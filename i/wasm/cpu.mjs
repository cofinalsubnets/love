// i/wasm/cpu.mjs -- the CPU under love.wasm: a worker that instantiates the
// module, answers its hypercalls, and never yields. the terminal is the other thread
// (inle.mjs under node, inle.html in the browser); the two share one ring of key bytes
// in a SharedArrayBuffer, which is what lets the kernel's idle really block: nanosleep is
// an Atomics.wait on the ring, one tick or the next key. moonlibc's calls never arrive --
// kmain writes __ai_osv = -1 and they take i/sys.c -- so what comes through the one import
// is i/wasm/arch.c's five hypercalls wearing linux's numbers, and i/wasm/horn.c's four
// wearing none, whose samples go into a second ring for the terminal's AudioWorklet.
//
//   in:  { wasm, ring, ram, cmd, fb,      the module's bytes, the shared ring, RAM in MiB,
//          image }                        the boot line, { w, h, scale, canvas } or null, and
//                                         the heap image (`bake PATH` on the boot line) or
//                                         null. w and h are REAL pixels and scale is how
//                                         many of them a glyph pixel gets (0 = the console
//                                         picks); rows and columns are the kernel's answer
//   out: { serial }                       a run of the serial console's bytes, as text
//        { reset }                        the kernel reset: the worker boots it again
//        { fault }                        the module trapped: the message, and the worker stops
//        { lift, bytes | error }          a ramfs file the terminal asked for (see lift below)

// the five wear linux's numbers; the horn's four are ours -- sound has no call to borrow
// one from, so the block sits well clear of any syscall table (i/wasm/horn.c).
const NR = { read: 0, write: 1, nanosleep: 35, reboot: 169, clock_gettime: 228,
             horn_open: 0x4000, horn_write: 0x4001, horn_lag: 0x4002, horn_close: 0x4003,
             lift: 0x4010, scan: 0x4011, drew: 0x4012, kexec: 0x4013,
             fetch_open: 0x4020, fetch_read: 0x4021, fetch_close: 0x4022 };
const ENOENT = 2, EBADF = 9, ENOSYS = 38, ENAMETOOLONG = 36;
// the ring: Int32 [0] the reader's head, [1] the writer's tail, [2] the wake count, [3] a
// lift request, [4] a resize request with [5] [6] [7] the width, height and glyph scale it
// asks for, [8] the horn's rate (0 closed) with [9] frames written and [10] played, and
// [11] whether something real is playing them, [12] [13] the scan ring's head and tail;
// then ring_n bytes of keys from ring_at, scan_n bytes of scancodes (PS/2 set 1, make and
// break, what the kernel's tap reads and a game wants: a key's release is not a byte),
// lift_n bytes holding the path of the file asked for, and the horn's own samples.
// inle.mjs and inle.html write it, this file reads it.
// the ring is the only door into the worker: it blocks inside k_start and idles in an
// Atomics.wait, so it never returns to an event loop and a postMessage cannot reach it.
export const ctl_n = 14, ring_n = 4096, ring_at = ctl_n * 4;
export const scan_n = 256, scan_at = ring_at + ring_n, c_sh = 12, c_st = 13;
export const lift_n = 256, lift_at = scan_at + scan_n;
export const c_rate = 8, c_wrote = 9, c_played = 10, c_live = 11;
// the horn's ring: 16-bit stereo frames, a third of a second at 48k, which is about what
// a small card holds. a power of two, so `& horn_mask` indexes it even once the written
// count has wrapped past 2^31 -- the counts are int32 and their DIFFERENCE is the lag.
export const horn_n = 16384, horn_mask = horn_n - 1, horn_at = lift_at + lift_n;
export const shared_n = horn_at + horn_n * 4;

