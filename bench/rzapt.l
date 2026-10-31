; lore's apartment at 1280 by 800, NF frames (10 when unset) after five to settle, the heading
; turning a full circle over the run. ccmeter.sh reads its instructions a frame
(borrow 'world) (borrow 'posix)
(: nf (getenv "NF" @ s (string? s ? (read s) 10))
   lv (world-load "src/apps/lore/levels/apartment.l")
   st (world-new 1280 800 lv "src/apps/lore/levels/")
   (step th) (pins st 'dt (1.0 / 30.0) 'th th 'fv 0.0, world-move st, world-pens st)
   _ (each ^5 (_ \ step 0.0))
   _ (each ^nf (k \ step (6.2832 * k / nf)))
   0)
