; wasm -- the module writer: a WebAssembly binary off love data, the container half of the
; browser lane (doc/misc/plan/moon-wasm.md, rung 0). not a holo backend: a module has no
; addresses, so lay/resolve never see it. what is here is the leaf encoders (LEB128, names,
; vectors, sections), the opcode table with each op's immediate shape, and one whole-module
; emitter over a tablet. the law: the ALU is i64 and the memory is 64-bit (memory64), so an
; address is an i64 and a data segment's offset is an i64.const. an f64 constant arrives as
; its bit pattern (gen.l's fbits) -- no float encoding lives here.
;
; a module tablet:
;   'types   (((params) (results)) ..)          valtypes: i32 i64 f32 f64
;   'imports ((mod name desc) ..)               desc: (func typeidx) (memory min [max]) (table n) (global vt mut)
;   'funcs   ((typeidx ((n vt) ..) body) ..)    body: instruction forms, the writer ends it
;   'table   n                                  n funcref slots, filled by 'elem from 0
;   'memory  (min [max])                        pages, 64-bit
;   'globals ((vt mut init) ..)                 init: instruction forms
;   'exports ((name kind idx) ..)               kind: func table memory global
;   'elem    (funcidx ..)                       the table's contents from slot 0
;   'data    ((off byte ..) ..)                 active segments in memory 0
;   'start   funcidx
;   'mem64   1                                  0 asks the wasm32 shape (i32 offsets, i32.const data offsets)
; an instruction form is (op imm ..): (i64.const 5) (local.get 0) (block i64) (br_table (1 0) 2)
; (i64.load align offset) (call_indirect typeidx tableidx) (f64.const bits) -- the table below
; names each op's shape. functions, types, tables, memories and globals are indices, imports first.

(module 'holo
(: ;; -- LEB128. unsigned rides // and % so a u64 past the fixnum stays exact; signed stops
   ;;    when the rest is the sign's own extension and the byte's bit 6 agrees. --
   (uleb n) (: b (n % 128) r (n // 128) (? (r = 0) [b] (b + 128 . uleb r)))
   (sleb n) (: m (n % 128) b (? (m < 0) (m + 128) m) r ((n - b) // 128)
               (? ((r = 0 && b < 64) || (r = -1 && b >= 64)) [b] (b + 128 . sleb r)))
   (wrap64 n) (? (n > 9223372036854775807) (n - 18446744073709551616) n)   ; a u64 pattern as the signed i64 it encodes
   (wrap32 n) (? (n > 2147483647) (n - 4294967296) n)
   (wbytes s) (map s (jot (tally s)))                 ; a string's bytes
   (wname s) (uleb (tally s) + wbytes s)
   (wvec items) (uleb (tally items) + catall items)   ; items: a list of byte lists
   (wsect id bs) (id . uleb (tally bs) + bs)

   ;; -- the types --
   wasm-vt (tabof [('i32 >< 127) ('i64 >< 126) ('f32 >< 125) ('f64 >< 124) ('funcref >< 112)])
   (vt t) (look wasm-vt t 'bad-valtype)
   (blocktype x) (? (= x ()) [64] (= x 'void) [64] (nom? x) [(vt x)] (sleb x))   ; a valtype, or a type index
   wasm-kind (tabof [('func >< 0) ('table >< 1) ('memory >< 2) ('global >< 3)])
   (kind k) (look wasm-kind k 'bad-kind)

   ;; -- the opcode table: op -> (code shape). code is a byte or, past the 0xfc prefix, the bytes;
   ;;    the shape names the immediates: n none, u one index, bt a blocktype, brt (labels) default,
   ;;    mem align offset, i32c/i64c a signed constant, f32c/f64c a bit pattern, ci type table,
   ;;    m0 the memory index byte. --
   wasm-rows
    '((unreachable 0 n) (nop 1 n) (block 2 bt) (loop 3 bt) (if 4 bt) (else 5 n) (end 11 n)
     (br 12 u) (br_if 13 u) (br_table 14 brt) (return 15 n) (call 16 u) (call_indirect 17 ci)
     (return_call 18 u) (return_call_indirect 19 ci)
     (drop 26 n) (select 27 n)
     (local.get 32 u) (local.set 33 u) (local.tee 34 u) (global.get 35 u) (global.set 36 u)
     (i32.load 40 mem) (i64.load 41 mem) (f32.load 42 mem) (f64.load 43 mem)
     (i32.load8_s 44 mem) (i32.load8_u 45 mem) (i32.load16_s 46 mem) (i32.load16_u 47 mem)
     (i64.load8_s 48 mem) (i64.load8_u 49 mem) (i64.load16_s 50 mem) (i64.load16_u 51 mem)
     (i64.load32_s 52 mem) (i64.load32_u 53 mem)
     (i32.store 54 mem) (i64.store 55 mem) (f32.store 56 mem) (f64.store 57 mem)
     (i32.store8 58 mem) (i32.store16 59 mem) (i64.store8 60 mem) (i64.store16 61 mem) (i64.store32 62 mem)
     (memory.size 63 m0) (memory.grow 64 m0)
     (i32.const 65 i32c) (i64.const 66 i64c) (f32.const 67 f32c) (f64.const 68 f64c)
     (i32.eqz 69 n) (i32.eq 70 n) (i32.ne 71 n) (i32.lt_s 72 n) (i32.lt_u 73 n) (i32.gt_s 74 n)
     (i32.gt_u 75 n) (i32.le_s 76 n) (i32.le_u 77 n) (i32.ge_s 78 n) (i32.ge_u 79 n)
     (i64.eqz 80 n) (i64.eq 81 n) (i64.ne 82 n) (i64.lt_s 83 n) (i64.lt_u 84 n) (i64.gt_s 85 n)
     (i64.gt_u 86 n) (i64.le_s 87 n) (i64.le_u 88 n) (i64.ge_s 89 n) (i64.ge_u 90 n)
     (f32.eq 91 n) (f32.ne 92 n) (f32.lt 93 n) (f32.gt 94 n) (f32.le 95 n) (f32.ge 96 n)
     (f64.eq 97 n) (f64.ne 98 n) (f64.lt 99 n) (f64.gt 100 n) (f64.le 101 n) (f64.ge 102 n)
     (i32.clz 103 n) (i32.ctz 104 n) (i32.popcnt 105 n) (i32.add 106 n) (i32.sub 107 n) (i32.mul 108 n)
     (i32.div_s 109 n) (i32.div_u 110 n) (i32.rem_s 111 n) (i32.rem_u 112 n) (i32.and 113 n)
     (i32.or 114 n) (i32.xor 115 n) (i32.shl 116 n) (i32.shr_s 117 n) (i32.shr_u 118 n)
     (i32.rotl 119 n) (i32.rotr 120 n)
     (i64.clz 121 n) (i64.ctz 122 n) (i64.popcnt 123 n) (i64.add 124 n) (i64.sub 125 n) (i64.mul 126 n)
     (i64.div_s 127 n) (i64.div_u 128 n) (i64.rem_s 129 n) (i64.rem_u 130 n) (i64.and 131 n)
     (i64.or 132 n) (i64.xor 133 n) (i64.shl 134 n) (i64.shr_s 135 n) (i64.shr_u 136 n)
     (i64.rotl 137 n) (i64.rotr 138 n)
     (f32.abs 139 n) (f32.neg 140 n) (f32.ceil 141 n) (f32.floor 142 n) (f32.trunc 143 n)
     (f32.nearest 144 n) (f32.sqrt 145 n) (f32.add 146 n) (f32.sub 147 n) (f32.mul 148 n)
     (f32.div 149 n) (f32.min 150 n) (f32.max 151 n) (f32.copysign 152 n)
     (f64.abs 153 n) (f64.neg 154 n) (f64.ceil 155 n) (f64.floor 156 n) (f64.trunc 157 n)
     (f64.nearest 158 n) (f64.sqrt 159 n) (f64.add 160 n) (f64.sub 161 n) (f64.mul 162 n)
     (f64.div 163 n) (f64.min 164 n) (f64.max 165 n) (f64.copysign 166 n)
     (i32.wrap_i64 167 n) (i32.trunc_f32_s 168 n) (i32.trunc_f32_u 169 n)
     (i32.trunc_f64_s 170 n) (i32.trunc_f64_u 171 n)
     (i64.extend_i32_s 172 n) (i64.extend_i32_u 173 n) (i64.trunc_f32_s 174 n) (i64.trunc_f32_u 175 n)
     (i64.trunc_f64_s 176 n) (i64.trunc_f64_u 177 n)
     (f32.convert_i32_s 178 n) (f32.convert_i32_u 179 n) (f32.convert_i64_s 180 n) (f32.convert_i64_u 181 n)
     (f32.demote_f64 182 n)
     (f64.convert_i32_s 183 n) (f64.convert_i32_u 184 n) (f64.convert_i64_s 185 n) (f64.convert_i64_u 186 n)
     (f64.promote_f32 187 n)
     (i32.reinterpret_f32 188 n) (i64.reinterpret_f64 189 n) (f32.reinterpret_i32 190 n) (f64.reinterpret_i64 191 n)
     (i32.extend8_s 192 n) (i32.extend16_s 193 n) (i64.extend8_s 194 n) (i64.extend16_s 195 n) (i64.extend32_s 196 n)
     ;; the 0xfc prefix: the saturating truncations, and bulk memory over memory 0
     (i32.trunc_sat_f32_s (252 0) n) (i32.trunc_sat_f32_u (252 1) n)
     (i32.trunc_sat_f64_s (252 2) n) (i32.trunc_sat_f64_u (252 3) n)
     (i64.trunc_sat_f32_s (252 4) n) (i64.trunc_sat_f32_u (252 5) n)
     (i64.trunc_sat_f64_s (252 6) n) (i64.trunc_sat_f64_u (252 7) n)
     (memory.copy (252 10 0 0) n) (memory.fill (252 11 0) n))
   wasm-ops (: t (tablet 0) _ (foldl (\ _ r (pin t <r >r)) 0 wasm-rows) t)

   ;; -- one instruction form -> its bytes --
   (wins f)
    (: r (peep wasm-ops <f ())
       _ (? !(two? r) (scare 'bad-wasm-op <f) 0)
       code (? (two? <r) <r [<r])
       ((r 1) @
        'n    code
        'u    (code + uleb (f 1))
        'bt   (code + blocktype (? (two? >f) (f 1) 'void))
        'brt  (code + wvec (map uleb (f 1)) + uleb (f 2))
        'mem  (code + uleb (f 1) + uleb (f 2))
        'i32c (code + sleb (wrap32 (f 1)))
        'i64c (code + sleb (wrap64 (f 1)))
        'f32c (code + le32 (f 1))
        'f64c (code + le64 (f 1))
        'ci   (code + uleb (f 1) + uleb (f 2))
        'm0   (code + [0])
              (scare 'bad-wasm-shape <f)))
   (wexpr body) (catmap wins body + [11])           ; a body or an init expression, ended

   ;; -- the module --
   (wlimits l is64) ((? (two? >l) 1 0) + (? is64 4 0) . uleb <l + (? (two? >l) (uleb (l 1)) ()))
   (wfunctype t) (96 . wvec (map (\ x [(vt x)]) <t) + wvec (map (\ x [(vt x)]) (t 1)))
   (wdesc d is64)
    (<d @ 'func   (0 . uleb (d 1))
         'table  (1 112 . wlimits [(d 1) (d 1)] 0)
         'memory (2 . wlimits >d is64)
         'global [3 (vt (d 1)) (d 2)]
                 (scare 'bad-import-desc <d))
   (wimport i is64) (wname <i + wname (i 1) + wdesc (i 2) is64)
   (wglobal g) ([(vt <g) (g 1)] + wexpr (g 2))
   (wexport e) (wname <e + [(kind (e 1))] + uleb (e 2))
   (wcode f) (: e (wvec (map (\ l (uleb <l + [(vt (l 1))])) (f 1)) + wexpr (f 2))
                (uleb (tally e) + e))
   (wdata d is64) (: bs (? (string? >d) (wbytes >d) >d)          ; (off byte ..), or (off . string)
                     (0 . wexpr [[(? is64 'i64.const 'i32.const) <d]] + uleb (tally bs) + bs))
   ;; presence is two?, never nil?: nil? is the falsy test, a net over the whole value, and a
   ;; body carrying the minimum i64 nets negative -- a section would vanish in silence
   (wsection id items f) (? !(two? items) () (wsect id (wvec (map f items))))
   (wasm-emit m)
    (: is64 (peep m 'mem64 1)
       mem (peep m 'memory ())  tab (peep m 'table ())  start (peep m 'start -1)
       elem (peep m 'elem ())
       ([0 97 115 109 1 0 0 0]
        + wsection 1 (peep m 'types ()) wfunctype
        + wsection 2 (peep m 'imports ()) (\ i (wimport i is64))
        + wsection 3 (peep m 'funcs ()) (\ f (uleb <f))
        + (? (= tab ()) () (wsect 4 (wvec [(112 . wlimits [tab tab] 0)])))
        + (? !(two? mem) () (wsect 5 (wvec [(wlimits mem is64)])))
        + wsection 6 (peep m 'globals ()) wglobal
        + wsection 7 (peep m 'exports ()) wexport
        + (? (start < 0) () (wsect 8 (uleb start)))
        + (? !(two? elem) () (wsect 9 (wvec [(0 . wexpr '((i32.const 0)) + wvec (map uleb elem))])))
        + wsection 10 (peep m 'funcs ()) wcode
        + wsection 11 (peep m 'data ()) (\ d (wdata d is64))
        + (: ns (peep m 'names ())                   ; the "name" custom section: a trap's stack names its function
             (? !(two? ns) ()
                (: fm (wvec (map (\ n (uleb <n + wname (n 1))) ns))
                   (wsect 0 (wname "name" + (1 . uleb (tally fm) + fm))))))))
   (wasm-hex m) (hexs (wasm-emit m))
   (wins-hex body) (hexs (catmap wins body))
   (wasm-write path m) (: q (open path "w") _ (say q (cask (wasm-emit m))) (close q))
)
) ; module 'holo
