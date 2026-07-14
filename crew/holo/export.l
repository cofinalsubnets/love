; crew/holo/export.l -- the assembler's MODULE BOUNDARY. crew/holo/{holo,x64,arm64}.l leak their names
; onto the global book to share them across files (the same channel the prel uses); this
; trailer sweeps that whole span into ONE book pinned under `holo`, then pulls the names
; back off the global book. `holo` is a lookup-only CLOSURE over a private tablet, so the
; surface is (holo 'assemble), (holo 'asmt), (holo 'holo-hex) .. and every internal stays a
; probe away ((holo 'arm64-alu)); (holo 'keys) lists them. the tablet is closure-private, so a
; stray (pin holo ..) has no tablet to reach -- namespacing AND poison-proof. the span is
; MEASURED, never listed: crew/holo/holo.l opens with
; holo-mark = (names ()) and crew/holo/arm64.l closes with holo-load = (names ()); the diff is the
; module, however it drifts -- no keep-up-to-date list. on the host this evals AFTER the
; glaze (host/main.c), whose direct references to assemble/asmt/asmx folded at its own
; compile -- the capture law does the linking; ai0 has no glaze and evals it right after
; arm64.l, before the corpus runs. one body-having : -- nothing leaks but `holo` itself.
(: seen (: t (tablet 0) _ (each holo-mark (\ k (pin t k 1))) t)
   m (tablet 0)
   _ (each holo-load
        (\ k (? (peep seen k 0) 0
                (: _ (pin m k (peep book k 0)) _ (pull book k 0) 0))))
   _ (pull book 'holo-mark 0)                     ; the mark itself is post-mark: swept above,
   _ (pull m 'holo-mark 0)                        ;   cleaned out of the module here
   _ (pull book 'holo-load 0)                     ; the snap is post-snap: never swept, pulled here
   _ (pin book 'holo (\ k (? (id? k 'keys) (keys m) (peep m k 0))))  ; lookup-only closure: m stays
   0)                                                                ;   private, so (pin holo ..) has no tablet to poison; (holo 'keys) introspects