// the way out of the machine: a ramfs file, read through the kernel's own fs faces --
// k_fs_open, k_fd_stat, k_fd_read, k_fd_close are plain C over kernel memory, exported like
// every extern, and called back into the module from a hypercall (the idle) or after
// a reset, when the kernel is parked and the tree is whole. the terminal leaves the path
// in the shared buffer and sets ctl[3]: 1 for the next idle, 2 for the reset -- a file a
// program writes last is there at the second and not the first. the bytes come back as
// a message.
let ex = null, top = 0;                                   // the module's exports; the scratch page
// the page's network, one body at a time (kmain's k_fetch through i/wasm/arch.c): the
// worker fetches a URL whole -- a synchronous XMLHttpRequest, which a worker may make, so
// the guest's blocking read is the browser's own -- and hands it over in pieces. under
// node there is no synchronous fetch, so a URL is a path under `origin` (inle.mjs
// --origin), which is what a gate wants of it anyway
let body = null, bodyAt = 0, origin = null, readFileSync = null;
const fetchOpen = (url) => {
  body = null, bodyAt = 0;
  try {
    if (isNode) {
      if (!origin || /^[a-z][a-z0-9+.-]*:/i.test(url)) return -ENOSYS;
      body = new Uint8Array(readFileSync(origin + '/' + url.replace(/^\/+/, ''))); }
    else {
      const x = new XMLHttpRequest();
      x.open('GET', url, false);
      x.responseType = 'arraybuffer';
      x.send();
      if (x.status < 200 || x.status >= 300) return -ENOENT;
      body = new Uint8Array(x.response); } }
  catch (e) { body = null; return -ENOENT; }
  return body.length; };
// ..and 3, at the reset, is a kexec: the slot holds a path, a NUL and a boot line, and
// the file's bytes become the module the machine boots next, with that line, no image --
// the way a page reloads what the machine built. the boot message is rewritten in place,
// so every reset after it boots the new module too
const lift = (when, msg) => {
  if (!ex) return;
  const kind = Atomics.load(ctl, 3);
  if (kind !== when && !(kind === 3 && when === 2)) return;
  const raw = new Uint8Array(ctl.buffer, lift_at, lift_n);
  let n = 0; while (n < lift_n && raw[n]) n++;
  const path = dec.decode(raw.slice(0, n));
  let cmd = null;
  if (kind === 3) { let e = n + 1; while (e < lift_n && raw[e]) e++; cmd = dec.decode(raw.slice(n + 1, e)); }
  Atomics.store(ctl, 3, 0);
  const at = top + 256, buf = top + 512, bufn = 4096 - 512;
  u8().set(raw.subarray(0, n), at);
  const fd = Number(call(ex.k_fs_open, at, n, 114));     // 'r'
  if (fd < 0) { post(kind === 3 ? { kexec: path, error: -fd } : { lift: path, error: -fd }); return; }
  const parts = [];
  for (;;) {
    const k = Number(call(ex.k_fd_read, fd, buf, bufn));
    if (k <= 0) break;
    parts.push(u8().slice(buf, buf + k)); }
  call(ex.k_fd_close, fd);
  const bytes = new Uint8Array(parts.reduce((a, p) => a + p.length, 0));
  for (let o = 0, i = 0; i < parts.length; o += parts[i++].length) bytes.set(parts[i], o);
  if (kind === 3) { msg.wasm = bytes.buffer; msg.image = null; msg.cmd = cmd; post({ kexec: path, cmd }); return path; }
  post({ lift: path, bytes }); };

// the canvas was resized under the running machine: the page leaves the new size in the
// ring and the kernel re-makes its console at it (kmain's k_fb_reseat, through arch.c).
// the base does not move -- the paper was carved at the RESERVATION at boot, and what a
// resize changes is only how much of it is in use -- so this side keeps blitting from the
// same place and reads a new w and h back. refused, the machine keeps the box it had, and
// the frame that goes out says which size that is -- as a module older than the door does,
// the export being the one thing this side can ask about before it calls.
const resize = () => {
  if (!ex?.k_fb_resize || !fb || !Atomics.exchange(ctl, 4, 0)) return;
  const w = Atomics.load(ctl, 5), h = Atomics.load(ctl, 6), scale = Atomics.load(ctl, 7);
  if (w <= 0 || h <= 0 || (w === fb.w && h === fb.h && scale === (fb.scale ?? 0))) return;
  if (!Number(call(ex.k_fb_resize, w, h, scale))) return;
  fb.w = w, fb.h = h, fb.scale = scale;
  if (fbCtx) fbImg = fbCtx.createImageData(w, h);
  drew = true; };                                         // the whole screen is new

