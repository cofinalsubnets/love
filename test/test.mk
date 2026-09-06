# test/test.mk -- the test_* gates (and the uuwm/uukind corpus generators).
# A fragment of the root Makefile, included by ./Makefile and invoked from the
# project root; paths resolve from there. Shared vars live in mk/common.mk.

# EVERY gate below is phony, this roster included -- a gate whose name is missing here
# stops running the day a file of that name appears. Generated from what this file
# defines; the root Makefile names only its own verbs.
.PHONY: \
  moon-bzip2 moon-bzip2-a64 moon-bzip2-rv64 moon-gzip moon-gzip-a64 moon-gzip-rv64 \
  moon-lua moon-lua-a64 moon-lua-rv64 moon-m4 moon-m4-a64 moon-m4-rv64 moon-sqlite \
  moon-sqlite-a64 moon-sqlite-rv64 moon-tar moon-tar-a64 moon-tar-rv64 mx nettest test \
  test_as test_asmops test_bakerep test_big test_cca64 test_ccrv64 test_ccthumb1 \
  test_ccthumb2 test_clay test_cli test_cookdiff test_cpio test_cts test_cts_a64 \
  test_cts_rv64 test_disk test_dist test_distboot test_doc test_drat test_drv test_dtb \
  test_elf32 test_encver test_extra test_extract test_fat test_fat32 test_filemode test_fixpoint \
  test_forge test_freebsd test_freebsd_a64 test_front test_gc test_gcheck test_gcstress \
  test_gen test_glaze test_glazefuzz test_gz test_hdiff test_holo test_holofuzz test_hook \
  test_host test_hostegg test_hostnif test_inle test_kboot test_kernel_a64 test_kernel_rv64 test_kore \
  test_kverb test_libc test_love0 test_lux test_moon test_moonfuzz test_mps2 test_mps2_t1 \
  test_mps2_wake test_mx test_netbsd test_netbsd_a64 test_nucleo446 test_nucleo446_smoke \
  test_objcopy test_playdate test_proof test_raw test_raw_a64 test_raw_bake test_raw_rv64 \
  test_refuzz test_root test_rv64 test_rp2040 test_rvboot test_sat test_sb test_seat test_seed \
  test_selfhost test_slow test_stdinbuf test_stdincorpus test_tco0 test_teensy41 test_thumb1 \
  test_thumb2 test_thumb2sp test_tools test_uefi test_uefi_a64 test_ulp test_uugen \
  test_uuhomgen test_uukind test_uulean test_uumx test_uusplgen test_uuvallaw test_uuwm \
  test_vec test_vi test_virt test_wake test_wasm test_xfixpoint uuhomgen uukind uumx uusplgen \
  uuvallaw uuwm vmret waits

# THE THREE GATES. `make test` is the fast one an edit loop runs, test_slow the
# merge gate, test_extra the really slow one (qemu boots, cross-arch, boards).
# Everything below is a member of one of them, or opt-in by name.
test_phases = test_host test_love0
# fast gate
test:
	@$(MAKE) --no-print-directory $(test_phases)

# slow gate
test_slow: test_host test_love0 vmret test_bakerep test_stdinbuf test_stdincorpus test_seat test_cli test_cookdiff test_dist test_seed


# really slow gate
test_extra: test_filemode waits test_front test_proof test_gen test_uugen test_uulean test_uuwm \
	test_uukind test_gc test_gcheck test_gcstress test_extract test_big test_mx \
	test_tools test_web test_hostnif test_doc test_glaze test_hook test_sat test_holo test_as \
	test_holofuzz test_glazefuzz test_encver test_lux test_kore test_refuzz test_sb test_vi \
	test_moon test_clay test_moonfuzz test_forge \
	test_cts test_libc test_ulp test_raw \
	test_drv test_hdiff test_tco0 nettest test_wake test_gz test_cpio test_fat32 test_root \
	test_uuhomgen test_uusplgen test_uumx test_uuvallaw \
	test_fixpoint test_xfixpoint test_raw_bake test_drat test_vec \
	test_asmops test_dtb test_rvboot test_elf32 test_objcopy test_distboot test_fat test_wasm \
	test_rv64 test_cca64 test_ccrv64 test_ccthumb1 test_ccthumb2 test_cts_a64 test_cts_rv64 \
	test_raw_a64 test_raw_rv64 \
	test_virt test_thumb1 test_thumb2 test_thumb2sp \
	test_mps2 test_mps2_t1 test_mps2_wake test_nucleo446 test_nucleo446_smoke \
	test_playdate test_rp2040 test_teensy41 \
	test_freebsd test_netbsd test_freebsd_a64 test_netbsd_a64 \
	test_inle

# $m is the WARM love -- the baked image woken, what ships. a gate whose subject is
# the egg boot spells LOVE_NO_IMAGE=1 itself; love0 is always the egg.

# love0 bakes prel+ev+repl + the whole corpus and self-tests BOTH compilers in one run
# (-Dai_tco=0, the trampoline lane too), so it must print TWO "tests pass" summaries: a
# reader stop drops the rest of the stream and exits 0. Status rides `.rc` -- no pipefail.
# ⚠ corpus.list IS A RUNTIME INPUT NOW, not only a stamp: love0 reads it to find the corpus
# (src/host/main.c), so it has to EXIST before love0 runs. It used to be pulled in as tests0.h's
# prerequisite; with the corpus off the bootstrap's dependency graph, nothing else asks for it,
# and a fresh tree died with `love0: corpus: cannot open out/lib/corpus.list` -- which the
# unpacked-release path found and no in-tree run could, out/lib always being warm here.
test_love0: $(love0) out/lib/corpus.list
	@echo TEST $(love0)
	@{ $(love0) </dev/null; echo $$? > out/.test_love0.rc; } | tee out/.test_love0.out; \
	  s=$$(cat out/.test_love0.rc); \
	  [ $$s -eq 0 ] && [ `grep -c "tests pass" out/.test_love0.out` -eq 2 ]
# test_filemode -- FILE MODE IS TERMINAL, and nothing inside the corpus can gate that:
# a test that proves the run dies cannot also report. so a shell runs one two-line file
# and asks both halves of the law -- the face on err AND exit 1 -- for a missing name.
test_filemode: $(ho)/.love.baked
	@echo TEST file mode is terminal
	@printf '(: _ (puts "reached\\n") _ (an-name-the-book-lacks 1) (puts "past\\n"))\n' > out/.test_filemode.l
	@$m out/.test_filemode.l > out/.test_filemode.out 2>&1; r=$$?; \
	  { [ $$r -eq 1 ] && grep -q "^reached$$" out/.test_filemode.out \
	      && grep -q "^;; missing an-name-the-book-lacks$$" out/.test_filemode.out \
	      && ! grep -q "^past$$" out/.test_filemode.out; } \
	    || { cat out/.test_filemode.out; echo "FAIL file mode not terminal (exit $$r)"; exit 1; }
# test_stdinbuf -- WHAT WE BORROW OF fd 0 IS INVISIBLE, and we borrow two things. Both doors
# read the device in 4096-byte gulps (src/core/love.c's rbio_of), so the first law is that BOTH ANSWER
# THE SAME: the bytes our reader has not taken are still there for an in-form (slurp in), and
# still there for a child that inherits the fd. A seekable door puts them back with an lseek;
# a pipe has no rewind, so stdin_hand DELIVERS them down a fresh pipe instead -- which is why
# the handoff laws below are asked of the PIPE output directly and not only of the diff. The
# pipe also lends its O_NONBLOCK bit (`inflag`), and the law for that one is read straight off
# /proc: a child must inherit fd 0 BLOCKING, or it takes an empty pipe for an ended one.
# The corpus cannot gate any of this; it exists only BETWEEN two ways of being fed.
test_stdinbuf: $(ho)/.love.baked
	@echo TEST stdin borrows a run
	@printf '(say out (+ "rest: [" (+ (slurp in) "]")))\n(say out "tail form")\n' > out/.test_stdinbuf1.l
	@printf '(exec ["cat"])\nHANDOFF-TAIL\n' > out/.test_stdinbuf2.l
	@for f in out/.test_stdinbuf1.l out/.test_stdinbuf2.l; do \
	   $m < $$f > $$f.seek 2>&1; cat $$f | $m > $$f.pipe 2>&1; \
	   cmp -s $$f.seek $$f.pipe \
	     || { echo "FAIL $$f: the buffered door differs from the bare one"; \
	          diff $$f.pipe $$f.seek; exit 1; }; done
	@grep -qF 'rest: [(say out "tail form")' out/.test_stdinbuf1.l.seek \
	  || { cat out/.test_stdinbuf1.l.seek; echo "FAIL an in-form (slurp in) lost the remainder"; exit 1; }
	@for w in seek pipe; do grep -qF HANDOFF-TAIL out/.test_stdinbuf2.l.$$w \
	  || { cat out/.test_stdinbuf2.l.$$w; echo "FAIL the exec'd child lost the fd position ($$w)"; exit 1; }; done
	@# ..and the residue is only the FIRST gulp: past it the pumper must splice the rest of the
	@# pipe, whose writer is still going (200000 bytes against a 64K pipe, so cat really blocks).
	@{ printf '(exec ["cat"])\n'; yes HANDOFF-BULK | head -c 200000; } > out/.test_stdinbuf4.l
	@cat out/.test_stdinbuf4.l | $m 2>/dev/null | wc -c > out/.test_stdinbuf4.n
	@n=`cat out/.test_stdinbuf4.n`; [ $$n -eq 200000 ] \
	  || { echo "FAIL the pumper delivered $$n of 200000 -- the splice past the residue stopped short"; exit 1; }
	@printf '(exec ["cat" "/proc/self/fdinfo/0"])\n' > out/.test_stdinbuf3.l
	@cat out/.test_stdinbuf3.l | $m > out/.test_stdinbuf3.out 2>&1; \
	  fl=$$(sed -n 's/^flags:[[:space:]]*//p' out/.test_stdinbuf3.out); \
	  [ -n "$$fl" ] && [ $$(( $$fl & 04000 )) -eq 0 ] \
	    || { cat out/.test_stdinbuf3.out; \
	         echo "FAIL fd 0 handed on nonblocking (flags $$fl) -- stdin_give did not put the bit back"; exit 1; }
# ..and the GIVE-BACK rides the same seek: `unchug` puts drained bytes back into the run, so
# ai_io_pending counts them again and the child inherits fd 0 in front of them. ⚠ THE CONTRAST
# IS THE LAW: `chug` drains the WHOLE borrowed run, so without the give-back the child inherits
# NOTHING and with it all ten. It is what an ai_io_unread reaching by bio_of would break -- the
# run is BORROWED under a static, so only rbio_of finds it, and a heap-port-only door would
# answer 0 here while every file-port law in test/io.l still passed.
	@printf 'abcdefghij' > out/.test_stdinbuf4.in
	@p='(: c (see in) _ (unsee in c) t (chug in)'; \
	  a=`$m -e "$$p k (unchug in 99) (exec [\"cat\"]))" < out/.test_stdinbuf4.in`; \
	  b=`$m -e "$$p (exec [\"cat\"]))" < out/.test_stdinbuf4.in`; \
	  { [ "$$a" = abcdefghij ] && [ -z "$$b" ]; } \
	    || { echo "FAIL unchug is not in the inherited fd offset (with=[$$a] without=[$$b])"; exit 1; }
# test_host takes the corpus as a FILE, and that is a SPEED choice, not a necessity:
# stdin works (test/io.l used to poke `in` and eat a byte of whatever fed the suite --
# it taps a charlist now), and it is equally strict, quitting 1 on a scare either way.
# What is left of the gap is the READER, not the device: a redirect gulps 4096 like
# the file does (src/core/love.c's rbio_of), but `reads` trickles `in` a byte at a time to keep
# its position exact, which costs ~1.45x here. This is the gate that runs constantly.
# cat'ing also keeps the corpus's one-global-scope property.
test_host: $(ho)/.love.baked
	@echo TEST $m
	@cat $t > out/.test_host.l
	@{ $m out/.test_host.l </dev/null; echo $$? > out/.test_host.rc; } | tee out/.test_host.out; \
	  s=$$(cat out/.test_host.rc); \
	  [ $$s -eq 0 ] && grep -q "tests pass" out/.test_host.out
