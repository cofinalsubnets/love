#include "i.h"

static size_t const vt_size[] = {
 [g_vt_i8]  = 1, [g_vt_i16] = 2, [g_vt_i32] = 4, [g_vt_i64] = 8,
 [g_vt_f32] = 4, [g_vt_f64] = 8,
};

uintptr_t g_vec_bytes(struct g_vec *v) {
 uintptr_t len = vt_size[v->type],
           rank = v->rank,
           *shape = v->shape;
 while (rank--) len *= *shape++;
 return sizeof(struct g_vec) + v->rank * sizeof(word) + len; }
