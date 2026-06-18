; cooktest -- tests for cook's Makefile importer (cook/cook.l).
;
; Run on the host binary:  out/host/ai tools/cooktest.l
; (wired into the build as `make test_cook`, part of `make test`).
;
; cook reads a real Makefile -- variable expansion, the make functions,
; conditionals, include, pattern + static-pattern rules -- so these tests build
; fixture Makefiles (a flat list of lines, joined by newlines), run cook on them
; as a SUBPROCESS (the host `run` nif), and assert over its captured stdout. The
; recipes mostly `echo` a computed value, so the assertion is a substring check;
; the pattern-rule tests build real files and check they appear.

(: dir "/tmp/cooktest"
   ai  "out/host/ai"                          ; run from the project root (where make runs)

   ; -- a tiny assert harness (this file is standalone, not in the corpus) --
   pass (tablet 0) fail (tablet 0)
   _ (pin pass 0 0) _ (pin fail 0 0)
   (ok nm c) (? c (pin pass 0 (+ 1 (peep pass 0 0)))
                (: _ (pin fail 0 (+ 1 (peep fail 0 0)))
                    _ (fputs out (+ "FAIL " nm)) (fputc out 10)))

   ; join a list of lines into Makefile text (each line gets a trailing newline).
   (mk l) (? (chainp l) (+ (cap l) (+ "\n" (mk (cup l)))) "")
   ; does string s contain the substring sub?
   (has s sub) ((: (g i) (? (> (+ i (tally sub)) (tally s)) 0
                            (? (= sub (snip s i (+ i (tally sub)))) 1 (g (+ 1 i))))) 0)

   (write-file path content) (: q (open path "w") _ (fputs q content) (close q))
   (sh cmd) (run (L "sh" "-c" cmd))
   ; run cook on a fixture Makefile, return its captured stdout.
   (run-cook src tgt)
   (: _ (write-file (+ dir "/Makefile") src)
       r (run (L ai "-l" "cook/cook.l" (+ dir "/Makefile") tgt))
       (? (chainp r) (cup r) ""))
   ; --emit a fixture Makefile, return the generated Cookfile text (stdout).
   (run-emit src)
   (: _ (write-file (+ dir "/Makefile") src)
       r (run (L ai "-l" "cook/cook.l" "--emit" (+ dir "/Makefile")))
       (? (chainp r) (cup r) ""))

   _ (sh (+ "rm -rf " (+ dir "; mkdir -p " dir)))

   ; ---------------------------------------------------------------- expansion
   ev (run-cook (mk (L "R := ."
                      "ho = out/host"
                      "ai_c = $R/ai.c $R/data.c"
                      "h_o = $(ai_c:$(R)/%.c=$(ho)/%.o)"
                      "suf = $(ai_c:.c=.o)"
                      "all:"
                      "\techo \"E1[$(h_o)]\""
                      "\techo \"E2[$(suf)]\""
                      "\techo \"E3[$R/$(ho)]\"")) "all")
   _ (ok "nested-paren + pattern subst-ref" (has ev "E1[out/host/ai.o out/host/data.o]"))
   _ (ok "suffix subst-ref"                 (has ev "E2[./ai.o ./data.o]"))
   _ (ok "single-char $R + $(VAR)"          (has ev "E3[./out/host]"))

   ; ---------------------------------------------------------------- functions
   fn (run-cook (mk (L "files = a.c b.c sub/c.c"
                       "empty ="
                       "all:"
                       "\techo \"F1[$(dir $(files))]\""
                       "\techo \"F2[$(notdir $(files))]\""
                       "\techo \"F3[$(patsubst %.c,%.o,$(files))]\""
                       "\techo \"F4[$(filter-out sub/%,$(files))]\""
                       "\techo \"F5[$(filter %.c,$(files))]\""
                       "\techo \"F6[$(sort b a c a)]\""
                       "\techo \"F7[$(subst x,y,axbx)]\""
                       "\techo \"F8[$(strip  a   b  )]\""
                       "\techo \"F9[$(addprefix o/,x y)]\""
                       "\techo \"F10[$(addsuffix .o,x y)]\""
                       "\techo \"F11[$(firstword x y z)]\""
                       "\techo \"F12[$(words a b c)]\""
                       "\techo \"F13[$(if $(empty),yes,no)]\""
                       "\techo \"F14[$(if x,yes,no)]\""
                       "\techo \"F15[$(shell echo SH)]\"")) "all")
   _ (ok "dir"        (has fn "F1[./ ./ sub/]"))
   _ (ok "notdir"     (has fn "F2[a.c b.c c.c]"))
   _ (ok "patsubst"   (has fn "F3[a.o b.o sub/c.o]"))
   _ (ok "filter-out" (has fn "F4[a.c b.c]"))
   _ (ok "filter"     (has fn "F5[a.c b.c sub/c.c]"))
   _ (ok "sort+uniq"  (has fn "F6[a b c]"))
   _ (ok "subst"      (has fn "F7[ayby]"))
   _ (ok "strip"      (has fn "F8[a b]"))
   _ (ok "addprefix"  (has fn "F9[o/x o/y]"))
   _ (ok "addsuffix"  (has fn "F10[x.o y.o]"))
   _ (ok "firstword"  (has fn "F11[x]"))
   _ (ok "words"      (has fn "F12[3]"))
   _ (ok "if (false)" (has fn "F13[no]"))
   _ (ok "if (true)"  (has fn "F14[yes]"))
   _ (ok "shell"      (has fn "F15[SH]"))

   ; ------------------------------------------------------------- conditionals
   cnd (run-cook (mk (L "x = 1"
                        "ifeq ($(x),1)"  "a = eqyes"  "else" "a = eqno"  "endif"
                        "ifneq ($(x),1)" "b = neqyes" "else" "b = neqno" "endif"
                        "ifdef x"  "c = def"  "endif"
                        "ifndef y" "d = ndef" "endif"
                        "all:"
                        "\techo \"C[$(a) $(b) $(c) $(d)]\"")) "all")
   _ (ok "ifeq/ifneq/ifdef/ifndef" (has cnd "C[eqyes neqno def ndef]"))

   ; a conditional INSIDE a recipe block selects which recipe lines run.
   rci (run-cook (mk (L "on = 1" "all:" "\techo R-a"
                        "ifeq ($(on),1)" "\techo R-b" "endif" "\techo R-c")) "all")
   _ (ok "recipe-internal ifeq" (&& (has rci "R-b") (has rci "R-c")))

   ; -------------------------------------------------------------------- include
   ; (make resolves an include relative to the cwd; the fixture lives elsewhere,
   ; so name it absolutely.)
   _ (write-file (+ dir "/common.mk") "FROM_INC = included-ok\n")
   inc (run-cook (mk (L (+ "include " (+ dir "/common.mk")) "all:" "\techo \"I[$(FROM_INC)]\"")) "all")
   _ (ok "include" (has inc "I[included-ok]"))

   ; ----------------------------------------------------- automatic vars + dir
   av (run-cook (mk (L "all: foo/bar.o"
                       "foo/bar.o:" "\techo \"A[@=$@ star=$* d=$(dir $@)]\"")) "foo/bar.o")
   _ (ok "auto-vars + $(dir $@)" (has av "A[@=foo/bar.o star= d=foo/]"))

   ; --------------------------------------------------------- pattern rules
   ; build x.o from x.c via an implicit pattern rule; check the file appears.
   _ (sh (+ "mkdir -p " (+ dir "/p; echo SRC > " (+ dir "/p/x.c"))))
   _ (run-cook (mk (L (+ "all: " (+ dir "/p/x.o"))
                      (+ dir "/p/%.o: " (+ dir "/p/%.c")) "\tcp $< $@")) (+ dir "/p/x.o"))
   _ (ok "pattern rule builds target" (= 0 (cap (sh (+ "test -f " (+ dir "/p/x.o"))))))

   ; static pattern rule: targets: tgtpat: prereqpats
   _ (sh (+ "echo S > " (+ dir "/p/y.in")))
   _ (run-cook (mk (L (+ "outs = " (+ dir "/p/y.out"))
                      "all: $(outs)"
                      (+ "$(outs): " (+ dir (+ "/p/%.out: " (+ dir "/p/%.in")))) "\tcp $< $@")) "all")
   _ (ok "static pattern rule builds target" (= 0 (cap (sh (+ "test -f " (+ dir "/p/y.out"))))))

   ; ------------------------------------------------------------- assignment ops
   ops (run-cook (mk (L "a := base" "a += more" "b ?= keep" "b ?= nope"
                        "all:" "\techo \"O[$(a)|$(b)]\"")) "all")
   _ (ok "+= and ?=" (has ops "O[base more|keep]"))

   ; ---------------------------------------------------------------------- emit
   ; --emit transpiles a Makefile to a RESOLVED Cookfile: vars/patterns expanded,
   ; .PHONY targets -> symbols, files -> strings, each recipe line an
   ; ("sh" "-c" cmd) step, the default ticket first, a trailing (cook (ticket 0)).
   em (run-emit (mk (L "CC := cc"  "OBJ := a.o b.o"  ".PHONY: all clean"
                       "all: prog"
                       "prog: $(OBJ)"  "\t$(CC) -o $@ $(OBJ)"
                       "%.o: %.c"      "\t$(CC) -c -o $@ $<"
                       "clean:"        "\t-rm -f prog $(OBJ)")))
   _ (ok "emit: .PHONY target -> symbol"   (has em "(recipe 'all "))
   _ (ok "emit: file target -> string"     (has em "(recipe '\"prog\" "))
   _ (ok "emit: var-resolved step"         (has em "(\"sh\" \"-c\" \"cc -o prog a.o b.o\")"))
   _ (ok "emit: pattern-resolved step"     (has em "(\"sh\" \"-c\" \"cc -c -o a.o a.c\")"))
   _ (ok "emit: default ticket emitted first" (has em "(recipe 'all "))
   _ (ok "emit: trailing cook call"        (has em "(cook-all 0)"))

   ; round-trip: cook the emitted Cookfile and confirm it runs the recipe. The
   ; rule just writes a file (no compiler / source lookup), so the test is hermetic.
   _ (sh (+ "mkdir -p " (+ dir "/e")))
   emc (run-emit (mk (L ".PHONY: all"
                        (+ "all: " (+ dir "/e/out.txt"))
                        (+ dir "/e/out.txt:") "\techo HI > $@")))
   _ (write-file (+ dir "/e/Cookfile") emc)
   _ (sh (+ "rm -f " (+ dir "/e/out.txt")))
   _ (run (L ai "-l" "cook/cook.l" (+ dir "/e/Cookfile") "all"))
   _ (ok "emit: round-trip cooks the emitted Cookfile" (= 0 (cap (sh (+ "test -f " (+ dir "/e/out.txt"))))))

   ; ---------------------------------------------------------------- summary
   np (peep pass 0 0) nf (peep fail 0 0)
   _ (puts (+ (show np) (+ " cook tests pass" (? (< 0 nf) (+ ", " (+ (show nf) " FAIL")) ""))))
   _ (putc 10)
   (? (< 0 nf) (exit 1) 0))
