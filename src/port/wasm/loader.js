// src/port/wasm/loader.js -- the environment of moon's wasm artifact, in place of emcc's
// runtime: Love() instantiates love.wasm and answers the Module the page already drives
// (repl.js, screen.mjs, test.mjs) -- ccall/cwrap, the string marshalling, _malloc/_free,
// and the HEAPU8/HEAPU32 views. the module imports ONE function, env.__ai_sys, nolibc's
// syscall door, and this file is the kernel under it: linux's numbers, the handful the
// artifact issues -- write, mmap over memory.grow, clock_gettime, exit -- and ENOSYS for
// the rest. the type law is the arity: every wasm param and answer is an i64, so a number
// crosses as a BigInt and comes back as a Number; the memory is 64-bit, so a view's
// offset is a Number and a pointer to wasm is a BigInt.
//
//   const M = await Love({ wasm, print, printErr })
//     wasm      the module's bytes, a URL, or a path; unset: love.wasm beside this file
//     print     a line of stdout (fd 1); printErr fd 2; both default to the console
//   Love is also the global `Love`, for a page that loads this file as a module script
//   and drives it from a classic one.

const NR = { write: 1, close: 3, mmap: 9, mprotect: 10, munmap: 11, writev: 20,
             exit: 60, clock_gettime: 228, exit_group: 231 };
const EBADF = 9, ENOSYS = 38;
const PAGE = 65536;

export class ExitStatus extends Error {
  constructor(status) { super('exit(' + status + ')'); this.name = 'ExitStatus'; this.status = status; } }

async function bytesOf(wasm) {
  if (wasm instanceof Uint8Array || wasm instanceof ArrayBuffer) return wasm;
  const node = typeof process !== 'undefined' && process.versions?.node;
  const at = wasm ?? (node && process.env.LOVE_WASM) ?? new URL('love.wasm', import.meta.url);   // a gate names the module
  if (node) {
    const { readFile } = await import('node:fs/promises');
    const { fileURLToPath } = await import('node:url');
    const p = at instanceof URL ? fileURLToPath(at) : String(at);
    return await readFile(p); }
  return await (await fetch(at)).arrayBuffer(); }

