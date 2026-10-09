#include "../impl.h"
#include <regex.h>

/* ---- regcomp, regexec, regerror, regfree: posix regular expressions, as glibc reads them ----
 * a pattern parses to a tree, the tree compiles to a program, and the program runs as a
 * backtracking search for the leftmost-longest match -- every path from a start, the longest
 * end kept, its groups those of the first path (greedy first) to reach it. BRE and ERE, glibc's
 * gnu escapes (\w \W \s \S \b \B \< \> \` \'), back-references in both. without
 * back-references a (pc, pos) is walked once per regexec: what can be reached from it does not
 * depend on how it was reached, and a start that failed reached nothing -- so the search is
 * O(program x text). a back-reference makes the reach depend on the groups, and the search
 * walks it whole. a mid-branch ^ also answers just past a newline the match consumed, and a
 * mid-branch $ just before one the match goes on to consume -- glibc's reading. */

enum { N_CHAR, N_ANY, N_SET, N_BOL, N_EOL, N_ASSERT, N_CAT, N_ALT, N_REP, N_GROUP, N_BREF, N_EMPTY };
enum { A_WORDB, A_NWORDB, A_WBEG, A_WEND, A_BUFBEG, A_BUFEND };
enum { O_CHAR, O_ANY, O_SET, O_BOL, O_EOL, O_ASSERT, O_SPLIT, O_JMP, O_SAVE, O_BREF, O_MARK, O_CHECK, O_MATCH };
#define REP_INF (-1)
#define DUP_MAX 0x7fff
#define PROG_MAX (1 << 16)

typedef struct node { int t, c, n, min, max; struct node *a, *b; unsigned char *set; } node;
typedef struct { int op, x, y; unsigned char *set; } ins;
typedef struct { ins *p; int np, nregs, bref, flags; size_t nsub; } prog;

typedef struct {
  char const *s; int ext, icase, nl, err, ngroup, bref; unsigned closed;
  node **all; int nall, call;
  unsigned char **sets; int nsets, csets; } parser;

static node *mk(parser *P, int t) {
  if (P->err) return 0;
  node *n = calloc(1, sizeof *n);
  if (!n) { P->err = REG_ESPACE; return 0; }
  if (P->nall == P->call) {
    int c = P->call ? 2 * P->call : 32;
    node **a = realloc(P->all, c * sizeof *a);
    if (!a) { free(n); P->err = REG_ESPACE; return 0; }
    P->all = a; P->call = c; }
  P->all[P->nall++] = n;
  n->t = t;
  return n; }

static unsigned char *mkset(parser *P) {
  unsigned char *s = calloc(1, 32);
  if (!s) { P->err = REG_ESPACE; return 0; }
  if (P->nsets == P->csets) {
    int c = P->csets ? 2 * P->csets : 8;
    unsigned char **a = realloc(P->sets, c * sizeof *a);
    if (!a) { free(s); P->err = REG_ESPACE; return 0; }
    P->sets = a; P->csets = c; }
  P->sets[P->nsets++] = s;
  return s; }

static void setb(unsigned char *s, int c) { s[c >> 3] |= (unsigned char) (1 << (c & 7)); }
static int getb(unsigned char const *s, int c) { return s[c >> 3] >> (c & 7) & 1; }
static void setc(parser *P, unsigned char *s, int c) {
  setb(s, c);
  if (P->icase) { setb(s, tolower(c)); setb(s, toupper(c)); } }

static node *two(parser *P, int t, node *a, node *b) {
  node *n = mk(P, t);
  if (n) { n->a = a; n->b = b; }
  return n; }

