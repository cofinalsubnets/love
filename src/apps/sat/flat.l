; src/apps/sat/flat -- the CDCL solver over flat state. its hot loops (bcp, conf, dec and
; the BVA grow step fbvag) are x64 kernels assembled through src/love/holo/, offsets baked
; as immediates and cached per nv, installed through `nif`. the interpreted twins
; fbcp3/fconf3/fdec3/fbvag3 are their spec, deopt fallback and non-x64 engine; `fknob`
; forces them. in the module sat after sat.l, whose oracle and instances it reuses.
;
; a literal is encoded +v -> 2v, -v -> 2v+1; val[v] holds the true encoded literal (0 free).
; activities are integers; when vinc passes 2^24 all shift right 8. words are 8-byte
; slots, low 4 bytes live, so the kernels' 64-bit ld/st and the word accessors agree.
; fx layout (word offsets; nv = nvars):
;   w0 top  w1 qhead  w2 level  w3 nv  w4 aru  w5 wnu  w6 vinc  w7 kernel scratch
;   tro=8 trail | lvo lvl | rso rsn (0 none, else cid+1) | who watch heads (2nv+2,
;   by encoded lit) | vao val | aco activity | pho saved phase (0 never, 1 pos, 2 neg)
;   | seo seen scratch (conf clears it on entry; also reused as a level-mark set)
; a clause at arena offset cid is [size, lit0..], watches always slots cid+1/cid+2;
; a watch node at offset p is [cid, next] (0 = nil; words 0-1 of both arenas reserved).
; the conf caller pre-ensures arena room (aru+nv+3 words) and node room (wnu+4): the
; kernels never grow a cask.
(module 'sat
(:
   ; --- 8-byte word slots: src/love/mem.c's word nifs --------------------------------
   getw (cite 'guts 'peepw)
   putw (cite 'guts 'pinw)
   (enc l) (l < 0 ? (1 + 2 * -l) (2 * l))          ; signed literal -> encoded
   ; --- the layout, from nv (twins recompute these from fx w3) --------------------
   (lvo-of nv) (8 + nv + 1)
   (rso-of nv) (lvo-of nv + nv + 1)
   (who-of nv) (rso-of nv + nv + 1)
   (vao-of nv) (who-of nv + 2 + 2 * nv)
   (aco-of nv) (vao-of nv + nv + 1)
   (pho-of nv) (aco-of nv + nv + 1)
   (seo-of nv) (pho-of nv + nv + 1)
   ; --- the twin assign, self-contained (offsets from fx w3) ----------------------
   (fasg fx el rv)                                          ; set el true at the current level, reason rv (0 = decision)
    (: nv (getw fx 3) v (el >> 1) t (getw fx 0)
       (putw fx (vao-of nv + v) el,
        putw fx (lvo-of nv + v) (getw fx 2),
        putw fx (rso-of nv + v) rv,
        putw fx (8 + t) el,
        putw fx 0 (t + 1)))
   ; --- state access for the lisp driver (offsets cached in s) --------------------
   (flv s el) (getw (s 'fx) (peep s 'vao 0 + (el >> 1)) @ m
                 (? (m = 0) 0 (m = el) 1 -1))               ; 1 sat / -1 false / 0 free
   (flvl s el) (getw (s 'fx) (peep s 'lvo 0 + (el >> 1)))
   (fens s k need)                                          ; ensure cask s[k] holds >= need bytes (grow by doubling)
    (s k @ c
       (need <= #c ? 0
          (: n2 ((: (go m) (m >= need ? m (go (2 * m)))) (2 * #c))
             nu (cask n2) (pour nu 0 c 0 #c, pin s k nu, 0))))
   (fassign s el rv) (fasg (s 'fx) el rv)
   ; --- clause db (lisp side: initial load + reduction; aru/wnu live in fx) --------
   (fadd s lits)                                            ; append [size, lits..] to the arena; -> cid (word offset)
    (: n #lits fx (s 'fx) aru (getw fx 4)
       _ (fens s 'ar (8 * (aru + (n + 1))))
       ar (s 'ar)
       (putw ar aru n,
        foldl (j \ el \ (putw ar j el, j + 1)) (aru + 1) lits,
        putw fx 4 (aru + (n + 1)), aru))
   (fclits s cid)                                           ; the clause's encoded literals, as a list
    (: ar (s 'ar) n (getw ar cid)
       ((: (go j acc) (j < cid + 1 ? acc (go (j - 1) (getw ar j . acc)))) (cid + n) ()))
   (fwatch s cid el)                                        ; push a watch node [cid -> wh[el] list]
    (: fx (s 'fx) wnu (getw fx 5) _ (fens s 'wn (8 * (wnu + 2)))
       wn (s 'wn) who (peep s 'who 0)
       (putw wn wnu cid, putw wn (wnu + 1) (getw fx (who + el)),
        putw fx (who + el) wnu, putw fx 5 (wnu + 2)))
   (fenq s el rv)                                           ; level-0 fact: assign if free, flag bad if already false
    (flv s el @ m (? (m = 1) 0 (m = -1) (pin s 'bad 1) (fassign s el rv, 0)))
   (fload s c0)                                             ; a source clause (signed lits) into the db + watches
    (1 = taut? c0 ? 0
       (dedup-lits c0 @ c
          (? (atom? c) (pin s 'bad 1)
             (atom? >c) (fadd s (enc <c . ()) @ cid (fenq s (enc <c) (cid + 1)))
             (fadd s (map enc c) @ cid
                (fwatch s cid (enc <c), fwatch s cid (enc <>c))))))
   ; --- the interpreted bcp twin: (fbcp3 fx ar wn) -> conflict cid or -1 ----------
   (fbcp3 fx ar wn)
    (: nv (getw fx 3) who (who-of nv) vao (vao-of nv)
       lv (el \ (getw fx (vao + (el >> 1)) @ m (? (m = 0) 0 (m = el) 1 -1)))
       prop1 (f \                                           ; f just became false: re-examine wh[f]
                  ((: (go p prev)
                      (p = 0 ? -1
                         (getw wn p @ cid
                            (0 = getw ar cid ?                           ; tombstone (freduce): unlink, walk on
                               (getw wn (p + 1) @ nx
                                  (prev = 0 ? (putw fx (who + f) nx) (putw wn (prev + 1) nx),
                                   go nx prev))
                            (: _ (getw ar (cid + 1) = f ?                ; normalize: f sits at slot cid+2
                                 (getw ar (cid + 2) @ t (putw ar (cid + 2) f, putw ar (cid + 1) t)) 0)
                            oth (getw ar (cid + 1))
                            (1 = lv oth ? (go (getw wn (p + 1)) p)       ; satisfied by the other watch: keep
                               (: k ((: (sc j)                           ; scan the tail for a non-false literal
                                        (j >= cid + (1 + getw ar cid) ? 0
                                           (getw ar j @ e (? !(-1 = lv e) j (sc (j + 1))))))
                                     (cid + 3))
                                  (? !(k = 0)                         ; slide the watch f -> ar[k]
                                     (: e (getw ar k) nx (getw wn (p + 1))
                                        (putw ar k f, putw ar (cid + 2) e,
                                         prev = 0 ? (putw fx (who + f) nx) (putw wn (prev + 1) nx),
                                         putw wn (p + 1) (getw fx (who + e)), putw fx (who + e) p,
                                         go nx prev))
                                     (0 = lv oth) (fasg fx oth (cid + 1), go (getw wn (p + 1)) p)     ; unit: force oth
                                     cid))))))))                         ; oth false too: conflict
                   (getw fx (who + f)) 0))
       ((: (drain _)
           (getw fx 1 >= getw fx 0 ? -1
              (: p (getw fx (8 + getw fx 1)) _ (putw fx 1 (1 + getw fx 1))
                 confl (prop1 (p ^ 1))
                 (confl > -1 ? confl (drain ()))))) ()))
   ; --- the interpreted conflict twin: (fconf3 fx ar wn confl) --------------------
   ; the conf kernel's phases: 0 level 0 -> -1; 1 clear seen; 2 1-uip absorb + trail walk,
   ;   asserting lit at ar[cid0+1], tail at ar[cid0+2..]; 3 minimize (self-subsumption,
   ;   dropped lits stay seen), compact in place; 3b reason-side bump; 4 clear seen, glue
   ;   (level marks) + backjump level; 5 backjump, saving phases; 6 commit size/aru, max-level
   ;   lit to watch 2, watches; 7 assert learnt[0], reason cid0+1 -> (cid0<<6)|min(glue,63)
   (fconf3 fx ar wn confl)
    (: nv (getw fx 3) lvo (lvo-of nv) rso (rso-of nv) who (who-of nv)
       vao (vao-of nv) aco (aco-of nv) pho (pho-of nv) seo (seo-of nv)
       dl (getw fx 2)
       (dl = 0 ? -1
        (: cid0 (getw fx 4)
           czero (_ \ ((: (go v) (v > nv ? 0 (putw fx (seo + v) 0, go (v + 1)))) 0))
           _ (czero ())
           abs1 (\ cs skipv counter widx                    ; absorb clause at cs -> (counter . widx)
            ((: (go j c w)
                (j > cs + getw ar cs ? (c . w)
                   (: el (getw ar j) v (el >> 1)
                      (? (v = skipv) (go (j + 1) c w)
                         !(0 = getw fx (seo + v)) (go (j + 1) c w)
                         (0 = getw fx (lvo + v)) (go (j + 1) c w)
                         (putw fx (seo + v) 1,
                          putw fx (aco + v) (getw fx (aco + v) + getw fx 6), ; bump
                          getw fx (lvo + v) = dl ? (go (j + 1) (c + 1) w)
                            (putw ar w el, go (j + 1) c (w + 1)))))))
             (cs + 1) counter widx))
           a0 (abs1 confl 0 0 (cid0 + 2))
           r ((: (walk counter widx t)
                 (: np ((: (fs i) (0 = getw fx (seo + (getw fx (8 + i) >> 1)) ? (fs (i - 1)) i)) t)
                    el (getw fx (8 + np)) v (el >> 1)
                    _ (putw fx (seo + v) 0) c (counter - 1)
                    (c = 0 ? (el . widx)
                       (abs1 (getw fx (rso + v) - 1) v c widx @ a
                          (walk <a >a (np - 1))))))
              <a0 >a0 (getw fx 0 - 1))
           uip <r wend >r
           _ (putw ar (cid0 + 1) (uip ^ 1))
           wr ((: (mn rd wr)                                ; minimize, compacting kept lits down
                  (rd >= wend ? wr
                     (: el (getw ar rd) v (el >> 1) rv (getw fx (rso + v))
                        red (rv = 0 ? 0
                               ((: (ck j) (j > rv - 1 + getw ar (rv - 1) ? 1
                                             (getw ar j >> 1 @ v2
                                                (? (v2 = v) (ck (j + 1))
                                                   (0 = getw fx (lvo + v2)) (ck (j + 1))
                                                   (0 != getw fx (seo + v2)) (ck (j + 1))
                                                   0)))) (rv + 0)))     ; j starts at (rv-1)+1 = rv
                        (red @ 1 (mn (rd + 1) wr)
                         (putw ar wr el, mn (rd + 1) (wr + 1))))))
               (cid0 + 2) (cid0 + 2))
           ; reason-side bump: every unseen var in a learnt literal's reason gets act += vinc.
           ; seen still holds the analysis marks here (czero follows).
           _ ((: (rb j) (j >= wr ? 0
                  (: v (getw ar j >> 1) rv (getw fx (rso + v))
                     (rv = 0 ? 0
                        ((: (go2 k) (k > (rv - 1) + getw ar (rv - 1) ? 0
                             (getw ar k >> 1 @ v2
                                (0 = getw fx (seo + v2) ?
                                   (putw fx (aco + v2) (getw fx (aco + v2) + getw fx 6)) 0,
                                 go2 (k + 1))))) rv),
                      rb (j + 1))))) (cid0 + 1))
           _ (czero ())
           gb ((: (go j glue bj)                            ; glue + backjump level over the kept tail
                  (j >= wr ? (glue . bj)
                     (: L (getw fx (lvo + (getw ar j >> 1)))
                        bj2 (L > bj ? L bj)
                        (0 = getw fx (seo + L) ?
                           (putw fx (seo + L) 1, go (j + 1) (glue + 1) bj2)
                           (go (j + 1) glue bj2)))))
               (cid0 + 2) (putw fx (seo + dl) 1, 1) 0)
           glue <gb bj >gb
           nt ((: (go t)                                    ; backjump: pop above bj, save phase
                  (t = 0 ? 0
                     (: el (getw fx (8 + (t - 1))) v (el >> 1)
                        (getw fx (lvo + v) > bj ?
                           (putw fx (pho + v) (1 + (el & 1)),
                            putw fx (vao + v) 0, putw fx (lvo + v) 0, putw fx (rso + v) 0,
                            go (t - 1))
                           t))))
               (getw fx 0))
           _ (putw fx 0 nt) _ (putw fx 1 nt) _ (putw fx 2 bj)
           size (wr - (cid0 + 1))
           (putw ar cid0 size, putw fx 4 wr,
            size < 2 ? 0
              (: mx ((: (go j b) (j >= wr ? b                           ; reorder: max-level tail lit to slot 2
                            (go (j + 1) (getw fx (lvo + (getw ar j >> 1)) > getw fx (lvo + (getw ar b >> 1)) ? j b))))
                     (cid0 + 3) (cid0 + 2))
                 a (getw ar (cid0 + 2)) b (getw ar mx)
                 _ (putw ar (cid0 + 2) b) _ (putw ar mx a)
                 l0 (getw ar (cid0 + 1)) l1 (getw ar (cid0 + 2)) wnu (getw fx 5)
                 (putw wn wnu cid0, putw wn (wnu + 1) (getw fx (who + l0)), putw fx (who + l0) wnu,
                  putw wn (wnu + 2) cid0, putw wn (wnu + 3) (getw fx (who + l1)), putw fx (who + l1) (wnu + 2),
                  putw fx 5 (wnu + 4))),
            fasg fx (getw ar (cid0 + 1)) (cid0 + 1),
            cid0 << 6 | (glue > 63 ? 63 glue)))))
   ; --- the interpreted decide twin: (fdec3 fx) -> the decided var, 0 = SAT -------
   (fdec3 fx)
    (: nv (getw fx 3) vao (vao-of nv) aco (aco-of nv) pho (pho-of nv)
       v ((: (go v best ba)
             (v > nv ? best
                (getw fx (aco + v) @ a
                   (0 = getw fx (vao + v) && (best = 0 || a > ba) ?
                      (go (v + 1) v a) (go (v + 1) best ba)))))
          1 0 -1)
       (v = 0 ? 0
          (getw fx (pho + v) @ ph
             (putw fx 2 (1 + getw fx 2),
              fasg fx (ph = 1 ? (2 * v) (1 + 2 * v)) 0, v))))
   ; --- the native kernels. lvm ABI: g=rdi(r6) Ip=rsi(r5) Hp=rdx(r2) Sp=rcx(r1); params
   ; tagged on Sp[i]. the guards deopt before any push, so sp balances on every path.
   ; byte base of a cask = [[v+8]+16]. epilogue: tag acc, st Sp[0], Ip+16 -> lvm_ret.
   ; deopt: Ip <- the interpreted body, args still on Sp. r3/r11-r14 pushed after the guards.
   (guard-ir i bufk)                                        ; Sp[i] must be a cask
    [['ld 'r0 'r1 (8 * i)] '(test r0 1) '(br ne deopt)
      '(ld r7 r0 0) ['li 'r8 bufk] '(cmp r7 r8) '(br ne deopt)]
   (fixg-ir i)                                              ; Sp[i] must be a fixnum
    [['ld 'r0 'r1 (8 * i)] '(test r0 1) '(br eq deopt)]
   epi-ir '((shl r0 1) (or r0 r0 1) (st r1 0 r0) (add r5 r5 16) (ld r7 r5 0) (jmpr r7))
   deopt2-ir '((label deopt) (ld r7 r5 8) (lea r5 r7 16) (ld r7 r5 0) (jmpr r7))   ; arity>=2
   deopt1-ir '((label deopt) (ld r7 r5 8) (mov r5 r7) (ld r7 r5 0) (jmpr r7))      ; arity 1
   ; --- kernel 1: bcp -- (bcp fx ar wn). registers: r11=fx r12=ar r13=wn r14=f
   ; (callee-saved) r3=cid, r9=p r10=prev r0/r7/r8 scratch. ---------------------------
   (fbcp-ir nv)
    (: tro8 64 who8 (8 * who-of nv) vao8 (8 * vao-of nv)
       lvo8 (8 * lvo-of nv) rso8 (8 * rso-of nv) bufk (apof (cask 1))
       (guard-ir 0 bufk + guard-ir 1 bufk + guard-ir 2 bufk
       + '((push r3) (push r11) (push r12) (push r13) (push r14)
              (ld r0 r1 0)  (ld r0 r0 8) (lea r11 r0 16)
              (ld r0 r1 8)  (ld r0 r0 8) (lea r12 r0 16)
              (ld r0 r1 16) (ld r0 r0 8) (lea r13 r0 16))
       + ['(label drain)
              '(ld r0 r11 8) '(ld r7 r11 0) '(cmp r0 r7) '(br ge noconf)
              ['ldx 'r14 'r11 'r0 8 tro8]
              '(xor r14 r14 1)
              '(add r0 r0 1) '(st r11 8 r0)
              ['ldx 'r9 'r11 'r14 8 who8]
              '(li r10 0)
              '(label node)
              '(cmp r9 0) '(br eq drain)
              '(ldx r3 r13 r9 8 0)
              '(ldx r0 r12 r3 8 0) '(cmp r0 0) '(br ne live)    ; size 0 = tombstone (freduce):
              '(ldx r0 r13 r9 8 8)                              ; unlink the dead node, walk on
              '(cmp r10 0) '(br ne dprev)
              ['stx 'r11 'r14 8 who8 'r0] '(jmp dnext)
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
              ['ldx 'r0 'r11 'r0 8 vao8]
              '(cmp r0 r8) '(br eq keep)
              '(ldx r7 r12 r3 8 0) '(add r7 r7 r3) '(add r7 r7 1) '(push r7)
              '(add r0 r3 3)
              '(label scan)
              '(ld r7 sp 0) '(cmp r0 r7) '(br ge scanfail)
              '(ldx r7 r12 r0 8 0)
              '(mov r8 r7) '(sar r8 1)
              ['ldx 'r8 'r11 'r8 8 vao8]
              '(xor r7 r7 1)
              '(cmp r8 r7) '(br ne found)
              '(add r0 r0 1) '(jmp scan)
              '(label found)
              '(xor r7 r7 1)
              '(stx r12 r0 8 0 r14)
              '(stx r12 r3 8 16 r7)
              '(ldx r0 r13 r9 8 8)
              '(cmp r10 0) '(br ne fprev)
              ['stx 'r11 'r14 8 who8 'r0] '(jmp flink)
              '(label fprev)
              '(stx r13 r10 8 8 r0)
              '(label flink)
              ['ldx 'r8 'r11 'r7 8 who8]
              '(stx r13 r9 8 8 r8)
              ['stx 'r11 'r7 8 who8 'r9]
              '(mov r9 r0)
              '(add sp sp 8) '(jmp node)
              '(label scanfail)
              '(add sp sp 8)
              '(ldx r8 r12 r3 8 8)
              '(mov r0 r8) '(sar r0 1)
              ['ldx 'r7 'r11 'r0 8 vao8]
              '(cmp r7 0) '(br ne conflict)
              ['stx 'r11 'r0 8 vao8 'r8]                         ; unit: val[v] = oth
              '(ld r7 r11 16) ['stx 'r11 'r0 8 lvo8 'r7]
              '(add r7 r3 1)  ['stx 'r11 'r0 8 rso8 'r7]
              '(ld r7 r11 0)  ['stx 'r11 'r7 8 tro8 'r8]
              '(add r7 r7 1) '(st r11 0 r7)
              '(label keep)
              '(ldx r7 r13 r9 8 8) '(mov r10 r9) '(mov r9 r7) '(jmp node)
              '(label conflict)
              '(mov r0 r3) '(jmp ret)
              '(label noconf)
              '(li r0 -1)
              '(label ret)
              '(pop r14) '(pop r13) '(pop r12) '(pop r11) '(pop r3)]
            + epi-ir + deopt2-ir))
   ; --- kernel 2: the conflict handler -- (conf fx ar wn confl). ---------------------
   ; registers: r11=fx r12=ar r13=wn (pushed), r3 scratch (pushed), r14 counter/glue
   ; (pushed); r9 write index, r10 trail/read index, r0/r7/r8 scratch; fx w7 (byte 56)
   ; holds the current skip-var. the twin above is the spec, phase for phase.
   (cls-ir nv seo8)                                         ; clear the seen section (fresh labels)
    (: L1 (mint 0) L2 (mint 0)
       ['(li r0 0) '(li r8 0) ['label L1] ['cmp 'r0 nv] ['br 'gt L2]
         ['stx 'r11 'r0 8 seo8 'r8] '(add r0 r0 1) ['jmp L1] ['label L2]])
   (abs-ir lvo8 seo8 aco8)                                  ; absorb the clause at r7 (fresh labels);
    (: Ll (mint 0) Lt (mint 0) Ln (mint 0) Le (mint 0)      ; counter r14, write r9, skipv fx w7
       ['(ldx r0 r12 r7 8 0) '(add r0 r0 r7) '(add r0 r0 1) '(push r0)
         '(add r7 r7 1)
         ['label Ll] '(ld r0 sp 0) '(cmp r7 r0) ['br 'ge Le]
         '(ldx r3 r12 r7 8 0)
         '(mov r0 r3) '(sar r0 1)
         '(ld r8 r11 56) '(cmp r0 r8) ['br 'eq Ln]
         ['ldx 'r8 'r11 'r0 8 seo8] '(cmp r8 0) ['br 'ne Ln]
         ['ldx 'r8 'r11 'r0 8 lvo8] '(cmp r8 0) ['br 'eq Ln]
         '(li r8 1) ['stx 'r11 'r0 8 seo8 'r8]
         ['ldx 'r8 'r11 'r0 8 aco8] '(ld r3 r11 48) '(add r8 r8 r3) ['stx 'r11 'r0 8 aco8 'r8]
         ['ldx 'r8 'r11 'r0 8 lvo8] '(ld r3 r11 16) '(cmp r8 r3) ['br 'ne Lt]
         '(add r14 r14 1) ['jmp Ln]
         ['label Lt] '(ldx r3 r12 r7 8 0) '(stx r12 r9 8 0 r3) '(add r9 r9 1)
         ['label Ln] '(add r7 r7 1) ['jmp Ll]
         ['label Le] '(add sp sp 8)])
   (fconf-ir nv)
    (: tro8 64 lvo8 (8 * lvo-of nv) rso8 (8 * rso-of nv) who8 (8 * who-of nv)
       vao8 (8 * vao-of nv) aco8 (8 * aco-of nv) pho8 (8 * pho-of nv) seo8 (8 * seo-of nv)
       bufk (apof (cask 1))
       (guard-ir 0 bufk + guard-ir 1 bufk + guard-ir 2 bufk + fixg-ir 3
       + '((push r3) (push r11) (push r12) (push r13) (push r14)
              (ld r0 r1 0)  (ld r0 r0 8) (lea r11 r0 16)
              (ld r0 r1 8)  (ld r0 r0 8) (lea r12 r0 16)
              (ld r0 r1 16) (ld r0 r0 8) (lea r13 r0 16)
              (ld r7 r1 24) (sar r7 1)                            ; confl -> r7 (first absorb's clause)
              (ld r0 r11 16) (cmp r0 0) (br eq retm1))            ; level 0 -> -1
       + cls-ir nv seo8                                      ; phase 1: clear seen
       + '((li r14 0)                                          ; counter
              (ld r9 r11 32) (add r9 r9 2)                        ; widx = cid0+2
              (li r0 0) (st r11 56 r0))                           ; skipv = 0
       + abs-ir lvo8 seo8 aco8                               ; phase 2: absorb the conflict clause
       + ['(ld r10 r11 0) '(sub r10 r10 1)                    ; t = top-1
              '(label walk)
              ['ldx 'r0 'r11 'r10 8 tro8]                        ; np = trail[t]
              '(mov r3 r0) '(sar r3 1)
              ['ldx 'r8 'r11 'r3 8 seo8] '(cmp r8 0) '(br ne got)
              '(sub r10 r10 1) '(jmp walk)
              '(label got)
              '(li r8 0) ['stx 'r11 'r3 8 seo8 'r8]              ; seen[v] = 0
              '(sub r14 r14 1) '(cmp r14 0) '(br eq uip)
              ['ldx 'r7 'r11 'r3 8 rso8] '(sub r7 r7 1)          ; cs = rsn[v]-1
              '(st r11 56 r3)                                     ; skipv = v
              '(push r10)]
       + abs-ir lvo8 seo8 aco8                               ; absorb the reason clause
       + '((pop r10) (sub r10 r10 1) (jmp walk)
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
       + [['ldx 'r7 'r11 'r3 8 rso8]
              '(cmp r7 0) '(br eq mkeep)
              '(sub r7 r7 1)
              '(ldx r0 r12 r7 8 0) '(add r0 r0 r7) '(push r0)     ; inner lim (inclusive)
              '(add r7 r7 1)
              '(label mck) '(ld r0 sp 0) '(cmp r7 r0) '(br gt mred)
              '(ldx r0 r12 r7 8 0) '(sar r0 1)
              '(ld r8 r11 56) '(cmp r0 r8) '(br eq mcknx)
              ['ldx 'r8 'r11 'r0 8 lvo8] '(cmp r8 0) '(br eq mcknx)
              ['ldx 'r8 'r11 'r0 8 seo8] '(cmp r8 0) '(br ne mcknx)
              '(add sp sp 8) '(jmp mkeep)                         ; a fresh lit -> not redundant
              '(label mcknx) '(add r7 r7 1) '(jmp mck)
              '(label mred) '(add sp sp 8) '(jmp mnnext)
              '(label mkeep) '(ldx r0 r12 r10 8 0) '(stx r12 r9 8 0 r0) '(add r9 r9 1)
              '(label mnnext) '(add r10 r10 1) '(jmp mn)
              '(label mnend) '(add sp sp 8)]                      ; r9 = wend after compaction
       ; phase 3b: reason-side bump -- every unseen var in a learnt literal's reason
       ; gets act += vinc (seen still holds the analysis marks; w7 free as scratch).
       + ['(ld r10 r11 32) '(add r10 r10 1)                   ; j = cid0+1
              '(label rb) '(cmp r10 r9) '(br ge rbe)
              '(ldx r0 r12 r10 8 0) '(sar r0 1)                   ; v
              ['ldx 'r7 'r11 'r0 8 rso8]
              '(cmp r7 0) '(br eq rbn)
              '(sub r7 r7 1)
              '(ldx r0 r12 r7 8 0) '(add r0 r0 r7) '(st r11 56 r0)    ; w7 = last lit index
              '(add r7 r7 1)
              '(label rk) '(ld r0 r11 56) '(cmp r7 r0) '(br gt rbn)
              '(ldx r0 r12 r7 8 0) '(sar r0 1)                    ; v2
              ['ldx 'r8 'r11 'r0 8 seo8] '(cmp r8 0) '(br ne rknx)
              ['ldx 'r8 'r11 'r0 8 aco8] '(ld r3 r11 48) '(add r8 r8 r3)
              ['stx 'r11 'r0 8 aco8 'r8]
              '(label rknx) '(add r7 r7 1) '(jmp rk)
              '(label rbn) '(add r10 r10 1) '(jmp rb)
              '(label rbe)]
       + cls-ir nv seo8                                      ; phase 4: clear seen (-> level marks)
       + ['(ld r0 r11 16)                                     ; mark dl
              '(li r8 1) ['stx 'r11 'r0 8 seo8 'r8]
              '(li r14 1) '(li r10 0)                             ; glue=1, bj=0
              '(ld r7 r11 32) '(add r7 r7 2)
              '(label gb) '(cmp r7 r9) '(br ge gbe)
              '(ldx r0 r12 r7 8 0) '(sar r0 1)
              ['ldx 'r0 'r11 'r0 8 lvo8]                         ; L
              '(cmp r10 r0) '(br ge gb1) '(mov r10 r0)
              '(label gb1)
              ['ldx 'r8 'r11 'r0 8 seo8] '(cmp r8 0) '(br ne gb2)
              '(li r8 1) ['stx 'r11 'r0 8 seo8 'r8] '(add r14 r14 1)
              '(label gb2) '(add r7 r7 1) '(jmp gb)
              '(label gbe)
               ; phase 5: backjump to bj (r10)
              '(ld r7 r11 0)
              '(label bjl) '(cmp r7 0) '(br eq bje)
              '(mov r8 r7) '(sub r8 r8 1)
              ['ldx 'r0 'r11 'r8 8 tro8]                         ; el = trail[t-1]
              '(mov r3 r0) '(sar r3 1)
              ['ldx 'r8 'r11 'r3 8 lvo8] '(cmp r8 r10) '(br le bje)
              '(and r0 r0 1) '(add r0 r0 1) ['stx 'r11 'r3 8 pho8 'r0]
              '(li r0 0) ['stx 'r11 'r3 8 vao8 'r0] ['stx 'r11 'r3 8 lvo8 'r0] ['stx 'r11 'r3 8 rso8 'r0]
              '(sub r7 r7 1) '(jmp bjl)
              '(label bje) '(st r11 0 r7) '(st r11 8 r7) '(st r11 16 r10)
               ; phase 6: size, aru, reorder, watches
              '(ld r3 r11 32)                                     ; cid0
              '(mov r0 r9) '(sub r0 r0 r3) '(sub r0 r0 1)         ; size
              '(stx r12 r3 8 0 r0) '(st r11 32 r9)                ; ar[cid0]=size; aru=wend
              '(cmp r0 2) '(br lt assert)
              '(mov r10 r3) '(add r10 r10 2)                      ; reorder: argmax level
              '(ldx r0 r12 r10 8 0) '(sar r0 1) ['ldx 'r8 'r11 'r0 8 lvo8]
              '(mov r7 r10) '(add r7 r7 1)
              '(label ro) '(cmp r7 r9) '(br ge roe)
              '(ldx r0 r12 r7 8 0) '(sar r0 1) ['ldx 'r0 'r11 'r0 8 lvo8]
              '(cmp r0 r8) '(br le ro2) '(mov r8 r0) '(mov r10 r7)
              '(label ro2) '(add r7 r7 1) '(jmp ro)
              '(label roe)
              '(ldx r0 r12 r3 8 16) '(ldx r7 r12 r10 8 0) '(stx r12 r3 8 16 r7) '(stx r12 r10 8 0 r0)
              '(ldx r7 r12 r3 8 8) '(ldx r8 r12 r3 8 16)          ; l0, l1
              '(ld r10 r11 40)                                    ; wnu
              '(stx r13 r10 8 0 r3)
              ['ldx 'r0 'r11 'r7 8 who8] '(stx r13 r10 8 8 r0) ['stx 'r11 'r7 8 who8 'r10]
              '(add r10 r10 2)
              '(stx r13 r10 8 0 r3)
              ['ldx 'r0 'r11 'r8 8 who8] '(stx r13 r10 8 8 r0) ['stx 'r11 'r8 8 who8 'r10]
              '(add r10 r10 2) '(st r11 40 r10)
              '(label assert)                                     ; phase 7: assign learnt[0], reason cid0+1
              '(ldx r8 r12 r3 8 8) '(mov r0 r8) '(sar r0 1)
              ['stx 'r11 'r0 8 vao8 'r8]
              '(ld r7 r11 16) ['stx 'r11 'r0 8 lvo8 'r7]
              '(mov r7 r3) '(add r7 r7 1) ['stx 'r11 'r0 8 rso8 'r7]
              '(ld r7 r11 0) ['stx 'r11 'r7 8 tro8 'r8] '(add r7 r7 1) '(st r11 0 r7)
              '(mov r0 r3) '(shl r0 6)                            ; return (cid0<<6)|min(glue,63)
              '(cmp r14 63) '(br le pk) '(li r14 63)
              '(label pk) '(or r0 r0 r14) '(jmp fin)
              '(label retm1) '(li r0 -1)
              '(label fin)
              '(pop r14) '(pop r13) '(pop r12) '(pop r11) '(pop r3)]
            + epi-ir + deopt2-ir))
   ; --- kernel 3: decide -- (dec fx). caller-saved regs only, no pushes. -------------
   (fdec-ir nv)
    (: tro8 64 lvo8 (8 * lvo-of nv) rso8 (8 * rso-of nv) vao8 (8 * vao-of nv)
       aco8 (8 * aco-of nv) pho8 (8 * pho-of nv) bufk (apof (cask 1))
       (guard-ir 0 bufk
       + '((ld r9 r1 0) (ld r9 r9 8) (lea r9 r9 16)
              (li r7 0) (li r8 -1) (li r0 1))
       + ['(label dl) ['cmp 'r0 nv] '(br gt dle)
              ['ldx 'r3 'r9 'r0 8 vao8] '(cmp r3 0) '(br ne dn)
              ['ldx 'r3 'r9 'r0 8 aco8]
              '(cmp r7 0) '(br eq take)
              '(cmp r3 r8) '(br gt take) '(jmp dn)
              '(label take) '(mov r7 r0) '(mov r8 r3)
              '(label dn) '(add r0 r0 1) '(jmp dl)
              '(label dle) '(cmp r7 0) '(br eq ret0)
              '(ld r0 r9 16) '(add r0 r0 1) '(st r9 16 r0)        ; level++
              ['ldx 'r3 'r9 'r7 8 pho8]
              '(mov r0 r7) '(add r0 r0 r0)                        ; el = 2v (+1 unless phase 1)
              '(cmp r3 1) '(br eq pos) '(add r0 r0 1)
              '(label pos)
              ['stx 'r9 'r7 8 vao8 'r0]                          ; assign(el, 0)
              '(ld r3 r9 16) ['stx 'r9 'r7 8 lvo8 'r3]
              '(li r3 0) ['stx 'r9 'r7 8 rso8 'r3]
              '(ld r3 r9 0) ['stx 'r9 'r3 8 tro8 'r0] '(add r3 r3 1) '(st r9 0 r3)
              '(mov r0 r7) '(jmp dfin)
              '(label ret0) '(li r0 0)
              '(label dfin)]
            + epi-ir + deopt1-ir))
   ; --- kernel 4: the BVA grow step -- (fbvag bx ba bo bp), spec fbvag3. registers:
   ; r11=bx r12=ba r13=bo r14=bp (pushed), r10=l, r9 chain cursor, r0/r3/r7/r8 scratch;
   ; bx w14..w20 (bytes 112..160) spill cid/n/limi/limj/x/pnext/tail. other bytes:
   ; 24 pnu, 40 l, 48 chain-in, 56 mode, 64 lo, 72 hi, 88 best, 96 count, 104 chain-out.
   (bva-p1-ir pco8)                                         ; pass-1 match block (m=r0): count + running best
    (: An (mint 0) Ax (mint 0)
       [['ldx 'r3 'r11 'r0 8 pco8] '(add r3 r3 1) ['stx 'r11 'r0 8 pco8 'r3]
         '(ld r7 r11 96)
         '(cmp r3 r7) ['br 'gt An]
         '(cmp r3 r7) ['br 'ne Ax]
         '(ld r7 r11 88) '(cmp r0 r7) ['br 'ge Ax]          ; ties -> lowest key
         ['label An] '(st r11 88 r0) '(st r11 96 r3)
         ['label Ax]])
   (bva-p2-ir pco8)                                         ; pass-2 match block: reset on sight + collect best's cids
    ((mint 0) @ Ax
       ['(li r3 0) ['stx 'r11 'r0 8 pco8 'r3]
         '(ld r3 r11 88) '(cmp r0 r3) ['br 'ne Ax]
         '(ld r3 r11 24) '(ld r7 r11 112)
         '(stx r14 r3 8 0 r7)                               ; node = [cid, chain]
         '(ld r7 r11 104) '(stx r14 r3 8 8 r7)
         '(st r11 104 r3)
         '(add r3 r3 2) '(st r11 24 r3)
         ['label Ax]])
   (bva-walk-ir oco8 hho8 mlo8 act)                         ; the shared two-pass walk (fresh labels)
    (: Lo (mint 0) Lod (mint 0) Lk (mint 0) Lkn (mint 0) Lke (mint 0)
       Lq (mint 0) Lqd (mint 0) Lm (mint 0) Lms (mint 0) Lmb (mint 0) Lmx (mint 0)
       Lme (mint 0) Lm2 (mint 0) Lmm (mint 0)
       (['(ld r0 r11 48)                                    ; p = chain-in
         ['label Lo] '(cmp r0 0) ['br 'eq Lod]
         '(ldx r3 r14 r0 8 0) '(st r11 112 r3)              ; cid
         '(ldx r7 r14 r0 8 8) '(st r11 152 r7)              ; pnext
         '(ldx r7 r12 r3 8 0) '(st r11 120 r7)              ; n
         '(add r7 r7 r3) '(st r11 128 r7)                   ; limi = cid + n
         '(ld r0 r11 112) '(add r0 r0 1)                    ; k = fewest-occurrence lit, l aside
         '(li r8 2147483647) '(li r9 0)
         ['label Lk] '(ld r7 r11 128) '(cmp r0 r7) ['br 'gt Lke]
         '(ldx r3 r12 r0 8 0)
         '(cmp r3 r10) ['br 'eq Lkn]
         ['ldx 'r7 'r11 'r3 8 oco8]
         '(cmp r7 r8) ['br 'ge Lkn]
         '(mov r8 r7) '(mov r9 r3)
         ['label Lkn] '(add r0 r0 1) ['jmp Lk]
         ['label Lke]
         ['ldx 'r9 'r11 'r9 8 hho8]                         ; q = heads[k]
         ['label Lq] '(cmp r9 0) ['br 'eq Lqd]
         '(ldx r0 r13 r9 8 0)                               ; did
         '(ldx r7 r13 r9 8 8) '(mov r9 r7)                  ; advance early: fails jump straight to Lq
         '(ldx r7 r12 r0 8 0) '(ld r3 r11 120)
         '(cmp r7 r3) ['br 'ne Lq]                          ; size != n (covers tombstones)
         '(ld r3 r11 112) '(cmp r0 r3) ['br 'eq Lq]         ; did == cid
         '(ld r3 r11 120) '(add r3 r0 r3) '(st r11 136 r3)  ; limj = did + n
         '(li r3 0) '(st r11 144 r3)                        ; x = 0
         '(ld r7 r11 112) '(add r7 r7 1)                    ; i = cid+1
         '(add r8 r0 1)                                     ; j = did+1
         ['label Lm] '(ld r0 r11 128) '(cmp r7 r0) ['br 'gt Lme]
         '(ldx r0 r12 r7 8 0)                               ; ci
         '(cmp r0 r10) ['br 'eq Lms]                        ; ci == l -> i++
         '(ld r3 r11 136) '(cmp r8 r3) ['br 'gt Lq]         ; j exhausted with r left -> fail
         '(ldx r3 r12 r8 8 0)                               ; cj
         '(cmp r0 r3) ['br 'eq Lmb]
         '(cmp r3 r0) ['br 'lt Lmx]                         ; cj < ci -> the extra
         ['jmp Lq]                                          ; ci < cj -> r not a subset
         ['label Lmx] '(ld r0 r11 144) '(cmp r0 0) ['br 'ne Lq]      ; a second extra -> fail
         '(st r11 144 r3) '(add r8 r8 1) ['jmp Lm]
         ['label Lms] '(add r7 r7 1) ['jmp Lm]
         ['label Lmb] '(add r7 r7 1) '(add r8 r8 1) ['jmp Lm]
         ['label Lme]                                       ; i exhausted
         '(ld r0 r11 144) '(cmp r0 0) ['br 'ne Lm2]
         '(ld r3 r11 136) '(cmp r8 r3) ['br 'ne Lq]         ; x=0: exactly the last slot remains
         '(ldx r0 r12 r8 8 0) ['jmp Lmm]
         ['label Lm2] '(ld r3 r11 136) '(cmp r8 r3) ['br 'le Lq]    ; x>0: j must be past limj
         '(ld r0 r11 144)
         ['label Lmm]                                       ; m = r0: band + M_lit mark
         '(ld r3 r11 64) '(cmp r0 r3) ['br 'lt Lq]
         '(ld r3 r11 72) '(cmp r0 r3) ['br 'gt Lq]
         ['ldx 'r3 'r11 'r0 8 mlo8] '(cmp r3 0) ['br 'ne Lq]]
        + act
        + [['jmp Lq]
           ['label Lqd]
           '(ld r0 r11 152) ['jmp Lo]
           ['label Lod]]))
   (fbvag-ir NB2)
    (: s2 (2 * NB2 + 2)
       hho8 192 oco8 (8 * (24 + s2)) pco8 (8 * (24 + 3 * s2)) mlo8 (8 * (24 + 4 * s2))
       bufk (apof (cask 1))
       (guard-ir 0 bufk + guard-ir 1 bufk + guard-ir 2 bufk + guard-ir 3 bufk
       + '((push r3) (push r11) (push r12) (push r13) (push r14)
              (ld r0 r1 0)  (ld r0 r0 8) (lea r11 r0 16)
              (ld r0 r1 8)  (ld r0 r0 8) (lea r12 r0 16)
              (ld r0 r1 16) (ld r0 r0 8) (lea r13 r0 16)
              (ld r0 r1 24) (ld r0 r0 8) (lea r14 r0 16)
              (li r0 0) (st r11 88 r0) (st r11 96 r0) (st r11 104 r0) (st r11 160 r0)
              (ld r0 r11 56) (cmp r0 0) (br eq grow))
       ; build mode: chain occ[l]'s live in-band clauses, walk order (tail-append)
       + ['(ld r10 r11 40)
             ['ldx 'r9 'r11 'r10 8 hho8]                      ; q = heads[l]
             '(ld r8 r11 64) '(ld r10 r11 72)                ; lo / hi
             '(label bq) '(cmp r9 0) '(br eq bend)
             '(ldx r0 r13 r9 8 0) '(ldx r7 r13 r9 8 8) '(mov r9 r7)
             '(ldx r3 r12 r0 8 0)
             '(cmp r3 2) '(br lt bq)                         ; unit / tombstone
             '(st r11 112 r0)                                ; did
             '(add r3 r0 r3) '(add r7 r0 1)                  ; limj / j
             '(label bo) '(cmp r7 r3) '(br gt badd)
             '(ldx r0 r12 r7 8 0)
             '(cmp r0 r8) '(br lt bq)                        ; out of band -> skip the clause
             '(cmp r0 r10) '(br gt bq)
             '(add r7 r7 1) '(jmp bo)
             '(label badd)
             '(ld r0 r11 24) '(ld r7 r11 112)
             '(stx r14 r0 8 0 r7)
             '(li r3 0) '(stx r14 r0 8 8 r3)
             '(ld r7 r11 160) '(cmp r7 0) '(br ne btl)
             '(st r11 104 r0) '(jmp btl2)
             '(label btl) '(stx r14 r7 8 8 r0)
             '(label btl2) '(st r11 160 r0)
             '(add r0 r0 2) '(st r11 24 r0)
             '(ld r0 r11 96) '(add r0 r0 1) '(st r11 96 r0)
             '(jmp bq)
             '(label bend) '(ld r0 r11 96) '(jmp gret)
             '(label grow)
             '(ld r10 r11 40)]
       + bva-walk-ir oco8 hho8 mlo8 (bva-p1-ir pco8)
       + '((ld r0 r11 88) (cmp r0 0) (br eq gret))
       + bva-walk-ir oco8 hho8 mlo8 (bva-p2-ir pco8)
       + '((ld r0 r11 88)
              (label gret)
              (pop r14) (pop r13) (pop r12) (pop r11) (pop r3))
       + epi-ir + deopt2-ir))
   fkers {}        ; nv -> (bcp conf dec), one assemble per nvars
   fknob {0}       ; pin 1 to force the interpreted twins (the differential switch)
   fmaxl0 {2000}   ; the initial learnt-db cap
   frp0 {4}        ; rephase-wheel cadence in restarts (pin 0 = off)
   fcmp0 {1048576} ; arena-words threshold for the real compaction
   fcmpk {2}       ; ..and past it, the arena's multiple of its live words after the last one
   fcmpn {0}       ; compactions so far
   fru0 {400}      ; the luby restart unit (conflicts per luby-1 block)
   fst0 {10000}    ; the stable/focused mode budget in conflicts (x3/2 per switch)
   ; --- drat proof: a jug pinned into fdrat0 gets an UNSAT solve's refutation against the
   ; original formula: a rup line per learnt, a `d` per tombstoned learnt, BVA's
   ; extended-resolution lines (rat on the fresh var), then the empty clause.
   fdrat0 {0}                                               ; 0 off; a jug records the proof
   (fdlit el) (el >> 1 @ v (1 = el & 1 ? -v v))    ; encoded -> signed dimacs literal
   (fdsay j pre c)                                          ; one proof line: prefix, lits, the closing 0
    (say j pre,
     foldl (\ _ l (say j (show l), say j " ")) 0 c,
     say j "0\n")
   nifseam (cite 'glaze 'nif)                              ; main.c pulls `nif` off the book; the glaze keeps it
   (fnif ir fb ar)                                          ; assemble + install one kernel (fb = the twin)
    (: bs (peep (cite 'holo 'assemble 'x64 ir) 'bytes 0)
       c (cask bs)                                           ; the charlist lane fills in C
       (nifseam c fb ar))
   (fbcpk nv)                                               ; -> (bcp conf dec), or () when they can't build
    (love-arch != 'x64 ? ()
       (peep fkers nv () @ hit
          (two? hit ? hit
             (: ks [(fnif (fbcp-ir nv) fbcp3 3)
                     (fnif (fconf-ir nv) fconf3 4)
                     (fnif (fdec-ir nv) fdec3 1)]
                (pin fkers nv ks, ks)))))
   bvkers {}                                        ; nb -> (fbvag), the grow-step kernel, one assemble per bucket
   (fbvagk NB2)
    (love-arch != 'x64 ? ()
       (bvkers NB2 @ hit
          (two? hit ? hit
             ((fnif (fbvag-ir NB2) fbvag3 4 . ()) @ ks
                (pin bvkers NB2 ks, ks)))))
   (fmk formula nvars)                                      ; build the flat solver state
    ; nv is nvars rounded up to a power of 2, so the kernel cache survives BVA's var counts.
    ; phantom vars are sound: never watched, activity 0, so decided after every real var.
    (: s {} nv ((: (go k) (k >= nvars ? k (go (2 * k)))) 16)
       fx (cask (8 * (seo-of nv + (nv + 1))))
       _ (putw fx 3 nv, putw fx 4 2, putw fx 5 2, putw fx 6 256)
       _ (pins s 'nvars nv 'fx fx
          'lvo (lvo-of nv) 'rso (rso-of nv) 'who (who-of nv) 'vao (vao-of nv)
          'ar (cask 4096) 'wn (cask 4096)  ; words 0-1 of each reserved: 0 stays "none"
          'bad 0 'nconf 0 'rnum 1 'climit (peep fru0 () 400) 'rew 0
          'mode 0 'mconf 0 'mbudget (peep fst0 () 10000) 'sclimit 2000
          'btop 0 'bph (cask (8 * (nv + 1)))
          'learnts () 'nl 0 'maxl (peep fmaxl0 () 2000))
       ks (fbcpk nv)
       borrow (two? ks && 0 = peep fknob () 0)
       ((pins s 'bcp  (borrow ? <ks fbcp3)
                'conf (borrow ? <>ks fconf3)
                'dec  (borrow ? <>>ks fdec3)),
        foldl (\ _ c (fload s c)) 0 formula, s))
   ; --- the cold path: restarts, decay, learnt-db reduction (lisp side) -----------
   (fbackjump s lvl)                                        ; pop + unassign above lvl (restarts: lvl = 0)
    (: fx (s 'fx) nv (peep s 'nvars 0) lvo (peep s 'lvo 0) rso (peep s 'rso 0)
       vao (peep s 'vao 0) pho (pho-of nv)
       nt ((: (go t)
              (t = 0 ? 0
                 (: el (getw fx (8 + t - 1)) v (el >> 1)
                    (getw fx (lvo + v) > lvl ?
                       (putw fx (pho + v) (1 + (el & 1)),
                        putw fx (vao + v) 0, putw fx (lvo + v) 0, putw fx (rso + v) 0,
                          go (t - 1))
                       t))))
           (getw fx 0))
       (putw fx 0 nt, putw fx 1 nt, putw fx 2 lvl))
   (fdecay s)                                               ; integer VSIDS: vinc *= 21/20; rescale by >>8
    (: fx (s 'fx) vi (getw fx 6 * 21 // 20)
       (vi > 16777216 ?
          (: nv (peep s 'nvars 0) aco (aco-of nv)
             (((: (go v) (v > nv ? 0 (putw fx (aco + v) (getw fx (aco + v) >> 8), go (v + 1)))) 1),
              putw fx 6 (vi >> 8)))
          (putw fx 6 vi)))
   (fnext-restart s) (1 + peep s 'rnum 1 @ rn (pin s 'rnum rn, pin s 'nconf 0, pin s 'climit (luby rn * peep fru0 () 400), 0))
   (frephase s st)                                          ; randomize every saved phase; -> st'
    (: fx (s 'fx) nv (peep s 'nvars 0) pho (pho-of nv)
       ((: (go v st) (v > nv ? st
             (random st 2 @ p (putw fx (pho + v) (1 + <p), go (v + 1) >p))))
        1 st))
   (fbest s)                                                ; restore the best-trail phases (the deepest basin seen)
    (: fx (s 'fx) nv (peep s 'nvars 0) pho (pho-of nv) b (s 'bph)
       ((: (go v) (v > nv ? 0
             (getw b v @ p (p = 0 ? 0 (putw fx (pho + v) p), go (v + 1))))) 1))
   (fsnap s)                                                ; snapshot the assignment's polarities at a new deepest trail
    (: fx (s 'fx) nv (peep s 'nvars 0) vao (vao-of nv) b (s 'bph)
       ((: (go v) (v > nv ? 0
             (getw fx (vao + v) @ el
                (putw b v (? (el = 0) 0 (0 = el & 1) 1 2),
                 go (v + 1))))) 1))
   (finvert s)                                              ; flip every saved phase
    (: fx (s 'fx) nv (peep s 'nvars 0) pho (pho-of nv)
       ((: (go v) (v > nv ? 0
             (getw fx (pho + v) @ p (putw fx (pho + v) (p = 1 ? 2 1), go (v + 1))))) 1))
   ; learnt-db reduction at a level-0 restart, by tombstone: the worst-glue half (glue <= 3
   ; immortal) gets its size word zeroed; bcp unlinks a dead clause's watches lazily, checking
   ; size 0 before reading anything else. dead slabs stay until fcompact.
   (freduce s)
    (: fx (s 'fx) rso (peep s 'rso 0) ar (s 'ar)
       ls (s 'learnts)
       srt (sortby (a \ b \ >a <= >b) (filter (p \ >p > 3) ls))
       nk (#srt // 2)
       dead {}
       _ (foldl (i \ p \ (i >= nk ? (pin dead <p 1), i + 1)) 0 srt)
       _ ((: (zr t) (t >= getw fx 0 ? 0
              (getw fx (8 + t) >> 1 @ v (putw fx (rso + v) 0, zr (t + 1))))) 0)
       ; the tombstone stashes the slab's length at cid+1, so fcompact can walk past it
       j (peep fdrat0 () 0)
       _ (foldl (\ _ cid (getw ar cid @ n
                            (hot? j ? (fdsay j "d " (map fdlit (fclits s cid))) 0,
                             putw ar cid 0, putw ar (cid + 1) n, 0))) 0 (keys dead))
       nl (filter (p \ 0 = peep dead <p 0) ls)
       (pin s 'learnts nl, pin s 'nl #nl,
       ; the cap grows linearly: geometric growth lets the db and its watch lists balloon
        pin s 'maxl (peep s 'maxl 2000 + 500)))
   ; real compaction, at a level-0 restart once the arena top passes its mark: the larger of
   ; fcmp0 words and fcmpk times the live words the last one left. live clauses move to a
   ; fresh cask, watches rebuild from scratch, learnt cids remap; a satisfied clause drops,
   ; a unit enqueues as a fact.
   (fswap c i j) (i = j ? 0 (: a (getw c i) b (getw c j) (putw c i b, putw c j a)))
   (fcompact s)
    (: fx (s 'fx) nv (peep s 'nvars 0) who (peep s 'who 0) rso (peep s 'rso 0) ar (s 'ar)
       ls (s 'learnts)
       lt {} _ (foldl (\ _ p (pin lt <p >p)) 0 ls)
       _ ((: (zw i) (i > 1 + 2 * nv ? 0 (putw fx (who + i) 0, zw (i + 1)))) 0)
       _ (putw fx 5 2)
       ; zero the level-0 reasons: every cid moves, so a stale one would point into garbage
       _ ((: (zr t) (t >= getw fx 0 ? 0
              (getw fx (8 + t) >> 1 @ v (putw fx (rso + v) 0, zr (t + 1))))) 0)
       end (getw fx 4)
       lw ((: (cw cid acc)                                  ; live words (dead slabs skip via the stash)
              (cid >= end ? acc
                 (getw ar cid @ n
                    (n = 0 ? (cw (cid + (getw ar (cid + 1) + 1)) acc)
                       (cw (cid + (n + 1)) (acc + (n + 1))))))) 2 2)
       na (cask (8 * (lw + (nv + 8)))) _ (pin s 'ar na)
       res ((: (walk cid nu nls)
               (cid >= end ? (nu . nls)
                  (getw ar cid @ n
                     (n = 0 ? (walk (cid + (getw ar (cid + 1) + 1)) nu nls)
                        (: nxt (cid + (n + 1))
                           lits ((: (go j acc) (j < cid + 1 ? acc (go (j - 1) (getw ar j . acc)))) (cid + n) ())
                           (? (n < 2) (walk nxt nu nls)
                              (any (el \ 1 = flv s el) lits) (walk nxt nu nls)
                              (filter (el \ !(-1 = flv s el)) lits @ nf
                                 ; all-false can arise: a fact enqueued earlier in this walk
                                 ; is not yet propagated. a level-0 conflict, so UNSAT
                                 (? (atom? nf) (pin s 'bad 1, walk nxt nu nls)
                                    (atom? >nf) (fenq s <nf 0, walk nxt nu nls)
                                    (: _ (pour na (8 * nu) ar (8 * cid) (8 * (n + 1)))
                                       l1 <nf l2 <>nf
                                       p1 ((: (fnd j) (getw na j = l1 ? j (fnd (j + 1)))) (nu + 1))
                                       _ (fswap na (nu + 1) p1)
                                       p2 ((: (fnd j) (getw na j = l2 ? j (fnd (j + 1)))) (nu + 2))
                                       _ (fswap na (nu + 2) p2)
                                       _ (fwatch s nu (getw na (nu + 1))) _ (fwatch s nu (getw na (nu + 2)))
                                       g (peep lt cid ())
                                       (walk nxt (nu + (n + 1))
                                             (whole? g ? ((nu . g) . nls) nls)))))))))))
            2 2 ())
       (putw fx 4 <res, pin s 'learnts >res, pin s 'nl #>res,
        pin s 'cmpat (max (peep fcmp0 () 1048576) (peep fcmpk () 2 * <res)),
        pin fcmpn () (1 + peep fcmpn () 0)))
   ; --- the search loop: three kernel calls + lisp bookkeeping --------------------
   (fsearch s)                                              ; -> 'sat or 'unsat (s holds the model on SAT)
    (: fx (s 'fx) nv (peep s 'nvars 0)
       ((: (loop st)                                                ; st threads the rephase RNG (seeded: reproducible)
           (peep s 'bcp () fx (s 'ar) (s 'wn) @ confl
              (? (confl > -1)
                 (: _ (getw fx 0 > peep s 'btop 0 ?                 ; a new deepest trail: snapshot its
                         (pin s 'btop (getw fx 0), fsnap s)  ; polarities (the wheel's best spoke)
                         0)
                    _ (fens s 'ar (8 * (getw fx 4 + (nv + 3))))     ; room for the learnt clause
                    _ (fens s 'wn (8 * (getw fx 5 + 4)))            ; ... and its two watch nodes
                    r (peep s 'conf () fx (s 'ar) (s 'wn) confl)
                    (r = -1 ? 'unsat
                       (: cid (r >> 6) glue (r & 63)
                          (peep fdrat0 () 0 @ j                  ; the learnt is rup: log it
                             (hot? j ? (fdsay j "" (map fdlit (fclits s cid))) 0),
                           1 < getw (s 'ar) cid ?                   ; size >= 2: track for reduction
                             (pin s 'learnts ((cid . glue) . peep s 'learnts ()),
                              pin s 'nl (1 + peep s 'nl 0)) 0,
                           fdecay s, pin s 'nconf (1 + peep s 'nconf 0),
                           pin s 'mconf (1 + peep s 'mconf 0),
                           loop st))))
                 (getw fx 2 > 0 &&                                  ; a full db also forces the restart:
                  (peep s 'nconf 0 >= peep s 'climit 0 ||           ; reduction is only sound at level 0
                   peep s 'nl 0 > peep s 'maxl 2000))
                    (: _ (fbackjump s 0) _ (fnext-restart s)
                       _ (peep s 'nl 0 > peep s 'maxl 2000 ? (freduce s) 0)
                       _ (getw fx 4 > peep s 'cmpat (peep fcmp0 () 1048576) ? (fcompact s) 0)
                       ; focused/stable alternation on a conflict budget (fst0, x3/2 per
                       ; switch): focused restarts by luby, stable by a geometric climit
                       ; (2000, x6/5). the rephase wheel (random, best, invert, best) turns
                       ; only on entering stable, so long refutations keep saved phases.
                       ; frp0 0 turns it off.
                       st2 (peep s 'mconf 0 > peep s 'mbudget 0 ?
                              (peep s 'mode 0 @ m (pin s 'mode (1 - m), pin s 'mconf 0,
                                                   pin s 'mbudget (peep s 'mbudget 0 * 3 // 2),
                                                   m = 0 && peep frp0 () 0 > 0 ?
                                                     (: _ (pin s 'sclimit 2000)
                                                        w (peep s 'rew 0) (pin s 'rew (w + 1),
                                                        ; random first: at the first entry bph is close
                                                        ; to the current phases, so best would change little
                                                                           (? (0 = w % 4) (frephase s st)
                                                                              (1 = w % 4) (fbest s, st)
                                                                              (2 = w % 4) (finvert s, st)
                                                                              (fbest s, st))))
                                                     st))
                              st)
                       (1 = peep s 'mode 0 ?
                          (peep s 'sclimit 2000 @ sc
                             (pin s 'sclimit (sc * 6 // 5),
                              pin s 'climit sc))
                          0,
                        0 = peep s 'bad 0 ? (loop st2) 'unsat))       ; a compaction can prove UNSAT (all-false at level 0)
                 (s 'dec  fx @ v
                    (v = 0 ? 'sat (loop st)))))) (wheel 42)))
   (fextract s nvars) (: fx (s 'fx) vao (peep s 'vao 0)
                         (map (v \ (v . (0 = getw fx (vao + v) & 1 ? 1 -1))) (rng 1 (nvars + 1))))
   ; --- BVA: bounded variable addition (clause factoring), the preprocessing pass ---
   ; for a literal l, grow literals M_lit and clauses M_cls (all holding l) with (m | C\{l})
   ; in the formula for every pairing; a fresh x replaces those |M_lit|*|M_cls| clauses with
   ; (x | C\{l}) per clause and (-x | m) per literal. resolving on x recovers every original;
   ; a model extends by x := and of M_lit, and projects back by dropping vars > nvars.
   ; definitional vars are extended resolution, where pigeonhole has short refutations.
   fbva0 {1}                                                ; pin 0 to solve raw
   fbvar0 {8}                                               ; BVA round cap
   fbvac0 {1}                                               ; 1 = factor original structure only (no aux cascade)
   ; a literal is a key, signed s -> s + nb, so key order is signed order. nb = 12*bucket+256
   ; bounds every var a call can mint: a round starts under 4*nvars+64 and each try adds one.
   ; bx header (24 words): w0 aru, w1 onu (occ-node top), w2 nv, w3 pnu (match-node top),
   ; w4 empty clause seen; to the kernel: w5 l, w6 chain-in, w7 mode (1 build M_cls from
   ; occ[l], 0 one grow level), w8/w9 the key band (0/4nb pass all), w10 nb; from it: w11
   ; best key, w12 count, w13 chain-out; w14+ scratch. then five key-indexed sections of
   ; 2*nb+2 words: hho occ heads | oco occurrence counts, adds only | lco live counts |
   ; pco per-level match counts, zeroed by pass 2 | mlo M_lit marks.
   ; a clause is [size, key0..] in ba, sorted; a tombstone zeroes size and stashes the length
   ; at cid+1, and occ chains are never pruned. nodes are [cid, next] in bo/bp (0 nil).
   ; the kernel never grows a cask: the driver ensures bp room before each call.
   ; --- the grow-step twin -- (fbvag3 bx ba bo bp). build mode chains occ[l]'s live in-band
   ; clauses in walk order -> count. grow pass 1: per clause, k its fewest-occurrence lit
   ; beside l; each equal-size occ[k] partner's one key beyond C\{l} counts into pco under a
   ; running best (ties -> lowest key). pass 2 zeroes pco and front-pushes best's clauses.
   (fbvag3 bx2 ba2 bo2 bp2)
    (: NB2 (getw bx2 10) s2 (2 * NB2 + 2)
       hho 24 oco (hho + s2) pco (hho + 3 * s2) mlo (hho + 4 * s2)
       l (getw bx2 5) lo (getw bx2 8) hi (getw bx2 9)
       (putw bx2 11 0, putw bx2 12 0, putw bx2 13 0,
        1 = getw bx2 7 ?
          ((: (bld q cnt tail)                              ; build M_cls: live, in-band, walk order
              (q = 0 ? (putw bx2 12 cnt, cnt)
                 (: did (getw bo2 q) qn (getw bo2 (q + 1))
                    n2 (getw ba2 did)
                    ok (n2 >= 2 &&
                        (: (ofr j) (j > did + n2 || lo <= getw ba2 j <= hi && ofr (j + 1)))
                        (did + 1))
                    (!ok ? (bld qn cnt tail)
                       (getw bx2 3 @ p (putw bx2 3 (p + 2),
                                        (putw bp2 p did, putw bp2 (p + 1) 0,
                                         tail = 0 ? (putw bx2 13 p) (putw bp2 (tail + 1) p),
                                         bld qn (cnt + 1) p)))))))
           (getw bx2 (hho + l)) 0 0)
          (: (mrg cid did n)                                ; the one key of d beyond c\{l}, -1 if none
              ((: (go i j x)
                  (i > cid + n ?
                     (? (x > 0)         (j > did + n ? x -1)
                        (j = did + n) (getw ba2 j)
                        -1)
                     (getw ba2 i @ ci
                        (? (ci = l) (go (i + 1) j x)
                           (j > did + n) -1
                           (getw ba2 j @ cj
                              (? (ci = cj) (go (i + 1) (j + 1) x)
                                 (cj < ci) (x > 0 ? -1 (go i (j + 1) cj))
                                 -1))))))
               (cid + 1) (did + 1) 0)
             (bmk2 cid n)                                   ; fewest-occurrence lit of the clause, l aside
              ((: (go j k kc)
                  (j > cid + n ? k
                     (getw ba2 j @ e2
                        (e2 = l ? (go (j + 1) k kc)
                           (getw bx2 (oco + e2) @ ec
                              (ec < kc ? (go (j + 1) e2 ec) (go (j + 1) k kc)))))))
               (cid + 1) 0 2147483647)
             (walk p act)                                   ; the shared two-pass skeleton
              (p = 0 ? 0
                 (: cid (getw bp2 p) pn (getw bp2 (p + 1))
                    n (getw ba2 cid) k (bmk2 cid n)
                    (((: (ow q)
                         (q @ 0 0
                          (: did (getw bo2 q) qn (getw bo2 (q + 1))
                             ((? !(n = getw ba2 did) 0       ; (covers tombstones: size 0)
                                 (did = cid) 0
                                 (mrg cid did n @ m
                                    (? (m < 0) 0
                                       (m < lo || m > hi) 0
                                       (1 = getw bx2 (mlo + m)) 0
                                       (act cid m)))),
                              ow qn))))
                      (getw bx2 (hho + k))),
                     walk pn act)))
             _ (walk (getw bx2 6)
                 (cid \ m \ (: c2 (1 + getw bx2 (pco + m))
                               _ (putw bx2 (pco + m) c2)
                               bb (getw bx2 12)
                               (c2 > bb || c2 = bb && m < getw bx2 11 ?
                                  (putw bx2 11 m, putw bx2 12 c2) 0))))
             bk (getw bx2 11)
             (bk = 0 ? 0
                (walk (getw bx2 6)
                  (cid \ m \ (putw bx2 (pco + m) 0,
                              (? !(m = bk) 0
                                 (getw bx2 3 @ p (putw bx2 3 (p + 2),
                                                  putw bp2 p cid, putw bp2 (p + 1) (getw bx2 13),
                                                  putw bx2 13 p))))),
                 bk)))))
   (fbva formula nvars)                                     ; -> (formula2 . nvars2), equisatisfiable
    (: NB (12 * (: (bkt k) (k >= nvars ? k (bkt (2 * k)))) 16 + 256)
       s2 (2 * NB + 2)
       HHO 24  OCO (HHO + s2)  LCO (OCO + s2)  PCO (LCO + s2)  MLO (PCO + s2)
       fo (peep fbvac0 () 0)
       LO (1 = fo ? (NB - nvars) 0)                       ; the original-variable key band
       HI (1 = fo ? (NB + nvars) (4 * NB))                ; (sentinels: everything passes)
       bx (cask (8 * (MLO + s2)))
       b {'ba (cask 8192) 'bo (cask 8192) 'bp (cask 4096)}
       _ (putw bx 0 2, putw bx 1 2, putw bx 2 nvars, putw bx 3 2,
          putw bx 8 LO, putw bx 9 HI, putw bx 10 NB)
       ks (fbvagk NB)
       gstep (two? ks && 0 = peep fknob () 0 ? <ks fbvag3)
       (bcl ar cid)                                         ; the clause back out, sorted signed lits
        (getw ar cid @ n
           ((: (go j acc) (j = cid ? acc (go (j - 1) ((getw ar j - NB) . acc)))) (cid + n) ()))
       (feq e n)                                            ; the live cid holding exactly keys e (size n), or ()
        (: ar (b 'ba) bo (b 'bo)
           k (foldl (a \ el \ (getw bx (OCO + el) < getw bx (OCO + a) ? el a)) <e >e)
           (eqr j e2) (? (atom? e2) 1 (getw ar j != <e2) 0 (eqr (j + 1) >e2))
           ((: (go p) (p @ 0 ()
                       (getw bo p @ cid
                          (n = getw ar cid && 1 = eqr (cid + 1) e ? cid (go (getw bo (p + 1)))))))
            (getw bx (HHO + k))))
       (addc c0)                                            ; canon + dedupe + lay + index; drops tautologies
        (sort (dedup-lits c0) @ c
           (? (1 = taut? c) 0
              (atom? c) (getw bx 4 @ 0 (putw bx 4 1, 1) 0)     ; the empty clause rides a flag
              (: e (map (+ NB) c) n #e
                 (whole? (feq e n) ? 0
                    (: _ (fens b 'ba (8 * (getw bx 0 + (n + 1))))
                       ar (b 'ba ) cid (getw bx 0)
                       (putw ar cid n,
                        foldl (j \ el \ (putw ar j el, j + 1)) (cid + 1) e,
                        putw bx 0 (cid + (n + 1)),
                        each e (el \ (fens b 'bo (8 * (getw bx 1 + 2)),
                         : bo (b 'bo) p (getw bx 1)
                         (putw bo p cid, putw bo (p + 1) (getw bx (HHO + el)),
                          putw bx (HHO + el) p,    putw bx 1 (p + 2),
                          putw bx (OCO + el) (1 + getw bx (OCO + el))))),
                        n >= 2 ? (each e (el \ putw bx (LCO + el) (1 + getw bx (LCO + el)))),
                        1))))))
       (delc cid)
        (: ar (b 'ba) n (getw ar cid)
           (n = 0 ? 0
              (n < 2 ? 0                                ; units were never counted
                 ((: (dr j) (j > cid + n ? 0
                       (getw ar j @ e2
                          (putw bx (LCO + e2) (getw bx (LCO + e2) - 1), dr (j + 1)))))
                  (cid + 1)),
               putw ar cid 0, putw ar (cid + 1) n, 1)))
       (lcnt el) (getw bx (LCO + el))                       ; live (size >= 2) clauses holding el
       (try l)                                              ; one greedy factoring attempt at key l -> 1 if applied
        (: pnu0 (getw bx 3)                                 ; bp is per-try scratch: top restored on every exit
           _ (putw bx 5 l)
           _ (fens b 'bp (8 * (pnu0 + 2 * getw bx (OCO + l))))
           _ (putw bx 7 1)
           n0 (l < LO || l > HI ? 0                     ; an out-of-band l factors nothing
               (gstep bx (b 'ba) (b 'bo) (b 'bp)))
           (n0 < 4 ? (putw bx 3 pnu0, 0)
              (: _ (putw bx (MLO + l) 1)
                 g ((: (grow mlit len chain red)            ; extend M_lit while the reduction strictly grows
                       (: _ (putw bx 6 chain) _ (putw bx 7 0)
                          _ (fens b 'bp (8 * (getw bx 3 + 2 * len)))
                          bk (gstep bx (b 'ba) (b 'bo) (b 'bp))
                          (bk = 0 ? (mlit . chain)
                             (: nc (getw bx 12) nl (1 + tally mlit)
                                red2 (nl * nc - (nl + nc))
                                (red2 > red ?                     ; max count; ties -> lowest literal
                                   (putw bx (MLO + bk) 1, ; (symmetric instances: groups stay contiguous)
                                    grow (bk . mlit) nc (getw bx 13) red2)
                                   (mlit . chain))))))
                    (l . ()) n0 (getw bx 13) -1)
                 mlit <g
                 bp2 (b 'bp)
                 mcls ((: (go p) (p = 0 ? () (getw bp2 p . go (getw bp2 (p + 1))))) >g)
                 _ (foldl (\ _ m (putw bx (MLO + m) 0, 0)) 0 mlit)
                 _ (putw bx 3 pnu0)
                 ar (b 'ba)
                 nl #mlit ncl #mcls
                 (nl * ncl - (nl + ncl) < 1 ? 0             ; apply only when it strictly shrinks the formula
                    (: x (1 + getw bx 2) _ (putw bx 2 x)
                       ml (map (m \ m - NB) mlit)         ; signed, most-recent first (l last)
                       rs (map (cid \ rem-lit (l - NB) (bcl ar cid)) mcls)
                       ; the proof lines, in rat-checkable order: the definitions
                       ; (-x m) while no clause carries x (blocked on -x), then the
                       ; x-clauses (RAT on x: every resolvent is an original (m r),
                       ; still present, or a tautology), then the originals deleted
                       (peep fdrat0 () 0 @ j
                          (hot? j ?
                             (foldl (\ _ m (fdsay j "" [-x m], 0)) 0 ml,
                              fdsay j "" (x . map (m \ -m) ml),
                              foldl (\ _ r (fdsay j "" (x . r), 0)) 0 rs,
                              foldl (\ _ m (foldl (\ _ r (fdsay j "d " (m . r), 0)) 0 rs)) 0 ml)
                             0),
                        foldl (\ _ m (foldl (\ _ r
                       (: k (sort (m . r)) e2 (map (s \ s + NB) k)
                          did (feq e2 #e2)
                          (whole? did ? (delc did) (scare 'bva-miss k))))
                     0 rs, 0)) 0 ml,
                        foldl (\ _ r (addc (x . r), 0)) 0 rs,
                        foldl (\ _ m (addc (-x . (m . ())), 0)) 0 ml,
                        addc (x . map (m \ -m) ml),         ; x <- and(m): a complete definition,
                        1))))))                                    ; so x propagates, never decided freely
       _ (foldl (\ _ c (addc c, 0)) 0 formula)
       _ ((: (round r)                                      ; sweep most-occurring literals first; stop on
             (: nv2 (getw bx 2)                             ; a quiet round, under nvars/16 new vars in all,
                ls (sortby (a2 \ b2 \ (<a2 = <b2 ? (>a2 <= >b2) (<a2 > <b2)))   ; the round cap or the var bound
                           ((: (go el acc)
                               (el > NB + nv2 ? acc
                                  (lcnt el @ c
                                     (go (el + 1) (c >= 4 ? ((c . (el - NB)) . acc) acc)))))
                            (NB - nv2) ()))
                ch (foldl (a2 \ p \ a2 + try (>p + NB)) 0 ls)
                (ch > 0 &&
                 16 * (getw bx 2 - nvars) > nvars &&
                 r < peep fbvar0 () 8 && getw bx 2 < 4 * nvars + 64 ?
                   (round (r + 1)) 0)))
           0)
       ar (b 'ba) end (getw bx 0)
       out ((: (walk cid acc)
               (cid >= end ? (rev acc)
                  (getw ar cid @ n
                     (n = 0 ? (walk (cid + (getw ar (cid + 1) + 1)) acc)
                        (walk (cid + (n + 1)) (bcl ar cid . acc))))))
            2 ())
       ((1 = getw bx 4 ? (() . out) out) . getw bx 2))
   (fcdcl formula nvars)
    ; the bva ladder: re-run on its own output, the last pass's aux vars counting as original,
    ; while a pass adds over nvars/16 vars, at most 3 passes. models project by the original nvars.
    (: p (peep fbva0 () 1 @ 0 (formula . nvars)
          ((: (go p k) (fbva <p >p @ p2
                          (16 * (>p2 - >p) <= >p || k >= 3 ? p2 (go p2 (k + 1)))))
           (formula . nvars) 1))
       s (fmk <p >p)
       r (peep s 'bad 0 @ 1 'unsat
          (fsearch s @ r (r @ 'unsat 'unsat (fextract s nvars))))
       j (peep fdrat0 () 0)                                  ; cap an UNSAT proof with the empty clause
       (hot? j && r = 'unsat ? (fdsay j "" ()) 0,
        r))
   (count-fcdcl formula nvars)                              ; #SAT by blocking clauses, on the flat engine
    ((: (go fm c) (fcdcl fm nvars @ r (r = 'unsat ? c (go (block r . fm) (c + 1))))) formula 0)
   (fdiff seed n m)                                         ; flat CDCL == the DPLL oracle (and models check)
    (: f (gen-formula seed n m) d (solve f n) c (fcdcl f n)
       dsat (d != 'unsat) csat (c != 'unsat)
       (? (dsat != csat) 0  !csat 1  (sat? c f)))
   (ffuzz k n m) (all (i \ 1 = fdiff (1009 + i * 7919) n m) ^k)
   (fboth f n)                                              ; kernels and twins agree, verdict for verdict
    (: _ (pin fknob () 1) a (fcdcl f n) _ (pin fknob () 0) b (fcdcl f n)
       (a = 'unsat ? (b = 'unsat) (b != 'unsat && sat? b f)))

   (fbvaboth f n)                                           ; the BVA transform itself, kernel vs twin:
    (: _ (pin fknob () 1) a (fbva f n)                      ; a wrong transform can still leave
       _ (pin fknob () 0) b (fbva f n) (a = b))              ; the verdict right

   ; --- a drat checker, independent of the emitter: rup, or rat on the first literal, by
   ; naive O(lines * db) unit propagation, so for small refutations only.
   (fd-parse txt)                                           ; drat text -> steps (tag . lits), tag 1 = delete
    (#txt @ n
       ((: (go i tag num sgn lits steps)
           (i >= n ? (rev steps)
              (txt i @ ch
                 (? (ch = 100) (go (i + 1) 1 0 0 lits steps)
                    (ch = 45) (go (i + 1) tag 0 -1 lits steps)
                    (48 <= ch <= 57)
                     (go (i + 1) tag (10 * num + ch - 48) (sgn = 0 ? 1 sgn) lits steps)
                    (sgn = 0) (go (i + 1) tag 0 0 lits steps)
                    (num * sgn @ v
                       (v = 0 ? (go (i + 1) 0 0 0 () ((tag . rev lits) . steps))
                          (go (i + 1) tag 0 0 (v . lits) steps)))))))
        0 0 0 0 () ()))
   (fd-up db asg)                                           ; propagate units over asg; -> 1 conflict / 0 fixpoint
    ((: (pass rest ch)
        (atom? rest ? (ch @ 1 (pass db 0) 0)
           (: r ((: (scan c sat un)
                    (atom? c ? (sat @ 1 'sat (atom? un ? 'conf un))
                       (<c @ l
                          (? (1 = peep asg l 0) (scan >c 1 un)
                             (1 = peep asg (neg l) 0) (scan >c sat un)
                             (scan >c sat (l . un))))))
                 <rest 0 ())
              (? (r = 'conf) 1
                 (r = 'sat) (pass >rest ch)
                 (atom? >r) (pin asg <r 1, pass >rest 1)
                 (pass >rest ch)))))
     db 0)
   (fd-rup? db c)                                           ; does the negation propagate to a conflict?
    (fd-up db (foldl (a \ l \ pin a (neg l) 1) {} c))
   (fd-rat? db c)                                           ; rat on <c: every resolvent taut or rup
    (atom? c ? 0
       (<c @ p
          (all (d \ (elem (neg p) d ?
                       (>c + rem-lit (neg p) d @ rv
                          (taut? rv @ 1 1 (fd-rup? db rv)))
                       1))
               db)))
   (fd-del db c)                                            ; drop one clause equal as a set
    (sort c @ k
       ((: (go d) (? (atom? d) ()
                     (sort <d = k) >d
                     (<d . go >d))) db))
   (fd-check f proof)                                       ; 1 iff every step checks and one derives ()
    ((: (go db ps)
        (atom? ps ? 0
           (: st <ps c >st
              (1 = <st ? (go (fd-del db c) >ps)
                 (1 = fd-rup? db c || fd-rat? db c @ ok
                    (? !ok 0
                       (atom? c) 1
                       (go (c . db) >ps)))))))
     (map dedup-lits f) proof))
) ; module sat
