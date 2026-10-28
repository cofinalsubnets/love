// src/inle/wasm/proc.mjs -- a process: an instance of its own of a compiled module, in a worker
// of its own, entered at moonlibc's __love_start as a hosted program. its memory, its clock and
// its sleeps are answered here; every other call goes to the kernel through the mailbox, which
// the kernel's worker serves (cpu.mjs) and src/inle/sys.c's k_proc_call answers. the numbers
// are x64's, moonlibc's on wasm.
//
//   in:  { module, pid, argv, env, box, ring }   the compiled module, the pid, its words, the
//                                                mailbox (procbox.mjs), and the kernel's ring
//                                                to wake it by
import { box_at, box_win } from './procbox.mjs';

const isNode = typeof process !== 'undefined' && !!process.versions?.node;
const port = isNode ? (await import('node:worker_threads')).parentPort
           : typeof WorkerGlobalScope !== 'undefined' ? self : null;
// a page's worker outlives its run unless it closes, its memory held: it says so and goes
if (port) isNode ? port.once('message', run)
                 : port.addEventListener('message', (e) => { run(e.data); port.postMessage(0); port.close(); }, { once: true });

class Exit extends Error { constructor(s) { super('exit ' + s); this.s = s; } }
const PAGE = 65536, enc = new TextEncoder();

// a call's pointer arguments: [which, length, direction]; a length is bytes, 'str' (to its
// NUL), 'int' (four bytes), or under 6 the index of the argument whose value it is
const ptrs = {
  0: [[1, 2, 'out']], 1: [[1, 2, 'in']], 217: [[1, 2, 'out']],            // read write getdents64
  5: [[1, 144, 'out']], 16: [[2, 64, 'both']], 293: [[0, 8, 'out']],      // fstat ioctl pipe2
  257: [[1, 'str', 'in']], 262: [[1, 'str', 'in'], [2, 144, 'out']],      // openat newfstatat
  258: [[1, 'str', 'in']], 263: [[1, 'str', 'in']], 268: [[1, 'str', 'in']],
  266: [[0, 'str', 'in'], [2, 'str', 'in']], 267: [[1, 'str', 'in'], [2, 3, 'out']],
  264: [[1, 'str', 'in'], [3, 'str', 'in']], 316: [[1, 'str', 'in'], [3, 'str', 'in']],
  280: [[1, 'str', 'in'], [2, 32, 'in']], 80: [[0, 'str', 'in']], 79: [[0, 1, 'out']],
  63: [[0, 390, 'out']], 61: [[1, 'int', 'out']],                           // uname wait4
  0x4100: [[0, 1, 'in'], [2, 3, 'in'], [4, 5, 'in']] };                   // inle's spawn
// the bulk calls go in window-sized pieces: a short count is a count all the same
const piece = { 0: 1, 1: 1, 217: 1 };