const isNode = typeof process !== 'undefined' && !!process.versions?.node;
const port = isNode ? (await import('node:worker_threads')).parentPort
           : typeof WorkerGlobalScope !== 'undefined' ? self : null;
const post = (m, t) => port.postMessage(m, t);

class Reboot extends Error { }

let memory, ctl, kb, sc, pcm, seen = 0;
let fb = null, fbAt = 0, fbImg = null, fbCtx = null, blitAt = 0;
const mono0 = (typeof performance !== 'undefined' ? performance : Date).now();
const dec = new TextDecoder('utf-8', { fatal: false });
let serial = '';

const u8 = () => new Uint8Array(memory.buffer);
const flush = () => { if (serial) { post({ serial }); serial = ''; } };

// the framebuffer, 0xRRGGBB a pixel (l/quay/xterm256.h), into the canvas's RGBA --
// or, under node with no canvas, a PPM at fb.dump once a second: the gate's eyes.
let writeFileSync = null, dumpAt = 0, postAt = 0;
// the guest wrote since the last frame went out. without one the only thing that can have
// moved is the cursor's blink, so an idle screen goes out at the blink's rate and not the
// tick's -- the idle forces a blit every 10 ms, and at REAL pixels a frame is megabytes to
// swizzle and hand over. a console nobody is typing at was the expensive case, which is
// absurd. (the next lever, if output bursts ever want it, is the painted band: quay knows
// which rows it drew, and a frame could carry those rows and a y.)
let drew = false;
const blink_ms = 640;                                     // kmain's cursor phase: kticks & 64, one tick per 10 ms
const blit = (force) => {
  if (!fb || !(fbCtx || fb.dump || fb.post)) return;
  const now = performance.now();
  if (!force && now - blitAt < 30) return;
  if (!drew && now - blitAt < blink_ms) return;
  if (fb.post && now - postAt < 16) return;
  blitAt = now;
  drew = false;
  const px = new Uint32Array(memory.buffer, fbAt, fb.w * fb.h);
  // THE FRAME GOES BY MESSAGE, not by an offscreen commit. this worker never returns to
  // its event loop -- the idle is an Atomics.wait inside the boot's own task -- and a
  // canvas transferred here only reaches its placeholder at a task checkpoint, which
  // never arrives. postMessage does work from inside a long task, so the pixels travel
  // that way and the page paints them. the 16 ms floor above is this lane's: no display
  // shows more than one frame in that time anyway.
  if (fb.post) {
    postAt = now;
    const rgba = new Uint8ClampedArray(px.length * 4), o32 = new Uint32Array(rgba.buffer);
    for (let i = 0; i < px.length; i++) {
      const v = px[i];
      o32[i] = 0xff000000 | ((v & 0xff) << 16) | (v & 0xff00) | ((v >>> 16) & 0xff); }
    post({ frame: rgba.buffer, w: fb.w, h: fb.h }, [rgba.buffer]);
    return; }
  if (fbCtx) {
    const out = new Uint32Array(fbImg.data.buffer);
    for (let i = 0; i < px.length; i++) {
      const v = px[i];
      out[i] = 0xff000000 | ((v & 0xff) << 16) | (v & 0xff00) | ((v >>> 16) & 0xff); }
    fbCtx.putImageData(fbImg, 0, 0); }
  else if (writeFileSync && now - dumpAt > 1000) {
    dumpAt = now;
    const head = new TextEncoder().encode(`P6\n${fb.w} ${fb.h}\n255\n`),
          out = new Uint8Array(head.length + px.length * 3);
    out.set(head);
    for (let i = 0, o = head.length; i < px.length; i++, o += 3) {
      const v = px[i];
      out[o] = v >>> 16, out[o + 1] = (v >>> 8) & 0xff, out[o + 2] = v & 0xff; }
    writeFileSync(fb.dump, out); } };

