; --- test/host/broker.l: the wild hive's broker stub (src/apps/broker.l) ----------------------
; a root, three voting nodes and an intruder; a policy that hands `node` decisions to a quorum
; of two; a fake renter, so nothing touches a host. every way a request is refused, the quorum
; kept inside the envelope, and the log. run standalone from the repo root:
;   cat test/00-init.l test/host/broker.l | out/love

(borrow "src/apps/broker.l")
(borrow 'seals)
(borrow 'posix)

(: br-t-hex (cite 'tls 'hex)
   br-t-root (seal-key 0) br-t-n1 (seal-key 0) br-t-n2 (seal-key 0) br-t-n3 (seal-key 0) br-t-evil (seal-key 0)
   br-t-dir ("/tmp/love-broker-" + show (getpid 0))
   br-t-cred "PROVIDER-SECRET-7f3a"
   (br-t-put p s) (: q (open p "w") _ (say q s) (close q))
   (br-t-read p) (uread p @ [1 s] (s + "") "")
   (br-t-policy serial budget mx auth)
    (broker-sign br-t-root
     [("serial " + show serial) ("budget " + show budget) ("max " + show mx)
      "allow x64-small lab 100" "allow x64-big lab 400"
      ("voter n1 " + br-t-hex (br-t-n1 1)) ("voter n2 " + br-t-hex (br-t-n2 1))
      ("voter n3 " + br-t-hex (br-t-n3 1))
      ("decide node " + auth) "wait 60"])
   (br-t-req cls hours by) ("class " + cls + "\nregion lab\nhours " + show hours + "\nby " + by + "\nwhy a test\n")
   (br-t-vote k nm id yn) (broker-sign k [("vote " + id + " " + yn) ("voter " + nm)])
   (br-t-ans k id yn) (broker-sign k [("answer " + id + " " + yn)])
   ; the fake renter: a box name and a slot per rent, every call counted
   br-t-calls {'rent 0 'free 0}
   (br-t-rent a) (: n (1 + br-t-calls 'rent) _ (pin br-t-calls 'rent n) [("box" + show n) ("slot-" + show n)])
   (br-t-free l) (pin br-t-calls 'free (1 + br-t-calls 'free))
   _ (mkdir br-t-dir 448)
   _ (br-t-put (br-t-dir + "/root.pub") (br-t-hex (br-t-root 1) + "\n"))
   _ (br-t-put (br-t-dir + "/creds") (br-t-cred + "\n"))
   _ (br-t-put (br-t-dir + "/policy") (br-t-policy 1 1000 2 "quorum 2"))
   b (broker-open br-t-dir)
   (refused? r) (string? r))

; --- the state: outside any hive tree, and read back as it was left ---------------------------
(test (tablet? b) (b 'spent = 0)
      (string? (broker-open "out")))                     ; out/ sits in this tree: refused

; --- refused at the ask -----------------------------------------------------------------------
(test (refused? (broker-request b (br-t-req "gpu-huge" 1 "n1") 100))     ; off the allowlist
      (refused? (broker-request b (br-t-req "x64-small" 1 "stranger") 100)) ; no such node
      (refused? (broker-request b (br-t-req "budget" 1 "n1") 100))       ; the envelope is not a request
      (refused? (broker-request b (br-t-req "x64-small" 11 "n1") 100))   ; 1100 > 1000: over budget
      (refused? (broker-request b (br-t-req "x64-small" 0 "n1") 100)))   ; no hours

; --- unanswered, wrongly answered, a voter counted once, too late -----------------------------
(: d1 (broker-request b (br-t-req "x64-small" 3 "n1") 100) id (d1 'id)
   _ (test (tablet? d1) (d1 'class = "node") (d1 'deadline = 160))
   _ (test (refused? (broker-answer b id () 110 br-t-rent)))             ; no answer: unanswered
   d2 (broker-request b (br-t-req "x64-small" 3 "n1") 100)
   ; n1's name on the intruder's key: wrongly answered
   _ (test (refused? (broker-answer b (d2 'id) [(br-t-vote br-t-n2 "n2" (d2 'id) "yes") (br-t-vote br-t-evil "n1" (d2 'id) "yes")] 110 br-t-rent)))
   d3 (broker-request b (br-t-req "x64-small" 3 "n1") 100)
   ; n1 twice is one vote: one of two
   _ (test (refused? (broker-answer b (d3 'id) [(br-t-vote br-t-n1 "n1" (d3 'id) "yes") (br-t-vote br-t-n1 "n1" (d3 'id) "yes")] 110 br-t-rent)))
   d4 (broker-request b (br-t-req "x64-small" 3 "n1") 100)
   ; a vote on another decision does not count for this one
   _ (test (refused? (broker-answer b (d4 'id) [(br-t-vote br-t-n1 "n1" id "yes") (br-t-vote br-t-n2 "n2" (d4 'id) "yes")] 110 br-t-rent)))
   d5 (broker-request b (br-t-req "x64-small" 3 "n1") 100)
   _ (test (refused? (broker-answer b (d5 'id) [(br-t-vote br-t-n1 "n1" (d5 'id) "yes") (br-t-vote br-t-n2 "n2" (d5 'id) "yes")] 161 br-t-rent)))
   ; under a quorum policy, root alone is not its authority
   d6 (broker-request b (br-t-req "x64-small" 3 "n1") 100)
   _ (test (refused? (broker-answer b (d6 'id) [(br-t-ans br-t-root (d6 'id) "yes")] 110 br-t-rent))
           (br-t-calls 'rent = 0) (b 'spent = 0))
   0)

; --- a quorum's yes rents, and spends inside the purse ----------------------------------------
(: d (broker-request b (br-t-req "x64-small" 3 "n2") 200)
   l (broker-answer b (d 'id) [(br-t-vote br-t-n1 "n1" (d 'id) "yes") (br-t-vote br-t-n3 "n3" (d 'id) "yes")] 210 br-t-rent)
   _ (test (tablet? l) (l 'cost = 300) (b 'spent = 300) (br-t-calls 'rent = 1)
           (l 'until = 210 + 3 * 3600) (l 'host = show "box1"))
   ; a quorum's no is a no
   e (broker-request b (br-t-req "x64-small" 1 "n2") 200)
   _ (test (refused? (broker-answer b (e 'id) [(br-t-vote br-t-n1 "n1" (e 'id) "no") (br-t-vote br-t-n3 "n3" (e 'id) "no")] 210 br-t-rent)))
   ; 300 spent + 800 > 1000: a yes cannot spend past the purse
   f (broker-request b (br-t-req "x64-big" 2 "n2") 200)
   _ (test (refused? f))
   0)

; --- the envelope: no quorum, and no node, moves it -------------------------------------------
(: raise (broker-sign br-t-n1 ["serial 9" "budget 999999" "max 9" "allow x64-small lab 100"
                               ("voter n1 " + br-t-hex (br-t-n1 1)) "decide node quorum 1"])
   _ (test (refused? (broker-policy b raise)) ((b 'policy) 'budget = 1000))   ; a node's policy is no policy
   ; even root may not hand the envelope to a quorum
   _ (test (refused? (broker-policy b (broker-sign br-t-root ["serial 5" "budget 1000" "max 2"
                                                               ("voter n1 " + br-t-hex (br-t-n1 1))
                                                               "decide budget quorum 1"]))))
   _ (test (refused? (broker-teardown b (broker-sign br-t-n1 ["teardown 7"]) br-t-free))
           (br-t-calls 'free = 0))
   ; root raises the purse, and an older serial cannot come back
   _ (test (1 = broker-policy b (br-t-policy 2 2000 3 "either 2")) ((b 'policy) 'budget = 2000)
           (refused? (broker-policy b (br-t-policy 1 50000 9 "quorum 1"))) ((b 'policy) 'budget = 2000))
   ; under `either`, root's yes is enough
   g (broker-request b (br-t-req "x64-small" 2 "n3") 300)
   l2 (broker-answer b (g 'id) [(br-t-ans br-t-root (g 'id) "yes")] 310 br-t-rent)
   _ (test (tablet? l2) (b 'spent = 500) (#(b 'leases) = 2))
   ; a root teardown frees its lease; the clock frees the rest
   _ (test (1 = broker-teardown b (broker-sign br-t-root [("teardown " + l2 'lease)]) br-t-free)
           (#(b 'leases) = 1) (br-t-calls 'free = 1))
   _ (test (1 = broker-tick b (310 + 4 * 3600) br-t-free) (#(b 'leases) = 0) (br-t-calls 'free = 2))
   0)

; --- the log holds every request and answer; the creds reach none of it -----------------------
(: log (br-t-read (br-t-dir + "/log"))
   ls (lines log)
   reqs (filter (l \ starts? l "request ") ls)
   b2 (broker-open br-t-dir)
   _ (test (#reqs = 15)                                    ; every broker-request above, refused or not
           (any (l \ starts? l "answer ") ls) (any (l \ starts? l "rented ") ls) (any (l \ starts? l "freed ") ls)
           (any (l \ starts? l "refused policy") ls)
           (fsub log br-t-cred 0 < 0)
           (fsub (br-t-read (br-t-dir + "/leases")) br-t-cred 0 < 0)
           (fsub (br-t-read (br-t-dir + "/ledger")) br-t-cred 0 < 0))
   ; reopened, it is the broker it was: the spend, the leases, the policy
   _ (test (tablet? b2) (b2 'spent = 500) (#(b2 'leases) = 0) ((b2 'policy) 'serial = 2) (b2 'nreq = 15))
   _ (each ["root.pub" "creds" "policy" "ledger" "leases" "log"] (f \ unlink (br-t-dir + "/" + f)))
   _ (rmdir br-t-dir)
   (puts "broker: ok -- the purse, the allowlist, the cap, the decision, the envelope, the log\n"))
