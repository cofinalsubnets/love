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
(: trap-log (table 0))

; status readers
(assert (sing? 1) !(sing? 3) !(sing? 2)
        (more? 2) !(more? 3) !(more? 1)
        (eof? 3) !(eof? 2) !(eof? 1))

; a counting ap that reproduces the default protocol
(: (trap s p e) (: _ (pin trap-log s (+ 1 (peep trap-log s 0)))
                   (? (more? s) p (eof? s) e 0)))
(assert (= 'eof (fread (sip 0) 'eof)))             ; eof through the lisp trap
(: q (sip '(40)) (assert (= q (fread q 99))))      ; more through the lisp trap
(assert (= 1 (peep trap-log 3 0)) (= 1 (peep trap-log 2 0)))

; (sing a b) is the deliberate throw: the sing bit set unconditionally, the
; ap hears (trap 1 a b). unlike a C sing (oom, terminal), the raise point is
; a clean boundary, so the ap's result comes back as (sing a b)'s value.
(assert (= 0 (sing 'deliberate 'data)))            ; the counting ap returns 0 on a sing
(assert (= 1 (peep trap-log 1 0)))                 ; ... and the observation logged

; the trap function owns the protocol: deliver a constant instead
(: (trap s p e) 'gotcha)
(assert (= 'gotcha (fread (sip 0) 'x)) (= 'gotcha (fread (sip '(40)) 'x))
        (= 'gotcha (sing 'any 'thing)))            ; the deliberate sing resumes the same way

; uninstall; the raw default is back
(pull dict 'trap 0)
(assert !(peep dict 'trap 0) (= 'eof (fread (sip 0) 'eof))
        (: p (sip '(40)) (= p (fread p 99))))
