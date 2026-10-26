; test/caja/trip.l -- one of tripman's two runs of caja in DIR, which holds trip.tex and trip.tfm:
; pass 1 is `\input trip', which dumps trip.fmt, and pass 2 `&trip  trip', at tripman's line lengths
;   love test/caja/trip.l ROOT DIR PASS   paths absolute
(: r (argv 1)
   _ (borrow 'posix)
   _ (borrow (r + "/src/apps/tfm.l"))
   _ (borrow (r + "/src/apps/caja/box.l"))
   _ (borrow (r + "/src/apps/caja/par.l"))
   _ (borrow (r + "/src/apps/caja/page.l"))
   _ (borrow (r + "/src/apps/caja/mouth.l"))
   _ (borrow (r + "/src/apps/caja/build.l"))
   _ (borrow (r + "/src/apps/caja/exec.l"))
   _ (borrow 'caja-tex)
   (run l)
    (tex-run {'line l 'max-print-line 72 'error-line 64 'half-error-line 32
              'tex-inputs ["./"] 'tfm-dirs ["./"]})
   _ (chdir (argv 2))
   _ (run (argv 3 = "1" ? "\\input trip" "&trip  trip "))
   0)
