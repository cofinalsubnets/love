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

   ; -- sizes and alignment. w is the word in bytes, stag: tag -> (fields size align).
   ; one body: parse bakes member offsets into stag and gen trusts them.
   (tysz w stag ty)
    (? (ptr? ty) w
       (arr? ty) (<>>ty * tysz w stag <>ty)
       (stru? ty) <>(stag <>ty)
       (bitf? ty) (two? (drop 4 ty) ? (ty 4) (tysz w stag <>ty))   ; the unit's size: a packed one's own, else its declared type's
       (ty @ ('char || 'schar || 'cchar || 'uchar || 'bool || 'void) 1   ; void is gcc's: void * steps by bytes
             ('short || 'ushort) 2
             ('int || 'uint || 'float) 4
             ('llong || 'ullong || 'double) 8  ; 8-byte on every target (t32's word is 4)
             ('i128 || 'u128) 16
             w))
   ; a scalar aligns to its size, up to cap (16 on 64-bit, 8 under AAPCS32, 4 under SysV i386)
   (tyalign w cap stag ty)
    (? (ptr? ty) w
       (arr? ty) (tyalign w cap stag <>ty)
       (stru? ty) (two? (drop 2 ty) ? (ty 2) <>>(stag <>ty))   ; a third element: the alignment its address carries
       (bitf? ty) (tyalign w cap stag <>ty)
       (min (tysz w stag ty) cap))

   ; -- integer promotions (C11 6.3.1.1) and usual arithmetic conversions (6.3.1.8).
   ; w64: whether long is 8 bytes -- on ilp32 long meets uint at ulong, on LP64 at long.
   (parith? ty) (bitf? ty ? 1
                   (elem ty '(bool char schar cchar uchar short ushort int uint long ulong
                                 llong ullong i128 u128 float double)))
   (trank ty) (ty @ ('i128 || 'u128) 4 ('llong || 'ullong) 3 ('long || 'ulong) 2 1)
   (tusg? ty) (elem ty '(cchar uchar ushort uint ulong ullong u128))
   (tusg ty) (ty @ 'int 'uint 'long 'ulong 'llong 'ullong 'i128 'u128 ty)
   (tw w64 ty) (trank ty @ 1 4 2 (w64 ? 8 4) 3 8 16)
   (pprom ty) (? (bitf? ty) (pprom <>ty)              ; a bitfield promotes as its unit
                 (elem ty '(bool char schar cchar uchar short ushort)) 'int
                 ty)
   (puac w64 ta tb)
    (? (ta = 'double || tb = 'double) 'double
       (ta = 'float || tb = 'float) 'float
     (: a (pprom ta) b (pprom tb)
      (a = b ? a
       (: ua (tusg? a) ub (tusg? b)
        (ua && ub || !ua && !ub ? (trank a < trank b ? b a)   ; same signedness: higher rank
         (: u (ua ? a b) s (ua ? b a)     ; one of each: the unsigned one, the signed one
            (? (trank s <= trank u) u     ; unsigned rank >= signed: unsigned wins
               (tw w64 u < tw w64 s) s    ; signed strictly wider: it represents all of u
               (tusg s))))))))            ; same width: the signed one's unsigned twin
   (tdecay ty) (arr? ty ? ['ptr <>ty] ty))
) ; module 'moon
