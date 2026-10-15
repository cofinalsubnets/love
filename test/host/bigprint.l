; test/host/bigprint.l -- a big's digits in products, and a long print stopped
; host-side for its clocks: a ratio on the stress build says nothing
;   cat test/00-init.l test/host/00-host.l test/host/bigprint.l | out/love
(borrow 'posix)
(: love <cmdline
   (best f x) (: (go k b) (k = 0 ? b (: t (clock 0) _ (f x) (go (k - 1) (min b (clock t)))))
                 (go 3 1000000))
   v1 (65536 5)  v2 (262144 5)
   a (best show v1)
   b (best show v2)
   _ (test (b < 12 * a) (b < 1000))

   ; a show aboard a task yields, so a freeze lands at once
   x (1048576 5)
   pid (twirl (_ \ show x) ())
   t0 (clock 0)
   _ (rest 30)
   dt (clock t0)
   up (landed? pid)
   _ (freeze pid)
   _ (test (dt < 500) !up)

   ; the repl: a print ^C'd mid-way, the prompt back, the next line answering
   (upto m pat t) (see m @ b (b < 0 ? t (t + string b @ t2 (has? t2 pat ? t2 (upto m pat t2)))))
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
   s1 (h-waitfor <r)
   (test (has? c1 "^C") (dc < 1000) (has? c2 "3") (<s1 = 0)))
(test_fin (), puts "bigprint: ok", putc 10, 0)
