; asm/export.l -- the assembler's MODULE BOUNDARY. asm/{asm,x64,arm64}.l leak their names
; onto the global book to share them across files (the same channel the prel uses); this
; trailer sweeps that whole span into ONE book pinned under `asm`, then pulls the names
; back off the global book. NAMESPACING, not hiding: a book is a lookup function, so the
; surface is (asm 'assemble), (asm 'asmt), (asm 'asm-hex) .. and every internal stays a
; probe away ((asm 'arm64-alu)). the span is MEASURED, never listed: asm/asm.l opens with
; asm-mark = (names ()) and asm/arm64.l closes with asm-load = (names ()); the diff is the
; module, however it drifts -- no keep-up-to-date list. on the host this evals AFTER the
; glaze (host/main.c), whose direct references to assemble/asmt/asmx folded at its own
; compile -- the capture law does the linking; ai0 has no glaze and evals it right after
; arm64.l, before the corpus runs. one body-having : -- nothing leaks but `asm` itself.
(: seen (: t (tablet 0) _ (each asm-mark (\ k (pin t k 1))) t)
   m (tablet 0)
   _ (each asm-load
        (\ k (? (peep seen k 0) 0
                (: _ (pin m k (peep book k 0)) _ (pull book k 0) 0))))
   _ (pull book 'asm-mark 0)                     ; the mark itself is post-mark: swept above,
   _ (pull m 'asm-mark 0)                        ;   cleaned out of the module here
   _ (pull book 'asm-load 0)                     ; the snap is post-snap: never swept, pulled here
   _ (pin book 'asm m)
   0)
