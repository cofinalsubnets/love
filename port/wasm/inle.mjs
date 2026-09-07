// port/wasm/inle.mjs -- the serial terminal for love-wasm.wasm under node: the machine
// runs in a worker (cpu.mjs), this thread is its console. stdin's bytes go into the shared
// key ring, the serial line comes out on stdout, and the kernel's reset ends the run --
// which is how test/kernel/all.l's (reset) quits the gate, as -no-reboot does under qemu.
// a tty is put in raw mode so every key reaches the machine; ctrl-] leaves. with --fb the
// machine has a framebuffer console too, and its pixels land in a PPM once a second --
// what a gate can look at where a browser would show the canvas. --lift names a ramfs
// file the machine's program leaves behind, and where to put it on this side, once the
// program has quit (the reset).
//   usage: node port/wasm/inle.mjs [--fb WxH --dump screen.ppm] [--lift /in/machine:out/here]
//                                  love-wasm.wasm [boot line ..]
import { Worker } from 'node:worker_threads';
import { readFileSync, writeFileSync } from 'node:fs';
import { ring_n, ring_at, lift_n, lift_at, shared_n } from './cpu.mjs';

const args = process.argv.slice(2);
let fb = null, dump = null, liftReq = null;
while (args[0]?.startsWith('--')) {
  const o = args.shift();
  if (o === '--fb') { const [w, h] = args.shift().split('x').map(Number); fb = { w, h }; }
  else if (o === '--dump') dump = args.shift();
  else if (o === '--lift') { const [from, to] = args.shift().split(':'); liftReq = { from, to: to ?? from.split('/').pop() }; }
  else { console.error('inle.mjs: unknown option ' + o); process.exit(2); } }
if (fb) fb.dump = dump;
const [wasm, ...cmd] = args;
if (!wasm) { console.error('usage: inle.mjs [--fb WxH --dump screen.ppm] [--lift IN:OUT] love-wasm.wasm [boot line ..]'); process.exit(2); }

const ring = new SharedArrayBuffer(shared_n);
const ctl = new Int32Array(ring, 0, 4), kb = new Uint8Array(ring, ring_at, ring_n);
if (liftReq) {                                            // asked for at the reset: 2
  const p = new TextEncoder().encode(liftReq.from).subarray(0, lift_n - 1);
  new Uint8Array(ring, lift_at, lift_n).set(p);
  Atomics.store(ctl, 3, 2); }
const push = (bytes) => {
  let tail = Atomics.load(ctl, 1);
  for (const b of bytes) {
    const n = (tail + 1) % ring_n;
    if (n === Atomics.load(ctl, 0)) break;              // full: the rest is dropped, as a uart's would be
    kb[tail] = b; tail = n; }
  Atomics.store(ctl, 1, tail);
  Atomics.add(ctl, 2, 1);
  Atomics.notify(ctl, 2); };

const cpu = new Worker(new URL('./cpu.mjs', import.meta.url));
const leave = (code) => { if (process.stdin.isTTY) process.stdin.setRawMode(false); process.exit(code); };
cpu.on('message', (m) => {
  if (m.serial !== undefined) process.stdout.write(m.serial);
  else if (m.lift !== undefined) {
    if (m.error) { process.stderr.write(`inle: lift ${m.lift}: errno ${m.error}\n`); process.exitCode = 1; }
    else { writeFileSync(liftReq.to, m.bytes); process.stderr.write(`inle: ${m.lift} -> ${liftReq.to} (${m.bytes.length} bytes)\n`); } }
  else if (m.reset) leave(process.exitCode ?? 0);
  else if (m.fault) { process.stderr.write('\ninle: ' + m.fault + '\n'); leave(1); } });
cpu.on('error', (e) => { process.stderr.write('\ninle: ' + e + '\n'); leave(1); });
// the boot line is one string the kernel splits quote-aware (kmain's bootargv), so a
// word with a space in it is quoted back the way a shell had it
const word = (a) => !/[\s"']/.test(a) ? a : !a.includes('"') ? '"' + a + '"' : "'" + a + "'";
cpu.postMessage({ wasm: readFileSync(wasm), ring, ram: Number(process.env.INLE_RAM ?? 256),
                  cmd: cmd.map(word).join(' '), fb });

if (process.stdin.isTTY) process.stdin.setRawMode(true);
process.stdin.on('data', (d) => { if (process.stdin.isTTY && d.includes(29)) leave(0); push(d); });
process.stdin.on('end', () => { });                      // a pipe's end is not the machine's
