// inle/wasm/inle.mjs -- the serial terminal for love.wasm under node: the machine
// runs in a worker (cpu.mjs), this thread is its console. stdin's bytes go into the shared
// key ring, the serial line comes out on stdout, and the kernel's reset ends the run --
// which is how test/kernel/all.l's (reset) quits the gate, as -no-reboot does under qemu.
// a tty is put in raw mode so every key reaches the machine; ctrl-] leaves. with --fb the
// machine has a framebuffer console too, and its pixels land in a PPM once a second --
// what a gate can look at where a browser would show the canvas; the size is REAL pixels
// and the console settles its own rows and columns inside it. --scale is how many of those
// pixels a glyph pixel gets, and without one the console picks from the size. --lift names
// a ramfs file the machine's program leaves behind, and where to put it on this side, once
// the program has quit (the reset). --image hands the machine a heap image to wake (the one
// `bake PATH` on the boot line writes, lifted out: `make out/wasm/love.image`).
// --horn names a file to lay what the machine PLAYS in, as raw 16-bit stereo at the
// horn's own rate: the AudioWorklet a page has, headless. --press names keys (scan.mjs's
// names, e.code's spelling) pressed and released in turn on the scan lane, --after
// seconds into the run, or five seconds after a line of the serial output holds that
// text: a game's keys, which no tty byte can carry. --for ends the run after that many
// seconds, with the status timeout(1) gives, for a program that never quits. a kexec
// aboard (the machine booting a module it built) is reported and the run goes on; the
// plain reset still ends it.
// --origin DIR is the page's network: what the machine fetches (kmain's fetch door) is read
// as a file under DIR, where a page would ask its own origin.
//   usage: node inle/wasm/inle.mjs [--fb WxH --scale N --dump screen.ppm]
//                                  [--lift /in/machine:b/here] [--horn sound.raw]
//                                  [--press "Escape Enter" --after S] [--for S]
//                                  [--origin DIR] [--image love.image] love.wasm [boot line ..]
import { Worker } from 'node:worker_threads';
import { openSync, readFileSync, writeFileSync, writeSync } from 'node:fs';
import { ctl_n, ring_n, ring_at, lift_n, lift_at, shared_n, scan_at, scan_n, c_sh, c_st,
         horn_at, horn_n, c_rate, c_wrote, c_played, c_live } from './cpu.mjs';
import { scanlane, codes } from './scan.mjs';

const args = process.argv.slice(2);
let fb = null, dump = null, scale = 0, liftReq = null, image = null, hornFile = null, deaf = false;
let press = [], after = 0, forS = 0, origin = null;
while (args[0]?.startsWith('--')) {
  const o = args.shift();
  if (o === '--fb') { const [w, h] = args.shift().split('x').map(Number); fb = { w, h }; }
  else if (o === '--scale') scale = Number(args.shift());
  else if (o === '--dump') dump = args.shift();
  else if (o === '--lift') { const [from, to] = args.shift().split(':'); liftReq = { from, to: to ?? from.split('/').pop() }; }
  else if (o === '--horn') hornFile = args.shift();
  else if (o === '--deaf') deaf = true;
  else if (o === '--press') press = args.shift().split(/\s+/).filter(Boolean);
  else if (o === '--after') { const v = args.shift(); after = /^[\d.]+$/.test(v) ? Number(v) : v; }
  else if (o === '--for') forS = Number(args.shift());
  else if (o === '--origin') origin = args.shift();
  else if (o === '--image') { const b = readFileSync(args.shift()); image = b.buffer.slice(b.byteOffset, b.byteOffset + b.length); }
  else { console.error('inle.mjs: unknown option ' + o); process.exit(2); } }
if (fb) fb.dump = dump, fb.scale = scale;
const [wasm, ...cmd] = args;
if (!wasm) { console.error('usage: inle.mjs [--fb WxH --scale N --dump screen.ppm] [--lift IN:OUT] [--horn RAW] [--press KEYS --after S] [--for S] [--origin DIR] [--deaf] [--image IMG] love.wasm [boot line ..]'); process.exit(2); }

const ring = new SharedArrayBuffer(shared_n);
const ctl = new Int32Array(ring, 0, ctl_n), kb = new Uint8Array(ring, ring_at, ring_n);
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