// the horn, where nothing real is draining it -- node, or a page whose audio has not been
// let in yet. the worker keeps the played count off its own clock, so the ring still
// fills, refuses and drains at the rate and the guest sees the shape a card gives. the
// remainder is kept: at 48k a millisecond is 48 frames and a bit, and dropping the bit
// every poll would run the clock slow.
// ..and THE MACHINE OUTLIVES ITS SPEAKER. c_live is the page's word that something is
// playing, and a page can stop being true to it without saying so: a worklet the browser
// collected, or one whose process threw and so will never be called again, leaves the flag
// standing and takes nothing. the guest would then park on a full ring for ever -- not
// slow, stopped, with the last of the audio going round. so a drainer that has taken
// nothing while the guest sat refused is deaf, and the clock takes the samples back: the
// sound stops and the game does not.
const horn_deaf = 250;
let sinkAt = 0, sinkAcc = 0, sawPlayed = 0, sawAt = 0, deaf = false;
const hornSink = () => {
  const rate = Atomics.load(ctl, c_rate);
  if (!rate) return;
  const now = performance.now();
  const seen = Atomics.load(ctl, c_played);
  if (seen !== sawPlayed) sawPlayed = seen, sawAt = now, deaf = false;
  if (Atomics.load(ctl, c_live) && !deaf) { sinkAt = now, sinkAcc = 0; return; }
  sinkAcc += (now - sinkAt) * rate / 1000;
  sinkAt = now;
  const step = Math.floor(sinkAcc);
  sinkAcc -= step;
  const w = Atomics.load(ctl, c_wrote);
  let p = (Atomics.load(ctl, c_played) + step) | 0;
  if (((p - w) | 0) > 0) p = w;                           // the clock passed the writer
  Atomics.store(ctl, c_played, p); };

