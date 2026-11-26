; avr -- the 8-bit avr for holo: one instruction table, its encoder and the chips' facts.
; a word is 16 bits, little-endian; call, jmp, lds and sts carry a second, the low half of a
; row's 32-bit match and mask. decode.l reads the same rows.

(module 'holo
(: ;; what a family has beyond the common core, its pc's bytes on the stack and its e_flags number
   avr-fams {'avr5  ['(mul jmp) 2 5]
             'avr25 [() 2 25]}
   ;; a chip: family, flash bytes, ram's start and size, interrupt vectors
   avr-devs {'atmega32u4 '(avr5 32768 0x100 2560 43)
             'atmega328p '(avr5 32768 0x100 2048 26)
             'attiny85   '(avr25 8192 0x60 512 15)}
   (avr-fam f) (peep avr-fams f () @ r (two? r ? r (scare 'avr-family f)))
   (avr-dev d) (peep avr-devs d () @ r (two? r ? r (scare 'avr-device d)))

   ;; an operand kind: [tag mask base step signed]. the value is base + step * field, the field's
   ;; bits low to high in the mask's. a value rides as (r n) (im n) (rel off) (abs a) (dsp p q) (ptr p)
   avr-kinds {'d5 '(r 0x1f0 0 1 0) 'r5 '(r 0x20f 0 1 0) 'd4 '(r 0xf0 16 1 0) 'r4 '(r 0xf 16 1 0)
              'd3 '(r 0x70 16 1 0) 'r3 '(r 7 16 1 0) 'dw '(r 0xf0 0 2 0) 'rw '(r 0xf 0 2 0)
              'da '(r 0x30 24 2 0) 'rr '(r 0x1f0 0 1 0)           ; rr: one register in both fields
              'k8 '(im 0xf0f 0 1 0) 'k6 '(im 0xcf 0 1 0) 'a6 '(im 0x60f 0 1 0) 'a5 '(im 0xf8 0 1 0)
              'b3 '(im 7 0 1 0) 'b7 '(rel 0x3f8 0 2 1) 'b12 '(rel 0xfff 0 2 1)
              'k22 '(abs 0x1f1ffff 0 2 0) 'k16 '(abs 0xffff 0 1 0)
              'Yq '(dsp 0x2c07 0 1 0) 'Zq '(dsp 0x2c07 0 1 0)}
   (av-get m w) (: (go m w o b) (m = 0 ? o (go (m >> 1) (w >> 1) (m & 1 = 1 ? (o | (w & 1) << b) o) (b + (m & 1)))) (go m w 0 0))
   (av-put m v) (: (go m v o b) (m = 0 ? o (m & 1 = 1 ? (go (m >> 1) (v >> 1) (o | (v & 1) << b) (b + 1)) (go (m >> 1) v o (b + 1)))) (go m v 0 0))
   (av-bits m) (m = 0 ? 0 ((m & 1) + av-bits (m >> 1)))

   avr-ptrs '(("Z+" 1) ("-Z" 2) ("Y+" 9) ("-Y" 10) ("X" 12) ("X+" 13) ("-X" 14))
   ;; a row [name match mask kinds fact]: the fact a family must have, or ()
   (av-r m k r) [<r (r 1) m k (two? >>r ? (r 2) ())]
   avr-tab (catall [
     ;; one register twice, ahead of the two-register rows llvm shows it instead of
     (map (av-r 0xfc00 '(rr)) '((lsl 0x0c00) (rol 0x1c00) (tst 0x2000) (clr 0x2400)))
     (map (av-r 0xfc00 '(d5 r5))
          '((cpc 0x0400) (sbc 0x0800) (add 0x0c00) (cpse 0x1000) (cp 0x1400) (sub 0x1800) (adc 0x1c00)
            (and 0x2000) (eor 0x2400) (or 0x2800) (mov 0x2c00) (mul 0x9c00 mul)))
     [['nop 0 0xffff () ()] ['movw 0x0100 0xff00 '(dw rw) ()] ['muls 0x0200 0xff00 '(d4 r4) 'mul]]
     (map (av-r 0xff88 '(d3 r3)) '((mulsu 0x0300 mul) (fmul 0x0308 mul) (fmuls 0x0380 mul) (fmulsu 0x0388 mul)))
     (map (av-r 0xf000 '(d4 k8)) '((cpi 0x3000) (sbci 0x4000) (subi 0x5000) (ori 0x6000) (andi 0x7000) (ldi 0xe000)))
     [['ldd 0x8000 0xd208 '(d5 Zq) ()] ['ldd 0x8008 0xd208 '(d5 Yq) ()]
      ['std 0x8200 0xd208 '(Zq d5) ()] ['std 0x8208 0xd208 '(Yq d5) ()]
      ['lds 0x90000000 0xfe0f0000 '(d5 k16) ()] ['sts 0x92000000 0xfe0f0000 '(k16 d5) ()]]
     (map (r \ ['ld (0x9000 | r 1) 0xfe0f ['d5 <r] ()]) avr-ptrs)
     (map (r \ ['st (0x9200 | r 1) 0xfe0f [<r 'd5] ()]) avr-ptrs)
     [['lpm 0x9004 0xfe0f ['d5 "Z"] ()] ['lpm 0x9005 0xfe0f ['d5 "Z+"] ()]
      ['elpm 0x9006 0xfe0f ['d5 "Z"] 'elpm] ['elpm 0x9007 0xfe0f ['d5 "Z+"] 'elpm]]
     (map (av-r 0xfe0f '(d5))
          '((pop 0x900f) (push 0x920f) (com 0x9400) (neg 0x9401) (swap 0x9402) (inc 0x9403)
            (asr 0x9405) (lsr 0x9406) (ror 0x9407) (dec 0x940a)))
     (map (av-r 0xfe0e0000 '(k22)) '((jmp 0x940c0000 jmp) (call 0x940e0000 jmp)))
     (map (av-r 0xffff ())
          '((sec 0x9408) (sez 0x9418) (sen 0x9428) (sev 0x9438) (ses 0x9448) (seh 0x9458) (set 0x9468) (sei 0x9478)
            (clc 0x9488) (clz 0x9498) (cln 0x94a8) (clv 0x94b8) (cls 0x94c8) (clh 0x94d8) (clt 0x94e8) (cli 0x94f8)
            (ijmp 0x9409) (eijmp 0x9419 eind) (icall 0x9509) (eicall 0x9519 eind) (ret 0x9508) (reti 0x9518)
            (sleep 0x9588) (break 0x9598) (wdr 0x95a8) (lpm 0x95c8) (elpm 0x95d8 elpm) (spm 0x95e8)))
     (map (av-r 0xff00 '(da k6)) '((adiw 0x9600) (sbiw 0x9700)))
     (map (av-r 0xff00 '(a5 b3)) '((cbi 0x9800) (sbic 0x9900) (sbi 0x9a00) (sbis 0x9b00)))
     [['in 0xb000 0xf800 '(d5 a6) ()] ['out 0xb800 0xf800 '(a6 d5) ()]
      ['rjmp 0xc000 0xf000 '(b12) ()] ['rcall 0xd000 0xf000 '(b12) ()]]
     (map (av-r 0xfc07 '(b7))
          '((brlo 0xf000) (breq 0xf001) (brmi 0xf002) (brvs 0xf003) (brlt 0xf004) (brhs 0xf005) (brts 0xf006) (brie 0xf007)
            (brsh 0xf400) (brne 0xf401) (brpl 0xf402) (brvc 0xf403) (brge 0xf404) (brhc 0xf405) (brtc 0xf406) (brid 0xf407)))
     (map (av-r 0xfe08 '(d5 b3)) '((bld 0xf800) (bst 0xfa00) (sbrc 0xfc00) (sbrs 0xfe00)))])
   (av-long? r) (0xffff < r 2)
   (av-has? fam r) (r 4 = () || elem (r 4) (<(avr-fam fam)))

   ;; a kind's field mask in a row: a two-word row's first word is its high half
   (av-mask r k m) (av-long? r && nelem k '(k22 k16) ? (m << 16) m)
   ;; an operand's field as a kind lays it, or () where it does not fit
   (av-fit k v)
    (peep avr-kinds k () @ f
     (!(two? f) ? (v = ['ptr k] ? 0 ())
      (: n (av-bits (f 1)) x (last v - f 2) q (x // f 3)
         lo (f 4 = 1 ? (0 - (1 << (n - 1))) 0) hi (f 4 = 1 ? ((1 << (n - 1)) - 1) ((1 << n) - 1))
         (<v = <f && (<f != 'dsp || v 1 = (k = 'Yq ? 'Y 'Z)) && x = q * f 3 && lo <= q <= hi
          ? (q & ((1 << n) - 1)) ()))))
   (av-lay1 r k q)
    (peep avr-kinds k () @ f
     (!(two? f) ? 0 (av-put (av-mask r k (f 1)) q | (k = 'rr ? (av-put 0x20f q) 0))))
   ;; a row's word for ops, or ()
   (av-lay r ops)
    (: (go ks vs w) (? !(two? ks) (two? vs ? () w) !(two? vs) ()
                       (av-fit <ks <vs @ q (q = () ? () (go >ks >vs (w | av-lay1 r <ks q)))))
       (go (r 3) ops (r 1)))
   avr-byname (foldl (\ t r (pin t <r (peep t <r () + [r]))) {} avr-tab)
   ;; the bytes of mn's first row to take ops, scaring by name for one the family lacks
   (avr-bytes fam mn ops)
    (: (go rs) (? !(two? rs) (scare 'avr-enc [mn ops])
                  (: w (av-lay <rs ops)
                     (? (w = ()) (go >rs)
                        !(av-has? fam <rs) (scare 'avr-lacks [fam mn])
                        (av-long? <rs) (le16 (w >> 16) + le16 (w & 0xffff))
                        (le16 w))))
       (go (peep avr-byname mn ()))))
) ; module 'holo
