; apps/lux/core.l -- the pure StackSet: the window model, no X and no sockets. This is
; xmonad's StackSet.hs, single-screen: a focus zipper per workspace holding every
; window on it, floats included, and a floating map (window -> rect) carrying
; geometry alone. One focus, one home tag, no second copy to drift. Pure -- so it
; rides the corpus on every target (test/law/lux.l asserts the invariants), and the
; driver (apps/lux/lux.l) + the X layers build on it.
;
; tools/wm2uu.l reads this file as data and keys on the post-opfix tree --
; cap/cup chains (the glued accessors factor to them), ></+/!=, and the literal
; shape (cap (cup (cup z))). a rewrite that changes the tree, even value-equal,
; must teach the translator first or test/host/overlay.l's leg 6 stops certifying.
;
; a body-less top-level `:` -- every binding leaks to the global scope, so the
; other apps/lux/ files see this vocabulary once concatenated. names shadow no
; nif; the wm vocabulary is `z*` (the zipper) and `ws*`/admit/evict/shiftto/
; shiftwin (the sheaf).
(:
   ; --- the app's own list utility ---
   (afind pred l) (? (atom? l) () (pred <l) <l (afind pred >l))    ; first element satisfying pred, else ()

   ; --- the zipper: a workspace's tiled stack. () or (focus up down), up reversed
   ;     (nearest-first), so focus motion is O(1) at either end. ---
   (zmk f up dn) [f up dn]
   (zfoc z) (two? z ? <z)                                     ; the focused window (() if empty)
   (zrow z) (two? z ? (rev <>z + (<z . <>>z)))               ; the stack as an ordered row, master first
   (zfrom l) (two? l ? (zmk <l () >l))                        ; a row -> a zipper, head focused
   (zrev z) (two? z ? (zmk <z <>>z <>z))                      ; mirror: up <-> down
   (zfocup z) (? !(two? z) ()                                      ; focus up, wrapping to the bottom
                 (: up <>z
                    (? (two? up) (zmk <up >up (<z . <>>z))
                       (: all (rev (<z . <>>z)) (zmk <all >all ())))))
   (zfocdn z) (zrev (zfocup (zrev z)))                             ; focus down = mirrored focus up
   (zswapup z) (? !(two? z) ()                                     ; swap the focused window upward
                  (: up <>z
                     (? (two? up) (zmk <z >up (<up . <>>z))
                        (zmk <z (rev <>>z) ()))))                  ; at the top: rotate to the bottom
   (zswapdn z) (zrev (zswapup (zrev z)))
   (zmaster z) (!(two? z) ? () (zmk <z () (rev <>z + <>>z)))       ; focused becomes master
   (zins w z) (two? z ? (zmk w <>z (<z . <>>z)) (zmk w () ()))  ; insert above the focus, focused
   (znub w l) (filter (x \ x != w) l)
   (zdel w z) (? !(two? z) ()                                      ; delete w; focus falls down, then up
                 (: f <z up (znub w <>z) dn (znub w <>>z)
                    (? (f != w) (zmk f up dn)
                       (two? dn) (zmk <dn up >dn)
                       (two? up) (zmk <up >up ())
                       ())))
   (zhas? w z) (any (x \ x = w) (zrow z))
   (zfromrow row f) (: (go up m) (? !(two? m) ()                   ; a row -> a zipper focused at f (() if absent)
                                    (<m = f) (zmk f up >m)
                                    (go (<m . up) >m))
                       (go () row))
   (zfocto w z) (zhas? w z ? (zfromrow (zrow z) w) z)            ; focus the named window (Go dir's StackSet half)
   (zswapw a b z) (? (zhas? a z && zhas? b z)                      ; exchange a and b in place; focus follows its window
                     (zfromrow (map (x \ (? (x = a) b (x = b) a x)) (zrow z)) (zfoc z)) z)

   ; --- the sheaf: (cur board floating). board = ((tag zipper)..), one tag
   ;     current. a zipper holds EVERY window on its workspace, floats included,
   ;     in ring order; floating = an alist ((window rect)..), geometry alone.
   ;     a window's workspace is structural -- whichever zipper holds it -- so
   ;     there is one focus and one home tag, never a second copy to drift. ---
   (sheaf tags) [<tags (map (t \ [t ()]) tags) ()]
   (wscur sh) <sh
   (wsboard sh) <>sh
   (wsfloat sh) <>>sh
   (wsmake cur board float) [cur board float]
   (wsknown? sh t) (any (p \ <p = t) (wsboard sh))
   (wsget sh t) (: p (assoc t (wsboard sh)) (two? p ? <>p))   ; the tag's zipper
   (wsset sh t z) (wsmake (wscur sh) (map (p \ (<p = t ? [t z] p)) (wsboard sh)) (wsfloat sh))
   (wsview sh t) (wsknown? sh t ? (wsmake t (wsboard sh) (wsfloat sh)) sh)   ; switch current (only the tag turns)
   (wsring sh) (zrow (wsget sh (wscur sh)))                        ; the focus ring: every window here, tiles and floats alike
   (wsfoc sh) (zfoc (wsget sh (wscur sh)))                         ; the focused window -- a float names itself
   (wsmap sh f) (wsset sh (wscur sh) (f (wsget sh (wscur sh))))    ; reshape the current zipper

   ; --- floating (xmonad's W.float / W.sink): the alist carries geometry only,
   ;     so lifting a window never moves it in the ring and sinking it never
   ;     moves it back. ---
   (wsunfl w fl) (filter (p \ <p != w) fl)                       ; drop w from the floating alist
   (wsfloating? sh w) (any (p \ <p = w) (wsfloat sh))            ; w is floating?
   (wsrect sh w) (: p (assoc w (wsfloat sh)) (two? p ? <>p))  ; w's float rect, or ()
   (wsflhere sh) (filter (w \ wsfloating? sh w) (wsring sh))     ; the floats on the current view, ring order
   (wsvisfl sh) (map (w \ [w (wsrect sh w)]) (wsflhere sh))      ; ...as (window rect), what the painter wants
   (wsdofloat sh w r)                                              ; float: pin a rect on a window already in the ring
    (wsknownw? sh w ? (wsmake (wscur sh) (wsboard sh) ([w r] . wsunfl w (wsfloat sh))) sh)
   (wssink sh w) (wsmake (wscur sh) (wsboard sh) (wsunfl w (wsfloat sh)))   ; sink: drop the rect, the window has not moved

   ; --- the tiled half, derived. the layout sees a zipper with the floats
   ;     filtered out (W.filter: a deleted focus falls down, then up). ---
   (wstilez sh) (foldl (\ z w (zdel w z)) (wsget sh (wscur sh)) (wsflhere sh))
   (wsrow sh) (zrow (wstilez sh))                                  ; the current tiled row, ordered, master first
   (wsztile sh zop)                                                ; run a zipper op on the TILED subsequence; floats keep their slots
    (: f (wsfoc sh)
       (? (!f || wsfloating? sh f) sh
          (: z (zfromrow (wsrow sh) f)
             (? !z sh
                (: ts (zrow (zop z)) row (wsring sh)
                   (fill m r) (? !(two? m) ()
                                 (wsfloating? sh <m) (<m . fill >m r)
                                 (<r . fill >m >r))
                   (wsmap sh (zz \ zfromrow (fill row ts) f)))))))
   (wsmaster sh) (wsztile sh zmaster)                              ; the focused tile fronts the tiled row
   (wsswapup sh) (wsztile sh zswapup)
   (wsswapdn sh) (wsztile sh zswapdn)

   ; --- managing windows across the whole sheaf ---
   (wsallw sh) (foldl (\ a p (a + zrow <>p)) () (wsboard sh))      ; every managed window, all workspaces
   (wstiled sh) (filter (w \ !(wsfloating? sh w)) (wsallw sh))     ; every tiled window
   (wsfloatw sh) (filter (w \ wsfloating? sh w) (wsallw sh))       ; every floating window
   (wswins sh) (wstiled sh + wsfloatw sh)                          ; tiles then floats: the stacking order a pager reads, bottom to top
   (wsknownw? sh w) (any (x \ x = w) (wsallw sh))
   (wsdelw sh w) (map (p \ [<p (zdel w <>p)]) (wsboard sh))        ; drop w from every workspace's zipper
   (wstagof sh w) (: r (filter (p \ zhas? w <>p) (wsboard sh))     ; the tag holding w, or ()
                     (two? r ? <<r))
   (admit sh w) (wsknownw? sh w ? sh (wsmap sh (zins w)))        ; manage w into the current ws (a no-op if already managed)
   (evict sh w) (wsmake (wscur sh) (wsdelw sh w) (wsunfl w (wsfloat sh)))   ; unmanage w everywhere
   (shiftwin sh w t) (? !(wsknown? sh t && wsknownw? sh w && (t != wstagof sh w)) sh
                        (: d (wsmake (wscur sh) (wsdelw sh w) (wsfloat sh))   ; one path: a float emigrates with its rect
                           (wsset d t (zins w (wsget d t)))))                 ; and arrives focused on t
   (shiftto sh t) (shiftwin sh (wsfoc sh) t)                       ; the focused window emigrates to tag t; we stay
   (wssane? sh) (wsknown? sh (wscur sh) && znodup? (wsallw sh)     ; the StackSet invariant: no window twice,
                  && all (p \ wsknownw? sh <p) (wsfloat sh))       ; and no rect without a window
   (znodup? l) (? !(two? l) 1 (any (x \ x = <l) >l) 0 (znodup? >l)))
