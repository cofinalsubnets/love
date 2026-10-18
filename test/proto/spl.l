; --- test/proto/spl.l: CALL vs SPLICE, modeled: the license an ev.l inliner would need ---
; a stack machine in ev's emitter shape (an emitter prepends onto the continuation's thread)
; and three call-site compilers, one body compiler `cb` handed three param readers:
; ecall -- args into seats; ebind -- splice by binding, args into locals;
; esubst -- splice by substitution, the arg emitter is the reader
; the observation is (value . trace): `emit` appends to the trace and leaves the stack, so
; only the trace convicts a duplicated effect. laws: ecall == ebind every sample; a param
; read twice under an effectful arg doubles the effect under esubst, the values equal (why
; pureset is a license); arg effects precede body effects. not modeled: the boxed return,
; a scare mid-body, recursion. spl2uu lifts these threads to test/uusplgen.l

; --- the machine: ops are (op x); state [stack locals seats trace]; A the caller's env.
; emitters prepend, compose runs left first ---
(: (kop op x) (k \ [op x] . k)
   (kpushk x) (kop 'pushk x)
   (kpusha i) (kop 'pusha i)                        ; caller arg i
   (kpushl i) (kop 'pushl i)
   (kpushs i) (kop 'pushs i)
   (ksetl i) (kop 'setl i)
   (ksets i) (kop 'sets i)
   kadd (kop 'add 0)
   kemit (kop 'emit 0)                              ; append TOS to the trace, keep it
   (kseq a b) (k \ a (b k))                         ; a's ops first

   ; the interpreter: a thread against env A -> (value . trace)
   (put9 al i v) ([i v] . al)
   (get9 al i) (: e (assoc i al) (two? e ? <>e (scare 'spl-unbound i)))
   (in9 th A st lo se tr)
    (? (atom? th) (<st . rev tr)
       (: op (<th 0) x (<th 1)
          (op @ 'pushk (in9 >th A (x . st) lo se tr)
                'pusha (in9 >th A (get9 A x . st) lo se tr)
                'pushl (in9 >th A (get9 lo x . st) lo se tr)
                'pushs (in9 >th A (get9 se x . st) lo se tr)
                'setl  (in9 >th A >st (put9 lo x <st) se tr)
                'sets  (in9 >th A >st lo (put9 se x <st) tr)
                'add   (in9 >th A (<>st + <st . >>st) lo se tr)
                'emit  (in9 >th A st lo se (<st . tr))
                (scare 'spl-op op))))
   (run em A) (in9 (em ()) A () () () ())

   ; --- the body compiler: exprs ('p i) ('a i) ('k n) ('add e e) ('emit e);
   ; prd the param reader: the three strategies are three prd's ---
   (cb e prd)
    (<e @ 'p (prd <>e)
          'a (kpusha <>e)
          'k (kpushk <>e)
          'add (kseq (cb <>e prd) (kseq (cb <>>e prd) kadd))
          'emit (kseq (cb <>e prd) kemit)
          (scare 'spl-expr e))

   ; --- the three call-site compilers, one body against three readers ---
   (args9 as f) (:- (go as 0)
                 (go as i) (atom? as ? (k \ k) (kseq (kseq (cb <as ()) (f i)) (go >as (i + 1)))))
   (ecall as body) (kseq (args9 as ksets) (cb body kpushs))
   (ebind as body) (kseq (args9 as ksetl) (cb body kpushl))
   (esubst as body) (cb body (i \ cb (as i) ()))

   ; --- the samples; a0e is the effectful arg (reads caller arg 0, emits it) ---
   a0e '(emit (a 0))
   e0 ['((a 0)) '(add (p 0) (k 1))]
   e1 [[a0e] '(add (p 0) (k 1))]
   e2 [[a0e] '(add (p 0) (p 0))]                    ; effect, param read TWICE
   e3 [[a0e] '(emit (k 5))]                         ; order: arg effect, then body's
   A9 '((0 7))                                      ; the demo env: arg 0 = 7

   (both f s) (run (f (s 0) (s 1)) A9))

; --- the license: call == bind as (value . trace), every sample ---
(test
 ((both ecall e0) = (both ebind e0)) ('(8) = (both ebind e0))
 ((both ecall e1) = (both ebind e1)) ('(8 7) = (both ebind e1))
 ((both ecall e2) = (both ebind e2)) ('(14 7) = (both ebind e2))
 ((both ecall e3) = (both ebind e3)) ('(5 7 5) = (both ebind e3)))

; --- the flip: substitution duplicates the effect; the VALUE cannot see it ---
(test
 ((both esubst e0) = (both ebind e0))
 ((both esubst e1) = (both ebind e1))
 (both esubst e2 != both ebind e2)
 ('(14 7 7) = (both esubst e2))                    ; value 14 equal, effect doubled
 (<(both esubst e2) = <(both ebind e2)))

(puts "spl: ok") (putc 10)
