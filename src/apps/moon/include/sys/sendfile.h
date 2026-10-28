#pragma once
#include <sys/types.h>
ssize_t sendfile(int, int, off_t*, size_t);
