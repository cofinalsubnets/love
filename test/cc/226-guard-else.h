/* an #else at the top: no guard, so the second #include still reads it */
#ifndef ELSE226
#define ELSE226 1
#else
#undef ELSE226
#define ELSE226 2
#endif
