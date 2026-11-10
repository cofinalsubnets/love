; the xtensa backend run whole: n checks laid as one program, each answer held to love's own
; 32-bit arithmetic, a miss exiting 100 + its index; all held, exit 42. the sources are cat in
; before it; XT_OUT names the linux ELF it writes, entered at 0x10060, for qemu-xtensa. with
; XT_BOARD=esp32 it writes an ELF whose one segment loads at iram's 0x40080000 for esprom's
; ram download, entered at its first byte, which says each line out of uart0 and spins
(borrow 'posix)
(borrow 'holo)
(: seed {0 12345}
   (rnd u) (pin seed 0 ((seed 0 * 1103515245 + 12345) & 2147483647), seed 0)
   (w x) (x & 4294967295)
   (s x) ((w x ^ 2147483648) - 2147483648)
   (pick u) (rnd 0 % 5 @ 0 (rnd 0 % 100) 1 (0 - rnd 0 % 3000) 2 (s (rnd 0 * 7 + rnd 0)) 3 (rnd 0 % 70000) _ (s (rnd 0 << 1)))
   ; each case: [prog-forms expected], the answer in r2
   (bin op f)
    (: a (pick 0) b (pick 0)
       [[['li 'r0 a] ['li 'r1 b] [op 'r2 'r0 'r1]] (f a b)])
   (imm op f)
    (: a (pick 0) b (pick 0)
       [[['li 'r0 a] [op 'r2 'r0 b]] (f a b)])
   (dv op f)
    (: a (pick 0) b0 (pick 0) b (b0 = 0 || b0 = -1 ? 7 b0)
       [[['li 'r0 a] ['li 'r1 b] (op = 'rem || op = 'urem ? [op 'r2 'r0 'r1 'r3] [op 'r2 'r0 'r1])] (f a b)])
   (sh op c f)
    (: a (pick 0) [[['li 'r2 a] [op 'r2 c]] (f a c)])
   (shv op f)
    (: a (pick 0) c (rnd 0 % 32) [[['li 'r2 a] ['li 'r5 c] [op 'r2 'r5]] (f a c)])
   (un op f) (: a (pick 0) [[['li 'r2 a] [op 'r2]] (f a)])
   (cnd c f)
    (: a (pick 0) b (rnd 0 % 3 @ 0 a 1 (pick 0) _ (a + 1))
       [[['li 'r0 a] ['li 'r1 b] ['cmp 'r0 'r1] ['set c 'r2]] (f a b ? 1 0)])
   (cnz c f)
    (: a (rnd 0 % 3 @ 0 0 1 (pick 0) _ (0 - 1 - rnd 0 % 9))
       [[['li 'r0 a] ['cmp 'r0 0] ['set c 'r2]] (f a ? 1 0)])
   (u x) (w x)
   (mem u)
    (: a (pick 0) o (4 * (rnd 0 % 8))
       [[['li 'r0 a] ['lea 'r6 'sp -64] ['st 'r6 o 'r0] ['li 'r0 0] ['ld 'r2 'r6 o]] a])
   (memb u)
    (: a (pick 0)
       [[['li 'r0 a] ['lea 'r6 'sp -64] ['st 'r6 0 'r0] ['ld1 'r2 'r6 1]] (s (((w a >> 8) & 255) ^ 128) - 128)])
   (memh u)
    (: a (pick 0)
       [[['li 'r0 a] ['lea 'r6 'sp -64] ['st 'r6 0 'r0] ['ldu2 'r2 'r6 2]] (w a >> 16)])
   (callc u)
    (: a (pick 0) b (pick 0)
       [[['li 'r0 a] ['li 'r1 b] ['call 'FN]] (a * 3 + b)])
   (pushc u) (: a (pick 0) [[['li 'r0 a] ['push 'r0] ['li 'r0 0] ['pop 'r2]] a])
   (idx u)
    (: a (pick 0) k (4 * (rnd 0 % 4)) sc ([1 2 4 8] (rnd 0 % 4)) o (4 * (rnd 0 % 4))
       [[['li 'r0 a] ['lea 'r6 'sp -128] ['li 'r5 k] ['leax 'r7 'r6 'r5 sc o] ['st 'r7 0 'r0]
         ['li 'r0 0] ['ldx 'r2 'r6 'r5 sc o]] a])
   (gen k)
    (k % 36 @
       0 (bin 'add (a \ b \ a + b)) 1 (bin 'sub (a \ b \ a - b)) 2 (bin 'and (a \ b \ w a & w b))
       3 (bin 'or (a \ b \ w a | w b)) 4 (bin 'xor (a \ b \ w a ^ w b)) 5 (bin 'imul (a \ b \ a * b))
       6 (dv 'div (a \ b \ a // b)) 7 (dv 'udiv (a \ b \ w a // w b)) 8 (dv 'rem (a \ b \ a % b)) 9 (dv 'urem (a \ b \ w a % w b))
       10 (imm 'add (a \ b \ a + b)) 11 (imm 'sub (a \ b \ a - b)) 12 (imm 'and (a \ b \ w a & w b)) 13 (imm 'xor (a \ b \ w a ^ w b))
       14 (rnd 0 % 31 + 1 @ c (sh 'shl c (a \ c \ w a << c)))
       15 (rnd 0 % 31 + 1 @ c (sh 'shr c (a \ c \ w a >> c)))
       16 (rnd 0 % 31 + 1 @ c (sh 'sar c (a \ c \ s a >> c)))
       17 (shv 'shlv (a \ c \ w a << c)) 18 (shv 'shrv (a \ c \ w a >> c)) 19 (shv 'sarv (a \ c \ s a >> c))
       20 (un 'neg (a \ 0 - a)) 21 (un 'not (a \ 0 - 1 - a))
       22 (un 'sx1 (a \ ((w a & 255) ^ 128) - 128)) 23 (un 'zx2 (a \ w a & 65535))
       24 ([['lt (a \ b \ s a < s b)] ['ge (a \ b \ s a >= s b)] ['gt (a \ b \ s a > s b)] ['le (a \ b \ s a <= s b)]
            ['eq (a \ b \ w a = w b)] ['ne (a \ b \ w a != w b)] ['below (a \ b \ u a < u b)] ['ae (a \ b \ u a >= u b)]
            ['above (a \ b \ u a > u b)] ['be (a \ b \ u a <= u b)]] (rnd 0 % 10) @ [c f] (cnd c f))
       25 ([['eq (a \ w a = 0)] ['ne (a \ w a != 0)] ['lt (a \ s a < 0)] ['ge (a \ s a >= 0)] ['gt (a \ s a > 0)] ['le (a \ s a <= 0)]
            ['above (a \ w a != 0)] ['be (a \ w a = 0)]] (rnd 0 % 8) @ [c f] (cnz c f))
       26 (mem 0) 27 (memb 0) 28 (memh 0) 29 (callc 0) 30 (pushc 0) 31 (rnd 0 % 2 @ 0 (idx 0) _ (pushc 0))
       ; muluh and mulsh are the esp32's mul32_high, which no qemu core carries
       32 (board ? (bin 'umulh (a \ b \ w a * w b >> 32)) (bin 'add (a \ b \ a + b)))
       33 (board ? (bin 'mulh (a \ b \ s a * s b >> 32)) (bin 'sub (a \ b \ a - b)))
       34 (rnd 0 % 32 @ c (sh 'ror4 c (a \ c \ w (w a >> c | w a << (32 - c)))))
       35 (shv 'rorv4 (a \ c \ w (w a >> c | w a << (32 - c))))
       _ (bin 'add (a \ b \ a + b)))
   board (getenv "XT_BOARD" = "esp32")
   n 300
   cases (map gen ^n)
   ; check i: answer in r2 against the expected, a miss exits 100 + i % 100
   (chk i c) ((c 0) + [['li 'r3 (s (w (c 1)))] ['cmp 'r2 'r3] ['br 'ne (name "F\(i)")]])
   ; uart0's fifo at 0x3FF40000, its fill in bits 16..23 of the status word at +28
   (say t) (catall (map (c \ [['li 'r0 c] ['call 'PUTC]]) (chars t)))
   putc [['align 4] ['label 'PUTC] ['li 'r6 0x3FF40000] ['label 'W] ['ld 'r7 'r6 28] ['shr 'r7 16]
         ['and 'r7 'r7 255] ['cmp 'r7 120] ['br 'ge 'W] ['st 'r6 0 'r0] ['ret]]
   (fails i) (board ? ([['label (name "F\(i)")]] + say "xtensa: check \(show i) missed\r\n" + [['jmp 'Z]])
                      [['label (name "F\(i)")] ['li 'r4 (100 + i % 100)] ['jmp 'X]])
   tail (board ? (say "xtensa: all \(show n) checks held\r\n" + [['label 'Z] ['jmp 'Z]])
                 [['li 'r4 42] ['label 'X] ['li 'r0 119] ['sys]])
   prog ((board ? (say "\r\nholo's xtensa, from ram\r\n") ()) + catall (map (i \ chk i (cases i)) ^n) + tail
         + catall (map fails ^n)
         + [['align 4] ['label 'FN] ['mov 'r2 'r0] ['add 'r2 'r2 'r0] ['add 'r2 'r2 'r0] ['add 'r2 'r2 'r1] ['ret]]
         + (board ? putc ()))
   code (holo-bytes 'xtensa prog)
   (zs k) (map (i \ 0) ^k)
   ; one PT_LOAD over the file at 0x10000, the code at 0x60 so a call0's word grain holds
   hdr ([127 69 76 70 1 1 1 0] + zs 8 + le16 2 + le16 94 + le32 1 + le32 (board ? 0x40080000 0x10060) + le32 52 + le32 0
        + le32 0x300 + le16 52 + le16 32 + le16 1 + le16 0 + le16 0 + le16 0)
   ; on the board, the code alone at iram's 0x40080000, for esprom's ram download
   ph (board ? (le32 1 + le32 0x60 + le32 0x40080000 + le32 0x40080000 + le32 #code + le32 #code + le32 5 + le32 4)
         (le32 1 + le32 0 + le32 0x10000 + le32 0x10000 + le32 (0x60 + #code) + le32 (0x60 + #code) + le32 5 + le32 0x1000))
   (write-bytes (getenv "XT_OUT") (hdr + ph + zs (0x60 - 84) + code),
    puts "xtrun: \(show n) checks laid, \(show #code) bytes\n", 0))
