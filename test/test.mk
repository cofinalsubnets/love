# test/test.mk -- the test_* gates, included by ./Makefile; paths resolve from the root

# every gate is phony: one missing here stops running once a file of its name appears
.PHONY: \
  moon-bzip2 moon-bzip2-a64 moon-bzip2-rv64 moon-gzip moon-gzip-a64 moon-gzip-rv64 \
  moon-bison moon-flex moon-lua moon-lua-a64 moon-lua-rv64 moon-m4 moon-m4-a64 moon-m4-rv64 moon-sqlite \
  moon-sqlite-a64 moon-sqlite-rv64 moon-tar moon-tar-a64 moon-tar-rv64 mx nettest test \
  test_as test_asmops test_bakerep test_big test_boards test_cca64 test_cci386 test_ccarm test_ccrv64 test_ccwasm test_ccthumb1 \
  test_ccthumb2 test_ccport test_clay test_cli test_nest test_cookdiff test_cpio test_cts test_cts_a64 \
  test_cts_rv64 test_cts_wasm test_disk test_dist test_distboot test_doc test_drat test_drv test_dtb test_ffalloc \
  test_elf32 test_encver test_extra test_extract test_fat test_fat32 test_filemode test_fixpoint \
  test_forge test_freebsd test_freebsd_a64 test_freebsd_rv64 test_front test_gc test_gcheck test_gcstress test_gcstress_full \
  test_gates test_gen test_glaze test_glazebench test_glazefuzz test_gz test_standalone test_harp test_hearts test_hearts_boot test_sqfs test_ext4 test_hdiff test_ccwarn test_holo test_holofuzz test_holowasm test_hook \
  test_host test_hostegg test_hostnif test_inle test_kboot test_kmitty test_kernel_a64 test_kernel_rv64 test_kernel_vmx test_kernel_wasm test_kore \
  test_kverb test_libc test_love0 test_lux test_moon test_moonfuzz test_mps2 test_mps2_t1 \
  test_mps2_build test_mps2_wake test_mx test_netbsd test_netbsd_a64 test_netbsd_rv64 test_nucleo446 test_nucleo446_smoke \
  test_objcopy test_playdate test_proof test_quick test_raw test_raw_a64 test_raw_bake test_raw_rv64 test_love_a64 \
  test_refuzz test_reloc32 test_root test_rp2040 test_rvboot test_sat test_sb test_seat test_seed \
  test_doomwasm test_nestwasm test_seedwasm test_selfhost test_slow test_softfp test_spin test_stdinbuf test_stdincorpus test_tco0 test_teensy41 test_thumb1 \
  test_thumb2 test_thumb2sp test_tools test_uefi test_uefi_a64 test_ulp test_uugen \
  test_uuhomgen test_uukind test_uulean test_uumx test_uusplgen test_uuvallaw test_uuwm \
  test_vec test_vi test_virt test_virt_build test_wake test_walkroom test_hashrun test_xfixpoint uuhomgen uukind uumx uusplgen \
  uuvallaw uuwm vmret waits test_doomx test_doomx-run test_doomwasm-run test_gcstress_bake test_kernel_uproc test_web test_wgetnet

# the three gates: test (fast), test_slow (merge), test_extra (qemu, cross-arch, boards)
test_phases = test_host test_love0
test:
	@$(MAKE) --no-print-directory $(test_phases)

test_slow: test_host test_love0 vmret test_bakerep test_stdinbuf test_stdincorpus test_seat test_cli test_nest test_spin test_cookdiff test_glazebench test_dist test_seed test_moon test_as test_links test_kernel_wasm test_harp

# the core's gate: test_extra's local, unheavy lanes, about a minute
test_quick: test_filemode test_walkroom test_hashrun waits test_front test_proof test_gen test_uugen test_uulean test_uuwm test_uukind \
	test_gc test_extract test_big test_mx test_tools test_web test_doc test_glaze test_hook test_sat \
	test_holo test_holowasm test_as test_glazefuzz test_encver test_refuzz test_vi test_clay \
	test_moonfuzz test_forge test_gates test_cts test_libc test_ulp test_softfp test_reloc32 \
	test_drv test_wake test_gz test_standalone test_sqfs test_ext4 test_cpio \
	test_fat32 test_root test_uuhomgen test_uusplgen test_uumx test_uuvallaw test_raw_bake test_drat \
	test_asmops test_dtb test_ffalloc test_elf32 test_objcopy test_fat test_cci386 test_ccarm test_ccthumb1 test_ccthumb2 \
	test_cts_rv64 test_cts_wasm test_thumb1 test_thumb2 test_thumb2sp

test_extra: test_filemode waits test_front test_proof test_gen test_uugen test_uulean test_uuwm \
	test_uukind test_gc test_gcheck test_gcstress test_extract test_big test_mx \
	test_tools test_web test_hostnif test_doc test_glaze test_hook test_sat test_holo test_holowasm test_as \
	test_holofuzz test_glazefuzz test_encver test_kore test_refuzz test_sb test_vi \
	test_clay test_moonfuzz test_forge test_gates test_kernel_vmx \
	test_cts test_libc test_ulp test_softfp test_reloc32 \
	test_drv test_hdiff test_ccwarn test_tco0 nettest test_wake test_gz test_standalone test_sqfs test_ext4 test_cpio test_fat32 test_root \
	test_uuhomgen test_uusplgen test_uumx test_uuvallaw \
	test_fixpoint test_xfixpoint test_raw_bake test_drat test_vec \
	test_asmops test_dtb test_ffalloc test_rvboot test_elf32 test_objcopy test_distboot test_fat \
	test_cca64 test_cci386 test_ccarm test_ccrv64 test_ccwasm test_ccthumb1 test_ccthumb2 test_ccport test_cts_a64 test_cts_rv64 test_cts_wasm \
	test_raw_a64 test_raw_rv64 test_love_a64 \
	test_virt test_thumb1 test_thumb2 test_thumb2sp \
	test_mps2 test_mps2_t1 test_mps2_wake test_nucleo446_smoke test_links \
	test_freebsd test_netbsd test_freebsd_a64 test_netbsd_a64 test_freebsd_rv64 test_netbsd_rv64 \
	test_inle

# $m is the warm love (the baked image); an egg-boot gate sets LOVE_NO_IMAGE=1 itself

# love0 self-tests both compilers: two "tests pass". corpus.list is an input, not a stamp
test_love0: $(love0) out/lib/corpus.list
	@echo TEST $(love0)
	@{ $(love0) </dev/null; echo $$? > out/.test_love0.rc; } | tee out/.test_love0.out; \
	  s=$$(cat out/.test_love0.rc); \
	  [ $$s -eq 0 ] && [ `grep -c "tests pass" out/.test_love0.out` -eq 2 ]
# test_filemode -- file mode is terminal: a missing name errs and exits 1, and nothing after runs
test_filemode: $(ho)/love
	@echo TEST file mode is terminal
	@printf '(: _ (puts "reached\\n") _ (an-name-the-book-lacks 1) (puts "past\\n"))\n' > out/.test_filemode.l
	@$m out/.test_filemode.l > out/.test_filemode.out 2>&1; r=$$?; \
	  { [ $$r -eq 1 ] && grep -q "^reached$$" out/.test_filemode.out \
	      && grep -q "^;; missing an-name-the-book-lacks$$" out/.test_filemode.out \
	      && ! grep -q "^past$$" out/.test_filemode.out; } \
	    || { cat out/.test_filemode.out; echo "FAIL file mode not terminal (exit $$r)"; exit 1; }
# test_stdinbuf -- the 4096 bytes gulped off fd 0 stay there for an in-form and an exec'd
# child, seekable or pipe; and fd 0 is handed on blocking
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
	@# past the first gulp the pumper splices the live pipe (200000 bytes against a 64K pipe)
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
# ..and `unchug` puts drained bytes back in front of the inherited fd: all ten with, none without
	@printf 'abcdefghij' > out/.test_stdinbuf4.in
	@p='(: c (see in) _ (unsee in c) t (chug in)'; \
	  a=`$m -e "$$p k (unchug in 99) (exec [\"cat\"]))" < out/.test_stdinbuf4.in`; \
	  b=`$m -e "$$p (exec [\"cat\"]))" < out/.test_stdinbuf4.in`; \
	  { [ "$$a" = abcdefghij ] && [ -z "$$b" ]; } \
	    || { echo "FAIL unchug is not in the inherited fd offset (with=[$$a] without=[$$b])"; exit 1; }
# test_host cats the corpus to a file: faster than stdin, and one global scope
test_host: $(ho)/love
	@echo TEST $m
	@cat $t > $(ho)/.test_host.l
	@{ $m $(ho)/.test_host.l </dev/null; echo $$? > $(ho)/.test_host.rc; } | tee $(ho)/.test_host.out; \
	  s=$$(cat $(ho)/.test_host.rc); \
	  [ $$s -eq 0 ] && grep -q "tests pass" $(ho)/.test_host.out
# test_hostegg -- the corpus down the egg boot. two asserts fewer than test_host: test/holo.l's
# holo laws need the glaze
test_hostegg: $(ho)/love.raw
	@echo TEST $m "(egg)"
	@cat $t > $(ho)/.test_hostegg.l
	@{ env LOVE_NO_IMAGE=1 $(ho)/love.raw $(ho)/.test_hostegg.l </dev/null; echo $$? > $(ho)/.test_hostegg.rc; } | tee $(ho)/.test_hostegg.out; \
	  s=$$(cat $(ho)/.test_hostegg.rc); \
	  [ $$s -eq 0 ] && grep -q "tests pass" $(ho)/.test_hostegg.out
# test_stdincorpus -- the corpus by file, redirect and pipe, egg and baked: each must match
# the file door byte for byte past the duration
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
# test_front -- a frontend over liblove.a whose port vt would-blocks on cue; 97 on a deadlock
$(ho)/front: test/front/main.c $(S)/love/bare.c $(S)/love/alloc.c $(S)/love/horn.c $(love_h) $(ho)/liblove.a $(ho)/.hostcc $(S)/love/love_data.ld \
    out/lib/egg.h out/lib/post.h out/lib/prel.h out/lib/ev.h
	@echo 'CC	'$@
	@mkdir -p $(dir $@)
	@$(hcc) -o $@ test/front/main.c $(S)/love/bare.c $(S)/love/alloc.c $(S)/love/horn.c $(ho)/liblove.a $(data_ld)
# ..and with horn.c's seat door: the frontend's k_horn_* play the device over hornring.h
$(ho)/frontseat: test/front/main.c $(S)/love/bare.c $(S)/love/alloc.c $(S)/love/horn.c $(S)/love/hornring.h $(love_h) $(ho)/liblove.a $(ho)/.hostcc $(S)/love/love_data.ld \
    out/lib/egg.h out/lib/post.h out/lib/prel.h out/lib/ev.h
	@echo 'CC	'$@
	@mkdir -p $(dir $@)
	@$(hcc) -D love_horn_seat=1 -o $@ test/front/main.c $(S)/love/bare.c $(S)/love/alloc.c $(S)/love/horn.c $(ho)/liblove.a $(data_ld)
test_front: $(ho)/front $(ho)/frontseat
	@echo TEST $(ho)/front
	@sh test/gate/run.sh -a front "$(ho)/front" "front: ok" test/front/io.l
	@echo TEST $(ho)/front "(src/love/horn.c's sink, read back through the tap)"
	@sh test/gate/run.sh -a horn "env HORN=none $(ho)/front" "horn: ok" test/front/horn.l
	@echo TEST $(ho)/frontseat "(src/love/horn.c's seat door, over the device's own ring)"
	@sh test/gate/run.sh -a hornseat "$(ho)/frontseat" "hornseat: ok" test/front/hornseat.l
