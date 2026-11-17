#pragma once
#include <stddef.h>
#define GRND_NONBLOCK 1
#define GRND_RANDOM   2
#define GRND_INSECURE 4
long getrandom(void*, size_t, unsigned int);
int getentropy(void*, size_t);
