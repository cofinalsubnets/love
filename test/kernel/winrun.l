; test/kernel/winrun.l -- a window on inle's paper, under node with --fb: hold the paper, lay
; it orange and show it, then say every event that comes -- the keys --press sends, the
; pointer --click sends, the text on stdin -- until the pointer lets go. the paper stays held
; through the reset, so the gate's dump shows it.
(: wh (kpaper 1)
   w (two? wh ? <wh 0) h (two? wh ? (wh 1) 0)
   p (cask (w * h * 4))
   row (cask (w * 4))
   _ (each ^w (x \ (pin row (4 * x + 1) 128, pin row (4 * x + 2) 255)))   ; 0x00ff8000
   _ (each ^h (y \ pour p (y * w * 4) row 0 (w * 4)))
   n (kshow p 0 h)
   _ (puts ("winrun: paper " + show w + "x" + show h + " shown " + show n + "\n"), flush out)
   (go k) (kwin-events 0 @ l
             ((each l (r \ puts ("winrun: " + show r + "\n"))), flush out,
              (any (r \ <r = 'release) l || 600 < k ? 0 (rest 20, go (k + 1)))))
   (go 0, rest 1500, puts "winrun: done\n", flush out, reset ()))
