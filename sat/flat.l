; sat/flat -- the CDCL solver over FLAT state, with THREE DOMAIN-SPECIFIC NATIVE
; KERNELS: at solver-build time the hot loops are assembled through asm/ (neutral IR,
; section offsets baked as immediates -- each kernel is SPECIALIZED to the instance's
; nvars, cached per nv) and installed via the `nif` seam:
;   bcp  (fx ar wn)        two-watched-literal propagation      -> conflict cid | -1
;   conf (fx ar wn confl)  the WHOLE conflict: 1-UIP absorb (+ inline VSIDS bumps),
;                          self-subsumption minimization (in-place compaction), glue,
;                          backjump, learnt-clause commit + watches, asserting assign
;                                                              -> (cid<<6)|glue | -1 at level 0
;   dec  (fx)              highest-activity free var, phase-saved polarity, assign
;                                                              -> the var | 0 = SAT
; the interpreted twins (fbcp3/fconf3/fdec3) over the SAME memory are the deopt
; fallbacks, the arm64/no-`nif` engine (the glazed image mops nif; make exports
; AI_NO_IMAGE=1 so every gate run has it), and the differential oracle: the `fknob`
; box forces the twins and `fboth` gates verdict equality. lisp keeps only the cold
; path: restarts, learnt-DB reduction, activity decay/rescale.
; Run AFTER sat.l (it reuses the leaked oracle + instances):
;   cat sat/sat.l sat/flat.l | ai
; the story, the kernel contract, and the measured results: doc/sat-kernels.md.
;
; a literal is ENCODED: +v -> 2v, -v -> 2v+1 (neg = xor 1, var = >>1). val[v] holds
; the TRUE encoded literal itself (0 = free) so lit-val is a load + a compare. VSIDS
; activities are INTEGERS (vinc starts 256, grows *21//20 per conflict; when it tops
; 2^24 every activity shifts right 8 -- decay-by-shift, ratios kept, ancient bumps
; fade to 0, which is the point). words are 8-byte slots whose LOW 4 bytes carry the
; value (getw/putw touch only those; the high bytes stay zero from the zeroed cask,
; so the kernels' 64-bit ld/st and the byte accessors agree exactly).
; fx layout (word offsets; nv = nvars):
;   w0 top  w1 qhead  w2 level  w3 nv  w4 aru  w5 wnu  w6 vinc  w7 kernel scratch
;   TRO=8 trail | LVO lvl | RSO rsn (0 none, else cid+1) | WHO watch heads (2nv+2,
;   by encoded lit) | VAO val | ACO activity | PHO saved phase (0 never, 1 pos, 2 neg)
;   | SEO seen scratch (conf clears it on entry; also reused as a level-mark set)
; a clause at arena offset cid is [size, lit0..], watches ALWAYS slots cid+1/cid+2;
; a watch node at offset p is [cid, next] (0 = nil; words 0-1 of both arenas reserved).
; the conf caller pre-ensures arena room (aru+nv+3 words) and node room (wnu+4): the
; kernels never grow a cask.
(:
   ; --- 8-byte word slots, low 4 bytes live ---------------------------------------
   (getw c i) (: b (* 8 i) (| (peep c b 0)
                              (| (<< (peep c (+ b 1) 0) 8)
                                 (| (<< (peep c (+ b 2) 0) 16) (<< (peep c (+ b 3) 0) 24)))))
   (putw c i v) (: b (* 8 i)
                   _ (pin c b (& v 255)) _ (pin c (+ b 1) (& (>> v 8) 255))
                   _ (pin c (+ b 2) (& (>> v 16) 255)) (pin c (+ b 3) (& (>> v 24) 255)))
   (enc l) (? (< l 0) (+ 1 (* 2 (- 0 l))) (* 2 l))          ; signed literal -> encoded
   ; --- the layout, from nv (twins recompute these from fx w3) --------------------
   (lvo-of nv) (+ 8 (+ nv 1))
   (rso-of nv) (+ (lvo-of nv) (+ nv 1))
   (who-of nv) (+ (rso-of nv) (+ nv 1))
   (vao-of nv) (+ (who-of nv) (+ 2 (* 2 nv)))
   (aco-of nv) (+ (vao-of nv) (+ nv 1))
   (pho-of nv) (+ (aco-of nv) (+ nv 1))
   (seo-of nv) (+ (pho-of nv) (+ nv 1))
   ; --- the twin assign, self-contained (offsets from fx w3) ----------------------
   (fasg fx el rv)                                          ; set el TRUE at the current level, reason rv (0 = decision)
    (: nv (getw fx 3) v (>> el 1) t (getw fx 0)
       _ (putw fx (+ (vao-of nv) v) el)
       _ (putw fx (+ (lvo-of nv) v) (getw fx 2))
       _ (putw fx (+ (rso-of nv) v) rv)
       _ (putw fx (+ 8 t) el)
       (putw fx 0 (+ t 1)))
   ; --- state access for the lisp driver (offsets cached in s) --------------------
   (flv s el) (: m (getw (peep s 'fx ()) (+ (peep s 'vao 0) (>> el 1)))
                 (? (= m 0) 0 (= m el) 1 -1))               ; 1 sat / -1 false / 0 free
   (flvl s el) (getw (peep s 'fx ()) (+ (peep s 'lvo 0) (>> el 1)))
   (fens s k need)                                          ; ensure cask s[k] holds >= need bytes (grow by doubling)
    (: c (peep s k ())
       (? (<= need (tally c)) 0
          (: n2 ((: (go m) (? (>= m need) m (go (* 2 m)))) (* 2 (tally c)))
             nu (cask n2) _ (pour nu 0 c 0 (tally c)) _ (pin s k nu) 0)))
   (fassign s el rv) (fasg (peep s 'fx ()) el rv)
   ; --- clause DB (lisp side: initial load + reduction; aru/wnu live in fx) --------
   (fadd s lits)                                            ; append [size, lits..] to the arena; -> cid (word offset)
    (: n (tally lits) fx (peep s 'fx ()) aru (getw fx 4)
       _ (fens s 'ar (* 8 (+ aru (+ n 1))))
       ar (peep s 'ar ())
       _ (putw ar aru n)
       _ (foldl (\ j el (: _ (putw ar j el) (+ j 1))) (+ aru 1) lits)
       _ (putw fx 4 (+ aru (+ n 1))) aru)
   (fclits s cid)                                           ; the clause's encoded literals, as a list
    (: ar (peep s 'ar ()) n (getw ar cid)
       ((: (go j acc) (? (< j (+ cid 1)) acc (go (- j 1) (link (getw ar j) acc)))) (+ cid n) ()))
   (fwatch s cid el)                                        ; push a watch node [cid -> wh[el] list]
    (: fx (peep s 'fx ()) wnu (getw fx 5) _ (fens s 'wn (* 8 (+ wnu 2)))
       wn (peep s 'wn ()) who (peep s 'who 0)
       _ (putw wn wnu cid) _ (putw wn (+ wnu 1) (getw fx (+ who el)))
       _ (putw fx (+ who el) wnu) (putw fx 5 (+ wnu 2)))
   (fenq s el rv)                                           ; level-0 fact: assign if free, flag bad if already false
    (: m (flv s el) (? (= m 1) 0 (= m -1) (pin s 'bad 1) (: _ (fassign s el rv) 0)))
   (fload s c0)                                             ; a source clause (signed lits) into the DB + watches
    (? (= 1 (taut? c0)) 0
       (: c (dedup-lits c0)
          (? (atom? c) (pin s 'bad 1)
             (atom? (cup c)) (: cid (fadd s (link (enc (cap c)) ())) (fenq s (enc (cap c)) (+ cid 1)))
             (: cid (fadd s (map enc c))
                _ (fwatch s cid (enc (cap c))) (fwatch s cid (enc (caup c)))))))
   ; --- the interpreted BCP twin: (fbcp3 fx ar wn) -> conflict cid or -1 ----------
   (fbcp3 fx ar wn)
    (: nv (getw fx 3) who (who-of nv) vao (vao-of nv)
       lv (\ el (: m (getw fx (+ vao (>> el 1))) (? (= m 0) 0 (= m el) 1 -1)))
       prop1 (\ f                                           ; f just became FALSE: re-examine wh[f]
        ((: (go p prev)
            (? (= p 0) -1
               (: cid (getw wn p)
                  (? (= 0 (getw ar cid))                                 ; TOMBSTONE (freduce): unlink, walk on
                     (: nx (getw wn (+ p 1))
                        _ (? (= prev 0) (putw fx (+ who f) nx) (putw wn (+ prev 1) nx))
                        (go nx prev))
                  (: _ (? (= (getw ar (+ cid 1)) f)                      ; normalize: f sits at slot cid+2
                       (: t (getw ar (+ cid 2)) _ (putw ar (+ cid 2) f) (putw ar (+ cid 1) t)) 0)
                  oth (getw ar (+ cid 1))
                  (? (= 1 (lv oth)) (go (getw wn (+ p 1)) p)             ; satisfied by the other watch: keep
                     (: k ((: (sc j)                                     ; scan the tail for a non-false literal
                              (? (>= j (+ cid (+ 1 (getw ar cid)))) 0
                                 (: e (getw ar j) (? (! (= -1 (lv e))) j (sc (+ j 1))))))
                           (+ cid 3))
                        (? (! (= k 0))                                   ; slide the watch f -> ar[k]
                           (: e (getw ar k) nx (getw wn (+ p 1))
                              _ (putw ar k f) _ (putw ar (+ cid 2) e)
                              _ (? (= prev 0) (putw fx (+ who f) nx) (putw wn (+ prev 1) nx))
                              _ (putw wn (+ p 1) (getw fx (+ who e))) _ (putw fx (+ who e) p)
                              (go nx prev))
                           (= 0 (lv oth)) (: _ (fasg fx oth (+ cid 1)) (go (getw wn (+ p 1)) p))   ; unit: force oth
                           cid))))))))                                   ; oth false too: CONFLICT
         (getw fx (+ who f)) 0))
       ((: (drain _)
           (? (>= (getw fx 1) (getw fx 0)) -1
              (: p (getw fx (+ 8 (getw fx 1))) _ (putw fx 1 (+ 1 (getw fx 1)))
                 confl (prop1 (^ p 1))
                 (? (> confl -1) confl (drain ()))))) ()))
   ; --- the interpreted CONFLICT twin: (fconf3 fx ar wn confl) --------------------
   ; the whole conflict handler, phase for phase what the conf kernel does:
   ;   0 level 0 -> -1        1 clear seen           2 1-UIP (absorb + trail walk),
   ;   asserting lit to ar[cid0+1], tail collected at ar[cid0+2..]
   ;   3 minimize (self-subsumption; dropped lits STAY seen), compact in place
   ;   3b reason-side bump: unseen vars in the learnt lits' reasons get act += vinc
   ;   4 clear seen; glue (level-mark set) + backjump level in one pass
   ;   5 backjump (save phase, unassign)   6 commit size/aru, reorder watch-2, watches
   ;   7 assert learnt[0] with reason cid0+1   -> (cid0<<6)|min(glue,63)
   (fconf3 fx ar wn confl)
    (: nv (getw fx 3) lvo (lvo-of nv) rso (rso-of nv) who (who-of nv)
       vao (vao-of nv) aco (aco-of nv) pho (pho-of nv) seo (seo-of nv)
       dl (getw fx 2)
       (? (= dl 0) -1
        (: cid0 (getw fx 4)
           czero (\ _ ((: (go v) (? (> v nv) 0 (: _ (putw fx (+ seo v) 0) (go (+ v 1))))) 0))
           _ (czero ())
           abs1 (\ cs skipv counter widx                    ; absorb clause at cs -> (counter . widx)
            ((: (go j c w)
                (? (> j (+ cs (getw ar cs))) (link c w)
                   (: el (getw ar j) v (>> el 1)
                      (? (= v skipv) (go (+ j 1) c w)
                         (! (= 0 (getw fx (+ seo v)))) (go (+ j 1) c w)
                         (= 0 (getw fx (+ lvo v))) (go (+ j 1) c w)
                         (: _ (putw fx (+ seo v) 1)
                            _ (putw fx (+ aco v) (+ (getw fx (+ aco v)) (getw fx 6)))   ; bump
                            (? (= (getw fx (+ lvo v)) dl) (go (+ j 1) (+ c 1) w)
                               (: _ (putw ar w el) (go (+ j 1) c (+ w 1)))))))))
             (+ cs 1) counter widx))
           a0 (abs1 confl 0 0 (+ cid0 2))
           r ((: (walk counter widx t)
                 (: np ((: (fs i) (? (= 0 (getw fx (+ seo (>> (getw fx (+ 8 i)) 1)))) (fs (- i 1)) i)) t)
                    el (getw fx (+ 8 np)) v (>> el 1)
                    _ (putw fx (+ seo v) 0) c (- counter 1)
                    (? (= c 0) (link el widx)
                       (: a (abs1 (- (getw fx (+ rso v)) 1) v c widx)
                          (walk (cap a) (cup a) (- np 1))))))
              (cap a0) (cup a0) (- (getw fx 0) 1))
           uip (cap r) wend (cup r)
           _ (putw ar (+ cid0 1) (^ uip 1))
           wr ((: (mn rd wr)                                ; minimize, compacting kept lits down
                  (? (>= rd wend) wr
                     (: el (getw ar rd) v (>> el 1) rv (getw fx (+ rso v))
                        red (? (= rv 0) 0
                               ((: (ck j) (? (> j (+ (- rv 1) (getw ar (- rv 1)))) 1
                                             (: v2 (>> (getw ar j) 1)
                                                (? (= v2 v) (ck (+ j 1))
                                                   (= 0 (getw fx (+ lvo v2))) (ck (+ j 1))
                                                   (! (= 0 (getw fx (+ seo v2)))) (ck (+ j 1))
                                                   0)))) (+ rv 0)))     ; j starts at (rv-1)+1 = rv
                        (? (= red 1) (mn (+ rd 1) wr)
                           (: _ (putw ar wr el) (mn (+ rd 1) (+ wr 1)))))))
               (+ cid0 2) (+ cid0 2))
           ; reason-side bump (cadical's bumpreason): every UNSEEN var in a learnt
           ; literal's reason gets an activity bump -- focuses VSIDS one step past the
           ; learnt, the decisive lever on factored/tree instances (php8 ~4000 -> ~1500
           ; conflicts). seen still holds the analysis marks here (czero follows).
           _ ((: (rb j) (? (>= j wr) 0
                  (: v (>> (getw ar j) 1) rv (getw fx (+ rso v))
                     _ (? (= rv 0) 0
                          ((: (go2 k) (? (> k (+ (- rv 1) (getw ar (- rv 1)))) 0
                               (: v2 (>> (getw ar k) 1)
                                  _ (? (= 0 (getw fx (+ seo v2)))
                                       (putw fx (+ aco v2) (+ (getw fx (+ aco v2)) (getw fx 6))) 0)
                                  (go2 (+ k 1))))) rv))
                     (rb (+ j 1))))) (+ cid0 1))
           _ (czero ())
           gb ((: (go j glue bj)                            ; glue + backjump level over the kept tail
                  (? (>= j wr) (link glue bj)
                     (: L (getw fx (+ lvo (>> (getw ar j) 1)))
                        bj2 (? (> L bj) L bj)
                        (? (= 0 (getw fx (+ seo L)))
                           (: _ (putw fx (+ seo L) 1) (go (+ j 1) (+ glue 1) bj2))
                           (go (+ j 1) glue bj2)))))
               (+ cid0 2) (: _ (putw fx (+ seo dl) 1) 1) 0)
           glue (cap gb) bj (cup gb)
           nt ((: (go t)                                    ; backjump: pop above bj, save phase
                  (? (= t 0) 0
                     (: el (getw fx (+ 8 (- t 1))) v (>> el 1)
                        (? (> (getw fx (+ lvo v)) bj)
                           (: _ (putw fx (+ pho v) (+ 1 (& el 1)))
                              _ (putw fx (+ vao v) 0) _ (putw fx (+ lvo v) 0) _ (putw fx (+ rso v) 0)
                              (go (- t 1)))
                           t))))
               (getw fx 0))
           _ (putw fx 0 nt) _ (putw fx 1 nt) _ (putw fx 2 bj)
           size (- wr (+ cid0 1))
           _ (putw ar cid0 size) _ (putw fx 4 wr)
           _ (? (< size 2) 0
                (: mx ((: (go j b) (? (>= j wr) b                       ; reorder: max-level tail lit to slot 2
                              (go (+ j 1) (? (> (getw fx (+ lvo (>> (getw ar j) 1)))
                                               (getw fx (+ lvo (>> (getw ar b) 1)))) j b))))
                       (+ cid0 3) (+ cid0 2))
                   a (getw ar (+ cid0 2)) b (getw ar mx)
                   _ (putw ar (+ cid0 2) b) _ (putw ar mx a)
                   l0 (getw ar (+ cid0 1)) l1 (getw ar (+ cid0 2)) wnu (getw fx 5)
                   _ (putw wn wnu cid0) _ (putw wn (+ wnu 1) (getw fx (+ who l0))) _ (putw fx (+ who l0) wnu)
                   _ (putw wn (+ wnu 2) cid0) _ (putw wn (+ wnu 3) (getw fx (+ who l1))) _ (putw fx (+ who l1) (+ wnu 2))
                   (putw fx 5 (+ wnu 4))))
           _ (fasg fx (getw ar (+ cid0 1)) (+ cid0 1))
           (| (<< cid0 6) (? (> glue 63) 63 glue)))))
   ; --- the interpreted DECIDE twin: (fdec3 fx) -> the decided var, 0 = SAT -------
   (fdec3 fx)
    (: nv (getw fx 3) vao (vao-of nv) aco (aco-of nv) pho (pho-of nv)
       v ((: (go v best ba)
             (? (> v nv) best
                (: a (getw fx (+ aco v))
                   (? (&& (= 0 (getw fx (+ vao v))) (|| (= best 0) (> a ba)))
                      (go (+ v 1) v a) (go (+ v 1) best ba)))))
          1 0 -1)
       (? (= v 0) 0
          (: ph (getw fx (+ pho v))
             _ (putw fx 2 (+ 1 (getw fx 2)))
             _ (fasg fx (? (= ph 1) (* 2 v) (+ 1 (* 2 v))) 0) v)))
   ; ===============================================================================
   ; the NATIVE kernels. lvm ABI: g=rdi(r6) Ip=rsi(r5) Hp=rdx(r2) Sp=rcx(r1); params
   ; TAGGED on Sp[i]. cask guard (deopts BEFORE any push -> machine sp balanced on
   ; every path): fixnum test + ap word vs (apof (cask 1)); byte base = [[v+8]+16].
   ; epilogue: tag acc, st Sp[0], Ip+16 -> lvm_ret. deopt (arity>=2): Ip <- interp
   ; body (args still on Sp). callee-saved r3/r11-r14 pushed after the guards.
   ; ===============================================================================
   (guard-ir i bufk)                                        ; Sp[i] must be a cask
    (L (L 'ld 'r0 'r1 (* 8 i)) '(test r0 1) '(br ne deopt)
       '(ld r7 r0 0) (L 'li 'r8 bufk) '(cmp r7 r8) '(br ne deopt))
   (fixg-ir i)                                              ; Sp[i] must be a fixnum
    (L (L 'ld 'r0 'r1 (* 8 i)) '(test r0 1) '(br eq deopt))
   epi-ir '((shl r0 1) (or r0 r0 1) (st r1 0 r0) (add r5 r5 16) (ld r7 r5 0) (jmpr r7))
   deopt2-ir '((label deopt) (ld r7 r5 8) (lea r5 r7 16) (ld r7 r5 0) (jmpr r7))   ; arity>=2
   deopt1-ir '((label deopt) (ld r7 r5 8) (mov r5 r7) (ld r7 r5 0) (jmpr r7))      ; arity 1
   ; --- kernel 1: BCP -- (bcp fx ar wn). registers: r11=fx r12=ar r13=wn r14=f
   ; (callee-saved) r3=cid, r9=p r10=prev r0/r7/r8 scratch. ---------------------------
   (fbcp-ir nv)
    (: tro8 64 who8 (* 8 (who-of nv)) vao8 (* 8 (vao-of nv))
       lvo8 (* 8 (lvo-of nv)) rso8 (* 8 (rso-of nv)) bufk (apof (cask 1))
       (cat (guard-ir 0 bufk) (cat (guard-ir 1 bufk) (cat (guard-ir 2 bufk)
       (cat '((push r3) (push r11) (push r12) (push r13) (push r14)
              (ld r0 r1 0)  (ld r0 r0 8) (lea r11 r0 16)
              (ld r0 r1 8)  (ld r0 r0 8) (lea r12 r0 16)
              (ld r0 r1 16) (ld r0 r0 8) (lea r13 r0 16))
       (cat (L '(label drain)
               '(ld r0 r11 8) '(ld r7 r11 0) '(cmp r0 r7) '(br ge noconf)
               (L 'ldx 'r14 'r11 'r0 8 tro8)
               '(xor r14 r14 1)
               '(add r0 r0 1) '(st r11 8 r0)
               (L 'ldx 'r9 'r11 'r14 8 who8)
               '(li r10 0)
               '(label node)
               '(cmp r9 0) '(br eq drain)
               '(ldx r3 r13 r9 8 0)
               '(ldx r0 r12 r3 8 0) '(cmp r0 0) '(br ne live)   ; size 0 = TOMBSTONE (freduce):
               '(ldx r0 r13 r9 8 8)                             ; unlink the dead node, walk on
               '(cmp r10 0) '(br ne dprev)
               (L 'stx 'r11 'r14 8 who8 'r0) '(jmp dnext)
               '(label dprev)
               '(stx r13 r10 8 8 r0)
               '(label dnext)
               '(mov r9 r0) '(jmp node)
               '(label live)
               '(ldx r0 r12 r3 8 8) '(cmp r0 r14) '(br ne noswap)
               '(ldx r7 r12 r3 8 16) '(stx r12 r3 8 8 r7) '(stx r12 r3 8 16 r0)
               '(label noswap)
               '(ldx r8 r12 r3 8 8)
               '(mov r0 r8) '(sar r0 1)
               (L 'ldx 'r0 'r11 'r0 8 vao8)
               '(cmp r0 r8) '(br eq keep)
               '(ldx r7 r12 r3 8 0) '(add r7 r7 r3) '(add r7 r7 1) '(push r7)
               '(add r0 r3 3)
               '(label scan)
               '(ld r7 sp 0) '(cmp r0 r7) '(br ge scanfail)
               '(ldx r7 r12 r0 8 0)
               '(mov r8 r7) '(sar r8 1)
               (L 'ldx 'r8 'r11 'r8 8 vao8)
               '(xor r7 r7 1)
               '(cmp r8 r7) '(br ne found)
               '(add r0 r0 1) '(jmp scan)
               '(label found)
               '(xor r7 r7 1)
               '(stx r12 r0 8 0 r14)
               '(stx r12 r3 8 16 r7)
               '(ldx r0 r13 r9 8 8)
               '(cmp r10 0) '(br ne fprev)
               (L 'stx 'r11 'r14 8 who8 'r0) '(jmp flink)
               '(label fprev)
               '(stx r13 r10 8 8 r0)
               '(label flink)
               (L 'ldx 'r8 'r11 'r7 8 who8)
               '(stx r13 r9 8 8 r8)
               (L 'stx 'r11 'r7 8 who8 'r9)
               '(mov r9 r0)
               '(add sp sp 8) '(jmp node)
               '(label scanfail)
               '(add sp sp 8)
               '(ldx r8 r12 r3 8 8)
               '(mov r0 r8) '(sar r0 1)
               (L 'ldx 'r7 'r11 'r0 8 vao8)
               '(cmp r7 0) '(br ne conflict)
               (L 'stx 'r11 'r0 8 vao8 'r8)                       ; unit: val[v] = oth
               '(ld r7 r11 16) (L 'stx 'r11 'r0 8 lvo8 'r7)
               '(add r7 r3 1)  (L 'stx 'r11 'r0 8 rso8 'r7)
               '(ld r7 r11 0)  (L 'stx 'r11 'r7 8 tro8 'r8)
               '(add r7 r7 1) '(st r11 0 r7)
               '(label keep)
               '(ldx r7 r13 r9 8 8) '(mov r10 r9) '(mov r9 r7) '(jmp node)
               '(label conflict)
               '(mov r0 r3) '(jmp ret)
               '(label noconf)
               '(li r0 -1)
               '(label ret)
               '(pop r14) '(pop r13) '(pop r12) '(pop r11) '(pop r3))
            (cat epi-ir deopt2-ir)))))))
   ; --- kernel 2: the CONFLICT handler -- (conf fx ar wn confl). ---------------------
   ; registers: r11=fx r12=ar r13=wn (pushed), r3 scratch (pushed), r14 counter/glue
   ; (pushed); r9 write index, r10 trail/read index, r0/r7/r8 scratch; fx w7 (byte 56)
   ; holds the current skip-var. the twin above is the spec, phase for phase.
   (cls-ir nv seo8)                                         ; clear the seen section (fresh labels)
    (: L1 (mint 0) L2 (mint 0)
       (L '(li r0 0) '(li r8 0) (L 'label L1) (L 'cmp 'r0 nv) (L 'br 'gt L2)
          (L 'stx 'r11 'r0 8 seo8 'r8) '(add r0 r0 1) (L 'jmp L1) (L 'label L2)))
   (abs-ir lvo8 seo8 aco8)                                  ; absorb the clause at r7 (fresh labels);
    (: Ll (mint 0) Lt (mint 0) Ln (mint 0) Le (mint 0)      ; counter r14, write r9, skipv fx w7
       (L '(ldx r0 r12 r7 8 0) '(add r0 r0 r7) '(add r0 r0 1) '(push r0)
          '(add r7 r7 1)
          (L 'label Ll) '(ld r0 sp 0) '(cmp r7 r0) (L 'br 'ge Le)
          '(ldx r3 r12 r7 8 0)
          '(mov r0 r3) '(sar r0 1)
          '(ld r8 r11 56) '(cmp r0 r8) (L 'br 'eq Ln)
          (L 'ldx 'r8 'r11 'r0 8 seo8) '(cmp r8 0) (L 'br 'ne Ln)
          (L 'ldx 'r8 'r11 'r0 8 lvo8) '(cmp r8 0) (L 'br 'eq Ln)
          '(li r8 1) (L 'stx 'r11 'r0 8 seo8 'r8)
          (L 'ldx 'r8 'r11 'r0 8 aco8) '(ld r3 r11 48) '(add r8 r8 r3) (L 'stx 'r11 'r0 8 aco8 'r8)
          (L 'ldx 'r8 'r11 'r0 8 lvo8) '(ld r3 r11 16) '(cmp r8 r3) (L 'br 'ne Lt)
          '(add r14 r14 1) (L 'jmp Ln)
          (L 'label Lt) '(ldx r3 r12 r7 8 0) '(stx r12 r9 8 0 r3) '(add r9 r9 1)
          (L 'label Ln) '(add r7 r7 1) (L 'jmp Ll)
          (L 'label Le) '(add sp sp 8)))
   (fconf-ir nv)
    (: tro8 64 lvo8 (* 8 (lvo-of nv)) rso8 (* 8 (rso-of nv)) who8 (* 8 (who-of nv))
       vao8 (* 8 (vao-of nv)) aco8 (* 8 (aco-of nv)) pho8 (* 8 (pho-of nv)) seo8 (* 8 (seo-of nv))
       bufk (apof (cask 1))
       (cat (guard-ir 0 bufk) (cat (guard-ir 1 bufk) (cat (guard-ir 2 bufk) (cat (fixg-ir 3)
       (cat '((push r3) (push r11) (push r12) (push r13) (push r14)
              (ld r0 r1 0)  (ld r0 r0 8) (lea r11 r0 16)
              (ld r0 r1 8)  (ld r0 r0 8) (lea r12 r0 16)
              (ld r0 r1 16) (ld r0 r0 8) (lea r13 r0 16)
              (ld r7 r1 24) (sar r7 1)                            ; confl -> r7 (first absorb's clause)
              (ld r0 r11 16) (cmp r0 0) (br eq retm1))            ; level 0 -> -1
       (cat (cls-ir nv seo8)                                      ; phase 1: clear seen
       (cat '((li r14 0)                                          ; counter
              (ld r9 r11 32) (add r9 r9 2)                        ; widx = cid0+2
              (li r0 0) (st r11 56 r0))                           ; skipv = 0
       (cat (abs-ir lvo8 seo8 aco8)                               ; phase 2: absorb the conflict clause
       (cat (L '(ld r10 r11 0) '(sub r10 r10 1)                   ; t = top-1
               '(label walk)
               (L 'ldx 'r0 'r11 'r10 8 tro8)                      ; np = trail[t]
               '(mov r3 r0) '(sar r3 1)
               (L 'ldx 'r8 'r11 'r3 8 seo8) '(cmp r8 0) '(br ne got)
               '(sub r10 r10 1) '(jmp walk)
               '(label got)
               '(li r8 0) (L 'stx 'r11 'r3 8 seo8 'r8)            ; seen[v] = 0
               '(sub r14 r14 1) '(cmp r14 0) '(br eq uip)
               (L 'ldx 'r7 'r11 'r3 8 rso8) '(sub r7 r7 1)        ; cs = rsn[v]-1
               '(st r11 56 r3)                                    ; skipv = v
               '(push r10))
       (cat (abs-ir lvo8 seo8 aco8)                               ; absorb the reason clause
       (cat '((pop r10) (sub r10 r10 1) (jmp walk)
              (label uip)
              (xor r0 r0 1)                                       ; asserting literal
              (ld r7 r11 32) (stx r12 r7 8 8 r0)                  ; ar[cid0+1] = it
              ; phase 3: minimize in place. rd=r10, wr=r9, wend on the stack.
              (push r9)
              (ld r10 r11 32) (add r10 r10 2) (mov r9 r10)
              (label mn) (ld r0 sp 0) (cmp r10 r0) (br ge mnend)
              (ldx r0 r12 r10 8 0)
              (mov r3 r0) (sar r3 1)
              (st r11 56 r3))                                     ; w7 = v
       (cat (L (L 'ldx 'r7 'r11 'r3 8 rso8)
               '(cmp r7 0) '(br eq mkeep)
               '(sub r7 r7 1)
               '(ldx r0 r12 r7 8 0) '(add r0 r0 r7) '(push r0)    ; inner lim (inclusive)
               '(add r7 r7 1)
               '(label mck) '(ld r0 sp 0) '(cmp r7 r0) '(br gt mred)
               '(ldx r0 r12 r7 8 0) '(sar r0 1)
               '(ld r8 r11 56) '(cmp r0 r8) '(br eq mcknx)
               (L 'ldx 'r8 'r11 'r0 8 lvo8) '(cmp r8 0) '(br eq mcknx)
               (L 'ldx 'r8 'r11 'r0 8 seo8) '(cmp r8 0) '(br ne mcknx)
               '(add sp sp 8) '(jmp mkeep)                        ; a fresh lit -> NOT redundant
               '(label mcknx) '(add r7 r7 1) '(jmp mck)
               '(label mred) '(add sp sp 8) '(jmp mnnext)
               '(label mkeep) '(ldx r0 r12 r10 8 0) '(stx r12 r9 8 0 r0) '(add r9 r9 1)
               '(label mnnext) '(add r10 r10 1) '(jmp mn)
               '(label mnend) '(add sp sp 8))                     ; r9 = wend after compaction
       ; phase 3b: reason-side bump -- every UNSEEN var in a learnt literal's reason
       ; gets act += vinc (seen still holds the analysis marks; w7 free as scratch).
       (cat (L '(ld r10 r11 32) '(add r10 r10 1)                  ; j = cid0+1
               '(label rb) '(cmp r10 r9) '(br ge rbe)
               '(ldx r0 r12 r10 8 0) '(sar r0 1)                  ; v
               (L 'ldx 'r7 'r11 'r0 8 rso8)
               '(cmp r7 0) '(br eq rbn)
               '(sub r7 r7 1)
               '(ldx r0 r12 r7 8 0) '(add r0 r0 r7) '(st r11 56 r0)   ; w7 = last lit index
               '(add r7 r7 1)
               '(label rk) '(ld r0 r11 56) '(cmp r7 r0) '(br gt rbn)
               '(ldx r0 r12 r7 8 0) '(sar r0 1)                   ; v2
               (L 'ldx 'r8 'r11 'r0 8 seo8) '(cmp r8 0) '(br ne rknx)
               (L 'ldx 'r8 'r11 'r0 8 aco8) '(ld r3 r11 48) '(add r8 r8 r3)
               (L 'stx 'r11 'r0 8 aco8 'r8)
               '(label rknx) '(add r7 r7 1) '(jmp rk)
               '(label rbn) '(add r10 r10 1) '(jmp rb)
               '(label rbe))
       (cat (cls-ir nv seo8)                                      ; phase 4: clear seen (-> level marks)
       (cat (L '(ld r0 r11 16)                                    ; mark dl
               '(li r8 1) (L 'stx 'r11 'r0 8 seo8 'r8)
               '(li r14 1) '(li r10 0)                            ; glue=1, bj=0
               '(ld r7 r11 32) '(add r7 r7 2)
               '(label gb) '(cmp r7 r9) '(br ge gbe)
               '(ldx r0 r12 r7 8 0) '(sar r0 1)
               (L 'ldx 'r0 'r11 'r0 8 lvo8)                       ; L
               '(cmp r10 r0) '(br ge gb1) '(mov r10 r0)
               '(label gb1)
               (L 'ldx 'r8 'r11 'r0 8 seo8) '(cmp r8 0) '(br ne gb2)
               '(li r8 1) (L 'stx 'r11 'r0 8 seo8 'r8) '(add r14 r14 1)
               '(label gb2) '(add r7 r7 1) '(jmp gb)
               '(label gbe)
               ; phase 5: backjump to bj (r10)
               '(ld r7 r11 0)
               '(label bjl) '(cmp r7 0) '(br eq bje)
               '(mov r8 r7) '(sub r8 r8 1)
               (L 'ldx 'r0 'r11 'r8 8 tro8)                       ; el = trail[t-1]
               '(mov r3 r0) '(sar r3 1)
               (L 'ldx 'r8 'r11 'r3 8 lvo8) '(cmp r8 r10) '(br le bje)
               '(and r0 r0 1) '(add r0 r0 1) (L 'stx 'r11 'r3 8 pho8 'r0)
               '(li r0 0) (L 'stx 'r11 'r3 8 vao8 'r0) (L 'stx 'r11 'r3 8 lvo8 'r0) (L 'stx 'r11 'r3 8 rso8 'r0)
               '(sub r7 r7 1) '(jmp bjl)
               '(label bje) '(st r11 0 r7) '(st r11 8 r7) '(st r11 16 r10)
               ; phase 6: size, aru, reorder, watches
               '(ld r3 r11 32)                                    ; cid0
               '(mov r0 r9) '(sub r0 r0 r3) '(sub r0 r0 1)        ; size
               '(stx r12 r3 8 0 r0) '(st r11 32 r9)               ; ar[cid0]=size; aru=wend
               '(cmp r0 2) '(br lt assert)
               '(mov r10 r3) '(add r10 r10 2)                     ; reorder: argmax level
               '(ldx r0 r12 r10 8 0) '(sar r0 1) (L 'ldx 'r8 'r11 'r0 8 lvo8)
               '(mov r7 r10) '(add r7 r7 1)
               '(label ro) '(cmp r7 r9) '(br ge roe)
               '(ldx r0 r12 r7 8 0) '(sar r0 1) (L 'ldx 'r0 'r11 'r0 8 lvo8)
               '(cmp r0 r8) '(br le ro2) '(mov r8 r0) '(mov r10 r7)
               '(label ro2) '(add r7 r7 1) '(jmp ro)
               '(label roe)
               '(ldx r0 r12 r3 8 16) '(ldx r7 r12 r10 8 0) '(stx r12 r3 8 16 r7) '(stx r12 r10 8 0 r0)
               '(ldx r7 r12 r3 8 8) '(ldx r8 r12 r3 8 16)         ; l0, l1
               '(ld r10 r11 40)                                   ; wnu
               '(stx r13 r10 8 0 r3)
               (L 'ldx 'r0 'r11 'r7 8 who8) '(stx r13 r10 8 8 r0) (L 'stx 'r11 'r7 8 who8 'r10)
               '(add r10 r10 2)
               '(stx r13 r10 8 0 r3)
               (L 'ldx 'r0 'r11 'r8 8 who8) '(stx r13 r10 8 8 r0) (L 'stx 'r11 'r8 8 who8 'r10)
               '(add r10 r10 2) '(st r11 40 r10)
               '(label assert)                                    ; phase 7: assign learnt[0], reason cid0+1
               '(ldx r8 r12 r3 8 8) '(mov r0 r8) '(sar r0 1)
               (L 'stx 'r11 'r0 8 vao8 'r8)
               '(ld r7 r11 16) (L 'stx 'r11 'r0 8 lvo8 'r7)
               '(mov r7 r3) '(add r7 r7 1) (L 'stx 'r11 'r0 8 rso8 'r7)
               '(ld r7 r11 0) (L 'stx 'r11 'r7 8 tro8 'r8) '(add r7 r7 1) '(st r11 0 r7)
               '(mov r0 r3) '(shl r0 6)                           ; return (cid0<<6)|min(glue,63)
               '(cmp r14 63) '(br le pk) '(li r14 63)
               '(label pk) '(or r0 r0 r14) '(jmp fin)
               '(label retm1) '(li r0 -1)
               '(label fin)
               '(pop r14) '(pop r13) '(pop r12) '(pop r11) '(pop r3))
            (cat epi-ir deopt2-ir)))))))))))))))))
   ; --- kernel 3: DECIDE -- (dec fx). caller-saved regs only, no pushes. -------------
   (fdec-ir nv)
    (: tro8 64 lvo8 (* 8 (lvo-of nv)) rso8 (* 8 (rso-of nv)) vao8 (* 8 (vao-of nv))
       aco8 (* 8 (aco-of nv)) pho8 (* 8 (pho-of nv)) bufk (apof (cask 1))
       (cat (guard-ir 0 bufk)
       (cat '((ld r9 r1 0) (ld r9 r9 8) (lea r9 r9 16)
              (li r7 0) (li r8 -1) (li r0 1))
       (cat (L '(label dl) (L 'cmp 'r0 nv) '(br gt dle)
               (L 'ldx 'r3 'r9 'r0 8 vao8) '(cmp r3 0) '(br ne dn)
               (L 'ldx 'r3 'r9 'r0 8 aco8)
               '(cmp r7 0) '(br eq take)
               '(cmp r3 r8) '(br gt take) '(jmp dn)
               '(label take) '(mov r7 r0) '(mov r8 r3)
               '(label dn) '(add r0 r0 1) '(jmp dl)
               '(label dle) '(cmp r7 0) '(br eq ret0)
               '(ld r0 r9 16) '(add r0 r0 1) '(st r9 16 r0)       ; level++
               (L 'ldx 'r3 'r9 'r7 8 pho8)
               '(mov r0 r7) '(add r0 r0 r0)                       ; el = 2v (+1 unless phase 1)
               '(cmp r3 1) '(br eq pos) '(add r0 r0 1)
               '(label pos)
               (L 'stx 'r9 'r7 8 vao8 'r0)                        ; assign(el, 0)
               '(ld r3 r9 16) (L 'stx 'r9 'r7 8 lvo8 'r3)
               '(li r3 0) (L 'stx 'r9 'r7 8 rso8 'r3)
               '(ld r3 r9 0) (L 'stx 'r9 'r3 8 tro8 'r0) '(add r3 r3 1) '(st r9 0 r3)
               '(mov r0 r7) '(jmp dfin)
               '(label ret0) '(li r0 0)
               '(label dfin))
            (cat epi-ir deopt1-ir)))))
   fkers (tablet 0)                                         ; nv -> (bcp conf dec), one assemble per nvars
   fknob #0                                                 ; pin 1 to force the interpreted twins (the differential switch)
   fmaxl0 #2000                                             ; the initial learnt-DB cap (the gate lowers it to force reductions)
   frp0 #4                                                  ; rephase-wheel cadence in restarts (pin 0 = off)
   (fnif ir fb ar)                                          ; assemble + install one kernel (fb = the honest twin)
    (: bs (peep (assemble 'x64 ir) 'bytes 0)
       c (cask (tally bs))
       _ (foldl (\ i b (: _ (pin c i b) (+ i 1))) 0 bs)
       (nif c fb '(\ q (q)) ar))
   (fbcpk nv)                                               ; -> (bcp conf dec), or () when they can't build
    (? (! (&& (lit? nif) (id? (intern ai-arch) 'x64))) ()
       (: hit (peep fkers nv ())
          (? (two? hit) hit
             (: ks (L (fnif (fbcp-ir nv) fbcp3 3)
                      (fnif (fconf-ir nv) fconf3 4)
                      (fnif (fdec-ir nv) fdec3 1))
                _ (pin fkers nv ks) ks))))
   (fmk formula nvars)                                      ; build the flat solver state
    ; the LAYOUT nv is nvars rounded up to a power-of-2 bucket, so the kernel cache
    ; (keyed per layout) survives BVA's varying variable counts. phantom vars above
    ; the real count are sound: never watched, activity 0 (decided dead last, after
    ; every real var -- the ascending scan keeps the FIRST max), popped clean.
    (: s (tablet 0) nv ((: (go k) (? (>= k nvars) k (go (* 2 k)))) 16)
       fx (cask (* 8 (+ (seo-of nv) (+ nv 1))))
       _ (putw fx 3 nv) _ (putw fx 4 2) _ (putw fx 5 2) _ (putw fx 6 256)
       _ (pin s 'nvars nv) _ (pin s 'fx fx)
       _ (pin s 'lvo (lvo-of nv)) _ (pin s 'rso (rso-of nv)) _ (pin s 'who (who-of nv)) _ (pin s 'vao (vao-of nv))
       _ (pin s 'ar (cask 4096)) _ (pin s 'wn (cask 4096))  ; words 0-1 of each reserved: 0 stays "none"
       _ (pin s 'bad 0)
       _ (pin s 'nconf 0) _ (pin s 'rnum 1) _ (pin s 'climit 400) _ (pin s 'rew 0)
       _ (pin s 'learnts ()) _ (pin s 'nl 0) _ (pin s 'maxl (peep fmaxl0 0 2000))
       ks (fbcpk nv)
       use (&& (two? ks) (= 0 (peep fknob 0 0)))
       _ (pin s 'bcp  (? use (cap ks) fbcp3))
       _ (pin s 'conf (? use (caup ks) fconf3))
       _ (pin s 'dec  (? use (caup (cup ks)) fdec3))
       _ (foldl (\ _ c (fload s c)) 0 formula) s)
   ; --- the cold path: restarts, decay, learnt-DB reduction (lisp side) -----------
   (fbackjump s lvl)                                        ; pop + unassign above lvl (restarts: lvl = 0)
    (: fx (peep s 'fx ()) nv (peep s 'nvars 0) lvo (peep s 'lvo 0) rso (peep s 'rso 0)
       vao (peep s 'vao 0) pho (pho-of nv)
       nt ((: (go t)
              (? (= t 0) 0
                 (: el (getw fx (+ 8 (- t 1))) v (>> el 1)
                    (? (> (getw fx (+ lvo v)) lvl)
                       (: _ (putw fx (+ pho v) (+ 1 (& el 1)))
                          _ (putw fx (+ vao v) 0) _ (putw fx (+ lvo v) 0) _ (putw fx (+ rso v) 0)
                          (go (- t 1)))
                       t))))
           (getw fx 0))
       _ (putw fx 0 nt) _ (putw fx 1 nt) (putw fx 2 lvl))
   (fdecay s)                                               ; integer VSIDS: vinc *= 21/20; rescale by >>8
    (: fx (peep s 'fx ()) vi (// (* (getw fx 6) 21) 20)
       (? (> vi 16777216)
          (: nv (peep s 'nvars 0) aco (aco-of nv)
             _ ((: (go v) (? (> v nv) 0 (: _ (putw fx (+ aco v) (>> (getw fx (+ aco v)) 8)) (go (+ v 1))))) 1)
             (putw fx 6 (>> vi 8)))
          (putw fx 6 vi)))
   (fnext-restart s) (: rn (+ 1 (peep s 'rnum 1)) _ (pin s 'rnum rn) _ (pin s 'nconf 0) _ (pin s 'climit (* (luby rn) 400)) 0)
   (frephase s st)                                          ; randomize every saved phase; -> st'
    (: fx (peep s 'fx ()) nv (peep s 'nvars 0) pho (pho-of nv)
       ((: (go v st) (? (> v nv) st
             (: p (random st 2) _ (putw fx (+ pho v) (+ 1 (cap p))) (go (+ v 1) (cup p)))))
        1 st))
   (finvert s)                                              ; flip every saved phase
    (: fx (peep s 'fx ()) nv (peep s 'nvars 0) pho (pho-of nv)
       ((: (go v) (? (> v nv) 0
             (: p (getw fx (+ pho v)) _ (putw fx (+ pho v) (? (= p 1) 2 1)) (go (+ v 1))))) 1))
   ; learnt-DB REDUCTION at a level-0 restart, by TOMBSTONE: the worst-glue half
   ; (glue <= 3 immortal) gets its arena SIZE word zeroed, and both kernels' bcp walk
   ; unlinks a dead clause's watch nodes lazily on the next visit -- no arena
   ; compaction, no watch rebuild, so a reduction is O(learnts) lisp. a dead clause's
   ; words stay intact (mark, not corrupt), but the size-0 check runs FIRST in the
   ; walk, so its stale watch slots are never read as a clause. level-0 reasons are
   ; zeroed (absorb skips level-0 vars anyway; belt and braces). the arena only
   ; grows -- dead slabs leak until the solve ends, the price of O(1)-amortized
   ; reduction (fens doubles, so the growth stays geometric).
   (freduce s)
    (: fx (peep s 'fx ()) rso (peep s 'rso 0) ar (peep s 'ar ())
       ls (peep s 'learnts ())
       srt (sortby (\ a b (<= (cup a) (cup b))) (filter (\ p (> (cup p) 3)) ls))
       nk (// (tally srt) 2)
       dead (tablet 0)
       _ (foldl (\ i p (: _ (? (>= i nk) (pin dead (cap p) 1) 0) (+ i 1))) 0 srt)
       _ ((: (zr t) (? (>= t (getw fx 0)) 0
              (: v (>> (getw fx (+ 8 t)) 1) _ (putw fx (+ rso v) 0) (zr (+ t 1))))) 0)
       _ (foldl (\ _ cid (: _ (putw ar cid 0) 0)) 0 (keys dead))
       nl (filter (\ p (= 0 (peep dead (cap p) 0))) ls)
       _ (pin s 'learnts nl) _ (pin s 'nl (tally nl))
       (pin s 'maxl (// (* (peep s 'maxl 2000) 3) 2)))
   ; --- the search loop: three kernel calls + lisp bookkeeping --------------------
   (fsearch s)                                              ; -> 'sat or 'unsat (s holds the model on SAT)
    (: fx (peep s 'fx ()) nv (peep s 'nvars 0)
       ((: (loop st)                                                ; st threads the rephase RNG (seeded: reproducible)
           (: confl ((peep s 'bcp ()) fx (peep s 'ar ()) (peep s 'wn ()))
              (? (> confl -1)
                 (: _ (fens s 'ar (* 8 (+ (getw fx 4) (+ nv 3))))   ; room for the learnt clause
                    _ (fens s 'wn (* 8 (+ (getw fx 5) 4)))          ; ... and its two watch nodes
                    r ((peep s 'conf ()) fx (peep s 'ar ()) (peep s 'wn ()) confl)
                    (? (= r -1) 'unsat
                       (: cid (>> r 6) glue (& r 63)
                          _ (? (< 1 (getw (peep s 'ar ()) cid))     ; size >= 2: track for reduction
                               (: _ (pin s 'learnts (link (link cid glue) (peep s 'learnts ())))
                                  (pin s 'nl (+ 1 (peep s 'nl 0)))) 0)
                          _ (fdecay s) _ (pin s 'nconf (+ 1 (peep s 'nconf 0)))
                          (loop st))))
                 (&& (> (getw fx 2) 0)                              ; a full DB also forces the restart:
                     (|| (>= (peep s 'nconf 0) (peep s 'climit 0))  ; reduction is only sound at level 0
                         (> (peep s 'nl 0) (peep s 'maxl 2000))))
                    (: _ (fbackjump s 0) _ (fnext-restart s)
                       _ (? (> (peep s 'nl 0) (peep s 'maxl 2000)) (freduce s) 0)
                       ; REPHASE WHEEL every frp0 restarts, policies cycling random ->
                       ; invert -> keep: a SAT instance stuck in a bad polarity basin
                       ; escapes (uf250 ~35% net), the keep spoke preserves a good basin,
                       ; and UNSAT/php runs are measurably untouched. always-random
                       ; instead reshuffles luck (one uf250 went 1.2s -> 12s).
                       rp (peep frp0 0 0)
                       st2 (? (&& (> rp 0) (= 0 (% (peep s 'rnum 1) rp)))
                              (: w (peep s 'rew 0) _ (pin s 'rew (+ w 1))
                                 (? (= 0 (% w 3)) (frephase s st)
                                    (= 1 (% w 3)) (: _ (finvert s) st)
                                    st))
                              st)
                       (loop st2))
                 (: v ((peep s 'dec ()) fx)
                    (? (= v 0) 'sat (loop st)))))) (seed 42)))
   (fextract s nvars) (: fx (peep s 'fx ()) vao (peep s 'vao 0)
                         (map (\ v (link v (? (= 0 (& (getw fx (+ vao v)) 1)) 1 -1))) (rng 1 (+ nvars 1))))
   ; --- BVA: bounded variable ADDITION (clause factoring), the preprocessing pass ---
   ; the ablation-found pigeonhole killer (doc/sat-kernels.md): cadical minus factoring
   ; collapses to minisat-class. for a literal l, GROW a set of literals M_lit and a set
   ; of clauses M_cls (all containing l) such that (m | C\{l}) is in the formula for
   ; every pairing; then a fresh variable x replaces the |M_lit|*|M_cls| clauses with
   ; |M_cls| clauses (x | C\{l}) + |M_lit| definitions (-x | m). resolving on x recovers
   ; every original (UNSAT preserved); a model extends by x := AND of M_lit (SAT
   ; preserved); models of the new formula project by DROPPING vars > nvars. adding
   ; definitional variables is the extended-resolution move -- the proof system where
   ; pigeonhole has POLYNOMIAL refutations (Cook 1976), which plain resolution (and so
   ; ANY amount of clause learning) provably lacks (Haken 1985).
   fbva0 #1                                                 ; pin 0 to solve raw (the A/B switch)
   fbvar0 #8                                                ; BVA round cap
   fbvac0 #1                                                ; 1 = factor ORIGINAL structure only (no aux cascade)
   (bva-sub? r d)                                           ; sorted lists: is r a subset of d?
    (? (atom? r) 1 (atom? d) 0
       (= (cap r) (cap d)) (bva-sub? (cup r) (cup d))
       (< (cap d) (cap r)) (bva-sub? r (cup d)) 0)
   (bva-x1 d r)                                             ; the ONE literal of d beyond r (|d| = |r|+1)
    (? (atom? r) (cap d) (= (cap d) (cap r)) (bva-x1 (cup d) (cup r)) (cap d))
   (fbva formula nvars)                                     ; -> (formula2 . nvars2), equisatisfiable
    (: cls (tablet 0) ckey (tablet 0) occ (tablet 0) ncid #0 nv #0
       _ (pin nv 0 nvars)
       addc (\ c0                                           ; canon + dedupe + index; drops tautologies
        (: c (sort (dedup-lits c0))
           (? (= 1 (taut? c)) 0
              (? (whole? (peep ckey c ())) 0                ; the sorted clause ITSELF is the key (chains key by value)
                 (: cid (peep ncid 0 0) _ (pin ncid 0 (+ cid 1))
                    _ (pin cls cid c) _ (pin ckey c cid)
                    _ (foldl (\ _ m (: _ (pin occ m (link cid (peep occ m ()))) 0)) 0 c)
                    1)))))
       delc (\ cid (: c (peep cls cid ())
                      (? (! (two? c)) 0 (: _ (pull cls cid 0) _ (pull ckey c 0) 1))))
       livec (\ l (filter (\ cid (< 1 (tally (peep cls cid ())))) (peep occ l ())))
       orig (\ m (<= (>> (abs m) 0) nvars))                 ; an ORIGINAL-variable literal
       ofree (\ c (all orig c))                             ; ... clause of only those
       try (\ l                                             ; one greedy factoring attempt at l -> 1 if applied
        (: mcls0 (? (&& (= 1 (peep fbvac0 0 0)) (! (orig l))) ()
                    (? (= 1 (peep fbvac0 0 0)) (filter (\ cid (= 1 (ofree (peep cls cid ())))) (livec l))
                       (livec l)))
           (? (< (tally mcls0) 4) 0
              (: g ((: (grow mlit mcls red)                  ; extend M_lit while the reduction strictly grows
                       (: pc (tablet 0) pl (tablet 0)        ; candidate -> match count / matched cids
                          _ (foldl (\ _ cid
                               (: c (peep cls cid ()) r (rem-lit l c)
                                  k (foldl (\ b m2 (? (< (tally (peep occ m2 ())) (tally (peep occ b ()))) m2 b))
                                           (cap r) (cup r))
                                  (foldl (\ _ did
                                       (: d (peep cls did ())
                                          (? (! (two? d)) 0
                                             (= did cid) 0
                                             (! (= (tally d) (tally c))) 0
                                             (! (= 1 (bva-sub? r d))) 0
                                             (: m (bva-x1 d r)
                                                (? (&& (= 1 (peep fbvac0 0 0)) (! (orig m))) 0
                                                   (member? m mlit) 0
                                                   (: _ (pin pc m (+ 1 (peep pc m 0)))
                                                      _ (pin pl m (link cid (peep pl m ()))) 0))))))
                                     0 (peep occ k ()))))
                             0 mcls)
                          ks (keys pc)
                          (? (atom? ks) (link mlit mcls)
                             (: best (foldl (\ b m (: cm (peep pc m 0) cb (peep pc b 0)   ; max count; ties -> LOWEST literal
                                               (? (|| (> cm cb) (&& (= cm cb) (< m b))) m b)))   ; (symmetric instances: keeps groups contiguous)
                                            (cap ks) (cup ks))
                                nc (peep pc best 0) nl (+ 1 (tally mlit))
                                red2 (- (* nl nc) (+ nl nc))
                                (? (> red2 red) (grow (link best mlit) (peep pl best ()) red2)
                                   (link mlit mcls))))))
                    (link l ()) mcls0 -1)
                 mlit (cap g) mcls (cup g)
                 nl (tally mlit) ncl (tally mcls)
                 (? (< (- (* nl ncl) (+ nl ncl)) 1) 0        ; apply only when it strictly shrinks the formula
                    (: x (+ 1 (peep nv 0 0)) _ (pin nv 0 x)
                       rs (map (\ cid (rem-lit l (peep cls cid ()))) mcls)
                       _ (foldl (\ _ m (: _ (foldl (\ _ r
                              (: k (sort (link m r)) did (peep ckey k ())
                                 (? (whole? did) (delc did) (scare 'bva-miss k))))
                            0 rs) 0)) 0 mlit)
                       _ (foldl (\ _ r (: _ (addc (link x r)) 0)) 0 rs)
                       _ (foldl (\ _ m (: _ (addc (link (- 0 x) (link m ()))) 0)) 0 mlit)
                       _ (addc (link x (map (\ m (- 0 m)) mlit)))   ; the OTHER direction: x <- AND(m) --
                       1))))))                                       ; a COMPLETE definition (pure extended
                                                                     ; resolution), so x propagates instead of
                                                                     ; wandering: without it CDCL decides x freely
       _ (foldl (\ _ c (: _ (addc c) 0)) 0 formula)
       _ ((: (round r)                                       ; sweep most-occurring literals first; stop on a quiet
             (: ls (sortby (\ a b (? (= (cap a) (cap b)) (<= (cup a) (cup b)) (> (cap a) (cap b))))   ; round OR when the
                           (filter (\ p (>= (cap p) 4)) (map (\ m (link (tally (livec m)) m)) (keys occ))))   ; cumulative find
                ch (foldl (\ a p (+ a (try (cup p)))) 0 ls)                                           ; is a handful (a sweep
                (? (&& (> ch 0)                                                                       ; costs a full pass; an
                       (&& (> (* 16 (- (peep nv 0 0) nvars)) nvars)                                   ; incidental 6-of-300 is
                           (&& (< r (peep fbvar0 0 8)) (< (peep nv 0 0) (+ (* 4 nvars) 64)))))        ; not worth another)
                   (round (+ r 1)) 0)))
           0)
       (link (map (\ cid (peep cls cid ())) (keys cls)) (peep nv 0 0)))
   (fcdcl formula nvars)
    ; the fbva LADDER: re-run the pass on its own output with the baseline lifted (level-1
    ; aux become "original" for level 2) while it keeps factoring SUBSTANTIALLY (> nvars/16
    ; fresh vars -- an incidental handful, e.g. flat graph coloring's 6-of-300, is not a
    ; commander hierarchy and another pass is pure intake cost) -- level 2 deepens the
    ; commander tree (php8 ~1550 -> ~1400 conflicts under the reason-side bump; WITHOUT
    ; that bump a deeper tree actively hurts, so the ladder rides the bump). an instance
    ; with nothing factorable exits after one pass (randoms: no ladder cost). models
    ; still project by the ORIGINAL nvars.
    (: p (? (= 0 (peep fbva0 0 1)) (link formula nvars)
            ((: (go p k) (: p2 (fbva (cap p) (cup p))
                            (? (|| (<= (* 16 (- (cup p2) (cup p))) (cup p)) (>= k 3)) p2 (go p2 (+ k 1)))))
             (link formula nvars) 1))
       s (fmk (cap p) (cup p))
       (? (= 1 (peep s 'bad 0)) 'unsat
          (: r (fsearch s) (? (id? r 'unsat) 'unsat (fextract s nvars)))))
   (count-fcdcl formula nvars)                              ; #SAT by blocking clauses, on the flat engine
    ((: (go fm c) (: r (fcdcl fm nvars) (? (id? r 'unsat) c (go (link (block r) fm) (+ c 1))))) formula 0)
   (fdiff seed n m)                                         ; flat CDCL == the DPLL oracle (and models check)
    (: f (gen-formula seed n m) d (solve f n) c (fcdcl f n)
       dsat (! (id? d 'unsat)) csat (! (id? c 'unsat))
       (? (! (= dsat csat)) 0  (! csat) 1  (sat? c f)))
   (ffuzz k n m) (all (\ i (= 1 (fdiff (+ 1009 (* i 7919)) n m))) (jot k))
   (fboth f n)                                              ; kernels and twins agree, verdict for verdict
    (: _ (pin fknob 0 1) a (fcdcl f n) _ (pin fknob 0 0) b (fcdcl f n)
       (? (id? a 'unsat) (id? b 'unsat) (&& (! (id? b 'unsat)) (sat? b f))))

 ; --- the gate: the flat engine answers exactly like the oracle, kernels == twins
 _ (assert
    ; tiny SAT / UNSAT
    (: f '((1 2) (-1 3) (-2 -3)) m (fcdcl f 3) (&& (! (id? m 'unsat)) (sat? m f)))
    (id? (fcdcl '((1) (-1)) 1) 'unsat)
    (id? (fcdcl '((1 2) (1 -2) (-1 2) (-1 -2)) 2) 'unsat)
    (id? (fcdcl '((1 2 3) (1 2 -3) (1 -2 3) (1 -2 -3) (-1)) 3) 'unsat)
    ; cyclic: SAT, the model checks, and #SAT == Lucas (solver-independent)
    (: f (cyclic 12) m (fcdcl f 12) (&& (! (id? m 'unsat)) (sat? m f)))
    (= (count-fcdcl (cyclic 8) 8) (lucas 8))
    (= (count-fcdcl (cyclic 10) 10) (lucas 10))
    ; differential fuzz vs the DPLL oracle, mixed SAT/UNSAT near the phase transition
    (ffuzz 60 8 30)
    (ffuzz 40 10 30)
    (ffuzz 30 12 50)
    (ffuzz 20 14 58)
    ; native kernels == interpreted twins, verdict for verdict (a no-op switch where they can't build)
    (fboth (cyclic 14) 14)
    (fboth (php 4) (php-vars 4))
    (fboth (php 5) (php-vars 5))
    ; pigeonhole PHP(5): UNSAT + resolution-hard (learning, restarts, arena growth end to end)
    (id? (fcdcl (php 5) (php-vars 5)) 'unsat)
    ; force the learnt-DB REDUCTION path hard (a tiny cap -> compaction every few restarts)
    ; and re-run the differential battery through it, both engines
    (: keep (peep fmaxl0 0 0) _ (pin fmaxl0 0 24)
       ok (&& (id? (fcdcl (php 5) (php-vars 5)) 'unsat)
              (&& (ffuzz 30 12 50) (fboth (php 4) (php-vars 4))))
       _ (pin fmaxl0 0 keep) ok))
 _ (say err (+ "sat/flat: ok -- flat-arena CDCL == DPLL on 150 fuzzed + PHP(5) + #SAT==Lucas"
               (? (two? (fbcpk 8)) " (native bcp+conf+dec kernels live)\n" " (interpreted twins)\n"))))
