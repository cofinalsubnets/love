; test/gate/psnap.l -- the parser's prefix memo, from inside one process: PSDIR holds the
; sources psnap.sh wrote. each line it prints is a law's answer, read by the script
(borrow 'posix)
(: d (getenv "PSDIR")
   (cc f) (<>((cite 'moon 'rtmem1) 'x64 'linux () ["m.o" "\(d)/\(f)" ()]))
   (kept _) #(peep (cite 'moon 'psmemo) 'l ())
   (lay f txt) (open "\(d)/\(f)" "w" @ q (say q txt, close q))
   a1 (cc "a.c") n1 (kept 0)
   b1 (cc "b.c") n2 (kept 0)
   a2 (cc "a.c") b2 (cc "b.c") n3 (kept 0)
   w1 (cc "w.c") n4 (kept 0)
   _ (lay "h.h" (getenv "PSH2"))
   a3 (cc "a.c") n5 (kept 0)
   (puts "kept \(n1) \(n2) \(n3) \(n4) \(n5)\n",
    puts "again \(a1 = a2 && b1 = b2)\n",
    puts "moved \(a1 = a3)\n",
    (cite 'holo 'write-bytes) "\(d)/a3.o" [a3],
    (cite 'holo 'write-bytes) "\(d)/a1.o" [a1],
    (cite 'holo 'write-bytes) "\(d)/b1.o" [b1],
    (cite 'holo 'write-bytes) "\(d)/w1.o" [w1],
    0))
