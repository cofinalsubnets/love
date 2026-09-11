// i/wasm/glass.mjs -- a canvas as REAL pixels, for the two pages that carry a machine.
// the backing store is the element's own box times the device ratio, so the browser
// resamples nothing and every glyph pixel is a whole screen pixel; the zoom says how many
// of those a glyph pixel gets. the machine is handed both and settles rows and columns
// itself (i/wasm/arch.c's k_start, then kmain's fbscale and cbinit) -- which is why
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

// the RESERVATION: the most this canvas can ever be, which is the screen it sits on. the
// paper is carved at it once, at boot, and the heap gets what is under it, so a later
// resize lands inside memory the kernel was never given. it is a whole-screen box because
// that is the largest layout any reflow can arrive at, and it is settled here because the
// screen is the reader's and not the kernel's.
const reservation = (r) => Math.min(pixel_cap,
  Math.round(screen.width * r) * Math.round(screen.height * r));

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
  const cap = reservation(r);
  while (r > 1 && w * h * r * r > cap) r--;
  // 1..8 is the kernel's own range for a glyph scale (kmain's fbscale, and what
  // k_fb_reseat will take): past it a huge screen would be refused outright
  const scale = Math.min(8, Math.max(1, Math.floor(w / (8 * n))) * r);
  return { w: w * r, h: h * r, scale, cap }; }
