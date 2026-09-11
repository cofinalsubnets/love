// lv.h -- love as a library. the whole surface a host program sees: no love.h,
// no struct ai, no word. one session, a value stack, and indices into it.
//
// the stack IS the handle table. love's collector copies, so every heap pointer
// moves; a value is safe exactly while it sits on the session's own stack, which
// the collector walks. so nothing here hands back a value -- it hands back an
// index, and lv_tostr's bytes die at the next call that can allocate.
//
// errors are return values, never a longjmp: love encodes a condition in the low
// bits of the state pointer, so a scare unwinds to the caller as -1 with the
// session still readable. a host language's exception is thrown by the host.
#ifndef _lv_h
#define _lv_h
#include <stddef.h>
#include <stdint.h>

struct lv;

// the kinds a host can tell apart. lv_other is everything love has and a foreign
// caller has no word for (mints, trays, tablets) -- still passable by index,
// just not readable as a C scalar.
enum lv_type { lv_nil, lv_int, lv_flo, lv_str, lv_sym, lv_list, lv_fn_t, lv_other };

// what a host callback sees: the session, its own userdata, and n arguments at
// indices 0..n-1. push one answer and return 0; return -1 to scare.
typedef int (*lv_fn)(struct lv*, void *ud, int n);

// a write the session made (fd 1 or 2). NULL routes to the process's own stdout.
typedef void (*lv_writer)(void *ud, int fd, char const *s, size_t n);

struct lv_opt {
  lv_writer write;
  void *write_ud;
  size_t budget_mb;   // 0 = the runtime's default
  void const *image;  // a heap image to wake from, instead of baking the egg
  size_t image_len;
};

struct lv *lv_open(struct lv_opt const*);   // NULL opts = defaults
void lv_close(struct lv*);
// bake this session to a fresh buffer the caller frees with lv_free. bytes, not
// a path: an embedded love owns no filesystem, and the host already has one.
void *lv_save(struct lv*, size_t *len);
void lv_free(void*);

// --- running ---------------------------------------------------------------
int lv_eval(struct lv*, char const *src);   // eval source, push the last value
int lv_apply(struct lv*, int nargs);        // apply the value under nargs args
int lv_global(struct lv*, char const *name);// push the value a name is bound to
int lv_ok(struct lv const*);
char const *lv_error(struct lv*);           // the last condition, shown; "" if none

// --- the stack -------------------------------------------------------------
// index 0 is the top; a bigger index is deeper.
int lv_top(struct lv const*);
void lv_pop(struct lv*, int n);
int lv_dup(struct lv*, int idx);

int lv_pushnil(struct lv*);
int lv_pushint(struct lv*, intptr_t);
int lv_pushflo(struct lv*, double);
int lv_pushstr(struct lv*, char const*, size_t);   // n == (size_t)-1 measures it

// --- reading ---------------------------------------------------------------
enum lv_type lv_type_at(struct lv*, int idx);
intptr_t lv_toint(struct lv*, int idx);            // 0 if it is not an integer
double lv_toflo(struct lv*, int idx);
char const *lv_tostr(struct lv*, int idx, size_t *len);  // borrowed; dies on the next call
size_t lv_strcpy(struct lv*, int idx, char *dst, size_t cap);  // the copying door
int lv_count(struct lv*, int idx);                 // tally, or -1
int lv_at(struct lv*, int idx, int i);             // push element i of a list or string

// --- host code as love code -------------------------------------------------
// bind name to a C function of arity n. the cell is immortal by construction
// (the session keeps it), which is what ai_defn asks of every definition.
int lv_defn(struct lv*, char const *name, int arity, lv_fn, void *ud);

#endif
