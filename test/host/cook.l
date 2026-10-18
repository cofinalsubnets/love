; test/host/cook.l -- cook's Makefile importer: fixture Makefiles through a cook subprocess,
; asserted over its stdout. standalone: out/love test/host/cook.l
; driven bare, so the posix door is borrowed here
(cite 'posix ? (borrow 'posix) ())

(: dir ("/tmp/cooktest-" + show (getpid 0))   ; per run: sessions share the box
   love  "out/love"

   pass {} fail {}
   _ (pin pass 0 0) _ (pin fail 0 0)
   (ok nm c) (c ? (pin pass 0 (1 + peep pass 0 0)) (pin fail 0 (1 + peep fail 0 0),
                 say out ("FAIL " + nm),
                 put out 10))

   (mk l) (two? l ? (<l + ("\n" + mk >l)) "")

   (write-file path content) (: q (open path "w") _ (say q content) (close q))
   (sh cmd) (hark ["sh" "-c" cmd])
   ; -f, not a positional: from the repo root a positional is a goal against ./Makefile
   (run-cook src tgt)
   (: _ (write-file (dir + "/Makefile") src)
       r (hark [love "-l" "src/apps/cook.l" "-f" (dir + "/Makefile") tgt])
       (two? r ? >r ""))
   ; ..under env's NAME=value words
   (run-cook-in env src tgt)
   (: _ (write-file (dir + "/Makefile") src)
       r (hark ((["env"] + env) + [love "-l" "src/apps/cook.l" "-f" (dir + "/Makefile") tgt]))
       (two? r ? >r ""))
   (run-emit src)
   (: _ (write-file (dir + "/Makefile") src)
       r (hark [love "-l" "src/apps/cook.l" "--emit" "-f" (dir + "/Makefile")])
       (two? r ? >r ""))

   _ (sh ("rm -rf " + dir + "; mkdir -p " + dir))

   ; expansion
   ev (run-cook (mk '("R := ."
                      "ho = out"
                      "love_c = $R/love/love.c $R/data.c"
                      "h_o = $(love_c:$(R)/%.c=$(ho)/%.o)"
                      "suf = $(love_c:.c=.o)"
                      "all:"
                      "\techo \"E1[$(h_o)]\""
                      "\techo \"E2[$(suf)]\""
                      "\techo \"E3[$R/$(ho)]\"")) "all")
   _ (ok "nested-paren + pattern subst-ref" (has? ev "E1[out/love/love.o out/data.o]"))
   _ (ok "suffix subst-ref"                 (has? ev "E2[./love/love.o ./data.o]"))
   _ (ok "single-char $R + $(VAR)"          (has? ev "E3[./out]"))

   ; functions
   fn (run-cook (mk '("files = a.c b.c sub/c.c"
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
   _ (ok "dir"        (has? fn "F1[./ ./ sub/]"))
   _ (ok "notdir"     (has? fn "F2[a.c b.c c.c]"))
   _ (ok "patsubst"   (has? fn "F3[a.o b.o sub/c.o]"))
   _ (ok "filter-out" (has? fn "F4[a.c b.c]"))
   _ (ok "filter"     (has? fn "F5[a.c b.c sub/c.c]"))
   _ (ok "sort+uniq"  (has? fn "F6[a b c]"))
   _ (ok "subst"      (has? fn "F7[ayby]"))
   _ (ok "strip"      (has? fn "F8[a b]"))
   _ (ok "addprefix"  (has? fn "F9[o/x o/y]"))
   _ (ok "addsuffix"  (has? fn "F10[x.o y.o]"))
   _ (ok "firstword"  (has? fn "F11[x]"))
   _ (ok "words"      (has? fn "F12[3]"))
   _ (ok "if (false)" (has? fn "F13[no]"))
   _ (ok "if (true)"  (has? fn "F14[yes]"))
   _ (ok "shell"      (has? fn "F15[SH]"))

   ; conditionals
   cnd (run-cook (mk '("x = 1"
                        "ifeq ($(x),1)"  "a = eqyes"  "else" "a = eqno"  "endif"
                        "ifneq ($(x),1)" "b = neqyes" "else" "b = neqno" "endif"
                        "ifdef x"  "c = def"  "endif"
                        "ifndef y" "d = ndef" "endif"
                        "all:"
                        "\techo \"C[$(a) $(b) $(c) $(d)]\"")) "all")
   _ (ok "ifeq/ifneq/ifdef/ifndef" (has? cnd "C[eqyes neqno def ndef]"))

   ; a conditional inside a recipe block selects which recipe lines run
   rci (run-cook (mk '("on = 1" "all:" "\techo R-a"
                        "ifeq ($(on),1)" "\techo R-b" "endif" "\techo R-c")) "all")
   _ (ok "recipe-internal ifeq" (has? rci "R-b" && has? rci "R-c"))

   ; include (resolved against the cwd, so the fixture names it absolutely)
   _ (sh ("mkdir -p " + (dir + "/mk")))
   _ (write-file (dir + "/mk/common.mk") "FROM_INC = included-ok\n")
   inc (run-cook (mk [("include " + (dir + "/mk/common.mk")) "all:" "\techo \"I[$(FROM_INC)]\""]) "all")
   _ (ok "include" (has? inc "I[included-ok]"))
   sinc (run-cook (mk [("-include " + (dir + "/mk/nosuch.mk " + dir + "/mk/common.mk"))
                       ("sinclude " + dir + "/mk/nosuch2.mk")
                       "all:" "\techo \"S[$(FROM_INC)]\""]) "all")
   _ (ok "-include and sinclude pass over a missing file" (has? sinc "S[included-ok]"))
   _ (write-file (dir + "/Makefile") (mk [("include " + dir + "/mk/nosuch.mk") "all:" "\techo x"]))
   hinc (: r (hark [love "-l" "src/apps/cook.l" "-f" (dir + "/Makefile") "all"]) (two? r ? <r 0))
   _ (ok "include of a missing file fails" !(0 = hinc))

   ; automatic vars + dir
   av (run-cook (mk '("all: foo/bar.o"
                       "foo/bar.o:" "\techo \"A[@=$@ star=$* d=$(dir $@)]\"")) "foo/bar.o")
   _ (ok "auto-vars + $(dir $@)" (has? av "A[@=foo/bar.o star= d=foo/]"))

   ; pattern rules
   _ (sh ("mkdir -p " + ((dir + "/p; echo SRC > ") + (dir + "/p/x.c"))))
   _ (run-cook (mk [("all: " + (dir + "/p/x.o"))
                     ((dir + "/p/%.o: ") + (dir + "/p/%.c")) "\tcp $< $@"]) (dir + "/p/x.o"))
   _ (ok "pattern rule builds target" (0 = <(sh ("test -f " + (dir + "/p/x.o")))))

   ; static pattern rule: targets: tgtpat: prereqpats
   _ (sh ("echo S > " + (dir + "/p/y.in")))
   _ (run-cook (mk [("outs = " + (dir + "/p/y.out"))
                     "all: $(outs)"
                     ("$(outs): " + (dir + ("/p/%.out: " + (dir + "/p/%.in")))) "\tcp $< $@"]) "all")
   _ (ok "static pattern rule builds target" (0 = <(sh ("test -f " + (dir + "/p/y.out")))))

   ; an empty recipe cancels a pattern rule; a live `%.c: %.l` would make every .c demand a .l
   _ (sh ("echo C > " + (dir + "/p/n.c")))
   ca (run-cook (mk ["%.c: %.l"
                     ("all: " + (dir + "/p/n.c")) "\t@echo \"CA[ok]\""]) "all")
   _ (ok "an empty pattern recipe cancels, not registers" (has? ca "CA[ok]"))

   ; the builtin implicit rules, asserted on the command issued so no host compiler is needed
   _ (sh ("mkdir -p " + dir + "/b; echo SRCB > " + dir + "/b/z.c"))
   bi (run-cook (mk ["CC = echo-cc"
                     ("all: " + (dir + "/b/z.o")) "\t@echo BUILTIN-DONE"]) "all")
   _ (ok "builtin %.o: %.c fires" (has? bi "echo-cc" && has? bi "-c -o" && has? bi "z.c"))
   ; ..and the match-anything builtins stay out: with x.o on disk, `x` is still the Makefile's recipe
   _ (sh ("echo O > " + (dir + "/b/lone.o")))
   ma (run-cook (mk [("all: " + (dir + "/b/lone")) ((dir + "/b/lone: ") + (dir + "/b/lone.o"))
                     "\t@echo \"MA[mine]\""]) "all")
   _ (ok "no match-anything builtin hijacks a link" (has? ma "MA[mine]"))

   ; old-style suffix rules: `.c.o:` is `%.o: %.c`, ahead of the builtin
   _ (sh ("echo SRCS > " + (dir + "/b/s.c")))
   _ (run-cook (mk [".SUFFIXES: .c .o"
                    ".c.o:" "\tcp $< $@"
                    ("all: " + (dir + "/b/s.o"))]) "all")
   _ (ok "suffix rule .c.o builds the target" (0 = <(sh ("test -f " + (dir + "/b/s.o")))))

   ; .POSIX moves make's defaults to c99 and -O1, as defaults: a file's own CC= still wins
   px (run-cook (mk '(".POSIX:" "all:" "\t@echo \"PX[$(CC) $(CFLAGS)]\"")) "all")
   _ (ok ".POSIX moves CC/CFLAGS" (has? px "PX[c99 -O1]"))
   nx (run-cook (mk '("all:" "\t@echo \"NX[$(CC)]\"")) "all")
   _ (ok "without .POSIX, CC stays cc" (has? nx "NX[cc]"))

   ; $@ of a phony target reads as the name (lua's `cd src && $(MAKE) $@`)
   pa (run-cook (mk '(".PHONY: guess" "all: guess" "guess:" "\t@echo \"PA[$@]\"")) "all")
   _ (ok "$@ of a phony target is its name" (has? pa "PA[guess]"))

   ; assignment ops
   ops (run-cook (mk '("a := base" "a += more" "b ?= keep" "b ?= nope"
                        "all:" "\techo \"O[$(a)|$(b)]\"")) "all")
   _ (ok "+= and ?=" (has? ops "O[base more|keep]"))

   ; seeding as make: environment, builtin defaults, then command-line VAR=VAL, which silences
   ; the file's assignment unless `override`; the subprocess inherits setenv
   (D2 f) (dir + f)
   (run-cookv src args)
   (: _ (write-file (dir + "/Makefile") src)
       r (hark ([love "-l" "src/apps/cook.l" "-f" (dir + "/Makefile")] + args))
       (two? r ? >r ""))
   _ (setenv "COOKT_ENV" "from-env")
   env (run-cookv (mk '("COOKT_ENV ?= nope"
                        "fv = infile"
                        "all:"
                        "\techo \"N1[$(COOKT_ENV)]\""
                        "\techo \"N2[$(origin COOKT_ENV) $(origin fv) $(origin COOKT_NO)]\""))
                  '("all"))
   _ (ok "environment import (and ?= yields to it)" (has? env "N1[from-env]"))
   _ (ok "$(origin): environment / file / undefined"
         (has? env "N2[environment file undefined]"))
   _ (setenv "COOKT_ENV" ())
   cli (run-cookv (mk '("cv = filewins"
                        "override ov := forced"
                        "all:"
                        "\techo \"L[$(cv) $(ov) $(origin cv)]\""))
                  '("all" "cv=cli" "ov=cli"))
   _ (ok "a command-line VAR=VAL silences the file assignment"
         (has? cli "L[cli forced command line]"))
   xp (run-cook (mk '("export EX := exported"
                      "all:"
                      "\techo \"X[$$EX]\"")) "all")
   _ (ok "export hands the value to the recipe's environment" (has? xp "X[exported]"))
   cal (run-cook (mk '("greet = hi-$(1)-$(2)"
                       "g := $(call greet,a,b)"
                       "all:"
                       "\techo \"G[$(g)]\"")) "all")
   _ (ok "$(call) binds $1..$n over the body" (has? cal "G[hi-a-b]"))
   evl (run-cook (mk '("define grp"
                       "$(1)-$(2):"
                       "\t@echo \"E[$(1) $(2) $$(src_$(2))]\""
                       "endef"
                       "src_a = x"
                       "$(foreach d,b,$(eval src_$d = y$d))"
                       "$(foreach i,i1 i2,$(foreach g,a b,$(eval $(call grp,$i,$g))))"
                       "v := $(eval w = in-assign)"
                       "all: i1-a i2-b"
                       "\t@echo \"W[$(w)]\"")) "all")
   _ (ok "$(eval) nested in a foreach lays rules" (has? evl "E[i1 a x]" && has? evl "E[i2 b yb]"))
   _ (ok "$(eval) inside an assignment runs" (has? evl "W[in-assign]"))
   dsh (run-cook (mk '("src_sys-af = one" "x-y := two" "k = sys-af"
                       "all:"
                       "\t@echo \"N[$(src_sys-af) $(x-y) $(src_$(k))]\"")) "all")
   _ (ok "a variable name may hold a dash" (has? dsh "N[one two one]"))
   _ (write-file (dir + "/Makefile") (mk '("all:" "\t@echo $(eval z = 1)")))
   evr (: r (hark [love "-l" "src/apps/cook.l" "-f" (dir + "/Makefile") "all"]) (two? r ? <r 0))
   _ (ok "$(eval) in a recipe refuses" !(0 = evr))

   ; @D/@F, wildcard, abspath
   adf (run-cook (mk '("all: foo/bar.o"
                       "foo/bar.o:" "\techo \"D[$(@D) $(@F)]\"")) "foo/bar.o")
   _ (ok "$(@D) and $(@F)" (has? adf "D[foo bar.o]"))
   _ (sh ("mkdir -p " + (D2 "/w; touch " + (D2 "/w/b.c " + (D2 "/w/a.c " + D2 "/w/.h.c")))))
   wc (run-cook (mk [("ws := $(wildcard " + (D2 "/w/*.c" + ")"))
                     ("ex := $(wildcard " + (D2 "/w/a.c" + ")"))
                     "no := $(wildcard nothing/here/*.q)"
                     "all:"
                     "\techo \"W[$(notdir $(ws))|$(notdir $(ex))|$(no)]\""]) "all")
   _ (ok "wildcard: sorted glob, no dotfiles, existence word, empty miss"
         (has? wc "W[a.c b.c|a.c|]"))
   ab (run-cook (mk '("p := $(abspath /x//y/./../z)"
                      "all:" "\techo \"P[$(p)]\"")) "all")
   _ (ok "abspath cleans // . .." (has? ab "P[/x/z]"))

   ; --emit: a resolved Cookfile, .PHONY as symbols, files as strings, each line a sh -c step,
   ; the default first. a pattern whose source is missing does not apply, so the sources are real
   _ (sh ("mkdir -p " + dir + "/e; touch " + dir + "/e/a.c " + dir + "/e/b.c"))
   eo (dir + "/e/a.o " + dir + "/e/b.o")
   em (run-emit (mk ["CC := cc"  ("OBJ := " + eo)  ".PHONY: all clean"
                      "all: prog"
                      "prog: $(OBJ)"  "\t$(CC) -o $@ $(OBJ)"
                      "%.o: %.c"      "\t$(CC) -c -o $@ $<"
                      "clean:"        "\t-rm -f prog $(OBJ)"]))
   _ (ok "emit: .PHONY target -> symbol"   (has? em "(recipe 'all "))
   _ (ok "emit: file target -> string"     (has? em "(recipe '\"prog\" "))
   _ (ok "emit: var-resolved step"         (has? em ("(\"sh\" \"-c\" \"cc -o prog " + (eo + "\")"))))
   _ (ok "emit: pattern-resolved step"     (has? em ("(\"sh\" \"-c\" \"cc -c -o " + (dir + ("/e/a.o " + (dir + "/e/a.c\")"))))))
   _ (ok "emit: default ticket emitted first" (has? em "(recipe 'all "))
   _ (ok "emit: trailing cook call"        (has? em "(cook-all 0)"))

   ; round-trip: cook the emitted Cookfile; the rule only writes a file, so it is hermetic
   _ (sh ("mkdir -p " + (dir + "/e")))
   emc (run-emit (mk [".PHONY: all"
                       ("all: " + (dir + "/e/out.txt"))
                       (dir + "/e/out.txt:") "\techo HI > $@"]))
   _ (write-file (dir + "/e/Cookfile") emc)
   _ (sh ("rm -f " + (dir + "/e/out.txt")))
   _ (hark [love "-l" "src/apps/cook.l" "-f" (dir + "/e/Cookfile") "all"])
   _ (ok "emit: round-trip cooks the emitted Cookfile" (0 = <(sh ("test -f " + (dir + "/e/out.txt")))))

   ; .DEFAULT_GOAL overrides the first rule as the default, directly and through --emit
   dgsrc (mk '(".PHONY: first second"
               ".DEFAULT_GOAL := second"
               "first:"  "\techo FIRST"
               "second:" "\techo SECOND"))
   _ (write-file (dir + "/Makefile") dgsrc)
   dgr (: r (hark [love "-l" "src/apps/cook.l" "-f" (dir + "/Makefile")]) (two? r ? >r ""))
   _ (ok ".DEFAULT_GOAL is the default ticket" (has? dgr "SECOND"))
   _ (write-file (dir + "/e/Cookfile") (run-emit dgsrc))
   dgc (: r (hark [love "-l" "src/apps/cook.l" "-f" (dir + "/e/Cookfile")]) (two? r ? >r ""))
   _ (ok "emit: .DEFAULT_GOAL survives the round-trip" (has? dgc "SECOND"))

   ; a step may write a file it does not own, so an item's date is read fresh at its turn
   ; (every fixture path is absolute: cook runs from the project root, not `dir`)
   (D f) (dir + f)
   _ (sh ("echo OLD > " + (D "/shared.txt" + (" && sleep 0.01 && echo STALE > " + D "/second"))))
   sidesrc (mk [".PHONY: all first"
                ("all: first " + D "/second")
                "first:" ("\techo NEW > " + D "/shared.txt")
                (D "/second: " + D "/shared.txt")
                ("\tcp " + (D "/shared.txt" + (" " + D "/second")))])
   _ (write-file (D "/Makefile") sidesrc)
   _ (: r (hark [love "-l" "src/apps/cook.l" "-f" (D "/Makefile") "all"]) 0)
   side (: r (sh ("cat " + D "/second")) (two? r ? >r ""))
   _ (ok "a recipe's side-effect write invalidates the date cache" (has? side "NEW"))


   ; .ONESHELL: a variable set on one line is live on the next; differential against GNU make
   one (run-cook (mk '(".ONESHELL:"
                       ".SHELLFLAGS := -ec"
                       "all:"
                       "\tx=hello"
                       "\techo \"O1[$$x world]\"")) "all")
   _ (ok ".ONESHELL: one shell for the whole recipe" (has? one "O1[hello world]"))
   ; ..and without it the default still holds: separate shells, so x is gone
   sep (run-cook (mk '("all:"
                       "\tx=hello"
                       "\techo \"O2[$$x world]\"")) "all")
   _ (ok "no .ONESHELL: a line still gets its own shell" (has? sep "O2[ world]"))
   ; one shell checks only the last line's status, so -e must stop the third line; silenced
   ; because a one-shell recipe echoes whole, and the assertion would read its own echo
   ec (run-cook (mk '(".ONESHELL:"
                      ".SHELLFLAGS := -ec"
                      "all:"
                      "\t@echo O3-one"
                      "\tfalse"
                      "\techo O3-three")) "all")
   _ (ok ".SHELLFLAGS -ec: a failing middle line stops the recipe"
         (has? ec "O3-one" && !(has? ec "O3-three")))

   ; `a b: src` is one rule under both targets; asking for the second proves it
   _ (sh ("echo x > " + D "/msrc"))
   _ (run-cook (mk [(D "/m1.out " + (D "/m2.out: " + D "/msrc"))
                    ("\techo M4 > " + D "/m1.out")
                    ("\techo M4 > " + D "/m2.out")])
               (D "/m2.out"))
   m2 (: r (sh ("cat " + D "/m2.out")) (two? r ? >r ""))
   _ (ok "a multi-target rule registers every target" (has? m2 "M4"))

   ; the @/-/+ prefixes are read after expansion (`Q = @`): an expanded @ silences the line
   qm (run-cook (mk '("Q = @"
                      "all:"
                      "\t$(Q)echo M5[quiet]")) "all")
   _ (ok "an expanded @ is a modifier, not a word"
         (has? qm "M5[quiet]" && !(has? qm "@echo")))

   ; SHELL picks the shell for recipe lines and $(shell), seen through $0 (lush pins "lush" in -c);
   ; $(wildcard) is lush's glob, nullglob
   _ (write-file (dir + "/lushsh") "#!/bin/sh\nexec out/love lush \"$@\"\n")
   _ (sh ("chmod +x " + (dir + "/lushsh")))
   shl (run-cook (mk [("SHELL := " + (dir + "/lushsh"))
                      "all:"
                      "\t@echo \"L1[$$0]\""
                      "\t@echo \"L2[$(shell echo $$0)]\""])
                 "all")
   _ (ok "SHELL: recipe lines ride lush"   (has? shl "L1[lush]"))
   _ (ok "SHELL: $(shell) rides lush too"  (has? shl "L2[lush]"))
   wld (run-cook (mk '("all:"
                       "\t@echo \"WC[$(wildcard src/apps/lus*.l src/apps/zz-nope*.q)]\""))
                 "all")
   _ (ok "wildcard: pure-love glob, nullglob" (has? wld "WC[src/apps/lush.l]"))
   ; a mode letter in .SHELLFLAGS is lush's: -a runs ours ahead of PATH's tr ("theirs");
   ; LUSHFLAGS=-g, or no letter with LUSHFLAGS unset, hands the line to PATH's sh and tr
   _ (sh ("mkdir -p " + dir + "/tb; printf '#!/bin/sh\\necho theirs\\n' > " + dir + "/tb/tr; chmod 755 " + dir + "/tb/tr"))
   tenv [("PATH=" + dir + "/tb:" + getenv "PATH") "LUSHFLAGS="]
   am (run-cook-in tenv (mk [".SHELLFLAGS := -ac" "all:" "\t@tr a b </dev/null; echo M[a]"]) "all")
   _ (ok ".SHELLFLAGS -ac: autonomous, our tr" (has? am "M[a]" && !(has? am "theirs")))
   gm (run-cook-in [("PATH=" + dir + "/tb:" + getenv "PATH") "LUSHFLAGS=-g"]
                   (mk ["all:" "\t@tr a b </dev/null; echo M[g]"]) "all")
   _ (ok "LUSHFLAGS=-g: gregarious, PATH's tr" (has? gm "theirs" && has? gm "M[g]"))
   nm (run-cook-in tenv (mk ["all:" "\t@tr a b </dev/null; echo M[n]"]) "all")
   _ (ok "no mode letter: gregarious, PATH's tr" (has? nm "theirs" && has? nm "M[n]"))
   ; $(shell) takes .SHELLFLAGS as a recipe line does: -e stops at the false
   se (run-cook (mk [".SHELLFLAGS := -ec" "X := $(shell false; echo no)" "all:" "\t@echo \"SE[$(X)]\""]) "all")
   _ (ok "$(shell) rides .SHELLFLAGS" (has? se "SE[]"))
   ; ..and runs in this image: under -a with PATH emptied it still has uname
   ea (run-cook-in ["PATH=/nonexistent" "LUSHFLAGS=-a"]
                   (mk ["U := $(shell uname -s)" ".SHELLFLAGS := -ec" "X := $(shell false; echo no)"
                        "all:" "\t@echo \"SA[$(U)]\"" "\t@echo \"SB[$(X)]\""]) "all")
   _ (ok "$(shell) in this image: no PATH wanted" (has? ea "SA[" && !(has? ea "SA[]")))
   _ (ok "$(shell) in this image rides .SHELLFLAGS" (has? ea "SB[]"))
   ; a line run in this image forks warm children (`sh FILE`, ( ), a pipeline stage); each
   ; one's `exit` ends that child only
   _ (write-file (dir + "/x0.sh") "true\nexit\n")
   _ (write-file (dir + "/x3.sh") "f() { exit 3; }\nf\necho no\n")
   xe (: _ (write-file (dir + "/Makefile")
                       (mk ["all:" ("\t@sh " + dir + "/x0.sh; echo X0[$$?]")
                            ("\t@sh " + dir + "/x3.sh; echo X3[$$?]")
                            "\t@(exit 4); echo XS[$$?]"
                            "\t@exit 5 | true; echo XP[$$?]"
                            ("\t@sh " + dir + "/x0.sh")
                            "\t@echo XE[end]"]))
         (hark ["env" "PATH=/nonexistent" "LUSHFLAGS=-a" love "-l" "src/apps/cook.l"
                "-f" (dir + "/Makefile") "all"]))
   xo (two? xe ? >xe "")
   _ (ok "sh FILE's exit ends the script: status 0" (has? xo "X0[0]"))
   _ (ok "exit 3 in a script's function: status 3" (has? xo "X3[3]" && !(has? xo "no")))
   _ (ok "exit in a ( ): the subshell's status" (has? xo "XS[4]"))
   _ (ok "exit in a pipeline stage: that stage's" (has? xo "XP[0]"))
   _ (ok "a recipe line of sh FILE; exit: rc 0" (has? xo "XE[end]" && two? xe && 0 = <xe))
   ; the build file's fd is closed before any recipe runs
   fdl (run-cook (mk ["all:" "\t@ls -l /proc/self/fd/ 2>/dev/null"]) "all")
   _ (ok "the Makefile's fd is not a recipe's" !(has? fdl (dir + "/Makefile")))

   ; -j: every case answers the same fixture at -j4 against the serial law, never a timing
   (run-cookj src tgt j)
   (: _ (write-file (dir + "/Makefile") src)
       r (hark [love "-l" "src/apps/cook.l" "-j" j "-f" (dir + "/Makefile") tgt])
       (two? r ? >r ""))
   _ (sh ("mkdir -p " + D "/j"))
   jsrc (mk [".PHONY: all"
             ("all: " + (D "/j/a " + (D "/j/b " + (D "/j/c " + D "/j/d"))))
             "\t@echo J[all]"
             (D "/j/a:") ("\t@echo A > " + D "/j/a")
             (D "/j/b:") ("\t@echo B > " + D "/j/b")
             (D "/j/c:") ("\t@echo C > " + D "/j/c")
             (D "/j/d:") ("\t@echo D > " + D "/j/d")])
   _ (sh ("rm -f " + D "/j/[abcd]"))
   j1 (run-cookj jsrc "all" "1")
   _ (sh ("rm -f " + D "/j/[abcd]"))
   j4 (run-cookj jsrc "all" "4")
   _ (ok "-j4 answers what -j1 answered" (j1 = j4))
   _ (ok "-j4 ran every independent recipe"
         (0 = <(sh ("test -f " + (D "/j/a" + (" && test -f " + (D "/j/b" + (" && test -f " + (D "/j/c" + (" && test -f " + D "/j/d"))))))))))
   ; a glued -jN is the same flag
   _ (sh ("rm -f " + D "/j/[abcd]"))
   jg (: r (hark [love "-l" "src/apps/cook.l" "-j4" "-f" (dir + "/Makefile") "all"]) (two? r ? >r ""))
   _ (ok "-j4 glued reads as -j 4" (j1 = jg))

   ; an edge still orders: one finishes before two starts
   _ (sh ("rm -f " + (D "/j/log" + (" " + (D "/j/one " + D "/j/two")))))
   jchain (mk [".PHONY: all"
               ("all: " + D "/j/two")
               (D "/j/one:") ("\t@sleep 1; echo one >> " + (D "/j/log" + ("; touch " + D "/j/one")))
               (D "/j/two: " + D "/j/one") ("\t@echo two >> " + (D "/j/log" + ("; touch " + D "/j/two")))])
   _ (run-cookj jchain "all" "4")
   jlog (: r (sh ("cat " + D "/j/log")) (two? r ? >r ""))
   _ (ok "-j4 keeps an edge in order" (has? jlog "one\ntwo"))

   ; a red recipe under -j is still red, and its siblings finish rather than leave half files
   _ (sh ("rm -f " + (D "/j/ok " + D "/j/red")))
   jred (mk [".PHONY: all"
             ("all: " + (D "/j/ok " + D "/j/red"))
             (D "/j/ok:") ("\t@sleep 1; echo OK > " + D "/j/ok")
             (D "/j/red:") "\t@exit 3"])
   _ (write-file (dir + "/Makefile") jred)
   jrst (: r (hark [love "-l" "src/apps/cook.l" "-j" "4" "-f" (dir + "/Makefile") "all"]) (two? r ? <r 0))
   _ (ok "-j4: a failed recipe fails the run" !(0 = jrst))
   _ (ok "-j4: outstanding jobs finish first" (0 = <(sh ("test -f " + D "/j/ok"))))

   ; a bare -j is make's unlimited; cook asks for a number (one unit here peaks at 2.3 GB)
   jbad (: r (hark [love "-l" "src/apps/cook.l" "-j" "x" "-f" (dir + "/Makefile") "all"]) (two? r ? <r 0))
   _ (ok "-j wants a count" !(0 = jbad))

   ; kbuild's make
   ; a name is make's: hyphens, and a computed part expanded before it is assigned
   kn (run-cook (mk '("X := y" "obj-y := a.o" "obj-$(X) += b.o" "obj- += c.o"
                     "all:" "\t@echo \"N[$(obj-y)]\"")) "all")
   _ (ok "obj-$(X) names obj-y" (has? kn "N[a.o b.o]"))
   ; += onto a simple variable expands its value now (u is unset at that line)
   ks (run-cook (mk '("s := 1" "t = $(u)" "s += [$(t)]" "u = late"
                     "all:" "\t@echo \"S[$(s)]\"")) "all")
   _ (ok "+= onto := expands now" (has? ks "S[1 []]"))
   ; -include of a missing file is no error, include of a present one still splices
   ko (run-cook (mk [("-include " + dir + "/no-such.mk") "sinclude /no/such/either.mk"
                     "all:" "\t@echo \"O[ok]\""]) "all")
   _ (ok "-include of a missing file" (has? ko "O[ok]"))
   ; $(file) bare is a variable (a foreach's), and $(eval) inside the foreach assigns
   ke (run-cook (mk '("$(foreach file,a b,$(eval V_$(file) := x$(file)))"
                     "all:" "\t@echo \"E[$(V_a)$(V_b)]\"")) "all")
   _ (ok "nested $(eval) under foreach's $(file)" (has? ke "E[xaxb]"))
   ; a name's $(..) may hold spaces; a tab-led line with no rule open is an ordinary line
   kp (run-cook (mk ["M := m" "obj-$(subst m,y,$(M)) += host/" "ifdef M" "\tobj-y += tab.o" "endif"
                     "all:" "\t@echo \"P[$(obj-y)]\""]) "all")
   _ (ok "obj-$(subst ..) names obj-y; a tab line outside a rule" (has? kp "P[host/ tab.o]"))
   ; a blank line inside a recipe leaves the rule open
   kb (run-cook (mk '("all:" "\t@echo \"B[one]\"" "" "\t@echo \"B[two]\"")) "all")
   _ (ok "a blank line inside a recipe" (has? kb "B[two]"))
   ; else ifeq chains: the first true arm, and a taken arm closes the rest
   kc (run-cook (mk ["A := 2" "ifeq ($(A),1)" "R := one" "else ifeq ($(A),2)" "R := two"
                     "else" "R := other" "endif"
                     "ifeq ($(A),2)" "T := first" "else ifeq ($(A),2)" "T := second" "endif"
                     "ifdef NOPE" "Q := a" "else ifndef NOPE" "Q := b" "endif"
                     "$(info C[$(R) $(T) $(Q)])" "all: ;@:"]) "all")
   _ (ok "else ifeq / else ifndef chains" (has? kc "C[two first b]"))
   ; an expanded value keeps its $: a :=, a call's argument, a foreach's word, $(value)
   kd (run-cook (mk ["x := $$y" "w := $(call f,$$p,q)" "v := $(foreach i,$$k,<$(i)>)" "u := $x"
                     "u += $$m" "define f" "$(1)-$(2)" "endef"
                     "$(info D[$(x)] [$(call f,$$p,q)] [$(v)] [$(value x)] [$(u)])" "all: ;@:"]) "all")
   _ (ok "$$ survives := call foreach value +=" (has? kd "D[$y] [$p-q] [<$k>] [$y] [$y $m]"))
   ; define's value stops before the newline that precedes endef
   kf (run-cook (mk ["define g" "a" "b" "endef" "$(info F[$(g)])" "all: ;@:"]) "all")
   _ (ok "define drops the newline before endef" (has? kf "F[a\nb]"))
   ; $(intcmp): gt falls back to eq; two args answer the number when equal
   ki (run-cook (mk ["$(info I[$(intcmp 1,2,lt,eq,gt) $(intcmp 3,2,lt,eq) $(intcmp 3,2,lt,eq,gt) $(intcmp 2,2)])"
                     "all: ;@:"]) "all")
   _ (ok "$(intcmp ..)" (has? ki "I[lt eq gt 2]"))
   ; $(file <f) reads a file less its last newline, as kbuild's read-file does
   _ (write-file (dir + "/rf.txt") "hi there\n")
   kr (run-cook (mk [("R := $(file <" + dir + "/rf.txt)") "$(info R[$(R)])" "all: ;@:"]) "all")
   _ (ok "$(file <f)" (has? kr "R[hi there]"))
   ; a caller of cook-vars may answer $(shell ..) itself
   hv (cite 'cook 'cook-vars)
   ht (pins {} " shell" (c \ "<" + c + ">"))
   _ (hv "X := $(shell uname -m)\n" ht)
   _ (ok "cook-vars: a caller's $(shell) answerer" (ht "X" = "<uname -m>"))
   ; `export A B` exports each, and a recipe sees both
   kx (run-cook (mk ["A := a1" "B = b$(A)" "export A B" "all:" "\t@echo \"X[$$A $$B]\""]) "all")
   _ (ok "export A B exports each" (has? kx "X[a1 ba1]"))
   ; an included file is on MAKEFILE_LIST while it is read
   _ (write-file (dir + "/inc.mk") "ME := $(lastword $(MAKEFILE_LIST))\n")
   km (run-cook (mk [("include " + dir + "/inc.mk") "$(info M[$(notdir $(ME))])" "all: ;@:"]) "all")
   _ (ok "MAKEFILE_LIST names the file being read" (has? km "M[inc.mk]"))
   ; a define body's tab-led lines join as a variable's: one space, the whitespace around it gone
   kj (run-cook (mk ["define v" "\tone two  \\" "\t\tthree" "endef" "$(info J[$(v)])" "all: ;@:"]) "all")
   _ (ok "a define's continuation folds as a variable's" (has? kj "J[\tone two three]"))
   ; target-specific assignments come back for a reader that scopes them, newest first
   tt {}
   _ (hv "T := a.o\n$(T) b.o: private X := 1\n%.p: Y += 2\nv: export Z = 3\n" tt)
   _ (ok "cook-vars: target-specific assignments, private off, export kept"
         (tt " tvars" = [["v" "export Z = 3"] ["%.p" "Y += 2"] ["a.o b.o" "X := 1"]]))
   ; expansion copies the text between references whole: $$, a one-letter name, a stray $ and
   ; a trailing one each keep their place
   ce (cite 'cook 'cook-expand)
   _ (ok "expand: the text around references" (ce "x$(A)y$$z$Bw$,v$" (pins {} "A" "1" "B" "2") = "x1y$z2w$,v$"))
   _ (ok "$(subst): every match, an empty from changes nothing"
         (ce "$(subst ab,X,abcabab)|$(subst ,X,abc)" {} = "XcXX|abc"))
   ; a .cmd's deps_ line is thousands of words: a := of it must stay linear
   lw (join " " (map (i \ "/k/include/linux/h" + show i + ".h $(wildcard include/config/C" + show i + ")") ^4000))
   lt {}
   t0 (clock 0)
   _ (hv ("D := " + lw + "\n") lt)
   _ (ok "a := of a long value is linear" (clock 0 - t0 < 3000 && #(words (lt "D")) = 4000))

   ; a caller's command line, named under " cl", beats a file's assignment: = and += pass
   ; it by, override does not, and $(origin) says so
   tc (pins {} " cl" ["CC" "W"] "CC" "mine" "W" "a")
   _ (hv "CC = clang\nW += b\nO = x\noverride CC2 = y\nOC := $(origin CC) $(origin O)\n" tc)
   _ (ok "cook-vars: the caller's command line beats the file" (tc "CC" = "mine" && tc "W" = "a"))
   _ (ok "cook-vars: $(origin) of a caller's command-line name" (tc "OC" = "command line file"))
   tc2 (pins {} " cl" ["CC"] "CC" "mine")
   _ (hv "override CC = clang\n" tc2)
   _ (ok "cook-vars: override beats the command line" (tc2 "CC" = "clang"))

   _ (sh ("rm -rf " + dir))
   np (peep pass 0 0) nf (peep fail 0 0)
   _ (puts (show np + (" cook tests pass" + ? (0 < nf) (", " + (show nf + " FAIL")) "")))
   _ (putc 10)
   _ (0 < nf ? 0 (puts "cook: ok\n"))
   (0 < nf ? (quit 1) 0))
