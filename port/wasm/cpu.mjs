// port/wasm/cpu.mjs -- the CPU under love-wasm.wasm: a worker that instantiates the
// module, answers its hypercalls, and never yields. the terminal is the other thread
// (inle.mjs under node, inle.html in the browser); the two share one ring of key bytes
// in a SharedArrayBuffer, which is what lets the kernel's idle really block: nanosleep is
// an Atomics.wait on the ring, one tick or the next key. nolibc's calls never arrive --
// kmain writes __ai_osv = -1 and they take inle/sys.c -- so what comes through the one
// import is inle/wasm/arch.c's five hypercalls, wearing linux's numbers.
//
//   in:  { wasm, ring, ram, cmd, fb }     the module's bytes, the shared ring, RAM in MiB,
//                                         the boot line, and { w, h, canvas } or null
//   out: { serial }                       a run of the serial console's bytes, as text
//        { reset }                        the kernel reset: the worker boots it again
//        { fault }                        the module trapped: the message, and the worker stops
//        { lift, bytes | error }          a ramfs file the terminal asked for (see lift below)

const NR = { read: 0, write: 1, nanosleep: 35, reboot: 169, clock_gettime: 228 };
const ENOSYS = 38;
// the ring: Int32 [0] the reader's head, [1] the writer's tail, [2] the wake count, [3] a
// lift request; then ring_n bytes of keys from ring_at, then lift_n bytes holding the
// path of the file asked for. inle.mjs and inle.html write it, this file reads it.
export const ring_n = 4096, ring_at = 16, lift_n = 256, lift_at = ring_at + ring_n;
export const shared_n = lift_at + lift_n;

// the way out of the machine: a ramfs file, read through the kernel's own fs faces --
// k_fs_open, k_fd_stat, k_fd_read, k_fd_close are plain C over kernel memory, exported like
// every extern, and called back into the module from a hypercall (the idle) or after
// a reset, when the kernel is parked and the tree is whole. the terminal leaves the path
// in the shared buffer and sets ctl[3]: 1 for the next idle, 2 for the reset -- a file a
// program writes last is there at the second and not the first. the bytes come back as
// a message.
let ex = null, top = 0;                                   // the module's exports; the scratch page
const lift = (when) => {
  if (!ex || Atomics.load(ctl, 3) !== when) return;
  const raw = new Uint8Array(ctl.buffer, lift_at, lift_n);
  let n = 0; while (n < lift_n && raw[n]) n++;
  const path = dec.decode(raw.slice(0, n));
  Atomics.store(ctl, 3, 0);
  const at = top + 256, buf = top + 512, bufn = 4096 - 512;
  u8().set(raw.subarray(0, n), at);
  const fd = Number(call(ex.k_fs_open, at, n, 114));     // 'r'
  if (fd < 0) { post({ lift: path, error: -fd }); return; }
  const parts = [];
  for (;;) {
    const k = Number(call(ex.k_fd_read, fd, buf, bufn));
    if (k <= 0) break;
    parts.push(u8().slice(buf, buf + k)); }
  call(ex.k_fd_close, fd);
  const bytes = new Uint8Array(parts.reduce((a, p) => a + p.length, 0));
  for (let o = 0, i = 0; i < parts.length; o += parts[i++].length) bytes.set(parts[i], o);
  post({ lift: path, bytes }); };

const isNode = typeof process !== 'undefined' && !!process.versions?.node;
const port = isNode ? (await import('node:worker_threads')).parentPort
           : typeof WorkerGlobalScope !== 'undefined' ? self : null;
const post = (m) => port.postMessage(m);

class Reboot extends Error { }

let memory, ctl, kb, seen = 0;
let fb = null, fbAt = 0, fbImg = null, fbCtx = null, blitAt = 0;
const mono0 = (typeof performance !== 'undefined' ? performance : Date).now();
const dec = new TextDecoder('utf-8', { fatal: false });
let serial = '';

const u8 = () => new Uint8Array(memory.buffer);
const flush = () => { if (serial) { post({ serial }); serial = ''; } };

// the framebuffer, 0xRRGGBB a pixel (core/quay/xterm256.h), into the canvas's RGBA --
// or, under node with no canvas, a PPM at fb.dump once a second: the gate's eyes.
let writeFileSync = null, dumpAt = 0;
const blit = (force) => {
  if (!fb || !(fbCtx || fb.dump)) return;
  const now = performance.now();
  if (!force && now - blitAt < 30) return;
  blitAt = now;
  const px = new Uint32Array(memory.buffer, fbAt, fb.w * fb.h);
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

const sys1 = (n, a, b, c) => {
  switch (Number(n)) {
    case NR.write: {                                    // the serial line: fds 1 and 2 alike
      const p = Number(b), len = Number(c), s = dec.decode(u8().subarray(p, p + len), { stream: true });
      serial += s;
      if (s.includes('\n') || serial.length > 4096) flush();
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
      flush(); blit(true); lift(1);
      // a key still queued is a wake already: the kernel drains a few per idle, so the
      // sleep is skipped until the ring is empty, and a pasted line lands at speed
      if (Atomics.load(ctl, 0) === Atomics.load(ctl, 1)) Atomics.wait(ctl, 2, seen, ms);
      seen = Atomics.load(ctl, 2);
      return 0n; }
    case NR.read: {                                     // the keys queued since the last read, never waiting
      const p = Number(b), max = Number(c), h = u8(), tail = Atomics.load(ctl, 1);
      let head = Atomics.load(ctl, 0), k = 0;
      while (k < max && head !== tail) { h[p + k++] = kb[head]; head = (head + 1) % ring_n; }
      Atomics.store(ctl, 0, head);
      return BigInt(k); }
    case NR.reboot: flush(); throw new Reboot();
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
  // boot line rides the top page of it, and a canvas's framebuffer is carved below that
  // by k_start (inle/wasm/arch.c) -- the same sum here says where to blit from.
  const lo = memory.buffer.byteLength;
  if (memory.grow(BigInt(Math.ceil(msg.ram * 1048576 / 65536))) < 0n) throw new Error('memory.grow refused');
  const hi = top = memory.buffer.byteLength - 4096;
  const cmd = new TextEncoder().encode(msg.cmd ?? '');
  u8().set(cmd.subarray(0, 255), hi); u8()[hi + Math.min(cmd.length, 255)] = 0;
  fb = msg.fb;
  if (fb) {
    fbAt = (hi - fb.w * fb.h * 4) & ~4095;
    if (fb.canvas) { fbCtx = fb.canvas.getContext('2d'); fbImg = fbCtx.createImageData(fb.w, fb.h); }
    else if (fb.dump && isNode) writeFileSync = (await import('node:fs')).writeFileSync; }
  seen = Atomics.load(ctl, 2);
  call(ex.k_start, lo, hi, fb ? fb.w : 0, fb ? fb.h : 0, hi); }

// the terminals import the ring's shape from here, so this file also loads on a main
// thread, where there is no port and nothing to do
if (port) isNode ? port.on('message', run) : port.addEventListener('message', (e) => run(e.data));
async function run(msg) {
  ctl = new Int32Array(msg.ring, 0, 4);
  kb = new Uint8Array(msg.ring, ring_at, ring_n);
  for (;;) {
    try { await boot(msg); return; }
    catch (e) {
      if (e instanceof Reboot) { lift(2); post({ reset: true }); continue; }   // a lift asked for at the end
      flush(); post({ fault: String(e?.stack ?? e) }); return; } } }
