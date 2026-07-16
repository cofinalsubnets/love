; arm64 CALL-OUT EXECUTION -- run ONLY under qemu-aarch64 (tools/arm64check.sh), NEVER in the x86
; corpus: it builds nifs with `jitcalloutx ... 'arm64`, whose code is aarch64 bytes -- calling one on
; x86 jumps into arm64 machine code (a fault). It lives in test/arm64/ (a subfolder), so the
; non-recursive test/*.l corpus glob (make test / ai0 bake) never sees it. arm64check cats it in.
;
; Proves the stackless call-out bridge (emit.l calloutir) EXECUTES correctly on aarch64: the near
; pc-relative resume address (`lar` -> ADR, translation-invariant in the word-aligned mmap blob,
; where la's page-relative ADRP would mis-page) and the tagged-accumulator overflow gate (the fixnum
; TAG boundary at 2^62, not the 64-bit 2^63). == the interpreter across fast path, empty, the
; [2^62,2^63) window, past 2^63, and the float (gate 1) deopt.
(: G glaze  jitcalloutx (G 'jitcalloutx)
   (ca-sq i)   (* i i)
   (ca-half i) (* i 0.5)
   ca-src   '(\ n ((: (go i a) (? (< i n) (go (+ i 1) (+ a (ca-sq i)))   a)) 0 0))
   caf-src  '(\ n ((: (go i a) (? (< i n) (go (+ i 1) (+ a (ca-half i))) a)) 0 0))
   nat  (jitcalloutx ca-sq   ca-src  'arm64)      ; native aarch64 call-out
   natf (jitcalloutx ca-half caf-src 'arm64)
   (ref n)  ((: (go i a) (? (< i n) (go (+ i 1) (+ a (ca-sq i)))   a)) 0 0)   ; interp twins (inline sums; not closures -> never glazed)
   (reff n) ((: (go i a) (? (< i n) (go (+ i 1) (+ a (ca-half i))) a)) 0 0)
   _ (assert
       (0   = (nat 0))                               ; empty
       (285 = (nat 10))  ((nat 10) = (ref 10))        ; fixnum fast path == interp
       (2666664666667000000 = (nat 2000000))         ; ~2.6e15 fixnum
       (8999995500000500000 = (nat 3000000))         ; [2^62,2^63): tag-overflow -> bignum (would be garbage on the untagged gate)
       ((nat 3000000) = (ref 3000000))               ; ... == interp
       ((nat 10000000) = (ref 10000000))             ; ~3.3e20, well past 2^63
       (95.0 = (natf 20)) ((natf 20) = (reff 20)))    ; GATE 1: float call-out result -> deopt to interp twin, gem == interp
   (say err "test/arm64/callout: aarch64 call-out execution (lar/ADR resume + tagged-accumulator gate) ok\n"))
