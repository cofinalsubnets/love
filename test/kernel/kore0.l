; the kore cat rides the corpus next (test/kernel/all.l's roster: crew/kore/{text,core,fs}.l,
; then test/kernel/kore.l drives the mains) -- but `quit`, the host's exit door,
; is absent on this seat, and 00-init.l's fallback for an absent nif answers ().
; a main folds its `quit` at compile, so the identity must be pinned before the
; cat loads: every tool then answers its exit code, which is what the smoke reads.
(: (quit n) n)
