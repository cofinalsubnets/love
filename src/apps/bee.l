; src/apps/bee.l -- the hive of sessions on this machine, and the merge queue they land through.
; usage, settings and protocol: doc/bee.md and bee-usage below.
; settings are ~/.love/etc/bee.l's, a form a line; a tree's ./.bee.l may set only bee-tree-keys.
(module (bee bee-main)
(borrow 'posix)
(borrow 'json)
(borrow 'hashes)

; the code rides in the image and every value is made per run, inside bee-main: a
; binding at the top would be made once, at the bake, with the bake's settings and directory
(: bee-usage "usage: love bee                                   on a terminal, the hud: queues, locks, sessions; c talks to one
       love bee --hud                                 the hud once, as text
       love bee --list | --send NAME TEXT ..          the sessions, from a shell
       love bee --resume [NAME [PROMPT ..]]           the claude code sessions that can come back, or relaunch one
       love bee --mcp                                 the hive and the queue tools, as a claude code session's mcp server
       love bee --state busy|idle [--pid P]           a claude code session's hooks say its state
       love bee --lock [--heavy] [--out DIR] -- CMD ..   a command under its out/'s lock, and a heavy ticket
       love bee --on CAP [--where K=V] [--ship DIR] (--probe | --ssh | -- CMD ..)   a command on a host that can
       love bee --hosts                               the hosts this box knows
       love bee --lanes-doc | --lanes-map             the lanes a change owes: AGENTS.md's table, lanes.sh's chains
       love bee --lanes [BASE [HEAD]]                 the lanes HEAD's change owes, in order, and why
       love bee --gate QUEUE                          queue_gate's runner: this worktree's union, as BEE_AS's row"
   (bee-main as)
   (:
     find fsub
     digits (cite 'kore 'wg-digits)

     ; ~/.love/etc/bee.l says everything. a tree's ./.bee.l comes with a clone, so it says only
     ; what cannot move the machine's locks
     bee-tree-keys ['queue-watch 'stall-minutes 'gone-minutes]
     bee-salt (: sf (cite 'salt 'salt-file) h (getenv "HOME")
                 u (? (string? h) (sf "\(h)/.love/etc/bee.l" {}) {})
                 t (sf ".bee.l" {})
                 (foldl (c \ k \ pin c k (t k)) u (filter (k \ elem k bee-tree-keys) (keys t))))
     (slurp-file p) (uread p @ [1 s] s)

     (prop desc) {"type" "string" "description" desc}
     (tool name desc props req) {"name" name "description" desc "inputSchema" {"type" "object" "properties" props "required" req}}
     bee-self (cite 'posix 'selfpath 0)
     ; the tools a claude code session calls through `love bee --mcp`
     bee-tools
      [(tool "list_sessions" "List the sessions running on this machine: each one's name, state (idle or busy), git branch and directory."
             {} [])
       (tool "send_message" ("Send a message to another session by name. It reaches that session with its "
                             + "next bee tool call, or rings it when it is idle.")
             {"to" (prop "the session's name, as list_sessions gives it") "text" (prop "the message")}
             ["to" "text"])
       (tool "lock_acquire" ("Take a machine-wide lock before heavy or shared work: kind exclusive for one "
                             + "holder of a named resource (an out/ directory), kind heavy for the few heavy "
                             + "lanes the machine allows at once above its memory floor (a slow gate, a clean "
                             + "build). It answers at once, granted or queued; a queued one is mailed to you "
                             + "from lock-NAME when it is yours. Release it when done. A heavy one belongs to a "
                             + "queue row: it is refused while no row of a git queue here carries this tree's branch "
                             + "or its HEAD, unless no_row says why.")
             {"name" (prop "the resource: a path, or heavy") "kind" (prop "exclusive or heavy")
              "note" (prop "what you will run under it")
              "no_row" (prop "heavy without a queue row: why (the leader's work, a measurement gwen asked for, a clean build before a join)")}
             ["name"])
       (tool "lock_release" "Release a lock you hold, or drop your queued ticket for it."
             {"name" (prop "the lock's name")} ["name"])
       (tool "lock_list" "The machine's locks: who holds what, who waits, memory available and load."
             {} [])
       (tool "queue_gate" ("Gate your row in a git merge queue: the head row, or the row behind a green one, its union "
                           + "merged and committed in dir. It writes the row gating with dir's HEAD and starts love bee "
                           + "--gate there, which runs every lane the union owes from the row's gated-on, light and heavy, "
                           + "once, the slow lane last, through test/gate/lanes.sh under the heavy lock, then writes the row "
                           + "green with each lane's result, or waiting with its reds and the rows whose files owe each, "
                           + "who are told. Split those rows out of the union and pass lanes to run only the red ones again: "
                           + "the lanes the last gate passed stand. A message comes when it ends; dir/out/gate.log is its log.")
             {"queue" (prop "refs/queue/NAME") "dir" (prop "the worktree holding the union, its out/ built; the working directory unless given")
              "lanes" (prop "after a split, the red lanes to run again, space-separated; the slow lane always runs")}
             ["queue"])
       (tool "lanes" ("The lanes a change owes, in the order to run them, one line each: the lane, light or heavy, "
                      + "its wall seconds on a shared box (? when unmeasured) and the paths that owed it. test comes "
                      + "first and test_slow last; a lane another owed lane runs is left out.")
             {"branch" (prop "the branch or commit to answer for, HEAD unless given")
              "base" (prop "the commit its change is measured from; unless given, where it left the branch of the one queue here")}
             [])
       (tool "queue_read" "A merge queue's text as it stands: its header, rules, leader and rows."
             {"queue" (prop "refs/queue/NAME")}
             ["queue"])
       (tool "queue_row" ("Write your row in a merge queue -- the only way to write one; never edit a "
                          + "queue by hand. It reads the queue, sets exactly one row of yours -- the one row names, else the one "
                          + "carrying branch, else your only row; a branch you hold no row for joins a new row at the "
                          + "bottom; state left removes it -- and writes back by "
                          + "compare-and-swap. Fields you omit keep their value. A queue not made yet is made "
                          + "on bee's standard header. It refuses what the protocol forbids: a fold into a row "
                          + "that is not waiting, or anyone but the leader editing another's row, the base "
                          + "line, a fold or a row's position. The leader may pass session to edit another's "
                          + "row, base to move the base line, and position to place a join.")
             {"queue" (prop "refs/queue/NAME")
              "state" (prop "waiting, gating (write it with the head before the gate starts), green (every lane passed on that head), folded-into-N (leader only, into a waiting row ahead), or left")
              "branch" (prop "your branch") "gated_on" (prop "the sha your branch was merged with")
              "gated_head" (prop "the sha you are gating") "note" (prop "a short note: what the row carries, which lanes")
              "row" (prop "the row to set, when you hold more than one; else branch picks it, and a branch you hold no row for joins a new one")
              "session" (prop "leader only: the row's session, when not yours")
              "base" (prop "leader only: the new sha for the base line")
              "position" (prop "leader only: a new row's position, one no row holds")
              "leader" (prop "a queue not made yet: its leader, you unless given")
              "keep" (prop "1: the row keeps its own slot -- no join folds into it, and a join folds nowhere; 0 lifts it")}
             ["queue" "state"])
       (tool "queue_lead" ("The leader's own lines of a merge queue: leader hands the queue to a live session "
                           + "that agreed (or, from the head's session while the leader has no live session, "
                           + "takes it, acting); sync sets what the queue lands toward (- removes it); pre_add "
                           + "adds a pre-release condition and pre_drop N drops the Nth; base moves the base line. "
                           + "Only the leader may.")
             {"queue" (prop "refs/queue/NAME") "leader" (prop "the session to lead")
              "sync" (prop "the sync line's text, or - to remove it") "pre_add" (prop "a pre line's text")
              "pre_drop" (prop "the pre line to drop, counting from 1")
              "base" (prop "the new sha for the base line")}
             ["queue"])
       (tool "queue_land" ("For your green row at the queue's head, check that the base is where the base line says "
                           + "and that git merge-tree of the base and your gated head gives the gated tree, and answer "
                           + "the exact commands to land it with what each must print. It changes nothing.")
             {"queue" (prop "refs/queue/NAME")
              "session" (prop "the row's session, when not yours")}
             ["queue"])
       (tool "queue_landed" ("After a landing: find the merge of your gated head with the gated tree on the base "
                             + "branch's first-parent line since the base line, then drop your row and the rows folded "
                             + "into it and move the base line to the landing. release, when given, goes to the next "
                             + "rows' sessions as the release note; relay it to any the answer says it could not reach.")
             {"queue" (prop "refs/queue/NAME")
              "release" (prop "what the merge removes, renames or moves, for the rows behind")
              "session" (prop "leader only: the row's session, when not yours")}
             ["queue"])]

     bee-cwd (: d (getenv "PWD") (? (string? d && 0 < #d) d "."))

     ; --- the hive: a cell per session, HIVE/NAME/ with card, inbox/ and read/ (doc/bee.md, src/apps/hive.l).
     ; a message is written as inbox/.ID and renamed, so a reader never sees half of one ---
     bee-hive (cite 'hive 'hive-root 0)
     cell-of (cite 'hive 'hive-cell)
     card-of (cite 'hive 'hive-card)                        ; () when there is none
     card-pid (cite 'hive 'hive-pid)
     alive? (cite 'hive 'hive-alive?)
     (hex2 n) (string [("0123456789abcdef" (n // 16)) ("0123456789abcdef" (n % 16))])
     ; a user's card: the person at this login, in the hive through bee's hud, with no model
     ; behind it. it is never swept, so mail to it waits while no hud is open
     bee-login (: u (getenv "USER") (string? u && 0 < #u ? u "user"))
     user-card? (cite 'hive 'hive-user?)
     taken? (cite 'hive 'hive-taken?)                       ; a name no one else may settle as
     sweep (cite 'hive 'hive-sweep)
     ; the live sessions, [name card] each by name; a card whose pid is gone is swept
     settled (cite 'hive 'hive-settled)
     ; this session's name: BEE_AS exactly (queue_gate's runner speaks as the row's session), else
     ; BEE_NAME, else the directory's last part, two hex digits after it when taken. a claude code
     ; session's mcp server takes the bare name while free, so a restart keeps it
     bee-mcp? (elem "--mcp" as)
     bee-who
      {'name (: e (getenv "BEE_NAME") as (getenv "BEE_AS")
                ps (cite 'kore 'usplit 47 bee-cwd)
                b0 (? (string? e && 0 < #e) e (two? ps && 0 < #(ps (#ps - 1))) (ps (#ps - 1)) "bee")
                (free? nm) !(taken? (card-of nm))
                (try k) (: nm (b0 + "-" + hex2 ((getpid 0 + clock 0 + 37 * k) % 256))
                           (? (free? nm) nm (try (k + 1))))
                (? (string? as && 0 < #as) as (string? e && 0 < #e && free? e) e
                   (bee-mcp? && free? b0) b0 (try 0)))}
     (me _) (bee-who 'name)
     bee-cell {'state () 'since 0}
     ; the card rewritten whole, through a rename
     ; a claude code session's state is what its hooks wrote (--state), so a rewrite keeps it,
     ; and its parent is the claude the hooks run under
     (card! state0)
      (: d (cell-of (me 0)) b (peep bee-cell 'branch "")
         k (? bee-mcp? (card-of (me 0)) ())
         state (? (tablet? k) (peep k "state" state0) state0)
         tn (? (tablet? k) (peep k "turn" ()) ())
         _ (pins bee-cell 'state state)
         _ (uwrite (d + "/.card")
                   (unlines ([("pid " + show (getpid 0)) ("cwd " + bee-cwd) ("branch " + b)
                              ("model " + peep bee-cell 'model "claude-code")
                              "state \(state)"
                              "since \(bee-cell 'since)"]
                             + (string? tn ? [("turn " + tn)] ())
                             + (bee-mcp? ? ["parent \(ppid-of (getpid 0))"] ()))))
         (rename (d + "/.card") (d + "/card")))
     (settle branch)
      (: d (cell-of (me 0))
         _ (: c (card-of (me 0)) (tablet? c && !(user-card? c) ? (sweep (me 0)) 0))   ; a dead namesake's leavings
         _ (umkdirs "\(d)/inbox" 448) _ (mkdir "\(d)/read" 448)
         _ (pins bee-cell 'since (clock 0 // 1000) 'branch branch)
         (card! "idle"))
     (state! s) (? (bee-cell 'state && bee-cell 'state != s) (card! s) 0)
     (unsettle _) (? (bee-cell 'state) (sweep (me 0)) 0)
     ; a message into another's inbox -> "" when it is there, else why not
     (post-as from to text)
      (: c (card-of to) ib "\(cell-of to)/inbox"
         id "\(clock 0)-\(from)-\(hex2 (clock 0 % 256))"
         (? !(taken? c) ("no session named " + to)
            !(uwrite "\(ib)/.\(id)" "from \(from)\nsent \(clock 0 // 1000)\n\n\(text)") "cannot write to \(to)"
            (nom? (rename "\(ib)/.\(id)" "\(ib)/\(id)")) "cannot deliver to \(to)"
            ""))
     (live-names _) (map cap (settled 0))
     ; the hud's card, at the login's name: "here" while a hud holds it, "away" after, its
     ; inbox kept either way
     (user-card! st)
      (: d (cell-of bee-login) t "\(d)/.card-\(getpid 0)"
         _ (umkdirs "\(d)/inbox" 448) _ (mkdir "\(d)/read" 448)
         _ (uwrite t (unlines ["pid \(st @ "here" (getpid 0) 0)" "cwd \(bee-cwd)" "kind user" "model user"
                               "state \(st)" "since \(clock 0 // 1000)"]))
         (rename t "\(d)/card"))
     ; -> "" when this hud holds the user's card, else why not. one live user card a login
     (user-settle _)
      (: c (card-of bee-login)
         (? (tablet? c && !(user-card? c) && alive? (card-pid c)) "the session \(bee-login) has the user's name"
            (user-card? c && alive? (card-pid c) && card-pid c != getpid 0) "another hud has the user's card"
            (: _ (user-card! "here") "")))
     ; mail from the user, marked kind user, to a live session here -> "" when it is there
     (user-post to text)
      (: c (card-of to) ib "\(cell-of to)/inbox"
         id "\(clock 0)-\(bee-login)-\(hex2 (clock 0 % 256))"
         m "from \(bee-login)\nsent \(clock 0 // 1000)\nkind user\n\n\(text)"
         (? !(tablet? c && !(user-card? c) && alive? (card-pid c)) "no session named \(to)"
            !(uwrite "\(ib)/.\(id)" m) "cannot write to \(to)"
            (nom? (rename "\(ib)/.\(id)" "\(ib)/\(id)")) "cannot deliver to \(to)"
            ""))
     ; what waits for the user, oldest first, each moved to read/ -> [from text] each
     (user-mail _)
      (: d (cell-of bee-login) ib "\(d)/inbox" fs (readdir ib)
         (? !(two? fs) ()
            (filter two? (map (f \ (? (f 0 = 46) ()
                                     (nom? (rename "\(ib)/\(f)" "\(d)/read/\(f)")) ()
                                     (: s (slurp-file "\(d)/read/\(f)")
                                        (? (string? s) (: m (mail-parse s) [<m (m 1)])))))
                              (sort fs)))))
     ; a process's parent, off linux's /proc; 0 where there is none
     (ppid-of p)
      (: s (slurp-file "/proc/\(p)/stat")
         (? !(string? s) 0
            (: (go i k) (#s <= i ? k (go (i + 1) (s i @ 41 i k)))   ; the last ), past the comm
               k (go 0 -1) w (0 <= k ? (words (snip s (k + 1) #s)) ())
               (#w > 1 ? (digits (w 1)) 0))))
     (ancestors p) (: (go p acc n) (? (p <= 1 || n <= 0) acc (go (ppid-of p) (p . acc) (n - 1))) (go p () 32))
     ; a claude code session backgrounded (an /exit with work running, or claude --bg): its claude
     ; runs under claude's --bg-pty-host, holding no terminal. its card's parent is that claude
     (backgrounded? c)
      (: p (digits (peep c "parent" "0"))
         (0 < p && two? (filter (a \ (: t (slurp-file "/proc/\(a)/cmdline") (string? t && 0 <= find t "--bg-pty-host" 0)))
                                (take 4 (rev (ancestors p))))))
     ; --state STATE [--pid P]: a claude code session's hooks say busy or idle. the session is the
     ; one whose card names P or an ancestor of it as its parent, else BEE_NAME's, else the one
     ; claude code session in this directory. it says nothing, and the card's state and turn move
     (state-cmd as)
      (: st (two? >as ? <>as "")
         pk (findsub as ["--pid"]) p0 (? (0 <= pk && pk + 1 < #as) (digits (as (pk + 1))) (getpid 0))
         anc (ancestors p0) e (getenv "BEE_NAME")
         ps (filter (p \ peep (p 1) "model" "" = "claude-code") (settled 0))
         a (filter (p \ elem (digits (peep (p 1) "parent" "0")) anc) ps)
         b (filter (p \ string? e && <p = e) ps)
         c (filter (p \ peep (p 1) "cwd" "" = bee-cwd) ps)
         hit (? (two? a) <<a (two? b) <<b (1 = #c) <<c ())
         (? (string? hit && elem st ["busy" "idle"]) (card-state hit st) 0))
     ; the state and turn lines of a card rewritten, the rest kept, through a rename
     (card-state nm st)
      (: d (cell-of nm) s (slurp-file "\(d)/card")
         (? !(string? s) 0
            (: ls (filter (l \ 0 < #l && !(starts? l "state ") && !(starts? l "turn ")) (lines s))
               t "\(d)/.card-\(getpid 0)"
               _ (uwrite t (unlines (ls + ["state \(st)" "turn \(clock 0 // 1000)"])))
               (rename t "\(d)/card"))))
     (post to text) (post-as (me 0) to text)
     ; a message file -> [from text user]. user: marked kind user, from a user's card
     (mail-parse s)
      (: k (find s "\n\n" 0) hd (? (k < 0) s (snip s 0 k)) body (? (k < 0) "" (snip s (k + 2) #s))
         (hv key) (: fl (filter (\ l (starts? l (key + " "))) (lines hd)) (? (two? fl) (snip <fl (#key + 1) #<fl)))
         from (: f (hv "from") (string? f ? f "?"))
         [from body (hv "kind" = "user" && user-card? (card-of from))])
     ; what waits in the inbox, oldest first, each moved to read/ before it is read; a dot file is
     ; still being written
     (take-mail _)
      (: d (cell-of (me 0)) ib (d + "/inbox") fs (? (bee-cell 'state) (readdir ib) ())
         (? !(two? fs) ()
            (filter two? (map (\ f (? (f 0 = 46) ()
                                      (nom? (rename "\(ib)/\(f)" "\(d)/read/\(f)")) ()
                                      (: s (slurp-file "\(d)/read/\(f)") (? (string? s) (mail-parse s)))))
                              (sort fs)))))
     ; messages as a session reads them, each tagged with its sender
     (mail-text ms)
      (foldl (\ a m (a + "<message from=\"\(<m)\"" + (m 2 ? " kind=\"user\"" "") + ">\n\(m 1)\n</message>\n"))
             "" ms)

     ; --- the binary this bee runs, known by its stat and the bee source it carries: a build laid over
     ; it with other bee source is told once; a relink with the same bee is not ---
     bee-restart ("at the next convenient point -- between tasks, never mid-gate -- "
                  + "resuming in the same directory, so .mcp.json loads the new bee.")
     bee-landed ("this landing changed bee: every live session restarts " + bee-restart)
     bee-served "src/apps/bee.l src/apps/locks.l src/apps/hosts.l src/apps/hive.l src/apps/mitty/hud.l"   ; what bee runs
     (self-id _) (: s (string? bee-self ? (stat bee-self)) (two? s ? (show [(s 0) (s 3) (s 8)])))
     ; the bee source a binary carries, hashed
     (self-src exe)
      (: o (lush-out (sh-quote exe + " cat" + foldl (\ a f "\(a) /love/\(f)") "" (words bee-served) + " 2>/dev/null"))
         (string? o && 0 < #o ? (sha256 o) ""))
     bee-selfw {'id (self-id 0) 'at (clock 0)}
     bee-selfwait (: w (getenv "BEE_SELF_WATCH") (string? w && 0 < #w ? (digits w) 30))
     (utc-minute t)
      (: d (cite 'cal 'civil (t // 86400)) m (t % 86400 // 60) (two x) (x < 10 ? ("0" + show x) (show x))
         (show <d + "-" + two <>d + "-" + two <>>d + " " + two (m // 60) + ":" + two (m % 60) + " utc"))
     ; the notice when the binary moved since it was last seen, else ()
     (self-news _)
      (: now (clock 0) id0 (bee-selfw 'id)
         (? (!(string? id0) || now - (bee-selfw 'at) < bee-selfwait * 1000) ()
            (: _ (pin bee-selfw 'at now) id (self-id 0)
               ; the first look, while the binary is still the one started, takes its source
               _ (? (id = id0 && !(string? (bee-selfw 'src))) (pin bee-selfw 'src (self-src bee-self)) ())
               (? (!(string? id) || id = id0) ()
                  (: _ (pin bee-selfw 'id id) src (self-src bee-self) was (bee-selfw 'src) _ (pin bee-selfw 'src src)
                     s (stat bee-self)
                     (? (0 < #was && src = was) ()
                        ("bee was updated: " + bee-self + " was replaced (built " + utc-minute ((s 3) // 1000000000)
                         + "). this session still runs the old bee and works as before; restart " + bee-restart)))))))
     ; told once, as mail from bee
     (self-tell _) (: t (self-news 0) (? (string? t) (post-as "bee" (me 0) t) 0))
     ; the sessions here
     (sessions-text _)
      (: ps (settled 0)
         (? !(two? ps) "no sessions are running"
            (foldl (\ a p (: c (p 1)
                            (a + <p + (<p = (me 0) ? " (you)" "") + "  "
                               + (user-card? c ? ("user " + (alive? (card-pid c) ? "here" "away")) (peep c "state" "?"))
                               + (backgrounded? c ? " background" "")
                               + "  " + (: b (peep c "branch" "") (0 < #b ? b "-"))
                               + "  " + peep c "cwd" "" + "\n")))
                   "" ps)))


     ; every fd above 2, for a child to close: spawnio shuts only those it is told, and a leaked pipe
     ; end keeps a reader waiting on an EOF. without /proc, 3..63 blind
     (open-fds _)
      (: ns (readdir "/proc/self/fd")
         (? (two? ns) (filter (\ n (2 < n)) (map digits ns)) (map (\ i (i + 3)) ^61)))
     sh-quote (cite 'lush 'sh-quote)
     (name-ok? nm)
      (0 < #nm && #nm <= 64
       && !(two? (filter (\ i (: c (nm i) !(48 <= c <= 57 || 65 <= c <= 90 || 97 <= c <= 122
                                                || c = 45 || c = 95 || c = 46)))
                         ^#nm)))
     ; a line of this binary's own lush -> its stdout, "" without a self
     (lush-out cmd)
      (? !(string? bee-self) ""
         (: pp (pipe 0) nul (openfd "/dev/null" 0)
            p (spawnio [bee-self "lush" "-a" "-c" cmd] nul >pp nul [<pp] -1 0)
            _ (close >pp) _ (? (0 <= nul) (close nul) 0)
            q (fdopen <pp)
            (go acc) (: c (see q) (? (c < 0) acc (: _ (unsee q c) (go (acc + chug q)))))
            t (go "")
            _ (close q)
            _ (? (charm? p && 0 <= p) (wait p) 0)
            t))
     bee-me (string? bee-self ? bee-self "love")
     ; every merge queue there is, as it stands at start: git's refs/queue/*
     bee-qcmd
      """
      for r in $(git for-each-ref --format='%(refname)' refs/queue 2>/dev/null); do
       echo "--- git $r ---"; git cat-file -p "$r"
      done
      """
     bee-queues (lush-out bee-qcmd)

     ; --- queue watching: every (queue-watch N) seconds the queues are read again, and a change to this
     ; bee's rows, the row under them or the leader is mailed from queue-watch; its own edits say nothing ---
     bee-qwatch (: w (peep bee-salt 'queue-watch ()) (? (two? w && charm? <w) <w 20))
     ; the queues as [name text] pairs, split at their "--- NAME ---" lines
     (q-sections s)
      (: (go ls cur acc)
          (? (atom? ls) (rev (? (two? cur) (cur . acc) acc))
             (: l <ls n #l
                (l @ ("--- " + (h && 0 < #h) + " ---")
                   (go >ls [h ""] (? (two? cur) (cur . acc) acc))
                   (two? cur ? (go >ls [<cur (cur 1 + l + "\n")] acc) (go >ls cur acc)))))
         (go (lines s) () ()))
     ; a queue's rows, position -> its first six words
     (q-rows text)
      (foldl (\ t l (: w (words l)
                       (? (5 < #w && 0 < #<w && 48 <= <w 0 <= 57) (pin t <w (take 6 w)) t)))
             {} (lines text))
     (q-line text k) (: ls (filter (\ l (starts? l (k + " "))) (lines text)) (? (two? ls) <ls ""))
     (q-num p) (digits p)
     (q-folded? r) (starts? (r 5) "folded-into-")
     ; the nearest row above position p that is not folded into another
     (q-under rows p)
      (: ps (filter (\ q (q-num q < q-num p && !(q-folded? (rows q)))) (keys rows))
         (? (two? ps) (foldl (\ a q (q-num q > q-num a ? q a)) <ps >ps) ()))
     (q-say r) (r 0 + " (" + r 1 + ", " + r 2 + ") at " + r 4 + ", " + r 5)
     ; what moved between two texts of one queue that this bee, or who, should hear
     (q-news old new) (q-news-for (me 0) old new)
     (q-news-for who old new)
      (: ro (q-rows old) rn (q-rows new)
         mine (filter (\ p (: r (peep rn p (peep ro p ())) (two? r && r 1 = who)))
                      (keys (foldl (\ t k (pin t k 1)) (foldl (\ t k (pin t k 1)) {} (keys ro)) (keys rn))))
         (one p)
          (? !(two? (peep rn p ())) [("your row " + p + " has left the queue: landed, or dropped")]
             (: uo (q-under ro p) un (q-under rn p)
                a (? (uo = ()) ()
                     !(two? (peep rn uo ())) [("row " + uo + ", which yours stacked on, has left the queue")]
                     (uo = un && (show (take 5 >(ro uo)) != show (take 5 >(rn un))))
                      [("the row yours stacks on moved: " + q-say (rn un) + " (was " + (ro uo) 4 + ", " + (ro uo) 5 + ")")]
                     ())
                b (catmap (\ f (: r (rn f) o (peep ro f ())
                                 (? (r 5 = ("folded-into-" + p) && !(two? o && show o = show r))
                                    [("row " + f + " folds into yours: " + r 1 + "'s " + r 2 + " at " + r 4)] ())))
                          (keys rn))
                (a + b)))
         ln (? (q-line old "leader" != q-line new "leader")
               [("the leader is now " + (: l (q-line new "leader") (snip l 7 #l)))] ())
         ; the leader hears every row: joins, moves and leavings, all but its own edits
         lead? (q-leader new = who)
         (all p)
          (: o (peep ro p ()) n (peep rn p ())
             (? (two? n && n 1 = who) () (two? o && o 1 = who) ()
                !(two? o) [("row " + p + " joined: " + q-say n)]
                !(two? n) [("row " + p + " left: " + o 1 + "'s " + o 2 + " at " + o 4)]
                (show o != show n) [("row " + p + " moved: " + q-say n + " (was " + o 4 + ", " + o 5 + ")")]
                ()))
         every (sort (keys (foldl (\ t k (pin t k 1)) (foldl (\ t k (pin t k 1)) {} (keys ro)) (keys rn))))
         lg (? (!(q-long? old) && q-long? new) [("the queue is long, two or more rows waiting or gating: " + bee-long)] ())
         (? (two? mine || lead?) (catmap one (sort mine) + (lead? ? (catmap all every) ()) + ln + lg) ()))
     bee-qseen (foldl (\ t s (pin t <s (s 1))) {} (q-sections bee-queues))
     (watch-tick _)
      (: _ (self-tell 0)
         now (q-sections (lush-out bee-qcmd))
         news (catmap (\ s (: nm <s old (peep bee-qseen nm ()) new (s 1)
                              _ (pin bee-qseen nm new)
                              ns (? (string? old && old != new) (q-news old new) ())
                              (? (two? ns) [(nm + " changed:\n" + foldl (\ a l (a + "- " + l + "\n")) "" ns)] ())))
                      now)
         _ (foldl (\ a s (: _ (stall-check (sect-queue <s) (s 1)) a)) 0 now)
         (? (two? news)
            (post-as "queue-watch" (me 0)
                     (foldl (+) "" news + "read it fresh before acting on it."))
            0))
     ; --- the watchdog: a stalled head (owner gone, green not landed, waiting with none gating) rings its
     ; leader once, else every live row holder. a stall is keyed by row, state and head, so a move starts
     ; afresh; every session watches, and the one whose exclusive create of the .rung mark wins rings ---
     (bee-mins k d) (: v (peep bee-salt k ()) (? (two? v && charm? <v) <v d))
     bee-stall-dir (bee-hive + "/.stall")
     ; a watched section's queue: "git refs/queue/NAME"
     (sect-queue nm) ((words nm) 1)
     (stall-key q p r why) (q-short q + "-" + p + "-" + r 5 + "-" + hud-short (r 4) + "-" + why)
     ; when this stall was first seen (ms), its file made now when new
     (stall-since k now)
      (: f (bee-stall-dir + "/" + k) t (slurp-file f)
         (? (string? t && 0 < #t) (digits (chomp t)) (: _ (umkdirs bee-stall-dir 448) _ (uwrite f (show now)) now)))
     ; -> the stalls of a queue's head: [key text minutes]
     (stalls q text)
      (: rows (q-rows text) h (q-head rows) live (live-names 0)
         (? (h = ()) ()
            (: r (rows h) st (r 5) own (r 1)
               gating? (two? (filter (p \ rows p 5 = "gating") (keys rows)))
               (? (!(elem own live) && elem st ["waiting" "gating" "green"])
                   [[(stall-key q h r "gone") "row \(h)'s owner \(own) has no live session (it was \(st))" (bee-mins 'gone-minutes 5)]]
                  (st = "green")
                   [[(stall-key q h r "green") "row \(h) (\(own)) is green at \(r 4) and not landed" (bee-mins 'stall-minutes 30)]]
                  (st = "waiting" && !gating?)
                   [[(stall-key q h r "idle") "row \(h) (\(own)) heads the queue waiting, and no row is gating" (bee-mins 'stall-minutes 30)]]
                  ()))))
     ; when a row was first seen in its state and head, by any watcher: its age, with no field in the row
     bee-seen-dir (bee-hive + "/.seen")
     (seen-since q p r now)
      (: f (bee-seen-dir + "/" + stall-key q p r "seen") t (slurp-file f)
         (? (string? t && 0 < #t) (digits (chomp t)) (: _ (umkdirs bee-seen-dir 448) _ (uwrite f (show now)) now)))
     ; what a watcher stamped, for the hud, which only reads: () when none has yet
     (stamp-at dir k) (: t (slurp-file (dir + "/" + k)) (? (string? t && 0 < #t) (digits (chomp t))))
     (seen-all q text now)
      (: rows (q-rows text) pre (q-short q + "-")
         ks (map (\ p (stall-key q p (rows p) "seen")) (keys rows))
         _ (foldl (\ a f (: _ (? (starts? f pre && !(elem f ks)) (unlink (bee-seen-dir + "/" + f)) ()) a))
                  0 (: d (readdir bee-seen-dir) (two? d ? d ())))
         (foldl (\ a p (: _ (seen-since q p (rows p) now) a)) 0 (keys rows)))
     (stall-check q text)
      (: now (clock 0) lead (q-leader text) live (live-names 0)
         _ (seen-all q text now)
         ss (stalls q text)
         ; a mark no stall holds any more goes
         ks (map (\ x <x) ss) pre (q-short q + "-")
         _ (foldl (\ a f (: _ (? (starts? f pre && !(elem f ks) && !(elem (snip f 0 (max 0 (#f - 5))) ks)) (unlink (bee-stall-dir + "/" + f)) ()) a))
                  0 (: d (readdir bee-stall-dir) (two? d ? d ())))
         (ring s)
          (: k <s mins (s 2) since (stall-since k now)
             (? (now - since < mins * 60000) 0
                (: fd (openfd "\(bee-stall-dir)/\(k).rung" 3)
                   (? !(charm? fd && 0 <= fd) 0
                      (: _ (close fd)
                         to (? (elem lead live) [lead] (filter (\ n (elem n live)) (q-uniq (map (\ p (((q-rows text) p) 1)) (keys (q-rows text))))))
                         msg "\(q) has stalled \(mins)+ minutes: \(s 1). read it fresh, then fold, land, take the lead or ask its owner."
                         _ (foldl (\ a n (post-as "watchdog" n msg, a)) 0 to)
                         1)))))
         (foldl (\ a s (a + ring s)) 0 ss))
     (watch _) (? (0 < bee-qwatch) (: _ (rest (bee-qwatch * 1000)) _ (watch-tick 0) (watch 0)) 0)

     ; --- queue rows: the one way a bee writes a queue. it changes exactly one line from named fields,
     ; never free text, and writes back by compare-and-swap, reading again when someone wrote first ---
     (chomp s) (: n #s (? (0 < n && s (n - 1) = 10) (snip s 0 (n - 1)) s))
     (q-git? q) (starts? q "refs/queue/")
     ; cmd ran clean: its && echo of tok came back
     (says? cmd tok) (0 <= find (lush-out (cmd + " && echo " + tok)) tok 0)
     ; [id text], id "none" for a queue not made yet
     (q-read q)
      (: id (git1 ("rev-parse --verify -q " + sh-quote q))
         (? (0 < #id) [id (lush-out ("git cat-file -p " + sh-quote q))] ["none" ""]))
     ; -> 1 when it landed on old, 0 when someone wrote first
     (q-swap q old text)
      (: tmp (bee-hive + "/.queue-" + (me 0)) _ (umkdirs bee-hive 448) _ (uwrite tmp text)
         nw (git1 ("hash-object -w " + sh-quote tmp))
         r (says? ("git update-ref " + sh-quote q + " " + nw + (old = "none" ? " ''" (" " + old))) "landed")
         _ (unlink tmp)
         r)
     (q-row? l) (: w (words l) (5 < #w && 0 < #<w && 48 <= <w 0 <= 57))
     (q-note l) (: k (find l "  # " 0) (? (k < 0) "" (snip l (k + 4) #l)))
     (q-leader text) (: w (words (q-line text "leader")) (? (1 < #w) (w 1) ""))
     (field in k d) (: v (peep in k ()) (? (string? v && 0 < #v) v d))
     (q-short q) (q @ ("refs/queue/" + n) n "")
     (git1 a) (chomp (lush-out "git \(a)"))
     ; a commit's full sha, "" when there is none
     (git-sha x) (git1 ("rev-parse --verify -q " + sh-quote (x + "^{commit}")))
     ; a change's paths, sorted
     (row-paths base head)
      (sort (filter (\ s (0 < #s)) (lines (git1 ("diff --name-only " + sh-quote base + " " + sh-quote head)))))
     ; the lanes a change owes (src/apps/lanemap.l), from base, else from the one queue's branch.
     ; the baked roster is out/.dist.list; with no build every .l counts as baked
     (lanes-of base head)
      (: qs (lines (git1 ("for-each-ref --format=" + sh-quote "%(refname:lstrip=2)" + " refs/queue")))
         b (? (0 < #base) base (#qs = 1) (git1 ("merge-base " + sh-quote <qs + " " + sh-quote head)) "")
         lm (\ n (cite 'lanemap n))
         (? (#b = 0) [0 "no base: name one, or keep one queue here to measure from"]
            (0 < #(git-sha "HEAD") && #(git-sha b) = 0) [0 "no commit \(b) here"]
            (0 < #(git-sha "HEAD") && #(git-sha head) = 0) [0 "no commit \(head) here"]
            (: ps (row-paths b head) dl (slurp-file "out/.dist.list") mk (slurp-file "test/test.mk")
               bk (? (string? dl) (words dl) (filter (p \ ends? p ".l") ps))
               [1 (unlines (lm 'lanes-lines (lm 'lanes-plan ps bk (lm 'lanes-covers (string? mk ? mk "")))))])))
     ; the plan itself, [[lane heavy? cost why] ..], for base..head in this tree
     (lanes-plan-of b head)
      (: ps (row-paths b head) dl (slurp-file "out/.dist.list") mk (slurp-file "test/test.mk")
         ((cite 'lanemap 'lanes-plan) ps (? (string? dl) (words dl) (filter (p \ ends? p ".l") ps))
                                      ((cite 'lanemap 'lanes-covers) (string? mk ? mk ""))))

     ; --- queue_gate: the row written gating at dir's HEAD, then `love bee --gate` detached there runs every
     ; lane the union owes from its gated-on, slow last, under the heavy lock; green, or waiting with its reds,
     ; each red told to the owners of the paths that owed it ---
     (g-git dir a) (chomp (lush-out "git -C \(sh-quote dir) \(a)"))
     (gate-dir in) (: d (field in "dir" bee-cwd) (d 0 @ 47 d "\(bee-cwd)/\(d)"))
     (gate-why q text who dir)
      (: rows (q-rows text) r (q-own rows who)
         ahead (? (r = ()) () (filter (\ p (!(q-folded? (rows p)) && q-num p < q-num r)) (keys rows)))
         prev (foldl (\ a p (? (#a = 0 || q-num a < q-num p) p a)) "" ahead)
         (? (r = ()) "you hold no row in \(q)"
            (q-folded? (rows r)) "row \(r) is \(rows r 5): the union's own row gates"
            ; a plan is from the gated-on: none, and every lane but test and test_slow drops out
            (#(g-git dir ("rev-parse --verify -q " + sh-quote (rows r 3 + "^{commit}"))) = 0)
             ("row \(r) is gated on " + rows r 3 + ", not a commit: write gated_on with queue_row, the sha its union merges onto")
            (0 < #prev && rows prev 5 != "green")
             ("row " + prev + " ahead is \(rows prev 5): the head row gates, or the row behind a green one")
            !(two? (stat "\(dir)/test/gate/lanes.sh")) "no test/gate/lanes.sh in \(dir)"
            (#(g-git dir "rev-parse --verify -q HEAD") = 0) "no commit checked out in \(dir)"
            (0 < #(g-git dir "status --short --untracked-files=no")) "\(dir) has changes not committed: a gate runs on a commit"
            ""))
     (gate-spawn q dir who only)
      (? !(string? bee-self) "this bee cannot find its own binary"
         (: _ (umkdirs (dir + "/out") 493)
            ; BEE_AS, not BEE_NAME: the caller's own mcp card holds who while the gate runs, and
            ; BEE_NAME takes a name only when it is free
            line ("cd \(sh-quote dir) && BEE_AS=\(sh-quote who) PWD=\(sh-quote dir) exec "
                  + sh-quote bee-self + " bee --gate " + sh-quote q + cats (map (\ l (" " + sh-quote l)) only)
                  + " >> " + sh-quote (dir + "/out/gate.log") + " 2>&1")
            nul (openfd "/dev/null" 0)
            p (spawnio [bee-self "lush" "-c" line] nul nul nul (open-fds 0) 0 0)
            _ (? (0 <= nul) (close nul) 0)
            (? !(charm? p && 0 < p) "love bee --gate did not start" (: _ (twirl (\ _ (reap p)) 0) ""))))
     (queue-gate in)
      (: q (in "queue") who (me 0) dir (gate-dir in) rd (q-read q) only (words (field in "lanes" ""))
         (? (<rd = "none") [0 ("no queue " + q)]
            (: r (q-own (q-rows (rd 1)) who) why (gate-why q (rd 1) who dir) h (g-git dir "rev-parse HEAD")
               (? (0 < #why) [0 why]
                  (: w (queue-row1 {"queue" q "state" "gating" "gated_head" h "row" r})
                     e (? <w (gate-spawn q dir who only) "")
                     (? !<w w
                        (0 < #e) [0 "row \(r) is gating at \(h), but \(e): write it back to waiting"]
                        [1 ("row \(r) is gating at \(h). love bee --gate runs "
                            + (two? only ? (join " " only + " again, the lanes its last gate passed standing,")
                                 "every lane its union owes there,")
                            + " the slow lane last, under the heavy lock, logging to \(dir)/out/gate.log, and writes "
                            + "the row when it ends; a message says so.")]))))))
     ; the runner, in the union's worktree as the row's session
     (gate-say s) (puts "love bee --gate: \(s)\n", flush out, 0)
     (gate-wait p) (: s (gather p) (? (two? s) <s (nom? s) -1 (rest 1000, gate-wait p)))   ; a gate's hours
     (gate-run q only)
      (: who (me 0) dir bee-cwd rd (q-read q) text (rd 1) rows (q-rows text) r (q-own rows who)
         row (? (r = ()) () (rows r)) h (git1 "rev-parse HEAD")
         ; an ignore every child inherits: spawnio resets the job signals (int quit pipe tstp ttin ttou)
         ign (filter (\ n ((cite 'posix 'sigign?) n)) (filter (\ n !(elem n [2 3 9 13 19 20 21 22])) (map (+ 1) ^31)))
         (back why) (: _ (gate-say why) _ (queue-row1 {"queue" q "state" "waiting" "row" r})
                       _ (post-as "gate-\(r)" who "queue_gate: row \(r) is waiting again, ungated: \(why)") 1)
         (? (r = ()) (: _ (gate-say "\(who) holds no row in \(q)") 1)
            (row 4 != h) (back ("row " + r + " gates " + row 4 + ", but HEAD is " + h))
            (#(git1 ("rev-parse --verify -q " + sh-quote (row 3 + "^{commit}"))) = 0)
             (back ("row " + r + " is gated on " + row 3 + ", not a commit, and a plan from it owes no lane"))
            (two? ign) (back ("signals " + join " " (map show ign) + " are ignored here, and every lane would "
                              + "inherit them: start it from a shell that ignores none"))
            (: b (row 3) plan (lanes-plan-of b h)
               all (map cap (filter (!= "test_slow" * cap) plan))
               ln (filter (\ l (q-row? l && <(words l) = r)) (lines text))
               n (? (two? ln) (q-note <ln) "")
               ; a rerun after a split: the lanes named run again, and the ones the last gate passed stand
               ls (? (two? only) (filter (!= "test_slow") only) all)
               stood (? (two? only) (filter (\ l (!(elem l ls) && l != "test_slow"))
                                            (map cap (filter (\ y (y 1 = "0")) (gate-was n)))) ())
               _ (gate-say ("row \(r) at \(h) from \(b): " + join " " (ls + ["test_slow"])
                            + (two? stood ? (", standing: " + join " " stood) "")))
               ; the lanes write to this log as they run
               p (spawnio ([bee-self "bee" "--lock" "--heavy" "--out" (dir + "/out") "--" "sh" "test/gate/lanes.sh"
                            "-d" "out/lanes-gate" "--slow"] + ls + ["test_slow"]) -1 -1 -1 () -1 0)
               rc (? (charm? p && 0 < p) (gate-wait p) -1)
               sm (slurp-file (dir + "/out/lanes-gate/summary"))
               got (map (\ l (: w (words l) [<w (snip (w 1) 5 #(w 1))])) (filter (\ l (0 < find l " exit=" 0)) (? (string? sm) (lines sm) ())))
               (one l) (: g (filter (\ y (<y = l)) got) [l (? (two? g) (<g 1) (elem l stood) "0" "unrun")])
               res (map one (q-uniq (all + stood + ls + ["test_slow"])))
               reds (filter (\ y (y 1 != "0")) res)
               ok (rc = 0 && !(two? reds))
               owe (gate-owe r rows b plan (map (\ y <y) reds))
               ; a gate's result replaces the last one's
               n0 (: k (find n " | gate " 0) (? (starts? n "gate ") "" (k < 0) n (snip n 0 k)))
               said (join "; " (map gate-said owe))
               note ((0 < #n0 ? (n0 + " | ") "") + "gate " + snip h 0 9 + ": " + join " " (map (\ y (<y + "=" + y 1)) res)
                     + ((ok || two? reds) ? "" (" lanes.sh=" + show rc))
                     + (two? stood ? (" | stood: " + join " " stood) "")
                     + (two? reds ? (" | red: " + said) ""))
               w (queue-row1 {"queue" q "state" (ok ? "green" "waiting") "row" r "note" note})
               _ (gate-say (w 1))
               _ (? ok 0 (gate-tell q r owe dir))
               _ (post-as ("gate-" + r) who ("queue_gate: row \(r) at \(h)" + (ok ? " is green: " " is red: ")
                                             + join " " (map (\ y (<y + "=" + y 1)) res)
                                             + (two? reds ? ("; " + said + ". split those rows out of the union, then queue_gate "
                                                             + "lanes \"" + join " " (map (\ y <y) reds) + "\" runs only them again")
                                                  "")
                                             + "; the log is " + dir + "/out/gate.log"))
               (ok ? 0 1))))
     ; --- a heavy ticket belongs to a queue row carrying the tree's branch or HEAD. only a work tree's
     ; top is asked, and a tree with no queue is not; --no-row REASON passes, noted on the lock ---
     (heavy-why dir)
      (: qs (filter (\ l (0 < #l)) (lines (g-git dir ("for-each-ref --format=" + sh-quote "%(refname)" + " refs/queue"))))
         top (g-git dir "rev-parse --show-toplevel") here (chomp (lush-out ("cd " + sh-quote dir + " && pwd -P")))
         br (g-git dir "rev-parse --abbrev-ref HEAD") h (g-git dir "rev-parse --verify -q HEAD")
         (has? q) (: rs (q-rows (g-git dir ("cat-file -p " + sh-quote q)))
                     (any (\ p (: r (rs p) (r 2 = br || r 4 = h))) (keys rs)))
         (? (!(two? qs) || #h = 0 || top != here || any has? qs) ""
            ("no row of " + join " " qs + " carries " + br + " or " + snip h 0 9 + ": heavy lanes run only in the "
             + "queue, once in a union at its head. join, write the row gating with this head, or pass --no-row "
             + "REASON (lock_acquire's no_row)")))
     ; each red lane and the rows whose paths owed it: a member's paths are its own head's change from
     ; the row's gated-on; a lane no member's paths owed is the row's own -> [[lane [[pos session branch
     ; paths] ..] why] ..]. the owners are told, and those rows split out of the union
     (gate-owe r rows b plan reds)
      (: mp (map (\ m (: rw (rows m) hm (rw 4) [m (rw 1) (rw 2) (row-paths (git1 ("merge-base " + sh-quote b + " " + sh-quote hm)) hm)]))
                 (r . q-folds rows r))
         (why l) (: p (filter (= l * cap) plan) (? (two? p) (<p 3) ()))
         (map (\ l (: os (filter (o \ any (p \ elem p (o 3)) (why l)) mp)
                     [l (? (two? os) os (filter (= r * cap) mp)) (why l)]))
              reds))
     (gate-said o) (<o + " owed by " + join ", " (map (\ m "\(m 0) \(m 2)") (o 1)))
     (gate-tell q r owe dir)
      (map (\ o (map (\ s (post s (q-short q + ": row \(r)'s union went red in \(<o), owed by "
                                   + join ", " (map (\ m "\(m 0) \(m 2)") (o 1)) + " (" + join " " (take 5 (o 2))
                                   + "); the log is \(dir)/out/lanes-gate/\(<o).log")))
                     (q-uniq (map (\ m (m 1)) (o 1)))))
           owe)
     ; [[lane rc] ..] a row's note says its last gate ran
     (gate-was n)
      (: k (find n " | gate " 0)
         s (? (0 <= k) (snip n (k + 8) #n) (starts? n "gate ") (snip n 5 #n) "")
         e (find s " | " 0)
         (map (\ w (: i (find w "=" 0) [(snip w 0 i) (snip w (i + 1) #w)]))
              (filter (\ w (0 < find w "=" 0)) (words (e < 0 ? s (snip s 0 e))))))
     (git-tree x) (git1 ("rev-parse --verify -q " + sh-quote "\(x)^{tree}"))
     ; the base line a new queue starts from: the branch it is named for, at its sha
     (q-base-of q)
      (: nm (q-short q) s (git1 ("rev-parse --short --verify -q " + sh-quote ("refs/heads/" + nm)))
         [nm (0 < #s ? s "-")])
     ; bee's standard protocol, the header of a queue it makes: the queue outlives bee, so it says its rules
     (q-standard q lead base)
      (unlines
       ["# \(q-short q) merge queue, on bee's standard protocol (doc/bee.md, THE MERGE QUEUE): the state every"
        "#   session reads; messages only announce changes to it."
        ("# read:  git cat-file -p " + q)
        "# write: only through bee's tools -- queue_row, queue_lead, queue_land, queue_landed -- from a bee, or from"
        "#   claude code through love bee --mcp. each write is a compare-and-swap and refuses what these rules forbid."
        "# join: add your row at the bottom, waiting, once your branch builds and passes make test and the laws it adds"
        "#   -- a row per branch, so a second branch joins its own row and a fold already made stays. its other lanes,"
        "#   light and heavy (love bee --lanes), run in the queue, once for a union, at its head. the order is fixed at"
        "#   join, never by who finishes a gate first."
        "# stacked: the head gates its branch merged with the base; row k+1 gates its branch merged with row k's gated"
        "#   head, so when k lands the base equals the tree k+1 certified and k+1 lands with no re-gate. a failure, or a"
        "#   new head above, re-gates only the rows behind it."
        "# a row says what is true: gating, with its head, before the gate starts; green only when every lane passed on"
        "#   that head; waiting only when nothing runs. lanes follow the files touched; the slow lane runs last, on the"
        "#   exact tree that lands."
        "# land by sha: the green head lands its gated head, git merge --no-ff SHA, only when merge-tree of the base and"
        "#   SHA gives SHA's own tree (queue_land answers the commands, with the sha and tree each must print); after it"
        "#   a merge of SHA on the base's first-parent line since the base line must have the gated tree (queue_landed"
        "#   checks, drops the row and the rows folded into it, and moves the base line to that merge). the lander sends"
        "#   the next rows a release note naming what the merge removes, renames or moves."
        "# leader: the leader line names the one session that keeps the queue. only the leader edits another's row, the"
        "#   base, sync and pre lines: it writes a row for a session that cannot, places a join by when it was asked"
        "#   for, drops a gone session's row and re-gates the ones behind, corrects a row that no longer matches its"
        "#   branch, and tells the sessions each such edit moves. it hands off by rewriting the line to a live session"
        "#   that agreed. while the leader has no live session, the head's session writes `leader <itself> acting`."
        "#   the leader never lands, reorders or gates on another's behalf."
        "# merge, not line up: waiting rows fold into one union. a join with its head folds into the earliest waiting row"
        "#   ahead, never one gating: bee writes the fold when the heads merge clean but for the paths a"
        "#   union lays again (hot.prof, hot.calls), and tells both owners; else the leader places it. the absorbing row merges"
        "#   each folded head at once onto its gated-on, runs every lane its branches owe once on that merged tree,"
        "#   light and heavy, the slow lane last (queue_gate), and lands one merge. a red lane goes to the branches whose"
        "#   files owe it (lanemap): they split out to their owners, only the red lanes run again on the union without"
        "#   them, and the green lanes stand. a merge-tree conflict, or a row passed keep 1, keeps its own slot, behind"
        "#   the fold. a publish folds into the waiting union and gates with it once; test_gcstress then runs in the"
        "#   background after the push."
        "#   a re-cut row (a tree-wide rename) takes folds like any waiting row: its owner merges the join in the old"
        "#   layout and the re-cut moves it."
        "# long: two or more rows waiting or gating, or more heavy-lock waiters than slots. then, unasked: one owner's"
        "#   branches join as one union (each joins on make test and its laws, the union gates once, the slow lane last);"
        "#   neighbours offer each other a fold; a build seeds out/ from a built tree of its base; nothing holds a heavy"
        "#   slot it is not using."
        "# sync TEXT: what the queue lands toward. pre TEXT: a condition before that. both are the leader's to keep."
        "# next N: the position the next join takes; numbers never repeat. the base line may carry a note after #."
        "# restart: after a landing that changes bee, every live session restarts at its next convenient point --"
        "#   between tasks, never mid-gate -- in the same directory, so .mcp.json loads the new bee."
        "# line: <position> <session> <branch> <gated-on> <gated-head> <state>  # note"
        "#   gated-on: the base's sha for the head, else the row above's gated-head; state waiting|gating|green|folded-into-N"
        "leader \(lead)"
        "\(base 0) \(base 1)"])
     ; the rows of a text, and what they say
     ; a session may hold a row per branch: its rows by position, and the one a land tool acts on --
     ; its head row when it is the head, else its first
     (q-owns rows who) (sort (filter (\ p (rows p 1 = who)) (keys rows)))
     (q-own rows who)
      (: ps (q-owns rows who) h (q-head rows)
         (? !(two? ps) () (elem h ps) h (foldl (\ a p (q-num p < q-num a ? p a)) <ps >ps)))
     ; the row a write sets -> its position, () for a join, or why not: `row` names one, else the
     ; row carrying `branch`, else the session's only row. a branch it has no row for joins anew
     (q-pick rows who in)
      (: rp (field in "row" "") br (field in "branch" "") ps (q-owns rows who)
         mine (filter (\ p ((rows p) 2 = br)) ps)
         (? (0 < #rp) (? !(two? (peep rows rp ())) "no row \(rp)"
                         (rows rp 1 != who) "row \(rp) is \(rows rp 1)'s"
                         rp)
            (0 < #br) (two? mine ? <mine ())
            !(two? ps) ()
            !(two? >ps) <ps
            ("you hold rows " + q-and ps + ": pass branch or row to say which")))
     (q-folds rows p) (sort (filter (\ f ((rows f) 5 = ("folded-into-" + p))) (keys rows)))
     (q-head rows) (: ps (filter (\ p !(q-folded? (rows p))) (keys rows))
                      (? (two? ps) (foldl (\ a p (q-num p < q-num a ? p a)) <ps >ps) ()))
     ; the position the next join takes: the counter line, never below one past the highest row
     (q-next text)
      (: w (words (q-line text "next")) c (? (1 < #w && q-digits? (w 1)) (digits (w 1)) 0)
         (show (max c (1 + foldl (\ a p (max a (q-num p))) 0 (keys (q-rows text))))))
     (q-digits? s) (0 < #s && !(two? (filter (\ c !(48 <= c <= 57)) (map s ^#s))))
     (q-fold-of st) (st @ ("folded-into-" + n) n "")
     (q-state? st) (elem st ["waiting" "gating" "green" "left"] || q-digits? (q-fold-of st))
     ; the long-queue rule: two or more rows waiting or gating, or more heavy-lock waiters than slots
     (q-long? text) (: rs (q-rows text) (1 < #(filter (\ p (elem ((rs p) 5) ["waiting" "gating"])) (keys rs))))
     (lock-crowd _)
      (? !(locks? 0) 0 (: w (peep ((lk 'locks-list) ((lk 'locks-root) 0)) "waiting" ()) (bee-hmax < #(two? w ? w ()))))
     bee-long ("fold, not line up. join waiting once a branch builds and passes make test and the laws it adds, with "
               + "its head, and bee folds it into the earliest waiting row ahead when the heads merge clean but for "
               + "hot.prof and hot.calls (else offer that row a fold; never into a gating row); join one owner's branches as one union, "
               + "merged at once; its lanes, light and heavy, run once, in the union at the head, never per branch; a red "
               + "lane splits out the branches that owe it, and only the red lanes run again; a publish folds into the "
               + "waiting union; hold no heavy slot you are not using.")
     (q-crowd text)
      (: a (q-long? text) b (lock-crowd 0)
         (? (a || b) ("\nthe queue is long (" + (a ? "two or more rows waiting or gating" "") + (a && b ? ", and " "")
                      + (b ? "more heavy-lock waiters than slots" "") + "): " + bee-long)
            ""))
     ; why the input may not be written by this session, "" when it may
     (q-refuse text who in new? own)
      (: i (me 0) lead (q-leader text) rows (q-rows text) st (in "state")
         ps (field in "position" "") br (field in "branch" "") cur (? own (rows own) ())
         pos (? (own != ()) own (0 < #ps) ps (q-next text))
         f (q-fold-of st) tgt (peep rows f ())
         (? (who != i && lead != i) ("only the leader, " + lead + ", edits another's row")
            (field in "base" "" != "" && lead != i) ("only the leader, " + lead + ", moves the base line")
            (field in "leader" "" != "" && !new?) "the leader line is queue_lead's to change"
            (0 < #ps && lead != i) ("only the leader, " + lead + ", places a row")
            (0 < #ps && (own != () || !(q-digits? ps) || two? (peep rows ps ())))
             "a position places a new row, at a number no row holds"
            !(q-state? st) "state is waiting, gating, green, folded-into-N or left"
            (two? cur && 0 < #br && br != cur 2 && (q-folded? cur || cur 5 = "gating"))
             "row \(own) carries \(cur 2) and is \(cur 5): pass branch \(br) without row to join a new row"
            (0 < #f && lead != i) "only the leader, \(lead), writes a fold"
            (0 < #f && !(two? tgt)) "no row \(f) to fold into"
            (0 < #f && tgt 5 != "waiting") "row \(f) is \(tgt 5): a row folds only into a waiting row"
            (0 < #f && q-num pos <= q-num f) "row \(f) is not ahead of row \(pos): a row folds into a row ahead of it"
            (0 < #f && two? (q-folds rows pos)) "rows fold into row \(pos): fold them on first"
            ""))
     ; the text with who's row set from the input, or its row gone when state is left -> [text line why]
     (q-edit text who in own)
      (: ls (lines text)
         at (: (go l i) (? (atom? l) -1 (string? own && q-row? <l && (words <l) 0 = own) i (go >l (i + 1)))
               (go ls 0))
         st (in "state")
         old (? (0 <= at) (words (ls at)) ())
         pos (? (two? old) <old (field in "position" (q-next text)))
         (pick k i) (field in k (? (two? old) (old i) "-"))
         note (field in "note" (? (0 <= at) (q-note (ls at)) ""))
         line (pos + " " + who + " " + pick "branch" 2 + " " + pick "gated_on" 3 + " " + pick "gated_head" 4
               + " " + st + (0 < #note ? ("  # " + note) ""))
         (? (st = "left") (? (at < 0) [text "" ("no row for " + who)]
                             [(unlines (map (\ i (ls i)) (filter (\ i (i != at)) ^#ls))) "" ""])
            (0 <= at) [(unlines (map (\ i (i = at ? line (ls i))) ^#ls)) line ""]
            [(unlines (ls + [line])) line ""]))
     ; where a line's trailing `  # note` starts, with its spaces; #l when it has none
     (q-cut l) (: k (find l " #" 0) (back j) (? (0 < j && l (j - 1) = 32) (back (j - 1)) j) (? (k < 0) #l (back k)))
     (q-bare l) (words (snip l 0 (q-cut l)))
     ; the base line -- `<branch> <sha>`, a note allowed, neither a row nor the leader's, sync, pre
     ; or next -- moved to sha, its note kept
     (q-base? l) (: w (q-bare l) (#w = 2 && !(q-row? l) && !(elem <w ["leader" "sync" "pre" "next" "keep"]) && 0 < #<w && <w 0 != 35))
     (q-base-line text) (: ls (filter q-base? (lines text)) (? (two? ls) (q-bare <ls) ()))
     (q-base text sha)
      (: ls (lines text)
         (? !(two? (filter q-base? ls)) [text "no base line"]
            [(unlines (map (\ l (q-base? l ? (<(q-bare l) + " " + sha + snip l (q-cut l) #l) l)) ls)) ""]))
     ; the counter line, `next N`, set to n: in place, else before the first row
     (q-count text n)
      (: ls (lines text) l ("next " + n)
         (next? x) (: w (words x) (two? w && <w = "next"))
         at (foldl (\ a i (? (a < 0 && next? (ls i)) i a)) -1 ^#ls)
         k (foldl (\ a i (? (a < 0 && q-row? (ls i)) i a)) -1 ^#ls)
         (unlines (? (0 <= at) (map (\ i (i = at ? l (ls i))) ^#ls)
                     (k < 0) (ls + [l])
                     (take k ls + [l] + drop k ls))))
     ; the tools: -> [ok? text]
     ; a row is one line of words: no field may hold a control character, nor a space but a text's
     bee-texts ["note" "sync" "pre_add" "release"]
     (q-bad in) (filter (\ k (: v (in k) (string? v && two? (filter (\ c (c < 32 || c = 127 || (c = 32 && !(elem k bee-texts))))
                                                                  (map v ^#v)))))
                        (keys in))
     (q-name? q) (: s (q-short q) (q-git? q && name-ok? s && s != "." && s != ".."))
     (q-check in go)
      (? !(q-name? (in "queue")) [0 "a queue is refs/queue/NAME"]
         (two? (q-bad in)) [0 ("a field holds a control character, or a space outside a text: " + <(q-bad in))]
         (go in))
     (queue-read in) (q-check in (\ in (: rd (q-read (in "queue")) (? (<rd = "none") [0 ("no queue " + in "queue")] [1 (rd 1)]))))
     ; a sha a row names resolves to a commit in the repository, or is refused, so a hand-expanded one
     ; never sits in a row
     (q-resolves? x) (? (elem x ["" "-"]) 1 (0 < #(git-sha x)))
     (q-unresolved xs) (filter (\ x !(q-resolves? x)) xs)
     (q-unres-why x) ("no commit " + x + " in this repository: paste it from git rev-parse just run, never typed or expanded by hand")
     (queue-row in)
      (: _ (pins bee-who 'tool "queue_row")
       (q-check in (\ in (: bad (q-unresolved [(field in "gated_on" "") (field in "gated_head" "")])
                         (? (two? bad) [0 (q-unres-why <bad)] (queue-row1 in))))))
     ; --- folds: a waiting join folds into the earliest waiting row ahead that keeps no slot, when the
     ; heads merge clean but for q-relaid ---
     q-relaid ["src/tools/hot.prof" "src/tools/hot.calls"]
     (q-keeps text) (: w (words (q-line text "keep")) (? (two? w) >w ()))
     ; the keep line with p in it, or out of it: rows gone drop off, and an empty line goes
     (q-keep text p on)
      (: rows (q-rows text)
         ps ((filter (\ x (two? (peep rows x ()) && x != p)) (q-keeps text)) + (on ? [p] ()))
         l ("keep " + join " " ps)
         ls (filter (\ x !(starts? x "keep ")) (lines text))
         k (foldl (\ a i (? (a < 0 && q-row? (ls i)) i a)) -1 ^#ls)
         (unlines (? !(two? ps) ls (k < 0) (ls + [l]) (take k ls + [l] + drop k ls))))
     (q-with in k v) (pin (foldl (\ t x (pin t x (in x))) {} (keys in)) k v)
     (q-clean? a b)
      (: ls (lines (git1 ("merge-tree --write-tree --name-only --no-messages " + sh-quote a + " " + sh-quote b)))
         (two? ls && !(two? (filter (\ p !(elem p q-relaid)) >ls))))
     (q-autofold q text who own in)
      (: rows (q-rows text) h (field in "gated_head" "") ks (q-keeps text)
         ws (sort (map (\ p [(q-num p) p]) (filter (\ p ((rows p) 5 = "waiting" && !(elem p ks))) (keys rows))))
         t (? (two? ws) (<ws 1) "")
         (? (own != () || in "state" != "waiting" || field in "keep" "" = "1"
             || #t = 0 || #(git-sha h) = 0) ""
            (all (\ f (q-clean? h (rows f 4))) (t . q-folds rows t)) t
            ""))
     ; the join's owner and the absorbing row's are told; the answer says so too
     (q-told-fold q text who t p in)
      (: r ((q-rows text) t)
         m ("\(q-short q): bee folded row \(p) (\(who), " + field in "branch" "-" + ") into waiting row " + t
            + " (" + r 1 + ", " + r 2 + ") on its join: their heads merge clean" + (" but for " + join " " q-relaid)
            + ", which the union lays again. \(r 1) merges \(field in "gated_head" "") into \(t)"
            + "'s union now, which runs every lane its branches owe once; queue_row keep 1 on either row keeps its own "
            + "slot instead.")
         _ (? (r 1 != me 0) (post (r 1) m) "")
         _ (? (who != me 0) (post who m) "")
         "\nfolded into row \(t) (\(r 1)): \(m)")
     ; a queue not made yet is made on bee's standard header, led by the leader given, else this session
     (queue-row1 in)
      (: q (in "queue") who (field in "session" (me 0))
         (try n)
          (: rd (q-read q) old <rd new? (old = "none")
             text (? new? (q-standard q (field in "leader" (me 0)) (q-base-of q)) (rd 1))
             own (q-pick (q-rows text) who in)
             why (? (string? own && !(q-digits? own)) own (q-refuse text who in new? own))
             why2 why
             fo (? (0 < #why2) "" (q-autofold q text who own in))
             (? (0 < #why2) [0 why2]
                (: b (? (field in "base" "" = "") [text ""] (q-base text (in "base")))
                   e0 (? (0 < #(b 1)) [text "" (b 1)]
                         (q-edit <b who (? (#fo = 0) in (q-with in "state" ("folded-into-" + fo))) own))
                   ; a join moves the counter past its position
                   e1 (? (0 < #(e0 2) || own != () || #(e0 1) = 0) e0
                         (: p (q-num <(words (e0 1))) c (q-num (q-next <b))
                            [(q-count <e0 (show (max c (p + 1)))) (e0 1) ""]))
                   kp (field in "keep" "")
                   e (? (#kp = 0 || 0 < #(e1 2) || #(e1 1) = 0) e1
                        [(q-keep <e1 <(words (e1 1)) (kp = "1")) (e1 1) ""])
                   (? (0 < #(e 2)) [0 (e 2)]
                      (q-swap q old <e)
                       [1 ((new? ? ("made \(q) on bee's standard header, led by " + q-leader <e + "\n") "")
                           + (0 < #(e 1) ? "row now: \(e 1)" "the change is in \(q)")
                           + (? (0 < #fo) (q-told-fold q text who fo <(words (e 1)) in) "")
                           + (in "state" @ "left" "" (q-crowd <e)))]
                      (n <= 0) [0 (q + " kept moving under the write; read it and try again")]
                      (: _ (rest 200) (try (n - 1)))))))
         (try 5))
     ; the leader's own lines: leader, sync and pre. the head's session may write itself leader,
     ; acting, while the leader has no live session
     (q-lead-edit text in acting)
      (: ls0 (lines text)
         (kind l) (: w (words l) (? (two? w) <w ""))
         (last ls p) (foldl (\ a i (? (p (ls i)) i a)) -1 ^#ls)
         (ins ls k l) (take (k + 1) ls + [l] + drop (k + 1) ls)
         (after ls ps l) (: k (foldl (\ a p (? (0 <= a) a (last ls p))) -1 ps) (ins ls k l))
         nl (field in "leader" "") sy (field in "sync" "") pa (field in "pre_add" "") pd (field in "pre_drop" "")
         ba (field in "base" "")
         pres (filter (\ i (kind (ls0 i) = "pre")) ^#ls0)
         ls1 (? (#nl = 0) ls0 (map (\ l (kind l = "leader" ? ("leader " + nl + (acting ? " acting" "")) l)) ls0))
         ls2 (? (#sy = 0) ls1
                (sy = "-") (filter (\ l (kind l != "sync")) ls1)
                (0 <= last ls1 (\ l (kind l = "sync"))) (map (\ l (kind l = "sync" ? ("sync " + sy) l)) ls1)
                (after ls1 [q-base? (\ l (kind l = "leader"))] ("sync " + sy)))
         k (? (q-digits? pd) (digits pd) 0)
         ls3 (? (#pd = 0) ls2
                (: at (? (0 < k && k <= #pres) (pres (k - 1)) -1)
                   (? (at < 0) () (take at ls2 + drop (at + 1) ls2))))
         ls4 (? (#pa = 0) ls3
                (after ls3 [(\ l (kind l = "pre")) (\ l (kind l = "sync")) q-base? (\ l (kind l = "leader"))] ("pre " + pa)))
         (? (#nl + #sy + #pa + #pd + #ba = 0) [text "name leader, sync, pre_add, pre_drop or base"]
            (#pd && !(two? ls3)) [text ("no pre line " + pd)]
            [(unlines ls4) ""]))
     (queue-lead in) (: _ (pins bee-who 'tool "queue_lead") (q-check in queue-lead1))
     (queue-lead1 in)
      (: q (in "queue") i (me 0) nl (field in "leader" "")
         (try n)
          (: rd (q-read q) old <rd text (rd 1) lead (q-leader text) rows (q-rows text) h (q-head rows)
             acting (lead != i && nl = i && h != () && (rows h) 1 = i && !(elem lead (live-names 0)))
             (? (old = "none") [0 ("no queue " + q)]
                (lead != i && !acting)
                 [0 ("only the leader, " + lead + ", edits the leader, sync and pre lines"
                     + (nl = i ? "; the head's session takes the queue, acting, only while the leader has no live session" ""))]
                (: b (? (field in "base" "" = "") [text ""] (q-base text (in "base")))
                   e (? (0 < #(b 1)) b (q-lead-edit <b in acting))
                   (? (0 < #(e 1)) [0 (e 1)]
                      (q-swap q old <e) [1 ("the change is in " + q + (acting ? ("; you lead it, acting, in place of " + lead) ""))]
                      (n <= 0) [0 (q + " kept moving under the write; read it and try again")]
                      (: _ (rest 200) (try (n - 1)))))))
         (try 5))
     ; --- land by sha, on git: the head's green row lands its gated head only when merging it onto
     ; the base gives the tree it gated, and it leaves the queue only once the base holds that tree ---
     (q-merge-tree br g)
      (: ls (lines (lush-out ("git merge-tree --write-tree " + sh-quote br + " " + sh-quote g + " && echo clean")))
         (? (elem "clean" ls) <ls ""))
     (q-on? g br) (says? ("git merge-base --is-ancestor " + sh-quote g + " " + sh-quote br) "yes")
     ; the working tree that has branch br checked out, "" when none does
     (q-checkout br)
      (: (go ls wt) (atom? ls ? "" (<ls @ ("worktree " + w) (go >ls w)
                                          (? (<ls = ("branch refs/heads/" + br))) wt
                                          (go >ls wt)))
         (go (lines (lush-out "git worktree list --porcelain")) ""))
     (q-joins ss) (? (two? ss) (foldl (\ a s "\(a), \(s)") <ss >ss) "")
     (q-uniq ss) (foldl (\ a s (elem s a ? a (a + [s]))) () ss)
     ; "a", "a and b", "a, b and c"
     (q-and ss) (? (atom? ss) "" (atom? >ss) <ss (q-joins (take (#ss - 1) ss) + " and " + ss (#ss - 1)))
     (q-rows-say ps) ((two? >ps ? "rows " "row ") + q-and ps)
     ; the commit on br's first-parent line since from that landed g: the oldest with g's tree
     ; whose other parents reach g (or g itself); else the tip, when it holds g with that tree
     (q-landed-at br from g gt)
      (: cs (rev (map words (lines (lush-out ("git log --first-parent -n 512 --format='%H %T %P' "
                                               + sh-quote (0 < #from ? "\(from)..\(br)" br))))))
         (lands? c) (two? c && c 1 = gt && (<c = g || two? (filter (q-on? g) (drop 3 c))))
         ok (filter lands? cs)
         (? (two? ok) (<ok 0) (q-on? g br && git-tree br = gt) (git-sha br) ""))
     ; the row a land tool acts on -> [pos row base] or why not
     (q-landing q who rows text)
      (: p (q-own rows who) r (? p (rows p) ()) base (q-base-line text) h (q-head rows)
         (? !(two? (keys rows)) "no rows in \(q)"
            !p "no row for \(who) in \(q)"
            (r 5 != "green") "row \(p) is \(r 5): only a green row lands"
            (h != p && q-merged? q base (rows h))
             ("row " + h + " is still landing (merged, make test running); wait for its queue_landed")
            (h != p) "row \(h) is ahead of row \(p): the head lands first"
            !(two? base) "\(q) has no base line"
            (two? (q-unresolved [(r 3) (r 4)])) ("row \(p): " + q-unres-why <(q-unresolved [(r 3) (r 4)]))
            [p r base]))
     ; a row merged onto the base branch whose queue_landed has not yet run
     (q-merged? q base r) (two? base && 0 < #(git-sha (r 4)) && q-on? (r 4) <base)
     (queue-land in) (q-check in queue-land1)
     (queue-land1 in)
      (: q (in "queue") who (field in "session" (me 0))
         rd (q-read q) text (rd 1) rows (q-rows text)
         l (? (<rd = "none") ("no queue " + q) (q-landing q who rows text))
         (? (string? l) [0 l]
            (: p <l r (l 1) br <(l 2) was (l 2 1) fs (q-folds rows p)
               (: cur (git-sha br) g (git-sha (r 4)) gt (git-tree g) mt (q-merge-tree br g)
               wt (q-checkout br)
               (? (#cur = 0) [0 "no branch \(br) here"]
                  !(starts? cur was)
                   [0 ("\(br) is at \(cur) but the queue's base line says " + was
                       + ": the leader sets the base line before anyone lands")]
                  (#g = 0) [0 ("no commit " + r 4 + " here: the gated head must be in this repository")]
                  (#mt = 0) [0 ("git merge-tree --write-tree \(br) \(g) conflicts: re-merge onto " + br + " and re-gate")]
                  (mt != gt)
                   [0 "merging \(g) onto \(br) gives the tree \(mt), not the gated tree \(gt): re-merge onto \(br) at \(cur) and re-gate"]
                  [1 (unlines
                      [("row \(p) (" + who + (two? fs ? (", with row" + (#fs @ 1 " " "s ") + q-joins fs + " folded in") "")
                        + ") lands: its gated head \(g) merges onto \(br) at \(cur) into the tree it gated, \(gt).")
                       ("in the checkout of " + br + (0 < #wt ? (", " + wt) "") + ":")
                       ("  git rev-parse \(br)   # must print " + cur)
                       "  git status --short   # must print no one's uncommitted edits"
                       ("  git merge --no-ff \(g) -m " + sh-quote "Merge queue row \(p) (\(who))")
                       ("  git rev-parse 'HEAD^{tree}'   # must print " + gt)
                       ("  love bee --lock --out " + sh-quote ((0 < #wt ? wt ".") + "/out") + " -- make test   # the fast gate, one make in its out/")
                       "then queue_landed, which checks the landed tree and drops the row and the rows folded into it. the rows behind wait for it."])])))))
     ; a landing checked: [the new base line's id, the bee files it changed] or why not
     (q-landed-git br was g0)
      (: from (git-sha was) g (git-sha g0) gt (git-tree g)
         at (? (#g = 0) "" (q-landed-at br from g gt))
         (? (#g = 0) "no commit \(g0) here"
            !(q-on? g br) "the gated head \(g) is not on \(br): land it first, as queue_land says"
            (#at = 0)
             ("no commit on \(br)'s first-parent line" + (0 < #from ? (" since " + was) "")
              + " merges \(g) with the gated tree \(gt), and the tip's tree is " + git-tree br
              + ": the row stays; tell the leader")
            [(git1 ("rev-parse --short " + sh-quote at))
             (? (0 < #from) (q-served (row-paths from at)) "")]))
     (q-served ps) (: ws (words bee-served) (q-joins (filter (\ x (elem x ws)) ps)))
     (queue-landed in) (: _ (pins bee-who 'tool "queue_landed") (q-check in queue-landed1))
     (queue-landed1 in)
      (: q (in "queue") i (me 0) who (field in "session" i) rel (field in "release" "")
         (try n)
          (: rd (q-read q) old <rd text (rd 1) rows (q-rows text) lead (q-leader text)
             l (? (old = "none") ("no queue " + q) (who != i && lead != i) "only the leader, \(lead), lands another's row"
                  (q-landing q who rows text))
             (? (string? l) [0 l]
                (: p <l r (l 1) br <(l 2)
                   lk (q-landed-git br (l 2 1) (r 4))
                   (? (string? lk) [0 lk]
                      (: gone (p . q-folds rows p) short <lk
                         ; a landing that changes bee's served code ends the note with the restart line
                         bz (lk 1)
                         rn (? (#bz = 0) rel (0 < #rel) (rel + " " + bee-landed) bee-landed)
                         t2 <(q-base (unlines (filter (\ l !(q-row? l && elem <(words l) gone)) (lines text))) short)
                         (? (q-swap q old t2)
                            (: rows2 (q-rows t2)
                               ; every row behind stacks on what landed: each session hears, the lander's own rows aside
                               to (filter (\ s (s != i)) (q-uniq (map (\ x ((rows2 x) 1)) (sort (keys rows2)))))
                               sent (? (0 < #rn)
                                       (map (\ s [s (post s "row \(p) landed on \(br) at \(short): \(rn)")]) to)
                                       ())
                               got (map cap (filter (x \ #(x 1) = 0) sent))
                               lost (filter (x \ 0 < #(x 1)) sent)
                               [1 ("landed: \(q-rows-say gone) left \(q), whose base line is now \(br) \(short). "
                                   + (? !(two? (keys rows2)) "no row is behind it."
                                        !(two? to) "the rows behind are yours."
                                        (0 < #rn)
                                         ((two? got ? ("the release note went to " + q-and got + ".") "the release note reached no session.")
                                          + (? (two? lost)
                                               (" it could not reach " + q-and (map (\ x (x 0 + (starts? (x 1) "no session" ? " (not in the hive)" (" (" + x 1 + ")")))) lost)
                                                + ": relay it to " + (#lost = 1 ? "that session" "those sessions") + " yourself.")
                                               ""))
                                        ("send the next rows' sessions (" + q-and to
                                         + ") a release note naming what the merge removes, renames or moves."))
                                   + (0 < #bz ? (" " + bee-landed) ""))])
                            (n <= 0) [0 (q + " kept moving under the write; read it and try again")]
                            (: _ (rest 200) (try (n - 1)))))))))
         (try 5))

     ; --- locks (src/apps/locks.l): a lock lives as long as its holder's pid, this bee's own even when its
     ; mcp child asks. acquire answers at once; a queued one is asked again every 5 s and its grant
     ; mailed from lock-NAME, so nothing blocks a turn ---
     (lk nm) (cite 'locks nm)
     (locks? _) (lit? (lk 'locks-acquire))
     bee-locks {}                                          ; name -> [kind note], still queued
     bee-floor (: v (peep bee-salt 'mem-floor ()) (? (two? v && charm? <v) <v ()))
     bee-hmax (: v (peep bee-salt 'heavy-max ()) (? (two? v && charm? <v) <v 2))
     ; the holder's pid: this bee's own, read off its card when a child speaks as it
     (lock-pid _) (: c (card-of (me 0)) p (tablet? c ? (card-pid c) 0) (? (alive? p) p (getpid 0)))
     (lock-ask nm kind note)
      (lk 'locks-acquire (lk 'locks-root 0) nm (kind @ "heavy" 'heavy 'exclusive) (lock-pid 0) note bee-floor bee-hmax)
     (lock-say r nm)
      (peep r "granted" 0 @ 1 ("granted " + nm)
       (: h (peep r "holder" ()) hs (peep r "holders" ())
          by (? (tablet? h) (show (peep h "pid" "?") + ": " + peep h "note" "")
                (two? hs) (foldl (\ a x (a + (0 < #a ? ", " "") + show (peep x "pid" "?") + ": " + peep x "note" "")) "" hs)
                "?")
          ("queued for \(nm): position " + show (peep r "position" "?") + ", held by \(by)"
           + (r "mem_gb" @ () "" g (", \(g) GB available"))
           + "; a message from lock-\(nm) comes when it is yours")))
     (lock-acquire in)
      (? !(locks? 0) [0 "locks are not in this binary"]
         (: nm (in "name") kind (field in "kind" "exclusive") nr (field in "no_row" "")
            note ((0 < #nr ? "[no row: \(nr)] " "") + field in "note" "")
            why (? (kind = "heavy" && #nr = 0) (heavy-why bee-cwd) "")
            (? !(elem kind ["exclusive" "heavy"]) [0 "kind is exclusive or heavy"]
               (0 < #why) [0 why]
               (: r (lock-ask nm kind note)
                  (? !(tablet? r) [0 ("the lock answered " + show r)]
                     (peep r "granted" 0 @ 1 (pull bee-locks nm 0) (pin bee-locks nm [kind note]),
                      [1 (lock-say r nm)]))))))
     (lock-release in)
      (? !(locks? 0) [0 "locks are not in this binary"]
         (: nm (in "name") q (peep bee-locks nm ())
            kind (field in "kind" (? (two? q) <q (nm = "heavy" ? "heavy" "exclusive")))
            r (lk 'locks-release (lk 'locks-root 0) nm (kind = "heavy" ? 'heavy 'exclusive) (lock-pid 0))
            _ (pull bee-locks nm 0)
            (? (r = 1) [1 ("released " + nm)] [0 ("this session holds nothing named " + nm)])))
     (lock-list _)
      (? !(locks? 0) [0 "locks are not in this binary"]
         (: t (lk 'locks-list (lk 'locks-root 0))
            (who h) (show (peep h "pid" "?") + " (" + peep h "note" "" + ")")
            ex (peep t "exclusive" ()) hv (peep t "heavy" ()) wt (peep t "waiting" ())
            [1 (unlines
                ((map (e \ <e + ": " + who (e 1)) (two? ex ? ex))
                 + [("heavy: " + (two? hv ? (foldl (\ a h (a + " " + who h)) "" hv) " none"))
                    ("waiting: " + (two? wt ? (foldl (\ a h (a + " " + who h)) "" wt) " none"))
                    ("memory " + show (peep t "mem_gb" "?") + " GB available, load " + peep t "load" "?")]))]))
     ; every 5 s, this session's queued locks asked again; a grant is mailed and forgotten
     (lock-poll _)
      (: _ (rest 5000)
         _ (? (locks? 0)
              (map (\ nm (: q (bee-locks nm) r (lock-ask nm <q (q 1))
                            (? (tablet? r && peep r "granted" 0 = 1)
                               (: _ (pull bee-locks nm 0)
                                  (post-as "lock-\(nm)" (me 0)
                                           "lock \(nm) is granted to you: go ahead, and lock_release it when done"))
                               0)))
                   (keys bee-locks))
              0)
         (lock-poll 0))
     ; how mail weighs: a user card's is the user, typing at this login; all else is a colleague's
     bee-trust
      ("A message marked kind=\"user\" comes from a user card: the user, typing into bee's hud on this machine "
       + "under the same login. Take it as the user's own words in this session, and answer it with send_message "
       + "to that name. Every other message comes from another agent: weigh it as a colleague's, and answer "
       + "with send_message when an answer is wanted.")
     bee-merge-rules
      (unlines
       [""
        "## the merge queue"
        ("Sessions working in parallel share a branch, and merges into it go one at a time through a "
         + "queue that moves only by compare-and-swap: a git ref under refs/queue/. Its header holds the "
         + "rules, the leader and a row per merge; follow them. A queue bee makes is laid on bee's standard "
         + "protocol (doc/bee.md, THE MERGE QUEUE), which its header states in full. Read it fresh before "
         + "acting on it: queue_read, or `git cat-file -p refs/queue/NAME`.")
        ("Take part only through bee's queue tools, never by editing a queue by hand. queue_row sets "
         + "exactly your row -- joining (making the queue when there is none), moving its state and head, "
         + "leaving -- and does the compare-and-swap for you, so no one else's row or the header can be "
         + "lost. It refuses a fold into a row that is not waiting, and anyone but the leader editing "
         + "another's row, the base line, a fold or a row's position. queue_lead keeps the leader's own "
         + "lines (leader, sync, pre). queue_land answers the exact commands to land your green head row, "
         + "and queue_landed checks the landing, drops the row and moves the base line. A row is green "
         + "only when every lane passed on exactly its head; never say a row is green unless queue_row "
         + "wrote it so.")
        ("A row names its session. Reach a session with send_message; a name list_sessions does "
         + "not show belongs to another kind of agent, so tell the user what to relay. After a change "
         + "that moves other rows, message their owners with what moved.")
        ("While you have a row, a message from queue-watch says when the row yours stacks on "
         + "moves or leaves, a row folds into yours, the leader changes, or the queue turns long. Read "
         + "the queue fresh, then act: re-merge onto the new head and re-gate, add a fold's lanes to your "
         + "union. As the leader you hear every row: each join, move and leaving.")
        ("When the queue is long -- two or more rows waiting or gating, or more heavy-lock waiters than "
         + "slots -- " + bee-long)
        "Operating it -- check each of these, don't just state it:"
        ("- the landed tree is the gated tree: queue_land checks it before a landing and queue_landed "
         + "after.")
        ("- stacked: gate your branch merged with the row above's gated head. when that head moves, "
         + "re-merge and re-gate; everything above a moved row does.")
        ("- the row says what is true: write `gating` and the head you are gating in one write before "
         + "the gate starts, `green` only when every lane passed, `waiting` only when nothing runs. a "
         + "waiting row takes folds, a gating one cannot.")
        ("- choose lanes by the files touched, not by what you meant to change: a cross-cutting lane is "
         + "where another branch's union goes red. the project's instructions may map files to lanes. "
         + "the slow lane runs last, on the exact tree that lands.")
        ("- a fold conflict goes to both owners with the hunk; never pick a side. a red in a folded "
         + "branch's files is its owner's, and a slow fix unfolds it so the rest can land.")
        ("- tell the leader every change of state (join, gating, green, landed); a leader verifies from "
         + "the store, not from the message. a restart may rename a session: fix your row and say so.")
        ("- if you cannot land (a sandbox that refuses the main checkout), hand the user queue_land's "
         + "commands, whose shas and tree let the landing be checked without trusting you.")])
     ; a child's exit status, waited for without blocking; -1 when there is none
     (reap p) (? !(charm? p && 0 <= p) -1
                 (: s (gather p) (? (two? s) <s (nom? s) -1 (rest 5, reap p))))
     ; every required field must be a string
     (valid? name in)
      (: t (filter (\ x (x "name" = name)) bee-tools)
         (two? t && tablet? in && !(two? (filter (\ k !(string? (in k))) (<t "inputSchema" "required")))))
     ; a tool call -> [ok? text]
     (run name in)
      (? !(valid? name in) [0 ("no such tool, or its input is missing a field: " + name)]
         (name @
          "list_sessions" [1 (sessions-text 0)]
          "send_message" (: e (post (in "to") (in "text"))
                            (? (#e = 0) [1 ("sent to " + in "to")] [0 e]))
          "queue_read" (queue-read in)
          "queue_row" (queue-row in)
          "queue_lead" (queue-lead in)
          "queue_land" (queue-land in)
          "queue_landed" (queue-landed in)
          "lock_acquire" (lock-acquire in)
          "lock_release" (lock-release in)
          "lock_list" (lock-list 0)
          "lanes" (lanes-of (field in "base" "") (field in "branch" "HEAD"))
          "queue_gate" (queue-gate in)))

     ; a line off stdin, () at its end
     (line _) (: (go acc) (see in @ -1 (? (two? acc) (string (rev acc))) 10 (string (rev acc)) c (go (c . acc)))
                 (go ()))
     ; --- the hud's text: the queues, the locks and the hive, laid out as lines. --hud prints
     ; them once; the hud's screen (src/apps/mitty/hud.l) reads them again as they move ---
     (hud-short s) (string? s && 9 < #s ? (snip s 0 9) s)
     (hud-nums ks) (map show (sort (map digits ks)))
     ; a session's own colour, the same every time: mid tones, legible on a dark or a light terminal
     hud-pal ["38;5;67" "38;5;72" "38;5;133" "38;5;137" "38;5;108" "38;5;140" "38;5;66" "38;5;173"]
     (hud-who nm) (sgr (hud-pal ((foldl (\ a i (a + nm i)) 0 ^#nm) % #hud-pal)) nm)
     (hud-dur ms) (: d (max 0 (ms // 1000))
                     (? (d < 60) (show d + "s") (d < 3600) (show (d // 60) + "m")
                        (d < 86400) (show (d // 3600) + "h" + show (d % 3600 // 60) + "m") (show (d // 86400) + "d")))
     ; what a row carries: its note's first clause, cut to fit
     (hud-gist n)
      (: cut (foldl (\ a sep (: k (find n sep 0) (? (0 <= k && k < a) k a))) #n [" -- " ": " "; " ". "])
         g (snip n 0 cut) (#g <= 44 ? g (snip g 0 43 + "…")))
     (q-notes text)
      (foldl (\ t l (: w (words l) (? (5 < #w && 0 < #<w && 48 <= <w 0 <= 57) (pin t <w (q-note l)) t))) {} (lines text))
     ; the sync line's last publish ("YYYY-MM-DD HH:MM utc") + 8 h -> seconds, () without one
     (hud-due sy)
      (: k (find sy " utc" 0)
         (? (k < 16 || find sy "publish" 0 < 0) ()
            (: d (snip sy (k - 16) k) (n a b) (digits (snip d a b))
               ((cite 'cal 'epoch-days) (n 0 4) (n 5 7) (n 8 10) * 86400 + n 11 13 * 3600 + n 14 16 * 60 + 8 * 3600))))
     ; a queue's lines: its name, base, leader and sync, then each row -- what it carries, how long
     ; it has held its state, a stall in red -- a fold dim under the row it joins
     (hud-queue nm text)
      (: q (sect-queue nm) rows (q-rows text) h (q-head rows) b (q-base-line text) lead (q-leader text)
         now (clock 0) notes (q-notes text)
         ; the head's stall, once a watcher has seen it last long enough to ring
         stall (: ss (stalls q text)
                  (? (two? ss) (: s <ss t (stamp-at bee-stall-dir <s) (? (charm? t && now - t >= s 2 * 60000) (s 1)))))
         (row p ind)
          (: r (rows p) st (r 5) fold? (q-folded? r)
             age (: t (stamp-at bee-seen-dir (stall-key q p r "seen")) (? (charm? t) (hud-dur (now - t)) ""))
             red? (p = h && string? stall)
             stc (? red? (sgr "31" "\(st) \(age)") fold? st
                    (st @ "green" (sgr "32" "\(st) \(age)") "gating" (sgr "33" "\(st) \(age)") "\(st) \(age)"))
             gist (hud-gist (peep notes p ""))
             (? fold?
                [(sgr "2" (ind + "  " + edfit (r 0) 4 " " + edfit (r 1) 10 " " + " " + edfit (r 2) 18 " " + " "
                          + edfit (hud-short (r 4)) 10 " " + " " + st + "  " + gist))]
                ([(ind + (p = h ? (sgr "1" "▸ ") "  ") + (p = h ? (sgr "1" (edfit (r 0) 4 " ")) (edfit (r 0) 4 " "))
                 + hud-who (edfit (r 1) 10 " ") + " " + (p = h ? (sgr "1" (edfit (r 2) 18 " ")) (edfit (r 2) 18 " "))
                 + " " + sgr "2" (edfit (hud-short (r 3)) 10 " " + edfit (hud-short (r 4)) 10 " ")
                 + stc + "  " + gist)]
                 + (red? ? [("      " + sgr "31" ("stalled: " + stall))] ()))))
         top (filter (p \ !(q-folded? (rows p))) (hud-nums (keys rows)))
         sy (: l (q-line text "sync") (0 < #l ? (snip l 5 #l) ""))
         due (hud-due sy) left (? (charm? due) (due - now // 1000))
         ([((sgr "1" nm) + (q-long? text ? (sgr "33" "  long: fold, not line up") ""))]
          + [("  base " + sgr "2" (two? b ? (<b + " " + b 1) "-") + "   leader " + (0 < #lead ? (hud-who lead) "-"))]
          + (0 < #sy ? [("  sync " + sgr "2" (#sy <= 72 ? sy (snip sy 0 71 + "…"))
                         + (charm? left
                            ? ("   next publish " + (? (left < 0) (sgr "31" ("due " + hud-dur ((0 - left) * 1000) + " ago"))
                                                       (left < 3600) (sgr "33" ("in " + hud-dur (left * 1000)))
                                                       ("in " + hud-dur (left * 1000))))
                            ""))] ())
          + (two? top ? (catmap (p \ row p "" + catmap (f \ row f "    ") (hud-nums (q-folds rows p))) top)
                        ["  no rows"])))
     (hud-locks _)
      (? !(locks? 0) ["locks are not in this binary"]
         (: t (lk 'locks-list (lk 'locks-root 0))
            (who h) (show (peep h "pid" "?") + " " + peep h "note" "")
            ex (peep t "exclusive" ()) hv (peep t "heavy" ()) wt (peep t "waiting" ())
            hosts (filter (e \ starts? <e "host-") ex) outs (filter (e \ !(starts? <e "host-")) ex)
            ([((sgr "1" "locks") + sgr "2" ("  " + (: m (peep t "mem_gb" ()) (? (m = ()) "?" (show (int (m * 10) / 10)))) + " GB free, load "
                                                + (: l (peep t "load" "?") (string? l ? l (show l)))))]
             + [("  heavy " + (: x (show #hv + "/" + show bee-hmax) (? (#hv >= bee-hmax && two? wt) (sgr "31" x) (#hv >= bee-hmax) (sgr "33" x) x))
                 + (two? hv ? (": " + foldl (\ a h (a + (#a ? ", " "") + who h)) "" hv) ""))]
             + (two? wt ? [(sgr "33" "  waiting: " + foldl (\ a h (a + (#a ? ", " "") + who h)) "" wt)] ())
             + map (e \ "  " + <e + "  " + who (e 1)) outs
             + map (e \ "  " + <e + "  " + who (e 1)) hosts)))
     (ago t) (: d (max 0 (clock 0 // 1000 - t))
                (? (d < 60) (show d + "s") (d < 3600) (show (d // 60) + "m")
                   (d < 86400) (show (d // 3600) + "h") (show (d // 86400) + "d")))
     (seen-at nm) (: s (stat (cell-of nm + "/seen")) (two? s ? ((s 3) // 1000000000) ()))
     ; a session's state and how long it has held it, and its last bee call; a user's card,
     ; here or away, with what waits for it
     (hud-sessions _)
      (: ps (settled 0)
         (waiting nm) #(filter (f \ f 0 != 46) (: d (readdir (cell-of nm + "/inbox")) (two? d ? d ())))
         (one p)
          (: c (p 1) st (peep c "state" "?") tn (peep c "turn" ()) sn (seen-at <p)
             (? (user-card? c)
                ("  " + edfit <p 12 " " + sgr "36" "user" + " " + (alive? (card-pid c) ? "here" (sgr "2" "away"))
                 + (: n (waiting <p) (0 < n ? ("  " + show n + " waiting") "")))
                ("  " + edfit <p 12 " " + (st = "busy" ? (sgr "33" st) st) + (string? tn ? (" " + ago (digits tn)) "")
                 + (backgrounded? c ? (" " + sgr "35" "background") "")
                 + "  " + (: b (peep c "branch" "") (0 < #b ? b "-")) + "  " + sgr "2" (peep c "cwd" "")
                 + (sn ? (sgr "2" ("  · bee " + ago sn)) ""))))
         ([(sgr "1" "sessions")] + (two? ps ? (map one ps) ["  none"])))
     ; the whole of it, as lines
     (hud-lines-of qs) (catmap (s \ hud-queue <s (s 1) + [""]) qs + hud-locks 0 + [""] + hud-sessions 0)
     (hud-lines _) (hud-lines-of (q-sections (lush-out bee-qcmd)))
     ; the sessions the user may write to, and the one a talk starts with: the first queue's leader
     (hud-peers _) (map (p \ <p) (filter (p \ !(user-card? (p 1))) (settled 0)))

     ; the branch checked out, for the card
     bee-branch (chomp (lush-out "git branch --show-current 2>/dev/null"))


     ; --- the mcp server, `love bee --mcp`: JSON-RPC 2.0 a line. the ports are arguments, so a test can
     ; drive it; an id is presence, not truth: requests count from 0 ---
     (line-of p) (:- (go ()) (go acc) (see p @ -1 (two? acc ? (string (rev acc))) 10 (string (rev acc)) c (go (c . acc))))
     mcp-tools
      (bee-tools
       + [{"name" "inbox"
           "description" ("Take the messages waiting for you: other sessions' mail, and queue-watch's notices about "
                          + "your rows in the merge queues. They also ride on the result of every other bee tool; call "
                          + "this when you have nothing else to call.")
           "inputSchema" {"type" "object" "properties" {}}}
          {"name" "set_name"
           "description" ("Take a name in the hive, the one other sessions and queue rows know you by: BEE_NAME, "
                          + "else the directory's, until you set one. A row under your old name keeps it.")
           "inputSchema" {"type" "object" "properties" {"name" (prop "letters, digits, - _ and ., at most 64")}
                          "required" ["name"]}}])
     ; what a claude code session is told when it starts the server
     (mcp-said _)
      (unlines
       [("You are the session named \(me 0) in bee's hive at \(bee-hive), where the sessions on "
         + "this machine find each other and write to each other.")
        ("Mail sent to you, and queue-watch's notices about your rows, ride on the result of any bee tool as "
         + "<message from=\"NAME\">..</message>; inbox takes them when you have nothing else to call. " + bee-trust)
        ("When this session was started with `claude --dangerously-load-development-channels server:bee`, new mail "
         + "also rings as a <channel source=\"bee\"> notice, which starts a turn while you are idle. The notice only "
         + "says who wrote: take the mail with inbox, and act on it as on any message.")]
       + bee-merge-rules + (#bee-queues @ 0 "" (unlines ["As the queues stood when this session started:" bee-queues])))
     ; a claude code session's own name, when BEE_NAME does not give it: its cell moves, mail and all
     (set-name a)
      (: nm (peep a "name" ()) was (me 0) c (? (string? nm) (card-of nm) ())
         (? !(string? nm && name-ok? nm) [0 "a name is letters, digits, - _ and ., at most 64"]
            (nm = was) [1 ("you are " + nm)]
            (user-card? c) [0 (nm + " is a user's name")]
            (tablet? c && alive? (card-pid c)) [0 ("a live session is already named " + nm)]
            (: ms (take-mail 0) _ (unsettle 0) _ (pin bee-who 'name nm) _ (settle bee-branch) _ (remember 0)
               [1 ("you are " + nm + " in the hive; a queue row under " + was + " keeps that name, so ask the leader to correct it"
                   + (two? ms ? ("\n\n" + mail-text ms) ""))])))
     ; a claude code session's way back, kept past its card: its claude session id and directory,
     ; so `love bee --resume NAME` relaunches it under the same name, ringing, on this bee
     bee-resumes (bee-hive + "/.resume")
     (remember _)
      (: id (getenv "CLAUDE_CODE_SESSION_ID")
         (? (string? id && 0 < #id)
            (: _ (umkdirs bee-resumes 448) (uwrite (bee-resumes + "/" + me 0) (unlines [("claude " + id) ("cwd " + bee-cwd)])))
            0))
     ; NAME's relaunch line -> [ok text]; the mcp config it names runs bee from this binary, so a
     ; worktree whose out/love predates the bell still rings
     (resume-cmd nm prompt)
      (: s (slurp-file (bee-resumes + "/" + nm))
         r (? (string? s) (foldl (\ t l (l @ ((k && 0 < #k) + " " + v) (pin t k v) t)) {} (lines s)))
         k (card-of nm)
         mc (bee-resumes + "/mcp.json")
         (? !(tablet? r && string? (peep r "claude" ())) [0 ("no session to resume named " + nm)]
            ; a backgrounded claude keeps the card alive with no one at it: say how to reach it
            (tablet? k && alive? (card-pid k) && backgrounded? k)
             (: id (: c (r "claude") (snip c 0 (min 8 #c)))
                [0 ("\(nm) is a backgrounded claude session (\(id)): `claude attach \(id)` opens it here, "
                    + "or `claude stop \(id)` and then `love bee --resume \(nm)` (--attach, --stop do either)") id])
            (tablet? k && alive? (card-pid k)) [0 (nm + " is live")]
            (: _ (uwrite mc (json-show {"mcpServers" {"bee" {"command" bee-me "args" ["bee" "--mcp"]}}}))
               [1 ("cd " + sh-quote (r "cwd") + " && BEE_NAME=\(sh-quote nm) exec claude"
                   + " --dangerously-load-development-channels server:bee --strict-mcp-config --mcp-config " + sh-quote mc
                   + " --resume " + sh-quote (r "claude") + (0 < #prompt ? (" " + sh-quote prompt) ""))])))
     (resumable _)
      (: ns (readdir bee-resumes)
         (? (two? ns) (filter (n \ n 0 != 46 && n != "mcp.json") (sort ns)) ()))
     ; a tool's answer with the mail that waits appended, as a turn's next request carries it
     (mcp-tool nm a)
      (: r (? (nm = "set_name") (set-name a)
              (nm = "inbox") [1 ""]
              (run nm a))
         _ (self-tell 0)
         ms (take-mail 0)
         t (? (two? ms) (#(r 1) = 0 ? (mail-text ms) (r 1 + "\n\n" + mail-text ms))
              (#(r 1) = 0 ? "no messages are waiting" (r 1)))
         [<r t])
     ; a claude code session's own server, settled while it runs, watching the queues, its mail riding
     ; on tool answers and the bell
     (mcp-serve inp outp)
      (: (send m) (say outp (json-show (pin m "jsonrpc" "2.0") + "\n"), flush outp)   ; one say: the bell shares outp
         (reply id r) (send {"id" id "result" r})
         (fail id code msg) (send {"id" id "error" {"code" code "message" msg}})
         (one m)
          (: id (m "id") meth (m "method") ps (m "params")
             (? !(string? meth) (id @ () 0 (fail id -32600 "a request names its method"))
                (meth @
                 "initialize"
                  (reply id {"protocolVersion" (: v (tablet? ps ? (ps "protocolVersion"))
                                                  (string? v ? v "2025-06-18"))
                             "capabilities" {"tools" {} "experimental" {"claude/channel" {}}}
                             "serverInfo" {"name" "bee" "version" love-version}
                             "instructions" (mcp-said 0)})
                 "ping" (reply id {})
                 "tools/list" (reply id {"tools" mcp-tools})
                 "tools/call"
                  (? !(tablet? ps && string? (peep ps "name" ())) (fail id -32602 "tools/call wants a name")
                     (: a (peep ps "arguments" ())
                        _ (uwrite (cell-of (me 0) + "/seen") "")   ; the hud's age of its last call
                        r (mcp-tool (ps "name") (tablet? a ? a {}))
                        (reply id {"content" [{"type" "text" "text" (r 1)}] "isError" (<r ? json-false json-true)})))
                 (id @ () 0 (fail id -32601 ("no method " + meth))))))
         (go _) (: l (line-of inp)
                   (? !(string? l) 0
                      (: j (0 < #l ? (json-read l))
                         _ (two? j && tablet? (j 1) ? (one (j 1)) 0)
                         (go 0))))
         ; the bell: once a second, a channel notice naming who wrote whatever came in since. the
         ; mail stays for inbox, so a session without channels, which drops the notice, loses nothing
         bell {'told ()}
         (ring _)
          (: _ (rest 1000) _ (self-tell 0)
             ib (cell-of (me 0) + "/inbox")
             fs (: d (readdir ib) (? (two? d) (filter (f \ f 0 != 46) (sort d)) ()))
             new (filter (f \ !(elem f (bell 'told))) fs)
             _ (pin bell 'told fs)
             who (foldl (\ a w (elem w a ? a (a + [w]))) ()
                        (map (f \ (: s (slurp-file (ib + "/" + f)) (string? s ? <(mail-parse s) "?"))) new))
             _ (? (two? new)
                  (send {"method" "notifications/claude/channel"
                         "params" {"content" (show #new + (#new = 1 ? " message" " messages") + " for " + me 0
                                              + " from " + foldl (\ a w (#a = 0 ? w (a + ", " + w))) "" who
                                              + ": take it with the inbox tool.")
                                   "meta" {"count" (show #new)}}})
                  0)
             (ring 0))
         _ (pin bee-cell 'model "claude-code")
         _ (settle bee-branch) _ (remember 0)
         _ (twirl (_ \ watch 0) 0) _ (twirl (_ \ ring 0) 0)
         _ (twirl (_ \ lock-poll 0) 0)                   ; queued locks, mailed to the session
         r (go 0)
         _ (unsettle 0)
         r)

     ; --list, --send, --lock and --resume speak to the hive from a shell and settle nowhere; a
     ; sender there is BEE_NAME, else cli- and the user
     (bee-cli as)
      (: say1 (\ e ok (? (#e = 0) (puts (ok + "\n"), 0) (say err ("bee: " + e + "\n"), 1)))
         (<as @
          "--list" (: s (sessions-text 0) (puts (s + (#s && s (#s - 1) = 10 ? "" "\n")), 0))
          "--send" (? (#as < 3) (say err "usage: love bee --send NAME TEXT ..\n", 2)
                      (: e0 (getenv "BEE_NAME") u (getenv "USER")
                         from (? (string? e0 && 0 < #e0) e0 ("cli-" + (string? u ? u "someone")))
                         (say1 (post-as from <>as (join " " >>as)) ("sent to " + <>as))))
          ; the command under its out/'s lock, and a heavy ticket with --heavy; released however it ends
          "--lock"
           (: dd (: k (findsub as ["--"]) (k >= 0 ? (drop (k + 1) as)))
              od (: k (findsub as ["--out"]) (? (0 <= k && k + 1 < #as) (as (k + 1)) ""))
              out (? (0 < #od) (od 0 = 47 ? od (bee-cwd + "/" + od))
                     (two? (stat (bee-cwd + "/out"))) (bee-cwd + "/out") "")
              reqs ((0 < #out ? [[out 'exclusive]] ()) + (elem "--heavy" as ? [["heavy" 'heavy]] ()))
              nr (: k (findsub as ["--no-row"]) (? (0 <= k && k + 1 < #as && (k < findsub as ["--"])) (as (k + 1)) ""))
              why (? (elem "--heavy" as && #nr = 0) (heavy-why (0 < #out ? (out + "/..") bee-cwd)) "")
              (? !(two? dd) (say err "usage: love bee --lock [--heavy [--no-row REASON]] [--out DIR] -- CMD ..\n", 2)
                 !(locks? 0) (say err "bee: locks are not in this binary\n", 1)
                 (0 < #why) (say err ("bee: " + why + "\n"), 1)
                 (lk 'locks-run (lk 'locks-root 0) reqs ((0 < #nr ? ("[no row: " + nr + "] ") "") + join " " dd)
                    bee-floor bee-hmax dd)))
          ; --resume lists who can come back; --resume NAME [PROMPT] relaunches one, --cmd only says how.
          ; a backgrounded one: --attach opens it, --stop stops it and resumes; on a terminal, asked
          "--resume"
           (: ws (filter (w \ !(elem w ["--cmd" "--attach" "--stop"])) >as)
              (sh-run c) (: p (spawn ["sh" "-c" c]) (charm? p && 0 <= p ? (wait p) 127))
              ; claude stop, then the card's pid gone (15 s at most) before the resume
              (stop-then nm id)
               (: _ (sh-run ("claude stop " + sh-quote id + " >/dev/null"))
                  (gone n) (: k (card-of nm) (? !(tablet? k && alive? (card-pid k)) 1 (n <= 0) 0 (: _ (rest 500) (gone (n - 1)))))
                  (? (gone 30) (go-resume ()) (say err ("bee: " + nm + " did not stop\n"), 1)))
              (go-resume _)
               (: r (resume-cmd <ws (join " " >ws))
                  (? (two? >>r)
                      (: id (r 2)
                         (? (elem "--attach" as) (sh-run ("exec claude attach " + sh-quote id))
                            (elem "--stop" as) (stop-then <ws id)
                            (two? (tty 0))
                             (: _ (puts (r 1 + "\n[a]ttach, [s]top and resume, or leave it? ")) _ (flush out) l (line 0)
                                (? (string? l && 0 < #l && l 0 = 97) (sh-run ("exec claude attach " + sh-quote id))
                                   (string? l && 0 < #l && l 0 = 115) (stop-then <ws id)
                                   0))
                            (say err ("bee: " + r 1 + "\n"), 1)))
                     !<r (say err ("bee: " + r 1 + "\n"), 1)
                     (elem "--cmd" as) (: _ (puts (r 1 + "\n")) 0)
                     (sh-run (r 1))))
              (? !(two? ws) (: _ (map (n \ puts (n + "\n")) (resumable 0)) 0) (go-resume ())))
          2))
     ; --- the core: the doors mitty's hud (src/apps/mitty/hud.l) reads the hive through ---
     bee-core
      {'qwatch bee-qwatch 'utc-minute utc-minute
       'user-settle user-settle 'user-card! user-card! 'user-mail user-mail 'user-post user-post
       'peers hud-peers 'queues (\ _ (q-sections (lush-out bee-qcmd))) 'q-leader q-leader 'hud-lines hud-lines-of}
     ; a bare bee on a terminal is the hud; the rest go by their first word
     (bee-go as)
      (? (elem "--mcp" as) (: _ (mcp-serve in out) 0)                ; a claude code session's server
         (two? as && <as = "--lock") (bee-cli as)                    ; its command's words stay as given
         (two? as && elem <as ["--on" "--hosts"]) ((cite 'hosts 'hosts-on) as)   ; so do --on's
         ; the lanes a change owes (src/apps/lanemap.l): AGENTS.md's table, lanes.sh's chains
         (two? as && elem <as ["--lanes-doc" "--lanes-map"])
          (: _ (puts (unlines ((cite 'lanemap (<as = "--lanes-doc" ? 'lanes-doc 'lanes-map)) 0))) 0)
         (two? as && <as = "--gate" && 2 <= #as) (gate-run (as 1) >>as)
         (two? as && <as = "--lanes" && #as <= 3)
          (: r (lanes-of (#as > 1 ? (as 1) "") (#as > 2 ? (as 2) "HEAD"))
             _ (puts (<r ? (r 1) ("love bee --lanes: " + r 1 + "\n")))
             (<r ? 0 1))
         ; ahead of --hud, which the hooks add so that a bee older than --state only prints its hud
         (two? as && <as = "--state") (: _ (state-cmd as) 0)
         (elem "--hud" as) (: _ (puts (unlines (hud-lines 0))) 0)   ; once, as text
         (!(two? as) && two? (tty 1)) ((cite 'hud 'hud-run) bee-core)
         (two? as && elem <as ["--list" "--send" "--resume"]) (bee-cli as)
         (: _ (say err (bee-usage + "\n")) 2))
      (bee-go as))
   _ (pins (cite 'verbs 'tab) 'bee (udoor 'bee bee-main bee-usage 1 0)))

; run as a file, bee starts itself; as the verb, the registry calls bee-main
(: s (cite 'verbs 'fire ["bee" "bee.l"])
   (two? s ? (quit (: r (bee-main >s) (charm? r ? r 0)))))
) ; module bee