/* [..] at P->s just past the '[' */
static node *bracket(parser *P) {
  node *n = mk(P, N_SET);
  unsigned char *s = mkset(P);
  if (!n || !s) return 0;
  n->set = s;
  int neg = 0, first = 1;
  if (*P->s == '^') { neg = 1; P->s++; }
  if (!*P->s) { P->err = REG_BADPAT; return 0; }
  for (;;) {
    int c = (unsigned char) *P->s, lo;
    if (!c) { P->err = REG_EBRACK; return 0; }
    if (c == ']' && !first) { P->s++; break; }
    first = 0;
    if (c == '[' && (P->s[1] == ':' || P->s[1] == '=' || P->s[1] == '.')) {
      int k = P->s[1];
      char const *b = P->s + 2, *e = b;
      while (*e && !(e[0] == k && e[1] == ']')) e++;
      if (!*e) { P->err = REG_EBRACK; return 0; }
      size_t len = (size_t) (e - b);
      P->s = e + 2;
      if (k == ':') {
        int (*f)(int) = __ctclass(b, len);
        if (!f) { P->err = REG_ECTYPE; return 0; }
        for (int i = 1; i < 256; i++) if (f(i)) setc(P, s, i);
        if (P->icase && (len == 5 && (!strncmp(b, "upper", 5) || !strncmp(b, "lower", 5))))
          for (int i = 1; i < 256; i++) if (isalpha(i)) setb(s, i);
        continue; }
      if (len != 1) { P->err = REG_ECOLLATE; return 0; }
      lo = (unsigned char) *b;
      if (k == '=') { setc(P, s, lo); continue; } }
    else { lo = c; P->s++; }
    if (P->s[0] == '-' && P->s[1] && P->s[1] != ']') {
      int hi;
      P->s++;
      if (P->s[0] == '[' && P->s[1] == '.') {
        char const *b = P->s + 2, *e = b;
        while (*e && !(e[0] == '.' && e[1] == ']')) e++;
        if (!*e) { P->err = REG_EBRACK; return 0; }
        if (e - b != 1) { P->err = REG_ECOLLATE; return 0; }
        hi = (unsigned char) *b; P->s = e + 2; }
      else if (P->s[0] == '[' && (P->s[1] == ':' || P->s[1] == '=')) { P->err = REG_ERANGE; return 0; }
      else hi = (unsigned char) *P->s++;
      if (hi < lo) { P->err = REG_ERANGE; return 0; }
      for (int i = lo; i <= hi; i++) setc(P, s, i); }
    else setc(P, s, lo); }
  if (neg) {
    for (int i = 0; i < 32; i++) s[i] = (unsigned char) ~s[i];
    if (P->nl) s['\n' >> 3] &= (unsigned char) ~(1 << ('\n' & 7)); }
  s[0] &= (unsigned char) ~1;                     /* nul is never in the text */
  return n; }

static node *alt(parser *P, int depth);

/* \{m,n\} or {m,n} past the opening brace: 0 on a refusal */
static int interval(parser *P, int *mn, int *mx) {
  char const *s = P->s;
  int m = -1, n;
  if (isdigit((unsigned char) *s)) { m = 0; while (isdigit((unsigned char) *s)) { m = m * 10 + (*s++ - '0'); if (m > DUP_MAX) m = DUP_MAX + 1; } }
  if (*s == ',') {
    s++;
    if (isdigit((unsigned char) *s)) { n = 0; while (isdigit((unsigned char) *s)) { n = n * 10 + (*s++ - '0'); if (n > DUP_MAX) n = DUP_MAX + 1; } }
    else n = REP_INF;
    if (m < 0) m = 0; }
  else n = m;
  if (P->ext ? *s != '}' : (s[0] != '\\' || s[1] != '}')) {
    P->err = strstr(s, P->ext ? "}" : "\\}") ? REG_BADBR : REG_EBRACE; return 0; }
  if (m < 0 || m > DUP_MAX || n > DUP_MAX || (n != REP_INF && n < m)) { P->err = REG_BADBR; return 0; }
  P->s = s + (P->ext ? 1 : 2);
  *mn = m; *mx = n;
  return 1; }