// --horn FILE: the browser's AudioWorklet, headless. it takes the machine's samples off
// the ring AT THE RATE, so the ring fills and refuses exactly as it does under a real one
// and the run is timed the way a player times it -- and what it takes goes to a file as
// raw 16-bit stereo, which is what a gate can look at where a page would make a sound.
// c_live is set before the machine boots: it says the ring has a drainer, and without it
// cpu.mjs would keep the count off its own clock and these samples would never be read.
const pcm = new Uint8Array(ring, horn_at, horn_n * 4);
let hornAt = 0, hornAcc = 0, hornOut = null;
const hornDrain = () => {
  const rate = Atomics.load(ctl, c_rate);
  if (!rate) { hornAt = 0; return; }
  const now = performance.now();
  if (!hornAt) { hornAt = now; return; }                  // the first tick only starts the clock
  hornAcc += (now - hornAt) * rate / 1000;
  hornAt = now;
  let want = Math.floor(hornAcc);
  hornAcc -= want;
  const p = Atomics.load(ctl, c_played), have = (Atomics.load(ctl, c_wrote) - p) | 0;
  if (want > have) want = have;                           // an underrun: real time, nothing to play
  if (want > 0) {
    const at = (p & (horn_n - 1)) * 4, head = Math.min(want * 4, horn_n * 4 - at);
    hornOut ??= openSync(hornFile, 'w');
    writeSync(hornOut, pcm.slice(at, at + head));          // sliced: the fd wants unshared bytes
    if (want * 4 > head) writeSync(hornOut, pcm.slice(0, want * 4 - head));
    Atomics.store(ctl, c_played, (p + want) | 0); } };
if (hornFile) { Atomics.store(ctl, c_live, 1); setInterval(hornDrain, 5).unref(); }
// --deaf: a speaker that says it is there and then takes nothing, which is what a worklet
// the browser collected -- or one whose process threw, and so is never called again --
// looks like from the machine's side. the machine has to outlive it (cpu.mjs's horn_deaf).
else if (deaf) Atomics.store(ctl, c_live, 1);

const cpu = new Worker(new URL('./cpu.mjs', import.meta.url));
const leave = (code) => { if (process.stdin.isTTY) process.stdin.setRawMode(false); process.exit(code); };
cpu.on('message', (m) => {
  if (m.serial !== undefined) {
    process.stdout.write(m.serial);
    if (typeof after === 'string' && !pressed) {
      serialSeen = (serialSeen + m.serial).slice(-4096);
      if (serialSeen.includes(after)) pressAll(5000); } }
  else if (m.kexec !== undefined) {
    if (m.error) { process.stderr.write(`inle: kexec ${m.kexec}: errno ${m.error}\n`); process.exitCode = 1; }
    else process.stderr.write(`inle: booting ${m.kexec} -- ${m.cmd}\n`); }
  else if (m.lift !== undefined) {
    if (m.error) { process.stderr.write(`inle: lift ${m.lift}: errno ${m.error}\n`); process.exitCode = 1; }
    else {
      // asked for by --lift it goes where that said; asked for aboard, beside the runner
      const to = liftReq ? liftReq.to : (m.lift.split('/').pop() || 'lift');
      writeFileSync(to, m.bytes); process.stderr.write(`inle: ${m.lift} -> ${to} (${m.bytes.length} bytes)\n`); } }
  else if (m.reset) { if (!m.into) leave(process.exitCode ?? 0); }   // a kexec's reset boots on
  else if (m.fault) { process.stderr.write('\ninle: ' + m.fault + '\n'); leave(1); } });
cpu.on('error', (e) => { process.stderr.write('\ninle: ' + e + '\n'); leave(1); });
// the boot line is one string the kernel splits quote-aware (kmain's bootargv), so a
// word with a space in it is quoted back the way a shell had it
const word = (a) => !/[\s"']/.test(a) ? a : !a.includes('"') ? '"' + a + '"' : "'" + a + "'";
cpu.postMessage({ wasm: readFileSync(wasm), ring, ram: Number(process.env.INLE_RAM ?? 256),
                  cmd: cmd.map(word).join(' '), fb, image, origin });

// the presses: a make, the break 60 ms behind it, the next key 300 ms on -- from --after's
// second, or five seconds after its text shows on the serial line
let pressed = false, serialSeen = '';
const pressAll = (delay) => {
  if (pressed) return;
  pressed = true;
  const send = scanlane(ring, ctl, { scan_at, scan_n, c_sh, c_st });
  press.forEach((k, i) => {
    setTimeout(() => send(k, 0), delay + i * 300).unref();
    setTimeout(() => send(k, 1), delay + i * 300 + 60).unref(); }); };
if (press.length) {
  for (const k of press) if (!(k in codes)) { console.error('inle.mjs: --press: no key ' + k); process.exit(2); }
  if (typeof after === 'number') pressAll(after * 1000); }
if (forS) setTimeout(() => { process.stderr.write('inle: the machine outran --for\n'); leave(124); }, forS * 1000).unref();

if (process.stdin.isTTY) process.stdin.setRawMode(true);
process.stdin.on('data', (d) => { if (process.stdin.isTTY && d.includes(29)) leave(0); push(d); });
process.stdin.on('end', () => { });                      // a pipe's end is not the machine's
