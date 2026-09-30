; --- test/host/locks.l: the machine's locks (src/apps/locks.l) ---------------------------
; a root of its own under out/, so a run never meets the box's real locks. pid 1 stands in
; for a second live holder (always alive, its stat readable); a child spawned and reaped
; stands in for a dead one. run standalone from the repo root:
;   cat test/00-init.l test/host/locks.l | out/love

(borrow 'locks)

(: lk-root ("out/.locks-" + show (getpid 0))
   lk-me (getpid 0)
   lk-dead (: p (spawn ["true"]) _ (wait p) p))

; --- exclusive: one holder, itself again, the next queued behind it ---------------------
(test (peep (locks-acquire lk-root "out-a" 'exclusive lk-me "gate" () 2) "granted" 0)
      (peep (locks-acquire lk-root "out-a" 'exclusive lk-me "gate" () 2) "granted" 0)
      (: a (locks-acquire lk-root "out-a" 'exclusive 1 "other" () 2)
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
      (: a (locks-acquire lk-root "inle" 'heavy 1 "test_inle" () 1)
         (&& (0 = peep a "granted" 1) (1 = peep a "position" 0) (1 = peep a "held" 0)))
      (1 = #(peep (locks-list lk-root) "heavy" ()))
      (1 = #(peep (locks-list lk-root) "waiting" ())))
; asking again polls the same ticket: it keeps its place and makes no second one
(test (: a (locks-acquire lk-root "inle" 'heavy 1 "test_inle" () 1) (1 = peep a "position" 0))
      (1 = #(peep (locks-list lk-root) "waiting" ())))
; the slot goes, and the ticket that waited takes it
(test (1 = locks-release lk-root "slow" 'heavy lk-me)
      (peep (locks-acquire lk-root "inle" 'heavy 1 "test_inle" () 1) "granted" 0)
      (1 = locks-release lk-root "inle" 'heavy 1))
; a floor above any machine's memory holds even the first ticket back
(test (: a (locks-acquire lk-root "big" 'heavy lk-me "x" 1000000 2)
         (&& (0 = peep a "granted" 1) (1 = peep a "position" 0)))
      (1 = locks-release lk-root "big" 'heavy lk-me))
; a dead ticket is swept, not waited behind
(test (: _ (locks-acquire lk-root "d" 'heavy lk-dead "gone" () 1)
         (peep (locks-acquire lk-root "e" 'heavy lk-me "gate" () 1) "granted" 0))
      (1 = locks-release lk-root "e" 'heavy lk-me))

; --- the wrapper: the child's status, and the locks gone after it ---------------------
(test (0 = locks-run lk-root [["out-c" 'exclusive] ["run" 'heavy]] "w" () 2 ["true"])
      (3 = locks-run lk-root [["out-c" 'exclusive]] "w" () 2 ["sh" "-c" "exit 3"])
      (0 = #(peep (locks-list lk-root) "exclusive" ()))
      (0 = #(peep (locks-list lk-root) "heavy" ())))

(test (string? (locks-root 0)))

; --- races: n processes at a barrier, each a kid file of its own run under this love ---
; a kid waits for ROOT.go, runs body, writes its answer to ROOT.res/PID, waits for ROOT.done
(: lr-love (: l <cmdline (l 0 = 47 ? l (cwd 0 + "/" + l)))
   (lr-put p s) (: f (open p "w") _ (say f s) (close f))
   (lr-names d) (: ns (readdir d) (? (two? ns) (filter (n \ n 0 != 46) ns) ()))
   (lr-kids rt n body)
    (: _ (hark ["rm" "-rf" rt (rt + ".go") (rt + ".done") (rt + ".res")])
       _ (mkdir rt 448) _ (mkdir (rt + ".res") 448)
       _ (lr-put (rt + ".kid.l")
                 ("(borrow 'posix)\n(borrow 'locks)\n(: rt " + show rt + " me (getpid 0)\n"
                  + " (bar f) (? (two? (stat f)) 0 (: _ (rest 1) (bar f)))\n _ (bar (rt + \".go\"))\n"
                  + " r " + body + "\n f (open (rt + \".res/\" + show me) \"w\") _ (say f (show r)) _ (close f)\n"
                  + " (bar (rt + \".done\")))\n"))
       (map (\ _ (spawn [lr-love (rt + ".kid.l")])) ^n))
   ; go, then watch f every few ms until n answers or 20 s -> [f's most, the answers]
   (lr-go rt ps n f)
    (: _ (rest 800) _ (lr-put (rt + ".go") "")
       (look m k) (: m2 (max m (f 0)) got (lr-names (rt + ".res"))
                     (? (n <= #got || k <= 0) [m2 got] (: _ (rest 3) (look m2 (k - 1)))))
       r (look 0 6000)
       as (map (\ p (: f (open (rt + ".res/" + p) "r") s (slurp f) _ (close f) s)) (r 1))
       _ (lr-put (rt + ".done") "")
       _ (map wait ps)
       _ (hark ["rm" "-rf" rt (rt + ".go") (rt + ".done") (rt + ".res") (rt + ".kid.l")])
       [<r as]))

; a stale exclusive lock, sixteen reapers at once: one of them holds it
(: lr-x (lk-root + "-x")
   (round _)
    (: ps (lr-kids lr-x 16 "(peep (locks-acquire rt \"out-r\" 'exclusive me \"race\" () 1) \"granted\" 0)")
       _ (mkdir (lr-x + "/x") 448) _ (mkdir (lr-x + "/x/out-r") 448)
       _ (lr-put (lr-x + "/x/out-r/owner") ("pid " + show lk-dead + "\nstart 1\nsince 0\nnote dead\n"))
       r (lr-go lr-x ps 16 (\ _ 0))
       [#(r 1) #(filter (\ a (a = "1")) (r 1))])
   _ (test (all (\ r (r = [16 1])) (map round ^4)))
   0)

; twelve pollers on a pool of one, each holding a moment when granted: never two in h/ at once,
; and every one served in turn
(: lr-h (lk-root + "-h")
   ps (lr-kids lr-h 12 ("(: (poll k) (: a (locks-acquire rt \"heavy\" 'heavy me \"race\" () 1)\n"
                        + "  (? (peep a \"granted\" 0) (: _ (rest 100) _ (locks-release rt \"heavy\" 'heavy me) 1)\n"
                        + "     (k <= 0) 0 (: _ (rest 20) (poll (k - 1))))) (poll 1000))"))
   r (lr-go lr-h ps 12 (\ _ #(lr-names (lr-h + "/heavy/h"))))
   _ (test (1 = <r) (12 = #(r 1)) (all (\ a (a = "1")) (r 1)))
   0)

(hark ["rm" "-rf" lk-root])
(test_fin ())
(puts "locks: ok")
(putc 10)
