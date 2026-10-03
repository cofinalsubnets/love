; the wrap: see src/apps/tar.l -- `borrow` splices into the current layer, so the ask
; needs a layer of this file's own rather than the dist cat's. the seed's lay reads the
; carried tree through it.
(module 'source
(borrow 'tar)

(borrow 'posix)
; civil, for a stamp's date (src/love/boot/post.l)
(borrow 'cal)
(: (src-die m) (udie 1 (";; " + m))

   ; the directory is positional, so a mistyped flag would be taken as one and a whole
   ; tree laid under it. a leading dash is never a directory here: name the flags, ask
   ; about anything else.
   (src-dash? w) (#w @ n (0 < n && w 0 = 45))
   (src-help? ("-h" || "--help" || "-help" || "help")) 1
   (src-vers? ("-v" || "--version")) 1
   (src-vers m) (puts (uvers m + "\n"), quit 0)
   (src-not-dir m w)
    (src-die (w + " is not a directory -- `love " + m + " help` for usage"))

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
       _ (atom? w ? (src-die ("can't write " + dir)))
       root (dir = "." ? top (dir + "/" + top))
       ; no love is laid beside the source: which mode a build is in belongs to whoever
       ; drives it. bare make has no love and can only mean the ambient cc; a love driving
       ; knows its own selfpath and says so in CC. a copy in bin/ would be the toolchain by
       ; being there, which is a claim made by a file existing rather than by anyone.
       ; nor the container: the laid tree cuts its own, to the same bytes.
       [1 root <>w])

   ; the nest every verb shares: love-<version> under dir, laid once. source, seed, doom
   ; and web build in the one tree, in any order, and a tree laid before is taken as it
   ; stands. the lay runs in a child where there is a path to one: the unpack leaves
   ; heap no collection gives back, and a server would hold it for good.
   (src-root dir) ((dir = "." ? "" (dir + "/")) + "love-" + love-version)
   (src-nest dir)
    (: root (src-root dir)
       exe (src-me 0)
       (two? (stat (root + "/Makefile")) ? root
          (: _ (say err (";; laying the source under " + dir + "\n"))
             st (string? exe ? (spawn [exe "source" dir] @ p (charm? p && 0 <= p ? (wait p) 1))
                   (two? (src-lay dir) ? 0 1))
             ((0 = st && two? (stat (root + "/Makefile")) ? 0
               (src-die ("the source did not lay under " + dir))),
              root))))

   (src-usage _)
    (puts "usage: love source [DIR]\n  lay this binary's carried source tree under DIR (default .)\n")

   (source-main as)
    (: d (two? as ? <as ".")
       _ (src-help? d ? (src-usage 0, quit 0))
       _ (src-vers? d ? (src-vers "source"))
       _ (src-dash? d ? (src-not-dir "source" d))
       r (src-lay d)
     (puts (";; wrote " + <>r + "\n"), 0))

   (src-dirs _)
    (: p ("" + getenv "PATH") n #p
       (go k st acc) (? (n <= k) (rev (snip p st k . acc))
                        (p k = 58) (go (k + 1) (k + 1) (snip p st k . acc))
                        (go (k + 1) st acc))
       (go 0 0 ()))
   (src-foreign? p) (: a (stat p) b (stat (selfpath 0)) (two? a ? !(a = b) 0))
   ; the probe asks a yes/no question of a candidate we may well reject, so its own
   ; diagnostics are not the caller's news -- both streams go to the hole and only the
   ; status is read. herald tees stdout and leaves stderr on the terminal, which is how
   ; a `cc` that exists and fails used to print its complaint before the first `;;` line.
   (src-ccworks? cc dir)
    (: c (dir + "/.ccprobe.c") o (dir + "/.ccprobe.o")
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
              (: d (#<ds ? <ds ".") p (d + "/" + w)
               (src-foreign? p && src-ccworks? p dir ? [1 p] (go >ds))))
      (go (src-dirs ())))
     (try '("cc" "gcc" "clang")))
   (src-farm root exe)
    (d : (root + "/out/.seedbin")
       ; a laid tree carries no out/, and mkdir makes one directory: the parent first
       (mkdir (root + "/out") 493, mkdir d 493,
        each (keys (cite 'verbs 'tab))
             (k \ (d + "/" + string k @ p (unlink p, symlink exe p))),
        d))
   ; this binary as a path, or () where there is none: on inle the artifact IS the
   ; kernel, so there is nothing to exec, no path to name and no farm worth laying --
   ; the verb registry is that machine's PATH already. every door below asks this.
   (src-me _) (selfpath 0 @ p (string? p ? p ()))
   ; the build's driver. a hosted seat execs the binary and reads the status back; a
   ; seat with none spawns a task, which is this same program under the same registry.
   (src-run exe as)
    (string? exe ? (herald (exe . as) @ s (two? s ? <s s))
       (spawn as @ p (charm? p && 0 <= p ? (wait p) 127)))
   ; the autonomous arming, what a seed sets before its build: the farm of our verbs
   ; first on PATH, lush autonomous, CC our mooncc. `love web` and `love doom` build
   ; under the same, so a nest or a page is ours throughout whatever PATH holds -- a
   ; tree our mooncc built and an object the ambient cc made link neither way.
   (src-arm root exe)
    (src-farm root exe @ farm
       (setenv "PATH" (farm + ":" + getenv "PATH"),
        setenv "LUSHFLAGS" "-a",
        setenv "CC" (exe + " mooncc"),
       ; the arm, said out loud: a recipe's `cat` is kore's here and its shell is lush,
       ; so the build's tags name the tool that RAN (common.mk). LUSHFLAGS is not
       ; that answer -- a person may set it for their own reasons.
        setenv "LOVE_ARMED" "1",
        farm))
   src-needs '("cc" "make" "sh" "sed" "grep" "tr" "cat" "mkdir" "mv" "rm" "ln"
               "test" "uname" "printf" "install" "cmp" "chmod" "touch" "echo")
   ; kore's ujoin is not in this layer -- src-dirs rolls its own split for the
   ; same reason, so the join is local too.
   (src-words l) (? (atom? l) "" (atom? >l) <l (<l + " " + src-words >l))
   (src-ours ns) (:- (go ns ())
    (go l acc) (atom? l ? (rev acc)
                (: w <l
                   (any ds) (two? ds ?
                             (: d (#<ds ? <ds ".") p (d + "/" + w)
                              (src-foreign? p ? 1 (any >ds))))
                 (go >l (any (src-dirs ()) ? acc (w . acc))))))
   ; not (sha256 (slurp a) = sha256 (slurp b)): slurp draws a byte at a time and the
   ; answer is copied, so two 13 MB binaries cost the waiter ~140 MB it never gets back.
   ; a short read rides as a leftover, so the streams line up however the reads fall.
   ; `snip` reads the cask -- (snip (string b) 0 k) would copy all 64K to take the k bytes
   ; the read filled, and a short read at the tail of every file pays it twice.
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

   ; a seat whose files are inside the machine: ask whatever is outside to carry one out,
   ; the way `lift` does. a hosted seat has no such file, and nothing is said.
   (src-lift p)
    (open "/proc/lift" "w" @ q
       (hot? q ? (say q p, close q, 1) 0))

   ; the fixpoint is scoped, not dropped: it can hold only where the output ought to be
   ; this binary, and a cross lay is the one case the invocation itself says it cannot.
   ; a dirty tree still fails.
   ; the lay is an egg -- the crew arrives at bake and a bake means running the artifact,
   ; which this machine cannot do for another ISA. the egg carries its source and the dist
   ; roster, so `love bake` on the target lays the crew from them (src/love/main.c), the same
   ; bytes a native `make dist` lays.
   (seed-cross root xa dst) (:- 0
    made (root + "/out/x-" + show (nom xa) + "/love")
    e (copyfile made dst)
    _ (e < 0 ? (src-die ("can't write " + dst)))
    _ (chmod dst 493)
    out? (src-lift dst)
    _ (puts (";; laid " + dst + " -- a raw egg for " + xa + ". on that machine\n"
             + ";; `love bake` lays its crew from the source it carries.\n"
             + (out? ? ";; carried out of the machine. the x bit does not travel: chmod +x it there.\n" "")
             + ";; no fixpoint claimed here: a cross lay cannot BE this binary --\n"
             + ";; `love seed` on the " + xa + " machine proves it.\n")))

   ; the wait runs in a fresh process. src-lay's inflate leaves ~200 MB of heap the parent
   ; would otherwise hold through the whole build, and no collection gives it back -- free
   ; coalesces into a list and never unmaps, so tightening the budget only raises rss. exec
   ; is the one thing that returns the pages; the waiter boots at ~57 MB. PATH, CC and the
   ; cwd all ride the environment across it, so only the root has to be said. a seat
   ; with no exec pays those pages: seed-lay calls this one straight through instead.
   (seed-wait root xa dst)
    (: exe (src-me 0)
       here (cwd 0)
       _ (!(chdir root) ? 0 (src-die ("can't enter " + root)))
       xm (string? xa ? (show (nom xa)))     ; make's word for it
       os (seed-os 0 @ o (nom? o ? [("xos=" + show o)] ()))
       ; -j with no count: cook reads this machine's width, and answers 1 where it
       ; cannot -- so the seed is as wide as the box and never wider.
       s (src-run exe (string? xa ? (["make" "-j" ("xa=" + xm)] + os + [("out/x-" + xm + "/love")])
                                    ["make" "-j" "dist"]))
       st (two? s ? <s s)
       (chdir here,
        (0 != st ? (src-die ("the build failed (exit " + show st + ")"))),
        (string? xa ? (seed-cross root xa dst)
           ; the one artifact (seed-universal U2): the seed is the laid tree's own
           ; binary, and the rebuild must be this binary, byte for byte.
           (seed-fix exe (root + "/out/love")))))

   ; the imageless projection of a binary, written beside p. a binary carrying no image
   ; is its own projection, which is how seed-fix reads either side's state.
   (seed-bare exe p)
    (: _ (unlink p)
       r (hark [exe "bake" "-n" "-o" p])
       (two? r && <r = 0 ? p ()))

   ; the fixpoint compares LIKE WITH LIKE. an image is a deterministic function of the
   ; binary carrying it (test_bakerep), so two sides in the same state are compared whole,
   ; images and all, and a mixed pair -- an installed love with no image rebuilding a baked
   ; one, either way round -- is compared stripped. that keeps a differing image a failure
   ; where both sides have one, instead of an answer no configuration could give.
   (seed-fix exe out)
    (: a (seed-bare exe (out + ".bare0"))
       b (seed-bare out (out + ".bare1"))
       ; a seat with no bake door strips NEITHER side -- the wasm guest has no ELF and no
       ; selfpath, and there both sides are unbaked by construction, so the whole compare
       ; already is like with like. one side stripping and the other not is a real refusal.
       ; every predicate parenthesised: a bare infix one swallows the arm beside it
       v (? (!(string? a) && !(string? b))          (src-same? exe out ? 'yes 'no)
            (!(string? a) || !(string? b))          'nostrip
            (!(src-same? a b))                      'no
            (src-same? a exe != src-same? b out)    'bare
            (src-same? exe out)                     'yes
                                                    'image)
       ((string? a ? (unlink a) 0),
        (string? b ? (unlink b) 0),
        (v @ 'yes   (puts (";; fixpoint ok -- " + out + "\n"), 0)
             'bare  (puts (";; fixpoint ok -- " + out + ", imageless: one side carries no image\n"), 0)
             'image (say err ";; fixpoint failed: the code matches, the images do not\n", 1)
             'nostrip (say err ";; fixpoint: can't lay an imageless copy\n", 1)
             (say err ";; fixpoint failed\n", 1))))

   ; the cross door: we are a cross compiler carrying our own source, so a seed
   ; lays a seed for a machine it is not -- which is the portability story now
   ; that one binary per ISA is the shape. Every love carries every ISA's
   ; runtime (mkrt joins all three), so any version builds any other.
   ; canonical inside, the world's word only at the doors. the prel's arch-canon takes
   ; every other spelling anyone types -- uname's, Debian's, the ISA shorthands -- so there
   ; is no second table here; `arch-mach` puts the triple word back on where make wants it
   ; (a cross toolchain's prefix is spelled a64-, never a64-).
   seed-arches '(x64 a64 rv64)
   ; the arch word is positional and A PATH still wins: `./a64` is the
   ; directory, the verb rail's own rule worn one level down.
   (seed-arch? w) (:- (go 0) n #w (go i)
                   (n <= i ? (elem (arch-nom w) seed-arches)
                             (w i @ 47 0 (go (i + 1)))))
   ; this machine's arch: love-arch is already canonical, which is seed-arches' spelling.
   (seed-native _) love-arch
   ; the OS a cross lay is for, named only where this machine cannot be asked. we are
   ; the kernel on inle, so a compile there owes the target a named OS rather than
   ; whichever hosted one reads closest (src/apps/moon/moon.l) -- linux is the word, and the
   ; make line carries it where nothing else can say it.
   (seed-os _) (elem 'love-os (names ()) && ev 'love-os @ n
                  (nom? n && !(elem n '(linux freebsd netbsd)) ? 'linux ()))

   (seed-usage _) (puts """
    usage: love seed [-g] [ARCH] [DIR]
      lay this binary's source under DIR (default .) and rebuild it there;
      the result has to BE this binary, byte for byte.
      ARCH    x64 | a64 | rv64 -- an egg for that machine instead
      -g      gregarious: the ambient cc and tools build, ours fill the gaps.
              without it ours go throughout, whatever PATH holds

    """)

   (seed-lay as0)
    (: _ (two? as0 && src-help? <as0 ? (seed-usage 0, quit 0))
       _ (two? as0 && src-vers? <as0 ? (src-vers "seed"))
       f0 (two? as0 ? <as0 "")
       greg? (f0 = "-g")
       as1 (greg? || f0 = "-a" ? >as0 as0)     ; -a is the default now; the word still eats
       ; naming this machine is a native seed, fixpoint and all: the cross lane
       ; exists for a machine we are not, and the fixpoint is scoped to where the
       ; output ought to be this binary -- which `love seed x64` on an x64
       ; box asks for exactly as much as a bare `love seed`. the word is eaten either
       ; way, or the arch would go on to be read as the directory.
       xa0 (two? as1 && seed-arch? <as1 ? (arch-nom <as1) ())
       xa (nom? xa0 && xa0 = seed-native 0 ? () xa0)
       as (nom? xa0 ? >as1 as1)
       dir (two? as ? <as ".")
       _ (src-dash? dir ? (src-not-dir "seed" dir))
       exe (src-me 0)
       ; a seat with no path to itself lays an egg for another machine and nothing
       ; else: a native seed's claim is that the rebuild IS this binary, and there is
       ; no file here to hold it to.
       _ (!(string? exe) && !(nom? xa) ?
          (src-die "this seat has no path to itself -- name a machine: `love seed x64`"))
       root (src-nest dir)
       farm (string? exe ? (src-farm root exe) "")
       path ("" + getenv "PATH")
       ; ours lead, so ours win wherever we carry a tool of that name; -g puts them
       ; last, where they fill the gaps only. the build's shells read the same choice
       ; off LUSHFLAGS: -g (gregarious) hands a bare word to PATH first, ours in its gaps (the
       ; bootstrap through an ambient cc and userland), -a keeps lush autonomous, PATH deciding nothing
       _ (string? exe ? (setenv "PATH" (greg? ? (path + ":" + farm) (farm + ":" + path))) 0)
       _ (setenv "LUSHFLAGS" (greg? ? "-g" "-a"))
       ; naming ourselves where there is no path to name: `love` is a verb like every
       ; other (src/love/boot/cli), so the Makefile's driving-love lane reaches this binary by
       ; word. no love0 is compiled under it -- there is no seat here to run one.
       _ (string? exe ? 0 (setenv "LOVE" "love"))
       env (getenv "CC")
       ; the probe writes into the laid tree's root: it is the one directory a lay
       ; is known to have made, and the two scratch files go straight back out
       amb (greg? && string? exe && !(string? env) ? (src-cc root))
       ; something has to be named. the tree carries no love, so an unnamed CC is the
       ; ambient cc and nothing else -- right as make's default, wrong as this verb's
       ; answer where the probe just found no cc that works. a working ambient one is the
       ; stronger claim, a foreign compiler holding the scaffold being the one thing a self
       ; build cannot say; this binary's own mooncc is the fallback, and the default
       ; takes it outright. naming CC reaches any other mix: `CC="<love> mooncc" love seed`
       ; is our compiler under an ambient userland. `cc` is that compiler's own verb
       ; row, which is the whole of CC on a seat whose PATH is the registry.
       _ (string? env ? 0
          (two? amb ? (setenv "CC" <>amb)
           (setenv "CC" (string? exe ? (exe + " mooncc") "cc"))))
       _ (!greg? ? (puts ";; using own tools throughout\n")
            (src-ours src-needs @ ours
               (two? ours ? (puts $ ";; using own tools: " + (src-words ours) + "\n") 0)))
       cc (? (string? env) env (two? amb) <>amb "this binary")
       ; the OS rides the word where we had to pick one, because nothing else here says it
       tgt (nom? xa ? (seed-os 0 @ o (" " + show xa + (nom? o ? ("-" + show o) ""))) "")
       _ (puts (";; seeding" + tgt + " -- the compiler is " + cc + "\n"))
       dst (nom? xa ? (dir + "/love-" + show xa) ())
       _ (string? exe ? 0 (quit (seed-wait root (show xa) dst)))   ; nothing to exec: wait here
       e (nom? xa ? (exec [exe "seed" "-wait" root (show xa) dst])
                    (exec [exe "seed" "-wait" root]))
       (src-die ("can't wait for the build (exec: " + show e + ")")))

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
   ; the artifact is the kernel: this verb emits
   ; the flat image a boot door eats, from nothing but what it already carries.
   ; the boot stub is laid here, not stored: mkboot.l rides the carried tree and
   ; holo is baked, so the lay's cat (kore text/u/asbook, then mkboot, then
   ; kproject) evals off /love, exactly the shape the Makefile cats from the
   ; tree. the arch is the binary's own -- e_machine says it, and a
   ; projection of self can be nothing else.
   (kern-pick nm)
    (uread ("/love/" + nm) @ [1 s] (s + "") (src-die ("the carried tree has no " + nm)))
   (kern-b16 s i) (s i + 256 * s (i + 1))
   kern-box {}                  ; the verb's inputs, read back by the stream
   (kernel-main as)
    ; the operand is a path to WRITE, so the flags are asked before it: a `-h` taken
    ; for one lays a kernel in a file called -h
    (: usage "usage: love kernel OUT.elf"
       _ (two? as && src-help? <as ? (puts (usage + "\n"), quit 0))
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
       ; the inputs cross on the verb table -- the one tablet every layer can
       ; reach ((cite 'verbs 'tab) hands the real thing) -- under a key pulled
       ; back off below, so `love verbs` never lists it. the stream evals in
       ; its own layer, where a plain name cannot cross either way; its last
       ; form does the whole projection where everything is visible, so
       ; nothing has to cross back out either.
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
        puts (";; wrote " + out + " (" + arch + ")\n"),
        0))

   ; -- nest: this binary laid as the user's love under ~/.love/bin, the tools linked to it --
   ; the build stamp is the carried tree's STAMP (src/tools/selfpack.l lays it); 0 where this
   ; binary carries no source, or no stamp in it
   (nest-stamp _)
    (uread "/love/STAMP" @ [1 s] (: v <(sound (s + "")) (charm? v ? v 0)) 0)
   ; a stamp as its utc minute, which is what a person compares
   (nest-when t)
    (t < 1 ? "unstamped"
       (: d (civil (t // 86400)) m (t % 86400 // 60)
          (two x) (x < 10 ? ("0" + show x) (show x))
          (show <d + "-" + two <>d + "-" + two <>>d + " " + two (m // 60) + ":" + two (m % 60)
           + " utc")))
   ; the installed love's stamp, asked of it: 0 when it has none to give. its verbs are
   ; read first, so a love older than nest is never handed a word it would complain about
   (nest-theirs p)
    (: vs (hark [p "verbs"])
       has (<vs = 0 && elem "nest" (lines >vs))
       r (has ? (hark [p "nest" "--stamp"]) [1 ""])
       v (? (<r = 0) <(sound >r) 0)
       (charm? v ? v 0))
   (nest-read p) (uread p @ [1 s] (s + "") ())
   ; the one tool linked to love by its own name, the argv[0] door: lush, autonomous by
   ; default, runs every other verb by name (`lush -c 'mooncc ..'`), PATH or no PATH
   nest-tools ["lush"]
   nest-keep ["love" "lush"]
   ; what an earlier nest or install laid that the one install no longer keeps: a link to
   ; love by another name, the lux script, the bao launcher, the papel link to its source.
   ; anything else in the nest is not ours to judge, and stays
   (nest-laid? p)
    (readlink p @ l
       (? (string? l) (l = "love" || (#l > 17 && snip l (#l - 17) #l = "/src/apps/papel.l"))
          (nest-read p @ s
             (string? s && (snip s 0 41 = "#!/usr/bin/env -S love -l\n; src/apps/lux/"
                            || 0 <= fsub s "((cite 'cli 'shell) 0)" 0)))))
   (nest-stale bin)
    (filter (nm \ 0 < #nm && nm 0 != 46 && !(elem nm nest-keep) && nest-laid? (bin + "/" + nm))
            (two? (stat bin) ? (readdir bin) ()))
   ; a ~/.local/bin link into the nest whose name the nest no longer holds, or will not
   (nest-stale-compat home bin gone)
    (: d (home + "/.local/bin")
       (filter (nm \ 0 < #nm && nm 0 != 46 && readlink (d + "/" + nm) = bin + "/" + nm
                     && (elem nm gone || !(two? (stat (bin + "/" + nm)))))
               (two? (stat d) ? (readdir d) ())))

   ; the plan: what is there, what this build is, and what to do about each. the verdict
   ; says how the two builds stand -- 'fresh (none there) 'older 'same (these very bytes)
   ; 'twin (one stamp, other bytes) 'newer -- and 'bin is 'lay or 'keep. a tool's 'was is
   ; its link's target, "a file", or "" when absent; its 'act is 'link or 'keep
   (nest-plan f?)
    (: home (getenv "HOME")
       _ (string? home && #home ? 0 (src-die "nest: no HOME"))
       me (selfpath 0)
       _ (string? me ? 0 (src-die "nest: cannot find this binary"))
       bin (home + "/.love/bin") dst (bin + "/love")
       new (nest-read me)
       _ (string? new ? 0 (src-die ("nest: cannot read " + me)))
       old (two? (stat dst) ? (nest-read dst))
       mine (nest-stamp 0)
       theirs (string? old ? (nest-theirs dst) 0)
       vd (? !(string? old) 'fresh (old = new) 'same (theirs < mine) 'older (theirs = mine) 'twin 'newer)
       lay (elem vd '(fresh older) || f? && !(vd = 'same))
       (tool nm) (: p (bin + "/" + nm) l (readlink p)
                    was (? (string? l) l (two? (stat p)) "a file" "")
                    {'nm nm 'was was 'act (was = "love" ? 'keep 'link)})
       gone (nest-stale bin)
       {'home home 'bin bin 'dst dst 'me me 'new new 'mine mine 'theirs theirs 'verdict vd
        'lay (lay ? 'lay 'keep) 'tools (map tool nest-tools)
        'gone gone 'gonec (nest-stale-compat home bin gone)})
   ; the verdict, said
   (nest-verdict pl) (pl 'verdict @
    'fresh "the nest has no love yet"
    'older "the nest's love is older"
    'same "the nest's love is this very build"
    'twin "the nest's love has this stamp but other bytes"
    "the nest's love is newer")
   ; a tool's line: what it is, and what it becomes
   (nest-tool-line pl t)
    (: nm (t 'nm) was (t 'was) pad (fill1 8 nm)
       (? (t 'act = 'link) (pad + (#was ? was "absent") + " -> love")
          (was = "love") (pad + "love")
          (pad + (#was ? was "absent") + ", kept")))
   (fill1 n s) (n <= #s ? (s + " ") (fill1 n (s + " ")))
   ; the plan, said: every line a person needs to say yes to it
   (nest-lines pl)
    ([("~/.love/bin/love: " + nest-when (pl 'theirs)
       + (pl 'verdict = 'fresh ? " (none)" "") + ", this build: " + nest-when (pl 'mine))
      (nest-verdict pl)
      (pl 'lay = 'lay ? "lay this build as ~/.love/bin/love" "leave ~/.love/bin/love as it is")
      "the tools:"]
     + map (t \ "  " + nest-tool-line pl t) (pl 'tools)
     + map (nm \ "  " + fill1 8 nm + "laid by an earlier install, removed") (pl 'gone)
     + map (nm \ "  ~/.local/bin/" + nm + " removed") (pl 'gonec))
   ; ~/.local/bin is already on PATH where ~/.love/bin is not; a name there that is not
   ; ours already is left alone
   (nest-compat home bin nm)
    (: d (home + "/.local/bin") p (d + "/" + nm) to (bin + "/" + nm)
       (!(two? (stat d)) || string? (readlink p) || two? (stat p) ? 0 (symlink to p)))
   ; the plan carried out: the lines it says of what it did
   (nest-apply pl)
    (: home (pl 'home) bin (pl 'bin) dst (pl 'dst)
       _ (mkdir (home + "/.love") 493) _ (mkdir bin 493)
       laid (pl 'lay = 'lay ?
               (: tmp (bin + "/.love.new")
                  q (open tmp "w")
                  _ (hot? q ? (say q (pl 'new), close q) (src-die ("nest: cannot write " + tmp)))
                  _ (chmod tmp 493)
                  ; the copy runs before it takes the name: a binary cut short, or one a
                  ; gate left half-built, never becomes the love on PATH
                  ok (hark [tmp "-e" "1 + 1"])
                  _ (<ok = 0 && >ok = "2\n" ? 0
                       (unlink tmp, src-die "nest: the copy does not run; nothing replaced"))
                  e (rename tmp dst)
                  ((!e ? 0 (unlink tmp, src-die ("nest: cannot rename over " + dst))),
                   [("~/.love/bin/love is now " + nest-when (pl 'mine)
                     + (pl 'verdict @ 'fresh "" (", was " + nest-when (pl 'theirs))))])))
       ; a link to love wants a love to point at
       there (two? (stat dst))
       (link t) (bin + "/" + t 'nm @ p
                   (unlink p, symlink "love" p,
                    readlink p = "love"))
       ls (there ? (filter (t \ t 'act = 'link && link t) (pl 'tools)))
       _ (each (pl 'gone) (nm \ unlink (bin + "/" + nm)))
       _ (each (pl 'gonec) (nm \ unlink (home + "/.local/bin/" + nm)))
       gn (pl 'gone + map (nm \ "~/.local/bin/" + nm) (pl 'gonec))
       ((there ? (each ("love" . map (t \ t 'nm) (pl 'tools)) (nest-compat home bin)) 0),
        laid + (two? ls ? [("linked " + foldl (a \ t \ a + " " + t 'nm) (<ls 'nm) >ls)])
        + (two? gn ? [("removed " + foldl (a \ n \ a + " " + n) <gn >gn)])))
   (nest-usage _)
    (say err "usage: love nest [-f] [-y | -n] [--stamp]
  lay this binary as ~/.love/bin/love and link its tools beside it. on a terminal the
  nest opens as a floor to walk; -y and -n are the plain ways, and the one taken
  anywhere else
  -y, --yes      do it: a newer build there, or one of this stamp, is kept unless -f
  -n, --dry-run  say the plan and leave
  -f, --force    lay this build whatever is there
  --stamp        print this build's stamp and leave
")
   (nest-main as)
    (: known ["-f" "--force" "-y" "--yes" "-n" "--dry-run" "--stamp"]
       bad (filter (a \ !(elem a known)) as)
       _ (two? bad ?
            (? (src-help? <bad) (nest-usage 0, quit 0)
               (src-vers? <bad) (src-vers "nest")
               (say err ("love nest: unknown option " + <bad + "\n"), nest-usage 0, quit 2))
            0)
       (has? a b) (elem a as || elem b as)
       f? (has? "-f" "--force") y? (has? "-y" "--yes") n? (has? "-n" "--dry-run")
       _ (elem "--stamp" as ? (puts (show (nest-stamp 0) + "\n"), quit 0) 0)
       pl (nest-plan f?)
       (say1 m) (puts ("love nest: " + m + "\n"))
       (sayall ls) (each ls (l \ puts (l + "\n")))
       floor (cite 'roost 'roost-run)
       term (two? (tty 0) && two? (tty 1))
       (? n? (sayall (nest-lines pl), 0)
          (term && !y? && floor)
          (floor pl @ r
             (r = 'apply ? (sayall (map (l \ "love nest: " + l) (nest-apply pl)), 0)
                (say1 "nothing changed", 0)))
          ; the plain way: a build no newer is kept, and says why
          (pl 'verdict @ vd
             ((elem vd '(newer twin) && !f? ?
                 (say err ("love nest: ~/.love/bin/love is " + nest-when (pl 'theirs)
                           + ", this is " + nest-when (pl 'mine)
                           + (vd = 'twin ? ", a different build" "")
                           + " -- -f lays this one\n"),
                  quit 1)
                 0),
              (vd = 'same ? (say1 ("~/.love/bin/love is this build already, " + nest-when (pl 'mine))) 0),
              sayall (map (l \ "love nest: " + l) (nest-apply pl)),
              0))))

   ; -- lux: the window manager, a verb over the source this binary carries. its modules
   ;    read in the Makefile's order (luxfiles), so the wm and its love never skew; it
   ;    restarts by exec'ing its own argv, which comes back here --
   lux-modules ["core" "layout" "wire" "ewmh" "manage" "keys" "config" "lux"]
   (lux-main as)
    (: cat (foldl (a \ m \ a + kern-pick ("src/apps/lux/" + m + ".l")) "" lux-modules)
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
