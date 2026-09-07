; tools/wm2uu.l -- stage 3 of the verified-lux ladder: the .l -> uu translator.
; Reads apps/lux/core.l's zipper ops as data and emits uu terms in the model's
; vocabulary, kind-directed by apps/lux/sigs.l (the overlay's boundary table is
; the type oracle): a cap on a zipper is zfoc, on a row hd0; cap-of-cup is zup,
; cap-of-cup-of-cup is zdn (the glued <>z / <>>z factor to those chains);
; ></link and +/cat/rev are ncons/lapp/lrev; a two? test cases on a
; row's length (nat_rect) or witnesses a zipper nonempty (the model's stk IS
; the nonempty zipper, so core.l's ()-lane erases -- zins's make-a-singleton
; else included); =/!= case through bool_rect on nateqb; local (: ..) chains
; become definitional lets; znub's filter shape is nfilt; zdel answers the
; model's Maybe (a zipper result wraps ii2, the bare () becomes ii1 tt).
; The output defn-certifies in the kernel (boot/post.l leg 6), answers the
; seeded fuzz exactly as core.l does, and lands convertible with the hand
; model -- stage 4's idpath bridges ride that. (wm2uu forms sigs) answers
; ((gen-name uu-type uu-term) ..) for the twelve ops in w2-want.
;
; a body-less `:` -- the w2-* vocabulary leaks; none shadows a nif.
(:
   (w2-sigof sigs nm) (? (one? sigs) ()
                         (nm = <<sigs) <sigs
                         (w2-sigof >sigs nm))
   (w2-zip ps ks) (two? ps ? ([<ps <ks] . w2-zip >ps >ks))
   ; the list ctor: `list` is what [..] and the ` sigil read to.
   (w2-list? 'list) 1
   ; and so does negation: `!` is the sigil, `nil?` what opfix factors it to.
   ; the forms arrive factored, so match the core word and the surface one both.
   (w2-not? ('! || 'nil?)) 1
   ; ..and the pair ops: >< is link, + is cat on a row. both spellings match.
   (w2-link? ('>< || 'link || '.)) 1
   (w2-cat? ('+ || 'cat)) 1

   ; --- kinds -> the model's types; zdel is the one Maybe op ---
   (w2-ty k) (k @ 'window 'nat 'zipper 'stk 'wrow 'nlist 'nat)
   (w2-mty rk) (rk @ 'mstk 'mstk 'zipper 'stk 'wrow 'nlist 'window 'nat rk)
   (w2-pi ps ks res) (one? ps ? res ['pi <ps (w2-ty <ks) (w2-pi >ps >ks res)])
   (w2-lams ps b) (one? ps ? b ['lam <ps (w2-lams >ps b)])

   ; --- the wanted ops and their emitted names. zmk/zfoc are not wanted:
   ;     they are the representation vocabulary the rules target (a generated
   ;     zfoc would be (lam z (zfoc z)), a self-reference) -- they live in
   ;     test/uu.l's substrate. the name map is a slot so a driver can emit
   ;     under gen-* names (the gate's bridges) or the model's own names
   ;     (stage 5's test/uuwm.l) ---
   w2-want '(zrow zrev zfocup zfocdn zswapup zswapdn zmaster zins znub zdel)
   w2-gmap '((zrow gen-zrow) (zrev gen-zrev)
             (zfocup gen-zfocup) (zfocdn gen-zfocdn) (zswapup gen-zswapup)
             (zswapdn gen-zswapdn) (zmaster gen-zmaster) (zins gen-zins)
             (znub gen-znub) (zdel gen-zdel))
   w2-nm {0 w2-gmap}
   (w2-gen nm) (: p (assoc nm (w2-nm 0)) (two? p ? <>p nm))
   (wm2uu-as forms sigs gmap) (: _ (pin w2-nm 0 gmap)
                                  r (wm2uu forms sigs)
                                  _ (pin w2-nm 0 w2-gmap)
                                  r)
   (w2-rk nm k) (nm @ 'zdel 'mstk k)

   ; --- the kind of a source expression (enough to steer the rules) ---
   (w2-kof e env sigs)
    (? (nom? e) (: p (assoc e env) (two? p ? <>p 'top))
       (charm? e) 'window
       (one? e) 'top
       (: h <e
          (? (h = 'cap)
              (: a <>e
               (two? a && <a = 'cup ? 'wrow          ; a cap-of-cup chain: the up/down row
                (: k (w2-kof a env sigs)
                 (k @ 'zipper 'window 'wrow 'window 'top))))
             (h = 'cup)  'wrow
             (h = 'rev) 'wrow (w2-cat? h) 'wrow (w2-link? h) 'wrow
             (h = 'filter) 'wrow (w2-list? h) 'zipper
             (: sg (w2-sigof sigs h) (two? sg ? <>>sg 'top)))))

   ; --- the translation. rk = the result kind at this position ---
   (w2-nil rk) (rk @ 'mstk '(ii1 tt) 'nnil)
   (w2-tx e env sigs rk)
    (? (nom? e) e
       (charm? e) e
       (one? e) (w2-nil rk)
       (: h <e
          (? (h = '?) (w2-cond >e env sigs rk)
             (h = ':) (w2-lets >e env sigs rk)
             (rk = 'mstk) ['ii2 (w2-app e env sigs 'zipper)]
             (w2-app e env sigs rk))))
   (w2-app e env sigs rk)
    (: h <e
       (? (h = 'cap && two? <>e && <<>e = 'cup)
            ; the glued chains: <>z is (cap (cup z)) -> zup, <>>z one cup deeper -> zdn
            (: in <><>e
               (? (two? in && <in = 'cup)
                  ['zdn (w2-tx <>in env sigs 'zipper)]
                  ['zup (w2-tx in env sigs 'zipper)]))
          (h = 'cap)
            (: k (w2-kof <>e env sigs)
               [(k @ 'zipper 'zfoc 'hd0) (w2-tx <>e env sigs k)])
          (h = 'cup) ['tl0 (w2-tx <>e env sigs 'wrow)]
          (w2-link? h) ['ncons (w2-tx <>e env sigs 'window)
                               (w2-tx <>>e env sigs 'wrow)]
          (w2-cat? h) ['lapp (w2-tx <>e env sigs 'wrow)
                             (w2-tx <>>e env sigs 'wrow)]
          (h = 'rev) ['lrev (w2-tx <>e env sigs 'wrow)]
          (w2-list? h) ['zmk (w2-tx <>e env sigs 'window)
                             (w2-tx <>>e env sigs 'wrow)
                             (w2-tx <>>>e env sigs 'wrow)]
          (h = 'filter)                              ; (filter (\ x (x != w)) l) -> nfilt
            (: fn <>e bd <>>fn     ; the body wears != or (nil? (= ..))
               wex (<bd = '!= ? <>>bd <>><>bd)
               ['nfilt (w2-tx wex env sigs 'window)
                       (w2-tx <>>e env sigs 'wrow)])
          (: sg (w2-sigof sigs h)
             (two? sg ? (w2-gen h . w2-args >e <>sg env sigs)
                        (h . map (a \ w2-tx a env sigs 'top) >e)))))
   (w2-args as ks env sigs)
    (two? as ? (w2-tx <as env sigs <ks . (w2-args >as >ks env sigs)))
   (w2-cond cs env sigs rk)
    (one? >cs ? (w2-tx <cs env sigs rk)
     (: t <cs r <>cs rest >>cs
        els (two? >rest ? ('? . rest) <rest)
      (w2-if t r els env sigs rk)))
   (w2-if t then-x else-x env sigs rk)
    (? (two? t && w2-not? <t) (w2-if <>t else-x then-x env sigs rk)
       (two? t && <t = 'two?)
         (: x <>t
            (? (w2-kof x env sigs = 'zipper)
               (w2-tx then-x env sigs rk)                ; nonempty by kind: the ()-lane erases
               ['nat_rect ['lam 'gq (w2-mty rk)]
                  (w2-tx else-x env sigs rk)
                  ['lam 'gk ['lam 'gr (w2-tx then-x env sigs rk)]]
                  ['pr1 (w2-tx x env sigs 'wrow)]]))
       (two? t && <t = '=)
         ['bool_rect ['lam 'gx (w2-mty rk)]
            (w2-tx then-x env sigs rk)
            (w2-tx else-x env sigs rk)
            ['nateqb (w2-tx <>t env sigs 'window)
                     (w2-tx <>>t env sigs 'window)]]
       (two? t && <t = '!=) ; != is = with the arms traded
         ['bool_rect ['lam 'gx (w2-mty rk)]
            (w2-tx else-x env sigs rk)
            (w2-tx then-x env sigs rk)
            ['nateqb (w2-tx <>t env sigs 'window)
                     (w2-tx <>>t env sigs 'window)]]
       'w2-untranslatable)
   (w2-lets bs env sigs rk)
    (one? >bs ? (w2-tx <bs env sigs rk)
       (: x <bs v <>bs k (w2-kof v env sigs)
          ['let x (w2-tx v env sigs k)
             (w2-lets >>bs ([x k] . env) sigs rk)]))

   ; --- the driver: fish the wanted pairs out of core.l's forms ---
   (w2-pairs (a . b . c)) ([a b] . w2-pairs c)
   (w2-find nm forms)
    (: prs (foldl (\ a f (two? f && <f = ': ? (a + w2-pairs >f) a)) () forms)
       hit (filter (((^nm . _) . _) \ 1) prs)
       (two? hit ? <hit))
   (wm2uu forms sigs)
    (map (\ nm (: pr (w2-find nm forms)
                  sg (w2-sigof sigs nm)
                  ps ><pr
                  ks <>sg
                  [(w2-gen nm)
                   (w2-pi ps ks (w2-mty (w2-rk nm <>>sg)))
                   (w2-lams ps (w2-tx (caup pr) (w2-zip ps ks) sigs (w2-rk nm <>>sg)))]))
         w2-want))
