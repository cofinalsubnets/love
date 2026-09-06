; src/port/wasm/web.l -- the page's love side: the quay tty apps on the page's console,
; unchanged. repl.js feeds this through ai_eval after story.l and BEFORE rove.l and
; ink.l -- a closure captures its free globals at creation, so the tty words an app asks
; for must stand first, and story's words must stand before the demo below -- and
; src/port/wasm/screen.mjs runs it under node the same way.
;
; the seat is a console with no fds: stdin is a ring of key bytes the page pushes
; (host.c's ai_key), so `see in` parks the reading task until the next push and `cue?`
; asks the ring; stdout is the buffer the page drains after each eval. an app runs as a
; task, twirled here; an app that opens another (story's vi) just calls it, in the same
; task, and parks the way it would anywhere. the page pumps:
;   (web-boot nm cols rows)   the screen, and the app named nm on it as a task
;   (web-step)                the app's turn -- one time slice; the page steps until
;                             host.c's ai_runnable says the app parked, sleeps or landed
;   (web-show frame)          what the app drew, scribed onto the screen and mirrored out
;                             (host.c) for cells.js to lay
; the app's drawing is whatever the page drains from out after ANY eval -- a task runs
; at every fair yield, the session's own evals included -- so the page drains each one
; and asks host.c's ai_alive, never this file, whether the app lives.
; the tty words this seat has no device for: winsize is the screen's, raw is nothing
; to do. an app run on the session's own task (a typed `(rove-run ())`) reads the end of
; stdin at once (host.c) and steps ashore, since nothing could unpark it.
(use 'story)                                        ; the engine, fed just before this file
(: raw (\ _ ())
   web-scr {} web-task {}
   (winsize _) (: s (peep web-scr () 0) (? s ((gaze s 1) . (gaze s 2)) ()))
   (web-boot nm c r) (: _ (scoop 0)                                 ; the last app's node, reaped
                        s (screen (cask (screen () r c)) r c)
                        f (nm @ "rove" (from 'rove 'rove-run) (ev (nom nm)))   ; the runner, by its name
                        _ (pin web-scr () s)
                        _ (pin web-task () (twirl (\ _ (f ())) 0))
                        ())
   ; the demo story: its level is a datum the page fetched (src/apps/rove/levels) and
   ; bound as lighthouse-data; the engine's load-level reads a file, which this seat lacks
   (lighthouse _) (story-run (level-of lighthouse-data))
   (web-step _) (: _ (rest 0) ())                 ; a rest of nothing: the other tasks' turn
   (web-show f) (: s (peep web-scr () 0) _ (scribe s f) _ (mirror s) ()))
