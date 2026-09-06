// the console seam's gate: a frame scribed into quay's screen, mirrored out of the wasm
// build, and laid by cells.js -- the same cells inle's painter would put on a
// framebuffer, checked here as cells and as html. and the real apps: rove and ink boot
// on a page-sized screen through web.l, the way repl.js drives them.
//
// Usage: node src/port/wasm/screen.mjs [--love <love.js>]
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { createRequire } from 'node:module';

const argv = process.argv.slice(2);
let mod = new URL('../../../out/wasm/love.js', import.meta.url).href;
if (argv[0] === '--love') mod = pathToFileURL(argv[1]).href;
const here = new URL('.', import.meta.url);
const tree = new URL('../../../', import.meta.url);
const { cellsFace, cellsHtml } = createRequire(import.meta.url)(new URL('cells.js', here).pathname);

const { default: Love } = await import(mod);
const M = await Love();
if (M.ccall('ai_init', 'number', [], []) !== 0) { console.error('ai_init failed'); process.exit(1); }
const evp = M.cwrap('ai_eval', 'number', ['number']);   // through the heap: a 'string' rides the wasm stack
const ev = s => { const n = M.lengthBytesUTF8(s) + 1, p = M._malloc(n); M.stringToUTF8(s, p, n); const r = evp(p); M._free(p); return r; };
const drain = () => M.UTF8ToString(M.ccall('ai_out_ptr', 'number', [], []), M.ccall('ai_out_len', 'number', [], []));
const mirror = M.cwrap('ai_mirror', 'number', []);
const palette = M.cwrap('ai_palette', 'number', []);
const unfold = M.cwrap('ai_unfold', 'number', ['number']);
const view = () => { const p = mirror() >> 2, h = M.HEAPU32.subarray(p, p + 4);
                     return { hdr: Array.from(h), cells: M.HEAPU32.subarray(p + 4, p + 4 + h[0] * h[1]) }; };
const face = cellsFace(M.HEAPU32.subarray(palette() >> 2, (palette() >> 2) + 256), unfold);

// the session's help, as repl.js installs it: a condition prints ";; a b" and answers (),
// in the app tasks too (a task inherits its parent's help) -- without one a scare in an
// app is not the app's end but a runaway
ev('(hear (\\ a b (: _ (puts ";; ") _ (putx a) _ (puts " ") _ (putx b) _ (putc 10) ())))'); drain();
let fails = 0;
const ok = (c, what) => { if (!c) { fails++; console.error('  FAIL: ' + what); } };
const src = f => readFileSync(new URL(f, tree), 'utf8');
const evs = s => { const st = ev(s); ok(st === 0, `eval ${JSON.stringify(s.slice(0, 40))} -> ${st}: ${drain().trim()}`); return drain(); };

// --- the palette and the glyphs are the engine's tables, not a second recipe ---
ok(face.css[0] === 'rgb(0,0,0)' && face.css[9] === 'rgb(255,0,0)' && face.css[196] === 'rgb(255,0,0)'
   && face.css[232] === 'rgb(8,8,8)' && face.css[255] === 'rgb(238,238,238)', 'xterm256 corners');
ok(face.glyph[3] === '♥' && face.glyph[0xb3] === '│' && face.glyph[0] === ' ' && face.glyph[65] === 'A', 'cp437 unfold');

// --- a hand frame: two pens, a home, an erase, the cursor hidden ---
evs('(: s (screen (cask (screen () 3 8)) 3 8))');
evs('(scribe s "\\e[?25l\\e[H\\e[38;5;196mab\\e[0m\\e[Kcd\\r\\n\\e[48;5;21;1m│\\e[0m")');   // the box glyph as utf-8: the fold lands it on cp437 0xb3
ok(evs('(puts (show (mirror s)))').trim() === '24', 'mirror answers the cell count');
{
  const { hdr, cells } = view();
  ok(hdr[0] === 3 && hdr[1] === 8, `head rows/cols ${hdr}`);
  ok(!(hdr[3] & 1), 'cursor hidden (DECTCEM off)');
  ok((cells[0] & 255) === 97 && (cells[0] >> 8 & 255) === 196, 'cell 0: a in 196');
  ok((cells[2] & 255) === 99 && (cells[2] >> 8 & 255) === 7 && (cells[2] >> 16 & 255) === 0, 'cell 2: c in the reset pen');
  ok((cells[8] & 255) === 0xb3 && (cells[8] >> 16 & 255) === 21 && (cells[8] >> 28 & 1) === 1, 'row 1: a box glyph, bg 21, bold');
  const html = cellsHtml(face, hdr, cells);
  const want = '<span style="color:rgb(255,0,0);background:rgb(0,0,0)">ab</span>'
             + '<span style="color:rgb(192,192,192);background:rgb(0,0,0)">cd    </span>\n'
             + '<span style="color:rgb(255,255,255);background:rgb(0,0,255)">│</span>'
             + '<span style="color:rgb(192,192,192);background:rgb(0,0,0)">       </span>\n'
             + '<span style="color:rgb(192,192,192);background:rgb(0,0,0)">        </span>';
  ok(html === want, 'the lay of the hand frame\n    got  ' + JSON.stringify(html) + '\n    want ' + JSON.stringify(want));
}

