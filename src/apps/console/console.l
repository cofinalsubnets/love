; src/apps/console/console.l -- the console door: (door f) runs a tty app on this console,
; f applied to (), reading in and drawing on out as it likes, and answers when it is
; done with the app's charm or 0. one verb, two bodies, and a caller never knows which:
; a seat that can fork (a terminal) forks, so the app owns the tty and the caller's own
; state survives whatever it does there; a seat that cannot (inle, the page) runs it as a
; task on the same console and parks until it lands. fork, wait and quit are host words,
; read late, so this compiles on every seat; a fork refused takes the task lane too.
; a crew file, not the core's: nothing under src/core spells a host word.
;   (use 'console) in the artifact; the page evals this file before the apps.
(module (console door door-fork door-task)
(: (door-task f) (: t (twirl (\ _ (f ())) 0)
                    r (catch t)
                    (charm? r ? r 0))
   (door-fork f) (: p ((ev 'fork) 0)
                    (? (nom? p) (door-task f)
                       (p = 0) (: _ (wear ())                       ; the child wears the console
                                  quit (ev 'quit)                    ; the host's, like fork
                                  ; a scare is the child's end, never a second caller
                                  _ (hear (\ a b (: _ (say err ";; ") _ (print err a) _ (say err " ")
                                                     _ (print err b) _ (put err 10) (quit 1))))
                                  r (f ())
                                  (quit (charm? r ? r 0)))
                       (: s ((ev 'wait) p) (charm? s ? s 0))))
   (door f) (? (member? 'fork (names ())) (door-fork f) (door-task f)))
) ; module console
