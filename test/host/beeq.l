; --- test/host/beeq.l: one merge-queue scenario played twice -- by bee agents, and by claude
; code sessions through `love bee --mcp` -- must leave the same queue and the same notices ---
; each way gets a scratch git repository laid alike (fixed names and dates, so the same shas),
; its own hive and locks, and four sessions: ant, bob, carol and queen, the leader. the bee
; agents serve, and a model played here answers each with the step's one tool call; the
; claude code sessions are MCP servers driven over stdio as claude would drive them. the
; scenario: join (the queue made on bee's standard header), a second join (the queue turns
; long), a fold, gating, a join and a fold refused, green, land by sha, the landing verified
; and a release note, and a long queue by its heavy-lock waiters.
;   cat test/00-init.l test/host/beeq.l | out/love
(borrow 'json)
(borrow 'locks)

(: bq-home (cwd 0)
   bq-love (: l <cmdline (l 0 = 47 ? l (bq-home + "/" + l)))
   bq-app (bq-home + "/src/apps/bee.l")
   bq-root (bq-home + "/out/.beeq-" + show (getpid 0))
   _ (mkdir bq-root 493)
   (bq-put p s) (: f (open p "w") _ (say f s) (close f))
   (bq-get p) (: f (open p "r") (hot? f ? (: s (slurp f) _ (close f) s) ""))
   bq-find (cite 'kore 'wg-find)
   (bq-in s p) (0 <= bq-find s p 0)
   (bq-reap p) (: s (gather p) (? (two? s) <s (nom? s) -1 (: _ (rest 5) (bq-reap p))))
   (bq-chomp s) (: n #s (? (0 < n && s (n - 1) = 10) (snip s 0 (n - 1)) s))
   (bq-sq s) ("'" + s + "'")
   bq-q "refs/queue/test"
   bq-names ["ant" "bob" "carol" "queen"]

   ; --- the model: every request heard, [session body]; each session's answers still to give.
   ; a session with none left is told its turn is over ---
   bq-box {'got () 'q {}}
   bq-pl (test-listen 0)
   bq-l (bq-pl 1)
   bq-url ("http://127.0.0.1:" + show <bq-pl)
   (bq-head c a) (: b (see c) (? (b < 0) a (: a2 (a + string b) (? (bq-in a2 "\r\n\r\n") a2 (bq-head c a2)))))
   (bq-take c n a) (? (#a < n) (: b (see c) (? (b < 0) a (bq-take c n (a + string b)))) a)
   (bq-who body)
    (: s (peep body "system" "") k (bq-find s "session named " 0)
       (? (k < 0) "?" (: e (bq-find s "." k) (snip s (k + 14) e))))
   (bq-sse evs) (foldl (\ a e (a + "data: " + json-show e + "\n\n")) "" evs)
   (bq-ok s) ("HTTP/1.1 200 OK\r\ncontent-type: text/event-stream\r\n\r\n" + s)
   bq-end (bq-ok (bq-sse [{"type" "message_delta" "delta" {"stop_reason" "end_turn"}}]))
   (bq-use id nm in)
    (bq-ok (bq-sse [{"type" "content_block_start" "index" 0 "content_block" {"type" "tool_use" "id" id "name" nm "input" {}}}
                    {"type" "content_block_delta" "index" 0 "delta" {"type" "input_json_delta" "partial_json" (json-show in)}}
                    {"type" "content_block_stop" "index" 0}
                    {"type" "message_delta" "delta" {"stop_reason" "tool_use"}}]))
   (bq-serve c)
    (: hd (bq-head c "")
       n (: v ((cite 'kore 'wg-header) hd "content-length") (? (string? v) ((cite 'kore 'wg-digits) v) 0))
       j (json-read (bq-take c n ""))
       body (? (two? j) (j 1) {})
       who (bq-who body)
       q (peep (bq-box 'q) who ())
       _ (pin (bq-box 'q) who (two? q ? >q ()))
       _ (pin bq-box 'got ([who body] . bq-box 'got))
       _ (say c (two? q ? <q bq-end))
       _ (flush c)
       (close c))
   bq-srv (twirl (\ _ ((: (g k) (: _ (await bq-l) c (accept bq-l) _ (bq-serve c) (g k))) 0)) 0)

   ; --- a way's own world: HOME with its config, a hive and locks, and the repository ---
   (bq-git w as)
    (hark (["env" "GIT_AUTHOR_DATE=2026-01-01T00:00:00Z" "GIT_COMMITTER_DATE=2026-01-01T00:00:00Z"
            "git" "-C" (w 'repo) "-c" "user.name=t" "-c" "user.email=t@t"] + as))
   (bq-out r) (? (two? r && string? >r) (bq-chomp >r) "")
   (bq-world nm)
    (: d (bq-root + "/" + nm) r (d + "/repo")
       _ (map (\ p (mkdir p 493)) [d (d + "/.love") (d + "/.love/etc")])
       _ (bq-put (d + "/.love/etc/bee.l")
                 ("(api anthropic)\n(url \"" + bq-url + "/v1/messages\")\n(model claude-mock)\n(heavy-max 1)\n"))
       w {'dir d 'repo r 'locks (d + "/locks") 'env ("HOME=" + bq-sq d + " BEE_LOCKS=" + bq-sq (d + "/locks"))}
       _ (hark ["git" "init" "-q" "-b" "test" r])
       _ (bq-put (r + "/f") "one\n")
       _ (bq-git w ["add" "f"]) _ (bq-git w ["commit" "-q" "-m" "one"])
       _ (bq-git w ["checkout" "-q" "-b" "ant"]) _ (bq-put (r + "/a") "a\n")
       _ (bq-git w ["add" "a"]) _ (bq-git w ["commit" "-q" "-m" "a"])
       _ (bq-git w ["checkout" "-q" "-b" "bob" "test"]) _ (bq-put (r + "/b") "b\n")
       _ (bq-git w ["add" "b"]) _ (bq-git w ["commit" "-q" "-m" "b"])
       _ (bq-git w ["checkout" "-q" "-b" "union" "test"])
       _ (bq-git w ["merge" "-q" "--no-ff" "ant" "bob" "-m" "the union"])
       _ (bq-git w ["checkout" "-q" "test"])
       _ (bq-put (r + "/.bee.l") "(queue-watch 1)\n")
       _ (pins w 'm (bq-out (bq-git w ["rev-parse" "--short" "test"])) 'g (bq-out (bq-git w ["rev-parse" "--short" "union"])))
       w)
   ; a command in the repository -> [exit output]
   (bq-sh w line)
    (: pp (pipe 0) nul (openfd "/dev/null" 0)
       p (spawnio ["sh" "-c" ("cd " + bq-sq (w 'repo) + " && exec env " + w 'env + " " + line)] nul >pp >pp [<pp] -1 0)
       _ (close >pp) _ (close nul)
       q (fdopen <pp) (go a) (: c (see q) (? (c < 0) a (: _ (unsee q c) (go (a + chug q)))))
       o (go "") _ (close q)
       [(bq-reap p) o])
   ; a session started detached in the repository -> [pid stdin stdout], the pipes () for a bee
   (bq-start w nm line pipes)
    (: pi (pipe 0) po (pipe 0) lg (openfd (w 'dir + "/" + nm + ".log") 2) nul (openfd "/dev/null" 0)
       cmd ("cd " + bq-sq (w 'repo) + " && exec env " + w 'env + " BEE_NAME=" + nm + " " + bq-sq bq-love + " " + bq-sq bq-app + " " + line)
       ; the child closes every fd above 2, so no session holds another's stdin open past its end
       fds (: ns (readdir "/proc/self/fd") (? (two? ns) (filter (\ n (2 < n)) (map (cite 'kore 'wg-digits) ns)) ()))
       p (? pipes (spawnio ["sh" "-c" cmd] <pi >po lg fds -1 0) (spawnio ["sh" "-c" cmd] nul lg lg fds -1 0))
       _ (close <pi) _ (close >po) _ (close lg) _ (close nul)
       (? pipes [p (fdopen >pi) (fdopen <po)] (: _ (close >pi) _ (close <po) [p () ()])))
   (bq-card w nm) (bq-get (w 'dir + "/.love/run/hive/" + nm + "/card"))
   (bq-until f n) (? (f 0) 1 (n <= 0) 0 (: _ (rest 100) (bq-until f (n - 1))))

   ; the steps: [id session tool input], the scenario either way plays
   (bq-steps w)
    [["s1" "ant" "queue_row" {"queue" bq-q "state" "waiting" "branch" "ant" "leader" "queen"}]
     ["s2" "bob" "queue_row" {"queue" bq-q "state" "waiting" "branch" "bob"}]
     ["s3" "queen" "queue_row" {"queue" bq-q "session" "bob" "state" "folded-into-1"}]
     ["s4" "ant" "queue_row" {"queue" bq-q "state" "gating" "gated_on" (w 'm) "gated_head" (w 'g) "note" "the union of ant and bob"}]
     ["s5" "carol" "queue_row" {"queue" bq-q "state" "waiting" "branch" "carol"}]
     ["s6" "queen" "queue_row" {"queue" bq-q "session" "carol" "state" "folded-into-1"}]
     ["s7" "ant" "queue_row" {"queue" bq-q "state" "green"}]
     ["s8" "ant" "queue_land" {"queue" bq-q}]
     'land
     ["s9" "ant" "queue_landed" {"queue" bq-q "release" "nothing moves or goes"}]
     'crowd
     ["s10" "carol" "queue_row" {"queue" bq-q "state" "waiting" "note" "still here"}]
     'uncrowd]
   ; the landing queue_land answered, as the lander runs it; the heavy pool crowded and freed
   (bq-land w) (bq-git w ["merge" "-q" "--no-ff" (w 'g) "-m" "Merge queue row 1 (ant)"])
   (bq-crowd w on)
    (? on (map (\ nm ((cite 'locks 'locks-acquire) (w 'locks) nm 'heavy (? (nm = "slow") (getpid 0) 1) nm () 1))
               ["slow" "wait-a" "wait-b"])
       (: _ ((cite 'locks 'locks-release) (w 'locks) "slow" 'heavy (getpid 0))
          (map (\ nm ((cite 'locks 'locks-release) (w 'locks) nm 'heavy 1)) ["wait-a" "wait-b"])))
   (bq-aside w s) (s @ 'land (bq-land w) 'crowd (bq-crowd w 1) 'uncrowd (bq-crowd w 0) 0)

   ; <message from="X">..</message> blocks in a text -> ["X: line" ..]
   (bq-mail t)
    (: (go k acc)
        (: a (bq-find t "<message from=\"" k)
           (? (a < 0) acc
              (: q (bq-find t "\">" a) e (bq-find t "</message>" q)
                 who (snip t (a + 15) q) body (snip t (q + 3) e)
                 (go (e + 10) (acc + map (\ l (who + ": " + l)) (filter (\ l (0 < #l)) (lines body)))))))
       (go 0 ()))
   (bq-set ls) (sort (foldl (\ a l (elem l a ? a (a + [l]))) () ls))
   ; a tool's answer without the mail riding on it, the repository's path said as REPO
   (bq-plain w t)
    (: k (bq-find t "<message from=" 0) s (? (k < 0) t (snip t 0 k))
       (: (tidy s) (: n #s (? (0 < n && s (n - 1) = 10) (tidy (snip s 0 (n - 1))) s))
          (: (swap s) (: j (bq-find s (w 'repo) 0) (? (j < 0) s (swap (snip s 0 j + "REPO" + snip s (j + #(w 'repo)) #s))))
             (swap (tidy s)))))
   bq-gap 2000)                                                   ; two readings of each queue apart

; --- the bee agents: each serves, and a message from the driver starts the turn whose one call
; the model hands it. the answers and the mail come back in the requests the model hears ---
(: w (bq-world "native")
   ps (map (\ nm (bq-start w nm "--serve -y" 0)) bq-names)
   _ (bq-until (\ _ (all (\ nm (bq-in (bq-card w nm) "state idle")) bq-names)) 100)
   (post nm) (: ib (w 'dir + "/.love/run/hive/" + nm + "/inbox") id (show (clock 0) + "-driver")
                _ (bq-put (ib + "/." + id) "from driver\n\ngo on\n")
                (rename (ib + "/." + id) (ib + "/" + id)))
   (step s)
    (? !(two? s) (bq-aside w s)
       (: nm (s 1)
          _ (pin (bq-box 'q) nm [(bq-use <s (s 2) (s 3))])
          _ (post nm)
          _ (bq-until (\ _ !(two? (peep (bq-box 'q) nm ()))) 150)
          _ (bq-until (\ _ (bq-in (bq-card w nm) "state idle")) 150)
          (rest bq-gap)))
   _ (map step (bq-steps w))
   _ (rest (2 * bq-gap))                                         ; the last notices, taken
   got (rev (bq-box 'got))
   ; every tool_result by its id, and every message each session was handed
   (users b) (filter (\ m (m "role" = "user")) (peep b "messages" ()))
   (texts m) (: c (m "content") (? (string? c) [c] (map (\ x (peep x "text" (peep x "content" ""))) c)))
   res (foldl (\ t g (foldl (\ t m (: c (m "content")
                                     (? (string? c) t
                                        (foldl (\ t x (? (peep x "type" "" = "tool_result") (pin t (x "tool_use_id") (x "content")) t)) t c))))
                             t (users (g 1))))
              {} got)
   heard (foldl (\ t nm (pin t nm (bq-set (filter (\ l !(starts? l "driver: "))    ; the driver's nudges are this way's own
                                                  (catmap (\ g (? (<g = nm) (catmap (\ m (catmap bq-mail (texts m))) (users (g 1))) ()))
                                                          got)))))
                {} bq-names)
   _ (map (\ nm (bq-sh w (bq-sq bq-love + " " + bq-sq bq-app + " --stop " + nm))) bq-names)
   _ (map (\ p (bq-reap <p)) ps)
   _ (pin bq-box 'native {'queue (bq-out (bq-git w ["cat-file" "-p" bq-q])) 'res res 'heard heard 'w w})
   0)

; --- the claude code sessions: each an MCP server of its own, called as claude calls it; the
; mail rides on the answers, and inbox takes what is left at the end ---
(: w (bq-world "mcp")
   ss (foldl (\ t nm (pin t nm (bq-start w nm "--mcp" 1))) {} bq-names)
   box {'n 100}
   (line q) (: (go acc) (: c (see q) (? (c < 0 || c = 10) (string (rev acc)) (go (c . acc)))) (go ()))
   (call nm tool in)
    (: s (ss nm) n (box 'n + 1) _ (pin box 'n n)
       _ (say (s 1) (json-show {"jsonrpc" "2.0" "id" n "method" "tools/call" "params" {"name" tool "arguments" in}}))
       _ (say (s 1) "\n") _ (flush (s 1))
       j (json-read (line (s 2)))
       (? (two? j) ((peep (peep (j 1) "result" {}) "content" [{"text" ""}]) 0 "text") ""))
   _ (map (\ nm (: s (ss nm)
                   _ (say (s 1) (json-show {"jsonrpc" "2.0" "id" 0 "method" "initialize" "params" {"protocolVersion" "2025-06-18"}}))
                   _ (say (s 1) "\n") _ (flush (s 1))
                   (pin box nm (line (s 2)))))
          bq-names)
   listed (bq-sh w (bq-sq bq-love + " " + bq-sq bq-app + " --list"))
   said {}
   (step s)
    (? !(two? s) (bq-aside w s)
       (: t (call (s 1) (s 2) (s 3))
          _ (pin said <s t)
          (rest bq-gap)))
   _ (map step (bq-steps w))
   _ (rest (2 * bq-gap))                                         ; the last notices, taken
   left (foldl (\ t nm (pin t nm (call nm "inbox" {}))) {} bq-names)
   res (foldl (\ t k (pin t k (said k))) {} (keys said))
   heard (foldl (\ t nm (pin t nm (bq-set (catmap (\ k (? ((filter (\ s (two? s && <s = k)) (bq-steps w)) 0 1 = nm) (bq-mail (said k)) ()))
                                                   (keys said)
                                           + bq-mail (left nm)))))
                {} bq-names)
   _ (map (\ nm (: s (ss nm) _ (close (s 1)) (bq-reap <s))) bq-names)
   gone (bq-sh w (bq-sq bq-love + " " + bq-sq bq-app + " --list"))
   _ (pin bq-box 'mcp {'queue (bq-out (bq-git w ["cat-file" "-p" bq-q])) 'res res 'heard heard 'w w
                       'listed (listed 1) 'gone (gone 1) 'init (box "ant")})
   0)

; --- the law: the same queue, the same answers, the same notices, and what they say ---------
(: n (bq-box 'native) m (bq-box 'mcp)
   (r k) (: a (bq-plain (n 'w) (peep (n 'res) k "")) b (bq-plain (m 'w) (peep (m 'res) k "")) [a b])
   ids ["s1" "s2" "s3" "s4" "s5" "s6" "s7" "s8" "s9" "s10"]
   same (filter (\ k (: x (r k) (<x != x 1))) ids)
   diff (filter (\ nm (show (n 'heard nm) != show (m 'heard nm))) bq-names)
   _ (? (two? same) (map (\ k (: x (r k) (puts ("beeq: " + k + " differs\n  bee: " + <x + "\n  mcp: " + x 1 + "\n")))) same) 0)
   _ (? (two? diff) (map (\ nm (puts ("beeq: " + nm + " heard\n  bee: " + show (n 'heard nm) + "\n  mcp: " + show (m 'heard nm) + "\n"))) diff) 0)
   q (m 'queue) g ((m 'w) 'g)
   (said k) (<(r k))
   (hears nm s) (elem s (m 'heard nm))
   _ (test
      (0 < #q) (n 'queue = q)                                         ; the same queue, byte for byte
      !(two? same) !(two? diff)                                       ; the same answers, the same notices
      (bq-in q "on bee's standard protocol") (bq-in q "leader queen")
      (bq-in q "3 carol carol - - waiting  # still here") !(bq-in q " ant ") !(bq-in q " bob ")
      (bq-in q ("test " + bq-out (bq-git (m 'w) ["rev-parse" "--short" "test"])))
      (bq-in (said "s1") "made refs/queue/test on bee's standard header, led by queen")
      (bq-in (said "s2") "the queue is long (two or more rows waiting or gating)")
      (bq-in (said "s3") "row now: 2 bob bob - - folded-into-1")
      (bq-in (said "s6") "row 1 is gating: a row folds only into a waiting row")
      (bq-in (said "s8") ("git merge --no-ff " + bq-out (bq-git (m 'w) ["rev-parse" "union"])))
      (bq-in (said "s8") "in the checkout of test, REPO:")
      (bq-in (said "s9") "landed: rows 1 and 2 left refs/queue/test") (bq-in (said "s9") "the release note went to carol")
      (bq-in (said "s10") "more heavy-lock waiters than slots")
      (hears "ant" "queue-watch: - row 2 folds into yours: bob's bob at -")
      (hears "carol" "queue-watch: - row 1, which yours stacked on, has left the queue")
      (hears "carol" ("ant: row 1 landed on test at " + bq-out (bq-git (m 'w) ["rev-parse" "--short" "test"]) + ": nothing moves or goes"))
      (hears "queen" ("queue-watch: - row 1 moved: 1 (ant, ant) at " + g + ", green (was " + g + ", gating)"))
      (hears "bob" "queue-watch: - your row 2 has left the queue: landed, or dropped")
      (bq-in (m 'listed) "queen  idle") (bq-in (m 'listed) "carol  idle")   ; claude code sessions in the hive
      !(bq-in (m 'gone) "queen")                                      ; and out of it when they end
      (bq-in (m 'init) "You are the session named ant"))
   0)

; --- the leader's own lines, and what only the leader may do --------------------------------
; queen keeps sync and pre and places a join; a fold into a missing row or one behind is refused;
; carol, not the leader, may not touch sync, but as the head takes the queue, acting, once
; queen has no live session
(: w (bq-box 'mcp 'w)
   (calls nm cs)
    (: f (w 'dir + "/" + nm + ".in")
       _ (bq-put f (foldl (\ a c (a + json-show {"jsonrpc" "2.0" "id" <c "method" "tools/call"
                                                "params" {"name" (c 1) "arguments" (pin (c 2) "queue" bq-q)}} + "\n"))
                         "" cs))
       r (bq-sh w ("env BEE_NAME=" + nm + " " + bq-sq bq-love + " " + bq-sq bq-app + " --mcp < " + bq-sq f))
       (foldl (\ t l (: j (json-read l) (? (two? j) (pin t ((j 1) "id") ((j 1) "result" "content" 0 "text")) t)))
              {} (filter (\ l (0 < #l)) (lines (r 1)))))
   a (calls "queen" [[1 "queue_lead" {"sync" "toward 0.3"}] [2 "queue_lead" {"pre_add" "one"}]
                     [3 "queue_lead" {"pre_add" "two"}] [4 "queue_lead" {"pre_drop" "1"}]
                     [5 "queue_row" {"session" "dan" "state" "waiting" "branch" "dan" "position" "7"}]
                     [6 "queue_row" {"session" "dan" "state" "folded-into-9"}]
                     [7 "queue_row" {"session" "carol" "state" "folded-into-7"}]])
   b (calls "carol" [[8 "queue_lead" {"sync" "mine"}] [9 "queue_lead" {"leader" "carol"}]])
   q (bq-out (bq-git w ["cat-file" "-p" bq-q]))
   _ (test
      (bq-in (a 5) "row now: 7 dan dan - - waiting")
      (bq-in (a 6) "no row 9 to fold into")
      (bq-in (a 7) "row 7 is not ahead of row 3")
      (bq-in (b 8) "only the leader, queen,")
      (bq-in (b 9) "you lead it, acting, in place of queen")
      (bq-in q ("test " + bq-out (bq-git w ["rev-parse" "--short" "test"]) + "\nsync toward 0.3\npre two\n"))
      !(bq-in q "pre one") (bq-in q "leader carol acting") (bq-in q "7 dan dan - - waiting"))
   0)

; --- stacked landings recorded late, the counter, a noted base line, a release that misses ---
; rows 1 and 2 land back to back before either is recorded: each is found by its own merge on
; the base's first-parent line, and the base line steps through both. the emptied queue's next
; join takes 3, not 1. a base line with a note still records a landing and keeps the note.
; ant's release note goes to bob, who has no session, and the answer says so
(: w (bq-box 'mcp 'w) stq "refs/queue/stack"
   (git as) (bq-out (bq-git w as))
   (calls nm cs)
    (: f (w 'dir + "/" + nm + ".in")
       _ (bq-put f (foldl (\ a c (a + json-show {"jsonrpc" "2.0" "id" <c "method" "tools/call"
                                                "params" {"name" (c 1) "arguments" (pin (c 2) "queue" stq)}} + "\n"))
                         "" cs))
       r (bq-sh w ("env BEE_NAME=" + nm + " " + bq-sq bq-love + " " + bq-sq bq-app + " --mcp < " + bq-sq f))
       (foldl (\ t l (: j (json-read l) (? (two? j) (pin t ((j 1) "id") ((j 1) "result" "content" 0 "text")) t)))
              {} (filter (\ l (0 < #l)) (lines (r 1)))))
   (commit br from f) (: _ (git ["checkout" "-q" "-b" br from]) _ (bq-put (w 'repo + "/" + f) (f + "\n"))
                         _ (git ["add" f]) _ (git ["commit" "-q" "-m" f]) (git ["rev-parse" "HEAD"]))
   (merge h nm) (: _ (git ["merge" "-q" "--no-ff" h "-m" nm]) (git ["rev-parse" "--short" "HEAD"]))
   (queue _) (git ["cat-file" "-p" stq])
   _ (git ["branch" "stack" "test"])
   m (git ["rev-parse" "--short" "stack"])
   g1 (commit "s1" "stack" "s1") g2 (commit "s2" "s1" "s2")
   a (calls "ant" [[1 "queue_row" {"state" "green" "branch" "s1" "gated_on" m "gated_head" g1 "leader" "queen"}]])
   b (calls "bob" [[2 "queue_row" {"state" "green" "branch" "s2" "gated_on" g1 "gated_head" g2}]])
   _ (git ["checkout" "-q" "stack"])
   m1 (merge g1 "row 1") m2 (merge g2 "row 2")
   c (calls "ant" [[3 "queue_landed" {"release" "s1 is new"}]])
   q1 (queue 0)
   d (calls "bob" [[4 "queue_landed" {}]])
   q2 (queue 0)
   ; the leader's note on the base line
   nf (w 'dir + "/stack.q")
   _ (bq-put nf (foldl (\ a l (a + (starts? l "stack " ? (l + "  # the base, noted") l) + "\n")) "" (lines q2)))
   _ (git ["update-ref" stq (git ["hash-object" "-w" nf])])
   g3 (commit "s3" "stack" "s3")
   e (calls "dan" [[5 "queue_row" {"state" "waiting" "branch" "s3"}]
                   [6 "queue_row" {"state" "green" "gated_on" m2 "gated_head" g3}]])
   q3 (queue 0)
   _ (git ["checkout" "-q" "stack"])
   m3 (merge g3 "row 3")
   _ (git ["checkout" "-q" "test"])
   f (calls "dan" [[7 "queue_landed" {}]])
   q4 (queue 0)
   _ (test
      (bq-in (a 1) "row now: 1 ant s1") (bq-in (b 2) "row now: 2 bob s2")
      (bq-in (c 3) ("landed: row 1 left refs/queue/stack, whose base line is now stack " + m1 + "."))
      (bq-in (c 3) "the release note reached no session. it could not reach bob (not in the hive): relay it to that session yourself.")
      (bq-in q1 ("\nstack " + m1 + "\n")) (bq-in q1 "2 bob s2")
      (bq-in (d 4) ("landed: row 2 left refs/queue/stack, whose base line is now stack " + m2 + "."))
      (bq-in q2 ("\nstack " + m2 + "\nnext 3")) !(bq-in q2 " bob ")
      (bq-in (e 5) "row now: 3 dan s3 - - waiting")
      (bq-in q3 ("\nstack " + m2 + "  # the base, noted\nnext 4\n3 dan s3 "))
      (bq-in (f 7) ("landed: row 3 left refs/queue/stack, whose base line is now stack " + m3 + "."))
      (bq-in q4 ("\nstack " + m3 + "  # the base, noted\nnext 4")))
   0)

(hark ["rm" "-rf" bq-root])
(test_fin (), puts "beeq: ok", putc 10, 0)
