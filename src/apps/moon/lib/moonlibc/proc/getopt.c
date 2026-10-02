#include "../impl.h"
#include <getopt.h>

/* ---- getopt, getopt_long, getopt_long_only: glibc's behaviour ----
 * the whole of a parse's state is a struct getopt_data, and the _r calls take one: next, the
 * cursor inside a clustered -abc, and [first, last), the operands passed over so far, beside
 * the posix four. gnu order (the default) permutes: each option found is moved ahead of the
 * operands before it, lazily, so the operands end after the options in their own order. a
 * leading '+' or POSIXLY_CORRECT stops at the first operand; a leading '-' answers an operand
 * as option 1. a ':' after those silences the messages and answers ':' for a missing value.
 * optind = 0 starts over. the posix calls run one instance, synced with posix's globals --
 * those and it are the only state at file scope. */
char *optarg;
int optind = 1, opterr = 1, optopt;
static struct getopt_data posix = GETOPT_DATA_INIT;

/* [first, last) and [last, optind) trade places, each in its own order */
static void swap(char **v, struct getopt_data *d) {
  int a = d->first, b = d->last, e = d->optind;
  for (int j = b; j < e; j++) {
    char *t = v[j];
    for (int n = j; n > a; n--) v[n] = v[n - 1];
    v[a++] = t; }
  d->first += e - b; d->last = e; }

static int operand(char const *a) { return a[0] != '-' || !a[1]; }

/* a long option, its name at d->next (past `pre`): the val, 0 when it set a flag, '?' / ':'
 * on a refusal, -1 when long_only finds no name and the short reading is to be tried */
static int longopt(int ac, char **av, char const *os, struct option const *lo, int *ix,
                   int only, int loud, char const *pre, struct getopt_data *d) {
  char *s = d->next, *eq = s;
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
    d->next = 0; d->optind++; d->optopt = 0; return '?'; }
  if (hit < 0) {
    if (!only || av[d->optind][1] == '-' || !strchr(os, *d->next)) {
      if (loud) fprintf(stderr, "%s: unrecognized option '%s%s'\n", av[0], pre, s);
      d->next = 0; d->optind++; d->optopt = 0; return '?'; }
    return -1; }
  struct option const *o = lo + hit;
  d->optind++; d->next = 0;
  if (*eq) {
    if (!o->has_arg) {
      if (loud) fprintf(stderr, "%s: option '%s%s' doesn't allow an argument\n", av[0], pre, o->name);
      d->optopt = o->val; return '?'; }
    d->optarg = eq + 1; }
  else if (o->has_arg == required_argument) {
    if (d->optind >= ac) {
      if (loud) fprintf(stderr, "%s: option '%s%s' requires an argument\n", av[0], pre, o->name);
      d->optopt = o->val; return os[0] == ':' ? ':' : '?'; }
    d->optarg = av[d->optind++]; }
  if (ix) *ix = hit;
  if (o->flag) { *o->flag = o->val; return 0; }
  return o->val; }

static int run(int ac, char *const *cav, char const *os, struct option const *lo, int *ix, int only,
               struct getopt_data *d) {
  char **av = (char **) cav;
  if (ac < 1) return -1;
  d->optarg = 0;
  if (d->optind == 0) { d->optind = 1; d->next = 0; d->first = d->last = 1; }
  int order = 0;                                   /* 0 permute, '+' stop, '-' in order */
  if (*os == '+' || *os == '-') order = *os++;
  else if (getenv("POSIXLY_CORRECT")) order = '+';
  int loud = d->opterr && *os != ':';
  if (!d->next || !*d->next) {
    if (d->last > d->optind) d->last = d->optind;
    if (d->first > d->optind) d->first = d->optind;
    if (!order) {
      if (d->first != d->last && d->last != d->optind) swap(av, d);
      else if (d->last != d->optind) d->first = d->optind;
      while (d->optind < ac && operand(av[d->optind])) d->optind++;
      d->last = d->optind; }
    if (d->optind != ac && !strcmp(av[d->optind], "--")) {
      d->optind++;
      if (d->first != d->last && d->last != d->optind) swap(av, d);
      else if (d->first == d->last) d->first = d->optind;
      d->last = ac; d->optind = ac; }
    if (d->optind == ac) {
      if (d->first != d->last) d->optind = d->first;
      return -1; }
    if (operand(av[d->optind])) {
      if (order == '+') return -1;
      d->optarg = av[d->optind++]; return 1; }
    if (lo) {
      if (av[d->optind][1] == '-') {
        d->next = av[d->optind] + 2; return longopt(ac, av, os, lo, ix, only, loud, "--", d); }
      if (only && (av[d->optind][2] || !strchr(os, av[d->optind][1]))) {
        d->next = av[d->optind] + 1;
        int r = longopt(ac, av, os, lo, ix, only, loud, "-", d);
        if (r != -1) return r; } }
    d->next = av[d->optind] + 1; }
  int c = (unsigned char) *d->next++;
  char const *o = strchr(os, c);
  if (!*d->next) d->optind++;
  if (!o || c == ':' || c == ';') {
    if (loud) fprintf(stderr, "%s: invalid option -- '%c'\n", av[0], c);
    d->optopt = c; return '?'; }
  if (o[1] == ':') {
    if (*d->next) { d->optarg = d->next; d->optind++; }
    else if (o[2] != ':') {
      if (d->optind == ac) {
        if (loud) fprintf(stderr, "%s: option requires an argument -- '%c'\n", av[0], c);
        d->optopt = c; c = os[0] == ':' ? ':' : '?'; }
      else d->optarg = av[d->optind++]; }
    d->next = 0; }
  return c; }

int getopt_r(int ac, char *const *av, char const *os, struct getopt_data *d) {
  return run(ac, av, os, 0, 0, 0, d); }
int getopt_long_r(int ac, char *const *av, char const *os, struct option const *lo, int *ix, struct getopt_data *d) {
  return run(ac, av, os, lo, ix, 0, d); }
int getopt_long_only_r(int ac, char *const *av, char const *os, struct option const *lo, int *ix,
                       struct getopt_data *d) {
  return run(ac, av, os, lo, ix, 1, d); }

/* the posix calls: the globals in, one parse step on the instance, the globals out */
static int step(int ac, char *const *av, char const *os, struct option const *lo, int *ix, int only) {
  posix.optind = optind; posix.opterr = opterr;
  int r = run(ac, av, os, lo, ix, only, &posix);
  optind = posix.optind; optarg = posix.optarg; optopt = posix.optopt;
  return r; }
int getopt(int ac, char *const *av, char const *os) { return step(ac, av, os, 0, 0, 0); }
int getopt_long(int ac, char *const *av, char const *os, struct option const *lo, int *ix) {
  return step(ac, av, os, lo, ix, 0); }
int getopt_long_only(int ac, char *const *av, char const *os, struct option const *lo, int *ix) {
  return step(ac, av, os, lo, ix, 1); }
