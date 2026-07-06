; crew/utils/au.l -- the multi-call dispatcher (busybox's trick): ONE binary, `au`,
; shadowing nothing on the host, picking the util off the command line -- or off
; argv[0] through a tool-named symlink, which is how the distro will shadow at will.
;
;   au diff OLD NEW    unified diff (patience hunks); exit 0 same / 1 differ / 2 trouble
;   au nc HOST PORT    the netcat (tools/ain.l); nc -l PORT listens
;   au make [F] [T..]  the build tool (crew/cook/cook.l)
;   au as TGT IN OUT   assemble IR forms from IN (x64|arm64) into an ELF at OUT
;   au cat|head|tail|wc|sort|uniq|tee|echo|seq|yes|true|false|basename|dirname
;   au cut|tr|nl|rev   the line + field tools + trivia (crew/utils/core.l)
;   au ls|cp|mv|rm|mkdir|rmdir|ln|touch|pwd|chmod   the fs tools (crew/utils/fs.l)
;   au grep [-nvcl] PATTERN [F..]   the BRE matcher (crew/utils/re.l)
;   au sed [-n] SCRIPT [F..]        the stream editor (crew/utils/sed.l)
;
; loads LAST in the au cat, when every tool main is already defined; the tool files'
; own SEATs stay quiet here (no file of theirs sits in the program seat), so this
; dispatcher is the one thing that fires. ONE body-having `:` -- the registry, the
; thin mains that live here (diff over the engines, as over the holo book), and the
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

   ; as: IR forms -> a runnable ELF (crew/holo/elf.l over the baked holo book)
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
              _ (pin t 'cat cat-main) _ (pin t 'echo echo-main)
              _ (pin t 'head head-main) _ (pin t 'tail tail-main)
              _ (pin t 'wc wc-main) _ (pin t 'sort sort-main)
              _ (pin t 'uniq uniq-main) _ (pin t 'tee tee-main)
              _ (pin t 'seq seq-main) _ (pin t 'yes yes-main)
              _ (pin t 'true true-main) _ (pin t 'false false-main)
              _ (pin t 'basename basename-main) _ (pin t 'dirname dirname-main)
              _ (pin t 'cut cut-main) _ (pin t 'tr tr-main)
              _ (pin t 'nl nl-main) _ (pin t 'rev rev-main)
              _ (pin t 'ls ls-main) _ (pin t 'cp cp-main) _ (pin t 'mv mv-main)
              _ (pin t 'rm rm-main) _ (pin t 'mkdir mkdir-main) _ (pin t 'rmdir rmdir-main)
              _ (pin t 'ln ln-main) _ (pin t 'touch touch-main)
              _ (pin t 'pwd pwd-main) _ (pin t 'chmod chmod-main)
              _ (pin t 'grep grep-main) _ (pin t 'sed sed-main)
              t)
   (usage _) (: _ (say err "au -- the ai multi-call toolbox
usage: au TOOL ARGS..     (or symlink a tool's name to au)
  diff OLD NEW       unified diff, patience hunks (0 same / 1 differ / 2 trouble)
  nc HOST PORT       netcat; nc -l PORT listens
  make [FILE] [T..]  the build tool (Cards.l / Cookfile / Makefile)
  as TGT IN OUT      assemble IR forms from IN (x64|arm64) into ELF OUT
  cat head tail wc sort uniq tee          the line tools (crew/utils/core.l)
  cut tr nl rev                           the field tools
  grep [-nvcl] PAT [F..]                  the BRE matcher (crew/utils/re.l)
  sed [-n] SCRIPT [F..]                   the stream editor (s///gp, d, p, q, addresses)
  ls cp mv rm mkdir rmdir ln touch pwd chmod   the fs tools (crew/utils/fs.l)
  echo seq yes true false basename dirname     ... and the trivia
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