const sys1 = (n, a, b, c) => {
  switch (Number(n)) {
    case NR.write: {                                    // the serial line: fds 1 and 2 alike
      const p = Number(b), len = Number(c), s = dec.decode(u8().subarray(p, p + len), { stream: true });
      serial += s;
      if (s.includes('\n') || serial.length > 4096) flush();
      drew = true;
      blit(false);
      return c; }
    case NR.clock_gettime: {                            // 0 the wall, 1 since the worker began
      const ms = Number(a) === 0 ? Date.now() : performance.now() - mono0;
      const sec = Math.floor(ms / 1000), ns = Math.floor((ms - sec * 1000) * 1e6);
      new BigInt64Array(memory.buffer, Number(b), 2).set([BigInt(sec), BigInt(ns)]);
      return 0n; }
    case NR.nanosleep: {                                // the idle: a tick, or the next key
      const ts = new BigInt64Array(memory.buffer, Number(a), 2),
            ms = Number(ts[0]) * 1000 + Number(ts[1]) / 1e6;
      flush(); resize(); blit(true); lift(1);
      // a key still queued is a wake already: the kernel drains a few per idle, so the
      // sleep is skipped until the ring is empty, and a pasted line lands at speed
      if (Atomics.load(ctl, 0) === Atomics.load(ctl, 1) && Atomics.load(ctl, c_sh) === Atomics.load(ctl, c_st))
        Atomics.wait(ctl, 2, seen, ms);
      seen = Atomics.load(ctl, 2);
      return 0n; }
    case NR.read: {                                     // the keys queued since the last read, never waiting
      const p = Number(b), max = Number(c), h = u8(), tail = Atomics.load(ctl, 1);
      let head = Atomics.load(ctl, 0), k = 0;
      while (k < max && head !== tail) { h[p + k++] = kb[head]; head = (head + 1) % ring_n; }
      Atomics.store(ctl, 0, head);
      return BigInt(k); }
    case NR.scan: {                                     // the scancodes queued, the same way
      const p = Number(a), max = Number(b), h = u8(), tail = Atomics.load(ctl, c_st);
      let head = Atomics.load(ctl, c_sh), k = 0;
      while (k < max && head !== tail) { h[p + k++] = sc[head]; head = (head + 1) % scan_n; }
      Atomics.store(ctl, c_sh, head);
      return BigInt(k); }
    case NR.drew: drew = true; blit(false); return 0n;  // the paper changed under a program's own hand
    case NR.fetch_open: return BigInt(fetchOpen(dec.decode(u8().subarray(Number(a), Number(a) + Number(b)))));
    case NR.fetch_read: {
      if (!body) return BigInt(-EBADF);
      const n = Math.min(Number(b), body.length - bodyAt);
      u8().set(body.subarray(bodyAt, bodyAt + n), Number(a));
      bodyAt += n;
      return BigInt(n); }
    case NR.fetch_close: body = null, bodyAt = 0; return 0n;
    case NR.reboot: flush(); throw new Reboot();
    // the horn: the rate the page will take, then the ring empty behind it -- what a
    // closed run left unplayed is not the new one's lag
    case NR.horn_open: {
      const rate = Number(a);
      if (rate < 8000 || rate > 192000) return -1n;
      Atomics.store(ctl, c_played, Atomics.load(ctl, c_wrote));
      sinkAt = sawAt = performance.now(), sinkAcc = 0;
      sawPlayed = Atomics.load(ctl, c_played), deaf = false;
      Atomics.store(ctl, c_rate, rate);
      return 0n; }
    case NR.horn_write: {                               // 16-bit stereo, what fits behind the head
      if (!Atomics.load(ctl, c_rate)) return -1n;
      hornSink();
      const w = Atomics.load(ctl, c_wrote), room = horn_n - ((w - Atomics.load(ctl, c_played)) | 0);
      // refused is the one moment the question matters: the guest is waiting on a drainer
      // that has taken nothing since sawAt, and past horn_deaf that is not a busy speaker
      if (room <= 0 && performance.now() - sawAt > horn_deaf) deaf = true;
      const frames = Math.min(Number(b) >>> 2, room > 0 ? room : 0);
      const src = new Uint8Array(memory.buffer, Number(a), frames * 4), at = (w & horn_mask) * 4;
      const head = Math.min(frames * 4, horn_n * 4 - at);
      pcm.set(src.subarray(0, head), at);
      pcm.set(src.subarray(head), 0);
      Atomics.store(ctl, c_wrote, (w + frames) | 0);
      return BigInt(frames * 4); }
    case NR.horn_lag:
      if (!Atomics.load(ctl, c_rate)) return 0n;
      hornSink();
      return BigInt((Atomics.load(ctl, c_wrote) - Atomics.load(ctl, c_played)) | 0);
    case NR.horn_close: Atomics.store(ctl, c_rate, 0); return 0n;
    // the machine asks for a file to be carried out: the path into the lift slot, the
    // request raised, and the next idle reads the file and posts it
    case NR.lift: {
      const p = Number(a), n = Math.min(Number(b), lift_n - 1);
      const raw = new Uint8Array(ctl.buffer, lift_at, lift_n);
      raw.fill(0);
      raw.set(u8().subarray(p, p + n));
      Atomics.store(ctl, 3, 1);
      return 0n; }
    case NR.kexec: {                                    // the path, a NUL, the boot line: read at the reset
      const p = Number(a), n = Number(b);
      if (n >= lift_n) return BigInt(-ENAMETOOLONG);
      const raw = new Uint8Array(ctl.buffer, lift_at, lift_n);
      raw.fill(0);
      raw.set(u8().subarray(p, p + n));
      Atomics.store(ctl, 3, 3);
      return 0n; }
    default: return BigInt(-ENOSYS); } };

// moon's convention: 16 params in (8 i64, 8 f64), (i64 i64 f64 f64) out
const call = (f, ...args) => {
  const vs = args.map((v) => typeof v === 'bigint' ? v : BigInt(v));
  if (f.length === 16) { while (vs.length < 8) vs.push(0n); while (vs.length < 16) vs.push(0); }
  const r = f(...vs);
  return Array.isArray(r) ? r[0] : r; };

