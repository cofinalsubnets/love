; the code generator: AST -> (1 ir-forms) | (), in holo's neutral IR. every expression
; computes into r0 and carries its type (cgexpr answers (type forms)); the ALU is 64-bit and
; widths bite only at memory and casts. clval answers an lvalue's address in r0 + pointee type.
; a float is 4 bytes in memory but always a double in an xmm register.
; refused, not fudged: ptr+ptr, deref of a non-pointer, assigning to an array.
; stage.l types each pass against its sig there: a new pass declares one.
(module 'moon
(borrow 'kore)
(borrow 'holo) ; the assembler + linker
(:
   ; a plain value folds eagerly at bake, in no textual order
   spush2 '((sub sp sp 16) (st sp 0 r0) (st sp 4 r1))   ; the t32 pair push
   wpush64 '((sub sp sp 16) (st sp 0 r0) (st sp 8 r2))  ; the wide kit's cell
   wdrop '((add sp sp 16))
   ; a composite at r0 into a fresh 16-byte cell: by words (t32), by eightbytes, or pushed (x64)
   cell4w '((sub sp sp 16) (ld r1 r0 12) (st sp 12 r1) (ld r1 r0 8) (st sp 8 r1)
            (ld r1 r0 4) (st sp 4 r1) (ld r1 r0 0) (st sp 0 r1))
   ; bswap32 in place on r0 through r1-r3
   bsw32 '((li r2 255)
           (mov r1 r0) (shr r1 24) (and r1 r1 r2)
           (mov r3 r0) (shr r3 16) (and r3 r3 r2) (shl r3 8) (or r1 r1 r3)
           (mov r3 r0) (shr r3 8) (and r3 r3 r2) (shl r3 16) (or r1 r1 r3)
           (and r0 r0 r2) (shl r0 24) (or r0 r0 r1))
   cell2w '((sub sp sp 16) (ld r1 r0 8) (st sp 8 r1) (ld r1 r0 0) (st sp 0 r1))
   push2w '((ld r1 r0 8) (push r1) (ld r1 r0 0) (push r1))
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
   cxdty '(struct "__cplx_double")                      ; the seeded complex-double tag
   ; the ISA families, the one place an op's membership is stated (an op off every list is opaque).
   ; off every list is opaque). an op that can base on r4 must also join a4base + uoff and deadst's scans
   ldops9 '(ld ld1 ld2 ld4 ldu1 ldu2 ldu4)
   gstops '(st st1 st2 st4)
   fldops '(ldsd ldss) fstops '(stsd stss)
   stops9 (gstops + fstops)                         ; gp head first
   leaops '(lea lean)                               ; lean: consumed by its own use
   xops '(leax ldx ldxb ldxw ldxsw)                 ; base index scale disp; ldxw/ldxsw: the 32-bit loads, zero/sign-extending
   x4ops '(andx4 orx4 xorx4) m4ops '(andm4 orm4 xorm4)   ; and/or/xor r32 by a 32-bit load (base index scale disp | base off): the top zeroes
   stxops '(stx stxb)
   fxops '(ldsdx ldssx) fstxops '(stsdx stssx)      ; x64: no gp effect
   siops '(si si1 si2 si4)                          ; the store-immediates
   aluops '(add sub and or xor imul)
   ; the flag family sets or reads the flags for the form beside it: never pure (deaddef would
   ; lift it), never in aluops (the two-address rewrites); off every list rdsp answers 'bar
   flagops '(adds subs adcs sbcs adc sbc ors)
   divops '(div rem udiv urem)                      ; r0..r3 clobber
   ; (umull dl dh a b) defines two; udivll/uremll are nullary, owning r0..r3 (r4..r7 saved inside)
   wmops '(umull smull)
   llops '(udivll uremll)
   vshops '(shlv shrv sarv rorv rorv4)              ; x64: count in r1
   qfile '(r0 r1 r2 r3 r4 r5 r6 r7 r8 r9 r10 r11 r12)   ; the gp file a 32-bit pair move walks
   unops '(neg not sx1 sx2 sx4 zx1 zx2 zx4)         ; one-register rewrites
   xmmops '(addsd subsd mulsd divsd minsd maxsd movsd movapd ucomisd cvtss2sd cvtsd2ss
            addss subss mulss divss minss maxss ucomiss movss)   ; no gp effect
   barops '(call callr callm raw sys)                     ; the opaque barriers
   ; the gen state g: 'n the label counter, 'off the frame high-water, 'brk/'cnt loop label stacks,
   ; 'glob name -> (label ty init), 'globs the emission order, 'strs ((label . text)..);
   ; env ((name off ty)..) the frame locals
   (nlab g pfx) (peep g 'n 0 @ k (pin g 'n (k + 1), name "\(pfx).\(k)"))   ; one counter across prefixes
   ; a loop head's pad, under the entry jump: x64 gains at 32 (not at 16 or 64), the 4-byte ISAs don't
   (lalign g) (x64? g ? '((align 32)) ())
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
   ; an even slot is the single view of dK; an odd one has no f-register name, so its word rides r12
   (vfpsv k base off) (0 = k & 1 ? [['stss base off (xmmreg (k // 2))]]   ; slot k -> a 4-byte home
                         [['movsnrx 'r12 k] ['st base off 'r12]])
   (bad? x) (x = 'bad)
   ; the value tuple (ty reg forms); the flo lane keeps the f0 protocol and dispatches on vty
   (vty v) <v
   (vreg v) <>v
   (vfs v) <>>v
   (mkv ty reg fs) [ty reg fs]
   ; the mem face: an lvalue as ['m b o] in the reg field, laid by its consumer as one fused form;
   ; matv is the degenerate face (the address on r0)
   (mkm ty b o fs) [ty ['m b o] fs]
   ; ..one that cannot carry its type's width under -mstrict-align, a the alignment it does carry
   (mkma ty b o fs a) [ty ['m b o a] fs]
   (ua? v) (vm? v && 3 < #(vreg v))
   (vma v) ((vreg v) 3)
   (vm? v) (bad? v ? () (two? (vreg v)))
   (vmb v) <>(vreg v)
   (vmo v) <>>(vreg v)
   (mata b o) (b @ 'r4 [['lean 'r0 'r4 o]] ; consumed, so lean (the & lane lays its own lea)
                   'r0 (o @ 0 () [['add 'r0 'r0 o]])
                   (o @ 0 [['mov 'r0 b]] [['add 'r0 b o]]))

   (matv g v) (!(vm? v) ? v
                 (vmb v @ b
                    (rfree g b,
                     mkv (vty v) 'r0 (vfs v + mata b (vmo v)))))
   ; the operand pool: g 'pool0 the fn's set (opool minus param homes), g 'pool the free list,
   ; reset per statement. a pool value never crosses a call (caller-saved, no spill wrap)
   opool '(r6 r5 r9 r10 r7 r8)
   fpark '(f3 f4 f5 f6 f7)                          ; the xmm park file (x64): f0/f1 the protocol pair, f2 the narrow scratch
   fpark-a64 '(f17 f18 f19 f20 f21 f22 f23)          ; a64: past the narrow scratch f16, under the homes
   fregs16 '(f0 f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12 f13 f14 f15)
   ; the forms an arm may lay between a compare and its cmov: none writes a flag
   fneu '(li mov lea lean leax ld ld1 ld2 ld4 ldu1 ldu2 ldu4 ldx ldxb ldxw ldxsw sx1 sx2 sx4 zx1 zx2 zx4)
   ; the vreg shadow: ralloc mints a nom (%v0 ..) mapped in g 'vrt to a physical, and vrfix
   ; substitutes at build's last link. every g-table holds physicals; rp resolves a nom for the machine
   (rp g rz) (g 'vrt rz || rz)
   (vmint? g x) !!(g 'vrt x)   ; pre-vrfix only
   ; one machine register? every hint-honor test rides this, never bare =: a value can come
   ; back wearing a new mint on the same physical
   (rpeq? g a b) (rp g a = rp g b)
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
   (dp nm fs) (getenv "MOON_DUMP" @ w
                 (string? w && two? fs && two? <fs && w = show (<fs 1) ?
                    (puts ";; \(show nm)\n",
                     map (f \ (putx f, putc 10)) fs,
                     fs)
                    fs))
   (ralloc g) (!(abl? g 'ralloc) ?
               (g 'pool @ (r9 . u)
                (pin g 'pool u,
                 vmint g r9)))
   (vmint g r9) (: k9 (peep g 'vrn 0)
                   v9 (name "%v\(k9)")
                 (pin g 'vrn (k9 + 1),
                  pin (g 'vrt) v9 r9,
                  v9))
   ; a spare pool register a shuttle borrows for one span, minted so the allocator may move it
   (vspare g r9) (r9 && (x64? g || a64? g) && !(abl? g 'ralloc) && !(abl? g 'vspare) ? (vmint g r9) r9)
   (rfree g rz) (rp g rz @ r
                  (elem r (g 'pool0) &&
                 nelem r (g 'pool) ?
                  (pin g 'pool (r . g 'pool))))
   (wr? g rz) (rz = 'r0  ||                        ; writable: r0 or an owned pool reg (a borrowed home is read-only)
               elem (rp g rz) (g 'pool0))
   ; the assignment: move a mint onto its copy's other side, so the copy becomes (mov X X) and the
   ; sweep drops it. only the adoption (mov %m X) at %m's birth moves; a refusal changes nothing.
   ; a move needs a straight-line window (no control/opaque form inside the span), X to itself
   ; (no other bare-X mention inside, no co-tenant mint overlapping) and its register released
   ; downstream (rel?). one cheap pass for an adoption-shaped mov gates the whole engine
   (rasg g fs)
    (: cfl (rafile g)
       (any9 (f . u))
        (two? f && <f = 'mov && vmint? g <>f && !(vmint? g <>>f) && elem <>>f cfl || any9 u)
       (any9 fs ? (rasg2 g fs cfl)))
   ; no r4 on the arm family (a4ize retargets a base-slot r4 to fp by position, and a moved mint
   ; can sit in a base slot) and no argument register (a ridden arrival's only def is its entry cvt)
   (rafile g)
    (filter (r9 \ !(elem r9 (csregs g) || r9 = fbase g || r9 = 'sp ||
                    elem r9 (argr g) ||
                    (arm? g && r9 = 'r4)))
            (lvgp g))
   (rasg2 g fs cfile)
    (: t (g 'vrt)
       mt {}                                 ; nom -> ([i kind] ..) descending
       st {}                                 ; position lists (descending) + 'cd
       (padd k i) (pin st k (i . st k))
       (madd nom i k) (pin mt nom ([i k] . mt nom))
       ; one walk: mentions per nom, the control classes, the mov candidates. 'ctl bars a window;
       ; for the release scans 'jout refuses, 'stop clears (caller-saved dies), 'ret reads lvret
       (w1 (f . u) i)
           ((two? f ?
               (<f @ op
                  (? (op = 'label) (padd 'ctl i)
                     (elem op '(jmp br jmpr sys)) (padd 'ctl i, padd 'jout i)
                     (elem op '(call callr callm ud2)) (padd 'ctl i, padd 'stop i)
                     (op = 'ret) (padd 'ctl i, padd 'ret i)
                     (op = 'align) ()
                     (rdsp g f @ rd9
                        (rd9 @ 'bar (padd 'ctl i, padd 'jout i)
                         (: (gr (a . u)) (madd a i 'r, gr u)
                            (gd (a . u)) (madd a i 'd, gd u)
                            (gr <rd9,
                             gd <>rd9,
                             op @ 'mov (pin st 'cd ([i <>f <>>f] . st 'cd)),
                             ()))))))),
            w1 u (i + 1))
       _ (w1 fs 0)
       mtr {}                                ; nom -> mentions ascending (memoized)
       (mup nom) (peep mtr nom 'none @ 'none (rev (mt nom) @ v (pin mtr nom v, v)) o o)
       (fpast l hi) (: (go2 l2 b) (? !(two? l2) b    ; descending bares: the smallest one > hi
                                     (<l2 > hi) (go2 >l2 <l2)
                                     b)
                       (go2 l ()))
       (posin? l lo hi exc)                          ; an ascending mention in [lo..hi] off exc?
        (two? l ?
           (<(<l) @ p (? (p > hi) ()
                         (p >= lo && nelem p exc) 1
                         (posin? >l lo hi exc))))
       (ctlin? (a . u) lo hi)  ; descending bare list: any strictly inside?
        (? (a >= hi) (ctlin? u lo hi)
           (a > lo) 1)
       (minp l) (atom? >l ? <<l (minp >l))
       ; the release scan: the earliest event past cite decides. a jump-out refuses, a call clears,
       ; a ret clears unless the register is in lvret, a def clears, a read refuses, no event clears
       (rel? nom cite)
        (: (go2 ml)
            (: p (: (nx (a . u)) (<a > cite ? [<a <>a] (nx u)) (nx ml))
               jp (fpast (st 'jout) cite)
               sp (fpast (st 'stop) cite)
               rtp (fpast (st 'ret) cite)
               big 1000000000
               pv (two? p ? <p big)
               jv (jp || big)
               sv (sp || big)
               rv (rtp || big)
               (? (pv = big && jv = big && sv = big && rv = big) 1
                  (jv < pv && jv < sv && jv < rv) 0
                  (sv < pv && sv < rv) 1
                  (rv < pv) (nelem nom (lvret g))
                  (<>p = 'd) 1))
           (go2 (mup nom)))
       ; co-tenants: every mint's mention span, listed under its current register
       tox {}
       (seed ms) (two? ms ?
                  (: m9 <ms l (mt m9)
                   (two? l ? (pin tox (t m9) ([(minp l) <<l] . tox (t m9))),
                    seed >ms)))
       _ (seed (keys t))
       (cot? (s9 . u) lo hi)                                ; a co-tenant span overlaps [lo..hi]?
        (<s9 <= hi && lo <= <>s9 || cot? u lo hi)
       mvd {}                                ; a mint moves at most once
       (att l)                                       ; candidates in form order, first wins
        (two? l ?
           (: c9 <l i <c9 D <>c9 S <>>c9
              dm (vmint? g D) sm (vmint? g S)
              m (? (dm && !sm) D (sm && !dm) S)
              (m ?
                 (: X (dm ? S D)
                    cur (t m)
                    dl (mt m)              ; descending; head is the last mention
                    (? (cur = X) ()              ; already identical: the sweep takes it
                       (mvd m) ()
                       (nelem X cfile) ()
                       (atom? dl) ()
                       (: ml (mup m)
                          lo9 (dm ? i (minp dl))
                          hi9 (dm ? <<dl i)
                          ndf (: (nd l2 n9) (!(two? l2) ? n9
                                               (nd >l2 (<><l2 @ 'd (n9 + 1) n9)))
                                (nd ml 0))
                          ; adoption only: a bridge onto r0 robs stld's forwarding through the staging cell
                          ok (dm && <<ml = i && <><ml = 'd)
                          ; the pair's closing copies are exceptions, not tenants (r0 -> %m -> r0
                          ; coalesces whole); only that direction -- a re-adoption resets m and refuses
                          exc (: (gx l2 a2)
                                  (!(two? l2) ? a2
                                     (: e9 <l2 p9 <e9
                                        hit (dm ? (<>e9 = X && <>>e9 = m && p9 > i)
                                               (<>e9 = m && <>>e9 = X && p9 < i))
                                        (gx >l2 (hit ? (p9 . a2) a2))))
                                 (gx (st 'cd) [i]))
                          (? !ok ()
                             (ctlin? (st 'ctl) lo9 hi9) ()
                             (posin? (mup X) lo9 hi9 exc) ()
                             (cot? (tox X) lo9 hi9) ()
                             (posin? (mup cur) lo9 hi9 ()) ()
                             !(rel? cur hi9) ()
                             ; a multi-def adoption rewrites X in place, so X's leftover must
                             ; be dead past the span too (the closing copy at hi9 defs X and clears it)
                             (dm && 1 < ndf && !(rel? X (hi9 - 1))) ()
                             (pin t m X,
                              pin mvd m 1,
                              pin tox X ([lo9 hi9] . peep tox X ()),
                              1))))),
               att >l)))
       (att (rev (st 'cd)),
        ()))
   (callish? (a . u))                                ; does the AST reach a call? (an inline splice still may)
    ; a statement expression resets the pool per statement: a barrier, like a call
    (a = 'call || a = 'sexpr || callish? a || callish? u)
   ; does the AST write anything? a face's base register must survive the rhs, so a
   ; store rides the face only past a write-free right side (calls clobber the pool too)
   (wrany? (a . u))
    (elem a '(asn post call asm vastart vaarg sexpr) || wrany? a || wrany? u)
   (tor0 g v)                                       ; land a value on the r0 protocol (frees its pool reg)
    (vreg v = 'r0 ? (vfs v)
       (: rd (vreg v) rl (rev (vfs v))
          lf (two? rl ? <rl)
          ; a trailing leax retargets to r0 outright: lea reads its sources before the dest write
          (two? lf && <lf = 'leax && <>lf = rd && wr? g rd ?
             (rev (['leax 'r0 <>>lf <>>>lf (lf 4) (lf 5)] . >rl) @ fs
              (rfree g rd,
               fs))
             (vfs v + [['mov 'r0 rd]] @ fs
              (rfree g rd,
               fs)))))
   (vdrop g v) (vfs v @ fs (rfree g (vreg v), fs))   ; the value is discarded: keep the effects, free the reg
   ; the result register for an op consuming rA: a writable operand, else a fresh pool reg, else r0
   (rdst g rA) (wr? g rA ? rA (ralloc g @ rX (rX || 'r0)))
   ; frame-direct: a constant-indexed frame-array element is a static slot (off + k*elsize), the
   ; address consumed by its own load/store, so escaping arrays too; pair/d128 keep the address lanes
   (afd g env e) (afd2 g env e ())                  ; -> (off elty) | ()
   (afd2 g env e fl)                                ; ..fl: a double element too (a load: the stores keep the int lanes)
    (e @ ('deref ('bin '+ ('var nm) ix))
          (knum g ix @ kc
           (: i (two? kc ? <kc)
            (!(charm? i) || i < 0 ? ()
           (vent g env nm @ en
              (!(two? en && <en = 'loc && arr? <>>en) ? ()
                 (<>(<>>en) @ et
                    ((ptr? et || elem et '(char schar cchar uchar bool short ushort int uint long ulong) ||
                      fl && flo? et && !(abl? g 'afdf)) &&
                     !(pair? g et) ?
                       [(<>en + i * tsz g et) et]))))))))
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
   (psreset g) (pin g 'pool (g 'pool0))
   ; the target seam: g 'tgt picks the ABI shapes; the IR stays neutral. the arm family retargets
   ; the frame base to fp at the end of build (a4ize)
   (a64? {'tgt 'a64}) 1
   (t32? g) (elem (g 'tgt) '(thumb2 thumb2sp arm thumb1))   ; AAPCS32: armv7e-m, linux's arm, armv6-M
   (sp64? {'tgt 'thumb2sp}) 1       ; armv7e-m with an sp-only fpu: f64 arithmetic softens
   (v6m? {'tgt 'thumb1}) 1          ; armv6-M: narrower immediates, no imm-mul, soft-divide, pop-pc epilogue
   (t32f? g) (t32? g && !(v6m? g))  ; with an fpu, hence AAPCS-VFP: floats ride s0..s15
   (rv64? g) (elem (g 'tgt) '(rv64 wasm))   ; rv64imfd (LP64): 64-bit, 8 gp args, hard doubles, the lr/fp frame
   (wasm? {'tgt 'wasm}) 1          ; ..which wasm rides whole; it differs only where its machine lacks an op
   (gtgt g) (wasm? g ? 'rv64 (peep g 'tgt 'x64))   ; the ABI name the asm dialect and the lane rosters read
   (x64? g) (peep g 'tgt 'x64 = 'x64)
   (a8? g) (a64? g || rv64? g)                        ; a64 + riscv share the AAPCS64 shapes
   (f32abi? g) (x64? g || a8? g)                      ; a prototyped float crosses a call as binary32 in its float register
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
   (wsize g) (ilp32? g ? 4 8)                       ; a pointer, a gp scalar, a stack cell
   (argr g) (? (a8? g) argregs-a64 (t32? g) argregs-t32 (ia32? g) (take (rpn g) '(r0 r2 r1)) argregs)   ; riscv a0..a7 map onto the same r0..r7; i386 -mregparm's eax edx ecx
   (ngp g) (? (a8? g) 8 (t32? g) 4 (ia32? g) (rpn g) 6)
   ; i386's hidden result pointer: eax under -mregparm (a variadic call keeps every word on the stack), else the first stack word
   (srreg? g va) (ia32? g && 0 < rpn g && !va)
   (pkr g) (? (a64? g) 'r15 (t32? g) 'r12 (rv64? g) 'r12 'r3)   ; the callr park (rbx / x15 / IP / t4), clear of the arg registers
   (ip2 g) (a8? g ? 'r1 'r2)                      ; an int-pair aggregate's second register (rax:rdx / x0:x1 / a0:a1)
   (ovb g) (? (a8? g) 32 (v6m? g) 12 (ilp32? g) 8 16)   ; overflow params above the push cells: x64 [ret+rbp]=16; a64/riscv 2x16; thumb2 lr+fp=8; v6m lr+fp+r4=12
   ; the a64 home pool: caller-saved, never an argument register (every home takes one prologue
   ; mov), clear of x15 (the callr park) and x16 (holo's far offset)
   hregs-a64 '(r10 r11 r12 r13 r14)
   hregs-t32 '(r5 r6 r7 r8)                          ; thumb2 callee-saved home pool (inert while nhome=0)
   ; the riscv home pool: caller-saved temporaries, never an argument register, clear of the
   ; callr park (t4 = r12) and holo's t5/t6; t1 last, the coldest seat
   hregs-rv64 '(r8 r10 r11 r9)
   (hregs g) (? (a64? g) hregs-a64 (rv64? g) hregs-rv64 (t32? g) hregs-t32 (ia32? g) () opool)   ; the home pool (x64 rides opool, positionally arg-aligned)
   (nhome g) (? (a64? g) 5 (rv64? g) 4 (ilp32? g) 0 6)      ; gp positions that can home; ilp32 spills every param
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
                 (ia32? g) (g 'ebx ? '(r5 r6 r3) '(r5 r6))   ; esi edi, and ebx where nothing parks there (cgfn); ebp the frame
                 (arm? g) ()
                 csx64)
   (deep? pl) (two? >>pl)                           ; a pool affords a priced seat: two remain after the take
   (fbase g) (arm? g ? 'fp 'r4)                   ; the frame base as post-build ir1 spells it (a4ize)
   ; 'bad is both a policy deopt ("take another lane") and "no lane anywhere"; only the second
   ; speaks, so nolane pins the phrase. last pin wins
   (nolane g txt) (pin g 'nolane txt, 'bad)
   (ontgt g) " on \(peep g 'tgt 'x64)"
   (no128 g) (nolane g "no lane for 128-bit integer arithmetic\(ontgt g)")
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
               'cmp (-255 <= n <= 255))               ; cmp/cmn imm8
       (fits32 n))
   ; may this op take n as its immediate? (the sweeps ask before rewriting a reg-reg form)
   (imma g op n) (op @ 'imul ((x64t? g || rv64? g) && fits32 n)   ; imul imm: x64's three-operand form, riscv materializes; a64/t32 have none
                       ('add || 'sub) (immok g 'addsub n)
                       'cmp (immok g 'cmp n)
                       (immok g 'log n))
   (uldop sz) (sz @ 1 'ldu1 2 'ldu2 4 'ldu4 'ld)
   (fnty g nm) (g 'sigs nm @ sig        ; return and params riding when sig'd
                (two? sig ? ['fn <sig <>sig] '(fn)))
   ; the SysV eightbyte classes of a by-value aggregate (its value is its address in r0): '(int) /
   ; '(sse) at <=8 bytes, two symbols at 9..16, () for a scalar, an unsized tag or >16 (memory)
   (aclass g ty)
    (!(stru? ty) || ia32? g ? ()                     ; i386 classes nothing: every aggregate is memory
       (peep (g 'stag) <>ty 0 @ se
          (? !(two? se) ()
             (16 < <>se) ()
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
   ; AAPCS64's float HFA: its member count, each member its own s register (the eightbyte classes
   ; would pack two to a d register) -> n | ()
   (a64hfa g ty) (a64? g && stru? ty && hfab g ty = 'float ? (tsz g ty // 4 @ n (0 < n <= 4 ? n)))
   ; ..its n words into a 16-byte cell at sp (ld4: a 12-byte one has no fourth word to read)
   (hfacell n) ('((sub sp sp 16)) + catmap (j \ [['ld4 'r1 'r0 (4 * j)] ['st4 'sp (4 * j) 'r1]]) ^n)
   (acls2 g ty ca cb) (aclass g ty @ (^ca ^cb) 1)
   (sse2? g ty) (acls2 g ty 'sse 'sse)       ; both eightbytes SSE: the xmm0:xmm1 pair
   (ipair? g ty) (acls2 g ty 'int 'int)      ; both INT: rax:rdx (return/result lanes)
   ; a t32 by-value aggregate outside its three lanes (the d-pair HFA, the 8B sse blob, the <=4B int one):
   ; mixed and int-pair composites refuse loud, as params, args and returns alike
   (t32nolane? g ty)
    (t32? g && stru? ty && !(sse2? g ty || aone g ty = 'sse && tsz g ty = 8 || aone g ty = 'int && tsz g ty <= 4))
   (t32core? g ty) (t32nolane? g ty && !(v6m? g) && 0 < tsz g ty)   ; ..which thumb2 lays as core words
   (aone g ty) (aclass g ty @ c (two? c && !(two? >c) ? <c))
   (aeb2 g ty) (aclass g ty @ c (two? c && two? >c ? c))       ; a 9..16B aggregate's two eightbyte classes (c0 c1), else ()
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
   (fnret ty) (!(two? ty && <ty = 'ptr) ? 'long        ; an indirect callee's result type: ('ptr ('fn ret ptys)) | 'long
                 (<>ty @ ft (fn? ft && two? >ft ? <>ft 'long)))
   (fnpts ty) (!(two? ty && <ty = 'ptr) ? ()           ; ..and its parameter types, () where the declarator had no prototype
                 (<>ty @ ft (fn? ft && 2 < #ft ? (ft 2) ())))
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
   (numty9 e ty) (litv e @ r (two? r ? (numty <r) ty))
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
   (znrw g ta tb ra rb)
    (u32bin? g ta tb ? ((usg? ta ? () [['zx4 ra]]) + (usg? tb ? () [['zx4 rb]])))
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
   (rflip op) (op @ 'lt 'gt 'gt 'lt 'le 'ge 'ge 'le op)      ; mirrored (n < x reads x > n): constant-on-the-left
   (irop op) (op @ '+ 'add '- 'sub '* 'imul '& 'and '| 'or '^ 'xor 'no) ; C op -> IR mnemonic; not one of the six -> 'no
   ; the NaN-honest ==/!= settle after ucomisd: unordered (PF=1) reads false for == and true
   ; for !=, so == ands the ordered bit in and != ors parity (r0 the truth, r1 the scratch)
   fsete '((set eq r0) (set np r1) (and r0 r0 r1))
   fsetn '((set ne r0) (set p r1) (or r0 r0 r1))
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
   (imby g rX sz) (arm? g ? [['li 'r3 sz] ['imul rX rX 'r3]] [['imul rX rX sz]])   ; arm mul has no imm form: the size rides r3 (free mid-expression)
   (homable? pty) (ptr? pty || elem pty '(long ulong))       ; an 8-byte gp scalar: what a register home can carry
   ; a home carries narrow gp scalars too, canonically extended (every def re-narrows through cvt,
   ; a param's entry cvt canonicalizes the arrival), so reads are zero forms; a bool home holds 0/1
   (lhomable? ty) (homable? ty || elem ty '(int uint short ushort char schar cchar uchar bool))
   ; a double or float local homes in an xmm register. the file is caller-saved: a crossing double
   ; joins g 'homes and fwrap wraps it, else only a name that crosses no call takes one
   (fhomable? ty) (ty = 'double || ty = 'float)
   (fphome? g ty) (ty = 'double || ty = 'float && f32abi? g)        ; a param: a float only where it arrives binary32
   (fwrap? g) ((x64? g || a64? g) && !(abl? g 'fwrap))
   ; a64's v8..v15 keep their low half across a call: a crossing double or float homes there for one
   ; save in the prologue (g 'cssv), never a wrap
   (fcspool g) (a64? g && !(abl? g 'fcs) && !(g 'hasasm) ? '(f8 f9 f10 f11 f12 f13 f14 f15) ())
   (ffile g) (? (abl? g 'fsel) ()
                 (x64? g) '(f8 f9 f10 f11 f12 f13 f14 f15)
                 (a64? g) '(f24 f25 f26 f27 f28 f29 f30 f31)   ; the pure temps past the parks (v8..v15 owe a save)
                 (rv64? g) '(f8 f9 f10 f11 f12 f13 f14 f15)    ; ft0..ft7, and wasm's locals
                 ())
   (fsel? g) ((x64? g || a64? g || rv64? g) && !(abl? g 'fsel))   ; the targets whose double lane rides the float file
   (fidx? g) ((x64? g || a64? g) && fsel? g)             ; ..and whose indexed float loads/stores are one form
   ; the homable-param fold for pgo, upar and ubuild: a float/sse param spends no gp seat, the
   ; walk stops at the home limit or a wide param, and (hx acc gpi param) folds each homable seat
   (homefold g ps gpi acc hx)
    (!(two? ps) ? acc
       (<><ps @ pty
          (? (flo? pty || sse2? g pty || aone g pty = 'sse) (homefold g >ps gpi acc hx)
             (nhome g <= gpi || d128? pty) acc
             (lhomable? pty) (homefold g >ps (gpi + 1) (hx acc gpi <ps) hx)
             (homefold g >ps (gpi + 1) acc hx))))
   ; the immediate lane: the left in a register, a constant on the right -> one imm-form op. a
   ; pointer +/- scales the constant; an unsigned / or % by a power of two reduces to shr/and. (ty forms) | 'no
   (pow2? n) (0 < n && 0 = n & (n - 1))
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
   ; a divide's sign fixup reads the dividend's sign (it agrees with the quotient's), so it spends
   ; n's seat; a remainder reads n again, so it keeps n and takes its own. a dividend in rax is copied first
   (magicop g op av aty n nty wnt)
    (: rA (vreg av)
       sgn !(cmpu g aty nty)
       bw (8 * wsize g)
       keep? (op = '%)
       copy? (x86? g && rpeq? g rA 'r0 || !keep? && !(wr? g rA))
       (grab k acc) (k < 1 ? (rev acc)
                       (ralloc g @ r
                          (r ? (grab (k - 1) (r . acc))
                             (map (x \ (rfree g x)) acc, 'no))))
       (? (t32? g || wasm? g) 'no               ; neither machine has a wide multiply
          (abl? g 'divk) 'no
          (n < 3) 'no
          !(n < (1 << (sgn ? (bw - 1) bw))) 'no
          (keep? && !(imma g 'imul n)) 'no
          (grab (1 + (copy? ? 1 0) + (keep? ? 1 0)) () @ rs
           (rs @ 'no 'no
            (magic1 n bw sgn @ [M s add?]
             (: rT <rs
                rN (copy? ? (rs 1) rA)
                rU (keep? ? (rs (copy? ? 2 1)) ())
                pre (copy? ? [['mov rN rA]] ())
                q9 ([['li rT M] [(sgn ? 'mulh 'umulh) rT rT rN]] +   ; the raw high word
                    (sgn && add? && [['add rT rT rN]]) +         ; ..and M's own fold-back
                    (sgn && 0 < s && [['sar rT s]]))
                fx (keep? ? rU rN)                    ; the seat the fold-back may spend
                tail (keep? ? [['imul rT rT n] ['sub fx rN rT]] ())  ; n - q*d, into the spare
                fs (? (!sgn && add?)                  ; the unsigned 65th bit: halve the gap
                       (: mid (q9 + [['sub fx rN rT] ['shr fx 1] ['add fx fx rT]] +
                               (0 < s ? [['shr fx s]] ()))
                          (keep? ? (mid + [['imul fx fx n] ['sub rT rN fx]]) mid))
                      sgn (q9 + (keep? ? [['mov fx rT]] ()) +
                           [['sar fx (bw - 1)] ['sub rT rT fx]] + tail)
                      (q9 + (0 < s ? [['shr rT s]] ()) + tail))
                rd (? (!sgn && add? && !keep?) fx   ; the unsigned fold-back answers in place
                      (!sgn && add? && keep?) rT
                      keep? fx
                      rT)
                (drop r9) (rpeq? g r9 rd || rpeq? g r9 rA ? () (rfree g r9))
                (map drop rs,
                 rpeq? g rd rA ? () (rfree g rA),
                 mkv (rbin g aty nty) rd (vfs av + pre + fs))))))))
   (immop g op av aty n nty wnt)                    ; av the left value tuple; nty the constant's C type; wnt the advisory destination
    (vreg av @ rA
       (? (llt? aty || d128? aty) 'no               ; a pair never rides the immediate lane
          (elem op '(eq ne lt le gt ge))
           ; a negative literal converts to the uint side (0xffffffff will not sit in a
           ; signed immediate): the shuttle materializes and narrows
           (? (u32? g aty && n < 0) 'no
              !(immok g 'cmp n) 'no
              (: rd (wnt || rdst g rA)
                 fs (vfs av + [['cmp rA n] ['set (scc op (cmpu g aty nty)) rd]])
                 (rpeq? g rd rA ? () (rfree g rA),
                  mkv 'long rd fs)))
          (elem op '(/ %))
           ; shr/and is licensed by the common type being unsigned (cmpu), not by either
           ; operand: `(long)-8 / 2u` is -4
           (? !(pow2? n) (magicop g op av aty n nty wnt)
              !(cmpu g aty nty)
               ; the signed pair: C rounds toward zero and sar toward -inf, so a negative
               ; dividend takes a bias of n-1 first (the sign mask shifted down to the low k bits)
               (: k (lg2 n) bw (8 * wsize g)
                  (? (abl? g 'divk) 'no
                     (n = 1) (op = '/ ? (mkv (rbin g aty nty) rA (vfs av))
                                (mkv (rbin g aty nty) 'r0 (vdrop g av + '((li r0 0)))))
                     (op = '% && !(immok g 'log (0 - n))) 'no
                     (ralloc g @ rT
                        (!rT ? 'no
                           ; a destination may alias its first source only, so the quotient
                           ; lands in the mask's own seat and the remainder takes a second
                           (: rd (op = '/ ? (wnt || rT) (wnt || rdst g rA))
                              bias [['mov rT rA] ['sar rT (bw - 1)] ['shr rT (bw - k)]]
                              body (op = '/ ? (bias + [['add rd rT rA] ['sar rd k]])
                                      (bias + [['add rT rT rA] ['and rT rT (0 - n)]
                                               ['sub rd rA rT]]))
                              (rpeq? g rd rT ? () (rfree g rT),
                               rpeq? g rd rA ? () (rfree g rA),
                               mkv (rbin g aty nty) rd (vfs av + body)))))))
              (op = '/) (n = 1 ? (mkv (rbin g aty nty) rA (vfs av))
                           (wr? g rA ?
                              (mkv (rbin g aty nty) rA (vfs av + [['shr rA (lg2 n)]]))
                              (wnt || rdst g rA @ rd   ; a borrowed home shifts a copy (no 3-address shr)
                                 (mkv (rbin g aty nty) rd (vfs av + [['mov rd rA] ['shr rd (lg2 n)]])))))
              (n = 1) (mkv (rbin g aty nty) 'r0 (vdrop g av + '((li r0 0))))
              !(immok g 'log (n - 1)) 'no                ; t32 has no simple and-imm: materialize (the register path)
              (: rd (wnt || rdst g rA)
                 fs (vfs av + [['and rd rA (n - 1)]])
                 (rpeq? g rd rA ? () (rfree g rA),
                  mkv (rbin g aty nty) rd fs)))
          (: sn (ptr? aty && elem op '(+ -) ? (n * tsz g <>aty) n)
             iop (irop op)
             ; a bare constant reads as int; a coated one carries its type, so `uint op <lit>`
             ; wraps and `uint op (ulong)k` widens, as C says
             u32 (nar32 g op aty nty (sn < 0 || !(usg? aty)))
             (? (iop = 'no) 'no
                !(imma g iop sn) 'no
                (: rt (ptr? aty ? aty (rbin g aty nty))
                   (sn = 0 && elem op '(+ -) ? (mkv rt rA (vfs av))
                      (: rd (wnt || rdst g rA)
                         fs (vfs av + [[iop rd rA sn]] + (u32 ? [[u32 rd]]))
                         (rpeq? g rd rA ? () (rfree g rA),
                          mkv rt rd fs))))))))
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
   ; a store narrows on its own: an int store needs no cvt before it (the value's cvt is for the
   ; expression's answer), and an integer cast at least as wide as the stored type, over a plain
   ; integer variable, truncates only what the store truncates
   (stcvt? ty) (elem ty '(char schar cchar uchar short ushort int uint))
   ; a narrow integer answer from a call: SysV and AAPCS64 leave the bits above it to the caller,
   ; so it extends here; riscv's and AAPCS32's callee extends, and ours always does
   (rext g ty) (? (!(x86? g || a64? g) || abl? g 'rext) ()
                  (ty = 'bool) [['zx1 'r0]]
                  (elem ty '(char schar cchar uchar short ushort int uint)) (cvt ty 'r0)
                  ())
   ints9 '(char schar cchar uchar short ushort int uint long ulong llong ullong)
   (stnar g env ty e)
    (e @ ('cast t ('var _))
          (rotty g env <>>e @ vt
             (elem t ints9 && elem vt ints9 && elem ty ints9 &&
              !(pair? g t || pair? g vt) && tsz g ty <= tsz g t && !(abl? g 'stnar) ?
                <>>e e))
         e)
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
   (fldf ty freg base off)                          ; load a float/double from [base+off] into freg (widen if float)
    (ty @ 'float [['ldss freg base off] ['cvtss2sd freg freg]]
                 [['ldsd freg base off]])
   ; the narrow scratch: x64 f2; a64 f16 (v8..v15 carry a callee-saved half); t32 f15, never allocated
   (fsc g) (? (a8? g) 'f16 (t32? g) 'f15 'f2)
   (fstf g ty base off val)                         ; val (a double in an xmm) to [base+off] as ty
    (ty @ 'float (fsc g @ f9 [['cvtsd2ss f9 val] ['stss base off f9]])   ; scratch narrows (val untouched)
                 [['stsd base off val]])
   ; the native single lane: a 'float value rides its f-register as binary32 (C's FLT_EVAL_METHOD 0);
   ; elsewhere a float widens on load and every value is a double
   (f32v? g) (x64? g || a8? g || t32? g || ia32? g)
   (n32? g ty) (ty = 'float && f32v? g)
   (fvt g ty) (n32? g ty ? 'float 'double)          ; the value type a ty load answers
   (fldv g ty freg base off) (n32? g ty ? [['ldss freg base off]] (fldf ty freg base off))
   (fstv g ty base off val) (n32? g ty ? [['stss base off val]] (fstf g ty base off val))   ; val in ty's own lane
   ; a value -> f0 in the lane ty stores from: binary32 for a native float, else a double
   (asfty g r ty) (n32? g ty ? (asf32 g r) (asflo g r))
   ; the double constant pool: one rodata block per distinct pattern, named by the pattern
   ; itself so a label is stable across the build's retries and shared across the unit
   (dbname u) (name ".D\(u)")
   (dblab g d) (u64 (fbits d) @ u
                  (pin (g 'dbls) u 1,
                   dbname u))
   (mkflo g d)                                      ; a double constant -> its value tuple
    (? (ilp32? g)                                   ; the 64-bit pattern splits over the r0:r1 pair
       (fbits d @ v
          (mkv 'double 'r0 [['li 'r0 (v & 4294967295)] ['li 'r1 ((v >> 32) & 4294967295)]
                            '(movqxr f0 r0)]))
       (x64? g && fsel? g) (mkv 'double 'r0 [['ldsdl 'f0 (dblab g d)]])
       ((a64? g || rv64? g) && fsel? g) (mkv 'double 'r0 [['la 'r0 (dblab g d)] ['ldsd 'f0 'r0 0]])
       (mkv 'double 'r0 [['li 'r0 (fbits d)] '(movqxr f0 r0)]))
   ; the type of a constant arithmetic expression: 'double, 'int (any integer type), or 'no.
   ; float answers 'no (the f suffix parses as a cast and rounds at every step)
   (dbty e)
    (atom? e ? 'no (<e @
     'var 'no
     'num 'int
     'flo 'double
     'bin (dbty <>>e @ 'no 'no
           a (dbty <>>>e @ b
               (? (b = 'no) 'no
                  (a = 'double || b = 'double) (elem <>e '(+ - * /) ? 'double 'no)
                  (elem <>e '(+ - * / % shl shr & | ^)) 'int
                  'no)))
     'un (<>e @ 'neg (dbty <>>e) 'bnot (dbty <>>e @ 'int 'int 'no) 'no)
     'cast (? (dbty <>>e = 'no) 'no
              (<>e = 'double) 'double
              (elem <>e '(bool char schar cchar uchar short ushort int uint long ulong llong ullong)) 'int
              'no)
     'no))
   ; love answers () for a NaN and `infinity` past the range, and neither is a fold
   (dfin? v) (gem? v && (v = 0.0 || !(v + v = v)))
   ; a constant double expression -> its value tuple | (); parse's cfold is the integer twin
   (cgdfold g e)
    (dbty e = 'double && (ffoldw !(ilp32? g) e @ v (dfin? v ? (mkflo g v) ())))
   ; result -> f0 as a double. t32: an unsigned word rides the U-converter, a pair source cvtlld
   (asflo g r) (? (vty r = 'float && f32v? g) (vfs r + '((cvtss2sd f0 f0)))
                  (flo? (vty r)) (vfs r)
                  ; an integer literal converts here, exactly, not at run time
                  (kli? g r @ k (charm? k)) (rfree g (vreg r), vfs (mkflo g (0.0 + kli? g r)))
                  (gcplx? (vty r))                  ; complex -> real reads re (C's implicit conversion)
                   (tor0 g r + (cxb (vty r) = 'float ?
                                '((ldss f0 r0 0) (cvtss2sd f0 f0))
                                '((ldsd f0 r0 0))))
                  (ilp32? g && llt? (vty r)) (tor0 g r + cvtlld g (usg? (vty r)) 0)
                  (ilp32? g && usg? (vty r)) (tor0 g r + '((cvtui2sd f0 r0)))
                  (vty r = 'ulong) (tor0 g r + ul2d)
                  (tor0 g r + '((cvtsi2sd f0 r0))))
   ; r as an integer literal a double holds exactly: one li, or a li and its neg -> k | ()
   (kli? g r) (: fs (vfs r) R (vreg r)
                 k (? (abl? g 'kflo || gcplx? (vty r) || (llt? (vty r) && ilp32? g)) ()
                      (fs @ [('li R2 k9)] (R2 = R ? k9)
                            [('li R2 k9) ('neg R3)] (R2 = R && R3 = R && charm? k9 ? (0 - k9))
                            ()))
                 (charm? k && (usg? (vty r) ? (0 <= k) 1) &&
                  k < 9007199254740992 && 0 - 9007199254740992 < k ? k))
   (asint g r) (? (vty r = 'float && f32v? g) (vfs r + '((cvttss2si r0 f0)))
                  (flo? (vty r)) (vfs r + '((cvttsd2si r0 f0)))
                  (tor0 g r))                                                   ; result -> r0 as an int
   ; C's usual conversions land on float (a float side, no double): the single lane's operands
   (f32rel? g ta tb) (f32v? g && (ta = 'float || tb = 'float) && !(ta = 'double || tb = 'double))
   ; result -> f0 as binary32: one rounding from any source
   (asf32 g r) (? (vty r = 'float && f32v? g) (vfs r)
                  (flo? (vty r) || gcplx? (vty r)) (asflo g r + '((cvtsd2ss f0 f0)))
                  (ia32? g && llt? (vty r)) (tor0 g r + ll2f g (usg? (vty r)))
                  (v6m? g && llt? (vty r))                 ; rt.c's one rounding, the answer's word in r0
                   (tor0 g r + [['call (usg? (vty r) ? '__aeabi_ul2f '__aeabi_l2f)] '(movdxr f0 r0)])
                  (ilp32? g && llt? (vty r))               ; sticky-folded to 53 bits: an exact double, one rounding
                   (tor0 g r + cvtlld g (usg? (vty r)) 1 + '((cvtsd2ss f0 f0)))
                  (ilp32? g && usg? (vty r)) (tor0 g r + '((cvtui2ss f0 r0)))
                  (vty r = 'ulong) (tor0 g r + ul2f g)
                  (tor0 g r + '((cvtsi2ss f0 r0))))
   ; i386 pair r0:r1 -> float: fild qword is exact, fstp dword the one rounding. unsigned past 2^63
   ; halves with the low bit sticky first and doubles after, as ul2f
   (ll2f g usg)
    (: a (m16? g ? [103] ()) o (m16? g ? [102] ())
       ld ['raw (o + [81] + o + [80] + a + [223 44 36] + a + [217 28 36]   ; push ecx; push eax; fild; fstp dword
                 + a + [243 15 16 4 36] + a + o + [141 100 36 8])]         ; movss xmm0,[esp]; lea esp,[esp+8]
       (!usg ? [ld]
          (: lb (nlab g ".lf") le (nlab g ".lg")
             ['(cmp r1 0) ['br 'lt lb] ld ['jmp le]
              ['label lb] '(mov r2 r0) '(and r2 r2 1) '(shr r0 1) '(mov r3 r1) '(shl r3 31) '(or r0 r0 r3)
              '(or r0 r0 r2) '(shr r1 1) ld '(addss f0 f0) ['label le]])))
   ; unsigned 64 -> float: past 2^63 halve with the low bit kept sticky, convert, double (gcc's shape)
   (ul2f g)
    (: lb (nlab g ".uf") ld (nlab g ".ug")
       ['(test r0 r0) ['br 'lt lb] '(cvtsi2ss f0 r0) ['jmp ld]
        ['label lb] '(mov r1 r0) '(shr r1 1) '(and r0 r0 1) '(or r1 r1 r0)
        '(cvtsi2ss f0 r1) '(addss f0 f0) ['label ld]])
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
   ; asint honouring an unsigned 64-bit destination; elsewhere C asks for the signed truncation
   (asintt g r ty)
    (!(ilp32? g) && flo? (vty r) && ty = 'ulong ? (asflo g r + dtoul g)
       (asint g r))
   ; the loop splitter's seat for a cell at this statement's tick, or () -- never inside a splice,
   ; whose statements do not tick
   (spr g nm) (? (g 'inlining) ()
                 (: q (peep g 'spq 0)
                    (go l) (? !(two? l) () (<<l <= q <= <><l) <>><l (go >l))
                    (go (peep (g 'spov) nm ()))))
   ; -- the environments: locals shadow globals --
   (vent g env name)                                ; -> ('regv rN ty) | ('regw (lo hi) ty) | ('loc off ty) | ('glo lbl ty) | 'bad
    (assoc name env @ e
       (two? e ?
           (: h <>e y <>>e                             ; a homed param's "off" slot is a (reg rN) list;
              (h @ ('reg x) ['regv x y]     ; a block-scope static's is (glob lbl)
                   ('regw x) ['regw x y]    ; a d128 pair home: (lo hi)
                   ('glob x) ['glo x y]
                   (spr g name @ r (r ? ['regv r y] ['loc h y]))))   ; a cell the loop splitter seats here
          (peep (g 'gregs) name () @ (s . y . _)
             (gas-regname (gtgt g) s @ r
                (nom? r ? ['regv r y] 'bad))
           (g 'glob name @ (a . b . _) ['glo a b] 'bad))))
   ; a static object's address: a frame slot off r4, a global off its label through the address
   ; temp; (f base off) lays the access
   (atstat en tmp f) (<en = 'loc ? (f 'r4 <>en) ([['la tmp <>en]] + f tmp 0))
   ; the type of an expression without its emission (arrays undecayed); every accumulator the
   ; walk touched is handed back as it was
   (peekty g env e)
    (: n0 (peep g 'n 0) s0 (g 'strs) o0 (peep g 'off 0) sl0 (g 'slots) fe0 (g 'fesc) fv0 (g 'fescv) fx0 (g 'fesca) fa0 (g 'fasecs)
       lv (clval g env e)
       _ (vm? lv ? (rfree g (vmb lv)))
       ty (bad? lv ? (cgexpr g env e () @ r (bad? r ? 'bad (rfree g (vreg r), vty r))) (vty lv))
       (pins g 'n n0 'strs s0 'off o0 'slots sl0 'fesc fe0 'fescv fv0 'fesca fx0 'fasecs fa0,
        ty))
   ; the fn's read graph, flow-blind: each local to the names its decl init and its writes read
   (rdgraph x)
    (: t {}
       (nms e acc) (? !(two? e) acc (<e = 'var) (<>e . acc) (foldl (a \ y \ nms y a) acc e))
       (edge v e) (pin t v (nms e (peep t v ())))
       (go e) (? !(two? e) 0
                 (: _ (e @ ('decl ps) (map (p \ two? >>p && edge <p <>>p) ps)
                           ('asn ('var v) r) (edge v r)
                           ('rmw _ ('var v) r) (edge v r)
                           0)
                    _ (map go e)
                    0))
       (go x, t))
   ; x = an ^ | & chain: the terms that read x again, through the graph, go last, so the run that
   ; does not wait on x's last value starts first. pure terms of the chain's own integer type only
   (rassoc g env dst e)
    (: op (e @ ('bin o _ _ && elem o '(^ | &)) o ())
       (? (!op || !(two? dst) || <dst != 'var || abl? g 'rassoc) e
          (: x <>dst
             gr (peep g 'rdg {})
             (leaves y) (y @ ('bin o a b && o = op) (leaves a + leaves b) [y])
             (reach? l) (: seen {}
                           (go ns) (? !(two? ns) ()
                                      (<ns = x) 1
                                      (seen <ns) (go >ns)
                                      (pin seen <ns 1, go (peep gr <ns () + >ns)))
                           (go (rdgraph0 l)))
             ls (leaves e)
             late (filter reach? ls)
             early (filter (l \ !(reach? l)) ls)
             o2 (early + late)
             (? (#ls < 3 || o2 = ls || any (l \ !(rotp? l)) ls) e
                (: ty (peekty g env e)
                   (!(nom? ty) || bad? ty || flo? ty || d128? ty ||
                    any (l \ peekty g env l != ty) ls ? e
                      (foldl (a \ l \ ['bin op a l]) <o2 >o2)))))))
   (rdgraph0 e) (? !(two? e) () (<e = 'var) [<>e] (foldl (a \ y \ rdgraph0 y + a) () e))
   ; a counted loop's step: for (..; v < E; v++ | ++v) with E no wider than v and v unwritten
   ; elsewhere steps only once v < E held, so v + 1 still fits and the home's re-narrow is the
   ; identity -> v | ()
   (bndv g env cnd stp body)
    (: v (stp @ ('post ('var v) 1) v ('asn ('var v) ('bin '+ ('var v2) ('num 1))) (v = v2 ? v ()) ())
       (wr? e) (? (atom? e) ()
                  (elem <e '(asm goto label) || elem <e '(asn post rmw addr) && two? >e && <>e = ['var v]) 1
                  (: (go l) (? (atom? l) () (wr? <l) 1 (go >l)) (go e)))
       (!v ? ()
          (cnd @ ('bin 'lt ('var v3) E)
           (v3 != v || wr? body || wr? E ? ()
              (: tv (peekty g env ['var v]) te (peekty g env E)
                 k (E @ ('num k) (charm? k ? k ()) ())       ; a literal bound: its value, not its type
                 (? (tv = 'int && (k ? (k <= 2147483647) (elem te '(int short ushort char schar cchar uchar bool)))) v
                    (tv = 'uint && (k ? (0 <= k <= 4294967295) (elem te '(uint ushort uchar cchar bool)))) v
                    ())))
           ())))
   (hcvt g nm ty r) (nm = g 'bndv ? () (cvt ty r))   ; the counted loop's step skips its re-narrow
   ; a targetable leaf re-emitted straight into rX -> forms | 'no. leaves are pure (no strs pin,
   ; no argpos), so re-aiming costs nothing
   (cgleaf g env e rX)
    (knum g e @ kc
       (? (two? kc) [['li rX <kc]]
          (<e != 'var) 'no
          (vent g env <>e @ en
           (? (bad? en) 'no
              !(<en = 'loc) 'no
              (<>>en @ ty
                 (stru? ty || arr? ty || flo? ty || d128? ty ? 'no
                    [[(ldop ty) rX 'r4 <>en]]))))))
   ; park the left out of r0 so the right may compute: a leaf re-aims at a fresh pool register,
   ; anything else takes one mov. the tuple | 'sh (pool dry: the caller keeps the memory shuttle)
   (vpark g env e v)
    (vreg v != 'r0 ? v
     (ralloc g @ rX
      (!rX ? 'sh
       (cgleaf g env e rX @ lf
        (lf != 'no ? (mkv (vty v) rX lf)
         (mkv (vty v) rX (vfs v + [['mov rX 'r0]])))))))
   ; a truth value in r0 that `cmp r0 0` can test: a double folds to d != 0.0
   (ctest g env e)
    (cgexpr g env e () @ r
       (? (bad? r) 'bad
          (flo? (vty r))                             ; NaN-honest: unordered is true (fsetn)
           (mkv 'long 'r0 (asflo g r + ('((li r1 0) (movqxr f1 r1) (ucomisd f0 f1)) + fsetn)))
          (d128? (vty r))                            ; wide truth: fold the pair into r0
           (mkv 'long 'r0 (vfs r + wor g))
          r))
   ; does e certainly compute a double? a static peek for the branch lanes: a miss (a shape
   ; the peek does not read) keeps the discard lane, so it is never wrong, only incomplete
   (flo9? g env e)
    (e @ ('flo . _) 1
         ('var nm) (vent g env nm @ en (two? en && flo? <>>en))
         ('cast . ty . _) (flo? ty)
         ('call . ('var nm) . _) (: sig (bad? (vent g env nm) ? (g 'sigs nm)) (two? sig && flo? <sig))
         ('bin o a b && elem o '(+ - * /)) (flo9? g env a || flo9? g env b)
         ('un 'neg x) (flo9? g env x)
         ('cond _ a b) (flo9? g env a || flo9? g env b)
         ('comma _ b) (flo9? g env b)
         ())
   ; the static type of a call head: an indirect call's arguments classify before the head
   ; evaluates, so the parameter types are read off the expression. a miss answers ()
   (hdty9 g env e)
    (e @ ('var nm) (vent g env nm @ en (bad? en ? () <>>en))
         ('dot b f) (: bt (hdty9 g env b)
                       fm (stru? bt ? (fmem g bt f) 'bad)
                       (bad? fm ? () <>fm))
         ('deref x) (hdty9 g env x @ it
                       (two? it && elem <it '(ptr arr) ? <>it ()))
         ('cast ty _) ty
         ; a[i] is *(a + i), so a table's element type reaches the deref through the sum's pointer operand
         ('bin o x y && o = '+)
          (hdty9 g env x @ a
             (two? a && elem <a '(ptr arr) ? a (hdty9 g env y)))
         ())
   ; (v & k) as a bare condition: test is flags-only, so the value's register survives (a mapped
   ; local stays mapped); the 'log gate is exactly test's immediate reach on each backend
   (tbr g env v k cc lbl)
    (cgexpr g env v () @ a
       (bad? a || flo? (vty a) ? 'bad
          (vfs a + [['test (vreg a) k] ['br cc lbl]] @ fs
             (rfree g (vreg a),
              fs))))
   ; the selects, tried before the branch lowering -> a value | 'no: `c ? 1 : 0` over a relation is
   ; its own value; `a < b ? a : b` and its twins are minsd/maxsd (strict lt/gt: <= differs on a
   ; signed zero); calm, deref-free, non-trapping int arms ride a cmov -- both arms evaluate before
   ; the condition, so nothing that could fault, trap or be written by it may speculate
   (relish? e) (two? e && (e @ ('bin op _ _) (elem op '(eq ne lt le gt ge))
                              ('land _ _) 1 ('lor _ _) 1 ('un 'not _) 1 ()))
   (spec? g env e)
    (two? e ?
       ; a weak global may be absent, its address 0: its load never speculates
       (e @ ('var nm) (vent g env nm @ en (two? en && elem <en '(regv loc glo) && !(d128? <>>en)
                                              && !(stru? <>>en || arr? <>>en)
                                              && !(<en = 'glo && elem nm (g 'weaks))))
            ('num _) 1
            ('bin op a b) (!(elem op '(/ %)) && spec? g env a && spec? g env b)
            ('un op a) (spec? g env a)
            ('cast ty a) (!(flo? ty || d128? ty) && spec? g env a)
            ()))
   (lbmen fs l) (!(two? fs) ? 0 ((two? <fs && elem l <fs ? 1 0) + lbmen >fs l))   ; forms naming l
   (csel g env cnd ea eb wnt)
    (? (relish? cnd && (ea @ ('num 1) 1 ()) && (eb @ ('num 0) 1 ())) (cgexpr g env cnd wnt)
       (relish? cnd && (ea @ ('num 0) 1 ()) && (eb @ ('num 1) 1 ())) (cgexpr g env ['un 'not cnd] wnt)
       (fminmax g env cnd ea eb @ r
          (? (r != 'no) r ((x86? g && !(old86? g)) || a64? g) (icmov g env cnd ea eb) 'no)))   ; rv64 has no cmov, nor i386 before the 686
   (fminmax g env cnd ea eb)
    (cnd @ ('bin op a b && x64? g && elem op '(lt gt) && flo9? g env a && flo9? g env b &&   ; minsd/maxsd are x64's (fmin's NaN differs)
            !(wrany? a || callish? a || wrany? b || callish? b) &&
            (ea = a && eb = b || ea = b && eb = a))
     (: da (ea = a)                                  ; the dst arm is the left operand
        opsd (da ? (op @ 'lt 'minsd 'maxsd) (op @ 'lt 'maxsd 'minsd))
        lv (cgexpr g env ea ())
        rv (bad? lv ? 'bad (cgexpr g env eb ()))
        (bad? lv || bad? rv ? 'bad
           (: af (asflo g lv) bf (asflo g rv) sim (fsimple g bf)
              (two? sim ? (mkv 'double 'r0 (af + <sim + [[opsd 'f0 <>sim]]))
                 (mkv 'double 'r0 (fshut g af bf + [[opsd 'f1 'f0] '(movapd f0 f1)]))))))
     'no)
   (negcc c) (c @ 'eq 'ne 'ne 'eq 'lt 'ge 'ge 'lt 'le 'gt 'gt 'le 'below 'ae 'ae 'below
                 'be 'above 'above 'be 's 'ns 'ns 's 'p 'np 'np 'p 'vs 'vc 'vs)
   (fneu? l) (!(two? l) ? 1 (<l @ f (two? f && elem <f fneu && <>f = 'r0 ? (fneu? >l))))
   (icmov g env cnd ea eb)
    (!(spec? g env ea && spec? g env eb && !(flo9? g env ea || flo9? g env eb) &&
       !(wrany? cnd || callish? cnd)) ? 'no
       (: (bl l) (two? >l ? (<l . bl >l))
          ; an arm already in a register of its own (a home, a pool value) is read there; a protocol
          ; value parks in a fresh pool register -> (reg forms) | (). a park is taken before the next
          ; arm is built: a later borrow (a shift count's spare) reads the free list, not the forms
          (arm v) (rpeq? g (vreg v) 'r0 ?
                     (ralloc g @ rA (!rA ? () [rA (tor0 g v + [['mov rA 'r0]])]))
                     [(vreg v) (vfs v)])
          t (cgexpr g env ea ())
          (bad? t ? 'bad
             (: tn (fneu? (vfs t))
                pa (tn ? 'lay (arm t))                 ; a neutral t may lay after the compare
                (!pa ? (vdrop g t, 'no)
                   (cgexpr g env eb () @ el
                      (bad? el ? ((two? pa ? (rfree g <pa) (vdrop g t)), 'bad)
                         (: en (fneu? (vfs el))
                            ; who lays after the compare: a neutral el (t parks; el borrows nothing), else a neutral t,
                            ; else both park ahead of it
                            lay (? en 'el (pa = 'lay) 't 'both)
                            pa2 (pa = 'lay && lay = 'el ? (arm t) pa)
                            pb (? (lay = 'el) 'lay (two? pa2) (arm el) ())
                            ta9 (numty9 ea (vty t)) tb9 (numty9 eb (vty el))
                            ua (parith? ta9 && parith? tb9 && !(d128? ta9) && !(d128? tb9))
                            rt (ua ? (puac 1 ta9 tb9) (vty t))
                            ; a 32-bit unsigned result owes a signed arm a zx4 the lay cannot place: refuse
                            nar (u32? g rt && !(usg? ta9 && usg? tb9))
                            (drop9 _) ((two? pa2 ? (rfree g <pa2) (vdrop g t)),
                                       (two? pb ? (rfree g <pb) (vdrop g el)),
                                       'no)
                            (? (!(two? pa2) && !(pa2 = 'lay)) (drop9 0)
                               (!(two? pb) && !(pb = 'lay)) (drop9 0)
                               nar (drop9 0)
                               (: lbl (nlab g ".v")
                                  c (cbranch g env cnd 'ne lbl)
                                  (bad? c ? 'bad
                                     (: lf (two? c ? (c (#c - 1)))
                                        ; one branch, the last form, and the label named nowhere else: its flags are the select's
                                        (!(two? lf && <lf = 'br && <>>lf = lbl && 1 = lbmen c lbl) ? (drop9 0)
                                           (: cc <>lf
                                              rA (two? pa2 ? <pa2) rB (two? pb ? <pb)
                                              fs (lay @ 'el (<>pa2 + bl c + tor0 g el +
                                                             (rpeq? g rA 'r0 ? () [['cmov cc 'r0 rA]]))
                                                      't (<>pb + bl c + tor0 g t +
                                                          (rpeq? g rB 'r0 ? () [['cmov (negcc cc) 'r0 rB]]))
                                                      (<>pa2 + <>pb + bl c + [['mov 'r0 rB]] +
                                                       (rpeq? g rA rB ? () [['cmov cc 'r0 rA]])))
                                              (rA ? (rfree g rA), rB ? (rfree g rB),
                                               mkv rt 'r0 fs)))))))))))))))
   ; cbranch: jump to lbl when the condition is false (cc 'eq) or true (cc 'ne), unmaterialized;
   ; fusions cmp+br, !, &&/||, tbr, fcb -> forms | 'bad. xpct: __builtin_expect(e, k)'s args | ()
   (xpct e) (two? e && <e = 'call && <>e = ['var "__builtin_expect"] && two? (e 2) ? (e 2))
   (cbranch g env e cc lbl)
    (cfold !(ilp32? g) e @ k                      ; a constant test is a jmp or nothing: do { } while (0)
     (cint? k ? ((k != 0) = (cc = 'ne) ? [['jmp lbl]])
    (two? (xpct e) ? (cbranch g env <(e 2) cc lbl)          ; the hint is its first argument's test
    (e @
       ('un 'not x)
        (cbranch g env x (cc @ 'eq 'ne 'eq) lbl)
       ('land a b)
        (cc @ 'eq
           (: f1 (cbranch g env a 'eq lbl)
              f2 (cbranch g env b 'eq lbl)
            (bad? f1 || bad? f2 ? 'bad (f1 + f2)))
           (: lf (nlab g ".f")
              f1 (cbranch g env a 'eq lf)
              f2 (cbranch g env b 'ne lbl)
            (bad? f1 || bad? f2 ? 'bad (f1 + f2 + [['label lf]]))))
       ('lor a b)
        (cc @ 'ne
           (: f1 (cbranch g env a 'ne lbl)
              f2 (cbranch g env b 'ne lbl)
            (bad? f1 || bad? f2 ? 'bad (f1 + f2)))
           (: lt (nlab g ".t")
              f1 (cbranch g env a 'ne lt)
              f2 (cbranch g env b 'eq lbl)
            (bad? f1 || bad? f2 ? 'bad (f1 + f2 + [['label lt]]))))
       ('bin op lhs rhs && elem op '(eq ne lt le gt ge))
        ; the left parks before the right evaluates (allocation order must match execution order).
        ; fcb: x64 above/ae are unordered-false, so < and <= compare swapped and ==/!= carry parity; a64 is native
        (: (fcb z9)
            (cgexpr g env lhs () @ a
               (bad? a ? 'bad
                  (: af (asflo g a)
                     b (cgexpr g env rhs ())
                     (bad? b ? 'bad
                        (: s9 (f32rel? g (vty a) (vty b))     ; C's conversions say float: compare singles
                           mid (? s9 (fshuts g (asf32 g a) (asf32 g b)) (fshut g af (asflo g b)))
                           swp (elem op '(lt le))
                           cf [[(s9 ? 'ucomiss 'ucomisd) (swp ? 'f0 'f1) (swp ? 'f1 'f0)]]
                           ecc (? (arm? g)               ; VCMP/FCMP flags: gt/ge unordered-false native
                                  (: t9 (? (elem op '(lt gt)) 'gt (elem op '(le ge)) 'ge op)
                                     (cc @ 'ne t9 (negrel t9)))
                                  (elem op '(lt gt)) (cc @ 'ne 'above 'be)
                                  (elem op '(le ge)) (cc @ 'ne 'ae 'below))
                           (? ecc (mid + cf + [['br ecc lbl]])
                              (op = (cc @ 'ne 'ne 'eq))
                               (mid + cf + [['br 'p lbl] ['br 'ne lbl]])
                              (nlab g ".u" @ sk
                                 (mid + cf + [['br 'p sk] ['br 'eq lbl] ['label sk]]))))))))
           (bcc o u) (scc (cc @ 'ne o (negrel o)) u)
           ; a pair side (t32 llong) branches off subs/sbcs via pbrf; a constant or 32-bit
           ; other side widens to a pair in r2:r3
           (pnum v) [['li 'r2 (v & 4294967295)] ['li 'r3 (v < 0 ? 4294967295 0)]]
           ; a wide relation settles 0/1 through c128 (the left rides the cell), then branches on it
           (wbr o2 af u2) (af + ([['c128 (scc o2 u2) 'sp]] + (wdrop + ['(cmp r0 0) ['br cc lbl]])))
           kr (knum g rhs)
           kl (knum g lhs)
           ; one side a cmp-immediate constant: x compares against k with x on the left (a constant
           ; left mirrors through rflip); a pair or wide x rides its own kit, a float re-fuses through fcb
           (kbr o k x)
            (cgexpr g env x () @ a
               (? (bad? a) 'bad
                  (flo? (vty a)) (rfree g (vreg a), fcb ())
                  (pair? g (vty a))
                   (vfs a + pnum <k + pbrf g o (usg? (vty a)) 'r0 'r1 'r2 'r3 cc lbl)
                  (d128? (vty a))
                   (? !(w128? g) (no128 g)
                      ; against zero: a signed pair's sign is its high word's, and == 0 is lo | hi
                      (<k = 0 && (elem o '(eq ne) || vty a = 'i128 && elem o '(lt ge)))
                       (elem o '(eq ne) @ z
                          (as128 g a + (z ? '((or r0 r0 r2)) ()) + [['cmp (z ? 'r0 'r2) 0] ['br (bcc o ()) lbl]]))
                      (wbr o (as128 g a + wpush g + wnum g <k) (vty a = 'u128)))
                  (: n <k
                     cc9 (bcc o (cmpu g (vty a) <>k))
                     ; a negative literal converts to the uint side (the masked pattern
                     ; will not sit in a signed immediate): materialize it
                     fs (u32? g (vty a) && n < 0 ?
                           (: sc (vreg a @ 'r1 'r0 'r1)
                              (vfs a + [['li sc (n & 4294967295)] ['cmp (vreg a) sc] ['br cc9 lbl]]))
                           (vfs a + [['cmp (vreg a) n] ['br cc9 lbl]]))
                     (rfree g (vreg a),
                      fs))))
           (? (flo9? g env lhs || flo9? g env rhs) (fcb ())   ; a side the peek reads as double: fuse outright
              (two? kr && immok g 'cmp <kr) (kbr op kr lhs)
              (two? kl && immok g 'cmp <kl) (kbr (rflip op) kl rhs)
              ; the destination die: with no call in the way the left aims at its park before it
              ; evaluates; an unhonored hint (a mapped local, a float, a wide) hands the register back
              (: pk (callish? lhs || callish? rhs ? () (ralloc g))
                 a (cgexpr g env lhs pk)
                 (pk && !(!(bad? a) && rpeq? g (vreg a) pk) ? (rfree g pk),
                  (? (bad? a) 'bad
                     (flo? (vty a)) (rfree g (vreg a), fcb ())
                     (: ah (callish? rhs || llt? (vty a) || d128? (vty a) ? 'sh (vpark g env lhs a))           ; a call on the right / a pair left: memory only
                        (ah = 'sh ?
                            (: pA (pair? g (vty a))
                               wA (d128? (vty a))
                               af0 (wA || pA ? () (tor0 g a))
                               af (? wA (as128 g a + wpush g)
                                     pA (asll g a + spush2)
                                     (af0 + spush 'r0))
                               b (cgexpr g env rhs ())
                               (? (bad? b) 'bad
                                  (flo? (vty b)) (wA ? 'bad (rfree g (vreg b), fcb ()))
                                  (wA || d128? (vty b))                 ; a wide side: c128 over the cell
                                   (!(w128? g) ? (no128 g)
                                      (: u2 ('u128 = (wA ? (d128? (vty b) ? (wbin (vty a) (vty b)) (vty a)) (vty b)))
                                         ; a word left widens its cell hi by its own signedness
                                         fixa (wA ? () (wfix g (vty a)))
                                         (af + as128 g b + fixa +
                                          ([['c128 (scc op u2) 'sp]] + (wdrop + ['(cmp r0 0) ['br cc lbl]])))))
                                  (ilp32? g && (pA || llt? (vty b)))
                                   (cmpu g (vty a) (vty b) @ u2
                                      (af + asll g b +
                                       (pA ? (spop2 'r2 'r3 + pbrf g op u2 'r2 'r3 'r0 'r1 cc lbl)
                                          (spop 'r2
                                           + pwid (vty a) 'r2 'r3
                                           + pbrf g op u2 'r2 'r3 'r0 'r1 cc lbl))))
                                  (: bf (tor0 g b)
                                     ta9 (numty9 lhs (vty a)) tb9 (numty9 rhs (vty b))
                                     brf (znrw g ta9 tb9 'r1 'r0 +
                                          ['(cmp r1 r0) ['br (bcc op (cmpu g ta9 tb9)) lbl]])
                                     (shut1 g a af0 bf + brf))))
                           (cgexpr g env rhs () @ b
                              (? (bad? b) 'bad
                                 (flo? (vty b)) (rfree g (vreg ah), rfree g (vreg b), fcb ())
                                 (d128? (vty b))                       ; a word park against a wide right: build its cell
                                  (!(w128? g) ? (no128 g)
                                     (: fs (vfs ah + vfs b
                                            + ['(sub sp sp 16) ['st 'sp 0 (vreg ah)]]
                                            + wfix g (vty ah)
                                            + ([['c128 (scc op (vty b = 'u128)) 'sp]] + (wdrop + ['(cmp r0 0) ['br cc lbl]])))
                                        (rfree g (vreg ah), rfree g (vreg b),
                                         fs)))
                                 (pair? g (vty b))                     ; a 32-bit park against a pair right: widen the park
                                  (: fs (vfs ah + vfs b
                                         + [['mov 'r2 (vreg ah)]]
                                         + pwid (vty ah) 'r2 'r3
                                         + pbrf g op (cmpu g (vty ah) (vty b)) 'r2 'r3 'r0 'r1 cc lbl)
                                     (rfree g (vreg ah), rfree g (vreg b),
                                      fs))
                                 (: ta9 (numty9 lhs (vty ah)) tb9 (numty9 rhs (vty b))
                                    cc9 (bcc op (cmpu g ta9 tb9))
                                    ; the zx4 narrow cannot touch a home in place: copy through r0:r1 (b first: it may sit in r1)
                                    zn (znrw g ta9 tb9 'r1 'r0)
                                    fs (two? zn ?
                                          (vfs ah + vfs b
                                           + [['mov 'r0 (vreg b)] ['mov 'r1 (vreg ah)]]
                                           + zn
                                           + ['(cmp r1 r0) ['br cc9 lbl]])
                                          (vfs ah + vfs b + [['cmp (vreg ah) (vreg b)] ['br cc9 lbl]]))
                                    (rfree g (vreg ah), rfree g (vreg b),
                                     fs)))))))))))
       ; the mask-test shapes: (v & k) / (k & v). ms is syntax, so its found-test is
       ; structural (a `?` on a term would net it)
       (: ms (e @ ('bin . '& . ops) ops ())
          lhs (two? ms ? <ms)
          rhs (two? ms ? <>ms)
          kr (two? ms ? (knum g rhs))
          kl (two? ms ? (knum g lhs))
          try (? !(two? ms) 'no
                 (two? kr && immok g 'log <kr) (tbr g env lhs <kr cc lbl)
                 (two? kl && immok g 'log <kl) (tbr g env rhs <kl cc lbl)
                 'no)
          (try != 'no ? try
           (cgexpr g env e () @ c
              (? (bad? c) 'bad
                 (flo? (vty c))
                  ; d != 0.0, NaN-honest: the parity dance rides the branch pair
                  (: fs (asflo g c + (ilp32? g ?               ; the zero pattern zeroes the r1:r2 pair
                                    '((li r1 0) (li r2 0) (movqxr f1 r1) (ucomisd f0 f1))
                                    '((li r1 0) (movqxr f1 r1) (ucomisd f0 f1))))
                     (rfree g (vreg c),
                      (? (arm? g) (fs + [['br cc lbl]])   ; VCMP/FCMP ne/eq are NaN-honest whole
                         (cc = 'ne) (fs + [['br 'p lbl] ['br 'ne lbl]])
                         (nlab g ".u" @ sk
                          (fs + [['br 'p sk] ['br 'eq lbl] ['label sk]])))))
                 (pair? g (vty c))                     ; pair truth: either word nonzero (v6-M, i386: no r12 dest; r0 is dead past the branch)
                  (vfs c + [['ors (v6m? g || ia32? g ? 'r0 'r12) 'r0 'r1] ['br cc lbl]])
                 (d128? (vty c))                       ; wide truth: either word nonzero
                  (vfs c + wor g + '((cmp r0 0)) + [['br cc lbl]])
                 (vfs c + [['cmp (vreg c) 0] ['br cc lbl]] @ fs
                    (rfree g (vreg c),
                     fs))))))))))
   ; n little-endian bytes of a constant (the global initializer image)
   (les n v) (map (i \ (v >> (8 * i)) & 255) ^n)
   (zeros n) (n >= 1 ? (0 . zeros (n - 1)))
   ; a straight-line block copy of sz bytes, src in r0, dest in r1, r2 the scratch
   (bcopy g off sz acc)                              ; a word at a time (8, 4 on t32), then a byte tail
    (wsize g @ w
       (? (w <= sz) (bcopy g (off + w) (sz - w)
                     (acc + [['ld 'r2 'r0 off] ['st 'r1 off 'r2]]))
          (0 < sz) (bcopy g (off + 1) (sz - 1)
                     (acc + [['ld1 'r2 'r0 off] ['st1 'r1 off 'r2]]))
          acc))
   ; ..their -mstrict-align twins, by the chunks an a-aligned run carries
   (bcopya off sz a) (foldl (acc \ [p k] \ acc + [[(uldop k) 'r2 'r0 (off + p)] [(k @ 1 'st1 2 'st2 4 'st4 'st) 'r1 (off + p) 'r2]])
                            () (alchunks sz a))
   (bseta off sz a) (foldl (acc \ [p k] \ acc + [[(k @ 1 'st1 2 'st2 4 'st4 'st) 'r1 (off + p) 'r2]]) () (alchunks sz a))
   ; the alignment a value's address carries: its face's mark, else its type's
   (val9 g v) (ua? v ? (vma v) (tal g (vty v)))
   ; a struct that rides registers by the word, which its alignment cannot carry
   (salw? g ty) (sal? g && tal g ty < 8)
   ; a pointer's mark from a misaligned array (sal only): the alignment its pointee is short of
   (pal g ty) (sal? g && two? (drop 2 ty) && (ty 2) < tal g <>ty ? (ty 2) ())
   ; a struct type as the value v's address aligns it: v's mark, when it carries one
   (amark ty v) (stru? ty && stru? (vty v) && two? (drop 2 (vty v)) ? [<ty <>ty ((vty v) 2)] ty)
   (ldw2 g ty)                                     ; a 9..16B aggregate at r0 into its 16-byte cell
    (salw? g ty ? (: n (tsz g ty) a (tal g ty)
                     (['(sub sp sp 16)] + ldal 'r1 'r0 8 (n - 8) a + [['st 'sp 8 'r1]] + ldal 'r1 'r0 0 8 a + [['st 'sp 0 'r1]]))
       cell2w)
   ; under -mstrict-align, what a mem builtin's pointer is known to align: a named object's own
   ; alignment, anything else a byte
   (memal g env e)
    (e @ ('cast _ x) (memal g env x)
         ('addr ('var nm)) (vent g env nm @ en (two? en && elem <en '(loc glo) ? (tal g <>>en) 1))
         1)
   ; ..and its fill twin: dest address in r1, the splatted word in r2. a byte tail stores
   ; the low byte of the same register, which for a splat is the byte the caller asked for
   (bset g off sz acc)
    (wsize g @ w
       (? (w <= sz) (bset g (off + w) (sz - w) (acc + [['st 'r1 off 'r2]]))
          (0 < sz) (bset g (off + 1) (sz - 1) (acc + [['st1 'r1 off 'r2]]))
          acc))
   ; memcpy/memset with a small constant size lay straight-line, by name (declining where a local
   ; shadows it or the fn is the library's own). no memmove: bcopy interleaves loads and stores
   (meminl g) (8 * wsize g)                          ; the widest expansion: 8 words either way
   (memk g e) (knum g e @ k (two? k ? <k (cfold !(ilp32? g) e @ v (cint? v ? v ()))))
   (memnm? g bi nm) (bi = nm && !(nobi? g nm) || bi = "__builtin_\(nm)")
   (memok? g env bi args)                            ; may this call expand at all?
    (3 = #args && !(abl? g 'meminl) && bad? (vent g env bi) && !(g 'fn = bi))
   (cgmem g env bi args)                             ; -> the value | 'no (leave it a call)
    (!(memok? g env bi args) ? 'no
       (memk g (args 2) @ n9
          (? (!(charm? n9) || n9 < 0 || meminl g < n9) 'no
             (memnm? g bi "memset")
              (memk g <>args @ c9
                 (!(charm? c9) ? 'no
                    ; the destination is an argument, not an address the fn keeps: argpos,
                    ; the way a real call marks one, or every &local memset loses its sibcalls
                    (: dv (elem <<args '(addr var) ? (pin g 'argpos 1),
                           cgexpr g env <args ())
                       (pin g 'argpos (),
                        bad? dv ? 'bad
                          ((c9 & 255) * (8 = wsize g ? 72340172838076673 16843009) @ v9
                             (mkv '(ptr void) 'r0 $
                              relean (tor0 g dv) + [['mov 'r1 'r0] ['li 'r2 v9]] +
                              (sal? g ? (bseta 0 n9 (memal g env <args)) (bset g 0 n9 ()))))))))
             (memnm? g bi "memcpy")
              ; the destination parks in a pool seat, never on the machine stack (sp motion costs
              ; a musttail fn its tail); a pool seat cannot survive a call, so a callish arg declines
              (callish? <args || callish? <>args ? 'no
                 (: dv (elem <<args '(addr var) ? (pin g 'argpos 1),
                        cgexpr g env <args ())
                    (pin g 'argpos (),
                     bad? dv ? 'bad
                       (: fd (tor0 g dv)
                          rd (ralloc g)
                          (!rd ? 'no
                             (: sv (elem <<>args '(addr var) ? (pin g 'argpos 1),
                                    cgexpr g env <>args ())
                                (pin g 'argpos (),
                                 rfree g rd,
                                 bad? sv ? 'bad
                                   (mkv '(ptr void) 'r0 $
                                    relean fd + [['mov rd 'r0]] + relean (tor0 g sv) +
                                    [['mov 'r1 rd]]
                                    + (sal? g ? (bcopya 0 n9 (min (memal g env <args) (memal g env <>args))) (bcopy g 0 n9 ()))
                                    + '((mov r0 r1))))))))))
             'no)))
   ; a spill across a nested sub-eval (which may call): a bare 8-byte push would leave rsp at
   ; 8 mod 16 across the inner call, so a whole 16-byte cell
   (spush r) ['(sub sp sp 16) ['st 'sp 0 r]]
   (spop r)  [['ld r 'sp 0] '(add sp sp 16)]
   ; the shuttle skip: a right side whose forms never write r1 or touch sp may run with the left
   ; parked in r1, one mov in place of the push/pop
   (r1safe? g fs)
    (!(two? fs) ? 1
       (<fs @ f
          (two? f ?
             (rdsp g f @ rd
                (? (rd = 'bar) ()
                   (elem 'r1 <>rd) ()
                   (elem 'sp <>rd) ()
                   (r1safe? g >fs))))))
   ; the pool cell: the left holds in a pool register across the right unless a call, an unknown
   ; op or a write of the candidate bars it; the write set reads resolved (this scan runs before vrfix)
   (psafe? g fs rz)
    (: r (rp g rz)
       (hit9 ds) (? !(two? ds) ()
                    (rp g <ds = r) 1
                    (hit9 >ds))
       (safe9 l)
        (!(two? l) ? 1
           (<l @ f
              (? !(two? f) (safe9 >l)
                 (elem <f '(label br jmp)) (safe9 >l)
                 (rdsp g f @ rd
                    (? (rd = 'bar) ()
                       (hit9 <>rd) ()
                       (safe9 >l))))))
       (safe9 fs))
   ; a free pool register bf never writes -> r | (). a borrow, not an allocation: the span
   ; closes inside its own staging, so the free list keeps its order
   (spare g bf)
    (: (go l) (? !(two? l) ()
                 (psafe? g bf <l) <l
                 (go >l))
       (go (g 'pool)))
   ; the shuttle: left in r1, right in r0 (af built before bf: the free order). a left in a
   ; register the right never writes reads through it; else the r1 skip, a pool cell, the sp cell last
   (shut1 g av af bf)
    (vreg av @ rA
       (? (!(two? (vfs av)) && rA != 'r0 && psafe? g bf rA) (bf + [['mov 'r1 rA]])
          (r1safe? g bf) (af + '((mov r1 r0)) + bf)
          (vspare g (spare g bf) @ s
             (s ? (af + [['mov s 'r0]] + bf + [['mov 'r1 s]])
                (af + spush 'r0 + bf + spop 'r1)))))
   ; the double twin: left in f1, right in f0. a float-file target parks the left in an xmm the
   ; right never writes (f1 itself when it can); else the bits hold in a gp register or the stack
   ; across the right (movqrx aims straight at it); ilp32 moves the pair through the gp stack
   (fclob? fs fr)                                   ; does fs write fr, or call out?
    (two? fs ?
       (<fs @ f
          (? !(two? f) (fclob? >fs fr)
             (elem <f barops) 1
             (<>f = fr) 1
             (fclob? >fs fr))))
   (fpick fs l) (? !(two? l) () (fclob? fs <l) (fpick fs >l) <l)
   (fparks g) (a64? g ? fpark-a64 fpark)
   ; a right operand that reads direct, no shuttle: an xmm home alone (its register is the
   ; operand), or gp-only forms then one write of f0, retargeted to f1 -> (forms operand) | ()
   (fsimple g fs)
    (two? fs ?
       (: hd (: (go l) (two? >l ? (<l . go >l)) (go fs))
          lf (fs (#fs - 1))
          k <lf
          (fmen? l) (? !(two? l) () (elem <l fregs16) 1 (fmen? >l))
          (gpo? l) (!(two? l) ? 1
                      (<l @ f
                         (? !(two? f) () (rdsp g f = 'bar) () (fmen? >f) () (gpo? >l))))
          (? (!(two? hd) && k = 'movapd && <>lf = 'f0 && nom? <>>lf) [() <>>lf]
             (elem k '(movqxr ldsd ldsdl cvtsi2sd) && <>lf = 'f0 && gpo? hd)
              [(hd + [(k . 'f1 . >>lf)]) 'f1]
             ())))
   ; a left operand that needs no park: one read of an xmm home, or one pool constant -> its form | ()
   (fleft g fs)
    (? !(fsel? g) () (abl? g 'fleft) ()
       (two? fs && !(two? >fs) && (<fs @ f (elem <f '(movapd ldsdl) && <>f = 'f0 && nom? <>>f))) <fs
       ())
   (fshut g af bf)
    (? (ilp32? g) (af + '((movqrx r0 f0)) + spush2 + bf + spop2 'r2 'r3 + '((movqxr f1 r2)))
       (fsel? g && !(fclob? bf 'f1)) (af + '((movapd f1 f0)) + bf)
       (: p (fsel? g ? (fpick bf (fparks g)) ())
          (nom? p ? (af + [['movapd p 'f0]] + bf + [['movapd 'f1 p]])
             (: s (r1safe? g bf ? 'r1 (vspare g (spare g bf)))
                (s ? (af + [['movqrx s 'f0]] + bf + [['movqxr 'f1 s]])
                   (af + '((movqrx r0 f0)) + spush 'r0 + bf + spop 'r1 + '((movqxr f1 r1))))))))
   ; the ops sp64's soften turns into calls (sf-bin's and the converts), which may clobber s0..s15
   (sfcall? op) (elem op '(addsd subsd mulsd divsd cvtsi2sd cvtui2sd cvttsd2si cvttsd2ui cvtss2sd cvtsd2ss ucomisd))
   ; the single lane's park: one word, so a 32-bit target keeps it in a register -- the right
   ; side's own f1 is free (sp64's softened double ops call out and count as clobbers), else a
   ; spare gp seat, else one pushed word
   (fshuts g af bf)
    (? (fsel? g) (fshut g af bf)
       !(fclob? bf 'f1 || sp64? g && any (f \ two? f && sfcall? <f) bf) (af + '((movss f1 f0)) + bf)
       (: s (spare g bf)
          (s ? (af + [['movdrx s 'f0]] + bf + [['movdxr 'f1 s]])
             (af + '((movdrx r0 f0)) + spush 'r0 + bf + spop 'r1 + '((movdxr f1 r1))))))
   ; the count park: the value already in r0 holds in a pool register past the count's
   ; forms bf, then value r0 / count r1 (the variable shifts' and rotates' contract)
   (cshut g bf)
    (vspare g (spare g bf) @ s
       (s ? ([['mov s 'r0]] + bf + ['(mov r1 r0) ['mov 'r0 s]])
          (spush 'r0 + bf + '((mov r1 r0)) + spop 'r0)))

   ; the pair kit (ilp32 llong/ullong): a 64-bit value rides r0 (lo) : r1 (hi). pairs never enter
   ; the pool or the immediate lanes: every pair op runs the shuttle, r2:r3 the popped left, r12 the scratch
   (pair? g ty) (ilp32? g && llt? ty)
   (pwid ty lo hi) (usg? ty ? [['li hi 0]] [['mov hi lo] ['sar hi 31]])   ; widen lo into lo:hi by its source signedness
   (pwide ty) (pwid ty 'r0 'r1)                                              ; ..the protocol pair
   (asll g v) (llt? (vty v) || d128? (vty v) ? (tor0 g v) (tor0 g v + pwide (vty v)))   ; land a pair on the protocol (a wide one's low pair)
   (spop2 ra rb) [['ld ra 'sp 0] ['ld rb 'sp 4] '(add sp sp 16)]
   ; pair load/store at base+off: a base of r0 loads hi first, so the low load may overwrite
   ; it; pst's base must never be r0/r1
   (pstw base off lo hi) [['st base off lo] ['st base (off + 4) hi]]
   (pld base off) (base @ 'r0 [['ld 'r1 base (off + 4)] ['ld 'r0 base off]]
                              [['ld 'r0 base off] ['ld 'r1 base (off + 4)]])
   (pst base off) [['st base off 'r0] ['st base (off + 4) 'r1]]
   ; the pair ++/-- tail: old rides r0:r1, the sign-widened step lands in r2:r3,
   ; the stepped pair stores back through base+off (base never r0..r3)
   (ppost base off sv)
    [['li 'r2 (sv & 4294967295)]
      ['li 'r3 (sv < 0 ? 4294967295 0)]
      '(adds r2 r0 r2) '(adc r3 r1 r3)
      ['st base off 'r2] ['st base (off + 4) 'r3]]
   ; flags := (la:lb) - (ra:rb) for lt/ge (gt/le swap operands first); eq/ne ors the two word
   ; differences. v6-M and i386 land them in la:lb: every caller's left pair must be dead past the compare
   (pcmpf g op la lb ra rb)
    (v6m? g || ia32? g ?
     ([['subs la la ra] ['sbcs lb lb rb]] + (op @ ('eq || 'ne) [['ors la la lb]]))
     (['subs 'r12 la ra] . (op @ ('eq || 'ne) [['sbc la lb rb] ['ors 'r12 'r12 la]]
                                               [['sbcs 'r12 lb rb]])))
   ; a pair relation as (cc forms), operands lhs r2:r3 / rhs r0:r1 (the shuttle shape):
   ; gt/le compute the swapped difference and flip to lt/ge; signedness picks lt/below via scc.
   (prel g op unsg)
    (? (elem op '(eq ne)) [op (pcmpf g op 'r2 'r3 'r0 'r1)]
       (elem op '(lt ge)) [(scc op unsg) (pcmpf g op 'r2 'r3 'r0 'r1)]
       [(scc (op = 'gt ? 'lt 'ge) unsg) (pcmpf g op 'r0 'r1 'r2 'r3)])
   ; the pair branch: cbranch's twin of prel -- cc 'ne branches when (la:lb OP ra:rb) holds,
   ; cc 'eq when it does not (the negated relation keeps the same operand order: !lt = ge).
   (pbrf g op unsg la lb ra rb cc lbl)
    (: o2 (cc @ 'ne op (negrel op))
       (? (elem o2 '(eq ne)) (pcmpf g o2 la lb ra rb + [['br o2 lbl]])
          (elem o2 '(lt ge)) (pcmpf g o2 la lb ra rb + [['br (scc o2 unsg) lbl]])
          (pcmpf g o2 ra rb la lb + [['br (scc (o2 @ 'gt 'lt 'ge) unsg) lbl]])))
   ; a pair shift by a constant count (kind 'shl/'shr/'sar), value on the protocol; in-place.
   (pshiftc kind c)
    (? (c < 1) ()
       (63 < c) '((li r0 0) (li r1 0))
       (kind = 'shl)
        (? (c = 32) '((mov r1 r0) (li r0 0))
           (32 < c) ['(mov r1 r0) ['shl 'r1 (c - 32)] '(li r0 0)]
           ['(mov r2 r0) ['shr 'r2 (32 - c)] ['shl 'r1 c] '(or r1 r1 r2) ['shl 'r0 c]])
       (kind = 'shr)
        (? (c = 32) '((mov r0 r1) (li r1 0))
           (32 < c) ['(mov r0 r1) ['shr 'r0 (c - 32)] '(li r1 0)]
           ['(mov r2 r1) ['shl 'r2 (32 - c)] ['shr 'r0 c] '(or r0 r0 r2) ['shr 'r1 c]])
       ; sar: the high word keeps its sign; a >=32 count floods it
       (? (c = 32) '((mov r0 r1) (sar r1 31))
          (32 < c) ['(mov r0 r1) ['sar 'r0 (c - 32)] '(sar r1 31)]
          ['(mov r2 r1) ['shl 'r2 (32 - c)] ['shr 'r0 c] '(or r0 r0 r2) ['sar 'r1 c]]))
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
   (wreg? g) (x64? g || a64? g)             ; ..each half one register: the homes, the parks, the r-twins
   (t32w? g) (t32? g && !(v6m? g))          ; the four-word face: lo r0:r1, hi r2:r3, r12 a shift's count
   ; the kit's moves, spelled per face. a load whose base is one of the four words takes that word last
   (wpush g) (t32w? g ? '((sub sp sp 16) (st sp 0 r0) (st sp 4 r1) (st sp 8 r2) (st sp 12 r3)) wpush64)
   (wld g b o) (? (t32w? g)
                  (: ws '((r0 0) (r1 4) (r2 8) (r3 12))
                     (catmap (w \ [['ld <w b (o + <>w)]]) (filter (w \ <w != b) ws + filter (w \ <w = b) ws)))
                  [['ld 'r0 b o] ['ld 'r2 b (o + 8)]])
   (wst g b o) (t32w? g ? (catmap (k \ [['st b (o + 4 * k) ('(r0 r1 r2 r3) k)]]) ^4) [['st b o 'r0] ['st b (o + 8) 'r2]])
   (wnum g v) (? (t32w? g)
                 (: u (v < 0 ? (v + 340282366920938463463374607431768211456) v)
                    (catmap (k \ [['li ('(r0 r1 r2 r3) k) (u >> (32 * k) & 4294967295)]]) ^4))
                 [['li 'r0 v] ['li 'r2 (v < 0 ? -1 0)]])
   ; the wide value's words folded into r0 (its truth)
   (wor g) (t32w? g ? '((or r0 r0 r1) (or r0 r0 r2) (or r0 r0 r3)) '((or r0 r0 r2)))
   ; a cell whose low word (a pair's two on t32) holds a narrower left: its high words by that
   ; one's signedness. r12 on the four-word face, whose r1 may carry the right
   (wfix g ty) (: u (usg? ty || ptr? ty)
                  (? (wreg? g) (u ? '((si sp 8 0)) '((ld r1 sp 0) (sar r1 63) (st sp 8 r1)))
                     (: p (llt? ty)
                        ((u ? '((li r12 0)) [['ld 'r12 'sp (p ? 4 0)] '(sar r12 31)])
                         + catmap (o \ [['st 'sp o 'r12]]) (p ? '(8 12) '(4 8 12))))))
   ; a cell op: the holo form, or on the four-word face the runtime's call, its answer read back off the cell
   (wop g op) (? (t32w? g && elem op '(m128 mw128 dv128 rm128))
                 ([['call (op @ ('m128 || 'mw128) '__moon_m128 'dv128 '__moon_dv128 '__moon_rm128)]] + wld g 'sp 0)
                 [[op 'sp]])
   (rot4? g) (x64t? g || a64? g)             ; carries the rotate ops (ror4/rorv/rorv4); elsewhere the shifts stand
   (wbin ta tb) (? (d128? ta && d128? tb) (ta = 'u128 || tb = 'u128 ? 'u128 'i128)
                   (d128? ta) ta tb)                ; a word side converts to the wide side's type
   ; land a value on the wide protocol: a pair rides; a word widens by its source signedness
   (as128 g v) (: u (usg? (vty v) || ptr? (vty v))
                  (? (d128? (vty v)) (tor0 g v)
                     (t32w? g)                ; the four-word face: a word widens to the pair first
                      (tor0 g v + (? (llt? (vty v)) () u '((li r1 0)) '((mov r1 r0) (sar r1 31)))
                       + (u ? '((li r2 0) (li r3 0)) '((sx128))))
                     (tor0 g v + (u ? '((li r2 0)) '((sx128))))))
   ; did this value's forms end in the zero-extend? (the widening-mul license: hi is 0)
   (zext128? fs) (rev fs @ rl (two? rl && (<rl = '(li r2 0) || <rl = '(li r3 0))))
   ; a fresh n-byte frame cell -> its (negative) offset; every cell registers in g 'slots
   ; ((off n)..), the object map deadst and repack read (an lea escapes the whole object)
   (nslot g n) (: off -(peep g 'off 0 + n)
                  (pin g 'off (peep g 'off 0 + n),
                   pin g 'slots ([off n] . g 'slots),
                   off))
   ; ..one aligned for a type that asks more than the word: the frame base holds 16 (8 under
   ; AAPCS32 and -mstack-alignment=8), so a cell's offset rounds to the ask up to that; past it
   ; no fixed offset can
   (fbal g) (t32? g || x86k? g 'sa8 ? 8 16)
   (naslot g n a)
    (: fb (fbal g) a2 (min a fb)
       (a2 <= 8 ? (nslot g n)
          (: e (aup (peep g 'off 0 + n) a2) off (0 - e)
             (pin g 'off e,
              pin g 'slots ([off n] . g 'slots),
              off))))
   ; the object under a frame offset, off the slot map -- () when no cell claims it
   (obj9 sl x) (!(charm? x) ? ()
                  (: (go l) (two? l ?
                             (<l @ o (<o <= x && x < <o + <>o ? o (go >l))))
                     (go sl)))
   (ntmp g ty) (naslot g (aup (tsz g ty) 8) (tal g ty))
   ; the store-immediate op for (ty, k) | (), the vi fold's license (x64 only). st sign-extends
   ; imm32, the narrow forms truncate
   (fitsw? v) (-2147483648 <= v <= 4294967295)      ; sits in a 32-bit word under either signedness
   (sik sop k) (sop @ 'st  (fits32 k ? 'si)         ; the si twin of a gp store sop for k | ()
                     'st4 (fitsw? k ? 'si4)
                     'st2 (-32768 <= k <= 65535 ? 'si2)
                     'st1 (-128 <= k <= 255 ? 'si1))
   (siop9 ty k) (sik (stop ty) k)
   ; the value at an lvalue rec, by type (arrays and functions decay, a struct is its address);
   ; the scalar tail honors the want hint
   (loadval g r W9)                                 ; the mem face is consumed: one fused form, its base register freed here
    (: ty (vty r) fs (vfs r)
       b (vm? r ? (vmb r) 'r0) o (vm? r ? (vmo r) 0)
       (rfree g b,
        ; a misaligned face's array or struct keeps its alignment on the type: ('ptr t a), ('struct tag a)
        (? (arr? ty) (mkv (ua? r ? ['ptr <>ty (vma r)] ['ptr <>ty]) 'r0 (fs + mata b o))
           (gvarr? ty) (mkv ['ptr (varel ty)] 'r0 (fs + mata b o))   ; a VLA row decays to its address (p[i] a char*)
           (fn? ty) (mkv ['ptr ty] 'r0 (fs + mata b o))
           (stru? ty) (mkv (ua? r ? [<ty <>ty (vma r)] ty) 'r0 (fs + mata b o))    ; a struct value is its address (the pair reps read through it)
           (ua? r)                                    ; a misaligned member: by its chunks
            (? (flo? ty) (ntmp g 'double @ tm
                            (mkv (fvt g ty) 'r0 (fs + ldal 'r0 b o (tsz g ty) (vma r) + [['st 'r4 tm 'r0]] + fldv g ty 'f0 'r4 tm)))
               (pair? g ty) (uanl g)
               (d128? ty)                             ; the high half gathers in r1 first, off a base that is not r1
                (: b2 (b = 'r1 ? 'r0 b) a (vma r)
                   (mkv ty 'r0 (fs + (b = 'r1 ? ['(mov r0 r1)] ()) + ldal 'r1 b2 (o + 8) 8 a + ldal 'r0 b2 o 8 a + ['(mov r2 r1)])))
               (W9 || 'r0 @ W (mkv ty W (fs + ldal W b o (tsz g ty) (vma r) + cvt ty W))))
           (flo? ty) (mkv (fvt g ty) 'r0 (fs + fldv g ty 'f0 b o))
           (pair? g ty) (mkv ty 'r0 (fs + pld b o))
           (d128? ty) (mkv ty 'r0 (fs + [['ld 'r2 b (o + 8)] ['ld 'r0 b o]]))   ; hi first: the low load may overwrite the base
           (W9 || 'r0 @ W
              (mkv ty W (fs + [[(ldop ty) W b o]]))))))
   ; the value at an lvalue rec: a bitfield loads its unit and extracts with two shifts (sar
   ; signed, shr unsigned), anything else loads flat
   (lvload g r wnt)
    (vty r @ ty
       (? (bitf? ty && bfwide? g ty) (bfnl g)
          (bitf? ty)
           (: uty <>ty bitoff <>>ty width <>>>ty
              hi (64 - (bitoff + width)) lo (64 - width)
              sgn !(usg? uty || uty = 'bool)         ; a bool field holds 0/1: never sign-extend
              b (vm? r ? (vmb r) 'r0) o (vm? r ? (vmo r) 0)
              (rfree g b,
               mkv 'long 'r0
                   (vfs r
                    + bfld g ty 'r0 b o (ua? r ? (vma r) ())
                    + (hi > 0 ? [['shl 'r0 hi]])
                    + (lo > 0 ? [[(sgn ? 'sar 'shr) 'r0 lo]]))))
          (loadval g r wnt)))
   ; the fill code for a compound literal at frame offset off: an aggregate zeroes
   ; then fills (cgfill), a scalar unwraps its single-element brace and stores.
   (clitcode g env off ty ini)
    (arr? ty || stru? ty ?
        (cgfill g env off ty ini @ f
           (bad? f ? 'bad (cgzero g off (aup (tsz g ty) 8) + f)))
       (: v (two? ini && <ini = 'init ?
               (two? <>ini ? <<>ini '(num 0)) ini)
          (cgstore g env off ty v)))

   ; lvalues: a mem-faced rec (pointee-ty (m base off) forms) | a plain rec with the address on r0
   ; (globals, clits) | 'bad. matv bridges for lanes wanting the address on r0
   (clval g env e)
    (e @
       ('var nm)
        (vent g env nm @ en
           (? (bad? en) 'bad
              (elem <en '(regv regw)) 'bad   ; a register home has no address (& is gated out per-fn)
              (<en = 'loc) (mkm <>>en 'r4 <>en ())
              (mkv <>>en 'r0 [['la 'r0 <>en]])))
       ('deref X)
        ; frame-direct: a constant-indexed element is a static (r4, off) face
        (: fdc (afd2 g env e 1)
           ; *p++ on a register-homed pointer: the home steps first and the face reads one step
           ; back, so the old value needs no copy (p's step and any other read of p are unsequenced)
           pp9 (X @ ('post ('var nm) k)
                     (vent g env nm @ en
                        (two? en && <en = 'regv && ptr? <>>en && !(gvarr? <>(<>>en)) &&
                         !(abl? g 'pinc) ?
                           (k * tsz g <>(<>>en) @ d (fits32 d ? [<>en <>(<>>en) d]))))
                     ())
           (? (two? fdc) (mkm <>fdc 'r4 <fdc ())
              (two? pp9) (mkm <>pp9 <pp9 (0 - pp9 2) [['add <pp9 <pp9 (pp9 2)]])
              ; ptr ± const folds the scaled constant into the face's offset (p[1] is one load).
              ; static only: a var whose vent type is a plain pointer (a VLA pointee scales at runtime)
              (: pv (X @ ('bin op a b && elem op '(+ -))
                          (: ka (knum g a) kb (knum g b)
                             (? (two? kb && !(two? ka)) [a (op @ '+ <kb (0 - <kb))]
                                (two? ka && !(two? kb) && op = '+) [b <ka])))
                 pty (<pv @ ('var nm)
                            (vent g env nm @ en
                               (two? en && elem <en '(loc regv glo) && ptr? <>>en &&
                                !(gvarr? <>(<>>en)) ?
                                  <>>en)))
                 off9 (pty ? (<>pv * tsz g <>pty @ d
                               (fits32 d ? d 'no)) 'no)
                 (charm? off9 ?
                    (cgexpr g env <pv () @ r
                       (bad? r ? 'bad
                          (mkm <>pty (vreg r) off9 (vfs r))))
                    (cgexpr g env X () @ r
                       (? (bad? r) 'bad
                          !(ptr? (vty r)) 'bad
                          ; the face keeps the pointer's own register (a home, a pin, a park --
                          ; the consumer reads through it and frees it); no bridge to r0
                          (pal g (vty r)) (mkma <>(vty r) (vreg r) 0 (vfs r) (pal g (vty r)))
                          (mkm <>(vty r) (vreg r) 0 (vfs r))))))))
       ('dot base fld)
        (: r (clval g env base @ lv
                ; an rvalue struct base (a call's parked temp: `mk(x).a`) is its address too
                (!(bad? lv) ? lv
                   (cgexpr g env base () @ rv
                      (? (bad? rv) 'bad !(stru? (vty rv)) 'bad rv))))
           (bad? r ? 'bad
              (fmem g (vty r) fld @ fm
                 (? (bad? fm) ((vm? r ? (rfree g (vmb r))), 'bad)
                    (vm? r) (sface g r fm (mkm <>fm (vmb r) (vmo r + <fm) (vfs r)))   ; the member folds into the face
                    (sface g r fm (mkm <>fm 'r0 <fm (vfs r)))))))
       ('clit ty ini)                            ; a compound literal is an lvalue: fill a temp, address it
        (: off (ntmp g ty)
           fill (clitcode g env off ty ini)
           (bad? fill ? 'bad
              (mkv ty 'r0 (fill + [['lea 'r0 'r4 off]]))))   ; a real lea: the temp's address is the value
       ; gen's own lvalue, minted by the rmw lane and reachable from no source: the object whose
       ; address is moored at frame offset off (reading it is calm, so it evaluates once)
       ('moor off ty) (mkm ty 'r0 0 [['ld 'r0 'r4 off]])
       ('moor off ty a) (mkma ty 'r0 0 [['ld 'r0 'r4 off]] a)
       'bad)

   ; the static face of a store target -> (off ty) | (): afd, or a dot chain over a frame local whose
   ; clval face is (r4, off) with no emission. only a var/dot chain over a loc enters clval: any other base could emit
   (sfd g env e) (sfd2 g env e ())
   (sfd2 g env e fl)                                ; ..fl: a double element too (a plain store's)
    (? (<e = 'deref) (afd2 g env e fl)
       (<e != 'dot) ()
       (: (dotv? x) (x @ ('var nm) nm  ('dot . b . _) (dotv? b)  ())
          nm (dotv? e)
          (!nm ? ()
             (vent g env nm @ en
                (!(two? en && <en = 'loc) ? ()
                   (clval g env e @ lv
                      (? !(vm? lv) ()
                         (ua? lv) ()
                         !(vmb lv = 'r4) ()
                         (two? (vfs lv)) ()
                         (vty lv @ ty
                            ((ptr? ty || elem ty '(char schar cchar uchar bool short ushort int uint long ulong)) &&
                             !(pair? g ty) ?
                               [(vmo lv) ty])))))))))

   ; -- the gcc builtins --
   ; popcount of r0 by the swar fold (masks and adds only, so every target), clobbering r1 r2.
   ; the 32-bit form masks first: the word above bit 31 is not ours to count
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
       (m16? g) (nolane g "no lane for an atomic read-modify-write\(ontgt g)")
       (ia32? g)                                                            ; x64's loop at 32 bits: no REX
        (: ld (w @ 1 '(15 182 1) 2 '(15 183 1) '(139 1))
           body ('(137 195)
                 + (op @ 'add '(1 211) 'sub '(41 211) 'and '(33 211) 'or '(9 211)
                         'xor '(49 211) 'nand '(33 211 247 211) 'set '(137 211))
                 + [240] + (w @ 2 [102] ()) + [15 (w = 1 ? 176 177) 25])
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
   ; a compare-and-swap: expected r0 (widened as the loop's load widens), pointer r1, desired r2 ->
   ; the old value r0, success (0/1) r2
   (acas g w)
    (? (wasm? g)
        (nlab g ".cas" @ f
           [[(uldop w) 'r3 'r1 0] '(cmp r3 r0) ['br 'ne f] [(stw w) 'r1 0 'r2] ['label f]
            '(cmp r3 r0) '(set eq r2) '(mov r0 r3)])
       (m16? g) (nolane g "no lane for a compare-and-swap\(ontgt g)")
       (x86? g)                                         ; no REX below eight bytes: i386 lays the same
        ['(li r3 0) ['raw ([240] + (w @ 2 [102] 8 [72] ()) + [15 (w = 1 ? 176 177) 17]   ; lock cmpxchg [rcx], rdx
                           + '(15 148 195 15 182 219))]                                  ; sete bl; movzx ebx, bl
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
   ; a memory order: a constant 0 is relaxed; any other answer, one known only at run time, or
   ; none, is laid as seq_cst, which every order permits -> (order forms) | 'bad
   (amo g env a) (? !(two? a) [5 ()] (<a = 'num) [<>a ()]
                    (cgexpr g env a () @ e (bad? e ? 'bad [5 (vfs e)])))
   (cgatomic g env k bi args)
    (: kind <k
       ; __sync's forms carry no order, and are full barriers
       mo1 (amo g env (? (bi @ ("__sync_" + _) 1 ()) () (elem kind '(lockfree generic)) () (args (#args - 1))))
       (? (bad? mo1) 'bad
          (kind = 'generic) (nolane g "\(bi) is not carried out (its _n form is)")
          (kind = 'fence) (mkv 'long 'r0 (<>mo1 + (<mo1 = 0 ? () (afence g))))
          (kind = 'sfence) (mkv 'long 'r0 (<>mo1 + abar g))
          (kind = 'lockfree)
           ; the size is a constant (a sizeof folds to one, under its size_t cast)
           (: (num l) (? (two? l && <l = 'num) <>l (two? l && <l = 'cast) (num (l 2)) ())
              n (num <args)
              (charm? n ? (mkv 'int 'r0 [['li 'r0 (elem n (awidths g) ? 1 0)]])
                 (nolane g "\(bi) wants a constant size")))
          (cgexpr g env <args () @ e1
             (: pt (two? (vty e1) && <(vty e1) = 'ptr ? <>(vty e1))
                w (pt ? (amw g pt))
                rmw? (elem kind '(rmw cas vcas bcas tas))
                (? (bad? e1) 'bad
                   !w (nolane g "no lane for \(bi) on this type")
                   (ilp32? g && w = 8) (nolane g "no lane for an 8-byte \(bi)\(ontgt g)")
                   (rmw? && !(elem (kind = 'tas ? 1 w) (awidths g)))
                    (nolane g "no lane for \(bi) on a \(kind = 'tas ? 1 w)-byte object\(ontgt g)")
                   (kind = 'load)
                    (mkv pt 'r0 (<>mo1 + tor0 g e1 + (<mo1 = 5 && !(x86? g) ? (afence g))
                                 + [[(ldop pt) 'r0 'r0 0]] + (<mo1 = 0 || x86? g ? () (afence g))))
                   (kind = 'clear)
                    (mkv 'long 'r0 (<>mo1 + tor0 g e1 + '((mov r1 r0) (li r0 0)) + (<mo1 = 0 ? () (afence g))
                                    + '((st1 r1 0 r0)) + (<mo1 = 5 ? (afence g))))
                   (kind = 'tas)
                    (mkv 'int 'r0 (<>mo1 + tor0 g e1 + '((mov r1 r0) (li r2 1)) + armw g 1 'set
                                   + '((zx1 r0) (cmp r0 0) (set ne r0))))
                   (kind = 'cas)
                    ; the expected value is read through its pointer, and written back there on failure
                    (cgexpr g env (args 1) () @ ep
                       (cgexpr g env (args 2) () @ dv
                          (? (bad? ep || bad? dv) 'bad
                             (nlab g ".casok" @ ok
                                (mkv 'int 'r0 (<>mo1 + tor0 g ep + spush 'r0 + tor0 g e1 + spush 'r0 + asint g dv
                                               + '((mov r2 r0)) + spop 'r1 + [['ld 'r0 'sp 0] [(uldop w) 'r0 'r0 0]]
                                               + aexp g w + acas g w + spop 'r1
                                               + ['(cmp r2 0) ['br 'ne ok] [(stw w) 'r1 0 'r0] ['label ok] '(mov r0 r2)]))))))
                   (cgexpr g env (args 1) () @ e2
                      (? (bad? e2) 'bad
                         (kind = 'store)
                          (mkv 'long 'r0 (<>mo1 + tor0 g e1 + spush 'r0 + asint g e2 + spop 'r1
                                          + (<mo1 = 0 || x86? g ? () (afence g))
                                          + [[(stop pt) 'r1 0 'r0]] + (<mo1 = 5 ? (afence g))))
                         (kind = 'rmw)
                          (mkv pt 'r0 (<>mo1 + tor0 g e1 + spush 'r0 + asint g e2 + spop 'r1 + '((mov r2 r0))
                                       + armw g w (k 1) + (k 2 = 'new ? '((mov r0 r3))) + cvt pt 'r0))
                         ; __sync's compare-and-swap: (p old new), the old value or the success
                         (cgexpr g env (args 2) () @ e3
                            (bad? e3 ? 'bad
                               (: pre (tor0 g e1 + spush 'r0 + asint g e2 + spush 'r0 + asint g e3
                                       + '((mov r2 r0)) + spop 'r0 + aexp g w + spop 'r1 + acas g w)
                                  (kind = 'vcas ? (mkv pt 'r0 (pre + cvt pt 'r0))
                                     (mkv 'int 'r0 (pre + '((mov r0 r2)))))))))))))))
   (cgbuiltin g env bi args)                       ; a builtin call -> its value | 'bad; not one -> 'no
    (?- 'no                                        ; "not a builtin" first: its clauses run long
       (elem bi '("__builtin_trap" "__builtin_unreachable"))
        ; unreachable rides the trap
        (arm? g ? (mkv 'long 'r0 '((trap)))
           (mkv 'long 'r0 '((ud2))))     ; the named op: a raw bars unframe
       (bi = "__builtin_inf")
        (ilp32? g ? (mkv 'double 'r0 '((li r0 0) (li r1 2146435072) (movqxr f0 r0)))
           (mkv 'double 'r0 '((li r0 9218868437227405312) (movqxr f0 r0))))
       (bi = "__builtin_nanf" || bi = "__builtin_nan")   ; the tag is ignored: one quiet NaN
        (ilp32? g ? (mkv 'double 'r0 '((li r0 0) (li r1 2146959360) (movqxr f0 r0)))
           (mkv 'double 'r0 '((li r0 9221120237041090560) (movqxr f0 r0))))
       (bi = "__builtin_expect") (cgexpr g env <args ())
       ; the base holds the caller's, the return address a slot above, so both want fpin.
       ; a level above 0 walks the chain: sound where callers keep frames
       (elem bi '("__builtin_return_address" "__builtin_frame_address"))
        (: lvl (two? args && two? <args && <<args = 'num ? <><args 'no)
           fb (fbase g)
           ; the saved lr above the base: a64's frame record, riscv's padded push, x64's 8
           w (? (ilp32? g) 4 (a64? g) 8 (rv64? g) 16 8)
           up (map (_ \ ['ld 'r0 'r0 0]) ^(charm? lvl ? lvl 0))
           (? (!(charm? lvl) || lvl < 0) (nolane g "\(bi) of a level that is no constant\(ontgt g)")
              (wasm? g && (lvl != 0 || bi = "__builtin_return_address"))
               (nolane g "\(bi)\(lvl != 0 ? " above level 0" " -- no return address") in linear memory\(ontgt g)")
              (rv64? g && lvl != 0) (nolane g "\(bi) above level 0 (the saved s0 is not the caller's base)\(ontgt g)")
              (pin g 'fesc 1,
               pin g 'fpin 1,
               (? (bi = "__builtin_frame_address") (mkv '(ptr void) 'r0 (['lean 'r0 fb 0] . up))
                  (lvl = 0) (mkv '(ptr void) 'r0 [['ld 'r0 fb w]])
                  (mkv '(ptr void) 'r0 (['lean 'r0 fb 0] . up + [['ld 'r0 'r0 w]]))))))
       ; a hint: only the address evaluates, for its effects
       (bi = "__builtin_prefetch") (cgexpr g env <args ())
       (bi = "__builtin___clear_cache")
        ; x86 keeps I-cache coherent. a64: dc cvau, ic ivau per line, strides off ctr_el0.
        ; scratch r2/r3/r9/r15 only: r10-r14 are the homes
        (!(a64? g) ? (mkv 'long 'r0 ())
           (: e1 (cgexpr g env <args ())
              e2 (cgexpr g env <>args ())
              lb (nlab g ".ccd") db (nlab g ".ccdd")
              li9 (nlab g ".cci") di (nlab g ".ccid")
              (bad? e1 || bad? e2 ? 'bad
                 (mkv 'long 'r0 $
                   asint g e1 + spush 'r0 + asint g e2 + '((mov r1 r0)) + spop 'r0 +
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
                       '(raw (223 63 3 213))]))))     ; isb
       (elem bi '("__builtin_clzll" "__builtin_clzl" "__builtin_clz"))
        (: e1 (cgexpr g env <args ())
           ; the `l` spelling is the target's long
           ll (? (bi = "__builtin_clz") () (bi = "__builtin_clzll") 1 !(ilp32? g))
           pre (ll ? () '((shl r0 32)))    ; clz32(x) = clz64(x << 32), clearing upper garbage
           (? (bad? e1) 'bad
              ; i386: bsr and xor 31 a word at a time
              (ia32? g)
               (: cz (m16b g + '(15 189 192) + m16b g + '(131 240 31))         ; bsr eax,eax; xor eax,31
                  lz (nlab g ".cz") ld (nlab g ".czd")
                  (mkv 'long 'r0 (!ll ? (asint g e1 + [['raw cz]])
                                    (asll g e1 + ['(cmp r1 0) ['br 'eq lz] '(mov r0 r1) ['raw cz] ['jmp ld]
                                                 ['label lz] ['raw cz] '(add r0 r0 32) ['label ld]]))))
              (t32? g && !ll)              ; one word: clz or __clzsi2
               (mkv 'long 'r0 (asint g e1 +
                  (v6m? g ? '((call __clzsi2)) '((clz r0 r0)))))
              (t32? g)                     ; the pair: clz(hi), or 32 + clz(lo) when hi is 0
               (: lz (nlab g ".cz") ld (nlab g ".czd")
                  (mkv 'long 'r0 (asll g e1 +
                    (v6m? g ?   ; no clz on v6-M
                       ['(cmp r1 0) ['br 'eq lz] '(mov r0 r1) '(call __clzsi2) ['jmp ld]
                          ['label lz] '(call __clzsi2) '(add r0 r0 32) ['label ld]]
                       ['(cmp r1 0) ['br 'eq lz] '(clz r0 r1) ['jmp ld]
                          ['label lz] '(clz r0 r0) '(add r0 r0 32) ['label ld]]))))
              (rv64? g)                      ; no clz in rv64i: a binary search
               (: ls (map (k \ (nlab g ".cz")) '(0 1 2 3 4 5))
                  step (kk \ lb2 \ ['(mov r2 r0) ['shr 'r2 (64 - kk)] '(cmp r2 0) ['br 'ne lb2]
                                     ['add 'r1 'r1 kk] ['shl 'r0 kk] ['label lb2]])
                  (mkv 'long 'r0 (asint g e1 + pre +
                    ('((li r1 0))
                     + step 32 (ls 0) + step 16 (ls 1) + step 8 (ls 2)
                     + step 4 (ls 3) + step 2 (ls 4) + step 1 (ls 5)
                     + '((mov r0 r1))))))
              (mkv 'long 'r0 (asint g e1 + pre +
                              (a64? g ? '((raw (0 16 192 218)))                    ; clz x0, x0
                                 '((raw (72 15 189 192 72 131 240 63))))))))   ; bsr rax,rax; xor rax,63
       ; ctz(0) stays UB; the 32-bit spelling's upper garbage is harmless
       (elem bi '("__builtin_ctzll" "__builtin_ctzl" "__builtin_ctz"))
        (: e1 (cgexpr g env <args ())
           ll (? (bi = "__builtin_ctz") () (bi = "__builtin_ctzll") 1 !(ilp32? g))
           (? (bad? e1) 'bad
              (ia32? g)                     ; bsf: lo, or hi + 32 when lo is 0
               (: tz (m16b g + '(15 188 192))
                  lz (nlab g ".tz") ld (nlab g ".tzd")
                  (mkv 'long 'r0 (!ll ? (asint g e1 + [['raw tz]])
                                    (asll g e1 + ['(cmp r0 0) ['br 'eq lz] ['raw tz] ['jmp ld]
                                                 ['label lz] '(mov r0 r1) ['raw tz] '(add r0 r0 32) ['label ld]]))))
              (ll && t32? g) (nolane g "no lane for \(bi)\(ontgt g)")
              (t32? g)
               (mkv 'long 'r0 (asint g e1 +
                  (v6m? g ? '((call __ctzsi2))
                     '((li r1 0) (sub r1 r1 r0) (and r0 r0 r1)     ; x & -x, then 31 - clz
                        (clz r0 r0) (li r1 31) (sub r0 r1 r0)))))
              (rv64? g)
               (: ls (map (k \ (nlab g ".tz")) '(0 1 2 3 4 5))
                  step (kk \ mk \ lb2 \ [['li 'r3 mk] '(mov r2 r0) '(and r2 r2 r3) '(cmp r2 0)
                                          ['br 'ne lb2] ['add 'r1 'r1 kk] ['shr 'r0 kk] ['label lb2]])
                  (mkv 'long 'r0 (asint g e1 +
                    ('((li r1 0))
                     + step 32 4294967295 (ls 0) + step 16 65535 (ls 1)
                     + step 8 255 (ls 2) + step 4 15 (ls 3)
                     + step 2 3 (ls 4) + step 1 1 (ls 5)
                     + '((mov r0 r1))))))
              (mkv 'long 'r0 (asint g e1 +
                              (? (a64? g && ll) '((raw (0 0 192 218 0 16 192 218)))   ; rbit x0,x0; clz x0,x0
                                 (a64? g) '((raw (0 0 192 90 0 16 192 90)))   ; rbit w0,w0; clz w0,w0
                                 '((raw (72 15 188 192))))))))                ; bsf rax,rax: REX.W serves both widths
       ; bswap: masked shift/or expansions, no raw, so unframe stays alive
       (elem bi '("__builtin_bswap16" "__builtin_bswap32" "__builtin_bswap64"))
        (? (bi = "__builtin_bswap64" && ia32? g)   ; i386: the words trade places
            (cgexpr g env <args () @ e1
               (bad? e1 ? 'bad
                  (mkv 'ullong 'r0 (asll g e1 + '((mov r2 r0) (mov r0 r1) (mov r1 r2))
                                    + [['raw (m16b g + [15 200] + m16b g + [15 201])]]))))   ; bswap eax; bswap ecx
           (bi = "__builtin_bswap64" && ilp32? g)   ; the words trade places
            (cgexpr g env <args () @ e1
               (bad? e1 ? 'bad
                  (mkv 'ullong 'r0 (asll g e1 + '((sub sp sp 16) (st sp 0 r0) (mov r0 r1)) + bsw32
                                    + '((st sp 4 r0) (ld r0 sp 0)) + bsw32
                                    + '((mov r1 r0) (ld r0 sp 4) (add sp sp 16))))))
           (cgexpr g env <args () @ e1
              (bad? e1 ? 'bad
                 (mkv 'long 'r0 (asint g e1 +
                   (? (bi = "__builtin_bswap16")
                      '((li r2 255) (mov r1 r0) (shr r1 8) (and r1 r1 r2)
                        (and r0 r0 r2) (shl r0 8) (or r0 r0 r1))
                      (bi = "__builtin_bswap32") bsw32
                      '((li r2 71777214294589695)                  ; 0x00ff00ff00ff00ff
                        (mov r1 r0) (shr r1 8) (and r1 r1 r2)
                        (and r0 r0 r2) (shl r0 8) (or r0 r0 r1)
                        (li r2 281470681808895)                    ; 0x0000ffff0000ffff
                        (mov r1 r0) (shr r1 16) (and r1 r1 r2)
                        (and r0 r0 r2) (shl r0 16) (or r0 r0 r1)
                        (mov r1 r0) (shr r1 32) (shl r0 32) (or r0 r0 r1))))))))
       ; popcount: the swar fold, masks and adds only, so every target
       (elem bi '("__builtin_popcount" "__builtin_popcountl" "__builtin_popcountll"))
        (? (bi = "__builtin_popcountll" && ilp32? g)   ; each word's count, summed
            (cgexpr g env <args () @ e1
               (bad? e1 ? 'bad
                  (mkv 'long 'r0 (asll g e1 + '((sub sp sp 16) (st sp 0 r1)) + popops g 1
                                  + '((st sp 4 r0) (ld r0 sp 0)) + popops g 1
                                  + '((ld r1 sp 4) (add r0 r0 r1) (add sp sp 16))))))
           (cgexpr g env <args () @ e1
              (bad? e1 ? 'bad
                 (mkv 'long 'r0 (asint g e1 + popops g (bi = "__builtin_popcount" || ilp32? g))))))
       ; ffs: 0 for 0, else popcount(x ^ (x - 1))
       (elem bi '("__builtin_ffs" "__builtin_ffsl" "__builtin_ffsll"))
        (bi = "__builtin_ffsll" && ilp32? g ?
            (nolane g "no lane for \(bi)\(ontgt g)")
           (: e1 (cgexpr g env <args ())
              w32 (bi = "__builtin_ffs" || ilp32? g)
              lz (nlab g ".ffs")
              (bad? e1 ? 'bad
                 (mkv 'long 'r0 (asint g e1
                    + (w32 && !(ilp32? g) ? '((li r2 4294967295) (and r0 r0 r2)))
                    + ['(cmp r0 0) ['br 'eq lz] '(mov r1 r0) '(sub r1 r1 1) '(xor r0 r0 r1)]
                    + popops g w32 + [['label lz]])))))
       ; the __sync lock pair: an acquire exchange and a release store of 0, sized by the pointee
       (atomop bi) (cgatomic g env (atomop bi) bi args)
       (elem bi '("__sync_lock_test_and_set" "__sync_lock_release"))
        (: e1 (cgexpr g env <args ())
           pt (two? (vty e1) && <(vty e1) = 'ptr ? <>(vty e1))
           w (? (elem pt '(int uint)) 4
                (ptr? pt || elem pt '(long ulong)) (wsize g) ())
           (? (v6m? g) (nolane g "no lane for \(bi)\(ontgt g)")
              (bad? e1) 'bad
              !w (nolane g "\(bi) wants an int* or a long*/T** (the pointee sizes the exchange)")
              (bi = "__sync_lock_release")
               (mkv 'long 'r0 (tor0 g e1 +
                 '((mov r1 r0) (li r0 0)) +
                 (? (a64? g) [['raw (w @ 4 '(32 252 159 136) '(32 252 159 200))]]   ; stlr w0/x0, [x1]
                    (t32? g) ([['raw (tw 0xF3BF8F5F)]] + [['st4 'r1 0 'r0]])                ; dmb sy, then the store
                    (rv64? g) ('((raw (15 0 16 3))) +                                       ; fence rw,w
                             [[(w = 4 ? 'st4 'st) 'r1 0 'r0]])
                    [[(w @ 4 'st4 'st) 'r1 0 'r0]])))
              (cgexpr g env <>args () @ e2
                 (bad? e2 ? 'bad
                    (: pre (tor0 g e1 + spush 'r0 + asint g e2 + spop 'r1)   ; val r0, ptr r1
                       body (? (a64? g)
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
                       (mkv pt 'r0 (pre + body + cvt pt 'r0)))))))
       (bi = "__builtin_isinf")
        (cgexpr g env <args () @ e1
           (bad? e1 ? 'bad
              (mkv 'long 'r0 (asflo g e1 +
                        (? (v6m? g || ia32? g)      ; r12-free: the diffs land in r1
                           '((movqrx r0 f0) (li r2 2147483647) (and r1 r1 r2)
                              (li r2 2146435072) (subs r1 r1 r2)
                              (ors r1 r1 r0) (set eq r0))
                           (t32? g)                 ; |hi| == 0x7ff00000 and lo == 0, over the pair
                           '((movqrx r0 f0) (li r2 2147483647) (and r1 r1 r2)
                              (li r2 2146435072) (subs r12 r1 r2)
                              (ors r12 r12 r0) (set eq r0))
                           (a8? g)
                           '((movqrx r0 f0) (shl r0 1) (li r1 18437736874454810624)
                              (cmp r0 r1) (set eq r0))
                           ('((movqrx r0 f0) (raw (72 209 224)) (li r1 18437736874454810624)) +   ; shl rax,1; rcx = inf<<1
                              '((raw (72 57 200 15 148 192 72 15 182 192)))))))))     ; cmp; sete al; movzx rax,al
       ; the _p forms: the plain form, storing to a fresh local of the third operand's type
       (elem bi '("__builtin_add_overflow_p" "__builtin_sub_overflow_p" "__builtin_mul_overflow_p"))
        (: k (peep g 'ovn 0) _ (pin g 'ovn (k + 1))
           nm ".ovp\(k)"
           (#args != 3 ? (nolane g "\(bi) wants three operands")
              (cgexpr g env ['sexpr [['decl [[nm (peekty g env (args 2)) (args 2)]]]]
                                    ['call ['var (snip bi 0 (#bi - 2))] [<args <>args ['addr ['var nm]]]] 'int] ())))
       (elem bi '("__builtin_add_overflow" "__builtin_sub_overflow" "__builtin_mul_overflow")
             && two? (ovlow g env bi args))
        (cgexpr g env (ovlow g env bi args) ())
       (elem bi '("__builtin_add_overflow" "__builtin_sub_overflow" "__builtin_mul_overflow"))
        (: e1 (cgexpr g env <args ())
           e2 (cgexpr g env <>args ())
           ; &t is consumed by the splice's store: argpos, like a call arg (keeps sibcalls)
           e3 (elem <<>>args '(addr var) ? (pin g 'argpos 1),
               cgexpr g env <>>args ())
           _ (pin g 'argpos ())
           ; x64 widens with REX.W; i386 is the word already
           rx (x64? g ? [72] (m16b g))
           opb (rx + (? (bi = "__builtin_add_overflow") '(1 200)      ; add rax,rcx
                        (bi = "__builtin_sub_overflow") '(41 200)     ; sub rax,rcx
                        '(15 175 193)))                               ; imul rax,rcx
           ; the op leaves r0 the result, r1 the overflow bit
           ovf (? !(arm? g)
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
                        ['label lo] '(li r1 1) ['label l2]]))
           ; &t's lea must not open the sibs window: lean on arm; x64's raw splice resets it
           e3f (arm? g ? (relean (tor0 g e3)) (tor0 g e3))
           (bad? e1 || bad? e2 || bad? e3 ? 'bad
              (mkv 'long 'r0 $
               asint g e1 + spush 'r0 + asint g e2 + spush 'r0 +
               e3f + '((mov r3 r0)) + spop 'r1 + spop 'r0 + ovf +
               '((st r3 0 r0) (mov r0 r1)))))
       ; the block moves last: every __builtin_ clause gets first refusal
       (0 < #bi && bi 0 = 109) (cgmem g env bi args)
       (elem bi '("__builtin_memcpy" "__builtin_memset")) (cgmem g env bi args))

   ; a value tuple | 'bad. wnt is an advisory destination hint
   (cgexpr g env e wnt)
    (e @- 'bad                                      ; the refusal up front
       ('bcp e2) (cgexpr g env ['num (charm? (cfold !(ilp32? g) e2) ? 1 0)] wnt)
       ('szof e2)                                   ; sizeof EXPR: the undecayed type
        (peekty g env e2 @ ty
           (? (bad? ty) 'bad
              (gvarr? ty && 3 < #ty)   ; sizeof a VLA local: the stashed byte size
               (g 'vslots (varix ty) @ sl
                  (!(two? sl) ? 'bad (mkv 'ulong 'r0 [['ld 'r0 'r4 <>sl]])))
              (mkv 'ulong 'r0 [['li 'r0 (tsz g ty)]])))
       ('num v)
        (? (w128? g && !(-9223372036854775808 <= v <= 18446744073709551615))
           ; past the word: the wide pair, split by // and % (a big has no bitwise ops)
           ((v < 0 ? (v + 64 2 * 64 2) v) % (64 2 * 64 2) @ u
              (mkv 'u128 'r0
                   (t32w? g ? (wnum g u)
                      [['li 'r0 (u % 18446744073709551616)]
                       ['li 'r2 (u // 18446744073709551616)]])))
           (ilp32? g && !(fitsw? v))
           ; past the 32-bit word: the pair (C99 decimal picks long long)
           (u64 v @ u
              (mkv (v < 0 ? 'llong 'ullong) 'r0
                   [['li 'r0 (u % 4294967296)] ['li 'r1 (u // 4294967296)]]))
           (ilp32? g && 2147483647 < v)
           ; bit 31 set: unsigned, so a pair-widen zero-extends
           (wnt || 'r0 @ W (mkv 'ulong W [['li W v]]))
           (wnt || 'r0 @ W (mkv (v > 9223372036854775807 ? 'ulong 'long) W [['li W v]])))
       ('flo d) (mkflo g d)
       ; gcc's &&L, for a computed goto
       ('laddr nm)
        (wasm? g ? (asmno g "a label's address (&&) has no wasm lane")
           (mkv '(ptr void) 'r0 [['la 'r0 (name "\(g 'fn).\(nm)")]]))
       ('str s)
        (nlab g ".S" @ lbl
           (pin g 'strs ([lbl s] . g 'strs),
            mkv ['ptr (gchar g)] 'r0 [['la 'r0 lbl]]))
       (('dot || 'moor) . _)
        (clval g env e @ r
           (bad? r ? 'bad (lvload g r wnt)))
       ('var nm)
        (vent g env nm @ en
           (? (bad? en)
               (g 'fns nm ?     ; a function name is its address
                  (mkv ['ptr (fnty g nm)] 'r0 [['la 'r0 (name nm)]])
                  (pin g 'undecl nm, 'bad))   ; undeclared: named for the gripe
              (<en = 'regv)
               (fhomable? <>>en ? (mkv <>>en 'r0 [['movapd 'f0 <>en]])   ; an xmm home lands on the protocol
                  (mkv <>>en <>en ()))   ; a homed param is its register, borrowed
              (<en = 'regw)                       ; a pair-homed d128 onto the protocol
               (mkv <>>en 'r0 [['mov 'r2 <><>en] ['mov 'r0 <<>en]])
              (: ty <>>en
                 ap? (g 'argpos)
                 (stru? ty || arr? ty ? (pin g 'argpos ()),
                  (? (stru? ty)                    ; a struct value is its address (the sse2 rep)
                      (<en = 'loc ?
                         (mkv ty 'r0 [['lea 'r0 'r4 <>en]] @ v (ap? ? (escana g v) (escan g v)))
                         (mkv ty 'r0 [['la 'r0 <>en]]))
                     (arr? ty)                     ; arrays decay to their address
                      (<en = 'loc ?
                         (mkv ['ptr <>ty] 'r0 [['lea 'r0 'r4 <>en]] @ v (ap? ? (escana g v) (escan g v)))
                         (mkv ['ptr <>ty] 'r0 [['la 'r0 <>en]]))
                     (gvarr? ty)                   ; a VLA local: its slot holds the block pointer
                      (<en = 'loc ?
                         (mkv ['ptr (varel ty)] 'r0 [['ld 'r0 'r4 <>en]])
                         'bad)
                     (flo? ty)                     ; a float/double loads into f0 (widened if float)
                      (mkv (fvt g ty) 'r0 (atstat en 'r1 (fldv g ty 'f0)))
                     (pair? g ty)                    ; r2 the address: r1 is the pair's high half
                      (mkv ty 'r0 (atstat en 'r2 pld))
                     (d128? ty)
                      (!(w128? g) ? (no128 g)
                         (mkv ty 'r0 (atstat en 'r1 (b \ o \ wld g b o))))
                     (: W (<en = 'loc && wnt ? wnt 'r0)   ; a slot load lands on the hint
                        (mkv ty W (atstat en 'r1 (b \ o \ [[(ldop ty) W b o]])))))))))
       ('addr lv)
        (: r (clval g env lv)
           ap? (g 'argpos)
           (pin g 'argpos (),
            (? (!(bad? r) && bitf? (vty r)) 'bad   ; &bitfield is illegal C
               !(bad? r)                        ; the address escapes: a real lea, so the gate sees it
               (: fs (vm? r ? (vfs r + unlean (mata (vmb r) (vmo r)))
                         (unlean (vfs r)))
                  _ (vm? r ? (rfree g (vmb r)))
                  v (mkv ['ptr (vty r)] 'r0 fs)
                  (ap? ? (escana g v) (escan g v)))
               ; &f: the function's address, unless a variable shadows it
               (<lv = 'var && bad? (vent g env <>lv) && g 'fns <>lv)
                (mkv ['ptr (fnty g <>lv)] 'r0 [['la 'r0 (name <>lv)]])
               'bad)))
       ('deref . _)
        (clval g env e @ r                  ; clval already walked the pointer
           (bad? r ? 'bad (loadval g r wnt)))
       ('asn dst rhs0)
        (: rhs (rassoc g env dst rhs0)
           dq9 (g 'drop9)           ; a statement drops the answer; an asn on its right still wants its own
           _ (pin g 'drop9 ())
           rv (<dst = 'var ? (vent g env <>dst) 'bad)
           fd (sfd2 g env dst 1)
           ; h = h op y (h = y op h for + *) on an xmm home: y alone on the protocol, the op on the home
           hop (two? rv && <rv = 'regv && <>>rv = 'double && fsel? g && !(abl? g 'fhop) &&
                (rhs @ ('bin op ('var v) y) (elem op '(+ - * /) && v = <>dst ? [op y])
                       ('bin op y ('var v)) (elem op '(+ *) && v = <>dst ? [op y])
                       ()))
           (? (two? hop)
               (cgexpr g env <>hop () @ r
                  (? (bad? r) 'bad
                     (: bf (asflo g r)
                        sim (fsimple g bf)
                        opn (<hop @ '+ 'addsd '- 'subsd '* 'mulsd 'divsd)
                        (mkv 'double 'r0 ((two? sim ? (<sim + [[opn <>rv <>sim]]) (bf + [[opn <>rv 'f0]])) +
                                          (dq9 ? () [['movapd 'f0 <>rv]]))))))
              (two? rv && <rv = 'regv && fhomable? <>>rv)   ; store into an xmm home: off the protocol
               (cgexpr g env rhs () @ r
                  (bad? r ? 'bad (mkv <>>rv 'r0 (asfty g r <>>rv + [['movapd <>rv 'f0]]))))
              (two? rv && <rv = 'regv)
               (cgexpr g env rhs <>rv @ r   ; the rhs aims straight at the home
                  (? (bad? r) 'bad
                     (flo? (vty r)) (mkv <>>rv 'r0 (asintt g r <>>rv + [['mov <>rv 'r0]] + cvt <>>rv <>rv))
                     (vreg r = <>rv) (mkv <>>rv <>rv (vfs r + hcvt g <>dst <>>rv <>rv))   ; already home (re-narrowed)
                     (vfs r + [['mov <>rv (vreg r)]] + hcvt g <>dst <>>rv <>rv @ fs   ; straight from the value's register
                        (rfree g (vreg r),
                         mkv <>>rv <>rv fs))))
              (two? rv && <rv = 'regw)     ; a pair-homed d128: via the protocol
               (cgexpr g env rhs () @ r
                (bad? r ? 'bad
                 (mkv <>>rv 'r0 (as128 g r + [['mov <<>rv 'r0] ['mov <><>rv 'r2]]))))
              ; store-direct: a plain variable's address is static, so the value stores from where it sits
              (two? rv && elem <rv '(loc glo) &&
                  (<>>rv @ ty9 !(stru? ty9 || arr? ty9 || flo? ty9)))
               (: ty <>>rv
                  nm <>dst
                  r (cgexpr g env rhs ())
                  (? (bad? r) 'bad
                     (pair? g ty)                     ; r2 the address: r1 is the pair's high half
                      (mkv ty 'r0 (asll g r + atstat rv 'r2 pst))
                     (d128? ty)
                      (!(w128? g) ? (no128 g)
                       (mkv ty 'r0 (as128 g r + atstat rv (t32w? g ? 'r12 'r1) (b \ o \ wst g b o))))
                     ; a double source truncates first; a narrow target converts on the protocol
                     (flo? (vty r) || two? (cvt ty 'r0))
                      (mkv ty 'r0 (asintt g r ty + cvt ty 'r0 + atstat rv 'r1 (b \ o \ [[(stop ty) b o 'r0]])))
                     (mkv ty (vreg r) (vfs r + atstat rv 'r1 (b \ o \ [['st b o (vreg r)]])))))
              ; frame-direct: the slot is static, so no address park, even past a call
              (two? fd)
               (: off <fd ty <>fd
                  r (cgexpr g env rhs ())
                  (? (bad? r) 'bad
                     (flo? ty) (mkv 'double 'r0 (asflo g r + fstf g ty 'r4 off 'f0))
                     ; a register-riding value stores itself (no r0 bridge)
                     (!(flo? (vty r)) && atom? (cvt ty 'r0) && vreg r != 'r0 ?
                        (mkv ty (vreg r) (vfs r + [[(stop ty) 'r4 off (vreg r)]]))
                        (mkv ty 'r0 (asintt g r ty + cvt ty 'r0 +
                                     [[(stop ty) 'r4 off 'r0]])))))
              (: lv0 (clval g env dst)
                 ; face-direct: the base survives a write-free rhs, so the store reads through the face
                 fdd (vm? lv0 && vmb lv0 != 'r0 && !(wrany? rhs))
           (? (bad? lv0) 'bad
              (arr? (vty lv0)) 'bad                ; an array is not assignable
              (stru? (vty lv0))                    ; a whole-struct copy (dest r1, src r0)
               (: lv (matv g lv0)
                  rl0 (clval g env rhs)
                  al (min (val9 g lv0) (bad? rl0 ? 8 (val9 g rl0)))
                  rl (matv g rl0)   ; an rvalue struct (a call's temp) is its address too
                  rv (bad? rl ? (cgexpr g env rhs ()) rl)
                  (? (bad? rv) 'bad
                     ; a real into a complex lvalue converts: re the value, im zero
                     (gcplx? (vty lv) && !(stru? (vty rv)))
                      (cxb (vty lv) @ b
                         (mkv (vty lv) 'r0
                            (vfs lv + spush 'r0 +
                             (asflo g rv + spop 'r1 + fstf g b 'r1 0 'f0
                              + '((li r2 0))
                              + (b @ 'float '((st4 r1 4 r2)) (z8 g 'r1 8))))))
                     !(stru? (vty rv)) 'bad
                     (mkv (vty lv) 'r0 $
                        vfs lv + spush 'r0 + tor0 g rv + spop 'r1 +
                          ; a complex width flip converts componentwise; else bytes
                          (gcplx? (vty lv) && gcplx? (vty rv) &&
                           !(<>(vty lv) = <>(vty rv)) ?
                             (cxcopy g (vty rv))
                             (sal? g ? (bcopya 0 (tsz g (vty lv)) al) (bcopy g 0 (tsz g (vty lv)) ()))))))
              ; a misaligned member (-mstrict-align): the value lands on the protocol, then by chunks
              (ua? lv0 && !(bitf? (vty lv0)))
               (: ty (vty lv0) n (tsz g ty) a (vma lv0)
                  (? (pair? g ty || d128? ty && !(w128? g)) (uanl g)
                     (: lv (matv g lv0)
                        r (cgexpr g env rhs ())
                        (? (bad? r) 'bad
                           (d128? ty)
                            (mkv ty 'r0 (vfs lv + spush 'r0 + as128 g r + spop 'r1 + stal 'r1 0 8 a 'r0 + stal 'r1 8 8 a 'r2))
                           (flo? ty)
                            (ntmp g 'double @ tm
                               (mkv (fvt g ty) 'r0 (vfs lv + spush 'r0 + asfty g r ty + fstv g ty 'r4 tm 'f0
                                                 + [[(uldop n) 'r0 'r4 tm]] + spop 'r1 + stal 'r1 0 n a 'r0)))
                           (mkv ty 'r0 (vfs lv + spush 'r0 + asintt g r ty + spop 'r1 + cvt ty 'r0
                                        + stal 'r1 0 n a 'r0))))))
              (flo? (vty lv0))                     ; a float/double store (value in f0; narrow if float)
               (fdd ?
                  (: b (vmb lv0) o (vmo lv0)      ; the face is the address: fstf reads through it
                     r (cgexpr g env rhs ())
                     (bad? r ? (rfree g b, 'bad)
                        (vfs lv0 + asfty g r (vty lv0) + fstv g (vty lv0) b o 'f0 @ fs
                           (rfree g b,
                            mkv (fvt g (vty lv0)) 'r0 fs))))
                  (: lv (matv g lv0)
                     r (cgexpr g env rhs ())
                     (bad? r ? 'bad
                        (mkv (fvt g (vty lv)) 'r0 (vfs lv + spush 'r0 +
                         (asfty g r (vty lv) + spop 'r1 + fstv g (vty lv) 'r1 0 'f0))))))
              (bitf? (vty lv0) && bfwide? g (vty lv0)) (bfnl g)
              (bitf? (vty lv0))                   ; a bitfield: read-modify-write the unit at r1, the truncated value answers
               (: ua (ua? lv0 ? (vma lv0) ()) lv (matv g lv0)
                  r (cgexpr g env rhs ())
                  (bad? r ? 'bad
                     (: bt (vty lv) uty <>bt bitoff <>>bt width <>>>bt
                        mask ((1 << width) - 1) mv (mask << bitoff) cmask (0 - mv - 1)
                        sgn !(usg? uty || uty = 'bool) lo (64 - width)
                        (mkv 'long 'r0
                           (vfs lv + spush 'r0
                            + asintt g r uty
                            + (uty @ 'bool (cvt uty 'r0))   ; normalize before the mask ((bool)4 is 1)
                            + spop 'r1
                            + bfld g bt 'r2 'r1 0 ua                ; r2 = the unit
                            + [['li 'r3 mask] '(and r0 r0 r3)       ; r0 = v & mask (the truncated value)
                                ['li 'r3 cmask] '(and r2 r2 r3)      ; clear the field's bits
                                '(mov r3 r0)]
                            + (bitoff > 0 ? [['shl 'r3 bitoff]])   ; r3 = (v & mask) << bitoff
                            + ['(or r2 r2 r3)] + bfst g bt 'r1 0 ua 'r2
                            + (sgn ? [['shl 'r0 lo] ['sar 'r0 lo]]))))))
              (pair? g (vty lv0))                 ; a pair store through a computed address
               (: lv (matv g lv0)
                  r (cgexpr g env rhs ())
                  (bad? r ? 'bad
                     (mkv (vty lv) 'r0
                      (vfs lv + spush 'r0 + asll g r + spop 'r2 + pst 'r2 0))))
              (d128? (vty lv0))                   ; a wide store through a computed address (r1)
               (!(w128? g) ? (no128 g)
                  (: lv (matv g lv0)
                     r (cgexpr g env rhs ())
                     (bad? r ? 'bad
                        (mkv (vty lv) 'r0 (vfs lv + spush 'r0 +
                         as128 g r + (t32w? g ? (spop 'r12 + wst g 'r12 0) (spop 'r1 + '((st r1 0 r0) (st r1 8 r2)))))))))
              ; face-direct: the store reads through the face's own base, no address park
              fdd
               (: b (vmb lv0) o (vmo lv0)
                  ty (vty lv0)
                  r (cgexpr g env (stnar g env ty rhs) ())
                  (bad? r ? (rfree g b, 'bad)
                     (!(flo? (vty r)) && (!(two? (cvt ty 'r0)) || stcvt? ty && !(abl? g 'stnar)) &&
                      vreg r != 'r0 && !(rpeq? g (vreg r) b) ?
                        (vfs lv0 + vfs r + [[(stop ty) b o (vreg r)]] @ fs
                           (rfree g b,
                           ; the answer takes its cvt after the store, and a statement drops it
                            two? (cvt ty 'r0) && !dq9 ? (mkv ty 'r0 (tor0 g (mkv ty (vreg r) fs) + cvt ty 'r0))
                              (mkv ty (vreg r) fs)))
                        (: fs (vfs lv0 + asintt g r ty + cvt ty 'r0 +
                               [[(stop ty) b o 'r0]])
                           (rfree g b,
                            mkv ty 'r0 fs)))))
              ; the address parks in a pool register unless a call on the right would clobber it
              (: lv (matv g lv0)
                 aR (callish? rhs ? () (ralloc g))
                 r (cgexpr g env (stnar g env (vty lv) rhs) ())
                 (bad? r ? ((aR ? (rfree g aR)), 'bad)
                    (vty lv @ ty
                       (aR ?
                          ; a register-riding value stores itself (no r0 bridge)
                          (!(flo? (vty r)) && (!(two? (cvt ty 'r0)) || stcvt? ty && !(abl? g 'stnar)) &&
                           vreg r != 'r0 && !(rpeq? g (vreg r) aR) ?
                             (: fs (vfs lv +
                                    [['mov aR 'r0]] +
                                    vfs r +
                                    [[(stop ty) aR 0 (vreg r)]])
                                (rfree g aR,
                                 two? (cvt ty 'r0) && !dq9 ? (mkv ty 'r0 (tor0 g (mkv ty (vreg r) fs) + cvt ty 'r0))
                                   (mkv ty (vreg r) fs)))
                             (: fs (vfs lv +
                                    [['mov aR 'r0]] +
                                    asintt g r ty +
                                    cvt ty 'r0 +
                                    [[(stop ty) aR 0 'r0]])
                                (rfree g aR,
                                 mkv ty 'r0 fs)))
                          (mkv ty 'r0
                           (vfs lv + spush 'r0 + asintt g r ty + spop 'r1 +
                            cvt ty 'r0 + [[(stop ty) 'r1 0 'r0]]))))))))))
       ('post dst step)
        (: rv (<dst = 'var ? (vent g env <>dst) 'bad)
           fd (sfd g env dst)
           ; a frame-direct ld/add/st: the old value answers in r0, the stepped one stores (b++/b-- lands on 0/1)
           (bump ty off stp)
            (mkv ty 'r0 ([[(ldop ty) 'r0 'r4 off] ['add 'r1 'r0 (stp * step)]]
                         + (ty @ 'bool (cvt ty 'r1)) + [[(stop ty) 'r4 off 'r1]]))
           (? (two? rv && <rv = 'regv && fhomable? <>>rv)   ; x++ on an xmm home: old in f0, home += step
               (: f9 (<>>rv = 'float)
                  (mkv <>>rv 'r0 (vfs (mkflo g (0.0 + step)) + (f9 ? '((cvtsd2ss f0 f0)) ()) +
                                  [['movapd 'f1 'f0] ['movapd 'f0 <>rv] [(f9 ? 'addss 'addsd) <>rv 'f1]])))
              (two? rv && <rv = 'regv)   ; p++ on a register-homed scalar: old in r0, home += step
               (: ty <>>rv stp (ptr? ty ? (tsz g <>ty) 1)
                  (mkv ty 'r0 ([['mov 'r0 <>rv]
                                ['add <>rv <>rv (stp * step)]] + hcvt g <>dst ty <>rv)))
              ; store-direct (the asn twin): a direct frame ld+st leaves no lean, so the local can still home
              (two? rv && <rv = 'loc &&
               (<>>rv @ t9 !(stru? t9 || arr? t9 || flo? t9 || bitf? t9)))
               (: ty <>>rv off <>rv stp (ptr? ty ? (tsz g <>ty) 1)
                  (? (pair? g ty)
                     (mkv ty 'r0 (pld 'r4 off + ppost 'r4 off (stp * step)))
                     (d128? ty)                   ; wide: step, store, step back to the old
                      (!(w128? g) ? (no128 g)
                         (mkv ty 'r0 (wld g 'r4 off + [[(step < 0 ? 'dec128 'inc128)]]
                                      + wst g 'r4 off + [[(step < 0 ? 'inc128 'dec128)]])))
                     (bump ty off stp)))
              ; frame-direct element ++/--
              (two? fd)
               (: ty <>fd off <fd (bump ty off (ptr? ty ? (tsz g <>ty) 1)))
              (clval g env dst @ lv0
           (bad? lv0 ? 'bad
              (: ty (vty lv0)
                 stp (ptr? ty ? (tsz g <>ty) 1)
                 (? (arr? ty) 'bad
                    (ua? lv0 && !(bitf? ty))        ; a misaligned member: old by chunks, the step back by chunks
                     (? (flo? ty || pair? g ty || d128? ty) (uanl g)
                        (: n (tsz g ty) a (vma lv0)
                           (matv g lv0 @ lv
                              (mkv ty 'r0 (vfs lv + ['(mov r1 r0)] + ldal 'r0 'r1 0 n a + cvt ty 'r0
                                           + [['add 'r2 'r0 (stp * step)]] + (ty @ 'bool (cvt ty 'r2))
                                           + stal 'r1 0 n a 'r2)))))
                    ; unit read-modify-write: the old field answers in r0, and the unit takes
                    ; ((old ^ new) & mask) << bitoff by xor, the mask two shifts
                    (bitf? ty)
                     (: uty <>ty bitoff <>>ty width <>>>ty usz (tsz g ty) ua (ua? lv0 ? (vma lv0) ())
                        hi (64 - (bitoff + width)) lo (64 - width)
                        (uty = 'bool || usz > wsize g ? 'bad   ; a pair unit refuses
                           (matv g lv0 @ lv
                              (mkv 'long 'r0
                                 (vfs lv + ['(mov r1 r0)] + bfld g ty 'r2 'r1 0 ua + ['(mov r0 r2)]
                                  + (hi > 0 ? [['shl 'r0 hi]])
                                  + (lo > 0 ? [[(usg? uty ? 'shr 'sar) 'r0 lo]])
                                  + [['add 'r3 'r0 step] '(xor r3 r3 r0)]
                                  + (lo > 0 ? [['shl 'r3 lo] ['shr 'r3 lo]])
                                  + (bitoff > 0 ? [['shl 'r3 bitoff]])
                                  + ['(xor r2 r2 r3)] + bfst g ty 'r1 0 ua 'r2)))))
                    (d128? ty) (nolane g "++/-- is not carried on a wide value (use `x = x + 1`)")
                    (pair? g ty && ia32? g)             ; i386: the old pair out, the step added in memory
                     (matv g lv0 @ lv
                        (: sv (stp * step)
                           (mkv ty 'r0 (vfs lv + [['mov 'r3 'r0] ['ld 'r1 'r3 4] ['ld 'r0 'r3 0]
                                                   '(sub sp sp 16) '(st sp 0 r0) '(st sp 4 r1)
                                                   ['li 'r2 (sv & 4294967295)] '(adds r0 r0 r2)
                                                   ['li 'r2 (sv < 0 ? 4294967295 0)] '(adc r1 r1 r2)
                                                   '(st r3 0 r0) '(st r3 4 r1) '(ld r0 sp 0) '(ld r1 sp 4) '(add sp sp 16)]))))
                    (pair? g ty)
                     (matv g lv0 @ lv
                        (mkv ty 'r0 (vfs lv +
                               '((mov r12 r0)) + pld 'r12 0 + ppost 'r12 0 (stp * step))))
                    ; a float: old on f0, old + step stores (r2 the address)
                    (flo? ty)
                     (matv g lv0 @ lv
                        (: n (n32? g ty)
                           (mkv (fvt g ty) 'r0
                              (vfs lv + '((mov r2 r0)) + vfs (mkflo g (0.0 + step))
                               + (n ? '((cvtsd2ss f1 f0)) '((movsd f1 f0))) + fldv g ty 'f0 'r2 0
                               + (n ? '((addss f1 f0)) '((addsd f1 f0))) + fstv g ty 'r2 0 'f1))))
                    ; face-direct: no step rhs runs, so the base survives by construction
                    (vm? lv0 && vmb lv0 != 'r0)
                     (: b (vmb lv0) o (vmo lv0)
                        fs (vfs lv0 +
                            ([[(ldop ty) 'r0 b o]
                               ['add 'r1 'r0 (stp * step)]]
                             + (ty @ 'bool (cvt ty 'r1))   ; b++/b-- lands on 0/1
                             + [[(stop ty) b o 'r1]]))
                        (rfree g b,
                         mkv ty 'r0 fs))
                    (matv g lv0 @ lv
                       (mkv ty 'r0 (vfs lv +
                              (['(mov r2 r0)
                                 [(ldop ty) 'r0 'r2 0]
                                 ['add 'r1 'r0 (stp * step)]]
                               + (ty @ 'bool (cvt ty 'r1))   ; b++/b-- lands on 0/1
                               + [[(stop ty) 'r2 0 'r1]]))))))))))
       ; op= evaluates e1 once: its address moors in a frame temp, ('moor off ty) standing for it
       ('rmw op dst rhs)
        (: lv0 (clval g env dst)
           (matv g lv0 @ lv
           (bad? lv ? 'bad
              (vty lv @ ty
                 (arr? ty || stru? ty ? 'bad
                    (: off (ntmp g 'long)
                       mo (ua? lv0 ? ['moor off ty (vma lv0)] ['moor off ty])
                       r (cgexpr g env ['asn mo ['bin op mo rhs]] ())
                       (bad? r ? 'bad
                          (mkv (vty r) (vreg r)
                               (vfs lv + [['st 'r4 off 'r0]] + vfs r)))))))))
       ('cast ty x)
        (: tgt ty
           ; (double) of a constant expression is one; (float) of one lays its binary32 bits
           fv (? (n32? g tgt) (dbty x != 'no && (ffoldw !(ilp32? g) x @ v
                                 (dfin? v ? (mkv 'float 'r0 [['li 'r0 (fbits32 v)] '(movdxr f0 r0)]) ())))
                 (flo? tgt) (cgdfold g e) ())
           r (two? fv ? 'bad (cgexpr g env x (!(flo? tgt) && !(two? (cvt tgt 'r0)) ? wnt)))
           (? (two? fv) fv
              (bad? r) 'bad
              (flo? tgt && d128? (vty r))
               ; (double) of a wide value: a constant expression only, folded exactly; no runtime lane
               (cfold !(ilp32? g) x @ v
                  (cint? v ? (ilp32? g ? (mkflo g (0.0 + v)) (mkv 'double 'r0 [['li 'r0 (fbits (0.0 + v))] '(movqxr f0 r0)]))
                     'bad))
              (d128? tgt && flo? (vty r))                                 ; double -> wide: not carried
               (nolane g "a double is not converted to a wide integer")
              (n32? g tgt) (mkv 'float 'r0 (asf32 g r))                      ; -> a native float: one rounding
              (flo? tgt && !(flo? (vty r))) (mkv 'double 'r0 (asflo g r))  ; int -> double
              (tgt = 'bool && flo? (vty r))       ; (bool)d is d != 0.0
               (: z1 (ilp32? g ? '((li r0 0) (li r1 0) (movqxr f1 r0))
                        '((li r0 0) (movqxr f1 r0)))
                  (mkv 'bool 'r0 (asflo g r + z1 + '((ucomisd f0 f1)) + fsetn)))
              (!(flo? tgt) && flo? (vty r))                              ; double -> int, then narrow
               (? (pair? g tgt)                                               ; double -> llong: the pattern peel
                   (mkv tgt 'r0 (asflo g r + cvtdll g (usg? tgt)))
                  (ilp32? g && usg? tgt)                                  ; 32-bit unsigned: the U-converter
                   (mkv tgt 'r0 (asflo g r + '((cvttsd2ui r0 f0)) + cvt tgt 'r0))
                  (mkv tgt 'r0 (asintt g r tgt + cvt tgt 'r0)))
              ; floats ride as doubles and narrow only at a store, so the cast narrows here
              (tgt = 'float && flo? (vty r))
               (mkv 'double 'r0 (vfs r + '((cvtsd2ss f0 f0) (cvtss2sd f0 f0))))
              (flo? tgt) (mkv 'double 'r0 (asflo g r))                        ; double -> double (a native float widens)
              (pair? g tgt && !(llt? (vty r)))                           ; widen to the pair (source signedness)
               (mkv tgt 'r0 (asll g r))
              (d128? tgt && !(d128? (vty r)))                            ; widen to the wide pair (source signedness)
               (w128? g ? (mkv tgt 'r0 (as128 g r)) (no128 g))
              (two? (cvt tgt 'r0)) (mkv tgt 'r0 (tor0 g r + cvt tgt 'r0))   ; int -> narrower int
              (mkv tgt (vreg r) (vfs r))))                                    ; a full-word cast keeps the register
       ('un op x)
        (: fv (op @ 'neg (cgdfold g e))      ; -1.5 is a 'un over a 'flo, not a literal
           r (two? fv ? 'bad (cgexpr g env x ()))
           (? (two? fv) fv
              (bad? r) 'bad
              (gcplx? (vty r) && op = 'neg)      ; -z: both components flip
               (cxpark g r @ pa
                  (bad? pa ? 'bad
                     (cxout g (cxb (vty r) @ 'float (vty r) cxdty)
                        ; each component's sign bit flips, a nan's too; r0 is free, cxout writes it last
                        (<>pa + [['ldsd 'f0 'r4 <pa] ['ldsd 'f1 'r4 (<pa + 8)]] + dneg g 'f0 + dneg g 'f1))))
              (vty r = 'float && f32v? g)           ; a native float: -f flips the sign bit
               (op @ 'neg (mkv 'float 'r0 (vfs r + '((movdrx r0 f0) (li r1 0x80000000) (xor r0 r0 r1) (movdxr f0 r0))))
                     'not (mkv 'long 'r0 (asflo g r + '((li r1 0) (movqxr f1 r1) (ucomisd f0 f1)) + fsete))
                     'bad)
              (flo? (vty r))                        ; unary on a double
               (: z1 (ilp32? g ? '((li r0 0) (li r1 0) (movqxr f1 r0))           ; 0.0 (the 32-bit pair)
                               '((li r0 0) (movqxr f1 r0)))
                  (op @ 'neg                 ; -d flips the sign bit, a nan's too
                         (mkv 'double 'r0 (vfs r + dneg g 'f0))
                        'not                 ; !d = (d == 0.0): !NaN is false
                         (mkv 'long 'r0 (vfs r + (z1 + ('((ucomisd f0 f1)) + fsete))))
                        'bad))                           ; ~ on a double is invalid
              (pair? g (vty r))                     ; unary on the pair
               (op @ 'neg
                      (mkv (vty r) 'r0 (tor0 g r + '((li r2 0) (li r3 0))
                                                 + (ia32? g ? '((subs r2 r2 r0) (sbc r3 r3 r1) (mov r0 r2) (mov r1 r3))   ; x86's two-address borrow
                                                     '((subs r0 r2 r0) (sbc r1 r3 r1)))))
                     'bnot
                      (mkv (vty r) 'r0 (tor0 g r + '((not r0) (not r1))))
                     (mkv 'long 'r0 (tor0 g r + [['ors (v6m? g || ia32? g ? 'r0 'r12) 'r0 'r1] '(set eq r0)])))
              (d128? (vty r))                       ; unary on the wide pair
               (? !(w128? g) (no128 g)
                  (op = 'neg) (mkv (vty r) 'r0 (tor0 g r + '((n128))))
                  (op = 'bnot) (mkv (vty r) 'r0 (tor0 g r + (t32w? g ? '((not r0) (not r1) (not r2) (not r3)) '((not r0) (not r2)))))
                  (mkv 'long 'r0 (tor0 g r + (t32w? g ? '((or r0 r0 r1) (or r0 r0 r2) (or r0 r0 r3)) '((or r0 r0 r2)))
                                  + '((cmp r0 0) (set eq r0)))))
              ; -1ull stays unsigned and -1u wraps at 32 bits, not 64; an unsigned char or short promotes
              ; to int first (6.3.1.1), so its ~ and - are int and nothing re-narrows
              (: uty (elem op '(neg bnot) && usg? (vty r) && !(elem (vty r) '(uchar cchar ushort)))
                 ; ..and under -fwrapv an int's - wraps: -INT_MIN is INT_MIN
                 sty (op = 'neg && !uty && s32bin? g (vty r) 'int)
                 renar (? uty (vty r @ 'uint '((zx4 r0))) sty '((sx4 r0)) ())
                 (mkv (? uty (vty r) sty 'int 'long) 'r0
                    (tor0 g r +
                     (op @ 'neg '((neg r0))
                           'bnot '((not r0))
                           '((cmp r0 0) (set eq r0))) +
                     renar)))))
       ('comma ea eb)
        (: a (cgexpr g env ea ())
           b (cgexpr g env eb wnt)
           (bad? a || bad? b ? 'bad
              (mkv (vty b) (vreg b) (vdrop g a + vfs b))))
       ('land . _)                                ; as a value: cbranch the short-circuit, then settle the bit
        (: lf (nlab g ".f") ld (nlab g ".d")
           f (cbranch g env e 'eq lf)
           (bad? f ? 'bad
              (mkv 'long 'r0 (f + ['(li r0 1) ['jmp ld]
                                       ['label lf] '(li r0 0) ['label ld]]))))
       ('lor . _)
        (: lt (nlab g ".t") ld (nlab g ".d")
           f (cbranch g env e 'ne lt)
           (bad? f ? 'bad
              (mkv 'long 'r0 (f + ['(li r0 0) ['jmp ld]
                                       ['label lt] '(li r0 1) ['label ld]]))))
       ('cond cnd ea eb)
        (: sel (fsel? g ? (csel g env cnd ea eb wnt) 'no)   ; a select, where one fits
           (sel != 'no ? sel
        (: le (nlab g ".e") ld (nlab g ".d")
           c (cbranch g env cnd 'eq le)
           t (cgexpr g env ea ())
           el (cgexpr g env eb ())
           (bad? c || bad? t || bad? el ? 'bad
              ; C converts the arms (6.5.15p5): one flo arm makes both flo, two arithmetic arms meet at puac
              (: fl (flo? (vty t) || flo? (vty el))
                 pl (pair? g (vty t) || pair? g (vty el))   ; one pair arm pairs the other too
                 ; a literal arm reads its written type: the tuple types a bare number 'long
                 ta9 (numty9 ea (vty t)) tb9 (numty9 eb (vty el))
                 ; the wide pair stays with the then-arm
                 ua (!fl && !pl && parith? ta9 && parith? tb9 &&
                     !(d128? ta9) && !(d128? tb9))
                 ; two native-float arms (or one and an integer) meet as a float; a double arm makes both doubles
                 f9 (fl && f32v? g && (vty t = 'float || vty el = 'float) && !(vty t = 'double || vty el = 'double))
                 tf (? f9 (asf32 g t) fl (asflo g t) pl (asll g t) (tor0 g t))
                 ef (? f9 (asf32 g el) fl (asflo g el) pl (asll g el) (tor0 g el))
                 rt (? f9 'float fl 'double
                       pl (llt? (vty t) ? (vty t) (vty el))
                       ua (puac !(ilp32? g) ta9 tb9)
                       (vty t))
                 ; a 32-bit unsigned result owes a signed arm the zx4: it rode sign-extended past bit 31
                 nt (u32? g rt && !(usg? ta9) ? '((zx4 r0)) ())
                 ne (u32? g rt && !(usg? tb9) ? '((zx4 r0)) ())
                 (mkv rt 'r0
                    (c + tf + nt + [['jmp ld] ['label le]] + ef + ne + [['label ld]])))))))
       ; va_list, SysV: {gp_offset, fp_offset, overflow_arg_area, reg_save_area}
       ; AAPCS64: {__stack, __gr_top, __vr_top, __gr_offs, __vr_offs}, offs negative from each top
       ('vastart ap)
        ; cgexpr, not clval: an array va_list decays, a param one loads
        (: lv (cgexpr g env ap ())                 ; the va_list struct pointer in r0
           rsa (peep g 'rsa 0) ngp (peep g 'vagp 0) nxmm (peep g 'vaxmm 0)
           nov (peep g 'vaov 0)                  ; named params that overflowed (slots)
           (bad? lv ? 'bad
              (pin g 'fesc 1,                                       ; the va_list holds frame addresses: no sibcalls here
               mkv 'long 'r0 (tor0 g lv +
                (? (ilp32? g)   ; __ap = the first anonymous word, past push cells, named regs, named overflow
                   [['lea 'r1 'r4 (ovb g + 4 * ngp + nov)] '(st r0 0 r1)]
                   (rv64? g)   ; likewise by 8-byte slots
                   [['lea 'r1 'r4 (ovb g + 8 * ngp + 8 * nov)] '(st r0 0 r1)]
                   (a64? g)
                   [['lea 'r1 'r4 (ovb g + 8 * nov)] '(st r0 0 r1)   ; __stack = fp+32 + named overflow
                      ['lea 'r1 'r4 (rsa + 64)]  '(st r0 8 r1)            ; __gr_top (past x0..x7)
                      ['lea 'r1 'r4 (rsa + 192)] '(st r0 16 r1)           ; __vr_top (past q0..q7)
                      ['li 'r1 -(8 * (8 - ngp))]  '(st4 r0 24 r1)    ; __gr_offs = -(unnamed gp)*8
                      ['li 'r1 (nofp? g ? 0 -(16 * (8 - nxmm)))] '(st4 r0 28 r1)]  ; __vr_offs = -(unnamed vr)*16, none saved under nofp
                   [['li 'r1 (8 * ngp)]         '(st4 r0 0 r1)   ; gp_offset = 8*named-gp
                      ['li 'r1 (48 + 16 * nxmm)] '(st4 r0 4 r1)  ; fp_offset = 48 + 16*named-xmm
                      '(lea r1 r4 16)  '(st r0 8 r1)             ; overflow_arg_area = rbp+16
                      ['lea 'r1 'r4 rsa] '(st r0 16 r1)])))))      ; reg_save_area = rbp+rsa
       ('vaarg ap ty)
        (: lv (cgexpr g env ap ())          ; the va_list struct pointer in r0
           lov (nlab g ".vo") ld (nlab g ".vd")
           ; r1 = the offset, r2 = the fetch address
           walk (? (ilp32? g)
                   '((ld r2 r0 0) (mov r3 r2) (add r3 r3 4) (st r0 0 r3))
                   (rv64? g)   ; __ap walks 8-byte slots (doubles ride gp slots)
                   '((ld r2 r0 0) (mov r3 r2) (add r3 r3 8) (st r0 0 r3))
                   (a64? g)
                   (: foff (flo? ty ? 28 24)               ; __vr_offs / __gr_offs
                      toff (flo? ty ? 16 8)                ; __vr_top / __gr_top
                      step (flo? ty ? 16 8)                ; a vr slot is one q (16)
                      [['ld4 'r1 'r0 foff] '(cmp r1 0) ['br 'ge lov]
                       ['ld 'r2 'r0 toff] '(add r2 r2 r1)           ; p = top + offs
                       ['add 'r1 'r1 step] ['st4 'r0 foff 'r1]          ; advance the offs
                       ['jmp ld] ['label lov]
                       '(ld r2 r0 0) '(mov r3 r2) '(add r3 r3 8) '(st r0 0 r3)   ; p = __stack; __stack += 8
                       ['label ld]])
                   (: foff (flo? ty ? 4 0)                 ; fp_offset (4) vs gp_offset (0)
                      lim (flo? ty ? 176 48)               ; the register-area limit
                      step (flo? ty ? 16 8)                ; the offset stride
                      [['ld4 'r1 'r0 foff] ['cmp 'r1 lim] ['br 'ge lov]
                       '(ld r2 r0 16) '(add r2 r2 r1)            ; p = reg_save_area + offset
                       ['add 'r1 'r1 step] ['st4 'r0 foff 'r1]         ; advance the offset
                       ['jmp ld] ['label lov]
                       '(ld r2 r0 8) '(mov r3 r2) '(add r3 r3 8) '(st r0 8 r3)   ; p = overflow; overflow += 8
                       ['label ld]]))
           (? (bad? lv) 'bad
              ; i386: a pair's two words and a struct's bytes lie where the caller laid them, 4-aligned
              (ia32? g && flo? ty)                  ; a double's 8 bytes (a float arrives promoted)
               (mkv 'double 'r0 (tor0 g lv + '((ld r2 r0 0) (mov r3 r2) (add r3 r3 8) (st r0 0 r3)) + fldf 'double 'f0 'r2 0))
              (ia32? g && llt? ty)
               (mkv ty 'r0 (tor0 g lv + '((ld r2 r0 0) (mov r3 r2) (add r3 r3 8) (st r0 0 r3) (ld r1 r2 4) (ld r0 r2 0))))
              (ia32? g && stru? ty)
               (mkv ty 'r0 (tor0 g lv + ['(ld r2 r0 0) '(mov r3 r2) ['add 'r3 'r3 (aup (tsz g ty) 4)] '(st r0 0 r3) '(mov r0 r2)]))
              ; aapcs32: a double or a pair sits 8-aligned, a struct at its own alignment
              (v6m? g && (flo? ty || llt? ty || stru? ty))     ; v6-M's va_arg reads words only
               (nolane g "no lane for a double/pair/struct va_arg\(ontgt g)")
              (t32? g && (flo? ty || llt? ty))
               (: al8 '((ld r2 r0 0) (add r2 r2 7) (li r3 -8) (and r2 r2 r3) (mov r3 r2) (add r3 r3 8) (st r0 0 r3))
                  (flo? ty ? (mkv 'double 'r0 (tor0 g lv + al8 + fldf 'double 'f0 'r2 0))
                             (mkv ty 'r0 (tor0 g lv + al8 + '((ld r1 r2 4) (ld r0 r2 0))))))
              (t32? g && stru? ty)
               (: al (asalign g ty) up (8 <= al ? 7 3) mk (8 <= al ? -8 -4)
                  (mkv ty 'r0 (tor0 g lv + [['ld 'r2 'r0 0] ['add 'r2 'r2 up] ['li 'r3 mk] '(and r2 r2 r3)
                                            '(mov r3 r2) ['add 'r3 'r3 (aup (tsz g ty) 4)] '(st r0 0 r3) '(mov r0 r2)])))
              (d128? ty) (nolane g "a wide va_arg is not carried")
              ; a by-value struct lies in place: the value is its slots' address. a64's memory class
              ; takes the pointer path below, its slot holding its copy's address
              (stru? ty && !(refm? g ty))
               (: n8 (8 * aslots g ty)
                  gpo (aone g ty = 'int || ipair? g ty)        ; every eightbyte INT
                  stk ['(ld r2 r0 0) '(mov r3 r2) ['add 'r3 'r3 n8] '(st r0 0 r3)]   ; p = the stack cursor, stepped past
                  done (seq \ mkv ty 'r0 (tor0 g lv + seq + ['(mov r0 r2)]))
                  (? (8 < asalign g ty) (nolane g "no lane for a va_arg of a struct aligned past 8\(ontgt g)")
                     ; AAPCS64: from the x save area while __gr_offs + size <= 0, else __stack, closing the gp file
                     (a64? g)
                      (hfab g ty @ b (flo? b) ?
                         (nolane g "no lane for a va_arg of a float aggregate\(ontgt g)")
                         (done ([['ld4 'r1 'r0 24] '(cmp r1 0) ['br 'ge lov]
                                 '(mov r3 r1) ['add 'r3 'r3 n8] ['st4 'r0 24 'r3]
                                 '(cmp r3 1) ['br 'ge lov]
                                 '(ld r2 r0 8) '(add r2 r2 r1) ['jmp ld] ['label lov]]
                                + stk + [['label ld]])))
                     ; riscv: __ap walks the slots whole
                     (rv64? g) (gpo ? (done stk) (nolane g "no lane for a va_arg of this struct\(ontgt g)"))
                     ; SysV: memory class from the overflow area; INT from the gp save area while
                     ; gp_offset + size <= 48, else whole from overflow, gp_offset unmoved
                     (: ovs ['(ld r2 r0 8) '(mov r3 r2) ['add 'r3 'r3 n8] '(st r0 8 r3)]
                        (? (amem? g ty) (done ovs)
                           gpo (done ([['ld4 'r1 'r0 0] ['cmp 'r1 (49 - n8)] ['br 'ge lov]
                                       '(ld r2 r0 16) '(add r2 r2 r1) ['add 'r1 'r1 n8] ['st4 'r0 0 'r1]
                                       ['jmp ld] ['label lov]]
                                      + ovs + [['label ld]]))
                           (nolane g "no lane for a va_arg of this struct\(ontgt g)")))))
              (flo? ty) (mkv 'double 'r0 (tor0 g lv + walk + fldf ty 'f0 'r2 0))
              (mkv ty 'r0 (tor0 g lv + walk + [[(ldop ty) 'r0 'r2 0]]))))
       ('vaend . _) (mkv 'long 'r0 ())
       ('call fh as)
        (: head fh args as
           bi (<head = 'var ? <>head)
           bv (cgbuiltin g env bi args)
           (bv != 'no ? bv
              (: direct (<head = 'var && bad? (vent g env <>head) &&  ; not a local/global variable...
                                         g 'fns <>head)     ; ...and a known function (typos refuse)
                 sig (direct ? (g 'sigs <>head))
                 ; the param types, a function pointer's too: a widened float arg looks like a double
                 ptys (? (two? sig) <>sig direct () (fnpts (hdty9 g env head)))
                 ; an indirect callee's result type is its pointer's (a memory return owes the hidden arg)
                 rt (? (two? sig) <sig direct 'long (fnret (hdty9 g env head)))
                 variadic (two? sig ? (sig 2))
                 ; the arity check, direct only. 0 < nps exempts the empty list: the sigs row
                 ; cannot tell `int f()` from `int f(void)`
                 nps #ptys nas #args
                 off (direct && 0 < nps && (variadic ? (nas < nps) (nas != nps)))
                 _ (off ? (pin g 'arity
                               "call to '\(<>head)' wants \(nps)\(variadic ? " or more" "")\(nps = 1 ? " argument" " arguments"), given \(nas)") 0)
                 cr (off ? 'bad (call-fixed g env head args direct ptys rt variadic))
                 (? (bad? cr) 'bad
                    !(stru? (vty cr)) cr
                    (sretm? g (vty cr)) cr   ; a memory return: the sret temp's address is the value
                    (cxf32? g (vty cr))             ; an i386 float complex: park its r0:r1 words
                     (nslot g 8 @ toff
                        (mkv (vty cr) 'r0 (vfs cr + [['st4 'r4 toff 'r0] ['st4 'r4 (toff + 4) 'r1] ['lean 'r0 'r4 toff]])))
                    (a64hfa g (vty cr))             ; an a64 float HFA result: s0.. into a fresh slot
                     (nslot g 16 @ toff
                        (mkv (vty cr) 'r0 (vfs cr + catmap (j \ [['stss 'r4 (toff + 4 * j) (xmmreg j)]]) ^(a64hfa g (vty cr))
                                           + [['lean 'r0 'r4 toff]])))
                    (sse2? g (vty cr))              ; a two-double struct: park the xmm pair, answer its address
                     (nslot g 16 @ toff
                        (mkv (vty cr) 'r0 (vfs cr +
                                           fstf g 'double 'r4 toff (xmmreg 0) +
                                           fstf g 'double 'r4 (toff + 8) (xmmreg 1) +
                                           [['lean 'r0 'r4 toff]])))
                    (t32? g &&                    ; t32: past the d-pair, only an 8B sse blob (d0) or a <=4B int (r0)
                     !(aone g (vty cr) = 'sse && tsz g (vty cr) = 8 ||
                       aone g (vty cr) = 'int && tsz g (vty cr) <= 4)) 'bad
                    (ipair? g (vty cr))             ; a two-int struct result: park rax:rdx (a64 x0:x1) the same way
                     (nslot g 16 @ toff
                        (mkv (vty cr) 'r0 (vfs cr +
                                     [['st 'r4 toff 'r0] ['st 'r4 (toff + 8) (ip2 g)]
                                        ['lean 'r0 'r4 toff]])))
                    (aone g (vty cr) = 'sse)    ; a small SSE aggregate result: park xmm0
                     (nslot g 16 @ toff
                        (mkv (vty cr) 'r0 (vfs cr +
                                           (fstf g 'double 'r4 toff (xmmreg 0) +
                                            [['lean 'r0 'r4 toff]]))))
                    (aone g (vty cr) = 'int)    ; a small int aggregate result: park rax
                     (nslot g 16 @ toff
                        (mkv (vty cr) 'r0 (vfs cr + [['st 'r4 toff 'r0] ['lean 'r0 'r4 toff]])))
                    (nolane g "no lane for receiving a \(tsz g (vty cr))-byte struct by value\(ontgt g)")))))
       ; a statement expression: the statements, then the value. 'inlining is raised so stq stops
       ; ticking and each statement wears the conservative wrapset
       ('sexpr items ve ty)
        (: il0 (g 'inlining)
           _ (pin g 'inlining ((il0 || 0) + 1))
           pre (g 'sxpre g env items ())
           (pin g 'inlining il0,
            (? (bad? pre) 'bad
               !(two? ve) (mkv ty 'r0 <pre)                   ; void: the statements alone
               (cgexpr g <>pre ve wnt @ r
                  (bad? r ? 'bad (mkv (vty r) (vreg r) (<pre + vfs r)))))))
       ('clit . _)                              ; a compound literal as a value: fill the temp, load it
        (clval g env e @ lv
           (bad? lv ? 'bad (loadval g lv wnt)))
       ('bin op a b)
        (: fv (elem op '(+ - * /) ? (cgdfold g e) ())   ; 1.5 + 2.25 is a constant, not an addsd
           (? (two? fv) fv
              (op = '|) (cgror g env a b wnt @ 'no (cgbin g env e wnt) r9 r9)
              (cgbin g env e wnt))))
   ; a targetable arg skips the cell and lands in its register after the spills. a gp one is a pure
   ; single-emission read -> ((ez i) forms) | ((ezm i rH) movforms ldforms) | 'no. a double (or an f32abi
   ; float) off its xmm home or frame cell, when every arg is a pure leaf -> ((ezx i) forms) | 'no
   (ezxarg g env e pty i)
    (? (!(fsel? g) || abl? g 'ezx || !(g 'ezride) || 8 <= i || !(<e = 'var)) 'no
       (vent g env <>e @ en
          (: fl (<>>en = 'float && pty = 'float && f32abi? g)
             (? (bad? en || !(fl || <>>en = 'double && (!pty || pty = 'double))) 'no
                (<en = 'regv && elem <>en fregs16) [['ezx i] [['movapd (xmmreg i) <>en]]]
                (<en = 'loc) [['ezx i] [[(fl ? 'ldss 'ldsd) (xmmreg i) 'r4 <>en]]]
                'no))))
   (ezall g env e pty gpc xmmc va)
    (ia32? g ? (gpc < ngp g ? (ezarg g env e pty gpc) 'no)   ; i386: a regparm word, never an xmm
       (: z (gpc < ngp g ? (ezarg g env e pty gpc) 'no)
          (z != 'no || va ? z (ezxarg g env e pty xmmc))))
   (ezarg g env e pty i)
    (: rT (argr g i)
       (fin ty fs) (: aty (pty ? pty ty)
                      (flo? aty || stru? aty || llt? aty || d128? aty ? 'no [['ez i] fs]))   ; a pair arg keeps the cell path
       kc (knum g e)
       (? (two? kc) (t32? g && !(fitsw? <kc) ? 'no
                       (fin 'long [['li rT <kc]]))
          (<e = 'str)
           (nlab g ".S" @ lbl
              (pin g 'strs ([lbl <>e] . g 'strs),
               fin ['ptr (gchar g)] [['la rT lbl]]))
          (<e = 'addr)                          ; &var only: lea/la, argpos-equivalent (escana)
           (!(<<>e = 'var) ? 'no
              (vent g env <><>e @ en
                 (? (bad? en) 'no
                    (<en = 'loc) (pin g 'fesca 1, fin ['ptr <>>en] [['lea rT 'r4 <>en]])
                    (<en = 'glo) (fin ['ptr <>>en] [['la rT <>en]])
                    'no)))
          !(<e = 'var) 'no
          (vent g env <>e @ en
             (bad? en ? 'no
                (<>>en @ ty
                   (? (<en = 'regv)             ; a register param: mov from it, or ld its spill slot
                       (? (flo? (pty ? pty ty) || stru? (pty ? pty ty)) 'no
                          ; callee-saved: the staging writes none, so it targets unconditionally
                          (elem <>en (cspool g)) (fin ty [['mov rT <>en]])
                          (assoc <>en (g 'homes) @ sl
                             (? (two? sl)
                                 [['ezm i <>en]
                                   [['mov rT <>en]]
                                   [['ld rT 'r4 <>sl]]]
                                ; no spill slot: only when every sibling is a pure leaf (ezride)
                                ; and the source is outside the argument file
                                (peep g 'ezride () && nelem <>en (argr g))
                                 (fin ty [['mov rT <>en]])
                                'no)))
                      (arr? ty)                      ; array decay: its address
                       (<en = 'loc ? (pin g 'fesca 1, fin ['ptr <>ty] [['lea rT 'r4 <>en]])
                          (fin ['ptr <>ty] [['la rT <>en]]))
                      (stru? ty || flo? ty) 'no
                      (<en = 'loc)
                       (fin ty [[(ldop ty) rT 'r4 <>en]])
                      ; a global: la then a self-based load, but not into a64/riscv's fifth arg register:
                      ; r4 in a base slot reads as the frame base
                      (a8? g && rT = 'r4 ? 'no (fin ty [['la rT <>en] [(ldop ty) rT rT 0]]))))))))
   ; overflow args emit first, then the register group, both right-to-left; the caller cleans the
   ; overflow block. params are named uniquely so no lambda param shadows a :-local
   (call-fixed g env hd ags dir pts ret va?)
    (: (kls as i gpc xmmc ovc acc)                       ; classify + evaluate, L->R -> (((class idx) pushforms)..) | 'bad
        (!(two? as) ? (rev acc)
           ; a targetable leaf skips the cell ('ez/'ezm): emitted into its register after the spills
           (: ez (ezall g env <as (pts i) gpc xmmc va?)
              (ez != 'no ? (<<ez = 'ezx ? (kls >as (i + 1) gpc (xmmc + 1) ovc (ez . acc))
                              (kls >as (i + 1) (gpc + 1) xmmc ovc (ez . acc)))
           ; a direct &x / array / struct-var arg is dead once the callee returns: argpos exempts it from fesc.
           ; the first cell arg aims at its register (it evaluates last); dir only, never a home
           (: aim (: (psh9 pl) (two? pl ?
                                  (elem <<<pl '(g g2 g4 gn x x2 p2 ezd) || psh9 >pl))
                     rT (argr g gpc)
                     (dir && gpc < ngp g && !(psh9 acc) &&
                      !(two? (assoc rT (g 'homes))) ? rT))
              a ((elem <<as '(addr var) ? (pin g 'argpos 1)),
                 cgexpr g env <as aim)
              (pin g 'argpos (),
               bad? a ? 'bad
                 (: pty (pts i)
                    aty (pty ? pty (vty a))
                    wd (flo? aty)
                    ; t32 composites: an HFA rides the d-regs, an 8B one-sse blob the packed s-pair, a <=4B int one r0; the rest refuse
                    (? (v6m? g && va? && stru? aty && !(t32core? g aty))   ; v6-M's variadic composites: not yet
                        (nolane g "no lane for a by-value struct in a variadic call\(ontgt g)")
                       (v6m? g && sse2? g aty)       ; v6-M: a 16B composite rides r0-r3 whole,
                        (gpc = 0 ?                     ; at position 0 only
                           (kls >as (i + 1) 4 xmmc ovc
                                (. ['(g4 0) (tor0 g a + cell4w)] acc))
                           'bad)
                       ; aapcs32: a composite rides r0-r3 as words (8-aligned from an even register), else
                       ; the stack, closing the gp file. one straddling r3 with the stack empty splits (C.5):
                       ; head in the last registers, tail at the block's start. the tail's entry runs first,
                       ; parking the struct's address for the head's
                       (t32core? g aty || t32? g && !(v6m? g) && va? && stru? aty && 0 < tsz g aty)   ; a variadic call: every composite
                        (: sz (tsz g aty) nw (sz // 4) nr ((aup sz 4) // 4) al8 (8 <= asalign g aty)
                           gpe (al8 ? (aup gpc 2) gpc)
                           (wc o) (catmap (j \ [['ld 'r1 'r0 (4 * j)] ['st 'sp (o + 4 * j) 'r1]]) ^nw
                                   + catmap (j \ [['ldu1 'r1 'r0 (4 * nw + j)] ['st1 'sp (o + 4 * nw + j) 'r1]]) ^(sz % 4))
                           (? (nr <= 4 && gpe + nr <= ngp g)
                               (kls >as (i + 1) (gpe + nr) xmmc ovc
                                    ([['gn gpe nr] (tor0 g a + '((sub sp sp 16)) + wc 0)] . acc))
                              (gpe < ngp g && ovc = 0)
                               (: nh (ngp g - gpe) nt (nr - nh) pk (ntmp g 'long)
                                  head ([['ld 'r0 'r4 pk]] + '((sub sp sp 16))
                                        + catmap (j \ [['ld 'r1 'r0 (4 * j)] ['st 'sp (4 * j) 'r1]]) ^nh)
                                  tail (tor0 g a + [['st 'r4 pk 'r0]]
                                        + catmap (j \ [['ld 'r1 'r0 (4 * (nh + j))] ['st 'sp (4 * j) 'r1]]) ^(nw - nh)
                                        + catmap (j \ [['ldu1 'r1 'r0 (4 * nw + j)] ['st1 'sp (4 * (nw - nh) + j) 'r1]]) ^(sz % 4))
                                  (kls >as (i + 1) (ngp g) xmmc (4 * nt)
                                       ([['gn gpe nh] head] . [['ov 0 (4 * nt)] tail] . acc)))
                              (: ov8 (al8 ? (aup ovc 8) ovc)
                                 (kls >as (i + 1) (ngp g) xmmc (ov8 + aup sz 4)
                                      ([['ov ov8 (aup sz 4)] (tor0 g a + wc ov8)] . acc)))))
                       (t32nolane? g aty) 'bad
                       ; a64 float HFA: consecutive s registers, else all to the stack, closing the s file (C.3)
                       (a64hfa g aty)
                        (: n (a64hfa g aty)
                           (xmmc + n <= 8 ?
                              (kls >as (i + 1) gpc (xmmc + n) ovc (. [['sa xmmc n] (tor0 g a + hfacell n)] acc))
                              (: ns ((aup (4 * n) 8) // 8)
                                 (kls >as (i + 1) gpc 8 (ovc + ns)
                                      (. [['ov ovc ns] (tor0 g a + catmap (j \ [['ld4 'r1 'r0 (4 * j)] ['st4 'sp (8 * ovc + 4 * j) 'r1]]) ^n)]
                                         acc)))))
                       (t32f? g && sse2? g aty)            ; a 16-byte HFA: four float slots, or a d-reg pair
                        (: fb (hfab g aty)
                           k (vfpn xmmc 4 (fb @ 'float 1 2))
                           (k < 0 ? 'bad
                              (kls >as (i + 1) gpc (vfpm xmmc k 4) ovc
                                   (. [(fb @ 'float ['sn k 4] ['x2 (k // 2)])
                                       (tor0 g a + cell4w)] acc))))
                       (sse2? g aty)                       ; a two-double struct: its pair (re on top) to an xmm pair
                        (6 < xmmc ? 'bad
                           (kls >as (i + 1) gpc (xmmc + 2) ovc
                                (. [['x2 xmmc]
                                         (tor0 g a +
                                          (? (t32? g) cell4w   ; t32: four word copies
                                             (a8? g) cell2w    ; a64/riscv's push is a 16-byte cell: lay the pair by hand
                                             push2w))]
                                      acc)))
                       (stru? aty && two? (aeb2 g aty))       ; a 9..16B struct (not sse:sse): each eightbyte to a gp or xmm reg, as the param side
                        (: cls (aeb2 g aty) c0 <cls c1 <>cls
                           hfa (c0 = 'sse && c1 = 'sse)
                           f0 (a64? g ? (hfa ? 'x 'g) (c0 @ 'sse 'x 'g))
                           f1 (a64? g ? (hfa ? 'x 'g) (c1 @ 'sse 'x 'g))
                           gpn ((f0 @ 'g 1 0) + (f1 @ 'g 1 0))
                           xmn ((f0 @ 'x 1 0) + (f1 @ 'x 1 0))
                           ; out of registers: SysV sends it whole to the overflow block, AAPCS64 a gp one,
                           ; closing the gp file (C.13); riscv and an a64 HFA would split, so they refuse
                           (ngp g < gpc + gpn || 8 < xmmc + xmn ?
                               (? (a64? g && gpn = 2)
                                   (: n (tsz g aty) al (tal g aty) o (8 * ovc)
                                      (kls >as (i + 1) (ngp g) xmmc (ovc + 2)
                                           (. [['ov ovc 2] (tor0 g a + ldal 'r1 'r0 0 8 al + [['st 'sp o 'r1]]
                                                            + ldal 'r1 'r0 8 (n - 8) al + [['st 'sp (o + 8) 'r1]])]
                                              acc)))
                                  (arm? g) (nolane g "no lane for a by-value struct past the arg registers\(ontgt g)")
                                  (kls >as (i + 1) gpc xmmc (ovc + 2)
                                       (. [['ov ovc 2] (tor0 g a + push2w)] acc)))
                              (: i0 (f0 @ 'g gpc xmmc)
                                 gpc1 (f0 @ 'g (gpc + 1) gpc)
                                 xmc1 (f0 @ 'x (xmmc + 1) xmmc)
                                 i1 (f1 @ 'g gpc1 xmc1)
                                 (kls >as (i + 1) (gpc + gpn) (xmmc + xmn) ovc
                                      (. [['p2 f0 i0 f1 i1] (tor0 g a + (a8? g ? (ldw2 g (amark aty a)) push2w))]
                                            acc)))))
                       ; an i386 struct under regparm: its words in registers when that many are left
                       (ia32? g && stru? aty && !(gcplx? aty) && 0 < tsz g aty && gpc + ((aup (tsz g aty) 4) // 4) <= ngp g)
                        (: sz (tsz g aty) nw (sz // 4)
                           (kls >as (i + 1) (gpc + ((aup sz 4) // 4)) xmmc ovc
                                ([['gn gpc ((aup sz 4) // 4)]
                                  (tor0 g a + '((sub sp sp 16))
                                   + catmap (j \ [['ld 'r1 'r0 (4 * j)] ['st 'sp (4 * j) 'r1]]) ^nw
                                   + catmap (j \ [['ldu1 'r1 'r0 (4 * nw + j)] ['st1 'sp (4 * nw + j) 'r1]]) ^(sz % 4))]
                                 . acc)))
                       ; an i386 struct: its bytes into the block at ovc, spending the registers left (a complex none)
                       (ia32? g && stru? aty)
                        (: sz (tsz g aty) nw (sz // 4)
                           (kls >as (i + 1) (gcplx? aty ? gpc (ngp g)) xmmc (ovc + aup sz 4)
                                ([['ov ovc (aup sz 4)]
                                  (tor0 g a
                                   + catmap (j \ [['ld 'r1 'r0 (4 * j)] ['st 'sp (ovc + 4 * j) 'r1]]) ^nw
                                   + catmap (j \ [['ldu1 'r1 'r0 (4 * nw + j)] ['st1 'sp (ovc + 4 * nw + j) 'r1]]) ^(sz % 4))]
                                 . acc)))
                       ; an a64 memory-class arg: copied into a temp of the caller's, whose address rides as a pointer
                       (refm? g aty)
                        (: off (ntmp g aty)
                           cp (tor0 g a + [['lea 'r1 'r4 off]]
                               + (sal? g ? (bcopya 0 (tsz g aty) (tal g aty)) (bcopy g 0 (tsz g aty) ()))
                               + [['lea 'r0 'r4 off]])
                           (gpc < ngp g ? (kls >as (i + 1) (gpc + 1) xmmc ovc ([['g gpc] (cp + spush 'r0)] . acc))
                              (kls >as (i + 1) gpc xmmc (ovc + 1) ([['ov ovc] (cp + [['st 'sp (8 * ovc) 'r0]])] . acc))))
                       ; a memory-class struct fills n overflow slots, highest eightbyte pushed first
                       (amem? g aty)
                        (8 < asalign g aty ?
                            (nolane g "a by-value struct aligned past 8 is not carried as an argument")
                           (: n (aslots g aty)
                              (mv j acc9) (j < 0 ? acc9
                                             (mv (j - 1) (acc9 + [['ld 'r1 'r0 (8 * j)] '(push r1)])))
                              (kls >as (i + 1) gpc xmmc (ovc + n)
                                   ([['ov ovc n] (tor0 g a + mv (n - 1) ())] . acc))))
                       (stru? aty && !(aone g aty))
                        (nolane g "no lane for passing this \(tsz g aty)-byte struct by value\(ontgt g)")
                       ; a wide arg on t32: r0-r3 whole when the file is untouched, else the 8-aligned stack.
                       ; elsewhere two gp registers lo first: AAPCS64 an even pair, else a 16-aligned stack pair
                       (d128? aty && t32w? g)
                        (? (gpc = 0)
                            (kls >as (i + 1) 4 xmmc ovc ([['gn 0 4] (as128 g a + wpush g)] . acc))
                           (aup ovc 8 @ ov8
                              (kls >as (i + 1) 4 xmmc (ov8 + 16) (. [['ov ov8 16] (as128 g a + wst g 'sp ov8)] acc))))
                       (d128? aty && w128? g)
                        (: gpe (a64? g ? (aup gpc 2) gpc)
                           (? (gpe + 2 <= ngp g)
                               (kls >as (i + 1) (gpe + 2) xmmc ovc ([['gw gpe] (as128 g a + wpush g)] . acc))
                              (a64? g)
                               (aup ovc 2 @ ov2
                                  (kls >as (i + 1) (ngp g) xmmc (ov2 + 2)
                                       (. [['ov ov2 2] (as128 g a + [['st 'sp (8 * ov2) 'r0] ['st 'sp (8 * ov2 + 8) 'r2]])]
                                          acc)))
                              (nolane g "a wide value past the argument registers is not carried")))
                       (d128? aty) (no128 g)
                       ; i386: a double its 8 bytes in the block, a float its 4 where a prototype says float
                       (ia32? g && flo? aty)
                        (: fl ((pts i) = 'float)
                           (kls >as (i + 1) gpc xmmc (ovc + (fl ? 4 8))
                                (. [['ov ovc (fl ? 4 8)]
                                    (fl ? (asf32 g a + [['stss 'sp ovc 'f0]]) (asflo g a + [['stsd 'sp ovc 'f0]]))]
                                   acc)))
                       ; i386: a pair rides two registers when two are left, else the stack, spending the rest
                       (pair? g aty && ia32? g && gpc + 2 <= ngp g)
                        (kls >as (i + 1) (gpc + 2) xmmc ovc ([['g2 gpc] (asll g a + spush2)] . acc))
                       (pair? g aty && ia32? g)
                        (kls >as (i + 1) (ngp g) xmmc (ovc + 8)
                             (. [['ov ovc 8] (asll g a + pstw 'sp ovc 'r0 'r1)] acc))
                       (pair? g aty)                             ; an even-odd register pair, else the stack
                        (aup gpc 2 @ gpe
                           (gpe + 2 <= ngp g ?               ; 8-aligned, closing gp (C.13)
                               (kls >as (i + 1) (gpe + 2) xmmc ovc
                                    ([['g2 gpe] (asll g a + spush2)] . acc))
                               (aup ovc 8 @ ov8
                                  (kls >as (i + 1) 4 xmmc (ov8 + 8)
                                       (. [['ov ov8 8]
                                                (asll g a + pstw 'sp ov8 'r0 'r1)]
                                             acc)))))
                       ; landed where aimed. a zero-form answer (a riding home) keeps the cell
                       (aim && rpeq? g (vreg a) aim && two? (vfs a) &&
                           !(flo? (vty a) || flo? aty || stru? aty))
                        (kls >as (i + 1) (gpc + 1) xmmc ovc ([['ezd gpc] (vfs a)] . acc))
                       ; a one-eightbyte aggregate rides the scalar path, its content loaded into r0
                       (: one (stru? aty ? (aone g aty))
                          wd2 (wd || one = 'sse)
                          aval (? (t32? g && one = 'sse) (tor0 g a + pld 'r0 0)           ; the t32 8B blob rides the r0:r1 pair
                                  one (tor0 g a + (amark aty a @ ma (salw? g ma ? (ldal 'r0 'r0 0 (tsz g ma) (tal g ma)) '((ld r0 r0 0)))))
                                  wd ((pty = 'float && f32abi? g ? (asf32 g a) (asflo g a)) + '((movqrx r0 f0)))
                                  (asintt g a aty))
                          ; a register arg rides a 16-byte cell (sp stays aligned); an overflow arg pushes 8
                          rpush (aval + (t32? g && wd2 ? spush2 (spush 'r0)))     ; a t32 double (or 8B blob) is the r0:r1 pair
                          ; x64 pushes; the rest store into the pre-allocated block
                          opush (? (a8? g) (aval + [['st 'sp (8 * ovc) 'r0]])
                                   (ilp32? g) (aval + [['st 'sp ovc 'r0]])
                                   (aval + '((push r0))))
                          ; a variadic call rides the base pcs, as v6-M's every call does: a double or 8B blob an
                          ; even-odd gp pair, else the 8-aligned stack; a bare float one word
                          (? ((v6m? g || (t32? g && va?)) && aty = 'float)
                              (: av1 (asf32 g a + '((movdrx r0 f0)))
                                 (gpc < ngp g ?
                                    (kls >as (i + 1) (gpc + 1) xmmc ovc
                                         ([['g gpc] (av1 + spush 'r0)] . acc))
                                    (kls >as (i + 1) gpc xmmc (ovc + 4)
                                         ([['ov ovc 4] (av1 + [['st 'sp ovc 'r0]])] . acc))))
                             ((v6m? g || (t32? g && va?)) && wd2)
                              (aup gpc 2 @ gpe
                                 (gpe + 2 <= ngp g ?
                                     (kls >as (i + 1) (gpe + 2) xmmc ovc
                                          ([['g2 gpe] (aval + spush2)] . acc))
                                     (aup ovc 8 @ ov8
                                        (kls >as (i + 1) 4 xmmc (ov8 + 8)
                                             (. [['ov ov8 8]
                                                      (aval + pstw 'sp ov8 'r0 'r1)]
                                                   acc)))))
                             ; AAPCS-VFP: a bare float takes one slot (back-filling a double's hole); past the
                             ; file a 4-byte stack word, the mask closing (vfpx)
                             (t32f? g && aty = 'float)
                              (vfpn xmmc 1 1 @ k
                                 (0 <= k ? (kls >as (i + 1) gpc (vfpm xmmc k 1) ovc
                                                ([['s k] (asf32 g a + '((movdrx r0 f0)) + spush 'r0)] . acc))
                                    (kls >as (i + 1) gpc vfpx (ovc + 4)
                                         ([['ov ovc 4] (asf32 g a + [['stss 'sp ovc 'f0]])] . acc))))
                             ; a two-float HFA: two slots aligned to one, so it may straddle a d-register
                             (t32f? g && one = 'sse && hfab g aty = 'float)
                              (vfpn xmmc 2 1 @ k
                                 (0 <= k ? (kls >as (i + 1) gpc (vfpm xmmc k 2) ovc
                                                ([['sn k 2] rpush] . acc))
                                    (kls >as (i + 1) gpc vfpx (ovc + 8)
                                         ([['ov ovc 8]
                                           (aval + pstw 'sp ovc 'r0 'r1)] . acc))))
                             (t32f? g && wd2)                 ; a double, or a one-double HFA: an aligned slot pair
                              (vfpn xmmc 2 2 @ k
                                 (0 <= k ? (kls >as (i + 1) gpc (vfpm xmmc k 2) ovc
                                                ([['x (k // 2)] rpush] . acc))
                                    (aup ovc 8 @ ov8
                                       (kls >as (i + 1) gpc vfpx (ov8 + 8)
                                            ([['ov ov8 8]
                                              (aval + pstw 'sp ov8 'r0 'r1)] . acc)))))
                             ; a variadic riscv call: every double rides the gp lane
                             (rv64? g && va? && wd2 && gpc < ngp g)
                              (kls >as (i + 1) (gpc + 1) xmmc ovc ([['g gpc] rpush] . acc))
                             (rv64? g && va? && wd2)
                              (kls >as (i + 1) gpc xmmc (ovc + 1) ([['ov ovc] opush] . acc))
                             (wd2 && xmmc < 8) (kls >as (i + 1) gpc (xmmc + 1) ovc ([['x xmmc] rpush] . acc))
                             (!wd2 && gpc < ngp g) (kls >as (i + 1) (gpc + 1) xmmc ovc ([['g gpc] rpush] . acc))
                             (ilp32? g) (kls >as (i + 1) gpc xmmc (ovc + 4) ([['ov ovc 4] opush] . acc))
                             (kls >as (i + 1) gpc xmmc (ovc + 1) ([['ov ovc] opush] . acc)))))))))))
       ; a memory return fills a caller temp whose address rides the first arg register
       sr6 (sretm? g ret)
       sroff (sr6 ? (ntmp g ret) 0)
       ; ezride: every arg a pure leaf, so no sibling evaluation moves a register param
       _ (pin g 'ezride (: (pure? l) (!(two? l) ? 1 (elem <<l '(num var) && pure? >l))
                          (pure? ags)))
       ; i386's hidden pointer is the block's first word, or eax under regparm; a variadic
       ; i386 call lays every word on the stack
       srg (sr6 && srreg? g va?)
       srk (sr6 && ia32? g && !srg ? 4 0)
       kr (kls ags 0 (? (ia32? g) (? va? (ngp g) srg 1 0) (sr6 && !(a64? g)) 1 0) 0 srk ())
       (pin g 'ezride (),
        bad? kr ? 'bad
          (: ov? (kent \ (<<kent = 'ov))
             ovr (: (go1 l1 acc1) (!(two? l1) ? acc1
                                     (go1 >l1 (ov? <l1 ? (<l1 . acc1) acc1)))
                    (go1 kr ()))                          ; overflow entries, reversed (deepest pushes first)
             rgr (: (go2 l2 acc2) (!(two? l2) ? acc2
                                     (go2 >l2 (elem <<<l2 '(g g2 gw g4 gn x x2 p2 ezd s sn sa) ?
                                                      (<l2 . acc2) acc2)))
                    (go2 kr ()))                          ; pushing register entries, reversed (pops run forward)
             (pushcat l3 acc3) (!(two? l3) ? acc3 (pushcat >l3 (acc3 + <><l3)))
             ; an arm double pops straight into its f-register off sp; x64 stages through r0
             pops (: (go4 l4 acc4)
                      (!(two? l4) ? acc4
                         (<<l4 @ kc
                            (go4 >l4 (elem <kc '(ov ez ezm ezd ezx) ? acc4 (acc4 +
                                      (<kc @ 'g (spop (argr g <>kc))
                                       'gw   ; a wide value: lo then hi off one cell
                                        [['ld (argr g <>kc) 'sp 0] ['ld (argr g (<>kc + 1)) 'sp 8] '(add sp sp 16)]
                                       'g2   ; the t32 pair: both words off one cell
                                        [['ld (argr g <>kc) 'sp 0]
                                           ['ld (argr g (<>kc + 1)) 'sp 4]
                                           '(add sp sp 16)]
                                       'gn   ; an i386 struct's n words off one cell, in argument order
                                        (catmap (j \ [['ld (argr g (<>kc + j)) 'sp (4 * j)]]) ^(<>>kc)
                                         + '((add sp sp 16)))
                                       'g4   ; the v6-M whole-composite quad: r0-r3 off one cell
                                        '((ld r0 sp 0) (ld r1 sp 4)
                                           (ld r2 sp 8) (ld r3 sp 12)
                                           (add sp sp 16))
                                       'x2   ; the struct pair: re then im (a natural 16-byte cell)
                                        (arm? g ?
                                           [['ldsd (xmmreg <>kc) 'sp 0] ['ldsd (xmmreg (<>kc + 1)) 'sp 8]
                                            '(add sp sp 16)]
                                           ['(pop r0) ['movqxr (xmmreg <>kc) 'r0]
                                             '(pop r0) ['movqxr (xmmreg (<>kc + 1)) 'r0]])
                                       'p2   ; a general two-eightbyte struct: eb0 (top) then eb1, each into its gp/xmm target
                                        (a8? g ?
                                           ((<>kc @ 'g [['ld (argr g <>>kc) 'sp 0]] [['ldsd (xmmreg <>>kc) 'sp 0]])
                                            + (<>>>kc @ 'g [['ld (argr g <>>>>kc) 'sp 8]] [['ldsd (xmmreg <>>>>kc) 'sp 8]])
                                            + '((add sp sp 16)))
                                           ((<>kc @ 'g [['pop (argr g <>>kc)]] ['(pop r0) ['movqxr (xmmreg <>>kc) 'r0]])
                                            + (<>>>kc @ 'g [['pop (argr g <>>>>kc)]] ['(pop r0) ['movqxr (xmmreg <>>>>kc) 'r0]])))
                                       's    ; a float: the cell's binary32 word into its slot
                                        [['ld 'r12 'sp 0] ['movsnxr <>kc 'r12] '(add sp sp 16)]
                                       'sa   ; an a64 float HFA's n words into s registers k.., off one cell
                                        (catmap (j \ [['ldss (xmmreg (<>kc + j)) 'sp (4 * j)]]) ^(<>>kc)
                                         + '((add sp sp 16)))
                                       'sn   ; n float words into n consecutive slots, off the same cell
                                        (catmap (i \ [['ld 'r12 'sp (4 * i)] ['movsnxr (<>kc + i) 'r12]]) ^(<>>kc)
                                         + '((add sp sp 16)))
                                       (arm? g ? [['ldsd (xmmreg <>kc) 'sp 0] '(add sp sp 16)]   ; a lone double
                                          (spop 'r0 + [['movqxr (xmmreg <>kc) 'r0]]))))))))
                     (go4 kr ()))
             nxmm (: (go5 l5 n5) (!(two? l5) ? n5
                                    (go5 >l5 (: ce <<l5 kk <ce
                                                     (kk @ 'x (n5 + 1) 'ezx (n5 + 1) 'x2 (n5 + 2)
                                                           'p2 (n5 + (ce 1 = 'x) + (ce 3 = 'x))
                                                           n5))))
                     (go5 kr 0))
             ; slots, not entries: ('ov off n) carries a slot count (bytes on ilp32, sized by ovblk).
             ; a64/riscv's block spans to its highest slot's end, past a wide pair's alignment gap
             nov (: (go8 l8 n8) (!(two? l8) ? n8
                                   (<<l8 @ ce
                                      (: n (two? >>ce ? <>>ce 1)
                                         (go8 >l8 (a8? g ? (max n8 (<>ce + n)) (n8 + n))))))
                    (go8 ovr 0))
             padn (nov & 1 = 1 ? 8 0)               ; keep sp 16-aligned across the overflow block
             ; ilp32 slots are byte offsets: the block spans to the highest end, rounded to 8 (i386 16)
             ovblk (ilp32? g ?
                      (: (go9 l9 m9) (!(two? l9) ? (aup m9 (ia32? g ? 16 8))
                                        (: ce <<l9
                                           e9 (<ce @ 'ov (<>ce + (two? >>ce ? <>>ce 4)) 0)
                                           (go9 >l9 (m9 < e9 ? e9 m9))))
                         (go9 kr srk))
                      (8 * nov + padn))
             ; x64 pads then pushes; a64/t32/i386 allocate the block up front and the ov forms store into it
             pad (arm? g || ia32? g ? (0 < ovblk ? [['sub 'sp 'sp ovblk]])
                    (0 < padn ? [['sub 'sp 'sp padn]]))
             clean (0 < ovblk ? [['add 'sp 'sp ovblk]])
             pf (pad + pushcat ovr () + pushcat rgr ())
             ; al = #xmm after the pops (r0 is no x64 arg register); on arm r0 is arg 0, so no al there
             setal (va? && !(arm? g) && !(ia32? g) && !(x86k? g 'nal) ? [['li 'r0 nxmm]])
             ; caller-saved homes spill before the pops and reload after the clean, filtered to the
             ; statement's wrapset (g 'stwrap). a wasm call writes only argument registers
             hs (: h9 (g 'homes) w9 (peep g 'stwrap 'all)
                   h8 (w9 @ 'all h9 (filter (h2 \ elem <>>h2 w9) h9))
                   (wasm? g ? (filter (h2 \ elem <h2 '(r0 r1 r2 r3 r4 r5 r6 r7)) h8) h8))
             (fh? p2) (elem <p2 (ffile g))           ; an xmm home wraps through its own pair
             spills (foldl (a2 \ p2 \ a2 + [(fh? p2 ? ['stsd 'r4 <>p2 <p2] ['st 'r4 <>p2 <p2])]) () hs)
             relods (foldl (a2 \ p2 \ a2 + [(fh? p2 ? ['ldsd <p2 'r4 <>p2] ['ld <p2 'r4 <>p2])]) () hs)
             ; the targeted emissions, after the spills and before the pops: an 'ezm home mov
             ; demotes to its spill-slot load when another targeted arg writes that home
             ezt (: (go6 l6 a6) (!(two? l6) ? a6
                                   (go6 >l6 (<<l6 @ kc
                                             (elem <kc '(ez ezm) ?
                                              (argr g <>kc . a6) a6))))
                    (go6 kr ()))
             ezf (: (go7 l7 a7) (!(two? l7) ? a7
                                   (go7 >l7
                                        (<<l7 @ kc
                                           (? (<kc = 'ez || <kc = 'ezx) (a7 + <><l7)
                                              !(<kc = 'ezm) a7
                                              (<>>kc @ rH
                                                 (elem rH ezt && rH != argr g <>kc ?
                                                  (a7 + <>><l7)
                                                  (a7 + <><l7)))))))
                    (go7 kr ()))
             (dir ?
                 (: ; v6-M: a double result arrives in r0:r1, a float in r0; either lands on f0
                    fres (? (ia32? g) (st0in g ret)                       ; i386: st(0) into f0
                            (n32? g ret) (v6m? g ? '((movdxr f0 r0)) ())       ; binary32 as is (v6-M: in r0)
                            ((t32f? g || f32abi? g) && ret = 'float) '((cvtss2sd f0 f0))   ; the result is binary32 in s0
                            !(v6m? g && flo? ret) ()
                            (ret = 'float) '((movqxr f0 r0) (cvtss2sd f0 f0))
                            '((movqxr f0 r0)))
                    ; the sret pointer rides the first arg register (a64: x8); the temp's address answers
                    srin (sr6 ? (srpass g sroff srg))
                    srout (sr6 ? (srback g sroff srg))
                    (mkv ret 'r0 (pf + spills + ezf + pops + setal + srin + [['call (intern <>hd)]] + fres + rext g ret + pairin g ret + srout + clean + relods)))
                (: hr (cgexpr g env hd ())                   ; a function-pointer value: park (x64 rbx; a64 x15), callr
                   pk (pkr g)
                   fres (? (ia32? g) (st0in g (fnret (vty hr)))
                           (n32? g (fnret (vty hr))) (v6m? g ? '((movdxr f0 r0)) ())
                           ((t32f? g || f32abi? g) && fnret (vty hr) = 'float) '((cvtss2sd f0 f0))
                           !(v6m? g && flo? (fnret (vty hr))) ()
                           (fnret (vty hr) = 'float) '((movqxr f0 r0) (cvtss2sd f0 f0))
                           '((movqxr f0 r0)))
                   (? (bad? hr) 'bad
                      ; t32: r12 is the far-mem scratch, so the park rides a frame slot, r12 reloaded last
                      (t32? g)
                       (ntmp g 'long @ pko
                          (mkv (fnret (vty hr)) 'r0 (pf + tor0 g hr + [['st 'r4 pko 'r0]] +
                                    spills + ezf + pops + setal + (sr6 ? (srpass g sroff srg) ()) + [['ld pk 'r4 pko] ['callr pk]]
                                    + fres + (sr6 ? (srback g sroff srg) ()) + clean + relods)))
                      ; i386: a pointer off a global is called where it lies
                      (ia32? g && two? (gword (vfs hr)))
                       (mkv (fnret (vty hr)) 'r0 (pf + spills + ezf + pops + setal + (sr6 ? (srpass g sroff srg) ()) +
                                 [['callm 'rip (gword (vfs hr))]] + fres +
                                 rext g (fnret (vty hr)) + pairin g (fnret (vty hr)) + (sr6 ? (srback g sroff srg) ()) + clean + relods))
                      (mkv (fnret (vty hr)) 'r0 (pf + tor0 g hr + [['mov pk 'r0]] +
                                spills + ezf + pops + setal + (sr6 ? (srpass g sroff srg) ()) + [['callr pk]] + fres +
                                rext g (fnret (vty hr)) + pairin g (fnret (vty hr)) + (sr6 ? (srback g sroff srg) ()) + clean + relods))))))))
   ; the hidden result pointer, out and back: a register (a64 x8, else the first argument's), or on
   ; i386 the block's first word -- which the callee pops (ret $4), so the caller's block is 4 short
   (srpass g off rg) (ia32? g && !rg ? [['lea 'r1 'r4 off] ['st 'sp 0 'r1]] [['lea (srreg g) 'r4 off]])
   ; raw: the callee's pop is no IR form, so the passes' sp model never sees it
   (srback g off rg) ((ia32? g && !rg ? [['raw (m16b g + [131 236 4])]] ()) + [['lea 'r0 'r4 off]])   ; sub esp,4: the callee's ret $4
   ; i386's double <-> pair moves through a 16-byte cell: movqxr/movqrx name only the pair's low
   ; half, which copy and store forwarding would rewrite without its twin
   (qcell g fs)
    (!(ia32? g) ? fs
       (catmap (f \ (? (two? f && <f = 'movqxr)
                        [['sub 'sp 'sp 16] ['st 'sp 0 <>>f] ['st 'sp 4 <(qtwin <>>f)] ['ldsd <>f 'sp 0] ['add 'sp 'sp 16]]
                        (two? f && <f = 'movqrx)
                        [['sub 'sp 'sp 16] ['stsd 'sp 0 <>>f] ['ld <>f 'sp 0] ['ld <(qtwin <>f) 'sp 4] ['add 'sp 'sp 16]]
                        [f]))
               fs))
   ; i386 answers a float on x87's st(0) and gen keeps it in f0 (xmm0): an 8-byte cell under esp
   ; carries it across, each way, raw so no pass reads the cell (16-bit: 67 on memory, 66 on lea)
   (x87raw g fl in?)
    (: a (m16? g ? [103] ()) o (m16? g ? [102] ())
       lea (\ k (a + o + [141 100 36 k]))                          ; lea esp,[esp+k]
       (in? ? (lea 248 + a + [(fl ? 217 221) 28 36]                 ; fstp dword|qword [esp]
               + a + [(fl ? 243 242) 15 16 4 36] + lea 8)            ; movss|movsd xmm0,[esp]
          (lea 248 + a + [(fl ? 243 242) 15 17 4 36]                 ; movss|movsd [esp],xmm0
           + a + [(fl ? 217 221) 4 36] + lea 8)))                    ; fld dword|qword [esp]
   (st0in g ty) (ia32? g && flo? ty ? [['raw (x87raw g (ty = 'float) 1)]])
   ; an i386 long long arrives in edx:eax; gen's pair is r0:r1
   (pairin g ty) (? (ia32? g && (pair? g ty || cxf32? g ty)) [['mov 'r1 'r2]]
                    (a64? g && d128? ty) [['mov 'r2 'r1]])   ; AAPCS64's wide answer is x0:x1, the pair x0:x2
   ; C99 complex: a two-member struct. arithmetic parks each side in a double-pair temp (the other
   ; may call), f0..f3 carry (a.re a.im b.re b.im), and a fresh temp's address answers
   (cxb ty) (<>ty = "__cplx_float" ? 'float 'double)
   (cxf32? g ty) (ia32? g && gcplx? ty && cxb ty = 'float)     ; i386: a float complex returns on edx:eax
   ; eight zero bytes at base+o from a zeroed r2 (ilp32: two words)
   (z8 g b o) (ilp32? g ? [['st4 b o 'r2] ['st4 b (o + 4) 'r2]] [['st b o 'r2]])
   ; a double's sign bit flipped in place, through r0 (ilp32: the pair's high word)
   (dneg g fr) (ilp32? g ? [['movqrx 'r0 fr] '(li r2 0x80000000) '(xor r1 r1 r2) ['movqxr fr 'r0]]
                 [['movqrx 'r0 fr] '(li r1 0x8000000000000000) '(xor r0 r0 r1) ['movqxr fr 'r0]])
   ; a VLA ('varr elt dim-expr [idx]): a local's idx keys g 'vslots -> (ptrslot sizeslot);
   ; a pointee carries just the expr, re-evaluated at each scale site
   (gvarr? ty) (two? ty && <ty = 'varr)
   (varel ty) <>ty                             ; the element type (const-sized)
   (varn ty) <>>ty                             ; the dim expression (an AST)
   ; reader ops, not `at`: the laws cat gen.l without holo, where `at` is unbound
   (varix ty) <>>>ty                                ; a decl's slot index (4-long only)
   ; park a value rec as a double-pair temp -> (off forms srcty) | 'bad
   (cxpark g rv)
    (: off (ntmp g cxdty)
       ty (vty rv)
       (? (gcplx? ty)
           (cxb ty @ 'float
               [off (tor0 g rv +
                      ['(ldss f2 r0 0) '(cvtss2sd f2 f2) ['stsd 'r4 off 'f2]
                       '(ldss f2 r0 4) '(cvtss2sd f2 f2) ['stsd 'r4 (off + 8) 'f2]])
                 ty]
              [off (tor0 g rv +
                     ['(ldsd f2 r0 0) ['stsd 'r4 off 'f2]
                      '(ldsd f2 r0 8) ['stsd 'r4 (off + 8) 'f2]])
                ty])
          (stru? ty) 'bad
          [off (asflo g rv + [['stsd 'r4 off 'f0] '(li r2 0)] + z8 g 'r4 (off + 8))
            ty]))
   ; evaluate an expr and park it -> (off forms srcty) | 'bad
   (cxmat g env x)
    (: rl (matv g (clval g env x))
       rv (!(bad? rl) && stru? (vty rl) ? rl (cgexpr g env x ()))
       (bad? rv ? 'bad (cxpark g rv)))
   (cxload oa ob) [['ldsd 'f0 'r4 oa] ['ldsd 'f1 'r4 (oa + 8)]
                    ['ldsd 'f2 'r4 ob] ['ldsd 'f3 'r4 (ob + 8)]]
   (cxarith op)                                     ; f0..f3 = (a.re a.im b.re b.im) -> (re im) in (f0 f1)
    (op @ '+ '((addsd f0 f2) (addsd f1 f3))
          '- '((subsd f0 f2) (subsd f1 f3))
          '* '((movsd f4 f0) (movsd f5 f1)
               (mulsd f0 f2) (mulsd f5 f3) (subsd f0 f5)                 ; re = ac - bd
               (mulsd f4 f3) (mulsd f1 f2) (addsd f1 f4))                ; im = bc + ad
          '/ '((movsd f4 f2) (mulsd f4 f2)                               ; c^2 (an untyped divisor; a typed one calls __divdc3)
               (movsd f5 f3) (mulsd f5 f3) (addsd f4 f5)                 ; den = c^2 + d^2
               (movsd f5 f0) (mulsd f5 f2)                               ; ac
               (movsd f6 f1) (mulsd f6 f3) (addsd f5 f6)                 ; ac + bd
               (divsd f5 f4)                                             ; re
               (mulsd f1 f2) (mulsd f0 f3) (subsd f1 f0)                 ; bc - ad
               (divsd f1 f4) (movsd f0 f5))
          ())
   ; a real divisor divides each part, as gcc's lowering does
   (cxar op tb) (op = '/ && !(gcplx? tb) ? '((divsd f0 f2) (divsd f1 f2)) (cxarith op))
   ; the (f0 f1) result into a fresh rt-typed temp; the temp's address answers
   (cxout g rt fs)
    (: ro (ntmp g rt)
       st (cxb rt @ 'float
           (fstf g 'float 'r4 ro 'f0 + fstf g 'float 'r4 (ro + 4) 'f1)
           [['stsd 'r4 ro 'f0] ['stsd 'r4 (ro + 8) 'f1]])
       (mkv rt 'r0 (fs + st + [['lean 'r0 'r4 ro]])))
   ; the single twins: a float complex parks as its own 8 bytes and + - * run in singles, rounding
   ; as C's float does, and so does / by a real that is not a double
   (cxs? g ty) (gcplx? ty && cxb ty = 'float && f32v? g)
   (cxpark32 g rv)
    (: off (ntmp g (vty rv))
       [off (tor0 g rv + [['ldss 'f2 'r0 0] ['stss 'r4 off 'f2] ['ldss 'f2 'r0 4] ['stss 'r4 (off + 4) 'f2]]) (vty rv)])
   (cxload32 oa ob) [['ldss 'f0 'r4 oa] ['ldss 'f1 'r4 (oa + 4)] ['ldss 'f2 'r4 ob] ['ldss 'f3 'r4 (ob + 4)]]
   (cxarith32 g op)
    (op @ '+ '((addss f0 f2) (addss f1 f3))
          '- '((subss f0 f2) (subss f1 f3))
          '* ([[(x86? g ? 'movapd 'movss) 'f4 'f0] [(x86? g ? 'movapd 'movss) 'f5 'f1]] + '(
               (mulss f0 f2) (mulss f5 f3) (subss f0 f5)                 ; re = ac - bd
               (mulss f4 f3) (mulss f1 f2) (addss f1 f4)))               ; im = bc + ad
          '/ '((divss f0 f2) (divss f1 f2))
          ())
   ; a float complex left parks first, as singles; past the right's evaluation, a float complex right
   ; under + - * meets it in singles, else the pair loads widened onto the double lane
   (cgcx32 g env op a rhs)
    (cxpark32 g a @ pa
       (: rl (matv g (clval g env rhs))
          rv (!(bad? rl) && stru? (vty rl) ? rl (cgexpr g env rhs ()))
          (? (bad? rv) 'bad
             (op = '/ && !(stru? (vty rv)) && vty rv != 'double)
              (: ro (ntmp g (vty a)) oa <pa
                 (mkv (vty a) 'r0 (<>pa + asf32 g rv + [['movss 'f2 'f0] ['ldss 'f0 'r4 oa] ['ldss 'f1 'r4 (oa + 4)]]
                                   + cxarith32 g op + [['stss 'r4 ro 'f0] ['stss 'r4 (ro + 4) 'f1] ['lean 'r0 'r4 ro]])))
             (cxs? g (vty rv) && op != '/ && two? (cxarith32 g op) ?
                (cxpark32 g rv @ mb
                   (: ro (ntmp g (vty a))
                      (mkv (vty a) 'r0 (<>pa + <>mb + cxload32 <pa <mb + cxarith32 g op
                                        + [['stss 'r4 ro 'f0] ['stss 'r4 (ro + 4) 'f1] ['lean 'r0 'r4 ro]]))))
                (cxpark g rv @ mb
                   (bad? mb ? 'bad
                      (: oa <pa ob <mb
                         rt (gcplx? <>>mb && cxb <>>mb = 'float ? '(struct "__cplx_float") cxdty)
                         (cxout g rt (<>pa + <>mb
                                      + [['ldss 'f0 'r4 oa] '(cvtss2sd f0 f0) ['ldss 'f1 'r4 (oa + 4)] '(cvtss2sd f1 f1)
                                         ['ldsd 'f2 'r4 ob] ['ldsd 'f3 'r4 (ob + 8)]]
                                      + cxar op <>>mb)))))))))
   (cgcx g env op a rhs)                            ; the left already evaluated (a value rec)
    (!(x86? g || a64? g || t32f? g && !(sp64? g)) ?
        (nolane g "no lane for C99 complex arithmetic\(ontgt g)")
       (cxs? g (vty a) && two? (cxarith op)) (cgcx32 g env op a rhs)
       (cxarith op @ arith
          (!(two? arith) ? 'bad
             (cxpark g a @ pa
                (bad? pa ? 'bad
                   (cxmat g env rhs @ mb
                      (bad? mb ? 'bad
                         (: tb <>>mb
                            rt (gcplx? (vty a) && cxb (vty a) = 'float &&
                                gcplx? tb && cxb tb = 'float ?
                                  '(struct "__cplx_float") cxdty)
                            (cxout g rt (<>pa + <>mb + cxload <pa <mb + cxar op tb))))))))))
   ; the rotate idiom (x >> n) | (x << (W - n)), x an unsigned W-bit pure operand: one rotate.
   ; a rotl count rides negated (the count reads mod W)
   (rotp? e)                                        ; pure: safe to evaluate once for the source's twice
    (e @ ((k . _) && elem k '(num flo flof str var)) 1
         ((k . x . _) && elem k '(deref dot moor addr)) (rotp? x)
         ('cast _ x) (rotp? x)
         ('bin _ a b) (rotp? a && rotp? b)
         ('un _ x) (rotp? x)
         ())
   (rotty g env e)                                  ; the operand's declared type, by static peek
    (e @ ('var nm) (vent g env nm @ en (bad? en ? () <>>en))
         ('cast . ty . _) ty
         ('deref p) (rotty g env p @ t (? (ptr? t) <>t (arr? t) <>t ()))
         ('bin op x y && elem op '(+ -))         ; index arithmetic keeps the ptr/arr side's type
          (rotty g env x @ a
             (ptr? a || arr? a ? a
                (rotty g env y @ b (ptr? b || arr? b ? b)))))
   (rotw g env e)                                   ; -> 32 | 64 | (): the unsigned rotate width; ilp32's long long is a pair
    (rotty g env e @ 'uint 32 'ulong (ilp32? g ? 32 64) 'ullong (ilp32? g ? () 64))
   (rotk g e)
    (knum g e @ k (two? k ? <k (cfold !(ilp32? g) e)))
   (rotc? g w big n)                                ; big reads (W - n), n pure and shared
    (big @ ('bin '- wide sub)
             (rotk g wide @ kb
                (charm? kb && kb = w && sub = n && rotp? n)))
   (cgrimm g env x w c wnt)                         ; the immediate rotate: mirror of the constant shift
    (cgexpr g env x () @ xv
       (bad? xv ? 'bad
          (: rt (w @ 32 'uint 'ulong)
             iop (w @ 32 'ror4 'ror)
             (wr? g (vreg xv) ?
                (mkv rt (vreg xv) (vfs xv + [[iop (vreg xv) c]]))
                (wnt || rdst g (vreg xv) @ rd
                   (mkv rt rd (vfs xv + [['mov rd (vreg xv)] [iop rd c]])))))))
   (cgrvar g env x w ce ng wnt)                     ; the register-count rotate: mirror of the variable shift
    (cgexpr g env x () @ xv
       (bad? xv ? 'bad
          (: cv (cgexpr g env ce ())
             ra (vreg xv)
             (bad? cv ? 'bad
                (: rt (w @ 32 'uint 'ulong)
                   vop (w @ 32 'rorv4 'rorv)
                   (!(elem ra '(r0 r1 r2 r3)) && !(callish? ce) && !(abl? g 'shv2) ?
                      (: bf (tor0 g cv)
                         rd (wr? g ra ? ra (wnt || rdst g ra @ w9 (w9 = 'r1 ? (rdst g ra) w9)))
                         (mkv rt rd (vfs xv + bf + ['(mov r1 r0)] + (ng ? '((neg r1))) +
                                     (rd = ra ? () [['mov rd ra]]) + [[vop rd 'r1]])))
                      (: af (tor0 g xv)
                         bf (tor0 g cv)
                         (mkv rt 'r0 (af + cshut g bf + (ng ? '((neg r1))) + [[vop 'r0 'r1]])))))))))
   (cgror g env L R wnt)                            ; -> tuple | 'bad | 'no (the general lane stands)
    (!(rot4? g) ? 'no
       (: a (two? L && <L = 'bin && elem <>L '(shl shr) ? L)
          b (two? R && <R = 'bin && elem <>R '(shl shr) ? R)
          (!(two? a) || !(two? b) || <>a = <>b ? 'no
             (: s (<>a @ 'shr a b)            ; the shr side: a rotate is ror by its count
                l (<>a @ 'shr b a)
                x <>>s
                (!(<>>l = x) || !(rotp? x) ? 'no
                   (rotw g env x @ w
                      (!w ? 'no
                         (: cs <>>>s cl <>>>l
                            ks (rotk g cs) kl (rotk g cl)
                            (? (charm? ks && charm? kl)
                                (ks + kl = w && 0 < ks && ks < w ?
                                   (cgrimm g env x w ks wnt) 'no)
                               (charm? ks || charm? kl) 'no
                               (rotc? g w cl cs) (cgrvar g env x w cs () wnt)   ; rotr: ror by the shr count
                               (rotc? g w cs cl) (cgrvar g env x w cl 1 wnt)    ; rotl: ror by the negated shl count
                               'no)))))))))
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
   (cgbin g env e wnt)
    (: gz9 (<>e = '| ? (gather g env e))
       (gz9 ? (cgexpr g env gz9 wnt) (cgbin0 g env e wnt)))
   (cgbin0 g env e wnt)
    (: op <>e
       lhs <>>e rhs <>>>e
       ; a load-shaped left (dot/moor/deref) aims at a pool park, one per spine or the pool drains;
       ; a call, a shift or a constant right bars it
       pk (!(two? lhs && elem <lhs '(dot moor deref)) ||
           callish? lhs || callish? rhs ||
           elem op '(shl shr) || two? (knum g rhs) ? ()
             (ralloc g))
       a (cgexpr g env lhs pk)
       (pk && !(!(bad? a) && rpeq? g (vreg a) pk) ? (rfree g pk),
        (? (bad? a) 'bad
           (gcplx? (vty a)) (cgcx g env op a rhs)    ; a complex left (parse lifted a real right already)
           ; a variable shift count is pinned to r1 (holo's contract)
           (elem op '(shl shr) && pair? g (vty a))    ; a pair shift keeps the left type
            (: kind (? (op = 'shl) 'shl (usg? (vty a)) 'shr 'sar)
               kc (knum g rhs)
               (two? kc ?
                   (mkv (vty a) 'r0 (tor0 g a + pshiftc kind <kc))
                  (cgexpr g env rhs () @ b
                     (bad? b ? 'bad
                        (mkv (vty a) 'r0 (tor0 g a + spush2 +
                                          tor0 g b + '((mov r2 r0)) + spop2 'r0 'r1 +
                                          pshiftv g kind))))))
           (elem op '(shl shr) && d128? (vty a))          ; a wide shift keeps the left type
            (!(w128? g) ? (no128 g)
               (: kind (? (op = 'shl) 'shl128 (usg? (vty a)) 'shr128 'sar128)
                  vknd (? (op = 'shl) 'shl128v (usg? (vty a)) 'shr128v 'sar128v)
                  kc (knum g rhs)
                  (two? kc ?
                      (? (<kc < 0 || 127 < <kc) 'bad
                         (<kc = 0) (mkv (vty a) 'r0 (tor0 g a))
                         (mkv (vty a) 'r0 (tor0 g a + [[kind <kc]])))
                     (cgexpr g env rhs () @ b
                        (bad? b ? 'bad
                           (mkv (vty a) 'r0 $
                            tor0 g a + wpush g + tor0 g b +
                             (t32w? g ? ('((mov r12 r0)) + wld g 'sp 0)       ; the four-word face counts in r12
                                '((mov r1 r0) (ld r0 sp 0) (ld r2 sp 8))) +   ; count -> cl, the pair back
                             wdrop + [[vknd]]))))))
           (elem op '(shl shr))
            (: uL (usg? (vty a))                             ; unsigned: a logical >>
               ; << carries out of a 32-bit unsigned like + - * do, so it re-narrows; >> stays inside a canonical value
               u32 (op = 'shl && u32? g (vty a))
               s32 (s32bin? g (vty a) 'int)                 ; ..and under -fwrapv an int's sign-extends
               (nar r) (? u32 [['zx4 r]] (s32 && op = 'shl) [['sx4 r]] ())
               rt (? (u32? g (vty a)) 'uint s32 'int uL 'ulong 'long) ; the shift result keeps the left operand's type
               iop (op = 'shl ? 'shl (uL ? 'shr 'sar))
               vop (op = 'shl ? 'shlv (uL ? 'shrv 'sarv))
               kc (knum g rhs)
               (two? kc ?
                   (wr? g (vreg a) ?
                      (mkv rt (vreg a) (vfs a + [[iop (vreg a) <kc]] + nar (vreg a)))
                      (wnt || rdst g (vreg a) @ rd    ; a borrowed home shifts a copy (no 3-address shift)
                         (mkv rt rd (vfs a + [['mov rd (vreg a)] [iop rd <kc]] + nar rd))))
                  (: b (cgexpr g env rhs ())
                     ra (vreg a)
                     (? (bad? b) 'bad
                        ; a left in a register that a call-free count leaves alone shifts there;
                        ; only the count takes the protocol
                        (!(elem ra '(r0 r1 r2 r3)) && !(callish? rhs) && !(abl? g 'shv2))
                         (: bf (tor0 g b)
                            rd (wr? g ra ? ra (wnt || rdst g ra @ w9 (w9 = 'r1 ? (rdst g ra) w9)))
                            (mkv rt rd (vfs a + bf + ['(mov r1 r0)] + (rd = ra ? () [['mov rd ra]]) +
                                        [[vop rd 'r1]] + nar rd)))
                        (: af (tor0 g a)
                           bf (tor0 g b)
                           (mkv rt 'r0 (af + cshut g bf + [[vop 'r0 'r1]] + nar 'r0)))))))
           (: ta (vty a)
              ; a constant right takes the immediate lane; a constant left swaps or mirrors (rflip)
              imr (knum g rhs @ kr
                     (!(flo? ta) && two? kr && !(ptr? ta && gvarr? <>ta) ?
                        (immop g op a ta <kr <>kr wnt) 'no))
              (imr != 'no ? imr
                 (: kl (elem op '(+ * & | ^ eq ne lt le gt ge) ? (knum g lhs))
                    iml? (!(flo? ta) && two? kl)
                    ah (iml? || flo? ta || callish? rhs || llt? ta || d128? ta ? 'sh
                          (vpark g env lhs a))       ; a pair lhs keeps the shuttle (no pool park)
                    ; a d128 left parks in two pool registers before the right evaluates; a callish right
                    ; keeps the cell, and / % too (the divide dance owns it)
                    wpk (wreg? g && d128? ta && !(callish? rhs) &&
                         elem op '(+ - * & | ^ eq ne lt le gt ge) ?
                           (ralloc g @ rl
                              (!rl ? ()
                                 (ralloc g @ rh
                                    (rh ? [rl rh] (rfree g rl, ()))))))
                    b (cgexpr g env rhs ())
                    (bad? b ? 'bad
                       (: tb (vty b)
                          ta9 (numty9 lhs ta)   ; C's type for a literal, read through
                          tb9 (numty9 rhs tb)   ; its written face (-1, ~0)
                          av (ah @ 'sh a ah)
                          ; the memory shuttle (shut1): left in r1, right in r0
                          (shut z9)
                           (: mid (: af9 (tor0 g av)       ; built first (the standing free order); the ride drops it
                                     bf (tor0 g b)
                                     (shut1 g av af9 bf))
                              back '((mov r0 r1))
                              pa (ptr? ta) pb (ptr? tb)
                              unsg (cmpu g ta9 tb9)                      ; divide and compare take the common type's signedness
                              u32 (u32bin? g ta9 tb9)                  ; a 32-bit unsigned result wraps
                              nar (? u32 '((zx4 r0)) (s32bin? g ta9 tb9 && elem op '(+ - *)) '((sx4 r0)) ())   ; the shuttle always lands in r0 (back)
                              nty (rbin g ta9 tb9)                      ; C's own result type, as every lane types it
                              (? (d128? ta || d128? tb)
                                  ; the wide shuttle: left in its cell, right on r2:r0
                                  (? !(w128? g) (no128 g)
                                     (pa || pb) 'bad
                                     (: rt (wbin ta tb)
                                        w? (two? wpk)
                                        ; a right read off its home pair is the op's own operand pair (these commute)
                                        hb (w? && d128? tb && elem op '(+ * | & ^ eq ne) ?
                                              (vfs b @ (('mov 'r2 H) ('mov 'r0 L)) [L H] ()))
                                        pk (hb || wpk)
                                        midw (? hb (as128 g av)
                                                w? (as128 g av + ([['mov <wpk 'r0] ['mov <>wpk 'r2]] + as128 g b))
                                                (as128 g av + (wpush g + as128 g b)))
                                        res (op @
                                             '+ (mkv rt 'r0 (midw + (w? ? [['a128r <pk <>pk]] ('((a128 sp)) + wdrop))))
                                             '- (mkv rt 'r0 (midw + (w? ? [['s128r <wpk <>wpk]] ('((s128 sp)) + wdrop))))
                                             '* (: zl (d128? ta ? (zext128? (vfs av)) (usg? ta9 || ptr? ta9))
                                                   zr (d128? tb ? (zext128? (vfs b)) (usg? tb9 || ptr? tb9))
                                                   (zl && zr && wreg? g ?      ; hi halves zero: one mulq, the park needs only lo
                                                      (mkv rt 'r0 (w? ? (as128 g av + [['mov <wpk 'r0]] + (tor0 g b + [['mw128r <wpk]]))
                                                                    (as128 g av + wpush g + tor0 g b + wop g 'mw128 + wdrop)))
                                                      (mkv rt 'r0 (midw + (w? ? [['m128r <pk <>pk]] (wop g 'm128 + wdrop))))))
                                             ('| || '& || '^)
                                              (irop op @ w9
                                                 (mkv rt 'r0 (midw + (? w? [[w9 'r0 'r0 <pk] [w9 'r2 'r2 <>pk]]
                                                                (t32w? g) (catmap (k \ [['ld 'r12 'sp (4 * k)] [w9 ('(r0 r1 r2 r3) k) ('(r0 r1 r2 r3) k) 'r12]]) ^4 + wdrop)
                                                                (['(ld r1 sp 0) [w9 'r0 'r0 'r1] '(ld r1 sp 8) [w9 'r2 'r2 'r1]] + wdrop)))))
                                             ('eq || 'ne || 'lt || 'le || 'gt || 'ge)
                                              (mkv 'long 'r0 (midw + (w? ? [['c128r (scc op (rt = 'u128)) <pk <>pk]]
                                                                ([['c128 (scc op (rt = 'u128)) 'sp]] + wdrop))))
                                             ('/ || '%)
                                              ; u128 by a divisor with a provably-zero high half only
                                              (: zr (? (d128? tb) (zext128? (vfs b))
                                                       (two? rhs && <rhs = 'num && 0 <= <>rhs) 1
                                                       (usg? tb9 || ptr? tb9))
                                                 (!zr || rt != 'u128 ? 'bad
                                                    (mkv rt 'r0 (midw + wop g (op @ '/ 'dv128 'rm128) + wdrop))))
                                             'bad)
                                        (w? ? (rfree g <wpk, rfree g <>wpk),
                                         res)))
                                 (ilp32? g && !(pa || pb) && (llt? ta || llt? tb))
                                  ; the pair shuttle: both sides widen to r0:r1, the left pops to r2:r3
                                  (: mid2 (asll g av + spush2 + asll g b + spop2 'r2 'r3)
                                     ; helper staging: the numerator on r0:r1, the denominator r2:r3
                                     mid2d (asll g av + spush2 + asll g b
                                            + '((mov r2 r0) (mov r3 r1)) + spop2 'r0 'r1)
                                     rt (ubin !(ilp32? g) ta tb)
                                     ; i386's helpers are cdecl: the four words on the stack, the answer edx:eax
                                     (cdh h) (mid2d + [['sub 'sp 'sp 16] ['st 'sp 0 'r0] ['st 'sp 4 'r1] ['st 'sp 8 'r2] ['st 'sp 12 'r3]
                                                       ['call h] ['add 'sp 'sp 16] ['mov 'r1 'r2]])
                                     (op @ '+ (mkv rt 'r0 (mid2 + '((adds r0 r2 r0) (adc r1 r3 r1))))
                                           '- (mkv rt 'r0 (mid2 + (ia32? g ? '((subs r2 r2 r0) (sbc r3 r3 r1) (mov r0 r2) (mov r1 r3))
                                                                         '((subs r0 r2 r0) (sbc r1 r3 r1)))))
                                           '*
                                           (? (v6m? g)   ; no umull/mla on v6-M: the runtime's helper
                                              (mkv rt 'r0 (mid2 + '((call __aeabi_lmul))))
                                              ; i386: the cross terms by imul, lo*lo by mul, the sum into hi
                                              (ia32? g)
                                              (mkv rt 'r0 (mid2 + [['imul 'r3 'r3 'r0] ['imul 'r1 'r1 'r2] ['add 'r3 'r3 'r1]
                                                                   ['raw (m16b g + [247 226])] ['add 'r1 'r2 'r3]]))
                                              (mkv rt 'r0 (mid2 + '((imul r3 r3 r0) (mla r3 r2 r1 r3)
                                                                    (umull r0 r12 r2 r0) (add r1 r12 r3)))))
                                          ('| || '& || '^)
                                           (irop op @ w9
                                              (mkv rt 'r0 (mid2 + [[w9 'r0 'r2 'r0] [w9 'r1 'r3 'r1]])))
                                          '/
                                           ; __divdi3, not aeabi's uldivmod (two answers). the backend's expansion is
                                           ; unsigned, so a signed pair divide takes the runtime's helper
                                           (? (ia32? g) (mkv rt 'r0 (cdh (unsg ? '__udivdi3 '__divdi3)))
                                              (v6m? g || !unsg)
                                              (mkv rt 'r0 (mid2d + [['call (unsg ? '__udivdi3 '__divdi3)]]))
                                              (mkv rt 'r0 (mid2 + '((udivll)))))
                                          '%
                                           (? (ia32? g) (mkv rt 'r0 (cdh (unsg ? '__umoddi3 '__moddi3)))
                                              (v6m? g || !unsg)
                                              (mkv rt 'r0 (mid2d + [['call (unsg ? '__umoddi3 '__moddi3)]]))
                                              (mkv rt 'r0 (mid2 + '((uremll)))))
                                          ('eq || 'ne || 'lt || 'le || 'gt || 'ge)
                                           (prel g op unsg @ cf
                                              (mkv 'long 'r0 (mid2 + <>cf + [['set <cf 'r0]])))
                                          'bad))
                                 (op = '+)
                                  ; ptr + idx: one leax at a machine scale, else imul/add; a VLA re-evaluates its dim
                                  (: (vlaidx vt pk ty)
                                      (: dv (cgexpr g env (varn vt) () @ de
                                                (bad? de ? 'bad
                                                   (tsz g (varel vt) @ es
                                                      (mid + pk + asint g de +
                                                       (1 < es ? (imby g 'r0 es)) +
                                                       spop 'r2 + '((imul r2 r2 r0)) +
                                                       spop 'r1 + '((add r1 r1 r2) (mov r0 r1))))))
                                         (bad? dv ? 'bad (mkv ty 'r0 dv)))
                                  (? (pa && pb) 'bad
                                     ; mid ran: ptr r1, idx r0 (or the reverse) park before the dim eval
                                     (pa && gvarr? <>ta) (vlaidx <>ta (spush 'r1 + spush 'r0) ta)
                                     (pb && gvarr? <>tb) (vlaidx <>tb (spush 'r0 + spush 'r1) tb)
                                     pa (tsz g <>ta @ sz
                                           (elem sz '(1 2 4 8) ?
                                              (mkv ta 'r0 (mid + [['leax 'r0 'r1 'r0 sz 0]]))
                                              (mkv ta 'r0 (mid + (1 < sz ? (imby g 'r0 sz)) +
                                                           ('((add r1 r1 r0)) + back)))))
                                     pb (tsz g <>tb @ sz
                                           (elem sz '(1 2 4 8) ?
                                              (mkv tb 'r0 (mid + [['leax 'r0 'r0 'r1 sz 0]]))
                                              (mkv tb 'r0 (mid + (1 < sz ? (imby g 'r1 sz)) +
                                                           ('((add r1 r1 r0)) + back)))))
                                     (mkv nty 'r0 (mid + '((add r1 r1 r0)) + back + nar))))
                                 (op = '-)
                                  (? (pa && pb)
                                      (tsz g <>ta = tsz g <>tb ?
                                         (tsz g <>ta @ esz
                                            (mkv 'long 'r0 (mid + '((sub r1 r1 r0)) +
                                                            (? (esz <= 1) back
                                                               (pow2? esz) (back + [['sar 'r0 (lg2 esz)]])
                                                               [['li 'r0 esz] '(div r1 r1 r0) '(mov r0 r1)]))))
                                         'bad)
                                     pa (mkv ta 'r0 (mid + (1 < tsz g <>ta ?
                                                          (imby g 'r0 (tsz g <>ta))) +
                                                     ('((sub r1 r1 r0)) + back)))
                                     pb 'bad
                                     (mkv nty 'r0 (mid + '((sub r1 r1 r0)) + back + nar)))
                                 (: tail (? (elem op '(* & | ^)) [[(irop op) 'r1 'r1 'r0]]
                                            ; a mixed int/uint divide runs at uint width: znrw first
                                            (op = '/) (znrw g ta9 tb9 'r1 'r0 + [[(unsg ? 'udiv 'div) 'r1 'r1 'r0]])
                                            (op = '%) (znrw g ta9 tb9 'r1 'r0 + [[(unsg ? 'urem 'rem) 'r1 'r1 'r0 'r3]])
                                            'bad)
                                    m32 (u32 && op = '*)              ; only the multiply here can carry
                                    (? !(bad? tail)
                                       (mkv (rbin g ta9 tb9) 'r0
                                            (mid + tail + back + (m32 ? nar)))
                                       (elem op '(eq ne lt le gt ge))
                                        (mkv 'long 'r0 (mid + znrw g ta9 tb9 'r1 'r0 +
                                                        ['(cmp r1 r0) ['set (scc op unsg) 'r0]]))
                                       'bad))))
                          iml (iml? && !(flo? tb) ? (immop g (rflip op) b tb <kl <>kl wnt) 'no)
                          (? (iml != 'no) iml
                             ((flo? ta || flo? tb) && (d128? ta || d128? tb))                ; wide meets double
                              (nolane g "a wide integer is not mixed with a double")
                             ; native floats: float meets float or an integer in single ops
                             (f32rel? g ta tb && elem op '(+ - * / lt le gt ge eq ne))
                              (: mid (fshuts g (asf32 g av) (asf32 g b))   ; f1 = left, f0 = right; relations as the double lane's
                                 (op @ '+ (mkv 'float 'r0 (mid + '((addss f0 f1))))
                                       '* (mkv 'float 'r0 (mid + '((mulss f0 f1))))
                                       '- (mkv 'float 'r0 (mid + '((subss f1 f0) (movsd f0 f1))))
                                       '/ (mkv 'float 'r0 (mid + '((divss f1 f0) (movsd f0 f1))))
                                       ('lt || 'le || 'gt || 'ge)
                                        (elem op '(lt le) @ swp
                                           (mkv 'long 'r0 (mid + [['ucomiss (swp ? 'f0 'f1) (swp ? 'f1 'f0)]
                                                                  ['set (? (elem op '(lt gt)) (arm? g ? 'gt 'above)
                                                                            (arm? g) 'ge 'ae) 'r0]])))
                                       'eq (mkv 'long 'r0 (mid + ('((ucomiss f1 f0)) + fsete)))
                                       (mkv 'long 'r0 (mid + ('((ucomiss f1 f0)) + fsetn)))))
                             (flo? ta || flo? tb)
                              ; the double lane: x64 arithmetic reads a simple right direct; else the
                              ; shuttle, f1 = left, f0 = right
                              (: af (asflo g av) bf (asflo g b)
                                 sim (fsel? g && elem op '(+ - * /) ? (fsimple g bf))
                                 ; a left that needs no park waits: + * read it direct, - / move the right
                                 ; to f1 and load the left on f0
                                 lf (two? sim || !(elem op '(+ - * /)) ? () (fleft g af))
                                 opn (op @ '+ 'addsd '- 'subsd '* 'mulsd 'divsd)
                                 mid (two? sim || two? lf ? () (fshut g af bf))
                                 (? (two? sim)
                                    (mkv 'double 'r0 (af + <sim + [[opn 'f0 <>sim]]))
                                    (two? lf)
                                    (mkv 'double 'r0
                                         (? (op = '- || op = '/) (bf + ['(movapd f1 f0) lf [opn 'f0 'f1]])
                                            (<lf = 'movapd) (bf + [[opn 'f0 (lf 2)]])
                                            (bf + [['ldsdl 'f1 (lf 2)] [opn 'f0 'f1]])))
                                 (op @ '+ (mkv 'double 'r0 (mid + '((addsd f0 f1))))
                                     '* (mkv 'double 'r0 (mid + '((mulsd f0 f1))))
                                     '- (mkv 'double 'r0 (mid + '((subsd f1 f0) (movsd f0 f1))))
                                     '/ (mkv 'double 'r0 (mid + '((divsd f1 f0) (movsd f0 f1))))
                                    ; NaN answers false for every relation but !=: x64's above/ae fail on it (cf=1), so
                                    ; lt/le compare swapped and eq/ne carry parity (fsete/fsetn)
                                    ('lt || 'le || 'gt || 'ge)
                                     (elem op '(lt le) @ swp
                                        (mkv 'long 'r0 (mid + [['ucomisd (swp ? 'f0 'f1) (swp ? 'f1 'f0)]
                                                               ['set (? (elem op '(lt gt)) (arm? g ? 'gt 'above)
                                                                         (arm? g) 'ge 'ae) 'r0]])))
                                    'eq (mkv 'long 'r0 (mid + ('((ucomisd f1 f0)) + fsete)))
                                    'ne (mkv 'long 'r0 (mid + ('((ucomisd f1 f0)) + fsetn)))
                                    'bad)))
                             ; the register lane: both values live, 3-address combine
                             (: pa (ptr? ta) pb (ptr? tb)
                                ; ptr + idx at a machine scale: one leax (reads both before writing, so any alias)
                                vpt (pa && gvarr? <>ta || pb && gvarr? <>tb)
                                lxsz (? !(op = '+) () (pa && pb) () vpt ()
                                        pa (tsz g <>ta @ s9 (elem s9 '(1 2 4 8) ? s9))
                                        pb (tsz g <>tb @ s9 (elem s9 '(1 2 4 8) ? s9)))
                                (? (ah = 'sh) (shut ())
                                   vpt (shut ())
                                   ((pa || pb) && !lxsz) (shut ())
                                   (ilp32? g && llt? tb) (shut ())       ; a pair right: the pair shuttle
                                   (d128? tb) (shut ())                ; a wide right: the wide shuttle
                                   lxsz
                                    (: rA (vreg ah) rB (vreg b)
                                       rd (wnt || rdst g rA)
                                       fs (vfs ah + vfs b
                                           + [['leax rd (pa ? rA rB) (pa ? rB rA) lxsz 0]])
                                       (rfree g rB, rpeq? g rd rA ? () (rfree g rA),
                                        mkv (pa ? ta tb) rd fs))
                                   (: rA (vreg ah) rB (vreg b)
                                      cunsg (cmpu g ta9 tb9)
                                      pre (vfs ah + vfs b)
                                      (? (elem op '(eq ne lt le gt ge))
                                          ; a mixed int/uint compare owes a zx4, and rA/rB may be homes: the shuttle owns the copies
                                          (two? (znrw g ta9 tb9 'r1 'r0) ? (shut ())
                                             (: rd (wnt || rdst g rA)   ; set runs after the cmp: rd may alias rB
                                                fs (pre + [['cmp rA rB] ['set (scc op cunsg) rd]])
                                                (rfree g rB, rpeq? g rd rA ? () (rfree g rA),
                                                 mkv 'long rd fs)))
                                         (elem op '(+ - * & | ^))
                                          (: iop2 (irop op)
                                             rd (wnt && !(rpeq? g wnt rB) ? wnt (rdst g rA))
                                             u32 (nar32 g op ta9 tb9 !(usg? ta9 && usg? tb9))
                                             ; holo reorders a commutative rd == rB; sub cannot, and a borrowed left with a dry pool lands rd on rB's r0
                                             (op = '- && rpeq? g rd rB ? (shut ())
                                                (pre + [[iop2 rd rA rB]] + (u32 ? [[u32 rd]]) @ fs
                                                   (rfree g rB, rpeq? g rd rA ? () (rfree g rA),
                                                    mkv (rbin g ta9 tb9) rd fs))))
                                         (shut ()))))))))))))))

   ; rbx is callee-saved and gen uses it (callr park, va_arg): every fn saves it at slot -8
   pro4 '((push r4) (mov r4 sp))                    ; the x64 frame link (unframe strips it; repack requires it)
   sav3 '(st r4 -8 r3)
   epi '((ld r3 r4 -8) (mov sp r4) (pop r4) (ret))
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
   sf-save '((sub sp sp 32) (st sp 0 r0) (st sp 4 r1) (st sp 8 r2) (st sp 12 r3))
   sf-rest '((ld r0 sp 0) (ld r1 sp 4) (ld r2 sp 8) (ld r3 sp 12) (add sp sp 32))
   (sf-slot r) (r @ 'r0 0 'r1 4 'r2 8 'r3 12 -1)
   ; v6-M: no fpu, so f0/f1/f15 live in the frame cells cgfn pinned (fc0/fc1/fc15); transfers are word
   ; moves through a saved low temp (r3, or r2 when the base is r3)
   (fcell g f) (f @ 'f0 (peep g 'fc0 0) 'f1 (peep g 'fc1 0)
                   'f15 (peep g 'fc15 0)    (scare 'soften6-freg f))
   (nxr r) (r @ 'r0 'r1 'r1 'r2 'r2 'r3 (scare 'soften6-pair r))
   (pl6 g f lo) (fcell g f @ c [['ld lo 'r4 c] ['ld (nxr lo) 'r4 (c + 4)]])   ; cell -> gp pair
   (ps6 g f lo) (fcell g f @ c [['st 'r4 c lo] ['st 'r4 (c + 4) (nxr lo)]])   ; gp pair -> cell
   (m2c g f base off)                                ; [base+off] -> cell (a softened ldsd)
    (: c (fcell g f) tmp (base @ 'r3 'r2 'r3) o2 (base @ 'sp (off + 16) off)
       ['(sub sp sp 16) ['st 'sp 0 tmp]
         ['ld tmp base o2] ['st 'r4 c tmp] ['ld tmp base (o2 + 4)] ['st 'r4 (c + 4) tmp]
         ['ld tmp 'sp 0] '(add sp sp 16)])
   (c2m g base off f)                                ; cell -> [base+off] (a softened stsd)
    (: c (fcell g f) tmp (base @ 'r3 'r2 'r3) o2 (base @ 'sp (off + 16) off)
       ['(sub sp sp 16) ['st 'sp 0 tmp]
         ['ld tmp 'r4 c] ['st base o2 tmp] ['ld tmp 'r4 (c + 4)] ['st base (o2 + 4) tmp]
         ['ld tmp 'sp 0] '(add sp sp 16)])
   (w2c g f base off)                                ; [base+off] -> cell low word (a softened ldss)
    (: c (fcell g f) tmp (base @ 'r3 'r2 'r3) o2 (base @ 'sp (off + 16) off)
       ['(sub sp sp 16) ['st 'sp 0 tmp]
         ['ld tmp base o2] ['st 'r4 c tmp]
         ['ld tmp 'sp 0] '(add sp sp 16)])
   (c2w g base off f)                                ; cell low word -> [base+off] (a softened stss)
    (: c (fcell g f) tmp (base @ 'r3 'r2 'r3) o2 (base @ 'sp (off + 16) off)
       ['(sub sp sp 16) ['st 'sp 0 tmp]
         ['ld tmp 'r4 c] ['st base o2 tmp]
         ['ld tmp 'sp 0] '(add sp sp 16)])
   ; one walker: v6m doubles live in frame cells, sp64's in d-registers (its f-memory ops stay)
   (soften g fs)
    (v6m? g @ w6
       (!(w6 || sp64? g) ? fs
          (: (gd d9 lo) (w6 ? (pl6 g d9 lo) [['movqrx lo d9]])   ; double -> the gp pair at lo
             (pd d9) (w6 ? (ps6 g d9 'r0) [['movqxr d9 'r0]])   ; the r0:r1 pair -> double
             (gs d9) (w6 ? [['ld 'r0 'r4 (fcell g d9)]]         ; single bits -> r0
                        [['stss 'sp 16 d9] '(ld r0 sp 16)])
             (ps d9) (w6 ? [['st 'r4 (fcell g d9) 'r0]]         ; r0 -> the single's home
                        ['(st sp 16 r0) ['ldss d9 'sp 16]])
             (mv dD dS)
              (w6 ? (: cd (fcell g dD) cs (fcell g dS)
                       ['(sub sp sp 16) '(st sp 0 r3)
                         ['ld 'r3 'r4 cs] ['st 'r4 cd 'r3]
                         ['ld 'r3 'r4 (cs + 4)] ['st 'r4 (cd + 4) 'r3]
                         '(ld r3 sp 0) '(add sp sp 16)])
                 ['(sub sp sp 16) ['stsd 'sp 0 dS] ['ldsd dD 'sp 0] '(add sp sp 16)])
             scc (w6 ? 'soften6-cc 'soften-cc)
             suc (w6 ? 'soften6-ucomisd 'soften-ucomisd)
             (go (f . r))
              (!(two? f) ? (f . go r)
                 (: op <f
                    h9 (sf-bin op)
                    (? h9                             ; (op fD fS): fD = fD op fS
                        (sf-save + gd <>f 'r0 +
                         gd <>>f 'r2 + [['call h9]] + pd <>f + sf-rest + go r)
                       (op = 'movsd) (mv <>f <>>f + go r)
                       (w6 && sf-bin1 op)            ; (op fD fS): single words through the helper
                        (sf-save + [['ld 'r0 'r4 (fcell g <>f)] ['ld 'r1 'r4 (fcell g <>>f)] ['call (sf-bin1 op)]]
                         + ps <>f + sf-rest + go r)
                       (w6 && elem op '(cvtsi2ss cvtui2ss))   ; (op fD rS)
                        (sf-slot <>>f @ sl
                           (sf-save + (sl < 0 ? [['mov 'r0 <>>f]] [['ld 'r0 'sp sl]])
                            + [['call (op = 'cvtsi2ss ? '__aeabi_i2f '__aeabi_ui2f)]] + ps <>f + sf-rest + go r))
                       (w6 && elem op '(cvttss2si cvttss2ui))   ; (op rD fS)
                        (sf-slot <>f @ sl
                           (sf-save + gs <>>f + [['call (op = 'cvttss2si ? '__aeabi_f2iz '__aeabi_f2uiz)]]
                            + (sl < 0 ? [['mov <>f 'r0]] [['st 'sp sl 'r0]]) + sf-rest + go r))
                       (w6 && op = 'movdxr) ([['st 'r4 (fcell g <>f) <>>f]] + go r)
                       (w6 && op = 'movss)
                        (['(sub sp sp 16) '(st sp 0 r3) ['ld 'r3 'r4 (fcell g <>>f)] ['st 'r4 (fcell g <>f) 'r3]
                          '(ld r3 sp 0) '(add sp sp 16)] + go r)
                       (w6 && op = 'movdrx) ([['ld <>f 'r4 (fcell g <>>f)]] + go r)
                       (w6 && op = 'ldsd) (m2c g <>f <>>f <>>>f + go r)
                       (w6 && op = 'stsd) (c2m g <>f <>>f <>>>f + go r)
                       (w6 && op = 'ldss) (w2c g <>f <>>f <>>>f + go r)
                       (w6 && op = 'stss) (c2w g <>f <>>f <>>>f + go r)
                       (w6 && op = 'movqrx) (pl6 g <>>f <>f + go r)
                       (w6 && op = 'movqxr) (ps6 g <>f <>>f + go r)
                       (elem op '(cvtsi2sd cvtui2sd))   ; (op fD rS)
                        (sf-slot <>>f @ sl
                           (sf-save +
                            (sl < 0 ? [['mov 'r0 <>>f]] [['ld 'r0 'sp sl]]) +
                            [['call (op = 'cvtsi2sd ? '__aeabi_i2d '__aeabi_ui2d)]] +
                            pd <>f +
                            sf-rest + go r))
                       (elem op '(cvttsd2si cvttsd2ui))   ; (op rD fS)
                        (sf-slot <>f @ sl
                           (sf-save + gd <>>f 'r0 +
                            [['call (op = 'cvttsd2si ? '__aeabi_d2iz '__aeabi_d2uiz)]] +
                            (sl < 0 ? [['mov <>f 'r0]] [['st 'sp sl 'r0]]) +   ; through the save slot: the restore lands it
                            sf-rest + go r))
                       (op = 'cvtss2sd)               ; (op fD fS): single bits in, a pair out
                        (sf-save + gs <>>f + '((call __aeabi_f2d)) + pd <>f + sf-rest + go r)
                       (op = 'cvtsd2ss)               ; (op fD fS): a pair in, the narrowed word home
                        (sf-save + gd <>>f 'r0 + '((call __aeabi_d2f)) + ps <>f + sf-rest + go r)
                       (op = 'ucomisd || w6 && op = 'ucomiss)   ; (sp64 keeps vcmp.f32 native)
                        (: args (op = 'ucomiss ?
                                   (sf-save + [['ld 'r0 'r4 (fcell g <>f)] ['ld 'r1 'r4 (fcell g <>>f)]])
                                   (sf-save + gd <>f 'r0 + gd <>>f 'r2))
                           cc9 (\ c (sf-cc c @ hs (op = 'ucomiss && two? hs ? [(sf-ccs <hs) <>hs] hs)))
                           n1 (two? r ? <r)
                           (? (two? n1 && <n1 = 'br)
                               (cc9 <>n1 @ hs
                                  (two? hs ? 0 (scare scc n1),
                                   args + [['call <hs] '(cmp r0 0)] + sf-rest + [['br <>hs <>>n1]] + go >r))
                              (two? n1 && <n1 = 'set)
                               (: n2 (two? >r ? <>r)
                                  n3 (two? >r && two? >>r ? <>>r)
                                  dance (two? n2 && <n2 = 'set && elem <>n2 '(p np) &&
                                         two? n3 && elem <n3 '(and or))
                                  hs (cc9 <>n1)
                                  (two? hs ? 0 (scare scc n1),
                                   args + [['call <hs] '(cmp r0 0)] + sf-rest + [['set <>hs <>>n1]] + go (dance ? >>>r >r)))
                              (scare suc n1)))
                       (f . go r))))
             (go fs))))
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
   (rdmk _)
    (: t {}
       (arm ops a) (map (o \ (peep t o 'none = 'none ? (pin t o a) 0)) ops)
       _ (arm '(li) (g \ f \ [() [<>f] 1]))
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
       _ (arm leaops (g \ f \ [[<>>f] [<>f] 1]))
       _ (arm xops (g \ f \ [[<>>f <>>>f] [<>f] 1]))
       _ (arm x4ops (g \ f \ [[<>f <>>f <>>>f] [<>f] 1]))
       _ (arm m4ops (g \ f \ [[<>f <>>f] [<>f] 1]))
       _ (arm '(la laa) (g \ f \ [() [<>f] 1]))
       _ (arm '(set) (g \ f \ [() [<>>f] 1]))
       _ (arm '(cmov) (g \ f \ [[<>>f <>>>f] [<>>f] 1]))
       _ (arm '(cmp test) (g \ f \ [(rg1 <>f + rg1 <>>f) () ()]))
       _ (arm unops (g \ f \ [[<>f] [<>f] 1]))
       ; vmov Df, Rlo, Rlo+1 names only the low half: qtwin spells the high one, else deaddef kills a
       ; live read and the forwarders keep a stale def
       _ (arm '(movqxr) (g \ f \ [([<>>f] + (ilp32? g ? (qtwin <>>f) ())) () ()]))
       _ (arm '(movqrx) (g \ f \ [() ([<>f] + (ilp32? g ? (qtwin <>f) ())) 1]))
       ; movsnxr's s-slot write is a side effect nothing here sees: never droppable
       _ (arm '(movsnxr) (g \ f \ [[<>>f] () ()]))
       _ (arm '(movsnrx) (g \ f \ [() [<>f] 1]))
       _ (arm '(cvtsi2sd cvtui2sd cvtsi2ss cvtui2ss movdxr) (g \ f \ [[<>>f] () ()]))
       _ (arm '(cvttsd2si cvttsd2ui cvttss2si cvttss2ui) (g \ f \ [() [<>f] ()]))
       _ (arm '(movdrx) (g \ f \ [() [<>f] 1]))
       _ (arm fldops (g \ f \ [[<>>f] () ()]))
       _ (arm fstops (g \ f \ [[<>f] () ()]))
       _ (arm xmmops (g \ f \ [() () ()]))
       _ (arm divops (g \ f \ [(rg1 <>>f + rg1 <>>>f) '(r0 r1 r2 r3) ()]))
       _ (arm llops (g \ f \ ['(r0 r1 r2 r3) '(r0 r1 r2 r3) ()]))
       _ (arm wmops (g \ f \ [[(f 3) (f 4)] [<>f <>>f] 1]))
       _ (arm '(mla) (g \ f \ [[<>>f <>>>f (f 4)] [<>f] 1]))
       _ (arm '(clz) (g \ f \ [[<>>f] [<>f] 1]))
       _ (arm '(jmpt) (g \ f \ [[<>f] () ()]))
       ; x64's wide multiply also writes rax (rdx it saves itself)
       _ (arm '(mulh umulh) (g \ f \ [[<>>f <>>>f] ([<>f] + (x86? g ? '(r0) ())) ()]))
       ; a variable shift defines only its dest (x64's count is cl, never moved into): a claimed r1
       ; def would make the pair lane's carry-in look dead
       _ (arm vshops (g \ f \ [[<>f <>>f] [<>f] ()]))
       ; the wide kit: the pair rides r2:r0 unspelled, so copyprop never renames it; x64 spends rcx in
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
           (foldl (t \ o \ pin t o 1) t (stops9 + stxops + fstxops + siops + '(cmpm))))
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
   ; sibcall: (call F) + exactly the epilogue -> epilogue + (jmp F). g 'fesc (frame_address, va_start,
   ; a VLA) pins every call; a frame address as a value (fescv) or an arg (fesca) pins unmarked ones
   (leas? (f . u)) (two? f && <f = 'lea && <>>f = 'r4 ? 1 (leas? u))
   (escan g r) ((two? r && leas? (vfs r) ? (pin g 'fescv 1)), r)
   ; the callee may keep a frame address arg, so only a musttail jumps out past it
   (escana g r) ((two? r && leas? (vfs r) ? (pin g 'fesca 1)), r)
   (unlean (f . u))
                     ((two? f && <f = 'lean ? ('lea . >f) f) . unlean u)
   (relean (f . u)) ; the inverse, for a splice consuming the address
    ((two? f && <f = 'lea ? ('lean . >f) f) . relean u)
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
       ('((mov r10 r3)) + butret ejx + '((jmpr r10))))            ; park first: the x64 epilogue reloads r3
   ; skiprel peels dead reloads after a ret-position call (pool regs only: a cs-reg ld is the epilogue's)
   (skiprel g fs hs)
    (!(two? fs) ? fs
       (<fs @ f
          (!(two? f && (elem <f ldops9 || <f = 'ldsd) && <>>f = 'r4) ? fs
             (filter (h2 \ (<h2 = <>f) && <>h2 = <>>>f) hs @ h   ; a home serves several spans: match reg and slot
                (? (two? h) (skiprel g >fs hs)
                   (elem <>f (g 'pool0)) (skiprel g >fs hs)
                   fs)))))
   ; a tail call's result extension may go: on x64 and a64 every caller extends
   (skipxt g l) (? (two? l && (x64? g || a64? g) && two? <l && elem <<l '(sx1 sx2 sx4 zx1 zx2 zx4) && <>(<l) = 'r0) >l l)
   (sibs g (f . r) lw el hs ej crf)
    (: lw2 (two? f && <f = 'lea && <>>f = 'r4 || lw)
       cand (!lw2 && two? f && (<f = 'call && two? >f ||
                                <f = 'callr && <>f = <>crf) &&
             (!(g 'fesca && !(abl? g 'fesca) || g 'fescv) || must? f))
       rr (cand ? (skiprel g (skipxt g r) hs) r)
       (? (cand && epim? rr ej)
           (sibjmp g f ej + sibs g (drop #ej rr) () el hs ej crf)
          (cand && lbl-epi? rr ej)
           (sibjmp g f ej + sibs g rr () el hs ej crf)
          (cand && (<rr @ nx (two? nx && <nx = 'jmp && peep el <>nx ())))
           (sibjmp g f ej + sibs g >rr () el hs ej crf)
          (cand && lbl-jmp? rr el)
           (sibjmp g f ej + sibs g rr () el hs ej crf)
          ((must? f ? (scare 'musttail-not-a-tail [(g 'fn) f]) 0),
           f . sibs g r (two? f && elem <f '(call callr callm raw) ? () lw2) el hs ej crf)))       ; raw: a builtin splice consumes its address like a call
   ; musttail: a pre-slotted ret (clay's (ret e PRE)) marks its call 'must; sibs jumps or scares
   (must? f) (two? f && elem <f '(call callr callm) && elem 'must >>f)
   (anymust? (a . u)) (must? a || anymust? u)
   (mustret g fs)
    (: (go l) (!(two? l) ? 'no
                 (go >l @ r
                    (r != 'no ? (<l . r)
                       (<l @ f (two? f && elem <f '(call callr callm) ? (f + '(must) . >l) 'no)))))
       r (go fs)
       (r @ 'no (nolane g "a musttail return does not end in a call") r))
   ; a musttail is its author's word nothing reads the frame past the jump, so a value escape
   ; still jumps; a frame address laid as an arg still refuses (lw), best-effort
   (sibcall g fs) (? (nsib? g) (anymust? fs ? (nolane g "a musttail call, and -fno-optimize-sibling-calls") fs)
                     (g 'fesc || g 'fescv && abl? g 'fescv || v6m? g)   ; v6m's pop-pc epilogue can't restore lr for a jmp
                      (anymust? fs ? (scare 'musttail-escape (g 'fn)), fs)
                     (peep g 'epi epi @ ej
                      (sibs g fs () (elabsx fs {} ej) (g 'homes) ej ['callr (pkr g)])))

   ; frame elision (frees rbp, the glaze's Ip): slots re-address off sp at off + K9 + D, K9 = K + the
   ; link bytes, so a call at a 16-multiple D keeps push r4's alignment; scan proves D at every label
   uoff (: t (foldl (t \ o \ pin t o 3) {} (ldops9 + fldops + leaops + '(cmprm)))
           t (foldl (t \ o \ pin t o 5) t (xops + fxops))
           t (foldl (t \ o \ pin t o 2) t (stops9 + siops + '(cmpm)))
         (foldl (t \ o \ pin t o 4) t (stxops + fstxops)))
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
    (: (sw? f) (two? f && (elem <f '(push pop) || f 1 = 'sp && nelem <f (stops9 + siops + stxops + fstxops)))
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
       (!(a64? g) || abl? g 'a64sp || g 'hasasm ? fs (go fs () () 0 () @ r (two? r ? r fs))))
   ; a64 three-register twins: (mov d s) (shl d c) = (lsl d s c), likewise shr, sar, the extends
   ; and not. never an sp source: ubfm and orn read 31 as xzr. last, with a64sp
   a64tw {'shl 'lsl 'shr 'lsr 'sar 'asr 'not 'mvn 'zx1 'uxtb 'zx2 'uxth 'zx4 'uxtw 'sx1 'sxtb 'sx2 'sxth 'sx4 'sxtw}
   (a64mv g fs)
    (? (!(a64? g) || abl? g 'a64mv) fs
       (: (go l acc)
           (? !(two? l) (rev acc)
              (: f <l h (two? >l ? <>l ())
                 tw (two? h ? (peep a64tw <h ()) ())
                 (? (two? f && <f = 'mov && #f = 3 && tw && h 1 = f 1 && atom? (f 2) && !(charm? (f 2)) && f 2 != 'sp)
                    (go >>l (([tw (h 1) (f 2)] + >>h) . acc))
                    (go >l (f . acc)))))
          (go fs ())))
   ; the x64 frame prologue heads fs
   (pro4? fs) (epim? >fs pro4)
   ; riscv: a body naming no sp, fp or lr and making no call (wasm: may call) drops its prologue
   ; and every exit's teardown
   (rvunframe g fs)
    (!(rv64? g && !(g 'fpin) && 5 < #fs && fs 1 = '(push lr) && fs 2 = '(push fp) && fs 4 = '(lea fp sp 0)) ? fs
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
             (strip (drop 5 fs) @ r (r = 'no ? fs (<fs . r))))))
   (unframe g fs)
    (: a64 (a64? g)
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
       body (: b2 (sv3 ? (drop 1 body0) body0) (a64 ? b2 (squeeze b2)))
       (epi3? l9)                                    ; l9 opens with a restore run -> its length | ()
        (butret (a64 ? epi-a64 epi) @ e3
           (? (epim? l9 e3) #e3
              (!a64 && epim? l9 >e3) 2                 ; the run past a dropped r3 reload
              ()))
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
                    (n3 ? ((r3f ? [['ld 'r3 'sp ((K + D) - 8)]])
                           + ((vs ? [['add 'sp 'sp (K9 + D)]] (0 < D ? [['add 'sp 'sp D]]))
                              + rw (drop n3 l) 0))
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
             (<fs . (vs ? (['sub 'sp 'sp K9] . rw body2 0) (rw body2 0))))))

   ; IR constant propagation: a straight-line pass tracking constants (the word's signed value) in
   ; registers, frame slots and stack cells, folding them to li's; an unknown op invalidates everything
   (cfoldir g fs0)
    (: fb (fbase g)                         ; the frame-slot base (r4, or fp past a4ize)
       (fresh z9) {}                        ; reg/slot/cell -> (1 K) const | (2 rX) copy-of-register | ()
       W (8 * wsize g) M (W 2) H (M // 2)   ; the word: its bits, 2^W, 2^(W-1)
       (wrap v) (: u (v % M) u2 (u < 0 ? (u + M) u) (u2 < H ? u2 (u2 - M)))
       (uns v) (v < 0 ? (v + M) v)            ; ..unsigned
       ; a64 li costs movz + a movk per further nonzero 16-bit lane, x64 one: a fold lays a li only up to two
       (licost k) (!(a64? g) ? 1
                     (: (go u n) (u = 0 ? (n < 1 ? 1 n)
                                   (go (u // 65536) (0 = u % 65536 ? n (n + 1))))
                        (go (uns k) 0)))
       (fold? k) (licost k <= 2)
       (rv t k) (t k)
       (rset t k v) (pin t k v)
       (kn? v) (two? v && <v = 1)            ; a known constant (never let a copy reach arithmetic)
       ; a const rides, a copy chases to its root register
       (rsv rg s) (rv rg s @ v (two? v ? v [2 s]))
       ; the copy index ci: source reg -> the (tag key) sites holding a copy, so a write visits only those
       (crec ci v tg k) (two? v && <v = 2 ?  (pin ci <>v ([tg k] . peep ci <>v ())))
       (kild ci rg sl ce d)
        (: (go1 (e . u))
                       (: t (<e @ 'g rg 's sl ce)
                          v (t <>e)
                          (two? v && <v = 2 && <>v = d ? (pin t <>e ()),
                           go1 u))
           (go1 (ci d),
            pin ci d ()))
       (defr ci rg sl ce d) (rset rg d (), kild ci rg sl ce d)
       ; rebuild the index for freshly joined tablets
       (mkci rg sl ce)
        (: ci {}
           (scan1 t tg (a . u)) (crec ci (t a) tg a, scan1 t tg u)
           (scan1 rg 'g (keys rg), scan1 sl 's (keys sl), scan1 ce 'c (keys ce),
            ci))
       (copyt t) (: t2 {}
                    (go1 ks) (!(two? ks) ? t2 (pin t2 <ks (t <ks), go1 >ks))
                  (go1 (keys t)))
       ; the join: a key survives only where both sides know it and agree -- a fresh tablet
       (joint ta tb) (: t2 {}
                        (go1 ks) (!(two? ks) ? t2
                                    (: k1 <ks va (ta k1) vb (tb k1)
                                       (two? va && two? vb &&
                                        <va = <vb && <>va = <>vb ?
                                          (pin t2 k1 va),
                                        go1 >ks)))
                        (go1 (keys ta)))
       (alu op a b) (wrap (op @ 'add (a + b) 'sub (a - b) 'imul (a * b)
                                'and (a & b) 'or (a | b) (a ^ b)))
       ; the immediate shifts and rotates, count in [0, W) (ror4 rotates the low 32 and zero-extends)
       (shf op v k) (op @ 'shl (wrap (v * k 2))
                          'shr (wrap (uns v // k 2))
                          'sar (v >> k)
                          'ror4 (: u (uns v % 4294967296) p (k 2)
                                   (u // p + (u % p) * (32 - k) 2))
                          (: k2 (op = 'rol ? ((W - k) % W) k) u (uns v) p (k2 2)   ; ror, rol = ror W-k
                             (wrap (u // p + (u % p) * (W - k2) 2))))
       (shk? op k) (charm? k && 0 <= k && k < (op = 'ror4 ? 32 W))
       ; a constant division -> [k] | (): () where the machine would trap (a zero divisor, signed INT_MIN / -1),
       ; so that op stands. // truncates toward zero, which is C's /
       (dvk op a b)
        (: sg (elem op '(div rem))
           x (sg ? a (uns a)) y (sg ? b (uns b))
           (? (y = 0) ()
              (sg && a = 0 - H && b = -1) ()
              [(wrap (elem op '(div udiv) ? (x // y) (x - (x // y) * y)))]))
       ; fold? rides here: a division writes r0..r3, so one kept with only d invalidated leaves stale knowns
       (dvfold rg op f)
        (: a (rv rg <>>f)
           b (charm? <>>>f ? [1 (wrap <>>>f)] (rv rg <>>>f))
           k (kn? a && kn? b ? (dvk op <>a <>b))
           (two? k && fold? <k ? k))
       (unop op v) (op @ 'neg (wrap -v) 'not (-v - 1)
                         (: n (op @ ('sx1 || 'zx1) 8 ('sx2 || 'zx2) 16 32)
                            u (uns v % n 2)
                            (? (elem op '(zx1 zx2 zx4)) (wrap u)      ; on a 32-bit word zx4 is the word itself
                               (u < (n - 1) 2) u
                               (u - n 2))))
       ccs9 '(eq ne lt le gt ge below be above ae)   ; the ccs a cmp decides (flag ccs stay)
       (ccev cc a b) (cc @ 'eq (a = b) 'ne !(a = b)
                           'lt (a < b) 'le (a <= b) 'gt (b < a) 'ge (b <= a)
                           'below (uns a < uns b) 'be (uns a <= uns b)
                           'above (uns b < uns a) (uns b <= uns a))   ; ae
       ; after an unconditional transfer everything to the next label is dead -- a folded ternary drops its arm
       (swallow fs) (two? fs ?                ; the align ahead of a label is the label's
                       (<fs @ f (two? f && (<f = 'label || <f = 'align) ? fs (swallow >fs))))
       (atlab? fs l) (two? fs && (<fs @ f (two? f && <f = 'label && <>f = l)))
       ; misc: labels named outside a control transfer (an asm splice, an asm goto's table words);
       ; over-approximate, seeded from those words and filled by bscan
       misc (cg-refs (g 'fasecs) {})
       ; back-edge labels: a loop head joins an edge this linear pass never computes -- assume nothing
       backs (: seen {} bt {}
                (bscan l) (!(two? l) ? bt
                             (<l @ f
                                (f @ ('label a) (pin seen a 1)
                                    ('jmp j)   (seen j ? (pin bt j 1))
                                    ('br _ b)  (seen b ? (pin bt b 1))
                                    ('jmpt _ _ ts) (map (j \ (seen j ? (pin bt j 1))) ts)
                                    ('raw bs) (pinnoms bt bs, pinnoms misc bs)   ; an asm goto's edge: no state rides it
                                    (two? f ? (pinnoms misc >f)),
                                 bscan >l)))
                (bscan fs0))
       ; pend: each forward transfer to L joins its state into pend[L]; the sp cursor must agree or the cells drop
       pend {}
       (pmerge l cur rg sl ce ci)
        (pend l @ old
           (!(two? old) ? (pin pend l [cur (copyt rg) (copyt sl) (copyt ce) (copyt ci)])
              (: rg2 (joint <>old rg) sl2 (joint <>>old sl)
                 nce (<old = cur ? (joint <>>>old ce) (fresh 0))
                 (pin pend l [<old rg2 sl2 nce (mkci rg2 sl2 nce)]))))
       ; lv: linearly live, () right after an unconditional transfer (the label then reads only its jump-in state)
       (go fs lv cur rg sl ce ci acc)
        (!(two? fs) ? (rev acc)
           (: f <fs r >fs
              op (two? f ? <f)
              dk (elem op divops ? (dvfold rg op f))
              (? (op = 'label)
                  (: l1 <>f acc2 (f . acc)
                     (backs l1 ? (go r 1 cur (fresh 0) (fresh 0) (fresh 0) (fresh 0) acc2)
                        (pend l1 @ pd
                           (? !(two? pd)
                               (? lv (go r 1 cur rg sl ce ci acc2)
                                  ; no edge in and the linear one cut: unreachable, drops with its label
                                  !(misc l1) (go (swallow r) () cur rg sl ce ci acc)
                                  (go r 1 cur (fresh 0) (fresh 0) (fresh 0) (fresh 0) acc2))
                              !lv (go r 1 <pd <>pd <>>pd <>>>pd
                                         <>>>>pd acc2)
                              (: rg2 (joint <>pd rg) sl2 (joint <>>pd sl)
                                 ce2 (<pd = cur ? (joint <>>>pd ce) (fresh 0))
                                 (go r 1 <pd rg2 sl2 ce2 (mkci rg2 sl2 ce2) acc2))))))
                 (elem op barops)
                  (go r 1 cur (fresh 0) (fresh 0) (fresh 0) (fresh 0) (f . acc))
                 (op = 'jmp)                         ; drop the dead tail; a jmp to the very next label falls through
                  (swallow r @ r2
                     (atlab? r2 <>f ? (go r2 1 cur rg sl ce ci acc)
                        (pmerge <>f cur rg sl ce ci,
                         go r2 () cur rg sl ce ci (f . acc))))
                 (op = 'br)
                  (pmerge <>>f cur rg sl ce ci,
                   go r 1 cur rg sl ce ci (f . acc))
                 (op = 'jmpt)
                  (map (L \ (pmerge L cur rg sl ce ci)) (f 3),
                   go (swallow r) () cur rg sl ce ci (f . acc))
                 (xit? f) (go (swallow r) () cur rg sl ce ci (f . acc))
                 (op = 'li)
                  (: nx (two? r ? <r)
                     (two? nx && elem <nx '(li mov) && <>nx = <>f ?
                        (go r 1 cur rg sl ce ci acc)    ; the very next form rewrites this register: dead li
                        (: k (constellation? <>>f ? (wrap <>>f) 'no)   ; a big rides too (charm? is the fixnum)
                           old (rv rg <>f)
                           (kn? old && <>old = k ?
                              (go r 1 cur rg sl ce ci acc)
                              (defr ci rg sl ce <>f,
                               rset rg <>f (constellation? k ? [1 k] ()),
                               go r 1 cur rg sl ce ci (f . acc))))))
                 (op = 'mov)
                  (<>f = <>>f ? (go r 1 cur rg sl ce ci acc)
                     (: v (rsv rg <>>f)
                        old (rv rg <>f)
                        ; a copy chasing back to the dest is a no-op -- not for sp/fp/r4, whose
                        ; copy records outlive the motion (sp moves through the cursor, not defr)
                        (two? old && two? v && <old = <v && <>old = <>v ||
                         two? v && <v = 2 && <>v = <>f && !(elem <>f '(sp fp r4 r3)) ?
                             (go r 1 cur rg sl ce ci acc)
                           (defr ci rg sl ce <>f,
                            rset rg <>f v,
                            crec ci v 'g <>f,
                              ; a64 only: x64's reg-reg mov vanishes at rename, its li would be a real uop
                            (kn? v && a64? g && licost <>v = 1 ?
                               (go r 1 cur rg sl ce ci (['li <>f <>v] . acc))
                               (go r 1 cur rg sl ce ci (f . acc)))))))
                 (elem op '(add sub and or xor imul))
                  (<>f = 'sp ?                ; sp arithmetic: the cell cursor moves
                      (<>>>f @ n
                         (go r 1 (op = 'add ? (cur - n) (cur + n)) rg sl ce ci (f . acc)))
                     (: d <>f a <>>f b <>>>f
                        bk (charm? b ? [1 (wrap b)] (rv rg b))
                        ak (rv rg a)
                        (? (kn? ak && kn? bk)
                            (alu op <>ak <>bk @ k
                               (defr ci rg sl ce d,
                                rset rg d [1 k],
                                fold? k ?
                                  (go r 1 cur rg sl ce ci (['li d k] . acc))
                                  (go r 1 cur rg sl ce ci (f . acc))))
                           (!(charm? b) && kn? bk && imma g op <>bk)   ; known reg source -> the imm form
                            (defr ci rg sl ce d,
                             go r 1 cur rg sl ce ci ([op d a <>bk] . acc))
                           (defr ci rg sl ce d,
                            go r 1 cur rg sl ce ci (f . acc)))))
                 ; a known division folds whole, so only d is written; an unfoldable one falls
                 ; to the default arm, whose rdsp defs carry the machine div's r0..r3 clobber
                 (two? dk)
                  (: d <>f k <dk
                     (defr ci rg sl ce d,
                      rset rg d [1 k],
                      go r 1 cur rg sl ce ci (['li d k] . acc)))
                 (elem op '(shl shr sar rol ror ror4))
                  (: d <>f k <>>f dk (rv rg d)
                     (defr ci rg sl ce d,
                      kn? dk && shk? op k ?
                         (shf op <>dk k @ v
                            (rset rg d [1 v],
                             (? (v = <>dk) (go r 1 cur rg sl ce ci acc)
                                (fold? v) (go r 1 cur rg sl ce ci (['li d v] . acc))
                                (go r 1 cur rg sl ce ci (f . acc)))))
                        (go r 1 cur rg sl ce ci (f . acc))))
                 ; a variable shift with a known count is the immediate one; the machine masks
                 ; the count where the immediate form does not, so shk? keeps one outside [0, W) variable
                 (elem op vshops)
                  (: d <>f iop (op @ 'shlv 'shl 'shrv 'shr 'sarv 'sar 'rorv 'ror 'ror4)
                     dk (rv rg d) ck (rv rg <>>f)
                     k (kn? ck ? <>ck 'no)
                     (defr ci rg sl ce d,
                      (? !(shk? iop k) (go r 1 cur rg sl ce ci (f . acc))
                         !(kn? dk) (go r 1 cur rg sl ce ci ([iop d k] . acc))
                         (shf iop <>dk k @ v
                            (rset rg d [1 v],
                             (? (v = <>dk) (go r 1 cur rg sl ce ci acc)
                                (fold? v) (go r 1 cur rg sl ce ci (['li d v] . acc))
                                (go r 1 cur rg sl ce ci ([iop d k] . acc))))))))
                 (elem op unops)
                  (: d <>f dk (rv rg d)
                     (defr ci rg sl ce d,
                      kn? dk ?
                         (unop op <>dk @ v
                            (rset rg d [1 v],
                             (? (v = <>dk) (go r 1 cur rg sl ce ci acc)
                                (fold? v) (go r 1 cur rg sl ce ci (['li d v] . acc))
                                (go r 1 cur rg sl ce ci (f . acc)))))
                        (go r 1 cur rg sl ce ci (f . acc))))
                 (op = 'st)
                  (? (<>f = fb)
                      (rsv rg <>>>f @ v9 (rset sl <>>f v9, crec ci v9 's <>>f,
                                          go r 1 cur rg sl ce ci (f . acc)))
                     (<>f = 'sp)
                      ; keyed by depth (cur - off): the wide kit's two words in one 16-byte cell track apart
                      (rsv rg <>>>f @ v9 (rset ce (cur - <>>f) v9, crec ci v9 'c (cur - <>>f),
                                          go r 1 cur rg sl ce ci (f . acc)))
                     (go r 1 cur rg (fresh 0) ce ci (f . acc)))     ; a pointer store may alias the frame
                 (op = 'ld)
                  (: d <>f b <>>f off <>>>f
                     kv (? (b = fb) (rv sl off) (b = 'sp) (rv ce (cur - off)) ())
                     (? (kn? kv)
                        (defr ci rg sl ce d,
                         rset rg d kv,
                         (fold? <>kv ?
                            (go r 1 cur rg sl ce ci (['li d <>kv] . acc))
                            (go r 1 cur rg sl ce ci (f . acc))))
                        (two? kv && <kv = 2)     ; the memory holds a live copy: read the register
                         (<>kv = d ?
                            (go r 1 cur rg sl ce ci acc)
                            (defr ci rg sl ce d,
                             rset rg d kv,
                             crec ci kv 'g d,
                             go r 1 cur rg sl ce ci (['mov d <>kv] . acc)))
                        (defr ci rg sl ce d,
                         go r 1 cur rg sl ce ci (f . acc))))
                 (op = 'push)                        ; cur + 8 on a64 too: keys are ledger depths
                  (: cur2 (cur + 8)
                     v9 (rsv rg <>f)
                     (rset ce cur2 v9, crec ci v9 'c cur2,
                      go r 1 cur2 rg sl ce ci (f . acc)))
                 (op = 'pop)
                  (rv ce cur @ v
                     (defr ci rg sl ce <>f,
                      rset rg <>f v,
                      crec ci v 'g <>f,
                      go r 1 (cur - 8) rg sl ce ci (f . acc)))
                 (elem op >stops9)                ; the full-word st has its own arm above
                  (<>f = fb || <>f = 'sp ?
                      ((<>f = fb ? (rset sl <>>f ()) (rset ce cur ())),
                       ; i386's word is 4 bytes: the store's own slot goes, and a double's second word with it
                       (ia32? g ? (: o <>>f k (<>f = fb ? sl ce) (key x) (<>f = fb ? x (cur - x))
                                     (rset k (key o) (), op = 'stsd ? (rset k (key (o + 4)) ()))) 0),
                       go r 1 cur rg sl ce ci (f . acc))
                     (go r 1 cur rg (fresh 0) ce ci (f . acc)))
                 (op = 'cmp)                         ; paired with its br/set/cmov consumer
                  (: a (rv rg <>f)
                     b (charm? <>>f ? [1 (wrap <>>f)] (rv rg <>>f))
                     ; a select's cmov may sit past forms that write no flag (icmov lays an arm there)
                     (sk l n) (two? l && two? <l && elem <<l fneu ? (sk >l (n + 1)) n)
                     ns (sk r 0)
                     cm (drop ns r)
                     nx (? (two? cm && two? <cm && <<cm = 'cmov) <cm (two? r) <r ())
                     (kn? a && kn? b && two? nx && elem <nx '(br set cmov) && elem <>nx ccs9 ?
                         (ccev <>nx <>a <>b @ tv
                            ; a decided select is its mov, or nothing
                            (? (<nx = 'cmov)
                                (: (pre l n) (n < 1 ? () (<l . pre >l (n - 1)))
                                   (go (pre r ns + (tv ? (['mov <>>nx <>>>nx] . >cm) >cm)) 1 cur rg sl ce ci acc))
                               (<nx = 'br)
                               (tv ? (swallow >r @ r2
                                        (atlab? r2 <>>nx ? (go r2 1 cur rg sl ce ci acc)
                                           (pmerge <>>nx cur rg sl ce ci,
                                            go r2 () cur rg sl ce ci (['jmp <>>nx] . acc))))
                                     (go >r 1 cur rg sl ce ci acc))
                               (: d <>>nx k (tv ? 1 0)
                                  (defr ci rg sl ce d,
                                   rset rg d [1 k],
                                   go >r 1 cur rg sl ce ci (['li d k] . acc)))))
                        (go r 1 cur rg sl ce ci (f . acc))))
                 ; every other tabled op writes rdsp's defs; off the table nothing survives. the
                 ; table is register effects only, so a memory-writing op needs its own arm above
                 (rdsp g f @ rd
                    (rd @ 'bar
                           (go r 1 cur (fresh 0) (fresh 0) (fresh 0) (fresh 0) (f . acc))
                          (((: (dfs ds) (!(two? ds) ? 1
                                           (defr ci rg sl ce <ds, dfs >ds)) dfs) <>rd),
                           go r 1 cur rg sl ce ci (f . acc)))))))
       ; a br over a jmp to the br's own target is the one br, inverted
       (brj l) (two? l ?
                  (<l @ f
                     (two? f && <f = 'br && elem <>f ccs9 && two? >l && two? >>l &&
                      (: j <>l k <>>l (two? j && <j = 'jmp && two? k && <k = 'label && <>k = <>>f)) ?
                         (['br (negcc <>f) <><>l] . brj >>l)
                        (f . brj >l))))
       (brj (go fs0 1 0 (fresh 0) (fresh 0) (fresh 0) (fresh 0) ())))

   ; dead cells: a spush cell nothing loads is write-only, so its store and its sub/add pair drop;
   ; a live cell converts to a frame slot (one per record depth) and the pair still drops
   (deadcell g fs)
    (: pex (map (f \ <>f) (filter (f \ (<f = 'pop)) (peep g 'epi epi)))   ; the epilogue's teardown pops
       cand {}                               ; st-index -> 1 while still droppable
       clds {}                               ; st-index -> its cell's ld indexes
       dirty {}                              ; sub-index -> 1: the span observed sp
       (dirt st2) (!(two? st2) ? 1
                     ((charm? <>><st2 ? (pin dirty <>><st2 1)),
                      dirt >st2))
       (scan l i stk sw)                             ; -> the (sub st k add depth) entries | 'no
        (!(two? l) ? sw
           (: f <l r >l
              (? !(two? f) (scan r (i + 1) stk sw)
                 (<f = 'sub && <>f = 'sp && charm? <>>>f)
                  (: k <>>>f
                     nx (two? r ? <r)
                     (k = 16 && two? nx && <nx = 'st &&
                      <>nx = 'sp && <>>nx = 0 ?
                        (pin cand (i + 1) 1,
                         scan >r (i + 2) ([(i + 1) 16 i #stk] . stk) sw)
                        (scan r (i + 1) ([() k i #stk] . stk) sw)))
                 (<f = 'add && <>f = 'sp && charm? <>>>f)
                  (: (unwind st2 k w)
                      (? (k = 0) [st2 w]
                         !(two? st2) 'no
                         (: rc <st2 sz <>rc
                            (k < sz ? 'no
                               (unwind >st2 (k - sz)
                                (charm? <>>rc ? ([<>>rc <rc sz i (rc 3)] . w) w)))))
                     r9 (unwind stk <>>>f ())
                     (r9 @ 'no 'no (scan r (i + 1) <r9 (<>r9 + sw))))
                 (<f = 'push) (scan r (i + 1) ([() 8 () ()] . stk) sw)
                 (<f = 'pop)
                  (? (elem <>f pex) (scan r (i + 1) stk sw)   ; the epilogue's frame pops: path exit
                     (two? stk && !<<stk && <><stk = 8)
                     (scan r (i + 1) >stk sw)
                     'no)
                 (elem <f ldops9 && <>>f = 'sp)
                  (two? stk && <<stk && <>>>f = 0 ?
                     (<<stk @ stx
                        (pin cand stx (),
                         pin clds stx (i . peep clds stx ()),
                         scan r (i + 1) stk sw))
                     'no)
                 (elem <f stops9 && <>f = 'sp) 'no
                 (elem <f fldops && <>>f = 'sp) 'no
                 ((<f = 'raw || elem 'sp >f ? (dirt stk)),
                  scan r (i + 1) stk sw))))
       ok (scan fs 0 () ())
       (ok @ 'no fs
             (: subdrop {} addsh {}     ; sub-index -> drop; add-index -> shrink bytes
                stconv {} ldconv {}     ; st/ld-index -> the slot's positive offset
                pf3 (fs 3)                         ; the prologue's frame sub: (sub sp sp F)
                cvok (pro4? fs &&
                      two? pf3 && <pf3 = 'sub && <>pf3 = 'sp && <>>pf3 = 'sp && charm? <>>>pf3)
                F (cvok ? <>>>pf3 0)
                (mark w cv) (!(two? w) ? cv
                               (: e <w sub (e 0) st (e 1) k (e 2) ad (e 3)
                                  (? (dirty sub) (mark >w cv)
                                     !(0 = k % 16) (mark >w cv)
                                     (!st || peep cand st ())
                                      (pin subdrop sub 1,
                                       pin addsh ad (peep addsh ad 0 + k),
                                       mark >w cv)
                                     (cvok && k = 16) (mark >w (e . cv))
                                     (mark >w cv))))
                cvl (mark ok ())
                ds (: (dd l acc) (!(two? l) ? acc
                                    (<l 4 @ d
                                       (dd >l (elem d acc ? acc (d . acc)))))
                      (dd cvl ()))
                (rank d l n) (<l = d ? n (rank d >l (n + 1)))
                _ ((: (cvt l) (!(two? l) ? 1
                                 (: e <l
                                    o (F + 8 + 8 * rank (e 4) ds 0)
                                    (pin subdrop (e 0) 1,
                                     pin addsh (e 3) (peep addsh (e 3) 0 + 16),
                                     pin stconv (e 1) o,
                                     ((: (pl ls) (!(two? ls) ? 1
                                                    (pin ldconv <ls o, pl >ls)) pl)
                                      (clds (e 1))),
                                     cvt >l))) cvt) cvl)
                F2 (aup (F + 8 * tally ds) 16)
                ; a converted cell joins the slot map, or deadst/repack bar the fn on an unclaimed r4 touch
                _ (foldl (_ \ d \ (F + 8) + (8 * rank d ds 0) @ o
                                    (pin g 'slots ([(0 - o) 8] . peep g 'slots ())))
                         0 ds)
                (drop2 l i) (two? l ?
                               (? (cand i) (drop2 >l (i + 1))
                                  (subdrop i) (drop2 >l (i + 1))
                                  (: f2 <l
                                     o9 (stconv i)
                                     ol (ldconv i)
                                     s (peep addsh i 0)
                                     (? o9 (['st 'r4 (0 - o9) <>>>f2] . drop2 >l (i + 1))
                                        ol ([<f2 <>f2 'r4 (0 - ol)] . drop2 >l (i + 1))
                                        (two? cvl && i = 3) (['sub 'sp 'sp F2] . drop2 >l (i + 1))
                                        (s = 0) (f2 . drop2 >l (i + 1))
                                        (<>>>f2 - s @ k2
                                           (k2 = 0 ? (drop2 >l (i + 1))
                                              (['add 'sp 'sp k2] . drop2 >l (i + 1))))))))
                (drop2 fs 0))))

   ; dead defs: within a block, a pure def re-defined before any read drops. one backward walk;
   ; a control edge or an untabled op resets the dead set. dead_before = (dead + defs) - reads
   (deaddef g fs)
    (: (go l dead acc)
        (!(two? l) ? acc
           (: f <l r >l
              (!(two? f) ? (go r dead (f . acc))
                 (rdsp g f @ rd
                    (rd @ 'bar (go r {} (f . acc))
                          (: reads <rd defs <>rd pure <>>rd
                             (dd? ds) (!(two? ds) ? 1
                                         (dead <ds ? (dd? >ds)))
                             (pure && two? defs && dd? defs ?
                                (go r dead acc)
                                (((: (ad ds) (!(two? ds) ? 1
                                                (<ds @ 'sp () (pin dead <ds 1),
                                                 ad >ds)) ad) defs),
                                 ((: (rm rs) (!(two? rs) ? 1
                                                (pin dead <rs (), rm >rs)) rm) reads),
                                 go r dead (f . acc)))))))))
       (go (rev fs) {} ()))

   (jr0 g fs)                                        ; a park (mov P X) straight-line to its (jmpr P) becomes (jmpr X)
    (two? fs ?
       (<fs @ f
          (!(two? f && <f = 'mov && !(charm? <>>f)) ?
              (f . jr0 g >fs)
             (: P <>f X <>>f
                (scan w n)                            ; forms to the jmpr -> n | 'no
                 (!(two? w) || 10 < n ? 'no
                    (<w @ f2
                       (? !(two? f2) 'no
                          (<f2 = 'jmpr && <>f2 = P) n
                          (rdsp g f2 @ rd
                             (? (rd = 'bar) 'no
                                (elem P >f2) 'no
                                (elem X <>rd) 'no
                                (scan >w (n + 1)))))))
                k (scan >fs 0)
                (k @ 'no (f . jr0 g >fs)
                     (: (mend w i) (i = k ? (['jmpr X] . jr0 g >w)
                                      (<w . mend >w (i + 1)))
                        (mend >fs 0)))))))
   ; i386: an address laid only to be accessed through at once becomes that access by absolute
   ; address ('rip (sym k)), when nothing reads the address after
   (absg g fs)
    (!(ia32? g) || abl? g 'absg ? fs
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
          (go fs)))
   ; a word read off a global's address (plus k): (sym k) | ()
   (gword fs) (fs @ (('la x s) ('ld r y k)) (x = y && charm? k ? [s k] ())
                    (('laa x s j) ('ld r y k)) (x = y && charm? k && charm? j ? [s (j + k)] ())
                    ())
   ; i386 -Os: the callee-saved saves ride push and pop. the pushes take the frame's top words,
   ; which nothing else reads (the rbx slot and the saves' own); every exit restores alike
   (pushsv g fs)
    (? (!(ia32? g && osz? g) || abl? g 'pushsv || !(two? fs) || !(two? >fs)) fs
       (: lab <fs pro <>fs
          N (pro @ ('sub 'sp 'sp n) (charm? n ? n ()) ())
          ; the saves straight after the frame: [(off reg)..] and the forms past them
          (svs l acc) (? (two? l && (<l @ ('st 'sp k r) (charm? k && elem r (cspool g)) ()) && #acc < 3)
                          (svs >l ([(<l 2) (<l 3)] . acc))
                          [(rev acc) l])
          sv (charm? N ? (svs >>fs ()) [() ()])
          sl <sv body <>sv
          offs (map (x \ <x) sl)
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
             ([lab] + map (x \ ['push (x 1)]) sl + (N = 4 * nsv ? () [['sub 'sp 'sp (N - 4 * nsv)]]) + rw body))))
   ; the fall-through's answer: 0, for main's sake -- a void fn has none to give
   (fz0 g nm) (<(peep (g 'sigs) nm ['long ()]) = 'void ? () '((li r0 0)))
   ; -Os: the straight runs that end in a ret and share a tail keep one copy of it, under a label;
   ; the others jump there. two forms at least, so a bare ret never trades for a jump
   (rjoin g fs)
    (? !(osz? g) fs
       (: (bar? f) (!(two? f) || elem <f '(label br jmp jmpr ret raw jmpm))
          (ret? f) (two? f && <f = 'ret)
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
                ends (map (b \ <b) blks)
                (go l i) (? !(two? l) ()
                            (i + k - 1 = <le) (['label lj] . (<l . go >l (i + 1)))
                            (elem (i + k - 1) ends) (['jmp lj] . go (drop k l) (i + k))
                            (<l . go >l (i + 1)))
                (go fs 0)))))
   ; x64: (ld X b o) .. (jmpr X) -> (jmpm b o), the load sinking past forms that leave X and b alone
   ; (b's own add folds into o). never off sp or fp, and X is no argument register
   (jmpm g fs)
    (!(x64? g) || x86k? g 'thk || x86k? g 'ibr ? fs
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
          (go fs)))
   ; -mindirect-branch=thunk-extern and -mfunction-return=thunk-extern, last over x64's code: an
   ; indirect call or jump goes by the kernel's thunk for its register, a return by its return thunk
   x86rn {'r0 "rax" 'r1 "rcx" 'r2 "rdx" 'r3 "rbx" 'r4 "rbp" 'r5 "rsi" 'r6 "rdi" 'r7 "r8"
          'r8 "r9" 'r9 "r10" 'r10 "r11" 'r11 "r12" 'r12 "r13" 'r13 "r14" 'r14 "r15"}
   (thunks g fs)
    (: thk (x86k? g 'thk) rth (x86k? g 'rth) cs (x86k? g 'cs)
       (via op r) (: s (intern "__x86_indirect_thunk_\(x86rn r)")
                     ((cs && elem r '(r7 r8 r9 r10 r11 r12 r13 r14) ? ['(raw (46))]) + [[op s]]))
       (one f) (? !(two? f) [f]
                  (thk && <f = 'callr) (via 'call <>f)
                  (thk && elem <f '(jmpr jmpt)) (via 'jmp <>f)
                  (rth && f = '(ret)) [['jmp '__x86_return_thunk]]
                  [f])
       (thk || rth ? (catmap one fs) fs))
   ; an early exit lays last: (br cc L) run (label L) -> (br !cc K) (label L) .., (label K) run after
   ; the fn. the run may hold labels, no branch; a cold L (__builtin_expect(c, 0)) lets the run past
   ; its last test of L branch, and one that falls into L jumps there. a lone (jmp X) run is the br, to X
   (tailarm g fs)
    (t32? g ? fs                                            ; thumb's short branches stay put
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
          (go l acc cs)
           (!(two? l) ? (rev acc + cs)
              (: f <l
                 k (two? f && <f = 'br && elem <>f '(eq ne lt le gt ge below be above ae s ns) &&
                    nelem <>>f hot ?
                      (run >l <>>f () 0 (elem <>>f cold)))
                 r1 (two? k && !(two? ><k) && <<<k = 'jmp ? (<<k 1))
                 (? (two? k && r1 && (x64? g || elem r1 labs))
                     (go (k 1) (['br (negcc <>f) r1] . acc) cs)
                    (two? k)
                     (nlab g ".k" @ K
                        (go (k 1) (['br (negcc <>f) K] . acc) (cs + (['label K] . <k))))
                    (go >l (f . acc) cs))))
          (go fs () ())))
   ; a64's frame record: the fp and lr pushes fuse to one stp, the pops to one ldp; the area stays
   ; 32 bytes, so no fp-relative offset moves
   (frrec g fs)
    (!(a64? g) || !(two? fs) ? fs
       (: (go l acc) (? !(two? l) (rev acc)
                        (<l = '(push lr) && <>l = '(push fp)) (go >>l ('(frpush) . acc))
                        (<l = '(pop fp) && <>l = '(pop lr)) (go >>l ('(frpop) . acc))
                        (go >l (<l . acc)))
          (lone? f) (two? f && elem <f '(push pop) && elem <>f '(fp lr))
          r (go fs ())
          (any lone? r ? (nolane g "a frame record split\(ontgt g)") r)))
   ; -mbranch-protection (a key): pac-ret lays paciasp before each (frpush), autiasp after each (frpop).
   ; under bti a table jump's targets land on bti j and an indirect jump goes by x16, which bti c and
   ; paciasp both take from a br. the entry's bti c is btic's: only the unit knows a static's address taken
   (bp? g k) (a64? g && elem k <>(g 'mo))
   ; -mstrict-align (a64): no access wider than its known alignment; a packed member's face carries
   ; its alignment and goes by chunks, r2 gathers and r3 shifts, neither ever a face's base
   (sal? g) (a64? g && <(g 'mo))
   ; -mregparm=n (i386): the first n argument words ride eax edx ecx
   (rpn g) (ia32? g ? (drop 2 (g 'mo) @ r (two? r && charm? <r ? <r 0)) 0)
   ; -march= a cpu before the 686: no cmov
   (old86? g) (ia32? g ? (drop 3 (g 'mo) @ r (two? r && <r)) 0)
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
   (x86k? g k) (x64? g && drop 16 (g 'mo) @ r (two? r && elem k <r))   ; the x86-64 kernel's asks: sa8 nal thk rth ibr cs
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
   (bfpk? bt) (two? (drop 4 bt))
   (bfld g bt d b o a) (? (bfpk? bt || a) (ldal d b o (tsz g bt) (a ? a 8)) [[(uldop (tsz g bt)) d b o]])
   (bfst g bt b o a v) (? (bfpk? bt || a) (stal b o (tsz g bt) (a ? a 8) v) [[(stop <>bt) b o v]])
   (bfwide? g bt) (bfpk? bt && wsize g < tsz g bt)   ; a packed unit past the register
   (bfnl g) (nolane g "a packed bit-field whose bytes outrun a register")
   ; a member's face, marked where its offset and its base's alignment cannot carry its width
   (sface g r fm v)
    (!(sal? g) ? v
       (: ty <>fm
          ba (ua? r ? (vma r) (tal g (vty r)))
          lb (lowb <fm) e (lb = 0 ? ba (min ba lb))
          nd (stru? ty || arr? ty ? (tal g ty) (tsz g ty))
          (e < nd ? (mkma ty (vmb v) (vmo v) (vfs v) e) v)))
   (uanl g) (nolane g "under -mstrict-align, a misaligned member of this kind")
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
    (: pac (bp? g 'pac) bti (bp? g 'bti) ibt (ibt? g)
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
       (pac || bti || ibt ? (go fs ()) fs))
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
    (: f1 (two? fs && two? >fs ? <>fs)
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
                   pro (<>fs . map (p \ ['st 'sp (p 0) (p 1)]) saves)
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
                   ((<fs . emit 0 ()) + stubs))))))
   ; the arrival rename: a call-free fn's param homes (mov H A) rename to A where A is never otherwise touched
   (unhome g fs)
    (: ar (argr g) hr (hregs g)
       (pears l n acc)                                ; the leading (mov H A) movs -> ((H A)..)
        (!(two? l) || 8 < n ? acc
           (<l @ f
              ; a body label ends the entry: a (mov H A) past it may be a loop's per-iteration reset
              (? (two? f && <f = 'label && 0 < n) acc
                 (two? f && <f = 'mov &&
                  elem <>f hr && elem <>>f ar)
                 (pears >l (n + 1) ([<>f <>>f] . acc))
                 (pears >l (n + 1) acc))))
       (callish l) (two? l ?
                      (<l @ f (two? f && elem <f barops ? 1 (callish >l))))
       (ok? H A l seen)
        (!(two? l) ? 1
           (<l @ f
              (? !(two? f) (ok? H A >l seen)
                 (!seen && <f = 'mov && <>f = H && <>>f = A)
                  (ok? H A >l 1)                      ; the entry mov
                 (seen && <f = 'mov && <>f = A && <>>f = H)
                  (ok? H A >l seen)                   ; a staging restore
                 (rdsp g f @ rd
                    (rd @ 'bar
                           (? (elem <f '(label jmp br ret)) (ok? H A >l seen)
                              (<f = 'jmpr && <>f != A) (ok? H A >l seen)
                              ())                        ; an op outside the tables: keep the homes
                          (<rd @ reads
                             (? (elem A reads || elem A <>rd) ()
                                ; H before the entry mov is another value (an arrival): renaming it corrupts
                                (!seen && (elem H reads || elem H <>rd)) ()
                                (elem H <>rd && nelem H reads) ()
                                (ok? H A >l seen))))))))
       (ren H A l)
        (two? l ?
           (: f <l
              f2 (two? f ? ((: (sw e) (!(two? e) ? e ((<e = H ? A <e) . sw >e)) sw) f) f)
              (two? f2 && <f2 = 'mov && <>f2 = <>>f2 ?
                 (ren H A >l)
                 (f2 . ren H A >l))))
       (go2 ps l)
        (!(two? ps) ? l
           (<ps @ p
              (go2 >ps (ok? <p <>p l () ? (ren <p <>p l) l))))
       (callish fs ? fs (go2 (pears fs 0 ()) fs)))

   ; adjacent sp adjustments merge; a cancelled pair (a dead cell's husk) vanishes
   (spadj? f) (two? f && elem <f '(add sub) &&
               <>f = 'sp && <>>f = 'sp && charm? <>>>f)
   (spmerge fs)
    (two? fs ?
       (: f <fs r >fs
          nx (two? r ? <r)
          (spadj? f && spadj? nx ?
             (: n1 (<f = 'add ? <>>>f (0 - <>>>f))
                n2 (<nx = 'add ? <>>>nx (0 - <>>>nx))
                net (n1 + n2)
                (? (net = 0) (spmerge >r)
                   (net < 0) (spmerge (['sub 'sp 'sp (0 - net)] . >r))
                   (spmerge (['add 'sp 'sp net] . >r))))
             (f . spmerge r))))

   ; a frame store that rides straight-line to an exit -- register work, stores and the
   ; epilogue between -- is dead; the sib rewrite leaves these where a musttail's wrap spilled
   (tailst g fs)
    (: fb (fbase g)
       (calm? f) (elem <f '(mov lea li sx4 zx4 pop label align) ||
                  elem <f stops9 || elem <f siops ||
                  elem <f '(add sub) && <>f = 'sp)
       (dead? l) (two? l ?
                    (<l @ f
                       (? !(two? f) (dead? >l)
                          (xit? f) 1
                          (calm? f) (dead? >l)
                          ())))
       (go l) (two? l ?
                 (<l @ f
                    (two? f && <f = 'st && <>f = fb && dead? >l ?
                       (go >l)
                       (f . go >l))))
       (go fs))
   ; dead frame stores: a slot never loaded back drops, with its newly-dead feeding li. an lea
   ; keeps its whole slot-map object live; an lea no object claims bars the fn
   (deadst g fs)
    (: used {} esc {}
       fb (fbase g)
       slots (g 'slots)
       (obmark x) (obj9 slots x @ o9               ; x's object stays whole; none bars the fn
                     (two? o9 ? (mark <o9 <>o9) (pin esc 'y 1)))
       ; liveness by the 8-byte granules an access spans, never offset-exact: a store at off+8
       ; is read back at off+12 by a struct's inner field
       (mwid op) (? (elem op '(ld1 ldu1 st1 si1)) 1
                    (elem op '(ld2 ldu2 st2 si2)) 2
                    (elem op '(ld4 ldu4 st4 si4 ldss stss)) 4
                    8)
       (mark o w) (: (go k) (((o + w) - 1) >> 3 < k ? 1 (pin used k 1, go (k + 1)))
                     (go (o >> 3)))
       (hit? o w) (: (go k) (? (((o + w) - 1) >> 3 < k) () (used k) 1 (go (k + 1)))
                     (go (o >> 3)))
       (scan l) (!(two? l) ? 1
                   (<l @ f
                      ((? !(two? f) ()
                          (elem <f ldops9 || elem <f fldops)
                           (<>>f = fb ? (mark <>>>f (mwid <f)))
                          (<f = 'cmpm)
                           (<>f = fb ? (mark <>>f 8))
                          (<f = 'cmprm)
                           (<>>f = fb ? (mark <>>>f 8))
                          (elem <f '(lea lean))          ; (lea sp fp 0) is teardown, not an address take
                           (<>>f = fb && <>f != 'sp ? (obmark <>>>f))
                          (elem <f xops || elem <f fxops)   ; a runtime index roams its object
                           (<>>f = fb ? (obmark (f 5)))
                          (elem <f stxops || elem <f fstxops)
                           (<>f = fb ? (obmark (f 4)))),
                       scan >l)))
       _ (scan fs)
       (drop (f . u)) (two? f && (elem <f stops9 || elem <f siops) &&
                        <>f = fb && !(hit? <>>f (mwid <f)) ?
                         (drop u)
                         (f . drop u))
       (lisweep (f . u)) (: nx (two? u ? <u)
                           (two? f && <f = 'li &&
                            two? nx && elem <nx '(li mov) && <>nx = <>f ?
                              (lisweep u)
                              (f . lisweep u)))
       (esc 'y ? fs (lisweep (drop fs))))

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
   ; the blanket cases filter mints out: a mint live across a call must read as crossing, not
   ; be read+def'd into a false kill. inert post-vrfix
   (lvtx g f u)                                     ; one form's (reads defs) | 'bar
    (!(two? f) ? [() ()]
       (<f @ op
          (? (elem op lvquiet) [() ()]
             (elem op '(call callr callm sys))
              (filter (r9 \ !(elem r9 (csregs g) || vmint? g r9)) u @ c
                 ; narrow (the allocator's): a call reads its argument file and r0 (x64's al), a callr its target too
                 (peep g 'lvnarrow () && op != 'sys ?
                    [(filter (r9 \ elem r9 (argr g) || r9 = 'r0 || nelem r9 (lvgp g)) c +
                      (op = 'callr && nom? <>f ? [<>f])) c]
                    [c c]))
             (retx? f) [(lvret g + csregs g) ()]
             (op = 'jmpr) [(filter (r9 \ !(vmint? g r9)) u) ()]
             (rdsp g f @ d (d @ 'bar 'bar [<d <>d])))))
   (lvuniv g fs)                                    ; every register in play
    (: t {}
       (add rs) (!(two? rs) ? 0 (pin t <rs 1, add >rs))
       _ (add (lvgp g))                             ; a register the fn never mentions must still clobber at a call
       (scan l) (!(two? l) ? 0
                   (: f <l d (two? f ? (rdsp g f) [() ()])
                      (d @ 'bar 0 (add <d, add <>d),
                       scan >l)))
       (scan fs,
        keys t))
   (lvun a b) (!(two? b) ? a (lvun (elem <b a ? a (<b . a)) >b))
   (lvsame a b) (#a = #b && !(two? (filter (r9 \ (nelem r9 b)) a)))
   (lvio g fs)                                      ; -> [lin lot tx] (index -> live in/out of it, its lvtx) | 'no
    (: u (lvuniv g fs)
       um (filter (r9 \ !(vmint? g r9)) u)          ; the machine share: what a blanket case reads
       (: labt {}
          (ix l i) (!(two? l) ? 0
                      (<l @ f
                         (two? f && <f = 'label ? (pin labt <>f i),
                          ix >l (i + 1))))
          _ (ix fs 0)
          (ixd l i) (two? l ? ([i <l] . ixd >l (i + 1)))
          rl (rev (ixd fs 0))
          (succ f i) (: op (two? f ? <f 'x)
                        (? (op = 'jmp) [(peep labt <>f -1)]
                           (op = 'br) [(peep labt <>>f -1) (i + 1)]
                           (op = 'jmpt) (map (L \ (peep labt L -1)) (f 3))
                           (xit? f) ()
                           [(i + 1)]))
          lin {}
          lot {}
          (gone? f) (xjmp? f labt)               ; a sibcall: arguments in flight, reads everything
          ; each form's (reads defs) and successors, once
          tx (foldl (t \ e \ pin t <e (lvtx g <>e u)) {} rl)
          bar9 (vany (e \ tx <e = 'bar) rl)
          dt (bar9 ? {} (foldl (t \ e \ pin t <e (gone? <>e ? [um ()] (tx <e))) {} rl))
          st (foldl (t \ e \ pin t <e (succ <>e <e)) {} rl)
          ; a form is read again only when a successor's live-in moved since: the same inputs give
          ; the same lists. tick numbers every reading, seen when i was read, moved when lin i grew
          ck {'n 0} seen {} moved {}
          (pass l ch)                            ; one backward sweep -> did any live-in grow?
           (!(two? l) ? ch
              (: e <l i <e
                 ss (st i)
                 (? (peep seen i -1 >= 0 && !(any (s \ peep moved s -1 > seen i) ss)) (pass >l ch)
                    (: d (dt i)
                       lo (foldl (a \ s \ lvun a (lin s)) () ss)
                       li (lvun <d (filter (r9 \ (nelem r9 <>d)) lo))
                       old (lin i)
                       ch2 !(lvsame li old)
                       n (ck 'n + 1)
                       (pin ck 'n n,
                        pin seen i n,
                        ch2 ? (pin lin i li, pin moved i n) 0,
                        pin lot i lo,
                        pass >l (ch || ch2))))))
          (fix u9) (pass rl () ? (fix ()) 0)
          (bar9 ? 'no (fix (), [lin lot tx]))))
   (lvout g fs) ; index -> the registers live out of it | 'no
    (lvio g fs @ 'no 'no r <>r)
   ; the staging webs (x64, a64): a def of r0 and the reads it reaches, all explicit operands of plain
   ; forms inside the body, never live into a join, an exit or an unnamed read, become one mint
   ; bound to r0 that valloc may move. a web nothing reads stays (al before a variadic call)
   (wpos f)                                         ; -> [defs reads both] operand positions | ()
    (<f @ op
       (? (elem op '(li la laa)) [[1] () ()]
          (op = 'mov || elem op ldops9 || elem op leaops) [[1] [2] ()]
          (elem op xops || elem op aluops || elem op '(adds subs)) [[1] [2 3] ()]
          (op = 'set) [[2] () ()]
          (elem op gstops) [() [1 3] ()]
          (elem op stxops) [() [1 2 5] ()]
          (elem op siops) [() [1] ()]
          (elem op '(cmp test cmprm)) [() [1 2] ()]
          (op = 'cmpm) [() [1 3] ()]
          (elem op unops || elem op '(shl shr sar)) [() () [1]]
          (op = 'cmov) [() [3] [2]]
          (elem op x4ops) [() [2 3] [1]]
          (elem op m4ops) [() [2] [1]]
          ()))
   (vweb g hd body tl)
    (: R 'r0
       fs (hd + body + tl)
       k0 #hd
       k1 (#hd + #body)
       n #fs
       labt {}
       _ (foldl (i \ f \ ((two? f && <f = 'label ? (pin labt <>f i)), i + 1)) 0 fs)
       (succ f i) (: op (two? f ? <f 'x)
                     (? (op = 'jmp) [(peep labt <>f -1)]
                        (op = 'br) [(peep labt <>>f -1) (i + 1)]
                        (op = 'jmpt) (map (L \ (peep labt L -1)) (f 3))
                        (xit? f) ()
                        [(i + 1)]))
       ; one form's touch of R, [reads? defs?]: a call reads it by name or as an argument
       ; register (x64's al rides its own li)
       (eff f) (? !(two? f) [() ()]
                  (elem <f lvquiet) [() ()]
                  (elem <f '(call callr callm)) [(elem R >f || elem R (argr g)) 1]
                  (xjmp? f labt) [1 ()]
                  (lvtx g f [R] @ 'bar [1 ()] d [(elem R <d) (elem R <>d)]))
       ef {} sc {}
       _ (foldl (i \ f \ (pin ef i (eff f), pin sc i (succ f i), i + 1)) 0 fs)
       lin {}
       (pass i ch) (? (i < 0) ch
                      (: e (ef i)
                         lv (<e || (!(<>e) && foldl (a \ s \ a || peep lin s ()) () (sc i)))
                       (lv && !(lin i) ? (pin lin i 1, pass (i - 1) 1) (pass (i - 1) ch))))
       (fix9 _) (pass (n - 1) () ? (fix9 ()) 0)
       _ (fix9 ())
       (at f l) (filter (p \ f p = R) l)
       (rpos f) (: (go l k) (? !(two? l) () (<l = R) (k . go >l (k + 1)) (go >l (k + 1))) (go >f 1))
       sites {}                                      ; web -> ([i pos] ..)
       bad {}
       used {}
       (add w i ps) (map (p \ pin sites w ([i p] . peep sites w ())) ps)
       (walk i cur nw)
        (? (i >= n) nw
           (: f (fs i)
              e (ef i)
              ps (k0 <= i && i < k1 && two? f ? (wpos f) ())
              rp (two? f ? (rpos f) ())
              dp (two? ps ? (at f <ps))
              up (two? ps ? (at f (<>ps + <>>ps)))
              ok (two? ps && #rp = #dp + #up && (two? up || !(<e)) && (two? dp || two? <>>ps || !(<>e)))
              (? ok
                  (: _ (cur >= 0 && two? up ? (add cur i up, pin used cur 1))
                     (two? dp ? (add nw i dp, walk (i + 1) nw (nw + 1))
                        (walk (i + 1) cur nw)))
                 (: _ (cur >= 0 && (two? rp || <e || (elem <f '(jmp br jmpt label) && lin i)) ? (pin bad cur 1))
                    (walk (i + 1) (<>e || elem <f '(jmp jmpt label) || xit? f ? -1 cur) nw)))))
       nw (walk 0 -1 0)
       t (g 'vrt)
       vw (: t9 {} (pin g 'vweb t9, t9))
       sub {}                                        ; index -> ([pos mint] ..)
       _ (: (mk w) (? (w >= nw) ()
                      (bad w || !(used w)) (mk (w + 1))
                      (: k9 (peep g 'vrn 0)
                         m (name "%v\(k9)")
                       (pin g 'vrn (k9 + 1),
                        pin t m R,
                        pin vw m 1,
                        map (s \ pin sub <s ([<>s m] . peep sub <s ())) (sites w),
                        mk (w + 1))))
            (mk 0))
       (re f l) (two? l ? (re (reop f <<l <>(<l)) >l) f)
       (: (go l i) (two? l ? (re <l (peep sub i ()) . go >l (i + 1)))
          (go body k0)))
   ; the allocator core: a mint's register comes from interference, not pool order. liveness tracks
   ; only the mints and the file, a bit each, a call reading its arg file (lvnarrow). a def meets what
   ; lives past it (a mov not its source) and every operand but its first source (either, by vacomm).
   ; a mint meeting a name on its own register keeps it (an alias relied on). colours go copy partner,
   ; binding, then file. answers 1, or () when a mint has none (vrfix's rasg then keeps the binding)
   ; x64's rcx and rdx join, a64's x1-x3 (x4 is a4ize's): liveness already sees them
   (vafile g) (lvun (lvun (g 'pool0) (rafile g))
                    (? (abl? g 'vrcx) '(r0) (x64? g) '(r0 r1 r2) (a64? g) '(r0 r1 r2 r3) '(r0)))
   ; the ops whose dest may share the second source: x64's holo lays d = b as d op= a when
   ; the op commutes; a64's alu is three-address throughout
   (vacomm g) (a64? g ? '(add sub and or xor adds subs imul) '(add or and xor adds imul))
   (valloc g fs)
    (: t (g 'vrt)
       file (vafile g)
       cm9 (vacomm g)
       ix {}                                         ; name -> its bit
       nx {}
       (bit x) (: b (peep ix x 0)
                  (? (b != 0) b
                     !(nom? x && (vmint? g x || elem x file)) 0
                     (: k (peep ix 'n9 0)
                        b2 (1 << k)
                      (pin ix 'n9 (k + 1), pin ix x b2, pin nx b2 x, b2))))
       (bits l) (foldl (a \ x \ a | bit x) 0 l)
       (lows b) (b = 0 ? () (: lb (b & (0 - b)) (nx lb . lows (b - lb))))
       _ (map bit file)
       ; the staging webs colour last and latest first, so a web follows the copy it feeds
       ms (: (mw acc x) (? (two? x) (foldl mw acc x)
                           (vmint? g x && peep ix x 0 = 0) (bit x, (x . acc))
                           acc)
             m9 (foldl mw () fs)
             (rev (filter (m \ !(peep g 'vweb {} m)) m9) + filter (m \ peep g 'vweb {} m) m9))
       mm (bits ms)
       labt {}
       n (foldl (i \ f \ ((two? f && <f = 'label ? (pin labt <>f i)), i + 1)) 0 fs)
       (succ f i) (: op (two? f ? <f 'x)
                     (? (op = 'jmp) [(peep labt <>f -1)]
                        (op = 'br) [(peep labt <>>f -1) (i + 1)]
                        (op = 'jmpt) (map (L \ (peep labt L -1)) (f 3))
                        (xit? f) ()
                        [(i + 1)]))
       (pos f y) (: (go l k) (? !(two? l) -1 (<l == y) k (go >l (k + 1))) (go >f 1))
       rr {} dd {} bd {} sr {} sc {}
       pt {}                                         ; mint -> copy partners, latest first
       s0 {}                                         ; mint -> its r0 copy is stored (or parked) straight off
       (w1 l i)
        (? !(two? l) 1
           (: f <l
              d (? !(two? f) [() ()] (xjmp? f labt) [file ()] (lvtx g f file))
              (d @ 'bar ()
                 (: mv (<f = 'mov)
                  (pin rr i (bits <d),
                   pin dd i (bits <>d),
                   pin bd i (mv ? 0 (bits (filter (y \ pos f y != 2 && !(pos f y = 3 && elem <f cm9)) <d))),
                   pin sr i (mv ? (bit <>>f) 0),
                   pin sc i (succ f i),
                   (mv && vmint? g <>f ? (pin pt <>f (<>>f . peep pt <>f ()))),
                   (mv && vmint? g <>>f ? (pin pt <>>f (<>f . peep pt <>>f ()))),
                   (mv && vmint? g <>>f && <>f = 'r0 &&
                    (: nx9 (two? >l && <>l = '(sub sp sp 16) ? >>l >l)   ; a park's store sits past its sp step
                     (two? nx9 && two? <nx9 && <<nx9 = 'st && (<nx9 3) == 'r0)) ?
                      (pin s0 <>>f 1)),
                   w1 >l (i + 1))))))
       _ (pin g 'lvnarrow 1)
       ok1 (w1 fs 0)
       _ (pin g 'lvnarrow ())
       lin {} lot {}
       (pass i ch) (? (i < 0) ch
                      (: lo (foldl (a \ s \ a | peep lin s 0) 0 (sc i))
                         li (rr i | (lo - (lo & dd i)))
                       (pin lot i lo,
                        (li != peep lin i 0 ? (pin lin i li, pass (i - 1) 1) (pass (i - 1) ch)))))
       (fix9 _) (pass (n - 1) () ? (fix9 ()) 0)
       nb {}                                         ; mint -> neighbour bits
       (nbor m b) (pin nb m (peep nb m 0 | (b - (b & ix m))))
       (w2 i) (? (i >= n) 1
                 (: db (dd i)
                    lx (lot i - (lot i & sr i))
                  (db = 0 ? () (map (x \ nbor x (lx | db | bd i)) (lows (db & mm))),
                   (db = 0 ? () (map (y \ nbor y db) (lows ((lx | bd i) & mm)))),
                   w2 (i + 1))))
       sm (foldl (a \ m \ pin a (t m) (peep a (t m) (peep ix (t m) 0) | ix m)) {} ms)
       (fixed? m) (: P (t m) (nelem P file || (peep nb m 0 & peep sm P 0) - (peep nb m 0 & ix m) != 0))
       col {}
       (cof n9) (vmint? g n9 ? (col n9) n9)
       (pick m)
        (: forb (map cof (lows (peep nb m 0)))
           cs (filter (r \ nelem r forb) file)
           ; r0 dies fast: a stored value born there leaves stld and the park fold nothing to forward from
           ; the copy chain read through uncoloured mints, nearest first, a few hops deep
           (reach l seen k)
            (? (!(two? l) || k = 0) ()
               (: nx (filter (x \ nelem x seen) (foldl (a \ y \ a + (vmint? g y && !(col y) ? (peep pt y ()) ())) () l))
                  (map cof l + reach nx (seen + nx) (k - 1))))
           pp (filter (r \ elem r cs && !(r = 'r0 && s0 m)) (reach (peep pt m ()) [m] (x64? g || a64? g ? 4 1)))
           (? (two? pp) <pp (elem (t m) cs) (t m) (two? cs) <cs))
       (go l) (? !(two? l) 1
                 (col <l) (go >l)
                 (pick <l @ r (r ? (pin col <l r, go >l))))
       (ok1 &&
          (: _ (fix9 ())
             _ (w2 0)
             _ (map (m \ (fixed? m ? (pin col m (t m)))) ms)
             ((go ms) ? (map (m \ pin t m (col m)) ms, 1)))))
   ; the early assignment: valloc where it runs, before the frame is sized
   (vpre g hd body tl)
    (? (!(x64? g || a64? g) || abl? g 'valloc) body
       (: b2 ((x64? g || a64? g) && !(abl? g 'vweb) ? (vweb g hd body tl) body)
        ((peep g 'vrn 0 && valloc g (dp 'vweb (hd + b2 + tl)) ? (pin g 'vdone 1)),
         b2)))
   ; substitute every mint over prologue+body+epilogue: sibcall and soften read registers, so neither
   ; may meet a vreg. the assignment runs first
   (vrfix g fs)
    (!(peep g 'vrn 0) ? fs
       (: _ (g 'vdone ? () (rasg g fs))
          t (g 'vrt)
          (fix1 x) (two? x ? (map fix1 x) (t x @ p9 (p9 ? p9 x)))
          (sweep (f . u)) (f @ ('mov x x) (sweep u) (f . sweep u))
        (sweep (map fix1 fs))))

   ; recompute an alu value (x64, a64, off liveness): (op h a b) again with a, b unchanged in a straight
   ; run is (mov h2 h); a def taking h between, dead before the recompute, moves with its reads to an idle reg
   (recse g fs)
    (: lot (x64t? g || a64? g ? (lvout g fs) 'no)
       ; caller-saved regs (rcx too: rdsp names its implicit uses), then cs regs the fn already saves
       fr9 (filter (r \ nelem r '(r0 r2 r3 r4)) (lvgp g) +
            filter (r \ nelem r '(r3 r4) && vany (f \ two? f && two? >f && <>f == r && rdsp g f != 'bar && elem r <>(rdsp g f)) fs)
                   (csregs g))
       (jot2 a b) (map (+ a) (jot (b - a + 1)))
       (sp? f) (: d (two? f ? (rdsp g f) 'bar)
                  (d = 'bar ? () !(two? (filter (r \ nelem r >f) (<d + <>d)))))
       (alu? f) (two? f && elem <f '(add sub and or xor) && #f = 4 && nom? <>f && nom? <>>f &&
                 nelem <>f '(r0 r1 r2 r3) &&                    ; off the protocol: no unspelled read of h
                 (nom? <>>>f || charm? <>>>f) && <>f != <>>f && <>f != <>>>f && sp? f)
       ; forms after p -> [j k u]: the recompute's offset, the def of h between, its last read (or ()) | ()
       (scan p w)
        (: h <>p a <>>p b <>>>p
           (go l n k u)
            (!(two? l) || 16 < n ? ()
               (: f <l d (two? f ? (rdsp g f) 'bar)
                  (? (d = 'bar || elem <f '(label br jmp jmpr jmpt ret call callr callm sys)) ()
                     (<f = <p && #f = 4 && <>>f = a && <>>>f = b && nelem <>f [a b]) [n k u]
                     (elem a <>d || elem b <>d) ()
                     ; renamed by its dest field alone: an in-place op reads that field too
                     (elem h <>d) (k || <>f != h || 1 < #<>d || elem 'zq <(rdsp g (reop f 1 'zq)) ? ()
                                     (go >l (n + 1) n u))
                     (k && elem h <d) (elem h >f && nelem <f vshops ? (go >l (n + 1) k n))   ; a read renames where spelled
                     (go >l (n + 1) k u))))
           (go w 1 () ()))
       (go l i)
        (!(two? l) ? ()
           (: p <l
              r (alu? p ? (scan p >l))
              (!r ? (p . go >l (i + 1))
                 (: j <r k <>r u <>>r h <>p
                    ms (take (j + 1) l)
                    e (u || k)
                    ; F: named nowhere in the window, dead from before the def through its last read
                    used (foldl (acc \ f \ acc + <(rdsp g f)) () ms +                 ; read anywhere here, or
                          foldl (acc \ o \ acc + <>(rdsp g (ms o))) () (k ? (jot2 k e)))   ; written in the span
                    F (!k ? 1
                         (: (pick c) (? !(two? c) ()
                                        (elem <c used || vany (o \ elem <c (lot (i + o))) (jot2 (k - 1) e)) (pick >c)
                                        <c)
                            (pick fr9)))
                    (!F || k && elem h (lot (i + e)) ? (p . go >l (i + 1))
                       (: out (map (o \ ms o @ f
                                        (? (k && o = k) (reop f 1 F)
                                           (k && k < o && o <= e) (map (x \ (x = h ? F x)) f)
                                           (o = j) ['mov <>f h]
                                           f))
                                   (jot2 0 j))
                          h2 <>(ms j)
                          ; the recompute's own reads follow h until either moves (copyprop keeps off addresses)
                          (fw w n) (!(two? w) || 16 < n ? w
                                      (: f <w d (two? f ? (rdsp g f) 'bar)
                                         (d = 'bar || elem <f '(label br jmp jmpr jmpt ret call callr callm sys) ? w
                                            (: f2 (elem h2 <d && elem h2 >f && nelem <f vshops && nelem h2 <>d ?
                                                     (map (x \ (x = h2 ? h x)) f) f)
                                               (elem h <>d || elem h2 <>d ? (f2 . >w) (f2 . fw >w (n + 1)))))))
                          ; liveness was read before this rewrite: the rest of the block keeps its forms
                          (skip w n) (!(two? w) || two? <w && <<w = 'label ? (go w n) (<w . skip >w (n + 1)))
                          (out + skip (fw (drop (j + 1) l) 1) (i + j + 1))))))))
       (lot @ 'no fs (go fs 0)))

   ; the wide pair's shuffles, off liveness (x64, a64): a word built in r0 while the pair parks,
   ; then added with a zero high half, is built in the park:
   ;   (mov p r0)(mov q r2) S (li r2 0)(a128r p q) -> S[r0 := p] (a128r p 0)
   ; S straight-line, every register it touches spelled, r0 written before read, r2 p q untouched.
   ; and a pair shifted down 64 into a home lands its halves: (shr128 64)(mov a r0)(mov b r2) -> (mov a r2)(li b 0)
   (wpair g fs)
    (: lot (wreg? g ? (lvout g fs) 'no)
       (reg? x) (nom? x && nelem x '(sp fp r0 r2))
       (dead? rs i) !(two? (filter (r \ elem r (lot i)) rs))
       ; the run S up to (li r2 0)(a128r p q) -> its length, or () off the shape
       (run l p q n w)
        (!(two? l) || 12 < n ? ()
           (<l @ f
              (two? l && two? >l && f = '(li r2 0) && <>l = ['a128r p q] ? (w ? n ())
                 (: d (two? f ? (rdsp g f) 'bar)
                    rs (d @ 'bar () (<d + <>d))
                    (d = 'bar || two? (filter (r \ nelem r >f) rs) ||
                     two? (filter (r \ elem r ['r2 p q]) rs) ||
                     !w && elem 'r0 <d ?
                       ()
                       (run >l p q (n + 1) (w || elem 'r0 <>d)))))))
       (go l i)
        (!(two? l) ? ()
           (<l @ f
              (? (two? f && <f = 'mov && two? >l && <>>f = 'r0 && (<>l @ f2 (two? f2 && <f2 = 'mov && <>>f2 = 'r2)) &&
                  reg? <>f && reg? <><>l && <>f != <><>l)
                  (: p <>f q <><>l
                     n (run >>l p q 0 ())
                     (charm? n && dead? [p q] (i + 3 + n) ?
                         (map (h \ map (x \ (x = 'r0 ? p x)) h) (take n >>l) @ S
                            (S + [['a128r p 0]] + go (drop (n + 2) >>l) (i + 4 + n)))
                        (f . go >l (i + 1))))
                 (f = '(shr128 64) && two? >>l &&
                  (: m1 <>l m2 <>>l
                     (two? m1 && two? m2 && <m1 = 'mov && <m2 = 'mov && <>>m1 = 'r0 && <>>m2 = 'r2 &&
                      reg? <>m1 && reg? <>m2 && nelem <>m1 '(r0 r2) && nelem <>m2 '(r0 r2) && <>m1 != <>m2)) &&
                  dead? '(r0 r2) (i + 2))
                  ([['mov <><>l 'r2] ['li <><>>l 0]] + go >>>l (i + 3))
                 ; the pair's constants: a widened li is two, a known pair shifts up 64 by moving its lo, lo 0 adds its hi alone
                 (two? f && <f = 'li && <>f = 'r0 && charm? <>>f && two? >l && <>l = '(sx128))
                  (go (f . ['li 'r2 (<>>f < 0 ? -1 0)] . >>l) i)        ; same length: the indices hold
                 (two? f && <f = 'li && <>f = 'r0 && charm? <>>f && fitsw? <>>f && two? >>>l &&
                  (<>l @ f2 (two? f2 && <f2 = 'li && <>f2 = 'r2 && charm? <>>f2)) && <>>l = '(shl128 64) &&
                  (<>>>l @ f4 (two? f4 && <f4 = 'a128r && reg? <>f4 && reg? <>>f4)))
                  (<>>>l @ f4
                     ([['mov 'r0 <>f4] ['mov 'r2 <>>f4] ['add 'r2 'r2 <>>f]] + go >>>>l (i + 4)))
                 (two? f && <f = 'li && <>f = 'r0 && charm? <>>f && two? >>l &&
                  (<>l @ f2 (two? f2 && <f2 = 'li && <>f2 = 'r2 && charm? <>>f2)) && <>>l = '(shl128 64))
                  ([['li 'r0 0] ['li 'r2 <>>f]] + go >>>l (i + 3))
                 (f . go >l (i + 1)))))
       (lot @ 'no fs (go fs 0)))

   ; coalescing: a (mov D S) whose S dies here, defined by the form just before, is a misnamed def:
   ; the def takes D and the mov drops
   (coal? g p f i lo lot)
    (!(two? p && two? f && <f = 'mov && lo < i) ? ()
       (: S (f 2)
          D (f 1)
          d (rdsp g p)
          (d @ 'bar ()
             (<>d @ dfs
                ; the def names S alone, and reads it only where its dest is a pure write
                (two? dfs && !(two? >dfs) && <dfs = S && p 1 == S &&
                 (nelem S <d || (x64? g || a64? g) && !(abl? g 'coalrd) &&
                  (elem <p aluops || elem <p xops || elem <p ldops9 || elem <p leaops || elem <p '(mov adds subs))) &&
                 ; D a stranger to the def (the emitter refuses an aliased dest), but an alu's first source may be D
                 nelem D dfs &&
                 (nelem D <d || (elem <p aluops && p 2 == D)) &&
                 nelem S (lot i) && D != S)))))
   (coal g fs)
    (: lot (lvout g fs)
       lo 5                                         ; unframe needs nothing at index <= 4 to shift
       (lot @ 'no fs
          ; one form of lookbehind: a form is emitted when the next declines to fold into it
          (: ; a copy read nowhere ahead is a dead def (pre-rename lot stays conservative)
             (dead9? f i) (lo < i && two? f && hmov? f &&
                           nelem (f 1) (lot i))
             (rn l p i)
              (!(two? l) ? (two? p ? [p])
                 (<l @ f
                    (? (coal? g p f i lo lot) (reop p 1 (f 1) . rn >l () (i + 1))
                       ; a dropped copy keeps the lookbehind: the def and the next copy become adjacent
                       (dead9? f i) (rn >l p (i + 1))
                       (two? p) (p . rn >l f (i + 1))
                       (rn >l f (i + 1)))))
             (rn fs () 0))))

   ; slot repack: objects whose live windows (touch spans, widened over backedges to a fixpoint)
   ; never meet share one cell; an address-taken object lives to the last form. x64 and a64
   (repack g fs)
    (: slots (g 'slots)
       a6 (a64? g)
       ki (a6 ? 4 3)                           ; the frame's (sub sp sp K)
       fb (fbase g)
       pro (a6 ? (epim? >fs pro-a64) (pro4? fs))
       sf (fs ki)
       K (sf @ ('sub 'sp 'sp k) (charm? k ? k))
       ; a64's spmerge folds an outgoing-arg park into the frame's sub: the excess rides under the slots
       xk (a6 && charm? K ? (K - aup (peep g 'off 0) 16) 0)
       (!(two? slots) || arm? g && !a6 || abl? g 'repack || g 'hasasm || g 'sspf || !pro || !(charm? K) || xk < 0 ? fs
          (: obs {}                            ; base -> (size lo hi esc wordy? first-src)
             ; wordy?: every touch a full-word ld/st at the base; first-src: the first store's reg, () if a load came first
             tls {}                        ; base -> ((i op reg off)..) newest-first
             (touch b n i e9 k9 s9 op9 x9)             ; k9: 'st | 'ld | 'no (an unpromotable shape)
              (obs b @ w
                 (pin tls b ([i op9 s9 x9] . peep tls b ()),
                  pin obs b (two? w ? [n <>w i (w 3 || e9)
                                         (w 4 && k9 !== 'no) (w 5)]
                               [n i i e9 (k9 != 'no) (k9 @ 'st s9 ())])))
             labt {}
             (loose? e i bp) (? !(two? e) ()
                                (<e = fb && !(i = bp)) 1
                                (loose? >e (i + 1) bp))
             (scan l i sps)                            ; every frame touch noted -> the backward spans | 'no
              (!(two? l) ? sps
                 (<l @ f
                    (? !(two? f) (scan >l (i + 1) sps)
                       (<f = 'label) (pin labt <>f i, scan >l (i + 1) sps)
                       (<f = 'raw) 'no
                       (elem <f '(push pop)) (scan >l (i + 1) sps)
                       (elem <f '(mov lea) && (<>f = fb && <>>f = 'sp ||
                                                <>f = 'sp && <>>f = fb))
                        (scan >l (i + 1) sps)          ; the frame link movs (unframe strips them)
                       (: tg (<f @ 'jmp <>f 'br <>>f ())
                          li9 (tg ? (peep labt tg 'no9) 'no9)
                          sp2 (charm? li9 ? ([li9 i] . sps) sps)
                          bp (peep a4base <f -1)
                          (? (0 <= bp && f bp == fb)
                             ; uoff misses as -1, and a negative index counts from the tail: a miss means the op itself
                             (: X (peep uoff <f -1 @ u9 (u9 < 1 ? <f (f u9)))
                                o9 (obj9 slots X)
                                (? (loose? >f 1 bp) 'no
                                   (two? o9)
                                    (touch <o9 <>o9 i
                                           (elem <f (leaops + '(leax)))
                                           ; a cs save/restore wears a promotable temporary's exact shape: a cs mover never promotes
                                           (? !(<>o9 = 8 && X = <o9) 'no
                                              (<f = 'st)
                                               (elem (f 3) (csregs g) ? 'no 'st)
                                              (<f = 'ld)
                                               (elem (f 1) (csregs g) ? 'no 'ld)
                                              'no)
                                           (? (0 < vstw <f) (f 3)
                                              (0 < vsiw <f) (f 3)
                                              (0 < vldw <f) (f 1)
                                              ())
                                           <f X,
                                     scan >l (i + 1) sp2)
                                   (charm? X && (X = -8 || 0 <= X)) (scan >l (i + 1) sp2)
                                   'no))
                             (loose? >f 1 -1) 'no
                             (scan >l (i + 1) sp2))))))
             spans (scan fs 0 ())
             (spans @ 'no fs
                      (: n2 #fs
                         bases (keys obs)
                         ; an escape pins the window's tail to the last form
                         _ (foldl (_ \ b \ obs b @ w
                                             (w 3 ?
                                                (pin obs b [<w <>w n2 1 (w 4) (w 5)]) 0))
                                  0 bases)
                         (widen1 bs ch)
                          (!(two? bs) ? ch
                             (: b <bs w (obs b)
                                (grow ss lo hi)
                                 (!(two? ss) ? [lo hi]
                                    (<ss @ s
                                       (lo <= <>s && <s <= hi ?
                                          (grow >ss (<s < lo ? <s lo) (hi < <>s ? <>s hi))
                                          (grow >ss lo hi))))
                                r (grow spans <>w <>>w)
                                ch2 !(<r = <>w && <>r = <>>w)
                                (ch2 ? (pin obs b [<w <r <>r (w 3) (w 4) (w 5)]) 0,
                                 widen1 >bs (ch || ch2))))
                         _ (: (fix u) (widen1 bases () ? (fix ()) 0) (fix ()))
                         ; promotion, per def chain: stores group by the loads their reaching defs join; a chain
                         ; takes a seat free over its live range; a narrow cell's seat is canonical to its first load's extension
                         (shp9 b)                    ; the cell's one touch width | 0
                          (: (go l w) (!(two? l) ? w
                                         (: t <l op <>t rg (t 2) X (t 3)
                                            w2 (? (0 < vldw op) (vldw op)
                                                  (0 < vstw op) (vstw op)
                                                  (0 < vsiw op) (vsiw op) 0)
                                            (? (w2 = 0 || !(X = b) || 0 < w && !(w = w2)) 0
                                               ; a full-word cs mover: never promotes
                                               (w2 = 8 && (0 < vldw op || 0 < vstw op)
                                                && elem rg (csregs g)) 0
                                               (go >l w2))))
                             (go (tls b) 0))
                         scand (foldl (a \ b \ obs b @ w
                                                 (!(w 3) && 0 < shp9 b ? (b . a) a))
                                      () bases)
                         sc9 (vsucc fs)                           ; the form graph, once per fn
                         lio9 (two? scand ? (lvio g fs) 'no)
                         lot9 (lio9 @ 'no 'no r <>r)              ; index -> live-out, or the refusal
                         tx9 (lio9 @ 'no {} r (r 2))
                         (dft9 i) <>(tx9 i)                       ; index -> the regs it defines
                         ; calls by index, and the cs pool a crossing chain may take: regs this fn never
                         ; writes, and never in a jmpr fn (a restore before the indirect exit is the dispatch's hot path)
                         callt (: t {}
                                  (go l i) (!(two? l) ? t
                                              (<l @ f
                                                 (two? f && elem <f '(call callr callm sys) ? (pin t i 1) 0,
                                                  go >l (i + 1))))
                                  (go fs 0))
                         jrf (vany (f \ (two? f && <f = 'jmpr)) fs)
                         csf (a6 ? (csregs g) (csx g))
                         ep9 (a6 ? (peep g 'epi epi-a64) epi)
                         cswr (lot9 @ 'no ()
                                      (: t {}
                                         (each ^n2 (i \ foldl (_ \ r \ elem r (csregs g) ? (pin t r 1) 0) 0 (dft9 i)),
                                          t)))
                         cspool9 (jrf || lot9 = 'no ? ()
                                    (filter (r \ !(peep cswr r 0)) csf))
                         ; a cs reg the prologue already saves rides free: its dead ranges owe no new pair
                         csprd (jrf || lot9 = 'no ? ()
                                  (: t9 {}
                                     (go l i) (!(two? l) || (a6 ? 16 12) < i ? 0
                                                 (<l @ f9
                                                    (two? f9 && <f9 = 'st &&
                                                     (<>f9 = 'sp || <>f9 = fb) &&
                                                     elem (f9 3) csf ?
                                                       (pin t9 (f9 3) 1) 0,
                                                     go >l (i + 1))))
                                     (go fs 0,
                                      filter (r9 \ (peep t9 r9 0)) csf)))
                         taken {}                    ; index -> the seats promotion already holds
                         (pfree? tk r is9)
                          (!(two? is9) ? 1
                             (<is9 @ i
                                (? (elem r (lot9 i)) ()
                                   (elem r (dft9 i)) ()
                                   (elem r (tk i)) ()
                                   (pfree? tk r >is9))))
                         (pseat tk rs is9) (? !(two? rs) () (pfree? tk <rs is9) <rs (pseat tk >rs is9))
                         (pclaim tk r is9) (!(two? is9) ? 0
                                              (pin tk <is9 (r . peep tk <is9 ()),
                                               pclaim tk r >is9))
                         (span9 lo hi) (: (go i acc) (i < lo ? acc (go (i - 1) (i . acc))) (go hi ()))
                         succ9 (lot9 @ 'no {} sc9)
                         (xt9 op) (op @ 'ld4 'sx4 'ldu4 'zx4 'ld2 'sx2 'ldu2 'zx2 'ld1 'sx1 'ldu1 'zx1 ())
                         (pxv xc w k)                ; an si value, canonically extended at compile time
                          (8 <= w ? k
                             (: m ((8 * w) 2)
                                v (k % m @ r9 (r9 < 0 ? (r9 + m) r9))
                                (elem xc '(sx1 sx2 sx4) ? (m // 2 <= v ? (v - m) v) v)))
                         clvm {}                     ; base -> its cell liveness, walked once
                         (clv9 b lo hi sts lds)
                          (clvm b @ c
                             (two? c ? <c (vclive lo hi sc9 sts lds @ r (pin clvm b [r], r))))
                         (chains9 b)                 ; one cell -> ((S pref defs ((use dst ext)..) xc)..)
                          (: w (obs b)
                             tl (rev (tls b))
                             sts (map (t \ <t) (filter (t \ (0 < vstw <>t || 0 < vsiw <>t)) tl))
                             lds (map (t \ <t) (filter (t \ (0 < vldw <>t)) tl))
                             ot (foldl (t9 \ t \ pin t9 <t <>t) {} tl)
                             rg9 (foldl (t9 \ t \ pin t9 <t (t 2)) {} tl)
                             (rich us) (map (u \ [u (rg9 u) (xt9 (ot u))]) us)
                             (xcof us) (two? us ? (xt9 (ot <us)))
                             (? !(two? sts) ()
                                !(two? >sts)                 ; one def: one chain, no reaching needed
                                 (: lo0 <>w hi0 <>>w
                                    clv (clv9 b lo0 hi0 sts lds)
                                    S (: (go i acc)
                                         (i < lo0 ? acc
                                            (go (i - 1) (i = <sts || 0 < peep clv i 0 ? (i . acc) acc)))
                                         (go hi0 ()))
                                    [[S (rg9 <sts) sts (rich lds) (xcof lds)]])
                                (: lo0 <>w hi0 <>>w
                                   rt (vreach lo0 hi0 succ9 sts)
                                   gps <(vgroup rt sts lds)   ; the chains; a no-def load stays a frame read
                                   clv (clv9 b lo0 hi0 sts lds)
                                   st9 (foldl (t \ d \ pin t d 1) {} sts)
                                   (map (gp \ (: ds <gp us <>gp
                                                  dt9 (foldl (t \ d \ pin t d 1) {} ds)
                                                  ; live out of i with a chain def reaching out of i: the value rides the edge
                                                  S (: (go i acc)
                                                       (i < lo0 ? acc
                                                          (go (i - 1)
                                                              (? (peep dt9 i 0) (i . acc)
                                                                 !(0 < peep clv i 0) acc
                                                                 (peep st9 i 0) acc
                                                                 (two? (vboth (rt i) ds)) (i . acc)
                                                                 acc)))
                                                       (go hi0 ()))
                                                  [S (rg9 <ds) ds (rich us) (xcof us)]))
                                        gps))))
                         bylo (sortby (a \ b \ (<>(obs a)) < (<>(obs b))) scand)
                         pxm {}                      ; touch index -> (seat canonical-ext)
                         retid {}                    ; base -> every touch promoted, the cell retires
                         ; hull first: a cell the hull serves takes one seat over its span; only its refusals pay for chains
                         hullw (: t {}
                                  (go l) (!(two? l) ? t
                                            (: b <l w (obs b)
                                               (!(w 4 && w 5) ? 0
                                                  (: S (span9 <>w <>>w)
                                                     pf (w 5)
                                                     r (pseat taken (elem pf (lvgp g) ? (pf . lvgp g) (lvgp g)) S)
                                                     (!r ? 0
                                                        (pclaim taken r S,
                                                         foldl (_ \ t9 \ pin pxm <t9 [r ()]) 0 (tls b),
                                                         pin retid b 1))),
                                                go >l)))
                                  (lot9 @ 'no t (go bylo)))
                         csut {}                     ; the cs seats promotion actually took
                         (ctfree? r is9) (? !(two? is9) 1
                                            (elem r (taken <is9)) ()
                                            (ctfree? r >is9))
                         (cstake rs is9) (? !(two? rs) () (ctfree? <rs is9) <rs (cstake >rs is9))
                         _ (lot9 @ 'no 0
                                   (foldl (_ \ b \
                                            (: nrw (foldl (k \ c9 \
                                                           (: S <c9 pf <>c9 ds (c9 2) rus (c9 3) xc (c9 4)
                                                              r0 (pseat taken (elem pf (lvgp g) ? (pf . lvgp g) (lvgp g)) S)
                                                              ; a crossing chain may take a cs seat (taken-only freeness: the pair meets the exit's phantom read)
                                                              ; when the call weight repays the pair: 64 = a call at loop depth >= 2
                                                              rp9 (r0 ? () (pseat taken csprd S))
                                                              r (? r0 r0
                                                                   rp9 rp9
                                                                   !(two? cspool9) ()
                                                                   (: wc (foldl (a \ i \ peep callt i 0 ?
                                                                                           (a + vwt spans i) a)
                                                                                0 S)
                                                                      (wc < 64 ? () (cstake cspool9 S))))
                                                              (? !r k
                                                                 ; a load into the seat itself at another extension would wreck it
                                                                 (vany (u3 \ (<>u3 = r && u3 2 && u3 2 !== xc)) rus) k
                                                                 (pclaim taken r S,
                                                                  (elem r cspool9 ? (pin csut r 1) 0),
                                                                  foldl (_ \ i \ pin pxm i [r xc]) 0 ds,
                                                                  foldl (_ \ u3 \ pin pxm <u3 [r xc]) 0 rus,
                                                                  k + #ds + #rus))))
                                                          0 (chains9 b))
                                               (nrw = tally (tls b) ? (pin retid b 1) 0)))
                                          0 (filter (b \ !(retid b)) bylo)))
                         lsc9 {}                     ; a cell -> [its live indices], for the regions and the packing
                         (lsm9 b) (lsc9 b @ v (two? v ? <v (: r (lset9 b) (pin lsc9 b [r], r))))
                         ; loop regions: a full-word cell no chain seated rides a caller-saved seat inside one
                         ; loop, loaded where control enters it live, stored where it leaves live when the loop
                         ; writes it, and stored and reloaded across a call it is live across
                         (rpass9 _)                  ; -> [bfr aft], the moves the regions lay | ()
                          (: (sfree? tk r is9)        ; a caller-saved seat is free wherever no call is; a call's clobber, the pair's to meet
                             (: (go l) (? !(two? l) 1
                                          (<l @ i
                                             (? (elem r (lot9 i)) ()
                                                (elem r (tk i)) ()
                                                (peep callt i 0) (go >l)
                                                (elem r (dft9 i)) ()
                                                (go >l))))
                                (go is9))
                            (sseat tk rs is9) (? !(two? rs) () (sfree? tk <rs is9) <rs (sseat tk >rs is9))
                            bfr {}                      ; index -> the cell moves laid before it, at the cell's own offset
                            aft {}                      ; index -> those laid after it
                            spb {}                      ; a cell a moved value keeps
                            (lay9 t i f) (pin t i (vapp (peep t i ()) [f]))
                            vwm9 {}                     ; index -> its loop weight, each laid once
                            (vw9 i) (: c (peep vwm9 i 0) (0 < c ? c (: w (vwt spans i) (pin vwm9 i w, w))))
                            fam9 {}                     ; 'f -> [the forms by index], laid on a region's first ask
                            (fat9 i) (fam9 'f @ v
                                        (two? v ? (<v i)
                                           (: t {} (go l k) (!(two? l) ? t (pin t k <l, go >l (k + 1)))
                                              t9 (go fs 0)
                                              (pin fam9 'f [t9], t9 i))))
                            (uncond? f) (two? f && (elem <f '(jmp jmpt jmpr ret) || exit9? f))
                            (tgt9 f) (two? f ? (<f @ 'jmp <>f 'br <>>f ()))
                            (ti f) (tgt9 f @ t (nom? t ? (peep labt t -1) -1))
                            ; one walk of the fn: its jumps [from to], and the forms no region may span
                            (walk9 l k js bs)
                             (!(two? l) ? [(rev js) (rev bs)]
                                (: f <l t (ti f)
                                   (walk9 >l (k + 1) (0 <= t ? ([k t] . js) js)
                                           (two? f && elem <f '(jmpt jmpr raw asm sys) ? (k . bs) bs))))
                            jb9 (walk9 fs 0 () ())
                            rinm {}                     ; lo -> the region's edges | 'no
                            (rinf sp)
                             (rinm <sp @ c
                                (two? c ? <c
                                   (: lo <sp hi <>sp
                                      (inr? i) (lo <= i && i <= hi)
                                      bad (vany inr? <>jb9)
                                      (edge j) [<j 'pre <>j]
                                      e0 [(map edge (filter (j \ !(inr? <j) && inr? <>j) <jb9))
                                          (map edge (filter (j \ inr? <j && !(inr? <>j)) <jb9))]
                                      ft (0 < lo && !(uncond? (fat9 (lo - 1))) ? [[(lo - 1) 'post lo]])
                                      fx (!(uncond? (fat9 hi)) && hi + 1 < n2 ? [[hi 'post (hi + 1)]])
                                      r9 (bad ? 'no [(ft + <e0) (fx + <>e0) (filter (i \ peep callt i 0) (span9 lo hi))])
                                      (pin rinm lo [r9], r9))))
                            (rgn1 b lv ins wr sp xc lop sop)
                             (rinf sp @ ri9
                                (ri9 @ 'no ()
                                   (: lo <sp hi <>sp ents <ri9 exs <>ri9 cls <>>ri9
                                      en (filter (e \ peep lv (e 2) 0) ents)
                                      ex (wr ? (filter (e \ peep lv (e 2) 0) exs) ())
                                      cl (filter (i \ peep lv i 0) cls)
                                      kk (a6 ? ki 4)
                                      tw (foldl (a \ t \ a + vw9 <t) 0 ins)
                                      cw (foldl (a \ e \ a + vw9 <e) 0 (en + ex) +
                                          foldl (a \ i \ a + (wr ? 2 1) * vw9 i) 0 cl)
                                      (eok? r) !(vany (e \ !(kk < <e && !(elem r (lot9 <e)) && !(elem r (taken <e)))) en)
                                      ; ..or a callee-saved one the fn never writes: no pair at a call, but its save and restore
                                      ; run on every invocation, looping or not, so it must repay them by a loop's worth (64)
                                      cw2 (foldl (a \ e \ a + vw9 <e) 0 (en + ex) + 64)
                                      (cok? r) !(vany (e \ !(kk < <e && !(elem r (taken <e)))) en)
                                      (? (!(two? ins) || (tw <= cw && tw <= cw2)) ()
                                         ; a load into the seat itself at another extension would wreck it
                                         (: (dok? r) !(vany (t \ 0 < vldw <>t && t 2 = r && xt9 <>t !== xc) ins)
                                            ri (span9 lo hi)
                                            ra (cw < tw ? (sseat taken (filter (r \ eok? r && dok? r) (lvgp g)) ri))
                                            rc (ra || tw <= cw2 ? () (cstake (filter (r \ cok? r && dok? r) cspool9) ri))
                                            r (ra || rc)
                                            (!r ? ()
                                               (pclaim taken r (ri + map (e \ <e) en),
                                                (rc ? (pin csut rc 1) 0),
                                                pin spb b 1,
                                                foldl (_ \ t \ pin pxm <t [r xc]) 0 ins,
                                                foldl (_ \ e \ lay9 (<>e = 'pre ? bfr aft) <e [lop r fb b]) 0 en,
                                                foldl (_ \ e \ lay9 (<>e = 'pre ? bfr aft) <e [sop fb b r]) 0 ex,
                                                (ra ? (foldl (_ \ i \ ((wr ? (lay9 bfr i [sop fb b r]) 0), lay9 aft i [lop r fb b])) 0 cl) 0),
                                                1)))))))
                            (rgn9 b sw)                 ; sw: the loops, widest first
                             (: lv (foldl (t \ i \ pin t i 1) {} (lsm9 b))
                                tl (tls b)
                                ; a narrow cell's seat is canonical to its first load's extension, as a chain's
                                w (shp9 b)
                                x0 (filter (t \ 0 < vldw <>t) (rev tl))
                                xc (? (w = 8) () (two? x0) (xt9 <><x0) (w @ 4 'zx4 2 'zx2 1 'zx1 ()))
                                lop (xc @ 'zx4 'ldu4 'sx4 'ld4 'zx2 'ldu2 'sx2 'ld2 'zx1 'ldu1 'sx1 'ld1 'ld)
                                sop (w @ 4 'st4 2 'st2 1 'st1 'st)
                                (go ss) (!(two? ss) ? ()
                                           (: lo <<ss hi <><ss
                                              ins (filter (t \ lo <= <t && <t <= hi) tl)
                                              wr (vany (t \ 0 < vstw <>t || 0 < vsiw <>t) ins)
                                              (two? ins && rgn1 b lv ins wr <ss xc lop sop || go >ss)))
                                (go sw))
                            inl9 (foldl (t \ sp \ foldl (_ \ i \ pin t i 1) t (span9 <sp <>sp)) {} spans)   ; an index inside a loop
                            cd (filter (b \ !(retid b) && !(spb b) && 0 < shp9 b && vany (t \ peep inl9 <t 0) (tls b) &&
                                         !(vany (t \ two? (peep pxm <t ())) (tls b))) bylo)
                            (!(two? cd) ? ()
                               (: sw (sortby (x \ y \ (<>y - <y) < (<>x - <x)) spans)
                                  n (foldl (a \ b \ a + (rgn9 b sw ? 1 0)) 0 cd)
                                  (0 < n ? [bfr aft]))))
                         rg9 (lot9 @ 'no ()
                                (abl? g 'creg || jrf || !(x64? g || a6) || !(two? spans) ? () (rpass9 0)))
                         prom (keys pxm)
                         ; a cell's occupancy: vclive's exact indices when every touch is a ld/st/si at its own base;
                         ; any other use (cmpm, an escape) keeps the window
                         (exact9? b)
                          (obs b @ w
                             (w 3 || abl? g 'setpack || <w != 8 ? 0
                                (foldl (a \ t \ a && t 3 = b &&
                                                (0 < vldw <>t || 0 < vstw <>t || 0 < vsiw <>t))
                                       1 (tls b))))
                         (lset9 b)
                          (: w (obs b)
                             tl (rev (tls b))
                             sts (map (t \ <t) (filter (t \ (0 < vstw <>t || 0 < vsiw <>t)) tl))
                             lds (map (t \ <t) (filter (t \ (0 < vldw <>t)) tl))
                             clv (clv9 b <>w <>>w sts lds)
                             st9 (foldl (t \ d \ pin t d 1) {} sts)
                             (go i acc) (i < <>w ? acc
                                           (go (i - 1) (st9 i || 0 < peep clv i 0 ? (i . acc) acc)))
                             (go <>>w ()))
                         ex9 (filter (b \ !(retid b) && exact9? b) bases)
                         ls9 (foldl (t \ b \ pin t b (lsm9 b)) {} ex9)
                         ext9 (foldl (t \ b \ pin t b 1) {} ex9)
                         rows (sortby (a \ b \ <a < <b)
                                      (map (b \ (obs b @ w [<>w b <w <>>w]))
                                           (filter (b \ !(retid b)) bases)))
                         nmap {}                     ; base -> its packed seat
                         ; a seat takes a tenant none of its tenants meets (tenants may overlap: no free list)
                         seats9 {}                   ; 'l -> the 8-byte seats laid, newest first
                         ten9 {}                     ; seat -> its tenants' occupancies
                         (occ9 b lo hi) (ext9 b ? ['st (ls9 b)] ['iv lo hi])
                         (hits? a c)
                          (? (<a = 'iv && <c = 'iv) (<>a <= c 2 && <>c <= a 2)
                             (<a = 'st && <c = 'st) (two? (vboth <>a <>c))
                             (<a = 'st) (vany (i \ (<>c <= i) && i <= (c 2)) <>a)
                             (vany (i \ (<>a <= i) && i <= (a 2)) <>c))
                         (fit9 o oc) !(foldl (x \ t \ x || hits? oc t) 0 (ten9 o))
                         (seat9 oc) (: (go l) (atom? l ? () (fit9 <l oc ? <l (go >l)))
                                       (go (seats9 'l)))
                         (place rs high)                     ; sweep by lo -> the packed high-water
                          (atom? rs ? high
                             (: r1 <rs lo <r1 b <>r1 n (r1 2) hi (r1 3)
                                oc (occ9 b lo hi)
                                o9 (n = 8 ? (seat9 oc) ())
                                pr (!(o9 = ()) ? [o9 high]
                                      (: h1 (16 <= n &&
                                             !(((0 - (high + n)) & 15) = (b & 15)) ?
                                               (high + 8) high)
                                         [(0 - (h1 + n)) (h1 + n)]))
                                (pin ten9 <pr (oc . peep ten9 <pr ()),
                                 n = 8 && nelem <pr (seats9 'l) ?
                                   (pin seats9 'l (<pr . peep seats9 'l ())) 0,
                                 pin nmap b <pr,
                                 place >rs <>pr)))
                         high2 (place rows 8)
                         ; the cs seats' save slots below the packed high water; one pair per seat
                         csused (filter (r \ (peep csut r 0)) cspool9)
                         cslot (: t {}
                                  (go l k) (!(two? l) ? t
                                              (pin t <l (0 - (high2 + 8 * k)),
                                               go >l (k + 1)))
                                  (go csused 1))
                         csaves (map (r \ ['st fb (peep cslot r 0) r]) csused)
                         csrests (map (r \ ['ld r fb (peep cslot r 0)]) csused)
                         K2 (aup high2 16 + xk)
                         K3 (two? csused ? (aup (high2 + 8 * tally csused) 16 + xk) K2)
                         ; a jmp off the label table is a sibcall; so is one to the entry label (a self tail call)
                         (exit9? f) (xit? f || xjmp? f labt ||
                                     two? f && <f = 'jmp && 0 = peep labt <>f -1)
                         (tearx? l) (!(two? l) ? 0                        ; teardown straight to an exit?
                                       (<l @ f
                                          (? (exit9? f) 1
                                             !(two? f) 0
                                             (elem f (butret ep9) ||
                                              <f = 'add && <>f = 'sp && <>>f = 'sp) (tearx? >l)
                                             0)))
                         (radj2 f op9)                       ; a mapped touch -> its packed spelling
                          (: X (f op9)
                             o9 (obj9 slots X)
                             nb (two? o9 ? (peep nmap <o9 'no9) 'no9)
                             (!(charm? nb) ? f (reop f op9 (nb + (X - <o9)))))
                         (prw f i)                           ; a promoted touch -> its forms (() drops whole) | 'no
                          (pxm i @ rec
                             (!(two? rec) ? 'no
                                (: r <rec xc <>rec op <f
                                   (? (0 < vsiw op)
                                       [['li r (pxv xc (vsiw op) (f 3))]]
                                      (0 < vstw op)
                                       (: m9 (f 3 != r ? [['mov r (f 3)]])
                                          (vstw op < 8 && !(xc = ()) ? (vapp m9 [[xc r]]) m9))
                                      (: d (f 1)
                                         xl (xt9 op)
                                         m9 (d = r ? () [['mov d r]])
                                         (!(xl = ()) && xl != xc ? (vapp m9 [[xl d]]) m9))))))
                         (rw l i inr)
                          (two? l ?
                             (: f <l
                                t9 (two? csused ? (tearx? l) 0)
                                spl (t9 && !inr ? csrests)
                                p (two? f && ki < i && two? prom ? (prw f i) 'no)
                                (adj9 c) (radj2 c (0 < vstw <c ? 2 3))
                                pre9 (two? rg9 ? (map adj9 (peep <rg9 i ())))
                                pst9 (two? rg9 ? (map adj9 (peep <>rg9 i ())))
                                (p @ 'no
                                     (: f2 (? !(two? f) f
                                              (i = ki) ['sub 'sp 'sp K3]
                                              (peep a4base <f -1 @ bp
                                                 ((0 <= bp && f bp == fb) ?
                                                    (radj2 f (peep uoff <f -1)) f)))
                                        (i = (a6 ? ki 4) && two? csused ?
                                           (vapp spl (f2 . vapp csaves (rw >l (i + 1) t9)))
                                           (vapp spl (vapp pre9 (f2 . vapp pst9 (rw >l (i + 1) t9))))))
                                     (vapp spl (vapp pre9 (vapp p (vapp pst9 (rw >l (i + 1) t9))))))))
                         ; the packed map replaces the build's for later slot readers (deadst); promoted or retired
                         ; objects have no cell, the cs save slots are their own
                         slots2 (foldl (a2 \ o \ peep nmap <o 'no9 @ nb
                                                   (charm? nb ? ([nb <>o] . a2) a2))
                                       (map (r \ [(peep cslot r 0) 8]) csused)
                                       slots)
                         (K2 < K || two? prom ? (pin g 'slots slots2, rw fs 0 0) fs))))))

   ; dead label regions: a form after an unconditional transfer drops until a still-referenced
   ; label (refs = every symbol operand, over-approximate); a dropped region takes its refs with it
   ; every nom among ops pinned into t; nested operands (a raw splice's forms) scan whole
   (pinnoms t ops) (!(two? ops) ? 0 (<ops @ o ((? (nom? o) (pin t o 1) (two? o) (pinnoms t o)), pinnoms t >ops)))
   ; ks seeds the refs: names a fn's asm uses from another section (an asm goto's target in a jump
   ; table, which no code jumps to)
   (deadlab fs) (deadlabk {} fs)
   (deadlabk ks fs) (deadlab1 ks fs @ r (#r = #fs ? r (deadlabk ks r)))
   (deadlab1 ks fs)
    (: ; a label is live once a live form names it, so a dead loop's back edge keeps nothing; from ks to a fixpoint
       (live R) (: t (foldl (t \ k \ pin t k 1) {} (keys ks))
                   (walk l dead) (two? l ?
                                    (<l @ f
                                       (? (two? f && <f = 'label) (walk >l (dead && !(R <>f)))
                                          dead (walk >l 1)
                                          (two? f ? (pinnoms t >f),
                                           walk >l (xit? f || two? f && elem <f '(jmp jmpt))))))
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
                 (f . sweep >l (xit? f || two? f && elem <f '(jmp jmpt))))))
       (sweep fs 0))

   ; an idle cs seat: a borrowed x64 cs reg untouched but for its save and restores owes neither.
   ; x64, past cskeep
   (csdrop g fs)
    (: (sv? f r) (two? f && <f = 'st && <>f = 'sp && f 3 == r)
       (rs? f r) (two? f && <f = 'ld && <>f = r && <>>f = 'sp)
       (idle? r) (vany (f \ sv? f r) fs &&
                  !(vany (f \ two? f && elem r >f && !(sv? f r || rs? f r)) fs))
       dr (x64t? g && !(g 'hasasm) && !(vany (f \ two? f && elem <f '(raw asm)) fs) ?
             (filter idle? (csx g)))
       (!(two? dr) ? fs
          (filter (f \ !(vany (r \ sv? f r || rs? f r) dr)) fs)))

   ; the callee-saved contract, held at emission: a cs reg written anywhere must be saved before
   ; its first write and restored by every exit. an op on neither rdsp nor csquiet refuses
   csquiet '(label align ud2 trap br jmp jmpr jmpt ret call callr callm sys mulo   ; trap = a64's brk #0, ud2's twin
             sx128 n128 a128 a128r s128 s128r m128 m128r mw128 mw128r c128 c128r
             dv128 rm128 inc128 dec128 shl128 shr128 sar128 shl128v shr128v sar128v)
   (csdefs g f)                                       ; the cs regs one form writes | 'dark
    (? (elem <f csquiet) ()
       (elem <f divops) (filter (r \ elem r (csregs g)) [<>f])   ; idiv self-saves r2: its dst only
       (rdsp g f @ rd
          (rd @ 'bar 'dark
                (filter (r \ elem r (csregs g)) <>rd))))
   (cskeep g fs)                                    ; answers fs; a breach scares, naming fn + reg
    (: (rawy? (f . l)) (two? f && <f = 'raw ? 1 (rawy? l))
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
             ; a fn no path leaves owes nothing back (deadlab took its epilogue, deadst its saves)
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
                    fs))))))

   ; the door set a call or a tail jump kills: caller-saved, never an argument (a64 args ride r0-r7,
   ; x64's al is li'd by setal first); a wasm call writes only r0 r1, so its locals ride it
   (doors g tail) (? (a64? g) '(r9 r10 r11 r12 r13 r14 r15)
                     (rv64? g) (wasm? g && !tail ? () '(r8 r9 r10 r11 r12))
                     (ia32? g) '(r0 r1 r2)
                     '(r0 r9 r10))
   ; a jump's target is a function (a sibcall) when its spelling has no dot: gen's own labels lead
   ; with one, and a C label is spelled fn.label (a goto) -- neither is an exit
   (fsym? x) (findsub (show x) "." < 0)
   ; dies on the straight line: overwritten before any read. a ret rides only r0 out; a call or
   ; sibcall jmp kills the door set
   (dies? g rd (f . l))
    (two? f ?
       (rdsp g f @ rs
          (? (rs = 'bar)
              (? (retx? f) (rd != 'r0)
                 (elem <f '(call callr callm)) (elem rd (doors g 0))
                 (<f = 'jmp && fsym? <>f) (elem rd (doors g 1))
                 ())
             (elem rd <rs) ()
             (elem rd <>rs) 1
             (dies? g rd l))))
   ; the addressing fold: an add/lea/mov consumed as the next load/store's base folds into its
   ; displacement; a live dest keeps the addr insn beside the re-based form. to a fixpoint, x64 only
   (addrf1 g all fs)
    (two? fs ?
       (: f <fs r >fs
          ; dead beyond: straight-line first, then the branching proof (a loop's back edge stops dies?)
          (dead9 rd rest) (dies? g rd rest || dieb? g rd all rest)
          nx (two? r ? <r)
          ; the fused next form stands in for the pair; the addr insn stays beside it while its dest lives
          (fuse j) (<>nx = <>f || dead9 <>f >r ? (j . addrf1 g all >r) (f . j . addrf1 g all >r))
          ; a leax feeding the next load's base is the indexed load, x64's float loads too (base/index may
          ; alias a dying dest)
          lx (? !(two? f && <f = 'leax && two? nx  &&
                  (elem <nx '(ld ldu1) || x64? g && !(abl? g 'ldxw) && elem <nx '(ldu4 ld4) || fidx? g && elem <nx fldops)) ()
                (<>>nx != <>f) ()
                !(charm? <>>>nx && charm? (f 5)) ()
                [(<nx @ 'ld 'ldx 'ldu1 'ldxb 'ldu4 'ldxw 'ld4 'ldxsw 'ldsd 'ldsdx 'ldssx) <>nx <>>f <>>>f (f 4)
                  (f 5 + <>>>nx)])
          ; ..and a store through the leax's dest further down (x64): the window between may not read or
          ; write the dest, write its base or index, nor bar (a label, a call)
          sw (? (two? lx || !(fidx? g) || !(two? f && <f = 'leax)) ()
                (elem (f 2) '(sp r4) || elem (f 3) '(sp r4)) ()   ; a frame address: sp moves under a park
                (f 1 = f 2 || f 1 = f 3) ()             ; the dest is its own base or index: the makers move
                (: D (f 1) b (f 2) i (f 3)
                   (scan l k acc)
                    (!(two? l) || 24 < k ? ()
                       (<l @ g9
                          (? !(two? g9) ()
                             (elem <g9 '(st st1 stsd stss) && <>g9 = D && charm? <>>g9 && <>>>g9 != D)
                              [(rev acc) g9 >l]
                             (elem <g9 '(push pop) || <>g9 = 'sp) ()   ; sp motion: the window closes
                             (rdsp g g9 @ rd
                                (? (rd = 'bar) ()
                                   (elem D <rd) ()
                                   (elem D <>rd || elem b <>rd || elem i <>rd) ()
                                   (scan >l (k + 1) (g9 . acc)))))))
                   (scan r 0 ())))
          ; leax feeding a store's base is the indexed store (the value must not be the leax's dest)
          sx (? (two? lx) ()
                !(two? f && <f = 'leax && two? nx &&
                  (elem <nx '(st st1) || fidx? g && elem <nx fstops)) ()
                (<>nx != <>f) ()
                !(charm? <>>nx && charm? (f 5)) ()
                (<>>>nx = <>f) ()
                [(<nx @ 'st 'stx 'st1 'stxb 'stsd 'stsdx 'stssx) <>>f <>>>f (f 4)
                  (f 5 + <>>nx) <>>>nx])
          hit (? (two? lx || two? sx) ()
                 !(two? f && two? nx  && elem <nx ldops9) ()
                 (<>>nx != <>f) ()               ; the load's base is f's dest
                 (<>f = 'fp) ()                  ; riscv's (lea fp sp 0): a slot stays on the frame base
                 !(charm? <>>>nx) ()
                 (elem <f '(lea lean))
                  (charm? <>>>f ? [<>>f (<>>>f + <>>>nx)])
                 (<f = 'add)
                  (charm? <>>>f && <>>f != 'sp && fits32 (<>>>f + <>>>nx) ?
                     [<>>f (<>>>f + <>>>nx)])
                 (<f = 'sub)
                  (charm? <>>>f && <>>f != 'sp && fits32 (<>>>nx - <>>>f) ?
                     [<>>f (<>>>nx - <>>>f)])
                 (<f = 'mov) [<>>f <>>>nx]
                 ())
          ; the store twin: f's dest as the store's base (operand 1; the value must not be f's dest)
          sh (? (two? lx || two? sx || two? hit) ()
                !(two? f && two? nx && (elem <nx stops9 || elem <nx siops)) ()
                (<>nx != <>f) ()
                (<>f = 'fp) ()
                !(charm? <>>nx) ()
                (<>>>nx = <>f) ()
                (elem <f '(lea lean))
                 (charm? <>>>f ? [<>>f (<>>>f + <>>nx)])
                (<f = 'add)
                 (charm? <>>>f && <>>f != 'sp && fits32 (<>>>f + <>>nx) ?
                    [<>>f (<>>>f + <>>nx)])
                (<f = 'sub)
                 (charm? <>>>f && <>>f != 'sp && fits32 (<>>nx - <>>>f) ?
                    [<>>f (<>>nx - <>>>f)])
                (<f = 'mov) [<>>f <>>nx]
                ())
          ; the value twin: a mov whose dest rides only the store's value operand renames it
          vh (? (two? lx || two? sx || two? hit || two? sh) ()
                !(two? f && <f = 'mov && !(charm? <>>f) && two? nx && elem <nx gstops) ()
                (<>>>nx != <>f) ()
                (<>nx = <>f) ()
                [<nx <>nx <>>nx <>>f])
          ; a li riding only the value operand is the store-immediate (x64 only: none elsewhere)
          vi (? (two? lx || two? sx || two? hit || two? sh || two? vh) ()
                (arm? g) ()
                !(two? f && <f = 'li && charm? <>>f && two? nx && elem <nx gstops) ()
                (<>>>nx != <>f) ()
                (<>nx = <>f) ()
                (: k <>>f s9 (sik <nx k)
                 (s9 ? [s9 <>nx <>>nx k])))
          ; a li negated in place is the negative li -- the constant lanes then see it
          ng (? (two? lx || two? sx || two? hit || two? sh || two? vh || two? vi) ()
                !(two? f && <f = 'li && charm? <>>f && two? nx && <nx = 'neg && <>nx = <>f) ()
                ['li <>f -<>>f])
          ; a label's address plus a constant is one rip-relative lea (x64; &tab[k] off a global), on i386 one mov
          lk (? (two? lx || two? sx || two? hit || two? sh || two? vh || two? vi || two? ng) ()
                !((x64? g || ia32? g) && !(abl? g 'laa) && two? f && <f = 'la && two? nx && <nx = 'add) ()
                (<>nx != <>f || <>>nx != <>f) ()
                !(charm? <>>>nx && fits32 <>>>nx) ()
                (: n2 (two? >r ? <(>r))     ; the add's flags: none may be read after it
                   (two? n2 && elem <n2 '(br set cmov adc sbb) ? () ['laa <>f <>>f <>>>nx])))
          ; a constant index folds into the displacement, the indexed form collapsing to plain
          xj (? (two? lx || two? sx || two? hit || two? sh || two? vh || two? vi || two? ng || two? lk) ()
                !(two? f && <f = 'li && charm? <>>f && two? nx) ()
                (elem <nx '(ldx ldxb leax ldsdx ldssx))
                 (nx 5 + <>>f * nx 4 @ d9
                    (? (<>>>nx != <>f) () (<>>nx = <>f) ()
                       !(fits32 d9) ()
                       (<nx = 'leax && !(imma g 'add d9)) ()   ; the lea lands as an add imm
                       [(<nx @ 'ldx 'ld 'ldxb 'ldu1 'ldxw 'ldu4 'ldxsw 'ld4 'ldsdx 'ldsd 'ldssx 'ldss 'lea) <>nx <>>nx d9]))
                (elem <nx '(stx stxb stsdx stssx))
                 (nx 4 + <>>f * <>>>nx @ d9
                    (? (<>>nx != <>f) () (<>nx = <>f) () (nx 5 = <>f) ()
                       !(fits32 d9) ()
                       [(<nx @ 'stx 'st 'stxb 'st1 'stsdx 'stsd 'stss) <>nx d9 (nx 5)])))
          ; a constant right operand rides the alu/cmp imm forms (cfoldir's knowns are green-only)
          aj (? (two? lx || two? sx || two? hit || two? sh || two? vh || two? vi || two? ng || two? xj) ()
                !(two? f && <f = 'li && charm? <>>f && fits32 <>>f && two? nx) ()
                (elem <nx aluops)
                 (<>>>nx = <>f ? (? (<>>nx = <>f) () (imma g <nx <>>f) [<nx <>nx <>>nx <>>f]))
                (<nx = 'cmp)
                 (<>>nx = <>f ? (? (<>nx = <>f) () (imma g 'cmp <>>f) ['cmp <>nx <>>f])))
          (? (two? sw && !(two? sx))
              (: win <sw st9 <>sw after <>>sw
                 new [(<st9 @ 'st 'stx 'st1 'stxb 'stsd 'stsdx 'stssx) <>>f <>>>f (f 4) (f 5 + <>>st9) <>>>st9]
                 r2 (win + (new . after))
                 (dead9 <>f after ? (addrf1 g all r2) (f . addrf1 g all r2)))
             (two? lx)
              (? (<>nx = <>f || dead9 <>f >r) (lx . addrf1 g all >r)
                 !(<>f = <>>f || <>f = <>>>f)
                  (f . lx . addrf1 g all >r)
                 !(<>nx = <>>f || <>nx = <>>>f)
                  (lx . f . addrf1 g all >r)
                 (f . addrf1 g all r))
             (two? sx)
              (? (dead9 <>f >r) (sx . addrf1 g all >r)
                 !(<>f = <>>f || <>f = <>>>f)
                  (f . sx . addrf1 g all >r)
                 (sx . f . addrf1 g all >r))
             (two? hit)
              ([<nx <>nx <hit <>hit] @ nl
                 (? (<>nx = <>f || dead9 <>f >r) (nl . addrf1 g all >r)
                    (<>f != <hit) (f .  nl . addrf1 g all >r)
                    (nl . f . addrf1 g all >r)))
             (two? sh)
              ([<nx <sh <>sh <>>>nx] @ nl
                 (? (dead9 <>f >r) (nl . addrf1 g all >r)
                    (<>f != <sh) (f . nl . addrf1 g all >r)
                    (nl . f . addrf1 g all >r)))
             (two? vh)
              (dead9 <>f >r ? (vh . addrf1 g all >r)
                 (f . vh . addrf1 g all >r))
             (two? vi)
              (dead9 <>f >r ? (vi . addrf1 g all >r)
                 (f . vi . addrf1 g all >r))
             (two? ng) (ng . addrf1 g all >r)
             (two? lk) (lk . addrf1 g all >r)
             (two? xj) (fuse xj)
             (two? aj) (fuse aj)
             (f . addrf1 g all r))))
   (addrfold g fs) (addrf1 g fs (addrf1 g fs fs) @ r (#r = #fs ? r (addrfold g r)))

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

   ; two constant adds onto one register fold: (add d a k1)(add d d k2) -> (add d a k1+k2).
   ; every target but thumb, while the sum is an immediate
   (addk g fs)
    (t32? g ? fs
       (: (go l) (!(two? l) ? l
                    (: f <l nx (two? >l ? <>l)
                       ((two? f && elem <f '(add lea) && two? nx && <nx = 'add &&
                         charm? (f 3) && charm? (nx 3) && nx 1 == f 1 && nx 2 == f 1 &&
                         imma g 'add (f 3 + nx 3)) ?
                          (go ([<f (f 1) (f 2) (f 3 + nx 3)] . >>l))
                          (f . go >l))))
          (go fs)))

   ; one table base per straight run (x64): a second (laa R L k) while R still holds L+k0 and is read
   ; only as a memory base drops, the reads till R's next def taking k-k0 into their displacement
   (laacse g fs)
    (!(x64? g) || abl? g 'laacse ? fs
       (: ; a memory form's [base-pos disp-pos index-pos], index-pos 0 for none
          (bpos f) (? !(two? f) ()
                      (elem <f (ldops9 + fldops)) [2 3 0]
                      (elem <f (xops + fxops)) [2 5 3]
                      (elem <f stops9) [1 2 0]
                      (elem <f (stxops + fstxops)) [1 4 2])
          ; R read in f only as its memory base, once
          (baseonly R f rs)
           (bpos f @ p (two? p && f <p = R && (<>>p = 0 || f <>>p != R) &&
                        #(filter (x \ x == R) <rs) = 1))
          ; can every read of R up to its next def take adj? the run must end in that def, or R die
          (ok? R adj l)
           (? !(two? l) 1
              (rdsp g <l @ rs
                 (? (rs = 'bar) (dies? g R l || dieb? g R fs l)
                    (elem R <rs)
                     (? !(baseonly R <l rs) ()
                        !(fits32 (<l (<>(bpos <l)) + adj)) ()
                        (elem R <>rs) 1
                        (ok? R adj >l))
                    (elem R <>rs) 1
                    (ok? R adj >l))))
          ; ..and take it
          (shift R adj l)
           (? !(two? l) l
              (rdsp g <l @ rs
                 (? (rs = 'bar) l
                    (elem R <rs)
                     (: f <l d (<>(bpos f))
                        g2 (map (i \ i = d ? (f i + adj) (f i)) ^#f)
                        (elem R <>rs ? (g2 . >l) (g2 . shift R adj >l)))
                    (elem R <>rs) l
                    (<l . shift R adj >l))))
          (go l st)
           (? !(two? l) l
              (: f <l
                    k9 (? !(two? f) () (<f = 'laa) <>>>f (<f = 'la) 0)   ; la is laa at 0
                 (? (charm? k9)
                     (? (two? st && <st = <>f && <>st = <>>f &&
                         ok? <>f (k9 - <>>st) >l)
                         (go (shift <>f (k9 - <>>st) >l) st)
                         (f . go >l [<>f <>>f k9]))
                    (rdsp g f @ rs
                       (? (rs = 'bar) (f . go >l ())
                          (two? st && elem <st <>rs) (f . go >l ())
                          (f . go >l st))))))
          (go fs ())))

   ; the top half (x64): a reg whose high 32 bits are known zero (32-bit load, zx, small li,
   ; and/or/xor over such, shr by 32 up) owes no zx4, nor one a mask clears next; a dying 32-bit
   ; load folds into the and/or/xor reading it. labels meet to a fixpoint; raw or an indirect jump
   ; leaves the fn as it was
   (hz4 g fs)
    (!(x64? g) || abl? g 'hz4 || any (f \ two? f && elem <f '(raw jmpr jmpm)) fs ? fs
       (: frame '(sp fp r4)
          inn {}
          (u32? k) (charm? k && whole? k && 0 <= k && k < 4294967296)
          (hz? x K) (u32? x || elem x K)
          ; f's one def is hz, K holding before it
          (hzd f K) (<f @ op
                       (? (elem op '(ldu1 ldu2 ldu4 ldxb ldxw zx1 zx2 zx4)) 1
                          (elem op (x4ops + m4ops)) 1
                          (op = 'li) (u32? <>>f)
                          (op = 'mov) (elem <>>f K)
                          (op = 'and) (hz? <>>f K || hz? (f 3) K)
                          (elem op '(or xor)) (hz? <>>f K && hz? (f 3) K)
                          (op = 'shr) (elem <>f K || u32? <>>f && <>>f >= 32)
                          ()))
          (meet a b) (? (a = 'top) b (b = 'top) a (filter (r \ elem r b) a))
          (step f K)
           (rdsp g f @ rs
              (? (rs = 'bar) ()
                 (K = 'top) K
                 (: k2 (filter (r \ nelem r <>rs) K)
                    (#<>rs = 1 && hzd f K ? (<<>rs . k2) k2))))
          ; a label's entry shrinks to its meet with K: 1 when it moved
          (into L K) (peep inn L 'top @ o
                        (meet o K @ n
                           (? (n = 'top) 0
                              (o = 'top || #n < #o) (pin inn L n, 1)
                              0)))
          (local? L) !(fsym? L)
          ; an and by a 32-bit mask straight after clears the top itself
          (masked r n) (two? n && <n = 'and && <>n = r && <>>n = r && u32? (n 3))
          (round l K ch)
           (!(two? l) ? ch
              (<l @ f
                 (? !(two? f) (round >l K ch)
                    (<f = 'label) (: c (into <>f K) (round >l (peep inn <>f 'top) (c || ch)))
                    (<f = 'align) (round >l K ch)
                    (elem <f '(jmp jmp8)) (: c (local? <>f && into <>f K) (round >l 'top (c || ch)))
                    (elem <f '(br br8)) (: c (into <>>f K) (round >l K (c || ch)))
                    (<f = 'jmpt) (: c (foldl (a \ L \ into L K || a) 0 (f 3)) (round >l 'top (c || ch)))
                    (retx? f) (round >l 'top ch)
                    (round >l (step f K) ch))))
          (settle n) (round fs () 0 ? (settle n) 1)
          ; (ldxw|ldu4 t ..)(op d a b), t one of a b and dying, the other o hz (and needs no proof)
          (fuse f r K)
           (: nx (two? r ? <r)
              (? !(two? f && elem <f '(ldxw ldu4) && two? nx && elem <nx '(and or xor) && K != 'top) ()
                 (: t <>f d <>nx a <>>nx b (nx 3)
                    o (? (a = t && b != t) b (b = t && a != t) a ())
                    x? (<f = 'ldxw)
                    rr (x? ? [<>>f <>>>f] [<>>f])
                    (? (!o || charm? o) ()
                       (any (x \ elem x frame) rr) ()
                       (d != o && elem d rr) ()                  ; the mov would clobber the address
                       !(<nx = 'and || elem o (step f K)) ()
                       !(d = t || dies? g t >r || dieb? g t fs >r) ()
                       (: op (<nx @ 'and (x? ? 'andx4 'andm4) 'or (x? ? 'orx4 'orm4) (x? ? 'xorx4 'xorm4))
                          fz ([op d] + >>f)
                          [(d = o ? [fz] [['mov d o] fz]) >r])))))
          (out l K)
           (!(two? l) ? l
              (<l @ f
                 (? !(two? f) (f . out >l K)
                    (<f = 'label) (f . out >l (peep inn <>f 'top))
                    (<f = 'align) (f . out >l K)
                    (elem <f '(jmp jmp8 jmpt)) (f . out >l 'top)
                    (elem <f '(br br8)) (f . out >l K)
                    (retx? f) (f . out >l 'top)
                    (<f = 'zx4 && K != 'top && elem <>f K) (out >l K)
                    (<f = 'zx4 && two? >l && masked <>f <>l) (out >l K)
                    (fuse f >l K @ m
                       (two? m ? (<m + out (m 1) (step <>l (step f K)))
                          (f . out >l (step f K)))))))
          (settle 0, out fs ())))

   ; cmp load-op fusion: (ld X b o)(cmp X y) -> (cmpm b o y), (cmp r X) -> (cmprm r b o) when X
   ; dies beyond. after addrfold; x64 and full-word only (a narrow cmp's flags shift with the extension)
   (cmpfuse g fs)
    (: (go (f . r))
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
       (go fs))

   ; memory forward: in a straight run a full word stored or loaded off a non-frame base rides the
   ; register holding it; an address is its base's root plus an offset. a store forgets what it may
   ; overlap, a memory write or call forgets all, a label starts over. only in a unit naming no
   ; volatile (the types don't say which loads are). every target but thumb
   (memfw g fs)
    (t32? g || !(g 'novol) ? fs
       (: fr '(sp fp r4)
          mw (stops9 + siops + stxops + fstxops + '(push pop call callr callm raw sys asm))
          (root A b o) (assoc b A @ e (two? e ? [(e 1) (o + e 2)] [b o]))
          ; x is redefined: what rooted at x re-roots at a surviving copy of it, else goes
          (kill M A x)
           (foldl (q \ e \ q || !(e 1 = x && e 0 != x) ? q e) () A @ p
              (!p ? [(filter (e \ e 0 != x && e 2 != x) M)
                     (filter (e \ e 0 != x && e 1 != x) A)]
                 (: r (p 0) dk (p 2)
                    [(filter (e \ e 2 != x) (map (e \ e 0 = x ? [r (e 1 - dk) (e 2)] e) M))
                     (filter (e \ e 0 != x && e 0 != r)
                             (map (e \ e 1 = x ? [(e 0) r (e 2 - dk)] e) A))])))
          (go l M A)
           (!(two? l) ? ()
              (: f <l op (two? f ? <f)
                 (? !(two? f) (f . go >l M A)
                    (op = 'label) (f . go >l () ())
                    (elem op '(jmp jmpr jmpm ret ud2)) (f . go >l () ())
                    (elem op '(br br8 align)) (f . go >l M A)
                    ; a full-word load: the register that holds the word answers it
                    (op = 'ld && nom? (f 1) && nom? (f 2) && charm? (f 3) && nelem (f 2) fr && f 1 != 'sp)
                     (: D (f 1) a (root A (f 2) (f 3))
                        hit (foldl (r \ e \ r || !(e 0 = a 0 && e 1 = a 1) ? r (e 2)) () M)
                        k (kill M A D)
                        M2 (a 0 != D ? ([(a 0) (a 1) D] . <k) <k)
                        (? (hit = D) (go >l M2 (k 1))
                           hit (['mov D hit] . go >l M2 (k 1))
                           (f . go >l M2 (k 1))))
                    ; a full-word store: what it may overlap goes, the stored register holds its word
                    (op = 'st && nom? (f 1) && charm? (f 2) && nelem (f 1) fr)
                     (: a (root A (f 1) (f 2))
                        M1 (filter (e \ e 0 = a 0 && (7 < e 1 - a 1 || e 1 - a 1 < -7)) M)
                        (f . go >l (nom? (f 3) ? ([(a 0) (a 1) (f 3)] . M1) M1) A))
                    (rdsp g f @ rd
                       (rd = 'bar || elem op mw ? (f . go >l () (rd = 'bar ? () (foldl (k \ x \ kill <k (k 1) x) [() A] <>rd 1)))
                          ; a base made by lea/add/sub off another, or a register copy, roots at that one
                          (: D (f 1)
                             bs (? (elem op '(lea add sub) && nom? D && nom? (f 2) && charm? (f 3) && nelem (f 2) fr)
                                   (root A (f 2) (op = 'sub ? (0 - f 3) (f 3)))
                                   (op = 'mov && nom? D && nom? (f 2) && nelem (f 2) fr) (root A (f 2) 0))
                             k (foldl (k \ x \ kill <k (k 1) x) [M A] <>rd)
                             (f . go >l <k (two? bs && bs 0 != D ? ([D (bs 0) (bs 1)] . k 1) (k 1)))))))))
          (go fs () ())))

   ; store-forward: within a straight run a full-word frame slot rides the register that last
   ; touched it; r3/cs reloads stay (epilogue anchors); an lea off r4 keeps the adjacent pair only
   stldkeep ('r3 . csx64)
   (stldkp g) (? (a64? g || rv64? g) (csregs g) (ia32? g) '(r3 r5 r6) stldkeep)      ; the epilogue-anchor destinations
   (bdropr bs r9) (filter (e9 \ (<>e9 != r9)) bs)
   (bdropo bs o9) (filter (e9 \ (<e9 - o9 @ d (7 < d || d < -7))) bs)
   (stld g fs)
    (: fb (fbase g)
       ; the epilogue's (lea sp fp 0) is teardown, not an address take
       (esc? (f . l))
        (two? f && elem <f '(lea lean) && <>>f = fb && <>f != 'sp ? 1 (esc? l))
       fs2 (stldp fb fs ())
       (xret g (xmov g (esc? fs2 ? (stlda fb fs2) (stldw g fb (stldkp g) fs2 ())))))
   ; an xmm move straight back over the move that set it is idle: (movapd A B) (movapd B A)
   (xmov g fs)
    (? (abl? g 'xmov) fs
       (: (fx? f) (two? f && elem <f '(movapd movsd) && elem <>f fregs16 && elem <>>f fregs16)
          (go (f . r)) (? !(two? r) (f . r)
                          (fx? f && fx? <r && <><r = <>>f && <>><r = <>f) (f . go >r)
                          (f . go r))
          (two? fs ? (go fs) fs)))
   ; a value built on f0 only to be moved to a home, with f0 written outright next, is built on
   ; the home: the run from its start renames f0, and the move goes
   (xret g fs)
    (? (abl? g 'xret) fs
       (: hs (ffile g)
          (w0? f) (two? f && <>f = 'f0 && (elem <f '(ldsd ldsdl cvtsi2sd) || <f = 'movapd && elem <>>f fregs16 && <>>f != 'f0))
          ; the run: arithmetic onto f0 off a register, or an xmm form that names no f0
          (ch? f) (two? f && (elem <f '(addsd subsd mulsd divsd) && <>f = 'f0 && elem <>>f fregs16
                              || elem <f '(addsd subsd mulsd divsd minsd maxsd movsd movapd ldsd ldsdl) && nelem 'f0 >f))
          ; the home h may be read by none of it
          (ok? l h) (? !(two? l) 1
                       (<l @ f (<>f = 'f0 ? <>>f != h (nelem h >f))) (ok? >l h)
                       ())
          (span l acc) (two? l && ch? <l ? (span >l (<l . acc)) [(rev acc) l])
          (rn f h) (map (x \ (x = 'f0 ? h x)) f)
          (go l)
           (? !(two? l) l
              (w0? <l)
               (: s <l sp (span >l ()) cs <sp tl <>sp e (two? tl ? <tl)
                  h (two? e && <e = 'movapd && <>>e = 'f0 && elem <>e hs ? <>e)
                  (h && two? >tl && w0? <>tl && ok? cs h ?
                     ((rn s h @ s2 (<>s2 = <>>s2 && <s2 = 'movapd ? () [s2])) + map (f \ rn f h) cs + go >tl)   ; a start that read h moves it onto itself
                     (s . go >l)))
              (<l . go >l))
          (go fs)))
   ; the adjacent pair needs no aliasing story. the full-width frame pair stays with the lanes
   ; below (slot map, anchors); narrow pairs forward on any base, at the load's extension
   (fwext s l) (s @ 'st (l @ 'ld 'mov)
                   'st4 (l @ 'ldu4 'zx4 'ld4 'sx4)
                   'st2 (l @ 'ldu2 'zx2 'ld2 'sx2)
                   'st1 (l @ 'ldu1 'zx1 'ld1 'sx1))
   (fwfs w rY rX) (? (w = 'mov) (rY != rX ? [['mov rY rX]])
                     (rY = rX) [[w rX]]
                     [['mov rY rX] [w rY]])
   ; a store fed by an adjacent li declines: that triple is the si fold's
   (stldp fb (f . r) pv)
    (!(two? r && two? f && elem <f gstops && !(<f = 'st && <>f = fb)) ?
       (f . stldp fb r f)
       (: nx <r
          rX <>>>f
          w (two? nx ? (fwext <f <nx))
          (w = () ||
           two? pv && <pv = 'li && <>pv = rX ||
           !(<>>nx = <>f && <>>>nx = <>>f) ?
             (f . stldp fb r f)
             (f . fwfs w <>nx rX + stldp fb >r f))))
   (stlda fb (f . r))                                     ; the escape lane: only the pair with nothing between is aliasing-proof
    (!(two? r && two? f && <f = 'st && <>f = fb) ?
       (f . stlda fb r)
       (: nx <r
          rX <>>>f
          (!(two? nx && <nx = 'ld && <>>nx = fb && <>>>nx = <>>f) ?
             (f . stlda fb r)
             (<>nx @ rY
                (rY = rX ? (f . stlda fb >r)
                 (f . ['mov rY rX] . stlda fb >r))))))
   (stldw g fb keep (f . r) bs)
    (!(two? f) ? (f . stldw g fb keep r bs)
       (<f @ op
          (? (op = 'label) (f . stldw g fb keep r ())
             (elem op '(br jmp jmpr ret)) (f . stldw g fb keep r bs)
             (op = 'ld && <>>f = fb)
              (: rY <>f o <>>>f
                 b9 (assoc o bs)
                 (? (elem rY keep)
                    (f . stldw g fb keep r ([o rY] . bdropo (bdropr bs rY) o))
                    (two? b9 && two? <>b9)     ; an immediate binding: the load remats
                     (['li rY <><>b9] . stldw g fb keep r ([o rY] . bdropr bs rY))
                    (two? b9 && <>b9 = rY) (stldw g fb keep r bs)
                    (two? b9) (['mov rY <>b9] . stldw g fb keep r ([o rY] . bdropr bs rY))
                    (f . stldw g fb keep r ([o rY] . bdropr bs rY))))
             (elem op stops9 && <>f = fb)
              (: o <>>f
                 b2 (bdropo bs o)
                 (op = 'st && nom? <>>>f ?
                    (f . stldw g fb keep r ([o <>>>f] . b2))
                    (f . stldw g fb keep r b2)))
             ; a full-width si binds its constant (a narrow one just invalidates): a later ld remats as li
             (elem op siops && <>f = fb)
              (: o <>>f
                 b2 (bdropo bs o)
                 (op = 'si ?
                    (f . stldw g fb keep r ([o ['k <>>>f]] . b2))
                    (f . stldw g fb keep r b2)))
             ; a reg-reg mov carries its src's bindings; sp/fp/r4 stay out (sp's defs are empty by design)
             (op = 'mov && nom? <>f && nom? <>>f
                 && !(elem <>f '(sp fp r4)) && !(elem <>>f '(sp fp r4)))
              (: rY <>f rB <>>f
                 news (map (e9 \ [<e9 rY]) (filter (e9 \ (<>e9 = rB)) bs))
                 (f . stldw g fb keep r (news + bdropr bs rY)))
             (rdsp g f @ rd
                (? (rd = 'bar) (f . stldw g fb keep r ())
                   (elem fb <>rd) (f . stldw g fb keep r ())
                   (f . stldw g fb keep r (filter (e9 \ (nelem <>e9 <>rd)) bs)))))))

   ; rezx: a zxN over a register already clean to N drops, and an sxN over one clean below N
   ; (clean: zx, ldu, the 32-bit rotates, li, mov). a set is clean to 1, so `cmp r 0; set ne r`
   ; over it drops unless the next form reads flags
   (rezx g fs)
    (: (go l t acc)
        (!(two? l) ? (rev acc)
           (: f <l r >l
              (!(two? f) ? (go r t (f . acc))
                 (<f @ op
                    (? (op = 'cmp && peep t <>f 0 = 1 && <>>f = 0 &&
                        two? r && <r = ['set 'ne <>f] &&
                        !(two? >r && two? <>r && elem <<>r '(br br8 set)))
                        (go >r t acc)
                       (op = 'set)
                        (pin t <>>f 1, go r t (f . acc))
                       (elem op '(zx1 zx2 zx4))
                        (: w (? (op = 'zx1) 8 (op = 'zx2) 16 32)
                           c (peep t <>f 0)
                           (0 < c && c <= w ? (go r t acc)
                              (pin t <>f w, go r t (f . acc))))
                       (elem op '(sx1 sx2 sx4))                 ; clean below the sign bit: a no-op
                        (: w (? (op = 'sx1) 8 (op = 'sx2) 16 32)
                           c (peep t <>f 0)
                           (0 < c && c < w ? (go r t acc)
                              (pin t <>f 0, go r t (f . acc))))
                       (elem op '(ldu1 ldu2 ldu4))
                        (pin t <>f (? (op = 'ldu1) 8 (op = 'ldu2) 16 32),
                         go r t (f . acc))
                       (op = 'ror4)
                        (pin t <>f 32, go r t (f . acc))
                       (op = 'rorv4)
                        (pin t 'r1 0, pin t <>f 32, go r t (f . acc))
                       (op = 'li)
                        (<>>f @ k
                           (pin t <>f (? !(charm? k) 0 (k < 0) 0
                                         (k < 2) 1 (k < 256) 8 (k < 65536) 16
                                         (k < 4294967296) 32 0),
                            go r t (f . acc)))
                       (op = 'mov)
                        (pin t <>f (peep t <>>f 0), go r t (f . acc))
                       (rdsp g f @ rd
                          (rd @ 'bar (go r {} (f . acc))
                                (: (dirty ds) (!(two? ds) ? 0
                                                 (pin t <ds 0, dirty >ds))
                                   (dirty <>rd,
                                    go r t (f . acc))))))))))
       (go fs {} ()))

   ; copy propagation: after (mov a b) later reads of a say b; once nothing reads a the copy
   ; drops. sp/fp/r4/r3 stay out: pro4?/epim?/sibjmp/unframe read the prologue and epilogue by shape
   (hmov? f) (two? f && <f = 'mov && nom? <>f && nom? <>>f
               && !(elem <>f '(sp fp r4 r3)) && !(elem <>>f '(sp fp r4 r3)))
   ; forms that keep their operands: addrfold owns a mov feeding an address, cskeep reads
   ; (push <cs>) as a save, a variable shift's count must stay in r1
   cpskip (ldops9 + gstops + stxops + siops + leaops + xops + fxops + fstxops + fldops + fstops + vshops +
           x4ops + m4ops + '(cmpm cmprm push))
   ; the read-only positions of a form, probed off rdsp with a stranger ('zq): a read-modify-write slot declines
   (cprp g f)
    (elem <f cpskip ? ()
       (: (go i acc)
           (!(i < #f) ? (rev acc)
              (f i @ x
                 (!(nom? x) ? (go (i + 1) acc)
                    (rdsp g (reop f i 'zq) @ d
                       (? (d = 'bar) (go (i + 1) acc)
                          (elem 'zq <d && nelem 'zq <>d) (go (i + 1) (i . acc))
                          (go (i + 1) acc))))))
          (go 1 ())))
   ; the substitute must be a stranger to the form's defs (the two-address expansion writes dest
   ; first). a mov passes ds empty (the self-mov we hunt); an alu's first source welcomes its dest
   (cpsub f ps m ds)
    (!(two? ps) ? f
       (: i <ps x (f i)
          b (m x)
          two (elem <f aluops && i = 2)
          (cpsub (nom? b && (two || nelem b ds) ? (reop f i b)
                    f)
                 >ps m ds)))
   (cpkill m ds)                                    ; a def kills its own copy and every copy of it
    (foldl (_ \ k \ elem k ds || elem (m k) ds ? (pin m k ()) 0) 0 (keys m),
     m)
   (cpwalk g (f . u) m)
    (!(two? f) ? (f . cpwalk g u m)
       (<f @ op
          (? (elem op '(br align ud2)) (f . cpwalk g u m)   ; a br rides its fall-through
             (elem op '(label jmp jmpr ret)) (f . cpwalk g u {})
             (rdsp g f @ d                    ; a call and every op off the table land here
                (d @ 'bar (f . cpwalk g u {})
                     (cpsub f (cprp g f) m (op @ 'mov () <>d) @ f2
                        (hmov? f2 && <>f2 = <>>f2 ? (cpwalk g u m)
                           (cpkill m <>d @ m2
                              (hmov? f2 ? (pin m2 <>f2 <>>f2) 0,
                               f2 . cpwalk g u m2)))))))))
   (copyprop g fs) (cpwalk g fs {})                 ; no liveness (build may run twice per fn); the drop rides coal

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

   ; local init: zero the slot (stride wsize: `st` is the machine word, 4 on t32), then fill
   (cgzero g off span)                              ; zero [r4+off .. +span)
    (: w (wsize g)                                  ; before `go`: a later sibling reads as missing
       (go o rem acc)
        (? (w <= rem) (go (o + w) (rem - w) (acc + [['st 'r4 o 'r0]]))
           (0 < rem) (go (o + 1) (rem - 1) (acc + [['st1 'r4 o 'r0]]))
           acc)
       ('((li r0 0)) + go off span ()))
   (cgstr off text)                                 ; a char array from a string: byte stores (NUL from the zero)
    (: (go i acc) (i < 0 ? acc (go (i - 1) ([['li 'r0 (text i)] ['st1 'r4 (off + i) 'r0]] + acc)))
       (go (#text - 1) ()))
   (cgstore g env off ty val)                       ; store a scalar value expr into [r4+off]
    (cgexpr g env val () @ r
       (? (bad? r) 'bad
          (sal? g && (lowb off @ b (0 < b && b < tsz g ty)))   ; a packed member: by its chunks
           (? (pair? g ty || d128? ty && !(w128? g)) (uanl g)
              (d128? ty) (as128 g r + stal 'r4 off 8 (lowb off) 'r0 + stal 'r4 (off + 8) 8 (lowb (off + 8)) 'r2)
              (flo? ty) (ntmp g 'double @ tm (asfty g r ty + fstv g ty 'r4 tm 'f0 + [[(uldop (tsz g ty)) 'r0 'r4 tm]]
                                                + stal 'r4 off (tsz g ty) (lowb off) 'r0))
              (asintt g r ty + cvt ty 'r0 + stal 'r4 off (tsz g ty) (lowb off) 'r0))
          (d128? ty && w128? g) (as128 g r + wst g 'r4 off)   ; both halves: a union's .full = v
          (flo? ty) (asfty g r ty + fstv g ty 'r4 off 'f0)
          (pair? g ty) (asll g r + pst 'r4 off)
          (asintt g r ty + cvt ty 'r0 + [[(stop ty) 'r4 off 'r0]])))
   (cgfill g env off ty ini0)                       ; fill an aggregate at frame offset off (no zero)
    (unelide g env ty ini0 @ ini
     (?- 'bad
      (<ini == 'str) (arr? ty ? (cgstr off (snip <>ini 0 (min #<>ini (tsz g ty)))) 'bad)   ; s[3] = "abc" drops the NUL
      (<ini != 'init) 'bad
      (arr? ty)
       (: elt <>ty esz (tsz g elt)
          (fill l idx acc)
           (!(two? l) ? acc
              (: it <l
                 ci (<it = 'didx ? <>it idx)
                 val (elval it)
                 eoff (off + ci * esz)
                 r (? (aggish? elt && <val = 'init || arr? elt && <val = 'str) (cgfill g env eoff elt val)   ; a string fills a char array
                      (stru? elt && <val != 'str) (cgsfill g env eoff elt val)
                      (cgstore g env eoff elt val))
                 (bad? r ? 'bad (fill >l (ci + 1) (acc + r)))))
          (fill <>ini 0 ()))
      (stru? ty)
       (:- (fill <>ini 0 ())
        fields <(peep (g 'stag) <>ty 0)
        (fill l cur acc)
         (!(two? l) ? acc
            (: it <l
               ci (<it = 'dfield ? (fidx fields <>it) cur)
               val (elval it)
               fe (nthfield fields ci)
               (bad? fe ? 'bad
                  (: foff (off + <>fe) fty <>>fe
                     r (? (aggish? fty && <val = 'init || arr? fty && <val = 'str) (cgfill g env foff fty val)
                          (stru? fty && !(<val = 'str)) (cgsfill g env foff fty val)
                          (bitf? fty) (cgbffill g env foff fty val)
                          (cgstore g env foff fty val))
                     (bad? r ? 'bad (fill >l (fnext g fields ci) (acc + r))))))))))
   ; a bitfield member: read-modify-write its unit at [r4+off] (cgstore would flatten the unit)
   (cgbffill g env off bt val)
    (cgexpr g env val () @ r
       (bad? r ? 'bad
          (: uty <>bt bitoff <>>bt a (sal? g && lowb off < tsz g bt ? (lowb off) ())
             mask ((1 << <>>>bt) - 1) cmask (0 - (mask << bitoff) - 1)
             (? (bfwide? g bt) (bfnl g)
             (asintt g r uty
              + (uty @ 'bool (cvt uty 'r0) ())   ; normalize before the mask
              + bfld g bt 'r2 'r4 off a
              + [['li 'r3 mask] '(and r0 r0 r3)
                  ['li 'r3 cmask] '(and r2 r2 r3)
                  '(mov r3 r0)]
              + (bitoff > 0 ? [['shl 'r3 bitoff]])
              + ['(or r2 r2 r3)] + bfst g bt 'r4 off a 'r2)))))
   ; a complex width flip, src in r0, dest in r1: componentwise convert
   (cxcopy g sty)
    (cxb sty = 'float ?
        '((ldss f2 r0 0) (cvtss2sd f2 f2) (stsd r1 0 f2)
          (ldss f2 r0 4) (cvtss2sd f2 f2) (stsd r1 8 f2))
        '((ldsd f2 r0 0) (cvtsd2ss f2 f2) (stss r1 0 f2)
          (ldsd f2 r0 8) (cvtsd2ss f2 f2) (stss r1 4 f2)))
   ; a member from a struct-valued expr: block copy from r0 (a complex width flip converts);
   ; a complex member from a real expr ({3.0}) gets re = value, im = 0
   (cgsfill g env foff fty val)
    (: rl (matv g (clval g env val))
       rv (!(bad? rl) && stru? (vty rl) ? rl (cgexpr g env val ()))
       (?- 'bad
        (bad? rv) 'bad
        (stru? (vty rv))
         (tor0 g rv + [['lea 'r1 'r4 foff]] @ mv
            (gcplx? fty && gcplx? (vty rv) && !(<>fty = <>(vty rv)) ?
               (mv + cxcopy g (vty rv))
               (mv + bcopy g 0 (tsz g fty) ())))
        (gcplx? fty)
         (cxb fty @ b
            (asflo g rv + (fstf g b 'r4 foff 'f0
             + ('((li r2 0))
                + (b = 'float ? [['st4 'r4 (foff + 4) 'r2]] (z8 g 'r4 (foff + 8)))))))))

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
   (imgbytes g ty ini)                              ; a byte/fix list of length tsz(ty) | 'bad
    (?- 'bad
     (atom? ini) (zeros (tsz g ty))
     (<ini = 'cond) (imsel g ini @ a (a = 'no ? 'bad (imgbytes g ty a)))
     (<ini = 'flo) (flo? ty ? (fim ty <>ini) 'bad)
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
     ; a label cast to a word-sized integer ((intptr_t)f) is still its address
     (<ini = 'cast && !(aggish? ty) && !(flo? ty) && tsz g ty = wsize g)
      (imaddr g ini @ r
         (r != 'no ? [['fix (wsize g) (ilp32? g ? 'abs32 'abs64) <r <>r]]
            (icfold ini @ v (v @ 'no (imgbytes g ty <>>ini) (imnum g ty v)))))
     ; a constant expression parse's cfold left: a float through a cast ((int)(0.867 * (1 << 16)))
     (!(aggish? ty) && !(flo? ty) && elem <ini '(bin un cast))
      (icfold ini @ v (v @ 'no 'bad (imnum g ty v)))
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
   (cgimage g ty ini)                               ; the full span-padded image | 'bad
    (: span (aup (tsz g ty) (wsize g))         ; round to the word (8 on x64/a64, 4 on t32)
       raw (imgbytes g ty ini)
       (bad? raw ? 'bad (raw + zeros (span - imbytelen raw))))

   ; the inline-asm register file (cgasm; cgdecl reads it for a register variable's pin)
   asmregs '(r0 r1 r2 r3 r5 r6 r7 r8 r9 r10)
   asmpick '(r10 r9 r8 r7 r6 r5 r2 r1 r0)
   ; a64's "w": a v register, from the caller-saved top (a function with an asm homes no float)
   asmfp '(f16 f17 f18 f19 f20 f21 f22 f23)
   (freg? r9) (elem r9 asmfp)
   asmnames (foldl (t \ i \ "r\(i)" @ s9 (pin t (name s9) s9)) {} ^11)
   (asmreg? g r9) (elem r9 (asmfile g) || a64? g && r9 = 'r4)
   (asmfile g) (ia32? g ? '(r0 r1 r2 r3 r5 r6) asmregs)      ; i386 has eight registers, esp and ebp aside
   (asmpk g) (ia32? g ? '(r2 r1 r0 r6 r5) asmpick)   ; i386's esi edi are callee-saved: taken last, and saved (cgasm1)
   ; an x64 xmm0..15 or an a64 v0..31, by name
   (vclob? g c) (: (num k) (: d (chars (snip c k #c))
                              (? (two? d && foldl (\ a ch (a && 48 <= ch <= 57)) 1 d) (foldl (\ a ch (a * 10 + ch - 48)) 0 d) -1))
                   (? (x64t? g && starts? c "xmm") (0 <= num 3 < 16)
                      (a64? g && starts? c "v") (0 <= num 1 < 32)
                      0))
   ; callee-saved seats a clobber may name past the asm file: pushed and popped around the body
   (asmsave? g r9) (? (ia32? g) (elem r9 '(r3 r5 r6))
                      (x64t? g) (elem r9 csx64)
                      (a64? g) (elem r9 '(r11 r12 r13 r14 r15 r16 r17 r18 r19 r20 r21 r22 r23 r24 r25 r26 r27 r28))
                      (rv64? g) (elem r9 '(r11 r12 r13 r14 r15 r19 r20 r21 r22 r23 r24 r25 r26))
                      (elem r9 '(r5 r6 r7 r8 r9 r10 r11 r12)))
   ; a declaration list ((name ty init)..) -> (forms env) | 'bad. a homable scalar ticks the decl
   ; seq (stable across ubuild's attempts: splices don't tick) and asks g 'lhome for a home
   (cgdecl g env pairs)
    (: ; the C99 VLA local: free any prior instance from this site (a loop re-runs the decl), size,
       ; sub sp, stash the block pointer; the fn stays out of sibcalls and homing (fesc + hasasm)
       v16 '((add r0 r0 15) (shr r0 4) (shl r0 4))   ; rounded up to 16: shr/shl, a64's encoder refuses ~15 as an and immediate
       vsub '((lea r1 sp 0) (sub r1 r1 r0) (lea sp r1 0))   ; sp -= r0 through a plain register: on a64 only lea (add-immediate) sees 31 as sp
       ; -ftrivial-auto-var-init=zero: the new block, r0 bytes at sp (a multiple of 16), word by word
       (vzero g lf) (: lz (name "\(lf).z") ld (name "\(lf).d")
                       ['(lea r1 sp 0) '(add r2 r1 r0) '(li r0 0) ['label lz] '(cmp r1 r2) ['br 'eq ld]
                        '(st r1 0 r0) ['add 'r1 'r1 (wsize g)] ['jmp lz] ['label ld]])
       (vone ps env2 acc p ty)
        (peep (g 'vslots) (varix ty) () @ sl
           (!(two? sl) ? 'bad
              (: po <sl so <>sl
                 es (tsz g (varel ty))
                 _ (pin g 'fesc 1) _ (pin g 'hasasm 1)
                 dr (cgexpr g env2 (varn ty) ())
                 (bad? dr ? 'bad
                    (: lf (nlab g ".vla")
                       code ([['ld 'r0 'r4 so] '(cmp r0 0) ['br 'eq lf]]
                             + v16
                             + [['ld 'r1 'r4 po] '(add r1 r1 r0) '(lea sp r1 0)
                                 ['label lf]]
                             + asint g dr
                             + (1 < es ? (imby g 'r0 es)) + [['st 'r4 so 'r0]]
                             + v16 + vsub + (avz? g ? (vzero g lf) ()) + ['(lea r0 sp 0) ['st 'r4 po 'r0]])
                       (one >ps ([<p po ty] . env2) (acc + code)))))))
       (one ps env2 acc)
        (!(two? ps) ? [acc env2]
           (: _ (psreset g)
              p <ps
              ty <>p
              ; -ftrivial-auto-var-init=zero: no initializer is a zero one
              init (avz? g && atom? <>>p && !(gvarr? ty) ? (aggish? ty ? ['init ()] ['num 0]) <>>p)
              ; a `register T v asm("reg")` local naming a register the asm surface cannot
              (? (two? >>>p && <>>>p && (gas-regname (gtgt g) <>>>p @ r9 !(nom? r9 && asmreg? g r9)))
                  (nolane g "no lane for a register variable in \(<>>>p)\(ontgt g)")
                 (gvarr? ty)
                  (? (two? init)
                      (nolane g "a variable-length array cannot take an initializer")
                     !(elem (gtgt g) '(x64 a64 rv64 i386 i386m16 thumb2 thumb2sp arm))
                      (nolane g "no lane for a variable-length array\(ontgt g)")
                     (fbal g < tal g (varel ty))   ; its block rounds sp, aligned no further than the frame base
                      (nolane g "a variable-length array of elements aligned past the stack's \(fbal g)")
                     (vone ps env2 acc p ty))
                 (: span (aup (tsz g ty) 8)
              off (naslot g span (max (tal g ty) (4 < #p ? (p 4) 0)))   ; a record's fifth slot: its own ask
              hreg (? (g 'inlining) ()                   ; a statement expression's decl takes no seat
                      !(lhomable? ty || fhomable? ty || (d128? ty && wreg? g)) ()
                      (: sq (1 + peep g 'dseq 0)
                         _ (pins g 'dseq sq
                                   'lrec ([sq off ty <p] . g 'lrec))
                         lht (g 'lhome)
                         ((lht ? (lht sq)) || spr g <p)))
              ; a register variable's pin rides the env entry's fourth slot for cgasm
              apin (two? >>>p && <>>>p ? (gas-regname (gtgt g) <>>>p))
              ; a d128's home is a pair (lo hi) off the cs pool -- ulloc packs two seats
              env3 ([<p (? (two? hreg) ['regw hreg] hreg ['reg hreg] off) ty] + (nom? apin ? [apin]) . env2)
              ; a cs home stays off g 'homes: no call wrap, no sib peel, and ezarg must not read its unwritten shadow
              _ (hreg && !(two? hreg) && nelem hreg (cspool g) && nelem hreg (fcspool g) && (!(fhomable? ty) || ty = 'double && fwrap? g) && !(spr g <p) ?
                   (pin g 'homes ([(rp g hreg) off <p] . g 'homes)))
              ; a constant init of a plain slotted scalar is one store-immediate; bool keeps its cvt (0/1)
              si9 (x64t? g && !hreg && <init = 'num && charm? <>init &&
                   !(flo? ty || pair? g ty || d128? ty || ty == 'bool) ?
                     (siop9 ty <>init))
              (? (atom? init) (one >ps env3 acc)
                 (<init = 'init || <init = 'str && arr? ty || clarr? ty init)
                  (<init = 'init && !(aggish? ty) ? 'bad      ; a brace for a scalar
                     (cgfill g env3 off ty init @ f
                        (bad? f ? 'bad
                           (one >ps env3 (acc + cgzero g off span + f)))))
                 (arr? ty) 'bad                          ; a bare-expr init of an array
                 si9 (one >ps env3 (acc + [[si9 'r4 off <>init]]))
                 (stru? ty)                              ; a struct local from a struct value (an address): copy its bytes
                  (cgexpr g env3 init () @ r
                     (bad? r ? 'bad
                        (: sz (tsz g ty)
                           cpf (: (go k acc9)
                                   (? (8 <= sz - k && !(ilp32? g))
                                       (go (k + 8) (acc9 + [['ld 'r1 'r0 k] ['st 'r4 (off + k) 'r1]]))
                                      (4 <= sz - k) (go (k + 4) (acc9 + [['ld4 'r1 'r0 k] ['st4 'r4 (off + k) 'r1]]))
                                      (2 <= sz - k) (go (k + 2) (acc9 + [['ld2 'r1 'r0 k] ['st2 'r4 (off + k) 'r1]]))
                                      (1 <= sz - k) (go (k + 1) (acc9 + [['ld1 'r1 'r0 k] ['st1 'r4 (off + k) 'r1]]))
                                      acc9)
                                  (go 0 ()))
                           (one >ps env3 (acc + tor0 g r + cpf)))))
                 (: w9 (hreg && !(two? hreg) && !(fhomable? ty) ? hreg)   ; the home is the destination (the asn regv arm's shape)
                    r (cgexpr g env3 init w9)               ; a scalar (a pointer = string rides cgexpr -> la)
                    (? (bad? r) 'bad
                       (flo? ty) (one >ps env3 (acc + asfty g r ty + (hreg ? [['movapd hreg 'f0]] (fstv g ty 'r4 off 'f0))))
                       (pair? g ty) (one >ps env3 (acc + asll g r + pst 'r4 off))
                       (d128? ty)
                        (? !(w128? g) (no128 g)
                           (two? hreg)              ; a pair home's init is two register moves
                            (one >ps env3 (acc + as128 g r + [['mov <hreg 'r0] ['mov <>hreg 'r2]]))
                           (one >ps env3 (acc + as128 g r + wst g 'r4 off)))
                       hreg                        ; a homed local's init delivers to the home (a narrow home lands canonical)
                        (? (flo? (vty r))
                           (one >ps env3 (acc + asintt g r ty + ([['mov hreg 'r0]] + cvt ty hreg)))
                           (rpeq? g (vreg r) hreg) ; the destination held: no bridge
                           (one >ps env3 (acc + vfs r + cvt ty hreg))
                           (vfs r + ([['mov hreg (vreg r)]] + cvt ty hreg) @ fs
                              (rfree g (vreg r),
                               one >ps env3 (acc + fs))))
                       (one >ps env3
                            (acc + asintt g r ty +
                             cvt ty 'r0 +
                             [[(stop ty) 'r4 off 'r0]])))))))))
       (stq g,                                     ; one statement tick for the whole decl
        one pairs env ()))

   ; block-scope static ((name ty init)..): a unique global per name, bound in the env as (glob
   ; lbl), which vent turns into a 'glo; no runtime init. -> (forms env) | 'bad
   (cgsdecl g env pairs)
    (: (one ps env2)
        (!(two? ps) ? [() env2]
           (: p <ps
              name <p ty <>p
              ; a &&L in the initializer names this function's label, so it is spelled now
              (lfix x) (? !(two? x) x (<x == 'laddr) ['lsym "\(g 'fn).\(<>x)"] (map lfix x))
              lbl (nlab g "\(g 'fn).")             ; `fn.N` -- the `.` bars any C-identifier collision
              ; the image lays after the fn with no env: a name the initializer reaches by address (this static
              ; itself, or one declared before it) is spelled by its label now
              (sfix x) (? !(two? x) x
                          (<x == 'var && string? <>x)
                           (? (<>x = name) ['var lbl]
                              (assoc <>x env2 @ e (two? e && two? <>e && <<>e == 'glob ? ['var <><>e] x)))
                          (map sfix x))
              init (sfix (lfix <>>p))
              (pin (g 'glob) lbl [lbl ty init],   ; a local data label (internal linkage): g 'statics,
               4 < #p && 0 < p 4 ? (pin (g 'aligns) lbl (p 4)) 0,   ; its own aligned ask
               5 < #p ? (pin (g 'sects) lbl (p 5)) 0,    ; ..and its section
               pin g 'statics (lbl . g 'statics),      ; not g 'globs -- a static is never an exported symbol
               one >ps ([name ['glob lbl] ty] . env2))))
       (stq g,                                     ; the statement tick (alive numbers sdecls too)
        one pairs env))

   ; stmt -> forms | 'bad

   ; inline asm: the target's GNU dialect (gas.l; neutral text under __attribute__((holo))), spliced as one ('raw ..)
   ; a constraint's register part: r/q/g/rm 'pick, i/n 'imm, m 'mem, a digit ('tie n), rN the nom,
   ; x86's a b c d S D letters by name (rax rbx rcx rdx rsi rdi, Nd dx), ir 'either. a longer
   ; set reads by its letters: immediates alone (x86's I J K L M N e Z beside i n) 'imm, a
   ; register letter among immediates 'either, among memory 'pick
   asmimm '(105 110 73 74 75 76 77 78 101 90)
   ; x86's "=@cc<cond>" flag outputs -> the set's condition
   asmflags {"e" 'eq "z" 'eq "ne" 'ne "nz" 'ne "c" 'below "b" 'below "nae" 'below
             "nc" 'ae "ae" 'ae "nb" 'ae "a" 'above "nbe" 'above "be" 'be "na" 'be
             "g" 'gt "nle" 'gt "ge" 'ge "nl" 'ge "l" 'lt "nge" 'lt "le" 'le "ng" 'le
             "s" 's "ns" 'ns "o" 'vs "no" 'vc "p" 'p "np" 'np}
   (asmc g c9)
    (: n #c9
       c0 (n > 0 ? (c9 0) 0)
       x86 (x64t? g)
       cs (map (i \ c9 i) ^n)
       (in? l) (all (c \ elem c l) cs)
       (? (n < 1) 'bad
          (n = 1 && 48 <= c0 <= 57) ['tie (c0 - 48)]
          (n = 1) (c0 @ 114 'pick 113 'pick 103 'pick 109 'mem
                      112 'pick                                ; "p": an address in a register, %a spells it as memory
                      81 (a64? g ? 'mem 'bad)                  ; a64's Q: a base register alone, [xN]
                      119 (a64? g ? 'fpick 'bad)               ; a64's w: a v register
                      97 (x86 ? 'r0 'bad) 98 (x86 ? 'r3 'bad) 99 (x86 ? 'r1 'bad)
                      100 (x86 ? 'r2 'bad) 83 (x86 ? 'r5 'bad) 68 (x86 ? 'r6 'bad)
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
       (any fit (map (i \ c9 i) ^#c9)))
   ; v at z bits is a logical immediate: a rotated run of ones in an element repeated across it
   (a64bm? v z)
    (: u (v & ((1 << z) - 1))
       (per e) (: h (e // 2) hm ((1 << h) - 1) (h >= 2 && (u & hm) = (u >> h & hm) ? (per h) e))
       e (per z)
       em ((1 << e) - 1) x (u & em)
       y (x ^ (((x << 1) | (x >> (e - 1))) & em))
       (x != 0 && x != em && net (map (k \ y >> k & 1) ^e) = 2))
   ; a `register T v asm("reg")` variable named as an operand: its pin, else ()
   (asmvpin g env e)
    (e @ ('var nm) (assoc nm env @ en (two? en && two? >>>en ? <>>>en))
         ())
   ; %-substitute the template: al the operand printers (a modifier letter, 0 for none -> text | 'bad)
   (asmsub tm al)
    (: n #tm
       (go i acc)
        (n <= i ? acc
           (tm i @ c
              (? !(c = 37) (go (i + 1) (acc + string c))
                 (i + 1 < n)
                  (: d (tm (i + 1))
                     md (elem d '(98 119 107 113 99 120 108 97 80 115 104 100) && i + 2 < n && 48 <= tm (i + 2) <= 57 ? d 0)
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
                   (<x = 'var) (assoc <>x env @ b (two? b && two? <>b && <<>b = 'glob ? ['var <><>b] x))
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
   (asmw g env e) (peekty g env e @ ty
                     (bad? ty ? 8 (tsz g ty @ n (elem n '(1 2 4 8) ? n 8))))
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
          r (gas-top-in tgt txt "" [1 6] pf)
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
                       (all (n \ have n) outs)))
       (asecs-of g (filter live? (rev (g 'fasecs)))))
   ; a refusal that names what the asm asked for, for cgfn's report
   (asmno g msg) (pin g 'nolane msg, 'bad)
   ; what gas or holo could not read, as a sentence: the reader's own name for it and the piece
   (asmwhy a b) "it has no lane for (\(show a) \(show b))"
   ; a line the assembler cannot read refuses the function, naming the line's piece
   (cgasm g env s)
    (trap (s9 \ cgasm1 g env s9) s
          (a \ b \ (a = 'leave ? (scare a b) (asmno g "an asm \(asmwhy a b)"))))
   (cgasm1 g env s)
    (: _ (pin g 'hasasm 1)
       tmpl <>s
       tgt (gtgt g)
       neutral? (two? >>>>>>s)                      ; the holo attribute: the template is neutral text
       ; asm goto's labels, mangled as cgstmt's lbl; %lN spells one, and the blob leaves them as fixes
       labs (map (nm \ (name "\(g 'fn).\(nm)")) <>>>>>s)
       ; one operand list, GNU order: ('o|'x reg expr w) an output (x in-out), ('i reg expr w) a
       ; register input, ('b reg (addr expr) 0) a memory input or output, ('m imm 0 0) an
       ; immediate, ('f reg expr 1 cond) a flag output, ('k sp expr 8) the stack pointer as it stands
       (pinof k e) (k @ 'pick (asmvpin g env e @ p (nom? p ? p k)) k)
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
                 (k = 'mem) (oconv >l (['b 'pick ['addr <><l] 0] . acc))
                 (oconv >l ([(h @ 43 'x 'o) (pinof k <><l) <><l (asmw g env <><l)] . acc)))))
       (iconv l acc)
        (!(two? l) ? (rev acc)
           (: k (asmc g <<l) e <><l
              v (elem k '(imm either) ? (asmk g env e) 'no)
              (k @ 'bad (asmno g "an asm input constrained \"\(<<l)\"")
                   'imm (v != 'no ? (iconv >l (['m v 0 0] . acc)) (asmno g "an asm immediate input that is not a constant"))
                   'either ((a64? g ? (cint? v && a64fit? <<l v) (charm? v)) ? (iconv >l (['m v 0 0] . acc)) (iconv >l (['i (pinof 'pick e) e (asmw g env e)] . acc)))
                   'mem (iconv >l (['b 'pick ['addr e] 0] . acc))
                   (iconv >l (['i (pinof k e) e (asmw g env e)] . acc)))))
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
                    (? (elem <e2 '(m k) || elem k '(pick fpick) || two? k) (pinset >l acc)
                       !(asmreg? g k) 'bad
                       (elem k acc) 'bad
                       (pinset >l (k . acc)))))
             pinned (pinset ops9 ())
             (bad? pinned ? (asmno g "an asm register pinned twice, or one no operand may take")
                (: (assign l fr acc)
                    (!(two? l) ? (rev acc)
                       (: e2 <l k <>e2
                          (? (elem <e2 '(m k)) (assign >l fr (k . acc))
                             (two? k && <k = 'one)          ; the first free register of the set
                              (filter (r9 \ elem r9 >k) fr @ c9
                                 (two? c9 ? (assign >l (filter (r9 \ r9 != <c9) fr) (<c9 . acc)) 'bad))
                             (two? k) (<>k < #acc ? (rev acc <>k @ r9 (assign >l fr (r9 . acc))) 'bad)
                             (k = 'pick)
                              (two? fr ? (assign >l >fr (<fr . acc)) 'bad)
                             (k = 'fpick)
                              (#(filter freg? acc) @ j (j < #asmfp ? (assign >l fr ((asmfp j) . acc)) 'bad))
                             (assign >l fr (k . acc)))))
                   ; no operand takes a register the asm clobbers; past the scratch file, x64 seats
                   ; callee-saved ones, saved around the whole asm
                   ckill (filter nom? (map (c \ (neutral? ? (intern c) (gas-regname tgt c)))
                                           (filter (c \ !(c = "memory" || c = "cc" || vclob? g c)) <>>>>s)))
                   xcs (x64t? g ? '(r3 r11 r12 r13 r14) ())
                   asgn (assign ops9 (filter (r9 \ (nelem r9 pinned && nelem r9 ckill)) (asmpk g + xcs)) ())
                   ; a v register's bits ride a free gp register in and out of it
                   scr (bad? asgn ? () (filter (r9 \ nelem r9 asgn && nelem r9 pinned && nelem r9 ckill && nelem r9 '(r0 r1)) (asmpk g) @ l9 (two? l9 ? <l9)))
                   (fmv w9) (w9 <= 4 ? 'movdxr 'movqxr)       ; gp bits -> v
                   (gmv w9) (w9 <= 4 ? 'movdrx 'movqrx)       ; v bits -> gp
                   ; a v output stores from its own register: s or d whole, a narrower one through a cell
                   (fst w9 ty f9) (w9 >= 4 ? [[(w9 = 8 ? 'stsd 'stss) 'r0 0 f9]]
                                     [['sub 'sp 'sp 16] ['stss 'sp 0 f9] [(w9 = 2 ? 'ldu2 'ldu1) 'r1 'sp 0] ['add 'sp 'sp 16]
                                      [(stop ty) 'r0 0 'r1]])
                   (clobs l acc)
                    (!(two? l) ? (rev acc)
                       (<l @ c
                          (c = "memory" || c = "cc" ? (clobs >l acc)
                             ; a vector register: a function with an asm homes no float (hasasm), so
                             ; none is live in one across the body and the clobber needs no save
                             (vclob? g c) (clobs >l acc)
                             (: r9 (neutral? ? (intern c) (gas-regname tgt c))
                                (? !(nom? r9) (asmno g "an asm clobber of \"\(c)\"")
                                   (asmreg? g r9) (clobs >l acc)
                                   (asmsave? g r9) (clobs >l (r9 . acc))
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
                         (rtext a9 w) (md \ (? (md = 108 || elem md '(115 104 100)) 'bad (md = 97 && !neutral?) (gas-mem tgt a9) neutral? (md ? 'bad (peep asmnames a9 "r?")) (gas-reg tgt a9 w md)))
                         (itext v) (md \ (? (md = 108 || elem md '(115 104 100)) 'bad neutral? (md || !(cint? v) ? 'bad (show v)) (gas-imm tgt v md)))
                         (mtext a9) (md \ (? md 'bad neutral? "\(peep asmnames a9 "r?"), 0" (gas-mem tgt a9)))
                         (ltext l9) (md \ (md = 108 ? (show l9) 'bad))
                         ; a v register: plain is v, s h d b q its scalar views
                         (ftext a9) (md \ (? neutral? 'bad
                                             (: n9 (snip (show a9) 1 #(show a9))
                                                (md @ 0 "v\(n9)" 115 "s\(n9)" 104 "h\(n9)" 100 "d\(n9)"
                                                      98 "b\(n9)" 113 "q\(n9)" 'bad))))
                         (optext l al acc)
                          (!(two? l) ? (rev acc)
                             (: e2 <l a9 <al
                                (optext >l >al ((<e2 @ 'm (itext a9)
                                                       'b (mtext a9)
                                                       'f (md \ 'bad)       ; a flag output has no spelling
                                                       (freg? a9 ? (ftext a9) (rtext a9 <>>>e2))) . acc))))
                         txt (asmsub tmpl (optext ops9 asgn () + map ltext tls))
                         (? (bad? txt) (asmno g "an asm operand the template spells with a modifier it has no lane for")
                            (!neutral? && nom? (gas-nolong tgt txt))
                             (asmno g "an asm \"\(show (gas-nolong tgt txt))\", which 64-bit mode has no encoding for")
                            (: ; inputs (and in-out outputs) evaluate and push -- all but the last, which
                               ; stays in r0 and moves to its register ahead of the pops
                               nin #(filter (e2 \ elem <e2 '(x i b)) ops9)
                               (loads l al k acc)
                                (!(two? l) ? acc
                                   (<l @ e2
                                      (elem <e2 '(x i b) ?
                                          (cgexpr g env <>>e2 () @ r
                                             (? (bad? r) 'bad
                                                (flo? (vty r) && freg? <al)
                                                 (loads >l >al (k + 1) (acc + vfs r + [[(gmv (vty r = 'float ? 4 8)) 'r0 'f0]]
                                                                        + (k + 1 = nin ? () (spush 'r0))))
                                                (flo? (vty r) || stru? (vty r)) (asmno g "a float or struct asm operand")
                                                (loads >l >al (k + 1) (acc + tor0 g r + (k + 1 = nin ? () (spush 'r0))))))
                                         (loads >l >al k acc))))
                               lf (loads ops9 asgn 0 ())
                               (bad? lf ? 'bad
                                  (: ; ..then pop into their registers, reverse order
                                     (pops l al k acc)
                                      (!(two? l) ? acc
                                         (elem <<l '(x i b) ?
                                            (pops >l >al (k + 1)
                                                  ((? (freg? <al) (k + 1 = nin ? [[(fmv <>>><l) <al 'r0]] (spop scr + [[(fmv <>>><l) <al scr]]))
                                                      (k + 1 = nin) (<al = 'r0 ? () [['mov <al 'r0]])
                                                      (spop <al)) + acc))
                                            (pops >l >al k acc)))
                                     ; the body, the saved clobbers pushed around it
                                     body (map (r9 \ ['push r9]) saves
                                           + (two? labs ? (asmbody g tgt neutral? txt)   ; a goto's edges are not unframe's to see
                                                 (asmfsafe txt (asmbody g tgt neutral? txt)))
                                           + map (r9 \ ['pop r9]) (rev saves))
                                     ; flag outputs: each set reads the flags before any push moves them
                                     (fsets l al acc)
                                      (!(two? l) ? acc
                                         (fsets >l >al (<<l = 'f ? (acc + [['set (<l 4) <al]]) acc)))
                                     ; outputs: push each register, store back reverse
                                     (opush l al acc)
                                      (!(two? l) ? acc
                                         (elem <<l '(o x f) ?
                                            (opush >l >al (acc + (freg? <al ? () (spush <al))))
                                            (opush >l >al acc)))
                                     (ostores l al acc)
                                      (!(two? l) ? acc
                                         (<l @ e2
                                            (!(elem <e2 '(o x f)) ? (ostores >l >al acc)
                                               (matv g (clval g env <>>e2) @ lv
                                                  (bad? lv ? 'bad
                                                     (vty lv @ ty
                                                        (flo? ty && !(freg? <al) || stru? ty || arr? ty || bitf? ty ? (asmno g "a float, struct, array or bit-field asm output")
                                                           (ostores >l >al
                                                            (vfs lv + (freg? <al ? (fst <>>><l ty <al) (spop 'r1 + [[(stop ty) 'r0 0 'r1]])) + acc)))))))))
                                     osf (ostores ops9 asgn ())
                                     ; one register output into a plain memory lvalue (a local's slot, a home's
                                     ; face) stores straight from its register: no cell
                                     oix9 ((: (g9 l j) (? !(two? l) -1 (elem <<l '(o x)) j (g9 >l (j + 1)))) ops9 0)
                                     one? (1 = #(filter (e2 \ elem <e2 '(o x f)) ops9) && 0 <= oix9)
                                     olv (one? ? (clval g env <>>(ops9 oix9)))
                                     oreg (one? ? (asgn oix9))
                                     direct (one? && !(freg? oreg) && vm? olv && !(two? (vfs olv)) && vmb olv != oreg
                                             && !(vty olv @ ty (flo? ty || stru? ty || arr? ty || bitf? ty)))
                                     (post u9) (fsets ops9 asgn () + (direct ? [[(stop (vty olv)) (vmb olv) (vmo olv) oreg]]
                                                                         (opush ops9 asgn () + osf)))
                                     (tramps t9 l9) (!(two? t9) ? ()
                                                       ([['label <t9]] + post 0 + [['jmp <l9]] + tramps >t9 >l9))
                                     (bad? osf ? 'bad
                                        (map (r9 \ ['push r9]) csops + lf + pops ops9 asgn 0 () + body + post 0
                                         + map (r9 \ ['pop r9]) (rev csops)
                                         + (tls = labs ? ()
                                              (: done (nlab g "\(g 'fn).ag")
                                                 ([['jmp done]] + tramps tls labs + [['label done]]))))))))))))))))

   ; a statement's child statements in tick order (a for's init only when it declares): alive's
   ; prepass and scasel walk by it, and cgstmt's walk must agree node for node
   (stkids s)
    (s @ ('blk items) items
         ('if _ thn els) [thn els]
         ('if _ thn) [thn]
         ('while _ body) [body]
         ('do . body . _) [body]
         ('for ini _ _ body && two? ini && elem <ini '(decl sdecl)) [ini body]
         ('for _ _ _ body) [body]
         ('switch _ items) items)

   ; -- alive: which homable names live across each call, one backward statement-grain walk ticking
   ; as cgstmt/cgdecl/cgsdecl do (stq). the universe: homable params + locals minus &-taken or
   ; multiply-declared names. loops seed with all they read, no fixpoint; a goto reads the universe.
   ; crossing counts mean nothing outside univ --
   (alive g f)
    (: params <>>f
       items <><>>>f
       dcl {} tak {} n9 {} liv {} crs {} spa {}
       crh {} rdc {} rdt {} sqm {}
       ; a label's live set, laid when the backward walk passes it: a goto that finds one is forward
       ; and reads just that; a goto that finds none may loop, and marks its label for pmx
       lab {} bwd {}
       ; a hard call: one no splice can erase. economics only -- a wrapped home survives any emitted call
       (nhcl l) (!(two? l) ? 0 (nhc <l + nhcl >l))
       (soft? nm) (two? (g 'inl nm))                 ; an inline candidate; the armed shadow covers a declined splice
       ; a soft site costs the spliced body's own hard calls -- nhcl, not nhcr: a splice's returns
       ; become jumps, so nothing tails. memoized, a cycle floors at 0
       nhmo {}
       (nhin nm) (peep nhmo nm 'no @ c9
                    ((c9 !== 'no) ? c9
                       (: _ (pin nhmo nm 0)
                          n2 (pmxl <><>>>(g 'inl nm) 1 ())
                          (pin nhmo nm n2,
                           n2))))
       ; the fn-level hard count is a path maximum: an if takes its heavier arm, loop weight multiplies,
       ; a goto answers a bar. tc9: ret-tails carve only at fn grain -- inside a splice body a ret call counts whole
       (pmxl l w tc9) (!(two? l) ? 0 (pmx <l w tc9 + pmxl >l w tc9))
       (pmx s w tc9)
        (!(two? s) ? 0
           (s @ ('blk items2) (pmxl items2 w tc9)
                ('expr e9) (nhc e9 * w)
                ('ret . rs) (: rv2 (two? rs ? <rs)
                               ((tc9 ? (nhcr rv2 (1 < #rs)) (nhc rv2)) * w))
                ('decl ps) ((: (hs l) (!(two? l) ? 0 (nhc <>><l + hs >l)) (hs ps)) * w)
                ('sdecl . _) 0
                ('if . cnd . thn . er)
                 (: a2 (pmx thn w tc9) b2 (two? <er ? (pmx <er w tc9) 0)
                    (nhc cnd * w + (a2 < b2 ? b2 a2)))
                ('while cnd body) (8 * w @ w8 (nhc cnd * w8 + pmx body w8 tc9))
                ('do body cnd) (8 * w @ w8 (nhc cnd * w8 + pmx body w8 tc9))
                ('for ini cnd stp body)
                 (8 * w @ w8
                    ((? (two? ini && elem <ini '(decl sdecl)) (pmx ini w tc9)
                        (two? ini) (nhc <>ini * w)) +
                     (two? cnd && nhc cnd * w8) +
                     (two? stp && nhc stp * w8) +
                     pmx body w8 tc9))
                ('switch ce items2) (nhc ce * w + pmxl items2 w tc9)   ; fallthrough: arms sum (conservative)
                (('case || 'dflt) . _) 0
                ('goto nm) (? (bwd nm) 99 ((peep lab nm 'no) == 'no) 99 0)
                (('asm || 'igoto) . _) 99
                0))
       (nhc e) (!(two? e) ? 0
                  (e @ ('call ('var nm) as) ((soft? nm ? (nhin nm) 1) + nhcl as)
                       ('call fh as) (1 + nhc fh + nhcl as)
                       (('szof || 'bcp) . _) 0
                       (nhcl e)))
       ; a ret-tail call hardens nothing (sibcall jumps it, and a home is dead at its own return) --
       ; but a soft tail splices and its body's hard calls land in this frame; a musttail never splices (mt9)
       (nhcr e mt9)
        (!(two? e) ? 0
           (e @ ('call ('var nm) as && soft? nm) ((mt9 ? 0 (nhin nm)) + nhcl as)
                ('call fh as) (nhc fh + nhcl as)
                ('comma a b) (nhc a + nhcr b mt9)
                ('cond c a b) (nhc c + nhcr a mt9 + nhcr b mt9)
                (k _ x && elem k '(un cast)) (nhcr x mt9)
                (nhc e)))
       ; protocol dirt, anything that writes r0-r3: a call's staging, div/mod (r0:r2), a variable
       ; shift (r1), a d128 cast (r0:r2). a fn with none may ride a quad arrival
       (pdt e) (e @ (('szof || 'bcp) . _) 0
                    ('call . _) 1
                    ('asm . _) 1
                    ('bin op a b && elem op '(/ %)) (1 + pdt a + pdt b)
                    ('bin op a b && elem op '(shl shr) &&
                     (atom? b || <b !== 'num)) (1 + pdt a + pdt b)
                    ('cast ty x) ((d128? ty ? 1 0) + pdt x)
                    (_ . _) (pdtl e))
       (pdtl l) (two? l ?
                   ((two? <l ? (pdt <l) 0) + pdtl >l))
       ; the touch counters: every mention, read or write, raw and loop-weighted
       (bump9 nm w) (pin rdc nm (1 + peep rdc nm 0),
                     pin rdt nm (w + peep rdt nm 0),
                     0)
       (rdn e w)
        (!(two? e) ? 0
           (e @ ('var nm) (bump9 nm w)
                ('szof . _) 0
                ('decl ps)                           ; an initialized decl's store is a touch that spells no var
                 ; not :- here: a destructured param resolves as a global from inside the moved body
                 (: (go2 (p9 . u))
                     (two? <>>p9 && bump9 <p9 w,
                      rdn <>>p9 w,
                      go2 u)
                    (go2 ps))
                (: w9 (elem <e '(while do for) ? (w * 8) w)
                   (go (a . u)) (two? a && rdn a w9, go u)
                   (go e))))
       ; -- prepass: &-taken names (sizeof's unevaluated &v over-records, harmless) --
       (pex e) (two? e ?
                  (e @ ('addr ('var nm)) (pin tak nm 1) (),
                     ; the head too: an init list's first element sits in head position
                   (? (two? <e) (pex <e) ()),
                   pexl >e))
       (pexl l) (two? l ? (pex <l, pexl >l))
       ; -- prepass: the tick total (mirrors lst's, statement for statement), decl counts, homable
       ; locals. s stays whole: a [k l] head would refuse an if or a for and silently drop its ticks --
       (pre s)
        (two? s &&
         (<s @ k
          (pin n9 'n (1 + peep n9 'n 0),
           k = 'asm && pin n9 'asm 1,
        (?- (prel (stkids s))
         (elem k '(decl sdecl)) (: (go (p . u))
          (pin dcl <p (1 + peep dcl <p 0),
           k = 'decl && (lhomable? <>p || fhomable? <>p) && pin n9 'loc (<p . n9 'loc),
           k = 'decl && gvarr? <>p && pin n9 'vla 1,
           ; predicts cgdecl's dseq: it ticks for exactly these, in this order
           k = 'decl && !(gvarr? <>p) &&
            (lhomable? <>p || fhomable? <>p || d128? <>p && wreg? g) &&
            (1 + peep n9 'sq 0 @ q2 (pin n9 'sq q2,
                                     pin sqm q2 [<p <>p])),
           go u)
          (go <>s))))))
       (prel l) (two? l ? (pre <l, prel >l))
       (pdcl ps) (two? ps ?
                    (pin dcl <<ps (1 + peep dcl <<ps 0),
                     pdcl >ps))
       ; -- the universe: the homable gp walk for the param names, plus the locals --
       (pgo ps gpi acc) (homefold g ps gpi acc
                          (a2 \ i9 \ p9 \ lhomable? <>p9 ?
                                            (<p9 . a2) a2))
       _ (pdcl params)
       _ (prel items)
       _ (pexl items)
       ; ..plus the double params: outside the gp walk, but a wrapset must see them (their crossings)
       pgs (pgo params 0 () + map (p9 \ <p9) (filter (p9 \ fhomable? <>p9) params))
       univ (filter (nm \ dcl nm = 1 && !(tak nm)) (pgs + n9 'loc))
       ; a homable param outside the universe still homes, so it must ride every wrapset
       pales (filter (nm \ (nelem nm univ)) pgs)
       ; -- the set kit (names are strings; elem compares content) --
       (sadd s2 nm) (elem nm s2 ? s2 (nm . s2))
       (sun s2 b) (!(two? b) ? s2 (sun (sadd s2 <b) >b))
       (sdel (a . u) nm) (a = nm ? u (a . sdel u nm))
       (tick u) (: q (peep n9 'q 0) (pin n9 'q (q - 1), q))
       ; a per-name [lo hi] tick span, a superset of the live range -- so the control-only lanes
       ; (goto, break) record too
       (spn sq l)
        (two? l ?
           (: nm <l o (spa nm)
              (pin spa nm (!(two? o) ? [sq sq]
                              (: a <o b <>o [(sq < a ? sq a) (b < sq ? sq b)])),
               spn sq >l)))
       ; w the wrapset (soundness), wc the names charged a crossing ncc times (economics),
       ; nclw the in-loop share of ncl (0 at depth 0), nclh the hard calls
       (recx sq w wc ncl ncc nclw nclh)             ; a call-bearing statement's record
        (spn sq w,
         (ncl < 1 ? ()
           (: _ (pin liv sq (sun w pales))          ; the outside-universe homes ride every wrap
              _ (pin n9 'ncw (nclw + peep n9 'ncw 0))
              _ (0 < nclh ? (pin n9 'nhc (nclh + peep n9 'nhc 0)))
              (bump (a . u)) (pin crs a (ncc + peep crs a 0),
                               (0 < nclh ? (pin crh a (nclh + peep crh a 0)) 0),
                               bump u)
            (0 < ncc || 0 < nclh ? (bump wc) 0))))
       (rec sq w ncl nclw nclh) (recx sq w w ncl ncl nclw nclh)
       ; a loop's record for the region splitter: its own tick, its last tick, the weight outside it,
       ; what is live entering it and leaving it, and the statement itself
       (lrc sq q0 w9 lin lout s) (pin n9 'loops ([sq q0 w9 lin lout s] . peep n9 'loops ()))
       ; -- an expression's universe reads -> (set ncalls): a var write is no read, sizeof never
       ; evaluates, an unknown head reads everything and counts a call --
       (erd e s2 nc)
        (!(two? e) ? [s2 nc]
           (e @ ('var nm) [(elem nm univ ? (sadd s2 nm) s2) nc]
                ((k . _) && elem k '(num flo str szof)) [s2 nc]
                ((k . x . _) && elem k '(dot deref addr post vastart vaend vaarg)) (erd x s2 nc)
                (k _ x && elem k '(un cast)) (erd x s2 nc)
                ('asn dst rhs) (erd rhs s2 nc @ r
                                  (<dst = 'var ? r (erd dst <r <>r)))
                ('bin _ a b) (erd a s2 nc @ r (erd b <r <>r))
                (k a b && elem k '(land lor comma)) (erd a s2 nc @ r (erd b <r <>r))
                ('cond c a b) (: r (erd c s2 nc) r2 (erd a <r <>r) (erd b <r2 <>r2))
                ('call fh as) (erd fh s2 (nc + 1) @ r (erdl as <r <>r))
                ('clit _ ini) (erdi ini s2 nc)
                ('init items) (erdi items s2 nc)
                [(sun s2 univ) (nc + 1)]))
       (erdl l s2 nc) (!(two? l) ? [s2 nc] (erd <l s2 nc @ r (erdl >l <r <>r)))
       ; a return value's reads, the tail call itself uncounted (nhcr's soft twin)
       (erdr e s2 nc)
        (!(two? e) ? [s2 nc]
           (e @ ('call fh as) (erd fh s2 nc @ r (erdl as <r <>r))
                ('comma a b) (erd a s2 nc @ r (erdr b <r <>r))
                ('cond c a b) (: r (erd c s2 nc) r2 (erdr a <r <>r) (erdr b <r2 <>r2))
                (k _ x && elem k '(un cast)) (erdr x s2 nc)
                (erd e s2 nc)))
       (erdi l s2 nc)                               ; init items: dfield/didx wrap their values
        (atom? l ? [s2 nc]
           (: it <l
              v (two? it && elem <it '(dfield didx) ? <>>it it)
              r (erd v s2 nc)
              (erdi >l <r <>r)))
       ; -- the names a statement declares, at any depth: dead at the entry of any loop around them,
       ; so a loop's seed drops them (else a loop-local name leaks out and crosses every earlier call) --
       (udn s acc)
        (atom? s ? acc
           (s @ (('decl || 'sdecl) ps) (foldl (a \ p \ <p . a) acc ps)
                (foldl (a \ k \ udn k a) acc (stkids s))))
       (ldrop set s) (foldl sdel set (udn s ()))
       ; -- a loop's uses (the back-edge seed): every name read, kills ignored; a goto inside reads the universe --
       (ust s acc)
        (s @ ('blk items) (ustl items acc)
             ('expr e9) <(erd e9 acc 0)
             ('ret . rv . _) (two? rv ? <(erd rv acc 0) acc)
             (('decl || 'sdecl) ps) (ustp ps acc)
             ('if cnd thn els) (: a1 <(erd cnd acc 0) a2 (ust thn a1) (ust els a2))
             ('if cnd thn) (<(erd cnd acc 0) @ a1 (ust thn a1))
             ('while cnd body) (ust body <(erd cnd acc 0))
             ('do body cnd) (ust body <(erd cnd acc 0))
             ('for ini cnd stp body)
              (: a1 (ini @ (('decl || 'sdecl) ps) (ustp ps acc)
                           (_ . x . _) <(erd x acc 0)
                           acc)
                 a2 (two? cnd ? <(erd cnd a1 0) a1)
                 a3 (two? stp ? <(erd stp a2 0) a2)
                 (ust body a3))
             ('switch ce items) (ustl items <(erd ce acc 0))
             ('goto nm) (peep lab nm 'no @ o (sun acc ((o == 'no) ? univ o)))
             (('asm || 'igoto) . _) (sun acc univ)
             acc)
       (ustl l acc) (!(two? l) ? acc (ustl >l (ust <l acc)))
       (ustp ps acc) (!(two? ps) ? acc (ustp >ps <(erd <>><ps acc 0)))
       ; -- the backward walk, children before their parent's tick (counting down = forward pre-order).
       ; w9 is the loop weight, x8 per level; wrapsets never depend on it --
       (litems l out brk cnt w9)
        (: (go l2 o) (!(two? l2) ? o (go >l2 (lst <l2 o brk cnt w9)))
           (go (rev l) out))
       (dpairs ps o nc)                             ; reversed decl pairs -> (in ncalls)
        (atom? ps ? [o nc]
           (: p <ps
              r (erd <>>p () 0)
              o2 (sun (elem <p univ ? (sdel o <p) o) <r)
              (dpairs >ps o2 (nc + <>r))))
       (lst s out brk cnt w9)
        (atom? s ? out
           (s @
              ('blk items) (: in (litems items out brk cnt w9) sq (tick ()) (spn sq in, in))
              ('expr e9)
               (: kv (e9 @ (('asn . ('var v) . _) && elem v univ) v ())
                  r (erd e9 () 0)
                  in (sun (kv ? (sdel out kv) out) <r)
                  ; the kill rides the record too: a name born here lives across the statement's own calls
                  sq (tick ()) (recx sq (sun (sun in out) (kv ? [kv]))
                                     (kv && <>r = 1 ? (sun in (sdel out kv)) (sun (sun in out) (kv ? [kv])))
                                     (<>r * w9) (<>r * w9)
                                     (1 < w9 ? (<>r * w9) 0) (nhc e9 * w9),
                                in))
              ('ret . rs)
               (: rv (two? rs ? <rs)
                  mt9 (1 < tally rs)                 ; clay's (ret e PRE): presence is the arity
                  r (two? rv ? (erd rv () 0) '(() 0))
                  _ (pin n9 'nx (1 + peep n9 'nx 0))
                  nct (two? rv ? <>(erdr rv () 0) 0)    ; the crossings charged: the tail call is none
                  sq (tick ()) (recx sq <r <r (<>r * w9) (nct * w9) (1 < w9 ? (<>r * w9) 0)
                                     (nhcr rv mt9 * w9),
                                <r))
              ('decl ps)
               (: pr (dpairs (rev ps) out 0)
                  ks (: (go p9) (two? p9 ?      ; the declared names: kills, in the record (see expr)
                                   (<<p9 @ nm
                                      (elem nm univ ? (nm . go >p9) (go >p9))))
                        (go ps))
                  sq (tick ()) (recx sq (sun (sun <pr out) ks)
                                     (<>pr = 1 ? (sun <pr (foldl sdel out ks)) (sun (sun <pr out) ks))
                                     (<>pr * w9) (<>pr * w9)
                                     (1 < w9 ? (<>pr * w9) 0)
                                    ((: (hs l) (!(two? l) ? 0 (nhc <>><l + hs >l)) (hs ps)) * w9),
                                <pr))
              ('sdecl . _) (tick () @ sq (spn sq out, out))   ; statics: no runtime init, no kill
              ('if . cnd . thn . er)
               (: els <er
                  inE (two? els ? (lst els out brk cnt w9) out)   ; else first (reverse order)
                  inT (lst thn out brk cnt w9)
                  r (erd cnd () 0)
                  in (sun (sun inT inE) <r)
                  sq (tick ()) (rec sq (sun in out) (<>r * w9) (1 < w9 ? (<>r * w9) 0)
                                    (nhc cnd * w9),
                                in))
              ('while cnd body)
               (: w8 (8 * w9)
                  seed (sun out (ldrop (ust body <(erd cnd () 0)) body))
                  q0 (peep n9 'q 0)
                  _ (lst body seed out seed w8)
                  r (erd cnd () 0)
                  sq (tick ()) (rec sq seed (<>r * w8) (<>r * w8) (nhc cnd * w8),
                                lrc sq q0 w9 seed out s,
                                seed))
              ('do body cnd)
               (: w8 (8 * w9)
                  seed (sun out (ldrop (ust body <(erd cnd () 0)) body))
                  r (erd cnd () 0)
                  q0 (peep n9 'q 0)
                  _ (lst body seed out seed w8)
                  sq (tick ()) (rec sq seed (<>r * w8) (<>r * w8) (nhc cnd * w8),
                                lrc sq q0 w9 seed out s,
                                seed))
              ('for ini cnd stp body)
               (: w8 (8 * w9)
                  useb (: u1 (two? cnd ? <(erd cnd () 0))
                          u2 (two? stp ? <(erd stp u1 0) u1)
                          (ust body u2))
                  seed (sun out (ldrop useb body))   ; the init's names are loop-carried: they stay
                  q0 (peep n9 'q 0)
                  _ (lst body seed out seed w8)
                  nc9 ((two? cnd ? <>(erd cnd () 0) 0) +
                       (two? stp ? <>(erd stp () 0) 0))
                  ri (two? ini && !(elem <ini '(decl sdecl)) ?
                        (erd <>ini () 0) '(() 0))
                  kv8 (two? ini && !(elem <ini '(decl sdecl)) ?
                         (<>ini @ (('asn . ('var v) . _) && elem v univ) v ()))
                  in (? !(two? ini) seed
                        (elem <ini '(decl sdecl)) (lst ini seed () () w9)   ; ticks (cgdecl does); kill applies; runs once
                        (sun (kv8 ? (sdel seed kv8) seed) <ri))
                  ; kv8 joins the record: the init's kill (see the expr lane)
                  sq (tick ()) (rec sq (sun (sun seed <ri) (kv8 ? [kv8])) (nc9 * w8 + <>ri * w9)
                                    (nc9 * w8 + (1 < w9 ? (<>ri * w9) 0))
                                    (((two? cnd ? (nhc cnd) 0) + (two? stp ? (nhc stp) 0)) * w8 +
                                     (two? ini && !(elem <ini '(decl sdecl)) ? (nhc <>ini) 0) * w9),
                                lrc sq q0 w9 in out s,
                                in))
              ('switch ce items)
               (: r (erd ce () 0)
                  _ (pin n9 'sw (() . peep n9 'sw ()))       ; push this switch's marker set
                  _ (litems items out out cnt w9)            ; brk = out; cont targets the outer loop
                  macc <(n9 'sw)
                  _ (pin n9 'sw >(n9 'sw))
                  in (sun (sun <r macc) out)
                  sq (tick ()) (rec sq in (<>r * w9) (1 < w9 ? (<>r * w9) 0)
                                    (nhc ce * w9),
                                in))
              (('case || 'dflt) . _)
               (: sw (n9 'sw)
                  _ (two? sw ? (pin n9 'sw (sun <sw out . >sw)))
                  sq (tick ()) (spn sq out, out))
              ('brk . _) (tick () @ sq (spn sq brk, brk))
              ('cont . _) (tick () @ sq (spn sq cnt, cnt))
              ('goto nm) (: o (peep lab nm 'no)
                            s9 ((o !== 'no) ? o (pin bwd nm 1, univ))   ; a target not yet passed: everything
                            sq (tick ()) (spn sq s9, s9))
              ('lbl nm) (tick () @ sq (spn sq out, abl? g 'glab ? () (pin lab nm out), out))
              (('asm || 'igoto) . _) (tick () @ sq (rec sq univ w9 (1 < w9 ? w9 0) w9, univ))   ; homing is off anyway (hasasm)
              (tick () @ sq (spn sq out, out))))   ; nop tdef
       ; -- run: the counter descends from the prepass total; pre and lst disagreeing misses zero,
       ; and alive answers () --
       _ (pin n9 'q (peep n9 'n 0))
       _ (litems items () () () 1)
       _ (rdn items 1)
       ; d128 material anywhere: the wide-pair park rides two pool registers per op, so no ride may drain the file
       (wdc e) (? (atom? e) ()
                  (<e == 'szof) ()
                  (<e == 'cast && d128? <>e) 1
                  (: (go l) (? (atom? l) ()
                               (two? <l && wdc <l) 1
                               (go >l))
                     (go e)))
       wd9 ((: (go i) (peep n9 'sq 0 >= i ?
                       (sqm i @ e2 (two? e2 && d128? <>e2 || go (i + 1))))
            (go 1)) ||
            (: (go l) (? !(two? l) () (d128? <><l) 1 (go >l)) (go params)) ||
            wdc items)
       ; the wide park's peak draw: a wide binop holds its left's two-register park while its right
       ; evaluates, so a right that parks again doubles it. a miss costs speed only (the cell lane)
       wdn (: (go i acc) (peep n9 'sq 0 < i ? acc
                             (sqm i @ e2 (go (i + 1) (two? e2 && d128? <>e2 ? (<e2 . acc) acc))))
              (go 1 (map (p \ <p) (filter (p \ d128? <>p) params))))
       (wide? e) (atom? e ? ()
                    (e @ ('cast ty _) (d128? ty) ('var nm) (elem nm wdn) ('bin _ l r) (wide? l || wide? r) ()))
       (wpd e) (atom? e ? 0
                  (e @ ('bin _ l r) (wide? l || wide? r ? (max (wpd l) (2 + wpd r)) (max (wpd l) (wpd r)))
                       (foldl (m \ x \ max m (wpd x)) 0 e)))
       pq9 (0 = pdtl items && !wd9)
       ; an asm anywhere pins its operands' registers, inside a statement expression too
       (asmin e) (? (atom? e) () (<e = 'asm) 1 (any asmin e))
       (0 = peep n9 'q 0 ?
          [liv crs univ (peep n9 'n 0) (peep n9 'ncw 0) spa
           crh rdc rdt sqm (peep n9 'nx 0)
           (peep n9 'asm 0 || asmin items) (peep n9 'vla 0) (peep n9 'sq 0) tak
           (pmxl items 1 1) (pq9 ? 1) (wd9 ? 1) (wd9 ? (wpd items) 0) (peep n9 'loops ())]))
   ; alive's forward twin: cgstmt/cgdecl/cgsdecl entries tick and pin the wrapset off livtab
   ; (a miss pins 'all); a statement expression's statements neither tick nor re-pin
   (stq g)
    (g 'inlining ? (peep g 'stwrap 'all)
       (: q (1 + peep g 'lsq 0)
          _ (pins g 'lsq q 'spq q)          ; spq: the tick whose code is laying (a for's step, a do's
          lt (g 'livtab)                    ; cond lay after their body and pin it back to their own)
          w (lt ? (peep lt q 'all) 'all)
          (pin g 'stwrap w,
           w)))
   ; the seat channels' neutral state; per-fn entry and the build teardown share it
   (rgreset g)
    (pins g
     'livtab ()  ; liveness (set only for a seat-bearing build)
     'lhome ()   ; locals-homing map (cgdecl's hook reads it)
     'rgon ()    ; ...and its seat-bearing flag (the splice decl gate)
     'fpar {}    ; double params granted an xmm seat (ubuild fills it, spill reads it)
     'spov {}    ; the loop splitter's seats: name -> ([lo hi reg]..) (vent and cgdecl read it)
     'splits {}  ; ..and its transfers: a loop's tick -> [evicted promoted] (cgstmt lays them)
     'homes ())  ; non-leaf home set (call-fixed + sibs read it)
   ; ..and their armed state: lh9 ulloc's map, av9 alive's answer
   (rgset g lh9 av9)
    (pins g
     'homes ()
     'lhome lh9
     'rgon 1
     'livtab <av9)
   ; the per-build counters, armed fresh per build attempt
   (bldreset g) (pins g
    'dseq 0                    ; the locals-homing decl sequence
    'lrec ()
    'lsq 0                     ; the alive statement counter
    'stwrap 'all
    'vrn 0                     ; the vreg mint counter (the shadow: ralloc mints, vrfix resolves)
    'vdone ()                  ; vpre assigned this build's mints
    'vweb {}                   ; ..and the staging webs among them
    'vrt {})           ; ...and its per-build map, mint -> physical
   ; every per-fn pin and its neutral, one roster: a new per-fn pin registers here (the computed
   ; ones -- fn, epi, pool, vslots, fc, sret -- re-pin at their owner)
   (fnreset g)
    (pins (rgreset g)          ; the seat channels' neutral state -- disjoint pin set
     'off (g 'sspf ? 16 8)      ; the frame cursor: slot -8 = saved r3 (see epi), -16 the canary
     'slots ()                 ; the frame's object map ((off n)..; nslot appends)
     'fesc ()                  ; escape flag (the sibcall gate reads it)
     'fescv ()                 ; ..a frame address become a value (a musttail call still jumps)
     'lpm ()                   ; lprop's answers: the fn's tree passes are done with them
     'kpm ()                   ; ..and kprop's
     'fesca ()                 ; ..and a frame address handed a call (a later call may not jump past it)
     'inlining ()              ; statement-expression depth (stq's conservative wrapset)
     'hasasm ()                ; an asm statement pins it (homing off)
     'twice ()                 ; a call returning twice pins it (no callee-saved pool)
     'ebx ()                   ; i386: ebx joins the seats (cgfn's second build)
     'ltaken ()                ; the labels a &&L names (a computed goto's targets)
     'fpin (g 'sspf)           ; the frame link is asked for by name (unframe stands off)
     'cssv ()                  ; the callee-saved save forms (a cs grant pins)
     'sret ()                  ; the memory-return slot (the driver re-pins under sr6f)
     'pcopy ())                ; the by-reference struct params' copies, laid after the spills (spillp)

   ; a split loop's transfers: an evicted name parks in its slot at entry and takes it back past the
   ; exit label (every break lands there); a seated cell loads at entry and stores back -- each only
   ; where alive has the name live across that edge, and only for a name declared by then
   (spw g env tk fs)
    (peep (g 'splits) tk () @ sp
       (? (!(two? sp) || g 'inlining) fs
          (: (slot nm) (: (go l) (? !(two? l) () (<l 3 = nm) (<l 1) (go >l)) (go (g 'lrec)))
             ; a cell the loop itself declares (its for-init) crosses none of its edges
             (cell nm) (assoc nm env @ e (two? e && charm? <>e ? [<>e <>>e]))
             pre (catmap (x \ (<>>x = 1 && charm? (slot <x) ? [['st 'r4 (slot <x) <>x]])) <sp
                  + catmap (x \ (<>>x = 1 ? (cell <x @ c (two? c ? [[(ldop <>c) <>x 'r4 <c]])))) <>sp)
             ; the exit mirrors the entry: a seated cell leaves its register first
             post (catmap (x \ (x 3 = 1 ? (cell <x @ c (two? c ? [[(stop <>c) 'r4 <c <>x]])))) <>sp
                   + catmap (x \ (x 3 = 1 && charm? (slot <x) ? [['ld <>x 'r4 (slot <x)]])) <sp)
             (pre + fs + post))))
   (cgstmt g env s)
    (: _ (psreset g)                                 ; a statement never carries a live operand in
       myw (stq g)                                   ; this statement's wrapset (alive's forward twin)
       tk9 (peep g 'lsq 0)                           ; ..and its tick, the loop splitter's key
       (s @- 'bad                                                        ; the refusal up front
          ('ret . rs)
          (: epj (peep g 'epi epi)                                       ; the target's epilogue (cgen-core pins it)
             mt (1 < tally rs)                                           ; clay's (ret e PRE): presence is the arity
             rr9
             (!(two? <rs) ?
                 (mt ? (nolane g "a musttail return carries no call") epj)   ; bare `return;`
                (: r (cgexpr g env <rs 'r0)
                   rt <(peep (g 'sigs) (g 'fn) ['long ()])
                   res
                   (? (bad? r) 'bad
                      (n32? g rt) (asf32 g r + (? (v6m? g) '((movdrx r0 f0)) (ia32? g) [['raw (x87raw g 1 ())]] ()) + epj)   ; binary32 in its register (v6-M: r0; i386: st(0))
                      (flo? rt)                                        ; a double returns in f0 (xmm0);
                       (asflo g r                                      ; v6-M: a double on r0:r1, a float as one word in r0
                        + (? (ia32? g) [['raw (x87raw g () ())]]       ; i386: st(0)
                             ((t32f? g || f32abi? g) && rt = 'float) '((cvtsd2ss f0 f0))   ; narrow into s0, d0's own low half
                             !(v6m? g) ()
                             (rt = 'float) '((cvtsd2ss f0 f0) (movqrx r0 f0))
                             '((movqrx r0 f0)))
                        + epj)
                      (v6m? g && stru? rt)                 ; v6-M composite: >4B fills the caller's temp
                       (4 < tsz g rt ?                   ; through the saved sret pointer;
                          (tor0 g r                        ; <=4B rides r0
                           + [['ld 'r1 'r4 (peep g 'sret 0)]]
                           + bcopy g 0 (tsz g rt) () + epj)
                          (tor0 g r + '((ld r0 r0 0)) + epj))
                      (t32? g && sretm? g rt)              ; AAPCS-VFP: a non-HFA past 4B, the same memory lane
                       (tor0 g r
                        + [['ld 'r1 'r4 (peep g 'sret 0)]]
                        + bcopy g 0 (tsz g rt) () + epj)
                      (t32nolane? g rt) 'bad
                      (cxf32? g rt) (tor0 g r + '((ld4 r2 r0 4) (ld4 r0 r0 0)) + epj)   ; edx:eax
                      (a64hfa g rt)                                      ; an a64 float HFA returns in s0..
                       (tor0 g r + catmap (j \ [['ldss (xmmreg j) 'r0 (4 * j)]]) ^(a64hfa g rt) + epj)
                      (sse2? g rt)                                       ; the xmm pair
                       (tor0 g r + (amark rt r @ ma (salw? g ma ?
                                      (: a (tal g ma) (ldal 'r1 'r0 8 8 a + [['movqxr (xmmreg 1) 'r1]] + ldal 'r0 'r0 0 8 a + [['movqxr (xmmreg 0) 'r0]]))
                                      (fldf 'double (xmmreg 0) 'r0 0 + fldf 'double (xmmreg 1) 'r0 8))) + epj)
                      (ipair? g rt)                                      ; rax:rdx (a64 x0:x1)
                       (tor0 g r + (amark rt r @ ma (salw? g ma ? (ldal (ip2 g) 'r0 8 (tsz g ma - 8) (tal g ma) + ldal 'r0 'r0 0 8 (tal g ma))
                                      [['ld (ip2 g) 'r0 8] '(ld r0 r0 0)])) + epj)
                      (aone g rt = 'sse)                             ; its eightbyte in xmm0
                       (tor0 g r + (amark rt r @ ma (salw? g ma ? (ldal 'r0 'r0 0 (tsz g ma) (tal g ma) + [['movqxr (xmmreg 0) 'r0]])
                                      (fldf 'double (xmmreg 0) 'r0 0))) + epj)
                      (aone g rt = 'int)                             ; rax (a union rides here)
                       (tor0 g r + (amark rt r @ ma (salw? g ma ? (ldal 'r0 'r0 0 (tsz g ma) (tal g ma)) '((ld r0 r0 0)))) + epj)
                      (amem? g rt || refm? g rt)                         ; a memory return: fill the caller's temp through
                       (tor0 g r                                         ; the saved hidden pointer, and answer it in rax
                        + [['ld 'r1 'r4 (peep g 'sret 0)]]
                        + (sal? g ? (bcopya 0 (tsz g rt) (tal g (amark rt r))) (bcopy g 0 (tsz g rt) ())) + '((mov r0 r1)) + epj)
                      (stru? rt || stru? (vty r))                        ; any other composite: no lane
                       (nolane g "no lane for returning this \(tsz g (stru? rt ? rt (vty r)))-byte struct by value\(ontgt g)")
                      (flo? (vty r)) (asintt g r rt + (rt @ 'bool (cvt rt 'r0) ()) + epj)     ; a double value, an int return -> truncate to r0
                      (pair? g rt) (asll g r + (ia32? g ? [['mov 'r2 'r1]] ()) + epj)   ; a pair return: r0:r1 (widen a word value); i386's is edx:eax
                      (d128? rt)                                                ; a wide return rides rdx:rax (SysV), x0:x1 (AAPCS64)
                       (w128? g ? (as128 g r + (a64? g ? [['mov 'r1 'r2]]) + epj) (no128 g))
                      (rt = 'bool)                             ; a bool return converts (callers read r0 whole)
                       (tor0 g r + cvt rt 'r0 + epj)
                      ; int -> int: a value the return type cannot hold converts
                      (tor0 g r + (irfit? (vty r) rt ? () (cvt rt 'r0)) + epj))
                   (!mt || bad? res ? res (mustret g res))))
             rr9)         ; a musttail ret marks its call for sibs
          ('expr pe)
           (: rv (<pe = 'post && <<>pe = 'var ?
                    (vent g env <><>pe) 'bad)
              (? (two? rv && <rv = 'regv && fhomable? <>>rv)   ; x++; on an xmm home
                  (vfs (mkflo g (0.0 + <>>pe))
                   + (<>>rv = 'float ? [['cvtsd2ss 'f0 'f0] ['addss <>rv 'f0]] [['addsd <>rv 'f0]]))
                 (two? rv && <rv = 'regv)     ; the old value is dead
                  (: ty <>>rv stp (ptr? ty ? (tsz g <>ty) 1)
                     ([['add <>rv <>rv (stp * <>>pe)]] + cvt ty <>rv))
                 ; a statement-position constant into a static slot: one store-immediate (x64)
                 (: sv (<pe = 'asn && <<>pe = 'var ? (vent g env <><>pe) 'bad)
                    sk (x64t? g && two? sv && elem <sv '(loc glo) &&
                        (<>>sv @ t9
                           !(stru? t9 || arr? t9 || flo? t9 || pair? g t9 ||
                             d128? t9 || t9 = 'bool)) &&
                        <<>>pe = 'num && charm? <><>>pe ?
                          (siop9 <>>sv <><>>pe))
                    (sk ? (atstat sv 'r1 (b \ o \ [[sk b o <><>>pe]]))
                       (: _ (<pe = 'asn && !(abl? g 'stnar) ? (pin g 'drop9 1))
                          r (cgexpr g env pe ())
                          (bad? r ? 'bad (vdrop g r)))))))
          ('nop . _) ()
          ('tdef . _) ()                            ; a block-scope _Static_assert
          ('blk items) (cgitems g env items ())
          ('if . cnd . thn . er)
           (: le (nlab g ".e")
              xm (thn @ ('blk (('nop m) . _)) m ())                    ; the parser's __builtin_expect mark
              _ (xm @ 'hot (pin g 'hot (le . peep g 'hot ()))              ; tailarm leaves the arm
                      'cold (pin g 'cold (le . peep g 'cold ()))           ; ..or lays it past the function
                      ())
              c (cbranch g env cnd 'eq le)
              t (cgstmt g env thn)
              (? (bad? c || bad? t) 'bad
                 !(two? <er)
                  (c + t + [['label le]])
                 (: el (cgstmt g env <er)
                    ld (nlab g ".d")
                    (bad? el ? 'bad
                     (c + t + [['jmp ld] ['label le]] + (el + [['label ld]]))))))
          ; loops are bottom-tested: one branch an iteration, not two
          ('while cnd body)
           (: lb (nlab g ".b") lc (nlab g ".c") ld (nlab g ".d")
              c (cbranch g env cnd 'ne lb)
              _ (pins g 'brk (ld . g 'brk)
                        'cnt (lc . g 'cnt))
              b (cgstmt g env body)
              (pins g 'brk >(g 'brk)
                      'cnt >(g 'cnt),
               bad? c || bad? b ? 'bad
               (spw g env tk9 ([['jmp lc]] + lalign g + [['label lb]] + b + [['label lc]] + c + [['label ld]]))))
          ('for init cnd stp body)
           (: lb (nlab g ".b") lc (nlab g ".c") ls (nlab g ".s") ld (nlab g ".d")
              ir (? !(two? init) [() env]
                    (<init = 'decl) (cgdecl g env <>init)
                    (<init = 'sdecl) (cgsdecl g env <>init)
                    (cgexpr g env <>init () @ r
                       (bad? r ? 'bad [(vdrop g r) env])))
              (bad? ir ? 'bad
                 (: env2 <>ir
                    _ (pins g 'stwrap myw 'spq tk9)  ; a decl init re-pinned; the cond is ours
                    c (two? cnd ? (cbranch g env2 cnd 'ne lb))
                    _ (pins g 'brk (ld . g 'brk)
                              'cnt (ls . g 'cnt))
                    b (cgstmt g env2 body)
                    _ (pins g 'brk >(g 'brk)
                              'cnt >(g 'cnt)
                              'stwrap myw            ; the body re-pinned as it went; the step is ours
                              'spq tk9)
                    _ (pin g 'bndv (bndv g env2 cnd stp body))
                    st2 (two? stp ? (cgexpr g env2 stp ()))
                    (pin g 'bndv (),
                     bad? c || bad? b || bad? st2 ? 'bad
                       (spw g env tk9
                         (<ir + (two? cnd ? ([['jmp lc]] + lalign g)) + [['label lb]] +
                          b + [['label ls]] + (two? st2 ? (vdrop g st2)) +
                          (two? cnd ? ([['label lc]] + c) [['jmp lb]]) +
                          [['label ld]]))))))
          ('brk . _)
           (two? (g 'brk) ? [['jmp <(g 'brk)]] 'bad)
          ('cont . _)
           (two? (g 'cnt) ? [['jmp <(g 'cnt)]] 'bad)
          ('do body cnd)
           (: lt (nlab g ".t") lc (nlab g ".c") ld (nlab g ".d")
              _ (pins g 'brk (ld . g 'brk)
                        'cnt (lc . g 'cnt))
              b (cgstmt g env body)
              _ (pins g 'brk >(g 'brk)
                        'cnt >(g 'cnt)
                        'stwrap myw                  ; the body re-pinned as it went; the cond is ours
                        'spq tk9)
              c (cbranch g env cnd 'ne lt)
              (bad? b || bad? c ? 'bad
                 (spw g env tk9
                   ([['label lt]] +
                    b +
                    [['label lc]] +
                    (c + [['label ld]])))))
          ('goto nm) [['jmp (name "\(g 'fn).\(nm)")]]
          ; goto *e: a table jump over every label whose address the function takes
          ('igoto e)
           (: ls (map (nm \ name "\(g 'fn).\(nm)") (g 'ltaken))
              (? (wasm? g) (asmno g "a computed goto has no wasm lane")
                 !(two? ls) (asmno g "a computed goto in a function that takes no label's address")
                 (cgexpr g env e 'r0 @ r
                    (bad? r ? 'bad (tor0 g r + [['jmpt 'r0 <ls ls]])))))
          ('lbl nm) [['label (name "\(g 'fn).\(nm)")]]
          ('asm . _) (cgasm g env s)
          ('ssp k) (sspblob g k)
          ; case/default labels come from the tablet atop g 'cases (the switch's pre-scan);
          ; no enclosing switch, or an unscanned value, refuses
          ('case lo hi)
           (!(two? (g 'cases)) ? 'bad
              (peep <(g 'cases) [lo hi] 'no @ lab
                 (lab @ 'no 'bad [['label lab]])))
          ('case cv)
           (!(two? (g 'cases)) ? 'bad
              (peep <(g 'cases) cv 'no @ lab
                 (lab @ 'no 'bad [['label lab]])))
          ('dflt . _)
           (!(two? (g 'cases)) ? 'bad
              (peep <(g 'cases) 'dflt 'no @ lab
                 (lab = 'no ? 'bad [['label lab]])))
          ('switch ce items9)
           (: c (cgexpr g env ce ())
              items (swdead g env ce items9 @ sw (sw @ 'no items9 sw))
              (bad? c ? 'bad
                 (: cr9 (vreg c)
                    lend (nlab g ".d")
                    tab {}
                    cases (rev (scasel-l g items tab ()))   ; -> (value label) dispatch pairs
                    dflt (peep tab 'dflt lend)
                    dup9 (peep tab 'dup ())
                    ; a range is two compares in the control's own signedness, r1 the scratch as
                    ; a single case's: below lo skips past, at most hi takes the case
                    (rng lo hi lab)
                     (: ty (vty c) u (usg? ty) l9 (cfit g ty lo) h9 (cfit g ty hi) sk (nlab g ".r")
                        (cmpk v) (immok g 'cmp v ? [['cmp cr9 v]] [['li 'r1 v] ['cmp cr9 'r1]])
                        (cmpk l9 + [['br (scc 'lt u) sk]] + cmpk h9 + [['br (scc 'le u) lab] ['label sk]]))
                    chain (: (go l acc)
                             (? !(two? l) acc
                                (bad? acc) acc
                                (two? <<l) (rng <<<l <><<l <><l @ r (bad? r ? 'bad (go >l (acc + r))))
                                (: e2 <l  v (cfit g (vty c) <e2)  lab <>e2
                                   ins (immok g 'cmp v ?
                                          [['cmp cr9 v] ['br 'eq lab]]
                                          [['li 'r1 v] ['cmp cr9 'r1] ['br 'eq lab]])
                                   (go >l (acc + ins))))
                            (go cases ()))
                    jt (jtable g c cr9 cases dflt)
                    disp (jt @ 'no chain jt)
                    _ (rfree g cr9)
                    _ (pins g 'brk (lend . g 'brk)
                              'brkm (() . peep g 'brkm ())   ; lock-step (a switch break's snap is discarded)
                              'cases (tab . g 'cases)) ; push
                    body (cgitems g env items ())
                    (pins g 'brk >(g 'brk)
                            'brkm >(g 'brkm)
                            'cases >(g 'cases),      ; pop
                     (? dup9 (nolane g "a duplicate case value, or a second default, in one switch")
                        (bad? body || bad? disp) 'bad
                        (vfs c + disp + [['jmp dflt]] + (body + [['label lend]])))))))))
   (cgitems g env items acc) (sxpre g env items acc @ r (bad? r ? 'bad <r))   ; -> forms | 'bad

   ; -- the switch's table lane -> forms | 'no (the caller keeps its chain) --
   ; index = control - lo, one unsigned compare bounds it. rel32 entries settle at link (so .rodata,
   ; no -pie slide): leax lands on the cell's end, ld4 reads back -4. jmpt names its targets for deadlab
   (jtable g c cr9 cases dflt)
    (: vs (sort (map (e2 \ (two? <e2 ? 0 (cfit g (vty c) <e2))) cases))
       n9 #cases
       lo (two? vs ? <vs 0)
       hi (two? vs ? (vs (n9 - 1)) 0)
       span (hi - lo + 1)
       (? (wasm? g || t32? g) 'no               ; no memory table on wasm; t32's REL lane is unproven here
          (any (e2 \ two? <e2) cases) 'no         ; a range rides the chain
          (abl? g 'jtab || njt? g) 'no            ; -fno-jump-tables, as the kernel's retpoline asks
          (n9 < 6) 'no                             ; fewer cases than a table is worth
          (4096 < span) 'no                         ; ..and a span no table should cover
          (3 * n9 < span) 'no                     ; too sparse: a third full is the floor
          !(immok g 'cmp (span - 1)) 'no
          (!(lo = 0) && !(imma g 'sub lo)) 'no
          (: tv (foldl (t \ e2 \ pin t (cfit g (vty c) <e2) <>e2) {} cases)
             labs (foldl (l \ e2 \ elem <>e2 l ? l (<>e2 . l)) [dflt] cases)
             tl (nlab g ".J")
             (lay rI rT)
              (pin g 'jtabs ([tl (catall (map (i \ [['fix 4 'rel32 (peep tv (lo + i) dflt) 0]]) ^span))] . g 'jtabs),
               (lo = 0 ? (rpeq? g rI cr9 ? () [['mov rI cr9]])
                  [['sub rI cr9 lo]]) +
               [['cmp rI (span - 1)] ['br 'above dflt] ['la rT tl]
                ['leax rT rT rI 4 4] ['ld4 rI rT -4] ['add rT rT rI]
                ['jmpt rT tl labs]])
             ; i386 has no pool: ecx and edx are free at the dispatch, which nothing else is live across
             (? (ia32? g) (rpeq? g cr9 'r2 ? 'no (lay 'r1 'r2))
             (: rI (wr? g cr9 ? cr9 (ralloc g))
             (!rI ? 'no
                (ralloc g @ rT
                   (!rT ? (rpeq? g rI cr9 ? () (rfree g rI), 'no)
                      (rfree g rT,
                       rpeq? g rI cr9 ? () (rfree g rI),
                       lay rI rT)))))))))
   ; a block's items, each decl extending env -> (forms env) | 'bad; cgexpr reaches it through g
   ; (a direct edge would close the cycle into cgstmt)
   (sxpre g env items acc)
    (!(two? items) ? [acc env]
       (<items @ it
          (it @ ('decl ps)
                 (cgdecl g env ps @ r
                    (bad? r ? 'bad (sxpre g <>r >items (acc + <r))))
                ('sdecl ps)
                 (cgsdecl g env ps @ r
                    (bad? r ? 'bad (sxpre g <>r >items (acc + <r))))
                (cgstmt g env it @ r
                   (bad? r ? 'bad (sxpre g env >items (acc + r)))))))

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
   ; a switch body's case/default labels at any depth, pinned into tab -> (value label) pairs
   ; a value held twice (C11 6.8.4.2p3), or a second default, marks 'dup
   (scover? tab a b)
    (any (k \ (? (charm? k) (a <= k && k <= b) (two? k) (<k <= b && a <= <>k) ())) (keys tab))
   (scasel g it tab acc)
    (!(two? it) ? acc
       (it @ ('case lo hi)  (: _ (scover? tab lo hi && pin tab 'dup 1)
                               (nlab g ".k" @ lab (pin tab [lo hi] lab, [[lo hi] lab . acc])))   ; a range: one label
             ('case cv)     (: _ (scover? tab cv cv && pin tab 'dup 1)
                               (nlab g ".k" @ lab (pin tab cv lab, [cv lab . acc])))
             ('dflt . _)   (: _ (peep tab 'dflt () && pin tab 'dup 1)
                              (nlab g ".k" @ lab (pin tab 'dflt lab, acc)))
             ('switch . _) acc                                   ; a nested switch owns its labels
             (scasel-l g (stkids it) tab acc)))
   (scasel-l g l tab acc) (!(two? l) ? acc (scasel-l g >l tab (scasel g <l tab acc)))
   ; a switch over a constant (sizeof) lays the cases it does not select with their asm as empty
   ; statements, as gcc never assembles it. only with every label at the top and no goto's label
   ; in the body -> items | 'no
   (swdead g env ce items)
    (: v (ce @ ('szof e2) (peekty g env e2 @ ty (bad? ty || gvarr? ty ? () (tsz g ty)))
              (memk g ce))
       (lab? it) (two? it && elem <it '(case dflt))
       (nest? x) (? !(two? x) () (elem <x '(case dflt)) 1 (<x = 'switch) () (any nest? x))
       (lbl? x) (? !(two? x) () (<x = 'lbl) 1 (any lbl? x))
       (idx k) ((: (go l i) (? !(two? l) -1 (<l = k) i (go >l (i + 1)))) items 0)
       at (idx ['case v] @ j (j < 0 ? (idx ['dflt]) j))
       (strip x) (? !(two? x) x (<x = 'asm) ['expr ['num 0]] (map strip x))
       ; live from the selected label to the first break at the top, or a block's last statement
       (ends? it) (it = ['brk] || <it = 'blk && two? <>it && <>it (#<>it - 1) = ['brk])
       (go l i live acc)
        (!(two? l) ? (rev acc)
           (: it <l
              kept (live || i = at || lab? it)
              (go >l (i + 1) (i = at ? !(ends? it) (live && !(ends? it)))
                  ((kept ? it (strip it)) . acc))))
       (!(charm? v) || any (it \ (<it = 'case && #it != 2) || (!(lab? it) && nest? it)) items
        || any lbl? items ?
          'no
          (go items 0 () ())))

   ; -- the inline lane: a small (or always_inline) fn splices its body at the call site, each arg in
   ; a fresh 8-byte temp, each return into r0 then a jump to the splice's end label --
   ; an always_inline body splices without its canary: the caller's frame is the one guarded
   (sspcut x) (? !(two? x) x (<x == 'ssp) '(nop) (map sspcut x))
   (noinl? x) (? (elem x '(sdecl goto lbl vastart varr ssp)) 1   ; varr: a VLA's slots ride cgfn's per-fn prescan; ssp its canary cell
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
       pn (dv x (map (p \ <p) ps))
       (pv? e) (pvl pn e)
       (imm? c) (#c @ n ((: (go i) (? (i >= n) () (elem (c i) '(105 110)) 1 (go (i + 1)))) 0))
       (go y) (? !(two? y) ()
                 (<y = 'asm) (any (o \ imm? <o && pv? <>o) (y 3))
                 (y @ ('call ('var fn) as) (peep (g 'ineed) fn () && any pv? as ? 1 (go as))
                      (go <y || go >y)))
       (go x))
   (noinlj? x) (? (elem x '(sdecl vastart varr)) 1 (atom? x) ()
                  (x @ ('call _ as && 6 < tally as) 1 ()) 1
                  (noinlj? <x || noinlj? >x))
   (oneret? (i . u))                                  ; decls* + one trailing `return expr`
    (i @ ('decl . _) (oneret? u)
         (('ret . rv . _) && two? rv) !(two? u))
   ; a body's weight by its structure: a name, a number or an operator one unit each, and a
   ; __builtin_expect (with the !! it wraps) its operand -- a hint lays no code
   (aweigh x)
    (? !(two? x) 1
       (x @ ('call ('var b9) [a _] && b9 = "__builtin_expect")
             (a @ ('un 'not ('un 'not a2)) (aweigh a2) (aweigh a))
            ('var _) 1
            (foldl (n \ y \ n + aweigh y) 0 x)))
   (inlok? g f sig aln)                             ; aln: always_inline waives the size gate
    (: rt (two? sig ? <sig 'long)
       items <><>>>f
       (dbl? ty) (ty = 'double && fsel? g)              ; a double binds and returns in the float file
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
          ; the size gate on the body's weight: 99 single-return, 43 branchy
          (!aln && (oneret? items ? 99 43) < aweigh <>>>f) ()
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
                    ('sexpr . ss . v . _) ((!(two? v) || fxless? v) && atom? (filter (st \ !(fxlst? st)) ss))
                    ())
   (fxlst? st) (st @ ('decl ps) (atom? (filter (p \ two? >>p && <>>p != ()) ps))
                     ('expr e) (fxless? e)
                     ('nop) 1
                     ())
   (acand g nm)                                    ; -> (params body rt locals frees decls) | ()
    (g 'inl nm @ f
       (two? f ?
          (: rf (respell f)
             ps <>>rf
             ; dead arms pruned before any splice: a call types by its signature, a cast by its type
             (sty e) (e @ ('call ('var n) _) <(peep (g 'sigs) n [()]) ('cast t _) t ())
             body (nofx (dprune !(ilp32? g) sty <>(rf 3)))
             (dps x a) (? !(two? x) a
                          (<x = 'decl) (foldl (a2 \ p \ p . a2) a <>x)
                          (dps >x (dps <x a)))
             dl (dps body ())
             loc (map (p \ <p) ps + map (p \ <p) dl)
             ; a frame address costs the caller its sibcalls, a return address read in place is the caller's,
             ; asm bars it unless the body compiles only spliced. always_inline waives both, as gcc reads it
             need (peep (g 'ineed) nm ())
             alw (peep (g 'alw) nm ())
             (bar? x) (two? x ?
                         (x @ ('addr ('var v)) (elem v loc)
                              ; the overflow builtins' result pointer is written in place: a local's address there does not escape
                              ('call ('var b9) [a1 a2 a3] && elem b9 '("__builtin_add_overflow" "__builtin_sub_overflow" "__builtin_mul_overflow"))
                               (bar? a1 || bar? a2 || (a3 @ ('addr ('var v)) () (bar? a3)))
                              ('call ('var b9) _ && b9 = "__builtin_frame_address") 1
                              ('call ('var b9) _ && b9 = "__builtin_return_address") !alw
                              ('asm . _) (need || alw ? (bar? >x) 1)
                              (('clit || 'sexpr) . _) 1
                              (bar? <x || bar? >x)))
             (fv x a) (!(two? x) ? a
                         (x @ ('var v) (elem v loc || elem v a ? a (v . a))
                              (fv >x (fv <x a))))
             (? (bar? body) ()
                (foldl (a \ p \ a || stru? <>p || arr? <>p) () dl) ()
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
       ps9 {'locals tys 'globals gty 'sigs (g 'sigs) 'stag (g 'stag) 'tgt (g 'tgt)}
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
                ; a body that compiles only spliced has no call to fall back on: it reaches deeper
                ((peep (g 'ineed) nm () ? 8 3) < #d) ()
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
                                 (ty9 = <>p && !(tak <>a) && !(wrs? <p bd))
                                  (pin m <p <>a, bind >ps >as pre)
                                 (tx != 'no)
                                  (<>p = ['ptr tx] && !(wrs? <p bd) && aonly <p bd ?
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
                 (: ra (hxb a d) rb (hxh e d (h \ (hxe b d h))) b2 <>rb
                    (!(armc? b2) ? [(<ra + <rb) [<e <>ra b2]]
                       (: t (tmp 'int)
                          s1 ['expr ['asn ['var t] ['num 1]]] s0 ['expr ['asn ['var t] ['num 0]]]
                          st (hs (<e = 'land ? ['if <>ra ['if b2 s1 s0] s0] ['if <>ra s1 ['if b2 s1 s0]]) d)
                          [(<ra + <rb + [['decl [[t 'int]]]] + st) ['var t]])))
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
              (: ra (hxb a d) rb (hxh e d (h \ (hxe b d h))) b2 <>rb
                 ty (armc? b2 ? (ety b))
                 (ty = () ? [(<ra + <rb) [<e <>ra b2]]
                    (: tv (tmp ty)
                       st (hs (<e = 'land ? ['if <>ra ['expr ['asn ['var tv] b2]] ['expr ['asn ['var tv] ['num 0]]]]
                                              ['if <>ra ['expr ['asn ['var tv] ['num 1]]] ['expr ['asn ['var tv] b2]]]) d)
                       [(<ra + <rb + [['decl [[tv ty]]]] + st) ['var tv]])))
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
                 (: rb (hxh s d (h \ (hxe b d h))) b2 <>rb
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
   (dprune w64 ty x)
    (atom? x ? x
       (x @ ('cond c a b)
             (: v (bcpopen? w64 c ? () (zfold w64 c)) t (? (!(cint? v) || lbl? a || lbl? b) () (ty a = ty b) (ty a) ())
                (!t ? (map (dprune w64 ty) x) ['cast t (dprune w64 ty (v != 0 ? a b))]))
            ('if c th el)
             ((bcpopen? w64 c ? () (zfold w64 c)) @ v
                (!(cint? v) || lbl? th || lbl? el ? (map (dprune w64 ty) x)
                   (: s (v != 0 ? th el) (two? s ? (dprune w64 ty s) '(nop)))))
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
                   (glb? l) (any (it \ glbl? it) l)
                   (? (k < 1 || glb? (take k items) || any (it \ !(elem <it '(case dflt)) && ncase? it) items) (map (dprune w64 ty) x)
                      ['switch c (map (dprune w64 ty) (drop k items))])))
            (map (dprune w64 ty) x)))
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
       (fix keep) (: r (go keep (f 3)) t (refs r {}) (all (n \ keep n) (keys t) ? r (fix (foldl (a \ n \ pin a n 1) keep (keys t)))))
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
       _ (map (f \ (<f = 'fn ? (respell f @ r (rel? r ? (scan (lprop g (dprune !(ilp32? g) (e \ ()) (lprop g r)))) (scan r)))
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
       (map (f \ (<f = 'fn ? (one f) f)) fs))
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
       tak {} tys {}
       ; an asm's memory operand takes its name's address, as kprop reads it
       (mem? c) ((: (go i) (? (#c <= i) () (elem (c i) '(109 111)) 1 (go (i + 1)))) 0)
       (cen x) (? !(two? x) 0
                  (x @ ('addr ('var nm)) (pin tak nm 1, 0)
                       ; a register variable keeps its pin, as kprop keeps it
                       ('decl ps) (foldl (_ \ p \ (pin tys <p <>p, (two? >>>p ? (pin tak <p 1) 0), cen >>p)) 0 ps)
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
       (sub env x) (? !(two? x) x (x @ ('var v) (assoc v env @ e (two? e ? <>e x)) (map (sub env) x)))
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
              it1 (sub e1 (it @ ('switch . _) (swp it (nkill (nws (it 1) ()) n0)) it))
              ; a block in the run is entered from above, so it starts with the facts
              it2 (it1 @ ('blk is) ['blk (blk is () n0 ())] (inner it1))
              e2 (it2 @ ('expr . ('asn . ('var v) . rhs . _) . _) (ok? v ? (val v rhs @ k (two? k ? ([v k] . e1) e1)) e1)
                        ('decl ps) (foldl (a \ p \ (two? >>p && ok? <p ? (val <p <>>p @ k (two? k ? ([<p k] . a) a)) a)) e1 ps)
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
                          foldl (_ \ o \ (? (has? <o '(109 111)) (<>o @ ('var nm) (pin tak nm 1) 0)
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
   ; its literal and spells its own locals apart --
   (unrl g f)
    (: w64 !(ilp32? g)
       (size x) (atom? x ? 1 (foldl (a \ y \ a + size y) 0 x))
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
           (<x = 'decl) (map (p \ <p) <>x)
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
                    (? (n < 0 || 16 < n || 512 < n * size b2 || nogo? b2 <t) ['for ini cnd stp b2]
                       (: ds (dnames b2)
                          ['blk (map (i \ copy b2 <t <>t (t 2 + i) ds) ^n)])))
                (map walk x)))
       (abl? g 'unroll ? f (walk f)))
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
           (x @ ('decl ps) ['decl (map (p \ (peep val <p 'no @ k (k = 'no ? p [<p <>p ['num k]]))) ps)]
                (map seat x)))
       (atom? (keys val) ? () (seat f2)))
   ; every __builtin_constant_p decided on what inlining and kprop left: 1 where its operand folds,
   ; else 0; the arms that settles pruned, then propagated again
   (bcpfin g f)
    (: w64 !(ilp32? g)
       (has? x) (? (atom? x) () (<x = 'bcp) 1 (has? <x || has? >x))
       (res x) (? (atom? x) x (<x = 'bcp) ['num (charm? (cfold w64 <>x) ? 1 0)] (map res x))
       (ucut (has? f ? (kprop g (dprune w64 (e \ ()) (res f))) (dprune w64 (e \ ()) f))))
   (cgfn g f)                                       ; ('fn name params ('blk items)) -> forms | 'bad
    ; ..and once more past the prune: an arm it dropped may have been a name's other value
    (: f (bcpfin g (: k0 (kprop g (lprop g (phome g (respell (oalign g (nopcall g (ainl g (nopcall g (lprop g (kcall g (respell f)))))))))))
                      u0 (unrl g k0)
                      k1 (u0 = k0 ? k0 (kprop g u0))
                      (ovfold g k1 @ k2 (two? k2 ? (kprop g k2) k1)))
                @ f1 (kprop g (ucut (dprune !(ilp32? g) (e \ ()) (lprop g f1)))))
       ; the tree passes probe addresses (kprop's, an asm operand's) before every constant has
       ; arrived; a name such a probe could not resolve is no refusal's cause
       _ (pin g 'undecl ())
       params <>>f
       _ (: (has? x) (? (atom? x) () (<x = 'ssp) 1 (any has? x)) (pin g 'sspf (has? (f 3))))   ; a canary keeps its cell
       _ (fnreset g)                                 ; the whole per-fn pin record wiped
       _ (pin g 'rdg (rdgraph >>>f))
       ; v6-M has no fpu: f0/f1/f15 are three frame cells, and soften rewrites every f-op onto them
       _ (v6m? g ? (pins g 'fc0 (ntmp g 'double)
                           'fc1 (ntmp g 'double)
                           'fc15 (ntmp g 'double)))
       ; -- VLA prep: each site takes a pointer slot + a size slot, the size zeroed after the param
       ; spill (the decl lane reads 0 = never allocated) --
       _ (pins g 'fn <>f 'vslots {})
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
       vzf (: (dscan prs a2)
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
       ; the epilogue is per-fn: a vararg t32/rv fn drops its push block on the way out
       _ (pin g 'epi (? (vararg && t32? g) (v6m? g ? epi-t16va epi-t32va)
                        ; an i386 struct return pops its hidden pointer: ret $4 (66 ahead of it in a 16-bit segment)
                        (ia32? g && two? sig && sretm? g <sig && !(srreg? g vararg))
                         ('((ld r3 r4 -8) (mov sp r4) (pop r4)) + [['raw ((g 'tgt = 'i386m16 ? [102] ()) + [194 4 0])]])
                        (vararg && rv64? g) epi-rv-va
                        (v6m? g) epi-t16 (arm? g) epi-a64 epi))
       ; hp is the home policy over the gp params: () spills every one to its slot, ('uni rides homes excl)
       ; seats upar's verdicts; under a policy an exotic composite answers 'bad and ubuild bares
       (pol? h9) (two? h9)                           ; the one policy is the uni seat list
       ; spill, then the by-reference struct params' copies (a64), which may run only once every arg register is home
       (spillp hp ps gpi acc)
        (: _ (pin g 'pcopy ())
           ov0 (ia32? g && charm? (peep g 'sret ()) && !(srreg? g ()) ? 4 0)   ; i386's hidden pointer is the first stack word
           (spill hp ps gpi 0 ov0 () acc @ r (two? r ? [(<r + g 'pcopy) <>r] r)))
       (spill hp ps gpi xmmi ovi env acc)
        (!(two? ps) ? [acc env]
           (: p <ps pty <>p
              ; the even-odd gp pair at gpe spills both words; else the 8-aligned caller stack (gp closes)
              (gpair gpe)
               (gpe + 2 <= ngp g ?
                   (nslot g 8 @ off
                      (spill hp >ps (gpe + 2) xmmi ovi ([<p off pty] . env)
                             (acc + pstw 'r4 off (argr g gpe) (argr g (gpe + 1)))))
                  (aup ovi 8 @ ov8
                     (spill hp >ps 4 xmmi (ov8 + 8) ([<p (ovb g + ov8) pty] . env) acc)))
              (? (ia32? g && flo? pty)                  ; i386: a float or double param is read where the caller laid it
                  (spill hp >ps gpi xmmi (ovi + (pty = 'float ? 4 8)) ([<p (ovb g + ovi) pty] . env) acc)
                 (v6m? g && sse2? g pty)                ; v6-M: a position-0 16B composite arrives whole in r0-r3
                  (gpi != 0 ? 'bad                          ;  (the caller's g4 lane); a later start: deferred
                   (nslot g 16 @ off
                      (spill hp >ps 4 xmmi ovi ([<p off pty] . env)
                       (acc + pstw 'r4 off 'r0 'r1 + pstw 'r4 (off + 8) 'r2 'r3))))
                 (t32core? g pty)                       ; aapcs32's core composite: its words off r0-r3, or the caller's block
                  (: nr ((aup (tsz g pty) 4) // 4) al8 (8 <= asalign g pty)
                     gpe (al8 ? (aup gpi 2) gpi)
                     (? (pol? hp) 'bad
                        (nr <= 4 && gpe + nr <= ngp g)
                         (: off (nslot g 16)
                            (spill hp >ps (gpe + nr) xmmi ovi ([<p off pty] . env)
                                   (acc + catmap (j \ [['st 'r4 (off + 4 * j) (argr g (gpe + j))]]) ^nr)))
                        (gpe < ngp g && ovi = 0)          ; split at r3: the head off the registers, the tail
                         (: nh (ngp g - gpe) nt (nr - nh) ;  off the caller's block through r3, spent by then
                            off (naslot g (aup (4 * nr) 8) 8)
                            (spill hp >ps (ngp g) xmmi (4 * nt) ([<p off pty] . env)
                                   (acc + catmap (j \ [['st 'r4 (off + 4 * j) (argr g (gpe + j))]]) ^nh
                                    + catmap (j \ [['ld 'r3 'r4 (ovb g + 4 * j)] ['st 'r4 (off + 4 * (nh + j)) 'r3]]) ^nt)))
                        (: ov8 (al8 ? (aup ovi 8) ovi)
                           (spill hp >ps (ngp g) xmmi (ov8 + 4 * nr) ([<p (ovb g + ov8) pty] . env) acc))))
                 (t32nolane? g pty) 'bad               ; (the gp lane's word store is a <=4B int one's bytes)
                 ; the AAPCS-VFP seats (t32f): a float HFA aligns to one s-slot and can straddle a d-register,
                 ; so its words come home one at a time; a float's slot holds the binary32 word (fldf 'float reads it)
                 (t32f? g && stru? pty && hfab g pty = 'float)
                  (: n (tsz g pty // 4)
                     k (vfpn xmmi n 1)
                     (k < 0 ? (nolane g "no lane for a float HFA param past the register file\(ontgt g)")
                        (: off (nslot g (tsz g pty <= 8 ? 8 16))
                           (spill hp >ps gpi (vfpm xmmi k n) ovi ([<p off pty] . env)
                                  (acc + catmap (i \ vfpsv (k + i) 'r4 (off + 4 * i)) ^n)))))
                 (t32f? g && sse2? g pty)                  ; a two-double HFA: an adjacent d-pair
                  (vfpn xmmi 4 2 @ k
                     (k < 0 ? (nolane g "no lane for an HFA param past the register file\(ontgt g)")
                        (: off (nslot g 16) d (k // 2)
                           (spill hp >ps gpi (vfpm xmmi k 4) ovi ([<p off pty] . env)
                                  (acc + fstf g 'double 'r4 off (xmmreg d)
                                       + fstf g 'double 'r4 (off + 8) (xmmreg (d + 1)))))))
                 (t32f? g && pty = 'float)               ; a bare float: one slot, else the caller's 4-byte word
                  (0 <= vfpn xmmi 1 1 ?
                     (: k (vfpn xmmi 1 1) off (nslot g 8)
                        (spill hp >ps gpi (vfpm xmmi k 1) ovi ([<p off pty] . env)
                               (acc + vfpsv k 'r4 off)))
                     (spill hp >ps gpi vfpx (ovi + 4) ([<p (ovb g + ovi) pty] . env) acc))
                 (t32f? g && (flo? pty || stru? pty && aone g pty = 'sse))   ; a double, or a one-double HFA
                  (0 <= vfpn xmmi 2 2 ?
                     (: k (vfpn xmmi 2 2) off (nslot g 8)
                        (spill hp >ps gpi (vfpm xmmi k 2) ovi ([<p off pty] . env)
                               (acc + fstf g 'double 'r4 off (xmmreg (k // 2)))))
                     (aup ovi 8 @ ov8
                        (spill hp >ps gpi vfpx (ov8 + 8) ([<p (ovb g + ov8) pty] . env) acc)))
                 (a64hfa g pty)                         ; an a64 float HFA: its members off s registers k.., else the caller's block
                  (: n (a64hfa g pty)
                     (xmmi + n <= 8 ?
                        (: off (nslot g 16)
                           (spill hp >ps gpi (xmmi + n) ovi ([<p off pty] . env)
                                  (acc + catmap (j \ [['stss 'r4 (off + 4 * j) (xmmreg (xmmi + j))]]) ^n)))
                        (spill hp >ps gpi 8 (ovi + (aup (4 * n) 8) // 8) ([<p (ovb g + 8 * ovi) pty] . env) acc)))
                 (v6m? g && stru? pty && aone g pty == 'sse)           ; v6-M 8B blob param: the even-odd gp pair (the caller's g2 lane)
                  (gpair (aup gpi 2))
                 (stru? pty && two? (aeb2 g pty))       ; a 9..16B struct param: two eightbytes into a 16-byte slot, each off a gp or an xmm reg
                  (pol? hp && !(sse2? g pty) ? 'bad        ; a policy homes gp scalars only -- mixed/int-pair 16B deopts
                     (: cls (aeb2 g pty) c0 <cls c1 <>cls
                        ; the file per eightbyte, 'g gp / 'x xmm: SysV by class, AAPCS64 wholly in X unless an all-float HFA
                        hfa (c0 = 'sse && c1 = 'sse)
                        f0 (a64? g ? (hfa ? 'x 'g) (c0 @ 'sse 'x 'g))
                        f1 (a64? g ? (hfa ? 'x 'g) (c1 @ 'sse 'x 'g))
                        gpn ((f0 = 'g) + (f1 = 'g))
                        xmn ((f0 = 'x) + (f1 = 'x))
                        (ngp g < gpi + gpn || 8 < xmmi + xmn ?     ; short of regs: the whole aggregate goes to memory
                            (? (pol? hp) 'bad           ; under a policy: deopt, not a fresh memory lane
                               (t32? g)                 ; t32 stack HFA params (9+ doubles): deferred
                                (nolane g "no lane for an HFA param past the register file\(ontgt g)")
                               (spill hp >ps gpi xmmi (ovi + 2) ([<p (ovb g + 8 * ovi) pty] . env) acc))
                            (: off (nslot g 16)
                               st0 (f0 @ 'g [['st 'r4 off (argr g gpi)]] (fstf g 'double 'r4 off (xmmreg xmmi)))
                               gp1 (f0 @ 'g (gpi + 1) gpi)
                               xm1 (f0 @ 'x (xmmi + 1) xmmi)
                               st1 (f1 @ 'g [['st 'r4 (off + 8) (argr g gp1)]] (fstf g 'double 'r4 (off + 8) (xmmreg xm1)))
                               gp2 (f1 @ 'g (gp1 + 1) gp1)
                               xm2 (f1 @ 'x (xm1 + 1) xm1)
                               (spill hp >ps gp2 xm2 ovi ([<p off pty] . env) (acc + st0 + st1))))))
                 (stru? pty && aone g pty == 'sse)       ; a small SSE aggregate: one xmm into an 8-byte slot
                  (xmmi < 8 ?
                     (nslot g 8 @ off
                        (spill hp >ps gpi (xmmi + 1) ovi ([<p off pty] . env)
                               (acc + fstf g 'double 'r4 off (xmmreg xmmi))))
                     (t32? g ?                        ; t32 stack blob params: deferred
                         (nolane g "no lane for a stack-passed by-value struct param\(ontgt g)")
                        (spill hp >ps gpi xmmi (ovi + 1) ([<p (ovb g + 8 * ovi) pty] . env) acc)))
                 ; an a64 memory-class param arrives as the address of the caller's copy: it saves like a pointer, and
                 ; the struct copies into this frame once every arg register is home (spillp: bcopy runs through r0-r2)
                 (refm? g pty)
                  (? (pol? hp) 'bad
                     (: off (ntmp g pty)
                        reg (gpi < ngp g)
                        src (reg ? (nslot g 8) (ovb g + 8 * ovi))
                        _ (pin g 'pcopy (g 'pcopy + [['ld 'r0 'r4 src] ['lea 'r1 'r4 off]] + bcopy g 0 (tsz g pty) ()))
                        (reg ? (spill hp >ps (gpi + 1) xmmi ovi ([<p off pty] . env) (acc + [['st 'r4 src (argr g gpi)]]))
                           (spill hp >ps gpi xmmi (ovi + 1) ([<p off pty] . env) acc))))
                 ; an i386 struct in registers (-mregparm): its words into a slot of its own
                 (ia32? g && stru? pty && !(gcplx? pty) && 0 < tsz g pty && gpi + ((aup (tsz g pty) 4) // 4) <= ngp g)
                  (: nw ((aup (tsz g pty) 4) // 4) off (nslot g 16)
                     (spill hp >ps (gpi + nw) xmmi ovi ([<p off pty] . env)
                            (acc + catmap (j \ [['st 'r4 (off + 4 * j) (argr g (gpi + j))]]) ^nw)))
                 ; a memory-class param binds straight to the caller's overflow block (SysV: that memory is the callee's copy)
                 (ia32? g && stru? pty)
                  (spill hp >ps (gcplx? pty ? gpi (ngp g)) xmmi (ovi + aup (tsz g pty) 4) ([<p (ovb g + ovi) pty] . env) acc)
                 (amem? g pty)
                  (pol? hp || 8 < asalign g pty ? 'bad     ; under a policy, or over-aligned: deopt/refuse
                     (spill hp >ps gpi xmmi (ovi + aslots g pty)
                            ([<p (ovb g + 8 * ovi) pty] . env) acc))
                 (stru? pty && aone g pty !== 'int)        ; mixed pair stays ahead; a small int one rides the gp lane
                  (nolane g "no lane for passing this \(tsz g pty)-byte struct by value\(ontgt g)")
                 (v6m? g && pty == 'float)             ; v6-M base ABI: a bare float param is one word
                  (gpi < ngp g ?                      ;  binary32 bits in a gp reg or a 4-byte caller slot;
                     (nslot g 8 @ off ;  fldf 'float widens it on read
                        (spill hp >ps (gpi + 1) xmmi ovi ([<p off pty] . env)
                               (acc + [['st 'r4 off (argr g gpi)]])))
                     (spill hp >ps gpi xmmi (ovi + 4) ([<p (ovb g + ovi) pty] . env) acc))
                 (v6m? g && flo? pty)                   ; v6-M base ABI: a double param is a gp pair (no FPU regs exist)
                  (gpair (aup gpi 2))
                 ; a double (a float arriving binary32) granted an xmm seat rides there off its arrival; the rest take a slot
                 (fphome? g pty && xmmi < 8 && nom? (peep (g 'fpar) <p ()))
                  (peep (g 'fpar) <p () @ fr
                     (spill hp >ps gpi (xmmi + 1) ovi ([<p ['reg fr] pty] . env)
                            (acc + [['movapd fr (xmmreg xmmi)]])))
                 (f32abi? g && pty = 'float && xmmi < 8)   ; a float arrives binary32: stored as is, fldf widens it
                  (nslot g 8 @ off
                     (spill hp >ps gpi (xmmi + 1) ovi ([<p off pty] . env)
                            (acc + [['stss 'r4 off (xmmreg xmmi)]])))
                 (flo? pty && xmmi < 8)
                  (nslot g 8 @ off
                     (spill hp >ps gpi (xmmi + 1) ovi ([<p off pty] . env)
                            (acc + fstf g pty 'r4 off (xmmreg xmmi))))
                 (pair? g pty && ia32? g && gpi + 2 <= ngp g)   ; i386 -mregparm: two registers, when two are left
                  (nslot g 8 @ off
                     (spill hp >ps (gpi + 2) xmmi ovi ([<p off pty] . env)
                            (acc + pstw 'r4 off (argr g gpi) (argr g (gpi + 1)))))
                 (pair? g pty && ia32? g)              ; i386: the pair's two words where the caller laid them, the rest spent
                  (spill hp >ps (ngp g) xmmi (ovi + 8) ([<p (ovb g + ovi) pty] . env) acc)
                 (pair? g pty) (gpair (aup gpi 2))   ; a pair param: the even-odd register pair
                 ; a wide param as the argument lane lays it: lo then hi into a 16-byte slot, or read in the
                 ; caller's block (homefold plans it no home)
                 (d128? pty && t32w? g)
                  (? (gpi = 0)
                      (nslot g 16 @ off
                         (spill hp >ps 4 xmmi ovi ([<p off pty] . env)
                                (acc + catmap (k \ [['st 'r4 (off + 4 * k) (argr g k)]]) ^4)))
                     (aup ovi 8 @ ov8
                        (spill hp >ps 4 xmmi (ov8 + 16) ([<p (ovb g + ov8) pty] . env) acc)))
                 (d128? pty && w128? g)
                  (: gpe (a64? g ? (aup gpi 2) gpi)
                     (? (gpe + 2 <= ngp g)
                         (nslot g 16 @ off
                            (spill hp >ps (gpe + 2) xmmi ovi ([<p off pty] . env)
                                   (acc + [['st 'r4 off (argr g gpe)] ['st 'r4 (off + 8) (argr g (gpe + 1))]])))
                        (a64? g)
                         (aup ovi 2 @ ov2
                            (spill hp >ps (ngp g) xmmi (ov2 + 2) ([<p (ovb g + 8 * ov2) pty] . env) acc))
                        (nolane g "a wide value past the argument registers is not carried as a parameter")))
                 (d128? pty) (no128 g)
                 (!(flo? pty) && gpi < ngp g)
                  (two? hp && gpi < nhome g &&
                   (elem gpi <>hp || elem gpi (hp 2)) ?
                      ; a rider keeps its arrival, a positional home pays one mov; every home wears the
                      ; armed shadow -- its slot is reserved but untouched until a call really emits
                      (: inc (argr g gpi)
                         home (elem gpi <>hp ? inc (homereg gpi))
                         mv (pin g 'homes ([home (nslot g 8) <p] . g 'homes),
                             (home != inc ? [['mov home inc]]) + cvt pty home)
                         (spill hp >ps (gpi + 1) xmmi ovi ([<p ['reg home] pty] . env)
                                (acc + mv)))
                     (: off (nslot g 8)
                        ; a bool param converts its arrival (cc calls untyped: the caller passed the bare int)
                        cv9 (pty @ 'bool (cvt pty (argr g gpi)))
                        (spill hp >ps (gpi + 1) xmmi ovi ([<p off pty] . env)
                         (acc + cv9 + [['st 'r4 off (argr g gpi)]]))))
                 ; an overflow param reads off the caller's block: 8-byte slots (x64/a64), 4-byte on t32
                 (ilp32? g) (spill hp >ps gpi xmmi (ovi + 4) ([<p (ovb g + ovi) pty] . env) acc)
                 (spill hp >ps gpi xmmi (ovi + 1) ([<p (ovb g + 8 * ovi) pty] . env) acc))))
       ; a variadic fn (SysV): a 176-byte save area, gp at +0 step 8, xmm at +48 step 16, saved but under
       ; -mno-sse; a pair touching xmm copies into its own slot (its eightbytes sit 8 apart)
       (vaspill ps)
        (: rsa (nslot g 176)
           _ (pin g 'rsa rsa)
           savegp (: (go i acc) (5 < i ? acc (go (i + 1) (acc + [['st 'r4 (rsa + 8 * i) (argregs i)]]))) (go 0 ()))
           savex  (nofp? g ? () (: (go i acc) (7 < i ? acc (go (i + 1) (acc + [['stsd 'r4 (rsa + 48 + 16 * i) (xmmreg i)]]))) (go 0 ())))
           (cls qs gpi xmmi ov env acc)
            (!(two? qs) ? (pins g 'vagp gpi 'vaxmm xmmi, [(savegp + savex + acc) env])
               (: p <qs pty <>p
                  eb2 (aeb2 g pty)
                  ovf (u \ cls >qs gpi xmmi
                       (ov + 8 * (stru? pty ? (aslots g pty) 1))
                       ([<p (ovb g + ov) pty] . env)
                       acc)
                (? (amem? g pty) (8 < asalign g pty ? 'bad (ovf ()))
                   (d128? pty) (nolane g "a wide param is not carried in a variadic function")
                   eb2 (: f0 (<eb2 @ 'sse 'x 'g) f1 (<>eb2 @ 'sse 'x 'g)
                          gpn ((f0 = 'g) + (f1 = 'g))
                          xmn ((f0 = 'x) + (f1 = 'x))
                        (? (6 < gpi + gpn || 8 < xmmi + xmn) (ovf ())   ; short of registers: the whole aggregate to memory
                           (2 = gpn) (cls >qs (gpi + 2) xmmi ov ([<p (rsa + 8 * gpi) pty] . env) acc)
                           (: off (nslot g 16)
                              st0 (f0 @ 'g [['st 'r4 off (argregs gpi)]] (fstf g 'double 'r4 off (xmmreg xmmi)))
                              gp1 (f0 @ 'g (gpi + 1) gpi)
                              xm1 (f0 @ 'x (xmmi + 1) xmmi)
                              st1 (f1 @ 'g [['st 'r4 (off + 8) (argregs gp1)]] (fstf g 'double 'r4 (off + 8) (xmmreg xm1)))
                            (cls >qs (gpi + gpn) (xmmi + xmn) ov ([<p off pty] . env) (acc + st0 + st1)))))
                   (flo? pty || aone g pty == 'sse)
                    (7 < xmmi ? (ovf ())
                     (cls >qs gpi (xmmi + 1) ov ([<p (rsa + 48 + 16 * xmmi) pty] . env) acc))
                   (5 < gpi) (ovf ())
                   (cls >qs (gpi + 1) xmmi ov ([<p (rsa + 8 * gpi) pty] . env) acc))))
           (cls ps 0 0 0 () ()))
       ; a variadic fn (AAPCS64): a 192-byte save area, x0..x7 at +0 step 8, q0..q7 at +64 step 16 (the low 8 bytes the double)
       (vaspill-a64 ps)
        (: rsa (nslot g 192)
           _ (pins g 'rsa rsa 'pcopy ())
           savegp (: (go i acc) (7 < i ? acc (go (i + 1) (acc + [['st 'r4 (rsa + 8 * i) (argregs-a64 i)]]))) (go 0 ()))
           ; -mgeneral-regs-only: no q register is touched, the vr half stays empty (a kernel traps on one)
           savevr (: (go i acc) (7 < i ? acc (go (i + 1) (acc + fstf g 'double 'r4 (rsa + 64 + 16 * i) (xmmreg i)))) (nofp? g ? () (go 0 ())))
           (cls qs gpi vri ov env)
            (!(two? qs) ? (pins g 'vagp gpi 'vaxmm vri 'vaov ov, [(savegp + savevr + g 'pcopy) env])
               (: p <qs pty <>p
                  (? (flo? pty)
                      (7 < vri ? (cls >qs gpi vri (ov + 1) ([<p (ovb g + 8 * ov) pty] . env))
                                 (cls >qs gpi (vri + 1) ov ([<p (rsa + 64 + 16 * vri) pty] . env)))
                     ; a by-reference struct: its pointer's slot, copied into the frame after the saves
                     (refm? g pty)
                      (: off (ntmp g pty) src (7 < gpi ? (ovb g + 8 * ov) (rsa + 8 * gpi))
                         _ (pin g 'pcopy (g 'pcopy + [['ld 'r0 'r4 src] ['lea 'r1 'r4 off]] + bcopy g 0 (tsz g pty) ()))
                         (7 < gpi ? (cls >qs gpi vri (ov + 1) ([<p off pty] . env))
                            (cls >qs (gpi + 1) vri ov ([<p off pty] . env))))
                     ; a gp struct takes its slots whole, as the caller's p2 lane lays them; an HFA, or one past the file, refuses there too
                     (stru? pty)
                      (aslots g pty @ n
                         (hfab g pty @ b (flo? b) || 8 < gpi + n ?
                            (nolane g "no lane for this by-value struct param in a variadic function\(ontgt g)")
                            (cls >qs (gpi + n) vri ov ([<p (rsa + 8 * gpi) pty] . env))))
                     (7 < gpi) (cls >qs gpi vri (ov + 1) ([<p (ovb g + 8 * ov) pty] . env))
                     (cls >qs (gpi + 1) vri ov ([<p (rsa + 8 * gpi) pty] . env)))))
           (cls ps 0 0 0 ()))
       ; a variadic fn (AAPCS32): the prologue pushed r0-r3 just under the caller's stack args, so a
       ; named register param sits at fp+ovb+4i and an overflow one past it. the base pcs: a double
       ; or a pair from an even register or the 8-aligned stack, a composite its words likewise, and
       ; the gp file closes behind whatever goes to the stack
       (vaspill-t32 ps)
        (: (cls qs gpi ov env)
            (!(two? qs) ? (pins g 'vagp gpi 'vaov ov, [() env])
               (: p <qs pty <>p
                  nw (? (stru? pty) ((aup (tsz g pty) 4) // 4) (pty != 'float && flo? pty || llt? pty) 2 1)
                  al8 (? (stru? pty) (8 <= asalign g pty) (nw = 2))
                  gpe (al8 ? (aup gpi 2) gpi)
                  (? (stru? pty && (v6m? g || !(0 < tsz g pty)))
                      (nolane g "no lane for a by-value struct param in a variadic function\(ontgt g)")
                     (gpe + nw <= 4) (cls >qs (gpe + nw) ov ([<p (ovb g + 4 * gpe) pty] . env))
                     (gpe < 4 && ov = 0)             ; a composite split at r3 lies whole across the push and the block
                      (cls >qs 4 (4 * (gpe + nw - 4)) ([<p (ovb g + 4 * gpe) pty] . env))
                     (: o8 (al8 ? (aup ov 8) ov)
                        (cls >qs 4 (o8 + 4 * nw) ([<p (ovb g + 16 + o8) pty] . env))))))
           (cls ps 0 0 ()))
       ; a variadic fn (i386): every named param is a stack word already; va_start starts past their bytes
       (vaspill-ia32 ps)
        (: (cls qs ov env)
            (!(two? qs) ? (pins g 'vagp 0 'vaov ov, [() env])
               (: p <qs pty <>p
                  n (? (llt? pty || pty = 'double) 8 (stru? pty) (aup (tsz g pty) 4) 4)
                  (cls >qs (ov + n) ([<p (ovb g + ov) pty] . env))))
           (cls ps 0 ()))
       ; a variadic fn (riscv): a0..a7 lie in a 64-byte block above the push cells, so a named register param
       ; sits at fp+ovb+8i and an overflow one past it (+64); a named double rides the gp lane too (the caller's va? classifier)
       (vaspill-rv ps)
        (: (cls qs gpi ov env)
            (!(two? qs) ? (pins g 'vagp gpi 'vaov ov, [() env])
               (: p <qs pty <>p
                  (? (stru? pty) (nolane g "no lane for a by-value struct param in a variadic function\(ontgt g)")
                     (7 < gpi) (cls >qs gpi (ov + 1) ([<p (ovb g + 64 + 8 * ov) pty] . env))
                     (cls >qs (gpi + 1) ov ([<p (ovb g + 8 * gpi) pty] . env)))))
           (cls ps 0 0 ()))
       ; -- register-homed params: the home pool (hregs g, by gp position) is disjoint from scratch and the
       ; arg registers; every home also takes a frame slot in g 'homes, which call-fixed spills around a call --
       (homereg gpi) (hregs g gpi)
       (build sp0)                                  ; assemble prologue + body + epilogue for a spill result
        (bad? sp0 ? 'bad
           (: body (bldreset g,
                    ; the assignment runs before the frame is sized, over the fn's own label, the body
                    ; and the tail (no prologue form names a register it watches); vrfix only substitutes
                    cgitems g <>sp0 <><>>>f () @ b9
                     (bad? b9 ? b9
                        (vpre g ([['label (name <>f)]] + <sp0) b9
                              ('((li r0 0)) + (arm? g ? (peep g 'epi epi-a64) (peep g 'epi epi))))))
              (bad? body ? 'bad
                 ; i386 enters with esp 12 past a 16 boundary and pushes ebp: 8 more keeps every call aligned
                 (aup (peep g 'off 0) 16 + (ia32? g ? 8 0) @ frame
                    (arm? g ?
                       ; the IR sweeps stay out of the arm build (a64 sweeps post-choice, where r4 is unambiguously fp:
                       ; a raw r4 is also the 5th argument); a4ize retargets r4 -> fp after sibcall. no sav3: r3 is caller-saved
                       ((? (v6m? g) (ir \ t16la (t16slots ir frame))   ; v6m: fp-neg slots -> r4-positive (after a4ize), then la -> literal pool
                           (sp64? g) (ir \ t16la ir)       ; playdate: la -> pooled abs32 word (its loader can't relocate MOVW/MOVT)
                           (rv64? g) (ir \ rvslots ir frame)  ; riscv: fp-neg slots -> fp-positive, for the C forms
                           1)
                        (a4ize
                         (sibcall g
                          (soften g
                          (vrfix g
                          ((v6m? g ?   ; v6m: extra push r4 (bottom base), planted after the sub; fp stays at top
                              ([['label (name <>f)]] +
                               (vararg ?   ; vararg v6m: r0-r3 above lr/fp/r4, contiguous with the caller's stack args
                                '((push r3) (push r2) (push r1) (push r0))) +
                               ['(push lr) '(push fp) '(push r4)
                                  '(lea fp sp 0) ['sub 'sp 'sp frame] '(lea r4 sp 0)])
                              ([['label (name <>f)]] +
                               (? (vararg && t32? g)     ; vararg t32: r0-r3 under fp/lr, likewise
                                  '((push r3) (push r2) (push r1) (push r0))
                                  (vararg && rv64? g)      ; vararg riscv: a0-a7 in a packed 64-byte block
                                  ['(sub sp sp 64)
                                     '(st sp 0 r0) '(st sp 8 r1) '(st sp 16 r2) '(st sp 24 r3)
                                     '(st sp 32 r4) '(st sp 40 r5) '(st sp 48 r6) '(st sp 56 r7)]
                                  ()) +
                               (rv64? g ?     ; riscv links last, so fp lands at the frame bottom
                                  ['(push lr) '(push fp) ['sub 'sp 'sp frame] '(lea fp sp 0)]
                                  (pro-a64 + [['sub 'sp 'sp frame]])))) +
                           ; the cs saves ride after the frame is up (fp-relative), past unframe's positional prologue read
                           g 'cssv +
                           <sp0 + body + fz0 g <>f + peep g 'epi epi-a64))))))
                       (dp 'sweeps (deadst g
                        (deaddef g      ; rerun: the widened addrfold strands live-dest addr insns
                        (cmpfuse g
                        (copyprop g                 ; memfw's movs fold before cmpfuse reads the pair
                        (memfw g                    ; after addrfold: an address is a base and an offset
                        (addk g                     ; again: addrfold's constant-index lea meets its add
                        (addrfold g
                        (addk g
                        (rezx g         ; after stld: the forward mints zx, this drops the redundant
                        (copyprop g
                        (stld g
                        (spmerge
                        (deaddef g
                        (deadcell g
                        (cfoldir g (dp 'built
                         (sibcall g
                          (qcell g (vrfix g
                          ([['label (name <>f)]] + pro4 + [['sub 'sp 'sp frame] sav3] +
                           g 'cssv + <sp0 +
                           body + fz0 g <>f + peep g 'epi epi))))))))))))))))))))))))))
       ; an r4 arrival (a64's 5th gp) is never ridden: gen spells the frame base r4 and a4ize retargets
       ; it to fp by position, so a ridden r4 in a base slot would turn into fp
       (a4rider? A) (fbase g !== 'r4 && A == 'r4)
       ; -- the AST-side allocator, fed by alive: raw mention counts rank, loop weight breaks ties, spans
       ; share seats. a name crossing a hard call never takes a caller-saved seat; a soft crossing rides the armed shadow --
       (ulloc av9 hp9 bl9)
        (: uv <>>av9 spa9 (av9 5) crs9 <>av9
           crh9 (av9 6) rdc9 (av9 7) rdt9 (av9 8) sqm9 (av9 9)
           tak9 (av9 14)
           lf9 (av9 15 <= 2)                  ; leaf-shaped: at most two cold hard crossings fn-wide (a loop crossing weighs 8+)
           ; the AST ret count, floored at 1
           nx9 (osz? g || !(0 < av9 10) ? 1 (av9 10))   ; -Os: the exits share one epilogue (rjoin)
           nsq (av9 13)
           navl (? (3 < #hp9) (#hp9 - 2) (1 < #hp9) 1 0)   ; the file already lost the param homes: keep one grantable seat while two remain
           (firstn l n) (atom? l || n < 1 ? () (<l . firstn >l (n - 1)))
           ; arrival registers rank last: a seat there evicts what the sweeps still forward from it
           arr9 (map (i \ (argr g i)) (jot (#params < ngp g ? #params (ngp g))))
           hp8 (filter (q \ (nelem q arr9)) hp9 + filter (q \ (elem q arr9)) hp9)
           pfile (firstn hp8 navl)
           kp (cspool g)
           ; touch counts key by name, so a shadowed name's sites conflate: average them out
           sitec (: t {}
                    (go2 i) (nsq < i ? t
                               (sqm9 i @ e2
                                  (two? e2 ? (pin t <e2 (1 + peep t <e2 0)) 0,
                                   go2 (i + 1))))
                    (go2 1))
           cands (: (go i acc)
                    (nsq < i ? acc
                       (sqm9 i @ e2
                          (!(two? e2) ? (go (i + 1) acc)
                             (: nm <e2 ty <>e2
                                u9 (elem nm uv)
                                ; an &-taken name stays a cell, and every name in a fn a call returns twice
                                ; into: the second return restores no register, and a volatile looks like any local
                                (tak9 nm || g 'twice ? (go (i + 1) acc)
                                   (: ns9 (peep sitec nm 1)
                                      tc (peep rdc9 nm 0 @ n (1 < ns9 ? (n // ns9) n))
                                      d1 (d128? ty)
                                      fl (fhomable? ty)
                                      ; a shadowed name (!u9) takes no pool seat and no span; a leaf-shaped fn
                                      ; pool-homes by rank alone, a hard-calling one only a zero-crossing name
                                      pok (? (d1 || fl || !u9) ()
                                             lf9 (2 <= tc)
                                             (peep crs9 nm 0 = 0 && 2 <= tc))
                                      ; a cs seat pays its save and a reload per exit -- except on wasm, where it has none
                                      cok (!fl && (wasm? g ? (2 <= tc) (2 < tc && 1 + nx9 < tc)))
                                      ; a double or float: the files it may take, in order. a zero-crossing name takes the free file
                                      ; first, a crossing one the cs file (priced as cok) then, a double only, a wrapped seat when its
                                      ; weighted mentions outweigh the spill and reload
                                      fok (: c9 (peep crs9 nm 0)
                                             fc (two? (fcspool g) && 2 < tc && 1 + nx9 < tc ? (fcspool g))
                                             fw (c9 = 0 || ty = 'double && fwrap? g && 2 * c9 < peep rdt9 nm 0 ? (ffile g))
                                             (fl && u9 && 2 <= tc ? (c9 = 0 ? (fw + fc) (fc + fw))))
                                      (!(pok || cok || fok) ? (go (i + 1) acc)
                                         (go (i + 1) ([tc (1 < ns9 ? (peep rdt9 nm 0 // ns9)
                                                             (peep rdt9 nm 0)) i
                                                       (u9 ? (spa9 nm))
                                                       (d1 ? 2 1) pok cok fok] . acc)))))))))
                    ; the blockers: a hot hard-crossing param competes by rank, and a seat it wins stays
                    ; unwritten for repack's chain lane downstream
                    (: (bgo l k acc)
                        (!(two? l) ? acc
                           (bgo >l (k - 1) ([<<l <><l k () 1 () 'b ()] . acc)))
                       (bgo bl9 -1 (go 1 ()))))
           byw (sortby (a \ b \ (? (<b < <a) 1 (<a < <b) ()
                                    (a 4 < b 4) 1 (b 4 < a 4) ()
                                    (<>b < <>a) 1 (<>a < <>b) ()
                                    (<>>a < <>>b)))
                       cands)
           occ {}                             ; seat -> its occupants' spans, 'x exclusive
           (fits? r sp)
            (occ r @ o
               (? (o = 'x) ()
                  !(two? o) 1
                  !(two? sp) ()
                  (: (dj l) (!(two? l) ? 1
                               (<l @ s9 (<>s9 < <sp || <>sp < <s9 ? (dj >l) ())))
                     (dj o))))
           (claim r sp) (pin occ r (!(two? sp) ? 'x
                                      (occ r @ o (two? o ? (sp . o) [sp]))))
           (seat1 file sp) (? !(two? file) ()
                              (fits? <file sp) <file
                              (seat1 >file sp))
           (seat2 file sp)
            (seat1 file sp @ r1
               (!r1 ? ()
                  (seat1 (filter (q \ (q != r1)) file) sp @ r2
                     (r2 ? [r1 r2]))))
           lh {} pw {} cw {}
           _ (foldl
              (_ \ c \
                (: sq (c 2) sp (c 3) w2 (c 4) pok (c 5) cok (c 6) fok (c 7)
                   r (pok ? (seat1 pfile sp))
                   (? r (claim r sp, pin pw r 1, pin lh sq r)
                      fok (seat1 fok sp @ r2
                             (r2 && (claim r2 sp, (elem r2 (fcspool g) ? (pin cw r2 1)), pin lh sq r2)))
                      !cok 0
                      (w2 = 2)
                       (seat2 kp sp @ p2
                          (!(two? p2) ? 0
                             (claim <p2 sp, claim <>p2 sp,
                              pin cw <p2 1, pin cw <>p2 1,
                              pin lh sq p2)))
                      (cok = 'b)
                       (seat1 kp sp @ r2 (r2 && claim r2 sp)) ; a blocker claims; nothing is written
                      (seat1 kp sp @ r2
                       (r2 && (claim r2 sp, pin cw r2 1, pin lh sq r2))))))
              0 byw)
           pused (filter (q \ peep pw q 0) hp9)
           cu0 (filter (q \ peep cw q 0) (kp + fcspool g))
           ; MOON_DUMP=<fn> also shows the seating: the ranked candidates (tc wt sq span w pok cok fok), the files, the map
           ((getenv "MOON_DUMP" @ w
               (string? w && w = <>f ?
                  (puts ";; ulloc pfile=\(show pfile) kp=\(show kp) nx=\(show nx9) lf=\(show lf9)\n",
                   (map (c \ (puts "  \(show <(sqm9 (c 2))) ", putx c, putc 10)) byw),
                   (: (go i) (nsq < i ? 0
                                (sqm9 i @ e2
                                   (two? e2 ? (puts "  decl \(show <e2) u=\(show (elem <e2 uv)) tak=\(show (tak9 <e2)) tc=\(show (peep rdc9 <e2 0)) crs=\(show (peep crs9 <e2 0))\n", 0) 0,
                                    go (i + 1))))
                      (go 1)),
                   puts ";; lh ", putx (map (k \ [k (lh k)]) (sort (keys lh))), putc 10)
                  0)),
            [lh (filter (q \ (nelem q pused)) hp9) cu0]))
       ; the loop-region splitter. inside a loop, a register whose seated names the loop never mentions is
       ; free: a name live through it parks in its slot at entry and comes back at exit, and the cells the
       ; loop mentions most take it over the loop's ticks, priced by weighted mentions against the transfers.
       ; a calling loop takes only callee-saved seats (no call wrap meets a split); a body with a jump or asm
       ; takes none, nor a loop holding a statement expression (its locals sit outside the ticks).
       ; -> [ov splits cu]: name -> ([lo hi reg]..), tick -> [evs prs]
       (usplit av9 lh9 cu0 items)
        (: sqm9 (av9 9) uv <>>av9 tak9 (av9 14) spa9 (av9 5)
           kp (cspool g)
           ; every name a subtree mentions or declares, weighted x8 per loop it sits in
           (mn9 e w t) (? (atom? e) t
                          (<e == 'var) (pin t <>e (w + peep t <>e 0))
                          (<e == 'decl) (foldl (t2 \ p \ (two? p ? (pin t2 <p (w + peep t2 <p 0), mn9 >p w t2) t2)) t <>e)
                          (: w2 (elem <e '(while do for) ? (w * 8) w)
                             (foldl (t2 \ x \ mn9 x w2 t2) t e)))
           (has9 ks e) (? (atom? e) () (elem <e ks) 1 (any (x \ has9 ks x) e))
           ; a local's name -> its type, and -> its gp seat; every seat's register -> its names
           nty (: (go i t) (sqm9 i @ e2 (? (atom? e2) t (go (i + 1) (pin t <e2 <>e2)))) (go 1 {}))
           ; ..and its decl's place: the tie-break, never the spelling (an inlined body's names are
           ; numbered per run, and generations that number them apart must choose alike)
           nsq (: (go i t) (sqm9 i @ e2 (? (atom? e2) t (go (i + 1) (peep t <e2 () ? t (pin t <e2 i))))) (go 1 {}))
           seat (foldl (t \ k \ (: r (lh9 k) e2 (sqm9 k)
                                  (two? e2 && r ? (pin t <e2 r) t))) {} (keys lh9))
           held (foldl (t \ k \ (: r (lh9 k) (? (two? r) (foldl (t2 \ x \ pin t2 x 1) t r) (nom? r) (pin t r 1) t))) {} (keys lh9))
           ; per seat, every name on it (a twice-declared name too: it pins its register, never evicts)
           occ (foldl (t \ k \ (: r (lh9 k) e2 (sqm9 k)
                                  (two? e2 && nom? r && lhomable? <>e2 ? (pin t r (<e2 . peep t r ())) t))) {} (sort (keys lh9)))
           ; a fresh callee-saved seat's save is paid on every call of the fn, and the loop may be its
           ; coldest part: only a loop whose mentions weigh 64 at the fn's entry may take one
           cs0 (filter (r \ !(peep held r ()) && nelem r cu0) kp)
           (ovl? a b lo hi) !(hi < a || b < lo)
           (busy? t k a b) (any (x \ ovl? a b <x <>x) (peep t k ()))
           rs9 {} ns9 {} ov9 {} sp9 {} cu9 {'cu cu0}
           (one L)
            (: a <L b <>L lin (L 3) lout (L 4) s9 (L 5)
               ms (mn9 s9 1 {})
               calls (has9 '(call) s9)
               (in9 nm) (elem nm lin ? 1 0) (out9 nm) (elem nm lout ? 1 0)
               ; the names seated on r live across these ticks: () when one is mentioned here
               (idle r) (: ns (filter (nm \ (spa9 nm @ sp (two? sp && ovl? a b <sp <>sp))) (peep occ r ()))
                           (any (nm \ 0 < peep ms nm 0 || nelem nm uv) ns ? 'no ns))
               (cost r) (? (elem r cs0) (elem r (cu9 'cu) ? 0 2)
                           (foldl (c \ nm \ c + in9 nm + out9 nm) 0 (idle r)))
               (ok? m r) (!(busy? rs9 r a b) && (!calls || elem r kp) &&
                          (elem r cs0 ? (64 <= (L 2) * peep ms m 0) (idle r != 'no)))
               cands (sortby (x \ y \ (? (peep ms y 0 < peep ms x 0) 1 (peep ms x 0 < peep ms y 0) () (nsq x < nsq y)))
                        (filter (nm \ elem nm uv && !(tak9 nm) && !(peep seat nm ()) &&
                                      lhomable? (nty nm) && !(busy? ns9 nm a b))
                                (sort (keys ms))))
               (take9 m)
                (: rs (sortby (x \ y \ cost x < cost y) (filter (r \ ok? m r) (sort (keys occ) + cs0)))
                   (two? rs &&
                    (: r <rs c (cost r + in9 m + out9 m)
                       ; priced at one trip per entry: the mentions an iteration saves pay the transfers
                       (8 * c + 8 <= peep ms m 0 &&
                        (: evs (elem r cs0 ? () (filter (nm \ 0 < in9 nm + out9 nm) (idle r)))
                           o (peep sp9 a [() ()])
                           (pin rs9 r ([a b] . peep rs9 r ()),
                            pin ns9 m ([a b] . peep ns9 m ()),
                            pin ov9 m ([a b r] . peep ov9 m ()),
                            pin sp9 a [(<o + map (nm \ [nm r (in9 nm) (out9 nm)]) evs)
                                       ([m r (in9 m) (out9 m)] . <>o)],
                            (elem r cs0 && nelem r (cu9 'cu) ? (pin cu9 'cu (r . cu9 'cu))),
                            1))))))
               (has9 '(sexpr) s9 ? () (map take9 cands)))
           (? (has9 '(goto igoto lbl asm) items) [{} {} cu0]
              (: _ (map one (sortby (x \ y \ (? (y 2 < x 2) 1 (x 2 < y 2) () (<>x - <x < <>y - <y))) (av9 19)))
                 [ov9 sp9 (cu9 'cu)])))
       ; the param verdicts -> (rides homes excl depth): a cold homable param rides its arrival where
       ; sound (a quad pays one mov to its positional seat), a hard-crossing one stays a cell
       (upar av9 qk)
        (: uv <>>av9 crh9 (av9 6) rdc9 (av9 7) rdt9 (av9 8)
           lf9 (av9 15 <= 2)                  ; leaf-shaped: at most two cold hard crossings (see ulloc)
           pq9 (qk && av9 16)                    ; protocol-quiet: nothing in the body writes a quad
           wm9 (av9 17 && !(a64? g || t32? g || rv64? g || ia32? g))   ; d128 material on x64, whose mul/div pin rax:rdx
           wd9 (wm9 && 2 < av9 18)             ; a nested park would starve: the wide kit owns the file
           dp9 (wm9 ? 5 3)                     ; else a take leaves the file two deeper, one park's draw
           ; a param holds its arrival only while it ranks among the seats: the locals that outrank it
           ; by ulloc's own key, live at once, would otherwise want more seats than the file has
           spa9 (av9 5) sqm9 (av9 9) tak9 (av9 14) nsq (av9 13)
           ltc (: (go i acc)
                  (nsq < i ? acc
                     (: e2 (sqm9 i) nm2 <e2
                        (two? e2 && elem nm2 uv && !(tak9 nm2) && !(fhomable? <>e2 || d128? <>e2) &&
                         2 <= peep rdc9 nm2 0 && two? (spa9 nm2) ?
                           (go (i + 1) ([(peep rdc9 nm2 0) <(spa9 nm2) <>(spa9 nm2)] . acc))
                           (go (i + 1) acc))))
                  (go 1 ()))
           nst9 (#tpool + #(cspool g))
           ; the most of them live at any one start
           (crowd l) (foldl (m \ s \ #(filter (t \ t 1 <= s 1 && s 1 <= t 2) l) @ n (m < n ? n m)) 0 l)
           (outrun? nm) (peep rdc9 nm 0 @ tc
                           (!(abl? g 'prank) && nst9 <= crowd (filter (t \ tc < <t) ltc)))
           (homefold g params 0 [() () () #tpool]
            (a4 \ gpi \ p9 \
              (: nm <p9 pty <>p9
                 A (argr g gpi)
                 nv (a4 3)                       ; the file's running depth (homes and rides drain it)
                 ok (lf9 && !wd9 && elem nm uv && peep crh9 nm 0 <= 2 && !(outrun? nm) &&
                     (!wm9 || 64 <= peep rdt9 nm 0))  ; beside the wide kit only a hot param takes a seat
                 ; a bool's entry cvt defs through set, which qclob? cannot tell from a clobber: a bool quad vacates
                 qb9 (pty = 'bool && elem A '(r0 r1 r2 r3))
                 (? (ok && homable? pty && (!wm9 || dp9 <= nv))
                    (? (A = homereg gpi) [<a4 (gpi . <>a4) (a4 2) (nv - 1)]
                       (a4rider? A) [<a4 (gpi . <>a4) (a4 2) nv]
                       (elem A '(r0 r1 r2 r3))
                        ; a protocol-quiet body rides the quad free (ubuild re-checks the built forms); a dirty one vacates
                        (pq9 ? [(gpi . <a4) <>a4 (a4 2) nv]
                           [<a4 (gpi . <>a4) (a4 2) (nv - 1)])
                       [(gpi . <a4) <>a4
                        (elem A tpool ? (A . a4 2) (a4 2))
                        (elem A tpool ? (nv - 1) nv)])
                    ; an int param rides its arrival if read at least once, no d128 about, and the file
                    ; stays two deep after the take; a64's r4 arrival rides free
                    (ok && lhomable? pty && !qb9 && 0 < peep rdc9 nm 0 && !wd9 &&
                     (elem A tpool && dp9 <= nv || a4rider? A))
                     [(gpi . <a4) <>a4
                      (elem A tpool ? (A . a4 2) (a4 2))
                      (elem A tpool ? (nv - 1) nv)]
                    (ok && lhomable? pty && !qb9 && 0 < peep rdc9 nm 0 &&
                     pq9 && elem A '(r0 r1 r2 r3))
                     [(gpi . <a4) <>a4 (a4 2) nv]
                    ; ..and a hot one (weighted reads >= 64, the blocker bar) that cannot ride vacates to its positional seat
                    (ok && lhomable? pty && !wd9 && 64 <= peep rdt9 nm 0 &&
                     elem A '(r0 r1 r2 r3) && dp9 <= nv)
                     [<a4 (gpi . <>a4) (a4 2) (nv - 1)]
                    a4)))))
       ; the quad-ride check: a ridden r0-r3 arrival's only legitimate def is its entry cvt; any other
       ; def falsifies the ride, and a form rdsp cannot read ('bar) counts as a hit
       (qclob? fs qrr)
        (two? qrr ?
           (: (go l) (two? l ?
                        (<l @ f9
                           (!(two? f9) ||
                            elem <f9 '(sx4 zx4 sx2 zx2 sx1 zx1 label align br jmp jmpr ret) ? (go >l)
                              (rdsp g f9 @ rd
                                 (rd @ 'bar 1
                                       (: (hit l2) (? !(two? l2) ()
                                                      (elem <l2 qrr) 1
                                                      (hit >l2))
                                          (hit <>rd ? 1 (go >l))))))))
              (go fs)))
       (ubuild av9)
        (: ok9 (two? av9 && !(av9 11) && !(av9 12))   ; no asm, no vla
           ; ride the quads first; if the built forms show a ridden register taken, demote them and
           ; build once more (attempt () has no rides to fail)
           (attempt qk)
            (: pv (ok9 ? (upar av9 qk) '(() () ()))
               rides <pv phs <>pv excl (pv 2)
               uh9 (map homereg phs)
               pool2 (filter (q \ !(elem q uh9 || elem q excl)) tpool)
               bl9 (!ok9 ? ()
                      (: crh9 (av9 6) rdc9 (av9 7) rdt9 (av9 8)
                         (homefold g params 0 ()
                          (a2 \ gpi \ p9 \
                            (: nm <p9
                               wt (peep rdt9 nm 0)
                               (homable? <>p9 && 0 < peep crh9 nm 0 && 64 <= wt ?
                                  ([(peep rdc9 nm 0) wt] . a2) a2))))))
               lr (ok9 ? (ulloc av9 pool2 bl9))
               lh9 (two? lr ? <lr {})
               lp9 (two? lr ? <>lr pool2)
               cu1 (two? lr ? <>>lr ())
               sx9 (ok9 && two? lr && !(abl? g 'lsplit) ? (usplit av9 lh9 cu1 <><>>>f) [{} {} cu1])
               cu0 <>>sx9                     ; the splitter's fresh callee-saved seats owe their saves too
               ; the double params' xmm grants: a read, zero-crossing, once-declared name takes a
               ; seat the locals left, in arrival order
               fgr ({} @ t
                      (!ok9 ? t
                         (: used (map (k \ lh9 k) (keys lh9))
                            crs9 <>av9 rdc9 (av9 7) uv <>>av9
                            (go ps free)
                             (? !(two? ps) 0
                                !(two? free) 0
                                (: nm <<ps pty <><ps
                                   (fphome? g pty && elem nm uv && peep crs9 nm 0 = 0 &&
                                    0 < peep rdc9 nm 0 ?
                                      (pin t nm <free, go >ps >free)
                                      (go >ps free))))
                            (go params (filter (f9 \ (nelem f9 used)) (ffile g)),
                             t))))
               e0 (peep g 'epi epi)
               ; no reset before the first attempt: the VLA prep's slots live in this frame state and a
               ; reset would re-deal them (ok9 bars VLAs from every path that retries)
               _ (pins g 'pool0 lp9 'pool lp9)
               _ (rgset g lh9 av9)
               _ (pins g 'spov <sx9 'splits <>sx9)
               _ (getenv "MOON_DUMP" @ w (string? w && w = <>f && two? (keys <>sx9) ?
                    (puts ";; splits \(show (map (k \ [k (<>sx9 k)]) (sort (keys <>sx9))))\n")))
               _ (pin g 'fpar fgr)
               ; wasm's cs seats need no save: a callee's locals are its own
               ; i386's ebx rides the frame's own rbx save (unframe keeps it once r3 is written)
               _ (two? cu0 && !(wasm? g) ?
                    (map (r9 \ [(elem r9 (fcspool g) ? 'stsd 'st) 'r4 (nslot g 8) r9]) (filter (r9 \ !(ia32? g && r9 = 'r3)) cu0) @ sv
                       (pin g 'cssv sv,
                        pin g 'epi (map (f9 \ [(<f9 = 'stsd ? 'ldsd 'ld) (f9 3) 'r4 (f9 2)]) sv + e0))))
               ; empty grants take the bare () policy, so no policy bar can fire
               spu (spillp (two? rides || two? phs ? ['uni rides phs]) params 0 ())
               spu (two? vzf ? [(<spu + vzf) <>spu] spu)
               irU (build spu)
               _ (pins (rgreset g) 'cssv () 'epi e0)
               qrr (: (go l) (two? l ?
                                (argr g <l @ A
                                   (elem A '(r0 r1 r2 r3) ? (A . go >l) (go >l))))
                      (go rides))
               (? (qk && two? qrr && qclob? irU qrr)
                  (pins (fnreset g) 'n n0 'strs strs0 'statics sts0 'fasecs fas0 'pool0 tpool 'pool tpool 'hasasm (pre0 1) 'twice (pre0 3) 'ltaken (pre0 5),
                   attempt ())
                  (bad? irU ||
                   two? av9 && peep g 'lsq 0 != av9 3 ||
                   !(peep g 'dseq 0 = (two? av9 ? (av9 13) (peep g 'dseq 0))))
                  (: _ (pins (fnreset g) 'n n0 'strs strs0 'statics sts0 'fasecs fas0 'pool0 tpool 'pool tpool 'hasasm (pre0 1) 'twice (pre0 3) 'ltaken (pre0 5))
                     sb (spillp () params 0 ())
                     sb (two? vzf ? [(<sb + vzf) <>sb] sb)
                     (build sb))
                  irU))
           (attempt 1))
       n0 (peep g 'n 0) strs0 (g 'strs) sts0 (g 'statics) fas0 (g 'fasecs)   ; snapshot the accumulators for ubuild's retry
       pre0 ['hasasm (g 'hasasm) 'twice (g 'twice) 'ltaken (g 'ltaken)]       ; ..and the prescan's pins, which fnreset clears
       ; no pool on t32 (r4-r11 callee-saved, r0-r3/r12 scratch); riscv pools t0..t3 then a5..a7, as
       ; a64 pools x5..x7 -- an arg register is dead once spilled or homed. a64 adds x11, x13, x14,
       ; caller-saved and never an argument (x12 stays the pair and float-word scratch)
       tpool (? (abl? g 'tpool) () (ilp32? g) () (rv64? g) '(r8 r9 r10 r11 r5 r6 r7)
                (a64? g && !(abl? g 'a64pool)) (opool + '(r11 r13 r14)) opool)
       _ (pins g 'pool0 tpool 'pool tpool)
       ; a memory return: the hidden pointer (gp 0) saves to its own slot (g 'sret), params start at gp 1
       srt (two? sig ? <sig 'long)
       sr6f (sretm? g srt)
       ; the one build: seats from alive; a memory sret and varargs take the bare spill build, no seats
       uni9 !(sr6f || vararg)
       _ (sr6f ? (pin g 'sret (ntmp g 'long)))
       sp1 (? uni9 ()
              (vararg && a64? g) (vaspill-a64 params)
              (vararg && t32? g) (vaspill-t32 params)
              (vararg && ia32? g) (vaspill-ia32 params)
              (vararg && rv64? g) (vaspill-rv params)
              vararg (vaspill params)
              (sr6f && ia32? g && !(srreg? g ())) (spillp () params 0 [['ld 'r1 'r4 (ovb g)] ['st 'r4 (peep g 'sret 0) 'r1]])
              sr6f (spillp () params (a64? g ? 0 1) [['st 'r4 (peep g 'sret 0) (srreg g)]])
              (spillp () params 0 ()))
       sp1 (uni9 || !(two? vzf) ? sp1 [(<sp1 + vzf) <>sp1])   ; the VLA size-slot zeroes ride after the spills
       irf0 (uni9 ? (ubuild (alive g f)) (build sp1))
       ; i386: a build that seats esi and edi and leaves ebx alone (no park, no pair scratch -- r3
       ; only in the frame's own save) builds again with ebx a seat too
       (r3in? x) (? (atom? x) (x = 'r3)
                    (x = sav3 || x = '(ld r3 r4 -8)) ()
                    (any r3in? x))
       (rhas? r x) (? (atom? x) (x = r) (any (rhas? r) x))
       irf (? (ia32? g && uni9 && !(bad? irf0) && !(abl? g 'ebx) && rhas? 'r5 irf0 && rhas? 'r6 irf0 && !(r3in? irf0))
              (: _ (pins (fnreset g) 'n n0 'strs strs0 'statics sts0 'fasecs fas0 'pool0 tpool 'pool tpool
                         'hasasm (pre0 1) 'twice (pre0 3) 'ltaken (pre0 5) 'ebx 1)
                 (ubuild (alive g f)))
              irf0)
       ; the post-choice chain, typed by stage.l (each pass advances a stage die, so only this order checks):
       ; the arm sweeps, then deadlab, then repack (a dead region's touches would fatten its windows). cmpfuse is
       ; x64-only; rezx is a64's (riscv's 32-bit ops sign-extend)
       (swp irx) (!(a64? g || rv64? g) ? irx
                    (tailst g
                    (deadst g
                     (deaddef g
                     (copyprop g
                     (memfw g
                     (addk g
                     (addrfold g
                     (addk g
                     ((a64? g ? (rezx g) 1)
                     (copyprop g
                     (stld g
                     (spmerge
                     (deaddef g
                     (deadcell g
                     (cfoldir g irx))))))))))))))))
       ; the copy fold again after repack: a slot copied from a seat repack just minted forwards from it now
       (post irx) (deadst g (deaddef g (copyprop g (stld g (copyprop g (repack g irx))))))
       (bad? irf ? irf (dp 'final (thunks g (pushsv g (rjoin g (absg g (rawclean (a64sp g (a64mv g (bprot g (frrec g (swrap g (tailarm g (jmpm g (csdrop g (cskeep g (unhome g (jr0 g (rvunframe g (unframe g (hz4 g (laacse g (coal g (copyprop g (recse g (wpair g (dp 'post (post (dp 'deadlab (deadlabk (cg-refs (g 'fasecs) {}) (swp irf))))))))))))))))))))))))))))))))

   ; the data tail -> (dataforms nifforms imgforms extras bssforms rodataforms) | 'bad, extras ((name forms
   ; ro?) ..) per other named section in declaration order. love_nifs packs for the linker's __start_/__stop_
   ; bracket, .image rides last so `love bake` can grow it at the tail.
   (cgdata g)
    (: sects (g 'sects || {})
       consts (g 'consts || {})
       memo (g 'romemo || {})
       (strm nm) (sects nm @ s
                    (s ? s ".data"))
       ; an uninitialized global rides .bss unless it names its own section
       (bss? nm) (!(sects nm) && !(two? <>>(peep (g 'glob) nm 0)))
       ; a const global rides .rodata only if its image needs no relocation (a pointer the linker
       ; writes stays in .data, gcc's .data.rel.ro)
       (ro? nm bytes) (consts nm &&
                       !(foldl (a \ x \ a || fixit? x) () bytes))
       ; a const candidate images twice ('d and 'r), so it memoizes; only candidates do
       (image1 nm ty init)
        (!(consts nm) ? (cgimage g ty init)
           (memo nm @ m
              (two? m ? <>m
                 (cgimage g ty init @ v (pin memo nm [1 v], v)))))
       ; zm: 'd the initialized, 'z the bss, 'r the const ones .rodata claims, () everything (a named stream never splits)
       (globs gs want zm acc)
        (? !(two? gs) acc
           !(strm <gs = want) (globs >gs want zm acc)
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
                                           + (elem want '("love_nifs" ".love.image") ? [['raw bytes]] (exact (tsz g ty) bytes))))))))
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
          'laid {}                                  ; names already on 'globs (a tentative repeat lays no twin)
          'fns {} 'inl {} 'ineed {} 'alw {} 'nopf {} 'fnret {} 'kretm {} 'ainlc {} 'cgitems cgitems 'sxpre sxpre 'stag stbl 'sigs sigs
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
          ; the unit names no volatile (the parser's word; absent reads as named): memfw may run
          'novol (two? xtra && 11 < #xtra && !(xtra 11))
          'xfns ()                                  ; (secname forms) per fn that named a section, newest first
          'fasecs ()                                ; a function's asm sections, one gas-top reading each
          'romemo {}                                ; a const candidate's image, laid once and read by both walks
          'mo (two? xtra && 12 < #xtra ? (xtra 12) [() () () () () () () () () () () () () () () () ()])   ; the asks: [strict-align branch-protection regparm pre-686 -Os no-float unsigned-char no-jump-tables no-builtin align-functions no-sibcalls auto-var-zero ibt wrapv patchable-entry stack-guard x86-kernel]
          'pfes (two? xtra && 13 < #xtra ? (xtra 13) {})   ; fn name -> its own patchable_function_entry (N M)
          'pfel ()}                                 ; the pads laid, newest first
       ; pass 0: every fn name (the sig table too: an mproto sibling has a sig but no proto form),
       ; and the inline table -- always_inline at any size, noinline never
       ainls (two? xtra && 5 < #xtra ? (xtra 5))
       noinls (two? xtra && 6 < #xtra ? (xtra 6))
       ; -fno-inline outranks always_inline: the flag is an instrument
       nolin (two? xtra && 9 < #xtra ? (xtra 9))
       (recfns fs) (!(two? fs) ? 1
                      (<fs @ f
                         (elem <f '(fn proto) ? (pin (g 'fns) <>f 1),
                          ; a body that does nothing: a call to it here is its arguments' effects alone
                          (<f = 'fn && nelem <>f weaks && empty? (f 3) ? (pin (g 'nopf) <>f 1) 0),
                          ; ..and one that is a single `return E`, for kcall to answer where E is one constant
                          (<f = 'fn && nelem <>f weaks ? ((f 3) @ ('blk . is . _) (two? is && !(two? >is) && <<is = 'ret && two? >(<is) ? (pin (g 'fnret) <>f <>(<is)) 0) 0) 0),
                          (<f = 'fn && !nolin &&
                           nelem <>f weaks &&
                           nelem <>f noinls ?
                             ((elem <>f ainls ? (sspcut f) f) @ fi
                                (inlok? g fi (sigs <>f) (elem <>f ainls) ?
                                   ((asmneed? g <>>f <>>>f ? (pin (g 'ineed) <>f 1) 0),
                                    (elem <>f ainls ? (pin (g 'alw) <>f 1) 0),
                                    pin (g 'inl) <>f fi) 0)) 0),
                          recfns >fs)))
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
       _ (pin g 'asecs (0 < #asrc ? (trap (t \ gas-top tgt t) asrc
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
               r (cgfn g f)
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
                     fm (['align an] . pfepre g nm pf + al2 + pfepost g nm pf (lpad? g ? (btiat nm r) r))
                     ; a fn that named its section leaves .text for that stream, its align riding out as the section's grain
                     sc (peep (g 'sects) nm ())
                     _ (nm = "main" ? (pin g 'saw 1))
                     _ (sc ? (pin g 'xfns ([sc fm an nm] . g 'xfns)) (pin lfm nm fm))
                     _ (pin laid nm 1)          ; before the walk: a recursive fn names itself
                     ; the wide relation's order, narrowed: tablet keys run in no fixed order, so
                     ; walking the narrow tablet's own would re-deal the layout
                     pr (cg-frefs fm {})
                     (filter (k \ pr k) (keys (cg-refs fm {}))))))
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
           ; ..and a static the file-scope asm names, which no C reference may reach
           aq (foldl (a \ x \ unom x @ t (t && !(laid t) ? (t . a) a)) () (keys (cg-refs (g 'asecs) {})))
           _ (drive (roots + sq + aq))
           ; the data lane's fn references, read off the initializers in g 'glob (block-scope statics
           ; included); a laid body can add its own, so this closes rather than passes
           (datclose _)
            (: t {}
               _ (foldl (_ \ k \ g 'glob k @ e
                                   (two? e ? (cg-srefs <>>e t, 0) 0))
                        0 (keys (g 'glob)))
               ; ..and what a function's asm names from another section
               _ (foldl (_ \ x \ unom x @ s (s ? (pin t s 1) 0)) 0 (keys (cg-refs (g 'fasecs) {})))
               q (foldl (a \ s \ fnix s && !(laid s) ? (s . a) a)
                        () (keys t))
               (two? q && !(gripe? (g 'genfail)) ? (drive q, datclose 0) 0))
           _ (datclose 0)
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
             ; ..only those whose label the text still lays, once each
             pfs (: lt (foldl (t \ f \ (two? f && <f = 'label ? (pin t (<>f) 1) t)) {} (<>r + catall (map (x \ x 1) xfns)))
                    ls (foldl (a \ L \ (lt L && !(elem L a) ? (L . a) a)) () (<r 'pfel))
                    w (ilp32? <r ? 4 8)
                    (two? ls ? [["__patchable_function_entries"
                                 (['align w] . map (L \ ['raw [['fix w (w = 4 ? 'abs32 'abs64) L 0]]]) ls) ()]]))
             [1 <>r <dat fnames gnames
                <>dat <>>dat (lnames + lals) (<>>>dat + pfs) <>>>>dat <>>>>>dat
                xfns (asecs-live <r [<>r (map (x \ x 1) xfns)])]))))
) ; module 'moon
