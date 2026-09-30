; src/tools/uuwmgen.l -- emit test/uuwm.l: the window-manager moves, compiled from
; src/apps/lux/core.l by src/tools/wm2uu.l (kind-directed by src/apps/lux/sigs.l) and printed
; as corpus source under the model's own names. run on the host binary:
;
;   love src/tools/uuwmgen.l > test/uuwm.l        (or: make uuwm)
;
; test/uuwm.l is committed: `make test_uuwm` regenerates and diffs it, and test/uuwmlaw.l
; proves its theorems at corpus time.
(borrow 'posix)
(: _ (reads (open "src/apps/lux/sigs.l" "r"))
   _ (reads (open "src/tools/wm2uu.l" "r"))
   ; opfix first: `forms` reads the surface, where `(i - 1)` is three data elements, and
   ; wm2uu matches the core shapes. no rev: uu's defn wants a name before its uses, which
   ; is the order wm2uu-as answers
   gens (wm2uu-as (map (f \ unglue (opfix f)) (forms (open "src/apps/lux/core.l" "r"))) lux-sigs ())
   (puts "; test/uuwm.l -- generated from src/apps/lux/core.l by src/tools/uuwmgen.l. Do not",
    puts "\n; edit; refresh with `make uuwm`. The window-manager moves, compiled from",
    puts "\n; the source the lux runs (kind-directed by src/apps/lux/sigs.l) -- so the laws",
    puts "\n; in test/uuwmlaw.l are proved of the implementation itself; an invariant-",
    puts "\n; breaking core.l edit fails a proof at `make test`. Substrate: test/uu.l.",
    puts "\n(test",
    each gens (g \ (puts "\n (defn ", puts (string <g),
                    puts "\n   ", puts (show <>g),
                    puts "\n   ", puts (show <>>g),
                    puts ")")),
    puts ")\n",
    0))
