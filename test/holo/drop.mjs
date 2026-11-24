// test/holo/drop.mjs -- a module's function exports, and one ccall through the loader
// usage: node test/holo/drop.mjs MODULE          the function exports, sorted, one a line
//        node test/holo/drop.mjs MODULE NAME     ccall NAME: its answer, or the loader's refusal
import { readFile } from 'node:fs/promises';
import Love from '../../src/inle/wasm/loader.js';

const [path, name] = process.argv.slice(2);
if (!name) {
  const m = new WebAssembly.Module(await readFile(path));
  for (const e of WebAssembly.Module.exports(m).filter((e) => e.kind === 'function').map((e) => e.name).sort()) console.log(e); }
else {
  const M = await Love({ wasm: path, print: () => {} });
  try { console.log(String(M.ccall(name, 'number', [], []))); }
  catch (e) { console.log(e.message); } }
