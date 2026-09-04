; tools/uuwmgen.l -- emit test/uuwm.l: the window-manager moves, compiled from
; crew/lux/core.l by tools/wm2uu.l (kind-directed by crew/lux/sigs.l) and printed
; as corpus source under the model's own names. Run on the host binary:
;
;   love tools/uuwmgen.l > test/uuwm.l        (or: make uuwm)
;
; test/uuwm.l is a committed artifact -- `make test_uuwm` regenerates and
; diffs, failing loudly if core.l moved without a refresh; test/uuwmlaw.l
; then proves the theorems OF these terms at corpus time on every target.
(: _ (reads (open "crew/lux/sigs.l" "r"))
   _ (reads (open "tools/wm2uu.l" "r"))
   ; opfix first. `forms` reads the surface, where `(i - 1)` is three data
   ; elements; wm2uu matches the core shapes. opfix is the one door between them,
   ; so the translator reads what the compiler reads, whatever the surface wears.
   ; no rev: uu's defn wants a name before its uses, which is the order wm2uu-as answers
   gens (wm2uu-as (map (f \ unglue (opfix f)) (forms (open "crew/lux/core.l" "r"))) lux-sigs ())
   _ (puts "; test/uuwm.l -- generated from crew/lux/core.l by tools/uuwmgen.l. Do not")
   _ (puts "\n; edit; refresh with `make uuwm`. The window-manager moves, compiled from")
   _ (puts "\n; the source the lux runs (kind-directed by crew/lux/sigs.l) -- so the laws")
   _ (puts "\n; in test/uuwmlaw.l are proved of the implementation itself; an invariant-")
   _ (puts "\n; breaking core.l edit fails a proof at `make test`. Substrate: test/uu.l.")
   _ (puts "\n(assert")
   _ (each gens (g \ (puts "\n (defn ", puts (string <g),
                      puts "\n   ", puts (show <>g),
                      puts "\n   ", puts (show <>>g),
                      puts ")")))
   _ (puts ")\n")
   0)
