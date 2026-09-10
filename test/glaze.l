; the glaze's install seam, arch-neutral half: guards only, never an actual run (executing bytes
; is machine-specific) -- plus the decline laws below, which run everywhere and answer the same on
; every target by construction: that is the whole point of a lane that knows when to stand down.
; The executing tests are test/glaze-x86.l; the mechanism, l/boot/glaze/README.md.
; `nif` -- the codegen-backend install seam (love.c): (nif code interp src ..) wraps
; emitted bytes in a transparent applicable native closure. neutral here (no
; install/run -- the bytes are x86-64; the real round-trip lives in l/boot/glaze/emit.l):
; non-byte / empty code installs nothing.
; by key, never bare: every boot pulls nif/nifx off the book (i/main.c), so raw byte
; installation is reachable only through the glaze, which is the only thing that does it.
; a bare `nif` here would read the zero point and every claim below would answer 1.
; and under the presence guard: love0 and the kernel/wasm frontends carry no glaze, so
; there is no seam there to hold to its word -- (cite 'glaze) answers () and this stands down.
(: G (cite 'glaze)
   (? G (: N (G 'nif)
           (test (lit? N)
                   !(N 5 0 0 1) !(N 'x 0 0 1) !(N () 0 0 1) !(N "" 0 0 1)))
      0))

; --- the natjit group lane declines what it cannot emit -------------------------------
; jitgroupir's codegen (emit.l cggir/cggvir) compiles a leaf that is a frame param or a
; whole-number immediate, and nothing else: every other leaf -- a string, a nom, a list, a
; gem -- falls off the end of their `?` into a silent (), emitting no code and leaving
; whatever the accumulator last held. So the lane is only ever as sound as the recognizer
; in front of it, and hook.l's natjit entrance had none: it gated on jgir-ok?, which
; answers "does jitgroupir implement these ops" and says in its own header that it does not
; re-derive the grammar. It was written as a backstop under autogroup, which had already run
; grpfix. hook.l now runs grpfix too (grp-ok?), so both entrances share one recognizer.
;
; each helper below is a `:` whose one binding is a self-recursive helper called from its
; body -- the shape anat-defs reads as a group -- carrying a value the integer group lane
; cannot hold. the wrong answers they used to give are noted; note how plausible they are,
; which is why this is a law and not a footnote: `(acc + " ")` compiled as `acc + k` and
; three spaces came back the triangular number 6.
(: (scar-sp n)   (: (go k acc) (? (k < 1) acc (go (k - 1) (acc + " "))) (go n ""))    ; string built by +
   (scar-dash z) (: (g j) (? (j < 1) "" ("-" + (g (j - 1)))) (g (tally z)))           ; ..the argument-applying twin
   (scar-lit n)  (: (go k acc) (? (k < 1) acc (go (k - 1) "Q")) (go n 0))             ; a bare string constant
   (scar-link n) (: (go k acc) (? (k < 1) acc (go (k - 1) (. acc 1))) (go n 0))    ; a cons
   _ (test
      ("   " = (scar-sp 3))                                  ; was 6  -- the triangular sum of k
      ("--" = (scar-dash "ab"))                              ; was 1
      ("Q" = (scar-lit 2))                                   ; was 0
      ((. (. (. 0 1) 1) 1) = (scar-link 3)))        ; was 1
   0)

; --- autogroup's constant fold respects a pair's own params ---------------------------
; fold-consts inlines a whole-constant sibling into every body of a bare top-level `:`,
; and dehof does the same with a lambda constant; a pair whose own params spell that
; name binds it itself -- sugared head and explicit lambda alike -- so the fold passes
; such a pair by. driven through `ev`: only a bare top-level letrec meets autogroup, and
; on a glazeless frontend `ev` is the base evaluator answering the same by definition.
(test
    (3  = (ev '(: (x f) f  f 2  (x 3))))
    (7  = (ev '(: (x f y) (+ f y)  f 2  (x 3 4))))
    (3  = (ev '(: f 2  (x f) f  (x 3))))
    (3  = (ev '(: x (\ f f)  f 2  (x 3))))
    (11 = (ev '(: f 2  (g f) (+ f 1)  (g 10))))
    (7  = (ev '(: tw (\ h (h 1))  (g tw) (tw (\ y (+ y 5)))  (g (\ k 7)))))   ; dehof's lamc fold holds the same law
    (12 = (ev '(: m 7  (g x) (+ x m)  (g 5)))))                                ; ..and an unshadowed const still folds

; --- a word an enclosing letrec rebinds is not the word the desugar owns --------------
; adesug rewrites (list a..), (one? x), (nil? x), (atom? x), (!= a b) and (!== a b) into
; the shapes amble compiles, by the head's name -- and the frame's binders are not the only
; ones in scope, so a letrec that spells one of those words itself declines the rewrite.
; each local answers 7 where its word answers 1 or 0; a constant body would be folded in
; before the desugar ever saw a call, so these compute.
(: (one? e)  (charm? e ? 7 9)
   (nil? e)  (charm? e ? 7 9)
   (atom? e) (charm? e ? 7 9)
   (!= a b)  (charm? a ? 7 9)
   (!== a b) (charm? a ? 7 9)
   (c1 r) (two? r && (one? <r))
   (c2 r) (two? r && (nil? <r))
   (c3 r) (two? r && (atom? <r))
   (c4 r) (two? r && (!= <r <r))
   (c5 r) (two? r && (!== <r <r))
   q [0 "x"]
   _ (test (7 = c1 q) (7 = c2 q) (7 = c3 q) (7 = c4 q) (7 = c5 q))
   0)
; ..and `list`, in a letrec of its own: a local spelling owns that scope's [..] too
(: (list a) (charm? a ? 7 9)
   (c6 r) (two? r && (list <r))
   q (. 0 (. "x" ()))
   _ (test (7 = c6 q))
   0)
