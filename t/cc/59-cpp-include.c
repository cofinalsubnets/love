/* #include a quoted header twice -- the guard makes the second a no-op */
#include "59-cpp-include.h"
#include "59-cpp-include.h"
int triple(int x) { return x + x + x; }
int main() {
  return triple(SEVEN);   /* 21 */
}