function run({ module, pid, argv, env, box: boxb, ring }) {
  const box = new Int32Array(boxb, 0, 4), boxa = new BigInt64Array(boxb, 16, 9),
        boxw = new Uint8Array(boxb, box_at, box_win), ctl = new Int32Array(ring, 0, 4);
  let memory, brk = 0, uni = false;
  const holes = [];                                     // freed ranges, address order, merged
  const u8 = () => new Uint8Array(memory.buffer);

  // one call to the kernel: the pointers' bytes into the window, the kernel woken, the answer
  // waited for and the bytes back
  const kcall = (n, args, deadline = 0) => {
    const a = args.map((v) => BigInt(v ?? 0)), back = [];
    let at = 0, mask = 0;
    for (const [i, len, dir] of ptrs[n] ?? []) {
      if (!a[i]) continue;                              // NULL stays NULL: the kernel's EFAULT
      const p = Number(a[i]), l = len === 'str' ? u8().indexOf(0, p) - p + 1 : len === 'int' ? 4 : len < 6 ? Number(a[len]) : len;
      if (l < 0 || at + l > box_win) return -14n;       // EFAULT: past the window
      if (dir !== 'out') boxw.set(u8().subarray(p, p + l), at);
      if (dir !== 'in') back.push([p, at, l]);
      a[i] = BigInt(at), mask |= 1 << i, at += (l + 7) & ~7; }
    boxa[0] = BigInt(n);
    for (let i = 0; i < 6; i++) boxa[i + 1] = a[i] ?? 0n;
    boxa[8] = BigInt(deadline);
    box[1] = mask, box[2] = at;
    Atomics.store(box, 0, 1);
    Atomics.add(ctl, 2, 1), Atomics.notify(ctl, 2);   // the kernel's idle wakes on its ring
    while (Atomics.load(box, 0) === 1) Atomics.wait(box, 0, 1);
    const r = boxa[7];
    for (const [p, o, l] of back) u8().set(boxw.subarray(o, o + l), p);
    Atomics.store(box, 0, 0);
    return r; };

  const map = (len) => {                                // whole pages, a freed range first
    const want = Math.ceil(len / PAGE) * PAGE, hi = holes.findIndex(([, l]) => l >= want);
    if (hi >= 0) {
      const [ha, hl] = holes[hi];
      if (hl === want) holes.splice(hi, 1); else holes[hi] = [ha + want, hl - want];
      u8().fill(0, ha, ha + want);                      // MAP_ANONYMOUS promises zeros
      return ha; }
    if (!brk) brk = memory.buffer.byteLength;
    if (brk + want > memory.buffer.byteLength &&
        memory.grow(BigInt(Math.ceil((brk + want - memory.buffer.byteLength) / PAGE))) < 0n) return -1;
    const at = brk;
    brk += want;
    return at; };
  const unmap = (a, len) => {
    holes.push([a, Math.ceil(len / PAGE) * PAGE]);
    holes.sort((x, y) => x[0] - y[0]);
    for (let i = 0; i + 1 < holes.length;)
      if (holes[i][0] + holes[i][1] === holes[i + 1][0]) holes[i][1] += holes.splice(i + 1, 1)[0][1];
      else i++; };
  const nap = (ms) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
  const clock = (which) => which === 0 ? Date.now() : performance.now();

  const sys1 = (n, a, b, c, d, e, f) => {
    n = Number(n);
    switch (n) {
      case 9: {                                         // mmap: anonymous, or a file read whole
        const len = Number(b), at = map(len);
        if (at < 0) return -12n;
        const fd = Number(e);
        if (fd >= 0 && fd < 1 << 30) {
          if (kcall(8, [e, f, 0n]) < 0n) return -19n;   // ENODEV: not a file that seeks
          for (let o = 0; o < len;) {
            const r = Number(sys1(0n, e, BigInt(at + o), BigInt(len - o)));
            if (r <= 0) break;
            o += r; } }
        return BigInt(at); }
      case 11: unmap(Number(a), Number(b)); return 0n;
      case 10: case 28: return 0n;                      // mprotect madvise
      case 13: case 14: return 0n;                      // the signal mask and actions: ours alone
      case 20: return -9n;                              // writev: moonlibc's probe, which says linux
      case 228: {
        const ms = clock(Number(a)), s = Math.floor(ms / 1000);
        new BigInt64Array(memory.buffer, Number(b), 2).set([BigInt(s), BigInt(Math.floor((ms - s * 1000) * 1e6))]);
        return 0n; }
      case 35: {                                        // nanosleep
        const ts = new BigInt64Array(memory.buffer, Number(a), 2);
        nap(Number(ts[0]) * 1000 + Number(ts[1]) / 1e6);
        return 0n; }
      case 271: {                                       // ppoll: the deadline is kept here
        let ms = -1;
        if (c) { const ts = new BigInt64Array(memory.buffer, Number(c), 2); ms = Number(ts[0]) * 1000 + Number(ts[1]) / 1e6; }
        const nb = Number(b) * 8;
        if (nb > box_win) return -22n;
        ptrs[271] = nb ? [[0, nb, 'both']] : [];
        return kcall(271, [a, b, ms === 0 ? 0n : 1n], ms > 0 ? Date.now() + ms : 0); }
      case 60: case 231: kcall(231, [a]); throw new Exit(Number(a) & 255);
      case 102: case 104: case 107: case 108: return 0n;  // uid gid euid egid: one user
      case 95: return 18n;                              // umask: 022, kept nowhere
      default: {
        if (!(n in ptrs) && ![3, 8, 72, 77, 81, 292, 39, 110, 109, 112, 111, 62].includes(n)) return -38n;
        if (piece[n] && Number(c) > box_win) c = BigInt(box_win);
        return kcall(n, [a, b, c, d, e, f]); } } };
  const sys = (...a) => { const r = sys1(...a); return uni ? [r, 0n, 0, 0] : r; };

  const inst = new WebAssembly.Instance(module, { env: { __love_sys: sys } }), ex = inst.exports;
  memory = ex.mem ?? ex.memory;
  uni = Object.values(ex).some((fn) => typeof fn === 'function' && fn.length === 16);
  // the stack linux lays: argc, argv, a NULL, envp, a NULL, an empty auxv; the words above it
  const base = memory.buffer.byteLength, words = [BigInt(argv.length)];
  memory.grow(1n);
  let at = base + 8 * (argv.length + env.length + 6);
  const lay = (s) => { const b = enc.encode(s + '\0'); u8().set(b, at); words.push(BigInt(at)); at += b.length; };
  argv.forEach(lay), words.push(0n), env.forEach(lay), words.push(0n, 0n, 0n);
  if (at > base + PAGE) { kcall(231, [7n]); return; }   // E2BIG, said as a status
  new BigInt64Array(memory.buffer, base, words.length).set(words);
  brk = memory.buffer.byteLength;
  const call = (fn, ...v) => { if (fn.length === 16) { while (v.length < 8) v.push(0n); while (v.length < 16) v.push(0); } return fn(...v); };
  try { call(ex.__love_start, BigInt(base), 0n); kcall(231, [0n]); }
  catch (e) {
    if (e instanceof Exit) return;
    // a trap ends the process and not the machine: the status a fault would leave
    const w = enc.encode(`\n;; pid ${pid}: ${e?.message ?? e}\n`);
    u8().set(w, base), kcall(1, [2n, BigInt(base), BigInt(w.length)]);
    kcall(231, [134n]); } }
