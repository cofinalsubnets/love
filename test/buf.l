; buf (Phase 3): a mutable flat byte string. One constructor (buf); pin /
; get / put fold into the generic ops (get/put dispatch on the value's kind);
; blit blits a byte range from a string or buf into a buf. Bytes are data, so
; a stored byte reads back as its unsigned value 0..255. Equality is by
; identity -- a buf is mutable, so two distinct bufs never compare =.

(assert
 ; --- construction + length, and what a buf is NOT ---
 (= 4 (sat (buf 4)))
 (= 0 (sat (buf 0)))
 !(strp (buf 4))                          ; a buf is not a string
 !(fixp (buf 4))                          ; ...nor a number

 ; --- a fresh buf is zeroed ---
 (: b (buf 4) (= 0 (+ (peep b 0 0) (peep b 1 0) (peep b 2 0) (peep b 3 0))))

 ; --- put stores a byte, get reads it back; put returns the buf ---
 (: b (buf 3) _ (pin b 0 65) _ (pin b 1 66) _ (pin b 2 67)
    (&& (= 65 (peep b 0 0)) (= 66 (peep b 1 0)) (= 67 (peep b 2 0))))
 (: b (buf 1) (= b (pin b 0 9)))             ; put returns the buf

 ; --- bytes are unsigned 0..255; a store keeps only the low byte ---
 (: b (buf 1) _ (pin b 0 255) (= 255 (peep b 0 0)))   ; 0xff reads unsigned
 (: b (buf 1) _ (pin b 0 257) (= 1 (peep b 0 0)))     ; 257 & 255 = 1

 ; --- out-of-range / misuse is a silent no-op (no crash) ---
 (: b (buf 2) _ (pin b 5 1) _ (pin b -1 1) (= 0 (+ (peep b 0 0) (peep b 1 0))))
 (= 0 (peep (buf 2) 9 0))                     ; out-of-range get -> default

 ; --- blit from a string source ---
 (: b (buf 4) _ (blit b 0 "ABCD" 0 4)
    (&& (= 65 (peep b 0 0)) (= 68 (peep b 3 0))))
 (: b (buf 4) _ (blit b 1 "ABCD" 2 2)       ; copy "CD" to offset 1
    (&& (= 0 (peep b 0 0)) (= 67 (peep b 1 0)) (= 68 (peep b 2 0))))
 (: b (buf 2) (= b (blit b 0 "XY" 0 2)))    ; blit returns dst

 ; --- blit buf -> buf ---
 (: s (buf 3) d (buf 3)
    _ (pin s 0 7) _ (pin s 1 8) _ (pin s 2 9)
    _ (blit d 0 s 0 3)
    (&& (= 7 (peep d 0 0)) (= 9 (peep d 2 0))))

 ; --- blit clamps an oversized count rather than trampling the heap ---
 (: b (buf 2) _ (blit b 0 "ABCD" 0 100) (= 2 (sat b)))

 ; --- equality is by identity (a buf is mutable) ---
 (: b (buf 2) (= b b))                       ; a buf equals itself
 !(= (buf 2) (buf 2)))                 ; distinct bufs never compare =
