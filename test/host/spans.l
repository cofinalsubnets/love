; test/host/spans.l -- libra's slow reader (src/apps/libra/spans.l): stripped, it reads every .l in
; the tree as sound does, each top form's text reads back as its form, and the notes and holes
; land where the header says
; run: cat test/00-init.l test/host/spans.l | out/love

(borrow 'posix)
(borrow 'spans)

; every .l under the root but out/ and dot-dirs, as rdiff.l walks
(: (sp-slurp path) (open path "r" @ q (hot? q ? (slurp q @ t (close q, t)) ""))
   (sp-dir? p) (stat p @ st (two? st && 16384 = 61440 & <>>st))
   (sp-walk d acc)
     (foldl (a \ n \ (("." = d ? n (d + "/" + n)) @ p
                        (? (46 = peep n 0 0 || n = "out") a
                           (sp-dir? p) (sp-walk p a)
                           (#n @ t (2 < t && ".l" = snip n (t - 2) t)) (p . a)
                           a)))
            acc (sort (readdir d)))
   (sp-torn? t) (trap spans-forms t (a \ b \ 1) @ 1 1 _ 0)
   ; a file's count of top forms whose stripped node or whose own text read otherwise
   (sp-bad t)
     (: ns (spans t) fs (spans-forms t)
        (back n) (sound (snip t (n 1 0) (n 1 1)) @ (f . _) f _ 'none)
        (? ((map spans-strip ns) != fs) 1
           (#(filter (n \ back n != spans-strip n) ns))))
   files (filter (p \ !(sp-torn? (sp-slurp p))) (sp-walk "." ()))
   bad (filter (p \ 0 < sp-bad (sp-slurp p)) files)
   _ (puts ("spans: " + show #files + " files" + (two? bad ? (", unequal: " + join " " bad) "") + "\n"))
   (test (100 < #files) (bad = ())))

; the header's sample: a form with a comment, a string with a hole, a bracket, a quote
(: s "; lead\n(f x) ; why\n\"a \\(b) c\"\n[1 2]\n'q\n"
   ns (spans s)
   w (ns 1 0 1 0)                 ; the weave's (list ..)
   (test (4 = #ns)
         ('((f x) (weave (list "a " (b) " c")) (list 1 2) 'q) = map spans-strip ns)
         ([7 12] = ns 0 1)
         ([["; lead" [0 6]] ["; why" [13 18]]] = ns 0 2)        ; the one before, and its line's
         ([19 29] = ns 1 1)
         (['weave [19 20] ()] = ns 1 0 0)                       ; a reader-made head, over the quote
         (["a " [20 22] ()] = w 1)
         ([23 26] = w 2 1)                                       ; a hole over its (..)
         (['b [24 25] ()] = w 2 0 0)
         ([" c" [26 28] ()] = w 3)
         (['list [30 31] ()] = ns 2 0 0)                        ; [ is the head (list ..) reads
         ([1 [31 32] ()] = ns 2 0 1)
         ([(nom "\\") [36 37] ()] = ns 3 0 0)
         (['q [37 38] ()] = ns 3 0 1)))

; where a note goes: the next node's past a line break, the list's before its closer, the last
; top form's at the end, a #! line's too
(: (notes s) (map (n \ n 2) (spans s))
   (kids s) (map (k \ [(k 0) (k 2)]) (<(spans s) 0))
   (test ([['a [["; t" [3 6]]]] ['b ()]] = kids "(a ; t\n b)")
         ([['a ()] ['b [["; c" [3 6]]]]] = kids "(a\n; c\n b)")
         ([[["; x" [4 7]]]] = notes "(a\n ; x\n)")
         ([[["; end" [2 7]]]] = notes "a\n; end\n")
         ([[["#!/bin/love" [0 11]]] ()] = notes "#!/bin/love\nx y")
         ([() ()] = notes "a\nb")))

; holes and raw texts read as sound reads them, and keep their spans
(: (same s) (map spans-strip (spans s) = spans-forms s)
   (test (same "\"x\\(f \"y\\(z)\")w\"")
         (same "\"\\(a)\\(b)\"")
         (same "\"\\u{48}\\x41\\n\"")
         (same "\"\"\"\n  a\n\n  \"\"\"")
         (same "\"\"\"one \"\" two\"\"\"")
         (same "{} @() [] {a 1} @(1 2) 2?<>x -5 !-5 @-5 x' 0x1f 017 1e5")
         ([0 13] = <(spans "\"\"\"\n  a\n  \"\"\"") 1)
         ("a" = <(spans "\"\"\"\n  a\n  \"\"\"") 0)))

; an unfinished form scares where it starts
(test ('(unfinished-form 2) = trap spans "x (a" (a \ b \ [a b])))

(test_fin ())
(puts "spans: ok")
(putc 10)
