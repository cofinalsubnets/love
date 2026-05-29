#include <stddef.h>

size_t strlen(char const *c) {
  size_t len = 0;
  while (*c++) len++;
  return len; }
