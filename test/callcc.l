; tests for call_cc -- continuation capture and invocation.
; the nif is inlined by the compiler (see ana_ap b1p branch); lvm_callk
; snapshots the inlined caller's stack into a heap thread and tail-
; applies f to that snapshot as k. invoking (k v) reinstates the
; captured stack and resumes as if (call_cc f) had returned v.

(assert
 ; --- f returns directly without invoking k ---
 ; the captured k is discarded; the form resolves to f's return value.
 (= 41 (call-cc (\ k 41)))
 ; --- invoke k explicitly ---
 ; (k v) abandons f's continuation and resumes at the call_cc site
 ; with v as the form's value. the body after (k 41) is never reached.
 (= 41 (call-cc (\ k (k 41))))
 (= 41 (call-cc (\ k (: _ (k 41) 0))))

 ; --- call_cc inside a surrounding expression ---
 ; both the f-returns path and the (k v) path must leave the result
 ; at the slot the surrounding expression reads from.
 (= 42 (+ 1 (call-cc (\ k (k 41)))))
 (= 42 (+ 1 (call-cc (\ k 41))))
 (= 42 (* 2 (+ 1 (call-cc (\ k (k 20))))))

 ; --- odd-arg fallback ---
 ; if f is a number (not callable) the form is a no-op that returns f,
 ; matching lvm_ap's "odd Sp[1]" convention.
 (= 42 (call-cc 42))
 (= 0 (call-cc 0))
 (= -7 (call-cc -7))

 ; --- the continuation is a heap value ---
 ; when f returns k unchanged, the call_cc form resolves to the
 ; snapshot itself, which is a heap-allocated thread (non-nil).
 !(nilp (call-cc (\ k k)))

 ; --- escape from inside a recursive helper ---
 ; loop counts down; at n=5 it bails via (k 100); otherwise it falls
 ; through naturally and returns -1.
 (: (loop n k) (? (= 0 n) -1
                  (= n 5) (k 100)
                  (loop (+ -1 n) k))
    (do (= 100 (call-cc (\ k (loop 10 k))))
       (= -1  (call-cc (\ k (loop  3 k))))))

 ; --- nested call_cc: inner k escapes only the inner form ---
 ; outer kout is captured but never invoked; the inner form yields 10
 ; via (kin 10), then (+ 100 10) yields 110 as the outer's value.
 (= 110 (call-cc (\ kout (+ 100 (call-cc (\ kin (kin 10)))))))
 (= 10  (call-cc (\ kout (+ 100 (call-cc (\ kin (kout 10)))))))
 ; outer kout escapes both levels: inner body invokes kout, so the
 ; (+ 100 ...) is abandoned and the outer form yields 10 directly.
 )
