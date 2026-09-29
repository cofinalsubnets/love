; src/apps/caja/page.l -- caja's \vsplit: a vertical list broken into a page and the rest.
; `(borrow 'caja-page)`. tex.web part 44 (967-979), section for section:
;
;   (cg-vsplit J v h)         v a vbox (or ()), h the height; answers [page rest], the page
;                             packed to h at \splitmaxdepth, the rest a vbox or () when v is spent
;   (cg-vert-break J p h d)   the best break in the vlist p for height h, depth d; () for the end
;   (cg-prune-top J p)        p less its leading glue, kerns and penalties, \splittopskip ahead
;
; marks and inserts are not ported; a vlist with neither splits as TeX splits it.
(module (caja-page cg-vsplit cg-vert-break cg-prune-top)
(borrow 'caja-box)
(borrow 'caja-par)
(:
   awful 1073741823
   max-dimen 1073741823
   (P J k) (J 'params k)
   (same? a b) (a != () && b != () && a 'id = b 'id)
   (spec-of g) (? (g = ()) (cp-spec 0 0 0 0 0) g)

   (cg-prune-top J p0)
    (: head {'type 'head 'link p0}
       (go prev p)
        (? (p = ()) ()
           (: y (p 'type)
              (? (y <= 2)
                  (: s (spec-of (P J 'splittopskip))
                     w (? (s 'width > p 'height) (s 'width - p 'height) 0)
                     q (cp-node J {'type 10 'sub 11 'glue (cp-spec w (s 'stretch) (s 'sto) (s 'shrink) (s 'sho))
                                   'leader () 'link p})
                     (pin prev 'link q))
                 (elem y [3 4 8]) (go p (p 'link))
                 (: nx (p 'link) _ (pin p 'link ()) _ (pin prev 'link nx) (go prev nx)))))
       _ (go head p0)
       (head 'link))

   (cg-vert-break J p0 h d)
    (: ah {1 0 2 0 3 0 4 0 5 0 6 0}
       S {'least awful 'best () 'pd 0}
       (cur _) (ah 1)
       (add k v) (pin ah k (ah k + v))
       ; the badness of a page ending here, awful_bad if it is too full
       (bad _)
        (? (cur 0 < h) (? (ah 3 != 0 || ah 4 != 0 || ah 5 != 0) 0 (cb-badness (h - cur 0) (ah 2)))
           (cur 0 - h > ah 6) awful
           (cb-badness (cur 0 - h) (ah 6)))
       ; a champion check at a break of penalty pi; answers 1 when the search is over
       (champ p pi)
        (? (pi < 10000)
           (: b0 (bad 0)
              b (? (b0 < awful) (? (pi <= -10000) pi (b0 < 10000) (b0 + pi) 100000) b0)
              _ (? (b <= S 'least) (: _ (pin S 'best p) (pin S 'least b)))
              (b = awful || pi <= -10000))
           0)
       (heights p)
        (: q (? (p 'type = 11) p
                (: g (p 'glue)
                   _ (add (2 + g 'sto) (g 'stretch)) _ (add 6 (g 'shrink))
                   (? (g 'sho != 0 && g 'shrink != 0)
                      (: g2 (cp-spec (g 'width) (g 'stretch) (g 'sto) (g 'shrink) 0) _ (pin p 'glue g2) g2)
                      g)))
           _ (add 1 (S 'pd + q 'width))
           (pin S 'pd 0))
       (settle _) (? (S 'pd > d) (: _ (add 1 (S 'pd - d)) (pin S 'pd d)))
       (go prev p)
        (? (p = ()) (: _ (champ () -10000) (S 'best))
           (: y (p 'type)
              ; pi, or 'nf (not a break), or 'uh (glue or kern that is no break)
              pi (? (y <= 2) (: _ (add 1 (S 'pd + p 'height)) _ (pin S 'pd (p 'depth)) 'nf)
                    (y = 10) (? (prev 'type < 9) 0 'uh)
                    (y = 11) (: t (? (p 'link = ()) 12 (p 'link 'type)) (? (t = 10) 0 'uh))
                    (y = 12) (p 'penalty)
                    'nf)
              (? (pi = 'nf) (: _ (settle 0) (go p (p 'link)))
                 (pi = 'uh) (: _ (heights p) _ (settle 0) (go p (p 'link)))
                 (champ p pi) (S 'best)
                 (: _ (? (y = 10 || y = 11) (heights p)) _ (settle 0) (go p (p 'link))))))
       (go p0 p0))

   (cg-vsplit J v h)
    (? (v = ()) [() ()]
       (: p (v 'list) d (P J 'splitmaxdepth)
          q (cg-vert-break J p h d)
          (cut n) (? (same? (n 'link) q) (pin n 'link ()) (n 'link = ()) () (cut (n 'link)))
          first (? (same? p q) () (: _ (? (p != ()) (cut p)) p))
          q2 (cg-prune-top J q)
          rest (? (q2 = ()) () (cp-node J (cb-vpackage J q2 0 'additional max-dimen)))
          [(cp-node J (cb-vpackage J first h 'exactly d)) rest])))
) ; module caja-page
