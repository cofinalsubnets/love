; test/host/init.l -- init's mounts say what mount answered: () is ok, an error is its name.
; in a private user+mount ns a tmpfs mounts and proc (no pid ns) is refused
(: d "out/hostnif/init-mnt"
   _ (hark ["rm" "-rf" d])
   _ (hark ["mkdir" "-p" d])
   (in-ns f call)
    >(hark ["out/love" "-l" f "-e"
            ("(: e (newns 0) _ (e = () ? " + call + " (puts \"no userns\\n\")) 0)")])
   b (in-ns "src/apps/init/boot.l" ("(mnt \"tmpfs\" \"" + d + "/b\" \"tmpfs\")"))
   t (in-ns "src/apps/init/init.l" ("(try-mount \"tmpfs\" \"" + d + "/t\" \"tmpfs\")"))
   p (in-ns "src/apps/init/init.l" ("(try-mount \"proc\" \"" + d + "/p\" \"proc\")"))
   ; outside any ns an unprivileged mount is refused on every box
   q >(hark ["out/love" "-l" "src/apps/init/init.l" "-e" ("(try-mount \"tmpfs\" \"" + d + "/q\" \"tmpfs\")")])
   ns? !(has? b "no userns")
   _ (test (!ns? || has? b ("mount tmpfs on " + d + "/b -> ok"))
           (!ns? || has? t ("mount tmpfs on " + d + "/t -> ok"))
           (!ns? || has? p ("mount proc on " + d + "/p -> eperm (needs root/pid-ns)"))
           (has? q ("mount tmpfs on " + d + "/q -> eperm (needs root/pid-ns)"))
           !(has? b "errno") !(has? t "EPERM"))
   _ (hark ["rm" "-rf" d])
   (test_fin (),
    say err ("test/host/init: init's mounts read ()/an error name"
             + (ns? ? "" " (no unprivileged userns: the refusal alone)") + ": ok"),
    put err 10,
    0))
