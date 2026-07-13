; crew/cc/gen.l -- the code generator (rung 3 stage 3). AST -> (1 ir-forms) |
; (). holo's neutral IR, chibicc-plain: every expression computes into r0 and
; now CARRIES ITS TYPE -- cgexpr answers (type forms) so pointer arithmetic
; scales, dereferences load by pointee width, and arrays decay to addresses.
; types: 'char 'short 'int 'long | ('ptr t) | ('arr t n). the ALU stays
; 64-bit (signed overflow is UB); widths bite only at memory and casts.
; lvalues have their own door (clval: the ADDRESS in r0 + the pointee type),
; so x, *p, and a[i] assign through one path. locals off the r4 frame;
; globals and string literals are LABELED RAW DATA after the code, reached
; by holo's (la) -- the one RWX segment carries text and data both until
; the .o seam (the doc). args ride the SysV registers r6 r5 r2 r1 r7 r8,
; at most six; call args evaluate left to right. stage 4b: a bare function
; name is its address (la); a call HEAD that is a function-pointer value goes
; through holo's (callr) after parking the callee in r3; a whole-struct assign
; is a word-then-byte block copy (bcopy). stage 4c: brace and designated
; initializers -- locals zero the slot then fill (cgfill, runtime values ok,
; nesting for arrays of structs), globals bake a constant byte image
; (cgimage; string-into-char-array and [] size inference included). stage 4d:
; a GLOBAL initializer whose value is a LABEL bakes an abs64 fixup ('fix 8
; abs64 label 0), the label's absolute load address -- char *s = "hi" (a
; rodata string), a static (name, fn-ptr) table (ai.c's nifs), &global,
; a decayed array. fenced and refused, not fudged: ptr+ptr, deref of a
; non-pointer, assigning to an array, struct params or returns by value.
; stage 6d: the `float` scalar (4 bytes in memory, but a value in an xmm
; register is ALWAYS a double -- a load widens, a store narrows), and the
; compound literal ('clit ty init), an unnamed object filled into a frame
; temp whose ADDRESS is the lvalue (so &(struct S){..} and (int){k} work).
(:
   ; the gen state g (a tablet): 'n the label counter, 'off the frame's
   ; high-water offset, 'brk/'cnt the loop label stacks, 'glob the global
   ; table (name -> (label ty init)), 'globs the emission order, 'strs the
   ; string table ((label . text)..). env: ((name off ty)..) frame locals.
   (nlab g pfx) (: k (peep g 'n 0) _ (pin g 'n (+ k 1)) (intern (+ pfx (show k))))
   argregs '(r6 r5 r2 r1 r7 r8)                      ; the SysV integer/pointer arg registers
   (xmmreg i) (intern (+ "f" (show i)))              ; the SysV double arg registers f0..f7
   (nthr l i) (? (< i 1) (cap l) (nthr (cup l) (- i 1)))
   (nthty l i) (? (! (two? l)) () (< i 1) (cap l) (nthty (cup l) (- i 1)))   ; the i-th list element or ()
   (bad? x) (id? x 'bad)
   ; -- the value tuple (the operand allocator's phase 0): every expression
   ; answers (ty reg forms) -- its type, the REGISTER holding the value, and
   ; the forms that compute it. reg is r0 on every lane until the allocator
   ; lands; the flo lane keeps the f0 protocol (its reg field is not consulted)
   ; and dispatches on vty as before. the accessors keep every consumer honest
   ; about which field it reads -- a (caup r) on a value tuple is a bug now. --
   (vty v) (cap v)
   (vreg v) (caup v)
   (vfs v) (cauup v)
   (mkv ty reg fs) (L ty reg fs)
   ; -- the operand pool (phase 1): an expression value may live in a home-pool
   ; register instead of riding the r0 protocol. g 'pool0 is the fn's whole set
   ; (opool minus any param homes -- cgfn pins it per build), g 'pool the free
   ; list, reset at every statement (values never cross one). ralloc answers a
   ; register | () (dry -> the caller keeps the shuttle); rfree is idempotent
   ; and ignores anything outside pool0 (r0, a borrowed home). a pool value
   ; NEVER lives across a call: pool registers are caller-saved and, unlike
   ; the homes, have no spill wrap -- the callish? gate holds that line. --
   opool '(r6 r5 r9 r10 r7 r8)
   (ralloc g) (: fr (peep g 'pool ())
                 (? (two? fr) (: _ (pin g 'pool (cup fr)) (cap fr)) ()))
   (rfree g r) (? (&& (member? r (peep g 'pool0 ()))
                      (! (member? r (peep g 'pool ()))))
                  (pin g 'pool (link r (peep g 'pool ()))) ())
   (wr? g r) (|| (id? r 'r0) (member? r (peep g 'pool0 ())))   ; writable: protocol r0 or an OWNED pool reg (a borrowed home is read-only)
   (callish? x) (? (! (two? x)) ()                             ; does the AST reach a call? (an inline splice still may)
                   (= (cap x) 'call) 1
                   (|| (callish? (cap x)) (callish? (cup x))))
   (tor0 g v)                                       ; land a value on the r0 protocol (frees its pool reg)
    (? (id? (vreg v) 'r0) (vfs v)
       (: fs (cat (vfs v) (L (L 'mov 'r0 (vreg v))))
          _ (rfree g (vreg v))
          fs))
   (vdrop g v) (: fs (vfs v) _ (rfree g (vreg v)) fs)   ; the value is DISCARDED: keep the effects, free the reg
   ; the result register for an op consuming rA: reuse a writable operand,
   ; else a fresh pool reg, else the protocol r0
   (rdst g rA) (? (wr? g rA) rA (: rX (ralloc g) (? rX rX 'r0)))
   ; -- the type floor (struct sizes come off the stag table riding in g) --
   (ptr? ty) (&& (two? ty) (= (cap ty) 'ptr))
   (arr? ty) (&& (two? ty) (= (cap ty) 'arr))
   (stru? ty) (&& (two? ty) (= (cap ty) 'struct))
   (fn? ty) (&& (two? ty) (= (cap ty) 'fn))         ; ('fn ret?) -- a function; decays to its address
   (fnty g nm) (: sig (peep (g 'sigs) nm ())        ; a named function's type, return riding when sig'd
                  (? (two? sig) (L 'fn (cap sig)) (L 'fn)))
   ; by-value aggregates (structs AND unions): a struct VALUE in cgexpr is its
   ; ADDRESS in r0; params/args/returns/results read the eightbytes through it.
   ; carried classes: one eightbyte ('int in a gp reg / 'sse in an xmm) and the
   ; two uniform 16-byte pairs -- '(sse sse) the xmm pair (ai.c's struct ai_zn,
   ; full lanes) and '(int int) rax:rdx (return/result lanes; int-pair args and
   ; params stay refused). MIXED 16-byte pairs and >16 bytes (MEMORY) refuse.
   ; the SysV eightbyte CLASSES of a small aggregate -- '(int) / '(sse) at <=8
   ; bytes, a two-symbol list at 9..16 -- or () (a scalar, an unsized tag, or
   ; >16 bytes: MEMORY class, still refused). an eightbyte is SSE only when
   ; every member overlapping it is float/double; any integer/pointer member
   ; wins it for INT. unions flatten to offset-0 fields (parse.l), so the same
   ; overlap walk classifies them -- a union of long and double is INT, like
   ; the ABI says. eightbyte moves ride full 8-byte loads/stores (a 1..7-byte
   ; tail reads its padding; frame temps and section interiors both hold it).
   (aclass g ty)
    (? (! (stru? ty)) ()
       (: se (peep (g 'stag) (caup ty) 0)
          (? (! (two? se)) ()
             (< 16 (caup se)) ()
             (: cls (tablet 0)
                (mark o c) (: i (>> o 3) old (peep cls i ())
                              (pin cls i (? (|| (id? old 'int) (id? c 'int)) 'int 'sse)))
                (walk o mty)
                 (? (flo? mty) (mark o 'sse)
                    (arr? mty)
                     (: esz (tsz g (caup mty))
                        (go i) (? (<= (cauup mty) i) 1
                                  (: _ (walk (+ o (* i esz)) (caup mty)) (go (+ i 1))))
                        (go 0))
                    (stru? mty)
                     (: e2 (peep (g 'stag) (caup mty) 0)
                        (? (! (two? e2)) 1 (fields o (cap e2))))
                    (mark o 'int))
                (fields o fs)
                 (? (! (two? fs)) 1
                    (: f (cap fs) _ (walk (+ o (caup f)) (cauup f)) (fields o (cup fs))))
                _ (fields 0 (cap se))
                (? (<= (caup se) 8) (L (peep cls 0 'int))
                   (L (peep cls 0 'int) (peep cls 1 'int)))))))
   (acls2 g ty ca cb) (: c (aclass g ty)
                         (&& (two? c) (&& (two? (cup c))
                             (&& (id? (cap c) ca) (id? (caup c) cb)))))
   (sse2? g ty) (acls2 g ty 'sse 'sse)       ; both eightbytes SSE: the xmm0:xmm1 pair
   (ipair? g ty) (acls2 g ty 'int 'int)      ; both INT: rax:rdx (return/result lanes)
   (aone g ty) (: c (aclass g ty) (? (&& (two? c) (! (two? (cup c)))) (cap c) ()))
   (fnret ty) (? (! (&& (two? ty) (= (cap ty) 'ptr))) 'long   ; an indirect callee's result type: ('ptr ('fn ret)) | 'long
                 (: ft (caup ty) (? (&& (fn? ft) (two? (cup ft))) (caup ft) 'long)))
   ; unsigned scalars ride 'uchar 'ushort 'uint 'ulong -- same WIDTH as their signed
   ; twin, but a load zero-extends, `>>` is logical, compare/divide go unsigned, and
   ; a binary op is unsigned if EITHER operand is (simplified usual conversions).
   (usg? ty) (member? ty '(uchar ushort uint ulong))
   (ubin ta tb) (? (|| (usg? ta) (usg? tb)) 'ulong 'long)
   (scc op unsg) (? (! unsg) op (= op 'lt) 'below (= op 'gt) 'above (= op 'le) 'be (= op 'ge) 'ae op)
   (rflip op) (? (= op 'lt) 'gt (= op 'gt) 'lt (= op 'le) 'ge (= op 'ge) 'le op)      ; MIRRORED (n < x reads x > n): constant-on-the-left
   (negrel op) (? (= op 'eq) 'ne (= op 'ne) 'eq (= op 'lt) 'ge (= op 'ge) 'lt (= op 'le) 'gt 'le)   ; NEGATED: branch-if-false
   (fits32? v) (&& (<= -2147483648 v) (<= v 2147483647))    ; holo's ALU/cmp/imul immediates ride le32
   (tsz g ty) (? (ptr? ty) 8
                 (arr? ty) (* (cauup ty) (tsz g (caup ty)))
                 (stru? ty) (caup (peep (g 'stag) (caup ty) 0))
                 (|| (= ty 'char) (= ty 'uchar)) 1 (|| (= ty 'short) (= ty 'ushort)) 2
                 (|| (= ty 'int) (|| (= ty 'uint) (= ty 'float))) 4 8)
   ; a member's (offset ty) off a struct type, | 'bad
   (fmem g ty name)
    (? (! (stru? ty)) 'bad
       (: e (peep (g 'stag) (caup ty) 0)
          (? (! (two? e)) 'bad
             (: f (assoc name (cap e))
                (? (two? f) (L (caup f) (cauup f)) 'bad)))))
   (lg2 n) (: (go k v) (? (<= v 1) k (go (+ k 1) (>> v 1))) (go 0 n))   ; a true log2 -- a pointer diff over a >8-byte struct needs sar 4+, not a capped 3
   (homable? pty) (|| (ptr? pty) (member? pty '(long ulong)))   ; an 8-byte gp scalar: what a register home can carry
   ; -- the immediate lane: the left value already in r0, a compile-time constant
   ; on the right -> ONE imm-form op (holo's add/sub/imul/and/or/xor/cmp take a
   ; signed-32 immediate), no operand-stack shuttle -- 6 insns and a memory
   ; round-trip fold to 1. a pointer +/- scales the constant at compile time; an
   ; UNSIGNED / or % by a power of two strength-reduces to shr/and (the b2w
   ; shape; signed stays a real div -- C rounds toward zero, sar toward -inf).
   ; answers (ty forms) | 'no (the caller falls back to the shuttle). --
   (pow2? n) (&& (< 0 n) (= 0 (& n (- n 1))))
   (lg2v n) (: (go k v) (? (<= v 1) k (go (+ k 1) (>> v 1))) (go 0 n))
   (immop g op av aty n wnt)                        ; av the LEFT value tuple; wnt the advisory destination
    (: rA (vreg av)
       (? (member? op '(eq ne lt le gt ge))
           (? (fits32? n)
              (: rd (? wnt wnt (rdst g rA))
                 fs (cat (vfs av) (L (L 'cmp rA n) (L 'set (scc op (|| (usg? aty) (ptr? aty))) rd)))
                 _ (? (id? rd rA) () (rfree g rA))
                 (mkv 'long rd fs))
              'no)
          (member? op '(/ %))
           (? (! (&& (usg? aty) (pow2? n))) 'no
              (= op '/) (? (= n 1) (mkv 'ulong rA (vfs av))
                           (? (wr? g rA)
                              (mkv 'ulong rA (cat (vfs av) (L (L 'shr rA (lg2v n)))))
                              (: rd (? wnt wnt (rdst g rA))   ; a borrowed home shifts a COPY (no 3-address shr)
                                 (mkv 'ulong rd (cat (vfs av) (L (L 'mov rd rA) (L 'shr rd (lg2v n))))))))
              (= n 1) (mkv 'ulong 'r0 (cat (vdrop g av) (L (L 'li 'r0 0))))
              (: rd (? wnt wnt (rdst g rA))
                 fs (cat (vfs av) (L (L 'and rd rA (- n 1))))
                 _ (? (id? rd rA) () (rfree g rA))
                 (mkv 'ulong rd fs)))
          (: sn (? (&& (ptr? aty) (member? op '(+ -))) (* n (tsz g (caup aty))) n)
             iop (? (= op '+) 'add (= op '-) 'sub (= op '*) 'imul
                    (= op '&) 'and (= op '|) 'or (= op '^) 'xor 'no)
             (? (id? iop 'no) 'no
                (! (fits32? sn)) 'no
                (: rt (? (ptr? aty) aty (ubin aty 'long))
                   (? (&& (= sn 0) (member? op '(+ -))) (mkv rt rA (vfs av))
                      (: rd (? wnt wnt (rdst g rA))
                         fs (cat (vfs av) (L (L iop rd rA sn)))
                         _ (? (id? rd rA) () (rfree g rA))
                         (mkv rt rd fs))))))))
   (ldop ty) (? (= ty 'char) 'ld1 (= ty 'short) 'ld2 (= ty 'int) 'ld4
                (= ty 'uchar) 'ldu1 (= ty 'ushort) 'ldu2 (= ty 'uint) 'ldu4 'ld)
   (stop ty) (? (|| (= ty 'char) (= ty 'uchar)) 'st1 (|| (= ty 'short) (= ty 'ushort)) 'st2
                (|| (= ty 'int) (= ty 'uint)) 'st4 'st)
   (cvt ty r) (? (= ty 'char) (L (L 'sx1 r)) (= ty 'short) (L (L 'sx2 r)) (= ty 'int) (L (L 'sx4 r))
                 (= ty 'uchar) (L (L 'zx1 r)) (= ty 'ushort) (L (L 'zx2 r)) (= ty 'uint) (L (L 'zx4 r)) ())
   ; -- the double lane (stage 6a, the gem): a 'double value lives in f0, not r0.
   ; its type is the flag; fbits is the compile-time IEEE-754 encoder; asflo/asint
   ; move a cgexpr result between the lanes (int<->double conversion); compares
   ; ride ucomisd's UNSIGNED flags, NaN-honest (the binop lane). --
   ; a float and a double share the register lane: a value in an xmm register is
   ; ALWAYS a 64-bit double; only MEMORY differs -- a `float` slot is 4 bytes, so
   ; a load widens (ldss + cvtss2sd) and a store narrows (cvtsd2ss + stss). fldf/
   ; fstf pick the lane by the DECLARED type; every loaded float types 'double.
   (flo? ty) (|| (= ty 'double) (= ty 'float))
   (fbits x)                                        ; finite double -> its IEEE-754 bits as the SIGNED i64 pattern
    (? (= x 0.0) 0                                  ; (the sign bit would make a BIG, and le8s/imnum walk i64 patterns)
       (: s (? (< x 0.0) 1 0) ax (? (< x 0.0) (- 0.0 x) x)
          eu ((: (go e) (? (<= ((+ e 1) 2.0) ax) (go (+ e 1)) e)) (int (/ (log ax) (log 2.0))))
          e  ((: (go e) (? (< ax (e 2.0)) (go (- e 1)) e)) eu)
          m (+ (* (+ e 1023) 4503599627370496)
               (int (* (- (/ ax (e 2.0)) 1.0) 4503599627370496.0)))
          (? (< 0 s) (- m 9223372036854775808) m)))
   (fbits32 x)                                      ; finite double -> its IEEE-754 SINGLE (u32) bits (a `float` image)
    (? (= x 0.0) 0
       (: s (? (< x 0.0) 1 0) ax (? (< x 0.0) (- 0.0 x) x)
          eu ((: (go e) (? (<= ((+ e 1) 2.0) ax) (go (+ e 1)) e)) (int (/ (log ax) (log 2.0))))
          e  ((: (go e) (? (< ax (e 2.0)) (go (- e 1)) e)) eu)
          (+ (* s 2147483648) (+ (* (+ e 127) 8388608)
             (int (* (- (/ ax (e 2.0)) 1.0) 8388608.0))))))
   (fldf ty freg base off)                          ; load a float/double from [base+off] into freg (widen if float)
    (? (= ty 'float) (L (L 'ldss freg base off) (L 'cvtss2sd freg freg))
       (L (L 'ldsd freg base off)))
   (fstf ty base off val)                           ; store val (a double in an xmm) to [base+off] as ty (narrow if float)
    (? (= ty 'float) (L (L 'cvtsd2ss 'f2 val) (L 'stss base off 'f2))    ; f2 the narrow scratch (val untouched)
       (L (L 'stsd base off val)))
   (asflo g r) (? (flo? (vty r)) (vfs r) (cat (tor0 g r) (L (L 'cvtsi2sd 'f0 'r0))))   ; result -> f0 as a double
   (asint g r) (? (flo? (vty r)) (cat (vfs r) (L (L 'cvttsd2si 'r0 'f0))) (tor0 g r))  ; result -> r0 as an int
   ; -- the environments: locals shadow globals --
   (vent g env name)                                ; -> ('regv rN ty) | ('loc off ty) | ('glo lbl ty) | 'bad
    (: e (assoc name env)
       (? (two? e)
           (: h (caup e)                             ; a homed param's "off" slot is a (reg rN) list;
              (? (&& (two? h) (= (cap h) 'reg)) (L 'regv (caup h) (cauup e))   ; a block-scope static's is (glob lbl)
                 (&& (two? h) (= (cap h) 'glob)) (L 'glo (caup h) (cauup e))
                 (L 'loc h (cauup e))))
          (: ge (peep (g 'glob) name 0)
             (? (two? ge) (L 'glo (cap ge) (caup ge)) 'bad))))
   ; a targetable LEAF re-emitted straight into register rX -> forms | 'no.
   ; leaves are PURE (no strs pin, no argpos), so discarding the r0 emission
   ; and re-aiming costs nothing; the narrow loads extend exactly like the
   ; r0 lanes. a homed param never lands here (its tuple already rides its
   ; home register, zero forms).
   (cgleaf g env e rX)
    (? (= (cap e) 'num) (L (L 'li rX (caup e)))
       (! (= (cap e) 'var)) 'no
       (: en (vent g env (caup e))
          (? (bad? en) 'no
             (! (= (cap en) 'loc)) 'no
             (: ty (cauup en)
                (? (|| (stru? ty) (|| (arr? ty) (flo? ty))) 'no
                   (L (L (ldop ty) rX 'r4 (caup en))))))))
   ; PARK the left operand out of r0 so the right may compute: a leaf re-aims
   ; at a fresh pool register (no protocol mov at all), anything else takes
   ; one mov. answers the (possibly re-homed) tuple | 'sh (pool dry -> the
   ; caller keeps the memory shuttle).
   (vpark g env e v)
    (? (! (id? (vreg v) 'r0)) v
       (: rX (ralloc g)
          (? (! rX) 'sh
             (: lf (cgleaf g env e rX)
                (? (! (id? lf 'no)) (mkv (vty v) rX lf)
                   (mkv (vty v) rX (cat (vfs v) (L (L 'mov rX 'r0)))))))))
   ; a truth value in r0 that `cmp r0 0` can test: a double folds to d != 0.0
   (ctest g env e)
    (: r (cgexpr g env e)
       (? (bad? r) 'bad
          (flo? (vty r))                             ; d != 0.0, NaN-honest: unordered is NONZERO (true), so `or` in the parity bit
           (mkv 'long 'r0 (cat (vfs r) (L (L 'li 'r1 0) (L 'movqxr 'f1 'r1) (L 'ucomisd 'f0 'f1)
                                          (L 'set 'ne 'r0) (L 'set 'p 'r1) (L 'or 'r0 'r0 'r1))))
          r))
   ; -- branch on a condition WITHOUT materializing its truth value: forms that
   ; jump to lbl when the condition is FALSE (cc 'eq) or TRUE (cc 'ne), the same
   ; sense as the fallback `(cmp r0 0) (br cc lbl)` over a ctest value. a
   ; comparison fuses to cmp + br<relation> (the cmp/set/movzx/cmp/br chain
   ; folds to cmp/br on EVERY if/while/for), !e flips the sense, && and ||
   ; short-circuit straight into the branch structure. the double lane stays
   ; materialized (ucomisd's NaN parity rides the set ops). forms | 'bad. --
   (cbranch g env e cc lbl)
    (? (&& (= (cap e) 'un) (= (caup e) 'not))
        (cbranch g env (cauup e) (? (= cc 'eq) 'ne 'eq) lbl)
       (= (cap e) 'land)
        (? (= cc 'eq)
           (: f1 (cbranch g env (caup e) 'eq lbl)
              f2 (cbranch g env (cauup e) 'eq lbl)
              (? (|| (bad? f1) (bad? f2)) 'bad (cat f1 f2)))
           (: lf (nlab g ".f")
              f1 (cbranch g env (caup e) 'eq lf)
              f2 (cbranch g env (cauup e) 'ne lbl)
              (? (|| (bad? f1) (bad? f2)) 'bad (cat f1 (cat f2 (L (L 'label lf)))))))
       (= (cap e) 'lor)
        (? (= cc 'ne)
           (: f1 (cbranch g env (caup e) 'ne lbl)
              f2 (cbranch g env (cauup e) 'ne lbl)
              (? (|| (bad? f1) (bad? f2)) 'bad (cat f1 f2)))
           (: lt (nlab g ".t")
              f1 (cbranch g env (caup e) 'ne lt)
              f2 (cbranch g env (cauup e) 'eq lbl)
              (? (|| (bad? f1) (bad? f2)) 'bad (cat f1 (cat f2 (L (L 'label lt)))))))
       (&& (= (cap e) 'bin) (member? (caup e) '(eq ne lt le gt ge)))
        (: op (caup e)
           lhs (cauup e) rhs (caup (cuup e))
           ; LAZY left-then-right: the left PARKS (allocates) before the right
           ; evaluates -- allocation order must match execution order, or the
           ; right's freed inner temps alias the parked left. a flo side falls
           ; back to ctest (both sides re-evaluate whole, the old shape).
           (fcb z9) (: c (ctest g env e)
                       (? (bad? c) 'bad (cat (vfs c) (L (L 'cmp 'r0 0) (L 'br cc lbl)))))
           (bcc o u) (scc (? (= cc 'ne) o (negrel o)) u)
           (cu2 ta tb) (|| (|| (usg? ta) (usg? tb)) (|| (ptr? ta) (ptr? tb)))
           (? (&& (= (cap rhs) 'num) (fits32? (caup rhs)))
               (: a (cgexpr g env lhs)
                  (? (bad? a) 'bad
                     (flo? (vty a)) (: _ (rfree g (vreg a)) (fcb ()))
                     (: fs (cat (vfs a) (L (L 'cmp (vreg a) (caup rhs)) (L 'br (bcc op (cu2 (vty a) 'long)) lbl)))
                        _ (rfree g (vreg a))
                        fs)))
              (&& (= (cap lhs) 'num) (fits32? (caup lhs)))
               (: b (cgexpr g env rhs)
                  (? (bad? b) 'bad
                     (flo? (vty b)) (: _ (rfree g (vreg b)) (fcb ()))
                     (: fs (cat (vfs b) (L (L 'cmp (vreg b) (caup lhs)) (L 'br (bcc (rflip op) (cu2 'long (vty b))) lbl)))
                        _ (rfree g (vreg b))
                        fs)))
              (: a (cgexpr g env lhs)
                 (? (bad? a) 'bad
                    (flo? (vty a)) (: _ (rfree g (vreg a)) (fcb ()))
                    (: ah (? (callish? rhs) 'sh (vpark g env lhs a))   ; a call on the right: memory only
                       (? (id? ah 'sh)
                           (: af (tor0 g a)
                              b (cgexpr g env rhs)
                              (? (bad? b) 'bad
                                 (flo? (vty b)) (: _ (rfree g (vreg b)) (fcb ()))
                                 (cat af (cat (spush 'r0) (cat (tor0 g b)
                                  (cat (spop 'r1) (L (L 'cmp 'r1 'r0) (L 'br (bcc op (cu2 (vty a) (vty b))) lbl))))))))
                          (: b (cgexpr g env rhs)
                             (? (bad? b) 'bad
                                (flo? (vty b)) (: _ (rfree g (vreg ah)) _ (rfree g (vreg b)) (fcb ()))
                                (: fs (cat (vfs ah) (cat (vfs b) (L (L 'cmp (vreg ah) (vreg b)) (L 'br (bcc op (cu2 (vty ah) (vty b))) lbl))))
                                   _ (rfree g (vreg ah)) _ (rfree g (vreg b))
                                   fs)))))))))
       (: c (ctest g env e)
          (? (bad? c) 'bad
             (: fs (cat (vfs c) (L (L 'cmp (vreg c) 0) (L 'br cc lbl)))
                _ (rfree g (vreg c))
                fs))))
   ; 8 little-endian bytes of a constant (the global initializer image)
   (le8s v) (: (go i acc) (? (< 7 i) (rev acc)
                             (go (+ i 1) (link (& (>> v (* 8 i)) 255) acc)))
              (go 0 ()))
   (le4s v) (: (go i acc) (? (< 3 i) (rev acc)
                             (go (+ i 1) (link (& (>> v (* 8 i)) 255) acc)))
              (go 0 ()))
   (zeros n) (? (< n 1) () (link 0 (zeros (- n 1))))
   ; a straight-line block copy of sz bytes, src address in r0, dest in r1,
   ; r2 the scratch -- 8 at a time, then a byte tail (struct = struct copies)
   (bcopy off sz acc)
    (? (<= 8 sz) (bcopy (+ off 8) (- sz 8)
                  (cat acc (L (L 'ld 'r2 'r0 off) (L 'st 'r1 off 'r2))))
       (< 0 sz) (bcopy (+ off 1) (- sz 1)
                  (cat acc (L (L 'ld1 'r2 'r0 off) (L 'st1 'r1 off 'r2))))
       acc)
   ; a spill that HOLDS a value across a nested sub-eval (which may itself contain
   ; a call). a bare `push` is 8 bytes and would leave rsp at 8 mod 16 while the
   ; inner call runs -- a SysV alignment violation that glibc's fork child path
   ; (movaps on rbp-relative slots) turns into a #GP. reserve a whole 16-byte cell
   ; so rsp stays 16-aligned through the sub-eval; the callee cleans it as a pair.
   (spush r) (L (L 'sub 'sp 'sp 16) (L 'st 'sp 0 r))
   (spop r)  (L (L 'ld r 'sp 0) (L 'add 'sp 'sp 16))

   ; a fresh frame temp of type ty -> its (negative) offset. bumps the frame's
   ; high-water like a local; used to give a compound literal a home.
   (ntmp g ty) (: span (& (+ (tsz g ty) 7) -8)
                  off (- 0 (+ (peep g 'off 0) span))
                  _ (pin g 'off (+ (peep g 'off 0) span))
                  off)
   ; load a value from the address in r0, by type -- the deref/clit value tail
   ; (arrays and functions decay to the address; a struct has no register value)
   (loadval ty addrf)
    (? (arr? ty) (mkv (L 'ptr (caup ty)) 'r0 addrf)
       (fn? ty) (mkv (L 'ptr ty) 'r0 addrf)
       (stru? ty) (mkv ty 'r0 addrf)                 ; a struct value IS its address (the pair reps read through it)
       (flo? ty) (mkv 'double 'r0 (cat addrf (fldf ty 'f0 'r0 0)))
       (mkv ty 'r0 (cat addrf (L (L (ldop ty) 'r0 'r0 0)))))
   ; the fill code for a compound literal at frame offset off: an aggregate zeroes
   ; then fills (cgfill), a scalar unwraps its single-element brace and stores.
   (clitcode g env off ty ini)
    (? (|| (arr? ty) (stru? ty))
        (: f (cgfill g env off ty ini)
           (? (bad? f) 'bad (cat (cgzero off (& (+ (tsz g ty) 7) -8)) f)))
       (: v (? (&& (two? ini) (= (cap ini) 'init))
               (? (two? (caup ini)) (cap (caup ini)) (L 'num 0)) ini)
          (cgstore g env off ty v)))

   ; -- lvalues: the ADDRESS lands in r0; answers (pointee-ty forms) | 'bad --
   (clval g env e)
    (: k (cap e)
       (? (= k 'var)
           (: en (vent g env (caup e))
              (? (bad? en) 'bad
                 (= (cap en) 'regv) 'bad             ; a register home has no address (& is gated out per-fn)
                 ; lean, not lea: an lvalue's address is CONSUMED by its own
                 ; load/store -- the sibcall escape gate must not see it. the
                 ; & lane flips it back to lea (there it really escapes).
                 (= (cap en) 'loc) (mkv (cauup en) 'r0 (L (L 'lean 'r0 'r4 (caup en))))
                 (mkv (cauup en) 'r0 (L (L 'la 'r0 (caup en))))))
          (= k 'deref)
           (: r (cgexpr g env (caup e))
              (? (bad? r) 'bad
                 (! (ptr? (vty r))) 'bad
                 (mkv (caup (vty r)) 'r0 (tor0 g r))))
          (= k 'dot)
           (: r (: lv (clval g env (caup e))
                   ; an rvalue struct base (a call's parked temp: `mk(x).a`) is
                   ; its address too -- same license the asn lane rides
                   (? (! (bad? lv)) lv
                      (: rv (cgexpr g env (caup e))
                         (? (bad? rv) 'bad (! (stru? (vty rv))) 'bad rv))))
              (? (bad? r) 'bad
                 (: fm (fmem g (vty r) (cauup e))
                    (? (bad? fm) 'bad
                       (mkv (caup fm) 'r0
                            (cat (vfs r)
                                 (? (= (cap fm) 0) () (L (L 'add 'r0 'r0 (cap fm))))))))))
          (= k 'clit)                               ; a compound literal is an lvalue: fill a temp, address it
           (: ty (caup e) ini (caup (cup e))
              off (ntmp g ty)
              fill (clitcode g env off ty ini)
              (? (bad? fill) 'bad
                 (mkv ty 'r0 (cat fill (L (L 'lea 'r0 'r4 off))))))   ; a real lea: the temp's address is the value (& pins via the addr lane, a call blocks via the window)
          'bad))

   ; -- expressions: answers a value tuple | 'bad. g 'want is the DESTINATION
   ; HINT: pinned by a consumer that knows where the value must land (an asn
   ; into a home, a ret's r0), consumed by the TOP node only (cleared here, so
   ; subexpressions never inherit it), and always ADVISORY -- a lane that
   ; ignores it answers its usual register and the consumer bridges. --
   (cgexpr g env e)
    (: wnt (peep g 'want ())
       _ (pin g 'want ())
       k (cap e)
       (? (= k 'szof)                                   ; sizeof EXPR: the UNDECAYED type (clval keeps arrays), size a constant
           (: e2 (caup e)
              lv (clval g env e2)
              ty (? (bad? lv) (: r (cgexpr g env e2) (? (bad? r) 'bad (: _ (rfree g (vreg r)) (vty r)))) (vty lv))
              (? (bad? ty) 'bad (mkv 'ulong 'r0 (L (L 'li 'r0 (tsz g ty))))))
          (= k 'num) (: W (? wnt wnt 'r0) (mkv 'long W (L (L 'li W (caup e)))))
          (= k 'flo) (mkv 'double 'r0 (L (L 'li 'r0 (fbits (caup e))) (L 'movqxr 'f0 'r0)))
          (= k 'str)
           (: lbl (nlab g ".S")
              _ (pin g 'strs (link (L lbl (caup e)) (g 'strs)))
              (mkv (L 'ptr 'char) 'r0 (L (L 'la 'r0 lbl))))
          (= k 'dot)
           (: r (clval g env e)
              (? (bad? r) 'bad
                 (: ty (vty r)
                    (? (arr? ty) (mkv (L 'ptr (caup ty)) 'r0 (vfs r))
                       (fn? ty) (mkv (L 'ptr ty) 'r0 (vfs r))     ; a fn-pointer member is its address
                       (stru? ty) (mkv ty 'r0 (vfs r))    ; a struct member's value is its address (the sse2 rep)
                       (flo? ty) (mkv 'double 'r0 (cat (vfs r) (fldf ty 'f0 'r0 0)))
                       (mkv ty 'r0 (cat (vfs r) (L (L (ldop ty) 'r0 'r0 0))))))))
          (= k 'var)
           (: en (vent g env (caup e))
              (? (bad? en)
                  (? (peep (g 'fns) (caup e) ())     ; a function name is its address
                     (mkv (L 'ptr (fnty g (caup e))) 'r0 (L (L 'la 'r0 (intern (caup e))))) 'bad)
                 (= (cap en) 'regv) (mkv (cauup en) (caup en) ())   ; a homed param IS its register: zero forms, borrowed (read-only)
                 (: ty (cauup en)
                    ap? (peep g 'argpos ())
                    _ (? (|| (stru? ty) (arr? ty)) (pin g 'argpos ()) ())
                    (? (stru? ty)                    ; a struct value is its ADDRESS (the sse2 rep)
                        (? (= (cap en) 'loc)
                           (: v (mkv ty 'r0 (L (L 'lea 'r0 'r4 (caup en)))) (? ap? v (escan g v)))
                           (mkv ty 'r0 (L (L 'la 'r0 (caup en)))))
                       (arr? ty)                     ; arrays decay to their address
                        (? (= (cap en) 'loc)
                           (: v (mkv (L 'ptr (caup ty)) 'r0 (L (L 'lea 'r0 'r4 (caup en)))) (? ap? v (escan g v)))
                           (mkv (L 'ptr (caup ty)) 'r0 (L (L 'la 'r0 (caup en)))))
                       (flo? ty)                     ; a float/double loads into f0 (widened if float)
                        (? (= (cap en) 'loc)
                           (mkv 'double 'r0 (fldf ty 'f0 'r4 (caup en)))
                           (mkv 'double 'r0 (cat (L (L 'la 'r1 (caup en))) (fldf ty 'f0 'r1 0))))
                       (? (= (cap en) 'loc)
                          (: W (? wnt wnt 'r0)
                             (mkv ty W (L (L (ldop ty) W 'r4 (caup en)))))
                          (mkv ty 'r0 (L (L 'la 'r1 (caup en)) (L (ldop ty) 'r0 'r1 0))))))))
          (= k 'addr)
           (: r (clval g env (caup e))
              ap? (peep g 'argpos ())
              _ (pin g 'argpos ())
              (? (! (bad? r))                        ; under & the lvalue's address ESCAPES: flip its leans to leas
                 (: v (mkv (L 'ptr (vty r)) 'r0 (unlean (vfs r))) (? ap? v (escan g v)))
                 ; &f on a function name: same address as the bare use (no lvalue).
                 ; a VARIABLE of the same name shadows it -- a homed param's regv
                 ; lands here as 'bad and must DEOPT, not read &libm-exp (vent!)
                 (&& (= (cap (caup e)) 'var)
                     (&& (bad? (vent g env (caup (caup e))))
                         (peep (g 'fns) (caup (caup e)) ())))
                  (mkv (L 'ptr (fnty g (caup (caup e)))) 'r0 (L (L 'la 'r0 (intern (caup (caup e))))))
                 'bad))
          (= k 'deref)
           (: r (clval g env e)                     ; clval already walked the pointer
              (? (bad? r) 'bad
                 (: ty (vty r)
                    (? (arr? ty) (mkv (L 'ptr (caup ty)) 'r0 (vfs r))   ; pointee array: decay again
                       (fn? ty) (mkv (L 'ptr ty) 'r0 (vfs r))           ; *fp -- a function is its address
                       (stru? ty) (mkv ty 'r0 (vfs r))                  ; *p as a struct value: the address rides
                       (flo? ty) (mkv 'double 'r0 (cat (vfs r) (fldf ty 'f0 'r0 0)))
                       (mkv ty 'r0 (cat (vfs r) (L (L (ldop ty) 'r0 'r0 0))))))))
          (= k 'asn)
           (: rv (? (= (cap (caup e)) 'var) (vent g env (caup (caup e))) 'bad)
              (? (&& (two? rv) (= (cap rv) 'regv))   ; store into a register-homed scalar (param or local)
                  (: _ (pin g 'want (caup rv))         ; hint the rhs straight at the home
                     r (cgexpr g env (cauup e))
                     (? (bad? r) 'bad
                        (flo? (vty r)) (mkv (cauup rv) 'r0 (cat (asint g r) (L (L 'mov (caup rv) 'r0))))
                        (id? (vreg r) (caup rv)) (mkv (cauup rv) (caup rv) (vfs r))   ; landed in the home already
                        (: fs (cat (vfs r) (L (L 'mov (caup rv) (vreg r))))   ; straight from the value's register
                           _ (rfree g (vreg r))
                           (mkv (cauup rv) (caup rv) fs))))
                 ; STORE-DIRECT: a plain variable target's address is STATIC (a
                 ; frame offset or a label) -- the value stores from wherever it
                 ; sits, no lean/spush/spop shuttle around it
                 (&& (two? rv) (&& (member? (cap rv) '(loc glo))
                     (: ty9 (cauup rv) (! (|| (stru? ty9) (|| (arr? ty9) (flo? ty9)))))))
                  (: ty (cauup rv)
                     r (cgexpr g env (cauup e))
                     (? (bad? r) 'bad
                        (two? (cvt ty 'r0))              ; a narrow target converts on the protocol
                         (mkv ty 'r0 (cat (tor0 g r)
                                      (cat (cvt ty 'r0)
                                           (? (= (cap rv) 'loc)
                                              (L (L (stop ty) 'r4 (caup rv) 'r0))
                                              (L (L 'la 'r1 (caup rv)) (L (stop ty) 'r1 0 'r0))))))
                        (= (cap rv) 'loc)
                         (mkv ty (vreg r) (cat (vfs r) (L (L 'st 'r4 (caup rv) (vreg r)))))
                        (mkv ty (vreg r) (cat (vfs r) (L (L 'la 'r1 (caup rv)) (L 'st 'r1 0 (vreg r)))))))
                 (: lv (clval g env (caup e))
              (? (bad? lv) 'bad
                 (arr? (vty lv)) 'bad                ; an array is not assignable
                 (stru? (vty lv))                    ; a whole-struct copy (dest r1, src r0)
                  (: rl (clval g env (cauup e))      ; an rvalue struct (a call's temp) is its address too
                     rv (? (bad? rl) (cgexpr g env (cauup e)) rl)
                     (? (bad? rv) 'bad
                        (! (stru? (vty rv))) 'bad
                        (mkv (vty lv) 'r0
                           (cat (vfs lv) (cat (spush 'r0)
                            (cat (tor0 g rv) (cat (spop 'r1)
                             (bcopy 0 (tsz g (vty lv)) ()))))))))
                 (flo? (vty lv))                     ; a float/double store (addr in r1, value in f0; narrow if float)
                  (: r (cgexpr g env (cauup e))
                     (? (bad? r) 'bad
                        (mkv 'double 'r0 (cat (vfs lv) (cat (spush 'r0)
                         (cat (asflo g r) (cat (spop 'r1) (fstf (vty lv) 'r1 0 'f0))))))))
                 (: r (cgexpr g env (cauup e))
                    (? (bad? r) 'bad
                       (: ty (vty lv)
                          (mkv ty 'r0 (cat (vfs lv)
                                 (cat (spush 'r0)
                                  (cat (asint g r)
                                   (cat (spop 'r1)
                                    (cat (cvt ty 'r0)
                                         (L (L (stop ty) 'r1 0 'r0)))))))))))))))
          (= k 'post)
           (: rv (? (= (cap (caup e)) 'var) (vent g env (caup (caup e))) 'bad)
              (? (&& (two? rv) (= (cap rv) 'regv))   ; p++ on a register-homed scalar: old in r0, home += step
                  (: ty (cauup rv) stp (? (ptr? ty) (tsz g (caup ty)) 1)
                     (mkv ty 'r0 (L (L 'mov 'r0 (caup rv))
                                    (L 'add (caup rv) 'r0 (* stp (cauup e))))))
                 (: lv (clval g env (caup e))
              (? (bad? lv) 'bad
                 (: ty (vty lv)
                    stp (? (ptr? ty) (tsz g (caup ty)) 1)
                    (? (arr? ty) 'bad
                       (mkv ty 'r0 (cat (vfs lv)
                              (L (L 'mov 'r2 'r0)
                                 (L (ldop ty) 'r0 'r2 0)
                                 (L 'add 'r1 'r0 (* stp (cauup e)))
                                 (L (stop ty) 'r2 0 'r1))))))))))
          (= k 'cast)
           (: tgt (caup e)
              _ (? (&& (! (flo? tgt)) (! (two? (cvt tgt 'r0)))) (pin g 'want wnt) ())
              r (cgexpr g env (cauup e))
              (? (bad? r) 'bad
                 (&& (flo? tgt) (! (flo? (vty r)))) (mkv 'double 'r0 (asflo g r))  ; int -> double
                 (&& (! (flo? tgt)) (flo? (vty r)))                              ; double -> int, then narrow
                  (mkv tgt 'r0 (cat (asint g r) (cvt tgt 'r0)))
                 (flo? tgt) (mkv 'double 'r0 (vfs r))                            ; double -> double
                 (two? (cvt tgt 'r0)) (mkv tgt 'r0 (cat (tor0 g r) (cvt tgt 'r0)))   ; int -> narrower int
                 (mkv tgt (vreg r) (vfs r))))                                    ; a full-word int cast KEEPS the register
          (= k 'un)
           (: r (cgexpr g env (cauup e))
              (? (bad? r) 'bad
                 (flo? (vty r))                        ; unary on a double
                  (? (= (caup e) 'neg)                 ; -d = 0.0 - d
                      (mkv 'double 'r0 (cat (vfs r) (L (L 'li 'r0 0) (L 'movqxr 'f1 'r0)
                                                       (L 'subsd 'f1 'f0) (L 'movsd 'f0 'f1))))
                     (= (caup e) 'not)                 ; !d = (d == 0.0), NaN-honest: !NaN is false (eq AND ordered)
                      (mkv 'long 'r0 (cat (vfs r) (L (L 'li 'r0 0) (L 'movqxr 'f1 'r0)
                                                     (L 'ucomisd 'f0 'f1) (L 'set 'eq 'r0)
                                                     (L 'set 'np 'r1) (L 'and 'r0 'r0 'r1))))
                     'bad)                             ; ~ on a double is invalid
                 ; -1ULL stays unsigned; a SUB-64 unsigned re-narrows after
                 ; neg/~ (the model keeps unsigned intermediates canonically
                 ; zero-extended: -1u must wrap at 32 bits, not ride 64)
                 (: uty (&& (member? (caup e) '(neg bnot)) (usg? (vty r)))
                    renar (? (! uty) () (= (vty r) 'uchar) (L (L 'zx1 'r0))
                             (= (vty r) 'ushort) (L (L 'zx2 'r0))
                             (= (vty r) 'uint) (L (L 'zx4 'r0)) ())
                    (mkv (? uty (vty r) 'long) 'r0
                       (cat (tor0 g r)
                            (cat (? (= (caup e) 'neg) (L (L 'neg 'r0))
                                    (= (caup e) 'bnot) (L (L 'not 'r0))
                                    (L (L 'cmp 'r0 0) (L 'set 'eq 'r0)))
                                 renar))))))
          (= k 'comma)
           (: a (cgexpr g env (caup e))
              _ (pin g 'want wnt)
              b (cgexpr g env (cauup e))
              (? (|| (bad? a) (bad? b)) 'bad
                 (mkv (vty b) (vreg b) (cat (vdrop g a) (vfs b)))))
          (= k 'land)                                ; as a VALUE: cbranch the short-circuit, then settle the bit
           (: lf (nlab g ".f") ld (nlab g ".d")
              f (cbranch g env e 'eq lf)
              (? (bad? f) 'bad
                 (mkv 'long 'r0 (cat f (L (L 'li 'r0 1) (L 'jmp ld)
                                          (L 'label lf) (L 'li 'r0 0) (L 'label ld))))))
          (= k 'lor)
           (: lt (nlab g ".t") ld (nlab g ".d")
              f (cbranch g env e 'ne lt)
              (? (bad? f) 'bad
                 (mkv 'long 'r0 (cat f (L (L 'li 'r0 0) (L 'jmp ld)
                                          (L 'label lt) (L 'li 'r0 1) (L 'label ld))))))
          (= k 'cond)
           (: le (nlab g ".e") ld (nlab g ".d")
              c (cbranch g env (caup e) 'eq le)
              t (cgexpr g env (cauup e))
              el (cgexpr g env (caup (cuup e)))
              (? (|| (bad? c) (|| (bad? t) (bad? el))) 'bad
                 ; C's conditional CONVERTS its arms: one flo arm makes the whole
                 ; result flo, so the INTEGER arm rides asflo at its edge -- typing
                 ; by the then-arm alone left `(Cp(a) ? im(a) : 0)`'s int 0 in r0
                 ; while the reader took f0 (the eq lane's charm×twin face).
                 (: fl (|| (flo? (vty t)) (flo? (vty el)))
                    tf (? fl (asflo g t) (tor0 g t))
                    ef (? fl (asflo g el) (tor0 g el))
                    rt (? (flo? (vty t)) (vty t) (? fl (vty el) (vty t)))
                    (mkv rt 'r0
                       (cat c
                        (cat tf (cat (L (L 'jmp ld) (L 'label le))
                         (cat ef (L (L 'label ld))))))))))
          ; -- the varargs builtins (the SysV ABI). a va_list is the 24-byte struct
          ; { int gp_offset; int fp_offset; void *overflow_arg_area; void
          ; *reg_save_area; } (crew/cc/include/stdarg.h). va_start seeds it past the
          ; named params; va_arg fetches from the register save area until its
          ; offset passes the reg limit, then from the overflow (stack) area,
          ; stepping the offset; va_end nops. --
          (= k 'vastart)
           ; cgexpr (not clval) gives the struct pointer uniformly: a va_list LOCAL
           ; (array) decays to its address, a va_list PARAM (a decayed pointer)
           ; loads its value -- both land the struct address in r0.
           (: lv (cgexpr g env (caup e))                 ; the va_list struct pointer in r0
              rsa (peep g 'rsa 0) ngp (peep g 'vagp 0) nxmm (peep g 'vaxmm 0)
              (? (bad? lv) 'bad
                 (: _ (pin g 'fesc 1)                                       ; the va_list HOLDS frame addresses: no sibcalls here
                    (mkv 'long 'r0 (cat (tor0 g lv)
                      (L (L 'li 'r1 (* 8 ngp))         (L 'st4 'r0 0 'r1)   ; gp_offset = 8*named-gp
                         (L 'li 'r1 (+ 48 (* 16 nxmm))) (L 'st4 'r0 4 'r1)  ; fp_offset = 48 + 16*named-xmm
                         (L 'lea 'r1 'r4 16)  (L 'st 'r0 8 'r1)             ; overflow_arg_area = rbp+16
                         (L 'lea 'r1 'r4 rsa) (L 'st 'r0 16 'r1)))))))       ; reg_save_area = rbp+rsa
          (= k 'vaarg)
           (: lv (cgexpr g env (caup e)) ty (cauup e)    ; the va_list struct pointer in r0
              lov (nlab g ".vo") ld (nlab g ".vd")
              foff (? (flo? ty) 4 0)                      ; the offset field: fp_offset (4) vs gp_offset (0)
              lim (? (flo? ty) 176 48)                    ; the register-area limit
              step (? (flo? ty) 16 8)                     ; the offset stride
              ; r1 = the relevant offset; if it is below the limit, p = reg_save_area
              ; + offset and the offset advances; else p = overflow, which advances 8.
              walk (L (L 'ld4 'r1 'r0 foff) (L 'cmp 'r1 lim) (L 'br 'ge lov)
                      (L 'ld 'r2 'r0 16) (L 'add 'r2 'r2 'r1)            ; p = reg_save_area + offset
                      (L 'add 'r1 'r1 step) (L 'st4 'r0 foff 'r1)         ; advance the offset
                      (L 'jmp ld) (L 'label lov)
                      (L 'ld 'r2 'r0 8) (L 'mov 'r3 'r2) (L 'add 'r3 'r3 8) (L 'st 'r0 8 'r3)   ; p = overflow; overflow += 8
                      (L 'label ld))
              (? (bad? lv) 'bad
                 (flo? ty) (mkv 'double 'r0 (cat (tor0 g lv) (cat walk (fldf ty 'f0 'r2 0))))
                 (mkv ty 'r0 (cat (tor0 g lv) (cat walk (L (L (ldop ty) 'r0 'r2 0)))))))
          (= k 'vaend) (mkv 'long 'r0 ())
          (= k 'call)
           ; the SysV ABI: integer/pointer args ride r6 r5 r2 r1 r7 r8 (<=6),
           ; double args ride f0..f7 (<=8), SEPARATE counters, placed by the
           ; callee's PARAM type (a direct call reads the sig table -- converting
           ; the arg to it), else by the arg's own type. the result rides f0 for
           ; a double-returning callee, r0 otherwise. args evaluate left to right,
           ; each pushed to the machine stack, then popped reversed into place.
           (: head (caup e) args (cauup e)
              bi (? (= (cap head) 'var) (caup head) ())
              (? ; the gcc builtins ai.c reaches, each a short raw-x64 splice:
                 ; trap = ud2; inf/nanf = IEEE constants into f0; expect = its value
                 ; (the hint drops); clear_cache = nothing (x86 I-cache is coherent);
                 ; clzll = bsr then xor 63 (63-x == 63^x on 0..63; 0 is the caller's
                 ; UB, as in gcc); isinf = bits<<1 == inf<<1; the overflow trio = the
                 ; op + seto, result stored through arg3, the flag the value.
                 (= bi "__builtin_trap") (mkv 'long 'r0 (L (L 'raw (L 15 11))))
                 (= bi "__builtin_inf")  (mkv 'double 'r0 (L (L 'li 'r0 9218868437227405312) (L 'movqxr 'f0 'r0)))
                 (|| (= bi "__builtin_nanf") (= bi "__builtin_nan"))   ; both take a (ignored) tag string; one quiet-NaN pattern
                  (mkv 'double 'r0 (L (L 'li 'r0 9221120237041090560) (L 'movqxr 'f0 'r0)))
                 (= bi "__builtin_expect") (cgexpr g env (cap args))
                 (= bi "__builtin___clear_cache") (mkv 'long 'r0 ())
                 (= bi "__builtin_clzll")
                  (: e1 (cgexpr g env (cap args))
                     (? (bad? e1) 'bad
                        (mkv 'long 'r0 (cat (asint g e1) (L (L 'raw (L 72 15 189 192 72 131 240 63)))))))   ; bsr rax,rax; xor rax,63
                 (= bi "__builtin_isinf")
                  (: e1 (cgexpr g env (cap args))
                     (? (bad? e1) 'bad
                        (mkv 'long 'r0 (cat (asflo g e1)
                                  (cat (L (L 'movqrx 'r0 'f0) (L 'raw (L 72 209 224)) (L 'li 'r1 18437736874454810624))   ; shl rax,1; rcx = inf<<1
                                       (L (L 'raw (L 72 57 200 15 148 192 72 15 182 192))))))))     ; cmp; sete al; movzx rax,al
                 (member? bi '("__builtin_add_overflow" "__builtin_sub_overflow" "__builtin_mul_overflow"))
                  (: e1 (cgexpr g env (cap args))
                     e2 (cgexpr g env (caup args))
                     ; the &t arg is consumed by the splice's own store -- argpos,
                     ; like a call arg (else every overflow user loses sibcalls)
                     e3 (: _ (? (member? (cap (cauup args)) '(addr var)) (pin g 'argpos 1) ())
                           (cgexpr g env (cauup args)))
                     _ (pin g 'argpos ())
                     opb (? (= bi "__builtin_add_overflow") (L 72 1 200)      ; add rax,rcx
                            (= bi "__builtin_sub_overflow") (L 72 41 200)     ; sub rax,rcx
                            (L 72 15 175 193))                                ; imul rax,rcx
                     (? (|| (bad? e1) (|| (bad? e2) (bad? e3))) 'bad
                        (mkv 'long 'r0 (cat (asint g e1) (cat (spush 'r0)
                                  (cat (asint g e2) (cat (spush 'r0)
                                   (cat (tor0 g e3) (cat (cat (L (L 'mov 'r3 'r0)) (cat (spop 'r1) (spop 'r0)))
                                    (cat (L (L 'raw (cat opb (L 15 144 193 72 15 182 201))))          ; seto cl; movzx rcx,cl
                                         (L (L 'st 'r3 0 'r0) (L 'mov 'r0 'r1))))))))))))
                 (: inlf (? (peep g 'inlining ()) ()
                            (! (= (cap head) 'var)) ()
                            (! (bad? (vent g env (caup head)))) ()   ; a local/global shadows the name
                            (peep (g 'inl) (caup head) ()))
                    ir9 (? (&& (two? inlf) (= (tally args) (tally (cauup inlf))))
                           (cginl g env inlf args) 'no)              ; 'no: splice declined (fesc or shape) -> the real call
                    (? (! (id? ir9 'no)) ir9
                 (: direct (&& (= (cap head) 'var)
                               (&& (bad? (vent g env (caup head)))                ; not a local/global variable...
                                   (peep (g 'fns) (caup head) ())))               ; ...and a KNOWN function (typos refuse)
                    sig (? direct (peep (g 'sigs) (caup head) ()) ())
                    ptys (? (two? sig) (caup sig) ())
                    rt (? (two? sig) (cap sig) 'long)
                    variadic (? (two? sig) (nthr sig 2) ())
                    ; every call rides the SysV registers (call-fixed); a variadic one
                    ; additionally sets al = #xmm args for its callee's register save area.
                    cr (call-fixed g env head args direct ptys rt variadic)
                    (? (bad? cr) 'bad
                       (! (stru? (vty cr))) cr
                       (sse2? g (vty cr))              ; a two-double struct result: park the xmm pair in a fresh slot, answer its address
                        (: toff (- 0 (+ (peep g 'off 0) 16))
                           _ (pin g 'off (+ (peep g 'off 0) 16))
                           (mkv (vty cr) 'r0 (cat (vfs cr)
                                        (cat (fstf 'double 'r4 toff (xmmreg 0))
                                         (cat (fstf 'double 'r4 (+ toff 8) (xmmreg 1))
                                              (L (L 'lea 'r0 'r4 toff)))))))
                       (ipair? g (vty cr))             ; a two-int struct result: park rax:rdx the same way
                        (: toff (- 0 (+ (peep g 'off 0) 16))
                           _ (pin g 'off (+ (peep g 'off 0) 16))
                           (mkv (vty cr) 'r0 (cat (vfs cr)
                                        (L (L 'st 'r4 toff 'r0) (L 'st 'r4 (+ toff 8) 'r2)
                                           (L 'lea 'r0 'r4 toff)))))
                       (id? (aone g (vty cr)) 'sse)    ; a small SSE aggregate result: park xmm0
                        (: toff (- 0 (+ (peep g 'off 0) 16))
                           _ (pin g 'off (+ (peep g 'off 0) 16))
                           (mkv (vty cr) 'r0 (cat (vfs cr)
                                        (cat (fstf 'double 'r4 toff (xmmreg 0))
                                             (L (L 'lea 'r0 'r4 toff))))))
                       (id? (aone g (vty cr)) 'int)    ; a small INT aggregate result: park rax
                        (: toff (- 0 (+ (peep g 'off 0) 16))
                           _ (pin g 'off (+ (peep g 'off 0) 16))
                           (mkv (vty cr) 'r0 (cat (vfs cr)
                                        (L (L 'st 'r4 toff 'r0) (L 'lea 'r0 'r4 toff)))))
                       'bad))))))
          (= k 'clit)                              ; a compound literal as a value: fill the temp, load it
           (: lv (clval g env e)
              (? (bad? lv) 'bad (loadval (vty lv) (vfs lv))))
          (= k 'bin) (cgbin g env e wnt)
          'bad))
   ; a TARGETABLE gp register argument: pure and single-emission, reading only
   ; an immediate, the frame, a home register, or a label -- so it skips the
   ; push/pop cell entirely and lands straight in its own argument register,
   ; emitted between the home spills and the pops (targets are disjoint; pops
   ; read only sp cells). deferring a pure read past its siblings is the same
   ; unspecified-order license the overflow-first emission already rides. a
   ; homed-param read is the one cross-entry hazard (another targeted arg may
   ; write its home first), so it carries BOTH emissions -- the home mov and
   ; the spill-slot load -- and the caller picks by conflict.
   ; -> ((ez i) forms) | ((ezm i rH) movforms ldforms) | 'no
   (ezarg g env e pty i)
    (: rT (nthr argregs i)
       (fin ty fs) (: aty (? pty pty ty)
                      (? (|| (flo? aty) (stru? aty)) 'no (L (L 'ez i) fs)))
       (? (= (cap e) 'num) (fin 'long (L (L 'li rT (caup e))))
          (= (cap e) 'str)
           (: lbl (nlab g ".S")
              _ (pin g 'strs (link (L lbl (caup e)) (g 'strs)))
              (fin (L 'ptr 'char) (L (L 'la rT lbl))))
          (= (cap e) 'addr)                          ; &var only: lea/la, argpos-equivalent (no escan)
           (? (! (= (cap (caup e)) 'var)) 'no
              (: en (vent g env (caup (caup e)))
                 (? (bad? en) 'no
                    (= (cap en) 'loc) (fin (L 'ptr (cauup en)) (L (L 'lea rT 'r4 (caup en))))
                    (= (cap en) 'glo) (fin (L 'ptr (cauup en)) (L (L 'la rT (caup en))))
                    'no)))
          (! (= (cap e) 'var)) 'no
          (: en (vent g env (caup e))
             (? (bad? en) 'no
                (: ty (cauup en)
                   (? (= (cap en) 'regv)             ; a homed param: mov from the home, or ld its spill slot
                       (? (|| (flo? (? pty pty ty)) (stru? (? pty pty ty))) 'no
                          (: sl (assoc (caup en) (peep g 'homes ()))
                             (? (! (two? sl)) 'no
                                (L (L 'ezm i (caup en))
                                   (L (L 'mov rT (caup en)))
                                   (L (L 'ld rT 'r4 (caup sl)))))))
                      (arr? ty)                      ; array decay: its address
                       (? (= (cap en) 'loc) (fin (L 'ptr (caup ty)) (L (L 'lea rT 'r4 (caup en))))
                          (fin (L 'ptr (caup ty)) (L (L 'la rT (caup en)))))
                      (|| (stru? ty) (flo? ty)) 'no
                      (= (cap en) 'loc) (fin ty (L (L (ldop ty) rT 'r4 (caup en))))
                      (fin ty (L (L 'la rT (caup en)) (L (ldop ty) rT rT 0)))))))))   ; a global: la then a self-based load
   ; the SysV register call, stack overflow included: args 1..6 gp / 1..8 xmm ride
   ; registers, the REST ride the caller stack (arg7 shallowest). evaluation order is
   ; free in C, so the overflow group emits FIRST, then the register group, both
   ; right-to-left -- the register pops then run forward and the overflow block is
   ; left sitting at [sp] for the callee; the caller cleans it after the call (an odd
   ; count takes an 8-byte pad UNDER it). va? marks a call to a VARIADIC function --
   ; additionally `al` (rax's low byte) carries the number of vector (xmm) arguments,
   ; which its variadic callee's prologue reads to decide whether to spill the xmm
   ; registers. params named uniquely so no lambda parameter shadows a sibling
   ; :-local through boxfix's shared cell (stage 5).
   (call-fixed g env hd ags dir pts ret va?)
    (: (kls as i gpc xmmc ovc acc)                       ; classify + evaluate, L->R -> (((class idx) pushforms)..) | 'bad
        (? (! (two? as)) (rev acc)
           ; a targetable leaf skips the cell: classified 'ez/'ezm, emitted
           ; straight into its argument register after the spills.
           (: ez (? (< gpc 6) (ezarg g env (cap as) (nthty pts i) gpc) 'no)
              (? (! (id? ez 'no)) (kls (cup as) (+ i 1) (+ gpc 1) xmmc ovc (link ez acc))
           ; a DIRECT &x / array / struct-var argument is presumed dead once the
           ; callee returns (the &Hp / &_res idiom): argpos exempts its lea from
           ; the fesc pin, one-shot, cleared right after. the sibs WINDOW rule
           ; still keeps the address out of a tail call's own staging.
           (: a (: _ (? (member? (cap (cap as)) '(addr var)) (pin g 'argpos 1) ())
                   (cgexpr g env (cap as)))
              _ (pin g 'argpos ())
              (? (bad? a) 'bad
                 (: pty (nthty pts i)
                    aty (? pty pty (vty a))                ; classify by the param type if known, else the arg's
                    wd (flo? aty)
                    (? (sse2? g aty)                       ; a two-double struct arg: push its pair (re on top), an xmm PAIR target
                        (? (< 6 xmmc) 'bad
                           (kls (cup as) (+ i 1) gpc (+ xmmc 2) ovc
                                (link (L (L 'x2 xmmc)
                                         (cat (tor0 g a) (L (L 'ld 'r1 'r0 8) (L 'push 'r1) (L 'ld 'r1 'r0 0) (L 'push 'r1))))
                                      acc)))
                       (&& (stru? aty) (! (aone g aty))) 'bad   ; a MIXED/>16B by-value struct stays ahead
                       ; a one-eightbyte aggregate rides the scalar path: its
                       ; 8 content bytes load into r0 (the value IS an address)
                       ; and class by its eightbyte -- INT a gp arg, SSE an xmm
                       (: one (? (stru? aty) (aone g aty) ())
                          wd2 (|| wd (id? one 'sse))
                          aval (? one (cat (tor0 g a) (L (L 'ld 'r0 'r0 0)))
                                  wd (cat (asflo g a) (L (L 'movqrx 'r0 'f0)))
                                  (asint g a))
                          ; a register arg rides a 16-byte cell: rsp stays 16-aligned
                          ; while the REMAINING args evaluate (a later arg may hold a
                          ; nested call, and the SysV ABI wants rsp%16==0 at it). an
                          ; overflow arg keeps its 8-byte push -- the callee reads the
                          ; overflow block packed, and its target is ai-internal (never
                          ; a libc movaps-on-rbp path), so a stray eval-time skew is moot.
                          rpush (cat aval (spush 'r0))
                          opush (cat aval (L (L 'push 'r0)))
                          (? (&& wd2 (< xmmc 8)) (kls (cup as) (+ i 1) gpc (+ xmmc 1) ovc (link (L (L 'x xmmc) rpush) acc))
                             (&& (! wd2) (< gpc 6)) (kls (cup as) (+ i 1) (+ gpc 1) xmmc ovc (link (L (L 'g gpc) rpush) acc))
                             (kls (cup as) (+ i 1) gpc xmmc (+ ovc 1) (link (L (L 'ov ovc) opush) acc)))))))))))
       kr (kls ags 0 0 0 0 ())
       (? (bad? kr) 'bad
          (: ov? (\ kent (= (cap (cap kent)) 'ov))
             ovr (: (go1 l1 acc1) (? (! (two? l1)) acc1
                                     (go1 (cup l1) (? (ov? (cap l1)) (link (cap l1) acc1) acc1)))
                    (go1 kr ()))                          ; overflow entries, REVERSED (deepest pushes first)
             rgr (: (go2 l2 acc2) (? (! (two? l2)) acc2
                                     (go2 (cup l2) (? (member? (cap (cap (cap l2))) '(g x x2))
                                                      (link (cap l2) acc2) acc2)))
                    (go2 kr ()))                          ; PUSHING register entries, reversed (pops run forward)
             (pushcat l3 acc3) (? (! (two? l3)) acc3 (pushcat (cup l3) (cat acc3 (caup (cap l3)))))
             pops (: (go4 l4 acc4)
                      (? (! (two? l4)) acc4
                         (: kc (cap (cap l4))
                            (go4 (cup l4) (? (member? (cap kc) '(ov ez ezm)) acc4
                                             (cat acc4 (? (= (cap kc) 'g) (spop (nthr argregs (caup kc)))
                                                          (= (cap kc) 'x2)   ; the struct pair: re then im (a natural 16-byte cell)
                                                           (L (L 'pop 'r0) (L 'movqxr (xmmreg (caup kc)) 'r0)
                                                              (L 'pop 'r0) (L 'movqxr (xmmreg (+ (caup kc) 1)) 'r0))
                                                          (cat (spop 'r0) (L (L 'movqxr (xmmreg (caup kc)) 'r0)))))))))
                     (go4 kr ()))
             nxmm (: (go5 l5 n5) (? (! (two? l5)) n5
                                    (go5 (cup l5) (: kk (cap (cap (cap l5)))
                                                     (? (= kk 'x) (+ n5 1) (= kk 'x2) (+ n5 2) n5))))
                     (go5 kr 0))
             nov (tally ovr)
             padn (? (= (& nov 1) 1) 8 0)                 ; keep sp 16-aligned across the overflow block
             pad (? (< 0 padn) (L (L 'sub 'sp 'sp padn)) ())
             clean (? (< 0 (+ (* 8 nov) padn)) (L (L 'add 'sp 'sp (+ (* 8 nov) padn))) ())
             pf (cat pad (cat (pushcat ovr ()) (pushcat rgr ())))
             setal (? va? (L (L 'li 'r0 nxmm)) ())        ; al = #xmm, set AFTER pops (r0 is no arg register)
             ; NON-LEAF register homes (g 'homes, ((reg slot)..)): a home rides a
             ; caller-saved register, so it spills to its frame slot just before
             ; the pops (the args' own evaluation -- and any assignment inside it
             ; -- has already run, so the register holds the latest value) and
             ; reloads right after the clean. a ret-position call's reloads are
             ; DEAD -- the sibcall pass skips them and tail-jumps (skiprel).
             hs (peep g 'homes ())
             spills (foldl (\ a2 p2 (cat a2 (L (L 'st 'r4 (caup p2) (cap p2))))) () hs)
             relods (foldl (\ a2 p2 (cat a2 (L (L 'ld (cap p2) 'r4 (caup p2))))) () hs)
             ; the targeted emissions, after the spills and before the pops: an
             ; 'ezm home mov demotes to its spill-slot load when ANOTHER targeted
             ; arg writes that home (a self-mov stays -- the fold drops it).
             ezt (: (go6 l6 a6) (? (! (two? l6)) a6
                                   (go6 (cup l6) (: kc (cap (cap l6))
                                                    (? (member? (cap kc) '(ez ezm))
                                                       (link (nthr argregs (caup kc)) a6) a6))))
                    (go6 kr ()))
             ezf (: (go7 l7 a7) (? (! (two? l7)) a7
                                   (go7 (cup l7)
                                        (: kc (cap (cap l7))
                                           (? (= (cap kc) 'ez) (cat a7 (caup (cap l7)))
                                              (! (= (cap kc) 'ezm)) a7
                                              (: rH (cauup kc)
                                                 (? (&& (member? rH ezt) (! (id? rH (nthr argregs (caup kc)))))
                                                    (cat a7 (cauup (cap l7)))
                                                    (cat a7 (caup (cap l7)))))))))
                    (go7 kr ()))
             (? dir
                 (mkv ret 'r0 (cat pf (cat spills (cat ezf (cat pops (cat setal (cat (L (L 'call (intern (caup hd)))) (cat clean relods))))))))
                (: hr (cgexpr g env hd)                   ; a function-pointer value: park in r3, callr
                   (? (bad? hr) 'bad
                      (mkv (fnret (vty hr)) 'r0 (cat pf (cat (tor0 g hr) (cat (L (L 'mov 'r3 'r0))
                                (cat spills (cat ezf (cat pops (cat setal (cat (L (L 'callr 'r3)) (cat clean relods))))))))))))))))
   (cgbin g env e wnt)
    (: op (caup e)
       lhs (cauup e) rhs (caup (cuup e))
       ; LAZY left-then-right, like cbranch: the left PARKS (allocates) before
       ; the right evaluates. a constant side rides the immediate lane with NO
       ; right evaluation; two register operands combine 3-address; pointer
       ; scaling, divide, a variable shift, and a call on the right keep the
       ; memory shuttle (shut).
       a (cgexpr g env lhs)
       (? (bad? a) 'bad
          ; a constant count rides the immediate shift; a variable count
          ; rides shlv/sarv with the count PINNED to r1 (holo's contract)
          (member? op '(shl shr))
           (: uL (usg? (vty a))                             ; a `>>` on an unsigned left operand is LOGICAL (shr, not sar)
              rt (? uL 'ulong 'long)                        ; the shift result keeps the left operand's signedness
              iop (? (= op 'shl) 'shl (? uL 'shr 'sar))
              vop (? (= op 'shl) 'shlv (? uL 'shrv 'sarv))
              (? (= (cap rhs) 'num)
                  (? (wr? g (vreg a))
                     (mkv rt (vreg a) (cat (vfs a) (L (L iop (vreg a) (caup rhs)))))
                     (: rd (? wnt wnt (rdst g (vreg a)))    ; a borrowed home shifts a COPY (no 3-address shift)
                        (mkv rt rd (cat (vfs a) (L (L 'mov rd (vreg a)) (L iop rd (caup rhs)))))))
                 (: b (cgexpr g env rhs)
                    (? (bad? b) 'bad
                       (mkv rt 'r0 (cat (tor0 g a)
                              (cat (spush 'r0)
                               (cat (tor0 g b) (cat (L (L 'mov 'r1 'r0)) (cat (spop 'r0)
                                                (L (L vop 'r0 'r1))))))))))))
          (: ta (vty a)
             ; a constant right rides the immediate lane; a constant LEFT swaps
             ; over (commutative ops) or mirrors (relations, rflip) onto the right
             imr (? (&& (! (flo? ta)) (= (cap rhs) 'num)) (immop g op a ta (caup rhs) wnt) 'no)
             (? (! (id? imr 'no)) imr
                (: iml? (&& (! (flo? ta)) (&& (= (cap lhs) 'num)
                            (member? op '(+ * & | ^ eq ne lt le gt ge))))
                   ah (? (|| iml? (|| (flo? ta) (callish? rhs))) 'sh (vpark g env lhs a))
                   b (cgexpr g env rhs)
                   (? (bad? b) 'bad
                      (: tb (vty b)
                         av (? (id? ah 'sh) a ah)
                         ; the memory shuttle: left in r1, right in r0 (today's shape)
                         (shut z9)
                          (: mid (cat (tor0 g av) (cat (spush 'r0) (cat (tor0 g b) (spop 'r1))))
                             back (L (L 'mov 'r0 'r1))
                             pa (ptr? ta) pb (ptr? tb)
                             unsg (|| (usg? ta) (usg? tb))            ; either operand unsigned -> unsigned divide
                             cunsg (|| unsg (|| pa pb))               ; a POINTER relational compares UNSIGNED too (C: addresses are unsigned; matters where a pointer sets bit 63)
                             (? (= op '+)
                                 (? (&& pa pb) 'bad
                                    pa (mkv ta 'r0 (cat mid (cat (? (< 1 (tsz g (caup ta)))
                                                             (L (L 'imul 'r0 'r0 (tsz g (caup ta)))) ())
                                                      (cat (L (L 'add 'r1 'r1 'r0)) back))))
                                    pb (mkv tb 'r0 (cat mid (cat (? (< 1 (tsz g (caup tb)))
                                                             (L (L 'imul 'r1 'r1 (tsz g (caup tb)))) ())
                                                      (cat (L (L 'add 'r1 'r1 'r0)) back))))
                                    (mkv 'long 'r0 (cat mid (cat (L (L 'add 'r1 'r1 'r0)) back))))
                                (= op '-)
                                 (? (&& pa pb)
                                     (? (= (tsz g (caup ta)) (tsz g (caup tb)))
                                        ; a pointer difference divides the byte gap by the pointee size.
                                        ; mid leaves left in r1, right in r0; `sub r1 r1 r0` makes r1 the
                                        ; gap. a power-of-two size shifts (move to r0, sar); any other
                                        ; size takes a real signed divide (the / lane's shape: dividend
                                        ; r1, divisor r0, result r1 -> r0). size 1 is just the move.
                                        (: esz (tsz g (caup ta))
                                           (mkv 'long 'r0 (cat mid (cat (L (L 'sub 'r1 'r1 'r0))
                                                            (? (<= esz 1) back
                                                               (pow2? esz) (cat back (L (L 'sar 'r0 (lg2 esz))))
                                                               (L (L 'li 'r0 esz) (L 'div 'r1 'r1 'r0) (L 'mov 'r0 'r1)))))))
                                        'bad)
                                    pa (mkv ta 'r0 (cat mid (cat (? (< 1 (tsz g (caup ta)))
                                                             (L (L 'imul 'r0 'r0 (tsz g (caup ta)))) ())
                                                      (cat (L (L 'sub 'r1 'r1 'r0)) back))))
                                    pb 'bad
                                    (mkv 'long 'r0 (cat mid (cat (L (L 'sub 'r1 'r1 'r0)) back))))
                                (: tail (? (= op '*) (L (L 'imul 'r1 'r1 'r0))
                                           (= op '/) (L (L (? unsg 'udiv 'div) 'r1 'r1 'r0))
                                           (= op '%) (L (L (? unsg 'urem 'rem) 'r1 'r1 'r0 'r3))
                                           (= op '&) (L (L 'and 'r1 'r1 'r0))
                                           (= op '|) (L (L 'or 'r1 'r1 'r0))
                                           (= op '^) (L (L 'xor 'r1 'r1 'r0))
                                           'bad)
                                   (? (! (bad? tail))
                                      (mkv (ubin ta tb) 'r0 (cat mid (cat tail back)))
                                      (member? op '(eq ne lt le gt ge))
                                       (mkv 'long 'r0 (cat mid (L (L 'cmp 'r1 'r0) (L 'set (scc op cunsg) 'r0))))
                                      'bad))))
                         iml (? (&& iml? (! (flo? tb))) (immop g (rflip op) b tb (caup lhs) wnt) 'no)
                         (? (! (id? iml 'no)) iml
                            (|| (flo? ta) (flo? tb))
                             ; the double lane: either operand double -> both to double (f1=left,
                             ; f0=right through the gp stack), then the scalar-double op or ucomisd.
                             (: mid (cat (asflo g av) (cat (cat (L (L 'movqrx 'r0 'f0)) (spush 'r0))
                                         (cat (asflo g b) (cat (spop 'r1) (L (L 'movqxr 'f1 'r1))))))
                                (? (= op '+) (mkv 'double 'r0 (cat mid (L (L 'addsd 'f0 'f1))))
                                   (= op '*) (mkv 'double 'r0 (cat mid (L (L 'mulsd 'f0 'f1))))
                                   (= op '-) (mkv 'double 'r0 (cat mid (L (L 'subsd 'f1 'f0) (L 'movsd 'f0 'f1))))
                                   (= op '/) (mkv 'double 'r0 (cat mid (L (L 'divsd 'f1 'f0) (L 'movsd 'f0 'f1))))
                                   ; IEEE compare: UNORDERED (a NaN operand) must answer false for
                                   ; every relation and true only for !=. above/ae read CF=0, which
                                   ; unordered sets, so < and <= COMPARE SWAPPED and ride above/ae;
                                   ; == and != carry the parity bit (unordered -> PF=1) explicitly.
                                   (member? op '(lt le))
                                    (mkv 'long 'r0 (cat mid (L (L 'ucomisd 'f0 'f1)
                                                               (L 'set (? (= op 'lt) 'above 'ae) 'r0))))
                                   (member? op '(gt ge))
                                    (mkv 'long 'r0 (cat mid (L (L 'ucomisd 'f1 'f0)
                                                               (L 'set (? (= op 'gt) 'above 'ae) 'r0))))
                                   (= op 'eq)
                                    (mkv 'long 'r0 (cat mid (L (L 'ucomisd 'f1 'f0) (L 'set 'eq 'r0)
                                                               (L 'set 'np 'r1) (L 'and 'r0 'r0 'r1))))
                                   (= op 'ne)
                                    (mkv 'long 'r0 (cat mid (L (L 'ucomisd 'f1 'f0) (L 'set 'ne 'r0)
                                                               (L 'set 'p 'r1) (L 'or 'r0 'r0 'r1))))
                                   'bad))
                            ; the REGISTER lane: both values live, 3-address combine
                            (: pa (ptr? ta) pb (ptr? tb)
                               (? (|| (id? ah 'sh) (|| pa pb)) (shut ())
                                  (: rA (vreg ah) rB (vreg b)
                                     cunsg (|| (|| (usg? ta) (usg? tb)) (|| pa pb))
                                     pre (cat (vfs ah) (vfs b))
                                     (? (member? op '(eq ne lt le gt ge))
                                         (: rd (? wnt wnt (rdst g rA))   ; set runs after the cmp: rd may alias rB
                                            fs (cat pre (L (L 'cmp rA rB) (L 'set (scc op cunsg) rd)))
                                            _ (rfree g rB) _ (? (id? rd rA) () (rfree g rA))
                                            (mkv 'long rd fs))
                                        (member? op '(+ - * & | ^))
                                         (: iop2 (? (= op '+) 'add (= op '-) 'sub (= op '*) 'imul
                                                    (= op '&) 'and (= op '|) 'or 'xor)
                                            rd (? (&& wnt (! (id? wnt rB))) wnt (rdst g rA))
                                            ; holo reorders a commutative rd==rb; sub CANNOT (alias-dst) --
                                            ; a borrowed left + dry pool can land rd on rB's r0
                                            (? (&& (= op '-) (id? rd rB)) (shut ())
                                               (: fs (cat pre (L (L iop2 rd rA rB)))
                                                  _ (rfree g rB) _ (? (id? rd rA) () (rfree g rA))
                                                  (mkv (ubin ta tb) rd fs))))
                                        (shut ())))))))))))))

   ; r3 (rbx) is CALLEE-SAVED under SysV and gen leans on it (callr park, the
   ; overflow builtins, va_arg's walk) -- an optimized gcc caller keeps LIVE
   ; LOCALS in rbx across our calls (the ai boot died in main's argv fold: its
   ; loop bound rode ebx straight through gxr). every fn owns frame slot -8 for
   ; it: the prologue stores, this shared epilogue reloads.
   epi (L (L 'ld 'r3 'r4 -8) (L 'mov 'sp 'r4) (L 'pop 'r4) (L 'ret))

   ; -- the SIBCALL pass (stage 8): a RET-position call tail-JUMPS instead, so
   ; deep tail recursion runs flat and the lvm shape Continues by jmp at
   ; ai_tco=1 (`make vmret` reads the disassembly). the rewrite is LOCAL:
   ; (call F) followed by exactly the epilogue becomes epilogue + (jmp F) -- at
   ; a ret-position call the operand stack is exactly the frame, and the
   ; epilogue parks sp on the return address, a call's entry state, so the
   ; callee answers our caller directly. (callr r3) parks the target in r10
   ; first (the epilogue reloads r3). anything BETWEEN the call and the
   ; epilogue -- an overflow-arg clean, a result conversion, a struct
   ; materialization -- breaks the pattern and keeps the plain call. GATED per
   ; fn: any (lea _ r4 _) means a frame address ESCAPES (a local's address, a
   ; struct temp, a va register save area) and the frame must outlive every
   ; call -- that fn keeps all its calls. the ESCAPE is tracked at the SOURCE
   ; (the g 'fesc pin, reset per fn): clval's lea for ordinary assignment is
   ; consumed by its own store and stays eligible -- only an address that
   ; becomes a VALUE (the & lane, a local array decaying, a struct-value rep,
   ; a compound literal, va_start's save area, the struct-return temp) pins.
   (leas? fs) (? (! (two? fs)) ()
                 (: f (cap fs)
                    (? (&& (two? f) (&& (= (cap f) 'lea) (= (cauup f) 'r4))) 1
                       (leas? (cup fs)))))
   (escan g r) (: _ (? (&& (two? r) (leas? (vfs r))) (pin g 'fesc 1) ()) r)
   (unlean fs) (? (! (two? fs)) ()                   ; & makes a consumed address ESCAPE: lean -> lea, so the gate sees it
                  (: f (cap fs)
                     (link (? (&& (two? f) (= (cap f) 'lean)) (link 'lea (cup f)) f)
                           (unlean (cup fs)))))
   (epi4? fs) (&& (two? fs) (&& (= (cap fs) '(ld r3 r4 -8))
              (: f2 (cup fs) (&& (two? f2) (&& (= (cap f2) '(mov sp r4))
              (: f3 (cup f2) (&& (two? f3) (&& (= (cap f3) '(pop r4))
              (: f4 (cup f3) (&& (two? f4) (= (cap f4) '(ret))))))))))))
   ; lw = the WINDOW rule: a frame lea seen since the last call boundary means
   ; the candidate's OWN staging may hand the callee a frame address (`return
   ; f(&x)`, `return f(buf)`) -- that call stays a call; the boundary resets
   ; the window (a consumed &Hp two statements up doesn't block the Continue).
   ; a ternary's JOIN LABEL may sit between the call and the epilogue (lvm_eval's
   ; Continue): the jump sequence lands BEFORE the labels and the labels + epi
   ; stay -- the other arm still flows through them.
   (lbl-epi? fs) (? (! (two? fs)) ()
                    (&& (two? (cap fs)) (= (cap (cap fs)) 'label))
                     (? (epi4? (cup fs)) 1 (lbl-epi? (cup fs)))
                    ())
   ; a nested-ternary return leaves each arm as (call F)(jmp JOIN) with JOIN
   ; leading to the epilogue: elabs collects those epilogue labels first, and
   ; a candidate followed by (jmp X), X collected, rewrites too (the dead jmp
   ; drops -- nothing lands mid-instruction).
   (elabs fs t) (? (! (two? fs)) t
                   (: f (cap fs)
                      _ (? (&& (two? f) (&& (= (cap f) 'label)
                                            (|| (epi4? (cup fs)) (lbl-epi? (cup fs)))))
                           (pin t (caup f) 1) ())
                      (elabs (cup fs) t)))
   (sibjmp f) (? (= (cap f) 'call)
                 (L (L 'ld 'r3 'r4 -8) (L 'mov 'sp 'r4) (L 'pop 'r4) (L 'jmp (caup f)))
                 (L (L 'mov 'r10 'r3) (L 'ld 'r3 'r4 -8) (L 'mov 'sp 'r4) (L 'pop 'r4) (L 'jmpr 'r10)))
   ; a home reload run ((ld rH r4 slot)..) after a ret-position call is DEAD --
   ; the tail-jump hands the frame back first. skiprel peels exactly those.
   (skiprel fs hs)
    (? (! (two? fs)) fs
       (: f (cap fs)
          (? (&& (two? f) (&& (= (cap f) 'ld) (= (cauup f) 'r4)))
              (: h (assoc (caup f) hs)
                 (? (&& (two? h) (= (caup h) (caup (cuup f)))) (skiprel (cup fs) hs) fs))
             fs)))
   (sibs fs lw el hs)
    (? (! (two? fs)) ()
       (: f (cap fs) r (cup fs)
          lw2 (? (&& (two? f) (&& (= (cap f) 'lea) (= (cauup f) 'r4))) 1 lw)
          cand (&& (! lw2) (&& (two? f) (|| (&& (= (cap f) 'call) (two? (cup f)))
                                            (= f '(callr r3)))))
          rr (? cand (skiprel r hs) r)
          (? (&& cand (epi4? rr))
              (cat (sibjmp f) (sibs (cup (cup (cup (cup rr)))) () el hs))
             (&& cand (lbl-epi? rr))
              (cat (sibjmp f) (sibs rr () el hs))
             (&& cand (: nx (cap rr) (&& (two? nx) (&& (= (cap nx) 'jmp) (peep el (caup nx) ())))))
              (cat (sibjmp f) (sibs (cup rr) () el hs))
             (link f (sibs r (? (&& (two? f) (member? (cap f) '(call callr raw))) () lw2) el hs)))))   ; raw: a builtin splice consumes its address like a call
   (sibcall g fs) (? (peep g 'fesc ()) fs (sibs fs () (elabs fs (tablet 0)) (peep g 'homes ())))

   ; -- IR constant propagation (cfoldir): a straight-line abstract pass over a
   ; function's final forms. it tracks known small constants in registers, frame
   ; slots, and machine-stack cells, folds ALU ops on them back to li's, turns
   ; reg-reg ALU with a known source into the imm form, folds loads of known
   ; slots, and evaluates known cmp+br / cmp+set pairs (a constant ternary
   ; drops its dead arm). the payoff: sizeof/Width/Have arithmetic -- constant
   ; subgraphs the inliner exposes -- collapses the way a real compiler folds
   ; them. knowns stay in [0, 2^30] (compare signedness and shifts agree there);
   ; labels and calls invalidate values (joins/effects); anything unrecognized
   ; invalidates EVERYTHING (new ops stay safe by default). --
   kmax 1073741824
   (kok? v) (&& (<= 0 v) (< v kmax))
   (cfoldir fs0)
    (: (fresh z9) (tablet 0)                        ; reg/slot/cell -> (1 K) const | (2 rX) copy-of-register | ()
       (rv t k) (peep t k ())
       (rset t k v) (pin t k v)
       (kn? v) (&& (two? v) (= (cap v) 1))          ; a known CONSTANT (never let a copy reach arithmetic)
       ; resolve a source register to its deepest value: a const rides, a copy
       ; chases to its ROOT register (valid until that register is written)
       (rsv rg s) (: v (rv rg s) (? (two? v) v (L 2 s)))
       ; a WRITE to d invalidates every copy-of-d anywhere (regs, slots, cells)
       (kilc t d) (: (go1 ks) (? (! (two? ks)) t
                                 (: k1 (cap ks) v (peep t k1 ())
                                    _ (? (&& (two? v) (&& (= (cap v) 2) (= (caup v) d))) (pin t k1 ()) ())
                                    (go1 (cup ks))))
                     (go1 (keys t)))
       (defr rg sl ce d) (: _ (rset rg d ()) _ (kilc rg d) _ (kilc sl d) (kilc ce d))
       (copyt t) (: t2 (tablet 0)
                    (go1 ks) (? (! (two? ks)) t2
                                (: _ (pin t2 (cap ks) (peep t (cap ks) ())) (go1 (cup ks))))
                    (go1 (keys t)))
       ; the JOIN of two abstract states: a key survives only where both sides
       ; know it and agree (the meet over the flat lattice) -- a fresh tablet
       (joint ta tb) (: t2 (tablet 0)
                        (go1 ks) (? (! (two? ks)) t2
                                    (: k1 (cap ks) va (peep ta k1 ()) vb (peep tb k1 ())
                                       _ (? (&& (two? va) (&& (two? vb)
                                                (&& (= (cap va) (cap vb)) (= (caup va) (caup vb)))))
                                            (pin t2 k1 va) ())
                                       (go1 (cup ks))))
                        (go1 (keys ta)))
       (alu op a b) (? (= op 'add) (+ a b) (= op 'sub) (- a b) (= op 'imul) (* a b)
                       (= op 'and) (& a b) (| a b))  ; xor stays unfolded (imm-converted only)
       (ccev cc a b) (? (= cc 'eq) (= a b) (= cc 'ne) (! (= a b))
                        (|| (= cc 'lt) (= cc 'below)) (< a b)
                        (|| (= cc 'le) (= cc 'be)) (<= a b)
                        (|| (= cc 'gt) (= cc 'above)) (< b a)
                        (<= b a))                    ; ge / ae
       ; after an unconditional transfer, everything to the next label is DEAD
       ; (a jump can only land on a label) -- a folded ternary drops its arm
       (swallow fs) (? (! (two? fs)) ()
                       (: f (cap fs) (? (&& (two? f) (= (cap f) 'label)) fs (swallow (cup fs)))))
       (atlab? fs l) (&& (two? fs) (: f (cap fs) (&& (two? f) (&& (= (cap f) 'label) (= (caup f) l)))))
       ; back-edge labels (a jmp/br sitting BELOW its target): a loop head joins
       ; an edge this one linear pass never computes -- assume nothing there
       backs (: seen (tablet 0) bt (tablet 0)
                (bscan l) (? (! (two? l)) bt
                             (: f (cap l)
                                _ (? (! (two? f)) ()
                                     (= (cap f) 'label) (pin seen (caup f) 1)
                                     (= (cap f) 'jmp) (? (peep seen (caup f) ()) (pin bt (caup f) 1) ())
                                     (= (cap f) 'br) (? (peep seen (cauup f) ()) (pin bt (cauup f) 1) ())
                                     ())
                                (bscan (cup l))))
                (bscan fs0))
       ; the pending in-states: every FORWARD jmp/br to L joins its state into
       ; pend[L]; L's label reads it back and joins the fall-through -- so a
       ; known value CROSSES a label (the spush around a folded ternary reaches
       ; its spop). the sp cursor must agree or the cells drop.
       pend (tablet 0)
       (pmerge l cur rg sl ce)
        (: old (peep pend l ())
           (? (! (two? old)) (pin pend l (L cur (copyt rg) (copyt sl) (copyt ce)))
              (: nce (? (= (cap old) cur) (joint (caup (cuup old)) ce) (fresh 0))
                 (pin pend l (L (cap old) (joint (caup old) rg) (joint (cauup old) sl) nce)))))
       ; lv: linearly LIVE -- () right after an unconditional transfer (the
       ; label then reads only its jump-in state, never the stale linear one)
       (go fs lv cur rg sl ce acc)
        (? (! (two? fs)) (rev acc)
           (: f (cap fs) r (cup fs)
              op (? (two? f) (cap f) ())
              (? (= op 'label)
                  (: l1 (caup f) acc2 (link f acc)
                     (? (peep backs l1 ()) (go r 1 cur (fresh 0) (fresh 0) (fresh 0) acc2)
                        (: pd (peep pend l1 ())
                           (? (! (two? pd))
                               (? lv (go r 1 cur rg sl ce acc2)
                                  (go r 1 cur (fresh 0) (fresh 0) (fresh 0) acc2))
                              (! lv) (go r 1 (cap pd) (caup pd) (cauup pd) (caup (cuup pd)) acc2)
                              (go r 1 (cap pd) (joint (caup pd) rg) (joint (cauup pd) sl)
                                  (? (= (cap pd) cur) (joint (caup (cuup pd)) ce) (fresh 0))
                                  acc2)))))
                 (member? op '(call callr raw sys))
                  (go r 1 cur (fresh 0) (fresh 0) (fresh 0) (link f acc))
                 (= op 'jmp)                         ; drop the dead tail; a jmp to the very next label falls through
                  (: r2 (swallow r)
                     (? (atlab? r2 (caup f)) (go r2 1 cur rg sl ce acc)
                        (: _ (pmerge (caup f) cur rg sl ce)
                           (go r2 () cur rg sl ce (link f acc)))))
                 (= op 'br)                          ; the taken edge records; the fall-through rides on
                  (: _ (pmerge (cauup f) cur rg sl ce)
                     (go r 1 cur rg sl ce (link f acc)))
                 (member? op '(jmpr ret)) (go (swallow r) () cur rg sl ce (link f acc))
                 (= op 'li)
                  (: nx (? (two? r) (cap r) ())
                     (? (&& (two? nx) (&& (member? (cap nx) '(li mov)) (= (caup nx) (caup f))))
                        (go r 1 cur rg sl ce acc)    ; the very next form rewrites this register: dead li
                        (: k (caup (cup f))
                           old (rv rg (caup f))
                           (? (&& (kn? old) (= (caup old) k))
                              (go r 1 cur rg sl ce acc)   ; the register already holds this value
                              (: _ (defr rg sl ce (caup f))
                                 _ (rset rg (caup f) (? (kok? k) (L 1 k) ()))
                                 (go r 1 cur rg sl ce (link f acc)))))))
                 (= op 'mov)
                  (? (id? (caup f) (cauup f)) (go r 1 cur rg sl ce acc)   ; a self-mov says nothing
                     (: v (rsv rg (cauup f))
                        old (rv rg (caup f))
                        (? (&& (two? old) (&& (two? v)
                              (&& (= (cap old) (cap v)) (= (caup old) (caup v)))))
                           (go r 1 cur rg sl ce acc)     ; the dest already holds this value
                           (: _ (defr rg sl ce (caup f))
                              _ (rset rg (caup f) v)
                              (go r 1 cur rg sl ce (link f acc))))))
                 (member? op '(add sub and or xor imul))
                  (? (= (caup f) 'sp)                ; sp arithmetic: the cell cursor moves
                      (: n (caup (cuup f))
                         (go r 1 (? (= op 'add) (- cur n) (+ cur n)) rg sl ce (link f acc)))
                     (: d (caup f) a (cauup f) b (caup (cuup f))
                        ; b is a register SYMBOL or a charm immediate -- never confuse
                        ; the two (a symbol in arithmetic church-explodes)
                        bk (? (charm? b) (? (kok? b) (L 1 b) ()) (rv rg b))
                        ak (rv rg a)
                        (? (&& (! (= op 'xor)) (&& (kn? ak) (kn? bk)))  ; both known: the op folds to a li
                            (: k (alu op (caup ak) (caup bk))
                               _ (defr rg sl ce d)
                               (? (kok? k)
                                  (: _ (rset rg d (L 1 k))
                                     (go r 1 cur rg sl ce (link (L 'li d k) acc)))
                                  (go r 1 cur rg sl ce (link f acc))))
                           (&& (! (charm? b)) (kn? bk))   ; known reg source -> the imm form
                            (: _ (defr rg sl ce d)
                               (go r 1 cur rg sl ce (link (L op d a (caup bk)) acc)))
                           (: _ (defr rg sl ce d)
                              (go r 1 cur rg sl ce (link f acc))))))
                 (member? op '(shl shr sar))         ; the 2-operand immediate shifts
                  (: d (caup f) k (cauup f) dk (rv rg d)
                     _ (defr rg sl ce d)
                     (? (&& (kn? dk) (charm? k))
                         (: v (? (= op 'shl) (* (caup dk) (k 2)) (>> (caup dk) k))
                            (? (kok? v)
                               (: _ (rset rg d (L 1 v))
                                  (go r 1 cur rg sl ce (link (L 'li d v) acc)))
                               (go r 1 cur rg sl ce (link f acc))))
                        (go r 1 cur rg sl ce (link f acc))))
                 (= op 'st)
                  (? (= (caup f) 'r4)
                      (: _ (rset sl (cauup f) (rsv rg (caup (cuup f))))
                         (go r 1 cur rg sl ce (link f acc)))
                     (= (caup f) 'sp)
                      (: _ (rset ce cur (rsv rg (caup (cuup f))))
                         (go r 1 cur rg sl ce (link f acc)))
                     (go r 1 cur rg (fresh 0) ce (link f acc)))   ; a pointer store may alias the frame
                 (= op 'ld)
                  (: d (caup f) b (cauup f) off (caup (cuup f))
                     kv (? (= b 'r4) (rv sl off) (&& (= b 'sp) (= off 0)) (rv ce cur) ())
                     (? (kn? kv)
                        (: _ (defr rg sl ce d)
                           _ (rset rg d kv)
                           (go r 1 cur rg sl ce (link (L 'li d (caup kv)) acc)))
                        (&& (two? kv) (= (cap kv) 2))   ; the memory holds a live COPY: read the register
                         (? (id? (caup kv) d)
                            (go r 1 cur rg sl ce acc)   ; ... and it IS this register: the load says nothing
                            (: _ (defr rg sl ce d)
                               _ (rset rg d kv)
                               (go r 1 cur rg sl ce (link (L 'mov d (caup kv)) acc))))
                        (: _ (defr rg sl ce d)
                           (go r 1 cur rg sl ce (link f acc)))))
                 (= op 'push)
                  (: cur2 (+ cur 8)
                     _ (rset ce cur2 (rsv rg (caup f)))
                     (go r 1 cur2 rg sl ce (link f acc)))
                 (= op 'pop)
                  (: v (rv ce cur)
                     _ (defr rg sl ce (caup f))
                     _ (rset rg (caup f) v)
                     (go r 1 (- cur 8) rg sl ce (link f acc)))
                 (member? op '(st1 st2 st4 stsd stss))
                  (? (member? (caup f) '(r4 sp))
                      (: _ (? (= (caup f) 'r4) (rset sl (cauup f) ()) (rset ce cur ()))
                         (go r 1 cur rg sl ce (link f acc)))
                     (go r 1 cur rg (fresh 0) ce (link f acc)))
                 (member? op '(ld1 ld2 ld4 ldu1 ldu2 ldu4))
                  (: _ (defr rg sl ce (caup f))
                     (go r 1 cur rg sl ce (link f acc)))
                 (member? op '(lea lean la movqrx cvttsd2si set))
                  (: _ (defr rg sl ce (? (= op 'set) (cauup f) (caup f)))
                     (go r 1 cur rg sl ce (link f acc)))
                 (member? op '(div rem udiv urem shlv shrv sarv neg not sx1 sx2 sx4 zx1 zx2 zx4))
                  (: _ (defr rg sl ce 'r0) _ (defr rg sl ce 'r1) _ (defr rg sl ce 'r2) _ (defr rg sl ce 'r3)
                     (go r 1 cur rg sl ce (link f acc)))
                 (= op 'cmp)                         ; paired with its br/set consumer
                  (: a (rv rg (caup f))
                     b (? (charm? (cauup f)) (? (kok? (cauup f)) (L 1 (cauup f)) ())
                          (rv rg (cauup f)))
                     nx (? (two? r) (cap r) ())
                     (? (&& (kn? a) (&& (kn? b) (&& (two? nx) (member? (cap nx) '(br set)))))
                         (: tv (ccev (caup nx) (caup a) (caup b))
                            (? (= (cap nx) 'br)
                               (? tv (: r2 (swallow (cup r))
                                        (? (atlab? r2 (caup (cup nx))) (go r2 1 cur rg sl ce acc)
                                           (: _ (pmerge (caup (cup nx)) cur rg sl ce)
                                              (go r2 () cur rg sl ce (link (L 'jmp (caup (cup nx))) acc)))))
                                     (go (cup r) 1 cur rg sl ce acc))
                               (: d (caup (cup nx)) k (? tv 1 0)
                                  _ (defr rg sl ce d)
                                  _ (rset rg d (L 1 k))
                                  (go (cup r) 1 cur rg sl ce (link (L 'li d k) acc)))))
                        (go r 1 cur rg sl ce (link f acc))))
                 (member? op '(movqxr ucomisd ldsd ldss cvtsi2sd cvtss2sd cvtsd2ss addsd subsd mulsd divsd movsd))
                  (go r 1 cur rg sl ce (link f acc)) ; the xmm lane leaves gp state alone
                 ; anything else: assume nothing survives
                 (go r 1 cur (fresh 0) (fresh 0) (fresh 0) (link f acc)))))
       (go fs0 1 0 (fresh 0) (fresh 0) (fresh 0) ()))

   ; dead CELLS: after the copy folds a spush cell whose load folded away is
   ; write-only -- its store drops (the sub/add sp pair stays; spmerge cancels
   ; what becomes adjacent). a record STACK mirrors the sp motion exactly --
   ; 16-byte cells (sub+st adjacent, the spush shape), 8-byte pushes, pads,
   ; multi-slot cleans -- and ANY shape outside the model bails the whole fn.
   ; a (mov sp r4) epilogue is a PATH exit, not sp motion on the linear walk.
   (deadcell fs)
    (: cand (tablet 0)                               ; st-index -> 1 while still droppable
       (scan l i stk)
        (? (! (two? l)) 1
           (: f (cap l) r (cup l)
              (? (! (two? f)) (scan r (+ i 1) stk)
                 (&& (= (cap f) 'sub) (&& (= (caup f) 'sp) (charm? (caup (cuup f)))))
                  (: k (caup (cuup f))
                     nx (? (two? r) (cap r) ())
                     (? (&& (= k 16) (&& (two? nx) (&& (= (cap nx) 'st)
                            (&& (= (caup nx) 'sp) (= (cauup nx) 0)))))
                        (: _ (pin cand (+ i 1) 1)
                           (scan (cup r) (+ i 2) (link (L (+ i 1) 16) stk)))
                        (scan r (+ i 1) (link (L () k) stk))))
                 (&& (= (cap f) 'add) (&& (= (caup f) 'sp) (charm? (caup (cuup f)))))
                  (: (unwind st2 k)
                      (? (= k 0) st2
                         (! (two? st2)) 'no
                         (: sz (caup (cap st2))
                            (? (< k sz) 'no (unwind (cup st2) (- k sz)))))
                     st3 (unwind stk (caup (cuup f)))
                     (? (id? st3 'no) 'no (scan r (+ i 1) st3)))
                 (= (cap f) 'push) (scan r (+ i 1) (link (L () 8) stk))
                 (= (cap f) 'pop)
                  (? (&& (two? stk) (&& (! (cap (cap stk))) (= (caup (cap stk)) 8)))
                     (scan r (+ i 1) (cup stk))
                     (= (caup f) 'r4) (scan r (+ i 1) stk)   ; the epilogue's frame pop: path exit
                     'no)
                 (&& (member? (cap f) '(ld ld1 ld2 ld4 ldu1 ldu2 ldu4)) (= (cauup f) 'sp))
                  (? (&& (two? stk) (&& (cap (cap stk)) (= (caup (cuup f)) 0)))
                     (: _ (pin cand (cap (cap stk)) ())     ; loaded: the store lives
                        (scan r (+ i 1) stk))
                     'no)
                 (&& (member? (cap f) '(st st1 st2 st4 stsd stss)) (= (caup f) 'sp)) 'no
                 (&& (member? (cap f) '(ldsd ldss)) (= (cauup f) 'sp)) 'no
                 (scan r (+ i 1) stk))))
       ok (scan fs 0 ())
       (? (id? ok 'no) fs
          (: (drop2 l i) (? (! (two? l)) ()
                            (? (peep cand i ()) (drop2 (cup l) (+ i 1))
                               (link (cap l) (drop2 (cup l) (+ i 1)))))
             (drop2 fs 0))))

   ; dead DEFS: within a basic block, a PURE definition whose register is
   ; re-defined before any read is dead -- the copy folds strand whole li/mov
   ; chains this way. one backward walk; every control edge (label, transfer,
   ; call, raw, sys) resets the dead set (everything assumed live across it);
   ; an op outside the tables does the same. dead_before = (dead + defs) - reads.
   (deaddef fs)
    (: (rdsp f)                                      ; -> (L reads defs pure?) | 'bar
        (: op (cap f)
           (rg1 x) (? (charm? x) () (L x))
           (? (= op 'li) (L () (L (caup f)) 1)
              (= op 'mov) (L (L (cauup f)) (L (caup f)) 1)
              (member? op '(add sub and or xor imul))
               (? (= (caup f) 'sp) (L () () ())      ; sp motion touches no gp register
                  (L (cat (rg1 (cauup f)) (rg1 (caup (cuup f)))) (L (caup f)) 1))
              (= op 'push) (L (L (caup f)) () ())
              (= op 'pop) (L () (L (caup f)) ())
              (member? op '(shl shr sar rol ror)) (L (L (caup f)) (L (caup f)) 1)
              (member? op '(ld ld1 ld2 ld4 ldu1 ldu2 ldu4)) (L (L (cauup f)) (L (caup f)) 1)
              (member? op '(st st1 st2 st4)) (L (L (caup f) (caup (cuup f))) () ())
              (member? op '(lea lean)) (L (L (cauup f)) (L (caup f)) 1)
              (= op 'la) (L () (L (caup f)) 1)
              (= op 'set) (L () (L (cauup f)) 1)
              (member? op '(cmp test)) (L (cat (rg1 (caup f)) (rg1 (cauup f))) () ())
              (member? op '(neg not)) (L (L (caup f)) (L (caup f)) 1)
              (member? op '(sx1 sx2 sx4 zx1 zx2 zx4)) (L (L (caup f)) (L (caup f)) 1)
              (= op 'movqxr) (L (L (cauup f)) () ())
              (= op 'movqrx) (L () (L (caup f)) 1)
              (= op 'cvtsi2sd) (L (L (cauup f)) () ())
              (= op 'cvttsd2si) (L () (L (caup f)) ())
              (member? op '(ldsd ldss)) (L (L (cauup f)) () ())
              (member? op '(stsd stss)) (L (L (caup f)) () ())
              (member? op '(addsd subsd mulsd divsd movsd ucomisd cvtss2sd cvtsd2ss)) (L () () ())
              (member? op '(div rem udiv urem))
               (L (cat (rg1 (cauup f)) (rg1 (caup (cuup f)))) (L 'r0 'r1 'r2 'r3) ())
              (member? op '(shlv shrv sarv)) (L (L (caup f) (cauup f)) (L (caup f) 'r1) ())
              'bar))
       (go l dead acc)                               ; l already REVERSED; acc rebuilds forward
        (? (! (two? l)) acc
           (: f (cap l) r (cup l)
              (? (! (two? f)) (go r dead (link f acc))
                 (: rd (rdsp f)
                    (? (id? rd 'bar) (go r (tablet 0) (link f acc))
                       (: reads (cap rd) defs (caup rd) pure (cauup rd)
                          (dd? ds) (? (! (two? ds)) 1
                                      (? (peep dead (cap ds) ()) (dd? (cup ds)) ()))
                          (? (&& pure (&& (two? defs) (dd? defs)))
                             (go r dead acc)                     ; every def overwritten unread: drop
                             (: _ ((: (ad ds) (? (! (two? ds)) 1
                                                 (: _ (? (id? (cap ds) 'sp) () (pin dead (cap ds) 1))
                                                    (ad (cup ds)))) ad) defs)
                                _ ((: (rm rs) (? (! (two? rs)) 1
                                                 (: _ (pin dead (cap rs) ()) (rm (cup rs)))) rm) reads)
                                (go r dead (link f acc))))))))))
       (go (rev fs) (tablet 0) ()))

   ; adjacent sp adjustments MERGE (nothing observes the point between two
   ; touching adds); a cancelled pair vanishes -- the husk a dead cell leaves
   (spadj? f) (&& (two? f) (&& (member? (cap f) '(add sub))
                (&& (= (caup f) 'sp) (&& (= (cauup f) 'sp) (charm? (caup (cuup f)))))))
   (spmerge fs)
    (? (! (two? fs)) ()
       (: f (cap fs) r (cup fs)
          nx (? (two? r) (cap r) ())
          (? (&& (spadj? f) (spadj? nx))
             (: n1 (? (= (cap f) 'add) (caup (cuup f)) (- 0 (caup (cuup f))))
                n2 (? (= (cap nx) 'add) (caup (cuup nx)) (- 0 (caup (cuup nx))))
                net (+ n1 n2)
                (? (= net 0) (spmerge (cup r))
                   (< net 0) (spmerge (link (L 'sub 'sp 'sp (- 0 net)) (cup r)))
                   (spmerge (link (L 'add 'sp 'sp net) (cup r)))))
             (link f (spmerge r)))))

   ; dead frame stores: after the constant folds, a slot the function never
   ; loads back is write-only -- its stores drop (the b2w-shape arg temps whose
   ; every read folded to a li). SAFE only when NO frame address is taken at
   ; all (any lea/lean of r4 skips the pass: an lea marks one offset but hands
   ; out a RANGE -- a va save area, an aggregate fill -- so per-offset liveness
   ; would lie). a store's newly-dead feeding li sweeps in the same pass.
   (deadst fs)
    (: used (tablet 0) esc (tablet 0)
       (scan l) (? (! (two? l)) 1
                   (: f (cap l)
                      _ (? (! (two? f)) ()
                           (member? (cap f) '(ld ld1 ld2 ld4 ldu1 ldu2 ldu4))
                            (? (= (cauup f) 'r4) (pin used (caup (cuup f)) 1) ())
                           (member? (cap f) '(ldsd ldss))
                            (? (= (cauup f) 'r4) (pin used (caup (cuup f)) 1) ())
                           (member? (cap f) '(lea lean))
                            (? (= (cauup f) 'r4) (pin esc 'y 1) ())
                           ())
                      (scan (cup l))))
       _ (scan fs)
       (drop l) (? (! (two? l)) ()
                   (: f (cap l)
                      (? (&& (two? f) (&& (member? (cap f) '(st st1 st2 st4 stsd stss))
                             (&& (= (caup f) 'r4) (! (peep used (cauup f) ())))))
                         (drop (cup l))
                         (link f (drop (cup l))))))
       (lisweep l) (? (! (two? l)) ()
                      (: f (cap l) nx (? (two? (cup l)) (cap (cup l)) ())
                         (? (&& (two? f) (&& (= (cap f) 'li)
                               (&& (two? nx) (&& (member? (cap nx) '(li mov)) (= (caup nx) (caup f))))))
                            (lisweep (cup l))
                            (link f (lisweep (cup l))))))
       (? (peep esc 'y ()) fs (lisweep (drop fs))))

   ; store-forward: a full-word frame store followed by ITS OWN reload reads the
   ; register instead -- (st r4 o rX) (ld rY r4 o) keeps the store and turns the
   ; reload into a mov (the same-register form drops it). the narrow loads
   ; (ld4 ..) keep their memory round-trip: they re-extend, a different value.
   (stld fs)
    (? (! (two? fs)) ()
       (: f (cap fs) r (cup fs)
          (? (! (&& (two? r) (&& (two? f) (&& (= (cap f) 'st) (= (caup f) 'r4)))))
             (link f (stld r))
             (: nx (cap r)
                rX (caup (cuup f))
                (? (! (&& (two? nx) (&& (= (cap nx) 'ld)
                          (&& (= (cauup nx) 'r4) (= (caup (cuup nx)) (cauup f))))))
                   (link f (stld r))
                   (: rY (caup nx)
                      (? (= rY rX) (link f (stld (cup r)))
                         (link f (link (L 'mov rY rX) (stld (cup r)))))))))))

   ; -- aggregate initializers: ('init (item..)), items plain | ('dfield
   ; name val) | ('didx n val), nesting for arrays of structs. shared bits: --
   (aggish? ty) (|| (arr? ty) (stru? ty))
   (elval it) (? (member? (cap it) '(dfield didx)) (caup (cup it)) it)   ; the value of an item
   (fidx fields name) (: (go l i) (? (! (two? l)) 0 (= (cap (cap l)) name) i (go (cup l) (+ i 1)))
                          (go fields 0))
   (nthfield fields i) (: (go l k) (? (! (two? l)) 'bad (< k 1) (cap l) (go (cup l) (- k 1)))
                           (go fields i))

   ; -- LOCAL init (codegen): zero the slot, then fill (values may be runtime) --
   (cgzero off span)                                ; zero [r4+off .. +span)
    (: (go o rem acc)
        (? (<= 8 rem) (go (+ o 8) (- rem 8) (cat acc (L (L 'st 'r4 o 'r0))))
           (< 0 rem) (go (+ o 1) (- rem 1) (cat acc (L (L 'st1 'r4 o 'r0))))
           acc)
       (cat (L (L 'li 'r0 0)) (go off span ())))
   (cgstr off text)                                 ; a char array from a string: byte stores (NUL from the zero)
    (: (go i acc) (? (< i 0) acc (go (- i 1) (cat (L (L 'li 'r0 (text i)) (L 'st1 'r4 (+ off i) 'r0)) acc)))
       (go (- (tally text) 1) ()))
   (cgstore g env off ty val)                       ; store a scalar value expr into [r4+off]
    (: r (cgexpr g env val)
       (? (bad? r) 'bad
          (flo? ty) (cat (asflo g r) (fstf ty 'r4 off 'f0))
          (cat (asint g r) (cat (cvt ty 'r0) (L (L (stop ty) 'r4 off 'r0))))))
   (cgfill g env off ty ini)                        ; fill an aggregate at frame offset off (no zero)
    (? (= (cap ini) 'str) (? (arr? ty) (cgstr off (caup ini)) 'bad)
       (! (= (cap ini) 'init)) 'bad
       (arr? ty)
        (: elt (caup ty) esz (tsz g elt)
           (fill l idx acc)
            (? (! (two? l)) acc
               (: it (cap l)
                  ci (? (= (cap it) 'didx) (caup it) idx)
                  val (elval it)
                  eoff (+ off (* ci esz))
                  r (? (&& (aggish? elt) (= (cap val) 'init)) (cgfill g env eoff elt val)
                       (cgstore g env eoff elt val))
                  (? (bad? r) 'bad (fill (cup l) (+ ci 1) (cat acc r)))))
           (fill (caup ini) 0 ()))
       (stru? ty)
        (: fields (cap (peep (g 'stag) (caup ty) 0))
           (fill l cur acc)
            (? (! (two? l)) acc
               (: it (cap l)
                  ci (? (= (cap it) 'dfield) (fidx fields (caup it)) cur)
                  val (elval it)
                  fe (nthfield fields ci)
                  (? (bad? fe) 'bad
                     (: foff (+ off (caup fe)) fty (cauup fe)
                        r (? (&& (aggish? fty) (= (cap val) 'init)) (cgfill g env foff fty val)
                             (cgstore g env foff fty val))
                        (? (bad? r) 'bad (fill (cup l) (+ ci 1) (cat acc r)))))))
           (fill (caup ini) 0 ()))
       'bad)

   ; -- GLOBAL init (a constant byte image, where a scalar is little-endian
   ; bytes, an aggregate a placement flatten, and a POINTER an abs64 fixup --
   ; ('fix 8 abs64 label 0), the label's absolute address, laid by holo/elf.
   ; a fixup is ONE list item but eight bytes, so lengths go through imbytelen. --
   (fixit? x) (&& (two? x) (= (cap x) 'fix))
   (imbytelen l) (foldl (\ a x (+ a (? (fixit? x) (caup x) 1))) 0 l)
   (imnum g ty val) (: n (tsz g ty) (go i acc) (? (<= n i) (rev acc)
                                                   (go (+ i 1) (link (& (>> val (* 8 i)) 255) acc)))
                       (go 0 ()))
   (iminsert x l) (? (! (two? l)) (L x)                 ; insert (off items) keeping offsets ascending
                     (< (cap x) (cap (cap l))) (link x l)
                     (link (cap l) (iminsert x (cup l))))
   (imsort ps) (: (go l acc) (? (! (two? l)) acc (go (cup l) (iminsert (cap l) acc))) (go ps ()))
   (imflat ps total)                                ; sorted (off items).. -> total bytes, gaps zeroed
    (: (go l pos acc)
        (? (! (two? l)) (cat acc (zeros (- total pos)))
           (: p (cap l) off (cap p) items (caup p)
              (go (cup l) (+ off (imbytelen items)) (cat acc (cat (zeros (- off pos)) items)))))
       (go ps 0 ()))
   ; a CONSTANT integer expression at image time -> its value | 'no. C's static
   ; initializers permit any int const-expr in an array subscript / pointer
   ; offset (`&a[2*K+1]`), so fold the arithmetic here. `//` truncates toward
   ; zero (C's `/`); the machine ops (<<, &..) wrap at the word, as cc's do.
   (icfold e)
    (? (! (two? e)) 'no
       (= (cap e) 'num) (caup e)
       (= (cap e) 'cast) (: v (icfold (cauup e)) (? (id? v 'no) 'no (flo? (caup e)) 'no v))
       (= (cap e) 'un)
        (: v (icfold (cauup e))
           (? (id? v 'no) 'no (= (caup e) 'neg) (- 0 v) (= (caup e) 'bnot) (- (- 0 v) 1) 'no))
       (= (cap e) 'bin)
        (: op (caup e) a (icfold (cauup e)) b (icfold (caup (cuup e)))
           (? (|| (id? a 'no) (id? b 'no)) 'no
              (= op '+) (+ a b) (= op '-) (- a b) (= op '*) (* a b)
              (= op '/) (? (= b 0) 'no (// a b)) (= op '%) (? (= b 0) 'no (- a (* (// a b) b)))
              (= op 'shl) (<< a b) (= op 'shr) (>> a b)
              (= op '&) (& a b) (= op '|) (| a b) (= op '^) (^ a b)
              'no))
       'no)
   ; a CONSTANT LVALUE at image time -> (label byteoffset type) | 'no: a
   ; file-scope global, a *(const pointer) (an array subscript desugars here --
   ; a[i] is *(a+i)), or a .member off either. the type threads so pointer
   ; arithmetic and the next .member scale/offset correctly.
   (imlval g e)
    (? (= (cap e) 'var)
        (? (peep (g 'fns) (caup e) ()) (L (intern (caup e)) 0 (fnty g (caup e)))   ; a function IS its address
           (: en (peep (g 'glob) (caup e) 0)                                       ; glob = (label type init)
              (? (two? en) (L (cap en) 0 (caup en)) 'no)))
       (= (cap e) 'deref)
        (: p (imaddr g (caup e)) (? (id? p 'no) 'no (L (cap p) (caup p) (caup (cauup p)))))
       (= (cap e) 'dot)
        (: b (imlval g (caup e))
           (? (id? b 'no) 'no
              (: fm (fmem g (cauup b) (cauup e)) (? (bad? fm) 'no (L (cap b) (+ (caup b) (cap fm)) (caup fm))))))
       'no)
   ; a CONSTANT ADDRESS expression at image time -> (label byteoffset ptrtype) |
   ; 'no: a string / function / decayed-array global (offset 0), &lvalue (the
   ; lvalue's address), or pointer +/- an int constant (scaled by the pointee).
   ; a cast retypes (so a later + scales by the new pointee). subsumes what a
   ; pointer initializer used to take and adds every label+constant-offset form.
   (imaddr g e)
    (? (= (cap e) 'cast)
        (: r (imaddr g (cauup e))                        ; a cast RETYPES the address (its type is the cast's) --
           (? (id? r 'no) 'no (L (cap r) (caup r) (caup e))))   ; so a later + scales (or doesn't) by the cast type
       (= (cap e) 'str)
        (: l (nlab g ".S") _ (pin g 'strs (link (L l (caup e)) (g 'strs))) (L l 0 (L 'ptr 'char)))
       (= (cap e) 'var)
        (? (peep (g 'fns) (caup e) ()) (L (intern (caup e)) 0 (L 'ptr (fnty g (caup e))))
           (: en (peep (g 'glob) (caup e) 0)
              (? (! (two? en)) 'no
                 (: ty (caup en) (? (arr? ty) (L (cap en) 0 (L 'ptr (caup ty))) (L (cap en) 0 (L 'ptr ty)))))))
       (= (cap e) 'addr)
        (: lv (imlval g (caup e)) (? (id? lv 'no) 'no (L (cap lv) (caup lv) (L 'ptr (cauup lv)))))
       (&& (= (cap e) 'bin) (member? (caup e) '(+ -)))
        ; label +/- an int constant. a POINTER type scales the constant by the
        ; pointee (C pointer arithmetic); an integer-typed label ((word)&x + 8)
        ; adds the raw bytes -- so scale by the pointee ONLY when it's a pointer.
        (: op (caup e)
           (imscale ty) (? (ptr? ty) (tsz g (caup ty)) 1)
           pa (imaddr g (cauup e)) kb (icfold (caup (cuup e)))
           (? (&& (! (id? pa 'no)) (! (id? kb 'no)))
               (L (cap pa) (+ (caup pa) (* (? (= op '-) (- 0 kb) kb) (imscale (cauup pa)))) (cauup pa))
              (: pb (imaddr g (caup (cuup e))) ka (icfold (cauup e))
                 (? (&& (&& (= op '+) (! (id? pb 'no))) (! (id? ka 'no)))
                     (L (cap pb) (+ (caup pb) (* ka (imscale (cauup pb)))) (cauup pb))
                    'no))))
       'no)
   ; a const FLOAT expression at image time -> its gem | 'bad. the int cfold
   ; lives at parse (array dims); floats fold here where the image lays them
   ; (`static const double toint = 1/DBL_EPSILON;` -- fdlibm's opener).
   ; same IEEE doubles as the target, so the fold is the runtime value.
   (ffold e)
    (? (! (two? e)) 'bad
       (= (cap e) 'flo) (caup e)
       (= (cap e) 'num) (+ 0.0 (caup e))
       (= (cap e) 'cast) (? (flo? (caup e)) (ffold (cauup e)) 'bad)
       (= (cap e) 'un)
        (: v (ffold (cauup e))
           (? (bad? v) 'bad (= (caup e) 'neg) (- 0.0 v) 'bad))
       (= (cap e) 'bin)
        (: op (caup e) a (ffold (cauup e)) b (ffold (caup (cuup e)))
           (? (|| (bad? a) (bad? b)) 'bad
              (= op '+) (+ a b) (= op '-) (- a b) (= op '*) (* a b)
              (= op '/) (? (= b 0.0) 'bad (/ a b))
              'bad))
       'bad)
   (imgbytes g ty ini)                              ; a byte/fix list of length tsz(ty) | 'bad
    (? (! (two? ini)) (zeros (tsz g ty))
       (= (cap ini) 'flo) (? (= ty 'float) (le4s (fbits32 (caup ini)))    ; a float literal -> 4 IEEE single bytes
                             (flo? ty) (le8s (fbits (caup ini))) 'bad)     ; a double literal -> 8 IEEE bytes
       (= (cap ini) 'num) (? (aggish? ty) 'bad (= ty 'float) (le4s (fbits32 (+ 0.0 (caup ini))))
                             (flo? ty) (le8s (fbits (+ 0.0 (caup ini)))) (imnum g ty (caup ini)))
       (&& (flo? ty) (member? (cap ini) '(bin un cast)))   ; a const float expression: fold, then image
        (: v (ffold ini)
           (? (bad? v) 'bad (= ty 'float) (le4s (fbits32 v)) (le8s (fbits v))))
       (&& (= (cap ini) 'str) (arr? ty))
        (: t (caup ini) n (tsz g ty)
           (bs i acc) (? (<= n i) (rev acc) (bs (+ i 1) (link (? (< i (tally t)) (t i) 0) acc)))
           (bs 0 ()))
       (ptr? ty) (: r (imaddr g ini)                    ; a data pointer: a constant ADDRESS (abs64 label+offset),
                     (? (! (id? r 'no)) (L (L 'fix 8 'abs64 (cap r) (caup r)))   ; or a constant INTEGER ((int*)0x1000, a null)
                        (: v (icfold ini) (? (id? v 'no) 'bad (imnum g ty v)))))
       ; a label cast to a WORD-SIZED integer ((word)nif_absent, (intptr_t)f) is
       ; still the label's address; a non-label cast folds through to its value
       (&& (= (cap ini) 'cast) (&& (! (aggish? ty)) (&& (! (flo? ty)) (= (tsz g ty) 8))))
        (: r (imaddr g ini)
           (? (! (id? r 'no)) (L (L 'fix 8 'abs64 (cap r) (caup r))) (imgbytes g ty (cauup ini))))
       (= (cap ini) 'init)
        (? (arr? ty)
            (: elt (caup ty) esz (tsz g elt)
               (place l idx acc)                     ; -> ((off items)..) | 'bad
                (? (! (two? l)) acc
                   (: it (cap l)
                      ci (? (= (cap it) 'didx) (caup it) idx)
                      eb (imgpad g elt esz (elval it))
                      (? (bad? eb) 'bad (place (cup l) (+ ci 1) (link (L (* ci esz) eb) acc)))))
               ps (place (caup ini) 0 ())
               (? (bad? ps) 'bad (imflat (imsort ps) (* (cauup ty) esz))))
           (stru? ty)
            (: e (peep (g 'stag) (caup ty) 0)
               fields (cap e) size (caup e)
               (place l cur acc)
                (? (! (two? l)) acc
                   (: it (cap l)
                      ci (? (= (cap it) 'dfield) (fidx fields (caup it)) cur)
                      fe (nthfield fields ci)
                      (? (bad? fe) 'bad
                         (: fb (imgpad g (cauup fe) (tsz g (cauup fe)) (elval it))
                            (? (bad? fb) 'bad (place (cup l) (+ ci 1) (link (L (caup fe) fb) acc)))))))
               ps (place (caup ini) 0 ())
               (? (bad? ps) 'bad (imflat (imsort ps) size)))
           'bad)
       'bad)
   (imgpad g ty w val)                              ; imgbytes padded (with zeros) to w bytes | 'bad
    (: b (imgbytes g ty val) (? (bad? b) 'bad (cat b (zeros (- w (imbytelen b))))))
   (cgimage g ty ini)                               ; the full span-padded image | 'bad
    (: span (& (+ (tsz g ty) 7) -8)
       raw (imgbytes g ty ini)
       (? (bad? raw) 'bad (cat raw (zeros (- span (imbytelen raw))))))

   ; a declaration list ((name ty init)..): slots by SIZE (rounded to 8),
   ; extends env -> (forms env) | 'bad. aggregate + string locals zero the
   ; slot then fill; a scalar takes its value; only a label-valued global image
   ; refuses (4d).
   ; -- the locals-homing hook: every homable scalar local (outside an inline
   ; splice) ticks a decl SEQUENCE number, records (seq off ty) in g 'lrec
   ; (pass 1 reads it back to rank candidates), and asks g 'lhome (seq ->
   ; register, pinned only for a REGEN) for a home. a homed local keeps its
   ; slot as the spill shadow (g 'homes wraps it around calls, exactly a
   ; homed param), binds (reg rN) in the env -- so a READ is a zero-form
   ; borrow on the phase-1 contract, which is why this pays now where the
   ; r0-shuttle version lost -- and its init lands with a mov. the seq is
   ; deterministic across pass 1 and the regen (same walk; splices don't
   ; tick, and a mis-target only ever deopts through &-local's 'bad). --
   (cgdecl g env pairs)
    (: (one ps env2 acc)
        (? (! (two? ps)) (L acc env2)
           (: _ (pin g 'pool (peep g 'pool0 ()))
              p (cap ps)
              ty (caup p)
              init (cauup p)
              span (& (+ (tsz g ty) 7) -8)
              off (- 0 (+ (peep g 'off 0) span))
              _ (pin g 'off (+ (peep g 'off 0) span))
              hreg (? (|| (peep g 'inlining ()) (! (homable? ty))) ()
                      (: sq (+ 1 (peep g 'dseq 0))
                         _ (pin g 'dseq sq)
                         _ (pin g 'lrec (link (L sq off ty) (peep g 'lrec ())))
                         lht (peep g 'lhome ())
                         (? lht (peep lht sq ()) ())))
              env3 (link (L (cap p) (? hreg (L 'reg hreg) off) ty) env2)
              _ (? hreg (pin g 'homes (link (L hreg off) (peep g 'homes ()))) ())
              (? (! (two? init)) (one (cup ps) env3 acc)
                 (|| (= (cap init) 'init) (&& (= (cap init) 'str) (arr? ty)))
                  (? (&& (= (cap init) 'init) (! (aggish? ty))) 'bad   ; a brace for a scalar
                     (: f (cgfill g env3 off ty init)
                        (? (bad? f) 'bad
                           (one (cup ps) env3 (cat acc (cat (cgzero off span) f))))))
                 (arr? ty) 'bad                          ; a bare-expr init of an array
                 (stru? ty)                              ; a struct local from a struct VALUE (an address): copy its bytes
                  (: r (cgexpr g env3 init)
                     (? (bad? r) 'bad
                        (: sz (tsz g ty)
                           cpf (: (go k acc9)
                                   (? (<= 8 (- sz k)) (go (+ k 8) (cat acc9 (L (L 'ld 'r1 'r0 k) (L 'st 'r4 (+ off k) 'r1))))
                                      (<= 4 (- sz k)) (go (+ k 4) (cat acc9 (L (L 'ld4 'r1 'r0 k) (L 'st4 'r4 (+ off k) 'r1))))
                                      (<= 2 (- sz k)) (go (+ k 2) (cat acc9 (L (L 'ld2 'r1 'r0 k) (L 'st2 'r4 (+ off k) 'r1))))
                                      (<= 1 (- sz k)) (go (+ k 1) (cat acc9 (L (L 'ld1 'r1 'r0 k) (L 'st1 'r4 (+ off k) 'r1))))
                                      acc9)
                                  (go 0 ()))
                           (one (cup ps) env3 (cat acc (cat (tor0 g r) cpf))))))
                 (: r (cgexpr g env3 init)               ; a scalar (a pointer = string rides cgexpr -> la)
                    (? (bad? r) 'bad
                       (flo? ty) (one (cup ps) env3 (cat acc (cat (asflo g r) (fstf ty 'r4 off 'f0))))
                       hreg (one (cup ps) env3           ; a homed local's init is a register move
                                 (cat acc (cat (asint g r) (L (L 'mov hreg 'r0)))))
                       (one (cup ps) env3
                            (cat acc (cat (asint g r)
                                     (cat (cvt ty 'r0)
                                          (L (L (stop ty) 'r4 off 'r0)))))))))))
       (one pairs env ()))

   ; block-scope `static` ((name ty init)..): each name gets a UNIQUE global
   ; laid in .bss/.data (persists across calls, one instance), NOT a stack slot.
   ; the name binds in the LOCAL env to a (glob lbl) marker (so it shadows outer
   ; names + is distinct per function), and vent turns that into a 'glo the same
   ; read/write/& paths a file-scope global already use. no runtime init code --
   ; a static's initializer is a compile-time constant image (cgdata emits it via
   ; cgimage, exactly like a file-scope global; a non-constant init -> 'bad there).
   ; -> (forms env) | 'bad, the same shape as cgdecl.
   (cgsdecl g env pairs)
    (: (one ps env2)
        (? (! (two? ps)) (L () env2)
           (: p (cap ps)
              name (cap p) ty (caup p) init (cauup p)
              lbl (nlab g (+ (g 'fn) "."))           ; `fn.N` -- the `.` bars any C-identifier collision
              _ (pin (g 'glob) lbl (L lbl ty init))   ; a LOCAL data label (internal linkage): g 'statics,
              _ (pin g 'statics (link lbl (g 'statics)))  ; NOT g 'globs -- a static is never an exported symbol
              (one (cup ps) (link (L name (L 'glob lbl) ty) env2))))
       (one pairs env))

   ; stmt -> forms | 'bad
   (cgstmt g env s)
    (: _ (pin g 'pool (peep g 'pool0 ()))            ; a statement never carries a live operand in
       k (cap s)
       (? (= k 'ret)                                                     ; inside an inline splice a return JUMPS to the
          (: il (peep g 'inlret ())                                      ; splice's end label instead of the epilogue
             (? (! (two? (caup s))) (? il (L (L 'jmp il)) epi)           ; bare `return;` -- just the epilogue
                (: _ (pin g 'want 'r0)                                   ; the return value's one true home
                   r (cgexpr g env (caup s))
                   rt (? il (peep g 'inlrt 'long)                        ; the INLINED function's return type
                         (cap (peep (g 'sigs) (g 'fn) (L 'long ()))))    ; else the current function's
                   (? (bad? r) 'bad
                      (flo? rt) (cat (asflo g r) epi)                    ; a double return leaves f0 (xmm0; never inline -- gated)
                      (sse2? g rt)                                       ; a two-double struct returns as the xmm PAIR
                       (cat (tor0 g r) (cat (fldf 'double (xmmreg 0) 'r0 0)
                                       (cat (fldf 'double (xmmreg 1) 'r0 8) epi)))
                      (ipair? g rt)                                      ; a two-int struct returns as rax:rdx (r0:r2)
                       (cat (tor0 g r) (cat (L (L 'ld 'r2 'r0 8) (L 'ld 'r0 'r0 0)) epi))
                      (id? (aone g rt) 'sse)                             ; a small SSE aggregate: its eightbyte in xmm0
                       (cat (tor0 g r) (cat (fldf 'double (xmmreg 0) 'r0 0) epi))
                      (id? (aone g rt) 'int)                             ; a small INT aggregate (a union rides here): rax
                       (cat (tor0 g r) (cat (L (L 'ld 'r0 'r0 0)) epi))
                      (|| (stru? rt) (stru? (vty r))) 'bad               ; a MIXED 16-byte pair or >16 bytes (MEMORY): still refused
                      (flo? (vty r)) (cat (asint g r) (? il (L (L 'jmp il)) epi))   ; a double value, an int return -> truncate to r0
                      (cat (tor0 g r) (? il (L (L 'jmp il)) epi))))))    ; int -> int, as before
          (= k 'expr)
           (: pe (caup s)
              rv (? (&& (= (cap pe) 'post) (= (cap (caup pe)) 'var))
                    (vent g env (caup (caup pe))) 'bad)
              (? (&& (two? rv) (= (cap rv) 'regv))   ; a statement-position x++ on a home: the old value is dead
                  (: ty (cauup rv) stp (? (ptr? ty) (tsz g (caup ty)) 1)
                     (L (L 'add (caup rv) (caup rv) (* stp (cauup pe)))))
                 (: r (cgexpr g env pe)
                    (? (bad? r) 'bad (vdrop g r)))))
          (= k 'nop) ()
          (= k 'tdef) ()                            ; a block-scope _Static_assert (already checked at parse)
          (= k 'blk) (cgitems g env (caup s) ())
          (= k 'if)
           (: le (nlab g ".e")
              c (cbranch g env (caup s) 'eq le)
              t (cgstmt g env (cauup s))
              (? (|| (bad? c) (bad? t)) 'bad
                 (! (two? (caup (cuup s))))
                  (cat c (cat t (L (L 'label le))))
                 (: el (cgstmt g env (caup (cuup s)))
                    ld (nlab g ".d")
                    (? (bad? el) 'bad
                       (cat c
                        (cat t (cat (L (L 'jmp ld) (L 'label le))
                         (cat el (L (L 'label ld))))))))))
          (= k 'while)
           (: lc (nlab g ".c") ld (nlab g ".d")
              c (cbranch g env (caup s) 'eq ld)
              _ (pin g 'brk (link ld (g 'brk)))
              _ (pin g 'cnt (link lc (g 'cnt)))
              b (cgstmt g env (cauup s))
              _ (pin g 'brk (cup (g 'brk)))
              _ (pin g 'cnt (cup (g 'cnt)))
              (? (|| (bad? c) (bad? b)) 'bad
                 (cat (L (L 'label lc))
                  (cat c
                   (cat b (L (L 'jmp lc) (L 'label ld)))))))
          (= k 'for)
           (: init (caup s) cnd (cauup s) stp (caup (cuup s)) body (cauup (cuup s))
              lc (nlab g ".c") ls (nlab g ".s") ld (nlab g ".d")
              ir (? (! (two? init)) (L () env)
                    (= (cap init) 'decl) (cgdecl g env (caup init))
                    (= (cap init) 'sdecl) (cgsdecl g env (caup init))
                    (: r (cgexpr g env (caup init))
                       (? (bad? r) 'bad (L (vdrop g r) env))))
              (? (bad? ir) 'bad
                 (: env2 (caup ir)
                    c (? (two? cnd) (cbranch g env2 cnd 'eq ld) ())
                    _ (pin g 'brk (link ld (g 'brk)))
                    _ (pin g 'cnt (link ls (g 'cnt)))
                    b (cgstmt g env2 body)
                    _ (pin g 'brk (cup (g 'brk)))
                    _ (pin g 'cnt (cup (g 'cnt)))
                    st2 (? (two? stp) (cgexpr g env2 stp) ())
                    (? (|| (bad? c) (|| (bad? b) (bad? st2))) 'bad
                       (cat (cap ir)
                        (cat (L (L 'label lc))
                         (cat (? (two? cnd) c ())
                          (cat b
                           (cat (L (L 'label ls))
                            (cat (? (two? st2) (vdrop g st2) ())
                                 (L (L 'jmp lc) (L 'label ld))))))))))))
          (= k 'brk) (? (two? (g 'brk)) (L (L 'jmp (cap (g 'brk)))) 'bad)
          (= k 'cont) (? (two? (g 'cnt)) (L (L 'jmp (cap (g 'cnt)))) 'bad)
          (= k 'do)
           (: lt (nlab g ".t") lc (nlab g ".c") ld (nlab g ".d")
              _ (pin g 'brk (link ld (g 'brk)))
              _ (pin g 'cnt (link lc (g 'cnt)))
              b (cgstmt g env (caup s))
              _ (pin g 'brk (cup (g 'brk)))
              _ (pin g 'cnt (cup (g 'cnt)))
              c (cbranch g env (cauup s) 'ne lt)
              (? (|| (bad? b) (bad? c)) 'bad
                 (cat (L (L 'label lt))
                  (cat b
                   (cat (L (L 'label lc))
                    (cat c (L (L 'label ld))))))))
          (= k 'goto) (L (L 'jmp (intern (+ (g 'fn) (+ "." (caup s))))))
          (= k 'lbl) (L (L 'label (intern (+ (g 'fn) (+ "." (caup s))))))
          (= k 'switch)
           (: c (cgexpr g env (caup s))
              (? (bad? c) 'bad
                 (: items (cauup s)
                    cr9 (vreg c)
                    lend (nlab g ".d")
                    labs (: (mk is acc)
                             (? (! (two? is)) (rev acc)
                                (: it (cap is)
                                   (? (= (cap it) 'case)
                                      (mk (cup is) (link (L 'case (caup it) (nlab g ".k")) acc))
                                      (= (cap it) 'dflt)
                                      (mk (cup is) (link (L 'dflt 0 (nlab g ".k")) acc))
                                      (mk (cup is) acc))))
                            (mk items ()))
                    dflt (: (fd l) (? (! (two? l)) lend
                                      (= (cap (cap l)) 'dflt) (cauup (cap l))
                                      (fd (cup l)))
                            (fd labs))
                    disp (: (go l acc)
                             (? (! (two? l)) acc
                                (: e2 (cap l)
                                   (? (= (cap e2) 'case)
                                      (go (cup l) (cat acc (L (L 'cmp cr9 (caup e2))
                                                              (L 'br 'eq (cauup e2)))))
                                      (go (cup l) acc))))
                            (go labs ()))
                    _ (rfree g cr9)
                    _ (pin g 'brk (link lend (g 'brk)))
                    body (: (go is ls env2 acc)
                             (? (! (two? is)) acc
                                (: it (cap is)
                                   (? (member? (cap it) '(case dflt))
                                      (go (cup is) (cup ls) env2
                                          (cat acc (L (L 'label (cauup (cap ls))))))
                                      (= (cap it) 'decl)
                                       (: r (cgdecl g env2 (caup it))
                                          (? (bad? r) 'bad
                                             (go (cup is) ls (caup r) (cat acc (cap r)))))
                                      (= (cap it) 'sdecl)
                                       (: r (cgsdecl g env2 (caup it))
                                          (? (bad? r) 'bad
                                             (go (cup is) ls (caup r) (cat acc (cap r)))))
                                      (: r (cgstmt g env2 it)
                                         (? (bad? r) 'bad
                                            (go (cup is) ls env2 (cat acc r)))))))
                            (go items labs env ()))
                    _ (pin g 'brk (cup (g 'brk)))
                    (? (bad? body) 'bad
                       (cat (vfs c)
                        (cat disp
                         (cat (L (L 'jmp dflt))
                          (cat body (L (L 'label lend))))))))))
          'bad))
   (cgitems g env items acc)
    (? (! (two? items)) acc
       (: it (cap items)
          (? (= (cap it) 'decl)
             (: r (cgdecl g env (caup it))
                (? (bad? r) 'bad
                   (cgitems g (caup r) (cup items) (cat acc (cap r)))))
             (= (cap it) 'sdecl)
             (: r (cgsdecl g env (caup it))
                (? (bad? r) 'bad
                   (cgitems g (caup r) (cup items) (cat acc (cap r)))))
             (: r (cgstmt g env it)
                (? (bad? r) 'bad
                   (cgitems g env (cup items) (cat acc r)))))))

   ; -- the inline lane (the b2w problem): a SMALL function splices its whole
   ; body at the call site -- each arg value lands in a fresh 8-byte frame temp
   ; (exactly a callee frame's param slot, so the semantics are the out-of-line
   ; call's: full-word stores, (ldop pty) reads), the body's statements compile
   ; in place (decls become caller temps), and every `return` computes its value
   ; into r0 then JUMPS to the splice's end label (cgstmt's inlret door -- so
   ; the ai_nilp if-chain shape inlines, not just a single-return body). no call
   ; is emitted, so a hot caller can turn LEAF and its params take register
   ; homes -- the gcc win on the dispatch ops twice over: no call overhead AND
   ; no frame reloads. depth 1: a body being inlined compiles its own calls
   ; out-of-line (the g 'inlining flag). gated out: goto/labels (two splices of
   ; one body in one caller would collide), block statics (each splice would
   ; mint a SEPARATE instance -- C owes one), va_start. --
   (noinl? x) (? (member? x '(sdecl goto lbl vastart)) 1
                 (! (two? x)) ()
                 (|| (noinl? (cap x)) (noinl? (cup x))))
   (oneret? items)                                  ; decls* + one trailing `return expr` (the b2w shape)
    (? (! (two? items)) ()
       (: it (cap items)
          (? (= (cap it) 'decl) (oneret? (cup items))
             (&& (= (cap it) 'ret) (&& (two? (caup it)) (! (two? (cup items))))))))
   (inlok? f sig)
    (: rt (? (two? sig) (cap sig) 'long)
       items (caup (caup (cuup f)))
       (pok ps n) (? (! (two? ps)) (<= n 6)
                     (: pty (caup (cap ps))
                        (? (|| (flo? pty) (|| (stru? pty) (arr? pty))) ()
                           (pok (cup ps) (+ n 1)))))
       (? (! (two? sig)) ()
          (|| (flo? rt) (stru? rt)) ()
          (nthr sig 2) ()                            ; variadic stays a real call
          (! (pok (cauup f) 0)) ()
          ; a straight-line single-return body pays broadly (600); a branchy one
          ; only while TINY (250, the guard shape) -- big if-chains bloat icache
          (< (? (oneret? items) 600 250) (tally (show (caup (cuup f))))) ()
          (! (noinl? (caup (cuup f))))))
   (cginl g env f args)                              ; splice f's body at the site -> (ty forms) | 'no (declined)
    (: fe0 (peep g 'fesc ())                          ; a splice that pins a CLEAR fesc would cost the CALLER
       strs0 (g 'strs)                                ; every sibcall (the lvm_peep stack blowup) -- decline it
       _ (pin g 'inlining 1)
       rt (cap (peep (g 'sigs) (caup f) (L 'long ())))
       ilb9 (nlab g ".il")
       (bind ps as benv acc)                         ; arg values -> fresh full-word slots, left to right
        (? (! (two? ps)) (L benv acc)
           (: r (cgexpr g env (cap as))
              (? (bad? r) 'bad
                 (: off (ntmp g 'long)
                    (bind (cup ps) (cup as)
                          (link (L (cap (cap ps)) off (caup (cap ps))) benv)
                          (cat acc (cat (asint g r) (L (L 'st 'r4 off 'r0)))))))))
       br (bind (cauup f) args () ())
       _ (pin g 'inlret ilb9)
       _ (pin g 'inlrt rt)
       ibd (? (bad? br) 'bad ((g 'cgitems) g (cap br) (caup (caup (cuup f))) ()))
       _ (pin g 'inlret ())
       _ (pin g 'inlining ())
       (? (|| (bad? br) (bad? ibd))                   ; a shape the splice can't take: the real call still can
           (: _ (pin g 'fesc fe0) _ (pin g 'strs strs0) 'no)
          (&& (! fe0) (peep g 'fesc ()))              ; the body took a frame address: keep the caller lean
           (: _ (pin g 'fesc ()) _ (pin g 'strs strs0) 'no)
          (mkv rt 'r0 (cat (caup br) (cat ibd (L (L 'label ilb9)))))))

   (cgfn g f)                                       ; ('fn name params ('blk items)) -> forms | 'bad
    (: params (cauup f)
       _ (pin g 'off 8)                              ; slot -8 = saved r3 (see epi)
       _ (pin g 'fesc ())                            ; fresh escape flag (the sibcall gate reads it)
       _ (pin g 'inlining ())                        ; fresh inline-depth flag
       _ (pin g 'inlret ())                          ; fresh inline-return label (cgstmt's ret door)
       _ (pin g 'homes ())                           ; fresh non-leaf home set (call-fixed + sibs read it)
       _ (pin g 'lhome ())                           ; fresh locals-homing map (cgdecl's hook reads it)
       _ (pin g 'fn (caup f))
       sig (peep (g 'sigs) (caup f) ())
       vararg (? (two? sig) (nthr sig 2) ())
       ; spill each param from its SysV register: integers from r6 r5 r2 r1 r7 r8
       ; (<=6), doubles from f0..f7 (<=8), SEPARATE counters. an OVERFLOW param
       ; already sits on the caller stack -- addressed at rbp+16+8k, no store.
       (spill ps gpi xmmi ovi env acc)
        (? (! (two? ps)) (L acc env)
           (: p (cap ps) pty (caup p)
              (? (sse2? g pty)                       ; a two-double struct param: an xmm PAIR into a 16-byte slot
                  (? (< 6 xmmi) 'bad
                     (: off (- 0 (+ (peep g 'off 0) 16))
                        _ (pin g 'off (+ (peep g 'off 0) 16))
                        (spill (cup ps) gpi (+ xmmi 2) ovi (link (L (cap p) off pty) env)
                               (cat acc (cat (fstf 'double 'r4 off (xmmreg xmmi))
                                             (fstf 'double 'r4 (+ off 8) (xmmreg (+ xmmi 1))))))))
                 (&& (stru? pty) (id? (aone g pty) 'sse))   ; a small SSE aggregate: one xmm into an 8-byte slot
                  (? (< xmmi 8)
                     (: off (- 0 (+ (peep g 'off 0) 8))
                        _ (pin g 'off (+ (peep g 'off 0) 8))
                        (spill (cup ps) gpi (+ xmmi 1) ovi (link (L (cap p) off pty) env)
                               (cat acc (fstf 'double 'r4 off (xmmreg xmmi)))))
                     (spill (cup ps) gpi xmmi (+ ovi 1) (link (L (cap p) (+ 16 (* 8 ovi)) pty) env) acc))
                 (&& (stru? pty) (! (id? (aone g pty) 'int))) 'bad   ; MIXED pair / >16B stays ahead; a small INT one rides the gp lane
                 (&& (flo? pty) (< xmmi 8))
                  (: off (- 0 (+ (peep g 'off 0) 8))
                     _ (pin g 'off (+ (peep g 'off 0) 8))
                     (spill (cup ps) gpi (+ xmmi 1) ovi (link (L (cap p) off pty) env)
                            (cat acc (fstf pty 'r4 off (xmmreg xmmi)))))
                 (&& (! (flo? pty)) (< gpi 6))
                  (: off (- 0 (+ (peep g 'off 0) 8))
                     _ (pin g 'off (+ (peep g 'off 0) 8))
                     (spill (cup ps) (+ gpi 1) xmmi ovi (link (L (cap p) off pty) env)
                            (cat acc (L (L 'st 'r4 off (nthr argregs gpi))))))
                 (spill (cup ps) gpi xmmi (+ ovi 1) (link (L (cap p) (+ 16 (* 8 ovi)) pty) env) acc))))
       ; a VARIADIC function (SysV): a 176-byte register SAVE AREA holds the 6 gp
       ; arg registers (@ +0, step 8) and 8 xmm registers (@ +48, step 16, low 8
       ; bytes each). named register-passed params are addressed INSIDE the area;
       ; overflow named params ride the caller stack (rbp+16+). va_start reads back
       ; g's rsa / vagp / vaxmm. the xmm registers are saved unconditionally (safe
       ; -- reading an xmm never faults -- so no `al` guard is needed on this side).
       (vaspill ps)
        (: rsa (- 0 (+ (peep g 'off 0) 176))
           _ (pin g 'off (+ (peep g 'off 0) 176))
           _ (pin g 'rsa rsa)
           savegp (: (go i acc) (? (< 5 i) acc (go (+ i 1) (cat acc (L (L 'st 'r4 (+ rsa (* 8 i)) (nthr argregs i)))))) (go 0 ()))
           savex  (: (go i acc) (? (< 7 i) acc (go (+ i 1) (cat acc (L (L 'stsd 'r4 (+ rsa (+ 48 (* 16 i))) (xmmreg i)))))) (go 0 ()))
           (cls qs gpi xmmi ov env)
            (? (! (two? qs)) (: _ (pin g 'vagp gpi) _ (pin g 'vaxmm xmmi) (L (cat savegp savex) env))
               (: p (cap qs) pty (caup p)
                  (? (flo? pty)
                      (? (< 7 xmmi) (cls (cup qs) gpi xmmi (+ ov 8) (link (L (cap p) (+ 16 ov) pty) env))
                         (cls (cup qs) gpi (+ xmmi 1) ov (link (L (cap p) (+ rsa (+ 48 (* 16 xmmi))) pty) env)))
                     (? (< 5 gpi) (cls (cup qs) gpi xmmi (+ ov 8) (link (L (cap p) (+ 16 ov) pty) env))
                        (cls (cup qs) (+ gpi 1) xmmi ov (link (L (cap p) (+ rsa (* 8 gpi)) pty) env))))))
           (cls ps 0 0 0 ()))
       ; -- register-homed params (the leaf lane). a gp param that is an 8-byte
       ; scalar (long/ulong/pointer) whose address never escapes can live in a
       ; CALLER-SAVED, non-scratch register for the whole function instead of a
       ; frame slot -- gcc's win on the hot dispatch ops (lvm_arg0 &c keep Sp/Hp/
       ; Ip in registers). the home pool (r6 r5 r9 r10 r7 r8), indexed by gp
       ; position, is disjoint from the codegen's scratch set (r0-r3) and from the
       ; overflow/xmm registers -- so Hp (incoming r2) and Sp (incoming r1) MOVE
       ; out of scratch at the prologue. it is applied ONLY when the function turns
       ; out to be a LEAF: after the sibcall pass no `call`/`callr` remains (every
       ; call tail-jumped, so no callee -- and no GLAZED callee -- ever clobbers a
       ; home), fesc is unset (no frame address escaped, so no param's address was
       ; taken), there is no raw `sys` (rcx/r11 are syscall-clobbered), and it is
       ; not variadic. decided by GENERATING first, then regenerating with the
       ; register env if the gate holds. --
       (homereg gpi) (nthr opool gpi)
       (spillr ps gpi xmmi ovi env acc)             ; like spill, but home eligible gp params in registers
        (? (! (two? ps)) (L acc env)
           (: p (cap ps) pty (caup p)
              (? (sse2? g pty)
                  (? (< 6 xmmi) 'bad
                     (: off (- 0 (+ (peep g 'off 0) 16))
                        _ (pin g 'off (+ (peep g 'off 0) 16))
                        (spillr (cup ps) gpi (+ xmmi 2) ovi (link (L (cap p) off pty) env)
                               (cat acc (cat (fstf 'double 'r4 off (xmmreg xmmi))
                                             (fstf 'double 'r4 (+ off 8) (xmmreg (+ xmmi 1))))))))
                 (&& (stru? pty) (id? (aone g pty) 'sse))   ; a small SSE aggregate: one xmm into an 8-byte slot
                  (? (< xmmi 8)
                     (: off (- 0 (+ (peep g 'off 0) 8))
                        _ (pin g 'off (+ (peep g 'off 0) 8))
                        (spillr (cup ps) gpi (+ xmmi 1) ovi (link (L (cap p) off pty) env)
                               (cat acc (fstf 'double 'r4 off (xmmreg xmmi)))))
                     (spillr (cup ps) gpi xmmi (+ ovi 1) (link (L (cap p) (+ 16 (* 8 ovi)) pty) env) acc))
                 (&& (stru? pty) (! (id? (aone g pty) 'int))) 'bad   ; MIXED / >16B ahead; small INT rides the gp lane (never homable)
                 (&& (flo? pty) (< xmmi 8))
                  (: off (- 0 (+ (peep g 'off 0) 8))
                     _ (pin g 'off (+ (peep g 'off 0) 8))
                     (spillr (cup ps) gpi (+ xmmi 1) ovi (link (L (cap p) off pty) env)
                            (cat acc (fstf pty 'r4 off (xmmreg xmmi)))))
                 (&& (! (flo? pty)) (< gpi 6))
                  (? (homable? pty)                  ; home in a register: move from the incoming arg reg if it differs
                      (: home (homereg gpi) inc (nthr argregs gpi)
                         mv (? (= home inc) () (L (L 'mov home inc)))
                         (spillr (cup ps) (+ gpi 1) xmmi ovi (link (L (cap p) (L 'reg home) pty) env)
                                (cat acc mv)))
                     (: off (- 0 (+ (peep g 'off 0) 8))
                        _ (pin g 'off (+ (peep g 'off 0) 8))
                        (spillr (cup ps) (+ gpi 1) xmmi ovi (link (L (cap p) off pty) env)
                               (cat acc (L (L 'st 'r4 off (nthr argregs gpi)))))))
                 (spillr (cup ps) gpi xmmi (+ ovi 1) (link (L (cap p) (+ 16 (* 8 ovi)) pty) env) acc))))
       (homes? ps gpi)                              ; does any gp param qualify for a register home?
        (? (! (two? ps)) ()
           (: pty (caup (cap ps))
              (? (|| (flo? pty) (|| (sse2? g pty) (id? (aone g pty) 'sse))) (homes? (cup ps) gpi)
                 (< 5 gpi) ()
                 (homable? pty) 1
                 (homes? (cup ps) (+ gpi 1)))))
       ; -- the NON-LEAF lane: like spillr, but each home ALSO takes a frame slot
       ; (its spill shadow) recorded in g 'homes -- call-fixed spills the homes
       ; there just before every remaining call's pops and reloads after, so a
       ; callee (glazed or not) only ever sees its own ABI registers. a &param
       ; deopts the whole regen (clval on a regv answers 'bad) back to ir1. --
       (spillr2 ps gpi xmmi ovi env acc)
        (? (! (two? ps)) (L acc env)
           (: p (cap ps) pty (caup p)
              (? (sse2? g pty)
                  (? (< 6 xmmi) 'bad
                     (: off (- 0 (+ (peep g 'off 0) 16))
                        _ (pin g 'off (+ (peep g 'off 0) 16))
                        (spillr2 (cup ps) gpi (+ xmmi 2) ovi (link (L (cap p) off pty) env)
                               (cat acc (cat (fstf 'double 'r4 off (xmmreg xmmi))
                                             (fstf 'double 'r4 (+ off 8) (xmmreg (+ xmmi 1))))))))
                 (&& (stru? pty) (id? (aone g pty) 'sse))   ; a small SSE aggregate: one xmm into an 8-byte slot
                  (? (< xmmi 8)
                     (: off (- 0 (+ (peep g 'off 0) 8))
                        _ (pin g 'off (+ (peep g 'off 0) 8))
                        (spillr2 (cup ps) gpi (+ xmmi 1) ovi (link (L (cap p) off pty) env)
                               (cat acc (fstf 'double 'r4 off (xmmreg xmmi)))))
                     (spillr2 (cup ps) gpi xmmi (+ ovi 1) (link (L (cap p) (+ 16 (* 8 ovi)) pty) env) acc))
                 (&& (stru? pty) (! (id? (aone g pty) 'int))) 'bad   ; MIXED / >16B ahead; small INT rides the gp lane (never homable)
                 (&& (flo? pty) (< xmmi 8))
                  (: off (- 0 (+ (peep g 'off 0) 8))
                     _ (pin g 'off (+ (peep g 'off 0) 8))
                     (spillr2 (cup ps) gpi (+ xmmi 1) ovi (link (L (cap p) off pty) env)
                            (cat acc (fstf pty 'r4 off (xmmreg xmmi)))))
                 (&& (! (flo? pty)) (< gpi 6))
                  (? (homable? pty)
                      (: home (homereg gpi) inc (nthr argregs gpi)
                         off (- 0 (+ (peep g 'off 0) 8))
                         _ (pin g 'off (+ (peep g 'off 0) 8))
                         _ (pin g 'homes (link (L home off) (peep g 'homes ())))
                         mv (? (= home inc) () (L (L 'mov home inc)))
                         (spillr2 (cup ps) (+ gpi 1) xmmi ovi (link (L (cap p) (L 'reg home) pty) env)
                                (cat acc mv)))
                     (: off (- 0 (+ (peep g 'off 0) 8))
                        _ (pin g 'off (+ (peep g 'off 0) 8))
                        (spillr2 (cup ps) (+ gpi 1) xmmi ovi (link (L (cap p) off pty) env)
                               (cat acc (L (L 'st 'r4 off (nthr argregs gpi)))))))
                 (spillr2 (cup ps) gpi xmmi (+ ovi 1) (link (L (cap p) (+ 16 (* 8 ovi)) pty) env) acc))))
       (anyop? fs op) (? (! (two? fs)) () (: f (cap fs) (? (&& (two? f) (= (cap f) op)) 1 (anyop? (cup fs) op))))
       (hascall? fs) (|| (anyop? fs 'call) (anyop? fs 'callr))
       ; the non-leaf PAYOFF gate: homing saves one frame load per param READ but
       ; costs a spill+reload PER HOME around every remaining call -- worth it
       ; only where reads dominate (the hot dispatch shape: many reads, a call
       ; or two). counted on the post-sibcall ir1: tail calls already cost nothing.
       (nhomable ps gpi n)
        (? (! (two? ps)) n
           (: pty (caup (cap ps))
              (? (|| (flo? pty) (|| (sse2? g pty) (id? (aone g pty) 'sse))) (nhomable (cup ps) gpi n)
                 (< 5 gpi) n
                 (homable? pty) (nhomable (cup ps) (+ gpi 1) (+ n 1))
                 (nhomable (cup ps) (+ gpi 1) n))))
       (ncalls fs n) (? (! (two? fs)) n
                        (: f (cap fs)
                           (ncalls (cup fs) (? (&& (two? f) (member? (cap f) '(call callr))) (+ n 1) n))))
       (pslots env acc)                             ; the homable params' PASS-1 frame slots
        (? (! (two? env)) acc
           (: e2 (cap env)
              (pslots (cup env) (? (&& (! (two? (caup e2))) (&& (< (caup e2) 0) (homable? (cauup e2))))
                                   (link (caup e2) acc) acc))))
       (nreads fs offs n)                           ; frame touches of those slots in ir1
        (? (! (two? fs)) n
           (: f (cap fs)
              hit (? (! (two? f)) ()
                     (member? (cap f) '(ld ld1 ld2 ld4 ldu1 ldu2 ldu4)) (&& (= (cauup f) 'r4) (member? (caup (cuup f)) offs))
                     (member? (cap f) '(st st1 st2 st4)) (&& (= (caup f) 'r4) (member? (cauup f) offs))
                     ())
              (nreads (cup fs) offs (? hit (+ n 1) n))))
       (build sp0)                                  ; assemble prologue + body + epilogue for a spill result
        (? (bad? sp0) 'bad
           (: _ (pin g 'dseq 0)                     ; the locals-homing decl sequence, fresh per build
              _ (pin g 'lrec ())
              body (cgitems g (caup sp0) (caup (caup (cuup f))) ())
              (? (bad? body) 'bad
                 (: frame (& (+ (peep g 'off 0) 15) -16)
                    (deadst
                     (stld
                     (spmerge
                     (deaddef
                     (deadcell
                     (cfoldir
                      (sibcall g
                       (cat (L (L 'label (intern (caup f)))
                               (L 'push 'r4) (L 'mov 'r4 'sp) (L 'sub 'sp 'sp frame)
                               (L 'st 'r4 -8 'r3))
                        (cat (cap sp0)
                         (cat body (cat (L (L 'li 'r0 0)) epi)))))))))))))))
       ; the operand pool rides BESIDE the homes: pass 1 owns all of opool, a
       ; regen loses the registers its param homes occupy
       (uhomes ps gpi acc)
        (? (|| (! (two? ps)) (< 5 gpi)) acc
           (: pty (caup (cap ps))
              (? (|| (flo? pty) (|| (sse2? g pty) (id? (aone g pty) 'sse))) (uhomes (cup ps) gpi acc)
                 (homable? pty) (uhomes (cup ps) (+ gpi 1) (link (homereg gpi) acc))
                 (uhomes (cup ps) (+ gpi 1) acc))))
       hpool (: uh (uhomes params 0 ())
                (filter (\ r9 (! (member? r9 uh))) opool))
       ; -- the LOCALS picker: rank the homable locals ir1 recorded (cgdecl's
       ; hook) by residual frame touches, drop any whose slot is lea/lean'd
       ; (address taken), gate each on touches beating the per-call wrap, and
       ; hand the hottest the FRONT of hpool -- the operand pool keeps the
       ; rest (two reserved, so expressions never go dry outright). answers
       ; (L lhome-tablet remaining-pool) | (). --
       (ntouch fs off n)
        (? (! (two? fs)) n
           (: f2 (cap fs)
              hit (? (! (two? f2)) ()
                     (member? (cap f2) '(ld ld1 ld2 ld4 ldu1 ldu2 ldu4)) (&& (= (cauup f2) 'r4) (= (caup (cuup f2)) off))
                     (member? (cap f2) '(st st1 st2 st4)) (&& (= (caup f2) 'r4) (= (cauup f2) off))
                     ())
              (ntouch (cup fs) off (? hit (+ n 1) n))))
       (leaoffs fs t) (? (! (two? fs)) t
                         (: f2 (cap fs)
                            _ (? (&& (two? f2) (&& (member? (cap f2) '(lea lean)) (= (cauup f2) 'r4)))
                                 (pin t (caup (cuup f2)) 1) ())
                            (leaoffs (cup fs) t)))
       (lastn l n) (: d (- (tally l) n)
                      (go2 l2 k) (? (< k 1) l2 (go2 (cup l2) (- k 1)))
                      (? (< d 1) l (go2 l d)))
       (dropn l n) (? (|| (< n 1) (! (two? l))) l (dropn (cup l) (- n 1)))
       (lpick ir1x)
        (: nc (ncalls ir1x 0)
           ; call-free fns only (post-sibcall: tail calls cost nothing): the
           ; static spill+reload wrap around real calls measured a net loss
           ; even with zero-cost reads -- a call inside a loop pays the wrap
           ; per iteration while the touch count stays static
           floor9 (? (= nc 0) 1 kmax)
           lt (leaoffs ir1x (tablet 0))
           navl (- (tally hpool) 2)
           (walk rs acc)
            (? (! (two? rs)) acc
               (: e2 (cap rs) sq (cap e2) off (caup e2)
                  (? (peep lt off ()) (walk (cup rs) acc)
                     (: tc (ntouch ir1x off 0)
                        (? (<= tc floor9) (walk (cup rs) acc)
                           (walk (cup rs) (link (L tc sq) acc)))))))
           cs (? (< navl 1) () (lastn (imsort (walk (peep g 'lrec ()) ())) navl))
           (mk l hp t) (? (|| (! (two? l)) (! (two? hp))) t
                          (: _ (pin t (caup (cap l)) (cap hp))
                             (mk (cup l) (cup hp) t)))
           (? (two? cs) (L (mk cs hpool (tablet 0)) (dropn hpool (tally cs))) ()))
       n0 (peep g 'n 0) strs0 (g 'strs)             ; snapshot the accumulators for a possible regen
       _ (pin g 'pool0 opool) _ (pin g 'pool opool)
       sp1 (? vararg (vaspill params) (spill params 0 0 0 () ()))
       ir1 (build sp1)
       n1 (peep g 'n 0) strs1 (g 'strs)             ; ir1's accumulators -- a DEOPT restores these
       hm (&& (! vararg) (&& (! (anyop? ir1 'sys)) (homes? params 0)))
       lr (? (|| vararg (|| (bad? ir1) (anyop? ir1 'sys))) () (lpick ir1))
       lh (? (two? lr) (cap lr) ())
       lp0 (? (two? lr) (caup lr) hpool)
       (? (bad? ir1) 'bad
          (&& (|| hm lh) (&& (! (peep g 'fesc ())) (! (hascall? ir1))))
           (: _ (pin g 'n n0) _ (pin g 'strs strs0) _ (pin g 'off 8) _ (pin g 'fesc ())
              _ (pin g 'pool0 lp0) _ (pin g 'pool lp0)
              _ (pin g 'homes ()) _ (pin g 'lhome lh)
              ir2 (build (spillr params 0 0 0 () ()))
              _ (pin g 'lhome ()) _ (pin g 'homes ())
              (? (bad? ir2) (: _ (pin g 'n n1) _ (pin g 'strs strs1) ir1) ir2))
          (: pp (&& hm (: nc (ncalls ir1 0) nh (nhomable params 0 0)   ; calls remain: home + spill
                          (< (* 2 (* nc nh)) (nreads ir1 (pslots (caup sp1) ()) 0))))   ; ... only where reads beat the wraps
             (? (|| pp lh)
                (: _ (pin g 'n n0) _ (pin g 'strs strs0) _ (pin g 'off 8) _ (pin g 'fesc ())
                   _ (pin g 'pool0 lp0) _ (pin g 'pool lp0)
                   _ (pin g 'homes ()) _ (pin g 'lhome lh)
                   ir2 (build (? pp (spillr2 params 0 0 0 () ()) (spill params 0 0 0 () ())))
                   _ (pin g 'lhome ()) _ (pin g 'homes ())   ; the wrap set dies with this fn
                   (? (bad? ir2) (: _ (pin g 'n n1) _ (pin g 'strs strs1) ir1) ir2))
                ir1))))

   ; the data tail: globals in declaration order, then the string table
   ; -> (dataforms nifforms) | 'bad. a global pinned to the `ai_nifs` section
   ; (AI_NIF's registry entries) lays in ITS OWN stream -- the .o emitter puts
   ; it in a real `ai_nifs` ELF section so the linker's __start_/__stop_
   ; bracket symbols exist and main()'s boot drain finds the entries. any
   ; OTHER named section stays in .data (reached by symbol, not by bracket).
   (cgdata g)
    (: sects (peep g 'sects (tablet 0))
       (nif? nm) (? (= (peep sects nm ()) "ai_nifs") 1 ())   ; canonical 1/() -- the walk compares with id?
       (globs gs nif acc)
        (? (! (two? gs)) acc
           (! (id? (nif? (cap gs)) nif)) (globs (cup gs) nif acc)   ; the other stream's
           (: ge (peep (g 'glob) (cap gs) 0)
              lbl (cap ge) ty (caup ge) init (cauup ge)
              bytes (cgimage g ty init)                 ; a constant image | 'bad (label values -> 4d)
              (? (bad? bytes) 'bad
                 (globs (cup gs) nif (cat acc (L (L 'label lbl) (L 'raw bytes)))))))
       (strs ss acc)
        (? (! (two? ss)) acc
           (: p (cap ss)
              (bts s i bacc) (? (< i 0) bacc (bts s (- i 1) (link (s i) bacc)))
              t (caup p)
              (strs (cup ss) (cat acc (L (L 'label (cap p))
                                         (L 'raw (cat (bts t (- (tally t) 1) ()) (L 0))))))))
       (: gb (globs (rev (g 'globs)) () ())           ; exported globals, then block-scope statics
          sb (? (bad? gb) 'bad (globs (rev (g 'statics)) () ()))   ; (local data labels), then strings
          nb (? (|| (bad? gb) (bad? sb)) 'bad (globs (rev (g 'globs)) 1 ()))
          (? (|| (bad? gb) (|| (bad? sb) (bad? nb))) 'bad
             (L (cat gb (cat sb (strs (g 'strs) ()))) nb))))

   ; the shared core: build the gen state, then TEXT (the functions, no _start)
   ; and DATA (globals + strings) separately -> (g textforms dataforms) | ().
   ; weaks: the __attribute__((weak)) names -- NEVER inlined (an inlined body
   ; would bake past the strong override the linker owes them).
   ; xtra: the parser's (sfns svars sects) tablets -- static fns, static
   ; globals, name -> section. () reads as three empties (the law harness).
   (cgen-core ast stbl sigs weaks xtra)
    (: g (: t (tablet 0) _ (pin t 'n 0) _ (pin t 'brk ()) _ (pin t 'cnt ())
            _ (pin t 'glob (tablet 0)) _ (pin t 'globs ()) _ (pin t 'strs ()) _ (pin t 'statics ())
            _ (pin t 'fns (tablet 0)) _ (pin t 'inl (tablet 0)) _ (pin t 'cgitems cgitems)
            _ (pin t 'stag stbl) _ (pin t 'sigs sigs)
            _ (pin t 'sects (? (two? xtra) (cauup xtra) (tablet 0))) t)
       ; pass 0: every function name -- so a bare use of one is its address (la).
       ; the sig table too: an mproto sibling (`double sin(..), cos(..);`) has a
       ; sig but no proto form of its own. a small single-return definition also
       ; lands in the INLINE table (order-independent: recorded before any body).
       (recfns fs) (? (! (two? fs)) 1
                      (: f (cap fs)
                         _ (? (member? (cap f) '(fn proto)) (pin (g 'fns) (caup f) 1) ())
                         _ (? (&& (= (cap f) 'fn)
                                  (&& (! (member? (caup f) weaks))
                                      (inlok? f (peep sigs (caup f) ()))))
                              (pin (g 'inl) (caup f) f) ())
                         (recfns (cup fs))))
       _ (recfns (caup ast))
       _ (: (go ns) (? (! (two? ns)) 1 (: _ (pin (g 'fns) (cap ns) 1) (go (cup ns))))
            (go (keys sigs)))
       ; pass 1: record every global (name -> (label ty init)); cgimage
       ; validates the initializer at data-emission time (a label-valued image
       ; refuses the whole compile -- 4d)
       (rec fs)
        (? (! (two? fs)) 1
           (: f (cap fs)
              (? (! (member? (cap f) '(gdecl xdecl))) (rec (cup fs))
                 (: xd (= (cap f) 'xdecl)              ; extern: addressable, NO storage laid
                    (one ps)
                     (? (! (two? ps)) (rec (cup fs))
                        (: p (cap ps)
                           _ (pin (g 'glob) (cap p) (L (intern (cap p)) (caup p) (cauup p)))
                           _ (? xd () (pin g 'globs (link (cap p) (g 'globs))))
                           (one (cup ps))))
                    (one (caup f))))))
       ok (rec (caup ast))
       ; always emit text + data (a library TU has no main); `saw` rides out so
       ; the EXECUTABLE path can insist on one.
       (gfns fs acc saw)
        (? (! (two? fs))
           (: dat (cgdata g) (? (bad? dat) () (L g acc dat saw)))
           (: f (cap fs)
              (? (member? (cap f) '(proto gdecl xdecl tdef)) (gfns (cup fs) acc saw)
                 (: r (cgfn g f)
                    (? (bad? r) (: _ (puts (+ ";; cgfn refuses " (+ (caup f) "\n"))) ())
                       (gfns (cup fs) (cat acc r)
                             (|| saw (= (caup f) "main"))))))))
       (? ok (gfns (caup ast) () ()) ()))
   (cgen ast stbl sigs weaks xtra)                  ; the STATIC EXECUTABLE: _start (crt0) + text + data -> (1 forms) | () -- needs main
    (: crt0 (L (L 'call 'main) (L 'mov 'r6 'r0) (L 'li 'r0 60) (L 'sys))
       r (cgen-core ast stbl sigs weaks xtra)
       (? (! (two? r)) ()
          (! (nthr r 3)) ()                          ; no main -> no program (the exe has nothing to start)
          (: dat (cauup r)                           ; (dataforms nifforms): the exe resolves labels itself,
             (L 1 (cat crt0 (cat (caup r) (cat (cap dat) (caup dat))))))))   ; so the nif stream just rides along
   ; the RELOCATABLE OBJECT view (stage 7a): text and data split, plus the
   ; DEFINED function names (global FUNC symbols, statics excluded -- they stay
   ; LOCAL, ai.h's inline helpers land in every TU) and global-variable names
   ; (global OBJECT symbols, statics excluded), plus the ai_nifs stream -- the
   ; .o emitter (crew/holo/obj.l) turns the rest (undefined labels,
   ; cross-section refs) into a symbol table + relocations.
   (cgen-obj ast stbl sigs weaks xtra)              ; -> (1 textforms dataforms funcnames globnames nifforms) | ()
    (: r (cgen-core ast stbl sigs weaks xtra)
       (? (! (two? r)) ()
          (: sfns (? (two? xtra) (cap xtra) (tablet 0))
             svars (? (two? xtra) (caup xtra) (tablet 0))
             sects (? (two? xtra) (cauup xtra) (tablet 0))
             (loc? nm) (|| (! (id? (peep svars nm 'no) 'no))
                           (= (peep sects nm ()) "ai_nifs"))     ; a nif entry is static by shape; any OTHER
                                                                 ; named section stays exported (.image is read by symbol)
             fnames (: (go fs acc) (? (! (two? fs)) (rev acc)
                                      (: f (cap fs)
                                         (go (cup fs) (? (&& (= (cap f) 'fn)
                                                            (id? (peep sfns (caup f) 'no) 'no))
                                                         (link (caup f) acc) acc))))
                       (go (caup ast) ()))
             gnames (: (go gs acc) (? (! (two? gs)) (rev acc)
                                      (go (cup gs) (? (loc? (cap gs)) acc (link (cap gs) acc))))
                       (go (rev ((cap r) 'globs)) ()))
             dat (cauup r)
             (L 1 (caup r) (cap dat) fnames gnames (caup dat))))))
