; apps/vi/vi.l -- the terminal face over apps/vi/core.l: read keys off `in`,
; blit vframe's escapes onto `out`, perform the write requests the ex commands
; leave on the state. a toolbox-style file (kore is its door: `kore vi FILE`);
; loads after core.l/re.l/vi core in the kore cat and rides the u-floor (uread,
; udie) and text.l's lines/unlines.
;
; the visit is cli's `stage`: raw tty, the alternate screen, one key a step through
; cli's edkey (arrows, alt letters, a bare escape after a beat), and port EOF leaves --
; a piped script (the smoke lane) ends with :wq and never dangles.
(module 'vi
(use 'kore) ; the text/u floors
(:
   (vi-main as)
    (: f (? (two? as) <as "")
       r (? (< 0 (tally f)) (uread f) ())
       st (vnew (? (two? r) (lines <>r) ()) f)
       _ (? ((< 0 (tally f)) && !(two? r)) (vmsg st (+ f ": new file")) ())
       ; the pens are the face's to hand over -- they want $colorterm and the
       ; user's own theme file, and the engine reads neither
       _ (pin st 'pens (hue-wake ()))
       ; the ex write requests: (name) means write, "" means the buffer's file
       (dow s2)
        (: rq (s2 'dow)
           (? !(two? rq) s2
              (: _ (pin s2 'dow ())
                 nm <rq
                 (? (< 0 (tally nm))
                    (: q (open nm "w")
                       (? (hot? q) (: _ (say q (unlines (s2 'lines))) _ (close q)
                               _ (pin s2 'dirty ())
                               (vmsg s2 (+ nm " written")))
                          (: _ (pin s2 'quit ())          ; a failed wq must not quit
                             (vmsg s2 (+ "cannot write " nm)))))
                    (: _ (pin s2 'quit ())
                       (vmsg s2 "no file name"))))))
       ; the ex read requests: (name) means put that file in the buffer. a name
       ; that does not open is not an error -- it is a new file, the same welcome
       ; the startup above gives one. presence is uread's (1 text) wrapper, not
       ; the text: an empty file is a real file with nothing in it.
       (doe s2)
        (: rq (s2 'doe)
           (? !(two? rq) s2
              (: _ (pin s2 'doe ())
                 nm <rq
                 r (uread nm)
                 _ (vload s2 (? (two? r) (lines <>r) ()) nm)
                 (vmsg s2 (? (two? r) (nm + ": " + show (tally (s2 'lines)) + " lines")
                              (nm + ": new file"))))))
       ; the stage hides the cursor; vi's frame places it, so the frame shows it
       (stage (\ w h (pins st 'w w 'h h, "\e[?25h" + vframe st))
              (\ c (vstep st c, dow st, doe st))
              (\ _ (st 'quit)))))
) ; module 'vi
