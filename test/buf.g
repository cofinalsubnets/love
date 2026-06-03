; buf (Phase 3): a mutable flat byte string. One constructor (bufnew); len /
; get / put fold into the generic ops (get/put dispatch on the value's kind);
; bcopy blits a byte range from a string or buf into a buf. Bytes are data, so
; a stored byte reads back as its unsigned value 0..255. Equality is by
; identity -- a buf is mutable, so two distinct bufs never compare =.

(assert
 ; --- construction + length, and what a buf is NOT ---
 (= 4 (len (bufnew 4)))
 (= 0 (len (bufnew 0)))
 (~ (strp (bufnew 4)))                          ; a buf is not a string
 (~ (nump (bufnew 4)))                          ; ...nor a number

 ; --- a fresh buf is zeroed ---
 (: b (bufnew 4) (= 0 (+ (get 0 0 b) (get 0 1 b) (get 0 2 b) (get 0 3 b))))

 ; --- put stores a byte, get reads it back; put returns the buf ---
 (: b (bufnew 3) _ (put 0 65 b) _ (put 1 66 b) _ (put 2 67 b)
    (&& (= 65 (get 0 0 b)) (= 66 (get 0 1 b)) (= 67 (get 0 2 b))))
 (: b (bufnew 1) (= b (put 0 9 b)))             ; put returns the buf

 ; --- bytes are unsigned 0..255; a store keeps only the low byte ---
 (: b (bufnew 1) _ (put 0 255 b) (= 255 (get 0 0 b)))   ; 0xff reads unsigned
 (: b (bufnew 1) _ (put 0 257 b) (= 1 (get 0 0 b)))     ; 257 & 255 = 1

 ; --- out-of-range / misuse is a silent no-op (no crash) ---
 (: b (bufnew 2) _ (put 5 1 b) _ (put -1 1 b) (= 0 (+ (get 0 0 b) (get 0 1 b))))
 (= 0 (get 0 9 (bufnew 2)))                     ; out-of-range get -> default

 ; --- bcopy from a string source ---
 (: b (bufnew 4) _ (bcopy b 0 "ABCD" 0 4)
    (&& (= 65 (get 0 0 b)) (= 68 (get 0 3 b))))
 (: b (bufnew 4) _ (bcopy b 1 "ABCD" 2 2)       ; copy "CD" to offset 1
    (&& (= 0 (get 0 0 b)) (= 67 (get 0 1 b)) (= 68 (get 0 2 b))))
 (: b (bufnew 2) (= b (bcopy b 0 "XY" 0 2)))    ; bcopy returns dst

 ; --- bcopy buf -> buf ---
 (: s (bufnew 3) d (bufnew 3)
    _ (put 0 7 s) _ (put 1 8 s) _ (put 2 9 s)
    _ (bcopy d 0 s 0 3)
    (&& (= 7 (get 0 0 d)) (= 9 (get 0 2 d))))

 ; --- bcopy clamps an oversized count rather than trampling the heap ---
 (: b (bufnew 2) _ (bcopy b 0 "ABCD" 0 100) (= 2 (len b)))

 ; --- equality is by identity (a buf is mutable) ---
 (: b (bufnew 2) (= b b))                       ; a buf equals itself
 (~ (= (bufnew 2) (bufnew 2))))                 ; distinct bufs never compare =
