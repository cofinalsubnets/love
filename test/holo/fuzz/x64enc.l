; the x86-64 table encoder's caches against itself: each name over random operands laid by the
; cache twice (a miss, then a hit) and by x64-enc's search; call, jmp and the jccs at numeric
; targets round the rel8 and rel32 edges, held to the reach and read back by the decoder; and
; the lowering's random IR laid in one order and the reverse, each on a fresh load, which must
; agree: an emitter's key that names the wrong shape hands one shape another's bytes.
; X64ENC_PART is one of order, targets, cached, keyed: each its own process, since a caught
; scare keeps some stack and these catch one per refused lay
;   cat src/love/holo/holo.l src/love/holo/x64.l src/love/holo/dialect.l src/love/holo/decode.l \
;     test/holo/fuzz/x64enc.l | X64ENC_PART=order out/love

(borrow 'holo)

(: st {'s 20251119}
   (rnd n) (: s ((st 's * 1103515245 + 12345) % 2147483648) _ (pin st 's s) (s // 65536 % n))
   (pick l) (l (rnd #l))
   tally {}
   (count k) (pin tally k (peep tally k 0 + 1))
   (miss why x) (count 'miss, peep tally 'miss 0 <= 8 ? (puts ("  " + why + " " + show x + "\n")) 0)
   (try f) (trap f 'refused (a \ b \ 'refused))
   (dedup l) (foldl (\ a x (elem x a ? a (a + [x]))) () l)

   ;; ---- operands ----
   ws [0 1 2 4 8]
   ds [0 1 -1 127 128 -128 -129 4096 2147483647 -2147483648 2147483648]
   vs [0 1 -1 2 3 15 16 127 128 -128 -129 255 256 65535 65536 -32768 -32769 2147483647 -2147483648
       2147483648 4294967295 4294967296 -4294967296]
   (rg w) ['rg (rnd 16) (w > 0 && rnd 2 ? w (pick [1 2 4 8]))]
   (mem _) ['mem (pick [-1 0 3 4 5 12 13]) (pick [-1 -1 0 4 9]) (pick [1 1 2 4 8]) (pick ds)]
   ; an operand's kind, then a value of it: the kind and the width fixed, the rest drawn
   (kind w) [(rnd 14) (w > 0 && rnd 2 ? w (pick [1 2 4 8])) (rnd 3)]
   (opnd k)
    (k @ [(0 || 1 || 2 || 3) w _] ['rg (rnd 16) w]
         [4 _ _] ['rg (16 + rnd 4) 1]
         [5 _ _] ['rg (rnd 16) 16]
         [(6 || 7) _ _] (mem 0)
         [8 _ _] ['rip () (pick [(fix 4 'rel32 'foo 0) 16 -16])]
         [9 _ _] ['im (pick vs)]
         [10 _ z] ['im (pick vs) ([1 2 4] z)]
         [11 _ _] ['lbl (pick [(fix 4 'rel32 'foo 0) (fix 1 'rel8 'foo 0) 100 -100 2147483647])]
         [12 _ z] ['ind (z = 0 ? ['rg (rnd 16) 8] (mem 0))]
         ['seg (pick '(es cs ss ds fs gs)) (mem 0)])

   ; ..or a row's own: an operand of each of its roles at its width, memory or register by z
   (wid l w) (l @ 'b 1 'w 2 'd 4 'q 8 (w > 0 ? w 8))
   (role r l w z)
    (r @ ('G || 'Z) ['rg (rnd 16) (wid l w)]
         'A ['rg 0 (wid l w)]
         'CL ['rg 1 1]
         'E (z ? (mem 0) ['rg (rnd 16) (wid l w)])
         'V ['rg (rnd 16) 16]
         'W (z ? (mem 0) ['rg (rnd 16) 16])
         'N ['ind (z ? (mem 0) ['rg (rnd 16) 8])]
         ('I || 'U || 'ub) ['im (pick vs)]
         'J ['lbl (pick [(fix 4 'rel32 'foo 0) (fix 1 'rel8 'foo 0) 100 -100 2147483647])]
         'S ['sr (rnd 6)] 'C ['cr (pick [0 2 3 4 8])] 'D ['dr (rnd 8)]
         (opnd (kind w)))
   (template ps w)
    (? (rnd 2) (: n (pick (dedup (map (p \ p 1) ps))) ks (map (_ \ kind w) ^n) (_ \ map opnd ks))
       (: p (pick ps) zs (map (_ \ rnd 2) ^(p 1)) (_ \ map (i \ role (p 2 i) (p 3 i) w (zs i)) ^(p 1))))

   ;; ---- the cache against the search ----
   lay (cite 'holo 'x6e-lay)
   (first-fit ps w ops) (? !(two? ps) () (lay <ps w ops 0 @ b (two? b ? b (first-fit >ps w ops))))
   (cached mn)
    (: ps (peep x64-byname mn ())
       (each ^16 (_ \
        (: w (pick ws) t (template ps w)
           (each ^4 (_ \
            (: ops (t 0)
               a (try (_ \ x6 mn w ops)) b (try (_ \ x6 mn w ops)) c (try (_ \ x64-enc mn w ops 0))
               (count 'laid, a != 'refused && count 'fit,
                (a = c && b = c) ? 0 (miss "cache" [mn w ops a b c])))))))))
   ; x6k: the first fitting row of one opcode
   (keyed mn)
    (: ps (peep x64-byname mn ()) ks (dedup (map (p \ p 0 1 * 256 + p 0 2) ps))
       (each ks (k \ (: kp (filter (p \ p 0 1 * 256 + p 0 2 = k) ps)
        (each ^4 (_ \
         (: w (pick ws) t (template kp w)
            (each ^4 (_ \
             (: ops (t 0)
                a (try (_ \ x6k k mn w ops)) b (try (_ \ x6k k mn w ops)) c (first-fit kp w ops @ () 'refused e e)
                (count 'laid, (a = c && b = c) ? 0 (miss "keyed" [mn k w ops a b c]))))))))))))

   ;; ---- numeric targets ----
   tv [-2147483659 -2147483648 -2147483643 -129 -128 -127 -2 0 1 2 125 126 127 128 129 130 131 132
       133 134 2147483647 2147483652 2147483653 4294967296]
   (jl mn) (? (mn = 'call) 5 (mn = 'jmp) 5 6)
   (target mn)
    (each [0 5 2147483640] (pc \ each tv (v \
     (: e (try (_ \ x64-enc mn 0 [['lbl v]] pc))
        r8 (mn != 'call && fits8 (v - pc - 2)) r32 (fits32 (v - pc - jl mn))
        (count 'target,
         (? (e = 'refused) (r8 || r32 ? (miss "refused" [mn v pc]) 0)
            (r8 && #e != 2) (miss "not rel8" [mn v pc e])
            (x64-decode e 0 @ (k . items) ((k = #e && items = [['op mn 0 [['lbl (v - pc)]]]]) ? 0 (miss "decode" [mn v pc e items]))
             (miss "decode" [mn v pc e]))))))))

   ;; ---- the emitters' keys, by order ----
   ; a shape's cell pinned () is a miss, so the shapes are staged again
   (clear t) (each (keys t) (k \ pin t k ()))
   (reset _) (each (keys x6-rows) (mn \ clear (x6-rows mn)),
              each (keys x6-krows) (k \ each (keys (x6-krows k)) (mn \ clear (x6-krows k mn))))
   regs '(sp r0 r1 r2 r3 r4 r5 r6 r7 r8 r9 r10 r11 r12 r13 r14)
   ints [0 1 -1 2 7 8 15 16 31 63 64 127 128 -128 -129 255 256 4095 65535 65536 2147483647 -2147483648
         2147483648 4294967295 4294967296 -8 -4096]
   misc ['foo '(foo 3) 'eq 'ne 'lt 'ge 'le 'gt 'below 'ae 'be 'above 'add 'or 'and 'sub 'xor 'cmp
         'shl 'shr 'sar 'inc 'dec 'not 'neg 'rip]
   pool (regs + regs + regs + ints + misc)
   irs (catmap (op \ (: n (ir-arity op) (map (_ \ op . map (_ \ pick pool) ^n) ^(n = 0 ? 1 100))))
               (sort (keys ir-arity)))
   (lower-all l) (: L (backends 'x64 'lower) (map (i \ show (trap (_ \ L i) 'refused (a \ b \ ['refused a]))) l))
   (ordered _)
    (: _ (reset 0) fw (lower-all irs) _ (reset 0) bw (rev (lower-all (rev irs)))
       (each ^#irs (i \ (count 'ir, fw i = bw i ? 0 (miss "order" [(irs i) (fw i) (bw i)])))))

   part (getenv "X64ENC_PART")
   names (sort (keys x64-byname))
   _ (? (part = "order") (ordered 0)
        (part = "targets") (each (filter (n \ n = 'call || n = 'jmp || elem n (map (c \ name ("j" + show c)) x6t-cc)) names) target)
        (part = "cached") (each names cached)
        (part = "keyed") (each names keyed)
        (scare 'x64enc-part part))
   (puts ("test/holo/fuzz/x64enc " + part + ": "
          + (? (part = "order") (show (peep tally 'ir 0) + " IR forms both ways")
               (part = "targets") (show (peep tally 'target 0) + " targets")
               (show (peep tally 'laid 0) + " lays" + (part = "cached" ? " (" + show (peep tally 'fit 0) + " fit)" "")))
          + ", " + show (peep tally 'miss 0) + " missed\n"),
    flush out,
    (peep tally 'miss 0 = 0 ? 0 (quit 1))))