async function boot(msg) {
  let uni = false;
  const sys = (...a) => { const r = sys1(...a); return uni ? [r, 0n, 0, 0] : r; };
  const { instance } = await WebAssembly.instantiate(msg.wasm, { env: { __ai_sys: sys } });
  ex = instance.exports;
  memory = ex.mem ?? ex.memory;
  uni = Object.values(ex).some((f) => typeof f === 'function' && f.length === 16);
  // RAM is everything above the module's own pages: grow, and hand kmain the span. the
  // boot line rides the top page of it, the heap image (if the terminal brought one) sits
  // below that, and a canvas's framebuffer is carved below those by k_start
  // (i/wasm/arch.c) -- the same sum here says where to blit from. the two carves must
  // agree to the byte: k_start never returns, so this side cannot ask where it landed.
  const lo = memory.buffer.byteLength, imgn = msg.image?.byteLength ?? 0;
  if (memory.grow(BigInt(Math.ceil((msg.ram * 1048576 + imgn) / 65536))) < 0n) throw new Error('memory.grow refused');
  // every carve below rounds DOWN with a remainder, never with `& ~mask`: the machine is
  // memory64 and an address past 2 GB does not survive a bitwise operator, which reads its
  // operand as int32. `& ~4095` on 2148 MB answers a negative offset and the first `set`
  // says only that it is out of bounds.
  const down = (x, m) => x - (x % m);
  let hi = top = memory.buffer.byteLength - 4096;
  const cmd = new TextEncoder().encode(msg.cmd ?? '');
  u8().set(cmd.subarray(0, 255), hi); u8()[hi + Math.min(cmd.length, 255)] = 0;
  const img = imgn ? down(hi - imgn, 8) : 0;
  if (imgn) { u8().set(new Uint8Array(msg.image), img); hi = down(img, 4096); }
  fb = msg.fb;
  origin = msg.origin ?? null;
  if (isNode && origin) readFileSync = (await import('node:fs')).readFileSync;
  let cap = 0;
  if (fb) {
    // the RESERVATION, in pixels: the most this canvas will ever be, which is the screen
    // it is on. the paper is carved at that and the heap gets what is under it, so a later
    // resize (k_fb_reseat) lands inside memory the kernel was never given. absent, it is
    // the live size -- the canvas is pinned, which is what it always was.
    cap = Math.max(fb.cap ?? 0, fb.w * fb.h);
    fbAt = down(hi - cap * 4, 4096);
    if (fb.canvas) { fbCtx = fb.canvas.getContext('2d'); fbImg = fbCtx.createImageData(fb.w, fb.h); }
    else if (fb.dump && isNode) writeFileSync = (await import('node:fs')).writeFileSync; }
  seen = Atomics.load(ctl, 2);
  // the scale and the reservation ride ONE argument: moon's wasm convention gives eight
  // integer slots and this call already spends them. low byte the scale, the rest pixels.
  const sc = fb ? ((fb.scale ?? 0) & 0xff) + cap * 256 : 0;
  call(ex.k_start, lo, hi, fb ? fb.w : 0, fb ? fb.h : 0, sc, top, img, imgn); }

// the terminals import the ring's shape from here, so this file also loads on a main
// thread, where there is no port and nothing to do
if (port) isNode ? port.on('message', run) : port.addEventListener('message', (e) => run(e.data));
async function run(msg) {
  ctl = new Int32Array(msg.ring, 0, ctl_n);
  kb = new Uint8Array(msg.ring, ring_at, ring_n);
  sc = new Uint8Array(msg.ring, scan_at, scan_n);
  pcm = new Uint8Array(msg.ring, horn_at, horn_n * 4);
  for (;;) {
    try { await boot(msg); return; }
    catch (e) {
      // a lift asked for at the end, and the card shut: a machine that has gone does not
      // leave a rate standing for the next one's first frames to be played under
      if (e instanceof Reboot) { Atomics.store(ctl, c_rate, 0); const into = lift(2, msg); post({ reset: true, into }); continue; }
      flush(); post({ fault: String(e?.stack ?? e) }); return; } } }
