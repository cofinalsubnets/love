// crew/haven/smoke.c -- the real-client smoke: libwayland-client (the
// reference implementation, strict about ids and the wire) sails against
// haven. it binds all four globals, insists on the xrgb format and the
// output's done, raises an xdg toplevel, paints frames of one color on the
// frame-callback clock, destroys the pool while its buffers still sail
// (weston-simple-shm's habit), dresses a FRESH pool on every resize -- so
// ids retire through delete_id and libwayland REUSES them -- then strikes
// everything in protocol order. exit 0 = every roundtrip clean.
//
//   haven-smoke <socket-path> <rrggbb> <frames>
//
// built by the Makefile only where wayland-scanner + libwayland live; haven
// itself stays zero-dep -- this binary exists to be the OTHER side.
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <time.h>
#include <sys/mman.h>
#include <wayland-client.h>
#include "xdg-shell-client-protocol.h"

struct smoke {
  struct wl_display *dpy;
  struct wl_compositor *comp;
  struct wl_shm *shm;
  struct xdg_wm_base *wm;
  struct wl_output *out;
  struct wl_surface *surf;
  struct xdg_surface *xsurf;
  struct xdg_toplevel *top;
  struct wl_buffer *buf[2];
  uint32_t *px[2];
  void *map; size_t mapn;
  int w, h;                    // dressed size
  int cw, ch;                  // configured size (0 = our choice)
  uint32_t rgb;
  int frames, configured, xrgb, outdone, flying;
};

static void fail(const char *m) { fprintf(stderr, "smoke: FAIL %s\n", m); exit(1); }

static void shm_format(void *d, struct wl_shm *shm, uint32_t f) {
  (void)shm;
  if (f == WL_SHM_FORMAT_XRGB8888) ((struct smoke*)d)->xrgb = 1; }
static const struct wl_shm_listener shm_l = { shm_format };

static void out_geom(void *d, struct wl_output *o, int32_t x, int32_t y,
                     int32_t pw, int32_t ph, int32_t sub, const char *make,
                     const char *model, int32_t tr) {
  (void)d; (void)o; (void)x; (void)y; (void)pw; (void)ph; (void)sub;
  (void)make; (void)model; (void)tr; }
static void out_mode(void *d, struct wl_output *o, uint32_t flags, int32_t w,
                     int32_t h, int32_t r) {
  (void)d; (void)o; (void)flags; (void)w; (void)h; (void)r; }
static void out_done(void *d, struct wl_output *o) {
  (void)o; ((struct smoke*)d)->outdone = 1; }
static void out_scale(void *d, struct wl_output *o, int32_t f) {
  (void)d; (void)o; (void)f; }
static const struct wl_output_listener out_l =
  { .geometry = out_geom, .mode = out_mode, .done = out_done, .scale = out_scale };

static void wm_ping(void *d, struct xdg_wm_base *wm, uint32_t serial) {
  (void)d; xdg_wm_base_pong(wm, serial); }
static const struct xdg_wm_base_listener wm_l = { wm_ping };

static void reg_global(void *d, struct wl_registry *r, uint32_t name,
                       const char *iface, uint32_t ver) {
  struct smoke *s = d;
  if (!strcmp(iface, "wl_compositor"))
    s->comp = wl_registry_bind(r, name, &wl_compositor_interface, ver < 4 ? ver : 4);
  else if (!strcmp(iface, "wl_shm")) {
    s->shm = wl_registry_bind(r, name, &wl_shm_interface, 1);
    wl_shm_add_listener(s->shm, &shm_l, s);
  } else if (!strcmp(iface, "xdg_wm_base")) {
    s->wm = wl_registry_bind(r, name, &xdg_wm_base_interface, ver < 2 ? ver : 2);
    xdg_wm_base_add_listener(s->wm, &wm_l, s);
  } else if (!strcmp(iface, "wl_output")) {
    s->out = wl_registry_bind(r, name, &wl_output_interface, ver < 2 ? ver : 2);
    wl_output_add_listener(s->out, &out_l, s);
  } }
static void reg_gone(void *d, struct wl_registry *r, uint32_t name) {
  (void)d; (void)r; (void)name; }
static const struct wl_registry_listener reg_l = { reg_global, reg_gone };

static void xs_conf(void *d, struct xdg_surface *xs, uint32_t serial) {
  struct smoke *s = d;
  xdg_surface_ack_configure(xs, serial);
  s->configured = 1; }
static const struct xdg_surface_listener xs_l = { xs_conf };

static void top_conf(void *d, struct xdg_toplevel *t, int32_t w, int32_t h,
                     struct wl_array *st) {
  struct smoke *s = d; (void)t; (void)st;
  s->cw = w; s->ch = h; }
static void top_close(void *d, struct xdg_toplevel *t) {
  (void)t; ((struct smoke*)d)->frames = 0; }
static const struct xdg_toplevel_listener top_l =
  { .configure = top_conf, .close = top_close };

