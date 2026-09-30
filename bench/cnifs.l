; bench/cnifs.l -- the heavy host nifs ccbench.sh times, one row each: real work on paths a user
; waits on, where ccrypto.l's pair is a lever.
;   inflate   src/love/lib/gz.c: bit reader, table lookup per symbol, byte copy -- the branchiest
;   crc32     src/love/lib/hash.c: eight independent table lookups per eight bytes, no branches
;   sha256    src/love/lib/hash.c: a 64-word schedule array plus eight scalars, between the two
; these run the nifs, never src/apps/gz.l's love twins -- this table times C compilers. the binary
; under test lives in out/bench/cc where the module walk misses lib/, so everything is built from
; the core, and the inflate stream is laid beside it by ccgen.l through the host love.
(borrow 'posix)
(:
   ; varied bytes: crc32 indexes its tables with the data, so an all-NUL message would read one
   ; entry of each. built small and doubled, since a love loop over the whole megabyte costs more
   ; than the row it feeds.
   nifseed (: b (cask 4096)
              (go i) (4096 <= i ? (string b) (pin b i (i * 7 & 255), go (i + 1)))
              (go 0))
   (nifdbl s k) (k < 1 ? s (nifdbl (s + s) (k - 1)))
   nifmsg (nifdbl nifseed 8)                 ; 4 KiB -> 1 MiB

   ; (f) at zero operands is f itself, unrun. the unit is the operand, and it is ().
   (rep k f) (k < 1 ? 0 (f (), rep (k - 1) f))

   ; fixed reps so all three compilers do identical work, sized so the fastest lane still spends
   ; ~300 ms: the floor on a ccbench ratio is 4%.
   (crc-run _) (rep 1000 (_ \ crc32 nifmsg), puts "cnifs crc32: ok\n")
   (sha-run _) (rep 100 (_ \ sha256 nifmsg), puts "cnifs sha256: ok\n")
   ; the stream and its inflated size come from ccbench.sh, which laid them with ccgen.l
   (inf-run p n k)
    (: q (open p "r")
       _ (q ? 0 (say err "cnifs: no stream\n", quit 1))
       d (slurp q + "")
       (close q, rep k (_ \ inflate d n), puts "cnifs inflate: ok\n")))
