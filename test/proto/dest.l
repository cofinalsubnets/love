; test/proto/dest.l -- destination-driven codegen, modeled: a gen.l design spike.
; two generators over one C-shaped AST, one holo-flavored IR. `cv` is gen.l's r0 protocol
; (every value lands in r0, the consumer relocates it); `ck` passes the consumer down, a die:
;   ('reg r)    deliver into r
;   ('mem b o)  deliver through a store
;   ('br lt lf) branch on the value, no 0/1 reify; either label may be 'fall
;   'tail       the return itself: a call here is a sibcall
;   ()          r0, so an unmigrated consumer keeps reading r0
; run: cat test/00-init.l test/proto/dest.l | out/love    ; dots, then `dest: ok`
; not modeled: residency across statements, pool spill, and the arg ordering law
; (a later arg reading an earlier arg register must park; these args never interfere)

(: G (tablet 0)                                    ; the label mint
   (relab _) (pin G 'n 0)
   (nlab _) (: k (peep G 'n 0) (pin G 'n (k + 1), intern ("l" + show k)))
   (site n env) (assoc n env)                      ; (name slot off) | (name home r)
   (heads fs) (map cap fs)

   ; --- cv: the r0 protocol. compounds shuttle the left through an sp cell; a
   ; relation reifies 0/1 via set ---
   shov '((sub sp sp 8) (st sp 0 r0))
   shpo '((ld r1 sp 0) (add sp sp 8))
   (cv e env)
    (<e @ 'k [['li 'r0 <>e]]
          'v (: s (site <>e env) (<>s = 'home ? [['mov 'r0 <>>s]] [['ld 'r0 'r4 <>>s]]))
          'bin (cv <>>e env + shov + cv <>>>e env + shpo + [[<>e 'r0 'r1 'r0]])
          'rel (cv <>>e env + shov + cv <>>>e env + shpo + [['cmp 'r1 'r0] ['set <>e 'r0]])
          'and (: lf (nlab 0) l2 (nlab 0)
                  (cv <>e env + [['cmp 'r0 0] ['br 'eq lf]] + cv <>>e env
                   + [['cmp 'r0 0] ['br 'eq lf] ['li 'r0 1] ['jmp l2]
                       ['label lf] ['li 'r0 0] ['label l2]]))
          'call (argcv <>>e '(r6 r5) env + [['call <>e]])
          [['bad]])
   (argcv as ss env) (atom? as ? () (cv <as env + [['mov <ss 'r0]] + argcv >as >ss env))
   (cvs s env)                                     ; asn / if / ret
    (<s @ 'asn (: lv <>s
                  (<lv = 'loc
                   ? (: e9 (site <>lv env)
                        (cv <>>s env + (<>e9 = 'home ? [['mov <>>e9 'r0]] [['st 'r4 <>>e9 'r0]])))
                     (cv <>lv env + shov + cv <>>s env + shpo + [['st 'r1 <>>lv 'r0]])))
          'if (: cf (cv <>s env) le (nlab 0) ld (nlab 0)
                 (cf + [['cmp 'r0 0] ['br 'eq le]] + cvs <>>s env
                     + [['jmp ld] ['label le]] + cvs <>>>s env + [['label ld]]))
          'ret (cv <>s env + [['ret]])
          [['bad]])

   ; --- ck: the die is ev's k defunctionalized. an operand that already sits somewhere
   ; costs zero forms; a subexpression writes only its die and scratches below it ---
   (negrel r) (r @ 'lt 'ge  'ge 'lt  'le 'gt  'gt 'le  'eq 'ne  'eq)
   (brto rel lt lf)
    (? (lf = 'fall) [['br rel lt]]
       (lt = 'fall) [['br (negrel rel) lf]]
       [['br rel lt] ['jmp lf]])
   (rd9 e env pool)                                ; -> (x forms)
    (<e @ 'k [<>e ()]
          'v (: s9 (site <>e env) (<>s9 = 'home ? [<>>s9 ()] (: s <pool [s [['ld s 'r4 <>>s9]]])))
          (: s <pool [s (ck e env >pool ['reg s])]))
   (ck e env pool w)
    (w = 'tail
     ? (<e = 'call ? (argck <>>e '(r6 r5) env pool + [['jmp <>e]]) (ck e env pool ['reg 'r0] + [['ret]]))
       (: w9 (two? w ? w ['reg 'r0])
          (<w9 @ 'reg (: r <>w9
                         (<e @ 'k [['li r <>e]]
                               'v (: s9 (site <>e env)
                                     (<>s9 = 'home ? (<>>s9 = r ? () [['mov r <>>s9]]) [['ld r 'r4 <>>s9]]))
                               'bin (: pb (rd9 <>>>e env pool)
                                       (ck <>>e env pool ['reg r] + <>pb + [[<>e r r <pb]]))
                               'rel (: pa (rd9 <>>e env pool) pb (rd9 <>>>e env >pool)
                                       (<>pa + <>pb + [['cmp <pa <pb] ['set <>e r]]))
                               'call (argck <>>e '(r6 r5) env pool + [['call <>e]]
                                      + (r = 'r0 ? () [['mov r 'r0]]))
                               [['bad]]))
                 'mem (: b <>w9 o <>>w9
                         (<e @ 'k [['si b o <>e]]
                               'v (: s9 (site <>e env)
                                     (<>s9 = 'home ? [['st b o <>>s9]]
                                                     (: s <pool (ck e env >pool ['reg s] + [['st b o s]]))))
                               (: s <pool (ck e env >pool ['reg s] + [['st b o s]]))))
                 'br (: lt <>w9 lf <>>w9
                        (<e @ 'rel (: pa (rd9 <>>e env pool) pb (rd9 <>>>e env >pool)
                                      (<>pa + <>pb + [['cmp <pa <pb]] + brto <>e lt lf))
                              'and (ck <>e env pool ['br 'fall lf] + ck <>>e env pool w9)
                              (: pa (rd9 e env pool) (<>pa + [['cmp <pa 0]] + brto 'ne lt lf))))
                 [['bad]])))
   (argck as ss env pool) (atom? as ? () (ck <as env pool ['reg <ss] + argck >as >ss env pool))
   (base9 lv env pool)                             ; a homed obj aliases its home: zero forms
    (: obj <>lv
       (<obj = 'v ? (: s8 (site <>obj env) (<>s8 = 'home ? [<>>s8 ()] (: s <pool [s [['ld s 'r4 <>>s8]]])))
                    (: s <pool [s (ck obj env >pool ['reg s])])))
   (cks s env pool)
    (<s @ 'asn (: lv <>s
                  (<lv = 'loc
                   ? (: e9 (site <>lv env)
                        (<>e9 = 'home ? (ck <>>s env pool ['reg <>>e9]) (ck <>>s env pool ['mem 'r4 <>>e9])))
                     (: b9 (base9 lv env pool) (<>b9 + ck <>>s env >pool ['mem <b9 <>>lv]))))
          'if (: le (nlab 0) ld (nlab 0)
                 (ck <>s env pool ['br 'fall le] + cks <>>s env pool
                  + [['jmp ld] ['label le]] + cks <>>>s env pool + [['label ld]]))
          'ret (ck <>s env pool 'tail)
          [['bad]])
   P '(r10 r11))                                   ; the scratch pool, clear of homes

; --- law: the member store. p->f = 7 is one si ---
(: s1 '(asn (fld (v p) 8) (k 7)) e1 '((p home r9)))
(test (cvs s1 e1 = '((mov r0 r9) (sub sp sp 8) (st sp 0 r0) (li r0 7)
                      (ld r1 sp 0) (add sp sp 8) (st r1 8 r0)))
      (cks s1 e1 P = '((si r9 8 7))))

; --- law: the home write. y = y + 1 into y's home is one alu form ---
(: s2 '(asn (loc y) (bin add (v y) (k 1))) e2 '((y home r8)))
(test (8 = tally (cvs s2 e2))
      (cks s2 e2 P = '((add r8 r8 1))))

; --- law: control destinations. if (x<y && y<3): ck branches straight off the
; compares, zero set forms; both stores land as si ---
(: s3 '(if (and (rel lt (v x) (v y)) (rel lt (v y) (k 3)))
           (asn (loc z) (k 1))
           (asn (loc z) (k 0)))
   e3 '((x home r8) (y home r9) (z slot -8)))
(: _ (relab 0)
   a3 (cvs s3 e3)
   _ (relab 0)
   b3 (cks s3 e3 P)
   _ (test (elem 'set (heads a3))
           !(elem 'set (heads b3))
           (34 = #a3)
           (b3 = '((cmp r8 r9) (br ge l0) (cmp r9 3) (br ge l0)
                   (si r4 -8 1) (jmp l1) (label l0) (si r4 -8 0) (label l1)))))

; --- law: the tail. return f(x, 3): ck delivers each arg into its register and the
; call is the jump ---
(: s4 '(ret (call f ((v x) (k 3)))) e4 '((x home r8)))
(: a4 (cvs s4 e4)
   _ (test (6 = #a4)
           ('ret = <(last a4))
           ('call = <<>(rev a4))
           (cks s4 e4 P = '((mov r6 r8) (li r5 3) (jmp f)))))

; --- law: the degenerate die. () compiles a leaf exactly as cv does, so migration
; goes lane by lane; compounds only improve ---
(: e5 '((z slot -8) (y home r9)))
(test (cv '(k 7) e5 = ck '(k 7) e5 P ())
      (cv '(v z) e5 = ck '(v z) e5 P ())
      (: b (ck '(bin add (v y) (k 1)) e5 P ())
         (#b < tally (cv '(bin add (v y) (k 1)) e5) && b = '((mov r0 r9) (add r0 r0 1)))))

(puts "dest: ok") (putc 10)
