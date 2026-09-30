; src/tools/clay-g2.l -- g2, doc/misc/clay.md's conversion gate: does the C a generator lays
; mean what the C it replaces meant?
;
; parse two whole translation units and compare the named top-level definitions as trees: both
; sides meet the same cpp, typedefs and macro expansions, so a surviving difference is one of
; meaning, never of spelling. it runs once per conversion, against the file the region came out of.
;
; run on the baked love, whose crew layer carries the front end:
;   love -l src/tools/clay-g2.l \
;     -e '(clay-g2 ".love-orig.c" "love.c" (\ ("salpha" "shash")))'
; answers 1 and prints a report; quits 1 on any difference.
(:
   _ (borrow 'moon)                       ; the front end is module 'moon now
   (g2-say s) (puts (s + "\n"))

   ; the front end without cc-parse's udie: a refusal has to come back as a value, so
   ; that "the file did not parse" reads differently from "the trees differ".
   (g2-front src)
    (uread src @ r
       (atom? r ? 'noread
          (clex (deftext [(archdef 'x64)] + <>r) @ lx
             (!(okv? lx) ? 'lexfail
                (cpp <>lx (\ n s (incload () () (cdir src) n s)) src @ pp
                   (!(okv? pp) ? 'cppfail
                      (cparse-t <>pp 'x64 @ ps
                         (okv? ps ? (<>ps 1) 'parsefail))))))))

   ; the definition, never the prototype that announces it: the two wear one name, and
   ; comparing the wrong one would pass on a signature while the body drifted.
   (g2-find tops nm)
    (: (go l) (atom? l ? ()
                 (<l @ e (<e = 'fn && (e 1 @ w (string? w && w = nm))
                          ? [1 e] (go >l))))
       (go tops))

   (clay-g2 old new names)
    (: a (g2-front old)
       b (g2-front new)
       _ (atom? a ? (g2-say ("g2: " + old + ": " + show a), quit 1))
       _ (atom? b ? (g2-say ("g2: " + new + ": " + show b), quit 1))
       (one nm)
        (: fa (g2-find a nm) fb (g2-find b nm)
           (? (atom? fa) (g2-say ("g2: MISSING from " + old + ": " + nm), 0)
              (atom? fb) (g2-say ("g2: MISSING from " + new + ": " + nm), 0)
              (fa 1 = fb 1) 1
              (g2-say ("g2: DIFFERS: " + nm), 0)))
       oks (foldl (+) 0 (map one names))
       (g2-say $ "g2: " + show oks + " / " + show #names
                 + " definitions identical as trees",
        ; a vacuous pass is a fail: a front end that answered nothing reports 0/0
        oks = #names && 0 < oks
        ? (g2-say "g2: pass", 1)
          (g2-say "g2: FAIL", quit 1))))
