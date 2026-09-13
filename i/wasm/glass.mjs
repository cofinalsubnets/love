// i/wasm/glass.mjs -- a canvas as REAL pixels, for the two pages that carry a machine.
// the backing store is the element's own box times a device ratio this file settles, and
// the zoom says how many of its pixels a glyph pixel gets. the ratio is held to what one
// frame is worth painting (frame_cap): past that the compositor does the last integer
// doubling, which is the same grid and costs the machine nothing. the machine is handed
// the size and the zoom and settles rows and columns itself (i/wasm/arch.c's k_start,
// then kmain's fbscale and cbinit) -- which is why
// nothing here mentions a font size or an aspect ratio, and why a page cannot pick a
// shape the console then has to live inside.
//
// nothing here pins the box: the element's own CSS lays it out and this only follows,
// which is what lets a page re-measure on a reflow and hand the machine the new size.

// how many pixels the machine may have -- 32 MiB of framebuffer, which covers a retina
// 1440p canvas and a plain 4K one. a dense screen at full ratio can ask for more than the
// RAM the worker grows (cpu.mjs's `ram`, 256 MiB by default) wants to spare, and a frame
// is that many bytes to swizzle each time one goes out; the ratio is what gives, the
// layout being the reader's.
const pixel_cap = 8 << 20;

// ..and how many one FRAME is worth, which is a different question and a smaller number.
// every pixel above this is swizzled and handed over on the machine's own thread
// (cpu.mjs's blit), so a dense screen spends the guest's time on pixels instead of on the
// guest -- and on a floor that repaints whether or not you touch it, that is the guest's
// sound going with it. a console's glyphs are integer-scaled bitmaps and the canvas is
// `image-rendering: pixelated`, so halving the ratio and doubling the scale to match is
// THE SAME GRID, pixel for pixel: the compositor does the last doubling, for free and on
// the GPU, instead of the worker doing it per pixel in a loop.
const frame_cap = 2 << 20;

// the RESERVATION: the most this canvas can ever be, which is the screen it sits on. the
// paper is carved at it once, at boot, and the heap gets what is under it, so a later
// resize lands inside memory the kernel was never given. it is a whole-screen box because
// that is the largest layout any reflow can arrive at, and it is settled here because the
// screen is the reader's and not the kernel's.
const reservation = (r) => Math.min(pixel_cap,
  Math.round(screen.width * r) * Math.round(screen.height * r));

// `cols` is the MOST columns worth reading: the zoom is the smallest that keeps the grid
// inside it, so a wide box gets bigger text rather than more of it. a cap and not a floor
// -- a box one glyph short of the next zoom would otherwise carry twice the columns asked
// for at half the size, which is the reading kmain's fbscale gives and a page can better,
// the pixels being the part a page knows and the kernel does not. /proc/vt/scale retunes
// it aboard, so this is the opening zoom and not a ceiling on one.
export function glass(canvas, cols = 80) {
  const n = cols > 0 ? cols : 80;             // a query string's nonsense falls back, never NaN
  const box = canvas.getBoundingClientRect();
  // the floor is a floor and not the column target: a narrow screen gets FEWER columns,
  // never a canvas wider than the box it was laid in
  const w = Math.max(64, Math.round(box.width)), h = Math.max(16, Math.round(box.height));
  let r = Math.max(1, Math.round(window.devicePixelRatio || 1));
  const cap = reservation(r);
  while (r > 1 && w * h * r * r > Math.min(cap, frame_cap)) r--;
  // 1..8 is the kernel's own range for a glyph scale (kmain's fbscale, and what
  // k_fb_reseat will take): past it a huge screen would be refused outright
  const scale = Math.min(8, Math.max(1, Math.ceil(w / (8 * n))) * r);
  return { w: w * r, h: h * r, scale, cap }; }
