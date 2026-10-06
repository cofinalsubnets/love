; src/apps/broker.l -- the wild hive's broker, the stub (notes/plan/wild-hive.md, rung 1): the one
; holder of the purse. a node asks for "one node of class X in region R for N hours"; the broker
; checks the allowlist, the concurrency cap and the budget, raises a decision, and rents only once
; the decision is answered by the authority the policy names for its class. every request and
; every answer goes to its log.
;
;   (broker-open dir)                   the broker's state -> a tablet | a reason
;   (broker-request b text now)         a request -> its decision {'id 'class 'ask 'by 'deadline} | a reason
;   (broker-answer b id answers now rent)  answers (signed texts) -> the lease | a reason
;   (broker-tick b now free)            expired leases given back -> how many
;   (broker-policy b text)              a new policy, root-signed and a higher serial -> 1 | a reason
;   (broker-teardown b text free)       a root-signed `teardown LEASE` -> 1 | a reason
;   (broker-sign k lines)               lines signed by a seals key -> the text
;   (broker-rent-local start)           rent and free through the host registry (src/apps/hosts.l)
;
; the state is a directory OUTSIDE any hive tree (BROKER_DIR, ~/.love/broker): root.pub (gwen's
; root key, hex), policy, ledger (cents spent), leases, log, and creds, which no answer, log line
; or lease ever carries. the policy is root-signed text, one `key value..` a line:
;   serial N                 a newer policy needs a higher one
;   budget CENTS             the purse; spend never passes it
;   max N                    nodes rented at once
;   allow CLASS REGION CENTS an instance class, where, and its price an hour
;   voter NAME PUBHEX        a node whose signed vote counts
;   decide CLASS root | decide CLASS quorum K | decide CLASS either K
;   wait SECONDS             how long a decision stays open (3600)
;   start WORD..             the command that starts a node on a rented box
; then `sig HEX` over every line above it. a request is `class C`, `region R`, `hours N`, `by NODE`,
; `why ..`, and raises a decision of class `node`. an answer is root's `answer ID yes|no` + sig, or
; a voter's `vote ID yes|no` + `voter NAME` + sig, one counted per voter per decision.
; THE ENVELOPE: budget, policy, teardown and revoke are root's in every policy -- a policy that
; hands one to a quorum is refused -- and nothing but a root signature moves them. a quorum
; spends inside the purse; it never raises it.
(module (broker broker-open broker-request broker-answer broker-tick broker-policy broker-teardown
         broker-sign broker-rent-local)
(borrow 'posix)
(borrow 'bytes)

(: br-sign-raw (cite 'ssh 'ed-sign)  br-verify-raw (cite 'ssh 'ed-verify)
   br-envelope ["budget" "policy" "teardown" "revoke"]

   ; --- text: `key value` lines, the last one a sig over all the rest ---
   (br-kv l) (: i (fsub l " " 0) (? (0 < i) [(snip l 0 i) (snip l (i + 1) #l)] [l ""]))
   (br-num s) (: v <(sound (s + "")) (charm? v && 0 <= v ? v -1))
   br-hex? (cite 'seals 'seal-hex?)
   (br-lines s) (filter (l \ 0 < #l) (lines s))
   (broker-sign k ls) (unlines ls + "sig " + b2hex (br-sign-raw <k (k 1) (unlines ls)) + "\n")
   ; text signed by pub -> its lines, the sig taken off | a reason
   (br-signed s pub)
    (: ls (br-lines s) n #ls
       (? (n < 2) "unsigned"
          (: last (br-kv (ls (n - 1))) body (take (n - 1) ls)
             (? (<last != "sig" || !(br-hex? (last 1) 64)) "no sig line"
                !(br-hex? pub 32) "no key to check it by"
                (br-verify-raw (hex2b pub) (unlines body) (hex2b (last 1))) body
                "a bad signature"))))
   ; lines -> {key [value ..]}, every value a key took, in order
   (br-fields ls) (foldl (t \ l \ br-kv l @ [k v] (pin t k (peep t k () + [v]))) {} ls)
   (br-one t k) (peep t k () @ (v . _) v "")
   (br-pol b k) (peep (b 'policy) k ())

   ; --- the files ---
   (br-read p) (uread p @ [1 s] (s + "") ())
   (br-add p s) (: q (open p "a") (? (hot? q) (: _ (say q s) _ (close q) 1) 0))
   ; a dir inside a hive tree is no place for the purse: a node could read or record it
   (br-up p) (: (cut i) (? (i <= 0) "/" (p i = 47) (snip p 0 i) (cut (i - 1))) (cut (#p - 1)))
   (br-in-tree? d) (: (up p) (? (two? (stat (p + "/.sb")) || two? (stat (p + "/.git"))) 1
                                 (p = "/" || p = "") 0
                                 (up (br-up p)))
                      (up d))

   ; --- the policy ---
   ; a parsed policy -> a tablet | a reason. the envelope classes stay root's whatever it says
   (br-parse ls)
    (: t (br-fields ls)
       auth (foldl (a \ v \ (: w (words v)
                                (? (string? a) a
                                   (#w = 2 && w 1 = "root") (pin a <w ['root 0])
                                   (#w = 3 && elem (w 1) ["quorum" "either"] && 0 < br-num (w 2))
                                     (elem <w br-envelope ? ("the envelope class " + <w + " is root's")
                                        (pin a <w [(sound (w 1) @ (s . _) s 'root) (br-num (w 2))]))
                                   ("a decide line I cannot read: " + v))))
                   {} (peep t "decide" ()))
       allow (foldl (a \ v \ (: w (words v)
                                 (? (string? a) a
                                    (#w = 3 && 0 <= br-num (w 2)) (pin a [<w (w 1)] (br-num (w 2)))
                                    ("an allow line I cannot read: " + v))))
                    {} (peep t "allow" ()))
       voters (foldl (a \ v \ (: w (words v) (? (string? a) a (#w = 2 && br-hex? (w 1) 32) (pin a <w (w 1))
                                                   ("a voter line I cannot read: " + v))))
                     {} (peep t "voter" ()))
       serial (br-num (br-one t "serial")) budget (br-num (br-one t "budget")) mx (br-num (br-one t "max"))
       wt (br-one t "wait" @ "" 3600 w (br-num w))
       (? (string? auth) auth (string? allow) allow (string? voters) voters
          (serial < 0) "no serial" (budget < 0) "no budget" (mx < 0) "no max" (wt < 0) "a bad wait"
          {'serial serial 'budget budget 'max mx 'wait wt 'auth auth 'allow allow 'voters voters
           'start (words (br-one t "start"))}))
   (br-load-policy dir root text)
    (: ls (br-signed text root) (? (string? ls) ("the policy: " + ls) (br-parse ls)))

   ; --- the state ---
   (broker-open dir)
    (: root (br-read (dir + "/root.pub") @ s (string? s ? <(words s) ()))
       pol (br-read (dir + "/policy"))
       (? (br-in-tree? dir) "the broker's state may not live inside a hive tree"
          !(string? root) "no root.pub"
          !(string? pol) "no policy"
          (br-load-policy dir root pol @ p
             (string? p ? p
                (: spent (br-read (dir + "/ledger") @ s (string? s ? (max 0 (br-num (<(words s) || "0"))) 0))
                   leases (br-read (dir + "/leases") @ s (string? s ? (map br-unrow (<(sound s) || ())) ()))
                   nreq (br-read (dir + "/log") @ s (string? s ? #(filter (l \ starts? l "request ") (lines s)) 0))
                   {'dir dir 'root root 'policy p 'spent spent 'leases leases 'nreq nreq 'open {}})))))
   (br-log b ws) (br-add (b 'dir + "/log") (foldl (\ a w (a + " " + w)) <ws >ws + "\n"))
   ; a lease on disk is a row, since a tablet does not read back
   br-cols ['lease 'class 'region 'until 'cost 'by 'host 'slot]
   (br-row l) (map (k \ peep l k "") br-cols)
   (br-unrow r) (foldl (t \ i \ pin t (br-cols i) (r i)) {} ^#br-cols)
   (br-save b) (: _ (uwrite (b 'dir + "/ledger") (show (b 'spent) + "\n"))
                  (uwrite (b 'dir + "/leases") (show (map br-row (b 'leases)) + "\n")))
   (br-live b) #(b 'leases)

   ; --- a request ---
   ; the checks the purse makes, at the ask and again at the rent: '() when it may go on
   (br-envelope-check b cls region hours)
    (: p (b 'policy) price (peep (p 'allow) [cls region] -1)
       (? (price < 0) ("off the allowlist: " + cls + " in " + region)
          (hours < 1) "hours must be a whole number above 0"
          (p 'max <= br-live b) ("at the concurrency cap of " + show (p 'max))
          (p 'budget < b 'spent + price * hours)
            ("over budget: " + show (b 'spent) + " spent + " + show (price * hours) + " > " + show (p 'budget))
          ()))
   (broker-request b text now)
    (: t (br-fields (br-lines text))
       cls (br-one t "class") region (br-one t "region") hours (br-num (br-one t "hours")) by (br-one t "by")
       id (show (b 'nreq + 1))
       _ (pin b 'nreq (b 'nreq + 1))
       _ (br-log b ["request" id (show now) "by" (#by ? by "?") cls region (show hours)])
       why (? (!(#cls) || !(#region) || !(#by)) "a request names a class, a region, hours and who asks"
              (elem cls br-envelope) ("the envelope is root's: " + cls + " is not a request")
              !(peep (br-pol b 'voters) by ()) ("no such node: " + by)
              (br-envelope-check b cls region hours))
       (? (string? why) (: _ (br-log b ["refused" id why]) why)
          (: d {'id id 'class "node" 'ask [cls region hours] 'by by 'deadline (now + br-pol b 'wait)}
             _ (pin (b 'open) id d)
             _ (br-log b ["decision" id "node" "deadline" (show (d 'deadline))])
             d)))

   ; --- the answers ---
   ; one answer's verdict on decision id -> ['root yes?] | ['vote name yes?] | a reason
   (br-read-answer b id s)
    (: ls (br-lines s) t (br-fields (take (#ls - 1) ls))
       (? (#(br-one t "answer")) (br-signed s (b 'root) @ r
                                   (string? r ? ("root's answer: " + r)
                                      (words (br-one t "answer") @ [i yn] (i = id ? ['root (yn = "yes")] "an answer to another decision")
                                         _ "an answer I cannot read")))
          (#(br-one t "vote"))
            (: nm (br-one t "voter") pub (peep (br-pol b 'voters) nm ())
               (? !(string? pub) ("a vote from no voter: " + nm)
                  (br-signed s pub @ r
                     (string? r ? ("a vote from " + nm + ": " + r)
                        (words (br-one t "vote") @ [i yn] (i = id ? ['vote nm (yn = "yes")] "a vote on another decision")
                           _ "a vote I cannot read")))))
          "neither an answer nor a vote"))
   ; the answers against the class's authority -> 'yes | 'no | a reason it stands unanswered
   (br-decide b cls rs)
    (: au (peep (br-pol b 'auth) cls ['root 0]) how <au k (au 1)
       roots (filter (r \ <r = 'root) rs)
       ; one vote a voter: the first one it cast
       votes (foldl (a \ r \ (? (<r = 'vote && !(any (v \ v 1 = r 1) a)) (a + [r]) a)) () rs)
       yes (#(filter (v \ v 2) votes)) no (#(filter (v \ !(v 2)) votes))
       rt (? (two? roots) (? (<roots 1) 'yes 'no))
       qt (? (k <= yes) 'yes (k <= no) 'no)
       (? (how = 'root) (rt || "unanswered: it is root's")
          (how = 'quorum) (qt || ("unanswered: " + show yes + " of " + show k + " votes"))
          (rt || qt || "unanswered by root or the quorum")))
   (broker-answer b id answers now rent)
    (: d (peep (b 'open) id ())
       (? !(tablet? d) (: _ (br-log b ["refused" id "no open decision"]) "no open decision")
          (: rs (map (s \ br-read-answer b id s) answers)
             bad (filter string? rs)
             v (? (d 'deadline < now) "unanswered: past its deadline"
                  (two? bad) ("wrongly answered: " + <bad)
                  (br-decide b (d 'class) rs))
             _ (br-log b ["answer" id (string? v ? v (show v))])
             (? (v != 'yes) (: _ (pin (b 'open) id ()) (string? v ? v "refused: the answer is no"))
                (d 'ask @ [cls region hours]
                   (br-envelope-check b cls region hours @ why
                      (? (string? why) (: _ (pin (b 'open) id ()) _ (br-log b ["refused" id why]) why)
                         (rent [cls region hours (br-pol b 'start)] @ got
                            (? (string? got) (: _ (br-log b ["refused" id ("the rent failed: " + got)]) got)
                               (: cost (peep (br-pol b 'allow) [cls region] 0 * hours)
                                  l {'lease id 'class cls 'region region 'until (now + hours * 3600)
                                     'cost cost 'by (d 'by) 'host (show <got) 'slot (got 1)}
                                  _ (pins b 'spent (b 'spent + cost) 'leases (b 'leases + [l]))
                                  _ (pin (b 'open) id ())
                                  _ (br-save b)
                                  _ (br-log b ["rented" id cls region (show hours) (show cost) "on" (show <got)])
                                  l))))))))))

   ; --- the root's own: a new policy, a teardown ---
   (broker-policy b text)
    (: p (br-load-policy (b 'dir) (b 'root) text)
       (? (string? p) (: _ (br-log b ["refused" "policy" p]) p)
          (p 'serial <= br-pol b 'serial)
            (: _ (br-log b ["refused" "policy" "not a newer serial"]) "not a newer serial")
          (: _ (uwrite (b 'dir + "/policy") text) _ (pin b 'policy p)
             _ (br-log b ["policy" (show (p 'serial)) "budget" (show (p 'budget))])
             1)))
   (br-drop b l free) (: _ (free l) _ (pin b 'leases (filter (x \ x 'lease != l 'lease) (b 'leases))) _ (br-save b)
                         (br-log b ["freed" (l 'lease) (l 'class)]))
   (broker-teardown b text free)
    (: r (br-signed text (b 'root))
       (? (string? r) (: _ (br-log b ["refused" "teardown" ("not root's: " + r)]) ("not root's: " + r))
          (words (br-one (br-fields r) "teardown") @ [id]
             (filter (l \ l 'lease = id) (b 'leases) @ (l . _) (: _ (br-drop b l free) 1)
                _ (: _ (br-log b ["refused" "teardown" id "no such lease"]) "no such lease"))
             _ "a teardown names one lease")))
   (broker-tick b now free)
    (: gone (filter (l \ l 'until <= now) (b 'leases))
       _ (each gone (l \ br-drop b l free))
       #gone)

   ; --- renting on our own boxes: a host whose caps name the class, a slot, the node started ---
   (broker-rent-local who)
    {'rent (a \ (: hs ((cite 'hosts 'hosts-with) <a ())
                   (? (atom? hs) ("no host here has the cap " + <a)
                      ((cite 'hosts 'hosts-take) hs who ("broker: " + <a) @ [h slot]
                         (: line ((cite 'hosts 'hosts-line) h "" (a 3))
                            r (two? (a 3) ? (hark ["sh" "-c" line]) [0 ""])
                            (? (<r = 0) [(h "name") slot] (: _ ((cite 'hosts 'hosts-free) slot who) "the node did not start")))
                         _ "no slot"))))
     'free (l \ (cite 'hosts 'hosts-free) (l 'slot) who)}
)
) ; module 'broker
