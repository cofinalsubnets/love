# test/test.mk -- the test_* gates (and the uuwm/uukind corpus generators).
# a fragment of the root Makefile, included by ./Makefile and invoked from the
# project root; paths resolve from there. Shared vars live in common.mk.

# every gate below is phony, this roster included -- a gate whose name is missing here
# stops running the day a file of that name appears. Generated from what this file
# defines; the root Makefile names only its own verbs.
.PHONY: \
  moon-bzip2 moon-bzip2-a64 moon-bzip2-rv64 moon-gzip moon-gzip-a64 moon-gzip-rv64 \
  moon-lua moon-lua-a64 moon-lua-rv64 moon-m4 moon-m4-a64 moon-m4-rv64 moon-sqlite \
  moon-sqlite-a64 moon-sqlite-rv64 moon-tar moon-tar-a64 moon-tar-rv64 mx nettest test \
  test_as test_asmops test_bakerep test_big test_boards test_cca64 test_ccrv64 test_ccwasm test_ccthumb1 \
  test_ccthumb2 test_clay test_cli test_cookdiff test_cpio test_cts test_cts_a64 \
  test_cts_rv64 test_cts_wasm test_disk test_dist test_distboot test_doc test_drat test_drv test_dtb \
  test_elf32 test_encver test_extra test_extract test_fat test_fat32 test_filemode test_fixpoint \
  test_forge test_freebsd test_freebsd_a64 test_front test_gc test_gcheck test_gcstress \
  test_gates test_gen test_glaze test_glazebench test_glazefuzz test_gz test_harp test_hdiff test_holo test_holofuzz test_holowasm test_hook \
  test_host test_hostegg test_hostnif test_inle test_kboot test_kernel_a64 test_kernel_rv64 test_kernel_wasm test_kore \
  test_kverb test_libc test_love0 test_lux test_moon test_moonfuzz test_mps2 test_mps2_t1 \
  test_mps2_build test_mps2_wake test_mx test_netbsd test_netbsd_a64 test_nucleo446 test_nucleo446_smoke \
  test_objcopy test_ord test_playdate test_proof test_raw test_raw_a64 test_raw_bake test_raw_rv64 \
  test_refuzz test_reloc32 test_root test_rv64 test_rp2040 test_rvboot test_sat test_sb test_seat test_seed \
  test_doomwasm test_nestwasm test_seedwasm test_selfhost test_slow test_softfp test_stdinbuf test_stdincorpus test_tco0 test_teensy41 test_thumb1 \
  test_thumb2 test_thumb2sp test_tools test_uefi test_uefi_a64 test_ulp test_uugen \
  test_uuhomgen test_uukind test_uulean test_uumx test_uusplgen test_uuvallaw test_uuwm \
  test_vec test_vi test_virt test_virt_build test_wake test_xfixpoint uuhomgen uukind uumx uusplgen \
  uuvallaw uuwm vmret waits

# the three gates. `make test` is the fast one an edit loop runs, test_slow the
# merge gate, test_extra the really slow one (qemu boots, cross-arch, boards).
# Everything below is a member of one of them, or opt-in by name.
test_phases = test_ord test_host test_love0
# fast gate
test:
	@$(MAKE) --no-print-directory $(test_phases)

# slow gate
test_slow: test_host test_love0 vmret test_bakerep test_stdinbuf test_stdincorpus test_seat test_cli test_cookdiff test_glazebench test_dist test_seed test_moon test_links test_kernel_wasm


# really slow gate
test_extra: test_filemode waits test_front test_proof test_gen test_uugen test_uulean test_uuwm \
	test_uukind test_gc test_gcheck test_gcstress test_extract test_big test_mx \
	test_tools test_web test_hostnif test_doc test_glaze test_hook test_sat test_holo test_holowasm test_as \
	test_holofuzz test_glazefuzz test_encver test_kore test_refuzz test_sb test_vi \
	test_clay test_moonfuzz test_forge test_gates \
	test_cts test_libc test_ulp test_softfp test_reloc32 \
	test_drv test_hdiff test_tco0 nettest test_wake test_gz test_cpio test_fat32 test_root \
	test_uuhomgen test_uusplgen test_uumx test_uuvallaw \
	test_fixpoint test_xfixpoint test_raw_bake test_drat test_vec \
	test_asmops test_dtb test_rvboot test_elf32 test_objcopy test_distboot test_fat \
	test_cca64 test_ccrv64 test_ccwasm test_ccthumb1 test_ccthumb2 test_cts_a64 test_cts_rv64 test_cts_wasm \
	test_raw_a64 test_raw_rv64 \
	test_virt test_thumb1 test_thumb2 test_thumb2sp \
	test_mps2 test_mps2_t1 test_mps2_wake test_nucleo446_smoke test_links \
	test_freebsd test_netbsd test_freebsd_a64 test_netbsd_a64 \
	test_inle

# $m is the warm love -- the baked image woken, what ships. a gate whose subject is
# the egg boot spells LOVE_NO_IMAGE=1 itself; love0 is always the egg.

# love0 self-tests BOTH compilers in one run (-Dai_tco=0, the trampoline lane too), so it
# must print two "tests pass" summaries -- a reader stop drops the rest and exits 0. status
# rides `.rc`, no pipefail. corpus.list is a runtime input, not a stamp: love0 reads it to
# find the corpus (inle/main.c), and nothing else asks for it, so it is named here or a fresh
# tree dies with `love0: corpus: cannot open out/lib/corpus.list`.
test_love0: $(love0) out/lib/corpus.list
	@echo TEST $(love0)
	@{ $(love0) </dev/null; echo $$? > out/.test_love0.rc; } | tee out/.test_love0.out; \
	  s=$$(cat out/.test_love0.rc); \
	  [ $$s -eq 0 ] && [ `grep -c "tests pass" out/.test_love0.out` -eq 2 ]
# test_filemode -- file mode is terminal, and nothing inside the corpus can gate that:
# a test that proves the run dies cannot also report. so a shell runs one two-line file
# and asks both halves of the law -- the face on err and exit 1 -- for a missing name.
test_filemode: $(ho)/love
	@echo TEST file mode is terminal
	@printf '(: _ (puts "reached\\n") _ (an-name-the-book-lacks 1) (puts "past\\n"))\n' > out/.test_filemode.l
	@$m out/.test_filemode.l > out/.test_filemode.out 2>&1; r=$$?; \
	  { [ $$r -eq 1 ] && grep -q "^reached$$" out/.test_filemode.out \
	      && grep -q "^;; missing an-name-the-book-lacks$$" out/.test_filemode.out \
	      && ! grep -q "^past$$" out/.test_filemode.out; } \
	    || { cat out/.test_filemode.out; echo "FAIL file mode not terminal (exit $$r)"; exit 1; }
# test_stdinbuf -- what we borrow OF fd 0 is invisible, and we borrow two things. both doors
# gulp 4096 (love/love.c's rbio_of), so the law is that both leave the untaken bytes there, for
# an in-form and for a child inheriting the fd. a seekable door lseeks them back; a pipe has
# no rewind, so stdin_hand sends them down a fresh pipe -- which is why the handoff laws are
# asked of the PIPE output directly. the pipe also lends its O_NONBLOCK bit (`inflag`), read
# straight off /proc: a child must inherit fd 0 blocking or it takes an empty pipe for an
# ended one. the corpus cannot gate any of this; it lives between two ways of being fed.
test_stdinbuf: $(ho)/love
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
# ..and the give-back rides the same seek: `unchug` returns drained bytes to the run, so
# ai_io_pending counts them again and the child inherits fd 0 in front of them. the CONTRAST
# is the law -- `chug` drains the whole run, so the child inherits nothing without it and all
# ten with. only rbio_of finds that run: a heap-port-only door answers 0 here while every
# file-port law in test/io.l still passes.
	@printf 'abcdefghij' > out/.test_stdinbuf4.in
	@p='(: c (see in) _ (unsee in c) t (chug in)'; \
	  a=`$m -e "$$p k (unchug in 99) (exec [\"cat\"]))" < out/.test_stdinbuf4.in`; \
	  b=`$m -e "$$p (exec [\"cat\"]))" < out/.test_stdinbuf4.in`; \
	  { [ "$$a" = abcdefghij ] && [ -z "$$b" ]; } \
	    || { echo "FAIL unchug is not in the inherited fd offset (with=[$$a] without=[$$b])"; exit 1; }
# test_host takes the corpus as a FILE: a speed choice, not a necessity. the gap is the
# reader, not the device -- a redirect gulps 4096 like a file does, but `reads` trickles `in`
# a byte at a time to keep its position exact, ~1.45x here, and this gate runs constantly.
# cat'ing also keeps the corpus's one-global-scope property.
test_host: $(ho)/love
	@echo TEST $m
	@cat $t > out/.test_host.l
	@{ $m out/.test_host.l </dev/null; echo $$? > out/.test_host.rc; } | tee out/.test_host.out; \
	  s=$$(cat out/.test_host.rc); \
	  [ $$s -eq 0 ] && grep -q "tests pass" out/.test_host.out
# test_hostegg -- the same corpus down the egg boot. a woken heap is not the egg's: it
# arrives with a pinned prefix it did not copy and an intern map it did not build, so both
# doors are worth running. wants $(ho)/love.raw, not the bake -- an egg lane has no use for
# the ~12 s bake. two asserts fewer than test_host is right: test/holo.l opens on
# `(lit? (cite 'holo))` and holo lives in the glaze, so those two laws are the baked door's.
test_hostegg: $(ho)/love.raw
	@echo TEST $m "(egg)"
	@cat $t > out/.test_hostegg.l
	@{ env LOVE_NO_IMAGE=1 $(ho)/love.raw out/.test_hostegg.l </dev/null; echo $$? > out/.test_hostegg.rc; } | tee out/.test_hostegg.out; \
	  s=$$(cat out/.test_hostegg.rc); \
	  [ $$s -eq 0 ] && grep -q "tests pass" out/.test_hostegg.out
# test_stdincorpus -- the only oracle for `reads` over STDIN at corpus scale, which is where
# a reader's window arithmetic breaks. three doors because they are three readers: a file and
# a redirect share the borrowed run (love/love.c's rbio_of), a pipe has none and drips. both
# loves because a reader bug that lost two bytes showed on the baked lane and not the egg.
# past the summary's duration everything matches byte for byte -- the dots included, a
# dropped assert being exactly what this catches.
test_stdincorpus: $(ho)/love
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
# test_front -- the test-only frontend: out/front links liblove.a (love/love.c only)
# and supplies the frontend contract itself, so its port vt can answer would-block on
# cue. it exits 97 on a wait with no deadline -- a deadlock, said loudly.
$(ho)/front: test/front/main.c $(R)/love/bare.c $(R)/inle/alloc.c $(R)/inle/horn.c $(love_h) $(ho)/liblove.a $(ho)/.hostcc $(R)/love/love_data.ld \
    out/lib/egg.h out/lib/post.h out/lib/p1.h out/lib/prel.h out/lib/ev.h
	@echo 'CC	'$@
	@mkdir -p $(dir $@)
	@$(hcc) -o $@ test/front/main.c $(R)/love/bare.c $(R)/inle/alloc.c $(R)/inle/horn.c $(ho)/liblove.a $(data_ld)
