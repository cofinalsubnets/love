; --- test/host/baotest.l: the editor + repl + parseall unit battery ---
; the line editor (ed*), the history zipper (uphist/downhist/eddetach), joinln/splitat,
; and parseall are cli's exports (core/boot/post.l), reached through the module
; tablet: (from 'cli) hands the module back, (B 'edleft) reaches one, (keys B) lists them.
;
; cli is baked (in the host egg), so this file needs no -l:
;
;   cat test/00-init.l test/host/baotest.l | out/love
;
; (wired into `make test_hostnif`.) green dots = pass.
; (ed u l r d) builds a buffer; (b4 t) and (b7 t) read it back as a comparable list,
; with the history zipper for b7.

(: B (from 'cli)
   ednew (B 'ednew)       edstep (B 'edstep)     edput (B 'edput)       ednl (B 'ednl)
   edleft (B 'edleft)     edright (B 'edright)   edbsp (B 'edbsp)       eddel (B 'eddel)
   edhome (B 'edhome)     edend (B 'edend)       edtop (B 'edtop)       edbot (B 'edbot)
   edup (B 'edup)         eddown (B 'eddown)     uphist (B 'uphist)     downhist (B 'downhist)
   eddetach (B 'eddetach) edempty? (B 'edempty?) edframe (B 'edframe)   edparses? (B 'edparses?)
   edchars (B 'edchars)   edtext (B 'edtext)     edcol (B 'edcol)       edkey (B 'edkey)
   joinln (B 'joinln)     splitat (B 'splitat)   parseall (B 'parseall)
   (ed u l r d) (pins (ednew ()) 'u u 'l l 'r r 'd d)
   (edh u l r d hu hd cur) (pins (ed u l r d) 'hu hu 'hd hd 'cur cur)
   (b4 t) ((t 'u) >< (t 'l) >< (t 'r) >< (t 'd))
   (b7 t) ((t 'u) >< (t 'l) >< (t 'r) >< (t 'd) >< (t 'hu) >< (t 'hd) >< (t 'cur))
   (k4 u l r d) (u >< l >< r >< d)
   (k7 u l r d hu hd cur) (u >< l >< r >< d >< hu >< hd >< cur)
   (fr u l r d) (edframe (ed u l r d))
   ; a key list through edstep, answering the buffer
   (typed t ks) (each ks (c \ edstep t c), t)
   results [
   ; --- edleft / edright / edbsp / eddel / edhome / edend ---
  ((k4 () '(1) '(2 3) ()) = (b4 (edleft (ed () '(2 1) '(3) ()))))
  ((k4 () '(2 1) () ['(3)]) = (b4 (edleft (ed ['(1 2)] () '(3) ()))))
  ((k4 () () '(1 2) ()) = (b4 (edleft (ed () () '(1 2) ()))))
  ((k4 () '(1) '(2 3) ()) = (b4 (edright (ed () () '(1 2 3) ()))))
  ((k4 ['(1 2)] () '(3 4) ()) = (b4 (edright (ed () '(2 1) () ['(3 4)]))))
  ((k4 () '(2 1) () ()) = (b4 (edright (ed () '(2 1) () ()))))
  ((k4 () '(1) '(3) ()) = (b4 (edbsp (ed () '(2 1) '(3) ()))))
  ((k4 () '(2 1) '(3) ()) = (b4 (edbsp (ed ['(1 2)] () '(3) ()))))
  ((k4 () () '(1) ()) = (b4 (edbsp (ed () () '(1) ()))))
  ((k4 () '(1) '(3) ()) = (b4 (eddel (ed () '(1) '(2 3) ()))))
  ((k4 () '(1) '(2 3) ()) = (b4 (eddel (ed () '(1) () ['(2 3)]))))
  ((k4 () '(1) () ()) = (b4 (eddel (ed () '(1) () ()))))
  ((k4 () () '(1 2 3) ()) = (b4 (edhome (ed () '(2 1) '(3) ()))))
  ((k4 () '(3 2 1) () ()) = (b4 (edend (ed () '(2 1) '(3) ()))))
   ; --- edtop / edbot ---
  ((k4 () () '(1 2 3) ()) = (b4 (edtop (ed () '(2 1) '(3) ()))))
  ((k4 () '(3 2 1) () ()) = (b4 (edbot (ed () '(2 1) '(3) ()))))
  ((k4 () () '(1) ['(2) '(3)]) = (b4 (edtop (ed ['(2) '(1)] '(3) () ()))))
  ((k4 ['(2) '(1)] '(3) () ()) = (b4 (edbot (ed () '(1) () ['(2) '(3)]))))
  ((k4 () () '(1) ['(8 9) '(4)]) = (b4 (edtop (ed ['(1)] '(8) '(9) ['(4)]))))
   ; --- edup / eddown ---
  ((k4 () '(1) '(2 3 4) ['(5 6)]) = (b4 (edup (ed ['(1 2 3 4)] '(5) '(6) ()))))
  ((k4 () '(2 1) () ['(3 4 5 6)]) = (b4 (edup (ed ['(1 2)] '(4 3) '(5 6) ()))))
  ((k4 () '(1) '(2) ()) = (b4 (edup (ed () '(1) '(2) ()))))
  ((k4 ['(5 6)] '(1) '(2 3 4) ()) = (b4 (eddown (ed () '(5) '(6) ['(1 2 3 4)]))))
  ((k4 () '(1) '(2) ()) = (b4 (eddown (ed () '(1) '(2) ()))))
   ; --- edput / ednl / edchars / edtext / edcol ---
  ((k4 () '(2 1) '(3) ()) = (b4 (edput (ed () '(1) '(3) ()) 2)))
  ((k4 ['(1)] () '(3) ()) = (b4 (ednl (ed () '(1) '(3) ()))))
  ('(1 2 3) = (edchars (ed () '(2 1) '(3) ())))
  ('(1 10 2) = (edchars (ed ['(1)] '(2) () ())))
  ('(1 10 2 10 3) = (edchars (ed ['(1)] '(2) () ['(3)])))
  ("ab" = (edtext (ed () [97] [98] ())))
  (2 = (edcol (ed () '(2 1) '(3) ())))
   ; --- edstep: a key at a time, 'ev holds what the editor left to the caller ---
  ("abc" = (edtext (typed (ednew ()) [97 98 99])))
  ("abc" = (edtext (typed (ednew ()) [97 99 -1 98])))              ; left, then b
  ("abc" = (edtext (typed (ednew ()) [97 98 120 127 99])))         ; x, backspace
  ("abc" = (edtext (typed (ednew ()) [98 99 -5 97])))              ; home, a
  ("abc" = (edtext (typed (ednew ()) [97 -5 -6 98 99])))           ; home, end
  ("ac" = (edtext (typed (ednew ()) [97 98 99 -1 -1 -4])))         ; left left del
  (0 = ((typed (ednew ()) [97]) 'ev))                              ; a key taken
  (10 = ((typed (ednew ()) [97 13]) 'ev))                          ; enter is 10
  (27 = ((typed (ednew ()) [97 27]) 'ev))                          ; escape is the caller's
  (-8 = ((typed (ednew ()) [97 -8]) 'ev))                          ; up with no line above
  ("a" = (edtext (typed (ednew ()) [97 -8 -9])))                  ; ..and the text stands
  (: t (typed (ed ['(1 2)] () () ()) [-8]) (0 = (t 'ev) && '(1 2 10) = (edchars t)))  ; up with a line above is a motion
   ; --- joinln / splitat ---
  (() = (joinln ()))
  ('(1 2 3) = (joinln ['(1 2 3)]))
  ('(1 10 2) = (joinln ['(1) '(2)]))
  ('(1 2 10 3 10 4 5) = (joinln ['(1 2) '(3) '(4 5)]))
  (('(2 1) >< '(3 4)) = (splitat link () 2 '(1 2 3 4)))
  (('(2 1) >< ()) = (splitat link () 5 '(1 2)))
  ((() >< '(1 2 3)) = (splitat link () 0 '(1 2 3)))
   ; --- edframe / eddetach / edempty? / edparses? ---
  ([() '(1) ()] = (fr () '(1) () ()))
  ('(((1)) (2 3) (4) (5)) = (fr ['(1)] '(2 3) '(4) ['(5)]))
  (() = ((eddetach (edh () () () () () () ())) 'hu))
  (: cur (fr () '(1) () ()) ([cur] = ((eddetach (edh () () () () () () cur)) 'hu)))
  (: cur (fr () '(1) () ()) old (fr () '(9) () ())
     (: t (eddetach (edh () () () () [old] () cur)) ([cur old] = (t 'hu) && () = (t 'cur))))
  (edempty? (ed () () () ()))
  !(edempty? (ed () '(1) () ()))
  !(edempty? (ed ['(1)] () () ()))
  !(edempty? (ed () () '(1) ()))
  !(edempty? (ed () () () ['(1)]))
  (edparses? (ed () [49] () ()))
  !(edparses? (ed () () () ()))
  !(edparses? (ed () [40] () ()))
  (edparses? (ed [[40]] [41] () ()))
   ; --- uphist / downhist ---
  (: cur (fr () '(1) () ()) old (fr () '(9) () ())
     ((k7 () '(9) () () () [cur] old) = (b7 (uphist (edh () '(1) () () [old] () cur)))))
  (: old (fr () '(9) () ())
     ((k7 () '(9) () () () () old) = (b7 (uphist (edh () () () () [old] () ())))))
  (: cur (fr () [49] () ())
     ((k7 () () () () () [cur] ()) = (b7 (uphist (edh () [49] () () () () cur)))))
  (: cur (fr () [40] () ())
     ((k7 () [40] () () () () cur) = (b7 (uphist (edh () [40] () () () () cur)))))
  ((k7 () [49] () () () () ()) = (b7 (uphist (edh () [49] () () () () ()))))
  (: cur (fr () '(1) () ()) new (fr () '(9) () ())
     ((k7 () '(9) () () [cur] () new) = (b7 (downhist (edh () '(1) () () () [new] cur)))))
  (: new (fr () '(9) () ())
     ((k7 () '(9) () () () () new) = (b7 (downhist (edh () () () () () [new] ())))))
  (: cur (fr () [49] () ())
     ((k7 () () () () [cur] () ()) = (b7 (downhist (edh () [49] () () () () cur)))))
   ; --- edkey: bytes as themselves, the escape family decoded, esc x pushed back ---
  (97 = (edkey (tap [97])))
  (-7 = (edkey (tap ())))
  (-1 = (edkey (tap [27 91 68])))                                 ; left
  (-8 = (edkey (tap [27 91 65])))                                 ; up
  (-5 = (edkey (tap [27 91 72])))  (-6 = (edkey (tap [27 91 70])))  ; home end
  (-5 = (edkey (tap [27 91 49 126])))  (-4 = (edkey (tap [27 91 51 126])))
  (-10 = (edkey (tap [27 91 49 59 53 72])))                       ; ctrl-home
  (377 = (edkey (tap [27 121])))                                  ; alt-y
  (: p (tap [27 58]) a (edkey p) b (edkey p) ([27 58] = [a b]))      ; esc, then a colon: two keys
   ; --- parseall: a line is one expression; floats; the more-sentinel ---
   ; a single datum is returned as-is in a one-list (no extra wrap), so a leading
   ; monadic stays fused: "+(-3)" -> (mono (+ (-3))) -> -3, not the head-position (+ -3).
  ('((1 2 3)) = (parseall '(49 32 50 32 51)))            ; "1 2 3" -> the application
  ('((1 2)) = (parseall '(40 49 32 50 41)))              ; "(1 2)" -> the one form, as-is
  (-3 = (ev <(parseall '(43 40 45 51 41))))              ; "+(-3)" -> monadic net = -3 (the bug fix)
  (() = (parseall ()))
  !(two? (parseall '(40 49)))
  (1.5 = <(parseall '(49 46 53)))
  (1000.0 = <(parseall '(49 101 51)))
  (two? <(parseall '(49 46 50 46 51)))      ; "1.2.3": a digit-led run factors now (test/glued.l), no longer a nom
   ; the more-sentinel: an unclosed shape is m (not two?); a complete datum is
  !(two? (parseall '(40 43 32 49)))                   ; "(+ 1" unclosed
  (two? (parseall '(49 32 43)))                       ; "1 +" complete (the curry partial)
  (two? (parseall '(49 32 63 32 39 97)))              ; "1 ? 'a" complete (curried cond)
  (two? (parseall '(40 43 32 49 32 50 41)))           ; "(+ 1 2)" closed
  (two? (parseall '(49 32 61 32 49)))]                ; "1 = 1"

   ; every check in the battery must be true.
   _ (each results (\ b (assert b)))
   ; and the battery must be non-trivial (a typo'd list returning () would
   ; vacuously pass the each above).
   _ (assert (< 50 (tally results))))

(test_fin ())
(puts "baotest: ok") (putc 10)