static node *atom(parser *P, int depth, int *anchor) {
  int c = (unsigned char) *P->s;
  node *n;
  *anchor = 0;
  if (c == '\\') {
    int d = (unsigned char) P->s[1];
    if (!d) { P->err = REG_EESCAPE; return 0; }
    P->s += 2;
    if (!P->ext && d == '(') goto group;
    if (d >= '1' && d <= '9') {
      if (!(P->closed >> (d - '0') & 1)) { P->err = REG_ESUBREG; return 0; }
      n = mk(P, N_BREF); if (n) n->n = d - '0';
      P->bref = 1; return n; }
    if (d == 'w' || d == 'W' || d == 's' || d == 'S') {
      n = mk(P, N_SET); unsigned char *s = mkset(P);
      if (!n || !s) return 0;
      n->set = s;
      for (int i = 1; i < 256; i++) {
        int in = d == 'w' || d == 'W' ? (isalnum(i) || i == '_') : isspace(i) != 0;
        if (in == (d == 'w' || d == 's')) setb(s, i); }
      return n; }
    int a = d == 'b' ? A_WORDB : d == 'B' ? A_NWORDB : d == '<' ? A_WBEG : d == '>' ? A_WEND
          : d == '`' ? A_BUFBEG : d == '\'' ? A_BUFEND : -1;
    if (a >= 0) { n = mk(P, N_ASSERT); if (n) n->c = a; *anchor = 1; return n; }
    n = mk(P, N_CHAR); if (n) n->c = d;
    return n; }
  if (P->ext && c == '(') {
    P->s++;
  group:;
    int g = ++P->ngroup;
    node *in = alt(P, depth + 1);
    if (P->err) return 0;
    if (P->ext ? *P->s != ')' : (P->s[0] != '\\' || P->s[1] != ')')) { P->err = REG_EPAREN; return 0; }
    P->s += P->ext ? 1 : 2;
    if (g < 32) P->closed |= 1u << g;
    n = mk(P, N_GROUP); if (n) { n->a = in; n->n = g; }
    return n; }
  P->s++;
  if (c == '.') {
    n = mk(P, N_SET); unsigned char *s = mkset(P);
    if (!n || !s) return 0;
    n->set = s;
    for (int i = 1; i < 256; i++) if (!(P->nl && i == '\n')) setb(s, i);
    return n; }
  if (c == '[') return bracket(P);
  n = mk(P, N_CHAR); if (n) n->c = c;
  return n; }

