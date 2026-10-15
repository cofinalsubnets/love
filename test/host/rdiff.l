; test/host/rdiff.l -- the C reader against test/host/p1.l over every .l in the tree, print->read,
; and flowing charlists; rd-hurt, a spoiled reader, must go red: a diff that cannot fail proves nothing
; run: cat test/00-init.l test/host/rdiff.l | out/love

(: (rd-cl s) (map s (jot #s))
   (rd-slurp path) (open path "r" @ q (hot? q ? (slurp q @ t (close q, t)) ""))
   (rd-cut s n) (#s <= n ? s (snip s 0 n))
   (rd-rep c n) (n <= 0 ? "" (c + rd-rep c (n - 1)))
   ; every form a reader gets off a text, sound's protocol: a clean end and a torn shape both stop
   (rd-forms r txt) (rd-cforms r (rd-cl txt))
   (rd-cforms r cl)
     (: (go cl acc) (r cl @ x
                       (two? x ? (go >x (<x . acc)) (rev acc)))
        (go cl ()))
   ; the text as a flowing charlist: k chars, then a promise of the rest
   (rd-flow s k)
     (: n #s
        (seg i j tl) (j <= i ? tl (seg i (j - 1) (s (j - 1) . tl)))
        (go i) (min n (i + k) @ j (seg i j (j < n ? (once (u \ go j)) ())))
        (n = 0 ? () (go 0)))
   rd-p1 (ev <(sound (rd-slurp "test/host/p1.l"))))

; the smallest pair where two trees part: a leaf alone names nothing
(: (rd-dn a b) (!(a = b) && two? a && two? b)
   (rd-small a b) (? (rd-dn <a <b) (rd-small <a <b)
                     (rd-dn >a >b) (rd-small >a >b)
                     [a b]))

; every .l under the root but out/ and dot-dirs; stat decides directory-or-not, as
; (two? (readdir p)) would call an empty directory a file
(: rd-skip '("out")
   (rd-dir? p) (stat p @ st (two? st && 16384 = 61440 & <>>st))
   (rd-dot? n) (46 = peep n 0 0)
   (rd-dotl? n) (#n @ t (2 < t && ".l" = snip n (t - 2) t))
   (rd-walk d acc)
     (foldl (a \ n \ (("." = d ? n (d + "/" + n)) @ p
                        (? (rd-dot? n || elem n rd-skip) a
                           (rd-dir? p) (rd-walk p a)
                           (rd-dotl? n) (p . a)
                           a)))
            acc (sort (readdir d))))

; the sweep -> a tablet of files, forms, bad; `loud` prints the first few divergences
(: (rd-run r paths loud)
   (: n {}
      (bump k v) (pin n k (v + peep n k 0))
      (say leg path a b)
        (bump 'bad 1,
         ? (loud && peep n 'bad 0 <= 8)
              (rd-small a b @ d
               (puts ("  " + leg + " " + path + "\n    A " + rd-cut (show <d) 120
                                             + "\n    B " + rd-cut (show <>d) 120 + "\n"), 0))
              0)
      (one path)
        (: txt (rd-slurp path)
           fa (rd-forms sound txt)
           fb (rd-forms r txt)
           (bump 'files 1,
            bump 'forms #fa,
            (fa = fb ? 0 (say "A/B" path fa fb)),
            each fa (f \ (rd-forms sound (show f) @ g
                            ([f] = g ? 0 (say "print->read" path [f] g))))))
      (each paths one,
       n)))

; the rig's own gate: the C reader with one form spoiled part-way, a plausible wrong tree
(: rd-hurt-n {}
   (rd-hurt cl)
     (sound cl @ x
      (pin rd-hurt-n 0 (1 + peep rd-hurt-n 0 0),
       (3 = peep rd-hurt-n 0 0 ? 'rd-spoiled x))))

(: rd-files (rd-walk "." ())
   _ (puts ("rdiff: " + show #rd-files + " .l files\n"))
   rd-clean (rd-run rd-p1 rd-files 1)
   rd-hurtn (rd-run rd-hurt ["test/spec.l"] 0)
   _ (puts ("rdiff: files=" + show (peep rd-clean 'files 0)
            + " forms=" + show (peep rd-clean 'forms 0)
            + " bad=" + show (peep rd-clean 'bad 0)
            + " injected=" + show (peep rd-hurtn 'bad 0) + "\n")))

; the texts as flowing charlists, a promise every k chars: small k on a few files, as a
; promise per char is a love call per char; a wide k on the whole tree
(: (rd-flows k paths)
     (foldl (n \ path \ (rd-slurp path @ txt
                            (n + (rd-forms sound txt = rd-cforms sound (rd-flow txt k) ? 0 1))))
            0 paths)
   rd-small ["test/spec.l" "test/io.l" "test/valence.l" "test/escape.l"]
   rd-fbad (net (map (k \ rd-flows k rd-small) [1 2 3 5]) + rd-flows 61 rd-files)
   ; the oracle reads a flow the same way
   rd-fp1 (rd-cforms sound (rd-flow (rd-slurp "test/valence.l") 2)
           = rd-cforms rd-p1 (rd-flow (rd-slurp "test/valence.l") 2))
   ; a whole text read in place against the forms threaded one by one
   rd-sbad (foldl (n \ path \ (rd-slurp path @ txt
                                 (n + (sounds txt = rd-forms sound txt ? 0 1))))
                  0 rd-files)
   rd-storn ('torn = sounds "(a \"b" && 'torn = sounds "(a" && [1 2] = sounds "1 2) 3")
   rd-port (rd-cforms sound (tap (rd-cl "(1 2) x \"y\"")) = ['(1 2) 'x "y"])
   ; the door holds the flow post.l sealed, never a name in scope
   rd-sealed ((flow \ rd-cforms sound (tap (rd-cl "(1 2) x"))) (_ \ ()) = ['(1 2) 'x])
   ; a promise per char under an 8k token and a 2000-form text: no prefix's promises read again
   rd-long (: tok (rd-rep "abcdefgh" 1000)
              txt ("\"" + tok + "\" " + tok + " " + rd-rep "(foo 12 \"b\") " 2000)
              (rd-cforms sound (rd-flow txt 1) = rd-forms sound txt))
   ; a form nests on the heap, never the C stack: far past the deepest in the tree
   rd-deep (: (depth x n) (two? x ? (depth <x (n + 1)) n)
              (19999 = depth <(sound (rd-rep "(" 20000 + rd-rep ")" 20000)) 0))
   _ (puts ("rdiff: flows bad=" + show rd-fbad + " texts bad=" + show rd-sbad + " oracle=" + show rd-fp1
            + " port=" + show rd-port + " sealed=" + show rd-sealed + " long=" + show rd-long
            + " deep=" + show rd-deep + "\n")))

(test
 ; the sweep reached the tree: floors, as the tree grows
 (250 < peep rd-clean 'files 0)
 (1200 < peep rd-clean 'forms 0)
 (0 = peep rd-clean 'bad 0)
 ; the rig can go red
 (0 < peep rd-hurtn 'bad 0)
 (0 = rd-fbad) rd-fp1 rd-port rd-sealed rd-long
 (0 = rd-sbad) rd-storn
 rd-deep)

(test_fin ())
(puts "rdiff: ok")
(putc 10)
