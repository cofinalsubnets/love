; test/gate/wasmguard.l -- the drop's guard, fired: WGDIR holds x.o and y.o, wasmdrop.sh's objects.
; a marker wrong in each way it can be -- no closure, a root lost, an edge lost -- drops a
; function the kept code or data still names, and the link refuses by name, where it would lay
; a null for a weak name and an import for a strong one the caller lists. each line is a law
(borrow '(holo posix cli))
(: d (getenv "WGDIR")
   txt (<>(uread (d + "/x.o")))
   strong (<>(uread (d + "/y.o")))
   (link-of t o) (trap (_ \ wasm-link [t] o) 0 (a \ b \ [a b]))
   link (link-of txt)
   (opts m imps) (pins {'imports imps 'exports '("_start")} 'marker m)
   (sans n l) (filter (x \ x != n) l)
   (flat u r) (reach (map (x \ [<x]) u) r)
   (rootless u r) (reach u (sans 'wd r))
   (edgeless u r) (reach (map (x \ (<x . sans 'wk >x)) u) r)
   (callless u r) (reach (map (x \ (<x . sans 'st >x)) u) r)
   m0 (link (opts reach ()))
   q (open (d + "/x.wasm") "w")
   _ (say q (wasm-emit m0), close q)
   (puts "sound \(tablet? m0)\n",
    puts "flat \(show (link (opts flat ())))\n",
    puts "root \(show (link (opts rootless ())))\n",
    puts "edge \(show (link (opts edgeless ())))\n",
    puts "import \(show (link-of strong (opts callless '("st"))))\n",
    puts "wins \(show ((link (opts reach '("wk"))) 'imports))\n",
    0))
