; --- test/glaze-tail.l: a native's tail call holds no frame ---------------------
; an ambled body's tail call to anything but itself -- a sibling, its parent, a global -- runs
; in its place: test.mk's test_hook runs this under a 64 MB budget, where two module siblings
; tail calling each other two million times answer, and a frame kept per hop runs out.
; a self tail call in a middle arm, a later arm pinning, holds none either.
(: gtail-n0 (peep fires () 0))
(module 'gtail
(: (gtail-a f n acc) (n = 0 ? acc (: _ (f n) (gtail-b f (n - 1) (acc + 1))))
   (gtail-b f n acc) (n = 0 ? acc (: _ (f n) (gtail-a f (n - 1) (acc + 1))))))
(: gtail-n1 (peep fires () 0))
(module 'gtail3
(: (gtail-c f s n) (? (n = 0) (s 'k) (n > 1) (f n, gtail-c f s (n - 1)) (f n, pins s 'b n 'o 1, n + s 'k))))
(: n 2000000
   r ((cite 'gtail 'gtail-a) (_ \ 0) n 0)
   s {'k 7}
   r3 ((cite 'gtail3 'gtail-c) (_ \ 0) s n)
   (? (fired? gtail-n0 && fired? gtail-n1 && r = n && r3 = 8 && s 'o = 1) (puts "glaze-tail: ok\n")
      (puts ("glaze-tail: " + show [(fired? gtail-n0) (fired? gtail-n1) r r3] + "\n"))))