/* one branch: atoms and their repetitions, until | ) or the end */
static node *cat(parser *P, int depth) {
  node *seq = mk(P, N_EMPTY), *eol = 0;
  int start = 1, begin = 1;
  while (!P->err) {
    char const *s = P->s;
    int c = (unsigned char) *s;
    if (!c) break;
    if (P->ext ? c == '|' : (c == '\\' && s[1] == '|')) break;
    if (P->ext ? (c == ')' && depth) : (c == '\\' && s[1] == ')')) break;
    node *a;
    int anchor = 0;
    if (c == '^' && (P->ext || begin)) { P->s++; a = mk(P, N_BOL); anchor = 1; if (a) a->n = !begin; }
    else if (c == '$' && (P->ext || !s[1] || (s[1] == '\\' && (s[2] == ')' || s[2] == '|')))) {
      P->s++; a = mk(P, N_EOL); anchor = 1; }
    else if (P->ext && (c == '*' || c == '+' || c == '?' || c == '{') && start) {
      P->err = REG_BADRPT; break; }
    else if (!P->ext && c == '*' && start) { P->s++; a = mk(P, N_CHAR); if (a) a->c = c; }
    else if (!P->ext && c == '\\' && s[1] == '{' && start) { P->err = REG_BADRPT; break; }
    else a = atom(P, depth, &anchor);
    if (P->err) break;
    int reps = 0;
    for (;;) {
      char const *t = P->s;
      int mn, mx;
      if (!P->ext && a && (a->t == N_BOL || a->t == N_ASSERT)) break;
      if (P->ext && anchor && (*t == '*' || *t == '+' || *t == '?' || *t == '{')) { P->err = REG_BADRPT; break; }
      if (!P->ext && reps && (*t == '*' || (t[0] == '\\' && t[1] == '{'))) { P->err = REG_BADRPT; break; }
      if (*t == '*') { P->s++; mn = 0; mx = REP_INF; }
      else if (P->ext && *t == '+') { P->s++; mn = 1; mx = REP_INF; }
      else if (P->ext && *t == '?') { P->s++; mn = 0; mx = 1; }
      else if (!P->ext && t[0] == '\\' && t[1] == '+') { P->s += 2; mn = 1; mx = REP_INF; }
      else if (!P->ext && t[0] == '\\' && t[1] == '?') { P->s += 2; mn = 0; mx = 1; }
      else if (P->ext ? *t == '{' : (t[0] == '\\' && t[1] == '{')) {
        P->s += P->ext ? 1 : 2;
        if (!interval(P, &mn, &mx)) break; }
      else break;
      if (anchor && P->ext) { P->err = REG_BADRPT; break; }
      node *r = mk(P, N_REP);
      if (r) { r->a = a; r->min = mn; r->max = mx; }
      a = r; anchor = 0; reps++; }
    if (P->err) break;
    if (eol) eol->n = 1;
    eol = a && a->t == N_EOL ? a : 0;
    seq = two(P, N_CAT, seq, a);
    start = !P->ext && a && (a->t == N_BOL || a->t == N_ASSERT);
    begin = 0; }
  return seq; }

/* a branch sees only the groups closed before its alternation or in itself */
static node *alt(parser *P, int depth) {
  unsigned before = P->closed, all;
  node *a = cat(P, depth);
  all = P->closed;
  while (!P->err && (P->ext ? *P->s == '|' : (P->s[0] == '\\' && P->s[1] == '|'))) {
    P->s += P->ext ? 1 : 2;
    P->closed = before;
    a = two(P, N_ALT, a, cat(P, depth));
    all |= P->closed; }
  P->closed = all;
  if (!P->err && !depth && *P->s) P->err = P->ext ? REG_ERPAREN : REG_EPAREN;
  return a; }

/* ---- the program ---- */
typedef struct { ins *p; int np, cp, nregs, err; } emitter;

static int emit(emitter *E, int op, int x, int y, unsigned char *set) {
  if (E->err) return 0;
  if (E->np >= PROG_MAX) { E->err = REG_ESIZE; return 0; }
  if (E->np == E->cp) {
    int c = E->cp ? 2 * E->cp : 64;
    ins *p = realloc(E->p, c * sizeof *p);
    if (!p) { E->err = REG_ESPACE; return 0; }
    E->p = p; E->cp = c; }
  E->p[E->np] = (ins) {op, x, y, set};
  return E->np++; }

