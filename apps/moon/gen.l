; apps/moon/gen.l -- the code generator. AST -> (1 ir-forms) | (), in holo's neutral IR
; (chibicc was the seed). every expression computes into r0 and carries its type -- cgexpr answers
; (type forms), so pointer arithmetic scales, a dereference loads by pointee width, and an
; array decays to an address. types: 'char 'short 'int 'long | ('ptr t) | ('arr t n); the ALU
; stays 64-bit (signed overflow is UB) and widths bite only at memory and casts. lvalues have
; their own door (clval: the address in r0 + the pointee type), so x, *p and a[i] assign through
; one path. locals ride the r4 frame; globals and string literals are labeled raw data after the
; code, reached by holo's (la) -- one rwx segment carries text and data both until the .o seam.
; args ride the SysV registers r6 r5 r2 r1 r7 r8, at most six, evaluated left to right; a
; function-pointer call head goes through (callr) after parking the callee in r3. a global
; initializer whose value is a label bakes an abs64 fixup ('fix 8 abs64 label 0). a `float` is
; 4 bytes in memory but always a double in an xmm register (a load widens, a store narrows); a
; compound literal ('clit ty init) fills a frame temp whose address is the lvalue.
; refused, not fudged: ptr+ptr, deref of a non-pointer, assigning to an array. a by-value
; aggregate rides x64; the lanes the other targets lack are doc/misc/moon-c-gaps' asymmetries.
; the pipeline's stages are typed: apps/moon/stage.l holds each pass's sig (input stage ->
; output stage), and the moon gate checks this file as data against it -- a new pass declares
; its sig there, and a recomposition of the strict chains is a clash naming its seam.
(module 'moon
(borrow 'kore)
(borrow 'holo) ; the assembler module: asm-text, arbytes, the linker
(:
   ; values lead the book: a plain value folds eagerly at bake, and the fold order is not textual
   spush2 '((sub sp sp 16) (st sp 0 r0) (st sp 4 r1))   ; the t32 pair push (spop2 rides with the pair kit)
   wpush '((sub sp sp 16) (st sp 0 r0) (st sp 8 r2))    ; the wide kit's cell
   wdrop '((add sp sp 16))
   ; a composite at r0 into a fresh 16-byte cell: by words (t32), by eightbytes (the a8 cell),
   ; or pushed high eightbyte first (x64) -- the call lanes' struct-by-value staging
   cell4w '((sub sp sp 16) (ld r1 r0 12) (st sp 12 r1) (ld r1 r0 8) (st sp 8 r1)
            (ld r1 r0 4) (st sp 4 r1) (ld r1 r0 0) (st sp 0 r1))
   cell2w '((sub sp sp 16) (ld r1 r0 8) (st sp 8 r1) (ld r1 r0 0) (st sp 0 r1))
   push2w '((ld r1 r0 8) (push r1) (ld r1 r0 0) (push r1))
   csx64 '(r11 r12 r13 r14)                         ; x64's borrowable callee-saved file (r12..r15): the cs pool and its rosters
   ; unsigned 64 -> double: cvtsi2sd is signed, so convert the two 32-bit halves (each exact)
   ; and sum hi*2^32 + lo, one rounding. the t32 twin is cvtlld's local u2d
   ul2d '((mov r1 r0) (shr r1 32)                     ; hi = x >> 32
         (shl r0 32) (shr r0 32)                     ; lo = x & 0xffffffff
         (cvtsi2sd f0 r1)
         (li r1 0x41f0000000000000) (movqxr f1 r1)   ; 2^32
         (mulsd f0 f1)                               ; hi * 2^32
         (cvtsi2sd f1 r0)
         (addsd f0 f1))
   cxdty '(struct "__cplx_double")                      ; the seeded complex-double tag
   ; the ISA families, the one place an op's membership is stated (every IR pass reads them; an op
   ; off every list is opaque). an op that can base on r4 must also join a4base + uoff and deadst's scans
   ldops9 '(ld ld1 ld2 ld4 ldu1 ldu2 ldu4)          ; the gp loads (full + narrow)
   gstops '(st st1 st2 st4)                         ; the gp stores
   fldops '(ldsd ldss) fstops '(stsd stss)          ; the f-memory pair
   stops9 (gstops + fstops)                         ; every plain store (gp head first)
   leaops '(lea lean)                               ; the address makes (lean: consumed by its own use)
   xops '(leax ldx ldxb)                            ; the indexed forms (base index scale disp)
   stxops '(stx stxb)                               ; the indexed stores
   siops '(si si1 si2 si4)                          ; the store-immediates (the addressing fold + the asn/decl delivery lanes)
   aluops '(add sub and or xor imul)
   ; the flag family: each sets or reads the flags for the form beside it, so never pure (deaddef
   ; would lift it) and never in aluops (the two-address rewrites); off every list rdsp answers 'bar
   flagops '(adds subs adcs sbcs adc sbc ors)
   divops '(div rem udiv urem)                      ; the division protocol (r0..r3 clobber)
   ; (umull dl dh a b) defines two, (mla d a b acc) reads three; udivll/uremll are nullary
   ; expansions owning the r0..r3 protocol quad (r4..r7 are pushed and popped inside)
   wmops '(umull smull)
   llops '(udivll uremll)
   vshops '(shlv shrv sarv rorv rorv4)              ; the variable shifts/rotates (x64: count in r1)
   qfile '(r0 r1 r2 r3 r4 r5 r6 r7 r8 r9 r10 r11 r12)   ; the gp file a 32-bit pair move walks
   unops '(neg not sx1 sx2 sx4 zx1 zx2 zx4)         ; one-register rewrites
   xmmops '(addsd subsd mulsd divsd movsd ucomisd cvtss2sd cvtsd2ss)   ; xmm-only: no gp effect
   barops '(call callr raw sys)                     ; the opaque barriers
   ; the gen state g: 'n the label counter, 'off the frame high-water, 'brk/'cnt the loop label
   ; stacks, 'glob name -> (label ty init), 'globs the emission order, 'strs ((label . text)..);
   ; env is ((name off ty)..), the frame locals
   (nlab g pfx) (: k (peep g 'n 0) (pin g 'n (k + 1), name (pfx + "." + show k)))   ; one counter across prefixes
   argregs '(r6 r5 r2 r1 r7 r8)                      ; the SysV integer/pointer arg registers
   argregs-a64 '(r0 r1 r2 r3 r4 r5 r6 r7)           ; AAPCS64: x0..x7
   argregs-t32 '(r0 r1 r2 r3)                        ; AAPCS32: r0..r3
   (xmmreg i) (name ("f" + show i))                ; the SysV double arg registers f0..f7
   ; the AAPCS-VFP argument slots (t32f): s0..s15, one per float and an aligned pair per double,
   ; each taking the lowest free run. the state is a 16-bit mask (the other seats carry a count); a miss fills it
   (vfpn m n a)                                    ; the lowest a-aligned run of n free slots, or -1
    (: (go i) (? (16 < i + n) -1                   ; a number, not (): slot 0 is a valid answer
                 (0 = (m & (((1 << n) - 1) << i))) i
                 (go (i + a)))
       (go 0))
   (vfpm m i n) (m | (((1 << n) - 1) << i))        ; the mask with that run taken
   vfpx 65535                                      ; the full mask
   ; an even slot is the low half of dK, so the convert lands there; an odd one has no f-register
   ; name, so the word bounces through r12 and s30 (f15's single view, the narrow scratch)
   (vfpst k fS) (? (0 = k & 1) [['cvtsd2ss (xmmreg (k // 2)) fS]]        ; the double in fS -> slot k
                   [['cvtsd2ss 'f15 fS] ['movsnrx 'r12 30] ['movsnxr k 'r12]])
   (vfpsv k base off) (? (0 = k & 1) [['stss base off (xmmreg (k // 2))]]   ; slot k -> a 4-byte home
                         [['movsnrx 'r12 k] ['st base off 'r12]])
   (bad? x) (= x 'bad)                             ; the gripe carrier (gripe/gripe?/okv?) lives in lex.l
   ; the value tuple (ty reg forms); the flo lane keeps the f0 protocol (its reg field is not
   ; consulted) and dispatches on vty
   (vty v) <v
   (vreg v) <>v
   (vfs v) <>>v
   (mkv ty reg fs) [ty reg fs]
   ; the mem face: an lvalue as a (base, offset) memory operand, ['m b o] in the reg seat; a
   ; consumer lays one fused form, and matv is the degenerate face (the address on r0)
   (mkm ty b o fs) [ty ['m b o] fs]
   (vm? v) (bad? v ? () (two? (vreg v)))
   (vmb v) <>(vreg v)
   (vmo v) <>>(vreg v)
   (mata b o) (b @ 'r4 [['lean 'r0 'r4 o]] ; consumed, so lean (the & lane lays its own lea)
                   'r0 (o @ 0 () [['add 'r0 'r0 o]])
                   (o @ 0 [['mov 'r0 b]] [['add 'r0 b o]]))

   (matv g v) (? !(vm? v) v
                 (: b (vmb v)
                    _ (rfree g b)
                    (mkv (vty v) 'r0 (vfs v + mata b (vmo v)))))
   ; the operand pool: g 'pool0 the fn's set (opool minus param homes), g 'pool the free list,
   ; reset per statement. a pool value never crosses a call (caller-saved, no spill wrap)
   opool '(r6 r5 r9 r10 r7 r8)
   ; the vreg shadow: ralloc mints a nom (%v0 ..) mapped in g 'vrt to a physical, and vrfix
   ; substitutes at build's last link. every g-table holds physicals; rp resolves a nom for the machine
   (rp g rz) (g 'vrt rz || rz)
   (vmint? g x) ?(g 'vrt x)   ; is x a minted nom? (pre-vrfix only)
   ; one machine register? every hint-honor test rides this, never bare =: a value can come
   ; back wearing a new mint on the same physical
   (rpeq? g a b) (= (rp g a) (rp g b))
   ; the ablation knob: MOON_ABLATE="tpool,cs" holds named mechanisms empty for pricing. read at
   ; run time per unit (a value binding would fold at bake); unset is every mechanism on
   (ablenv _)
    (: s (getenv "MOON_ABLATE")
       (? !(string? s) ()
          (: n #s
             (cut i j acc) (i < j ? (name (snip s i j) . acc) acc)
             (go i j acc)
              (? (n <= j) (cut i j acc)
                 (elem (s j) '(44 32)) (go (j + 1) (j + 1) (cut i j acc))
                 (go i (j + 1) acc))
             (go 0 0 ()))))
   (abl? g nm) (elem nm (g 'abl))
   (ralloc g) (? !(abl? g 'ralloc)
               (g 'pool @ (r9 . u)
                ; a pinned reg on the free list is the free-list/pin split resurfacing: refuse loud
                (elem r9 (g 'rpin) ? (scare 'ralloc-pinned r9),
                 pin g 'pool u,
                 (: k9 (peep g 'vrn 0)
                    v9 (name ("%v" + show k9))
                  (pin g 'vrn (k9 + 1),
                   pin (g 'vrt) v9 r9,
                   v9)))))
   (rfree g rz) (: r (rp g rz)
                  (elem r (g 'pool0) &&
                 !(elem r (g 'pool)) &&
                 !(elem r (g 'rpin)) ?             ; a splice's register bind is not ours to free
                  (pin g 'pool (r . g 'pool))))
   (wr? g rz) (? (= rz 'r0) 1                        ; writable: protocol r0 or an owned pool reg
                 (: r (rp g rz)
                    (elem r (g 'pool0) &&   ; (a borrowed home or a bind
                     !(elem r (g 'rpin)))))  ;  reg is read-only)
   ; the assignment: move a mint onto its copy's other side, so the copy substitutes to (mov X X)
   ; and the sweep drops it. a move is licensed only over a straight-line window, every rule is a
   ; mention-list scan, and a refused move changes nothing (a leaked mint still dies loud at holo).
   ; two shapes: the bridge (mov X %m) at %m's death and the adoption (mov %m X) at %m's birth
   ; (the call-return mov coal cannot reach). the rules:
   ;   window   -- no control/opaque form strictly inside the span
   ;   tenancy  -- no bare-X mention inside the span but the copy itself, and no co-tenant
   ;               mint on X whose mention span overlaps
   ;   release  -- %m's token T still looks occupied downstream: a bare-T mention inside the
   ;               span, or a bare-T read after it before a def, refuses; a branch/label before
   ;               the answer refuses too (a call/ret is the safe stop: T is caller-saved, never in lvret)
   ;   adoption is %m's only def, so X is never rewritten through it
   ; one cheap pass for an adoption-shaped mov gates the whole engine
   (rasg g fs)
    (: cfl (rafile g)
       (any9 (f . u))
        (two? f && (= <f 'mov) && vmint? g <>f && !(vmint? g <>>f) && elem <>>f cfl || any9 u)
       (any9 fs ? (rasg2 g fs cfl)))
   ; no r4 on the arm family (a4ize retargets a base-slot r4 to fp by position, and a moved mint
   ; can sit in a base slot) and no argument register (a ridden arrival's only def is its entry cvt)
   (rafile g)
    (filter (\ r9 !(elem r9 (csregs g) || (= r9 (fbase g)) || (= r9 'sp) ||
                    elem r9 (argr g) ||
                    (arm? g && (= r9 'r4))))
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
           (: _ (two? f ?
                   (: op <f
                      (? (= op 'label) (padd 'ctl i)
                         (elem op '(jmp br jmpr sys)) (: _ (padd 'ctl i) (padd 'jout i))
                         (elem op '(call callr ud2)) (: _ (padd 'ctl i) (padd 'stop i))
                         (= op 'ret) (: _ (padd 'ctl i) (padd 'ret i))
                         (= op 'align) ()
                         (: rd9 (rdsp g f)
                            (? (= rd9 'bar) (: _ (padd 'ctl i) (padd 'jout i))
                               (: (gr (a . u)) (madd a i 'r, gr u)
                                  (gd (a . u)) (madd a i 'd, gd u)
                                  _ (gr <rd9)
                                  _ (gd <>rd9)
                                  _ (= op 'mov ? (pin st 'cd ([i <>f <>>f] . st 'cd)))
                                  ()))))))
              (w1 u (i + 1)))
       _ (w1 fs 0)
       mtr {}                                ; nom -> mentions ascending (memoized)
       (mup nom) (: o (peep mtr nom 'none)
                    (? (= o 'none)
                       (: v (rev (peep mt nom ())) _ (pin mtr nom v) v) o))
       (fpast l hi) (: (go2 l2 b) (? !(two? l2) b    ; descending bares: the smallest one > hi
                                     (<l2 > hi) (go2 >l2 <l2)
                                     b)
                       (go2 l ()))
       (posin? l lo hi exc)                          ; an ascending mention in [lo..hi] off exc?
        (? !(two? l) ()
           (: p <(<l) (? (p > hi) ()
                         ((p >= lo) && !(elem p exc)) 1
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
                  (rv < pv) !(elem nom (lvret g))
                  (= <>p 'd) 1))
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
        (? !(two? l) ()
           (: c9 <l i <c9 D <>c9 S <>>c9
              dm (vmint? g D) sm (vmint? g S)
              m (? (dm && !sm) D (sm && !dm) S)
              _ (? m
                   (: X (? dm S D)
                      cur (t m)
                      dl (mt m)              ; descending; head is the last mention
                      (? (= cur X) ()              ; already identical: the sweep takes it
                         (mvd m) ()
                         !(elem X cfile) ()
                         (atom? dl) ()
                         (: ml (mup m)
                            lo9 (? dm i (minp dl))
                            hi9 (? dm <<dl i)
                            ndf (: (nd l2 n9) (? !(two? l2) n9
                                                 (nd >l2 (? (= <><l2 'd) (n9 + 1) n9)))
                                  (nd ml 0))
                            ; adoption only (the copy is m's first mention and a def): a
                            ; bridge onto r0 robs stld's forwarding through the staging cell
                            ok (dm && (<(<ml) = i) && (= <>(<ml)) 'd)
                            ; the pair's closing copies are exceptions, not tenants (r0 -> %m -> r0
                            ; coalesces whole); only that direction -- a re-adoption resets m and refuses
                            exc (: (gx l2 a2)
                                    (? !(two? l2) a2
                                       (: e9 <l2 p9 <e9
                                          hit (? dm (= <>e9 X && (= <>>e9 m) && p9 > i)
                                                 (= <>e9 m && (= <>>e9 X) && p9 < i))
                                          (gx >l2 (? hit (p9 . a2) a2))))
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
                               (: _ (pin t m X)
                                  _ (pin mvd m 1)
                                  _ (pin tox X ([lo9 hi9] . peep tox X ()))
                                  1))))))
              (att >l)))
       _ (att (rev (st 'cd)))
       ())
   ; substitute every mint over the assembled prologue+body+epilogue, the innermost build-tail
   ; link: sibcall and soften read registers, so neither may meet a vreg. the assignment runs first
   (vrfix g fs)
    (? !(peep g 'vrn 0) fs
       (: _ (rasg g fs)
          t (g 'vrt)
          (fix1 x) (two? x ? (map fix1 x) (: p9 (t x) (p9 ? p9 x)))
          (sweep (f . u)) (f @ ('mov x x) (sweep u) (f . sweep u))
        (sweep (map fix1 fs))))
   (callish? (a . u))                                ; does the AST reach a call? (an inline splice still may)
    ; a statement expression resets the pool per statement: a barrier, like a call
    (a = 'call || a = 'sexpr || callish? a || callish? u)
   ; does the AST write anything? a face's base register must survive the rhs, so a
   ; store rides the face only past a write-free right side (calls clobber the pool too)
   (wrany? (a . u))
    (elem a '(asn post call asm vastart vaarg sexpr) || wrany? a || wrany? u)
   (tor0 g v)                                       ; land a value on the r0 protocol (frees its pool reg)
    (? (= (vreg v) 'r0) (vfs v)
       (: rd (vreg v) rl (rev (vfs v))
          lf (two? rl ? <rl)
          ; a trailing leax retargets to r0 outright -- lea reads its sources before the dest
          ; write, so even an r0 index is licensed, and the deref's load then sits same-dest
          (? (two? lf && (= <lf 'leax) && (= <>lf rd) && wr? g rd)
             (: fs (rev (['leax 'r0 <>>lf <>>>lf (lf 4) (lf 5)] . >rl))
              (rfree g rd,
               fs))
             (: fs (vfs v + [['mov 'r0 rd]])
              (rfree g rd,
               fs)))))
   (vdrop g v) (: fs (vfs v) (rfree g (vreg v), fs))   ; the value is discarded: keep the effects, free the reg
   ; the result register for an op consuming rA: a writable operand, else a fresh pool reg, else r0
   (rdst g rA) (wr? g rA ? rA (: rX (ralloc g) (rX || 'r0)))
   ; what a register costs, per class, in memory operations; every gate weighs its own extent (the
   ; traffic the residency erases) against it. a gate's n and ext must share one clock (per call or per iteration)
   (rcost cls n)                                    ; -> memory ops per register, or 'never
    (cls @ 'ros  n                                  ; a rostered pin reloads at every call in scope
           'bor  (1 + n)                            ; a seat: one save, then one reload per exit
           'home (2 * n)                            ; a caller-saved home: the wrap pair per call
           'pool (? (0 < n) 'never 1)               ; not a price: a pool home cannot cross a call
           'bind 7                                  ; a splice bind's park (measured, not derived)
           'never)
   (rprice cls n ext)                               ; the margin: ops saved, net of ops spent
    (rcost cls n @ 'never 'never c (ext - c))
   (rpays? cls n ext)                               ; ...and it must win
    (rprice cls n ext @ 'never 0 m (0 < m ))
   ; frame-direct: a constant-indexed frame-array element is a static slot (off + k*elsize), the
   ; address consumed by its own load/store, so escaping arrays too; pair/d128 keep the address lanes
   (afd g env e)                                    ; -> (off elty) | ()
    (e @ ('deref ('bin '+ ('var nm) ('num i && 0 <= i)))
           (: en (vent g env nm)
              (? !(two? en && (= <en 'loc) && arr? <>>en) ()
                 (: et <>(<>>en)
                    (? ((ptr? et || elem et '(char uchar bool short ushort int uint long ulong)) &&
                        !(pair? g et))
                       [(<>en + i * tsz g et) et])))))
   ; may an alias live across a splice body? only in a register the body's staging never writes:
   ; x64 staging owns r0-r3; elsewhere the arrivals r0-r7 are staging-adjacent, so pool/cs only
   (alsafe? g rz)
    (: r (rp g rz)
       (? (x64t? g) !(elem r '(r0 r1 r2 r3))
          (elem r (g 'pool0) || elem r (cspool g))))
   ; may this param alias? only if the body never writes it (the register holds the caller's
   ; live value). a C name is a string, so the compare is `=` -- `==` never matches
   (wrs? nm e)
    (e @ (('asn || 'post) . ('var ^nm) . _) 1
     (: (go (a . u)) (wrs? nm a || go u) (go e)))
   ; how hard the body leans on this param: reads weighted x8 per loop level (alive's convention)
   (rdw nm e w)
    (? !(two? e) 0
       (e @ ('var ^nm) w
            (: w9 (? (elem <e '(while do for)) (w * 8) w)
               (go l a) (? !(two? l) a (go >l (a + rdw nm <l w9)))
               ((? (two? <e) (rdw nm <e w9) 0) + go >e 0))))
   ; the per-statement pool reset: pool0 minus the splice binds
   (psreset g)
    (: vp (g 'rpin)
       (? !(two? vp) (pin g 'pool (g 'pool0))
          (pin g 'pool (filter (\ r9 !(elem r9 vp)) (g 'pool0)))))
   ; the target seam: g 'tgt (x64 | a64 | rv64 | wasm | thumb2 | thumb2sp | thumb1) picks the ABI
   ; shapes; the IR stays neutral. the arm family retargets the frame base to fp at the end of build (a4ize)
   (a64? {'tgt 'a64}) 1
   (t32? g) (elem (g 'tgt) '(thumb2 thumb2sp thumb1))   ; the 32-bit thumb ABI family (AAPCS32): armv7e-m + armv6-M share it
   (sp64? {'tgt 'thumb2sp}) 1       ; armv7e-m with an sp-only fpu (the playdate's STM32F746): f64 arithmetic softens
   (v6m? {'tgt 'thumb1}) 1          ; armv6-M refinements only: narrower immediates, no imm-mul, soft-divide, pop-pc epilogue
   (t32f? g) (t32? g && !(v6m? g))  ; the thumb seats with an fpu, hence AAPCS-VFP: floats ride s0..s15
   (rv64? g) (elem (g 'tgt) '(rv64 wasm))   ; rv64imfd (LP64): 64-bit, 8 gp args, hard doubles, the lr/fp frame
   (wasm? {'tgt 'wasm}) 1          ; ..which wasm rides whole; it differs only where its machine lacks an op
   (gtgt g) (? (wasm? g) 'rv64 (peep g 'tgt 'x64))   ; the ABI name the asm dialect and the lane rosters read
   (x64? g) (= (peep g 'tgt 'x64) 'x64)
   (a8? g) (a64? g || rv64? g)                        ; the 8-gp-arg LP64 pair: a64 + riscv share the AAPCS64 shapes
   (arm? g) (a64? g || t32? g || rv64? g)             ; the lr-push / fp-base frame family (riscv rides it whole)
   (wsize g) (? (t32? g) 4 8)                       ; the machine word in bytes (a pointer, a gp scalar, a stack cell)
   (argr g) (? (a8? g) argregs-a64 (t32? g) argregs-t32 argregs)   ; riscv a0..a7 map onto the same r0..r7
   (ngp g) (? (a8? g) 8 (t32? g) 4 6)
   (pkr g) (? (a64? g) 'r15 (t32? g) 'r12 (rv64? g) 'r12 'r3)   ; the callr park (rbx / x15 / IP / t4), clear of the arg registers
   (ip2 g) (? (a8? g) 'r1 'r2)                      ; an int-pair aggregate's second register (rax:rdx / x0:x1 / a0:a1); thumb2 unused for M1 scalar
   (ovb g) (? (a8? g) 32 (v6m? g) 12 (t32? g) 8 16)   ; overflow params above the push cells: x64 [ret+rbp]=16; a64/riscv 2x16; thumb2 lr+fp=8; v6m lr+fp+r4=12
   ; the a64 home pool: caller-saved, never an argument register (every home takes one prologue
   ; mov), clear of x15 (the callr park) and x16 (holo's far offset)
   hregs-a64 '(r10 r11 r12 r13 r14)
   hregs-t32 '(r5 r6 r7 r8)                          ; thumb2 callee-saved home pool (inert while nhome=0)
   ; the riscv home pool: caller-saved temporaries, never an argument register, clear of the
   ; callr park (t4 = r12) and holo's t5/t6; t1 last, the coldest seat
   hregs-rv64 '(r8 r10 r11 r9)
   (hregs g) (? (a64? g) hregs-a64 (rv64? g) hregs-rv64 (t32? g) hregs-t32 opool)   ; the home pool (x64 rides opool, positionally arg-aligned)
   (nhome g) (? (a64? g) 5 (rv64? g) 4 (t32? g) 0 6)      ; how many gp positions can home (thumb2: none yet -- spill all params)
   ; the callee-saved pools residency may borrow: saved by the prologue (g 'cssv), reloaded on every
   ; exit, a target joining once cskeep verifies its prologue. no r4 in any arm pool (a4ize renames
   ; a base-slot r4 to fp) and no r7 in v6m's (fp there); riscv leads with s1 (r15), the rvc window's one cs seat
   (cspool g) (? (abl? g 'cs) ()
                 (a64? g) '(r19 r20 r21 r22 r23 r24 r25 r26 r27 r28)
                 (rv64? g) '(r15 r13 r14 r19 r20 r21 r22 r23 r24 r25 r26)
                 (v6m? g) '(r5 r6)                    ; the 16-bit str/ldr reach r0-r7 only, and r7 is fp
                 (t32? g) '(r5 r6 r7 r8 r9 r10)
                 (arm? g) ()
                 csx64)
   (deep? pl) (two? >>pl)                           ; a pool affords a priced seat: two remain after the take
   (fbase g) (arm? g ? 'fp 'r4)                   ; the frame base as post-build ir1 spells it (a4ize); a64+thumb2 fp, x64 r4
   ; a refusal names itself: 'bad is both "take another lane" (a policy deopt) and "no lane
   ; anywhere" (a target gate); only the second speaks, so nolane pins the phrase. last pin wins
   (nolane g txt) (pin g 'nolane txt, 'bad)
   (ontgt g) (" on " + show (peep g 'tgt 'x64))      ; " on a64" -- for a phrase whose answer turns on the target
   (no128 g) (nolane g ("no lane for 128-bit integer arithmetic" + ontgt g))   ; every d128 site, one phrase
   ; the immediate gate: what each target's ALU/cmp immediates reach
   (immok g cls n)
    (? (a64? g)
       (cls @ 'addsub (-16777215 <= n <= 16777215)   ; imm12, or the backend's hi12+lo12 split
              'cmp (-4095 <= n <= 4095)              ; imm12 only (no split -- flags)
              'log (0 < n && 0 = (n & (n + 1))))
       (v6m? g)
        (cls @ 'addsub (-255 <= n <= 255)             ; v6-M ADDS/subs imm8 (imm3 3-addr / imm8 2-addr; negative flips)
               'cmp (0 <= n <= 255))                  ; cmp imm8 only -- no cmn-imm on v6-M, so materialize negatives
       (t32? g)
        (cls @ 'addsub (-4095 <= n <= 4095)           ; addw/subw imm12
               'cmp (-255 <= n <= 255))               ; cmp/cmn imm8
       (fits32? n))
   ; may this op take n as its immediate? (the sweeps ask before rewriting a reg-reg form)
   (imma g op n) (op @ 'imul ((x64t? g || rv64? g) && fits32? n)   ; imul imm: x64's three-operand form, riscv materializes; a64/t32 have none
                       ('add || 'sub) (immok g 'addsub n)
                       'cmp (immok g 'cmp n)
                       (immok g 'log n))
   ; the type floor rides apps/moon/floor.l; g carries only the machine word and the stag table
   (uldop sz) (sz @ 1 'ldu1 2 'ldu2 4 'ldu4 'ld)   ; unsigned load of a sz-byte word
   (fnty g nm) (: sig (g 'sigs nm)        ; a named function's type, return and parameters riding when sig'd
                (two? sig ? ['fn <sig <>sig] '(fn)))
   ; the SysV eightbyte classes of a by-value aggregate (its value is its address in r0): '(int) /
   ; '(sse) at <=8 bytes, two symbols at 9..16, () for a scalar, an unsized tag or >16 (memory)
   (aclass g ty)
    (? !(stru? ty) ()
       (: se (peep (g 'stag) <>ty 0)
          (? !(two? se) ()
             (16 < <>se) ()
             (: cls {}
                (mark o c) (: i (o >> 3) old (cls i)
                              (pin cls i (= old 'int || (= c 'int) ? 'int 'sse)))
                (walk o mty)
                 (? (flo? mty) (mark o 'sse)
                    (arr? mty)
                     (: esz (tsz g <>mty)
                        (go i) (? (<>>mty <= i) 1
                                  (: _ (walk (o + (* i esz)) <>mty) (go (i + 1))))
                        (go 0))
                    (stru? mty)
                     (: e2 (peep (g 'stag) <>mty 0)
                        (? !(two? e2) 1 (fields o <e2)))
                    (mark o 'int))
                (fields o fs)
                 (? !(two? fs) 1
                    (: f <fs _ (walk (o + <>f) <>>f) (fields o >fs)))
                _ (fields 0 <se)
                (? (<>se <= 8) [(peep cls 0 'int)]
                   [(peep cls 0 'int) (peep cls 1 'int)])))))
   ; the HFA base: the one float type of every scalar leaf, else (). AAPCS-VFP aligns a candidate
   ; to its base (a float HFA to one slot, a double to two), which the eightbyte classes cannot tell
   (hfab g ty)
    (: (walk mty acc)
        (? (flo? mty) (? !acc mty (= acc mty) acc 'no)
           (arr? mty) (walk <>mty acc)
           (stru? mty) (: e2 (peep (g 'stag) <>mty 0)
                          (? !(two? e2) 'no (fields <e2 acc)))
           'no)
       (fields fs acc)
        (? !(two? fs) acc
           (: a2 (walk <>><fs acc) (? (= a2 'no) 'no (fields >fs a2))))
       (? !(stru? ty) ()
          (: se (peep (g 'stag) <>ty 0)
             (? !(two? se) ()
                (: r (fields <se ()) (? (= r 'no) () r))))))
   (acls2 g ty ca cb) (aclass g ty @ (^ca ^cb) 1)
   (sse2? g ty) (acls2 g ty 'sse 'sse)       ; both eightbytes SSE: the xmm0:xmm1 pair
   (ipair? g ty) (acls2 g ty 'int 'int)      ; both INT: rax:rdx (return/result lanes)
   (aone g ty) (: c (aclass g ty) (two? c && !(two? >c) ? <c))
   (aeb2 g ty) (: c (aclass g ty) (two? c && two? >c ? c))       ; a 9..16B aggregate's two eightbyte classes (c0 c1), else ()
   ; the memory class: an aggregate past 16 bytes, passed wholly on the stack (x64 only; AAPCS64 differs)
   (amem? g ty) (stru? ty && !(aclass g ty) && !(arm? g) && !(t32? g))
   (asalign g ty) (: e (peep (g 'stag) <>ty 0) (two? e ? <>>e 8))        ; a struct tag's alignment
   (aslots g ty) (((tsz g ty + 7) & -8) >> 3)                              ; its eightbyte count
   ; a memory-class return: a hidden pointer as the first gp argument, filled and answered by
   ; the callee. v6-M past 4 bytes, SysV past 16
   (sretm? g ty) (stru? ty && (v6m? g && 4 < tsz g ty || amem? g ty))
   (fnret ty) (? !(two? ty && <ty = 'ptr) 'long        ; an indirect callee's result type: ('ptr ('fn ret ptys)) | 'long
                 (: ft <>ty (fn? ft && two? >ft ? <>ft 'long)))
   (fnpts ty) (? !(two? ty && <ty = 'ptr) ()           ; ..and its parameter types, () where the declarator had no prototype
                 (: ft <>ty (fn? ft && 2 < #ft ? (ft 2) ())))
   ; the unsigned scalars: the signed twin's width, but a load zero-extends, `>>` is logical,
   ; and compare/divide go unsigned
   (usg? ty) (elem ty '(uchar ushort uint ulong ullong u128))
   ; llong/ullong exist only on t32 (canon folds `long long` to 'long elsewhere): the r0:r1
   ; pair, the one type wider than the accumulator
   (llt? ty) (ty = 'llong || ty = 'ullong)
   ; the signedness is C's (6.3.1.8's rank rule, puac in floor.l): a strictly wider signed type
   ; keeps the common type signed. the width is still the accumulator's, not C's
   (ubin w64 ta tb)
    (: c (puac w64 ta tb)
       (? (llt? ta || llt? tb) (tusg? c ? 'ullong 'llong)
          (tusg? c) 'ulong 'long))
   ; a 32-bit unsigned result wraps in C and not in a 64-bit register: rbin types every uint binary
   ; op 'uint (so a later op sees the narrow operand) and + - * << also re-narrow. 64-bit only: t32's word is 32
   (u32? g ty) (!(t32? g) && (= ty 'uint))
   (u32bin? g ta tb)
    (!(ptr? ta || ptr? tb) &&
     !(elem ta '(long ulong llong ullong) ||
       elem tb '(long ulong llong ullong)) &&
     (u32? g ta || u32? g tb))
   (rbin g ta tb) (u32bin? g ta tb ? 'uint (ubin !(t32? g) ta tb))
   ; what C calls the literal: an unsuffixed literal that fits is an int, so `uint x * <lit>`
   ; wraps; one too wide is long and the result must not wrap -- hence the range test
   (numty n) (fits32? n ? 'int 'long)
   ; a literal through its written face: -1 is (un neg (num 1)), ~0 (un bnot (num 0)). litv
   ; folds it to (v) | (); numty9 types an operand as C reads the source, else the tuple's type
   (litv e) (e @ ('num n) [n]
                 ('un op x && two? x)
                  (: r (litv x)
                     (? (atom? r) ()
                        (op = 'neg) [-<r]
                        (op = 'bnot) [(-<r - 1)])))
   (numty9 e ty) (: r (litv e) (two? r ? (numty <r) ty))
   ; a literal wearing a cast coat rides the immediate lanes as its masked value plus the coat's
   ; type; long/ulong pass the 64-bit pattern whole, so t32 refuses them. knum: bare or coated -> (v ty) | ()
   (cnum g e)
    (e @ ('cast ty ('num n && (charm? n || sun? n)))
     (ty @ 'bool [(n != 0) ty]
           'uchar [(n & 255) ty]
           'ushort [(n & 65535) ty]
           'uint [(n & 4294967295) ty]
           ('char || 'short || 'int)
            (: w (ty @ 'char 8 'short 16 32)
               r (n & ((1 << w) - 1))
               s (r < (1 << (w - 1)) ? r (r - (1 << w)))
             [s ty])
           ('long || 'ulong) (t32? g ? () [n ty])))
   (knum g e) (e @ ('num n) [n (numty n)] (cnum g e))
   ; a compare or divide takes the common converted type's signedness (puac); a pointer compares
   ; as the unsigned word. znrw: int meets uint at uint, so the 64-bit targets also owe the 32-bit narrow
   (cmpu g ta tb)
    (ptr? ta || ptr? tb || tusg? (puac !(t32? g) ta tb))
   (znrw g ta tb ra rb)
    (u32bin? g ta tb ? ((usg? ta ? () [['zx4 ra]]) + (usg? tb ? () [['zx4 rb]])))
   ; a case constant converts to the switch control's type (C11 6.8.4.2p5) as the register's
   ; extended pattern. no & here: the 64-bit mask is a big, and love's bitwise ops answer nothing on one
   (cfit g ty v)
    (: m (t32? g || !(elem ty '(long ulong llong ullong)) ? 4294967296 18446744073709551616)
       r (v % m)
       u (r < 0 ? (r + m) r)
       (? (usg? ty || ptr? ty) u
          (u < (m // 2)) u
          (u - m)))
   (scc op unsg) (!unsg ? op (op @ 'lt 'below 'gt 'above 'le 'be 'ge 'ae op))
   (rflip op) (op @ 'lt 'gt 'gt 'lt 'le 'ge 'ge 'le op)      ; mirrored (n < x reads x > n): constant-on-the-left
   (irop op) (op @ '+ 'add '- 'sub '* 'imul '& 'and '| 'or '^ 'xor 'no) ; C op -> IR mnemonic; not one of the six -> 'no
   ; the NaN-honest ==/!= settle after ucomisd: unordered (PF=1) reads false for == and true
   ; for !=, so == ands the ordered bit in and != ors parity (r0 the truth, r1 the scratch)
   fsete '((set eq r0) (set np r1) (and r0 r0 r1))
   fsetn '((set ne r0) (set p r1) (or r0 r0 r1))
   (negrel op) (op @ 'eq 'ne 'ne 'eq 'lt 'ge 'ge 'lt 'le 'gt 'le)   ; negated: branch-if-false
   (fits32? v) (-2147483648 <= v <= 2147483647)    ; holo's ALU/cmp/imul immediates ride le32
   (tsz g ty) (tysz (wsize g) (g 'stag) ty)
   ; a member's (offset ty) off a struct type, | 'bad
   (fmem g ty name)
    (? !(stru? ty) 'bad
     (: e (g 'stag <>ty)
      (one? e ? 'bad
       (: f (assoc name <e)
        (one? f ? 'bad [<>f <>>f])))))
   (lg2 n) (: (go k v) (v <= 1 ? k (go (k + 1) (v >> 1))) (go 0 n))   ; a true log2 -- a pointer diff over a >8-byte struct needs sar 4+, not a capped 3
   (imby g rX sz) (? (arm? g) [['li 'r3 sz] ['imul rX rX 'r3]] [['imul rX rX sz]])   ; arm mul has no imm form: the size rides r3 (free mid-expression)
   (homable? pty) (ptr? pty || elem pty '(long ulong))       ; an 8-byte gp scalar: what a register home can carry
   ; a home carries narrow gp scalars too, canonically extended (every def re-narrows through cvt,
   ; a param's entry cvt canonicalizes the arrival), so reads are zero forms; a bool home holds 0/1
   (lhomable? ty) (homable? ty || elem ty '(int uint short ushort char uchar bool))
   ; the homable-param fold for pgo, upar and ubuild: a float/sse param spends no gp seat, the
   ; walk stops at the home limit, and (hx acc gpi param) folds each homable seat
   (homefold g ps gpi acc hx)
    (? !(two? ps) acc
       (: pty <><ps
          (? (flo? pty || sse2? g pty || aone g pty = 'sse) (homefold g >ps gpi acc hx)
             (nhome g <= gpi) acc
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
       r (P - (q * d))
       (sig m) (m >= (W // 2) ? (m - W) m)
       (? ((d - r) < (1 << L)) [(sig ((q + 1) % W)) (sgn ? (L - 1) L) 0]
          [(sig (((q + q + ((r + r) >= d ? 1 0)) + 1) % W)) L 1]))
   ; a divide's sign fixup reads the dividend's sign (it agrees with the quotient's), so it spends
   ; n's seat; a remainder reads n again, so it keeps n and takes its own. a dividend in rax is copied first
   (magicop g op av aty n nty wnt)
    (: rA (vreg av)
       sgn !(cmpu g aty nty)
       bw (8 * wsize g)
       keep? (op = '%)
       copy? ((x64? g && rpeq? g rA 'r0) || (!keep? && !(wr? g rA)))
       (grab k acc) (? (k < 1) (rev acc)
                       (: r (ralloc g)
                          (? r (grab (k - 1) (r . acc))
                             (: _ (map (\ x (rfree g x)) acc) 'no))))
       (? ((t32? g) || (wasm? g)) 'no               ; neither machine has a wide multiply
          (abl? g 'divk) 'no
          (n < 3) 'no
          !(n < (1 << (sgn ? (bw - 1) bw))) 'no
          (keep? && !(imma g 'imul n)) 'no
          (: rs (grab (1 + (copy? ? 1 0) + (keep? ? 1 0)) ())
             (? (= rs 'no) 'no
                (@ (magic1 n bw sgn) [M s add?]
                 (: rT <rs
                    rN (copy? ? (rs 1) rA)
                    rU (keep? ? (rs (copy? ? 2 1)) ())
                    pre (copy? ? [['mov rN rA]] ())
                    q9 ([['li rT M] [(sgn ? 'mulh 'umulh) rT rT rN]] +   ; the raw high word
                        (? (sgn && add?) [['add rT rT rN]] ()) +         ; ..and M's own fold-back
                        (? sgn (0 < s ? [['sar rT s]] ()) ()))
                    fx (keep? ? rU rN)                    ; the seat the fold-back may spend
                    tail (keep? ? [['imul rT rT n] ['sub fx rN rT]] ())  ; n - q*d, into the spare
                    fs (? (!sgn && add?)                  ; the unsigned 65th bit: halve the gap
                           (: mid (q9 + [['sub fx rN rT] ['shr fx 1] ['add fx fx rT]] +
                                   (0 < s ? [['shr fx s]] ()))
                              (keep? ? (mid + [['imul fx fx n] ['sub rT rN fx]]) mid))
                          sgn (q9 + (keep? ? [['mov fx rT]] ()) +
                               [['sar fx (bw - 1)] ['sub rT rT fx]] + tail)
                          (q9 + (0 < s ? [['shr rT s]] ()) + tail))
                    rd (? ((!sgn && add?) && !keep?) fx   ; the unsigned fold-back answers in place
                          ((!sgn && add?) && keep?) rT
                          keep? fx
                          rT)
                    (drop r9) (? ((rpeq? g r9 rd) || rpeq? g r9 rA) () (rfree g r9))
                    _ (map drop rs)
                    _ (rpeq? g rd rA ? () (rfree g rA))
                    (mkv (rbin g aty nty) rd (vfs av + pre + fs))))))))
   (immop g op av aty n nty wnt)                    ; av the left value tuple; nty the constant's C type; wnt the advisory destination
    (: rA (vreg av)
       (? (llt? aty || d128? aty) 'no               ; a pair never rides the immediate lane
          (elem op '(eq ne lt le gt ge))
           ; a negative literal converts to the uint side (0xffffffff will not sit in a
           ; signed immediate): the shuttle materializes and narrows
           (? (u32? g aty && n < 0) 'no
              !(immok g 'cmp n) 'no
              (: rd (wnt || rdst g rA)
                 fs (vfs av + [['cmp rA n] ['set (scc op (cmpu g aty nty)) rd]])
                 _ (? (rpeq? g rd rA) () (rfree g rA))
                 (mkv 'long rd fs)))
          (elem op '(/ %))
           ; shr/and is licensed by the common type being unsigned (cmpu), not by either
           ; operand: `(long)-8 / 2u` is -4
           (? !(pow2? n) (magicop g op av aty n nty wnt)
              !(cmpu g aty nty)
               ; the signed pair: C rounds toward zero and sar toward -inf, so a negative
               ; dividend takes a bias of n-1 first (the sign mask shifted down to the low k bits)
               (: k (lg2 n) bw (8 * wsize g)
                  (? (abl? g 'divk) 'no
                     (n = 1) (? (op = '/) (mkv (rbin g aty nty) rA (vfs av))
                                (mkv (rbin g aty nty) 'r0 (vdrop g av + '((li r0 0)))))
                     ((op = '%) && !(immok g 'log (0 - n))) 'no
                     (: rT (ralloc g)
                        (? !rT 'no
                           ; a destination may alias its first source only, so the quotient
                           ; lands in the mask's own seat and the remainder takes a second
                           (: rd (? (op = '/) (wnt || rT) (wnt || rdst g rA))
                              bias [['mov rT rA] ['sar rT (bw - 1)] ['shr rT (bw - k)]]
                              body (? (op = '/) (bias + [['add rd rT rA] ['sar rd k]])
                                      (bias + [['add rT rT rA] ['and rT rT (0 - n)]
                                               ['sub rd rA rT]]))
                              _ (rpeq? g rd rT ? () (rfree g rT))
                              _ (rpeq? g rd rA ? () (rfree g rA))
                              (mkv (rbin g aty nty) rd (vfs av + body)))))))
              (op = '/) (? (n = 1) (mkv (rbin g aty nty) rA (vfs av))
                           (? (wr? g rA)
                              (mkv (rbin g aty nty) rA (vfs av + [['shr rA (lg2 n)]]))
                              (: rd (wnt || rdst g rA)   ; a borrowed home shifts a copy (no 3-address shr)
                                 (mkv (rbin g aty nty) rd (vfs av + [['mov rd rA] ['shr rd (lg2 n)]])))))
              (n = 1) (mkv (rbin g aty nty) 'r0 (vdrop g av + '((li r0 0))))
              !(immok g 'log (n - 1)) 'no                ; t32 has no simple and-imm: materialize (the register path)
              (: rd (wnt || rdst g rA)
                 fs (vfs av + [['and rd rA (n - 1)]])
                 _ (rpeq? g rd rA ? () (rfree g rA))
                 (mkv (rbin g aty nty) rd fs)))
          (: sn (? (ptr? aty && elem op '(+ -)) (n * tsz g <>aty) n)
             iop (irop op)
             ; a bare constant reads as int; a coated one carries its type, so `uint op <lit>`
             ; wraps and `uint op (ulong)k` widens, as C says
             u32 (elem op '(+ - *) && u32bin? g aty nty)
             (? (iop = 'no) 'no
                !(imma g iop sn) 'no
                (: rt (? (ptr? aty) aty (rbin g aty nty))
                   (? (sn = 0 && elem op '(+ -)) (mkv rt rA (vfs av))
                      (: rd (wnt || rdst g rA)
                         fs (vfs av + [[iop rd rA sn]] + (? u32 [['zx4 rd]] ()))
                         _ (? (rpeq? g rd rA) () (rfree g rA))
                         (mkv rt rd fs))))))))
   (ldop ty) (ty @ 'char 'ld1 'short 'ld2 'int 'ld4
                   ('uchar || 'bool) 'ldu1 'ushort 'ldu2 'uint 'ldu4 'ld)
   (stop ty) (ty @ ('char || 'uchar || 'bool) 'st1 ('short || 'ushort) 'st2
                   ('int || 'uint) 'st4 'st)
   ; bool's cvt converts (any nonzero -> 1): every write site runs cvt before its store, so a
   ; bool object holds 0/1 and loads ride a plain ldu1
   (cvt ty r) (ty @ 'char [['sx1 r]] 'short [['sx2 r]] 'int [['sx4 r]]
                    'uchar [['zx1 r]] 'ushort [['zx2 r]] 'uint [['zx4 r]]
                    'bool [['cmp r 0] ['set 'ne r]])
   ; the double lane: a 'double value lives in f0, always a 64-bit double in the register; only
   ; memory differs -- a float slot is 4 bytes, so a load widens and a store narrows (fldf/fstf)
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
       (? (ax < emin 2.0) (fnear (mul2 ax (p - emin)))         ; subnormal: the biased exponent is 0
          (: eu ((: (go e) (? ((e + 1) 2.0 <= ax) (go (e + 1)) e)) (int (log ax / log 2.0)))
             e  ((: (go e) (? (ax < e 2.0) (go (e - 1)) e)) eu)
             m  (fnear ((ax / e 2.0 - 1.0) * (0.0 + mant)))
             ; a fraction that rounds up out of its binade carries into the exponent
             ; (0x1.ff..f -> 0x2.0), and at the top that is the infinity pattern C wants
             (m < mant ? ((e + bias) * mant + m) ((e + 1 + bias) * mant)))))
   (fbits x)                                        ; double -> its IEEE-754 bits as the signed i64 pattern
    (? (x = 0.0) (1.0 / x < 0.0 ? -9223372036854775808 0)   ; -0.0 = 0.0, so the reciprocal's sign parts them
       !(x = x) 9221120237041090560                 ; nan (the quiet pattern): fenc's climb never ends on a non-finite. FIXME: does love ever answer !(x = x)?
       (x + x = x) (x < 0.0 ? -4503599627370496 9218868437227405312)   ; +-inf (1e999 reads as one)
       (: m (fenc (x < 0.0 ? (0.0 - x) x) 1023 52)
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
   ; the narrow scratch: x64 f2 (caller-saved, never live here); a64 f16 (v8..v15 carry a
   ; callee-saved half, so v16+ are the pure temps); t32 f15/d15, which moon never allocates
   (fsc g) (? (a8? g) 'f16 (t32? g) 'f15 'f2)
   (fstf g ty base off val)                         ; store val (a double in an xmm) to [base+off] as ty (narrow if float)
    (ty @ 'float (: f9 (fsc g) [['cvtsd2ss f9 val] ['stss base off f9]])   ; scratch narrows (val untouched)
                 [['stsd base off val]])
   (mkflo g d)                                      ; a double constant -> its value tuple
    (? (t32? g)                                     ; the 64-bit pattern splits over the r0:r1 pair
       (: v (fbits d)
          (mkv 'double 'r0 [['li 'r0 (v & 4294967295)] ['li 'r1 ((v >> 32) & 4294967295)]
                            '(movqxr f0 r0)]))
       (mkv 'double 'r0 [['li 'r0 (fbits d)] '(movqxr f0 r0)]))
   ; the type of a constant arithmetic expression: 'double, 'int (any integer type), or 'no.
   ; float answers 'no (the f suffix parses as a cast and rounds at every step)
   (dbty e)
    (? (atom? e) 'no
       (: k <e
          (? (= k 'var) 'no
             (= k 'num) 'int
             (= k 'flo) 'double
             (= k 'bin)
              (: a (dbty <>>e)
                 (? (= a 'no) 'no
                    (: b (dbty <>>>e)
                       (? (= b 'no) 'no
                          (= a 'double || (= b 'double)) (elem <>e '(+ - * /) ? 'double 'no)
                          (elem <>e '(+ - * / % shl shr & | ^)) 'int
                          'no))))
             (= k 'un) (? (= <>e 'neg) (dbty <>>e)
                             (= <>e 'bnot) (= (dbty <>>e) 'int ? 'int 'no)
                             'no)
             (= k 'cast)
              (? (= (dbty <>>e) 'no) 'no
                 (= <>e 'double) 'double
                 (elem <>e '(bool char uchar short ushort int uint long ulong llong ullong)) 'int
                 'no)
             'no)))
   ; love answers () for a NaN and `infinity` past the range, and neither is a fold
   (dfin? v) (gem? v && (v = 0.0 || !(v + v = v)))
   ; a constant double expression -> its value tuple | (). parse's cfold is the integer twin
   ; (array dims, case labels) and imgbytes' ffold the image-time one; this is the runtime one.
   (cgdfold g e)
    (= (dbty e) 'double && (: v (ffold e) (dfin? v ? (mkflo g v) ())))
   ; result -> f0 as a double. t32: an unsigned word rides the U-converter, a pair source cvtlld
   (asflo g r) (? (flo? (vty r)) (vfs r)
                  (gcplx? (vty r))                  ; complex -> real reads re (C's implicit conversion)
                   (tor0 g r + (cxb (vty r) = 'float ?
                                '((ldss f0 r0 0) (cvtss2sd f0 f0))
                                '((ldsd f0 r0 0))))
                  (t32? g && llt? (vty r)) (tor0 g r + cvtlld g (usg? (vty r)))
                  (t32? g && usg? (vty r)) (tor0 g r + '((cvtui2sd f0 r0)))
                  (= (vty r) 'ulong) (tor0 g r + ul2d)
                  (tor0 g r + '((cvtsi2sd f0 r0))))
   (asint g r) (? (flo? (vty r)) (vfs r + '((cvttsd2si r0 f0))) (tor0 g r))        ; result -> r0 as an int
   ; the mirror of ul2d: cvttsd2si is signed, so a double at or above 2^63 subtracts 2^63 first
   ; (exact: its ulp is >= 2^11), converts, and xors the bit back. negative/NaN/out of range stay UB
   (dtoul g)
    (: lb (nlab g ".du") ld (nlab g ".dv")
       ['(li r1 0x43e0000000000000) '(movqxr f1 r1)         ; 2^63
          '(ucomisd f0 f1) ['br 'ae lb]
          '(cvttsd2si r0 f0) ['jmp ld]                        ; d < 2^63: straight
          ['label lb]
          '(subsd f0 f1)                                       ; d - 2^63, exact
          '(cvttsd2si r0 f0)
          '(li r1 0x8000000000000000) '(xor r0 r0 r1)         ; put 2^63 back
          ['label ld]])
   ; asint honouring an unsigned 64-bit destination: every caller that knows its destination type
   ; comes through here; the rest are integer contexts where the signed truncation is what C asks for
   (asintt g r ty)
    (? (!(t32? g) && flo? (vty r) && (= ty 'ulong)) (vfs r + dtoul g)
       (asint g r))
   ; -- the environments: locals shadow globals --
   (vent g env name)                                ; -> ('regv rN ty) | ('regw (lo hi) ty) | ('loc off ty) | ('glo lbl ty) | 'bad
    (: e (assoc name env)
       (? (two? e)
           (: h <>e y <>>e                             ; a homed param's "off" slot is a (reg rN) list;
              (h @ ('reg x) ['regv x y]     ; a block-scope static's is (glob lbl)
                   ('regw x) ['regw x y]    ; a d128 pair home: (lo hi)
                   ('glob x) ['glo x y]
                   ['loc h y]))
          (peep (g 'gregs) name () @ (s . y . _)
             (: r (gas-regname (gtgt g) s)
                (? (nom? r) ['regv r y] 'bad))
           (g 'glob name @ (a . b . _) ['glo a b] 'bad))))
   ; a static object's address: a frame slot off r4, a global off its label through the address
   ; temp; (f base off) lays the access
   (atstat en tmp f) (? (<en = 'loc) (f 'r4 <>en) ([['la tmp <>en]] + f tmp 0))
   ; the type of an expression without its emission (arrays undecayed); every accumulator the
   ; walk touched is handed back as it was
   (peekty g env e)
    (: n0 (peep g 'n 0) s0 (g 'strs) o0 (peep g 'off 0) sl0 (g 'slots) fe0 (g 'fesc)
       lv (clval g env e)
       _ (? (vm? lv) (rfree g (vmb lv)) ())
       ty (? (bad? lv) (: r (cgexpr g env e ()) (? (bad? r) 'bad (: _ (rfree g (vreg r)) (vty r)))) (vty lv))
       _ (pins g 'n n0 'strs s0 'off o0 'slots sl0 'fesc fe0)
       ty)
   ; a targetable leaf re-emitted straight into rX -> forms | 'no. leaves are pure (no strs pin,
   ; no argpos), so re-aiming costs nothing
   (cgleaf g env e rX)
    (: kc (knum g e)
       (? (two? kc) [['li rX <kc]]
          (<e != 'var) 'no
          (: en (vent g env <>e)
           (? (bad? en) 'no
              !(<en = 'loc) 'no
              (: ty <>>en
                 (stru? ty || arr? ty || flo? ty || d128? ty ? 'no
                    [[(ldop ty) rX 'r4 <>en]]))))))
   ; park the left out of r0 so the right may compute: a leaf re-aims at a fresh pool register,
   ; anything else takes one mov. the tuple | 'sh (pool dry: the caller keeps the memory shuttle)
   (vpark g env e v)
    (vreg v != 'r0 ? v
     (: rX (ralloc g)
      (? !rX 'sh
       (: lf (cgleaf g env e rX)
        (lf != 'no ? (mkv (vty v) rX lf)
         (mkv (vty v) rX (vfs v + [['mov rX 'r0]])))))))
   ; a truth value in r0 that `cmp r0 0` can test: a double folds to d != 0.0
   (ctest g env e)
    (: r (cgexpr g env e ())
       (? (bad? r) 'bad
          (flo? (vty r))                             ; d != 0.0, NaN-honest: unordered is nonzero (true) -- fsetn
           (mkv 'long 'r0 (vfs r + ('((li r1 0) (movqxr f1 r1) (ucomisd f0 f1)) + fsetn)))
          (d128? (vty r))                            ; wide truth: fold the pair into r0
           (mkv 'long 'r0 (vfs r + '((or r0 r0 r2))))
          r))
   ; the predicate splice: a call to an inline-table fn whose body is one `return E` with E a bit
   ; by shape branches through the body straight to lbl. the fesc/strs decline protocol is cginl's. forms | 'no
   (retex f)                                     ; init-free scalar decls* + one `return E` -> (((name ty)..) E) | ()
    (: (dok ps acc9)
        (? (one? ps) acc9
         (: p9 <ps
          (? (two? <>>p9 || arr? <>p9 || stru? <>p9) 'bad
           (dok >ps ([<p9 <>p9] . acc9)))))
       (go items dacc)
        (? (one? items) ()
         (: it <items
          (? (<it = 'decl)
              (: ds (dok <>it dacc) (bad? ds ? () (go >items ds)))
             (<it != 'ret) ()
             (one? <>it) ()
             (two? >items) ()
             [dacc <>it])))
       (go <><>>>f ()))
   (abit? e9) (? !(two? e9) ()
                 (<e9 = 'un && <>e9 = 'not) 1
                 (elem <e9 '(land lor)) 1
                 (<e9 = 'bin && elem <>e9 '(eq ne lt le gt ge)))
   ; the splice bind: params against args -> [benv acc rbs sbs] | 'bad. an arg lands as a constant
   ; (kb?), a homed local's alias register (call-free, never assigned), a pool park (call-free, pk?,
   ; two seats stay free), else a frame slot. rpin holds each bind register; rbs lists the parks, sbs the constants
   (sbind g env ps as nocall body kb? pk?)
    (: (go ps as benv acc rbs sbs)
        (? (one? ps) [benv acc rbs sbs]
           (: nm <<ps pty <><ps
              kb (? (kb? && kb? nm)
                    (: kc (knum g <as)
                       (? (one? kc) ()
                          (: cv (cnum g ['cast pty ['num <kc]])
                             (two? cv ? ['cast pty ['num <cv]])))))
              al (? (nocall && !(flo? pty) && 8 = tsz g pty &&
                     two? <as && <<as = 'var && !(wrs? nm body))
                    (: v9 (vent g env <><as)               ; a homed/riding local: a read-only
                       (? (two? v9 && <v9 = 'regv && !(flo? <>>v9)) <>v9)))   ; reg holding the value
              al (? al (? (alsafe? g al) al ()) ())        ; staging must never write it
              (? (two? kb) (go >ps >as benv acc rbs ([nm kb] . sbs))
                 al (: _ (pin g 'rpin ((rp g al) . g 'rpin))   ; the alias bind: zero forms
                       (go >ps >as ([nm ['reg al] pty] . benv) acc rbs sbs))
                 (: r (cgexpr g env <as ())
                    (? (bad? r) 'bad
                       (pair? g pty)                          ; a pair param: an 8-byte slot, both words
                        (: off (ntmp g 'llong)
                           (go >ps >as ([nm off pty] . benv) (acc + asll g r + pst 'r4 off) rbs sbs))
                       (: rb (? (nocall && !(flo? pty) && pk? nm && deep? (g 'pool)) (ralloc g) ())
                          (? rb                              ; the park bind: the value rides a pool reg
                              (: _ (pin g 'rpin ((rp g rb) . g 'rpin))
                                 (go >ps >as ([nm ['reg rb] pty] . benv)
                                     (acc + asintt g r pty + [['mov rb 'r0]] + cvt pty rb)
                                     (rb . rbs) sbs))
                             (: off (ntmp g 'long)
                                vd (? (flo? (vty r) || (= pty 'bool) || (= (vreg r) 'r0)) () (vreg r))
                                (go >ps >as ([nm off pty] . benv)
                                    (? vd (: fs (acc + vfs r + [['st 'r4 off vd]]) _ (rfree g vd) fs)
                                       (acc + asintt g r pty
                                            + (pty @ 'bool (cvt pty 'r0))   ; the entry conversion the splice skips
                                            + [['st 'r4 off 'r0]]))
                                    rbs sbs)))))))))
       (go ps as () () () ()))
   ; does e certainly compute a double? a static peek for the branch lanes: a miss (a shape
   ; the peek does not read) keeps the discard lane, so it is never wrong, only incomplete
   (flo9? g env e)
    (e @ ('flo . _) 1
         ('var nm) (: en (vent g env nm) (two? en && flo? <>>en))
         ('cast ty . _) (flo? ty)
         ('call ('var nm) . _) (: sig (bad? (vent g env nm) ? (g 'sigs nm)) (two? sig && flo? <sig))
         ('bin o a b && elem o '(+ - * /)) (flo9? g env a || flo9? g env b)
         ('un 'neg x) (flo9? g env x)
         ('cond _ a b) (flo9? g env a || flo9? g env b)
         ('comma _ b) (flo9? g env b)
         ())
   ; the static type of a call head: an indirect call's arguments classify before the head
   ; evaluates, so the parameter types are read off the expression. a miss answers ()
   (hdty9 g env e)
    (e @ ('var nm) (: en (vent g env nm) (bad? en ? () <>>en))
         ('dot b f) (: bt (hdty9 g env b)
                       fm (stru? bt ? (fmem g bt f) 'bad)
                       (bad? fm ? () <>fm))
         ('deref x) (: it (hdty9 g env x)
                       (two? it && elem <it '(ptr arr) ? <>it ()))
         ('cast ty _) ty
         ; a[i] is *(a + i), so a table's element type reaches the deref through the sum's pointer operand
         ('bin o x y && (= o '+))
          (: a (hdty9 g env x)
             (two? a && elem <a '(ptr arr) ? a (hdty9 g env y)))
         ())
   (cbinl g env e cc lbl)
    (: head <>e args <>>e
       il0 (peep g 'inlining ())
       d0 (il0 || 0)
       inlf (? (2 < d0) ()                        ; nests to depth 3: no labels, so only recursion needs a cap
               !(<head = 'var) ()
               !(bad? (vent g env <>head)) ()     ; a local/global shadows the name
               (: c9 (g 'inl <>head)
                  (? (atom? c9) ()
                     (#args = #<>>c9) c9)))
       rx (two? inlf ? (retex inlf))
       e9 (two? rx ? <>rx)
       (? !(abit? e9) 'no
          (: fe0 (g 'fesc)
             strs0 (g 'strs)
             rp0 (g 'rpin)
             (anyc l) (? !(two? l) () (? (callish? <l) 1 (anyc >l)))
             nocall (!(callish? e9) && !(anyc args))
             _ (pin g 'inlining (d0 + 1))
             (dtmp ds benv9)                       ; the body's own decls: fresh temps over the params
              (? !(two? ds) benv9
                 (: d9 <ds (dtmp >ds ([<d9 (ntmp g <>d9) <>d9] . benv9))))
             br (sbind g env <>>inlf args nocall <><>>>inlf () (nm \ 1))   ; every park priced in: the body is one expression
             ib0 (peep g 'inlbody 0)
             _ (pin g 'inlbody (ib0 + 1))          ; the body blinds the alias bind (name conflation)
             bf (? (bad? br) 'bad (cbranch g (dtmp <rx <br) e9 cc lbl))
             _ (pins g 'inlbody ib0 'inlining il0 'rpin rp0) ; the bind pins die with the splice
             (unrb (a . u)) (rfree g a, unrb u)
             _ (two? br ? (unrb (br 2)))
             (? (bad? bf)
                 (pin g 'fesc fe0, pin g 'strs strs0, 'no)
                (!fe0 && g 'fesc)          ; the body took a frame address: keep the caller lean
                 (pin g 'fesc (), pin g 'strs strs0, 'no)
                (<>br + bf)))))
   ; (v & k) as a bare condition: test is flags-only, so the value's register survives (a mapped
   ; local stays mapped); the 'log gate is exactly test's immediate reach on each backend
   (tbr g env v k cc lbl)
    (: a (cgexpr g env v ())
       (? (bad? a || flo? (vty a)) 'bad
          (: fs (vfs a + [['test (vreg a) k] ['br cc lbl]])
             _ (rfree g (vreg a))
             fs)))
   ; branch on a condition without materializing it: jump to lbl when it is false (cc 'eq) or true
   ; (cc 'ne), the sense of `(cmp r0 0) (br cc lbl)`. fusions: cmp+br, !, &&/||, tbr, cbinl, fcb. forms | 'bad
   (cbranch g env e cc lbl)
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
            (: a (cgexpr g env lhs ())
               (? (bad? a) 'bad
                  (: af (asflo g a)
                     b (cgexpr g env rhs ())
                     (? (bad? b) 'bad
                        (: mid (fshut g af (asflo g b))
                           swp (elem op '(lt le))
                           cf [['ucomisd (? swp 'f0 'f1) (? swp 'f1 'f0)]]
                           ecc (? (arm? g)               ; VCMP/FCMP flags: gt/ge unordered-false native
                                  (: t9 (? (elem op '(lt gt)) 'gt (elem op '(le ge)) 'ge op)
                                     (cc @ 'ne t9 (negrel t9)))
                                  (elem op '(lt gt)) (cc @ 'ne 'above 'be)
                                  (elem op '(le ge)) (cc @ 'ne 'ae 'below))
                           (? ecc (mid + cf + [['br ecc lbl]])
                              (op = (cc @ 'ne 'ne 'eq))
                               (mid + cf + [['br 'p lbl] ['br 'ne lbl]])
                              (: sk (nlab g ".u")
                                 (mid + cf + [['br 'p sk] ['br 'eq lbl] ['label sk]]))))))))
           (bcc o u) (scc (cc @ 'ne o (negrel o)) u)
           ; a pair side (t32 llong) branches off subs/sbcs via pbrf; a constant or 32-bit
           ; other side widens to a pair in r2:r3
           (pnum v) [['li 'r2 (v & 4294967295)] ['li 'r3 (? (v < 0) 4294967295 0)]]
           ; a wide relation settles 0/1 through c128 (the left rides the cell), then branches on it
           (wbr o2 af u2) (af + ([['c128 (scc o2 u2) 'sp]] + (wdrop + ['(cmp r0 0) ['br cc lbl]])))
           (wnum v) [['li 'r0 v] ['li 'r2 (? (v < 0) -1 0)]]
           kr (knum g rhs)
           kl (knum g lhs)
           ; one side a cmp-immediate constant: x compares against k with x on the left (a constant
           ; left mirrors through rflip); a pair or wide x rides its own kit, a float re-fuses through fcb
           (kbr o k x)
            (: a (cgexpr g env x ())
               (? (bad? a) 'bad
                  (flo? (vty a)) (: _ (rfree g (vreg a)) (fcb ()))
                  (pair? g (vty a))
                   (vfs a + pnum <k + pbrf g o (usg? (vty a)) 'r0 'r1 'r2 'r3 cc lbl)
                  (d128? (vty a))
                   (? !(w128? g) (no128 g)
                      (wbr o (as128 g a + (wpush + wnum <k)) (= (vty a) 'u128)))
                  (: n <k
                     cc9 (bcc o (cmpu g (vty a) <>k))
                     ; a negative literal converts to the uint side (the masked pattern
                     ; will not sit in a signed immediate): materialize it
                     fs (? (u32? g (vty a) && (n < 0))
                           (: sc (? (= (vreg a) 'r1) 'r0 'r1)
                              (vfs a + [['li sc (n & 4294967295)] ['cmp (vreg a) sc] ['br cc9 lbl]]))
                           (vfs a + [['cmp (vreg a) n] ['br cc9 lbl]]))
                     _ (rfree g (vreg a))
                     fs)))
           (? (flo9? g env lhs || flo9? g env rhs) (fcb ())   ; a side the peek reads as double: fuse outright
              (two? kr && immok g 'cmp <kr) (kbr op kr lhs)
              (two? kl && immok g 'cmp <kl) (kbr (rflip op) kl rhs)
              ; the destination die: with no call in the way the left aims at its park before it
              ; evaluates; an unhonored hint (a mapped local, a float, a wide) hands the register back
              (: pk (? (callish? lhs || callish? rhs) () (ralloc g))
                 a (cgexpr g env lhs pk)
                 _ (? (pk && !(!(bad? a) && rpeq? g (vreg a) pk)) (rfree g pk) ())
                 (? (bad? a) 'bad
                    (flo? (vty a)) (: _ (rfree g (vreg a)) (fcb ()))
                    (: ah (? (callish? rhs || llt? (vty a) || d128? (vty a)) 'sh (vpark g env lhs a))           ; a call on the right / a pair left: memory only
                       (? (= ah 'sh)
                           (: pA (pair? g (vty a))
                              wA (d128? (vty a))
                              af0 (? (wA || pA) () (tor0 g a))
                              af (? wA (as128 g a + wpush)
                                    pA (asll g a + spush2)
                                    (af0 + spush 'r0))
                              b (cgexpr g env rhs ())
                              (? (bad? b) 'bad
                                 (flo? (vty b)) (? wA 'bad (: _ (rfree g (vreg b)) (fcb ())))
                                 (wA || d128? (vty b))                 ; a wide side: c128 over the cell
                                  (? !(w128? g) (no128 g)
                                     (: u2 (= (? (wA && d128? (vty b)) (wbin (vty a) (vty b))
                                                   wA (vty a) (vty b)) 'u128)
                                        ; a word left widens its cell hi by its own signedness
                                        fixa (? wA ()
                                                (usg? (vty a) || ptr? (vty a)) '((si sp 8 0))
                                                '((ld r1 sp 0) (sar r1 63) (st sp 8 r1)))
                                        (af + as128 g b + fixa +
                                         ([['c128 (scc op u2) 'sp]] + (wdrop + ['(cmp r0 0) ['br cc lbl]])))))
                                 (t32? g && (pA || llt? (vty b)))
                                  (: u2 (cmpu g (vty a) (vty b))
                                     (af + asll g b +
                                      (? pA (spop2 'r2 'r3 + pbrf g op u2 'r2 'r3 'r0 'r1 cc lbl)
                                         (spop 'r2
                                          + pwid (vty a) 'r2 'r3
                                          + pbrf g op u2 'r2 'r3 'r0 'r1 cc lbl))))
                                 (: bf (tor0 g b)
                                    ta9 (numty9 lhs (vty a)) tb9 (numty9 rhs (vty b))
                                    brf (znrw g ta9 tb9 'r1 'r0 +
                                         ['(cmp r1 r0) ['br (bcc op (cmpu g ta9 tb9)) lbl]])
                                    (shut1 g a af0 bf + brf))))
                          (: b (cgexpr g env rhs ())
                             (? (bad? b) 'bad
                                (flo? (vty b)) (: _ (rfree g (vreg ah)) _ (rfree g (vreg b)) (fcb ()))
                                (d128? (vty b))                       ; a word park against a wide right: build its cell
                                 (? !(w128? g) (no128 g)
                                    (: fs (vfs ah + vfs b
                                           + ['(sub sp sp 16) ['st 'sp 0 (vreg ah)]]
                                           + (? (usg? (vty ah) || ptr? (vty ah)) '((si sp 8 0))
                                                [['mov 'r1 (vreg ah)] '(sar r1 63) '(st sp 8 r1)])
                                           + ([['c128 (scc op (= (vty b) 'u128)) 'sp]] + (wdrop + ['(cmp r0 0) ['br cc lbl]])))
                                       _ (rfree g (vreg ah)) _ (rfree g (vreg b))
                                       fs))
                                (pair? g (vty b))                     ; a 32-bit park against a pair right: widen the park
                                 (: fs (vfs ah + vfs b
                                        + [['mov 'r2 (vreg ah)]]
                                        + pwid (vty ah) 'r2 'r3
                                        + pbrf g op (cmpu g (vty ah) (vty b)) 'r2 'r3 'r0 'r1 cc lbl)
                                    _ (rfree g (vreg ah)) _ (rfree g (vreg b))
                                    fs)
                                (: ta9 (numty9 lhs (vty ah)) tb9 (numty9 rhs (vty b))
                                   cc9 (bcc op (cmpu g ta9 tb9))
                                   ; the zx4 narrow cannot touch a home in place: copy
                                   ; through the staging pair (b first -- it may sit in r1)
                                   zn (znrw g ta9 tb9 'r1 'r0)
                                   fs (? (two? zn)
                                         (vfs ah + vfs b
                                          + [['mov 'r0 (vreg b)] ['mov 'r1 (vreg ah)]]
                                          + zn
                                          + ['(cmp r1 r0) ['br cc9 lbl]])
                                         (vfs ah + vfs b + [['cmp (vreg ah) (vreg b)] ['br cc9 lbl]]))
                                   _ (rfree g (vreg ah)) _ (rfree g (vreg b))
                                   fs)))))))))
       ; the mask-test shapes: (v & k) / (k & v). ms is syntax, so its found-test is
       ; structural (a `?` on a term would net it)
       (: ms (e @ ('bin . '& . ops) ops ())
          lhs (two? ms ? <ms)
          rhs (two? ms ? <>ms)
          kr (two? ms ? (knum g rhs))
          kl (two? ms ? (knum g lhs))
          try (? (<e = 'call) (cbinl g env e cc lbl)
                 !(two? ms) 'no
                 (two? kr && immok g 'log <kr) (tbr g env lhs <kr cc lbl)
                 (two? kl && immok g 'log <kl) (tbr g env rhs <kl cc lbl)
                 'no)
          (? !(= try 'no) try
             (: c (cgexpr g env e ())
                (? (bad? c) 'bad
                   (flo? (vty c))
                    ; a bare double condition is d != 0.0, NaN-honest: the parity dance rides the branch pair
                    (: fs (vfs c + (? (t32? g)               ; the zero pattern zeroes the r1:r2 pair
                                      '((li r1 0) (li r2 0) (movqxr f1 r1) (ucomisd f0 f1))
                                      '((li r1 0) (movqxr f1 r1) (ucomisd f0 f1))))
                       _ (rfree g (vreg c))
                       (? (arm? g) (fs + [['br cc lbl]])   ; VCMP/FCMP ne/eq are NaN-honest whole
                          (cc = 'ne) (fs + [['br 'p lbl] ['br 'ne lbl]])
                          (: sk (nlab g ".u")
                           (fs + [['br 'p sk] ['br 'eq lbl] ['label sk]]))))
                   (pair? g (vty c))                     ; pair truth: either word nonzero (v6-M: no r12 dest; r0 is dead past the branch)
                    (vfs c + [['ors (? (v6m? g) 'r0 'r12) 'r0 'r1] ['br cc lbl]])
                   (d128? (vty c))                       ; wide truth: either word nonzero
                    (vfs c + '((or r0 r0 r2) (cmp r0 0)) + [['br cc lbl]])
                   (: fs (vfs c + [['cmp (vreg c) 0] ['br cc lbl]])
                      _ (rfree g (vreg c))
                      fs))))))
   ; n little-endian bytes of a constant (the global initializer image)
   (les n v) (: (go i acc) (? (n <= i) (rev acc)
                              (go (i + 1) ((& (>> v (* 8 i)) 255) . acc)))
               (go 0 ()))
   (zeros n) (n >= 1 ? (0 . zeros (n - 1)))
   ; a straight-line block copy of sz bytes, src in r0, dest in r1, r2 the scratch
   (bcopy g off sz acc)                              ; a word at a time (8, 4 on t32), then a byte tail
    (: w (wsize g)
       (? (w <= sz) (bcopy g (off + w) (sz - w)
                     (acc + [['ld 'r2 'r0 off] ['st 'r1 off 'r2]]))
          (0 < sz) (bcopy g (off + 1) (sz - 1)
                     (acc + [['ld1 'r2 'r0 off] ['st1 'r1 off 'r2]]))
          acc))
   ; ..and its fill twin: dest address in r1, the splatted word in r2. a byte tail stores
   ; the low byte of the same register, which for a splat is the byte the caller asked for
   (bset g off sz acc)
    (: w (wsize g)
       (? (w <= sz) (bset g (off + w) (sz - w) (acc + [['st 'r1 off 'r2]]))
          (0 < sz) (bset g (off + 1) (sz - 1) (acc + [['st1 'r1 off 'r2]]))
          acc))
   ; memcpy/memset with a small constant size lay straight-line, by name (declining where a local
   ; shadows it or the fn is the library's own). no memmove: bcopy interleaves loads and stores
   (meminl g) (8 * wsize g)                          ; the widest expansion: 8 words either way
   (memk g e) (: k (knum g e) (? (two? k) <k (: v (cfold e) (cint? v ? v ()))))
   (memnm? bi nm) (bi = nm || bi = "__builtin_" + nm)
   (memok? g env bi args)                            ; may this call expand at all?
    ((3 = #args) && !(abl? g 'meminl) && (bad? (vent g env bi)) && !(g 'fn = bi))
   (cgmem g env bi args)                             ; -> the value | 'no (leave it a call)
    (? !(memok? g env bi args) 'no
       (: n9 (memk g (args 2))
          (? (!(charm? n9) || n9 < 0 || (meminl g) < n9) 'no
             (memnm? bi "memset")
              (: c9 (memk g <>args)
                 (? !(charm? c9) 'no
                    ; the destination is an argument, not an address the fn keeps: argpos,
                    ; the way a real call marks one, or every &local memset loses its sibcalls
                    (: dv (elem <<args '(addr var) ? (pin g 'argpos 1),
                           cgexpr g env <args ())
                       _ (pin g 'argpos ())
                       (? (bad? dv) 'bad
                          (: v9 ((c9 & 255) * (8 = wsize g ? 72340172838076673 16843009))
                             (mkv '(ptr void) 'r0 $
                              relean (tor0 g dv) + [['mov 'r1 'r0] ['li 'r2 v9]] +
                              bset g 0 n9 ()))))))
             (memnm? bi "memcpy")
              ; the destination parks in a pool seat, never on the machine stack (sp motion costs
              ; a musttail fn its tail); a pool seat cannot survive a call, so a callish arg declines
              (? (callish? <args || callish? <>args) 'no
                 (: dv (elem <<args '(addr var) ? (pin g 'argpos 1),
                        cgexpr g env <args ())
                    _ (pin g 'argpos ())
                    (? (bad? dv) 'bad
                       (: fd (tor0 g dv)
                          rd (ralloc g)
                          (? !rd 'no
                             (: sv (elem <<>args '(addr var) ? (pin g 'argpos 1),
                                    cgexpr g env <>args ())
                                _ (pin g 'argpos ())
                                _ (rfree g rd)
                                (? (bad? sv) 'bad
                                   (mkv '(ptr void) 'r0 $
                                    relean fd + [['mov rd 'r0]] + relean (tor0 g sv) +
                                    [['mov 'r1 rd]] + bcopy g 0 n9 () + '((mov r0 r1))))))))))
             'no)))
   ; a spill across a nested sub-eval (which may call): a bare 8-byte push would leave rsp at
   ; 8 mod 16 across the inner call, so a whole 16-byte cell
   (spush r) ['(sub sp sp 16) ['st 'sp 0 r]]
   (spop r)  [['ld r 'sp 0] '(add sp sp 16)]
   ; the shuttle skip: a right side whose forms never write r1 or touch sp may run with the left
   ; parked in r1, one mov in place of the push/pop
   (r1safe? g fs)
    (? !(two? fs) 1
       (: f <fs
          (? !(two? f) ()
             (: rd (rdsp g f)
                (? (= rd 'bar) ()
                   (elem 'r1 <>rd) ()
                   (elem 'sp <>rd) ()
                   (r1safe? g >fs))))))
   ; the pool cell: the left holds in a pool register across the right unless a call, an unknown
   ; op or a write of the candidate bars it; the write set reads resolved (this scan runs before vrfix)
   (psafe? g fs rz)
    (: r (rp g rz)
       (hit9 ds) (? !(two? ds) ()
                    (= (rp g <ds) r) 1
                    (hit9 >ds))
       (safe9 l)
        (? !(two? l) 1
           (: f <l
              (? !(two? f) (safe9 >l)
                 (elem <f '(label br jmp)) (safe9 >l)
                 (: rd (rdsp g f)
                    (? (= rd 'bar) ()
                       (hit9 <>rd) ()
                       (safe9 >l))))))
       (safe9 fs))
   ; a free pool register bf never writes -> r | (). a borrow, not an allocation: the span
   ; closes inside its own staging, so the free list keeps its order
   (spare g bf)
    (: (go l) (? !(two? l) ()
                 (elem <l (g 'rpin))
                  (scare 'spare-pinned <l)
                 (psafe? g bf <l) <l
                 (go >l))
       (go (g 'pool)))
   ; the shuttle: left in r1, right in r0 (af built before bf: the free order). a left in a
   ; register the right never writes reads through it; else the r1 skip, a pool cell, the sp cell last
   (shut1 g av af bf)
    (: rA (vreg av)
       (? (!(two? (vfs av)) && !(= rA 'r0) && psafe? g bf rA) (bf + [['mov 'r1 rA]])
          (r1safe? g bf) (af + '((mov r1 r0)) + bf)
          (: s (spare g bf)
             (? s (af + [['mov s 'r0]] + bf + [['mov 'r1 s]])
                (af + spush 'r0 + bf + spop 'r1)))))
   ; the double twin: left in f1, right in f0. the left's bits hold in a gp register across
   ; the right (movqrx aims straight at it); t32 moves the pair through the gp stack
   (fshut g af bf)
    (? (t32? g) (af + '((movqrx r0 f0)) + spush2 + bf + spop2 'r2 'r3 + '((movqxr f1 r2)))
       (: s (? (r1safe? g bf) 'r1 (spare g bf))
          (? s (af + [['movqrx s 'f0]] + bf + [['movqxr 'f1 s]])
             (af + '((movqrx r0 f0)) + spush 'r0 + bf + spop 'r1 + '((movqxr f1 r1))))))
   ; the count park: the value already in r0 holds in a pool register past the count's
   ; forms bf, then value r0 / count r1 (the variable shifts' and rotates' contract)
   (cshut g bf)
    (: s (spare g bf)
       (? s ([['mov s 'r0]] + bf + ['(mov r1 r0) ['mov 'r0 s]])
          (spush 'r0 + bf + '((mov r1 r0)) + spop 'r0)))

   ; the pair kit (t32 llong/ullong): a 64-bit value rides r0 (lo) : r1 (hi). pairs never enter
   ; the pool or the immediate lanes: every pair op runs the shuttle, r2:r3 the popped left, r12 the scratch
   (pair? g ty) (t32? g && llt? ty)
   (pwid ty lo hi) (usg? ty ? [['li hi 0]] [['mov hi lo] ['sar hi 31]])   ; widen lo into lo:hi by its source signedness
   (pwide ty) (pwid ty 'r0 'r1)                                              ; ..the protocol pair
   (asll g v) (llt? (vty v) ? (tor0 g v) (tor0 g v + pwide (vty v)))      ; land a pair on the protocol
   (spop2 ra rb) [['ld ra 'sp 0] ['ld rb 'sp 4] '(add sp sp 16)]
   ; pair load/store at base+off: a base of r0 loads hi first, so the low load may overwrite
   ; it; pst's base must never be r0/r1
   (pld base off) (= base 'r0 ? [['ld 'r1 base (off + 4)] ['ld 'r0 base off]]
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
   ; differences. v6-M has no r12-dest alu, so they land in la:lb: every caller's left pair must be dead past the compare
   (pcmpf g op la lb ra rb)
    (? (v6m? g)
     ([['subs la la ra] ['sbcs lb lb rb]] + (op @ ('eq || 'ne) [['ors la la lb]]))
     (['subs 'r12 la ra] . (op @ ('eq || 'ne) [['sbc la lb rb] ['ors 'r12 'r12 la]]
                                               [['sbcs 'r12 lb rb]])))
   ; a pair relation as (cc forms), operands lhs r2:r3 / rhs r0:r1 (the shuttle shape):
   ; gt/le compute the swapped difference and flip to lt/ge; signedness picks lt/below via scc.
   (prel g op unsg)
    (? (elem op '(eq ne)) [op (pcmpf g op 'r2 'r3 'r0 'r1)]
       (elem op '(lt ge)) [(scc op unsg) (pcmpf g op 'r2 'r3 'r0 'r1)]
       [(scc (? (op = 'gt) 'lt 'ge) unsg) (pcmpf g op 'r0 'r1 'r2 'r3)])
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
   ; llong -> double (VFP converts only through 32 bits): hi rides the U-converter scaled by 2^32,
   ; lo adds exactly, one rounding; the signed face negates the pair in and the double out. v6-M: one call
   (cvtlld g usg)
    (? (v6m? g)
       [['call (? usg '__aeabi_ul2d '__aeabi_l2d)] '(movqxr f0 r0)]
    (: lu (nlab g ".lu") ld (nlab g ".ld")
       u2d '((cvtui2sd f0 r1)
             (li r2 0) (li r3 1106247680) (movqxr f1 r2)   ; 2^32 (0x41F00000:0)
              (mulsd f0 f1)
              (cvtui2sd f1 r0) (addsd f0 f1))
       (? usg u2d                                    ; unsigned: straight through
          (['(cmp r1 0) ['br 'ge lu]
              '(li r2 0) '(li r3 0) '(subs r0 r2 r0) '(sbc r1 r3 r1)]
           + u2d
           + ['(li r2 0) '(li r3 0) '(movqxr f1 r2)           ; 0.0 - d
              '(subsd f1 f0) '(movsd f0 f1) ['jmp ld] ['label lu]]
           + u2d + [['label ld]]))))
   ; double -> llong, toward zero: peel sign/exponent, rebuild the 53-bit mantissa as a pair, shift
   ; it into place, refix the sign. |d| < 1 answers 0; out of range is UB. v6-M: one runtime call
   (cvtdll g usg)
    (? (v6m? g)
       ['(movqrx r0 f0) ['call (? usg '__aeabi_d2ulz '__aeabi_d2lz)]]
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
        + [['jmp ls] ['label lr] '(li r3 0) '(sub r2 r3 r2)]
        + pshiftv g 'shr
        + [['label ls] '(ld r2 sp 0) '(add sp sp 16)
           '(cmp r2 0) ['br 'eq ld]
           '(li r2 0) '(li r3 0) '(subs r0 r2 r0) '(sbc r1 r3 r1)
           ['label ld]])))

   ; the wide kit (i128/u128): hi r2 : lo r0, only on the r0 protocol (never the pool, an immediate
   ; lane or a home). a binop's left parks in a 16-byte sp cell that the carrying ops (a128/s128/m128/mw128/c128) read
   (d128? ty) (ty = 'i128 || ty = 'u128)
   (x64t? g) !(arm? g)
   (w128? g) (x64t? g || a64? g)             ; carries the wide pair: x64's rdx:rax, a64's x2:x0
   (rot4? g) (x64t? g || a64? g)             ; carries the rotate ops (ror4/rorv/rorv4); elsewhere the shifts stand
   (wbin ta tb) (? (d128? ta && d128? tb) (? (= ta 'u128 || (= tb 'u128)) 'u128 'i128)
                   (d128? ta) ta tb)                ; a word side converts to the wide side's type
   ; land a value on the wide protocol: a pair rides; a word widens by its source signedness
   (as128 g v) (? (d128? (vty v)) (tor0 g v)
                  (tor0 g v + (? (usg? (vty v) || ptr? (vty v)) '((li r2 0)) '((sx128)))))
   ; did this value's forms end in the zero-extend? (the widening-mul license: hi is 0)
   (zext128? fs) (: rl (rev fs) (two? rl && '(li r2 0) = <rl))
   ; a fresh n-byte frame cell -> its (negative) offset; every cell registers in g 'slots
   ; ((off n)..), the object map deadst and repack read (an lea escapes the whole object)
   (nslot g n) (: off -(peep g 'off 0 + n)
                  _ (pin g 'off (peep g 'off 0 + n))
                  _ (pin g 'slots ([off n] . g 'slots))
                  off)
   ; the object under a frame offset, off the slot map -- () when no cell claims it
   (obj9 sl x) (? !(charm? x) ()
                  (: (go l) (two? l ?
                             (: o <l (<o <= x && x < <o + <>o ? o (go >l))))
                     (go sl)))
   (ntmp g ty) (nslot g $ (tsz g ty + 7) & -8)
   ; the store-immediate op for (ty, k) | (), the vi fold's license (x64 only). st sign-extends
   ; imm32, the narrow forms truncate
   (fitsw? v) (-2147483648 <= v <= 4294967295)      ; sits in a 32-bit word under either signedness
   (sik sop k) (sop @ 'st  (fits32? k ? 'si)         ; the si twin of a gp store sop for k | ()
                     'st4 (fitsw? k ? 'si4)
                     'st2 (-32768 <= k <= 65535 ? 'si2)
                     'st1 (-128 <= k <= 255 ? 'si1))
   (siop9 ty k) (sik (stop ty) k)
   ; the value at an lvalue rec, by type (arrays and functions decay, a struct is its address);
   ; the scalar tail honors the want hint
   (loadval g r W9)                                 ; the mem face is consumed: one fused form, and
    (: ty (vty r) fs (vfs r)                        ;  the face's base register is freed here
       b (? (vm? r) (vmb r) 'r0) o (? (vm? r) (vmo r) 0)
       _ (rfree g b)
       (? (arr? ty) (mkv ['ptr <>ty] 'r0 (fs + mata b o))
          (gvarr? ty) (mkv ['ptr (varel ty)] 'r0 (fs + mata b o))   ; a VLA row decays to its address (p[i] a char*)
          (fn? ty) (mkv ['ptr ty] 'r0 (fs + mata b o))
          (stru? ty) (mkv ty 'r0 (fs + mata b o))    ; a struct value is its address (the pair reps read through it)
          (flo? ty) (mkv 'double 'r0 (fs + fldf ty 'f0 b o))
          (pair? g ty) (mkv ty 'r0 (fs + pld b o))
          (d128? ty) (mkv ty 'r0 (fs + [['ld 'r2 b (o + 8)] ['ld 'r0 b o]]))   ; hi first: the low load may overwrite the base
          (: W (W9 || 'r0)
             (mkv ty W (fs + [[(ldop ty) W b o]])))))
   ; the value at an lvalue rec: a bitfield loads its unit and extracts with two shifts (sar
   ; signed, shr unsigned), anything else loads flat
   (lvload g r wnt)
    (: ty (vty r)
       (? (bitf? ty)
           (: uty <>ty bitoff <>>ty width <>>>ty
              usz (tsz g uty) hi (64 - (bitoff + width)) lo (64 - width)
              sgn !(usg? uty || (= uty 'bool))         ; a bool field holds 0/1: never sign-extend
              b (? (vm? r) (vmb r) 'r0) o (? (vm? r) (vmo r) 0)
              _ (rfree g b)
              (mkv 'long 'r0
                   (vfs r
                    + [[(uldop usz) 'r0 b o]]
                    + (? (hi > 0) [['shl 'r0 hi]] ())
                    + (? (lo > 0) [[(? sgn 'sar 'shr) 'r0 lo]] ()))))
          (loadval g r wnt)))
   ; the fill code for a compound literal at frame offset off: an aggregate zeroes
   ; then fills (cgfill), a scalar unwraps its single-element brace and stores.
   (clitcode g env off ty ini)
    (? (arr? ty || stru? ty)
        (: f (cgfill g env off ty ini)
           (? (bad? f) 'bad (cgzero g off ((tsz g ty + 7) & -8) + f)))
       (: v (? (two? ini && <ini = 'init)
               (? (two? <>ini) <<>ini '(num 0)) ini)
          (cgstore g env off ty v)))

   ; lvalues: a mem-faced rec (pointee-ty (m base off) forms) | a plain rec with the address on r0
   ; (globals, clits) | 'bad. matv bridges for lanes wanting the address on r0
   (clval g env e)
    (e @
       ('var nm)
        (: en (vent g env nm)
           (? (bad? en) 'bad
              (elem <en '(regv regw)) 'bad   ; a register home has no address (& is gated out per-fn)
              (<en = 'loc) (mkm <>>en 'r4 <>en ())
              (mkv <>>en 'r0 [['la 'r0 <>en]])))
       ('deref X)
        ; frame-direct: a constant-indexed element is a static (r4, off) face
        (: fdc (afd g env e)
           (? (two? fdc) (mkm <>fdc 'r4 <fdc ())
              ; ptr ± const folds the scaled constant into the face's offset (p[1] is one load).
              ; static only: a var whose vent type is a plain pointer (a VLA pointee scales at runtime)
              (: pv (X @ ('bin op a b && elem op '(+ -))
                          (: ka (knum g a) kb (knum g b)
                             (? (two? kb && !(two? ka)) [a (op @ '+ <kb (0 - <kb))]
                                (two? ka && !(two? kb) && op = '+) [b <ka])))
                 pty (<pv @ ('var nm)
                            (: en (vent g env nm)
                               (? (two? en && elem <en '(loc regv glo) && ptr? <>>en &&
                                   !(gvarr? <>(<>>en)))
                                  <>>en)))
                 off9 (? pty (: d (* <>pv (tsz g <>pty))
                               (? (fits32? d) d 'no)) 'no)
                 (? (charm? off9)
                    (: r (cgexpr g env <pv ())
                       (? (bad? r) 'bad
                          (mkm <>pty (vreg r) off9 (vfs r))))
                    (: r (cgexpr g env X ())
                       (? (bad? r) 'bad
                          !(ptr? (vty r)) 'bad
                          ; the face keeps the pointer's own register (a home, a pin, a park --
                          ; the consumer reads through it and frees it); no bridge to r0
                          (mkm <>(vty r) (vreg r) 0 (vfs r))))))))
       ('dot base fld)
        (: r (: lv (clval g env base)
                ; an rvalue struct base (a call's parked temp: `mk(x).a`) is
                ; its address too -- same license the asn lane rides
                (? !(bad? lv) lv
                   (: rv (cgexpr g env base ())
                      (? (bad? rv) 'bad !(stru? (vty rv)) 'bad rv))))
           (? (bad? r) 'bad
              (: fm (fmem g (vty r) fld)
                 (? (bad? fm) (: _ (? (vm? r) (rfree g (vmb r)) ()) 'bad)
                    (vm? r) (mkm <>fm (vmb r) (vmo r + <fm) (vfs r))   ; the member folds into the face
                    (mkm <>fm 'r0 <fm (vfs r))))))
       ('clit ty ini)                            ; a compound literal is an lvalue: fill a temp, address it
        (: off (ntmp g ty)
           fill (clitcode g env off ty ini)
           (? (bad? fill) 'bad
              (mkv ty 'r0 (fill + [['lea 'r0 'r4 off]]))))   ; a real lea: the temp's address is the value
       ; gen's own lvalue, minted by the rmw lane and reachable from no source: the object whose
       ; address is moored at frame offset off (reading it is calm, so it evaluates once)
       ('moor off ty) (mkm ty 'r0 0 [['ld 'r0 'r4 off]])
       'bad)

   ; the static face of a store target -> (off ty) | (): afd, or a dot chain over a frame local whose
   ; clval face is (r4, off) with no emission. only a var/dot chain over a loc enters clval: any other base could emit
   (sfd g env e)
    (? (= <e 'deref) (afd g env e)
       !(= <e 'dot) ()
       (: (dotv? x) (x @ ('var nm) nm  ('dot . b . _) (dotv? b)  ())
          nm (dotv? e)
          (? !nm ()
             (: en (vent g env nm)
                (? !(two? en && (= <en 'loc)) ()
                   (: lv (clval g env e)
                      (? !(vm? lv) ()
                         !(= (vmb lv) 'r4) ()
                         (two? (vfs lv)) ()
                         (: ty (vty lv)
                            (? ((ptr? ty || elem ty '(char uchar bool short ushort int uint long ulong)) &&
                                !(pair? g ty))
                               [(vmo lv) ty] ())))))))))

   ; the gcc builtins love.c reaches: x64 as short raw splices, a64 as neutral IR or one raw word
   (cgbuiltin g env bi args)                       ; a builtin call -> its value | 'bad; not one -> 'no
    (?- 'no                                        ; "not a builtin" first: its clauses run 250 lines
       (elem bi '("__builtin_trap" "__builtin_unreachable"))
        ; unreachable rides the trap (gcc emits nothing and lets the fall-through run)
        (? (arm? g) (mkv 'long 'r0 '((trap)))
           (mkv 'long 'r0 '((ud2))))     ; the named op, not raw bytes: a raw bars unframe in every splice site
       (bi = "__builtin_inf")
        (? (t32? g) (mkv 'double 'r0 '((li r0 0) (li r1 2146435072) (movqxr f0 r0)))
           (mkv 'double 'r0 '((li r0 9218868437227405312) (movqxr f0 r0))))
       (bi = "__builtin_nanf" || bi = "__builtin_nan")   ; both take a (ignored) tag string; one quiet-NaN pattern
        (? (t32? g) (mkv 'double 'r0 '((li r0 0) (li r1 2146959360) (movqxr f0 r0)))
           (mkv 'double 'r0 '((li r0 9221120237041090560) (movqxr f0 r0))))
       (bi = "__builtin_expect") (cgexpr g env <args ())
       ; level 0 only. the return address sits one push slot above the frame base, so both answers
       ; want the link kept: fpin (a base slot is what unframe rewrites). wasm has no return address in linear memory
       (elem bi '("__builtin_return_address" "__builtin_frame_address"))
        (: lvl (? (two? args && two? <args && (= <<args 'num)) <><args 'no)
           fb (fbase g)
           ; one push slot above the base: a64/riscv pad each push to 16, x64's is 8
           w (? (t32? g) 4 (a64? g || rv64? g) 16 8)
           (? !(= lvl 0) (nolane g (bi + " above level 0" + ontgt g))
              (wasm? g && bi = "__builtin_return_address")
               (nolane g (bi + " -- no return address in linear memory" + ontgt g))
              (: _ (pin g 'fesc 1)
                 _ (pin g 'fpin 1)
                 (? (bi = "__builtin_frame_address") (mkv '(ptr void) 'r0 [['lean 'r0 fb 0]])
                    (mkv '(ptr void) 'r0 [['ld 'r0 fb w]])))))
       ; a prefetch is a hint: the address evaluates for its effects, the locality/rw operands are ignored
       (bi = "__builtin_prefetch") (cgexpr g env <args ())
       (bi = "__builtin___clear_cache")
        ; x86 keeps I-cache coherent: nothing. a64 does not (metal, not qemu-user): dc cvau per
        ; D-line, dsb, ic ivau per I-line, dsb+isb, strides off ctr_el0. scratch r2/r3/r9/r15 only: r10-r14 are the homes
        (? !(a64? g) (mkv 'long 'r0 ())
           (: e1 (cgexpr g env <args ())
              e2 (cgexpr g env <>args ())
              lb (nlab g ".ccd") db (nlab g ".ccdd")
              li9 (nlab g ".cci") di (nlab g ".ccid")
              (? (bad? e1 || bad? e2) 'bad
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
           ; the `l` spelling is as wide as the target's own long: 8 bytes everywhere but t32
           ll (? (bi = "__builtin_clz") () (bi = "__builtin_clzll") 1 !(t32? g))
           pre (? ll () '((shl r0 32)))    ; clz32(x) = clz64(x << 32) -- the shift also clears upper garbage
           (? (bad? e1) 'bad
              (t32? g && !ll)              ; clz32 is one word: clz / the runtime's __clzsi2
               (mkv 'long 'r0 (asint g e1 +
                  (? (v6m? g) '((call __clzsi2)) '((clz r0 r0)))))
              (t32? g)                     ; the pair: clz(hi), or 32 + clz(lo) when hi is 0
               (: lz (nlab g ".cz") ld (nlab g ".czd")
                  (mkv 'long 'r0 (asll g e1 +
                    (? (v6m? g)   ; no clz on v6-M: the runtime's __clzsi2 (arg/result r0)
                       ['(cmp r1 0) ['br 'eq lz] '(mov r0 r1) '(call __clzsi2) ['jmp ld]
                          ['label lz] '(call __clzsi2) '(add r0 r0 32) ['label ld]]
                       ['(cmp r1 0) ['br 'eq lz] '(clz r0 r1) ['jmp ld]
                          ['label lz] '(clz r0 r0) '(add r0 r0 32) ['label ld]]))))
              (rv64? g)                      ; no clz in rv64i: the 6-stage binary search (branchy; clz(0) stays UB)
               (: ls (map (\ k (nlab g ".cz")) '(0 1 2 3 4 5))
                  step (\ kk lb2 ['(mov r2 r0) ['shr 'r2 (64 - kk)] '(cmp r2 0) ['br 'ne lb2]
                                   ['add 'r1 'r1 kk] ['shl 'r0 kk] ['label lb2]])
                  (mkv 'long 'r0 (asint g e1 + pre +
                    ('((li r1 0))
                     + step 32 (ls 0) + step 16 (ls 1) + step 8 (ls 2)
                     + step 4 (ls 3) + step 2 (ls 4) + step 1 (ls 5)
                     + '((mov r0 r1))))))
              (mkv 'long 'r0 (asint g e1 + pre +
                              (? (a64? g) '((raw (0 16 192 218)))                    ; clz x0, x0
                                 '((raw (72 15 189 192 72 131 240 63))))))))   ; bsr rax,rax; xor rax,63
       ; count trailing zeros (ctz(0) stays UB; the 32-bit spelling's upper garbage is harmless):
       ; x64 bsf, a64 rbit+clz, rv a mask-narrowing search, t32 isolate-and-clz
       (elem bi '("__builtin_ctzll" "__builtin_ctzl" "__builtin_ctz"))
        (: e1 (cgexpr g env <args ())
           ll (? (bi = "__builtin_ctz") () (bi = "__builtin_ctzll") 1 !(t32? g))
           (? (bad? e1) 'bad
              (ll && t32? g) (nolane g ("no lane for " + bi + (ontgt g)))   ; the pair lane, again
              (t32? g)
               (mkv 'long 'r0 (asint g e1 +
                  (? (v6m? g) '((call __ctzsi2))
                     '((li r1 0) (sub r1 r1 r0) (and r0 r0 r1)     ; x & -x, then 31 - clz
                        (clz r0 r0) (li r1 31) (sub r0 r1 r0)))))
              (rv64? g)
               (: ls (map (\ k (nlab g ".tz")) '(0 1 2 3 4 5))
                  step (\ kk mk lb2 [['li 'r3 mk] '(mov r2 r0) '(and r2 r2 r3) '(cmp r2 0)
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
                                 '((raw (72 15 188 192))))))))                ; bsf rax,rax -- REX.W, so it serves both widths
       ; the bswap trio: masked neutral shift/or expansions (no raw, so unframe stays alive).
       ; 16/32 ride every target; 64 refuses on t32 (a pair lane with no taker)
       (elem bi '("__builtin_bswap16" "__builtin_bswap32" "__builtin_bswap64"))
        (? ((bi = "__builtin_bswap64") && t32? g)
            (nolane g ("no lane for __builtin_bswap64" + ontgt g))   ; 'no would emit a call the link cannot bind
           (: e1 (cgexpr g env <args ())
              (? (bad? e1) 'bad
                 (mkv 'long 'r0 (asint g e1 +
                   (? (bi = "__builtin_bswap16")
                      '((li r2 255) (mov r1 r0) (shr r1 8) (and r1 r1 r2)
                        (and r0 r0 r2) (shl r0 8) (or r0 r0 r1))
                      (bi = "__builtin_bswap32")
                      '((li r2 255)
                        (mov r1 r0) (shr r1 24) (and r1 r1 r2)
                        (mov r3 r0) (shr r3 16) (and r3 r3 r2) (shl r3 8) (or r1 r1 r3)
                        (mov r3 r0) (shr r3 8) (and r3 r3 r2) (shl r3 16) (or r1 r1 r3)
                        (and r0 r0 r2) (shl r0 24) (or r0 r0 r1))
                      '((li r2 71777214294589695)                  ; 0x00ff00ff00ff00ff
                        (mov r1 r0) (shr r1 8) (and r1 r1 r2)
                        (and r0 r0 r2) (shl r0 8) (or r0 r0 r1)
                        (li r2 281470681808895)                    ; 0x0000ffff0000ffff
                        (mov r1 r0) (shr r1 16) (and r1 r1 r2)
                        (and r0 r0 r2) (shl r0 16) (or r0 r0 r1)
                        (mov r1 r0) (shr r1 32) (shl r0 32) (or r0 r0 r1))))))))
       ; popcount, the swar fold: masks and adds only, so it rides every target. the 64-bit forms
       ; refuse on t32; the 32-bit form masks first (the word above bit 31 may carry garbage)
       (elem bi '("__builtin_popcount" "__builtin_popcountl" "__builtin_popcountll"))
        (? ((bi != "__builtin_popcount") && t32? g)
            (nolane g ("no lane for " + bi + ontgt g))
           (: e1 (cgexpr g env <args ())
              w32 (bi = "__builtin_popcount" || t32? g)
              fold (\ k ['(mov r1 r0) ['shr 'r1 k] '(add r0 r0 r1)])
              ; each arm parenthesized: a bare `+` inside a clause arm would capture the rest of the clause
              w32ops ((? (t32? g) () '((li r2 4294967295) (and r0 r0 r2)))   ; the word above bit 31 is not ours to count
                      + '((li r2 1431655765) (mov r1 r0) (shr r1 1) (and r1 r1 r2) (sub r0 r0 r1)
                          (li r2 858993459) (mov r1 r0) (shr r1 2) (and r1 r1 r2) (and r0 r0 r2) (add r0 r0 r1)
                          (li r2 252645135) (mov r1 r0) (shr r1 4) (add r0 r0 r1) (and r0 r0 r2))
                      + (fold 8) + (fold 16) + '((li r2 63) (and r0 r0 r2)))
              w64ops ('((li r2 6148914691236517205) (mov r1 r0) (shr r1 1) (and r1 r1 r2) (sub r0 r0 r1)
                        (li r2 3689348814741910323) (mov r1 r0) (shr r1 2) (and r1 r1 r2) (and r0 r0 r2) (add r0 r0 r1)
                        (li r2 1085102592571150095) (mov r1 r0) (shr r1 4) (add r0 r0 r1) (and r0 r0 r2))
                      + (fold 8) + (fold 16) + (fold 32) + '((li r2 127) (and r0 r0 r2)))
              (? (bad? e1) 'bad
                 (mkv 'long 'r0 (asint g e1 + (w32 ? w32ops w64ops))))))
       ; the __sync spin-lock pair: test_and_set is the acquire exchange (xchg / ldaxr+stxr / amoswap.aq),
       ; release a release-ordered store of 0. the pointee sizes the exchange (4/8); an unsized one refuses
       (elem bi '("__sync_lock_test_and_set" "__sync_lock_release"))
        (: e1 (cgexpr g env <args ())
           pt (two? (vty e1) && <(vty e1) = 'ptr ? <>(vty e1))
           w (? (elem pt '(int uint)) 4
                (ptr? pt || elem pt '(long ulong)) 8 ())
           (? (t32? g) (nolane g (("no lane for " + bi) + ontgt g))
              (bad? e1) 'bad
              !w (nolane g (bi + " wants an int* or a long*/T** (the pointee sizes the exchange)"))
              (bi = "__sync_lock_release")
               (mkv 'long 'r0 (tor0 g e1 +
                 '((mov r1 r0) (li r0 0)) +
                 (? (a64? g) [['raw (w @ 4 '(32 252 159 136) '(32 252 159 200))]]   ; stlr w0/x0, [x1]
                    (rv64? g) ('((raw (15 0 16 3))) +                                       ; fence rw,w
                             [[(? (w = 4) 'st4 'st) 'r1 0 'r0]])
                    [[(w @ 4 'st4 'st) 'r1 0 'r0]])))
              (: e2 (cgexpr g env <>args ())
                 (? (bad? e2) 'bad
                    (: pre (tor0 g e1 + spush 'r0 + asint g e2 + spop 'r1)   ; val r0, ptr r1
                       body (? (a64? g)
                               (: lb (nlab g ".ts")
                                  [['label lb]
                                   ['raw (w @ 4 '(34 252 95 136) '(34 252 95 200))]   ; ldaxr w2/x2, [x1]
                                   ['raw (w @ 4 '(32 124 3 136) '(32 124 3 200))]     ; stxr w3, w0/x0, [x1]
                                   '(cmp r3 0) ['br 'ne lb] '(mov r0 r2)])
                              (rv64? g)
                               [['raw (w @ 4 '(47 165 165 12) '(47 181 165 12))]]      ; amoswap.w/d.aq a0,a0,(a1)
                              [['raw (w @ 4 '(135 1) '(72 135 1))]])                   ; xchg eax/rax, (rcx)
                       (mkv pt 'r0 (pre + body + cvt pt 'r0)))))))
       (bi = "__builtin_isinf")
        (: e1 (cgexpr g env <args ())
           (? (bad? e1) 'bad
              (mkv 'long 'r0 (asflo g e1 +
                        (? (v6m? g)                 ; the r12-free twin: the diffs land in r1 (dead past the set)
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
                           (+ '((movqrx r0 f0) (raw (72 209 224)) (li r1 18437736874454810624))   ; shl rax,1; rcx = inf<<1
                              '((raw (72 57 200 15 148 192 72 15 182 192)))))))))     ; cmp; sete al; movzx rax,al
       (elem bi '("__builtin_add_overflow" "__builtin_sub_overflow" "__builtin_mul_overflow"))
        (: e1 (cgexpr g env <args ())
           e2 (cgexpr g env <>args ())
           ; the &t arg is consumed by the splice's own store -- argpos,
           ; like a call arg (else every overflow user loses sibcalls)
           e3 (elem <<>>args '(addr var) ? (pin g 'argpos 1),
               cgexpr g env <>>args ())
           _ (pin g 'argpos ())
           opb (? (bi = "__builtin_add_overflow") '(72 1 200)      ; add rax,rcx
                  (bi = "__builtin_sub_overflow") '(72 41 200)     ; sub rax,rcx
                  '(72 15 175 193))                                ; imul rax,rcx
           ; the op leaves r0 the result, r1 the overflow bit
           ovf (? !(arm? g)
                  [['raw (opb + '(15 144 193 72 15 182 201))]]          ; op; seto cl; movzx rcx,cl
                  !(bi = "__builtin_mul_overflow")
                   [[(bi @ "__builtin_add_overflow" 'adds 'subs) 'r0 'r0 'r1] '(set vs r1)]
                  (v6m? g)                          ; no smull: sign-widen both words through __aeabi_lmul,
                   (spush 'r3 +                     ; then hi vs lo>>31. r3 = the &t address -- saved around the call
                    '((mov r2 r1) (mov r1 r0) (sar r1 31)
                      (mov r3 r2) (sar r3 31) (call __aeabi_lmul)
                      (mov r2 r0) (sar r2 31) (subs r1 r1 r2) (set ne r1)) +
                    spop 'r3)
                  (t32? g)                          ; smull, then hi vs lo>>31 (no 64-bit regs)
                   '((smull r0 r2 r0 r1) (mov r12 r0) (sar r12 31)
                      (subs r1 r2 r12) (set ne r1))
                  (: lo (nlab g ".vo") l2 (nlab g ".vd")
                     [['mulo 'r0 'r0 'r1 'r2 lo] '(li r1 0) ['jmp l2]
                        ['label lo] '(li r1 1) ['label l2]]))
           ; &t's frame lea must not open the sibs window: a64's neutral IR is no call boundary,
           ; so the address reads lean there; x64's raw splice resets it (IR untouched)
           e3f (? (arm? g) (relean (tor0 g e3)) (tor0 g e3))
           (? (bad? e1 || bad? e2 || bad? e3) 'bad
              (mkv 'long 'r0 $
               asint g e1 + spush 'r0 + asint g e2 + spush 'r0 +
               e3f + '((mov r3 r0)) + spop 'r1 + spop 'r0 + ovf +
               '((st r3 0 r0) (mov r0 r1)))))
       ; the block moves last in the chain: every __builtin_ clause gets first refusal, and an
       ; ordinary call pays one byte compare to reach the roster
       ((0 < #bi) && (bi 0) = 109) (cgmem g env bi args)
       (elem bi '("__builtin_memcpy" "__builtin_memset")) (cgmem g env bi args))

   ; expressions: a value tuple | 'bad. wnt is the destination hint, advisory: a consumer that
   ; knows where the value must land passes it, and a lane that ignores it answers its usual register
   (cgexpr g env e wnt)
    (e @- 'bad                                      ; the refusal, up front: its clauses run 600 lines
       ('szof e2)                                   ; sizeof EXPR: the undecayed type (clval keeps arrays), size a constant
        (: ty (peekty g env e2)
           (? (bad? ty) 'bad
              (gvarr? ty && 3 < #ty)   ; sizeof a VLA local: the stashed byte size
               (: sl (g 'vslots (varix ty))
                  (? !(two? sl) 'bad (mkv 'ulong 'r0 [['ld 'r0 'r4 <>sl]])))
              (mkv 'ulong 'r0 [['li 'r0 (tsz g ty)]])))
       ('num v)
        (? (t32? g && !(fitsw? v))
           ; a literal past the 32-bit word: the pair (C99 decimal picks long long), split by
           ; // and % -- a big literal has no bitwise ops
           (: u (v < 0 ? (v + 18446744073709551616) v)
              (mkv (v < 0 ? 'llong 'ullong) 'r0
                   [['li 'r0 (u % 4294967296)] ['li 'r1 (u // 4294967296)]]))
           (t32? g && 2147483647 < v)
           ; bit 31 set on the 32-bit word: unsigned (0xffffffff reads uint), so a
           ; pair-widen zero-extends: 'ulong, not 'long
           (: W (wnt || 'r0) (mkv 'ulong W [['li W v]]))
           (w128? g && !(-9223372036854775808 <= v <= 18446744073709551615))
           ; a literal past the word: the wide pair, split by // and % (a big has no bitwise ops)
           (: u ((v < 0 ? (v + 64 2 * 64 2) v) % (64 2 * 64 2))
              (mkv 'u128 'r0
                   [['li 'r0 (u % 18446744073709551616)]
                    ['li 'r2 (u // 18446744073709551616)]]))
           (: W (wnt || 'r0) (mkv 'long W [['li W v]])))
       ('flo d) (mkflo g d)
       ('str s)
        (: lbl (nlab g ".S")
           _ (pin g 'strs ([lbl s] . g 'strs))
           (mkv '(ptr char) 'r0 [['la 'r0 lbl]]))
       (('dot || 'moor) . _)
        (: r (clval g env e)
           (? (bad? r) 'bad (lvload g r wnt)))
       ('var nm)
        (: en (vent g env nm)
           (? (bad? en)
               (? (g 'fns nm)     ; a function name is its address
                  (mkv ['ptr (fnty g nm)] 'r0 [['la 'r0 (name nm)]])
                  (: _ (pin g 'undecl nm) 'bad))   ; undeclared: name it for the gripe (an undeclared call's head lands here too)
              (<en = 'regv) (mkv <>>en <>en ())   ; a homed param is its register: zero forms, borrowed (read-only)
              (<en = 'regw)                       ; a pair-homed d128 materializes onto the protocol (hi first)
               (mkv <>>en 'r0 [['mov 'r2 <><>en] ['mov 'r0 <<>en]])
              (: ty <>>en
                 ap? (g 'argpos)
                 _ (? (stru? ty || arr? ty) (pin g 'argpos ()) ())
                 (? (stru? ty)                    ; a struct value is its address (the sse2 rep)
                     (? (<en = 'loc)
                        (: v (mkv ty 'r0 [['lea 'r0 'r4 <>en]]) (? ap? v (escan g v)))
                        (mkv ty 'r0 [['la 'r0 <>en]]))
                    (arr? ty)                     ; arrays decay to their address
                     (? (<en = 'loc)
                        (: v (mkv ['ptr <>ty] 'r0 [['lea 'r0 'r4 <>en]]) (? ap? v (escan g v)))
                        (mkv ['ptr <>ty] 'r0 [['la 'r0 <>en]]))
                    (gvarr? ty)                   ; a VLA local: its slot holds the block pointer
                     (? (<en = 'loc)
                        (mkv ['ptr (varel ty)] 'r0 [['ld 'r0 'r4 <>en]])
                        'bad)
                    (flo? ty)                     ; a float/double loads into f0 (widened if float)
                     (mkv 'double 'r0 (atstat en 'r1 (fldf ty 'f0)))
                    (pair? g ty)                    ; a pair reads both words (the address temp dodges
                     (mkv ty 'r0 (atstat en 'r2 pld))   ;  r1 -- it is the pair's own high half)
                    (d128? ty)                      ; a wide value reads both words (r1 the address
                     (? !(w128? g) (no128 g)        ;  temp -- clear of the pair's own halves)
                        (mkv ty 'r0 (atstat en 'r1 (b \ o \ [['ld 'r0 b o] ['ld 'r2 b (o + 8)]]))))
                    (: W (? (<en = 'loc && wnt) wnt 'r0)   ; a slot load lands on the hint
                       (mkv ty W (atstat en 'r1 (b \ o \ [[(ldop ty) W b o]]))))))))
       ('addr lv)
        (: r (clval g env lv)
           ap? (g 'argpos)
           _ (pin g 'argpos ())
           (? (!(bad? r) && bitf? (vty r)) 'bad   ; &bitfield is illegal C -- refuse
              !(bad? r)                        ; under & the lvalue's address escapes: a real lea, so the gate sees it
              (: fs (? (vm? r) (vfs r + unlean (mata (vmb r) (vmo r)))
                        (unlean (vfs r)))
                 _ (? (vm? r) (rfree g (vmb r)) ())
                 v (mkv ['ptr (vty r)] 'r0 fs)
                 (? ap? v (escan g v)))
              ; &f on a function name: the address, unless a variable of that name shadows it (the vent test)
              (<lv = 'var && bad? (vent g env <>lv) && g 'fns <>lv)
               (mkv ['ptr (fnty g <>lv)] 'r0 [['la 'r0 (name <>lv)]])
              'bad))
       ('deref . _)
        (: r (clval g env e)                  ; clval already walked the pointer
           (? (bad? r) 'bad (loadval g r wnt)))
       ('asn dst rhs)
        (: rv (? (<dst = 'var) (vent g env <>dst) 'bad)
           fd (sfd g env dst)
           (? (two? rv && <rv = 'regv)   ; store into a register-homed scalar (param or local)
               (: r (cgexpr g env rhs <>rv)   ; the rhs aims straight at the home
                  (? (bad? r) 'bad
                     (flo? (vty r)) (mkv <>>rv 'r0 (asintt g r <>>rv + ([['mov <>rv 'r0]] + cvt <>>rv <>rv)))
                     (= (vreg r) <>rv) (mkv <>>rv <>rv ((vfs r) + cvt <>>rv <>rv))   ; landed in the home already (re-narrowed)
                     (: fs (vfs r + ([['mov <>rv (vreg r)]] + cvt <>>rv <>rv))   ; straight from the value's register
                        _ (rfree g (vreg r))
                        (mkv <>>rv <>rv fs))))
              (two? rv && <rv = 'regw)     ; store into a pair-homed d128: land on the protocol, mov both halves
               (: r (cgexpr g env rhs ())
                (bad? r ? 'bad
                 (mkv <>>rv 'r0 (as128 g r + [['mov <<>rv 'r0] ['mov <><>rv 'r2]]))))
              ; store-direct: a plain variable's address is static, so the value stores from where it sits
              (two? rv && elem <rv '(loc glo) &&
                  (: ty9 <>>rv !(stru? ty9 || arr? ty9 || flo? ty9)))
               (: ty <>>rv
                  nm <>dst
                  r (cgexpr g env rhs ())
                  (? (bad? r) 'bad
                     (pair? g ty)                     ; a pair target stores both words (r2 the address
                      (mkv ty 'r0 (asll g r + atstat rv 'r2 pst))   ;  temp -- r1 is the pair's own high half)
                     (d128? ty)                       ; a wide target stores both words (r1 the address temp)
                      (? !(w128? g) (no128 g)
                       (mkv ty 'r0 (as128 g r + atstat rv 'r1 (b \ o \ [['st b o 'r0] ['st b (o + 8) 'r2]]))))
                     ; a double source truncates first (the lane below would store the raw bits);
                     ; a narrow target converts on the protocol -- asintt is tor0 on a non-float
                     (flo? (vty r) || two? (cvt ty 'r0))
                      (mkv ty 'r0 (asintt g r ty + cvt ty 'r0 + atstat rv 'r1 (b \ o \ [[(stop ty) b o 'r0]])))
                     (mkv ty (vreg r) (vfs r + atstat rv 'r1 (b \ o \ [['st b o (vreg r)]])))))
              ; frame-direct (store-direct's element twin): the slot is static, so no address park, even past a call on the right
              (two? fd)
               (: off <fd ty <>fd
                  r (cgexpr g env rhs ())
                  (? (bad? r) 'bad
                     ; a register-riding value stores itself (no r0 bridge)
                     (? (!(flo? (vty r)) && atom? (cvt ty 'r0) && vreg r != 'r0)
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
                  rl (matv g (clval g env rhs))   ; an rvalue struct (a call's temp) is its address too
                  rv (? (bad? rl) (cgexpr g env rhs ()) rl)
                  (? (bad? rv) 'bad
                     ; a real into a complex lvalue converts: re the value, im zero
                     (gcplx? (vty lv) && !(stru? (vty rv)))
                      (: b (cxb (vty lv))
                         (mkv (vty lv) 'r0
                            (vfs lv + spush 'r0 +
                             (asflo g rv + spop 'r1 + fstf g b 'r1 0 'f0
                              + '((li r2 0))
                              + (b @ 'float '((st4 r1 4 r2)) '((st r1 8 r2)))))))
                     !(stru? (vty rv)) 'bad
                     (mkv (vty lv) 'r0 $
                        vfs lv + spush 'r0 + tor0 g rv + spop 'r1 +
                          ; a complex width flip converts componentwise; else bytes
                          (? (gcplx? (vty lv) && gcplx? (vty rv) &&
                              !(<>(vty lv) = <>(vty rv)))
                             (cxcopy g (vty rv))
                             (bcopy g 0 (tsz g (vty lv)) ())))))
              (flo? (vty lv0))                     ; a float/double store (value in f0; narrow if float)
               (? fdd
                  (: b (vmb lv0) o (vmo lv0)      ; the face is the address: fstf reads through it
                     r (cgexpr g env rhs ())
                     (? (bad? r) (: _ (rfree g b) 'bad)
                        (: fs (vfs lv0 + asflo g r + fstf g (vty lv0) b o 'f0)
                           _ (rfree g b)
                           (mkv 'double 'r0 fs))))
                  (: lv (matv g lv0)
                     r (cgexpr g env rhs ())
                     (? (bad? r) 'bad
                        (mkv 'double 'r0 (vfs lv + spush 'r0 +
                         (asflo g r + spop 'r1 + fstf g (vty lv) 'r1 0 'f0))))))
              (bitf? (vty lv0))                   ; a bitfield store: unit addr in r1, read-modify-write, result (truncated) in r0
               (: lv (matv g lv0)
                  r (cgexpr g env rhs ())
                  (? (bad? r) 'bad
                     (: bt (vty lv) uty <>bt bitoff <>>bt width <>>>bt
                        usz (tsz g uty)
                        mask ((1 << width) - 1) mv (mask << bitoff) cmask ((0 - mv) - 1)
                        sgn !(usg? uty || (= uty 'bool)) lo (64 - width)
                        (mkv 'long 'r0
                           (vfs lv + spush 'r0
                            + asintt g r uty
                            + (? (= uty 'bool) (cvt uty 'r0) ())   ; normalize before the mask ((bool)4 is 1)
                            + spop 'r1
                            + [[(uldop usz) 'r2 'r1 0]              ; r2 = the unit
                                ['li 'r3 mask] '(and r0 r0 r3)       ; r0 = v & mask (the truncated value)
                                ['li 'r3 cmask] '(and r2 r2 r3)      ; clear the field's bits
                                '(mov r3 r0)]
                            + (? (bitoff > 0) [['shl 'r3 bitoff]] ())   ; r3 = (v & mask) << bitoff
                            + ['(or r2 r2 r3) [(stop uty) 'r1 0 'r2]]
                            + (? sgn [['shl 'r0 lo] ['sar 'r0 lo]] ()))))))
              (pair? g (vty lv0))                 ; a pair store through a computed address
               (: lv (matv g lv0)
                  r (cgexpr g env rhs ())
                  (? (bad? r) 'bad
                     (mkv (vty lv) 'r0
                      (vfs lv + spush 'r0 + asll g r + spop 'r2 + pst 'r2 0))))
              (d128? (vty lv0))                   ; a wide store through a computed address (r1)
               (? !(w128? g) (no128 g)
                  (: lv (matv g lv0)
                     r (cgexpr g env rhs ())
                     (? (bad? r) 'bad
                        (mkv (vty lv) 'r0 (vfs lv + spush 'r0 +
                         as128 g r + spop 'r1 + '((st r1 0 r0) (st r1 8 r2)))))))
              ; face-direct: the store reads through the face's own base, no address park
              fdd
               (: b (vmb lv0) o (vmo lv0)
                  ty (vty lv0)
                  r (cgexpr g env rhs ())
                  (? (bad? r) (: _ (rfree g b) 'bad)
                     (? (!(flo? (vty r)) && !(two? (cvt ty 'r0)) &&
                         !(= (vreg r) 'r0) && !(rpeq? g (vreg r) b))
                        (: fs (vfs lv0 + vfs r + [[(stop ty) b o (vreg r)]])
                           _ (rfree g b)
                           (mkv ty (vreg r) fs))
                        (: fs (vfs lv0 + asintt g r ty + cvt ty 'r0 +
                               [[(stop ty) b o 'r0]])
                           _ (rfree g b)
                           (mkv ty 'r0 fs)))))
              ; the address parks in a pool register past a call-free rhs; a call on the right would clobber the park, so it keeps the shuttle
              (: lv (matv g lv0)
                 aR (? (callish? rhs) () (ralloc g))
                 r (cgexpr g env rhs ())
                 (? (bad? r) (: _ (? aR (rfree g aR) ()) 'bad)
                    (: ty (vty lv)
                       (? aR
                          ; a register-riding value stores itself (no r0 bridge)
                          (? (!(flo? (vty r)) && !(two? (cvt ty 'r0)) &&
                              !(= (vreg r) 'r0) && !(rpeq? g (vreg r) aR))
                             (: fs (vfs lv +
                                    [['mov aR 'r0]] +
                                    vfs r +
                                    [[(stop ty) aR 0 (vreg r)]])
                                _ (rfree g aR)
                                (mkv ty (vreg r) fs))
                             (: fs (vfs lv +
                                    [['mov aR 'r0]] +
                                    asintt g r ty +
                                    cvt ty 'r0 +
                                    [[(stop ty) aR 0 'r0]])
                                _ (rfree g aR)
                                (mkv ty 'r0 fs)))
                          (mkv ty 'r0
                           (vfs lv + spush 'r0 + asintt g r ty + spop 'r1 +
                            cvt ty 'r0 + [[(stop ty) 'r1 0 'r0]]))))))))))
       ('post dst step)
        (: rv (<dst = 'var ? (vent g env <>dst) 'bad)
           fd (sfd g env dst)
           (? (two? rv && <rv = 'regv)   ; p++ on a register-homed scalar: old in r0, home += step
               (: ty <>>rv stp (ptr? ty ? (tsz g <>ty) 1)
                  (mkv ty 'r0 ([['mov 'r0 <>rv]
                                ['add <>rv <>rv (stp * step)]] + cvt ty <>rv)))
              ; store-direct (the asn twin): a direct frame ld+st leaves no lean, so the local can still home
              (two? rv && <rv = 'loc &&
               (: t9 <>>rv !(stru? t9 || arr? t9 || flo? t9 || bitf? t9)))
               (: ty <>>rv off <>rv stp (? (ptr? ty) (tsz g <>ty) 1)
                  (? (pair? g ty)
                     (mkv ty 'r0 (pld 'r4 off + ppost 'r4 off (* stp step)))
                     (d128? ty)                   ; wide ++/--: step in place, store, step back (the
                      (? !(w128? g) (no128 g)     ;  answer is the old pair, and the carry ops are in-place)
                         (mkv ty 'r0 [['ld 'r0 'r4 off] ['ld 'r2 'r4 (off + 8)]
                                       [(step < 0 ? 'dec128 'inc128)]
                                       ['st 'r4 off 'r0] ['st 'r4 (off + 8) 'r2]
                                       [(step < 0 ? 'inc128 'dec128)]]))
                     (mkv ty 'r0 ([[(ldop ty) 'r0 'r4 off]
                                    ['add 'r1 'r0 (stp * step)]]
                                  + (ty @ 'bool (cvt ty 'r1))   ; b++/b-- lands on 0/1
                                  + [[(stop ty) 'r4 off 'r1]]))))
              ; frame-direct element ++/-- (the store-direct twin; pair/d128 stay on afd's far side)
              (two? fd)
               (: ty <>fd off <fd stp (? (ptr? ty) (tsz g <>ty) 1)
                  (mkv ty 'r0 ([[(ldop ty) 'r0 'r4 off]
                                 ['add 'r1 'r0 (* stp step)]]
                               + (ty @ 'bool (cvt ty 'r1))
                               + [[(stop ty) 'r4 off 'r1]])))
              (: lv0 (clval g env dst)
           (? (bad? lv0) 'bad
              (: ty (vty lv0)
                 stp (? (ptr? ty) (tsz g <>ty) 1)
                 (? (arr? ty) 'bad
                    (bitf? ty) 'bad             ; bitfield ++/-- -- refuse (rare; use `f = f + 1`)
                    (d128? ty) (nolane g "++/-- is not carried on a wide value (use `x = x + 1`)")
                    (pair? g ty)
                     (: lv (matv g lv0)
                        (mkv ty 'r0 (vfs lv +
                               '((mov r12 r0)) + (pld 'r12 0) + (ppost 'r12 0 (* stp step)))))
                    ; face-direct: no step rhs runs, so the base survives by construction
                    (vm? lv0 && !(= (vmb lv0) 'r0))
                     (: b (vmb lv0) o (vmo lv0)
                        fs (vfs lv0 +
                            ([[(ldop ty) 'r0 b o]
                               ['add 'r1 'r0 (stp * step)]]
                             + (ty @ 'bool (cvt ty 'r1))   ; b++/b-- lands on 0/1
                             + [[(stop ty) b o 'r1]]))
                        _ (rfree g b)
                        (mkv ty 'r0 fs))
                    (: lv (matv g lv0)
                       (mkv ty 'r0 (vfs lv +
                              (['(mov r2 r0)
                                 [(ldop ty) 'r0 'r2 0]
                                 ['add 'r1 'r0 (stp * step)]]
                               + (ty @ 'bool (cvt ty 'r1))   ; b++/b-- lands on 0/1
                               + [[(stop ty) 'r2 0 'r1]]))))))))))
       ; E1 op= E2 evaluates e1 once: the address moors in a frame temp and ('moor off ty), a calm lvalue,
       ; stands for it in the asn/bin desugar -- so every store lane rides unchanged
       ('rmw op dst rhs)
        (: lv (matv g (clval g env dst))
           (? (bad? lv) 'bad
              (: ty (vty lv)
                 (? (arr? ty || stru? ty) 'bad
                    (: off (ntmp g 'long)
                       mo ['moor off ty]
                       r (cgexpr g env ['asn mo ['bin op mo rhs]] ())
                       (? (bad? r) 'bad
                          (mkv (vty r) (vreg r)
                               (vfs lv + [['st 'r4 off 'r0]] + vfs r))))))))
       ('cast ty x)
        (: tgt ty
           fv (flo? tgt ? (cgdfold g e) ())         ; (double) of a constant expression is one
           r (two? fv ? 'bad (cgexpr g env x (? (!(flo? tgt) && !(two? (cvt tgt 'r0))) wnt ())))
           (? (two? fv) fv
              (bad? r) 'bad
              (flo? tgt && d128? (vty r))
               ; (double) of a wide value: a constant expression only, folded exactly (love's + rounds a big correctly);
               ; there is no runtime lane, and the discarded emission r is pure
               (: v (cfold x)
                  (? (cint? v) (mkv 'double 'r0 [['li 'r0 (fbits (0.0 + v))] '(movqxr f0 r0)])
                     'bad))
              (d128? tgt && flo? (vty r))                                 ; double -> wide: not carried
               (nolane g "a double is not converted to a wide integer")
              (flo? tgt && !(flo? (vty r))) (mkv 'double 'r0 (asflo g r))  ; int -> double
              (tgt = 'bool && flo? (vty r))       ; (bool)d is d != 0.0, never a truncation
               (: z1 (? (t32? g) '((li r0 0) (li r1 0) (movqxr f1 r0))
                        '((li r0 0) (movqxr f1 r0)))
                  (mkv 'bool 'r0 (vfs r + z1 + '((ucomisd f0 f1)) + fsetn)))
              (!(flo? tgt) && flo? (vty r))                              ; double -> int, then narrow
               (? (pair? g tgt)                                               ; double -> llong: the pattern peel
                   (mkv tgt 'r0 (vfs r + cvtdll g (usg? tgt)))
                  (t32? g && usg? tgt)                                    ; t32 unsigned: the U-converter
                   (mkv tgt 'r0 (vfs r + '((cvttsd2ui r0 f0)) + cvt tgt 'r0))
                  (mkv tgt 'r0 (asintt g r tgt + cvt tgt 'r0)))
              ; (float) of a double rounds: floats ride as doubles and narrow only at a store, so the cast must narrow here
              (tgt = 'float && flo? (vty r))
               (mkv 'double 'r0 (vfs r + '((cvtsd2ss f0 f0) (cvtss2sd f0 f0))))
              (flo? tgt) (mkv 'double 'r0 (vfs r))                            ; double -> double
              (pair? g tgt && !(llt? (vty r)))                           ; widen to the pair (source signedness)
               (mkv tgt 'r0 (asll g r))
              (d128? tgt && !(d128? (vty r)))                            ; widen to the wide pair (source signedness)
               (w128? g ? (mkv tgt 'r0 (as128 g r)) (no128 g))
              (two? (cvt tgt 'r0)) (mkv tgt 'r0 (tor0 g r + cvt tgt 'r0))   ; int -> narrower int
              (mkv tgt (vreg r) (vfs r))))                                    ; a full-word int cast keeps the register (a wide one narrows to its lo)
       ('un op x)
        (: fv (= op 'neg ? (cgdfold g e) ())      ; -1.5 is a 'un over a 'flo, not a literal
           r (two? fv ? 'bad (cgexpr g env x ()))
           (? (two? fv) fv
              (bad? r) 'bad
              (gcplx? (vty r) && (= op 'neg))      ; -z: both components flip through the complex lane
               (: pa (cxpark g r)
                  (? (bad? pa) 'bad
                     (cxout g (cxb (vty r) @ 'float (vty r) cxdty)
                        ; each component subtracts from minus zero (see the scalar lane); r0 is free, cxout writes it last
                        (<>pa + [['ldsd 'f0 'r4 <pa] ['ldsd 'f1 'r4 (<pa + 8)]
                                  ['li 'r0 0x8000000000000000] '(movqxr f4 r0)
                                  '(subsd f4 f0) '(movsd f0 f4)
                                  ['li 'r0 0x8000000000000000] '(movqxr f4 r0)
                                  '(subsd f4 f1) '(movsd f1 f4)]))))
              (flo? (vty r))                        ; unary on a double
               (: z1 (t32? g ? '((li r0 0) (li r1 0) (movqxr f1 r0))             ; 0.0 (the t32 pair)
                               '((li r0 0) (movqxr f1 r0)))
                  ; -0.0: 0.0 - 0.0 is +0.0, so negation subtracts from minus zero
                  n0 (? (t32? g) ['(li r0 0) ['li 'r1 0x80000000] '(movqxr f1 r0)]
                        [['li 'r0 0x8000000000000000] '(movqxr f1 r0)])
                  (op @ 'neg                 ; -d = (-0.0) - d
                         (mkv 'double 'r0 (vfs r + (n0 + '((subsd f1 f0) (movsd f0 f1)))))
                        'not                 ; !d = (d == 0.0), NaN-honest: !NaN is false -- fsete
                         (mkv 'long 'r0 (vfs r + (z1 + ('((ucomisd f0 f1)) + fsete))))
                        'bad))                           ; ~ on a double is invalid
              (pair? g (vty r))                     ; unary on the pair
               (op @ 'neg
                      (mkv (vty r) 'r0 (tor0 g r + '((li r2 0) (li r3 0)
                                                     (subs r0 r2 r0) (sbc r1 r3 r1))))
                     'bnot
                      (mkv (vty r) 'r0 (tor0 g r + '((not r0) (not r1))))
                     (mkv 'long 'r0 (tor0 g r + [['ors (v6m? g ? 'r0 'r12) 'r0 'r1] '(set eq r0)])))
              (d128? (vty r))                       ; unary on the wide pair
               (? !(w128? g) (no128 g)
                  (op = 'neg) (mkv (vty r) 'r0 (tor0 g r + '((n128))))
                  (op = 'bnot) (mkv (vty r) 'r0 (tor0 g r + '((not r0) (not r2))))
                  (mkv 'long 'r0 (tor0 g r + '((or r0 r0 r2) (cmp r0 0)) + '((set eq r0)))))
              ; -1ull stays unsigned; a sub-64 unsigned re-narrows after neg/~ (-1u wraps at 32 bits, not 64)
              (: uty (elem op '(neg bnot) && usg? (vty r))
                 renar (uty ? (vty r @ 'uchar '((zx1 r0))
                                       'ushort '((zx2 r0))
                                       'uint '((zx4 r0))))
                 (mkv (? uty (vty r) 'long) 'r0
                    (tor0 g r +
                     (op @ 'neg '((neg r0))
                           'bnot '((not r0))
                           '((cmp r0 0) (set eq r0))) +
                     renar)))))
       ('comma ea eb)
        (: a (cgexpr g env ea ())
           b (cgexpr g env eb wnt)
           (? (bad? a || bad? b) 'bad
              (mkv (vty b) (vreg b) (vdrop g a + vfs b))))
       ('land . _)                                ; as a value: cbranch the short-circuit, then settle the bit
        (: lf (nlab g ".f") ld (nlab g ".d")
           f (cbranch g env e 'eq lf)
           (? (bad? f) 'bad
              (mkv 'long 'r0 (f + ['(li r0 1) ['jmp ld]
                                       ['label lf] '(li r0 0) ['label ld]]))))
       ('lor . _)
        (: lt (nlab g ".t") ld (nlab g ".d")
           f (cbranch g env e 'ne lt)
           (? (bad? f) 'bad
              (mkv 'long 'r0 (f + ['(li r0 0) ['jmp ld]
                                       ['label lt] '(li r0 1) ['label ld]]))))
       ('cond cnd ea eb)
        (: le (nlab g ".e") ld (nlab g ".d")
           c (cbranch g env cnd 'eq le)
           t (cgexpr g env ea ())
           el (cgexpr g env eb ())
           (? (bad? c || bad? t || bad? el) 'bad
              ; C converts the arms (6.5.15p5): one flo arm makes the result flo, two arithmetic arms meet at puac;
              ; typing by the then-arm alone leaves an int in r0 where the reader takes f0
              (: fl (flo? (vty t) || flo? (vty el))
                 pl (pair? g (vty t) || pair? g (vty el))   ; one pair arm pairs the other too
                 ; a literal arm reads through its written face (numty9): the value tuple types a bare number 'long
                 ta9 (numty9 ea (vty t)) tb9 (numty9 eb (vty el))
                 ; ..and the wide pair rides its own lane, so it stays with the then-arm
                 ua (!fl && !pl && parith? ta9 && parith? tb9 &&
                     !(d128? ta9) && !(d128? tb9))
                 tf (? fl (asflo g t) pl (asll g t) (tor0 g t))
                 ef (? fl (asflo g el) pl (asll g el) (tor0 g el))
                 rt (? (flo? (vty t)) (vty t) fl (vty el)
                       pl (? (llt? (vty t)) (vty t) (vty el))
                       ua (puac !(t32? g) ta9 tb9)
                       (vty t))
                 ; a 32-bit unsigned result owes a signed arm the zx4: it rode sign-extended past bit 31
                 nt (u32? g rt && !(usg? ta9) ? '((zx4 r0)) ())
                 ne (u32? g rt && !(usg? tb9) ? '((zx4 r0)) ())
                 (mkv rt 'r0
                    (c + tf + nt + [['jmp ld] ['label le]] + ef + ne + [['label ld]])))))
       ; the va_list per target (apps/moon/include/stdarg.h). SysV: { int gp_offset; int fp_offset; void *overflow_arg_area; void *reg_save_area; }
       ; AAPCS64: { void *__stack; void *__gr_top; void *__vr_top; int __gr_offs; int __vr_offs; } (offs negative, counted back from each top)
       ('vastart ap)
        ; cgexpr, not clval: an array va_list decays and a param one loads -- both land the address in r0
        (: lv (cgexpr g env ap ())                 ; the va_list struct pointer in r0
           rsa (peep g 'rsa 0) ngp (peep g 'vagp 0) nxmm (peep g 'vaxmm 0)
           nov (peep g 'vaov 0)                  ; named params that overflowed (slots)
           (? (bad? lv) 'bad
              (: _ (pin g 'fesc 1)                                       ; the va_list holds frame addresses: no sibcalls here
                 (mkv 'long 'r0 (tor0 g lv +
                   (? (t32? g)   ; aapcs32: __ap = the first anonymous word, past the push cells + named regs + named overflow
                      [['lea 'r1 'r4 (ovb g + 4 * ngp + nov)] '(st r0 0 r1)]
                      (rv64? g)   ; LP64: __ap = the first anonymous 8-byte slot, past the push cells + named regs + named overflow
                      [['lea 'r1 'r4 (ovb g + 8 * ngp + 8 * nov)] '(st r0 0 r1)]
                      (a64? g)
                      [['lea 'r1 'r4 (ovb g + 8 * nov)] '(st r0 0 r1)   ; __stack = fp+32 + named overflow
                         ['lea 'r1 'r4 (rsa + 64)]  '(st r0 8 r1)            ; __gr_top (past x0..x7)
                         ['lea 'r1 'r4 (rsa + 192)] '(st r0 16 r1)           ; __vr_top (past q0..q7)
                         ['li 'r1 -(8 * (8 - ngp))]  '(st4 r0 24 r1)    ; __gr_offs = -(unnamed gp)*8
                         ['li 'r1 -(16 * (8 - nxmm))] '(st4 r0 28 r1)]  ; __vr_offs = -(unnamed vr)*16
                      [['li 'r1 (8 * ngp)]         '(st4 r0 0 r1)   ; gp_offset = 8*named-gp
                         ['li 'r1 (48 + 16 * nxmm)] '(st4 r0 4 r1)  ; fp_offset = 48 + 16*named-xmm
                         '(lea r1 r4 16)  '(st r0 8 r1)             ; overflow_arg_area = rbp+16
                         ['lea 'r1 'r4 rsa] '(st r0 16 r1)]))))))      ; reg_save_area = rbp+rsa
       ('vaarg ap ty)
        (: lv (cgexpr g env ap ())          ; the va_list struct pointer in r0
           lov (nlab g ".vo") ld (nlab g ".vd")
           ; r1 = the offset, r2 = the fetch address
           walk (? (t32? g)
                   '((ld r2 r0 0) (mov r3 r2) (add r3 r3 4) (st r0 0 r3))
                   (rv64? g)   ; LP64: __ap just walks, one 8-byte slot per anonymous arg (doubles ride gp slots)
                   '((ld r2 r0 0) (mov r3 r2) (add r3 r3 8) (st r0 0 r3))
                   (a64? g)
                   (: foff (? (flo? ty) 28 24)               ; __vr_offs / __gr_offs
                      toff (? (flo? ty) 16 8)                ; __vr_top / __gr_top
                      step (? (flo? ty) 16 8)                ; a vr slot is one q (16)
                      [['ld4 'r1 'r0 foff] '(cmp r1 0) ['br 'ge lov]
                       ['ld 'r2 'r0 toff] '(add r2 r2 r1)           ; p = top + offs
                       ['add 'r1 'r1 step] ['st4 'r0 foff 'r1]          ; advance the offs
                       ['jmp ld] ['label lov]
                       '(ld r2 r0 0) '(mov r3 r2) '(add r3 r3 8) '(st r0 0 r3)   ; p = __stack; __stack += 8
                       ['label ld]])
                   (: foff (? (flo? ty) 4 0)                 ; fp_offset (4) vs gp_offset (0)
                      lim (? (flo? ty) 176 48)               ; the register-area limit
                      step (? (flo? ty) 16 8)                ; the offset stride
                      [['ld4 'r1 'r0 foff] ['cmp 'r1 lim] ['br 'ge lov]
                       '(ld r2 r0 16) '(add r2 r2 r1)            ; p = reg_save_area + offset
                       ['add 'r1 'r1 step] ['st4 'r0 foff 'r1]         ; advance the offset
                       ['jmp ld] ['label lov]
                       '(ld r2 r0 8) '(mov r3 r2) '(add r3 r3 8) '(st r0 8 r3)   ; p = overflow; overflow += 8
                       ['label ld]]))
           (? (bad? lv) 'bad
              (t32? g && (flo? ty || llt? ty || stru? ty))        ; t32 va_arg reads words only (love.c's shape)
               (nolane g ("no lane for a double/pair/struct va_arg" + ontgt g))
              (d128? ty) (nolane g "a wide va_arg is not carried")
              (flo? ty) (mkv 'double 'r0 (tor0 g lv + walk + fldf ty 'f0 'r2 0))
              (mkv ty 'r0 (tor0 g lv + walk + [[(ldop ty) 'r0 'r2 0]]))))
       ('vaend . _) (mkv 'long 'r0 ())
       ('call fh as)
        (: head fh args as
           bi (? (<head = 'var) <>head ())
           bv (cgbuiltin g env bi args)
           (? !(= bv 'no) bv
              (: m9 (g 'must9)
                 _ (m9 ? (pin g 'must9 ()))
                 inlf (? m9 ()                                  ; a musttail call is owed as a call: never spliced
                         (2 < peep g 'inlining 0) ()   ; splices nest to depth 3, cbinl's cap
                         !(<head = 'var) ()
                         !(bad? (vent g env <>head)) ()   ; a local/global shadows the name
                         (g 'inl <>head))
                 ir9 (? (two? inlf && #args = #<>>inlf)
                        (cginl g env inlf args) 'no)              ; 'no: splice declined (fesc or shape) -> the real call
                 (? !(= ir9 'no) ir9
              (: direct (<head = 'var && bad? (vent g env <>head) &&  ; not a local/global variable...
                                         g 'fns <>head)     ; ...and a known function (typos refuse)
                 sig (direct ? (g 'sigs <>head))
                 ; the param types, a function-pointer type's included: a widened float arg is indistinguishable from a double
                 ptys (? (two? sig) <>sig direct () (fnpts (hdty9 g env head)))
                 rt (? (two? sig) <sig 'long)
                 variadic (two? sig ? (sig 2))
                 ; the arity check, direct only (the gripe spells a name). 0 < nps exempts the empty list: `int f()` and
                 ; `int f(void)` both park an empty ptys and the sigs row cannot tell them apart
                 nps #ptys nas #args
                 off (direct && 0 < nps && (variadic ? (nas < nps) (nas != nps)))
                 _ (? off (pin g 'arity
                               ("call to '" + <>head + "' wants "
                                + show nps + (? variadic " or more" "")
                                + (? (nps = 1) " argument" " arguments")
                                + ", given " + show nas)) 0)
                 cr (? off 'bad (call-fixed g env head args direct ptys rt variadic))
                 (? (bad? cr) 'bad
                    !(stru? (vty cr)) cr
                    (sretm? g (vty cr)) cr   ; a memory return: the sret temp's address in r0 is the struct value
                    (sse2? g (vty cr))              ; a two-double struct result: park the xmm pair in a fresh slot, answer its address
                     (: toff (nslot g 16)
                        (mkv (vty cr) 'r0 (vfs cr +
                                           fstf g 'double 'r4 toff (xmmreg 0) +
                                           fstf g 'double 'r4 (toff + 8) (xmmreg 1) +
                                           [['lean 'r0 'r4 toff]])))
                    (t32? g &&                    ; t32: past the d-pair, only the 8B sse blob (d0) and the <=4B int one (r0) return
                     !((= (aone g (vty cr)) 'sse && tsz g (vty cr) = 8) ||
                       (= (aone g (vty cr)) 'int && tsz g (vty cr) <= 4))) 'bad
                    (ipair? g (vty cr))             ; a two-int struct result: park rax:rdx (a64 x0:x1) the same way
                     (: toff (nslot g 16)
                        (mkv (vty cr) 'r0 (vfs cr +
                                     [['st 'r4 toff 'r0] ['st 'r4 (toff + 8) (ip2 g)]
                                        ['lean 'r0 'r4 toff]])))
                    (= (aone g (vty cr)) 'sse)    ; a small SSE aggregate result: park xmm0
                     (: toff (nslot g 16)
                        (mkv (vty cr) 'r0 (vfs cr +
                                           (fstf g 'double 'r4 toff (xmmreg 0) +
                                            [['lean 'r0 'r4 toff]]))))
                    (= (aone g (vty cr)) 'int)    ; a small int aggregate result: park rax
                     (: toff (nslot g 16)
                        (mkv (vty cr) 'r0 (vfs cr + [['st 'r4 toff 'r0] ['lean 'r0 'r4 toff]])))
                    'bad))))))
       ; a statement expression: the statements in place, then the value as an ordinary expression (keeps its register);
       ; 'inlining is raised over the statements so stq stops ticking and each wears the conservative wrapset
       ('sexpr items ve ty)
        (: il0 (g 'inlining)
           _ (pin g 'inlining ((il0 || 0) + 1))
           pre ((g 'sxpre) g env items ())
           _ (pin g 'inlining il0)
           (? (bad? pre) 'bad
              !(two? ve) (mkv ty 'r0 <pre)                   ; void: the statements alone
              (: r (cgexpr g <>pre ve wnt)
                 (? (bad? r) 'bad (mkv (vty r) (vreg r) (<pre + vfs r))))))
       ('clit . _)                              ; a compound literal as a value: fill the temp, load it
        (: lv (clval g env e)
           (? (bad? lv) 'bad (loadval g lv wnt)))
       ('bin op a b)
        (: fv (elem op '(+ - * /) ? (cgdfold g e) ())   ; 1.5 + 2.25 is a constant, not an addsd
           (? (two? fv) fv
              (= op '|)
               (: r9 (cgror g env a b wnt)
                  (? (= r9 'no) (cgbin g env e wnt) r9))
              (cgbin g env e wnt))))
   ; a targetable gp arg: a pure single-emission read (immediate, frame, home register, label) skips the cell and
   ; lands in its register after the spills -> ((ez i) forms) | ((ezm i rH) movforms ldforms) | 'no
   (ezarg g env e pty i)
    (: rT (argr g i)
       (fin ty fs) (: aty (? pty pty ty)
                      (? (flo? aty || stru? aty || llt? aty || d128? aty) 'no [['ez i] fs]))   ; a pair arg keeps the cell path
       kc (knum g e)
       (? (two? kc) (? (t32? g && !(fitsw? <kc)) 'no
                       (fin 'long [['li rT <kc]]))
          (<e = 'str)
           (: lbl (nlab g ".S")
              _ (pin g 'strs ([lbl <>e] . g 'strs))
              (fin '(ptr char) [['la rT lbl]]))
          (<e = 'addr)                          ; &var only: lea/la, argpos-equivalent (no escan)
           (? !(<<>e = 'var) 'no
              (: en (vent g env <><>e)
                 (? (bad? en) 'no
                    (<en = 'loc) (fin ['ptr <>>en] [['lea rT 'r4 <>en]])
                    (<en = 'glo) (fin ['ptr <>>en] [['la rT <>en]])
                    'no)))
          !(<e = 'var) 'no
          (: en (vent g env <>e)
             (? (bad? en) 'no
                (: ty <>>en
                   (? (<en = 'regv)             ; a param in a register: mov from it, or ld its spill slot
                       (? (flo? (? pty pty ty) || stru? (? pty pty ty)) 'no
                          ; a cs seat: nothing in the staging writes a callee-saved register, so it targets unconditionally
                          (elem <>en (cspool g)) (fin ty [['mov rT <>en]])
                          (: sl (assoc <>en (peep g 'homes ()))
                             (? (two? sl)
                                 [['ezm i <>en]
                                   [['mov rT <>en]]
                                   [['ld rT 'r4 <>sl]]]
                                ; no spill slot to fall back on: the ride targets only when every sibling is a pure leaf (ezride)
                                ; and the source is outside the argument file (no targeted sibling lands on it)
                                (peep g 'ezride () && !(elem <>en (argr g)))
                                 (fin ty [['mov rT <>en]])
                                'no)))
                      (arr? ty)                      ; array decay: its address
                       (? (<en = 'loc) (fin ['ptr <>ty] [['lea rT 'r4 <>en]])
                          (fin ['ptr <>ty] [['la rT <>en]]))
                      (stru? ty || flo? ty) 'no
                      (<en = 'loc)
                       (fin ty [[(ldop ty) rT 'r4 <>en]])
                      (fin ty [['la rT <>en] [(ldop ty) rT rT 0]])))))))   ; a global: la then a self-based load
   ; the register call: overflow args emit first, then the register group, both right-to-left; the caller
   ; cleans the overflow block after the call. params are named uniquely so no lambda param shadows a :-local
   (call-fixed g env hd ags dir pts ret va?)
    (: (kls as i gpc xmmc ovc acc)                       ; classify + evaluate, L->R -> (((class idx) pushforms)..) | 'bad
        (? !(two? as) (rev acc)
           ; a targetable leaf skips the cell ('ez/'ezm): emitted into its register after the spills
           (: ez (? (gpc < ngp g) (ezarg g env <as (pts i) gpc) 'no)
              (? !(= ez 'no) (kls >as (i + 1) (gpc + 1) xmmc ovc (ez . acc))
           ; a direct &x / array / struct-var arg is presumed dead once the callee returns: argpos exempts its lea from fesc.
           ; aim the first cell arg at its seat (it evaluates last, nothing after writes it); dir only, never a home seat
           (: aim (: (psh9 pl) (? !(two? pl) ()
                                  (elem <<<pl '(g g2 g4 x x2 p2 ezd) || psh9 >pl))
                     rT (argr g gpc)
                     (? (dir && gpc < ngp g && !(psh9 acc) &&
                         !(two? (assoc rT (peep g 'homes ())))) rT ()))
              a (: _ (? (elem <<as '(addr var)) (pin g 'argpos 1) ())
                   (cgexpr g env <as aim))
              _ (pin g 'argpos ())
              (? (bad? a) 'bad
                 (: pty (pts i)
                    aty (? pty pty (vty a))                ; classify by the param type if known, else the arg's
                    wd (flo? aty)
                    ; t32 composites: an HFA rides the d-regs, an 8B one-sse blob the packed s-pair, a <=4B int one r0; the rest refuse
                    (? (t32? g && va? && stru? aty)        ; a t32 variadic call rides the base pcs: no d-reg composites
                        (nolane g ("no lane for a by-value struct in a variadic call" + ontgt g))
                       (v6m? g && sse2? g aty)       ; v6-M: a position-0 16B composite rides r0-r3 whole (the
                        (? (gpc = 0)                     ;  base-ABI words); any later start would split -- deferred
                           (kls >as (i + 1) 4 xmmc ovc
                                (. ['(g4 0) (tor0 g a + cell4w)] acc))
                           'bad)
                       (t32? g && stru? aty &&
                           !(sse2? g aty ||
                             (= (aone g aty) 'sse && tsz g aty = 8) ||
                             (= (aone g aty) 'int && tsz g aty <= 4))) 'bad
                       (t32f? g && sse2? g aty)            ; a 16-byte HFA: four float slots, or a d-reg pair
                        (: fb (hfab g aty)
                           k (vfpn xmmc 4 (= fb 'float ? 1 2))
                           (? (k < 0) 'bad
                              (kls >as (i + 1) gpc (vfpm xmmc k 4) ovc
                                   (. [(= fb 'float ? ['sn k 4] ['x2 (k // 2)])
                                       (tor0 g a + cell4w)] acc))))
                       (sse2? g aty)                       ; a two-double struct arg: push its pair (re on top), an xmm pair target
                        (? (6 < xmmc) 'bad
                           (kls >as (i + 1) gpc (xmmc + 2) ovc
                                (. [['x2 xmmc]
                                         (tor0 g a +
                                          (? (t32? g) cell4w   ; t32: four word copies
                                             (a8? g) cell2w    ; a64/riscv push is a 16-byte cell of its own: lay the pair by hand
                                             push2w))]
                                      acc)))
                       (stru? aty && two? (aeb2 g aty))       ; a 9..16B struct arg (not sse:sse): eb0/eb1 each into a gp or xmm reg, mirrors the param side's file rule
                        (: cls (aeb2 g aty) c0 <cls c1 <>cls
                           hfa (= c0 'sse && (= c1 'sse))
                           f0 (? (a64? g) (? hfa 'x 'g) (? (= c0 'sse) 'x 'g))
                           f1 (? (a64? g) (? hfa 'x 'g) (? (= c1 'sse) 'x 'g))
                           gpn ((? (= f0 'g) 1 0) + (? (= f1 'g) 1 0))
                           xmn ((? (= f0 'x) 1 0) + (? (= f1 'x) 1 0))
                           ; register-exhausted: SysV sends the whole aggregate to the overflow block. x64 only -- AAPCS64 closes the
                           ; gp file behind a stack composite and riscv splits one across the seam, so they refuse
                           (? (ngp g < gpc + gpn || 8 < xmmc + xmn)
                               (? (arm? g) 'bad             ; arm? is every non-x64 seat here
                                  (kls >as (i + 1) gpc xmmc (ovc + 2)
                                       (. [['ov ovc 2] (tor0 g a + push2w)] acc)))
                              (: i0 (? (= f0 'g) gpc xmmc)
                                 gpc1 (? (= f0 'g) (gpc + 1) gpc)
                                 xmc1 (? (= f0 'x) (xmmc + 1) xmmc)
                                 i1 (? (= f1 'g) gpc1 xmc1)
                                 (kls >as (i + 1) (gpc + gpn) (xmmc + xmn) ovc
                                      (. [['p2 f0 i0 f1 i1] (tor0 g a + (a8? g ? cell2w push2w))]
                                            acc)))))
                       ; a memory-class struct arg fills n overflow slots, highest eightbyte pushed first (x64 pushes deepest first)
                       (amem? g aty)
                        (? (< 8 (asalign g aty))              ; over-aligned memory arg: deferred
                            (nolane g "a by-value struct aligned past 8 is not carried as an argument")
                           (: n (aslots g aty)
                              (mv j acc9) (? (j < 0) acc9
                                             (mv (j - 1) (acc9 + [['ld 'r1 'r0 (* 8 j)] '(push r1)])))
                              (kls >as (i + 1) gpc xmmc (ovc + n)
                                   ([['ov ovc n] (tor0 g a + mv (n - 1) ())] . acc))))
                       (stru? aty && !(aone g aty))             ; a mixed 16B by-value struct stays ahead
                        (nolane g ("no lane for passing this " + show (tsz g aty) + "-byte struct by value" + ontgt g))
                       (d128? aty)                               ; a wide arg: not carried (love.c passes limbs, never dlimbs)
                        (nolane g "a wide value is not carried as an argument")
                       (pair? g aty)                             ; a pair arg: an even-odd register pair (AAPCS32
                        (: gpe (& (gpc + 1) -2)                  ;  rounds up), else the stack 8-aligned -- and gp
                           (? ((gpe + 2) <= ngp g)               ;  assignment closes behind a stack arg (C.13)
                               (kls >as (i + 1) (gpe + 2) xmmc ovc
                                    ([['g2 gpe] (asll g a + spush2)] . acc))
                               (: ov8 (& (ovc + 7) -8)
                                  (kls >as (i + 1) 4 xmmc (ov8 + 8)
                                       (. [['ov ov8 8]
                                                (asll g a + [['st 'sp ov8 'r0] ['st 'sp (ov8 + 4) 'r1]])]
                                             acc)))))
                       ; the delivered seat: aimed and honored. a zero-form answer (a riding home) predates the staging, so it keeps the cell
                       (aim && rpeq? g (vreg a) aim && two? (vfs a) &&
                           !(flo? (vty a) || flo? aty || stru? aty))
                        (kls >as (i + 1) (gpc + 1) xmmc ovc ([['ezd gpc] (vfs a)] . acc))
                       ; a one-eightbyte aggregate rides the scalar path: its content loads into r0 (the value is an address)
                       (: one (? (stru? aty) (aone g aty) ())
                          wd2 (wd || (= one 'sse))
                          aval (? (t32? g && (= one 'sse)) (tor0 g a + pld 'r0 0)           ; the t32 8B blob rides the r0:r1 pair
                                  one (tor0 g a + '((ld r0 r0 0)))
                                  wd (asflo g a + '((movqrx r0 f0)))
                                  (asintt g a aty))
                          ; a register arg rides a 16-byte cell (sp stays aligned while later args evaluate);
                          ; an overflow arg pushes 8, the callee reads the block packed
                          rpush (aval + (? (t32? g && wd2) spush2 (spush 'r0)))     ; a t32 double (or 8B blob) is the r0:r1 pair
                          ; the overflow store: x64 pushes; a64/t32 store into the pre-allocated block (sp sits at its base while args evaluate)
                          opush (? (a8? g) (aval + [['st 'sp (* 8 ovc) 'r0]])
                                   (t32? g) (aval + [['st 'sp ovc 'r0]])
                                   (aval + '((push r0))))
                          (? (t32? g && va? && wd2)        ; a t32 variadic call rides the base pcs: no d-reg doubles
                              (nolane g ("no lane for a double in a variadic call" + ontgt g))
                             ; AAPCS-VFP: a bare float takes one slot (back-filling a double's hole); the cell carries the widened double,
                             ; the pop narrows it. past the file a 4-byte stack word, and the mask closes behind it (vfpx)
                             (t32f? g && (= aty 'float))
                              (: k (vfpn xmmc 1 1)
                                 (? (0 <= k) (kls >as (i + 1) gpc (vfpm xmmc k 1) ovc
                                                  ([['s k] rpush] . acc))
                                    (kls >as (i + 1) gpc vfpx (ovc + 4)
                                         ([['ov ovc 4]
                                           (asflo g a + [['cvtsd2ss 'f15 (xmmreg 0)]
                                                         ['stss 'sp ovc 'f15]])] . acc))))
                             ; a two-float HFA: two slots aligned to one, so it may straddle a d-register -- the words ride one slot at a time
                             (t32f? g && (= one 'sse) && (= (hfab g aty) 'float))
                              (: k (vfpn xmmc 2 1)
                                 (? (0 <= k) (kls >as (i + 1) gpc (vfpm xmmc k 2) ovc
                                                  ([['sn k 2] rpush] . acc))
                                    (kls >as (i + 1) gpc vfpx (ovc + 8)
                                         ([['ov ovc 8]
                                           (aval + [['st 'sp ovc 'r0] ['st 'sp (ovc + 4) 'r1]])] . acc))))
                             (t32f? g && wd2)                 ; a double, or a one-double HFA: an aligned slot pair
                              (: k (vfpn xmmc 2 2)
                                 (? (0 <= k) (kls >as (i + 1) gpc (vfpm xmmc k 2) ovc
                                                  ([['x (k // 2)] rpush] . acc))
                                    (: ov8 ((ovc + 7) & -8)
                                       (kls >as (i + 1) gpc vfpx (ov8 + 8)
                                            ([['ov ov8 8]
                                              (aval + [['st 'sp ov8 'r0] ['st 'sp (ov8 + 4) 'r1]])] . acc)))))
                             (v6m? g && (= aty 'float))    ; v6-M base ABI: a bare float arg is one word (binary32,
                              (: av1 (asflo g a              ;  the gcc shape -- ai_flo_t is float on a 32-bit love)
                                      + '((cvtsd2ss f0 f0) (movqrx r0 f0)))
                                 (? (gpc < ngp g)
                                    (kls >as (i + 1) (gpc + 1) xmmc ovc
                                         ([['g gpc] (av1 + spush 'r0)] . acc))
                                    (kls >as (i + 1) gpc xmmc (ovc + 4)
                                         ([['ov ovc 4] (av1 + [['st 'sp ovc 'r0]])] . acc))))
                             (v6m? g && wd2)               ; v6-M base ABI: a double/8B-blob arg is an even-odd gp
                              (: gpe ((gpc + 1) & -2)      ;  pair (aval already lands r0:r1), else the 8-aligned stack
                                 (? (gpe + 2 <= (ngp g))
                                     (kls >as (i + 1) (gpe + 2) xmmc ovc
                                          ([['g2 gpe] (aval + spush2)] . acc))
                                     (: ov8 (& (ovc + 7) -8)
                                        (kls >as (i + 1) 4 xmmc (ov8 + 8)
                                             (. [['ov ov8 8]
                                                      (aval + [['st 'sp ov8 'r0] ['st 'sp (ov8 + 4) 'r1]])]
                                                   acc)))))
                             ; a variadic riscv call: every double rides the gp lane (the callee's packed a0..a7 block reads gp slots)
                             (rv64? g && va? && wd2 && gpc < ngp g)
                              (kls >as (i + 1) (gpc + 1) xmmc ovc ([['g gpc] rpush] . acc))
                             (rv64? g && va? && wd2)
                              (kls >as (i + 1) gpc xmmc (ovc + 1) ([['ov ovc] opush] . acc))
                             (wd2 && xmmc < 8) (kls >as (i + 1) gpc (xmmc + 1) ovc ([['x xmmc] rpush] . acc))
                             (!wd2 && gpc < ngp g) (kls >as (i + 1) (gpc + 1) xmmc ovc ([['g gpc] rpush] . acc))
                             (t32? g) (kls >as (i + 1) gpc xmmc (ovc + 4) ([['ov ovc 4] opush] . acc))
                             (kls >as (i + 1) gpc xmmc (ovc + 1) ([['ov ovc] opush] . acc)))))))))))
       ; v6-M memory return: a >4-byte composite fills a caller temp whose address rides r0, so args start at gpc 1
       sr6 (sretm? g ret)
       sroff (? sr6 (ntmp g ret) 0)
       ; ezride: every arg a pure leaf, so no sibling evaluation can move a register-resident param (ezarg's ride lane)
       _ (pin g 'ezride (: (pure? l) (? !(two? l) 1 (elem <<l '(num var) && pure? >l))
                          (pure? ags)))
       kr (kls ags 0 (? sr6 1 0) 0 0 ())
       _ (pin g 'ezride ())
       (? (bad? kr) 'bad
          (: ov? (\ kent (<<kent = 'ov))
             ovr (: (go1 l1 acc1) (? !(two? l1) acc1
                                     (go1 >l1 (? (ov? <l1) (<l1 . acc1) acc1)))
                    (go1 kr ()))                          ; overflow entries, reversed (deepest pushes first)
             rgr (: (go2 l2 acc2) (? !(two? l2) acc2
                                     (go2 >l2 (? (elem <<<l2 '(g g2 g4 x x2 p2 ezd s sn))
                                                      (<l2 . acc2) acc2)))
                    (go2 kr ()))                          ; pushing register entries, reversed (pops run forward)
             (pushcat l3 acc3) (? !(two? l3) acc3 (pushcat >l3 (acc3 + <><l3)))
             ; an arm double pops straight into its f-register off sp; x64 stages through r0
             pops (: (go4 l4 acc4)
                      (? !(two? l4) acc4
                         (: kc <<l4
                            (go4 >l4 (elem <kc '(ov ez ezm ezd) ? acc4 (acc4 +
                                      (<kc @ 'g (spop (argr g <>kc))
                                       'g2   ; the t32 pair: both words off one cell
                                        [['ld (argr g <>kc) 'sp 0]
                                           ['ld (argr g (<>kc + 1)) 'sp 4]
                                           '(add sp sp 16)]
                                       'g4   ; the v6-M whole-composite quad: r0-r3 off one cell
                                        '((ld r0 sp 0) (ld r1 sp 4)
                                           (ld r2 sp 8) (ld r3 sp 12)
                                           (add sp sp 16))
                                       'x2   ; the struct pair: re then im (a natural 16-byte cell)
                                        (? (arm? g)
                                           [['ldsd (xmmreg <>kc) 'sp 0] ['ldsd (xmmreg (<>kc + 1)) 'sp 8]
                                            '(add sp sp 16)]
                                           ['(pop r0) ['movqxr (xmmreg <>kc) 'r0]
                                             '(pop r0) ['movqxr (xmmreg (<>kc + 1)) 'r0]])
                                       'p2   ; a general two-eightbyte struct: eb0 (top) then eb1, each into its gp/xmm target
                                        (? (a8? g)
                                           ((<>kc @ 'g [['ld (argr g <>>kc) 'sp 0]] [['ldsd (xmmreg <>>kc) 'sp 0]])
                                            + (<>>>kc @ 'g [['ld (argr g <>>>>kc) 'sp 8]] [['ldsd (xmmreg <>>>>kc) 'sp 8]])
                                            + '((add sp sp 16)))
                                           ((<>kc @ 'g [['pop (argr g <>>kc)]] ['(pop r0) ['movqxr (xmmreg <>>kc) 'r0]])
                                            + (<>>>kc @ 'g [['pop (argr g <>>>>kc)]] ['(pop r0) ['movqxr (xmmreg <>>>>kc) 'r0]])))
                                       's    ; a float: the cell holds the widened double, the slot takes it narrowed
                                        ([['ldsd 'f15 'sp 0]] + vfpst <>kc 'f15 + '((add sp sp 16)))
                                       'sn   ; n float words into n consecutive slots, off the same cell
                                        (: (go i acc5)
                                            (? (<>>kc <= i) acc5
                                               (go (i + 1) (acc5 + [['ld 'r12 'sp (4 * i)]
                                                                    ['movsnxr (<>kc + i) 'r12]])))
                                           (go 0 () + '((add sp sp 16))))
                                       (? (arm? g) [['ldsd (xmmreg <>kc) 'sp 0] '(add sp sp 16)]   ; a lone double
                                          (spop 'r0 + [['movqxr (xmmreg <>kc) 'r0]]))))))))
                     (go4 kr ()))
             nxmm (: (go5 l5 n5) (? !(two? l5) n5
                                    (go5 >l5 (: ce <<l5 kk <ce
                                                     (kk @ 'x (n5 + 1) 'x2 (n5 + 2)
                                                           'p2 (n5 + (ce 1 = 'x) + (ce 3 = 'x))
                                                           n5))))
                     (go5 kr 0))
             ; slots, not entries: ('ov off n) carries a struct's slot count (t32's third field is bytes; ovblk sizes that)
             nov (: (go8 l8 n8) (? !(two? l8) n8
                                   (: ce <<l8
                                      (go8 >l8 (n8 + (two? >>ce ? <>>ce 1)))))
                    (go8 ovr 0))
             padn ((nov & 1) = 1 ? 8 0)               ; keep sp 16-aligned across the overflow block
             ; t32 slots are byte offsets: the block spans to the highest slot's end, rounded to 8; x64/a64 count 8-byte slots
             ovblk (? (t32? g)
                      (: (go9 l9 m9) (? !(two? l9) ((m9 + 7) & -8)
                                        (: ce <<l9
                                           e9 (<ce @ 'ov (<>ce + (two? >>ce ? <>>ce 4)) 0)
                                           (go9 >l9 (m9 < e9 ? e9 m9))))
                         (go9 kr 0))
                      (8 * nov + padn))
             ; x64 pads then pushes; a64/t32 allocate the block up front and the ov forms store into it
             pad (? (arm? g) (0 < ovblk ? [['sub 'sp 'sp ovblk]])
                    (0 < padn ? [['sub 'sp 'sp padn]]))
             clean (0 < ovblk ? [['add 'sp 'sp ovblk]])
             pf (pad + pushcat ovr () + pushcat rgr ())
             ; al = #xmm after the pops (r0 is no x64 arg register); on arm r0 is arg 0, so no al there
             setal (va? && !(arm? g) ? [['li 'r0 nxmm]])
             ; caller-saved homes spill before the pops and reload after the clean, filtered to this statement's
             ; wrapset (g 'stwrap; 'all wraps every home). a ret-position call's reloads are dead: skiprel peels them
             hs (: h9 (g 'homes) w9 (peep g 'stwrap 'all)
                   (w9 @ 'all h9 (filter (h2 \ elem <>>h2 w9) h9)))
             spills (foldl (\ a2 p2 (a2 + [['st 'r4 <>p2 <p2]])) () hs)
             relods (foldl (\ a2 p2 (a2 + [['ld <p2 'r4 <>p2]])) () hs)
             ; the targeted emissions, after the spills and before the pops: an 'ezm home mov
             ; demotes to its spill-slot load when another targeted arg writes that home
             ezt (: (go6 l6 a6) (? !(two? l6) a6
                                   (go6 >l6 (: kc <<l6
                                             (? (elem <kc '(ez ezm))
                                              (argr g <>kc . a6) a6))))
                    (go6 kr ()))
             ezf (: (go7 l7 a7) (? !(two? l7) a7
                                   (go7 >l7
                                        (: kc <<l7
                                           (? (<kc = 'ez) (a7 + <><l7)
                                              !(<kc = 'ezm) a7
                                              (: rH <>>kc
                                                 (? (elem rH ezt && !(= rH (argr g <>kc)))
                                                    (a7 + <>><l7)
                                                    (a7 + <><l7)))))))
                    (go7 kr ()))
             (? dir
                 (: ; v6-M base ABI: a double result arrives in r0:r1, a bare float as binary32 in r0 -- either lands on f0
                    fres (? (t32f? g && (= ret 'float)) '((cvtss2sd f0 f0))   ; AAPCS-VFP: the result is binary32 in s0
                            !(v6m? g && flo? ret) ()
                            (= ret 'float) '((movqxr f0 r0) (cvtss2sd f0 f0))
                            '((movqxr f0 r0)))
                    ; the hidden sret pointer rides the first argument register; the result is the temp's address, fresh in r0
                    srin (? sr6 [['lea (argr g 0) 'r4 sroff]] ())
                    srout (? sr6 [['lea 'r0 'r4 sroff]] ())
                    (mkv ret 'r0 (pf + spills + ezf + pops + setal + srin + [['call (intern <>hd)]] + fres + srout + clean + relods)))
                (: hr (cgexpr g env hd ())                   ; a function-pointer value: park (x64 rbx; a64 x15), callr
                   pk (pkr g)
                   fres (? (t32f? g && (= (fnret (vty hr)) 'float)) '((cvtss2sd f0 f0))
                           !(v6m? g && flo? (fnret (vty hr))) ()
                           (= (fnret (vty hr)) 'float) '((movqxr f0 r0) (cvtss2sd f0 f0))
                           '((movqxr f0 r0)))
                   (? (bad? hr) 'bad
                      (v6m? g && stru? (fnret (vty hr)) &&   ; a memory-returning callee behind a pointer: the
                          4 < tsz g (fnret (vty hr)))        ; implicit-arg shift wasn't staged
                       (nolane g ("no lane for an indirect call to a MEMORY-returning function" + ontgt g))
                      ; t32: r12 doubles as the far-mem scratch, so the park rides a frame slot and reloads r12 last before the call
                      (t32? g)
                       (: pko (ntmp g 'long)
                          (mkv (fnret (vty hr)) 'r0 (pf + tor0 g hr + [['st 'r4 pko 'r0]] +
                                    spills + ezf + pops + setal + [['ld pk 'r4 pko] ['callr pk]] + fres + clean + relods)))
                      (mkv (fnret (vty hr)) 'r0 (pf + tor0 g hr + [['mov pk 'r0]] +
                                spills + ezf + pops + setal + [['callr pk]] + clean + relods))))))))
   ; the C99 complex lane (x64): a complex value is its two-member struct, so it flows as one. arithmetic parks each
   ; side in a double-pair temp (the other side may call), f0..f3 carry (a.re a.im b.re b.im), the answer is a fresh temp's address
   (cxb ty) (? (<>ty = "__cplx_float") 'float 'double)
   ; the C99 VLA type ('varr elt dim-expr [idx]): a local carries its parse-stamped idx into g 'vslots -> (ptrslot sizeslot);
   ; a pointee (char (*p)[width]) carries just the expr, re-evaluated at each scale site
   (gvarr? ty) (two? ty && <ty = 'varr)
   (varel ty) <>ty                             ; the element type (const-sized)
   (varn ty) <>>ty                             ; the dim expression (an AST)
   ; by reader ops, not `at`: gen.l is cat'd without holo for the laws, where an unbound `at` is a silent no-op
   (varix ty) <>>>ty                                ; a decl's slot index (4-long only)
   ; park a value rec as a double-pair temp -> (off forms srcty) | 'bad
   (cxpark g rv)
    (: off (ntmp g cxdty)
       ty (vty rv)
       (? (gcplx? ty)
           (? (= (cxb ty) 'float)
               [off (tor0 g rv +
                      ['(ldss f2 r0 0) '(cvtss2sd f2 f2) ['stsd 'r4 off 'f2]
                       '(ldss f2 r0 4) '(cvtss2sd f2 f2) ['stsd 'r4 (off + 8) 'f2]])
                 ty]
              [off (tor0 g rv +
                     ['(ld r2 r0 0) ['st 'r4 off 'r2]
                      '(ld r2 r0 8) ['st 'r4 (off + 8) 'r2]])
                ty])
          (stru? ty) 'bad
          [off (asflo g rv + [['stsd 'r4 off 'f0] '(li r2 0) ['st 'r4 (off + 8) 'r2]])
            ty]))
   ; evaluate an expr and park it -> (off forms srcty) | 'bad
   (cxmat g env x)
    (: rl (matv g (clval g env x))
       rv (? (!(bad? rl) && stru? (vty rl)) rl (cgexpr g env x ()))
       (? (bad? rv) 'bad (cxpark g rv)))
   (cxload oa ob) [['ldsd 'f0 'r4 oa] ['ldsd 'f1 'r4 (oa + 8)]
                    ['ldsd 'f2 'r4 ob] ['ldsd 'f3 'r4 (ob + 8)]]
   (cxarith op)                                     ; f0..f3 = (a.re a.im b.re b.im) -> (re im) in (f0 f1)
    (op @ '+ '((addsd f0 f2) (addsd f1 f3))
          '- '((subsd f0 f2) (subsd f1 f3))
          '* '((movsd f4 f0) (movsd f5 f1)
               (mulsd f0 f2) (mulsd f5 f3) (subsd f0 f5)                 ; re = ac - bd
               (mulsd f4 f3) (mulsd f1 f2) (addsd f1 f4))                ; im = bc + ad
          '/ '((movsd f4 f2) (mulsd f4 f2)                               ; c^2
               (movsd f5 f3) (mulsd f5 f3) (addsd f4 f5)                 ; den = c^2 + d^2
               (movsd f5 f0) (mulsd f5 f2)                               ; ac
               (movsd f6 f1) (mulsd f6 f3) (addsd f5 f6)                 ; ac + bd
               (divsd f5 f4)                                             ; re
               (mulsd f1 f2) (mulsd f0 f3) (subsd f1 f0)                 ; bc - ad
               (divsd f1 f4) (movsd f0 f5)))
   ; the (f0 f1) result into a fresh rt-typed temp; the temp's address answers
   (cxout g rt fs)
    (: ro (ntmp g rt)
       st (cxb rt @ 'float
           (fstf g 'float 'r4 ro 'f0 + fstf g 'float 'r4 (ro + 4) 'f1)
           [['stsd 'r4 ro 'f0] ['stsd 'r4 (ro + 8) 'f1]])
       (mkv rt 'r0 (fs + st + [['lean 'r0 'r4 ro]])))
   (cgcx g env op a rhs)                            ; the left already evaluated (a value rec)
    (? !(= (peep g 'tgt 'x64) 'x64)
        (nolane g ("no lane for C99 complex arithmetic" + ontgt g))
       (: arith (cxarith op)
          (? !(two? arith) 'bad
             (: pa (cxpark g a)
                (? (bad? pa) 'bad
                   (: mb (cxmat g env rhs)
                      (? (bad? mb) 'bad
                         (: tb <>>mb
                            rt (? (gcplx? (vty a) && (= (cxb (vty a)) 'float) &&
                                   gcplx? tb && (= (cxb tb) 'float))
                                  '(struct "__cplx_float") cxdty)
                            (cxout g rt (<>pa + (<>mb + (cxload <pa <mb + arith))))))))))))
   ; the rotate idiom: (x >> n) | (x << (W - n)) in either order, x an unsigned W-bit pure operand -- one eval of x,
   ; one rotate (ror4/rorv4 at 32, ror/rorv at 64). a rotl count rides negated (both ISAs read the count mod W)
   (rotp? e)                                        ; pure: safe to evaluate once for the source's twice
    (e @ ((k . _) && elem k '(num flo flof str var)) 1
         ((k . x . _) && elem k '(deref dot moor addr)) (rotp? x)
         ('cast _ x) (rotp? x)
         ('bin _ a b) (rotp? a && rotp? b)
         ('un _ x) (rotp? x)
         ())
   (rotty g env e)                                  ; the operand's declared type, by static peek
    (e @ ('var nm) (: en (vent g env nm) (? (bad? en) () <>>en))
         ('cast . ty . _) ty
         ('deref p) (: t (rotty g env p) (? (ptr? t) <>t (arr? t) <>t ()))
         ('bin op x y && elem op '(+ -))         ; index arithmetic keeps the ptr/arr side's type
          (: a (rotty g env x)
             (? (ptr? a || arr? a) a
                (: b (rotty g env y) (ptr? b || arr? b ? b)))))
   (rotw g env e)                                   ; -> 32 | 64 | (): the unsigned rotate width
    (rotty g env e @ 'uint 32 ('ulong || 'ullong) 64)
   (rotk g e)                                       ; a count as a number: knum, then the const fold
    (: k (knum g e) (two? k ? <k (cfold e)))
   (rotc? g w big n)                                ; big reads (W - n), n pure and shared
    (big @ ('bin '- wide sub)
             (: kb (rotk g wide)
                (charm? kb && kb = w && sub = n && rotp? n)))
   (cgrimm g env x w c wnt)                         ; the immediate rotate: mirror of the constant shift
    (: xv (cgexpr g env x ())
       (? (bad? xv) 'bad
          (: rt (w @ 32 'uint 'ulong)
             iop (w @ 32 'ror4 'ror)
             (? (wr? g (vreg xv))
                (mkv rt (vreg xv) (vfs xv + [[iop (vreg xv) c]]))
                (: rd (wnt || rdst g (vreg xv))
                   (mkv rt rd (vfs xv + [['mov rd (vreg xv)] [iop rd c]])))))))
   (cgrvar g env x w ce ng)                         ; the register-count rotate: mirror of the variable shift
    (: xv (cgexpr g env x ())
       (? (bad? xv) 'bad
          (: cv (cgexpr g env ce ())
             (? (bad? cv) 'bad
                (: rt (w @ 32 'uint 'ulong)
                   vop (w @ 32 'rorv4 'rorv)
                   af (tor0 g xv)
                   bf (tor0 g cv)
                   (mkv rt 'r0 (af + cshut g bf + (ng ? '((neg r1))) + [[vop 'r0 'r1]])))))))
   (cgror g env L R wnt)                            ; -> tuple | 'bad | 'no (the general lane stands)
    (? !(rot4? g) 'no
       (: a (two? L && (<L = 'bin) && elem <>L '(shl shr) ? L)
          b (two? R && (<R = 'bin) && elem <>R '(shl shr) ? R)
          (? (!(two? a) || !(two? b) || (= <>a <>b)) 'no
             (: s (<>a @ 'shr a b)            ; the shr side: a rotate is ror by its count
                l (<>a @ 'shr b a)
                x <>>s
                (? (!(<>>l = x) || !(rotp? x)) 'no
                   (: w (rotw g env x)
                      (? !w 'no
                         (: cs <>>>s cl <>>>l
                            ks (rotk g cs) kl (rotk g cl)
                            (? (charm? ks && charm? kl)
                                (? (ks + kl = w && 0 < ks && ks < w)
                                   (cgrimm g env x w ks wnt) 'no)
                               (charm? ks || charm? kl) 'no
                               (rotc? g w cl cs) (cgrvar g env x w cs ())   ; rotr: ror by the shr count
                               (rotc? g w cs cl) (cgrvar g env x w cl 1)    ; rotl: ror by the negated shl count
                               'no)))))))))
   (cgbin g env e wnt)
    (: op <>e
       lhs <>>e rhs <>>>e
       ; lazy left-then-right: the left parks before the right evaluates. the destination die aims a load-shaped left
       ; (dot/moor/deref) at its park -- one aim per spine, or the pool drains top-down; a call, a shift or a constant right bars it
       pk (? (!(two? lhs && elem <lhs '(dot moor deref)) ||
              callish? lhs || callish? rhs ||
              elem op '(shl shr) || two? (knum g rhs)) ()
             (ralloc g))
       a (cgexpr g env lhs pk)
       _ (? (pk && !(!(bad? a) && rpeq? g (vreg a) pk)) (rfree g pk) ())
       (? (bad? a) 'bad
          (gcplx? (vty a)) (cgcx g env op a rhs)    ; a complex left: the complex lane (parse lifted a real right already)
          ; a variable shift count is pinned to r1 (holo's contract)
          (elem op '(shl shr) && pair? g (vty a))    ; a pair shift keeps the left type
           (: kind (? (op = 'shl) 'shl (usg? (vty a)) 'shr 'sar)
              kc (knum g rhs)
              (? (two? kc)
                  (mkv (vty a) 'r0 (tor0 g a + pshiftc kind <kc))
                 (: b (cgexpr g env rhs ())
                    (? (bad? b) 'bad
                       (mkv (vty a) 'r0 (tor0 g a + spush2 +
                                         tor0 g b + '((mov r2 r0)) + spop2 'r0 'r1 +
                                         pshiftv g kind))))))
          (elem op '(shl shr) && d128? (vty a))          ; a wide shift keeps the left type
           (? !(w128? g) (no128 g)
              (: kind (? (op = 'shl) 'shl128 (usg? (vty a)) 'shr128 'sar128)
                 vknd (? (op = 'shl) 'shl128v (usg? (vty a)) 'shr128v 'sar128v)
                 kc (knum g rhs)
                 (? (two? kc)
                     (? ((<kc < 0) || (127 < <kc)) 'bad
                        (<kc = 0) (mkv (vty a) 'r0 (tor0 g a))
                        (mkv (vty a) 'r0 (tor0 g a + [[kind <kc]])))
                    (: b (cgexpr g env rhs ())
                       (? (bad? b) 'bad
                          (mkv (vty a) 'r0 $
                           tor0 g a + wpush + tor0 g b +
                            '((mov r1 r0) (ld r0 sp 0) (ld r2 sp 8)) +   ; count -> cl, the pair back
                            wdrop + [[vknd]]))))))
          (elem op '(shl shr))
           (: uL (usg? (vty a))                             ; a `>>` on an unsigned left operand is logical (shr, not sar)
              ; << carries out of a 32-bit unsigned like + - * do, so it re-narrows; >> stays inside a canonical value
              u32 ((op = 'shl) && u32? g (vty a))
              (nar r) (? u32 [['zx4 r]] ())
              rt (? (u32? g (vty a)) 'uint uL 'ulong 'long) ; the shift result keeps the left operand's type
              iop (? (op = 'shl) 'shl (? uL 'shr 'sar))
              vop (? (op = 'shl) 'shlv (? uL 'shrv 'sarv))
              kc (knum g rhs)
              (? (two? kc)
                  (? (wr? g (vreg a))
                     (mkv rt (vreg a) (vfs a + [[iop (vreg a) <kc]] + nar (vreg a)))
                     (: rd (wnt || rdst g (vreg a))    ; a borrowed home shifts a copy (no 3-address shift)
                        (mkv rt rd (vfs a + [['mov rd (vreg a)] [iop rd <kc]] + nar rd))))
                 (: b (cgexpr g env rhs ())
                    (? (bad? b) 'bad
                       (: af (tor0 g a)
                          bf (tor0 g b)
                          (mkv rt 'r0 (af + cshut g bf + [[vop 'r0 'r1]] + nar 'r0)))))))
          (: ta (vty a)
             ; a constant right rides the immediate lane; a constant left swaps (commutative) or mirrors (rflip) onto the right
             imr (: kr (knum g rhs)
                    (? (!(flo? ta) && two? kr && !(ptr? ta && gvarr? <>ta))
                       (immop g op a ta <kr <>kr wnt) 'no))
             (? !(= imr 'no) imr
                (: kl (? (elem op '(+ * & | ^ eq ne lt le gt ge)) (knum g lhs) ())
                   iml? (!(flo? ta) && two? kl)
                   ah (? (iml? || flo? ta || callish? rhs || llt? ta || d128? ta) 'sh
                         (vpark g env lhs a))       ; a pair lhs keeps the shuttle (no pool park)
                   ; the wide pair park: a d128 left steps into two pool registers allocated before the right evaluates;
                   ; a callish right keeps the cell (a call clobbers the pool), / % too (the divide dance owns it)
                   wpk (? (w128? g && d128? ta && !(callish? rhs) &&
                           elem op '(+ - * & | ^ eq ne lt le gt ge))
                          (: rl (ralloc g)
                             (? !rl ()
                                (: rh (ralloc g)
                                   (? rh [rl rh] (: _ (rfree g rl) ())))))
                          ())
                   b (cgexpr g env rhs ())
                   (? (bad? b) 'bad
                      (: tb (vty b)
                         ta9 (numty9 lhs ta)   ; C's type for a literal, read through
                         tb9 (numty9 rhs tb)   ; its written face (-1, ~0) -- see numty9
                         av (? (= ah 'sh) a ah)
                         ; the memory shuttle (shut1): left in r1, right in r0
                         (shut z9)
                          (: mid (: af9 (tor0 g av)       ; built first (the standing free order); the ride drops it
                                    bf (tor0 g b)
                                    (shut1 g av af9 bf))
                             back '((mov r0 r1))
                             pa (ptr? ta) pb (ptr? tb)
                             unsg (cmpu g ta9 tb9)                      ; divide and compare take the common type's signedness -- see cmpu
                             u32 (u32bin? g ta9 tb9)                  ; a 32-bit unsigned result wraps -- see u32bin?
                             nar (? u32 '((zx4 r0)) ())               ; the shuttle always lands in r0 (back)
                             nty (? u32 'uint 'long)
                             (? (d128? ta || d128? tb)
                                 ; the wide shuttle: the left rides its cell, the right the r2:r0 protocol; a product with both hi halves zero is one mulq
                                 (? !(w128? g) (no128 g)
                                    (pa || pb) 'bad
                                    (: rt (wbin ta tb)
                                       w? (two? wpk)
                                       midw (? w? (as128 g av + ([['mov <wpk 'r0] ['mov <>wpk 'r2]] + as128 g b))
                                               (as128 g av + (wpush + as128 g b)))
                                       res (op @
                                            '+ (mkv rt 'r0 (midw + (? w? [['a128r <wpk <>wpk]] ('((a128 sp)) + wdrop))))
                                            '- (mkv rt 'r0 (midw + (? w? [['s128r <wpk <>wpk]] ('((s128 sp)) + wdrop))))
                                            '* (: zl (d128? ta ? (zext128? (vfs av)) (usg? ta9 || ptr? ta9))
                                                  zr (d128? tb ? (zext128? (vfs b)) (usg? tb9 || ptr? tb9))
                                                  (? (zl && zr)                 ; hi halves zero: one mulq, the park needs only lo
                                                     (mkv rt 'r0 (? w? (as128 g av + ([['mov <wpk 'r0]] + (tor0 g b + [['mw128r <wpk]])))
                                                                   (as128 g av + (wpush + (tor0 g b + ('((mw128 sp)) + wdrop))))))
                                                     (mkv rt 'r0 (midw + (? w? [['m128r <wpk <>wpk]] ('((m128 sp)) + wdrop))))))
                                            ('| || '& || '^)
                                             (: w9 (irop op)
                                                (mkv rt 'r0 (midw + (? w? [[w9 'r0 'r0 <wpk] [w9 'r2 'r2 <>wpk]]
                                                               (['(ld r1 sp 0) [w9 'r0 'r0 'r1] '(ld r1 sp 8) [w9 'r2 'r2 'r1]] + wdrop)))))
                                            ('eq || 'ne || 'lt || 'le || 'gt || 'ge)
                                             (mkv 'long 'r0 (midw + (? w? [['c128r (scc op (= rt 'u128)) <wpk <>wpk]]
                                                               ([['c128 (scc op (= rt 'u128)) 'sp]] + wdrop))))
                                            ('/ || '%)
                                             ; u128 by a divisor with a provably-zero high half only (dv128's two-step divq is unsigned)
                                             (: zr (? (d128? tb) (zext128? (vfs b))
                                                      (two? rhs && (= <rhs 'num) && 0 <= <>rhs) 1
                                                      (usg? tb9 || ptr? tb9))
                                                (? (!zr || !(= rt 'u128)) 'bad
                                                   (mkv rt 'r0 (midw + [[(op @ '/ 'dv128 'rm128) 'sp]] + wdrop))))
                                            'bad)
                                       _ (w? ? (rfree g <wpk, rfree g <>wpk))
                                       res))
                                (t32? g && !(pa || pb) && (llt? ta || llt? tb))
                                 ; the pair shuttle: both sides widen to r0:r1, the left pops to r2:r3
                                 (: mid2 (asll g av + spush2 + asll g b + spop2 'r2 'r3)
                                    ; helper-call staging: the numerator (left) lands r0:r1, the denominator r2:r3 -- the pair-argument places
                                    mid2d (asll g av + spush2 + asll g b
                                           + '((mov r2 r0) (mov r3 r1)) + spop2 'r0 'r1)
                                    rt (ubin !(t32? g) ta tb)
                                    (op @ '+ (mkv rt 'r0 (mid2 + '((adds r0 r2 r0) (adc r1 r3 r1))))
                                          '- (mkv rt 'r0 (mid2 + '((subs r0 r2 r0) (sbc r1 r3 r1))))
                                          '*
                                          (? (v6m? g)   ; no umull/mla on v6-M: the runtime's exact helper (commutative, either staging)
                                             (mkv rt 'r0 (mid2 + '((call __aeabi_lmul))))
                                             (mkv rt 'r0 (mid2 + '((imul r3 r3 r0) (mla r3 r2 r1 r3)
                                                                   (umull r0 r12 r2 r0) (add r1 r12 r3)))))
                                         ('| || '& || '^)
                                          (: w9 (irop op)
                                             (mkv rt 'r0 (mid2 + [[w9 'r0 'r2 'r0] [w9 'r1 'r3 'r1]])))
                                         '/
                                          ; __divdi3 etc., not aeabi's uldivmod (two answers, which no C function spells). the backend's expansion
                                          ; is unsigned and no thumb has a 64-bit divide, so a signed pair divide takes rt.c's helper on every seat
                                          (? (v6m? g || !unsg)
                                             (mkv rt 'r0 (mid2d + [['call (? unsg '__udivdi3 '__divdi3)]]))
                                             (mkv rt 'r0 (mid2 + '((udivll)))))
                                         '%
                                          (? (v6m? g || !unsg)
                                             (mkv rt 'r0 (mid2d + [['call (? unsg '__umoddi3 '__moddi3)]]))
                                             (mkv rt 'r0 (mid2 + '((uremll)))))
                                         ('eq || 'ne || 'lt || 'le || 'gt || 'ge)
                                          (: cf (prel g op unsg)
                                             (mkv 'long 'r0 (mid2 + <>cf + [['set <cf 'r0]])))
                                         'bad))
                                (op = '+)
                                 ; ptr + idx: one leax at a machine scale, imul/add for odd sizes; a VLA pointee re-evaluates its dim here
                                 (? (pa && pb) 'bad
                                    (pa && gvarr? <>ta)
                                     (: vt <>ta                    ; mid ran: ptr r1, idx r0 -- park before the dim eval
                                        dv (: pk (spush 'r1 + spush 'r0)
                                              de (cgexpr g env (varn vt) ())
                                              (? (bad? de) 'bad
                                                 (: es (tsz g (varel vt))
                                                    (mid + pk + asint g de +
                                                     (? (1 < es) (imby g 'r0 es) ()) +
                                                     spop 'r2 + '((imul r2 r2 r0)) +
                                                     spop 'r1 + '((add r1 r1 r2) (mov r0 r1))))))
                                        (? (bad? dv) 'bad (mkv ta 'r0 dv)))
                                    (pb && gvarr? <>tb)
                                     (: vt <>tb
                                        dv (: pk (spush 'r0 + spush 'r1)       ; ptr r0, idx r1 here
                                              de (cgexpr g env (varn vt) ())
                                              (? (bad? de) 'bad
                                                 (: es (tsz g (varel vt))
                                                    (mid + pk + asint g de +
                                                     (? (1 < es) (imby g 'r0 es) ()) +
                                                     spop 'r2 + '((imul r2 r2 r0)) +
                                                     spop 'r1 + '((add r1 r1 r2) (mov r0 r1))))))
                                        (? (bad? dv) 'bad (mkv tb 'r0 dv)))
                                    pa (: sz (tsz g <>ta)
                                          (? (elem sz '(1 2 4 8))
                                             (mkv ta 'r0 (mid + [['leax 'r0 'r1 'r0 sz 0]]))
                                             (mkv ta 'r0 (mid + (? (1 < sz) (imby g 'r0 sz) ()) +
                                                          ('((add r1 r1 r0)) + back)))))
                                    pb (: sz (tsz g <>tb)
                                          (? (elem sz '(1 2 4 8))
                                             (mkv tb 'r0 (mid + [['leax 'r0 'r0 'r1 sz 0]]))
                                             (mkv tb 'r0 (mid + (? (1 < sz) (imby g 'r1 sz) ()) +
                                                          ('((add r1 r1 r0)) + back)))))
                                    (mkv nty 'r0 (mid + '((add r1 r1 r0)) + back + nar)))
                                (op = '-)
                                 (? (pa && pb)
                                     (? (tsz g <>ta = tsz g <>tb)
                                        ; a pointer difference: the byte gap (left r1, right r0) over the pointee size -- a shift at a power of two, a signed divide else
                                        (: esz (tsz g <>ta)
                                           (mkv 'long 'r0 (mid + '((sub r1 r1 r0)) +
                                                           (? (esz <= 1) back
                                                              (pow2? esz) (back + [['sar 'r0 (lg2 esz)]])
                                                              [['li 'r0 esz] '(div r1 r1 r0) '(mov r0 r1)]))))
                                        'bad)
                                    pa (mkv ta 'r0 (mid + (? (1 < tsz g <>ta)
                                                         (imby g 'r0 (tsz g <>ta)) ()) +
                                                    ('((sub r1 r1 r0)) + back)))
                                    pb 'bad
                                    (mkv nty 'r0 (mid + '((sub r1 r1 r0)) + back + nar)))
                                (: tail (? (elem op '(* & | ^)) [[(irop op) 'r1 'r1 'r0]]
                                           ; a mixed int/uint divide runs at uint width: znrw first
                                           (op = '/) (znrw g ta9 tb9 'r1 'r0 + [[(? unsg 'udiv 'div) 'r1 'r1 'r0]])
                                           (op = '%) (znrw g ta9 tb9 'r1 'r0 + [[(? unsg 'urem 'rem) 'r1 'r1 'r0 'r3]])
                                           'bad)
                                   m32 (u32 && (op = '*))              ; only the multiply here can carry
                                   (? !(bad? tail)
                                      (mkv (rbin g ta9 tb9) 'r0
                                           (mid + tail + back + (? m32 nar ())))
                                      (elem op '(eq ne lt le gt ge))
                                       (mkv 'long 'r0 (mid + znrw g ta9 tb9 'r1 'r0 +
                                                       ['(cmp r1 r0) ['set (scc op unsg) 'r0]]))
                                      'bad))))
                         iml (? (iml? && !(flo? tb)) (immop g (rflip op) b tb <kl <>kl wnt) 'no)
                         (? !(= iml 'no) iml
                            ((flo? ta || flo? tb) && (d128? ta || d128? tb))                ; wide meets double
                             (nolane g "a wide integer is not mixed with a double")
                            (flo? ta || flo? tb)
                             ; the double lane: both to double, f1 = left, f0 = right
                             (: af (asflo g av)
                                mid (fshut g af (asflo g b))
                                (op @ '+ (mkv 'double 'r0 (mid + '((addsd f0 f1))))
                                    '* (mkv 'double 'r0 (mid + '((mulsd f0 f1))))
                                    '- (mkv 'double 'r0 (mid + '((subsd f1 f0) (movsd f0 f1))))
                                    '/ (mkv 'double 'r0 (mid + '((divsd f1 f0) (movsd f0 f1))))
                                   ; unordered (NaN) answers false for every relation but !=. x64's above/ae read cf=0, which unordered sets,
                                   ; so lt/le compare swapped and eq/ne carry the parity bit (fsete/fsetn); a64's gt/ge are unordered-false natively
                                   ('lt || 'le || 'gt || 'ge)   ; lt/le compare swapped so the sense rides gt/ge
                                    (: swp (elem op '(lt le))
                                       (mkv 'long 'r0 (mid + [['ucomisd (swp ? 'f0 'f1) (swp ? 'f1 'f0)]
                                                              ['set (? (elem op '(lt gt)) (arm? g ? 'gt 'above)
                                                                        (arm? g) 'ge 'ae) 'r0]])))
                                   'eq (mkv 'long 'r0 (mid + ('((ucomisd f1 f0)) + fsete)))
                                   'ne (mkv 'long 'r0 (mid + ('((ucomisd f1 f0)) + fsetn)))
                                   'bad))
                            ; the register lane: both values live, 3-address combine
                            (: pa (ptr? ta) pb (ptr? tb)
                               ; live ptr + idx at a machine scale: one leax (reads both sources before writing, so any alias); a VLA pointee has no static scale
                               vpt ((pa && gvarr? <>ta) || (pb && gvarr? <>tb))
                               lxsz (? !(op = '+) () (pa && pb) () vpt ()
                                       pa (: s9 (tsz g <>ta) (elem s9 '(1 2 4 8) ? s9))
                                       pb (: s9 (tsz g <>tb) (elem s9 '(1 2 4 8) ? s9)))
                               (? (= ah 'sh) (shut ())
                                  vpt (shut ())
                                  ((pa || pb) && !lxsz) (shut ())
                                  (t32? g && llt? tb) (shut ())       ; a pair right: the pair shuttle (widen the park)
                                  (d128? tb) (shut ())                ; a wide right: the wide shuttle (widen the park)
                                  lxsz
                                   (: rA (vreg ah) rB (vreg b)
                                      rd (wnt || rdst g rA)
                                      fs (vfs ah + vfs b
                                          + [['leax rd (? pa rA rB) (? pa rB rA) lxsz 0]])
                                      _ (rfree g rB) _ (? (rpeq? g rd rA) () (rfree g rA))
                                      (mkv (? pa ta tb) rd fs))
                                  (: rA (vreg ah) rB (vreg b)
                                     cunsg (cmpu g ta9 tb9)
                                     pre (vfs ah + vfs b)
                                     (? (elem op '(eq ne lt le gt ge))
                                         ; a mixed int/uint compare owes a zx4, and rA/rB may be homes: the shuttle owns the copies
                                         (? (two? (znrw g ta9 tb9 'r1 'r0)) (shut ())
                                            (: rd (wnt || rdst g rA)   ; set runs after the cmp: rd may alias rB
                                               fs (pre + [['cmp rA rB] ['set (scc op cunsg) rd]])
                                               _ (rfree g rB) _ (? (rpeq? g rd rA) () (rfree g rA))
                                               (mkv 'long rd fs)))
                                        (elem op '(+ - * & | ^))
                                         (: iop2 (irop op)
                                            rd (? (wnt && !(rpeq? g wnt rB)) wnt (rdst g rA))
                                            u32 (elem op '(+ - *) && u32bin? g ta9 tb9)
                                            ; holo reorders a commutative rd == rB; sub cannot, and a borrowed left with a dry pool lands rd on rB's r0
                                            (? ((op = '-) && rpeq? g rd rB) (shut ())
                                               (: fs (pre + [[iop2 rd rA rB]] + (? u32 [['zx4 rd]] ()))
                                                  _ (rfree g rB) _ (? (rpeq? g rd rA) () (rfree g rA))
                                                  (mkv (rbin g ta9 tb9) rd fs))))
                                        (shut ())))))))))))))

   ; r3 (rbx) is callee-saved under SysV and gen uses it (callr park, va_arg's walk): every fn saves it at slot -8
   pro4 '((push r4) (mov r4 sp))                    ; the x64 frame link (unframe strips it; repack requires it)
   sav3 '(st r4 -8 r3)                              ; ..and the rbx save under it
   epi '((ld r3 r4 -8) (mov sp r4) (pop r4) (ret))
   ; the a64 twin: lr pushed before fp (bl clobbers it), no rbx slot (x3 is caller-saved), and the sp hop
   ; rides lea because mov to/from sp is ORR (XZR at 31). cgstmt/build read the target's epilogue off g 'epi
   pro-a64 '((push lr) (push fp) (lea fp sp 0))
   epi-a64 '((lea sp fp 0) (pop fp) (pop lr) (ret))
   ; the thumb2 vararg twin: drops the r0-r3 block the prologue pushed under fp/lr
   epi-t32va '((lea sp fp 0) (pop fp) (pop lr) (add sp sp 16) (ret))
   epi-rv-va '((lea sp fp 0) (pop fp) (pop lr) (add sp sp 64) (ret))                   ; drop the a0-a7 block
   ; the soft-double pass (sp64, an SP-only FPU): f64 arithmetic/compare/convert lowers to gcc's __aeabi_* helper through a
   ; 32-byte sp cell blanketing r0-r3 (above sp: an irq frame owns the space below); d-regs need no save, moon stages doubles only in f0/f1/f15
   sf-bin {'addsd '__aeabi_dadd 'subsd '__aeabi_dsub
           'mulsd '__aeabi_dmul 'divsd '__aeabi_ddiv}
   ; cc -> (helper sense): 'ne means helper-true holds the cc; 'eq negates (le = !(a>b), lt = !(a>=b), unordered-true like the flags)
   (sf-cc cc) (cc @ 'gt '(__aeabi_dcmpgt ne)
                    'ge '(__aeabi_dcmpge ne)
                    'eq '(__aeabi_dcmpeq ne)
                    'ne '(__aeabi_dcmpeq eq)
                    'le '(__aeabi_dcmpgt eq)
                    'lt '(__aeabi_dcmpge eq))
   sf-save '((sub sp sp 32) (st sp 0 r0) (st sp 4 r1) (st sp 8 r2) (st sp 12 r3))
   sf-rest '((ld r0 sp 0) (ld r1 sp 4) (ld r2 sp 8) (ld r3 sp 12) (add sp sp 32))
   (sf-slot r) (r @ 'r0 0 'r1 4 'r2 8 'r3 12 -1)
   ; the v6-M face: no fpu at all, so f0/f1/f15 rewrite onto the frame cells cgfn pinned (fc0/fc1/fc15) and the
   ; transfers become word moves through a saved low temp (r3, or r2 when the base is r3); no cell crosses a frame
   (fcell g f) (f @ 'f0 (peep g 'fc0 0) 'f1 (peep g 'fc1 0)
                   'f15 (peep g 'fc15 0)    (scare 'soften6-freg f))
   (nxr r) (r @ 'r0 'r1 'r1 'r2 'r2 'r3 (scare 'soften6-pair r))
   (pl6 g f lo) (: c (fcell g f) [['ld lo 'r4 c] ['ld (nxr lo) 'r4 (c + 4)]])   ; cell -> gp pair
   (ps6 g f lo) (: c (fcell g f) [['st 'r4 c lo] ['st 'r4 (c + 4) (nxr lo)]])   ; gp pair -> cell
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
   ; one walker, the transfer kit is the difference: v6m doubles live in frame cells, sp64's in d-registers
   ; (the SP FPU loads and stores f64 fine, so its f-memory ops stay)
   (soften g fs)
    (: w6 (v6m? g)
       (? !(w6 || sp64? g) fs
          (: (gd d9 lo) (? w6 (pl6 g d9 lo) [['movqrx lo d9]])   ; double -> the gp pair at lo
             (pd d9) (? w6 (ps6 g d9 'r0) [['movqxr d9 'r0]])   ; the r0:r1 pair -> double
             (gs d9) (? w6 [['ld 'r0 'r4 (fcell g d9)]]         ; single bits -> r0
                        [['stss 'sp 16 d9] '(ld r0 sp 16)])
             (ps d9) (? w6 [['st 'r4 (fcell g d9) 'r0]]         ; r0 -> the single's home
                        ['(st sp 16 r0) ['ldss d9 'sp 16]])
             (mv dD dS)                                           ; movsd: double -> double
              (? w6 (: cd (fcell g dD) cs (fcell g dS)
                       ['(sub sp sp 16) '(st sp 0 r3)
                         ['ld 'r3 'r4 cs] ['st 'r4 cd 'r3]
                         ['ld 'r3 'r4 (cs + 4)] ['st 'r4 (cd + 4) 'r3]
                         '(ld r3 sp 0) '(add sp sp 16)])
                 ['(sub sp sp 16) ['stsd 'sp 0 dS] ['ldsd dD 'sp 0] '(add sp sp 16)])
             scc (? w6 'soften6-cc 'soften-cc)
             suc (? w6 'soften6-ucomisd 'soften-ucomisd)
             (go (f . r))
              (? !(two? f) (f . go r)
                 (: op <f
                    h9 (sf-bin op)
                    (? h9                             ; (op fD fS): fD = fD op fS
                        (sf-save + gd <>f 'r0 +
                         gd <>>f 'r2 + [['call h9]] + pd <>f + sf-rest + go r)
                       (op = 'movsd) (mv <>f <>>f + go r)
                       (w6 && op = 'ldsd) (m2c g <>f <>>f <>>>f + go r)
                       (w6 && op = 'stsd) (c2m g <>f <>>f <>>>f + go r)
                       (w6 && op = 'ldss) (w2c g <>f <>>f <>>>f + go r)
                       (w6 && op = 'stss) (c2w g <>f <>>f <>>>f + go r)
                       (w6 && op = 'movqrx) (pl6 g <>>f <>f + go r)
                       (w6 && op = 'movqxr) (ps6 g <>f <>>f + go r)
                       (elem op '(cvtsi2sd cvtui2sd))   ; (op fD rS)
                        (: sl (sf-slot <>>f)
                           (sf-save +
                            (? (sl < 0) [['mov 'r0 <>>f]] [['ld 'r0 'sp sl]]) +
                            [['call (? (op = 'cvtsi2sd) '__aeabi_i2d '__aeabi_ui2d)]] +
                            pd <>f +
                            sf-rest + go r))
                       (elem op '(cvttsd2si cvttsd2ui))   ; (op rD fS)
                        (: sl (sf-slot <>f)
                           (sf-save + gd <>>f 'r0 +
                            [['call (? (op = 'cvttsd2si) '__aeabi_d2iz '__aeabi_d2uiz)]] +
                            (? (sl < 0) [['mov <>f 'r0]] [['st 'sp sl 'r0]]) +   ; through the save slot: the restore lands it
                            sf-rest + go r))
                       (op = 'cvtss2sd)               ; (op fD fS): single bits in, a pair out
                        (sf-save + gs <>>f + '((call __aeabi_f2d)) + pd <>f + sf-rest + go r)
                       (op = 'cvtsd2ss)               ; (op fD fS): a pair in, the narrowed word home
                        (sf-save + gd <>>f 'r0 + '((call __aeabi_d2f)) + ps <>f + sf-rest + go r)
                       (op = 'ucomisd)
                        (: args (sf-save + gd <>f 'r0 + gd <>>f 'r2)
                           n1 (? (two? r) <r ())
                           (? (two? n1 && (= <n1 'br))
                               (: hs (sf-cc <>n1)
                                  _ (? (two? hs) 0 (scare scc n1))
                                  (args + [['call <hs] '(cmp r0 0)] + sf-rest + [['br <>hs <>>n1]] + go >r))
                              (two? n1 && (= <n1 'set))
                               (: n2 (? (two? >r) <>r ())
                                  n3 (? (two? >r && (two? >>r)) <>>r ())
                                  dance (two? n2 && (= <n2 'set) && elem <>n2 '(p np) &&
                                         two? n3 && elem <n3 '(and or))
                                  hs (sf-cc <>n1)
                                  _ (? (two? hs) 0 (scare scc n1))
                                  (args + [['call <hs] '(cmp r0 0)] + sf-rest + [['set <>hs <>>n1]] + go (? dance >>>r >r)))
                              (scare suc n1)))
                       (f . go r))))
             (go fs))))
   ; the v6-M twin: pop reaches r0..r7/pc, not lr, so the return is pop pc; r4 is the bottom base (t16slots), under fp
   epi-t16 '((lea sp fp 0) (pop r4) (pop fp) (pop pc))
   ; the v6-M vararg twin: pop pc could not drop the r0-r3 block after it, so lr pops into r3 (bit0 set, so bx stays thumb)
   epi-t16va '((lea sp fp 0) (pop r4) (pop fp) (pop r3) (add sp sp 16) (jmpr r3))
   ; the exit tests: a jmp out of the fn is an exit too, but only the label table can tell it from a local one (xjmp?)
   (retx? f) (two? f && (= <f 'ret || (= <f 'pop && (= <>f 'pc))))
   (xit? f) (retx? f || (two? f && (= <f 'jmpr)))
   (xjmp? f t)                                      ; a jmp/br to no label of ours, t the fn's label table: a sibcall leaving
    (: tg (? !(two? f) () (= <f 'jmp) <>f (= <f 'br) <>>f ())
       (tg && (= (peep t tg 'no) 'no)))
   (qtwin r)                                        ; ['rN+1], a 32-bit pair's high half | ()
    (: (go l) (? !(two? >l) ()                      ; not a gp name (a probe's placeholder): none
                 (= <l r) [<>l]
                 (go >l))
       (go qfile))
   (rdsp g f)                                         ; -> [reads defs pure?] | 'bar
    (: op <f
       (rg1 x) (? (charm? x) () [x])
       (? (op = 'li) [() [<>f] 1]
          (op = 'mov) [[<>>f] [<>f] 1]
          (elem op aluops)
           (? (<>f = 'sp) [() () ()]      ; sp motion touches no gp register
              [(rg1 <>>f + rg1 <>>>f) [<>f] 1])
          (elem op flagops) [(rg1 <>>f + rg1 <>>>f) [<>f] ()]
          (op = 'push) [[<>f] () ()]
          ; v6-M returns through pop pc: an exit, reading what one owes back (lvtx says the same), else the return value dies as a dead set
          ((op = 'pop) && (= <>f 'pc)) [((lvret g) + (csregs g)) [<>f] ()]
          (op = 'pop) [() [<>f] ()]
          (elem op '(shl shr sar rol ror ror4)) [[<>f] [<>f] 1]
          (elem op ldops9) [[<>>f] [<>f] 1]
          (elem op gstops) [[<>f <>>>f] () ()]
          (elem op stxops) [[<>f <>>f (f 5)] () ()]
          (elem op siops) [[<>f] () ()]
          (op = 'cmpm) [([<>f] + rg1 <>>>f) () ()]
          (op = 'cmprm) [[<>f <>>f] () ()]
          (elem op leaops) [[<>>f] [<>f] 1]
          (elem op xops) [[<>>f <>>>f] [<>f] 1]
          (op = 'la) [() [<>f] 1]
          (op = 'set) [() [<>>f] 1]
          (elem op '(cmp test)) [(rg1 <>f + rg1 <>>f) () ()]
          (elem op unops) [[<>f] [<>f] 1]
          ; the 32-bit pair moves (vmov Df, Rlo, Rlo+1) name only the low half, so qtwin spells the high one:
          ; an unspelled read is a live value deaddef takes away, an unspelled def a stale one the forwarders keep
          (op = 'movqxr) [([<>>f] + (t32? g ? (qtwin <>>f) ())) () ()]
          (op = 'movqrx) [() ([<>f] + (t32? g ? (qtwin <>f) ())) 1]
          ; the numbered single moves: the s-slot write is a side effect nothing here sees, so movsnxr is never droppable
          (op = 'movsnxr) [[<>>f] () ()]
          (op = 'movsnrx) [() [<>f] 1]
          (elem op '(cvtsi2sd cvtui2sd)) [[<>>f] () ()]
          (elem op '(cvttsd2si cvttsd2ui)) [() [<>f] ()]
          (elem op fldops) [[<>>f] () ()]
          (elem op fstops) [[<>f] () ()]
          (elem op xmmops) [() () ()]
          (elem op divops)
           [(rg1 <>>f + rg1 <>>>f) '(r0 r1 r2 r3) ()]
          (elem op llops) ['(r0 r1 r2 r3) '(r0 r1 r2 r3) ()]
          (elem op wmops) [[(f 3) (f 4)] [<>f <>>f] 1]
          (op = 'mla) [[<>>f <>>>f (f 4)] [<>f] 1]
          (op = 'clz) [[<>>f] [<>f] 1]
          (op = 'jmpt) [[<>f] () ()]           ; the table jump reads its register and nothing else
          ; the wide multiply also writes rax on x64 (one-operand mul; it saves rdx itself, so rdx stays unspelled)
          (elem op '(mulh umulh)) [[<>>f <>>>f] ([<>f] + (x64? g ? '(r0) ())) ()]
          ; a variable shift defines only its dest: x64's encoder wants cl but refuses any other register outright, so no
          ; move clobbers r1 -- and a claimed r1 def would read the pair lane's carry-in or as dead
          (elem op vshops) [[<>f <>>f] [<>f] ()]
          'bar))
   ; the a64 retarget renames by position, not symbol: x4 is also an argument register, so only the base slot's r4 becomes fp
   a4base (: t (foldl (\ t o (pin t o 2)) {} (ldops9 + fldops + xops + leaops + '(cmprm)))
           (foldl (\ t o (pin t o 1)) t (stops9 + stxops + siops + '(cmpm))))
   (a4ize fs)
    (: (go (f . u))
        (: bp (two? f ? (peep a4base <f -1) -1)
         (. (0 <= bp && f bp == 'r4 ? (reop f bp 'fp) f) (go u)))
     (go fs))
   ; v6-M slot retarget: loads/stores encode only positive immediates and sp moves around calls, so a second base r4
   ; sits at the frame bottom and each fp-negative slot becomes r4 + (frame + off). runs after a4ize, v6m only
   (t16reb f i bp fr)
    (? !(two? f) f
       ((? (i = bp) 'r4 (i = (bp + 1)) (fr + <f) <f) . t16reb >f (i + 1) bp fr))
   (t16slots (f . u) fr)
       (: bp (two? f ? (peep a4base <f -1) -1)
          (. (? (bp >= 0 && f bp == 'fp && f (bp + 1) < 0) (t16reb f 0 bp fr) f)
                (t16slots u fr)))
   ; v6m has no MOVW/MOVT: (la Rd lbl) becomes a literal-pool load over an R_ARM_ABS32 word. runs last, v6m only
   (t16la (f . u)) ((atom? f || <f != 'la ?  [f]
                      ['(align 4) ['lapool <>f] ['raw [['fix 4 'abs32 <>>f 0]]]])
                     + t16la u)
   ; the sibcall pass: (call F) followed by exactly the epilogue becomes epilogue + (jmp F); anything between keeps
   ; the call. gated per fn on g 'fesc: a frame address that becomes a value pins every call (a store's own lea does not)
   (leas? (f . u)) (two? f && <f = 'lea && <>>f = 'r4 ? 1 (leas? u))
   (escan g r) (: _ (? (two? r && leas? (vfs r)) (pin g 'fesc 1) ()) r)
   (unlean (f . u))
                     ((two? f && <f = 'lean ? ('lea . >f) f) . unlean u)
   (relean (f . u)) ; the inverse, for a splice that consumes the address itself (the overflow trio's &t)
    ((two? f && (<f = 'lea) ? ('lean . >f) f) . relean u)
   (epim? fs es) (? !(two? es) 1                  ; the next forms are exactly es (the target's epilogue)
                    !(two? fs) ()
                    (<fs = <es && epim? >fs >es))
   ; lw, the window rule: a frame lea since the last call boundary (`return f(&x)`) keeps that call a call.
   ; a join label between call and epilogue: the jump lands before it, label + epi stay for the other arm
   (lbl-epi? (f . u) ej) (two? f && <f = 'label ? (epim? u ej || lbl-epi? u ej))
   ; a join label then a jmp to a collected epilogue label is still ret position; label + jmp stay for the arms that join
   (lbl-jmp? (f . u) el)
    (two? f ? (<f @ 'label (lbl-jmp? u el)
                    ('jmp && el <>f) 1))
   ; elabs collects the labels that lead to the epilogue (a nested-ternary return leaves (call F)(jmp JOIN) arms);
   ; a label whose region is one jmp to a collected label counts too and may point forward, so elabsx iterates to a fixpoint
   (jmp-el? (('jmp x) . _) t) (t x)
   (elabs fs t ej) (? !(two? fs) t
                      (: f <fs
                         _ (? (two? f && (<f = 'label) &&
                               (epim? >fs ej ||
                                lbl-epi? >fs ej || jmp-el? >fs t))
                              (pin t <>f 1) ())
                         (elabs >fs t ej)))
   (elabsx fs t ej) (: n #(keys t)
                       t2 (elabs fs t ej)
                       (#(keys t2) = n ? t2 (elabsx fs t2 ej)))
   (butret es) (two? >es ? (<es . butret >es))          ; the epilogue's restore forms (the ret drops)
   (sibjmp g f ejx)                                 ; ejx = the epilogue this tail owes, restores first
    ; riscv's jal reaches only +-1MB, so its direct tail call borrows la's reach and the t4 park, loaded after the restores
    (? (rv64? g && (<f = 'call))
       (butret (peep g 'epi epi-a64) + [['la (pkr g) <>f] ['jmpr (pkr g)]])
       (<f = 'call) (butret ejx + [['jmp <>f]])
       ; ejx, never the epi-a64 constant: a cs-granted build pins its restores into g 'epi, and t32's vararg epilogue adds 16
       (a64? g) (butret ejx + '((jmpr r15)))                   ; the a64 epilogue never touches the x15 park
       (rv64? g) (butret (peep g 'epi epi-a64) + [['jmpr (pkr g)]])     ; riscv: the park (t4) survives the epilogue
       (t32? g) (butret ejx + [['jmpr (pkr g)]])             ; thumb2: the callr target parks in r12 (pkr), untouched by the epilogue
       ('((mov r10 r3)) + butret ejx + '((jmpr r10))))            ; park first: the x64 epilogue reloads r3
   ; skiprel peels the dead reloads after a ret-position call: a home's, or a roster reload into a pool reg;
   ; pool only -- a cs-reg ld here is the epilogue's own reload. the epim? check downstream keeps the peel honest
   (skiprel g fs hs)
    (? !(two? fs) fs
       (: f <fs
          (? !(two? f && elem <f ldops9 && (<>>f = 'r4)) fs
             (: h (filter (h2 \ (<h2 = <>f) && (<>h2 = <>>>f)) hs)   ; a seat serves several spans: match reg and slot
                (? (two? h) (skiprel g >fs hs)
                   (elem <>f (peep g 'pool0 ())) (skiprel g >fs hs)
                   fs)))))
   (sibs g (f . r) lw el hs ej crf)
    (: lw2 (two? f && <f = 'lea && <>>f = 'r4 || lw)
       cand (!lw2 && two? f && (<f = 'call && two? >f ||
                                <f = 'callr && (= <>f <>crf)))
       rr (? cand (skiprel g r hs) r)
       (? (cand && epim? rr ej)
           (sibjmp g f ej + sibs g (drop #ej rr) () el hs ej crf)
          (cand && lbl-epi? rr ej)
           (sibjmp g f ej + sibs g rr () el hs ej crf)
          (cand && (: nx <rr (two? nx && <nx = 'jmp && peep el <>nx ())))
           (sibjmp g f ej + sibs g >rr () el hs ej crf)
          (cand && lbl-jmp? rr el)
           (sibjmp g f ej + sibs g rr () el hs ej crf)
          (: _ (? (must? f) (scare 'musttail-not-a-tail [(g 'fn) f]) 0)   ; a marked call is owed its jump
             (f . sibs g r (? (two? f && elem <f '(call callr raw)) () lw2) el hs ej crf))))       ; raw: a builtin splice consumes its address like a call
   ; the musttail contract: a pre-slotted ret (clay's (ret e PRE)) marks its call (call F must) / (callr PK must);
   ; sibs spells the marked jump or scares instead of falling back. the marker dies with the rewrite
   (must? f) (two? f && elem <f '(call callr) && elem 'must >>f)
   (anymust? (a . u)) (must? a || anymust? u)
   (mustret g fs)                                   ; mark the last call/callr; none to mark refuses
    (: (go l) (? !(two? l) 'no
                 (: r (go >l)
                    (? !(= r 'no) (<l . r)
                       (: f <l (? (two? f && elem <f '(call callr)) (f + '(must) . >l) 'no)))))
       r (go fs)
       (? (= r 'no) (nolane g "a musttail return does not end in a call") r))
   (sibcall g fs) (? (g 'fesc || v6m? g)   ; v6m: the pop-pc epilogue cannot restore lr for a tail-jmp, so no sibcall
                      (anymust? fs ? (scare 'musttail-escape (g 'fn)), fs)
                     (: ej (peep g 'epi epi)
                      (sibs g fs () (elabsx fs {} ej) (g 'homes) ej ['callr (pkr g)])))

   ; frame elision: slots re-address off sp at off + K9 + D, K9 = K + the link bytes (8 x64, 32 a64) so a call at a
   ; 16-multiple D sees the alignment push r4 gave; scan proves D at every label. the glaze rides Ip in rbp, so rbp goes wherever it can
   uoff (: t (foldl (\ t o (pin t o 3)) {} (ldops9 + fldops + leaops + '(cmprm)))
           t (foldl (\ t o (pin t o 5)) t xops)
           t (foldl (\ t o (pin t o 2)) t (stops9 + siops + '(cmpm)))
         (foldl (\ t o (pin t o 4)) t stxops))
   ; rebuild a form with operand i9 replaced (the a4base/uoff seam every frame-rewriting pass lands on)
   (reop f i9 v) (: (go (a . u) i) ((i = i9 ? v a) . go u (i + 1)) (go f 0))
   ; the riscv slot rebase: fp links at the frame bottom (c.ld/c.sd want unsigned offsets), so every fp-relative
   ; displacement gains `frame`. after a4ize, riscv only. the displacement is uoff's position, never bp + 1 (an indexed op's index sits there)
   (rvreb f i up fr)
    (? !(two? f) f
       ((? (i = up) (charm? <f ? (fr + <f) (scare 'rv-slot-nonum f)) <f)
          . rvreb >f (i + 1) up fr))
   (rvslots fs fr)
    (? !(two? fs) ()
       (: f <fs
          bp (two? f ? (peep a4base <f -1) -1)
          up (two? f ? (peep uoff <f -1) -1)
          (. (bp >= 0 && up >= 0 && f bp = 'fp ? (rvreb f 0 up fr) f)
                (rvslots >fs fr))))
   ; the x64 frame prologue at fs's head (unframe strips it; repack requires it)
   (pro4? fs) (epim? >fs pro4)
   (unframe g fs)
    (: a64 (a64? g)
       fb (? a64 'fp 'r4)
       pro (? a64 (epim? >fs pro-a64) (pro4? fs))
       sf (fs (? a64 4 3))
       K (two? sf && <sf = 'sub && <>sf = 'sp && <>>sf = 'sp && charm? <>>>sf ? <>>>sf)
       body0 (drop (? a64 5 4) fs)
       ; the park lane (x64): a callr sib's (mov r3 X) .. (mov r10 r3) collapses to one mov at the unpark when nothing
       ; between mentions r3 or rewrites X -- then the fn never writes r3 and the rbx save/restores drop with the frame
       sv3 (!a64 && body0 0 = sav3)
       wind ('(mov li) + leaops + xops + aluops + ldops9)
       wina (wind + gstops + '(cmp test))
       (squeeze (f . r))
        (? !(two? f && <f = 'mov && (= <>f 'r3) && !(= <>>f 'sp))
           (f . squeeze r)
           (: X <>>f
              (win w n)                        ; forms between park and unpark -> count | 'no
               (? (!(two? w) || 8 < n) 'no
                  (: g2 <w
                     (? (g2 = '(mov r10 r3)) n
                        !(two? g2) 'no
                        (elem 'r3 >g2) 'no
                        !(elem <g2 wina) 'no
                        (elem <g2 wind && (= <>g2 X)) 'no
                        (win >w (n + 1)))))
              k (win r 0)
              (? (= k 'no) (f . squeeze r)
                 (: (take w n) (? (n < 1) (['mov 'r10 X] . squeeze (drop 1 w))
                                  (<w . take >w (n - 1)))
                    (take r k)))))
       body (: b2 (? sv3 (drop 1 body0) body0) (? a64 b2 (squeeze b2)))
       (epi3? l9)                                    ; l9 opens with a restore run -> its length | ()
        (: e3 (butret (? a64 epi-a64 epi))
           (? (epim? l9 e3) #e3
              (!a64 && epim? l9 >e3) 2                 ; the run past a dropped r3 reload
              ()))
       (clean? f2 bp)                                ; fb only at its base slot; a64 lr never
        (: (go e i) (? !(two? e) 1
                       (: x <e
                          (? (= x fb && !(i = bp)) ()
                             (a64 && (= x 'lr)) ()
                             (go >e (i + 1)))))
           (go f2 0))
       labt {}                               ; label -> the D every arrival agrees on
       (scan l D vs r3f live)                        ; -> 'no | (needs-sub r3-in-use)
        (? !(two? l) [vs r3f]
           (: n3 (epi3? l)
              (? n3 (scan (drop n3 l) 0 vs r3f live)
                 (: f <l
                    (? !(two? f) (scan >l D vs r3f live)
                       (<f = 'label)
                        (: d9 (peep labt <>f 'no9)
                           (? !(= d9 'no9)
                              (? (live && !(D = d9)) 'no (scan >l d9 vs r3f 1))
                              (: D2 (? live D 0)
                                 _ (pin labt <>f D2)
                                 (scan >l D2 vs r3f 1))))
                       (<f = 'jmp)
                        (: d9 (peep labt <>f 'no9)
                           (? (= d9 'no9) (: _ (pin labt <>f D) (scan >l D vs r3f ()))
                              !(D = d9) 'no
                              (scan >l D vs r3f ())))
                       (<f = 'br)
                        (: d9 (peep labt <>>f 'no9)
                           (? (= d9 'no9) (: _ (pin labt <>>f D) (scan >l D vs r3f live))
                              !(D = d9) 'no
                              (scan >l D vs r3f live)))
                       (xit? f)
                        (scan >l D vs (r3f || (!a64 && elem 'r3 >f)) ())
                       (elem <f '(raw push pop)) 'no
                       (elem <f '(call callr))                 ; a plain call rides: sp is as call-stable as r4 was, and
                        ; K9 (8 mod 16) + a 16-multiple D hand the ABI what push r4 did
                        (? a64 'no                                ; bl clobbers lr: the link stays
                           !(0 = (D & 15)) 'no
                           (scan >l D 1 (r3f || elem 'r3 >f) live))
                       (spadj? f && <f = 'sub) (scan >l (D + <>>>f) vs r3f live)
                       (spadj? f && <f = 'add)
                        (? ((D - <>>>f) < 0) 'no (scan >l (D - <>>>f) vs r3f live))
                       (elem <f '(sub add mov lea lean) && <>f = 'sp) 'no
                       (: bp (peep a4base <f -1)
                          (? !(clean? f bp) 'no
                             (scan >l D
                                   (? (0 <= bp && f bp == fb) 1 vs)
                                   (r3f || (!a64 && elem 'r3 >f))
                                   live))))))))
       vr (? (pro && charm? K) (scan body 0 () () 1) 'no)
       (? (g 'fpin) fs                              ; the frame's own address was taken: keep the link
          (= vr 'no || (!a64 && <>vr && !sv3)) fs    ; r3 in use with no save to ride
          (: r3f (!a64 && <>vr)
             vs (<vr || r3f)                         ; the save is a slot: r3f forces the sub
             K9 (K + (? a64 32 8))
             (radj f2 bp op9 D)                      ; the base slot -> sp, its displacement -> off+K+D
              (reop (reop f2 bp 'sp) op9 (f2 op9 + K + D))
             (rw l D)
              (? !(two? l) ()
                 (: n3 (epi3? l)
                    (? n3 ((? r3f [['ld 'r3 'sp ((K + D) - 8)]] ())
                           + ((? vs [['add 'sp 'sp (K9 + D)]] (? (0 < D) [['add 'sp 'sp D]] ()))
                              + rw (drop n3 l) 0))
                       (: f <l
                          (? !(two? f) (f . rw >l D)
                             (<f = 'label) (f . rw >l (peep labt <>f D))
                             (spadj? f && <f = 'sub) (f . rw >l (D + <>>>f))
                             (spadj? f && <f = 'add) (f . rw >l (D - <>>>f))
                             (: bp (peep a4base <f -1)
                                (. (? (0 <= bp && f bp == fb)
                                         (radj f bp (peep uoff <f -1) D)
                                         f)
                                      (rw >l D))))))))
             body2 (? r3f (sav3 . body) body)
             (<fs . (? vs (['sub 'sp 'sp K9] . rw body2 0) (rw body2 0))))))

   ; IR constant propagation: a straight-line abstract pass tracking known constants in registers, frame slots and
   ; stack cells, folding what it can back to li's. a known is the word's signed value; anything unrecognized invalidates everything
   (cfoldir g fs0)
    (: fb (fbase g)                         ; the frame-slot base (r4, or fp past a4ize)
       (fresh z9) {}                        ; reg/slot/cell -> (1 K) const | (2 rX) copy-of-register | ()
       W (8 * wsize g) M (W 2) H (M // 2)   ; the word: its bits, 2^W, 2^(W-1)
       (wrap v) (: u (v % M) u2 (u < 0 ? (u + M) u) (u2 < H ? u2 (u2 - M)))   ; two's complement, signed
       (uns v) (v < 0 ? (v + M) v)            ; ...and unsigned, for the below/above ccs and the logical shifts
       ; what an li of k costs: a64 movz + a movk per further nonzero 16-bit lane, x64 one mov -- a fold answers a li only up to two
       (licost k) (? !(a64? g) 1
                     (: (go u n) (? (u = 0) (n < 1 ? 1 n)
                                   (go (u // 65536) (0 = (u % 65536) ? n (n + 1))))
                        (go (uns k) 0)))
       (fold? k) (licost k <= 2)
       (rv t k) (t k)
       (rset t k v) (pin t k v)
       (kn? v) (two? v && <v = 1)            ; a known constant (never let a copy reach arithmetic)
       ; a const rides, a copy chases to its root register
       (rsv rg s) (: v (rv rg s) (two? v ? v [2 s]))
       ; the copy index ci: source register -> the (tag key) sites holding a copy; a write to d visits only those (a stale entry is harmless)
       (crec ci v tg k) (two? v && <v = 2 ?  (pin ci <>v ([tg k] . peep ci <>v ())))
       (kild ci rg sl ce d)
        (: (go1 (e . u))
                       (: t (<e @ 'g rg 's sl ce)
                          v (t <>e)
                          _ (two? v && <v = 2 && <>v = d ? (pin t <>e ()))
                          (go1 u))
           _ (go1 (ci d))
           (pin ci d ()))
       (defr ci rg sl ce d) (rset rg d (), kild ci rg sl ce d)
       ; rebuild the index for freshly joined tablets (small: agreed entries only)
       (mkci rg sl ce)
        (: ci {}
           (scan1 t tg (a . u)) (crec ci (t a) tg a, scan1 t tg u)
           _ (scan1 rg 'g (keys rg)) _ (scan1 sl 's (keys sl)) _ (scan1 ce 'c (keys ce))
           ci)
       (copyt t) (: t2 {}
                    (go1 ks) (? !(two? ks) t2 (pin t2 <ks (t <ks), go1 >ks))
                  (go1 (keys t)))
       ; the join: a key survives only where both sides know it and agree -- a fresh tablet
       (joint ta tb) (: t2 {}
                        (go1 ks) (? !(two? ks) t2
                                    (: k1 <ks va (peep ta k1 ()) vb (peep tb k1 ())
                                       _ (? (two? va && two? vb &&
                                             <va = <vb && <>va = <>vb)
                                            (pin t2 k1 va))
                                       (go1 >ks)))
                        (go1 (keys ta)))
       (alu op a b) (wrap (op @ 'add (a + b) 'sub (a - b) 'imul (a * b)
                                'and (a & b) 'or (a | b) (a ^ b)))
       ; the immediate shifts and rotates, count in [0, W) (ror4 rotates the low 32 and zero-extends)
       (shf op v k) (op @ 'shl (wrap (v * (k 2)))
                          'shr (wrap (uns v // (k 2)))
                          'sar (v >> k)
                          'ror4 (: u (uns v % 4294967296) p (k 2)
                                   ((u // p) + ((u % p) * ((32 - k) 2))))
                          (: k2 (op = 'rol ? ((W - k) % W) k) u (uns v) p (k2 2)   ; ror, rol = ror W-k
                             (wrap ((u // p) + ((u % p) * ((W - k2) 2))))))
       (shk? op k) (charm? k && 0 <= k && k < (op = 'ror4 ? 32 W))
       ; a constant division -> [k] | (): () where the machine would trap (a zero divisor, signed INT_MIN / -1),
       ; so that op stands. // truncates toward zero, which is C's /
       (dvk op a b)
        (: sg (elem op '(div rem))
           x (? sg a (uns a)) y (? sg b (uns b))
           (? (y = 0) ()
              (sg && (a = (0 - H)) && (b = -1)) ()
              [(wrap (? (elem op '(div udiv)) (// x y) (x - ((// x y) * y))))]))
       ; fold? rides in here: a division writes r0..r3, so keeping one with d alone invalidated would leave three stale knowns
       (dvfold rg op f)
        (: a (rv rg <>>f)
           b (? (charm? <>>>f) [1 (wrap <>>>f)] (rv rg <>>>f))
           k (? (kn? a && kn? b) (dvk op <>a <>b) ())
           (? (two? k && fold? <k) k ()))
       ; the one-register rewrites: negate, complement, the sign/zero extensions from 8/16/32
       (unop op v) (op @ 'neg (wrap -v) 'not (-v - 1)
                         (: n (op @ ('sx1 || 'zx1) 8 ('sx2 || 'zx2) 16 32)
                            u (uns v % (n 2))
                            (? (elem op '(zx1 zx2 zx4)) u
                               (u < ((n - 1) 2)) u
                               (u - (n 2)))))
       ccs9 '(eq ne lt le gt ge below be above ae)   ; the ccs a cmp decides (flag ccs stay)
       (ccev cc a b) (cc @ 'eq (a = b) 'ne !(a = b)
                           'lt (a < b) 'le (a <= b) 'gt (b < a) 'ge (b <= a)
                           'below (uns a < uns b) 'be (uns a <= uns b)
                           'above (uns b < uns a) (uns b <= uns a))   ; ae
       ; after an unconditional transfer everything to the next label is dead -- a folded ternary drops its arm
       (swallow fs) (? !(two? fs) ()
                       (: f <fs (? (two? f && <f = 'label) fs (swallow >fs))))
       (atlab? fs l) (two? fs && (: f <fs (two? f && <f = 'label && <>f = l)))
       ; misc: labels named by a form other than a control transfer (an asm splice can hold one); over-approximate, filled by bscan
       misc {}
       ; back-edge labels (a transfer below its target): a loop head joins an edge this linear pass never computes -- assume nothing
       backs (: seen {} bt {}
                (note ops) (? !(two? ops) 0
                              (: o <ops
                                 _ (? (nom? o) (pin misc o 1) (two? o) (note o))
                                 (note >ops)))
                (bscan l) (? !(two? l) bt
                             (: f <l
                                _ (f @ ('label a) (pin seen a 1)
                                      ('jmp j)   (seen j ? (pin bt j 1))
                                      ('br _ b)  (seen b ? (pin bt b 1))
                                      ('jmpt _ _ ts) (map (\ j (seen j ? (pin bt j 1))) ts)
                                      (two? f ? (note >f)))
                                (bscan >l)))
                (bscan fs0))
       ; pend: every forward transfer to L joins its state into pend[L], the label reads it back; the sp cursor must agree or the cells drop
       pend {}
       (pmerge l cur rg sl ce ci)
        (: old (peep pend l ())
           (? !(two? old) (pin pend l [cur (copyt rg) (copyt sl) (copyt ce) (copyt ci)])
              (: rg2 (joint <>old rg) sl2 (joint <>>old sl)
                 nce (? (<old = cur) (joint <>>>old ce) (fresh 0))
                 (pin pend l [<old rg2 sl2 nce (mkci rg2 sl2 nce)]))))
       ; lv: linearly live, () right after an unconditional transfer (the label then reads only its jump-in state)
       (go fs lv cur rg sl ce ci acc)
        (? !(two? fs) (rev acc)
           (: f <fs r >fs
              op (two? f ? <f)
              dk (? (elem op divops) (dvfold rg op f) ())   ; a foldable division's answer
              (? (op = 'label)
                  (: l1 <>f acc2 (f . acc)
                     (? (peep backs l1 ()) (go r 1 cur (fresh 0) (fresh 0) (fresh 0) (fresh 0) acc2)
                        (: pd (peep pend l1 ())
                           (? !(two? pd)
                               (? lv (go r 1 cur rg sl ce ci acc2)
                                  ; no edge in and the linear one cut: unreachable, drops with its label (a folded ternary's untaken arm)
                                  !(peep misc l1 ()) (go (swallow r) () cur rg sl ce ci acc)
                                  (go r 1 cur (fresh 0) (fresh 0) (fresh 0) (fresh 0) acc2))
                              !lv (go r 1 <pd <>pd <>>pd <>>>pd
                                         <>>>>pd acc2)
                              (: rg2 (joint <>pd rg) sl2 (joint <>>pd sl)
                                 ce2 (? (<pd = cur) (joint <>>>pd ce) (fresh 0))
                                 (go r 1 <pd rg2 sl2 ce2 (mkci rg2 sl2 ce2) acc2))))))
                 (elem op barops)
                  (go r 1 cur (fresh 0) (fresh 0) (fresh 0) (fresh 0) (f . acc))
                 (op = 'jmp)                         ; drop the dead tail; a jmp to the very next label falls through
                  (: r2 (swallow r)
                     (? (atlab? r2 <>f) (go r2 1 cur rg sl ce ci acc)
                        (: _ (pmerge <>f cur rg sl ce ci)
                           (go r2 () cur rg sl ce ci (f . acc)))))
                 (op = 'br)                          ; the taken edge records; the fall-through rides on
                  (: _ (pmerge <>>f cur rg sl ce ci)
                     (go r 1 cur rg sl ce ci (f . acc)))
                 (op = 'jmpt)                        ; ..and a table jump records one edge per target
                  (: _ (map (\ L (pmerge L cur rg sl ce ci)) (f 3))
                     (go (swallow r) () cur rg sl ce ci (f . acc)))
                 (xit? f) (go (swallow r) () cur rg sl ce ci (f . acc))
                 (op = 'li)
                  (: nx (? (two? r) <r ())
                     (? (two? nx && elem <nx '(li mov) && <>nx = <>f)
                        (go r 1 cur rg sl ce ci acc)    ; the very next form rewrites this register: dead li
                        (: k (constellation? <>>f ? (wrap <>>f) 'no)   ; a big rides too (charm? is the fixnum)
                           old (rv rg <>f)
                           (? (kn? old && <>old = k)
                              (go r 1 cur rg sl ce ci acc)   ; the register already holds this value
                              (: _ (defr ci rg sl ce <>f)
                                 _ (rset rg <>f (constellation? k ? [1 k] ()))
                                 (go r 1 cur rg sl ce ci (f . acc)))))))
                 (op = 'mov)
                  (? (= <>f <>>f) (go r 1 cur rg sl ce ci acc)   ; a self-mov says nothing
                     (: v (rsv rg <>>f)
                        old (rv rg <>f)
                        ; a copy chasing back to the dest is a no-op -- not for sp/fp/r4, whose
                        ; copy records outlive the motion (sp moves through the cursor, not defr)
                        (? ((two? old && two? v && <old = <v && <>old = <>v) ||
                            (two? v && <v = 2 && (= <>v <>f) && !(elem <>f '(sp fp r4 r3))))
                             (go r 1 cur rg sl ce ci acc)     ; the dest already holds this value
                           (: _ (defr ci rg sl ce <>f)
                              _ (rset rg <>f v)
                              _ (crec ci v 'g <>f)
                              ; a64 only: x64's reg-reg mov vanishes at rename, its li would be a real uop
                              (? (kn? v && a64? g && licost <>v = 1)
                                 (go r 1 cur rg sl ce ci (['li <>f <>v] . acc))
                                 (go r 1 cur rg sl ce ci (f . acc)))))))
                 (elem op '(add sub and or xor imul))
                  (? (<>f = 'sp)                ; sp arithmetic: the cell cursor moves
                      (: n <>>>f
                         (go r 1 (? (op = 'add) (cur - n) (cur + n)) rg sl ce ci (f . acc)))
                     (: d <>f a <>>f b <>>>f
                        bk (? (charm? b) [1 (wrap b)] (rv rg b))
                        ak (rv rg a)
                        (? (kn? ak && kn? bk)           ; both known: the op folds to a li
                            (: k (alu op <>ak <>bk)
                               _ (defr ci rg sl ce d)
                               _ (rset rg d [1 k])
                               (? (fold? k)
                                  (go r 1 cur rg sl ce ci (['li d k] . acc))
                                  (go r 1 cur rg sl ce ci (f . acc))))
                           (!(charm? b) && kn? bk && imma g op <>bk)   ; known reg source -> the imm form
                            (: _ (defr ci rg sl ce d)
                               (go r 1 cur rg sl ce ci ([op d a <>bk] . acc)))
                           (: _ (defr ci rg sl ce d)
                              (go r 1 cur rg sl ce ci (f . acc))))))
                 ; a known division folds whole, so only d is written; an unfoldable one falls
                 ; to the default arm, whose rdsp defs carry the machine div's r0..r3 clobber
                 (two? dk)
                  (: d <>f k <dk
                     _ (defr ci rg sl ce d)
                     _ (rset rg d [1 k])
                     (go r 1 cur rg sl ce ci (['li d k] . acc)))
                 (elem op '(shl shr sar rol ror ror4))   ; the 2-operand immediate shifts/rotates
                  (: d <>f k <>>f dk (rv rg d)
                     _ (defr ci rg sl ce d)
                     (? (kn? dk && shk? op k)
                         (: v (shf op <>dk k)
                            _ (rset rg d [1 v])
                            (? (v = <>dk) (go r 1 cur rg sl ce ci acc)   ; the op left the value alone
                               (fold? v) (go r 1 cur rg sl ce ci (['li d v] . acc))
                               (go r 1 cur rg sl ce ci (f . acc))))
                        (go r 1 cur rg sl ce ci (f . acc))))
                 ; a variable shift with a known count is the immediate one; the machine masks
                 ; the count where the immediate form does not, so shk? keeps one outside [0, W) variable
                 (elem op vshops)
                  (: d <>f iop (op @ 'shlv 'shl 'shrv 'shr 'sarv 'sar 'rorv 'ror 'ror4)
                     dk (rv rg d) ck (rv rg <>>f)
                     k (kn? ck ? <>ck 'no)
                     _ (defr ci rg sl ce d)
                     (? !(shk? iop k) (go r 1 cur rg sl ce ci (f . acc))
                        !(kn? dk) (go r 1 cur rg sl ce ci ([iop d k] . acc))
                        (: v (shf iop <>dk k)
                           _ (rset rg d [1 v])
                           (? (v = <>dk) (go r 1 cur rg sl ce ci acc)
                              (fold? v) (go r 1 cur rg sl ce ci (['li d v] . acc))
                              (go r 1 cur rg sl ce ci ([iop d k] . acc))))))
                 (elem op unops)
                  (: d <>f dk (rv rg d)
                     _ (defr ci rg sl ce d)
                     (? (kn? dk)
                         (: v (unop op <>dk)
                            _ (rset rg d [1 v])
                            (? (v = <>dk) (go r 1 cur rg sl ce ci acc)   ; the op left the value alone
                               (fold? v) (go r 1 cur rg sl ce ci (['li d v] . acc))
                               (go r 1 cur rg sl ce ci (f . acc))))
                        (go r 1 cur rg sl ce ci (f . acc))))
                 (op = 'st)
                  (? (<>f = fb)
                      (: v9 (rsv rg <>>>f) _ (rset sl <>>f v9) _ (crec ci v9 's <>>f)
                         (go r 1 cur rg sl ce ci (f . acc)))
                     (<>f = 'sp)
                      ; keyed by depth (cur - off): the wide kit's two words in one 16-byte cell track apart
                      (: v9 (rsv rg <>>>f) _ (rset ce (cur - <>>f) v9) _ (crec ci v9 'c (cur - <>>f))
                         (go r 1 cur rg sl ce ci (f . acc)))
                     (go r 1 cur rg (fresh 0) ce ci (f . acc)))     ; a pointer store may alias the frame
                 (op = 'ld)
                  (: d <>f b <>>f off <>>>f
                     kv (? (b = fb) (rv sl off) (b = 'sp) (rv ce (cur - off)) ())
                     (? (kn? kv)
                        (: _ (defr ci rg sl ce d)
                           _ (rset rg d kv)
                           (? (fold? <>kv)
                              (go r 1 cur rg sl ce ci (['li d <>kv] . acc))
                              (go r 1 cur rg sl ce ci (f . acc))))
                        (two? kv && (<kv = 2))     ; the memory holds a live copy: read the register
                         (? (= <>kv d)
                            (go r 1 cur rg sl ce ci acc)   ; ... and it is this register: the load says nothing
                            (: _ (defr ci rg sl ce d)
                               _ (rset rg d kv)
                               _ (crec ci kv 'g d)
                               (go r 1 cur rg sl ce ci (['mov d <>kv] . acc))))
                        (: _ (defr ci rg sl ce d)
                           (go r 1 cur rg sl ce ci (f . acc)))))
                 (op = 'push)                        ; cur + 8 on a64 too: keys are ledger depths, nothing addresses push padding
                  (: cur2 (cur + 8)
                     v9 (rsv rg <>f)
                     _ (rset ce cur2 v9) _ (crec ci v9 'c cur2)
                     (go r 1 cur2 rg sl ce ci (f . acc)))
                 (op = 'pop)
                  (: v (rv ce cur)
                     _ (defr ci rg sl ce <>f)
                     _ (rset rg <>f v)
                     _ (crec ci v 'g <>f)
                     (go r 1 (cur - 8) rg sl ce ci (f . acc)))
                 (elem op >stops9)                ; the full-word st has its own arm above
                  (? ((<>f = fb) || (<>f = 'sp))
                      (: _ (? (<>f = fb) (rset sl <>>f ()) (rset ce cur ()))
                         (go r 1 cur rg sl ce ci (f . acc)))
                     (go r 1 cur rg (fresh 0) ce ci (f . acc)))
                 (op = 'cmp)                         ; paired with its br/set consumer
                  (: a (rv rg <>f)
                     b (? (charm? <>>f) [1 (wrap <>>f)] (rv rg <>>f))
                     nx (? (two? r) <r ())
                     (? (kn? a && kn? b && two? nx && elem <nx '(br set) && elem <>nx ccs9)
                         (: tv (ccev <>nx <>a <>b)
                            (? (<nx = 'br)
                               (? tv (: r2 (swallow >r)
                                        (? (atlab? r2 <>>nx) (go r2 1 cur rg sl ce ci acc)
                                           (: _ (pmerge <>>nx cur rg sl ce ci)
                                              (go r2 () cur rg sl ce ci (['jmp <>>nx] . acc)))))
                                     (go >r 1 cur rg sl ce ci acc))
                               (: d <>>nx k (? tv 1 0)
                                  _ (defr ci rg sl ce d)
                                  _ (rset rg d [1 k])
                                  (go >r 1 cur rg sl ce ci (['li d k] . acc)))))
                        (go r 1 cur rg sl ce ci (f . acc))))
                 ; every other tabled op writes rdsp's defs; off the table nothing survives. the
                 ; table is register effects only, so a memory-writing op needs its own arm above
                 (: rd (rdsp g f)
                    (? (= rd 'bar)
                        (go r 1 cur (fresh 0) (fresh 0) (fresh 0) (fresh 0) (f . acc))
                       (: _ ((: (dfs ds) (? !(two? ds) 1
                                            (: _ (defr ci rg sl ce <ds) (dfs >ds))) dfs) <>rd)
                          (go r 1 cur rg sl ce ci (f . acc))))))))
       (go fs0 1 0 (fresh 0) (fresh 0) (fresh 0) (fresh 0) ()))

   ; dead cells: a spush cell nothing loads is write-only, so its store and its sub/add pair drop;
   ; a live cell converts to a frame slot (one per record depth) and the pair still drops
   (deadcell g fs)
    (: pex (map (\ f <>f) (filter (\ f (<f = 'pop)) (peep g 'epi epi)))   ; the epilogue's teardown pops
       cand {}                               ; st-index -> 1 while still droppable
       clds {}                               ; st-index -> its cell's ld indexes
       dirty {}                              ; sub-index -> 1: the span observed sp
       (dirt st2) (? !(two? st2) 1
                     (: _ (? (charm? <>><st2) (pin dirty <>><st2 1) ())
                        (dirt >st2)))
       (scan l i stk sw)                             ; -> the (sub st k add depth) entries | 'no
        (? !(two? l) sw
           (: f <l r >l
              (? !(two? f) (scan r (i + 1) stk sw)
                 (<f = 'sub && <>f = 'sp && charm? <>>>f)
                  (: k <>>>f
                     nx (two? r ? <r)
                     (? (k = 16 && two? nx && <nx = 'st &&
                         <>nx = 'sp && <>>nx = 0)
                        (: _ (pin cand (i + 1) 1)
                           (scan >r (i + 2) ([(i + 1) 16 i #stk] . stk) sw))
                        (scan r (i + 1) ([() k i #stk] . stk) sw)))
                 (<f = 'add && <>f = 'sp && charm? <>>>f)
                  (: (unwind st2 k w)
                      (? (k = 0) [st2 w]
                         !(two? st2) 'no
                         (: rc <st2 sz <>rc
                            (? (k < sz) 'no
                               (unwind >st2 (k - sz)
                                (? (charm? <>>rc) ([<>>rc <rc sz i (rc 3)] . w) w)))))
                     r9 (unwind stk <>>>f ())
                     (? (= r9 'no) 'no (scan r (i + 1) <r9 (<>r9 + sw))))
                 (<f = 'push) (scan r (i + 1) ([() 8 () ()] . stk) sw)
                 (<f = 'pop)
                  (? (elem <>f pex) (scan r (i + 1) stk sw)   ; the epilogue's frame pops: path exit
                     (two? stk && !<<stk && (<><stk = 8))
                     (scan r (i + 1) >stk sw)
                     'no)
                 (elem <f ldops9 && (<>>f = 'sp))
                  (? (two? stk && <<stk && (<>>>f = 0))
                     (: stx <<stk
                        _ (pin cand stx ())              ; loaded: the store lives
                        _ (pin clds stx (i . peep clds stx ()))
                        (scan r (i + 1) stk sw))
                     'no)
                 (elem <f stops9 && (<>f = 'sp)) 'no
                 (elem <f fldops && (<>>f = 'sp)) 'no
                 (: _ (? ((<f = 'raw) || elem 'sp >f) (dirt stk) ())
                    (scan r (i + 1) stk sw)))))
       ok (scan fs 0 () ())
       (? (= ok 'no) fs
          (: subdrop {} addsh {}     ; sub-index -> drop; add-index -> shrink bytes
             stconv {} ldconv {}     ; st/ld-index -> the slot's positive offset
             pf3 (fs 3)                         ; the prologue's frame sub: (sub sp sp F)
             cvok (pro4? fs &&
                   two? pf3 && (<pf3 = 'sub) && (<>pf3 = 'sp) && (<>>pf3 = 'sp) && charm? <>>>pf3)
             F (? cvok <>>>pf3 0)
             (mark w cv) (? !(two? w) cv
                            (: e <w sub (e 0) st (e 1) k (e 2) ad (e 3)
                               (? (peep dirty sub ()) (mark >w cv)
                                  !(0 = k % 16) (mark >w cv)
                                  (!st || peep cand st ())
                                   (: _ (pin subdrop sub 1)
                                      _ (pin addsh ad (peep addsh ad 0 + k))
                                      (mark >w cv))
                                  (cvok && k = 16) (mark >w (e . cv))
                                  (mark >w cv))))
             cvl (mark ok ())
             ds (: (dd l acc) (? !(two? l) acc
                                 (: d (<l 4)
                                    (dd >l (? (elem d acc) acc (d . acc)))))
                   (dd cvl ()))
             (rank d l n) (? (= <l d) n (rank d >l (n + 1)))
             _ ((: (cvt l) (? !(two? l) 1
                              (: e <l
                                 o ((F + 8) + (8 * rank (e 4) ds 0))
                                 _ (pin subdrop (e 0) 1)
                                 _ (pin addsh (e 3) (peep addsh (e 3) 0 + 16))
                                 _ (pin stconv (e 1) o)
                                 _ ((: (pl ls) (? !(two? ls) 1
                                                  (: _ (pin ldconv <ls o) (pl >ls))) pl)
                                    (peep clds (e 1) ()))
                                 (cvt >l))) cvt) cvl)
             F2 ((F + 8 * tally ds + 15) & -16)
             ; a converted cell joins the slot map, or deadst/repack meet an unclaimed r4 touch and
             ; bar the fn; one 8-byte slot per record depth, at the offset cvt hands the st/ld
             _ (foldl (\ _ d (: o ((F + 8) + (8 * rank d ds 0))
                                (pin g 'slots ([(0 - o) 8] . peep g 'slots ()))))
                      0 ds)
             (drop2 l i) (? !(two? l) ()
                            (? (peep cand i ()) (drop2 >l (i + 1))
                               (peep subdrop i ()) (drop2 >l (i + 1))
                               (: f2 <l
                                  o9 (peep stconv i ())
                                  ol (peep ldconv i ())
                                  s (peep addsh i 0)
                                  (? o9 (['st 'r4 (0 - o9) <>>>f2] . drop2 >l (i + 1))
                                     ol ([<f2 <>f2 'r4 (0 - ol)] . drop2 >l (i + 1))
                                     (two? cvl && i = 3) (['sub 'sp 'sp F2] . drop2 >l (i + 1))
                                     (s = 0) (f2 . drop2 >l (i + 1))
                                     (: k2 (<>>>f2 - s)
                                        (? (k2 = 0) (drop2 >l (i + 1))
                                           (['add 'sp 'sp k2] . drop2 >l (i + 1))))))))
             (drop2 fs 0))))

   ; dead defs: within a block, a pure def re-defined before any read drops. one backward walk;
   ; a control edge or an untabled op resets the dead set. dead_before = (dead + defs) - reads
   (deaddef g fs)
    (: (go l dead acc)                               ; l already reversed; acc rebuilds forward
        (? !(two? l) acc
           (: f <l r >l
              (? !(two? f) (go r dead (f . acc))
                 (: rd (rdsp g f)
                    (? (= rd 'bar) (go r {} (f . acc))
                       (: reads <rd defs <>rd pure <>>rd
                          (dd? ds) (? !(two? ds) 1
                                      (? (peep dead <ds ()) (dd? >ds) ()))
                          (? (pure && two? defs && dd? defs)
                             (go r dead acc)                     ; every def overwritten unread: drop
                             (: _ ((: (ad ds) (? !(two? ds) 1
                                                 (: _ (? (= <ds 'sp) () (pin dead <ds 1))
                                                    (ad >ds))) ad) defs)
                                _ ((: (rm rs) (? !(two? rs) 1
                                                 (: _ (pin dead <rs ()) (rm >rs))) rm) reads)
                                (go r dead (f . acc))))))))))
       (go (rev fs) {} ()))

   ; the arrival rename: a call-free fn's param homes copy the arg registers in (mov H A) and back
   ; at every staged tail; where A is never otherwise touched, H renames to A and the movs drop
   (jr0 g fs)                                        ; first: a park (mov P X) straight-line to its (jmpr P) retargets to (jmpr X)
    (? !(two? fs) ()
       (: f <fs
          (? !(two? f && (<f = 'mov) && !(charm? <>>f))
              (f . jr0 g >fs)
             (: P <>f X <>>f
                (scan w n)                            ; forms to the jmpr -> n | 'no
                 (? (!(two? w) || (10 < n)) 'no
                    (: f2 <w
                       (? !(two? f2) 'no
                          ((<f2 = 'jmpr) && (= <>f2 P)) n
                          (: rd (rdsp g f2)
                             (? (= rd 'bar) 'no
                                (elem P >f2) 'no
                                (elem X <>rd) 'no
                                (scan >w (n + 1)))))))
                k (scan >fs 0)
                (? (= k 'no) (f . jr0 g >fs)
                   (: (mend w i) (? (i = k) (['jmpr X] . jr0 g >w)
                                    (<w . mend >w (i + 1)))
                      (mend >fs 0)))))))
   (unhome g fs)
    (: ar (argr g) hr (hregs g)
       (pears l n acc)                                ; the leading (mov H A) movs -> ((H A)..)
        (? (!(two? l) || (8 < n)) acc
           (: f <l
              ; a body label ends the entry: a (mov H A) past it may be a loop's per-iteration reset
              (? (two? f && (<f = 'label) && (0 < n)) acc
                 (two? f && (<f = 'mov) &&
                  elem <>f hr && elem <>>f ar)
                 (pears >l (n + 1) ([<>f <>>f] . acc))
                 (pears >l (n + 1) acc))))
       (callish l) (? !(two? l) ()
                      (: f <l (? (two? f && elem <f barops) 1 (callish >l))))
       (ok? H A l seen)
        (? !(two? l) 1
           (: f <l
              (? !(two? f) (ok? H A >l seen)
                 (!seen && (<f = 'mov) && (= <>f H) && (= <>>f A))
                  (ok? H A >l 1)                      ; the entry mov
                 (seen && (<f = 'mov) && (= <>f A) && (= <>>f H))
                  (ok? H A >l seen)                   ; a staging restore
                 (: rd (rdsp g f)
                    (? (= rd 'bar)
                        (? (elem <f '(label jmp br ret)) (ok? H A >l seen)
                           ((<f = 'jmpr) && !(= <>f A)) (ok? H A >l seen)
                           ())                        ; an op outside the tables: keep the homes
                       (: reads <rd
                          (? (elem A reads || elem A <>rd) ()
                             ; H before the entry mov is another value (an arrival): renaming it corrupts
                             (!seen && (elem H reads || elem H <>rd)) ()
                             (elem H <>rd && !(elem H reads)) ()
                             (ok? H A >l seen))))))))
       (ren H A l)
        (? !(two? l) ()
           (: f <l
              f2 (? (two? f) ((: (sw e) (? !(two? e) e ((? (= <e H) A <e) . sw >e)) sw) f) f)
              (? (two? f2 && (<f2 = 'mov) && (= <>f2 <>>f2))
                 (ren H A >l)                         ; a self-mov husk drops
                 (f2 . ren H A >l))))
       (go2 ps l)
        (? !(two? ps) l
           (: p <ps
              (go2 >ps (? (ok? <p <>p l ()) (ren <p <>p l) l))))
       (? (callish fs) fs (go2 (pears fs 0 ()) fs)))

   ; adjacent sp adjustments merge; a cancelled pair (a dead cell's husk) vanishes
   (spadj? f) (two? f && elem <f '(add sub) &&
               (<>f = 'sp) && (<>>f = 'sp) && charm? <>>>f)
   (spmerge fs)
    (? !(two? fs) ()
       (: f <fs r >fs
          nx (? (two? r) <r ())
          (? (spadj? f && spadj? nx)
             (: n1 (? (<f = 'add) <>>>f (0 - <>>>f))
                n2 (? (<nx = 'add) <>>>nx (0 - <>>>nx))
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
                  (elem <f '(add sub) && (= <>f 'sp)))
       (dead? l) (? !(two? l) ()
                    (: f <l
                       (? !(two? f) (dead? >l)
                          (xit? f) 1
                          (calm? f) (dead? >l)
                          ())))
       (go l) (? !(two? l) ()
                 (: f <l
                    (? (two? f && (<f = 'st) && (= <>f fb) && dead? >l)
                       (go >l)
                       (f . go >l))))
       (go fs))
   ; dead frame stores: a slot never loaded back drops, with its newly-dead feeding li. an lea
   ; keeps its whole slot-map object live; an lea no object claims bars the fn
   (deadst g fs)
    (: used {} esc {}
       fb (fbase g)
       slots (peep g 'slots ())
       (obmark x) (: o9 (obj9 slots x)               ; the object under x rides whole | the old bar
                     (? (two? o9) (mark <o9 <>o9) (pin esc 'y 1)))
       ; liveness by the 8-byte granules an access spans, never offset-exact: a store at off+8
       ; is read back at off+12 by a struct's inner field
       (mwid op) (? (elem op '(ld1 ldu1 st1 si1)) 1
                    (elem op '(ld2 ldu2 st2 si2)) 2
                    (elem op '(ld4 ldu4 st4 si4 ldss stss)) 4
                    8)
       (mark o w) (: (go k) (? ((>> ((o + w) - 1) 3) < k) 1 (: _ (pin used k 1) (go (k + 1))))
                     (go (o >> 3)))
       (hit? o w) (: (go k) (? ((>> ((o + w) - 1) 3) < k) () (peep used k ()) 1 (go (k + 1)))
                     (go (o >> 3)))
       (scan l) (? !(two? l) 1
                   (: f <l
                      _ (? !(two? f) ()
                           (elem <f ldops9 || elem <f fldops)
                            (<>>f = fb ? (mark <>>>f (mwid <f)))
                           (<f = 'cmpm)
                            (<>f = fb ? (mark <>>f 8))
                           (<f = 'cmprm)
                            (<>>f = fb ? (mark <>>>f 8))
                           (elem <f '(lea lean))          ; (lea sp fp 0) is teardown, not an address take
                            (<>>f = fb && <>f != 'sp ? (obmark <>>>f))
                           (elem <f xops)          ; a runtime index roams its object
                            (<>>f = fb ? (obmark (f 5)))
                           (elem <f stxops)
                            (<>f = fb ? (obmark (f 4))))
                      (scan >l)))
       _ (scan fs)
       (drop (f . u)) (? (two? f && (elem <f stops9 || elem <f siops) &&
                           <>f = fb && !(hit? <>>f (mwid <f)))
                         (drop u)
                         (f . drop u))
       (lisweep (f . u)) (: nx (two? u ? <u)
                           (? (two? f && <f = 'li &&
                               two? nx && elem <nx '(li mov) && <>nx = <>f)
                              (lisweep u)
                              (f . lisweep u)))
       (esc 'y ? fs (lisweep (drop fs))))

   ; the callee-saved file per target, read off holo's own tables (love/holo/<tgt>.l): x64 rbx rbp
   ; r12..r15, a64 x19..x28, riscv s1..s11, thumb2 r4..r10 (r11 is fp)
   (csregs g) (? (a64? g) '(r19 r20 r21 r22 r23 r24 r25 r26 r27 r28)
                 (rv64? g) '(r13 r14 r15 r19 r20 r21 r22 r23 r24 r25 r26)
                 (t32? g) '(r4 r5 r6 r7 r8 r9 r10)
                 ('(r3 r4) + csx64))

   ; the liveness kit: a backward fixpoint over the per-form graph. the answer over-approximates
   ; live: a call reads+writes the caller-saved file, a sibcall reads everything, an unnamed op bars
   (lvgp g) (? (a64? g) '(r0 r1 r2 r3 r4 r5 r6 r7 r8 r9 r10 r11 r12 r13 r14 r15)
               (rv64? g) '(r0 r1 r2 r3 r4 r5 r6 r7 r8 r9 r10 r11 r12)
               (t32? g) '(r0 r1 r2 r3 r12)
               '(r0 r1 r2 r5 r6 r7 r8 r9 r10))       ; caller-saved gp: a seat owes no pair but may not span a call
   lvquiet '(label align ud2 br jmp)                ; no register effect at all
   ; what an exit owes back beside the cs file. r2 (rdx, an aggregate's high half) is missing:
   ; a consumer using this for a plain dead-def test owes it first
   (lvret g) (? (t32? g) '(r0 r1) '(r0 r1 f0 f1))
   ; the blanket cases filter mints out: a mint live across a call must read as crossing, not
   ; be read+def'd into a false kill. inert post-vrfix
   (lvtx g f u)                                     ; one form's (reads defs) | 'bar
    (? !(two? f) [() ()]
       (: op <f
          (? (elem op lvquiet) [() ()]
             (elem op '(call callr sys))
              (: c (filter (\ r9 !(elem r9 (csregs g) || vmint? g r9)) u) [c c])
             (retx? f) [((lvret g) + (csregs g)) ()]   ; a return reads what it owes back
             (op = 'jmpr) [(filter (\ r9 !(vmint? g r9)) u) ()]
             (: d (rdsp g f) (? (= d 'bar) 'bar [<d <>d])))))
   (lvuniv g fs)                                    ; every register in play: the seats + rdsp's
    (: t {}
       (add rs) (? !(two? rs) 0 (: _ (pin t <rs 1) (add >rs)))
       _ (add (lvgp g))                             ; a seat the fn never mentions must still clobber at a call
       (scan l) (? !(two? l) 0
                   (: f <l d (? (two? f) (rdsp g f) [() ()])
                      _ (? (= d 'bar) 0 (: _ (add <d) (add <>d)))
                      (scan >l)))
       _ (scan fs)
       (keys t))
   (lvun a b) (? !(two? b) a (lvun (elem <b a ? a (<b . a)) >b))     ; set union
   (lvsame a b) (#a = #b && !(two? (filter (\ r9 !(elem r9 b)) a)))
   (lvio g fs)                                      ; -> [lin lot] (index -> live in/out of it) | 'no
    (: u (lvuniv g fs)
       um (filter (\ r9 !(vmint? g r9)) u)          ; the machine share: what a blanket case reads
       (bary? (f . l)) (lvtx g f u @ 'bar 1 (bary? l))
       (? (bary? fs) 'no
          (: labt {}
             (ix l i) (? !(two? l) 0
                         (: f <l
                            _ (two? f && (= <f 'label) ? (pin labt <>f i))
                            (ix >l (i + 1))))
             _ (ix fs 0)
             (ixd l i) (? !(two? l) () ([i <l] . ixd >l (i + 1)))
             rl (rev (ixd fs 0))
             (succ f i) (: op (? (two? f) <f 'x)
                           (? (op = 'jmp) [(peep labt <>f -1)]
                              (op = 'br) [(peep labt <>>f -1) (i + 1)]
                              ; the table jump goes to every label its own operand names
                              (op = 'jmpt) (map (\ L (peep labt L -1)) (f 3))
                              (xit? f) ()
                              [(i + 1)]))
             lin {}
             lot {}
             (gone? f) (xjmp? f labt)               ; a jmp to no local label is a sibcall, arguments in flight: reads everything
             (pass l ch)                            ; one backward sweep -> did any live-in grow?
              (? !(two? l) ch
                 (: e <l i <e f <>e
                    d (? (gone? f) [um ()] (lvtx g f u))
                    lo (foldl (\ a s (lvun a (lin s))) () (succ f i))
                    li (lvun <d (filter (\ r9 !(elem r9 <>d)) lo))
                    old (lin i)
                    ch2 !(lvsame li old)
                    _ (? ch2 (pin lin i li) 0)
                    _ (pin lot i lo)
                    (pass >l (ch || ch2))))
             (fix u9) (pass rl () ? (fix ()) 0)
             _ (fix ())
             [lin lot])))
   (lvout g fs) ; index -> the registers live out of it | 'no
    (lvio g fs @ 'no 'no r <>r)

   ; coalescing: a (mov D S) whose S dies here and was defined by the form just before is a
   ; misnamed def: the def takes D and the mov drops. the prologue is unframe's, read by position
   (coal? g p f i lo lot)                             ; may (mov D S) at i fold into its def p?
    (? !(two? p && two? f && (= <f 'mov) && (lo < i)) ()
       (: S (f 2)
          D (f 1)
          d (rdsp g p)
          (d @ 'bar ()
             (: dfs <>d
                ; the def names S alone and never reads it
                (two? dfs && !(two? >dfs) && (= <dfs S) && p 1 == S &&
                 ; D a stranger to the def's defs and reads (the emitter refuses an aliased dest),
                 ; except an alu's first source: (mov d a; op d b) lowers, so (add r7 r7 8) fuses
                 !(elem S <d) && !(elem D dfs) &&
                 (!(elem D <d) || (elem <p aluops && p 2 == D)) &&
                 !(elem S (peep lot i ())) && !(= D S))))))
   (coal g fs)
    (: lot (lvout g fs)
       lo 5                                         ; the prologue floor on every target: unframe needs nothing at index <= 4 to shift
       (lot @ 'no fs
          ; one form of lookbehind: a form is emitted when the next declines to fold into it
          (: ; a copy read nowhere ahead is a dead def. lot is pre-rename, which stays conservative:
             ; a fold shortens the source's range and leaves the destination's alone
             (dead9? f i) (lo < i && two? f && hmov? f &&
                           !(elem (f 1) (lot i)))
             (rn l p i)
              (? !(two? l) (two? p ? [p])
                 (: f <l
                    (? (coal? g p f i lo lot) ((reop p 1 (f 1)) . rn >l () (i + 1))
                       ; a dropped copy keeps the lookbehind: the def and the next copy become adjacent
                       (dead9? f i) (rn >l p (i + 1))
                       (two? p) (p . rn >l f (i + 1))
                       (rn >l f (i + 1)))))
             (rn fs () 0))))

   ; slot repack: objects whose live windows (touch spans, widened over backedges to a fixpoint)
   ; never meet share one cell; an address-taken object lives to the last form. x64 only
   (repack g fs)
    (: slots (g 'slots)
       pro (pro4? fs)
       sf (fs 3)
       K (sf @ ('sub 'sp 'sp k) (charm? k ? k))
       (? (!(two? slots) || arm? g || g 'hasasm || !pro || !(charm? K)) fs
          (: obs {}                            ; base -> (size lo hi esc wordy? first-src)
             ; wordy? and first-src are promotion's: every touch a full-word ld/st at the base, and
             ; the register the first store took (the preferred seat), () when the first touch was a load
             tls {}                        ; base -> ((i op reg off)..) newest-first, the chains' food
             (touch b n i e9 k9 s9 op9 x9)             ; k9: 'st | 'ld | 'no (an unpromotable shape)
              (: w (obs b)
                 _ (pin tls b ([i op9 s9 x9] . peep tls b ()))
                 (pin obs b (? (two? w) [n <>w i (w 3 || e9)
                                           (w 4 && k9 !== 'no) (w 5)]
                               [n i i e9 !(= k9 'no) (? (= k9 'st) s9 ())])))
             labt {}
             (loose? e i bp) (? !(two? e) ()
                                (= <e 'r4 && !(i = bp)) 1
                                (loose? >e (i + 1) bp))
             (scan l i sps)                            ; every frame touch noted -> the backward spans | 'no
              (? !(two? l) sps
                 (: f <l
                    (? !(two? f) (scan >l (i + 1) sps)
                       (= <f 'label) (: _ (pin labt <>f i) (scan >l (i + 1) sps))
                       (= <f 'raw) 'no
                       (elem <f '(push pop)) (scan >l (i + 1) sps)
                       (= <f 'mov && ((= <>f 'r4 && (= <>>f 'sp)) ||
                                        (= <>f 'sp && (= <>>f 'r4))))
                        (scan >l (i + 1) sps)          ; the frame link movs (unframe strips them)
                       (: tg (? (= <f 'jmp) <>f (= <f 'br) <>>f ())
                          li9 (? tg (peep labt tg 'no9) 'no9)
                          sp2 (? (charm? li9) ([li9 i] . sps) sps)
                          bp (peep a4base <f -1)
                          (? (0 <= bp && f bp == 'r4)
                             ; uoff misses as -1, and a negative index counts from the tail: a miss means the op itself
                             (: X (peep uoff <f -1 @ u9 (u9 < 1 ? <f (f u9)))
                                o9 (obj9 slots X)
                                (? (loose? >f 1 bp) 'no
                                   (two? o9)
                                    (: _ (touch <o9 <>o9 i
                                                (elem <f (leaops + '(leax)))
                                                ; a cs save/restore wears a promotable temporary's exact shape: a cs mover never promotes
                                                (? !((<>o9 = 8) && (X = <o9)) 'no
                                                   (= <f 'st)
                                                    (? (elem (f 3) (csregs g)) 'no 'st)
                                                   (= <f 'ld)
                                                    (? (elem (f 1) (csregs g)) 'no 'ld)
                                                   'no)
                                                (? (0 < vstw <f) (f 3)
                                                   (0 < vsiw <f) (f 3)
                                                   (0 < vldw <f) (f 1)
                                                   ())
                                                <f X)
                                       (scan >l (i + 1) sp2))
                                   (charm? X && ((X = -8) || (0 <= X))) (scan >l (i + 1) sp2)
                                   'no))
                             (loose? >f 1 -1) 'no
                             (scan >l (i + 1) sp2))))))
             spans (scan fs 0 ())
             (? (= spans 'no) fs
                (: n2 #fs
                   bases (keys obs)
                   ; an escape pins the window's tail to the last form
                   _ (foldl (\ _ b (: w (peep obs b ())
                                      (? (w 3)
                                         (pin obs b [<w <>w n2 1 (w 4) (w 5)]) 0)))
                            0 bases)
                   (widen1 bs ch)                      ; one widening sweep -> did anything grow?
                    (? !(two? bs) ch
                       (: b <bs w (peep obs b ())
                          (grow ss lo hi)
                           (? !(two? ss) [lo hi]
                              (: s <ss
                                 (? ((lo <= <>s) && (<s <= hi))
                                    (grow >ss (? (<s < lo) <s lo) (? (hi < <>s) <>s hi))
                                    (grow >ss lo hi))))
                          r (grow spans <>w <>>w)
                          ch2 !((<r = <>w) && (<>r = <>>w))
                          _ (? ch2 (pin obs b [<w <r <>r (w 3) (w 4) (w 5)]) 0)
                          (widen1 >bs (ch || ch2))))
                   _ (: (fix u) (? (widen1 bases ()) (fix ()) 0) (fix ()))
                   ; promotion, per def chain: stores group by the loads their reaching defs join; a chain
                   ; takes a seat free over its live range; a narrow cell's seat is canonical to its first load's extension
                   (shp9 b)                    ; the cell's one touch width | 0
                    (: (go l w) (? !(two? l) w
                                   (: t <l op <>t rg (t 2) X (t 3)
                                      w2 (? (0 < vldw op) (vldw op)
                                            (0 < vstw op) (vstw op)
                                            (0 < vsiw op) (vsiw op) 0)
                                      (? ((w2 = 0) || !(X = b) || ((0 < w) && !(w = w2))) 0
                                         ; a full-word cs mover is a save/restore in shape: never promotes
                                         ((w2 = 8) && (0 < vldw op || 0 < vstw op)
                                          && elem rg (csregs g)) 0
                                         (go >l w2))))
                       (go (peep tls b ()) 0))
                   scand (foldl (\ a b (: w (peep obs b ())
                                          (? (!(w 3) && (0 < shp9 b)) (b . a) a)))
                                () bases)
                   sc9 (vsucc fs)                           ; the form graph, once per fn
                   lot9 (? (two? scand) (lvout g fs) 'no)   ; index -> live-out, or the refusal
                   dft9 (? (= lot9 'no) {}
                           (: t {}
                              u9 (lvuniv g fs)
                              (go l i) (? !(two? l) 0
                                          (: d (lvtx g <l u9)
                                             _ (? (= d 'bar) 0 (pin t i <>d))
                                             (go >l (i + 1))))
                              _ (go fs 0)
                              t))
                   ; calls by index, and the cs pool a crossing chain may take: regs this fn never
                   ; writes, and never in a jmpr fn (a restore before the indirect exit is the dispatch's hot path)
                   callt (: t {}
                            (go l i) (? !(two? l) t
                                        (: f <l
                                           _ (? (two? f && elem <f '(call callr sys)) (pin t i 1) 0)
                                           (go >l (i + 1))))
                            (go fs 0))
                   jrf (vany (\ f (two? f && (= <f 'jmpr))) fs)
                   cswr (? (= lot9 'no) ()
                           (: t {}
                              (go i) (? (n2 <= i) 0
                                        (: _ (foldl (\ _ r (? (elem r (csregs g)) (pin t r 1) 0))
                                                    0 (peep dft9 i ()))
                                           (go (i + 1))))
                              _ (go 0)
                              t))
                   cspool9 (? (jrf || (= lot9 'no)) ()
                              (filter (\ r !(peep cswr r 0)) csx64))
                   ; a cs reg the prologue already saves rides free: its dead ranges owe no new pair
                   csprd (? (jrf || (= lot9 'no)) ()
                            (: t9 {}
                               (go l i) (? (!(two? l) || 12 < i) 0
                                           (: f9 <l
                                              _ (? (two? f9 && (= <f9 'st) &&
                                                    (= <>f9 'sp || (= <>f9 'r4)) &&
                                                    elem (f9 3) csx64)
                                                   (pin t9 (f9 3) 1) 0)
                                              (go >l (i + 1))))
                               _ (go fs 0)
                               (filter (\ r9 (peep t9 r9 0)) csx64)))
                   taken {}                    ; index -> the seats promotion already holds
                   (pfree? tk r is9)
                    (? !(two? is9) 1
                       (: i <is9
                          (? (elem r (peep lot9 i ())) ()
                             (elem r (peep dft9 i ())) ()
                             (elem r (peep tk i ())) ()
                             (pfree? tk r >is9))))
                   (pseat tk rs is9) (? !(two? rs) () (pfree? tk <rs is9) <rs (pseat tk >rs is9))
                   (pclaim tk r is9) (? !(two? is9) 0
                                        (: _ (pin tk <is9 (r . peep tk <is9 ()))
                                           (pclaim tk r >is9)))
                   (span9 lo hi) (: (go i acc) (? (i < lo) acc (go (i - 1) (i . acc))) (go hi ()))
                   succ9 (? (= lot9 'no) {} sc9)
                   (xt9 op) (op @ 'ld4 'sx4 'ldu4 'zx4 'ld2 'sx2 'ldu2 'zx2 'ld1 'sx1 'ldu1 'zx1 ())
                   (pxv xc w k)                ; an si value, canonically extended at compile time
                    (? (8 <= w) k
                       (: m ((8 * w) 2)
                          v (: r9 (k % m) (? (r9 < 0) (r9 + m) r9))
                          (? (elem xc '(sx1 sx2 sx4)) (? ((m // 2) <= v) (v - m) v) v)))
                   clvm {}                     ; base -> its cell liveness, walked once
                   (clv9 b lo hi sts lds)
                    (: c (peep clvm b ())
                       (two? c ? <c (: r (vclive lo hi sc9 sts lds) _ (pin clvm b [r]) r)))
                   (chains9 b)                 ; one cell -> ((S pref defs ((use dst ext)..) xc)..)
                    (: w (peep obs b ())
                       tl (rev (peep tls b ()))
                       sts (map (\ t <t) (filter (\ t (0 < vstw <>t || 0 < vsiw <>t)) tl))
                       lds (map (\ t <t) (filter (\ t (0 < vldw <>t)) tl))
                       ot (foldl (\ t9 t (pin t9 <t <>t)) {} tl)
                       rg9 (foldl (\ t9 t (pin t9 <t (t 2))) {} tl)
                       (rich us) (map (\ u [u (peep rg9 u ()) (xt9 (peep ot u ()))]) us)
                       (xcof us) (? !(two? us) () (xt9 (peep ot <us ())))
                       (? !(two? sts) ()               ; no store: nothing to promote
                          !(two? >sts)                 ; one def: one chain, no reaching needed
                           (: lo0 <>w hi0 <>>w
                              clv (clv9 b lo0 hi0 sts lds)
                              S (: (go i acc)
                                   (? (i < lo0) acc
                                      (go (i - 1) (? ((i = <sts) || 0 < peep clv i 0) (i . acc) acc)))
                                   (go hi0 ()))
                              [[S (peep rg9 <sts ()) sts (rich lds) (xcof lds)]])
                          (: lo0 <>w hi0 <>>w
                             rt (vreach lo0 hi0 succ9 sts)
                             gps <(vgroup rt sts lds)   ; the chains; a no-def load stays a frame read
                             clv (clv9 b lo0 hi0 sts lds)         ; the cell's liveness, once
                             st9 (foldl (\ t d (pin t d 1)) {} sts)
                             (map (\ gp (: ds <gp us <>gp
                                            dt9 (foldl (\ t d (pin t d 1)) {} ds)
                                            ; live out of i and a chain def reaching out of i:
                                            ; this chain's value rides the edge
                                            S (: (go i acc)
                                                 (? (i < lo0) acc
                                                    (go (i - 1)
                                                        (? (peep dt9 i 0) (i . acc)
                                                           !(0 < peep clv i 0) acc
                                                           (peep st9 i 0) acc
                                                           (two? (vboth (peep rt i ()) ds)) (i . acc)
                                                           acc)))
                                                 (go hi0 ()))
                                            [S (peep rg9 <ds ()) ds (rich us) (xcof us)]))
                                  gps))))
                   bylo (sortby (\ a b ((<>(peep obs a ())) < (<>(peep obs b ())))) scand)
                   pxm {}                      ; touch index -> (seat canonical-ext)
                   retid {}                    ; base -> every touch promoted, the cell retires
                   ; hull first: a cell the hull can serve takes one seat over its span with no chain
                   ; analysis; only the cells it refuses pay for per-def chains
                   hullw (: t {}
                            (go l) (? !(two? l) t
                                      (: b <l w (peep obs b ())
                                         _ (? !(w 4 && w 5) 0
                                              (: S (span9 <>w <>>w)
                                                 pf (w 5)
                                                 r (pseat taken (? (elem pf (lvgp g)) (pf . (lvgp g)) (lvgp g)) S)
                                                 (? !r 0
                                                    (: _ (pclaim taken r S)
                                                       _ (foldl (\ _ t9 (pin pxm <t9 [r ()])) 0 (peep tls b ()))
                                                       (pin retid b 1)))))
                                         (go >l)))
                            (? (= lot9 'no) t (go bylo)))
                   csut {}                     ; the cs seats promotion actually took
                   (ctfree? r is9) (? !(two? is9) 1
                                      (elem r (peep taken <is9 ())) ()
                                      (ctfree? r >is9))
                   (cstake rs is9) (? !(two? rs) () (ctfree? <rs is9) <rs (cstake >rs is9))
                   _ (? (= lot9 'no) 0
                        (foldl (\ _ b
                                 (: nrw (foldl (\ k c9
                                                (: S <c9 pf <>c9 ds (c9 2) rus (c9 3) xc (c9 4)
                                                   r0 (pseat taken (? (elem pf (lvgp g)) (pf . (lvgp g)) (lvgp g)) S)
                                                   ; a crossing chain may take a cs seat, taken-only freeness (the
                                                   ; pair meets the exit's phantom read), when the call weight repays the pair: 64 = a call at loop depth >= 2
                                                   rp9 (? r0 () (pseat taken csprd S))
                                                   r (? r0 r0
                                                        rp9 rp9
                                                        !(two? cspool9) ()
                                                        (: wc (foldl (\ a i (? (peep callt i 0)
                                                                               (a + vwt spans i) a))
                                                                     0 S)
                                                           (? (wc < 64) () (cstake cspool9 S))))
                                                   (? !r k
                                                      ; a load into the seat itself at another extension would wreck it
                                                      (vany (\ u3 (= <>u3 r && u3 2 && u3 2 !== xc)) rus) k
                                                      (: _ (pclaim taken r S)
                                                         _ (? (elem r cspool9) (pin csut r 1) 0)
                                                         _ (foldl (\ _ i (pin pxm i [r xc])) 0 ds)
                                                         _ (foldl (\ _ u3 (pin pxm <u3 [r xc])) 0 rus)
                                                         (k + #ds + #rus)))))
                                               0 (chains9 b))
                                    (? (nrw = tally (peep tls b ())) (pin retid b 1) 0)))
                               0 (filter (\ b !(peep retid b ())) bylo)))
                   prom (keys pxm)
                   ; what a cell occupies: where every touch is a classified ld/st/si at its own base,
                   ; vclive's exact indices; any other use (cmpm, an escape) is unseen, so those keep the window
                   (exact9? b)
                    (: w (peep obs b ())
                       (? ((w 3) || (abl? g 'setpack) || (<w != 8)) 0
                          (foldl (\ a t (a && (t 3) = b &&
                                         (0 < vldw <>t || 0 < vstw <>t || 0 < vsiw <>t)))
                                 1 (peep tls b ()))))
                   (lset9 b)
                    (: w (peep obs b ())
                       tl (rev (peep tls b ()))
                       sts (map (\ t <t) (filter (\ t (0 < vstw <>t || 0 < vsiw <>t)) tl))
                       lds (map (\ t <t) (filter (\ t (0 < vldw <>t)) tl))
                       clv (clv9 b <>w <>>w sts lds)
                       st9 (foldl (\ t d (pin t d 1)) {} sts)
                       (go i acc) (? (i < <>w) acc
                                     (go (i - 1) (? (st9 i || 0 < peep clv i 0) (i . acc) acc)))
                       (go <>>w ()))
                   ex9 (filter (b \ !(peep retid b ()) && exact9? b) bases)
                   ls9 (foldl (\ t b (pin t b (lset9 b))) {} ex9)
                   ext9 (foldl (\ t b (pin t b 1)) {} ex9)
                   rows (sortby (\ a b (<a < <b))
                                (map (\ b (: w (peep obs b ()) [<>w b <w <>>w]))
                                     (filter (\ b !(peep retid b ())) bases)))
                   nmap {}                     ; base -> its packed seat
                   ; the seat book: a seat takes a new tenant when none it carries meets it (no free
                   ; list: a seat's tenants may overlap, so it is never handed on "the last one ended")
                   seats9 {}                   ; 'l -> the 8-byte seats laid, newest first
                   ten9 {}                     ; seat -> its tenants' occupancies
                   (occ9 b lo hi) (ext9 b ? ['st (peep ls9 b ())] ['iv lo hi])
                   (hits? a c)
                    (? ((<a = 'iv) && (<c = 'iv)) ((<>a <= (c 2)) && (<>c <= (a 2)))
                       ((<a = 'st) && (<c = 'st)) (two? (vboth <>a <>c))
                       (<a = 'st) (vany (i \ (<>c <= i) && (i <= (c 2))) <>a)
                       (vany (i \ (<>a <= i) && (i <= (a 2))) <>c))
                   (fit9 o oc) !(foldl (\ x t (x || hits? oc t)) 0 (peep ten9 o ()))
                   (seat9 oc) (: (go l) (? (one? l) () (fit9 <l oc ? <l (go >l)))
                                 (go (peep seats9 'l ())))
                   (place rs high)                     ; sweep by lo -> the packed high-water
                    (? (one? rs) high
                       (: r1 <rs lo <r1 b <>r1 n (r1 2) hi (r1 3)
                          oc (occ9 b lo hi)
                          o9 (n = 8 ? (seat9 oc) ())
                          pr (? !(o9 = ()) [o9 high]
                                (: h1 (? ((16 <= n) &&
                                          !((& (0 - (high + n)) 15) = (b & 15)))
                                         (high + 8) high)
                                   [(0 - (h1 + n)) (h1 + n)]))
                          _ (pin ten9 <pr (oc . peep ten9 <pr ()))
                          _ (? ((n = 8) && !(elem <pr (peep seats9 'l ())))
                               (pin seats9 'l (<pr . peep seats9 'l ())) 0)
                          _ (pin nmap b <pr)
                          (place >rs <>pr)))
                   high2 (place rows 8)
                   ; the cs seats' save slots below the packed high water; one pair per seat
                   csused (filter (\ r (peep csut r 0)) cspool9)
                   cslot (: t {}
                            (go l k) (? !(two? l) t
                                        (: _ (pin t <l (0 - (high2 + (8 * k))))
                                           (go >l (k + 1))))
                            (go csused 1))
                   csaves (map (\ r ['st 'r4 (peep cslot r 0) r]) csused)
                   csrests (map (\ r ['ld r 'r4 (peep cslot r 0)]) csused)
                   K2 ((high2 + 15) & -16)
                   K3 (? (two? csused) (((high2 + (8 * tally csused)) + 15) & -16) K2)
                   ; a jmp off the label table is a sibcall; so is one to the entry label (a self tail call)
                   (exit9? f) (xit? f || xjmp? f labt ||
                               (two? f && (= <f 'jmp) && (0 = (peep labt <>f -1))))
                   (tearx? l) (? !(two? l) 0                        ; teardown straight to an exit?
                                 (: f <l
                                    (? (exit9? f) 1
                                       !(two? f) 0
                                       (elem f (butret epi) ||
                                        (= <f 'add && (= <>f 'sp) && (= <>>f 'sp))) (tearx? >l)
                                       0)))
                   (radj2 f op9)                       ; a mapped touch -> its packed spelling
                    (: X (f op9)
                       o9 (obj9 slots X)
                       nb (? (two? o9) (peep nmap <o9 'no9) 'no9)
                       (? !(charm? nb) f (reop f op9 (nb + (X - <o9)))))
                   (prw f i)                           ; a promoted touch -> its forms (() drops whole) | 'no
                    (: rec (peep pxm i ())
                       (? !(two? rec) 'no
                          (: r <rec xc <>rec op <f
                             (? (0 < vsiw op)
                                 [['li r (pxv xc (vsiw op) (f 3))]]
                                (0 < vstw op)
                                 (: m9 (f 3 != r ? [['mov r (f 3)]])
                                    (? (((vstw op) < 8) && !(xc = ())) (vapp m9 [[xc r]]) m9))
                                (: d (f 1)
                                   xl (xt9 op)
                                   m9 (? (= d r) () [['mov d r]])
                                   (? (!(xl = ()) && !(= xl xc)) (vapp m9 [[xl d]]) m9))))))
                   (rw l i inr)
                    (? !(two? l) ()
                       (: f <l
                          t9 (? (two? csused) (tearx? l) 0)
                          spl (? (t9 && !inr) csrests ())
                          p (? (two? f && (3 < i) && two? prom) (prw f i) 'no)
                          (? (= p 'no)
                             (: f2 (? !(two? f) f
                                      (i = 3) ['sub 'sp 'sp K3]
                                      (: bp (peep a4base <f -1)
                                         (? (0 <= bp && f bp == 'r4)
                                            (radj2 f (peep uoff <f -1)) f)))
                                (? ((i = 4) && two? csused)
                                   (vapp spl (f2 . vapp csaves (rw >l (i + 1) t9)))
                                   (vapp spl (f2 . rw >l (i + 1) t9))))
                             (vapp spl (vapp p (rw >l (i + 1) t9))))))
                   ; the packed map replaces the build's for later slot readers (deadst); a promoted
                   ; or retired object has no cell, the cs save slots are objects of their own
                   slots2 (foldl (\ a2 o (: nb (peep nmap <o 'no9)
                                            (? (charm? nb) ([nb <>o] . a2) a2)))
                                 (map (\ r [(peep cslot r 0) 8]) csused)
                                 slots)
                   (? ((K2 < K) || two? prom) (: _ (pin g 'slots slots2) (rw fs 0 0)) fs))))))

   ; dead label regions: a form after an unconditional transfer drops until a still-referenced
   ; label (refs = every symbol operand, over-approximate); a dropped region takes its refs with it
   (deadlab fs) (: r (deadlab1 fs) (? (#r = #fs) r (deadlab r)))
   (deadlab1 fs)
    (: refs {}
       (note ops) (? !(two? ops) 0
                     (: o <ops
                        _ (? (nom? o) (pin refs o 1)
                             (two? o) (note o))     ; nested operands (a raw splice's forms) scan whole
                      (note >ops)))
       (scan l) (? !(two? l) 0
                   (: f <l
                      _ (two? f && <f != 'label ? (note >f))
                    (scan >l)))
       _ (scan fs)
       (sweep l dead)
        (? !(two? l) ()
           (: f <l
              lbl (two? f && <f = 'label)
              (? (dead && lbl)
                  (refs <>f ? (f . sweep >l 0) (sweep >l 1))
                 dead (sweep >l 1)
                 ; a jump to the very next label is the fall-through: drops, and the fixpoint may take the label
                 (two? f && <f = 'jmp &&
                  (: n <>l (two? n && <n = 'label && <>n = <>f)))
                  (sweep >l 0)
                 (f . sweep >l (xit? f || (two? f && elem <f '(jmp jmpt)))))))
       (sweep fs 0))

   ; the callee-saved contract, held at emission: a cs reg written anywhere must be saved before
   ; its first write and restored by every exit. an op on neither rdsp nor csquiet refuses
   csquiet '(label align ud2 trap br jmp jmpr jmpt ret call callr sys mulo   ; trap = a64's brk #0, ud2's twin
             sx128 n128 a128 a128r s128 s128r m128 m128r mw128 mw128r c128 c128r
             dv128 rm128 inc128 dec128 shl128 shr128 sar128 shl128v shr128v sar128v)
   (csdefs g f)                                       ; the cs regs one form writes | 'dark
    (? (elem <f csquiet) ()
       (elem <f divops) (filter (r \ elem r (csregs g)) [<>f])   ; idiv self-saves r2: its dst only
       (: rd (rdsp g f)
          (? (= rd 'bar) 'dark
             (filter (r \ elem r (csregs g)) <>rd))))
   (cskeep g fs)                                    ; answers fs; a breach scares, naming fn + reg
    (: (rawy? (f . l)) (two? f && (= <f 'raw) ? 1 (rawy? l))
       ; every target with a cs file; a8 has none and bails
       (? (!(two? (cspool g)) || !(two? fs) || g 'hasasm || rawy? fs) fs
          (: fn (<fs 1)
             labs {} saves {} defs {}
             (note l i)
              (? !(two? l) 0
                 (: f <l
                    _ (? !(two? f) 0
                         (= <f 'label) (pin labs <>f 1)
                         (: _ (? (= <f 'push && elem <>f (csregs g))
                                 (? (saves <>f) 0 (pin saves <>f ['push i])) 0)
                            _ (? (= <f 'st &&
                                  (= <>f 'sp || (= <>f 'r4) || (= <>f (fbase g))) &&
                                  elem <>>>f (csregs g))
                                 (? (saves <>>>f) 0 (pin saves <>>>f ['slot <>f <>>f i])) 0)
                            ds (csdefs g f)
                            (? (= ds 'dark) (scare 'cs-dark-op <f)
                               (foldl (\ _ r (defs r ? 0 (pin defs r i))) 0 ds))))
                    (note >l (i + 1))))
             _ (note fs 1)
             dr (filter defs (csregs g))
             ; a fn no path leaves owes nothing back (a main ending in a non-returning call:
             ; deadlab took its epilogue, deadst its saves)
             (anyx? l) (? !(two? l) ()
                          (: f <l
                             (? (xit? f || xjmp? f labs) 1
                                (anyx? >l))))
             (? (!(two? dr) || !(anyx? fs)) fs      ; no cs writes, or no exit: most fns leave here
                (: _ (foldl                         ; every written reg saved, before its first write
                      (\ _ r (: sv (saves r)
                                (? !(two? sv) (scare 'cs-unsaved [fn r])
                                   (: sp9 (sv $ <sv @ 'push 1 3)
                                      (? (sp9 < peep defs r 0) 0 (scare 'cs-save-late [fn r]))))))
                      0 dr)
                   (rest r) (: sv (saves r)  ; the restore shape a save earns
                               (? !(two? sv) ()
                                  (= <sv 'push) ['pop r]
                                  ['ld r <>sv <>>sv]))
                   ; the dirty walk: a written reg is dirty until its restore, a label unions its
                   ; paths in (to a fixpoint), every exit must leave the set empty
                   lst {}                   ; label -> the join of its incoming dirty sets
                   (uni a b) (foldl (\ s r (? (elem r s) s (r . s))) b a)
                   (sub? a b) (? !(two? a) 1 (elem <a b && sub? >a b))
                   (bmark L S) (: old (peep lst L ())
                                  new (uni S old)
                                  (? (sub? new old) 0 (pin lst L new, 1)))
                   (move f S)                       ; one form's transfer on the dirty set
                    (: ds (csdefs g f)
                       S2 (uni (ds @ 'dark dr (filter (r \ elem r dr) ds)) S)
                       (filter (r \ f != rest r) S2))
                   (step l S chg fin)
                    (? !(two? l) chg
                       (: f <l
                          (? !(two? f) (step >l S chg fin)
                             (: k <f
                                dead (= S 'dead)
                                (? (= k 'label)
                                    (step >l (uni (? dead () S) (lst <>f)) chg fin)
                                   dead (step >l S chg fin)
                                   (= k 'br) (step >l S (chg + bmark <>>f S) fin)
                                   (= k 'jmp && labs <>f)
                                    (step >l 'dead (chg + bmark <>f S) fin)
                                   (elem k '(ret jmpr jmp))
                                    (: _ (? fin (foldl (\ _ r (scare 'cs-unrestored [fn r])) 0 S) 0)
                                       (step >l 'dead chg fin))
                                   (step >l (move f S) chg fin))))))
                   (fix n) (? (step fs () 0 ()) (? (n < 24) (fix (n + 1)) (scare 'cs-fix fn)) 0)
                   _ (fix 0)
                   _ (step fs () 0 1)
                   fs)))))

   ; dies on the straight line: overwritten before any read. a ret rides only r0 out; a call or
   ; sibcall jmp (a function symbol -- labels are dot-interned, 46 = '.') kills the door set
   (dies? g rd (f . l))
    (? !(two? f) ()
       (: rs (rdsp g f)
          (? (= rs 'bar)
              (? (retx? f) !(= rd 'r0)
                 (elem <f '(call callr) ||
                  (= <f 'jmp && !(46 = ((show <>f) 0))))
                  ; the door set: caller-saved, never an argument (a64 args ride r0-r7; x64's al is li'd by setal first)
                  (elem rd (? (a64? g) '(r9 r10 r11 r12 r13 r14 r15) '(r0 r9 r10)))
                 ())
             (elem rd <rs) ()
             (elem rd <>rs) 1
             (dies? g rd l))))
   ; the addressing fold: an add/lea/mov consumed as the next load/store's base folds into its
   ; displacement; a live dest keeps the addr insn beside the re-based form. to a fixpoint, x64 only
   (addrf1 g fs)
    (? !(two? fs) ()
       (: f <fs r >fs
          nx (two? r ? <r)
          ; a leax feeding the next ld/ldu1 base is the indexed load (base/index may alias a dying dest)
          lx (? !(two? f && <f = 'leax && two? nx  && elem <nx '(ld ldu1)) ()
                !(= <>>nx <>f) ()
                !(charm? <>>>nx && charm? (f 5)) ()
                [(<nx @ 'ld 'ldx 'ldxb) <>nx <>>f <>>>f (f 4)
                  (f 5 + <>>>nx)])
          ; leax feeding a store's base is the indexed store (the value must not be the leax's dest)
          sx (? (two? lx) ()
                !(two? f && <f = 'leax && two? nx && elem <nx '(st st1)) ()
                !(= <>nx <>f) ()
                !(charm? <>>nx && charm? (f 5)) ()
                (= <>>>nx <>f) ()
                [(<nx @ 'st 'stx 'stxb) <>>f <>>>f (f 4)
                  (f 5 + <>>nx) <>>>nx])
          hit (? (two? lx || two? sx) ()
                 !(two? f && two? nx  && elem <nx ldops9) ()
                 !(= <>>nx <>f) ()               ; the load's base is f's dest
                 !(charm? <>>>nx) ()
                 (elem <f '(lea lean))
                  (charm? <>>>f ? [<>>f (<>>>f + <>>>nx)])
                 (<f = 'add)
                  (charm? <>>>f && !(= <>>f 'sp) && fits32? (<>>>f + <>>>nx) ?
                     [<>>f (<>>>f + <>>>nx)])
                 (<f = 'sub)
                  (charm? <>>>f && !(= <>>f 'sp) && fits32? (<>>>nx - <>>>f) ?
                     [<>>f (<>>>nx - <>>>f)])
                 (<f = 'mov) [<>>f <>>>nx]
                 ())
          ; the store twin: f's dest as the store's base (operand 1; the value must not be f's dest)
          sh (? (two? lx || two? sx || two? hit) ()
                !(two? f && two? nx && (elem <nx stops9 || elem <nx siops)) ()
                !(= <>nx <>f) ()
                !(charm? <>>nx) ()
                (= <>>>nx <>f) ()
                (elem <f '(lea lean))
                 (charm? <>>>f ? [<>>f (<>>>f + <>>nx)])
                (<f = 'add)
                 (charm? <>>>f && !(= <>>f 'sp) && fits32? (<>>>f + <>>nx) ?
                    [<>>f (<>>>f + <>>nx)])
                (<f = 'sub)
                 (charm? <>>>f && !(= <>>f 'sp) && fits32? (<>>nx - <>>>f) ?
                    [<>>f (<>>nx - <>>>f)])
                (<f = 'mov) [<>>f <>>nx]
                ())
          ; the value twin: a mov whose dest rides only the store's value operand renames it
          vh (? (two? lx || two? sx || two? hit || two? sh) ()
                !(two? f && <f = 'mov && !(charm? <>>f) && two? nx && elem <nx gstops) ()
                !(= <>>>nx <>f) ()
                (= <>nx <>f) ()
                [<nx <>nx <>>nx <>>f])
          ; a li riding only the value operand is the store-immediate (x64 only: none elsewhere)
          vi (? (two? lx || two? sx || two? hit || two? sh || two? vh) ()
                (arm? g) ()
                !(two? f && <f = 'li && charm? <>>f && two? nx && elem <nx gstops) ()
                !(= <>>>nx <>f) ()
                (= <>nx <>f) ()
                (: k <>>f s9 (sik <nx k)
                 (s9 ? [s9 <>nx <>>nx k])))
          ; a li negated in place is the negative li -- the constant lanes then see it
          ng (? (two? lx || two? sx || two? hit || two? sh || two? vh || two? vi) ()
                !(two? f && <f = 'li && charm? <>>f && two? nx && <nx = 'neg && (= <>nx <>f)) ()
                ['li <>f -<>>f])
          ; a constant index folds into the displacement, the indexed form collapsing to plain
          xj (? (two? lx || two? sx || two? hit || two? sh || two? vh || two? vi || two? ng) ()
                !(two? f && <f = 'li && charm? <>>f && two? nx) ()
                (elem <nx '(ldx ldxb leax))
                 (: d9 (nx 5 + <>>f * nx 4)
                    (? !(= <>>>nx <>f) () (= <>>nx <>f) ()
                       !(fits32? d9) ()
                       (<nx = 'leax && !(imma g 'add d9)) ()   ; the lea lands as an add imm
                       [(<nx @ 'ldx 'ld 'ldxb 'ldu1 'lea) <>nx <>>nx d9]))
                (elem <nx '(stx stxb))
                 (: d9 (nx 4 + (* <>>f <>>>nx))
                    (? !(= <>>nx <>f) () (= <>nx <>f) () (= (nx 5) <>f) ()
                       !(fits32? d9) ()
                       [(? (<nx = 'stx) 'st 'st1) <>nx d9 (nx 5)])))
          ; a constant right operand rides the alu/cmp imm forms (cfoldir's knowns are green-only)
          aj (? (two? lx || two? sx || two? hit || two? sh || two? vh || two? vi || two? ng || two? xj) ()
                !(two? f && <f = 'li && charm? <>>f && fits32? <>>f && two? nx) ()
                (elem <nx aluops)
                 (? (= <>>>nx <>f) (? (= <>>nx <>f) () (imma g <nx <>>f) [<nx <>nx <>>nx <>>f]))
                (<nx = 'cmp)
                 (? (= <>>nx <>f) (? (= <>nx <>f) () (imma g 'cmp <>>f) ['cmp <>nx <>>f])))
          (? (two? lx)
              (? (= <>nx <>f || dies? g <>f >r) (lx . addrf1 g >r)
                 !(= <>f <>>f || (= <>f <>>>f))
                  (f . lx . addrf1 g >r)
                 !(= <>nx <>>f || (= <>nx <>>>f))
                  (lx . f . addrf1 g >r)
                 (f . addrf1 g r))
             (two? sx)
              (? (dies? g <>f >r) (sx . addrf1 g >r)
                 !(= <>f <>>f || (= <>f <>>>f))
                  (f . sx . addrf1 g >r)
                 (sx . f . addrf1 g >r))
             (two? hit)
              (: nl [<nx <>nx <hit <>hit]
                 (? (= <>nx <>f || dies? g <>f >r) (nl . addrf1 g >r)
                    !(= <>f <hit) (f .  nl . addrf1 g >r)
                    (nl . f . addrf1 g >r)))
             (two? sh)
              (: nl [<nx <sh <>sh <>>>nx]
                 (? (dies? g <>f >r) (nl . addrf1 g >r)
                    !(= <>f <sh) (f . nl . addrf1 g >r)
                    (nl . f . addrf1 g >r)))
             (two? vh)
              (? (dies? g <>f >r) (vh . addrf1 g >r)
                 (f . vh . addrf1 g >r))
             (two? vi)
              (? (dies? g <>f >r) (vi . addrf1 g >r)
                 (f . vi . addrf1 g >r))
             (two? ng) (ng . addrf1 g >r)
             (two? xj)
              (? (= <>nx <>f || dies? g <>f >r) (xj . addrf1 g >r)
                 (f . xj . addrf1 g >r))
             (two? aj)
              (? (= <>nx <>f || dies? g <>f >r) (aj . addrf1 g >r)
                 (f . aj . addrf1 g >r))
             (f . addrf1 g r))))
   (addrfold g fs) (: r (addrf1 g (addrf1 g fs)) (#r = #fs ? r (addrfold g r)))

   ; the branching death proof (cmpfuse's license): dead when no reachable path reads before a
   ; def; ret frees all but r0; a read, an untabled op or a call answers live
   (dieb? g rd all fs0)
    (: seen {}
       (lab l w) (? !(two? l) ()
                    (: f <l (? (two? f && <f = 'label && (= <>f w)) >l (lab >l w))))
       (go l wl)
        (? !(two? l) (next wl)
           (: f <l
              (? !(two? f) (go >l wl)
                 (<f = 'label)
                  (? (seen <>f) (next wl)
                     (: _ (pin seen <>f 1) (go >l wl)))
                 (elem <f '(jmp jmp8)) (next (<>f . wl))
                 (elem <f '(br br8)) (go >l (<>>f . wl))
                 (retx? f) (rd @ 'r0 () (next wl))
                 (: rs (rdsp g f)
                    (? (= rs 'bar) ()
                       (elem rd <rs) ()
                       (elem rd <>rs) (next wl)
                       (go >l wl))))))
       (next wl) (? !(two? wl) 1
                  (: w <wl (seen w ? (next >wl) (pin seen w 1, go (lab all w) >wl))))
       (go fs0 ()))

   ; cmp load-op fusion: (ld X b o)(cmp X y) -> (cmpm b o y), (cmp r X) -> (cmprm r b o) when X
   ; dies beyond. after addrfold; x64 and full-word only (a narrow cmp's flags shift with the extension)
   (cmpfuse g fs)
    (: (go (f . r))
           (: nx (two? r ? <r)
              X (two? f && <f = 'ld && two? nx && <nx = 'cmp ? <>f)
              m (? !(nom? X) ()
                   (= <>nx X)
                    (? (= <>>nx X) ()             ; X both sides never fuses
                       (charm? <>>nx && !(fits32? <>>nx)) ()
                       ['cmpm <>>f <>>>f <>>nx])
                   (= <>>nx X)
                    (charm? <>nx ? () ['cmprm <>nx <>>f <>>>f]))
              (two? m && dieb? g X fs >r ? (m . go >r) (f . go r)))
       (go fs))

   ; store-forward: within a straight run a full-word frame slot rides the register that last
   ; touched it; r3/cs reloads stay (epilogue anchors); an lea off r4 keeps the adjacent pair only
   stldkeep ('r3 . csx64)
   (stldkp g) (? (a64? g) (csregs g) stldkeep)      ; the epilogue-anchor destinations, per target
   (bdropr bs r9) (filter (\ e9 (<>e9 != r9)) bs)
   (bdropo bs o9) (filter (\ e9 (: d (<e9 - o9) ((7 < d) || (d < -7)))) bs)
   (stld g fs)
    (: fb (fbase g)
       ; the epilogue's (lea sp fp 0) is teardown, not an address take
       (esc? (f . l))
        (two? f && elem <f '(lea lean) && <>>f = fb && !(= <>f 'sp) ? 1 (esc? l))
       fs2 (stldp fb fs ())
       (esc? fs2 ? (stlda fb fs2) (stldw g fb (stldkp g) fs2 ())))
   ; the adjacent pair needs no aliasing story. the full-width frame pair stays with the lanes
   ; below (slot map, anchors); narrow pairs forward on any base, at the load's extension
   (fwext s l) (s @ 'st (l @ 'ld 'mov)
                   'st4 (l @ 'ldu4 'zx4 'ld4 'sx4)
                   'st2 (l @ 'ldu2 'zx2 'ld2 'sx2)
                   'st1 (l @ 'ldu1 'zx1 'ld1 'sx1))
   (fwfs w rY rX) (? (= w 'mov) (rY != rX ? [['mov rY rX]])
                     (rY = rX) [[w rX]]
                     [['mov rY rX] [w rY]])
   ; a store fed by an adjacent li declines: that triple is the si fold's
   (stldp fb (f . r) pv)
    (? !(two? r && two? f && elem <f gstops && !(<f = 'st && <>f = fb))
       (f . stldp fb r f)
       (: nx <r
          rX <>>>f
          w (two? nx ? (fwext <f <nx))
          (? (= w () ||
              (two? pv && <pv = 'li && <>pv = rX) ||
              !(<>>nx = <>f && <>>>nx = <>>f))
             (f . stldp fb r f)
             (f . fwfs w <>nx rX + stldp fb >r f))))
   (stlda fb (f . r))                                     ; the escape lane: only the pair with nothing between is aliasing-proof
    (? !(two? r && two? f && <f = 'st && <>f = fb)
       (f . stlda fb r)
       (: nx <r
          rX <>>>f
          (? !(two? nx && <nx = 'ld && <>>nx = fb && <>>>nx = <>>f)
             (f . stlda fb r)
             (: rY <>nx
                (rY = rX ? (f . stlda fb >r)
                 (f . ['mov rY rX] . stlda fb >r))))))
   (stldw g fb keep (f . r) bs)
    (? !(two? f) (f . stldw g fb keep r bs)
       (: op <f
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
                 (? (op = 'st && nom? <>>>f)
                    (f . stldw g fb keep r ([o <>>>f] . b2))
                    (f . stldw g fb keep r b2)))
             ; a full-width si binds its constant (a narrow one just invalidates): a later ld remats as li
             (elem op siops && <>f = fb)
              (: o <>>f
                 b2 (bdropo bs o)
                 (? (op = 'si)
                    (f . stldw g fb keep r ([o ['k <>>>f]] . b2))
                    (f . stldw g fb keep r b2)))
             ; a reg-reg mov carries its src's bindings; sp/fp/r4 stay out (sp's defs are empty by design)
             (op = 'mov && nom? <>f && nom? <>>f
                 && !(elem <>f '(sp fp r4)) && !(elem <>>f '(sp fp r4)))
              (: rY <>f rB <>>f
                 news (map (\ e9 [<e9 rY]) (filter (\ e9 (<>e9 = rB)) bs))
                 (f . stldw g fb keep r (news + bdropr bs rY)))
             (: rd (rdsp g f)
                (? (= rd 'bar) (f . stldw g fb keep r ())
                   (elem fb <>rd) (f . stldw g fb keep r ())
                   (f . stldw g fb keep r (filter (\ e9 !(elem <>e9 <>rd)) bs)))))))

   ; rezx: a zxN over a register already clean to N drops (clean: zx, ldu, the 32-bit rotates, li,
   ; mov). a set is clean to 1, so `cmp r 0; set ne r` over it drops unless the next form reads flags
   (rezx g fs)
    (: (go l t acc)
        (? !(two? l) (rev acc)
           (: f <l r >l
              (? !(two? f) (go r t (f . acc))
                 (: op <f
                    (? (op = 'cmp && (peep t <>f 0) = 1 && (<>>f = 0) &&
                        two? r && (<r = ['set 'ne <>f]) &&
                        !(two? >r && two? <>r && elem <<>r '(br br8 set)))
                        (go >r t acc)
                       (op = 'set)
                        (: _ (pin t <>>f 1) (go r t (f . acc)))
                       (elem op '(zx1 zx2 zx4))
                        (: w (? (op = 'zx1) 8 (op = 'zx2) 16 32)
                           c (peep t <>f 0)
                           (? ((0 < c) && (c <= w)) (go r t acc)
                              (: _ (pin t <>f w) (go r t (f . acc)))))
                       (elem op '(ldu1 ldu2 ldu4))
                        (: _ (pin t <>f (? (op = 'ldu1) 8 (op = 'ldu2) 16 32))
                           (go r t (f . acc)))
                       (op = 'ror4)
                        (: _ (pin t <>f 32) (go r t (f . acc)))
                       (op = 'rorv4)
                        (: _ (pin t 'r1 0) _ (pin t <>f 32) (go r t (f . acc)))
                       (op = 'li)
                        (: k <>>f
                           _ (pin t <>f (? !(charm? k) 0 (k < 0) 0
                                           (k < 2) 1 (k < 256) 8 (k < 65536) 16
                                           (k < 4294967296) 32 0))
                           (go r t (f . acc)))
                       (op = 'mov)
                        (: _ (pin t <>f (peep t <>>f 0)) (go r t (f . acc)))
                       (: rd (rdsp g f)
                          (? (= rd 'bar) (go r {} (f . acc))
                             (: (dirty ds) (? !(two? ds) 0
                                              (: _ (pin t <ds 0) (dirty >ds)))
                                _ (dirty <>rd)
                                (go r t (f . acc))))))))))
       (go fs {} ()))

   ; copy propagation: after (mov a b) later reads of a say b; once nothing reads a the copy
   ; drops. sp/fp/r4/r3 stay out: pro4?/epim?/sibjmp/unframe read the prologue and epilogue by shape
   (hmov? f) (two? f && <f = 'mov && nom? <>f && nom? <>>f
               && !(elem <>f '(sp fp r4 r3)) && !(elem <>>f '(sp fp r4 r3)))
   ; forms that keep their operands: addrfold owns a mov feeding an address, cskeep reads
   ; (push <cs>) as a save, a variable shift's count must stay in r1
   cpskip (ldops9 + gstops + stxops + siops + leaops + xops + fldops + fstops + vshops +
           '(cmpm cmprm push))
   ; the read-only positions of a form, probed off rdsp with a stranger ('zq): a read-modify-write slot declines
   (cprp g f)
    (? (elem <f cpskip) ()
       (: (go i acc)
           (? !(i < #f) (rev acc)
              (: x (f i)
                 (? !(nom? x) (go (i + 1) acc)
                    (: d (rdsp g (reop f i 'zq))
                       (? (= d 'bar) (go (i + 1) acc)
                          (elem 'zq <d && !(elem 'zq <>d)) (go (i + 1) (i . acc))
                          (go (i + 1) acc))))))
          (go 1 ())))
   ; the substitute must be a stranger to the form's defs (the two-address expansion writes dest
   ; first). a mov passes ds empty (the self-mov we hunt); an alu's first source welcomes its dest
   (cpsub f ps m ds)
    (? !(two? ps) f
       (: i <ps x (f i)
          b (peep m x ())
          two (elem <f aluops && (i = 2))
          (cpsub (? (nom? b && (two || !(elem b ds))) (reop f i b)
                    f)
                 >ps m ds)))
   (cpkill m ds)                                    ; a def kills its own copy and every copy of it
    (: _ (foldl (\ _ k (elem k ds || elem (m k) ds ? (pin m k ()) 0)) 0 (keys m))
       m)
   (cpwalk g (f . u) m)
    (? !(two? f) (f . cpwalk g u m)
       (: op <f
          (? (elem op '(br align ud2)) (f . cpwalk g u m)   ; a br rides its fall-through
             (elem op '(label jmp jmpr ret)) (f . cpwalk g u {})
             (: d (rdsp g f)                    ; a call and every op off the table land here
                (? (= d 'bar) (f . cpwalk g u {})
                   (: f2 (cpsub f (cprp g f) m (op @ 'mov () <>d))
                      (? (hmov? f2 && (= <>f2 <>>f2)) (cpwalk g u m)
                         (: m2 (cpkill m <>d)
                            _ (? (hmov? f2) (pin m2 <>f2 <>>f2) 0)
                            (f2 . cpwalk g u m2)))))))))
   (copyprop g fs) (cpwalk g fs {})                 ; rides the build tail without liveness (build may run twice per fn); the drop rides coal

   ; -- aggregate initializers: ('init (item..)), items plain | ('dfield
   ; name val) | ('didx n val), nesting for arrays of structs. shared bits: --
   (aggish? ty) (arr? ty || stru? ty)
   ; the seeded complex tags: a complex is a scalar to brace elision
   (gcplx? ty) (stru? ty && elem <>ty '("__cplx_double" "__cplx_float"))
   (elval it) (elem <it '(dfield didx) ? <>>it it)   ; the value of an item
   (fidx fields name) (: (go l i) (? (atom? l) 0 (<<l = name) i (go >l (i + 1)))
                          (go fields 0))
   (nthfield fields i) (0 <= i && i < #fields ? (fields i) 'bad)

   ; brace elision (C 6.7.9): the init tree normalizes up front, each elided run wrapped in an
   ; explicit ('init ..), so layout only sees fully-braced inits. idempotent
   (initval? ('init . _)) 1
   ; a wide literal (a clit-of-array) initializes an array; a pointer element keeps the clit (it decays)
   (clarr? ty ini) (arr? ty && !(ptr? <>ty) && two? ini && (<ini = 'clit) && arr? <>ini)
   (unelide g ty ini)                               ; normalize ini against ty
    (? (clarr? ty ini) (unelide g ty <>>ini)      ; a wide literal: take its init
       !(initval? ini) ini                        ; a scalar / non-brace: nothing to nest
       !(aggish? ty) ini                           ; a brace on a scalar type: leave (layout unwraps/scares)
       ; { "s" } on a char array (C11 6.7.9p14): unwrap to the bare literal
       (arr? ty && !(ptr? <>ty) &&
        (: its <>ini (two? its && !(two? >its) && two? <its && (= <<its 'str))))
        <<>ini
       (arr? ty && !(ptr? <>ty) &&                   ; { L"s" }: p14's wide twin
        (: its <>ini (two? its && !(two? >its) && two? <its && (= <<its 'clit) && arr? <><its)))
        (unelide g ty <>><<>ini)
       (: pr (normfill g ty <>ini) ['init <pr]))     ; <pr = normed items; <>pr (excess) dropped
   (redesig dh dk v) [dh dk v]   ; ('didx k v) | ('dfield k v)
   (normelt g ty desig dh dk val l)                 ; one element of type ty from item stream l -> (item rest)
    (? (arr? ty && !(ptr? <>ty) && two? val && (= <val 'str))
        [<l >l]                                    ; a string is a char array's whole element -- never an elision run
       (clarr? ty val)                              ; a wide literal: the whole element, as its init
        (: w (unelide g ty <>>val)
           [(? desig (redesig dh dk w) w) >l])
       (aggish? ty && (!(gcplx? ty) && !(initval? val)))   ; elide: fill ty from the run starting at val (never into a complex -- a scalar)
        (: pr (normfill g ty (val . >l))
           w ['init <pr]
           [(? desig (redesig dh dk w) w) <>pr])
       (: nv (? (initval? val) (unelide g ty val) val)  ; a braced sub -> recurse-normalize; a scalar -> as-is
          [(? desig (redesig dh dk nv) (? (= nv val) <l nv)) >l]))
   (normfill g ty items)                            ; consume items to fill aggregate ty -> (normed-items rest)
    (? (arr? ty)
        (: elt <>ty n <>>ty
           (go l idx acc)
            (? !(two? l) [(rev acc) ()]
               (: it <l
                  desig (<it = 'didx)
                  ; full and plain ends the walk; a designator may jump back ({ [2] = 9, [0] = 1 })
                  (!desig && 0 < n && n <= idx ? [(rev acc) l]
                     (: ci (? desig <>it idx)
                        pr (normelt g elt desig 'didx ci (elval it) l)
                        (go <>pr (ci + 1) (<pr . acc))))))
           (go items 0 ()))
       (stru? ty)
        (: fields <(peep (g 'stag) <>ty 0)
           (go l cur acc)
            (? !(two? l) [(rev acc) ()]
               (: it <l
                  desig (<it = 'dfield)
                  ci (? desig (fidx fields <>it) cur)
                  fe (nthfield fields ci)
                  (? (bad? fe) [(rev acc) l]          ; unknown field / past the end -> leave the rest
                     (: pr (normelt g <>>fe desig 'dfield <>it (elval it) l)
                        (go <>pr (ci + 1) (<pr . acc))))))
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
    (: (go i acc) (? (i < 0) acc (go (i - 1) ([['li 'r0 (text i)] ['st1 'r4 (off + i) 'r0]] + acc)))
       (go (#text - 1) ()))
   (cgstore g env off ty val)                       ; store a scalar value expr into [r4+off]
    (: r (cgexpr g env val ())
       (? (bad? r) 'bad
          (flo? ty) (asflo g r + fstf g ty 'r4 off 'f0)
          (pair? g ty) (asll g r + pst 'r4 off)
          (asintt g r ty + cvt ty 'r0 + [[(stop ty) 'r4 off 'r0]])))
   (cgfill g env off ty ini0)                       ; fill an aggregate at frame offset off (no zero)
    (: ini (unelide g ty ini0)                        ; normalize elided braces (idempotent)
     (?- 'bad
      (<ini == 'str) (arr? ty ? (cgstr off <>ini) 'bad)
      (<ini != 'init) 'bad
      (arr? ty)
       (: elt <>ty esz (tsz g elt)
          (fill l idx acc)
           (? !(two? l) acc
              (: it <l
                 ci (? (<it = 'didx) <>it idx)
                 val (elval it)
                 eoff (off + ci * esz)
                 r (? (aggish? elt && <val = 'init) (cgfill g env eoff elt val)
                      (stru? elt && <val != 'str) (cgsfill g env eoff elt val)
                      (cgstore g env eoff elt val))
                 (bad? r ? 'bad (fill >l (ci + 1) (acc + r)))))
          (fill <>ini 0 ()))
      (stru? ty)
       (:- (fill <>ini 0 ())
        fields <(peep (g 'stag) <>ty 0)
        (fill l cur acc)
         (? !(two? l) acc
            (: it <l
               ci (? (<it = 'dfield) (fidx fields <>it) cur)
               val (elval it)
               fe (nthfield fields ci)
               (bad? fe ? 'bad
                  (: foff (off + <>fe) fty <>>fe
                     r (? (aggish? fty && (<val = 'init)) (cgfill g env foff fty val)
                          (stru? fty && !(<val = 'str)) (cgsfill g env foff fty val)
                          (bitf? fty) (cgbffill g env foff fty val)
                          (cgstore g env foff fty val))
                     (bad? r ? 'bad (fill >l (ci + 1) (acc + r))))))))))
   ; a bitfield member: read-modify-write its unit at [r4+off] (cgstore would flatten the unit)
   (cgbffill g env off bt val)
    (: r (cgexpr g env val ())
       (bad? r ? 'bad
          (: uty <>bt bitoff <>>bt usz (tsz g uty)
             mask ((1 << <>>>bt) - 1) cmask ((0 - (mask << bitoff)) - 1)
             (asintt g r uty
              + (? (= uty 'bool) (cvt uty 'r0) ())   ; normalize before the mask
              + [[(uldop usz) 'r2 'r4 off]
                  ['li 'r3 mask] '(and r0 r0 r3)
                  ['li 'r3 cmask] '(and r2 r2 r3)
                  '(mov r3 r0)]
              + (? (bitoff > 0) [['shl 'r3 bitoff]] ())
              + ['(or r2 r2 r3) [(stop uty) 'r4 off 'r2]]))))
   ; a complex width flip, src in r0, dest in r1: componentwise convert
   (cxcopy g sty)
    (? (= (cxb sty) 'float)
        '((ldss f2 r0 0) (cvtss2sd f2 f2) (stsd r1 0 f2)
          (ldss f2 r0 4) (cvtss2sd f2 f2) (stsd r1 8 f2))
        '((ldsd f2 r0 0) (cvtsd2ss f2 f2) (stss r1 0 f2)
          (ldsd f2 r0 8) (cvtsd2ss f2 f2) (stss r1 4 f2)))
   ; a member from a struct-valued expr: block copy from r0 (a complex width flip converts);
   ; a complex member from a real expr ({3.0}) gets re = value, im = 0
   (cgsfill g env foff fty val)
    (: rl (matv g (clval g env val))
       rv (? (!(bad? rl) && stru? (vty rl)) rl (cgexpr g env val ()))
       (?- 'bad
        (bad? rv) 'bad
        (stru? (vty rv))
         (: mv (tor0 g rv + [['lea 'r1 'r4 foff]])
            (? (gcplx? fty && gcplx? (vty rv) && !(<>fty = <>(vty rv)))
               (mv + cxcopy g (vty rv))
               (mv + bcopy g 0 (tsz g fty) ())))
        (gcplx? fty)
         (: b (cxb fty)
            (asflo g rv + (fstf g b 'r4 foff 'f0
             + ('((li r2 0))
                + (b = 'float ? [['st4 'r4 (foff + 4) 'r2]] [['st 'r4 (foff + 8) 'r2]])))))))

   ; global init (a constant byte image): scalars little-endian, aggregates a placement flatten,
   ; a pointer an abs64 fixup -- one list item but eight bytes, so lengths go through imbytelen
   (fixit? x) (two? x && (<x = 'fix))
   (imbytelen l) (foldl (\ a x (a + (? (fixit? x) <>x 1))) 0 l)
   ; // and %, not & and >>: a big's bitwise ops are undefined. raw bytes only: bfover feeds
   ; it merged unit bits, so bool normalization stays in imgbytes
   (imnum g ty val) (: n (tsz g ty)
                       (pw k acc) (? (k < 1) acc (pw (k - 1) (acc * 256)))
                       u0 (? (val < 0) (val + pw n 1) val)
                       (go i v acc) (? (n <= i) (rev acc)
                                       (go (i + 1) (v // 256) (v % 256 . acc)))
                       (go 0 u0 ()))
   (iminsert x l) (? !(two? l) [x]                    ; insert (off items) keeping offsets ascending
                     (<x < <<l) (x . l)
                     (<l . iminsert x >l))
   (imsort ps) (: (go l acc) (? !(two? l) acc (go >l (iminsert <l acc))) (go ps ()))
   (imflat ps total)                                ; sorted (off items).. -> total bytes, gaps zeroed
    (: (go l pos acc)
        (? !(two? l) (acc + zeros (total - pos))
           (: p <l off <p items <>p
              (go >l (off + imbytelen items) (acc + zeros (off - pos) + items))))
       (go ps 0 ()))
   ; a cast on a folded integer (C11 6.3.1.3): narrow types wrap and re-sign, word-sized keep the pattern
   (icast ty v)
    (ty @ 'bool (v != 0)
          'uchar (v & 255) 'ushort (v & 65535) 'uint (v & 4294967295)
          ('char || 'short || 'int)
           (: w (ty @ 'char 8 'short 16 32)
              r (v & ((1 << w) - 1))
              (r < (1 << (w - 1)) ? r (r - (1 << w))))
          v)
   ; a constant integer expression at image time -> value | 'no; `//` truncates toward zero like C's `/`
   (icfold e)
    (? !(two? e) 'no
    (<e @ 'num <>e
       ; a cast may carry a float operand (C11 6.6p6): truncates toward zero, as `// 1` does
       'cast (: v (icfold <>>e)
              (? (flo? <>e) 'no
                 !(v = 'no) (icast <>e v)
                 (: f (ffold <>>e)
                    (? (bad? f) 'no
                       (<>e = 'bool) (f = 0.0 ? 0 1)          ; to _Bool is a compare, never a truncation
                       (icast <>e (ceil (f // 1)))))))
       'un
        (: v (icfold <>>e)
           (? (v = 'no) 'no (<>e = 'neg) -v (<>e = 'bnot) (-v - 1) 'no))
       'bin (: op <>e a (icfold <>>e) b (icfold <>>>e)
             (? (a = 'no || b = 'no) 'no
              (op @ '+ (a + b) '- (a - b) '* (a * b)
                    '/ (? (b = 0) 'no (a // b)) '% (b = 0 ? 'no (a - (a // b) * b))
                    'shl (a << b) 'shr (a >> b)
                    '& (a & b) '| (a | b) '^ (a ^ b)
                    'no)))
       'no))
   ; a constant lvalue at image time -> (label byteoffset type) | 'no: a global, *(const ptr),
   ; or a .member off either; the type threads so the next .member scales
   (imlval g e)
    (<e @ 'var
            (? (g 'fns <>e) [(name <>e) 0 (fnty g <>e)]   ; a function is its address
               (: en (peep (g 'glob) <>e 0)               ; glob = (label type init)
                (two? en ? [<en 0 <>en] 'no)))
           'deref
            (: p (imaddr g <>e) (? (= p 'no) 'no [<p <>p <><>>p]))
           'dot
            (imlval g <>e @ 'no 'no b
             (: fm (fmem g <>>b <>>e) (bad? fm ? 'no [<b (<>b + <fm) <>fm])))
           'no)
   ; a constant address at image time -> (label byteoffset ptrtype) | 'no; a cast retypes, so
   ; a later + scales by the new pointee
   (imaddr g e)
    (<e @ 'cast
        (: r (imaddr g <>>e)
           (r @ 'no 'no [<r <>r <>e]))
       'str
        (: l (nlab g ".S") _ (pin g 'strs ([l <>e] . g 'strs)) [l 0 '(ptr char)])
       'var
        (? (peep (g 'fns) <>e ()) [(intern <>e) 0 ['ptr (fnty g <>e)]]
           (: en (peep (g 'glob) <>e 0)
              ; neither a function nor a global: pin 'undecl (as cgfn does) so the diagnostic names it
              (? !(two? en) (: _ (pin g 'undecl <>e) 'no)
                 (: ty <>en (? (arr? ty) [<en 0 ['ptr <>ty]] [<en 0 ['ptr ty]])))))
       'addr
        (: lv (imlval g <>e) (? (= lv 'no) 'no [<lv <>lv ['ptr <>>lv]]))
       ('bin && elem <>e '(+ -))
        ; label +/- int: a pointer type scales by the pointee, an integer-typed label ((word)&x + 8) adds bytes
        (: op <>e
           (imscale ty) (? (ptr? ty) (tsz g <>ty) 1)
           pa (imaddr g <>>e) kb (icfold <>>>e)
           (? (pa != 'no && kb != 'no)
               [<pa (<>pa + (op @ '- -kb kb) * imscale <>>pa) <>>pa]
              (: pb (imaddr g <>>>e) ka (icfold <>>e)
                 (? (op = '+ && pb != 'no && ka != 'no)
                     [<pb (<>pb + ka * imscale <>>pb) <>>pb]
                    'no))))
       'no)
   ; a const float expression at image time -> gem | 'bad (love's doubles are the target's IEEE doubles)
   (ffold e) (atom? e ? 'bad
     ; an int const subtree floats ((double)(1 << N))
     (: iv (icfold e)
        (? !(= iv 'no) (0.0 + iv)
        (<e @ 'flo <>e
            'num (0.0 + <>e)
            'cast (flo? <>e ? (ffold <>>e) 'bad)
            'un (: v (ffold <>>e) (? (bad? v) 'bad (<>e = 'neg) (-1.0 * v) 'bad))   ; times -1: 0.0 - 0.0 is +0.0, and -0.0 is its own value
            'bin
            (: op <>e a (ffold <>>e) b (ffold <>>>e)
               (? (bad? a || bad? b) 'bad
               (op @ '+ (a + b) '- (a - b) '* (* a b)
                  '/ (b = 0.0 ? 'bad (a / b))
                  'bad)))
           'bad))))
   (fim ty v)                                       ; a float value's IEEE image as ty: 4 single bytes | 8 double bytes
    (ty = 'float ? (les 4 (fbits32 v)) (les 8 (fbits v)))
   (imgbytes g ty ini)                              ; a byte/fix list of length tsz(ty) | 'bad
    (?- 'bad
     (atom? ini) (zeros (tsz g ty))
     (<ini = 'flo) (? (flo? ty) (fim ty <>ini) 'bad)
     (<ini = 'num) (? (aggish? ty) 'bad
                           (flo? ty) (fim ty (0.0 + <>ini))
                           (= ty 'bool) (imnum g ty (? (<>ini = 0) 0 1))   ; a bool image normalizes (C11 6.3.1.2)
                           (imnum g ty <>ini))
     (flo? ty && elem <ini '(bin un cast))       ; a const float expression: fold, then image
      (: v (ffold ini)
         (? (bad? v) 'bad (fim ty v)))
     (<ini = 'str && arr? ty)
      (: t <>ini n (tsz g ty)
         (bs i acc) (? (n <= i) (rev acc) (bs (i + 1) ((? (i < tally t) (t i) 0) . acc)))
         (bs 0 ()))
     (clarr? ty ini) (imgbytes g ty <>>ini)          ; a wide literal at file scope: its init is the image
     (ptr? ty) (: r (imaddr g ini)                    ; a data pointer: a constant address (word-sized abs label+offset),
                   (? !(= r 'no) [['fix (wsize g) (? (t32? g) 'abs32 'abs64) <r <>r]]      ; or a constant integer ((int*)0x1000, a null)
                      (: v (icfold ini) (? (= v 'no) 'bad (imnum g ty v)))))
     ; a label cast to a word-sized integer ((intptr_t)f) is still its address
     (<ini = 'cast && !(aggish? ty) && !(flo? ty) && tsz g ty = wsize g)
      (: r (imaddr g ini)
         (? !(= r 'no) [['fix (wsize g) (? (t32? g) 'abs32 'abs64) <r <>r]]
            (: v (icfold ini) (? (= v 'no) (imgbytes g ty <>>ini) (imnum g ty v)))))
     ; a constant expression parse's cfold left: a float through a cast ((int)(0.867 * (1 << 16)))
     (!(aggish? ty) && !(flo? ty) && elem <ini '(bin un cast))
      (: v (icfold ini) (? (= v 'no) 'bad (imnum g ty v)))
     (<ini = 'init)
      (: nini (unelide g ty ini)                     ; normalize elided braces (idempotent)
       (?- 'bad
        (<nini != 'init) (imgbytes g ty nini)           ; unwrapped ({ "s" } -> the bare literal): re-dispatch
        (arr? ty) (: elt <>ty esz (tsz g elt)
                     (place l idx acc)                     ; -> ((off items)..) | 'bad
                      (atom? l ? acc
                       (: it <l
                          ci (? (<it = 'didx) <>it idx)
                          eb (imgpad g elt esz (elval it))
                        (bad? eb ? 'bad (place >l (ci + 1) ([(* ci esz) eb] . acc)))))
                     ps (place <>nini 0 ())
                     (bad? ps ? 'bad (imflat (imsort ps) (* <>>ty esz))))
        (stru? ty)
          ; a bitfield takes no placement: it merges into its unit, overlaid on the flattened image
          (: e (peep (g 'stag) <>ty 0)
             fields <e size <>e
             (place l cur acc bfs)                ; -> (((off items)..) ((uoff uty bits)..)) | 'bad
              (atom? l ? [acc bfs]
               (: it <l
                  ci (? (<it = 'dfield) (fidx fields <>it) cur)
                  fe (nthfield fields ci)
                (? (bad? fe) 'bad
                   (bitf? <>>fe)
                    (: v (icfold (elval it))
                       (v = 'no ? 'bad
                        (place >l (ci + 1) acc (bfmerge g <>fe <>>fe v bfs))))
                   (: fb (imgpad g <>>fe (tsz g <>>fe) (elval it))
                    (bad? fb ? 'bad (place >l (ci + 1) ([<>fe fb] . acc) bfs))))))
             pr (place <>nini 0 () ())
             (bad? pr ? 'bad (bfover g <>pr (imflat (imsort <pr) size)))))))
   ; bitfield units, ((uoff uty value)..): arithmetic only, a 64-bit unit's mask is a big (% takes low bits, * shifts)
   (pw2 n) (? (n < 1) 1 (2 * pw2 (n - 1)))
   (bfmerge g uoff bt v rows)
    (: v9 (? (= <>bt 'bool) (? (v = 0) 0 1) v)    ; a bool field's image normalizes
       m (pw2 <>>>bt)
       lo (((v9 % m) + m) % m)                      ; the low `width` bits, a negative wrapped in
       bits (lo * pw2 <>>bt)
       ; a merged row keeps the wider unit, or a bool/char neighbour truncates the write
       (go l) (? !(two? l) [[uoff <>bt bits]]
                 (<<l = uoff) (: u9 (? (tsz g <><l < tsz g <>bt) <>bt <><l)
                                 ([uoff u9 (<>><l + bits)] . >l))
                 (<l . go >l))
       (go rows))
   ; or each unit's bytes into the flattened image; a fixup in the way (one item, eight bytes) refuses
   (bfover g rows bytes)
    (: (lay img uoff ub)
        (: (go l pos acc)
            (? (atom? l) acc
               (fixit? <l)
                (? (pos + 8 > uoff && uoff + #ub > pos) 'bad
                   (go >l (pos + 8) (acc + [<l])))
               (: b (? (uoff <= pos && pos < uoff + #ub) (<l | ub (pos - uoff)) <l)
                  (go >l (pos + 1) (acc + [b]))))
           (go img 0 ()))
       (fold l img)
        (atom? l ? img
         (: n (lay img <<l (imnum g <><l <>><l)) (bad? n ? 'bad (fold >l n))))
       (fold rows bytes))
   (imgpad g ty w val)                              ; imgbytes padded (with zeros) to w bytes | 'bad
    (: b (imgbytes g ty val) (? (bad? b) 'bad (b + zeros (w - imbytelen b))))
   (cgimage g ty ini)                               ; the full span-padded image | 'bad
    (: span ((tsz g ty + wsize g - 1) & -(wsize g))         ; round to the word (8 on x64/a64, 4 on t32)
       raw (imgbytes g ty ini)
       (? (bad? raw) 'bad (raw + zeros (span - imbytelen raw))))

   ; the inline-asm register file (cgasm; cgdecl reads it for a register variable's pin)
   asmregs '(r0 r1 r2 r3 r5 r6 r7 r8 r9 r10)
   asmpick '(r10 r9 r8 r7 r6 r5 r2 r1 r0)
   asmnames (foldl (\ t i (: s9 ("r" + show i) (pin t (name s9) s9))) {} ^11)
   (asmreg? g r9) (elem r9 asmregs || (a64? g && (= r9 'r4)))
   ; callee-saved seats a clobber may name past the asm file: pushed and popped around the body
   (asmsave? g r9) (? (x64t? g) (elem r9 csx64)
                      (a64? g) (elem r9 '(r11 r12 r13 r14 r15 r16 r17 r18 r19 r20 r21 r22 r23 r24 r25 r26 r27 r28))
                      (rv64? g) (elem r9 '(r11 r12 r13 r14 r15 r19 r20 r21 r22 r23 r24 r25 r26))
                      (elem r9 '(r5 r6 r7 r8 r9 r10 r11 r12)))
   ; a declaration list ((name ty init)..) -> (forms env) | 'bad. a homable scalar ticks the decl
   ; seq (deterministic across ubuild's attempts: splices don't tick) and asks g 'lhome for a home
   (cgdecl g env pairs)
    (: ; the C99 VLA local: free any prior instance from this site (a loop re-runs the decl), size,
       ; sub sp, stash the block pointer; the fn stays out of sibcalls and homing (fesc + hasasm)
       v16 '((add r0 r0 15) (shr r0 4) (shl r0 4))   ; rounded up to 16: shr/shl, a64's encoder refuses ~15 as an and immediate
       vsub '((lea r1 sp 0) (sub r1 r1 r0) (lea sp r1 0))   ; sp -= r0 through a plain register: on a64 only lea (add-immediate) sees 31 as sp
       (vone ps env2 acc p ty)
        (: sl (peep (g 'vslots) (varix ty) ())
           (? !(two? sl) 'bad
              (: po <sl so <>sl
                 es (tsz g (varel ty))
                 _ (pin g 'fesc 1) _ (pin g 'hasasm 1)
                 dr (cgexpr g env2 (varn ty) ())
                 (? (bad? dr) 'bad
                    (: lf (nlab g ".vla")
                       code ([['ld 'r0 'r4 so] '(cmp r0 0) ['br 'eq lf]]
                             + v16
                             + [['ld 'r1 'r4 po] '(add r1 r1 r0) '(lea sp r1 0)
                                 ['label lf]]
                             + asint g dr
                             + (? (1 < es) (imby g 'r0 es) ()) + [['st 'r4 so 'r0]]
                             + v16 + vsub + ['(lea r0 sp 0) ['st 'r4 po 'r0]])
                       (one >ps ([<p po ty] . env2) (acc + code)))))))
       (one ps env2 acc)
        (? !(two? ps) [acc env2]
           (: _ (psreset g)
              p <ps
              ty <>p
              init <>>p
              ; a `register T v asm("reg")` local naming a register the asm surface cannot
              (? (two? >>>p && (: r9 (gas-regname (gtgt g) <>>>p) !(nom? r9 && asmreg? g r9)))
                  (nolane g ("no lane for a register variable in " + <>>>p + ontgt g))
                 (gvarr? ty)
                  (? (two? init)
                      (nolane g "a variable-length array cannot take an initializer")
                     !(elem (gtgt g) '(x64 a64 rv64))
                      (nolane g ("no lane for a variable-length array" + ontgt g))
                     (vone ps env2 acc p ty))
                 (: span (& (tsz g ty + 7) -8)
              off (nslot g span)
              hreg (? (g 'inlining)
                      ; a splice's body decl takes a pool seat when cginl licensed the name (inlrb),
                      ; held in rpin and freed by the splice (inlrbs); seat-bearing builds (rgon) only
                      (? (g 'rgon &&
                          lhomable? ty &&
                          elem <p (g 'inlrb) &&
                          deep? (g 'pool))
                          (: rb (ralloc g)
                             (? !rb ()
                                (: _ (pins g 'rpin ((rp g rb) . g 'rpin)
                                             'inlrbs (rb . g 'inlrbs))
                                   rb))))
                      !(lhomable? ty || (d128? ty && w128? g)) ()
                      (: sq (1 + peep g 'dseq 0)
                         _ (pins g 'dseq sq
                                   'lrec ([sq off ty <p] . g 'lrec))
                         lht (g 'lhome)
                         (? lht (lht sq) ())))
              ; a register variable's pin rides the env entry's fourth slot for cgasm
              apin (? (two? >>>p) (gas-regname (gtgt g) <>>>p) ())
              ; a d128's home is a pair (lo hi) off the cs pool -- ulloc packs two seats
              env3 (([<p (? (two? hreg) ['regw hreg] hreg ['reg hreg] off) ty] + (? (nom? apin) [apin] ())) . env2)
              ; a callee-saved home stays off g 'homes: no call wrap, no sib peel, and ezarg must not read its unwritten shadow
              _ (? (hreg && !(two? hreg) && !(elem hreg (cspool g)))
                   (pin g 'homes ([(rp g hreg) off <p] . g 'homes)))
              ; a constant init of a plain slotted scalar is one store-immediate; bool keeps its cvt (0/1)
              si9 (? (x64t? g && !hreg && (<init = 'num) && charm? <>init &&
                      !(flo? ty || pair? g ty || d128? ty || ty == 'bool))
                     (siop9 ty <>init) ())
              (? (atom? init) (one >ps env3 acc)
                 (<init = 'init || <init = 'str && arr? ty || clarr? ty init)
                  (? ((<init = 'init) && !(aggish? ty)) 'bad      ; a brace for a scalar
                     (: f (cgfill g env3 off ty init)
                        (? (bad? f) 'bad
                           (one >ps env3 (acc + cgzero g off span + f)))))
                 (arr? ty) 'bad                          ; a bare-expr init of an array
                 si9 (one >ps env3 (acc + [[si9 'r4 off <>init]]))
                 (stru? ty)                              ; a struct local from a struct value (an address): copy its bytes
                  (: r (cgexpr g env3 init ())
                     (? (bad? r) 'bad
                        (: sz (tsz g ty)
                           cpf (: (go k acc9)
                                   (? (8 <= sz - k && !(t32? g))
                                       (go (k + 8) (acc9 + [['ld 'r1 'r0 k] ['st 'r4 (off + k) 'r1]]))
                                      (4 <= sz - k) (go (k + 4) (acc9 + [['ld4 'r1 'r0 k] ['st4 'r4 (off + k) 'r1]]))
                                      (2 <= sz - k) (go (k + 2) (acc9 + [['ld2 'r1 'r0 k] ['st2 'r4 (off + k) 'r1]]))
                                      (1 <= sz - k) (go (k + 1) (acc9 + [['ld1 'r1 'r0 k] ['st1 'r4 (off + k) 'r1]]))
                                      acc9)
                                  (go 0 ()))
                           (one >ps env3 (acc + tor0 g r + cpf)))))
                 (: w9 (? (hreg && !(two? hreg)) hreg ())   ; the home is the destination (the asn regv arm's shape)
                    r (cgexpr g env3 init w9)               ; a scalar (a pointer = string rides cgexpr -> la)
                    (? (bad? r) 'bad
                       (flo? ty) (one >ps env3 (acc + asflo g r + fstf g ty 'r4 off 'f0))
                       (pair? g ty) (one >ps env3 (acc + asll g r + pst 'r4 off))
                       (d128? ty)
                        (? !(w128? g) (no128 g)
                           (two? hreg)              ; a pair home's init is two register moves
                            (one >ps env3 (acc + as128 g r + [['mov <hreg 'r0] ['mov <>hreg 'r2]]))
                           (one >ps env3 (acc + as128 g r + [['st 'r4 off 'r0] ['st 'r4 (off + 8) 'r2]])))
                       hreg                        ; a homed local's init delivers to the home (a narrow home lands canonical)
                        (? (flo? (vty r))
                           (one >ps env3 (acc + asintt g r ty + ([['mov hreg 'r0]] + cvt ty hreg)))
                           (rpeq? g (vreg r) hreg) ; the destination held: no bridge
                           (one >ps env3 (acc + vfs r + cvt ty hreg))
                           (: fs (vfs r + ([['mov hreg (vreg r)]] + cvt ty hreg))
                              _ (rfree g (vreg r))
                              (one >ps env3 (acc + fs))))
                       (one >ps env3
                            (acc + asintt g r ty +
                             cvt ty 'r0 +
                             [[(stop ty) 'r4 off 'r0]])))))))))
       _ (stq g)                                     ; one statement tick for the whole decl
       (one pairs env ()))

   ; block-scope static ((name ty init)..): a unique global per name, bound in the env as (glob
   ; lbl), which vent turns into a 'glo; no runtime init. -> (forms env) | 'bad
   (cgsdecl g env pairs)
    (: (one ps env2)
        (? !(two? ps) [() env2]
           (: p <ps
              name <p ty <>p init <>>p
              lbl (nlab g (g 'fn + "."))             ; `fn.N` -- the `.` bars any C-identifier collision
              _ (pin (g 'glob) lbl [lbl ty init])   ; a local data label (internal linkage): g 'statics,
              _ (pin g 'statics (lbl . g 'statics))      ; not g 'globs -- a static is never an exported symbol
              (one >ps ([name ['glob lbl] ty] . env2))))
       _ (stq g)                                     ; the statement tick (alive numbers sdecls too)
       (one pairs env))

   ; stmt -> forms | 'bad

   ; inline asm: the target's GNU dialect (love/holo/gas.l; holo's neutral text under __attribute__((holo))), spliced as one opaque ('raw ..)
   ; a constraint's register part: r/q/g/rm 'pick, i/n 'imm, m 'mem, a digit ('tie n), rN the nom,
   ; x86's a b c d S D letters by name (rax rbx rcx rdx rsi rdi, Nd dx), ir 'either
   (asmc g c9)
    (: n #c9
       c0 (? (n > 0) (c9 0) 0)
       x86 (x64t? g)
       (? (n < 1) 'bad
          (n = 1 && 48 <= c0 <= 57) ['tie (c0 - 48)]
          (n = 1) (c0 @ 114 'pick 113 'pick 103 'pick 105 'imm 110 'imm 109 'mem
                      97 (x86 ? 'r0 'bad) 98 (x86 ? 'r3 'bad) 99 (x86 ? 'r1 'bad)
                      100 (x86 ? 'r2 'bad) 83 (x86 ? 'r5 'bad) 68 (x86 ? 'r6 'bad) 'bad)
          ((c9 = "rm") || (c9 = "mr")) 'pick
          ((c9 = "Nd") || (c9 = "dN")) (x86 ? 'r2 'bad)
          ((c9 = "ir") || (c9 = "ri") || (c9 = "in") || (c9 = "ni")) 'either
          (name c9)))
   ; a `register T v asm("reg")` variable named as an operand: its pin, else ()
   (asmvpin g env e)
    (e @ ('var nm) (: en (assoc nm env) (? (two? en && two? >>>en) <>>>en ()))
         ())
   ; %-substitute the template: al the operand printers (a modifier letter, 0 for none -> text | 'bad)
   (asmsub tm al)
    (: n #tm
       (go i acc)
        (? (n <= i) acc
           (: c (tm i)
              (? !(c = 37) (go (i + 1) (acc + string c))
                 (i + 1 < n)
                  (: d (tm (i + 1))
                     md (? (elem d '(98 119 107 113 99 120) && i + 2 < n && 48 <= (tm (i + 2)) <= 57) d 0)
                     dx (? md (tm (i + 2)) d)
                     (? (d = 37) (go (i + 2) (acc + "%"))
                        (48 <= dx <= 57)
                         (: ix (dx - 48)
                            (? (ix < #al)
                               (: sub ((al ix) md) (? (bad? sub) 'bad (go (i + (? md 3 2)) (acc + sub))))
                               'bad))
                        'bad))
                 'bad)))
       (go 0 ""))
   ; an operand's byte width, off its type by static peek (a register spells by it on x64)
   (asmw g env e) (: ty (peekty g env e)
                     (? (bad? ty) 8 (: n (tsz g ty) (? (elem n '(1 2 4 8)) n 8))))
   asmhb holo-bytes                                 ; bare: the cat leads with (borrow 'holo) (asbook.l), so this folds at compile
   (cgasm g env s)
    (: _ (pin g 'hasasm 1)
       tmpl <>s
       tgt (gtgt g)
       neutral? (two? >>>>>s)                       ; the holo attribute: the template is neutral text
       ; one operand list, GNU order: ('o|'x reg expr w) an output (x in-out), ('i reg expr w) a
       ; register input, ('b reg (addr expr) 0) a memory input, ('m imm 0 0) an immediate
       (pinof k e) (? (= k 'pick) (: p (asmvpin g env e) (? (nom? p) p k)) k)
       (oconv l acc)
        (? !(two? l) (rev acc)
           (: c <<l n #c
              h (0 < n ? (c 0) 0)
              c2 (? (1 < n && c 1 = 38) (snip c 2 n) (snip c 1 n))    ; "=&r": the early clobber is the picking rule already
              k (h @ (61 || 43) (asmc g c2) 'bad)
              (? (bad? k || elem k '(imm mem either) || two? k) 'bad
                 (oconv >l ([(h @ 43 'x 'o) (pinof k <><l) <><l (asmw g env <><l)] . acc)))))
       (iconv l acc)
        (? !(two? l) (rev acc)
           (: k (asmc g <<l) e <><l
              const? (two? e && (= <e 'num) && charm? <>e)
              (k @ 'bad 'bad
                   'imm (const? ? (iconv >l (['m <>e 0 0] . acc)) 'bad)
                   'either (? const? (iconv >l (['m <>e 0 0] . acc)) (iconv >l (['i (pinof 'pick e) e (asmw g env e)] . acc)))
                   'mem (iconv >l (['b 'pick ['addr e] 0] . acc))
                   (iconv >l (['i (pinof k e) e (asmw g env e)] . acc)))))
       os (oconv <>>s ())
       is9 (iconv <>>>s ())
       (? (bad? os || bad? is9) 'bad
          (: ops9 (os + is9)
             ; pinned registers: validated, a duplicate refuses; a tie takes its output's
             (pinset l acc)
              (? !(two? l) acc
                 (: e2 <l k <>e2
                    (? (= <e2 'm || (= k 'pick) || two? k) (pinset >l acc)
                       !(asmreg? g k) 'bad
                       (elem k acc) 'bad
                       (pinset >l (k . acc)))))
             pinned (pinset ops9 ())
             (? (bad? pinned) 'bad
                (: (assign l fr acc)
                    (? !(two? l) (rev acc)
                       (: e2 <l k <>e2
                          (? (= <e2 'm) (assign >l fr (k . acc))
                             (two? k) (? (<>k < #acc) (: r9 ((rev acc) <>k) (assign >l fr (r9 . acc))) 'bad)
                             (= k 'pick)
                              (? (two? fr) (assign >l >fr (<fr . acc)) 'bad)
                             (assign >l fr (k . acc)))))
                   asgn (assign ops9 (filter (\ r9 !(elem r9 pinned)) asmpick) ())
                   (clobs l acc)
                    (? !(two? l) (rev acc)
                       (: c <l
                          (? ((c = "memory") || (c = "cc")) (clobs >l acc)
                             (: r9 (? neutral? (intern c) (gas-regname tgt c))
                                (? !(nom? r9) 'bad
                                   (asmreg? g r9) (clobs >l acc)
                                   (asmsave? g r9) (clobs >l (r9 . acc))
                                   'bad)))))
                   saves (clobs <>>>>s ())
                   (? (bad? asgn || bad? saves) 'bad
                      (: ; the operand printers, one per kind (neutral: a plain register name, "m" as `rN, 0`)
                         (rtext a9 w) (\ md (? neutral? (md ? 'bad (peep asmnames a9 "r?")) (gas-reg tgt a9 w md)))
                         (itext v) (\ md (? neutral? (md ? 'bad (show v)) (gas-imm tgt v md)))
                         (mtext a9) (\ md (? md 'bad neutral? ((peep asmnames a9 "r?") + ", 0") (gas-mem tgt a9)))
                         (optext l al acc)
                          (? !(two? l) (rev acc)
                             (: e2 <l a9 <al
                                (optext >l >al ((? (= <e2 'm) (itext a9)
                                                   (= <e2 'b) (mtext a9)
                                                   (rtext a9 <>>>e2)) . acc))))
                         txt (asmsub tmpl (optext ops9 asgn ()))
                         (? (bad? txt) 'bad
                            (: ; inputs (and in-out outputs) evaluate and push..
                               (loads l acc)
                                (? !(two? l) acc
                                   (: e2 <l
                                      (? (elem <e2 '(x i b))
                                          (: r (cgexpr g env <>>e2 ())
                                             (? (bad? r) 'bad
                                                (flo? (vty r) || stru? (vty r)) 'bad
                                                (loads >l (acc + tor0 g r + spush 'r0))))
                                         (loads >l acc))))
                               lf (loads ops9 ())
                               (? (bad? lf) 'bad
                                  (: ; ..then pop into their registers, reverse order
                                     (pops l al acc)
                                      (? !(two? l) acc
                                         (? (elem <<l '(x i b))
                                            (pops >l >al (spop <al + acc))
                                            (pops >l >al acc)))
                                     ; the body: one opaque raw, the saved clobbers pushed around it
                                     body ((map (\ r9 ['push r9]) saves)
                                           + [['raw (asmhb tgt (? neutral? (asm-text txt) (gas-text tgt txt)))]]
                                           + map (\ r9 ['pop r9]) (rev saves))
                                     ; outputs: push each register, store back reverse
                                     (opush l al acc)
                                      (? !(two? l) acc
                                         (? (elem <<l '(o x))
                                            (opush >l >al (acc + spush <al))
                                            (opush >l >al acc)))
                                     (ostores l al acc)
                                      (? !(two? l) acc
                                         (: e2 <l
                                            (? !(elem <e2 '(o x)) (ostores >l >al acc)
                                               (: lv (matv g (clval g env <>>e2))
                                                  (? (bad? lv) 'bad
                                                     (: ty (vty lv)
                                                        (? (flo? ty || stru? ty || arr? ty || bitf? ty) 'bad
                                                           (ostores >l >al
                                                            ((vfs lv + spop 'r1 + [[(stop ty) 'r0 0 'r1]]) + acc)))))))))
                                     osf (ostores ops9 asgn ())
                                     (? (bad? osf) 'bad
                                        (lf + pops ops9 asgn () + body + opush ops9 asgn () + osf)))))))))))))

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

   ; -- alive: the one build's liveness -- which homable names live across each call, one backward
   ; statement-grain walk ticking as the build's cgstmt/cgdecl/cgsdecl entries do (stq). the universe
   ; is homable params + locals minus &-taken or multiply-declared names (respell spells autos apart;
   ; a static local can still share one, and a conflated name keeps the blanket wrap). loops seed
   ; with everything they read, no fixpoint; a goto reads the whole universe. the crossing counts
   ; are only meaningful for univ names -- a gate must not read them for an outsider. --
   (alive g f)
    (: params <>>f
       items <><>>>f
       dcl {} tak {} n9 {} liv {} crs {} spa {}
       crh {} rdc {} rdt {} sqm {}
       ; a hard call: one no splice can erase. economics only -- a wrapped home survives any emitted call
       (nhcl l) (? !(two? l) 0 (+ (nhc <l) (nhcl >l)))
       (soft? nm) (two? (g 'inl nm))                 ; an inline candidate; the armed shadow covers a declined splice
       ; a soft site costs the spliced body's own hard calls -- nhcl, not nhcr: a splice's returns
       ; become jumps, so nothing tails. memoized, a cycle floors at 0
       nhmo {}
       (nhin nm) (: c9 (peep nhmo nm 'no)
                    (? (c9 !== 'no) c9
                       (: _ (pin nhmo nm 0)
                          n2 (pmxl <><>>>(g 'inl nm) 1 ())
                          _ (pin nhmo nm n2)
                          n2)))
       ; the fn-level hard count is a path maximum: an if takes its heavier arm, loop weight multiplies,
       ; a goto answers a bar. tc9: ret-tails carve only at fn grain -- inside a splice body a ret call counts whole
       (pmxl l w tc9) (? !(two? l) 0 (+ (pmx <l w tc9) (pmxl >l w tc9)))
       (pmx s w tc9)
        (? !(two? s) 0
           (s @ ('blk items2) (pmxl items2 w tc9)
                ('expr e9) (* (nhc e9) w)
                ('ret . rs) (: rv2 (? (two? rs) <rs ())
                               (* (? tc9 (nhcr rv2 (1 < #rs)) (nhc rv2)) w))
                ('decl ps) (* (: (hs l) (? !(two? l) 0 (+ (nhc <>><l) (hs >l))) (hs ps)) w)
                ('sdecl . _) 0
                ('if . cnd . thn . er)
                 (: a2 (pmx thn w tc9) b2 (? (two? <er) (pmx <er w tc9) 0)
                    ((* (nhc cnd) w) + (? (a2 < b2) b2 a2)))
                ('while cnd body) (: w8 (8 * w) ((* (nhc cnd) w8) + pmx body w8 tc9))
                ('do body cnd) (: w8 (8 * w) ((* (nhc cnd) w8) + pmx body w8 tc9))
                ('for ini cnd stp body)
                 (: w8 (8 * w)
                    ((? (two? ini && elem <ini '(decl sdecl)) (pmx ini w tc9)
                        (two? ini) (nhc <>ini * w)) +
                     (two? cnd && nhc cnd * w8) +
                     (two? stp && nhc stp * w8) +
                     pmx body w8 tc9))
                ('switch ce items2) ((* (nhc ce) w) + pmxl items2 w tc9)   ; fallthrough: arms sum (conservative)
                (('case || 'dflt) . _) 0
                ('goto . _) 99
                ('asm . _) 99
                0))
       (nhc e) (? !(two? e) 0
                  (e @ ('call ('var nm) as) ((? (soft? nm) (nhin nm) 1) + nhcl as)
                       ('call fh as) (1 + (nhc fh) + nhcl as)
                       ('szof . _) 0
                       (nhcl e)))
       ; a ret-tail call hardens nothing (sibcall jumps it, and a home is dead at its own return) --
       ; but a soft tail splices and its body's hard calls land in this frame; a musttail never splices (mt9)
       (nhcr e mt9)
        (? !(two? e) 0
           (e @ ('call ('var nm) as && soft? nm) ((? mt9 0 (nhin nm)) + nhcl as)
                ('call fh as) ((nhc fh) + nhcl as)
                ('comma a b) ((nhc a) + nhcr b mt9)
                ('cond c a b) ((nhc c) + nhcr a mt9 + nhcr b mt9)
                ((k _ x) && elem k '(un cast)) (nhcr x mt9)
                (nhc e)))
       ; protocol dirt, anything that writes r0-r3: a call's staging, div/mod (r0:r2), a variable
       ; shift (r1), a d128 cast (r0:r2). a fn with none may ride a quad arrival
       (pdt e) (e @ ('szof . _) 0
                    ('call . _) 1
                    ('asm . _) 1
                    ('bin op a b && elem op '(/ %)) (1 + pdt a + pdt b)
                    ('bin op a b && elem op '(shl shr) &&
                     (atom? b || <b !== 'num)) (1 + pdt a + pdt b)
                    ('cast ty x) ((? (d128? ty) 1 0) + pdt x)
                    (_ . _) (pdtl e))
       (pdtl l) (two? l ?
                   ((two? <l ? (pdt <l) 0) + pdtl >l))
       ; the touch counters: every mention, read or write, raw and loop-weighted
       (bump9 nm w) (: _ (pin rdc nm (1 + peep rdc nm 0))
                       _ (pin rdt nm (w + peep rdt nm 0))
                       0)
       (rdn e w)
        (? !(two? e) 0
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
       (pex e) (? !(two? e) ()
                  (: _ (e @ ('addr ('var nm)) (pin tak nm 1) ())
                     ; the head too: an init list's first element sits in head position
                     _ (? (two? <e) (pex <e) ())
                     (pexl >e)))
       (pexl l) (? !(two? l) () (: _ (pex <l) (pexl >l)))
       ; -- prepass: the tick total (mirrors lst's, statement for statement), decl counts, homable
       ; locals. s stays whole: a [k l] head would refuse an if or a for and silently drop its ticks --
       (pre s)
        (two? s &&
         (: k <s
          (pin n9 'n (1 + peep n9 'n 0),
           k = 'asm && pin n9 'asm 1,
        (?- (prel (stkids s))
         (elem k '(decl sdecl)) (: (go (p . u))
          (pin dcl <p (1 + peep dcl <p 0),
           k = 'decl && lhomable? <>p && pin n9 'loc (<p . n9 'loc),
           k = 'decl && gvarr? <>p && pin n9 'vla 1,
           ; predicts cgdecl's dseq: it ticks for exactly these, in this order
           k = 'decl && !(gvarr? <>p) &&
            (lhomable? <>p || d128? <>p && w128? g) &&
            (1 + peep n9 'sq 0 @ q2 (pin n9 'sq q2,
                                     pin sqm q2 [<p <>p])),
           go u)
          (go <>s))))))
       (prel l) (? !(two? l) () (: _ (pre <l) (prel >l)))
       (pdcl ps) (? !(two? ps) ()
                    (: _ (pin dcl <<ps (1 + peep dcl <<ps 0))
                       (pdcl >ps)))
       ; -- the universe: the homable gp walk for the param names, plus the locals --
       (pgo ps gpi acc) (homefold g ps gpi acc
                          (\ a2 i9 p9 (? (lhomable? <>p9)
                                         (<p9 . a2) a2)))
       _ (pdcl params)
       _ (prel items)
       _ (pexl items)
       pgs (pgo params 0 ())
       univ (filter (nm \ dcl nm = 1 && !(tak nm)) (pgs + n9 'loc))
       ; a homable param outside the universe still homes, so it must ride every wrapset
       pales (filter (\ nm !(elem nm univ)) pgs)
       ; -- the set kit (names are strings; elem compares content) --
       (sadd s2 nm) (? (elem nm s2) s2 (nm . s2))
       (sun s2 b) (? !(two? b) s2 (sun (sadd s2 <b) >b))
       (sdel (a . u) nm) (a = nm ? u (a . sdel u nm))
       (tick u) (: q (peep n9 'q 0) _ (pin n9 'q (q - 1)) q)
       ; a per-name [lo hi] tick span, a superset of the live range -- so the control-only lanes
       ; (goto, break) record too
       (spn sq l)
        (? !(two? l) ()
           (: nm <l o (peep spa nm ())
              _ (pin spa nm (? !(two? o) [sq sq]
                                (: a <o b <>o [(? (sq < a) sq a) (? (b < sq) sq b)])))
              (spn sq >l)))
       ; w the wrapset (soundness), wc the names charged a crossing ncc times (economics),
       ; nclw the in-loop share of ncl (0 at depth 0), nclh the hard calls
       (recx sq w wc ncl ncc nclw nclh)             ; a call-bearing statement's record
        (: _ (spn sq w)
         (? (ncl < 1) ()
           (: _ (pin liv sq (sun w pales))          ; the outside-universe homes ride every wrap
              _ (pin n9 'ncw (nclw + peep n9 'ncw 0))
              _ (? (0 < nclh) (pin n9 'nhc (nclh + peep n9 'nhc 0)) ())
              (bump (a . u)) (pin crs a (ncc + peep crs a 0),
                               (? (0 < nclh) (pin crh a (nclh + peep crh a 0)) 0),
                               bump u)
            (? (0 < ncc || 0 < nclh) (bump wc) 0))))
       (rec sq w ncl nclw nclh) (recx sq w w ncl ncl nclw nclh)
       ; -- an expression's universe reads -> (set ncalls): a var write is no read, sizeof never
       ; evaluates, an unknown head reads everything and counts a call --
       (erd e s2 nc)
        (? !(two? e) [s2 nc]
           (e @ ('var nm) [(? (elem nm univ) (sadd s2 nm) s2) nc]
                ((k . _) && elem k '(num flo str szof)) [s2 nc]
                ((k . x . _) && elem k '(dot deref addr post vastart vaend vaarg)) (erd x s2 nc)
                ((k _ x) && elem k '(un cast)) (erd x s2 nc)
                ('asn dst rhs) (: r (erd rhs s2 nc)
                                  (? (<dst = 'var) r (erd dst <r <>r)))
                ('bin _ a b) (: r (erd a s2 nc) (erd b <r <>r))
                ((k a b) && elem k '(land lor comma)) (: r (erd a s2 nc) (erd b <r <>r))
                ('cond c a b) (: r (erd c s2 nc) r2 (erd a <r <>r) (erd b <r2 <>r2))
                ('call fh as) (: r (erd fh s2 (nc + 1)) (erdl as <r <>r))
                ('clit _ ini) (erdi ini s2 nc)
                ('init items) (erdi items s2 nc)
                [(sun s2 univ) (nc + 1)]))
       (erdl l s2 nc) (? !(two? l) [s2 nc] (: r (erd <l s2 nc) (erdl >l <r <>r)))
       ; a return value's reads, the tail call itself uncounted (nhcr's soft twin)
       (erdr e s2 nc)
        (? !(two? e) [s2 nc]
           (e @ ('call fh as) (: r (erd fh s2 nc) (erdl as <r <>r))
                ('comma a b) (: r (erd a s2 nc) (erdr b <r <>r))
                ('cond c a b) (: r (erd c s2 nc) r2 (erdr a <r <>r) (erdr b <r2 <>r2))
                ((k _ x) && elem k '(un cast)) (erdr x s2 nc)
                (erd e s2 nc)))
       (erdi l s2 nc)                               ; init items: dfield/didx wrap their values
        (? (atom? l) [s2 nc]
           (: it <l
              v (? (two? it && elem <it '(dfield didx)) <>>it it)
              r (erd v s2 nc)
              (erdi >l <r <>r)))
       ; -- a loop's uses (the back-edge seed): every name read, kills ignored; a goto inside reads the universe --
       (ust s acc)
        (s @ ('blk items) (ustl items acc)
             ('expr e9) <(erd e9 acc 0)
             ('ret . rv . _) (? (two? rv) <(erd rv acc 0) acc)
             (('decl || 'sdecl) ps) (ustp ps acc)
             ('if cnd thn els) (: a1 <(erd cnd acc 0) a2 (ust thn a1) (ust els a2))
             ('if cnd thn) (: a1 <(erd cnd acc 0) (ust thn a1))
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
             (('goto || 'asm) . _) (sun acc univ)
             acc)
       (ustl l acc) (? !(two? l) acc (ustl >l (ust <l acc)))
       (ustp ps acc) (? !(two? ps) acc (ustp >ps <(erd <>><ps acc 0)))
       ; -- the backward walk, children before their parent's tick (counting down = forward pre-order).
       ; w9 is the loop weight, x8 per level; wrapsets never depend on it --
       (litems l out brk cnt w9)
        (: (go l2 o) (? !(two? l2) o (go >l2 (lst <l2 o brk cnt w9)))
           (go (rev l) out))
       (dpairs ps o nc)                             ; reversed decl pairs -> (in ncalls)
        (? (atom? ps) [o nc]
           (: p <ps
              r (erd <>>p () 0)
              o2 (sun (? (elem <p univ) (sdel o <p) o) <r)
              (dpairs >ps o2 (nc + <>r))))
       (lst s out brk cnt w9)
        (? (atom? s) out
           (s @
              ('blk items) (: in (litems items out brk cnt w9) sq (tick ()) _ (spn sq in) in)
              ('expr e9)
               (: kv (e9 @ (('asn . ('var v) . _) && elem v univ) v ())
                  r (erd e9 () 0)
                  in (sun (? kv (sdel out kv) out) <r)
                  ; the kill rides the record too: a name born here lives across the statement's own calls
                  sq (tick ()) _ (recx sq (sun (sun in out) (? kv [kv] ()))
                                       (? (kv && <>r = 1) (sun in (sdel out kv)) (sun (sun in out) (? kv [kv] ())))
                                       (* <>r w9) (* <>r w9)
                                       (? (1 < w9) (* <>r w9) 0) (* (nhc e9) w9))
                  in)
              ('ret . rs)
               (: rv (? (two? rs) <rs ())
                  mt9 (1 < tally rs)                 ; clay's (ret e PRE): presence is the arity
                  r (? (two? rv) (erd rv () 0) '(() 0))
                  _ (pin n9 'nx (1 + peep n9 'nx 0))
                  nct (? (two? rv) <>(erdr rv () 0) 0)    ; the crossings charged: the tail call is none
                  sq (tick ()) _ (recx sq <r <r (* <>r w9) (* nct w9) (? (1 < w9) (* <>r w9) 0)
                                       (* (nhcr rv mt9) w9))
                  <r)
              ('decl ps)
               (: pr (dpairs (rev ps) out 0)
                  ks (: (go p9) (? !(two? p9) ()      ; the declared names: kills, in the record (see expr)
                                   (: nm <<p9
                                      (? (elem nm univ) (nm . go >p9) (go >p9))))
                        (go ps))
                  sq (tick ()) _ (recx sq (sun (sun <pr out) ks)
                                       (? (<>pr = 1) (sun <pr (foldl sdel out ks)) (sun (sun <pr out) ks))
                                       (* <>pr w9) (* <>pr w9)
                                       (? (1 < w9) (* <>pr w9) 0)
                                      (* (: (hs l) (? !(two? l) 0 (+ (nhc <>><l) (hs >l))) (hs ps)) w9))
                  <pr)
              ('sdecl . _) (: sq (tick ()) _ (spn sq out) out)   ; statics: no runtime init, no kill
              ('if . cnd . thn . er)
               (: els <er
                  inE (? (two? els) (lst els out brk cnt w9) out)   ; else first (reverse order)
                  inT (lst thn out brk cnt w9)
                  r (erd cnd () 0)
                  in (sun (sun inT inE) <r)
                  sq (tick ()) _ (rec sq (sun in out) (<>r * w9) (? (1 < w9) (<>r * w9) 0)
                                      ((nhc cnd) * w9))
                  in)
              ('while cnd body)
               (: w8 (8 * w9)
                  seed (sun out (ust body <(erd cnd () 0)))
                  _ (lst body seed out seed w8)
                  r (erd cnd () 0)
                  sq (tick ()) _ (rec sq seed (<>r * w8) (<>r * w8) ((nhc cnd) * w8))
                  seed)
              ('do body cnd)
               (: w8 (8 * w9)
                  seed (sun out (ust body <(erd cnd () 0)))
                  r (erd cnd () 0)
                  _ (lst body seed out seed w8)
                  sq (tick ()) _ (rec sq seed (<>r * w8) (<>r * w8) ((nhc cnd) * w8))
                  seed)
              ('for ini cnd stp body)
               (: w8 (8 * w9)
                  useb (: u1 (? (two? cnd) <(erd cnd () 0) ())
                          u2 (? (two? stp) <(erd stp u1 0) u1)
                          (ust body u2))
                  seed (sun out useb)
                  _ (lst body seed out seed w8)
                  nc9 (+ (? (two? cnd) <>(erd cnd () 0) 0)
                         (? (two? stp) <>(erd stp () 0) 0))
                  ri (? (two? ini && !(elem <ini '(decl sdecl)))
                        (erd <>ini () 0) '(() 0))
                  kv8 (? (two? ini && !(elem <ini '(decl sdecl)))
                         (<>ini @ (('asn . ('var v) . _) && elem v univ) v ())
                         ())
                  in (? !(two? ini) seed
                        (elem <ini '(decl sdecl)) (lst ini seed () () w9)   ; ticks (cgdecl does); kill applies; runs once
                        (sun (? kv8 (sdel seed kv8) seed) <ri))
                  ; kv8 joins the record: the init's kill (see the expr lane)
                  sq (tick ()) _ (rec sq (sun (sun seed <ri) (? kv8 [kv8] ())) (nc9 * w8 + <>ri * w9)
                                      (nc9 * w8 + (? (1 < w9) (<>ri * w9) 0))
                                      (((? (two? cnd) (nhc cnd) 0) + (? (two? stp) (nhc stp) 0)) * w8 +
                                       (? (two? ini && !(elem <ini '(decl sdecl))) (nhc <>ini) 0) * w9))
                  in)
              ('switch ce items)
               (: r (erd ce () 0)
                  _ (pin n9 'sw (() . peep n9 'sw ()))       ; push this switch's marker set
                  _ (litems items out out cnt w9)            ; brk = out; cont targets the outer loop
                  macc <(peep n9 'sw ())
                  _ (pin n9 'sw >(peep n9 'sw ()))            ; pop
                  in (sun (sun <r macc) out)
                  sq (tick ()) _ (rec sq in (<>r * w9) (? (1 < w9) (<>r * w9) 0)
                                      ((nhc ce) * w9))
                  in)
              (('case || 'dflt) . _)
               (: sw (peep n9 'sw ())
                  _ (? (two? sw) (pin n9 'sw (sun <sw out . >sw)) ())
                  sq (tick ()) _ (spn sq out) out)
              ('brk . _) (: sq (tick ()) _ (spn sq brk) brk)
              ('cont . _) (: sq (tick ()) _ (spn sq cnt) cnt)
              ('goto . _) (: sq (tick ()) _ (spn sq univ) univ)   ; any target: everything
              ('lbl . _) (: sq (tick ()) _ (spn sq out) out)
              ('asm . _) (: sq (tick ()) _ (rec sq univ w9 (? (1 < w9) w9 0) w9) univ)   ; homing is off anyway (hasasm)
              (: sq (tick ()) _ (spn sq out) out)))   ; nop tdef
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
                       (: e2 (sqm i) (two? e2 && d128? <>e2 || go (i + 1))))
            (go 1)) ||
            (: (go l) (? !(two? l) () (d128? <><l) 1 (go >l)) (go params)) ||
            (wdc items))
       pq9 (0 = pdtl items && !wd9)
       (? (0 = peep n9 'q 0)
          [liv crs univ (peep n9 'n 0) (peep n9 'ncw 0) spa
           crh rdc rdt sqm (peep n9 'nx 0)
           (peep n9 'asm 0) (peep n9 'vla 0) (peep n9 'sq 0) tak
           (pmxl items 1 1) (? pq9 1 ()) (? wd9 1 ())] ()))
   ; alive's forward twin: cgstmt/cgdecl/cgsdecl entries tick and pin the wrapset off livtab
   ; (a miss pins 'all); a splice neither ticks nor re-pins
   (stq g)
    (? (g 'inlining) (peep g 'stwrap 'all)
       (: q (1 + peep g 'lsq 0)
          _ (pin g 'lsq q)
          lt (g 'livtab)
          w (? lt (peep lt q 'all) 'all)
          _ (pin g 'stwrap w)
          w))
   ; the seat channels' neutral state; per-fn entry and the build teardown share it
   (rgreset g)
    (pins g
     'livtab ()  ; liveness (set only for a seat-bearing build)
     'lhome ()   ; locals-homing map (cgdecl's hook reads it)
     'rgon ()    ; ...and its seat-bearing flag (the splice decl gate)
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
    'vrt {})           ; ...and its per-build map, mint -> physical
   ; every per-fn pin and its neutral, one roster: a new per-fn pin registers here (the computed
   ; ones -- fn, epi, pool, vslots, fc, sret -- re-pin at their owner)
   (fnreset g)
    (pins (rgreset g)          ; the seat channels' neutral state -- disjoint pin set
     'off 8                    ; the frame cursor: slot -8 = saved r3 (see epi)
     'slots ()                 ; the frame's object map ((off n)..; nslot appends)
     'fesc ()                  ; escape flag (the sibcall gate reads it)
     'inlining () 'inlbody 0   ; splice depth + body depth (the bind lanes' blind)
     'inlret () 'inlrt ()      ; splice return label + type (cgstmt's ret door)
     'inlrb () 'inlrbs ()      ; splice decl-license + its reg roster
     'rpin ()                  ; splice bind pins
     'hasasm ()                ; an asm statement pins it (homing off)
     'fpin ()                  ; the frame link is asked for by name (unframe stands off)
     'cssv ()                  ; the callee-saved save forms (a cs grant pins)
     'sret ())                 ; the memory-return slot (the driver re-pins under sr6f)

   (cgstmt g env s)
    (: _ (psreset g)                                 ; a statement never carries a live operand in (splice binds do)
       myw (stq g)                                   ; this statement's wrapset (alive's forward twin)
       (s @- 'bad                                                        ; the refusal up front, 180 lines of clauses below
          ('ret . rs)                                                     ; inside an inline splice a return jumps to the
          (: il (g 'inlret)                                      ; splice's end label instead of the epilogue
             epj (peep g 'epi epi)                                       ; the target's epilogue (cgen-core pins it)
             mt (1 < tally rs)                                           ; clay's (ret e PRE): presence is the arity
             rr9
             (? (mt && il) 'bad                     ; a musttail never inlines: the splice declines, the real call still can
                !(two? <rs)
                 (? mt (nolane g "a musttail return carries no call") (? il [['jmp il]] epj))   ; bare `return;` -- just the epilogue
                (: _ (? mt (pin g 'must9 1) 0)      ; the ret's own call stays a call (no splice) -- consumed at first touch
                   r (cgexpr g env <rs 'r0)         ; the return value's one true home
                   _ (pin g 'must9 ())
                   rt (? il (peep g 'inlrt 'long)                        ; the inlined function's return type
                         <(peep (g 'sigs) (g 'fn) ['long ()]))         ; else the current function's
                   res
                   (? (bad? r) 'bad
                      (flo? rt)                                        ; a double return leaves f0 (xmm0; never inline -- gated);
                       (asflo g r                                      ; v6-M base ABI carries a double out on the r0:r1 pair,
                        + (? (t32f? g && (= rt 'float)) '((cvtsd2ss f0 f0))   ; AAPCS-VFP: narrow into s0, d0's own low half
                             !(v6m? g) ()                              ; a bare float as one word (binary32 in r0)
                             (= rt 'float) '((cvtsd2ss f0 f0) (movqrx r0 f0))
                             '((movqrx r0 f0)))
                        + epj)
                      (v6m? g && stru? rt)                 ; v6-M composite returns: >4B fills the caller's temp
                       (? (4 < tsz g rt)                   ; through the saved sret pointer (memory, the base ABI);
                          (tor0 g r                        ; <=4B rides its word in r0
                           + [['ld 'r1 'r4 (peep g 'sret 0)]]
                           + bcopy g 0 (tsz g rt) () + epj)
                          (tor0 g r + '((ld r0 r0 0)) + epj))
                      (t32? g && stru? rt &&               ; t32 returns: the d-pair HFA, the 8B sse blob (d0),
                       !(sse2? g rt ||                     ; and the <=4B int one (r0); mixed/int-pair refuse loud
                         (aone g rt = 'sse && tsz g rt = 8) ||
                         (aone g rt = 'int && tsz g rt <= 4))) 'bad
                      (sse2? g rt)                                       ; a two-double struct returns as the xmm pair
                       (tor0 g r + fldf 'double (xmmreg 0) 'r0 0 +
                        (fldf 'double (xmmreg 1) 'r0 8 + epj))
                      (ipair? g rt)                                      ; a two-int struct returns as rax:rdx (a64 x0:x1)
                       (tor0 g r + [['ld (ip2 g) 'r0 8] '(ld r0 r0 0)] + epj)
                      (aone g rt = 'sse)                             ; a small SSE aggregate: its eightbyte in xmm0
                       (tor0 g r + fldf 'double (xmmreg 0) 'r0 0 + epj)
                      (aone g rt = 'int)                             ; a small int aggregate (a union rides here): rax
                       (tor0 g r + '((ld r0 r0 0)) + epj)
                      (amem? g rt)                                       ; a memory return: fill the caller's temp through
                       (tor0 g r                                         ; the saved hidden pointer, and answer it in rax
                        + [['ld 'r1 'r4 (peep g 'sret 0)]]
                        + bcopy g 0 (tsz g rt) () + '((mov r0 r1)) + epj)
                      (stru? rt || stru? (vty r))                        ; a mixed 16-byte pair, and every composite class
                       (nolane g ("no lane for returning this " + show (tsz g (? (stru? rt) rt (vty r)))     ; a64 has no memory return yet
                                  + "-byte struct by value" + ontgt g))
                      (flo? (vty r)) (asintt g r rt + (? (= rt 'bool) (cvt rt 'r0) ()) + (? il [['jmp il]] epj))     ; a double value, an int return -> truncate to r0
                      (pair? g rt) (asll g r + (? il [['jmp il]] epj))        ; a pair return: r0:r1 (widen a word value)
                      (d128? rt)                                                ; a wide return rides rdx:rax (the SysV i128 pair)
                       (? (w128? g) (as128 g r + (? il [['jmp il]] epj)) (no128 g))
                      (rt = 'bool)                             ; a bool return converts (callers read r0 whole -- cc calls untyped)
                       (tor0 g r + cvt rt 'r0 + (? il [['jmp il]] epj))
                      (tor0 g r + (? il [['jmp il]] epj)))      ; int -> int, as before (a pair value narrows to its lo)
                   (? (!mt || bad? res) res (mustret g res))))
             rr9)         ; a musttail ret marks its call for sibs
          ('expr pe)
           (: rv (? (<pe = 'post && <<>pe = 'var)
                    (vent g env <><>pe) 'bad)
              (? (two? rv && <rv = 'regv)     ; a statement-position x++ on a home: the old value is dead
                  (: ty <>>rv stp (? (ptr? ty) (tsz g <>ty) 1)
                     ([['add <>rv <>rv (* stp <>>pe)]] + cvt ty <>rv))
                 ; a statement-position asn of a constant into a static slot delivers as one store-immediate (x64)
                 (: sv (? (<pe = 'asn && <<>pe = 'var) (vent g env <><>pe) 'bad)
                    sk (? (x64t? g && two? sv && elem <sv '(loc glo) &&
                           (: t9 <>>sv
                              !(stru? t9 || arr? t9 || flo? t9 || pair? g t9 ||
                                d128? t9 || (= t9 'bool))) &&
                           (<<>>pe = 'num) && charm? <><>>pe)
                          (siop9 <>>sv <><>>pe) ())
                    (? sk (atstat sv 'r1 (b \ o \ [[sk b o <><>>pe]]))
                       (: r (cgexpr g env pe ())
                          (? (bad? r) 'bad (vdrop g r)))))))
          ('nop . _) ()
          ('tdef . _) ()                            ; a block-scope _Static_assert (already checked at parse)
          ('blk items) (cgitems g env items ())
          ('if . cnd . thn . er)
           (: le (nlab g ".e")
              c (cbranch g env cnd 'eq le)
              t (cgstmt g env thn)
              (? (bad? c || bad? t) 'bad
                 !(two? <er)
                  (c + t + [['label le]])
                 (: el (cgstmt g env <er)
                    ld (nlab g ".d")
                    (? (bad? el) 'bad
                     (c + t + [['jmp ld] ['label le]] + (el + [['label ld]]))))))
          ('while cnd body)
           (: lc (nlab g ".c") ld (nlab g ".d")
              c (cbranch g env cnd 'eq ld)
              _ (pins g 'brk (ld . g 'brk)
                        'cnt (lc . g 'cnt))
              b (cgstmt g env body)
              _ (pins g 'brk >(g 'brk)
                        'cnt >(g 'cnt))
              (? (bad? c || bad? b) 'bad
               ([['label lc]] + c + (b + [['jmp lc] ['label ld]]))))
          ('for init cnd stp body)
           (: lc (nlab g ".c") ls (nlab g ".s") ld (nlab g ".d")
              ir (? !(two? init) [() env]
                    (<init = 'decl) (cgdecl g env <>init)
                    (<init = 'sdecl) (cgsdecl g env <>init)
                    (: r (cgexpr g env <>init ())
                       (? (bad? r) 'bad [(vdrop g r) env])))
              (? (bad? ir) 'bad
                 (: env2 <>ir
                    _ (pin g 'stwrap myw)            ; a decl init re-pinned; the cond is ours
                    c (two? cnd ? (cbranch g env2 cnd 'eq ld))
                    _ (pins g 'brk (ld . g 'brk)
                              'cnt (ls . g 'cnt))
                    b (cgstmt g env2 body)
                    _ (pins g 'brk >(g 'brk)
                              'cnt >(g 'cnt)
                              'stwrap myw)           ; the body re-pinned as it went; the step is ours
                    st2 (two? stp ? (cgexpr g env2 stp ()))
                    (? (bad? c || bad? b || bad? st2) 'bad
                       (<ir + [['label lc]] + (two? cnd ? c) +
                        b + [['label ls]] + (two? st2 ? (vdrop g st2)) +
                        [['jmp lc] ['label ld]])))))
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
                        'stwrap myw)                 ; the body re-pinned as it went; the cond is ours
              c (cbranch g env cnd 'ne lt)
              (? (bad? b || bad? c) 'bad
                 ([['label lt]] +
                  b +
                  [['label lc]] +
                  (c + [['label ld]]))))
          ('goto nm) [['jmp (name (g 'fn + "." + nm))]]
          ('lbl nm) [['label (name (g 'fn + "." + nm))]]
          ('asm . _) (cgasm g env s)
          ; a case/default label emits from the tablet atop g 'cases (the switch's pre-scan pinned
          ; value->label); no enclosing switch, or an unscanned value, refuses
          ('case cv)
           (? !(two? (g 'cases)) 'bad
              (: lab (peep <(g 'cases) cv 'no)
                 (lab @ 'no 'bad [['label lab]])))
          ('dflt . _)
           (? !(two? (g 'cases)) 'bad
              (: lab (peep <(g 'cases) 'dflt 'no)
                 (? (lab = 'no) 'bad [['label lab]])))
          ('switch ce items)
           (: c (cgexpr g env ce ())
              (? (bad? c) 'bad
                 (: cr9 (vreg c)
                    lend (nlab g ".d")
                    tab {}                ; this switch's value->label map (and 'dflt->label)
                    cases (rev (scasel-l g items tab ()))   ; pre-scan the body at any depth -> (value label) dispatch pairs
                    dflt (peep tab 'dflt lend)
                    chain (: (go l acc)
                             (? !(two? l) acc
                                (: e2 <l  v (cfit g (vty c) <e2)  lab <>e2
                                   ins (? (immok g 'cmp v)
                                          [['cmp cr9 v] ['br 'eq lab]]
                                          [['li 'r1 v] ['cmp cr9 'r1] ['br 'eq lab]])
                                   (go >l (acc + ins))))
                            (go cases ()))
                    jt (jtable g c cr9 cases dflt)
                    disp (? (= jt 'no) chain jt)
                    _ (rfree g cr9)
                    _ (pins g 'brk (lend . g 'brk)
                              'brkm (() . peep g 'brkm ())   ; lock-step (a switch break's snap is discarded)
                              'cases (tab . g 'cases)) ; push -- cgstmt emits each case/dflt label from here
                    body (cgitems g env items ())       ; decls thread env; case/dflt labels emit via g 'cases
                    _ (pins g 'brk >(g 'brk)
                              'brkm >(peep g 'brkm ())
                              'cases >(g 'cases))      ; pop
                    (? (bad? body) 'bad
                       (vfs c + disp + [['jmp dflt]] + (body + [['label lend]]))))))))
   (cgitems g env items acc)
    (? !(two? items) acc
       (: it <items
          (it @ ('decl ps)
                 (: r (cgdecl g env ps)
                    (? (bad? r) 'bad
                       (cgitems g <>r >items (acc + <r))))
                ('sdecl ps)
                 (: r (cgsdecl g env ps)
                    (? (bad? r) 'bad
                       (cgitems g <>r >items (acc + <r))))
                (: r (cgstmt g env it)
                   (? (bad? r) 'bad
                      (cgitems g env >items (acc + r)))))))

   ; -- the switch's table lane -> forms | 'no (the caller keeps its chain). index = control - lo, so one
   ; unsigned compare bounds it. entries are rel32 label differences, settled at link and never written
   ; again (so the table rides .rodata; -pie slides an abs64): leax lands on the cell's end, ld4 reads
   ; back -4, the sum is the target. jmpt names its targets so the labels survive deadlab. --
   (jtable g c cr9 cases dflt)
    (: vs (sort (map (\ e2 (cfit g (vty c) <e2)) cases))
       n9 #cases
       lo (? (two? vs) <vs 0)
       hi (? (two? vs) (vs (n9 - 1)) 0)
       span (hi - lo + 1)
       (? ((wasm? g) || (t32? g)) 'no               ; no memory table on wasm; t32's REL lane is unproven here
          (abl? g 'jtab) 'no
          (n9 < 6) 'no                              ; fewer cases than a table is worth
          (4096 < span) 'no                         ; ..and a span no table should cover
          ((3 * n9) < span) 'no                     ; too sparse: a third full is the floor
          !(immok g 'cmp (span - 1)) 'no
          (!(lo = 0) && !(imma g 'sub lo)) 'no
          (: tv (foldl (\ t e2 (pin t (cfit g (vty c) <e2) <>e2)) {} cases)
             (ent i acc) (? (span <= i) (rev acc)
                            (ent (i + 1) ([['fix 4 'rel32 (peep tv (lo + i) dflt) 0]] . acc)))
             labs (foldl (\ l e2 (elem <>e2 l ? l (<>e2 . l))) [dflt] cases)
             tl (nlab g ".J")
             rI (? (wr? g cr9) cr9 (ralloc g))
             (? !rI 'no
                (: rT (ralloc g)
                   (? !rT (: _ (rpeq? g rI cr9 ? () (rfree g rI)) 'no)
                      (: _ (pin g 'jtabs ([tl (catall (ent 0 ()))] . g 'jtabs))
                         _ (rfree g rT)
                         _ (rpeq? g rI cr9 ? () (rfree g rI))
                         ((? (lo = 0) (rpeq? g rI cr9 ? () [['mov rI cr9]])
                             [['sub rI cr9 lo]]) +
                          [['cmp rI (span - 1)] ['br 'above dflt] ['la rT tl]
                           ['leax rT rT rI 4 4] ['ld4 rI rT -4] ['add rT rT rI]
                           ['jmpt rT tl labs]]))))))))
   ; cgitems' twin for a statement expression's leading statements -> (forms env) | 'bad. reached
   ; through the g tablet, as cgitems is: a direct cgexpr edge would close the cycle into cgstmt
   (sxpre g env items acc)
    (? !(two? items) [acc env]
       (: it <items
          (it @ ('decl ps)
                 (: r (cgdecl g env ps)
                    (? (bad? r) 'bad (sxpre g <>r >items (acc + <r))))
                ('sdecl ps)
                 (: r (cgsdecl g env ps)
                    (? (bad? r) 'bad (sxpre g <>r >items (acc + <r))))
                (: r (cgstmt g env it)
                   (? (bad? r) 'bad (sxpre g env >items (acc + r)))))))

   ; a switch body's case/default labels at any depth: value->label pinned into tab -> (value label) dispatch pairs
   (scasel g it tab acc)
    (? !(two? it) acc
       (it @ ('case cv)     (: lab (nlab g ".k") _ (pin tab cv lab) [cv lab . acc])
             ('dflt . _)   (: lab (nlab g ".k") _ (pin tab 'dflt lab) acc)
             ('switch . _) acc                                   ; a nested switch owns its labels
             (scasel-l g (stkids it) tab acc)))
   (scasel-l g l tab acc) (? !(two? l) acc (scasel-l g >l tab (scasel g <l tab acc)))

   ; -- the inline lane: a small (or always_inline) fn splices its whole body at the call site, each arg
   ; in a fresh 8-byte temp, every return computing into r0 then jumping to the splice's end label. --
   (noinl? x) (? (elem x '(sdecl goto lbl vastart varr)) 1   ; varr: a VLA's slots ride cgfn's per-fn prescan
                 (atom? x) ()
                 (x @ ('call _ as && 6 < tally as) 1 ()) 1     ; an overflow-arg call moves sp -- splicing it bars the caller's unframe
                 (noinl? <x || noinl? >x))
   (oneret? (i . u))                                  ; decls* + one trailing `return expr` (the b2w shape)
    (i @ ('decl . _) (oneret? u)
         (('ret . rv . _) && two? rv) !(two? u))
   (inlok? f sig aln)                               ; aln: __attribute__((always_inline)) -- the author's word waives the size gate
    (: rt (? (two? sig) <sig 'long)
       items <><>>>f
       (pok ps n) (? !(two? ps) (n <= 6)
                     (: pty <><ps                               ; a d128 param would bind only its lo word -- a real call takes it
                        (? (flo? pty || stru? pty || arr? pty || d128? pty) ()
                           (pok >ps (n + 1)))))
       (? !(two? sig) ()
          (flo? rt || stru? rt) ()
          (sig 2) ()                            ; variadic stays a real call
          !(pok <>>f 0) ()
          ; the size gate on the shown body: 600 for a single-return body, 250 for a branchy one
          (!aln && (oneret? items ? 600 250) < #(show <>>>f)) ()
          !(noinl? <>>>f)))
   (cginl g env f args)                              ; splice f's body at the site -> (ty forms) | 'no (declined)
    (: fe0 (g 'fesc)                          ; a splice that pins fesc would cost the caller every sibcall: declined below
       strs0 (g 'strs)
       il0 (g 'inlining)
       ir0 (g 'inlret)
       irt0 (g 'inlrt)
       _ (pin g 'inlining ((il0 || 0) + 1))
       rt <(peep (g 'sigs) <>f ['long ()])
       ilb9 (nlab g ".il")
       rp0 (g 'rpin)
       ; the bind is sbind's; &param self-declines through clval. a park spans the whole body, so it
       ; must earn its seat by weighted reads (paid?)
       (anyc (a . u)) (callish? a || anyc u)
       body9 <><>>>f
       (paid? nm) (rpays? 'bind 0 (rdw nm body9 1))
       nocall (!(callish? body9) && !(anyc args))
       (dnames x a9)
        (? !(two? x) a9
           (= <x 'decl && two? >x)
            (: (dn ps a) (? !(two? ps) a (dn >ps (<<ps . a)))
               (dn <>x a9))
           (dnames <x (dnames >x a9)))
       dns (dnames body9 ())
       (anyasm x) (? (= x 'asm) 1 !(two? x) () (anyasm <x || anyasm >x))
       asm9 (anyasm body9)
       ; the const bind's license: a literal arg that folds exactly substitutes into the body; declined
       ; when the body assigns or shadows the name, or carries asm (an output could write it unseen)
       (kok? nm) !(asm9 || wrs? nm body9 || elem nm dns)
       br (sbind g env <>>f args nocall body9 kok? paid?)
       ; the body-decl license: a paid decl name register-binds in cgdecl's splice lane; nesting saves/restores
       rb0 (g 'inlrb)
       rbs0 (g 'inlrbs)
       _ (pins g 'inlrb (? nocall (filter paid? dns))
          'inlrbs () 'inlret ilb9 'inlrt rt)
       ; (g 'cgitems), not cgitems: the direct edge closes a letrec cycle the loader re-weaves wrong
       ib0 (peep g 'inlbody 0)
       _ (pin g 'inlbody (ib0 + 1))                ; the body blinds the alias bind (name conflation)
       csbs (? (bad? br) () (br 3))
       (vsub x) (? !(two? x) x
                   (= <x 'var) (: p (assoc <>x csbs) (? (two? p) <>p x))
                   ((vsub <x) . (vsub >x)))
       ibd (? (bad? br) 'bad ((g 'cgitems) g <br (? (two? csbs) (vsub body9) body9) ()))
       _ (pins g 'inlbody ib0 'inlret ir0 'inlrt irt0 'inlining il0 'rpin rp0) ; the bind pins die with the splice
       drbs (g 'inlrbs)
       _ (pins g 'inlrb rb0 'inlrbs rbs0)
       (unrb (a . u)) (rfree g a, unrb u)
       _ (two? br ? (unrb (br 2)))          ; the park regs return to the pool...
       _ (unrb drbs)                                  ; ...and the body-decl binds with them
       (? (bad? br || bad? ibd)                       ; a shape the splice can't take: the real call still can
           (pin g 'fesc fe0, pin g 'strs strs0, 'no)
          (!fe0 && g 'fesc)                   ; the splice took a frame address (an & arg too -- the
           (pin g 'fesc (), pin g 'strs strs0, 'no)   ; real call's arg lane wraps it, bind cannot): keep the caller lean
          (mkv rt 'r0 (<>br + ibd + [['label ilb9]]))))

   ; -- respell: a name declared twice in one fn conflates in alive and kprop, so each later decl
   ; respells (nm`2 ..) and its scope's mentions follow; a static local keeps its spelling (its label) --
   (respell f)
    (: cnt {}
       (fresh nm) (: k (1 + peep cnt nm 0)
                     _ (pin cnt nm k)
                     (? (k = 1) nm (nm + "`" + show k)))
       (re e env)                                   ; an expression (or a type): mentions respell
        (? (atom? e) e
           (e @ ('var nm) (: a (assoc nm env) (? (two? a) ['var <>a] e))
                (map (x \ re x env) e)))
       (rps ps env acc)                             ; decl pairs -> [pairs env]
        (? !(two? ps) [(rev acc) env]
           (: p <ps
              nn (fresh <p)
              env2 ([<p nn] . env)
              (rps >ps env2 (([nn (re <>p env2) (re <>>p env2)] + >>>p) . acc))))   ; + a register variable's pin
       (rsl items env acc)                          ; a statement run: decls extend env for their siblings
        (? !(two? items) (rev acc)
           (: s <items
              (? (two? s && <s = 'decl)
                  (: r (rps <>s env ()) (rsl >items <>r (['decl <r] . acc)))
                 (two? s && <s = 'sdecl)
                  (: env2 (foldl (\ a2 p ([<p <p] . a2)) env <>s)
                     (rsl >items env2 (re s env2 . acc)))
                 (rsl >items env (rs s env . acc)))))
       (rs s env)
        (? (atom? s) s
           (s @ ('blk items) ['blk (rsl items env ())]
                ('if cnd thn els) ['if (re cnd env) (rs thn env) (rs els env)]
                ('if cnd thn) ['if (re cnd env) (rs thn env)]
                ('while cnd body) ['while (re cnd env) (rs body env)]
                ('do body cnd) ['do (rs body env) (re cnd env)]
                ('for ini cnd stp body)
                 (: r (? (two? ini && <ini = 'decl) (rps <>ini env ()) [() env])
                    ini2 (? (two? <r) ['decl <r] (re ini env))
                    env2 <>r
                    ['for ini2 (re cnd env2) (re stp env2) (rs body env2)])
                ('switch ce items) ['switch (re ce env) (rsl items env ())]
                (re s env)))
       env0 (foldl (\ a2 p (: _ (fresh <p) ([<p <p] . a2))) () <>>f)
       [<f <>f <>>f (rs (f 3) env0)])
   ; -- AST constant propagation: a scalar local declared once from a folding initializer, never
   ; written or &-taken, shadowing nothing, reads as its cast literal and its decl drops. runs to a fixpoint --
   (kprop g f)
    (: items <><>>>f
       dcl {} tak {} wrt {} st {}
       (cen x c9)                                   ; one walk: the censuses + the decl pairs seen
        (? !(two? x) c9
           (: c8 (x @ ('addr ('var nm)) (pin tak nm 1, c9)
                     (('asn || 'post) . ('var nm) . _) (pin wrt nm 1, c9)
                     ('asm . _) (pin st 'asm 1, c9)
                     (('decl || 'sdecl) ps)
                      (: (dn l a) (? !(two? l) a
                                     (: _ (pin dcl <<l (1 + peep dcl <<l 0))
                                        (dn >l (? (<x = 'decl && two? >><l) (<l . a) a))))
                         (dn ps c9))
                     c9)
              c8 (cen <x c8)
              (cen >x c8)))
       cds (cen items ())
       pns (: (go l a) (? !(two? l) a (go >l (<<l . a))) (go <>>f))
       (kok nm ty init)
        (? (st 'asm) ()
           !(elem ty '(bool char uchar short ushort int uint long ulong)) ()
           !(1 = peep dcl nm 0) ()
           (tak nm || wrt nm) ()
           (elem nm pns) ()
           (two? (peep (g 'glob) nm 0)) ()
           (g 'fns nm) ()
           (: v (: kc (knum g init)
                   (? (two? kc) <kc
                      (: lv (litv init) (? (two? lv) <lv 'no))))
              (? !(charm? v) ()
                 (: cv (cnum g ['cast ty ['num v]])
                    (two? cv ? ['cast ty ['num <cv]])))))
       sbs (: t {}
              (go l) (? !(two? l) t
                        (: p <l
                           kb (kok <p <>p <>>p)
                           _ (two? kb ? (pin t <p kb))
                           (go >l)))
              (go cds))
       (sub x)
        (atom? x ? x
         (x @ ('var nm) (: k (peep sbs nm ()) (? (two? k) k x))
              ; not &&/||: dp answering () is a legitimate tail
              ('decl ps) ['decl (: (dp l) (? (atom? l) ()
                                             (two? (sbs <<l)) (dp >l)
                                             (sub <l . dp >l))
                                (dp ps))]
             (sub <x . sub >x)))
       (atom? (keys sbs) ? f
        (kprop g ([<f <>f <>>f] + (['blk (sub items)] . >>>>f)))))

   (cgfn g f)                                       ; ('fn name params ('blk items)) -> forms | 'bad
    (: f (kprop g (respell f))
       params <>>f
       _ (fnreset g)                                 ; the whole per-fn pin record wiped (one roster)
       ; v6-M has no fpu: f0/f1/f15 are three frame cells, and soften rewrites every f-op onto them
       _ (v6m? g ? (pins g 'fc0 (ntmp g 'double)
                           'fc1 (ntmp g 'double)
                           'fc15 (ntmp g 'double)))
       ; -- VLA prep: each site takes a pointer slot + a size slot, the size zeroed after the param
       ; spill (the decl lane reads 0 = never allocated) --
       _ (pins g 'fn <>f 'vslots {})
       vzf (: (dscan prs a2)
               (? (atom? prs) a2
                  (: ty9 <><prs
                     (dscan >prs (? (gvarr? ty9 && 3 < #ty9)
                                    (varix ty9 . a2) a2))))
              (vscan x acc)                          ; walk the body for VLA decl sites
               (? !(two? x) acc
                  (<x == 'decl && two? >x) (dscan <>x acc)
                  (vlist x acc))
              (vlist l acc) (atom? l ? acc (vlist >l (vscan <l acc)))
              idxs (vscan (f 3) ())
              (mk l a2)
               (? !(two? l) a2
                  (: po (ntmp g 'long) so (ntmp g 'long)
                     _ (pin (g 'vslots) <l [po so])
                     (mk >l (a2 + [['st 'r4 so 'r0]]))))
              (? !(two? idxs) () ('((li r0 0)) + mk idxs ())))
       sig (g 'sigs <>f)
       vararg (two? sig ? (sig 2))
       ; the epilogue is per-fn: a vararg t32/rv fn drops its push block on the way out
       _ (pin g 'epi (? (vararg && t32? g) (v6m? g ? epi-t16va epi-t32va)
                        (vararg && rv64? g) epi-rv-va
                        (v6m? g) epi-t16 (arm? g) epi-a64 epi))
       ; hp is the home policy over the gp params: () spills every one to its slot, ('uni rides homes excl)
       ; seats upar's verdicts; under a policy an exotic composite answers 'bad and ubuild bares
       (pol? h9) (two? h9)                           ; the one policy is the uni seat list
       (spill hp ps gpi xmmi ovi env acc)
        (? !(two? ps) [acc env]
           (: p <ps pty <>p
              (? (v6m? g && sse2? g pty)                ; v6-M: a position-0 16B composite arrives whole in r0-r3
                  (gpi != 0 ? 'bad                          ;  (the caller's g4 lane); any later start splits -- deferred
                   (: off (nslot g 16)
                      (spill hp >ps 4 xmmi ovi ([<p off pty] . env)
                       (acc + [['st 'r4 off 'r0] ['st 'r4 (off + 4) 'r1]
                               ['st 'r4 (off + 8) 'r2] ['st 'r4 (off + 12) 'r3]]))))
                 (t32? g && stru? pty &&                ; t32 params: the d-pair HFA, the 8B sse blob, the <=4B int
                  !(sse2? g pty ||                      ; one (the gp lane's word store is its <=4 bytes);
                    aone g pty == 'sse && tsz g pty = 8 ||       ; mixed/int-pair composites refuse loud
                    aone g pty == 'int && tsz g pty <= 4)) 'bad
                 ; the AAPCS-VFP seats (t32f): a float HFA aligns to one s-slot and can straddle a d-register,
                 ; so its words come home one at a time; a float's slot holds the binary32 word (fldf 'float reads it)
                 (t32f? g && stru? pty && (= (hfab g pty) 'float))
                  (: n (tsz g pty // 4)
                     k (vfpn xmmi n 1)
                     (? (k < 0) (nolane g ("no lane for a float HFA param past the register file" + ontgt g))
                        (: off (nslot g (tsz g pty <= 8 ? 8 16))
                           (go i acc9) (? (n <= i) acc9
                                          (go (i + 1) (acc9 + vfpsv (k + i) 'r4 (off + 4 * i))))
                           (spill hp >ps gpi (vfpm xmmi k n) ovi ([<p off pty] . env) (acc + go 0 ())))))
                 (t32f? g && sse2? g pty)                  ; a two-double HFA: an adjacent d-pair
                  (: k (vfpn xmmi 4 2)
                     (? (k < 0) (nolane g ("no lane for an HFA param past the register file" + ontgt g))
                        (: off (nslot g 16) d (k // 2)
                           (spill hp >ps gpi (vfpm xmmi k 4) ovi ([<p off pty] . env)
                                  (acc + fstf g 'double 'r4 off (xmmreg d)
                                       + fstf g 'double 'r4 (off + 8) (xmmreg (d + 1)))))))
                 (t32f? g && (= pty 'float))               ; a bare float: one slot, else the caller's 4-byte word
                  (? (0 <= vfpn xmmi 1 1)
                     (: k (vfpn xmmi 1 1) off (nslot g 8)
                        (spill hp >ps gpi (vfpm xmmi k 1) ovi ([<p off pty] . env)
                               (acc + vfpsv k 'r4 off)))
                     (spill hp >ps gpi vfpx (ovi + 4) ([<p (ovb g + ovi) pty] . env) acc))
                 (t32f? g && (flo? pty || stru? pty && (= (aone g pty) 'sse)))   ; a double, or a one-double HFA
                  (? (0 <= vfpn xmmi 2 2)
                     (: k (vfpn xmmi 2 2) off (nslot g 8)
                        (spill hp >ps gpi (vfpm xmmi k 2) ovi ([<p off pty] . env)
                               (acc + fstf g 'double 'r4 off (xmmreg (k // 2)))))
                     (: ov8 ((ovi + 7) & -8)
                        (spill hp >ps gpi vfpx (ov8 + 8) ([<p (ovb g + ov8) pty] . env) acc)))
                 (v6m? g && stru? pty && aone g pty == 'sse)           ; v6-M 8B blob param: the even-odd gp pair (the caller's g2 lane)
                  (: gpe ((gpi + 1) & -2)
                     (? (gpe + 2 <= ngp g)
                         (: off (nslot g 8)
                            (spill hp >ps (gpe + 2) xmmi ovi ([<p off pty] . env)
                                   (acc + [['st 'r4 off (argr g gpe)]
                                            ['st 'r4 (off + 4) (argr g (gpe + 1))]])))
                        (: ov8 ((ovi + 7) & -8)
                           (spill hp >ps 4 xmmi (ov8 + 8) ([<p (ovb g + ov8) pty] . env) acc))))
                 (stru? pty && two? (aeb2 g pty))       ; a 9..16B struct param: two eightbytes into a 16-byte slot, each from a gp or an xmm reg
                  (? (pol? hp && !(sse2? g pty)) 'bad        ; a policy homes gp scalars only -- mixed/int-pair 16B deopts
                     (: cls (aeb2 g pty) c0 <cls c1 <>cls
                        ; the file per eightbyte, 'g gp / 'x xmm: SysV by class, AAPCS64 wholly in X unless an all-float HFA
                        hfa (c0 = 'sse && c1 = 'sse)
                        f0 (a64? g ? (hfa ? 'x 'g) (c0 @ 'sse 'x 'g))
                        f1 (a64? g ? (hfa ? 'x 'g) (c1 @ 'sse 'x 'g))
                        gpn ((f0 = 'g) + (f1 = 'g))
                        xmn ((f0 = 'x) + (f1 = 'x))
                        (? (ngp g < gpi + gpn || 8 < xmmi + xmn)     ; not enough regs -> the whole aggregate goes to memory (2 stack eightbytes)
                            (? (pol? hp) 'bad           ; under a policy: deopt, not a fresh memory lane
                               (t32? g)                 ; t32 stack HFA params (9+ doubles): deferred
                                (nolane g ("no lane for an HFA param past the register file" + ontgt g))
                               (spill hp >ps gpi xmmi (ovi + 2) ([<p (ovb g + (* 8 ovi)) pty] . env) acc))
                            (: off (nslot g 16)
                               st0 (f0 @ 'g [['st 'r4 off (argr g gpi)]] (fstf g 'double 'r4 off (xmmreg xmmi)))
                               gp1 (f0 @ 'g (gpi + 1) gpi)
                               xm1 (f0 @ 'x (xmmi + 1) xmmi)
                               st1 (f1 @ 'g [['st 'r4 (off + 8) (argr g gp1)]] (fstf g 'double 'r4 (off + 8) (xmmreg xm1)))
                               gp2 (f1 @ 'g (gp1 + 1) gp1)
                               xm2 (f1 @ 'x (xm1 + 1) xm1)
                               (spill hp >ps gp2 xm2 ovi ([<p off pty] . env) (acc + st0 + st1))))))
                 (stru? pty && aone g pty == 'sse)       ; a small SSE aggregate: one xmm into an 8-byte slot
                  (? (xmmi < 8)
                     (: off (nslot g 8)
                        (spill hp >ps gpi (xmmi + 1) ovi ([<p off pty] . env)
                               (acc + fstf g 'double 'r4 off (xmmreg xmmi))))
                     (? (t32? g)                        ; t32 stack blob params: deferred
                         (nolane g ("no lane for a stack-passed by-value struct param" + ontgt g))
                        (spill hp >ps gpi xmmi (ovi + 1) ([<p (ovb g + (* 8 ovi)) pty] . env) acc)))
                 ; a memory-class param binds straight to the caller's overflow block (SysV: that memory is the callee's copy)
                 (amem? g pty)
                  (? (pol? hp || 8 < asalign g pty) 'bad     ; under a policy, or over-aligned: deopt/refuse
                     (spill hp >ps gpi xmmi (ovi + aslots g pty)
                            ([<p (ovb g + 8 * ovi) pty] . env) acc))
                 (stru? pty && aone g pty !== 'int)        ; mixed pair stays ahead; a small int one rides the gp lane
                  (nolane g ("no lane for passing this " + show (tsz g pty)
                             + "-byte struct by value" + ontgt g))
                 (v6m? g && pty == 'float)             ; v6-M base ABI: a bare float param is one word
                  (? (gpi < ngp g)                      ;  (binary32 bits in a gp reg / a 4-byte caller slot);
                     (: off (nslot g 8) ;  clval's fldf 'float widens it on read
                        (spill hp >ps (gpi + 1) xmmi ovi ([<p off pty] . env)
                               (acc + [['st 'r4 off (argr g gpi)]])))
                     (spill hp >ps gpi xmmi (ovi + 4) ([<p (ovb g + ovi) pty] . env) acc))
                 (v6m? g && flo? pty)                   ; v6-M base ABI: a double param is a gp pair
                  (: gpe ((gpi + 1) & -2)               ;  (no FPU regs exist) -- spill both words, or
                     (? (gpe + 2 <= ngp g)            ;  read the 8-aligned caller stack
                         (: off (nslot g 8)
                          (spill hp >ps (gpe + 2) xmmi ovi ([<p off pty] . env)
                           (acc + [['st 'r4 off (argr g gpe)]
                            ['st 'r4 (off + 4) (argr g (gpe + 1))]])))
                        (: ov8 ((ovi + 7) & -8)
                         (spill hp >ps 4 xmmi (ov8 + 8) ([<p (ovb g + ov8) pty] . env) acc))))
                 (flo? pty && xmmi < 8)
                  (: off (nslot g 8)
                     (spill hp >ps gpi (xmmi + 1) ovi ([<p off pty] . env)
                            (acc + fstf g pty 'r4 off (xmmreg xmmi))))
                 (pair? g pty)                          ; a pair param: an even-odd register pair spills
                  (: gpe ((gpi + 1) & -2)               ;  both words; else the 8-aligned stack (gp closes)
                     (? (gpe + 2 <= ngp g)
                         (: off (nslot g 8)
                          (spill hp >ps (gpe + 2) xmmi ovi ([<p off pty] . env)
                                 (acc + [['st 'r4 off (argr g gpe)]
                                          ['st 'r4 (off + 4) (argr g (gpe + 1))]])))
                        (: ov8 ((ovi + 7) & -8)
                         (spill hp >ps 4 xmmi (ov8 + 8) ([<p (ovb g + ov8) pty] . env) acc))))
                 (d128? pty)                            ; a wide param: not carried (mirror of the arg refusal)
                  (nolane g "a wide value is not carried as a parameter")
                 (!(flo? pty) && gpi < ngp g)
                  (? (two? hp && gpi < nhome g &&
                      (elem gpi <>hp || elem gpi (hp 2)))
                      ; a rider keeps its arrival, a positional home pays one mov; every home wears the
                      ; armed shadow -- its slot is reserved but untouched until a call really emits
                      (: inc (argr g gpi)
                         home (? (elem gpi <>hp) inc (homereg gpi))
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
                 (t32? g) (spill hp >ps gpi xmmi (ovi + 4) ([<p (ovb g + ovi) pty] . env) acc)
                 (spill hp >ps gpi xmmi (ovi + 1) ([<p (ovb g + 8 * ovi) pty] . env) acc))))
       ; a variadic fn (SysV): a 176-byte save area, gp regs at +0 step 8, xmm at +48 step 16, saved
       ; unconditionally; a pair touching xmm copies into its own slot (the xmm cells step 16, its eightbytes sit 8 apart)
       (vaspill ps)
        (: rsa (nslot g 176)
           _ (pin g 'rsa rsa)
           savegp (: (go i acc) (? (5 < i) acc (go (i + 1) (acc + [['st 'r4 (rsa + 8 * i) (argregs i)]]))) (go 0 ()))
           savex  (: (go i acc) (? (7 < i) acc (go (i + 1) (acc + [['stsd 'r4 (rsa + 48 + 16 * i) (xmmreg i)]]))) (go 0 ()))
           (cls qs gpi xmmi ov env acc)
            (? !(two? qs) (: _ (pins g 'vagp gpi 'vaxmm xmmi) [((savegp + savex) + acc) env])
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
                        (? (6 < gpi + gpn || 8 < xmmi + xmn) (ovf ())   ; short of registers: the whole aggregate goes to memory
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
                   (cls >qs (gpi + 1) xmmi ov ([<p (rsa + (* 8 gpi)) pty] . env) acc))))
           (cls ps 0 0 0 () ()))
       ; a variadic fn (AAPCS64): a 192-byte save area, x0..x7 at +0 step 8, q0..q7 at +64 step 16 (the low 8 bytes the double)
       (vaspill-a64 ps)
        (: rsa (nslot g 192)
           _ (pin g 'rsa rsa)
           savegp (: (go i acc) (7 < i ? acc (go (i + 1) (acc + [['st 'r4 (rsa + 8 * i) (argregs-a64 i)]]))) (go 0 ()))
           savevr (: (go i acc) (7 < i ? acc (go (i + 1) (acc + fstf g 'double 'r4 (rsa + 64 + 16 * i) (xmmreg i)))) (go 0 ()))
           (cls qs gpi vri ov env)
            (? !(two? qs) (: _ (pins g 'vagp gpi 'vaxmm vri 'vaov ov) [(savegp + savevr) env])
               (: p <qs pty <>p
                  (? (flo? pty)
                      (7 < vri ? (cls >qs gpi vri (ov + 1) ([<p (ovb g + 8 * ov) pty] . env))
                                 (cls >qs gpi (vri + 1) ov ([<p (rsa + 64 + 16 * vri) pty] . env)))
                     (7 < gpi ? (cls >qs gpi vri (ov + 1) ([<p (ovb g + 8 * ov) pty] . env))
                                (cls >qs (gpi + 1) vri ov ([<p (rsa + 8 * gpi) pty] . env))))))
           (cls ps 0 0 0 ()))
       ; a variadic fn (AAPCS32): the prologue pushed r0-r3 just under the caller's stack args, so a
       ; named register param sits at fp+ovb+4i and an overflow one past it; word params only
       (vaspill-t32 ps)
        (: (cls qs gpi ov env)
            (? !(two? qs) (pins g 'vagp gpi 'vaov ov, [() env])
               (: p <qs pty <>p
                  (? (flo? pty || llt? pty || stru? pty)
                      (nolane g ("no lane for a double/pair/struct param in a variadic function" + ontgt g))
                     (3 < gpi) (cls >qs gpi (ov + 4) ([<p (ovb g + 16 + ov) pty] . env))
                     (cls >qs (gpi + 1) ov ([<p (ovb g + 4 * gpi) pty] . env)))))
           (cls ps 0 0 ()))
       ; a variadic fn (riscv): a0..a7 lie in a 64-byte block above the push cells, so a named register param
       ; sits at fp+ovb+8i and an overflow one past it (+64); a named double rides the gp lane too (the caller's va? classifier)
       (vaspill-rv ps)
        (: (cls qs gpi ov env)
            (? !(two? qs) (pins g 'vagp gpi 'vaov ov, [() env])
               (: p <qs pty <>p
                  (? (stru? pty) (nolane g ("no lane for a by-value struct param in a variadic function" + ontgt g))
                     (7 < gpi) (cls >qs gpi (ov + 1) ([<p ((ovb g + 64) + 8 * ov) pty] . env))
                     (cls >qs (gpi + 1) ov ([<p (ovb g + 8 * gpi) pty] . env)))))
           (cls ps 0 0 ()))
       ; -- register-homed params: the home pool (hregs g, by gp position) is disjoint from scratch and the
       ; arg registers; every home also takes a frame slot in g 'homes, which call-fixed spills around a call --
       (homereg gpi) (hregs g gpi)
       (build sp0)                                  ; assemble prologue + body + epilogue for a spill result
        (? (bad? sp0) 'bad
           (: body (bldreset g,
                    cgitems g <>sp0 <><>>>f ())
              (? (bad? body) 'bad
                 (: frame ((peep g 'off 0 + 15) & -16)
                    (? (arm? g)
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
                          ((? (v6m? g)   ; v6m: extra push r4 (bottom base), planted after the sub; fp stays at top
                              ([['label (name <>f)]] +
                               (? vararg   ; vararg v6m: r0-r3 land above lr/fp/r4, contiguous with the caller stack args
                                '((push r3) (push r2) (push r1) (push r0))) +
                               ['(push lr) '(push fp) '(push r4)
                                  '(lea fp sp 0) ['sub 'sp 'sp frame] '(lea r4 sp 0)])
                              ([['label (name <>f)]] +
                               (? (vararg && t32? g)     ; vararg t32: r0-r3 land under fp/lr,
                                  '((push r3) (push r2) (push r1) (push r0))               ; contiguous with the caller stack args
                                  (vararg && rv64? g)      ; vararg riscv: a0-a7 in a packed 64-byte block
                                  ['(sub sp sp 64)      ; under fp/lr, contiguous with the caller stack args
                                     '(st sp 0 r0) '(st sp 8 r1) '(st sp 16 r2) '(st sp 24 r3)
                                     '(st sp 32 r4) '(st sp 40 r5) '(st sp 48 r6) '(st sp 56 r7)]
                                  ()) +
                               (? (rv64? g)     ; riscv links last, so fp lands at the frame bottom
                                  ['(push lr) '(push fp) ['sub 'sp 'sp frame] '(lea fp sp 0)]
                                  (pro-a64 + [['sub 'sp 'sp frame]])))) +
                           ; the cs saves ride after the frame is up (fp-relative slots), past unframe's positional prologue read
                           g 'cssv +
                           <sp0 + body + '((li r0 0)) + peep g 'epi epi-a64))))))
                       (deadst g
                        (deaddef g      ; rerun: the widened addrfold strands live-dest addr insns
                        (cmpfuse g
                        (addrfold g
                        (rezx g         ; after stld: the forward mints zx, this drops the redundant
                        (copyprop g
                        (stld g
                        (spmerge
                        (deaddef g
                        (deadcell g
                        (cfoldir g
                         (sibcall g
                          (vrfix g
                          ([['label (name <>f)]] + pro4 + [['sub 'sp 'sp frame] sav3] +
                           g 'cssv + <sp0 +
                           body + '((li r0 0)) + peep g 'epi epi)))))))))))))))))))
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
           ; the AST ret count, floored at 1 (strict: sibcalls eat rets in emission, and the chains catch the rest)
           nx9 (? (0 < av9 10) (av9 10) 1)
           nsq (av9 13)
           navl (? (3 < #hp9) (#hp9 - 2) (1 < #hp9) 1 0)   ; the file already lost the param homes: keep one grantable seat while two remain
           (firstn l n) (? (atom? l || n < 1) () (<l . firstn >l (n - 1)))
           ; arrival registers rank last: a seat there evicts what the sweeps still forward from it
           arr9 (map (\ i (argr g i)) (jot (? (#params < ngp g) #params (ngp g))))
           hp8 (filter (\ q !(elem q arr9)) hp9 + filter (\ q (elem q arr9)) hp9)
           pfile (firstn hp8 navl)
           kp (cspool g)
           ; touch counts key by name, so a shadowed name's sites conflate: average them out
           sitec (: t {}
                    (go2 i) (? (nsq < i) t
                               (: e2 (sqm9 i)
                                  _ (? (two? e2) (pin t <e2 (1 + peep t <e2 0)) 0)
                                  (go2 (i + 1))))
                    (go2 1))
           cands (: (go i acc)
                    (? (nsq < i) acc
                       (: e2 (peep sqm9 i ())
                          (? !(two? e2) (go (i + 1) acc)
                             (: nm <e2 ty <>e2
                                u9 (elem nm uv)
                                (? (tak9 nm) (go (i + 1) acc)   ; an &-taken name stays a cell
                                   (: ns9 (peep sitec nm 1)
                                      tc (peep rdc9 nm 0 @ n (1 < ns9 ? (n // ns9) n))
                                      d1 (d128? ty)
                                      ; a shadowed name (!u9) takes no pool seat and no span; a leaf-shaped fn
                                      ; pool-homes by rank alone, a hard-calling one only a zero-crossing name
                                      pok (? (d1 || !u9) ()
                                             lf9 (2 <= tc)
                                             (peep crs9 nm 0 = 0 && 2 <= tc))
                                      cok (2 < tc && 1 + nx9 < tc)
                                      (? !(pok || cok) (go (i + 1) acc)
                                         (go (i + 1) ([tc (? (1 < ns9) (peep rdt9 nm 0 // ns9)
                                                             (peep rdt9 nm 0)) i
                                                       (? u9 (spa9 nm) ())
                                                       (? d1 2 1) pok cok] . acc)))))))))
                    ; the blockers: a hot hard-crossing param competes by rank, and a seat it wins stays
                    ; unwritten for repack's chain lane downstream
                    (: (bgo l k acc)
                        (? !(two? l) acc
                           (bgo >l (k - 1) ([<<l <><l k () 1 () 'b] . acc)))
                       (bgo bl9 -1 (go 1 ()))))
           byw (sortby (\ a b (? (<b < <a) 1 (<a < <b) ()
                                  (a 4 < b 4) 1 (b 4 < a 4) ()
                                  (<>b < <>a) 1 (<>a < <>b) ()
                                  (<>>a < <>>b)))
                       cands)
           occ {}                             ; seat -> its occupants' spans, 'x exclusive
           (fits? r sp)
            (: o (peep occ r ())
               (? (= o 'x) ()
                  !(two? o) 1
                  !(two? sp) ()
                  (: (dj l) (? !(two? l) 1
                               (: s9 <l ((<>s9 < <sp) || (<>sp < <s9) ? (dj >l) ())))
                     (dj o))))
           (claim r sp) (pin occ r (? !(two? sp) 'x
                                      (: o (peep occ r ()) (? (two? o) (sp . o) [sp]))))
           (seat1 file sp) (? !(two? file) ()
                              (fits? <file sp) <file
                              (seat1 >file sp))
           (seat2 file sp)
            (: r1 (seat1 file sp)
               (? !r1 ()
                  (: r2 (seat1 (filter (\ q !(= q r1)) file) sp)
                     (? r2 [r1 r2] ()))))
           lh {} pw {} cw {}
           _ (foldl
              (\ _ c
                (: sq (c 2) sp (c 3) w2 (c 4) pok (c 5) cok (c 6)
                   r (? pok (seat1 pfile sp) ())
                   (? r (: _ (claim r sp) _ (pin pw r 1) (pin lh sq r))
                      !cok 0
                      (w2 = 2)
                       (: p2 (seat2 kp sp)
                          (? !(two? p2) 0
                             (: _ (claim <p2 sp) _ (claim <>p2 sp)
                                _ (pin cw <p2 1) _ (pin cw <>p2 1)
                                (pin lh sq p2))))
                      (= cok 'b)
                       (: r2 (seat1 kp sp) (r2 && claim r2 sp)) ; a blocker claims; nothing is written
                      (: r2 (seat1 kp sp)
                       (r2 && (claim r2 sp, pin cw r2 1, pin lh sq r2))))))
              0 byw)
           pused (filter (q \ peep pw q 0) hp9)
           cu0 (filter (q \ peep cw q 0) kp)
           [lh (filter (q \ !(elem q pused)) hp9) cu0])
       ; the param verdicts -> (rides homes excl depth): a cold homable param rides its arrival where
       ; sound (a quad pays one mov to its positional seat), a hard-crossing one stays a cell
       (upar av9 qk)
        (: uv <>>av9 crh9 (av9 6) rdc9 (av9 7) rdt9 (av9 8)
           lf9 (av9 15 <= 2)                  ; leaf-shaped: at most two cold hard crossings (see ulloc)
           pq9 (qk && av9 16)                    ; protocol-quiet: nothing in the body writes a quad
           wd9 (av9 17 &&                      ; d128 material: the wide kit owns the file --
                !(a64? g || t32? g || rv64? g))         ; on x64, whose mul/div pin the rax:rdx pair
           (homefold g params 0 [() () () #tpool]
            (\ a4 gpi p9
              (: nm <p9 pty <>p9
                 A (argr g gpi)
                 nv (a4 3)                       ; the file's running depth (homes and rides drain it)
                 ok (lf9 && !wd9 && elem nm uv && peep crh9 nm 0 <= 2)
                 ; a bool's entry cvt defs through set, which qclob? cannot tell from a clobber: a bool quad vacates
                 qb9 (= pty 'bool && elem A '(r0 r1 r2 r3))
                 (? (ok && homable? pty)
                    (? (= A (homereg gpi)) [<a4 (gpi . <>a4) (a4 2) (nv - 1)]
                       (a4rider? A) [<a4 (gpi . <>a4) (a4 2) nv]
                       (elem A '(r0 r1 r2 r3))
                        ; a protocol-quiet body rides the quad free (ubuild re-checks the built forms); a dirty one vacates
                        (? pq9 [(gpi . <a4) <>a4 (a4 2) nv]
                           [<a4 (gpi . <>a4) (a4 2) (nv - 1)])
                       [(gpi . <a4) <>a4
                        (? (elem A tpool) (A . a4 2) (a4 2))
                        (? (elem A tpool) (nv - 1) nv)])
                    ; an int param rides its arrival if read at least once, no d128 about, and the file
                    ; stays two deep after the take; a64's r4 arrival rides free
                    (ok && lhomable? pty && !qb9 && (0 < peep rdc9 nm 0) && !wd9 &&
                     (elem A tpool && 3 <= nv || a4rider? A))
                     [(gpi . <a4) <>a4
                      (? (elem A tpool) (A . a4 2) (a4 2))
                      (? (elem A tpool) (nv - 1) nv)]
                    (ok && lhomable? pty && !qb9 && (0 < peep rdc9 nm 0) &&
                     pq9 && elem A '(r0 r1 r2 r3))
                     [(gpi . <a4) <>a4 (a4 2) nv]
                    ; ..and a hot one (weighted reads >= 64, the blocker bar) that cannot ride vacates to its positional seat
                    (ok && lhomable? pty && !wd9 && 64 <= peep rdt9 nm 0 &&
                     elem A '(r0 r1 r2 r3) && 3 <= nv)
                     [<a4 (gpi . <>a4) (a4 2) (nv - 1)]
                    a4)))))
       ; the quad-ride check: a ridden r0-r3 arrival's only legitimate def is its entry cvt; any other
       ; def falsifies the ride, and a form rdsp cannot read ('bar) counts as a hit
       (qclob? fs qrr)
        (? !(two? qrr) ()
           (: (go l) (? !(two? l) ()
                        (: f9 <l
                           (? (!(two? f9) ||
                               elem <f9 '(sx4 zx4 sx2 zx2 sx1 zx1 label align br jmp jmpr ret)) (go >l)
                              (: rd (rdsp g f9)
                                 (? (= rd 'bar) 1
                                    (: (hit l2) (? !(two? l2) ()
                                                   (elem <l2 qrr) 1
                                                   (hit >l2))
                                       (? (hit <>rd) 1 (go >l))))))))
              (go fs)))
       (ubuild av9)
        (: ok9 (two? av9 && !(av9 11) && !(av9 12))   ; no asm, no vla
           ; ride the quads first; if the built forms show a ridden register taken, demote them and
           ; build once more (attempt () has no rides to fail)
           (attempt qk)
            (: pv (? ok9 (upar av9 qk) '(() () ()))
               rides <pv phs <>pv excl (pv 2)
               uh9 (map homereg phs)
               pool2 (filter (\ q !(elem q uh9 || elem q excl)) tpool)
               bl9 (? !ok9 ()
                      (: crh9 (av9 6) rdc9 (av9 7) rdt9 (av9 8)
                         (homefold g params 0 ()
                          (\ a2 gpi p9
                            (: nm <p9
                               wt (peep rdt9 nm 0)
                               (homable? <>p9 && 0 < peep crh9 nm 0 && 64 <= wt ?
                                  ([(peep rdc9 nm 0) wt] . a2) a2))))))
               lr (ok9 ? (ulloc av9 pool2 bl9))
               lh9 (two? lr ? <lr {})
               lp9 (two? lr ? <>lr pool2)
               cu0 (two? lr ? <>>lr ())
               e0 (peep g 'epi epi)
               ; no reset before the first attempt: the VLA prep's slots live in this frame state and a
               ; reset would re-deal them (ok9 bars VLAs from every path that retries)
               _ (pins g 'pool0 lp9 'pool lp9)
               _ (rgset g lh9 av9)
               _ (? (two? cu0)
                    (: sv (map (\ r9 ['st 'r4 (nslot g 8) r9]) cu0)
                       _ (pin g 'cssv sv)
                       (pin g 'epi (map (\ f9 ['ld (f9 3) 'r4 (f9 2)]) sv + e0)))
                    ())
               ; empty grants take the bare () policy, so no policy bar can fire
               spu (spill (? (two? rides || two? phs) ['uni rides phs] ()) params 0 0 0 () ())
               spu (? (two? vzf) [(<spu + vzf) <>spu] spu)
               irU (build spu)
               _ (pins (rgreset g) 'cssv () 'epi e0)
               qrr (: (go l) (? !(two? l) ()
                                (: A (argr g <l)
                                   (? (elem A '(r0 r1 r2 r3)) (A . go >l) (go >l))))
                      (go rides))
               (? (qk && two? qrr && qclob? irU qrr)
                  (: _ (pins (fnreset g) 'n n0 'strs strs0 'statics sts0 'pool0 tpool 'pool tpool)
                     (attempt ()))
                  (bad? irU ||
                   (two? av9 && peep g 'lsq 0 != av9 3) ||
                   !(peep g 'dseq 0 = (two? av9 ? (av9 13) (peep g 'dseq 0))))
                  (: _ (pins (fnreset g) 'n n0 'strs strs0 'statics sts0 'pool0 tpool 'pool tpool)
                     sb (spill () params 0 0 0 () ())
                     sb (? (two? vzf) [(<sb + vzf) <>sb] sb)
                     (build sb))
                  irU))
           (attempt 1))
       n0 (peep g 'n 0) strs0 (g 'strs) sts0 (g 'statics)   ; snapshot the accumulators for ubuild's retry
       ; no pool on t32 (r4-r11 callee-saved, r0-r3/r12 scratch); riscv pools t0..t3 then a5..a7, as
       ; a64 pools x5..x7 -- an arg register is dead once spilled or homed
       tpool (? (abl? g 'tpool) () (t32? g) () (rv64? g) '(r8 r9 r10 r11 r5 r6 r7) opool)
       _ (pins g 'pool0 tpool 'pool tpool)
       ; a memory return: the hidden pointer (gp 0) saves to its own slot, params start at gp 1; the ret lane reads g 'sret
       srt (two? sig ? <sig 'long)
       sr6f (sretm? g srt)
       ; the one build: seats from alive; a memory sret and varargs take the bare spill build, no seats
       uni9 !(sr6f || vararg)
       _ (? sr6f (pin g 'sret (ntmp g 'long)) ())
       sp1 (? uni9 ()
              (vararg && a64? g) (vaspill-a64 params)
              (vararg && t32? g) (vaspill-t32 params)
              (vararg && rv64? g) (vaspill-rv params)
              vararg (vaspill params)
              sr6f (spill () params 1 0 0 () [['st 'r4 (peep g 'sret 0) (argr g 0)]])
              (spill () params 0 0 0 () ()))
       sp1 (? (uni9 || !(two? vzf)) sp1 [(<sp1 + vzf) <>sp1])   ; the VLA size-slot zeroes ride after the spills
       irf (? uni9 (ubuild (alive g f)) (build sp1))
       ; the post-choice chain, typed by stage.l (each pass advances a stage die, so only this order checks):
       ; the a64 sweeps, then deadlab, then repack (a dead region's touches would fatten its windows). cmpfuse is x64-only
       (swp irx) (? !(a64? g) irx
                    (tailst g
                    (deadst g
                     (deaddef g
                     (addrfold g
                     (rezx g
                     (copyprop g
                     (stld g
                     (spmerge
                     (deaddef g
                     (deadcell g
                     (cfoldir g irx))))))))))))
       ; the copy fold again after repack: a slot copied from a seat repack just minted forwards from it now
       (post irx) (deadst g (deaddef g (copyprop g (stld g (copyprop g (repack g irx))))))
       (? (bad? irf) irf (cskeep g (unhome g (jr0 g (unframe g (coal g (post (deadlab (swp irf))))))))))

   ; the data tail -> (dataforms nifforms imgforms extras bssforms rodataforms) | 'bad, extras ((name forms
   ; ro?) ..) per other named section in declaration order. love_nifs packs for the linker's __start_/__stop_
   ; bracket, .image rides last so `love bake` can grow it at the tail.
   (cgdata g)
    (: sects (g 'sects || {})
       consts (g 'consts || {})
       memo (g 'romemo || {})
       (strm nm) (: s (sects nm)                  ; which stream a global belongs to
                    (? s s ".data"))                      ; the name is the stream
       ; an uninitialized global rides .bss unless it names its own section
       (bss? nm) (!(sects nm) && !(two? <>>(peep (g 'glob) nm 0)))
       ; a const global rides .rodata only if its image needs no relocation (a pointer the linker
       ; writes stays in .data, gcc's .data.rel.ro)
       (ro? nm bytes) (consts nm &&
                       !(foldl (a \ x \ a || fixit? x) () bytes))
       ; a const candidate images twice ('d and 'r), so it memoizes; only candidates do
       (image1 nm ty init)
        (? !(consts nm) (cgimage g ty init)
           (: m (memo nm)
              (? (two? m) <>m
                 (: v (cgimage g ty init) (pin memo nm [1 v], v)))))
       ; zm: 'd the initialized, 'z the bss, 'r the const ones .rodata claims, () everything (a named stream never splits)
       (globs gs want zm acc)
        (? !(two? gs) acc
           !(strm <gs = want) (globs >gs want zm acc)        ; another stream's
           (elem zm '(d r) && bss? <gs) (globs >gs want zm acc)
           (zm = 'z && !(bss? <gs)) (globs >gs want zm acc)
           (: ge (peep (g 'glob) <gs 0)
              lbl <ge ty <>ge init <>>ge
              _ (pins g 'undecl () g 'datacause ())   ; fresh per global: the refusal below names this one's cause
              bytes (image1 <gs ty init)                ; a constant image | 'bad (label values -> 4d)
              ; a refusal is neither 'r nor 'd: the 'd walk reports it, 'r steps past in silence
              roq (!(bad? bytes) && ro? <gs bytes)
              ; an aligned(N) global pads within the stream (the .o's header carries the max N); the two packed streams take none
              an (? (elem want '("love_nifs" ".love.image")) 0 (peep (g 'aligns) <gs 0))
              ; the cause rides a pin: callers thread a bare 'bad through (bad? x) joins, and a gripe is not one
              (? (zm = 'r && !roq) (globs >gs want zm acc)
                 (zm = 'd && roq) (globs >gs want zm acc)
                 (bad? bytes)
                 (: u (g 'undecl)
                    _ (pin g 'datacause
                           (? u ("undeclared '" + u + "' in the initializer of '" + <gs + "'")
                              ("cannot lay the initializer of '" + <gs + "' (" + show init + ")")))
                    'bad)
                 (: als (: (go l a2) (? !(two? l) a2
                                          (go >l (g 'alias <l = <gs ?
                                                  (['label (name <l)] . a2) a2)))
                           (go (keys (g 'alias)) ()))   ; a data alias (musl's __stdin_used) names the same bytes
                    (globs >gs want zm (acc + (1 < an ? [['align an]])
                                           + als + [['label lbl] ['raw bytes]]))))))
       ; equal literals share one block with every label on it (C leaves them unspecified as distinct);
       ; grouped at layout, not at intern -- the codegen retry paths roll 'strs back
       (strs ss acc)
        (: (bts s i bacc) (i < 0 ? bacc (bts s (i - 1) (s i . bacc)))
           (grp l seen ord)
            (? !(two? l) [seen (rev ord)]
               (: p <l t <>p old (peep seen t ())
                  (grp >l (pin seen t (old + [<p])) (two? old ? ord (t . ord)))))
           (lay ts seen a)
            (? !(two? ts) a
               (: t <ts
                  (lay >ts seen (a + map (\ b ['label b]) (seen t)
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
                         (? (!(bad? b) && ro? <gs b) (go >gs) ())))
           (go (g 'globs)))
       ; the other section names, first-seen in declaration order
       xnames (: (go gs acc) (? !(two? gs) (rev acc)
                                (: s (strm <gs)
                                   (go >gs (? (elem s '(".data" ".rodata" "love_nifs" ".love.image") ||
                                               elem s acc)
                                              acc (s . acc)))))
                 (go (rev (g 'globs)) ()))
       (: gb (globs (rev (g 'globs)) ".data" 'd ())     ; exported globals, then block-scope statics
          sb (? (bad? gb) 'bad (globs (rev (g 'statics)) ".data" 'd ()))   ; (local data labels)
          zg (? (bad? gb || bad? sb) 'bad (globs (rev (g 'globs)) ".data" 'z ()))
          zs (? (bad? zg) 'bad (globs (rev (g 'statics)) ".data" 'z ()))
          ; .rodata: strings, jump tables, self-named globals and the 'r walk's consts -- nothing
          ; written at load or run (a pointer cannot ride: -pie slides it)
          rg (? (bad? zg || bad? zs) 'bad (globs (rev (g 'globs)) ".rodata" () ()))
          rs (? (bad? rg) 'bad (globs (rev (g 'statics)) ".rodata" () ()))
          cg (? (bad? rg || bad? rs) 'bad (globs (rev (g 'globs)) ".data" 'r ()))
          cs (? (bad? cg) 'bad (globs (rev (g 'statics)) ".data" 'r ()))
          nb (? (bad? cg || bad? cs) 'bad (globs (rev (g 'globs)) "love_nifs" () ()))
          ib (? (bad? nb) 'bad (globs (rev (g 'globs)) ".love.image" () ()))
          xb (? (bad? ib) 'bad
                (map (\ nm [nm (globs (rev (g 'globs)) nm () ()) (xro? nm)]) xnames))
          ; each switch's jump table: a label, then 4-byte self-relative entries (label differences, settled at link)
          jt (foldl (\ a p (a + [['align 4] ['label <p]] + [['raw <>p]]))
                    () (rev (g 'jtabs)))
          (? (foldl (\ a x (a || bad? x)) () [gb sb zg zs rg rs cg cs nb ib xb]) 'bad
             [(gb + sb) nb ib xb (zg + zs)
              (rg + rs + cg + cs + jt + strs (g 'strs) ())])))

   ; every nom in a form tree, pinned into a tablet: the dead-static sweep's reference relation,
   ; over-approximate on purpose (an opcode or a register name counts too; a miss is a wild jump)
   (cg-refs x t)
    (? (nom? x) (pin t x 1)
       !(two? x) t
       (cg-refs >x (cg-refs <x t)))
   ; the same relation over an AST, where a name is still text (laid forms wear the nom)
   (cg-srefs x t)
    (? (string? x) (pin t x 1)
       !(two? x) t
       (cg-srefs >x (cg-srefs <x t)))
   ; the shared core: the gen state, then text (no _start) and data -> (g textforms dataforms) | ().
   ; weaks never inline (a spliced body would bake past the linker's strong override); xtra is the parser's tablets, () reading as empties
   (cgen-core ast stbl sigs weaks xtra tgt)
    (: g {'n 0 'brk () 'brkm () 'cnt () 'cases () 'glob {} 'globs () 'strs () 'jtabs () 'statics ()
          'abl (ablenv 0)                           ; the pricing knob, read per unit at run time
          'laid {}                                  ; names already on 'globs (a tentative repeat lays no twin)
          'fns {} 'inl {} 'cgitems cgitems 'sxpre sxpre 'stag stbl 'sigs sigs
          'tgt tgt                                  ; (the epilogue is per fn: cgfn pins g 'epi)
          'sects (two? xtra ? <>>xtra {})
          'alias (two? xtra && 3 < #xtra ? (xtra 3) {})
          'aligns (two? xtra && 4 < #xtra ? (xtra 4) {})
          'consts (two? xtra && 7 < #xtra ? (xtra 7) {})
          ; the parser's restrict roster, fn -> its restrict param names; nothing reads it yet
          'rstrs (two? xtra && 8 < #xtra ? (xtra 8) {})
          ; file-scope `register T nm asm("R")` names: vent answers the register, nothing is laid
          'gregs (two? xtra && 10 < #xtra ? (xtra 10) {})
          'xfns ()                                  ; (secname forms) per fn that named a section, newest first
          'romemo {}}                               ; a const candidate's image, laid once and read by both walks
       ; pass 0: every fn name (the sig table too: an mproto sibling has a sig but no proto form),
       ; and the inline table -- always_inline at any size, noinline never
       ainls (two? xtra && 5 < #xtra ? (xtra 5))
       noinls (two? xtra && 6 < #xtra ? (xtra 6))
       ; -fno-inline outranks always_inline: the flag is an instrument
       nolin (two? xtra && 9 < #xtra ? (xtra 9))
       (recfns fs) (? !(two? fs) 1
                      (: f <fs
                         _ (elem <f '(fn proto) ? (pin (g 'fns) <>f 1))
                         _ (? (<f = 'fn && !nolin &&
                               !(elem <>f weaks) &&
                               !(elem <>f noinls) &&
                               inlok? f (peep sigs <>f ()) (elem <>f ainls))
                              (pin (g 'inl) <>f f))
                         (recfns >fs)))
       _ (recfns <>ast)
       _ (: (go ns) (? !(two? ns) 1 (pin (g 'fns) <ns 1, go >ns))
            (go (keys sigs)))
       ; an array declared []: parse spells the open bound 0, the one type a later decl may complete
       (openarr? ty) (two? ty && <ty = 'arr && <>>ty = 0)
       ; pass 1: every global, name -> (label ty init); cgimage validates the initializer at emission
       (rec fs)
        (? !(two? fs) 1
           (: f <fs
              (? !(elem <f '(gdecl xdecl)) (rec >fs)
                 (: xd (<f = 'xdecl)              ; extern: addressable, no storage laid
                    (one ps)
                     (? !(two? ps) (rec >fs)
                        (: p <ps
                           old (g 'glob <p)
                           ; the tentative rule (6.9.2): an initialized def wins the entry, a repeat lays no second
                           ; symbol; a complete type outranks an open [] (6.2.7), else it lays at size zero
                           _ (? (atom? old || two? <>>p || openarr? <>old && !(openarr? <>p))
                                (pin (g 'glob) <p [(name <p) <>p <>>p]) ())
                           _ (!xd && !(g 'laid <p) ? (pin (g 'laid) <p 1,
                                                      pin g 'globs (<p . g 'globs)))
                           (one >ps)))
                    (one <>f)))))
       ok (rec <>ast)
       ; -- lazy lowering: lay the roots (every exported fn, alias target, section-named fn, and every
       ; fn an initializer names), then what their laid forms still call, to closure; a spliced static's body ships only if named --
       (glay _)
        (: fnix {}                              ; fn name -> its AST form
           _ (foldl (\ _ f (? (<f = 'fn) (pin fnix <>f f, 0) 0)) 0 <>ast)
           unom {}                              ; the interned nom -> that name
           _ (foldl (\ _ nm (pin unom (name nm) nm, 0)) 0 (keys fnix))
           sfns (two? xtra ? <xtra {})
           als (g 'alias || {})
           atg (foldl (\ a k (als k . a)) () (keys als))
           (cut? nm) (peep sfns nm 'no != 'no && !(elem nm atg))
           ; two tablets: a truth test on a form list reads its net, which lands on zero, so presence is its own mark
           laid {}                              ; fn name -> 1 once its body is laid
           lfm {}                               ; ..and the forms, for the ones that stayed in .text
           ; lay one body -> the noms it still names; a refusal parks in 'genfail (the first cause stands)
           (lay1 nm)
            (: f (peep fnix nm ())
               _ (pins g 'undecl () 'nolane () 'arity ())   ; fresh per fn: the pins the refusal reads name this fn's cause
               r (cgfn g f)
               (? (bad? r)
                  (: u (g 'undecl)      ; rung 1: an undeclared id was named -> a gripe carrying it + the enclosing fn
                     nl (g 'nolane)     ; rung 4: a deliberate refusal named the feature it has no lane for
                     ar (g 'arity)      ; a direct call disagreeing with its own prototype
                     _ (? (gripe? (g 'genfail)) 0        ; the first cause stands
                          (pin g 'genfail
                               (? u (gripe () () () ("undeclared '" + u + "' (in " + nm + ")"))
                                  ar (gripe () () () (ar + (" (in " + nm + ")")))
                                  nl (gripe () () () (nl + (" (in " + nm + ")")))
                                  (gripe () () () ("cannot compile '" + nm + "' (cause unnamed)")))))
                     ())
                  ; align 2: the image codec tells a pointer from a fixnum by parity, so an odd fn address desyncs
                  ; a woken heap; wider measured slower (btb aliasing). alias labels ride inside the align, before the fn's own
                  (: al2 (: (go l a2) (? !(two? l) a2
                                         (go >l (? (g 'alias <l = nm)
                                                   (['label (name <l)] . a2) a2)))
                           (go (keys (g 'alias)) ()))
                     ; an aligned(N) fn, floored at 2 by the parity law
                     an (: a (peep (g 'aligns) nm 2) (? (a < 2) 2 a))
                     fm (['align an] . (al2 + r))
                     ; a fn that named its section leaves .text for that stream, its align riding out as the section's grain
                     sc (peep (g 'sects) nm ())
                     _ (nm = "main" ? (pin g 'saw 1))
                     _ (? sc (pin g 'xfns ([sc fm an] . g 'xfns)) (pin lfm nm fm))
                     _ (pin laid nm 1)          ; before the walk: a recursive fn names itself
                     (keys (cg-refs fm {})))))
           (drive q)
            (? (gripe? (g 'genfail) || !(two? q)) 0
               (: nm <q
                  (? (laid nm) (drive >q)
                     (drive (foldl (\ a x (: t (unom x) (t && !(laid t) ? (t . a) a)))
                                   >q (lay1 nm))))))
           ; the sectioned bodies first, in declaration order: a named section's layout is the program's
           ; (love.c reads a kind by dividing a sentinel's offset), and the worklist would tile them in discovery order
           (secs fs acc)
            (? (atom? fs || gripe? (g 'genfail)) acc
               (: f <fs
                  (? (<f = 'fn && g 'sects <>f && !(laid <>f))
                     (secs >fs (acc + (lay1 <>f)))
                     (secs >fs acc))))
           snoms (secs <>ast ())
           ; the roots in declaration order, so the layout is reproducible
           roots (: (go fs acc)
                     (fs @ (f . u) (go u (<f = 'fn && !(cut? <>f) ? (<>f . acc) acc)) (rev acc))
                    (go <>ast ()))
           ; what the sectioned bodies call joins the worklist like any other ref
           sq (foldl (\ a x (: t (unom x) (t && !(laid t) ? (t . a) a))) () snoms)
           _ (drive (roots + sq))
           ; the data lane's fn references, read off the initializers in g 'glob (block-scope statics
           ; included); a laid body can add its own, so this closes rather than passes
           (datclose _)
            (: t {}
               _ (foldl (\ _ k (: e (g 'glob k)
                                  (? (two? e) (cg-srefs <>>e t, 0) 0)))
                        0 (keys (g 'glob)))
               q (foldl (\ a s (? ((fnix s) && !(laid s)) (s . a) a))
                        () (keys t))
               (? (two? q && !(gripe? (g 'genfail))) (drive q, datclose 0) 0))
           _ (datclose 0)
           gf (g 'genfail)
           (? (gripe? gf) gf
              (: dat (cgdata g)
                 (? (bad? dat)
                    (: c (g 'datacause)   ; the static-data refusal, minted here (globs pinned it)
                       (gripe () () () (? c c "cannot lay the static data (cause unnamed)")))
                    ; txt builds reversed (a cat per fn is quadratic) and the rev restores order
                    (: _ (pin g 'dropped
                          (foldl (\ a f (<f = 'fn && !(laid <>f) ? (<>f . a) a)) () <>ast))
                       txt (foldl (\ a f (: u (<f = 'fn ? (lfm <>f))
                                          (two? u ? (revcat u a) a)))
                                  () <>ast)
                       [g (rev txt) dat (g 'saw)])))))
       (? ok (glay 0) ()))
   (cgen ast stbl sigs weaks xtra tgt)              ; the static executable: _start (crt0) + text + data -> (1 forms) | () -- needs main
    (: crt0 (? (= tgt 'a64)
               '((call main) (li r8 93) (sys))            ; x0 already the exit code; x8 = __nr_exit (93), svc
               (= tgt 'rv64)
               '((call main) (li r7 94) (sys))            ; a0 already the exit code; a7 = __nr_exit_group (94), ecall
               '((call main) (mov r6 r0) (li r0 60) (sys)))
       r (cgen-core ast stbl sigs weaks xtra tgt)
       (? (gripe? r) r                               ; a named cause rides out to the driver (a gripe is a chain, so guard before two?)
          !(two? r) ()
          !(r 3) ()                               ; no main -> no program (the exe has nothing to start)
          (: dat <>>r                           ; one flat image: nifs, rodata and bss (as real zeros) all ride the one lane
             [1 (crt0 + <>r + <>>>>>dat + <dat + <>dat + <>>>>dat)])))
   ; the relocatable object view: the .o emitter turns the names into a symbol table + relocations;
   ; the static fns ride as lnames (local func symbols, so nm/gdb see real boundaries)
   (cgen-obj ast stbl sigs weaks xtra tgt)          ; -> (1 textforms dataforms funcnames globnames nifforms imgforms lnames xsecs bssforms rodataforms xfnsecs) | ()
    (: r (cgen-core ast stbl sigs weaks xtra tgt)
       (? (gripe? r) r                               ; a named cause rides out (guard before two?, a gripe is a chain)
          !(two? r) ()
          (: sfns (two? xtra ? <xtra {})
             svars (two? xtra ? <>xtra {})
             sects (two? xtra ? <>>xtra {})
             (loc? nm) (!(= (peep svars nm 'no) 'no) ||
                        peep sects nm () = "love_nifs")     ; a nif entry is static by shape; any other
                                                                 ; named section stays exported (.image is read by symbol)
             als (? (two? xtra && 3 < #xtra) (xtra 3) {})
             fnames (: (go fs acc) (? !(two? fs) (rev acc)
                                      (: f <fs
                                         (go >fs (? (<f = 'fn && (= (peep sfns <>f 'no) 'no))
                                                         (<>f . acc) acc))))
                       ; an alias whose target is a function defined here is a
                       ; func symbol of its own, at the same address
                       defd (: (go2 fs acc) (? !(two? fs) acc
                                               (: f <fs
                                                  (go2 >fs (? (<f = 'fn) (<>f . acc) acc))))
                               (go2 <>ast ()))
                       (: base (go <>ast ())
                          (go3 l a2) (? !(two? l) a2
                                        (go3 >l (? (elem (als <l) defd) (<l . a2) a2)))
                          (base + go3 (keys als) ())))
             gnames (: (go gs acc) (? !(two? gs) (rev acc)
                                      (go >gs (? (loc? <gs) acc (<gs . acc))))
                       ; an alias onto a global (or a block-scope static) is an
                       ; object symbol of its own, at the same bytes
                       dgl (revcat (<r 'globs) $ rev (<r 'statics))
                       (: base (go (rev (<r 'globs)) ())
                          (go2 l a2) (? !(two? l) a2
                                        (go2 >l (? (elem (als <l) dgl) (<l . a2) a2)))
                          (base + go2 (keys als) ())))
             ; minus the swept: a local func symbol with no body would name whatever followed it
             gone (<r 'dropped)
             lnames (: (go fs acc) (? !(two? fs) (rev acc)
                                      (: f <fs
                                         (go >fs (? (<f = 'fn && !(= (peep sfns <>f 'no) 'no)
                                                     && !(elem <>f gone))
                                                         (<>f . acc) acc))))
                       (go <>ast ()))
             dat <>>r
             ; the sectioned fns folded to (name forms align) per section, in declaration order; the grain is the widest asked
             xfns (: (noms l acc) (? !(two? l) (rev acc)
                                     (noms >l (? (elem <<l acc) acc (<<l . acc))))
                     (forsec nm l) (: (go l2 a2) (? !(two? l2) a2
                                                    (go >l2 (? (<<l2 = nm) (a2 + <><l2) a2)))
                                      (go l ()))
                     (grain nm l) (: (go l2 a2) (? !(two? l2) a2
                                                   (go >l2 (? (<<l2 = nm && a2 < <>><l2)
                                                              <>><l2 a2)))
                                     (go l 16))
                     (: src (rev (<r 'xfns))
                        (map (\ nm [nm (forsec nm src) (grain nm src)]) (noms src ()))))
             [1 <>r <dat fnames gnames
                <>dat <>>dat lnames <>>>dat <>>>>dat <>>>>>dat
                xfns]))))
) ; module 'moon
