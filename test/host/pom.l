; test/host/pom.l -- the phase of the moon (src/apps/pom.l), against the perl pom's answers
;   cat test/00-init.l test/host/pom.l | out/love
(borrow 'pom)
(: (said h m d y) ("The Moon is " + pom-name (pom-phase h m d y) + " (" + show (pom-percent (pom-phase h m d y)) + "% of Full)")
   art (pom-art (pom-phase 12 9 23 2026) 38 9 "9/23/2026:12")
   (test (2461307 = pom-julian 9 23 2026)
         (2299170 = pom-julian 10 14 1582)                  ; the julian calendar's last day
         (2299161 = pom-julian 10 15 1582)                  ; ..and gregory's first
         (abs (pom-phase 12 9 23 2026 - 0.401967376881775) < 0.000000001)
         ("The Moon is Waxing Gibbous (81% of Full)" = said 12 9 23 2026)
         ("The Moon is Waning Crescent (33% of Full)" = said 23 12 31 1999)
         ("The Moon is Waxing Crescent (43% of Full)" = said 20 7 20 1969)
         ("The Moon is Waning Crescent (10% of Full)" = said 12 10 14 1582)
         ("The Moon is Waxing Gibbous (74% of Full)" = said 0 6 7 5)
         ("Date : 9/23/2026:12::0@@@@@@@@@\nPhase: Waxing Gibbous::::@@@@@@@@@@@@@@@@\nFull : 81%::::+@@@@@@@@@@@@@@@@@@@\n      :::::@@@@@@@@@@@@@@@@@@@@@\n      :::::@@@@@@@@@@@@@@@@@@@@@\n      :::::@@@@@@@@@@@@@@@@@@@@@\n       ::::+@@@@@@@@@@@@@@@@@@@\n         ::::@@@@@@@@@@@@@@@@\n             ::0@@@@@@@@@\n" = art),
    0))

; the moon in pixels: a disc of 52 at n=8, one colour when full and another when new, the
; quarters lit on opposite halves; drawn, four rows of eight cells
(: (pm-cols g) (: (go l a) (? (atom? l) a (go >l (charm? <l && !(elem <l a) ? (<l . a) a))) (go (catmap (\ r r) g) ()))
   (pm-disc g) #(filter charm? (catmap (\ r r) g))
   (pm-side g c) (: (go i j a) (? (8 <= i) a (8 <= j) (go (i + 1) 0 a)
                                  (go i (j + 1) (g i j = c ? (j . a) a)))
                    (go 0 0 ()))
   (pm-cells s) (: (go i n) (? (#s <= i) n
                               (s i = 27) (: (to k) (s k = 109 ? (k + 1) (to (k + 1))) (go (to i) n))
                               (go (i + 1) (s i & 192 = 128 ? n (n + 1))))
                   (go 0 0))
   full (pom-pixels 0.5 8) new (pom-pixels 0 8) fq (pom-pixels 0.25 8) lq (pom-pixels 0.75 8)
   lit <(pm-cols full) dim <(pm-cols new)
   drawn (pom-cells fq 0)
   (test (52 = pm-disc full) (52 = pm-disc new) (52 = pm-disc fq)
         (1 = #(pm-cols full)) (1 = #(pm-cols new)) (lit != dim)
         (all (\ j (3 < j)) (pm-side fq lit)) (all (\ j (j < 4)) (pm-side fq dim))
         (all (\ j (j < 4)) (pm-side lq lit)) (all (\ j (3 < j)) (pm-side lq dim))
         (two? (pm-side fq lit)) (two? (pm-side lq lit))
         (4 = #drawn) (all (\ l (8 = pm-cells l)) drawn)
         ; the saver's moon, -s: a disc in the saver's own pens, seas on the lit side, the
         ; limb dark, the same face the saver draws
         (sort (pm-cols (pom-moon 0.45 24)) = [0x1c1c1c 0xd7d7af 0xffffd7])
         (12 = #(pom-cells (pom-moon 0.45 24) 0))
         (187 = pom-face 0.45 0.3 -0.05) (230 = pom-face 0.45 0.0 0.0)
         (234 = pom-face 0.45 -0.99 0.0) (() = pom-face 0.45 0.0 2.0)
         ; drawn naturally, -n: on the disc only; the lit side right waxing and left waning;
         ; a full moon near flat to its limb; a new one a faint glow of earthshine; the seas
         ; darker than the highlands; and twelve rows of half blocks for 24
         (: (lum v) ((v // 65536 + v // 256 % 256 + v % 256) / 3.0) (g p x y) (lum (pom-glow p x y))
          (&& (() = pom-glow 0.45 0.0 2.0)
              (4.0 * g 0.25 -0.6 0.0 < g 0.25 0.6 0.0) (4.0 * g 0.75 0.6 0.0 < g 0.75 -0.6 0.0)
              (g 0.5 0.0 0.0 < 1.35 * g 0.5 0.9 0.0)
              (0.0 < g 0.02 0.0 0.0) (g 0.02 0.0 0.0 < 40.0)
              (g 0.5 -0.35 -0.45 < g 0.5 -0.05 -0.82)
              (12 = #(pom-cells (pom-natural 0.45 24) 0)))),
    puts "pom: ok\n"))