# standalone smoke tests kept out of the corpus: each wants a crew module, is not idempotent
# (love0 evaluates twice), or can hang. gate = exit 0 and "<name>: ok"
hostnif_tests = test/host/gcpause.l test/host/gcage.l test/host/gcroom.l test/host/mop.l test/host/deepeq.l test/host/wharf.l test/host/cb.l test/host/rune.l test/host/pty.l test/host/loader.l test/host/rdiff.l test/host/run.l test/host/luxui.l test/host/sh.l test/host/mitty.l test/host/vi.l test/host/overlay.l test/host/bake.l test/host/rove.l test/host/tty.l test/host/lapiz.l test/host/papel.l test/host/kiosko.l test/host/web.l test/host/sbhttp.l test/host/salt.l test/host/libra.l test/host/clay.l test/host/tls.l test/host/tlsc.l test/host/ssh.l test/host/sshd.l test/host/gz.l test/host/gzc.l test/host/png.l test/host/imgenc.l test/host/jpeg.l test/host/webp.l test/host/pnm.l test/host/bmp.l test/host/qoi.l test/host/im.l test/host/font.l test/host/story.l test/host/design.l test/host/slop.l test/host/score.l test/host/grass.l test/host/grass99.l test/host/wade.l test/host/dusk.l test/host/apartment.l test/host/garage.l test/host/shaft.l test/host/court.l test/host/stones.l test/host/world.l test/host/brush.l test/host/swatch.l test/host/flicker.l test/host/walk.l test/host/gesture.l test/host/mesh.l test/host/lore.l test/host/synth.l test/host/opl.l test/host/mus.l test/host/ops.l test/host/aplay.l test/host/flac.l test/host/icy.l test/host/ogg.l test/host/mp3.l test/host/opus.l test/host/player.l test/host/hexedit.l test/host/seek.l test/host/ptui.l test/host/mc.l test/host/torrent.l test/host/pom.l test/host/tuner.l test/host/saver.l test/host/helm.l test/host/wget.l test/host/www.l test/host/smallweb.l test/host/net.l test/host/ed.l test/host/cook.l test/host/x11.l test/host/window.l test/host/lorewin.l test/host/wad.l test/host/mittywin.l test/host/kitpng.l test/host/bee.l test/host/beeq.l test/host/locks.l test/host/hosts.l test/host/showbig.l test/host/bigprint.l test/host/lovefs.l test/host/droid.l test/host/imgcheck.l test/host/sshkeys.l
# test/host/sh.l drives out/lush via out/love, not PATH's love
hostnif_tests += test/host/xz.l test/host/bz2.l test/host/zstd.l   # the xz, bzip2 and zstd pulls against their whole-string reads
hostnif_tests += test/host/pool.l   # the thread pool: widths, LOVE_THREADS and love.l, a fork's child
hostnif_tests += test/host/init.l   # init's mounts: () is ok, an error says its name
hostnif_tests += test/host/lazyglaze.l   # LOVE_LAZY_GLAZE: first-call compiles, tasks on a compile in flight
# hostnif_j gates at once, longest first, a log shown only on failure; a parent's jobserver wins
hostnif_j = 4
hostnif_first = test/host/sh.l test/host/bee.l test/host/cook.l test/host/beeq.l test/host/court.l
test_hostnif: host out$(hsuf)/lush
	@rm -rf out$(hsuf)/hostnif && mkdir -p out$(hsuf)/hostnif
	@$(MAKE) -s $(if $(findstring jobserver,$(MAKEFLAGS)),,-j$(hostnif_j)) hsuf=$(hsuf) \
	   $(patsubst test/host/%.l,hostnif-%,$(filter $(hostnif_tests),$(hostnif_first)) $(filter-out $(hostnif_first),$(hostnif_tests)))
	@echo "test_hostnif: $(words $(hostnif_tests)) gates"
hostnif-%:
	@s=test/host/$*.l; t0=`date +%s`; \
	 cat test/00-init.l test/host/00-host.l $$s | DL=$(dl) $(gsh) test/gate/run.sh hostnif-$* "$m" ": ok" \
	   > out$(hsuf)/hostnif/$*.log 2>&1 \
	   || { cat out$(hsuf)/hostnif/$*.log; echo "  (the gate above is $$s)"; exit 1; }; \
	 echo "TEST $$s ($$((`date +%s` - t0))s)"
# pure-love design models; they leak helpers into the global scope, so run standalone
doc_tests = test/proto/dest.l test/proto/spl.l
test_doc: host
	@for s in $(doc_tests); do echo "TEST $$s"; \
	  cat test/00-init.l $$s | $(gsh) test/gate/run.sh doc "$m" ": ok" \
	    || { echo "  (the gate above is $$s)"; exit 1; }; \
	done
# the glaze's x86-64 emitter and auto recognizer, holo backends catted ahead; x64 only
ifeq ($a,x64)
test_glaze: host $(love0)
	@echo TEST test/glaze-x86.l "(emit + auto)"
	@{ echo "(borrow 'holo)"; cat src/love/holo/x64.l src/love/holo/a64.l test/glaze-x86.l; } \
	  | $(gsh) test/gate/run.sh glaze "env LOVE_NO_IMAGE=1 $m" "test/glaze-x86:"
	@echo TEST test/gate/rebind.sh "(a rebinding, glazed, unglazed and in love0)"
	@$(gsh) test/gate/rebind.sh "$m" $(love0)
else
test_glaze:
	@sh test/gate/skip.sh gate-skip "test_glaze: skipped (host arch $a is not x64)"
endif
# test_hook -- the creation-hook laws, baked and egg. never cat hook.l in: a woken image lacks `nif`
ifneq ($(filter $a,x64 a64),)
test_hook: host
	@echo TEST test/glaze-hook.l "(the baked image)"
	@$(gsh) test/gate/run.sh -a hook "$m" "glaze-hook: ok" test/glaze-hook.l
	@echo TEST test/glaze-hook.l "(egg boot, hook.l out of the tree)"
	@$(gsh) test/gate/run.sh -a hook "env LOVE_NO_IMAGE=1 $m" "glaze-hook: ok" test/glaze-hook.l
	@echo TEST test/glaze-tail.l "(a native's tail call holds no frame, under a 64 MB budget)"
	@$(gsh) test/gate/run.sh -a hook "env LOVE_BUDGET_MB=64 $m" "glaze-tail: ok" test/glaze-tail.l
# test_glazebench -- each bench, by stdin and by file, beats LOVE_NO_GLAZE=1 by a floor ratio
test_glazebench: host
	@echo TEST test/gate/glazebench.sh "(the benches glaze through the driver)"
	@$(gsh) test/gate/glazebench.sh $m $a
# test_glazefuzz -- 3000 random closures, glazed vs LOVE_NO_GLAZE=1; `fires=` proves work;
# a budget makes a runaway corpus die ;; oom (peak ~95 MB)
test_glazefuzz: host
	@echo TEST test/gate/glazefuzz.l "(glaze differential fuzz: glazed vs interpreted)"
	@on=out/.gfuzz_on.out; off=out/.gfuzz_off.out; \
	  LOVE_NO_IMAGE=1 LOVE_BUDGET_MB=400 $m test/gate/glazefuzz.l > $$on 2>/dev/null \
	    || { echo "FAIL glazefuzz: the GLAZED run died"; exit 1; }; \
	  LOVE_NO_IMAGE=1 LOVE_NO_GLAZE=1 LOVE_BUDGET_MB=400 $m test/gate/glazefuzz.l > $$off 2>/dev/null \
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
test_hook:
	@sh test/gate/skip.sh gate-skip "test_hook: skipped (the hook emits for x64 / a64; host arch is $a)"
test_glazebench test_glazefuzz:
	@sh test/gate/skip.sh gate-skip "$@: skipped (the glaze emits for x64 / a64; host arch is $a)"
endif
# the SAT solver, portable; cold on purpose (3.6 s egg vs 14.4 s woken)
test_sat: host
	@echo TEST src/apps/sat/sat.l + src/apps/sat/dimacs.l + src/apps/sat/flat.l
	@cat src/apps/sat/sat.l src/apps/sat/dimacs.l src/apps/sat/flat.l \
	  | $(gsh) test/gate/run.sh sat "env LOVE_NO_IMAGE=1 $m" "sat: Stages 1-3 ok|src/apps/sat/dimacs: ok|src/apps/sat/flat: ok"
# flat.l's refutations checked by drat-trim (fetched into out/drat; skips offline)
test_drat: host
	@cd src/apps/sat && ./dratcheck.sh || { echo "FAIL drat"; exit 1; }
# lux's pure core: the StackSet with xmonad's QuickCheck laws and a seeded fuzz
test_lux: host
	@$m test/gate/gates.l lux < /dev/null
# harp: the pattern algebra as queries, plus one cycle to .wav and one second out horn=none
test_harp: host
	@$m test/gate/gates.l harp < /dev/null
# test_gates -- the app-law rows in one love; each row also runs by its own target
test_gates: host
	@echo TEST test/gate/gates.l "(the app-law rows, one love)"
	@$m test/gate/gates.l < /dev/null
# test_seat: an app fired by its file name, the dispatch door no other gate reaches; a seat
# answering () fails silently
gate_m += test_seat
gate_m += test_hashrun   # a hash across processes
gate_m += test_walkroom   # a walk past the gap, and past the budget
gate_m += test_cli   # exit status: 0 working, 1 unopenable, 2 malformed, a verb's own charm
gate_m += test_nest   # love nest, in a HOME of its own
gate_m += test_spin   # a waiting machine spends nothing

# the checked-in icon must be what src/tools/mkicon.l lays
test_web: host
	@echo TEST src/tools/mkicon.l
	@mkdir -p out/.w
	@env -u LOVE_NO_IMAGE $m src/tools/mkicon.l src/love/quay/cga_8x8.c 3 32 out/.w/favicon.png 2>/dev/null
	@cmp -s out/.w/favicon.png web/favicon.png \
	  || { echo "  FAIL: a committed web asset is behind web/ -- run make web and commit"; exit 1; }
	@echo "  web: ok -- the icon is what web/ lays"
test_sb: host out$(hsuf)/sb
	@echo TEST src/apps/sb/sb.l + test/host/sb.l
	@cat test/00-init.l test/host/sb.l | $(gsh) test/gate/run.sh sb "$m" "sb: ok"
# the kore smokes run through the crew layer, warm per spawn
korerun = $m
# spelled, as common.sh is dotted, never run. `make test_kore_sed` runs one
kore_parts = laws diff toolchain line sort ls grep field column encode fs sed proc \
  procfs sh fork awk find record sum expr bc stat time patch pager top lapiz archive \
  misc ed openssl prop-seams prop-door prop-status
test_kore: host
	@for p in $(kore_parts); do $(gsh) test/kore/$$p.sh $(ho) $m || exit 1; done
$(kore_parts:%=test_kore_%): test_kore_%: host
	@$(gsh) test/kore/$*.sh $(ho) $m
# the fuzz lanes run capped: a heap budget, so a runaway corpus dies ;; oom, and a clock, since
# near the budget the collector slows quadratically before it gives up
fuzzlate = [ $$? -ne 124 ] || echo "  (it ran out its clock)"
# grep + sed against GNU over seeded random patterns; skips without GNU (`grep` may be ugrep).
# each tool run peaks ~15 MB, the lane ~2 min
test_refuzz: host
	@echo TEST test/gate/refuzz.sh
	@LOVE_BUDGET_MB=200 timeout 900 $(gsh) test/gate/refuzz.sh $m \
	  || { $(fuzzlate); echo "FAIL refuzz -- grep or sed parted from GNU, or died"; exit 1; }
