; call-cc: (k v) reinstates the captured stack, as if (call-cc f) had returned v

(test
 ; --- f returns directly without invoking k ---
 (41 = call-cc (k \ 41))
 ; --- invoke k: the body after (k 41) is never reached ---
 (41 = call-cc (k \ k 41))
 (41 = call-cc (k \ (k 41, 0)))

 ; --- inside a surrounding expression, by either path ---
 (42 = (1 + call-cc (k \ k 41)))
 (42 = (1 + call-cc (k \ 41)))
 (42 = (2 * (1 + call-cc (k \ k 20))))

 ; --- a number for f answers f ---
 (42 = call-cc 42)
 (0 = call-cc 0)
 (-7 = call-cc -7)

 ; --- the continuation is a heap value (non-nil) ---
 !!(call-cc (k \ k))

 ; --- escape from a recursive helper: bails at n=5, else -1 ---
 (: (loop n k) (? (0 = n) -1
                  (n = 5) (k 100)
                  (loop (-1 + n) k))
    (&& (100 = call-cc (k \ loop 10 k))        ; `do` answers its LAST operand, so a
        (-1 = call-cc (k \ loop 3 k))))        ; do here would leave the first unchecked

 ; --- nested: kin escapes only the inner form, kout both ---
 (110 = call-cc (kout \ 100 + call-cc (kin \ kin 10)))
 (10 = call-cc (kout \ 100 + call-cc (kin \ kout 10)))
 )
