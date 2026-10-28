#pragma once
#include <unistd.h>

struct option { char const *name; int has_arg; int *flag; int val; };
#define no_argument       0
#define required_argument 1
#define optional_argument 2

int getopt_long(int, char *const *, char const *, struct option const *, int *);
int getopt_long_only(int, char *const *, char const *, struct option const *, int *);

/* moonlibc's reentrant parse state: start from GETOPT_DATA_INIT, or optind 0 */
struct getopt_data { int optind, opterr, optopt; char *optarg; char *next; int first, last; };
#define GETOPT_DATA_INIT {1, 1, 0, 0, 0, 1, 1}
int getopt_r(int, char *const *, char const *, struct getopt_data *);
int getopt_long_r(int, char *const *, char const *, struct option const *, int *, struct getopt_data *);
int getopt_long_only_r(int, char *const *, char const *, struct option const *, int *, struct getopt_data *);
