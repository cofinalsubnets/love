; neon -- signs bent from glass tube: a stroke font, and a sign laid on a wall from it as
; three things a scene draws -- the tubes, lit by nothing but themselves; the halo they
; throw on the wall close by, glows added over it; and a lamp (mesh.l's) for the light
; they throw further off.
;
;   (neon-strokes s)                    s's strokes, polylines of [x y] in caps 1 tall,
;                                       and its width: [lines w]
;   (neon-sign s o al up out h col)     s laid from its bottom left o along al, up up, out of
;                                       the wall toward out, h metres tall, its light col:
;                                       {'tube pk 'halo pk 'lamp lamp 'w metres}
(module (neon neon-font neon-strokes neon-sign)
(borrow 'vec)
(borrow 'mesh)
(:
 ; --- the font: each glyph polylines on a grid 4 wide and 6 tall, y up, each line its
 ;     points' x y in a run ---
 neon-font
  {65 [[0 0 0 4 2 6 4 4 4 0] [0 3 4 3]]
   66 [[0 0 0 6 3 6 4 5 4 4 3 3 0 3] [3 3 4 2 4 1 3 0 0 0]]
   67 [[4 5 3 6 1 6 0 5 0 1 1 0 3 0 4 1]]
   68 [[0 0 0 6 2 6 4 4 4 2 2 0 0 0]]
   69 [[4 6 0 6 0 0 4 0] [0 3 3 3]]
   70 [[4 6 0 6 0 0] [0 3 3 3]]
   71 [[4 5 3 6 1 6 0 5 0 1 1 0 3 0 4 1 4 3 2 3]]
   72 [[0 0 0 6] [4 0 4 6] [0 3 4 3]]
   73 [[1 6 3 6] [2 6 2 0] [1 0 3 0]]
   74 [[4 6 4 1 3 0 1 0 0 1]]
   75 [[0 0 0 6] [4 6 0 2] [1 3 4 0]]
   76 [[0 6 0 0 4 0]]
   77 [[0 0 0 6 2 3 4 6 4 0]]
   78 [[0 0 0 6 4 0 4 6]]
   79 [[1 0 0 1 0 5 1 6 3 6 4 5 4 1 3 0 1 0]]
   80 [[0 0 0 6 3 6 4 5 4 4 3 3 0 3]]
   81 [[1 0 0 1 0 5 1 6 3 6 4 5 4 1 3 0 1 0] [2 2 4 0]]
   82 [[0 0 0 6 3 6 4 5 4 4 3 3 0 3] [2 3 4 0]]
   83 [[4 5 3 6 1 6 0 5 0 4 1 3 3 3 4 2 4 1 3 0 1 0 0 1]]
   84 [[0 6 4 6] [2 6 2 0]]
   85 [[0 6 0 1 1 0 3 0 4 1 4 6]]
   86 [[0 6 2 0 4 6]]
   87 [[0 6 1 0 2 4 3 0 4 6]]
   88 [[0 0 4 6] [0 6 4 0]]
   89 [[0 6 2 3 4 6] [2 3 2 0]]
   90 [[0 6 4 6 0 0 4 0]]
   48 [[1 0 0 1 0 5 1 6 3 6 4 5 4 1 3 0 1 0] [4 5 0 1]]
   49 [[1 5 2 6 2 0] [1 0 3 0]]
   50 [[0 5 1 6 3 6 4 5 4 4 0 0 4 0]]
   51 [[0 5 1 6 3 6 4 5 4 4 3 3 1 3] [3 3 4 2 4 1 3 0 1 0 0 1]]
   52 [[3 0 3 6 0 2 4 2]]
   53 [[4 6 0 6 0 3 3 3 4 2 4 1 3 0 1 0 0 1]]
   54 [[4 5 3 6 1 6 0 5 0 1 1 0 3 0 4 1 4 2 3 3 0 3]]
   55 [[0 6 4 6 1 0]]
   56 [[1 3 0 4 0 5 1 6 3 6 4 5 4 4 3 3 1 3 0 2 0 1 1 0 3 0 4 1 4 2 3 3]]
   57 [[4 3 1 3 0 4 0 5 1 6 3 6 4 5 4 1 3 0 1 0 0 1]]
   45 [[1 3 3 3]]
   46 [[1.7 0 2.3 0]]}
 adv 5.5                                ; a glyph's step across, in the grid's units
 (pairs l) (atom? l ? () ([(1.0 * <l) (1.0 * <>l)] . pairs >>l))
 ; ..s's strokes, the caps 1 tall: a letter not in the font a space, lower case as upper
 (neon-strokes s) (: cs (chars s) k (1.0 / 6.0)
   (go l x) (atom? l ? () (: c <l u (97 <= c <= 122 ? (c - 32) c)
                             (map (ln \ map (p \ [(k * (x + p 0)) (k * p 1)]) (pairs ln)) (peep neon-font u ()) + go >l (x + adv))))
   [(go cs 0.0) (k * (adv * #cs - adv + 4.0))])
 ; --- the sign: the tubes as three sides of a square a stroke, the halo a band either side
 ;     of each stroke on the wall, bright down its middle and gone at its edges ---
 (vx p c) [(p 0) (p 1) (p 2) 0.0 0.0 0.0 0.0 0.0 (c 0) (c 1) (c 2)]
 ; ..a triangle of vs turned so its front faces out
 (facing vs t out) (: a (vs (t 0)) b (vs (t 1)) c (vs (t 2))
   (dot (cross (c+ c (c* -1.0 a)) (c+ b (c* -1.0 a))) out < 0.0 ? [(t 0) (t 2) (t 1) -1] [(t 0) (t 1) (t 2) -1]))
 (piece vs ts out) (mesh vs (map (t \ facing vs t out) ts))
 (neon-sign s o al up out h col)
  (: sk (neon-strokes s) u (c* h al) v (c* h up)
     (at p d) (c+ o (c+ (c+ (c* (p 0) u) (c* (p 1) v)) (c* d out)))
     glass (cmix col [1.0 1.0 1.0] 0.15)          ; the tube's own colour, paler than its light
     segs (cats (map (ln \ (: (go l) (atom? >l ? () ([<l <>l] . go >l)) (go ln))) (sk 0)))
     rt (0.035 * h) hw (0.35 * h) lift (0.04 + rt)
     (tube g) (: A (at (g 0) lift) B (at (g 1) lift) t (unit (c+ B (c* -1.0 A))) n2 (unit (cross t out))
       (face o2 o3) (: (cn q k) (c+ q (c+ (c* rt o2) (c* (k * rt) o3)))
                       (piece (map (q \ vx q glass) [(cn A -1.0) (cn B -1.0) (cn B 1.0) (cn A 1.0)]) [[0 1 2] [0 2 3]] o2))
       (mesh-join [(face out n2) (face n2 out) (face (c* -1.0 n2) out)]))
     ; ..each band tapering to nothing past the stroke's ends, so they join without a seam
     (halo g) (: A (at (g 0) 0.004) B (at (g 1) 0.004) t (c* hw (unit (c+ B (c* -1.0 A)))) n2 (c* hw (unit (cross t out)))
       z [0.0 0.0 0.0] (e p) (vx p z) (m p) (vx p col) (neg v) (c* -1.0 v)
       (row q k) [(e (c+ q n2)) (k q) (e (c+ q (neg n2)))]
       (piece (row (c+ A (neg t)) e + row A m + row B m + row (c+ B t) e)
              (cats (map (r \ (: a (3 * r) [[a (a + 1) (a + 4)] [a (a + 4) (a + 3)] [(a + 1) (a + 2) (a + 5)] [(a + 1) (a + 5) (a + 4)]])) ^3))
              out))
     pts (cats (map (g \ [(at (g 0) lift) (at (g 1) lift)]) segs))
     {'tube (mesh-pack (mesh-join (map tube segs))) 'halo (mesh-pack (mesh-join (map halo segs)))
      'lamp {'at pts 'c col 'r (6.0 * h + 2.0) 'soft (0.5 * h)} 'w (h * sk 1)}))
) ; module neon
