; bench/ccrypto.l -- the cipher workloads ccbench.sh times, one per row. a lever gauge, not a
; cipher benchmark: one C function each, where the corpus row averages.
;   chacha    a 16-word state array, filled by a memcpy, that mooncc splits into scalars; then a
;             byte-at-a-time xor
;   poly1305  five limbs as scalar locals
; chacha far wider than poly again says the array is back in memory. these run the nifs
; (src/love/crypto/tls.c), never src/apps/tls's love ciphers; that meeting is src/apps/tls/bench.l.
; the binary under test lives in out/bench/cc where the module
; walk misses lib/, so everything is built from the core. ccbench.sh cats this file and one driver
; call; the reps are fixed, and each row prints a sentinel so a lane that answered nothing cannot
; be timed as fast.
(borrow 'tls)
(:
   ccbytes 65536                             ; 64 KiB per call, 1024 chacha blocks
   msg (string (cask ccbytes))               ; content is irrelevant: both ciphers
   non (string (cask 12))                    ; are constant-time by construction

   ; a key that is not all zeros -- poly1305 with r = 0 costs the same, but reads like an accident
   cckey (: b (cask 32)
            (go i) (32 <= i ? (string b) (pin b i (i * 7 & 255), go (i + 1)))
            (go 0))

   ; (f) at zero operands is f itself, unrun. the unit is the operand, and it is ().
   (rep k f) (k < 1 ? 0 (f (), rep (k - 1) f))
   ; the reps' ms by the process's own clock, so neither boot nor the setup is timed
   (timed k f) (clock 0 @ t0 (rep k f, clock 0 - t0))

   (cc-run _) (puts "ccrypto chacha: ok ms \(timed 2000 (_ \ chacha20 cckey non 1 msg))\n")
   (po-run _) (puts "ccrypto poly1305: ok ms \(timed 20000 (_ \ poly1305 cckey msg))\n"))
