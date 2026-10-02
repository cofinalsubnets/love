#include "../impl.h"
#include <getopt.h>

/* ---- getopt, getopt_long, getopt_long_only: glibc's behaviour ----
 * optind optarg opterr optopt are posix's mutable globals. getopt's own state rides beside
 * them, as glibc keeps it: next, the cursor inside a clustered -abc, and [first, last), the
 * operands passed over so far. gnu order (the default) permutes: each option found is moved
 * ahead of the operands before it, lazily, so the operands end after the options in their
 * own order. a leading '+' or POSIXLY_CORRECT stops at the first operand; a leading '-'
 * answers an operand as option 1. a ':' after those silences the messages and answers ':'
 * for a missing value. optind = 0 starts over. */
char *optarg;
int optind = 1, opterr = 1, optopt;
static char *next;
static int first = 1, last = 1;

/* [first, last) and [last, optind) trade places, each in its own order */
static void swap(char **v) {
  int a = first, b = last, e = optind;
  for (int j = b; j < e; j++) {
    char *t = v[j];
    for (int n = j; n > a; n--) v[n] = v[n - 1];
    v[a++] = t; }
  first += e - b; last = e; }

static int operand(char const *a) { return a[0] != '-' || !a[1]; }

/* a long option, its name at next (past `pre`): the val, 0 when it set a flag, '?' / ':' on
 * a refusal, -1 when long_only finds no name and the short reading is to be tried */
static int longopt(int ac, char **av, char const *os, struct option const *lo, int *ix,
                   int only, int loud, char const *pre) {
  char *s = next, *eq = s;
  while (*eq && *eq != '=') eq++;
  size_t n = (size_t) (eq - s);
  int hit = -1, many = 0;
  for (int i = 0; lo[i].name; i++)
    if (!strncmp(lo[i].name, s, n) && strlen(lo[i].name) == n) { hit = i; break; }
  if (hit < 0)
    for (int i = 0; lo[i].name; i++) {
      if (strncmp(lo[i].name, s, n)) continue;
      if (hit < 0) hit = i;
      else if (lo[i].has_arg != lo[hit].has_arg || lo[i].flag != lo[hit].flag || lo[i].val != lo[hit].val)
        many = 1; }
  if (many) {
    if (loud) {
      fprintf(stderr, "%s: option '%s%s' is ambiguous; possibilities:", av[0], pre, s);
      for (int i = 0; lo[i].name; i++)
        if (!strncmp(lo[i].name, s, n) && (i == hit || lo[i].has_arg != lo[hit].has_arg
            || lo[i].flag != lo[hit].flag || lo[i].val != lo[hit].val))
          fprintf(stderr, " '%s%s'", pre, lo[i].name);
      fputc('\n', stderr); }
    next = 0; optind++; optopt = 0; return '?'; }
  if (hit < 0) {
    if (!only || av[optind][1] == '-' || !strchr(os, *next)) {
      if (loud) fprintf(stderr, "%s: unrecognized option '%s%s'\n", av[0], pre, s);
      next = 0; optind++; optopt = 0; return '?'; }
    return -1; }
  struct option const *o = lo + hit;
  optind++; next = 0;
  if (*eq) {
    if (!o->has_arg) {
      if (loud) fprintf(stderr, "%s: option '%s%s' doesn't allow an argument\n", av[0], pre, o->name);
      optopt = o->val; return '?'; }
    optarg = eq + 1; }
  else if (o->has_arg == required_argument) {
    if (optind >= ac) {
      if (loud) fprintf(stderr, "%s: option '%s%s' requires an argument\n", av[0], pre, o->name);
      optopt = o->val; return os[0] == ':' ? ':' : '?'; }
    optarg = av[optind++]; }
  if (ix) *ix = hit;
  if (o->flag) { *o->flag = o->val; return 0; }
  return o->val; }

static int run(int ac, char *const *cav, char const *os, struct option const *lo, int *ix, int only) {
  char **av = (char **) cav;
  if (ac < 1) return -1;
  optarg = 0;
  if (optind == 0) { optind = 1; next = 0; first = last = 1; }
  int order = 0;                                   /* 0 permute, '+' stop, '-' in order */
  if (*os == '+' || *os == '-') order = *os++;
  else if (getenv("POSIXLY_CORRECT")) order = '+';
  int loud = opterr && *os != ':';
  if (!next || !*next) {
    if (last > optind) last = optind;
    if (first > optind) first = optind;
    if (!order) {
      if (first != last && last != optind) swap(av);
      else if (last != optind) first = optind;
      while (optind < ac && operand(av[optind])) optind++;
      last = optind; }
    if (optind != ac && !strcmp(av[optind], "--")) {
      optind++;
      if (first != last && last != optind) swap(av);
      else if (first == last) first = optind;
      last = ac; optind = ac; }
    if (optind == ac) {
      if (first != last) optind = first;
      return -1; }
    if (operand(av[optind])) {
      if (order == '+') return -1;
      optarg = av[optind++]; return 1; }
    if (lo) {
      if (av[optind][1] == '-') { next = av[optind] + 2; return longopt(ac, av, os, lo, ix, only, loud, "--"); }
      if (only && (av[optind][2] || !strchr(os, av[optind][1]))) {
        next = av[optind] + 1;
        int r = longopt(ac, av, os, lo, ix, only, loud, "-");
        if (r != -1) return r; } }
    next = av[optind] + 1; }
  int c = (unsigned char) *next++;
  char const *d = strchr(os, c);
  if (!*next) optind++;
  if (!d || c == ':' || c == ';') {
    if (loud) fprintf(stderr, "%s: invalid option -- '%c'\n", av[0], c);
    optopt = c; return '?'; }
  if (d[1] == ':') {
    if (*next) { optarg = next; optind++; }
    else if (d[2] != ':') {
      if (optind == ac) {
        if (loud) fprintf(stderr, "%s: option requires an argument -- '%c'\n", av[0], c);
        optopt = c; c = os[0] == ':' ? ':' : '?'; }
      else optarg = av[optind++]; }
    next = 0; }
  return c; }

int getopt(int ac, char *const *av, char const *os) { return run(ac, av, os, 0, 0, 0); }
int getopt_long(int ac, char *const *av, char const *os, struct option const *lo, int *ix) {
  return run(ac, av, os, lo, ix, 0); }
int getopt_long_only(int ac, char *const *av, char const *os, struct option const *lo, int *ix) {
  return run(ac, av, os, lo, ix, 1); }
