; apps/utils/au.l -- the multi-call dispatcher (busybox's trick): ONE binary, `au`,
; shadowing nothing on the host, picking the util off the command line -- or off
; argv[0] through a tool-named symlink, which is how the distro will shadow at will.
;
;   au diff OLD NEW    unified diff (patience hunks); exit 0 same / 1 differ / 2 trouble
;   au nc HOST PORT    the netcat (tools/ain.l); nc -l PORT listens
;   au make [F] [T..]  the build tool (apps/cook/cook.l)
;   au as TGT IN OUT   assemble IR forms from IN (x64|arm64) into an ELF at OUT
;
; loads LAST in the au cat, when every tool main is already defined; the tool files'
; own SEATs stay quiet here (no file of theirs sits in the program seat), so this
; dispatcher is the one thing that fires. ONE body-having `:` -- the registry, the
; thin mains that live here (diff over the engines, as over the asm book), and the
; dispatch as the body; nothing leaks, and every path ends in a nap (the exit door).
(: (read-text p) (: q (open p "r") (? q (: t (slurp q) _ (close q) (L 1 t)) ()))   ; (1 text) | ()
   (die m) (: _ (say err m) _ (put err 10) (nap 2))

   ; diff: two files -> unified hunks on out; the classic exit triple
   (diff-main as)
    (? (! (two? (cup as))) (die "usage: au diff OLD NEW")
       (: fa (cap as) fb (caup as)
          ta (read-text fa) tb (read-text fb)
          _ (? (two? ta) () (die (+ "diff: cannot open " fa)))
          _ (? (two? tb) () (die (+ "diff: cannot open " fb)))
          d (udiff fa fb (caup ta) (caup tb))
          (? (nil? d) (nap 0)
             (: _ (puts d) _ (flush out) (nap 1)))))

   ; as: IR forms -> a runnable ELF (apps/asm/elf.l over the baked asm book)
   (as-main as)
    (? (! (two? (cup (cup as)))) (die "usage: au as TARGET IN OUT   (TARGET: x64 | arm64)")
       (: tgt (intern (cap as)) src (caup as) dst (caup (cup as))
          _ (? (|| (= tgt 'x64) (|| (= tgt 'amd64) (|| (= tgt 'arm64) (= tgt 'aarch64)))) ()
               (die (+ "as: unknown target " (cap as))))
          q (open src "r")
          _ (? q () (die (+ "as: cannot open " src)))
          e (nom 0)
          (rd acc) (: r (sound q e)
                      (? (id? r e) (rev acc)
                         (id? r q) (die (+ "as: unfinished form in " src))
                         (rd (link r acc))))
          ir (rd ())
          _ (? (two? ir) () (die (+ "as: no IR forms in " src)))
          res (elf64 tgt (\ _ ir) ())
          _ (write-bytes dst (peep res 'bytes 0))
          _ (say err (+ "as: wrote " dst)) _ (put err 10)
          (nap 0)))

   ; the registry: name -> main (aliases share)
   applets (: t (tablet 0)
              _ (pin t 'diff diff-main)
              _ (pin t 'nc ain-main) _ (pin t 'ain ain-main)
              _ (pin t 'make cook-main) _ (pin t 'cook cook-main)
              _ (pin t 'as as-main)
              t)
   (usage _) (: _ (say err "au -- the ai multi-call toolbox
usage: au TOOL ARGS..     (or symlink a tool's name to au)
  diff OLD NEW       unified diff, patience hunks (0 same / 1 differ / 2 trouble)
  nc HOST PORT       netcat; nc -l PORT listens
  make [FILE] [T..]  the build tool (Cards.l / Cookfile / Makefile)
  as TGT IN OUT      assemble IR forms from IN (x64|arm64) into ELF OUT
")
                (nap 2))
   (bn p) (: n (tally p)
             (go k r) (? (< k n) (go (+ k 1) (? (= (p k) 47) (+ k 1) r)) (snip p r n))
             (go 0 0))

   ; -- the dispatch (this form's body) --
   ; the program seat off the true command line (cmdline is never rebound, so the
   ; read is the same whether au loaded positionally or as a -l preload): drop the
   ; -l pairs, and the first element left is the seat. its BASENAME picks the face
   ; -- a tool name (the symlink lane) runs that tool on the rest; anything else
   ; (au itself, a dev path) reads the next word as the tool.
   (seat a) (? (! (two? a)) ()
               (= (cap a) "-l") (? (two? (cup a)) (seat (cuup a)) ())
               a)
   (: s (seat (cup cmdline))
      _ (? (two? s) () (usage ()))
      f0 (applets (intern (bn (cap s))))
      _ (? f0 (: _ (f0 (cup s)) (nap 0)) ())
      t (cup s)
      f (? (two? t) (applets (intern (cap t))) ())
      _ (? f (: _ (f (cup t)) (nap 0)) ())
      (usage ())))
