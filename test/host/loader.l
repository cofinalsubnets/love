; test/host/loader.l -- `borrow` of a path, the loader in src/love/boot/prel.l. a module comes by
; a name already held (baked, catted, loaded) or a path the caller writes, never an invented path:
; a name it lacks is a miss even with the file in the cwd. a path load is one fresh layer
; registered under its basename. not in the corpus: the first law (zz-loadprobe absent) holds
; once. fixtures are zz- names, removed at the foot. run from the repo root:
;   cat test/00-init.l test/host/loader.l | out/love

(mkdir "lib" 493, mkdir "lib/zz-loadprobe" 493,
 (open "lib/zz-loadprobe.l" "w" @ p
  (say p "(: (zz-probe-hi x) (+ x 1) zz-probe-pin 41)",
   close p)),
 (open "lib/zz-loadprobe/sub.l" "w" @ p
  (say p "(: (zz-probe-sub x) (* x 10))",
   close p)))

; the NAME lane touches no filesystem. lib/zz-loadprobe.l is right there and the
; symbol still misses: the loader has no path to invent, so the splice raises by
; name and nothing registers.
(trap (_ \ (borrow 'zz-loadprobe)) () (a \ b \ 'caught) @ a
 (test (a = 'caught) !(cite 'zz-loadprobe)))

; the path lane: one layer named for the basename, registered, spliced -- bare names
; resolve in forms compiled after the use (the capture law: a use must precede its readers)
(borrow "lib/zz-loadprobe.l")
(test (3 = zz-probe-hi 2)
        (41 = cite 'zz-loadprobe 'zz-probe-pin)
        (lit? (cite 'zz-loadprobe)))

; the basename is the whole name: a nested path registers under `sub`, and the
; directory it sat in is not part of it
(borrow "lib/zz-loadprobe/sub.l")
(test (70 = zz-probe-sub 7)
        (lit? (cite 'sub))
        !(cite 'zz-loadprobe/sub))

; a re-use hits the registry, never the file again -- by name or by the path that
; named it: rewrite the file, use both ways, the module keeps its first reading
(open "lib/zz-loadprobe.l" "w" @ p (say p "(: zz-probe-pin 999)", close p))
(borrow 'zz-loadprobe)
(borrow "lib/zz-loadprobe.l")
(test (41 = cite 'zz-loadprobe 'zz-probe-pin))

; a self-registering file -- its text is a (module 'nm ..) wrap (cook.l's shape) --
; keeps its registration: the loader's empty wrapper layer must not pin over the
; module the file made, and the name it registers need not be the basename. where
; the two differ the wrapper was never written to, so the basename does not register
; at all -- an empty tablet standing under it would answer a later use with nothing.
(open "lib/zz-pathprobe.l" "w" @ p
 (say p "(module 'zz-pathprobe (: zz-path-pin 78))", close p))
(borrow "lib/zz-pathprobe.l")
(test (78 = cite 'zz-pathprobe 'zz-path-pin))
(open "lib/zz-elsewhere.l" "w" @ p
 (say p "(module 'zz-othername (: zz-other-pin 79))", close p))
(borrow "lib/zz-elsewhere.l")
(test (79 = cite 'zz-othername 'zz-other-pin)
        !(cite 'zz-elsewhere))

; a path that opens nothing is a miss, like any other
(trap (_ \ (borrow "lib/zz-absent.l")) () (a \ b \ 'caught) @ a
 (test (a = 'caught)))

(unlink "lib/zz-loadprobe.l", unlink "lib/zz-loadprobe/sub.l",
 unlink "lib/zz-pathprobe.l", unlink "lib/zz-elsewhere.l",
 rmdir "lib/zz-loadprobe",
 ; ..and lib/ itself, which this file made. rmdir refuses a directory with anything
 ; in it, so a real one is safe -- and without this the repo root grows an empty lib/
 ; on every run, which is a fixture the foot forgot rather than a thing the tree has.
 rmdir "lib", 0)

; the seat rungs are retired (the modules arc, rung 3) and so is the cwd walk:
; the loader reads no directory of its own, so a fixture beside the binary is as
; invisible as one in lib/. this binary is out/love, so its old rungs were
; out/lib/ and out/lib/love/ -- fixture there, and the use must miss.
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
; a path names its file, never a module that merely shares the basename: with a module
; zz-shadow registered, a module-less out/zz-sub/zz-shadow.l borrowed by path answers its own
; bindings, the module keeps its own, and a second borrow of the path reads nothing again
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
