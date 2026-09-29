; test/host/locks-stub.l -- apps/locks.l's API, played: `busy` stays queued for its first two
; asks, anything else is granted at once, and every acquire is logged to LOCKS_STUB_LOG so the
; test can see what bee passed. preloaded ahead of apps/bee.l by the bee test
(module (locks locks-root locks-acquire locks-release locks-list locks-run)
(: lk-st {'asks 0}
   (locks-root _) "stub-root"
   (locks-acquire root nm kind who note floor max)
    (: n (lk-st 'asks + 1) _ (pin lk-st 'asks n)
       lg (getenv "LOCKS_STUB_LOG")
       _ (? (string? lg) (: f (open lg "a") (? (hot? f) (: _ (say f (nm + " " + show kind + " " + show who + " "
                                                                      + show floor + " " + show max + "\n")) (close f)) 0)) 0)
       (? (nm = "busy" && n < 3)
          {"granted" 0 "lock" nm "position" 2 "held" 1 "mem_gb" 12
           "holders" [{"pid" 4242 "note" "make test_slow" "since" 0}]}
          {"granted" 1 "lock" nm}))
   (locks-release root nm kind who) (? (nm = "nothing") () 1)
   (locks-list root)
    {"exclusive" [["out--x" {"pid" 4242 "note" "make" "since" 0}]]
     "heavy" [{"pid" 4242 "note" "test_slow" "since" 0}] "waiting" () "mem_gb" 12 "load" "3.10"}
   (locks-run root reqs note floor max argv) (: r (hark argv) (? (two? r) <r 1)))
) ; module locks
