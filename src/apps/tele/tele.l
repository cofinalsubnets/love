; tele -- reverse-mode autograd in love over trays. an op is a lens: its value and a
; closure from the output cotangent to its inputs'; back walks the lenses backward from 1.
; pure love, no nif. load with -l after the prel; the gradient check is test/tele/grad.l
;
; a node is a tablet {'val 'grad 'bwd}, itself the identity key; grad accumulates by
; replacing the slot, so a node consumed twice sums its cotangents. leaves carry a noop
; bwd and stay off the tape; ops are taped in creation order, so its reverse is topological

(: ;; append: + adjoins () as an element, so treat it as empty here
   (tl-app a b) (a @ (a . u) (a . tl-app u b) b)
   (tl-cat (a . u)) (tl-app a (tl-cat u))

   ;; the tape, newest-first
   tl-tape {}
   (tl-reset _) (pin tl-tape 0 ())
   (tl-push n)  (pin tl-tape 0 (n . peep tl-tape 0 ()), n)

   ;; -- nodes --
   (tl-node? x)  (tablet? x)                          ; a raw tray is never a tablet
   (tl-val x)    (peep x 'val 0)
   (node x)      (tl-node? x ? x (const x))       ; a raw tray -> a const leaf
   (tl-accum n d)(pin n 'grad (peep n 'grad 0 + d))   ; cotangent += d
   (tl-mk v bwd) {'val v 'grad 0 'bwd bwd}
   (tl-op v bwd) (tl-push (tl-mk v bwd))            ; taped

   ;; glass: a leaf you read the grad of; const: one you don't. mechanically the same
   (glass v) (tl-mk v (s \ 0))
   (const v) (tl-mk v (s \ 0))
   (grad g)  (peep g 'grad 0)                       ; after back

   ;; -- shapes & the un-broadcast --
   (tl-cshape v) (tray? v && shape v)
   (tl-lsum l)   (l @ (a . u) (a + tl-lsum u) 0)
   (tl-lprod l)  (l @ (a . u) (a * tl-lprod u) 1)
   (tl-ncells v) (tray? v ? (tl-lprod (shape v)) 1)
   ;; sum a rank-2 tray over axis 0: the bias un-broadcast, (C,) added to (N,C)
   (tl-colsum g) (: sh (shape g) r <sh c <>sh
      (gem-tray [c]
           (map (j \ tl-lsum (map (i \ peep g [i j] 0) ^r)) ^c)))
   ;; sh is (C,), C g's last axis
   (tl-can-colsum g sh)
    (tray? g && rank g = 2 && two? sh && atom? >sh && <sh = <>(shape g))
   ;; sumto: a cotangent back to a target shape: scalar (sum all), the same shape, or
   ;; (N,C)->(C,). anything else scares
   (tl-sumto g sh)
      (? (atom? sh) (tray? g ? (net g) g)
         (sh = tl-cshape g)  g
         (tl-can-colsum g sh)  (tl-colsum g)
         (scare 'sumto-todo sh))

   ;; -- 2D transpose: mm's adjoint needs it, inner contracts last-of-a with first-of-b
   (transp2 m)
    (shape m @ (r . c . _) (gem-tray [c r]
     (tl-cat (map (j \ map (i \ peep m [i j] 0) ^r) ^c))))

   ;; -- the device seam: a backend {gemm ew reduce transp}; tl-cpu is love's own trays.
   ;; src/apps/tele/device.l adds a sim and roofline meter, chosen by (tl-use bk).
   ;; ew takes the op first, (+) (*) (-), so one slot covers all three
   tl-cpu  {'name "cpu" 'gemm inner 'ew id
            'reduce net 'transp transp2}
   tl-dev  {}
   (tl-use bk) (pin tl-dev 0 bk)
   (tl-k key)  (peep (peep tl-dev 0 tl-cpu) key 0)      ; the active kernel for key
   (tl-gemm a b)  (tl-k 'gemm a b)
   (tl-ew op a b) (tl-k 'ew op a b)
   (tl-reduce a)  (tl-k 'reduce a)
   (tl-tr m)      (tl-k 'transp m)

   ;; -- the lens ops: s is the op node, (peep s 'grad 0) its landed cotangent.
   ;; coerced nodes take fresh names: `a (node a)` would read a before it is bound
   (add a b) (: na (node a) nb (node b)
    (tl-op (tl-ew (+) (tl-val na) (tl-val nb))
     (s \ : g (peep s 'grad 0)
           (tl-accum na (tl-sumto g (tl-cshape (tl-val na))),
            tl-accum nb (tl-sumto g (tl-cshape (tl-val nb)))))))
   (mul a b) (: na (node a) nb (node b)             ; elementwise
    (tl-op (tl-ew (*) (tl-val na) (tl-val nb))
     (s \ : g (peep s 'grad 0)
           (tl-accum na (tl-sumto (tl-ew (*) g (tl-val nb)) (tl-cshape (tl-val na))),
            tl-accum nb (tl-sumto (tl-ew (*) g (tl-val na)) (tl-cshape (tl-val nb)))))))
   (mm a b) (: na (node a) nb (node b)              ; rides the gemm kernel
    (tl-op (tl-gemm (tl-val na) (tl-val nb))
     (s \ : g (peep s 'grad 0)
           (tl-accum na (tl-gemm g (tl-tr (tl-val nb))),     ; dA = G @ b^t
            tl-accum nb (tl-gemm (tl-tr (tl-val na)) g)))))  ; dB = a^t @ G
   (sum x) (node x @ nx                              ; reduce-all to a scalar
    (tl-op (tl-reduce (tl-val nx))
     (s \ tl-accum nx (tl-val nx * 0 + peep s 'grad 0))))  ; broadcast g to x's shape

   ;; -- activations + loss --
   ;; e^z is application: a tray applied to e exponentiates each cell
   (tl-exp z) (z e)

   (sub a b) (: na (node a) nb (node b)
      (tl-op (tl-ew (-) (tl-val na) (tl-val nb))
             (s \ : g (peep s 'grad 0)
                   (tl-accum na (tl-sumto g (tl-cshape (tl-val na))),
                    tl-accum nb (tl-sumto (-1 * g) (tl-cshape (tl-val nb)))))))

   (mean x) (: nx (node x) xv (tl-val nx) n (tl-ncells xv)
    (tl-op (tl-reduce xv / n)
     (s \ tl-accum nx (xv * 0 + peep s 'grad 0 / n))))

   ;; relu: the local slope is the mask x > 0
   (relu x) (: nx (node x) xv (tl-val nx) m (0 < xv)
      (tl-op (xv * m) (s \ tl-accum nx (peep s 'grad 0 * m))))

   ;; sigmoid s = 1/(1+e^-x); the adjoint s'(x) = s(1-s) (read off the output).
   (sig x) (: nx (node x) xv (tl-val nx) sv (1 / (1 + tl-exp (0 - xv)))
      (tl-op sv (s \ tl-accum nx (peep s 'grad 0 * sv * (1 - sv)))))

   ;; tanh = 2*sig(2x)-1; the adjoint t'(x) = 1 - t^2.
   (tanh x) (: nx (node x) xv (tl-val nx) tv (2 / (1 + tl-exp (-2 * xv)) - 1)
      (tl-op tv (s \ tl-accum nx (peep s 'grad 0 * (1 - tv * tv)))))

   ;; mse: a composite; mul d d's fan-out gives the chain rule's 2d
   (mse p t) (sub p t @ d (mean (mul d d)))

   ;; -- modules + optim --
   ;; a module is {'fwd 'params}; a bare function is a param-less one. the glasses persist
   ;; across steps; each forward builds a fresh graph over them
   (tl-mod fwd ps) {'fwd fwd 'params ps}
   (tl-mfwd m)    (tablet? m ? (peep m 'fwd 0) m)
   (tl-mparams m) (tablet? m ? (peep m 'params 0) ())
   (call m x)     (tl-mfwd m x)
   (params m)     (tl-mparams m)

   ;; weight init: uniform in [-0.5, 0.5); seed with (rng-set (wheel n))
   (tl-randmat r c) (gem-tray [r c] (map (_ \ randf 0 - 0.5) ^(r * c)))
   (tl-zeros n)     (gem-tray [n] 0)

   ;; linear: y = x@W + b; (linear i o) inits W random and b zero
   (linear-wb W b) (tl-mod (x \ add (mm x W) b) [W b])
   (linear i o)    (linear-wb (glass (tl-randmat i o)) (glass (tl-zeros o)))

   ;; seq: compose left to right; params concatenate
   (seq lib) (tl-mod (x \ foldl (flip tl-mfwd) x lib) (tl-cat (map tl-mparams lib)))

   ;; sgd: step p <- p - lr*grad in place; zero clears every grad
   (sgd ps lr) {'params ps 'lr lr}
   (step opt)  (: ps (peep opt 'params 0) lr (peep opt 'lr 0)
                  (map (p \ pin p 'val (tl-val p - lr * grad p)) ps))
   (zero opt)  (map (p \ pin p 'grad 0) (peep opt 'params 0))

   ;; -- back: seed ones, walk the tape newest-first
   (tl-seed v) (tray? v ? (v * 0 + 1) 1)
   (tl-walk ns) (two? ns ? (<ns @ n (peep n 'bwd 0 n, tl-walk >ns)) 0)
   (back loss) (pin loss 'grad (tl-seed (tl-val loss)), tl-walk (peep tl-tape 0 ()), loss))
