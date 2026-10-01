; test/kernel/pty.l -- the kernel's pty: the master the terminal's side, the slave the
; program's, and the line discipline between them -- echo, a line at a time with erase, kill
; and word, ^D as one read's end, \n out as \r\n -- then raw, the size, the foreground group,
; and tether over all of it, ^C ending the group that holds the terminal. kernel corpus only.

(: (pt-take fd n) (? (n < 1) "" (: c (see fd) (string c + pt-take fd (n - 1)))))

; three rows, a size from either side; the signal row is no terminal
(: fs (openpty 0) m <fs s <>fs q <>>fs
   a (tty s)
   _ (settty m 30 100)
   b (tty s) c (tty m)
   (close m, close s, close q,
    test (charm? m) (charm? s) (charm? q)
         ((24 . 80) = a) ((30 . 100) = b) ((30 . 100) = c) (nom? (tty q))))

; cooked: the keys echo, a rubout takes a character back off the line and the glass, and
; the program reads the line only once it is whole, its \r made \n
(: fs (openpty 0) m <fs s <>fs
   _ (say m "ab", put m 127, say m "c\r")
   l (pt-take s 3) e (pt-take m 8)
   ; ^U the line, ^W the word
   _ (say m "junk", put m 21, say m "one two", put m 23, say m "2\r")
   l2 (pt-take s 6)
   ; the program's \n leaves as \r\n
   _ (say s "x\ny")
   o (pt-take m (4 + 12 + 7 + 9 + 3 + 4))   ; junk, its rubouts, one two, two's, 2, x\r\ny
   (close m, close s, close <>>fs,
    test ("ac\n" = l) (("ab" + string 8 + " " + string 8 + "c\r\n") = e) ("one 2\n" = l2)
         ("x\r\ny" = snip o (#o - 4) #o)))

; ^D on an empty line is one read's end, and the line after it reads as ever; the master
; gone is the end for good
(: fs (openpty 0) m <fs s <>fs
   _ (put m 4)
   e (see s)
   _ (say m "z\r")
   l (pt-take s 2)
   _ (close m)
   h (see s)
   (close s, close <>>fs,
    test (-1 = e) ("z\n" = l) (-1 = h)))

; raw off fd 0: keys arrive as they are, unechoed, ^C a byte like any other; the
; foreground group is set and read the same way
(: fs (openpty 0) m <fs s <>fs
   sp (fdopen (dup s))
   w (worn ())
   _ (wear [sp out err])
   r (raw 1)
   _ (ttyfg 7)
   _ (wear w)
   g (ttypg m)
   _ (say m "k\r", put m 3)
   l (pt-take s 3)
   _ (say s "!")
   o (see m)
   _ (wear [sp out err])
   _ (raw 0) _ (ttyfg 0)
   _ (wear w)
   h (ttypg m)
   (close sp, close m, close s, close <>>fs,
    test (() = r) (7 = g) (("k\r" + string 3) = l) (33 = o) (() = h)
         (nom? (ttypg <>>fs))))

; tether: a child on a pty of its own, holding its terminal. its line comes back twice --
; the echo, then cat -- and ^C ends it where it stands: wait answers 128+2, the master
; reads the ^C's echo and then the end
(tether ["kore" "cat"] @ r
 (: p <r mp >r
    _ (say mp "hi\r", flush mp)
    t (pt-take mp 8)
    g (ttypg mp)
    _ (put mp 3, flush mp)
    st (wait p)
    tl (slurp mp)
    (close mp,
     test (charm? p) ("hi\r\nhi\r\n" = t) (p = g) (130 = st) ("^C" = tl))))
