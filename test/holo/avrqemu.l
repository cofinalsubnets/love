; one image for the 328p, run here by avrrun.l and by qemu-system-avr's uno: every operation over
; pseudo-random operands and sreg, its answer and sreg sent out the uart, then memory, stack, call and
; skip programs. AVR_OUT is the raw image; the interpreter's bytes go to AVR_REF
(borrow 'holo)
(borrow '(posix bytes))
(: seed {0 4242}
   (rnd u) (pin seed 0 ((seed 0 * 1103515245 + 12345) & 2147483647), seed 0 >> 8 & 255)
   (a mn ops) (avr-bytes 'avr5 mn ops)
   (ldi d v) (a 'ldi [['r d] ['im v]])
   (tx d) (a 'sts [['abs 0xc6] ['r d]])
   (cat l) (foldl (\ x y (x + y)) () l)
   ; op over (r16 r17), or r16 with an immediate; after it r16 (and r0 r1 for a multiply) and sreg
   (case mn ops regs)
    (: d (rnd 0) r (rnd 0) f (rnd 0 & 127)
       (cat [(ldi 16 d) (ldi 17 r) (ldi 18 f) (a 'out '((im 0x3f) (r 18))) (a mn ops) (a 'in '((r 19) (im 0x3f)))
             (cat (map tx regs)) (tx 19)]))
   rr '((r 16) (r 17)) u '((r 16)) one '(16)
   (imm _) [['r 16] ['im (rnd 0)]]
   (reps n f) (cat (map (_ \ f 0) ^n))
   alu (cat (map (mn \ reps 26 (_ \ case mn rr one)) '(add adc sub sbc and or eor cp cpc)))
   alui (cat (map (mn \ reps 16 (_ \ case mn (imm 0) one)) '(subi sbci cpi andi ori)))
   un (cat (map (mn \ reps 16 (_ \ case mn u one)) '(com neg inc dec lsr ror asr swap lsl rol tst clr)))
   mu (cat (map (mn \ reps 16 (_ \ case mn rr '(0 1))) '(mul muls mulsu fmul fmuls fmulsu)))
   wd (cat (map (mn \ reps 16 (_ \ (: k (rnd 0 & 63) (cat [(ldi 24 (rnd 0)) (ldi 25 (rnd 0)) (a mn [['r 24] ['im k]]) (a 'in '((r 19) (im 0x3f))) (tx 24) (tx 25) (tx 19)])))) '(adiw sbiw)))
   mem (cat [(ldi 26 0) (ldi 27 2) (ldi 28 0x20) (ldi 29 2) (ldi 30 0x40) (ldi 31 2) (ldi 16 0xa5) (ldi 17 0x3c)
             (a 'st '((ptr "X+") (r 16))) (a 'st '((ptr "-X") (r 17))) (a 'ld '((r 18) (ptr "X"))) (tx 18) (tx 26)
             (a 'st '((ptr "Y+") (r 16))) (a 'std '((dsp Y 5) (r 17))) (a 'ldd '((r 18) (dsp Y 5))) (tx 18) (tx 28)
             (a 'ld '((r 18) (ptr "-Y"))) (tx 18) (tx 28) (a 'std '((dsp Z 63) (r 16))) (a 'ldd '((r 18) (dsp Z 63))) (tx 18)
             (a 'st '((ptr "Z+") (r 17))) (a 'ld '((r 18) (ptr "-Z"))) (tx 18) (tx 30) (a 'movw '((r 2) (r 30))) (tx 2) (tx 3)
             (a 'push '((r 16))) (a 'in '((r 19) (im 0x3d))) (tx 19) (a 'pop '((r 18))) (tx 18)
             (a 'bst '((r 16) (im 0))) (a 'bld '((r 17) (im 7))) (tx 17)
             (a 'sec ()) (a 'in '((r 19) (im 0x3f))) (tx 19) (a 'clc ()) (a 'set ()) (a 'in '((r 19) (im 0x3f))) (tx 19)
             (ldi 30 4) (ldi 31 0) (a 'lpm '((r 18) (ptr "Z+"))) (tx 18) (a 'lpm ()) (tx 0) (tx 30)])
   ; rcall over the way out, the pushed bytes read back; skips past a two-word sts
   calls (cat [(a 'rcall '((rel 2))) (a 'rjmp '((rel 20))) (a 'pop '((r 20))) (a 'pop '((r 21))) (a 'push '((r 21))) (a 'push '((r 20)))
               (tx 20) (tx 21) (a 'ret ()) (a 'nop ()) (a 'nop ()) (ldi 16 1) (a 'sbrs '((r 16) (im 0))) (tx 16) (a 'sbrc '((r 16) (im 0)))
               (tx 16) (a 'cpse '((r 16) (r 16))) (tx 16) (ldi 16 0x5a) (tx 16)])
   ; sbic and sbis on an io register that reads 0; the uno has no bit to set there, so sbi and cbi only run
   bits (cat [(a 'sbi '((im 5) (im 3))) (a 'cbi '((im 5) (im 3))) (ldi 16 1) (a 'sbic '((im 5) (im 0))) (tx 16) (a 'sbis '((im 5) (im 0))) (tx 16) (ldi 16 2) (tx 16)])
   ; from byte b: icall and ijmp over z, jmp, reti, a mark sent at each stop and i read after reti
   (far b)
    (: w (b >> 1) (z k) (cat [(ldi 30 (w + k & 255)) (ldi 31 (w + k >> 8))])
       (cat [(z 8) (a 'icall ()) (a 'in '((r 19) (im 0x3f))) (tx 19) (a 'rjmp '((rel 10)))   ; words 0-6
             (a 'nop ())                                                                  ; word 7
             (ldi 16 0x31) (tx 16) (a 'reti ()) (a 'nop ())                               ; words 8-12
             (z 17) (a 'ijmp ()) (a 'nop ())                                             ; words 13-16
             (ldi 16 0x32) (tx 16) (a 'jmp [['abs (b + 46)]]) (a 'nop ())                 ; words 17-22
             (ldi 16 0x33) (tx 16)]))
   init (cat [(ldi 16 8) (a 'sts '((abs 0xc1) (r 16))) (ldi 16 0xff) (a 'out '((im 0x3d) (r 16))) (ldi 16 8) (a 'out '((im 0x3e) (r 16)))])
   pre (cat [init alu alui un mu wd mem calls bits])
   img (cat [pre (far #pre) (a 'rjmp '((rel -2)))])
   s (ar-run (ar-new 'atmega328p (string img)) 100000)
   (write-bytes (getenv "AVR_OUT") img, write-bytes (getenv "AVR_REF") (rev (s 'out)),
    (puts ("test/holo/avrqemu: " + show #img + " bytes, " + show (s 'n) + " steps, " + show #(s 'out) + " out, halt " + show (s 'halt) + "\n"))))
