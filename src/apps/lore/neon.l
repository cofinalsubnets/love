; neon -- signs bent from glass tube: a stroke font, and a sign laid on a wall as three things
; a scene draws -- the tubes, lit by nothing but themselves; a glow round them, off the wall;
; and a lamp (mesh.l's) for the light on the wall and further off.
; (neon-strokes s) answers [lines w], polylines of [x y] in caps 1 tall; (neon-sign s o al up
; out h col) lays s from its bottom left o, h metres tall: {'tube pk 'halo pk 'lamp lamp 'w metres}
(module (neon neon-font neon-strokes neon-sign)
(borrow '(vec mesh))
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
   46 [[1.7 0 2.3 0]]
   40 [[3 6 1.6 5 1 3 1.6 1 3 0]]
   41 [[1 6 2.4 5 3 3 2.4 1 1 0]]
   ; ..and a few hanzi, 6 wide, by their code points
   0x6208 [[0.5 4 5.5 4] [2.6 6 3 3.2 4.4 1.2 5.6 0 6 1.2] [0.8 0 4.6 3] [4.4 5.9 5.2 5.2]]             ; 戈
   0x6587 [[3 6 3 5.2] [0.3 4.8 5.7 4.8] [4.5 4.8 3.1 2.1 0.3 0] [1.5 4.8 2.9 2.1 5.8 0]]             ; 文
   0x5929 [[0.5 5.5 5.5 5.5] [0 3.5 6 3.5] [3 5.5 3 3.5 1.6 1.2 0 0] [3 3.5 4.4 1.2 6 0]]                 ; 天
   0x7136 [[1.3 6 0.3 4.4] [0.9 5.3 2.6 5.3 2 3.7 0.3 2.6] [0.9 4.3 1.8 3.6]
           [3 4.8 6 4.8] [4.6 6 4.4 4 3 2.5] [4.5 4.2 6 2.5] [5.3 6 5.8 5.5]
           [0.6 1.3 0.2 0.2] [2.1 1.3 2.3 0.2] [3.8 1.3 4.1 0.2] [5.4 1.3 6 0.2]]                         ; 然
   0x98DF [[3 6 0 4] [3 6 6 4] [2.2 4.4 3.8 4.4] [1.2 3.6 4.8 3.6 4.8 1.6 1.2 1.6]
           [1.2 2.6 4.8 2.6] [1.2 3.6 1.2 0.2 3 1.2] [3.3 1.6 6 0]]                                       ; 食
   0x54C1 [[1.8 6 4.2 6 4.2 4 1.8 4 1.8 6] [0 3 2.6 3 2.6 0 0 0 0 3] [3.4 3 6 3 6 0 3.4 0 3.4 3]]       ; 品
   0x4E2D [[0.5 4.5 5.5 4.5 5.5 1.8 0.5 1.8 0.5 4.5] [3 6 3 0]]                                         ; 中
   0x5FC3 [[0.2 1.5 0.8 3] [1.8 4 1.8 0.8 2.8 0 5 0 5.3 1.2] [2.8 5.6 3.6 4.2] [4.8 4.2 5.8 2.6]]}     ; 心
 adv 5.5                                ; a glyph's step across, in the grid's units
 (pairs l) (atom? l ? () ([(1.0 * <l) (1.0 * <>l)] . pairs >>l))
 ; ..s's code points, its utf-8 read
 (points s) (: n #s (go i) (? (i >= n) ()
                                (s i < 0xE0) ((s i < 0x80 ? (s i) 63) . go (i + (s i < 0x80 ? 1 (s i < 0xC0 ? 1 2))))
                                (i + 2 < n) ((((s i & 15) << 12) | ((s (i + 1) & 63) << 6) | (s (i + 2) & 63)) . go (i + 3))
                                ())
   (go 0))
 ; ..s's strokes, the caps 1 tall: a letter not in the font a space, lower case as upper;
 ; a hanzi 6 wide where a letter is 4
 (neon-strokes s) (: cs (points s) k (1.0 / 6.0)
   (wd c) (c > 255 ? 6.0 4.0)
   (go l x) (atom? l ? () (: c <l u (97 <= c <= 122 ? (c - 32) c)
                             (map (ln \ map (p \ [(k * (x + p 0)) (k * p 1)]) (pairs ln)) (neon-font u) + go >l (x + wd c + 1.5))))
   [(go cs 0.0) (k * (foldl (\ a c (a + wd c + 1.5)) 0.0 cs - 1.5))])
 ; --- the sign: the tubes as three sides of a square a stroke, run on past a joint to close
 ;     it; the halo one band a line, level with the tube, mitred at each joint and rounded at
 ;     each end, a bell across ---
 (vx p c) [(p 0) (p 1) (p 2) 0.0 0.0 0.0 0.0 0.0 (c 0) (c 1) (c 2)]
 ; ..a triangle of vs turned so its front faces out
 (facing vs t out) (: a (vs (t 0)) b (vs (t 1)) c (vs (t 2))
   (dot (cross (c+ c (c* -1.0 a)) (c+ b (c* -1.0 a))) out < 0.0 ? [(t 0) (t 2) (t 1) -1] [(t 0) (t 1) (t 2) -1]))
 (piece vs ts out) (mesh vs (map (t \ facing vs t out) ts))
 (neon-sign s o al up out h col)
  (: sk (neon-strokes s) u (c* h al) v (c* h up)
     (at p d) (c+ o (c+ (c+ (c* (p 0) u) (c* (p 1) v)) (c* d out)))
     glass (cmix col [1.0 1.0 1.0] 0.15)          ; the tube's own colour, paler than its light
     ; ..a line's segments, each [p q ea eb], ea eb 1 where it runs on into a neighbour
     (shut? ln) (#ln > 2 && ln 0 = ln (#ln - 1))
     (joins ln) (: n (#ln - 1) s (shut? ln) (map (i \ [(ln i) (ln (i + 1)) (s || i > 0 ? 1 0) (s || i < n - 1 ? 1 0)]) ^n))
     segs (catmap joins (sk 0)) ls (sk 0)
     ; ..an end left without a cap where it lands on a stroke, or on a point of a line before
     ; it: the glow already there, a cap would double it
     (on? p a b) (: dx (b 0 - a 0) dy (b 1 - a 1) t (((p 0 - a 0) * dx + (p 1 - a 1) * dy) / (dx * dx + dy * dy))
                   ex (a 0 + t * dx - p 0) ey (a 1 + t * dy - p 1)
                   (1e-6 < t && t < 1.0 - 1e-6 && ex * ex + ey * ey < 1e-8))
     (bare? k p) !(any (ln \ any (i \ on? p (ln i) (ln (i + 1))) ^(#ln - 1)) ls
                   || any (j \ any (q \ abs (q 0 - p 0) + abs (q 1 - p 1) < 1e-6) (ls j)) ^k)
     rt (0.035 * h) lift (0.04 + rt)
     (tube g) (: P (at (g 0) lift) Q (at (g 1) lift) t (unit (c- Q P)) n2 (unit (cross t out))
       A (c+ P (c* (rt * -1.0 * g 2) t)) B (c+ Q (c* (rt * g 3) t))
       (face o2 o3) (: (cn q k) (c+ q (c+ (c* rt o2) (c* (k * rt) o3)))
                       (piece (map (q \ vx q glass) [(cn A -1.0) (cn B -1.0) (cn B 1.0) (cn A 1.0)]) [[0 1 2] [0 2 3]] o2))
       (mesh-join [(face out n2) (face n2 out) (face (c* -1.0 n2) out)]))
     hw (0.06 + 0.2 * h) gain 1.5 rs [0.15 0.45 1.0] rb [0.6 0.15 0.0] K 6
     across [-1.0 -0.45 -0.15 0.0 0.15 0.45 1.0] bell [0.0 0.15 0.6 1.0 0.6 0.15 0.0]
     (lit k) (c* (gain * k) col)
     (strip m nr) (catmap (i \ catmap (j \ (: a (m * i + j) [[a (a + 1) (a + m + 1)] [a (a + m + 1) (a + m)]])) ^(m - 1)) ^(nr - 1))
     ; ..a half disc of the bell round end c, from n through t, its rim on the band's; its
     ; middle as bright as the band beside the tube, there being no tube over it
     (cap c n t) (: (dir k) (: f (pi * k / K) (c+ (c* (cos f) n) (c* (sin f) t)))
                    (ix r k) (1 + r * (K + 1) + k)
                    (piece ([(vx c (lit 0.75))] + catmap (r \ map (k \ vx (c+ c (c* (hw * rs r) (dir k))) (lit (rb r))) ^(K + 1)) ^3)
                           (map (k \ [0 (ix 0 k) (ix 0 (k + 1))]) ^K
                            + catmap (r \ catmap (k \ [[(ix r k) (ix r (k + 1)) (ix (r + 1) (k + 1))] [(ix r k) (ix (r + 1) (k + 1)) (ix (r + 1) k)]]) ^K) ^2)
                           out))
     (halo k) (: ln (ls k) ps (map (p \ at p lift) ln) n #ps s (shut? ln)
       (nm i j) (unit (cross (c- (ps j) (ps i)) out))
       sn (map (i \ nm i (i + 1)) ^(n - 1))
       ; ..each point's mitre: the two sides' normals halved, as long as keeps the band hw wide
       (mitre a b) (dot a b < -0.9 ? a (: m (unit (c+ a b)) (c* (1.0 / max 0.5 (dot m a)) m)))
       (dv i) (? (i = 0) (s ? (mitre (sn (n - 2)) (sn 0)) (sn 0)) (i = n - 1) (s ? (mitre (sn (n - 2)) (sn 0)) (sn (n - 2)))
                 (mitre (sn (i - 1)) (sn i)))
       band (piece (catmap (i \ (: d (dv i) (map (j \ vx (c+ (ps i) (c* (hw * across j) d)) (lit (bell j))) ^7))) ^n) (strip 7 n) out)
       (s ? band (mesh-join ([band] + (bare? k (ln 0) ? [(cap (ps 0) (sn 0) (unit (c- (ps 0) (ps 1))))] ())
                                     + (bare? k (ln (n - 1)) ? [(cap (ps (n - 1)) (sn (n - 2)) (unit (c- (ps (n - 1)) (ps (n - 2)))))] ())))))
     ; ..its light from the strokes' ends, one to each half-height square, so a busy glyph
     ; costs a lamp no more than a plain one; held off the wall and soft, so the wall it lights
     ; takes no spot from any one of them
     q (0.5 * h) (cell v) (show (map (k \ floor (v k / q + 0.5)) ^3))
     ends (foldl (\ t v (pin t (cell v) v)) {} (catmap (g \ [(at (g 0) (lift + 0.5 * h)) (at (g 1) (lift + 0.5 * h))]) segs))
     pts (map ends (sort (keys ends)))
     {'tube (mesh-pack (mesh-join (map tube segs))) 'halo (mesh-pack (mesh-join (map halo ^#ls)))
      'lamp {'at pts 'c col 'r (6.0 * h + 2.0) 'soft h 'wrap 0.6} 'w (h * sk 1)}))
) ; module neon
