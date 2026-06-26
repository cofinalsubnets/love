// host/image.c -- file I/O around the core's stdio-free image codec (ai_image_save /
// ai_image_load, ai.c). The CORE owns the heap serialization (compact + range-encode a
// {header, blob} buffer, and its inverse); the HOST owns stdio -- so ai.c stays
// freestanding-clean. main.c calls image_dump (--dump-image) and image_load (--load-image
// / the <exe>.img auto-load). Conventions: dump 0 ok / <0 error; load NULL on any problem
// so the caller falls back to a normal egg boot.
#include "ai.h"
#include <stdio.h>
#include <stdlib.h>

int image_dump(struct ai *g, char const *path) {
  uintptr_t len = 0;
  void *buf = ai_image_save(g, &len);             // g->alloc'd; --dump-image exits right after, so we don't free it
  if (!buf) return -2;
  FILE *f = fopen(path, "wb");
  int rc = !f ? -4 : (fwrite(buf, 1, len, f) == len) ? 0 : -4;
  if (f) fclose(f);
  return rc;
}

struct ai *image_load(char const *path) {
  FILE *f = fopen(path, "rb");
  if (!f) return NULL;
  struct ai *g = NULL;
  if (!fseek(f, 0, SEEK_END)) {
    long n = ftell(f);
    if (n > 0 && !fseek(f, 0, SEEK_SET)) {
      void *buf = malloc((size_t) n);             // the host owns the file buffer; the core copies the blob out
      if (buf && fread(buf, 1, (size_t) n, f) == (size_t) n) g = ai_image_load(buf, (uintptr_t) n);
      free(buf);
    }
  }
  fclose(f);
  return g;
}
