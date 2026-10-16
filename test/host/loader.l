; test/host/loader.l -- `borrow` (src/love/boot/prel.l): a module comes by a name already held or
; a path written out, never an invented path. not in the corpus: the first law holds once.
; fixtures are zz- names, removed at the foot. run from the repo root:
;   cat test/00-init.l test/host/loader.l | out/love

(mkdir "lib" 493, mkdir "lib/zz-loadprobe" 493,
 (open "lib/zz-loadprobe.l" "w" @ p
  (say p "(: (zz-probe-hi x) (+ x 1) zz-probe-pin 41)",
   close p)),
 (open "lib/zz-loadprobe/sub.l" "w" @ p
  (say p "(: (zz-probe-sub x) (* x 10))",
   close p)))

; a name touches no filesystem: lib/zz-loadprobe.l is right there and still misses
(trap (_ \ (borrow 'zz-loadprobe)) () (a \ b \ 'caught) @ a
 (test (a = 'caught) !(cite 'zz-loadprobe)))

; a path: one layer registered under its basename; bare names resolve in later forms only
(borrow "lib/zz-loadprobe.l")
(test (3 = zz-probe-hi 2)
        (41 = cite 'zz-loadprobe 'zz-probe-pin)
        (lit? (cite 'zz-loadprobe)))

; the basename is the whole name: a nested path registers under `sub`
(borrow "lib/zz-loadprobe/sub.l")
(test (70 = zz-probe-sub 7)
        (lit? (cite 'sub))
        !(cite 'zz-loadprobe/sub))

; a re-use, by name or path, hits the registry: the module keeps its first reading
(open "lib/zz-loadprobe.l" "w" @ p (say p "(: zz-probe-pin 999)", close p))
(borrow 'zz-loadprobe)
(borrow "lib/zz-loadprobe.l")
(test (41 = cite 'zz-loadprobe 'zz-probe-pin))

; a file that is a (module 'nm ..) wrap keeps its own registration, under any name; when
; that is not the basename, the basename does not register (an empty one would answer nothing)
(open "lib/zz-pathprobe.l" "w" @ p
 (say p "(module 'zz-pathprobe (: zz-path-pin 78))", close p))
(borrow "lib/zz-pathprobe.l")
(test (78 = cite 'zz-pathprobe 'zz-path-pin))
(open "lib/zz-elsewhere.l" "w" @ p
 (say p "(module 'zz-othername (: zz-other-pin 79))", close p))
(borrow "lib/zz-elsewhere.l")
(test (79 = cite 'zz-othername 'zz-other-pin)
        !(cite 'zz-elsewhere))

(trap (_ \ (borrow "lib/zz-absent.l")) () (a \ b \ 'caught) @ a
 (test (a = 'caught)))

(unlink "lib/zz-loadprobe.l", unlink "lib/zz-loadprobe/sub.l",
 unlink "lib/zz-pathprobe.l", unlink "lib/zz-elsewhere.l",
 rmdir "lib/zz-loadprobe",
 ; ..and lib/, which this file made; rmdir leaves a non-empty one alone
 rmdir "lib", 0)

; the loader reads no directory of its own: a fixture in out/lib/ or out/lib/love/ misses
(mkdir "out/lib/love" 493,
 (open "out/lib/zz-seatprobe.l" "w" @ p
  (say p "(: zz-seat-pin 51)",
   close p)),
 (open "out/lib/love/zz-fhsprobe.l" "w" @ p
  (say p "(: zz-fhs-pin 52)",
   close p)))
(: a (trap (_ \ (borrow 'zz-seatprobe)) () (a \ b \ 'caught))
   b (trap (_ \ (borrow 'zz-fhsprobe)) () (a \ b \ 'caught))
 (test (a = 'caught) (b = 'caught)
         !(cite 'zz-seatprobe) !(cite 'zz-fhsprobe)))
(unlink "out/lib/zz-seatprobe.l",
 unlink "out/lib/love/zz-fhsprobe.l",
 rmdir "out/lib/love",
 0)
; a path names its file, not a module sharing its basename; a second borrow reads nothing
(module (zz-shadow zz-shadow-mod) (: zz-shadow-mod 7))
(mkdir "out/zz-sub" 493)
(open "out/zz-sub/zz-shadow.l" "w" @ p (say p "(: zz-shadow-file 42 (zz-shadow-f x) (x + 1))", close p))
(borrow "out/zz-sub/zz-shadow.l")
(test (42 = zz-shadow-file) (3 = zz-shadow-f 2)
      (7 = cite 'zz-shadow 'zz-shadow-mod) !(cite 'zz-shadow 'zz-shadow-file)
      (42 = cite "out/zz-sub/zz-shadow.l" 'zz-shadow-file))
(open "out/zz-sub/zz-shadow.l" "w" @ p (say p "(: zz-shadow-file 43)", close p))
(borrow "out/zz-sub/zz-shadow.l")
(test (42 = cite "out/zz-sub/zz-shadow.l" 'zz-shadow-file))
(unlink "out/zz-sub/zz-shadow.l", rmdir "out/zz-sub", 0)
(test_fin ())
(puts "loader: ok")
(putc 10)
