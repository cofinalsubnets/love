// port/wasm/coi.js -- cross-origin isolation for a static host. SharedArrayBuffer, which
// the machine's key ring rides (cpu.mjs), wants two headers a plain file server never
// sends: COOP and COEP. this file is both halves of the usual answer -- loaded by a page,
// it registers itself as a service worker and reloads once under it; running as that
// worker, it adds the two headers to every response. a server that sends them itself
// never registers it (the page is already isolated, and the script does nothing).
if (typeof window === 'undefined') {
  self.addEventListener('install', () => self.skipWaiting());
  self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));
  self.addEventListener('fetch', (e) => {
    if (e.request.cache === 'only-if-cached' && e.request.mode !== 'same-origin') return;
    e.respondWith(fetch(e.request).then((r) => {
      if (r.status === 0) return r;
      const h = new Headers(r.headers);
      h.set('Cross-Origin-Embedder-Policy', 'require-corp');
      h.set('Cross-Origin-Opener-Policy', 'same-origin');
      return new Response(r.body, { status: r.status, statusText: r.statusText, headers: h }); })); });
} else if (!window.crossOriginIsolated && navigator.serviceWorker) {
  const src = document.currentScript.src;
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (!sessionStorage.getItem('coi-reloaded')) { sessionStorage.setItem('coi-reloaded', '1'); location.reload(); } });
  navigator.serviceWorker.register(src).then((reg) => {
    if (reg.active && !navigator.serviceWorker.controller && !sessionStorage.getItem('coi-reloaded')) {
      sessionStorage.setItem('coi-reloaded', '1'); location.reload(); } });
}
