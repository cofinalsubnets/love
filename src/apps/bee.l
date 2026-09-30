; src/apps/bee.l -- a coding agent: a model over its api, and the tools it may call here --
; read_file, write_file, edit_file, shell, and list_sessions and send_message, which speak to
; the other bees on this machine (doc/bee.md). a write, an edit or a command asks y/n first.
;
;   love bee [-y] [--plain] [prompt ..]      one prompt, the screen, or a > loop
;   love bee --list | --send NAME TEXT ..    the sessions, from a shell
;
; the settings are ~/.love/etc/bee.l's, each a form per line; ./.bee.l may set model,
; max-tokens, thinking, context and queue-watch over them:
;   (api anthropic)       or openai: chat completions, what ollama, llama-server and most hosts speak
;   (url "https://..")    the endpoint, http only to this machine
;   (model NAME)          claude-opus-5 on anthropic; openai has no default
;   (key-env VAR)         where the key is: ANTHROPIC_API_KEY, or OPENAI_API_KEY
;   (max-tokens N)        64000 on anthropic; openai leaves it to the server
;   (shell WORD ..)       the shell a command line runs in; lush -a, this binary's own
;   (context N)           the window in tokens, for the screen's gauge; claude's are known
;   (queue-watch N)       seconds between readings of the merge queues; 20, and 0 for never
;   (backend claude-code) a `claude -p` child thinks and runs the tools, bee the harness; api else
;   (claude-model NAME)   the model that child runs; claude's own default when unset
;   (mem-floor GB) (heavy-max N)   no heavy lock below GB available; N heavy locks at once, 2
; the answer streams: text prints as it comes. a key goes out only over tls, and only to a
; peer tls-open verified: its chain to a root the host trusts, and its name.
(module (bee bee-main)
(borrow 'posix)
(borrow 'json)

; the code rides in the image and every value is made per run, inside bee-main: a
; binding at the top would be made once, at the bake, with the bake's settings and directory
(: (bee-main as)
   (:
     dial (cite 'tls 'tls-dial)
     tsay (cite 'tls 'tls-say)
     hear (cite 'tls 'tls-hear)
     topen (cite 'tls 'tls-open)                             ; () on a binary that cannot verify
     find (cite 'kore 'wg-find)
     header (cite 'kore 'wg-header)
     digits (cite 'kore 'wg-digits)

     ; ~/.love/etc/bee.l says everything. a tree's ./.bee.l comes with a clone, so it says only
     ; what cannot move the key, the shell, the backend or the machine's locks
     bee-tree-keys ['model 'max-tokens 'thinking 'context 'queue-watch]
     bee-salt (: sf (cite 'salt 'salt-file) h (getenv "HOME")
                 u (? (string? h) (sf (h + "/.love/etc/bee.l") {}) {})
                 t (sf ".bee.l" {})
                 (foldl (\ c k (pin c k (t k))) u (filter (\ k (elem k bee-tree-keys)) (keys t))))
     (word w) (string? w ? w (show w))
     (setting k d) (: v (peep bee-salt k ()) (two? v ? (word <v) d))
     (slurp-file p) (: f (open p "r") (? (hot? f) (: s (slurp f) _ (close f) s)))
     (spit-file p s) (: f (open p "w") (? (hot? f) (: _ (say f s) _ (close f) 1)))

     ; --- where the model is ---
     bee-api (setting 'api "anthropic")
     bee-oai? (bee-api = "openai")
     bee-model (setting 'model (bee-oai? ? "" "claude-opus-5"))
     bee-url (setting 'url (bee-oai? ? "https://api.openai.com/v1/chat/completions"
                                         "https://api.anthropic.com/v1/messages"))
     bee-at (cite 'kore 'wg-url bee-url)                   ; [tls? host port path] | ()
     bee-host (? (two? bee-at) (bee-at 1) "")
     bee-key-env (setting 'key-env (bee-oai? ? "OPENAI_API_KEY" "ANTHROPIC_API_KEY"))
     bee-max (: m (peep bee-salt 'max-tokens ()) (? (two? m) <m (bee-oai? ? () 64000)))
     ; this machine, where plain http is allowed and no key is wanted
     bee-local? (elem bee-host ["localhost" "127.0.0.1" "::1"])
     ; claude's newest take the server-side fallback on a refusal
     bee-fallbacks? (!bee-oai? && (starts? bee-model "claude-opus-5" || starts? bee-model "claude-fable"
                                     || starts? bee-model "claude-mythos"))
     ; the models whose thinking comes back empty unless a summary is asked for; (thinking off)
     ; leaves the request as it is
     bee-summarize? (!bee-oai? && setting 'thinking "on" != "off"
                      && (starts? bee-model "claude-opus-5" || starts? bee-model "claude-fable"
                          || starts? bee-model "claude-mythos" || starts? bee-model "claude-sonnet-5"
                          || starts? bee-model "claude-opus-4-8" || starts? bee-model "claude-opus-4-7"))
     bee-cap 30000                                           ; a tool answer's bytes, at most
     ; the context window in tokens; () when unknown, and the gauge counts tokens instead
     bee-window (: c (peep bee-salt 'context ())
                    (? (two? c && charm? <c) <c
                       bee-oai? ()
                       (starts? bee-model "claude-haiku") 200000
                       1000000))

     (prop desc) {"type" "string" "description" desc}
     (tool name desc props req)
      {"name" name "description" desc "eager_input_streaming" json-true
       "input_schema" {"type" "object" "properties" props "required" req}}
     ; --- the shell ---
     ; (shell WORD ..) is the argv a command line follows after -c, (shell lush -a) when
     ; unset: lush first is this binary's own, -a its verbs ahead of PATH; any other word
     ; runs as written
     bee-shell (: s (peep bee-salt 'shell ()) (two? s ? (map word s) ["lush" "-a"]))
     bee-ours? (<bee-shell = "lush")
     ; lush's verbs lead only in its autonomous mode; gregarious (its default) puts PATH first
     bee-verbs-lead? (bee-ours? && (elem "-a" bee-shell || elem "--autonomous" bee-shell))
     bee-self (cite 'posix 'selfpath 0)
     (shell-argv cmd) ((bee-ours? ? (bee-self . bee-shell) bee-shell) + ["-c" cmd])
     bee-shname (foldl (\ a w (a + " " + w)) <bee-shell >bee-shell)
     bee-verbs (foldl (\ a v (a + " " + v)) "" (sort (map show (keys (cite 'verbs 'tab)))))

     bee-tools
      [(tool "read_file" "Read a file and answer its text."
             {"path" (prop "the file's path")} ["path"])
       (tool "write_file" "Write text to a file, replacing it whole."
             {"path" (prop "the file's path") "content" (prop "the new text")} ["path" "content"])
       (tool "edit_file" "Replace old_text, which must occur exactly once, with new_text."
             {"path" (prop "the file's path") "old_text" (prop "the text now there")
              "new_text" (prop "its replacement")} ["path" "old_text" "new_text"])
       (tool "shell" ("Run a command line in " + bee-shname + ". Answers stdout and stderr, then "
                      + "the exit status." + (bee-verbs-lead? ? (" The commands the system prompt names "
                      + "are love's own userland (kore); anything else comes from PATH.") ""))
             {"command" (prop "the command line")} ["command"])
       (tool "list_sessions" "List the bee sessions running on this machine: each one's name, state (idle, busy or asking), git branch and directory."
             {} [])
       (tool "send_message" ("Send a message to another bee session by name. It reaches that session "
                             + "before its next request, or starts a turn there when it is idle.")
             {"to" (prop "the session's name, as list_sessions gives it") "text" (prop "the message")}
             ["to" "text"])
       (tool "start_job" ("Start a command line in the background and answer its job id at once. When "
                          + "it ends, a message from job-ID says so with its exit status and last lines, "
                          + "waking this session if it is idle. For anything longer than a minute.")
             {"command" (prop "the command line")} ["command"])
       (tool "check_job" "A job's state (running, or its exit status) and the last lines of its output."
             {"id" (prop "the job's id, as start_job gave it")} ["id"])
       (tool "stop_job" "Stop a running job: its shell and everything it started."
             {"id" (prop "the job's id")} ["id"])
       (tool "spawn_bee" ("Start another bee, detached, in a directory -- best a worktree made for it -- "
                          + "with a first prompt. It serves until stopped: after the prompt, each message "
                          + "sent to it is a turn. It acts without asking only when this session was "
                          + "started with -y; otherwise it can read but not change anything.")
             {"name" (prop "its session name: letters, digits, - _ and .")
              "dir" (prop "the directory it works in") "prompt" (prop "what it should do first")}
             ["name" "dir" "prompt"])
       (tool "stop_bee" "Stop a bee this machine is running, by name."
             {"name" (prop "the session's name")} ["name"])
       (tool "lock_acquire" ("Take a machine-wide lock before heavy or shared work: kind exclusive for one "
                             + "holder of a named resource (an out/ directory), kind heavy for the few heavy "
                             + "lanes the machine allows at once above its memory floor (a slow gate, a clean "
                             + "build). It answers at once, granted or queued; a queued one is mailed to you "
                             + "from lock-NAME when it is yours. Release it when done.")
             {"name" (prop "the resource: a path, or heavy") "kind" (prop "exclusive or heavy")
              "note" (prop "what you will run under it")}
             ["name"])
       (tool "lock_release" "Release a lock you hold, or drop your queued ticket for it."
             {"name" (prop "the lock's name")} ["name"])
       (tool "lock_list" "The machine's locks: who holds what, who waits, memory available and load."
             {} [])
       (tool "queue_row" ("Write your row in a merge queue -- the only way to write one; never edit a "
                          + "queue by hand. It reads the queue, sets exactly your row (joining at the "
                          + "bottom if you have none, leaving it when state is left) and writes back by "
                          + "compare-and-swap. Fields you omit keep their value. The leader may also pass "
                          + "session to edit another's row, or base to move the base line when it lands.")
             {"queue" (prop "refs/queue/NAME for git, or queue/NAME for an sb ledger in the hub")
              "state" (prop "waiting, gating (write it with the head before the gate starts), green (every lane passed on that head), folded-into-N, or left")
              "branch" (prop "your branch") "gated_on" (prop "the sha your branch was merged with")
              "gated_head" (prop "the sha you are gating") "note" (prop "a short note: what the row carries, which lanes")
              "session" (prop "leader only: the row's session, when not yours")
              "base" (prop "leader only: the new sha for the base line")}
             ["queue" "state"])]

     ; --- the project's own instructions ---
     ; from / down to the working directory, each directory's AGENTS.md and then its CLAUDE.md:
     ; the files other agents read, so the same words instruct them all. both, not either: a
     ; CLAUDE.md that imports its AGENTS.md (@AGENTS.md) still holds words of its own
     bee-cwd (: d (getenv "PWD") (? (string? d && 0 < #d) d "."))
     ; "" for the root, then "/home", "/home/gwen" .. the working directory
     bee-dirs (foldl (\ a p (a + [(a (#a - 1) + "/" + p)]))
                      [""] (filter (\ p (0 < #p)) (cite 'kore 'usplit 47 bee-cwd)))
     (instr-in d) (filter two? (map (\ f (: p (d + "/" + f) s (slurp-file p) (? (string? s) [p s])))
                                    ["AGENTS.md" "CLAUDE.md"]))
     bee-instr (catmap instr-in bee-dirs)
     (clip0 s) (#s <= 40000 ? s (snip s 0 40000 + "\n[cut]"))

     ; --- the hive: the bee sessions on this machine, and the messages between them ---
     ; each running bee settles in a cell, HIVE/NAME/: `card` says who it is, a `key value` a line,
     ; `inbox/` holds what was sent to it, a file each, and `read/` what it has taken. a message
     ; is written as inbox/.ID and renamed to inbox/ID, so a reader never sees half of one.
     ; doc/bee.md is the protocol, for anything else that wants to speak it
     bee-hive (: r (getenv "BEE_HIVE") h (getenv "HOME")
                   (? (string? r && 0 < #r) r (string? h) (h + "/.love/run/hive") "/tmp/bee-hive"))
     (cell-of nm) (bee-hive + "/" + nm)
     (mkdirs p) (foldl (\ a s (: d (a + "/" + s) _ (mkdir d 448) d)) ""
                       (filter (\ s (0 < #s)) (cite 'kore 'usplit 47 p)))
     (hex2 n) (string [("0123456789abcdef" (n // 16)) ("0123456789abcdef" (n % 16))])
     (alive? p) (charm? p && 0 < p && !(nom? (still p 0)))
     ; a card as a tablet, "name" included; () when there is none
     (card-of nm)
      (: s (slurp-file (cell-of nm + "/card"))
         (? (string? s)
            (foldl (\ t l (: k (find l " " 0) (? (0 < k) (pin t (snip l 0 k) (snip l (k + 1) #l)) t)))
                   {"name" nm} (lines s))))
     (card-pid c) (digits (peep c "pid" "0"))
     ; a gone session's cell, messages and all. a cell with no card yet is being made, and stays
     (sweep nm)
      (: d (cell-of nm)
         _ (map (\ sub (: q (d + "/" + sub) fs (readdir q)
                          _ (? (two? fs) (map (\ f (unlink (q + "/" + f))) fs) 0)
                          (rmdir q)))
                ["inbox" "read"])
         _ (unlink (d + "/card"))
         (rmdir d))
     ; the live sessions, [name card] each by name; a card whose pid is gone is swept
     (settled _)
      (: ns (readdir bee-hive)
         (? !(two? ns) ()
            (filter two? (map (\ nm (: c (card-of nm)
                                       (? !(tablet? c) ()
                                          (alive? (card-pid c)) [nm c]
                                          (: _ (sweep nm) ()))))
                              (sort ns)))))
     ; this session's name: BEE_NAME, else the working directory's last part; two hex digits
     ; follow when that is taken by a live session
     ; BEE_AS is exactly the session to act as, live or not: a bee's own MCP server, run by
     ; its claude child, speaks as that bee
     bee-name
      (: e (getenv "BEE_NAME") as (getenv "BEE_AS")
         ps (cite 'kore 'usplit 47 bee-cwd)
         b0 (? (string? e && 0 < #e) e (two? ps && 0 < #(ps (#ps - 1))) (ps (#ps - 1)) "bee")
         (free? nm) (: c (card-of nm) !(tablet? c && alive? (card-pid c)))
         (try k) (: nm (b0 + "-" + hex2 ((getpid 0 + clock 0 + 37 * k) % 256))
                    (? (free? nm) nm (try (k + 1))))
         (? (string? as && 0 < #as) as (string? e && 0 < #e && free? e) e (try 0)))
     bee-cell {'state () 'since 0}
     ; the card rewritten whole, through a rename
     (card! state)
      (: d (cell-of bee-name) b (peep bee-cell 'branch "")
         _ (pins bee-cell 'state state)
         _ (spit-file (d + "/.card")
                      (paras [("pid " + show (getpid 0)) ("cwd " + bee-cwd) ("branch " + b)
                              ("model " + (bee-cc? ? (peep bee-cc 'model "claude") bee-model)) ("state " + state)
                              ("since " + show (bee-cell 'since))]
                             + (: s (peep bee-cell 'claude ()) (string? s ? ("claude " + s + "\n") ""))))
         (rename (d + "/.card") (d + "/card")))
     (settle branch)
      (: d (cell-of bee-name)
         _ (? (tablet? (card-of bee-name)) (sweep bee-name) 0)   ; a dead namesake's leavings
         _ (mkdirs (d + "/inbox")) _ (mkdir (d + "/read") 448)
         _ (pins bee-cell 'since (clock 0 // 1000) 'branch branch)
         (card! "idle"))
     (state! s) (? (bee-cell 'state && bee-cell 'state != s) (card! s) 0)
     (unsettle _) (? (bee-cell 'state) (sweep bee-name) 0)
     ; a message from one name into another's inbox -> "" when it is there, else why not
     (post-as from to text)
      (: c (card-of to) ib (cell-of to + "/inbox")
         id (show (clock 0) + "-" + from + "-" + hex2 (clock 0 % 256))
         (? !(tablet? c && alive? (card-pid c)) ("no session named " + to)
            !(spit-file (ib + "/." + id) ("from " + from + "\nsent " + show (clock 0 // 1000) + "\n\n" + text))
             ("cannot write to " + to)
            (nom? (rename (ib + "/." + id) (ib + "/" + id))) ("cannot deliver to " + to)
            ""))
     (post to text) (post-as bee-name to text)
     ; a message file -> [from text]: headers to the first blank line, then the text
     (mail-parse s)
      (: k (find s "\n\n" 0) hd (? (k < 0) s (snip s 0 k)) body (? (k < 0) "" (snip s (k + 2) #s))
         fl (filter (\ l (starts? l "from ")) (lines hd))
         [(? (two? fl) (snip <fl 5 #<fl) "?") body])
     ; what waits in this session's inbox, oldest first, each moved to read/ as it is taken; a
     ; dot file is still being written
     (take-mail _)
      (: d (cell-of bee-name) ib (d + "/inbox") fs (? (bee-cell 'state) (readdir ib) ())
         (? !(two? fs) ()
            (filter two? (map (\ f (? (f 0 = 46) ()
                                      (: s (slurp-file (ib + "/" + f))
                                         _ (rename (ib + "/" + f) (d + "/read/" + f))
                                         (? (string? s) (mail-parse s)))))
                              (sort fs)))))
     ; messages as the model reads them, each tagged with its sender
     (mail-text ms) (foldl (\ a m (a + "<message from=\"" + <m + "\">\n" + m 1 + "\n</message>\n")) "" ms)
     (sessions-text _)
      (: ps (settled 0)
         (? !(two? ps) "no bee sessions are running"
            (foldl (\ a p (: c (p 1)
                             (a + <p + (<p = bee-name ? " (you)" "") + "  " + peep c "state" "?"
                                + "  " + (: b (peep c "branch" "") (0 < #b ? b "-"))
                             + "  " + peep c "cwd" "" + "\n")))
                   "" ps)))

     ; --- jobs: a command line in the background, its group its own, its output to
     ; HIVE/jobs/NAME/ID.log. a task here drains and reaps it and then mails this bee from
     ; job-ID, so an idle screen wakes to the news and a turn reads it with its next request ---
     ; every fd above 2 this process holds, for a child to close: spawnio shuts only the ones
     ; it is told, and a leaked pipe end keeps a reader waiting on an EOF that never comes. a
     ; seat with no /proc closes 3..63 blind, which costs nothing for the ones not open
     (open-fds _)
      (: ns (readdir "/proc/self/fd")
         (? (two? ns) (filter (\ n (2 < n)) (map digits ns)) (map (\ i (i + 3)) ^61)))
     bee-jobs {'n 0}
     (job-dir _) (bee-hive + "/jobs/" + bee-name)
     (tail-of p n) (: s (slurp-file p) ls (? (string? s) (lines s) ())
                      (foldl (\ a l (a + l + "\n")) "" (#ls <= n ? ls (drop (#ls - n) ls))))
     (job-start cmd)
      (: n (bee-jobs 'n + 1) _ (pin bee-jobs 'n n) id ("j" + show n)
         _ (mkdirs (job-dir 0)) log (job-dir 0 + "/" + id + ".log")
         pp (pipe 0) nul (openfd "/dev/null" 0)
         p (spawnio (shell-argv cmd) nul >pp >pp (open-fds 0) 0 0)
         _ (close >pp) _ (? (0 <= nul) (close nul) 0)
         (? !(charm? p && 0 < p) (: _ (close <pp) ())
            (: j {'id id 'cmd cmd 'pid p 'log log 'code () 't0 (clock 0)}
               _ (pin bee-jobs id j)
               _ (twirl (\ _ (job-watch j <pp)) 0)
               id)))
     (job-watch j rfd)
      (: q (fdopen rfd) o (open (j 'log) "w")
         (go _) (: c (see q) (? (c < 0) 0 (: _ (unsee q c) _ (say o (chug q)) _ (flush o) (go 0))))
         _ (go 0) _ (close q) _ (close o)
         code (reap (j 'pid))
         _ (pin j 'code code)
         (post-as ("job-" + j 'id) bee-name
                  ("job " + j 'id + " ended with exit " + show code + " after "
                   + show ((clock 0 - j 't0) // 1000) + "s: " + j 'cmd + "\nits last lines:\n"
                   + tail-of (j 'log) 20)))
     (job-text id)
      (: j (peep bee-jobs id ())
         (? !(tablet? j) ("no job " + id)
            ((? (charm? (j 'code)) ("exit " + show (j 'code))
                ("running for " + show ((clock 0 - j 't0) // 1000) + "s"))
             + ": " + j 'cmd + "\n" + tail-of (j 'log) 30)))
     ; the whole group: the shell and whatever it started
     (job-stop id)
      (: j (peep bee-jobs id ())
         (? !(tablet? j) ("no job " + id)
            (charm? (j 'code)) (id + " has already ended")
            (: _ (still (0 - j 'pid) 15) ("stopped " + id))))

     ; --- spawning: a bee started detached in a directory, serving -- its first prompt,
     ; then a turn per message until it is stopped -- its output to HIVE/logs/NAME.log ---
     (sq s) ("'" + foldl (\ a i (a + (s i = 39 ? "'\\''" (string (s i))))) "" ^#s + "'")
     (name-ok? nm)
      (0 < #nm && #nm <= 64
       && !(two? (filter (\ i (: c (nm i) !(48 <= c <= 57 || 65 <= c <= 90 || 97 <= c <= 122
                                                || c = 45 || c = 95 || c = 46)))
                         ^#nm)))
     (settles? nm n) (? (tablet? (card-of nm)) 1 (n <= 0) 0 (: _ (rest 50) (settles? nm (n - 1))))
     ; -> "" when it has settled, else why not
     (spawn-bee nm dir0 prompt yes)
      (: dir (? (0 < #dir0 && dir0 0 = 47) dir0 (bee-cwd + "/" + dir0))
         c (card-of nm) lg (bee-hive + "/logs")
         (? !(string? bee-self) "this bee cannot find its own binary"
            !(name-ok? nm) ("a name is letters, digits, - _ and ., at most 64: " + nm)
            (tablet? c && alive? (card-pid c)) ("a bee named " + nm + " is already running")
            !(two? (stat dir)) ("no directory " + dir)
            (: _ (mkdirs lg)
               line ("cd " + sq dir + " && BEE_NAME=" + sq nm + " PWD=" + sq dir
                     + " BEE_PROMPT=" + sq prompt + " exec " + sq bee-self + " bee --serve"
                     + (yes ? " -y" "") + " >> " + sq (lg + "/" + nm + ".log") + " 2>&1")
               nul (openfd "/dev/null" 0)
               p (spawnio [bee-self "lush" "-c" line] nul nul nul (open-fds 0) 0 0)
               _ (? (0 <= nul) (close nul) 0)
               (? !(charm? p && 0 < p) ("could not start " + nm)
                  (: _ (twirl (\ _ (reap p)) 0)                  ; reaped when it ends
                     (? (settles? nm 100) ""
                        (nm + " started but has not settled; its log is " + lg + "/" + nm + ".log")))))))
     (stop-bee nm)
      (: c (card-of nm)
         (? !(tablet? c && alive? (card-pid c)) ("no bee named " + nm + " is running")
            (: _ (still (card-pid c) 15) ("stopped " + nm))))

     ; --- what the model is told ---
     ; a line of this binary's own lush, run once at start -> its stdout, "" without a self
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
     ; the date and platform from love's own verbs; the git summary only where the host has git
     bee-env
      (lush-out ("echo \"date: $(date '+%Y-%m-%d %A %H:%M %Z')\"\n"
                 + "echo \"platform: $(uname -s -r -m)\"\n"
                 + "if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then\n"
                 + " echo \"git branch: $(git branch --show-current)\"\n"
                 + " s=$(git status --short 2>/dev/null | head -n 20)\n"
                 + " echo \"git status, first 20 lines:\"; echo \"${s:-(clean)}\"\n"
                 + " echo \"recent commits:\"; git log --oneline -5 2>/dev/null | cut -c1-120\n"
                 + "fi\n"))

     (paras ls) (foldl (\ a l (a + l + "\n")) "" ls)
     bee-me (string? bee-self ? bee-self "love")
     ; how a verb is reached: by bare name where lush puts love's verbs first, else through love
     bee-run (bee-verbs-lead? ? "by bare name in your shell, where lush finds it inside love before PATH"
                                  ("as `" + bee-me + " VERB ARGS`"))
     bee-brief
      (paras
       ["## love, the binary you run in"
        ("bee, your shell and its commands all run inside one static binary, love, at `" + bee-me
         + "` (version " + love-version + "). It carries a whole toolchain and userland, so the work "
         + "needs nothing from the host: no system compiler, make, libc, coreutils or interpreter. "
         + "Run each tool " + bee-run + ". A command love does not carry comes from the host's PATH "
         + "and may be missing there, so prefer the built-in one.")
        "- cc (mooncc): a C11 compiler written in love; static executables for linux and freebsd on x64, a64 and rv64 (-t, -os), linked against its own libc. `cc -o hello hello.c && ./hello` works with an empty PATH. with it: as, ld, ar, nm, objcopy, readelf, size, strip, strings."
        "- make (cook): runs ordinary Makefiles, and Cookfiles written in love; -j works."
        "- sh (lush), vi, ed, sed, awk, grep, diff, patch, find, xargs, sort and the rest of a posix userland (kore). Flags are POSIX: a GNU-only option may be refused with status 2, and `VERB --help` shows what a verb takes."
        "- archives: tar, gzip, gunzip, xz, bzip2, cpio. network: nc, wget (with tls), ssh, scp, sshd, httpd, telnet, ping, nslookup, traceroute. also bc, dc, less, man, xxd, hexdump, ps, top, and sb, a patch-set vcs."
        ("- every verb love carries:" + bee-verbs + ".")
        ""
        "## the love language"
        "love is a curried lisp with infix sugar; source files end in .l."
        "- three special forms: (\\ x y body) is a lambda; (: a 1 b 2 body) binds in order then answers body, and a (name args) body pair inside it defines a function; (? test then test2 then2 else) is cond."
        "- every function takes one argument and currying does the rest: (f x y) is ((f x) y). there are no varargs: (+ 1 2 3) is ((+ 1 2) 3) = 3 3 = 27."
        "- infix: (a + b * c), (x ? yes no), chained (1 < 2 <= 3). application binds tighter than infix, so f x + 1 is (f x) + 1; write an application inside a ternary in parens."
        "- data: lists [1 2 3], tablets (hash maps) {'a 1 'b 2}, strings of utf-8 bytes. data indexes by application: [7 8 9] 1 = 8, \"abc\" 0 = 97, t 'a reads key 'a."
        "- numbers: 3 / 2 = 1.5 while 3 // 2 = 1; a number applied is a power, 3 2 = 8."
        "- glued prefixes: #x length, +x sum, <x first, >x rest, ^5 = (0 1 2 3 4)."
        "- truth: a value is true when it sums positive, so 0, () and -1 are all false; predicates answer 0 or 1."
        "- matching: (x @ pattern result pattern2 result2 default)."
        "- io: (puts s) writes, (show x) renders any value as a string, argv holds a program's arguments."
        ("- try an expression with `" + bee-me + " -e 'EXPR'` (it prints the answer), run a program with `"
         + bee-me + " prog.l ARGS`, list the verbs with `" + bee-me + " verbs`.")
        ""
        "## how love is made"
        "- src/love/: the virtual machine and runtime in C, and the boot .l files (evaluator, prelude)."
        "- src/apps/moon/: moon, the C compiler written in love, and its libc, moonlibc."
        "- src/apps/kore/ and src/apps/*.l: the userland in love: lush (src/apps/lush.l), cook (src/apps/cook.l), vi, nc, tar, the tls stack."
        "- src/inle/: a bare-metal kernel that shares the same image."
        "moon compiles the C runtime, the love programs are baked into an image inside the binary, and a compressed copy of the whole source tree rides along; from it the binary rebuilds itself byte for byte."
        ""
        "## the source, and working on it"
        ("- `" + bee-me + " source DIR` lays the carried source at DIR/love-" + love-version + " (DIR defaults to .).")
        ("- `" + bee-me + " seed [DIR]` lays it and rebuilds it with the built-in tools, checking the result is this binary byte for byte.")
        ("- to develop there: cd into the tree and read its CLAUDE.md, then build with love's own tools, as seed does: `LUSHFLAGS=-a CC=\"" + bee-me
         + " mooncc\" make -j dist` makes out/love, and `make test` is the fast gate. `" + bee-me
         + " src/apps/libra/libra.l FILE` checks a .l file's parens.")
        "- that build needs nothing from the host, PATH or not; two checks in make test spawn the host's sh and true by name, and fail where PATH has neither."])

     ; every merge queue there is, as it stands at start: git's refs/queue/*, and the queue/*
     ; ledgers of sb's hub nest -- SB_HUB, else this directory when it holds a .sb
     bee-qcmd
      ("for r in $(git for-each-ref --format='%(refname)' refs/queue 2>/dev/null); do\n"
       + " echo \"--- git $r ---\"; git cat-file -p \"$r\"\n"
       + "done\n"
       + "hub=${SB_HUB:-}; [ -z \"$hub\" ] && [ -d .sb ] && hub=.\n"
       + "if [ -n \"$hub\" ]; then\n"
       + " for n in $(sb -C \"$hub\" ledger 2>/dev/null | cut -d' ' -f1); do\n"
       + "  case $n in queue/*) echo \"--- sb ledger $n, in the nest at $hub ---\"; sb -C \"$hub\" ledger \"$n\";; esac\n"
       + " done\n"
       + "fi\n")
     bee-queues (lush-out bee-qcmd)

     ; --- queue watching: every (queue-watch N) seconds, 20 unless set and 0 for never, the
     ; queues are read again, and a change that concerns this bee's rows -- one leaving, the
     ; row it stacks on moving, a row folding into it, a new leader -- is mailed to it from
     ; queue-watch. rows are the header's `<position> <session> <branch> <gated-on>
     ; <gated-head> <state>`; its own edits to its own rows say nothing ---
     bee-qwatch (: w (peep bee-salt 'queue-watch ()) (? (two? w && charm? <w) <w 20))
     ; the queues as [name text] pairs, split at their "--- NAME ---" lines
     (q-sections s)
      (: (go ls cur acc)
          (? (atom? ls) (rev (? (two? cur) (cur . acc) acc))
             (: l <ls n #l
                (? (8 < n && starts? l "--- " && snip l (n - 4) n = " ---")
                   (go >ls [(snip l 4 (n - 4)) ""] (? (two? cur) (cur . acc) acc))
                   (two? cur) (go >ls [<cur (cur 1 + l + "\n")] acc)
                   (go >ls cur acc))))
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
     ; what moved between two texts of one queue that this bee should hear
     (q-news old new)
      (: ro (q-rows old) rn (q-rows new)
         mine (filter (\ p (: r (peep rn p (peep ro p ())) (two? r && r 1 = bee-name)))
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
         lead? (q-leader new = bee-name)
         (all p)
          (: o (peep ro p ()) n (peep rn p ())
             (? (two? n && n 1 = bee-name) () (two? o && o 1 = bee-name) ()
                !(two? o) [("row " + p + " joined: " + q-say n)]
                !(two? n) [("row " + p + " left: " + o 1 + "'s " + o 2 + " at " + o 4)]
                (show o != show n) [("row " + p + " moved: " + q-say n + " (was " + o 4 + ", " + o 5 + ")")]
                ()))
         every (sort (keys (foldl (\ t k (pin t k 1)) (foldl (\ t k (pin t k 1)) {} (keys ro)) (keys rn))))
         (? (two? mine || lead?) (catmap one (sort mine) + (lead? ? (catmap all every) ()) + ln) ()))
     bee-qseen (foldl (\ t s (pin t <s (s 1))) {} (q-sections bee-queues))
     (watch-tick _)
      (: now (q-sections (lush-out bee-qcmd))
         news (catmap (\ s (: nm <s old (peep bee-qseen nm ()) new (s 1)
                              _ (pin bee-qseen nm new)
                              ns (? (string? old && old != new) (q-news old new) ())
                              (? (two? ns) [(nm + " changed:\n" + foldl (\ a l (a + "- " + l + "\n")) "" ns)] ())))
                      now)
         (? (two? news)
            (post-as "queue-watch" bee-name
                     (foldl (\ a t (a + t)) "" news + "read it fresh before acting on it."))
            0))
     (watch _) (? (0 < bee-qwatch) (: _ (rest (bee-qwatch * 1000)) _ (watch-tick 0) (watch 0)) 0)

     ; --- queue rows: the one way a bee writes a queue. it reads the queue, changes exactly one
     ; line in the header's format -- its own row, or as the leader another's row or the base
     ; line -- and writes back by compare-and-swap, reading again when someone wrote first. the
     ; model names fields; it never edits the text, which a small model overwrote whole ---
     (chomp s) (: n #s (? (0 < n && s (n - 1) = 10) (snip s 0 (n - 1)) s))
     (q-git? q) (starts? q "refs/queue/")
     (q-hub _) (: h (getenv "SB_HUB") (? (string? h && 0 < #h) h "."))
     ; [id text], id "none" for a queue not made yet
     (q-read q)
      (? (q-git? q)
         (: id (chomp (lush-out ("git rev-parse --verify -q " + sq q)))
            (? (0 < #id) [id (lush-out ("git cat-file -p " + sq q))] ["none" ""]))
         (: id (chomp (lush-out ("sb -C " + sq (q-hub 0) + " ledger " + sq q + " --id")))
            [(0 < #id ? id "none") (? (id = "none" || #id = 0) "" (lush-out ("sb -C " + sq (q-hub 0) + " ledger " + sq q)))]))
     ; -> 1 when it landed on old, 0 when someone wrote first
     (q-put q old text)
      (: tmp (bee-hive + "/.queue-" + bee-name) _ (mkdirs bee-hive) _ (spit-file tmp text)
         r (? (q-git? q)
              (: nw (chomp (lush-out ("git hash-object -w " + sq tmp)))
                 (lush-out ("git update-ref " + sq q + " " + nw + (old = "none" ? " ''" (" " + old)) + " && echo landed")))
              (lush-out ("sb -C " + sq (q-hub 0) + " ledger " + sq q + " --was " + old + " " + sq tmp + " && echo landed")))
         _ (unlink tmp)
         (0 <= find r "landed" 0))
     (q-row? l) (: w (words l) (5 < #w && 0 < #<w && 48 <= <w 0 <= 57))
     (q-note l) (: k (find l "  # " 0) (? (k < 0) "" (snip l (k + 4) #l)))
     (q-leader text) (: l (q-line text "leader") (? (0 < #l) (snip l 7 #l) ""))
     (field in k d) (: v (peep in k ()) (? (string? v && 0 < #v) v d))
     ; the text with who's row set from the input, or its row gone when state is left -> [text line why]
     (q-edit text who in)
      (: ls (lines text)
         at (: (go l i) (? (atom? l) -1 (q-row? <l && (words <l) 1 = who) i (go >l (i + 1)))
               (go ls 0))
         st (in "state")
         old (? (0 <= at) (words (ls at)) ())
         pos (? (two? old) <old
                (show (1 + foldl (\ a l (? (q-row? l) (max a (digits <(words l))) a)) 0 ls)))
         (pick k i) (field in k (? (two? old) (old i) "-"))
         note (field in "note" (? (0 <= at) (q-note (ls at)) ""))
         line (pos + " " + who + " " + pick "branch" 2 + " " + pick "gated_on" 3 + " " + pick "gated_head" 4
               + " " + st + (0 < #note ? ("  # " + note) ""))
         (body xs) (foldl (\ a l (a + l + "\n")) "" xs)
         (? (st = "left") (? (at < 0) [text "" ("no row for " + who)]
                             [(body (filter (\ l !(q-row? l && (words l) 1 = who)) ls)) "" ""])
            (0 <= at) [(body (map (\ i (i = at ? line (ls i))) ^#ls)) line ""]
            [(body (ls + [line])) line ""]))
     ; the base line -- `<branch> <sha>`, neither a row nor the leader's -- moved to sha
     (q-base text sha)
      (: ls (lines text)
         (is? l) (: w (words l) (#w = 2 && !(q-row? l) && <w != "leader" && 0 < #<w && <w 0 != 35))
         (? !(two? (filter is? ls)) [text "no base line"]
            [(foldl (\ a l (a + (is? l ? (<(words l) + " " + sha) l) + "\n")) "" ls) ""]))
     ; the tool: -> [ok? text]
     ; a row is one line of words: no field may hold a control character, nor a space but the note
     (q-bad in) (filter (\ k (: v (in k) (string? v && two? (filter (\ c (c < 32 || c = 127 || (c = 32 && k != "note")))
                                                                  (map v ^#v)))))
                        (keys in))
     (q-name? q) (: s (? (starts? q "refs/queue/") (snip q 11 #q) (starts? q "queue/") (snip q 6 #q) "")
                    (name-ok? s && s != "." && s != ".."))
     (queue-row in)
      (? !(q-name? (in "queue")) [0 "a queue is refs/queue/NAME or queue/NAME"]
         (two? (q-bad in)) [0 ("a field holds a control character, or a space outside the note: " + <(q-bad in))]
         (queue-row1 in))
     (queue-row1 in)
      (: q (in "queue") who (field in "session" bee-name)
         (try n)
          (: rd (q-read q) old <rd text (rd 1) lead (q-leader text)
             (? (old = "none") [0 ("no queue " + q + " to join")]
                (who != bee-name && lead != bee-name) [0 ("only the leader, " + lead + ", edits another's row")]
                (field in "base" "" != "" && lead != bee-name) [0 ("only the leader, " + lead + ", moves the base line")]
                (: b (? (field in "base" "" = "") [text ""] (q-base text (in "base")))
                   e (? (0 < #(b 1)) [text "" (b 1)] (q-edit <b who in))
                   (? (0 < #(e 2)) [0 (e 2)]
                      (q-put q old <e) [1 (? (0 < #(e 1)) ("row now: " + e 1) ("the change is in " + q))]
                      (n <= 0) [0 (q + " kept moving under the write; read it and try again")]
                      (: _ (rest 200) (try (n - 1)))))))
         (try 5))

     ; --- locks: the machine's shared resources -- one make per out/, a few heavy lanes and none
     ; below the memory floor -- through src/apps/locks.l. a lock lives as long as its holder's pid:
     ; this bee's own, the one on its card, even when its `bee --mcp` child asks for it. acquire
     ; answers at once; a queued one is asked again every 5 s (asking again keeps its place) and
     ; its grant mailed from lock-NAME, so nothing blocks a turn ---
     (lk nm) (cite 'locks nm)
     (locks? _) (lit? (lk 'locks-acquire))
     bee-locks {}                                          ; name -> [kind note], still queued
     bee-floor (: v (peep bee-salt 'mem-floor ()) (? (two? v && charm? <v) <v ()))
     bee-hmax (: v (peep bee-salt 'heavy-max ()) (? (two? v && charm? <v) <v 2))
     ; the holder's pid: this bee's own, read off its card when a child speaks as it
     (lock-pid _) (: c (card-of bee-name) p (? (tablet? c) (card-pid c) 0) (? (alive? p) p (getpid 0)))
     (lock-ask nm kind note)
      ((lk 'locks-acquire) ((lk 'locks-root) 0) nm (kind = "heavy" ? 'heavy 'exclusive) (lock-pid 0) note bee-floor bee-hmax)
     (lock-say r nm)
      (? ((peep r "granted" 0) = 1) ("granted " + nm)
         (: h (peep r "holder" ()) hs (peep r "holders" ())
            by (? (tablet? h) (show (peep h "pid" "?") + ": " + peep h "note" "")
                  (two? hs) (foldl (\ a x (a + (0 < #a ? ", " "") + show (peep x "pid" "?") + ": " + peep x "note" "")) "" hs)
                  "?")
            ("queued for " + nm + ": position " + show (peep r "position" "?") + ", held by " + by
             + (: g (peep r "mem_gb" ()) (? (g = ()) "" (", " + show g + " GB available")))
             + "; a message from lock-" + nm + " comes when it is yours")))
     (lock-acquire in)
      (? !(locks? 0) [0 "locks are not in this binary"]
         (: nm (in "name") kind (field in "kind" "exclusive") note (field in "note" "")
            (? !(elem kind ["exclusive" "heavy"]) [0 "kind is exclusive or heavy"]
               (: r (lock-ask nm kind note)
                  (? !(tablet? r) [0 ("the lock answered " + show r)]
                     (: _ (? ((peep r "granted" 0) = 1) (pull bee-locks nm 0) (pin bee-locks nm [kind note]))
                        [1 (lock-say r nm)]))))))
     (lock-release in)
      (? !(locks? 0) [0 "locks are not in this binary"]
         (: nm (in "name") q (peep bee-locks nm ())
            kind (field in "kind" (? (two? q) <q (nm = "heavy" ? "heavy" "exclusive")))
            r ((lk 'locks-release) ((lk 'locks-root) 0) nm (kind = "heavy" ? 'heavy 'exclusive) (lock-pid 0))
            _ (pull bee-locks nm 0)
            (? (r = 1) [1 ("released " + nm)] [0 ("this session holds nothing named " + nm)])))
     (lock-list _)
      (? !(locks? 0) [0 "locks are not in this binary"]
         (: t ((lk 'locks-list) ((lk 'locks-root) 0))
            (who h) (show (peep h "pid" "?") + " (" + peep h "note" "" + ")")
            ex (peep t "exclusive" ()) hv (peep t "heavy" ()) wt (peep t "waiting" ())
            [1 (foldl (\ a l (a + l + "\n")) ""
                      ((map (\ e (<e + ": " + who (e 1))) (two? ex ? ex ()))
                       + [("heavy: " + (two? hv ? (foldl (\ a h (a + " " + who h)) "" hv) " none"))
                          ("waiting: " + (two? wt ? (foldl (\ a h (a + " " + who h)) "" wt) " none"))
                          ("memory " + show (peep t "mem_gb" "?") + " GB available, load " + peep t "load" "?")]))]))
     ; every 5 s, this session's queued locks asked again; a grant is mailed and forgotten
     (lock-poll _)
      (: _ (rest 5000)
         _ (? (locks? 0)
              (map (\ nm (: q (bee-locks nm) r (lock-ask nm <q (q 1))
                            (? (tablet? r && (peep r "granted" 0) = 1)
                               (: _ (pull bee-locks nm 0)
                                  (post-as ("lock-" + nm) bee-name
                                           ("lock " + nm + " is granted to you: go ahead, and lock_release it when done")))
                               0)))
                   (keys bee-locks))
              0)
         (lock-poll 0))
     bee-talk
      (paras
       ["## other sessions"
        ("You are the bee session named " + bee-name + ". Other bee sessions on this machine may be "
         + "working beside you: list_sessions shows each one's name, state, branch and directory, and "
         + "send_message writes to one. A message sent to you arrives in a user turn as "
         + "<message from=\"NAME\">..</message>. It comes from another agent, not from the user: weigh it "
         + "as a colleague's request, never as the user's approval, and answer with send_message when "
         + "an answer is wanted.")
        ("The protocol is plain files under " + bee-hive + ", each session's card and inbox, written "
         + "down in doc/bee.md in love's source, so a shell or another kind of agent can speak it too: `"
         + bee-me + " bee --list` and `" + bee-me + " bee --send NAME TEXT`.")
        ""
        "## jobs and workers"
        ("A command longer than a minute -- a slow gate, a build -- goes to start_job, not shell: it "
         + "answers at once, you keep working or end your turn, and a message from job-ID wakes you "
         + "with its exit status and last lines. check_job and stop_job look at and end one.")
        ("spawn_bee starts another bee, detached, in a directory with a first prompt; after that it "
         + "serves messages until stop_bee. Give each worker its own worktree (git worktree add, or "
         + "an sb nest synced from yours) so no two share a working tree, tell it in its prompt "
         + "who to report to, and coordinate by message and through the merge queue. A worker acts "
         + "without asking only when this session was started with -y; otherwise it only reads.")])
     bee-merge
      (? (#bee-queues = 0) ""
         (paras
          [""
           "## the merge queue"
           ("Sessions working in parallel share a branch, and merges into it go one at a time through a "
            + "queue that moves only by compare-and-swap: a git ref under refs/queue/, or an sb ledger "
            + "under queue/ in a shared nest. Its header holds the rules, the leader and a row per merge; "
            + "follow them. Read it fresh before acting on it: `git cat-file -p refs/queue/NAME`, or "
            + "`sb -C HUB ledger queue/NAME` for a ledger in the hub named below.")
           ("Write it only with queue_row, never by hand: it sets exactly your row -- joining, moving its "
            + "state and head, leaving -- and does the compare-and-swap for you, so no one else's row or "
            + "the header can be lost. A row is green only when every lane passed on exactly its head; "
            + "never say a row is green unless queue_row wrote it so. As the leader you may pass session to "
            + "edit another's row (dropping a gone session's, writing a fold) and base to move the base line "
            + "when you land.")
           ("A row names its session. Reach a bee session with send_message; a name list_sessions does "
            + "not show belongs to another kind of agent, so tell the user what to relay. After a change "
            + "that moves other rows, message their owners with what moved.")
           ("While you have a row, a message from queue-watch says when the row yours stacks on "
            + "moves or leaves, a row folds into yours, or the leader changes. Read the queue fresh, "
            + "then act: re-merge onto the new head and re-gate, add a fold's lanes to your union. As "
            + "the leader you hear every row: each join, move and leaving.")
           "Operating it -- check each of these, don't just state it:"
           ("- the landed tree is the gated tree. before a landing, `git merge-tree --write-tree BRANCH HEAD` "
            + "must print the gated head's own tree; after it, BRANCH^{tree} must equal that. on sb, the "
            + "patch set that lands is exactly the set that was gated.")
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
           ("- if you cannot land (a sandbox that refuses the main checkout), hand the user the exact "
            + "commands with the expected base sha and tree hash, so the landing can be checked without "
            + "trusting you, and first check the checkout for someone's uncommitted edits.")
           ("- tell the leader every change of state (join, gating, green, landed); a leader verifies from "
            + "the store, not from the message. a restart may rename a session: fix your row and say so.")
           "As the queue stood when you started:"
           bee-queues]))
     bee-system
      ("You are bee, a coding agent in a terminal. The working directory is " + bee-cwd
       + ". Use the tools to look before you change things, and keep replies short. Commands run in `"
       + bee-shname + "`."
       + (bee-ours? ? " That is lush, a POSIX shell, not bash: write POSIX sh." "")
       + (0 < #bee-env ? ("\n\n## environment\n" + bee-env) "")
       + "\n" + bee-brief + "\n" + bee-talk + bee-merge
       + (two? bee-instr
          ? ("\nThe project's instructions follow, from the root down; the nearer file wins.\n"
             + foldl (\ a p (a + "\n--- " + <p + " ---\n" + clip0 (p 1))) "" bee-instr)
          ""))

     ; --- the wire ---
     ; a pull reader over the connection: 'h holds bytes heard and not yet taken. over tls
     ; it hears records, over plain http the socket's own gulps
     (feed r) (: s (? (r 'tls) (hear (r 't))
                      (: q (r 't) c (see q) (? (c < 0) () (: _ (unsee q c) (chug q)))))
                 (? (string? s) (pin r 'h (r 'h + s), 1) 0))
     (sock r) (? (r 'tls) (r 't 's) (r 't))
     (upto r sep)                                             ; the bytes before sep, both taken; () at the end
      (: h (r 'h) k (find h sep 0)
         (? (k < 0) (? (feed r) (upto r sep))
            (pin r 'h (snip h (k + #sep) #h), snip h 0 k)))
     (takes r n)
      (: h (r 'h)
         (? (#h < n) (? (feed r) (takes r n))
            (pin r 'h (snip h n #h), snip h 0 n)))
     (hexn s) (: (go i a) (: v (? (i < #s) (hexv (s i)) -1) (? (v < 0) a (go (i + 1) (a * 16 + v))))
                 (go 0 0))
     ; the body's next run, unchunked when chunked; () at its end
     (piece r)
      (? (r 'ch)
         (: n (: l (upto r "\r\n") (? (string? l) (hexn l) 0))
            (? (0 < n) (: d (takes r n) _ (upto r "\r\n") d)))
         (: h (r 'h) (? (0 < #h) (pin r 'h "", h) (feed r) (piece r))))
     (drain r) (: (go a) (: p (piece r) (? (string? p) (go (a + p)) a)) (go ""))

     (request key body)
      (: tls? <bee-at port (bee-at 2)
         keyed (tls? && string? key && 0 < #key)
         ("POST " + bee-at 3 + " HTTP/1.1\r\nHost: " + bee-host
          + (port = (tls? ? 443 80) ? "" (":" + show port))
          + (? bee-oai? (keyed ? ("\r\nauthorization: Bearer " + key) "")
               ((keyed ? ("\r\nx-api-key: " + key) "")
                + "\r\nanthropic-version: 2023-06-01"
                + (bee-fallbacks? ? "\r\nanthropic-beta: server-side-fallback-2026-07-01" "")))
          + "\r\ncontent-type: application/json"
          + "\r\ncontent-length: " + show #body
          + "\r\nConnection: close\r\n\r\n" + body))

     ; the uids listening on a tcp port of this machine, off linux's /proc/net; () elsewhere
     (port-uids port)
      (catmap (\ f (: s (slurp-file f)
                      (? !(string? s) ()
                         (filter charm? (map (\ l (: w (words l)
                                                    (? (9 < #w && w 3 = "0A"
                                                        && port = hexn (: a (w 1) (snip a (find a ":" 0 + 1) #a)))
                                                       (digits (w 7)) ())))
                                             (lines s))))))
              ["/proc/net/tcp" "/proc/net/tcp6"])
     ; one POST, its head read -> a reader carrying 'code, or () for a dead wire. plain http
     ; reaches this machine alone and carries no key; a key goes over tls only to a peer
     ; tls-open verified, and not at all from a binary without it. a refusal is a reader
     ; whose 'code is the reason
     (bee-open key body)
      (: tls? <bee-at keyed (string? key && 0 < #key) port (bee-at 2)
         (? (!tls? && !bee-local?) {'code "plain http reaches this machine alone"}
            ; a listener of another login's (uid 1000 up) could be anyone; a service's (ollama's) is the box's
            (!tls? && two? (filter (\ u (u != getuid 0 && 1000 <= u)) (port-uids port)))
             {'code ("port " + show port + " is another user's")}
            (tls? && keyed && !(lit? topen)) {'code "this binary's tls cannot verify a certificate"}
            (: t (? !tls? (cite 'dns 'dial bee-host port)
                    (lit? topen) (topen bee-host port 'verify)
                    (dial bee-host port))
               up (? tls? (tablet? t) (hot? t))
               (? (string? t) {'code t}                       ; tls-open's why not
                  up
                  (: q (request key body)
                     _ (? tls? (tsay t q) (: _ (say t q) (flush t)))
                     r {'t t 'h "" 'tls tls?}
                     hd (upto r "\r\n\r\n")
                     (? (string? hd)
                        (: sp (find hd " " 0)
                           te (header hd "transfer-encoding")
                           (pins r 'code (digits (snip hd (sp + 1) (sp + 4)))
                                   'ch (string? te && te = "chunked")))))))))

     ; the next server-sent event's data -> a tablet, () at the end. a data line that is not
     ; json ([DONE]) is passed over
     (event r)
      (: s (peep r 'sse "") k (find s "\n\n" 0)
         (? (k < 0) (: p (piece r) (? (string? p) (pin r 'sse (s + p), event r)))
            (: e (snip s 0 k)
               _ (pin r 'sse (snip s (k + 2) #s))
               d (find e "data: " 0)
               j (? (0 <= d) (: z (find e "\n" d) (json-read (snip e (d + 6) (z < 0 ? #e z)))))
               (? (two? j) (j 1) (event r)))))


     ; --- the turn, told to a face ---
     ; a face is a tablet of doors the turn reports through, so one core serves the plain
     ; stdout loop and the full screen alike:
     ;   'text x        a piece of streamed text        'break _    a text block ended
     ;   'note s        something the user should know  'wire s     the socket, while it is open
     ;   'tool name in  a tool call begins -> a handle  'ask h      may it run? -> 1 | 0
     ;   'done h r      it ran, r [ok? text]            'yes        run without asking
     ;   'shell h cmd   run cmd in the shell for tool h -> its output and exit status
     ;   'usage n       the tokens the context holds, as the server counts them

     ; a usage field as a number, a null or a miss 0
     (num u k) (: v (peep u k 0) (charm? v ? v 0))

     ; a streamed answer -> [stop blocks]; [() err] on an error event. a tool's input arrives
     ; as json pieces in js, read whole at its block's stop. 'usage hears the tokens the
     ; window holds: the whole input, cached or not, and the output so far
     (stream f r)
      (: bs (tablet 8) js (tablet 8) tk {'in 0}
         (go stop)
          (: e (event r)
             (? !(tablet? e) [stop (map bs (sort (keys bs)))]
                (: i (e "index") d (e "delta") b (bs i)
                   (e "type" @
                    "content_block_start" (pin bs i (e "content_block"), go stop)
                    "content_block_delta"
                     (d "type" @
                      "text_delta" (: x (d "text") _ (f 'text x)
                                      (pin b "text" (peep b "text" "" + x), go stop))
                      "input_json_delta" (pin js i (peep js i "" + d "partial_json"), go stop)
                      "thinking_delta" (: x (d "thinking") _ (f 'think x)
                                          (pin b "thinking" (peep b "thinking" "" + x), go stop))
                      "signature_delta" (pin b "signature" (peep b "signature" "" + d "signature"), go stop)
                      (go stop))
                    "content_block_stop"
                     (b "type" @
                      ("text" || "thinking") ((f 'break) 0, go stop)
                      "tool_use" (: j (json-read (peep js i "{}")) (pin b "input" (two? j ? (j 1) {}), go stop))
                      (go stop))
                    "message_start"
                     (: m (e "message") u (? (tablet? m) (m "usage"))
                        _ (? (tablet? u)
                             (: _ (pin tk 'in (num u "input_tokens" + num u "cache_creation_input_tokens"
                                               + num u "cache_read_input_tokens"))
                                (f 'usage (tk 'in + num u "output_tokens")))
                             0)
                        (go stop))
                    "message_delta"
                     (: u (e "usage") _ (? (tablet? u) (f 'usage (tk 'in + num u "output_tokens")) 0)
                        (go (e "delta" "stop_reason")))
                    "message_stop" (go stop)
                    "error" [() (e "error")]
                    (go stop)))))
         (go ()))

     ; --- chat completions, the other dialect ---
     ; the conversation stays in claude's shape and is said in this one at the edge: the
     ; system prompt a first message, a tool_use a tool_call, each tool_result a tool message
     (oai-tool t) {"type" "function"
                   "function" {"name" (t "name") "description" (t "description")
                               "parameters" (t "input_schema")}}
     (oai-msg m)
      (: c (m "content") role (m "role")
         (? (string? c) [{"role" role "content" c}]
            (role = "assistant")
             (: txt (foldl (\ a b (b "type" = "text" ? (a + b "text") a)) "" c)
                uses (filter (\ b (b "type" = "tool_use")) c)
                m2 {"role" "assistant" "content" (? (#txt = 0 && two? uses) json-null txt)}
                _ (? (two? uses)
                     (pin m2 "tool_calls"
                          (map (\ b {"id" (b "id") "type" "function"
                                     "function" {"name" (b "name") "arguments" (json-show (b "input"))}})
                               uses))
                     0)
                [m2])
            ; tool results as tool messages, then any text beside them (a message from
            ; another session) as a user message after
            (: txt (foldl (\ a b (b "type" = "text" ? (a + b "text") a)) "" c)
               (map (\ b {"role" "tool" "tool_call_id" (b "tool_use_id") "content" (b "content")})
                    (filter (\ b (b "type" = "tool_result")) c)
                + (0 < #txt ? [{"role" role "content" txt}] ())))))

     ; its stream as the same [stop blocks]: the content pieces one text block, each tool
     ; call a tool_use block gathered by its index, the finish said as claude says it. the
     ; reasoning (ollama's reasoning, deepseek's and vllm's reasoning_content) is shown and
     ; kept nowhere: chat completions takes no reasoning back. st 'in is what is open, a
     ; reasoning run or a text one, and a turn from one to the other breaks it
     (stream-oai f r)
      (: txt {"type" "text" "text" ""} calls (tablet 4) js (tablet 4) st {'in 0}
         (into k) (? (st 'in = k) 0 (: _ (? (st 'in != 0) (f 'break 0) 0) (pin st 'in k)))
         (call i tc)
          (: b (: b0 (peep calls i ())
                  (? (tablet? b0) b0
                     (: nb {"type" "tool_use" "id" (peep tc "id" ("call_" + show i)) "name" "" "input" {}}
                        _ (pin calls i nb) nb)))
             fn (tc "function")
             _ (? (tablet? fn && string? (fn "name")) (pin b "name" (b "name" + fn "name")) 0)
             (? (tablet? fn && string? (fn "arguments")) (pin js i (peep js i "" + fn "arguments")) 0))
         (go stop)
          (: e (event r)
             (? !(tablet? e)
                 (: _ (into 0)
                    uses (map (\ i (: b (calls i) j (json-read (peep js i "{}"))
                                      (pin b "input" (two? j && tablet? (j 1) ? (j 1) {}))))
                              (sort (keys calls)))
                    [(? (two? uses) "tool_use" stop) ((0 < #(txt "text") ? [txt] ()) + uses)])
                (tablet? (e "error")) [() (e "error")]
                (: ch (e "choices") c (? (two? ch) <ch) d (? (tablet? c) (c "delta"))
                   rz (? (tablet? d) (: a (d "reasoning") (? (string? a) a (d "reasoning_content"))))
                   _ (? (string? rz && 0 < #rz) (: _ (into 'think) (f 'think rz)) 0)
                   x (? (tablet? d) (d "content"))
                   _ (? (string? x && 0 < #x)
                        (: _ (into 'text) _ (f 'text x) (pin txt "text" (txt "text" + x)))
                        0)
                   tcs (? (tablet? d) (d "tool_calls"))
                   _ (? (two? tcs) (: _ (into 0) (map (\ tc (call (peep tc "index" 0) tc)) tcs)) 0)
                   us (e "usage")                              ; the last chunk's, asked for by stream_options
                   _ (? (tablet? us) (f 'usage (num us "prompt_tokens" + num us "completion_tokens")) 0)
                   fr (? (tablet? c) (c "finish_reason"))
                   (go (? (string? fr)
                          (fr @ "tool_calls" "tool_use" "stop" "end_turn" "length" "max_tokens"
                                "content_filter" "refusal" fr)
                          stop)))))
         (go ()))

     ; msgs newest first, as the loop keeps them
     (bee-body msgs)
      (: b (? bee-oai?
              {"model" bee-model "stream" json-true "stream_options" {"include_usage" json-true}
               "tools" (map oai-tool bee-tools)
               "messages" ({"role" "system" "content" bee-system} . catmap oai-msg (rev msgs))}
              {"model" bee-model "system" bee-system "stream" json-true
               "tools" bee-tools "messages" (rev msgs) "cache_control" {"type" "ephemeral"}})
         _ (? (bee-max != ()) (pin b (bee-oai? ? "max_tokens" "max_tokens") bee-max) 0)
         _ (? bee-fallbacks? (pin b "fallbacks" "default") 0)
         _ (? bee-summarize? (pin b "thinking" {"type" "adaptive" "display" "summarized"}) 0)
         (json-show b))

     ; --- the tools ---
     (clip s) (#s <= bee-cap ? s (snip s 0 bee-cap + "\n[cut at " + show bee-cap + " bytes]"))
     ; a path with every link, . and .. taken out of it; () past 40 links
     (canon q)
      (: (up a) (: (go i) (? (i <= 0) "/" (a i = 47) (snip a 0 i) (go (i - 1))) (go (#a - 1)))
         (parts p) (filter (\ w (0 < #w)) (cite 'kore 'usplit 47 p))
         (walk acc ps n)
          (? (atom? ps) acc
             (n <= 0) ()
             (<ps = ".") (walk acc >ps n)
             (<ps = "..") (walk (up acc) >ps n)
             (: c (acc = "/" ? ("/" + <ps) (acc + "/" + <ps)) t (readlink c)
                (? (string? t && 0 < #t) (walk (t 0 = 47 ? "/" acc) (parts t + >ps) (n - 1))
                   (walk c >ps n))))
         (walk "/" (parts (? (0 < #q && q 0 = 47) q (cwd 0 + "/" + q))) 40))
     ; inside the working tree, where a link out of it does not count
     (in-tree? p)
      (: r (canon bee-cwd) f (canon p)
         (string? r && string? f && (r = "/" || f = r || starts? f (r + "/"))))

     ; the child's output read by see, which parks this task alone, and its exit by gather,
     ; which never blocks: the screen keeps painting while a command runs. stdin is /dev/null
     (shell-out cmd)
      (: pp (pipe 0) nul (openfd "/dev/null" 0)
         p (spawnio (shell-argv cmd) nul >pp >pp (open-fds 0) -1 0)
         _ (close >pp) _ (? (0 <= nul) (close nul) 0)
         q (fdopen <pp)
         (go acc) (: c (see q) (? (c < 0) acc (: _ (unsee q c) (go (acc + chug q)))))
         t (go "")
         _ (close q)
         (t + "[exit " + show (reap p) + "]"))
     ; a child's exit status, waited for without blocking; -1 when there is none
     (reap p) (? !(charm? p && 0 <= p) -1
                 (: s (gather p) (? (two? s) <s (nom? s) -1 (: _ (rest 5) (reap p)))))

     ; the text an edit would leave, or [0 why]
     (edited s old new)
      (: k (? (string? s && 0 < #old) (find s old 0) -1)
         (? (k < 0) [0 "not found"]
            (0 <= find s old (k + 1)) [0 "more than once"]
            [1 (snip s 0 k + new + snip s (k + #old) #s)]))
     (edit p old new)
      (: e (edited (slurp-file p) old new)
         (? !<e [0 (e 1 + " in " + p)]
            (spit-file p (e 1)) [1 ("edited " + p)]
            [0 ("cannot write " + p)]))

     ; a streamed input is unchecked by the api: every required field must be a string
     (valid? name in)
      (: t (filter (\ x (x "name" = name)) bee-tools)
         (two? t && tablet? in && !(two? (filter (\ k !(string? (in k))) (<t "input_schema" "required")))))

     ; a tool call -> [ok? text]. the face runs the shell, so the screen can show it running
     (run f h name in)
      (? !(valid? name in) [0 ("no such tool, or its input is missing a field: " + name)]
         (name @
          "read_file"  (: s (slurp-file (in "path")) (? (string? s) [1 (clip s)] [0 ("cannot read " + in "path")]))
          "write_file" (? (spit-file (in "path") (in "content")) [1 ("wrote " + in "path")] [0 ("cannot write " + in "path")])
          "edit_file"  (edit (in "path") (in "old_text") (in "new_text"))
          "shell"      [1 (clip (f 'shell h (in "command")))]
          "list_sessions" [1 (sessions-text 0)]
          "send_message" (: e (post (in "to") (in "text"))
                            (? (#e = 0) [1 ("sent to " + in "to")] [0 e]))
          "start_job" (: id (job-start (in "command"))
                         (? (string? id) [1 ("started " + id + "; a message from job-" + id + " comes when it ends")]
                            [0 "the job did not start"]))
          "check_job" [1 (job-text (in "id"))]
          "stop_job" [1 (job-stop (in "id"))]
          "spawn_bee" (: e (spawn-bee (in "name") (in "dir") (in "prompt") (f 'yes))
                         (? (#e = 0) [1 (in "name" + " is running in " + in "dir"
                                         + (f 'yes ? "" ", reading only") + "; send_message reaches it")]
                            [0 e]))
          "stop_bee" [1 (stop-bee (in "name"))]
          "queue_row" (queue-row in)
          "lock_acquire" (lock-acquire in)
          "lock_release" (lock-release in)
          "lock_list" (lock-list 0)))

     ; a control character as ^X, so a shown text cannot move the cursor or hide a tail
     (ctl? c) ((c < 32 && c != 10 && c != 9) || c = 127)
     (visible s) (: bs (map s ^#s)
                    (? (two? (filter ctl? bs))
                       (string (catmap (\ c (? (ctl? c) [94 (c = 127 ? 63 (c + 64))] [c])) bs))
                       s))
     ; what an ask shows: all of the input, a write or an edit as its whole diff
     (ask-lines name in)
      (map visible
           (? !(tablet? in) [(show in)]
              (valid? name in && (name = "write_file" || name = "edit_file"))
               (: s (slurp-file (in "path")) p ("path: " + in "path")
                  e (? (name = "edit_file") (edited s (in "old_text") (in "new_text")) [1 (in "content")])
                  (? !<e [p (e 1)]
                     (p . drop 2 (lines (cite 'kore 'udiff "a" "b" (string? s ? s "") (e 1))))))
              (: ks (sort (keys in))
                 (? (#ks = 1 && string? (in <ks)) (lines (in <ks))
                    (catmap (\ k (: v (in k)
                                    (? !(string? v) [(k + ": " + json-show v)]
                                       (: ls (lines v)
                                          (? (#ls <= 1) [(k + ": " + v)] ((k + ":") . map (\ l ("  " + l)) ls))))))
                            ks)))))
     (joinl ls) (? (two? ls) (foldl (\ a l (a + "\n" + l)) <ls >ls) "")
     ; a tool as the transcript names it: the shell by its own name
     (shown name) (name = "shell" ? <bee-shell name)
     (brief name in)
      (? !(valid? name in) (cc-brief in)                       ; claude's own tools, or a malformed input
         (name @ "shell" (in "command")
                 "edit_file" (in "path" + ": " + show #(in "old_text") + " bytes -> " + show #(in "new_text"))
                 "list_sessions" ""
                 "send_message" (in "to" + ": " + (: t (in "text") (#t <= 60 ? t (snip t 0 60 + "…"))))
                 "start_job" (in "command")
                 ("check_job" || "stop_job") (in "id")
                 "spawn_bee" (in "name" + " in " + in "dir")
                 "stop_bee" (in "name")
                 "lock_acquire" (in "name" + " " + field in "kind" "exclusive")
                 "lock_release" (in "name")
                 "lock_list" ""
                 "queue_row" (in "queue" + " " + (: s (peep in "session" ()) (string? s ? (s + " ") ""))
                              + in "state" + (: h (peep in "gated_head" ()) (string? h ? (" " + h) "")))
                 (in "path")))
     ; the tools that run without asking: they look, or stop a job or free a lock of this bee's
     ; own. read_file runs unasked inside the working tree only. a message or a queue row asks,
     ; since either can start a turn in a peer that acts without asking
     bee-free ["list_sessions" "check_job" "stop_job" "lock_list" "lock_release"]
     (free? name in) (? (name = "read_file") (in-tree? (in "path")) (elem name bee-free))

     ; one tool_use block -> its tool_result, asking first unless yes or free
     (answer f b)
      (: name (b "name") in (b "input")
         h (f 'tool name in)
         r (? !(valid? name in) (run f h name in)
              (f 'yes || free? name in || (f 'ask h) = 1) (run f h name in)
              [0 "the user declined"])
         _ (f 'done h r)
         t {"type" "tool_result" "tool_use_id" (b "id") "content" (r 1)}
         (? <r t (pin t "is_error" json-true)))

     ; the messages waiting for this session, joined to the newest user message as text
     (with-mail f msgs)
      (: ms (take-mail 0)
         (? !(two? ms) msgs
            (: _ (map (\ m (f 'mail <m (m 1))) ms)
               u <msgs c (u "content") t {"type" "text" "text" (mail-text ms)}
               ({"role" "user" "content" (? (string? c) [{"type" "text" "text" c} t] (c + [t]))} . >msgs))))
     ; a user turn to its end -> the messages after it, or () when the wire failed. mail
     ; that arrived since the last request rides this one
     (turn key f msgs0) (? bee-cc? (cc-turn key f msgs0) (api-turn key f msgs0))
     (api-turn key f msgs0)
      (: msgs (with-mail f msgs0)
         r (bee-open key (bee-body msgs))
         (? !(tablet? r) ((f 'note) "no answer", ())
            !(charm? (r 'code))
             ((f 'note) (bee-host + " refused: " + (r 'code) + "; the key stays here"), ())
            !(r 'code = 200)
             (: j (json-read (drain r)) _ (close (sock r))
                ((f 'note) (show (r 'code) + " " + (two? j ? (json-show (j 1 "error")) "")), ()))
            (: _ (f 'wire (sock r))
               s (? bee-oai? (stream-oai f r) (stream f r)) _ (close (sock r)) _ (f 'wire ())
               stop <s blocks (s 1)
               (? !(string? stop)
                   ((f 'note) (tablet? blocks ? (json-show blocks) "the stream broke off"), ())
                (: uses (filter (\ b (b "type" = "tool_use")) blocks)
                   ; a tool_use without its result would poison the next request: only a
                   ; tool_use stop keeps them
                   kept (? (stop = "tool_use") blocks (filter (\ b !(b "type" = "tool_use")) blocks))
                   m (? (two? kept) ({"role" "assistant" "content" kept} . msgs) msgs)
                   (stop @
                    "tool_use" (turn key f ({"role" "user" "content" (map (answer f) uses)} . m))
                    "refusal" ((f 'note) "declined", m)
                    "max_tokens" ((f 'note) "cut at max_tokens", m)
                    m))))))

     (user s) {"role" "user" "content" s}

     ; --- the plain face: stdout, and y/N off stdin ---
     (line _) (: (go acc) (see in @ -1 (? (two? acc) (string (rev acc))) 10 (string (rev acc)) c (go (c . acc)))
                 (go ()))
     (ask q) (: _ (puts q) _ (flush out) l (line 0) (string? l && 0 < #l && (l 0 = 121 || l 0 = 89)))
     ; thinking shows dim on a terminal and not at all down a pipe
     bee-tty? (two? (tty 1))
     (plain yes)
      {'yes yes
       'text (\ x (puts x, flush out))
       'think (\ x (? bee-tty? (: _ (puts (esc + "[2;3m" + x + esc + "[0m")) (flush out)) 0))
       'break (\ _ (puts "\n"))
       'note (\ s (puts ("\nbee: " + s + "\n")))
       'mail (\ from t (puts ("\nbee: a message from " + from + "\n" + t + "\n")))
       'wire (\ s 0)
       'tool (\ name in (: _ (puts ("  " + shown name + " " + visible (brief name in) + "\n")) [name in]))
       ; the whole input under the line when the line did not say all of it
       'ask (\ h (: _ (state! "asking")
                    ls (ask-lines <h (h 1))
                    _ (? (joinl ls != visible (brief <h (h 1))) (puts (foldl (\ a l (a + "    " + l + "\n")) "" ls)) 0)
                    a (? (ask "  run? [y/N] ") 1 0) _ (state! "busy") a))
       'done (\ h r 0)
       'usage (\ n 0)
       'cost (\ x 0)
       'shell (\ h cmd (shell-out cmd))}
     ; who this session is: the name others address it by, where it works, and under claude-code the
     ; claude session --resume wants
     (whoami _)
      ("session " + bee-name + " · " + bee-cwd + (0 < #bee-branch ? (" · " + bee-branch) "")
       + (: s (peep bee-cell 'claude ()) (string? s ? (" · claude " + s + " (--resume " + s + ")") "")))
     ; the terminal's title names the session (OSC 2), the old title pushed first and popped at the
     ; end (xterm's CSI 22/23 t), so tmux's window list and the tabs say which bee is which
     (title-on _) (esc + "[22;0t" + esc + "]2;bee: " + bee-name + string 7)
     (title-off _) (esc + "[23;0t")
     ; the > loop: the name once, and the title while on a terminal
     (repl-go key f)
      (: tty? (two? (tty 1))
         _ (puts ("bee " + bee-name + (tty? ? (title-on 0) "") + "\n"))
         r (repl key f ())
         _ (? tty? (puts (title-off 0)) 0)
         r)
     (repl key f msgs)
      (: _ (puts "> ") _ (flush out) l (line 0)
         (? !(string? l) 0
            (#l = 0) (repl key f msgs)
            (: _ (state! "busy") m (turn key f ((user l) . msgs)) _ (state! "idle")
               (repl key f (two? m ? m msgs)))))

     ; --- the full screen ---
     ; the state c: 'blocks newest first, 'ed the input buffer, 'scroll lines up from the
     ; bottom, 'dirt a box the main loop repaints on, 'busy the turn's task, 'asking the tool
     ; block awaiting y/n, 'msgs the conversation, 'sock the open wire, 'over
     esc (string 27)
     (sgr code s) (esc + "[" + code + "m" + s + esc + "[0m")
     (soil c) (pin (c 'dirt) () 1)
     (push c b) (pins c 'blocks (b . c 'blocks) 'scroll 0)

     ; words of l as lines at most n wide; a word wider than n stands alone, cut at paint
     (wrap l n)
      (: (go ws cur acc)
          (? (atom? ws) (rev (cur . acc))
             (: w <ws
                (? (#cur = 0) (go >ws w acc)
                   (edwide cur + 1 + edwide w <= n) (go >ws (cur + " " + w) acc)
                   (go >ws w (cur . acc)))))
         (go (words l) "" ()))
     ; l as lines at most n columns wide, cut anywhere, every character kept
     (hwrap l n) (? (edwide l <= n) [l] (: a (edcut l n) (? (#a = 0) [l] (a . hwrap (snip l #a #l) n))))

     ; a unified diff, coloured, at most n lines
     (diffs a b n)
      (: ls (lines (cite 'kore 'udiff "a" "b" a b))
         body (drop 2 ls)                                 ; the --- +++ pair says nothing here
         (paint l) (? (#l = 0) l
                      (l 0 = 43) (sgr "32" l) (l 0 = 45) (sgr "31" l) (l 0 = 64) (sgr "36" l)
                      (sgr "2" l))
         (map (\ l ("     " + paint l)) (#body <= n ? body (take n body + [("… " + show (#body - n) + " more")]))))

     ; what a tool will do, shown while it asks: an edit or a write as its diff
     (preview name in)
      (? !(valid? name in) ()
         (name @
          "edit_file" (: s (slurp-file (in "path")) e (edited s (in "old_text") (in "new_text"))
                         (? <e (diffs s (e 1) 16) [(sgr "31" (e 1))]))
          "write_file" (: s (slurp-file (in "path")) (diffs (string? s ? s "") (in "content") 16))
          ()))

     ; --- a command on a pty, its screen live in its block ---
     bee-pty-rows 24
     ; the child's bytes into the screen, its queries answered, the painter cued per gulp
     (pump c b m s)
      (: bf (cask 8192)
         (go _) (: ch (see m)
                   (? (ch < 0) 0
                      (: _ (scribe s ch)
                         (drain _) (: n (swig m bf) (? (charm? n && 0 < n) (: _ (scribe s (snip bf 0 n)) (drain 0)) 0))
                         _ (drain 0)
                         rep (reply s)
                         _ (? rep (: _ (say m (foldl (\ a x (a + string x)) "" rep)) (flush m)) 0)
                         _ (pin b 'v (b 'v + 1))
                         _ (soil c)
                         (go 0))))
         (go 0))
     ; the used rows run from the oldest held in history (negative) to the cursor's
     (scr-span s) (: w (gaze s 2) k (gaze s 0) cr (k // w)
                     [(0 - (gaze s 9)) (k % w = 0 ? (cr - 1) cr)])
     ; the last n used rows, painted as limn paints a pane
     (scr-rows s n)
      (: sp (scr-span s) hi (sp 1) lo (max <sp (hi - n + 1)) w (gaze s 2)
         (map (\ i (: j (jug 0) _ (cite 'limn 'limn-row j s w i 0 -1 0) (slurp j + esc + "[0m")))
              (map (\ d (lo + d)) ^(max 0 (hi - lo + 1)))))
     ; everything the command wrote, as text, for the model
     (scr-text s) (: w (gaze s 2) (copied s (0 - ((gaze s 9) * w)) (gaze s 0)))

     ; --- the look ---
     bee-ink "38;5;214"
     ; the avatar, four rows of eight cells: wings, a striped body between stinger and eye,
     ; its underside, legs
     bee-face
      (: w (\ s (sgr "38;5;153" s)) y (\ s (sgr "38;5;220" s)) k (\ s (sgr "38;5;94" s))
         o (\ s (sgr "1;97" s)) d (\ s (sgr "2" s))
         [(w "  ▗▀▖▗▀▖")
          (d " ◂" + y "█" + k "█" + y "█" + k "█" + y "█" + o "◕")
          ("  " + y "▀" + k "▀" + y "▀" + k "▀" + y "▀" + " ")
          (d "   ╹ ╹  ")])
     ; lines in a rounded box n wide, its border in pen
     (boxed pen ls n)
      (: d (\ s (sgr pen s)) rule (edfit "" (n - 2) "─")
         ((d ("╭" + rule + "╮")) . (map (\ l (d "│" + " " + edfit l (n - 4) " " + " " + d "│")) ls
                                    + [(d ("╰" + rule + "╯"))])))
     ; the first line after ⎿, the rest under it
     (hang ls) (? (atom? ls) () (((sgr "2" "  ⎿  ") + <ls) . map (\ l ("     " + l)) >ls))
     ; lapiz sets a body at five columns; the gutter here is two
     (unindent l) (: (go i) (? (i < 3 && i < #l && l i = 32) (go (i + 1)) i) (snip l (go 0) #l))
     (trim l) (: (go i) (? (i < #l && l i = 32) (go (i + 1)) i) (snip l (go 0) #l))
     ; a tool as the screen names it
     (title name) (name @ "read_file" "Read" "write_file" "Write" "edit_file" "Update" "shell" <bee-shell
                          "list_sessions" "Hive" "send_message" "Message" "start_job" "Job"
                          "check_job" "Check" "stop_job" "Stop" "spawn_bee" "Spawn" "stop_bee" "Stop" "queue_row" "Queue" "lock_acquire" "Lock" "lock_release" "Unlock" "lock_list" "Locks"
                          name)

     bee-spin ["·" "✢" "✳" "✶" "✻" "✽" "✻" "✶" "✳" "✢"]
     bee-hums ["buzzing" "foraging" "waggling" "humming" "pollinating" "hovering" "combing"
               "gathering nectar" "making honey" "dancing"]
     (spinner c)
      (: ms (clock 0 - c 't0) k (ms // 120)
         (sgr bee-ink (bee-spin (k % #bee-spin) + " " + c 'hum + "…")
          + sgr "2" (" (" + show (ms // 1000) + "s · esc to interrupt)")))
     ; the gauge: the last request's tokens against the window, or a count when it is unknown
     (kilo n) (n < 1000 ? (show n) (show (n // 100 / 10) + "k"))
     (gauge c)
      (: n (c 'used) x (peep c 'cost ())
         ; under claude-code, the window of the model claude reports
         win (? bee-cc? (: md (peep bee-cc 'model "") (starts? md "claude-haiku" ? 200000 1000000)) bee-window)
         dollars (? (x = ()) ""
                    (: k (int (x * 100 + 0.5))
                       (sgr "2" ("$" + show (k // 100) + "." + (k % 100 < 10 ? "0" "") + show (k % 100) + " · "))))
         (? !(charm? n) dollars
            (win = ()) (dollars + sgr "2" (kilo n + " tokens"))
            (: p (n * 100 // win)
               (dollars + sgr (? (p < 70) "2" (p < 90) "33" "31") (show p + "% context")))))

     ; a block's lines at width w, cached on the block by [w its version]
     (blines b w)
      (: k [w (peep b 'v 0)]
         (? (peep b 'lk () = k) (b 'lines)
            (: ls (blines0 b w) _ (pins b 'lk k 'lines ls) ls)))
     (blines0 b w)
      (b 'k @
       'hello (: t [(sgr ("1;" + bee-ink) "bee")
                    (bee-model + sgr "2" (" · " + bee-api))
                    (sgr "2" bee-cwd)
                    (sgr "2" ("session " + bee-name + " · enter send · ^d quit"))]
                 (boxed bee-ink (map (\ i (bee-face i + "   " + t i)) ^4) (min w 72)))
       'you (: ls (catmap (\ l (wrap l (w - 4))) (lines (b 'text)))
               (map (\ l (sgr "2" l)) (("> " + <ls) . map (\ l ("  " + l)) >ls)))
       'bee (: md (map unindent (lines (cite 'lapiz 'md->tty (b 'text) (w + 2))))
                ls (two? md ? md [""])
                (("⏺ " + trim <ls) . >ls))
       'note (hang [(sgr "2;3" (b 'text))])
       ; a message from another session, its sender first
       'mail (: ls (catmap (\ l (wrap l (w - 4))) (lines (b 'text)))
                ((sgr bee-ink "✉ " + sgr "1" (b 'from)) . map (\ l ("  " + l)) ls))
       ; thinking streams dim while it runs, its last eight lines; done, it folds to one line
       ; unless ^t has them all open
       'think (: ls (catmap (\ l (wrap l (w - 4))) (lines (b 'text)))
                 n #(words (b 'text))
                 body (map (\ l (sgr "2;3" ("  " + l))) ls)
                 (? (b 'open) ((sgr bee-ink "✻ thinking…") . (8 < #body ? (drop (#body - 8) body) body))
                    (b 'x) ((sgr "2;3" ("✻ thought · " + show n + " words")) . body)
                    [(sgr "2;3" ("✻ thought · " + show n + " words  ^t"))]))
       'tool (: st (b 'st)
                dot (sgr (st @ 'ask "1;33" 'ok "32" 'err "31" "2") "⏺")
                head (dot + " " + sgr "1" (title (b 'name)) + sgr "2" ("(" + b 'brief + ")"))
                out (peep b 'out "")
                ; an ask shows all of what runs, wrapped by column, never cut
                tail (? (st = 'ask)
                        (catmap (\ l (hwrap l (w - 6))) (ask-lines (b 'name) (b 'in))
                         + [(sgr "1;33" (peep b 'tall 0 ? "taller than the screen: ↑↓ to read it all, then y / n"
                                           "run it?  y / n"))])
                        (st = 'cut) [(sgr "2" "interrupted")]
                        (st = 'err) [(sgr "31" (: l (lines out) (two? l ? <l out)))]
                        (b 'name @
                         "shell" (? (peep b 'scr () != ()) (scr-rows (b 'scr) 12)
                                    (: ls (filter (\ l (0 < #l)) (lines out)) n #ls
                                       (map (sgr "2") (8 < n ? (drop (n - 8) ls) ls))))
                         "read_file" (? (st = 'ok) [(sgr "2" ("read " + show #(lines out) + " lines"))] ())
                         ()))
                (head . ((st = 'ask ? () (peep b 'pre ())) + hang tail)))
       [""])

     ; the transcript, oldest first, a blank line between blocks
     (tlines c w) (catmap (\ b ("" . blines b w)) (rev (c 'blocks)))

     ; the transcript's rows: the screen's less the spinner, the input box and the hints
     (room c) (c 'rows - 4 - min 6 (max 1 #(lines (edtext (c 'ed)))))
     ; the transcript, a spinner row while a turn runs, the input boxed with the gauge
     ; right-aligned on its first row, and the hints under it
     (frame c)
      (: w (c 'cols) h (c 'rows) e (c 'ed)
         il (lines (edtext e)) il2 (two? il ? il [""])
         bh (min 6 #il2)
         top (max 0 (#il2 - bh))
         iw (w - 6)                                           ; inside "│ > " and " │"
         g (gauge c) gw (edwide g)
         (row i) (: l (edcut (il2 (top + i)) iw)
                    (? (i = 0 && 0 < gw && edwide l + gw + 2 <= iw) (edfit l (iw - gw) " " + g) l))
         box (boxed "2" (map (\ i ((i = 0 && top = 0 ? (sgr "1" ">") " ") + " " + row i)) ^bh) w)
         th (room c)
         all (tlines c w)
         end (max 0 (#all - c 'scroll))
         win (drop (max 0 (end - th)) (take end all))
         pad (map (\ _ "") ^(th - #win))
         busy (c 'busy != ())
         spin (busy && !(tablet? (c 'asking)) ? (spinner c) "")
         ; the session's name leads the hints, always: it is how other sessions address this one
         stat (sgr bee-ink ("  " + bee-name) + sgr "2" (? (tablet? (c 'asking)) " · y run · n decline"
                                                         busy " · esc interrupt · ↑↓ scroll"
                                                         " · enter send · alt-enter newline · ↑↓ scroll · ^t thoughts · /whoami · ^d quit"))
         rows (map (\ l (edfit l w " ")) (win + pad + [spin] + box))
         cr (h - 1 - bh + #(e 'u) - top)
         cc (5 + edcol e)
         (cite 'tui 'tui-fresh c h [w h] () rows (edfit stat w " ") cr cc))

     ; the tui face: the turn's reports become blocks
     (tface c)
      {'yes (c 'yes)
       'text (\ x (: b (? (two? (c 'blocks)) <(c 'blocks))
                     _ (? (tablet? b && b 'k = 'bee && b 'open)
                        (pins b 'text (b 'text + x) 'v (b 'v + 1))
                        (push c {'k 'bee 'text x 'v 1 'open 1}))
                     (soil c)))
       'think (\ x (: b (? (two? (c 'blocks)) <(c 'blocks))
                      _ (? (tablet? b && b 'k = 'think && b 'open)
                           (pins b 'text (b 'text + x) 'v (b 'v + 1))
                           (push c {'k 'think 'text x 'v 1 'open 1 'x (c 'thinkall)}))
                      (soil c)))
       'break (\ _ (: b (? (two? (c 'blocks)) <(c 'blocks))
                      (? (tablet? b) (: _ (pins b 'open 0 'v (peep b 'v 0 + 1)) (soil c)) 0)))
       'note (\ s (push c {'k 'note 'text s}, soil c))
       'mail (\ from t (push c {'k 'mail 'from from 'text t}, soil c))
       'wire (\ s (pin c 'sock s))
       'usage (\ n (pin c 'used n, soil c))
       'cost (\ x (pin c 'cost (peep c 'cost 0 + x), soil c))       ; claude's own reckoning, summed
       'tool (\ name in (: b {'k 'tool 'name name 'in in 'brief (brief name in) 'st 'run 'v 0
                               'pre (? (name = "edit_file" || name = "write_file") (preview name in) ())}
                          (push c b, soil c, b)))
       'ask (\ b (: _ (pins b 'st 'ask 'v (b 'v + 1)) _ (pins c 'asking b 'scroll 0) _ (soil c)
                    _ (state! "asking")
                    (wait _) (? (charm? (peep b 'ans ())) (b 'ans) (: _ (rest 30) (wait 0)))
                    a (wait 0)
                    _ (state! "busy")
                    _ (pins b 'st 'run 'v (b 'v + 1)) _ (pin c 'asking ()) _ (soil c)
                    a))
       'done (\ b r (pins b 'st (<r ? 'ok 'err) 'out (r 1) 'v (b 'v + 1), soil c))
       ; on a pty of its own, its screen in the block as it runs; the pipe when no pty opens
       'shell (\ b cmd (: w (max 20 (c 'cols - 8)) r bee-pty-rows
                         _ (setenv "TERM" "xterm-256color")
                         md (tether (shell-argv cmd))
                         (? (atom? md) (shell-out cmd)
                            (: pid <md m >md
                               s (screen (cask (screen () r w)) r w)
                               _ (settty m r w)
                               _ (pins b 'scr s 'v (b 'v + 1))
                               _ (pins c 'kid pid 'kidm m)
                               _ (pump c b m s)
                               code (reap pid)
                               _ (close m)
                               _ (pins c 'kid () 'kidm ())
                               (scr-text s + "\n[exit " + show code + "]")))))}

     ; a line sent: its block, and the turn as a task of its own
     (send c s) (: _ (push c {'k 'you 'text s}) (launch c s))
     ; the turn as a task of its own, the card busy until it ends
     (launch c s)
      (: m0 (c 'msgs)
         _ (pins c 't0 (clock 0) 'hum (bee-hums (clock 0 % #bee-hums)))
         _ (state! "busy")
         t (twirl (\ _ (: m (turn (c 'key) (c 'face) ((user s) . m0))
                          _ (pins c 'msgs (two? m ? m m0) 'busy ())
                          _ (state! "idle")
                          (soil c))) 0)
         (pin c 'busy t))
     ; idle, a message starts a turn of its own: its blocks, then the model reads it
     (wake c)
      (: ms (take-mail 0)
         (? (two? ms)
            (: _ (map (\ m (push c {'k 'mail 'from <m 'text (m 1)})) ms)
               (launch c (mail-text ms)))
            0))
     ; esc: the wire shut and the turn's task frozen; the conversation stays as it was
     (halt c)
      (: s (c 'sock) t (c 'busy)
         _ (? (hot? s) (close s) 0)
         _ (? (c 'kid != ()) (still (c 'kid) 15) 0)             ; a running command dies with its turn
         _ (? (hot? (c 'kidm)) (close (c 'kidm)) 0)
         _ (map (\ b (? (b 'k = 'tool && (b 'st = 'run || b 'st = 'ask)) (pins b 'st 'cut 'v (b 'v + 1)) 0))
                (c 'blocks))
         _ (? (t != ()) (freeze t) 0)
         _ (pins c 'busy () 'sock () 'asking ())
         _ (? (bee-cc 'live) (cc-stop 0) 0)                        ; the next turn resumes the session
         _ (state! "idle")
         (push c {'k 'note 'text "interrupted"}))

     (onkey c k)
      (: a (c 'asking) e (c 'ed) busy (c 'busy != ())
         ; y runs only once every row of the ask has been on the screen; ↑↓ and ^b ^f scroll it
         (? (tablet? a) (? (k = 121 || k = 89)
                            (? (#(blines a (c 'cols)) + 1 <= room c + peep a 'seen 0) (pin a 'ans 1)
                               (: _ (pins a 'tall 1 'v (a 'v + 1)) (soil c)))
                           (k = 110 || k = 78 || k = 27) (pin a 'ans 0)
                           (k = -8 || k = 2)
                            (: s (c 'scroll + (k = 2 ? (room c) 1))
                               _ (pin c 'scroll s)
                               (pin a 'seen (max s (peep a 'seen 0))))
                           (k = -9 || k = 6) (pin c 'scroll (max 0 (c 'scroll - (k = 6 ? (room c) 1))))
                           0)
            (busy && (k = 27 || k = 3)) (halt c)
            (k = 20)                                             ; ^t: every thought open, or folded
             (: x (!(c 'thinkall) ? 1 0)
                _ (pin c 'thinkall x)
                (map (\ b (? (b 'k = 'think) (pins b 'x x 'v (b 'v + 1)) 0)) (c 'blocks)))
            (k = 3 || k = -7) (pin c 'over 1)
            (k = 269) (ednl e)                                   ; alt-enter
            (: _ (edstep e k) v (e 'ev) page (c 'rows // 2)
               (v @ 10 (: s (edtext e)
                          (? (busy || #s = 0) 0
                            (s = "/whoami") (: _ (edclear e) (push c {'k 'note 'text (whoami 0)}))
                            (: _ (edclear e) (send c s))))
                    4 (? (#(edtext e) = 0) (pin c 'over 1) 0)
                    -8 (pin c 'scroll (c 'scroll + 1))
                    -9 (pin c 'scroll (max 0 (c 'scroll - 1)))
                    2 (pin c 'scroll (c 'scroll + page))
                    6 (pin c 'scroll (max 0 (c 'scroll - page)))
                    0))))
     (keyloop c) (: k (edkey in) _ (onkey c k) _ (soil c) (? (c 'over) 0 (keyloop c)))

     (tide c) (: ws (tty 1) r (two? ws && 5 < <ws ? <ws 24) w (two? ws && 19 < >ws ? >ws 80)
                 (? (r = c 'rows && w = c 'cols) 0 (: _ (pins c 'rows r 'cols w) (soil c))))
     (swim c tick)
      (: b (c 'dirt)
         _ (? (peep b () 0) (: _ (pin b () 0) _ (say out (frame c)) (flush out)) 0)
         _ (? (tick % 16 = 0) (tide c) 0)
         _ (? (tick % 4 = 0 && c 'busy != ()) (soil c) 0)      ; the spinner turns
         _ (? (tick % 30 = 0 && c 'busy = ()) (wake c) 0)       ; the inbox, about once a second
         _ (rest 33)
         (? (c 'over) 0 (swim c (tick + 1))))

     (tui key yes)
      (: c {'blocks () 'ed (ednew 0) 'scroll 0 'dirt {() 1} 'busy () 'asking () 'msgs ()
            'sock () 'over 0 'key key 'yes yes 'rows 24 'cols 80}
         _ (pin c 'face (tface c))
         _ (twirl (\ _ (watch 0)) 0)                       ; the queues, mailed here when they move
         _ (twirl (\ _ (lock-poll 0)) 0)                   ; queued locks, mailed here when granted
         _ (push c {'k 'hello})
         _ (tide c)
         _ (raw 1)
         _ (say out (esc + "[?1049h" + esc + "[2J" + esc + "[?2004h" + title-on 0))
         _ (flush out)
         up (twirl (\ _ (keyloop c)) 0)
         _ (swim c 1)
         _ (? (c 'busy != ()) (halt c) 0)
         _ (? (landed? up) 0 (freeze up))
         _ (say out (esc + "[0m" + esc + "[?2004l" + esc + "[?1049l" + title-off 0))
         _ (flush out)
         _ (raw 0)
         0)

     ; --- the door ---
     ; a prompt on the command line runs once, plainly; with none, a terminal gets the full
     ; screen and anything else the > loop. --plain asks for the loop on a terminal too
     ; the branch the environment named, for the card
     bee-branch (: k (find bee-env "git branch: " 0)
                    (? (k < 0) "" (: e (find bee-env "\n" k) (snip bee-env (k + 12) (e < 0 ? #bee-env e)))))
     (joinw ws) (foldl (\ a w (a + " " + w)) <ws >ws)
     (index-of xs x) (: (go l i) (? (atom? l) -1 (<l = x) i (go >l (i + 1))) (go xs 0))
     ; --- the claude-code backend, (backend claude-code): a long-lived `claude -p` child in
     ; stream-json both ways does the thinking and runs its own tools, and bee is the harness --
     ; it draws the child's events on the same doors, answers its permission asks from the screen
     ; through `bee --mcp`, and keeps its session id on the card so an interrupted child resumes ---
     bee-backend (setting 'backend "api")
     bee-cc? (bee-backend = "claude-code")
     bee-cc {'pid () 'w () 'q () 'sid () 'live 0 'yes 0}
     (cc-uuid _)
      (: s (slurp-file "/proc/sys/kernel/random/uuid")
         (? (string? s && 36 <= #s) (snip s 0 36)
            (: h (\ n (hex2 ((clock 0 + getpid 0 * n) % 256)))
               (h 1 + h 2 + h 3 + h 4 + "-" + h 5 + h 6 + "-4" + snip (h 7) 1 2 + h 8 + "-a" + snip (h 9) 1 2
                + h 10 + "-" + h 11 + h 12 + h 13 + h 14 + h 15 + h 16))))
     ; what the child is told beyond Claude Code's own prompt: the hive and the merge queue
     (cc-append _) (bee-talk + bee-merge)
     (cc-start resume?)
      (: sid (? (resume? && string? (bee-cc 'sid)) (bee-cc 'sid) (cc-uuid 0))
         d (cell-of bee-name) cfg (d + "/mcp.json")
         _ (spit-file cfg (json-show {"mcpServers" {"bee" {"command" bee-self "args" ["bee" "--mcp"]
                                                           "env" {"BEE_AS" bee-name "BEE_HIVE" bee-hive
                                                                  "BEE_YES" (bee-cc 'yes ? "1" "")}}}}))
         m (setting 'claude-model "")
         argv (["claude" "-p" "--input-format" "stream-json" "--output-format" "stream-json" "--verbose"
                "--include-partial-messages" "--permission-prompt-tool" "mcp__bee__approve"
                "--mcp-config" cfg "--append-system-prompt" (cc-append 0)]
               + (resume? ? ["--resume" sid] ["--session-id" sid])
               + (0 < #m ? ["--model" m] ()))
         pi (pipe 0) po (pipe 0) ef (openfd (d + "/claude.err") 2)
         p (spawnio argv <pi >po ef (open-fds 0) -1 0)
         _ (close <pi) _ (close >po) _ (? (0 <= ef) (close ef) 0)
         (? !(charm? p && 0 < p) (: _ (close >pi) (close <po) 0)
            (: _ (pins bee-cc 'pid p 'w (fdopen >pi) 'q (fdopen <po) 'sid sid 'live 1)
               _ (pins bee-cell 'claude sid)
               _ (card! (bee-cell 'state))
               1)))
     ; the child ended or was stopped: the next turn resumes its session
     (cc-stop _)
      (: p (bee-cc 'pid)
         _ (? (charm? p && 0 < p) (still p 2) 0)
         _ (? (hot? (bee-cc 'w)) (close (bee-cc 'w)) 0)
         (pins bee-cc 'live 0 'pid ()))
     ; a tool call as the screen shows it, for claude's own tools: their usual field
     (cc-brief in)
      (? !(tablet? in) ""
         (: f (filter (\ k (string? (peep in k ()))) ["command" "file_path" "path" "pattern" "url" "description" "prompt"])
            (? (two? f) (: s (in <f) (#s <= 100 ? s (snip s 0 100 + "…"))) (: s (json-show in) (#s <= 100 ? s (snip s 0 100 + "…"))))))
     ; a tool result's text, whether a string or a list of text blocks
     (cc-text c) (? (string? c) c (two? c) (foldl (\ a b (? (tablet? b && string? (peep b "text" ())) (a + b "text") a)) "" c) "")
     ; the screen's side of `approve`: each asks/ID.ask becomes the tool's block, asking; the key
     ; writes asks/ID.answer. runs while a turn does
     (cc-asks f blocks)
      (: d (cell-of bee-name + "/asks") fs (readdir d)
         _ (? (two? fs)
              (map (\ fl (? !(ends? fl ".ask") 0
                            (: p (d + "/" + fl) a (: s (slurp-file p) (? (string? s) (json-read s) ()))
                               id (snip fl 0 (#fl - 4)) ans (d + "/" + id + ".answer")
                               (? (two? (stat ans)) 0
                                  (: j (? (two? a && tablet? (a 1)) (a 1) {})
                                     tn (peep j "tool_name" "?") in (peep j "input" {})
                                     tu (peep j "tool_use_id" ())
                                     h (? (string? tu) (peep blocks tu ()) ())
                                     ; the ask's own input is what is shown, whichever block it lands on
                                     h2 (? (tablet? h) (: _ (pins h 'name tn 'in in 'v (h 'v + 1)) h) ((f 'tool) tn in))
                                     r ((f 'ask) h2)
                                     (spit-file ans (r = 1 ? "y" "n")))))))
                   (sort fs))
              0)
         0)
     ; the text of the newest user message, what the child is sent
     (cc-said msgs) (: c (<msgs "content") (? (string? c) c (cc-text c)))
     ; one user turn through the child -> the messages after it, or () when it failed
     (cc-turn key f msgs0)
      (: msgs (with-mail f msgs0)
         ok (? (bee-cc 'live) 1 (cc-start (string? (bee-cc 'sid))))
         (? !ok ((f 'note) "claude would not start: is it on PATH? its errors are in the cell's claude.err", ())
            (: w (bee-cc 'w) q (bee-cc 'q)
               _ (say w (json-show {"type" "user" "message" {"role" "user" "content" (cc-said msgs)}}))
               _ (say w "\n") _ (flush w)
               blocks {} kinds {} st {'done () 'text ""}
               asker (twirl (\ _ (: (go _) (? (st 'done) 0 (: _ (cc-asks f blocks) _ (rest 200) (go 0))) (go 0))) 0)
               (ev e)
                (: ty (e "type") i (peep e "index" ())
                   (ty @
                    "content_block_start" (pin kinds i (peep (e "content_block") "type" ""))
                    "content_block_delta"
                     (: d (e "delta")
                        (d "type" @
                         "text_delta" (: x (d "text") _ (pin st 'text (st 'text + x)) ((f 'text) x))
                         "thinking_delta" (: x (d "thinking") (? (0 < #x) ((f 'think) x) 0))
                         0))
                    "content_block_stop" (? (elem (peep kinds i "") ["text" "thinking"]) ((f 'break) 0) 0)
                    "message_start" (: u (peep (e "message") "usage" ())
                                       (? (tablet? u) ((f 'usage) (num u "input_tokens" + num u "cache_creation_input_tokens"
                                                                   + num u "cache_read_input_tokens" + num u "output_tokens")) 0))
                    0))
               (go _)
                (: l (line-of q)
                   (? !(string? l) 'eof
                      (: j (json-read l) m (? (two? j && tablet? (j 1)) (j 1) {})
                         (m "type" @
                          "stream_event" (: _ (ev (m "event")) (go 0))
                          ; the model claude runs names the card and the gauge's window
                          "system" (: md (peep m "model" ())
                                      _ (? (string? md && md != peep bee-cc 'model "")
                                           (: _ (pin bee-cc 'model md) (card! (bee-cell 'state))) 0)
                                      (go 0))
                          "assistant" (: _ (map (\ b (? (b "type" = "tool_use")
                                                         (pin blocks (b "id") ((f 'tool) (b "name") (b "input")))
                                                         0))
                                                (: c (m "message" "content") (two? c ? c ())))
                                         (go 0))
                          "user" (: c (m "message" "content")
                                    _ (? (two? c)
                                         (map (\ b (? (tablet? b && b "type" = "tool_result")
                                                      (: h (peep blocks (b "tool_use_id") ())
                                                         (? h ((f 'done) h [(!(peep b "is_error" ()) || peep b "is_error" () = json-false ? 1 0)
                                                                              (cc-text (b "content"))]) 0))
                                                      0))
                                              c)
                                         0)
                                    (go 0))
                          "result" (: x (peep m "total_cost_usd" ())
                                      _ (? (x = () || string? x) 0 ((f 'cost) x))
                                      (? ((peep m "is_error" ()) = json-true)
                                         (: _ ((f 'note) ("claude: " + (: r (peep m "result" "") (string? r ? r (show r))))) 'failed)
                                         'ok))
                          (go 0)))))
               end (go 0)
               _ (pin st 'done 1)
               _ (? (end = 'eof) (: _ (cc-stop 0) ((f 'note) "the claude child ended; the next turn resumes its session")) 0)
               (? (end = 'ok)
                  (: t (st 'text) ({"role" "assistant" "content" (0 < #t ? t "(tools only)")} . msgs))
                  ()))))

     ; --- the MCP server: `love bee --mcp`, JSON-RPC 2.0 one message a line, what a claude
     ; child runs to reach its bee and the hive. the ports are arguments, so a test drives a
     ; whole conversation without a child. an id is presence, not truth: requests count from 0 ---
     (line-of p) (: (go acc) (see p @ -1 (? (two? acc) (string (rev acc))) 10 (string (rev acc)) c (go (c . acc)))
                    (go ()))
     mcp-shared ["list_sessions" "send_message" "queue_row" "lock_acquire" "lock_release" "lock_list"]
     mcp-tools
      ({"name" "approve"
        "description" "Ask this bee's user whether a tool may run: Claude Code's permission prompt, answered from bee's screen."
        "inputSchema" {"type" "object"
                       "properties" {"tool_name" {"type" "string"} "input" {"type" "object"}
                                     "tool_use_id" {"type" "string"}}
                       "required" ["tool_name"]}}
       . map (\ t {"name" (t "name") "description" (t "description") "inputSchema" (t "input_schema")})
             (filter (\ t (elem (t "name") mcp-shared)) bee-tools))
     ; how long an ask waits for the screen, in seconds: BEE_ASK_WAIT, else ten minutes
     ask-limit (: w (getenv "BEE_ASK_WAIT") (? (string? w && 0 < #w) (digits w) 600))
     ; "y", "n", or () when no answer came in time
     (ask-wait p n)
      (: s (slurp-file p)
         (? (string? s && 0 < #s) (? (s 0 = 121 || s 0 = 89) "y" "n")
            (n <= 0) ()
            (: _ (rest 200) (ask-wait p (n - 1)))))
     ; claude's permission prompt -> [ok? text], the text claude's own {behavior ..} answer. under
     ; BEE_YES it allows; else it drops the ask in this bee's cell, asks/ID.ask, and waits for the
     ; screen to write asks/ID.answer
     (mcp-approve a)
      (: tn (peep a "tool_name" ()) inp (peep a "input" ())
         (allow _) [1 (json-show {"behavior" "allow" "updatedInput" (tablet? inp ? inp {})})]
         (deny why) [1 (json-show {"behavior" "deny" "message" why})]
         (? !(string? tn) [0 "approve wants tool_name"]
            (getenv "BEE_YES" = "1") (allow 0)
            (: d (cell-of bee-name + "/asks") _ (mkdirs d)
               id (show (clock 0) + "-" + hex2 (clock 0 % 256))
               tu (peep a "tool_use_id" ())                ; so the screen asks on the block it drew
               _ (spit-file (d + "/." + id) (json-show (: j {"tool_name" tn "input" (tablet? inp ? inp {})}
                                                           (? (string? tu) (pin j "tool_use_id" tu) j))))
               _ (rename (d + "/." + id) (d + "/" + id + ".ask"))
               ans (ask-wait (d + "/" + id + ".answer") (ask-limit * 5))
               _ (unlink (d + "/" + id + ".ask")) _ (unlink (d + "/" + id + ".answer"))
               (? (ans = "y") (allow 0)
                  (deny (? (ans = ()) "no answer came from bee's screen" "the user declined"))))))
     (mcp-call nm a)
      (? (nm = "approve") (mcp-approve a)
         (elem nm mcp-shared) (run (plain 1) () nm a)
         [0 ("no tool " + nm)])
     (mcp-serve inp outp)
      (: (send m) (: _ (say outp (json-show (pin m "jsonrpc" "2.0"))) _ (say outp "\n") (flush outp))
         (reply id r) (send {"id" id "result" r})
         (fail id code msg) (send {"id" id "error" {"code" code "message" msg}})
         (one m)
          (: id (peep m "id" ()) meth (peep m "method" ()) ps (peep m "params" ())
             (? !(string? meth) (? (() = id) 0 (fail id -32600 "a request names its method"))
                (meth @
                 "initialize"
                  (reply id {"protocolVersion" (: v (? (tablet? ps) (peep ps "protocolVersion" ()) ())
                                                  (string? v ? v "2025-06-18"))
                             "capabilities" {"tools" {}}
                             "serverInfo" {"name" "bee" "version" love-version}})
                 "ping" (reply id {})
                 "tools/list" (reply id {"tools" mcp-tools})
                 "tools/call"
                  (? !(tablet? ps && string? (peep ps "name" ())) (fail id -32602 "tools/call wants a name")
                     (: a (peep ps "arguments" ())
                        r (mcp-call (ps "name") (tablet? a ? a {}))
                        (reply id {"content" [{"type" "text" "text" (r 1)}] "isError" (<r ? json-false json-true)})))
                 (? (() = id) 0 (fail id -32601 ("no method " + meth))))))
         (go _) (: l (line-of inp)
                   (? !(string? l) 0
                      (: j (? (0 < #l) (json-read l) ())
                         _ (? (two? j && tablet? (j 1)) (one (j 1)) 0)
                         (go 0))))
         _ (twirl (\ _ (lock-poll 0)) 0)                   ; a claude child's queued locks, mailed to its bee
         (go 0))

     ; --list, --send, --spawn and --stop speak to the hive from a shell and settle nowhere;
     ; a sender there is BEE_NAME, else cli- and the user
     (bee-cli as yes)
      (: say1 (\ e ok (? (#e = 0) (: _ (puts (ok + "\n")) 0) (say err ("bee: " + e + "\n"), 1)))
         (<as @
          "--list" (: s (sessions-text 0) (puts (s + (#s && s (#s - 1) = 10 ? "" "\n")), 0))
          "--send" (? (#as < 3) (say err "usage: love bee --send NAME TEXT ..\n", 2)
                      (: e0 (getenv "BEE_NAME") u (getenv "USER")
                         from (? (string? e0 && 0 < #e0) e0 ("cli-" + (string? u ? u "someone")))
                         (say1 (post-as from <>as (joinw >>as)) ("sent to " + <>as))))
          "--spawn" (? (#as < 4) (say err "usage: love bee --spawn NAME DIR [-y] PROMPT ..\n", 2)
                       (say1 (spawn-bee <>as <>>as (joinw >>>as) yes)
                             (<>as + " is serving" + (yes ? "" ", reading only"))))
          ; --lock [--heavy] [--out DIR] -- CMD ..: the command under an exclusive lock on its out/
          ; (./out when there is one) and, with --heavy, a heavy ticket; waits for both, runs,
          ; releases whatever way it ends, and answers the command's status
          "--lock"
           (: dd (: k (index-of as "--") (? (k < 0) () (drop (k + 1) as)))
              od (: k (index-of as "--out") (? (0 <= k && k + 1 < #as) (as (k + 1)) ""))
              out (? (0 < #od) (od 0 = 47 ? od (bee-cwd + "/" + od))
                     (two? (stat (bee-cwd + "/out"))) (bee-cwd + "/out") "")
              reqs ((0 < #out ? [[out 'exclusive]] ()) + (elem "--heavy" as ? [["heavy" 'heavy]] ()))
              (? !(two? dd) (say err "usage: love bee --lock [--heavy] [--out DIR] -- CMD ..\n", 2)
                 !(locks? 0) (say err "bee: locks are not in this binary\n", 1)
                 ((lk 'locks-run) ((lk 'locks-root) 0) reqs (joinw dd) bee-floor bee-hmax dd)))
          "--stop" (? (#as < 2) (say err "usage: love bee --stop NAME\n", 2)
                      (: e (stop-bee <>as) (? (starts? e "stopped") (: _ (puts (e + "\n")) 0) (say err ("bee: " + e + "\n"), 1))))
          2))
     ; serving: the first prompt, if any, then a turn for each message as it comes. the idle
     ; wait is a rest, so the jobs' tasks run beside it
     (serve key f msgs)
      (: ms (take-mail 0)
         (? (two? ms)
            (: _ (map (\ m (f 'mail <m (m 1))) ms) _ (state! "busy")
               m (turn key f ((user (mail-text ms)) . msgs)) _ (state! "idle")
               (serve key f (two? m ? m msgs)))
            (: _ (rest 1000) (serve key f msgs))))
     (serve-first key f p)
      (? (0 < #p) (: _ (state! "busy") m (turn key f [(user p)]) _ (state! "idle") (serve key f (two? m ? m ())))
         (serve key f ()))
     bee-flags ["-y" "--plain" "--serve" "--mcp"]
     (bee-go as)
      (: key (getenv bee-key-env)
         yes (elem "-y" as)
         pl (elem "--plain" as)
         sv (elem "--serve" as)
         words (filter (\ w !(elem w bee-flags)) as)
         (? (elem "--mcp" as) (: _ (mcp-serve in out) 0)             ; a claude child's own server
            (two? as && <as = "--lock") (bee-cli as yes)              ; its command's words stay as given
            (two? words && elem <words ["--list" "--send" "--spawn" "--stop"]) (bee-cli words yes)
            ; the api backend wants its endpoint, model and key; claude brings its own
            (!bee-cc? && atom? bee-at) (say err ("bee: cannot read the url " + bee-url + "\n"), 1)
            (!bee-cc? && #bee-model = 0) (say err "bee: name the model, (model NAME) in ~/.love/etc/bee.l\n", 1)
            (!bee-cc? && !bee-local? && !(string? key && 0 < #key)) (say err ("bee: set " + bee-key-env + "\n"), 1)
            ; settled for the run, so other sessions can find it and write to it
            (: _ (settle bee-branch)
               _ (pin bee-cc 'yes yes)
               _ (? sv (: _ (twirl (\ _ (watch 0)) 0) (twirl (\ _ (lock-poll 0)) 0)) 0)
               r (? sv (serve-first key (plain yes) (: p (getenv "BEE_PROMPT")
                                                    (? (string? p && 0 < #p) p (two? words) (joinw words) "")))
                    (two? words) (: _ (state! "busy") _ (turn key (plain yes) [(user (joinw words))]) 0)
                    (!pl && two? (tty 1)) (tui key yes)
                    (repl-go key (plain yes)))
               _ (? (bee-cc 'live) (cc-stop 0) 0)
               _ (unsettle 0)
               r)))
      (bee-go as))
   bee-usage "usage: love bee [-y] [--plain] [PROMPT ..]      one prompt, the screen, or a > loop
       love bee --list | --send NAME TEXT ..           the sessions, from a shell
       love bee --spawn NAME DIR [-y] PROMPT ..         a bee serving detached in DIR
       love bee --stop NAME | --serve [-y] [PROMPT ..]"
   _ (pins (cite 'verbs 'tab) 'bee (udoor 'bee bee-main bee-usage 1 0)))

; the seat: run as a file, `love src/apps/bee.l ..`, bee starts itself; as the verb, the
; registry calls bee-main
(: s (cite 'verbs 'fire ["bee" "bee.l"])
   (two? s ? (quit (: r (bee-main >s) (charm? r ? r 0)))))
) ; module bee
