; --- test/host/hosts.l: the host registry and bee --on (src/apps/hosts.l) ----------------------
; a registry, a lock root and a stand-in ssh of its own under out/: the stand-in runs the
; command it is given here, as the far side would, and a down host's answers 255 the way ssh
; does. run standalone from the repo root:
;   cat test/00-init.l test/host/hosts.l | out/love

(borrow 'hosts)

(: ht-home (cwd 0)
   ht-d (ht-home + "/out/.hosts-" + show (getpid 0))
   _ (mkdir ht-d 493)
   (ht-put nm s) (: p (open (ht-d + "/" + nm) "w") _ (say p s) (close p))
   (ht-get p) (: f (open p "r") (hot? f ? (: s (slurp f) _ (close f) s) ()))
   _ (ht-put "ssh" "for a; do l=$a; done; exec sh -c \"$l\"\n")      ; the last word is the line
   _ (ht-put "down" "exit 255\n")
   _ (ht-put "hosts" ("# a test registry\nname up\nreach sh " + ht-d + "/ssh up\nslots 2\ncaps a64-exec kvm-a64\npage 16384\n\n"
                      + "name gone\nreach sh " + ht-d + "/down gone\ncaps a64-exec\n\n"
                      + "name bsd\nreach sh " + ht-d + "/ssh bsd\ncaps freebsd-x64\nos freebsd\n"))
   _ (setenv "BEE_HOSTS" (ht-d + "/hosts"))
   _ (setenv "BEE_LOCKS" (ht-d + "/locks"))
   ; hermetic: no host the gate's env names (osbox-env's) takes a cap over this registry
   _ (map (k \ setenv k "") ["KTEST_A64_HOSTS" "KTEST_A64_HOST" "KTEST_VMX_HOSTS"
                              "FBSD_SSH" "NBSD_SSH" "FBSD_ARM64_SSH" "NBSD_ARM64_SSH"])
   (ht-names hs) (map (h \ h "name") hs)
   (ht-seq a b) (show a = show b)
   all (hosts-all 0)
   a64 (hosts-with "a64-exec" ())
   live (hosts-live a64)
   p16 (hosts-with "a64-exec" "page=16384")
   p4 (hosts-live (hosts-with "a64-exec" "page=4096"))
   ; --on: a probe, a cap no host has, and a run that ships a dir and answers its status
   probe (hosts-on ["--on" "a64-exec" "--probe"])
   none (hosts-on ["--on" "vt-x" "--probe"])
   _ (mkdir (ht-d + "/ship") 493)
   _ (: p (open (ht-d + "/ship/in.txt") "w") _ (say p "carried\n") (close p))
   ran (hosts-on ["--on" "a64-exec" "--ship" (ht-d + "/ship") "--" "sh" "-c"
                  ("cat in.txt > '" + ht-d + "/got'; env > '" + ht-d + "/env'; exit 3")])
   got (ht-get (ht-d + "/got"))
   env (ht-get (ht-d + "/env"))
   gone (two? (stat ("/tmp/bee-on-" + show (getpid 0))))
   ; two holders take up's two slots, each its own lock, and give them back (pid 1 stands in
   ; for a second live holder, as in test/host/locks.l)
   s1 (hosts-take [<live] (getpid 0) "one")
   s2 (hosts-take [<live] 1 "two")
   _ (hosts-free s1 (getpid 0)) _ (hosts-free s2 1)
   ; the env names hosts for a release, and takes the cap over the registry
   _ (setenv "KTEST_A64_HOSTS" "far.lan:3 near.lan")
   ev (hosts-with "kvm-a64" ())
   _ (setenv "KTEST_A64_HOSTS" "")
   _ (test (ht-seq (ht-names all) ["up" "gone" "bsd"])
           (2 = all 0 "slots") (1 = all 1 "slots") (ht-seq (all 2 "reach") ["sh" (ht-d + "/ssh") "bsd"])
           (ht-seq (all 0 "caps") ["a64-exec" "kvm-a64"]) ("16384" = all 0 "page") ("freebsd" = all 2 "os")
           (ht-seq (ht-names a64) ["up" "gone"]) (ht-seq (ht-names live) ["up"])
           (ht-seq (ht-names p16) ["up"]) !(two? p4)
           (0 = probe) (75 = none)
           (3 = ran) (got = "carried\n") !gone
           (0 > fsub env "BEE_HOSTS" 0) (0 <= fsub env "LANG=C" 0)       ; only PATH HOME LANG=C cross
           ("host-up-1" = s1 1) ("host-up-2" = s2 1)
           (ht-seq (ht-names ev) ["far.lan" "near.lan"]) (ht-seq (map (h \ h "slots") ev) [3 1])
           (ht-seq (ev 0 "reach") ["ssh" "far.lan"]))
   _ (setenv "BEE_HOSTS" "") _ (setenv "BEE_LOCKS" "")
   _ (hark ["rm" "-rf" ht-d])
   0)

(test_fin (), puts "hosts: ok", putc 10, 0)
