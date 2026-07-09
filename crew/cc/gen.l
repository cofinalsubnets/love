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
   ; -- the type floor (struct sizes come off the stag table riding in g) --
   (ptr? ty) (&& (two? ty) (= (cap ty) 'ptr))
   (arr? ty) (&& (two? ty) (= (cap ty) 'arr))
   (stru? ty) (&& (two? ty) (= (cap ty) 'struct))
   (fn? ty) (&& (two? ty) (= (cap ty) 'fn))         ; ('fn ret?) -- a function; decays to its address
   (fnty g nm) (: sig (peep (g 'sigs) nm ())        ; a named function's type, return riding when sig'd
                  (? (two? sig) (L 'fn (cap sig)) (L 'fn)))
   ; the one by-value struct shape cc carries (SysV: two SSE eightbytes -- an
   ; xmm pair): exactly two double fields, 16 bytes. ai.c's struct ai_zn. a
   ; struct VALUE in cgexpr is its ADDRESS in r0; params/args/returns/copies
   ; read the pair through it. every other by-value struct stays refused.
   (sse2? g ty) (? (! (stru? ty)) ()
                   (: se (peep (g 'stag) (caup ty) 0)
                      (? (! (two? se)) ()
                         (: fs (cap se)
                            (&& (= (caup se) 16)
                                (&& (= (tally fs) 2)
                                    (&& (flo? (cauup (cap fs))) (flo? (cauup (caup fs))))))))))
   (fnret ty) (? (! (&& (two? ty) (= (cap ty) 'ptr))) 'long   ; an indirect callee's result type: ('ptr ('fn ret)) | 'long
                 (: ft (caup ty) (? (&& (fn? ft) (two? (cup ft))) (caup ft) 'long)))
   ; unsigned scalars ride 'uchar 'ushort 'uint 'ulong -- same WIDTH as their signed
   ; twin, but a load zero-extends, `>>` is logical, compare/divide go unsigned, and
   ; a binary op is unsigned if EITHER operand is (simplified usual conversions).
   (usg? ty) (member? ty '(uchar ushort uint ulong))
   (ubin ta tb) (? (|| (usg? ta) (usg? tb)) 'ulong 'long)
   (scc op unsg) (? (! unsg) op (= op 'lt) 'below (= op 'gt) 'above (= op 'le) 'be (= op 'ge) 'ae op)
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
   (lg2 n) (? (= n 1) 0 (= n 2) 1 (= n 4) 2 3)
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
   (asflo r) (? (flo? (cap r)) (caup r) (cat (caup r) (L (L 'cvtsi2sd 'f0 'r0))))   ; result -> f0 as a double
   (asint r) (? (flo? (cap r)) (cat (caup r) (L (L 'cvttsd2si 'r0 'f0))) (caup r))  ; result -> r0 as an int
   ; a truth value in r0 that `cmp r0 0` can test: a double folds to d != 0.0
   (ctest g env e)
    (: r (cgexpr g env e)
       (? (bad? r) 'bad
          (flo? (cap r))                             ; d != 0.0, NaN-honest: unordered is NONZERO (true), so `or` in the parity bit
           (L 'long (cat (caup r) (L (L 'li 'r1 0) (L 'movqxr 'f1 'r1) (L 'ucomisd 'f0 'f1)
                                     (L 'set 'ne 'r0) (L 'set 'p 'r1) (L 'or 'r0 'r0 'r1))))
          r))
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

   ; -- the environments: locals shadow globals --
   (vent g env name)                                ; -> ('loc off ty) | ('glo lbl ty) | 'bad
    (: e (assoc name env)
       (? (two? e) (L 'loc (caup e) (cauup e))
          (: ge (peep (g 'glob) name 0)
             (? (two? ge) (L 'glo (cap ge) (caup ge)) 'bad))))

   ; a fresh frame temp of type ty -> its (negative) offset. bumps the frame's
   ; high-water like a local; used to give a compound literal a home.
   (ntmp g ty) (: span (& (+ (tsz g ty) 7) -8)
                  off (- 0 (+ (peep g 'off 0) span))
                  _ (pin g 'off (+ (peep g 'off 0) span))
                  off)
   ; load a value from the address in r0, by type -- the deref/clit value tail
   ; (arrays and functions decay to the address; a struct has no register value)
   (loadval ty addrf)
    (? (arr? ty) (L (L 'ptr (caup ty)) addrf)
       (fn? ty) (L (L 'ptr ty) addrf)
       (stru? ty) 'bad
       (flo? ty) (L 'double (cat addrf (fldf ty 'f0 'r0 0)))
       (L ty (cat addrf (L (L (ldop ty) 'r0 'r0 0)))))
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
                 ; lean, not lea: an lvalue's address is CONSUMED by its own
                 ; load/store -- the sibcall escape gate must not see it. the
                 ; & lane flips it back to lea (there it really escapes).
                 (= (cap en) 'loc) (L (cauup en) (L (L 'lean 'r0 'r4 (caup en))))
                 (L (cauup en) (L (L 'la 'r0 (caup en))))))
          (= k 'deref)
           (: r (cgexpr g env (caup e))
              (? (bad? r) 'bad
                 (! (ptr? (cap r))) 'bad
                 (L (caup (cap r)) (caup r))))
          (= k 'dot)
           (: r (clval g env (caup e))
              (? (bad? r) 'bad
                 (: fm (fmem g (cap r) (cauup e))
                    (? (bad? fm) 'bad
                       (L (caup fm)
                          (cat (caup r)
                               (? (= (cap fm) 0) () (L (L 'add 'r0 'r0 (cap fm))))))))))
          (= k 'clit)                               ; a compound literal is an lvalue: fill a temp, address it
           (: ty (caup e) ini (caup (cup e))
              off (ntmp g ty)
              fill (clitcode g env off ty ini)
              (? (bad? fill) 'bad
                 (L ty (cat fill (L (L 'lea 'r0 'r4 off))))))   ; a real lea: the temp's address is the value (& pins via the addr lane, a call blocks via the window)
          'bad))

   ; -- expressions: answers (type forms) | 'bad, the value in r0 --
   (cgexpr g env e)
    (: k (cap e)
       (? (= k 'szof)                                   ; sizeof EXPR: the UNDECAYED type (clval keeps arrays), size a constant
           (: e2 (caup e)
              lv (clval g env e2)
              ty (? (bad? lv) (: r (cgexpr g env e2) (? (bad? r) 'bad (cap r))) (cap lv))
              (? (bad? ty) 'bad (L 'ulong (L (L 'li 'r0 (tsz g ty))))))
          (= k 'num) (L 'long (L (L 'li 'r0 (caup e))))
          (= k 'flo) (L 'double (L (L 'li 'r0 (fbits (caup e))) (L 'movqxr 'f0 'r0)))
          (= k 'str)
           (: lbl (nlab g ".S")
              _ (pin g 'strs (link (L lbl (caup e)) (g 'strs)))
              (L (L 'ptr 'char) (L (L 'la 'r0 lbl))))
          (= k 'dot)
           (: r (clval g env e)
              (? (bad? r) 'bad
                 (: ty (cap r)
                    (? (arr? ty) (L (L 'ptr (caup ty)) (caup r))
                       (fn? ty) (L (L 'ptr ty) (caup r))     ; a fn-pointer member is its address
                       (stru? ty) (L ty (caup r))    ; a struct member's value is its address (the sse2 rep)
                       (flo? ty) (L 'double (cat (caup r) (fldf ty 'f0 'r0 0)))
                       (L ty (cat (caup r) (L (L (ldop ty) 'r0 'r0 0))))))))
          (= k 'var)
           (: en (vent g env (caup e))
              (? (bad? en)
                  (? (peep (g 'fns) (caup e) ())     ; a function name is its address
                     (L (L 'ptr (fnty g (caup e))) (L (L 'la 'r0 (intern (caup e))))) 'bad)
                 (: ty (cauup en)
                    ap? (peep g 'argpos ())
                    _ (? (|| (stru? ty) (arr? ty)) (pin g 'argpos ()) ())
                    (? (stru? ty)                    ; a struct value is its ADDRESS (the sse2 rep)
                        (? (= (cap en) 'loc)
                           (: v (L ty (L (L 'lea 'r0 'r4 (caup en)))) (? ap? v (escan g v)))
                           (L ty (L (L 'la 'r0 (caup en)))))
                       (arr? ty)                     ; arrays decay to their address
                        (? (= (cap en) 'loc)
                           (: v (L (L 'ptr (caup ty)) (L (L 'lea 'r0 'r4 (caup en)))) (? ap? v (escan g v)))
                           (L (L 'ptr (caup ty)) (L (L 'la 'r0 (caup en)))))
                       (flo? ty)                     ; a float/double loads into f0 (widened if float)
                        (? (= (cap en) 'loc)
                           (L 'double (fldf ty 'f0 'r4 (caup en)))
                           (L 'double (cat (L (L 'la 'r1 (caup en))) (fldf ty 'f0 'r1 0))))
                       (? (= (cap en) 'loc)
                          (L ty (L (L (ldop ty) 'r0 'r4 (caup en))))
                          (L ty (L (L 'la 'r1 (caup en)) (L (ldop ty) 'r0 'r1 0))))))))
          (= k 'addr)
           (: r (clval g env (caup e))
              ap? (peep g 'argpos ())
              _ (pin g 'argpos ())
              (? (! (bad? r))                        ; under & the lvalue's address ESCAPES: flip its leans to leas
                 (: v (L (L 'ptr (cap r)) (unlean (caup r))) (? ap? v (escan g v)))
                 ; &f on a function name: same address as the bare use (no lvalue)
                 (&& (= (cap (caup e)) 'var) (peep (g 'fns) (caup (caup e)) ()))
                  (L (L 'ptr (fnty g (caup (caup e)))) (L (L 'la 'r0 (intern (caup (caup e))))))
                 'bad))
          (= k 'deref)
           (: r (clval g env e)                     ; clval already walked the pointer
              (? (bad? r) 'bad
                 (: ty (cap r)
                    (? (arr? ty) (L (L 'ptr (caup ty)) (caup r))   ; pointee array: decay again
                       (fn? ty) (L (L 'ptr ty) (caup r))           ; *fp -- a function is its address
                       (stru? ty) (L ty (caup r))                  ; *p as a struct value: the address rides
                       (flo? ty) (L 'double (cat (caup r) (fldf ty 'f0 'r0 0)))
                       (L ty (cat (caup r) (L (L (ldop ty) 'r0 'r0 0))))))))
          (= k 'asn)
           (: lv (clval g env (caup e))
              (? (bad? lv) 'bad
                 (arr? (cap lv)) 'bad                ; an array is not assignable
                 (stru? (cap lv))                    ; a whole-struct copy (dest r1, src r0)
                  (: rl (clval g env (cauup e))      ; an rvalue struct (a call's temp) is its address too
                     rv (? (bad? rl) (cgexpr g env (cauup e)) rl)
                     (? (bad? rv) 'bad
                        (! (stru? (cap rv))) 'bad
                        (L (cap lv)
                           (cat (caup lv) (cat (spush 'r0)
                            (cat (caup rv) (cat (spop 'r1)
                             (bcopy 0 (tsz g (cap lv)) ()))))))))
                 (flo? (cap lv))                     ; a float/double store (addr in r1, value in f0; narrow if float)
                  (: r (cgexpr g env (cauup e))
                     (? (bad? r) 'bad
                        (L 'double (cat (caup lv) (cat (spush 'r0)
                         (cat (asflo r) (cat (spop 'r1) (fstf (cap lv) 'r1 0 'f0))))))))
                 (: r (cgexpr g env (cauup e))
                    (? (bad? r) 'bad
                       (: ty (cap lv)
                          (L ty (cat (caup lv)
                                 (cat (spush 'r0)
                                  (cat (asint r)
                                   (cat (spop 'r1)
                                    (cat (cvt ty 'r0)
                                         (L (L (stop ty) 'r1 0 'r0)))))))))))))
          (= k 'post)
           (: lv (clval g env (caup e))
              (? (bad? lv) 'bad
                 (: ty (cap lv)
                    stp (? (ptr? ty) (tsz g (caup ty)) 1)
                    (? (arr? ty) 'bad
                       (L ty (cat (caup lv)
                              (L (L 'mov 'r2 'r0)
                                 (L (ldop ty) 'r0 'r2 0)
                                 (L 'add 'r1 'r0 (* stp (cauup e)))
                                 (L (stop ty) 'r2 0 'r1))))))))
          (= k 'cast)
           (: r (cgexpr g env (cauup e)) tgt (caup e)
              (? (bad? r) 'bad
                 (&& (flo? tgt) (! (flo? (cap r)))) (L 'double (asflo r))       ; int -> double
                 (&& (! (flo? tgt)) (flo? (cap r)))                              ; double -> int, then narrow
                  (L tgt (cat (asint r) (cvt tgt 'r0)))
                 (flo? tgt) (L 'double (caup r))                                 ; double -> double
                 (L tgt (cat (caup r) (cvt tgt 'r0)))))                          ; int -> int
          (= k 'un)
           (: r (cgexpr g env (cauup e))
              (? (bad? r) 'bad
                 (flo? (cap r))                        ; unary on a double
                  (? (= (caup e) 'neg)                 ; -d = 0.0 - d
                      (L 'double (cat (caup r) (L (L 'li 'r0 0) (L 'movqxr 'f1 'r0)
                                                  (L 'subsd 'f1 'f0) (L 'movsd 'f0 'f1))))
                     (= (caup e) 'not)                 ; !d = (d == 0.0), NaN-honest: !NaN is false (eq AND ordered)
                      (L 'long (cat (caup r) (L (L 'li 'r0 0) (L 'movqxr 'f1 'r0)
                                                (L 'ucomisd 'f0 'f1) (L 'set 'eq 'r0)
                                                (L 'set 'np 'r1) (L 'and 'r0 'r0 'r1))))
                     'bad)                             ; ~ on a double is invalid
                 (L 'long
                    (cat (caup r)
                         (? (= (caup e) 'neg) (L (L 'neg 'r0))
                            (= (caup e) 'bnot) (L (L 'not 'r0))
                            (L (L 'cmp 'r0 0) (L 'set 'eq 'r0)))))))
          (= k 'comma)
           (: a (cgexpr g env (caup e)) b (cgexpr g env (cauup e))
              (? (|| (bad? a) (bad? b)) 'bad
                 (L (cap b) (cat (caup a) (caup b)))))
          (= k 'land)
           (: a (ctest g env (caup e)) b (ctest g env (cauup e))
              lf (nlab g ".f") ld (nlab g ".d")
              (? (|| (bad? a) (bad? b)) 'bad
                 (L 'long
                    (cat (caup a) (cat (L (L 'cmp 'r0 0) (L 'br 'eq lf))
                     (cat (caup b) (L (L 'cmp 'r0 0) (L 'br 'eq lf)
                                      (L 'li 'r0 1) (L 'jmp ld)
                                      (L 'label lf) (L 'li 'r0 0) (L 'label ld))))))))
          (= k 'lor)
           (: a (ctest g env (caup e)) b (ctest g env (cauup e))
              lt (nlab g ".t") ld (nlab g ".d")
              (? (|| (bad? a) (bad? b)) 'bad
                 (L 'long
                    (cat (caup a) (cat (L (L 'cmp 'r0 0) (L 'br 'ne lt))
                     (cat (caup b) (L (L 'cmp 'r0 0) (L 'br 'ne lt)
                                      (L 'li 'r0 0) (L 'jmp ld)
                                      (L 'label lt) (L 'li 'r0 1) (L 'label ld))))))))
          (= k 'cond)
           (: c (ctest g env (caup e))
              t (cgexpr g env (cauup e))
              el (cgexpr g env (caup (cuup e)))
              le (nlab g ".e") ld (nlab g ".d")
              (? (|| (bad? c) (|| (bad? t) (bad? el))) 'bad
                 ; C's conditional CONVERTS its arms: one flo arm makes the whole
                 ; result flo, so the INTEGER arm rides asflo at its edge -- typing
                 ; by the then-arm alone left `(Cp(a) ? im(a) : 0)`'s int 0 in r0
                 ; while the reader took f0 (the eq lane's charm×twin face).
                 (: fl (|| (flo? (cap t)) (flo? (cap el)))
                    tf (? fl (asflo t) (caup t))
                    ef (? fl (asflo el) (caup el))
                    rt (? (flo? (cap t)) (cap t) (? fl (cap el) (cap t)))
                    (L rt
                       (cat (caup c) (cat (L (L 'cmp 'r0 0) (L 'br 'eq le))
                        (cat tf (cat (L (L 'jmp ld) (L 'label le))
                         (cat ef (L (L 'label ld)))))))))))
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
                    (L 'long (cat (caup lv)
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
                 (flo? ty) (L 'double (cat (caup lv) (cat walk (fldf ty 'f0 'r2 0))))
                 (L ty (cat (caup lv) (cat walk (L (L (ldop ty) 'r0 'r2 0)))))))
          (= k 'vaend) (L 'long ())
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
                 (= bi "__builtin_trap") (L 'long (L (L 'raw (L 15 11))))
                 (= bi "__builtin_inf")  (L 'double (L (L 'li 'r0 9218868437227405312) (L 'movqxr 'f0 'r0)))
                 (= bi "__builtin_nanf") (L 'double (L (L 'li 'r0 9221120237041090560) (L 'movqxr 'f0 'r0)))
                 (= bi "__builtin_expect") (cgexpr g env (cap args))
                 (= bi "__builtin___clear_cache") (L 'long ())
                 (= bi "__builtin_clzll")
                  (: e1 (cgexpr g env (cap args))
                     (? (bad? e1) 'bad
                        (L 'long (cat (asint e1) (L (L 'raw (L 72 15 189 192 72 131 240 63)))))))   ; bsr rax,rax; xor rax,63
                 (= bi "__builtin_isinf")
                  (: e1 (cgexpr g env (cap args))
                     (? (bad? e1) 'bad
                        (L 'long (cat (asflo e1)
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
                        (L 'long (cat (asint e1) (cat (spush 'r0)
                                  (cat (asint e2) (cat (spush 'r0)
                                   (cat (caup e3) (cat (cat (L (L 'mov 'r3 'r0)) (cat (spop 'r1) (spop 'r0)))
                                    (cat (L (L 'raw (cat opb (L 15 144 193 72 15 182 201))))          ; seto cl; movzx rcx,cl
                                         (L (L 'st 'r3 0 'r0) (L 'mov 'r0 'r1))))))))))))
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
                       (! (stru? (cap cr))) cr
                       (sse2? g (cap cr))              ; a two-double struct result: park the xmm pair in a fresh slot, answer its address
                        (: toff (- 0 (+ (peep g 'off 0) 16))
                           _ (pin g 'off (+ (peep g 'off 0) 16))
                           (L (cap cr) (cat (caup cr)
                                        (cat (fstf 'double 'r4 toff (xmmreg 0))
                                         (cat (fstf 'double 'r4 (+ toff 8) (xmmreg 1))
                                              (L (L 'lea 'r0 'r4 toff)))))))
                       'bad))))
          (= k 'clit)                              ; a compound literal as a value: fill the temp, load it
           (: lv (clval g env e)
              (? (bad? lv) 'bad (loadval (cap lv) (caup lv))))
          (= k 'bin) (cgbin g env e)
          'bad))
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
           ; a DIRECT &x / array / struct-var argument is presumed dead once the
           ; callee returns (the &Hp / &_res idiom): argpos exempts its lea from
           ; the fesc pin, one-shot, cleared right after. the sibs WINDOW rule
           ; still keeps the address out of a tail call's own staging.
           (: a (: _ (? (member? (cap (cap as)) '(addr var)) (pin g 'argpos 1) ())
                   (cgexpr g env (cap as)))
              _ (pin g 'argpos ())
              (? (bad? a) 'bad
                 (: pty (nthty pts i)
                    aty (? pty pty (cap a))                ; classify by the param type if known, else the arg's
                    wd (flo? aty)
                    (? (sse2? g aty)                       ; a two-double struct arg: push its pair (re on top), an xmm PAIR target
                        (? (< 6 xmmc) 'bad
                           (kls (cup as) (+ i 1) gpc (+ xmmc 2) ovc
                                (link (L (L 'x2 xmmc)
                                         (cat (caup a) (L (L 'ld 'r1 'r0 8) (L 'push 'r1) (L 'ld 'r1 'r0 0) (L 'push 'r1))))
                                      acc)))
                       (stru? aty) 'bad                    ; any other by-value struct stays ahead
                       (: aval (? wd (cat (asflo a) (L (L 'movqrx 'r0 'f0))) (asint a))
                          ; a register arg rides a 16-byte cell: rsp stays 16-aligned
                          ; while the REMAINING args evaluate (a later arg may hold a
                          ; nested call, and the SysV ABI wants rsp%16==0 at it). an
                          ; overflow arg keeps its 8-byte push -- the callee reads the
                          ; overflow block packed, and its target is ai-internal (never
                          ; a libc movaps-on-rbp path), so a stray eval-time skew is moot.
                          rpush (cat aval (spush 'r0))
                          opush (cat aval (L (L 'push 'r0)))
                          (? (&& wd (< xmmc 8)) (kls (cup as) (+ i 1) gpc (+ xmmc 1) ovc (link (L (L 'x xmmc) rpush) acc))
                             (&& (! wd) (< gpc 6)) (kls (cup as) (+ i 1) (+ gpc 1) xmmc ovc (link (L (L 'g gpc) rpush) acc))
                             (kls (cup as) (+ i 1) gpc xmmc (+ ovc 1) (link (L (L 'ov ovc) opush) acc)))))))))
       kr (kls ags 0 0 0 0 ())
       (? (bad? kr) 'bad
          (: ov? (\ kent (= (cap (cap kent)) 'ov))
             ovr (: (go1 l1 acc1) (? (! (two? l1)) acc1
                                     (go1 (cup l1) (? (ov? (cap l1)) (link (cap l1) acc1) acc1)))
                    (go1 kr ()))                          ; overflow entries, REVERSED (deepest pushes first)
             rgr (: (go2 l2 acc2) (? (! (two? l2)) acc2
                                     (go2 (cup l2) (? (ov? (cap l2)) acc2 (link (cap l2) acc2))))
                    (go2 kr ()))                          ; register entries, reversed (pops run forward)
             (pushcat l3 acc3) (? (! (two? l3)) acc3 (pushcat (cup l3) (cat acc3 (caup (cap l3)))))
             pops (: (go4 l4 acc4)
                      (? (! (two? l4)) acc4
                         (: kc (cap (cap l4))
                            (go4 (cup l4) (? (= (cap kc) 'ov) acc4
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
             (? dir
                 (L ret (cat pf (cat pops (cat setal (cat (L (L 'call (intern (caup hd)))) clean)))))
                (: hr (cgexpr g env hd)                   ; a function-pointer value: park in r3, callr
                   (? (bad? hr) 'bad
                      (L (fnret (cap hr)) (cat pf (cat (caup hr) (cat (L (L 'mov 'r3 'r0))
                                (cat pops (cat setal (cat (L (L 'callr 'r3)) clean)))))))))))))
   (cgbin g env e)
    (: op (caup e)
       a (cgexpr g env (cauup e))
       b (cgexpr g env (caup (cuup e)))
       rhs (caup (cuup e))
       (? (|| (bad? a) (bad? b)) 'bad
          ; a constant count rides the immediate shift; a variable count
          ; rides shlv/sarv with the count PINNED to r1 (holo's contract)
          (member? op '(shl shr))
           (: uL (usg? (cap a))                             ; a `>>` on an unsigned left operand is LOGICAL (shr, not sar)
              rt (? uL 'ulong 'long)                        ; the shift result keeps the left operand's signedness
              iop (? (= op 'shl) 'shl (? uL 'shr 'sar))
              vop (? (= op 'shl) 'shlv (? uL 'shrv 'sarv))
              (? (= (cap rhs) 'num)
                 (L rt (cat (caup a) (L (L iop 'r0 (caup rhs)))))
                 (L rt (cat (caup a)
                        (cat (spush 'r0)
                         (cat (caup b) (cat (L (L 'mov 'r1 'r0)) (cat (spop 'r0)
                                          (L (L vop 'r0 'r1))))))))))
          ; the double lane: either operand double -> both to double (f1=left,
          ; f0=right through the gp stack), then the scalar-double op or ucomisd.
          (|| (flo? (cap a)) (flo? (cap b)))
           (: mid (cat (asflo a) (cat (cat (L (L 'movqrx 'r0 'f0)) (spush 'r0))
                       (cat (asflo b) (cat (spop 'r1) (L (L 'movqxr 'f1 'r1))))))
              (? (= op '+) (L 'double (cat mid (L (L 'addsd 'f0 'f1))))
                 (= op '*) (L 'double (cat mid (L (L 'mulsd 'f0 'f1))))
                 (= op '-) (L 'double (cat mid (L (L 'subsd 'f1 'f0) (L 'movsd 'f0 'f1))))
                 (= op '/) (L 'double (cat mid (L (L 'divsd 'f1 'f0) (L 'movsd 'f0 'f1))))
                 ; IEEE compare: UNORDERED (a NaN operand) must answer false for
                 ; every relation and true only for !=. above/ae read CF=0, which
                 ; unordered sets, so < and <= COMPARE SWAPPED and ride above/ae;
                 ; == and != carry the parity bit (unordered -> PF=1) explicitly.
                 (member? op '(lt le))
                  (L 'long (cat mid (L (L 'ucomisd 'f0 'f1)
                                       (L 'set (? (= op 'lt) 'above 'ae) 'r0))))
                 (member? op '(gt ge))
                  (L 'long (cat mid (L (L 'ucomisd 'f1 'f0)
                                       (L 'set (? (= op 'gt) 'above 'ae) 'r0))))
                 (= op 'eq)
                  (L 'long (cat mid (L (L 'ucomisd 'f1 'f0) (L 'set 'eq 'r0)
                                       (L 'set 'np 'r1) (L 'and 'r0 'r0 'r1))))
                 (= op 'ne)
                  (L 'long (cat mid (L (L 'ucomisd 'f1 'f0) (L 'set 'ne 'r0)
                                       (L 'set 'p 'r1) (L 'or 'r0 'r0 'r1))))
                 'bad))
          (: ta (cap a) tb (cap b)
             pa (ptr? ta) pb (ptr? tb)
             ; left lands in r1, right in r0; scale the int side of ptr math
             mid (cat (caup a) (cat (spush 'r0) (cat (caup b) (spop 'r1))))
             back (L (L 'mov 'r0 'r1))
             (? (= op '+)
                 (? (&& pa pb) 'bad
                    pa (L ta (cat mid (cat (? (< 1 (tsz g (caup ta)))
                                             (L (L 'imul 'r0 'r0 (tsz g (caup ta)))) ())
                                      (cat (L (L 'add 'r1 'r1 'r0)) back))))
                    pb (L tb (cat mid (cat (? (< 1 (tsz g (caup tb)))
                                             (L (L 'imul 'r1 'r1 (tsz g (caup tb)))) ())
                                      (cat (L (L 'add 'r1 'r1 'r0)) back))))
                    (L 'long (cat mid (cat (L (L 'add 'r1 'r1 'r0)) back))))
                (= op '-)
                 (? (&& pa pb)
                     (? (= (tsz g (caup ta)) (tsz g (caup tb)))
                        (L 'long (cat mid (cat (L (L 'sub 'r1 'r1 'r0))
                                          (cat back (? (< 1 (tsz g (caup ta)))
                                                       (L (L 'sar 'r0 (lg2 (tsz g (caup ta)))))
                                                       ())))))
                        'bad)
                    pa (L ta (cat mid (cat (? (< 1 (tsz g (caup ta)))
                                             (L (L 'imul 'r0 'r0 (tsz g (caup ta)))) ())
                                      (cat (L (L 'sub 'r1 'r1 'r0)) back))))
                    pb 'bad
                    (L 'long (cat mid (cat (L (L 'sub 'r1 'r1 'r0)) back))))
                (: unsg (|| (usg? ta) (usg? tb))            ; either operand unsigned -> unsigned divide/compare
                   tail (? (= op '*) (L (L 'imul 'r1 'r1 'r0))
                           (= op '/) (L (L (? unsg 'udiv 'div) 'r1 'r1 'r0))
                           (= op '%) (L (L (? unsg 'urem 'rem) 'r1 'r1 'r0 'r3))
                           (= op '&) (L (L 'and 'r1 'r1 'r0))
                           (= op '|) (L (L 'or 'r1 'r1 'r0))
                           (= op '^) (L (L 'xor 'r1 'r1 'r0))
                           'bad)
                   (? (! (bad? tail))
                      (L (ubin ta tb) (cat mid (cat tail back)))
                      (member? op '(eq ne lt le gt ge))
                       (L 'long (cat mid (L (L 'cmp 'r1 'r0) (L 'set (scc op unsg) 'r0))))
                      'bad))))))

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
   (escan g r) (: _ (? (&& (two? r) (leas? (caup r))) (pin g 'fesc 1) ()) r)
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
   (sibs fs lw el)
    (? (! (two? fs)) ()
       (: f (cap fs) r (cup fs)
          lw2 (? (&& (two? f) (&& (= (cap f) 'lea) (= (cauup f) 'r4))) 1 lw)
          cand (&& (! lw2) (&& (two? f) (|| (&& (= (cap f) 'call) (two? (cup f)))
                                            (= f '(callr r3)))))
          (? (&& cand (epi4? r))
              (cat (sibjmp f) (sibs (cup (cup (cup (cup r)))) () el))
             (&& cand (lbl-epi? r))
              (cat (sibjmp f) (sibs r () el))
             (&& cand (: nx (cap r) (&& (two? nx) (&& (= (cap nx) 'jmp) (peep el (caup nx) ())))))
              (cat (sibjmp f) (sibs (cup r) () el))
             (link f (sibs r (? (&& (two? f) (member? (cap f) '(call callr raw))) () lw2) el)))))   ; raw: a builtin splice consumes its address like a call
   (sibcall g fs) (? (peep g 'fesc ()) fs (sibs fs () (elabs fs (tablet 0))))

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
          (flo? ty) (cat (asflo r) (fstf ty 'r4 off 'f0))
          (cat (asint r) (cat (cvt ty 'r0) (L (L (stop ty) 'r4 off 'r0))))))
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
   ; the label a pointer initializer points at (abs64) | () -- a string, a
   ; function name, a decayed global array/var, or &global (all file-scope)
   (imlabel g ini)
    (? (= (cap ini) 'cast) (imlabel g (cauup ini))   ; a cast keeps the label ((word)&x, (op)f)
       (= (cap ini) 'str)
        (: l (nlab g ".S") _ (pin g 'strs (link (L l (caup ini)) (g 'strs))) l)
       (&& (= (cap ini) 'var) (peep (g 'fns) (caup ini) ())) (intern (caup ini))
       (&& (= (cap ini) 'var) (two? (peep (g 'glob) (caup ini) 0))) (cap (peep (g 'glob) (caup ini) 0))
       (&& (&& (= (cap ini) 'addr) (two? (caup ini))) (&& (= (cap (caup ini)) 'var)
           (peep (g 'fns) (caup (caup ini)) ()))) (intern (caup (caup ini)))
       (&& (&& (= (cap ini) 'addr) (two? (caup ini))) (&& (= (cap (caup ini)) 'var)
           (two? (peep (g 'glob) (caup (caup ini)) 0)))) (cap (peep (g 'glob) (caup (caup ini)) 0))
       ())
   (imgbytes g ty ini)                              ; a byte/fix list of length tsz(ty) | 'bad
    (? (! (two? ini)) (zeros (tsz g ty))
       (= (cap ini) 'flo) (? (= ty 'float) (le4s (fbits32 (caup ini)))    ; a float literal -> 4 IEEE single bytes
                             (flo? ty) (le8s (fbits (caup ini))) 'bad)     ; a double literal -> 8 IEEE bytes
       (= (cap ini) 'num) (? (aggish? ty) 'bad (= ty 'float) (le4s (fbits32 (+ 0.0 (caup ini))))
                             (flo? ty) (le8s (fbits (+ 0.0 (caup ini)))) (imnum g ty (caup ini)))
       (&& (= (cap ini) 'str) (arr? ty))
        (: t (caup ini) n (tsz g ty)
           (bs i acc) (? (<= n i) (rev acc) (bs (+ i 1) (link (? (< i (tally t)) (t i) 0) acc)))
           (bs 0 ()))
       (ptr? ty) (: lbl (imlabel g ini) (? lbl (L (L 'fix 8 'abs64 lbl 0)) 'bad))   ; a data pointer -> abs64
       ; a label cast to a WORD-SIZED integer ((word)nif_absent, (intptr_t)f) is
       ; still the label's address; a non-label cast folds through to its value
       (&& (= (cap ini) 'cast) (&& (! (aggish? ty)) (&& (! (flo? ty)) (= (tsz g ty) 8))))
        (: lbl (imlabel g ini)
           (? lbl (L (L 'fix 8 'abs64 lbl 0)) (imgbytes g ty (cauup ini))))
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
   (cgdecl g env pairs)
    (: (one ps env2 acc)
        (? (! (two? ps)) (L acc env2)
           (: p (cap ps)
              ty (caup p)
              init (cauup p)
              span (& (+ (tsz g ty) 7) -8)
              off (- 0 (+ (peep g 'off 0) span))
              _ (pin g 'off (+ (peep g 'off 0) span))
              env3 (link (L (cap p) off ty) env2)
              (? (! (two? init)) (one (cup ps) env3 acc)
                 (|| (= (cap init) 'init) (&& (= (cap init) 'str) (arr? ty)))
                  (? (&& (= (cap init) 'init) (! (aggish? ty))) 'bad   ; a brace for a scalar
                     (: f (cgfill g env3 off ty init)
                        (? (bad? f) 'bad
                           (one (cup ps) env3 (cat acc (cat (cgzero off span) f))))))
                 (arr? ty) 'bad                          ; a bare-expr init of an array
                 (stru? ty)                              ; a struct local from a struct VALUE (an address): 16-byte copy
                  (? (! (sse2? g ty)) 'bad
                     (: r (cgexpr g env3 init)
                        (? (bad? r) 'bad
                           (one (cup ps) env3
                                (cat acc (cat (caup r)
                                 (L (L 'ld 'r1 'r0 0) (L 'st 'r4 off 'r1)
                                    (L 'ld 'r1 'r0 8) (L 'st 'r4 (+ off 8) 'r1))))))))
                 (: r (cgexpr g env3 init)               ; a scalar (a pointer = string rides cgexpr -> la)
                    (? (bad? r) 'bad
                       (flo? ty) (one (cup ps) env3 (cat acc (cat (asflo r) (fstf ty 'r4 off 'f0))))
                       (one (cup ps) env3
                            (cat acc (cat (asint r)
                                     (cat (cvt ty 'r0)
                                          (L (L (stop ty) 'r4 off 'r0)))))))))))
       (one pairs env ()))

   ; stmt -> forms | 'bad
   (cgstmt g env s)
    (: k (cap s)
       (? (= k 'ret) (? (! (two? (caup s))) epi                          ; bare `return;` -- just the epilogue
                      (: r (cgexpr g env (caup s))
                        rt (cap (peep (g 'sigs) (g 'fn) (L 'long ())))   ; the current function's return type
                        (? (bad? r) 'bad
                           (flo? rt) (cat (asflo r) epi)                 ; a double return leaves f0 (xmm0)
                           (sse2? g rt)                                  ; a two-double struct returns as the xmm PAIR
                            (cat (caup r) (cat (fldf 'double (xmmreg 0) 'r0 0)
                                          (cat (fldf 'double (xmmreg 1) 'r0 8) epi)))
                           (|| (stru? rt) (stru? (cap r))) 'bad          ; any other struct return, or a struct where a scalar is due
                           (flo? (cap r)) (cat (asint r) epi)            ; a double value, an int return -> truncate to r0
                           (cat (caup r) epi))))                         ; int -> int, as before
          (= k 'expr) (: r (cgexpr g env (caup s))
                         (? (bad? r) 'bad (caup r)))
          (= k 'nop) ()
          (= k 'tdef) ()                            ; a block-scope _Static_assert (already checked at parse)
          (= k 'blk) (cgitems g env (caup s) ())
          (= k 'if)
           (: c (ctest g env (caup s))
              t (cgstmt g env (cauup s))
              le (nlab g ".e")
              (? (|| (bad? c) (bad? t)) 'bad
                 (! (two? (caup (cuup s))))
                  (cat (caup c) (cat (L (L 'cmp 'r0 0) (L 'br 'eq le)) (cat t (L (L 'label le)))))
                 (: el (cgstmt g env (caup (cuup s)))
                    ld (nlab g ".d")
                    (? (bad? el) 'bad
                       (cat (caup c) (cat (L (L 'cmp 'r0 0) (L 'br 'eq le))
                        (cat t (cat (L (L 'jmp ld) (L 'label le))
                         (cat el (L (L 'label ld)))))))))))
          (= k 'while)
           (: lc (nlab g ".c") ld (nlab g ".d")
              c (ctest g env (caup s))
              _ (pin g 'brk (link ld (g 'brk)))
              _ (pin g 'cnt (link lc (g 'cnt)))
              b (cgstmt g env (cauup s))
              _ (pin g 'brk (cup (g 'brk)))
              _ (pin g 'cnt (cup (g 'cnt)))
              (? (|| (bad? c) (bad? b)) 'bad
                 (cat (L (L 'label lc))
                  (cat (caup c) (cat (L (L 'cmp 'r0 0) (L 'br 'eq ld))
                   (cat b (L (L 'jmp lc) (L 'label ld))))))))
          (= k 'for)
           (: init (caup s) cnd (cauup s) stp (caup (cuup s)) body (cauup (cuup s))
              lc (nlab g ".c") ls (nlab g ".s") ld (nlab g ".d")
              ir (? (! (two? init)) (L () env)
                    (= (cap init) 'decl) (cgdecl g env (caup init))
                    (: r (cgexpr g env (caup init))
                       (? (bad? r) 'bad (L (caup r) env))))
              (? (bad? ir) 'bad
                 (: env2 (caup ir)
                    c (? (two? cnd) (ctest g env2 cnd) ())
                    _ (pin g 'brk (link ld (g 'brk)))
                    _ (pin g 'cnt (link ls (g 'cnt)))
                    b (cgstmt g env2 body)
                    _ (pin g 'brk (cup (g 'brk)))
                    _ (pin g 'cnt (cup (g 'cnt)))
                    st2 (? (two? stp) (cgexpr g env2 stp) ())
                    (? (|| (bad? c) (|| (bad? b) (bad? st2))) 'bad
                       (cat (cap ir)
                        (cat (L (L 'label lc))
                         (cat (? (two? cnd) (cat (caup c) (L (L 'cmp 'r0 0) (L 'br 'eq ld))) ())
                          (cat b
                           (cat (L (L 'label ls))
                            (cat (? (two? st2) (caup st2) ())
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
              c (ctest g env (cauup s))
              (? (|| (bad? b) (bad? c)) 'bad
                 (cat (L (L 'label lt))
                  (cat b
                   (cat (L (L 'label lc))
                    (cat (caup c) (L (L 'cmp 'r0 0) (L 'br 'ne lt) (L 'label ld))))))))
          (= k 'goto) (L (L 'jmp (intern (+ (g 'fn) (+ "." (caup s))))))
          (= k 'lbl) (L (L 'label (intern (+ (g 'fn) (+ "." (caup s))))))
          (= k 'switch)
           (: c (cgexpr g env (caup s))
              (? (bad? c) 'bad
                 (: items (cauup s)
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
                                      (go (cup l) (cat acc (L (L 'cmp 'r0 (caup e2))
                                                              (L 'br 'eq (cauup e2)))))
                                      (go (cup l) acc))))
                            (go labs ()))
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
                                      (: r (cgstmt g env2 it)
                                         (? (bad? r) 'bad
                                            (go (cup is) ls env2 (cat acc r)))))))
                            (go items labs env ()))
                    _ (pin g 'brk (cup (g 'brk)))
                    (? (bad? body) 'bad
                       (cat (caup c)
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
             (: r (cgstmt g env it)
                (? (bad? r) 'bad
                   (cgitems g env (cup items) (cat acc r)))))))

   (cgfn g f)                                       ; ('fn name params ('blk items)) -> forms | 'bad
    (: params (cauup f)
       _ (pin g 'off 8)                              ; slot -8 = saved r3 (see epi)
       _ (pin g 'fesc ())                            ; fresh escape flag (the sibcall gate reads it)
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
                 (stru? pty) 'bad                    ; any other by-value struct stays ahead
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
       sp0 (? vararg (vaspill params) (spill params 0 0 0 () ()))
       (? (bad? sp0) 'bad
          (: body (cgitems g (caup sp0) (caup (caup (cuup f))) ())
             (? (bad? body) 'bad
                (: frame (& (+ (peep g 'off 0) 15) -16)
                   (sibcall g
                    (cat (L (L 'label (intern (caup f)))
                            (L 'push 'r4) (L 'mov 'r4 'sp) (L 'sub 'sp 'sp frame)
                            (L 'st 'r4 -8 'r3))
                     (cat (cap sp0)
                      (cat body (cat (L (L 'li 'r0 0)) epi))))))))))

   ; the data tail: globals in declaration order, then the string table
   (cgdata g)
    (: (globs gs acc)
        (? (! (two? gs)) acc
           (: ge (peep (g 'glob) (cap gs) 0)
              lbl (cap ge) ty (caup ge) init (cauup ge)
              bytes (cgimage g ty init)                 ; a constant image | 'bad (label values -> 4d)
              (? (bad? bytes) 'bad
                 (globs (cup gs) (cat acc (L (L 'label lbl) (L 'raw bytes)))))))
       (strs ss acc)
        (? (! (two? ss)) acc
           (: p (cap ss)
              (bts s i bacc) (? (< i 0) bacc (bts s (- i 1) (link (s i) bacc)))
              t (caup p)
              (strs (cup ss) (cat acc (L (L 'label (cap p))
                                         (L 'raw (cat (bts t (- (tally t) 1) ()) (L 0))))))))
       (: gb (globs (rev (g 'globs)) ())
          (? (bad? gb) 'bad (cat gb (strs (g 'strs) ())))))

   ; the shared core: build the gen state, then TEXT (the functions, no _start)
   ; and DATA (globals + strings) separately -> (g textforms dataforms) | ().
   (cgen-core ast stbl sigs)
    (: g (: t (tablet 0) _ (pin t 'n 0) _ (pin t 'brk ()) _ (pin t 'cnt ())
            _ (pin t 'glob (tablet 0)) _ (pin t 'globs ()) _ (pin t 'strs ())
            _ (pin t 'fns (tablet 0)) _ (pin t 'stag stbl) _ (pin t 'sigs sigs) t)
       ; pass 0: every function name -- so a bare use of one is its address (la).
       ; the sig table too: an mproto sibling (`double sin(..), cos(..);`) has a
       ; sig but no proto form of its own
       (recfns fs) (? (! (two? fs)) 1
                      (: f (cap fs)
                         _ (? (member? (cap f) '(fn proto)) (pin (g 'fns) (caup f) 1) ())
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
                    (? (bad? r) ()
                       (gfns (cup fs) (cat acc r)
                             (|| saw (= (caup f) "main"))))))))
       (? ok (gfns (caup ast) () ()) ()))
   (cgen ast stbl sigs)                             ; the STATIC EXECUTABLE: _start (crt0) + text + data -> (1 forms) | () -- needs main
    (: crt0 (L (L 'call 'main) (L 'mov 'r6 'r0) (L 'li 'r0 60) (L 'sys))
       r (cgen-core ast stbl sigs)
       (? (! (two? r)) ()
          (! (nthr r 3)) ()                          ; no main -> no program (the exe has nothing to start)
          (L 1 (cat crt0 (cat (caup r) (cauup r))))))
   ; the RELOCATABLE OBJECT view (stage 7a): text and data split, plus the
   ; DEFINED function names (global FUNC symbols) and global-variable names
   ; (global OBJECT symbols) -- the .o emitter (crew/holo/obj.l) turns the rest
   ; (undefined labels, cross-section refs) into a symbol table + relocations.
   (cgen-obj ast stbl sigs)                         ; -> (1 textforms dataforms funcnames globnames) | ()
    (: r (cgen-core ast stbl sigs)
       (? (! (two? r)) ()
          (: fnames (: (go fs acc) (? (! (two? fs)) (rev acc)
                                      (: f (cap fs) (go (cup fs) (? (= (cap f) 'fn) (link (caup f) acc) acc))))
                      (go (caup ast) ()))
             (L 1 (caup r) (cauup r) fnames (rev ((cap r) 'globs)))))))
