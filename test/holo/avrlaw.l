; the interpreter's flags held to the manual's equations, written bit by bit here and by arithmetic
; there, over every operand pair; its pointer, stack, skip and refusal rules by small programs
(borrow 'holo)
(borrow '(posix))
(: misses {0 0}
   (bad what) (pin misses 0 (misses 0 + 1), misses 0 <= 8 ? (puts ("  miss " + show what + "\n")) 0)
   (ck what ok) (ok ? 0 (bad what))
   (bt v i) (v >> i & 1) (no x) (1 - x)
   ; the manual's h s v n z c as one byte, bits 5 4 3 2 1 0
   (pk h v n z c) (h << 5 | (n ^ v) << 4 | v << 3 | n << 2 | z << 1 | c)
   (zf r) (r = 0 ? 1 0)
   (m-add d r c)
    (: x (d + r + c & 255) (e i) (bt d i & bt r i | bt r i & no (bt x i) | no (bt x i) & bt d i)
       [x (pk (e 3) (bt d 7 & bt r 7 & no (bt x 7) | no (bt d 7) & no (bt r 7) & bt x 7) (bt x 7) (zf x) (e 7))])
   (m-sub d r c z0)
    (: x (d - r - c & 255) (e i) (no (bt d i) & bt r i | bt r i & bt x i | bt x i & no (bt d i))
       [x (pk (e 3) (bt d 7 & no (bt r 7) & no (bt x 7) | no (bt d 7) & bt r 7 & bt x 7) (bt x 7) (zf x & z0) (e 7))])
   (fresh f) (ar-new 'atmega328p f)
   ; one instruction from given registers and sreg
   (one mn ops l sr)
    (: s (fresh (string (avr-bytes 'avr5 mn ops + le16 0)))
       _ (each l (p \ ar-wr s <p (p 1))) _ (ar-wr s sreg sr)
       (ar-step s))
   f0 {'c 0}
   full (fresh "")
   (pair mn k d r)
    (: c (bt k 0) keep (bt k 1) sub (elem mn '(sub sbc)) two (elem mn '(adc sbc))
       ci (two ? c 0)
       _ (ar-wr full sreg (c | keep << 1))
       x (sub ? (ar-sub full d r ci two) (ar-add full d r ci))
       w (sub ? (m-sub d r ci (two ? keep 1)) (m-add d r ci))
       (ck [mn d r k] (x = <w && (ar-rd full sreg & 63) = w 1)))
   _ (each '(add adc sub sbc) (mn \ each (elem mn '(add sub) ? '(0) ^4) (k \ each ^256 (d \ each ^256 (r \ pair mn k d r)))))
   ; each mnemonic reaches its operation: the instruction itself, over a spread of values
   vals '(0 1 2 15 16 63 64 127 128 129 170 240 254 255)
   (st2 mn ops d r sr want)
    (: s (one mn ops [[16 d] [17 r]] sr) (ck [mn d r sr] (ar-rd s 16 = <want && (ar-rd s sreg & 63) = want 1)))
   (m-log x) [x (pk 0 0 (bt x 7) (zf x) 0)]
   _ (each vals (d \ each vals (r \ each ^4 (k \
       (: c (bt k 0) z (bt k 1) sr (c | z << 1) rr '((r 16) (r 17)) ri [['r 16] ['im r]]
          same (w \ [d (w 1)])
          (st2 'add rr d r sr (m-add d r 0), st2 'adc rr d r sr (m-add d r c), st2 'lsl '((r 16)) d r sr (m-add d d 0),
           st2 'rol '((r 16)) d r sr (m-add d d c), st2 'sub rr d r sr (m-sub d r 0 1), st2 'subi ri d r sr (m-sub d r 0 1),
           st2 'sbc rr d r sr (m-sub d r c z), st2 'sbci ri d r sr (m-sub d r c z), st2 'cp rr d r sr (same (m-sub d r 0 1)),
           st2 'cpi ri d r sr (same (m-sub d r 0 1)), st2 'cpc rr d r sr (same (m-sub d r c z)),
           st2 'neg '((r 16)) d r sr (m-sub 0 d 0 1)))))))
   ; the logic ops keep h and c
   (lg mn ops d r sr x c)
    (: w (pk (bt sr 5) 0 (bt x 7) (zf x) c) (st2 mn ops d r sr [x w]))
   _ (each vals (d \ each vals (r \ each '(0 33 63) (sr \
       (: rr '((r 16) (r 17)) ri [['r 16] ['im r]] u '((r 16)) c (bt sr 0)
          (lg 'and rr d r sr (d & r) c, lg 'andi ri d r sr (d & r) c, lg 'or rr d r sr (d | r) c, lg 'ori ri d r sr (d | r) c,
           lg 'eor rr d r sr (d ^ r) c, lg 'tst u d r sr d c, lg 'clr u d r sr 0 c, lg 'com u d r sr (255 - d) 1))))))
   ; inc and dec: v at 0x80 and 0x7f, h and c kept; the shifts: v is n^c, s is n^v, h kept
   _ (each ^256 (d \ each '(0 33 63) (sr \
       (: u '((r 16)) c (bt sr 0) h (bt sr 5) i (d + 1 & 255) e (d - 1 & 255)
          (sh mn x) (: n (bt x 7) k (bt d 0) (st2 mn u d 0 sr [x (pk h (n ^ k) n (zf x) k)]))
          (st2 'inc u d 0 sr [i (pk h (i = 128 ? 1 0) (bt i 7) (zf i) c)],
           st2 'dec u d 0 sr [e (pk h (e = 127 ? 1 0) (bt e 7) (zf e) c)],
           sh 'lsr (d >> 1), sh 'ror (d >> 1 | c << 7), sh 'asr (d >> 1 | d & 128),
           st2 'swap u d 0 sr [((d & 15) * 16 + (d >> 4)) sr])))))
   ; adiw and sbiw over word corners: v and c by the high byte's bit and r15
   _ (each '(0 1 62 63 64 255 256 32767 32768 32769 65472 65473 65534 65535) (d \ each '(0 1 32 63) (k \
       (: up (d + k & 65535) dn (d - k & 65535) h (bt d 15)
          (wd mn x v c) (: s (one mn [['r 24] ['im k]] [[24 (d & 255)] [25 (d >> 8)]] 0) n (bt x 15)
                           (ck [mn d k] (ar-w s 24 = x && (ar-rd s sreg) = (pk 0 v n (zf x) c))))
          (wd 'adiw up (no h & bt up 15) (no (bt up 15) & h), wd 'sbiw dn (h & no (bt dn 15)) (bt dn 15 & no h))))))
   ; the multiplies: c is the product's bit 15 before fmul's shift, z the result's
   (sg v) (v < 128 ? v (v - 256))
   _ (each vals (d \ each vals (r \
       (: (mu mn p sh) (: t (p & 65535) x (t << sh & 65535) s (one mn '((r 16) (r 17)) [[16 d] [17 r]] 60)
                          (ck [mn d r] (ar-w s 0 = x && (ar-rd s sreg & 63) = (60 | zf x << 1 | bt t 15) && (ar-rd s sreg & 60) = 60)))
          (mu 'mul (d * r) 0, mu 'muls (sg d * sg r) 0, mu 'mulsu (sg d * r) 0,
           mu 'fmul (d * r) 1, mu 'fmuls (sg d * sg r) 1, mu 'fmulsu (sg d * r) 1)))))
   ; programs: (mn ops) lists run to their break
   (prog fam dev l) (ar-run (ar-new dev (string (foldl (\ a i (a + avr-bytes fam <i (i 1))) () l))) 500)
   p5 (prog 'avr5 'atmega328p)
   (says what s rows) (ck [what (map (p \ ar-rd s <p) rows)] (s 'halt = 1 && all (p \ ar-rd s <p = p 1) rows))
   brk ['break ()]
   ; a call pushes its return's low byte first, so the high byte is the lower: from 0x8ff down
   s (p5 ['(call ((abs 8))) brk '(nop ()) brk])
   _ (ck 'call (s 'pc = 10 && s 'sp = 0x8fd && ar-rd s 0x8ff = 2 && ar-rd s 0x8fe = 0))
   s (p5 ['(rcall ((rel 4))) ['ldi '((r 17) (im 9))] brk ['ldi '((r 16) (im 7))] ['ret ()]])
   _ (says 'ret s '((16 7) (17 9)))
   _ (ck 'sp (s 'sp = 0x8ff))
   ; a post-increment and a pre-decrement step x by one around the access
   s (p5 ['(ldi ((r 26) (im 0))) '(ldi ((r 27) (im 2))) '(ldi ((r 16) (im 5))) '(st ((ptr "X+") (r 16)))
          '(ld ((r 17) (ptr "-X"))) '(st ((ptr "X+") (r 17))) brk])
   _ (says 'ptr s '((26 1) (27 2) (17 5) (0x200 5)))
   ; a skip passes a two-word instruction whole
   s (p5 ['(ldi ((r 17) (im 3))) '(sbrs ((r 17) (im 0))) '(sts ((abs 0xe015) (r 16))) brk])   ; 0xe015 is ldi r17, 5
   _ (says 'skip s '((17 3)))
   ; a 16-bit subtract's z is both halves'
   s (p5 ['(ldi ((r 16) (im 0))) '(ldi ((r 17) (im 1))) '(subi ((r 16) (im 1))) '(sbci ((r 17) (im 0)))
          '(cpi ((r 16) (im 255))) brk])
   _ (says 'sbci s '((16 255) (17 0)))
   (scares f) (trap (\ _ (f 0, 0)) 0 (a \ b \ [a b]))
   (refuse what f tag) (: e (scares f) (ck what (two? e && <e = tag)))
   (lacks mn ops)
    (: code (string (avr-bytes 'avr5 mn ops + le16 0x9598))
       (refuse [mn ops] (u \ avr-bytes 'avr25 mn ops) 'avr-lacks,
        ck [mn 'dec] ((avr-dec 'avr25 code 0 0) 1 0 = 'dir),
        refuse [mn 'run] (u \ ar-run (ar-new 'attiny85 code) 5) 'avr-op))
   ; what a family lacks: the encoder names it, the decoder reads <unknown>, the interpreter scares
   _ (each '((mul ((r 1) (r 2))) (muls ((r 16) (r 17))) (mulsu ((r 16) (r 17))) (fmul ((r 16) (r 17)))
             (fmuls ((r 16) (r 17))) (fmulsu ((r 16) (r 17))) (call ((abs 4))) (jmp ((abs 4))))
       (i \ lacks <i (i 1)))
   ; no family here has these, so their words are laid raw
   (none mn ops w fam dev)
    (: code (string (le16 w + le16 0x9598))
       (refuse [mn fam] (u \ avr-bytes fam mn ops) 'avr-lacks,
        ck [mn fam 'dec] ((avr-dec fam code 0 0) 1 0 = 'dir),
        refuse [mn fam 'run] (u \ ar-run (ar-new dev code) 5) 'avr-op))
   _ (each '((avr5 atmega328p) (avr25 attiny85)) (p \
       each '((elpm () 0x95d8) (elpm ((r 1) (ptr "Z")) 0x9016) (elpm ((r 1) (ptr "Z+")) 0x9017) (eijmp () 0x9419) (eicall () 0x9519))
         (i \ none <i (i 1) (i 2) <p (p 1))))
   ; io bits: sbi sets one, cbi clears one, sbic and sbis skip by one, over a two-word sts
   s (p5 ['(ldi ((r 16) (im 0x81))) '(out ((im 5) (r 16))) '(sbi ((im 5) (im 3))) '(cbi ((im 5) (im 0))) '(in ((r 18) (im 5)))
          '(ldi ((r 17) (im 3))) '(sbic ((im 5) (im 0))) '(sts ((abs 0xe015) (r 16))) '(sbis ((im 5) (im 3))) '(sts ((abs 0xe016) (r 16)))
          '(sbic ((im 5) (im 3))) '(ldi ((r 19) (im 1))) '(sbis ((im 5) (im 0))) '(ldi ((r 20) (im 1))) brk])
   _ (says 'iobit s '((18 0x88) (17 3) (19 1) (20 1)))
   ; jmp, ijmp and icall by word address, reti sets i
   s (p5 ['(ldi ((r 30) (im 6))) '(ldi ((r 31) (im 0))) '(icall ()) '(jmp ((abs 20))) brk '(ldi ((r 16) (im 7))) '(reti ()) brk brk
          '(ldi ((r 30) (im 14))) '(ijmp ()) brk brk '(ldi ((r 17) (im 8))) brk])
   _ (says 'far s '((16 7) (17 8) (0x5f 128)))
   _ (ck 'farsp (s 'sp = 0x8ff))
   _ (each '((ldi ((r 5) (im 1))) (ldi ((r 16) (im 256))) (adiw ((r 22) (im 1))) (adiw ((r 24) (im 64))) (ldd ((r 1) (dsp Y 64)))
             (brne ((rel 128))) (brne ((rel -130))) (rjmp ((rel 1))) (rjmp ((rel 4096))) (movw ((r 1) (r 2))) (in ((r 1) (im 64))) (frob ()))
       (i \ refuse i (_ \ avr-bytes 'avr5 <i (i 1)) 'avr-enc))
   _ (refuse 'family (_ \ avr-fam 'avr9) 'avr-family)
   _ (refuse 'bus (_ \ p5 ['(lds ((r 1) (abs 0x900))) brk]) 'avr-bus)
   _ (refuse 'flash (_ \ p5 ['(nop ())]) 'avr-op)
   (, (puts ("test/holo/avrlaw: " + show (misses 0) + " missed\n")) (misses 0 = 0 ? 0 (quit 1))))