static void gen(emitter *E, node *n, int icase) {
  if (!n || E->err) return;
  switch (n->t) {
  case N_EMPTY: return;
  case N_CHAR:
    if (icase && isalpha(n->c)) {
      emit(E, O_SPLIT, E->np + 1, E->np + 3, 0);
      emit(E, O_CHAR, tolower(n->c), 0, 0); emit(E, O_JMP, E->np + 2, 0, 0);
      emit(E, O_CHAR, toupper(n->c), 0, 0); }
    else emit(E, O_CHAR, n->c, 0, 0);
    return;
  case N_SET: emit(E, O_SET, 0, 0, n->set); return;
  case N_BOL: emit(E, O_BOL, n->n, 0, 0); return;
  case N_EOL: emit(E, O_EOL, n->n, 0, 0); return;
  case N_ASSERT: emit(E, O_ASSERT, n->c, 0, 0); return;
  case N_BREF: emit(E, O_BREF, n->n, 0, 0); return;
  case N_CAT: gen(E, n->a, icase); gen(E, n->b, icase); return;
  case N_GROUP:
    emit(E, O_SAVE, 2 * n->n, 0, 0); gen(E, n->a, icase); emit(E, O_SAVE, 2 * n->n + 1, 0, 0);
    return;
  case N_ALT: {
    int sp = emit(E, O_SPLIT, 0, 0, 0);
    if (E->err) return;
    E->p[sp].x = E->np; gen(E, n->a, icase);
    int j = emit(E, O_JMP, 0, 0, 0);
    if (E->err) return;
    E->p[sp].y = E->np; gen(E, n->b, icase);
    E->p[j].x = E->np;
    return; }
  case N_REP: {
    for (int i = 0; i < n->min; i++) gen(E, n->a, icase);
    if (n->max == REP_INF) {
      int k = E->nregs++;
      int l = emit(E, O_SPLIT, 0, 0, 0);
      if (E->err) return;
      E->p[l].x = E->np;
      emit(E, O_MARK, k, 0, 0); gen(E, n->a, icase);
      int ck = emit(E, O_CHECK, k, 0, 0);
      emit(E, O_JMP, l, 0, 0);
      if (E->err) return;
      E->p[l].y = E->p[ck].y = E->np;
      return; }
    int opt = n->max - n->min, *hole = opt ? malloc(opt * sizeof *hole) : 0;
    if (opt && !hole) { E->err = REG_ESPACE; return; }
    for (int i = 0; i < opt; i++) {
      hole[i] = emit(E, O_SPLIT, 0, 0, 0);
      if (E->err) break;
      E->p[hole[i]].x = E->np; gen(E, n->a, icase); }
    for (int i = 0; i < opt && !E->err; i++) E->p[hole[i]].y = E->np;
    free(hole);
    return; } } }

static void freeparse(parser *P, int keepsets) {
  for (int i = 0; i < P->nall; i++) free(P->all[i]);
  free(P->all);
  if (!keepsets) { for (int i = 0; i < P->nsets; i++) free(P->sets[i]); free(P->sets); } }

int regcomp(regex_t *re, char const *pat, int flags) {
  parser P = {0};
  P.s = pat; P.ext = flags & REG_EXTENDED; P.icase = flags & REG_ICASE; P.nl = flags & REG_NEWLINE;
  re->re_prog = 0; re->re_nsub = 0;
  node *root = alt(&P, 0);
  if (P.err) { freeparse(&P, 0); return P.err; }
  emitter E = {0};
  gen(&E, root, P.icase);
  emit(&E, O_MATCH, 0, 0, 0);
  freeparse(&P, 1);
  prog *g = E.err ? 0 : malloc(sizeof *g);
  if (!g) {
    free(E.p);
    for (int i = 0; i < P.nsets; i++) free(P.sets[i]);
    free(P.sets);
    return E.err ? E.err : REG_ESPACE; }
  *g = (prog) {E.p, E.np, E.nregs, P.bref, flags, (size_t) P.ngroup};
  /* the sets ride at the program's tail, so regfree finds them */
  unsigned char **keep = realloc(P.sets, (P.nsets + 1) * sizeof *keep);
  if (!keep) { free(E.p); free(g); for (int i = 0; i < P.nsets; i++) free(P.sets[i]); free(P.sets); return REG_ESPACE; }
  keep[P.nsets] = 0;
  re->re_prog = g; re->re_nsub = (size_t) P.ngroup;
  g->p[g->np - 1].set = (unsigned char *) keep;
  return 0; }

void regfree(regex_t *re) {
  prog *g = re->re_prog;
  if (!g) return;
  unsigned char **keep = (unsigned char **) g->p[g->np - 1].set;
  for (unsigned char **k = keep; *k; k++) free(*k);
  free(keep); free(g->p); free(g);
  re->re_prog = 0; }

