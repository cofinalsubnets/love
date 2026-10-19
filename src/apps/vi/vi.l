; src/apps/vi/vi.l -- the terminal face over core.l: keys off `in`, vframe's escapes onto
; `out`, and the write requests ex leaves on the state. kore is its door (`love vi FILE`).
; a mitty where the seat has one, else cli's stage: raw tty, alternate screen, port EOF
; leaves, so a piped script ending :wq never dangles
(module 'vi
(borrow 'kore) ; the text/u floors
(borrow 'posix)

(:
   ; a state for a file, read or new
   (vi-open f)
    (: r (0 < #f ? (uread f))
       st (vnew (two? r ? (lines <>r)) f)
       (pin st 'home (getenv "HOME"),
        0 < #f && atom? r ? (vmsg st (f + ": new file")),
        (vi-theme st ())))
   ; the pens, and the door :colorscheme rings to swap them: the face reads the env and the
   ; theme file, the engine neither
   (vi-theme st nm)
    (pin st 'pens (hues-wake nm), pin st 'theme (hue-name nm),
     pin st 'retheme (n \ two? (hue-theme-of n) ? (hues-wake n) ()),
     st)
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
   ; the ex read requests: (name) put in the buffer; one that does not open is a new file.
   ; presence is uread's (1 text), so an empty file is a real file
   (doe s2)
    (s2 'doe @ rq
       (atom? rq ? s2
          (: _ (pin s2 'doe ())
             nm <rq
             r (uread nm)
             (vload s2 (two? r ? (lines <>r)) nm,
              vmsg s2 (two? r ? (nm + ": " + show #(s2 'lines) + " lines")
                          (nm + ": new file"))))))
   ; the ex split requests: (dir name), another buffer beside or under; split is the mitty's
   ; door, or () with no mitty
   (dos s2 split)
    (s2 'dos @ rq
       (atom? rq ? s2
          (pin s2 'dos (), split ? (split <rq <>rq) (vmsg s2 "no splits on this seat"), s2)))
   ; the picker requests: (word query) opens seek under the cwd -- :find files, :grep lines --
   ; in the buffer's place; a pick opens the file there, a line on its row; esc goes back
   (dof s2)
    (s2 'dof @ rq
       (atom? rq ? s2
          (: _ (pin s2 'dof ())
             find? (<rq = "find")
             fs (cite 'seek 'seek-files ".")
             d (? find? (cite 'seek 'seek-new fs (f \ f) (f \ f) "find")
                  (cite 'seek 'seek-new (cite 'seek 'seek-lines fs) (it \ it 2) (cite 'seek 'seek-label ".") "grep"))
             (0 < #(<>rq) ? (cite 'seek 'seek-q d (<>rq)) 0,
              pin s2 'seek d, s2))))
   ; the picked: a file, or [file line text]; the buffer's own file just moves the cursor
   (vpicked s2 it)
    (: f (string? it ? it (it 0))
       row (string? it ? 0 (it 1 - 1))
       (? (f = s2 'file) (pins s2 'row row 'col 0)
          (s2 'dirty) (vmsg s2 "no write since last change")
          (uread f @ r
             (vload s2 (two? r ? (lines <>r)) f,
              pins s2 'row row 'col 0,
              vmsg s2 (f + ": " + show #(s2 'lines) + " lines")))))
   ; a key while the picker is up is the picker's; when it goes the buffer is drawn whole
   (vseek s2 c)
    (: d (s2 'seek)
       ((cite 'seek 'seek-key) d c,
        d 'over ? (pins s2 'seek () 'lastr (), d 'pick @ it (it ? (vpicked s2 it) 0)) 0))
   ; the explore requests: (dir) to the face's 'explore door (state dir); none, no explorer
   (dex s2 ex)
    (s2 'dex @ rq
       (atom? rq ? s2
          (pin s2 'dex (), ex ? (ex s2 <rq) (vmsg s2 "no explorer on this seat"), s2)))
   ; ex words the engine does not know: (word arg) to the face's ex door, which answers true
   ; when it took it, else the complaint stands
   (dox s2 ex)
    (s2 'dox @ rq
       (atom? rq ? s2
          (pin s2 'dox (),
           ex ? (s2 'msg @ m (pin s2 'msg "", ex s2 <rq <>rq ? 0 (pin s2 'msg m))) 0,
           s2)))
   ; the face: cli's triple and a paste over a state, with the doors a host lends it, any
   ; missing: 'split (dir name), 'ex (state word arg), 'explore (state dir), 'reg a box
   ; holding the register between steps so every buffer shares one. the paste puts in normal
   ; mode, types in insert. vfresh, not vframe: it writes only the rows that changed
   (vi-face st doors)
    (: box (doors 'reg)
       (load _) (box ? (pin st 'reg (peep box () (st 'reg))) 0)
       (keep _) (box ? (pin box () (st 'reg)) 0)
       (text v) (? (atom? v) "" (<v = 'lin) (foldl (a \ l \ a + l + "\n") "" <>v) <>v)
       ; a paste is text, not typing: its own indent stands, so :set ai sits it out
       (type s) (: ai (st 'ai) _ (pin st 'ai ()) _ (each ^#s (i \ vstep st (s i))) (pin st 'ai ai))
     [(w \ h \ (pins st 'w w 'h h, st 'seek @ d (nil? d ? ("\e[?25h" + vfresh st) (cite 'seek 'seek-frame d w h))))
      (c \ (nil? (st 'seek) ? (load (), vstep st c, keep (), dow st, doe st, dos st (doors 'split), dox st (doors 'ex), dof st, dex st (doors 'explore))
               (vseek st c)))
      (_ \ (st 'quit))
      (v \ (? (elem (st 'mode) '(i c s)) (type (text v))
              (pin st 'reg v, vstep st 112, keep ())))])
   ; a buffer handed over (ex's `vi`), full screen: lines, file, already dirty?, the line to open
   (vi-buffer ls f dirty row)
    (: st (vi-open "")
       _ (vload st ls f)
       _ (pins st 'dirty dirty 'row (0 < row ? (row - 1) 0))
       fc (vi-face st {})
       (stage (fc 0) (fc 1) (fc 2)))
   ; the visit: on a mitty every buffer a pane (:sp :vs, C-a s, C-a v), one register between
   ; them; else cli's stage, one buffer full screen
   (vi-main as)
    (: f (two? as ? <as "")
       ; vi reads no options: a dash word would open a file named after it
       _ (1 < #f && f 0 = 45 ? (udie 2 ("vi: unknown option " + f)))
       st (vi-open f)
       br (cite 'mitty)
       (tablet? br ?
          (: sz (br 'hsize 0) hb (br 'mitty-up <sz <>sz)
             (stage-of s) (: fc (vi-face s {'split split 'explore explore 'reg (hb 'clip)})
                              sg (br 'mitty-stage (fc 0) (fc 1) (fc 2))
                              (pin sg 'paste (fc 3), sg))
             ; a buffer's pane, kept on it so a door can show it again
             (berth-of s r c) (br 'hopen-stage (stage-of s) r c @ p (pin s 'vpane p, p))
             (split d nm) (br 'hberth hb d 50 (berth-of (vi-open nm) 1 1))
             ; :ex -- mc in a pane beside, its enter on a file opening that file in s
             (explore s d) (: mc (cite 'mc)
                              dir (0 < #d ? d ("" + cwd 0))
                              ms ((mc 'mc-new) dir dir)
                              _ (pin ms 'open (f \ (vpicked s f,
                                                      s 'vpane @ p (nil? p ? 0 (br 'hshow p)),
                                                      br 'hsoil hb)))
                              sg (br 'mitty-stage (w \ h \ (mc 'mc-frame) ms w h) (c \ (mc 'mc-key) ms c) (_ \ ms 'over))
                              (pin sg 'name "mc", br 'hberth hb 'beside 35 (br 'hopen-stage sg 1 1)))
             (pin hb 'more (_ \ (berth-of (vi-open "") 1 1)),
              br 'hberth hb 'stack 50 (berth-of st <sz <>sz),
              br 'hsail hb))
          (vi-face st {} @ fc (stage (fc 0) (fc 1) (fc 2))))))
) ; module 'vi
