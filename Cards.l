; Cards.l -- the project's build, as a cook recipe. make, in ai, building ai.
;
; run it with the cook.mk front door (`make -f cook.mk test`) or straight:
;     out/host/ai -l tools/cook.l Cards.l [ticket]
; the first recipe ('all) is the default ticket.
;
; SCOPE: the cross-cutting verbs + the host build. one rung is DELEGATED to the
; real Makefile rather than re-expressed here, on purpose:
;   * host -- the C bootstrap (ai0 -> reflect data.h -> the ai binary) is
;     circular for cook: building ai needs ai. make owns that rung; this recipe
;     just leans on it (and make no-ops when the binary is already current).
; everything else (test, clean, valg, vmret, bench, install) is the genuine command, ported.
; the kernel/wasm/qemu/repl verbs stay with make (cook's `run` captures stdout and
; waits, so it can't drive qemu, a tty repl, or stream a sub-make) -- cook.mk hands
; those straight through.

; the corpus, in the Makefile's order: the harness first (00-init), the spec
; second (CLAUDE.l), then the rest of test/*.l sorted. built once as a shell word.
(: corpus "test/00-init.l CLAUDE.l $(ls test/*.l | grep -v 00-init)")

; --- the default ticket ----------------------------------------------------------
; all -- the host build. kernel and wasm are make-delegated (see header), so the
; default here is the host binary, exactly as a bare `make` lands on host first.
(recipe 'all '(host) 0)

; --- the host binary (delegated bootstrap) -------------------------------------
(recipe 'host '() '(("make" "host")))

; --- the fast gate -------------------------------------------------------------
; test = the host corpus + the self-hosted ai0, each of which MUST print the
; zz-fin "tests pass" summary -- exit 0 alone is a lie (a reader stop drops the
; rest of the stream and still exits 0). ai0 prints it TWICE (c0 then ev).
(recipe 'test '(host)
      (L (L "sh" "-c"
            (+ "o=out/host/.test_host; cat " (+ corpus
               " | out/host/ai >$o 2>&1; cat $o; grep -q 'tests pass' $o")))
         '("sh" "-c"
            "o=out/host/.test_ai0; out/host/ai0 </dev/null >$o 2>&1; cat $o; [ $(grep -c 'tests pass' $o) -eq 2 ]")))

; --- the corpus under valgrind -------------------------------------------------
(recipe 'valg '(host)
      (L (L "sh" "-c"
            (+ "cat " (+ corpus
               " | valgrind --error-exitcode=1 --suppressions=tools/valgrind.supp out/host/ai")))))

; --- the VM no-return invariant ------------------------------------------------
(recipe 'vmret '(host) '(("out/host/ai" "tools/vmret.l" "out/host/ai")))

; --- benchmarks ----------------------------------------------------------------
(recipe 'bench '(host) '(("make" "-C" "bench" "bench")))

; --- clean ---------------------------------------------------------------------
(recipe 'clean '() '(("rm" "-rf" "out") ("make" "-C" "wasm" "clean")))

; --- install (ported) ----------------------------------------------------------
; mirror `make install`: copy the binary, libs, header, manpage and vim files
; under $DESTDIR/$PREFIX (and $DESTDIR/$VIMPREFIX for the vim files), with the
; Makefile's env-overridable defaults. `install -D` makes the parent dirs; -s
; strips the binary and the shared lib. the .a/.so land in lib/ beside lib/ai/.
(recipe 'install '(host)
   (: (getdef k dv) (: e (getenv k) (? e e dv))
      dest (getdef "DESTDIR" (+ (getenv "HOME") "/"))
      d (+ (+ dest "/") (getdef "PREFIX" ".local/"))        ; $(DESTDIR)/$(PREFIX)
      vd (+ (+ dest "/") (getdef "VIMPREFIX" ".vim/"))       ; $(DESTDIR)/$(VIMPREFIX)
      (at dir sub) (+ (+ dir "/") sub)                       ; dir/sub
      (cp mode src dst) (L "install" "-D" "-m" mode src dst)
      (cps mode src dst) (L "install" "-D" "-m" mode "-s" src dst)
      (L (cps "755" "out/host/ai"        (at d "bin/ai"))
         (cp  "644" "out/host/ai.1"       (at d "share/man/man1/ai.1"))
         (cp  "644" "ai/prel.l"        (at d "lib/ai/prel.l"))
         (cp  "644" "ai/ev.l"             (at d "lib/ai/ev.l"))
         (cp  "644" "ai/repl.l"           (at d "lib/ai/repl.l"))
         (cp  "644" "out/host/libai.a"    (at d "lib/libai.a"))
         (cps "755" "out/host/libai.so"   (at d "lib/libai.so"))
         (cp  "644" "ai.h"                (at d "include/ai.h"))
         (cp  "644" "vim/ftdetect.vim"      (at vd "ftdetect/ai.vim"))
         (cp  "644" "vim/syntax.vim"        (at vd "syntax/ai.vim"))
         (cp  "644" "vim/ftplugin.vim"      (at vd "ftplugin/ai.vim")))))

(cook (ticket 0))