/* ---- the search ---- */
typedef struct { int kind, a, b; } frame;      /* kind 0: branch (pc a, pos b); 1: restore slot a to b */
typedef struct {
  prog const *g; char const *s; int n, base, eflags, *slot, nslot;
  frame *st; int nst, cst;
  unsigned char *seen; int best, *bestslot, err; } run;

static int push(run *R, int k, int a, int b) {
  if (R->nst == R->cst) {
    int c = R->cst ? 2 * R->cst : 256;
    frame *f = realloc(R->st, c * sizeof *f);
    if (!f) { R->err = REG_ESPACE; return 0; }
    R->st = f; R->cst = c; }
  R->st[R->nst++] = (frame) {k, a, b};
  return 1; }

static int wordc(run *R, int i) {
  if (i < 0 || i >= R->n) return 0;
  int c = (unsigned char) R->s[i];
  return isalnum(c) || c == '_'; }

static int assert1(run *R, int a, int i) {
  int w0 = wordc(R, i - 1), w1 = wordc(R, i);
  switch (a) {
  case A_WORDB: return w0 != w1;
  case A_NWORDB: return w0 == w1;
  case A_WBEG: return !w0 && w1;
  case A_WEND: return w0 && !w1;
  case A_BUFBEG: return i == 0;
  default: return i == R->n; } }

/* every path from (0, at), the longest end kept: 1 when one matched */
static int search(run *R, int at) {
  prog const *g = R->g;
  int nl = g->flags & REG_NEWLINE, icase = g->flags & REG_ICASE;
  int pc = 0, i = at;
  for (int k = 0; k < R->nslot; k++) R->slot[k] = -1;
  R->nst = 0;
  for (;;) {
    ins const *p = g->p + pc;
    int ok = 1;
    if (R->seen) {
      size_t b = ((size_t) pc * (size_t) (R->n + 1) + (size_t) i) * 2 + (R->slot[R->nslot - 1] == i);
      if (R->seen[b >> 3] >> (b & 7) & 1) ok = 0;
      else R->seen[b >> 3] |= (unsigned char) (1 << (b & 7)); }
    if (ok) switch (p->op) {
    case O_CHAR: if (i < R->n && (unsigned char) R->s[i] == p->x) { i++; pc++; continue; } ok = 0; break;
    case O_SET: if (i < R->n && getb(p->set, (unsigned char) R->s[i])) { i++; pc++; continue; } ok = 0; break;
    case O_BOL:
      if ((i == 0 && !(R->eflags & REG_NOTBOL)) || (i > 0 && R->s[i - 1] == '\n' && (nl || (p->x && i > at)))) {
        pc++; continue; }
      ok = 0; break;
    case O_EOL:
      if ((i == R->n && !(R->eflags & REG_NOTEOL)) || (nl && i < R->n && R->s[i] == '\n')) { pc++; continue; }
      if (p->x && i < R->n && R->s[i] == '\n') {
        if (!push(R, 1, R->nslot - 1, R->slot[R->nslot - 1])) return 0;
        R->slot[R->nslot - 1] = i; pc++; continue; }
      ok = 0; break;
    case O_ASSERT: if (assert1(R, p->x, i)) { pc++; continue; } ok = 0; break;
    case O_SPLIT: if (!push(R, 0, p->y, i)) return 0; pc = p->x; continue;
    case O_JMP: pc = p->x; continue;
    case O_SAVE: if (!push(R, 1, p->x, R->slot[p->x])) return 0; R->slot[p->x] = i; pc++; continue;
    case O_MARK: {
      int r = 2 * ((int) g->nsub + 1) + p->x;
      if (!push(R, 1, r, R->slot[r])) return 0;
      R->slot[r] = i; pc++; continue; }
    case O_CHECK: pc = R->slot[2 * ((int) g->nsub + 1) + p->x] != i ? pc + 1 : p->y; continue;
    case O_BREF: {
      int so = R->slot[2 * p->x], eo = R->slot[2 * p->x + 1];
      if (so < 0 || eo < 0) { ok = 0; break; }
      int len = eo - so;
      if (i + len > R->n) { ok = 0; break; }
      for (int k = 0; k < len && ok; k++) {
        int a = (unsigned char) R->s[so + k], b = (unsigned char) R->s[i + k];
        if (icase ? tolower(a) != tolower(b) : a != b) ok = 0; }
      if (ok) { i += len; pc++; continue; }
      break; }
    case O_MATCH:
      if (R->slot[R->nslot - 1] == i) { ok = 0; break; }
      if (i > R->best) {
        R->best = i;
        memcpy(R->bestslot, R->slot, 2 * ((int) g->nsub + 1) * sizeof *R->slot);
        R->bestslot[0] = at; R->bestslot[1] = i;
        if (i == R->n) return 1; }
      ok = 0; break; }
    /* a dead end: undo back to the latest branch */
    for (;;) {
      if (!R->nst) return R->best >= 0;
      frame f = R->st[--R->nst];
      if (f.kind) { R->slot[f.a] = f.b; continue; }
      pc = f.a; i = f.b; break; } } }

