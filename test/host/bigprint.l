; test/host/bigprint.l -- a big's digits in products, and a long print stopped
; four times the digits costs well under sixteen times the time; a show aboard a task yields, so a
; freeze lands at once; and the repl's ^C stops a print where it stands, the next line answering.
; host-side for its clocks: a ratio on the stress build says nothing.
;   cat test/00-init.l test/host/bigprint.l | out/love
(borrow 'posix)
(: love <cmdline
   (best f x) (: (go k b) (k = 0 ? b (: t (clock 0) _ (f x) (go (k - 1) (min b (clock t)))))
                 (go 3 1000000))
   v1 (65536 5)  v2 (262144 5)
   a (best show v1)
   b (best show v2)
   _ (test (b < 12 * a) (b < 1000))

   ; reading by halves, the same; radix too, which walked a digit at a time
   (rd s) <(sound s)
   r1 (show v2)  r2 (show (1048576 5))
   c (best rd r1)
   d (best rd r2)
   (rx b) (x \ radix x b)
   e (best (rx 16) v1)
   f (best (rx 7) v1)
   _ (test (d < 12 * c) (d < 3000) (e < 300) (f < 300))

   ; a product eight times lopsided goes in short-sized karatsuba pieces: well under the
   ; square of its long operand, which schoolbook pieces cost as much as
   la ((64 * 16384) 2 - 5)  lb ((64 * 2048) 2 - 3)
   h (best (x \ x * lb) la)
   i (best (x \ x * x) la)
   _ (test (2 * h < i))

   ; a freeze lands while a long show runs
   x (1048576 5)
   pid (twirl (_ \ show x) ())
   t0 (clock 0)
   _ (rest 30)
   dt (clock t0)
   up (landed? pid)
   _ (freeze pid)
   _ (test (dt < 500) !up)

   ; the repl: a print ^C'd mid-way, the prompt back, the next line answering
   (sub? h n) (: (go i) (? (#h < i + #n) 0 (n = snip h i (i + #n)) 1 (go (i + 1))) (go 0))
   (upto m pat t) (see m @ b (b < 0 ? t (t + string b @ t2 (sub? t2 pat ? t2 (upto m pat t2)))))
   (waitfor pid) (gather pid @ s (? (two? s) s (nom? s) s (rest 2, waitfor pid)))
   (type m s) (say m s, flush m)
   r (tether [love])
   _ (test (two? r))
   m >r
   _ (upto m "> " "")
   _ (type m "2097152 5\r")
   _ (rest 800)
   t1 (clock 0)
   _ (type m (string 3))
   c1 (upto m "^C" "")
   dc (clock t1)
   _ (upto m "> " "")
   _ (type m "(+ 1 2)\r")
   c2 (upto m "> " "")
   _ (type m (string 4))
   _ (slurp m)
   s1 (waitfor <r)
   (test (sub? c1 "^C") (dc < 1000) (sub? c2 "3") (<s1 = 0)))
(test_fin (), puts "bigprint: ok", putc 10, 0)
