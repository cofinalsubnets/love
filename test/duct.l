; the duct (src/love/io.c): a buffered port whose far side is love's. duct-feed puts bytes for
; the program and duct-take gets what it wrote; say, see, chug, cue?, seal and close work it
(: d (duct 8)
   _ (test (hot? d) (!(cue? d)) (duct-room d = 8) (duct-take d = ""))
   ; a feed takes what fits; the run is read as any port's
   _ (test (duct-feed d "hello world" = 8) (duct-room d = 0) (cue? d)
           (see d = 104) (chug d = "ello wo") (duct-room d = 8)
           (duct-feed d "rld" = 3) (see d = 114) (chug d = "ld"))
   ; what the program writes waits for a take
   _ (say d "abc")
   _ (flush d)
   _ (test (duct-take d = "abc") (duct-take d = ""))
   ; the fed end: every read after answers it
   _ (test (duct-feed d () = 0) (cue? d) (see d = -1) (see d = -1))
   ; the write half sealed: a take answers () once spent, the read half stays
   _ (say d "01234567")
   _ (test (seal d 1 = d) (duct-take d = "01234567") (duct-take d = ()) (duct-room d = 8))
   e (duct 0)
   ; a close lands the run, then shuts both halves
   _ (say e "x")
   _ (close e)
   (test (duct-take e = "x") (duct-take e = ()) (duct-room e = -1) (duct-feed e "z" = -1)
         (see e = -1)
         (duct 'a = 'badarg) (duct-take 5 = 'badarg) (duct-feed 3 "x" = 'badarg)
         (duct-seal d 7 = 'badarg) (duct-room "d" = 'badarg)))

; a nom fed is the end and the far side gone: writes fail, and no run is left behind
(: d (duct 0)
   _ (duct-feed d 'econnreset)
   _ (say d "lost")
   _ (flush d)
   (test (see d = -1) (duct-take d = "")))

; a full side parks its task: a writer past a small duct waits on the takes, a reader on a feed
(: d (duct 64)
   msg (string (map (i \ i * 7 & 255) ^5000))
   w (twirl (_ \ (say d msg, seal d 1, 1)) 0)
   (take acc) (duct-take d @ b (b = () ? (join "" (rev acc)) (rest 0, take (b . acc))))
   got (take ())
   _ (test (catch w) (got = msg))
   r (twirl (_ \ see d @ c (c = -1 ? () (string c + chug d))) 0)
   _ (rest 2)
   _ (test (!(landed? r)))
   _ (duct-feed d "late")
   (test (catch r = "late")))
