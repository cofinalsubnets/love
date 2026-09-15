// test/gate/glass.mjs -- the page's half of the console's grid, asked without a page.
// inle/wasm/glass.mjs turns a canvas box into real pixels and the zoom a glyph pixel gets,
// and no lane here has a browser, so the three globals it reads are stubbed and the law
// is checked as arithmetic: the machine divides the pixels it is handed by the face times
// the zoom (kmain's cbinit), so the columns are settled HERE and read back the same way.
// what is asked is the cap -- the box a glyph short of the next zoom is the one that used
// to carry twice the columns at half the size.
// usage: node test/gate/glass.mjs
import { glass } from '../../inle/wasm/glass.mjs';

const face = 8;                                  // cga_8x8's width, what cbinit divides by
globalThis.screen = { width: 2560, height: 1440 };
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
    const g = grid(w, Math.round(w * 0.6), r, 80);
    if (g.cols > worst) worst = g.cols;
    if (!g.cols || !g.rows) none++;
    if (g.scale < 1 || g.scale > 8) none++; }
  law(worst <= 80, `at ratio ${r} no box carries more than 80 columns (widest ${worst})`);
  law(!none, `at ratio ${r} every box has a grid, at a zoom the kernel will take`); }

// ..and the cap is the one asked for, not 80 baked in
law(grid(1600, 900, 1, 40).cols <= 40, 'a narrower cap is narrower');
law(grid(1600, 900, 1, 120).cols <= 120, '..and a wider one wider');
law(grid(1600, 900, 1, 0).cols <= 80, 'a query string that is not a number falls back to 80');

// a wide box gets BIGGER text rather than more of it: the zoom climbs with the pixels
const zooms = [640, 1280, 2560].map((w) => grid(w, 400, 1, 80).scale);
law(zooms[0] <= zooms[1] && zooms[1] <= zooms[2], 'the zoom climbs with the box, never falls');

// the canvas never outgrows the box it was laid in, whatever the ratio asks for
for (const r of [1, 2, 3]) {
  const g = grid(1024, 640, r, 80);
  law(g.w <= 1024 * r && g.h <= 640 * r, `at ratio ${r} the pixels stay inside the box`); }

console.log(bad ? `FAIL glass: ${bad} of the grid's laws` : '  glass: ok -- inle/wasm/glass.mjs without a page');
process.exitCode = bad ? 1 : 0;