export default async function Love(opts = {}) {
  const print = opts.print ?? ((s) => console.log(s));
  const printErr = opts.printErr ?? ((s) => console.error(s));
  const dec = new TextDecoder(), enc = new TextEncoder();
  let memory, brk = 0;                                     // brk: the mmap bump, page-aligned bytes
  let uni = false;                                         // moon's convention: 16 params in, (i64 i64 f64 f64) out
  const u8 = () => new Uint8Array(memory.buffer);

  // the kernel: (n a b c d e f) as BigInts, the answer a BigInt (negative errno on refusal)
  const sys = (...a) => { const r = sys1(...a); return uni ? [r, 0n, 0, 0] : r; };
  const sys1 = (n, a, b, c, d, e, f) => {
    switch (Number(n)) {
      case NR.write: {
        const fd = Number(a), p = Number(b), len = Number(c);
        const s = dec.decode(u8().slice(p, p + len));
        (fd === 2 ? printErr : print)(s);
        return c; }
      case NR.writev: return BigInt(-EBADF);               // nolibc's kernel probe: -EBADF says linux
      case NR.close: case NR.mprotect: case NR.munmap: return 0n;
      case NR.mmap: {                                     // anonymous only: grow the memory by whole pages
        const len = Number(b), pages = Math.ceil(len / PAGE);
        if (!brk) brk = memory.buffer.byteLength;
        const at = brk;
        if (at + pages * PAGE > memory.buffer.byteLength)
          if (memory.grow(BigInt(pages)) < 0n) return BigInt(-12);   // ENOMEM
        brk = at + pages * PAGE;
        return BigInt(at); }
      case NR.clock_gettime: {                            // timespec {i64 sec, i64 nsec} at b
        const ms = Number(a) === 0 ? Date.now() : performance.now();
        const sec = Math.floor(ms / 1000), nsec = Math.floor((ms - sec * 1000) * 1e6);
        new BigInt64Array(memory.buffer, Number(b), 2).set([BigInt(sec), BigInt(nsec)]);
        return 0n; }
      case NR.exit: case NR.exit_group: throw new ExitStatus(Number(a));
      default: return BigInt(-ENOSYS); } };

  const { instance } = await WebAssembly.instantiate(await bytesOf(opts.wasm), { env: { __ai_sys: sys } });
  const ex = instance.exports;
  memory = ex.mem ?? ex.memory;
  uni = Object.values(ex).some((f) => typeof f === 'function' && f.length === 16);

  // the marshalling: every wasm param is an i64
  const toWasm = (t, v) => t === 'number' ? BigInt(Math.trunc(v)) : t === 'boolean' ? (v ? 1n : 0n) : v;
  const fromWasm = (t, v) => t === 'number' ? Number(v) : t === 'boolean' ? v !== 0n : t === 'string' ? UTF8ToString(Number(v)) : undefined;
  const lengthBytesUTF8 = (s) => enc.encode(s).length;
  const stringToUTF8 = (s, p, n) => {                     // n counts the terminator, as emcc's does
    const b = enc.encode(s), k = Math.max(0, Math.min(b.length, n - 1));
    u8().set(b.subarray(0, k), p); u8()[p + k] = 0; return k; };
  const UTF8ToString = (p, len) => {
    const h = u8(); if (len === undefined) { len = 0; while (h[p + len]) len++; }
    return dec.decode(h.slice(p, p + len)); };           // slice: firefox's TextDecoder refuses a view over resizable memory
  const _malloc = (n) => ccall('malloc', 'number', ['number'], [n]);
  const _free = (p) => { ccall('free', 'null', ['number'], [p]); };
  const ccall = (name, ret, types, args) => {
    const f = ex[name]; if (!f) throw new Error('no export ' + name);
    const frees = [];
    const vs = (args ?? []).map((v, i) => {
      if (types[i] === 'string') { const n = lengthBytesUTF8(v) + 1, p = _malloc(n); stringToUTF8(v, p, n); frees.push(p); return BigInt(p); }
      return toWasm(types[i], v); });
    // moon's convention: r0..r7 then f0..f7 in, the answer the first of (r0 f0)
    if (f.length === 16) { while (vs.length < 8) vs.push(0n); while (vs.length < 16) vs.push(0); }
    try { const r = f(...vs); return fromWasm(ret, Array.isArray(r) ? r[0] : r); } finally { frees.forEach(_free); } };
  const cwrap = (name, ret, types) => (...args) => ccall(name, ret, types, args);

  const M = { ccall, cwrap, UTF8ToString, stringToUTF8, lengthBytesUTF8, _malloc, _free, memory,
              get HEAPU8() { return new Uint8Array(memory.buffer); },
              get HEAPU32() { return new Uint32Array(memory.buffer); },
              get HEAP32() { return new Int32Array(memory.buffer); } };
  for (const k of Object.keys(ex)) if (typeof ex[k] === 'function' && !(('_' + k) in M)) M['_' + k] = ex[k];

  // the horn, in a browser: the sink taps its accepted PCM (host.c ai_horn_tap), and
  // this drains the ring and schedules it just ahead of the AudioContext clock. node
  // has no AudioContext, so M.horn.pull is a no-op there and the ring just cycles.
  const AC = typeof AudioContext !== 'undefined' ? AudioContext
           : typeof webkitAudioContext !== 'undefined' ? webkitAudioContext : null;
  let ctx = null, playhead = 0, pcmBuf = 0, pcmCap = 0;
  const horn = {
    // start (or resume, past the autoplay gate) the audio clock -- call from a gesture
    resume() { if (!AC) return false; ctx = ctx || new AC(); if (ctx.state === 'suspended') ctx.resume(); return true; },
    // drain what the horn has written and queue it; call each animation frame
    pull() {
      if (!ctx || ctx.state !== 'running') return 0;
      const rate = ccall('ai_horn_rate', 'number', [], []); if (!rate) return 0;
      const chans = ccall('ai_horn_chans', 'number', [], []) || 2, want = rate;   // up to a second per pull
      if (pcmCap < want) { if (pcmBuf) _free(pcmBuf); pcmBuf = _malloc(want * 2); pcmCap = want; }
      const got = ccall('ai_horn_drain', 'number', ['number', 'number'], [pcmBuf, want]);
      if (!got) return 0;
      const frames = (got / chans) | 0; if (!frames) return 0;
      const pcm = new Int16Array(memory.buffer, Number(pcmBuf), frames * chans);
      const ab = ctx.createBuffer(chans, frames, rate);
      for (let c = 0; c < chans; c++) { const ch = ab.getChannelData(c);
        for (let i = 0; i < frames; i++) ch[i] = pcm[i * chans + c] / 32768; }
      const src = ctx.createBufferSource(); src.buffer = ab; src.connect(ctx.destination);
      const now = ctx.currentTime, at = Math.max(now + 0.02, playhead);   // a small lead over the clock
      src.start(at); playhead = at + frames / rate;
      return frames; } };
  M.horn = horn;
  return M; }

if (typeof globalThis !== 'undefined') globalThis.Love = Love;
