; src/apps/vi/vi.l -- the terminal face over src/apps/vi/core.l: read keys off `in`,
; blit vframe's escapes onto `out`, perform the write requests the ex commands
; leave on the state. a toolbox-style file (kore is its door: `kore vi FILE`);
; loads after core.l/re.l/vi core in the kore cat and rides the u-floor (uread,
; udie) and text.l's lines/unlines.
;
; the visit is berth's harbour where the seat carries one -- each buffer a stage in a
; pane, split by :sp/:vs or the prefix -- and cli's `stage` otherwise: raw tty, the
; alternate screen, one key a step through cli's edkey (arrows, alt letters, a bare
; escape after a beat), and port EOF leaves -- a piped script (the smoke lane) ends
; with :wq and never dangles.
(module 'vi
(borrow 'kore) ; the text/u floors
(borrow 'posix)

(:
   ; a state for a file, read or new; the pens are the face's to hand over -- they
   ; want $colorterm and the user's own theme file, and the engine reads neither
   (vi-open f)
    (: r (0 < #f ? (uread f))
       st (vnew (two? r ? (lines <>r)) f)
       (0 < #f && atom? r ? (vmsg st (f + ": new file")),
        (pin st 'pens (hues-wake ()), st)))
   ; the ex write requests: (name) means write, "" means the buffer's file
   (dow s2)
    (s2 'dow @ rq
       (atom? rq ? s2
          (: _ (pin s2 'dow ())
             nm <rq
             (0 < #nm ?
                (open nm "w" @ q
                   (hot? q ? (say q (unlines (s2 'lines)), close q, pin s2 'dirty (),
                              vmsg s2 (nm + " written"))
                      (pin s2 'quit (),                   ; a failed wq must not quit
                       vmsg s2 ("cannot write " + nm))))
                (pin s2 'quit (), vmsg s2 "no file name")))))
   ; the ex read requests: (name) means put that file in the buffer. a name
   ; that does not open is not an error -- it is a new file, the same welcome
   ; the startup above gives one. presence is uread's (1 text) wrapper, not
   ; the text: an empty file is a real file with nothing in it.
   (doe s2)
    (s2 'doe @ rq
       (atom? rq ? s2
          (: _ (pin s2 'doe ())
             nm <rq
             r (uread nm)
             (vload s2 (two? r ? (lines <>r)) nm,
              vmsg s2 (two? r ? (nm + ": " + show #(s2 'lines) + " lines")
                          (nm + ": new file"))))))
   ; the ex split requests: (dir name) means another buffer, on name or fresh, beside
   ; or under this one. split is the harbour's door, or () on a seat with no harbour
   (dos s2 split)
    (s2 'dos @ rq
       (atom? rq ? s2
          (pin s2 'dos (), split ? (split <rq <>rq) (vmsg s2 "no splits on this seat"), s2)))
   ; the ex words the engine does not know: (word arg) goes to the face's ex door,
   ; which answers true when it took it and the complaint stands otherwise
   (dox s2 ex)
    (s2 'dox @ rq
       (atom? rq ? s2
          (pin s2 'dox (),
           ex ? (s2 'msg @ m (pin s2 'msg "", ex s2 <rq <>rq ? 0 (pin s2 'msg m))) 0,
           s2)))
   ; the face: cli's triple over a state and a paste, with the doors a host lends it
   ; -- 'split (dir name), 'ex (state word arg) and 'reg, a box the register is kept
   ; in between steps so every buffer on a wharf shares one; any may be missing. the
   ; paste takes a register's value: a put in normal mode, the text typed in insert.
   ; the stage hides the cursor; vi's frame places it, so the frame shows it. vfresh,
   ; not vframe: a full redraw a keystroke is what the flicker is, and it writes only
   ; the rows that changed since the last
   (vi-face st doors)
    (: box (peep doors 'reg ())
       (load _) (box ? (pin st 'reg (peep box () (st 'reg))) 0)
       (keep _) (box ? (pin box () (st 'reg)) 0)
       (text v) (? (atom? v) "" (<v = 'lin) (foldl (a \ l \ a + l + "\n") "" <>v) <>v)
       (type s) (map (c \ vstep st c) (map (i \ s i) ^#s))
     [(w \ h \ (pins st 'w w 'h h, "\e[?25h" + vfresh st))
      (c \ (load (), vstep st c, keep (), dow st, doe st, dos st (peep doors 'split ()), dox st (peep doors 'ex ())))
      (_ \ (st 'quit))
      (v \ (? (elem (st 'mode) '(i c s)) (type (text v))
              (pin st 'reg v, vstep st 112, keep ())))])
   ; a buffer handed over from elsewhere (ex's `vi`), visited full screen on cli's stage:
   ; its lines, its file, whether it already differs from that file, the line to open on
   (vi-buffer ls f dirty row)
    (: st (vi-open "")
       _ (vload st ls f)
       _ (pins st 'dirty dirty 'row (0 < row ? (row - 1) 0))
       fc (vi-face st {})
       (stage (fc 0) (fc 1) (fc 2)))
   ; the visit: on a harbour where the seat has one -- every buffer a stage in a pane
   ; of its own, :sp and :vs and the prefix's C-a s and C-a v opening another, :q
   ; shutting the one it is typed in, one register between them -- else cli's stage,
   ; one buffer full screen
   (vi-main as)
    (: f (two? as ? <as "")
       ; vi reads no options: a dash word would open a new file named after it
       _ (1 < #f && f 0 = 45 ? (udie 2 ("vi: unknown option " + f)))
       st (vi-open f)
       br (cite 'berth)
       (tablet? br ?
          (: sz (br 'hsize 0) hb (br 'harbour <sz <>sz)
             (stage-of s) (: fc (vi-face s {'split split 'reg (hb 'clip)})
                              sg (br 'berth-stage (fc 0) (fc 1) (fc 2))
                              (pin sg 'paste (fc 3), sg))
             (split d nm) (br 'hberth hb d 50 (br 'hopen-stage (stage-of (vi-open nm)) 1 1))
             (pin hb 'more (_ \ (br 'hopen-stage (stage-of (vi-open "")) 1 1)),
              br 'hberth hb 'stack 50 (br 'hopen-stage (stage-of st) <sz <>sz),
              br 'hsail hb))
          (vi-face st {} @ fc (stage (fc 0) (fc 1) (fc 2))))))
) ; module 'vi
