; test/host/bigprint.l -- a big's digits in products, and a long print stopped
; host-side for its clocks: a ratio on the stress build says nothing. the clocks are this
; process's cpu, which a loaded box does not stretch
;   cat test/00-init.l test/host/00-host.l test/host/bigprint.l | out/love
(borrow 'posix)
(: love <cmdline
   (cpu _) (rusage 0 @ [u s] ((u + s) // 1000))                     ; ms
   (best f x) (: (go k b) (k = 0 ? b (: t (cpu 0) _ (f x) (go (k - 1) (min b (cpu 0 - t)))))
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
   t0 (cpu 0)
   _ (rest 30)
   dt (cpu 0 - t0)
   up (landed? pid)
   _ (freeze pid)
   _ (test (dt < 500) !up)

   ; the repl: a print ^C'd once its digits flow, the prompt back well short of its
   ; 1465808 digits, the next line answering
   (upto m pat t) (see m @ b (b < 0 ? t (t + string b @ t2 (has? t2 pat ? t2 (upto m pat t2)))))
   (type m s) (say m s, flush m)
   r (tether [love])
   _ (test (two? r))
   m >r
   _ (upto m "> " "")
   _ (type m "2097152 5\r")
   _ (upto m "\n" "")                                              ; the line's echo
   _ (see m)                                                       ; its first digit
   _ (type m (string 3))
   c1 (upto m "^C" "")
   _ (upto m "> " "")
   _ (type m "(+ 1 2)\r")
   c2 (upto m "> " "")
   _ (type m (string 4))
   _ (slurp m)
   s1 (h-waitfor <r)
   (test (has? c1 "^C") (#c1 < 1000000) (has? c2 "3") (<s1 = 0)))
(test_fin (), puts "bigprint: ok", putc 10, 0)
