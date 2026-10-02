#ifndef _GETOPT_H
#define _GETOPT_H
#include <unistd.h>

struct option { char const *name; int has_arg; int *flag; int val; };
#define no_argument       0
#define required_argument 1
#define optional_argument 2

int getopt_long(int, char *const *, char const *, struct option const *, int *);
int getopt_long_only(int, char *const *, char const *, struct option const *, int *);
#endif
