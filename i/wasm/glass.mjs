// i/wasm/glass.mjs -- a canvas as REAL pixels, for the two pages that carry a machine.
// the backing store is the element's own box times the device ratio, so the browser
// resamples nothing and every glyph pixel is a whole screen pixel; the zoom says how many
// of those a glyph pixel gets. the machine is handed both and settles rows and columns
// itself (i/wasm/arch.c's k_start, then kmain's fbscale and cbinit) -- which is why
// nothing here mentions a font size or an aspect ratio, and why a page cannot pick a
// shape the console then has to live inside.
//
// the box is PINNED to what it measured: the console's size is fixed at boot, so a canvas
// that kept reflowing would only end up showing its pixels at some other scale.

// how many pixels the machine may have -- 32 MiB of framebuffer, which covers a retina
// 1440p canvas and a plain 4K one. a dense screen at full ratio can ask for more than the
// RAM the worker grows (cpu.mjs's `ram`, 256 MiB by default) wants to spare, and a frame
// is that many bytes to swizzle each time one goes out; the ratio is what gives, the
// layout being the reader's.
const pixel_cap = 8 << 20;

// `cols` is the fewest columns worth reading: the zoom is the largest that still leaves
// that many, so a wide box gets bigger text rather than more of it. it is the same law
// kmain's fbscale runs when no door names a scale -- in the reader's pixels, which is
// the part a page knows and the kernel does not.
export function glass(canvas, cols = 80) {
  const n = cols > 0 ? cols : 80;             // a query string's nonsense falls back, never NaN
  const box = canvas.getBoundingClientRect();
  // the floor is a floor and not the column target: a narrow screen gets FEWER columns,
  // never a canvas wider than the box it was laid in
  const w = Math.max(64, Math.round(box.width)), h = Math.max(16, Math.round(box.height));
  let r = Math.max(1, Math.round(window.devicePixelRatio || 1));
  while (r > 1 && w * h * r * r > pixel_cap) r--;
  canvas.style.width = w + 'px';
  canvas.style.height = h + 'px';
  canvas.width = w * r;
  canvas.height = h * r;
  return { w: canvas.width, h: canvas.height, scale: Math.max(1, Math.floor(w / (8 * n))) * r }; }