# test_hostegg -- the same corpus down the EGG boot, for the gates that can afford both
# doors. $m wakes the image, so test_host reads one heap only, and the two are not the same
# heap: a woken one arrives with a pinned prefix it did not copy and an intern map it did
# not build. three baked-only GC gates once passed a commit that broke the egg lane, and
# test_stdincorpus -- the one gate that ran both -- caught it on its first run.
# ⚠ it asks for $(ho)/love, NOT .love.baked: an egg lane has no use for the ~12 s bake, and
# a gate that pulled the stamp would pay it for a binary it then tells to ignore the image.
# ⚠ it counts TWO asserts fewer than test_host, and that is right: test/holo.l opens on
# `(lit? (from 'holo))`, and holo lives in the glaze -- so its two backend laws are the
# baked door's alone. Fewer asserts is not less collector; it is a different heap.
test_hostegg: $(ho)/love
	@echo TEST $m "(egg)"
	@cat $t > out/.test_hostegg.l
	@{ env LOVE_NO_IMAGE=1 $m out/.test_hostegg.l </dev/null; echo $$? > out/.test_hostegg.rc; } | tee out/.test_hostegg.out; \
	  s=$$(cat out/.test_hostegg.rc); \
	  [ $$s -eq 0 ] && grep -q "tests pass" out/.test_hostegg.out
# test_stdincorpus -- THE ORACLE FOR `reads` OVER STDIN, and nothing else was one. test_host
# takes the corpus as a FILE (the speed choice above) and test_stdinbuf runs two-line programs,
# so at the scale where a reader's window arithmetic actually breaks, nothing looked: a `reads`
# that parsed the corpus's own English COMMENTS as code still printed "3959 tests pass" on the
# file door and exited 0. It was caught by hand-diffing the doors; this is that diff, kept.
# ⚠ ALL THREE DOORS, because they are three different readers -- a file and a redirect share the
# borrowed run (src/core/love.c's rbio_of), a pipe has none and drips.
# ⚠ the summary line carries a DURATION, so that is normalised away and everything else must
# match byte for byte -- the dots included, since a dropped assert is exactly what this catches.
# ⚠ AND BOTH LOVES. The egg lane and the baked image are not interchangeable here: a
# reader bug that lost two bytes of the corpus showed on the baked lane and NOT on the
# egg one, so a gate that ran only the egg reported ok while the shipped binary read
# 2286 of 3959 asserts and quit 1.
test_stdincorpus: $(ho)/.love.baked
	@echo TEST the corpus down file, redirect and pipe -- egg and baked
	@cat $t > out/.test_sc.l
	@for L in "env LOVE_NO_IMAGE=1 $m" "$m"; do \
	 for d in file seek pipe; do \
	   case $$d in \
	     file) $$L out/.test_sc.l < /dev/null > out/.test_sc.$$d 2>&1;; \
	     seek) $$L < out/.test_sc.l > out/.test_sc.$$d 2>&1;; \
	     pipe) cat out/.test_sc.l | $$L > out/.test_sc.$$d 2>&1;; \
	   esac; \
	   r=$$?; \
	   [ $$r -eq 0 ] \
	     || { echo "FAIL [$$L] the $$d door exited $$r"; tail -4 out/.test_sc.$$d; exit 1; }; \
	   grep -q "tests pass" out/.test_sc.$$d \
	     || { echo "FAIL [$$L] the $$d door printed no summary"; tail -4 out/.test_sc.$$d; exit 1; }; \
	   ! grep -q "^;;" out/.test_sc.$$d \
	     || { echo "FAIL [$$L] the $$d door scared"; grep -m3 "^;;" out/.test_sc.$$d; exit 1; }; \
	   sed 's/in [0-9.]* seconds/in Xs/' out/.test_sc.$$d > out/.test_sc.$$d.n; \
	 done; \
	 for d in seek pipe; do \
	   cmp -s out/.test_sc.file.n out/.test_sc.$$d.n \
	     || { echo "FAIL [$$L] the $$d door read a different corpus than the file door"; \
	          diff out/.test_sc.file.n out/.test_sc.$$d.n | head -8; exit 1; }; \
	 done; \
	 done
	@echo "  ok   file, redirect and pipe read the corpus identically on both loves"
# test_front -- the TEST-ONLY FRONTEND: out/front links liblove.a (src/core/love.c only)
# and supplies the frontend contract itself, so its port vt can answer WOULD-BLOCK on
# cue. ⚠ it EXITS 97 on a wait with no deadline -- a deadlock, said loudly.
$(ho)/front: test/front/main.c $(love_h) $(ho)/liblove.a $(ho)/.hostcc $(R)/src/core/love_data.ld \
    out/lib/egg.h out/lib/post.h out/lib/p1.h out/lib/prel.h out/lib/ev.h
	@echo 'CC	'$@
	@mkdir -p $(dir $@)
	@$(hcc) -o $@ test/front/main.c $(ho)/liblove.a $(data_ld) $(nifs_ld)
test_front: $(ho)/front
	@echo TEST $(ho)/front
	@sh test/gate/run.sh -a front "$(ho)/front" "front: ok" test/front/io.l
# Host-nif smoke tests: the host lane's nifs link into `love` but NOT love0, so they live under
# test/host/, invisible to the corpus glob ($t is a non-recursive test/*.l). Gate = exit 0
# AND a "<name>: ok"; a cold lane opts in via hostnif_cold.
hostnif_tests = test/host/rdiff.l test/host/loader.l test/host/gcpause.l test/host/run.l test/host/pty.l test/host/net.l test/host/lux.l test/host/luxui.l test/host/baoedit.l test/host/baotest.l test/host/init.l test/host/fs.l test/host/sh.l test/host/cb.l test/host/berth.l test/host/wharf.l test/host/limn.l test/host/manifest.l test/host/overlay.l test/host/bake.l test/host/rove.l test/host/rune.l test/host/lapiz.l test/host/papel.l test/host/kiosko.l test/host/serve.l test/host/sbhttp.l test/host/json.l test/host/salt.l test/host/libra.l test/host/clay.l test/host/fat.l test/host/tls.l test/host/tlsc.l test/host/gz.l test/host/gzc.l test/host/hash.l test/host/story.l test/host/design.l test/host/helm.l test/host/wget.l
# out/lush: test/host/sh.l drives the BUILT shell end to end, via out/love and
# never env's PATH love -- the tree's nifs, not the nest's.
hostnif_cold =                                   # empty: no gate needs the cold lane
test_hostnif: host out$(hsuf)/lush
	@for s in $(hostnif_tests); do echo "TEST $$s"; \
	  case " $(hostnif_cold) " in *" $$s "*) L="env LOVE_NO_IMAGE=1 $m";; *) L="$m";; esac; \
	  cat test/00-init.l $$s | sh test/gate/run.sh hostnif "$$L" ": ok" \
	    || { echo "  (the gate above is $$s)"; exit 1; }; \
	done
# Runnable design companions -- pure-love models that pin the shape a C design
# takes. Zero-dep, but they leak helper names into the
# one global scope, so they run standalone. Same contract: exit 0 AND a "<name>: ok".
doc_tests = doc/misc/proto/dest.l doc/misc/proto/spl.l
test_doc: host
	@for s in $(doc_tests); do echo "TEST $$s"; \
	  cat test/00-init.l $$s | sh test/gate/run.sh doc "$m" ": ok" \
	    || { echo "  (the gate above is $$s)"; exit 1; }; \
	done
# Native-codegen self-tests (the src/core/boot/glaze/ x86-64 jit): test/glaze-x86.l covers emit
# (the SSE emitter) + auto (ev's source-recognizer), cats the holo backends ahead of
# itself, and runs each block through base-ev. Needs the `nat` nif; x86-64 only.
ifeq ($a,x64)
test_glaze: host
	@echo TEST test/glaze-x86.l "(emit + auto)"
	@{ echo "(use 'holo)"; cat src/core/holo/x64.l src/core/holo/a64.l test/glaze-x86.l; } \
	  | sh test/gate/run.sh glaze "env LOVE_NO_IMAGE=1 $m" "test/glaze-x86:"
else
test_glaze:
	@echo "test_glaze: skipped (host arch $a is not x64)"
endif
# test_hook -- the natjit CREATION-HOOK laws: every law claims BOTH the answer and that the hook
# owned it (`fired?`), twice over the hook's two lives -- the IMAGE's ($m, what ships) and the
# EGG BOOT's ($m). ⚠ never by cat'ing hook.l in: a woken image has `nif` off the book.
ifneq ($(filter $a,x64 a64),)
test_hook: host
	@echo TEST test/glaze-hook.l "(the baked image)"
	@sh test/gate/run.sh -a hook "$m" "glaze-hook: ok" test/glaze-hook.l
	@echo TEST test/glaze-hook.l "(egg boot, hook.l out of the tree)"
	@sh test/gate/run.sh -a hook "env LOVE_NO_IMAGE=1 $m" "glaze-hook: ok" test/glaze-hook.l
else
test_hook:
	@echo "test_hook: skipped (the hook emits for x64 / a64; host arch is $a)"
endif
# test_glazefuzz -- the glaze's DIFFERENTIAL fuzz (src/core/boot/glaze/fuzz.l): 3000 random closures
# run TWICE against the SAME binary (plain, then LOVE_NO_GLAZE=1), stdouts byte-identical.
# `fires=` is the checked proof of work; stderr is dropped (the two runs scare differently).
ifneq ($(filter $a,x64 a64),)
test_glazefuzz: host
	@echo TEST src/core/boot/glaze/fuzz.l "(glaze differential fuzz: glazed vs interpreted)"
	@on=out/.gfuzz_on.out; off=out/.gfuzz_off.out; \
	  LOVE_NO_IMAGE=1 $m src/core/boot/glaze/fuzz.l > $$on 2>/dev/null \
	    || { echo "FAIL glazefuzz: the GLAZED run died"; exit 1; }; \
	  LOVE_NO_IMAGE=1 LOVE_NO_GLAZE=1 $m src/core/boot/glaze/fuzz.l > $$off 2>/dev/null \
	    || { echo "FAIL glazefuzz: the INTERPRETED run died"; exit 1; }; \
	  fon=`sed -n 's/^fires=//p' $$on`; foff=`sed -n 's/^fires=//p' $$off`; \
	  [ -n "$$fon" ] && [ -n "$$foff" ] \
	    || { echo "FAIL glazefuzz: no fires= trailer -- a run stopped early"; exit 1; }; \
	  [ "$$fon" -gt 0 ] \
	    || { echo "FAIL glazefuzz: the glazed run native-backed NOTHING (fires=0) -- the fuzz proved nothing"; exit 1; }; \
	  [ "$$foff" -eq 0 ] \
	    || { echo "FAIL glazefuzz: LOVE_NO_GLAZE=1 still fired (fires=$$foff)"; exit 1; }; \
	  sed '$$d' $$on > $$on.body; sed '$$d' $$off > $$off.body; \
	  cmp -s $$on.body $$off.body \
	    || { echo "FAIL glazefuzz: the glaze DISAGREES with the interpreter"; \
	         echo "  first differing case:"; \
	         cmp $$on.body $$off.body 2>&1 | head -1; \
	         n=`cmp $$on.body $$off.body 2>/dev/null | sed -n 's/.*line \([0-9]*\).*/\1/p'`; \
	         [ -n "$$n" ] && { echo "  glazed: `sed -n $${n}p $$on.body`"; \
	                           echo "  interp: `sed -n $${n}p $$off.body`"; }; \
	         exit 1; }; \
	  echo "  $$fon closures native-backed, `wc -l < $$on.body` cases, all agree"
else
test_glazefuzz:
	@echo "test_glazefuzz: skipped (the glaze emits for x64 / a64; host arch is $a)"
endif
# src/apps/sat/ -- the CDCL SAT solver app. Portable love (no glaze), so it runs on every arch.
# Gate = exit 0 AND the sentinels. COLD on purpose -- the one app gate that is: the
# solver answers in 3.6 s over the fresh egg and 14.4 s over the woken image.
test_sat: host
	@echo TEST src/apps/sat/sat.l + src/apps/sat/dimacs.l + src/apps/sat/flat.l
	@cat src/apps/sat/sat.l src/apps/sat/dimacs.l src/apps/sat/flat.l \
	  | sh test/gate/run.sh sat "env LOVE_NO_IMAGE=1 $m" "sat: Stages 1-3 ok|src/apps/sat/dimacs: ok|src/apps/sat/flat: ok"
