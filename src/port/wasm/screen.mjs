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
const ev = M.cwrap('ai_eval', 'number', ['string']);
const drain = () => M.UTF8ToString(M.ccall('ai_out_ptr', 'number', [], []), M.ccall('ai_out_len', 'number', [], []));
const mirror = M.cwrap('ai_mirror', 'number', []);
const palette = M.cwrap('ai_palette', 'number', []);
const unfold = M.cwrap('ai_unfold', 'number', ['number']);
const view = () => { const p = mirror() >> 2, h = M.HEAPU32.subarray(p, p + 4);
                     return { hdr: Array.from(h), cells: M.HEAPU32.subarray(p + 4, p + 4 + h[0] * h[1]) }; };
const face = cellsFace(M.HEAPU32.subarray(palette() >> 2, (palette() >> 2) + 256), unfold);

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

// --- the apps, through web.l, on a page-sized screen ---
evs(src('src/apps/rove/rove.l')); evs(src('src/apps/ink/ink.l')); evs(src('src/port/wasm/web.l'));
evs('(puts (rove-web-boot 80 24 7))');
{
  const { hdr, cells } = view();
  ok(hdr[0] === 24 && hdr[1] === 80, `rove screen ${hdr[0]}x${hdr[1]}`);
  const row = r => Array.from(cells.subarray(r * 80, r * 80 + 80), c => face.glyph[c & 255]).join('');
  ok(row(0).trim() === '', 'row 0 is the message line, blank at boot: ' + JSON.stringify(row(0).trim()));
  ok(Array.from({ length: 22 }, (_, r) => row(r + 1)).join('').trim().length > 40, 'the deck rows carry glyphs');
  ok(row(23).startsWith('deck 1/'), 'row 23 is the bar: ' + JSON.stringify(row(23).trim()));
  ok(cellsHtml(face, hdr, cells).split('\n').length === 24, 'rove lays 24 rows');
}
ok(evs('(puts (rove-web-key 108))') === '', 'a step mirrors and says nothing');
ok(evs('(puts (rove-web-key 113))') === '\x1b_quit\x1b\\', 'q answers the quit sentinel');
evs('(puts (ink-web-boot 40 12 3))'); evs('(puts (ink-web-tick ()))');
{
  const { hdr } = view();
  ok(hdr[0] === 12 && hdr[1] === 40, `ink screen ${hdr[0]}x${hdr[1]}`);
}

if (fails) { console.error(`WASM SCREEN FAILED (${fails})`); process.exit(1); }
console.log('  screen: ok -- the mirror, the face, the lay, rove and ink on the page screen');