# cook against GNU make differentially (an unknown builtin expands empty in silence); skips without
gate_m += test_cookdiff
# test_dist smokes the baked binary's verb rail, cc door, image chain and in-image lane
test_dist: $(ho)/love
	@$(gsh) test/gate/dist.sh smoke $(ho)/love
# test_seed -- the artifact rebuilds itself byte for byte; -g defers to an ambient cc, test_distboot poisons them all
test_seed: $(ho)/love
	@echo TEST love seed "(the fixpoint)"
	@rm -rf $(ho)/.seedtest && mkdir -p $(ho)/.seedtest
	@$(ho)/love seed -g $(ho)/.seedtest > $(ho)/.test_seed.out 2>&1 \
	  || { tail -20 $(ho)/.test_seed.out; echo "FAIL love seed"; exit 1; }
	@tail -1 $(ho)/.test_seed.out
	@rm -rf $(ho)/.seedtest
# vi: the modal engine's laws, then scripted `love vi` sessions over a pipe
test_vi: host
	@echo TEST src/apps/{tui,vi/hue,vi/hues,vi/core}.l test/law/{tui,vi}.l
	@cat test/00-init.l src/apps/kore/text.l src/apps/kore/u.l src/apps/kore/core.l src/apps/kore/re.l src/apps/kore/sed.l src/apps/libra/lint.l \
	    src/apps/tui.l test/law/tui.l \
	    src/apps/vi/config.l src/apps/vi/hue.l src/apps/vi/hues.l src/apps/vi/core.l test/law/vi.l \
	  | $(gsh) test/gate/run.sh vi "$m" "test/law/vi:"
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
# mooncc: the pipeline's goldens, then compile-and-run against a gcc -O0 differential
moonrun = $m mooncc
# love0 for the inline-asm checks: the bootstrap lane binds its own `post`
test_moon: host $(love0)
	@$(gsh) test/gate/moon.sh $(ho) $m $(love0)
# the generated headers, dest:source:value:check, written by `make mx` and diffed by test_clay;
# a refresh is gated by `make test`
mx_gen = src/love/mx.h:src/love/mx.l:mx-h:mx-ok src/love/kinds.h:src/love/mx.l:kinds-h:mx-ok src/love/nifs.h:src/love/nifs.l:nifs-h:nifs-ok \
         src/love/quay/xterm256.h:src/love/quay/quay.l:q-c:q-ok src/love/quay/cp437.h:src/love/quay/quay.l:q-437:q-437-ok src/love/love_data.ld:src/love/mx.l:mx-ld:mx-ok
