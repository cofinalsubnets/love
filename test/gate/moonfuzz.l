; test/gate/moonfuzz.l -- moon's refusal surface, fuzzed: each test/cc file broken eight ways from
; a fixed seed, run inside a woken mooncc image with clay borrowed as a module.
;   p1 the front end survives: no mutant may scare or hang. a red.
;   p2 a refusal names its cause with a gripe. a census printed by stage, not a red.
;   p3 (cparse (clay-show ast)) == ast on every mutant that parses. a red.
; a run where nothing parsed and nothing refused proved nothing, so the floors are explicit.
(borrow 'posix)
(:
   _ (borrow "src/apps/moon/clay.l")
   _ (borrow 'moon)                       ; the front end (clex/cpp/cparse-t) is module 'moon
   cshow (cite 'clay 'clay-show)
   cok? (cite 'clay 'clay-ok?)
   nl (string 10)
   (say1 s) (puts (s + nl))
   (dotc? s) (#s @ n (2 < n && s (n - 2) = 46 && s (n - 1) = 99))
   (mn a b) (a < b ? a b)

   ; --- the scare trap. help resumes with its value (test/help.l), so a caught
   ; scare does not unwind -- it flips the flag and the stage carries on with the
   ; zero point. that is fine: the flag is read after the case either way, and a
   ; stage that then loops is p1's other face, a hang, which the recipe's timeout
   ; owns because nothing inside the process can.
   scared {}
   _ (hear (a \ b \ (pin scared 0 1, 0)))
   (unscared _) (pin scared 0 0)
   (scared? _) (peep scared 0 0)

   ; --- the mutations. text in, text out, threading the rng state (test/fuzz.l's
   ; generator shape: st -> (value . st')). eight of them, chosen because each
   ; breaks the source at a different stage: a truncation dies in the reader, a
   ; punctuation insert in the parser, a dropped line in the type checker.
   punct "(){}[];,*&+-/%<>=!?:#\\\"'"
   (linelo txt i) (: (go k) (? (k < 1) 0 (txt (k - 1) = 10) k (go (k - 1))) (go i))
   (linehi txt i) (: n #txt
                     (go k) (? (n <= k) n (txt k = 10) (k + 1) (go (k + 1)))
                     (go i))
   (mut txt st)
    (: n #txt
       r0 (random st 8)      k <r0
       r1 (random >r0 n)     i <r1
       r2 (random >r1 24)    m (<r2 + 1)
       r3 (random >r2 #punct) c (string (punct <r3))
       st' >r3
       a (snip txt 0 i)
       lo (linelo txt i) hi (linehi txt i)
       out (? (k = 0) a                                              ; truncate
              (k = 1) (a + snip txt (mn n (i + 1)) n)              ; delete one byte
              (k = 2) (a + snip txt (mn n (i + m)) n)              ; delete a run
              (k = 3) (a + c + snip txt (mn n (i + 1)) n)          ; flip a byte
              (k = 4) (a + c + snip txt i n)                       ; insert punctuation
              (k = 5) (mn (n - 1) (i + 1) @ j                      ; swap two
                         (? (j <= i) txt
                            (snip txt 0 i) + (snip txt j (j + 1)) + (snip txt i (i + 1))
                              + (snip txt (j + 1) n)))
              (k = 6) (snip txt 0 lo + snip txt hi n)            ; drop a line
              (snip txt 0 lo + snip txt lo hi + snip txt lo n))  ; double a line
       (. out st'))

   ; --- the front end off TEXT, every stage's refusal kept apart and its carrier
   ; read. cc-parse's udie is deliberately not in the path: a refusal has to come
   ; back as a value here, since the whole point is counting how they arrive.
   ; answers ('bad stage carrier) or ('ok ast).
   ; the include hook is the driver's, rooted at test/cc/ -- a stub that resolves
   ; nothing would have counted the corpus's own `#include <stdarg.h>` as a cpp
   ; refusal in every mutant of every file that has one, and the census would have
   ; been measuring the harness.
   (front txt)
    (clex txt @ lx
       (!(okv? lx) ? ['bad 'lex lx]
          (cpp <>lx (n \ s \ (incload () () "test/cc/" n s)) "<fuzz>" @ pp
             (!(okv? pp) ? ['bad 'cpp pp]
                (cparse-t <>pp 'x64 @ ps
                   (!(okv? ps) ? ['bad 'parse ps]
                      (cgen-obj <>ps (cauup ps) (caup (cuup ps)) (cauup (cuup ps)) () 'x64 @ g
                         (!(okv? g) ? ['bad 'gen g] ['ok <>ps (ps 3)]))))))))

   ; --- one mutant -> a verdict symbol, plus the stage it died in when it died.
   ; ('scare ..) beats everything: a case that scared is not a refusal, it is a fall.
   (one txt)
    (: _ (unscared ())
       r (front txt)
       sc (scared? ())
       ; the scare's stage is 'late when the front end still answered -- (r 1)
       ; there is the whole AST, and it is a census key. a red run has to stay
       ; readable, so a tree never becomes one.
       (? sc ['scare (<r = 'bad ? (r 1) 'late)]
          (<r = 'bad)
          (: st (r 1) cy (r 2)
             (gripe? cy ? ['named st] ['bare st]))
          ; it parsed. the clay leg -- G1 over a tree the corpus never had.
          (: a (r 1)
             v (cok? a)
             ; cparse keeps a definition's return type in its sigs, not the tree;
             ; clay's RET slot is where the shower reads it
             (rety f) (two? f && <f = 'fn && #f = 4 && two? (r 2 (f 1)) ? (f + [<(r 2 (f 1))]) f)
             (!(v = 1) ? ['badshape 'clay]
                (cshow (<a = 'prog ? ['prog (map rety <>a)] a) @ t
                   (gripe? t ? ['inexpr 'clay]
                    (front t @ b
                       (? !(<b = 'ok) ['reparse 'clay]
                          (b 1 = a) ['ok 'clay]
                          ['diff 'clay]))))))))

   files (filter dotc? (readdir "test/cc"))
   ; per file: muts mutants, from a seed keyed by the file's own index, so a red
   ; names a (file, case) pair that reproduces on its own.
   muts 8

   ; the census: one tablet keyed by "verdict/stage", so a new verdict cannot fall
   ; through a chain of ids into silence.
   cen {}
   (ckey v s) (string v + "/" + string s)
   (bump v s) (pin cen (ckey v s) (1 + peep cen (ckey v s) 0))
   (cnt v s) (peep cen (ckey v s) 0)
   sins {}                       ; the named ones: verdict -> a list of cases
   (sin k f) (pin sins k (. f (sins k)))

   (runfile idx f)
    (uread ("test/cc/" + f) @ r
       (atom? r ? 0
        (: src <>r
           (go j st) (muts <= j ? 0
              (: mr (mut src st)
                 v (one <mr)
                 (bump <v (v 1),
                  (elem <v '(scare diff badshape reparse) ?
                     (sin <v (f + ":" + show j)) 0),
                  go (j + 1) >mr)))
           (go 0 (wheel (1 + idx))))))

   (walk l i) (atom? l ? 0 (runfile i <l, walk >l (i + 1)))
   _ (walk files 0)

   ; --- the report. the census first (P2, a measurement), then the reds (P1, P3).
   stages '(lex cpp parse gen)
   nbare (foldl (a \ s \ (a + cnt 'bare s)) 0 stages)
   nnamed (foldl (a \ s \ (a + cnt 'named s)) 0 stages)
   nok (cnt 'ok 'clay) nix (cnt 'inexpr 'clay)
   nscare (foldl (a \ s \ (a + cnt 'scare s)) 0 stages
           + cnt 'scare 'clay + cnt 'scare 'late)
   ndiff (cnt 'diff 'clay) nrep (cnt 'reparse 'clay) nbs (cnt 'badshape 'clay)
   nfile #files
   total (nfile * muts)

   _ (each stages (s \ (: b (cnt 'bare s) g (cnt 'named s)
        (b + g ? (say1 ("moonfuzz: " + string s + " refused " + show (b + g)
                        + " -- " + show g + " named, " + show b + " bare")) 0))))
   _ (say1 ("moonfuzz: " + show nok + " still parsed and round-tripped, "
            + show nix + " inexpressible"))
   _ (say1 ("moonfuzz: " + show (nbare + nnamed) + " refusals over " + show total
            + " mutants of " + show nfile + " files"))

   ; the named reds, by name -- a count alone would let a regression hide in a bucket
   _ (each '(scare diff badshape reparse)
        (v \ (each (rev (sins v)) (f \ (say1 ("moonfuzz: " + string v + " " + f))))))

   ; the floors. a run where nothing refused, or nothing survived to reach clay,
   ; measured nothing and must not print pass.
   _ (nbare + nnamed < 100 || nok < 100 ?
        (say1 ("moonfuzz: FAIL -- vacuous run (" + show (nbare + nnamed)
                    + " refusals, " + show nok + " round-trips): the front end is not in scope"), quit 1) 0)
   (!(nscare + ndiff + nbs + nrep) ?
      (say1 "moonfuzz: pass", quit 0)
      (say1 ("moonfuzz: FAIL -- " + show nscare + " scared, " + show ndiff
                  + " clay diff, " + show nbs + " malformed, " + show nrep + " unreadable"), quit 1)))
