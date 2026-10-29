; a module of its own, so `borrow` splices tar into this layer, not the dist cat's
(module 'source
(borrow 'tar)

(borrow 'posix)
(: (src-die m) (udie 1 ";; \(m)")

   ; a leading dash is never the positional directory, so a mistyped flag lays nothing
   (src-dash? w) (#w @ n (0 < n && w 0 = 45))
   (src-help? ("-h" || "--help" || "-help" || "help")) 1
   (src-vers? ("-v" || "--version")) 1
   (src-vers m) (puts "\(uvers m)\n", quit 0)
   (src-not-dir m w)
    (src-die "\(w) is not a directory -- `love \(m) help` for usage")

   (src-head nom) (: n #nom
                     (go i) (? (n <= i) nom (nom i = 47) (snip nom 0 i) (go (i + 1)))
                     (go 0))

   (src-top es) (atom? es ? ""
    (src-head (tar-get <es 'nom "") @ ("." || "") (src-top >es) c c))

   ; the carried tree whole, every section joined: the tar it was cut to
   (src-lay dir)
    (: a (tree-tar 0)
       _ (!(string? a) ? (src-die "this love carries no source"))
       t (tar-unpack a)
       _ (atom? t ? (src-die "the carried source is torn"))
       es <>t
       top (src-top es)
       _ (0 >= #top ? (src-die "the carried source names no top directory"))
       w (tar-scatter dir es)
       _ (atom? w ? (src-die "can't write \(dir)"))
       root (dir = "." ? top "\(dir)/\(top)")
       ; no love is laid beside the source: the driver names the compiler in CC
       [1 root <>w])

   ; love-<version> under dir, laid once and shared by every verb that builds. the lay
   ; runs in a child where it can: the unpack leaves heap no collection gives back.
   (src-root dir) "\(dir = "." ? "" "\(dir)/")love-\(love-version)"
   (src-nest dir)
    (: root (src-root dir)
       exe (src-me 0)
       (two? (stat "\(root)/Makefile") ? root
          (: _ (say err ";; laying the source under \(dir)\n")
             st (string? exe ? (spawn [exe "source" dir] @ p (charm? p && 0 <= p ? (wait p) 1))
                   (two? (src-lay dir) ? 0 1))
             ((0 = st && two? (stat "\(root)/Makefile") ? 0
               (src-die "the source did not lay under \(dir)")),
              root))))

   (src-usage _)
    (puts "usage: love source [DIR]\n  lay this binary's carried source tree under DIR (default .)\n")

   (source-main as)
    (: d (two? as ? <as ".")
       _ (src-help? d ? (src-usage 0, quit 0))
       _ (src-vers? d ? (src-vers "source"))
       _ (src-dash? d ? (src-not-dir "source" d))
       r (src-lay d)
     (puts ";; wrote \(<>r)\n", 0))

   (src-dirs _)
    (: p ("" + getenv "PATH") n #p
       (go k st acc) (? (n <= k) (rev (snip p st k . acc))
                        (p k = 58) (go (k + 1) (k + 1) (snip p st k . acc))
                        (go (k + 1) st acc))
       (go 0 0 ()))
   (src-foreign? p) (: a (stat p) b (stat (selfpath 0)) (two? a ? !(a = b) 0))
   ; a candidate's complaints are not the caller's news: both streams to /dev/null, status only
   (src-ccworks? cc dir)
    (: c "\(dir)/.ccprobe.c" o "\(dir)/.ccprobe.o"
       q (open c "w")
       (!(hot? q) ? 0
          (: _ (say q "int main(void){return 0;}\n")
             _ (close q)
             nul (openfd "/dev/null" 1)
             p (spawnio [cc "-c" "-o" o c] -1 nul nul () -1 0)
             st (0 <= p ? (wait p) 1)
             ((0 <= nul ? (close nul) 0),
              unlink c, unlink o,
              0 = st))))
   (src-cc dir)
    (: (try (w . x))
     (: (go ds) (atom? ds ? (try x)
              (: d (#<ds ? <ds ".") p "\(d)/\(w)"
               (src-foreign? p && src-ccworks? p dir ? [1 p] (go >ds))))
      (go (src-dirs ())))
     (try '("cc" "gcc" "clang")))
   (src-farm root exe)
    (d : "\(root)/out/.seedbin"
       ; a laid tree carries no out/, and mkdir makes one directory: the parent first
       (mkdir "\(root)/out" 493, mkdir d 493,
        each (keys (cite 'verbs 'tab))
             (k \ ("\(d)/\(string k)" @ p (unlink p, symlink exe p))),
        d))
   ; this binary as a path, or () where there is none (on inle the artifact is the kernel)
   (src-me _) (selfpath 0 @ p (string? p ? p ()))
   ; run a verb: exec this binary where it has a path, else spawn a task
   (src-run exe as)
    (string? exe ? (herald (exe . as) @ s (two? s ? <s s))
       (spawn as @ p (charm? p && 0 <= p ? (wait p) 127)))
   ; the autonomous build: our verbs first on PATH, lush autonomous, CC our mooncc.
   ; objects from our mooncc and the ambient cc do not link together.
   (src-arm root exe)
    (src-farm root exe @ farm
       (setenv "PATH" (farm + ":" + getenv "PATH"),
        setenv "LUSHFLAGS" "-a",
        setenv "CC" "\(exe) mooncc",
       ; says the arm out loud for common.mk's tags; a person may set LUSHFLAGS themselves
        setenv "LOVE_ARMED" "1",
        farm))
   src-needs '("cc" "make" "sh" "sed" "grep" "tr" "cat" "mkdir" "mv" "rm" "ln"
               "test" "uname" "printf" "install" "cmp" "chmod" "touch" "echo")
   ; kore's ujoin is not in this layer, so the join is local, like src-dirs' split
   (src-words l) (? (atom? l) "" (atom? >l) <l "\(<l) \(src-words >l)")
   (src-ours ns) (:- (go ns ())
    (go l acc) (atom? l ? (rev acc)
                (: w <l
                   (any ds) (two? ds ?
                             (: d (#<ds ? <ds ".") p "\(d)/\(w)"
                              (src-foreign? p ? 1 (any >ds))))
                 (go >l (any (src-dirs ()) ? acc (w . acc))))))
   ; compare two files in chunks, not whole: slurping two binaries holds their heap for good.
   ; a short read rides as a leftover, so the streams line up however the reads fall.
   (src-chunk q b) (swig q b @ k (charm? k && 0 < k ? (snip b 0 k) ""))
   (src-same? p1 p2)
    (: q1 (open p1 "r")
       q2 (open p2 "r")
       ((!(hot? q1 && hot? q2)) ? (hot? q1 ? (close q1) 0, hot? q2 ? (close q2) 0, 0)
          (: b1 (cask 65536)
             b2 (cask 65536)
             (go r1 r2)
              (: r1 (#r1 ? r1 (src-chunk q1 b1))
                 r2 (#r2 ? r2 (src-chunk q2 b2))
                 n1 #r1
                 n2 #r2
                 m (n1 < n2 ? n1 n2)
                 (? (0 = m) (n1 + n2 @ 0 1 0)      ; both ended, same place
                    (n1 = n2) (r1 = r2 ? (go "" "") 0)   ; the even case: no snip at all
                    (snip r1 0 m != snip r2 0 m) 0
                    (go (snip r1 m n1) (snip r2 m n2))))
             v (go "" "")
             (close q1,
              close q2,
              v))))

   ; inside a guest, ask the outside to carry the file out, as `lift` does; hosted, a no-op
   (src-lift p)
    (open "/proc/lift" "w" @ q
       (hot? q ? (say q p, close q, 1) 0))

   ; a cross lay is an unbaked egg: no fixpoint, since it cannot be this binary. the first
   ; word of its .love.image stub goes 1 -> 2, which src/love/main.c reads as `bake in
   ; place, then run again`. answers 1, or () where made is not an egg we can mark
   (seed-mark made dst)
    (: (rd o n) (uread-at made o n @ [1 t] t "")
       at ((cite 'holo 'elf-sec-at) rd ".love.image")
       (two? at && 16 <= at 1 && rd (at 0) 1 = string [1] && 0 <= copyfile made dst ?
          (uwrite-at dst (at 0) (string [2]))))
   (seed-cross root xa dst) (:- 0
    made "\(root)/out/x-\(nom xa)/love"
    m (seed-mark made dst)
    e (m = 1 ? 0 (copyfile made dst))
    _ (e < 0 ? (src-die "can't write \(dst)"))
    _ (chmod dst 493)
    out? (src-lift dst)
    _ (puts (";; laid \(dst) -- a raw egg for \(xa). on that machine\n"
             + (m = 1 ? ";; its first run bakes it in place, then goes on.\n"
                         ";; `love bake` lays its crew from the source it carries.\n")
             + (out? ? ";; carried out of the machine. the x bit does not travel: chmod +x it there.\n" "")
             + ";; no fixpoint claimed here: a cross lay cannot BE this binary --\n"
             + ";; `love seed` on the \(xa) machine proves it.\n")))

   ; run in a fresh exec, since the lay's heap is never unmapped; PATH and CC ride the
   ; environment. with no path to exec, seed-lay calls this directly and keeps the heap
   (seed-wait root xa dst)
    (: exe (src-me 0)
       here (cwd 0)
       _ (!(chdir root) ? 0 (src-die "can't enter \(root)"))
       xm (string? xa ? (show (nom xa)))     ; make's word for it
       os (seed-os 0 @ o (nom? o ? ["xos=\(o)"] ()))
       ; -j with no count: cook reads this machine's width, and answers 1 where it
       ; cannot -- so the seed is as wide as the box and never wider.
       s (src-run exe (string? xa ? (["make" "-j" "xa=\(xm)"] + os + ["out/x-\(xm)/love"])
                                    ["make" "-j" "dist"]))
       st (two? s ? <s s)
       (chdir here,
        (0 != st ? (src-die "the build failed (exit \(st))")),
        (string? xa ? (seed-cross root xa dst)
           ; the rebuild must be this binary, byte for byte
           (: out "\(root)/out/love"
              (seed-roster out, seed-fix exe out)))))

   ; the units this image left out (`love roster`): the rebuild bakes the same roster
   (seed-left _)
    (: V (cite 'verbs)
       (foldl (a \ f \ (V 'unit <f @ u (>f = 0 && !(elem u a) ? (a + [u]) a))) () (rev (V 'ros 'files))))
   (seed-roster out)
    (seed-left 0 @ () 0
       l (: _ (puts ";; baking the roster: --without \(join "," l)\n")
            r (spawn [out "roster" "bake" "--without" (join "," l) "-o" out] @ p
                 (charm? p && 0 <= p ? (wait p) 127))
            (0 != r ? (src-die "the roster bake failed (exit \(r))"))))

   ; the imageless projection of a binary, written beside p. a binary carrying no image
   ; is its own projection, which is how seed-fix reads either side's state.
   (seed-bare exe p)
    (: _ (unlink p)
       r (hark [exe "bake" "-n" "-o" p])
       (two? r && <r = 0 ? p ()))

   ; like with like: two baked or two bare sides compare whole, a mixed pair stripped.
   ; an image is a deterministic function of its binary, so differing images still fail
   (seed-fix exe out)
    (: a (seed-bare exe "\(out).bare0")
       b (seed-bare out "\(out).bare1")
       ; neither side strips where there is no bake (wasm): both are bare already.
       ; every predicate parenthesised: a bare infix one swallows the arm beside it
       v (? (!(string? a) && !(string? b))          (src-same? exe out ? 'yes 'no)
            (!(string? a) || !(string? b))          'nostrip
            (!(src-same? a b))                      'no
            (src-same? a exe != src-same? b out)    'bare
            (src-same? exe out)                     'yes
                                                    'image)
       ((string? a ? (unlink a) 0),
        (string? b ? (unlink b) 0),
        (v @ 'yes   (puts ";; fixpoint ok -- \(out)\n", 0)
             'bare  (puts ";; fixpoint ok -- \(out), imageless: one side carries no image\n", 0)
             'image (say err ";; fixpoint failed: the code matches, the images do not\n", 1)
             'nostrip (say err ";; fixpoint: can't lay an imageless copy\n", 1)
             (say err ";; fixpoint failed\n", 1))))

   ; a seed can lay for another machine: every love carries every ISA's runtime.
   ; arch-nom (post.l) canonicalises any spelling to these words
   seed-arches '(x64 a64 rv64)
   ; the arch word is positional and A PATH still wins: `./a64` is the
   ; directory, the verb rail's own rule worn one level down.
   (seed-arch? w) (:- (go 0) n #w (go i)
                   (n <= i ? (elem (arch-nom w) seed-arches)
                             (w i @ 47 0 (go (i + 1)))))
   ; this machine's arch: love-arch is already canonical, which is seed-arches' spelling.
   (seed-native _) love-arch
   ; the OS a cross lay is for, named only where this machine is not a hosted OS (inle): linux
   (seed-os _) (elem 'love-os (names ()) && ev 'love-os @ n
                  (nom? n && !(elem n '(linux freebsd netbsd)) ? 'linux ()))

   (seed-usage _) (puts """
    usage: love seed [-g] [ARCH] [DIR]
    lay this binary's source under DIR (default .) and rebuild it, byte for byte
      ARCH   x64 | a64 | rv64: build for that machine instead, as DIR/love-ARCH
      -g     build with the system cc and tools, ours filling the gaps

    """)

   (seed-lay as0)
    (: _ (two? as0 && src-help? <as0 ? (seed-usage 0, quit 0))
       _ (two? as0 && src-vers? <as0 ? (src-vers "seed"))
       f0 (two? as0 ? <as0 "")
       greg? (f0 = "-g")
       as1 (greg? || f0 = "-a" ? >as0 as0)     ; -a is the default, still eaten
       ; naming this machine's own arch is a native seed, fixpoint and all. the word is
       ; eaten either way, or it would be read as the directory
       xa0 (two? as1 && seed-arch? <as1 ? (arch-nom <as1) ())
       xa (nom? xa0 && xa0 = seed-native 0 ? () xa0)
       as (nom? xa0 ? >as1 as1)
       dir (two? as ? <as ".")
       _ (src-dash? dir ? (src-not-dir "seed" dir))
       exe (src-me 0)
       ; with no path to itself there is no binary to hold a native seed to: cross only.
       ; said bare, it lists the machines it can lay for
       _ (!(string? exe) && !(nom? xa) ?
          (two? as ? (src-die "this seat has no path to itself -- name a machine: `love seed x64`")
             (puts "seed for a machine: \(src-words (map show seed-arches))\n", quit 0)))
       root (src-nest dir)
       farm (string? exe ? (src-farm root exe) "")
       path ("" + getenv "PATH")
       ; ours lead PATH, or with -g trail it to fill the gaps; lush reads the same
       ; choice off LUSHFLAGS
       _ (string? exe ? (setenv "PATH" (greg? ? "\(path):\(farm)" "\(farm):\(path)")) 0)
       _ (setenv "LUSHFLAGS" (greg? ? "-g" "-a"))
       ; with no path to name, the Makefile reaches this binary by the verb `love`
       _ (string? exe ? 0 (setenv "LOVE" "love"))
       env (getenv "CC")
       ; the probe writes into the laid tree's root: it is the one directory a lay
       ; is known to have made, and the two scratch files go straight back out
       amb (greg? && string? exe && !(string? env) ? (src-cc root))
       ; CC is always named: an env CC wins, then with -g a working ambient cc, else our
       ; mooncc (the verb `cc` where there is no path to exec)
       _ (string? env ? 0
          (two? amb ? (setenv "CC" <>amb)
           (setenv "CC" (string? exe ? "\(exe) mooncc" "cc"))))
       _ (!greg? ? (puts ";; using own tools throughout\n")
            (src-ours src-needs @ ours
               (two? ours ? (puts ";; using own tools: \(src-words ours)\n") 0)))
       cc (? (string? env) env (two? amb) <>amb "this binary")
       ; the OS rides the word where we had to pick one, because nothing else here says it
       tgt (nom? xa ? (seed-os 0 @ o " \(xa)\(nom? o ? "-\(o)" "")") "")
       _ (puts ";; seeding\(tgt) -- the compiler is \(cc)\n")
       dst (nom? xa ? "\(dir)/love-\(xa)" ())
       _ (string? exe ? 0 (quit (seed-wait root (show xa) dst)))   ; nothing to exec: wait here
       e (nom? xa ? (exec [exe "seed" "-wait" root (show xa) dst])
                    (exec [exe "seed" "-wait" root]))
       (src-die "can't wait for the build (exec: \(show e))"))

   (seed-main as0)
    (atom? as0 || <as0 != "-wait" ? (seed-lay as0)
       (: a1 >as0
          root (two? a1 ? <a1 ".")
          a2 (two? a1 ? >a1)
          xa (two? a2 ? <a2)
          a3 (two? a2 ? >a2)
          dst (two? a3 ? <a3)
          (seed-wait root xa dst)))

   ; --- `love kernel OUT.elf` -- the metal projection of this binary ----------
   ; the boot stub is laid, not stored: the cat below evals off the carried tree in the
   ; Makefile's order. the arch is this binary's own, read off e_machine
   (kern-pick nm)
    (uread "/love/\(nm)" @ [1 s] (s + "") (src-die "the carried tree has no \(nm)"))
   (kern-b16 s i) (s i + 256 * s (i + 1))
   kern-box {}                  ; the verb's inputs, read back by the stream
   (kernel-main as)
    ; the operand is a path to WRITE, so the flags are asked before it: a `-h` taken
    ; for one lays a kernel in a file called -h
    (: usage "usage: love kernel OUT.elf"
       _ (two? as && src-help? <as ? (puts "\(usage)\n", quit 0))
       _ (two? as && src-vers? <as ? (src-vers "kernel"))
       _ (two? as ? 0 (src-die usage))
       out <as
       exe (selfpath 0)
       _ (string? exe ? 0 (src-die "can't read the seed path"))
       pie (open exe "r" @ h
             (hot? h ? (slurp h @ s (close h, s))
                (src-die "can't read this binary")))
       m (kern-b16 pie 18)
       arch (m @ 62 "x64" 183 "a64" 243 "rv64"
             (src-die "no boot door for this machine"))
       ; the stream evals in its own layer, so the inputs cross on the verb table,
       ; the one tablet every layer reaches, under a key pulled back off after
       _ (pins kern-box 'pie pie 'out out 'arch arch)
       vt (cite 'verbs 'tab)
       _ (pin vt 'kern-in kern-box)
       cat ("(borrow 'holo)"
            + kern-pick "src/apps/kore/text.l"
            + kern-pick "src/apps/kore/u.l"
            + "(borrow 'kore)"
            + kern-pick "src/apps/kore/asbook.l"
            + kern-pick "src/inle/mkboot.l"
            + kern-pick "src/tools/kproject.l"
            + "(: kb (peep (cite 'verbs 'tab) 'kern-in 0)"
            + "   bb (string (cask (lay-boot-bytes (peep kb 'arch 0))))"
            + "   (kproject (peep kb 'pie 0) bb (peep kb 'out 0) (peep kb 'arch 0)))")
       (reads (tap ((: (g i) (i < #cat ? (peep cat i 0 . g (1 + i)))) 0)),
        pull vt 'kern-in 0,
        puts ";; wrote \(out) (\(arch))\n",
        0))

   ; -- nest: this binary laid as the user's love under ~/.love/bin, lush linked to it --
   (nest-read p) (uread p @ [1 s] (s + "") ())
   ; the one tool linked to love by its own name, the argv[0] door: lush, autonomous by
   ; default, runs every other verb by name (`lush -c 'mooncc ..'`), PATH or no PATH
   nest-tools ["lush"]
   nest-keep ["love" "lush"]
   ; what an earlier install laid that is no longer kept: a link to love by another
   ; name, the lux script, a shell launcher, the papel link. anything else stays
   (nest-laid? p)
    (readlink p @ l
       (? (string? l) (l = "love" || (#l > 17 && snip l (#l - 17) #l = "/src/apps/papel.l"))
          (nest-read p @ s
             (string? s && (snip s 0 41 = "#!/usr/bin/env -S love -l\n; src/apps/lux/"
                            || 0 <= fsub s "((cite 'cli 'shell) 0)" 0)))))
   (nest-stale bin)
    (filter (nm \ 0 < #nm && nm 0 != 46 && !(elem nm nest-keep) && nest-laid? "\(bin)/\(nm)")
            (two? (stat bin) ? (readdir bin) ()))
   ; a ~/.local/bin link into the nest whose name the nest no longer holds
   (nest-stale-compat home bin)
    (: d "\(home)/.local/bin"
       (filter (nm \ 0 < #nm && nm 0 != 46 && readlink "\(d)/\(nm)" = "\(bin)/\(nm)"
                     && !(two? (stat "\(bin)/\(nm)")))
               (two? (stat d) ? (readdir d) ())))
   ; ~/.local/bin is already on PATH where ~/.love/bin is not; a name there that is not
   ; ours already is left alone
   (nest-compat home bin nm)
    (: d "\(home)/.local/bin" p "\(d)/\(nm)" to "\(bin)/\(nm)"
       (!(two? (stat d)) || string? (readlink p) || two? (stat p) ? 0 (symlink to p)))
   ; lays new as dst unless it is there already: 'laid or 'same
   (nest-lay bin dst new)
    (? (nest-read dst = new) 'same
       (: tmp "\(bin)/.love.new"
          q (open tmp "w")
          _ (hot? q ? (say q new, close q) (src-die "nest: cannot write \(tmp)"))
          _ (chmod tmp 493)
          ; the copy runs before it takes the name: a binary cut short, or one a
          ; gate left half-built, never becomes the love on PATH
          ok (hark [tmp "-e" "1 + 1"])
          _ (<ok = 0 && >ok = "2\n" ? 0
               (unlink tmp, src-die "nest: the copy does not run; nothing replaced"))
          (!(rename tmp dst) ? 'laid (unlink tmp, src-die "nest: cannot rename over \(dst)"))))
   nest-usage "usage: love nest
install this binary as ~/.love/bin/love, with lush beside it
"
   (nest-main as)
    (: _ (two? as ?
            (? (src-help? <as) (puts nest-usage, quit 0)
               (src-vers? <as) (src-vers "nest")
               (say err "love nest: unknown option \(<as)\n", say err nest-usage, quit 2))
            0)
       home (getenv "HOME")
       _ (string? home && #home ? 0 (src-die "nest: no HOME"))
       me (selfpath 0)
       _ (string? me ? 0 (src-die "nest: cannot find this binary"))
       new (nest-read me)
       _ (string? new ? 0 (src-die "nest: cannot read \(me)"))
       bin "\(home)/.love/bin"
       _ (mkdir "\(home)/.love" 493) _ (mkdir bin 493)
       r (nest-lay bin "\(bin)/love" new)
       _ (each nest-tools (nm \ "\(bin)/\(nm)" @ p (readlink p = "love" ? 0 (unlink p, symlink "love" p))))
       _ (each (nest-stale bin) (nm \ unlink "\(bin)/\(nm)"))
       _ (each (nest-stale-compat home bin) (nm \ unlink "\(home)/.local/bin/\(nm)"))
       _ (each ("love" . nest-tools) (nest-compat home bin))
       (puts (r = 'same ? "love nest: ~/.love/bin/love is already this build (\(love-build 0))\n"
                          "love nest: installed ~/.love/bin/love (\(love-build 0))\n"),
        0))

   ; -- lux: the window manager, a verb over the source this binary carries. its modules
   ;    read in the Makefile's order (luxfiles), so the wm and its love never skew; it
   ;    restarts by exec'ing its own argv, which comes back here --
   lux-modules ["core" "layout" "wire" "ewmh" "manage" "keys" "config" "lux"]
   (lux-main as)
    (: cat (foldl (a \ m \ a + kern-pick "src/apps/lux/\(m).l") "" lux-modules)
       (reads (tap ((: (g i) (i < #cat ? (peep cat i 0 . g (1 + i)))) 0))))
   lux-usage "usage: love lux
  the window manager, over the display DISPLAY names; settings ride ~/.love/etc/lux.l
"

   ; a binding, not a body: the letrec stays body-less, so every name above is the
   ; module's -- (cite 'source 'src-arm) for serve and doom -- and the pins still run at load
   _ (pins (cite 'verbs 'tab)
      'source source-main
      'src    source-main
      'seed   seed-main
      'kernel kernel-main
      'nest   nest-main
      'lux    (udoor 'lux lux-main lux-usage 1 1)))

) ; module 'source
