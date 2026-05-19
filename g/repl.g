; the read-eval-print loop and its line editor. loaded after boot.g by
; the interactive frontends (host and kernel). the editor is a zipper
; (table) with 'l (chars left of the cursor, reversed) and 'r (focus and
; rest, in order); 'eof latches ^D. the cursor never crosses a newline,
; so a redraw only ever touches the current physical line.
(: (revappend a b) (foldl b (flip cons) a)
   (takenl l) (? (&& (twop l) (!= 10 (car l))) (cons (car l) (takenl (cdr l))) 0)
   (prc c) (putc (? (&& (<= 32 c) (< c 127)) c 32))
   (edleft z) (: l (get 0 'l z)
     (? (&& (twop l) (!= 10 (car l)))
        (put 'r (cons (car l) (get 0 'r z)) (put 'l (cdr l) z)) z))
   (edright z) (: r (get 0 'r z)
     (? (&& (twop r) (!= 10 (car r)))
        (put 'l (cons (car r) (get 0 'l z)) (put 'r (cdr r) z)) z))
   (edbsp z) (: l (get 0 'l z)
     (? (&& (twop l) (!= 10 (car l))) (put 'l (cdr l) z) z))
   (eddel z) (: r (get 0 'r z)
     (? (&& (twop r) (!= 10 (car r))) (put 'r (cdr r) z) z))
   (edhome z) (? (&& (twop (get 0 'l z)) (!= 10 (car (get 0 'l z))))
                 (edhome (edleft z)) z)
   (edend z) (? (&& (twop (get 0 'r z)) (!= 10 (car (get 0 'r z))))
                (edend (edright z)) z)
   (edit z ev) (? (< 0 ev) (put 'l (cons ev (get 0 'l z)) z)
                  (= ev -3) (edbsp z)  (= ev -4) (eddel z)
                  (= ev -1) (edleft z) (= ev -2) (edright z)
                  (= ev -5) (edhome z) (= ev -6) (edend z)
                  z)
   (edesc x) (? (!= 91 (getc 0)) 0
     (: c (getc 0)
        (? (= c 68) -1 (= c 67) -2 (= c 72) -5 (= c 70) -6
           (|| (= c 49) (= c 55)) (: _ (getc 0) -5)
           (|| (= c 52) (= c 56)) (: _ (getc 0) -6)
           (= c 51) (: _ (getc 0) -4) 0)))
   (edev x) (: c (getc 0)
     (? (|| (= c -1) (= c 4)) -7
        (|| (= c 13) (= c 10)) 10
        (|| (= c 8) (= c 127)) -3
        (= c 1) -5  (= c 5) -6  (= c 27) (edesc 0)
        (? (&& (<= 32 c) (< c 127)) c 0)))
   (edrender z) (: cr (takenl (get 0 'r z))
     (, (putc 27) (putc 56) (putc 27) (putc 91) (putc 75)
        (each (rev (takenl (get 0 'l z))) prc)
        (each cr prc)
        (? (twop cr) (, (putc 27) (putc 91) (putn (len cr) 10) (putc 68)) 0)
        (puts "")))
   (edreset z) (: _ (put 'l 0 z) _ (put 'r 0 z) (put 'eof 0 z))
   (edline z p) (: _ (puts p) _ (putc 27) _ (putc 55)
     (loop x) (: _ (edrender z) ev (edev 0)
       (? (= ev -7) (put 'eof -1 z)
          (= ev 10) (: _ (edit z 10) _ (putc 10)
                       (revappend (get 0 'l z) (get 0 'r z)))
          (: _ (edit z ev) (loop 0))))
     (loop 0))

   ; read-eval-print: edline gathers a line, parse turns it into a datum
   ; (or moresym, when the parens are still open -- keep editing the same
   ; zipper -- or eofsym, an empty line).
   z (new 0) e (sym 0) m (sym 0)
   (repl x)
     (: cl (edline z " ;; ")
        (? (get 0 'eof z) 0
           (: r (parse cl e m)
              (? (= r m) (repl 0)
                 (= r e) (: _ (edreset z) (repl 0))
                 (: _ (. (ev 'ev r)) _ (putc 10) _ (edreset z) (repl 0))))))
   (repl 0))
