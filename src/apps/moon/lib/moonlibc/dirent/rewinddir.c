#include "../impl.h"

void rewinddir(DIR *d) {
  lseek(d->fd, 0, SEEK_SET);
  d->pos = 0; d->len = 0; }
