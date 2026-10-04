// src/inle/wasm/hostfs.mjs -- the seat's own files: the worker that answers the kernel's
// /mnt/host (kmain's k_host, src/inle/wasm/arch.c's hc_host) out of a directory handle --
// a folder the reader picked (the File System Access API), the browser's private storage
// (navigator.storage.getDirectory, OPFS), or under node a directory through nodedir.mjs,
// which wears the same shape. the cpu worker never returns to its event loop, so it asks
// by message and then waits on a shared word: this worker does the asking's async work,
// lays the answer in the shared window, and wakes it.
//
//   the ring is hostring.mjs's.
//   in, on the port:  { op, path, path2, h, n, off, m, cap }   the kernel's ask
//   in, on its own:   { ring, port }                           the lanes, once
//                     { root }                                 a directory handle, or a
//                                                              path under node: the mount's
//                                                              new root; null for storage
//                     { put, bytes }                           a file the reader dropped or
//                                                              uploaded, laid at path put
//   out:              { put, error? }                          the drop landed, or why not
import { host_f64, host_at, host_win } from './hostring.mjs';
const E = { ENOENT: 2, EIO: 5, EBADF: 9, EACCES: 13, EBUSY: 16, EEXIST: 17, EXDEV: 18,
            ENOTDIR: 20, EISDIR: 21, EINVAL: 22, EFBIG: 27, ENOSPC: 28, ENOTEMPTY: 39, ENODEV: 19 };

// a DOMException's name as an errno, the nearest the browser says
const errno = (e) => -({ NotFoundError: E.ENOENT, TypeMismatchError: E.ENOTDIR,
                         InvalidModificationError: E.ENOTEMPTY, NotAllowedError: E.EACCES,
                         SecurityError: E.EACCES, NoModificationAllowedError: E.EBUSY,
                         QuotaExceededError: E.ENOSPC, InvalidStateError: E.EIO }[e?.name] ?? E.EIO);

let root = null;
const names = (p) => p.split('/').filter((s) => s);
// the directory a path's last name lies in, and that name
const parent = async (p) => {
  const ns = names(p);
  let d = root;
  for (const n of ns.slice(0, -1)) d = await d.getDirectoryHandle(n);
  return [d, ns[ns.length - 1]]; };
const dir = async (p) => { let d = root; for (const n of names(p)) d = await d.getDirectoryHandle(n); return d; };
// what lies at p: [kind, handle]; the mount's own root is a directory
const at = async (p) => {
  const [d, n] = await parent(p);
  if (n === undefined) return ['d', d];
  try { return ['f', await d.getFileHandle(n)]; }
  catch (e) { if (e?.name !== 'TypeMismatchError') throw e; }
  return ['d', await d.getDirectoryHandle(n)]; };

// an open file: a reader keeps the File it opened, a writer a writable stream -- or, where
// the browser has none (Safari's private storage), the sync access handle this worker may hold
let next = 1;
const files = new Map();
const open = async (p, m) => {
  const [d, n] = await parent(p);
  if (n === undefined) return -E.EISDIR;
  const make = m === 'w' || m === 'a' || m === 'c';
  let fh;
  try { fh = await d.getFileHandle(n, { create: make }); }
  catch (e) {
    if (e?.name !== 'TypeMismatchError') throw e;
    return -E.EISDIR; }
  const f = { fh, file: null, w: null, sync: null, size: 0 };
  if (m !== 'r') {
    f.size = m === 'w' ? 0 : (await fh.getFile()).size;
    if (fh.createWritable) f.w = await fh.createWritable({ keepExistingData: m !== 'w' });
    else if (fh.createSyncAccessHandle) { f.sync = await fh.createSyncAccessHandle(); if (m === 'w') f.sync.truncate(0); }
    else return -E.EACCES; }
  files.set(next, f);
  return next++; };
const file = async (f) => f.file ??= await f.fh.getFile();

