// bake.mjs -- the module's heap image: boot the egg once under node, read any cats into
// the base, and write the booted heap as bytes the page fetches beside the module
// (loader.js `wake`, host.c ai_wake). the image is anchored to the module that baked it:
// another build refuses it and boots the egg, so `make wasm` lays both together.
// usage: node bake.mjs --love love.wasm -o love.image [cat.l ...]
import { readFileSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const argv = process.argv.slice(2);
let wasm = null, out = null; const cats = [];
for (let i = 0; i < argv.length; i++)
  if (argv[i] === '--love') wasm = argv[++i];
  else if (argv[i] === '-o') out = argv[++i];
  else cats.push(argv[i]);
if (!wasm || !out) { console.error('usage: bake.mjs --love love.wasm -o love.image [cat.l ...]'); process.exit(2); }

const { default: Love } = await import(new URL('./loader.js', import.meta.url).href);
const m = await Love({ wasm: pathToFileURL(wasm) });
const t0 = performance.now();
const rc = m.ccall('ai_boot', 'number', [], []);
if (rc !== 0) { console.error(`ai_boot failed (code ${rc})`); process.exit(1); }
for (const f of cats) {                                  // through the heap: a cat overflows the wasm stack
  const src = readFileSync(f, 'utf8'), n = m.lengthBytesUTF8(src) + 1, p = m._malloc(n);
  m.stringToUTF8(src, p, n);
  m.ccall('ai_out_reset', 'null', [], []);
  const r = m.ccall('ai_eval', 'number', ['number'], [p]);
  m._free(p);
  const said = m.UTF8ToString(m.ccall('ai_out_ptr', 'number', [], []), m.ccall('ai_out_len', 'number', [], []));
  if (r !== 0) { console.error(`${f}: eval failed (code ${r})\n${said}`); process.exit(1); }
  if (said.trim()) console.error(said);                  // a cat says nothing at bake time; anything is news
}
const t1 = performance.now();
const ptr = m.ccall('ai_bake', 'number', [], []), len = m.ccall('ai_bake_len', 'number', [], []);
if (!ptr || !len) { console.error('the bake was refused'); process.exit(1); }
writeFileSync(out, new Uint8Array(m.memory.buffer, ptr, len));
console.log(`baked ${out}: ${len} bytes (boot ${(t1 - t0).toFixed(0)} ms, bake ${(performance.now() - t1).toFixed(0)} ms)`);