# ..and the same frontend with the horn's SEAT door in place of its sink: ai_horn_seat
# makes inle/horn.c ask k_horn_* for the device, which is the lane inle runs over inle/hda.c
# and the playdate over its SDK. no gate can reach that lane WITH hardware, and this one
# reaches it without -- the frontend's k_horn_* are the device, over the same
# inle/hornring.h the playdate hands its SDK callback.
$(ho)/frontseat: test/front/main.c $(R)/love/bare.c $(R)/inle/alloc.c $(R)/inle/horn.c $(R)/inle/hornring.h $(love_h) $(ho)/liblove.a $(ho)/.hostcc $(R)/love/love_data.ld \
    out/lib/egg.h out/lib/post.h out/lib/p1.h out/lib/prel.h out/lib/ev.h
	@echo 'CC	'$@
	@mkdir -p $(dir $@)
	@$(hcc) -D ai_horn_seat=1 -o $@ test/front/main.c $(R)/love/bare.c $(R)/inle/alloc.c $(R)/inle/horn.c $(ho)/liblove.a $(data_ld)
test_front: $(ho)/front $(ho)/frontseat
	@echo TEST $(ho)/front
	@sh test/gate/run.sh -a front "$(ho)/front" "front: ok" test/front/io.l
	@echo TEST $(ho)/front "(inle/horn.c's sink, read back through the tap)"
	@sh test/gate/run.sh -a horn "env HORN=none $(ho)/front" "horn: ok" test/front/horn.l
	@echo TEST $(ho)/frontseat "(inle/horn.c's seat door, over the device's own ring)"
	@sh test/gate/run.sh -a hornseat "$(ho)/frontseat" "hornseat: ok" test/front/hornseat.l
# standalone smoke tests, held out of the corpus glob ($t is a non-recursive test/*.l).
# a file is held back for one of three reasons and says which: it wants a crew module and
# cats.c is the catalog love0 lacks; it is not idempotent and love0 evaluates twice; or its
# regression is a HANG, wanting a timeout a corpus cannot give -- a wedged gate is worse than
# a red one. gate = exit 0 and a "<name>: ok"; a cold lane opts in via hostnif_cold.
hostnif_tests = test/host/gcpause.l test/host/deepeq.l test/host/wharf.l test/host/cb.l test/host/manifest.l test/host/rune.l test/host/pty.l test/host/loader.l test/host/rdiff.l test/host/run.l test/host/luxui.l test/host/sh.l test/host/berth.l test/host/overlay.l test/host/bake.l test/host/rove.l test/host/tty.l test/host/lapiz.l test/host/papel.l test/host/kiosko.l test/host/web.l test/host/sbhttp.l test/host/salt.l test/host/libra.l test/host/clay.l test/host/tls.l test/host/tlsc.l test/host/gz.l test/host/gzc.l test/host/story.l test/host/design.l test/host/slop.l test/host/score.l test/host/grass.l test/host/lupa.l test/host/mc.l test/host/helm.l test/host/wget.l test/host/cook.l test/host/x11.l
# out/lush: test/host/sh.l drives the built shell end to end, via out/love and
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
# one global scope, so they run standalone. Same contract: exit 0 and a "<name>: ok".
doc_tests = test/proto/dest.l test/proto/spl.l
test_doc: host
	@for s in $(doc_tests); do echo "TEST $$s"; \
	  cat test/00-init.l $$s | sh test/gate/run.sh doc "$m" ": ok" \
	    || { echo "  (the gate above is $$s)"; exit 1; }; \
	done
# native-codegen self-tests (the love/boot/glaze.l x86-64 jit): test/glaze-x86.l covers emit
# (the SSE emitter) + auto (ev's source-recognizer), cats the holo backends ahead of
# itself, and runs each block through base-ev. Needs the `nat` nif; x86-64 only.
ifeq ($a,x64)
test_glaze: host
	@echo TEST test/glaze-x86.l "(emit + auto)"
	@{ echo "(borrow 'holo)"; cat love/holo/x64.l love/holo/a64.l test/glaze-x86.l; } \
	  | sh test/gate/run.sh glaze "env LOVE_NO_IMAGE=1 $m" "test/glaze-x86:"
else
test_glaze:
	@echo "test_glaze: skipped (host arch $a is not x64)"
endif
# test_hook -- the natjit creation-hook laws: every law claims both the answer and that the hook
# owned it (`fired?`), twice over the hook's two lives -- the image's ($m, what ships) and the
# egg boot's ($m). never by cat'ing hook.l in: a woken image has `nif` off the book.
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
# test_glazebench -- the glaze pays on the benches, through the lanes a user runs: each bench
# source as spelled (bench/bench.l + bench/benches/<b>.l), glazed against LOVE_NO_GLAZE=1, by
# stdin and by file in turn, each ratio held to a floor near a third of the healthy speedup;
# and the driver's ev is the live one. what test_glaze/test_hook cannot see: they hand (ev '..)
# forms they spelled themselves. on the merge gate because both misses it caught rode one.
ifneq ($(filter $a,x64 a64),)
test_glazebench: host
	@echo TEST test/gate/glazebench.sh "(the benches glaze through the driver)"
	@sh test/gate/glazebench.sh $m $a
else
test_glazebench:
	@echo "test_glazebench: skipped (the glaze emits for x64 / a64; host arch is $a)"
endif
# test_glazefuzz -- the glaze's differential fuzz (test/gate/glazefuzz.l): 3000 random closures
# run twice against the same binary (plain, then LOVE_NO_GLAZE=1), stdouts byte-identical.
# `fires=` is the checked proof of work; stderr is dropped (the two runs scare differently).
ifneq ($(filter $a,x64 a64),)
test_glazefuzz: host
	@echo TEST test/gate/glazefuzz.l "(glaze differential fuzz: glazed vs interpreted)"
	@on=out/.gfuzz_on.out; off=out/.gfuzz_off.out; \
	  LOVE_NO_IMAGE=1 $m test/gate/glazefuzz.l > $$on 2>/dev/null \
	    || { echo "FAIL glazefuzz: the GLAZED run died"; exit 1; }; \
	  LOVE_NO_IMAGE=1 LOVE_NO_GLAZE=1 $m test/gate/glazefuzz.l > $$off 2>/dev/null \
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
# apps/sat/ -- the CDCL SAT solver app. Portable love (no glaze), so it runs on every arch.
# Gate = exit 0 and the sentinels. cold on purpose -- the one app gate that is: the
# solver answers in 3.6 s over the fresh egg and 14.4 s over the woken image.
test_sat: host
	@echo TEST apps/sat/sat.l + apps/sat/dimacs.l + apps/sat/flat.l
	@cat apps/sat/sat.l apps/sat/dimacs.l apps/sat/flat.l \
	  | sh test/gate/run.sh sat "env LOVE_NO_IMAGE=1 $m" "sat: Stages 1-3 ok|apps/sat/dimacs: ok|apps/sat/flat: ok"
# The DRAT lane's external check: flat.l's refutations verified by drat-trim, the SAT
# competition's own checker (fetched + built into out/drat on first use; skips offline).
# The in-gate twin (fd-check) runs inside test_sat. Not in test_slow (network).
test_drat: host
	@cd apps/sat && ./dratcheck.sh || { echo "FAIL drat"; exit 1; }
# The lux app's pure core (apps/lux/core.l): xmonad's StackSet -- focus zipper, workspace
# sheaf, floating half -- with xmonad's QuickCheck laws + a seeded fuzz. Pure love, so it
# self-tests portably; the X layers need connectu and are proven against Xephyr, not here.
test_lux: host
	@$m test/gate/gates.l lux < /dev/null
# harp (apps/harp/harp.l): tidal's cycle algebra, where a pattern is a function from a
# span to events -- so the gate is queries, and the whole pure half runs anywhere. the
# voices (apps/harp/play.l) ride along for the far end: one cycle into a .wav whose
# energy has to land where the pattern said, and one out the horn=none sink, which has
# to take a second to play a second. that is as far as a gate that cannot listen goes.
test_harp: host
	@$m test/gate/gates.l harp < /dev/null
# test_gates -- the app-law rows in one love. a row's files arrive by `borrow` on a path,
# which makes the layer `cat` was faking, so rows keep their names apart without a process
# apiece; and the verdict is the harness's own tally instead of a grep for the red X it
# prints -- run.sh reads that back off stdout because a pipe is all a shell can see. each
# row above keeps its make target, which runs that row by name.
test_gates: host
	@echo TEST test/gate/gates.l "(the app-law rows, one love)"
	@$m test/gate/gates.l < /dev/null
# the seat lane -- an app fired by its own file NAME (positional, or a -l preload), which
# is the one dispatch door no other gate reaches: every app gate below drives its subject
# through the verb rail or a baked image instead. ~2.5s, most of it one bake, and it rides
# test_slow because the failure it catches is silent by construction (a seat that answers
# () is indistinguishable from an app with nothing to say).
.PHONY: test_seat test_cli
test_seat: host
	@echo TEST test/gate/seat.sh "(the file-seat lane)"
	@sh test/gate/seat.sh $m
# the CLI's exit status -- 0 working, 1 unopenable, 2 malformed, a verb's own charm.
# seat.sh reads what the binary says; until this, nothing read what it answers.
test_cli: host
	@echo TEST test/gate/cli.sh "(the cli exit-status lane)"
	@sh test/gate/cli.sh $m

# the front page's icon is laid (tools/mkicon.l) and checked in for github pages: a lay
# that differs from the tree means someone edited a source without `make web`. the page
# and its stylesheet are written by hand and lay nothing
test_web: host
	@echo TEST tools/mkicon.l
	@mkdir -p out/.w
	@env -u LOVE_NO_IMAGE $m tools/mkicon.l love/quay/cga_8x8.c 3 32 out/.w/favicon.png 2>/dev/null
	@cmp -s out/.w/favicon.png web/favicon.png \
	  || { echo "  FAIL: a committed web asset is behind web/ -- run make web and commit"; exit 1; }
	@echo "  web: ok -- the icon is what web/ lays"
test_sb: host out$(hsuf)/sb
	@echo TEST apps/sb/sb.l + test/host/sb.l
	@rm -rf out/.sbtest
	@cat test/00-init.l test/host/sb.l | sh test/gate/run.sh sb "$m" "sb: ok"
# the kore smokes drive love's own crew layer (`love kore ..` -- the layered bake),
# warm per spawn; the argv0 smoke lays its own two-line shim,
# the distro's shape, since the tree carries no kore binary anymore.
korerun = $m kore
test_kore: host
	@sh test/gate/kore.sh $(ho) $m
