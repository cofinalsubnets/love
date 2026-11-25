; the mips backend run whole: n checks laid as one big-endian linux program, each answer held to
; love's own 32-bit arithmetic, a miss exiting 100 + its index; all held, exit 42. the sources are
; cat in before it; MIPS_OUT names the ELF it writes, entered at 0x400060, for qemu-mips
(borrow 'posix)
(borrow 'holo)
(: seed {0 12345}
   (rnd u) (pin seed 0 ((seed 0 * 1103515245 + 12345) & 2147483647), seed 0)
   (w x) (x & 4294967295)
   (s x) ((w x ^ 2147483648) - 2147483648)
   (pick u) (rnd 0 % 5 @ 0 (rnd 0 % 100) 1 (0 - rnd 0 % 3000) 2 (s (rnd 0 * 7 + rnd 0)) 3 (rnd 0 % 70000) _ (s (rnd 0 << 1)))
   ; each case: [prog-forms expected], the answer in r2
   (bin op f) (: a (pick 0) b (pick 0) [[['li 'r0 a] ['li 'r1 b] [op 'r2 'r0 'r1]] (f a b)])
   (imm op f) (: a (pick 0) b (pick 0) [[['li 'r0 a] [op 'r2 'r0 b]] (f a b)])
   (dv op f)
    (: a (pick 0) b0 (pick 0) b (b0 = 0 || b0 = -1 ? 7 b0)
       [[['li 'r0 a] ['li 'r1 b] (op = 'rem || op = 'urem ? [op 'r2 'r0 'r1 'r3] [op 'r2 'r0 'r1])] (f a b)])
   (sh op c f) (: a (pick 0) [[['li 'r2 a] [op 'r2 c]] (f a c)])
   (shv op f) (: a (pick 0) c (rnd 0 % 32) [[['li 'r2 a] ['li 'r5 c] [op 'r2 'r5]] (f a c)])
   (un op f) (: a (pick 0) [[['li 'r2 a] [op 'r2]] (f a)])
   ; set's answer and br's in one: set into r4, r2 is 2 where the branch was taken, then r2 + r4
   (cnd c f k)
    (: a (pick 0) b (k // 380 @ 0 a 1 (a + 1) _ (pick 0)) l (name "T\(k)")
       [[['li 'r0 a] ['li 'r1 b] ['li 'r2 2] ['cmp 'r0 'r1] ['set c 'r4] ['br c l] ['li 'r2 0] ['label l]
         ['add 'r2 'r2 'r4]] (f a b ? 3 0)])
   (cnz c f k)
    (: a (k // 380 @ 0 0 1 (pick 0) _ (0 - 1 - rnd 0 % 9)) l (name "T\(k)")
       [[['li 'r0 a] ['li 'r2 2] ['cmp 'r0 0] ['set c 'r4] ['br c l] ['li 'r2 0] ['label l]
         ['add 'r2 'r2 'r4]] (f a ? 3 0)])
   (u x) (w x)
   (mem u)
    (: a (pick 0) o (4 * (rnd 0 % 8))
       [[['li 'r0 a] ['lea 'r6 'sp -64] ['st 'r6 o 'r0] ['li 'r0 0] ['ld 'r2 'r6 o]] a])
   ; big-endian: byte 1 of a word is its bits 16..23, the halfword at 2 its low half
   (memb u)
    (: a (pick 0)
       [[['li 'r0 a] ['lea 'r6 'sp -64] ['st 'r6 0 'r0] ['ld1 'r2 'r6 1]] (s (((w a >> 16) & 255) ^ 128) - 128)])
   (memh u)
    (: a (pick 0)
       [[['li 'r0 a] ['lea 'r6 'sp -64] ['st 'r6 0 'r0] ['ldu2 'r2 'r6 2]] (w a & 65535)])
   (callc u)
    (: a (pick 0) b (pick 0)
       [[['li 'r0 a] ['li 'r1 b] ['call 'FN]] (a * 3 + b)])
   (pushc u) (: a (pick 0) [[['li 'r0 a] ['push 'r0] ['li 'r0 0] ['pop 'r2]] a])
   (idx u)
    (: a (pick 0) k (4 * (rnd 0 % 4)) sc ([1 2 4 8] (rnd 0 % 4)) o (4 * (rnd 0 % 4))
       [[['li 'r0 a] ['lea 'r6 'sp -128] ['li 'r5 k] ['leax 'r7 'r6 'r5 sc o] ['st 'r7 0 'r0]
         ['li 'r0 0] ['ldx 'r2 'r6 'r5 sc o]] a])
   (big u)
    (: a (pick 0) o (4 * (rnd 0 % 4))
       [[['li 'r0 a] ['lea 'r6 'sp -40000] ['st 'r6 (36000 + o) 'r0] ['li 'r0 0] ['ld 'r2 'r6 (36000 + o)]] a])
   (gen k)
    (k % 38 @
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
            ['above (a \ b \ u a > u b)] ['be (a \ b \ u a <= u b)]] (k // 38 % 10) @ [c f] (cnd c f k))
       25 ([['eq (a \ w a = 0)] ['ne (a \ w a != 0)] ['lt (a \ s a < 0)] ['ge (a \ s a >= 0)] ['gt (a \ s a > 0)] ['le (a \ s a <= 0)]
            ['above (a \ w a != 0)] ['be (a \ w a = 0)]] (k // 38 % 8) @ [c f] (cnz c f k))
       26 (mem 0) 27 (memb 0) 28 (memh 0) 29 (callc 0) 30 (pushc 0) 31 (idx 0)
       32 (bin 'umulh (a \ b \ w a * w b >> 32)) 33 (bin 'mulh (a \ b \ s a * s b >> 32))
       34 (rnd 0 % 32 @ c (sh 'ror4 c (a \ c \ w (w a >> c | w a << (32 - c)))))
       35 (shv 'rorv4 (a \ c \ w (w a >> c | w a << (32 - c))))
       36 (big 0) 37 (imm 'or (a \ b \ w a | w b))
       _ (bin 'add (a \ b \ a + b)))
   ; 30 rounds of 38: each condition against registers and zero, b = a, a + 1, then any
   n 1140
   cases (map gen ^n)
   ; check i: answer in r2 against the expected, a miss exits 100 + i % 100
   (chk i c) ((c 0) + [['li 'r3 (s (w (c 1)))] ['cmp 'r2 'r3] ['br 'ne (name "F\(show i)")]])
   (fails i) [['label (name "F\(show i)")] ['li 'r2 (100 + i % 100)] ['jmp 'X]]
   ; exit is o32's 4001, its status in a0
   prog (catall (map (i \ chk i (cases i)) ^n) + [['li 'r2 42] ['label 'X] ['li 'r0 4001] ['sys]]
         + catall (map fails ^n)
         + [['label 'FN] ['mov 'r2 'r0] ['add 'r2 'r2 'r0] ['add 'r2 'r2 'r0] ['add 'r2 'r2 'r1] ['ret]])
   code (holo-bytes-at 'mips prog 0x400060)
   (zs k) (map (i \ 0) ^k)
   ; one PT_LOAD over the file at 0x400000; o32, mips32r2
   hdr ([127 69 76 70 1 2 1 0] + zs 8 + be16 2 + be16 8 + be32 1 + be32 0x400060 + be32 52 + be32 0
        + be32 0x70001000 + be16 52 + be16 32 + be16 1 + be16 0 + be16 0 + be16 0)
   ph (be32 1 + be32 0 + be32 0x400000 + be32 0x400000 + be32 (0x60 + #code) + be32 (0x60 + #code) + be32 5 + be32 0x1000)
   (write-bytes (getenv "MIPS_OUT") (hdr + ph + zs (0x60 - 84) + code),
    puts "mipsrun: \(show n) checks laid, \(show #code) bytes\n", 0))
