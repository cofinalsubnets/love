; hearts' build: kbuild's goals made by hearts (kbuild.l) in this directory, the output dir,
; from the kernel tree $HEARTS_SRC. each command runs through lush with kore's verbs ahead of
; PATH (sh, sed, cat, ..), so only the borrowed compiler and linker reach the host, and $(shell)
; is answered there too. `--sub ARGS` is the make a recipe's own
; script execs (link-vmlinux.sh's ${MAKE}), started from the environment.
;
; $HEARTS_GOALS  the goals, each made from a fresh read of the Makefile (default
;                "defconfig syncconfig Image": syncconfig is the included auto.conf that
;                make would remake and restart for)
; $HEARTS_JOBS   commands in flight at once (default 1); a filechk and a sub-make's script run
;                here, in order
; $HEARTS_PRIOR  1: an earlier build's .cmd files stand as the prior state (hk-make's " prior")
; $KBUILD_BUILD_USER/HOST/VERSION/TIMESTAMP  the build's identity, handed in as the command
;                line's, so no clock or host name reaches the image
; $HEARTS_HOSTCC the compiler the host programs build with (kconfig's conf, fixdep, dtc, ..),
;                as `make HOSTCC=` names it; unset, mooncc through .hearts/bin/hk-hostcc, which
;                lays certs/extract-cert as ours (xcert.l) rather than link openssl's
; $HEARTS_LEX, $HEARTS_YACC  the flex and bison the build runs (`make LEX= YACC=`); unset, kbuild's
; $HEARTS_KGZIP  the gzip the build runs (`make KGZIP=`): the reference is given the same one
; $HEARTS_SH     a shell to run the commands with instead of lush (/bin/sh, for a differential)
(: argv cmdline
   memo {}
   jobs {}
   pids {}
   cnt {}
   made {}
   (lastsl p) ((: (g i) (i < 0 ? -1 (p i = 47 ? i (g (i - 1))))) (#p - 1))
   (dir p) (lastsl p @ k (k <= 0 ? "." (snip p 0 k)))
   _ (borrow (dir (argv 1) + "/kbuild.l"))
   _ (borrow 'hearts-kbuild)
   _ (borrow 'posix)
   K (getenv "HEARTS_SRC" || "")
   here (cwd 0)
   hd (here + "/.hearts")
   njobs (getenv "HEARTS_JOBS" @ j (string? j ? (read j) 1))
   (chomp s) ((: (g i) (0 < i && s (i - 1) = 10 ? (g (i - 1)) (snip s 0 i))) #s)
   ; the wrappers' interpreter line: lush, as the commands run (a #!/bin/sh would be the host's)
   bang ("#!" + selfpath 0 + " lush\n")
   (shc cmd) (getenv "HEARTS_SH" @ h (string? h ? [h "-c" cmd] [(selfpath 0) "lush" "-a" "-c" cmd]))
   (sh cmd) (peep memo cmd 0 @ a (string? a ? a
              (: r (hark (shc cmd))
                 a (two? r ? (join " " (lines (chomp >r))) "")
                 (pin memo cmd a, a))))
   (split1 s) ((: (g i st acc) (i >= #s ? (rev (snip s st i . acc))
                                  (s i = 39 ? (g (i + 1) (i + 1) (snip s st i . acc)) (g (i + 1) st acc)))) 0 0 ())
   (q s) ("'" + (join "'\\''" (split1 s)) + "'")
   (ident? n) (0 < #n && all (c \ c = 95 || 65 <= c <= 90 || 97 <= c <= 122 || 48 <= c <= 57) (map n ^#n)
               && !(48 <= n 0 <= 57))
   ; the prior build's saved command for a target: its .cmd, read as make reads it
   (prior tg) (: p (hk-path tg) k (lastsl p)
                 f ((k >= 0 ? (snip p 0 (k + 1)) "") + "." + snip p (k + 1) #p + ".cmd")
                 l (uread f @ [1 s] <(lines s) "")
                 i (findsub l " := ")
                 (0 <= i ? ((cite 'cook 'cook-expand) (snip l (i + 4) #l) (pins {} "pound" "#")) ()))
   (appendf p t) (cite 'posix 'open p "a" @ f (hot? f ? (say f t, cite 'posix 'close f, 1)))
   (bump k) (pin cnt k (peep cnt k 0 + 1), peep cnt k 0)

   ; jobs in flight: target -> pid, pid -> [target output-file]. one lands when glean reaps
   ; it; a failure prints its output and stops the make, as make does once the running finish
   (land pid status)
    (peep pids pid 0 @ j
       (atom? j ? 0
          (: _ (pull pids pid 0, pin cnt 'live (peep cnt 'live 0 - 1))
             _ (peep jobs (j 0) 0 = pid ? (pull jobs (j 0) 0) 0)
             out (uread (j 1) @ [1 s] s "")
             _ (unlink (j 1))
             (status = 0 ? 0
                (puts ("FAILED " + j 0 + " (" + show status + ")\n" + out),
                 peep made " failed" 0 ? 0 (pin made " failed" (j 0)))))))
   (reap1 _) (glean 0 @ r (? (two? r) (land <r >r) (atom? r) (rest 2) 0))
   (waitfor tg) (peep jobs tg 0 ? (reap1 0, waitfor tg) 0)
   (slot _) (peep cnt 'live 0 >= njobs ? (reap1 0, slot 0) 0)
   (drain _) (0 < peep cnt 'live 0 ? (reap1 0, drain 0) 0)

   ; one command: its exports, a PATH where hk-make is this script, its target's directory
   ; first. a filechk ('out) writes through a tmp file and leaves an equal target alone ('same);
   ; a target's own lines run in order, so its earlier job lands first
   (run tg kind saved text env)
    (: ex (join "" (map (e \ "export " + e 0 + "=" + q (e 1) + "\n") (filter (e \ ident? (e 0)) env)))
       pre (ex + "export PATH=" + q (hd + "/bin") + ":\"$PATH\"\nexport MAKE=hk-make\n"
            + "mkdir -p " + q (dir tg) + " && ")
       _ (waitfor tg)
       _ (appendf (hd + "/commands") (tg + "\t" + show kind + "\t" + text + "\n"))
       (kind = 'out || njobs < 2
        ? (: line (pre + (kind = 'out
                           ? ("{ " + text + "\n} > " + q (tg + ".tmp") + " && if cmp -s " + q (tg + ".tmp") + " " + q tg
                              + "; then rm -f " + q (tg + ".tmp") + "; exit 3; else mv -f " + q (tg + ".tmp") + " " + q tg + "; fi")
                           text))
             r (hark (shc (line + " 2>&1")))
             (? (two? r && 0 = <r) 0
                (kind = 'out && two? r && 3 = <r) 'same
                (puts ("FAILED " + tg + " (" + show (two? r ? <r r) + ")\n" + text + "\n" + (two? r ? >r "") + "\n"), 1)))
          (: _ (slot 0)
             f (hd + "/job." + show (bump 'n))
             pid (spawn (shc ("{ " + pre + text + "\n} > " + q f + " 2>&1")))
             (pin pids pid [tg f], pin jobs tg pid, bump 'live, 0))))
   ; mooncc finds its headers and runtime at <its binary>/../lib/love/moon: a seat under .hearts,
   ; a copy of this love beside the tree's own src/apps/moon (build.l sits in src/apps/hearts)
   (seat _)
    (: sd (hd + "/seat") apps (dir (dir (argv 1)))
       moon ((apps 0 = 47 ? apps (here + "/" + apps)) + "/moon")
       (hark ["mkdir" "-p" (sd + "/bin") (sd + "/lib/love")],
        hark ["cp" "-f" (selfpath 0) (sd + "/bin/love")],
        hark ["ln" "-sfn" moon (sd + "/lib/love/moon")],
        uwrite (hd + "/bin/hk-hostcc")
               (bang + "# the host compiler: mooncc; extract-cert, which links openssl, is laid as ours instead\n"
                + "case \" $* \" in\n  *\" -o certs/extract-cert \"*) exec cp -f " + q (hd + "/bin/xcert") + " certs/extract-cert;;\n"
                + "esac\nexec " + q (sd + "/bin/love") + " mooncc \"$@\"\n"),
        uwrite (hd + "/bin/xcert") (bang + "exec " + q (sd + "/bin/love") + " " + q (dir (argv 1) + "/xcert.l") + " \"$@\"\n"),
        hark ["chmod" "+x" (hd + "/bin/xcert")],
        hark ["chmod" "+x" (hd + "/bin/hk-hostcc")],
        ; perl: the scripts the build runs are ported (perlasm.l, oidreg.l, each pinned by hash); any
        ; other refuses
        uwrite (hd + "/bin/perl")
               (bang + "# the build's perl: the ported scripts, nothing else\ncase \"$1\" in\n"
                + "  */sha2-armv8.pl) exec " + q (sd + "/bin/love") + " " + q (dir (argv 1) + "/perlasm.l") + " \"$@\";;\n"
                + "  */build_OID_registry) exec " + q (sd + "/bin/love") + " " + q (dir (argv 1) + "/oidreg.l") + " \"$@\";;\n"
                + "esac\necho \"hearts: no perl here for $1\" >&2\nexit 1\n"),
        hark ["chmod" "+x" (hd + "/bin/perl")]))
   (after l) (atom? l ? () (<l = "--sub" ? >l (after >l)))
   sub (after argv)
   _ (pins made " prior" (getenv "HEARTS_PRIOR" = "1" ? prior ()) " wait" waitfor)
   (two? sub
    ? (: f (hk-envmake K sub sh run (made " prior")) (drain 0, quit (string? f ? 1 0)))
      (: t0 (clock 0)
         _ (hark ["mkdir" "-p" (hd + "/bin")])
         _ (uwrite (hd + "/bin/hk-make") (bang + "HEARTS_JOBS=1 exec " + q (argv 0) + " " + q (argv 1) + " --sub \"$@\"\n"))
         _ (hark ["chmod" "+x" (hd + "/bin/hk-make")])
         _ (seat 0)
         id (filter (n \ string? (getenv n)) ["KBUILD_BUILD_USER" "KBUILD_BUILD_HOST" "KBUILD_BUILD_VERSION" "KBUILD_BUILD_TIMESTAMP"])
         ; no rust or pahole, and no libc to link a user program against, whatever the host has: their
         ; versions and CC_CAN_LINK land in .config, and so the image
         _ (hark ["mkdir" "-p" (hd + "/no-sysroot")])
         cl0 (foldl (a \ n \ pin a n (getenv n))
                    (pins {} "ARCH" "arm64" "LLVM" "1" "RUSTC" "false" "HOSTRUSTC" "false" "BINDGEN" "false" "PAHOLE" "false"
                             "USERCFLAGS" ("--sysroot=" + hd + "/no-sysroot")) id)
         cl1 (pin cl0 "HOSTCC" (getenv "HEARTS_HOSTCC" @ h (string? h ? h (hd + "/bin/hk-hostcc"))))
         cl (foldl (a \ kv \ (getenv (kv 0) @ v (string? v ? (pin a (kv 1) v) a))) cl1
                   [["HEARTS_LEX" "LEX"] ["HEARTS_YACC" "YACC"] ["HEARTS_KGZIP" "KGZIP"]])
         goals (words (getenv "HEARTS_GOALS" || "defconfig syncconfig Image"))
         (one g) (peep made " failed" 0 ? 0
                   (: top (hk-topgoal K here cl sh g)
                      (hk-make K top g made {} run, drain 0, puts ("made " + g + " in " + show (clock 0 - t0) + " ms\n"))))
         (each goals one,
          peep made " failed" 0 @ f (string? f ? (puts ("FAILED at " + f + "\n"), quit 1) 0)))))
