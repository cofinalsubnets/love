// test/gate/grab.mjs -- a window's grab of the pointer, asked without a page. this side stands
// where machine.js does: test/kernel/wingrab.l grabs, the worker says { hold: 1 }, and the
// page's locked pointer sends motions (how 3) the kernel steps its own pointer by, from the
// paper's middle; a warp puts it at 10 10, and plain moves step it from there; letting go
// says { hold: 0 }. what the window heard comes back on the serial line.
// usage: node test/gate/grab.mjs MODULE IMAGE [LOG]
import { Worker } from 'node:worker_threads';
import { readFileSync, writeFileSync } from 'node:fs';
import { ctl_n, shared_n } from '../../src/inle/wasm/cpu.mjs';
import { pointlane } from '../../src/inle/wasm/machine.js';

const [wasm, image, log] = process.argv.slice(2);
const nap = (ms) => new Promise((r) => setTimeout(r, ms));
const ring = new SharedArrayBuffer(shared_n);
const ctl = new Int32Array(ring, 0, ctl_n), point = pointlane(ring, ctl);
const motion = (dx, dy) => point(3, 3, dy & 0xffff, dx & 0xffff);

let said = '';
const holds = [];
const cpu = new Worker(new URL('../../src/inle/wasm/cpu.mjs', import.meta.url));
cpu.on('message', (m) => {
  if (m.serial !== undefined) said += m.serial;
  else if (m.hold !== undefined) holds.push(m.hold);
  else if (m.fault) said += '\nfault: ' + m.fault; });
const img = readFileSync(image);
cpu.postMessage({ wasm: readFileSync(wasm), ring, ram: 256, cmd: 'test/kernel/wingrab.l',
                  fb: { w: 640, h: 400, scale: 1 }, image: img.buffer.slice(img.byteOffset, img.byteOffset + img.length) });

const until = async (f, ms) => { for (let t = 0; t < ms && !f(); t += 50) await nap(50); return f(); };
let bad = 0;
const check = (ok, what) => { if (!ok) bad++, console.log('FAIL grab: ' + what); };
const heard = (s) => said.includes('wingrab: ' + s);

check(await until(() => heard('grabbed 1 on 640x400'), 20000), 'the window grabbed the pointer');
check(await until(() => holds[0] === 1, 3000), 'the page was told to lock');
motion(5, -3);
check(await until(() => heard('(move 325 197)'), 3000), 'a motion moves from the middle');
await nap(100);
motion(-1000, 4), motion(2, 0);                          // ..unread, the second over the first
check(await until(() => heard('(move 2 201)'), 3000), 'motions kept on the paper, unread moves as one');
check(!heard('(move 0 201)'), 'an unread move is overwritten, not queued');
point(0, 0, 50, 50), point(1, 0, 50, 50);
check(await until(() => heard('(press 1 2 201)') && heard('(release 1 2 201)'), 3000), 'a click where the grabbed pointer is');
check(await until(() => heard('warped 1'), 3000), 'the warp');
point(2, 3, 50, 50);
check(await until(() => heard('(move 10 10)'), 3000), "a plain move after motions starts where it is");
await nap(100);
point(2, 3, 60, 57);
check(await until(() => heard('(move 17 20)'), 3000), "a plain move steps by the real pointer's step");
point(0, 0, 60, 57), point(1, 0, 60, 57);
check(await until(() => heard('let go 1'), 3000), 'let go');
check(await until(() => holds[1] === 0, 3000), 'the page was told to unlock');

await cpu.terminate();
if (log) writeFileSync(log, said);
if (bad) { console.log(said.slice(-1500)); process.exit(1); }
console.log('  grab: ok -- the lock asked and given back; motions, a warp and steps on the grabbed pointer');
