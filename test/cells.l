; the cell doors: peek/poke values, pick/place instructions. a mopped image drops them and these
; laws stand down; cited, never borrowed, since the corpus is one scope
(: G (cite 'guts)
   (guts k) (G k || (elem k (names ()) ? (ev k) ()))      ; the module, else the book (love0)
   g-peek (guts 'peek) g-poke (guts 'poke)
   g-pick (guts 'pick) g-place (guts 'place)
   g-seek (guts 'seek) g-spin (guts 'spin) g-trim (guts 'trim)
   g-ret (guts 'lvm_ret) g-ap (guts 'lvm_ap) g-quote (guts 'lvm_quote)
   cells-open (lit? g-peek))
(:: 'cells-law (l \ ['? 'cells-open ('test . l) ()]))

; the doors are reachable, and every instruction name is a charm rather than an address
(cells-law (tablet? G) g-peek g-pick g-place (charm? g-ret) (charm? g-ap))

; pick reads an instruction, peek a value, each () for the other.
; a 2-arg nif is [cur][arity][impl][ret0], a 1-arg one [impl][ret0]
(cells-law
 (charm? (g-pick 0 (+))) (charm? (g-pick 2 (+))) (charm? (g-pick 0 cap))
 (() = g-peek 0 (+)) (() = g-peek 2 (+)) (() = g-peek 0 cap)
 (2 = g-peek 1 (+)) (() = g-pick 1 (+))              ; cell 1 of a curried nif is its arity
 (g-pick 0 (+) = g-pick 0 (-))                     ; both curry through the same lvm_cur
 (g-pick 2 (+) != g-pick 2 (-))                    ; but their bodies differ
 (g-pick 3 (+) = g-pick 1 cap))                    ; and both end in lvm_ret0

; totality: a charm is no heap address, so every door answers () on one
(cells-law
 (() = g-peek 0 5) (() = g-pick 0 5) (() = g-seek 0 5)
 (() = g-poke 0 1 5) (() = g-place 0 g-ret 5)
 (5 = g-trim 5)                                      ; trim answers its argument
 (() = g-peek 0 -1) (() = g-pick 0 max-charm))

; place takes an instruction by index and nothing else
(: th (g-spin 3))
(cells-law
 (() = g-place 0 'nope th) (() = g-place 0 () th) (() = g-place 0 -1 th)
 (() = g-place 0 999999 th)                          ; no such index
 (g-place 0 g-ret th, g-ret = g-pick 0 th)           ; ..and pick reads back what place wrote
 (g-place 0 g-quote th, g-quote = g-pick 0 th)
 (() = g-peek 0 th)                                  ; an op cell is still () to peek
 (g-poke 1 'val th, 'val = g-peek 1 th)              ; and a poked value is still a value
 (() = g-pick 1 th))

; a nif value in a cell is a value, though its address looks like an instruction's
(cells-law
 (g-poke 1 (+) th, 5 = g-peek 1 th 2 3)            ; poked in, read back, still adds
 (g-poke 1 cap th, 1 = g-peek 1 th [1 2])
 (() = g-pick 1 th))                                 ; and pick declines it: not an instruction

; an instruction is a charm, so ordinary value machinery walks it safely
(cells-law
 (charm? g-ret) (charm? g-quote) !(g-ret = g-quote)
 (0 < g-ret) ("" != show g-ret)
 (1 = #[g-ret]) ({g-ret 1} g-ret = 1))          ; a tablet key, which peep would eql

; --- bounds: stem reads the head off the object's terminator, span counts cells to it ---
(: g-stem (guts 'stem) g-span (guts 'span) g-dis (guts 'dis))

(: fn (x \ x + 1) h (g-stem fn))
(cells-law
 (charm? (g-span fn)) (0 < g-span fn)
 (g-span h >= g-span fn)                             ; the head is at or before the value
 (h = g-stem h)                                      ; ..and is its own stem
 (() = g-stem 5) (() = g-span 5)                     ; a charm is no object
 (() = g-stem (+)) (() = g-span (+)))                ; a nif's run is static: no terminator

; seek stops at both walls and says so with (), rather than answering a wild cell
(: t3 (g-spin 3))
(cells-law
 (3 = g-span t3)
 (t3 = g-seek 0 t3) (() != g-seek 2 t3)
 (() = g-seek 3 t3)                                  ; the terminator is not a cell to reach
 (() = g-seek -1 t3)                                 ; ..nor is the object below it
 (() = g-seek 9999 t3) (() = g-seek -9999 t3)
 (t3 = g-seek -2 (g-seek 2 t3)))                     ; a step out and back is fine

; the terminator is the heap's own bookkeeping, not a value: no door touches it
(: t2 (g-spin 2))
(cells-law
 (() = g-peek 2 t2) (() = g-pick 2 t2)               ; reading it answers ()
 (() = g-poke 2 'x t2) (() = g-place 2 g-ret t2)     ; writing it is refused
 (2 = g-span t2))                                    ; ..and the object is still whole

; a glazed body is a raw code address: peek must not hand it out
(cells-law (nat? fn ? (() = g-peek 0 fn) 1))

; the disassembler: one row a cell, over the whole object
(: rows (g-dis fn) r0 (rows 0))
(cells-law
 (two? rows) (#rows = g-span h)
 (2 = #r0) ('op = <r0 || 'val = <r0)
 (() = g-dis 5))                                     ; nothing off the heap to walk
