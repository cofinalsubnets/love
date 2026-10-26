; test/caja/initex.l -- caja as tex -ini -interaction=batchmode, tripman's line lengths:
; each DIR holds NAME.tex for its basename NAME, and the job runs there as tex would.
;   love test/caja/initex.l ROOT TFMDIRS DIR..   ROOT the tree, TFMDIRS :-separated, paths absolute
(: r (argv 1)
   _ (borrow 'posix)
   _ (borrow (r + "/src/apps/tfm.l"))
   _ (borrow (r + "/src/apps/caja/box.l"))
   _ (borrow (r + "/src/apps/caja/mouth.l"))
   _ (borrow (r + "/src/apps/caja/exec.l"))
   _ (borrow 'caja-tex)
   (base d) (: (go k) (k < 0 || d k = 47 ? (snip d (k + 1) #d) (go (k - 1))) (go (#d - 1)))
   (split s) (: (go k a acc) (? (k >= #s) (rev (snip s a k . acc))
                                  (s k = 58) (go (k + 1) (k + 1) (snip s a k . acc))
                                  (go (k + 1) a acc))
                (go 0 0 ()))
   tfms (map (\ d (d + "/")) (split (argv 2)))
   (job d)
    (chdir d,
     tex-run {'line (base d + ".tex") 'interaction 0 'max-print-line 72 'error-line 64
              'half-error-line 32 'tex-inputs ["./"] 'tfm-dirs tfms})
   _ (map job >>>argv)
   0)
