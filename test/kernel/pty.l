; test/kernel/pty.l -- the kernel's pty: master the terminal's side, slave the program's,
; the line discipline between (echo, erase/kill/word, ^D, \n out as \r\n), raw, the size,
; the foreground group, and tether. kernel corpus only.

(: (pt-take fd n) (? (n < 1) "" (: c (see fd) (string c + pt-take fd (n - 1)))))

; three rows, a size from either side; the signal row is no terminal
(: fs (openpty 0) m <fs s <>fs q <>>fs
   a (tty s)
   _ (settty m 30 100)
   b (tty s) c (tty m)
   (close m, close s, close q,
    test (charm? m) (charm? s) (charm? q)
         ((24 . 80) = a) ((30 . 100) = b) ((30 . 100) = c) (nom? (tty q))))

; cooked: keys echo, a rubout takes a character back off line and glass, and the program
; reads only a whole line, its \r made \n
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

; ^D on an empty line is one read's end; the master gone is the end for good
(: fs (openpty 0) m <fs s <>fs
   _ (put m 4)
   e (see s)
   _ (say m "z\r")
   l (pt-take s 2)
   _ (close m)
   h (see s)
   (close s, close <>>fs,
    test (-1 = e) ("z\n" = l) (-1 = h)))

; raw off fd 0: keys arrive unechoed, ^C a byte like any other
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

; tether: a child holding its own pty echoes its line, cat repeats it, and ^C ends it:
; wait answers 128+2, the master reads the ^C's echo and then the end
(tether ["cat"] @ r
 (: p <r mp >r
    _ (say mp "hi\r", flush mp)
    t (pt-take mp 8)
    g (ttypg mp)
    _ (put mp 3, flush mp)
    st (wait p)
    tl (slurp mp)
    (close mp,
     test (charm? p) ("hi\r\nhi\r\n" = t) (p = g) (130 = st) ("^C" = tl))))

; the master closed is a hangup: a child that never reads still ends, as 128+1
(tether ["sleep" "100"] @ r
 (: p <r _ (close >r) st (wait p)
  (test (charm? p) (129 = st))))

; a child's quit leaves its parent's terminal be: a shell on a pty runs `cat` on a
; directory as its own task on the shell's slave, then reads the next line
(tether ["sh"] @ r
 (: p <r mp >r
    _ (say mp "cat /tmp\r", flush mp)
    _ (rest 1500)
    _ (say mp "echo \"a\"\"live\"; exit 3\r", flush mp)
    tl (slurp mp)
    st (wait p)
    (close mp,
     test (charm? p) (0 <= subidx tl "alive" 0) (3 = st))))

; a held task: catch answers at once and it has not landed; resumed, it finishes.
; nothing is held twice, or resumed that was not held
(: t (twirl (_ \ (rest 30, 7)) 0)
   h (pause t) h2 (pause t)
   _ (catch t) _ (rest 60)
   l (landed? t)
   w (resume t) w2 (resume t)
   r (catch t)
 (test (1 = h) (() = h2) (0 = l) (1 = w) (() = w2) (7 = r) (() = pause 999999)))

; ^Z holds the group in front (wait answers 256+20, the host's stopped status), and
; cont lets it go on: the line typed after it reads and comes back
(tether ["cat"] @ r
 (: p <r mp >r
    _ (put mp 26, flush mp)
    st (wait p)
    e (pt-take mp 2)
    c (still (0 - p) 18)
    _ (say mp "go\r", flush mp)
    t (pt-take mp 8)
    _ (put mp 3, flush mp)
    st2 (wait p)
    (close mp,
     test (276 = st) ("^Z" = e) (0 = c) ("go\r\ngo\r\n" = t) (130 = st2))))
