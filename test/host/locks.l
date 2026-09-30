; test/host/locks.l -- the machine's locks (src/apps/locks.l)
; a root of its own under out/, so a run never meets the box's real locks. pid 1 stands in
; for a second live holder (always alive, its stat readable); a child spawned and reaped
; stands in for a dead one. run standalone from the repo root:
;   cat test/00-init.l test/host/locks.l | out/love

(borrow 'locks)

(: lk-root ("out/.locks-" + show (getpid 0))
   lk-me (getpid 0)
   lk-dead (spawn ["true"] @ p (wait p, p)))

; --- exclusive: one holder, itself again, the next queued behind it ---------------------
(test (peep (locks-acquire lk-root "out-a" 'exclusive lk-me "gate" () 2) "granted" 0)
      (peep (locks-acquire lk-root "out-a" 'exclusive lk-me "gate" () 2) "granted" 0)
      (locks-acquire lk-root "out-a" 'exclusive 1 "other" () 2 @ a
         (&& (0 = peep a "granted" 1) (lk-me = peep (peep a "holder" {}) "pid" 0))))
; only the holder lets go, and then the next one takes it
(test (() = locks-release lk-root "out-a" 'exclusive 1)
      (1 = locks-release lk-root "out-a" 'exclusive lk-me)
      (peep (locks-acquire lk-root "out-a" 'exclusive 1 "other" () 2) "granted" 0)
      (1 = locks-release lk-root "out-a" 'exclusive 1))
; a holder that died is reclaimed by the next to ask
(test (peep (locks-acquire lk-root "out-b" 'exclusive lk-dead "gone" () 2) "granted" 0)
      (peep (locks-acquire lk-root "out-b" 'exclusive lk-me "gate" () 2) "granted" 0)
      (1 = locks-release lk-root "out-b" 'exclusive lk-me))
; a name any string can be: its slug is the file
(test (peep (locks-acquire lk-root "/home/x/.claude/out" 'exclusive lk-me "gate" () 2) "granted" 0)
      (1 = #(peep (locks-list lk-root) "exclusive" ()))
      (1 = locks-release lk-root "/home/x/.claude/out" 'exclusive lk-me))

; --- heavy: first asked, first granted, at most max at once --------------------------
(test (peep (locks-acquire lk-root "slow" 'heavy lk-me "test_slow" () 1) "granted" 0)
      (locks-acquire lk-root "inle" 'heavy 1 "test_inle" () 1 @ a
         (&& (0 = peep a "granted" 1) (1 = peep a "position" 0) (1 = peep a "held" 0)))
      (1 = #(peep (locks-list lk-root) "heavy" ()))
      (1 = #(peep (locks-list lk-root) "waiting" ())))
; asking again polls the same ticket: it keeps its place and makes no second one
(test (locks-acquire lk-root "inle" 'heavy 1 "test_inle" () 1 @ a (1 = peep a "position" 0))
      (1 = #(peep (locks-list lk-root) "waiting" ())))
; the slot goes, and the ticket that waited takes it
(test (1 = locks-release lk-root "slow" 'heavy lk-me)
      (peep (locks-acquire lk-root "inle" 'heavy 1 "test_inle" () 1) "granted" 0)
      (1 = locks-release lk-root "inle" 'heavy 1))
; a floor above any machine's memory holds even the first ticket back
(test (locks-acquire lk-root "big" 'heavy lk-me "x" 1000000 2 @ a
         (&& (0 = peep a "granted" 1) (1 = peep a "position" 0)))
      (1 = locks-release lk-root "big" 'heavy lk-me))
; a dead ticket is swept, not waited behind
(test (locks-acquire lk-root "d" 'heavy lk-dead "gone" () 1,
       peep (locks-acquire lk-root "e" 'heavy lk-me "gate" () 1) "granted" 0)
      (1 = locks-release lk-root "e" 'heavy lk-me))

; --- the wrapper: the child's status, and the locks gone after it ---------------------
(test (0 = locks-run lk-root [["out-c" 'exclusive] ["run" 'heavy]] "w" () 2 ["true"])
      (3 = locks-run lk-root [["out-c" 'exclusive]] "w" () 2 ["sh" "-c" "exit 3"])
      (0 = #(peep (locks-list lk-root) "exclusive" ()))
      (0 = #(peep (locks-list lk-root) "heavy" ())))

(test (string? (locks-root 0)))

(hark ["rm" "-rf" lk-root])
(test_fin ())
(puts "locks: ok")
(putc 10)
