// port/wasm/cells.js -- a quay screen as html: the page's painter, the pure half.
// the wasm build mirrors a screen (host.c's `mirror`: rows, cols, cursor, flag, then
// the packed cells, quay.h's layout) and this lays it as text -- one span per run of
// like-penned cells, rows joined by newlines -- in the quay face the sheet sets. the
// colours are the same xterm256 table core/quay/paint.c spends and the glyphs the
// same unfold, read out of the module once, so a cell means the same pixels on inle's
// framebuffer and on the page. no DOM here: node lays the same frame in the gate.

// the face: the palette (256 xrgb words, ai_palette) as css, and every cp437 byte as
// the string it shows (ai_unfold), both looked up per run rather than computed
function cellsFace(pal, unfold) {
  const css = new Array(256), glyph = new Array(256);
  for (let i = 0; i < 256; i++) {
    const v = pal[i];
    css[i] = `rgb(${v >> 16 & 255},${v >> 8 & 255},${v & 255})`;
    // berth's rule (apps/berth/limn.l): ascii as itself, else the unfold, else '?';
    // and the empty cell is a space
    const cp = i === 0 ? 32 : (i >= 32 && i < 127) ? i : unfold(i);
    glyph[i] = String.fromCodePoint(cp > 0 ? cp : 63);
  }
  return { css, glyph };
}

const cellsEsc = s => s.replace(/[&<>]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));

// a pen (the cell's high 24 bits) as a style, paint.c's reading: bold is the bright half
// of the first eight, reverse swaps, underline is the last scanline
function cellsStyle(face, pen) {
  let fg = pen & 255, bg = pen >> 8 & 255;
  const fa = pen >> 20 & 15;
  if (fa & 1 && fg < 8) fg += 8;
  if (fa & 4) { const t = fg; fg = bg; bg = t; }
  return `color:${face.css[fg]};background:${face.css[bg]}` + (fa & 2 ? ';text-decoration:underline' : '');
}

// the lay. hdr is the mirror's head [rows cols cur flag]; cells the rows*cols words
// after it. the cursor wears the reverse face when the screen shows one (flag bit 0).
function cellsHtml(face, hdr, cells) {
  const [rows, cols, cur, flag] = hdr;
  let out = '';
  for (let r = 0; r < rows; r++) {
    let pen = -1, buf = '';
    const flush = () => { if (buf) out += `<span style="${cellsStyle(face, pen)}">${cellsEsc(buf)}</span>`; buf = ''; };
    for (let c = 0; c < cols; c++) {
      const i = r * cols + c;
      let cell = cells[i];
      if (flag & 1 && i === cur) cell ^= 4 << 28;
      const p = cell >>> 8;
      if (p !== pen) { flush(); pen = p; }
      buf += face.glyph[cell & 255];
    }
    flush();
    if (r + 1 < rows) out += '\n';
  }
  return out;
}

if (typeof module !== 'undefined') module.exports = { cellsFace, cellsHtml };
