; bench/cnifs.l -- the heavy host nifs ccbench.sh times, one row each: real work on paths a user
; waits on, where ccrypto.l's pair is a lever.
;   inflate   src/love/compress/gz.c: bit reader, table lookup per symbol, byte copy -- the branchiest
;   crc32     src/love/crypto/hash.c: eight independent table lookups per eight bytes, no branches
;   sha256    src/love/crypto/hash.c: a 64-word schedule array plus eight scalars, between the two
;   zstd      src/love/compress/zstd.c: fse and huffman tables, a bit reader in a struct, the
;             sequence loop the register allocator works hardest on
; these run the nifs, never src/apps/gz.l's love twins -- this table times C compilers. the binary
; under test lives in out/bench/cc where the module walk misses lib/, so everything is built from
; the core, and the inflate and zstd inputs are laid beside it by ccgen.l through the host love.
(borrow '(posix hashes gz zstd))
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
   ; the reps' ms by the process's own clock, so neither boot nor the inputs are timed
   (timed k f) (clock 0 @ t0 (rep k f, clock 0 - t0))

   ; fixed reps so all three compilers do identical work, sized so the fastest lane still spends
   ; ~300 ms: the floor on a ccbench ratio is 4%.
   (crc-run _) (puts "cnifs crc32: ok ms \(timed 1000 (_ \ crc32 nifmsg))\n")
   (sha-run _) (puts "cnifs sha256: ok ms \(timed 100 (_ \ sha256 nifmsg))\n")
   ; the stream and its inflated size come from ccbench.sh, which laid them with ccgen.l
   (inf-run p n k)
    (: q (open p "r")
       _ (q ? 0 (say err "cnifs: no stream\n", quit 1))
       d (slurp q + "")
       (close q, puts "cnifs inflate: ok ms \(timed k (_ \ inflate d n))\n"))
   ; a frame of the same source; a wrong decode is dnf, not a fast row
   (zst-run p n k)
    (: q (open p "r")
       _ (q ? 0 (say err "cnifs: no frame\n", quit 1))
       d (slurp q + "")
       (close q, timed k (_ \ zstd-d d) @ ms (#(zstd-d d) = n ? (puts "cnifs zstd: ok ms \(ms)\n") 0))))
