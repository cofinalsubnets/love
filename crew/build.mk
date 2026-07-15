# crew/build.mk -- the crew app builds (kore/aicc/reef scripts + aicc.image)
#
# Fragment of the root Makefile (split out 2026-07-15). Included by ./Makefile,
# which is invoked from the project root; paths resolve from there. Shared vars
# live in common.mk. Every recipe here is unchanged from the single-file Makefile.

# kore (crew/kore/): the myers + patience diff engines, the text/tool surface,
# the line tools (crew/kore/core.l: cat head tail wc sort uniq tee + the trivia),
# and `kore`, the multi-call toolbox (busybox's trick -- one binary, the util picked
# off the command line or an argv[0] symlink; crew/kore/kore.l is the dispatcher).
# The law file holds the engines to their projections, to an O(nm) LCS oracle
# (minimality), the u-floor to its GNU faces, and seeded fuzzes; the kore smokes then
# drive the BUILT artifact: diff + the line tools byte-identical to GNU (LC_ALL=C
# for sort), the exit triple, argv[0] dispatch through a `diff` symlink, usage at 2,
# and (x86_64) `kore as` assembling an exit(7) ELF that RUNS. Gate = the law sentinel
# AND exit 0 AND the smokes.
korefiles = crew/kore/text.l crew/kore/core.l crew/kore/fs.l crew/kore/re.l crew/kore/sed.l crew/kore/proc.l crew/vi/core.l crew/vi/vi.l crew/kore/diff.l tools/ain.l crew/cook/cook.l crew/kore/asbook.l crew/holo/elf.l crew/holo/obj.l crew/kore/kore.l
# aicc: the C compiler is its OWN app, NOT baked into the kore cat -- a cc edit rebuilds
# only aicc (never kore), so an kore rebuild in another session can't tear the compiler.
# Its own catted `#!/usr/bin/env -S ai -l` script: the u-floor (text+core), the assembler
# book + elf/obj writers, then crew/cc/{lex,cpp,parse,gen,cc}.l whose tail SEAT fires.
aiccfiles = crew/kore/text.l crew/kore/core.l crew/kore/asbook.l crew/holo/elf.l crew/holo/obj.l crew/holo/link.l crew/cc/lex.l crew/cc/cpp.l crew/cc/parse.l crew/cc/gen.l crew/cc/cc.l
# (`ho` is defined further down, after this rule is READ -- target/prereq names
# expand at parse time, so these two lines spell out/host$(hsuf) themselves.)
out/host$(hsuf)/kore: $(korefiles)
	@echo AI	$(abspath $@)
	@{ echo '#!/usr/bin/env -S ai'; cat $(korefiles); } > $@
	@chmod 755 $@
out/host$(hsuf)/aicc: $(aiccfiles)
	@echo AI	$(abspath $@)
	@{ echo '#!/usr/bin/env -S ai -l'; cat $(aiccfiles); } > $@
	@chmod 755 $@
# reef: the patch-set vcs (crew/reef/reef.l over the kore text+diff floor;
# doc/reef.md). its own catted shebang script, the aicc precedent.
reeffiles = crew/kore/text.l crew/kore/diff.l crew/reef/reef.l
out/host$(hsuf)/reef: $(reeffiles)
	@echo AI	$(abspath $@)
	@{ echo '#!/usr/bin/env -S ai'; cat $(reeffiles); } > $@
	@chmod 755 $@
# the aicc image: the compiler baked WARM (the live bake, doc/snapshot.md). The
# cat loads under a NEUTRAL name so cc.l's tail SEAT stays quiet, then the bake
# nif snapshots the session. AI_NO_IMAGE rides the recipe (exported above), so
# the bake session itself egg-boots -- same warm state, deterministically.
$(ho)/aicc.image: $(ho)/aicc $m
	@echo AI	$(abspath $@)
	@cp $(ho)/aicc $(ho)/.aicc-cat.l
	@$m -l $(ho)/.aicc-cat.l -e '(? ((bake "$@") = 1) (quit 0) (quit 1))'
# the kore image: the multi-call toolbox baked WARM, the aicc.image precedent. the
# cat loads under a NEUTRAL name so kore.l's SEAT me? is false and stays quiet, then
# the bake snapshots. test_kore wakes it per tool (`--wake kore.image -e '(kore-main
# (link "kore" (cuup (cup cmdline))))'`) -- ~0.02s vs ~0.75s cold, across its ~77 spawns.
$(ho)/kore.image: $(ho)/kore $m
	@echo AI	$(abspath $@)
	@cp $(ho)/kore $(ho)/.kore-cat.l
	@$m -l $(ho)/.kore-cat.l -e '(? ((bake "$@") = 1) (quit 0) (quit 1))'
