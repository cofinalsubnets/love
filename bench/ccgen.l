; bench/ccgen.l -- lays the inflate row's input for ccbench.sh.
;
;   love ccgen.l SRC OUT    writes SRC deflated into OUT, prints SRC's byte count
;
; runs through the built out/love, never a lane binary: the binaries under test in out/bench/cc
; have no module path to src/apps/gz.l, so the stream and its inflated size arrive as a file.
(borrow 'posix)
(: _ (borrow 'gz)
   av >argv
   _ (2 <= #av ? 0 (say err "ccgen: usage: ccgen.l SRC OUT\n", quit 1))
   q (open <av "r")
   _ (q ? 0 (say err ("ccgen: cannot read " + <av + "\n"), quit 1))
   s (slurp q + "")
   _ (close q)
   w (open <>av "w")
   _ (w ? 0 (say err ("ccgen: cannot write " + <>av + "\n"), quit 1))
   (say w (gz-deflate s), close w, puts (show #s), 0))