int regexec(regex_t const *re, char const *str, size_t nm, regmatch_t *pm, int eflags) {
  prog const *g = re->re_prog;
  if (!g) return REG_BADPAT;
  int off = 0, n;
  if ((eflags & REG_STARTEND) && pm) { off = pm[0].rm_so; n = pm[0].rm_eo - pm[0].rm_so; }
  else n = (int) strlen(str);
  run R = {0};
  R.g = g; R.s = str + off; R.n = n; R.eflags = eflags;
  R.nslot = 2 * ((int) g->nsub + 1) + g->nregs + 1;
  R.slot = malloc((R.nslot + 2 * ((int) g->nsub + 1)) * sizeof *R.slot);
  if (!R.slot) return REG_ESPACE;
  R.bestslot = R.slot + R.nslot;
  size_t bits = (size_t) g->np * (size_t) (n + 1) * 2;
  if (!g->bref && bits <= ((size_t) 1 << 31)) R.seen = calloc(bits / 8 + 1, 1);
  int hit = 0;
  for (int at = 0; at <= n && !hit && !R.err; at++) {
    R.best = -1;
    hit = search(&R, at); }
  int err = R.err;
  free(R.st); free(R.seen);
  if (err) { free(R.slot); return err; }
  if (!hit) { free(R.slot); return REG_NOMATCH; }
  if (!(g->flags & REG_NOSUB) && pm)
    for (size_t k = 0; k < nm; k++) {
      int so = -1, eo = -1;
      if (k <= g->nsub && R.bestslot[2 * k] >= 0 && R.bestslot[2 * k + 1] >= 0) {
        so = R.bestslot[2 * k] + off; eo = R.bestslot[2 * k + 1] + off; }
      pm[k].rm_so = so; pm[k].rm_eo = eo; }
  free(R.slot);
  return 0; }

size_t regerror(int e, regex_t const *re, char *buf, size_t n) {
  static char const *const m[] = {
    "Success", "No match", "Invalid regular expression", "Invalid collation character",
    "Invalid character class name", "Trailing backslash", "Invalid back reference",
    "Unmatched [, [^, [:, [., or [=", "Unmatched ( or \\(", "Unmatched \\{", "Invalid content of \\{\\}",
    "Invalid range end", "Memory exhausted", "Invalid preceding regular expression",
    "Premature end of regular expression", "Regular expression too big", "Unmatched ) or \\)"};
  (void) re;
  char const *s = e >= 0 && e < (int) (sizeof m / sizeof *m) ? m[e] : "Unknown error";
  size_t len = strlen(s) + 1;
  if (n) { size_t k = len < n ? len : n; memcpy(buf, s, k - 1); buf[k - 1] = 0; }
  return len; }
