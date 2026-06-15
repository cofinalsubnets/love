; the lisp help calling convention. a global `help` function receives
; (help s a b): s = the status word -- two bits, scare (1: something went
; wrong) and more (2: read control flow); more alone = incomplete, eof =
; more|scare. a/b = the condition data: for the more bit the port and the
; read sentinel. the result is delivered per the bits: more -> to the
; reader's resume (the read protocol: the ap chooses what the reader's
; caller sees); a bare scare is observed, then the default escape proceeds
; (oom is the only C scare today and is terminal, so that lane is exercised
; manually, not here). entries are live immediately (datum-at-a-time read
; loop); the ap is UNINSTALLED at the end of this file.
(: help-log (tablet 0))

; status readers
(assert (scare? 1) !(scare? 3) !(scare? 2)
        (more? 2) !(more? 3) !(more? 1)
        (eof? 3) !(eof? 2) !(eof? 1))

; a counting ap that reproduces the default protocol
(: (help s p e) (: _ (pin help-log s (+ 1 (peep help-log s 0)))
                   (? (more? s) p (eof? s) e 0)))
(assert (= 'eof (read (sip 0) 'eof)))             ; eof through the lisp help
(: q (sip '(40)) (assert (= q (read q 99))))      ; more through the lisp help
(assert (= 1 (peep help-log 3 0)) (= 1 (peep help-log 2 0)))

; (scare a b) is the deliberate raise: the scare bit set unconditionally, the
; ap hears (help 1 a b). unlike a C scare (oom, terminal), the raise point is
; a clean boundary, so the ap's result comes back as (scare a b)'s value.
(assert (= 0 (scare 'deliberate 'data)))            ; the counting ap returns 0 on a scare
(assert (= 1 (peep help-log 1 0)))                  ; ... and the observation logged, exactly once

; the help function owns the protocol: deliver a constant instead
(: (help s p e) 'gotcha)
(assert (= 'gotcha (read (sip 0) 'x)) (= 'gotcha (read (sip '(40)) 'x))
        (= 'gotcha (scare 'any 'thing)))            ; the deliberate scare resumes the same way

; uninstall; the raw default is back
(: help 0)                       ; uninstall: a non-lamp value defers to the raw default
(assert !help (= 'eof (read (sip 0) 'eof))
        (: p (sip '(40)) (= p (read p 99))))

; help is present by its net, like everything: "" is a lamp netting nothing,
; so it is no help -- the missing read stays 0 and the read protocol stays
; raw. the koan's help (\ s a b 1) is =-equal to 0 yet a top netting 1:
; installed, and every scare answers 1.
(: help "")
(assert !help (idp (:) one-nothing-unpinned) (= 'eof (read (sip 0) 'eof)))
(: help (\ s a b 1))
(assert (1 = (scare 'k 'v)) (1 = one-nothing-unpinned-2))
(: help 0)

; welp -- the floor handler (repl.l), the fromempty the introductions never
; named: it keeps the read protocol (more -> the port, eof -> the sentinel)
; and welps a bare scare to the zero point. it is a plain function, not the
; installed help -- a policy that runs out of cases delegates to it, and
; shell-help is welp WITH A FACE (it prints `# a b` first, then welps).
(assert (= 'port (welp 2 'port 'sent))         ; more -> the port back
        (= 'sent (welp 3 'port 'sent))         ; eof  -> the sentinel
        (idp (:) (welp 1 'x 'y))               ; a bare scare -> the zero point
        !(welp 1 'x 'y))                       ; ... which nets nothing (false)