// dress: a fresh pool + two buffers at (w h); the pool OBJECT is destroyed
// at once -- the live buffers must keep the mapping afloat server-side
static void dress(struct smoke *s, int w, int h) {
  int stride = w * 4, size = stride * h * 2;
  int fd = memfd_create("smoke", 0);
  if (fd < 0 || ftruncate(fd, size)) fail("memfd");
  s->map = mmap(NULL, (size_t)size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
  if (s->map == MAP_FAILED) fail("mmap");
  s->mapn = (size_t)size;
  struct wl_shm_pool *pool = wl_shm_create_pool(s->shm, fd, size);
  for (int i = 0; i < 2; i++) {
    s->buf[i] = wl_shm_pool_create_buffer(pool, i * stride * h, w, h, stride,
                                          WL_SHM_FORMAT_XRGB8888);
    s->px[i] = (uint32_t*)((char*)s->map + (size_t)(i * stride * h));
  }
  wl_shm_pool_destroy(pool);                       // the rung-1 lane under test
  close(fd);
  s->w = w; s->h = h; }

static void undress(struct smoke *s) {
  for (int i = 0; i < 2; i++)
    if (s->buf[i]) { wl_buffer_destroy(s->buf[i]); s->buf[i] = NULL; }
  if (s->map) { munmap(s->map, s->mapn); s->map = NULL; } }

static void sail(struct smoke *s);
static void frame_done(void *d, struct wl_callback *cb, uint32_t t) {
  (void)t;
  wl_callback_destroy(cb);
  struct smoke *s = d;
  s->flying = 0;
  if (s->frames > 0) sail(s); }
static const struct wl_callback_listener frame_l = { frame_done };

// one frame: re-dress if the compositor resized us, paint, attach, damage,
// commit -- and ask for the next tick unless this is the last. the 10ms
// nap sets a deterministic pace (haven's frame clock answers instantly),
// so <frames> is a lifetime the gate can probe against
static void sail(struct smoke *s) {
  struct timespec ts = { 0, 10 * 1000 * 1000 };
  nanosleep(&ts, NULL);
  if (s->cw > 0 && s->ch > 0 && (s->cw != s->w || s->ch != s->h)) {
    undress(s);
    dress(s, s->cw, s->ch);                        // ids retire and come back
  }
  int i = s->frames & 1;
  for (int j = 0; j < s->w * s->h; j++) s->px[i][j] = s->rgb;
  wl_surface_attach(s->surf, s->buf[i], 0, 0);
  wl_surface_damage(s->surf, 0, 0, s->w, s->h);
  if (s->frames > 1) {
    struct wl_callback *cb = wl_surface_frame(s->surf);
    wl_callback_add_listener(cb, &frame_l, s);
    s->flying = 1;
  }
  wl_surface_commit(s->surf);
  s->frames--; }

int main(int argc, char **argv) {
  if (argc != 4) fail("usage: haven-smoke <socket> <rrggbb> <frames>");
  struct smoke s = {0};
  s.rgb = (uint32_t)strtoul(argv[2], NULL, 16);
  s.frames = atoi(argv[3]);
  s.dpy = wl_display_connect(argv[1]);
  if (!s.dpy) fail("connect");
  struct wl_registry *reg = wl_display_get_registry(s.dpy);
  wl_registry_add_listener(reg, &reg_l, &s);
  if (wl_display_roundtrip(s.dpy) < 0) fail("registry roundtrip");
  if (!s.comp || !s.shm || !s.wm || !s.out) fail("globals");
  if (wl_display_roundtrip(s.dpy) < 0) fail("events roundtrip");
  if (!s.xrgb) fail("no xrgb8888");
  if (!s.outdone) fail("no output done");

  s.surf = wl_compositor_create_surface(s.comp);
  s.xsurf = xdg_wm_base_get_xdg_surface(s.wm, s.surf);
  xdg_surface_add_listener(s.xsurf, &xs_l, &s);
  s.top = xdg_surface_get_toplevel(s.xsurf);
  xdg_toplevel_add_listener(s.top, &top_l, &s);
  xdg_toplevel_set_title(s.top, "smoke");
  wl_surface_commit(s.surf);                       // bufferless: ask to be configured
  while (!s.configured)
    if (wl_display_dispatch(s.dpy) < 0) fail("configure");

  dress(&s, s.cw > 0 ? s.cw : 320, s.ch > 0 ? s.ch : 240);
  sail(&s);
  while (s.frames > 0 || s.flying)
    if (wl_display_dispatch(s.dpy) < 0) fail("dispatch");

  // strike in protocol order: every destructor must be answered by delete_id
  undress(&s);
  xdg_toplevel_destroy(s.top);
  xdg_surface_destroy(s.xsurf);
  wl_surface_destroy(s.surf);
  xdg_wm_base_destroy(s.wm);
  wl_output_destroy(s.out);
  wl_shm_destroy(s.shm);
  wl_compositor_destroy(s.comp);
  wl_registry_destroy(reg);
  if (wl_display_roundtrip(s.dpy) < 0) fail("teardown roundtrip");
  if (wl_display_get_error(s.dpy)) fail("protocol error");
  wl_display_disconnect(s.dpy);
  printf("smoke: ok\n");
  return 0; }