# grep + sed against GNU over seeded random patterns (doc: the script's own head).
# test_kore's battery is a list someone thought of; this one is NOT, which is the point.
# skips (exit 0) without GNU grep/sed, and checks --version, since an interactive `grep`
# may be a ugrep shim whose BRE differs. ~a minute.
test_refuzz: host
	@sh test/gate/refuzz.sh $m
# cook against GNU make, differentially (doc: the script's own head). The oracle is a
# second implementation, and it has to be: a builtin cook never implemented is a variable
# reference in make's grammar, so it expands to empty and the build carries on -- invisible
# to any test that only asks whether cook agrees with itself. Skips (exit 0) where GNU make
# is not on the box, since there is no oracle to ask.
test_cookdiff: host
	@sh test/gate/cookdiff.sh $m
# the dist artifact -- the tree's own baked binary: test_dist smokes its verb rail,
# the bare cc door, the image chain and the in-image lane. seconds, test_slow.
test_dist: $(ho)/love
	@sh test/gate/dist.sh smoke $(ho)/love
# test_seed -- the merge gate: the artifact lays its own source into a scratch dir, rebuilds
# itself through the machine's toolchain, and the rebuilt binary must answer the running
# one's bytes. minutes, and the claim the product makes. scratch stays on a red.
# ONLY this gate runs the GREGARIOUS lane, where the seed probes for an ambient cc and
# defers to it (apps/source.l) -- the diverse-double-compiling leg, the one thing a self build
# cannot say. it is `-g` since autonomous became the default, and naming it is the point. test_distboot runs `love seed` with every compiler poisoned, so it takes the
# fallback and can never exercise the deference. do not roster the two as one claim.
test_seed: $(ho)/love
	@echo TEST love seed "(the fixpoint)"
	@rm -rf $(ho)/.seedtest && mkdir -p $(ho)/.seedtest
	@$(ho)/love seed -g $(ho)/.seedtest > $(ho)/.test_seed.out 2>&1 \
	  || { tail -20 $(ho)/.test_seed.out; echo "FAIL love seed"; exit 1; }
	@tail -1 $(ho)/.test_seed.out
	@rm -rf $(ho)/.seedtest
# The editor (apps/vi/): the pure modal engine's laws (no tty -- vstep driven byte by
# byte), then scripted end-to-end passes through the `kore vi` face over a pipe (keys off
# stdin, frames onto a captured stdout, :wq writes), driven through the crew layer.
test_vi: host
	@echo TEST apps/{tui,vi/hue,vi/core}.l test/law/{tui,vi}.l
	@cat test/00-init.l apps/kore/text.l apps/kore/u.l apps/kore/core.l apps/kore/re.l apps/kore/sed.l apps/libra/lint.l \
	    apps/tui.l test/law/tui.l \
	    apps/vi/config.l apps/vi/hue.l apps/vi/core.l test/law/vi.l \
	  | sh test/gate/run.sh vi "$m" "test/law/vi:"
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
# The C compiler (apps/moon/, doc/misc/moon.md): the pure pipeline's goldens, then stage-0 end
# to end through the real `mooncc` -- compile, run, exit 42, against a gcc -O0 differential
# on the same source. Drives the crew layer warm (~0.68s -> ~0.1s per compile, 88 of them).
moonrun = $m mooncc
# love0 rides along for the inline-asm checks: neutral templates parse through holo/text.l,
# whose combinators come off the bare `post` each frontend's boot binds itself, so the
# bootstrap lane can lose the feature while this one keeps it.
test_moon: host $(love0)
	@sh test/gate/moon.sh $(ho) $m $(love0)
# the committed generated artifacts, laid from the tables that define them (love/mx.l the +/*
# matrices and the kind lattice, love/nifs.l the nif + instruction registry, quay.l the
# xterm-256 palette host and kernel share). `make mx` refreshes, test_clay diffs.
# mx.h/kinds.h/nifs.h are core headers, so the gate after a refresh is `make test`, not
# test_clay alone. each is written aside and moved only once the whole set lays.
# dest:source:value:shape-check -- one roster, read by `make mx` (which writes) and by
# test_clay (which regenerates and diffs). Two spellings of this list is how they drift.
mx_gen = love/mx.h:love/mx.l:mx-h:mx-ok love/kinds.h:love/mx.l:kinds-h:mx-ok love/nifs.h:love/nifs.l:nifs-h:nifs-ok \
         love/quay/xterm256.h:love/quay/quay.l:q-c:q-ok love/love_data.ld:love/mx.l:mx-ld:mx-ok
