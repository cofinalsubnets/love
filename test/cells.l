; --- test/cells.l: the cell doors -- peek/poke for values, pick/place for instructions ---
; the four are the compiler's own, and they live in the `guts` module rather than on the
; book. read them through `cite`, never a (borrow 'guts) splice: the corpus is one scope and
; a splice here would reach every file after this one. the bootstrap egg (love0) never mops,
; so there the same names are still the book's -- and `guts` still answers a tablet, since
; a def row registers into it from C. so ask the module first and the book after.
(: G (cite 'guts)
   (guts k) (G k || book k)
   g-peek (guts 'peek) g-poke (guts 'poke)
   g-pick (guts 'pick) g-place (guts 'place)
   g-seek (guts 'seek) g-spin (guts 'spin) g-trim (guts 'trim)
   g-ret (guts 'lvm_ret) g-ap (guts 'lvm_ap) g-quote (guts 'lvm_quote))

; the doors are reachable, and every instruction name is a charm rather than an address
(test (tablet? G) g-peek g-pick g-place (charm? g-ret) (charm? g-ap))

; an instruction reads as a charm through pick and as () through peek, and a value cell
; the other way round. a 2-arg nif is [cur][arity][impl][ret0], a 1-arg one [impl][ret0].
(test
 (charm? (g-pick 0 (+))) (charm? (g-pick 2 (+))) (charm? (g-pick 0 cap))
 (() = g-peek 0 (+)) (() = g-peek 2 (+)) (() = g-peek 0 cap)
 (2 = g-peek 1 (+)) (() = g-pick 1 (+))              ; cell 1 of a curried nif is its arity
 (g-pick 0 (+) = g-pick 0 (-))                     ; both curry through the same lvm_cur
 (g-pick 2 (+) != g-pick 2 (-))                    ; but their bodies differ
 (g-pick 3 (+) = g-pick 1 cap))                    ; and both end in lvm_ret0

; totality: a charm target is not a heap address, and every door answers () rather than
; dereferencing one. these six segfaulted before the guard, on any fixnum at all.
(test
 (() = g-peek 0 5) (() = g-pick 0 5) (() = g-seek 0 5)
 (() = g-poke 0 1 5) (() = g-place 0 g-ret 5)
 (5 = g-trim 5)                                      ; trim answers its argument
 (() = g-peek 0 -1) (() = g-pick 0 max-charm))

; place takes an instruction by index and nothing else
(: th (g-spin 3))
(test
 (() = g-place 0 'nope th) (() = g-place 0 () th) (() = g-place 0 -1 th)
 (() = g-place 0 999999 th)                          ; no such index
 (: _ (g-place 0 g-ret th) (g-ret = g-pick 0 th))    ; ..and pick reads back what place wrote
 (: _ (g-place 0 g-quote th) (g-quote = g-pick 0 th))
 (() = g-peek 0 th)                                  ; an op cell is still () to peek
 (: _ (g-poke 1 'val th) ('val = g-peek 1 th))       ; and a poked value is still a value
 (() = g-pick 1 th))

; a nif VALUE in a cell is a value, whole: its address is a def1 row like an instruction's,
; and reading it as one left every nif call off the inline path -- silently, and everywhere.
(test
 (: _ (g-poke 1 (+) th) (5 = g-peek 1 th 2 3))     ; poked in, read back, still adds
 (: _ (g-poke 1 cap th) (1 = g-peek 1 th [1 2]))
 (() = g-pick 1 th))                                 ; and pick declines it: not an instruction

; the whole point: the instruction the book hands out is a charm, not a code address, so
; ordinary value machinery walks it without dereferencing anything
(test
 (charm? g-ret) (charm? g-quote) !(g-ret = g-quote)
 (0 < g-ret) ("" != show g-ret)
 (1 = #[g-ret]) ({g-ret 1} g-ret = 1))          ; a tablet key, which peep would eql

; --- the bounds. these are structural, not content: stem reads the head off the object's
; --- terminator and span counts the cells to it, so a walk stays inside whatever it finds.
(: g-stem (guts 'stem) g-span (guts 'span) g-dis (guts 'dis))

(: fn (x \ x + 1) h (g-stem fn))
(test
 (charm? (g-span fn)) (0 < g-span fn)
 (g-span h >= g-span fn)                             ; the head is at or before the value
 (h = g-stem h)                                      ; ..and is its own stem
 (() = g-stem 5) (() = g-span 5)                     ; a charm is no object
 (() = g-stem (+)) (() = g-span (+)))                ; a nif's run is static: no terminator

; seek stops at both walls and says so with (), rather than answering a wild cell
(: t3 (g-spin 3))
(test
 (3 = g-span t3)
 (t3 = g-seek 0 t3) (() != g-seek 2 t3)
 (() = g-seek 3 t3)                                  ; the terminator is not a cell to reach
 (() = g-seek -1 t3)                                 ; ..nor is the object below it
 (() = g-seek 9999 t3) (() = g-seek -9999 t3)
 (t3 = g-seek -2 (g-seek 2 t3)))                     ; a step out and back is fine

; the terminator is the heap's own bookkeeping, not a value: no door touches it
(: t2 (g-spin 2))
(test
 (() = g-peek 2 t2) (() = g-pick 2 t2)               ; reading it answers ()
 (() = g-poke 2 'x t2) (() = g-place 2 g-ret t2)     ; writing it is refused
 (2 = g-span t2))                                    ; ..and the object is still whole

; a glazed body is a code address the op table cannot name, so pick will not see it and
; peek would otherwise hand it out raw. under LOVE_NO_GLAZE there is none, and this holds.
(test (nat? fn ? (() = g-peek 0 fn) 1))

; the disassembler: one row a cell, over the whole object
(: rows (g-dis fn) r0 (rows 0))
(test
 (two? rows) (tally rows = g-span h)
 (2 = #r0) ('op = <r0 || 'val = <r0)
 (() = g-dis 5))                                     ; nothing off the heap to walk
