// src/inle/wasm/nodedir.mjs -- a directory under node wearing the File System Access API's
// shape, the part hostfs.mjs asks of it: so node (inle.mjs --host DIR, the gate) runs the
// page's own worker over real files. a refusal is thrown with the DOMException name the
// browser gives the same miss. a writer writes in place, where a browser lays the bytes
// whole at the close; a run that only reads a file after its writer closed sees the same.
import { promises as fs } from 'node:fs';
import { join } from 'node:path';

const named = (name, msg) => Object.assign(new Error(msg), { name });
const miss = (e, p) => {
  if (e?.code === 'ENOENT') return named('NotFoundError', p);
  if (e?.code === 'ENOTDIR' || e?.code === 'EISDIR') return named('TypeMismatchError', p);
  if (e?.code === 'ENOTEMPTY') return named('InvalidModificationError', p);
  if (e?.code === 'EACCES' || e?.code === 'EPERM') return named('NotAllowedError', p);
  return e; };
const kindOf = async (p) => { try { return (await fs.stat(p)).isDirectory() ? 'directory' : 'file'; } catch (e) { throw miss(e, p); } };

class NodeFile {
  constructor(p, name) { this.p = p; this.name = name; this.kind = 'file'; }
  async getFile() {
    const p = this.p;
    let st;
    try { st = await fs.stat(p); } catch (e) { throw miss(e, p); }
    return { size: st.size, lastModified: Math.floor(st.mtimeMs),
             slice: (a, b) => ({ arrayBuffer: async () => {
               const h = await fs.open(p, 'r'), n = Math.max(0, Math.min(b, st.size) - a), buf = Buffer.alloc(n);
               try { if (n) await h.read(buf, 0, n, a); } finally { await h.close(); }
               return buf.buffer.slice(buf.byteOffset, buf.byteOffset + n); } }) }; }
  async createWritable({ keepExistingData = false } = {}) {
    const h = await fs.open(this.p, keepExistingData ? 'r+' : 'w');
    let at = 0;
    return {
      write: async (x) => {
        const w = x?.type === 'write' ? x : { position: at, data: x };
        const d = w.data instanceof ArrayBuffer ? new Uint8Array(w.data) : w.data.arrayBuffer ? new Uint8Array(await w.data.arrayBuffer()) : w.data;
        await h.write(d, 0, d.length, w.position ?? at);
        at = (w.position ?? at) + d.length; },
      truncate: (n) => h.truncate(n),
      close: () => h.close() }; }
  async move(d, name) {
    const to = join(d.p, name);
    try { await fs.rename(this.p, to); } catch (e) { throw miss(e, to); }
    this.p = to; this.name = name; } }

export class NodeDir {
  constructor(p, name = '') { this.p = p; this.name = name; this.kind = 'directory'; }
  async getDirectoryHandle(name, { create = false } = {}) {
    const p = join(this.p, name);
    try { if ((await kindOf(p)) !== 'directory') throw named('TypeMismatchError', p); }
    catch (e) {
      if (!(create && e?.name === 'NotFoundError')) throw e;
      try { await fs.mkdir(p); } catch (e2) { throw miss(e2, p); } }
    return new NodeDir(p, name); }
  async getFileHandle(name, { create = false } = {}) {
    const p = join(this.p, name);
    try { if ((await kindOf(p)) !== 'file') throw named('TypeMismatchError', p); }
    catch (e) {
      if (!(create && e?.name === 'NotFoundError')) throw e;
      try { await (await fs.open(p, 'a')).close(); } catch (e2) { throw miss(e2, p); } }
    return new NodeFile(p, name); }
  async removeEntry(name, { recursive = false } = {}) {
    const p = join(this.p, name);
    try { (await kindOf(p)) !== 'directory' ? await fs.unlink(p) : recursive ? await fs.rm(p, { recursive }) : await fs.rmdir(p); }
    catch (e) { throw miss(e, p); } }
  async *entries() {
    let ns;
    try { ns = await fs.readdir(this.p, { withFileTypes: true }); } catch (e) { throw miss(e, this.p); }
    for (const d of ns) yield [d.name, d.isDirectory() ? new NodeDir(join(this.p, d.name), d.name) : new NodeFile(join(this.p, d.name), d.name)]; }
  async *keys() { for await (const [n] of this.entries()) yield n; }
  async move(d, name) {
    const to = join(d.p, name);
    try { await fs.rename(this.p, to); } catch (e) { throw miss(e, to); }
    this.p = to; this.name = name; } }