# The DRAT lane's EXTERNAL check: flat.l's refutations verified by drat-trim, the SAT
# competition's own checker (fetched + built into out/drat on first use; skips offline).
# The in-gate twin (fd-check) runs inside test_sat. Not in test_slow (network).
test_drat: host
	@cd src/apps/sat && ./dratcheck.sh || { echo "FAIL drat"; exit 1; }
# The lux app's pure core (src/apps/lux/core.l): xmonad's StackSet -- focus zipper, workspace
# sheaf, floating half -- with xmonad's QuickCheck laws + a seeded fuzz. Pure love, so it
# self-tests portably; the X layers need connectu and are proven against Xephyr, not here.
test_lux: host
	@echo TEST src/apps/lux/core.l ... src/apps/lux/config.l + src/apps/lux/law.l "(the whole app, host)"
	@cat test/00-init.l src/apps/lux/core.l src/apps/lux/layout.l src/apps/lux/wire.l src/apps/lux/ewmh.l \
	    src/apps/lux/manage.l src/apps/lux/keys.l src/apps/lux/config.l src/apps/lux/law.l \
	  | sh test/gate/run.sh lux "$m" "src/apps/lux/law: StackSet"
# the SEAT lane -- an app fired by its own FILE NAME (positional, or a -l preload), which
# is the one dispatch door no other gate reaches: every app gate below drives its subject
# through the verb rail or a baked image instead. ~2.5s, most of it one bake, and it rides
# test_slow because the failure it catches is silent by construction (a seat that answers
# () is indistinguishable from an app with nothing to say).
.PHONY: test_seat test_cli
test_seat: host
	@echo TEST test/gate/seat.sh "(the file-seat lane)"
	@sh test/gate/seat.sh $m
# the CLI's exit STATUS -- 0 working, 1 unopenable, 2 malformed, a verb's own charm.
# seat.sh reads what the binary SAYS; until this, nothing read what it ANSWERS.
test_cli: host
	@echo TEST test/gate/cli.sh "(the cli exit-status lane)"
	@sh test/gate/cli.sh $m

# the front page, its sheet and its icon are laid (web/index.l, web/style.l, tools/mkicon.l)
# and checked in for github pages: a lay that differs from the tree means someone edited a
# source without `make web`.
test_web: host
	@echo TEST web/index.l web/style.l tools/mkicon.l
	@mkdir -p out/.web
	@$m web/index.l out/.web/index.html
	@env -u LOVE_NO_IMAGE $m web/style.l out/.web/style.css
	@env -u LOVE_NO_IMAGE $m tools/mkicon.l src/core/quay/cga_8x8.c 3 32 out/.web/favicon.png 2>/dev/null
	@cmp -s out/.web/index.html index.html && cmp -s out/.web/style.css assets/web/style.css \
	  && cmp -s out/.web/favicon.png assets/web/favicon.png \
	  || { echo "  FAIL: index.html, style.css or favicon.png is behind web/ -- run make web and commit"; exit 1; }
	@echo "  web: ok -- index.html, style.css and favicon.png are what web/ lays"
test_sb: host out$(hsuf)/sb
	@echo TEST src/apps/sb/sb.l + test/host/sb.l
	@rm -rf out/.sbtest
	@cat test/00-init.l test/host/sb.l | sh test/gate/run.sh sb "$m" "sb: ok"
# the kore smokes drive love's own crew layer (`love kore ..` -- the layered bake,
# doc/misc/plan/one-binary.md), warm per spawn; the argv0 smoke lays its own two-line shim,
# the distro's shape, since the tree carries no kore binary anymore.
korerun = $m kore
test_kore: host
	@sh test/gate/kore.sh $(ho) $m
# grep + sed against GNU over SEEDED RANDOM patterns (doc: the script's own head).
# test_kore's battery is a list someone thought of; this one is not, which is why it
# found the (a*)+ empty-iteration bug and the -w greedy-span bug that the battery,
# the laws and a green test_slow all sat happily on top of. Skips (exit 0) where GNU
# grep/sed are absent -- and checks --version, since an interactive `grep` may be a
# ugrep shim whose BRE differs. Rides test_extra: it costs ~a minute.
test_refuzz: host
	@sh test/gate/refuzz.sh $m
# cook against GNU MAKE, differentially (doc: the script's own head). The oracle is a
# SECOND IMPLEMENTATION, and it has to be: a builtin cook never implemented is a VARIABLE
# reference in make's grammar, so it expands to EMPTY and the build carries on -- invisible
# to any test that only asks whether cook agrees with itself. Skips (exit 0) where GNU make
# is not on the box, since there is no oracle to ask.
test_cookdiff: host
	@sh test/gate/cookdiff.sh $m
# the dist artifact -- the tree's own baked binary: test_dist smokes its verb rail,
# the bare cc door, the image chain and the in-image lane. seconds, test_slow.
test_dist: $(ho)/.love.baked
	@sh test/gate/dist.sh smoke $(ho)/love
# test_seed -- THE MERGE GATE: the artifact lays its own source into a scratch dir and
# rebuilds itself through the machine's toolchain; the rebuilt binary must answer the
# running one's bytes (`love seed`). Minutes -- a whole bootstrap -- and the claim the
# product makes, so it rides the slow gate. The scratch stays on a red for the autopsy.
# ⚠ WHAT ONLY THIS GATE SAYS: the DEFAULT lane, where the seed probes for an ambient cc
# that works and DEFERS to it (src/apps/source/source.l). test_distboot runs `love seed` too, but with
# every compiler poisoned, so it takes the fallback and can never exercise the deference.
# That deference is the diverse-double-compiling leg -- a foreign compiler holding the
# scaffold, the one thing a self build cannot say -- and it stopped working for eleven
# days (2026-08-14 to 08-25) with every gate green, because this is the only gate that
# runs it and a roster note had called it the same claim as test_distboot's circle.
test_seed: $(ho)/.love.baked
	@echo TEST love seed "(the fixpoint)"
	@rm -rf $(ho)/.seedtest && mkdir -p $(ho)/.seedtest
	@$(ho)/love seed $(ho)/.seedtest > $(ho)/.test_seed.out 2>&1 \
	  || { tail -20 $(ho)/.test_seed.out; echo "FAIL love seed"; exit 1; }
	@tail -1 $(ho)/.test_seed.out
	@rm -rf $(ho)/.seedtest
# The editor (src/apps/vi/): the pure modal engine's laws (no tty -- vstep driven byte by
# byte), then scripted end-to-end passes through the `kore vi` face over a pipe (keys off
# stdin, frames onto a captured stdout, :wq writes), driven through the crew layer.
test_vi: host
	@echo TEST src/apps/vi/{hue,core,law}.l
	@cat test/00-init.l src/apps/kore/text.l src/apps/kore/u.l src/apps/kore/core.l src/apps/kore/re.l src/apps/kore/sed.l src/apps/libra/lint.l \
	    src/apps/vi/config.l src/apps/vi/hue.l src/apps/vi/core.l src/apps/vi/law.l \
	  | sh test/gate/run.sh vi "$m" "src/apps/vi/law:"
	@rm -f $(ho)/.vi1; \
	  printf 'ihello world\033:wq\n' | $(korerun) vi $(ho)/.vi1 > /dev/null 2>&1; r=$$?; \
	  { [ $$r -eq 0 ] && [ "$$(cat $(ho)/.vi1)" = "hello world" ]; } \
	    || { echo "FAIL kore vi create+write (exit $$r)"; exit 1; }; \
	  printf 'ddZZ' | $(korerun) vi $(ho)/.vi1 > /dev/null 2>&1; r=$$?; \
	  { [ $$r -eq 0 ] && [ "$$(cat $(ho)/.vi1)" = "" ]; } \
	    || { echo "FAIL kore vi dd+ZZ (exit $$r)"; exit 1; }; \
	  printf 'ix\033:q!\n' | $(korerun) vi $(ho)/.vi1 > /dev/null 2>&1; r=$$?; \
	  { [ $$r -eq 0 ] && [ "$$(cat $(ho)/.vi1)" = "" ]; } \
	    || { echo "FAIL kore vi q! holds fire (exit $$r)"; exit 1; }; \
	  printf 'AX\033u:wq\n' | $(korerun) vi $(ho)/.vi1 > /dev/null 2>&1; r=$$?; \
	  { [ $$r -eq 0 ] && [ "$$(cat $(ho)/.vi1)" = "" ]; } \
	    || { echo "FAIL kore vi undo (exit $$r)"; exit 1; }; \
	  printf 'ione\ntwo\nthree\033:1,$$s/o/0/g\n:2,3m0\n:wq\n' \
	    | $(korerun) vi $(ho)/.vi1 > /dev/null 2>&1; r=$$?; \
	  { [ $$r -eq 0 ] && [ "$$(tr '\n' ' ' < $(ho)/.vi1)" = "tw0 three 0ne " ]; } \
	    || { echo "FAIL kore vi ex :s + :m (exit $$r)"; exit 1; }; \
	  echo "kore: vi (laws + piped create/dd/q!/undo/ex end-to-end) ok"
# The C compiler (src/apps/moon/, doc/misc/moon.md): the pure pipeline's goldens, then stage-0 end
# to end through the real `mooncc` -- compile, run, exit 42, against a gcc -O0 differential
# on the same source. Drives the crew layer warm (~0.68s -> ~0.1s per compile, 88 of them).
moonrun = $m mooncc
# love0 rides along for the inline-asm checks: neutral templates parse through holo/text.l,
# whose combinators come off the bare `post` each frontend's boot binds ITSELF, so the
# bootstrap lane can lose the feature while this one keeps it.
test_moon: host $(love0)
	@sh test/gate/moon.sh $(ho) $m $(love0)
# the COMMITTED GENERATED artifacts, laid from the tables that define them (src/core/mx.l the +/*
# dispatch matrices and the kind lattice they index, src/core/nifs.l the nif + instruction registry,
# quay.l the xterm-256 palette host and kernel share). `make mx` refreshes; test_clay diffs.
# ⚠ src/core/mx.h/kinds.h/nifs.h are CORE headers -- a refresh rebuilds the tree, so the gate to run
# after is `make test`, not test_clay alone. Each is written aside and moved only once the
# whole set lays, so a shape check that quits leaves every committed file untouched.
# src/core/love_data.ld is the last linker script in the tree and is laid WHOLE: every other
# seat's link became ours, and holo needs no script at all.
# dest:source:value:shape-check -- ONE roster, read by `make mx` (which writes) and by
# test_clay (which regenerates and diffs). Two spellings of this list is how they drift.
mx_gen = src/core/mx.h:src/core/mx.l:mx-h:mx-ok src/core/kinds.h:src/core/mx.l:kinds-h:mx-ok src/core/nifs.h:src/core/nifs.l:nifs-h:nifs-ok \
         src/core/quay/xterm256.h:src/core/quay/quay.l:q-c:q-ok src/core/love_data.ld:src/core/mx.l:mx-ld:mx-ok
