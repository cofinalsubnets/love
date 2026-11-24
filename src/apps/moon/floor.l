; src/apps/moon/floor.l -- the C type floor: laws neither syntax nor codegen, read by parse and gen.
; pure over the type vocabulary ('int .. | ('ptr t) | ('arr t n) | ('struct tag) | ('bitfield ty off w [n]));
; the word and the struct-tag table are parameters. never name a token, parse state, register or target.
(module 'moon
(:
   ; -- the type shapes --
   (ptr? ('ptr . _)) 1
   (arr? ('arr . _)) 1
   (fn? ('fn . _)) 1                     ; ('fn ret?) -- a function; decays to its address
   (stru? ('struct . _)) 1
   (bitf? ('bitfield . _)) 1             ; (bitfield uty bitoff width [n]); its lvalue is a unit address, n bytes when packed
   (cplxty? ty) (stru? ty && elem <>ty '("__cplx_double" "__cplx_float"))   ; a seeded complex

   ; -- the type model: a target's [int long llong double pointer] in bytes, the one place they are said
   tm-lp64 '(4 8 8 8 8)
   tm-ilp32 '(4 4 8 8 4)
   (tmof tgt) (elem tgt '(thumb2 thumb2sp arm thumb1 i386 i386m16 rv32 xtensa mips) ? tm-ilp32 tm-lp64)
   (tmint tm) <tm
   (tmlong tm) (tm 1)
   (tmll tm) (tm 2)
   (tmdbl tm) (tm 3)
   (tmptr tm) (tm 4)

   ; -- sizes and alignment. tm is the model, stag: tag -> (fields size align).
   ; one body: parse bakes member offsets into stag and gen trusts them.
   (tysz tm stag ty)
    (? (ptr? ty) (tmptr tm)
       (arr? ty) (<>>ty * tysz tm stag <>ty)
       (stru? ty) <>(stag <>ty)
       (bitf? ty) (two? (drop 4 ty) ? (ty 4) (tysz tm stag <>ty))   ; the unit's size: a packed one's own, else its declared type's
       (ty @ ('char || 'schar || 'cchar || 'uchar || 'bool || 'void) 1   ; void is gcc's: void * steps by bytes
             ('short || 'ushort) 2
             'float 4
             ('int || 'uint) (tmint tm)
             ('llong || 'ullong) (tmll tm)
             'double (tmdbl tm)
             ('i128 || 'u128) 16
             ('long || 'ulong) (tmlong tm)
             (tmptr tm)))
   ; a scalar aligns to its size, up to cap (16 on 64-bit, 8 under AAPCS32, 4 under SysV i386)
   (tyalign tm cap stag ty)
    (? (ptr? ty) (tmptr tm)
       (arr? ty) (tyalign tm cap stag <>ty)
       (stru? ty) (two? (drop 2 ty) ? (ty 2) <>>(stag <>ty))   ; a third element: the alignment its address carries
       (bitf? ty) (tyalign tm cap stag <>ty)
       (min (tysz tm stag ty) cap))

   ; -- integer promotions (C11 6.3.1.1) and usual arithmetic conversions (6.3.1.8).
   ; on ilp32 long meets uint at ulong, on LP64 at long.
   (parith? ty) (bitf? ty ? 1
                   (elem ty '(bool char schar cchar uchar short ushort int uint long ulong
                                 llong ullong i128 u128 float double)))
   (trank ty) (ty @ ('i128 || 'u128) 4 ('llong || 'ullong) 3 ('long || 'ulong) 2 1)
   (tusg? ty) (elem ty '(cchar uchar ushort uint ulong ullong u128))
   (tusg ty) (ty @ 'int 'uint 'long 'ulong 'llong 'ullong 'i128 'u128 ty)
   (tw tm ty) (trank ty @ 1 (tmint tm) 2 (tmlong tm) 3 (tmll tm) 16)
   ; a bit-field an int holds is an int, one of exactly unsigned int's width that, a wider one its type
   (pprom tm ty) (? (bitf? ty) (: w (ty 3) b (8 * tmint tm) (? (w < b || w = b && !(tusg? <>ty)) 'int (w = b) 'uint (pprom tm <>ty)))
                 (ty = 'ushort && tmint tm = 2) 'uint
                 (elem ty '(bool char schar cchar uchar short ushort)) 'int
                 ty)
   (puac tm ta tb)
    (? (ta = 'double || tb = 'double) 'double
       (ta = 'float || tb = 'float) 'float
     (: a (pprom tm ta) b (pprom tm tb)
      (a = b ? a
       (: ua (tusg? a) ub (tusg? b)
        (ua && ub || !ua && !ub ? (trank a < trank b ? b a)   ; same signedness: higher rank
         (: u (ua ? a b) s (ua ? b a)     ; one of each: the unsigned one, the signed one
            (? (trank s <= trank u) u     ; unsigned rank >= signed: unsigned wins
               (tw tm u < tw tm s) s    ; signed strictly wider: it represents all of u
               (tusg s))))))))            ; same width: the signed one's unsigned twin
   (tdecay ty) (arr? ty ? ['ptr <>ty] ty))
) ; module 'moon
