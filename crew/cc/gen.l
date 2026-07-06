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
(:
   ; the gen state g (a tablet): 'n the label counter, 'off the frame's
   ; high-water offset, 'brk/'cnt the loop label stacks, 'glob the global
   ; table (name -> (label ty init)), 'globs the emission order, 'strs the
   ; string table ((label . text)..). env: ((name off ty)..) frame locals.
   (nlab g pfx) (: k (peep g 'n 0) _ (pin g 'n (+ k 1)) (intern (+ pfx (show k))))
   argregs '(r6 r5 r2 r1 r7 r8)
   (nthr l i) (? (< i 1) (cap l) (nthr (cup l) (- i 1)))
   (bad? x) (id? x 'bad)
   ; -- the type floor (struct sizes come off the stag table riding in g) --
   (ptr? ty) (&& (two? ty) (= (cap ty) 'ptr))
   (arr? ty) (&& (two? ty) (= (cap ty) 'arr))
   (stru? ty) (&& (two? ty) (= (cap ty) 'struct))
   (fn? ty) (&& (two? ty) (= (cap ty) 'fn))         ; ('fn) -- a function; decays to its address
   (tsz g ty) (? (ptr? ty) 8
                 (arr? ty) (* (cauup ty) (tsz g (caup ty)))
                 (stru? ty) (caup (peep (g 'stag) (caup ty) 0))
                 (= ty 'char) 1 (= ty 'short) 2 (= ty 'int) 4 8)
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
   ; 8 little-endian bytes of a constant (the global initializer image)
   (le8s v) (: (go i acc) (? (< 7 i) (rev acc)
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
          'bad))

   ; -- expressions: answers (type forms) | 'bad, the value in r0 --
   (cgexpr g env e)
    (: k (cap e)
       (? (= k 'num) (L 'long (L (L 'li 'r0 (caup e))))
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
                 (: r (cgexpr g env (cauup e))
                    (? (bad? r) 'bad
                       (: ty (cap lv)
                          (L ty (cat (caup lv)
                                 (cat (L (L 'push 'r0))
                                  (cat (caup r)
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
           (: r (cgexpr g env (cauup e))
              (? (bad? r) 'bad
                 (L (caup e) (cat (caup r) (cvt (caup e) 'r0)))))
          (= k 'un)
           (: r (cgexpr g env (cauup e))
              (? (bad? r) 'bad
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
           (: a (cgexpr g env (caup e)) b (cgexpr g env (cauup e))
              lf (nlab g ".f") ld (nlab g ".d")
              (? (|| (bad? a) (bad? b)) 'bad
                 (L 'long
                    (cat (caup a) (cat (L (L 'cmp 'r0 0) (L 'br 'eq lf))
                     (cat (caup b) (L (L 'cmp 'r0 0) (L 'br 'eq lf)
                                      (L 'li 'r0 1) (L 'jmp ld)
                                      (L 'label lf) (L 'li 'r0 0) (L 'label ld))))))))
          (= k 'lor)
           (: a (cgexpr g env (caup e)) b (cgexpr g env (cauup e))
              lt (nlab g ".t") ld (nlab g ".d")
              (? (|| (bad? a) (bad? b)) 'bad
                 (L 'long
                    (cat (caup a) (cat (L (L 'cmp 'r0 0) (L 'br 'ne lt))
                     (cat (caup b) (L (L 'cmp 'r0 0) (L 'br 'ne lt)
                                      (L 'li 'r0 0) (L 'jmp ld)
                                      (L 'label lt) (L 'li 'r0 1) (L 'label ld))))))))
          (= k 'cond)
           (: c (cgexpr g env (caup e))
              t (cgexpr g env (cauup e))
              el (cgexpr g env (caup (cuup e)))
              le (nlab g ".e") ld (nlab g ".d")
              (? (|| (bad? c) (|| (bad? t) (bad? el))) 'bad
                 (L (cap t)
                    (cat (caup c) (cat (L (L 'cmp 'r0 0) (L 'br 'eq le))
                     (cat (caup t) (cat (L (L 'jmp ld) (L 'label le))
                      (cat (caup el) (L (L 'label ld))))))))))
          (= k 'call)
           (: head (caup e)
              args (cauup e)
              n (tally args)
              (? (< 6 n) 'bad
                 (: (pushes as acc)
                     (? (! (two? as)) acc
                        (: r (cgexpr g env (cap as))
                           (? (bad? r) 'bad
                              (: r2 (pushes (cup as) (cat acc (cat (caup r) (L (L 'push 'r0)))))
                                 (? (bad? r2) 'bad r2)))))
                    up (pushes args ())
                    (pops i acc) (? (< i 0) acc
                                    (pops (- i 1) (cat acc (L (L 'pop (nthr argregs i))))))
                    (? (bad? up) 'bad
                       ; a bare name that is NOT a variable -> a direct call by label
                       (&& (= (cap head) 'var) (bad? (vent g env (caup head))))
                        (L 'long (cat up (cat (pops (- n 1) ())
                                              (L (L 'call (intern (caup head)))))))
                       ; otherwise the head is a function-pointer VALUE: eval it,
                       ; park in the callee-saved r3, load the args, callr
                       (: hr (cgexpr g env head)
                          (? (bad? hr) 'bad
                             (L 'long (cat up (cat (caup hr)
                                          (cat (L (L 'mov 'r3 'r0))
                                           (cat (pops (- n 1) ())
                                                (L (L 'callr 'r3)))))))))))))
          (= k 'bin) (cgbin g env e)
          'bad))
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
          (cat (caup r) (cat (cvt ty 'r0) (L (L (stop ty) 'r4 off 'r0))))))
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
       (= (cap ini) 'num) (? (aggish? ty) 'bad (imnum g ty (caup ini)))
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
                       (one (cup ps) env3
                            (cat acc (cat (caup r)
                                     (cat (cvt ty 'r0)
                                          (L (L (stop ty) 'r4 off 'r0)))))))))))
       (one pairs env ()))

   ; stmt -> forms | 'bad
   (cgstmt g env s)
    (: k (cap s)
       (? (= k 'ret) (: r (cgexpr g env (caup s))
                        (? (bad? r) 'bad (cat (caup r) epi)))
          (= k 'expr) (: r (cgexpr g env (caup s))
                         (? (bad? r) 'bad (caup r)))
          (= k 'nop) ()
          (= k 'blk) (cgitems g env (caup s) ())
          (= k 'if)
           (: c (cgexpr g env (caup s))
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
              c (cgexpr g env (caup s))
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
                    c (? (two? cnd) (cgexpr g env2 cnd) ())
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
              c (cgexpr g env (cauup s))
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
       (? (< 6 (tally params)) 'bad
          (: _ (pin g 'off 0)
             _ (pin g 'fn (caup f))
             (spill ps i env acc)
              (? (! (two? ps)) (L acc env)
                 (: off (- 0 (+ (peep g 'off 0) 8))
                    _ (pin g 'off (+ (peep g 'off 0) 8))
                    (spill (cup ps) (+ i 1)
                           (link (L (cap (cap ps)) off (caup (cap ps))) env)
                           (cat acc (L (L 'st 'r4 off (nthr argregs i)))))))
             sp0 (spill params 0 () ())
             body (cgitems g (caup sp0) (caup (caup (cuup f))) ())
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

   (cgen ast stbl)                                  ; ('prog items) + the stag -> (1 forms) | ()
    (: g (: t (tablet 0) _ (pin t 'n 0) _ (pin t 'brk ()) _ (pin t 'cnt ())
            _ (pin t 'glob (tablet 0)) _ (pin t 'globs ()) _ (pin t 'strs ())
            _ (pin t 'fns (tablet 0)) _ (pin t 'stag stbl) t)
       crt0 (L (L 'call 'main) (L 'mov 'r6 'r0) (L 'li 'r0 60) (L 'sys))
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
       (gfns fs acc saw)
        (? (! (two? fs))
           (? saw (: dat (cgdata g) (? (bad? dat) () (L 1 (cat crt0 (cat acc dat))))) ())
           (: f (cap fs)
              (? (member? (cap f) '(proto gdecl tdef)) (gfns (cup fs) acc saw)
                 (: r (cgfn g f)
                    (? (bad? r) ()
                       (gfns (cup fs) (cat acc r)
                             (|| saw (= (caup f) "main"))))))))
       (? ok (gfns (caup ast) () ()) ())))
