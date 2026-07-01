; serve.l -- the DOCK: a localhost eval-over-socket server for steering ai.
;
; The dock is where a coding agent MOORS to ai. It is bao's read/eval/write
; filter (the shell law) behind `listen`/`accept`: forms in over a TCP socket,
; `show`'d values back, a welp-face so the session survives every raise. There
; is NO protocol to version and no SDK -- the API is the book: every global is a
; verb, `(names ())` discovers them, and the model that steers lives OUTSIDE the
; dock entirely. A human at `ain`, an oracle curling a model (oracle.l), or any
; agent that can write text to a socket drives it the same way. That is what
; "model-agnostic" means here: the dock never learns what a model is.
;
; Launch from a STABLE COPY `out/host/dock` (so `adopt` can rebuild the canonical
; out/host/ai without ETXTBSY -- see adopt), judge.l FIRST (the dock leaves the
; probe ladder to judge, and a closure would fossilize a not-yet-loaded `judge`
; to the zero point):
;   make host && cp out/host/ai out/host/dock
;   out/host/dock -l port/inle/judge.l -l port/inle/serve.l -l port/inle/drive.l -l port/inle/patch.l -e "(dock 7620)"
; (a plain `out/host/ai ... -e "(dock N)"` works too, but then `adopt` can't
; rebuild -- it would be rebuilding its own running exe. drive.l + patch.l are
; optional -- the self-modify loop; the dock serves fine without them.)
; Then drive it (another shell):
;   out/host/ai tools/ain.l 127.0.0.1 7620
;   > (brief ())            ; the served steering prompt -- read this first
;   > (verbs ())            ; the dock's own verbs
;   > (probe "(puts (show (+ 1 2)))")   ; run a candidate against the binary
;
; TRUST: an eval server that can rewrite its own source is root on the box for
; anyone who reaches the socket. Bind loopback (INADDR_ANY here, so firewall it
; or tunnel over ssh); never expose it raw. Candidate/untrusted code goes
; through `probe`/`judge` (a subprocess under `timeout`), never the live session.
;
; CONCURRENT: the accept loop `await`s the listener fd (cooperative park) and
; spins each client's session as its own task, so many agents moor at once.
; Sessions interleave through the scheduler -- parked in `sound`/`get` on their
; own fds, and a long pure-ai computation yields periodically too. The ONE thing
; that freezes the dock is a blocking C nif: `run` (fork/wait), so the heavy
; verbs `probe`/`gate`/`build`/`adopt` hold the whole dock while they run. That
; is acceptable -- they are deliberate, occasional, and want the machine anyway.