const win = (ring) => new Uint8Array(ring, host_at, host_win);
const ops = {
  stat: async (q, ring, f64) => {
    const [k, h] = await at(q.path);
    if (k === 'd') { f64[1] = 0, f64[2] = 0, f64[3] = 0o40755; return 0; }
    const fl = await h.getFile();
    f64[1] = fl.size, f64[2] = fl.lastModified, f64[3] = 0o100644;
    return 0; },
  open: (q) => open(q.path, q.m),
  pread: async (q, ring) => {
    const f = files.get(q.h);
    if (!f) return -E.EBADF;
    if (f.sync) { const b = win(ring).subarray(0, q.n); return f.sync.read(b, { at: q.off }); }
    const fl = await file(f), b = new Uint8Array(await fl.slice(q.off, q.off + q.n).arrayBuffer());
    win(ring).set(b);
    return b.length; },
  pwrite: async (q, ring) => {
    const f = files.get(q.h);
    if (!f || !(f.w || f.sync)) return -E.EBADF;
    const b = win(ring).slice(0, q.n);
    if (f.sync) f.sync.write(b, { at: q.off });
    else await f.w.write({ type: 'write', position: q.off, data: b });
    f.size = Math.max(f.size, q.off + q.n);
    return q.n; },
  trunc: async (q) => {
    const f = files.get(q.h);
    if (!f || !(f.w || f.sync)) return -E.EBADF;
    if (f.sync) f.sync.truncate(q.n); else await f.w.truncate(q.n);
    f.size = q.n;
    return 0; },
  close: async (q) => {
    const f = files.get(q.h);
    if (!f) return -E.EBADF;
    files.delete(q.h);
    if (f.sync) { f.sync.flush(); f.sync.close(); }
    if (f.w) await f.w.close();                            // the bytes land here, whole
    return 0; },
  fstat: async (q, ring, f64) => {
    const f = files.get(q.h);
    if (!f) return -E.EBADF;
    f64[1] = f.w || f.sync ? (f.sync ? f.sync.getSize() : f.size) : (await file(f)).size;
    f64[2] = Date.now(), f64[3] = 0o100644;
    return 0; },
  // the listing, a kind byte, the name and a NUL each, sorted so it reads the same twice;
  // the room it wants back when the kernel's is short, which it then asks again with
  list: async (q, ring) => {
    const d = await dir(q.path), es = [];
    for await (const [n, h] of d.entries())                // a writer's swap file is chromium's own
      if (!n.endsWith('.crswap')) es.push((h.kind === 'directory' ? 'd' : 'f') + n + '\0');
    const b = new TextEncoder().encode(es.sort((x, y) => x.slice(1) < y.slice(1) ? -1 : 1).join(''));
    if (b.length > host_win) return -E.EFBIG;
    if (b.length <= q.cap) win(ring).set(b);
    return b.length; },
  mkdir: async (q) => {
    const [d, n] = await parent(q.path);
    if (n === undefined) return -E.EEXIST;
    try { await d.getFileHandle(n); return -E.EEXIST; } catch (e) { }
    try { await d.getDirectoryHandle(n); return -E.EEXIST; } catch (e) { }
    await d.getDirectoryHandle(n, { create: true });
    return 0; },
  rmdir: async (q) => {
    const [d, n] = await parent(q.path);
    if (n === undefined) return -E.EBUSY;
    const h = await d.getDirectoryHandle(n);
    for await (const _ of h.keys()) return -E.ENOTEMPTY;
    await d.removeEntry(n);
    return 0; },
  unlink: async (q) => {
    const [d, n] = await parent(q.path);
    if (n === undefined) return -E.EISDIR;
    try { await d.getFileHandle(n); }
    catch (e) { return e?.name === 'TypeMismatchError' ? -E.EISDIR : errno(e); }
    await d.removeEntry(n);
    return 0; },
  // a file lands on a file, replacing it, as rename(2) has it; a directory only where
  // nothing is. move() where the browser has it, else a file is copied and the old removed
  rename: async (q) => {
    const [k, h] = await at(q.path);
    const [d, n] = await parent(q.path2);
    if (n === undefined) return -E.EBUSY;
    if (q.path2 === q.path) return 0;
    if (k === 'd' && (q.path2 + '/').startsWith(q.path + '/')) return -E.EINVAL;
    let there = null;
    try { there = await at(q.path2); } catch (e) { if (e?.name !== 'NotFoundError') throw e; }
    if (there) {
      if (k === 'f' && there[0] === 'd') return -E.EISDIR;
      if (k === 'd') return there[0] === 'd' ? -E.ENOTEMPTY : -E.ENOTDIR;
      await d.removeEntry(n); }
    if (h.move) { await h.move(d, n); return 0; }
    if (k === 'd') return -E.EXDEV;
    const [sd, sn] = await parent(q.path), w = await (await d.getFileHandle(n, { create: true })).createWritable();
    await w.write(await h.getFile()); await w.close();
    await sd.removeEntry(sn);
    return 0; } };

// one ask at a time: the cpu worker waits on each before it sends the next
const serve = async (q, ring) => {
  const ctl = new Int32Array(ring, 0, 4), f64 = new Float64Array(ring, host_f64, 4);
  let r;
  try { r = !root ? -E.ENODEV : await ops[q.op]?.(q, ring, f64) ?? -E.EINVAL; }
  catch (e) { r = errno(e); }
  f64[0] = r;
  Atomics.store(ctl, 0, 2);
  Atomics.notify(ctl, 0); };

// a file from the page: its directories made on the way, the bytes laid whole
const put = async (p, bytes) => {
  let d = root;
  const ns = names(p);
  for (const n of ns.slice(0, -1)) d = await d.getDirectoryHandle(n, { create: true });
  const fh = await d.getFileHandle(ns[ns.length - 1], { create: true });
  if (fh.createWritable) { const w = await fh.createWritable(); await w.write(bytes); await w.close(); }
  else { const s = await fh.createSyncAccessHandle(); s.truncate(0); s.write(new Uint8Array(bytes), { at: 0 }); s.flush(); s.close(); } };

const isNode = typeof process !== 'undefined' && !!process.versions?.node;
const self_ = isNode ? (await import('node:worker_threads')).parentPort
            : typeof WorkerGlobalScope !== 'undefined' ? self : null;
const rooted = async (r) => {
  if (isNode) return r ? new (await import('./nodedir.mjs')).NodeDir(r) : null;
  return r ?? await navigator.storage?.getDirectory?.() ?? null; };
let ready = Promise.resolve(), lane = null;
const take = (m) => {
  if (m.ring) {
    lane = m.ring;
    const port = m.port;
    const on = (q) => { ready = ready.then(() => serve(q, lane)); };
    isNode ? port.on('message', on) : port.addEventListener('message', (e) => on(e.data));
    port.start?.(); }
  if ('root' in m) ready = ready.then(async () => { files.clear(); root = await rooted(m.root); });
  if (m.put) ready = ready.then(() => put(m.put, m.bytes))
    .then(() => self_.postMessage({ put: m.put }), (e) => self_.postMessage({ put: m.put, error: String(e?.message ?? e) })); };
if (self_) isNode ? self_.on('message', take) : self_.addEventListener('message', (e) => take(e.data));
