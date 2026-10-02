; src/apps/kore/patch.l -- patch(1), the other half of diff: unified hunks laid on a tree.
; a toolbox of one: patch-main, no seat, kore.l is its door. unified diffs only.
;
;   * a file is a list of (text nl) pairs -- a missing final newline is data, and a patch
;     can carry one in or take one away, so the flag rides per line.
;   * a hunk is (ostart nstart lines), a line (op text nl), op 32 keep / 45 del / 43 add.
;   * applying walks the hunks over the evolving file carrying the delta between old and
;     new positions; a hunk that does not sit where it says searches outward (`offset`).
;
; the exit code is patch's: 0 everything applied, 1 some hunk was rejected (a .rej beside
; the file, the original kept as .orig), 2 the patch itself is unreadable.
(module 'kore
(borrow 'posix)

(:
   ; the say flushes: the hunk reports go to err and the file report to out, so an
   ; unflushed out lands its line in the middle of a later one -- patch's own output
   ; reads as one conversation and has to stay one
   (pt-say s) (say out s, put out 10, flush out)
   (pt-cry s) (flush out, say err s, put err 10, flush err)
   ; a header line -> its path: everything past "--- " up to the first tab, or the whole
   ; rest when there is none (git's headers carry no timestamp)
   (pt-hname ln)
    (: n #ln
       (go k) (? (n <= k) n (ln k = 9) k (go (k + 1)))
       (n < 5 ? "" (snip ln 4 (go 4))))
   ; -p N: drop N leading components. unsaid drops them all, which is patch's own
   ; default and the reason a bare `patch < p` run from inside the tree works at all
   (pt-strip nm p)
    (!(charm? p) ? (ubase nm "")
       (: (go s k)
           (k < 1 ? s
            (s @ (_ + "/" + r) (go r (k - 1)) s))
          (go nm p)))
   ; "@@ -1,8 +3 @@ .." -> (ostart ocount nstart ncount) | ()
   (pt-side w)
    (: b (snip w 1 #w)
       ps (usplit 44 b)
       [(uatoi <ps) (two? ps && two? >ps ? (uatoi <>ps) 1)])
   (pt-hdr ln)
    (filter (w \ (0 < #w)) (usplit 32 ln) @ ws
       (#ws < 3 ? ()
        (: ow <>ws nw <>>ws
           ((0 < #ow && 0 < #nw) && (ow 0 = 45 && nw 0 = 43) ?
              (: o (pt-side ow) n (pt-side nw) [<o <>o <n <>n])))))

   ; --- the reader: a patch text -> ((oldname newname hunks)..) -------------------
   ; a section opens on a --- / +++ pair and runs to the next one. anything between
   ; sections is prose (a mail body, a commit message) and is skipped, which is how a
   ; patch pulled off a mailing list applies at all.
   ; the `\` line is tested before the counts run out. `\ No newline at end of file`
   ; carries no count of its own, so the one that follows the hunk's last line arrives
   ; after both counters have hit zero -- and a body that stopped on the counts alone
   ; would leave every "the patch takes the newline away" case unmarked.
   (pt-body m no nn acc)
    (atom? m ? [(rev acc) m]
     (: ln <m
        c (0 < #ln ? (ln 0) 32)
        (? (c = 92)
           (pt-body >m no nn (two? acc ?
                                ((<acc @ h [<h <>h 0]) . >acc)
                                acc))
           (no < 1 && nn < 1) [(rev acc) m]
           ((0 < #ln ? (snip ln 1 #ln) "") @ txt
              (? (c = 45) (pt-body >m (no - 1) nn ([45 txt 1] . acc))
                 (c = 43) (pt-body >m no (nn - 1) ([43 txt 1] . acc))
                 (c = 32 || c = 0) (pt-body >m (no - 1) (nn - 1) ([32 txt 1] . acc))
                 [(rev acc) m])))))
   (pt-hunks m acc)
    (atom? m || !(starts? <m "@@") ? [(rev acc) m]
     (pt-hdr <m @ hd
        (atom? hd ? [(rev acc) m]
         (pt-body >m <>hd (hd 3) () @ b
            (pt-hunks <>b ([<hd <>>hd <b] . acc))))))
   (pt-parse ls)
    (: (go m acc)
        (atom? m ? (rev acc)
         (starts? <m "--- " && (two? >m && starts? <>m "+++ ") ?
            (pt-hunks >>m () @ h
               (go <>h (two? <h ? ([(pt-hname <m) (pt-hname <>m) <h] . acc) acc)))
            (go >m acc)))
       (go ls ()))

   ; --- the file, as (text nl) pairs ---------------------------------------------
   (pt-pairs t)
    (: ls (lines t) n #ls e (nl-end? t)
       (go m i acc) (atom? m ? (rev acc)
                     (go >m (i + 1) ([<m (i + 1 = n ? e 1)] . acc)))
       (go ls 0 ()))
   (pt-render ps)
    (: o (jug 0)
       (go m) (atom? m ? (slurp o)
               (say o <<m, <><m ? (put o 10) 0, go >m))
       (go ps))
   ; the two sides of a hunk: the old texts to look for, the new pairs to lay down
   (pt-old h) (map (l \ <>l) (filter (\ l !(<l = 43)) (h 2)))
   (pt-new h) (map (l \ [<>l (l 2)]) (filter (\ l !(<l = 45)) (h 2)))

   ; --- the search: where does this hunk's old side actually sit ------------------
   (pt-match ps k old)
    (: (go m o) (? (atom? o) 1 (atom? m) 0 (<<m = <o) (go >m >o) 0)
       (go (drop k ps) old))
   (pt-fits ps k old) ((0 <= k && k + #old <= #ps) && pt-match ps k old)
   ; the reach is (n + 1 + |want|), not n: a create hunk's `-0,0` wants seat -1 in a
   ; file of no lines, so a search bounded by the file's own length never takes a step.
   (pt-seek ps old want)
    (: far (#ps + 1 + abs want)
       (try d) (? (far < d) ()
                  (pt-fits ps (want - d) old) [1 (want - d)]
                  (pt-fits ps (want + d) old) [1 (want + d)]
                  (try (d + 1)))
       (pt-fits ps want old ? [1 want] (try 1)))

   ; --- the reject, written back as the patch it failed to be ---------------------
   (pt-rej nm hs)
    (: o (jug 0)
       (rng l c) (c = 1 ? (show l) (show l + "," + show c))
       (one h) (: ls (h 2)
                  no #(filter (\ l !(<l = 43)) ls)
                  nn #(filter (\ l !(<l = 45)) ls)
                  (say o ("@@ -" + rng <h no + (" +" + rng <>h nn) + " @@\n"),
                   foldl (\ _ l (put o <l, say o <>l, l 2 ? (put o 10) (say o "\n\\ No newline at end of file\n")))
                         0 ls))
       (say o ("--- " + nm + "\n" + ("+++ " + nm + "\n")),
        foldl (\ _ h (one h)) 0 hs,
        slurp o))

   ; --- one file's worth ----------------------------------------------------------
   ; the hunks are reversed before anything else under -R: swapping each line's op and
   ; the two starts turns the patch around, and everything downstream then reads one
   ; shape. a -R that reversed at apply time would owe every later step a second lane.
   (pt-flip h)
    [<>h <h (map (l \ [(? (<l = 45) 43 (<l = 43) 45 32) <>l (l 2)]) (h 2))]
   (pt-file nm hs dry? silent?)
    (: r (uread nm)
       fresh (atom? r)
       ps0 (fresh ? () (pt-pairs <>r))
       _ (silent? ? () (pt-say ((dry? ? "checking file " "patching file ") + nm)))
       (go m ps delta i bad off? rej)
        (atom? m ? [ps bad (rev rej) off?]
         (: h <m
            old (pt-old h) new (pt-new h)
            ; the -0,0 convention: a side with no lines names the seat before it, so
            ; start 0 is position 0 and not -1 (diff.l writes it, this reads it)
            want ((0 < <h ? (<h - 1) 0) + delta)
            s (pt-seek ps old want)
            (atom? s ?
               (pt-cry ("Hunk #" + show i + (" FAILED at " + show (want + 1) + ".")), go >m ps delta (i + 1) (bad + 1) off? (h . rej))
               (: k <>s
                  ps2 (take k ps + (new + drop (k + #old) ps))
                  off (k - want)
                  ((off = 0 || silent? ? ()
                    (pt-say ("Hunk #" + show i + (" succeeded at " + show (k + 1))
                             + (" (offset " + show off + (off = 1 || off = -1 ?
                                                               " line)." " lines)."))))),
                   go >m ps2 (delta + off + (#new - #old)) (i + 1) bad
                      (off ? 1 off?) rej)))))
       res (go hs ps0 0 1 0 0 ())
       ps' <res bad <>res rej <>>res off? (res 3)
       nh #hs
       ((bad ?
           (pt-cry (show bad + " out of " + show nh + (nh = 1 ? " hunk" " hunks")
                    + (" FAILED -- saving rejects to file " + nm + ".rej")))),
        (dry? ? ()
           ; the .orig lands on a mismatch and not only on a failure -- a hunk
           ; that moved applied to a file the patch did not quite describe, and GNU's
           ; --backup-if-mismatch keeps the original for exactly that case
           ((bad || off?) && !fresh ? (uwrite (nm + ".orig") <>r), bad ? (uwrite (nm + ".rej") (pt-rej nm rej)), uwrite nm (pt-render ps'))),
        bad))

   (patch-main as)
    (: (fl a p R inp dry silent outp rest)
        (atom? a ? [p R inp dry silent outp (rev rest)]
         (<a @ ("-R" || "--reverse") (fl >a p 1 inp dry silent outp rest)
               "--dry-run" (fl >a p R inp 1 silent outp rest)
               ("-s" || "--silent") (fl >a p R inp dry 1 outp rest)
               "-p" (two? >a ? (fl >>a (uatoi <>a) R inp dry silent outp rest)
                     (udie 2 "patch: -p wants a count"))
               "-i" (two? >a ? (fl >>a p R <>a dry silent outp rest)
                     (udie 2 "patch: -i wants a file"))
               "-o" (two? >a ? (fl >>a p R inp dry silent <>a rest)
                     (udie 2 "patch: -o wants a file"))
               ("-p" + n) (fl >a (uatoi n) R inp dry silent outp rest)
               ("--strip=" + (n && 0 < #n)) (fl >a (uatoi n) R inp dry silent outp rest)
               ("--input=" + (f && 0 < #f)) (fl >a p R f dry silent outp rest)
               (fl >a p R inp dry silent outp (<a . rest))))
       q (fl as () 0 () 0 0 () ())
       p <q R? <>q inp <>>q dry? (q 3) silent? (q 4) outp (q 5) rest (q 6)
       txt (string? inp ?
              (uread inp @ r (two? r ? <>r (udie 2 ("patch: cannot open " + inp))))
              (slurp in))
       secs (pt-parse (lines txt))
       _ (two? secs ? () (udie 2 "patch: no unified diff in the input"))
       ; the name: the new side unless the patch creates the file, and an operand wins
       ; over both -- which is how `patch f < p` retargets a diff cut somewhere else
       (name sec) (two? rest ? <rest
                   (<>sec @ nn
                      (nn = "/dev/null" ? (pt-strip <sec p) (pt-strip nn p))))
       (one acc sec)
        (: hs (R? ? (map pt-flip <>>sec) <>>sec)
           nm (string? outp ? outp (name sec))
           (acc + pt-file nm hs dry? silent?))
       bad (foldl one 0 secs)
       (flush out, flush err,
        bad ? 1 0)))
) ; module 'kore
