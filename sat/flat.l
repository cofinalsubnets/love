; sat/flat -- the CDCL solver again, over FLAT state, with a DOMAIN-SPECIFIC NATIVE
; KERNEL: at solver-build time the two-watched-literal BCP loop is assembled through
; asm/ (neutral IR, section offsets baked as immediates -- the kernel is SPECIALIZED
; to the instance's nvars) and installed via the `nif` seam; the interpreted twin
; `fbcp3` over the SAME memory is its honest deopt fallback, its differential oracle,
; and the whole engine where the kernel can't build (no `nif` in the book -- the
; glazed image mops it -- or a non-x64 host). Everything lives in casks: one fixed
; cask `fx` (header + trail/lvl/rsn/watch-heads/val sections) + two growable arenas
; (`ar` clauses, `wn` watch nodes). Words are 8-byte slots whose LOW 4 bytes carry
; the value (getw/putw touch only those; the high bytes stay zero from the zeroed
; cask, so the kernel's 64-bit ld/st and the byte-level accessors agree exactly).
; Run AFTER sat.l (it reuses the leaked oracle + instances):
;   cat sat/sat.l sat/flat.l | ai
;
; a literal is ENCODED: +v -> 2v, -v -> 2v+1 (neg = xor 1, var = >>1). val[v] holds
; the TRUE encoded literal itself (0 = free), so lit-val is one load + one compare.
; fx word layout (nv = nvars):  w0 top, w1 qhead, w2 level, w3 nv,
;   trail at TRO=4 (nv+1 words), lvl at LVO, rsn at RSO (0 none, else cid+1),
;   watch heads at WHO (2nv+2 words, indexed by encoded literal), val at VAO.
; a clause at arena offset cid is [size, lit0..]; the two WATCHED literals are
; always slots cid+1 and cid+2 (a slide swaps in place). a watch node at offset p
; is [cid, next] (0 = nil; words 0-1 of both arenas are reserved so 0 stays "none").
(:
   ; --- 8-byte word slots, low 4 bytes live ---------------------------------------
   (getw c i) (: b (* 8 i) (| (peep c b 0)
                              (| (<< (peep c (+ b 1) 0) 8)
                                 (| (<< (peep c (+ b 2) 0) 16) (<< (peep c (+ b 3) 0) 24)))))
   (putw c i v) (: b (* 8 i)
                   _ (pin c b (& v 255)) _ (pin c (+ b 1) (& (>> v 8) 255))
                   _ (pin c (+ b 2) (& (>> v 16) 255)) (pin c (+ b 3) (& (>> v 24) 255)))
   (enc l) (? (< l 0) (+ 1 (* 2 (- 0 l))) (* 2 l))          ; signed literal -> encoded
   ; --- state access (the lisp driver's view; offsets cached in s) ----------------
   (flv s el) (: m (getw (peep s 'fx ()) (+ (peep s 'vao 0) (>> el 1)))
                 (? (= m 0) 0 (= m el) 1 -1))               ; 1 sat / -1 false / 0 free
   (flvl s el) (getw (peep s 'fx ()) (+ (peep s 'lvo 0) (>> el 1)))
   (fens s k need)                                          ; ensure cask s[k] holds >= need bytes (grow by doubling)
    (: c (peep s k ())
       (? (<= need (tally c)) 0
          (: n2 ((: (go m) (? (>= m need) m (go (* 2 m)))) (* 2 (tally c)))
             nu (cask n2) _ (pour nu 0 c 0 (tally c)) _ (pin s k nu) 0)))
   (fassign s el rv)                                        ; set el TRUE at the current level, reason rv (0 = decision)
    (: fx (peep s 'fx ()) v (>> el 1) t (getw fx 0)
       _ (putw fx (+ (peep s 'vao 0) v) el)
       _ (putw fx (+ (peep s 'lvo 0) v) (getw fx 2))
       _ (putw fx (+ (peep s 'rso 0) v) rv)
       _ (putw fx (+ 4 t) el)                               ; trail (TRO = 4)
       (putw fx 0 (+ t 1)))
   ; --- clause DB ----------------------------------------------------------------
   (fadd s lits)                                            ; append [size, lits..] to the arena; -> cid (word offset)
    (: n (tally lits) aru (peep s 'aru 0)
       _ (fens s 'ar (* 8 (+ aru (+ n 1))))
       ar (peep s 'ar ())
       _ (putw ar aru n)
       _ (foldl (\ j el (: _ (putw ar j el) (+ j 1))) (+ aru 1) lits)
       _ (pin s 'aru (+ aru (+ n 1))) _ (pin s 'ncls (+ 1 (peep s 'ncls 0))) aru)
   (fclits s cid)                                           ; the clause's encoded literals, as a list
    (: ar (peep s 'ar ()) n (getw ar cid)
       ((: (go j acc) (? (< j (+ cid 1)) acc (go (- j 1) (link (getw ar j) acc)))) (+ cid n) ()))
   (fwatch s cid el)                                        ; push a watch node [cid -> wh[el] list]
    (: wnu (peep s 'wnu 0) _ (fens s 'wn (* 8 (+ wnu 2)))
       wn (peep s 'wn ()) fx (peep s 'fx ()) who (peep s 'who 0)
       _ (putw wn wnu cid) _ (putw wn (+ wnu 1) (getw fx (+ who el)))
       _ (putw fx (+ who el) wnu) (pin s 'wnu (+ wnu 2)))
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
   ; self-contained over the packed layout (offsets recomputed from the nv header
   ; word), so it IS the kernel's deopt fallback -- same arity, same memory, same
   ; answer -- and the reference the kernel is diffed against.
   (fbcp3 fx ar wn)
    (: nv (getw fx 3) lvo (+ 4 (+ nv 1)) rso (+ lvo (+ nv 1)) who (+ rso (+ nv 1)) vao (+ who (+ 2 (* 2 nv)))
       lv (\ el (: m (getw fx (+ vao (>> el 1))) (? (= m 0) 0 (= m el) 1 -1)))
       asg (\ el rv (: v (>> el 1) t (getw fx 0)
               _ (putw fx (+ vao v) el) _ (putw fx (+ lvo v) (getw fx 2))
               _ (putw fx (+ rso v) rv) _ (putw fx (+ 4 t) el) (putw fx 0 (+ t 1))))
       prop1 (\ f                                           ; f just became FALSE: re-examine wh[f]
        ((: (go p prev)
            (? (= p 0) -1
               (: cid (getw wn p)
                  _ (? (= (getw ar (+ cid 1)) f)                         ; normalize: f sits at slot cid+2
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
                           (= 0 (lv oth)) (: _ (asg oth (+ cid 1)) (go (getw wn (+ p 1)) p))   ; unit: force oth
                           cid))))))                                     ; oth false too: CONFLICT
         (getw fx (+ who f)) 0))
       ((: (drain _)
           (? (>= (getw fx 1) (getw fx 0)) -1
              (: p (getw fx (+ 4 (getw fx 1))) _ (putw fx 1 (+ 1 (getw fx 1)))
                 confl (prop1 (^ p 1))
                 (? (> confl -1) confl (drain ()))))) ()))
   ; --- the NATIVE kernel: fbcp3 compiled by hand through asm/ --------------------
   ; specialized per nvars (section displacements are immediates), cached by nv.
   ; lvm ABI: g=rdi(r6) Ip=rsi(r5) Hp=rdx(r2) Sp=rcx(r1); params TAGGED on Sp[i].
   ; prologue: kind-guard the three cask params (a miss deopts to fbcp3 BEFORE any
   ; push, so the machine sp stays balanced on every path), save the callee-saved
   ; five, unwrap byte bases (buf value -> [v+8]=backing str -> +16 = bytes).
   ; registers: r11=fx r12=ar r13=wn r14=f (callee-saved), r3=cid (callee-saved),
   ; r9=p r10=prev r0/r7/r8 scratch (caller-saved). result tagged into Sp[0], out
   ; via Ip+16 -> lvm_ret, exactly the glaze's putfix epilogue.
   (fbcp-ir nv)
    (: tro8 32 lvo8 (* 8 (+ 4 (+ nv 1))) rso8 (+ lvo8 (* 8 (+ nv 1))) who8 (+ rso8 (* 8 (+ nv 1)))
       vao8 (+ who8 (* 8 (+ 2 (* 2 nv)))) bufk (apof (cask 1))
       (gd i) (L (L 'ld 'r0 'r1 (* 8 i)) '(test r0 1) '(br ne deopt)
                 '(ld r7 r0 0) (L 'li 'r8 bufk) '(cmp r7 r8) '(br ne deopt))
       (cat (gd 0) (cat (gd 1) (cat (gd 2)
       (cat '((push r3) (push r11) (push r12) (push r13) (push r14)
              (ld r0 r1 0)  (ld r0 r0 8) (lea r11 r0 16)          ; fx bytes
              (ld r0 r1 8)  (ld r0 r0 8) (lea r12 r0 16)          ; ar bytes
              (ld r0 r1 16) (ld r0 r0 8) (lea r13 r0 16))         ; wn bytes
       (cat (L '(label drain)
               '(ld r0 r11 8) '(ld r7 r11 0) '(cmp r0 r7) '(br ge noconf)   ; qhead >= top -> done
               (L 'ldx 'r14 'r11 'r0 8 tro8)                      ; f = trail[qhead]
               '(xor r14 r14 1)                                   ; ... negated
               '(add r0 r0 1) '(st r11 8 r0)                      ; qhead++
               (L 'ldx 'r9 'r11 'r14 8 who8)                      ; p = wh[f]
               '(li r10 0)                                        ; prev = 0
               '(label node)
               '(cmp r9 0) '(br eq drain)
               '(ldx r3 r13 r9 8 0)                               ; cid = wn[p]
               '(ldx r0 r12 r3 8 8) '(cmp r0 r14) '(br ne noswap) ; normalize: f -> slot cid+2
               '(ldx r7 r12 r3 8 16) '(stx r12 r3 8 8 r7) '(stx r12 r3 8 16 r0)
               '(label noswap)
               '(ldx r8 r12 r3 8 8)                               ; oth = ar[cid+1]
               '(mov r0 r8) '(sar r0 1)
               (L 'ldx 'r0 'r11 'r0 8 vao8)                       ; m = val[oth>>1]
               '(cmp r0 r8) '(br eq keep)                         ; oth satisfied: keep watching f
               '(ldx r7 r12 r3 8 0) '(add r7 r7 r3) '(add r7 r7 1) '(push r7)   ; [sp] = cid+size+1
               '(add r0 r3 3)                                     ; j = cid+3
               '(label scan)
               '(ld r7 sp 0) '(cmp r0 r7) '(br ge scanfail)
               '(ldx r7 r12 r0 8 0)                               ; e = ar[j]
               '(mov r8 r7) '(sar r8 1)
               (L 'ldx 'r8 'r11 'r8 8 vao8)                       ; val[e>>1]
               '(xor r7 r7 1)                                     ; e^1
               '(cmp r8 r7) '(br ne found)                        ; not falsified -> new watch
               '(add r0 r0 1) '(jmp scan)
               '(label found)
               '(xor r7 r7 1)                                     ; e
               '(stx r12 r0 8 0 r14)                              ; ar[j] = f
               '(stx r12 r3 8 16 r7)                              ; ar[cid+2] = e
               '(ldx r0 r13 r9 8 8)                               ; nx = wn[p+1] (read BEFORE relink)
               '(cmp r10 0) '(br ne fprev)
               (L 'stx 'r11 'r14 8 who8 'r0) '(jmp flink)         ; wh[f] = nx
               '(label fprev)
               '(stx r13 r10 8 8 r0)                              ; wn[prev+1] = nx
               '(label flink)
               (L 'ldx 'r8 'r11 'r7 8 who8)                       ; wh[e]
               '(stx r13 r9 8 8 r8)                               ; wn[p+1] = wh[e]
               (L 'stx 'r11 'r7 8 who8 'r9)                       ; wh[e] = p
               '(mov r9 r0)                                       ; p = nx (prev unchanged)
               '(add sp sp 8) '(jmp node)
               '(label scanfail)
               '(add sp sp 8)
               '(ldx r8 r12 r3 8 8)                               ; oth again
               '(mov r0 r8) '(sar r0 1)
               (L 'ldx 'r7 'r11 'r0 8 vao8)
               '(cmp r7 0) '(br ne conflict)                      ; assigned (not sat) -> false -> conflict
               (L 'stx 'r11 'r0 8 vao8 'r8)                       ; unit: val[v] = oth
               '(ld r7 r11 16) (L 'stx 'r11 'r0 8 lvo8 'r7)       ; lvl[v] = level
               '(add r7 r3 1)  (L 'stx 'r11 'r0 8 rso8 'r7)       ; rsn[v] = cid+1
               '(ld r7 r11 0)  (L 'stx 'r11 'r7 8 tro8 'r8)       ; trail[top] = oth
               '(add r7 r7 1) '(st r11 0 r7)                      ; top++
               '(label keep)
               '(ldx r7 r13 r9 8 8) '(mov r10 r9) '(mov r9 r7) '(jmp node)
               '(label conflict)
               '(mov r0 r3) '(jmp ret)
               '(label noconf)
               '(li r0 -1)
               '(label ret)
               '(pop r14) '(pop r13) '(pop r12) '(pop r11) '(pop r3)
               '(shl r0 1) '(or r0 r0 1)                          ; putfix
               '(st r1 0 r0) '(add r5 r5 16) '(ld r7 r5 0) '(jmpr r7)   ; Sp[0] = result; Continue via lvm_ret
               '(label deopt)
               '(ld r7 r5 8) '(lea r5 r7 16) '(ld r7 r5 0) '(jmpr r7))  ; tail-apply fbcp3 (args still on Sp)
            ()))))))
   fkers (tablet 0)                                         ; nv -> installed kernel (one assemble per nvars)
   fknob #0                                                 ; pin 1 to force the interpreted twin (the differential switch)
   fmaxl0 #2000                                             ; the initial learnt-DB cap (the gate lowers it to force reductions)
   (fbcpk nv)                                               ; the specialized native BCP, or () when it can't build
    (? (! (&& (lit? nif) (id? (intern ai-arch) 'x64))) ()
       (: hit (peep fkers nv ())
          (? (lit? hit) hit
             (: bs (peep (assemble 'x64 (fbcp-ir nv)) 'bytes 0)
                c (cask (tally bs))
                _ (foldl (\ i b (: _ (pin c i b) (+ i 1))) 0 bs)
                k (nif c fbcp3 '(\ fx ar wn (fbcp3 fx ar wn)) 3)
                _ (pin fkers nv k) k))))
   (fmk formula nvars)                                      ; build the flat solver state
    (: s (tablet 0) nv nvars
       tro 4 lvo (+ tro (+ nv 1)) rso (+ lvo (+ nv 1)) who (+ rso (+ nv 1)) vao (+ who (+ 2 (* 2 nv)))
       fx (cask (* 8 (+ vao (+ nv 1))))
       _ (putw fx 3 nv)
       _ (pin s 'nvars nv) _ (pin s 'fx fx)
       _ (pin s 'lvo lvo) _ (pin s 'rso rso) _ (pin s 'who who) _ (pin s 'vao vao)
       _ (pin s 'phase (cask (+ nv 1)))
       _ (pin s 'ar (cask 4096)) _ (pin s 'aru 2)           ; words 0-1 reserved: 0 stays "no clause"
       _ (pin s 'wn (cask 4096)) _ (pin s 'wnu 2)
       _ (pin s 'ncls 0) _ (pin s 'bad 0)
       _ (pin s 'act (tablet 0)) _ (pin s 'vinc 1.0)
       _ (pin s 'nconf 0) _ (pin s 'rnum 1) _ (pin s 'climit 100)
       _ (pin s 'learnts ()) _ (pin s 'maxl (peep fmaxl0 0 2000))
       k (fbcpk nv)
       _ (pin s 'bcp (? (&& (lit? k) (= 0 (peep fknob 0 0))) k fbcp3))
       _ (foldl (\ _ c (fload s c)) 0 formula) s)
   (fpropagate s) ((peep s 'bcp ()) (peep s 'fx ()) (peep s 'ar ()) (peep s 'wn ()))
   ; --- 1-UIP analysis / backjump (sat.l's algorithm, reading the arena) ----------
   (fbump s v) (: a (peep s 'act ()) (pin a v (+ (peep a v 0.0) (peep s 'vinc 1.0))))
   (fabs s seen dl skipv c acc)                             ; absorb a clause's encoded lits into (counter . learnt)
    (foldl (\ st el
              (: v (>> el 1)
                 (? (= v skipv) st
                    (! (= 0 (peep seen v 0))) st
                    (= 0 (getw (peep s 'fx ()) (+ (peep s 'lvo 0) v))) st
                    (: _ (pin seen v 1) _ (fbump s v)
                       (? (= (getw (peep s 'fx ()) (+ (peep s 'lvo 0) v)) dl) (link (+ 1 (cap st)) (cup st))
                          (link (cap st) (link el (cup st))))))))
           acc c)
   (ffind-seen fx seen idx) (? (= 0 (peep seen (>> (getw fx (+ 4 idx)) 1) 0)) (ffind-seen fx seen (- idx 1)) idx)
   ; a learnt tail literal is REDUNDANT (self-subsumed) when its var's reason clause is
   ; entirely covered by the learnt clause + level-0 facts -- dropping it keeps the
   ; clause implied. dropped literals STAY seen, so they still cover later checks.
   (fred? s seen el)
    (: v (>> el 1) rv (getw (peep s 'fx ()) (+ (peep s 'rso 0) v))
       (? (= rv 0) 0
          (all (\ l2 (: v2 (>> l2 1)
                        (|| (= v2 v) (|| (= 0 (getw (peep s 'fx ()) (+ (peep s 'lvo 0) v2)))
                                         (= 1 (peep seen v2 0))))))
               (fclits s (- rv 1)))))
   (flbd s lits)                                            ; the clause's GLUE: distinct decision levels among its lits
    (: t (tablet 0) _ (foldl (\ _ el (pin t (flvl s el) 1)) 0 lits) $t)
   (fbj-level s learnt) (foldl (\ m el (: lv (flvl s el) (? (> lv m) lv m))) 0 learnt)
   (fmax-lit s ls) (foldl (\ b el (? (> (flvl s el) (flvl s b)) el b)) (cap ls) (cup ls))
   (freorder s learnt)                                      ; learnt[1] must be the max-level tail literal
    (? (atom? (cup learnt)) learnt
       (: a0 (cap learnt) rest (cup learnt) mx (fmax-lit s rest) (link a0 (link mx (rem-lit mx rest)))))
   (fanalyze s confl)                                       ; -> (learnt-clause . backjump-level), learnt[0] asserting
    (: fx (peep s 'fx ()) dl (getw fx 2) seen (tablet 0)
       a0 (fabs s seen dl 0 (fclits s confl) (link 0 ()))
       res ((: (go counter learnt idx)
               (: ix (ffind-seen fx seen idx) np (getw fx (+ 4 ix)) v (>> np 1)
                  _ (pin seen v 0) cnt (- counter 1)
                  (? (= cnt 0) (link np learnt)
                     (: rv (getw fx (+ (peep s 'rso 0) v))
                        a (fabs s seen dl v (fclits s (- rv 1)) (link cnt learnt))
                        (go (cap a) (cup a) (- ix 1))))))
            (cap a0) (cup a0) (- (getw fx 0) 1))
       uip (cap res) learnt (filter (\ el (! (fred? s seen el))) (cup res))   ; minimize: drop self-subsumed tail lits
       learntc (link (^ uip 1) learnt)
       (link learntc (fbj-level s learnt)))
   (fbackjump s lvl)                                        ; pop + unassign every trail entry above level lvl
    (: fx (peep s 'fx ()) ph (peep s 'phase ()) lvo (peep s 'lvo 0) rso (peep s 'rso 0) vao (peep s 'vao 0)
       nt ((: (go t)
              (? (= t 0) 0
                 (: el (getw fx (+ 4 (- t 1))) v (>> el 1)
                    (? (> (getw fx (+ lvo v)) lvl)
                       (: m (getw fx (+ vao v))
                          _ (pin ph v (? (= 0 (& m 1)) 1 2))          ; save phase (1 = was positive)
                          _ (putw fx (+ vao v) 0) _ (putw fx (+ lvo v) 0) _ (putw fx (+ rso v) 0)
                          (go (- t 1)))
                       t))))
           (getw fx 0))
       _ (putw fx 0 nt) _ (putw fx 1 nt) (putw fx 2 lvl))
   ; --- VSIDS + Luby restarts + phase saving (lisp-side heuristics) ---------------
   (frescale s) (foldl (\ _ v (: a (peep s 'act ()) (pin a v (* (peep a v 0.0) 1e-100)))) 0 (rng 1 (+ (peep s 'nvars 0) 1)))
   (fdecay s) (: vi (* (peep s 'vinc 1.0) 1.05)
                 (? (> vi 1e100) (: _ (frescale s) (pin s 'vinc (* vi 1e-100))) (pin s 'vinc vi)))
   (fpick s)                                                ; highest-activity free var, 0 if none
    (: fx (peep s 'fx ()) vao (peep s 'vao 0) act (peep s 'act ()) nv (peep s 'nvars 0)
       ((: (go v best ba)
           (? (> v nv) best
              (: a (peep act v 0.0)
                 (? (&& (= 0 (getw fx (+ vao v))) (|| (= best 0) (> a ba))) (go (+ v 1) v a) (go (+ v 1) best ba)))))
        1 0 -1.0))
   (fnext-restart s) (: rn (+ 1 (peep s 'rnum 1)) _ (pin s 'rnum rn) _ (pin s 'nconf 0) _ (pin s 'climit (* (luby rn) 100)) 0)
   ; --- learnt-DB REDUCTION (at a level-0 restart, so no reason cid is live: absorb
   ; never reads a level-0 var's reason, and we zero those anyway). drop the worst-glue
   ; half of the learnt clauses (glue <= 3 is kept forever), drop anything level-0
   ; satisfied or retired, compact the survivors into a fresh arena (pour per slab),
   ; re-establish the two watches per clause vs the level-0 assignment, and rebuild
   ; every watch list. a clause down to ONE non-false literal is a permanent unit
   ; (enqueue it); all-false cannot arise (level-0 propagation ran to fixpoint).
   (fswap c i j) (? (= i j) 0 (: a (getw c i) b (getw c j) _ (putw c i b) (putw c j a)))
   (freduce s)
    (: fx (peep s 'fx ()) nv (peep s 'nvars 0) who (peep s 'who 0) ar (peep s 'ar ())
       ls (peep s 'learnts ())
       srt (sortby (\ a b (<= (cup a) (cup b))) (filter (\ p (> (cup p) 3)) ls))   ; ascending glue; the back half dies
       nk (// (tally srt) 2)
       dead (tablet 0)
       _ (foldl (\ i p (: _ (? (>= i nk) (pin dead (cap p) 1) 0) (+ i 1))) 0 srt)
       lt (tablet 0) _ (foldl (\ _ p (pin lt (cap p) (cup p))) 0 ls)               ; cid -> glue (the learnt set)
       _ ((: (zw i) (? (> i (+ 1 (* 2 nv))) 0 (: _ (putw fx (+ who i) 0) (zw (+ i 1))))) 0)   ; clear watch heads
       _ (pin s 'wnu 2)                                                            ; ... and nodes
       _ ((: (zr t) (? (>= t (getw fx 0)) 0                                        ; zero the (level-0) trail reasons
              (: v (>> (getw fx (+ 4 t)) 1) _ (putw fx (+ (peep s 'rso 0) v) 0) (zr (+ t 1))))) 0)
       na (cask (tally ar)) _ (pin s 'ar na)                                       ; survivors compact into na (fwatch sees it)
       end (peep s 'aru 0)
       res ((: (walk cid nu nls nc)                                                ; -> (nu nls nc): new aru / learnts / count
               (? (>= cid end) (L nu nls nc)
                  (: n (getw ar cid) nxt (+ cid (+ n 1))
                     lits (: (go j acc) (? (< j (+ cid 1)) acc (go (- j 1) (link (getw ar j) acc))) (go (+ cid n) ()))
                     (? (! (= 0 (peep dead cid 0))) (walk nxt nu nls nc)           ; reduced away
                        (< n 2) (walk nxt nu nls nc)                               ; retired unit
                        (any (\ el (= 1 (flv s el))) lits) (walk nxt nu nls nc)    ; level-0 satisfied: gone for good
                        (: nf (filter (\ el (! (= -1 (flv s el)))) lits)
                           (? (atom? nf) (scare 'freduce-allfalse cid)
                              (atom? (cup nf)) (: _ (fenq s (cap nf) 0) (walk nxt nu nls nc))   ; permanent unit
                              (: _ (pour na (* 8 nu) ar (* 8 cid) (* 8 (+ n 1)))   ; copy the slab
                                 l1 (cap nf) l2 (caup nf)
                                 p1 ((: (fnd j) (? (= (getw na j) l1) j (fnd (+ j 1)))) (+ nu 1))
                                 _ (fswap na (+ nu 1) p1)
                                 p2 ((: (fnd j) (? (= (getw na j) l2) j (fnd (+ j 1)))) (+ nu 2))
                                 _ (fswap na (+ nu 2) p2)
                                 _ (fwatch s nu (getw na (+ nu 1))) _ (fwatch s nu (getw na (+ nu 2)))
                                 g (peep lt cid ())
                                 (walk nxt (+ nu (+ n 1))
                                       (? (whole? g) (link (link nu g) nls) nls) (+ nc 1)))))))))
            2 2 () 0)
       _ (pin s 'aru (cap res)) _ (pin s 'learnts (caup res)) _ (pin s 'ncls (caup (cup res)))
       (pin s 'maxl (// (* (peep s 'maxl 2000) 13) 10)))                           ; the cap grows geometrically
   (fsearch s)                                              ; -> 'sat or 'unsat (s holds the model on SAT)
    (: fx (peep s 'fx ())
       ((: (loop _)
           (: confl (fpropagate s)
              (? (> confl -1)
                 (? (= 0 (getw fx 2)) 'unsat
                    (: res (fanalyze s confl) learnt (freorder s (cap res)) cid (fadd s learnt)
                       glue (flbd s learnt)                                       ; before the backjump unassigns the head
                       _ (fdecay s) _ (pin s 'nconf (+ 1 (peep s 'nconf 0)))
                       _ (fbackjump s (cup res))
                       _ (? (atom? (cup learnt)) 0
                            (: _ (fwatch s cid (cap learnt)) _ (fwatch s cid (caup learnt))
                               (pin s 'learnts (link (link cid glue) (peep s 'learnts ())))))
                       _ (fassign s (cap learnt) (+ cid 1)) (loop ())))
                 (&& (> (getw fx 2) 0) (>= (peep s 'nconf 0) (peep s 'climit 0)))
                    (: _ (fbackjump s 0) _ (fnext-restart s)
                       _ (? (> (tally (peep s 'learnts ())) (peep s 'maxl 2000)) (freduce s) 0)
                       (loop ()))
                 (: v (fpick s)
                    (? (= v 0) 'sat
                       (: ph (peep (peep s 'phase ()) v 0)
                          _ (putw fx 2 (+ 1 (getw fx 2)))
                          _ (fassign s (? (= ph 1) (* 2 v) (+ 1 (* 2 v))) 0) (loop ()))))))) ()))
   (fextract s nvars) (: fx (peep s 'fx ()) vao (peep s 'vao 0)
                         (map (\ v (link v (? (= 0 (& (getw fx (+ vao v)) 1)) 1 -1))) (rng 1 (+ nvars 1))))
   (fcdcl formula nvars)
    (: s (fmk formula nvars)
       (? (= 1 (peep s 'bad 0)) 'unsat
          (: r (fsearch s) (? (id? r 'unsat) 'unsat (fextract s nvars)))))
   (count-fcdcl formula nvars)                              ; #SAT by blocking clauses, on the flat engine
    ((: (go fm c) (: r (fcdcl fm nvars) (? (id? r 'unsat) c (go (link (block r) fm) (+ c 1))))) formula 0)
   (fdiff seed n m)                                         ; flat CDCL == the DPLL oracle (and models check)
    (: f (gen-formula seed n m) d (solve f n) c (fcdcl f n)
       dsat (! (id? d 'unsat)) csat (! (id? c 'unsat))
       (? (! (= dsat csat)) 0  (! csat) 1  (sat? c f)))
   (ffuzz k n m) (all (\ i (= 1 (fdiff (+ 1009 (* i 7919)) n m))) (jot k))
   (fboth f n)                                              ; kernel and twin agree exactly (same engine, two lanes)
    (: _ (pin fknob 0 1) a (fcdcl f n) _ (pin fknob 0 0) b (fcdcl f n)
       (? (id? a 'unsat) (id? b 'unsat) (&& (! (id? b 'unsat)) (sat? b f))))

 ; --- the gate: the flat layout answers exactly like the tablet solver + the oracle
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
    ; native kernel == interpreted twin, verdict for verdict (a no-op switch where the kernel can't build)
    (fboth (cyclic 14) 14)
    (fboth (php 4) (php-vars 4))
    ; pigeonhole PHP(5): UNSAT + resolution-hard (learning, restarts, arena growth end to end)
    (id? (fcdcl (php 5) (php-vars 5)) 'unsat)
    ; force the learnt-DB REDUCTION path hard (a tiny cap -> compaction every few restarts)
    ; and re-run the differential battery through it, both engines
    (: _ (pin fmaxl0 0 24)
       ok (&& (id? (fcdcl (php 5) (php-vars 5)) 'unsat)
              (&& (ffuzz 30 12 50) (fboth (php 4) (php-vars 4))))
       _ (pin fmaxl0 0 2000) ok))
 _ (say err (+ "sat/flat: ok -- flat-arena CDCL == DPLL on 150 fuzzed + PHP(5) + #SAT==Lucas"
               (? (lit? (fbcpk 8)) " (native BCP kernel live)\n" " (interpreted twin)\n"))))
