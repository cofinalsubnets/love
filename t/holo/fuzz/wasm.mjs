// the other half of t/holo/fuzz/wasm.l: instantiate what love laid and hold every export
// to the model's answer. v8 is the second opinion -- its decoder rejects a malformed module
// outright, and its engine disagrees with a wrong immediate.
// usage: node t/holo/fuzz/wasm.mjs [b/.wasmfuzz.wasm] [b/.wasmfuzz.json]
import { readFileSync } from 'node:fs';

const wasm = process.argv[2] ?? 'b/.wasmfuzz.wasm';
const spec = JSON.parse(readFileSync(process.argv[3] ?? 'b/.wasmfuzz.json', 'utf8'));

const bytes = readFileSync(wasm);
if (!WebAssembly.validate(bytes)) {
  console.log('FAIL the engine refuses the module outright -- the encoder laid something malformed');
  process.exit(1);
}
const { instance } = await WebAssembly.instantiate(bytes, {});

let pass = 0, fail = 0;
for (const t of spec) {
  const f = instance.exports[t.name];
  if (typeof f !== 'function') { fail++; console.log(`FAIL ${t.name}: not exported`); continue; }
  let got;
  try { got = f(BigInt(t.arg)); }
  catch (e) { fail++; console.log(`FAIL ${t.name}(${t.arg}) trapped: ${e.message}`); continue; }
  if (got === BigInt(t.want)) pass++;
  // a run of failures is one bug; the first few name it, the tally sizes it
  else { fail++; if (fail <= 8) console.log(`FAIL ${t.name}(${t.arg}) = ${got}, want ${t.want}`); }
}
console.log(`wasmfuzz: ${pass} pass, ${fail} fail`);
process.exit(fail ? 1 : 0);