# /warn the \# escapes are load-bearing: a bare # in a make variable starts a comment and
# would eat the rest of the line (a recipe line passes # through, a variable does not).
mxsplit = d=$${s%%:*}; r=$${s\#*:}; l=$${r%%:*}; r=$${r\#*:}; v=$${r%%:*}; k=$${r\#*:}; o=out/.`basename $$d`
# the egg lane, deliberately: these generators read core tables with the boot
# vocabulary, and the warm book now carries the crew (the layered bake) -- kore's
# two-arg `join` shadowed clay's one-arg at mx-h's define and the .h came out empty.
mxlay   = LOVE_NO_IMAGE=1 $m -l $$l -e "(: _ (? $$k 0 (quit 1)) _ (puts $$v) (quit 0))"
mx: host
	@echo 'LOVE	'love/mx.h love/kinds.h love/nifs.h xterm256.h love/love_data.ld "(love/mx.l + love/nifs.l + quay.l on $m)"
	@for s in $(mx_gen); do $(mxsplit); $(mxlay) > $$o || exit 1; done
	@for s in $(mx_gen); do $(mxsplit); mv $$o $$d; done
# ...and the dependency, off the same roster: without it a new love/nifs.l row builds clean and
# gates green with its nom still off the book, and the drift diff only test_extra reaches.
# the prerequisite is the TABLE alone, never $(m) -- love is built from these headers, so
# naming it closes the loop and make drops the lot. the recipe takes whatever love exists,
# sound because the generator IS love/nifs.l/mx.l and a stale love lays a fresh table. a tree
# with no love is the bootstrap case: the committed file builds the first one, so the rule
# stands aside and only marks it seen.
define mx_dep
$(word 1,$(subst :, ,$(1))): $(word 2,$(subst :, ,$(1)))
	@if test -x $$(m); then \
	   $$(m) -l $$< -e "(: _ (? $(word 4,$(subst :, ,$(1))) 0 (quit 1)) _ (puts $(word 3,$(subst :, ,$(1)))) (quit 0))" > out/.$$(@F) || exit 1; \
	   cmp -s out/.$$(@F) $$@ || echo "LOVE	$$@ (relaid -- $$< moved)"; \
	   mv out/.$$(@F) $$@; \
	 else touch $$@; fi
endef
$(foreach s,$(mx_gen),$(eval $(call mx_dep,$(s))))
# test_ord -- the four orderings on a tray, asked with a collection inside them. THE
# SMALL BUDGET IS THE WHOLE POINT: at a roomy heap a collect lands in the middle of a
# comparison too rarely to be a law, and what one answers there is the question.
test_ord: host
	@echo TEST test/gate/ord.l "(the four orderings on a tray, under the collector)"
	@LOVE_BUDGET_MB=32 $m $(R)/test/gate/ord.l < /dev/null || { echo "FAIL test_ord"; exit 1; }
# test_clay -- G1, clay's faithfulness gate (apps/moon/clay.l, doc/misc/clay.md): for every file
# in test/cc/, (cparse (clay-show ast)) == ast, structurally. the run partitions and names
# both halves: what it can say, and the declarations cparse did not keep -- a measured gap.
test_clay: host
	@echo TEST test/gate/clay.l "(clay G1: (cparse (clay-show c)) == c over test/cc)"
	@$m -l test/gate/clay.l < /dev/null
# ...and the consumers: the generated headers regenerate and diff here -- a hand edit to any,
# or a table edit with no regen, is a red. The roster is mx_gen above; `cmp`, not rtk diff.
	@for s in $(mx_gen); do $(mxsplit); $(mxlay) > $$o; \
	   cmp -s $$o $$d || { echo "FAIL $$d is not what $$l lays -- run: make mx"; \
	                       diff -u $$d $$o | head -20; exit 1; }; done
	@echo "clay-mx: love/mx.h, love/kinds.h, love/nifs.h, xterm256.h and love/love_data.ld regenerate identically"
	@for s in $(mx_gen); do $(mxsplit); rm -f $$o; done
# test_moonfuzz -- moon's refusal surface: each test/cc file broken
# eight ways from a fixed seed. Two reds -- no scare, no hang -- plus G1 on every mutant that
# still parses, and a printed census of named-vs-bare refusals. stderr is kept: cpp speaks there.
test_moonfuzz: host
	@echo TEST test/gate/moonfuzz.l "(moon refusal fuzz: 8 mutants per file over test/cc)"
	@$m -l test/gate/moonfuzz.l < /dev/null
# test_forge -- nifs written in love (apps/forge.l): a kernel's holo IR assembled for this cpu,
# installed through the `nif` seam, and required to agree with the twin it deopts into -- on the
# monomorphic lane it says and on every lane it hands back.
# the twin here is the C nif itself, so a disagreement is one denotation answering two ways.
# Zero kernels fitted fails: a graceful decline is the design, a silent one reads like a pass.
test_forge: host
	@echo TEST test/gate/forge.l "(forge: love IR -> holo -> nif -> differential)"
	@LOVE_NO_IMAGE=1 $m -l test/gate/forge.l < /dev/null
# every test/cc/*.c by `mooncc -t $*`, run under qemu-user, held to what x64 answers.
# the three programs no cross lane can build must refuse, not skip.
test_cca64 test_ccrv64: test_cc%: host
	@sh test/gate/ccarch.sh $* $(ho) $m
# test_ccwasm -- the same battery on the wasm target, node as the machine (ccwasm.sh)
test_ccwasm: host
	@sh test/gate/ccwasm.sh $(ho) $m
# the same battery on the device CPUs: M-profile has no qemu-user lane and is ILP32, so
# x64 is neither runnable nor the oracle -- arm-none-eabi-gcc's build of the source is.
test_ccthumb1 test_ccthumb2: test_cc%: host
	@sh test/gate/ccthumb.sh $* $(ho) $m
# an outside corpus: c-testsuite's 220 programs held to the stdout the corpus ships.
# test/cc/ pins faults we had met; these did not, and found nine mooncc answers wrong --
# rostered with a cause apiece in cts.sh, refusals and wrong answers kept apart.
# opt-in on an imported tree (`make dl/c-testsuite`), skips whole without it.
test_cts: host
	@sh test/gate/cts.sh x64 $(ho) $m
test_cts_a64 test_cts_rv64 test_cts_wasm: test_cts_%: host
	@sh test/gate/cts.sh $* $(ho) $m
# the corpus itself -- 220 files, cloned once and kept in dl/ like OVMF, so `make clean`
# leaves it and only `make distclean` asks the network again. nothing depends on this rule:
# a gate that downloads is a gate that fails on a train.
dl/c-testsuite:
	@echo 'MK	'c-testsuite
	@git clone --depth=1 https://github.com/c-testsuite/c-testsuite.git $@ > /dev/null 2>&1
# test_libc -- our C library against the system's, function by function:
# test/libc/*.c built by mooncc (pulling apps/moon/lib/moonlibc/ by need) and by gcc, run,
# and the two outputs compared, so a drift names the function and the case.
test_libc: host
	@sh test/gate/libc.sh $(ho) $m
# test_ulp -- the math floor, built by both compilers and required to agree. `make ulp`
# measures am.c's accuracy for the $(CC) build alone, which asks whether the algorithm is
# right, never whether our compiler builds it -- and float bits are where codegen hides.
test_ulp: host
	@sh test/gate/ulp.sh $(ho) $m
# test_softfp -- the compiler runtime, against the machine that has the instruction.
# apps/moon/lib/rt.c is what mooncc's own lowering calls on a board with no FPU, no umull
# and no clz; on the board there is no second opinion, so it is held to bit equality with
# real hardware here, built by the system cc and by mooncc on all three backends.
test_softfp: host
	@sh test/gate/softfp.sh $(ho) $m
# test_reloc32 -- --emit-relocs on the arm32 lane: a fully linked image that keeps its
# R_ARM_ABS32 sites, so a loader placing it at a base of its own can slide them. The gate
# links one source twice, 64K apart, and holds the table to being exactly the words that
# moved -- and holds the seat whose absolutes ride MOVW/MOVT to refusing outright.
test_reloc32: host
	@sh test/gate/reloc32.sh $(ho) $m
# The rung-2 self-host gate: compile the love and host lanes with mooncc (gcc/clang only
# links), then run the whole corpus through the all-mooncc binary -- the compiler compiles
# the runtime it runs on. opt-in; x86-64 only; the binary carries no image, so a fresh egg.
test_selfhost: host
	@echo TEST $(ho)/love-selfhost
	@if [ "`uname -m`" != x86_64 ]; then echo "test_selfhost: x86-64 only, skipped on `uname -m`"; exit 0; fi; \
	  d=$(ho)/selfhost; mkdir -p $$d; rm -f $$d/*.o; \
	  for f in $(love_tu_c) $(host_c) $(R)/inle/nokern.c $(R)/inle/noblob.c; do b=`basename $$f .c`; \
	    $(moonrun) -D ai_tco=$(tco) -I$(ho) -I. -Ilove -Iinle -Iout/lib -c $$f $$d/$$b.o \
	      || { echo "FAIL mooncc -c $$f"; exit 1; }; done; \
	  $(moonrun) -Iapps/moon/include -c apps/moon/lib/moonlibc/math/am.c $$d/am.o \
	    || { echo "FAIL mooncc -c am.c"; exit 1; }; \
	  $(CC) -static -o $(ho)/love-selfhost $$d/*.o $(host_ldflags) \
	    || { echo "FAIL link all-mooncc binary"; exit 1; }; \
	  cat $t > $(ho)/.selfhost-corpus.l; \
	  LOVE_NO_IMAGE=1 $(ho)/love-selfhost $(ho)/.selfhost-corpus.l </dev/null > $(ho)/.test_selfhost.out 2>&1; s=$$?; \
	  tail -1 $(ho)/.test_selfhost.out; \
	  { [ $$s -eq 0 ] && grep -q "tests pass" $(ho)/.test_selfhost.out; } \
	    || { echo "FAIL all-mooncc corpus (exit $$s)"; exit 1; }; \
	  echo "test_selfhost: all `echo $(love_tu_c) $(host_c) | wc -w` src/*.c built by mooncc, corpus passes"
# the rung-4 gate: the gcc-free fixpoint. everything test_selfhost builds plus our own raw
# libc (moonlibc/), math floor (am.c) and sys.o, bound by our static linker -- no gcc, no
# glibc, no ld anywhere. in test_slow, x86-64 only; supersedes test_selfhost. the two cross
# twins below take the same roster, so it is spelled once.
raw_env = gate_love_c='$(love_tu_c)' gate_host_c='$(host_c)' gate_arch_c='$(hosta_c)' gate_hosta='$(hosta)' gate_seat_c='$(R)/inle/nokern.c $(R)/inle/noblob.c'
test_raw: host
	@$(raw_env) sh test/gate/raw.sh x64 $(ho) $m $t
# test_tco0 -- the trampoline at full strength. love0 is the tree's other tco=0 lane and
# cannot cover this: it is the Love0 branch, which never reaches LvGlazed, so the glaze's
# tail-threaded lvm shape goes uncalled there. this is the full love at tco=0 -- build,
# bake, pass the corpus -- in its own hsuf'd tree, so it neither clobbers nor is clobbered.
# no vmret here: at tco=0 an lvm returns, which is the point.
test_tco0:
	@$(MAKE) --no-print-directory tco=0 host
	@$(MAKE) --no-print-directory tco=0 test_host
	@echo "test_tco0: the trampoline builds, bakes and passes the host corpus"
# test_hdiff -- the foreign-cc differential, the one lane a cc that is not ours still gets
# to build. gcc and clang each link the whole vm at ai_tco=1, which the mooncc lane never
# does, and each must build, answer, pass the quick suite and come out ret-free. not the
# corpus twice: semantics are the interpreter's and do not move with the compiler.
test_hdiff: host
	@echo TEST test/gate/hdiff.sh
	@sh test/gate/hdiff.sh gcc clang
# the cc-driver conventions (the `CC=mooncc` door's floor): the real $(ai_cflags) soup
# rides through -c, a link owing libc symbols pulls the runtime by need, and the loud edges
# stay loud (-shared usage-refuses, -nostdlib names its undefined references). In test_slow.
test_drv: host
	@sh test/gate/drv.sh $(ho) $(ai_cflags)
# the kernel's inline-asm seam: inle/<a>/asmops.h says every privileged instruction
# once, in GNU's template, and mooncc reads it through holo/gas.l -- so the gate compiles one
# probe with mooncc and clang and compares op by op. Skips without llvm-objdump.
test_asmops: host
	@sh test/gate/asmops.sh $(ho)
# test_dtb -- inle/dtb.h, the walk both device-tree doors ride (a64_dtb.c and
# rv64_dtb.c, each one two constants and this include), on trees the gate builds
# rather than a machine hands over. a boot reaches exactly one tree, virt's; these reach
# the other cell width, a nested reg that is not memory, two banks either way a tree says
# it, both clamps, a cmdline past the buffer and a torn magic. Host cc, no love, no qemu.
test_dtb:
	@echo TEST test/gate/dtb.c
	@$(CC) -I$R/inle -I$R/love -I$R -o $(ho)/.dtbgate $R/test/gate/dtb.c
	@$(ho)/.dtbgate
# test_rvboot -- the riscv bring-up on A HART: mkboot.l's sv39 lane and inle/rv64/dtb.c
# under qemu -M virt, entered the way the kernel will be (OpenSBI, S-mode, a1 the tree).
# Three objects and nothing else -- the stub, the door, and test/gate/rvboot.c standing in
# for kmain -- bound by ldkern, the kernel linker's own door, since mooncc's driver enters
# through its crt0 and a machine enters at the load address. Nine laws, exit 42.
rvboot_o = $(ko)/rv64/rv64/boot.o $(ko)/rv64/inle/rv64/dtb.o $(ko)/rv64/rvboot.o
$(ko)/rv64/rvboot.o: test/gate/rvboot.c $(love_h) $(R)/inle/k.h $(R)/inle/dtb.h $(mooncc_dep)
	@echo 'MOON	'$@
	@mkdir -p "$(dir $@)"
	@$(mooncc) -I$(ko)/rv64 -I. -Ilove -Iinle -I$(ho) -Iout/lib -I$R -I$R/apps/moon/include \
	  -t rv64 -c $< -o $@
$(ko)/rv64/rvboot.elf: $(rvboot_o) test/gate/rvboot.l $m
	@echo 'RVLINK	'$@
	@LOVE_NO_IMAGE= $m test/gate/rvboot.l $(rvboot_o) $@
test_rvboot:
	@$(MAKE) -s a=rv64 $(ko)/rv64/rv64/boot.o $(ko)/rv64/inle/rv64/dtb.o
	@$(MAKE) -s $(ko)/rv64/rvboot.elf
	@sh test/gate/boot.sh rvboot "$(MAKE)"
# test_vec -- the interrupt gate: raises a real CPU exception with (fault n) and reads the
# report, the only way to reach inle/mkvec.l's 32 stubs and the fault vector, then checks the
# stubs no boot reaches against the architecture's own error-code list.
# which vec.o: at the host arch there is no $(k_pie) build -- the elf is projected out of the
# shipped love -- so $(k_o) never runs and $(moon_d)/kvec.o is the only one laid. a cross arch
# builds the pie and lays its own under $(ko). two ifeqs, never an else-ifeq.
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
# the fixpoint: the default love is mooncc-built, so this gate has it rebuild itself --
# love1 (love0's lane, relinked) bakes its own compiler image, recompiles every TU, links
# love2, and the two must be byte-identical. a headline invariant -- but it runs in
# test_extra only, so a deleted src/*.c goes green through test_slow either way.
# $(moon_o) $(kart_o) is the link list, the artifact's own: the gate is handed make's
# objects, it never globs the odir, and it links no less than `make` does.
test_fixpoint: host $(moon_seat_o) $(love0) out/mooncc0.image
	@$(MAKE) -s a=$(hosta) $(ko)/$(hosta)/mkvec.l
	@gate_love_c='$(love_tu_c)' gate_host_c='$(host_c)' gate_arch_c='$(hosta_c)' \
	  gate_kern_c='$(k_free_c)' gate_seat_c='$(R)/inle/noblob.c' \
	  sh test/gate/fixpoint.sh $(ho) $(love0) $(hosta) $(moon_d) $(moon_o) $(moon_seat_o) $(kart_o)
# the cross-machine fixpoint, in effigy: the x-lane's
# twin objects link love1, then love1 under qemu-user rebuilds itself natively and must
# answer the same bytes -- the twin machine reproducing this machine's, on one box.
# opt-in by NAME (a full rebuild under emulation is minutes): `make test_xfixpoint`,
# or `make xa=rv64 test_xfixpoint` for the other twin. skips loudly without qemu.
.PHONY: test_xfixpoint
test_xfixpoint: $(x_o) $(x_seat_o) $(xkart_o) $(love0) out/mooncc0.image
	@gate_love_c='$(love_tu_c)' gate_host_c='$(host_c)' gate_arch_c='$(wildcard $R/inle/$(xa)/*.c)' \
	  gate_kern_c='$(k_free_c)' gate_seat_c='$(R)/inle/noblob.c' \
	  sh test/gate/xfixpoint.sh $(ho) $(love0) $(xqemu) $(xa) mksys-$(xa) $(tco) $(xod) $(xa) $(x_o) $(x_seat_o) $(xkart_o)
# test_fat -- the fat container (seed-universal U1): the one file answers through
# its prefix + cache on the native machine, the pack is byte-deterministic, and
# the foreign member answers under qemu-user. opt-in by name, like the x-lane.
.PHONY: test_fat
test_fat: dist-fat
	@sh test/gate/fat.sh $(fat) $a $(xa) $(xqemu) "$(love0)" $(ho) $(xd) $(uname_$(xa))
# the multi-OS gate: one default-lane
# binary answers every kernel with the same text. the box arrives by env --
# FBSD_SSH / NBSD_SSH = "ssh -p 2222 -i key root@host" -- and without one the
# gate skips loudly. opt-in by name, like test_distboot; FBSD_SEED=1 /
# NBSD_SEED=1 adds the on-box `love seed` trophy leg (minutes).
.PHONY: test_freebsd test_netbsd test_freebsd_a64 test_netbsd_a64
test_freebsd test_netbsd: test_%: host $(love0) out/mooncc0.image
	@sh test/gate/osbox.sh $(ho) $(love0) $*
# the second ISA: {F,N}BSD_ARM64_SSH name aarch64 boxes and the local half of each
# comparison rides qemu-aarch64, so one binary answers all three kernels on an ISA this
# machine is not. the door netbsd needs there is the svc immediate. skips loudly without.
test_freebsd_a64 test_netbsd_a64: test_%_a64: host $(love0) out/mooncc0.image
	@sh test/gate/osbox.sh $(ho) $(love0) $* a64
# test_raw_bake -- the mooncc-PIE binary bakes its own image and wakes it. The procedure
# (and the why) lives in test/gate/raw-bake.sh; make keeps the dependency and the file list,
# the whole corpus. Opt-in: needs the -pie toolchain, x86-64 only.
test_raw_bake: test_raw
	@sh test/gate/raw-bake.sh $(ho) $t
# test_rv64 -- the test/cc battery `mooncc -t rv64` under qemu-riscv64, exit code
# against the native x64 build. In no tier: test_ccrv64 runs the same battery and compares
# STDOUT, so this is its strict subset -- the lighter lane, opt-in by name.
test_rv64: host
	@sh test/gate/rv64.sh $(ho) $m
# test_raw's rv64 twin: mooncc -t rv64 lays every object, mksys-rv64 the syscall
# leaf, our linker binds, qemu-riscv64 runs the whole corpus over the fresh egg. The riscv
# backend loads into the sealed holo module at runtime for mksys. Opt-in; skips w/o qemu.
test_raw_rv64: host
	@$(raw_env) sh test/gate/raw.sh rv64 $(ho) $m $t
# test_raw's a64 twin: mooncc -t a64 lays every object, mksys-a64 the syscall leaf,
# our linker binds, qemu-user runs the whole C-sorted $t over the fresh egg. $t must stay
# in C/byte order: test/uu.l defines the kernel test/uukindlaw.l calls. Opt-in; needs qemu.
# test/a64/callout.l rides past $t: it builds 'a64 nifs and runs them, so only an a64
# love may read it -- gate_sentinel is how the gate knows it was read and not stopped short.
test_raw_a64: host
	@$(raw_env) gate_sentinel='test/a64/callout:.* ok' \
	  sh test/gate/raw.sh a64 $(ho) $m $t test/a64/callout.l
# the ELF32/EM_ARM object writer (love/holo/obj.l objsecs32) and the 32-bit data model:
# a cross-object BL, the inline v6-M soft divide/rem, a literal-pool `la`, a gcc-built
# struct read back field-wise, and a named section holding a function-pointer table --
# the vector-table shape, thumb bit and all. ld32.l reads an object back the other way,
# the only exercise link.l's 32-bit field rows get.
#   thumb1 v6-M | thumb2 ARMv7E-M on the device CPU, featuring MOVW/MOVT `la`
#   thumb2sp the SP-only FPU (playdate STM32F746): f64 softens to __aeabi_*, the 64-bit
#   transfers keep the d-reg model, and qemu's mps2-an386 faults on any that slipped through
test_thumb1 test_thumb2 test_thumb2sp: test_%: host
	@sh test/gate/thumb.sh $* $(ho)
# love itself on the metal, one port apiece: the whole runtime by mooncc, start.o laid
# from holo IR, our linker binding -- no foreign toolchain anywhere. exit 42 = hatched and
# the laws held, 98 = a machine trap.
#   virt      the bare rv64 hart (inle/virt/)
#   mps2      the M7 by -t thumb2, ldbare32 one RWX segment at 0; bakes the egg from source
#   mps2_t1   the same port on the RP2040's ISA, -t thumb1: v6-M runs natively on qemu's M7,
#             and libgcc.a is a library the link reads by need, not a tool it runs
#   mps2_wake the image lane: the baker dumps a symbolic heap, a different binary whose
#             arena is deliberately offset wakes it. the teensy build rides the same love.img
#   nucleo446_smoke  the -D QSMOKE twin on qemu's Cortex-M4, exit code = the self-check
#             tally out through mkboot.l's sh_exit -- the only lane running crt0, the
#             semihosting block and the fault vectors. qemu only: on silicon a bkpt with
#             no debugger escalates to lockup.
test_virt test_mps2 test_mps2_t1 test_mps2_wake test_nucleo446_smoke: test_%: host
	@sh test/gate/boot.sh $* "$(MAKE)"
# test_playdate -- the playdate build gate. The device half is ours end to end now:
# mooncc -t thumb2sp compiles every object, pdglue.c (the pd_api.h owner) included, and
# ldbare32 binds them -- no arm-none-eabi-gcc, no ld, no linker script. The SDK is wanted
# for its C_API headers and for pdc. See test/gate/playdate.sh for what the image is held to.
test_playdate: host
	@sh test/gate/playdate.sh "$(MAKE)" $m
# test_teensy41 -- the real-metal build gate, and the one port asking for no foreign tool at
# all: mooncc -t thumb2 compiles, tlink.l binds (no ld, no linker script -- the XIP flash map
# is the map in that file), mkimg.l wraps the baked heap image, ocopy.l writes the .hex/.bin,
# and the ROM-facing boot image is verified out of that .bin (FCFB tag at flash 0, IVT at
# 0x1000, thumb-bit entry). So this one never skips; test_mps2 is the runtime (no RT1062 qemu).
test_teensy41: host
	@echo TEST out/teensy41/love.hex
	@$(MAKE) -C inle/teensy41 || { echo "FAIL teensy41 build (the boot-image verify is inside)"; exit 1; }
	@echo "test_teensy41: love (all-mooncc thumb2), OUR linker, flatten and boot image -- nothing foreign"
# test_nucleo446 -- the Nucleo-F446RE firmware build: mooncc -t thumb2sp compiles, nlink.l
# binds (no ld, no script -- the F4's memory map is the map in that file), ocopy.l flattens,
# boot image verified (initial SP inside SRAM, thumb-bit reset entry inside flash).
# arm-none-eabi-gcc is asked only where its cortex-m4 hard-float libgcc.a lives, and the .a
# is READ by need. the 128 KB SRAM never held love: this port is the toolchain on silicon.
test_nucleo446: host
	@echo TEST out/nucleo446/firm.hex
	@if ! command -v arm-none-eabi-gcc >/dev/null 2>&1; then \
	   echo "test_nucleo446: no arm-none-eabi toolchain, skipped"; exit 0; fi; \
	  $(MAKE) -C inle/nucleo446 || { echo "FAIL nucleo446 build (the boot-image verify is inside)"; exit 1; }; \
	  echo "test_nucleo446: firmware (all-mooncc thumb2sp), OUR linker and flatten, no linker script, boot image verified"
# test_rp2040 -- the Pico firmware build, nucleo446-shaped, and the one port with no .S:
# vector table and crt0 are C, and boot2 -- the 256-byte stage the mask ROM checksums first --
# is laid into a named section by mkboot2.l. so the verify has THREE words: boot2's
# CRC-32/MPEG-2 must be 0x7a4eb274, the SP inside the 264 KB SRAM, the reset entry thumb-bit
# and inside flash. nothing foreign is left to ask after, so this never skips. qemu has no
# RP2040 machine, so it builds and never boots -- test_mps2_t1 runs the ISA.
test_rp2040: host
	@echo TEST out/rp2040/love.bin
	@$(MAKE) -C inle/rp2040 || { echo "FAIL rp2040 build (the boot-image verify is inside)"; exit 1; }
	@echo "test_rp2040: firmware (all-mooncc thumb1, boot2 laid by holo, no .S), OUR linker, flatten and runtime -- no foreign file, flash R|X, boot surface verified"
# test_boards -- the build half of the ports, no emulator anywhere: the boot gates prove a
# port runs, this proves it still compiles, and that is the half that rots unwatched.
# PREREQUISITES, not recipe lines, so a wide make runs the six at once -- ~10 s together
# against ~35 s in a row, each port's own make being single-threaded.
# mps2 and virt want nothing foreign to build, only to boot, so their build halves are here.
# inle/wasm is not a board and never joins: it is the machine, and the module the page carries
# is out/love.wasm, from test_links.
test_boards: test_mps2_build test_virt_build test_rp2040 test_nucleo446 test_teensy41 test_playdate
	@echo "test_boards: six ports build and link -- mooncc and our linker, no emulator"
test_mps2_build: host
	@echo TEST out/mps2/love.elf '(build)'
	@$(MAKE) -C inle/mps2 || { echo "FAIL mps2 build"; exit 1; }
test_virt_build: host
	@echo TEST out/virt/love.elf '(build)'
	@$(MAKE) -C inle/virt || { echo "FAIL virt build"; exit 1; }
# test_links -- every distinct link topology, compiled and linked, nothing run. a seat
# change breaks LINKS, and a link is the cheapest question this tree asks; playdate keeps
# its own roster, so it is the one that goes missing. rides both slow tiers -- in test_extra
# it stands for the four build-only board rows, being test_boards and more.
# and the lay law over what an OS loader maps: test/gate/lay.l, which needs no kernel to ask
# it -- the kernels and boards above are placed by something that is not a loader.
.PHONY: test_links
test_links: host $(ho)/front $(ho)/frontseat $(love0)
	@$(MAKE) -s $(ko)/love-x64.elf
	@$(MAKE) -s a=a64 $(ko)/love-a64.elf
	@$(MAKE) -s a=rv64 $(ko)/love-rv64.elf
	@$(MAKE) -s a=wasm $(ko)/love.wasm
	@$(MAKE) -s test_boards
	@$m test/gate/lay.l $(ho)/love $(ho)/front $(ho)/frontseat || { echo "FAIL lay"; exit 1; }
	@echo "test_links: hosted, bootstrap, front and its seat-horn twin, the wasm machine, three kernels, six boards"

# the userland packages: each built by mooncc + moonlibc + the holo linker -- no gcc/glibc/ld
# anywhere -- then run and held to the package's own answers: tar 1.13 roundtrips and
# system-tar interop, m4 1.4's 57-check suite, lua 5.4's battery, sqlite's amalgamation + VFS.
# opt-in: point the package's SRC var at a prepared tree and each script skips without one.
# a cross lane puts a qemu wrapper on PATH so a suite that execs by name runs unmodified;
# riscv routes around faults the other two share (nhome = 0), so it is not redundant.
# /warn the sqlite cross lanes wait on moon-sqlite: they read its x86-64 answers as the oracle.
moon_arch_a64 = a64
moon_arch_rv64 = rv64
# $1 package, $2 its source-tree var, $3 what the two cross lanes wait on
define moon_pkg
moon-$1: host
moon-$1-a64 moon-$1-rv64: $3
moon-$1 moon-$1-a64 moon-$1-rv64:
	@$2="$$($2)" ./u/moon-$1.sh $$(moon_arch_$$(patsubst moon-$1-%,%,$$@))
endef
$(eval $(call moon_pkg,tar,TARSRC,host))
$(eval $(call moon_pkg,m4,M4SRC,host))
$(eval $(call moon_pkg,lua,LUASRC,host))
$(eval $(call moon_pkg,sqlite,SQLSRC,moon-sqlite))
$(eval $(call moon_pkg,gzip,GZIPSRC,host))
$(eval $(call moon_pkg,bzip2,BZIP2SRC,host))
# test_distboot -- the release claim: take either artifact, type make, get the same binary.
# source bootstraps through the machine's cc; seed lays the source it carries in .rodata and
# builds it with cc/gcc/clang shadowed by scripts that fail loudly, so "no ambient compiler
# did the work" is proved. then the circle: `love seed` with nothing on PATH that compiles,
# taking its own mooncc. the claim holds because the local cc builds love0 and nothing else.
# three full builds and still NOT a superset of test_seed -- no leg here runs a default
# `love seed`, so the deference decision goes untested. minutes, opt-in, by name.
# test_bakerep -- A bake is a function OF the tree. Seconds, and it rides the slow gate
# because test_distboot proves the same law over the whole circle but is opt-in and
# minutes long; a regression would otherwise wait for a release to surface.
test_bakerep: host
	@echo TEST test/gate/bakerep.sh
	@sh test/gate/bakerep.sh $(ho)
test_distboot: dist
	@echo TEST test/gate/distboot.sh
	@sh test/gate/distboot.sh $(dist_source) $(ho)/love
# test_gz -- apps/tar.l + apps/gz.l against the two programs they replace. the laws
# are test/host/gz.l; this is the half only the OUTSIDE can say, and it is separate because
# a coder and decoder by one hand round-trip cleanly through a format nobody else speaks.
# skips without either system tool. gzfind.l rides along: the differential between gz.l's
# match finder and the holo IR beside it, over corpora chosen for the chain the kernel walks.
test_gz: host
	@echo TEST test/gate/gzfind.l
	@$m $R/test/gate/gzfind.l
	@echo TEST test/gate/targz.sh
	@sh test/gate/targz.sh $(ho)/love
# test_root -- the privileged verbs: chroot, mount, umount, sync, mkfifo, mknod. the
# refusals as an ordinary user, then test/gate/rootns.l, which makes itself root in an
# unprivileged user namespace and does the REAL thing -- tmpfs mounted, a bind showing the
# other tree, both unmounted, a chroot with a command inside. a gate that only watched these
# answer 'eperm would pass against a stub. a kernel with user namespaces off skips the second
# half and stays green: a machine's policy, not a fault in the code.
test_root: host
	@echo TEST test/gate/root.sh
	@sh test/gate/root.sh $(ho) $(ho)/love
# test_fat32 -- `love fat` + `love mkfs.vfat`, the command line over apps/fat.l.
# not test_fat, which gates the fat container (seed-universal U1) and shares only a
# word. test/fat.l proves the filesystem's own laws over a cask, needing nothing
# outside; this is the half only another implementation can say, and mtools is it --
# their reader on our format, our reader on theirs, and our reader on an mformat image.
# Skips the interop half where mtools is missing; the verbs still run.
test_fat32: host
	@echo TEST test/gate/fat32.sh
	@sh test/gate/fat32.sh $(ho) $(ho)/love
# test_cpio -- apps/cpio.l's wire + its face against GNU cpio, both ways over newc. Separate
# from test_gz for the same reason test_gz is separate from the laws: the system tool
# is the only oracle that can catch a format two of our own functions agree on. This
# is the wire `make distro-initramfs` cuts its image with.
test_cpio: host
	@echo TEST test/gate/cpio.sh
	@sh test/gate/cpio.sh $(ho)/love
# The neutral assembler (love/holo/) + its x86-64 backend: every encoder golden is
# objdump-checked (test/holo/golden.l). a host-only app -- it adds no nif and is not
# baked into love0. The sources are cat'd in because the host bakes its native backend
# only; the other four reach the gate no other way. Gate = exit 0 and the "N passed,
# 0 failed" sentinel.
test_holo: host
	@echo TEST test/holo/golden.l
	@cat love/holo/holo.l love/holo/x64.l love/holo/a64.l love/holo/thumb2.l \
	    love/holo/rv64.l love/holo/thumb1.l love/holo/text.l love/holo/dialect.l love/holo/gas.l love/holo/elf.l \
	    love/holo/wasm.l love/holo/wasmfn.l test/holo/golden.l | sh test/gate/run.sh holo "$m" ", 0 failed"
# as.l -- the real x86-64 front over holo, either dialect through dialect.l's lens
# (dialect.sh judges it against gcc's two outputs, skipping without gcc), and decode.l reads
# the bytes back (decode.sh judges it against objdump). test/holo/as.l's goldens are
# byte-identical to /usr/bin/as, frozen, no shell-out at gate time. same sentinel gate as
# test_holo; asrefuse.sh is the other half, what must raise, one love per case.
test_as: host
	@echo TEST test/holo/as.l
	@cat love/holo/holo.l love/holo/x64.l love/holo/dialect.l love/holo/decode.l love/holo/as.l test/holo/as.l \
	  | sh test/gate/run.sh as "$m" ", 0 failed"
	@sh test/gate/asrefuse.sh "$m"
	@sh test/gate/dialect.sh "$m" $(ho)
	@sh test/gate/decode.sh "$m" $(ho)
# test_elf32 -- holo's ELF32 executable writer, judged by a real loader: both thumb backends
# lay write+exit, Linux maps the segment and enters in Thumb state, and 42 must come back.
# test/holo/golden.l pins the header fields; this pins the only opinion that counts. Needs qemu-arm
# and nothing else -- no as, no ld, no arm-none-eabi -- so it runs where the thumb gates skip.
test_elf32: host
	@sh test/gate/elf32.sh $(ho)
# test_objcopy -- love/holo/copy.l, the flatten, against the objcopy it replaces: a BYTE
# comparison of both output formats over fixtures our own linker mints plus every ELF on
# hand. Intel HEX is a wire (a Teensy loader reads it), so nothing softer would do. The
# gate skips where no objcopy exists -- see the script for what the fixtures are for.
test_objcopy: host
	@sh test/gate/objcopy.sh $(ho)
# ain's two-process loopback gate: a server and a client over real TCP on 127.0.0.1,
# full-duplex, each asserting it got what the other sent. The only net gate driving the real
# `love apps/ain.l` cli path. In test_slow; override the port with `make nettest PORT=N`.
PORT ?= 7390
nettest: host
	@echo TEST $m "(127.0.0.1:$(PORT))"
	@sh $R/test/net/loopback.sh $m $(PORT)
# The tool gates beside the build: the hue generators, cook, tele. See tools/Makefile.
# vmret is not here -- it rides test_slow over $m, and after plan C2 every other love in
# the tree is a projection of that one. lush is a real
# prerequisite: test/host/cook.l's SHELL pair sets `SHELL := out/lush` to prove cook honors it.
test_tools: host out$(hsuf)/lush
	@$(MAKE) -C tools
# test_gcheck: the copy loop's fixpoint instance check. LvGcCheck makes gen_minor re-drive
# its whole scan after the drain and trap if the second pass copies a word, in its own tree.
# /warn the knob is GCDBG: EXTRA_CFLAGS rides $(ai_cflags), which the mooncc recipes do not use.
# the shared unsuffixed prerequisites are named here so the parent makes them once.
# both debug lanes recurse, and a target two sub-makes each decide to remake is a partial
# file to whoever reads it meanwhile -- a half-written mooncc0.image wakes with no verb
# table and `mooncc` then reads as a filename (the Makefile). test_fixpoint names them
# for the same reason.
test_gcheck: host $(love0) out/mooncc0.image
	@$(MAKE) --no-print-directory hsuf=/gck GCDBG=-DLvGcCheck test_host
	@$(MAKE) --no-print-directory hsuf=/gck GCDBG=-DLvGcCheck test_hostegg
# test_gcstress: the mutator's side -- whether the C around the collector holds a raw pointer
# across a call that collects. LvGcStress always collects, poisons the vacated nursery, and
# majors every 32nd. ~12 min, own tree -- the baked leg tracks the glaze, since every major
# walks it, and costs 3.4x the egg one for it (429 s against 126 s).
test_gcstress: host $(love0) out/mooncc0.image
	@$(MAKE) --no-print-directory hsuf=/gcs GCDBG=-DLvGcStress test_host
	@$(MAKE) --no-print-directory hsuf=/gcs GCDBG=-DLvGcStress test_hostegg
# --- the machine-checked half: test/proof/rocq/ + test/proof/lean/ ---------------------------------
# Each gate below is a no-op that says so when its checker is missing, so a bare box stays
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
# theorems, axiom-free and universe-checked: the executable spec upgraded from shown to proved.
# spec.vo is a file target, compiled once and kept: test_gen and test_extract both `Require
# Import spec`. /warn one spelling everywhere (`cd test/proof/rocq && -R . ""`), or spec.vo's logical
# name is not the one gen.v asks for. a static pattern: big/mx/enc take their own flags.
rocq_kept = test/proof/rocq/spec.vo test/proof/rocq/patch.vo
$(rocq_kept): test/proof/rocq/%.vo: test/proof/rocq/%.v
	@echo TEST test/proof/rocq/$*.v "(coqc)"
	@cd test/proof/rocq && $(COQC) -q -R . "" $*.v
test_proof: $(rocq_kept)
	@echo "test_proof: spec.v + patch.v check (the .vo IS the evidence, so a re-run is quiet)"
# gc.v -- the generational minor is sound (under a complete write barrier no live young is
# lost), its pause is bounded by the nursery, and the Cheney drain terminates as a true
# fixpoint. Axiom-free; test_gcheck instance-checks the drain.
test_gc:
	@echo TEST test/proof/rocq/gc.v "(coqc)"
	@$(COQC) -q test/proof/rocq/gc.v
	@$(call vclean,gc)
# The .l -> .v pipeline: tools/spec2coq.l reads test/spec.l and emits gen.v, the spec generating
# theorems for its own numeral facts. Regenerated every run, so asserts and proofs cannot diverge.
test_gen: host $(rocq_kept)
	@echo 'LOVE	'test/proof/rocq/gen.v "(tools/spec2coq.l on $m)"
	@$m tools/spec2coq.l > test/proof/rocq/gen.v
	@echo TEST test/proof/rocq/gen.v "(coqc, against spec.v's shared model)"
	@cd test/proof/rocq && $(COQC) -R . "" gen.v
	@$(call vclean,gen)
# The proof half of that pipeline (cf. test_gen, which exports concrete ASSERTS): tools/uu2coq.l
# has uu's kernel type-check a proof term and emits the same term in Gallina for coqc to re-check
# -- a law proved in love's own kernel and certified by Rocq.
test_uugen: host
	@echo 'LOVE	'test/proof/rocq/uugen.v "(tools/uu2coq.l on $m)"
	@$m tools/uu2coq.l > test/proof/rocq/uugen.v
	@echo TEST test/proof/rocq/uugen.v "(coqc)"
	@$(COQC) -q test/proof/rocq/uugen.v
	@$(call vclean,uugen)
# love/mx.l is the +/* dispatch matrices; love/mx.h is laid from it through clay and tools/mx2coq.l models
# it in Rocq -- two derivations of one datum.
test_mx: host
	@echo TEST test/proof/rocq/mx.v "(the dispatch matrices: band factorization + dispatch commutativity, coqc)"
	@cat love/mx.l tools/mx2coq.l | $m > test/proof/rocq/mx.v
	@cd test/proof/rocq && $(COQC) -q mx.v >/dev/null
	@$(call vclean,mx)
endif

ifeq ($(and $(COQC),$(OCAMLOPT)),)
test_extract test_big test_encver:
	@echo "$@: skipped (needs coqc + ocamlopt)"
else
# extract.v's normalizer (on spec.v's PROVEN subst/shift) extracted to OCaml and fuzzed against
# ev. /warn run the oracle once, into a file (2>&1 too): grep it, then cat it -- a second run
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
# binary Z with the codec; big_drive.ml emits decimal comparisons -- love's reader, limbs and
# printer against it.
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
# the prove rung of the holo encoder ladder: reference x86-64 encoders each proving decode
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
	   { cat love/holo/holo.l love/holo/x64.l; echo "(borrow 'holo)"; cat $$o.l; } | $m > $$o.out 2>&1; r=$$?; \
	   { [ $$r -eq 0 ] && grep -q "$$c / $$c PASS" $$o.out; } \
	     || { echo "FAIL the $$n oracle, $$l (exit $$r):"; cat $$o.out; exit 1; }; \
	   cat $$o.out; done
	@$(call vclean,enc encmem encli)
	@$(call dclean,enc encmem encli)
	@rm -f test/proof/rocq/*.cmi test/proof/rocq/*.cmx test/proof/rocq/*.o out/.enc_oracle.* out/.encmem_oracle.* out/.encli_oracle.*
endif

# the lean leg of the proof bridge (cf. test_uugen, the Rocq leg): tools/uu2lean.l emits the same
# uu corpus to Lean 4, which re-checks it -- a second independent kernel, so each law is agreed
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

# the fuzz-first rung of the holo encoder ladder (test/holo/fuzz/): random IR encoded via
# holo, disassembled (objdump for x64, llvm-mc elsewhere), decode checked against intent.
# fuzz.l skips a lane whose disassembler is absent, exits 1 on any disagreement. sysdiff.l
# rides it for the system ops off holo's own a64.l tables, and rvc.l sweeps the riscv C
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
# the committed generated corpora, one shape four times over: a design's own code
# compiled into uu terms, so the matching *law.l proves its theorems OF the
# implementation at corpus time and not of a transcription somebody keeps by hand.
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
#   uukind    the abstract kinds-lattice join         -> test/uukindlaw.l, the semilattice laws
#   uuhomgen  dest.l's two code generators, on its law sites -> test/uuhomlaw.l, the destination-die laws
#   uusplgen  spl.l's three call-site compilers (call, binding splice, substitution
#             splice) on its samples                  -> test/uuspllaw.l, the splice license
#   uumx      love.c's +/* dispatch matrices (love/mx.l) -> test/uumxlaw.l, the band lattice
#   uuvallaw  CLAUDE.md's laws off test/law.l's own rows -> proved where they stand, one
#             spelling for the fuzz lane and the proof lane both
$(eval $(call uu_corpus,uuwm,uuwmgen,apps/lux/core.l))
$(eval $(call uu_corpus,uukind,kinds2uu,test/proto/kinds.l))
$(eval $(call uu_corpus,uuhomgen,dest2uu,test/proto/dest.l))
$(eval $(call uu_corpus,uusplgen,spl2uu,test/proto/spl.l))
$(eval $(call uu_corpus,uumx,mx2uu,love/mx.l))
$(eval $(call uu_corpus,uuvallaw,law2uu,test/law.l))
# test_wake: the bake-then-wake round trip, which no other gate runs -- every other lane
# wakes an image some earlier recipe baked. a candidate copy bakes (love.wake, ETXTBSY-proof)
# under a timeout the wake storm cannot meet: a fresh lane checks uu in ~1s, a storming one
# takes >90s, so the clock is the whole assertion.
test_wake: $(ho)/love
	@echo TEST wake "(the woken-image lane)"
	@cp $(ho)/love $(ho)/love.wake && $(ho)/love.wake bake
	@# ..and that it woke AT ALL. a refused image is not an error: love boots the egg
	@# instead, which is a correct boot of a smaller vocabulary -- same answers, no
	@# crew, and fast enough that the clock below cannot tell. the crew is the tell.
	@if ! $(ho)/love.wake -q -e "(quit (nil? (cite 'cook)))"; \
	  then echo "test_wake: the baked image was REFUSED -- this is an egg boot"; \
	       rm -f $(ho)/love.wake; exit 1; fi
	@cat test/00-init.l test/uu.l > $(ho)/wake-corpus.l
	@if timeout 60 $(ho)/love.wake $(ho)/wake-corpus.l > /dev/null 2>&1; \
	  then echo "test_wake: green (the woken image checks uu at speed)"; rm -f $(ho)/love.wake $(ho)/wake-corpus.l; \
	  else echo "test_wake: FAILED -- the woken image storms"; rm -f $(ho)/love.wake $(ho)/wake-corpus.l; exit 1; fi

# --- the metal gates: what boots, and where ---------------------------
# The kernel build rules and the `run`/`uefi` verbs stay in the root Makefile;
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

# doom in an X window, the doom=1 build under an Xvfb (apps/doom.l): opt-in --
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
	@$m $(R)/tools/kboot.l $(k_elf) "kore ls /proc/src/apps/kore" "kore.l"
	@$m $(R)/tools/kboot.l $(k_elf) "kore wc /proc/src/apps/json.l" "/proc/src/apps/json.l" $$(wc -c < $(R)/apps/json.l)
	@$m $(R)/tools/kboot.l $(k_elf) "sh -c \"cd /proc/src/apps/kore; pwd\"" "/proc/src/apps/kore"
	@$m $(R)/tools/kboot.l $(k_elf) "sh -c \"kore ls /proc/src/apps/kore | kore wc -l\"" $$(ls $(R)/apps/kore | wc -l)
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
	@$(MAKE) -s test_kernel_wasm
	@echo "test_inle: boot, disk, command line, firmware -- the three arches and the wasm seat"

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
# INLE_RAM: cpu.mjs grows the memory once at boot and hands kmain that fixed span, so the
# seat's room is a number here, not a policy. 256 (the default) is short of the corpus: the
# collector's doubling asks 4480156 words and the grow refuses, at the same length whichever
# member is running, the live set being what crossed the line.
# test_kernel_wasm -- the wasm inle seat (out/love.wasm) under node: the image baked
# (the egg lane, `bake PATH` on the boot line), then the kernel corpus off the ramfs on the
# woken image, the serial line captured, the (reset) that ends it read as the exit -- what
# tools/ktest.l reads off qemu, with no qemu and no browser.
ifeq ($(NODE),)
test_kernel_wasm:
	@echo "test_kernel_wasm: skipped (needs node)"
else
test_kernel_wasm: host
	@$(MAKE) -s wasm
	@echo TEST out/love.wasm "(node: the kernel corpus on the woken image, serial, headless)"
	@INLE_RAM=768 $(NODE) $(R)/inle/wasm/inle.mjs --image $(ko)/wasm/love.image $(R)/$(ko)/love.wasm test/kernel/all.l \
	   < /dev/null > $(ko)/wasm/kernel.log 2>&1; \
	 grep -q "image awake" $(ko)/wasm/kernel.log \
	   && grep -q "tests pass" $(ko)/wasm/kernel.log && ! grep -q "failed:" $(ko)/wasm/kernel.log \
	   && ! grep -q "^0 tests pass" $(ko)/wasm/kernel.log \
	   || { tail -20 $(ko)/wasm/kernel.log; echo "FAIL test_kernel_wasm"; exit 1; }
	@grep "tests pass" $(ko)/wasm/kernel.log
	@echo TEST test/kernel/glass.l "(the console's grid, and its text across a re-made one)"
	@sh $(R)/test/gate/glass.sh $(NODE) $(R)/out/love.wasm out/wasm/love.image out/wasm/glass.log $m
	@echo TEST test/gate/glass.mjs "(the page's half of the grid, asked without a page)"
	@$(NODE) $(R)/test/gate/glass.mjs || { echo "FAIL test_kernel_wasm"; exit 1; }
	@echo TEST test/gate/worklet.mjs "(the page's speaker, asked without a page)"
	@$(NODE) $(R)/test/gate/worklet.mjs || { echo "FAIL test_kernel_wasm"; exit 1; }
	@echo TEST test/gate/idle.mjs "(the machine still sleeps once it has been typed at)"
	@$(NODE) $(R)/test/gate/idle.mjs $(R)/out/love.wasm out/wasm/love.image out/wasm/idle.log \
	   || { tail -5 out/wasm/idle.log; echo "FAIL test_kernel_wasm"; exit 1; }
	@echo TEST test/kernel/horn.l "(the horn: a ramp through the port and out of the machine)"
	@INLE_RAM=256 $(NODE) $(R)/inle/wasm/inle.mjs --horn out/wasm/horn.raw --image out/wasm/love.image \
	   $(R)/out/love.wasm test/kernel/horn.l < /dev/null > out/wasm/horn.log 2>&1; \
	 grep -q "horn wrote 80000" out/wasm/horn.log \
	   || { tail -20 out/wasm/horn.log; echo "FAIL test_kernel_wasm (the horn refused the machine)"; exit 1; }
	@$m $(R)/test/gate/horn.l out/wasm/horn.raw || { echo "FAIL test_kernel_wasm"; exit 1; }
	@echo TEST "the fetch door (wget aboard, off --origin, the tree standing in for the page)"
	@INLE_RAM=256 $(NODE) $(R)/inle/wasm/inle.mjs --origin $(R) --image out/wasm/love.image $(R)/out/love.wasm \
	   sh -c 'mkdir -p /s; wget -O /s/v /VERSION && cmp /s/v /proc/src/VERSION && echo fetch: ok; wget -q -O /s/no /no-such-file; echo missing: $$?' \
	   < /dev/null > out/wasm/fetch.log 2>&1; \
	 grep -q "fetch: ok" out/wasm/fetch.log && grep -q "missing: 4" out/wasm/fetch.log \
	   || { tail -8 out/wasm/fetch.log; echo "FAIL test_kernel_wasm (the fetch door)"; exit 1; }
	@echo TEST test/kernel/horn.l "(--deaf: the machine outlives a speaker that stopped taking)"
	@timeout 120 $(NODE) $(R)/inle/wasm/inle.mjs --deaf --image out/wasm/love.image \
	   $(R)/out/love.wasm test/kernel/horn.l < /dev/null > out/wasm/deaf.log 2>&1; \
	 grep -q "horn wrote 80000" out/wasm/deaf.log \
	   || { tail -5 out/wasm/deaf.log; echo "FAIL test_kernel_wasm (a dead speaker stopped the machine)"; exit 1; }
	@echo "  deaf: ok -- the ring fills, nobody empties it, and the walk goes on"
	@echo TEST test/kernel/lift.l "(the lift: a path written to /proc/lift, and the file lands outside)"
	@rm -f lifted.txt out/wasm/lifted.txt; INLE_RAM=256 $(NODE) $(R)/inle/wasm/inle.mjs --image out/wasm/love.image \
	   $(R)/out/love.wasm test/kernel/lift.l < /dev/null > out/wasm/lift.log 2>&1; \
	 mv -f lifted.txt out/wasm/lifted.txt 2>/dev/null; \
	 grep -q "lift asked" out/wasm/lift.log && grep -q "carried out of the machine, whole" out/wasm/lifted.txt \
	   || { tail -5 out/wasm/lift.log; echo "FAIL test_kernel_wasm (the lift did not land)"; exit 1; }
	@echo "  lift: ok -- the file came out under its own name"
	@echo TEST test/kernel/pkcheck.l "(harp's pack: the two arms answer the same bytes HERE)"
	@$(NODE) $(R)/inle/wasm/inle.mjs --image out/wasm/love.image $(R)/out/love.wasm \
	   test/kernel/pkcheck.l < /dev/null > out/wasm/pack.log 2>&1; \
	 grep -q "gain 20000     1" out/wasm/pack.log && grep -q "gain 900000    1" out/wasm/pack.log \
	   && grep -q "gain 100       1" out/wasm/pack.log \
	   || { cat out/wasm/pack.log; echo "FAIL test_kernel_wasm (pack differs on this seat)"; exit 1; }
	@echo "  pack: ok -- pinv and the byte loop agree where the float-to-int is not the host's"
endif

# doom on the wasm seat (inle/doom.c's kernel doors under the module): opt-in for the same
# reason. the game boots off doomrun.l, draws into the framebuffer and plays through
# the horn, and is quit from its own menu over the scan lane -- Escape, up to QUIT GAME,
# Enter, y -- which is the keys proven make and break: exit() aboard is the reset, and the
# reset ends the run, where a game that never heard the keys outruns --for.
# DOOM=1 is its own tree (common.mk's hsuf), so the flavour is named where it lands:
# out/doom is what the sub-make built, and out/ beside it is the plain seat kexec boots.
ifeq ($(NODE),)
test_doomwasm:
	@echo "test_doomwasm: skipped (needs node)"
else
test_doomwasm:
	@$(MAKE) -s wasm DOOM=1
	@echo TEST test/kernel/doomrun.l "(doom on the wasm seat: a frame, the horn, and quit by key)"
	@rm -f out/wasm/doom.ppm out/wasm/doom.raw
	@INLE_RAM=512 $(NODE) $(R)/inle/wasm/inle.mjs --fb 640x400 --dump out/wasm/doom.ppm --horn out/wasm/doom.raw \
	   --after 12 --press "Escape ArrowUp Enter KeyY" --for 60 \
	   --image out/doom/wasm/love.image $(R)/out/doom/love.wasm test/kernel/doomrun.l \
	   < /dev/null > out/wasm/doom.log 2>&1 \
	 && grep -q "I_InitGraphics: DOOM screen size" out/wasm/doom.log \
	 && grep -q "doomsnd: the horn is open" out/wasm/doom.log \
	 && test -s out/wasm/doom.ppm && test -s out/wasm/doom.raw \
	   || { tail -20 out/wasm/doom.log; echo "FAIL test_doomwasm"; exit 1; }
	@echo "  doomwasm: ok -- drew, sounded, and quit from the menu"
	@rm -rf out/wasm/origin && mkdir -p out/wasm/origin && cp out/doom/love.wasm out/wasm/origin/doom.wasm
	@$(MAKE) -s wasm
	@echo TEST test/kernel/kexec.l "(the machine fetches the doom module off its origin and boots it in place of itself)"
	@rm -f out/wasm/kexec.ppm
	@INLE_RAM=512 $(NODE) $(R)/inle/wasm/inle.mjs --fb 640x400 --dump out/wasm/kexec.ppm --origin out/wasm/origin \
	   --after "I_InitGraphics: Auto-scaling" --press "Escape ArrowUp Enter KeyY" --for 300 \
	   --image out/wasm/love.image $(R)/out/love.wasm test/kernel/kexec.l \
	   < /dev/null > out/wasm/kexec.log 2>&1 \
	 && grep -q "inle: booting /d.wasm" out/wasm/kexec.log \
	 && grep -q "I_InitGraphics: DOOM screen size" out/wasm/kexec.log \
	 && grep -q "doom-rc=0" out/wasm/kexec.log && test -s out/wasm/kexec.ppm \
	   || { tail -20 out/wasm/kexec.log; echo "FAIL test_doomwasm (kexec)"; exit 1; }
	@echo "  kexec: ok -- fetched, booted, drawn, and quit"
endif

# test_seedwasm -- `love seed x64` ON THE WASM SEAT: the machine lays the source it
# carries, drives cook with the artifact itself as the bootstrap (LOVE=, so no love0 is
# compiled -- there is no seat here to run one) and cross-builds a hosted x64 love with
# its own mooncc. nothing under it but wasm: no cc, no shell, no toolchain. the lift
# brings the egg out and, on an x64 box, it has to run.
# RAM: the seat's collector is bounded at an eighth of the machine (inle/kmain.c), so the
# machine has to be big enough that an eighth of it holds the largest live set. that is
# selfpack's, laying the dist tarball: 512 ooms there, 768 carries it, and this is the
# round number above. ~6 minutes. opt-in by name -- the compile set is the whole
# artifact, interpreted.
ifeq ($(NODE),)
test_seedwasm:
	@echo "test_seedwasm: skipped (needs node)"
else
test_seedwasm: host
	@$(MAKE) -s wasm
	@echo TEST "love seed x64 (the wasm seat, nothing under it)"
	@rm -f out/wasm/love-x64
	@INLE_RAM=1024 $(NODE) $(R)/inle/wasm/inle.mjs --lift /s/love-x64:out/wasm/love-x64 \
	   --image out/wasm/love.image $(R)/out/love.wasm seed x64 /s \
	   < /dev/null > out/wasm/seed.log 2>&1; \
	 grep -q "a raw egg for x64" out/wasm/seed.log && test -s out/wasm/love-x64 \
	   || { tail -20 out/wasm/seed.log; echo "FAIL test_seedwasm"; exit 1; }
	@chmod +x out/wasm/love-x64
	@$(if $(filter x64,$(hosta)),out/wasm/love-x64 -v,echo "  the egg is x64 and this box is $(hosta): laid, not run")
endif

# test_nestwasm -- the artifact rebuilds its own wasm MODULE aboard the wasm seat: the
# source laid off the carried tarball, cook driven with the kernel as the toolchain
# (LOVE=love on cook's line: a task shares no environment with its spawner there), and
# the link under the seat's collector budget -- what `love web` and `love doom` do on the
# page. ~15 minutes, opt-in by name.
ifeq ($(NODE),)
test_nestwasm:
	@echo "test_nestwasm: skipped (needs node)"
else
test_nestwasm:
	@$(MAKE) -s wasm
	@echo TEST test/kernel/nest.l "(the wasm module rebuilt aboard the wasm seat)"
	@INLE_RAM=1024 $(NODE) $(R)/inle/wasm/inle.mjs --for 2400 \
	   --image out/wasm/love.image $(R)/out/love.wasm test/kernel/nest.l \
	   < /dev/null > out/wasm/nest.log 2>&1; \
	 grep -q "nest: cook wasm answered 0, the module stands" out/wasm/nest.log \
	   || { tail -20 out/wasm/nest.log; echo "FAIL test_nestwasm"; exit 1; }
	@echo "  nestwasm: ok -- laid, built and linked aboard"
endif

# the wasm module writer and the IR lowering (love/holo/wasm.l) under a foreign engine, and
# the fuzz beside it -- the one backend with NO reader in the tree and no disassembler on
# most boxes, so v8 is the second opinion and the model in the fuzz file is the intent:
# love lays three modules (the writer's by hand, the program's off holo IR, a mock of the
# artifact's face), binaryen validates them where the box has one, node instantiates and
# runs them -- the third through inle/wasm/loader.js, the artifact's own environment.
# skips without node.
WASMOPT ?= $(shell command -v wasm-opt 2>/dev/null)
wasmopt_flags = --enable-memory64 --enable-bulk-memory --enable-nontrapping-float-to-int
holo_wasm = out/.holo.wasm out/.holo2.wasm out/.holo3.wasm
ifeq ($(NODE),)
test_holowasm:
	@echo "test_holowasm: skipped (needs node)"
else
test_holowasm: host
	@echo TEST test/holo/wasm.l
	@cat love/holo/holo.l love/holo/wasm.l love/holo/wasmfn.l test/holo/wasm.l | $m
	@$(if $(WASMOPT),for w in $(holo_wasm); do $(WASMOPT) $(wasmopt_flags) $$w -o /dev/null 2>/dev/null || exit 1; done && echo "  wasm-opt: all valid",echo "  wasm-opt: absent, node alone validates")
	@$(NODE) test/holo/wasm.mjs out/.holo.wasm out/.holo2.wasm
	@$(NODE) test/holo/loader.mjs out/.holo3.wasm
	@echo TEST test/holo/fuzz/wasm.l "(the wasm lane's second opinion: v8 against the model)"
	@cat love/holo/holo.l love/holo/wasm.l love/holo/wasmfn.l test/holo/fuzz/wasm.l | $m
	@$(NODE) test/holo/fuzz/wasm.mjs out/.wasmfuzz.wasm out/.wasmfuzz.json
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