// --- the apps, through web.l, as tasks on a page-sized console ---
// a love string literal for a frame: " and \ and controls ride \xHH (as repl.js spells it)
const aiStr = t => '"' + Array.from(t, ch => { const o = ch.codePointAt(0);
  return ch === '"' || ch === '\\' || (o < 32 && ch !== '\n' && ch !== '\t') ? '\\x' + o.toString(16).padStart(2, '0')
       : ch === '\n' ? '\\n' : ch === '\t' ? '\\t' : ch; }).join('') + '"';
const key = b => M.ccall('ai_key', 'number', ['number'], [b]);
// one pump, repl.js's: the app's turn, its drawing scribed and mirrored, and whether it lives
const runnable = M.cwrap('ai_runnable', 'number', []), alive = M.cwrap('ai_alive', 'number', []);
const pump = () => { let acc = drain();
  for (let n = 0; n < 256 && acc.length < 65536; n++) { ev('(web-step)'); acc += drain(); if (!runnable()) break; }
  for (let k = 0; acc && k < 4; k++) { ev('(web-show ' + aiStr(acc) + ')'); acc = drain(); }
  return alive() === 1; };
const row = (r, cols) => { const { cells } = view(); return Array.from(cells.subarray(r * cols, r * cols + cols), c => face.glyph[c & 255]).join(''); };
evs(src('src/port/wasm/web.l')); evs(src('src/apps/rove/rove.l')); evs(src('src/apps/rove/story.l')); evs(src('src/apps/ink/ink.l'));   // the stubs first: a closure captures its globals at creation
ok(evs('(puts (show (rest 0)))').trim() !== '', 'a rest of nothing yields');
ev('(web-boot "rove" 80 24)');
ok(pump(), 'rove boots and lives');
{
  const { hdr } = view();
  ok(hdr[0] === 24 && hdr[1] === 80, `rove screen ${hdr[0]}x${hdr[1]}`);
  ok(row(0, 80).startsWith('the hold is dark'), 'row 0 is the message: ' + JSON.stringify(row(0, 80).trim()));
  ok(row(23, 80).startsWith('deck 1/'), 'row 23 is the bar: ' + JSON.stringify(row(23, 80).trim()));
}
key(108); ok(pump(), 'a key steps the crawl, and it lives');                      // l
key(27); key(91); key(65); ok(pump(), 'an arrow rides as its CSI bytes');          // up
// the helm rests a beat after an escape to let the sequence's tail land: sleeping is
// not runnable, so the page's next beat (50ms) finds it; here, wait it out
await new Promise(r => setTimeout(r, 5)); ok(pump(), 'the sequence lands on the next beat');
key(113); ok(!pump(), 'q: the runner steps ashore and the task lands');           // q
const beat = () => new Promise(r => setTimeout(r, 50));
ev('(web-boot "ink" 40 12)');
ok(pump(), 'ink boots and lives');
{ const { hdr } = view(); ok(hdr[0] === 12 && hdr[1] === 40, `ink screen ${hdr[0]}x${hdr[1]}`); }
await beat(); ok(pump(), 'ink rests a beat and swims on');
// a key lands while ink sleeps: sleeping is not runnable, so it is seen on the next beat
key(32); pump(); await beat(); ok(!pump(), 'any key: ink steps ashore on the next beat');

// the story: a line-driven app -- the typed line rides the key ring, enter turns it
ev('(web-boot "lighthouse" 60 12)');
ok(pump(), 'the lighthouse boots and lives');
{ const { hdr } = view(); ok(hdr[0] === 12 && hdr[1] === 60, `story screen ${hdr[0]}x${hdr[1]}`);
  ok(row(0, 60).startsWith('the lighthouse -- the lamp room'), 'the title bar: ' + JSON.stringify(row(0, 60).trim()));
  ok(row(11, 60).startsWith('> '), 'the prompt is the last row'); }
for (const c of 'down\r') key(c.charCodeAt(0));
ok(pump(), 'a typed line turns');
ok(row(0, 60).startsWith('the lighthouse -- the stair'), 'the line moved us: ' + JSON.stringify(row(0, 60).trim()));
for (const c of 'q\r') key(c.charCodeAt(0));
ok(!pump(), 'quit lands the story');

if (fails) { console.error(`WASM SCREEN FAILED (${fails})`); process.exit(1); }
console.log('  screen: ok -- the mirror, the face, the lay, and rove, ink and a story as tasks on the page console');
