#include "i.h"

size_t const g_vt_size[] = {
 [g_vt_i8]  = 1, [g_vt_i16] = 2, [g_vt_i32] = 4, [g_vt_i64] = 8,
 [g_vt_f32] = 4, [g_vt_f64] = 8,
 [g_vt_cplx] = 2 * sizeof(g_flo_t), };   // complex scalar: (re, im)

uintptr_t g_vec_bytes(struct g_vec *v) {
 uintptr_t len = g_vt_size[v->type],
           rank = v->rank,
           *shape = v->shape;
 while (rank--) len *= *shape++;
 return sizeof(struct g_vec) + v->rank * sizeof(word) + len; }
