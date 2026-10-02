/* getopt, getopt_long, getopt_long_only: every answer of every call (the value, optind,
 * optarg, optopt, the long index, a flag) and the argv left behind, over the kernel
 * hostprogs' own argv shapes, the edges (clusters, glued and next-word values, optional
 * ones, `--`, a bare `-`, the '+' '-' ':' modes, ambiguous and unique prefixes, long_only's
 * fall back to short), then a seeded sweep with POSIXLY_CORRECT off and on. the messages
 * are part of the answer: stderr rides stdout, both unbuffered, so they land in order. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <getopt.h>
#include "say.h"

static int flag;
static struct option L1[] = {
  {"defconfig", optional_argument, 0, 'D'}, {"syncconfig", no_argument, 0, 's'}, {"oldconfig", no_argument, 0, 'o'},
  {"olddefconfig", no_argument, 0, 'O'}, {"verbose", no_argument, &flag, 7}, {"output", required_argument, 0, 'w'},
  {"opt", required_argument, 0, 'p'}, {"help", no_argument, 0, 'h'}, {0, 0, 0, 0}};
static struct option L2[] = {
  {"color", no_argument, 0, 'c'}, {"colour", no_argument, 0, 'c'}, {"count", required_argument, 0, 'n'}, {0, 0, 0, 0}};
static struct option L3[] = {
  {"alpha", no_argument, 0, 'A'}, {"alps", no_argument, 0, 'P'}, {"beta", required_argument, 0, 'B'},
  {"gamma", optional_argument, &flag, 9}, {"delta", no_argument, 0, 'D'}, {"delta-x", required_argument, 0, 'E'}, {0, 0, 0, 0}};

struct sc { char const *os; struct option *lo; int only; char const *args[12]; };
static struct sc T[] = {
  {"", L1, 0, {"conf", "--defconfig=arch/arm64/configs/defconfig", "Kconfig"}},
  {"", L1, 0, {"conf", "--syncconfig", "Kconfig"}},
  {"", L1, 0, {"conf", "Kconfig", "--olddefconfig"}},
  {"", L1, 0, {"conf", "--defconfig", "Kconfig"}},
  {"", L1, 0, {"conf", "--syncc", "K"}},
  {"", L1, 0, {"conf", "--old", "K"}},
  {"", L1, 0, {"conf", "--old=x", "K"}},
  {"", L1, 0, {"conf", "--nope", "K"}},
  {"", L1, 0, {"conf", "--syncconfig=1", "K"}},
  {"", L1, 0, {"conf", "--output"}},
  {"", L1, 0, {"conf", "--output", "f", "a", "--verbose", "b"}},
  {":", L1, 0, {"conf", "--output"}},
  {"ab:c::", 0, 0, {"p", "-abX", "-c", "x", "-cY", "--", "-a"}},
  {"ab:c::", 0, 0, {"p", "x", "-a", "y", "-b", "z", "w", "-q", "v"}},
  {"+ab:", 0, 0, {"p", "-a", "x", "-b", "z"}},
  {"-ab:", 0, 0, {"p", "-a", "x", "-b", "z", "y"}},
  {":ab:", 0, 0, {"p", "-b"}},
  {"ab:", 0, 0, {"p", "-b"}},
  {"ab:", 0, 0, {"p", "-", "-a", "--", "-b"}},
  {"ab:", 0, 0, {"p", "-a:", "-x"}},
  {"ab", L2, 0, {"p", "--col", "--co", "x", "--cou=3", "-ab"}},
  {"ab", L1, 1, {"p", "-opt", "v", "-help", "-ab", "-sync", "-a", "-zz"}},
  {"qI:O:o:V:d:R:S:p:a:fb:i:H:sW:E:@AThv", 0, 0, {"dtc", "-O", "dtb", "-o", "x.dtb", "-b", "0", "-iinc", "-d", "x.d", "x.dts"}},
  {"adT:Vhp", 0, 0, {"genksyms", "-r", "f"}},
  {"adT:Vhp", 0, 0, {"genksyms", "-a", "arm64", "-T", "x.symtypes"}},
};

static void calls(int ac, char **av, char const *os, struct option *lo, int only) {
  for (int n = 0; n < 20; n++) {
    int ix = -1, r = lo ? (only ? getopt_long_only : getopt_long)(ac, av, os, lo, &ix) : getopt(ac, av, os);
    say_n("  r", r); say_n("  optind", optind); say_s("  optarg", optarg ? optarg : "-");
    say_n("  optopt", optopt); say_n("  ix", ix); say_n("  flag", flag);
    if (r == -1) break; }
  for (int i = 0; i < ac; i++) say_s("  argv", av[i]); }

static unsigned seed = 12345;
static unsigned rnd(unsigned n) { seed = seed * 1103515245u + 12345u; return (seed >> 16) % n; }
static char const *tok[] = {"-a", "-b", "-c", "-ab", "-ba", "-bx", "-cx", "-abc", "-q", "-:", "-", "--", "x", "y",
  "--alpha", "--al", "--a", "--beta=1", "--beta", "--gamma", "--gam=2", "--gamma=", "--zz", "-alpha", "-be",
  "-gamma=3", "--delta", "--del", "-W", "--alp=x", "--b"};

int main(void) {
  setvbuf(stdout, 0, _IONBF, 0); setvbuf(stderr, 0, _IONBF, 0); dup2(1, 2);
  for (unsigned k = 0; k < sizeof T / sizeof *T; k++) {
    char *av[13]; int ac = 0;
    while (T[k].args[ac]) { av[ac] = strdup(T[k].args[ac]); ac++; }
    av[ac] = 0;
    optind = 0; opterr = 1; flag = 0;
    say_s("case", T[k].os);
    calls(ac, av, T[k].os, T[k].lo, T[k].only); }
  char const *pre[] = {"", "+", "-", ":", "+:", "-:"}, *body[] = {"abc", "ab:c", "ab:c::", "a:b::c", "abq", "a"};
  for (int k = 0; k < 4000; k++) {
    if (k == 2000) setenv("POSIXLY_CORRECT", "1", 1);
    char os[16]; strcpy(os, pre[rnd(6)]); strcat(os, body[rnd(6)]);
    int mode = rnd(3), ac = 1 + rnd(7);
    char *av[10]; av[0] = strdup("prog");
    for (int i = 1; i < ac; i++) av[i] = strdup(tok[rnd(sizeof tok / sizeof *tok)]);
    av[ac] = 0;
    optind = 0; opterr = rnd(4) != 0; flag = 0;
    say_s("sweep", os); say_n("  mode", mode);
    calls(ac, av, os, mode ? L3 : 0, mode == 2); }
  return 0; }
