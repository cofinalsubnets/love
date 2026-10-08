// test/gate/glass.mjs -- the page's half of the console's grid, asked without a page.
// src/inle/wasm/machine.js's glass turns a canvas box into real pixels and the scale a glyph pixel gets,
// and no lane here has a browser, so the two globals it reads are stubbed and the law
// is checked as arithmetic: the machine divides the pixels it is handed by the face times
// the scale (kmain's cbinit), so the columns are settled HERE and read back the same way.
// what is asked is the cap -- the box a glyph short of the next scale is the one that used
// to carry twice the columns at half the size.
// ..and the bytes a hardware key sends, the same way: keybytes on a made-up event.
// usage: node test/gate/glass.mjs
import { glass, keybytes, cols_n } from '../../src/inle/wasm/machine.js';

const face = 8;                                  // cga_8x8's width, what cbinit divides by
const canvas = (w, h) => ({ getBoundingClientRect: () => ({ width: w, height: h }) });

let bad = 0;
const law = (ok, m) => { if (ok) console.log('  ' + m); else bad++, console.log('FAIL glass: ' + m); };
const grid = (w, h, r, cols) => {
  globalThis.window = { devicePixelRatio: r };
  const g = glass(canvas(w, h), cols);
  return { ...g, cols: Math.floor(g.w / (face * g.scale)), rows: Math.floor(g.h / (face * g.scale)) }; };

// the sweep: every box from a phone to a wall, at both the ratios a screen comes at
const boxes = [320, 480, 640, 700, 900, 1024, 1279, 1280, 1281, 1600, 1920, 2560, 3840];
for (const r of [1, 2]) {
  let worst = 0, none = 0;
  for (const w of boxes) {
    const g = grid(w, Math.round(w * 0.6), r, cols_n);
    if (g.cols > worst) worst = g.cols;
    if (!g.cols || !g.rows) none++;
    if (g.scale < 1 || g.scale > 8) none++; }
  law(worst <= cols_n, `at ratio ${r} no box carries more than ${cols_n} columns (widest ${worst})`);
  law(!none, `at ratio ${r} every box has a grid, at a scale the kernel will take`); }

// ..and the cap is the one asked for, not 80 baked in
law(grid(1600, 900, 1, 40).cols <= 40, 'a narrower cap is narrower');
law(grid(1600, 900, 1, 200).cols <= 200, '..and a wider one wider');
law(grid(1600, 900, 1, 0).cols <= cols_n, 'a query string that is not a number falls back to the default');

// a desktop monitor's box opens at scale 2 under the default cap
law([1300, 1600, 1900, 1920].every((w) => grid(w, 1000, 1, cols_n).scale === 2), 'a desktop box opens at scale 2');

// a box past the reservation asks for the most it holds, in its own shape, and is never refused
const huge = (() => { globalThis.window = { devicePixelRatio: 1 }; return glass(canvas(5120, 2880), cols_n); })();
law(huge.w * huge.h <= huge.cap && Math.abs(huge.w / huge.h - 16 / 9) < 0.01, 'a box past the reservation keeps its shape inside it');

// a scale picked by hand is taken as it stands, in CSS pixels, whatever the cap would give
const picked = (w, r, z) => { globalThis.window = { devicePixelRatio: r }; return glass(canvas(w, 1000), cols_n, 0, z).scale; };
law(picked(1920, 1, 1) === 1 && picked(400, 2, 1) === 2 && picked(640, 1, 3) === 3, 'a picked scale wins over the cap');
law(picked(1920, 2, 8) === 8, '..and stays inside the kernel\'s range');

// a wide box gets BIGGER text rather than more of it: the scale climbs with the pixels
const scales = [640, 1280, 2560].map((w) => grid(w, 400, 1, 80).scale);
law(scales[0] <= scales[1] && scales[1] <= scales[2], 'the scale climbs with the box, never falls');

// the canvas never outgrows the box it was laid in, whatever the ratio asks for
for (const r of [1, 2, 3]) {
  const g = grid(1024, 640, r, 80);
  law(g.w <= 1024 * r && g.h <= 640 * r, `at ratio ${r} the pixels stay inside the box`); }

// the keys: a character is its bytes, shift is whatever character the keymap made of it,
// ctrl with a letter the control byte, alt an escape before the character -- and the same
// escape before a shifted one, so both together reach the guest as one key -- while meta
// is nothing and an arrow is its own sequence under any modifier
const key = (k, m = {}) => ({ key: k, ctrlKey: false, metaKey: false, altKey: false, ...m });
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
law(same(keybytes(key('1')), [49]), 'a digit is its byte');
law(same(keybytes(key('!')), [33]), 'shift is the character the keymap made');
law(same(keybytes(key('a', { ctrlKey: true })), [1]), 'ctrl with a letter is the control byte');
law(same(keybytes(key('1', { altKey: true })), [27, 49]), 'alt is an escape before the key');
law(same(keybytes(key('!', { altKey: true })), [27, 33]), 'alt and shift together, one escape');
law(keybytes(key('1', { metaKey: true })) === null, 'meta is nothing');
law(same(keybytes(key('ArrowUp', { altKey: true })), [27, 91, 65]), 'an arrow is its sequence under alt too');
law(keybytes(key('Shift')) === null, 'a modifier alone is nothing');

console.log(bad ? `FAIL glass: ${bad} of the grid's laws` : '  glass: ok -- the glass of src/inle/wasm/machine.js without a page');
process.exitCode = bad ? 1 : 0;