# /warn the \# escapes are load-bearing: a bare # in a make VARIABLE starts a comment and
# would eat the rest of the line (a recipe line passes # through, a variable does not).
mxsplit = d=$${s%%:*}; r=$${s\#*:}; l=$${r%%:*}; r=$${r\#*:}; v=$${r%%:*}; k=$${r\#*:}; o=out/.`basename $$d`
# ⚠ the EGG lane, deliberately: these generators read CORE tables with the boot
# vocabulary, and the warm book now carries the crew (the layered bake) -- kore's
# two-arg `join` shadowed clay's one-arg at mx-h's define and the .h came out empty.
mxlay   = LOVE_NO_IMAGE=1 $m -l $$l -e "(: _ (? $$k 0 (quit 1)) _ (puts $$v) (quit 0))"
mx: host
	@echo 'LOVE	'src/core/mx.h src/core/kinds.h src/core/nifs.h xterm256.h src/core/love_data.ld "(src/core/mx.l + src/core/nifs.l + quay.l on $m)"
	@for s in $(mx_gen); do $(mxsplit); $(mxlay) > $$o || exit 1; done
	@for s in $(mx_gen); do $(mxsplit); mv $$o $$d; done
# ...and the DEPENDENCY, off the same roster: a committed generated file is stale the moment
# its table moves, and the objects that include it then rebuild from the fresh one. Without
# this a new src/core/nifs.l row builds clean and gates GREEN with its nom still off the book -- the
# drift diff lives in test_clay, which only test_extra reaches.
# ⚠ the prerequisite is the TABLE ALONE, never $(m): love is built FROM these headers, so
# naming it as a prerequisite closes the loop and make drops the lot. The recipe instead takes
# whatever love ALREADY exists -- sound because the generator is src/core/nifs.l/mx.l themselves, and a
# stale love lays a fresh table. A tree with no love yet is the bootstrap case: the committed
# file is what builds the first one, so the rule stands aside and only marks it seen.
define mx_dep
$(word 1,$(subst :, ,$(1))): $(word 2,$(subst :, ,$(1)))
	@if test -x $$(m); then \
	   $$(m) -l $$< -e "(: _ (? $(word 4,$(subst :, ,$(1))) 0 (quit 1)) _ (puts $(word 3,$(subst :, ,$(1)))) (quit 0))" > out/.$$(@F) || exit 1; \
	   cmp -s out/.$$(@F) $$@ || echo "LOVE	$$@ (relaid -- $$< moved)"; \
	   mv out/.$$(@F) $$@; \
	 else touch $$@; fi
endef
$(foreach s,$(mx_gen),$(eval $(call mx_dep,$(s))))
# test_clay -- G1, clay's faithfulness gate (src/apps/moon/clay.l, doc/misc/clay.md): for every file
# in test/cc/, (cparse (clay-show ast)) == ast, STRUCTURALLY. ⚠ the run PARTITIONS and names
# both halves: what it can say, and the declarations cparse did not keep -- a measured gap.
test_clay: host
	@echo TEST test/gate/clay.l "(clay G1: (cparse (clay-show c)) == c over test/cc)"
	@$m -l test/gate/clay.l < /dev/null
# ...and the CONSUMERS: the generated headers regenerate and DIFF here -- a hand edit to any,
# or a table edit with no regen, is a red. The roster is mx_gen above; `cmp`, not rtk diff.
	@for s in $(mx_gen); do $(mxsplit); $(mxlay) > $$o; \
	   cmp -s $$o $$d || { echo "FAIL $$d is not what $$l lays -- run: make mx"; \
	                       diff -u $$d $$o | head -20; exit 1; }; done
	@echo "clay-mx: src/core/mx.h, src/core/kinds.h, src/core/nifs.h, xterm256.h and src/core/love_data.ld regenerate identically"
	@for s in $(mx_gen); do $(mxsplit); rm -f $$o; done
# test_moonfuzz -- moon's REFUSAL surface: each test/cc file broken
# eight ways from a fixed seed. Two reds -- no SCARE, no hang -- plus G1 on every mutant that
# still parses, and a printed CENSUS of named-vs-bare refusals. stderr is KEPT: cpp speaks there.
test_moonfuzz: host
	@echo TEST test/gate/moonfuzz.l "(moon refusal fuzz: 8 mutants per file over test/cc)"
	@$m -l test/gate/moonfuzz.l < /dev/null
# test_forge -- nifs WRITTEN IN LOVE (src/apps/forge/forge.l): a kernel's holo IR assembled for this cpu,
# installed through the `nif` seam, and required to agree with the twin it deopts into -- on the
# monomorphic lane it says and on every lane it hands back.
# ⚠ the twin here is the C nif itself, so a disagreement is one denotation answering two ways.
# Zero kernels fitted FAILS: a graceful decline is the design, a silent one reads like a pass.
test_forge: host
	@echo TEST test/gate/forge.l "(forge: love IR -> holo -> nif -> differential)"
	@LOVE_NO_IMAGE=1 $m -l test/gate/forge.l < /dev/null
# test_cca64 / test_ccrv64 -- the battery on a CROSS TARGET (two targets, one procedure
# in ccarch.sh): every test/cc/*.c built by `mooncc -t <arch>`, run under qemu-user, required
# to answer what x64 answers. The three programs no cross lane can build must REFUSE, not skip.
test_cca64: host
	@sh test/gate/ccarch.sh a64 $(ho) $m
test_ccrv64: host
	@sh test/gate/ccarch.sh rv64 $(ho) $m
# test_ccthumb1 / test_ccthumb2 -- the same battery on the DEVICE CPUs, where ccarch.sh's
# procedure cannot reach: M-profile has no qemu-user lane and is ILP32, so x64 is neither
# runnable nor the right oracle. arm-none-eabi-gcc's build of the same source, on the same
# machine, is (ccthumb.sh says why, and what the three exclusion lists each assert).
test_ccthumb1: host
	@sh test/gate/ccthumb.sh thumb1 $(ho) $m
test_ccthumb2: host
	@sh test/gate/ccthumb.sh thumb2 $(ho) $m
# test_cts -- an OUTSIDE corpus: c-testsuite's 220 single-file programs, each held to the
# stdout the corpus itself ships, on all three targets. Every file in test/cc/ was written
# here to pin a fault we had already met; these were not, and the first run found nine
# programs mooncc compiles clean and answers wrong. The failures are ROSTERED with a cause
# apiece in cts.sh, refusals and wrong answers kept apart. Opt-in on an imported tree
# (`make dl/c-testsuite`), skips whole without it.
test_cts: host
	@sh test/gate/cts.sh x64 $(ho) $m
test_cts_a64: host
	@sh test/gate/cts.sh a64 $(ho) $m
test_cts_rv64: host
	@sh test/gate/cts.sh rv64 $(ho) $m
# the corpus itself -- 220 files, cloned once and kept in dl/ like OVMF, so `make clean`
# leaves it and only `make distclean` asks the network again. NOTHING depends on this rule:
# a gate that downloads is a gate that fails on a train.
dl/c-testsuite:
	@echo 'MK	'c-testsuite
	@git clone --depth=1 https://github.com/c-testsuite/c-testsuite.git $@ > /dev/null 2>&1
# test_libc -- OUR C LIBRARY against the system's, function by function:
# test/libc/*.c built by mooncc (pulling src/apps/moon/lib/nolibc.c by need) and by gcc, run,
# and the two OUTPUTS compared, so a drift names the function and the case.
test_libc: host
	@sh test/gate/libc.sh $(ho) $m
# test_ulp -- THE MATH FLOOR, built by both compilers and required to agree. `make ulp`
# measures am.c's accuracy for the $(CC) build alone, which asks whether the algorithm is
# right, never whether OUR compiler builds it -- and float BITS are where codegen hides.
test_ulp: host
	@sh test/gate/ulp.sh $(ho) $m
# The rung-2 self-host gate: compile the love AND host lanes with mooncc (gcc/clang only
# LINKS), then run the whole corpus through the all-mooncc binary -- the compiler compiles
# the runtime it runs on. OPT-IN; x86-64 only; the binary carries no image, so a fresh egg.
test_selfhost: host
	@echo TEST $(ho)/love-selfhost
	@if [ "`uname -m`" != x86_64 ]; then echo "test_selfhost: x86-64 only, skipped on `uname -m`"; exit 0; fi; \
	  d=$(ho)/selfhost; mkdir -p $$d; rm -f $$d/*.o; \
	  for f in $(love_tu_c) $(host_c); do b=`basename $$f .c`; \
	    $(moonrun) -D ai_tco=$(tco) -I$(ho) -I. -Isrc/core -Isrc/host -Isrc/inle -Iout/lib -c $$f $$d/$$b.o \
	      || { echo "FAIL mooncc -c $$f"; exit 1; }; done; \
	  $(moonrun) -Isrc/apps/moon/include -c src/apps/moon/lib/math/am.c $$d/am.o \
	    || { echo "FAIL mooncc -c am.c"; exit 1; }; \
	  $(CC) -static -o $(ho)/love-selfhost $$d/*.o $(host_ldflags) \
	    || { echo "FAIL link all-mooncc binary"; exit 1; }; \
	  cat $t > $(ho)/.selfhost-corpus.l; \
	  LOVE_NO_IMAGE=1 $(ho)/love-selfhost $(ho)/.selfhost-corpus.l </dev/null > $(ho)/.test_selfhost.out 2>&1; s=$$?; \
	  tail -1 $(ho)/.test_selfhost.out; \
	  { [ $$s -eq 0 ] && grep -q "tests pass" $(ho)/.test_selfhost.out; } \
	    || { echo "FAIL all-mooncc corpus (exit $$s)"; exit 1; }; \
	  echo "test_selfhost: all `echo $(love_tu_c) $(host_c) | wc -w` src/*.c built by mooncc, corpus passes"
# The rung-4 gate: the GCC-FREE fixpoint. Everything test_selfhost builds PLUS our own raw
# libc (nolibc.c), math floor (am.c) and sys.o, bound by OUR OWN static linker -- no gcc,
# no glibc, no ld anywhere. In test_slow, x86-64 only; supersedes test_selfhost.
test_raw: host
	@gate_love_c='$(love_tu_c)' gate_host_c='$(host_c)' gate_arch_c='$(hosta_c)' \
	  sh test/gate/raw.sh x64 $(ho) $m $t
# test_tco0 -- THE TRAMPOLINE, at full strength. `tco=0` is a documented knob
# (mk/common.mk) and it had rotted to a segfault in `bake`: the glaze emits the
# TAIL-THREADED lvm shape, and nothing stopped a trampoline build from calling it.
# ⚠ love0 is the tree's other tco=0 lane and it cannot cover this -- it is the
# LoveBoot branch, which never reaches AiGlazed, so the one build that exercised
# the trampoline was the one build that could not meet the bug. this is the full
# love at tco=0: it must build, BAKE (where the segfault was), and pass the corpus.
# it takes its own hsuf'd tree, so it neither clobbers nor is clobbered by the
# default flavour. no vmret here -- at tco=0 an lvm returns, which is the point.
test_tco0:
	@$(MAKE) --no-print-directory tco=0 host
	@$(MAKE) --no-print-directory tco=0 test_host
	@echo "test_tco0: the trampoline builds, bakes and passes the host corpus"
# test_hdiff -- the FOREIGN-CC differential at the host: the one lane a cc that is not
# ours still gets to build, since nothing foreign builds the kernel at all. gcc and
# clang each link the whole vm at ai_tco=1, which the default mooncc lane never does, and
# each must build, answer, pass the quick host suite and come out ret-free. NOT the corpus
# twice over: semantics are the interpreter's, and they do not move with the compiler.
test_hdiff: host
	@echo TEST test/gate/hdiff.sh
	@sh test/gate/hdiff.sh gcc clang
# the cc-DRIVER conventions (the `CC=mooncc` door's floor): the REAL $(ai_cflags) soup
# rides through -c, a link owing libc symbols pulls the runtime by need, and the loud edges
# stay loud (-shared usage-refuses, -nostdlib names its undefined references). In test_slow.
test_drv: host
	@sh test/gate/drv.sh $(ho) $(ai_cflags)
# the kernel's inline-asm SEAM: src/inle/<a>/asmops.h says every privileged instruction
# once, in GNU's template, and mooncc reads it through holo/gas.l -- so the gate compiles one
# probe with mooncc and clang and compares op by op. Skips without llvm-objdump.
test_asmops: host
	@sh test/gate/asmops.sh $(ho)
# test_dtb -- src/inle/dtb.h, the walk both device-tree doors ride (a64_dtb.c and
# rv64_dtb.c, each one two constants and this include), on trees the gate builds
# rather than a machine hands over. A boot reaches exactly ONE tree, virt's; these reach
# the other cell width, a nested reg that is not memory, two banks either way a tree says
# it, both clamps, a cmdline past the buffer and a torn magic. Host cc, no love, no qemu.
test_dtb:
	@echo TEST test/gate/dtb.c
	@$(CC) -I$R/src -I$R -o $(ho)/.dtbgate $R/test/gate/dtb.c
	@$(ho)/.dtbgate
# test_rvboot -- THE RISCV BRING-UP ON A HART: mkboot.l's sv39 lane and src/inle/rv64/dtb.c
# under qemu -M virt, entered the way the kernel will be (OpenSBI, S-mode, a1 the tree).
# Three objects and nothing else -- the stub, the door, and test/gate/rvboot.c standing in
# for kmain -- bound by ldkern, the kernel linker's own door, since mooncc's driver enters
# through its crt0 and a machine enters at the load address. Nine laws, exit 42.
rvboot_o = $(ko)/rv64/rv64/boot.o $(ko)/rv64/src/inle/rv64/dtb.o $(ko)/rv64/rvboot.o
$(ko)/rv64/rvboot.o: test/gate/rvboot.c $(love_h) $(R)/src/inle/k.h $(R)/src/inle/dtb.h $(mooncc_dep)
	@echo 'MOON	'$@
	@mkdir -p "$(dir $@)"
	@$(mooncc) -I$(ko)/rv64 -I. -Isrc/core -Isrc/host -Isrc/inle -I$(ho) -Iout/lib -I$R -I$R/src/apps/moon/include \
	  -t rv64 -c $< -o $@
$(ko)/rv64/rvboot.elf: $(rvboot_o) test/gate/rvboot.l $m
	@echo 'RVLINK	'$@
	@LOVE_NO_IMAGE= $m test/gate/rvboot.l $(rvboot_o) $@
test_rvboot:
	@$(MAKE) -s a=rv64 $(ko)/rv64/rv64/boot.o $(ko)/rv64/src/inle/rv64/dtb.o
	@$(MAKE) -s $(ko)/rv64/rvboot.elf
	@sh test/gate/boot.sh rvboot "$(MAKE)"
# test_vec -- the INTERRUPT gate: raises a real CPU exception with (fault n) and reads the
# report, the only way to reach src/inle/mkvec.l's 32 stubs and the fault vector, then
# checks the stubs no boot can reach against the architecture's own error-code list.
# ⚠ WHICH vec.o: at the HOST arch there is no $(k_pie) build -- the elf is projected out of
# the shipped love, which already carries the kart lane's objects -- so $(k_o) never runs and
# the only vec.o laid for this machine is $(moon_d)/kvec.o. same mkvec.l, same arch, same lay.
# a cross arch builds the pie and lays its own under $(ko). two ifeqs, never an else-ifeq.
kvec_x64  = $(ko)/x64/x64/vec.o
kvec_a64 = $(ko)/a64/a64/vec.o
kvec_rv64 = $(ko)/rv64/rv64/vec.o
ifeq ($(hosta),x64)
kvec_x64  = $(moon_d)/kvec.o
endif
ifeq ($(hosta),a64)
kvec_a64 = $(moon_d)/kvec.o
endif
test_vec: host
	@$(MAKE) -s a=x64 kernel
	@sh test/gate/vec.sh x64 out/love-x64.elf $(kvec_x64)
	@$(MAKE) -s a=a64 kernel
	@sh test/gate/vec.sh a64 out/love-a64.elf $(kvec_a64)
	@$(MAKE) -s a=rv64 kernel
	@sh test/gate/vec.sh rv64 out/love-rv64.elf $(kvec_rv64)
# THE FIXPOINT: the default love IS mooncc-built, so this gate has it rebuild ITSELF --
# love1 (love0's lane, relinked) bakes its own compiler image, recompiles every TU, links
# love2, and the two must be byte-identical. A headline invariant -- but it runs in
# test_extra only, so a deleted src/*.c goes green through test_slow either way.
# $(moon_o) $(kart_o) is the link list, the artifact's own: the gate is handed make's
# objects, it never globs the odir, and it links no less than `make` does.
test_fixpoint: host $(love0) out/mooncc0.image
	@$(MAKE) -s a=$(hosta) $(ko)/$(hosta)/mkvec.l
	@gate_love_c='$(love_tu_c)' gate_host_c='$(host_c)' gate_arch_c='$(hosta_c)' \
	  sh test/gate/fixpoint.sh $(ho) $(love0) $(hosta) $(moon_o) $(kart_o)
# THE CROSS-MACHINE FIXPOINT, in effigy (doc/misc/plan/seed-universal.md U0): the x-lane's
# twin objects link love1, then love1 under qemu-user rebuilds itself natively and must
# answer the same bytes -- the twin machine reproducing this machine's, on one box.
# opt-in BY NAME (a full rebuild under emulation is minutes): `make test_xfixpoint`,
# or `make xa=rv64 test_xfixpoint` for the other twin. skips loudly without qemu.
.PHONY: test_xfixpoint
test_xfixpoint: $(x_o) $(xkart_o) $(love0) out/mooncc0.image
	@gate_love_c='$(love_tu_c)' gate_host_c='$(host_c)' gate_arch_c='$(wildcard $R/src/inle/$(xa)/*.c)' \
	  sh test/gate/xfixpoint.sh $(ho) $(love0) $(xqemu) $(xa) mksys-$(xa) $(tco) $(xd) $(xa) $(x_o) $(xkart_o)
# test_fat -- the fat container (seed-universal U1): the one file answers through
# its prefix + cache on the native machine, the pack is byte-deterministic, and
# the foreign member answers under qemu-user. opt-in by name, like the x-lane.
.PHONY: test_fat
test_fat: dist-fat
	@sh test/gate/fat.sh $(fat) $a $(xa) $(xqemu) "$(love0)" $(ho) $(xd)
# the multi-OS gate (doc/misc/plan/seed-universal.md, rung UV): ONE default-lane
# binary answers every kernel with the same text. the box arrives by env --
# FBSD_SSH / NBSD_SSH = "ssh -p 2222 -i KEY root@HOST" -- and without one the
# gate skips loudly. opt-in by name, like test_distboot; FBSD_SEED=1 /
# NBSD_SEED=1 adds the on-box `love seed` trophy leg (minutes).
.PHONY: test_freebsd test_netbsd test_freebsd_a64 test_netbsd_a64
test_freebsd: host $(love0) out/mooncc0.image
	@sh test/gate/osbox.sh $(ho) $(love0) freebsd
test_netbsd: host $(love0) out/mooncc0.image
	@sh test/gate/osbox.sh $(ho) $(love0) netbsd
# the SECOND ISA: FBSD_ARM64_SSH names an aarch64 freebsd box and the local half
# of each comparison rides qemu-aarch64, so the leg is one binary under two
# kernels on an ISA this machine is not. Skips loudly without either.
test_freebsd_a64: host $(love0) out/mooncc0.image
	@sh test/gate/osbox.sh $(ho) $(love0) freebsd a64
# and its netbsd sibling: NBSD_ARM64_SSH, the same shape. one aarch64 binary
# answers all three kernels -- the door netbsd needs there is the svc IMMEDIATE.
test_netbsd_a64: host $(love0) out/mooncc0.image
	@sh test/gate/osbox.sh $(ho) $(love0) netbsd a64
# test_raw_bake -- the mooncc-PIE binary bakes its own image and wakes it. The procedure
# (and the why) lives in test/gate/raw-bake.sh; make keeps the dependency and the file list,
# the WHOLE corpus. Opt-in: needs the -pie toolchain, x86-64 only.
test_raw_bake: test_raw
	@sh test/gate/raw-bake.sh $(ho) $t
# test_rv64 -- the test/cc battery `mooncc -t rv64` under qemu-riscv64, exit code
# against the native x64 build. OUT of test_slow: test_ccrv64 runs the same battery and
# compares STDOUT, so this is its strict subset -- the lighter opt-in lane.
test_rv64: host
	@sh test/gate/rv64.sh $(ho) $m
# test_raw's rv64 twin: mooncc -t rv64 lays every object, mksys-rv64 the syscall
# leaf, OUR linker binds, qemu-riscv64 runs the whole corpus over the fresh egg. The riscv
# backend loads into the sealed holo module at runtime for mksys. Opt-in; skips w/o qemu.
test_raw_rv64: host
	@gate_love_c='$(love_tu_c)' gate_host_c='$(host_c)' gate_arch_c='$(hosta_c)' \
	  sh test/gate/raw.sh rv64 $(ho) $m $t
# test_raw's a64 twin: mooncc -t a64 lays every object, mksys-a64 the syscall leaf,
# OUR linker binds, qemu-user runs the WHOLE C-sorted $t over the fresh egg. ⚠ $t must stay
# in C/byte order: test/uu.l defines the kernel test/uukindlaw.l calls. Opt-in; needs qemu.
# test/a64/callout.l rides past $t: it builds 'a64 nifs and RUNS them, so only an a64
# love may read it -- gate_sentinel is how the gate knows it was read and not stopped short.
test_raw_a64: host
	@gate_love_c='$(love_tu_c)' gate_host_c='$(host_c)' gate_arch_c='$(hosta_c)' \
	  gate_sentinel='test/a64/callout:.* ok' \
	  sh test/gate/raw.sh a64 $(ho) $m $t test/a64/callout.l
# test_thumb1 -- the ELF32/EM_ARM object writer (src/core/holo/obj.l objsecs32) end to end and the
# 32-bit data model: a cross-object BL, the inline v6-M soft divide/rem, a global via the
# literal-pool `la`, a gcc-built pointer-bearing struct mooncc reads a field back from, and a
# NAMED SECTION holding a function-pointer table -- the vector-table shape, thumb bit and all.
# Then the other direction: test/gate/ld32.l reads an object back through link.l's ld-read,
# the only exercise the 32-bit rows of its field table get.
test_thumb1: host
	@sh test/gate/thumb.sh thumb1 $(ho)
# test_thumb2 -- the thumb1 gate's ARMv7E-M twin, ON THE DEVICE CPU (qemu mps2-an500 is a
# Cortex-M7, the Teensy 4.1 / Playdate silicon). the featured lane is `la`, thumb2's
# MOVW/MOVT pair: every binding shape rides once -- global fn, static fn, literal, var.
test_thumb2: host
	@sh test/gate/thumb.sh thumb2 $(ho)
# test_virt -- LOVE ITSELF on the bare rv64 hart: the whole runtime compiled end to end
# by mooncc -t rv64 (src/port/virt/), start.o laid from holo IR, OUR linker binds -- no
# foreign toolchain ANYWHERE. Bakes the egg, asserts, exits 42; 98 = a machine trap.
test_virt: host
	@sh test/gate/boot.sh virt "$(MAKE)"
# test_mps2 -- LOVE ITSELF on the M7: the whole runtime by mooncc -t thumb2 (src/port/mps2/),
# start.o laid from holo IR, ldbare32 binding one RWX segment at 0 -- no foreign toolchain
# ANYWHERE, the second port after virt to reach that. On qemu's Cortex-M7 it bakes the egg
# FROM SOURCE and asserts spec laws over the hatched image; exits 42, and 98 = fault.
test_mps2: host
	@sh test/gate/boot.sh mps2 "$(MAKE)"
# test_mps2_t1 -- LOVE ON THE RP2040'S ISA: the same port by mooncc -t thumb1 (ARMv6-M,
# ai_tco=0's trampoline, soft floats through libgcc's v6-m __aeabi set). v6-M is a strict
# subset of ARMv7E-M, so qemu's M7 runs it natively; exit 42 = hatched + laws held. Our linker
# binds this one too -- libgcc.a is named on the line and its members pulled by need through
# the ranlib index, so the .a is a LIBRARY the link READS, not a tool it runs.
test_mps2_t1: host
	@sh test/gate/boot.sh mps2_t1 "$(MAKE)"
# test_mps2_wake -- the IMAGE lane: the baker bakes the corpus on qemu's M7 and dumps a
# fully-symbolic heap image; the WAKER -- a different binary, arena deliberately offset --
# wakes it and re-runs the driver laws. The teensy's build rides the same love.img.
test_mps2_wake: host
	@sh test/gate/boot.sh mps2_wake "$(MAKE)"
# test_thumb2sp -- the SP-only-FPU face (the playdate's STM32F746): f64 arithmetic SOFTENS
# to __aeabi_* libgcc calls while the 64-bit transfers keep the d-reg value model. Gated on
# qemu's mps2-an386, whose FPv4-SP FPU FAULTS on any f64 arithmetic that slipped through.
test_thumb2sp: host
	@sh test/gate/thumb.sh thumb2sp $(ho)
# test_playdate -- the playdate build gate: the device half compiled by mooncc -t thumb2sp
# behind pdglue's word-only SDK seam, the pdx built by pdc. Verifies the DEVICE elf: no UND,
# eventHandler exported, ZERO movw/movt relocs -- the loader relocates ABS32 words only.
test_playdate: host
	@echo TEST out/playdate/love.pdx
	@if [ -z "$$PLAYDATE_SDK_PATH" ] || ! command -v arm-none-eabi-gcc >/dev/null 2>&1; then \
	   echo "test_playdate: no PLAYDATE_SDK_PATH / arm-none-eabi toolchain, skipped"; exit 0; fi; \
	  $(MAKE) -C src/port/playdate || { echo "FAIL playdate build"; exit 1; }; \
	  u=`llvm-readelf -s out/playdate/pdex.elf | grep -c "UND [a-zA-Z_]"`; \
	  [ "$$u" -eq 0 ] || { echo "FAIL pdex.elf has $$u undefined symbols"; exit 1; }; \
	  llvm-readelf -s out/playdate/pdex.elf | grep -qw eventHandler || { echo "FAIL no eventHandler"; exit 1; }; \
	  m=`llvm-readelf -r out/playdate/pdex.elf | grep -c "MOVW\|MOVT"`; \
	  [ "$$m" -eq 0 ] || { echo "FAIL $$m movw/movt relocs (the loader can't relocate them)"; exit 1; }; \
	  echo "test_playdate: love.pdx (device half all-mooncc -t thumb2sp, soft f64) -- resolved, word-relocs only"
# test_teensy41 -- the REAL-METAL build gate, and the one port asking for NO foreign tool at
# all: mooncc -t thumb2 compiles, tlink.l binds (no ld, no linker script -- the XIP flash map
# is the map in that file), mkimg.l wraps the baked heap image, ocopy.l writes the .hex/.bin,
# and the ROM-facing boot image is VERIFIED out of that .bin (FCFB tag at flash 0, IVT at
# 0x1000, thumb-bit entry). So this one never skips; test_mps2 is the runtime (no RT1062 qemu).
test_teensy41: host
	@echo TEST out/teensy41/love.hex
	@$(MAKE) -C src/port/teensy41 || { echo "FAIL teensy41 build (the boot-image verify is inside)"; exit 1; }
	@echo "test_teensy41: love (all-mooncc thumb2), OUR linker, flatten and boot image -- nothing foreign"
# test_nucleo446 -- the Nucleo-F446RE firmware BUILD gate: mooncc -t thumb2sp compiles,
# nlink.l binds (no ld, no linker script -- the F4's memory map is the map in that file),
# ocopy.l flattens, and the boot image is VERIFIED (initial SP inside SRAM, thumb-bit reset
# entry inside flash). arm-none-eabi-gcc is still asked where its cortex-m4 hard-float
# libgcc.a lives, but the .a is READ as an archive, by need, not run. The 128 KB SRAM never
# held love: this port is the TOOLCHAIN on silicon, its arithmetic gated by test_thumb2sp
# and its boot by test_nucleo446_smoke below.
test_nucleo446: host
	@echo TEST out/nucleo446/firm.hex
	@if ! command -v arm-none-eabi-gcc >/dev/null 2>&1; then \
	   echo "test_nucleo446: no arm-none-eabi toolchain, skipped"; exit 0; fi; \
	  $(MAKE) -C src/port/nucleo446 || { echo "FAIL nucleo446 build (the boot-image verify is inside)"; exit 1; }; \
	  echo "test_nucleo446: firmware (all-mooncc thumb2sp), OUR linker and flatten, no linker script, boot image verified"
# test_nucleo446_smoke -- the same port RUN, not read: the -D QSMOKE twin on qemu's Cortex-M4,
# its exit code the self-check tally carried out through mkboot.l's sh_exit. The only lane that
# executes crt0, the semihosting block and the fault vectors. ~0.7s.
# ⚠ qemu only -- on silicon a bkpt with no debugger escalates to lockup.
test_nucleo446_smoke: host
	@sh test/gate/boot.sh nucleo446_smoke "$(MAKE)"
# test_rp2040 -- the Pico firmware BUILD gate, nucleo446-shaped, and the one port with NO .S:
# vector table and crt0 are C, and boot2 -- the 256-byte stage the mask ROM checksums before
# it runs anything -- is laid straight into a named section by mkboot2.l. So the boot image
# verify has THREE words, not two: boot2's CRC-32/MPEG-2 must be 0x7a4eb274, the SP inside the
# 264 KB SRAM, the reset entry thumb-bit and inside flash. rlink.l binds, ocopy.l flattens; the
# skip asks after the last foreign thing here, gcc's cortex-m0 libgcc, READ as an archive.
# qemu has no RP2040 machine, so this builds and never boots -- test_thumb1 gates the ISA.
test_rp2040: host
	@echo TEST out/rp2040/love.bin
	@if ! command -v arm-none-eabi-gcc >/dev/null 2>&1; then \
	   echo "test_rp2040: no arm-none-eabi toolchain, skipped"; exit 0; fi; \
	  $(MAKE) -C src/port/rp2040 || { echo "FAIL rp2040 build (the boot-image verify is inside)"; exit 1; }; \
	  echo "test_rp2040: firmware (all-mooncc thumb1, boot2 laid by holo, no .S), OUR linker and flatten, flash R|X, boot surface verified"
# the userland packages: each built by mooncc + nolibc + the holo
# linker -- no gcc/glibc/ld anywhere -- then RUN and held to the package's own answers:
# tar 1.13 cf/xf + czf/xzf roundtrips and system-tar interop, m4 1.4's own 57-check suite,
# lua 5.4's interpreter battery, sqlite's amalgamation + VFS battery. Opt-in: point the
# package's SRC var at a prepared tree (./configure'd for tar/m4, extracted for lua/sqlite)
# and each script SKIPS cleanly without one. A cross lane puts a qemu wrapper on PATH, so a
# suite that execs the binary by name runs unmodified; riscv routes around faults the other
# two share (nhome = 0, so nothing rides), which is why it is not redundant.
# /warn the sqlite cross lanes wait on moon-sqlite: they read its x86-64 answers as the oracle.
moon_arch_a64 = a64
moon_arch_rv64 = rv64
# $1 package, $2 its source-tree var, $3 what the two CROSS lanes wait on
define moon_pkg
moon-$1: host
moon-$1-a64 moon-$1-rv64: $3
moon-$1 moon-$1-a64 moon-$1-rv64:
	@$2="$$($2)" ./tools/moon-$1.sh $$(moon_arch_$$(patsubst moon-$1-%,%,$$@))
endef
$(eval $(call moon_pkg,tar,TARSRC,host))
$(eval $(call moon_pkg,m4,M4SRC,host))
$(eval $(call moon_pkg,lua,LUASRC,host))
$(eval $(call moon_pkg,sqlite,SQLSRC,moon-sqlite))
$(eval $(call moon_pkg,gzip,GZIPSRC,host))
$(eval $(call moon_pkg,bzip2,BZIP2SRC,host))
# test_distboot -- THE RELEASE CLAIM: take either artifact, type make, get the same
# binary. SOURCE bootstraps through the machine's own cc; SEED lays the source it carries
# in .rodata and builds it with cc/gcc/clang shadowed by scripts that fail loudly -- so
# "no ambient compiler did the work" is proved, not assumed. Then the circle: `love seed`
# with nothing on PATH that compiles, which is where its FALLBACK is exercised -- it takes
# its own mooncc and rebuilds ITSELF byte for byte. Minutes, opt-in, by name -- and the
# reason the claim can hold at all is that the local cc builds love0 and nothing else
# (see the script).
# ⚠ IT DOES NOT SUBSUME test_seed, and must not be read as doing so: no leg here runs a
# DEFAULT `love seed`, so nothing here tests the seed choosing to defer to a working
# ambient cc. Both lanes are covered; only one of the two DECISIONS is. Three full builds
# against test_seed's one, and still not a superset.
# test_bakerep -- A BAKE IS A FUNCTION OF THE TREE. Seconds, and it rides the slow gate
# because test_distboot proves the same law over the whole circle but is opt-in and
# minutes long; a regression would otherwise wait for a release to surface.
test_bakerep: host
	@echo TEST test/gate/bakerep.sh
	@sh test/gate/bakerep.sh $(ho)
test_distboot: dist
	@echo TEST test/gate/distboot.sh
	@sh test/gate/distboot.sh $(dist_source) $(ho)/love
# test_gz -- src/apps/tar/tar.l + src/apps/gz/gz.l against the two programs they replace. The LAWS are
# test/host/gz.l (in test_hostnif, needing nothing outside the tree); this is the half
# only the outside world can say, and it is a separate gate because a coder and a
# decoder written by one hand round-trip cleanly through a format nobody else speaks.
# Skips where either system tool is missing. gzfind.l rides along and needs NOTHING
# outside: it is the differential between gz.l's match finder and the holo IR beside it
# that says the same thing to a cpu, over corpora chosen for the chain the kernel walks.
test_gz: host
	@echo TEST test/gate/gzfind.l
	@$m $R/test/gate/gzfind.l
	@echo TEST test/gate/targz.sh
	@sh test/gate/targz.sh $(ho)/love
# test_root -- the privileged verbs: chroot, mount, umount, sync, mkfifo, mknod. Two
# halves, and the second is the one that means something: the refusals as an ordinary
# user, then test/gate/rootns.l, which makes itself root in an unprivileged USER
# NAMESPACE and does the real thing -- a tmpfs mounted, a bind that shows the other
# tree, both unmounted, and a chroot with a command running inside the new root. A
# gate that only watched these answer 'eperm would pass against a stub.
# ⚠ a kernel with unprivileged user namespaces off skips the second half with a word
# and stays green: that is a machine's policy, not a fault in the code.
test_root: host
	@echo TEST test/gate/root.sh
	@sh test/gate/root.sh $(ho) $(ho)/love
# test_fat32 -- `love fat` + `love mkfs.vfat`, the command line over src/apps/fat/fat.l.
# ⚠ NOT test_fat, which gates the fat CONTAINER (seed-universal U1) and shares only a
# word. test/host/fat.l proves the filesystem's own laws over a cask, needing nothing
# outside; this is the half only another implementation can say, and mtools is it --
# their reader on our format, our reader on theirs, and our reader on an mformat image.
# Skips the interop half where mtools is missing; the verbs still run.
test_fat32: host
	@echo TEST test/gate/fat32.sh
	@sh test/gate/fat32.sh $(ho) $(ho)/love
# test_cpio -- src/apps/cpio/cpio.l + its face against GNU cpio, both ways over newc. Separate
# from test_gz for the same reason test_gz is separate from the laws: the system tool
# is the only oracle that can catch a format two of our own functions agree on. This
# is the wire `make distro-initramfs` cuts its image with.
test_cpio: host
	@echo TEST test/gate/cpio.sh
	@sh test/gate/cpio.sh $(ho)/love
# The neutral assembler (src/core/holo/) + its x86-64 backend: every encoder golden is
# objdump-checked (test/holo/golden.l). A host-only app -- it adds no nif and is NOT
# baked into love0. The sources are cat'd in because the host bakes its NATIVE backend
# only; the other four reach the gate no other way. Gate = exit 0 AND the "N passed,
# 0 failed" sentinel.
test_holo: host
	@echo TEST test/holo/golden.l
	@cat src/core/holo/holo.l src/core/holo/x64.l src/core/holo/a64.l src/core/holo/thumb2.l \
	    src/core/holo/rv64.l src/core/holo/thumb1.l src/core/holo/text.l src/core/holo/gas.l src/core/holo/elf.l \
	    test/holo/golden.l | sh test/gate/run.sh holo "$m" ", 0 failed"
# as.l -- the real AT&T x86-64 front over holo. test/holo/as.l's goldens are byte-identical
# to /usr/bin/as (frozen, no shell-out at gate time). Same sentinel gate as test_holo.
# asrefuse.sh is the other half: what must RAISE, one love per case.
test_as: host
	@echo TEST test/holo/as.l
	@cat src/core/holo/holo.l src/core/holo/x64.l src/core/holo/as.l test/holo/as.l \
	  | sh test/gate/run.sh as "$m" ", 0 failed"
	@sh test/gate/asrefuse.sh "$m"
# test_elf32 -- holo's ELF32 executable writer, judged by a real loader: both thumb backends
# lay write+exit, Linux maps the segment and enters in Thumb state, and 42 must come back.
# test/holo/golden.l pins the header fields; this pins the only opinion that counts. Needs qemu-arm
# and NOTHING else -- no as, no ld, no arm-none-eabi -- so it runs where the thumb gates skip.
test_elf32: host
	@sh test/gate/elf32.sh $(ho)
# test_objcopy -- src/core/holo/copy.l, the flatten, against the objcopy it replaces: a BYTE
# comparison of both output formats over fixtures our own linker mints plus every ELF on
# hand. Intel HEX is a wire (a Teensy loader reads it), so nothing softer would do. The
# gate skips where no objcopy exists -- see the script for what the fixtures are for.
test_objcopy: host
	@sh test/gate/objcopy.sh $(ho)
# ain's two-process loopback gate: a server and a client over real TCP on 127.0.0.1,
# full-duplex, each asserting it got what the other sent. The ONLY net gate driving the real
# `love src/apps/ain/ain.l` cli path. In test_slow; override the port with `make nettest PORT=N`.
PORT ?= 7390
nettest: host
	@echo TEST $m "(127.0.0.1:$(PORT))"
	@sh $R/test/net/loopback.sh $m $(PORT)
# The tool gates beside the build: the hue generators, cook, tele. See tools/Makefile.
# vmret is NOT here -- it rides test_slow over $m, and after plan C2 every other love in
# the tree is a projection of that one. ⚠ lush is a real
# prerequisite: test/host/cook.l's SHELL pair sets `SHELL := out/lush` to prove cook honors it.
test_tools: host out$(hsuf)/lush
	@$(MAKE) -C tools
# test_gcheck: the copy loop's FIXPOINT instance check. AiGcCheck makes gen_minor re-drive
# its WHOLE scan after the drain and trap if the second pass copies a word, in its own tree.
# /warn the knob is GCDBG: EXTRA_CFLAGS rides $(ai_cflags), which the mooncc recipes do not use.
# â  the shared unsuffixed prerequisites are named HERE so the PARENT makes them once.
# both debug lanes recurse, and a target two sub-makes each decide to remake is a partial
# file to whoever reads it meanwhile -- a half-written mooncc0.image wakes with no verb
# table and `mooncc` then reads as a filename (the Makefile). test_fixpoint names them
# for the same reason.
test_gcheck: host $(love0) out/mooncc0.image
	@$(MAKE) --no-print-directory hsuf=/gck GCDBG=-DAiGcCheck test_host
	@$(MAKE) --no-print-directory hsuf=/gck GCDBG=-DAiGcCheck test_hostegg
# test_gcstress: the MUTATOR's side -- whether the C around the collector holds a raw pointer
# across a call that collects. AiGcStress always collects, poisons the vacated nursery, and
# majors every 32nd. ~12 min, own tree -- the baked leg tracks the glaze, since every major
# walks it, and costs 3.4x the egg one for it (429 s against 126 s).
test_gcstress: host $(love0) out/mooncc0.image
	@$(MAKE) --no-print-directory hsuf=/gcs GCDBG=-DAiGcStress test_host
	@$(MAKE) --no-print-directory hsuf=/gcs GCDBG=-DAiGcStress test_hostegg
# --- the machine-checked half: test/proof/rocq/ + test/proof/lean/ ---------------------------------
# Each gate below is a no-op that SAYS SO when its checker is missing, so a bare box stays
# green. The tool guards are grouped by what they need, not by gate.
COQC     ?= $(shell command -v coqc 2>/dev/null)
OCAMLOPT ?= $(shell command -v ocamlopt 2>/dev/null)
LEAN     ?= $(shell command -v lean 2>/dev/null)
# the scratch coqc strews beside a .v, and what an extracted ocaml ref leaves
vclean = rm -f $(foreach n,$1,test/proof/rocq/$n.vo test/proof/rocq/$n.vok test/proof/rocq/$n.vos test/proof/rocq/$n.glob test/proof/rocq/.$n.aux)
dclean = rm -f $(foreach n,$1,test/proof/rocq/$n_ref.ml test/proof/rocq/$n_ref.mli test/proof/rocq/$n_drive)

ifeq ($(COQC),)
test_proof test_gc test_gen test_uugen test_mx:
	@echo "$@: skipped (needs rocq/coqc)"
else
# spec.v -- love's headline laws (the numeral / function / absence core of test/spec.l) as Rocq
# theorems, axiom-free and universe-checked: the executable spec upgraded from SHOWN to PROVED.
# spec.vo is a FILE target, compiled once and KEPT: test_gen and test_extract both `Require
# Import spec`. /warn one spelling everywhere (`cd test/proof/rocq && -R . ""`), or spec.vo's logical
# name is not the one gen.v asks for. A static pattern: big/mx/enc take their own flags.
rocq_kept = test/proof/rocq/spec.vo test/proof/rocq/patch.vo
$(rocq_kept): test/proof/rocq/%.vo: test/proof/rocq/%.v
	@echo TEST test/proof/rocq/$*.v "(coqc)"
	@cd test/proof/rocq && $(COQC) -q -R . "" $*.v
test_proof: $(rocq_kept)
	@echo "test_proof: spec.v + patch.v check (the .vo IS the evidence, so a re-run is quiet)"
# gc.v -- the generational MINOR is SOUND (under a complete write barrier no live young is
# lost), its PAUSE is bounded by the nursery, and the Cheney drain terminates as a true
# fixpoint. Axiom-free; test_gcheck instance-checks the drain.
test_gc:
	@echo TEST test/proof/rocq/gc.v "(coqc)"
	@$(COQC) -q test/proof/rocq/gc.v
	@$(call vclean,gc)
# The .l -> .v pipeline: tools/spec2coq.l reads test/spec.l and EMITS gen.v, the spec generating
# theorems for its own numeral facts. Regenerated every run, so asserts and proofs cannot diverge.
test_gen: host $(rocq_kept)
	@echo 'LOVE	'test/proof/rocq/gen.v "(tools/spec2coq.l on $m)"
	@$m tools/spec2coq.l > test/proof/rocq/gen.v
	@echo TEST test/proof/rocq/gen.v "(coqc, against spec.v's shared model)"
	@cd test/proof/rocq && $(COQC) -R . "" gen.v
	@$(call vclean,gen)
# The PROOF half of that pipeline (cf. test_gen, which exports concrete ASSERTS): tools/uu2coq.l
# has uu's kernel TYPE-CHECK a proof term and emits the same term in Gallina for coqc to re-check
# -- a law proved in love's own kernel and certified by Rocq.
test_uugen: host
	@echo 'LOVE	'test/proof/rocq/uugen.v "(tools/uu2coq.l on $m)"
	@$m tools/uu2coq.l > test/proof/rocq/uugen.v
	@echo TEST test/proof/rocq/uugen.v "(coqc)"
	@$(COQC) -q test/proof/rocq/uugen.v
	@$(call vclean,uugen)
# src/core/mx.l IS the +/* dispatch matrices; src/core/mx.h is laid from it through clay and tools/mx2coq.l models
# it in Rocq -- two derivations of ONE datum.
test_mx: host
	@echo TEST test/proof/rocq/mx.v "(the dispatch matrices: band factorization + dispatch commutativity, coqc)"
	@cat src/core/mx.l tools/mx2coq.l | $m > test/proof/rocq/mx.v
	@cd test/proof/rocq && $(COQC) -q mx.v >/dev/null
	@$(call vclean,mx)
endif

ifeq ($(and $(COQC),$(OCAMLOPT)),)
test_extract test_big test_encver:
	@echo "$@: skipped (needs coqc + ocamlopt)"
else
# extract.v's normalizer (on spec.v's PROVEN subst/shift) extracted to OCaml and fuzzed against
# ev. /warn RUN THE ORACLE ONCE, into a file (2>&1 too): grep it, then cat it -- a second run
# to display doubles the work.
test_extract: host $(rocq_kept)
	@echo TEST test/proof/rocq/extract.v "(coqc extraction -> ocaml ref vs ev)"
	@cd test/proof/rocq && $(COQC) -R . "" extract.v >/dev/null \
	  && rm -f normalizer.mli && $(OCAMLOPT) -w -a normalizer.ml oracle_drive.ml -o oracle_drive
	@test/proof/rocq/oracle_drive 2000 6 1 > out/.extract_oracle.l
	@$m out/.extract_oracle.l > out/.extract_oracle.out 2>&1; r=$$?; \
	  { [ $$r -eq 0 ] && grep -q "2000 / 2000 PASS" out/.extract_oracle.out; } \
	    || { echo "FAIL the extract oracle (exit $$r):"; cat out/.extract_oracle.out; exit 1; }
	@cat out/.extract_oracle.out
	@$(call vclean,extract)
	@rm -f test/proof/rocq/normalizer.ml test/proof/rocq/normalizer.mli test/proof/rocq/oracle_drive \
	  test/proof/rocq/*.cmi test/proof/rocq/*.cmx test/proof/rocq/*.o out/.extract_oracle.l out/.extract_oracle.out
# big.v proves the decimal codec roundtrip and the quot-rem/gcd witnesses, then extracts stdlib's
# binary Z with the codec; big_drive.ml emits decimal comparisons -- love's READER, limbs and
# PRINTER against it.
test_big: host
	@echo TEST test/proof/rocq/big.v "(coqc codec proof + extracted Z ref vs the limb lane)"
	@cd test/proof/rocq && $(COQC) -q big.v >/dev/null \
	  && rm -f bigref.mli && $(OCAMLOPT) -w -a bigref.ml big_drive.ml -o big_drive
	@test/proof/rocq/big_drive 2000 1 > out/.big_oracle.l
	@$m out/.big_oracle.l > out/.big_oracle.out 2>&1; r=$$?; \
	  { [ $$r -eq 0 ] && grep -q "2000 / 2000 PASS" out/.big_oracle.out; } \
	    || { echo "FAIL the big oracle (exit $$r):"; cat out/.big_oracle.out; exit 1; }
	@cat out/.big_oracle.out
	@$(call vclean,big)
	@rm -f test/proof/rocq/bigref.ml test/proof/rocq/bigref.mli test/proof/rocq/big_drive \
	  test/proof/rocq/*.cmi test/proof/rocq/*.cmx test/proof/rocq/*.o out/.big_oracle.l out/.big_oracle.out
# the PROVE rung of the holo encoder ladder: reference x86-64 encoders each proving decode
# inverts encode, extracted to OCaml and checked BYTE-IDENTICAL against holo -- an oracle, not a
# disassembler. enc.v is reg-direct, encmem.v ModRM/SIB, encli.v `li`'s form choice.
encver = enc:1792:reg-direct encmem:6144:memory encli:320:immediate
test_encver: host
	@echo TEST test/proof/rocq/enc.v test/proof/rocq/encmem.v test/proof/rocq/encli.v "(coqc round-trip proofs -> ocaml refs vs holo, byte-exact)"
	@cd test/proof/rocq && $(COQC) -q enc.v >/dev/null && $(COQC) -q encmem.v >/dev/null && $(COQC) -q encli.v >/dev/null \
	  && rm -f enc_ref.mli encmem_ref.mli encli_ref.mli \
	  && $(OCAMLOPT) -w -a enc_ref.ml enc_drive.ml -o enc_drive >/dev/null \
	  && $(OCAMLOPT) -w -a encmem_ref.ml encmem_drive.ml -o encmem_drive >/dev/null \
	  && $(OCAMLOPT) -w -a encli_ref.ml encli_drive.ml -o encli_drive >/dev/null
	@for s in $(encver); do n=$${s%%:*}; r=$${s#*:}; c=$${r%%:*}; l=$${r#*:}; \
	   o=out/.$${n}_oracle; \
	   test/proof/rocq/$${n}_drive > $$o.l; \
	   { cat src/core/holo/holo.l src/core/holo/x64.l; echo "(use 'holo)"; cat $$o.l; } | $m > $$o.out 2>&1; r=$$?; \
	   { [ $$r -eq 0 ] && grep -q "$$c / $$c PASS" $$o.out; } \
	     || { echo "FAIL the $$n oracle, $$l (exit $$r):"; cat $$o.out; exit 1; }; \
	   cat $$o.out; done
	@$(call vclean,enc encmem encli)
	@$(call dclean,enc encmem encli)
	@rm -f test/proof/rocq/*.cmi test/proof/rocq/*.cmx test/proof/rocq/*.o out/.enc_oracle.* out/.encmem_oracle.* out/.encli_oracle.*
endif

# the LEAN leg of the proof bridge (cf. test_uugen, the Rocq leg): tools/uu2lean.l emits the SAME
# uu corpus to Lean 4, which re-checks it -- a SECOND independent kernel, so each law is agreed
# by two unrelated implementations. Regenerated every run.
ifeq ($(LEAN),)
test_uulean:
	@echo "test_uulean: skipped (needs lean)"
else
test_uulean: host
	@mkdir -p test/proof/lean
	@echo 'LOVE	'test/proof/lean/uugen.lean "(tools/uu2lean.l on $m)"
	@$m tools/uu2lean.l > test/proof/lean/uugen.lean
	@echo TEST test/proof/lean/uugen.lean "(lean)"
	@$(LEAN) test/proof/lean/uugen.lean > out/.uulean.out 2>&1; r=$$?; \
	  if [ $$r -ne 0 ] || grep -q sorryAx out/.uulean.out; then cat out/.uulean.out; exit 1; fi
endif

# the fuzz-first rung of the holo encoder ladder (test/holo/fuzz/): random IR forms encoded
# via holo (in-process), disassembled (objdump for x64, cross-read by llvm-mc; llvm-mc
# elsewhere), decode checked against intent. fuzz.l skips a lane whose disassembler is
# absent and exits 1 on any decode disagreement. sysdiff.l rides the same lane for the
# SYSTEM ops, byte-exact off holo's own a64.l tables, and rvc.l sweeps the riscv C
# squeeze by EQUIVALENCE -- every compressed word against the 32-bit word it replaced.
test_holofuzz: host
	@echo TEST test/holo/fuzz/fuzz.l "(holo x64+a64+riscv encoder differential fuzz)"
	@FUZZ_N=8 FUZZ_SEED=20250717 $m test/holo/fuzz/fuzz.l \
	  || { echo "FAIL holofuzz -- a holo encoding disagrees with its disassembler"; exit 1; }
	@if command -v llvm-mc >/dev/null 2>&1; then \
	   $m test/holo/fuzz/sysdiff.l \
	     || { echo "FAIL sysdiff -- a holo SYSTEM encoding disagrees with llvm-mc"; exit 1; }; \
	 else echo "  (sysdiff skipped: no llvm-mc)"; fi
	@$m test/holo/fuzz/rvc.l \
	  || { echo "FAIL rvc -- an RVC squeeze changes what the word means"; exit 1; }
# THE COMMITTED GENERATED CORPORA, one shape four times over: a design's own code
# compiled into uu terms, so the matching *law.l proves its theorems OF THE
# IMPLEMENTATION at corpus time and not of a transcription somebody keeps by hand.
# `make <stem>` refreshes one; test_<stem> regenerates into scratch and diffs, so a
# source that moved reddens here instead of going quiet.
# $1 the corpus stem, $2 its generator under tools/, $3 the source that generator reads
define uu_corpus
$1: host
	@echo 'LOVE	'test/$1.l "(tools/$2.l on $$m)"
	@$$m tools/$2.l > test/$1.l
test_$1: host
	@echo TEST test/$1.l "(regenerate + diff)"
	@$$m tools/$2.l > out/.$1.l.tmp
	@cmp -s out/.$1.l.tmp test/$1.l \
	  || { echo "FAIL: test/$1.l is stale ($3 moved?) -- run: make $1"; exit 1; }
	@rm -f out/.$1.l.tmp
endef
# what each row proves, the only part that differs:
#   uuwm      lux's zipper ops                        -> test/uuwmlaw.l, its theorems
#   uukind    the abstract kinds-lattice JOIN         -> test/uukindlaw.l, the semilattice laws
#   uuhomgen  dest.l's two code generators, on its law sites -> test/uuhomlaw.l, the destination-die laws
#   uusplgen  spl.l's three call-site compilers (call, binding splice, substitution
#             splice) on its samples                  -> test/uuspllaw.l, the SPLICE LICENSE
#   uumx      love.c's +/* DISPATCH MATRICES (src/core/mx.l) -> test/uumxlaw.l, the band lattice
#   uuvallaw  CLAUDE.md's LAWS off test/law.l's own rows -> proved where they stand, one
#             spelling for the fuzz lane and the proof lane both
$(eval $(call uu_corpus,uuwm,uuwmgen,src/apps/lux/core.l))
$(eval $(call uu_corpus,uukind,kinds2uu,doc/misc/proto/kinds.l))
$(eval $(call uu_corpus,uuhomgen,dest2uu,doc/misc/proto/dest.l))
$(eval $(call uu_corpus,uusplgen,spl2uu,doc/misc/proto/spl.l))
$(eval $(call uu_corpus,uumx,mx2uu,src/core/mx.l))
$(eval $(call uu_corpus,uuvallaw,law2uu,test/law.l))
# test_wake: the BAKE-THEN-WAKE ROUND TRIP, which no other gate runs -- every other lane
# wakes an image some earlier recipe baked. A CANDIDATE COPY bakes (love.wake, ETXTBSY-proof)
# under a timeout the wake storm cannot meet (fresh lane ~1s, storm >90s; doc/wake-storm.md).
test_wake: $(ho)/love
	@echo TEST wake "(the woken-image lane, doc/wake-storm.md)"
	@cp $(ho)/love $(ho)/love.wake && $(ho)/love.wake bake
	@cat test/00-init.l test/uu.l > $(ho)/wake-corpus.l
	@if timeout 60 $(ho)/love.wake $(ho)/wake-corpus.l > /dev/null 2>&1; \
	  then echo "test_wake: green (the woken image checks uu at speed)"; rm -f $(ho)/love.wake $(ho)/wake-corpus.l; \
	  else echo "test_wake: FAILED -- the wake storm (doc/wake-storm.md)"; rm -f $(ho)/love.wake $(ho)/wake-corpus.l; exit 1; fi

# --- the metal gates: what boots, and where ---------------------------
# The kernel BUILD rules and the `run`/`uefi` verbs stay in the root Makefile;
# these are only the gates that drive the artifacts those rules lay.

ifeq ($a,x64)

test_disk: host $(R)/tools/ktest.l
	@$(MAKE) -s $(k_elf)
	@rm -f $(k_elf).disk
	@echo TEST $(k_elf) "(the WAKE lane: two boots, one disk, the reset-persistence gate)"
	@$m $(R)/tools/ktest.l $(k_elf) - $a
	@$m $(R)/tools/ktest.l $(k_elf) - $a "disk: fat kept across the reset"
	@echo "test_disk: the machine remembered"

# wget against a live https peer: opt-in, it needs the internet (test/host/wgetnet.l)
test_wgetnet: host
	@echo TEST test/host/wgetnet.l "(wget over TLS 1.3 to a live peer)"
	@cat test/00-init.l test/host/wgetnet.l | sh test/gate/run.sh wgetnet "$m" "wgetnet: ok"

# doom in an X window, the DOOM=1 build under an Xvfb (src/apps/doom/doom.l): opt-in --
# it wants the vendored source and the IWAD, and rebuilds the artifact with doom inside
test_doomx: $(R)/test/host/doomx.l
	@$(MAKE) -s host DOOM=1
	@echo TEST test/host/doomx.l "(doom on X, 300 frames under Xvfb, a held key)"
	@cat test/00-init.l test/host/doomx.l | sh test/gate/run.sh doomx "$m" "doomx: ok"

test_kverb: host
	@$(MAKE) -s $(k_elf)
	@echo TEST love kernel "(the projection verb; byte-identical to make's)"
	@rm -f $(ko)/.kverb.elf
	@cd $(ko) && $(abspath $m) kernel .kverb.elf > /dev/null
	@cmp $(ko)/.kverb.elf $(k_elf)
	@rm -f $(ko)/.kverb.elf

test_kboot: host $(R)/tools/kboot.l
	@$(MAKE) -s $(k_elf)
	@echo TEST $(k_elf) "(the kore cat off cmdline; 4 boots, ceiling 420s each)"
	@$m $(R)/tools/kboot.l $(k_elf) "kore ls src/apps/json" "json.l"
	@$m $(R)/tools/kboot.l $(k_elf) "kore wc src/apps/json/json.l" "src/apps/json/json.l" $$(wc -c < $(R)/src/apps/json/json.l)
	@$m $(R)/tools/kboot.l $(k_elf) "sh -c \"cd src/apps/json; pwd\"" "/src/apps/json"
	@$m $(R)/tools/kboot.l $(k_elf) "sh -c \"kore ls src/apps/json | kore wc -l\"" $$(ls $(R)/src/apps/json | wc -l)
else
test_disk test_kboot:
	@echo "$@: skipped (host arch $a is not x64)"
endif

OVMF_X64 := $(wildcard dl/edk2-ovmf/ovmf-code-x86_64.fd)
ifeq ($(and $(filter x64,$a),$(OVMF_X64)),)
test_uefi:
	@echo "test_uefi: skipped (x64 + dl/edk2-ovmf/ovmf-code-x86_64.fd needed)"
else
test_uefi: host $(R)/tools/ktest.l
	@$(MAKE) -s $(ko)/esp-x64/EFI/BOOT/BOOTX64.EFI $(ko)/esp-x64/love.elf $(ko)/esp-x64/love.cmd
	@echo TEST $(ko)/esp-x64 "(serial, headless, our own BOOTX64.EFI; ~64s, ceiling 420s)"
	@$m $(R)/tools/ktest.l $(ko)/esp-x64 $(OVMF_X64) x64
endif

OVMF_A64 := $(wildcard dl/edk2-ovmf/ovmf-code-aarch64.fd)
QEMU_A64 ?= $(shell command -v qemu-system-aarch64 2>/dev/null)
ifeq ($(and $(OVMF_A64),$(QEMU_A64)),)
test_uefi_a64:
	@echo "test_uefi_a64: skipped (qemu-system-aarch64 + dl/edk2-ovmf/ovmf-code-aarch64.fd needed)"
else
test_uefi_a64: host $(R)/tools/ktest.l
	@$(MAKE) -s a=a64 $(ko)/esp-a64/EFI/BOOT/BOOTAA64.EFI $(ko)/esp-a64/love.elf $(ko)/esp-a64/love.cmd
	@echo TEST $(ko)/esp-a64 "(serial, headless, our own BOOTAA64.EFI; TCG, ceiling 420s)"
	@$m $(R)/tools/ktest.l $(ko)/esp-a64 $(OVMF_A64) a64
endif

test_inle:
	@$(MAKE) -s test_disk
	@$(MAKE) -s test_uefi
	@$(MAKE) -s test_kboot
	@$(MAKE) -s test_kverb
	@$(MAKE) -s test_kernel_a64
	@$(MAKE) -s test_uefi_a64
	@$(MAKE) -s test_kernel_rv64
	@echo "test_inle: boot, disk, command line, firmware -- all three arches"

ifeq ($(QEMU_A64),)
test_kernel_a64:
	@echo "test_kernel_a64: skipped (need qemu-system-aarch64)"
else
test_kernel_a64: host $(R)/tools/ktest.l
	@$(MAKE) -s a=a64 $(ko)/love-a64.elf
	@echo TEST $(ko)/love-a64.elf "(the WARM lane: serial, headless, TCG, -kernel; ceiling 420s)"
	@$m $(R)/tools/ktest.l $(ko)/love-a64.elf - a64
endif

QEMU_RV64 ?= $(shell command -v qemu-system-riscv64 2>/dev/null)
ifeq ($(QEMU_RV64),)
test_kernel_rv64:
	@echo "test_kernel_rv64: skipped (need qemu-system-riscv64)"
else
test_kernel_rv64: host $(R)/tools/ktest.l
	@$(MAKE) -s a=rv64 $(ko)/love-rv64.elf
	@echo TEST $(ko)/love-rv64.elf "(the WARM lane: serial, headless, TCG, -kernel; ceiling 420s)"
	@$m $(R)/tools/ktest.l $(ko)/love-rv64.elf - rv64
endif

NODE ?= $(shell command -v node 2>/dev/null)
EMCC ?= $(or $(shell command -v emcc 2>/dev/null),/usr/lib/emscripten/emcc)
ifeq ($(and $(NODE),$(wildcard $(EMCC))),)
test_wasm:
	@echo "test_wasm: skipped (needs emcc + node)"
else
test_wasm:
	@$(MAKE) -s -C $(R)/src/port/wasm gate
	@echo TEST out/wasm/love.js "(node)"
	@$(NODE) $(R)/src/port/wasm/test.mjs --love $(R)/out/wasm/love.js $t
	@$(NODE) $(R)/src/port/wasm/screen.mjs --love $(R)/out/wasm/love.js
endif

# --- the two binary-shape gates, both skipping when their tool is absent ---

OBJDUMP_ANY := $(shell command -v objdump 2>/dev/null || command -v llvm-objdump 2>/dev/null)
ifeq ($(OBJDUMP_ANY),)
vmret: host
	@echo "vmret: skipped (needs objdump or llvm-objdump)"
else
vmret: host
	@$m tools/vmret.l $m
endif

WAITS_C := $(shell git ls-files '*.c' 2>/dev/null)
ifeq ($(WAITS_C),)
waits: host
	@echo "waits: skipped (needs a git checkout to enumerate the .c files)"
else
waits: host
	@$m tools/waits.l $(WAITS_C)
endif
