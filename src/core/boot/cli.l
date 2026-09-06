; cli -- the console and command line: the read-eval-print loop, its multi-line line
; editor, the stream shell (read/reads), the floor handler (welp), the port-driven line
; reader (edraw/edln/edlnc) that lush drives, and the host command line, read left to
; right after the program-name head:
;   (cli-rail ln)     the walk over ln = (program-name . args)
;   (cli-line ln tty) a frontend's whole tail: the argv[0] door, the rail, the repl, stdin
; src/host/main.c calls cli-line, and so does a forked lush child -- a word whose PATH winner
; is this binary need not exec, and what it would have exec'd is (cli-line its-line) on a
; warm heap. the shadow rule lives in one place, src/core/boot/verbs.l's `word`. prel and pat
; must be up before this compiles: @ reads here, and a macro reaches a reader only once its
; layer is spliced.

(module '(cli read reads forms shell welp edraw edln edlnc cli-rail cli-line
          edleft edright edbsp eddel edhome edend edtop edbot edup eddown uphist downhist
          detach emptybuf mkframe parses joinln flatten splitat parseall)
(: (read s) (sound (hot? s ? (flow s) s) @ (x . _) (ev x)))
; reads: the stream shell -- reads and evals every form of a port, the value the last
; form's; ev late-binds ((ev 'ev r)) so one definition drives both of love0's passes.
; the two endings differ: a clean end comes between forms, `torn` inside one -- and torn
; is a scare, the reader having drunk for itself and found the end.
(: (reads p)
   (: (walk cl z) (sound cl @ 'torn (scare 'unfinished-form p)
                              (a . b) (walk b (ev 'ev a))
                              z)
      ; the shared lane, for `in`: gulp for speed, hold nothing across an eval. box slot 0 counts
      ; every byte drawn off p, so the walk can put the port where it belongs. no window on purpose:
      ; a straddling `;` comment would end one cleanly and the next reads the prose as code.
      box {}
      (drew u) (peep box 0 0)
      ; absolute, not relative -- p is already behind us, so a plain (unchug p rem) re-reads the run
      (drop n) (unchug p (n - inhand p))     ; the port to n pending; we hold the rest
      ; flow, plus the count: one chug per gulp, the run laid down as plain conses.
      (feed u)
       (see p @ -1 () c
        (: _ (unsee p c)
           t (chug p)
           _ (pin box 0 (drew () + #t))
           (go k l) (0 >= k ? l (: j (k - 1) (go j (t j . l))))
         (go #t (once (\ u (feed ()))))))
      ; consumed, forwards and by identity. never (tally >r) -- the residue is lazy, so that
      ; forces the whole rest; and force at every step, or a plain `cup` walk stops dead at a
      ; gulp boundary and spins on () forever. `once` memoizes, so re-forcing is free.
      (frc x) (lit? x ? (x ()) x)
      (upto a b n) (: aa (frc a) bb (frc b)
                      (? (= aa bb) n
                         (two? aa)   (upto (cup aa) bb (n + 1))
                         n))
      ; with no window both endings are honest -- they can only mean the stream itself ended
      (step cl walked z)
       (sound cl @
         'torn (scare 'unfinished-form p)
         (a . b) (: k (upto cl b 0)
                    w2 (walked + k)
                    rem (drew () - w2)
                    ; one byte short on purpose -- the byte-exact lane runs one ahead, and test_stdincorpus diffs it
                    _ (drop (0 < rem ? (rem - 1) 0))
                    h (inhand p)
                    v (ev 'ev a)
                    (h = inhand p ? (drop 0, step b w2 v)
                                    (start (two? b ? [<b]) v)))
         (drop 0, z))
      (start pre z)
       (see p @
        -1 (atom? pre ? z (walk pre z))
        c (unsee p c,
           inhand p ? (pin box 0 #pre, step (cat pre (feed ())) 0 z)
                      (walk (cat pre (trickle p)) z)))
      ; never rebind `in` -- this identity folded at egg-compile, so a fresh port fails it in silence
      (? (= p in) (start () 0) (walk (flow p) 0))))
(: (forms p)
   ((: (g cl acc) (sound cl @ 'torn (scare 'unfinished-form p)
                              (a . b) (g b (a . acc))
                              (rev acc)))
    (flow p) ()))

(: m (nom 0) eofsym (nom 0)

   (want n) (member? n (names ()) ? (ev n) ())
   raw (want 'raw)


   (rdall cl acc)
    (sound cl @ 'torn m                            ; unfinished shape -> more
                (a . b) (rdall b (a . acc))
                (rev acc))                         ; a clean end -> the datums, in order
   (parseall cl)
    (rdall cl () @ ^m  m                           ; unfinished shape
                   [a] [a]                         ; one datum: as-is (leading monadic preserved)
                   ds  (two? ds ? [ds]))           ; many: the application; a blank line: ()

   ; --- editor ---

   ; intersperse a list of charlists with newlines, in order
   (joinln ls)
    (ls @ (a . b) (atom? b ? a (a + (10 . joinln b))))

   ; flatten the editor state into one charlist suitable for parseall
   (flatten u l r d)
     (joinln (revcat u (revcat l r . d)))

   ; walk xs forward taking n chars into acc (reversed); when done
   ; call k with (rev (take n xs)) and (drop n xs). stops cleanly at
   ; end-of-xs even if n exceeds the list length.
   (splitat k acc n xs)
    (xs @ ((ax . ux) && 0 < n) (splitat k (ax . acc) (n - 1) ux)
     (k acc xs))

   ; map non-printables to space; otherwise pass through
   (prc c) (putc $ 32 <= c < 127 ? c 32)

   ; line editor buffer zipper arguments
   ; u up (reversed), l left (reversed), r right, d down
   (edleft k u l r d)
    (l @ (al . ul) (k u ul (al . r) d)
     (u @ (au . uu) (k uu (rev au) () (revcat l r . d))
      (k u l r d)))
   (edright k u l r d)
    (r @ (ar . ur) (k u (ar . l) ur d)
     (d @ (ad . ud) (k (revcat l r . u) () ad ud)
      (k u l r d)))
   (edbsp k u l r d)
    (l @ (_ . ul) (k u ul r d)
     (u @ (au . uu) (k uu (rev au) r d)
      (k u l r d)))
   (eddel k u l r d)
    (r @ (_ . ur) (k u l ur d)
     (d @ (ad . ud) (k u l ad ud)
      (k u l r d)))
   (edhome k u l r d) (k u () (revcat l r) d)
   (edend  k u l r d) (k u (revcat r l) () d)

   ; edtop / edbot jump across the whole buffer: cursor at the start of
   ; the topmost line / end of the bottommost line. on a single-line
   ; buffer they degenerate to edhome / edend.
   (edtop k u l r d)
    (rev u @ (au . uu) (k () () au (uu + (revcat l r . d)))
     (k u () (revcat l r) d))
   (edbot k u l r d)
    (rev d @ (ad . ud) (k (ud + (revcat l r . u)) (revcat ad ()) () ())
     (k u (revcat r l) () d))
   (edup k u l r d)
    (u @ (au . uu)(splitat (\ lz rr (k uu lz rr (revcat l r . d))) () #l au)
     (k u l r d))
   (eddown k u l r d)
    (d @ (ad . ud) (splitat (\ lz rr (k (revcat l r . u) lz rr ud)) () #l ad)
     (k u l r d))

   ; --- history zipper ---

   ; pack the buffer's four halves into one slot for history storage.
   (mkframe u l r d) (u . l . r . d)

   ; if cur holds a pristine recall, restore it at its slot in hu;
   ; called before any mutating edit so the original survives.
   (detach hu cur) (two? cur ? (cur . hu) hu)

   (emptybuf u l r d) (!u && !l && !r && !d)
   (parses u l r d)   (two? (parseall (flatten u l r d)))

   ; up/down through the history zipper. on a normal pop, push the
   ; current buffer onto the other side (skipping if empty); if the
   ; other side is empty (hu or hd) but we're on a real recall (cur
   ; non-nil) and the buffer parses, push and scroll into a fresh
   ; empty line.
   (uphist k u l r d hu hd cur)
     (? (two? hu)
        (: e <hu
           nhd (? (emptybuf u l r d) hd (mkframe u l r d . hd))
           (k <e <>e <>>e >>>e >hu nhd e))
        (two? cur && parses u l r d)
        (: nhd (mkframe u l r d . hd)
           (k () () () () hu nhd ()))
        (k u l r d hu hd cur))
   (downhist k u l r d hu hd cur)
     (? (two? hd)
        (: e <hd
           nhu (? (emptybuf u l r d) hu (mkframe u l r d . hu))
           (k <e <>e <>>e >>>e nhu >hd e))
        (two? cur && parses u l r d)
        (: nhu (mkframe u l r d . hu)
           (k () () () () nhu hd ()))
        (k u l r d hu hd cur))

   ; 0 is the miss, read with id? -- an event code nets red, so truth cannot tell hit from miss
   arrow    {68 -1 67 -2 65 -8 66 -9 72 -5 70 -6}    ; ESC [ F -- the plain finals
   modarrow {68 -1 67 -2 65 -8 66 -9 72 -10 70 -11}  ; ESC [ 1 ; M F -- modified home/end jump the buffer
   evk      {-1 -7 4 -7 3 -12 13 10 10 10 8 -3 127 -3 1 -5 5 -6}   ; the raw control bytes
   (edesc1 c) (? (c = 126) -5
                 (c = 59)  (getc 0, peep modarrow (getc 0) 0))
   (edesc x)
    (? !(91 = getc 0) 0
     (: c (getc 0) e (peep arrow c 0)
      (? !(= e 0) e
       (c @ 49 (edesc1 (getc 0))
            55 (getc 0, -5)
            (52 || 56) (getc 0, -6)
            51 (getc 0, -4)
            0))))

   (edev x)
    (: c (getc 0) e (peep evk c 0)
     (? !(= e 0) e
        (c = 27) (edesc 0)
        (32 <= c < 127 ? c)))

   ; redraw the buffer in place. pra is rows above the cursor from the previous
   ; render -- move up that many first, so we land back on the prompt's row. all
   ; motion is relative, so terminal scrolling never desyncs us. pl is the prompt's
   ; column; the topmost line shares it, later lines start at column 0.
   (csi n f) (putc 27, putc 91, putn n, putc f)   ; ESC [ n f -- the one cursor verb
   (edrender pl pra u l r d)
     (: _ (0 < pra ? (csi pra 65),
           putc 13,
           0 < pl ? (csi pl 67),
           putc 27, putc 91, putc 74, ; clear to end of screen
           each (rev u) (\ ln (each ln prc, putc 10)),
           each (revcat l r) prc,
           each d (\ ln (putc 10, each ln prc)))
        ld (tally d)
        col ((two? u ? 0 pl) + tally l)
        (0 < ld ? (csi ld 65),
         putc 13,
         0 < col ? (csi col 67),
         flush out))

   ps1 "> "
   ; the helm glows in the crew's cyan (256-colour 117 ~ #7dcfff), reset after.
   ; SGR is zero-width to both the host terminal and the inle console (src/core/quay/quay.c),
   ; so `pl` below stays (tally ps1) and the cursor math is undisturbed.
   ps1c (string 27 + "[38;5;117m" + ps1 + string 27 + "[39m")

   ; print the prompt, then dispatch events until ^D or a submitted buffer.
   ; returns eofsym on ^D, else (vs . nhu) so the repl can thread history.
   (edline hu hd)
     (: pr ps1
        _ (puts ps1c)
        pl (tally pr)
        (loop pra u l r d hu hd cur)
          (: _ (edrender pl pra u l r d)
             npra (tally u)
             (kloop uu lz rr dd) (loop npra uu lz rr dd hu hd cur)
             (kedit uu lz rr dd) (loop npra uu lz rr dd (detach hu cur) hd ())
             (khist uu lz rr dd nhu nhd ncur) (loop npra uu lz rr dd nhu nhd ncur)
             ; the dispatch stays a chain, not a table: every arm runs a different
             ; continuation over the live buffer, so a table would hold closures
             ; built per keystroke. the tables above work because their arms are constants.
             (edev 0 @
              -7 eofsym
              ; enter cashes the buffer as long as it parses complete
              10 (parseall (flatten u l r d) @
                  ^m (loop npra (rev l . u) () r d (detach hu cur) hd ())
                  vs (two? d ? (csi (tally d) 66) (),
                      putc 10,
                      [vs (!vs ? (revcat hd (detach hu cur))
                           (take 100 (mkframe u l r d . revcat hd (detach hu cur)))) ]))
              (c && 0 < c) (loop npra u (c . l) r d (detach hu cur) hd ())
              -1 (edleft  kloop u l r d)
              -2 (edright kloop u l r d)
              -3 (edbsp   kedit u l r d)
              -4 (eddel   kedit u l r d)
              -5 (edhome  kloop u l r d)
              -6 (edend   kloop u l r d)
              -8 (two? u ? (edup    kloop u l r d)
                           (uphist   khist u l r d hu hd cur))
              -9 (two? d ? (eddown  kloop u l r d)
                           (downhist khist u l r d hu hd cur))
              -10 (edtop kloop u l r d)
              -11 (edbot kloop u l r d)
              -12 (puts "^C\n", emptybuf u l r d ? eofsym (edline hu hd))
              (loop npra u l r d hu hd cur)))
        (loop 0 () () () () hu hd ()))

   ; evaluate a single parsed datum cooperatively.
   (do_eval v)
     (: pid (twirl ev v)
        (poll _)
          (? (landed? pid) (putx (catch pid), -1)   ; the answer
             (cue? 0) 
             (getc 0 @ 3 (puts "^C", freeze pid, -1) (poll ()))
             (rest 0, poll ()))
        (poll ()))

   ; the read-eval-print loop proper. the host and kernel frontends start the
   ; shell via (shell 0), which calls (repl 0 0).
   (repl hu hd)
    (edline hu hd @ ^eofsym 0
                    (vs . nhu . nhd) (each vs (\ v (do_eval v, putc 10)), repl nhu nhd))

   ; no-op () returning scare handler
   (welp a b) ()

   ; the face a raise wears -- ;; a b
   (hface a b) (say err ";; ", print err a, say err " ", print err b, put err 10)
   (shell-help a b) (hface a b, welp a b)
   ; the welp after the quit is not dead -- a frontend with no quit nif folds it, and welp answers
   (file-help a b) (hface a b, quit 1, welp a b)

   _ (!(heard ()) ? (hear file-help))
   (shell _)
    (hear shell-help,             ; the prompt survives every raise; a script must not
     raw 1,
     puts $ ";3 love " love-version "\n",
     repl 0 0)

   (besc1 ip c)
    (c @ 126 -5                               ; a line reader never jumps the buffer:
         59  (see ip, peep arrow (see ip) 0)) ;   the plain finals
   (besc ip) (see ip != 91 ? 0
    (: c (see ip) e (peep arrow c 0)
     (? !(= e 0) e
      (c @ 49        (besc1 ip (see ip))
           55        (see ip, -5)
           (52 || 56) (see ip, -6)
           51        (see ip, -4)
           0))))
   ; the `see` comes first and exactly once -- evk is indexed by the byte, so peeping before
   ; reading has nothing to peep with
   (bev ip) (: c (see ip) e (peep evk c 0)
               (? !(= e 0) e
                  (c @ 27 (besc ip)
                       9  -13          ; Tab -> the completion event (edlnc's; others ignore)
                       (32 <= c < 127 ? c))))

   ; (edraw ip pr) -- read one line off port `ip`, with in-line editing
   (edraw ip pr)
     (: pl (tally (puts pr))
        (loop l r)
          (: _ (edrender pl 0 () l r ())
             (km uu ll rr dd) (loop ll rr)         ; motion: edleft/.. give (k u l r d), keep l r
           (bev ip @
            -7 eofsym
            10 (putc 10, revcat l r)
            (c && 0 < c) (loop (c . l) r)            ; insert a printable
            -1 (edleft  km () l r ())
            -2 (edright km () l r ())
            -3 (edbsp   km () l r ())
            -4 (eddel   km () l r ())
            -5 (edhome  km () l r ())
            -6 (edend   km () l r ())
            (loop l r)))
        (loop () ()))

   ; the shell line reader: edraw + command history
   (edlnc ip pr hist comp)
     (: pl (tally (puts pr)) hn (tally hist)
        (hnth k) <(drop k hist)                       ; hist[k], 0-based (k < hn)
        (loop l r i draft)
          (: _ (edrender pl 0 () l r ())
             (km uu ll rr dd) (loop ll rr i draft)     ; motion: index + draft kept
             (recall ni)                               ; jump to view index ni (0 = the draft)
               (: nd (i = 0 ? (revcat l r) draft)    ; save the live draft once, the instant up leaves it
                  ln (ni = 0 ? nd (hnth (ni - 1)))
                  (loop (rev ln) () ni nd))

             (bev ip @ -7 'eof
                10 (: ln (putc 10, revcat l r)
                      nh (!ln ? hist (take 100 (ln . hist)))
                    (ln . nh))
                (c && 0 < c) (loop (c . l) r i draft)
                -12 (puts "^C\n", () . hist)   ; ^C: abandon the line, hist untouched
                -13
                  (? !comp (loop l r i draft)
                     (: t (comp (revcat l ()))
                        (? !(two? t) (loop l r i draft)
                           (: l2 (foldl (a \ ch \ ch . a) l <t)
                              cs >t
                            (two? cs && two? >cs ?
                              (puts $ "\n" + foldl (a \ s \ 0 = #a ? s (a + "  " + s)) "" cs + "\n"),
                             loop l2 r i draft)))))
                -1 (edleft  km () l r ())
                -2 (edright km () l r ())
                -3 (edbsp   km () l r ())
                -4 (eddel   km () l r ())
                -5 (edhome  km () l r ())
                -6 (edend   km () l r ())
                -8 (recall (i >= hn ? i (i + 1)))   ; up: older
                -9 (recall (0 >= i  ? i (i - 1)))    ; down: newer
                (loop l r i draft)))
        (loop () () 0 ()))
   (edln ip pr hist) (edlnc ip pr hist ())
)


; the command line. the defglobs go through `ev` of a built (: nm 'v), and the inner quote
; is load-bearing -- without it ev takes the value apart as a form to run. argv reaches the
; program's view before (run ()) fires, which a loaded program reads.
;
; the exit door: every leave -- a bad -m, a missing operand, an unopenable file, a
; torn -e, a verb's own status -- scares 'cli-leave, and the trap handler is the only
; `quit`. that lets a caller in the same image put its own trap on and get a charm where a
; spawn hands it a dead process. the handler is written twice because a leave lands in
; either of two spans, `pre` and `run`, and the defglob has to sit between them.
(: (cli-rail ln)
 (: (charm0 x) (charm? x ? x 0)
    cli2
 (trap (\ x
 (: (cli-leave c) (scare 'cli-leave c)
    ; a kind test, not a match on (): a refusal answers a nom, and a nom is truthy
    (load1 p) (: q (open p "r")
                 (? (hot? q) (reads q) (say err $ "love: cannot open " + p, cli-leave 1)))
    (eval1 s) (: m (nom 0)                           ; a fresh nom: the unfinished shape, id?-safe
       (rdl x acc) (sound x @ 'torn      m           ; every top-level datum off the string, in order
                               (a . b)  (rdl b (a . acc))
                               (rev acc))
       (rdl s () @ ^m (say err "love: -e: unfinished form", cli-leave 2)
                   (d @ (a . u)) (ev $ atom? u ? a d))) ; many datums fold to one application
    (say1 s) (puts s, putc 10)             ; -v and -h each print and keep walking argv
    (version _) ("love " + love-version)   ; _ arg: love has no nullary calls
    (usage _)
    ("usage: love [wake IMAGE] [-l FILE] [-e EXPR] [-q] [-m SIZE] [-v] [-h] [--] [VERB|FILE] [ARG ...]\n" +
     "  -l, --load FILE   preload FILE (read-eval) before the program\n" +
     "  -e, --eval EXPR   eval EXPR as one expression (infix works), print the answer\n" +
     "  -q, --quiet       with -e: do not print the answer\n" +
     "  -m  --memory N    max heap in {k,m,g} default = 0m = unlimited\n" +
     "  -v, --version     print the version\n" +
     "  -h, --help        print this help\n" +
     "  --                end of options; the rest are files, and none of them is stdin\n" +
     "with no arguments at all love reads stdin; with arguments and no program it stops\n" +
     "when the command line runs out, so -v and -h compose and neither is terminal.\n" +
     "`love verbs` names the verbs this binary carries.\n")
    (need h '()) (say err $ "love: " + h + " needs an argument", cli-leave 2)
    K 1024 M 1048576 G 1073741824
    wordsz (charm? G ? 8 4)             ; 2^30 is a charm only where a fixnum is 62-bit
    ; validate here: a bad value reaching `tune` writes a non-Z tray, which the nif refuses
    ; whole and in silence, so the flag would read as accepted and do nothing. 0 is the
    ; unbounded spelling, which is why this floors at 0 rather than 1.
    (size h s) (: n #s
                  u (peep s (n - 1) 0 @ (107 || 75) K
                                        (109 || 77) M
                                        (103 || 71) G)
                  d (u && snip s 0 (n - 1) || s)
                  v <(sound d)                   ; bound, not inlined: a bare infix `//` in the
                                                 ; `:` body slot folds into the binding chain
                  (charm? v && v >= 0 ?
                   (v * (u || M) // wordsz)
                   (say err $ "love: " + h + ": not a size: " + s,
                    cli-leave 2)))
    ; -> (kind . rest): 'eval code.args / 'verb fn.args / 'file prog.args / 'stdin / 'none.
    ; 'none is the command line running out with no program named: -v and -h are not
    ; terminal, so `love -v -h` prints both, reaches the end, and leaves 0.
    (pre a) (a @ (h . t)
      (h @ ("-l" || "--load")    (need h t, load1 <t, pre >t)
           ("-v" || "--version") (say1 (version 0), pre t)
           ("-h" || "--help")    (say1 (usage 0), pre t)
           ("-e" || "--eval")    (need h t, 'eval . t)
           ("-q" || "--quiet")   (pre t @ ('eval . r) ('evalq . r) r r)
           ; slot 0 of a fresh `tune` read, so the other knobs ride and the last -m wins. it
           ; lands at the next collection: the opening pool was sized before argv was read.
           ("-m" || "--memory")  (need h t, tune (pin (tune ()) 0 (size h <t)), pre >t)
           "--"                 (t @ (_ . _) ('file . t) '(stdin))
           (from 'verbs 'word h @ '() ('file . a) f ('verb . f . a)))
      '(none))
    ; stdin is the answer to an empty command line, or to `--` with nothing after it --
    ; never to a line that carried flags and named no program.
    p (two? >ln ? (pre >ln) '(stdin))   ; runs -l preloads + -v/-h + -m; the program kind
    k <p
    av (k @ ('eval || 'evalq || 'verb) >>p >p)   ; the program's view of argv
    run (\ _
      (k @ 'eval  (puts * show $ eval1 <>p, putc 10)  ; -e answers out loud through `show`, the
           'evalq (eval1 <>p)         ; repl's face, not dot's raw one; -q mutes
           'verb  (: r (<>p >>>p)     ; a verb takes the args after its name and answers a status,
                     (cli-leave $ charm0 r))  ; out the one door
           'file  (load1 <>p)
           'none  ()                  ; the flags did their printing; leaving is the answer
           (reads in)))
    [av run]))
       () (\ a b (a == 'cli-leave ? (quit $ charm0 b) (scare a b))))
 (ev [': 'argv ['\ <cli2]], ; the program's view, before the run
  trap (\ x (<>cli2 ()))    ; (run ()): dispatch, argv now the program's view
   () (\ a b (a == 'cli-leave ? (quit $ charm0 b) (scare a b)))))

 (cli-line ln tty)
   (: (charm0 x) (charm? x ? x 0)
      V  (from 'verbs)
      _  (ev [': 'cmdline ['\ ln] 'argv ['\ ln] ])   ; C's line is already past the primes
      f  (V 'seat <ln)
      (? f          (quit * charm0 $ f >ln)
         (two? >ln) (cli-rail ln)
         tty        (shell 0)
         (reads in))))                     ; non-tty stdin: the stream face drinks the in port
) ; module cli