(: (note s) (: _ (puts s) _ (puts "\n") ())

   ; --- source in hand: read and write tree files (so the brief self-edits) ---
   (look path)      (: q (open path "r") (? q (: s (slurp q) _ (close q) s) ()))
   (lay path body)  (: q (open path "w") (? q (: _ (say q body) _ (close q) 1) 0))

   ; run an argv, returning a PROPER 2-list (status output) -- not run's raw
   ; (status . output) dotted pair, whose string tail `show` drops (an improper
   ; list is ill-formed under the ()-terminated ontology). status: 0 clean, 124
   ; a timeout kill, >=128 a signal kill. destructure: (cap r) status, (caup r) output.
   (runl argv) (: r (run argv) `((cap r) (cup r)))

   ; --- the world: shell out (git, ls, grep, ...) -> (status output) ---
   (sh argv) (runl argv)

   ; --- probe: run ONE candidate program against the current binary, isolated.
   ; a subprocess under `timeout` (secs), so a hang or crash can't touch the
   ; dock. -> (status output): 0 clean, 124 hung, >=128 signal-killed. This is
   ; the "binary probe" the whole dock is named for; `judge` (judge.l) climbs
   ; the full ladder (parse, host-vs-ai0 divergence, reward/bug lenses). --
   (probe prog)      (probe-for "out/host/ai" prog 5)
   (probe-for bin prog secs) (runl (L "timeout" (show secs) bin "-e" prog))

   ; --- rebuild-capable: build a fresh binary, then GATE it. The gate is
   ; `make test` -- host + ai0 exactly twice; the exit status is the honest
   ; signal (0 = the zz-fin summary printed on both passes). -> (status . out).
   ; These OVERWRITE the running binary's target in place (Linux keeps the live
   ; inode, so the dock survives); the two-generation side-build + `adopt`
   ; re-exec is the next rung (needs a side-path make target + an exec nif). --
   (build _) (runl (L "make" "host"))               ; the binary only (bare `make` is all: host+kernel+wasm)
   (gate _)  (runl (L "make" "test"))               ; the gate: host + ai0 twice
   (rebuild _) (: b (build ()) (? (= (cap b) 0) (gate ()) b))   ; build, then gate iff it built

   ; --- adopt: the two-generation re-exec, the copying-GC / egg move at process
   ; scale. the dock runs from a STABLE COPY `out/host/dock` so the canonical
   ; `out/host/ai` is free to rebuild (rebuilding your own running exe fails:
   ; the .img bake objcopies it in place -> ETXTBSY -- the whole reason a
   ; side-path is required, not optional). adopt: rebuild + gate `out/host/ai`;
   ; only on a GREEN gate install it as the fresh `out/host/dock` (a rename ->
   ; a NEW inode, so the running dock keeps its old inode and survives the swap)
   ; and re-exec onto it. the old generation stays LIVE and serving until the
   ; new one is proven; a RED gate leaves the running dock untouched. exec drops
   ; open sessions; the dock re-moors on the same port (SO_REUSEADDR), so a
   ; client just reconnects. -> on red, (status output) of the failure; on green
   ; it does not return (the image is replaced). --
   dock-bin "out/host/dock"                         ; the stable copy the dock runs from
   relaunch-slot (tablet 0)                          ; dock stashes its re-exec argv here
   (adopt _)
     (: r (rebuild ())                               ; build + gate the canonical out/host/ai
        (? (= (cap r) 0)
           (: _ (note "dock: gate GREEN -- installing the fresh binary + adopting")
              _ (sh (L "cp" "out/host/ai" (+ dock-bin ".new")))
              _ (sh (L "mv" "-f" (+ dock-bin ".new") dock-bin))  ; atomic swap, new inode
              (exec (peep relaunch-slot 0 (L dock-bin))))        ; returns only on exec failure
           (: _ (note "dock: gate RED -- staying on the current image") r)))

   ; --- the served steering prompt: a tree file, so the system can rewrite its
   ; own brief under the same gate. `(brief ())` is the first verb a stranger
   ; calls; edit brief.md and re-serve to retune. --
   brief-path "port/inle/brief.md"
   (brief _) (look brief-path)

   ; --- the dock's own verbs (judge/* come from judge.l; every other global is
   ; callable too -- (names ()) is the full surface). --
   (verbs _)
     (+ "dock verbs -- (brief ()) first, then:\n"
     (+ "  (brief ())            the steering prompt (read this)\n"
     (+ "  (verbs ())            this list\n"
     (+ "  (look \"path\")         read a tree file -> its bytes\n"
     (+ "  (lay \"path\" body)     write a tree file (careful) -> 1|0\n"
     (+ "  (sh (L \"git\" ...))    shell out -> (status . output)\n"
     (+ "  (probe \"PROG\")        run PROG against the binary, isolated -> (status . stdout)\n"
     (+ "  (judge \"PROG\")        the full ladder: parse/run/host-vs-ai0/reward/bug (judge.l)\n"
     (+ "  (build ())            make (build+test in place) -> (status . out)\n"
     (+ "  (gate ())             make test (the gate, twice) -> (status . out)\n"
     (+ "  (rebuild ())          build, then gate iff it built\n"
         "  any global is a verb; (names ()) is the whole surface.\n")))))))))))

   ; --- the session: read one form off the socket, eval it in the book (so
   ; every global is a verb), `show` the value back, flush. Loop to disconnect.
   ; `sound` parks on `get` cooperatively, so it waits for a full form and ends
   ; only at EOF (client gone) or an unfinished shape at close. A scare during
   ; eval is caught by the installed dock-help (below): the client sees the
   ; condition as a value and the session lives on -- the shell law, over TCP. --
   (session c)
     (: e (nom 0)
        (go _) (: r (sound c e)
                   (? (id? r e) 0                          ; EOF -- client disconnected
                      (id? r c) 0                          ; unfinished shape at close
                      (: v (ev 'ev r)                      ; eval through the self-hosted ev
                         _ (say c (+ (show v) "\n"))
                         _ (flush c)
                         (go ()))))
        (go ()))

   ; the accept loop: CONCURRENT. `await` parks the loop on the listener fd
   ; (yielding to running sessions) until a client is pending, so the following
   ; `accept` returns without blocking; each client's session is SPUN as its own
   ; task and the loop immediately re-parks. Sessions interleave through the
   ; cooperative scheduler -- each is parked in `sound`/`get` on its own fd
   ; (lvm_fgetc yields on a not-ready fd), exactly like ain's two pumps. The
   ; session tasks are deliberate ORPHANS (never caught) -- the dock runs
   ; forever, so an uncaught task is the point, not the corpus-runner stall.
   (accept-loop l)
     (: _ (await l)                                 ; park until a client is pending
        c (accept l)                                ; now ready -- does not block
        _ (? c (spin (\ _ (: _ (note "dock: client moored") _ (session c)
                             _ (close c) (note "dock: client cast off"))) ())
             0)
        (accept-loop l))

   ; a welp-face help so a scare returns a visible value to the client instead
   ; of dropping the dock. keeps the read protocol (more -> a, eof -> b); a bare
   ; scare answers (scare a b) so the client sees WHAT went wrong. this is
   ; shell-help's shape, aimed at a socket peer rather than a local tty. it is a
   ; leaked top-level global (the web term installs help the same way) -- `book`
   ; is mopped off the globals post-egg, so a live `(pin book 'help ..)` can't
   ; reach it; a plain top-level binding is how help gets installed after birth.
   (help s a b)
     (? (eof? s) b (more? s) a `('scare a b))

   ; the entry: stash the relaunch argv (so `adopt` can re-exec this exact
   ; dock), listen, run the accept loop. `port` is a fixnum. (help is installed
   ; by this file's load -- see above.)
   (dock port)
     (: _ (pin relaunch-slot 0 (L dock-bin "-l" "port/inle/judge.l" "-l" "port/inle/serve.l"
                                  "-l" "port/inle/drive.l" "-l" "port/inle/patch.l"
                                  "-e" (+ "(dock " (+ (show port) ")"))))
        l (listen port)
        (? l (: _ (note (+ "dock: moored on :" (show port)))
                _ (note "dock: (brief ()) is the steering prompt")
                _ (accept-loop l)
                _ (close l) 1)
           (: _ (note (+ "dock: cannot listen on :" (show port))) 0))))
