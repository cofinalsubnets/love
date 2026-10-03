#include "../impl.h"

int dirfd(DIR *d) { return d->fd; }
