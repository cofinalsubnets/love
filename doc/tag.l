; --- pointer-tagging, modeled in ai (a runnable sketch; the real thing is C) ---
; an EXAMPLE of the "ap is cap" representation: encode a heap object's KIND in
; the low bits of every reference to it, so the object carries NO ap/header word
; -- word0 IS cap. dispatch becomes a mask on the reference, never a memory read.
; here a machine "word" is a fixnum, ai's bit ops ARE the word, and a bump-
; allocated `heap` map stands in for raw memory.
;
; --- the recommended 16-byte / 2-bit-kind layout (the one that pays on 64-bit) ---
;   bit 0      1 = fixnum (value in bits 63:1), 0 = a heap reference
;   bit 1      (ref only) the thread-GC mark: 1 = a threaded link
;   bits 3:2   (ref only) the kind: 0 chain . 1 cplx . 2 rsvd . 3 other
;   bits 63:4  (ref only) the 16-byte-aligned address
;
; --- 32-bit / wasm note ---
; the free low bits come from ALIGNMENT, not word width: a 16-aligned address has
; the same 4 low bits whether the pointer is 32 or 64 bits. so this tag PORTS to
; 32-bit unchanged. what breaks is ZERO-WASTE: a 2-word object is 16 B on 64-bit
; (fills the 16-byte slot exactly) but 8 B on 32-bit (rounds up to 16 -> 100% pad).
; SEAMLESS fix: cut the in-band GC tag to ONE bit (just fixnum) by moving
; forward/thread detection out of band (a to-space range test or a side bitmap),
; then put the kind in bits 2:1 at 8-BYTE alignment -- a 2-word object is then a
; multiple of 8 on both targets, zero waste either way, the math identical (only
; sizeof(word) varies). that variant also retires the wasm code-address special
; case (no sentinel function pointers left to dispatch on). costs a GC change;
; the layout below is the no-GC-change version. don't #ifdef the object layout by
; word size -- keep it uniform, parametrize the constants by sizeof(word).

(: CHAIN 0  CPLX 1  RSVD 2  OTHER 3            ; the four inline kinds (bits 3:2)

   ; --- word <-> fields (pure fixnum arithmetic) ---
   (charm? w)     (& w 1)                        ; bit 0 set -> a fixnum
   (val w)      (>> w 1)                       ; ... its carried value
   (fixnum n)   (| (<< n 1) 1)                 ; tag a value as a fixnum
   (threaded w) (& (>> w 1) 1)                 ; ref bit 1 -> a GC thread link
   (kind w)     (& (>> w 2) 3)                 ; ref bits 3:2 -> the kind
   (addr w)     (& w (^ 15 -1))                ; mask the nibble -> the address
   (ref a k)    (| a (<< k 2))                 ; pack address + kind (bits 1:0 = 0)

   ; --- a toy heap: a 16-aligned bump allocator over a map ---
   heap (tablet 0)                             ; address -> #(0 word0 1 word1)
   hp   #0                                      ; the bump pointer (a 1-cell box)
   _    (pin hp () 16)                           ; address 0 reserved as nil
   (alloc w0 w1) (: a (peep hp () 16)
                    _ (pin hp () (+ a 16))
                    _ (pin heap a #(0 w0 1 w1))
                    a)                          ; return the raw 16-aligned address
   (cell a i)    (peep (peep heap a 0) i 0)

   ; --- constructors return TAGGED references (no header word stored) ---
   (mk-chain cap cup) (ref (alloc cap cup) CHAIN)
   (mk-cplx  re  im)  (ref (alloc re  im)  CPLX)

   ; --- dispatch: the kind comes from the TAG, never a memory read ---
   (klass r) (? (charm? r)          'fixnum
                (= CHAIN (kind r)) 'chain
                (= CPLX  (kind r)) 'cplx
                                   'other)
   ; projections read word0/word1 of the addressed object directly: ap IS cap
   (hd r)  (cell (addr r) 0)
   (tl r)  (cell (addr r) 1)
   (cre r) (cell (addr r) 0)
   (cim r) (cell (addr r) 1)

   ; the apply-matrix ROW indexed by the tag -- the diagonal IS the table,
   ; reached with one mask, no header fetch
   row `((\ r 'apply-chain) (\ r 'apply-cplx) (\ r 'apply-rsvd) (\ r 'apply-other))
   (apply- r) ((row (kind r)) r))

; --- demos (expr ; value) ---
(& (mk-chain 7 9) 15)          ; 0        a chain ref is a RAW pointer (zero nibble)
(& (mk-cplx 3 4) 15)           ; 4        a cplx ref tags bits 3:2 (1 << 2)
(klass (mk-chain 7 9))         ; chain    kind recovered from the tag alone
(klass (mk-cplx 3 4))          ; cplx
(: c (mk-chain 7 9) (hd c))    ; 7        ap IS cap: word0 read directly, no ap stored
(: c (mk-chain 7 9) (tl c))    ; 9
(threaded (mk-chain 7 9))      ; 0        bit 1 is the GC's, untouched by the kind
(apply- (mk-cplx 3 4))         ; apply-cplx
(charm? (fixnum 42))             ; 1
(val (fixnum 42))              ; 42
(klass (fixnum 42))            ; fixnum
