; src/love/compress/lz.l -- LZMA's decoder as data: vc.l lays lz_gen.h and the obligations in
; test/uuzxvc.l. the probabilities, the coder's range and code and the bytes are not modelled: each
; read that could leave an array is guarded or held under a bound, so what is proved holds whatever
; they hold. a bit, a tree and a length are laid by functions here, each site its own labels.
(:
   _ (borrow "src/apps/moon/clay.l")
   _ (borrow "src/love/compress/vc.l")

   ; the model's probabilities as one array, in struct lz_model's order (xz.c asserts the offsets)
   NP 1846
   ISREP 192 ISG0 204 ISG1 216 ISG2 228 REP0L 240 SLOT 432 SPEC 688 ALIGN 802 LEN 818 REPLEN 1332

   ; --- labels and proofs: a site's statements, guards and invariants each take a fresh name.
   ; argument order is unspecified, so every draw is its own row
   nlab {}
   (lab p) (: k (1 + peep nlab p 0) _ (pin nlab p k) (intern "z\(p)\(k)"))
   pf {}
   (prove l j p) (pin pf "\(l)-\(j)" p)
   ; the name a havoc or a join gives x at the statement labelled l
   (fr x l) (intern "\(x)\(l)")
   ; the trees' counters, each its own name so no loop rebinds another's
   tms {}
   (tmv _) (: m (lab "m") _ (pin tms m 1) m)
   (guard _) [[(lab "s") 'set 'rc 0] [(lab "k") 'brk]]
   ia '(inf-le i (add nin 1))

   ; --- the coder: normalize, then one bit off the probability at A[ix] ----------------------------
   ; past the input's end the coder reads zeros, and i stops one past it
   (norm _)
    (: J (lab "j") G (lab "g") K (lab "j") H (lab "g") X (lab "h") Y (lab "h") Z (lab "h") U (lab "s") V (lab "s")
       A (lab "a") B (lab "a")
     [[J 'join G '(wlt rg 16777216)
       [[X 'havoc 'rg '(wshl rg 8)]
        [K 'join H '(lt i nin)
         [[Y 'havoc 'cd '(wor (wshl cd 8) (at In i))] [U 'set 'i '(+ i 1)]]
         [[Z 'havoc 'cd '(wshl cd 8)] [V 'set 'i '(+ nin 1)]]
         [[A ia]]]]
       ()
       [[B ia]]]])
   ; with a branch, for the bits that lean one way: into b, 0 or 1
   (bit ix)
    (: P (lab "h") Q (lab "h") J (lab "j") G (lab "g") R (lab "h") W (lab "p") S (lab "s") C (lab "h") T (lab "h")
       D (lab "p") E (lab "s") F (lab "a")
     (norm 0
      + [[P 'havoc 'pw ['at 'Pr ix]]
         [Q 'havoc 'q '(wmul (wshr rg 11) pw)]
         [J 'join G '(lt cd q)
          [[R 'havoc 'rg 'q] [W 'poke 'Pr ix '(w16 (wadd pw (wshr (wsub 2048 pw) 5)))] [S 'set 'b 0]]
          [[C 'havoc 'rg '(wsub rg q)] [T 'havoc 'cd '(wsub cd q)] [D 'poke 'Pr ix '(w16 (wsub pw (wshr pw 5)))] [E 'set 'b 1]]
          [[F '(inf-le b 1)]]]]))
   ; with none, for a tree's: k all ones for a 0, b its low bit. answers [t's havoc label, statements]
   (bitf A ix)
    (: P (lab "h") Q (lab "h") K (lab "h") T (lab "h") B (lab "s") R (lab "h") C (lab "h") W (lab "p")
     [T (norm 0
         + [[P 'havoc 'pw ['at A ix]]
            [Q 'havoc 'q '(wmul (wshr rg 11) pw)]
            [K 'havoc 'k '(wlt cd q)]
            [T 'havoc 't '(wadd k 1)]
            [B 'set 'b '(low t 1)]
            [R 'havoc 'rg '(wadd q (and64 (wsub (wsub rg q) q) (bnot k)))]
            [C 'havoc 'cd '(wsub cd (and64 q (bnot k)))]
            [W 'poke A ix '(w16 (wsub (wadd pw (and64 (wshr (wsub 2048 pw) 5) k)) (and64 (wshr pw 5) (bnot k))))]])])
   ; a tree step's m: m << 1 | b, b the bit bitf left; its four obligations, and the loop's back,
   ; whose invariants are a tree's three (tr) or the matched literal's two
   (step O W m top tb t a1 tr)
    (: m2 ['add ['add m m] tb]
       or ['lz-or m top tb W ['inf-modlt 1 t]]
       _ (prove O 1 ['lz-fit ['add m m] (top + top) 'w 'gw ['lz-dbl m top W] '(idpath false)])
       _ (prove O 2 ['inf-moddbl m])
       _ (prove O 4 ['lz-fit m2 (top + top) 'w 'gw or '(idpath false)])
       _ (prove "\(W)b" 1 ['lz-ge1 m tb a1])
       _ (? tr (prove "\(W)b" 2 or) 0)
       _ (prove "\(W)b" (? tr 4 3) ['lz-fall m top tb a1 W])
     [[O 'set m ['or ['shl m 1] 'b 1]]])

   ; --- trees ---------------------------------------------------------------------------------------
   ; a forward tree of top leaves off A from bx, whose term is bt: bt <= B by the proof bh, B + top <= N by bn. m its
   ; own counter; the leaf, m - top, into res, and in tl what bounds it: (lz-tres m top a2 W)
   tl {}
   (tree A N bx bt B bh bn top res)
    (: m (tmv 0) f (bitf A ['+ bx m]) t (fr 't (f 0)) tb ['inf-mod 2 t]
       S (lab "s") W (lab "w") O (lab "s") R (lab "s") a1 (lab "a") a2 (lab "a") a3 (lab "a")
       ix ['lz-ix m top bt B N W bh bn]
       fit (charm? N ? ['lz-fit ['add bt m] N 'w 'gw ix '(idpath false)] ['inf-lttrans ['add bt m] N '(inf-pow w) ix ['inf-ltle N '(inf-pow w) 'gln]])
       body (f 1)
       ; the two reads of A[bx + m]: what bx + m owes, then that it is in
       _ (map (s \ s @ [L 'havoc 'pw _] (prove L 1 fit, prove L 2 ix) [L 'poke _ _ _] (prove L 1 fit, prove L 2 ix) _ 0) body)
       _ (prove R 2 ['lz-fit ['natminus m top] top 'w 'gw ['lz-tres m top a2 W] '(idpath false)])
       _ (pin tl 'leaf ['natminus m top])
       _ (pin tl 'bound ['lz-tres m top a2 W])
     [[S 'set m 1]
      [W 'while ['lt m top] ['natminus top m] [[a1 ['inf-le 1 m]] [a2 ['inf-lt m (top + top)]] [a3 ia]]
       (body + step O W m top tb t a1 1)]
      [R 'set res ['- m top]]])
   ; a reverse tree of n leaves, n a nat that fits, each index guarded: its leaf into v
   (rtree base n)
    (: S (lab "h") V (lab "h") F (lab "f") X (lab "h") I (lab "i") G (lab "g") M (lab "h") U (lab "h") a1 (lab "a")
       f (bitf 'Pr 'ix)
     [[S 'havoc 'rm 1] [V 'havoc 'v 0]
      [F 'for 'j 0 n [[a1 ia]]
       ([[X 'havoc 'ix ['wadd base 'rm]] [I 'if G ['le NP 'ix] (guard 0)]] + f 1
        + [[M 'havoc 'rm '(wor (wshl rm 1) b)] [U 'havoc 'v '(wor v (wshl b j))]])]])

   ; a length's leaf, 0 to 271, into lv: a choice, then a low or mid tree by ps, or the high one
   psT '(inf-mod 16 t0rh1)
   p15 '(inf-ltsle (inf-mod 16 t0rh1) 15 (inf-modlt 15 t0rh1))
   ; bx = ps * 8 + off, at most off + 120: [its hypothesis, statements, its term]
   (by8 off)
    (: S (lab "s") H (lab "h") x ['add '(inf-by8 (inf-mod 16 t0rh1)) off]
       _ (prove H 1 ['lz-by8 psT off p15])
       _ (prove S 1 ['lz-fit '(inf-by8 (inf-mod 16 t0rh1)) 121 'w 'gw ['inf-lelts '(inf-by8 (inf-mod 16 t0rh1)) 120 ['inf-by8mono psT 15 p15]] '(idpath false)])
       _ (prove S 2 ['lz-fit x (off + 121) 'w 'gw ['inf-lelts x (off + 120) ['lz-by8 psT off p15]] '(idpath false)])
     [H [[S 'set 'bx ['+ '(shl ps 3) off]] [H 'have H ['inf-le 'bx (off + 120)]]] x])
   (lenf base)
    (: J1 (lab "j") G1 (lab "g") J2 (lab "j") G2 (lab "g") a1 (lab "a") a2 (lab "a") a3 (lab "a") a4 (lab "a")
       L1 (lab "s") L2 (lab "s") L3 (lab "s")
       lo (by8 (base + 2)) mi (by8 (base + 130))
       ; each leaf's value of lv, and that it fits and stays under 272
       t1 (tree 'Pr NP 'bx (lo 2) (base + 122) (lo 0) '(idpath false) 8 'tv) x1 (tl 'leaf) p1 (tl 'bound)
       t2 (tree 'Pr NP 'bx (mi 2) (base + 250) (mi 0) '(idpath false) 8 'tv) x2 ['add (tl 'leaf) 8] p2 ['inf-ltaddr (tl 'leaf) 8 8 (tl 'bound)]
       t3 (tree 'Pr NP (base + 258) (base + 258) (base + 258) '(idpath false) '(idpath false) 256 'tv) x3 ['add (tl 'leaf) 16] p3 ['inf-ltaddr (tl 'leaf) 256 16 (tl 'bound)]
       _ (prove L1 1 ['lz-fit x1 8 'w 'gw p1 '(idpath false)])
       _ (prove L2 1 ['lz-fit x2 16 'w 'gw p2 '(idpath false)])
       _ (prove L3 1 ['lz-fit x3 272 'w 'gw p3 '(idpath false)])
       _ (prove "\(J1)j" 2 ['inf-letrans x1 7 271 ['inf-ltsle x1 7 p1] '(idpath false)])
       _ (prove "\(J2)j" 2 ['inf-letrans x2 15 271 ['inf-ltsle x2 15 p2] '(idpath false)])
       _ (prove "\(J2)j" 4 ['inf-ltsle x3 271 p3])
       _ (pin tl 'lv (fr 'lv J1))
       c2 (bit (base + 1)) c1 (bit base)
     (c1
      + [[J1 'join G1 '(z b)
          (lo 1 + t1 + [[L1 'set 'lv 'tv]])
          (c2
           + [[J2 'join G2 '(z b)
               (mi 1 + t2 + [[L2 'set 'lv '(+ tv 8)]])
               (t3 + [[L3 'set 'lv '(+ tv 16)]])
               [[a1 ia] [a2 '(inf-le lv 271)]]]])
          [[a3 ia] [a4 '(inf-le lv 271)]]]]))

   ; --- lz_run: decode to lim bytes, or with eopm the end marker ------------------------------------
   ; rc: 1 done, 2 the marker, 3 paused for input, 0 corrupt. the coder, the state and rep0 ride
   ; locals, back in r and m at the end; the other reps stay in m
   (cf s f) ['dot ['deref ['var s]] f]
   (repk k) ['deref ['bin '+ (cf "m" "reps") ['num k]]]
   (cput lv e) [(lab "r") 'raw ['expr ['asn lv e]]]
   u32 '(named "uint32_t")
   ; the byte at the context, led by the byte at rep0 while the bits agree (st >= 7)
   matched
    (: f (bitf 'Lt 'ix) t (fr 't (f 0)) tb ['inf-mod 2 t] g5 (guard 0) g6 (guard 0)
     [['ri5 'if 'rg9 '(le (- on base) r0) g5]
      '(rh6 havoc mb (at Ob (- (- on r0) 1)))
      '(rs5 set sy 1)
      '(rh7 havoc off 256)
      ['rw1 'while '(lt sy 256) '(natminus 256 sy) '((rc1 (inf-le 1 sy)) (rc2 (inf-le i (add nin 1))))
       ('((rh8 havoc mb (wshl mb 1))
          (rh9 havoc mbit (and64 mb off))
          (rh10 havoc ix (wadd (wadd li (wadd off mbit)) sy)))
        + [['ri6 'if 'rg10 '(le litn ix) g6]]
        + f 1
        + step 'rs6 'rw1 'sy 256 tb t 'rc1 0
        + '((rh11 havoc off (and64 off (bxor (wsub 0 b) (bnot mbit))))))]])
   plain (tree 'Lt 'litn 'li 'lirh5 '(natminus litn 768) 'rg7 '(lz-sub768 litn gl) 256 'sy)
   g4 (guard 0)
   g3 (guard 0)
   lit-arm
    [['ri3 'if 'rg5 '(le cap on) g3]
     '(rj2 join rg6 (lt base on) ((rh3 havoc pv (at Ob (- on 1)))) ((rh4 havoc pv 0)) ())
     '(rh5 havoc li (wmul 768 (wadd (wshl (and64 on lpm) lc) (wshr pv (wsub 8 lc)))))
     ['ri4 'if 'rg7 '(lt (- litn 768) li) g4]
     ['rj3 'join 'rg8 '(le 7 st) matched plain '((ra1 (inf-le i (add nin 1))))]
     '(rp1 poke Ob on (w8 sy))
     '(rs4 set on (+ on 1))
     '(re2 ife rg20 (lt st 4) ((rs12 set st 0)) ((re3 ife rg21 (lt st 10) ((rs13 set st (- st 3))) ((rs14 set st (- st 6))))))]

   ; a match: its length, then its distance's slot, middle bits and low bits, or the end marker
   rta (rtree ALIGN 4)
   nrm (norm 0)
   rtb (rtree 'bx 'fb)
   dist
    [['rh17 'havw 'fb '(wsub (wshr slot 1) 1) 'rg19]
      '(rh18 havoc d (wshl (wor 2 (and64 slot 1)) fb))
      ['rj7 'join 'rg22 '(lt slot 14)
       ('((rh19 havoc bx (wsub (wsub (wadd 688 d) slot) 1))) + rtb + '((rh20 havoc d (wadd d v))))
       ('((rh21 havw nd (wsub fb 4) rg23) (rh22 havoc v 0))
        + [['rf1 'for 'j 0 'nd '((ra7 (inf-le i (add nin 1))))
            (nrm + '((rh23 havoc rg (wshr rg 1)) (rh24 havoc t (wge cd rg))
                        (rh25 havoc cd (wsub cd (and64 rg (wsub 0 t)))) (rh26 havoc v (wor (wshl v 1) t))))]]
        + '((rh27 havoc d (wadd d (wshl v 4))))
        + rta
        + '((rh28 havoc d (wadd d v))))
       '((ra6 (inf-le i (add nin 1))))]]
   (len1 j l) (prove "\(j)j" 3 ['inf-letrans 1 2 ['add l 2] '(idpath false) ['inf-leaddl 2 l]])
   normal
    (: x (lenf LEN) _ (len1 'rj4 (tl 'lv)) g7 (guard 0) sl (tree 'Pr NP 'sb 'sbrh14 624 'rg13 '(idpath false) 64 'slot)
       p3 (cput (repk 3) (repk 2)) p2 (cput (repk 2) (repk 1)) p1 (cput (repk 1) ['cast u32 ['var "r0"]])
     (x
     + '((rs7 set len (+ lv 2)) (rs8 set kind 0)
         (rj5 join rg12 (lt lv 3) ((rh12 havoc lx lv)) ((rh13 havoc lx 3)) ())
         (rh14 havoc sb (wadd 432 (wshl lx 6))))
     + [['ri7 'if 'rg13 '(lt 624 sb) g7]]
     + sl
     + [['rj6 'join 'rg14 '(lt slot 4) '((rh15 havoc d slot)) dist '((ra5 (inf-le i (add nin 1))))]
        ['ri8 'if 'rg15 '(eq d 4294967295)
         '((re4 ife rg16 (nz em) ((re5 ife rg17 (le i nin) ((rs9 set rc 2)) ((rs10 set rc 0)))) ((rs11 set rc 0)))
           (rk2 brk))]
        p3 p2 p1
        '(rh16 havw r0 d rg18)]))
   ; a rep: rep0 short (one byte) or long, or rep 1 to 3 moved to the front
   rep
    (: x (lenf REPLEN) _ (len1 'rj12 (tl 'lv)) b2 (bit ['+ 'st ISG2]) b1 (bit ['+ 'st ISG1]) bl (bit ['+ 'sx REP0L]) b0 (bit ['+ 'st ISG0])
       p3 (cput (repk 3) (repk 2)) p2 (cput (repk 2) (repk 1)) p1 (cput (repk 1) ['cast u32 ['var "r0"]])
     (b0
     + [['rj8 'join 'rg24 '(z b)
         (bl + '((rj9 join rg25 (z b) ((rs15 set sh 1)) ((rs16 set sh 0)) ((ra8 (inf-le sh 1)) (ra9 (inf-le i (add nin 1)))))))
         ('((rs17 set sh 0)) + b1
          + [['rj10 'join 'rg26 '(z b) [['rh29 'havoc 'd ['raw (repk 1)]]]
              (b2
               + [['rj11 'join 'rg27 '(z b) [['rh30 'havoc 'd ['raw (repk 2)]]]
                   [['rh31 'havoc 'd ['raw (repk 3)]] p3]
                   '((ra10 (inf-le i (add nin 1))))]
                  p2])
              '((ra11 (inf-le i (add nin 1))))]
             p1
             '(rh32 havw r0 d rg28)])
         '((ra12 (inf-le i (add nin 1))) (ra13 (inf-le sh 1)))]
        ['rj12 'join 'rg29 '(z sh)
         (x + '((rs18 set len (+ lv 2)) (rs19 set kind 1)))
         '((rs20 set len 1) (rs21 set kind 2))
         '((ra14 (inf-le i (add nin 1))) (ra15 (inf-le kind 2)) (ra16 (inf-le 1 len)))]]))
   ; the copy, len bytes from r0 + 1 back: whole words where they cannot overlap and room follows
   wide '((rs22 set ck 0)
          (rw2 while (lt ck len) (natminus len ck) ()
           ((rp2 pokew Ob (+ on ck) (ld64 Ob (- (+ on ck) (+ r0 1))))
            (rs23 set ck (+ ck 8)))))
   (bytes L S P T) [[S 'set 'ck 0]
                    [L 'while '(lt ck len) '(natminus len ck) ()
                     [[P 'poke 'Ob '(+ on ck) '(at Ob (- (+ on ck) (+ r0 1)))]
                      [T 'set 'ck '(+ ck 1)]]]]
   g12 (guard 0)
   g11 (guard 0)
   g10 (guard 0)
   g9 (guard 0)
   bmatch (bit ['+ 'st ISREP])
   match-arm
    (bmatch
     + [['rj4 'join 'rg11 '(z b) normal rep
         '((ra2 (inf-le i (add nin 1))) (ra3 (inf-le kind 2)) (ra4 (inf-le 1 len)))]
        ['ri9 'if 'rg30 '(le (- on base) r0) g9]
        ['ri10 'if 'rg31 '(lt nin i) g10]
        ['ri11 'if 'rg32 '(lt top on) g11]
        ['ri12 'if 'rg33 '(lt (- top on) len) g12]
        ['rj13 'join 'rg34 '(wide (+ r0 1))
         [['rj14 'join 'rg35 '(le (+ len 8) (- cap on)) wide (bytes 'rw3 'rs24 'rp3 'rs25) ()]]
         (bytes 'rw4 'rs26 'rp4 'rs27)
         ()]
        '(rs28 set on (+ on len))
        '(re6 ife rg36 (lt st 7) ((rs29 set st (+ 7 kind))) ((re7 ife rg37 (z kind) ((rs30 set st 10)) ((rs31 set st 11)))))])
   bsx (bit 'sx)
   g1 (guard 0)
   run-body
    ('((rh1 havoc t0 (and64 on pbm)) (rs1 set ps (low t0 15)))
     + [['ri1 'if 'rg1 '(lt nin i) g1]
        ['rj1 'join 'rg2 '(eq pz 1) [['ri2 'if 'rg3 '(lt (- nin i) 20) '((rs2 set rc 3) (rk1 brk))]] () ()]
        '(rs3 set sx (+ (shl st 4) ps))
        '(rh2 have rh2 (inf-le sx 191))]
     + bsx
     + [['re1 'ife 'rg4 '(z b) lit-arm match-arm]])
   ; the hand proofs the walk's own statements owe, by label
   sxT '(add (inf-by16 st) (inf-mod 16 t0rh1))
   LC '(inf-letrans lenrj4 (natminus toprj25 on) cap rg33 (inf-letrans (natminus toprj25 on) toprj25 cap (inf-suble toprj25 on) ra46))
   OLC '(lz-room on lenrj4 toprj25 cap rg33 rg32 ra46)
   CW '(lz-cw w cap gc)
   bk '(natminus (add on ck) (add r0rj4 1))
   (fits-on W) ['inf-lelt '(add on ck) 'cap '(inf-pow w) ['inf-letrans '(add on ck) '(add on lenrj4) 'cap ['inf-addl 'on 'ck 'lenrj4 ['inf-ltle 'ck 'lenrj4 W]] OLC] CW]
   (in-on W) ['inf-lttrans '(add on ck) '(add on lenrj4) 'cap ['inf-ltaddl 'on 'ck 'lenrj4 W] OLC]
   _ (map (r \ prove (r 0) (r 1) (r 2))
      [["rs29" 1 ['lz-fit '(add 7 kindrj4) 10 'w 'gw ['inf-lelts '(add 7 kindrj4) 9 ['inf-addl 7 'kindrj4 2 'ra3]] '(idpath false)]]
       ["rs3" 1 ['lz-fit '(inf-by16 st) 177 'w 'gw ['inf-lelts '(inf-by16 st) 176 '(inf-by16mono st 11 rb4)] '(idpath false)]]
       ["rs3" 2 ['lz-fit sxT 192 'w 'gw ['inf-lelts sxT 191 ['lz-sx 'st psT 'rb4 p15]] '(idpath false)]]
       ["rh2" 1 ['lz-sx 'st psT 'rb4 p15]]
       ["rh3" 1 '(inf-letrans 1 (succ base) on (idpath false) (inf-ltsu base on rg6))]
       ["rh6" 2 '(inf-ltsu 0 (natminus on r0) (inf-subpos on r0 (inf-lttrans r0 (natminus on base) on rg9 (inf-suble on base))))]
       ["rj14" 1 ['inf-lelt '(add lenrj4 8) '(add cap 8) '(inf-pow w) ['inf-addr 'lenrj4 'cap 8 LC] 'gc]]
       ["rp2" 1 (fits-on 'rw2)]
       ["rp2" 2 '(lz-w8 on ck lenrj4 cap rw2 rg35 rb1)]
       ["rp2" 5 ['inf-letrans ['add bk 8] '(add (add on ck) 8) 'cap ['inf-addr bk '(add on ck) 8 ['inf-suble '(add on ck) '(add r0rj4 1)]] '(lz-w8 on ck lenrj4 cap rw2 rg35 rb1)]]
       ["rs23" 1 ['inf-lelt '(add ck 8) '(add cap 8) '(inf-pow w) ['inf-addr 'ck 'cap 8 ['inf-letrans 'ck 'lenrj4 'cap '(inf-ltle ck lenrj4 rw2) LC]] 'gc]]
       ["rw2b" 1 '(inf-subby ck lenrj4 8 rw2 (idpath true))]
       ["rp3" 1 (fits-on 'rw3)] ["rp4" 1 (fits-on 'rw4)]
       ["rp3" 2 (in-on 'rw3)] ["rp4" 2 (in-on 'rw4)]
       ["rp3" 5 ['inf-lelt bk '(add on ck) 'cap ['inf-suble '(add on ck) '(add r0rj4 1)] (in-on 'rw3)]]
       ["rp4" 5 ['inf-lelt bk '(add on ck) 'cap ['inf-suble '(add on ck) '(add r0rj4 1)] (in-on 'rw4)]]
       ["rs25" 1 ['inf-lelt '(add ck 1) 'cap '(inf-pow w) ['inf-letrans '(add ck 1) 'lenrj4 'cap '(inf-lt1 ck lenrj4 rw3) LC] CW]]
       ["rs27" 1 ['inf-lelt '(add ck 1) 'cap '(inf-pow w) ['inf-letrans '(add ck 1) 'lenrj4 'cap '(inf-lt1 ck lenrj4 rw4) LC] CW]]
       ["rs28" 1 ['inf-lelt '(add on lenrj4) 'cap '(inf-pow w) OLC CW]]
       ["rw0b" 16 OLC] ["rw0b" 21 OLC] ["rw0b" 26 OLC]
       ["rw0b" 19 '(inf-letrans (add 7 kindrj4) 9 11 (inf-addl 7 kindrj4 2 ra3) (idpath false))]
       ["rw0b" 20 '(inf-subby on limrj22 lenrj4 rw0 (inf-le1 lenrj4 ra4))]
       ["rw0b" 25 '(inf-subby on limrj22 lenrj4 rw0 (inf-le1 lenrj4 ra4))]
       ["rw0b" 30 '(inf-subby on limrj22 lenrj4 rw0 (inf-le1 lenrj4 ra4))]])
   run
    {'name "lz_run" 'short "zxrun"
     'attrs '("static")
     'ret 'int
     'params '(("m" (ptr (struct "lz_model"))) ("r" (ptr (struct "lz_rd"))) ("o" (ptr (struct "lz_out")))
               ("lim" (named "uintptr_t")) ("eopm" int))
     'fields ()
     'arrays '((In (v "inb") nin) (Ob (v "ob") cap) (Pr (v "P") 1846) (Lt (v "L") litn))
     'requires
      '((In (pi x nat nat)) (Ob (pi x nat nat)) (Pr (pi x nat nat)) (Lt (pi x nat nat))
        (w nat) (nin nat) (i nat) (cap nat) (on nat) (base nat) (st nat) (r0 nat) (litn nat) (lim nat)
        (rg nat) (cd nat) (pz nat) (bd nat) (em nat)
        (gw (inf-le 32 w))
        (gn (inf-lt (add nin 1) (inf-pow w)))
        (gi (inf-le i (add nin 1)))
        (gc (inf-lt (add cap 8) (inf-pow w)))
        (go (inf-le on cap))
        (gb (inf-le base on))
        (gs (inf-le st 11))
        (gl (inf-le 768 litn))
        (gln (inf-lt litn (inf-pow w)))
        (glim (inf-lt lim (inf-pow w))))
     'decls
      [['(ptr (const (named "uint8_t"))) ['inb ['raw (cf "r" "p")]]]
       ['(ptr (named "uint8_t")) ['ob ['raw (cf "o" "b")]]]
       ['(ptr (named "lzp")) ['P ['raw ['cast '(ptr (named "lzp")) ['var "m"]]]] ['L ['raw (cf "m" "lit")]]]
       ('(named "uintptr_t")
        . [['i ['raw (cf "r" "i")]] ['nin ['raw (cf "r" "n")]] ['rg ['raw (cf "r" "range")]] ['cd ['raw (cf "r" "code")]]
           ['on ['raw (cf "o" "n")]] ['cap ['raw (cf "o" "cap")]] ['base ['raw (cf "o" "base")]]
           ['st ['raw (cf "m" "state")]] ['r0 ['raw (repk 0)]]
           ['litn ['raw ['bin 'shl ['cast '(named "uintptr_t") ['num 768]] ['bin '+ (cf "m" "lc") (cf "m" "lp")]]]]
           ['lpm ['raw ['bin '- ['bin 'shl ['cast '(named "uintptr_t") ['num 1]] (cf "m" "lp")] ['num 1]]]]
           ['pbm ['raw ['bin '- ['bin 'shl ['cast '(named "uintptr_t") ['num 1]] (cf "m" "pb")] ['num 1]]]]
           ['lc ['raw (cf "m" "lc")]]
           ['pz ['raw (cf "o" "pause")]] ['bd ['raw (cf "r" "bad")]] ['em ['raw ['var "eopm"]]]]
        + map (x \ [x]) '(hlim top b pw q k t t0 ps sx li pv mb mbit off sy len lv tv bx lx sb slot d fb nd v rm ix j kind sh ck)
        + map (x \ [x]) (sort (keys tms)))
       '(int (rc 1))]
     'ensures ()
     'body
      ('((rj20 join rg40 (nz bd) ((rs40 set i (+ nin 1))) () ((ra40 (inf-le i (add nin 1)))))
         (rj21 join rg41 (nz em) ((rh42 havw lim (bnot 0) rg42)) () ((ra41 (inf-lt lim (inf-pow w)))))
         (rs41 set hlim lim)
         (rj22 join rg43 (nz pz)
          ((ri40 if rg44 (lt cap 273) ((rr20 ret 0)))
           (rj23 join rg45 (lt (- cap 273) lim) ((rs42 set lim (- cap 273))) () ((ra42 (inf-lt lim (inf-pow w)))))
           (rj24 join rg46 (lt cap hlim) ((rs43 set hlim cap)) () ((ra43 (inf-lt hlim (inf-pow w))))))
          ()
          ((ra44 (inf-lt lim (inf-pow w))) (ra45 (inf-lt hlim (inf-pow w)))))
         (rs44 set top cap)
         (rj25 join rg47 (lt hlim top) ((rs45 set top hlim)) () ((ra46 (inf-le top cap)))))
       + [['rw0 'while '(lt on lim) '(natminus lim on)
           '((rb1 (inf-le on cap)) (rb2 (inf-le base on)) (rb3 (inf-le i (add nin 1))) (rb4 (inf-le st 11)))
           run-body]]
       + map (p \ cput (p 0) (p 1))
          [[(cf "r" "range") ['cast u32 ['var "rg"]]]
           [(cf "r" "code") ['cast u32 ['var "cd"]]]
           [(cf "r" "bad") ['bin 'lt ['var "nin"] ['var "i"]]]
           [(cf "r" "i") ['cond ['bin 'lt ['var "nin"] ['var "i"]] ['var "nin"] ['var "i"]]]
           [(cf "m" "state") ['cast 'uint ['var "st"]]]
           [(repk 0) ['cast u32 ['var "r0"]]]
           [(cf "o" "n") ['var "on"]]]
       + '((rr1 ret rc)))
     'macros '()
     'proofs pf}

   ; --- the model and the coder at a chunk's start and end ------------------------------------------
   (mput f e) ['raw ['expr ['asn (cf "m" f) e]]]
   (rput f e) ['raw ['expr ['asn (cf "r" f) e]]]
   ; every probability even: the fixed ones, then the literals'
   reset
    {'name "lz_reset" 'short "zxreset"
     'attrs '("static")
     'ret 'void
     'params '(("m" (ptr (struct "lz_model"))))
     'fields ()
     'arrays '((Pr (v "P") 1846) (Lt (v "L") litn))
     'requires '((w nat) (litn nat) (gw (inf-le 32 w)) (gln (inf-lt litn (inf-pow w))))
     'decls
      [['(ptr (named "lzp")) ['P ['raw ['cast '(ptr (named "lzp")) ['var "m"]]]] ['L ['raw (cf "m" "lit")]]]
       ['(named "uintptr_t") '(j)
        ['litn ['raw ['bin 'shl ['cast '(named "uintptr_t") ['num 768]] ['bin '+ (cf "m" "lc") (cf "m" "lp")]]]]]]
     'ensures ()
     'body
      ('((f1 for j 0 1846 () ((p1 poke Pr j 1024)))
         (f2 for j 0 litn () ((p2 poke Lt j 1024))))
       + [('w1 . mput "state" ['num 0])]
       + map (k \ ['w2 'raw ['expr ['asn (repk k) ['num 0]]]]) [0 1 2 3])
     'macros '()
     'proofs
      {"f1b-1" '(lz-fit (succ j) 1847 w gw (inf-lelts (succ j) 1846 (inf-ltsu j 1846 f1)) (idpath false))}}
   ; the props byte, pb lp lc packed as ((pb * 5) + lp) * 9 + lc: 0 refused, 1 and m's three laid
   props
    (: q '(un-div 9 b) dq '(un-divlt 9 (idpath true) b 25 (inf-lelts b 224 g1))
       lcb '(inf-ltsle (inf-mod 9 b) 8 (inf-modlt 8 b)) lpb ['inf-ltsle ['inf-mod 5 q] 4 ['inf-modlt 4 q]]
       dp ['un-divlt 5 '(idpath true) q 5 dq] pbb ['inf-ltsle ['un-div 5 q] 4 dp]
       sum ['add '(inf-mod 9 b) ['inf-mod 5 q]] sumb ['inf-add2 '(inf-mod 9 b) 8 ['inf-mod 5 q] 4 lcb lpb]
    {'name "lz_props" 'short "zxprops"
     'attrs '("static")
     'ret 'int
     'params '(("m" (ptr (struct "lz_model"))) ("b" uint) ("maxlclp" uint))
     'fields ()
     'arrays ()
     'requires '((w nat) (b nat) (maxlclp nat) (gw (inf-le 32 w)))
     'decls '((uint (lc 0) (lp 0) (pb 0) (q)))
     'ensures '((e1 (inf-le lc 8)) (e2 (inf-le lp 4)) (e3 (inf-le pb 4)))
     'body
      ['(i1 if g1 (lt 224 b) ((r1 ret 0)))
       '(s1 set lc (d% b 9)) '(s2 set q (d/ b 9)) '(s3 set lp (d% q 5)) '(s4 set pb (d/ q 5))
       '(i2 if g2 (lt maxlclp (+ lc lp)) ((r2 ret 0)))
       ('w1 . mput "lc" ['var "lc"]) ('w2 . mput "lp" ['var "lp"]) ('w3 . mput "pb" ['var "pb"])
       '(r3 ret 1)]
     'macros '()
     'proofs {"s2-2" ['lz-fit q 25 'w 'gw dq '(idpath false)]
              "s4-2" ['lz-fit ['un-div 5 q] 5 'w 'gw dp '(idpath false)]
              "i2-1" ['lz-fit sum 13 'w 'gw ['inf-lelts sum 12 sumb] '(idpath false)]
              "r2-1" lcb "r2-2" lpb "r2-3" pbb "r3-1" lcb "r3-2" lpb "r3-3" pbb}})
   ; n bytes at p, the first five the coder's: 0 refused
   init
    (: (rd k) ['inf-lttrans k 5 'n '(idpath true) 'g1]
    {'name "rd_init" 'short "zxinit"
     'attrs '("static")
     'ret 'int
     'params '(("r" (ptr (struct "lz_rd"))) ("p" (ptr (const (named "uint8_t")))) ("n" (named "uintptr_t")))
     'fields ()
     'arrays '((In (v "p") n))
     'requires '((In (pi x nat nat)) (n nat))
     'decls '(((named "uint32_t") (cd)))
     'ensures '((e1 (pi e (inf-lt 0 res) (inf-le 5 n))))
     'body
      ['(i1 if g1 (lt n 5) ((r1 ret 0)))
       '(h1 havoc cd (at In 0))
       '(i2 if g2 (ne cd 0) ((r2 ret 0)))
       '(h2 havoc cd (wor (wor (wor (wshl (u32 (at In 1)) 24) (wshl (u32 (at In 2)) 16)) (wshl (u32 (at In 3)) 8)) (at In 4)))
       ('w1 . rput "p" ['var "p"]) ('w2 . rput "i" ['num 5]) ('w3 . rput "n" ['var "n"])
       ('w4 . rput "range" ['cast u32 ['un 'neg ['num 1]]]) ('w5 . rput "code" ['var "cd"]) ('w6 . rput "bad" ['num 0])
       '(r3 ret 1)]
     'macros '()
     'proofs {"h1-1" (rd 0) "h2-1" (rd 1) "h2-2" (rd 2) "h2-3" (rd 3) "h2-4" (rd 4)
              "r1-1" '(lam e (fromempty (inf-le 5 n) (nopathsfalsetotrue e)))
              "r2-1" '(lam e (fromempty (inf-le 5 n) (nopathsfalsetotrue e)))
              "r3-1" '(lam e g1)}})
   ; one step with no bit after: the byte the coder's last bit left
   rnorm
    {'name "rd_norm" 'short "zxnorm"
     'attrs '("static")
     'ret 'void
     'params '(("r" (ptr (struct "lz_rd"))))
     'fields '(i n range code)
     'state '((i i0))
     'arrays '((In (r "p") n))
     'requires '((In (pi x nat nat)) (w nat) (n nat) (i0 nat) (gw (inf-le 32 w)) (gn (inf-lt n (inf-pow w))) (gi (inf-le i0 n)))
     'decls '((uint (x)))
     'ensures '((e1 (inf-le i n)))
     'body
      '((i1 if g1 (wlt range 16777216)
         ((s1 store "range" (wshl range 8))
          (j1 join g2 (lt i n)
           ((h1 havoc x (at In i)) (s2 set i (+ i 1)) (s3 store "code" (wor (wshl code 8) x)))
           ((s4 store "code" (wshl code 8)) (s5 store "bad" 1))
           ((a1 (inf-le i n)))))))
     'macros '()
     'proofs {}}

   ; --- LZMA2's chunks --------------------------------------------------------------------------------
   ; a refusal, and the header's lengths, each one under what it says
   (no l g c) [l 'if g c [[(intern "\(l)r") 'retneg 1]]]
   (ix x d) (name? x ? ['+ x d] d)
   (be2 x d) ['wadd ['wor ['wshl ['u32 ['at 'In (ix x d)]] 8] ['at 'In (ix x (d + 1))]] 1]
   be3 '(wadd (wor (wor (wshl (and64 c 31) 16) (wshl (u32 (at In (+ si 1))) 8)) (at In (+ si 2))) 1)
   ; under a header of h bytes (hp: 5 or 3 <= h) with room hm: a read at si + d, and k more after it (km)
   sile '(inf-ltle si n g1)
   (nfit x p) ['inf-lelt x 'n '(inf-pow w) p 'gn]
   (hlt h hp d) (charm? h ? '(idpath true) ['inf-lttrans d 5 h '(idpath true) hp])
   (hrd h hp hm d) ['bz-nbq 'si d h 'n (hlt h hp d) hm sile]
   (hpr t L h hp hm ds)
    (map (r \ r @ [j d] (: x ['add 'si d] p (hrd h hp hm d)
      (pin t "\(L)-\(j)" ['inf-lttrans x 'n '(inf-pow w) p '(inf-ltle n (inf-pow w) gn)], pin t "\(L)-\(j + 1)" p))) ds)
   (hk h hm k km) ['bz-nbr h k '(natminus n si) km hm]
   (hkn h hm k km) ['bz-nbr 'si ['add h k] 'n (hk h hm k km) sile]
   (hkp h hp k) (charm? h ? '(idpath true)
                 ['bz-pos ['add h k] ['inf-letrans 1 h ['add h k] ['inf-letrans 1 5 h '(idpath false) hp] ['inf-leaddr h k]]])
   (hin h hm k km) ['inf-letr ['add 'si ['add h k]] ['add ['add 'si h] k] 'n ['inf-addassoc 'si h k] (hkn h hm k km)]
   ; si's step past it, at L, and the loop's fall, the back's j
   (hstep t L j h hp hm k km)
    (pin t "\(L)-1" (nfit ['add h k] ['inf-letrans ['add h k] '(natminus n si) 'n (hk h hm k km) '(inf-suble n si)]),
     pin t "\(L)-2" (nfit ['add 'si ['add h k]] (hkn h hm k km)),
     pin t "w0b-\(j)" ['inf-subby 'si 'n ['add h k] 'g1 (hkp h hp k)])
   ; the header pass: the bytes it says, *end past the 0x00; -1 malformed
   wpf {}
   _ (hpr wpf "h2" 3 () 'g5 [[1 1] [3 2]])
   _ (hstep wpf "s1" 1 3 () 'g5 'kh2 'g6)
   _ (hpr wpf "h4" 'hj1 'a1 'g8 [[1 1] [3 2]])
   _ (hpr wpf "h5" 'hj1 'a1 'g8 [[1 3] [3 4]])
   _ (hstep wpf "s4" 2 'hj1 'a1 'g8 'kh5 'g9)
   walk
    {'name "l2_walk" 'short "zxwalk"
     'attrs '("static")
     'ret '(named "int64_t")
     'params '(("s" (ptr (const (named "uint8_t")))) ("n" (named "uintptr_t")) ("end" (ptr (named "uintptr_t"))))
     'fields ()
     'arrays '((In (v "s") n))
     'requires '((In (pi x nat nat)) (w nat) (n nat) (gw (inf-le 32 w)) (gn (inf-lt n (inf-pow w))))
     'decls '(((named "uintptr_t") (si 0) (k) (h) (u)) ((named "int64_t") (tot 0)) (uint (c)))
     'ensures ()
     'body
      [['w0 'while '(tru) '(natminus n si) ()
        [(no 'i1 'g1 '(le n si))
         '(h1 havoc c (at In si))
         '(i2 if g2 (z c) ((o1 raw (expr (asn (deref (var "end")) (bin + (var "si") (num 1))))) (r2 ret tot)))
         ['e1 'ife 'g3 '(lt c 128)
          [(no 'i3 'g4 '(lt 2 c))
           (no 'i4 'g5 '(lt (- n si) 3))
           ['h2 'havoc 'k (be2 'si 1)]
           (no 'i5 'g6 '(lt (- (- n si) 3) k))
           '(h3 havoc tot (wadd tot k))
           '(s1 set si (+ si (+ 3 k)))]
          ['(j1 join g7 (lt c 192) ((s2 set h 5)) ((s3 set h 6)) ((a1 (inf-le 5 h))))
           (no 'i6 'g8 '(lt (- n si) h))
           ['h4 'havoc 'u be3]
           ['h5 'havoc 'k (be2 'si 3)]
           (no 'i7 'g9 '(lt (- (- n si) h) k))
           '(h6 havoc tot (wadd tot u))
           '(s4 set si (+ si (+ h k)))]]]]]
     'macros '()
     'proofs wpf}
   ; the chunks into out, pre bytes of it said already: 0 and cap full, -1 corrupt. a dict reset first
   ; unless pre, props before the first LZMA chunk and after a 0x01. each header is held to n, and what
   ; lz_run left is read back guarded, so nothing here leans on l2_walk
   (of f) ['dot ['var "o"] f]
   (rf f) ['dot ['var "r"] f]
   litnx ['raw ['bin 'shl ['cast '(named "uintptr_t") ['num 768]] ['bin '+ (cf "m" "lc") (cf "m" "lp")]]]
   (oput l f e) [l 'raw ['expr ['asn (of f) e]]]
   dpf {}
   _ (hpr dpf "h3" 3 () 'g7 [[1 1] [3 2]])
   _ (hstep dpf "s4" 3 3 () 'g7 'kh3 'g8)
   _ (hpr dpf "h5" 'hj1 'a1 'a2 [[1 1] [3 2]])
   _ (hpr dpf "h6" 'hj1 'a1 'a2 [[1 3] [3 4]])
   _ (hstep dpf "s8" 6 'hj1 'a1 'a2 'kh6 'g15)
   ; what fits under cap fits a word
   (cfit x p) ['inf-lelt x 'cap '(inf-pow w) p '(lz-cw w cap gc)]
   onk '(bz-nbr on kh3 cap g9 b1) onu '(bz-nbr on uh5 cap g19 b1)
   kn ['inf-lttrans 'kh6 '(add hj1 kh6) 'n
       '(inf-lttrans kh6 (add 1 kh6) (add hj1 kh6) (inf-lelts kh6 kh6 (inf-refl kh6)) (inf-addr 1 hj1 kh6 (inf-letrans 1 5 hj1 (idpath false) a1)))
       ['inf-letrans '(add hj1 kh6) '(natminus n si) 'n (hk 'hj1 'a2 'kh6 'g15) '(inf-suble n si)]]
   _ (map (r \ pin dpf (r 0) (r 1))
      [["m1-1" (nfit '(add si 3) ['bz-nbr 'si 3 'n 'g7 sile])] ["m1-2" onk] ["m1-3" (hin 3 'g7 'kh3 'g8)]
       ["s3-1" (cfit '(add on kh3) onk)] ["w0b-1" onk]
       ["h4-1" ['inf-lttrans '(add si 5) 'n '(inf-pow w) ['bz-nbq 'si 5 6 'n '(idpath true) 'g13 sile] '(inf-ltle n (inf-pow w) gn)]]
       ["h4-2" ['bz-nbq 'si 5 6 'n '(idpath true) 'g13 sile]]
       ["h7-1" (hin 'hj1 'a2 'kh6 'g15)]
       ["c4-2" (nfit '(add kh6 1) ['inf-lt1 'kh6 'n kn])]
       ["c4-3" '(inf-letrans 5 kh6 (add kh6 1) (c3e1 g20) (inf-leaddr kh6 1))]
       ["c4-10" (cfit '(add on uh5) onu)]])
   dec
    {'name "l2_dec" 'short "zxdec"
     'attrs '("static")
     'ret 'int
     'params '(("s" (ptr (const (named "uint8_t")))) ("n" (named "uintptr_t")) ("out" (ptr (named "uint8_t")))
               ("cap" (named "uintptr_t")) ("m" (ptr (struct "lz_model"))) ("pre" (named "uintptr_t")))
     'fields ()
     'arrays '((In (v "s") n) (Ob (v "out") cap))
     'requires
      '((In (pi x nat nat)) (Ob (pi x nat nat)) (Pr (pi x nat nat)) (Lt (pi x nat nat))
        (w nat) (n nat) (cap nat) (pre nat)
        (gw (inf-le 32 w))
        (gn (inf-lt n (inf-pow w)))
        (gc (inf-lt (add cap 8) (inf-pow w)))
        (gp (inf-le pre cap)))
     'decls
      '(((struct "lz_out") (o)) ((struct "lz_rd") (r))
        ((named "uintptr_t") (si 0) (on pre) (base 0) (k) (h) (u) (i) (st) (litn))
        (uint (c) (b) (x) (nd) (np 1)))
     'ensures ()
     'calls [props reset init run rnorm]
     'body
      [(oput 'o1 "b" ['var "out"]) (oput 'o2 "cap" ['var "cap"]) (oput 'o3 "pause" ['num 0])
       '(h0 havoc nd (raw (un not (var "pre"))))
       ['w0 'while '(tru) '(natminus n si) '((b1 (inf-le on cap)) (b2 (inf-le base on)))
        [(no 'i1 'g1 '(le n si))
         '(h1 havoc c (at In si))
         '(i2 if g2 (z c) ((i2a if g2a (eq on cap) ((r2 ret 0))) (r3 retneg 1)))
         '(h2 havoc x (raw (lor (bin le (num 224) (var "c")) (bin eq (var "c") (num 1)))))
         '(j0 join g3 (nz x) ((s0 set np 1) (s1 set nd 0) (s2 set base on))
           ((i3 if g4 (nz nd) ((r4 retneg 1)))) ((a0 (inf-le base on))))
         ['e1 'ife 'g5 '(lt c 128)
          [(no 'i4 'g6 '(lt 2 c))
           (no 'i5 'g7 '(lt (- n si) 3))
           ['h3 'havoc 'k (be2 'si 1)]
           (no 'i6 'g8 '(lt (- (- n si) 3) k))
           (no 'i7 'g9 '(lt (- cap on) k))
           '(m1 mcopy Ob on In (+ si 3) k)
           '(s3 set on (+ on k))
           '(s4 set si (+ si (+ 3 k)))]
          [['j1 'join 'g10 '(lt c 192)
            [(no 'i8 'g11 '(nz np)) (no 'i9 'g12 '(lt (- n si) 5)) '(s5 set h 5)]
            [(no 'i10 'g13 '(lt (- n si) 6))
             '(h4 havoc b (at In (+ si 5)))
             '(c1 calx x "lz_props" ((raw (var "m")) b 4) (w b (maxlclp 4)) ((lc lc) (lp lp) (pb pb)))
             (no 'i11 'g14 '(z x))
             '(s6 set np 0) '(s7 set h 6)]
            '((a1 (inf-le 5 h)) (a2 (inf-le h (natminus n si))))]
           ['h5 'havoc 'u be3]
           ['h6 'havoc 'k (be2 'si 3)]
           (no 'i12 'g15 '(lt (- (- n si) h) k))
           '(h7 have h7 (inf-le (add (add si h) k) n))
           ['h8 'havw 'litn litnx 'g16]
           (no 'i13 'g17 '(lt litn 768))
           '(j2 join g18 (lt 159 c) ((c2 call "lz_reset" ((raw (var "m"))) (w litn) ())) () ())
           (no 'i14 'g19 '(lt (- cap on) u))
           '(c3 calx x "rd_init" ((raw (addr (var "r"))) (raw (bin + (bin + (var "s") (var "si")) (var "h"))) k) (In (n k)) ())
           (no 'i15 'g20 '(z x))
           ['h9 'havoc 'st ['raw (cf "m" "state")]]
           (no 'i16 'g21 '(lt 11 st))
           (oput 'o4 "n" ['var "on"]) (oput 'o5 "base" ['var "base"])
           ; what no law reads of lz_run's fields goes as 0
           '(c4 calx x "lz_run" ((raw (var "m")) (raw (addr (var "r"))) (raw (addr (var "o"))) (+ on u) 0)
             (In Ob Pr Lt w (nin k) (i 5) cap on base st (r0 0) litn (lim (add on u)) (rg 0) (cd 0) (pz 0) (bd 0) (em 0)) ())
           (no 'i17 'g22 '(ne x 1))
           ['h10 'havoc 'on ['raw (of "n")]]
           (no 'i18 'g23 '(lt cap on))
           (no 'i19 'g24 '(lt on base))
           ['h11 'havoc 'i ['raw (rf "i")]]
           (no 'i20 'g25 '(lt k i))
           '(c5 call "rd_norm" ((raw (addr (var "r")))) (In w (n k)) ())
           ['h12 'havoc 'x ['raw ['lor ['lor (rf "bad") ['bin 'ne (rf "i") (rf "n")]] (rf "code")]]]
           (no 'i21 'g26 '(nz x))
           '(s8 set si (+ si (+ h k)))]]]]]
     'macros '()
     'proofs dpf}

   ; what slides a window down by a multiple of 16, the last dict bytes kept: how far
   slide
    {'name "lz_slide" 'short "zxslide"
     'attrs '("static")
     'ret '(named "uintptr_t")
     'params '(("win" (ptr (named "uint8_t"))) ("on" (named "uintptr_t")) ("dict" (named "uintptr_t")))
     'fields ()
     'arrays '((Ob (v "win") cap))
     'requires '((Ob (pi x nat nat)) (w nat) (cap nat) (on nat) (dict nat) (gw (inf-le 32 w))
                 (gc (inf-lt (add cap 8) (inf-pow w))) (go (inf-le on cap)))
     'decls '(((named "uintptr_t") (x)))
     'ensures '((e1 (inf-le res on)))
     'body
      ['(i1 if g1 (le on dict) ((r1 ret 0)))
       '(h1 havoc x (and64 (- on dict) (bnot 15)))
       '(i2 if g2 (lt on x) ((r2 ret 0)))
       '(m1 mmove Ob 0 Ob x (- on x))
       '(r3 ret x)]
     'macros '()
     'proofs {"m1-3" '(inf-letrans (add xh1 (natminus on xh1)) on cap (bz-nbr xh1 (natminus on xh1) on (inf-refl (natminus on xh1)) g2) go)}}
   (sf f) ['dot ['deref ['var "S"]] f]
   (sput l f e) [l 'raw ['expr ['asn (sf f) e]]]
   (out l v e) [l 'raw ['expr ['asn ['deref ['var v]] e]]]
   mdecl ['(ptr (struct "lz_model")) ['m ['raw ['addr (sf "m")]]]]
   ; room for need: the window slid where it is short
   (room J g C need)
    [[J 'join g ['lt '(- cap on) need]
       [[C 'calx 'sx "lz_slide" '((raw (var "win")) on dict) '(Ob w cap on dict) ()]
        [(intern "\(C)s") 'set 'on '(- on sx)]
        [(intern "\(C)j") 'join (intern "\(C)g") '(lt base sx) [[(intern "\(C)t") 'set 'base 0]] [[(intern "\(C)u") 'set 'base '(- base sx)]] [[(intern "\(C)v") '(inf-le base on)]]]]
       () [[(intern "\(J)a") '(inf-le on cap)] [(intern "\(J)b") '(inf-le base on)]]]
     (no (intern "\(J)i") (intern "\(J)h") ['lt '(- cap on) need])]
   ; one LZMA2 chunk into the cask's window: the bytes it put out, from *o0; -1 malformed, the state
   ; then torn. the end byte is the caller's
   spf {}
   _ (: eqle (A \ k \ g \ ['inf-letr A k A g ['inf-refl A]])
        k3 ['bz-nbr 3 'kh7 'n (eqle '(natminus n 3) 'kh7 'g9) 'g8]
        (hdr d) ['inf-lttrans d 5 'n '(idpath true) '(inf-letrans 5 hj1 n a1 a2)]
        hk ['bz-nbr 'hj1 'kh10 'n (eqle '(natminus n hj1) 'kh10 'g16) 'a2]
        kn ['inf-lttrans 'kh10 '(add hj1 kh10) 'n
            '(inf-lttrans kh10 (add 1 kh10) (add hj1 kh10) (inf-lelts kh10 kh10 (inf-refl kh10)) (inf-addr 1 hj1 kh10 (inf-letrans 1 5 hj1 (idpath false) a1))) hk]
      (map (r \ pin spf (r 0) (r 1))
       [["h7-1" '(inf-lttrans 1 3 n (idpath true) g8)] ["h7-2" '(inf-lttrans 2 3 n (idpath true) g8)]
        ["m1-1" '(bz-nbr onj3 kh7 cap j3h j3a)] ["m1-2" k3] ["h8-1" '(inf-lttrans 5 6 n (idpath true) g14)]
        ["h9-1" (hdr 1)] ["h9-2" (hdr 2)] ["h10-1" (hdr 3)] ["h10-2" (hdr 4)]
        ["c6-2" (nfit '(add kh10 1) ['inf-lt1 'kh10 'n kn])]
        ["c6-3" '(inf-letrans 5 kh10 (add kh10 1) (c5e1 g21) (inf-leaddr kh10 1))]
        ["c6-10" (cfit '(add onj4 uh9) '(bz-nbr onj4 uh9 cap j4h j4a))]
        ["c1jj-2" '(inf-submono basej0 onh2 sxc1 a0)] ["c4jj-2" '(inf-submono basej0 onh2 sxc4 a0)]
        ["c7-2" ['inf-lttrans 'kh10 'n '(inf-pow w) kn '(inf-ltle n (inf-pow w) gn)]]]))
   cstep
    {'name "l2_step" 'short "zxstep"
     'attrs '("static")
     'ret '(named "intptr_t")
     'params '(("S" (ptr (struct "l2_st"))) ("win" (ptr (named "uint8_t"))) ("s" (ptr (const (named "uint8_t"))))
               ("n" (named "uintptr_t")) ("o0" (ptr (named "uintptr_t"))))
     'fields ()
     'arrays '((In (v "s") n) (Ob (v "win") cap))
     'requires
      '((In (pi x nat nat)) (Ob (pi x nat nat)) (Pr (pi x nat nat)) (Lt (pi x nat nat))
        (w nat) (n nat) (cap nat) (dict nat)
        (gw (inf-le 32 w)) (gn (inf-lt n (inf-pow w))) (gc (inf-lt (add cap 8) (inf-pow w))))
     'decls
      [mdecl '((struct "lz_out") (o)) '((struct "lz_rd") (r))
       ['(named "uintptr_t") ['cap ['raw (sf "cap")]] ['dict ['raw (sf "dict")]] '(on) '(base) '(sx) '(k) '(h) '(u) '(i) '(st) '(litn)]
       '(uint (c) (b) (x) (nd) (np))]
     'ensures ()
     'calls [props reset init run rnorm slide]
     'body
      ([(no 'i0 'g0 '(z n))
        '(h1 havoc c (at In 0))
        (no 'i1 'g1 '(z c))
        ['h2 'havoc 'on ['raw (sf "n")]] ['h3 'havoc 'base ['raw (sf "base")]]
        ['h4 'havoc 'nd ['raw (sf "needdict")]] ['h5 'havoc 'np ['raw (sf "needprops")]]
        (no 'i2 'g2 '(lt cap on)) (no 'i3 'g3 '(lt on base))
        '(h6 havoc x (raw (lor (bin le (num 224) (var "c")) (bin eq (var "c") (num 1)))))
        '(j0 join g4 (nz x) ((s0 set np 1) (s1 set nd 0) (s2 set base on))
          ((i4 if g5 (nz nd) ((r4 retneg 1)))) ((a0 (inf-le base on))))
        (sput 'o1 "needdict" ['var "nd"])
        ['i5 'if 'g6 '(lt c 128)
         ([(no 'i6 'g7 '(lt 2 c)) (no 'i7 'g8 '(lt n 3))
           ['h7 'havoc 'k (be2 0 1)]
           (no 'i8 'g9 '(dif (- n 3) k))]
          + room 'j3 'g10 'c1 'k
          + ['(m1 mcopy Ob on In 3 k) (out 'o2 "o0" ['var "on"])
             (sput 'o3 "n" ['bin '+ ['var "on"] ['var "k"]]) (sput 'o4 "base" ['var "base"]) (sput 'o5 "needprops" ['var "np"])
             '(r5 ret k)])]
        ['j1 'join 'g11 '(lt c 192)
         [(no 'i9 'g12 '(nz np)) (no 'i10 'g13 '(lt n 5)) '(s5 set h 5)]
         [(no 'i11 'g14 '(lt n 6))
          '(h8 havoc b (at In 5))
          '(c2 calx x "lz_props" ((raw (var "m")) b 4) (w b (maxlclp 4)) ((lc lc) (lp lp) (pb pb)))
          (no 'i12 'g15 '(z x))
          '(s6 set np 0) '(s7 set h 6)]
         '((a1 (inf-le 5 h)) (a2 (inf-le h n)))]
        '(h9 havoc u (wadd (wor (wor (wshl (and64 c 31) 16) (wshl (u32 (at In 1)) 8)) (at In 2)) 1))
        ['h10 'havoc 'k (be2 0 3)]
        (no 'i13 'g16 '(dif (- n h) k))
        ['h11 'havw 'litn litnx 'g17]
        (no 'i14 'g18 '(lt litn 768))
        '(j2 join g19 (lt 159 c) ((c3 call "lz_reset" ((raw (var "m"))) (w litn) ())) () ())]
       + room 'j4 'g20 'c4 'u
       + [(out 'o6 "o0" ['var "on"])
        '(c5 calx x "rd_init" ((raw (addr (var "r"))) (raw (bin + (var "s") (var "h"))) k) (In (n k)) ())
        (no 'i15 'g21 '(z x))
        ['h12 'havoc 'st ['raw (cf "m" "state")]]
        (no 'i16 'g22 '(lt 11 st))
        (oput 'o7 "b" ['var "win"]) (oput 'o8 "n" ['var "on"]) (oput 'o9 "cap" ['var "cap"]) (oput 'o10 "base" ['var "base"]) (oput 'o11 "pause" ['num 0])
        '(c6 calx x "lz_run" ((raw (var "m")) (raw (addr (var "r"))) (raw (addr (var "o"))) (+ on u) 0)
          (In Ob Pr Lt w (nin k) (i 5) cap on base st (r0 0) litn (lim (add on u)) (rg 0) (cd 0) (pz 0) (bd 0) (em 0)) ())
        (no 'i17 'g23 '(ne x 1))
        ['h13 'havoc 'i ['raw (rf "i")]]
        (no 'i18 'g24 '(lt k i))
        '(c7 call "rd_norm" ((raw (addr (var "r")))) (In w (n k)) ())
        ['h14 'havoc 'x ['raw ['lor ['lor (rf "bad") ['bin 'ne (rf "i") (rf "n")]] (rf "code")]]]
        (no 'i19 'g25 '(nz x))
        (sput 'o12 "n" (of "n")) (sput 'o13 "base" ['var "base"]) (sput 'o14 "needprops" ['var "np"])
        '(r6 ret u)])
     'macros '()
     'proofs spf}
   ; a .lzma body's feed, n bytes at s, the rest of the last feed first: 0 corrupt, 1 paused for room with
   ; *used of them read, 2 done, 3 the rest kept in pin. the bytes out start at *o0
   lpf {}
   _ (map (r \ pin lpf (r 0) (r 1))
      [["s3-1" (cfit '(add onj1 rm) '(bz-nbr onj1 rm cap g9 a1))] ["j3j-3" '(bz-nbr onj1 rm cap g9 a1)]
       ["c3-4" '(inf-lelt (add ocj3 8) (add cap 8) (inf-pow w) (inf-addr ocj3 cap 8 a2) gc)]
       ["m2-3" '(bz-nbr ih9 (natminus n ih9) n (inf-refl (natminus n ih9)) g16)]])
   (zero l g c) [l 'if g c [[(intern "\(l)r") 'ret 0]]]
   known ['bin 'ne (sf "want") ['cast '(named "uint64_t") ['un 'neg ['num 1]]]]
   said-all ['land known ['bin 'eq (sf "tot") (sf "want")]]
   lmstep
    {'name "lm_step" 'short "zxlm"
     'attrs '("static")
     'ret 'int
     'params '(("S" (ptr (struct "lm_st"))) ("win" (ptr (named "uint8_t"))) ("s" (ptr (const (named "uint8_t"))))
               ("n" (named "uintptr_t")) ("last" uint) ("o0" (ptr (named "uintptr_t"))) ("used" (ptr (named "uintptr_t"))))
     'fields ()
     'arrays '((In (v "s") n) (Ob (v "win") cap) (Pin (v "pin") 24))
     'requires
      '((In (pi x nat nat)) (Ob (pi x nat nat)) (Pin (pi x nat nat)) (Pr (pi x nat nat)) (Lt (pi x nat nat))
        (w nat) (n nat) (cap nat) (dict nat) (last nat) (rm nat)
        (gw (inf-le 32 w)) (gn (inf-lt (add n 1) (inf-pow w))) (gc (inf-lt (add cap 8) (inf-pow w))))
     'decls
      [mdecl '((struct "lz_out") (o)) '((struct "lz_rd") (r))
       ['(ptr (named "uint8_t")) ['pin ['raw (sf "pin")]]]
       ['(named "uintptr_t") ['cap ['raw (sf "cap")]] ['dict ['raw (sf "dict")]] ['rm ['raw ['var "LM_ROOM"]]] '(on) '(sx) '(oc) '(oe) '(i) '(st) '(lim) '(litn)]
       '(uint (x) (y))]
     'ensures ()
     'calls [init run slide]
     'body
      [['h1 'havoc 'on ['raw (sf "n")]]
       (zero 'i1 'g1 '(lt cap on))
       '(j1 join g2 (le (- cap on) 273)
         ((c1 calx sx "lz_slide" ((raw (var "win")) on dict) (Ob w cap on dict) ()) (s1 set on (- on sx)))
         () ((a1 (inf-le on cap))))
       (sput 'o1 "n" ['var "on"]) (out 'o2 "o0" ['var "on"]) (out 'o3 "used" ['num 0])
       ['h2 'havoc 'y ['raw (sf "started")]]
       ['j2 'join 'g3 '(z y)
        [['i2 'if 'g4 '(lt n 5)
          [(zero 'i3 'g5 '(nz last)) '(m1 mcopy Pin 0 In 0 n)
           (sput 'o4 "pend" ['cast '(named "uint32_t") ['var "n"]]) '(r1 ret 3)]]
         '(c2 calx x "rd_init" ((raw (addr (var "r"))) (raw (var "s")) n) (In n) ())
         (zero 'i4 'g6 '(z x))
         (sput 'o5 "started" ['num 1])]
        [['o6 'raw ['expr ['asn (rf "p") ['var "s"]]]] ['o7 'raw ['expr ['asn (rf "i") ['num 0]]]] ['o8 'raw ['expr ['asn (rf "n") ['var "n"]]]]
         ['o9 'raw ['expr ['asn (rf "range") (sf "range")]]] ['o10 'raw ['expr ['asn (rf "code") (sf "code")]]] ['o11 'raw ['expr ['asn (rf "bad") ['num 0]]]]]
        ()]
       ['h3 'havoc 'i ['raw (rf "i")]]
       (zero 'i5 'g7 '(lt n i))
       ['h4 'havoc 'y ['raw said-all]]
       ['i6 'if 'g8 '(nz y)
        [(sput 'o12 "range" (rf "range")) (sput 'o13 "code" (rf "code")) (out 'o14 "used" ['var "i"]) (sput 'o15 "done" ['num 1]) '(r2 ret 2)]]
       '(j3 join g9 (lt (- cap on) rm) ((s2 set oc cap)) ((s3 set oc (+ on rm))) ((a2 (inf-le oc cap)) (a3 (inf-le on oc))))
       ['h5 'havw 'lim ['raw ['cond known ['bin '+ ['var "on"] ['cast '(named "uintptr_t") ['bin '- (sf "want") (sf "tot")]]] ['num 0]]] 'g10]
       ['h6 'havw 'litn litnx 'g11]
       (zero 'i7 'g12 '(lt litn 768))
       ['h7 'havoc 'st ['raw (cf "m" "state")]]
       (zero 'i8 'g13 '(lt 11 st))
       (oput 'o16 "b" ['var "win"]) (oput 'o17 "n" ['var "on"]) (oput 'o18 "cap" ['var "oc"]) (oput 'o19 "base" ['num 0])
       (oput 'o20 "pause" ['cond ['var "last"] ['num 2] ['num 1]])
       ['c3 'calx 'x "lz_run" ['(raw (var "m")) '(raw (addr (var "r"))) '(raw (addr (var "o"))) 'lim ['raw ['un 'not known]]]
        '(In Ob Pr Lt w (nin n) i (cap oc) on (base 0) st (r0 0) litn lim (rg 0) (cd 0) (pz 0) (bd 0) (em 0)) ()]
       (zero 'i9 'g14 '(z x))
       ['h8 'havoc 'y ['raw (rf "bad")]]
       (zero 'i10 'g15 '(nz y))
       ['h9 'havoc 'i ['raw (rf "i")]]
       (zero 'i11 'g16 '(lt n i))
       ['h13 'havoc 'oe ['raw (of "n")]]
       (zero 'i16 'g22 '(lt oc oe)) (zero 'i17 'g23 '(lt oe on))
       ['o21 'raw ['expr ['rmw '+ (sf "tot") ['bin '- ['var "oe"] ['var "on"]]]]]
       (sput 'o22 "n" ['var "oe"]) (sput 'o23 "range" (rf "range")) (sput 'o24 "code" (rf "code")) (out 'o25 "used" ['var "i"])
       '(h10 havoc y (raw (bin eq (var "x") (num 2))))
       ['j4 'join 'g17 '(eq x 1) [['h11 'havoc 'y ['raw said-all]]] () ()]
       ['i12 'if 'g18 '(nz y) [(sput 'o26 "done" ['num 1]) '(r3 ret 2)]]
       ['h12 'havoc 'y ['raw ['land ['land ['bin 'eq ['var "x"] ['num 1]] ['var "last"]] ['bin 'lt ['var "oe"] ['bin '- ['var "oc"] ['num 273]]]]]]
       (zero 'i13 'g19 '(nz y))
       '(i14 if g20 (ne x 3) ((r4 ret 1)))
       (zero 'i15 'g21 '(lt 24 (- n i)))
       '(m2 mcopy Pin 0 In i (- n i))
       (sput 'o27 "pend" ['cast '(named "uint32_t") '(bin - (var "n") (var "i"))])
       '(r5 ret 3)]
     'macros '()
     'proofs lpf}

   lz-specs [reset props init rnorm run walk dec slide cstep lmstep]
   lz-h (cats ["// lz_gen.h -- laid by src/love/compress/lz.l, `make mx`. edit that file.\n"
               (cats (map (s \ clay-show (cl-fn s)) lz-specs))])
   lz-ledger
    [["pointers" "lz_run's m, r and o, lz_reset's and lz_props's m, rd_init's n bytes at p, l2_walk's, l2_dec's, l2_step's and lm_step's n at s, the casks' windows of cap" "xz.c's callers hand them over whole: m from lz_new or a cask, r over the input, o over the window"]
     ["model" "the probabilities are struct lz_model's first 1846 words, lit 0x300 << (lc + lp) more, a count that fits" "xz.c's static asserts; lz_new and the casks size lit"]
     ["props" "m's lc, lp and pb are what lz_props proved lc <= 8, lp <= 4, pb <= 4 of" "its raw stores, and no other write: the coder's own are the encoder's, lc 4"]
     ["coder" "rd_norm's i <= n" "the guards of l2_dec and l2_step"]
     ["window" "on <= cap, base <= on, cap + 8 and nin + 1 fit" "held by l2_dec, l2_step and lm_step, n + 1 and cap + 8 from their callers, whose sizes XZ_MAX and a string's bound"]
     ["chunk" "rd_init answers 1 with r.i 5 and r.n n; the bad, code, want, tot and props fields are read raw" "its raw stores; a wrong one is a wrong answer, not a read outside"]
     ["raw" "a raw statement writes only r, m and o's fields, read again by no term" "lz.l's epilogue and rep moves"]
     ["word" "a word read back fits" "the C type; `havw` states it"]]
   (ledger-text l) (cats (map (r \ r @ [a b c] "; \(a): \(b) -- \(c)\n") l))
   lz-vc (cats ["; test/uuzxvc.l -- laid by src/love/compress/lz.l, `make mx`. edit that file.\n"
                "; the ledger: what the theorems leave open, each with who answers for it\n"
                (ledger-text lz-ledger)
                "(test\n"
                (cats (map (s \ cats (vc-text s)) lz-specs)) " )\n"])
   lz-ok (0 < #lz-vc && all (s \ clay-ok? (cl-fn s) = 1 && atom? (vc-open s) && atom? (vc-stale s)) lz-specs))
