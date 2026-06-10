; buf (Phase 3): a mutable flat byte string. One constructor (bufnew); pin /
; get / put fold into the generic ops (get/put dispatch on the value's kind);
; bcopy blits a byte range from a string or buf into a buf. Bytes are data, so
; a stored byte reads back as its unsigned value 0..255. Equality is by
; identity -- a buf is mutable, so two distinct bufs never compare =.

(assert
 ; --- construction + length, and what a buf is NOT ---
 (= 4 (hash (bufnew 4)))
 (= 0 (hash (bufnew 0)))
 !(strp (bufnew 4))                          ; a buf is not a string
 !(fixp (bufnew 4))                          ; ...nor a number

 ; --- a fresh buf is zeroed ---
 (: b (bufnew 4) (= 0 (+ (peek b 0 0) (peek b 1 0) (peek b 2 0) (peek b 3 0))))

 ; --- put stores a byte, get reads it back; put returns the buf ---
 (: b (bufnew 3) _ (pin b 0 65) _ (pin b 1 66) _ (pin b 2 67)
    (&& (= 65 (peek b 0 0)) (= 66 (peek b 1 0)) (= 67 (peek b 2 0))))
 (: b (bufnew 1) (= b (pin b 0 9)))             ; put returns the buf

 ; --- bytes are unsigned 0..255; a store keeps only the low byte ---
 (: b (bufnew 1) _ (pin b 0 255) (= 255 (peek b 0 0)))   ; 0xff reads unsigned
 (: b (bufnew 1) _ (pin b 0 257) (= 1 (peek b 0 0)))     ; 257 & 255 = 1

 ; --- out-of-range / misuse is a silent no-op (no crash) ---
 (: b (bufnew 2) _ (pin b 5 1) _ (pin b -1 1) (= 0 (+ (peek b 0 0) (peek b 1 0))))
 (= 0 (peek (bufnew 2) 9 0))                     ; out-of-range get -> default

 ; --- bcopy from a string source ---
 (: b (bufnew 4) _ (bcopy b 0 "ABCD" 0 4)
    (&& (= 65 (peek b 0 0)) (= 68 (peek b 3 0))))
 (: b (bufnew 4) _ (bcopy b 1 "ABCD" 2 2)       ; copy "CD" to offset 1
    (&& (= 0 (peek b 0 0)) (= 67 (peek b 1 0)) (= 68 (peek b 2 0))))
 (: b (bufnew 2) (= b (bcopy b 0 "XY" 0 2)))    ; bcopy returns dst

 ; --- bcopy buf -> buf ---
 (: s (bufnew 3) d (bufnew 3)
    _ (pin s 0 7) _ (pin s 1 8) _ (pin s 2 9)
    _ (bcopy d 0 s 0 3)
    (&& (= 7 (peek d 0 0)) (= 9 (peek d 2 0))))

 ; --- bcopy clamps an oversized count rather than trampling the heap ---
 (: b (bufnew 2) _ (bcopy b 0 "ABCD" 0 100) (= 2 (hash b)))

 ; --- equality is by identity (a buf is mutable) ---
 (: b (bufnew 2) (= b b))                       ; a buf equals itself
 !(= (bufnew 2) (bufnew 2)))                 ; distinct bufs never compare =
