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

   ; --- labels and proofs: a site's statements, guards and invariants each take a fresh name ------
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
     (bit base
      + [[J1 'join G1 '(z b)
          (lo 1 + t1 + [[L1 'set 'lv 'tv]])
          (bit (base + 1)
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
    (: f (bitf 'Lt 'ix) t (fr 't (f 0)) tb ['inf-mod 2 t]
     [['ri5 'if 'rg9 '(le (- on base) r0) (guard 0)]
      '(rh6 havoc mb (at Ob (- (- on r0) 1)))
      '(rs5 set sy 1)
      '(rh7 havoc off 256)
      ['rw1 'while '(lt sy 256) '(natminus 256 sy) '((rc1 (inf-le 1 sy)) (rc2 (inf-le i (add nin 1))))
       ('((rh8 havoc mb (wshl mb 1))
          (rh9 havoc mbit (and64 mb off))
          (rh10 havoc ix (wadd (wadd li (wadd off mbit)) sy)))
        + [['ri6 'if 'rg10 '(le litn ix) (guard 0)]]
        + f 1
        + step 'rs6 'rw1 'sy 256 tb t 'rc1 0
        + '((rh11 havoc off (and64 off (bxor (wsub 0 b) (bnot mbit))))))]])
   plain (tree 'Lt 'litn 'li 'lirh5 '(natminus litn 768) 'rg7 '(lz-sub768 litn gl) 256 'sy)
   lit-arm
    [['ri3 'if 'rg5 '(le cap on) (guard 0)]
     '(rj2 join rg6 (lt base on) ((rh3 havoc pv (at Ob (- on 1)))) ((rh4 havoc pv 0)) ())
     '(rh5 havoc li (wmul 768 (wadd (wshl (and64 on lpm) lc) (wshr pv (wsub 8 lc)))))
     ['ri4 'if 'rg7 '(lt (- litn 768) li) (guard 0)]
     ['rj3 'join 'rg8 '(le 7 st) matched plain '((ra1 (inf-le i (add nin 1))))]
     '(rp1 poke Ob on (w8 sy))
     '(rs4 set on (+ on 1))
     '(re2 ife rg20 (lt st 4) ((rs12 set st 0)) ((re3 ife rg21 (lt st 10) ((rs13 set st (- st 3))) ((rs14 set st (- st 6))))))]

   ; a match: its length, then its distance's slot, middle bits and low bits, or the end marker
   dist
    [['rh17 'havw 'fb '(wsub (wshr slot 1) 1) 'rg19]
      '(rh18 havoc d (wshl (wor 2 (and64 slot 1)) fb))
      ['rj7 'join 'rg22 '(lt slot 14)
       ('((rh19 havoc bx (wsub (wsub (wadd 688 d) slot) 1))) + rtree 'bx 'fb + '((rh20 havoc d (wadd d v))))
       ('((rh21 havw nd (wsub fb 4) rg23) (rh22 havoc v 0))
        + [['rf1 'for 'j 0 'nd '((ra7 (inf-le i (add nin 1))))
            (norm 0 + '((rh23 havoc rg (wshr rg 1)) (rh24 havoc t (wge cd rg))
                        (rh25 havoc cd (wsub cd (and64 rg (wsub 0 t)))) (rh26 havoc v (wor (wshl v 1) t))))]]
        + '((rh27 havoc d (wadd d (wshl v 4))))
        + rtree ALIGN 4
        + '((rh28 havoc d (wadd d v))))
       '((ra6 (inf-le i (add nin 1))))]]
   (len1 j l) (prove "\(j)j" 3 ['inf-letrans 1 2 ['add l 2] '(idpath false) ['inf-leaddl 2 l]])
   normal
    (: x (lenf LEN) _ (len1 'rj4 (tl 'lv))
     (x
     + '((rs7 set len (+ lv 2)) (rs8 set kind 0)
         (rj5 join rg12 (lt lv 3) ((rh12 havoc lx lv)) ((rh13 havoc lx 3)) ())
         (rh14 havoc sb (wadd 432 (wshl lx 6))))
     + [['ri7 'if 'rg13 '(lt 624 sb) (guard 0)]]
     + tree 'Pr NP 'sb 'sbrh14 624 'rg13 '(idpath false) 64 'slot
     + [['rj6 'join 'rg14 '(lt slot 4) '((rh15 havoc d slot)) dist '((ra5 (inf-le i (add nin 1))))]
        ['ri8 'if 'rg15 '(eq d 4294967295)
         '((re4 ife rg16 (nz em) ((re5 ife rg17 (le i nin) ((rs9 set rc 2)) ((rs10 set rc 0)))) ((rs11 set rc 0)))
           (rk2 brk))]
        (cput (repk 3) (repk 2)) (cput (repk 2) (repk 1)) (cput (repk 1) ['cast u32 ['var "r0"]])
        '(rh16 havw r0 d rg18)]))
   ; a rep: rep0 short (one byte) or long, or rep 1 to 3 moved to the front
   rep
    (bit ['+ 'st ISG0]
     + [['rj8 'join 'rg24 '(z b)
         (bit ['+ 'sx REP0L] + '((rj9 join rg25 (z b) ((rs15 set sh 1)) ((rs16 set sh 0)) ((ra8 (inf-le sh 1)) (ra9 (inf-le i (add nin 1)))))))
         ('((rs17 set sh 0)) + bit ['+ 'st ISG1]
          + [['rj10 'join 'rg26 '(z b) [['rh29 'havoc 'd ['raw (repk 1)]]]
              (bit ['+ 'st ISG2]
               + [['rj11 'join 'rg27 '(z b) [['rh30 'havoc 'd ['raw (repk 2)]]]
                   [['rh31 'havoc 'd ['raw (repk 3)]] (cput (repk 3) (repk 2))]
                   '((ra10 (inf-le i (add nin 1))))]
                  (cput (repk 2) (repk 1))])
              '((ra11 (inf-le i (add nin 1))))]
             (cput (repk 1) ['cast u32 ['var "r0"]])
             '(rh32 havw r0 d rg28)])
         '((ra12 (inf-le i (add nin 1))) (ra13 (inf-le sh 1)))]
        ['rj12 'join 'rg29 '(z sh)
         (: x (lenf REPLEN) _ (len1 'rj12 (tl 'lv)) (x + '((rs18 set len (+ lv 2)) (rs19 set kind 1))))
         '((rs20 set len 1) (rs21 set kind 2))
         '((ra14 (inf-le i (add nin 1))) (ra15 (inf-le kind 2)) (ra16 (inf-le 1 len)))]])
   ; the copy, len bytes from r0 + 1 back: whole words where they cannot overlap and room follows
   wide '((rs22 set ck 0)
          (rw2 while (lt ck len) (natminus len ck) ()
           ((rp2 pokew Ob (+ on ck) (ld64 Ob (- (+ on ck) (+ r0 1))))
            (rs23 set ck (+ ck 8)))))
   (bytes L S P T) [[S 'set 'ck 0]
                    [L 'while '(lt ck len) '(natminus len ck) ()
                     [[P 'poke 'Ob '(+ on ck) '(at Ob (- (+ on ck) (+ r0 1)))]
                      [T 'set 'ck '(+ ck 1)]]]]
   match-arm
    (bit ['+ 'st ISREP]
     + [['rj4 'join 'rg11 '(z b) normal rep
         '((ra2 (inf-le i (add nin 1))) (ra3 (inf-le kind 2)) (ra4 (inf-le 1 len)))]
        ['ri9 'if 'rg30 '(le (- on base) r0) (guard 0)]
        ['ri10 'if 'rg31 '(lt nin i) (guard 0)]
        ['ri11 'if 'rg32 '(lt top on) (guard 0)]
        ['ri12 'if 'rg33 '(lt (- top on) len) (guard 0)]
        ['rj13 'join 'rg34 '(wide (+ r0 1))
         [['rj14 'join 'rg35 '(le (+ len 8) (- cap on)) wide (bytes 'rw3 'rs24 'rp3 'rs25) ()]]
         (bytes 'rw4 'rs26 'rp4 'rs27)
         ()]
        '(rs28 set on (+ on len))
        '(re6 ife rg36 (lt st 7) ((rs29 set st (+ 7 kind))) ((re7 ife rg37 (z kind) ((rs30 set st 10)) ((rs31 set st 11)))))])
   run-body
    ('((rh1 havoc t0 (and64 on pbm)) (rs1 set ps (low t0 15)))
     + [['ri1 'if 'rg1 '(lt nin i) (guard 0)]
        ['rj1 'join 'rg2 '(eq pz 1) [['ri2 'if 'rg3 '(lt (- nin i) 20) '((rs2 set rc 3) (rk1 brk))]] () ()]
        '(rs3 set sx (+ (shl st 4) ps))
        '(rh2 have rh2 (inf-le sx 191))]
     + bit 'sx
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
           run-body]
          (cput (cf "r" "range") ['cast u32 ['var "rg"]])
          (cput (cf "r" "code") ['cast u32 ['var "cd"]])
          (cput (cf "r" "bad") ['bin 'lt ['var "nin"] ['var "i"]])
          (cput (cf "r" "i") ['cond ['bin 'lt ['var "nin"] ['var "i"]] ['var "nin"] ['var "i"]])
          (cput (cf "m" "state") ['cast 'uint ['var "st"]])
          (cput (repk 0) ['cast u32 ['var "r0"]])
          (cput (cf "o" "n") ['var "on"])
          '(rr1 ret rc)])
     'macros '()
     'proofs pf}

   lz-specs [run]
   lz-h (cats ["// lz_gen.h -- laid by src/love/compress/lz.l, `make mx`. edit that file.\n"
               (cats (map (s \ clay-show (cl-fn s)) lz-specs))])
   lz-ledger
    [["pointers" "lz_run's m, r and o" "xz.c's callers hand them over whole: m from lz_new or a cask, r over the input, o over the window"]
     ["model" "the probabilities are struct lz_model's first 1846 words, lit 0x300 << (lc + lp) more, a count that fits" "xz.c's static asserts; lz_new and the casks size lit"]
     ["props" "lc <= 8, lp <= 4, pb <= 4" "lz_props, which every caller passes the byte through"]
     ["window" "on <= cap, base <= on, cap + 8 and nin + 1 fit" "l2_dec and lzma_feed lay o and r so"]
     ["raw" "a raw statement writes only r, m and o's fields, read again by no term" "lz.l's epilogue and rep moves"]
     ["word" "a word read back fits" "the C type; `havw` states it"]]
   (ledger-text l) (cats (map (r \ r @ [a b c] "; \(a): \(b) -- \(c)\n") l))
   lz-vc (cats ["; test/uuzxvc.l -- laid by src/love/compress/lz.l, `make mx`. edit that file.\n"
                "; the ledger: what the theorems leave open, each with who answers for it\n"
                (ledger-text lz-ledger)
                "(test\n"
                (cats (map (s \ cats (vc-text s)) lz-specs)) " )\n"])
   lz-ok (0 < #lz-vc && all (s \ clay-ok? (cl-fn s) = 1 && atom? (vc-open s) && atom? (vc-stale s)) lz-specs))
