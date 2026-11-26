; tumble -- rigid bodies that fall, bounce, roll and come to rest: spheres and boxes, each with a
; mass, a spin and how hard it is to turn, against brushes held still. a brush is a list of
; planes [n d], n unit and outward, its inside where n . x <= d; one plane is a half space, a
; floor or a slope. a step solves the contacts by impulses: each pushes along its normal and
; no harder than it must, friction across it no more than mu times that, a bounce kept only
; from a real blow, and a body still a while sleeps until something wakes it.
; (tb-sphere p r m) (tb-box p h m) a body at p, radius r or half its sides h, of mass m; then
;   pins for 'e (bounce) 'mu (friction) 'roll (rolling drag) 'q 'v 'w
; (tb-floor n d) a half-space brush; (tb-world bodies brushes) {'bodies 'brushes 'g}
; (tb-step W dt) on in substeps no longer than tb-h, by tumble-step in C (src/love/tumble.c), or
;   here where W's 'engine is 'love; (tb-energy W) kinetic plus height's
(module (tumble tb-sphere tb-box tb-floor tb-world tb-step tb-energy tb-wake tb-rot tb-corners tb-h qaxis qmul)
(borrow 'vec)
(borrow 'lore)                          ; tumble-step, in C
(:
 tb-h (1.0 / 240.0)                      ; the longest substep
 tb-iters 30                             ; passes over the contacts each substep: fewer, and a box
                                         ; landing square comes up turning
 slop 0.002 fix-k 0.4                    ; depth let be, and how much of the rest a substep takes back
 bounce-min 0.6                          ; slower than this into a contact, no bounce
 rest-v 0.05 rest-t 0.5                  ; slower than this, this long, touching: asleep
 ; --- quaternions [w x y z] ---
 (qmul a b) [(a 0 * b 0 - a 1 * b 1 - a 2 * b 2 - a 3 * b 3)
             (a 0 * b 1 + a 1 * b 0 + a 2 * b 3 - a 3 * b 2)
             (a 0 * b 2 - a 1 * b 3 + a 2 * b 0 + a 3 * b 1)
             (a 0 * b 3 + a 1 * b 2 - a 2 * b 1 + a 3 * b 0)]
 (qnorm q) (: l (sqrt (q 0 * q 0 + q 1 * q 1 + q 2 * q 2 + q 3 * q 3)) (map (x \ x / l) q))
 (qaxis k a) (: s (sin (0.5 * a)) u (unit k) [(cos (0.5 * a)) (s * u 0) (s * u 1) (s * u 2)])
 ; ..its rotation, row by row
 (tb-rot q) (: w (q 0) x (q 1) y (q 2) z (q 3)
   [[(1.0 - 2.0 * (y * y + z * z)) (2.0 * (x * y - w * z)) (2.0 * (x * z + w * y))]
    [(2.0 * (x * y + w * z)) (1.0 - 2.0 * (x * x + z * z)) (2.0 * (y * z - w * x))]
    [(2.0 * (x * z - w * y)) (2.0 * (y * z + w * x)) (1.0 - 2.0 * (x * x + y * y))]])
 (mv m v) [(dot (m 0) v) (dot (m 1) v) (dot (m 2) v)]
 (mtv m v) (c+ (c+ (c* (v 0) (m 0)) (c* (v 1) (m 1))) (c* (v 2) (m 2)))
 ; ..the inverse inertia in the world, R its rotation, applied to v
 (iw b R v) (mv R (cm (b 'ii) (mtv R v)))
 ; --- bodies ---
 (body sh p m ii more) (foldl (\ t k (pin t k (more k))) {'shape sh 'm m 'im (1.0 / m) 'ii ii 'p p 'q [1.0 0.0 0.0 0.0]
                                                       'v [0.0 0.0 0.0] 'w [0.0 0.0 0.0] 'e 0.5 'mu 0.5 'roll 0.0 'idle 0.0 'still 0}
                              (keys more))
 (tb-sphere p r m) (: k (2.5 / (m * r * r)) (body 'sphere p m [k k k] {'r r 'roll 0.02}))
 (tb-box p h m) (: (k a b) (3.0 / (m * (2 (h a) + 2 (h b)))) (body 'box p m [(k 1 2) (k 0 2) (k 0 1)] {'h h}))
 (tb-floor n d) [[(unit n) d]]
 (tb-world bs brs) {'bodies bs 'brushes brs 'g [0.0 -9.81 0.0] 't 0.0}
 (tb-wake b) (pins b 'still 0 'idle 0.0)
 ; ..a box's corners in the world
 (tb-corners b) (: R (tb-rot (b 'q)) h (b 'h)
   (map (s \ c+ (b 'p) (mtv (map (k \ [(R 0 k) (R 1 k) (R 2 k)]) ^3) [(s 0 * h 0) (s 1 * h 1) (s 2 * h 2)]))
        [[-1.0 -1.0 -1.0] [1.0 -1.0 -1.0] [-1.0 1.0 -1.0] [1.0 1.0 -1.0] [-1.0 -1.0 1.0] [1.0 -1.0 1.0] [-1.0 1.0 1.0] [1.0 1.0 1.0]]))
 ; --- contacts: the plane of brush B a point x stands furthest out of, [s n] ---
 (most B x) (foldl (\ a pl (: s (dot (pl 0) x - pl 1) (s > a 0 ? [s (pl 0)] a))) [-1e9 [0.0 1.0 0.0]] B)
 (col R k) [(R 0 k) (R 1 k) (R 2 k)]
 ; ..a box as a brush: its six faces where it stands
 (faces b) (: R (b 'R) p (b 'p) (catmap (k \ (: u (col R k) o (dot u p) [[u (o + b 'h k)] [(c* -1.0 u) (b 'h k - o)]])) ^3))
 ; ..at x, along n out of b into a, d deep, b () for a brush: the axes across it, how hard
 ; the two are to move apart each way there, and the bounce a real blow keeps
 (rel a ra b rb) (: va (vel a ra) (tablet? b ? (c- va (vel b rb)) va))
 (contact a b n x d) (: ra (c- x (a 'p)) rb (tablet? b ? (c- x (b 'p)) ()) t1 (side n) t2 (cross n t1)
   (k1 o r u) (o 'im + dot u (cross (iw o (o 'R) (cross r u)) r))
   (eff u) (k1 a ra u + (tablet? b ? (k1 b rb u) 0.0))
   vn (dot (rel a ra b rb) n) e (tablet? b ? (max (a 'e) (b 'e)) (a 'e))
   {'a a 'b b 'n n 'ra ra 'rb rb 'd d 't1 t1 't2 t2 'kn (eff n) 'k1 (eff t1) 'k2 (eff t2) 'jn 0.0 'j1 0.0 'j2 0.0
    'mu (tablet? b ? (sqrt (a 'mu * b 'mu)) (a 'mu)) 'bias (vn < 0.0 - bounce-min ? (0.0 - e * vn) 0.0)})
 ; ..a body against a brush
 (contacts b B) (? (b 'shape = 'sphere)
                   (: c (b 'p) h (most B c) (h 0 < b 'r ? [(contact b () (h 1) (c- c (c* (b 'r) (h 1))) (b 'r - h 0))] ()))
                   (catmap (x \ most B x @ h (h 0 < 0.0 ? [(contact b () (h 1) x (0.0 - h 0))] ())) (tb-corners b)))
 ; ..two bodies, as [n x d] with n out of b into a
 (sph-sph a b) (: u (c- (a 'p) (b 'p)) l (mag3 u) d (a 'r + b 'r - l)
   (d > 0.0 && l > 1e-9 ? (c* (1.0 / l) u @ n [[n (c+ (b 'p) (c* (b 'r) n)) d]]) ()))
 ; ..a sphere a and a box b: the box's nearest point, or its nearest face from inside
 (sph-box a b) (: R (b 'R) c (mtv R (c- (a 'p) (b 'p))) h (b 'h) r (a 'r)
   q (map (k \ max (0.0 - h k) (min (h k) (c k))) ^3) u (c- c q) l (mag3 u)
   (? (l > 1e-9) (l < r ? (: n (mv R (c* (1.0 / l) u)) [[n (c+ (b 'p) (mv R q)) (r - l)]]) ())
      (: f (most (faces b) (a 'p)) [[(f 1) (a 'p) (r - f 0)]])))
 ; ..two boxes: of their fifteen axes, faces' and edges' crossed, the one they overlap least
 ; along. on a face, the other's corners through it within its edges, and its own corners
 ; inside the other; on two edges, the nearest points between them
 (sgn x) (x < 0.0 ? -1.0 1.0)
 (span b L) (net (map (k \ b 'h k * mag (dot (col (b 'R) k) L)) ^3))
 (inside? b x e) (: u (c- x (b 'p)) (all (k \ mag (dot (col (b 'R) k) u) <= b 'h k + e) ^3))
 (on-face? b k x e) (: u (c- x (b 'p)) (all (j \ j = k || mag (dot (col (b 'R) j) u) <= b 'h j + e) ^3))
 (box-axes a b) (: A (map (col (a 'R)) ^3) B (map (col (b 'R)) ^3)
   (map (k \ ['fa k () (A k)]) ^3 + map (k \ ['fb k () (B k)]) ^3
    + catmap (i \ catmap (j \ (: L (cross (A i) (B j)) l (mag3 L) (l < 1e-5 ? () [['ee i j (c* (1.0 / l) L)]]))) ^3) ^3))
 (box-box a b) (: d (c- (a 'p) (b 'p))
   ; ..each axis's overlap, n turned from b toward a; edges must beat faces by a little
   os (map (x \ (: L (x 3) s (dot d L) [(span a L + span b L - mag s) (s < 0.0 ? (c* -1.0 L) L) x])) (box-axes a b))
   (better o q) (: w (o 2 0 = 'ee ? 1.05 1.0) v (q 2 0 = 'ee ? 1.05 1.0) (w * o 0 + 0.001 * (w - 1.0) < v * q 0))
   best (foldl (\ q o (better o q ? o q)) (os 0) >os)
   ov (best 0) n (best 1) x (best 2) tol 0.005
   (? (any (o \ o 0 < 0.0) os) ()
      ; ..a face of b: a's corners through it, b's face corners inside a
      (x 0 = 'fb) (: k (x 1) P (dot n (b 'p) + b 'h k)
                     (filter two? (map (c \ (: e (P - dot n c) (e > 0.0 && on-face? b k c tol ? [n c e] ()))) (tb-corners a))
                      + filter two? (map (c \ (dot n c > P - tol && inside? a c tol ? [n c ov] ())) (tb-corners b))))
      ; ..a face of a, the same turned about
      (x 0 = 'fa) (: k (x 1) m (c* -1.0 n) P (dot m (a 'p) + a 'h k)
                     (filter two? (map (c \ (: e (P - dot m c) (e > 0.0 && on-face? a k c tol ? [n c e] ()))) (tb-corners b))
                      + filter two? (map (c \ (dot m c > P - tol && inside? b c tol ? [n c ov] ())) (tb-corners a))))
      ; ..edge i of a nearest b, edge j of b nearest a, and the middle of their nearest points
      (: i (x 1) j (x 2) Ra (a 'R) Rb (b 'R) ai (col Ra i) bj (col Rb j)
         ca (foldl (\ s k (k = i ? s (c+ s (c* (sgn (0.0 - dot (col Ra k) n) * a 'h k) (col Ra k))))) (a 'p) ^3)
         cb (foldl (\ s k (k = j ? s (c+ s (c* (sgn (dot (col Rb k) n) * b 'h k) (col Rb k))))) (b 'p) ^3)
         r (c- ca cb) e (dot ai bj) dn (1.0 - e * e)
         sa (max (0.0 - a 'h i) (min (a 'h i) (dn < 1e-9 ? 0.0 ((e * dot bj r - dot ai r) / dn))))
         tb (max (0.0 - b 'h j) (min (b 'h j) (e * sa + dot bj r)))
         [[n (c* 0.5 (c+ (c+ ca (c* sa ai)) (c+ cb (c* tb bj)))) ov]])))
 (touching a b) (? (a 'shape = 'sphere && b 'shape = 'sphere) (sph-sph a b)
                   (a 'shape = 'sphere) (sph-box a b)
                   (b 'shape = 'sphere) (map (t \ [(c* -1.0 (t 0)) (t 1) (t 2)]) (sph-box b a))
                   (box-box a b))
 (reach b) (b 'shape = 'sphere ? (b 'r) (mag3 (b 'h)))
 ; ..each pair near enough with one awake. a sleeper is held still against one barely moving,
 ; and woken by one moving faster than wake-v
 wake-v 0.3
 (pairs bs) (: n #bs
   (catmap (i \ catmap (j \ (: a (bs i) b (bs j)
                             (? (a 'still = 1 && b 'still = 1) ()
                                (: u (c- (a 'p) (b 'p)) r (reach a + reach b)
                                   (dot u u > r * r ? ()
                                      (: ts (touching a b)
                                         (? (atom? ts) ()
                                            (a 'still = 1 && mag3 (b 'v) + mag3 (b 'w) * reach b > wake-v) (tb-wake a, ())
                                            (b 'still = 1 && mag3 (a 'v) + mag3 (a 'w) * reach a > wake-v) (tb-wake b, ())
                                            (a 'still = 1) (map (t \ contact b () (c* -1.0 (t 0)) (t 1) (t 2)) ts)
                                            (b 'still = 1) (map (t \ contact a () (t 0) (t 1) (t 2)) ts)
                                            (map (t \ contact a b (t 0) (t 1) (t 2)) ts))))))))
                        (drop (i + 1) ^n))
           ^n))
 ; --- the solve: an impulse J at r, and its opposite on the other ---
 (push! b r J) (pins b 'v (c+ (b 'v) (c* (b 'im) J)) 'w (c+ (b 'w) (iw b (b 'R) (cross r J))))
 (push2! c J) (push! (c 'a) (c 'ra) J, tablet? (c 'b) ? (push! (c 'b) (c 'rb) (c* -1.0 J)) 0)
 (vel b r) (c+ (b 'v) (cross (b 'w) r))
 (solve1 c) (: a (c 'a) b (c 'b) n (c 'n) (v _) (rel a (c 'ra) b (c 'rb))
   jn (max 0.0 (c 'jn + (c 'bias - dot (v ()) n) / c 'kn)) dn (jn - c 'jn)
   _ (pin c 'jn jn, push2! c (c* dn n))
   lim (c 'mu * jn)
   (fr ka ja t) (: j (max (0.0 - lim) (min lim (c ja - dot (v ()) t / c ka))) dj (j - c ja)
                   (pin c ja j, push2! c (c* dj t)))
   (fr 'k1 'j1 (c 't1), fr 'k2 'j2 (c 't2)))
 ; ..and what is left sunk, taken back a part: shared between the two by how light each is,
 ; and among a body's contacts
 (unsink! cs) (: (k o) #(filter (q \ q 'a == o || q 'b == o) cs)
   (each cs (c \ (: a (c 'a) b (c 'b) d (c 'd)
                   (d > slop ? (: m (tablet? b ? (b 'im) 0.0) s (fix-k * (d - slop) / (a 'im + m))
                                  _ (pin a 'p (c+ (a 'p) (c* (s * a 'im / k a) (c 'n))))
                                  (tablet? b ? (pin b 'p (c+ (b 'p) (c* (0.0 - s * m / k b) (c 'n)))) 0))
                      0)))))
 ; --- a substep of h ---
 (sub W h) (: all (W 'bodies) _ (each all (b \ pin b 'R (tb-rot (b 'q)))) g (W 'g)
   bs (filter (b \ b 'still = 0) all)
   _ (each bs (b \ pin b 'v (c+ (b 'v) (c* h g))))
   cs (catmap (b \ catmap (contacts b) (W 'brushes)) bs + pairs all)
   _ (each ^tb-iters (_ \ each cs solve1))
   _ (unsink! cs)
   ; ..a sphere touching drags its roll, then all move and turn
   _ (each bs (b \ (: touch (any (c \ c 'a == b || c 'b == b) cs)
                    (touch && b 'roll > 0.0 ? (pin b 'w (c* (max 0.0 (1.0 - b 'roll * 9.81 * h / (b 'r))) (b 'w))) 0,
                     pins b 'p (c+ (b 'p) (c* h (b 'v)))
                            'q (qnorm (map (k \ b 'q k + 0.5 * h * qmul (0.0 . b 'w) (b 'q) k) ^4)),
                     ; ..and sleeps once slow and touching long enough
                     (: s (max (mag3 (b 'v)) (mag3 (b 'w) * size b))
                        (? (touch && s < rest-v) (: t (b 'idle + h) (t > rest-t ? (pins b 'still 1 'idle t 'v [0.0 0.0 0.0] 'w [0.0 0.0 0.0]) (pin b 'idle t)))
                           (pin b 'idle 0.0)))))))
   (pin W 't (W 't + h)))
 (size b) (b 'shape = 'sphere ? (b 'r) (max (b 'h 0) (max (b 'h 1) (b 'h 2))))
 (mag3 v) (sqrt (dot v v))
 (tb-step W dt) (peep W 'engine 'c = 'love ? (: n (max 1 (int (dt / tb-h + 0.999))) (each ^n (_ \ sub W (dt / n)), W))
                   (c-step W dt))
 ; ..the bodies as rows of 28 for C, the brushes' planes as rows of 5 with their brush's number
 (row b) (: s (b 'shape = 'sphere ? [(b 'r) 0.0 0.0] (b 'h))
   (map (x \ 1.0 * x) ([(b 'shape = 'sphere ? 0 1) (b 'm) (b 'im)] + b 'ii + b 'p + b 'q + b 'v + b 'w
                       + [(b 'e) (b 'mu) (b 'roll)] + s + [(b 'idle) (b 'still) 0])))
 (planes W) (peep W 'P () @ () (: P (gem-tray [(5 * net (map (B \ #B) (W 'brushes)))]
                                          (catmap (i \ catmap (pl \ map (x \ 1.0 * x) (pl 0 + [(pl 1) i])) (W 'brushes i)) ^#(W 'brushes)))
                                  (pin W 'P P, P))
                         P P)
 (c-step W dt) (: bs (W 'bodies) g (W 'g)
   r (tumble-step (gem-tray [(28 * #bs)] (catmap row bs)) (planes W) (gem-tray [4] [(g 0) (g 1) (g 2) (1.0 * dt)]))
   (slice i a n) (map (k \ r (28 * i + a + k)) ^n)
   _ (each ^#bs (i \ pins (bs i) 'p (slice i 6 3) 'q (slice i 9 4) 'v (slice i 13 3) 'w (slice i 16 3)
                            'idle (r (28 * i + 25)) 'still (int (r (28 * i + 26)))))
   (pin W 't (W 't + dt)))
 ; --- energy: of motion, turning, and height against g ---
 (tb-energy W) (net (map (b \ (: R (tb-rot (b 'q)) wb (mtv R (b 'w))
                                 (0.5 * b 'm * dot (b 'v) (b 'v) + 0.5 * net (map (k \ 2 (wb k) / b 'ii k) ^3)
                                  - b 'm * dot (W 'g) (b 'p))))
                         (W 'bodies))))
)