# \# is load-bearing: a bare # in a make variable starts a comment
mxsplit = d=$${s%%:*}; r=$${s\#*:}; l=$${r%%:*}; r=$${r\#*:}; v=$${r%%:*}; k=$${r\#*:}; o=out/.`basename $$d`
# the egg lane: the crew in the warm book shadows names these generators use
mxlay   = LOVE_NO_IMAGE=1 $m -l $$l -e "(: _ (? $$k 0 (quit 1)) _ (puts $$v) (quit 0))"
mx: host
	@echo 'LOVE	'src/love/mx.h src/love/kinds.h src/love/nifs.h xterm256.h cp437.h src/love/love_data.ld "(src/love/mx.l + src/love/nifs.l + quay.l on $m)"
	@for s in $(mx_gen); do $(mxsplit); $(mxlay) > $$o || exit 1; done
	@for s in $(mx_gen); do $(mxsplit); mv $$o $$d; done
# each header depends on its table alone ($(m) would close a loop); with no love it stands
define mx_dep
$(word 1,$(subst :, ,$(1))): $(word 2,$(subst :, ,$(1)))
	@if test -x $$(m); then \
	   $$(m) -l $$< -e "(: _ (? $(word 4,$(subst :, ,$(1))) 0 (quit 1)) _ (puts $(word 3,$(subst :, ,$(1)))) (quit 0))" > out/.$$(@F) || exit 1; \
	   cmp -s out/.$$(@F) $$@ || echo "LOVE	$$@ (relaid -- $$< moved)"; \
	   mv out/.$$(@F) $$@; \
	 else touch $$@; fi
endef
$(foreach s,$(mx_gen),$(eval $(call mx_dep,$(s))))
# test_clay -- (cparse (clay-show ast)) == ast over test/cc, then the headers regenerate
test_clay: host
	@echo TEST test/gate/clay.l "(clay G1: (cparse (clay-show c)) == c over test/cc)"
	@$m -l test/gate/clay.l < /dev/null
	@for s in $(mx_gen); do $(mxsplit); $(mxlay) > $$o; \
	   cmp -s $$o $$d || { echo "FAIL $$d is not what $$l lays -- run: make mx"; \
	                       diff -u $$d $$o | head -20; exit 1; }; done
	@echo "clay-mx: src/love/mx.h, src/love/kinds.h, src/love/nifs.h, xterm256.h, cp437.h and src/love/love_data.ld regenerate identically"
	@for s in $(mx_gen); do $(mxsplit); rm -f $$o; done
# test_moonfuzz -- each test/cc file mutated eight ways: no scare, no hang, G1 where it parses.
# mooncc runs in this process, so the budget reaches it (peak ~215 MB, passes at 60; ~1 min)
test_moonfuzz: host
	@echo TEST test/gate/moonfuzz.l "(moon refusal fuzz: 8 mutants per file over test/cc)"
	@LOVE_BUDGET_MB=400 timeout 600 $m -l test/gate/moonfuzz.l < /dev/null || { $(fuzzlate); exit 1; }
# test_forge -- love-written nifs via holo agree with the C nif they deopt into; none fitted fails
test_forge: host
	@echo TEST test/gate/forge.l "(forge: love IR -> holo -> nif -> differential)"
	@LOVE_NO_IMAGE=1 $m -l test/gate/forge.l < /dev/null
# every test/cc/*.c by `mooncc -t $*` under qemu-user, held to x64; unbuildable ones must refuse
test_cca64 test_ccrv64: test_cc%: host
	@$(gsh) test/gate/ccarch.sh $* $(ho) $m
# the battery on 32-bit linux: gcc -m32, or arm-none-eabi-gcc's newlib under qemu-arm
test_cci386 test_ccarm: test_cc%: host
	@$(gsh) test/gate/cc32.sh $* $(ho) $m
# test_ccwasm -- the battery on wasm, node as the machine
gate_hm += test_ccwasm
# the battery on M-profile: no qemu-user, ILP32, so arm-none-eabi-gcc's build is the oracle
test_ccthumb1 test_ccthumb2: test_cc%: host
	@$(gsh) test/gate/ccthumb.sh $* $(ho) $m
# c-testsuite held to its shipped stdout, misses rostered in cts.sh
test_cts: host
	@DL=$(dl) $(gsh) test/gate/cts.sh x64 $(ho) $m
test_cts_a64 test_cts_rv64 test_cts_wasm: test_cts_%: host
	@DL=$(dl) $(gsh) test/gate/cts.sh $* $(ho) $m
# the tests fetch their pinned, hash-checked inputs into dl/ themselves, once (test/gate/dl.sh
# holds the pins; `make clean` keeps dl/); a failed fetch skips loudly
# test_ccport -- tcc and chibicc built by mooncc, held to their gcc builds (test/gate/ccport.sh)
test_ccport: host
	@DL=$(dl) $(gsh) test/gate/ccport.sh $(ho) $m
# test_libc -- test/libc/*.c built by mooncc and by gcc, outputs compared
gate_hm += test_libc
# test_ulp -- the math floor built by both compilers must agree bit for bit
gate_hm += test_ulp
# test_softfp -- rt.c's soft fpu/umull/clz against hardware, system cc and mooncc's backends
gate_hm += test_softfp
# test_reloc32 -- arm32 --emit-relocs: linked 64K apart, the table is the words that moved;
# MOVW/MOVT absolutes refuse
gate_hm += test_reloc32
# every love C file and moonlibc by mooncc, the system linker binding; opt-in, x64 only
test_selfhost: host
	@echo TEST $(ho)/love-selfhost
	@$(raw_env) $(gsh) test/gate/selfhost.sh $(ho) $m $t
# the gcc-free fixpoint: test_selfhost plus our libc, lm.c, sys.o and linker. raw_env is shared
# with the cross twins
raw_env = gate_love_c='$(love_tu_c)' gate_host_c='$(host_c)' gate_arch_c='$(hosta_c)' gate_hosta='$(hosta)' gate_seat_c='$(S)/love/user/nokern.c $(S)/love/noblob.c'
test_raw: host
	@$(raw_env) $(gsh) test/gate/raw.sh x64 $(ho) $m $t
# test_tco0 -- love at tco=0 (love0 never reaches the glaze's lvm shape): build, bake, corpus in
# its own hsuf'd tree. no vmret: at tco=0 an lvm returns
test_tco0: host $(love0) $(ho)/mooncc0.image
	@$(MAKE) --no-print-directory tco=0 host
	@$(MAKE) --no-print-directory tco=0 test_host
	@echo "test_tco0: the trampoline builds, bakes and passes the host corpus"
# test_hdiff -- gcc and clang each link the whole vm at tco=1: build, answer, quick suite, ret-free
gate_cc += test_hdiff
# test_ccwarn -- gcc and clang build love0 and the vm with -Werror
gate_cc += test_ccwarn
# the `CC=mooncc` driver: $(cflags) through -c, libc pulled by need, -shared and -nostdlib loud
test_drv: host
	@$(gsh) test/gate/drv.sh $(ho) $(cflags)
# src/inle/<a>/asmops.h compiled by mooncc and clang, compared op by op; skips without llvm-objdump
gate_ho += test_asmops
# host cc only. test_dtb: src/inle/dtb.h on built trees: the other cell width, non-memory reg,
# banks, clamps, long cmdline, torn magic. test_ffalloc: ffalloc.h's free list, checked every step
test_dtb test_ffalloc: test_%:
	@echo TEST test/gate/$*.c
	@$(CC) -I$S/inle -I$S/love -I$R -o $(ho)/.$*gate $R/test/gate/$*.c
	@$(ho)/.$*gate
# test_rvboot -- the rv64 boot stub and dtb door under qemu virt + OpenSBI, linked by ldkern (a
# machine enters at the load address, not crt0). exit 42
rvboot_o = $(ko)/rv64/rv64/boot.o $(ko)/rv64/inle/rv64/dtb.o $(ko)/rv64/rvboot.o
$(ko)/rv64/rvboot.o: test/gate/rvboot.c $(love_h) $(S)/inle/k.h $(S)/inle/dtb.h $(mooncc_dep)
	@echo 'MOON	'$@
	@mkdir -p "$(dir $@)"
	@$(mooncc) -I$(ko)/rv64 -I. -Isrc/love -Isrc/inle -I$(ho) -Iout/lib -I$R -I$S/apps/moon/include \
	  -t rv64 -c $< -o $@
$(ko)/rv64/rvboot.elf: $(rvboot_o) test/gate/rvboot.l $m
	@echo 'RVLINK	'$@
	@LOVE_NO_IMAGE= $m test/gate/rvboot.l $(rvboot_o) $@
test_rvboot: host
	@$(MAKE) -s a=rv64 $(ko)/rv64/rv64/boot.o $(ko)/rv64/inle/rv64/dtb.o
	@$(MAKE) -s $(ko)/rv64/rvboot.elf
	@sh test/gate/boot.sh rvboot "$(MAKE)"
# test_vec -- real CPU exceptions and their reports. kvec.o: $(moon_d) at the host arch, else $(ko).
# two ifeqs, never an else-ifeq
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
	@$(MAKE) -s $(src_tree) out/rootfs.tar
	@rm -rf out/vec && mkdir -p out/vec
	@$(MAKE) -s $(if $(findstring jobserver,$(MAKEFLAGS)),,-j3) vec-x64 vec-a64 vec-rv64
vec-%:
	@{ $(MAKE) -s a=$* kernel && $(gsh) test/gate/vec.sh $* out/love-$*.elf $(kvec_$*); } \
	   > out/vec/$*.log 2>&1; r=$$?; cat out/vec/$*.log; exit $$r
# the fixpoint: love1 rebuilds every TU into love2, byte-identical; the link list is make's
# objects, never a glob. test_extra only
test_fixpoint: host $(moon_seat_o) $(love0) $(ho)/mooncc0.image
	@$(MAKE) -s a=$(hosta) $(ko)/$(hosta)/mkvec.l
	@gate_love_c='$(love_tu_c)' gate_host_c='$(host_c)' gate_arch_c='$(hosta_c)' \
	  gate_kern_c='$(k_free_c)' gate_seat_c='$(S)/love/noblob.c' \
	  $(gsh) test/gate/fixpoint.sh $(ho) $(love0) $(hosta) $(moon_d) $(moon_o) $(moon_seat_o) $(kart_o)
# the cross fixpoint under qemu-user; opt-in (`make xa=rv64 test_xfixpoint`), skips without qemu
test_xfixpoint: $(x_o) $(x_seat_o) $(xkart_o) $(love0) $(ho)/mooncc0.image
	@gate_love_c='$(love_tu_c)' gate_host_c='$(host_c)' gate_arch_c='$(wildcard $S/inle/$(xa)/*.c)' \
	  gate_kern_c='$(k_free_c)' gate_seat_c='$(S)/love/noblob.c' \
	  sh test/gate/xfixpoint.sh $(ho) $(love0) $(xqemu) $(xa) mksys-$(xa) $(tco) $(xod) $(xa) $(x_o) $(x_seat_o) $(xkart_o)
# test_fat -- the fat container: native answer, deterministic pack, foreign member under qemu-user
test_fat: dist-fat
	@sh test/gate/fat.sh $(fat) $a $(xa) $(xqemu) "$(love0)" $(ho) $(xd) $(uname_$(xa))
# one binary answers every kernel alike, on a bee host with cap freebsd-x64/netbsd-x64 (-a64, -rv64,
# -arm, -i386 likewise) (or FBSD_SSH/NBSD_SSH); skips without. FBSD_SEED=1/NBSD_SEED=1 adds `love seed` there
.PHONY: test_freebsd test_netbsd test_freebsd_a64 test_netbsd_a64 test_freebsd_rv64 test_netbsd_rv64 test_freebsd_arm test_netbsd_arm test_freebsd_i386 test_netbsd_i386 test_macos test_macos_love
# test_OS_ISA: the local half under qemu-user; rv64 hosts are riscv64 guests (the doors are each
# kernel's number register: linux a7, freebsd t0, netbsd t6), arm and i386 the 64-bit boxes' 32-bit lanes
test_freebsd test_netbsd test_freebsd_a64 test_netbsd_a64 test_freebsd_rv64 test_netbsd_rv64 \
test_freebsd_arm test_netbsd_arm test_freebsd_i386 test_netbsd_i386: host $(love0) $(ho)/mooncc0.image
	@$(gsh) test/gate/osbox.sh $(ho) $(love0) $(subst _, ,$(@:test_%=%))
# macos: a mach-o for the box (cap macos-x64) beside each leg's ELF, the two answering alike
test_macos: host $(love0) $(ho)/mooncc0.image
	@$(gsh) test/gate/osbox.sh $(ho) $(love0) macos x64
# love itself there: linked here as a mach-o, baked and run on the box
test_macos_love: host $(ho)/love-macos.raw $(ho)/.dist-cat.l
	@$(gsh) test/gate/maclove.sh $(ho)
# test_raw_bake -- the mooncc PIE bakes and wakes its own image; x64 only, opt-in
test_raw_bake: test_raw
	@sh test/gate/raw-bake.sh $(ho) $t
# test_raw's rv64 twin under qemu-riscv64, whole corpus over the egg; skips without qemu
test_raw_rv64: host
	@$(raw_env) $(gsh) test/gate/raw.sh rv64 $(ho) $m $t
# test_raw's a64 twin under qemu-user. $t stays in C byte order (uu.l before uukindlaw.l);
# callout.l only an a64 love may read, gate_sentinel proves it was
test_raw_a64: host
	@$(raw_env) gate_sentinel='test/a64/callout:.* ok' \
	  $(gsh) test/gate/raw.sh a64 $(ho) $m $t test/a64/callout.l
# test_love_a64 -- the cross-built a64 artifact on a64 (else qemu-user): corpus, bake, corpus.
# on an a64 box test_host is this lane
ifeq ($(xa),a64)
test_love_a64: host $(xd)/love $(ho)/.dist-cat.l
	@$(gsh) test/gate/a64love.sh $(ho) $m $(xd)/love $(ho)/.dist-cat.l $t
else
test_love_a64:
	@echo "test_love_a64: this box is $(a); test_host is the native lane here"
endif
# the ELF32/EM_ARM writer and 32-bit model: cross-object BL, soft divide, `la`, a gcc struct,
# a pointer table in a named section; ld32.l reads it back.
#   thumb2sp the SP-only FPU: f64 softens, qemu's mps2-an386 faults on any that slip
test_thumb1 test_thumb2 test_thumb2sp: test_%: host
	@$(gsh) test/gate/thumb.sh $* $(ho)
# love on the metal by mooncc and our linker; exit 42 = laws held, 98 = a trap.
#   virt the bare rv64 hart; mps2 the M7, -t thumb2; mps2_t1 the same at -t thumb1
#   mps2_wake a differently offset arena wakes the baked heap
#   nucleo446_smoke the QSMOKE twin on qemu's M4, the only lane running crt0 and the fault
#             vectors. qemu only: a bkpt with no debugger locks up silicon
test_virt test_mps2 test_mps2_t1 test_mps2_wake test_nucleo446_smoke: test_%: host
	@$(gsh) test/gate/boot.sh $* "$(MAKE)"
# test_playdate -- mooncc -t thumb2sp and ldbare32, nothing foreign; the SDK gives headers and pdc
test_playdate: host
	@$(gsh) test/gate/playdate.sh "$(MAKE)" $m
# test_teensy41 -- mooncc, tlink.l, mkimg.l, ocopy.l, the boot image verified out of the .bin
test_teensy41: host
	@echo TEST out/teensy41/love.hex
	@$(MAKE) -C src/inle/teensy41 || { echo "FAIL teensy41 build (the boot-image verify is inside)"; exit 1; }
	@test -s out/mps2/love.img || { . test/gate/skip.sh; gate_partly "test_teensy41: no qemu-system-arm to bake the heap image -- the firmware egg-boots, its image wrap untested"; }
	@echo "test_teensy41: love (all-mooncc thumb2), OUR linker, flatten and boot image -- nothing foreign"
# test_nucleo446 -- mooncc, nlink.l, ocopy.l; arm-none-eabi-gcc only for its libgcc.a
test_nucleo446: host
	@echo TEST out/nucleo446/firm.hex
	@if ! command -v arm-none-eabi-gcc >/dev/null 2>&1; then \
	   sh test/gate/skip.sh gate-skip "test_nucleo446: no arm-none-eabi toolchain, skipped"; exit $$?; fi; \
	  $(MAKE) -C src/inle/nucleo446 || { echo "FAIL nucleo446 build (the boot-image verify is inside)"; exit 1; }; \
	  echo "test_nucleo446: firmware (all-mooncc thumb2sp), OUR linker and flatten, no linker script, boot image verified"
# test_rp2040 -- the Pico, no .S: boot2 by mkboot2.l, verified; builds only, test_mps2_t1 runs it
test_rp2040: host
	@echo TEST out/rp2040/love.bin
	@$(MAKE) -C src/inle/rp2040 || { echo "FAIL rp2040 build (the boot-image verify is inside)"; exit 1; }
	@echo "test_rp2040: firmware (all-mooncc thumb1, boot2 laid by holo, no .S), OUR linker, flatten and runtime -- no foreign file, flash R|X, boot surface verified"
# test_boards -- the ports still compile; prerequisites, so a wide make runs them at once
test_boards: test_mps2_build test_virt_build test_rp2040 test_nucleo446 test_teensy41 test_playdate
	@echo "test_boards: six ports build and link -- mooncc and our linker, no emulator"
test_mps2_build test_virt_build: test_%_build: host
	@echo TEST out/$*/love.elf '(build)'
	@$(MAKE) -C src/inle/$* || { echo "FAIL $* build"; exit 1; }
# test_links -- every link topology, nothing run, plus test/gate/lay.l's law over what a loader maps
.PHONY: test_links
test_links: host $(ho)/front $(ho)/frontseat $(love0)
	@$(MAKE) -s $(ko)/love-x64.elf
	@$(MAKE) -s a=a64 $(ko)/love-a64.elf
	@$(MAKE) -s a=rv64 $(ko)/love-rv64.elf
	@$(MAKE) -s a=wasm $(ko)/love.wasm
	@$(MAKE) -s test_boards
	@$m test/gate/lay.l $(ho)/love $(ho)/front $(ho)/frontseat || { echo "FAIL lay"; exit 1; }
	@echo "test_links: hosted, bootstrap, front and its seat-horn twin, the wasm machine, three kernels, six boards"

# userland packages by mooncc + moonlibc + holo linker, held to their own suites; opt-in by
# the SRC var. the sqlite cross lanes read moon-sqlite's x64 answers
moon_arch_a64 = a64
moon_arch_rv64 = rv64
# $1 package, $2 its source-tree var, $3 what the two cross lanes wait on
define moon_pkg
moon-$1: host
moon-$1-a64 moon-$1-rv64: $3
moon-$1 moon-$1-a64 moon-$1-rv64:
	@$2="$$($2)" ./src/tools/moon-$1.sh $$(moon_arch_$$(patsubst moon-$1-%,%,$$@))
endef
$(eval $(call moon_pkg,tar,TARSRC,host))
$(eval $(call moon_pkg,m4,M4SRC,host))
$(eval $(call moon_pkg,lua,LUASRC,host))
$(eval $(call moon_pkg,sqlite,SQLSRC,moon-sqlite))
$(eval $(call moon_pkg,gzip,GZIPSRC,host))
$(eval $(call moon_pkg,bzip2,BZIP2SRC,host))
# flex and bison on m4, built with CC=mooncc, held byte-identical to the host's flex and bison
moon-flex moon-bison: host
	@./src/tools/$@.sh
# test_bakerep -- a bake is a function of the tree; seconds, so it rides test_slow
test_bakerep: host $(prof_raw)
	@echo TEST test/gate/bakerep.sh
	@$(gsh) test/gate/bakerep.sh $(ho) $(prof_raw)
# test_distboot -- the carried source rebuilt two ways, every cc poisoned in one; then `love seed`
# with no compiler (not test_seed's default seed)
test_distboot: dist
	@echo TEST test/gate/distboot.sh
	@sh test/gate/distboot.sh $(ho)/love
# test_hearts -- the arm64 defconfig Image, byte-identical to kbuild+clang's; heavy, opt-in
gate_love += test_hearts
# test_hearts_boot -- hearts under qemu virt: chooser, helm as pid 1, three updates. heavy
hb_love = $(if $(filter a64,$a),$(ho)/love,out/x-a64/love)
test_hearts_boot: host $(hb_love) $(ho)/.dist-cat.l
	@echo TEST test/gate/hearts-boot.sh
	@DL=$(dl) $(gsh) test/gate/hearts-boot.sh $(ho)/love $(hb_love) $(ho)/.dist-cat.l
# test_sqfs -- src/apps/sqfs.l against mksquashfs over four trees, byte for byte; skips without
gate_love += test_sqfs
# test_ext4 -- src/apps/ext4.l against mke2fs, byte for byte, five sizes; skips without
gate_love += test_ext4
# test_gz -- tar.l + gz.l against the system tools; skips without
test_gz: host
	@echo TEST test/gate/targz.sh
	@$(gsh) test/gate/targz.sh $(ho)/love
# test_standalone -- zstd.c, bz2.c, xz.c outside love (_STANDALONE), built by mooncc, their streams and love's both ways
gate_love += test_standalone
# test_root -- the privileged verbs refuse as a user, then run in a user namespace (skipped
# with namespaces off)
gate_hol += test_root
# test_fat32 -- `love fat` + `love mkfs.vfat` against mtools both ways; skips without
gate_hol += test_fat32
# test_cpio -- src/apps/cpio.l against GNU cpio, both ways over newc
gate_love += test_cpio
# holo's encoder goldens, objdump-checked. every backend is catted in: the host bakes only its own
test_holo: host
	@echo TEST test/holo/golden.l
	@cat src/love/holo/holo.l src/love/holo/x64.l src/love/holo/a64.l src/love/holo/thumb2.l \
	    src/love/holo/rv64.l src/love/holo/thumb1.l src/love/holo/i386.l src/love/holo/text.l src/love/holo/dialect.l src/love/holo/gas.l src/love/holo/elf.l \
	    src/love/holo/wasm.l src/love/holo/wasmfn.l test/holo/golden.l | $(gsh) test/gate/run.sh holo "$m" ", 0 failed"
	@cat test/00-init.l test/law/lds.l | $(gsh) test/gate/run.sh lds "$m" "test/law/lds:"
	@cat test/00-init.l test/law/klink.l | $(gsh) test/gate/run.sh klink "$m" "test/law/klink:"
# as.l, x86-64 over holo: goldens from /usr/bin/as; asrefuse, dialect and decode alongside
test_as: host
	@echo TEST test/holo/as.l
	@cat src/love/holo/holo.l src/love/holo/x64.l src/love/holo/dialect.l src/love/holo/decode.l src/love/holo/as.l test/holo/as.l \
	  | $(gsh) test/gate/run.sh as "$m" ", 0 failed"
	@$(gsh) test/gate/asrefuse.sh "$m"
	@$(gsh) test/gate/dialect.sh "$m" $(ho)
	@$(gsh) test/gate/decode.sh "$m" $(ho)
# test_elf32 -- holo's ELF32 writer judged by Linux under qemu-arm: thumb write+exit returns 42
gate_ho += test_elf32
# test_objcopy -- src/love/holo/copy.l byte-compared with objcopy, both formats; skips without
gate_ho += test_objcopy
# nc over real TCP on 127.0.0.1, both directions; `make nettest PORT=N`
PORT ?= 7390
nettest: host
	@echo TEST $m "(127.0.0.1:$(PORT))"
	@sh $R/test/net/loopback.sh $m $(PORT)
# the tool gates (src/tools/Makefile); lush is needed by test/host/cook.l's SHELL pair
test_tools: host out$(hsuf)/lush
	@$(MAKE) -C src/tools
# test_gcheck: LvGcCheck traps a re-driven minor that copies again. GCDBG, not EXTRA_CFLAGS; shared
# prerequisites named here so two sub-makes never race to write them
test_gcheck: host $(love0) $(ho)/mooncc0.image
	@$(MAKE) --no-print-directory hsuf=/gck GCDBG=-DLvGcCheck test_host
	@$(MAKE) --no-print-directory hsuf=/gck GCDBG=-DLvGcCheck test_hostegg
# test_gcstress: LvGcStress collects every time and poisons the nursery, the corpus in GCS_SHARDS
# shards; _bake bakes
# under stress too, _full runs it whole plus the stress love0 (hours)
GCS_SHARDS ?= 4
test_gcstress: host $(love0) $(ho)/mooncc0.image
	@MAKE='$(MAKE)' sh test/gate/gcshard.sh . $(GCS_SHARDS)
test_gcstress_bake: host $(love0) $(ho)/mooncc0.image
	@GCS_BAKE=1 MAKE='$(MAKE)' sh test/gate/gcshard.sh . $(GCS_SHARDS)
test_gcstress_full: host $(love0) out/gcs0/love0 out/lib/corpus.list $(ho)/mooncc0.image
	@$(MAKE) --no-print-directory hsuf=/gcs GCDBG=-DLvGcStress test_host
	@$(MAKE) --no-print-directory hsuf=/gcs GCDBG=-DLvGcStress test_hostegg
	@sh test/gate/l0stress.sh .
# --- the machine-checked half: test/proof/rocq/ + test/proof/lean/ ---
# each gate skips, saying so, when its checker is missing
COQC     ?= $(shell command -v coqc 2>/dev/null)
OCAMLOPT ?= $(shell command -v ocamlopt 2>/dev/null)
LEAN     ?= $(shell command -v lean 2>/dev/null)
# the scratch coqc strews beside a .v, and what an extracted ocaml ref leaves
vclean = rm -f $(foreach n,$1,test/proof/rocq/$n.vo test/proof/rocq/$n.vok test/proof/rocq/$n.vos test/proof/rocq/$n.glob test/proof/rocq/.$n.aux)
dclean = rm -f $(foreach n,$1,test/proof/rocq/$n_ref.ml test/proof/rocq/$n_ref.mli test/proof/rocq/$n_drive)

ifeq ($(COQC),)
test_proof test_gc test_gen test_uugen test_mx:
	@sh test/gate/skip.sh gate-skip "$@: skipped (needs rocq/coqc)"
else
# spec.v -- test/spec.l's headline laws in Rocq, kept for test_gen and test_extract; always
# `-R . ""` from test/proof/rocq, or its logical name differs
rocq_kept = test/proof/rocq/spec.vo test/proof/rocq/patch.vo
# a kept .vo depends on a witness rewritten only when coqc --version changes
.PHONY: force_coqc
force_coqc: ;
rocq_ver = $(ho)/.coqc-version
$(rocq_ver): force_coqc
	@mkdir -p $(ho)
	@tf=$@.$$$$.tmp; $(COQC) --version > $$tf 2>&1; \
	 $(note)
# the stdlib the proofs import, built by this coqc from its own .v: a packaged stdlib's .vo
# refuse a coqc of another version. coqc carries it
rocq_std = $(ho)/rocq
rocq_srcs = $(addprefix test/proof/rocq/,spec.v patch.v gc.v gcsize.v extract.v big.v enc.v encmem.v encli.v) \
  src/tools/spec2coq.l src/tools/uu2coq.l src/tools/mx2coq.l
$(rocq_std)/.built: $(rocq_ver) test/gate/rocqstd.sh $(rocq_srcs)
	@sh test/gate/rocqstd.sh "$(COQC)" $(rocq_std) $(rocq_srcs)
coqc = $(COQC) -R $(abspath $(rocq_std))/Stdlib Stdlib
$(rocq_kept): test/proof/rocq/%.vo: test/proof/rocq/%.v $(rocq_ver) $(rocq_std)/.built
	@echo TEST test/proof/rocq/$*.v "(coqc)"
	@cd test/proof/rocq && $(coqc) -q -R . "" $*.v
test_proof: $(rocq_kept)
	@echo "test_proof: spec.v + patch.v check (the .vo IS the evidence, so a re-run is quiet)"
# gc.v -- the minor is sound under a complete barrier, its pause bounded, the drain a fixpoint
test_gc: $(rocq_std)/.built
	@echo TEST test/proof/rocq/gc.v "(coqc)"
	@$(coqc) -q test/proof/rocq/gc.v
	@echo TEST test/proof/rocq/gcsize.v "(coqc)"
	@$(coqc) -q test/proof/rocq/gcsize.v
	@$(call vclean,gc gcsize)
# src/tools/spec2coq.l turns test/spec.l's numeral facts into gen.v, regenerated every run
test_gen: host $(rocq_kept)
	@echo 'LOVE	'test/proof/rocq/gen.v "(src/tools/spec2coq.l on $m)"
	@$m src/tools/spec2coq.l > test/proof/rocq/gen.v
	@echo TEST test/proof/rocq/gen.v "(coqc, against spec.v's shared model)"
	@cd test/proof/rocq && $(coqc) -R . "" gen.v
	@$(call vclean,gen)
# src/tools/uu2coq.l: a proof term checked by uu's kernel, re-checked by coqc
test_uugen: host $(rocq_std)/.built
	@echo 'LOVE	'test/proof/rocq/uugen.v "(src/tools/uu2coq.l on $m)"
	@$m src/tools/uu2coq.l > test/proof/rocq/uugen.v
	@echo TEST test/proof/rocq/uugen.v "(coqc)"
	@$(coqc) -q test/proof/rocq/uugen.v
	@$(call vclean,uugen)
# src/love/mx.l modelled in Rocq by src/tools/mx2coq.l, a second derivation beside mx.h
test_mx: host $(rocq_std)/.built
	@echo 'LOVE	'test/proof/rocq/mx.v "(src/tools/mx2coq.l on $m)"
	@cat src/love/mx.l src/tools/mx2coq.l | $m > test/proof/rocq/mx.v
	@echo TEST test/proof/rocq/mx.v "(the dispatch matrices: band factorization + dispatch commutativity, coqc)"
	@cd test/proof/rocq && $(coqc) -q mx.v >/dev/null
	@$(call vclean,mx)
endif

ifeq ($(and $(COQC),$(OCAMLOPT)),)
test_extract test_big test_encver:
	@sh test/gate/skip.sh gate-skip "$@: skipped (needs coqc + ocamlopt)"
else
# extract.v's normalizer, extracted to OCaml and fuzzed against ev. run the oracle once into a file
test_extract: host $(rocq_kept)
	@echo TEST test/proof/rocq/extract.v "(coqc extraction -> ocaml ref vs ev)"
	@cd test/proof/rocq && $(coqc) -R . "" extract.v >/dev/null \
	  && rm -f normalizer.mli && $(OCAMLOPT) -w -a normalizer.ml oracle_drive.ml -o oracle_drive
	@test/proof/rocq/oracle_drive 2000 6 1 > out/.extract_oracle.l
	@$m out/.extract_oracle.l > out/.extract_oracle.out 2>&1; r=$$?; \
	  { [ $$r -eq 0 ] && grep -q "2000 / 2000 PASS" out/.extract_oracle.out; } \
	    || { echo "FAIL the extract oracle (exit $$r):"; cat out/.extract_oracle.out; exit 1; }
	@cat out/.extract_oracle.out
	@$(call vclean,extract)
	@rm -f test/proof/rocq/normalizer.ml test/proof/rocq/normalizer.mli test/proof/rocq/oracle_drive \
	  test/proof/rocq/*.cmi test/proof/rocq/*.cmx test/proof/rocq/*.o out/.extract_oracle.l out/.extract_oracle.out
# big.v: the decimal codec roundtrip and quot-rem/gcd, extracted Z against love's bignums
test_big: host $(rocq_std)/.built
	@echo TEST test/proof/rocq/big.v "(coqc codec proof + extracted Z ref vs the limb lane)"
	@cd test/proof/rocq && $(coqc) -q big.v >/dev/null \
	  && rm -f bigref.mli && $(OCAMLOPT) -w -a bigref.ml big_drive.ml -o big_drive
	@test/proof/rocq/big_drive 2000 1 > out/.big_oracle.l
	@$m out/.big_oracle.l > out/.big_oracle.out 2>&1; r=$$?; \
	  { [ $$r -eq 0 ] && grep -q "2000 / 2000 PASS" out/.big_oracle.out; } \
	    || { echo "FAIL the big oracle (exit $$r):"; cat out/.big_oracle.out; exit 1; }
	@cat out/.big_oracle.out
	@$(call vclean,big)
	@rm -f test/proof/rocq/bigref.ml test/proof/rocq/bigref.mli test/proof/rocq/big_drive \
	  test/proof/rocq/*.cmi test/proof/rocq/*.cmx test/proof/rocq/*.o out/.big_oracle.l out/.big_oracle.out
# reference x86-64 encoders proved to invert decode, extracted and held byte-identical to holo
encver = enc:1792:reg-direct encmem:6144:memory encli:320:immediate
test_encver: host $(rocq_std)/.built
	@echo TEST test/proof/rocq/enc.v test/proof/rocq/encmem.v test/proof/rocq/encli.v "(coqc round-trip proofs -> ocaml refs vs holo, byte-exact)"
	@cd test/proof/rocq && $(coqc) -q enc.v >/dev/null && $(coqc) -q encmem.v >/dev/null && $(coqc) -q encli.v >/dev/null \
	  && rm -f enc_ref.mli encmem_ref.mli encli_ref.mli \
	  && $(OCAMLOPT) -w -a enc_ref.ml enc_drive.ml -o enc_drive >/dev/null \
	  && $(OCAMLOPT) -w -a encmem_ref.ml encmem_drive.ml -o encmem_drive >/dev/null \
	  && $(OCAMLOPT) -w -a encli_ref.ml encli_drive.ml -o encli_drive >/dev/null
	@for s in $(encver); do n=$${s%%:*}; r=$${s#*:}; c=$${r%%:*}; l=$${r#*:}; \
	   o=out/.$${n}_oracle; \
	   test/proof/rocq/$${n}_drive > $$o.l; \
	   { cat src/love/holo/holo.l src/love/holo/x64.l; echo "(borrow 'holo)"; cat $$o.l; } | $m > $$o.out 2>&1; r=$$?; \
	   { [ $$r -eq 0 ] && grep -q "$$c / $$c PASS" $$o.out; } \
	     || { echo "FAIL the $$n oracle, $$l (exit $$r):"; cat $$o.out; exit 1; }; \
	   cat $$o.out; done
	@$(call vclean,enc encmem encli)
	@$(call dclean,enc encmem encli)
	@rm -f test/proof/rocq/*.cmi test/proof/rocq/*.cmx test/proof/rocq/*.o out/.enc_oracle.* out/.encmem_oracle.* out/.encli_oracle.*
endif

# src/tools/uu2lean.l: the uu corpus re-checked by Lean 4, a second kernel
ifeq ($(LEAN),)
test_uulean:
	@sh test/gate/skip.sh gate-skip "test_uulean: skipped (needs lean)"
else
test_uulean: host
	@mkdir -p test/proof/lean
	@echo 'LOVE	'test/proof/lean/uugen.lean "(src/tools/uu2lean.l on $m)"
	@$m src/tools/uu2lean.l > test/proof/lean/uugen.lean
	@echo TEST test/proof/lean/uugen.lean "(lean)"
	@$(LEAN) test/proof/lean/uugen.lean > out/.uulean.out 2>&1; r=$$?; \
	  if [ $$r -ne 0 ] || grep -q sorryAx out/.uulean.out; then cat out/.uulean.out; exit 1; fi
endif

# random IR via holo against objdump and llvm-mc; a missing disassembler skips its lane.
# peaks ~120 MB, rvc ~310 MB and ~13 min; the disassemblers are not love and take no budget
test_holofuzz: host
	@echo TEST test/holo/fuzz/fuzz.l "(holo x64+a64+riscv encoder differential fuzz)"
	@FUZZ_N=8 FUZZ_SEED=20250717 LOVE_BUDGET_MB=400 timeout 300 $m test/holo/fuzz/fuzz.l \
	  || { $(fuzzlate); echo "FAIL holofuzz -- a holo encoding disagrees with its disassembler"; exit 1; }
	@if command -v llvm-mc >/dev/null 2>&1; then \
	   LOVE_BUDGET_MB=400 timeout 120 $m test/holo/fuzz/sysdiff.l \
	     || { $(fuzzlate); echo "FAIL sysdiff -- a holo SYSTEM encoding disagrees with llvm-mc"; exit 1; }; \
	 else . test/gate/skip.sh; gate_partly "  (sysdiff skipped: no llvm-mc)"; fi
	@LOVE_BUDGET_MB=400 timeout 2700 $m test/holo/fuzz/rvc.l \
	  || { $(fuzzlate); echo "FAIL rvc -- an RVC squeeze changes what the word means"; exit 1; }
# generated uu corpora: a design's code as uu terms for its *law.l. `make <stem>` refreshes,
# test_<stem> diffs
# $1 the stem, $2 its generator under src/tools/, $3 the source it reads
define uu_corpus
$1: host
	@echo 'LOVE	'test/$1.l "(src/tools/$2.l on $$m)"
	@$$m src/tools/$2.l > test/$1.l
test_$1: host
	@echo TEST test/$1.l "(regenerate + diff)"
	@$$m src/tools/$2.l > out/.$1.l.tmp
	@cmp -s out/.$1.l.tmp test/$1.l \
	  || { echo "FAIL: test/$1.l is stale ($3 moved?) -- run: make $1"; exit 1; }
	@rm -f out/.$1.l.tmp
endef
$(eval $(call uu_corpus,uuwm,uuwmgen,src/apps/lux/core.l))   # lux's zipper ops
$(eval $(call uu_corpus,uukind,kinds2uu,test/proto/kinds.l))   # the kinds-lattice join
$(eval $(call uu_corpus,uuhomgen,dest2uu,test/proto/dest.l))   # dest.l's code generators
$(eval $(call uu_corpus,uusplgen,spl2uu,test/proto/spl.l))   # spl.l's call-site compilers
$(eval $(call uu_corpus,uumx,mx2uu,src/love/mx.l))   # the +/* dispatch matrices
$(eval $(call uu_corpus,uuvallaw,law2uu,test/law.l))   # test/law.l's rows, where they stand
# test_wake: bake then wake a copy; a fresh image checks uu in ~1s, a storming one >90s, so the
# timeout is the assertion
test_wake: $(ho)/love
	@echo TEST wake "(the woken-image lane)"
	@cp $(ho)/love $(ho)/love.wake && $(ho)/love.wake bake
	@# a refused image boots the egg, as fast and crewless: the crew is the tell
	@if ! $(ho)/love.wake -q -e "(quit (nil? (cite 'cook)))"; \
	  then echo "test_wake: the baked image was REFUSED -- this is an egg boot"; \
	       rm -f $(ho)/love.wake; exit 1; fi
	@cat test/00-init.l test/uu.l > $(ho)/wake-corpus.l
	@if timeout 60 $(ho)/love.wake $(ho)/wake-corpus.l > /dev/null 2>&1; \
	  then echo "test_wake: green (the woken image checks uu at speed)"; rm -f $(ho)/love.wake $(ho)/wake-corpus.l; \
	  else echo "test_wake: FAILED -- the woken image storms"; rm -f $(ho)/love.wake $(ho)/wake-corpus.l; exit 1; fi

# --- the metal gates; kernel build rules stay in the root Makefile ---

ifeq ($a,x64)

test_disk: host $(S)/tools/ktest.l
	@$(MAKE) -s $(k_elf)
	@rm -f $(k_elf).disk
	@echo TEST $(k_elf) "(the WAKE lane: two boots, one disk, the reset-persistence gate)"
	@$m $(S)/tools/ktest.l $(k_elf) - $a
	@$m $(S)/tools/ktest.l $(k_elf) - $a "disk: fat kept across the reset"
	@echo "test_disk: the machine remembered"

# wget against a live https peer: opt-in, it needs the internet (test/host/wgetnet.l)
test_wgetnet: host
	@echo TEST test/host/wgetnet.l "(wget over TLS 1.3 to a live peer)"
	@cat test/00-init.l test/host/wgetnet.l | $(gsh) test/gate/run.sh wgetnet "$m" "wgetnet: ok"

# the doom lanes: their source and IWAD fetched into dl/ first, else a loud skip; then the lane
test_doomx test_doomwasm:
	@DL=$(dl) sh test/gate/dl.sh doomgeneric doom1.wad || exit 1; \
	 if [ -d $(dl)/doomgeneric ] && [ -f $(dl)/doom1.wad ]; then $(MAKE) -s $@-run; \
	 else sh test/gate/skip.sh gate-skip "$@: skipped (no dl/doomgeneric or dl/doom1.wad: could not fetch them)"; fi

# doom on X under Xvfb: opt-in
test_doomx-run: $(R)/test/host/doomx.l
	@$(MAKE) -s host DOOM=1
	@echo TEST test/host/doomx.l "(doom on X, 300 frames under Xvfb, a held key)"
	@cat test/00-init.l test/host/doomx.l | $(gsh) test/gate/run.sh doomx "$R/out/doom/love" "doomx: ok"

test_kverb: host
	@$(MAKE) -s $(k_elf)
	@echo TEST love kernel "(the projection verb; byte-identical to make's)"
	@rm -f $(ko)/.kverb.elf
	@cd $(ko) && $(abspath $m) kernel .kverb.elf > /dev/null
	@cmp $(ko)/.kverb.elf $(k_elf)
	@rm -f $(ko)/.kverb.elf

test_kboot: host $(S)/tools/kboot.l
	@$(MAKE) -s $(k_elf)
	@echo TEST $(k_elf) "(the kore cat off cmdline; 4 boots, ceiling 420s each)"
	@$m $(S)/tools/kboot.l $(k_elf) "ls /love/src/apps/kore" "kore.l"
	@$m $(S)/tools/kboot.l $(k_elf) "wc /love/src/apps/json.l" "/love/src/apps/json.l" $$(wc -c < $(S)/apps/json.l)
	@$m $(S)/tools/kboot.l $(k_elf) "sh -c \"cd /love/src/apps/kore; pwd\"" "/love/src/apps/kore"
	@$m $(S)/tools/kboot.l $(k_elf) "sh -c \"ls /love/src/apps/kore | wc -l\"" $$(ls $(S)/apps/kore | wc -l)

# the vmx laws boot on a bee host with cap vt-x (kvm, -cpu host); test_extra only
test_kernel_vmx: host $(S)/tools/ktest.l
	@if ! $m bee --on vt-x --probe; then \
	   sh test/gate/skip.sh gate-skip "test_kernel_vmx: skipped (no host with vt-x answers, a VT-x box to boot on)"; exit $$?; fi; \
	 $(MAKE) -s $(k_elf) && \
	 echo TEST $(k_elf) "(the vmx lane: kvm and -cpu host on a vt-x host)" && \
	 KTEST_CAP=vt-x KTEST_CORPUS=test/kernel/vmx-lane.l \
	   $m $(S)/tools/ktest.l $(k_elf) - $a "vmx: guest ran, cpuid exited"

# a mooncc-built C program at /proc/initrd run in ring 3, then love itself as processes
test_kernel_uproc: host $(S)/tools/ktest.l
	@$(MAKE) -s $(k_elf)
	@mkdir -p $(ko)/uproc && $(ho)/love mooncc test/kernel/c/hello.c -o $(ko)/uproc/hello
	@echo TEST $(k_elf) "(C programs and love as x64 processes: ring 3, address spaces of their own)"
	@KTEST_CORPUS=test/kernel/uproc-lane.l KTEST_INITRD=$(ko)/uproc/hello \
	   $m $(S)/tools/ktest.l $(k_elf) - $a "uproc: ok"

# an empty boot line is a mitty on the console: keys by qemu's monitor, lush, exit, reset
test_kmitty: host test/gate/kmitty.l
	@$(MAKE) -s $(k_elf)
	@echo TEST $(k_elf) "(the console a mitty: an empty boot line, keys by sendkey)"
	@$m test/gate/kmitty.l $(k_elf)
else
test_disk test_kboot test_kernel_vmx test_kernel_uproc test_kmitty:
	@sh test/gate/skip.sh gate-skip "$@: skipped (host arch $a is not x64)"
endif

# the firmware is fetched into dl/ by the lane itself; a failed fetch skips
ifneq ($a,x64)
test_uefi:
	@sh test/gate/skip.sh gate-skip "test_uefi: skipped (host arch $a is not x64)"
else
test_uefi: host $(S)/tools/ktest.l
	@DL=$(dl) sh test/gate/dl.sh edk2-ovmf || exit 1; fw=$(dl)/edk2-ovmf/ovmf-code-x86_64.fd; \
	 if [ ! -f $$fw ]; then sh test/gate/skip.sh gate-skip "test_uefi: skipped (no dl/edk2-ovmf: could not fetch it)"; else \
	 $(MAKE) -s $(ko)/esp-x64/EFI/BOOT/BOOTX64.EFI $(ko)/esp-x64/love.elf $(ko)/esp-x64/love.cmd \
	 && echo TEST $(ko)/esp-x64 "(serial, headless, our own BOOTX64.EFI; ~64s, ceiling 420s)" \
	 && $m $(S)/tools/ktest.l $(ko)/esp-x64 $$fw x64; fi
endif

QEMU_A64 ?= $(shell command -v qemu-system-aarch64 2>/dev/null)
ifeq ($(QEMU_A64),)
test_uefi_a64:
	@sh test/gate/skip.sh gate-skip "test_uefi_a64: skipped (qemu-system-aarch64 needed)"
else
test_uefi_a64: host $(S)/tools/ktest.l
	@DL=$(dl) sh test/gate/dl.sh edk2-ovmf || exit 1; fw=$(dl)/edk2-ovmf/ovmf-code-aarch64.fd; \
	 if [ ! -f $$fw ]; then sh test/gate/skip.sh gate-skip "test_uefi_a64: skipped (no dl/edk2-ovmf: could not fetch it)"; else \
	 $(MAKE) -s a=a64 $(ko)/esp-a64/EFI/BOOT/BOOTAA64.EFI $(ko)/esp-a64/love.elf $(ko)/esp-a64/love.cmd \
	 && echo TEST $(ko)/esp-a64 "(serial, headless, our own BOOTAA64.EFI; TCG, ceiling 900s)" \
	 && $m $(S)/tools/ktest.l $(ko)/esp-a64 $$fw a64; fi
endif

# rv64's tcg corpus nears its ceiling beside anything, so it boots alone first; then the rest
# at once, an arch's lanes in turn (they share its disk). the tree first: selfpack writes it
inle_rv64 = test_kernel_rv64
inle_x64 = test_disk test_uefi test_kboot test_kernel_uproc test_kmitty test_kverb
inle_wasm = test_kernel_wasm
inle_a64 = test_kernel_a64 test_uefi_a64
test_inle: host
	@$(MAKE) -s $(src_tree) out/rootfs.tar
	@rm -rf out/inle && mkdir -p out/inle
	@$(MAKE) -s inle-rv64
	@$(MAKE) -s $(if $(findstring jobserver,$(MAKEFLAGS)),,-j4) inle-x64 inle-wasm inle-a64
	@echo "test_inle: boot, disk, command line, firmware -- the three arches and the wasm seat"
inle-%:
	@for l in $(inle_$*); do $(MAKE) -s $$l || { echo "FAIL $$l"; exit 1; }; done > out/inle/$*.log 2>&1; \
	 r=$$?; cat out/inle/$*.log; exit $$r

ifeq ($(QEMU_A64),)
test_kernel_a64:
	@sh test/gate/skip.sh gate-skip "test_kernel_a64: skipped (need qemu-system-aarch64)"
else
test_kernel_a64: host $(S)/tools/ktest.l
	@$(MAKE) -s a=a64 $(ko)/love-a64.elf
	@echo TEST $(ko)/love-a64.elf "(the WARM lane: serial, headless, -kernel; kvm on a kvm-a64 host, else TCG, ceiling 900s)"
	@$m $(S)/tools/ktest.l $(ko)/love-a64.elf - a64
endif

QEMU_RV64 ?= $(shell command -v qemu-system-riscv64 2>/dev/null)
ifeq ($(QEMU_RV64),)
test_kernel_rv64:
	@sh test/gate/skip.sh gate-skip "test_kernel_rv64: skipped (need qemu-system-riscv64)"
else
test_kernel_rv64: host $(S)/tools/ktest.l
	@$(MAKE) -s a=rv64 $(ko)/love-rv64.elf
	@echo TEST $(ko)/love-rv64.elf "(the WARM lane: serial, headless, TCG, -kernel; ceiling 1200s)"
	@$m $(S)/tools/ktest.l $(ko)/love-rv64.elf - rv64
endif

NODE ?= $(shell command -v node 2>/dev/null)
WASMOPT ?= $(shell command -v wasm-opt 2>/dev/null)
wasmopt_flags = --enable-memory64 --enable-bulk-memory --enable-nontrapping-float-to-int
holo_wasm = out/.holo.wasm out/.holo2.wasm out/.holo3.wasm
ifeq ($(NODE),)
test_kernel_wasm test_doomwasm-run test_seedwasm test_nestwasm test_holowasm:
	@sh test/gate/skip.sh gate-skip "$@: skipped (needs node)"
else
# test_kernel_wasm -- the kernel corpus on out/love.wasm's woken image, the (reset) read as the exit.
# INLE_RAM is fixed at boot, and the default 256 is short
test_kernel_wasm: host
	@$(MAKE) -s wasm
	@echo TEST out/love.wasm "(node: the kernel corpus on the woken image, serial, headless; /mnt/host a fresh directory)"
	@rm -rf $(ko)/wasm/host && mkdir -p $(ko)/wasm/host
	@INLE_RAM=768 $(NODE) $(S)/inle/wasm/inle.mjs --host $(R)/$(ko)/wasm/host --image $(ko)/wasm/love.image $(R)/$(ko)/love.wasm test/kernel/all.l \
	   < /dev/null > $(ko)/wasm/kernel.log 2>&1; \
	 grep -q "image awake" $(ko)/wasm/kernel.log \
	   && grep -qx "the seat keeps this" $(ko)/wasm/host/kept.txt \
	   && grep -q "tests pass" $(ko)/wasm/kernel.log && ! grep -q "failed:" $(ko)/wasm/kernel.log \
	   && ! grep -q "^0 tests pass" $(ko)/wasm/kernel.log \
	   || { tail -20 $(ko)/wasm/kernel.log; echo "FAIL test_kernel_wasm"; exit 1; }
	@grep "tests pass" $(ko)/wasm/kernel.log
	@echo TEST test/kernel/glass.l "(the console's grid, and its text across a re-made one)"
	@$(gsh) $(R)/test/gate/glass.sh $(NODE) $(R)/out/love.wasm out/wasm/love.image out/wasm/glass.log $m
	@echo TEST test/gate/glass.mjs "(the page's half of the grid, asked without a page)"
	@$(NODE) $(R)/test/gate/glass.mjs || { echo "FAIL test_kernel_wasm"; exit 1; }
	@echo TEST test/gate/wall.mjs "(what a link and a guest may ask of the page, asked without a page)"
	@$(NODE) $(R)/test/gate/wall.mjs || { echo "FAIL test_kernel_wasm"; exit 1; }
	@echo TEST test/gate/worklet.mjs "(the page's speaker, asked without a page)"
	@$(NODE) $(R)/test/gate/worklet.mjs || { echo "FAIL test_kernel_wasm"; exit 1; }
	@echo TEST test/gate/echo.mjs "(a keystroke reaches the glass, not just the guest)"
	@$(NODE) $(R)/test/gate/echo.mjs $(R)/out/love.wasm out/wasm/love.image out/wasm/echo \
	   || { echo "FAIL test_kernel_wasm"; exit 1; }
	@echo TEST test/gate/point.mjs "(the page's pointer and clipboard: select, copy, paste, the wheel)"
	@$(NODE) $(R)/test/gate/point.mjs $(R)/out/love.wasm out/wasm/love.image out/wasm/point.log \
	   || { echo "FAIL test_kernel_wasm"; exit 1; }
	@echo TEST test/gate/grab.mjs "(a window's grab: the page's lock, motions, a warp)"
	@$(NODE) $(R)/test/gate/grab.mjs $(R)/out/love.wasm out/wasm/love.image out/wasm/grab.log \
	   || { echo "FAIL test_kernel_wasm"; exit 1; }
	@echo TEST test/kernel/winrun.l "(a window on the paper: its pixels shown, keys by place, the pointer, the text)"
	@rm -f out/wasm/winrun.ppm
	@printf 'hi\033[A!' | INLE_RAM=256 $(NODE) $(S)/inle/wasm/inle.mjs --fb 640x400 --dump out/wasm/winrun.ppm \
	   --after "winrun: paper" --press "KeyA ArrowUp KeyQ" --click 100,50 --for 120 \
	   --image out/wasm/love.image $(R)/out/love.wasm test/kernel/winrun.l > out/wasm/winrun.log 2>&1; \
	 grep -q "winrun: paper 640x400 shown 400" out/wasm/winrun.log \
	   && grep -q 'winrun: (text "hi!")' out/wasm/winrun.log \
	   && grep -q "winrun: (down 30)" out/wasm/winrun.log && grep -q "winrun: (up 30)" out/wasm/winrun.log \
	   && grep -q "winrun: (down 328)" out/wasm/winrun.log && grep -q "winrun: (up 16)" out/wasm/winrun.log \
	   && grep -q "winrun: (press 1 100 50)" out/wasm/winrun.log \
	   && grep -q "winrun: (release 1 100 50)" out/wasm/winrun.log \
	   && $(NODE) $(R)/test/gate/ppmcolor.mjs out/wasm/winrun.ppm 255,128,0 \
	   || { tail -12 out/wasm/winrun.log; echo "FAIL test_kernel_wasm (the window)"; exit 1; }
	@echo TEST test/gate/idle.mjs "(the machine still sleeps once it has been typed at)"
	@$(NODE) $(R)/test/gate/idle.mjs $(R)/out/love.wasm out/wasm/love.image out/wasm/idle.log \
	   || { tail -5 out/wasm/idle.log; echo "FAIL test_kernel_wasm"; exit 1; }
	@echo TEST test/kernel/horn.l "(the horn: a ramp through the port and out of the machine)"
	@INLE_RAM=256 $(NODE) $(S)/inle/wasm/inle.mjs --horn out/wasm/horn.raw --image out/wasm/love.image \
	   $(R)/out/love.wasm test/kernel/horn.l < /dev/null > out/wasm/horn.log 2>&1; \
	 grep -q "horn wrote 80000" out/wasm/horn.log \
	   || { tail -20 out/wasm/horn.log; echo "FAIL test_kernel_wasm (the horn refused the machine)"; exit 1; }
	@$m $(R)/test/gate/horn.l out/wasm/horn.raw || { echo "FAIL test_kernel_wasm"; exit 1; }
	@echo TEST "the fetch door (wget aboard, off --origin, the tree standing in for the page)"
	@INLE_RAM=256 $(NODE) $(S)/inle/wasm/inle.mjs --origin $(R) --image out/wasm/love.image $(R)/out/love.wasm \
	   sh -c 'mkdir -p /s; wget -O /s/v /VERSION && cmp /s/v /love/VERSION && echo fetch: ok; wget -q -O /s/no /no-such-file; echo missing: $$?' \
	   < /dev/null > out/wasm/fetch.log 2>&1; \
	 grep -q "fetch: ok" out/wasm/fetch.log && grep -q "missing: 4" out/wasm/fetch.log \
	   || { tail -8 out/wasm/fetch.log; echo "FAIL test_kernel_wasm (the fetch door)"; exit 1; }
	@echo TEST test/kernel/horn.l "(--deaf: the machine outlives a speaker that stopped taking)"
	@timeout 120 $(NODE) $(S)/inle/wasm/inle.mjs --deaf --image out/wasm/love.image \
	   $(R)/out/love.wasm test/kernel/horn.l < /dev/null > out/wasm/deaf.log 2>&1; \
	 grep -q "horn wrote 80000" out/wasm/deaf.log \
	   || { tail -5 out/wasm/deaf.log; echo "FAIL test_kernel_wasm (a dead speaker stopped the machine)"; exit 1; }
	@echo "  deaf: ok -- the ring fills, nobody empties it, and the walk goes on"
	@echo TEST test/kernel/lift.l "(the lift: a path written to /proc/lift, and the file lands outside)"
	@rm -f out/wasm/lifted.txt; INLE_RAM=256 $(NODE) $(S)/inle/wasm/inle.mjs --lifts out/wasm \
	   --image out/wasm/love.image $(R)/out/love.wasm test/kernel/lift.l < /dev/null > out/wasm/lift.log 2>&1; \
	 grep -q "lift asked" out/wasm/lift.log && grep -q "carried out of the machine, whole" out/wasm/lifted.txt \
	   || { tail -5 out/wasm/lift.log; echo "FAIL test_kernel_wasm (the lift did not land)"; exit 1; }
	@echo "  lift: ok -- the file came out under its own name"
	@echo TEST test/gate/seatwall.sh "(what the seat refuses a guest: host files past --origin, lifts nobody asked for)"
	@$(gsh) $(R)/test/gate/seatwall.sh $(NODE) $(R)/out/love.wasm out/wasm/love.image out/wasm/seatwall \
	   || { echo "FAIL test_kernel_wasm (the seat's wall)"; exit 1; }
	@echo TEST test/kernel/pkcheck.l "(harp's pack: the two arms answer the same bytes HERE)"
	@$(NODE) $(S)/inle/wasm/inle.mjs --image out/wasm/love.image $(R)/out/love.wasm \
	   test/kernel/pkcheck.l < /dev/null > out/wasm/pack.log 2>&1; \
	 grep -q "gain 20000     1" out/wasm/pack.log && grep -q "gain 900000    1" out/wasm/pack.log \
	   && grep -q "gain 100       1" out/wasm/pack.log \
	   || { cat out/wasm/pack.log; echo "FAIL test_kernel_wasm (pack differs on this seat)"; exit 1; }
	@echo "  pack: ok -- pinv and the byte loop agree where the float-to-int is not the host's"
	@echo TEST test/kernel/proc.l "(a process: love in memory of its own, its calls through the kernel)"
	@INLE_RAM=512 $(NODE) $(S)/inle/wasm/inle.mjs --image out/wasm/love.image $(R)/out/love.wasm \
	   test/kernel/proc.l < /dev/null > out/wasm/proc.log 2>&1; \
	 grep -qx "proc: ok" out/wasm/proc.log || { tail -5 out/wasm/proc.log; echo "FAIL test_kernel_wasm (proc)"; exit 1; }
	@echo "  proc: ok -- its own cwd and environment, its stdio, and its status back"
	@echo TEST test/kernel/spawn.l "(a process starts processes: spawn, wait, kill, the shell's pipelines)"
	@INLE_RAM=768 $(NODE) $(S)/inle/wasm/inle.mjs --image out/wasm/love.image $(R)/out/love.wasm \
	   test/kernel/spawn.l < /dev/null > out/wasm/spawn.log 2>&1; \
	 grep -qx "spawn: ok" out/wasm/spawn.log || { tail -5 out/wasm/spawn.log; echo "FAIL test_kernel_wasm (spawn)"; exit 1; }
	@echo "  spawn: ok -- a pipeline of love processes, the shell's own stages, kill and wait"
	@echo TEST test/kernel/cprog.l "(a C program is a process: mooncc's wasm, by path and on PATH, in a pipeline)"
	@rm -rf out/wasm/cprog && mkdir -p out/wasm/cprog
	@for c in hello cat; do $(ho)/love mooncc -t wasm test/kernel/c/$$c.c -o out/wasm/cprog/$$c.wasm || exit 1; done
	@INLE_RAM=768 $(NODE) $(S)/inle/wasm/inle.mjs --host $(R)/out/wasm/cprog --image out/wasm/love.image $(R)/out/love.wasm \
	   test/kernel/cprog.l < /dev/null > out/wasm/cprog.log 2>&1; \
	 grep -qx "cprog: ok" out/wasm/cprog.log || { tail -5 out/wasm/cprog.log; echo "FAIL test_kernel_wasm (cprog)"; exit 1; }
	@echo "  cprog: ok -- a C hello and a C cat, as the process shell and the kernel's run them"

# doom on wasm: draws, sounds, quits from its menu by key (a game deaf to keys outruns --for).
# DOOM=1 builds in out/doom; then kexec boots it off the origin
test_doomwasm-run:
	@$(MAKE) -s wasm DOOM=1
	@echo TEST test/kernel/doomrun.l "(doom on the wasm seat: a frame, the horn, and quit by key)"
	@rm -f out/wasm/doom.ppm out/wasm/doom.raw
	@INLE_RAM=512 $(NODE) $(S)/inle/wasm/inle.mjs --fb 640x400 --dump out/wasm/doom.ppm --horn out/wasm/doom.raw \
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
	@INLE_RAM=512 $(NODE) $(S)/inle/wasm/inle.mjs --fb 640x400 --dump out/wasm/kexec.ppm --origin out/wasm/origin \
	   --after "I_InitGraphics: Auto-scaling" --press "Escape ArrowUp Enter KeyY" --for 300 \
	   --image out/wasm/love.image $(R)/out/love.wasm test/kernel/kexec.l \
	   < /dev/null > out/wasm/kexec.log 2>&1 \
	 && grep -q "inle: booting /d.wasm" out/wasm/kexec.log \
	 && grep -q "I_InitGraphics: DOOM screen size" out/wasm/kexec.log \
	 && grep -q "doom-rc=0" out/wasm/kexec.log && test -s out/wasm/kexec.ppm \
	   || { tail -20 out/wasm/kexec.log; echo "FAIL test_doomwasm (kexec)"; exit 1; }
	@echo "  kexec: ok -- fetched, booted, drawn, and quit"

# test_seedwasm -- `love seed x64` on wasm, nothing under it. the collector gets an eighth of
# INLE_RAM; selfpack needs 768. ~6 minutes, opt-in
test_seedwasm: host
	@$(MAKE) -s wasm
	@echo TEST "love seed x64 (the wasm seat, nothing under it)"
	@rm -f out/wasm/love-x64
	@INLE_RAM=1024 $(NODE) $(S)/inle/wasm/inle.mjs --lifts out/wasm \
	   --image out/wasm/love.image $(R)/out/love.wasm seed x64 /s \
	   < /dev/null > out/wasm/seed.log 2>&1; \
	 grep -q "a raw egg for x64" out/wasm/seed.log \
	   && grep -q "carried out of the machine" out/wasm/seed.log && test -s out/wasm/love-x64 \
	   || { tail -20 out/wasm/seed.log; echo "FAIL test_seedwasm"; exit 1; }
	@chmod +x out/wasm/love-x64
	@$(if $(filter x64,$(hosta)),sh test/gate/seedegg.sh out/wasm/love-x64,echo "  the egg is x64 and this box is $(hosta): laid, not run")

# test_nestwasm -- the wasm module rebuilt aboard the wasm kernel (LOVE=love on cook's line: a
# task shares no environment). ~15 minutes, opt-in
test_nestwasm:
	@$(MAKE) -s wasm
	@echo TEST test/kernel/nest.l "(the wasm module rebuilt aboard the wasm seat)"
	@INLE_RAM=1024 $(NODE) $(S)/inle/wasm/inle.mjs --for 2400 \
	   --image out/wasm/love.image $(R)/out/love.wasm test/kernel/nest.l \
	   < /dev/null > out/wasm/nest.log 2>&1; \
	 grep -q "nest: cook wasm answered 0, the module stands" out/wasm/nest.log \
	   || { tail -20 out/wasm/nest.log; echo "FAIL test_nestwasm"; exit 1; }
	@echo "  nestwasm: ok -- laid, built and linked aboard"

# holo's wasm writer: three modules, wasm-opt if present, run by node, and the fuzz vs its model
test_holowasm: host
	@echo TEST test/holo/wasm.l
	@cat src/love/holo/holo.l src/love/holo/wasm.l src/love/holo/wasmfn.l test/holo/wasm.l | $m
	@$(if $(WASMOPT),for w in $(holo_wasm); do $(WASMOPT) $(wasmopt_flags) $$w -o /dev/null 2>/dev/null || exit 1; done && echo "  wasm-opt: all valid",echo "  wasm-opt: absent, node alone validates")
	@$(NODE) test/holo/wasm.mjs out/.holo.wasm out/.holo2.wasm
	@$(NODE) test/holo/loader.mjs out/.holo3.wasm
	@echo TEST test/holo/fuzz/wasm.l "(the wasm lane's second opinion: v8 against the model)"
	@cat src/love/holo/holo.l src/love/holo/wasm.l src/love/holo/wasmfn.l test/holo/fuzz/wasm.l | $m
	@$(NODE) test/holo/fuzz/wasm.mjs out/.wasmfuzz.wasm out/.wasmfuzz.json
endif

# --- the two binary-shape gates, both skipping when their tool is absent ---

OBJDUMP_ANY := $(shell command -v objdump 2>/dev/null || command -v llvm-objdump 2>/dev/null)
ifeq ($(OBJDUMP_ANY),)
vmret: host
	@sh test/gate/skip.sh gate-skip "vmret: skipped (needs objdump or llvm-objdump)"
else
vmret: host
	@$m src/tools/vmret.l $m
endif

# the .c files from the tree's own listing (selfpack -l); an empty one is a refusal, never a pass
waits: host
	@fs=$$($m src/tools/selfpack.l -l | grep '\.c$$'); [ -n "$$fs" ] || { echo "FAIL waits: no .c files listed"; exit 1; }; \
	 $m src/tools/waits.l $$fs

# a gate script run whole by name: test_X runs test/gate/X.sh
$(gate_love): test_%: host
	@echo TEST test/gate/$*.sh
	@$(gsh) test/gate/$*.sh $(ho)/love
$(gate_m): test_%: host
	@echo TEST test/gate/$*.sh
	@$(gsh) test/gate/$*.sh $m
$(gate_hol): test_%: host
	@echo TEST test/gate/$*.sh
	@$(gsh) test/gate/$*.sh $(ho) $(ho)/love
$(gate_cc): test_%: host
	@echo TEST test/gate/$*.sh
	@$(gsh) test/gate/$*.sh gcc clang
$(gate_hm): test_%: host
	@$(gsh) test/gate/$*.sh $(ho) $m
$(gate_ho): test_%: host
	@$(gsh) test/gate/$*.sh $(ho)
