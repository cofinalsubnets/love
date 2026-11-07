; test/host/hosts.l -- the host registry and bee --on (src/apps/hosts.l), with a stand-in ssh
;   cat test/00-init.l test/host/hosts.l | out/love

(borrow 'hosts)

(: ht-locks (cite 'locks 'locks-list)
   ht-num (cite 'kore 'wg-digits)
   ht-home (cwd 0)
   ht-d (ht-home + "/out/.hosts-" + show (getpid 0))
   _ (mkdir ht-d 493)
   (ht-put nm s) (: p (open (ht-d + "/" + nm) "w") _ (say p s) (close p))
   (ht-get p) (: f (open p "r") (hot? f ? (: s (slurp f) _ (close f) s) ()))
   ; past the options and the host: one word is a line, more an argv
   _ (ht-put "ssh" "while [ \"$1\" = -o ]; do shift 2; done; shift; [ $# -eq 1 ] && exec sh -c \"$1\"; exec \"$@\"\n")
   _ (ht-put "down" "exit 255\n")
   _ (ht-put "hosts" ("# a test registry\nname up\nreach sh " + ht-d + "/ssh up\nslots 2\ncaps a64-exec kvm-a64 lanes\nslots-lanes 1\napart-lanes bsd\npage 16384\n\n"
                      + "name gone\nreach sh " + ht-d + "/down gone\ncaps a64-exec\n\n"
                      + "name bsd\nreach sh " + ht-d + "/ssh bsd\ncaps freebsd-x64\nos freebsd\n"))
   _ (setenv "BEE_HOSTS" (ht-d + "/hosts"))
   _ (setenv "BEE_LOCKS" (ht-d + "/locks"))
   ; hermetic: no host the gate's env names takes a cap over this registry
   _ (map (k \ setenv k "") ["KTEST_A64_HOSTS" "KTEST_A64_HOST" "KTEST_VMX_HOSTS"
                              "FBSD_SSH" "NBSD_SSH" "FBSD_ARM64_SSH" "NBSD_ARM64_SSH"])
   (ht-names hs) (map (h \ h "name") hs)
   (ht-seq a b) (show a = show b)
   all (hosts-all 0)
   a64 (hosts-with "a64-exec" ())
   live (hosts-live a64)
   p16 (hosts-with "a64-exec" "page=16384")
   p4 (hosts-live (hosts-with "a64-exec" "page=4096"))
   probe (hosts-on ["--on" "a64-exec" "--probe"])
   none (hosts-on ["--on" "vt-x" "--probe"])
   _ (mkdir (ht-d + "/ship") 493)
   _ (: p (open (ht-d + "/ship/in.txt") "w") _ (say p "carried\n") (close p))
   ran (hosts-on ["--on" "a64-exec" "--ship" (ht-d + "/ship") "--" "sh" "-c"
                  ("cat in.txt > '" + ht-d + "/got'; env > '" + ht-d + "/env'; exit 3")])
   got (ht-get (ht-d + "/got"))
   env (ht-get (ht-d + "/env"))
   gone (two? (stat ("/tmp/bee-on-" + show (getpid 0))))
   ; pid 1 stands in for a second live holder
   s1 (hosts-take [<live] (getpid 0) "one")
   s2 (hosts-take [<live] 1 "two")
   _ (hosts-free s1 (getpid 0)) _ (hosts-free s2 1)
   ; a cap with slots of its own takes host-NAME-CAP-N, and holds its apart host's slot beside it
   l1 (hosts-take (hosts-live (hosts-with "lanes" ())) (getpid 0) "lanes")
   held (map cap (ht-locks (ht-d + "/locks") "exclusive"))
   _ (hosts-free l1 (getpid 0))
   after (map cap (ht-locks (ht-d + "/locks") "exclusive"))
   ; a kept directory: --push lays this repo's commit in it, untracked files but out/ cleaned,
   ; and it outlives the run; a second push leaves a file the commit keeps at its time and
   ; carries the changed one; --at runs only on that commit with its tracked files untouched
   kd (ht-d + "/kept")
   _ (mkdir (ht-d + "/src") 493)
   (ht-git as) (hark (["git" "-C" (ht-d + "/src") "-c" "user.name=t" "-c" "user.email=t@t"] + as))
   (ht-sha _) <(lines <>(ht-git ["rev-parse" "HEAD"]))
   _ (ht-git ["init" "-q"]) _ (ht-put "src/a.txt" "a\n") _ (ht-put "src/b.txt" "b\n")
   _ (ht-git ["add" "a.txt" "b.txt"]) _ (ht-git ["commit" "-qm" "one"])
   c1 (ht-sha 0)
   here (cwd 0) _ (chdir (ht-d + "/src"))
   kin (hosts-on ["--on" "lanes" "--in" kd "--push" c1 "--" "sh" "-c" "mkdir -p out && cat a.txt b.txt > out/got"])
   _ (ht-put "kept/stray" "") _ (ht-put "kept/out/keep" "")
   k1 (ht-get (kd + "/out/got"))
   _ (hark ["touch" "-d" "@1000" (kd + "/a.txt")])
   _ (ht-put "src/b.txt" "c\n") _ (ht-git ["commit" "-qam" "two"])
   c2 (ht-sha 0)
   ks (hosts-on ["--on" "lanes" "--in" kd "--push" c2])
   kb (ht-get (kd + "/b.txt"))
   kat (hosts-on ["--on" "lanes" "--in" kd "--at" c2 "--" "true"])
   kold (hosts-on ["--on" "lanes" "--in" kd "--at" c1 "--" "true"])
   _ (ht-put "kept/b.txt" "edited\n")
   kdirty (hosts-on ["--on" "lanes" "--in" kd "--at" c2 "--" "true"])
   _ (chdir here)
   (ht-mt f) (hark ["stat" "-c" "%Y" f] @ r (<r = 0 ? (ht-num >r) ()))
   ; the env names hosts for a release, and takes the cap over the registry
   _ (setenv "KTEST_A64_HOSTS" "far.lan:3 near.lan")
   ev (hosts-with "kvm-a64" ())
   _ (setenv "KTEST_A64_HOSTS" "")
   _ (test (ht-seq (ht-names all) ["up" "gone" "bsd"])
           (2 = all 0 "slots") (1 = all 1 "slots") (ht-seq (all 2 "reach") ["sh" (ht-d + "/ssh") "bsd"])
           (ht-seq (all 0 "caps") ["a64-exec" "kvm-a64" "lanes"]) ("16384" = all 0 "page") ("freebsd" = all 2 "os")
           (ht-seq (ht-names a64) ["up" "gone"]) (ht-seq (ht-names live) ["up"])
           (ht-seq (ht-names p16) ["up"]) !(two? p4)
           (0 = probe) (75 = none)
           (3 = ran) (got = "carried\n") !gone
           (0 > fsub env "BEE_HOSTS" 0) (0 <= fsub env "LANG=C" 0)       ; only PATH HOME LANG=C cross
           ("host-up-1" = s1 1) ("host-up-2" = s2 1)
           (1 = all 0 "slots-lanes") (ht-seq (all 0 "apart-lanes") ["bsd"])
           (ht-seq l1 [<l1 "host-up-lanes-1" "host-bsd-1"]) (ht-seq (sort held) ["host-bsd-1" "host-up-lanes-1"])
           !(two? after)
           (0 = kin) (k1 = "a\nb\n") (0 = ks) (1000 = ht-mt (kd + "/a.txt")) (kb = "c\n")
           !(two? (stat (kd + "/stray"))) (two? (stat (kd + "/out/keep")))
           (0 = kat) (97 = kold) (97 = kdirty)
           (ht-seq (ht-names ev) ["far.lan" "near.lan"]) (ht-seq (map (h \ h "slots") ev) [3 1])
           (ht-seq (ev 0 "reach") ["ssh" "far.lan"]))
   _ (setenv "BEE_HOSTS" "") _ (setenv "BEE_LOCKS" "")
   _ (hark ["rm" "-rf" ht-d])
   0)

(test_fin (), puts "hosts: ok", putc 10, 0)
