; --- test/glaze-tail.l: a native's tail call holds no frame ---------------------
; an ambled body's tail call to anything but itself -- a sibling, its parent, a global -- runs
; in its place: test.mk's test_hook runs this under a 64 MB budget, where two module siblings
; tail calling each other two million times answer, and a frame kept per hop runs out.
(: gtail-n0 (peep fires () 0))
(module 'gtail
(: (gtail-a f n acc) (n = 0 ? acc (: _ (f n) (gtail-b f (n - 1) (acc + 1))))
   (gtail-b f n acc) (n = 0 ? acc (: _ (f n) (gtail-a f (n - 1) (acc + 1))))))
(: n 2000000
   r ((cite 'gtail 'gtail-a) (_ \ 0) n 0)
   (? (fired? gtail-n0 && r = n) (puts "glaze-tail: ok\n")
      (puts ("glaze-tail: " + show [(fired? gtail-n0) r] + "\n"))))
