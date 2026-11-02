#include "../impl.h"
#include <search.h>

/* an avl tree; a node answered is a pointer to its key, as posix has it */
typedef struct tn { void const *key; struct tn *l, *r; int h; } tn;
typedef int (*cmpf)(void const *, void const *);

static int ht(tn *n) { return n ? n->h : 0; }
static void upd(tn *n) { int a = ht(n->l), b = ht(n->r); n->h = (a > b ? a : b) + 1; }
static tn *rotl(tn *n) { tn *r = n->r; n->r = r->l; r->l = n; upd(n); upd(r); return r; }
static tn *rotr(tn *n) { tn *l = n->l; n->l = l->r; l->r = n; upd(n); upd(l); return l; }
static tn *bal(tn *n) {
  upd(n);
  int d = ht(n->l) - ht(n->r);
  if (d > 1) { if (ht(n->l->r) > ht(n->l->l)) n->l = rotl(n->l); return rotr(n); }
  if (d < -1) { if (ht(n->r->l) > ht(n->r->r)) n->r = rotr(n->r); return rotl(n); }
  return n; }

static tn *ins(tn *n, void const *k, cmpf f, tn **hit) {
  if (!n) {
    n = malloc(sizeof *n);
    if (n) { n->key = k; n->l = n->r = 0; n->h = 1; }
    *hit = n;
    return n; }
  int c = f(k, n->key);
  if (!c) { *hit = n; return n; }
  if (c < 0) n->l = ins(n->l, k, f, hit); else n->r = ins(n->r, k, f, hit);
  return bal(n); }

void *tsearch(void const *k, void **root, cmpf f) {
  tn *hit = 0;
  if (!root) return 0;
  *root = ins(*root, k, f, &hit);
  return hit; }

void *tfind(void const *k, void *const *root, cmpf f) {
  if (!root) return 0;
  for (tn *n = *root; n; ) {
    int c = f(k, n->key);
    if (!c) return n;
    n = c < 0 ? n->l : n->r; }
  return 0; }

/* the least node of n, unlinked: *m takes it */
static tn *dmin(tn *n, tn **m) {
  if (!n->l) { *m = n; return n->r; }
  n->l = dmin(n->l, m);
  return bal(n); }

static tn *del(tn *n, void const *k, cmpf f, tn *up, void **ret) {
  if (!n) return 0;
  int c = f(k, n->key);
  if (c < 0) n->l = del(n->l, k, f, n, ret);
  else if (c > 0) n->r = del(n->r, k, f, n, ret);
  else {
    tn *m, *g = n;
    *ret = up;
    if (!n->l) n = n->r;
    else if (!n->r) n = n->l;
    else { tn *r = dmin(n->r, &m); m->l = n->l; m->r = r; n = m; }
    free(g);
    if (!n) return 0; }
  return bal(n); }

/* answers the deleted node's parent, the root slot when it was the root, 0 on a miss */
void *tdelete(void const *k, void **root, cmpf f) {
  void *ret = 0;
  if (!root || !*root) return 0;
  *root = del(*root, k, f, (tn *) root, &ret);
  return ret; }

static void walk(tn *n, void (*a)(void const *, VISIT, int), int d) {
  if (!n->l && !n->r) { a(n, leaf, d); return; }
  a(n, preorder, d);
  if (n->l) walk(n->l, a, d + 1);
  a(n, postorder, d);
  if (n->r) walk(n->r, a, d + 1);
  a(n, endorder, d); }

void twalk(void const *root, void (*a)(void const *, VISIT, int)) { if (root && a) walk((tn *) root, a, 0); }

void tdestroy(void *root, void (*f)(void *)) {
  tn *n = root;
  if (!n) return;
  tdestroy(n->l, f);
  tdestroy(n->r, f);
  f((void *) n->key);
  free(n); }
