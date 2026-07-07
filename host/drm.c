// host/drm.c -- the metal's two doors: a generic ioctl (the struct rides in
// a cask, read and written in place -- peek/poke-class honesty, the caller
// keeps its layouts straight) and an OFFSET mmap (a DRM dumb buffer maps at
// the magic offset MAP_DUMB hands back; plain mapfd is pinned to 0).
// crew/haven/drm.l speaks the actual DRM vocabulary in ai over these two.
// Self-contained host nif file: auto-globbed + AI_NIF-registered, no core
// edit -- the same discipline as net.c/pty.c/haven.c.
//
//   (ioctl fd req buf)  -> result charm | negative -errno ; fd a charm or an
//                          open port; buf a cask (the struct, in place) or 0
//                          for the no-argument kind
//   (mapfdo fd n off)   -> ptr charm | negative -errno (mmap RW shared at off)
#define _GNU_SOURCE
#include "ai.h"
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <errno.h>

static struct ai_str *drm_bytes(ai_word x) {
  if (x & 1) return 0;
  if (((union u*) x)->ap == lvm_buf) return ((struct ai_buf*) x)->str;
  return ai_strp(x) ? (struct ai_str*) x : 0; }

// an fd charm, or an open port's fd -- the device rides either way
static intptr_t drm_fd(ai_word x) {
  if (x & 1) return getcharm(x);
  if (((union u*) x)->ap == lvm_port_io) return getcharm(((struct ai_io*) x)->fd);
  return -1; }

static lvm(lvm_ioctl) {
  intptr_t fd = drm_fd(Sp[0]);
  uintptr_t req = (Sp[1] & 1) ? (uintptr_t) getcharm(Sp[1]) : 0;
  struct ai_str *b = drm_bytes(Sp[2]);
  ai_word out;
  if (fd < 0) out = putcharm(-EINVAL);
  else {
    int r = ioctl((int) fd, (unsigned long) req, b ? (void*) b->bytes : 0);
    out = putcharm(r < 0 ? -errno : r); }
  Sp[2] = out;
  Sp += 2; Ip += 1; return Continue(); }

static lvm(lvm_mapfdo) {
  intptr_t fd  = drm_fd(Sp[0]),
           n   = (Sp[1] & 1) ? getcharm(Sp[1]) : -1,
           off = (Sp[2] & 1) ? getcharm(Sp[2]) : -1;
  ai_word out = putcharm(-EINVAL);
  if (fd >= 0 && n > 0 && off >= 0) {
    void *p = mmap(0, (size_t) n, PROT_READ | PROT_WRITE, MAP_SHARED,
                   (int) fd, (off_t) off);
    out = p == MAP_FAILED ? putcharm(-errno) : putcharm((intptr_t) p); }
  Sp[2] = out;
  Sp += 2; Ip += 1; return Continue(); }

static union u const
  nif_ioctl[]  = {{lvm_cur}, {.x = putcharm(3)}, {lvm_ioctl}, {lvm_ret0}},
  nif_mapfdo[] = {{lvm_cur}, {.x = putcharm(3)}, {lvm_mapfdo}, {lvm_ret0}};
AI_NIF("ioctl", nif_ioctl);
AI_NIF("mapfdo", nif_mapfdo);
