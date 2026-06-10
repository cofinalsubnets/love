; the lisp trap calling convention. a global `trap` function receives
; (trap s a b): s = the status word -- two bits, sing (1: something went
; wrong) and more (2: read control flow); more alone = incomplete, eof =
; more|sing. a/b = the condition data: for the more bit the port and the
; read sentinel. the result is delivered per the bits: more -> to the
; reader's resume (the fread protocol: the ap chooses what the reader's
; caller sees); a bare sing is observed, then the default escape proceeds
; (oom is the only C sing today and is terminal, so that lane is exercised
; manually, not here). entries are live immediately (datum-at-a-time read
; loop); the ap is UNINSTALLED at the end of this file.
(: trap-log (hashn 0))

; status readers
(assert (sing? 1) !(sing? 3) !(sing? 2)
        (more? 2) !(more? 3) !(more? 1)
        (eof? 3) !(eof? 2) !(eof? 1))

; a counting ap that reproduces the default protocol
(: (trap s p e) (: _ (pin trap-log s (+ 1 (peek trap-log s 0)))
                   (? (more? s) p (eof? s) e 0)))
(assert (= 'eof (fread (sip 0) 'eof)))             ; eof through the lisp trap
(: q (sip '(40)) (assert (= q (fread q 99))))      ; more through the lisp trap
(assert (= 1 (peek trap-log 3 0)) (= 1 (peek trap-log 2 0)))

; the trap function owns the protocol: deliver a constant instead
(: (trap s p e) 'gotcha)
(assert (= 'gotcha (fread (sip 0) 'x)) (= 'gotcha (fread (sip '(40)) 'x)))

; uninstall; the raw default is back
(pull dict 'trap 0)
(assert !(peek dict 'trap 0) (= 'eof (fread (sip 0) 'eof))
        (: p (sip '(40)) (= p (fread p 99))))
