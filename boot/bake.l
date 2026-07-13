; --- boot/bake.l: smoke test for the bake nif (host/image.c + ai_image_save_) ---
; (bake path) snapshots the LIVE session to an image file MID-EVAL -- the running
; stack rides along as wake-unreachable ballast, live finalizer nodes forge into
; dead chains, and a NULL bio-buffer word encodes as an immortal -- and `ai --wake
; PATH prog.l` boots a session carrying every global pinned before the bake.
; host-only (the nif + run + --wake), so it runs standalone against the built
; binary like boot/fs.l:
;   cat test/00-init.l boot/bake.l | out/host/ai
(: img "out/.bake-nif-smoke.image"
   drv "out/.bake-nif-drive.l"
   _ (unlink img) _ (unlink drv)                    ; a clean slate, tolerated if absent
   _ (pin book 'bake-smoke-marker 4242)

   ; the bake answers 1 and the session RIDES ON (this very assert runs post-dump);
   ; note the file port feeding THIS script is live at the dump -- the fz leg.
   _ (assert ((bake img) = 1))

   ; the woken child reads the marker this session pinned before its bake
   _ (: p (open drv "w") _ (say p "(: _ (putn bake-smoke-marker) (quit 0))") (close p))
   r (run `("out/host/ai" "--wake" img drv))
   _ (assert (two? r) (<r = 0) (>r = "4242"))

   _ (unlink img) _ (unlink drv)
   (puts "bake: ok\n"))
