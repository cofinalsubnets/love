// test/gate/point.mjs -- the page's pointer and clipboard, asked without a page.
// the machine boots a shell on a framebuffer console, and this side stands where the page
// would: its pointer events go down the pointer lane as machine.js's pointlane lays them,
// its pastes down the paste lane, and what the console copies comes back as { copy }.
// a drag selects a word, a double click another, a triple the line; a paste reaches the
// shell with its control byte gone; the wheel moves the view a line-count the copy of
// row 0 then says; a program that asks for the mouse gets its report instead, and one
// that asks for bracketed paste gets the paste bracketed -- both read back through od.
// usage: node test/gate/point.mjs MODULE IMAGE [LOG]
import { Worker } from 'node:worker_threads';
import { readFileSync, writeFileSync } from 'node:fs';
import { ctl_n, ring_n, ring_at, shared_n } from '../../inle/wasm/cpu.mjs';
import { pointlane, pastelane } from '../../inle/wasm/machine.js';

const [wasm, image, log] = process.argv.slice(2);
const nap = (ms) => new Promise((r) => setTimeout(r, ms));
const ring = new SharedArrayBuffer(shared_n);
const ctl = new Int32Array(ring, 0, ctl_n), kb = new Uint8Array(ring, ring_at, ring_n);
const type = (s) => {
  let tail = Atomics.load(ctl, 1);
  for (const b of new TextEncoder().encode(s)) { kb[tail] = b; tail = (tail + 1) % ring_n; }
  Atomics.store(ctl, 1, tail);
  Atomics.add(ctl, 2, 1); Atomics.notify(ctl, 2); };
const point = pointlane(ring, ctl), paste = pastelane(ring, ctl);

let said = '';
const copies = [];
const cpu = new Worker(new URL('../../inle/wasm/cpu.mjs', import.meta.url));
cpu.on('message', (m) => {
  if (m.serial !== undefined) said += m.serial;
  else if (m.copy !== undefined) copies.push(m.copy);
  else if (m.fault) said += '\nfault: ' + m.fault; });
const img = readFileSync(image);
cpu.postMessage({ wasm: readFileSync(wasm), ring, ram: 256, cmd: 'sh --login',
                  fb: { w: 800, h: 400, scale: 1 }, image: img.buffer.slice(img.byteOffset, img.byteOffset + img.length) });

const until = async (f, ms) => { for (let t = 0; t < ms && !f(); t += 50) await nap(50); return f(); };
let bad = 0;
const check = (ok, what) => { if (!ok) bad++, console.log('FAIL point: ' + what); };
const copy = async (clicks) => {                          // presses and releases, the copy they make
  const n = copies.length;
  for (const [how, b, row, col] of clicks) point(how, b, row, col);
  return (await until(() => copies.length > n, 3000)) ? copies[copies.length - 1] : null; };
const click = (row, col, n) => Array.from({ length: n }, () => [[0, 0, row, col], [1, 0, row, col]]).flat();

if (!await until(() => said.includes('$'), 15000)) { console.log('FAIL point: no prompt'); process.exit(1); }
await nap(800);
type("printf '\\033[2J\\033[3;1Hhello world\\033[6;1H'\r");
await nap(1500);
check((await copy([[0, 0, 2, 0], [2, 0, 2, 4], [1, 0, 2, 4]])) === 'hello', 'a drag across hello');
check((await copy(click(2, 7, 2))) === 'world', 'a double click on world');
check((await copy(click(2, 3, 3))) === 'hello world', 'a triple click on the line');

// a paste reaches the shell as typed, less its control byte
paste('echo pas\u0007ted\n');
check(await until(() => said.split(/\r?\n/).some((l) => l.trim() === 'pasted'), 5000), 'a paste into the shell');

// the wheel: forty numbered lines, and row 0's copy before and after one notch up
type('i=0; while [ $i -lt 40 ]; do echo L$i; i=$((i+1)); done\r');
await until(() => said.includes('L39'), 8000);
await nap(800);
const before = await copy(click(0, 1, 3));
point(0, 64, 5, 5);
await nap(300);
const after = await copy(click(0, 1, 3));
const num = (s) => Number((s ?? '').replace(/^L/, ''));
check(before !== null && after !== null && /^L\d+$/.test(before) && num(before) - num(after) === 3,
      `the wheel looks back three lines (row 0 read ${before}, then ${after})`);
point(0, 65, 5, 5);                                     // ..and home again

// a program that asked for the mouse gets the report, and one that asked for bracketed
// paste the bracket: both said back through od
type("printf '\\033[?1000h\\033[?1006h'; head -c 9 | od -c\r");
await nap(1200);
point(0, 0, 1, 2);
check(await until(() => /<\s+0\s+;\s+3\s+;\s+2\s+M/.test(said), 5000), 'the mouse report a program asked for');
type("printf '\\033[?1000l\\033[?1006l\\033[?2004h'; head -c 14 | od -c\r");
await nap(1200);
paste('x\n');
check(await until(() => /2\s+0\s+0\s+~\s+x\s+\\r\s+033\s+\[\s+2\s+0\s+1\s+~/.test(said), 5000), 'a bracketed paste');

await cpu.terminate();
if (log) writeFileSync(log, said);
if (bad) { console.log(said.slice(-1500)); process.exit(1); }
console.log('  point: ok -- a drag, a double and a triple click copied; a paste, the wheel, a report and a bracket');
