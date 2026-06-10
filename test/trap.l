; the lisp trap calling convention. a global `trap` function receives
; (trap s a b): s = the status word -- two bits, scare (1: something went
; wrong) and more (2: read control flow); more alone = incomplete, eof =
; more|scare. a/b = the condition data: for the more bit the port and the
; read sentinel. the result is delivered per the bits: more -> to the
; reader's resume (the fread protocol: the handler chooses what the reader's
; caller sees); a bare scare is observed, then the default escape proceeds
; (oom is the only C scare today and is terminal, so that lane is exercised
; manually, not here). entries are live immediately (datum-at-a-time read
; loop); the handler is UNINSTALLED at the end of this file.
(: trap-log (mapn 0))

; status readers
(assert (scare? 1) !(scare? 3) !(scare? 2)
        (more? 2) !(more? 3) !(more? 1)
        (eof? 3) !(eof? 2) !(eof? 1))

; a counting handler that reproduces the default protocol
(: (trap s p e) (: _ (pin trap-log s (+ 1 (peek trap-log s 0)))
                   (? (more? s) p (eof? s) e 0)))
(assert (= 'eof (fread (strin 0) 'eof)))             ; eof through the lisp trap
(: q (strin '(40)) (assert (= q (fread q 99))))      ; more through the lisp trap
(assert (= 1 (peek trap-log 3 0)) (= 1 (peek trap-log 2 0)))

; the handler owns the protocol: deliver a constant instead
(: (trap s p e) 'gotcha)
(assert (= 'gotcha (fread (strin 0) 'x)) (= 'gotcha (fread (strin '(40)) 'x)))

; uninstall; the raw default is back
(pull dict 'trap 0)
(assert !(peek dict 'trap 0) (= 'eof (fread (strin 0) 'eof))
        (: p (strin '(40)) (= p (fread p 99))))
