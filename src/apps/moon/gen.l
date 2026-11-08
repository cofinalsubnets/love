; the code generator's frame and finish: AST -> (1 ir-forms) | (), in holo's neutral IR. lo.l
; lowers each function to vregs, ra.l colours them, and the passes here lay the frame and tidy
; what ra left. this file also holds the kits, types and tables lo.l calls.
; stage.l types each pass against its sig there: a new pass declares one.
(module 'moon
(borrow 'kore)
(borrow 'holo) ; the assembler + linker
(:
   x86rn {'r0 "rax" 'r1 "rcx" 'r2 "rdx" 'r3 "rbx" 'r4 "rbp" 'r5 "rsi" 'r6 "rdi" 'r7 "r8"
          'r8 "r9" 'r9 "r10" 'r10 "r11" 'r11 "r12" 'r12 "r13" 'r13 "r14" 'r14 "r15"}
   ; bswap32 in place on r0 through r1-r3
   bsw32 '((li r2 255)
           (mov r1 r0) (shr r1 24) (and r1 r1 r2)
           (mov r3 r0) (shr r3 16) (and r3 r3 r2) (shl r3 8) (or r1 r1 r3)
           (mov r3 r0) (shr r3 8) (and r3 r3 r2) (shl r3 16) (or r1 r1 r3)
           (and r0 r0 r2) (shl r0 24) (or r0 r0 r1))
   ; calls that return twice: what lives across one lives in memory
   twicefns '("setjmp" "_setjmp" "__setjmp" "sigsetjmp" "__sigsetjmp" "savectx" "vfork" "getcontext" "__builtin_setjmp")
   csx64 '(r11 r12 r13 r14)                         ; x64's borrowable callee-saved r12..r15
   (csx g) (ia32? g ? '(r5 r6) csx64)              ; ..i386's: esi edi
   ; unsigned 64 -> double: cvtsi2sd is signed, so sum the halves (each exact) as hi*2^32 + lo
   ul2d '((mov r1 r0) (shr r1 32)
         (shl r0 32) (shr r0 32)
         (cvtsi2sd f0 r1)
         (li r1 0x41f0000000000000) (movqxr f1 r1)   ; 2^32
         (mulsd f0 f1)
         (cvtsi2sd f1 r0)
         (addsd f0 f1))
   ; the ISA families, the one place an op's membership is stated (an op off every list is opaque).
   ; off every list is opaque). an op that can base on r4 must also join a4base + uoff
   ldops9 '(ld ld1 ld2 ld4 ldu1 ldu2 ldu4)
   gstops '(st st1 st2 st4)
   fldops '(ldsd ldss) fstops '(stsd stss)
   stops9 (gstops + fstops)                         ; gp head first
   leaops '(lea lean)                               ; lean: consumed by its own use
   xops '(leax ldx ldxb ldxh ldxw ldxsw)            ; base index scale disp; ldxh a zero-extending 16-bit load, ldxw/ldxsw the 32-bit ones, zero/sign-extending
   x4ops '(andx4 orx4 xorx4) m4ops '(andm4 orm4 xorm4)   ; and/or/xor r32 by a 32-bit load (base index scale disp | base off): the top zeroes
   stxops '(stx stxb)
   fxops '(ldsdx ldssx) fstxops '(stsdx stssx)      ; x64: no gp effect
   siops '(si si1 si2 si4)                          ; the store-immediates
   aluops '(add sub and or xor imul)
   ; the flag family sets or reads the flags for the form beside it: never pure, never in aluops (the two-address rewrites); off every list rdsp answers 'bar
   flagops '(adds subs adcs sbcs adc sbc ors)
   divops '(div rem udiv urem)
   ; (umull dl dh a b) defines two; udivll/uremll are nullary, owning r0..r3 (r4..r7 saved inside)
   wmops '(umull smull)
   llops '(udivll uremll)
   vshops '(shlv shrv sarv rorv rorv4)              ; x64: count in r1
   qfile '(r0 r1 r2 r3 r4 r5 r6 r7 r8 r9 r10 r11 r12)   ; the gp file a 32-bit pair move walks
   unops '(neg not sx1 sx2 sx4 zx1 zx2 zx4)         ; one-register rewrites
   xmmops '(addsd subsd mulsd divsd minsd maxsd movsd movapd ucomisd cvtss2sd cvtsd2ss
            addss subss mulss divss minss maxss ucomiss movss)   ; no gp effect
   ; the gen state g: 'n the label counter, 'off the frame high-water, 'brk/'cnt loop label stacks,
   ; 'glob name -> (label ty init), 'globs the emission order, 'strs ((label . text)..);
   ; env ((name off ty)..) the frame locals
   (nlab g pfx) (peep g 'n 0 @ k (pin g 'n (k + 1), name "\(pfx).\(k)"))   ; one counter across prefixes
   argregs '(r6 r5 r2 r1 r7 r8)                      ; the SysV integer/pointer arg registers
   argregs-a64 '(r0 r1 r2 r3 r4 r5 r6 r7)           ; AAPCS64: x0..x7
   argregs-t32 '(r0 r1 r2 r3)                        ; AAPCS32: r0..r3
   (xmmreg i) (name "f\(i)")                ; the SysV double args f0..f7
   ; the AAPCS-VFP arg slots (t32f) s0..s15: a float takes one, a double an aligned pair, each the
   ; lowest free run. the state is a 16-bit mask; a miss fills it
   (vfpn m n a)                                    ; the lowest a-aligned run of n free slots, or -1
    (: (go i) (? (16 < i + n) -1                   ; a number, not (): slot 0 is a valid answer
                 (0 = m & (((1 << n) - 1) << i)) i
                 (go (i + a)))
       (go 0))
   (vfpm m i n) (m | (((1 << n) - 1) << i))
   vfpx 65535
   ; an even slot is the single view of dK; an odd one has no f-register name, so its word rides
   ; r12 into the scratch s30, leaving r12 for a far home's address
   (vfpsv k base off) (0 = k & 1 ? [['stss base off (xmmreg (k // 2))]]   ; slot k -> a 4-byte home
                         [['movsnrx 'r12 k] ['movdxr 'f15 'r12] ['stss base off 'f15]])
   (bad? x) (x = 'bad)
   ; the value tuple (ty reg forms); the flo lane keeps the f0 protocol and dispatches on vty
   (vty v) <v
   (vreg v) <>v
   (vfs v) <>>v
   fregs16 '(f0 f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12 f13 f14 f15)
   ; MOON_ABLATE="tpool,cs" holds named mechanisms empty, for pricing. read per unit at run time
   ; (a value binding would fold at bake)
   (ablenv _)
    (getenv "MOON_ABLATE" @ s
       (!(string? s) ? ()
          (: n #s
             (cut i j acc) (i < j ? (name (snip s i j) . acc) acc)
             (go i j acc)
              (? (n <= j) (cut i j acc)
                 (elem (s j) '(44 32)) (go (j + 1) (j + 1) (cut i j acc))
                 (go i (j + 1) acc))
             (go 0 0 ()))))
   (abl? g nm) (elem nm (g 'abl))
   ; MOON_DUMP=<fn> prints that fn's forms at a seam (out, before the object), named by nm
   ; MOON_CENSUS=1 prints a line per pass run: the fn, the pass, its forms dropped and made, as
   ; the multiset difference of what it took and what it gave back. read per unit, as abl is
   (cenv _) (getenv "MOON_CENSUS" @ s (string? s && 0 < #s))
   (cz g nm fs out)
    (!(g 'census) || !(two? fs) || !(two? out) ? out
       (: t (foldl (t \ e \ (show e @ k (pin t k (peep t k 0 + 1)))) {} fs)
          c (foldl (c \ e \ (show e @ k (peep t k 0 > 0 ? (pin t k (t k - 1), c + 1) c))) 0 out)
          (puts "census \(show (g 'fn)) \(show nm) \(#fs - c) \(#out - c)\n", out)))
   ; MOON_PROF=1 prints a line per timed stage, its name and nanoseconds, for the reader to sum
   (mprof k th) (getenv "MOON_PROF" @ () (th 0) _ (nclock 0 @ t0 (th 0 @ v (puts ";; prof \(k) \(nclock t0)\n", v))))
   (dp nm fs) (getenv "MOON_DUMP" @ w
                 (string? w && two? fs && two? <fs && w = show (<fs 1) ?
                    (puts ";; \(show nm)\n",
                     map (f \ (putx f, putc 10)) fs,
                     fs)
                    fs))
   (callish? (a . u))                                ; does the AST reach a call? (an inline splice still may)
    ; a statement expression resets the pool per statement: a barrier, like a call
    (a = 'call || a = 'sexpr || callish? a || callish? u)
   ; may this param alias? only if the body never writes it (the register holds the caller's
   ; live value). a C name is a string, so the compare is `=` -- `==` never matches
   (wrs? nm e)
    (e @ (('asn || 'post) . ('var ^nm) . _) 1
         ('asm . _) (any (o \ <>o @ ('var ^nm) 1 ()) (e 2))   ; an asm output writes its name
     (: (go (a . u)) (wrs? nm a || go u) (go e)))
   ; how hard the body leans on this param: reads weighted x8 per loop level
   (rdw nm e w)
    (!(two? e) ? 0
       (e @ ('var ^nm) w
            (: w9 (elem <e '(while do for) ? (w * 8) w)
               (go l a) (!(two? l) ? a (go >l (a + rdw nm <l w9)))
               ((two? <e ? (rdw nm <e w9) 0) + go >e 0))))
   ; the target seam: g 'tgt picks the ABI shapes; the IR stays neutral. the arm family retargets
   ; the frame base to fp at the end of build (a4ize)
   (a64? {'tgt 'a64}) 1
   (t32? g) (elem (g 'tgt) '(thumb2 thumb2sp arm thumb1))   ; AAPCS32: armv7e-m, linux's arm, armv6-M
   (sp64? {'tgt 'thumb2sp}) 1       ; armv7e-m with an sp-only fpu: f64 arithmetic softens
   (v6m? {'tgt 'thumb1}) 1          ; armv6-M: narrower immediates, no imm-mul, soft-divide, pop-pc epilogue
   (t32f? g) (t32? g && !(v6m? g))  ; with an fpu, hence AAPCS-VFP: floats ride s0..s15
   (t2? g) (elem (g 'tgt) '(thumb2 thumb2sp))   ; armv7e-m itself, past linux's arm and v6-M
   (rv64? g) (elem (g 'tgt) '(rv64 wasm))   ; rv64imfd (LP64): 64-bit, 8 gp args, hard doubles, the lr/fp frame
   (wasm? {'tgt 'wasm}) 1          ; ..which wasm rides whole; it differs only where its machine lacks an op
   (gtgt g) (wasm? g ? 'rv64 (peep g 'tgt 'x64))   ; the ABI name the asm dialect and the lane rosters read
   (x64? g) (peep g 'tgt 'x64 = 'x64)
   (a8? g) (a64? g || rv64? g)                        ; a64 + riscv share the AAPCS64 shapes
   (gchar g) (drop 6 (peep g 'mo ()) @ r (two? r && charm? <r ? (<r = 1 ? 'cchar 'char)   ; plain char, as parse.l's pchar: the driver's
                (elem (peep g 'tgt 'x64) '(a64 rv64 thumb1 thumb2 thumb2sp arm) ? 'cchar 'char)))
   (arm? g) (a64? g || t32? g || rv64? g)             ; the lr-push / fp-base frame family (riscv rides it whole)
   ; the 32-bit x86 seats (SysV i386, cdecl; i386m16 its 16-bit face): thumb's word and pair,
   ; x64's instructions, and every argument on the stack
   (ia32? g) (elem (g 'tgt) '(i386 i386m16))
   (x86? g) (x64? g || ia32? g)
   (ilp32? g) (t32? g || ia32? g)                 ; the 32-bit word: a long and a pointer one register, a long long the r0:r1 pair
   (m16? g) (g 'tgt = 'i386m16)
   (m16b g) (m16? g ? [102] ())                    ; a raw 32-bit operation's operand-size prefix in a 16-bit segment
   (m16a g) (m16? g ? [103] ())                    ; ..and a raw memory operand's address-size prefix
   (acw g w) (m16? g ? (w @ 4 [102] ()) (w @ 2 [102] 8 [72] ()))   ; a cmpxchg's width prefix: a 16-bit segment reads 16 bits bare
   (wsize g) (ilp32? g ? 4 8)                       ; a pointer, a gp scalar, a stack cell
   (argr g) (? (a8? g) argregs-a64 (t32? g) argregs-t32 (ia32? g) (take (rpn g) '(r0 r2 r1)) argregs)   ; riscv a0..a7 map onto the same r0..r7; i386 -mregparm's eax edx ecx
   (ngp g) (? (a8? g) 8 (t32? g) 4 (ia32? g) (rpn g) 6)
   ; i386's hidden result pointer: eax under -mregparm (a variadic call keeps every word on the stack), else the first stack word
   (srreg? g va) (ia32? g && 0 < rpn g && !va)
   (pkr g) (? (a64? g) 'r15 (t32? g) 'r12 (rv64? g) 'r12 'r3)   ; the callr park (rbx / x15 / IP / t4), clear of the arg registers
   (ovb g) (? (a8? g) 32 (v6m? g) 12 (ilp32? g) 8 16)   ; overflow params above the push cells: x64 [ret+rbp]=16; a64/riscv 2x16; thumb2 lr+fp=8; v6m lr+fp+r4=12
   ; the callee-saved pools residency may borrow: saved by the prologue (g 'cssv), reloaded on every
   ; exit. no r4 in an arm pool (a4ize renames a base-slot r4 to fp), no r7 in v6m's (fp there);
   ; riscv leads with s1 (r15), the rvc window's one callee-saved register
   (cspool g) (? (abl? g 'cs || g 'twice) ()
                 (a64? g) '(r19 r20 r21 r22 r23 r24 r25 r26 r27 r28)
                 ; wasm's r16..r18 are riscv's gp tp and flag scratch: plain locals there
                 (wasm? g) '(r15 r13 r14 r19 r20 r21 r22 r23 r24 r25 r26 r16 r17 r18)
                 (rv64? g) '(r15 r13 r14 r19 r20 r21 r22 r23 r24 r25 r26)
                 (v6m? g) '(r5 r6)                    ; the 16-bit str/ldr reach r0-r7 only, and r7 is fp
                 (t32? g) '(r5 r6 r7 r8 r9 r10)
                 (ia32? g) '(r5 r6)   ; esi edi, and ebx where nothing parks there (cgfn); ebp the frame
                 (arm? g) ()
                 csx64)
   (deep? pl) (two? >>pl)                           ; a pool affords a priced seat: two remain after the take
   (fbase g) (arm? g ? 'fp 'r4)                   ; the frame base as post-build ir1 spells it (a4ize)
   ; the frame hangs off its top, so a save slot laid late moves no other (rv64, v6m address up)
   (cstop? g) (!(rv64? g) && !(v6m? g))
   ; 'bad is both a policy deopt ("take another lane") and "no lane anywhere"; only the second
   ; speaks, so nolane pins the phrase. last pin wins
   (nolane g txt) (pin g 'nolane txt, 'bad)
   ; the immediate gate: what each target's ALU/cmp immediates reach
   (immok g cls n)
    (? (a64? g)
       (cls @ 'addsub (-16777215 <= n <= 16777215)   ; imm12, or the backend's hi12+lo12 split
              'cmp (-4095 <= n <= 4095 || 0 = n % 4096 && -16777215 <= n <= 16777215)   ; imm12, or imm12 lsl 12 (no split -- flags)
              'log (0 < n < 9223372036854775808 && 0 = n & (n + 1)))   ; a low run of 1..63 ones: all 64 has no encoding
       (v6m? g)
        (cls @ 'addsub (-255 <= n <= 255)             ; imm8 (a negative flips)
               'cmp (0 <= n <= 255))                  ; cmp imm8 only -- no cmn-imm on v6-M, so materialize negatives
       (t32? g)
        (cls @ 'addsub (-4095 <= n <= 4095)           ; addw/subw imm12
               'cmp (-2147483648 < n < 2147483648 && t2imm? (abs n))   ; cmp/cmn, a modified immediate
               'log (-2147483648 <= n < 4294967296 && t2imm? n))      ; and/or/xor/tst
       (fits32 n))
   ; a thumb2 modified immediate: a byte, a byte laid 00XY00XY / XY00XY00 / XYXYXYXY, or eight
   ; bits anywhere above
   (t2imm? n)
    (: u (n & 4294967295) b (u & 255) c (u >> 8 & 255)
       (u < 256 || u = b * 65537 || u = c * 16777472 || u = b * 16843009 || u // (u & (0 - u)) < 256))
   ; may this op take n as its immediate? (the sweeps ask before rewriting a reg-reg form)
   (imma g op n) (op @ 'imul ((x64t? g || rv64? g) && fits32 n)   ; imul imm: x64's three-operand form, riscv materializes; a64/t32 have none
                       ('add || 'sub) (immok g 'addsub n)
                       'cmp (immok g 'cmp n)
                       (immok g 'log n || t32? g && !(v6m? g) && elem op '(and or) && -2147483648 <= n < 4294967296
                        && (t2imm? (-1 - n) || op = 'and && 0 < n && 0 = n & (n + 1))))   ; bic, orn, a low run's ubfx
   (uldop sz) (sz @ 1 'ldu1 2 'ldu2 4 'ldu4 'ld)
   (fnty g nm) (g 'sigs nm @ sig        ; return and params riding when sig'd, a variadic's as an unprototyped one's
                (two? sig ? ['fn <sig (sig 2 ? () <>sig)] '(fn)))
   ; the eightbyte classes of a by-value aggregate (its value is its address in r0): '(int) /
   ; '(sse) at <=8 bytes, two symbols at 9..16, () for a scalar, an unsized tag or >16 (memory)
   (aclass g ty)
    (!(stru? ty) || ia32? g ? ()                     ; i386 classes nothing: every aggregate is memory
       (peep (g 'stag) <>ty 0 @ se
          (? !(two? se) ()
             (16 < <>se) ()
             ; AAPCS64: an aggregate not of one float base rides gp registers alone
             ((a64? g || t32? g) && !(flo? (hfab g ty))) (<>se <= 8 ? '(int) '(int int))
             (: cls {}
                (mark o c) (: i (o >> 3) old (cls i)
                              (pin cls i (old = 'int || c = 'int ? 'int 'sse)))
                (walk o mty)
                 (? (flo? mty) (mark o 'sse)
                    (arr? mty)
                     (: esz (tsz g <>mty) (each ^(<>>mty) (i \ walk (o + i * esz) <>mty), 1))
                    (stru? mty)
                     (peep (g 'stag) <>mty 0 @ e2
                        (!(two? e2) ? 1 (fields o <e2)))
                    (mark o 'int))
                (fields o fs)
                 (!(two? fs) ? 1
                    (<fs @ f (walk (o + <>f) <>>f, fields o >fs)))
                (fields 0 <se,
                 <>se <= 8 ? [(peep cls 0 'int)]
                   [(peep cls 0 'int) (peep cls 1 'int)])))))
   ; the HFA base: the one float type of every scalar leaf, else (). AAPCS-VFP aligns a candidate
   ; to its base (a float HFA to one slot, a double to two), which the eightbyte classes cannot tell
   (hfab g ty)
    (: (walk mty acc)
        (? (flo? mty) (? !acc mty (acc = mty) acc 'no)
           (arr? mty) (walk <>mty acc)
           (stru? mty) (peep (g 'stag) <>mty 0 @ e2
                          (!(two? e2) ? 'no (fields <e2 acc)))
           'no)
       (fields fs acc)
        (!(two? fs) ? acc
           (walk <>><fs acc @ a2 (a2 @ 'no 'no (fields >fs a2))))
       (!(stru? ty) ? ()
          (peep (g 'stag) <>ty 0 @ se
             (two? se ?
                (fields <se () @ r (r @ 'no () r))))))
   (acls2 g ty ca cb) (aclass g ty @ (^ca ^cb) 1)
   (ipair? g ty) (acls2 g ty 'int 'int)      ; both INT: rax:rdx (return/result lanes)
   (aone g ty) (aclass g ty @ c (two? c && !(two? >c) ? <c))
   ; the memory class: an aggregate past 16 bytes, passed wholly on the stack (x64 only; AAPCS64 differs)
   (amem? g ty) (stru? ty && !(aclass g ty) && !(arm? g) && !(t32? g))
   (asalign g ty) (peep (g 'stag) <>ty 0 @ e (two? e ? <>>e 8))        ; a struct tag's alignment
   (aslots g ty) (aup (tsz g ty) 8 >> 3)                              ; its eightbyte count
   ; a memory-class return: a hidden pointer as the first gp arg, filled and answered by the callee.
   ; AAPCS32 past 4 bytes (but a VFP seat's HFA, carried in s/d), SysV past 16
   (sretm? g ty) (stru? ty && !(cxf32? g ty) && (t32? g && 4 < tsz g ty && !(t32f? g && t32hfa? g ty) || amem? g ty || refm? g ty))
   ; the by-reference class: a composite past 16 bytes (AAPCS64: and no HFA; LP64 riscv and wasm: any) travels
   ; as the address of the caller's own copy, and returns through the buffer x8 (riscv: a0) points at
   (refm? g ty) (stru? ty && 16 < tsz g ty && (rv64? g || (a64? g && !(hfab g ty @ b (flo? b && tsz g ty <= 4 * tsz g b)))))
   ; an AAPCS-VFP homogeneous aggregate: one float base, at most four of it
   (t32hfa? g ty) (hfab g ty @ b (flo? b && tsz g ty <= 4 * tsz g b))
   (srreg g) (a64? g ? 'r8 (argr g 0))              ; where the hidden result pointer rides
   ; the unsigned scalars: the signed twin's width, but a load zero-extends, `>>` is logical,
   ; and compare/divide go unsigned
   (usg? ty) (elem ty '(cchar uchar ushort uint ulong ullong u128))
   ; llong/ullong exist only on t32 (canon folds `long long` to 'long elsewhere): the r0:r1
   ; pair, the one type wider than the accumulator
   (llt? ty) (ty = 'llong || ty = 'ullong)
   ; the signedness is C's (6.3.1.8): a strictly wider signed type
   ; keeps the common type signed. the width is still the accumulator's, not C's
   (ubin w64 ta tb)
    (puac w64 ta tb @ c
       (? (llt? ta || llt? tb) (tusg? c ? 'ullong 'llong)
          (tusg? c) 'ulong 'long))
   ; a 32-bit unsigned result wraps in C and not in a 64-bit register: rbin types every uint binary
   ; op 'uint (so a later op sees the narrow operand) and + - * << also re-narrow. 64-bit only: t32's word is 32
   (u32? g ty) (!(ilp32? g) && ty = 'uint)
   (u32bin? g ta tb)
    (!(ptr? ta || ptr? tb) &&
     !(elem ta '(long ulong llong ullong) ||
       elem tb '(long ulong llong ullong)) &&
     (u32? g ta || u32? g tb))
   ; ..and under -fwrapv a 32-bit signed one: an int op int is typed 'int, + - * sign-extend again
   (wrapv? g) (drop 13 (g 'mo) @ r (two? r && <r))
   (s32? ty) (elem ty '(int short schar char cchar uchar ushort bool))
   (s32bin? g ta tb) (wrapv? g && !(ilp32? g) && s32? ta && s32? tb)
   (rbin g ta tb) (? (u32bin? g ta tb) 'uint (s32bin? g ta tb) 'int (ubin !(ilp32? g) ta tb))
   ; does a 32-bit unsigned result owe its re-narrow? + - * carry out of the word; | ^ with a
   ; sign-extended operand (a signed type, a negative literal) spread its top into the result
   (u32nar? g op ta tb sx) (u32bin? g ta tb && (elem op '(+ - *) || elem op '(| ^) && sx))
   ; the re-narrow a 32-bit result owes: zx4, sx4 or none
   (nar32 g op ta tb sx) (? (u32nar? g op ta tb sx) 'zx4 (s32bin? g ta tb && elem op '(+ - *)) 'sx4 ())
   ; what C calls the literal: an unsuffixed literal that fits is an int, so `uint x * <lit>`
   ; wraps; one too wide is long and the result must not wrap -- hence the range test
   (numty n) (? (fits32 n) 'int (n > 9223372036854775807) 'ulong 'long)   ; past long, only unsigned long holds it
   ; a literal through its written face: -1 is (un neg (num 1)), ~0 (un bnot (num 0)). litv
   ; folds it to (v) | (); numty9 types an operand as C reads the source, else the tuple's type
   (litv e) (e @ ('num n) [n]
                 ('un op x && two? x)
                  (litv x @ r
                     (? (atom? r) ()
                        (op = 'neg) [-<r]
                        (op = 'bnot) [(-<r - 1)])))
   ; a literal wearing a cast coat rides the immediate lanes as its masked value plus the coat's
   ; type; long/ulong pass the 64-bit pattern whole, so t32 refuses them. knum: bare or coated -> (v ty) | ()
   (cnum g e)
    (e @ ('cast ty ('num n && (charm? n || sun? n)))
     (ty @ 'bool [(n != 0) ty]
           ('uchar || 'cchar) [(n & 255) ty]
           'ushort [(n & 65535) ty]
           'uint [(n & 4294967295) ty]
           ('char || 'schar || 'short || 'int)
            (: w (ty @ ('char || 'schar) 8 'short 16 32)
               r (n & ((1 << w) - 1))
               s (r < 1 << (w - 1) ? r (r - (1 << w)))
             [s ty])
           ('long || 'ulong) (ilp32? g ? () [n ty])))
   (knum g e) (e @ ('num n) [n (numty n)] (cnum g e))
   ; a compare or divide takes the common converted type's signedness (puac); a pointer compares
   ; as the unsigned word. znrw: int meets uint at uint, so the 64-bit targets also owe the 32-bit narrow
   (cmpu g ta tb)
    (ptr? ta || ptr? tb || tusg? (puac !(ilp32? g) ta tb))
   ; a case constant converts to the switch control's type (C11 6.8.4.2p5) as the register's
   ; extended pattern. no & here: the 64-bit mask is a big, and love's bitwise ops answer nothing on one
   (cfit g ty v)
    (: m (ilp32? g || !(elem ty '(long ulong llong ullong)) ? 4294967296 18446744073709551616)
       r (v % m)
       u (r < 0 ? (r + m) r)
       (? (usg? ty || ptr? ty) u
          (u < m // 2) u
          (u - m)))
   (scc op unsg) (!unsg ? op (op @ 'lt 'below 'gt 'above 'le 'be 'ge 'ae op))
   (irop op) (op @ '+ 'add '- 'sub '* 'imul '& 'and '| 'or '^ 'xor 'no) ; C op -> IR mnemonic; not one of the six -> 'no
   (negrel op) (op @ 'eq 'ne 'ne 'eq 'lt 'ge 'ge 'lt 'le 'gt 'le)   ; negated: branch-if-false
   (tsz g ty) (tysz (wsize g) (g 'stag) ty)
   (tal g ty) (tyalign (wsize g) (? (ia32? g) 4 (t32? g) 8 16) (g 'stag) ty)
   ; a member's (offset ty) off a struct type, | 'bad
   (fmem g ty name)
    (!(stru? ty) ? 'bad
     (g 'stag <>ty @ e
      (atom? e ? (nolane g "member '\(name)' of an incomplete type '\(<>ty)'")
       (assoc name <e @ f
        (atom? f ? (nolane g "no member '\(name)' in '\(<>ty)'") [<>f <>>f])))))
   (lg2 n) (: (go k v) (v <= 1 ? k (go (k + 1) (v >> 1))) (go 0 n))   ; floor log2, uncapped
   (homable? pty) (ptr? pty || elem pty '(long ulong))       ; an 8-byte gp scalar: what a register home can carry
   ; a home carries narrow gp scalars too, canonically extended (every def re-narrows through cvt,
   ; a param's entry cvt canonicalizes the arrival), so reads are zero forms; a bool home holds 0/1
   (lhomable? ty) (homable? ty || elem ty '(int uint short ushort char schar cchar uchar bool))
   (fsel? g) ((x64? g || a64? g || rv64? g) && !(abl? g 'fsel))   ; the targets whose double lane rides the float file
   (ldop ty) (ty @ ('char || 'schar) 'ld1 'short 'ld2 'int 'ld4
                   ('uchar || 'cchar || 'bool) 'ldu1 'ushort 'ldu2 'uint 'ldu4 'ld)
   (stop ty) (ty @ ('char || 'schar || 'cchar || 'uchar || 'bool) 'st1 ('short || 'ushort) 'st2
                   ('int || 'uint) 'st4 'st)
   ; does every value of integer type a fit b? (a canonical a is then already a canonical b)
   (irng ty) (ty @ 'bool [0 1] ('char || 'schar) [-128 127] ('uchar || 'cchar) [0 255] 'short [-32768 32767] 'ushort [0 65535]
                   'int [-2147483648 2147483647] 'uint [0 4294967295] ())
   (irfit? a b) (: ra (irng a) rb (irng b)
                   (? !(two? rb) 1 !(two? ra) () (<rb <= <ra && >ra <= >rb)))
   ; bool's cvt converts (any nonzero -> 1): every write site runs cvt before its store, so a
   ; bool object holds 0/1 and loads ride a plain ldu1
   (cvt ty r) (ty @ ('char || 'schar) [['sx1 r]] 'short [['sx2 r]] 'int [['sx4 r]]
                    ('uchar || 'cchar) [['zx1 r]] 'ushort [['zx2 r]] 'uint [['zx4 r]]
                    'bool [['cmp r 0] ['set 'ne r]])
   ; a narrow integer answer from a call: SysV and AAPCS64 leave the bits above it to the caller,
   ; so it extends here; lp64's callee sign-extends even an unsigned, which ours reads zero-extended
   (rext g ty) (? (!(x86? g || a64? g || rv64? g) || abl? g 'rext) ()
                  (ty = 'bool) [['zx1 'r0]]
                  (elem ty '(char schar cchar uchar short ushort int uint)) (cvt ty 'r0)
                  ())
   ints9 '(char schar cchar uchar short ushort int uint long ulong llong ullong)
   ; the double lane: a 'double value lives in f0 as a 64-bit double; a float slot is 4 bytes,
   ; so a load widens and a store narrows (fldf/fstf)
   (flo? ty) (ty = 'double || ty = 'float)
   ; a subnormal has no implicit 1 and one fixed exponent, so it takes its own lane; a float
   ; constant must round to its 24 bits (truncation leaves 0.1f a ulp light)
   (mul2 x k) (k <= 1000 ? (x * k 2.0) (mul2 (x * 1000 2.0) (k - 1000)))   ; x * 2^k, split so 2^1074 never needs a double
   (fnear y)                                        ; y >= 0 -> the nearest integer, ties to even
    (: f (int y) r (y - (0.0 + f))
       (? (r > 0.5) (f + 1) (r < 0.5) f (f & 1) (f + 1) f))
   (fenc ax bias p)                                 ; positive finite -> biased-exponent * 2^p + mantissa fraction
    (: mant (p 2)
       emin (1 - bias)                              ; the smallest normal's exponent
       (ax < emin 2.0 ? (fnear (mul2 ax (p - emin)))         ; subnormal: the biased exponent is 0
          (: eu ((: (go e) ((e + 1) 2.0 <= ax ? (go (e + 1)) e)) (int (log ax / log 2.0)))
             e  ((: (go e) (ax < e 2.0 ? (go (e - 1)) e)) eu)
             m  (fnear ((ax / e 2.0 - 1.0) * (0.0 + mant)))
             ; a fraction that rounds up out of its binade carries into the exponent
             ; (0x1.ff..f -> 0x2.0), and at the top that is the infinity pattern C wants
             (m < mant ? ((e + bias) * mant + m) ((e + 1 + bias) * mant)))))
   (fbits x)                                        ; double -> its IEEE-754 bits as the signed i64 pattern
    (? (x = 0.0) (1.0 / x < 0.0 ? -9223372036854775808 0)   ; -0.0 = 0.0, so the reciprocal's sign parts them
       !(x = x) 9221120237041090560                 ; the quiet nan: fenc's climb never ends on a non-finite
       (x + x = x) (x < 0.0 ? -4503599627370496 9218868437227405312)   ; +-inf (1e999 reads as one)
       (fenc (x < 0.0 ? (0.0 - x) x) 1023 52 @ m
          (x < 0.0 ? (m - 9223372036854775808) m)))
   (fbits32 x)                                      ; double -> its IEEE-754 single (u32) bits (a `float` image)
    (? (x = 0.0) (1.0 / x < 0.0 ? 2147483648 0)
       !(x = x) 2143289344
       (x + x = x) (x < 0.0 ? 4286578688 2139095040)
       (: ax (x < 0.0 ? (0.0 - x) x)
          ; under 2^128 fenc's own carry covers the top edge; at or above it the exponent
          ; would wrap, so name the infinity here
          m (ax < 128 2.0 ? (fenc ax 127 23) 2139095040)
          ((x < 0.0) * 2147483648 + m)))
   ; the native single lane: a 'float value rides its f-register as binary32 (C's FLT_EVAL_METHOD 0);
   ; elsewhere a float widens on load and every value is a double
   (f32v? g) (x64? g || a8? g || t32? g || ia32? g)
   (n32? g ty) (ty = 'float && f32v? g)
   ; the double constant pool: one rodata block per distinct pattern, named by the pattern
   ; itself so a label is stable across the build's retries and shared across the unit
   (dbname u) (name ".D\(u)")
   ; the mirror of ul2d: cvttsd2si is signed, so a double at or above 2^63 subtracts 2^63 first
   ; (exact: its ulp is >= 2^11), converts, and xors the bit back. negative/NaN/out of range stay UB
   (dtoul g)
    (: lb (nlab g ".du") ld (nlab g ".dv")
       ['(li r1 0x43e0000000000000) '(movqxr f1 r1)         ; 2^63
          '(ucomisd f0 f1) ['br 'ae lb]
          '(cvttsd2si r0 f0) ['jmp ld]
          ['label lb]
          '(subsd f0 f1)
          '(cvttsd2si r0 f0)
          '(li r1 0x8000000000000000) '(xor r0 r0 r1)
          ['label ld]])
   ; the type of an expression without its emission (arrays undecayed); every accumulator the
   ; walk touched is handed back as it was
   (peekty g env e) ((g 'lopeek) g env e)
   (negcc c) (c @ 'eq 'ne 'ne 'eq 'lt 'ge 'ge 'lt 'le 'gt 'gt 'le 'below 'ae 'ae 'below
                 'be 'above 'above 'be 's 'ns 'ns 's 'p 'np 'np 'p 'vs 'vc 'vs)
   ; n little-endian bytes of a constant (the global initializer image)
   (les n v) (map (i \ (v >> (8 * i)) & 255) ^n)
   (zeros n) (n >= 1 ? (0 . zeros (n - 1)))
   ; a struct that rides registers by the word, which its alignment cannot carry
   (salw? g ty) (a64? g && sal? g && tal g ty < 8)
   (w2 g ty)                                       ; a 9..16B aggregate at r0: its two words' loads into r1
    (salw? g ty ? (: n (tsz g ty) a (tal g ty) [(ldal 'r1 'r0 0 8 a) (ldal 'r1 'r0 8 (n - 8) a)])
       '(((ld r1 r0 0)) ((ld r1 r0 8))))
   ; memcpy/memset with a small constant size lay straight-line, by name (declining where a local
   ; shadows it or the fn is the library's own). no memmove: bcopy interleaves loads and stores
   (meminl g) (8 * wsize g)                          ; the widest expansion: 8 words either way
   (memk g e) (knum g e @ k (two? k ? <k (cfold !(ilp32? g) e @ v (cint? v ? v ()))))
   (memnm? g bi nm) (bi = nm && !(nobi? g nm) || bi = "__builtin_\(nm)")
   ; a spill across a nested sub-eval (which may call): a bare 8-byte push would leave rsp at
   ; 8 mod 16 across the inner call, so a whole 16-byte cell
   (spush r) ['(sub sp sp 16) ['st 'sp 0 r]]
   (spop r)  [['ld r 'sp 0] '(add sp sp 16)]
   ; the pair kit (ilp32 llong/ullong): a 64-bit value rides r0 (lo) : r1 (hi). pairs never enter
   ; the pool or the immediate lanes: every pair op runs the shuttle, r2:r3 the popped left, r12 the scratch
   (pair? g ty) (ilp32? g && llt? ty)
   ; a pair shift by a variable count in r2 (0..63): count >= 32 moves one word across, else the
   ; carry composes through r12 (count 0 skips: a 32-c shift at 0 is unpredictable). v6-M calls the helper
   (pshiftv g kind)
    (? (v6m? g)
       [['call (kind @ 'shl '__aeabi_llsl 'shr '__aeabi_llsr '__aeabi_lasr)]]
       (ia32? g) (pshiftv-ia32 g kind)
    (: lb (nlab g ".pb") ld (nlab g ".pd")
       one (kind @ 'shl '((mov r1 r0) (shlv r1 r2) (li r0 0))
                   'shr '((mov r0 r1) (shrv r0 r2) (li r1 0))
                        '((mov r0 r1) (sarv r0 r2) (sar r1 31)))
       sm (kind @ 'shl
             '((mov r12 r0) (li r3 32) (sub r3 r3 r2) (shrv r12 r3)
                (shlv r1 r2) (or r1 r1 r12) (shlv r0 r2))
             (: hop (kind @ 'shr 'shrv 'sarv)
                ['(mov r12 r1) '(li r3 32) '(sub r3 r3 r2) '(shlv r12 r3)
                   '(shrv r0 r2) '(or r0 r0 r12) [hop 'r1 'r2]]))
       (['(cmp r2 32) ['br 'ae lb] '(cmp r2 0) ['br 'eq ld]]
        + sm + [['jmp ld] ['label lb] '(sub r2 r2 32)]
        + one + [['label ld]])))
   ; the i386 twin: x86 counts in cl, the pair's hi -- so hi parks in r3 and the count takes r1. the
   ; carry word composes through r2 at the complement count, flipped into cl between the two shifts
   (pshiftv-ia32 g kind)
    (: lb (nlab g ".pb") ld (nlab g ".pd")
       big (kind @ 'shl '((mov r3 r0) (shlv r3 r1) (li r0 0))
                   'shr '((mov r0 r3) (shrv r0 r1) (li r3 0))
                        '((mov r0 r3) (sarv r0 r1) (sar r3 31)))
       sm (kind @ 'shl '((mov r2 r0) (shlv r3 r1) (shlv r0 r1) (neg r1) (add r1 r1 32) (shrv r2 r1) (or r3 r3 r2))
             (: hop (kind @ 'shr 'shrv 'sarv)
                ['(mov r2 r3) '(shrv r0 r1) [hop 'r3 'r1] '(neg r1) '(add r1 r1 32) '(shlv r2 r1) '(or r0 r0 r2)]))
       (['(mov r3 r1) '(mov r1 r2) '(cmp r1 32) ['br 'ae lb] '(cmp r1 0) ['br 'eq ld]]
        + sm + [['jmp ld] ['label lb] '(sub r1 r1 32)]
        + big + [['label ld] '(mov r1 r3)]))
   ; llong -> double (VFP converts only through 32 bits): hi rides the U-converter scaled by 2^32,
   ; lo adds exactly, one rounding; the signed face negates the pair in and the double out. v6-M: one call.
   ; sk: a magnitude at or past 2^53 first folds its low 11 bits into bit 11 (sticky), so it fits exactly
   (cvtlld g usg sk)
    (v6m? g ?
       [['call (usg ? '__aeabi_ul2d '__aeabi_l2d)] '(movqxr f0 r0)]
    (: lu (nlab g ".lu") ld (nlab g ".ld")
       (fold lf lk) ['(li r2 2097152) '(cmp r1 r2) ['br 'ae lf] ['jmp lk] ['label lf]   ; hi >= 2^21
                     '(li r3 2047) '(mov r2 r0) '(and r2 r2 r3) '(add r2 r2 r3) '(or r0 r0 r2)
                     '(li r3 -2048) '(and r0 r0 r3) ['label lk]]
       (u2d _) ((!sk ? () (fold (nlab g ".lf") (nlab g ".lk")))
              + '((cvtui2sd f0 r1)
                  (li r2 0) (li r3 1106247680) (movqxr f1 r2)   ; 2^32 (0x41F00000:0)
                  (mulsd f0 f1)
                  (cvtui2sd f1 r0) (addsd f0 f1)))
       (usg ? (u2d 0)                                  ; unsigned: straight through
          (['(cmp r1 0) ['br 'ge lu]] + pneg g
           + (u2d 0)
           + ['(li r2 0) '(li r3 0) '(movqxr f1 r2)           ; 0.0 - d
              '(subsd f1 f0) '(movsd f0 f1) ['jmp ld] ['label lu]]
           + (u2d 0) + [['label ld]]))))
   ; double -> llong, toward zero: peel sign/exponent, rebuild the 53-bit mantissa as a pair, shift
   ; it into place, refix the sign. |d| < 1 answers 0; out of range is UB. v6-M: one runtime call
   (cvtdll g usg)
    (v6m? g ?
       ['(movqrx r0 f0) ['call (usg ? '__aeabi_d2ulz '__aeabi_d2lz)]]
    (: l1 (nlab g ".d1") lr (nlab g ".dr") ls (nlab g ".ds") ld (nlab g ".dd")
       (['(movqrx r0 f0)
           '(mov r2 r1) '(shr r2 31) '(sub sp sp 16) '(st sp 0 r2)   ; park the sign
           '(mov r2 r1) '(shr r2 20) '(li r3 2047) '(and r2 r2 r3)   ; e
           '(li r3 1048575) '(and r1 r1 r3)
           '(li r3 1048576) '(or r1 r1 r3)                                ; mantissa | implicit bit
           '(li r3 1023) '(cmp r2 r3) ['br 'ge l1]
           '(li r0 0) '(li r1 0) '(add sp sp 16) ['jmp ld]              ; |d| < 1 -> 0
           ['label l1]
           '(sub r2 r2 1075) '(cmp r2 0) ['br 'lt lr]]
        + pshiftv g 'shl
        + [['jmp ls] ['label lr]] + (ia32? g ? '((neg r2)) '((li r3 0) (sub r2 r3 r2)))
        + pshiftv g 'shr
        + [['label ls] '(ld r2 sp 0) '(add sp sp 16)
           '(cmp r2 0) ['br 'eq ld]]
        + pneg g + [['label ld]])))
   ; r0:r1 <- 0 - r0:r1 through r2:r3. x86's two-address borrow chain lands on the left
   (pneg g) ('((li r2 0) (li r3 0))
             + (ia32? g ? '((subs r2 r2 r0) (sbc r3 r3 r1) (mov r0 r2) (mov r1 r3)) '((subs r0 r2 r0) (sbc r1 r3 r1))))

   ; the wide kit (i128/u128): hi r2 : lo r0, only on the r0 protocol (never the pool, an immediate
   ; lane or a home). a binop's left parks in a 16-byte sp cell that the carrying ops (a128/s128/m128/mw128/c128) read
   (d128? ty) (ty = 'i128 || ty = 'u128)
   (x64t? g) !(arm? g)
   (w128? g) (x64? g || a64? g || t32w? g)  ; carries the wide pair: x64's rdx:rax, a64's x2:x0, thumb2's r0-r3
   (t32w? g) (t32? g && !(v6m? g))          ; the four-word face: lo r0:r1, hi r2:r3, r12 a shift's count
   (wbin ta tb) (? (d128? ta && d128? tb) (ta = 'u128 || tb = 'u128 ? 'u128 'i128)
                   (d128? ta) ta tb)                ; a word side converts to the wide side's type
   ; a fresh n-byte frame cell -> its (negative) offset; every cell registers in g 'slots
   ; ((off n)..), the frame's object map
   (nslot g n) (: off -(peep g 'off 0 + n)
                  (pin g 'off (peep g 'off 0 + n),
                   pin g 'slots ([off n] . g 'slots),
                   off))
   ; ..one aligned for a type that asks more than the word: the frame base holds 16 (8 under
   ; AAPCS32, -mstack-alignment=8 and i386, whose ebp sits 8 past the boundary; 4 under i386's =4),
   ; so a cell's offset rounds to the ask up to that; past it no fixed offset can
   (fbal g) (? (sa4? g) 4 (t32? g || ia32? g || x86k? g 'sa8) 8 16)
   (naslot g n a)
    (: fb (fbal g) a2 (min a fb)
       (a2 <= 8 ? (nslot g n)
          (: e (aup (peep g 'off 0 + n) a2) off (0 - e)
             (pins g 'off e 'slal 1,
              pin g 'slots ([off n] . g 'slots),
              off))))
   (ntmp g ty) (naslot g (aup (tsz g ty) 8) (tal g ty))
   ; -- the gcc builtins --
   ; popcount of r0 by the swar fold (masks and adds only, so every target), clobbering r1 r2.
   ; the 32-bit form masks first: the word above bit 31 is not ours to count
   ; clz over r0, or the pair r0:r1 at 32 bits when ll
   (clzops g ll)
    (: pre (ll ? () '((shl r0 32)))    ; clz32(x) = clz64(x << 32), clearing upper garbage
       (? (ia32? g)                    ; bsr and xor 31 a word at a time
           (: cz (m16b g + '(15 189 192) + m16b g + '(131 240 31))         ; bsr eax,eax; xor eax,31
              lz (nlab g ".cz") ld (nlab g ".czd")
              (!ll ? [['raw cz]]
                 ['(cmp r1 0) ['br 'eq lz] '(mov r0 r1) ['raw cz] ['jmp ld]
                  ['label lz] ['raw cz] '(add r0 r0 32) ['label ld]]))
          (t32? g && !ll)              ; one word: clz or __clzsi2
           (v6m? g ? '((call __clzsi2)) '((clz r0 r0)))
          (t32? g)                     ; the pair: clz(hi), or 32 + clz(lo) when hi is 0
           (: lz (nlab g ".cz") ld (nlab g ".czd")
              (v6m? g ?   ; no clz on v6-M
                 ['(cmp r1 0) ['br 'eq lz] '(mov r0 r1) '(call __clzsi2) ['jmp ld]
                  ['label lz] '(call __clzsi2) '(add r0 r0 32) ['label ld]]
                 ['(cmp r1 0) ['br 'eq lz] '(clz r0 r1) ['jmp ld]
                  ['label lz] '(clz r0 r0) '(add r0 r0 32) ['label ld]]))
          (rv64? g)                      ; no clz in rv64i: a binary search
           (: ls (map (k \ (nlab g ".cz")) '(0 1 2 3 4 5))
              step (kk \ lb2 \ ['(mov r2 r0) ['shr 'r2 (64 - kk)] '(cmp r2 0) ['br 'ne lb2]
                                 ['add 'r1 'r1 kk] ['shl 'r0 kk] ['label lb2]])
              (pre + '((li r1 0))
               + step 32 (ls 0) + step 16 (ls 1) + step 8 (ls 2)
               + step 4 (ls 3) + step 2 (ls 4) + step 1 (ls 5)
               + '((mov r0 r1))))
          (pre + (a64? g ? '((raw (0 16 192 218)))                    ; clz x0, x0
                    '((raw (72 15 189 192 72 131 240 63)))))))   ; bsr rax,rax; xor rax,63
   ; ctz over r0, or the pair r0:r1 on i386 when ll
   (ctzops g ll)
    (? (ia32? g)                     ; bsf: lo, or hi + 32 when lo is 0
        (: tz (m16b g + '(15 188 192))
           lz (nlab g ".tz") ld (nlab g ".tzd")
           (!ll ? [['raw tz]]
              ['(cmp r0 0) ['br 'eq lz] ['raw tz] ['jmp ld]
               ['label lz] '(mov r0 r1) ['raw tz] '(add r0 r0 32) ['label ld]]))
       (t32? g)
        (v6m? g ? '((call __ctzsi2))
           '((li r1 0) (sub r1 r1 r0) (and r0 r0 r1)     ; x & -x, then 31 - clz
             (clz r0 r0) (li r1 31) (sub r0 r1 r0)))
       (rv64? g)
        (: ls (map (k \ (nlab g ".tz")) '(0 1 2 3 4 5))
           step (kk \ mk \ lb2 \ [['li 'r3 mk] '(mov r2 r0) '(and r2 r2 r3) '(cmp r2 0)
                                   ['br 'ne lb2] ['add 'r1 'r1 kk] ['shr 'r0 kk] ['label lb2]])
           ('((li r1 0))
            + step 32 4294967295 (ls 0) + step 16 65535 (ls 1)
            + step 8 255 (ls 2) + step 4 15 (ls 3)
            + step 2 3 (ls 4) + step 1 1 (ls 5)
            + '((mov r0 r1))))
       (a64? g && ll) '((raw (0 0 192 218 0 16 192 218)))   ; rbit x0,x0; clz x0,x0
       (a64? g) '((raw (0 0 192 90 0 16 192 90)))           ; rbit w0,w0; clz w0,w0
       '((raw (72 15 188 192))))                            ; bsf rax,rax: REX.W serves both widths
   ; a pair's bytes reversed at 32 bits: the words trade places
   (bs64ops g)
    (ia32? g ? ('((mov r2 r0) (mov r0 r1) (mov r1 r2))
                + [['raw (m16b g + [15 200] + m16b g + [15 201])]])   ; bswap eax; bswap ecx
       ('((sub sp sp 16) (st sp 0 r0) (mov r0 r1)) + bsw32
        + '((st sp 4 r0) (ld r0 sp 0)) + bsw32
        + '((mov r1 r0) (ld r0 sp 4) (add sp sp 16))))
   ; a pair's popcount at 32 bits: each word's, summed
   (pc64ops g)
    ('((sub sp sp 16) (st sp 0 r1)) + popops g 1
     + '((st sp 4 r0) (ld r0 sp 0)) + popops g 1
     + '((ld r1 sp 4) (add r0 r0 r1) (add sp sp 16)))
   ; a checked add, sub or mul over r0 and r1: r0 the result, r1 the overflow bit
   (ovfops g bi)
    (: rx (x64? g ? [72] (m16b g))   ; x64 widens with REX.W; i386 is the word already
       opb (rx + (? (bi = "__builtin_add_overflow") '(1 200)      ; add rax,rcx
                    (bi = "__builtin_sub_overflow") '(41 200)     ; sub rax,rcx
                    '(15 175 193)))                               ; imul rax,rcx
       (? !(arm? g)
           [['raw (opb + '(15 144 193) + rx + '(15 182 201))]]   ; op; seto cl; movzx rcx,cl
          !(bi = "__builtin_mul_overflow")
           [[(bi @ "__builtin_add_overflow" 'adds 'subs) 'r0 'r0 'r1] '(set vs r1)]
          (v6m? g)                          ; no smull: __aeabi_lmul on the widened words,
           (spush 'r3 +                     ; then hi vs lo>>31. r3 = &t, saved
            '((mov r2 r1) (mov r1 r0) (sar r1 31)
              (mov r3 r2) (sar r3 31) (call __aeabi_lmul)
              (mov r2 r0) (sar r2 31) (subs r1 r1 r2) (set ne r1)) +
            spop 'r3)
          (t32? g)                          ; smull, then hi vs lo>>31
           '((smull r0 r2 r0 r1) (mov r12 r0) (sar r12 31)
             (subs r1 r2 r12) (set ne r1))
          (: lo (nlab g ".vo") l2 (nlab g ".vd")
             [['mulo 'r0 'r0 'r1 'r2 lo] '(li r1 0) ['jmp l2]
              ['label lo] '(li r1 1) ['label l2]])))
   (popops g w32)
    (: fold (k \ ['(mov r1 r0) ['shr 'r1 k] '(add r0 r0 r1)])
       (w32 ? ((ilp32? g ? () '((li r2 4294967295) (and r0 r0 r2)))
               + '((li r2 1431655765) (mov r1 r0) (shr r1 1) (and r1 r1 r2) (sub r0 r0 r1)
                   (li r2 858993459) (mov r1 r0) (shr r1 2) (and r1 r1 r2) (and r0 r0 r2) (add r0 r0 r1)
                   (li r2 252645135) (mov r1 r0) (shr r1 4) (add r0 r0 r1) (and r0 r0 r2))
               + fold 8 + fold 16 + '((li r2 63) (and r0 r0 r2)))
          ('((li r2 6148914691236517205) (mov r1 r0) (shr r1 1) (and r1 r1 r2) (sub r0 r0 r1)
             (li r2 3689348814741910323) (mov r1 r0) (shr r1 2) (and r1 r1 r2) (and r0 r0 r2) (add r0 r0 r1)
             (li r2 1085102592571150095) (mov r1 r0) (shr r1 4) (add r0 r0 r1) (and r0 r0 r2))
           + fold 8 + fold 16 + fold 32 + '((li r2 127) (and r0 r0 r2)))))
   ; -- gcc's __atomic and __sync families. atomop names the form from the spelling -> (kind ..) | ();
   ; the generic (non-_n) forms take their operands by address and are refused by name --
   (aop o) (o @ "add" 'add "sub" 'sub "and" 'and "or" 'or "xor" 'xor "nand" 'nand ())
   (atomop bi)
    (bi @ ("__atomic_" + s)
            (s @ "load_n" ['load] "store_n" ['store] "exchange_n" ['rmw 'set 'old] "compare_exchange_n" ['cas]
                 "test_and_set" ['tas] "clear" ['clear] "thread_fence" ['fence] "signal_fence" ['sfence]
                 ("always_lock_free" || "is_lock_free") ['lockfree]
                 ("load" || "store" || "exchange" || "compare_exchange") ['generic]
                 ("fetch_" + o) (aop o @ k (k = () ? () ['rmw k 'old]))
                 (o + "_fetch") (aop o @ k (k = () ? () ['rmw k 'new]))
                 ())
          ("__sync_" + s)
            (s @ "synchronize" ['fence] "val_compare_and_swap" ['vcas] "bool_compare_and_swap" ['bcas]
                 ("fetch_and_" + o) (aop o @ k (k = () ? () ['rmw k 'old]))
                 (o + "_and_fetch") (aop o @ k (k = () ? () ['rmw k 'new]))
                 ())
          ())
   ; the bytes of a little-endian word, and a thumb2 32-bit instruction (its high halfword first)
   (le2 x) [(x & 255) (x >> 8 & 255)]
   (le4 x) (le2 (x & 65535) + le2 (x >> 16))
   (tw x) (le2 (x >> 16) + le2 (x & 65535))
   ; the widths an exclusive loop lays: riscv's lr/sc are word and doubleword only, armv7-m has
   ; no doubleword exclusive, armv6-m none at all (gcc calls libatomic there); wasm is one thread
   (awidths g) (? (wasm? g) '(1 2 4 8) (v6m? g) () (rv64? g) '(4 8) (ilp32? g) '(1 2 4) '(1 2 4 8))
   (amw g pt) (? (ptr? pt) (wsize g) (elem pt '(char schar cchar uchar bool)) 1 (elem pt '(short ushort)) 2
                 (elem pt '(int uint)) 4 (elem pt '(long ulong llong ullong)) (tsz g pt) ())
   ; a full fence, and a compiler-only one (a raw form nothing moves across)
   (afence g) (? (wasm? g) () (x86? g) [['raw '(15 174 240)]] (a64? g) [['raw (le4 0xD5033BBF)]]
                 (rv64? g) [['raw (le4 0x0330000F)]] [['raw (tw 0xF3BF8F5F)]])
   (abar g) (? (wasm? g) () (x86? g) [['raw '(144)]] (a64? g) [['raw (le4 0xD503201F)]]
               (rv64? g) [['raw (le4 19)]] [['raw (le2 0xBF00)]])
   (stw w) (w @ 1 'st1 2 'st2 4 'st4 'st)
   ; riscv's R and B shapes
   (rvr f7 rs2 rs1 f3 rd) (f7 << 25 | rs2 << 20 | rs1 << 15 | f3 << 12 | rd << 7 | 0x33)
   (rvbr f3 rs1 rs2 off) (: i (off & 0x1FFF)
                            ((i >> 12 & 1) << 31 | (i >> 5 & 63) << 25 | rs2 << 20 | rs1 << 15 | f3 << 12
                             | (i >> 1 & 15) << 8 | (i >> 11 & 1) << 7 | 0x63))
   ; a read-modify-write: pointer r1, operand r2 -> the old value r0, the new r3. one exclusive
   ; loop (x64 a lock cmpxchg loop) whose branch back is counted here
   (armw g w op)
    (? (wasm? g)
        ([[(uldop w) 'r0 'r1 0] '(mov r3 r0)]
         + (op @ 'set '((mov r3 r2)) 'nand '((and r3 r3 r2) (li r2 -1) (xor r3 r3 r2)) [[op 'r3 'r3 'r2]])
         + [[(stw w) 'r1 0 'r3]])
       (x64? g)
        (: ld (w @ 1 '(15 182 1) 2 '(15 183 1) 4 '(139 1) '(72 139 1))     ; movzx/mov rax, [rcx]
           body ('(72 137 195)                                              ; mov rbx, rax
                 + (op @ 'add '(72 1 211) 'sub '(72 41 211) 'and '(72 33 211) 'or '(72 9 211)
                         'xor '(72 49 211) 'nand '(72 33 211 72 247 211) 'set '(72 137 211))
                 + [240] + (w @ 2 [102] 8 [72] ()) + [15 (w = 1 ? 176 177) 25])   ; lock cmpxchg [rcx], rbx
           ; rbx is named once outside the raw, so the callee-saved save sees it written
           ['(li r3 0) ['raw (ld + body + [117 (256 - (#body + 2))])]])     ; jne back
       (ia32? g)                                                            ; x64's loop at 32 bits: no REX
        (: o (m16b g) (r x) (o + x)
           ld (m16a g + o + (w @ 1 '(15 182 1) 2 '(15 183 1) '(139 1)))
           body (r '(137 195)
                 + (op @ 'add (r '(1 211)) 'sub (r '(41 211)) 'and (r '(33 211)) 'or (r '(9 211))
                         'xor (r '(49 211)) 'nand (r '(33 211) + r '(247 211)) 'set (r '(137 211)))
                 + [240] + m16a g + acw g w + [15 (w = 1 ? 176 177) 25])
           ['(li r3 0) ['raw (ld + body + [117 (256 - (#body + 2))])]])
       (a64? g)
        (: lx ((w @ 1 0x085FFC00 2 0x485FFC00 4 0x885FFC00 0xC85FFC00) | 32)          ; ldaxr x0, [x1]
           sx ((w @ 1 0x0800FC00 2 0x4800FC00 4 0x8800FC00 0xC800FC00) | 4 << 16 | 32 | 3)   ; stlxr w4, x3, [x1]
           ops (op @ 'add [0x8B020003] 'sub [0xCB020003] 'and [0x8A020003] 'or [0xAA020003] 'xor [0xCA020003]
                     'nand [0x8A020003 0xAA2303E3] 'set [0xAA0203E3])
           body ([lx] + ops + [sx])
           [['raw (catall (map le4 (body + [(0x35000000 | ((0x80000 - #body) & 0x7FFFF) << 5 | 4)   ; cbnz w4, back
                                            0xD5033BBF])))]])
       (rv64? g)
        (: f3 (w = 4 ? 2 3)
           lr (2 << 27 | 3 << 25 | 11 << 15 | f3 << 12 | 10 << 7 | 0x2F)             ; lr.aqrl a0, (a1)
           sc (3 << 27 | 3 << 25 | 13 << 20 | 11 << 15 | f3 << 12 | 14 << 7 | 0x2F)   ; sc.aqrl a4, a3, (a1)
           ops (op @ 'add [(rvr 0 12 10 0 13)] 'sub [(rvr 32 12 10 0 13)] 'and [(rvr 0 12 10 7 13)]
                     'or [(rvr 0 12 10 6 13)] 'xor [(rvr 0 12 10 4 13)]
                     'nand [(rvr 0 12 10 7 13) (0xFFF << 20 | 13 << 15 | 4 << 12 | 13 << 7 | 0x13)]
                     'set [(12 << 15 | 13 << 7 | 0x13)])
           body ([lr] + ops + [sc])
           [['raw (catall (map le4 (body + [(rvbr 1 14 0 (-4 * #body))])))]])       ; bnez a4, back
       (: lx (w @ 1 0xE8D10F4F 2 0xE8D10F5F 0xE8510F00)                ; ldrex{b,h} r0, [r1]
          sx (w @ 1 0xE8C13F44 2 0xE8C13F54 0xE8413400)                ; strex{b,h} r4, r3, [r1]
          ops (op @ 'add [0xEB000302] 'sub [0xEBA00302] 'and [0xEA000302] 'or [0xEA400302] 'xor [0xEA800302]
                    'nand [0xEA000302 0xEA6F0303] 'set [0xEA4F0302])
          body (catall (map tw ([lx] + ops + [sx])) + le2 0x2C00)      ; cmp r4, #0
          dmb (tw 0xF3BF8F5F)
          [['raw (dmb + body + le2 (0xD100 | (256 - (#body + 4) // 2) & 255) + dmb)]]))   ; bne back
   ; an exchange: value r0, pointer r1 -> the old value r0, r2 r3 spent
   ; a64's flush of [r0, r1): dc cvau, ic ivau per line, strides off ctr_el0. it writes r2 r3 r9 r15
   (a64flush g)
    (: lb (nlab g ".ccd") db (nlab g ".ccdd")
       li9 (nlab g ".cci") di (nlab g ".ccid")
     ['(raw (34 0 59 213))          ; mrs x2, ctr_el0
       '(li r9 15)
       '(and r15 r2 r9)
       '(li r3 4)
       '(raw (111 32 207 154))      ; lsl x15, x3, x15 -- isize
       '(shr r2 16)
       '(and r2 r2 r9)
       '(raw (98 32 194 154))       ; lsl x2, x3, x2 -- dsize
       '(sub r3 r2 1)
       '(not r3)
       '(and r9 r0 r3)            ; begin & ~(dsize-1)
       ['label lb]
       '(cmp r9 r1)
       ['br 'ae db]
       '(raw (41 123 11 213))       ; dc cvau, x9
       '(add r9 r9 r2)
       ['jmp lb]
       ['label db]
       '(raw (159 59 3 213))        ; dsb ish
       '(sub r3 r15 1)
       '(not r3)
       '(and r9 r0 r3)            ; begin & ~(isize-1)
       ['label li9]
       '(cmp r9 r1)
       ['br 'ae di]
       '(raw (41 117 11 213))         ; ic ivau, x9
       '(add r9 r9 r15)
       ['jmp li9]
       ['label di]
       '(raw (159 59 3 213))          ; dsb ish
       '(raw (223 63 3 213))]) ; isb
   (axchg g w)
    (? (wasm? g) [[(w @ 4 'ldu4 'ld) 'r2 'r1 0] [(stw w) 'r1 0 'r0] '(mov r0 r2)]
       (a64? g)
        (nlab g ".ts" @ lb
           [['label lb]
            ['raw (w @ 4 '(34 252 95 136) '(34 252 95 200))]   ; ldaxr w2/x2, [x1]
            ['raw (w @ 4 '(32 124 3 136) '(32 124 3 200))]     ; stxr w3, w0/x0, [x1]
            '(cmp r3 0) ['br 'ne lb] '(mov r0 r2)])
       (rv64? g)
        [['raw (w @ 4 '(47 165 165 12) '(47 181 165 12))]]      ; amoswap.w/d.aq a0,a0,(a1)
       (t32? g)                                                 ; ldrex r2 / strex r3, r0, [r1] until it holds, dmb
        (: body (tw 0xE8512F00 + tw 0xE8410300 + le2 0x2B00)    ; cmp r3, #0
           [['raw (body + le2 (0xD100 | (256 - (#body + 4) // 2) & 255) + tw 0xF3BF8F5F)]
            '(mov r0 r2)])
       [['raw ((m16? g ? [103 102] ()) + (w @ 4 '(135 1) '(72 135 1)))]])   ; xchg eax/rax, (rcx)
   ; a lock's release: zero in r0, pointer r1
   (arel g w)
    (? (a64? g) [['raw (w @ 4 '(32 252 159 136) '(32 252 159 200))]]   ; stlr w0/x0, [x1]
       (t32? g) ([['raw (tw 0xF3BF8F5F)]] + [['st4 'r1 0 'r0]])                ; dmb sy, then the store
       (wasm? g) [[(w @ 4 'st4 'st) 'r1 0 'r0]]
       (rv64? g) ('((raw (15 0 16 3))) +                                       ; fence rw,w
                  [[(w = 4 ? 'st4 'st) 'r1 0 'r0]])
       [[(w @ 4 'st4 'st) 'r1 0 'r0]])
   ; a compare-and-swap: expected r0 (widened as the loop's load widens), pointer r1, desired r2 ->
   ; the old value r0, success (0/1) r2
   (acas g w)
    (? (wasm? g)
        (nlab g ".cas" @ f
           [[(uldop w) 'r3 'r1 0] '(cmp r3 r0) ['br 'ne f] [(stw w) 'r1 0 'r2] ['label f]
            '(cmp r3 r0) '(set eq r2) '(mov r0 r3)])
       (x86? g)                                         ; no REX below eight bytes: i386 lays the same
        ['(li r3 0) ['raw ([240] + m16a g + acw g w + [15 (w = 1 ? 176 177) 17]          ; lock cmpxchg [rcx], rdx
                           + '(15 148 195) + m16b g + '(15 182 219))]                    ; sete bl; movzx ebx, bl
         '(mov r2 r3)]
       (+ (? (a64? g)
              (: lx ((w @ 1 0x085FFC00 2 0x485FFC00 4 0x885FFC00 0xC85FFC00) | 32 | 3)          ; ldaxr x3, [x1]
                 sx ((w @ 1 0x0800FC00 2 0x4800FC00 4 0x8800FC00 0xC800FC00) | 4 << 16 | 32 | 2)   ; stlxr w4, x2, [x1]
                 [['raw (catall (map le4 [lx 0xEB00007F 0x54000061 sx                 ; cmp x3, x0; b.ne out
                                          (0x35000000 | (0x80000 - 4) << 5 | 4) 0xD5033BBF]))]])   ; cbnz w4, back
             (rv64? g)
              (: f3 (w = 4 ? 2 3)
                 lr (2 << 27 | 3 << 25 | 11 << 15 | f3 << 12 | 13 << 7 | 0x2F)             ; lr.aqrl a3, (a1)
                 sc (3 << 27 | 3 << 25 | 12 << 20 | 11 << 15 | f3 << 12 | 14 << 7 | 0x2F)   ; sc.aqrl a4, a2, (a1)
                 [['raw (catall (map le4 [lr (rvbr 1 13 10 12) sc (rvbr 1 14 0 -12)]))]])   ; bne a3, a0, out; bnez a4, back
             (: lx (w @ 1 0xE8D13F4F 2 0xE8D13F5F 0xE8513F00)                ; ldrex{b,h} r3, [r1]
                sx (w @ 1 0xE8C12F44 2 0xE8C12F54 0xE8412400)                ; strex{b,h} r4, r2, [r1]
                dmb (tw 0xF3BF8F5F)
                [['raw (dmb + tw lx + le2 0x4283 + le2 0xD103 + tw sx + le2 0x2C00 + le2 0xD1F7 + dmb)]]))
          '((cmp r3 r0) (set eq r2) (mov r0 r3))))
   ; the expected value as the loop's own load leaves it: riscv's lr.w sign-extends, the
   ; exclusive loads elsewhere zero-extend (x64's cmpxchg reads the low w bytes)
   (aexp g w) (? (x86? g || w = 8) () (rv64? g && !(wasm? g)) (w = 4 ? '((sx4 r0))) [[(w @ 1 'zx1 2 'zx2 'zx4) 'r0]])
   ; i386 answers a float on x87's st(0) and gen keeps it in f0 (xmm0): an 8-byte cell under esp
   ; carries it across, each way, raw so no pass reads the cell (16-bit: 67 on memory, 66 on lea)
   (x87raw g fl in?)
    (: a (m16? g ? [103] ()) o (m16? g ? [102] ())
       lea (\ k (a + o + [141 100 36 k]))                          ; lea esp,[esp+k]
       (in? ? (lea 248 + a + [(fl ? 217 221) 28 36]                 ; fstp dword|qword [esp]
               + a + [(fl ? 243 242) 15 16 4 36] + lea 8)            ; movss|movsd xmm0,[esp]
          (lea 248 + a + [(fl ? 243 242) 15 17 4 36]                 ; movss|movsd [esp],xmm0
           + a + [(fl ? 217 221) 4 36] + lea 8)))                    ; fld dword|qword [esp]
   ; C99 complex: a two-member struct. arithmetic parks each side in a double-pair temp (the other
   ; may call), f0..f3 carry (a.re a.im b.re b.im), and a fresh temp's address answers
   (cxb ty) (<>ty = "__cplx_float" ? 'float 'double)
   (cxf32? g ty) (ia32? g && gcplx? ty && cxb ty = 'float)     ; i386: a float complex returns on edx:eax
   ; a VLA ('varr elt dim-expr [idx]): a local's idx keys g 'vslots -> (ptrslot sizeslot);
   ; a pointee carries just the expr, re-evaluated at each scale site
   (gvarr? ty) (two? ty && <ty = 'varr)
   (varel ty) <>ty                             ; the element type (const-sized)
   (varn ty) <>>ty                             ; the dim expression (an AST)
   ; reader ops, not `at`: the laws cat gen.l without holo, where `at` is unbound
   (varix ty) <>>>ty                                ; a decl's slot index (4-long only)
   ; rbx is callee-saved and gen uses it (callr park, va_arg): csframe saves it at slot -8 when written
   pro4 '((push r4) (mov r4 sp))                    ; the x64 frame link (unframe strips it)
   sav3 '(st r4 -8 r3)
   epi '((mov sp r4) (pop r4) (ret))
   ; a64: lr pushed before fp, no rbx slot; the sp hop rides lea since mov to/from sp is ORR (31 is xzr)
   pro-a64 '((push lr) (push fp) (lea fp sp 0))
   epi-a64 '((lea sp fp 0) (pop fp) (pop lr) (ret))
   ; thumb2 vararg: drops the r0-r3 block the prologue pushed
   epi-t32va '((lea sp fp 0) (pop fp) (pop lr) (add sp sp 16) (ret))
   epi-rv-va '((lea sp fp 0) (pop fp) (pop lr) (add sp sp 64) (ret))                   ; drop the a0-a7 block
   ; soft-double (sp64, an SP-only FPU): f64 ops lower to __aeabi_* helpers through a 32-byte sp cell over
   ; r0-r3 (above sp: an irq frame owns below); moon stages doubles only in f0/f1/f15
   sf-bin {'addsd '__aeabi_dadd 'subsd '__aeabi_dsub
           'mulsd '__aeabi_dmul 'divsd '__aeabi_ddiv}
   ; v6-M singles too (r0, r1 the right); sp64's fpu keeps them native
   sf-bin1 {'addss '__aeabi_fadd 'subss '__aeabi_fsub 'mulss '__aeabi_fmul 'divss '__aeabi_fdiv}
   ; cc -> (helper sense): 'eq negates (le = !(a>b), lt = !(a>=b), unordered-true like the flags)
   (sf-cc cc) (cc @ 'gt '(__aeabi_dcmpgt ne)
                    'ge '(__aeabi_dcmpge ne)
                    'eq '(__aeabi_dcmpeq ne)
                    'ne '(__aeabi_dcmpeq eq)
                    'le '(__aeabi_dcmpgt eq)
                    'lt '(__aeabi_dcmpge eq))
   (sf-ccs h) (h @ '__aeabi_dcmpgt '__aeabi_fcmpgt '__aeabi_dcmpge '__aeabi_fcmpge '__aeabi_fcmpeq)   ; ..a single's twin
   ; v6-M: pop reaches r0..r7/pc, not lr, so return is pop pc; r4 is the bottom base (t16slots)
   epi-t16 '((lea sp fp 0) (pop r4) (pop fp) (pop pc))
   ; v6-M vararg: pop pc can't drop the r0-r3 block after it, so lr pops into r3 (bit0 keeps thumb)
   epi-t16va '((lea sp fp 0) (pop r4) (pop fp) (pop r3) (add sp sp 16) (jmpr r3))
   ; exit tests: a jmp out of the fn is an exit too, but only the label table tells (xjmp?)
   (retx? f) (two? f && (<f = 'ret || <f = 'pop && <>f = 'pc))
   (xit? f) (retx? f || two? f && <f = 'jmpr)
   (xjmp? f t)                                      ; a jmp/br to no label in t: a sibcall
    (: tg (? !(two? f) () (<f = 'jmp) <>f (<f = 'br) <>>f ())
       (tg && peep t tg 'no = 'no))
   (qtwin r)                                        ; ['rN+1], a 32-bit pair's high half | ()
    (: (go l) (? !(two? >l) ()
                 (<l = r) [<>l]
                 (go >l))
       (go qfile))
   ; rdsp's arms by op: an op takes the first arm that names it, as the chain of tests it
   ; replaces read them, so one lookup answers where up to forty tests ran. laid once a unit
   ; (g 'rdarms): the arms call fns the book lays later, which a bake-time value cannot
   (rg1 x) (charm? x ? () [x])
   (snm k) (0 = k & 1 ? (xmmreg (k // 2)) (name "f\(16 + k // 2)"))   ; thumb2sp's single S[k] by name
   ; thumb2sp's odd singles f16..f31, f(16+n) the high half of fN, and each one's other half
   (rafo g r) (peep (g 'rafo @ () (foldl (t \ i \ (pin t (name "f\(16 + i)") (name "f\(i)"), pin t (name "f\(i)") (name "f\(16 + i)"))) {} ^16 @ t (pin g 'rafo t, t))
                       t t) r ())
   (lofo? x) (nom? x && elem x '(f16 f17 f18 f19 f20 f21 f22 f23 f24 f25 f26 f27 f28 f29 f30 f31))
   (rdmk _)
    (: t {}
       (arm ops a) (map (o \ (peep t o 'none = 'none ? (pin t o a) 0)) ops)
       _ (arm '(li fimm) (g \ f \ [() [<>f] 1]))
       _ (arm '(ucom0) (g \ f \ [[<>f] () ()]))
       _ (arm '(fli) (g \ f \ [() [<>f <>>f] ()]))
       _ (arm '(addss3 subss3 mulss3 divss3) (g \ f \ [[<>>f <>>>f] [<>f] ()]))
       _ (arm '(ldsspi ldpi4) (g \ f \ [[<>>f] [<>f <>>f] ()]))
       _ (arm '(stsspi stpi4) (g \ f \ [[<>f <>>f] [<>f] ()]))
       _ (arm '(mov) (g \ f \ [[<>>f] [<>f] 1]))
       _ (arm aluops (g \ f \ (<>f @ 'sp [() () ()]      ; sp motion touches no gp register
                               [(rg1 <>>f + rg1 <>>>f) [<>f] 1])))
       _ (arm flagops (g \ f \ [(rg1 <>>f + rg1 <>>>f) [<>f] ()]))
       _ (arm '(push) (g \ f \ [[<>f] () ()]))
       ; v6-M's pop pc is an exit: it reads what it owes back, or the return value dies
       _ (arm '(pop) (g \ f \ (<>f = 'pc ? [(lvret g + csregs g) [<>f] ()] [() [<>f] ()])))
       _ (arm '(shl shr sar rol ror ror4) (g \ f \ [[<>f] [<>f] 1]))
       _ (arm ldops9 (g \ f \ [[<>>f] [<>f] 1]))
       _ (arm gstops (g \ f \ [[<>f <>>>f] () ()]))
       _ (arm stxops (g \ f \ [[<>f <>>f (f 5)] () ()]))
       _ (arm fxops (g \ f \ [[<>>f <>>>f] () ()]))
       _ (arm fstxops (g \ f \ [[<>f <>>f] () ()]))
       _ (arm '(ldsdl) (g \ f \ [() () ()]))
       _ (arm siops (g \ f \ [[<>f] () ()]))
       _ (arm '(cmpm) (g \ f \ [([<>f] + rg1 <>>>f) () ()]))
       _ (arm '(cmprm) (g \ f \ [[<>f <>>f] () ()]))
       _ (arm '(alurm) (g \ f \ [[(f 3) (f 4)] [(f 3)] 1]))
       _ (arm '(alu4) (g \ f \ [(rg1 (f 3) + rg1 (f 4)) [(f 2)] 1]))
       _ (arm '(shl4) (g \ f \ [[<>f] [<>f] 1]))
       _ (arm leaops (g \ f \ [[<>>f] [<>f] 1]))
       _ (arm xops (g \ f \ [[<>>f <>>>f] [<>f] 1]))
       _ (arm x4ops (g \ f \ [[<>f <>>f <>>>f] [<>f] 1]))
       _ (arm m4ops (g \ f \ [[<>f <>>f] [<>f] 1]))
       _ (arm '(la laa) (g \ f \ [() [<>f] 1]))
       _ (arm '(set) (g \ f \ [() [<>>f] 1]))
       _ (arm '(cmov) (g \ f \ [[<>>f <>>>f] [<>>f] 1]))
       _ (arm '(cmp test) (g \ f \ [(rg1 <>f + rg1 <>>f) () ()]))
       _ (arm unops (g \ f \ [[<>f] [<>f] 1]))
       ; vmov Df, Rlo, Rlo+1 names only the low half: qtwin spells the high one, else a dead-store sweep
       ; kills a live read
       _ (arm '(movqxr) (g \ f \ [([<>>f] + (ilp32? g ? (qtwin <>>f) ())) () ()]))
       _ (arm '(movqrx) (g \ f \ [() ([<>f] + (ilp32? g ? (qtwin <>f) ())) 1]))
       _ (arm '(movrrq) (_ \ f \ [[(f 3)] [(f 1) (f 2)] 1]))
       _ (arm '(movqrr) (_ \ f \ [[(f 2) (f 3)] [(f 1)] 1]))
       ; movsnxr's s-slot write is a side effect nothing here sees: never droppable
       _ (arm '(movsnxr) (g \ f \ [[<>>f] (sp64? g ? [(snm <>f)] ()) ()]))
       _ (arm '(movsnrx) (g \ f \ [(sp64? g ? [(snm <>>f)] ()) [<>f] 1]))
       _ (arm '(cvtsi2sd cvtui2sd cvtsi2ss cvtui2ss movdxr) (g \ f \ [[<>>f] () ()]))
       _ (arm '(cvttsd2si cvttsd2ui cvttss2si cvttss2ui) (g \ f \ [() [<>f] ()]))
       _ (arm '(movdrx) (g \ f \ [() [<>f] 1]))
       _ (arm fldops (g \ f \ [[<>>f] () ()]))
       _ (arm fstops (g \ f \ [[<>f] () ()]))
       _ (arm xmmops (g \ f \ [() () ()]))
       ; a divide writes what its encoding does: x86's rax beside the dest (rdx it saves itself), the
       ; arm and riscv pair the dest and a rem's temp, v6m's loop r0..r3
       _ (arm divops (g \ f \ [(rg1 <>>f + rg1 <>>>f)
                               (? (x86? g) [<>f 'r0]
                                  (a64? g || rv64? g || t32? g && !(v6m? g)) (<>f . (#f = 5 ? [(f 4)] ()))
                                  '(r0 r1 r2 r3))
                               ()]))
       _ (arm llops (g \ f \ ['(r0 r1 r2 r3) '(r0 r1 r2 r3) ()]))
       _ (arm wmops (g \ f \ [[(f 3) (f 4)] [<>f <>>f] 1]))
       _ (arm '(mla) (g \ f \ [[<>>f <>>>f (f 4)] [<>f] 1]))
       _ (arm '(clz) (g \ f \ [[<>>f] [<>f] 1]))
       _ (arm '(jmpt) (g \ f \ [[<>f] () ()]))
       ; the frame's markers, laid out by csframe: a restore defines the callee-saved file, so a body's
       ; last write to one is dead unless read; neither is pure, so neither drops
       _ (arm '(saves) (g \ f \ [() () ()]))
       _ (arm '(rests) (g \ f \ [() (filter (r \ r != fbase g) (csregs g)) ()]))
       ; x64's wide multiply also writes rax (rdx it saves itself)
       _ (arm '(mulh umulh) (g \ f \ [[<>>f <>>>f] ([<>f] + (x86? g ? '(r0) ())) ()]))
       ; a variable shift defines only its dest (x64's count is cl, never moved into): a claimed r1
       ; def would make the pair lane's carry-in look dead
       _ (arm vshops (g \ f \ [[<>f <>>f] [<>f] ()]))
       ; the wide kit: the pair rides r2:r0 unspelled; x64 spends rcx in
       ; m128r/c128r and s128r answers through the park; the four-word face carries all four, r12 scratch
       _ (arm '(sx128) (g \ f \ (t32w? g ? ['(r1) '(r2 r3) 1] ['(r0) '(r2) 1])))
       _ (arm '(n128 inc128 dec128 shl128 shr128 sar128)
              (g \ f \ (t32w? g ? ['(r0 r1 r2 r3) '(r0 r1 r2 r3 r12) 1] ['(r0 r2) '(r0 r2) 1])))
       _ (arm '(mw128r) (g \ f \ [['r0 <>f] '(r0 r2) 1]))
       _ (arm '(a128r s128r m128r)
              (g \ f \ [(['r0 'r2 <>f] + rg1 <>>f) ('(r0 r2) + (x64? g ? (<f @ 's128r [<>f <>>f] 'm128r '(r1) ()) ())) 1]))   ; a128r's hi may be 0
       _ (arm '(c128r) (g \ f \ [['r0 'r2 <>>f <>>>f] (x64? g ? '(r0 r1 r2) '(r0)) 1]))
       t)
   (rdsp g f)                                         ; -> [reads defs pure?] | 'bar
    (: t (g 'rdarms @ () (: t9 (rdmk 0) _ (pin g 'rdarms t9) t9) t8 t8)
       (peep t <f 'bar @ 'bar 'bar a (a g f)))
   ; a64 renames by position: x4 is also an arg register, so only the base slot's r4 becomes fp
   a4base (: t (foldl (t \ o \ pin t o 2) {} (ldops9 + fldops + xops + fxops + leaops + '(cmprm)))
           t (foldl (t \ o \ pin t o 1) t (stops9 + stxops + fstxops + siops + '(cmpm)))
         (pin t 'alurm 4))
   (a4ize fs)
    (: (go (f . u))
        (: bp (two? f ? (peep a4base <f -1) -1)
         (. (0 <= bp && f bp == 'r4 ? (reop f bp 'fp) f) (go u)))
     (go fs))
   ; v6-M: ld/st encode only positive immediates and sp moves around calls, so r4 is a second base
   ; at the frame bottom: an fp-negative slot becomes r4 + (frame + off). after a4ize
   (t16reb f i bp fr)
    (!(two? f) ? f
       ((? (i = bp) 'r4 (i = bp + 1) (fr + <f) <f) . t16reb >f (i + 1) bp fr))
   (t16slots (f . u) fr)
       (: bp (two? f ? (peep a4base <f -1) -1)
          (. ((bp >= 0 && f bp == 'fp && f (bp + 1) < 0) ? (t16reb f 0 bp fr) f)
                (t16slots u fr)))
   ; v6m has no MOVW/MOVT: (la Rd lbl) becomes a literal-pool load. runs last
   (t16la (f . u)) ((atom? f || <f != 'la ?  [f]
                      ['(align 4) ['lapool <>f] ['raw [['fix 4 'abs32 <>>f 0]]]])
                     + t16la u)
   (epim? fs es) (? !(two? es) 1                  ; the next forms are exactly es
                    !(two? fs) ()
                    (<fs = <es && epim? >fs >es))
   ; lw: a frame lea since the last call (`return f(&x)`) keeps that call a call. a join label
   ; between call and epilogue: the jump lands before it, label + epi stay for the other arm
   (lbl-epi? (f . u) ej) (two? f && <f = 'label ? (epim? u ej || lbl-epi? u ej))
   ; a join label then a jmp to an epilogue label is still ret position
   (lbl-jmp? (f . u) el)
    (two? f ? (<f @ 'label (lbl-jmp? u el)
                    ('jmp && el <>f) 1))
   ; elabs: the labels leading to the epilogue; one whose region is a jmp to one counts too and
   ; may point forward, so elabsx iterates to a fixpoint
   (jmp-el? (('jmp x) . _) t) (t x)
   (elabs fs t ej) (!(two? fs) ? t
                      (<fs @ f
                         (two? f && <f = 'label &&
                          (epim? >fs ej ||
                           lbl-epi? >fs ej || jmp-el? >fs t) ?
                            (pin t <>f 1),
                          elabs >fs t ej)))
   (elabsx fs t ej) (: n #(keys t)
                       t2 (elabs fs t ej)
                       (#(keys t2) = n ? t2 (elabsx fs t2 ej)))
   (butret es) (two? >es ? (<es . butret >es))          ; the epilogue minus its ret
   (sibjmp g f ejx)                                 ; ejx: the epilogue this tail owes
    ; riscv's jal reaches only +-1MB: the tail call goes by la into the park, after the restores
    (? (rv64? g && <f = 'call)
       (butret (peep g 'epi epi-a64) + [['la (pkr g) <>f] ['jmpr (pkr g)]])
       (<f = 'call) (butret ejx + [['jmp <>f]])
       ; ejx, not epi-a64: a cs-granted build pins its restores into g 'epi, and t32's vararg epilogue adds 16
       (a64? g) (butret ejx + '((jmpr r15)))                   ; the a64 epilogue never touches x15
       (rv64? g) (butret (peep g 'epi epi-a64) + [['jmpr (pkr g)]])     ; riscv: the park (t4) survives the epilogue
       (t32? g) (butret ejx + [['jmpr (pkr g)]])             ; thumb2: the park r12 survives the epilogue
       (ia32? g) ('((mov r1 r3)) + butret ejx + '((jmpr r1)))    ; i386: ecx, caller-saved and no result's
       (<>f = 'r10) (butret ejx + '((jmpr r10)))              ; lo.l's park, clear of the epilogue
       ('((mov r10 r3)) + butret ejx + '((jmpr r10))))            ; park first: the x64 epilogue reloads r3
   ; a tail call's result extension may go: on x64 and a64 every caller extends
   (skipxt g l) (? (two? l && (x64? g || a64? g) && two? <l && elem <<l '(sx1 sx2 sx4 zx1 zx2 zx4) && <>(<l) = 'r0) >l l)
   (sibs g (f . r) lw el ej crf)
    (: lw2 (two? f && <f = 'lea && <>>f = 'r4 || lw)
       cand (!lw2 && two? f && (<f = 'call && two? >f ||
                                <f = 'callr && (<>f = <>crf || x64? g && <>f = 'r10)) &&
             (!(g 'fescv) || must? f))
       rr (cand ? (skipxt g r) r)
       (? (cand && epim? rr ej)
           (sibjmp g f ej + sibs g (drop #ej rr) () el ej crf)
          (cand && lbl-epi? rr ej)
           (sibjmp g f ej + sibs g rr () el ej crf)
          (cand && (<rr @ nx (two? nx && <nx = 'jmp && peep el <>nx ())))
           (sibjmp g f ej + sibs g >rr () el ej crf)
          (cand && lbl-jmp? rr el)
           (sibjmp g f ej + sibs g rr () el ej crf)
          ((must? f ? (scare 'musttail-not-a-tail [(g 'fn) f]) 0),
           f . sibs g r (two? f && elem <f '(call callr callm raw) ? () lw2) el ej crf)))       ; raw: a builtin splice consumes its address like a call
   ; musttail: a pre-slotted ret (clay's (ret e PRE)) marks its call 'must; sibs jumps or scares
   (must? f) (two? f && elem <f '(call callr callm) && elem 'must >>f)
   (anymust? (a . u)) (must? a || anymust? u)
   ; a musttail is its author's word nothing reads the frame past the jump, so a value escape
   ; still jumps; a frame address laid as an arg still refuses (lw), best-effort
   (sibcall g fs) (? (nsib? g) (anymust? fs ? (nolane g "a musttail call, and -fno-optimize-sibling-calls") fs)
                     (g 'fesc || g 'fescv && abl? g 'fescv || v6m? g)   ; v6m's pop-pc epilogue can't restore lr for a jmp
                      (anymust? fs ? (scare 'musttail-escape (g 'fn)), fs)
                     (peep g 'epi epi @ ej
                      (sibs g fs () (elabsx fs {} ej) ej ['callr (pkr g)])))

   ; frame elision (frees rbp, the glaze's Ip): slots re-address off sp at off + K9 + D, K9 = K + the
   ; link bytes, so a call at a 16-multiple D keeps push r4's alignment; scan proves D at every label
   uoff (: t (foldl (t \ o \ pin t o 3) {} (ldops9 + fldops + leaops + '(cmprm)))
           t (foldl (t \ o \ pin t o 5) t (xops + fxops))
           t (foldl (t \ o \ pin t o 2) t (stops9 + siops + '(cmpm)))
           t (foldl (t \ o \ pin t o 4) t (stxops + fstxops))
         (pin t 'alurm 5))
   ; rebuild f with operand i9 replaced
   (reop f i9 v) (: (go (a . u) i) ((i = i9 ? v a) . go u (i + 1)) (go f 0))
   ; riscv slot rebase: fp links at the frame bottom (c.ld/c.sd want unsigned offsets), so fp-relative
   ; displacements gain `frame`; at uoff's position, not bp + 1 (an index sits there). after a4ize
   (rvreb f i up fr)
    (!(two? f) ? f
       ((i = up ? (charm? <f ? (fr + <f) (scare 'rv-slot-nonum f)) <f)
          . rvreb >f (i + 1) up fr))
   (rvslots fs fr)
    (two? fs ?
       (: f <fs
          bp (two? f ? (peep a4base <f -1) -1)
          up (two? f ? (peep uoff <f -1) -1)
          (. (bp >= 0 && up >= 0 && f bp = 'fp ? (rvreb f 0 up fr) f)
                (rvslots >fs fr))))
   ; a64 slots off sp: past the prologue's (sub sp sp F), sp = fp - F - d, d the straight-line parks
   ; open, so fp+o is sp+F+d+o: 4095 scaled units where fp's negative side has ldur's 256 bytes.
   ; a body moving sp any other way keeps fp. last, after bprot
   a64sc {'ld 8 'st 8 'ldsd 8 'stsd 8 'ld4 4 'ldu4 4 'st4 4 'ldss 4 'stss 4
          'ld2 2 'ldu2 2 'st2 2 'ld1 1 'ldu1 1 'st1 1 'lea 0 'lean 0}
   (a64w sc o)                                     ; holo's word count for base+o
    (: u (o < 0 ? (0 - o) o)
       (? (sc = 0 ? (u <= 4095) (0 <= o && o % sc = 0 && o // sc <= 4095 || -256 <= o && o <= 255)) 1
          (u <= 4095 || u % 4096 = 0) 2
          3))
   (a64sp g fs)
    (cz g 'a64sp fs (: (sw? f) (two? f && (elem <f '(push pop) || f 1 = 'sp && nelem <f (stops9 + siops + stxops + fstxops)))
       (spk? f k) (two? f && <f = k && f 1 = 'sp && f 2 = 'sp && charm? (f 3))
       (ctl? f) (two? f && elem <f '(label br br8 cbr tbr jmp jmpm jmpr jmpt ret))
       (reb f F d) (: bp (peep a4base <f -1) up (peep uoff <f -1) sc (peep a64sc <f -1)
                      (? (sc < 0 || bp < 0 || up < 0 || f 1 = 'sp || f bp != 'fp || !(charm? (f up))) f
                         (F + d + f up @ n
                            (0 <= n && a64w sc n < a64w sc (f up) ? (reop (reop f bp 'sp) up n) f))))
       ; F the frame once the prologue stands, d the parks open; () when sp moves any other way
       (go l pv F d acc)
        (? !(two? l) (d = 0 ? (rev acc) ())
           (<l @ f
              (? (spk? f 'sub && pv = '(lea fp sp 0)) (d = 0 && (!F || F = f 3) ? (go >l f (f 3) 0 (f . acc)) ())
                 (f = '(lea sp fp 0)) (d = 0 && two? >l && <>l = '(frpop) ? (go >l f F d (f . acc)) ())
                 (spk? f 'sub) (F ? (go >l f F (d + f 3) (f . acc)) ())
                 (spk? f 'add) (F && f 3 <= d ? (go >l f F (d - f 3) (f . acc)) ())
                 (sw? f) ()
                 (ctl? f && d != 0) ()
                 (go >l f F d ((F ? (reb f F d) f) . acc)))))
       (!(a64? g) || abl? g 'a64sp || g 'hasasm ? fs (go fs () () 0 () @ r (two? r ? r fs)))))
   ; three-register twins: (mov d s) (shl d c) = (lsl d s c), likewise shr, sar, the extends
   ; and not. never an sp source: ubfm and orn read 31 as xzr, thumb's forms are unpredictable
   ; on it. last, with a64sp
   a64tw {'shl 'lsl 'shr 'lsr 'sar 'asr 'not 'mvn 'zx1 'uxtb 'zx2 'uxth 'zx4 'uxtw 'sx1 'sxtb 'sx2 'sxth 'sx4 'sxtw}
   t2tw {'shl 'lsl 'shr 'lsr 'sar 'asr 'not 'mvn 'zx1 'uxtb 'zx2 'uxth 'sx1 'sxtb 'sx2 'sxth}
   (twmv g fs)
    (cz g 'twmv fs (? (!(a64? g || t32? g && !(v6m? g)) || abl? g 'twmv) fs
       (: tws (a64? g ? a64tw t2tw)
          (go l acc)
           (? !(two? l) (rev acc)
              (: f <l h (two? >l ? <>l ())
                 tw (two? h ? (peep tws <h ()) ())
                 ; thumb2: a move or load into a register that only passes it on lands where it goes
                 cp (? !(t32? g && two? f && two? h && <h = 'mov && #h = 3 && h 2 = f 1 && h 1 != f 1) ()
                       !(atom? (h 1) && !(charm? (h 1)) && h 1 != 'sp) ()
                       !(<f = 'mov && #f = 3 && atom? (f 2) && !(charm? (f 2)) || elem <f ldops9) ()
                       (dies? g (f 1) >>l) (<f . (h 1) . >>f))
                 ; thumb2: a right shift masked to a low run is one ubfx; a mask the shift already
                 ; cleared goes. bf is the shift's (source count)
                 bf (? !(t32? g && two? f && <f = 'and && #f = 4 && f 1 = f 2 && charm? (f 3) && two? acc) ()
                       (: a <acc m (f 3)
                          (? !(0 < m && 0 = m & (m + 1) && two? a && a 1 = f 1) ()
                             (<a = 'lsr && #a = 4 && charm? (a 3) && 0 < a 3 < 32) [(a 2) (a 3)]
                             (<a = 'shr && #a = 3 && charm? (a 2) && 0 < a 2 < 32) [(a 1) (a 2)]
                             ())))
                 (? (two? f && <f = 'mov && #f = 3 && tw && h 1 = f 1 && atom? (f 2) && !(charm? (f 2)) && f 2 != 'sp)
                    (go >>l (([tw (h 1) (f 2)] + >>h) . acc))
                    (two? cp) (go (cp . >>l) acc)
                    (two? bf) (lg2 (f 3 + 1) @ w
                                 (32 <= <>bf + w ? (go >l acc)
                                    (go >l (['ubfx (f 1) <bf <>bf w] . >acc))))
                    (go >l (f . acc)))))
          (go fs ()))))
   ; a word's zx4/sx4 lays nothing on a 32-bit arm: gone before the folds, so they part no pair
   (t2nx g fs) (cz g 't2nx fs (t32? g ? (filter (f \ !(two? f && elem <f '(zx4 sx4))) fs) fs))
   ; the x64 frame prologue heads fs
   (pro4? fs) (epim? >fs pro4)
   ; riscv: a body naming no sp, fp or lr and making no call (wasm: may call) drops its prologue
   ; and every exit's teardown
   (rvunframe g fs)
    (cz g 'rvunframe fs (!(rv64? g && !(g 'fpin) && 5 < #fs && fs 1 = '(push lr) && fs 2 = '(push fp) && fs 4 = '(lea fp sp 0)) ? fs
       (: sf (fs 3) K (sf 3)
          tear [['lea 'sp 'fp K] '(pop fp) '(pop lr)]
          (deep? x) (two? x ? (vany deep? x) (elem x '(sp fp lr)))
          ; a riscv call clobbers lr; a wasm call leaves every local but the answers
          (bare? f) (!(two? f) || !(elem <f (wasm? g ? '(push pop raw) '(call callr callm push pop raw))) && !(vany deep? >f))
          (strip l) (? !(two? l) ()
                       (take 3 l = tear) (strip (drop 3 l))
                       !(bare? <l) 'no
                       (strip >l @ r (r = 'no ? 'no (<l . r))))
          (!(two? sf && <sf = 'sub && sf 1 = 'sp && sf 2 = 'sp && charm? K) ? fs
             (strip (drop 5 fs) @ r (r = 'no ? fs (<fs . r)))))))
   (unframe g fs)
    (cz g 'unframe fs (kfp? g ? fs (: a64 (a64? g)
       fb (a64 ? 'fp 'r4)
       pro (a64 ? (epim? >fs pro-a64) (pro4? fs))
       sf (fs (a64 ? 4 3))
       K (two? sf && <sf = 'sub && <>sf = 'sp && <>>sf = 'sp && charm? <>>>sf ? <>>>sf)
       body0 (drop (a64 ? 5 4) fs)
       ; x64: a callr sib's (mov r3 X) .. (mov r10 r3) is one mov at the unpark when nothing between
       ; touches r3 or rewrites X; then the rbx save drops with the frame
       sv3 (!a64 && body0 0 = sav3)
       wind ('(mov li) + leaops + xops + aluops + ldops9)
       wina (wind + gstops + '(cmp test))
       (squeeze (f . r))
        (!(two? f && <f = 'mov && <>f = 'r3 && <>>f != 'sp) ?
           (f . squeeze r)
           (: X <>>f
              (win w n)                        ; forms between park and unpark -> count | 'no
               (!(two? w) || 8 < n ? 'no
                  (<w @ g2
                     (? (g2 = '(mov r10 r3)) n
                        !(two? g2) 'no
                        (elem 'r3 >g2) 'no
                        (nelem <g2 wina) 'no
                        (elem <g2 wind && <>g2 = X) 'no
                        (win >w (n + 1)))))
              k (win r 0)
              (k @ 'no (f . squeeze r)
                 (: (take w n) (n < 1 ? (['mov 'r10 X] . squeeze (drop 1 w))
                                  (<w . take >w (n - 1)))
                    (take r k)))))
       ; ..and when the squeeze leaves r3 named only by csframe's restores, they drop too
       body (: b2 (sv3 ? (drop 1 body0) body0)
               b3 (a64 ? b2 (squeeze b2))
               rl3 '(ld r3 r4 -8)
               (sv3 && !(vany (f \ f != rl3 && two? f && elem 'r3 >f) b3) ? (filter (f \ f != rl3) b3) b3))
       (epi3? l9)                                    ; l9 opens with the teardown -> its length | ()
        (butret (a64 ? epi-a64 epi) @ e3 (epim? l9 e3 ? #e3))
       (clean? f2 bp)                                ; fb only at its base slot; a64 lr never
        (: (go e i) (!(two? e) ? 1
                       (<e @ x
                          (? (x = fb && !(i = bp)) ()
                             (a64 && x = 'lr) ()
                             (go >e (i + 1)))))
           (go f2 0))
       labt {}                               ; label -> the D every arrival agrees on
       (scan l D vs r3f live)                        ; -> 'no | (needs-sub r3-in-use)
        (!(two? l) ? [vs r3f]
           (epi3? l @ n3
              (n3 ? (scan (drop n3 l) 0 vs r3f live)
                 (<l @ f
                    (? !(two? f) (scan >l D vs r3f live)
                       (<f = 'label)
                        (peep labt <>f 'no9 @ d9
                           (d9 != 'no9 ?
                              (live && !(D = d9) ? 'no (scan >l d9 vs r3f 1))
                              (: D2 (live ? D 0)
                                 (pin labt <>f D2,
                                  scan >l D2 vs r3f 1))))
                       (<f = 'jmp)
                        (peep labt <>f 'no9 @ d9
                           (? (d9 = 'no9) (pin labt <>f D, scan >l D vs r3f ())
                              !(D = d9) 'no
                              (scan >l D vs r3f ())))
                       (<f = 'br)
                        (peep labt <>>f 'no9 @ d9
                           (? (d9 = 'no9) (pin labt <>>f D, scan >l D vs r3f live)
                              !(D = d9) 'no
                              (scan >l D vs r3f live)))
                       (xit? f)
                        (scan >l D vs (r3f || !a64 && elem 'r3 >f) ())
                       (elem <f '(push pop) || (<f = 'raw && !(elem 'fsafe f))) 'no
                       (elem <f '(call callr callm))                 ; sp is as call-stable as r4, and
                        ; K9 (8 mod 16) + a 16-multiple D hand the ABI what push r4 did
                        (? a64 'no                                ; bl clobbers lr: the link stays
                           !(0 = (D & 15)) 'no
                           (scan >l D 1 (r3f || elem 'r3 >f) live))
                       (spadj? f && <f = 'sub) (scan >l (D + <>>>f) vs r3f live)
                       (spadj? f && <f = 'add)
                        (D - <>>>f < 0 ? 'no (scan >l (D - <>>>f) vs r3f live))
                       (elem <f '(sub add mov lea lean) && <>f = 'sp) 'no
                       (peep a4base <f -1 @ bp
                          (!(clean? f bp) ? 'no
                             (scan >l D
                                   ((0 <= bp && f bp == fb) ? 1 vs)
                                   (r3f || !a64 && elem 'r3 >f)
                                   live))))))))
       vr (pro && charm? K ? (scan body 0 () () 1) 'no)
       (? (g 'fpin) fs                              ; the frame's address was taken
          (vr = 'no || !a64 && <>vr && !sv3) fs    ; r3 in use with no save to ride
          (: r3f (!a64 && <>vr)
             vs (<vr || r3f)                         ; the save is a slot: r3f forces the sub
             K9 (K + (? a64 32 (ia32? g) 4 8))           ; the dropped link: a64's record, i386's 4-byte ebp, x64's 8
             (radj f2 bp op9 D)
              (reop (reop f2 bp 'sp) op9 (f2 op9 + K + D))
             (rw l D)
              (two? l ?
                 (epi3? l @ n3
                    (n3 ? ((vs ? [['add 'sp 'sp (K9 + D)]] (0 < D ? [['add 'sp 'sp D]]))
                           + rw (drop n3 l) 0)
                       (<l @ f
                          (? !(two? f) (f . rw >l D)
                             (<f = 'label) (f . rw >l (peep labt <>f D))
                             (spadj? f && <f = 'sub) (f . rw >l (D + <>>>f))
                             (spadj? f && <f = 'add) (f . rw >l (D - <>>>f))
                             (peep a4base <f -1 @ bp
                                (. ((0 <= bp && f bp == fb) ?
                                         (radj f bp (peep uoff <f -1) D)
                                         f)
                                      (rw >l D))))))))
             body2 (r3f ? (sav3 . body) body)
             (<fs . (vs ? (['sub 'sp 'sp K9] . rw body2 0) (rw body2 0))))))))

   ; i386: an address laid only to be accessed through at once becomes that access by absolute
   ; address ('rip (sym k)), when nothing reads the address after
   (absg g fs)
    (cz g 'absg fs (!(ia32? g) || abl? g 'absg ? fs
       (: lds '(ld ld1 ld2 ld4 ldu1 ldu2 ldu4)
          sts '(st st1 st2 st4)
          sis '(si si1 si2 si4)
          (sym f) (<f = 'la ? [(f 2) 0] [(f 2) (f 3)])
          ; the register is written before it is read again, in a straight run
          (dead? x l n)
           (? (n < 1 || !(two? l)) ()
              (: f <l
                 (? (!(two? f) || elem <f '(label br jmp jmpr jmpm ret raw sys call callr callm)) ()
                    (rdsp g f @ rd
                       (? (rd = 'bar) ()
                          (elem x <rd) ()
                          (elem x <>rd) 1
                          (dead? x >l (n - 1)))))))
          ; the first form that names x, past ones that do not: (gap form rest) | ()
          (seek x l n gap)
           (? (n < 1 || !(two? l)) ()
              (: f <l
                 (? (!(two? f) || elem <f '(label br jmp jmpr jmpm ret raw sys call callr callm)) ()
                    (rdsp g f @ rd
                       (? (rd = 'bar) ()
                          (elem x <rd || elem x <>rd) [(rev gap) f >l]
                          (seek x >l (n - 1) (f . gap)))))))
          (go l)
           (? !(two? l) l
              (: f <l
                 k (two? f && elem <f '(la laa) ? (seek (f 1) >l 8 ()))
                 (? !(two? k) (f . go >l)
                    (: x (f 1) s9 (sym f) gap <k nx <>k rest <>>k
                       (? ((elem <nx lds) && (nx 2 = x) && charm? (nx 3) && ((nx 1 = x) || dead? x rest 24))
                           (gap + ([<nx (nx 1) 'rip [<s9 (s9 1 + nx 3)]] . go rest))
                          ((elem <nx sts) && (nx 1 = x) && charm? (nx 2) && (nx 3 != x) && dead? x rest 24)
                           (gap + ([<nx 'rip [<s9 (s9 1 + nx 2)] (nx 3)] . go rest))
                          ((elem <nx sis) && (nx 1 = x) && charm? (nx 2) && dead? x rest 24)
                           (gap + ([<nx 'rip [<s9 (s9 1 + nx 2)] (nx 3)] . go rest))
                          (f . go >l))))))
          (go fs))))
   ; i386 -Os: the callee-saved saves ride push and pop. the pushes take the frame's top words,
   ; which nothing else reads (the rbx slot and the saves' own); every exit restores alike
   (pushsv g fs)
    (cz g 'pushsv fs (? (!(ia32? g && osz? g) || abl? g 'pushsv || !(two? fs) || !(two? >fs)) fs
       (: lab <fs pro <>fs
          N (pro @ ('sub 'sp 'sp n) (charm? n ? n ()) ())
          ; the saves straight after the frame: [(off reg)..] and the forms past them
          (svs l acc) (? (two? l && (<l @ ('st 'sp k r) (charm? k && elem r (cspool g)) ()) && #acc < 3)
                          (svs >l ([(<l 2) (<l 3)] . acc))
                          [(rev acc) l])
          sv (charm? N ? (svs >>fs ()) [() ()])
          sl <sv body <>sv
          offs (map cap sl)
          ; an exit: the restores in any order, the frame back, ret
          nsv #sl
          (exit? l) (: lds (take nsv l) tl (drop nsv l)
                       (all (f \ (f @ ('ld r 'sp k) (elem [k r] sl) ())) lds && #lds = nsv &&
                        two? tl && <tl = ['add 'sp 'sp N] && two? >tl && <(>tl) = '(ret)))
          (spoff f) (: (go i) (? (#f <= i) () (f i = 'sp) i (go (i + 1))) (go 1))
          ; the body is ours to rewrite: a straight walk of the sp depth, every frame access clear of
          ; the top two words and the save slots, every ret an exit
          (ok? l d) (? !(two? l) 1
                       (: f <l
                          (? (!(two? f)) (ok? >l d)
                             (<f = 'label) (ok? >l 0)
                             (elem <f '(jmpr jmpm callr callm)) ()
                             (<f = 'ret) ()
                             (exit? l) (ok? (drop (nsv + 2) l) d)
                             (f @ ('sub 'sp 'sp k) (charm? k) ()) (ok? >l (d + f 3))
                             (f @ ('add 'sp 'sp k) (charm? k) ()) (ok? >l (d - f 3))
                             (elem <f '(push pushl)) (ok? >l (d + 4))
                             (<f = 'pop) (ok? >l (d - 4))
                             (: i (spoff f)
                                (? !(charm? i) (ok? >l d)
                                   (: o (i + 1 < #f ? (f (i + 1)))
                                      e (charm? o ? (o - d))
                                      (? (!(charm? e) || (N - 4 * nsv <= e && e < N) || elem e offs) ()
                                         (ok? >l d))))))))
          (rw l) (? !(two? l) ()
                    (exit? l) ((N = 4 * nsv ? () [['add 'sp 'sp (N - 4 * nsv)]]) + map (x \ ['pop (x 1)]) (rev sl) + ['(ret)] + rw (drop (nsv + 2) l))
                    (<l . rw >l))
          (? (!(charm? N) || N < 4 * nsv || nsv < 1 || !(ok? body 0)) fs
             ([lab] + map (x \ ['push (x 1)]) sl + (N = 4 * nsv ? () [['sub 'sp 'sp (N - 4 * nsv)]]) + rw body)))))
   ; the fall-through's answer: 0, for main's sake -- a void fn has none to give
   (fz0 g nm) (<(peep (g 'sigs) nm ['long ()]) = 'void ? () '((li r0 0)))
   ; -Os: the straight runs that end in a ret, or a pop of pc, and share a tail keep one copy of it,
   ; under a label; the others jump there. two forms at least, so a bare ret never trades for a jump
   (rjoin g fs)
    (cz g 'rjoin fs (? !(osz? g) fs
       (: (bar? f) (!(two? f) || elem <f '(label br jmp jmpr ret raw jmpm))
          (ret? f) (two? f && (<f = 'ret || <f = 'popm && elem 'pc (f 1)))
          blks (: (go l i run acc)
                  (? !(two? l) (rev acc)
                     (ret? <l) (go >l (i + 1) () ([i (rev (<l . run))] . acc))
                     (bar? <l) (go >l (i + 1) () acc)
                     (go >l (i + 1) (<l . run) acc))
                  (go fs 0 () ()))
          (csuf a b) (: (go x y n) (? (two? x && two? y && <x = <y) (go >x >y (n + 1)) n)
                        (go (rev a) (rev b) 0))
          b0 <blks
          k (two? blks && two? >blks ? (foldl (m \ b \ min m (csuf (b0 1) (b 1))) 1000000 >blks) 0)
          (k < 2 ? fs
             (: lj (nlab g ".ej")
                le (<(rev blks))
                ends (map cap blks)
                (go l i) (? !(two? l) ()
                            (i + k - 1 = <le) (['label lj] . (<l . go >l (i + 1)))
                            (elem (i + k - 1) ends) (['jmp lj] . go (drop k l) (i + k))
                            (<l . go >l (i + 1)))
                (go fs 0))))))
   ; x64: (ld X b o) .. (jmpr X) -> (jmpm b o), the load sinking past forms that leave X and b alone
   ; (b's own add folds into o). never off sp or fp, and X is no argument register
   (jmpm g fs)
    (cz g 'jmpm fs (!(x64? g) || x86k? g 'thk || x86k? g 'thki || x86k? g 'ibr ? fs
       (: ar (argr g)
          (sink X b o l acc n)                        ; -> [forms-between o' rest] | ()
           (!(two? l) || 8 < n ? ()
              (<l @ f
                 (? !(two? f) ()
                    (<f = 'jmpr) (<>f = X && fits32 o ? [(rev acc) o >l])
                    !(elem <f '(mov ld add sub pop li lea)) ()
                    (rdsp g f @ rd
                       (? (rd = 'bar || elem X <rd || elem X <>rd) ()
                          !(elem b <>rd) (sink X b o >l (f . acc) (n + 1))
                          (charm? (f 3) && f 1 = b && f 2 = b)
                           (<f @ 'add (sink X b (o - f 3) >l (f . acc) (n + 1))
                                 'sub (sink X b (o + f 3) >l (f . acc) (n + 1))
                                 ())
                          ())))))
          (go l) (!(two? l) ? l
                    (: f <l
                       k (two? f && <f = 'ld && charm? (f 3) && nelem (f 2) '(sp r4) && nelem (f 1) ar ?
                            (sink (f 1) (f 2) (f 3) >l () 0))
                       (two? k ? (<k + (['jmpm (f 2) (k 1)] . go (k 2)))
                          (f . go >l))))
          (go fs))))
   ; x64's kernel thunks by name, and -mretpoline's laid at the site, on i386 too: the target over
   ; the return address, the speculated return caught in a pause loop
   (thunks g fs)
    (cz g 'thunks fs (: thk (x86k? g 'thk) rth (x86k? g 'rth) cs (x86k? g 'cs) thki (x86ki? g)
       (via op r) (: s (intern "__x86_indirect_thunk_\(x86rn r)")
                     ((cs && elem r '(r7 r8 r9 r10 r11 r12 r13 r14) ? ['(raw (46))]) + [[op s]]))
       (rjmp r) (nlab g ".rp" @ L0 (nlab g ".rp" @ L1
                  [['call L1] ['label L0] '(raw (243 144)) '(raw (15 174 232)) ['jmp L0]
                   ['label L1] ['st 'sp 0 r] '(ret)]))
       (rcall r) (nlab g ".rp" @ L2 (nlab g ".rp" @ L3 ([['jmp L2] ['label L3]] + rjmp r + [['label L2] ['call L3]])))
       (one f) (? !(two? f) [f]
                  (thki && <f = 'callr) (rcall <>f)
                  (thki && elem <f '(jmpr jmpt)) (rjmp <>f)
                  (thk && <f = 'callr) (via 'call <>f)
                  (thk && elem <f '(jmpr jmpt)) (via 'jmp <>f)
                  (rth && f = '(ret)) [['jmp '__x86_return_thunk]]
                  [f])
       (thk || rth || thki ? (catmap one fs) fs)))
   ; an else of one move lays before its test, and the then writes over it: (cmp ..) (br cc E) then
   ; (jmp J) (label E) (li|mov r x) (label J) -> (li|mov r x) (cmp ..) (br cc J) then (label J). the
   ; then must write r before any read of it or any exit, and E have no other reader
   (kelse g fs)
    (cz g 'kelse fs (t32? g ? fs
       (: (cnt t x) (? (two? x) (foldl cnt t x) (atom? x) (pin t x (peep t x 0 + 1)) t)
          refs (foldl (t \ f \ (two? f && <f = 'label ? t (cnt t f))) {} fs)
          (mv? f) (f @ ('li r _) (nelem r '(sp fp)) ('mov r s) (nelem r '(sp fp)) _ ())
          els (: (go l t) (l @ (('jmp J) . ('label E) . f . ('label J2) . _)
                                (go >l (J = J2 && mv? f && refs E = 1 ? (pin t E [J f]) t))
                               (_ . u) (go u t)
                               _ t)
                 (go fs {}))
          dn {}
          (dead? l r n) (l @ (f . u) (? (64 < n || !(two? f)) ()
                                         (<f = 'label) (dead? u r (n + 1))
                                         (rdsp g f @ 'bar ()
                                            (rs . ds . _) (? (elem r rs) () (elem r ds) 1 (dead? u r (n + 1)))))
                        _ ())
          (ok? c f u) (elem <c '(cmp test) &&
                       (rdsp g c @ 'bar ()
                          (rs . ds . _) (: r <>f (nelem r rs && nelem r ds && (<f = 'li || nelem (f 2) ds) && dead? u r 0))))
          (hoist l) (l @ (c . ('br cc E) . u)
                          (els E @ (J f) (ok? c f u ? (pin dn E 1, [f c ['br cc J] u]))
                                   _ ())
                         _ ())
          (go l acc)
           (? !(two? l) (rev acc)
              (hoist l @ (f c b u) (go u ([b c f] + acc))
                         _ (l @ (('jmp _) . ('label E) . _ . u) (dn E ? (go u acc) (go >l (<l . acc)))
                                (f . u) (go u (f . acc)))))
          (go fs ()))))
   ; an early exit lays last: (br cc L) run (label L) -> (br !cc K) (label L) .., (label K) run after
   ; the fn. the run may hold labels, no branch; a cold L (__builtin_expect(c, 0)) lets the run past
   ; its last test of L branch, and one that falls into L jumps there. a lone (jmp X) run is the br, to X.
   ; an else behind its then's (jmp J) lays last too when it looks the colder: a call the then has none
   ; of, or twice the then's length. the then then falls into J, the else jumps back
   (tailarm g fs)
    (cz g 'tailarm fs (t32? g ? fs                                            ; thumb's short branches stay put
       (: hot (g 'hot) cold (g 'cold)
          labs (map (f \ f 1) (filter (f \ two? f && <f = 'label) fs))
          (term? f) (two? f && elem <f '(jmp jmpr jmpm ret))
          (exit? f) (two? f && (elem <f '(jmpr jmpm ret) || <f = 'jmp && nelem (f 1) labs))
          (run l L acc n c)                                   ; -> [run rest] | ()
           (!(two? l) || (c ? 96 48) < n ? ()
              (<l @ f
                 (? !(two? f) (run >l L (f . acc) (n + 1) c)
                    (<f = 'label && <>f = L) (? !(two? acc) ()
                                                (c ? (term? <acc) (exit? <acc)) [(rev acc) l]
                                                c [(rev (['jmp L] . acc)) l]
                                                ())
                    (elem <f '(jmpt align)) ()
                    (elem <f '(br br8) && (!c || f 2 = L)) ()          ; a later test of L owns the region
                    (run >l L (f . acc) (n + 1) c))))
          (ops l) (filter (f \ two? f && <f != 'label) l)
          (call? l) (any (f \ elem <f '(call callr)) l)
          ; acc's forms back to the test of E -> the then, only a guess's evidence
          (thn l E t n) (l @ (f . u) (? (96 < n) ()
                                        (two? f && <f = 'br && f 2 = E) t
                                        (thn u E (f . t) (n + 1)))
                               _ ())
          (arm l J acc n) (l @ (f . u) (? (96 < n) ()
                                          (!(two? f)) (arm u J (f . acc) (n + 1))
                                          (<f = 'label && <>f = J) [(rev acc) l]
                                          (elem <f '(jmpt align)) ()
                                          (arm u J (f . acc) (n + 1)))
                                 _ ())
          (colder? a t) (: oa (ops a) ot (ops t)
                           (two? ot && (call? oa && !(call? ot) || 2 * #ot <= #oa)))
          (else f l acc)
           (f @ ['jmp J] (l @ (['label E] . u)
                            (: a (nelem E hot && arm u J () 0)
                               (two? a && colder? <a (thn acc E () 0) ? [E J a])))
                         _ ())
          (go l acc cs)
           (!(two? l) ? (rev acc + cs)
              (else <l >l acc @
               [E J a] (: b <a
                          (go (a 1) acc (cs + (['label E] . b) + (term? (last b) ? () [['jmp J]]))))
               _ (: f <l
                 k (two? f && <f = 'br && elem <>f '(eq ne lt le gt ge below be above ae s ns) &&
                    nelem <>>f hot ?
                      (run >l <>>f () 0 (elem <>>f cold)))
                 r1 (two? k && !(two? ><k) && <<<k = 'jmp ? (<<k 1))
                 (? (two? k && r1 && (x64? g || elem r1 labs))
                     (go (k 1) (['br (negcc <>f) r1] . acc) cs)
                    (two? k)
                     (nlab g ".k" @ K
                        (go (k 1) (['br (negcc <>f) K] . acc) (cs + (['label K] . <k))))
                    (go >l (f . acc) cs)))))
          (go fs () ()))))
   ; a64's frame record: the fp and lr pushes fuse to one stp, the pops to one ldp; the area stays
   ; 32 bytes, so no fp-relative offset moves
   (frrec g fs)
    (cz g 'frrec fs (!(a64? g) || !(two? fs) ? fs
       (: (go l acc) (? !(two? l) (rev acc)
                        (<l = '(push lr) && <>l = '(push fp)) (go >>l ('(frpush) . acc))
                        (<l = '(pop fp) && <>l = '(pop lr)) (go >>l ('(frpop) . acc))
                        (go >l (<l . acc)))
          (lone? f) (two? f && elem <f '(push pop) && elem <>f '(fp lr))
          r (go fs ())
          (any lone? r ? (nolane g "a frame record split\(ontgt g)") r))))
   ; thumb2's frame by register list: the saves and the frame record push as one, each exit pops them
   ; with pc. the saves sit just under fp (r4 pads them to an even count), so every negative fp offset
   ; moves down past them; sp-relative ones hold. a fn whose fp or exits read any other way keeps its frame
   (t2pm g fs)
    (cz g 't2pm fs (? (!(t2? g) || g 'hasasm || abl? g 't2pm || #fs < 5) fs
                      !(take 3 >fs = '((push lr) (push fp) (lea fp sp 0))) fs
       (: r0 (drop 4 fs)
          sb (<r0 @ ('sub 'sp 'sp n) (charm? n ? [<r0]) ())
          (svs l acc) (<l @ ('st 'fp k r) (charm? k && k < 0 && elem r (cspool g) && !(any (x \ <x = r) acc) ?
                                             (svs >l ([r k] . acc)) [acc l])
                          [acc l])
          sv (two? sb ? (svs >r0 ()) [() r0])
          sl <sv
          rs (filter (r \ any (x \ <x = r) sl || #sl % 2 = 1 && r = 'r4) '(r4 r5 r6 r7 r8 r9 r10))
          P (4 * #rs)
          (sh f) (? (elem <f (ldops9 + fldops + leaops) && f 2 = 'fp)
                     (charm? (f 3) && f 3 < 0 ? [<f <>f 'fp (f 3 - P)] (charm? (f 3) && 0 < f 3 ? f 'bad))
                    (elem <f (gstops + fstops) && <>f = 'fp)
                     (charm? (f 2) && f 2 < 0 ? [<f 'fp (f 2 - P) (f 3)] (charm? (f 2) && 0 < f 2 ? f 'bad))
                    (fp? f) 'bad
                    f)
          (fp? x) (? (atom? x) (x = 'fp) (any fp? x))
          ; an exit: the restores it owes, in any order and maybe none (csdrop keeps only the written ones;
          ; the pop puts back the rest unchanged), then the frame back and the record (acc runs backwards,
          ; already shifted)
          (rst? f) (f @ ('ld r 'fp k) (any (x \ x = [r (k + P)]) sl) ())
          (unrst l) (two? l && rst? <l ? (unrst >l) l)
          up [['spfp P]]                       ; sp back to fp - P, which t2sp lowers by the depth it knows
          (go l acc)
           (? !(two? l) (rev acc)
              (take 3 l = '((lea sp fp 0) (pop fp) (pop lr)))
               (drop 3 l @ l3
                  (two? l3 && <l3 = '(ret) ?
                     (go >l3 ([['popm (rs + '(fp pc))]] + up + unrst acc))
                     (go l3 ([['popm (rs + '(fp lr))]] + up + unrst acc))))
              (sh <l @ f (f = 'bad ? 'bad (go >l (f . acc)))))
          body (go <>sv ())
          ; the save cells go unwritten now, so a reload of one left anywhere keeps the old frame
          (stale? f) (f @ ('ld r 'fp k) (any (x \ <>x - P = k) sl) ())
          ; a body that names neither sp nor fp past its pushes and exits keeps no frame below the saves
          (fr? x) (? (atom? x) (x = 'fp || x = 'sp) (any fr? x))
          sb2 (any (f \ (two? f && nelem <f '(push pop spfp) && fr? f)) body ? sb ())
          (body = 'bad || any stale? body ? fs
             (<fs . [['pushm (rs + '(fp lr))] ['lea 'fp 'sp P]] + sb2 + t2sp body (P + (two? sb2 ? (<sb2 3) 0)))))))
   ; under t2pm a frame slot rides sp where sp's depth under fp is known: a positive offset reaches 4095
   ; in one ldr.w where a negative one reaches 255. the depth walks every constant sp move and meets at
   ; labels; a move by a register, or two paths that disagree, leaves it unknown and the slot on fp
   (t2sp fs d0)
    (: lab {}
       labs (foldl (t \ f \ (<f = 'label ? (pin t <>f 1) t)) {} fs)
       ch {}
       (bump t) (pin ch 0 (peep ch 0 0 + 1), t)
       (rec L d) (peep lab L () @ o (? (d = 'none) 0
                                      (o = ()) (bump (pin lab L (charm? d ? d 'x)))
                                      (o = 'x || o = d) 0
                                      (bump (pin lab L 'x))))
       (dd d n) (charm? d ? (d + n) ())
       ; a form's effect on the depth: a number, () unknown, 'none where nothing falls through
       (eff f d)
        (f @ ('sub 'sp 'sp n) (charm? n ? (dd d n) ())
             ('add 'sp 'sp n) (charm? n ? (dd d (0 - n)) ())
             ('push _) (dd d 4)
             ('pop _) (dd d -4)
             ('pushm rs) (dd d (4 * #rs))
             ('popm rs) (elem 'pc rs ? 'none (dd d (-4 * #rs)))
             ('lea 'sp 'fp k) (charm? k ? (0 - k) ())
             ('lea 'sp 'sp k) (charm? k ? (dd d (0 - k)) ())
             ('spfp p) p
             ('br _ L) (rec L d, d)
             ('jmp L) ((labs L ? (rec L d)), 'none)
             ('jmpt _ _ ls) (map (L \ rec L d) ls, 'none)
             (elem <f '(ret jmpr trap ud2) ? 'none
                (<>f = 'sp && nelem <f (stops9 + stxops + siops + '(cmp test)) ? () d)))
       ; at a label the fall-through meets what the branches recorded
       (at L d) (peep lab L () @ o (? (d = 'none) (? (o = ()) 'none (o = 'x) () o)
                                      (o = () || o = d) d
                                      ()))
       (next f d) (d = 'none ? 'none (eff f d))
       (walk l d)
        (two? l &&
         (<l @ f (<f = 'label ? (at <>f d @ d2 (rec <>f d2, walk >l d2))
                    (walk >l (next f d)))))
       (fix n) (walk fs d0, peep ch 0 0 @ m (m = n ? 0 (fix m)))
       _ (fix -1)
       (fits? f o) (0 <= o && (elem <f (fldops + fstops) ? (o <= 1020 && o % 4 = 0) (o <= 4095)))
       (sp f d)
        (? !(charm? d) [f]
           (elem <f (ldops9 + fldops + leaops) && <>f != 'sp && f 2 = 'fp && charm? (f 3) && f 3 < 0)
            (f 3 + d @ o [(fits? f o ? [<f <>f 'sp o] f)])
           (elem <f (gstops + fstops) && <>f = 'fp && charm? (f 2) && f 2 < 0)
            (f 2 + d @ o [(fits? f o ? [<f 'sp o (f 3)] f)])
           [f])
       (low f d)
        (f @ ('spfp p) (? !(charm? d) ('((lea sp fp 0)) + (p = 0 ? () [['sub 'sp 'sp p]]))
                                   (d = p) ()
                                   [['add 'sp 'sp (d - p)]])
             (sp f d))
       (out l d)
        (? !(two? l) ()
           (<l @ f (<f = 'label ? (at <>f d @ d2 (f . out >l d2))
                      (low f d + out >l (next f d)))))
       (out fs d0))
   ; -mbranch-protection (a key): pac-ret lays paciasp before each (frpush), autiasp after each (frpop).
   ; under bti a table jump's targets land on bti j and an indirect jump goes by x16, which bti c and
   ; paciasp both take from a br. the entry's bti c is btic's: only the unit knows a static's address taken
   (bp? g k) (a64? g && elem k <>(g 'mo))
   ; -mstrict-align (a64), and always on v6-M, which faults on any unaligned word: no access wider
   ; than its known alignment; a packed member's face carries its alignment and goes by chunks, r2
   ; gathers and r3 shifts, neither ever a face's base
   (sal? g) (a64? g && <(g 'mo) || v6m? g)
   (salk g n) (v6m? g ? (min n 4) n)                ; the alignment an n-aligned access needs: v6-M's widest is a word
   ; -mregparm=n (i386): the first n argument words ride eax edx ecx
   (rpn g) (ia32? g ? (drop 2 (g 'mo) @ r (two? r && charm? <r ? <r 0)) 0)
   (osz? g) (drop 4 (g 'mo) @ r (two? r && <r))   ; -Os: for size
   (nofp? g) (drop 5 (g 'mo) @ r (two? r && <r))  ; -mno-sse and kin: no float register
   (njt? g) (drop 7 (g 'mo) @ r (two? r && <r))   ; -fno-jump-tables: a switch is a chain of compares
   ; -fno-builtin: 1 every plain name a call, else the names -fno-builtin-NAME gave
   (nobi? g nm) (drop 8 (g 'mo) @ r (two? r && (<r = 1 || elem nm <r)))
   (falgn g) (drop 9 (g 'mo) @ r (two? r && charm? <r ? <r 0))   ; -falign-functions=N
   (nsib? g) (drop 10 (g 'mo) @ r (two? r && <r))  ; -fno-optimize-sibling-calls: a call stays a call
   (avz? g) (drop 11 (g 'mo) @ r (two? r && <r))   ; -ftrivial-auto-var-init=zero
   (ibt? g) (x64t? g && drop 12 (g 'mo) @ r (two? r && <r))   ; -fcf-protection=branch: x86's endbr pads
   (sspg g) (drop 15 (g 'mo) @ r (two? r ? <r))   ; -fstack-protector's guard (mode reg symbol offset)
   (x86k? g k) (x64? g && drop 16 (g 'mo) @ r (two? r && elem k <r))   ; the x86-64 kernel's asks: sa8 nal thk thki rth ibr cs
   (xkask? g k) (drop 16 (g 'mo) @ r (two? r && elem k <r))           ; an ask by its word, any target
   (x86ki? g) ((x64? g || ia32? g) && xkask? g 'thki)                   ; -mretpoline, either width
   (kfp? g) (xkask? g 'kfp)                                              ; -fno-omit-frame-pointer: the link stays
   (sa4? g) (ia32? g && drop 16 (g 'mo) @ r (two? r && elem 'sa4 <r))   ; i386 -mstack-alignment=4
   (npic? g) (drop 17 (g 'mo) @ r (two? r && <r))   ; -fno-pie said: no load base moves the image
   (lowb x) (x & (0 - x))                            ; the alignment an offset keeps (0 for 0)
   ; the chunks of n bytes at an a-aligned address: (pos width) each, widest first
   (alchunks n a)
    (: (go p acc) (!(p < n) ? (rev acc)
                     (: lb (lowb p) c (min (p = 0 ? a (min a lb)) (n - p))
                        k (? (8 <= c) 8 (4 <= c) 4 (2 <= c) 2 1)
                        (go (p + k) ([p k] . acc))))
       (go 0 ()))
   (ldal d b o n a)                                 ; n bytes at b+o into d, zero-extended
    (foldl (acc \ [p k] \ acc + (p = 0 ? [[(uldop k) 'r2 b (o + p)]]
                                    [[(uldop k) 'r3 b (o + p)] ['shl 'r3 (8 * p)] '(or r2 r2 r3)]))
           () (alchunks n a) + (d = 'r2 ? () [['mov d 'r2]]))
   (stal b o n a v)                                 ; the low n bytes of v to b+o; v stands
    (foldl (acc \ [p k] \ acc + (p = 0 ? [[(k @ 1 'st1 2 'st2 4 'st4 'st) b o v]]
                                    [['mov 'r3 v] ['shr 'r3 (8 * p)] [(k @ 1 'st1 2 'st2 4 'st4 'st) b (o + p) 'r3]]))
           () (alchunks n a))
   ; a bitfield's unit, n bytes at b+o: one word as its type says, or by chunks when packed (its
   ; own n bytes, every one exact) or misaligned (a, the alignment its face carries)
   ; n bytes at b+o by chunks to the frame word(s) at tm, and back: a float wider than a register
   (ldalw g b o n a tm) (catmap (p \ ldal 'r2 b (o + p) (min (wsize g) (n - p)) a + [['st 'r4 (tm + p) 'r2]]) (filter (p \ p % wsize g = 0) ^n))
   (stalw g b o n a tm) (catmap (p \ (min (wsize g) (n - p) @ k ([(uldop k) 'r2 'r4 (tm + p)] . stal b (o + p) k a 'r2))) (filter (p \ p % wsize g = 0) ^n))
   (bfpk? bt) (two? (drop 4 bt))
   bp-paci '(raw (63 35 3 213))                     ; paciasp
   bp-auti '(raw (191 35 3 213))                    ; autiasp
   bp-btic '(raw (95 36 3 213))                     ; bti c
   bp-btij '(raw (159 36 3 213))                    ; bti j
   bp-endbr64 '(raw (243 15 30 250))
   bp-endbr32 '(raw (243 15 30 251))
   ; a landing pad's bytes: bti c, or x86's endbr
   (lpad? g) (bp? g 'bti || ibt? g)
   (lpad g) (? !(ibt? g) bp-btic (ia32? g) bp-endbr32 bp-endbr64)
   ; under ibt every indirect target lands on endbr: a table's cases, a label whose address is
   ; taken, and the return from a returns-twice call, which a longjmp reaches by an indirect jmp
   (bprot g fs)
    (cz g 'bprot fs (: pac (bp? g 'pac) bti (bp? g 'bti) ibt (ibt? g)
       tl (bti || ibt ? (foldl (t \ f \ (? !(two? f) t
                                         (<f = 'jmpt) (foldl (t2 \ L \ pin t2 L 1) t (f 3))
                                         (ibt && <f = 'la && starts? (show (f 2)) "\(g 'fn).") (pin t (f 2) 1)
                                         t)) {} fs))
       (go l acc)
        (!(two? l) ? (rev acc)
           (<l @ f
              (? (pac && f = '(frpush)) (go >l (f . bp-paci . acc))
                 (pac && f = '(frpop)) (go >l (bp-auti . f . acc))
                 (bti && two? f && <f = 'label && peep tl (f 1) ()) (go >l (bp-btij . f . acc))
                 (bti && two? f && <f = 'jmpr && nelem (f 1) '(r16 r17))
                  (go >l (['jmpr 'r16] . ['mov 'r16 (f 1)] . acc))
                 (ibt && two? f && <f = 'label && peep tl (f 1) ()) (go >l (lpad g . f . acc))
                 (ibt && two? f && <f = 'call && elem (show (f 1)) twicefns) (go >l (lpad g . f . acc))
                 (go >l (f . acc)))))
       (pac || bti || ibt ? (go fs ()) fs)))
   ; the entry's bti c, once the unit is laid: a fn callable from outside or address-taken, unless
   ; paciasp (a landing pad itself) leads. its slot sits right behind the fn's own label
   (btiat nm fs) (: L ['label (name nm)]
                    (go l) (!(two? l) ? l (<l = L ? (<l . '(btislot) . >l) (<l . go >l)))
                    (go fs))
   ; -fpatchable-function-entry's pad: N nops, M of them ahead of the entry, the rest behind
   ; it (and its landing pad); each pad's start is a word in __patchable_function_entries
   (pfeof g nm) (peep (g 'pfes) nm (drop 14 (g 'mo) @ r (two? r ? <r ())) @ p (two? p && 0 < <p ? p ()))
   (pnops g k) (map (_ \ (? (x64t? g) '(raw (144)) (a64? g) '(raw (31 32 3 213)) '(raw (19 0 0 0)))) ^k)
   (pfelab nm) (name ".pfe.\(nm)")
   (pfepre g nm pf) (two? pf ? (pin g 'pfel (pfelab nm . g 'pfel), ['label (pfelab nm)] . pnops g (pf 1)))
   (pfepost g nm pf fs)
    (? !(two? pf) fs
       (: L ['label (name nm)] k (<pf - pf 1)
          (go l) (? !(two? l) l
                    (<l = L && two? >l && <>l = '(btislot)) (<l . <>l . pnops g k + >>l)
                    (<l = L) (<l . pnops g k + >l)
                    (<l . go >l))
          (go fs)))
   (btic g fm on)
    (: (go l acc)
        (!(two? l) ? (rev acc)
           (<l = '(btislot) ? (go >l (on && <>l != bp-paci ? (lpad g . acc) acc))
              (go >l (<l . acc))))
       (go fm ()))
   ; shrink-wrap (x64): code the entry reaches without the frame runs without it. the prologue moves onto
   ; the edges leaving that region, one stub each, and its exits drop their restores. the frame is needed by
   ; an sp operand, a call, push/pop, or a write of a saved register; a label reached from outside is outside
   (swrap g fs)
    (cz g 'swrap fs (kfp? g ? fs (: f1 (two? fs && two? >fs ? <>fs)
       N (two? f1 && <f1 = 'sub && f1 1 = 'sp && f1 2 = 'sp && charm? (f1 3) ? (f1 3))
       (sv l acc) (two? l && two? <l && <<l = 'st && <l 1 = 'sp && charm? (<l 2) && nom? (<l 3) ?
                     (sv >l ([(<l 2) (<l 3)] . acc)) [(rev acc) l])
       s9 (N ? (sv >>fs ()))
       (!(x64? g) || g 'sspf || !N || !(two? <>s9) ? fs
          (: saves <s9 rs (map (p \ p 1) saves) bod <>s9 n #bod
             fv (foldl (t \ i \ pin t i (bod i)) {} (jot n))
             lix (foldl (t \ i \ fv i @ f (two? f && <f = 'label ? (pin t (f 1) i) t)) {} (jot n))
             (uncond? f) (two? f && elem <f '(jmp jmpm jmpr ret ud2))
             (epi? f) (two? f && (<f = 'add && f 1 = 'sp && f 2 = 'sp && f 3 = N ||
                                  <f = 'ld && f 2 = 'sp && elem [(f 3) (f 1)] saves))
             (needs? f) (? (!(two? f) || epi? f) ()
                           (elem <f '(call callr callm push pop raw sys asm jmpt) || elem 'sp f) 1
                           (elem <f '(label align br br8 jmp jmpm jmpr ret ud2)) ()   ; rdsp bars control forms
                           (rdsp g f @ rd (rd = 'bar || foldl (a \ r \ a || elem r rs) () <>rd)))
             (tgt f) (? (two? f && elem <f '(br br8)) (f 2) (two? f && <f = 'jmp) (f 1))
             (succ i f) (: t (tgt f) j (t ? (lix t))
                           (? (charm? j) (uncond? f ? [j] [j (i + 1)])
                              (uncond? f) ()
                              (i + 1 < n) [(i + 1)] ()))
             ; the branch predecessors of each label, a table jump one of each of its targets
             (bpin t i L) (charm? (peep lix L ()) ? (pin t L (i . peep t L ())) t)
             bp (foldl (t \ i \ (: f (fv i)
                                   (two? f && <f = 'jmpt ? (foldl (t2 \ L \ bpin t2 i L) t (f 3))
                                      (bpin t i (tgt f))))) {} (jot n))
             (reach B)
              (: (go st P) (!(two? st) ? P
                              (<st @ i
                                 (peep P i () || peep B i () || needs? (fv i) ? (go >st P)
                                    (go (succ i (fv i) + >st) (pin P i 1)))))
                 (go [0] {}))
             (settle B)
              (: P (reach B)
                 bad (filter (j \ (: f (fv j) L (f 1)
                                    ; a label is inside only if every way in is
                                    (!(foldl (a \ i \ a && peep P i ()) 1 (peep bp L ())) ||
                                     0 < j && !(uncond? (fv (j - 1))) && !(peep P (j - 1) ()))))
                             (filter (j \ fv j @ f (two? f && <f = 'label)) (keys P)))
                 (two? bad ? (settle (foldl (t \ j \ pin t j 1) B bad)) P))
             P (settle {})
             (inP i) (P i)
             (exit? f) (two? f && (elem <f '(jmpm jmpr ret) || <f = 'jmp && !(charm? (peep lix (f 1) ()))))
             ; the ways out: a branch to an outside label, or a fall into an outside form
             (uniq l) (foldl (a \ j \ elem j a ? a (j . a)) () l)
             jb (uniq (foldl (a \ i \ (: f (fv i) t (tgt f) j (t ? (lix t))
                                          (charm? j && !(inP j) ? (j . a) a)))
                             () (filter inP (jot n))))
             jf (filter (i \ i < n && !(inP i) && inP (i - 1) && !(uncond? (fv (i - 1))))
                        (map (+ 1) (filter inP (jot n))))
             js (uniq (jb + jf))
             (!(inP 0) || !(foldl (a \ i \ a || exit? (fv i)) () (filter inP (jot n))) ? fs
                (: tl (foldl (t \ j \ fv j @ f (pin t j (two? f && <f = 'label ? (f 1) (nlab g ".w")))) {} js)
                   sl (foldl (t \ j \ pin t j (nlab g ".w")) {} jb)
                   pro (['lea 'sp 'sp (0 - N)] . map (p \ ['st 'sp (p 0) (p 1)]) saves)   ; lea: a compare's flags may outlive it
                   (emit i acc)
                    (!(i < n) ? (rev acc)
                       (fv i @ f
                          (inP i ?
                              (: t (tgt f) j (t ? (lix t))
                                 f2 (charm? j && !(inP j) ? (reop f (<f = 'jmp ? 1 2) (sl j)) f)
                                 a1 (epi? f ? acc (f2 . acc))
                                 (emit (i + 1) (!(uncond? f) && i + 1 < n && !(inP (i + 1)) ?
                                                  (rev pro + a1) a1)))            ; a fall out lays the prologue inline
                             (: a1 (elem i js && !(two? f && <f = 'label) ? (['label (tl i)] . acc) acc)
                                (emit (i + 1) (f . a1))))))
                   stubs (foldl (a \ j \ a + [['label (sl j)]] + pro + [['jmp (tl j)]]) () jb)
                   ((<fs . emit 0 ()) + stubs))))))))
   ; adjacent sp adjustments merge; a cancelled pair (a dead cell's husk) vanishes
   (spadj? f) (two? f && elem <f '(add sub) &&
               <>f = 'sp && <>>f = 'sp && charm? <>>>f)
   ; the callee-saved file per target, as holo's tables have it
   (csregs g) (? (a64? g) '(r19 r20 r21 r22 r23 r24 r25 r26 r27 r28)
                 (wasm? g) '(r13 r14 r15 r16 r17 r18 r19 r20 r21 r22 r23 r24 r25 r26)
                 (rv64? g) '(r13 r14 r15 r19 r20 r21 r22 r23 r24 r25 r26)
                 (t32? g) '(r4 r5 r6 r7 r8 r9 r10)
                 (ia32? g) '(r3 r4 r5 r6)             ; ebx ebp esi edi
                 ('(r3 r4) + csx64))

   ; the liveness kit: a backward fixpoint over the per-form graph. the answer over-approximates
   ; live: a call reads+writes the caller-saved file, a sibcall reads everything, an unnamed op bars
   (lvgp g) (? (a64? g) '(r0 r1 r2 r3 r4 r5 r6 r7 r8 r9 r10 r11 r12 r13 r14 r15)
               (rv64? g) '(r0 r1 r2 r3 r4 r5 r6 r7 r8 r9 r10 r11 r12)
               (t32? g) '(r0 r1 r2 r3 r12)
               (ia32? g) '(r0 r1 r2)
               '(r0 r1 r2 r5 r6 r7 r8 r9 r10))       ; caller-saved gp: no save owed, but none may span a call
   lvquiet '(label align ud2 br jmp)
   ; what an exit owes back beside the cs file; r2 only where a wide return rides it
   (lvret g) (? (t32w? g && d128? <(peep (g 'sigs) (g 'fn) ['long ()])) '(r0 r1 r2 r3)   ; a wide return's four words
                (t32? g) '(r0 r1)
                (ia32? g) '(r0 r1 r2)                          ; a pair leaves as edx:eax, moved there at the exit
                (<(peep (g 'sigs) (g 'fn) ['long ()]) @ rt       ; r2: a wide return's high half, x64's int pair's
                   (w128? g && (d128? rt || x64? g && ipair? g rt) ? '(r0 r1 r2 f0 f1) '(r0 r1 f0 f1))))
   ; -- the float file's reads and writes, beside rdsp's gp model: every float form is two-address,
   ; an op reading both and writing its first; a copy or a convert reads its source alone. a form
   ; naming a float register the table does not know bars, as a call that may write it all --
   fall9 '(f0 f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12 f13 f14 f15 f16 f17 f18 f19 f20 f21 f22 f23
           f24 f25 f26 f27 f28 f29 f30 f31)
   fbin9 '(addsd subsd mulsd divsd minsd maxsd addss subss mulss divss minss maxss
           mulpd addpd subpd divpd xorpd andpd pcmpeqd psubq unpcklpd movhlps)
   fcpy9 '(movapd movsd movss movupd)
   fmop9 '(addsd subsd mulsd divsd minsd maxsd ucomisd)     ; the scalar ops fldop gives a memory source
   fmops9 '(addss subss mulss divss minss maxss ucomiss)
   (fcvt9 op) (elem op '(cvtss2sd cvtsd2ss))
   (fdef9 op) (elem op '(ldsd ldss ldsdl ldsdx ldssx cvtsi2sd cvtui2sd cvtsi2ss cvtui2ss movqxr movdxr fimm fli ldsspi))
   (fuse9 op) (elem op '(cvttsd2si cvttsd2ui cvttss2si cvttss2ui movqrx movdrx movmskpd))
   ; what a call writes: x64's whole file; a64 keeps v8..v15's low half
   (fcalld g) (? (a64? g) '(f0 f1 f2 f3 f4 f5 f6 f7 f16 f17 f18 f19 f20 f21 f22 f23 f24 f25 f26 f27 f28 f29 f30 f31)
                 (sp64? g) '(f0 f1 f2 f3 f4 f5 f6 f7 f15 f16 f17 f18 f19 f20 f21 f22 f23 f31)
                 (t32? g) '(f0 f1 f2 f3 f4 f5 f6 f7 f15)   ; d8-d14 callee-saved, d15 moon's own scratch
                 fregs16)
   (fnm? g x) (nom? x && elem x fall9)
   (frd g f)                                          ; -> [reads defs] of the float file | 'bar
    (? !(two? f) [() ()]
       (<f @ op
          (? (elem op lvquiet) [() ()]
             (elem op '(call callr callm sys))
              [(op = 'call && !(abl? g 'fcar) ? (peep (peep g 'fcar {}) <>f () @ (1 . a) a '(f0 f1 f2 f3 f4 f5 f6 f7)) '(f0 f1 f2 f3 f4 f5 f6 f7)) (fcalld g)]
             (retx? f) [(filter (r9 \ elem r9 fall9) (lvret g)) ()]
             (op = 'jmpr) [fall9 ()]
             (elem op '(raw asm)) 'bar
             (elem op fbin9) [[<>f <>>f] [<>f]]
             (elem op '(addss3 subss3 mulss3 divss3)) [[<>>f <>>>f] [<>f]]
             (elem op fcpy9 || fcvt9 op) [[<>>f] [<>f]]
             (fdef9 op) [() [<>f]]
             (elem op '(stsd stss)) [[(f 3)] ()]
             (elem op '(stsdx stssx)) [[(f 5)] ()]
             (elem op '(ucomisd ucomiss)) [[<>f <>>f] ()]
             (op = 'ucom0) [[<>f] ()]
             (op = 'stsspi) [[<>>f] ()]
             (fuse9 op) [[<>>f] ()]
             (op = 'cmppd) [[<>f <>>f] [<>f]]
             (any (fnm? g) >f) 'bar
             [() ()])))
   ; dead label regions: a form after an unconditional transfer drops until a still-referenced
   ; label (refs = every symbol operand, over-approximate); a dropped region takes its refs with it
   ; every nom among ops pinned into t; nested operands (a raw splice's forms) scan whole
   (pinnoms t ops) (!(two? ops) ? 0 (<ops @ o ((? (nom? o) (pin t o 1) (two? o) (pinnoms t o)), pinnoms t >ops)))
   (deadlabk ks fs) (deadlab1 ks fs @ r (#r = #fs ? r (deadlabk ks r)))
   (deadlab1 ks fs)
    (: ; a label is live once a live form names it, so a dead loop's back edge keeps nothing; from ks to a fixpoint
       (live R) (: t (foldl (t \ k \ pin t k 1) {} (keys ks))
                   (walk l dead) (two? l ?
                                    (<l @ f
                                       (? (two? f && <f = 'label) (walk >l (dead && !(R <>f)))
                                          dead (walk >l 1)
                                          (two? f ? (pinnoms t >f),
                                           walk >l (gone? f)))))
                   _ (walk fs 0)
                   t)
       (reach R) (live R @ R2 (#(keys R2) = #(keys R) ? R (reach R2)))
       refs (reach {})
       (sweep l dead)
        (two? l ?
           (: f <l
              lbl (two? f && <f = 'label)
              (? (dead && lbl)
                  (refs <>f ? (f . sweep >l 0) (sweep >l 1))
                 ; the align ahead of a live label is that label's pad, not dead code
                 (dead && two? f && <f = 'align)
                  (: n (two? >l ? <(>l))
                     (two? n && <n = 'label && refs <>n ? (f . sweep >l 1) (sweep >l 1)))
                 dead (sweep >l 1)
                 ; a jump to the very next label is the fall-through: drops, and the fixpoint may take the label
                 (two? f && <f = 'jmp &&
                  (<>l @ n (two? n && <n = 'label && <>n = <>f)))
                  (sweep >l 0)
                 (f . sweep >l (gone? f)))))
       (sweep fs 0))
   ; a form control never passes: an exit, a jump, or a trap (__builtin_trap and unreachable)
   (gone? f) (xit? f || two? f && elem <f '(jmp jmpt ud2 trap))
   ; ..again once the late passes have run, which lay a cold arm out of line with a jmp back: what
   ; follows a trap to the next label never runs (a label's align stays with it)
   (trapcut fs)
    (: (go l cut) (? !(two? l) l
                     (<l @ f (? (two? f && <f = 'label) (f . go >l 0)
                                (cut && !(two? f && <f = 'align && two? >l && two? <>l && <<>l = 'label)) (go >l 1)
                                (f . go >l (cut || two? f && elem <f '(ud2 trap))))))
       (go fs 0))
   (fldcut g fs) (trapcut (fldop g fs))

   ; an idle cs seat: a borrowed x64 cs reg untouched but for its save and restores owes neither.
   ; x64, past cskeep
   (csdrop g fs)
    (cz g 'csdrop fs (: (sv? f r) (two? f && <f = 'st && <>f = 'sp && f 3 == r)
       (rs? f r) (two? f && <f = 'ld && <>f = r && <>>f = 'sp)
       ; a store that first names r saves its entry value; a later one passes something loaded
       (idle? r) (filter (f \ two? f && elem r >f) fs @ (h . t) (sv? h r && !(any (f \ !(rs? f r)) t)) _ ())
       dr (x64t? g && !(g 'hasasm) && !(vany (f \ two? f && elem <f '(raw asm)) fs) ?
             (filter idle? (csx g)))
       (!(two? dr) ? fs
          (filter (f \ !(vany (r \ sv? f r || rs? f r) dr)) fs))))

   ; the callee-saved contract, held at emission: a cs reg written anywhere must be saved before
   ; its first write and restored by every exit. an op on neither rdsp nor csquiet refuses
   csquiet '(label align ud2 trap br jmp jmpr jmpt ret call callr callm sys mulo   ; trap = a64's brk #0, ud2's twin
             sx128 n128 a128 a128r s128 s128r m128 m128r mw128 mw128r c128 c128r
             dv128 rm128 inc128 dec128 shl128 shr128 sar128 shl128v shr128v sar128v)
   (csdefs g f)                                       ; the cs regs one form writes | 'dark
    (? (elem <f csquiet) ()
       ; idiv self-saves r2: its dst only; elsewhere a remainder's scratch is written too
       (elem <f divops) (filter (r \ elem r (csregs g)) (f @ (_ . d . _ . _ . t . _) (x86? g ? [d] [d t]) _ [<>f]))
       (rdsp g f @ rd
          (rd @ 'bar 'dark
                (filter (r \ elem r (csregs g)) <>rd))))
   ; the frame's saves, laid out from build's markers: each callee-saved register the body names
   ; is saved (an asm saves its own clobbers), rbx in its own cell, the rest just under the frame's
   ; fixed cells (rbx's, the canary's), every other slot moving down to make room, kept aligned,
   ; and the frame growing by as much; (saves) becomes the stores, and each (rests) the loads of
   ; what may be dirty there
   (csframe g fs)
    (cz g 'csframe fs
     (!(elem '(saves) fs) ? fs
        (: (mark? f) (f = '(saves) || f = '(rests))
           (names r x) (? (atom? x) (x = r) (any (names r) x))
           fb (fbase g)
           fcs (? (a64? g) '(f8 f9 f10 f11 f12 f13 f14 f15) (t32? g && !(v6m? g)) '(f8 f9 f10 f11 f12 f13 f14) ())
           ; wasm's registers are the function's own locals: a call leaves them, none is saved
           ; thumb2sp: an odd single's d is saved whole, by its even name
           (named? r f) (names r f || sp64? g && elem r fcs && names (rafo g r) f)
           nm (wasm? g ? () (filter (r \ any (f \ !(mark? f) && named? r f) fs) (filter (r \ r != fb) (v6m? g ? '(r5 r6) (csregs g)) + fcs)))
           r3 (x86? g && elem 'r3 nm)
           cs (filter (r \ !(r3 && r = 'r3)) nm)
           n #cs
           b0 (g 'sspf ? 16 8)
           d (g 'slal ? (aup (8 * n) (fbal g)) (8 * n))       ; an over-aligned object keeps its alignment
           hw (foldl (a \ s \ max a (0 - <s)) b0 (g 'slots))
           dk (aup (hw + d) 16 - aup hw 16)               ; what rides under the slots keeps its room
           offs (map (k \ 0 - (b0 + 8 * (k + 1))) ^n)
           sv ((r3 ? [['st fb -8 'r3]]) + map (k \ [(elem (cs k) fcs ? 'stsd 'st) fb (offs k) (cs k)]) ^n)
           (rs S) (catmap (k \ ((cs k) @ r
                                 (? (elem r fcs) [['ldsd r fb (offs k)]]
                                    (elem r S) [['ld r fb (offs k)]]
                                    ()))) ^n
                   + (r3 && elem 'r3 S ? [['ld 'r3 fb -8]]))
           ; the dirty walk: a write dirties a grant until an exit, a label joins its paths (to a
           ; fixpoint), and each (rests) restores what may be dirty there; an op the table cannot
           ; read dirties them all, and a jump whose targets go unspelled reaches every label
           labs (foldl (t \ f \ (two? f && <f = 'label ? (pin t <>f 1) t)) {} fs)
           lst {}
           (uni a b) (foldl (s \ r \ elem r s ? s (r . s)) b a)
           (sub? a b) (!(two? a) ? 1 (elem <a b && sub? >a b))
           (bmark L S) (: old (lst L) new (uni S old) (sub? new old ? 0 (pin lst L new, 1)))
           (ball S) (foldl (c \ L \ c + bmark L S) 0 (keys labs))
           (wr f S) (csdefs g f @ ds (ds @ 'dark (uni nm S) (uni (filter (r \ elem r nm) ds) S)))
           (walk l S chg acc)                          ; -> [changed the dirty sets at each (rests), last first]
            (!(two? l) ? [chg acc]
               (: f <l k (two? f ? <f ()) dead (S = 'dead)
                  (? (k = 'label) (walk >l (uni (dead ? () S) (lst <>f)) chg acc)
                     (f = '(rests)) (walk >l 'dead chg ((dead ? () S) . acc))
                     dead (walk >l S chg acc)
                     (k = 'br) (walk >l S (chg + bmark <>>f S) acc)
                     (k = 'jmp && labs <>f) (walk >l 'dead (chg + bmark <>f S) acc)
                     (elem k '(jmpt jmpr)) (walk >l 'dead (chg + ball S) acc)
                     (elem k '(ret jmp)) (walk >l 'dead chg acc)
                     (walk >l (wr f S) chg acc))))
           lim (1 + #(keys labs) * #nm)
           (fix j) (<(walk fs () 0 ()) = 0 ? 0 (j < lim ? (fix (j + 1)) (scare 'csframe-fix (g 'fn))))
           dts (two? nm ? (fix 0, rev <>(walk fs () 0 ())) ())
           ; a lea at the fixed cells' floor is one past a slot's end (va_start's tops): it moves too
           (down e o) (charm? o && (o < 0 - b0 || e && o = 0 - b0) ? (o - d) o)
           (reb f) (: bp (two? f ? (peep a4base <f -1) -1) up (two? f ? (peep uoff <f -1) -1)
                      (bp >= 0 && up >= 0 && f bp = fb ? (reop f up (down (<f = 'lea) (f up))) f))
           (kat l i) (? !(two? l) ()
                        (<l @ ('sub 'sp 'sp k) (charm? k ? i (kat >l (i + 1))) (kat >l (i + 1))))
           ki (kat fs 0)
           (lay l i ds) (? !(two? l) ()
                           (<l = '(saves)) (sv + lay >l (i + 1) ds)
                           (<l = '(rests)) (rs <ds + lay >l (i + 1) >ds)
                           (i = ki) (['sub 'sp 'sp (<l 3 + dk)] . lay >l (i + 1) ds)
                           ((0 < d ? (reb <l) <l) . lay >l (i + 1) ds))
           (0 < n && !(charm? ki) ? (scare 'csframe-no-frame (g 'fn))
              (pin g 'slots (map (o \ [o 8]) offs + map (s \ (down 0 <s . >s)) (g 'slots)),
               lay fs 0 dts)))))
   (cskeep g fs)                                    ; answers fs; a breach scares, naming fn + reg
    (cz g 'cskeep fs (: (rawy? (f . l)) (two? f && <f = 'raw ? 1 (rawy? l))
       ; every target with a cs file; a8 has none and bails
       (!(two? (cspool g)) || wasm? g || !(two? fs) || g 'hasasm || rawy? fs ? fs
          (: fn (<fs 1)
             labs {} saves {} defs {}
             (note l i)
              (!(two? l) ? 0
                 (<l @ f
                    ((? !(two? f) 0
                        (<f = 'label) (pin labs <>f 1)
                        (: _ (<f = 'push && elem <>f (csregs g) ?
                                (saves <>f ? 0 (pin saves <>f ['push i])) 0)
                           _ (<f = 'st &&
                              (<>f = 'sp || <>f = 'r4 || <>f = fbase g) &&
                              elem <>>>f (csregs g) ?
                                (saves <>>>f ? 0 (pin saves <>>>f ['slot <>f <>>f i])) 0)
                           ds (csdefs g f)
                           (ds @ 'dark (scare 'cs-dark-op <f)
                                 (foldl (_ \ r \ defs r ? 0 (pin defs r i)) 0 ds)))),
                     note >l (i + 1))))
             _ (note fs 1)
             dr (filter defs (csregs g))
             ; a fn no path leaves owes nothing back (its epilogue is gone)
             (anyx? l) (two? l ?
                          (<l @ f
                             (xit? f || xjmp? f labs ? 1
                                (anyx? >l))))
             (!(two? dr) || !(anyx? fs) ? fs      ; no cs writes, or no exit: most fns leave here
                (: _ (foldl                         ; every written reg saved, before its first write
                      (_ \ r \ saves r @ sv
                                 (!(two? sv) ? (scare 'cs-unsaved [fn r])
                                    (: sp9 (sv $ <sv @ 'push 1 3)
                                       (sp9 < peep defs r 0 ? 0 (scare 'cs-save-late [fn r])))))
                      0 dr)
                   (rest r) (saves r @ sv  ; the restore shape a save earns
                               (? !(two? sv) ()
                                  (<sv = 'push) ['pop r]
                                  ['ld r <>sv <>>sv]))
                   ; the dirty walk: a written reg is dirty until its restore, a label unions its
                   ; paths in (to a fixpoint), every exit must leave the set empty
                   lst {}                   ; label -> the join of its incoming dirty sets
                   (uni a b) (foldl (s \ r \ elem r s ? s (r . s)) b a)
                   (sub? a b) (!(two? a) ? 1 (elem <a b && sub? >a b))
                   (bmark L S) (: old (lst L)
                                  new (uni S old)
                                  (sub? new old ? 0 (pin lst L new, 1)))
                   (move f S)                       ; one form's transfer on the dirty set
                    (: ds (csdefs g f)
                       S2 (uni (ds @ 'dark dr (filter (r \ elem r dr) ds)) S)
                       (filter (r \ f != rest r) S2))
                   (step l S chg fin)
                    (!(two? l) ? chg
                       (<l @ f
                          (!(two? f) ? (step >l S chg fin)
                             (: k <f
                                dead (S = 'dead)
                                (? (k = 'label)
                                    (step >l (uni (dead ? () S) (lst <>f)) chg fin)
                                   dead (step >l S chg fin)
                                   (k = 'br) (step >l S (chg + bmark <>>f S) fin)
                                   (k = 'jmp && labs <>f)
                                    (step >l 'dead (chg + bmark <>f S) fin)
                                   (elem k '(ret jmpr jmp))
                                    ((fin ? (foldl (_ \ r \ scare 'cs-unrestored [fn r]) 0 S) 0),
                                     step >l 'dead chg fin)
                                   (step >l (move f S) chg fin))))))
                   ; a pass that changes anything grows some label's set, and no set outgrows dr
                   lim (1 + #(keys labs) * #dr)
                   (fix n) (step fs () 0 () ? (n < lim ? (fix (n + 1)) (scare 'cs-fix fn)) 0)
                   (fix 0,
                    step fs () 0 1,
                    fs)))))))

   ; the door set a call or a tail jump kills: caller-saved, never an argument (a64 args ride r0-r7,
   ; x64's al is li'd by setal first); a wasm call writes only r0 r1, so its locals ride it. arm
   ; has none: r0-r3 carry arguments, r12 a call's target, and the rest are callee-saved
   (doors g tail) (? (a64? g) '(r9 r10 r11 r12 r13 r14 r15)
                     (rv64? g) (wasm? g && !tail ? () '(r8 r9 r10 r11 r12))
                     (ia32? g) '(r0 r1 r2)
                     (t32? g) ()
                     '(r0 r9 r10))
   ; a jump's target is a function (a sibcall) when its spelling has no dot: gen's own labels lead
   ; with one, and a C label is spelled fn.label (a goto) -- neither is an exit
   (fsym? x) (findsub (show x) "." < 0)
   ; dies on the straight line: overwritten before any read. a ret rides r0 out, and on arm a
   ; pair's r1 beside it; a call or sibcall jmp kills the door set
   (dies? g rd (f . l))
    (two? f ?
       (rdsp g f @ rs
          (? (rs = 'bar)
              (? (retx? f) (rd != 'r0 && !(t32? g && rd = 'r1))
                 (elem <f '(call callr callm)) (elem rd (doors g 0))
                 (<f = 'jmp && fsym? <>f) (elem rd (doors g 1))
                 ())
             (elem rd <rs) ()
             (elem rd <>rs) 1
             (dies? g rd l))))
   ; the branching death proof (cmpfuse's license): dead when no reachable path reads before a
   ; def; ret frees all but r0; a read, an untabled op or a call answers live
   (dieb? g rd all fs0)
    (: seen {}
       (lab l w) (two? l ?
                    (<l @ f (two? f && <f = 'label && <>f = w ? >l (lab >l w))))
       (go l wl)
        (!(two? l) ? (next wl)
           (<l @ f
              (? !(two? f) (go >l wl)
                 (<f = 'label)
                  (seen <>f ? (next wl)
                     (pin seen <>f 1, go >l wl))
                 (<f = 'align) (go >l wl)          ; a loop head's pad: no register effect
                 (elem <f '(jmp jmp8))
                  (? !(fsym? <>f) (next (<>f . wl))
                     ; a tail jump to a function exits reading its args: only the door set dies
                     (elem rd (doors g 1)) (next wl)
                     ())
                 (<f = 'jmpt) (next (f 3 + wl))   ; a table jump: every target, and no fall-through
                 (elem <f '(br br8)) (go >l (<>>f . wl))
                 (retx? f) (rd @ 'r0 () (next wl))
                 (rdsp g f @ rs
                    (? (rs = 'bar) ()
                       (elem rd <rs) ()
                       (elem rd <>rs) (next wl)
                       (go >l wl))))))
       (next wl) (!(two? wl) ? 1
                  (<wl @ w (seen w ? (next >wl) (pin seen w 1, go (lab all w) >wl))))
       (go fs0 ()))

   ; cmp load-op fusion: (ld X b o)(cmp X y) -> (cmpm b o y), (cmp r X) -> (cmprm r b o) when X
   ; dies beyond. x64 and full-word only (a narrow cmp's flags shift with the extension)
   (cmpfuse g fs)
    (cz g 'cmpfuse fs (: (go (f . r))
           (: nx (two? r ? <r)
              X (two? f && <f = 'ld && two? nx && <nx = 'cmp ? <>f)
              m (? !(nom? X) ()
                   (<>nx = X)
                    (? (<>>nx = X) ()             ; X both sides never fuses
                       (charm? <>>nx && !(fits32 <>>nx)) ()
                       ['cmpm <>>f <>>>f <>>nx])
                   (<>>nx = X)
                    (charm? <>nx ? () ['cmprm <>nx <>>f <>>>f]))
              (two? m && dieb? g X fs >r ? (m . go >r) (f . go r)))
       (go fs)))

   ; within a straight run: a copy into a register the next op reads as its source, and that the run
   ; writes again before any read, lends the op its own source; a float copy or frame load whose
   ; register the run writes again unread goes
   ; a straight run's float reads and writes, () at its end; r is dead when the run writes it whole
   ; before any read (a write that keeps the upper lane, movsd between registers or a convert, does not)
   (fstep g f) (? (!(two? f) || elem <f '(label jmp br jmpt) || xit? f) () (frd g f @ 'bar () d d))
   (fdead? g r l) (? !(two? l) ()
                     (fstep g <l @ d (? !(two? d) ()
                                        (elem r <d) ()
                                        (elem r <>d) (elem <<l '(movapd ldsd ldss ldsdl ldsdx ldssx movqxr movdxr))
                                        (fdead? g r >l))))
   ; the last x64 pass: a load the next scalar op alone reads becomes that op's memory source, and
   ; a load copied straight on loads its copy. no frame pass runs past it
   (fldop g fs)
    (cz g 'fldop fs (? (!(x64? g) || abl? g 'fldop) fs
       (: (ld? f) (two? f && elem <f '(ldsd ldss ldsdl) && elem <>f fregs16)
          ; the op reading the loaded S as its source: d op= S, or a compare of d with S
          (use? f s w) (two? f && #f = 3 && elem <f (w = 'ldss ? fmops9 fmop9) && <>>f = s && <>f != s)
          (mo w op d f) (w = 'ldsdl ? ['fopl op d (f 2)] ['fopm op d (f 2) (f 3)])
          (go l) (? !(two? l) l
                    (: f <l n (two? >l ? <>l)
                     (? (ld? f && use? n <>f <f && fdead? g <>f >>l) (mo <f <n <>n f . go >>l)
                        (ld? f && two? n && <n = 'movapd && <>>n = <>f && elem <>n fregs16 && fdead? g <>f >>l)
                         (go ((<f . <>n . >>f) . >>l))
                        (f . go >l))))
          (go fs))))
   ; -- aggregate initializers: ('init (item..)), items plain | ('dfield name val) | ('didx n val) --
   (aggish? ty) (arr? ty || stru? ty)
   ; the seeded complex tags: a complex is a scalar to brace elision
   (gcplx? ty) (stru? ty && elem <>ty '("__cplx_double" "__cplx_float"))
   (elval it) (elem <it '(dfield didx) ? <>>it it)   ; the value of an item
   (fidx fields name) (: (go l i) (? (atom? l) 0 (<<l = name) i (go >l (i + 1)))
                          (go fields 0))
   (nthfield fields i) (0 <= i && i < #fields ? (fields i) 'bad)
   ; the member a positional initializer reaches after field ci: a union's later members start inside
   ; ci's storage (an anonymous union's are spliced flat), and brace elision passes them by
   (fnext g fields ci)
    (: fe (fields ci) end (<>fe + tsz g <>>fe)
       (go i) (i < #fields && !(bitf? <>>(fields i)) && <>(fields i) < end ? (go (i + 1)) i)
       (bitf? <>>fe ? (ci + 1) (go (ci + 1))))

   ; brace elision (C 6.7.9): the init tree normalizes up front, each elided run wrapped in an
   ; explicit ('init ..), so layout only sees fully-braced inits. idempotent
   (initval? ('init . _)) 1
   ; a wide literal (a clit-of-array) initializes an array; a pointer element keeps the clit (it decays)
   (clarr? ty ini) (arr? ty && !(ptr? <>ty) && two? ini && <ini = 'clit && arr? <>ini)
   ; braces at field fe that are an anonymous member's (`{ .tp = &x }`): fe is a scalar, or they open
   ; on a designator of this struct's own fields that fe's type lacks; those fields read in place
   (anonbr? g fields fe it)
    (: has? (fs \ nm \ any (f \ <f = nm) fs)           ; fidx answers 0 for a miss: ask by name
       (<it = 'init && two? <>it &&
        (!(aggish? <>>fe) ||
         (<<>it @ f0
            (two? f0 && <f0 = 'dfield && has? fields <>f0 &&
             !(stru? <>>fe && has? <(peep (g 'stag) <><>>fe 0) <>f0))))))
   ; ..and a struct's own compound literal is a whole member
   (clstru? g ty ini) (stru? ty && two? ini && <ini = 'clit && stru? <>ini && two? >>ini && tsz g <>ini = tsz g ty)
   ; ..and so is an expression of its own struct type (6.7.9p13), given a frame (env 'none: a static image)
   (whole? g env ty val) (stru? ty && env != 'none && (peekty g env val @ t (stru? t && <t = <ty && <>t = <>ty)))
   (unelide g env ty ini)
    (? (clarr? ty ini) (unelide g env ty <>>ini)      ; a wide literal: take its init
       !(initval? ini) ini                        ; a scalar / non-brace: nothing to nest
       !(aggish? ty) ini                           ; a brace on a scalar type: leave (layout unwraps/scares)
       ; { "s" } on a char array (C11 6.7.9p14): unwrap to the bare literal
       (arr? ty && !(ptr? <>ty) &&
        (<>ini @ its (two? its && !(two? >its) && two? <its && <<its = 'str)))
        <<>ini
       (arr? ty && !(ptr? <>ty) &&                   ; { L"s" }: p14's wide twin
        (<>ini @ its (two? its && !(two? >its) && two? <its && <<its = 'clit && arr? <><its)))
        (unelide g env ty <>><<>ini)
       (normfill g env ty <>ini @ pr ['init <pr]))     ; <pr = normed items; <>pr (excess) dropped
   (redesig dh dk v) [dh dk v]   ; ('didx k v) | ('dfield k v)
   (normelt g env ty desig dh dk val l)                 ; one element of type ty from item stream l -> (item rest)
    (? (arr? ty && !(ptr? <>ty) && two? val && <val = 'str)
        [<l >l]                                    ; a string is a char array's whole element, never an elision run
       (clarr? ty val || clstru? g ty val)          ; a wide or struct literal: the whole element, as its init
        (unelide g env ty <>>val @ w
           [(desig ? (redesig dh dk w) w) >l])
       (whole? g env ty val) [(desig ? (redesig dh dk val) val) >l]
       (aggish? ty && !(gcplx? ty) && !(initval? val))   ; elide: fill ty from the run at val (a complex is a scalar)
        (: pr (normfill g env ty (val . >l))
           w ['init <pr]
           [(desig ? (redesig dh dk w) w) <>pr])
       (: nv (initval? val ? (unelide g env ty val) val)  ; a braced sub -> recurse-normalize; a scalar -> as-is
          [(desig ? (redesig dh dk nv) (nv = val ? <l nv)) >l]))
   (normfill g env ty items)                            ; consume items to fill aggregate ty -> (normed-items rest)
    (? (arr? ty)
        (: elt <>ty n <>>ty
           (go l idx acc)
            (!(two? l) ? [(rev acc) ()]
               (: it <l
                  desig (<it = 'didx)
                  ; full and plain ends the walk; a designator may jump back ({ [2] = 9, [0] = 1 })
                  (!desig && 0 < n && n <= idx ? [(rev acc) l]
                     (: ci (desig ? <>it idx)
                        pr (normelt g env elt desig 'didx ci (elval it) l)
                        (go <>pr (ci + 1) (<pr . acc))))))
           (go items 0 ()))
       (stru? ty)
        (: fields <(peep (g 'stag) <>ty 0)
           (go l cur acc)
            (!(two? l) ? [(rev acc) ()]
               (: it <l
                  desig (<it = 'dfield)
                  ci (desig ? (fidx fields <>it) cur)
                  fe (nthfield fields ci)
                  (? (bad? fe) [(rev acc) l]          ; unknown field / past the end -> leave the rest
                     (!desig && anonbr? g fields fe it) (go (<>it + >l) cur acc)
                     (normelt g env <>>fe desig 'dfield <>it (elval it) l @ pr
                        (go <>pr (fnext g fields ci) (<pr . acc))))))
           (go items 0 ()))
       [items ()])

   ; global init (a constant byte image): scalars little-endian, aggregates a placement flatten,
   ; a pointer an abs64 fixup -- one list item but eight bytes, so lengths go through imbytelen
   (fixit? x) (two? x && <x = 'fix)
   (imbytelen l) (foldl (a \ x \ a + (fixit? x ? <>x 1)) 0 l)
   ; // and %, not & and >>: a big's bitwise ops are undefined. raw bytes only: bfover feeds
   ; it merged unit bits, so bool normalization stays in imgbytes
   (imnum g ty val) (: n (tsz g ty)
                       (pw k acc) (k < 1 ? acc (pw (k - 1) (acc * 256)))
                       u0 (val < 0 ? (val + pw n 1) val)
                       (go i v acc) (n <= i ? (rev acc)
                                       (go (i + 1) (v // 256) (v % 256 . acc)))
                       (go 0 u0 ()))
   ; insert (off items) keeping offsets ascending. pieces come newest first, so one at an offset
   ; already laid is an earlier initializer the later one overrides (6.7.9p19: [0 ... 5] = a, [3] = b)
   (iminsert x l) (? !(two? l) [x]
                     (<x < <<l) (x . l)
                     (<x = <<l) l
                     (<l . iminsert x >l))
   (imsort ps) (: (go l acc) (!(two? l) ? acc (go >l (iminsert <l acc))) (go ps ()))
   (imflat ps total)                                ; sorted (off items).. -> total bytes, gaps zeroed
    (: (go l pos acc)                               ; acc reversed: one rev at the end keeps it linear
        (!(two? l) ? (rev (revcat (zeros (total - pos)) acc))
           (: p <l off <p items <>p
              (go >l (off + imbytelen items) (revcat items (revcat (zeros (off - pos)) acc)))))
       (go ps 0 ()))
   ; a cast on a folded integer (C11 6.3.1.3): narrow types wrap and re-sign, word-sized keep the pattern
   (icast ty v)
    (ty @ 'bool (v != 0)
          ('uchar || 'cchar) (v & 255) 'ushort (v & 65535) 'uint (v & 4294967295)
          ('char || 'schar || 'short || 'int)
           (: w (ty @ ('char || 'schar) 8 'short 16 32)
              r (v & ((1 << w) - 1))
              (r < 1 << (w - 1) ? r (r - (1 << w))))
          v)
   ; a constant integer expression at image time -> value | 'no; `//` truncates toward zero like C's `/`
   (icfold e)
    (!(two? e) ? 'no
    (<e @ 'num <>e
       ; a cast may carry a float operand (C11 6.6p6): truncates toward zero, as `// 1` does
       'cast (icfold <>>e @ v
              (? (flo? <>e) 'no
                 !(v = 'no) (icast <>e v)
                 (ffold <>>e @ f
                    (? (bad? f || nan? f) 'no
                       (<>e = 'bool) (f = 0.0 ? 0 1)          ; to _Bool is a compare, never a truncation
                       (icast <>e (ceil (f // 1)))))))
       'un
        (icfold <>>e @ v
           (? (v = 'no) 'no (<>e = 'neg) -v (<>e = 'bnot) (-v - 1) 'no))
       'cond
        (icfold <>e @ c (? (c = 'no) 'no (c != 0) (icfold <>>e) (icfold <>>>e)))
       'bin (: op <>e a (icfold <>>e) b (icfold <>>>e)
             (a = 'no || b = 'no ? 'no
              (op @ '+ (a + b) '- (a - b) '* (a * b)
                    '/ (b = 0 ? 'no (a // b)) '% (b = 0 ? 'no (a - (a // b) * b))
                    'shl (a << b) 'shr (a >> b)
                    '& (a & b) '| (a | b) '^ (a ^ b)
                    'no)))
       'no))
   ; a constant lvalue at image time -> (label byteoffset type) | 'no: a global, *(const ptr),
   ; or a .member off either; the type threads so the next .member scales
   (imlval g e)
    (<e @ 'var
            (g 'fns <>e ? [(name <>e) 0 (fnty g <>e)]   ; a function is its address
               (peep (g 'glob) <>e 0 @ en               ; glob = (label type init)
                (two? en ? [<en 0 <>en] 'no)))
           'deref
            (imaddr g <>e @ p (p @ 'no 'no [<p <>p <><>>p]))
           'str (imaddr g e @ a [<a 0 ['arr (gchar g) (tally <>e + 1)]])   ; &"s": the literal's array
           'dot
            (imlval g <>e @ 'no 'no b
             (fmem g <>>b <>>e @ fm (bad? fm ? 'no [<b (<>b + <fm) <>fm])))
           ; a compound literal in a static initializer is its own static object (C11 6.5.2.5), laid beside
           ; the data, keyed by the global and its place in the image so re-imaging reuses it
           'clit
            (: ty <>e i (peep g 'clitn 0) _ (pin g 'clitn (i + 1)) k [(g 'clitg) i] m (g 'clitm)
               (peep m k () @ l
                 (l ? [l 0 ty]
                    (cgimage g ty (aggish? ty ? <>>e e) @ b      ; a scalar's braces unwrap in cgimage's clit arm
                      (bad? b ? 'no
                         (: l2 (nlab g ".C")
                            (pin m k l2,
                             pin g 'clits ([l2 (max 8 (tal g ty)) b] . g 'clits),
                             [l2 0 ty])))))))
           'no)
   ; a ?: whose condition is known at image time -> the arm it takes | 'no: an integer that
   ; folds, or a string or static address, which is never null
   (imsel g e)
    (: c <>e
       v (cfold !(ilp32? g) c)
       ; an object's or function's address is never null: compared with null, or negated, it decides the test
       (addr? x) ((two? x && <x = 'str) || imaddr g x != 'no)
       (null? x) (cfold !(ilp32? g) x @ k (cint? k && k = 0))
       t (? (cint? v) (v != 0)
            (two? c && <c = 'str) 1
            (c @ ('bin op a b) (elem op '(eq ne)) ('un 'not _) 1 ())
             (c @ ('un 'not x) (addr? x ? 0 'no)
                  ('bin op a b) ((addr? a && null? b) || (addr? b && null? a) ? (op = 'ne) 'no)
                  'no)
            (imaddr g c @ a (a = 'no ? 'no 1)))
       (? (t = 'no) 'no t <>>e <>>>e))
   ; a constant address at image time -> (label byteoffset ptrtype) | 'no; a cast retypes, so
   ; a later + scales by the new pointee
   (imaddr g e)
    (<e @ 'cond
        (imsel g e @ a (a = 'no ? 'no (imaddr g a)))
       'cast
        (imaddr g <>>e @ r
           (r @ 'no 'no [<r <>r <>e]))
       'str
        (nlab g ".S" @ l (pin g 'strs ([l <>e] . g 'strs), [l 0 ['ptr (gchar g)]]))
       'lsym [(name <>e) 0 '(ptr void)]         ; a label's address, spelled by cgsdecl
       'var
        (peep (g 'fns) <>e () ? [(intern <>e) 0 ['ptr (fnty g <>e)]]
           (peep (g 'glob) <>e 0 @ en
              ; neither a function nor a global: pin 'undecl (as cgfn does) so the diagnostic names it
              (!(two? en) ? (pin g 'undecl <>e, 'no)
                 (<>en @ ty (arr? ty ? [<en 0 ['ptr <>ty]] [<en 0 ['ptr ty]])))))
       'addr
        (imlval g <>e @ lv (lv @ 'no 'no [<lv <>lv ['ptr <>>lv]]))
       ; an array-typed element or compound literal decays the same way (`&a[0][0]`, `(const char *[]){..}`)
       ('deref || 'clit)
        (imlval g e @ lv (lv = 'no || !(arr? <>>lv) ? 'no [<lv <>lv ['ptr <>(<>>lv)]]))
       ; an array member decays to its first element's address (&s.arr[0] reads s.arr + 0)
       'dot
        (imlval g e @ lv (lv = 'no || !(arr? <>>lv) ? 'no [<lv <>lv ['ptr <>(<>>lv)]]))
       ('bin && elem <>e '(+ -))
        ; label +/- int: a pointer type scales by the pointee, an integer-typed label ((word)&x + 8) adds bytes
        (: op <>e
           (imscale ty) (ptr? ty ? (tsz g <>ty) 1)
           pa (imaddr g <>>e) kb (icfold <>>>e)
           (pa != 'no && kb != 'no ?
               [<pa (<>pa + (op @ '- -kb kb) * imscale <>>pa) <>>pa]
              (: pb (imaddr g <>>>e) ka (icfold <>>e)
                 (op = '+ && pb != 'no && ka != 'no ?
                     [<pb (<>pb + ka * imscale <>>pb) <>>pb]
                    'no))))
       'no)
   ; a const float expression at image time -> gem | 'bad (love's doubles are the target's IEEE doubles).
   ; an unsigned int subtree reads mod 2^width: icfold keeps a word's pattern, and (ulong)-1 is no -1.0
   (ffold e) (ffoldw 1 e)
   (nan? v) (elem v '(nan -nan))                    ; ffoldw's nan, with its sign
   (ffoldw w64 e) (atom? e ? 'bad
     ; an int const subtree floats ((double)(1 << N))
     (icfold e @ iv
        (iv != 'no ? (0.0 + (uwid w64 e @ w (? !w iv (: m (1 << w) r (iv % m) (r < 0 ? (r + m) r)))))
        (<e @ 'flo <>e
            'num (0.0 + <>e)
            'cast (flo? <>e ? (ffoldw w64 <>>e) 'bad)
            'un (ffoldw w64 <>>e @ v (? (bad? v) 'bad (<>e != 'neg) 'bad
                                        (nan? v) (v = 'nan ? '-nan 'nan)
                                        (-1.0 * v)))   ; times -1: 0.0 - 0.0 is +0.0, and -0.0 is its own value
            'bin
            (: op <>e a (ffoldw w64 <>>e) b (ffoldw w64 <>>>e)
               (? (bad? a || bad? b) 'bad
                  !(elem op '(+ - * /)) 'bad
                  (nan? a) a
                  (nan? b) b
                  ; love has no nan: an invalid operation (0/0, inf-inf, 0*inf) answers (), and C's is +qnan
                  ((op @ '+ (a + b) '- (a - b) '* (a * b) (a / b)) @ v (gem? v ? v 'nan))))
           'bad))))
   ; a constant int expression's C type, as parse reads the source (suffixed literals arrive cast) | ()
   (icty w64 e)
    (: (both a b) (icty w64 a @ ta (icty w64 b @ tb (ta && tb ? (puac w64 ta tb))))
       (e @ ('num v) (fits32 v ? 'int 'long)
            ('cast t _) (nom? t ? t)
            ('un op x) (elem op '(neg bnot) ? (icty w64 x @ t (t ? (pprom t))) 'int)
            ('bin op a b) (? (elem op '(shl shr)) (icty w64 a @ t (t ? (pprom t)))
                             (elem op '(+ - * / % & | ^)) (both a b)
                             'int)
            ('cond _ a b) (both a b)
            ()))
   (uwid w64 e) (icty w64 e @ 'uint 32 'ulong (w64 ? 64 32) 'ullong 64 ())
   (fim ty v)                                       ; a float value's IEEE image as ty: 4 single bytes | 8 double bytes
    (? (nan? v) (: neg (v = '-nan) (ty = 'float ? (les 4 (neg ? 4290772992 2143289344)) (les 8 (neg ? -2251799813685248 9221120237041090560))))
       (ty = 'float) (les 4 (fbits32 v))
       (les 8 (fbits v)))
   ; sizeof a file-scope object in an initializer, its own too: parse types the name only once
   ; its declaration ends
   (imszof g e)
    (? (!(two? e) || !(elem <e '(bin un cast cond szof))) e
       (<e = 'szof) (<>e @ ('var nm) (peep (g 'glob) nm 0 @ ge
                                        (two? ge && !(gvarr? <>ge) ? ['num (tsz g <>ge)] e))
                       e)
       (<e = 'cast) ['cast <>e (imszof g <>>e)]
       (<e = 'un) ['un <>e (imszof g <>>e)]
       (<e = 'bin) ['bin <>e (imszof g <>>e) (imszof g <>>>e)]
       ['cond (imszof g <>e) (imszof g <>>e) (imszof g <>>>e)])
   (imgbytes g ty ini)                              ; a byte/fix list of length tsz(ty) | 'bad
    (?- 'bad
     (atom? ini) (zeros (tsz g ty))
     (<ini = 'cond) (imsel g ini @ a (a = 'no ? 'bad (imgbytes g ty a)))
     (<ini = 'flo) (? (flo? ty) (fim ty <>ini)
                      (aggish? ty || ptr? ty) 'bad
                      (icfold ['cast ty ini] @ c (c @ 'no 'bad (imnum g ty c))))
     (<ini = 'num) (? (aggish? ty) 'bad
                           (flo? ty) (fim ty (0.0 + <>ini))
                           (ty = 'bool) (imnum g ty (<>ini = 0 ? 0 1))   ; a bool image normalizes (C11 6.3.1.2)
                           (imnum g ty <>ini))
     (flo? ty && elem <ini '(bin un cast))       ; a const float expression: fold, then image
      (ffoldw !(ilp32? g) ini @ v
         (bad? v ? 'bad (fim ty v)))
     (<ini = 'str && arr? ty)
      (: t <>ini n (tsz g ty)
         (map (i \ (i < tally t ? (t i) 0)) ^n))
     (clarr? ty ini) (imgbytes g ty <>>ini)          ; a wide literal at file scope: its init is the image
     ; a compound literal of the object's own aggregate (gcc's constant-literal extension): its init is the image
     (<ini = 'clit && aggish? ty && two? >>ini && tsz g <>ini = tsz g ty) (imgbytes g ty <>>ini)
     ; ..and of a scalar, `(int){ 5 }`: its one item is the image
     (<ini = 'clit && !(aggish? <>ini) && two? >>ini)
      (<>>ini @ ('init (e . _)) (cgimage g ty e) (cgimage g ty <>>ini))
     (ptr? ty) (imaddr g ini @ r                    ; a data pointer: a constant address (word-sized abs label+offset),
                   (r != 'no ? [['fix (wsize g) (ilp32? g ? 'abs32 'abs64) <r <>r]]      ; or a constant integer ((int*)0x1000, a null)
                      (icfold ini @ v (v @ 'no 'bad (imnum g ty v)))))
     ; a label cast to a word-sized integer ((intptr_t)f) is still its address, and so is one
     ; plus or minus a constant ((unsigned long)&init_stack + 16384)
     (elem <ini '(cast bin) && !(aggish? ty) && !(flo? ty) && tsz g ty = wsize g)
      (imaddr g ini @ r
         (? (r != 'no) [['fix (wsize g) (ilp32? g ? 'abs32 'abs64) <r <>r]]
            (<ini = 'bin) (imcexp g ty ini)
            (icfold ini @ v (v @ 'no (imgbytes g ty <>>ini) (imnum g ty v)))))
     (!(aggish? ty) && !(flo? ty) && elem <ini '(bin un cast)) (imcexp g ty ini)
     (<ini = 'init)
      (unelide g 'none ty ini @ nini
       (?- 'bad
        (<nini != 'init) (imgbytes g ty nini)           ; unwrapped ({ "s" } -> the bare literal): re-dispatch
        (arr? ty) (: elt <>ty esz (tsz g elt)
                     (place l idx acc)                     ; -> ((off items)..) | 'bad
                      (atom? l ? acc
                       (: it <l
                          ci (<it = 'didx ? <>it idx)
                          eb (imgpad g elt esz (elval it))
                        (bad? eb ? 'bad (place >l (ci + 1) ([(ci * esz) eb] . acc)))))
                     ps (place <>nini 0 ())
                     (bad? ps ? 'bad (imflat (imsort ps) (<>>ty * esz))))
        (stru? ty)
          ; a bitfield takes no placement: it merges into its unit, overlaid on the flattened image
          (: e (peep (g 'stag) <>ty 0)
             fields <e size <>e
             (place l cur acc bfs)                ; -> (((off items)..) ((uoff uty bits)..)) | 'bad
              (atom? l ? [acc bfs]
               (: it <l
                  ci (<it = 'dfield ? (fidx fields <>it) cur)
                  fe (nthfield fields ci)
                (? (bad? fe) 'bad
                   (anonbr? g fields fe it) (place (<>it + >l) cur acc bfs)
                   ; an empty record lays nothing (its piece would overlay the next member)
                   (stru? <>>fe && tsz g <>>fe = 0) (place >l (fnext g fields ci) acc bfs)
                   (bitf? <>>fe)
                    (icfold (elval it) @ v
                       (v = 'no ? 'bad
                        (place >l (ci + 1) acc (bfmerge g <>fe <>>fe v bfs))))
                   (imgpad g <>>fe (tsz g <>>fe) (elval it) @ fb
                    (bad? fb ? 'bad (place >l (fnext g fields ci) ([<>fe fb] . acc) bfs))))))
             pr (place <>nini 0 () ())
             (bad? pr ? 'bad (bfover g <>pr (imflat (imsort <pr) size)))))))
   ; bitfield units, ((uoff uty value)..): arithmetic only, a 64-bit unit's mask is a big
   (pw2 n) (n < 1 ? 1 (2 * pw2 (n - 1)))
   (bfmerge g uoff bt v rows)
    (: v9 (<>bt @ 'bool (v = 0 ? 0 1) v)    ; a bool field's image normalizes
       m (pw2 <>>>bt)
       lo ((v9 % m + m) % m)                      ; the low `width` bits, a negative wrapped in
       bits (lo * pw2 <>>bt)
       ; a merged row keeps the wider unit, or a bool/char neighbour truncates the write
       ut (bfpk? bt ? bt <>bt)                    ; the type whose size is the unit
       (go l) (? !(two? l) [[uoff ut bits]]
                 (<<l = uoff) (: u9 (tsz g <><l < tsz g ut ? ut <><l)
                                 ([uoff u9 (<>><l + bits)] . >l))
                 (<l . go >l))
       (go rows))
   ; or each unit's bytes into the flattened image; a fixup in the way (one item, eight bytes) refuses
   (bfover g rows bytes)
    (: (lay img uoff ub)
        (: (go l pos acc)
            (? (atom? l) acc
               (fixit? <l)
                (pos + 8 > uoff && uoff + #ub > pos ? 'bad
                   (go >l (pos + 8) (acc + [<l])))
               (: b (uoff <= pos && pos < uoff + #ub ? (<l | ub (pos - uoff)) <l)
                  (go >l (pos + 1) (acc + [b]))))
           (go img 0 ()))
       (fold l img)
        (atom? l ? img
         (lay img <<l (imnum g <><l <>><l) @ n (bad? n ? 'bad (fold >l n))))
       (fold rows bytes))
   (imgpad g ty w val)                              ; imgbytes padded (with zeros) to w bytes | 'bad
    (imgbytes g ty val @ b (bad? b ? 'bad (b + zeros (w - imbytelen b))))
   ; a constant expression parse's cfold left: a float through a cast ((int)(0.867 * (1 << 16))), or
   ; a floating one (2 * 4.5 - 1), which converts as by assignment
   (imcexp g ty ini)
    (imszof g ini @ e
       (icfold e @ v (v @ 'no (icfold ['cast ty e] @ c (c @ 'no 'bad (imnum g ty c))) (imnum g ty v))))
   (cgimage g ty ini)                               ; the full span-padded image | 'bad
    (: raw (imgbytes g ty ini)
       ; round to the word (8 on x64/a64, 4 on t32), past a flexible array's initializer too
       ; an empty object still takes a byte, so two never share an address
       (bad? raw ? 'bad (: n (imbytelen raw) (raw + zeros (aup (max (max 1 (tsz g ty)) n) (wsize g) - n)))))

   ; the inline-asm register file (cgasm; cgdecl reads it for a register variable's pin)
   asmregs '(r0 r1 r2 r3 r5 r6 r7 r8 r9 r10)
   asmpick '(r10 r9 r8 r7 r6 r5 r2 r1 r0)
   ; a64's "w" and x64's "x": a v register, from the caller-saved top (a function with an asm
   ; homes no float); x64's leave the low xmm to the loads' scratch
   asmfp-a64 '(f16 f17 f18 f19 f20 f21 f22 f23)
   asmfp-x64 '(f8 f9 f10 f11 f12 f13 f14 f15)
   (asmfp g) (a64? g ? asmfp-a64 asmfp-x64)
   (freg? r9) (elem r9 asmfp-a64 || elem r9 asmfp-x64)
   asmnames (foldl (t \ i \ "r\(i)" @ s9 (pin t (name s9) s9)) {} ^11)
   (asmreg? g r9) (elem r9 (asmfile g) || a64? g && elem r9 '(r4 lr))   ; lr: the a64 frame saves it, and its epilogue restores
   (asmfile g) (ia32? g ? '(r0 r1 r2 r3 r5 r6) asmregs)      ; i386 has eight registers, esp and ebp aside
   ; i386's esi edi are callee-saved: taken last, and saved (cgasm1). v6-M's constants and most of its
   ; forms reach only the low registers
   (asmpk g) (ia32? g || v6m? g ? '(r2 r1 r0 r6 r5) asmpick)
   ; an x64 xmm0..15 or an a64 v0..31, by name
   (vclob? g c) (: (num k) (: d (chars (snip c k #c))
                              (? (two? d && foldl (\ a ch (a && 48 <= ch <= 57)) 1 d) (foldl (\ a ch (a * 10 + ch - 48)) 0 d) -1))
                   (? (x64t? g && starts? c "xmm") (0 <= num 3 < 16)
                      (a64? g && starts? c "v") (0 <= num 1 < 32)
                      0))
   ; callee-saved seats a clobber may name past the asm file: pushed and popped around the body
   (asmsave? g r9) (? (ia32? g) (elem r9 '(r3 r5 r6))
                      (x64t? g) (r9 = 'r3 || elem r9 csx64)
                      (a64? g) (elem r9 '(r11 r12 r13 r14 r15 r16 r17 r18 r19 r20 r21 r22 r23 r24 r25 r26 r27 r28))
                      (rv64? g) (elem r9 '(r11 r12 r13 r14 r15 r19 r20 r21 r22 r23 r24 r25 r26))
                      (elem r9 '(r5 r6 r7 r8 r9 r10 r11 r12)))
   ; inline asm: the target's GNU dialect (gas.l; neutral text under __attribute__((holo))), spliced as one ('raw ..)
   ; a constraint's register part: r/q/g/rm 'pick, i/n 'imm, m 'mem, a digit ('tie n), rN the nom,
   ; x86's a b c d S D letters by name (rax rbx rcx rdx rsi rdi, Nd dx), ir 'either. a longer
   ; set reads by its letters: immediates alone (x86's I J K L M N e Z beside i n) 'imm, a
   ; register letter among immediates 'either, among memory 'pick
   asmimm '(105 110 73 74 75 76 77 78 101 90)
   (asmc g c9)
    (: n #c9
       c0 (n > 0 ? (c9 0) 0)
       x86 (x64t? g)
       cs (map c9 ^n)
       (in? l) (all (c \ elem c l) cs)
       (? (n < 1) 'bad
          (n = 1 && 48 <= c0 <= 57) ['tie (c0 - 48)]
          (n = 1) (c0 @ 114 'pick 113 'pick 103 'pick 109 'mem
                      112 'pick                                ; "p": an address in a register, %a spells it as memory
                      81 (a64? g ? 'mem 'bad)                  ; a64's Q: a base register alone, [xN]
                      119 (a64? g ? 'fpick 'bad)               ; a64's w: a v register
                      120 (x64? g ? 'fpick 'bad)               ; x64's x: an xmm register
                      97 (x86 ? 'r0 'bad) 98 (x86 ? 'r3 'bad) 99 (x86 ? 'r1 'bad)
                      100 (x86 ? 'r2 'bad) 83 (x86 ? 'r5 'bad) 68 (x86 ? 'r6 'bad)
                      65 (ia32? g ? 'apair 'bad)               ; i386's A: edx:eax
                      (elem c0 asmimm ? 'imm 'bad))
          (c9 = "Nd" || c9 = "dN") (x86 ? 'r2 'bad)
          ; several register letters ("bdS"): whichever of them is free, ('one r..)
          (x86 && in? '(97 98 99 100 83 68))
           ('one . map (c \ c @ 97 'r0 98 'r3 99 'r1 100 'r2 83 'r5 'r6) cs)
          (c9 = "ir" || c9 = "ri" || c9 = "in" || c9 = "ni") 'either
          (in? asmimm) 'imm
          (a64? g && in? '(81 109 111)) 'mem                  ; "Qo": [xN] is offsettable too
          (a64? g && elem 90 cs && elem 114 cs) 'pick         ; "rZ": a register, never a bare 0 where one is spelt
          (in? (asmimm + '(114 113 103 109 111)) && any (c \ elem c '(114 113 103)) cs)
           (any (c \ elem c asmimm) cs ? 'either 'pick)
          (name c9)))
   ; a64: some immediate letter of the set reaches v -- I an add's, J a negated one, K L a
   ; logical immediate at 32 and 64 bits, M N a single mov, Z zero, i n anything
   (a64fit? c9 v)
    (: (addi u) (0 <= u && (u <= 4095 || u % 4096 = 0 && u // 4096 <= 4095))
       (one16 u) (#(filter (k \ ((u >> (16 * k)) & 0xffff) != 0) ^4) <= 1)
       (mov1 z) (: m ((1 << z) - 1) u (v & m) (one16 u || one16 (m - u) || a64bm? v z))
       (fit c) (c @ 73 (addi v) 74 (addi (0 - v)) 75 (a64bm? v 32) 76 (a64bm? v 64)
                    77 (mov1 32) 78 (mov1 64) 90 (v = 0) 105 1 110 1 0)
       (any fit (map c9 ^#c9)))
   ; v at z bits is a logical immediate: a rotated run of ones in an element repeated across it
   (a64bm? v z)
    (: u (v & ((1 << z) - 1))
       (per e) (: h (e // 2) hm ((1 << h) - 1) (h >= 2 && (u & hm) = (u >> h & hm) ? (per h) e))
       e (per z)
       em ((1 << e) - 1) x (u & em)
       y (x ^ (((x << 1) | (x >> (e - 1))) & em))
       (x != 0 && x != em && net (map (k \ y >> k & 1) ^e) = 2))
   ; %-substitute the template: al the operand printers (a modifier letter, 0 for none -> text | 'bad)
   (asmsub tm al)
    (: n #tm
       (go i acc)
        (n <= i ? acc
           (tm i @ c
              (? !(c = 37) (go (i + 1) (acc + string c))
                 (i + 1 < n)
                  (: d (tm (i + 1))
                     md (elem d '(98 119 107 113 99 120 108 97 80 115 104 100 81 82) && i + 2 < n && 48 <= tm (i + 2) <= 57 ? d 0)
                     dx (md ? (tm (i + 2)) d)
                     (? (d = 37) (go (i + 2) "\(acc)%")
                        (48 <= dx <= 57)
                         (dx - 48 @ ix
                            (ix < #al ?
                               (al ix md @ sub (bad? sub ? 'bad (go (i + (md ? 3 2)) (acc + sub))))
                               'bad))
                        'bad))
                 'bad)))
       (go 0 ""))
   ; an "i" operand: a constant -> the number, an address constant (a global, a function, a
   ; string, &a.b[k]) -> its "label+k" text, else 'no. a name a local shadows is no constant
   (asmk g env e)
    (: k (memk g e)
       ; a block-scope static is its data label
       (stat x) (? !(two? x) x
                   (<x = 'var) (assoc <>x env @ (_ . 'g . l . _) ['var l]   ; a lo env's
                                                b (two? b && two? <>b && <<>b = 'glob ? ['var <><>b] x))
                   (stat <x . stat >x))
       e2 (stat e)
       (local? x) (? !(two? x) ()
                     (<x = 'var) (two? (assoc <>x env))
                     (local? <x || local? >x))
       (? (cint? k) k
          (local? e2) 'no
          ; a probe: what it fails to resolve is no refusal's cause, so the pin is left as found
          ((: u0 (g 'undecl) a (imaddr g e2) (pin g 'undecl u0, a)) @ a
             (a @ 'no 'no
                  (: nm (nom? <a ? (show <a) <a) (<>a @ 0 nm (<>a < 0 ? "\(nm)\(<>a)" "\(nm)+\(<>a)")))))))
   ; an operand's byte width, off its type by static peek (a register spells by it on x64)
   (asmw g env e) ((asmcty g e @ k (k ? k (peekty g env e))) @ ty
                     (bad? ty ? 8 (tsz g ty @ n (elem n '(1 2 4 8) ? n 8))))
   ; a constant operand's C type, so "a"(3 * 8) is %eax as in gcc: its literals' and casts'
   ; types through the promotions and conversions. () for anything else
   (asmcty g e)
    (knum g e @ k
       (? (two? k) (k 1)
          (two? e && <e = 'bin)
           (asmcty g (e 2) @ ta
              (? !ta ()
                 (elem (e 1) '(== != < > <= >= && ||)) 'int
                 (elem (e 1) '(<< >>)) (pprom ta)
                 (asmcty g (e 3) @ tb (tb ? (puac !(ilp32? g) ta tb)))))
          (two? e && <e = 'un) (asmcty g (e 2) @ ta (ta ? (pprom ta)))
          ()))
   asmho holo-bytes-open                            ; bare: the cat leads with (borrow 'holo) (asbook.l), so this folds at compile
   ; a template's bytes: one opaque raw, unless it carries a directive or a label beside an
   ; instruction -- then gas-top reads it in place: raw runs split at its labels (numbered per
   ; reading, so an inlined copy lays its own), other sections ride 'fasecs to the object, and a
   ; name it does not define (a goto label, a global) stays a fix
   ; an asm naming no stack or frame register and moving no sp cannot see the frame: its raw runs
   ; wear 'fsafe, so unframe drops the link around them (rawclean takes the mark off)
   asmsp '("%esp" "%ebp" "%rsp" "%rbp" "%sp" "%bp" "push" "pop" "call" "ret" "enter" "leave")
   (asmfsafe txt fs)
    (any (w \ 0 <= findsub txt w) asmsp ? fs (map (f \ (two? f && <f = 'raw ? (f + ['fsafe]) f)) fs))
   (rawclean fs) (map (f \ (two? f && <f = 'raw && 2 < #f ? [<f <>f] f)) fs)
   (asmbody g tgt neutral? txt)
    ; one blob resolves its labels inside it; an absolute label (pushl's) wants the link, so a
    ; template carrying one takes the runs path, its labels the function's own
    (neutral? || gas-plain? tgt txt && !(any (f \ two? f && <f = 'pushl) (gas-text tgt txt)) ?
       [['raw (: prog (neutral? ? (asm-text txt) (gas-text tgt txt))                 (asmho tgt prog (cg-refs prog {})))]]
       (: pf "\(nlab g "\(g 'fn).asm")."
          r (gas-top-in tgt txt "" [1 6] pf (peep (g 'sects) (g 'fn) ".text"))
          _ (two? (r 4) ? (scare 'gas-alias <>(<(r 4))))      ; a template's alias has no C name to land on
          home (foldl (a \ x \ <x = "" ? (x 3) a) () <r)
          ; the prefix rides along: what dead code removes of the home, the record follows out
          (pin g 'fasecs ([(filter (x \ <x != "") <r) (r 1) (r 2) pf (r 3)] . g 'fasecs),
           asmruns tgt home)))
   ; the canary sits at fp-16, under the frame link (fnreset keeps the cell): set from the guard
   ; at entry, compared on every way out. one blob each, every register it borrows put back
   (sspblob g k)
    (: G (sspg g) m <G r (G 1) sy (G 2) o (G 3) tgt (gtgt g)
       gx (? (m = 'tls) (string? sy ? "%\(r):\(sy)" "%\(r):\(o)") (tgt = 'x64) "\(sy)(%rip)" sy)
       ga (m = 'global ? "adrp x9, \(sy)\nldr x9, [x9, :lo12:\(sy)]" "mrs x9, \(r)\nldr x9, [x9, #\(o)]")
       fail (tgt = 'a64 ? "b.eq 1f\nbl __stack_chk_fail\n1:" "je 1f\ncall __stack_chk_fail\n1:")
       txt (? (tgt = 'x64)
               (k = 'set ? "pushq %rax\nmovq \(gx), %rax\nmovq %rax, -16(%rbp)\npopq %rax"
                  "pushq %rax\npushq %r11\nmovq \(gx), %rax\nmovq -16(%rbp), %r11\ncmpq %rax, %r11\npopq %r11\npopq %rax\n\(fail)")
              (tgt = 'i386)
               (k = 'set ? "pushl %eax\nmovl \(gx), %eax\nmovl %eax, -16(%ebp)\npopl %eax"
                  "pushl %eax\nmovl \(gx), %eax\ncmpl %eax, -16(%ebp)\npopl %eax\n\(fail)")
              (k = 'set ? "stp x9, x10, [sp, #-16]!\n\(ga)\nstr x9, [x29, #-16]\nldp x9, x10, [sp], #16"
                 "stp x9, x10, [sp, #-16]!\n\(ga)\nldr x10, [x29, #-16]\ncmp x9, x10\nldp x9, x10, [sp], #16\n\(fail)"))
       (asmbody g tgt () txt))
   ; forms -> raw runs between the labels and aligns, every fix left open for the function's lay
   (asmruns tgt fs)
    (: (flush cur acc) (two? cur ? (rev cur @ p (['raw (asmho tgt p (cg-refs p {}))] . acc)) acc)
       (go l cur acc)
        (!(two? l) ? (rev (flush cur acc))
           (<l @ f
              (two? f && elem <f '(label align) ? (go >l () (f . flush cur acc))
                 (go >l (f . cur) acc))))
       (go fs () ()))
   ; the file-scope asm's sections and every function's, one [secs fns objs weaks]
   (asecs-all g) (asecs-of g (rev (g 'fasecs)))
   (asecs-of g l) (foldl (a \ r \ two? a ? [(<a + <r) (a 1 + r 1) (a 2 + r 2) (a 3 + r 4)] [<r (r 1) (r 2) (r 4)])
                         (g 'asecs) l)
   ; ..less a function asm's whose home dead code removed: its words name labels no longer laid
   (asecs-live g txt)
    (: (lbls x t) (? !(two? x) t (<x = 'label && nom? <>x) (pin t (show <>x) 1) (lbls >x (lbls <x t)))
       have (lbls txt {})
       ; a record is dead when a label of its own asm that it names but does not itself lay is
       ; gone from the text; a label it lays in its own section (`2:` in the table) is no home's
       (live? r) (? !(string? (r 3)) 1
                    (: own (lbls (take 3 r) {})
                       outs (filter (n \ starts? n (r 3) && !(own n)) (map show (keys (cg-refs (take 3 r) {}))))
                       (all have outs)))
       (asecs-of g (filter live? (rev (g 'fasecs)))))
   ; a refusal that names what the asm asked for, for cgfn's report
   asmflags {"e" 'eq "z" 'eq "ne" 'ne "nz" 'ne "c" 'below "b" 'below "nae" 'below
             "nc" 'ae "ae" 'ae "nb" 'ae "a" 'above "nbe" 'above "be" 'be "na" 'be
             "g" 'gt "nle" 'gt "ge" 'ge "nl" 'ge "l" 'lt "nge" 'lt "le" 'le "ng" 'le
             "s" 's "ns" 'ns "o" 'vs "no" 'vc "p" 'p "np" 'np}
   (ontgt g) " on \(peep g 'tgt 'x64)"
   (asmwhy a b) "it has no lane for (\(show a) \(show b))"
   (dblab g d) (u64 (fbits d) @ u
                  (pin (g 'dbls) u 1,
                   dbname u))
   ; a little-endian byte gather (T)p[0] | (T)p[1] << 8 | .. off one unsigned char pointer: one load
   (gather g env e)
    (!(x64? g || a64? g) || abl? g 'gath || sal? g ? ()
       (: (orl x) (x @ ('bin '| a b) (orl a + orl b) [x])
          (unc x) (x @ ('cast _ y) (unc y) x)
          (kn x) (knum g x @ k (two? k && charm? <k ? <k))
          ; a term -> [base byte shift type] | ()
          (trm x)
           (: sy (x @ ('bin 'shl y2 kx) (kn kx @ s (charm? s ? [y2 s])) [x 0])
              (!(two? sy) ? ()
                 (: y <sy ct (y @ ('cast t _) t ()) d (unc y)
                    (!(two? d && <d = 'deref && elem (rotty g env d) '(uchar cchar)) ? ()
                       (: A <>d
                          bk (A @ ('bin '+ b9 kx) (kn kx @ k (charm? k ? [b9 k]))
                                  ('bin '+ kx b9) (kn kx @ k (charm? k ? [b9 k]))
                                  [A 0])
                          (two? bk ? [<bk <>bk <>sy ct]))))))
          ts (map trm (orl e))
          n #ts
          (!(elem n '(2 4 8)) || !(foldl (a \ t \ a && two? t) 1 ts) ? ()
             (: B <<ts T (ts 0 3)
                (fit t) (<t = B && <<t = 'var && t 2 = 8 * <>t && t 3 = T)
                (!(foldl (a \ t \ a && fit t) 1 ts) || !(elem T ints9) || pair? g T ||
                 tsz g T < n || !(sort (map (t \ <>t) ts) = jot n) ? ()
                   ['cast T ['deref ['cast ['ptr (n @ 2 'ushort 4 'uint 'ulong)] B]]])))))
   (lbmen fs l) (!(two? fs) ? 0 ((two? <fs && elem l <fs ? 1 0) + lbmen >fs l))   ; forms naming l
   ; the reciprocal divide (Granlund-Montgomery, libdivide's derivation) -> [M shift add?]; add?
   ; is the case where M wants a 65th bit, folded back by hand. M comes back as its signed representative
   (magic1 d bw sgn)
    (: L (lg2 d)
       W (1 << bw)
       P (1 << (sgn ? (bw - 1 + L) (bw + L)))
       q (P // d)
       r (P - q * d)
       (sig m) (m >= W // 2 ? (m - W) m)
       (d - r < 1 << L ? [(sig ((q + 1) % W)) (sgn ? (L - 1) L) 0]
          [(sig ((q + q + (r + r >= d ? 1 0) + 1) % W)) L 1]))
   ; the immediate lane: the left in a register, a constant on the right -> one imm-form op. a
   ; pointer +/- scales the constant; an unsigned / or % by a power of two reduces to shr/and. (ty forms) | 'no
   (pow2? n) (0 < n && 0 = n & (n - 1))
   ; the selects, tried before the branch lowering -> a value | 'no: `c ? 1 : 0` over a relation is
   ; its own value; `a < b ? a : b` and its twins are minsd/maxsd (strict lt/gt: <= differs on a
   ; signed zero); calm, deref-free, non-trapping int arms ride a cmov -- both arms evaluate before
   ; the condition, so nothing that could fault, trap or be written by it may speculate
   (relish? e) (two? e && (e @ ('bin op _ _) (elem op '(eq ne lt le gt ge))
                              ('land _ _) 1 ('lor _ _) 1 ('un 'not _) 1 ()))
   (rot4? g) (x64t? g || a64? g)             ; carries the rotate ops (ror4/rorv/rorv4); elsewhere the shifts stand
   (rotc? g w big n)                                ; big reads (W - n), n pure and shared
    (big @ ('bin '- wide sub)
             (rotk g wide @ kb
                (charm? kb && kb = w && sub = n && rotp? n)))
   (rotk g e)
    (knum g e @ k (two? k ? <k (cfold !(ilp32? g) e)))
   ; the rotate idiom (x >> n) | (x << (W - n)), x an unsigned W-bit pure operand: one rotate.
   ; a rotl count rides negated (the count reads mod W)
   (rotp? e)                                        ; pure: safe to evaluate once for the source's twice
    (e @ ((k . _) && elem k '(num flo flof str var)) 1
         ((k . x . _) && elem k '(deref dot moor addr)) (rotp? x)
         ('cast _ x) (rotp? x)
         ('bin _ a b) (rotp? a && rotp? b)
         ('un _ x) (rotp? x)
         ())
   (rotw g env e)                                   ; -> 32 | 64 | (): the unsigned rotate width; ilp32's long long is a pair
    (rotty g env e @ 'uint 32 'ulong (ilp32? g ? 32 64) 'ullong (ilp32? g ? () 64))
   ; does the AST write anything? a face's base register must survive the rhs, so a
   ; store rides the face only past a write-free right side (calls clobber the pool too)
   (wrany? (a . u))
    (elem a '(asn post call asm vastart vaarg sexpr) || wrany? a || wrany? u)
   (rotty g env e)                                  ; the operand's declared type, by static peek
    (e @ ('var _) (peekty g env e @ t (bad? t ? () t))
         ('cast . ty . _) ty
         ('deref p) (rotty g env p @ t (? (ptr? t) <>t (arr? t) <>t ()))
         ('bin op x y && elem op '(+ -))         ; index arithmetic keeps the ptr/arr side's type
          (rotty g env x @ a
             (ptr? a || arr? a ? a
                (rotty g env y @ b (ptr? b || arr? b ? b)))))
   (asmno g msg) (pin g 'nolane msg, 'bad)
   ; an asm's operands seated and its template spelt, for either backend -> [ops9 asgn kills saves csops
   ; labs tls txt neutral? scr] | 'bad: ops9 GNU order, asgn each one's register, kills the caller-saved
   ; and vector clobbers, saves the callee-saved ones pushed around the body
   (asmplan g env s)
    (: _ (pin g 'hasasm 1)
       tmpl <>s
       tgt (gtgt g)
       neutral? (two? >>>>>>s)                      ; the holo attribute: the template is neutral text
       ; asm goto's labels, mangled as the statement's lbl; %lN spells one, and the blob leaves them as fixes
       labs (map (nm \ (name "\(g 'fn).\(nm)")) <>>>>>s)
       ; one operand list, GNU order: ('o|'x reg expr w) an output (x in-out), ('i reg expr w) a
       ; register input, ('b reg (addr expr) 0) a memory input or output, ('g text 0 0) one at a
       ; rip-relative address constant, ('m imm 0 0) an
       ; immediate, ('f reg expr 1 cond) a flag output, ('k sp expr 8) the stack pointer as it stands
       (pinof k e) (k @ 'pick ((g 'lovpin) g env e @ p (nom? p ? p k)) k)
       ; a 64-bit register operand on thumb rides a pair, %Q its low register and %R its high
       (pr? e2) (t32? g && elem <e2 '(o x i) && e2 3 = 8)
       ; i386's A: a 64-bit value rides edx:eax, a narrower one eax
       (apw k e) (k = 'apair && asmw g env e < 8 ? 'r0 k)
       ; x64's memory operand at an address constant is `sym+k(%rip)`, as gcc spells it, and takes no
       ; register: paravirt's `call *%[op]` must stay the six-byte `ff 15` the kernel patches. a
       ; segment's operand keeps the register: holo lays no %gs: store at a rip address
       (riptext e) (? (neutral? || gtgt g != 'x64 || 0 <= findsub tmpl "s:") () (asmk g env ['addr e] @ v (string? v ? v ())))
       (oconv l acc)
        (!(two? l) ? (rev acc)
           (: c <<l n #c
              h (0 < n ? (c 0) 0)
              c2 (1 < n && c 1 = 38 ? (snip c 2 n) (snip c 1 n))    ; "=&r": the early clobber is the picking rule already
              k (h @ (61 || 43) (asmc g c2) 'bad)
              fc (c2 @ ("@cc" + (f && 0 < #f)) (peep asmflags f ()) ())
              gv (<><l @ ('var nm) (two? (peep (g 'gregs) nm ())) ())
              ; the stack-pointer register variable ("+r"(current_stack_pointer)) is sp as it stands:
              ; nothing loads it or stores it back
              (? (gv && elem h '(61 43)) (oconv >l (['k 'sp <><l 8] . acc))
                 (0 < #c2 && c2 0 = 64)
                  ; a flag output: a picked register the condition sets right after the body
                  (h = 61 && nom? fc && x64t? g ? (oconv >l (['f 'pick <><l 1 fc] . acc))
                     (asmno g "an asm flag output \"\(c)\"\(ontgt g)"))
                 (bad? k || elem k '(imm either) || two? k && <k != 'one) (asmno g "an asm output constrained \"\(c)\"")
                 ; a memory output is the asm's own store: its address rides a register, as "m" in
                 (k = 'mem) (oconv >l ((riptext <><l @ v (v ? ['g v 0 0] ['b 'pick ['addr <><l] 0])) . acc))
                 (oconv >l ([(h @ 43 'x 'o) (pinof (apw k <><l) <><l) <><l (asmw g env <><l)] . acc)))))
       (iconv l acc)
        (!(two? l) ? (rev acc)
           (: k (asmc g <<l) e <><l
              v (elem k '(imm either) ? (asmk g env e) 'no)
              (k @ 'bad (asmno g "an asm input constrained \"\(<<l)\"")
                   'imm (v != 'no ? (iconv >l (['m v 0 0] . acc)) (asmno g "an asm immediate input that is not a constant"))
                   'either ((a64? g ? (cint? v && a64fit? <<l v) (charm? v)) ? (iconv >l (['m v 0 0] . acc)) (iconv >l (['i (pinof 'pick e) e (asmw g env e)] . acc)))
                   'mem (iconv >l ((riptext e @ v (v ? ['g v 0 0] ['b 'pick ['addr e] 0])) . acc))
                   (iconv >l (['i (pinof (apw k e) e) e (asmw g env e)] . acc)))))
       os (oconv <>>s ())
       is9 (iconv <>>>s ())
       ; an input pinned where an output is ("=a"(n) : "a"(0), cpuid's) is that output's tie
       (oix l k j) (? !(two? l) () (elem <<l '(o x) && <><l = k) j (oix >l k (j + 1)))
       (tieup e) (: j (<e = 'i && !(two? <>e) && !(elem <>e '(pick fpick)) ? (oix os <>e 0))
                    (charm? j ? ['i ['tie j] <>>e <>>>e] e))
       (bad? os || bad? is9 ? 'bad
          (: ops9 (os + map tieup is9)
             ; pinned registers: validated, a duplicate refuses; a tie takes its output's
             (pinset l acc)
              (!(two? l) ? acc
                 (: e2 <l k <>e2
                    (? (elem <e2 '(m k g) || elem k '(pick fpick) || two? k) (pinset >l acc)
                       (k = 'apair) (elem 'r0 acc || elem 'r2 acc ? 'bad (pinset >l ('apair . 'r0 . 'r2 . acc)))
                       !(asmreg? g k) 'bad
                       ; an input may take a half of the A pair it is read before
                       (elem k acc) (<e2 = 'i && elem k '(r0 r2) && elem 'apair acc && !(elem ['i k] acc) ? (pinset >l (['i k] . acc)) 'bad)
                       (pinset >l (k . acc)))))
             pinned (pinset ops9 ())
             (bad? pinned ? (asmno g "an asm register pinned twice, or one no operand may take")
              (any (e2 \ pr? e2 && nom? <>e2 && !(elem <>e2 '(pick fpick))) ops9) (asmno g "a 64-bit asm operand pinned to one register")
                (: (assign l fr acc)
                    (!(two? l) ? (rev acc)
                       (: e2 <l k <>e2
                          (? (elem <e2 '(m k g)) (assign >l fr (k . acc))
                             (two? k && <k = 'one)          ; the first free register of the set
                              (filter (r9 \ elem r9 >k) fr @ c9
                                 (two? c9 ? (assign >l (filter (r9 \ r9 != <c9) fr) (<c9 . acc)) 'bad))
                             (two? k) (<>k < #acc ? (rev acc <>k @ r9 (assign >l fr (r9 . acc))) 'bad)
                             (k = 'apair) (assign >l fr (['r0 'r2] . acc))
                             (k = 'pick && pr? e2)          ; a thumb pair: two registers, lo then hi
                              (two? >fr ? (assign >l >>fr ([<fr <>fr] . acc)) 'bad)
                             (k = 'pick)
                              (two? fr ? (assign >l >fr (<fr . acc)) 'bad)
                             (k = 'fpick)
                              (#(filter freg? acc) @ j (j < #(asmfp g) ? (assign >l fr (asmfp g j . acc)) 'bad))
                             (assign >l fr (k . acc)))))
                   ; no operand takes a register the asm clobbers; past the scratch file, x64 seats
                   ; callee-saved ones, saved around the whole asm
                   ckill (filter nom? (map (c \ (neutral? ? (intern c) (gas-regname tgt c)))
                                           (filter (c \ !(c = "memory" || c = "cc" || vclob? g c)) <>>>>s)))
                   ; a vector clobber, as the float file names it
                   vkill (map (c \ name "f\(snip c (starts? c "xmm" ? 3 1) #c)") (filter (vclob? g) <>>>>s))
                   xcs (x64t? g ? '(r3 r11 r12 r13 r14) ())
                   asgn (assign ops9 (filter (r9 \ (nelem r9 pinned && nelem r9 ckill)) (asmpk g + xcs)) ())
                   ; a v register's bits ride a free gp register in and out of it
                   scr (bad? asgn ? () (filter (r9 \ nelem r9 asgn && nelem r9 pinned && nelem r9 ckill && nelem r9 '(r0 r1)) (asmpk g) @ l9 (two? l9 ? <l9)))
                   (clobs l acc)
                    (!(two? l) ? (rev acc)
                       (<l @ c
                          (c = "memory" || c = "cc" ? (clobs >l acc)
                             ; a vector register: a function with an asm homes no float (hasasm), so
                             ; none is live in one across the body and the clobber needs no save
                             (vclob? g c) (clobs >l acc)
                             (: r9 (neutral? ? (intern c) (gas-regname tgt c))
                                (? !(nom? r9) (asmno g "an asm clobber of \"\(c)\"")
                                   (asmsave? g r9) (clobs >l (r9 . acc))
                                   (asmreg? g r9) (clobs >l acc)
                                   (asmno g "an asm clobber of \"\(c)\""))))))
                   saves (clobs <>>>>s ())
                   ; a cs register seated as an operand (i386's esi edi, x64's past scratch) is saved around the asm
                   csops (bad? saves || bad? asgn ? () (filter (r9 \ elem r9 asgn && nelem r9 saves) (ia32? g ? '(r5 r6) xcs)))
                   ; an asm goto with outputs jumps to a trampoline per label that stores them
                   ; and goes on; a pushed clobber would leave it a frame deeper than the fall-through
                   outs? (any (e2 \ elem <e2 '(o x f)) os)
                   tls (two? labs && outs? ? (map (_ \ nlab g "\(g 'fn).ag") labs) labs)
                   (? (bad? saves) 'bad
                      (bad? asgn) (asmno g "more asm operands than registers to seat them")
                      (any freg? asgn && !scr) (asmno g "no gp register free to carry a v operand")
                      (two? labs && two? saves) (asmno g "an asm goto with a callee-saved clobber")
                      (two? labs && two? csops) (asmno g "an asm goto with an esi or edi operand")
                      (: ; the operand printers, one per kind (neutral: a plain register name, "m" as `rN, 0`)
                         (rtext a9 w) (md \ (? (two? a9) (md @ (0 || 81) (gas-reg tgt <a9 4 0) 82 (gas-reg tgt <>a9 4 0) 'bad)
                                              (elem md '(81 82)) 'bad
                                              (md = 108 || elem md '(115 104 100)) 'bad (md = 97 && !neutral?) (gas-mem tgt a9) neutral? (md ? 'bad (peep asmnames a9 "r?")) (gas-reg tgt a9 w md)))
                         (itext v) (md \ (? (md = 108 || elem md '(115 104 100)) 'bad neutral? (md || !(cint? v) ? 'bad (show v))
                                               ; x64's %a of an address constant is rip-relative, as gcc spells it, but under a
                                               ; segment, which holo lays only absolute; %P and %c stay absolute
                                               (md = 97 && tgt = 'x64 && !(cint? v) && findsub tmpl "s:" < 0) "\(v)(%rip)"
                                               (gas-imm tgt v md)))
                         (mtext a9) (md \ (? md 'bad neutral? "\(peep asmnames a9 "r?"), 0" (gas-mem tgt a9)))
                         (ltext l9) (md \ (md = 108 ? (show l9) 'bad))
                         ; a v register: plain is v, s h d b q its scalar views; x64's is xmm, x too
                         (ftext a9) (md \ (? neutral? 'bad
                                             (: n9 (snip (show a9) 1 #(show a9))
                                                (? (x64? g) (md = 0 || md = 120 ? "%xmm\(n9)" 'bad)
                                                   (md @ 0 "v\(n9)" 115 "s\(n9)" 104 "h\(n9)" 100 "d\(n9)"
                                                         98 "b\(n9)" 113 "q\(n9)" 'bad)))))
                         (optext l al acc)
                          (!(two? l) ? (rev acc)
                             (: e2 <l a9 <al
                                (optext >l >al ((<e2 @ 'm (itext a9)
                                                       'b (mtext a9)
                                                       'g (md \ (md ? 'bad "\(a9)(%rip)"))
                                                       'f (md \ 'bad)       ; a flag output has no spelling
                                                       (freg? a9 ? (ftext a9) (rtext a9 <>>>e2))) . acc))))
                         txt (asmsub tmpl (optext ops9 asgn () + map ltext tls))
                         (? (bad? txt) (asmno g "an asm operand the template spells with a modifier it has no lane for")
                            (!neutral? && nom? (gas-nolong tgt txt))
                             (asmno g "an asm \"\(show (gas-nolong tgt txt))\", which 64-bit mode has no encoding for")
                            [ops9 asgn (filter (r9 \ nelem r9 saves) ckill + vkill) saves csops labs tls txt neutral? scr]))))))))

   ; every per-fn pin and its neutral, one roster: a new per-fn pin registers here (the computed
   ; ones -- fn, epi, pool, vslots, fc, sret -- re-pin at their owner)
   (fnreset g)
    (pins g
     'off (g 'sspf ? 16 8)      ; the frame cursor: slot -8 = saved r3 (see epi), -16 the canary
     'slots ()                 ; the frame's object map ((off n)..; nslot appends)
     'fesc ()                  ; escape flag (the sibcall gate reads it)
     'fescv ()                 ; ..a frame address become a value (a musttail call still jumps)
     'lpm ()                   ; lprop's answers: the fn's tree passes are done with them
     'kpm ()                   ; ..and kprop's
     'hasasm ()                ; an asm statement pins it (homing off)
     'twice ()                 ; a call returning twice pins it (no callee-saved pool)
     'ltaken ()                ; the labels a &&L names (a computed goto's targets)
     'fpin (g 'sspf)           ; the frame link is asked for by name (unframe stands off)
     'slal ())                 ; a slot asks more than 8-byte alignment (csframe shifts by the frame's)

   ; __builtin_{add,sub,mul}_overflow(a, b, r): the exact a op b, stored in *r's type modulo its
   ; width, answering whether it did not fit. operands are sign + 64-bit magnitude; a carry past 64
   ; bits overflows. -> an sexpr | ()
   (ovlow g env bi args)
    (: ity '(char schar cchar uchar short ushort int uint long ulong llong ullong)
       ta (peekty g env <args) tb (peekty g env <>args) tr (peekty g env <>>args)
       tt (two? tr && <tr = 'ptr ? <>tr ())
       ; all three a signed machine word: the machine's own flag answers it (cgbuiltin's lane)
       (sw? ty) (!(usg? ty) && tsz g ty = wsize g)
       (? !(#args = 3 && elem ta ity && elem tb ity && elem tt ity && tsz g ta <= 8 && tsz g tb <= 8 && tsz g tt <= 8) ()
          (sw? ta && sw? tb && sw? tt) ()
          (: k (peep g 'ovn 0) _ (pin g 'ovn (k + 1))
             (v n) ['var ".ov\(k)\(n)"]
             (d n ty e) ['decl [[".ov\(k)\(n)" ty e]]]
             U 'ullong
             (sgn n x ty) (usg? ty ? ['num 0] ['bin 'lt ['cast 'llong x] ['num 0]])
             (mag n x) ['cond n ['un 'neg ['cast U x]] ['cast U x]]
             sub (bi = "__builtin_sub_overflow") mul (bi = "__builtin_mul_overflow")
             na (v "na") ma (v "ma") nb (v "nb") mb (v "mb") m (v "m") n (v "n") o (v "o")
             w (8 * tsz g tt) M32 ['num 4294967295]
             ; add/sub: like signs add; unlike subtract the smaller magnitude from the larger, keeping its sign
             add [(d "s" 'int ['bin 'eq na nb])
                  (d "m" U ['cond (v "s") ['bin '+ ma mb] ['cond ['bin 'ge ma mb] ['bin '- ma mb] ['bin '- mb ma]]])
                  (d "o" 'int ['land (v "s") ['bin 'lt m ma]])
                  (d "n" 'int ['cond (v "s") na ['cond ['bin 'ge ma mb] na nb]])]
             ; mul: the low word wraps as the machine's; a high half times a high half, a cross
             ; product past 32 bits, or the carry adding it, overflows
             mu [(d "m" U ['bin '* ma mb])
                 (d "ah" U ['bin 'shr ma ['num 32]]) (d "bh" U ['bin 'shr mb ['num 32]])
                 (d "c" U ['bin '+ ['bin '* (v "ah") ['bin '& mb M32]] ['bin '* ['bin '& ma M32] (v "bh")]])
                 (d "o" 'int ['lor ['land (v "ah") (v "bh")]
                               ['lor ['bin 'ne ['bin 'shr (v "c") ['num 32]] ['num 0]]
                                     ['bin 'lt m ['bin '* ['bin '& ma M32] ['bin '& mb M32]]]]])
                 (d "n" 'int ['land ['bin '^ na nb] ['bin 'ne m ['num 0]]])]
             ; fits *r: within its range, a negative only where it is signed
             fit (usg? tt ?
                    ['land ['lor ['un 'not n] ['bin 'eq m ['num 0]]] (w < 64 ? ['bin 'le m ['num (2 ** w - 1)]] ['num 1])]
                    ['cond n ['bin 'le m ['num (2 ** (w - 1))]] ['bin 'le m ['num (2 ** (w - 1) - 1)]]])
             ; a plain &x stores to x by name: taking its address would escape x and cost its sibcalls
             rx (<>>args @ ('addr ('var _)) <><>>args ())
             ['sexpr
              ([(d "a" ta <args) (d "b" tb <>args)] + (rx ? () [(d "r" tr <>>args)]) +
               [(d "na" 'int (sgn "a" (v "a") ta)) (d "ma" U (mag na (v "a")))
                (d "nb0" 'int (sgn "b" (v "b") tb)) (d "mb" U (mag (v "nb0") (v "b")))
                (d "nb" 'int (sub ? ['un 'not (v "nb0")] (v "nb0")))]
               + (mul ? mu add)
               + [['expr ['asn (rx || ['deref (v "r")]) ['cast tt ['cond n ['un 'neg m] m]]]]])
              ['lor o ['un 'not fit]] 'int])))
   ; -- the inline lane: a small (or always_inline) fn splices its body at the call site, each arg in
   ; a fresh 8-byte temp, each return into r0 then a jump to the splice's end label --
   ; an always_inline body splices without its canary, each return as written: the caller's frame is the one guarded
   (sspcut x)
    (? !(two? x) x
       (x @ ('blk (('ssp 'set) b ('ssp 'chk))) (sspcut b)
            ('blk (('decl ((_ _ e))) ('ssp 'chk) ('ret ('var _)))) ['ret (sspcut e)]
            ('blk (('expr e) ('ssp 'chk) ('ret ()))) ['ret (sspcut e)]
            ('blk (('ssp 'chk) r)) (sspcut r)
            ('ssp . _) '(nop)
            _ (map sspcut x)))
   ; ..as does any body whose canary guards no buffer: an address-taken scalar (check_mul_overflow's
   ; &t) lives on in a register once spliced, as gcc decides protection after inlining
   (sspbuf? g x)
    (: (arrin? ty d) (? (atom? ty) () (elem <ty '(arr varr)) 1
                        (stru? ty && d < 16) (peep (g 'stag) <>ty () @ e (two? e && any (f \ arrin? <>>f (d + 1)) <e))
                        ())
       (? (atom? x) () (<x = 'decl && two? >x) (any (d \ two? d && arrin? <>d 0) <>x || sspbuf? g >x)
          (sspbuf? g <x || sspbuf? g >x)))
   (noinl? x) (? (elem x '(sdecl goto lbl vastart varr ssp "__builtin_alloca")) 1   ; varr: a VLA's slots ride cgfn's per-fn prescan; ssp its canary cell; alloca the caller's frame
                 (atom? x) ()
                 (x @ ('call _ as && 6 < tally as) 1 ()) 1     ; an overflow-arg call moves sp -- splicing it bars the caller's unframe
                 (noinl? <x || noinl? >x))
   ; a body whose asm names a param in an immediate ("i"(key)) compiles only where spliced, as does
   ; one handing a param to such a body
   (asmneed? g ps x)
    ; a local whose initializer names a param counts as one (arch_static_branch's
    ; `char *k = &((char *)key)[branch]` is constant only once branch is
    (: (dv l pn) (? !(two? l) pn
                    (<l = 'decl) (foldl (a \ d \ (two? >>d && pvl a <>>d) ? (<d . a) a) pn <>l)
                    (dv >l (dv <l pn)))
       (pvl pn e) (!(two? e) ? () (e @ ('var v) (elem v pn) (pvl pn <e || pvl pn >e)))
       pn (dv x (map cap ps))
       (pv? e) (pvl pn e)
       (imm? c) (#c @ n ((: (go i) (? (i >= n) () (elem (c i) '(105 110)) 1 (go (i + 1)))) 0))
       (go y) (? !(two? y) ()
                 (<y = 'asm) (any (o \ imm? <o && pv? <>o) (y 3))
                 (y @ ('call ('var fn) as) (peep (g 'ineed) fn () && any pv? as ? 1 (go as))
                      (go <y || go >y)))
       (go x))
   (noinlj? x) (? (elem x '(sdecl vastart varr "__builtin_alloca")) 1 (atom? x) ()
                  (x @ ('call _ as && 6 < tally as) 1 ()) 1
                  (noinlj? <x || noinlj? >x))
   ; decls and expression statements, then one trailing `return expr`: no arm to copy
   (straight? (i . u))
    (i @ (('decl || 'expr) . _) (straight? u)
         (('ret . rv . _) && two? rv) !(two? u))
   ; a body's weight by its structure: a name, a number or an operator one unit each, and a
   ; __builtin_expect (with the !! it wraps) its operand -- a hint lays no code
   (aweigh x)
    (? !(two? x) 1
       (x @ ('call ('var b9) [a _] && b9 = "__builtin_expect")
             (a @ ('un 'not ('un 'not a2)) (aweigh a2) (aweigh a))
            ('var _) 1
            (foldl (n \ y \ n + aweigh y) 0 x)))
   ; the size gate: 99 straight, 43 branchy, and what the sites cost together, more where one sits
   ; in a loop; -Os, what a call costs
   (inlgate g nm st w)
    (: n (peep (g 'csites) nm 0)
       (? (osz? g) (w <= (st ? 8 4))
          ((st ? 99 43) < w) ()
          (n < 2) 1
          (w * n <= (? (peep (g 'cloop) nm ()) 800 100))))
   (inlok? g f sig aln)                             ; aln: always_inline waives the size gate
    (: rt (two? sig ? <sig 'long)
       items <><>>>f
       ; a double binds and returns in the float file, a float wherever it rides its own lane
       (dbl? ty) (ty = 'double && fsel? g || n32? g ty)
       (pok ps n) (!(two? ps) ? (n <= 6)
                     (<><ps @ pty                               ; a d128 param would bind only its lo word -- a real call takes it
                        (flo? pty && !(dbl? pty) || d128? pty ? ()
                           ; a struct the body never names binds nothing
                           (stru? pty || arr? pty) && ment? <<ps <>>>f ? ()
                           (pok >ps (n + 1)))))
       (ment? nm x) (? !(two? x) () (x @ ('var v) (v = nm) (ment? nm <x || ment? nm >x)))
       (? !(two? sig) ()
          (flo? rt && !(dbl? rt) || stru? rt) ()
          (sig 2) ()                            ; variadic stays a real call
          !(pok <>>f 0) ()
          (!aln && !(inlgate g <>f (straight? items) (aweigh <>>>f))) ()
          (asmneed? g <>>f <>>>f) !(noinlj? <>>>f)
          !(noinl? <>>>f)))
   ; -- the AST inliner: a call to an inline candidate, evaluated by its statement before anything it
   ; sequences (not under && || ?: nor a comma's right), becomes the callee's body ahead of it: each
   ; param a fresh local, each return a store to the call's value; a lone `return e` is e in place, at a
   ; return the returns stay returns, at an if's test each return decides the if, the arms copied there --
   ; a statement that can do nothing drops before a callee is judged (typecheck()'s address compare);
   ; no read counts (a volatile one is an effect), nor a division
   (nofx x) (? !(two? x) x
               (x @ ('expr e) (fxless? e ? '(expr (num 0)) x)
                    (map nofx x)))
   (fxless? e) (e @ ('num . _) 1
                    ('addr ('var _)) 1
                    ('cast _ a) (fxless? a)
                    ('un 'not a) (fxless? a)
                    ('bin op a b) (elem op '(eq ne lt le gt ge + - * & | ^) && fxless? a && fxless? b)
                    (('land || 'lor) a b) (fxless? a && fxless? b)
                    ('sexpr . ss . v . _) ((!(two? v) || fxless? v) && atom? (filter (st \ !(fxlst? st)) ss))
                    ())
   ; a do-while(0) no break or continue leaves is its body, a block without decls its statements:
   ; WRITE_ONCE's wrapping weighs and splices as the store it is
   (do0 x)
    (: (bc? x) (? !(two? x) () (elem <x '(brk cont)) 1 (elem <x '(do while for)) () (<x = 'switch) (co? x) (any bc? x))
       (co? x) (? !(two? x) () (<x = 'cont) 1 (elem <x '(do while for)) () (any co? x))
       (stms ss) (foldr (st \ a \ do0 st @ s2 (s2 @ ('blk l) (any (y \ two? y && <y = 'decl) l ? (s2 . a) (l + a)) (s2 . a))) () ss)
       (? !(two? x) x
          (x @ (('do b ('num 0)) && !(bc? b)) (do0 b)
               ('blk ss) ['blk (stms ss)]
               (map do0 x))))
   (fxlst? st) (st @ ('decl ps) (atom? (filter (p \ two? >>p && <>>p != ()) ps))
                     ('expr e) (fxless? e)
                     ('nop) 1
                     ())
   (acand g nm)                                    ; -> (params body rt locals frees decls) | ()
    (g 'inl nm @ f
       (two? f ?
          (: rf (respell f)
             ps <>>rf
             ; dead arms pruned before any splice, a constant-returning call answered first, at any depth:
             ; a call types by its signature, a cast by its type
             (sty e) (e @ ('call ('var n) _) <(peep (g 'sigs) n [()]) ('cast t _) t ())
             body (nofx (dprune !(ilp32? g) sty (kcall1 g <>(rf 3) 0)))
             (dps x a) (? !(two? x) a
                          (<x = 'decl) (foldl (a2 \ p \ p . a2) a <>x)
                          (dps >x (dps <x a)))
             dl (dps body ())
             loc (map cap ps + map cap dl)
             ; a frame address costs the caller its sibcalls, and a return address read in place is the
             ; caller's, which always_inline waives as gcc reads it. asm, a statement expression, a compound
             ; literal and a struct or array local splice as any body does, under the size gate
             need (peep (g 'ineed) nm ())
             alw (peep (g 'alw) nm ())
             (bar? x) (two? x ?
                         (x @ ('addr ('var v)) (elem v loc)
                              ; the overflow builtins' result pointer is written in place: a local's address there does not escape
                              ('call ('var b9) [a1 a2 a3] && elem b9 '("__builtin_add_overflow" "__builtin_sub_overflow" "__builtin_mul_overflow"))
                               (bar? a1 || bar? a2 || (a3 @ ('addr ('var v)) () (bar? a3)))
                              ('call ('var b9) _ && b9 = "__builtin_frame_address") 1
                              ('call ('var b9) _ && b9 = "__builtin_return_address") !alw
                              (bar? <x || bar? >x)))
             (fv x a) (!(two? x) ? a
                         (x @ ('var v) (elem v loc || elem v a ? a (v . a))
                              (fv >x (fv <x a))))
             (? (bar? body) ()
                [ps body <(peep (g 'sigs) nm ['long ()]) loc (fv body ()) dl need]))))
   ; a callee body's returns -> what rs lays for each, no jump: a return ends the list, or an if arm
   ; that always returns, the rest moving into the other arm | 'no. sw: a trailing switch may end it
   ; too, each case's top-level return a store and a break (a copied arm could carry its own break,
   ; so a push-down passes ())
   (aelim l rs sw)
    (: (hr x) (? !(two? x) () (<x = 'ret) 1 (hr <x || hr >x))
       (swel items)
        (two? items ?
           (: s9 <items
              r1 (!(two? s9) ? [s9]
                    (s9 @ ('ret . e) (rs <e + [['brk]])
                         ('blk bs) (swel bs @ r (r @ 'no 'no [['blk r]]))
                         ('if c t e) (: a (swb t) b (two? e ? (swb e))
                                        (a = 'no || b = 'no ? 'no [['if c a b]]))
                         (hr s9 ? 'no [s9])))
              (r1 @ 'no 'no (swel >items @ r2 (r2 @ 'no 'no (r1 + r2))))))
       (swb x) (swel [x] @ r (? (r = 'no) 'no (two? r && !(two? >r)) <r ['blk r]))
       (ar s) (s @ ('ret . _) 1
                   ('blk items) (foldl (a \ x \ a || ar x) () items)
                   ('if _ t e) (ar t && ar e)
                   ())
       (bl l) (el l @ r (r @ 'no 'no ['blk r]))
       (arm c a b) (a = 'no || b = 'no ? 'no [['if c a b]])
       (el l)
        (two? l ?
           (<l @ s
              (!(hr s) ? (el >l @ r (r @ 'no 'no (s . r)))
                 (s @ ('ret . e) (rs <e)
                      ('blk items) (el (items + >l))
                      ; the parse's else-less if carries a () arm
                      ('if c t e) (? (ar t) (arm c (bl [t]) (bl (two? e ? (e . >l) >l)))
                                     (ar e) (arm c (bl (t . >l)) (bl [e]))
                                     'no)
                      ; ..a tail past the switch moves inside it, last (behind a default when there is none), and a
                      ; copy goes ahead of each switch-level break: every way out still meets it
                      ('switch e items)
                       ('(expr (call (var "__builtin_trap") ())) @ trap
                          (: tl0 >l trap? (two? tl0 && all (x \ (x = trap)) tl0)
                             dfl (foldl (a \ x \ a || (two? x && <x = 'dflt)) () items)
                             ; a break at the switch's own level: not inside a loop or a nested switch
                             (tb s) (s @ ('brk) ['blk (tl0 + [['brk]])]
                                         ('blk bs) ['blk (map tb bs)]
                                         ('if c t e2) ['if c (tb t) (two? e2 ? (tb e2) e2)]
                                         s)
                             (nb s) (s @ ('brk) 1 ('blk bs) (foldl (a \ x \ a + nb x) 0 bs)
                                         ('if _ t e2) (nb t + (two? e2 ? (nb e2) 0)) 0)
                             its (? (trap? || !(two? tl0)) items (map tb items))
                             (? (!sw || two? tl0 && !trap? && 0 < foldl (a \ x \ a + nb x) 0 items && 160 < #(show tl0)) 'no
                                (: r (swel (its + (? (!(two? tl0) || trap?) () dfl tl0 (['dflt] . tl0))))
                                   tl (? (!(two? tl0) || !trap?) () dfl [trap] [['dflt] trap])
                                   (r @ 'no 'no [['switch e (r + tl)]])))))
                      ; ..a trailing loop's top-level returns break out too: with nothing after the loop a break is the
                      ; return (only an empty tail, else the loop's own breaks would meet it)
                      ('while c b) (!sw || two? >l ? 'no (swb b @ r (r @ 'no 'no [['while c r]])))
                      ('do b c) (!sw || two? >l ? 'no (swb b @ r (r @ 'no 'no [['do r c]])))
                      ('for i c st b) (!sw || two? >l ? 'no (swb b @ r (r @ 'no 'no [['for i c st r]])))
                      'no))))
       (el l))
   ; is every mention of p a deref or a call's arg? then p may stand for an address
   (aonly p x)
    (!(two? x) ? 1
       (x @ ('var ^p) ()
            ('deref ('var ^p)) 1
            ('call fh as) (aonly p fh && foldl (a \ e \ a && (e @ ('var ^p) 1 (aonly p e))) 1 as)
            (aonly p <x && aonly p >x)))
   ; rename the callee's locals per m: every var, every decl head. a name m maps to an
   ; expression (&x) stands for it, and its deref for x
   (aren x m)
    (!(two? x) ? x
       (x @ ('var nm) (peep m nm 'no @ v (? (v = 'no) x (two? v) v ['var v]))
            ('deref ('var nm)) (peep m nm 'no @ v (two? v && <v = 'addr ? <>v ['deref (aren <>x m)]))
            ('decl ps) ['decl (map (p \ (peep m <p <p . aren >p m)) ps)]
            (aren <x m . aren >x m)))
   (ainl g f)
    (: rf (respell f)
       tys {} dn {} tak {} sdn {} n9 {'k 0} st9 {'s ()}   ; st9: the statement being laid; sdn the block statics
       ; an expression's static type by the parser's typer over the caller's names: () where unknown
       gty (g 'ainlg @ t
              (t ? t (foldl (a \ k \ pin a k <>(g 'glob k)) {} (keys (g 'glob)) @ t2
                        (pin g 'ainlg t2, t2))))
       ps9 {'locals tys 'lqs {} 'globals gty 'gqs {} 'sigs (g 'sigs) 'stag (g 'stag) 'tgt (g 'tgt)}
       (ety e) (ptype ps9 e @ t (stru? t || arr? t ? () t))
       (tmp ty) (: k (n9 'k) _ (pin n9 'k (k + 1)) t "`c\(k)" (pin tys t ty, t))
       (cen x)                                     ; the caller's names: types, and which are &-taken
        (!(two? x) ? 0
           (x @ ('addr ('var nm)) (pin tak nm 1, 0)
                (('decl || 'sdecl) ps) (map (p \ (pin tys <p <>p, pin dn <p 1, (<x = 'sdecl ? (pin sdn <p 1) 0), cen >>p)) ps, 0)
                (cen <x, cen >x)))
       _ (map (p \ (pin tys <p <>p, pin dn <p 1)) <>>rf)
       _ (cen (rf 3))
       memo (g 'ainlc)
       (cand nm) (peep memo nm 'no @ c
                    (c @ 'no (acand g nm @ c9 (pin memo nm c9, c9)) c))
       crt <(peep (g 'sigs) <>rf ['long ()])
       ; a call's value in its return type: a truth value needs no conversion to an integer type
       (cv e rt) (elem rt '(bool char schar cchar uchar short ushort int uint long ulong) &&
                  (e @ ('bin op _ _) (elem op '(eq ne lt le gt ge)) (('land || 'lor) . _) 1 ('un 'not _) 1 ()) ?
                    e ['cast rt e])
       ; a call spliced here -> (pre value) | () declined. mode: 'val its value, 'br a branch's test,
       ; 'stmt none, 'ret the caller's return (the body's returns stay returns), ('push inv then else) an
       ; if's test, 'expr a conditional or looped position: the body's one expression in place, nothing
       ; hoisted; ('exprh ws) the same where a non-trapping arg may hoist to a decl, not inside ws.
       ; always_inline whose returns do not fold away splices again on the jump lane
       (site nm as d mode) (site1 nm as d mode () @ r
                              (two? r || !(peep (g 'alw) nm ()) ? r (site1 nm as d mode 1)))
       (site1 nm as d mode jf)
        (: c (? (elem nm d || dn nm) ()
                ; a body that compiles only spliced, or always_inline, splices at any depth
                (!(peep (g 'ineed) nm () || peep (g 'alw) nm ()) && 3 < #d) ()
                ; noinstr's no_profile_instrument_function takes always_inline alone, as clang does
                (elem <>rf (g 'nopro) && !(peep (g 'alw) nm ())) ()
                (cand nm))
           xh (two? mode && <mode = 'exprh)
           xo (xh || mode = 'expr)
           xi (two? mode && <mode = 'into)             ; ('into v T): the body's returns store to v, cast T when given
           val? (xo || xi || elem mode '(val br))
           pm (two? mode && !xh && !xi)
           (two? c ?
              (: ps <c body <>c rt <>>c loc (c 3) fr (c 4) dl (c 5) jl (c 6 || jf)
                 one (body @ (('ret e)) (two? e) ())          ; the whole body one `return e`
                 nr9 (: (go x) (? !(two? x) 0 (<x = 'ret) 1 (go <x + go >x)) (go body))
                 ; ..or statements then one: at a test the statements hoist, the return is the test
                 tr1 (mode = 'br && !one && nr9 = 1 && (rev body @ rl (two? rl && <rl @ ('ret e) (two? e) ())))
                 ex (xo ? (flat body (nm . d)))
                 bd (two? ex ? [['ret ex]] body)
                 nocall (foldl (a \ x \ a && !(callish? x)) 1 as)
                 (? (#ps != #as) ()
                    (foldl (a \ v \ a || dn v) () fr) ()          ; a free name the caller shadows
                    ((val? || pm) && rt = 'void) ()
                    (mode = 'br && !one && !tr1 && !jl) ()       ; a branchy test that does not push down stays a call
                    (xo && !(two? ex)) ()
                    ; ..each return past the first lays its own copy of the arms: a few small ones
                    (pm && !jl && 1 < nr9 && (64 < dsz (mode 2) + dsz (mode 3) || 5 < nr9)) ()
                    (: k (n9 'k) _ (pin n9 'k (k + 1))
                       sfx "`a\(k)"
                       m {}
                       _ (map (v \ pin m v (v + sfx)) loc)
                       _ (map (p \ pin tys (m <p) <>p) dl)
                       ; a caller local of the param's type, never &-taken nor written by the body, is the param; so is &x
                       ; of a caller local x the body only derefs or hands a call (a fresh local holding &x would cost the
                       ; frame, so that arg declines). any other binds a fresh local, but in an expression a pure arg read
                       ; at most once (a small one twice, a local or literal any number) stands as (T)arg
                       (bind ps as pre)
                        (!(two? ps) ? pre
                           (: p <ps
                              ; a constant arg folded, and a sizeof the caller's names type (kcalloc's sizeof(*p))
                              a (cfold !(ilp32? g) <as @ kc
                                  (? (cint? kc) ['num kc]
                                     (<as @ ('szof e9) (ptype ps9 e9 @ t9 ((two? t9 ? elem <t9 '(ptr struct) (elem t9 '(char schar cchar uchar short ushort int uint long ulong llong ullong double))) ? ['num (tsz g t9)] <as)) <as)))
                              ty9 (two? a && <a = 'var ? (peep tys <>a 'no) 'no)
                              ax (two? a && <a = 'addr && two? <>a && <<>a = 'var ? <><>a)
                              ; (a block static's address costs no frame: it binds as any arg)
                              tx (string? ax && !(sdn ax) ? (peep tys ax 'no) 'no)
                              (? ; a struct param the body never names: only the arg's effects stay
                                 (stru? <>p || arr? <>p) (bind >ps >as (pure? a ? pre (pre + [['expr a]])))
                                 ; ..and a scalar one the pruned body never names, when its arg loads nothing
                                 (rdw <p bd 1 = 0 && nold? a) (bind >ps >as pre)
                                 (tbare ty9 = tbare <>p && !(tak <>a) && !(wrs? <p bd))
                                  (pin m <p <>a, bind >ps >as pre)
                                 (tx != 'no)
                                  (tbare <>p = ['ptr (tbare tx)] && !(wrs? <p bd) && aonly <p bd ?
                                     (pin m <p a, bind >ps >as pre)
                                     ; always_inline, or a body that compiles only spliced: the frame is the price
                                     (peep (g 'alw) nm () || jl ?
                                        (m <p @ nn (pin tys nn <>p, bind >ps >as (pre + [['decl [[nn <>p a]]]])))
                                        'no))
                                 (xo && nocall && pure? a && !(stru? <>p || arr? <>p) &&
                                  (elem <a '(num var) || rdw <p ex 1 <= (dsz a < 13 ? 2 1)))
                                  (pin m <p ['cast <>p a], bind >ps >as pre)
                                 (xo && !(xh && safe? a <>mode)) 'no
                                 (m <p @ nn (pin tys nn <>p,
                                             bind >ps >as (pre + [['decl [[nn <>p a]]]]))))))
                       pre (bind ps as ())
                       rb (aren bd m)
                       (rc x) (? !(two? x) x
                                 (<x = 'ret) (two? <>x ? ['ret (rt = crt ? <>x (cv <>x rt))] x)
                                 (rc <x . rc >x))
                       rv (? xi <>mode (val? && !one) "`r\(k)" ())
                       (into e) (cv e rt @ v [['expr ['asn ['var rv] (mode 2 ? ['cast (mode 2) v] v)]]])
                       ; a test pushed down: each return's value decides the caller's if in place, the arms copied under
                       ; armk (walked one level up by hs); a re-pushed arm stays absent under its armk
                       (arm? a) (two? a && (<a != 'armk || arm? <>a))
                       (pt e) (: v (cv e rt) kc (cnum g v)
                                 (two? kc ?                    ; a constant return is its arm
                                     (: a ((<kc = 0) = (<>mode = 1) ? (mode 2) (mode 3)) (arm? a ? [['armk a]]))
                                    [['if (<>mode = 1 ? ['un 'not v] v) (arm? (mode 2) ? ['armk (mode 2)] ['blk ()])
                                        (arm? (mode 3) ? ['armk (mode 3)])]]))
                       ; the jump lane: the body's labels take this splice's suffix (asm goto's list
                       ; too), each return stores the value and jumps to the splice's end label
                       lm (: t {} (lb x) (!(two? x) ? 0 (x @ ('lbl v) (pin t v "\(v).\(snip sfx 1 #sfx)", 0) (lb <x, lb >x)))   ; `.`: no C label has one, and gas reads it
                             (jl ? (lb rb) 0, t))
                       (lset l i v) (i = 0 ? (v . >l) (<l . lset >l (i - 1) v))
                       (lren x) (!(two? x) ? x
                                   (x @ ('lbl v) ['lbl (lm v)]
                                        ('goto v) ['goto (peep lm v v)]
                                        ('laddr v) ['laddr (peep lm v v)]
                                        ('asm . _) (map lren x @ y (5 < #y ? (lset y 5 (map (v \ peep lm v v) (y 5))) y))
                                        (map lren x)))
                       jend "`e\(k)"
                       jrv (jl && rt != 'void ? "`r\(k)")
                       ; a void body's `return h();` still calls h: only the value has nowhere to go
                       (jr x) (? !(two? x) x
                                 (<x = 'ret) ['blk (? (jrv && two? >x) [['expr ['asn ['var jrv] (cv <>x rt)]] ['goto jend]]
                                                     (two? >x && two? <>x) [['expr <>x] ['goto jend]]
                                                     [['goto jend]])]
                                 (map jr x))
                       jst (jl ? ((jrv ? [['decl [[jrv rt]]]]) + [['blk (jr (lren rb))] ['lbl jend]]))
                       _ (jrv ? (pin tys jrv rt) 0)
                       el (? (pre = 'no) 'no
                             jl (? xo 'no
                                   (mode = 'ret) (jst + [(jrv ? ['ret ['var jrv]] ['ret])])
                                   pm (jst + pt ['var jrv])
                                   xi (jst + into ['var jrv])
                                   jst)
                             ; the caller's `return f();`: f's returns are the caller's, and a void f
                             ; that runs off its end owes the caller's return there too
                             (mode = 'ret) (rc rb + (rt = 'void && !(: rl (rev rb) (two? rl && two? <rl && <<rl = 'ret)) ?
                                                      [['ret]]))
                             xi (aelim rb (e \ (two? e ? (into e))) 1)
                             (xo || val? && one) rb
                             tr1 (: rl (rev rb) r (hx <>(<rl) (nm . d))       ; the trailing return is the test
                                    [(hitems (rev >rl) (nm . d) + <r) (cv <>r rt)])
                             pm (aelim rb pt !(hasjmp? (mode 2) || hasjmp? (mode 3)))   ; an arm with a break of its own may not copy under a loop or switch
                             (aelim rb (e \ (? !(two? e) () rv [['expr ['asn ['var rv] e]]] [['expr e]])) 1))
                       (? (el = 'no) ()
                          jl [(pre + hitems el (nm . d)) (mode = 'ret || pm || xi || !jrv ? () ['var jrv])]
                          (mode = 'ret || pm || xi) [(pre + hitems el (nm . d)) ()]
                          tr1 [(pre + <el) <>el]
                          xo [pre (cv <><rb rt)]
                          (val? && one) (hx <><rb (nm . d) @ r [(pre + <r) (cv <>r rt)])
                          (: _ (rv ? (pin tys rv rt) 0)
                             ; one return, the last statement: the value is a decl from it (kprop reads those)
                             rl (rev el)
                             tl (two? rl ? (<rl @ ('expr ('asn ('var ^rv) e)) [e] ()))
                             st (? !rv el
                                   (two? tl && nr9 = 1) (rev (['decl [[rv rt <tl]]] . >rl))
                                   (['decl [[rv rt]]] . el))
                             [(pre + hitems st (nm . d)) (rv ? ['var rv])])))))))
       ; a test that pushes down -> (inv nm as) | (): a call, or its !, to a candidate of many returns
       (pcall c)
        (: pc (c @ ('call ('var nm) as) [0 nm as] ('un 'not ('call ('var nm) as)) [1 nm as]
                   ('un 'not ('un 'not x)) (pcall x) ())
           cd (pc ? (cand <>pc))
           (two? cd && !(<>cd @ (('ret e)) 1 ()) ? pc))
       ; no call, store or storage: evaluating it any number of times, or not at all, changes nothing
       (pure? x) (? !(two? x) 1 (elem <x '(call callr sys asn rmw post sexpr clit asm)) () (pure? <x && pure? >x))
       ; no load at all, a volatile's included: constants, addresses, an array or a function by name
       (nold? x) (x @ ('num . _) 1
                      ('var _) (ptype ps9 x @ t (arr? t || fn? t))
                      ('addr ('var _)) 1
                      ('cast _ a) (nold? a)
                      ('un _ a) (nold? a)
                      ('bin o a b) (elem o '(eq ne lt le gt ge + - * & | ^) && nold? a && nold? b)
                      ())
       (sub x nm v) (!(two? x) ? x (x @ ('var ^nm) v (sub <x nm v . sub >x nm v)))
       ; may x evaluate ahead of its position, at the statement's head? pure, no trap (no load,
       ; no division), over caller locals nothing else writes: not &-taken, not written in ws
       (safe? x ws) (!(two? x) ? 1
                       (x @ ('var v) (peep tys v 'no != 'no && !(tak v) && !(wrs? v ws))
                            ('deref . _) ()
                            ('bin o _ _ && elem o '(/ %)) ()
                            (pure? x && safe? <x ws && safe? >x ws)))
       ; a body of pure scalar decls and one `return e`: its own candidate calls substituted, each local
       ; read at most once (a local or literal any number of times) stands as (T)init | ()
       (flat items d9)
        (: (hxi l) (map (s9 \ (s9 @ ('ret e) ['ret (hxe e d9 ())]
                                  ('decl ps) ['decl (map (p \ (two? >>p ? (<p . <>p . hxe <>>p d9 () . >>>p) p)) ps)]
                                  s9)) l)
           (go items)
            (two? items ?
               (items @ (('ret e)) (two? e && pure? e ? e)
                        (('decl ps) . rest)
                         (!(two? ps) ? (go rest)
                            (: p <ps
                               r9 (['decl >ps] . rest)
                               (? (!(two? >>p) || two? >>>p || !(pure? <>>p) || stru? <>p || arr? <>p) ()
                                  !(elem <<>>p '(num var) || rdw <p r9 1 <= 1) ()
                                  (go (sub r9 <p ['cast <>p <>>p])))))
                        ()))
           (go (hxi items)))
       ; an expression at a conditional or looped position: a candidate call whose body is one expression
       ; becomes it in place. h: () in a loop, else {'pre 'ws}, the decls args hoist to
       (hxe e d h)
        (!(two? e) ? e
           (e @ ('call ('var nm) as)
                (: as2 (map (a \ hxe a d h) as)
                   s (site nm as2 d (h ? ['exprh (h 'ws)] 'expr))
                   (two? s && two? <s ? (pin h 'pre (h 'pre + <s)) 0,
                    two? s ? <>s ['call ['var nm] as2]))
                ('sexpr . _) (hsx e d)
                (map (x \ hxe x d h) e)))
       (hxh e d f)                                    ; f builds e's form from its hoist box
        (: h {'pre () 'ws (st9 's)} r (f h) [(h 'pre) r])
       ; a candidate call the expression lane left (its body is statements): at a value position
       ; the operand becomes a typed temporary assigned under an if, where the body splices
       (armc? x) (two? x ? (x @ ('call ('var nm) _) (two? (cand nm)) (armc? <x || armc? >x)))
       (cvt ty x) (ty @ 'same x ['cast ty x])
       (hascont? x) (? !(two? x) () (<x = 'cont) 1 (hascont? <x || hascont? >x))
       (hasjmp? x) (? !(two? x) () (elem <x '(brk cont goto)) 1 (hasjmp? <x || hasjmp? >x))
       ; a left operand that decides its && or || (0 &&, 1 ||): the right is never evaluated, nor spliced
       (dcd? e a) (a @ ('num k) (<e = 'land ? (k = 0) (k != 0)) ())
       ; an arm's weight as a copy, or past any budget when a copy would be wrong (a label, a decl)
       (dsz x) (? (x = ()) 0 !(two? x) 1 (elem <x '(lbl case dflt decl sdecl asm)) 99 (dsz <x + dsz >x))
       ; an expression -> (pre e'): only the positions evaluated first are hoisted
       (hx e d)
        (!(two? e) ? [() e]
           (e @ ('call ('var nm) as)
                (: ha (hxl as d)
                   s (site nm <>ha d 'val)
                   (two? s ? [(<ha + <s) <>s] [<ha ['call ['var nm] <>ha]]))
                ('call fh as) (hxl as d @ ha [<ha ['call fh <>ha]])
                ('bin op a b) (: ra (hx a d) rb (hx b d) [(<ra + <rb) ['bin op <>ra <>rb]])
                ; a comma's right evaluates once its left has: the left is a statement, the right hoists
                ('comma a b) (: sa (hs ['expr a] d) rb (hx b d) [(sa + <rb) <>rb])
                ; a short-circuit or a select branches on its first operand, as cbranch lays it -- a
                ; right operand of statements decides a temporary under nested ifs (its test pushes down)
                (('land || 'lor) a b)
                 (: ra (hxb a d)
                    (dcd? e <>ra ? [<ra ['num (<e = 'lor ? 1 0)]]
                  (: rb (hxh e d (hxe b d)) b2 <>rb
                    (!(armc? b2) ? [(<ra + <rb) [<e <>ra b2]]
                       (: t (tmp 'int)
                          s1 ['expr ['asn ['var t] ['num 1]]] s0 ['expr ['asn ['var t] ['num 0]]]
                          st (hs (<e = 'land ? ['if <>ra ['if b2 s1 s0] s0] ['if <>ra s1 ['if b2 s1 s0]]) d)
                          [(<ra + <rb + [['decl [[t 'int]]]] + st) ['var t]])))))
                ('cond c a b)
                 (: rb (hxh e d (h \ [(hxe a d h) (hxe b d h)])) a2 <<>rb b2 <><>rb
                    ty (armc? a2 || armc? b2 ? (ety e))
                    (ty = () ? (hxb c d @ rc [(<rc + <rb) ['cond <>rc a2 b2]])
                       (: t (tmp ty)
                          st (hs ['if c ['expr ['asn ['var t] a2]] ['expr ['asn ['var t] b2]]] d)
                          [(<rb + [['decl [[t ty]]]] + st) ['var t]])))
                ('asn l r) (: rl (hx l d) rr (hx r d) [(<rl + <rr) ['asn <>rl <>rr]])
                ('rmw op l r) (: rl (hx l d) rr (hx r d) [(<rl + <rr) ['rmw op <>rl <>rr]])
                ('post l n) (hx l d @ r [<r ['post <>r n]])
                ('un op a) (hx a d @ r [<r ['un op <>r]])
                ('cast ty a) (hx a d @ r [<r ['cast ty <>r]])
                ('deref a) (hx a d @ r [<r ['deref <>r]])
                ('dot a fl) (hx a d @ r [<r ['dot <>r fl]])
                ('addr a) (hx a d @ r [<r ['addr <>r]])
                ('sexpr . _) [() (hsx e d)]
                ; a brace's items hoist in order: C sequences them no tighter
                ('init items) (: rs (map (it \ (it @ ('dfield fl v) (hx v d @ r [<r ['dfield fl <>r]])
                                                     ('didx n v) (hx v d @ r [<r ['didx n <>r]])
                                                     _ (hx it d))) items)
                                 [(catmap (r \ <r) rs) ['init (map (r \ <>r) rs)]])
                [() e]))
       ; a statement expression splices within itself: its items take calls like a block's, its value's
       ; hoist lands among them
       (hsx e d) (e @ ('sexpr items v ty) (hx v d @ r ['sexpr (hitems items d + <r) <>r ty]) e)
       ; a branch's test: the call its truth decides, through ! and the first operand of && ||
       (hxb e d)
        (e @ ('call ('var nm) as)
             (: ha (hxl as d)
                s (site nm <>ha d 'br)
                (two? s ? [(<ha + <s) <>s] [<ha ['call ['var nm] <>ha]]))
             ('un 'not a) (hxb a d @ r [<r ['un 'not <>r]])
             ; a right operand of statements at a test decides a temporary under the left's if
             (('land || 'lor) a b)
              (: ra (hxb a d)
                 (dcd? e <>ra ? [<ra ['num (<e = 'lor ? 1 0)]]
               (: rb (hxh e d (hxe b d)) b2 <>rb
                 ty (armc? b2 ? (ety b))
                 (ty = () ? [(<ra + <rb) [<e <>ra b2]]
                    (: tv (tmp ty)
                       st (hs (<e = 'land ? ['if <>ra ['expr ['asn ['var tv] b2]] ['expr ['asn ['var tv] ['num 0]]]]
                                              ['if <>ra ['expr ['asn ['var tv] ['num 1]]] ['expr ['asn ['var tv] b2]]]) d)
                       [(<ra + <rb + [['decl [[tv ty]]]] + st) ['var tv]])))))
             (hx e d))
       (hxl l d) (!(two? l) ? [() ()]
                    (: r (hx <l d) rs (hxl >l d) [(<r + <rs) (<>r . <>rs)]))
       ; a statement -> the statements it becomes
       ; an arm of one statement unwraps, unless a decl (an empty callee's params): an arm takes no decl
       (hb s d) (hs s d @ l (two? l && !(two? >l) && !(elem <<l '(decl sdecl)) ? <l ['blk l]))
       (hs s d) (: s0 (st9 's) _ (pin st9 's s) r (hs1 s d) (pin st9 's s0, r))
       (hs1 s d)
        (!(two? s) ? [s]
           (s @ ('armk s9) (hs s9 >d)                    ; a pushed-down arm: the caller's code
                ('expr ('call ('var nm) as))
                (: ha (hxl as d)
                   st (site nm <>ha d 'stmt)
                   (two? st ? (<ha + <st) (<ha + [['expr ['call ['var nm] <>ha]]])))
                ('ret ('call ('var nm) as))
                 (: ha (hxl as d)
                    st (site nm <>ha d 'ret)
                    (two? st ? (<ha + <st) (<ha + [['ret ['call ['var nm] <>ha]]])))
                ; x = c ? a : b and return c ? a : b are ifs where c pushes down or an arm splices:
                ; each arm cast to the arms' common type first -- a pointer x converts them so itself
                ('expr ('asn lv ('cond c a b)))
                 (: ty (? !(pure? lv && (pcall c || armc? a || armc? b)) () (ptr? (ety lv)) 'same (ety ['cond c a b]))
                    (ty = () ? (hx <>s d @ r (<r + [['expr <>r]]))
                       (hs ['if c ['expr ['asn lv (cvt ty a)]] ['expr ['asn lv (cvt ty b)]]] d)))
                ('ret ('cond c a b))
                 (: ty (? !(pcall c || armc? a || armc? b) () (ptr? crt) 'same (ety ['cond c a b]))
                    (ty = () ? (hx <>s d @ r (<r + [['ret <>r]]))
                       (hs ['if c ['ret (cvt ty a)] ['ret (cvt ty b)]] d)))
                ; x = f(..), or (T) f(..): the body's returns store to x
                ('expr ('asn ('var v) x))
                 (: cx (x @ ('call ('var nm) as) [nm as ()] ('cast ty ('call ('var nm) as)) [nm as ty] ())
                    (!(two? cx) ? (hx <>s d @ r (<r + [['expr <>r]]))
                       (: ha (hxl <>cx d)
                          st (site <cx <>ha d ['into v (cx 2)])
                          c2 ['call ['var <cx] <>ha]
                          (two? st ? (<ha + <st)
                             (<ha + [['expr ['asn ['var v] (cx 2 ? ['cast (cx 2) c2] c2)]]])))))
                ('expr ('comma a b)) (hs ['expr a] d + hs ['expr b] d)   ; a, b; is two statements
                ('expr e) (hx e d @ r (<r + [['expr <>r]]))
                ('decl ps)
                 ; an init may name its own decl (sizeof *h): what hoists above it may not
                 (: (men nm x) (two? x ? (x @ ('var ^nm) 1 (men nm <x || men nm >x)))
                    rs (map (p \ (!(two? >>p) ? [() ()]
                                   (hx <>>p d @ r (men <p <r ? [() <>>p] r)))) ps)
                    (go ps rs) (two? ps ?
                                  (: p <ps r <rs
                                     (<r + [['decl [(two? >>p ? ([<p <>p <>r] + >>>p) p)]]] + go >ps >rs)))
                    (go ps rs))
                ('ret e) (!(two? e) ? [s] (hx e d @ r (<r + [['ret <>r]])))
                ; a test's && || whose right still holds a callee of statements: the right decides its own if
                ; under (or beside) the left's, the small arm copied -- each test then pushes down
                ('if (('land || 'lor) a b) t e && 40 > dsz (? (<<>s = 'land) e t))
                 (: rb (hxh s d (hxe b d)) b2 <>rb
                    (!(armc? b2) ? (hif <>s t e d)
                       (<rb + hs (<<>s = 'land ? ['if a ['if b2 t e] e] ['if a t ['if b2 t e]]) d)))
                ('if c t e) (hif c t e d)
                ; a loop's test of statements: the test is an if at the body's head, a break its
                ; else -- continue runs it again (for a do-while only where the body has no continue)
                ('while c b) (hxe c d () @ c2
                                (!(armc? c2) ? [['while c2 (hb b d)]]
                                   [['while ['num 1] ['blk (hs ['if ['un 'not c2] ['brk] ()] d + [(hb b d)])]]]))
                ('do b c) (hxe c d () @ c2
                             (!(armc? c2 && !(hascont? b)) ? [['do (hb b d) c2]]
                                [['do ['blk ([(hb b d)] + hs ['if ['un 'not c2] ['brk] ()] d)] ['num 1]]]))
                ; a step that is a call is the body's last statement where no continue skips to it:
                ; there a callee of statements splices
                ('for i c ('call ('var nm) _) b && !(hascont? b) && two? (cand nm))
                 (hs ['for i c () ['blk [b ['expr <>>>s]]]] d)
                ('for i c st b) (hxe c d () @ c2
                                   (!(armc? c2) ? [['for (hxe i d ()) c2 (hxe st d ()) (hb b d)]]
                                      [['for (hxe i d ()) ['num 1] (hxe st d ()) ['blk (hs ['if ['un 'not c2] ['brk] ()] d + [(hb b d)])]]]))
                ('switch e items) (hx e d @ r (<r + [['switch <>r (hitems items d)]]))
                ('blk items) [['blk (hitems items d)]]
                [s]))
       (hif c t e d)
        (: pc (pcall c)
           ha (pc ? (hxl (pc 2) d))
           st (pc ? (site <>pc <>ha d ['push <pc t e]))
           ; ..declined (arms too big to copy): the callee's value lands in a temporary of its
           ; return type instead, and the if tests that
           fl (!(pc && !(two? st)) ? ()
                 (: rt <>>(cand <>pc) tv (tmp rt)
                    s9 (hs ['expr ['asn ['var tv] ['call ['var <>pc] <>ha]]] d)
                    ((s9 @ (('expr ('asn _ ('call . _)))) 1 ()) ? ()      ; the call stayed: no temporary then
                       (<ha + [['decl [[tv rt]]]] + s9 + [['if (<pc = 1 ? ['un 'not ['var tv]] ['var tv]) (hb t d) (hb e d)]]))))
           (? (two? st) (<ha + <st)
              (two? fl) fl
              (hxb c d @ r (<r + [['if <>r (hb t d) (hb e d)]]))))
       (hitems l d) (two? l ? (hs <l d + hitems >l d))
       [<rf <>rf <>>rf ['blk (hitems (dprune !(ilp32? g) ety <>(rf 3)) [<>rf])]])
   ; a test that folds (in C's types) prunes its dead arm before anything splices in: gcc's
   ; `__builtin_constant_p(n) ? f(n) : g(n)` never lays f's "i"(n). an arm a jump may reach (a label,
   ; a case) stays; a ?: prunes only where ty types both arms alike, keeping that type by a cast. a
   ; splice's own labels (`e0) are reached from inside it alone
   (lbl? x) (? (atom? x) () (<x = 'lbl) !(string? <>x && starts? <>x "`") (elem <x '(case dflt)) 1 (lbl? <x || lbl? >x))
   ; a local asking more alignment than the frame base (fbal) lives in a char block of
   ; its size plus the ask, used through a pointer rounded up to the ask; an initializer builds in a
   ; compound literal and copies in. the rewrite stops past a decl that shadows the name
   (oalign g f)
    (: fb (fbal g)
       (ask p) (max (tal g <>p) (4 < #p ? (p 4) 0))
       (big? p) (!(gvarr? <>p) && fb < ask p)
       (shadow? it x) (two? it && <it = 'decl ? (any (q \ <q = x) <>it) 0)
       (sub x xp e)
        (? (atom? e) e
           (e = ['var x]) ['deref ['var xp]]
           (: (go l) (atom? l ? l
                        (sub x xp <l @ h (shadow? <l x ? (h . >l) (h . go >l))))
              (go e)))
       (nm1 g) (peep g 'aln 0 @ k (pin g 'aln (k + 1), show k))
       (one p rest)                                   ; -> (items rest') for one big record
        (: x <p ty <>p init <>>p a (ask p) sz (tsz g ty) k (nm1 g)
           xb "\(x).alb\(k)" xp "\(x).alp\(k)"
           adr ['cast ['ptr ty] ['bin '& ['bin '+ ['cast 'ulong ['var xb]] ['num (a - 1)]] ['num (0 - a)]]]
           ini (? (atom? init) ()
                  (!(arr? ty) || !(elem <init '(init str))) [['expr ['asn ['deref ['var xp]] (elem <init '(init str) ? ['clit ty init] init)]]]
                  ; an array moves as a one-member struct of its bytes: struct assignment copies inline
                  (['struct "\(x).als\(k)"] @ st
                     (pin (g 'stag) <>st [[[".m" 0 ty]] sz a],
                      [['expr ['asn ['deref ['cast ['ptr st] ['var xp]]]
                                     ['deref ['cast ['ptr st] ['addr ['clit ty init]]]]]]])))
           [([['decl [[xb ['arr 'char (sz + a)] ()]]] ['decl [[xp ['ptr ty] adr]]]] + ini)
            (sub x xp rest)])
       (items l)
        (atom? l ? l
           (: it (rec <l) ps (two? it && <it = 'decl ? <>it)
              (? (two? >ps && any big? ps) (items (map (q \ ['decl [q]]) ps + >l))   ; a record a decl
                 (two? ps && big? <ps) (one <ps >l @ r (<r + items <>r))
                 (it . items >l))))
       (rec e) (? (atom? e) e (<e = 'blk) ['blk (items <>e)] (map rec e))
       (two? (f 3) && <(f 3) = 'blk ? ([<f <>f <>>f (rec (f 3))] + >>>>f) f))
   ; a __builtin_constant_p whose operand does not fold yet: an inline body's param, decided
   ; once the caller's constants have reached it
   (bcpopen? w64 x) (? (atom? x) () (<x = 'bcp) !(cint? (cfold w64 <>x)) (bcpopen? w64 <x || bcpopen? w64 >x))
   ; zfold: a test settled whatever its unknown parts hold (`e & 0`, `e * 0`, `e && 0`, `e || 1` over a
   ; pure e) -> its value | (). zpure?: a statement expression is pure when what it holds is
   (zpure? x) (? !(two? x) 1 (elem <x '(call callr sys asn rmw post clit asm)) () (zpure? <x && zpure? >x))
   ; -- a call to a function that is `return E`, E constant whatever its params hold (its own such
   ; calls answered first), over pure args, is that constant --
   (kret g nm d)
    (peep (g 'kretm) nm 'none @ m
       (? (m != 'none) m
          (: e (peep (g 'fnret) nm ())
             ; the answer in the function's own return type: a bool's `return 5` is 1
             rt <(peep (g 'sigs) nm [()])
             k (? (!(two? e) || 4 < d || !(elem rt '(bool char schar cchar uchar short ushort int uint long ulong))) ()
                  (zfold !(ilp32? g) (kcall1 g e (d + 1)) @ v (cint? v ? (cfold !(ilp32? g) ['cast rt ['num v]] @ c (cint? c ? c ())) ())))
             (pin (g 'kretm) nm k, k))))
   (kcall1 g x d) (? !(two? x) x
                     (x @ ('call . ('var nm) . as . _)
                           (kret g nm d @ k (cint? k && all zpure? as ? ['num k] (map (y \ kcall1 g y d) x)))
                          (map (y \ kcall1 g y d) x)))
   (kcall g f) ([<f <>f <>>f (kcall1 g (f 3) 0)] + >>>>f)
   (zfold w64 x)
    (cfold w64 x @ v
       (? (cint? v) v
          !(two? x) ()
          (x @ ('bin . op . a . b . _)
                (elem op '(& *) ? (: va (zfold w64 a) vb (zfold w64 b) (? (va = 0 && zpure? b) 0 (vb = 0 && zpure? a) 0 ())) ())
               ('land . a . b . _)
                (: va (zfold w64 a) vb (zfold w64 b) (? (va = 0) 0 (vb = 0 && zpure? a) 0 (cint? va && cint? vb) 1 ()))
               ('lor . a . b . _)
                (: va (zfold w64 a) vb (zfold w64 b)
                   (? (cint? va && va != 0) 1 (cint? vb && vb != 0 && zpure? a) 1 (va = 0 && vb = 0) 0 ()))
               ('un . 'not . a . _) (zfold w64 a @ va (cint? va ? (va = 0 ? 1 0) ()))
               ('cast . t . a . _) (zfold w64 a @ va (cint? va ? (cfold w64 ['cast t ['num va]]) ()))
               ())))
   (dprune w64 ty x) (dprunel w64 ty lbl? x)
   ; lk: does a piece hold a label that something outside it may reach
   (dprunel w64 ty lk x)
    (atom? x ? x
       (x @ ('cond c a b)
             (: v (bcpopen? w64 c ? () (zfold w64 c)) t (? (!(cint? v) || lk a || lk b) () (ty a = ty b) (ty a) ())
                (!t ? (map (dprunel w64 ty lk) x) ['cast t (dprunel w64 ty lk (v != 0 ? a b))]))
            ('if c th el)
             ((bcpopen? w64 c ? () (zfold w64 c)) @ v
                (!(cint? v) || lk th || lk el ? (map (dprunel w64 ty lk) x)
                   (: s (v != 0 ? th el) (two? s ? (dprunel w64 ty lk s) '(nop)))))
            ; a switch on a constant starts at its case: no case reaches what lies ahead, unless a goto's
            ; label is there or a case stands deeper than the body's own list (Duff's device)
            ('switch c items)
             ((bcpopen? w64 c ? () (zfold w64 c)) @ v
                (: (hit? it) (it @ ('case . lo . r) (two? r ? (lo <= v && v <= <r) (lo = v)) ())
                   (at p l i) (? !(two? l) -1 (p <l) i (at p >l (i + 1)))
                   ; a label converts to the control's type, which is not known here: every value small
                   ; and not negative, where no conversion moves one
                   (sm? n) (cint? n && 0 <= n && n < 2147483648)
                   ok (sm? v && all (it \ (it @ ('case . lo . r) (sm? lo && (!(two? r) || sm? <r)) 1)) items)
                   k (ok ? (at hit? items 0 @ i (i < 0 ? (at (it \ it = '(dflt)) items 0) i)) -1)
                   (glb? l) (any glbl? l)
                   (? (k < 1 || glb? (take k items) || any (it \ !(elem <it '(case dflt)) && ncase? it) items) (map (dprunel w64 ty lk) x)
                      ['switch c (map (dprunel w64 ty lk) (drop k items))])))
            (map (dprunel w64 ty lk) x)))
   (glbl? x) (? !(two? x) () (<x = 'lbl) 1 (glbl? <x || glbl? >x))
   (exits? x) (x @ ('ret . _) 1 ('goto . _) 1 ('blk items) (two? items && exits? (last items)) ())
   ; -- a block ends at an item that always leaves: what follows is unreachable unless a kept jump
   ; names a label in it, or a case stands there; kept labels grow from kept jumps to a fixpoint --
   (ucut f)
    (: (refs x t) (? !(two? x) t
                     (x @ ('goto . n . _) (pin t n 1)
                          ('laddr . n . _) (pin t n 1)
                          ('asm . _) (: _ (5 < #x ? (map (n \ pin t n 1) (x 5)) 0) (refs >x (refs <x t)))
                          (refs >x (refs <x t))))
       (defs x acc) (? !(two? x) acc (<x = 'lbl) (<>x . acc) (defs >x (defs <x acc)))
       (go keep x) (? !(two? x) x (x @ ('blk . items . _) ['blk (cutl keep items)] (map (go keep) x)))
       (cutl keep l) (? !(two? l) l
                        (: h (go keep <l)
                           (exits? h && !(ncase? >l) && !(any keep (defs >l ())) ? [h] (h . cutl keep >l))))
       (fix keep) (: r (go keep (f 3)) t (refs r {}) (all keep (keys t) ? r (fix (foldl (a \ n \ pin a n 1) keep (keys t)))))
       ([<f <>f <>>f (fix {})] + >>>>f))
   (ncase? x) (? !(two? x) () (<x = 'switch) () (elem <x '(case dflt)) 1 (ncase? <x || ncase? >x))
   ; -- respell: a name declared twice in one fn conflates in alive and kprop, so each later decl
   ; respells (nm`2 ..) and its scope's mentions follow; a static local keeps its spelling (its label) --
   ; i386: a param read 3+ times in a fn that calls copies into a local at entry, which the local
   ; allocator may seat across the calls (a param's own homes are the leaf lane's)
   (phome g f)
    (: (cnt nm e) (atom? e ? 0
                     (e @ ('var n) (n = nm ? 1 0)
                          ('addr ('var n)) (n = nm ? 99 0)
                          (foldl (a \ x \ a + cnt nm x) 0 e)))
       (callin? e) (two? e && ((<e == 'call) || callin? <e || callin? >e))
       (vaish? e) (two? e && ((e @ ('var n) (elem n '("__builtin_va_start" "__builtin_va_arg" "__builtin_va_end" "__builtin_va_copy")) ()) || vaish? <e || vaish? >e))
       vari (peep (g 'sigs) <>f () @ s (two? s && s 2))
       ps (f 2) bd (f 3)
       hit (filter (p \ lhomable? <>p && (cnt <p bd @ k ((3 <= k) && (k < 99)))) ps)
       (!(ia32? g) || abl? g 'phome || vari || !(two? hit) || !(callin? bd) || vaish? bd ? f
          ([<f <>f (map (p \ elem p hit ? ("\(<p)`p" . >p) p) ps)
            ['blk (map (p \ ['decl [[<p <>p ['var "\(<p)`p"]]]]) hit + <>bd)]] + >>>>f)))
   (respell f)
    (: cnt {}
       (fresh nm) (1 + peep cnt nm 0 @ k
                     (pin cnt nm k,
                      k = 1 ? nm "\(nm)`\(k)"))
       (re e env)                                   ; an expression (or a type): mentions respell
        (atom? e ? e
           (e @ ('var nm) (assoc nm env @ a (two? a ? ['var <>a] e))
                ; a statement expression's items are a statement run, its value in their scope
                ('sexpr items v ty) (rsle items env () @ r ['sexpr <r (re v <>r) ty])
                (map (x \ re x env) e)))
       (rsle items env acc)                         ; rsl, answering (items env) for what follows
        (!(two? items) ? [(rev acc) env]
           (<items @ s
              (two? s && <s = 'decl ?
                  (rps <>s env () @ r (rsle >items <>r (['decl <r] . acc)))
                 (rsle >items env (rs s env . acc)))))
       (rps ps env acc)                             ; decl pairs -> [pairs env]
        (!(two? ps) ? [(rev acc) env]
           (: p <ps
              nn (fresh <p)
              env2 ([<p nn] . env)
              (rps >ps env2 ([nn (re <>p env2) (re <>>p env2)] + >>>p . acc))))   ; + a register variable's pin
       (rsl items env acc)                          ; a statement run: decls extend env for their siblings
        (!(two? items) ? (rev acc)
           (<items @ s
              (? (two? s && <s = 'decl)
                  (rps <>s env () @ r (rsl >items <>r (['decl <r] . acc)))
                 (two? s && <s = 'sdecl)
                  (foldl (a2 \ p \ [<p <p] . a2) env <>s @ env2
                     (rsl >items env2 (re s env2 . acc)))
                 (rsl >items env (rs s env . acc)))))
       (rs s env)
        (atom? s ? s
           (s @ ('blk items) ['blk (rsl items env ())]
                ('if cnd thn els) ['if (re cnd env) (rs thn env) (rs els env)]
                ('if cnd thn) ['if (re cnd env) (rs thn env)]
                ('while cnd body) ['while (re cnd env) (rs body env)]
                ('do body cnd) ['do (rs body env) (re cnd env)]
                ('for ini cnd stp body)
                 (: r (two? ini && <ini = 'decl ? (rps <>ini env ()) [() env])
                    ini2 (two? <r ? ['decl <r] (re ini env))
                    env2 <>r
                    ['for ini2 (re cnd env2) (re stp env2) (rs body env2)])
                ('switch ce items) ['switch (re ce env) (rsl items env ())]
                (re s env)))
       env0 (foldl (a2 \ p \ (fresh <p, [<p <p] . a2)) () <>>f)
       [<f <>f <>>f (rs (f 3) env0)])
   ; a body of nothing but `return;`
   (empty? b) (b @ ('blk items) (all (it \ it = '(nop) || (<it = 'ret && !(two? >it && two? <>it))) items) ())
   ; a statement calling such a function is its impure arguments alone: gcc's reading too, so the
   ; extern arrays such a call passes need never link
   (nopcall g f)
    (: (go x) (? !(two? x) x
                 (x @ ('expr . ('call . ('var nm) . as . _) . _)
                       (peep (g 'nopf) nm () ? (filter (a \ !(zpure? a)) as @ es (two? es ? ['blk (map (a \ ['expr a]) es)] '(nop)))
                          (map go x))
                      (map go x)))
       ([<f <>f <>>f (go (f 3))] + >>>>f))
   ; -- a static function's param every call here passes as the one constant, and its body never
   ; writes, reads as that constant (gcc's ipa-cp). the calls are read after each caller's own
   ; propagation; a name used other than as a call's head, or spelled in any asm, is out of reach --
   (ipcp g sfns fs)
    (: calls {} esc {} asms {'t ()}
       (scan x) (? !(two? x) 0
                   (x @ ('call . ('var nm) . as . _) (: _ (pin calls nm (as . peep calls nm ())) (scan as))
                        ('var nm) (pin esc nm 1)
                        (('asm || 'tasm) . t . _) (: _ (pin asms 't (t . asms 't)) (scan >>x))
                        (scan <x, scan >x)))
       ; propagation only drops names and asms, never adds one: a body naming no static fn and
       ; holding no asm scans to nothing that counts, propagated or not
       (rel? x) (? !(two? x) ()
                   (x @ ('var nm) (peep sfns nm () && 1)
                        (('asm || 'tasm) . _) 1
                        (rel? <x || rel? >x)))
       ; only a fn glay may lay counts (cgreach): a header's unused static inline is neither scanned
       ; nor substituted
       reach (g 'reach)
       _ (map (f \ (<f = 'fn ? (reach <>f ? (respell f @ r (rel? r ? (scan (lprop g (dprune !(ilp32? g) (e \ ()) (lprop g r)))) (scan r))) 0)
                     (scan f))) fs)
       (spelt? nm) (any (t \ string? t && 1 < #(split nm t)) (asms 't))
       w64 !(ilp32? g)
       ; the substitution: a parameter the body writes, or one of a type no constant stands for, is left alone
       (one f)
        (: nm <>f ps <>>f body (f 3) cs (peep calls nm ())
           (? (!(peep sfns nm ()) || esc nm || spelt? nm || !(two? cs)) f
              (: ws (pwrites body () + pdecls body ())   ; ..or a name a block declares again
                 (kof i) (: vs (map (as \ (i < #as ? (cfold w64 (as i)) ())) cs)
                            (cint? <vs && all (v \ v = <vs) vs ? <vs ()))
                 (go l i acc) (? !(two? l) acc
                                 (: p <l k (kof i)
                                    (go >l (i + 1) (cint? k && nelem <p ws && elem <>p '(bool char schar cchar uchar short ushort int uint long ulong)
                                                     ? ([<p ['cast <>p ['num k]]] . acc) acc))))
                 ks (go ps 0 ())
                 (two? ks ? ([<f <>f <>>f (psub ks body)] + >>>>f) f))))
       (map (f \ (<f = 'fn && reach <>f ? (one f) f)) fs))
   ; the fns glay may lay, fn name -> 1: each one no cut leaves (an export, a used or aliased
   ; static), then every name a reached body or an initializer holds and every word an asm spells,
   ; to closure. a superset of the laid: propagation and the splice only drop names
   (cgreach fs sfns als)
    (: fnx (foldl (t \ f \ (<f = 'fn ? (pin t <>f f) t)) {} fs)
       atg (map als (keys als))
       (idc? c) (c = 95 || 48 <= c <= 57 || 65 <= c <= 90 || 97 <= c <= 122)
       (idws s acc) ((: (go i j acc) (? (#s <= i) (j < i ? (snip s j i . acc) acc)
                                        (idc? (s i)) (go (i + 1) j acc)
                                        (go (i + 1) (i + 1) (j < i ? (snip s j i . acc) acc))))
                     0 0 acc)
       (refs x asm acc) (? (string? x) (asm ? (idws x (x . acc)) (x . acc))
                           !(two? x) acc
                           (: a (asm || <x = 'asm || <x = 'tasm) (refs >x a (refs <x a acc))))
       reach {}
       (visit nm) (? (reach nm) 0
                     (two? (fnx nm)) (: _ (pin reach nm 1) (foldl (_ \ n \ visit n) 0 (refs (fnx nm) () ())))
                     0)
       (root? f) (? (<f != 'fn) (foldl (_ \ n \ visit n) 0 (refs f () ()))
                    ((peep sfns <>f 'no @ s (s = 'no || s = 'used)) || elem <>f atg) (visit <>f)
                    0)
       (foldl (_ \ f \ root? f) 0 fs, reach))
   (pwrites x acc) (? !(two? x) acc
                      (x @ (('asn || 'post) . ('var v) . _) (pwrites >>x (v . acc))
                           ('rmw . _ . ('var v) . _) (pwrites >>>x (v . acc))
                           ('addr . ('var v) . _) (v . acc)
                           ('asm . _) (foldl (a \ o \ <>o @ ('var v) (v . a) a) acc (x 2 + x 3))   ; any asm operand stays a name
                           (pwrites >x (pwrites <x acc))))
   (pdecls x acc) (? !(two? x) acc (x @ (('decl || 'sdecl) . ps . _) (foldl (a \ p \ (<p . a)) acc ps) (pdecls >x (pdecls <x acc))))
   ; a __builtin_constant_p keeps its param: ipa-cp is no inlining, so it reads 0 as in any other shape
   (psub ks x) (? !(two? x) x (x @ ('var v) (assoc v ks @ e (two? e ? <>e x)) ('bcp . _) x (map (psub ks) x)))
   ; -- straight-line propagation: in a block, past `x = K` (or an op= whose answer is K whatever x
   ; held) x reads as K up to its next write. a label keeps it only when every write of x is behind it
   ; and no goto came first. a scalar local never &-taken; not across a call that returns twice --
   ; cgfn's chain hands it the same tree again: one answer per tree until fnreset lets them go,
   ; keyed by the statics too, the only names the unit's table gains as fns are laid
   (lprop g f)
    (: m (g 'lpm @ () (: t {} _ (pin g 'lpm t) t) t9 t9)
       k [(g 'statics) f]
       (peep m k 'none @ 'none (: r (lprop0 g f) _ (pin m k r) r) r9 r9))
   (lprop0 g f)
    (: w64 !(ilp32? g)
       tak {} tys {} sds {}                         ; sds: the block statics
       ; an asm's memory operand takes its name's address, as kprop reads it
       mc (a64? g ? '(81 109 111) '(109 111))       ; a64's Q is memory too
       (mem? c) ((: (go i) (? (#c <= i) () (elem (c i) mc) 1 (go (i + 1)))) 0)
       (cen x) (? !(two? x) 0
                  (x @ ('addr ('var nm)) (pin tak nm 1, 0)
                       ; a register variable keeps its pin, as kprop keeps it
                       ('decl ps) (foldl (_ \ p \ (pin tys <p <>p, (two? >>>p ? (pin tak <p 1) 0), cen >>p)) 0 ps)
                       ('sdecl ps) (foldl (_ \ p \ (pin sds <p 1, cen >>p)) 0 ps)
                       ('asm . _) (: _ (foldl (_ \ o \ (mem? <o ? (<>o @ ('var v) (pin tak v 1) 0) 0)) 0 (x 2 + x 3)) (cen <x, cen >x))
                       (cen <x, cen >x)))
       _ (cen (f 3))
       _ (map (p \ pin tys <p <>p) <>>f)            ; a parameter too
       (tw? x) (? !(two? x) () (x @ ('call . ('var n) . _) (elem n twicefns) (tw? <x || tw? >x)))
       ; ..and not a name the unit has at file scope: a block's `extern` reads that one
       (ok? nm) (!(tak nm) && !(two? (peep (g 'glob) nm 0)) && !(g 'fns nm)
                 && elem (peep tys nm ()) '(bool char schar cchar uchar short ushort int uint long ulong))
       ; -- not-equal facts: `x != K` (K small) holds where only the test leads, until x is written or a
       ; label passed; a `switch (x)` there drops `case K` when only the dispatch reaches it. x is a
       ; scalar local, or a member of a local struct never &-taken --
       (mb x) (x @ ('var v) v ('dot . y . _) (mb y) ('idx . y . _) (mb y) ())
       mtk {}
       (mcen x) (? !(two? x) 0
                   (: _ (x @ ('addr e) (mb e @ b (string? b ? (pin mtk b 1) 0))
                             ('asm . _) (foldl (_ \ o \ (mb <>o @ b (string? b ? (pin mtk b 1) 0))) 0 (x 2 + x 3))
                             0)
                      (mcen <x, mcen >x)))
       _ (mcen (f 3))
       ; ..a record of scalars at distinct offsets: no union's overlap, no array decaying to an address
       (rec? ty) (g 'stag <>ty @ e
                    (two? e && (: ms <e
                                  (sc? t) (ptr? t || elem t '(bool char schar cchar uchar short ushort int uint long ulong llong ullong))
                                  (dis l) (? !(two? l) 1 (elem <l >l) () (dis >l))
                                  (two? ms && atom? (filter (m \ !(sc? (m 2))) ms) && dis (map (m \ m 1) ms)))))
       (mok? s) (!(tak s) && !(mtk s) && !(two? (peep (g 'glob) s 0)) && !(g 'fns s)
                 && (peep tys s () @ ('struct . _) (rec? (tys s)) ()))
       (fk a) (a @ ('var v) (ok? v ? v ()) ('dot ('var s) fl) (mok? s ? "\(s).\(fl)" ()) ())
       (nf a e) (: q (fk a) k (e @ ('num n) n ())
                   (string? q && charm? k && 0 <= k && k < 128 ? [[q k]] ()))
       (tf c) (c @ ('bin 'ne a b) (nf a b + nf b a)
                   ('land a b) (tf a + tf b)
                   ('un 'not a) (ff a)
                   (fk c @ q (string? q ? [[q 0]] ())))
       (ff c) (c @ ('bin 'eq a b) (nf a b + nf b a)
                   ('lor a b) (ff a + ff b)
                   ('un 'not a) (tf a)
                   ())
       ; the keys a statement writes, a whole struct's name for a write into it, and what it declares
       (tk t) (t @ ('dot ('var s) fl) "\(s).\(fl)" (mb t))
       (nws x acc) (? !(two? x) acc
                      (x @ (('asn || 'post) . t . _) (nws >>x (tk t . acc))
                           ('rmw . _ . t . _) (nws >>>x (tk t . acc))
                           ('asm . _) (foldl (a \ o \ (tk <>o . a)) acc (x 2))
                           (('decl || 'sdecl) . ps . _) (nws >x (foldl (a \ p \ (<p . a)) acc ps))
                           (nws >x (nws <x acc))))
       (kb k) ((: (go i) (? (#k <= i) k (k i = 46) (snip k 0 i) (go (i + 1)))) 0)
       (nkill ws ng) (filter (e \ nelem <e ws && nelem (kb <e) ws) ng)
       (cln? c) (atom? (filter string? (nws c ())))
       ; a label kills them, but a case of a switch inside the statement is reached from that switch alone
       (lbl? x) (? !(two? x) () (<x = 'lbl) 1 (lbl? <x || lbl? >x))
       (lab2? x) (? !(two? x) () (<x = 'switch) (lbl? x) (elem <x '(lbl case dflt)) 1 (lab2? <x || lab2? >x))
       (uj? x) (x @ (('goto || 'brk || 'cont || 'ret) . _) 1 ('blk is) (two? is && uj? (is (#is - 1))) ())
       (scut l ks open)
        (!(two? l) ? ()
           (<l @ ('case k && charm? k && elem k ks && !open)
                 ((: (skip m) (? !(two? m) () (lab? <m) (scut m ks ()) (skip >m))) >l)
                 (<l . scut >l ks !(uj? <l))))
       (swp sw ng) (sw @ ('switch sc body)
                         (: q (fk sc) ks (foldl (a \ e \ (<e = q ? (<>e . a) a)) () ng)
                            (string? q && two? ks ? ['switch sc (scut body ks ())] sw))
                         sw)
       ; the names a statement writes (an asm's outputs among them), and whether it holds a label
       (wrs x acc) (? !(two? x) acc
                      (x @ (('asn || 'post) . ('var v) . _) (wrs >>x (v . acc))
                           ('rmw . _ . ('var v) . _) (wrs >>>x (v . acc))
                           ('asm . _) (foldl (a \ o \ <>o @ ('var v) (v . a) a) acc (x 2))
                           (wrs >x (wrs <x acc))))
       (lab? x) (? !(two? x) () (elem <x '(lbl case dflt)) 1 (lab? <x || lab? >x))
       (gto? x) (? !(two? x) () (elem <x '(goto igoto)) 1 (<x = 'asm && 5 < #x && two? (x 5)) 1 (gto? <x || gto? >x))
       ; every write of a name, a declaration's initializer one
       (nw t x) (? !(two? x) 0
                   (x @ ('decl . ps . _) (foldl (_ \ p \ ((two? >>p && <>>p != () ? (pin t <p (1 + peep t <p 0)) 0), nw t >>p)) 0 ps)
                        (: _ (map (v \ pin t v (1 + peep t v 0)) (x @ (('asn || 'post) . ('var v) . _) [v] ('rmw . _ . ('var v) . _) [v]
                                                                       ('asm . _) (foldl (a \ o \ <>o @ ('var v) (v . a) a) () (x 2)) ()))
                           (nw t <x, nw t >x))))
       wtot {} wdone {} gs {'g 0}
       _ (nw wtot (f 3))
       (sub env x) (? !(two? x) x (x @ ('var v) (assoc v env @ e (two? e && !(two? >>e) ? <>e x)) (map (sub env) x)))
       ; a pointer declared at an address constant, &g or an array or a function, is that constant to
       ; an asm's immediate input alone ("i"(p), rip_rel_ptr's), read before the asm's outputs are
       (iok? nm) (!(tak nm) && !(two? (peep (g 'glob) nm 0)) && !(g 'fns nm) && ptr? (peep tys nm ()))
       (lcl? x) (? !(two? x) () (x @ ('var v) (two? (peep tys v ())) (lcl? <x || lcl? >x)))
       ; a block static's address is one too: every name in it one of this fn's statics
       (onlys x) (? !(two? x) 1 (<x = 'var) (sds <>x) (onlys <x && onlys >x))
       (iaddr e) (!(lcl? e) && (onlys e || (: u0 (g 'undecl) a (imaddr g e) (pin g 'undecl u0, a != 'no))))
       (imm? c) ((: (go i) (? (#c <= i) () (elem (c i) '(105 110)) 1 (go (i + 1)))) 0)
       (iop env o) (imm? <o ? (<>o @ ('var v) (assoc v env @ e (two? e && two? >>e ? (<o . <>e . >>o) o)) o) o)
       (ias env x) (x @ ('asm . _) (map (j \ (j = 3 ? (map (iop env) (x 3)) (x j))) ^#x)
                        ('expr a) ['expr (ias env a)]
                        x)
       (vsub nm k x) (? !(two? x) x (x = ['var nm]) ['num k] (map (vsub nm k) x))
       ; x's value past `x = rhs`: one constant whatever x held, in x's own type. an rhs that
       ; reads x is one only through a & or * with a zero
       (val nm rhs) (: ty (tys nm)
                       (at k) (cfold w64 ['cast ty (vsub nm k rhs)])
                       (rds? x) (? !(two? x) () (x = ['var nm]) 1 (rds? <x || rds? >x))
                       (z? x) (cfold w64 x @ v (cint? v && v = 0))
                       ok (!(rds? rhs) || (rhs @ ('bin op p q && elem op '(& *)) (z? p || z? q) ()))
                       a (at 0)
                       (ok && cint? a && a = at 1 && a = at (0 - 1) ? (cnum g ['cast ty ['num a]] @ cv (two? cv ? ['cast ty ['num <cv]])) ()))
       ; ..and a name every write of which gives the one K is K at every read
       kv {}
       (one nm k) (peep kv nm 'none @ o (pin kv nm (? (o = 'none) k (o = k) k 'no)))
       (kw x) (? !(two? x) 0
                 (x @ ('decl . ps . _) (foldl (_ \ p \ ((two? >>p && <>>p != () ? (one <p (ok? <p ? (val <p <>>p @ k (two? k ? k 'no)) 'no)) 0), kw >>p)) 0 ps)
                      ('asn . ('var v) . rhs . _) (: _ (one v (ok? v ? (val v rhs @ k (two? k ? k 'no)) 'no)) (kw rhs))
                      (('post || 'rmw) . _) (: _ (map (v \ one v 'no) (wrs x ())) (kw <x, kw >x))
                      ('asm . _) (: _ (map (v \ one v 'no) (wrs x ())) (kw <x, kw >x))
                      (kw <x, kw >x)))
       _ (map (p \ one <p 'no) <>>f)                ; ..whose arrival is no constant
       _ (kw (f 3))
       kenv (foldl (a \ nm \ (kv nm @ k (two? k ? ([nm k] . a) a))) () (keys kv))
       ; reads only: the name an assignment writes stays its own
       (rd x) (? !(two? x) x
                 (x @ ('var v) (assoc v kenv @ e (two? e ? <>e x))
                      ('asn . ('var v) . rhs . _) ['asn ['var v] (rd rhs)]
                      (map rd x)))
       ; top: the body's own list, where an item's writes are counted (a nested one starts with nothing)
       (blk items env ng top)
        (!(two? items) ? ()
           (: it <items
              e0 (lab? it ? (gs 'g || !top ? () (filter (e \ peep wtot <e 0 = peep wdone <e 0) env)) env)
              _ (top ? (nw wdone it) 0)
              _ (gto? it ? (pin gs 'g 1) 0)
              ws (wrs it ())
              e1 (filter (e \ nelem <e ws) e0)
              n0 (lab2? it ? () ng)
              it1 (sub e1 (ias e0 (it @ ('switch . _) (swp it (nkill (nws (it 1) ()) n0)) it)))
              ; a block in the run is entered from above, so it starts with the facts: the not-equal
              ; ones and the immediates'
              it2 (it1 @ ('blk is) ['blk (blk is (filter (e \ two? >>e) e0) n0 ())] (inner it1))
              e2 (it2 @ ('expr . ('asn . ('var v) . rhs . _) . _) (ok? v ? (val v rhs @ k (two? k ? ([v k] . e1) e1)) e1)
                        ('decl ps) (foldl (a \ p \ (? !(two? >>p) a
                                                        (ok? <p) (val <p <>>p @ k (two? k ? ([<p k] . a) a))
                                                        (iok? <p && iaddr <>>p) ([<p ['cast (tys <p) <>>p] 'imm] . a)
                                                        a)) e1 ps)
                        e1)
              (it2 . blk >items e2 (nkill (nws it ()) n0) top)))
       ; a nested block starts over: the entry it is reached by need not be the one above it.
       ; but a loop's body and an if's arms are entered by the test alone, which they keep
       (arm a n) (a @ ('blk is) ['blk (blk is () n ())] (inner a))
       (inner x) (? !(two? x) x
                    (<x = 'blk) ['blk (blk <>x () () ())]
                    (x @ ('for i c st b) ['for (inner i) (inner c) (inner st) (arm b (cln? c ? (tf c) ()))]
                         ('while c b) ['while (inner c) (arm b (cln? c ? (tf c) ()))]
                         ('if c t e) ['if (inner c) (arm t (cln? c ? (tf c) ())) (arm e (cln? c ? (ff c) ()))]
                         (map inner x)))
       ; `0 || e` and `1 && e` are e's truth, evaluated as surely as the test, where the inliner takes it
       (simp x) (? !(two? x) x
                   (x @ ('lor . a . b . _) (zfold w64 a = 0 ? ['un 'not ['un 'not (simp b)]] (map simp x))
                        ('land . a . b . _) (zfold w64 a @ v (cint? v && v != 0 ? ['un 'not ['un 'not (simp b)]] (map simp x)))
                        (map simp x)))
       (tw? (f 3) ? f ([<f <>f <>>f (simp ((rd (f 3)) @ ('blk items) ['blk (blk items () () 1)] (inner (rd (f 3)))))] + >>>>f)))
   ; -- AST constant propagation: a scalar local declared once from a folding initializer, never
   ; written or &-taken, shadowing nothing, reads as its cast literal and its decl drops. runs to a fixpoint --
   ; it runs to its fixpoint, so a tree it answered once answers itself again
   (kprop g f)
    (: m (g 'kpm @ () (: t {} _ (pin g 'kpm t) t) t9 t9)
       (peep m f () ? f (: r (kprop0 g f) _ (pin m r 1) r)))
   (kprop0 g f)
    (: items <><>>>f
       dcl {} tak {} wrt {} ivs {} sdl {}           ; ivs: the locals an asm names as an immediate; sdl the block statics
       (cen x c9)                                   ; one walk: the censuses + the decl pairs seen
        (!(two? x) ? c9
           (: c8 (x @ ('addr ('var nm)) (pin tak nm 1, c9)
                     (('asn || 'post) . ('var nm) . _) (pin wrt nm 1, c9)
                     ; an asm writes its outputs and takes a memory input's address
                     ('asm . _)
                      (: (has? c l) ((: (go i) (? (#c <= i) () (elem (c i) l) 1 (go (i + 1)))) 0)
                         (foldl (_ \ o \ <>o @ ('var nm) (pin wrt nm 1) 0) 0 (x 2),
                          foldl (_ \ o \ (? (has? <o (a64? g ? '(81 109 111) '(109 111))) (<>o @ ('var nm) (pin tak nm 1) 0)
                                            (has? <o '(105 110)) (<>o @ ('var nm) (pin ivs nm 1) 0) 0)) 0 (x 3),
                          c9))
                     (('decl || 'sdecl) ps)
                      (: (dn l a) (!(two? l) ? a
                                     (pin dcl <<l (1 + peep dcl <<l 0),
                                      (<x = 'sdecl ? (pin sdl <<l 1) 0),
                                      dn >l (<x = 'decl && two? >><l ? (<l . a) a)))
                         (dn ps c9))
                     c9)
              c8 (cen <x c8)
              (cen >x c8)))
       cds (cen items ())
       ; ..and what an immediate local's initializer names is one too, so a spliced
       ; `char *k = &((char *)key)[branch]` folds once key's own address has
       (vs x) (? !(two? x) () (<x = 'var) (pin ivs <>x 1) (vs <x, vs >x))
       _ (foldl (_ \ p \ (ivs <p && two? >>p ? (vs <>>p) 0)) 0 cds)
       pns (: (go l a) (!(two? l) ? a (go >l (<<l . a))) (go <>>f))
       (onlys x) (? !(two? x) 1 (<x = 'var) (sdl <>x) (onlys <x && onlys >x))
       (kok nm ty init)
        (? !(1 = peep dcl nm 0) ()
           (tak nm || wrt nm) ()
           (elem nm pns) ()
           (two? (peep (g 'glob) nm 0)) ()
           (g 'fns nm) ()
           ; a pointer an asm names as an immediate reads as its address constant (a spliced jump label's
           ; key); a block static's address is one too: every name in it one of this fn's statics
           (ptr? ty) (ivs nm && (init @ ('addr . _) 1 ('cast _ ('addr . _)) 1 ()) &&
                      (imaddr g init != 'no || onlys init) ?
                        ['cast ty init])
           !(elem ty '(bool char schar cchar uchar short ushort int uint long ulong)) ()
           (: v (bcpopen? !(ilp32? g) init ? 'no (cfold !(ilp32? g) init @ cv (cint? cv ? cv 'no)))   ; any constant init, folded in C's types
              (!(charm? v) ? ()
                 (cnum g ['cast ty ['num v]] @ cv
                    (two? cv ? ['cast ty ['num <cv]])))))
       sbs (: t {}
              (go l) (!(two? l) ? t
                        (: p <l
                           kb (two? >>>p ? () (kok <p <>p <>>p))    ; a register variable keeps its pin
                           (two? kb ? (pin t <p kb),
                            go >l)))
              (go cds))
       (sub x)
        (atom? x ? x
         (x @ ('var nm) (sbs nm @ k (two? k ? k x))
              ; not &&/||: dp answering () is a legitimate tail
              ; a decl every entry of which propagated is a nop, not an empty decl (an if arm takes no decl)
              ('decl ps) (: ds (: (dp l) (? (atom? l) ()
                                              (two? (sbs <<l)) (dp >l)
                                              (sub <l . dp >l))
                                  (dp ps))
                            (two? ds ? ['decl ds] '(nop)))
             (sub <x . sub >x)))
       (atom? (keys sbs) ? f
        (kprop0 g ([<f <>f <>>f] + (['blk (sub items)] . >>>>f)))))

   ; -- a small counted loop unrolled: for (T k = A; k < B; k++) of at most 16 trips, its copies small
   ; in all, a body that neither writes k, takes its address, nor leaves early. each copy reads k as
   ; its literal and spells its own locals apart. a body indexing a small local array by k may run
   ; larger: its copies are what lets sra seat the array --
   (unrl g f)
    (: w64 !(ilp32? g)
       (size x) (atom? x ? 1 (foldl (a \ y \ a + size y) 0 x))
       sm {}                                        ; the small local arrays sra may take
       (cen x) (? (atom? x) 0
                  (<x = 'decl) (map (p \ <>p @ ('arr _ n) (charm? n && n <= 16 ? (pin sm <p 1) 0) 0) <>x)
                  (map cen x))
       _ (cen f)
       (ment? x k) (? (atom? x) () (x @ ('var n) (n = k) (ment? <x k || ment? >x k)))
       (akx? x k) (? (atom? x) ()
                     (x @ ('deref ('bin '+ ('var nm) e)) (sm nm && ment? e k) ()) 1
                     (akx? <x k || akx? >x k))
       (kv e) (cfold w64 e @ v (cint? v ? v ()))
       (nogo? x k)                                  ; something a copy may not repeat, or k may not suffer
        (? (atom? x) ()
           (elem <x '(brk cont goto lbl case dflt switch asm sexpr sdecl)) 1
           (x @ (('asn || 'post || 'rmw) . ('var n) . _) (n = k)
                ('rmw _ ('var n) _) (n = k)
                ('addr ('var n)) (n = k)
                ())
            1
           (foldl (a \ y \ a || nogo? y k) () x))
       (dnames x)                                   ; the locals the body declares
        (? (atom? x) ()
           (<x = 'decl) (map cap <>x)
           (foldl (a \ y \ a + dnames y) () x))
       (copy x k kt i ds)
        (? (atom? x) x
           (x @ ('var n) (? (n = k) ['cast kt ['num i]]
                            (elem n ds) ['var "\(n)`u\(i)"]
                            x)
                ('decl ps) ['decl (map (p \ (elem <p ds ? ("\(<p)`u\(i)" . copy >p k kt i ds) (copy p k kt i ds))) ps)]
                (map (y \ copy y k kt i ds) x)))
       ; the trip: (k ty lo hi) for a loop in the shape, else ()
       (trip ini cnd stp)
        (ini @ ('decl [[k kt e0]])
           (: lo (kv e0)
              st (stp @ ('post ('var k2) 1) (k2 = k)
                        ('asn ('var k2) ('bin '+ ('var k3) e1)) (k2 = k && k3 = k && kv e1 = 1)
                        ())
              (? !(charm? lo) () !st () !(elem kt '(char schar uchar short ushort int uint long ulong)) ()
                 (cnd @ ('bin op ('var k2) e2)
                    (: hi (kv e2)
                       (? (k2 != k || !(charm? hi)) ()
                          (op = 'lt) [k kt lo hi]
                          (op = 'le) [k kt lo (hi + 1)]
                          (op = 'ne && lo <= hi) [k kt lo hi]
                          ()))
                    ())))
           ())
       (walk x)
        (? (atom? x) x
           (x @ ('for ini cnd stp body)
                 (: t (trip ini cnd stp)
                    n (two? t ? (t 3 - t 2) -1)
                    b2 (walk body)
                    (? (n < 0 || 16 < n || (akx? b2 <t ? 2048 512) < n * size b2 || nogo? b2 <t) ['for ini cnd stp b2]
                       (: ds (dnames b2)
                          ['blk (map (i \ copy b2 <t <>t (t 2 + i) ds) ^n)])))
                (map walk x)))
       (abl? g 'unroll ? f (walk f)))
   ; -- a small local array named only by constant-indexed elements becomes those elements as
   ; scalars, which the allocator may seat; a brace of plain items initializes them in order, the
   ; rest zero. no decay, no &, no sizeof, no designator: any other mention leaves the array whole --
   (sra g f)
    (: w64 !(ilp32? g)
       (kv e) (cfold w64 e @ v (cint? v ? v ()))
       (scal? t) (ptr? t || elem t '(char schar cchar uchar bool short ushort int uint long ulong llong ullong double float))
       cand {}                                      ; name -> (elty n)
       dcl {}
       (plain? p2 n) (p2 @ ('init is) (#is <= n && !(any (e \ two? e && elem <e '(dfield didx init)) is)) !(two? p2))
       ; an entry with nothing past its init but a mask, and that not volatile
       (bare? p) (#p = 3 || #p = 7 && take 3 >>>p = [() 0 ()] && !(p 6 & 2))
       (fit? x p) (<x = 'decl && bare? p &&
                   (<>p @ ('arr et n) (scal? et && charm? n && 0 < n <= 16 && plain? (p 2) n) ()))
       (one x p) (pin dcl <p (1 + peep dcl <p 0), fit? x p ? (pin cand <p >(<>p)) 0)
       (cen x) (? (atom? x) 0
                  (elem <x '(decl sdecl)) (map (one x) <>x)
                  (map cen x))
       _ (cen f)
       bad {}
       (elt x) (x @ ('deref ('bin '+ ('var nm) ix)) (cand nm @ c (two? c ? (kv ix @ k (charm? k && 0 <= k < c 1 ? [nm k]))))
                    ())
       ; an element's address is the array's: pointer arithmetic may walk from it
       (scan x) (? (atom? x) 0
                   (x @ ('addr e) (two? (elt e)) ()) (elt <>x @ [nm _] (pin bad nm 1))
                   (two? (elt x)) 0
                   (<x = 'var) (two? (cand <>x) ? (pin bad <>x 1) 0)
                   (map scan x))
       _ (two? (keys cand) ? (scan f))
       ok (filter (nm \ !(bad nm) && peep dcl nm 0 = 1 && !(two? (peep (g 'glob) nm 0)) && !(g 'fns nm)) (sort (keys cand)))
       (sn nm k) "\(nm)`s\(k)"
       (rd ps) (? !(two? ps) ()
                  (elem <<ps ok) (: is (<ps 2 @ ('init l) l ())
                                    (cand <<ps @ [et n] (map (k \ [(sn <<ps k) et (two? is ? (k < #is ? (rw (is k)) '(num 0)))]) ^n) + rd >ps))
                  (rw <ps . rd >ps))
       (rw x) (? (atom? x) x
                 (elt x @ e (? (two? e && elem <e ok) ['var (sn <e <>e)]
                               (<x = 'decl) ['decl (rd <>x)]
                               (map rw x))))
       (abl? g 'sra || !(two? ok) ? f (rw f)))
   ; a pointer parameter nothing keeps: named only through * or ->, its address and its value unasked
   (nocap? p x)
    (? (atom? x) 1
       (x @ ['var n] (n != p)
            ['addr y] !(nmen p y)
            ['dot ['deref ['var _]] _] 1
            ['deref ['var _]] 1
            _ !(any (q \ !(nocap? p q)) x)))
   (nmen nm x) (? (atom? x) 0 (x @ ['var n] (n = nm) (any (nmen nm) x)))
   ; -- a local struct of scalars, named only by member or by & to a call that keeps no pointer,
   ; becomes its members as scalars, which the allocator may seat; around such a call they copy to
   ; the struct and back. one that starts as a copy from memory, or is assigned one as a statement,
   ; reads its members there, through an address taken once. a volatile struct, member or
   ; source stays whole --
   (srs g f)
    (: w64 !(ilp32? g)
       (scal? t) (ptr? t || elem t '(char schar cchar uchar bool short ushort int uint long ulong llong ullong double float))
       (mems t) (t @ ('struct . _) (peep (g 'stag) <>t 0 @ e (two? e ? <e)) ())
       (over a b) (a 1 < b 1 + tsz g (b 2) && b 1 < a 1 + tsz g (a 2))
       (vol? q) (charm? q && q & 2 > 0)
       (clean? t) (mems t @ m (two? m && #m <= 16 && !(any (x \ !(scal? (x 2)) || vol? (x 3)) m) &&
                               !(any (a \ any (b \ !(<a = <b) && over a b) m) m)))
       cand {} dcl {} bad {} use {} site {} inis {} tmps {'k 0 'l ()}
       ; the parser's typer over this fn's names, for a source's mask
       tys {} lqs {} ps9 {'locals tys 'lqs lqs 'globals {} 'gqs {} 'sigs (g 'sigs) 'stag (g 'stag) 'tgt (g 'tgt)}
       (vsrc? e) (vol? (accq ps9 e))
       (mem? e) (e @ (('idx || 'deref || 'dot) . _) 1 0)
       (bind p) (pin tys <p <>p, vol? (p 6) ? (pin lqs <p (p 6)) 0)
       (one x p) (pin dcl <p (1 + peep dcl <p 0), bind p, (mem? (p 2) ? (pin inis <p 1) 0),
                  <x = 'decl && (!(two? (p 2)) || mem? (p 2) && !(vsrc? (p 2))) && !(vol? (p 6)) && clean? <>p ?
                     (pin cand <p <>p) 0)
       (cen x) (? (atom? x) 0
                  (elem <x '(decl sdecl)) (map (one x) <>x)
                  (map cen x))
       _ (map bind <>>f, cen f)
       (cand? nm) (two? (peep cand nm ()))
       (fine? fn) (!(dcl fn) && !(two? (assoc fn <>>f)) && two? (g 'sigs fn) &&
                   (<(g 'sigs fn) @ t (t = 'void || scal? t)))
       (arg nc as i) (as i @ a
                        (a @ (['addr ['var nm]] && cand? nm && fine? (nc 0) && <>nc i = 1 &&
                              !(any (j \ !(j = i) && nmen nm (as j)) ^#as))
                              (pin site nm 1)
                              _ (scan a)))
       ; a whole copy in, its value unread: a statement, or a comma's left
       (eff x) (x @ (['asn ['var nm] m] && cand? nm && mem? m) (vsrc? m ? (pin bad nm 1) (scan m))
                    ['comma a b] (eff a, eff b)
                    _ (scan x))
       (scan x) (? (atom? x) 0
                   (x @ ['expr e] (eff e)
                        ['comma a b] (eff a, scan b)
                        ['dot ['var nm] fl] (cand? nm ? (pin use nm (elem fl (peep use nm ()) ? (use nm) (fl . peep use nm ()))) 0)
                        ['var nm] (pin bad nm 1)
                        ['addr ['var nm]] (pin bad nm 1)
                        ['addr ['dot ['var nm] _]] (pin bad nm 1)
                        ['call ['var fn] as] (g 'nocap fn @ c (map (arg [fn c] as) ^#as))
                        _ (map scan x)))
       _ (two? (keys cand) ? (scan f))
       ok (filter (nm \ !(bad nm) && two? (peep use nm ()) && peep dcl nm 0 = 1 && !(two? (peep (g 'glob) nm 0)) && !(g 'fns nm) && !(peep site nm 0 && peep inis nm 0)) (sort (keys cand)))
       (sn nm fl) "\(nm)`m\(fl)"
       (fty nm fl) (assoc fl (mems (cand nm)) @ m (m 2))
       (rd ps) (? !(two? ps) ()
                  (elem <<ps ok) ((peep inis <<ps 0 ? (ini <ps) (map (fl \ [(sn <<ps fl) (fty <<ps fl) ()]) (use <<ps) + (peep site <<ps 0 ? [<ps]))) + rd >ps)
                  (rw <ps . rd >ps))
       (ini p) ("`p\(<p)" @ t ([t ['ptr <>p] ['addr (rw (p 2))]] . map (fl \ [(sn <p fl) (fty <p fl) ['dot ['deref ['var t]] fl]]) (use <p)))
       (seq l) (two? >l ? ['comma <l (seq >l)] <l)
       (rwcall fn as)
        (: nms (filter (nm \ any (a \ a @ ['addr ['var n]] (n = nm) 0) as) ok)
           c ['call ['var fn] (map rw as)]
           (? !(two? nms) c
              (: in (catmap (nm \ map (fl \ ['asn ['dot ['var nm] fl] ['var (sn nm fl)]]) (use nm)) nms)
                 out (catmap (nm \ map (fl \ ['asn ['var (sn nm fl)] ['dot ['var nm] fl]]) (use nm)) nms)
                 rt <(g 'sigs fn)
                 (? (rt = 'void) (seq (in + [c] + out))
                    (: k (tmps 'k) t "`s\(k)"
                       _ (pins tmps 'k (k + 1) 'l ([t rt ()] . tmps 'l))
                       (seq (in + [['asn ['var t] c]] + out + [['var t]])))))))
       (asg nm m) (: k (tmps 'k) t "`s\(k)"
                     _ (pins tmps 'k (k + 1) 'l ([t ['ptr (cand nm)] ()] . tmps 'l))
                     (seq ([['asn ['var t] ['addr (rw m)]]] + map (fl \ ['asn ['var (sn nm fl)] ['dot ['deref ['var t]] fl]]) (use nm))))
       (rw x) (? (atom? x) x
                 (x @ (['dot ['var nm] fl] && elem nm ok) ['var (sn nm fl)]
                      (['asn ['var nm] m] && elem nm ok) (asg nm m)
                      ['decl ps] ['decl (rd ps)]
                      ['call ['var fn] as] (rwcall fn as)
                      _ (map rw x)))
       (? (abl? g 'srs || !(two? ok)) f
          (rw f @ r (tmps 'l @ l (two? l ? [<r <>r <>>r (r 3 @ ['blk is] ['blk (['decl l] . is)])] r)))))
   ; an overflow builtin over two constant operands into a local only it &-takes and nothing else
   ; writes, answered here: the local's decl takes the exact value at its width, the call whether it
   ; fit, so kprop carries the local on -> f | ()
   (ovfold g f)
    (: w64 !(ilp32? g)
       ity '(char schar cchar uchar short ushort int uint long ulong llong ullong)
       ovs '("__builtin_add_overflow" "__builtin_sub_overflow" "__builtin_mul_overflow")
       tys {} tak {} wrt {}
       (cen x) (? (atom? x) 0
                  (: _ (x @ ('decl ps) (map (p \ pin tys <p <>p) ps)
                            ('addr ('var v)) (pin tak v (peep tak v 0 + 1))
                            (('asn || 'post || 'rmw) . _) (: d (x (<x = 'rmw ? 2 1)) (d @ ('var v) (pin wrt v 1) 0))
                            0)
                     (map cen x)))
       _ (cen f)
       ; the folds: the local -> its value, and each call -> its answer
       val {}
       (ans x)
        (x @ ('call ('var b9) [a b ('addr ('var v))] && elem b9 ovs)
              (: ka (cfty w64 a) kb (cfty w64 b) tt (peep tys v ())
                 (? !(two? ka && two? kb && elem tt ity && tsz g tt <= 8 && peep tak v 0 = 1 && !(wrt v)) ()
                    (: va <ka vb <kb
                       r (? (b9 = "__builtin_add_overflow") (va + vb) (b9 = "__builtin_sub_overflow") (va - vb) (va * vb))
                       m (2 ** (8 * tsz g tt))
                       u (((r % m) + m) % m)
                       _ (pin val v (usg? tt || u < m // 2 ? u (u - m)))
                       ['num (? (usg? tt) (0 <= r && r < m ? 0 1) (0 - m // 2 <= r && r < m // 2 ? 0 1))])))
             ())
       (fold x)
        (? (atom? x) x
           (ans x @ k (two? k ? k (map fold x))))
       f2 (fold f)
       (seat x)
        (? (atom? x) x
           ; an entry it does not take keeps its initializer walked: a statement expression there holds decls
           (x @ ('decl ps) ['decl (map (p \ (peep val <p 'no @ k (k = 'no ? (<p . <>p . seat >>p) [<p <>p ['num k]]))) ps)]
                (map seat x)))
       (atom? (keys val) ? () (seat f2)))
   ; every __builtin_constant_p decided on what inlining and kprop left: 1 where its operand folds,
   ; else 0; the arms that settles pruned, then propagated again
   (bcpfin g f)
    (: w64 !(ilp32? g)
       (has? x) (? (atom? x) () (<x = 'bcp) 1 (has? <x || has? >x))
       (res x) (? (atom? x) x (<x = 'bcp) ['num (charm? (cfold w64 <>x) ? 1 0)] (map res x))
       ; a spliced body's labels are reached from the splice alone: an arm holds one only when a jump
       ; outside it names it (or a case stands in it)
       (refs x t) (? !(two? x) t
                     (x @ (('goto || 'laddr) . n . _) (pin t n (1 + peep t n 0))
                          ('asm . _) (: _ (5 < #x ? (map (n \ pin t n (1 + peep t n 0)) (x 5)) 0) (refs >x (refs <x t)))
                          (refs >x (refs <x t))))
       all (refs f {})
       (lk x) (: inn (refs x {})
                 (go y) (? (atom? y) () (elem <y '(case dflt)) 1
                           (<y = 'lbl) (string? <>y && !(starts? <>y "`") && peep inn <>y 0 < peep all <>y 0)
                           (go <y || go >y))
                 (go x))
       (ucut (has? f ? (kprop g (dprunel w64 (e \ ()) lk (res f))) (dprune w64 (e \ ()) f))))
   (cgfn g f)                                       ; ('fn name params ('blk items)) -> forms | 'bad
    ; ..and once more past the prune: an arm it dropped may have been a name's other value
    (: f (bcpfin g (: k0 (kprop g (lprop g (phome g (respell (oalign g (nopcall g (ainl g (nopcall g (lprop g (kcall g (respell f)))))))))))
                      u0 (unrl g k0)
                      k1 (srs g (sra g (u0 = k0 ? k0 (kprop g u0))))
                      (ovfold g k1 @ k2 (two? k2 ? (kprop g k2) k1)))
                @ f1 (kprop g (ucut (dprune !(ilp32? g) (e \ ()) (lprop g f1)))))
       ; the tree passes probe addresses (kprop's, an asm operand's) before every constant has
       ; arrived; a name such a probe could not resolve is no refusal's cause
       _ (pin g 'undecl ())
       params <>>f
       _ (: (has? x) (? (atom? x) () (<x = 'ssp) 1 (any has? x)) (pin g 'sspf (has? (f 3))))   ; a canary keeps its cell
       _ (fnreset g)                                 ; the whole per-fn pin record wiped
       ; -- VLA prep: each site takes a pointer slot + a size slot, the size zeroed after the param
       ; spill (the decl lane reads 0 = never allocated) --
       _ (pins g 'fn <>f 'vslots {})
       ; an alloca must run where no operand is parked on the stack: under a statement, a cast,
       ; a comma, a ?: or a plain variable's assignment, as another alloca's size, or left of an
       ; operator, which compiles first (| aside: gather may reorder its terms)
       _ (: (ab? e) (e @ ('call ('var n) _) (n = "__builtin_alloca") ())
            (un e) (? !(two? e) () (ab? e) 1 (un <e || un >e))
            (xs e) (? !(two? e) ()
                      (two? <e) (any xs e)
                      (ab? e) (any xs <>>e)
                      (elem <e '(blk if while do for switch case dflt lbl expr ret sexpr)) (any xs >e)
                      (<e = 'decl) (any (d \ two? d && two? >d && two? >>d && xs <>>d) <>e)
                      (e @ ('cast _ x) (xs x) ('comma a b) (xs a || xs b) ('asn ('var _) r) (xs r)
                           ('cond c a b) (xs c || xs a || xs b) ('bin o a b && o != '|) (xs a || un b) (un e)))
            (pin g 'abad (xs (f 3))))
       ; the labels whose address the body takes; a computed goto may land on any of them, so
       ; homing stands off as for an asm (every name is live at the jump). a call that returns
       ; twice does the same: the second return restores callee-saved registers, not memory
       _ (: (lt x acc) (? !(two? x) acc
                          (<x == 'laddr) (elem <>x acc ? acc (<>x . acc))
                          (<x == 'igoto) (pin g 'hasasm 1, lt <>x acc)
                          ((<x == 'call) && (<>x @ ('var n) (elem n twice) ()))
                           (pins g 'hasasm 1 'twice 1, lt >x (lt <x acc))
                          (lt >x (lt <x acc)))
            twice twicefns
            (pin g 'ltaken (rev (lt (f 3) ()))))
       _ (: (dscan prs a2)
               (atom? prs ? a2
                  (<><prs @ ty9
                     (dscan >prs (gvarr? ty9 && 3 < #ty9 ?
                                    (varix ty9 . a2) a2))))
              (vscan x acc)                          ; walk the body for VLA decl sites
               (? !(two? x) acc
                  (<x == 'decl && two? >x) (dscan <>x acc)
                  (vlist x acc))
              (vlist l acc) (atom? l ? acc (vlist >l (vscan <l acc)))
              idxs (vscan (f 3) ())
              (mk l a2)
               (!(two? l) ? a2
                  (: po (ntmp g 'long) so (ntmp g 'long)
                     (pin (g 'vslots) <l [po so],
                      mk >l (a2 + [['st 'r4 so 'r0]]))))
              (two? idxs ? ('((li r0 0)) + mk idxs ())))
       sig (g 'sigs <>f)
       vararg (two? sig ? (sig 2))
       ; the epilogue is per-fn: a vararg t32/rv fn drops its push block on the way out; where the
       ; frame hangs off its top, the restores are csframe's (rests)
       _ (pin g 'epi ((? (vararg && t32? g) (v6m? g ? epi-t16va epi-t32va)
                        ; an i386 struct return pops its hidden pointer: ret $4 (66 ahead of it in a 16-bit segment)
                        (ia32? g && two? sig && sretm? g <sig && !(srreg? g vararg))
                         ('((mov sp r4) (pop r4)) + [['raw ((g 'tgt = 'i386m16 ? [102] ()) + [194 4 0])]])
                        (vararg && rv64? g) epi-rv-va
                        (v6m? g) epi-t16 (arm? g) epi-a64 epi)
             @ e9 (cstop? g ? ('((rests)) + e9) e9)))
       ; lo.l lays after this file: its names resolve at the call
       (mprof 'lo (_ \ (cite 'moon 'lofn) g f params sig) @
         'bad ((cite 'moon 'lorefuse) g)
         fs (mprof 'lotail (_ \ (cite 'moon 'lotail) g fs))))

   ; the data tail -> (dataforms nifforms imgforms extras bssforms rodataforms) | 'bad, extras ((name forms
   ; ro?) ..) per other named section in declaration order. love_nifs packs for the linker's __start_/__stop_
   ; bracket, .image rides last so `love bake` can grow it at the tail.
   (cgdata g)
    (: sects (g 'sects || {})
       consts (g 'consts || {})
       memo (g 'romemo || {})
       (strm nm) (sects nm @ s
                    (s ? s ".data"))
       ; an uninitialized global rides .bss unless it names its own section, as does one whose
       ; initializer images to zeros (gcc's and clang's lay); a const one stays a .rodata candidate
       (bss? nm) (!(sects nm) && (<>>(peep (g 'glob) nm 0) @ init (!(two? init) || !(consts nm) && zero? nm init)))
       (zero? nm init) (image1 nm <>(peep (g 'glob) nm 0) init @ b (!(bad? b) && !(any (x \ x != 0) b)))
       ; a const global rides .rodata only if its image needs no relocation (a pointer the linker
       ; writes stays in .data, gcc's .data.rel.ro: a -pie startup writes the base there), or
       ; under -fno-pie, where no base moves it
       (ro? nm bytes) (consts nm &&
                       (npic? g || !(foldl (a \ x \ a || fixit? x) () bytes)))
       ; a global images more than once (bss?, then 'd or 'z, a const candidate 'r too), so it memoizes;
       ; a refusal images again, its walk pinning the cause
       (image1 nm ty init)
        (memo nm @ m
           (two? m ? <>m
              (cgimage g ty init @ v (bad? v ? v (pin memo nm [1 v], v)))))
       ; zm: 'd the initialized, 'z the bss, 'r the const ones .rodata claims, () everything (a named stream never splits)
       (globs gs want zm acc)
        (? !(two? gs) acc
           !(strm <gs = want) (globs >gs want zm acc)
           (peep (g 'alias) <gs ()) (globs >gs want zm acc)   ; an alias lays no bytes: its label rides its target's
           (elem zm '(d r) && bss? <gs) (globs >gs want zm acc)
           (zm = 'z && !(bss? <gs)) (globs >gs want zm acc)
           (: ge (peep (g 'glob) <gs 0)
              lbl <ge ty <>ge init <>>ge
              _ (pins g 'undecl () g 'datacause () 'clitg <gs 'clitn 0)   ; fresh per global: the refusal below names this one's cause
              bytes (image1 <gs ty init)                ; a constant image | 'bad (label values -> 4d)
              ; a refusal is neither 'r nor 'd: the 'd walk reports it, 'r steps past in silence
              roq (!(bad? bytes) && ro? <gs bytes)
              ; an aligned(N) global pads within the stream (the .o's header carries the max N), as does a type
              ; asking more than the stream's word; the packed streams take none. a named stream has no word
              ; of its own (its header takes the widest), so there every global asks its type's
              an (? (elem want '("love_nifs" ".love.image")) 0
                    (elem want '(".data" ".bss" ".rodata")) (max (peep (g 'aligns) <gs 0) (tal g ty @ ta (8 < ta ? ta 0)))
                    (max (peep (g 'aligns) <gs 0) (tal g ty)))
              ; the cause rides a pin: callers thread a bare 'bad through (bad? x) joins, and a gripe is not one
              (? (zm = 'r && !roq) (globs >gs want zm acc)
                 (zm = 'd && roq) (globs >gs want zm acc)
                 (bad? bytes)
                 (g 'undecl @ u
                    (pin g 'datacause
                         (u ? "undeclared '\(u)' in the initializer of '\(<gs)'"
                            "cannot lay the initializer of '\(<gs)' (\(show init))"),
                     'bad))
                 (: als (: (go l a2) (!(two? l) ? a2
                                          (go >l (g 'alias <l = <gs ?
                                                  (['label (name <l)] . a2) a2)))
                           (go (keys (g 'alias)) ()))   ; a data alias (musl's __stdin_used) names the same bytes
                    (globs >gs want zm (acc + (1 < an ? [['align an]])
                                           + als + [['label lbl]]
                                           + (? (elem want '("love_nifs" ".love.image")) [['raw bytes]]
                                                (elem want '(".data" ".bss" ".rodata")) (exact (own ty init) bytes)
                                                [<(exact (own ty init) bytes)])))))))   ; a named stream: no word's pad past the object
       ; an object's own bytes: its type's, or more where a flexible array's initializer runs past it
       (own ty init) (max (max 1 (tsz g ty)) (imbytelen (imgbytes g ty init)))
       ; an image as its object's own bytes, and the word's padding past them apart: the object
       ; writer reads a symbol's size up to the align (modpost holds a device table to it)
       (exact n bs)
        (: (go l k acc) (? (k <= 0 || !(two? l)) [(rev acc) l] (go >l (k - item-len <l) (<l . acc)))
           (go bs n () @ pp ([['raw <pp]] + (two? <>pp ? [['align 1] ['raw <>pp]]))))
       ; equal literals share one block with every label on it (C leaves them unspecified as distinct);
       ; grouped at layout, not at intern -- the codegen retry paths roll 'strs back
       (strs ss acc)
        (: (bts s i bacc) (i < 0 ? bacc (bts s (i - 1) (s i . bacc)))
           (grp l seen ord)
            (!(two? l) ? [seen (rev ord)]
               (: p <l t <>p old (seen t)
                  (grp >l (pin seen t (old + [<p])) (two? old ? ord (t . ord)))))
           (lay ts seen a)
            (!(two? ts) ? a
               (<ts @ t
                  (lay >ts seen (a + map (b \ ['label b]) (seen t)
                                    + [['raw (bts t (#t - 1) () + '(0))]]))))
           gs (grp ss {} ())
           (lay <>gs <gs acc))
       ; may a named section go read-only: ro? of every member, one writable deciding for all;
       ; the const gate first, so a writable section never images anything
       (xro? nm)
        (: (go gs) (? !(two? gs) 1
                      !(strm <gs = nm) (go >gs)
                      !(consts <gs) ()
                      (: ge (peep (g 'glob) <gs 0)
                         b (image1 <gs <>ge <>>ge)
                         (!(bad? b) && ro? <gs b ? (go >gs))))
           (go (g 'globs)))
       ; the other section names, first-seen in declaration order
       xnames (: (go gs acc) (!(two? gs) ? (rev acc)
                                (strm <gs @ s
                                   (go >gs (elem s '(".data" ".rodata" "love_nifs" ".love.image") ||
                                            elem s acc ?
                                              acc (s . acc)))))
                 (go (rev (g 'globs) + rev (g 'statics)) ()))   ; a block static may name one too
       (: gb (globs (rev (g 'globs)) ".data" 'd ())     ; exported globals, then block-scope statics
          sb (bad? gb ? 'bad (globs (rev (g 'statics)) ".data" 'd ()))
          zg (bad? gb || bad? sb ? 'bad (globs (rev (g 'globs)) ".data" 'z ()))
          zs (bad? zg ? 'bad (globs (rev (g 'statics)) ".data" 'z ()))
          ; .rodata: strings, jump tables, self-named globals and the 'r walk's consts -- nothing
          ; written at load or run (a pointer cannot ride: -pie slides it)
          rg (bad? zg || bad? zs ? 'bad (globs (rev (g 'globs)) ".rodata" () ()))
          rs (bad? rg ? 'bad (globs (rev (g 'statics)) ".rodata" () ()))
          cg (bad? rg || bad? rs ? 'bad (globs (rev (g 'globs)) ".data" 'r ()))
          cs (bad? cg ? 'bad (globs (rev (g 'statics)) ".data" 'r ()))
          nb (bad? cg || bad? cs ? 'bad (globs (rev (g 'globs)) "love_nifs" () ()))
          ib (bad? nb ? 'bad (globs (rev (g 'globs)) ".love.image" () ()))
          ; a named section's refusal refuses the whole: else one entry it cannot lay empties the section
          xb (bad? ib ? 'bad
                (map (nm \ [nm (globs (rev (g 'globs) + rev (g 'statics)) nm () ()) (xro? nm)]) xnames @ l
                   (any (x \ bad? (x 1)) l ? 'bad l)))
          ; each switch's jump table: a label, then 4-byte self-relative entries (label differences, settled at link)
          jt (foldl (a \ p \ a + [['align 4] ['label <p]] + [['raw <>p]])
                    () (rev (g 'jtabs)))
          (foldl (a \ x \ a || bad? x) () [gb sb zg zs rg rs cg cs nb ib xb] ? 'bad
             [(gb + sb + clits (rev (g 'clits))) nb ib xb (zg + zs)
              (rg + rs + cg + cs + jt + strs (g 'strs) () + dbls g)])))
       ; the static compound literals, each aligned as its type asks
       (clits l) (foldl (a \ c \ a + [['align (c 1)] ['label <c] ['raw (c 2)]]) () l)
       ; the double pool: 8-aligned blocks in pattern order (keys are unsorted; the lay must not drift)
       (dbls g) (foldl (a \ u \ a + [['align 8] ['label (dbname u)] ['raw (le64 u)]])
                       () (sort (keys (g 'dbls))))

   ; every nom in a form tree, pinned into a tablet: the dead-static sweep's reference relation,
   ; over-approximate on purpose (an opcode or a register name counts too; a miss is a wild jump)
   (cg-refs x t)
    (? (nom? x) (pin t x 1)
       !(two? x) t
       (cg-refs >x (cg-refs <x t)))
   ; ..narrowed over a laid body's forms: an opcode is never a reference, and a register's spelling
   ; (r8, f0, sp) is one only at an op's label operand (cg-labpos) or in a form holo lays whole: a
   ; static named r8 dies unless a call, jmp or la names it. a label op missing here scares undef-label
   cg-labpos {'call [1] 'jmp [1] 'jmp8 [1] 'br [2] 'br8 [2] 'la [2] 'lar [2] 'lia [2]
              'ldsdl [2] 'mulo [5] 'jmpt [2 3]}
   cg-wholeops '(raw addr fix)
   (cg-regnom? x) (: s (show x) n #s
                     (? (s = "sp" || s = "fp") 1
                        (1 < n && elem (s 0) '(114 102 120) && all digit? (map s (map (+ 1) ^(n - 1)))) 1 0))
   (cg-frefs fm t)
    (foldl (t \ ins \ (? !(two? ins) t
                         (!(nom? <ins) || elem <ins cg-wholeops) (cg-orefs ins () t)   ; a nested run, or laid whole
                         (: lp (cg-labpos <ins)
                            (go os i t) (!(two? os) ? t (go >os (i + 1) (cg-orefs <os !(elem i lp) t)))
                            (go >ins 1 t))))
           t fm)
   ; ..over gas's read of an asm, its sections first ([name _ _ forms]): those forms narrowed as a
   ; body's, so an opcode in an alternative's replacement (`stac`) keeps no static of that name
   (cg-arefs r t) (!(two? r) ? t (foldl (t \ s \ (two? s && 3 < #s ? (cg-frefs (s 3) t) t)) (cg-refs >r t) <r))
   (cg-orefs x reg? t)
    (? (nom? x) (reg? && cg-regnom? x ? t (pin t x 1))
       !(two? x) t
       (cg-orefs >x reg? (cg-orefs <x reg? t)))
   ; the same relation over an AST, where a name is still text (laid forms wear the nom): only a
   ; mention names one -- a struct tag, a field's designator or a string literal that spells a
   ; function's name is not a reference to it
   (cg-srefs x t)
    (!(two? x) ? t
       (x @ ('var s) (string? s ? (pin t s 1) t)
            (cg-srefs >x (cg-srefs <x t))))
   ; the shared core: the gen state, then text (no _start) and data -> (g textforms dataforms) | ().
   ; weaks never inline (a spliced body would bake past the linker's strong override); xtra is the parser's tablets, () reading as empties
   (cgen-core ast stbl sigs weaks xtra tgt)
    (: g {'n 0 'brk () 'brkm () 'cnt () 'cases () 'glob {} 'globs () 'strs () 'clits () 'clitm {} 'dbls {} 'jtabs () 'statics ()
          'abl (ablenv 0)                           ; the pricing knob, read per unit at run time
          'census (cenv 0)
          'laid {}                                  ; names already on 'globs (a tentative repeat lays no twin)
          'fns {} 'csites {} 'cloop {} 'inl {} 'nocap {} 'ineed {} 'alw {} 'nopf {} 'fnret {} 'kretm {} 'ainlc {} 'stag stbl 'sigs sigs
          'tgt tgt                                  ; (the epilogue is per fn: cgfn pins g 'epi)
          'weaks weaks                              ; the unit's weak names, never speculated
          'sects (two? xtra ? <>>xtra {})
          'alias (two? xtra && 3 < #xtra ? (xtra 3) {})
          'aligns (two? xtra && 4 < #xtra ? (xtra 4) {})
          'consts (two? xtra && 7 < #xtra ? (xtra 7) {})
          ; the parser's restrict roster, fn -> its restrict param names; nothing reads it yet
          'rstrs (two? xtra && 8 < #xtra ? (xtra 8) {})
          ; file-scope `register T nm asm("R")` names: vent answers the register, nothing is laid
          'gregs (two? xtra && 10 < #xtra ? (xtra 10) {})
          'xfns ()                                  ; (secname forms) per fn that named a section, newest first
          'fasecs ()                                ; a function's asm sections, one gas-top reading each
          'romemo {}                                ; a global's image, laid once and read by every walk
          'mo (two? xtra && 11 < #xtra ? (xtra 11) [() () () () () () () () () () () () () () () () () ()])   ; the asks: [strict-align branch-protection regparm pre-686 -Os no-float unsigned-char no-jump-tables no-builtin align-functions no-sibcalls auto-var-zero ibt wrapv patchable-entry stack-guard x86-kernel no-pie]
          'pfes (two? xtra && 12 < #xtra ? (xtra 12) {})   ; fn name -> its own patchable_function_entry (N M)
          'nopro (two? xtra && 13 < #xtra ? (xtra 13) ())  ; no_profile_instrument_function names
          'pfel ()}                                 ; the pads laid, newest first
       ; pass 0: every fn name (the sig table too: an mproto sibling has a sig but no proto form),
       ; and the inline table -- always_inline at any size, noinline never
       ainls (two? xtra && 5 < #xtra ? (xtra 5))
       noinls (two? xtra && 6 < #xtra ? (xtra 6))
       ; -fno-inline outranks always_inline: the flag is an instrument
       nolin (two? xtra && 9 < #xtra ? (xtra 9))
       ; what glay may lay: an unreached fn is judged for no splice
       _ (pin g 'reach (cgreach <>ast (two? xtra ? <xtra {}) (g 'alias)))
       (recfns fs) (!(two? fs) ? 1
                      (<fs @ f
                         (elem <f '(fn proto) ? (pin (g 'fns) <>f 1),
                          ; a body that does nothing: a call to it here is its arguments' effects alone
                          (<f = 'fn && nelem <>f weaks && empty? (f 3) ? (pin (g 'nopf) <>f 1) 0),
                          ; ..and one that is a single `return E`, for kcall to answer where E is one constant
                          (<f = 'fn && nelem <>f weaks ? ((f 3) @ ('blk . is . _) (two? is && !(two? >is) && <<is = 'ret && two? >(<is) ? (pin (g 'fnret) <>f <>(<is)) 0) 0) 0),
                          (<f = 'fn && nelem <>f weaks ? (pin (g 'nocap) <>f (map (p \ ptr? <>p && nocap? <p (f 3) ? 1 0) <>>f)) 0),
                          (<f = 'fn && !nolin && g 'reach <>f &&
                           nelem <>f weaks &&
                           nelem <>f noinls ?
                             ; judged as it would splice: dead arms pruned, a tail past a return cut, a do-while(0) unwrapped, a statement that does nothing dropped
                             ((elem <>f ainls || !(sspbuf? g (f 3)) ? (sspcut f) f) @ f9 (nofx (do0 (ucut (dprune !(ilp32? g) (e \ ()) f9)))) @ fi
                                (inlok? g fi (sigs <>f) (elem <>f ainls) ?
                                   ((asmneed? g <>>f <>>>f ? (pin (g 'ineed) <>f 1) 0),
                                    (elem <>f ainls ? (pin (g 'alw) <>f 1) 0),
                                    pin (g 'inl) <>f fi) 0)) 0),
                          recfns >fs)))
       _ (: (go x lp) (? !(two? x) 0
                         (x @ ('call . ('var nm) . r) (pin (g 'csites) nm (1 + peep (g 'csites) nm 0),
                                                       (lp ? (pin (g 'cloop) nm 1) 0), go r lp)
                              (('while || 'for || 'do) . r) (go r 1)
                              (go <x lp, go >x lp)))
            (go <>ast ()))
       _ (recfns <>ast)
       _ (: (go ns) (!(two? ns) ? 1 (pin (g 'fns) <ns 1, go >ns))
            (go (keys sigs)))
       ; an array declared []: parse spells the open bound 0, the one type a later decl may complete
       (openarr? ty) (two? ty && <ty = 'arr && <>>ty = 0)
       ; pass 1: every global, name -> (label ty init); cgimage validates the initializer at emission
       (rec fs)
        (!(two? fs) ? 1
           (<fs @ f
              (!(elem <f '(gdecl xdecl)) ? (rec >fs)
                 (: xd (<f = 'xdecl)              ; extern: addressable, no storage laid
                    (one ps)
                     (!(two? ps) ? (rec >fs)
                        (: p <ps
                           old (g 'glob <p)
                           ; the tentative rule (6.9.2): an initialized def wins the entry, a repeat lays no second
                           ; symbol; a complete type outranks an open [] (6.2.7), else it lays at size zero
                           (atom? old || two? <>>p || openarr? <>old && !(openarr? <>p) ?
                              (pin (g 'glob) <p [(name <p) <>p <>>p]),
                            !xd && !(g 'laid <p) ? (pin (g 'laid) <p 1,
                                                    pin g 'globs (<p . g 'globs)),
                            one >ps)))
                    (one <>f)))))
       ; the file-scope asm, one text in declaration order (gas's section state runs across them)
       asrc (foldl (a \ f \ <f = 'tasm ? "\(a)\(<>f)\n" a) "" <>ast)
       _ (pin g 'asecs (0 < #asrc ? (trap (gas-top tgt) asrc
                                         (a \ b \ (a = 'leave ? (scare a b)
                                                     (pin g 'genfail (gripe () () () "an assembly line \(asmwhy a b)"), ()))))))
       ; its `.set a, t` onto a name the C defines: an alias of the C's own
       _ (foldl (_ \ al \ (: t <>al
                            ((any (f \ <f = 'fn && <>f = t) <>ast) || peep (g 'glob) t () ?
                               (pin (g 'alias) <al t, 0)
                               (pin g 'genfail (gripe () () () "an assembly line .set \(<al), \(t) -- nothing here defines \(t)"), 0))))
                0 (two? (g 'asecs) && 4 < #(g 'asecs) ? (g 'asecs 4) ()))
       ok (rec <>ast)
       ; -- lazy lowering: lay the roots (every exported fn, alias target, section-named fn, and every
       ; fn an initializer names), then what their laid forms still call, to closure; a spliced static's body ships only if named --
       (glay _)
        (: fnix {}                              ; fn name -> its AST form
           _ (foldl (_ \ f \ <f = 'fn ? (pin fnix <>f f, 0) 0) 0 (ipcp g (two? xtra ? <xtra {}) <>ast))
           unom {}                              ; the interned nom -> that name
           _ (foldl (_ \ nm \ (pin unom (name nm) nm, 0)) 0 (keys fnix))
           sfns (two? xtra ? <xtra {})
           als (g 'alias || {})
           atg (foldl (a \ k \ als k . a) () (keys als))
           (cut? nm) ((peep sfns nm 'no @ s (s != 'no && s != 'used)) && nelem nm atg)
           ; two tablets: a truth test on a form list reads its net, which lands on zero, so presence is its own mark
           laid {}                              ; fn name -> 1 once its body is laid
           lfm {}                               ; ..and the forms, for the ones that stayed in .text
           ; lay one body -> the noms it still names; a refusal parks in 'genfail (the first cause stands)
           (lay1 nm)
            (: f (fnix nm)
               _ (pins g 'undecl () 'nolane () 'arity ())   ; fresh per fn: the refusal's pins name this fn's cause
               r (mprof 'fn (_ \ cgfn g f))
               (bad? r ?
                  (: u (g 'undecl)      ; an undeclared id was named
                     nl (g 'nolane)     ; a deliberate refusal named its missing lane
                     ar (g 'arity)      ; a direct call disagreeing with its own prototype
                     (gripe? (g 'genfail) ? 0
                        (pin g 'genfail
                             (? u (gripe () () () "undeclared '\(u)' (in \(nm))")
                                ar (gripe () () () "\(ar) (in \(nm))")
                                nl (gripe () () () "\(nl) (in \(nm))")
                                (gripe () () () "cannot compile '\(nm)' (cause unnamed)"))),
                      ()))
                  ; align 2: the image codec tells a pointer from a fixnum by parity, so an odd fn address desyncs
                  ; a woken heap; wider measured slower. alias labels ride inside the align, before the fn's own
                  (: al2 (: (go l a2) (!(two? l) ? a2
                                         (go >l (g 'alias <l = nm ?
                                                   (['label (name <l)] . a2) a2)))
                           (go (keys (g 'alias)) ()))
                     ; an aligned(N) fn, or -falign-functions', floored at 2 by the parity law
                     an (peep (g 'aligns) nm 2 @ a (max (max a 2) (falgn g)))
                     pf (pfeof g nm)
                     fm (['align an] . pfepre g nm pf + al2 + pfepost g nm pf (lpad? g ? (btiat nm r) r)
                          + (wasm? g ? () (catmap (a \ [['label (fn-end a)] ['label (fn-type a)]]) (nm . map (f \ <>f) al2))))   ; elf's size and type
                     ; a fn that named its section leaves .text for that stream, its align riding out as the section's grain
                     sc (peep (g 'sects) nm ())
                     _ (nm = "main" ? (pin g 'saw 1))
                     _ (sc ? (pin g 'xfns ([sc fm an nm] . g 'xfns)) (pin lfm nm fm))
                     _ (pin laid nm 1)          ; before the walk: a recursive fn names itself
                     ; the wide relation's order, narrowed: tablet keys run in no fixed order, so
                     ; walking the narrow tablet's own would re-deal the layout
                     pr (cg-frefs fm {})
                     (filter pr (keys (cg-refs fm {}))))))
           (drive q)
            (gripe? (g 'genfail) || !(two? q) ? 0
               (<q @ nm
                  (laid nm ? (drive >q)
                     (drive (foldl (a \ x \ unom x @ t (t && !(laid t) ? (t . a) a))
                                   >q (lay1 nm))))))
           ; the sectioned bodies first, in declaration order: a named section's layout is the program's
           ; (love.c reads a kind by dividing a sentinel's offset), and the worklist would tile them in discovery
           ; order. an unused static is no root here either: a reference lays it, as anywhere else
           (secs fs acc)
            (atom? fs || gripe? (g 'genfail) ? acc
               (<fs @ f
                  (<f = 'fn && g 'sects <>f && !(laid <>f) && !(cut? <>f) ?
                     (secs >fs (acc + lay1 <>f))
                     (secs >fs acc))))
           snoms (secs <>ast ())
           ; the roots in declaration order, so the layout is reproducible
           roots (: (go fs acc)
                     (fs @ (f . u) (go u (<f = 'fn && !(cut? <>f) ? (<>f . acc) acc)) (rev acc))
                    (go <>ast ()))
           ; what the sectioned bodies call joins the worklist like any other ref
           sq (foldl (a \ x \ unom x @ t (t && !(laid t) ? (t . a) a)) () snoms)
           ; ..and a static the file-scope asm names, which no C reference may reach. an inline's
           ; name stays undefined for the link: only a call lays one
           aq (foldl (a \ x \ unom x @ t (t && !(laid t) && peep sfns t () != 'inl ? (t . a) a)) () (keys (cg-arefs (g 'asecs) {})))
           _ (drive (roots + sq + aq))
           ; the live globals: one another unit may name (not static), a `used` or sectioned static, an alias's
           ; target, and what a laid body, an asm or a live initializer names. a block-scope static is no svar,
           ; so it stays. only a live initializer's fns are laid, and only live globals
           svs (two? xtra ? <>xtra {})
           gnom {}                              ; a global's label nom -> its name
           live {}
           gfr {}                               ; every name a live initializer mentions
           (gadd ks) (foldl (a \ k \ (two? (peep (g 'glob) k 0) && !(live k) ? (pin live k 1, k . a) a)) () ks)
           (gclose ws) (!(two? ws) ? 0
                          (: r (cg-srefs <>>(g 'glob <ws) {})
                             _ (foldl (_ \ k \ (pin gfr k 1, 0)) 0 (keys r))
                             (gclose (gadd (keys r) + >ws))))
           (groot? k) ((peep svs k 'no @ s (s = 'no || s = 'used)) || peep (g 'sects || {}) k () || elem k atg)
           ; a laid body can name more, and lays its block statics, so this closes rather than passes
           (datclose _)
            (: _ (foldl (_ \ k \ (pin gnom <(g 'glob k) k, 0)) 0 (keys (g 'glob)))
               _ (gclose (gadd (filter groot? (keys (g 'glob)))))
               t (foldl (t2 \ k \ cg-refs (lfm k) t2)
                        (cg-refs (g 'xfns) (foldl (t \ r \ cg-arefs r t) (cg-arefs (g 'asecs) {}) (g 'fasecs))) (keys lfm))
               _ (gclose (gadd (foldl (a \ x \ peep gnom x () @ s (s ? (s . a) a)) () (keys t))))
               ; ..and what a function's asm names from another section
               _ (foldl (_ \ x \ unom x @ s (s ? (pin gfr s 1) 0)) 0 (keys (foldl (t \ r \ cg-arefs r t) {} (g 'fasecs))))
               q (foldl (a \ s \ two? (fnix s) && !(laid s) ? (s . a) a)
                        () (keys gfr))
               (two? q && !(gripe? (g 'genfail)) ? (drive q, datclose 0) 0))
           _ (datclose 0)
           _ (pin g 'globs (filter live (g 'globs)))
           gf (g 'genfail)
           (gripe? gf ? gf
              (cgdata g @ dat
                 (bad? dat ?
                    (g 'datacause @ c   ; the static-data refusal, minted here (globs pinned it)
                       (gripe () () () (c ? c "cannot lay the static data (cause unnamed)")))
                    ; txt builds reversed (a cat per fn is quadratic) and the rev restores order
                    (: _ (pin g 'dropped
                          (foldl (a \ f \ <f = 'fn && !(laid <>f) ? (<>f . a) a) () <>ast))
                       ; who may reach a fn by an indirect call: another unit, unless it is static;
                       ; else an address taken in code (la), in data, in an asm, or by an alias
                       tk (lpad? g ?
                             (: t {}
                                _ (foldl (_ \ k \ g 'glob k @ e (two? e ? (cg-srefs <>>e t, 0) 0)) 0 (keys (g 'glob)))
                                _ (foldl (_ \ s \ (pin t s 1, 0)) 0 atg)
                                n {}
                                _ (foldl (_ \ s \ (pin n (name s) 1, 0)) 0 (keys t))
                                _ (foldl (_ \ x \ (pin n x 1, 0)) 0 (keys (cg-refs [(g 'asecs) (g 'fasecs)] {})))
                                (lafs fm) (foldl (_ \ f \ (two? f && elem <f '(la lar lia) ? (pin n (f 2) 1, 0) 0)) 0 fm)
                                _ (foldl (_ \ k \ (lafs (lfm k), 0)) 0 (keys lfm))
                                _ (foldl (_ \ x \ (lafs (x 1), 0)) 0 (g 'xfns))
                                n))
                       (bton nm) (peep sfns nm 'no = 'no || peep tk (name nm) ())
                       _ (lpad? g ? (foldl (_ \ k \ (pin lfm k (btic g (lfm k) (bton k)), 0)) 0 (keys lfm)))
                       _ (pin g 'xfns (map (x \ [(x 0) (lpad? g ? (btic g (x 1) (bton (x 3))) (x 1)) (x 2)]) (g 'xfns)))
                       txt (foldl (a \ f \ (: u (<f = 'fn ? (lfm <>f))
                                            (two? u ? (revcat u a) a)))
                                  () <>ast)
                       [g (rev txt) (jtlive g dat txt) (g 'saw)])))))
       (ok ? (glay 0)))
   ; a jump table whose case labels the text no longer lays -- its switch fell with dead code, or
   ; with a retried build's first attempt -- leaves the rodata
   (jtlive g dat txt)
    (: (key x) (string? x ? x (show x))
       (lbls x t) (? !(two? x) t (<x = 'label) (pin t (key <>x) 1) (lbls >x (lbls <x t)))
       have (lbls (map (x \ x 1) (g 'xfns)) (lbls txt {}))
       jl (foldl (t \ p \ pin t (key <p) 1) {} (g 'jtabs))
       (ok? es) (all (e \ !(two? e) || <e != 'fix || have (key (e 3))) es)
       (go l) (? !(two? l) l
                 ((<l @ ('label . k . _) (jl (key k)) ()) && two? >l) (ok? <>(<>l) ? (<l . <>l . go >>l) (go >>l))
                 (<l . go >l))
       (dat @ (a . b . c . d . e . f . _) [a b c d e (go f)] dat))
   (cgen ast stbl sigs weaks xtra tgt)              ; the static executable: _start (crt0) + text + data -> (1 forms) | () -- needs main
    (: crt0 (? (tgt = 'a64)
               '((call main) (li r8 93) (sys))            ; x0 already the exit code; x8 = __nr_exit (93), svc
               (tgt = 'rv64)
               '((call main) (li r7 94) (sys))            ; a0 already the exit code; a7 = __nr_exit_group (94), ecall
               '((call main) (mov r6 r0) (li r0 60) (sys)))
       r (cgen-core ast stbl sigs weaks xtra tgt)
       (? (gripe? r) r                               ; a named cause rides out (a gripe is a chain: guard before two?)
          !(two? r) ()
          !(r 3) ()                               ; no main -> no program
          (two? (asecs-all <r)) (gripe () () () "an asm's sections ride only an object")
          (<>>r @ dat                           ; one flat image: nifs, rodata and bss (as real zeros) all ride the one lane
             [1 (crt0 + <>r + <>>>>>dat + <dat + <>dat + <>>>>dat)])))
   ; the relocatable object view: the .o emitter turns the names into a symbol table + relocations;
   ; the static fns ride as lnames (local func symbols, so nm/gdb see real boundaries)
   (cgen-obj ast stbl sigs weaks xtra tgt)          ; -> (1 textforms dataforms funcnames globnames nifforms imgforms lnames xsecs bssforms rodataforms xfnsecs asecs) | ()
    (cgen-core ast stbl sigs weaks xtra tgt @ r
       (? (gripe? r) r                               ; a named cause rides out
          !(two? r) ()
          (: sfns (two? xtra ? <xtra {})
             svars (two? xtra ? <>xtra {})
             sects (two? xtra ? <>>xtra {})
             (loc? nm) (peep svars nm 'no != 'no ||
                        peep sects nm () = "love_nifs")     ; a nif entry is static by shape; any other
                                                                 ; named section stays exported (.image is read by symbol)
             als (two? xtra && 3 < #xtra ? (xtra 3) {})
             ; a `static` alias (MODULE_DEVICE_TABLE's) is a local symbol at its target's place
             (sal? a) (loc? a || peep sfns a 'no != 'no)
             fnames (: (go fs acc) (!(two? fs) ? (rev acc)
                                      (<fs @ f
                                         (go >fs (<f = 'fn && peep sfns <>f 'no = 'no ?
                                                         (<>f . acc) acc))))
                       ; an alias of a function defined here is a func symbol of its own, at the same address
                       defd (: (go2 fs acc) (!(two? fs) ? acc
                                               (<fs @ f
                                                  (go2 >fs (<f = 'fn ? (<>f . acc) acc))))
                               (go2 <>ast ()))
                       (: base (go <>ast ())
                          (go3 l a2) (!(two? l) ? a2
                                        (go3 >l (elem (als <l) defd && !(sal? <l) ? (<l . a2) a2)))
                          (base + go3 (keys als) ())))
             gnames (: (go gs acc) (!(two? gs) ? (rev acc)
                                      (go >gs (loc? <gs ? acc (<gs . acc))))
                       ; an alias onto a global (or block static) is an object symbol of its own, at the same bytes
                       dgl (revcat (<r 'globs) $ rev (<r 'statics))
                       (: base (go (rev (<r 'globs)) ())
                          (go2 l a2) (!(two? l) ? a2
                                        (go2 >l (elem (als <l) dgl && !(sal? <l) ? (<l . a2) a2)))
                          (base + go2 (keys als) ())))
             ; minus the swept: a local func symbol with no body would name whatever followed it
             gone (<r 'dropped)
             lnames (: (go fs acc) (!(two? fs) ? (rev acc)
                                      (<fs @ f
                                         (go >fs (<f = 'fn && peep sfns <>f 'no != 'no
                                                  && nelem <>f gone ?
                                                         (<>f . acc) acc))))
                       (go <>ast ()))
             laid ((map (f \ <>f) (filter (f \ <f = 'fn && nelem <>f gone) <>ast)) + (<r 'globs) + (<r 'statics))
             lals (filter (a \ sal? a && elem (als a) laid) (sort (keys als)))
             ; file-scope static data rides as lnames too, an object symbol where its bytes went, as clang
             ; lays it: modpost lets a table reach .init only by its name (*_ops, *_probe, *_console)
             lvars (filter (s \ loc? s && nelem s lals) (rev (<r 'globs)))
             dat <>>r
             ; the sectioned fns folded to (name forms align) per section, in declaration order; the grain is the widest asked
             xfns (: (noms l acc) (!(two? l) ? (rev acc)
                                     (noms >l (elem <<l acc ? acc (<<l . acc))))
                     (forsec nm l) (: (go l2 a2) (!(two? l2) ? a2
                                                    (go >l2 (<<l2 = nm ? (a2 + <><l2) a2)))
                                      (go l ()))
                     (grain nm l) (: (go l2 a2) (!(two? l2) ? a2
                                                   (go >l2 (<<l2 = nm && a2 < <>><l2 ?
                                                              <>><l2 a2)))
                                     (go l 16))
                     (rev (<r 'xfns) @ src
                        (map (nm \ [nm (forsec nm src) (grain nm src)]) (noms src ()))))
             ; the pads' words, a fixup to each: what ftrace and the kernel's call padding walk
             ; ..only those whose label the text still lays, once each, one section per function
             ; section and ordered by it (shf_link_order), as a discarded .init.text takes its own
             pfs (: w (ilp32? <r ? 4 8)
                    (lt fs) (foldl (t \ f \ (two? f && <f = 'label ? (pin t (<>f) 1) t)) {} fs)
                    (pfsec fs) (lt fs @ t (foldl (a \ L \ (t L && !(elem L a) ? (L . a) a)) () (<r 'pfel) @ ls
                                  (two? ls ? [["__patchable_function_entries"
                                               (['align w] . map (L \ ['raw [['fix w (w = 4 ? 'abs32 'abs64) L 0]]]) ls) 'lo]])))
                    (pfsec <>r + catmap (x \ pfsec (x 1)) xfns))
             [1 <>r <dat fnames gnames
                <>dat <>>dat (lnames + lvars + lals) (<>>>dat + pfs) <>>>>dat <>>>>>dat
                xfns (asecs-live <r [<>r (map (x \ x 1) xfns)])]))))
) ; module 'moon
