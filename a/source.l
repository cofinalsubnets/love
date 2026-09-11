; the wrap: see a/tar/tarcmd.l -- `borrow` splices into the current layer, so the two asks
; need a layer of this file's own rather than the dist cat's. the seed's lay reads the
; carried archive through both, and rode that cat's leak to reach them before.
(module 'source
(borrow 'gz)
(borrow 'tar)

(borrow 'posix)
(: (src-die m) (say err (";; " + m + "\n"), quit 1)

   ; the directory is positional, so a mistyped flag would be taken as one and a whole
   ; tree laid under it. a leading dash is never a directory here: name the flags, ask
   ; about anything else.
   (src-dash? w) (: n #w (0 < n && w 0 = 45))
   (src-help? ("-h" || "--help" || "-help" || "help")) 1
   (src-vers? ("-v" || "--version")) 1
   (src-vers m) (puts (m + " (love " + love-version + ")\n"), quit 0)
   (src-not-dir m w)
    (src-die (w + " is not a directory -- `love " + m + " help` for usage"))

   (src-head nom) (: n #nom
                     (go i) (? (n <= i) nom (nom i = 47) (snip nom 0 i) (go (i + 1)))
                     (go 0))

   (src-top es) (? (one? es) ""
    (src-head (tar-get <es 'nom "") @ ("." || "") (src-top >es) c c))

   (src-lay-tgz root top gz)
    (: _ (mkdir (root + "/b") 493)
       _ (mkdir (root + "/b/dist") 493)
       p (root + "/b/dist/" + top + ".tar.gz")
       q (open p "w")
       _ (!(hot? q) ? (src-die ("can't write " + p)))
       _ (say q gz)
       _ (close q)
       p)

   (src-lay dir)
    (: gz (source-gz "x")
       _ (!(string? gz) ? (src-die "this love carries no source"))
       u (gz-unzip gz)
       _ (one? u ? (src-die "the embedded archive did not inflate"))
       t (tar-unpack <>u)
       _ (one? t ? (src-die "the embedded archive is torn"))
       es <>t
       top (src-top es)
       _ (0 >= #top ? (src-die "the embedded archive names no top directory"))
       w (tar-scatter dir es)
       _ (one? w ? (src-die ("can't write " + dir)))
       root (dir = "." ? top (dir + "/" + top))
       ; no love is laid beside the source: which mode a build is in belongs to whoever
       ; drives it. bare make has no love and can only mean the ambient cc; a love driving
       ; knows its own selfpath and says so in CC. a copy in bin/ would be the toolchain by
       ; being there, which is a claim made by a file existing rather than by anyone.
       (src-lay-tgz root top gz,
        [1 root <>w]))

   (src-usage _)
    (puts ("usage: love source [DIR]\n  lay this binary's carried source tree under DIR (default .)\n"))

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
       (? !(hot? q) 0
          (: _ (say q "int main(void){return 0;}\n")
             _ (close q)
             nul (openfd "/dev/null" 1)
             p (spawnio [cc "-c" "-o" o c] -1 nul nul () -1 0)
             st (0 <= p ? (wait p) 1)
             _ (0 <= nul ? (close nul) 0)
             _ (unlink c) _ (unlink o)
             (0 = st))))
   (src-cc dir)
    (: (try (w . x))
     (: (go ds) (one? ds ? (try x)
              (: d (#<ds ? <ds ".") p (d + "/" + w)
               (src-foreign? p && src-ccworks? p dir ? [1 p] (go >ds))))
      (go (src-dirs ())))
     (try '("cc" "gcc" "clang")))
   (src-farm root exe)
    (d : (root + "/b/.seedbin")
       ; a laid tree carries no b/, and mkdir makes one directory: the parent first
       (mkdir (root + "/b") 493, mkdir d 493,
        each (keys (cite 'verbs 'tab))
             (k \ (d + "/" + string k @ p (unlink p, symlink exe p))),
        d))
   ; the autonomous arming, what a seed sets before its build: the farm of our verbs
   ; first on PATH, lush autonomous, CC our mooncc. `love serve` and `love doom` build
   ; under the same, so a nest or a page is ours throughout whatever PATH holds -- a
   ; tree our mooncc built and an object the ambient cc made link neither way.
   (src-arm root exe)
    (: farm (src-farm root exe)
       _ (setenv "PATH" (farm + ":" + getenv "PATH"))
       _ (setenv "LUSHFLAGS" "-a")
       _ (setenv "CC" (exe + " mooncc"))
       ; the arm, said out loud: a recipe's `cat` is kore's here and its shell is lush,
       ; so the build's tags name the tool that RAN (common.mk). LUSHFLAGS is not
       ; that answer -- a person may set it for their own reasons.
       _ (setenv "LOVE_ARMED" "1")
       farm)
   src-needs '("cc" "make" "sh" "sed" "grep" "tr" "cat" "mkdir" "mv" "rm" "ln"
               "test" "uname" "printf" "install" "cmp" "chmod" "touch" "echo")
   ; kore's ujoin is not in this layer -- src-dirs rolls its own split for the
   ; same reason, so the join is local too.
   (src-words l) (? (one? l) "" (one? >l) <l (<l + " " + (src-words >l)))
   (src-ours ns) (:- (go ns ())
    (go l acc) (? (one? l) (rev acc)
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
   (src-chunk q b) (: k (swig q b) (charm? k && 0 < k ? (snip b 0 k) ""))
   (src-same? p1 p2)
    (: q1 (open p1 "r")
       q2 (open p2 "r")
       (? (!(hot? q1 && hot? q2)) (: _ (hot? q1 ? (close q1) 0) _ (hot? q2 ? (close q2) 0) 0)
          (: b1 (cask 65536)
             b2 (cask 65536)
             (go r1 r2)
              (: r1 (#r1 ? r1 (src-chunk q1 b1))
                 r2 (#r2 ? r2 (src-chunk q2 b2))
                 n1 #r1
                 n2 #r2
                 m (? (n1 < n2) n1 n2)
                 (? (0 = m) (? (0 = n1 + n2) 1 0)      ; both ended, same place
                    (n1 = n2) (r1 = r2 ? (go "" "") 0)   ; the even case: no snip at all
                    (snip r1 0 m != snip r2 0 m) 0
                    (go (snip r1 m n1) (snip r2 m n2))))
             v (go "" "")
             _ (close q1)
             _ (close q2)
             v)))

   ; the fixpoint is scoped, not dropped: it can hold only where the output ought to be
   ; this binary, and a cross lay is the one case the invocation itself says it cannot.
   ; a dirty tree still fails.
   ; the lay is an egg -- the crew arrives at bake and a bake means running the artifact,
   ; which this machine cannot do for another ISA. the egg carries its source and the dist
   ; roster, so `love bake` on the target lays the crew from them (i/main.c), the same
   ; bytes a native `make dist` lays.
   (seed-cross root xa dst)
    (: made (root + "/b/x-" + (show (nom xa)) + "/love")
       e (copyfile made dst)
       _ (e < 0 ? (src-die ("can't write " + dst)))
       _ (chmod dst 493)
       _ (puts (";; laid " + dst + " -- a raw egg for " + xa + ". on that machine\n"
                + ";; `love bake` lays its crew from the source it carries.\n"
                + ";; no fixpoint claimed here: a cross lay cannot BE this binary --\n"
                + ";; `love seed` on the " + xa + " machine proves it.\n"))
       0)

   ; the wait runs in a fresh process. src-lay's inflate leaves ~200 MB of heap the parent
   ; would otherwise hold through the whole build, and no collection gives it back -- free
   ; coalesces into a list and never unmaps, so tightening the budget only raises rss. exec
   ; is the one thing that returns the pages; the waiter boots at ~57 MB. PATH, CC and the
   ; cwd all ride the environment across it, so only the root has to be said.
   (seed-wait root xa dst)
    (: exe (selfpath 0)
       _ (string? exe ? 0 (src-die "can't find seed path"))
       here (cwd 0)
       _ (? !(chdir root) 0 (src-die ("can't enter " + root)))
       xm (? (string? xa) (show (nom xa)) ())     ; make's word for it
       ; -j with no count: cook reads this machine's width, and answers 1 where it
       ; cannot -- so the seed is as wide as the box and never wider.
       s (herald (string? xa ? [exe "make" "-j" ("xa=" + xm) ("b/x-" + xm + "/love")]
                              [exe "make" "-j" "dist"]))
       st (two? s ? <s s)
       _ (chdir here)
       _ (0 != st ? (src-die ("the build failed (exit " + show st + ")")))
       (? (string? xa) (seed-cross root xa dst)
          ; the one artifact (seed-universal U2): the seed is the laid tree's own
          ; binary, and the rebuild must be this binary, byte for byte.
          (seed-fix exe (root + "/b/love"))))

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
            ((src-same? a exe) != (src-same? b out)) 'bare
            (src-same? exe out)                     'yes
                                                    'image)
       _ (string? a ? (unlink a) 0)
       _ (string? b ? (unlink b) 0)
       (v @ 'yes   (puts (";; fixpoint ok -- " + out + "\n"), 0)
            'bare  (puts (";; fixpoint ok -- " + out + ", imageless: one side carries no image\n"), 0)
            'image (say err ";; fixpoint failed: the code matches, the images do not\n", 1)
            'nostrip (say err ";; fixpoint: can't lay an imageless copy\n", 1)
            (say err ";; fixpoint failed\n", 1)))

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
   (seed-arch? w) (: n #w
                     (go i) (? (n <= i) (elem (arch-nom w) seed-arches)
                               (w i = 47) 0
                               (go (i + 1)))
                     (go 0))
   ; this machine's arch: love-arch is already canonical, which is seed-arches' spelling.
   (seed-native _) love-arch

   (seed-usage _)
    (puts ("usage: love seed [-g] [ARCH] [DIR]\n"
           + "  lay this binary's source under DIR (default .) and rebuild it there;\n"
           + "  the result has to BE this binary, byte for byte.\n"
           + "  ARCH    x64 | a64 | rv64 -- an egg for that machine instead\n"
           + "  -g      gregarious: the ambient cc and tools build, ours fill the gaps.\n"
           + "          without it ours go throughout, whatever PATH holds\n"))

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
       r (src-lay dir)
       root <>r
       _ (puts (";; laid " + root + "\n"))
       exe (selfpath 0)
       _ (string? exe ? 0 (src-die "can't find seed path"))
       farm (src-farm root exe)
       path ("" + getenv "PATH")
       ; ours lead, so ours win wherever we carry a tool of that name; -g puts them
       ; last, where they fill the gaps only. the build's shells read the same choice
       ; off LUSHFLAGS: -g (gregarious) makes a bare word PATH's business (the bootstrap
       ; through an ambient cc and userland), -a keeps lush autonomous, PATH deciding nothing
       _ (setenv "PATH" (greg? ? (path + ":" + farm) (farm + ":" + path)))
       _ (setenv "LUSHFLAGS" (greg? ? "-g" "-a"))
       env (getenv "CC")
       ; the probe writes into the laid tree's root: it is the one directory a lay
       ; is known to have made, and the two scratch files go straight back out
       amb (greg? && !(string? env) ? (src-cc root))
       ; something has to be named. the tree carries no love, so an unnamed CC is the
       ; ambient cc and nothing else -- right as make's default, wrong as this verb's
       ; answer where the probe just found no cc that works. a working ambient one is the
       ; stronger claim, a foreign compiler holding the scaffold being the one thing a self
       ; build cannot say; this binary's own mooncc is the fallback, and the default
       ; takes it outright. naming CC reaches any other mix: `CC="<love> mooncc" love seed`
       ; is our compiler under an ambient userland.
       _ (string? env ? 0
          (two? amb ? (setenv "CC" <>amb) (setenv "CC" (exe + " mooncc"))))
       _ (? !greg? (puts ";; using own tools throughout\n")
            (: ours (src-ours src-needs)
               (two? ours ? (puts $ ";; using own tools: " + (src-words ours) + "\n") 0)))
       cc (? (string? env) env (two? amb) <>amb "this binary")
       _ (puts (";; seeding " + (nom? xa ? (show xa + " ") "") + "with " + cc + "\n"))
       dst (nom? xa ? (dir + "/love-" + show xa) ())
       e (nom? xa ? (exec [exe "seed" "-wait" root (show xa) dst])
                    (exec [exe "seed" "-wait" root]))
       (src-die ("can't wait for the build (exec: " + show e + ")")))

   (seed-main as0)
    (? (one? as0 || <as0 != "-wait") (seed-lay as0)
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
   ; the boot stub is laid here, not stored: mkboot.l rides the source blob and
   ; holo is baked, so the lay's cat (kore text/u/asbook, then mkboot, then
   ; kproject) evals off the in-memory tar, exactly the shape the Makefile cats
   ; from the tree. the arch is the binary's own -- e_machine says it, and a
   ; projection of self can be nothing else.
   (kern-pick es top nm)
    (: want (top + "/" + nm)
       (go l) (? (one? l) (src-die ("the blob carries no " + nm))
                 (tar-get <l 'nom "" = want) (tar-get <l 'body "")
                 (go >l))
       (go es))
   (kern-b16 s i) ((s i) + (256 * (s (+ i 1))))
   kern-box {}                  ; the verb's inputs, read back by the stream
   (kernel-main as)
    ; the operand is a path to WRITE, so the flags are asked before it: a `-h` taken
    ; for one lays a kernel in a file called -h
    (: u "usage: love kernel OUT.elf"
       _ (two? as && src-help? <as ? (puts (u + "\n"), quit 0))
       _ (two? as && src-vers? <as ? (src-vers "kernel"))
       _ (? (two? as) 0 (src-die u))
       out <as
       exe (selfpath 0)
       _ (string? exe ? 0 (src-die "can't read the seed path"))
       pie (: h (open exe "r")
             (? (hot? h) (: s (slurp h) _ (close h) s)
                (src-die "can't read this binary")))
       m (kern-b16 pie 18)
       arch (? (m = 62) "x64" (m = 183) "a64" (m = 243) "rv64"
               (src-die "no boot door for this machine"))
       gz (source-gz "x")
       _ (string? gz ? 0 (src-die "this love carries no source"))
       u (gz-unzip gz)
       _ (two? u ? 0 (src-die "the embedded archive did not inflate"))
       t (tar-unpack <>u)
       _ (two? t ? 0 (src-die "the embedded archive is torn"))
       es <>t
       top (src-top es)
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
            + kern-pick es top "a/kore/text.l"
            + kern-pick es top "a/kore/u.l"
            + "(borrow 'kore)"
            + kern-pick es top "a/kore/asbook.l"
            + kern-pick es top "i/mkboot.l"
            + kern-pick es top "u/kproject.l"
            + "(: kb (peep (cite 'verbs 'tab) 'kern-in 0)"
            + "   bb (string (cask (lay-boot-bytes (peep kb 'arch 0))))"
            + "   (kproject (peep kb 'pie 0) bb (peep kb 'out 0) (peep kb 'arch 0)))")
       _ (reads (tap ((: (g i) (? (< i #cat) (. (peep cat i 0) (g (+ 1 i))))) 0)))
       _ (pull vt 'kern-in 0)
       _ (puts (";; wrote " + out + " (" + arch + ")\n"))
       0)

   ; a binding, not a body: the letrec stays body-less, so every name above is the
   ; module's -- (cite 'source 'src-arm) for serve and doom -- and the pins still run at load
   _ (pins (cite 'verbs 'tab)
      'source source-main
      'src    source-main
      'seed   seed-main
      'kernel kernel-main))

) ; module 'source
