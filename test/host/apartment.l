; --- test/host/apartment.l: the glass cube on the plain, headless ---
; not in the test/*.l corpus (it loads a crew module). the level is pure love, so
; everything but the tty runner gates here: the lay -- the road, the cubes each with a
; path to it, yours closed round you with the stranger at its pane -- the names in
; blocks, the sign, glass that holds, the talk through the pane from its first node to
; a leaf, and the end: the stranger gone, the pane open, the drum asked for, the grass
; outside gone to sand and the plain reachable; and the song into a jug.
;   cat test/00-init.l test/host/apartment.l | out/love

(borrow 'apartment)   ; the artifact's module, warm from the tree
(borrow 'rove)        ; dat, open?, the words

(: (find h n i) (i + #n < 1 + #h ? (n = snip h i (i + #n) ? 1 (find h n (i + 1))) 0)
   (has? h n) (find h n 0)
   (count s n) (:- (go 0 0) (go i k) (i + #n <= #s ? (go (i + 1) (k + (n = snip s i (i + #n)))) k))
   (rows s) (1 + count s "\r\n")
   (range a b) (map (+ a) ^(b - a))
   ; the cells you can walk to from where you stand, four ways at a step
   (reach g) (: d (g 'd) w (d 'w) h (d 'h) seen {}
                (nbs i) (: x (i % w) y (i // w)
                           (filter (j \ 0 <= j)
                                   (map ([dx dy] \ (: nx (x + dx) ny (y + dy)
                                                     (0 <= nx < w && 0 <= ny < h && open? d nx ny ? (nx + w * ny) -1)))
                                        '((1 0) (-1 0) (0 1) (0 -1)))))
                (go l) (l @- seen (i . u) (seen i ? (go u) (pin seen i 1, go (u + nbs i))))
                (go [(g 'p 'x + w * g 'p 'y)]))
   (blocky? s) (0 < #s && 0 = #s % 3 && all (i \ elem (snip s (3 * i) (3 * i + 3)) blocks) ^(#s // 3)))

; --- the lay: the road across, every cube's path down to it, and yours closed with you
; --- inside and the stranger outside at the pane
(: g (apartment-new 80 22 (wheel 5)) d (g 'd) w 80 h 22 c (d 'cube) p (g 'p) npc (g 'npc)
   (t x y) (dat d x y)
   ry (d 'road)
   in (reach g)
   f (apartment-frame g)
   (pathed? cb) (: x (cb 4)
                   ys (cb 5 ? (range (ry + road-h) (cb 1)) (range (cb 1 + cube-h) ry))
                   (all (y \ 3 = t x y) ys))
 (test (rows f = h + 2) (f = apartment-frame g)                 ; the note row, the plain, the bar
       (all (x \ 4 = t x ry && 4 = t x (ry + road-h - 1)) ^w)   ; the road, edge to edge
       (3 <= #(d 'cubes)) (all pathed? (d 'cubes))              ; each cube a path to the road
       (inside? c (p 'x) (p 'y)) (1 = t (p 'x) (p 'y))         ; you, on grass inside yours
       (6 = t (c 0) (c 1)) (6 = t (c 0 + cube-w - 1) (c 1 + cube-h - 1))   ; ..which is glass round
       (all (i \ inside? c (i % w) (i // w)) (keys in))         ; ..and closed: nowhere to walk but inside
       (#(keys in) = (cube-w - 2) * (cube-h - 2))
       (tablet? npc) (!(inside? c (npc 'x) (npc 'y)))           ; the stranger outside
       (npc 'y = c 1 + cube-h) (6 = t (npc 'x) (npc 'y - 1))   ; ..at the foot, a pane between
       (g 'pane = npc 'x + w * (npc 'y - 1))
       (blocky? (npc 'nm)) (blocky? (npc 'greet))               ; named and greeting in blocks
       (two? (g 'sign)) (!(g 'talk))                             ; the opening sign stands
       (apartment-turn g 32, !(g 'sign))                        ; ..and a key takes it down
       ; the same seed lays the same plain and names the same stranger
       (: g2 (apartment-new 80 22 (wheel 5)) (g2 'npc 'nm = npc 'nm && g2 'd 'cube = c))))

; --- glass holds, but for the pane the stranger stands at, which opens the talk ---
(: g (apartment-new 80 22 (wheel 5)) d (g 'd) w 80 c (d 'cube) p (g 'p) npc (g 'npc)
   _ (apartment-turn g 32)
   _ (pins p 'x (c 0 + 1) 'y (c 1 + 1)) _ (apartment-turn g '(0 -1))   ; up into the top wall
   x1 (p 'x) y1 (p 'y) m1 (g 'msg) k1 (g 'talk)
   _ (pins p 'x (npc 'x) 'y (npc 'y - 2)) _ (apartment-turn g '(0 1))  ; down into the pane
   sg (g 'sign)
 (test (x1 = c 0 + 1) (y1 = c 1 + 1) (0 < #m1) (nil? k1)      ; held, and something said
       ('start = g 'talk) (two? sg) (<sg = npc 'nm)             ; the talk, under the stranger's name
       (any (l \ has? l (npc 'greet)) >sg)                       ; ..greeting in blocks
       (p 'x = npc 'x) (p 'y = npc 'y - 2)))                     ; ..and you never moved

; --- the talk walks its tree; a leaf closes it, and that is the end ---
(: g (apartment-new 80 22 (wheel 5)) d (g 'd) w 80 h 22 c (d 'cube) p (g 'p) npc (g 'npc)
   (t x y) (dat d x y)
   _ (apartment-turn g 32)
   _ (pins p 'x (npc 'x) 'y (npc 'y - 2)) _ (apartment-turn g '(0 1))
   root (chat-node 'start) c1 <(root 2)
   _ (apartment-turn g (48 + <c1)) k1 (g 'talk)
   _ (apartment-turn g 120) k2 (g 'talk)                          ; x is no choice: shown again
   leaf <(filter (e \ one? (e 2)) chat-book)
   ; a grass cell outside the cube, and one inside, before the end
   out (<(filter (i \ 1 = peep (d 't) i 0 && !(inside? c (i % w) (i // w))) ^(w * h)))
   _ (chat g <leaf) s1 (g 'sign)
   _ (apartment-turn g 32)
   in (reach g)
 (test (k1 = c1 2) (k2 = c1 2) (two? s1)
       (!(g 'talk)) (!(g 'sign)) (!(g 'npc))                    ; closed, and the stranger gone
       (elem 'drum (g 'sfx)) (0 < #(g 'msg))                     ; the drum asked for, and something said
       (7 = t (npc 'x) (npc 'y - 1))                             ; the pane is shards
       (open? d (npc 'x) (npc 'y - 1))
       (g 'desert) (2 = peep (d 't) out 0)                        ; the grass outside is sand
       (1 = t (p 'x) (p 'y)) (all (i \ 1 = peep (d 't) i 0) (filter (i \ inside? c (i % w) (i // w)) ^(w * h)))
       (any (i \ 4 = peep (d 't) i 0) (keys in))                 ; ..and the road is a walk away
       (apartment-turn g '(0 1), apartment-turn g '(0 1), p 'y = npc 'y)   ; out through the pane
       (rows (apartment-frame g) = h + 2)))

; --- the song: no bars yet, so a fresh song is silence, and the drum is not ---
(: j (jug 0) s (apartment-song-new j)
   _ (each ^5 (i \ apartment-song-feed s))
   quiet (slurp j)
   g (apartment-new 80 22 (wheel 5))
   _ (pin g 'sfx '(drum))
   _ (apartment-sfx s g)
   n1 #(s 'vs)
   j2 (jug 0) _ (pin s 'h j2)
   _ (each ^40 (i \ apartment-song-feed s))
   loud (slurp j2)
 (test (#quiet = 5 * 4 * song-chunk) (all (i \ 0 = quiet i) ^#quiet)
       (0 < n1) (!(g 'sfx))
       (#loud = 40 * 4 * song-chunk) (any (i \ 0 != loud (i * 89)) ^400)))

(test_fin (),
 puts "apartment: ok -- the plain is laid, the cube is closed, the stranger talks through the pane, and the end opens it\n")
