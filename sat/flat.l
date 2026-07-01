; sat/flat -- the CDCL solver again, over FLAT state: every hot structure lives in a
; cask (bytes; 4-byte little-endian words via getw/putw), laid out exactly as a native
; propagation kernel wants it (asm/ ldx/stx at scale 4). This file is the LAYOUT's
; reference implementation: interpreted it is SLOWER than sat.l's tablet solver (a word
; access is four byte nifs), but it proves the arena semantics differentially against
; the same oracles, and the native kernel then diffs against IT, word for word.
; Run AFTER sat.l (it reuses the leaked oracle + instances):  cat sat/sat.l sat/flat.l | ai
;
; the layout. a literal is ENCODED: +v -> 2v, -v -> 2v+1 (so neg = xor 1, var = >>1).
; casks in the state map s:
;   'hd    3 words: 0 top, 1 qhead, 2 level        (the scalars the kernel mutates)
;   'val   1 byte per var: 0 free, 1 true, 2 false (lit el sat iff val = 1+(el&1))
;   'phase 1 byte per var: last value held (0 = never assigned -> decide negative)
;   'lvl / 'rsn / 'trail  1 word per var: decision level, reason (0 none, else cid+1),
;          trail slot (encoded lits, dense from 0)
;   'ar    the clause arena, growable: a clause at word offset cid is [size, lit0..];
;          the two WATCHED literals are always slots cid+1 and cid+2 (slides swap in place)
;   'wn    watch nodes, growable: node at offset p is [cid, next] (0 = nil; word 0-1 reserved)
;   'wh    1 word per encoded literal: head of that literal's watch list
; lisp-side (tablets/scalars, the heuristics the kernel never touches): 'act 'vinc
; 'nconf 'rnum 'climit 'aru 'wnu 'ncls 'bad.
(:
   ; --- words in a cask: 4-byte little-endian at word index i --------------------
   (getw c i) (: b (* 4 i) (| (peep c b 0)
                              (| (<< (peep c (+ b 1) 0) 8)
                                 (| (<< (peep c (+ b 2) 0) 16) (<< (peep c (+ b 3) 0) 24)))))
   (putw c i v) (: b (* 4 i)
                   _ (pin c b (& v 255)) _ (pin c (+ b 1) (& (>> v 8) 255))
                   _ (pin c (+ b 2) (& (>> v 16) 255)) (pin c (+ b 3) (& (>> v 24) 255)))
   (enc l) (? (< l 0) (+ 1 (* 2 (- 0 l))) (* 2 l))          ; signed literal -> encoded
   ; --- state access -------------------------------------------------------------
   (flv s el) (: m (peep (peep s 'val ()) (>> el 1) 0)      ; 1 sat / -1 false / 0 free
                 (? (= m 0) 0 (= m (+ 1 (& el 1))) 1 -1))
   (flvl s el) (getw (peep s 'lvl ()) (>> el 1))            ; decision level of el's var
   (fens s k need)                                          ; ensure cask s[k] holds >= need bytes (grow by doubling)
    (: c (peep s k ())
       (? (<= need (tally c)) 0
          (: n2 ((: (go m) (? (>= m need) m (go (* 2 m)))) (* 2 (tally c)))
             nu (cask n2) _ (pour nu 0 c 0 (tally c)) _ (pin s k nu) 0)))
   (fassign s el rv)                                        ; set el TRUE at the current level, reason rv (0 = decision)
    (: v (>> el 1) hd (peep s 'hd ()) t (getw hd 0)
       _ (pin (peep s 'val ()) v (+ 1 (& el 1)))
       _ (putw (peep s 'lvl ()) v (getw hd 2))
       _ (putw (peep s 'rsn ()) v rv)
       _ (putw (peep s 'trail ()) t el)
       (putw hd 0 (+ t 1)))
   ; --- clause DB ----------------------------------------------------------------
   (fadd s lits)                                            ; append [size, lits..] to the arena; -> cid (word offset)
    (: n (tally lits) aru (peep s 'aru 0)
       _ (fens s 'ar (* 4 (+ aru (+ n 1))))
       ar (peep s 'ar ())
       _ (putw ar aru n)
       _ (foldl (\ j el (: _ (putw ar j el) (+ j 1))) (+ aru 1) lits)
       _ (pin s 'aru (+ aru (+ n 1))) _ (pin s 'ncls (+ 1 (peep s 'ncls 0))) aru)
   (fclits s cid)                                           ; the clause's encoded literals, as a list
    (: ar (peep s 'ar ()) n (getw ar cid)
       ((: (go j acc) (? (< j (+ cid 1)) acc (go (- j 1) (link (getw ar j) acc)))) (+ cid n) ()))
   (fwatch s cid el)                                        ; push a watch node [cid -> wh[el] list]
    (: wnu (peep s 'wnu 0) _ (fens s 'wn (* 4 (+ wnu 2)))
       wn (peep s 'wn ()) wh (peep s 'wh ())
       _ (putw wn wnu cid) _ (putw wn (+ wnu 1) (getw wh el))
       _ (putw wh el wnu) (pin s 'wnu (+ wnu 2)))
   (fenq s el rv)                                           ; level-0 fact: assign if free, flag bad if already false
    (: m (flv s el) (? (= m 1) 0 (= m -1) (pin s 'bad 1) (: _ (fassign s el rv) 0)))
   (fload s c0)                                             ; a source clause (signed lits) into the DB + watches
    (? (= 1 (taut? c0)) 0
       (: c (dedup-lits c0)
          (? (atom? c) (pin s 'bad 1)
             (atom? (cup c)) (: cid (fadd s (link (enc (cap c)) ())) (fenq s (enc (cap c)) (+ cid 1)))
             (: cid (fadd s (map enc c))
                _ (fwatch s cid (enc (cap c))) (fwatch s cid (enc (caup c)))))))
   (fmk formula nvars)                                      ; build the flat solver state
    (: s (tablet 0) nb (* 4 (+ nvars 1))
       _ (pin s 'nvars nvars) _ (pin s 'hd (cask 12))
       _ (pin s 'val (cask (+ nvars 1))) _ (pin s 'phase (cask (+ nvars 1)))
       _ (pin s 'lvl (cask nb)) _ (pin s 'rsn (cask nb)) _ (pin s 'trail (cask nb))
       _ (pin s 'wh (cask (* 4 (+ 2 (* 2 nvars)))))
       _ (pin s 'ar (cask 4096)) _ (pin s 'aru 2)           ; word 0-1 reserved: 0 stays "no clause"
       _ (pin s 'wn (cask 4096)) _ (pin s 'wnu 2)
       _ (pin s 'ncls 0) _ (pin s 'bad 0)
       _ (pin s 'act (tablet 0)) _ (pin s 'vinc 1.0)
       _ (pin s 'nconf 0) _ (pin s 'rnum 1) _ (pin s 'climit 100)
       _ (foldl (\ _ c (fload s c)) 0 formula) s)
   ; --- two-watched-literal BCP over the arena ------------------------------------
   (fprop-lit s f)                                          ; encoded f just became FALSE; -> conflict cid or -1
    (: va (peep s 'val ()) ar (peep s 'ar ()) wn (peep s 'wn ()) wh (peep s 'wh ())
       lv (\ el (: m (peep va (>> el 1) 0) (? (= m 0) 0 (= m (+ 1 (& el 1))) 1 -1)))
       ((: (go p prev)
           (? (= p 0) -1
              (: cid (getw wn p) nx (getw wn (+ p 1))
                 _ (? (= (getw ar (+ cid 1)) f)                          ; normalize: f sits at slot cid+2
                      (: t (getw ar (+ cid 2)) _ (putw ar (+ cid 2) f) (putw ar (+ cid 1) t)) 0)
                 oth (getw ar (+ cid 1))
                 (? (= 1 (lv oth)) (go nx p)                             ; satisfied by the other watch: keep
                    (: k ((: (sc j)                                      ; scan the tail for a non-false literal
                             (? (>= j (+ cid (+ 1 (getw ar cid)))) 0
                                (: e (getw ar j) (? (! (= -1 (lv e))) j (sc (+ j 1))))))
                          (+ cid 3))
                       (? (! (= k 0))                                    ; slide the watch f -> ar[k]
                          (: e (getw ar k) _ (putw ar k f) _ (putw ar (+ cid 2) e)
                             _ (? (= prev 0) (putw wh f nx) (putw wn (+ prev 1) nx))   ; unlink from f
                             _ (putw wn (+ p 1) (getw wh e)) _ (putw wh e p)           ; link into e
                             (go nx prev))
                          (= 0 (lv oth)) (: _ (fassign s oth (+ cid 1)) (go nx p))     ; unit: force oth
                          cid))))))                                      ; oth false too: CONFLICT
        (getw wh f) 0))
   (fpropagate s)                                           ; drain the trail queue; -> conflict cid or -1
    (: hd (peep s 'hd ()) tr (peep s 'trail ())
       ((: (loop _)
           (? (>= (getw hd 1) (getw hd 0)) -1
              (: p (getw tr (getw hd 1)) _ (putw hd 1 (+ 1 (getw hd 1)))
                 confl (fprop-lit s (^ p 1))
                 (? (> confl -1) confl (loop ()))))) ()))
   ; --- 1-UIP analysis / backjump (sat.l's algorithm, reading the arena) ----------
   (fbump s v) (: a (peep s 'act ()) (pin a v (+ (peep a v 0.0) (peep s 'vinc 1.0))))
   (fabs s seen dl skipv c acc)                             ; absorb a clause's encoded lits into (counter . learnt)
    (foldl (\ st el
              (: v (>> el 1)
                 (? (= v skipv) st
                    (! (= 0 (peep seen v 0))) st
                    (= 0 (getw (peep s 'lvl ()) v)) st
                    (: _ (pin seen v 1) _ (fbump s v)
                       (? (= (getw (peep s 'lvl ()) v) dl) (link (+ 1 (cap st)) (cup st))
                          (link (cap st) (link el (cup st))))))))
           acc c)
   (ffind-seen tr seen idx) (? (= 0 (peep seen (>> (getw tr idx) 1) 0)) (ffind-seen tr seen (- idx 1)) idx)
   (fbj-level s learnt) (foldl (\ m el (: lv (flvl s el) (? (> lv m) lv m))) 0 learnt)
   (fmax-lit s ls) (foldl (\ b el (? (> (flvl s el) (flvl s b)) el b)) (cap ls) (cup ls))
   (freorder s learnt)                                      ; learnt[1] must be the max-level tail literal
    (? (atom? (cup learnt)) learnt
       (: a0 (cap learnt) rest (cup learnt) mx (fmax-lit s rest) (link a0 (link mx (rem-lit mx rest)))))
   (fanalyze s confl)                                       ; -> (learnt-clause . backjump-level), learnt[0] asserting
    (: hd (peep s 'hd ()) dl (getw hd 2) seen (tablet 0) tr (peep s 'trail ())
       a0 (fabs s seen dl 0 (fclits s confl) (link 0 ()))
       res ((: (go counter learnt idx)
               (: ix (ffind-seen tr seen idx) np (getw tr ix) v (>> np 1)
                  _ (pin seen v 0) cnt (- counter 1)
                  (? (= cnt 0) (link np learnt)
                     (: rv (getw (peep s 'rsn ()) v)
                        a (fabs s seen dl v (fclits s (- rv 1)) (link cnt learnt))
                        (go (cap a) (cup a) (- ix 1))))))
            (cap a0) (cup a0) (- (getw hd 0) 1))
       uip (cap res) learnt (cup res) learntc (link (^ uip 1) learnt)
       (link learntc (fbj-level s learnt)))
   (fbackjump s lvl)                                        ; pop + unassign every trail entry above level lvl
    (: hd (peep s 'hd ()) tr (peep s 'trail ()) va (peep s 'val ())
       lm (peep s 'lvl ()) rs (peep s 'rsn ()) ph (peep s 'phase ())
       nt ((: (go t)
              (? (= t 0) 0
                 (: el (getw tr (- t 1)) v (>> el 1)
                    (? (> (getw lm v) lvl)
                       (: _ (pin ph v (peep va v 1)) _ (pin va v 0)
                          _ (putw lm v 0) _ (putw rs v 0) (go (- t 1)))
                       t))))
           (getw hd 0))
       _ (putw hd 0 nt) _ (putw hd 1 nt) (putw hd 2 lvl))
   ; --- VSIDS + Luby restarts + phase saving (lisp-side heuristics) ---------------
   (frescale s) (foldl (\ _ v (: a (peep s 'act ()) (pin a v (* (peep a v 0.0) 1e-100)))) 0 (rng 1 (+ (peep s 'nvars 0) 1)))
   (fdecay s) (: vi (* (peep s 'vinc 1.0) 1.05)
                 (? (> vi 1e100) (: _ (frescale s) (pin s 'vinc (* vi 1e-100))) (pin s 'vinc vi)))
   (fpick s)                                                ; highest-activity free var, 0 if none
    (: va (peep s 'val ()) act (peep s 'act ()) nv (peep s 'nvars 0)
       ((: (go v best ba)
           (? (> v nv) best
              (: a (peep act v 0.0)
                 (? (&& (= 0 (peep va v 0)) (|| (= best 0) (> a ba))) (go (+ v 1) v a) (go (+ v 1) best ba)))))
        1 0 -1.0))
   (fnext-restart s) (: rn (+ 1 (peep s 'rnum 1)) _ (pin s 'rnum rn) _ (pin s 'nconf 0) _ (pin s 'climit (* (luby rn) 100)) 0)
   (fsearch s)                                              ; -> 'sat or 'unsat (s holds the model on SAT)
    (: hd (peep s 'hd ())
       ((: (loop _)
           (: confl (fpropagate s)
              (? (> confl -1)
                 (? (= 0 (getw hd 2)) 'unsat
                    (: res (fanalyze s confl) learnt (freorder s (cap res)) cid (fadd s learnt)
                       _ (fdecay s) _ (pin s 'nconf (+ 1 (peep s 'nconf 0)))
                       _ (fbackjump s (cup res))
                       _ (? (atom? (cup learnt)) 0
                            (: _ (fwatch s cid (cap learnt)) (fwatch s cid (caup learnt))))
                       _ (fassign s (cap learnt) (+ cid 1)) (loop ())))
                 (&& (> (getw hd 2) 0) (>= (peep s 'nconf 0) (peep s 'climit 0)))
                    (: _ (fbackjump s 0) _ (fnext-restart s) (loop ()))
                 (: v (fpick s)
                    (? (= v 0) 'sat
                       (: ph (peep (peep s 'phase ()) v 0)
                          _ (putw hd 2 (+ 1 (getw hd 2)))
                          _ (fassign s (? (= ph 1) (* 2 v) (+ 1 (* 2 v))) 0) (loop ()))))))) ()))
   (fextract s nvars) (: va (peep s 'val ())
                         (map (\ v (link v (? (= 1 (peep va v 0)) 1 -1))) (rng 1 (+ nvars 1))))
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
    ; pigeonhole PHP(5): UNSAT + resolution-hard (learning, restarts, arena growth end to end)
    (id? (fcdcl (php 5) (php-vars 5)) 'unsat))
 _ (say err "sat/flat: ok -- flat-arena CDCL == DPLL on 150 fuzzed + PHP(5) + #SAT==Lucas\n"))
