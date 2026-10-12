// test/gate/ppmcolor.mjs -- whether every pixel of a PPM (P6) is the one colour named.
// usage: node test/gate/ppmcolor.mjs FILE R,G,B
import { readFileSync } from 'node:fs';

const [file, want] = process.argv.slice(2);
const b = readFileSync(file), [r, g, bl] = want.split(',').map(Number);
const m = /^P6\s+(\d+)\s+(\d+)\s+255\s/.exec(b.subarray(0, 64).toString('latin1'));
if (!m) { console.log('ppmcolor: ' + file + ' is no P6'); process.exit(1); }
const n = Number(m[1]) * Number(m[2]), o = m[0].length;
let off = 0;
for (let i = 0; i < n; i++) if (b[o + 3 * i] !== r || b[o + 3 * i + 1] !== g || b[o + 3 * i + 2] !== bl) off++;
if (off) { console.log(`ppmcolor: ${off} of ${n} pixels are not ${want}`); process.exit(1); }
