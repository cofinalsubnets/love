; a64 call-out execution, run only under qemu-aarch64 (test_raw_a64): a64 bytes fault on x86,
; so it lives outside the test/*.l glob. proves emit.l's call-out bridge: `lar` -> ADR (adrp
; would mis-page in the mmap blob), and the + / * fold overflow gates (fixnum boundary 2^62).

; --- direct emit: build the a64 nif by hand and run it ---
(: G (cite 'glaze)  jitcalloutx (G 'jitcalloutx)
   (ca-sq i)   (i * i)
   (ca-half i) (i * 0.5)
   (ca-inc i)  (i + 1)
   (ca-ph i)   (i + 0.5)                             ; a non-trivial float product
   (ca-thr i)  (i @ 0 3 2)                           ; product 3*2^(n-1)
   (ca-md7 x)  (x % 7)                               ; an overflow deopts only on the arg
   ca-src   '(\ n ((: (go i a) (? (< i n) (go (+ i 1) (+ a (ca-sq i)))   a)) 0 0))
   caf-src  '(\ n ((: (go i a) (? (< i n) (go (+ i 1) (+ a (ca-half i))) a)) 0 0))
   nat  (jitcalloutx ca-sq   ca-src  '+ 'i 'i 'a64)   ; + fold, bare arg
   natf (jitcalloutx ca-half caf-src '+ 'i 'i 'a64)
   natp (jitcalloutx ca-inc  '(\ n 0) '* 'i 'i 'a64)  ; n!
   natpf (jitcalloutx ca-ph  '(\ n 0) '* 'i 'i 'a64)  ; float callee -> gate 1
   natp3 (jitcalloutx ca-thr  '(\ n 0) '* 'i 'i 'a64) ; product lands in [2^62,2^63)
   natc  (jitcalloutx ca-sq  '(\ n 0) '+ 'i '(+ i 1) 'a64)                       ; sum sq(i+1)
   natco (jitcalloutx ca-sq  '(\ n 0) '+ 'i '(* i i) 'a64)                       ; sum i^4, overflows -> bignum twin
   natcd (jitcalloutx ca-md7 '(\ n 0) '+ 'i '(* (* i i) 1000000000) 'a64)        ; arg overflows ~i=68k -> caargdeopt -> twin
   r3m ((: (go i a) (i < 3000000 ? (go (i + 1) (a + ca-sq i)) a)) 0 0)       ; interp reference: never glazed
   _ (test
       (0 = (nat 0))                                 ; empty
       (285 = (nat 10))                              ; fixnum fast path
       (2666664666667000000 = (nat 2000000))         ; ~2.6e15 fixnum
       (8999995500000500000 = (nat 3000000))         ; [2^62,2^63): tag overflow -> bignum
       ((nat 3000000) = r3m)
       (333333283333335000000 = (nat 10000000))      ; ~3.3e20, well past 2^63
       (95.0 = (natf 20))                             ; gate 1: float result -> deopt to interp twin
       ; * fold: sa kept raw (mulo), retagged behind an overflow gate
       (1 = (natp 0))                                 ; empty product
       (120 = (natp 5))
       (51090942171709440000 = (natp 21))            ; gate 2: product overflow -> bignum
       (1.875 = (natpf 3))                            ; gate 1: float product -> deopt
       (6917529027641081856 = (natp3 62))            ; the end-retag gate must deopt
       ; computed args: an arg leaving fixnum range deopts (caargdeopt)
       (55 = (natc 5)) (0 = (natc 0)) (91 = (natc 6))
       (979 = (natco 6)) (1950333330 = (natco 100))      ; fixnum then overflow -> bignum twin
       (280000 = (natcd 70000)) (399999 = (natcd 100000))))   ; arg overflow -> caargdeopt

; --- auto-glaze: the natjit hook glazes at closure creation. a global sum takes the
; jitcalloutx path; a returned captured closure takes njit-calloutframe (frame-read F) ---
(: (ag-sq i)  (i * i)
   (ag-half i) (i * 0.5)
   (ag-inc i)  (i + 1)
   (ag-ph i)   (i + 0.5)
   (ag-sum n)  ((: (go i a) (i < n ? (go (i + 1) (a + ag-sq i)) a)) 0 0)              ; hook -> jitcalloutx
   (ag-prod n) ((: (go i a) (i < n ? (go (i + 1) (a * ag-inc i)) a)) 0 1)             ; hook -> jitcalloutx
   (ag-summer f) (n \ (: (go i a) (i < n ? (go (i + 1) (a + f i)) a)) 0 0)            ; hook -> njit-calloutframe
   (ag-multiplier f) (n \ (: (go i a) (i < n ? (go (i + 1) (a * f i)) a)) 0 1)        ; hook -> njit-calloutframe
   (ag-cgsum n) ((: (go i a) (i < n ? (go (i + 1) (a + ag-sq (i * i))) a)) 0 0)       ; sum i^4, hook -> jitcalloutx
   (ag-capcg f) (n \ (: (go i a) (i < n ? (go (i + 1) (a + f (i + 1))) a)) 0 0)       ; sum f(i+1), hook -> njit-calloutframe
   cs (ag-summer ag-sq)  cf (ag-summer ag-half)  cp (ag-multiplier ag-inc)  cpf (ag-multiplier ag-ph)  ccg (ag-capcg ag-sq)
   ag30 (ag-sum 30)
   ((test
      (285 = (ag-sum 10)) (0 = (ag-sum 0))
      (8555 = (ag-sum 30))
      (8999995500000500000 = (ag-sum 3000000))                                       ; gate-2 boundary -> bignum
      (285 = (cs 10)) (0 = (cs 0)) (8555 = (cs 30))
      ((cs 30) = ag30)                                                               ; captured == global
      (8999995500000500000 = (cs 3000000))                                           ; gate-2 boundary
      (95.0 = (cf 20))                                                               ; gate-1 float
      (1 = (ag-prod 0)) (120 = (ag-prod 5)) (51090942171709440000 = (ag-prod 21))
      (1 = (cp 0)) (120 = (cp 5)) (51090942171709440000 = (cp 21))
      ((cp 5) = (ag-prod 5))
      (1.875 = (cpf 3))
      (979 = (ag-cgsum 6)) (1950333330 = (ag-cgsum 100))
      (55 = (ccg 5)) (0 = (ccg 0)) (91 = (ccg 6))),
    say err "test/a64/callout: a64 call-out execution (direct + auto-glaze, lar/ADR + fold gates + computed args) ok\n"))
