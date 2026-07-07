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
   (fn? ty) (&& (two? ty) (= (cap ty) 'fn))         ; ('fn) -- a function; decays to its address
   (tsz g ty) (? (ptr? ty) 8
                 (arr? ty) (* (cauup ty) (tsz g (caup ty)))
                 (stru? ty) (caup (peep (g 'stag) (caup ty) 0))
                 (= ty 'char) 1 (= ty 'short) 2 (|| (= ty 'int) (= ty 'float)) 4 8)
   ; a member's (offset ty) off a struct type, | 'bad
   (fmem g ty name)
    (? (! (stru? ty)) 'bad
       (: e (peep (g 'stag) (caup ty) 0)
          (? (! (two? e)) 'bad
             (: f (assoc name (cap e))
                (? (two? f) (L (caup f) (cauup f)) 'bad)))))
   (lg2 n) (? (= n 1) 0 (= n 2) 1 (= n 4) 2 3)
   (ldop ty) (? (= ty 'char) 'ld1 (= ty 'short) 'ld2 (= ty 'int) 'ld4 'ld)
   (stop ty) (? (= ty 'char) 'st1 (= ty 'short) 'st2 (= ty 'int) 'st4 'st)
   (cvt ty r) (? (= ty 'char) (L (L 'sx1 r)) (= ty 'short) (L (L 'sx2 r))
                 (= ty 'int) (L (L 'sx4 r)) ())
   ; -- the double lane (stage 6a, the gem): a 'double value lives in f0, not r0.
   ; its type is the flag; fbits is the compile-time IEEE-754 encoder; asflo/asint
   ; move a cgexpr result between the lanes (int<->double conversion); fcc maps a
   ; comparison to the UNSIGNED setcc ucomisd's flags want. --
   ; a float and a double share the register lane: a value in an xmm register is
   ; ALWAYS a 64-bit double; only MEMORY differs -- a `float` slot is 4 bytes, so
   ; a load widens (ldss + cvtss2sd) and a store narrows (cvtsd2ss + stss). fldf/
   ; fstf pick the lane by the DECLARED type; every loaded float types 'double.
   (flo? ty) (|| (= ty 'double) (= ty 'float))
   (fbits x)                                        ; finite double -> its IEEE-754 u64 bits (ported from the glaze)
    (? (= x 0.0) 0
       (: s (? (< x 0.0) 1 0) ax (? (< x 0.0) (- 0.0 x) x)
          eu ((: (go e) (? (<= ((+ e 1) 2.0) ax) (go (+ e 1)) e)) (int (/ (log ax) (log 2.0))))
          e  ((: (go e) (? (< ax (e 2.0)) (go (- e 1)) e)) eu)
          (+ (* s 9223372036854775808) (+ (* (+ e 1023) 4503599627370496)
             (int (* (- (/ ax (e 2.0)) 1.0) 4503599627370496.0))))))
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
   (fcc op) (? (= op 'lt) 'below (= op 'le) 'be (= op 'gt) 'above (= op 'ge) 'ae op)
   ; a truth value in r0 that `cmp r0 0` can test: a double folds to d != 0.0
   (ctest g env e)
    (: r (cgexpr g env e)
       (? (bad? r) 'bad
          (flo? (cap r))
           (L 'long (cat (caup r) (L (L 'li 'r1 0) (L 'movqxr 'f1 'r1) (L 'ucomisd 'f0 'f1) (L 'set 'ne 'r0))))
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
                 (= (cap en) 'loc) (L (cauup en) (L (L 'lea 'r0 'r4 (caup en))))
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
                 (L ty (cat fill (L (L 'lea 'r0 'r4 off))))))
          'bad))

   ; -- expressions: answers (type forms) | 'bad, the value in r0 --
   (cgexpr g env e)
    (: k (cap e)
       (? (= k 'num) (L 'long (L (L 'li 'r0 (caup e))))
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
                       (stru? ty) 'bad               ; no struct VALUES in registers
                       (flo? ty) (L 'double (cat (caup r) (fldf ty 'f0 'r0 0)))
                       (L ty (cat (caup r) (L (L (ldop ty) 'r0 'r0 0))))))))
          (= k 'var)
           (: en (vent g env (caup e))
              (? (bad? en)
                  (? (peep (g 'fns) (caup e) ())     ; a function name is its address
                     (L (L 'ptr (L 'fn)) (L (L 'la 'r0 (intern (caup e))))) 'bad)
                 (: ty (cauup en)
                    (? (stru? ty) 'bad               ; a struct name is only an lvalue base
                       (arr? ty)                     ; arrays decay to their address
                        (? (= (cap en) 'loc)
                           (L (L 'ptr (caup ty)) (L (L 'lea 'r0 'r4 (caup en))))
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
              (? (bad? r) 'bad (L (L 'ptr (cap r)) (caup r))))
          (= k 'deref)
           (: r (clval g env e)                     ; clval already walked the pointer
              (? (bad? r) 'bad
                 (: ty (cap r)
                    (? (arr? ty) (L (L 'ptr (caup ty)) (caup r))   ; pointee array: decay again
                       (fn? ty) (L (L 'ptr ty) (caup r))           ; *fp -- a function is its address
                       (stru? ty) 'bad                             ; no struct values
                       (flo? ty) (L 'double (cat (caup r) (fldf ty 'f0 'r0 0)))
                       (L ty (cat (caup r) (L (L (ldop ty) 'r0 'r0 0))))))))
          (= k 'asn)
           (: lv (clval g env (caup e))
              (? (bad? lv) 'bad
                 (arr? (cap lv)) 'bad                ; an array is not assignable
                 (stru? (cap lv))                    ; a whole-struct copy (dest r1, src r0)
                  (: rv (clval g env (cauup e))
                     (? (bad? rv) 'bad
                        (! (stru? (cap rv))) 'bad
                        (L (cap lv)
                           (cat (caup lv) (cat (L (L 'push 'r0))
                            (cat (caup rv) (cat (L (L 'pop 'r1))
                             (bcopy 0 (tsz g (cap lv)) ()))))))))
                 (flo? (cap lv))                     ; a float/double store (addr in r1, value in f0; narrow if float)
                  (: r (cgexpr g env (cauup e))
                     (? (bad? r) 'bad
                        (L 'double (cat (caup lv) (cat (L (L 'push 'r0))
                         (cat (asflo r) (cat (L (L 'pop 'r1)) (fstf (cap lv) 'r1 0 'f0))))))))
                 (: r (cgexpr g env (cauup e))
                    (? (bad? r) 'bad
                       (: ty (cap lv)
                          (L ty (cat (caup lv)
                                 (cat (L (L 'push 'r0))
                                  (cat (asint r)
                                   (cat (L (L 'pop 'r1))
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
                     (= (caup e) 'not)                 ; !d = (d == 0.0)
                      (L 'long (cat (caup r) (L (L 'li 'r0 0) (L 'movqxr 'f1 'r0)
                                                (L 'ucomisd 'f0 'f1) (L 'set 'eq 'r0))))
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
                 (L (cap t)
                    (cat (caup c) (cat (L (L 'cmp 'r0 0) (L 'br 'eq le))
                     (cat (caup t) (cat (L (L 'jmp ld) (L 'label le))
                      (cat (caup el) (L (L 'label ld))))))))))
          ; -- the varargs builtins (cc's simplified all-stack ABI): a va_list is
          ; a char* cursor over the caller's pushed argument block. va_start aims
          ; it past the named params; va_arg reads a slot and steps 8; va_end nops.
          (= k 'vastart)
           (: lv (clval g env (caup e))                 ; &ap in r0
              nc (tally (caup (peep (g 'sigs) (g 'fn) (L () () ()))))   ; the current function's named-param count
              (? (bad? lv) 'bad
                 (L 'long (cat (caup lv) (L (L 'lea 'r1 'r4 (+ 16 (* 8 nc))) (L 'st 'r0 0 'r1))))))
          (= k 'vaarg)
           (: lv (clval g env (caup e)) ty (cauup e)
              (? (bad? lv) 'bad
                 (flo? ty)
                  (L 'double (cat (caup lv) (L (L 'mov 'r3 'r0) (L 'ld 'r2 'r3 0)
                                               (L 'ldsd 'f0 'r2 0) (L 'add 'r2 'r2 8) (L 'st 'r3 0 'r2))))
                 (L ty (cat (caup lv) (L (L 'mov 'r3 'r0) (L 'ld 'r2 'r3 0)
                                         (L (ldop ty) 'r0 'r2 0) (L 'add 'r2 'r2 8) (L 'st 'r3 0 'r2))))))
          (= k 'vaend) (L 'long ())
          (= k 'call)
           ; the SysV ABI: integer/pointer args ride r6 r5 r2 r1 r7 r8 (<=6),
           ; double args ride f0..f7 (<=8), SEPARATE counters, placed by the
           ; callee's PARAM type (a direct call reads the sig table -- converting
           ; the arg to it), else by the arg's own type. the result rides f0 for
           ; a double-returning callee, r0 otherwise. args evaluate left to right,
           ; each pushed to the machine stack, then popped reversed into place.
           (: head (caup e) args (cauup e)
              direct (&& (= (cap head) 'var) (bad? (vent g env (caup head))))
              sig (? direct (peep (g 'sigs) (caup head) ()) ())
              ptys (? (two? sig) (caup sig) ())
              rt (? (two? sig) (cap sig) 'long)
              variadic (? (two? sig) (nthr sig 2) ())
              ; a VARIADIC callee rides cc's all-stack ABI: every argument (named
              ; args converted to their param type, varargs as-is) is pushed as an
              ; 8-byte slot, arg0 landing at [rbp+16], a pad word keeping rsp 16-
              ; aligned; the caller pops the block after the call.
              (? (&& direct variadic)
                  (: n (tally args)
                     pad (? (= (& n 1) 1) 8 0)
                     (blocks as i acc)
                      (? (! (two? as)) (rev acc)
                         (: a (cgexpr g env (cap as))
                            (? (bad? a) 'bad
                               (: pty (nthty ptys i)
                                  wd (? pty (flo? pty) (flo? (cap a)))
                                  conv (? wd (asflo a) (asint a))
                                  blk (? wd (cat conv (L (L 'movqrx 'r0 'f0) (L 'push 'r0)))
                                            (cat conv (L (L 'push 'r0))))
                                  (blocks (cup as) (+ i 1) (link blk acc))))))
                     bl (blocks args 0 ())
                     (? (bad? bl) 'bad
                        (: pushcode (foldl (\ ac b (cat ac b)) (? (< 0 pad) (L (L 'sub 'sp 'sp 8)) ()) (rev bl))
                           (L rt (cat pushcode (cat (L (L 'call (intern (caup head))))
                                                    (L (L 'add 'sp 'sp (+ pad (* 8 n))))))))))
                 (call-fixed g env head args direct ptys rt)))
          (= k 'clit)                              ; a compound literal as a value: fill the temp, load it
           (: lv (clval g env e)
              (? (bad? lv) 'bad (loadval (cap lv) (caup lv))))
          (= k 'bin) (cgbin g env e)
          'bad))
   ; the fixed-arity call (SysV registers). params named uniquely so no lambda
   ; parameter shadows a sibling :-local through boxfix's shared cell (stage 5).
   (call-fixed g env hd ags dir pts ret)
    (: (ca as i gpc xmmc pf tg)                          ; -> (pushforms targets) | 'bad
        (? (! (two? as)) (L pf (rev tg))
           (: a (cgexpr g env (cap as))
              (? (bad? a) 'bad
                 (: pty (nthty pts i)
                    wd (? pty (flo? pty) (flo? (cap a)))   ; classify by the param type if known, else the arg's
                    (? (&& wd (< 7 xmmc)) 'bad       ; over 8 double args
                       (&& (! wd) (< 5 gpc)) 'bad     ; over 6 integer args
                       (: push (? wd (cat (asflo a) (L (L 'movqrx 'r0 'f0) (L 'push 'r0)))
                                     (cat (asint a) (L (L 'push 'r0))))
                          (ca (cup as) (+ i 1) (? wd gpc (+ gpc 1)) (? wd (+ xmmc 1) xmmc)
                              (cat pf push) (link (? wd (L 'x xmmc) (L 'g gpc)) tg))))))))
       car (ca ags 0 0 0 () ())
       (? (bad? car) 'bad
          (: pf (cap car) tg (caup car)
             (popr ts acc) (? (! (two? ts)) acc
                              (: t (cap ts)
                                 (popr (cup ts) (cat acc
                                   (? (= (cap t) 'g) (L (L 'pop (nthr argregs (caup t))))
                                      (L (L 'pop 'r0) (L 'movqxr (xmmreg (caup t)) 'r0)))))))
             pops (popr (rev tg) ())
             (? dir
                 (L ret (cat pf (cat pops (L (L 'call (intern (caup hd)))))))
                (: hr (cgexpr g env hd)                   ; a function-pointer value: park in r3, callr
                   (? (bad? hr) 'bad
                      (L 'long (cat pf (cat (caup hr) (cat (L (L 'mov 'r3 'r0))
                                (cat pops (L (L 'callr 'r3)))))))))))))
   (cgbin g env e)
    (: op (caup e)
       a (cgexpr g env (cauup e))
       b (cgexpr g env (caup (cuup e)))
       rhs (caup (cuup e))
       (? (|| (bad? a) (bad? b)) 'bad
          ; a constant count rides the immediate shift; a variable count
          ; rides shlv/sarv with the count PINNED to r1 (holo's contract)
          (member? op '(shl shr))
           (? (= (cap rhs) 'num)
              (L 'long (cat (caup a) (L (L (? (= op 'shl) 'shl 'sar) 'r0 (caup rhs)))))
              (L 'long (cat (caup a)
                        (cat (L (L 'push 'r0))
                         (cat (caup b) (L (L 'mov 'r1 'r0) (L 'pop 'r0)
                                          (L (? (= op 'shl) 'shlv 'sarv) 'r0 'r1)))))))
          ; the double lane: either operand double -> both to double (f1=left,
          ; f0=right through the gp stack), then the scalar-double op or ucomisd.
          (|| (flo? (cap a)) (flo? (cap b)))
           (: mid (cat (asflo a) (cat (L (L 'movqrx 'r0 'f0) (L 'push 'r0))
                       (cat (asflo b) (L (L 'pop 'r1) (L 'movqxr 'f1 'r1)))))
              (? (= op '+) (L 'double (cat mid (L (L 'addsd 'f0 'f1))))
                 (= op '*) (L 'double (cat mid (L (L 'mulsd 'f0 'f1))))
                 (= op '-) (L 'double (cat mid (L (L 'subsd 'f1 'f0) (L 'movsd 'f0 'f1))))
                 (= op '/) (L 'double (cat mid (L (L 'divsd 'f1 'f0) (L 'movsd 'f0 'f1))))
                 (member? op '(eq ne lt le gt ge))
                  (L 'long (cat mid (L (L 'ucomisd 'f1 'f0) (L 'set (fcc op) 'r0))))
                 'bad))
          (: ta (cap a) tb (cap b)
             pa (ptr? ta) pb (ptr? tb)
             ; left lands in r1, right in r0; scale the int side of ptr math
             mid (cat (caup a) (cat (L (L 'push 'r0)) (cat (caup b) (L (L 'pop 'r1)))))
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
                (: tail (? (= op '*) (L (L 'imul 'r1 'r1 'r0))
                           (= op '/) (L (L 'div 'r1 'r1 'r0))
                           (= op '%) (L (L 'rem 'r1 'r1 'r0 'r3))
                           (= op '&) (L (L 'and 'r1 'r1 'r0))
                           (= op '|) (L (L 'or 'r1 'r1 'r0))
                           (= op '^) (L (L 'xor 'r1 'r1 'r0))
                           'bad)
                   (? (! (bad? tail))
                      (L 'long (cat mid (cat tail back)))
                      (member? op '(eq ne lt le gt ge))
                       (L 'long (cat mid (L (L 'cmp 'r1 'r0) (L 'set op 'r0))))
                      'bad))))))

   epi (L (L 'mov 'sp 'r4) (L 'pop 'r4) (L 'ret))

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
    (? (= (cap ini) 'str)
        (: l (nlab g ".S") _ (pin g 'strs (link (L l (caup ini)) (g 'strs))) l)
       (&& (= (cap ini) 'var) (peep (g 'fns) (caup ini) ())) (intern (caup ini))
       (&& (= (cap ini) 'var) (two? (peep (g 'glob) (caup ini) 0))) (cap (peep (g 'glob) (caup ini) 0))
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
       (? (= k 'ret) (: r (cgexpr g env (caup s))
                        rt (cap (peep (g 'sigs) (g 'fn) (L 'long ())))   ; the current function's return type
                        (? (bad? r) 'bad
                           (flo? rt) (cat (asflo r) epi)                 ; a double return leaves f0 (xmm0)
                           (flo? (cap r)) (cat (asint r) epi)            ; a double value, an int return -> truncate to r0
                           (cat (caup r) epi)))                          ; int -> int, as before
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
       _ (pin g 'off 0)
       _ (pin g 'fn (caup f))
       sig (peep (g 'sigs) (caup f) ())
       vararg (? (two? sig) (nthr sig 2) ())
       ; spill each param from its SysV register: integers from r6 r5 r2 r1 r7 r8
       ; (<=6), doubles from f0..f7 (<=8), SEPARATE counters.
       (spill ps gpi xmmi env acc)
        (? (! (two? ps)) (L acc env)
           (: p (cap ps) pty (caup p)
              off (- 0 (+ (peep g 'off 0) 8))
              _ (pin g 'off (+ (peep g 'off 0) 8))
              env2 (link (L (cap p) off pty) env)
              (? (flo? pty)
                  (? (< 7 xmmi) 'bad
                     (spill (cup ps) gpi (+ xmmi 1) env2 (cat acc (fstf pty 'r4 off (xmmreg xmmi)))))
                 (? (< 5 gpi) 'bad
                    (spill (cup ps) (+ gpi 1) xmmi env2 (cat acc (L (L 'st 'r4 off (nthr argregs gpi)))))))))
       ; a VARIADIC function reads its NAMED params off the caller's stack
       ; ([rbp+16+i*8], cc's all-stack ABI) -- no register spill, no save area
       (place ps i env) (? (! (two? ps)) env
                           (place (cup ps) (+ i 1)
                                  (link (L (cap (cap ps)) (+ 16 (* i 8)) (caup (cap ps))) env)))
       sp0 (? vararg (L () (place params 0 ())) (spill params 0 0 () ()))
       (? (bad? sp0) 'bad
          (: body (cgitems g (caup sp0) (caup (caup (cuup f))) ())
             (? (bad? body) 'bad
                (: frame (& (+ (peep g 'off 0) 15) -16)
                   (cat (L (L 'label (intern (caup f)))
                           (L 'push 'r4) (L 'mov 'r4 'sp) (L 'sub 'sp 'sp frame))
                    (cat (cap sp0)
                     (cat body (cat (L (L 'li 'r0 0)) epi)))))))))

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
       ; pass 0: every function name -- so a bare use of one is its address (la)
       (recfns fs) (? (! (two? fs)) 1
                      (: f (cap fs)
                         _ (? (member? (cap f) '(fn proto)) (pin (g 'fns) (caup f) 1) ())
                         (recfns (cup fs))))
       _ (recfns (caup ast))
       ; pass 1: record every global (name -> (label ty init)); cgimage
       ; validates the initializer at data-emission time (a label-valued image
       ; refuses the whole compile -- 4d)
       (rec fs)
        (? (! (two? fs)) 1
           (: f (cap fs)
              (? (! (= (cap f) 'gdecl)) (rec (cup fs))
                 (: (one ps)
                     (? (! (two? ps)) (rec (cup fs))
                        (: p (cap ps)
                           _ (pin (g 'glob) (cap p) (L (intern (cap p)) (caup p) (cauup p)))
                           _ (pin g 'globs (link (cap p) (g 'globs)))
                           (one (cup ps))))
                    (one (caup f))))))
       ok (rec (caup ast))
       ; always emit text + data (a library TU has no main); `saw` rides out so
       ; the EXECUTABLE path can insist on one.
       (gfns fs acc saw)
        (? (! (two? fs))
           (: dat (cgdata g) (? (bad? dat) () (L g acc dat saw)))
           (: f (cap fs)
              (? (member? (cap f) '(proto gdecl tdef)) (gfns (cup fs) acc saw)
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
