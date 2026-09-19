// test/gate/echo.mjs -- a keystroke reaches the GLASS, not just the guest.
// the console's bytes leave by the serial door before quay paints them, so a seat that
// takes the write for its cue hands the page a frame from just before the keystroke and
// then sits: the glyph rides out on the cursor's blink instead, two thirds of a second
// later. every other gate stays green through that -- the guest echoed, the bytes were
// right, the frames kept coming -- because only the PIXELS say when a key was shown.
// so: boot to a prompt, type one letter, and weigh the frames (inle.mjs's --frames) for
// the first one whose signature moves. the ceiling is the blink's own period: under it
// means the paint was what sent the frame, over it means the blink was.
// usage: node test/gate/echo.mjs MODULE IMAGE [LOG]
import { spawn } from 'node:child_process';
import { readFileSync, unlinkSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const [wasm, image, log] = process.argv.slice(2);
const seat = join(here, '..', '..', 'inle', 'wasm', 'inle.mjs');
const frames = (log ?? 'out/wasm/echo') + '.frames';
const nap = (ms) => new Promise((r) => setTimeout(r, ms));
const ceiling = 200;                   // ms; the paint answers in tens, the blink in ~650

const child = spawn(process.execPath,
  [seat, '--fb', '800x400', '--frames', frames, '--for', '12', '--image', image, wasm, 'sh', '--login'],
  { stdio: ['pipe', 'pipe', 'ignore'], env: { ...process.env, INLE_RAM: '256' } });

let said = '';
child.stdout.on('data', (b) => { said += b; });
for (let i = 0; i < 100 && !said.includes('$'); i++) await nap(100);   // the prompt
if (!said.includes('$')) { child.kill('SIGKILL'); console.log('FAIL echo: no prompt to type at'); process.exit(1); }
await nap(1500);                       // ..and let the screen settle, so the next change is ours

const sig = () => { const l = readFileSync(frames, 'utf8').trim().split('\n').filter(Boolean); return l.length ? l[l.length - 1].split(' ')[1] : null; };
const was = sig();
const typed = Date.now();
child.stdin.write('a');
await nap(1200);                       // well past the blink, so a late frame is still caught
child.kill('SIGKILL');

const rows = readFileSync(frames, 'utf8').trim().split('\n').filter(Boolean).map((r) => r.split(' '));
const shown = rows.find((r) => Number(r[0]) > typed && r[1] !== was);
try { unlinkSync(frames); } catch {}
if (!shown) { console.log('FAIL echo: the letter never reached a frame at all'); process.exit(1); }
const ms = Number(shown[0]) - typed;
const ok = ms < ceiling;
console.log(ok ? `  echo: ok -- the keystroke was on the glass in ${ms.toFixed(0)} ms`
               : `FAIL echo: the keystroke took ${ms.toFixed(0)} ms to reach the glass -- the frame went out before the paint, and the blink carried it`);
process.exit(ok ? 0 : 1);
