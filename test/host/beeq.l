; bee's merge queue (src/apps/bee.l): one scenario played by `love bee --mcp` sessions in a
; scratch repository (fixed names and dates, so the same shas), its own hive and locks; queen leads
;   cat test/00-init.l test/host/beeq.l | out/love
(borrow 'json)
(borrow 'locks)

(: bq-home (cwd 0)
   bq-love (: l <cmdline (l 0 = 47 ? l (bq-home + "/" + l)))
   bq-app "bee"            ; the binary's verb, baked from this tree: the lane makes `host` first
   bq-root (bq-home + "/out/.beeq-" + show (getpid 0))
   _ (mkdir bq-root 493)
   ; a session running these passes its own hive down -- BEE_HIVE, BEE_NAME, BEE_AS -- and a
   ; world would read the live sessions and write its cells among them: HOME alone says here
   _ (map (\ k (setenv k ())) ["BEE_HIVE" "BEE_NAME" "BEE_AS"])
   (bq-put p s) (: f (open p "w") _ (say f s) (close f))
   (bq-get p) (: f (open p "r") (hot? f ? (: s (slurp f) _ (close f) s) ""))
   bq-find fsub
   (bq-reap p) (: s (gather p) (? (two? s) <s (nom? s) -1 (: _ (rest 5) (bq-reap p))))
   (bq-chomp s) (: n #s (? (0 < n && s (n - 1) = 10) (snip s 0 (n - 1)) s))
   (bq-sq s) ("'" + s + "'")
   bq-q "refs/queue/test"
   bq-names ["ant" "bob" "carol" "queen"]

   bq-box {}

   ; a way's world: HOME, a hive, locks and the repository
   (bq-git w as)
    (hark (["env" "GIT_AUTHOR_DATE=2026-01-01T00:00:00Z" "GIT_COMMITTER_DATE=2026-01-01T00:00:00Z"
            "git" "-C" (w 'repo) "-c" "user.name=t" "-c" "user.email=t@t"] + as))
   (bq-out r) (? (two? r && string? >r) (bq-chomp >r) "")
   (bq-world nm)
    (: d (bq-root + "/" + nm) r (d + "/repo")
       _ (map (\ p (mkdir p 493)) [d (d + "/.love") (d + "/.love/etc")])
       _ (bq-put (d + "/.love/etc/bee.l") "(heavy-max 1)\n")
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
   ; a session started detached in the repository -> [pid stdin stdout]
   (bq-start w nm line)
    (: pi (pipe 0) po (pipe 0) lg (openfd (w 'dir + "/" + nm + ".log") 2)
       cmd ("cd " + bq-sq (w 'repo) + " && exec env " + w 'env + " BEE_NAME=" + nm + " " + bq-sq bq-love + " " + bq-sq bq-app + " " + line)
       ; the child closes fds above 2, so no session holds another's stdin open
       fds (: ns (readdir "/proc/self/fd") (? (two? ns) (filter (\ n (2 < n)) (map (cite 'kore 'wg-digits) ns)) ()))
       p (spawnio ["sh" "-c" cmd] <pi >po lg fds -1 0)
       _ (close <pi) _ (close >po) _ (close lg)
       [p (fdopen >pi) (fdopen <po)])
   (bq-until f n) (? (f 0) 1 (n <= 0) 0 (: _ (rest 100) (bq-until f (n - 1))))

   ; the steps: [id session tool input], the scenario played
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
   ; tools/call lines to `bee --mcp` as nm on queue q, env words ahead: texts by id
   (bq-calls w q env nm cs)
    (: f (w 'dir + "/" + nm + ".in")
       _ (bq-put f (foldl (\ a c (a + json-show {"jsonrpc" "2.0" "id" <c "method" "tools/call"
                                                "params" {"name" (c 1) "arguments" (pin (c 2) "queue" q)}} + "\n"))
                         "" cs))
       r (bq-sh w ("env " + env + "BEE_NAME=" + nm + " " + bq-sq bq-love + " " + bq-sq bq-app + " --mcp < " + bq-sq f))
       (foldl (\ t l (: j (json-read l) (? (two? j) (pin t ((j 1) "id") ((j 1) "result" "content" 0 "text")) t)))
              {} (filter (\ l (0 < #l)) (lines (r 1)))))
   bq-gap 2000)                                                   ; two readings of each queue apart

; the claude code sessions: MCP servers over stdio; inbox takes the mail left at the end
(: w (bq-world "mcp")
   ss (foldl (\ t nm (pin t nm (bq-start w nm "--mcp"))) {} bq-names)
   box {'n 100}
   (line q) (: (go acc) (: c (see q) (? (c < 0 || c = 10) (string (rev acc)) (go (c . acc)))) (go ()))
   ; the answer to request n, past the bell's notices, which carry no id
   (answer q n) (: l (line q) j (json-read l)
                   (? (#l = 0) () (two? j && peep (j 1) "id" () = n) j (answer q n)))
   (call nm tool in)
    (: s (ss nm) n (box 'n + 1) _ (pin box 'n n)
       _ (say (s 1) (json-show {"jsonrpc" "2.0" "id" n "method" "tools/call" "params" {"name" tool "arguments" in}}))
       _ (say (s 1) "\n") _ (flush (s 1))
       j (answer (s 2) n)
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

; the law: the queue, answers and notices
(: m (bq-box 'mcp)
   q (m 'queue) g ((m 'w) 'g)
   (said k) (bq-plain (m 'w) (peep (m 'res) k ""))
   (hears nm s) (elem s (m 'heard nm))
   _ (test
      (0 < #q)
      (has? q "on bee's standard protocol") (has? q "leader queen")
      (has? q "3 carol carol - - waiting  # still here") !(has? q " ant ") !(has? q " bob ")
      (has? q ("test " + bq-out (bq-git (m 'w) ["rev-parse" "--short" "test"])))
      (has? (said "s1") "made refs/queue/test on bee's standard header, led by queen")
      (has? (said "s2") "the queue is long (two or more rows waiting or gating)")
      (has? (said "s3") "row now: 2 bob bob - - folded-into-1")
      (has? (said "s6") "row 1 is gating: a row folds only into a waiting row")
      (has? (said "s8") ("git merge --no-ff " + bq-out (bq-git (m 'w) ["rev-parse" "union"])))
      (has? (said "s8") "in the checkout of test, REPO:")
      (has? (said "s9") "landed: rows 1 and 2 left refs/queue/test") (has? (said "s9") "the release note went to carol")
      (has? (said "s10") "more heavy-lock waiters than slots")
      (hears "ant" "queue-watch: - row 2 folds into yours: bob's bob at -")
      (hears "carol" "queue-watch: - row 1, which yours stacked on, has left the queue")
      (hears "carol" ("ant: row 1 landed on test at " + bq-out (bq-git (m 'w) ["rev-parse" "--short" "test"]) + ": nothing moves or goes"))
      (hears "queen" ("queue-watch: - row 1 moved: 1 (ant, ant) at " + g + ", green (was " + g + ", gating)"))
      (hears "bob" "queue-watch: - your row 2 has left the queue: landed, or dropped")
      (has? (m 'listed) "queen  idle") (has? (m 'listed) "carol  idle")   ; claude code sessions in the hive
      !(has? (m 'gone) "queen")                                      ; and out of it when they end
      (has? (m 'init) "You are the session named ant"))
   0)

; only the leader keeps sync and pre and places a join; a fold into a missing row or one
; behind is refused; the head takes the queue, acting, once the leader has no live session
(: w (bq-box 'mcp 'w)
   calls (bq-calls w bq-q "")
   a (calls "queen" [[1 "queue_lead" {"sync" "toward 0.3"}] [2 "queue_lead" {"pre_add" "one"}]
                     [3 "queue_lead" {"pre_add" "two"}] [4 "queue_lead" {"pre_drop" "1"}]
                     [5 "queue_row" {"session" "dan" "state" "waiting" "branch" "dan" "position" "7"}]
                     [6 "queue_row" {"session" "dan" "state" "folded-into-9"}]
                     [7 "queue_row" {"session" "carol" "state" "folded-into-7"}]])
   b (calls "carol" [[8 "queue_lead" {"sync" "mine"}] [9 "queue_lead" {"leader" "carol"}]])
   q (bq-out (bq-git w ["cat-file" "-p" bq-q]))
   _ (test
      (has? (a 5) "row now: 7 dan dan - - waiting")
      (has? (a 6) "no row 9 to fold into")
      (has? (a 7) "row 7 is not ahead of row 3")
      (has? (b 8) "only the leader, queen,")
      (has? (b 9) "you lead it, acting, in place of queen")
      (has? q ("test " + bq-out (bq-git w ["rev-parse" "--short" "test"]) + "\nsync toward 0.3\npre two\n"))
      !(has? q "pre one") (has? q "leader carol acting") (has? q "7 dan dan - - waiting"))
   0)

; landings recorded late are found by their merges on the base's first-parent line; the
; emptied queue's next join takes 3; a noted base line keeps its note; a release to no session says so
(: w (bq-box 'mcp 'w) stq "refs/queue/stack"
   (git as) (bq-out (bq-git w as))
   calls (bq-calls w stq "")
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
      (has? (a 1) "row now: 1 ant s1") (has? (b 2) "row now: 2 bob s2")
      (has? (c 3) ("landed: row 1 left refs/queue/stack, whose base line is now stack " + m1 + "."))
      (has? (c 3) "the release note reached no session. it could not reach bob (not in the hive): relay it to that session yourself.")
      (has? q1 ("\nstack " + m1 + "\n")) (has? q1 "2 bob s2")
      (has? (d 4) ("landed: row 2 left refs/queue/stack, whose base line is now stack " + m2 + "."))
      (has? q2 ("\nstack " + m2 + "\nnext 3")) !(has? q2 " bob ")
      (has? (e 5) "row now: 3 dan s3 - - waiting")
      (has? q3 ("\nstack " + m2 + "  # the base, noted\nnext 4\n3 dan s3 "))
      (has? (f 7) ("landed: row 3 left refs/queue/stack, whose base line is now stack " + m3 + "."))
      (has? q4 ("\nstack " + m3 + "  # the base, noted\nnext 4")))
   0)

; a landing that touches src/apps/bee.l says to restart: carl's note does, dan's does not
(: w (bq-box 'mcp 'w) sq "refs/queue/served"
   (git as) (bq-out (bq-git w as))
   calls (bq-calls w sq "")
   (commit br from f) (: _ (git ["checkout" "-q" "-b" br from]) _ (hark ["mkdir" "-p" (w 'repo + "/src/apps")])
                         _ (bq-put (w 'repo + "/" + f) (br + "\n"))
                         _ (git ["add" f]) _ (git ["commit" "-q" "-m" br]) (git ["rev-parse" "HEAD"]))
   (cell nm) (: d (w 'dir + "/.love/run/hive/" + nm)
                _ (hark ["mkdir" "-p" (d + "/inbox") (d + "/read")])
                (bq-put (d + "/card") ("pid " + show (getpid 0) + "\ncwd /\nstate idle\nsince 0\n")))
   (note nm) (: d (w 'dir + "/.love/run/hive/" + nm + "/inbox") fs (readdir d)
                (foldl (\ a f (a + bq-get (d + "/" + f))) "" (two? fs ? (sort fs) ())))
   _ (git ["branch" "served" "test"])
   m (git ["rev-parse" "--short" "served"])
   g1 (commit "v1" "served" "src/apps/bee.l") g2 (commit "v2" "v1" "v2")
   _ (calls "ant" [[1 "queue_row" {"state" "green" "branch" "v1" "gated_on" m "gated_head" g1 "leader" "queen"}]])
   _ (calls "carl" [[2 "queue_row" {"state" "green" "branch" "v2" "gated_on" g1 "gated_head" g2}]])
   _ (calls "dan" [[3 "queue_row" {"state" "waiting" "branch" "v3"}]])
   _ (cell "carl") _ (cell "dan")
   _ (git ["checkout" "-q" "served"])
   _ (git ["merge" "-q" "--no-ff" g1 "-m" "row 1"])
   a (calls "ant" [[4 "queue_landed" {"release" "v1 is in"}]])
   _ (git ["merge" "-q" "--no-ff" g2 "-m" "row 2"])
   b (calls "queen" [[5 "queue_landed" {"session" "carl" "release" "v2 is in"}]])
   _ (git ["checkout" "-q" "test"])
   _ (test
      (has? (a 4) "the release note went to carl and dan.") (has? (a 4) "this landing changed bee: every live session restarts")
      (has? (note "carl") "v1 is in this landing changed bee: every live session restarts at the next convenient point -- between tasks, never mid-gate --")
      (has? (b 5) "the release note went to dan.") !(has? (b 5) "changed bee")
      (has? (note "dan") ": v2 is in") !(has? (note "dan") "v2 is in this landing"))
   0)

; the lander's own row next still leaves the rows behind it told; with only its own rows behind, it says so
(: w (bq-box 'mcp 'w) sq "refs/queue/mine"
   (git as) (bq-out (bq-git w as))
   calls (bq-calls w sq "")
   (commit br from f) (: _ (git ["checkout" "-q" "-b" br from]) _ (bq-put (w 'repo + "/" + f) (br + "\n"))
                         _ (git ["add" f]) _ (git ["commit" "-q" "-m" br]) (git ["rev-parse" "HEAD"]))
   (cell nm) (: d (w 'dir + "/.love/run/hive/" + nm)
                _ (hark ["mkdir" "-p" (d + "/inbox") (d + "/read")])
                (bq-put (d + "/card") ("pid " + show (getpid 0) + "\ncwd /\nstate idle\nsince 0\n")))
   (note nm) (: d (w 'dir + "/.love/run/hive/" + nm + "/inbox") fs (readdir d)
                (foldl (\ a f (a + bq-get (d + "/" + f))) "" (two? fs ? (sort fs) ())))
   _ (git ["branch" "mine" "test"])
   m (git ["rev-parse" "--short" "mine"])
   g1 (commit "m1" "mine" "m1") g2 (commit "m2" "m1" "m2")
   _ (calls "ant" [[1 "queue_row" {"state" "green" "branch" "m1" "gated_on" m "gated_head" g1 "leader" "queen"}]
                   [2 "queue_row" {"state" "green" "branch" "m2" "gated_on" g1 "gated_head" g2}]])
   _ (calls "cyd" [[3 "queue_row" {"state" "waiting" "branch" "m3"}]])
   _ (cell "cyd")
   _ (git ["checkout" "-q" "mine"])
   _ (git ["merge" "-q" "--no-ff" g1 "-m" "row 1"])
   a (calls "ant" [[4 "queue_landed" {"release" "m1 is in"}]])
   _ (calls "queen" [[5 "queue_row" {"session" "cyd" "state" "left"}]])
   _ (git ["merge" "-q" "--no-ff" g2 "-m" "row 2"])
   _ (calls "ant" [[6 "queue_row" {"state" "waiting" "branch" "m4"}]])
   b (calls "ant" [[7 "queue_landed" {"release" "m2 is in"}]])
   _ (git ["checkout" "-q" "test"])
   _ (test
      (has? (a 4) "the release note went to cyd.") (has? (note "cyd") ": m1 is in")
      (has? (b 7) "the rows behind are yours.") !(has? (b 7) "no row is behind it"))
   0)

; a session is told once when its binary is replaced by one with other bee source; a touch tells nothing
(: w (bq-box 'mcp 'w) d (w 'dir + "/self") _ (mkdir d 493) exe (d + "/love")
   _ (hark ["cp" bq-love exe])
   s (: pi (pipe 0) po (pipe 0) nul (openfd "/dev/null" 2)
        cmd ("cd " + bq-sq (w 'repo) + " && exec env " + w 'env + " BEE_NAME=selfie BEE_SELF_WATCH=0 " + bq-sq exe + " " + bq-sq bq-app + " --mcp")
        p (spawnio ["sh" "-c" cmd] <pi >po nul [>pi <po] -1 0)
        _ (close <pi) _ (close >po) _ (close nul)
        [p (fdopen >pi) (fdopen <po)])
   (line q) (: (go acc) (: c (see q) (? (c < 0 || c = 10) (string (rev acc)) (go (c . acc)))) (go ()))
   (rpc id meth ps) (: _ (say (s 1) (json-show {"jsonrpc" "2.0" "id" id "method" meth "params" ps}))
                       _ (say (s 1) "\n") _ (flush (s 1))
                       (json-read (line (s 2))))
   (inbox id) (: j (rpc id "tools/call" {"name" "inbox" "arguments" {}})
                 (? (two? j) ((peep (peep (j 1) "result" {}) "content" [{"text" ""}]) 0 "text") ""))
   (n-told t) (: (go k n) (: a (bq-find t "<message from=\"bee\">" k) (? (a < 0) n (go (a + 1) (n + 1)))) (go 0 0))
   _ (rpc 0 "initialize" {"protocolVersion" "2025-06-18"})
   t1 (inbox 1)
   _ (hark ["touch" "-d" "2030-01-02 03:04" exe])
   t2 (inbox 2) t3 (inbox 3)
   _ (bq-put (d + "/other") "#!/bin/sh\necho another bee\n") _ (hark ["chmod" "755" (d + "/other")])
   _ (hark ["mv" (d + "/other") exe])
   t4 (inbox 4) t5 (inbox 5)
   _ (close (s 1)) _ (bq-reap <s) _ (close (s 2))
   _ (test
      (n-told t1 = 0)
      (n-told t2 = 0) (n-told t3 = 0)
      (n-told t4 = 1) (has? t4 ("bee was updated: " + exe + " was replaced")) (has? t4 "never mid-gate")
      (n-told t5 = 0))
   0)


; a row merged but not queue_landed blocks the row behind, and the answer names the locked fast gate
(: w (bq-world "landing") lq bq-q
   (sha r) (bq-out (bq-git w ["rev-parse" r]))
   calls (bq-calls w lq "")
   m (sha "test") ga (sha "ant") gu (sha "union")
   a (calls "ant" [[1 "queue_row" {"state" "waiting" "branch" "ant" "leader" "queen"}]
                   [2 "queue_row" {"state" "green" "gated_on" m "gated_head" ga}]])
   b (calls "bob" [[3 "queue_row" {"state" "waiting" "branch" "union"}]
                   [4 "queue_row" {"state" "green" "gated_on" ga "gated_head" gu}]
                   [5 "queue_land" {}]])
   _ (bq-git w ["merge" "-q" "--no-ff" ga "-m" "Merge queue row 1 (ant)"])
   c (calls "bob" [[6 "queue_land" {}]])
   d (calls "ant" [[7 "queue_landed" {}]])
   e (calls "bob" [[8 "queue_land" {}]])
   _ (test
      (has? (b 4) " green")
      (has? (b 5) "row 1 is ahead of row 2: the head lands first")
      (has? (c 6) "row 1 is still landing (merged, make test running); wait for its queue_landed")
      (has? (d 7) "landed: row 1 left")
      (has? (e 8) ("git merge --no-ff " + gu))
      (has? (e 8) "love bee --lock --out ") (has? (e 8) (w 'repo + "/out")) (has? (e 8) " -- make test"))
   0)

; a waiting join folds into the earliest waiting row ahead when the heads merge clean but for
; hot.prof; a conflict, or keep, keeps its slot
(: w (bq-world "autofold") lq bq-q
   (sha r) (bq-out (bq-git w ["rev-parse" r]))
   (branch nm files)
    (: _ (bq-git w ["checkout" "-q" "-b" nm "test"])
       _ (hark ["mkdir" "-p" (w 'repo + "/src/tools")])
       _ (map (\ f (: _ (bq-put (w 'repo + "/" + <f) (f 1)) (bq-git w ["add" <f]))) files)
       _ (bq-git w ["commit" "-q" "-m" nm])
       (bq-git w ["checkout" "-q" "test"]))
   _ (branch "p1" [["src/tools/hot.prof" "x\n"] ["p1.txt" "p1\n"]])
   _ (branch "p2" [["src/tools/hot.prof" "y\n"] ["p2.txt" "p2\n"]])
   _ (branch "c1" [["p1.txt" "other\n"]])
   _ (branch "k1" [["k1.txt" "k\n"]])
   _ (branch "e1" [["e1.txt" "e\n"]])
   calls (bq-calls w lq "")
   (join nm id br more) (calls nm [[id "queue_row" (foldl (\ t k (pin t k (more k))) {"state" "waiting" "branch" br "gated_head" (sha br)} (keys more))]])
   a (join "ant" 1 "p1" {"leader" "queen"})
   b (join "bob" 2 "p2" {})
   c (join "carol" 3 "c1" {})
   d (join "dan" 4 "k1" {"keep" "1"})
   e (join "eve" 5 "e1" {})
   q (bq-out (bq-git w ["cat-file" "-p" lq]))
   (row p) (: ls (filter (\ l (starts? l (p + " "))) (lines q)) (? (two? ls) (words <ls) ()))
   k0 (calls "dan" [[6 "queue_row" {"state" "waiting" "branch" "k1" "keep" "0"}]])
   q2 (bq-out (bq-git w ["cat-file" "-p" lq]))
   _ (test
      (row "1" 5 = "waiting")
      (has? (b 2) "folded into row 1 (ant)") (has? (b 2) "but for src/tools/hot.prof")
      (row "2" 5 = "folded-into-1")
      (row "3" 5 = "waiting") !(has? (c 3) "folded into")          ; p1.txt conflicts with row 1
      (row "4" 5 = "waiting") !(has? (d 4) "folded into")          ; keep
      (has? q "\nkeep 4\n")
      (has? (e 5) "folded into row 1 (ant)") (row "5" 5 = "folded-into-1")
      (has? (k0 6) "row now: 4 dan k1") !(has? q2 "\nkeep "))
   0)

; queue_gate: the head row's union gated by bee -- every owed lane through test/gate/lanes.sh (a stub
; here) under the heavy lock, the row green with each result or waiting with its reds and the rows owing
; them; refused off the head, or dirty; after a split only the red lanes run again. the first gate
; is asked by a server that stays up, so its card holds the name while the gate runs
(: w (bq-world "gate") lq bq-q
   (sha r) (bq-out (bq-git w ["rev-parse" r]))
   _ (hark ["mkdir" "-p" (w 'repo + "/test/gate")])
   _ (bq-put (w 'repo + "/test/gate/lanes.sh")
             (unlines ["d=out/lanes-gate; mkdir -p $d; echo \"$@\" > out/args; : > $d/summary; rc=0"
                       "for a in \"$@\"; do case $a in test*)"
                       "  if [ -f red-$a ]; then echo \"$a exit=1 secs=0\" >> $d/summary; rc=1"
                       "  else echo \"$a exit=0 secs=0\" >> $d/summary; fi;; esac; done"
                       "exit $rc"]))
   (calls nm cs) (calls-for nm cs "")
   ; ..and hold: the server's stdin stays open that much longer after the asks, the name its card's
   (calls-for nm cs hold)
    (: f (w 'dir + "/" + nm + ".in")
       _ (bq-put f (foldl (\ a c (a + json-show {"jsonrpc" "2.0" "id" <c "method" "tools/call"
                                                "params" {"name" (c 1) "arguments" (pin (c 2) "queue" lq)}} + "\n"))
                         "" cs))
       srv ("env BEE_NAME=" + nm + " " + bq-sq bq-love + " " + bq-sq bq-app + " --mcp")
       r (bq-sh w (? (0 < #hold) ("sh -c \"(cat " + bq-sq f + "; sleep " + hold + ") | " + srv + "\"")
                     (srv + " < " + bq-sq f)))
       (foldl (\ t l (: j (json-read l) (? (two? j) (pin t ((j 1) "id") ((j 1) "result" "content" 0 "text")) t)))
              {} (filter (\ l (0 < #l)) (lines (r 1)))))
   (row p) (: ls (filter (\ l (starts? l (p + " "))) (lines (bq-out (bq-git w ["cat-file" "-p" lq]))))
              (? (two? ls) <ls ""))
   m (sha "test")
   a (calls "ant" [[1 "queue_row" {"state" "waiting" "branch" "ant" "gated_on" m "gated_head" (sha "ant") "leader" "queen"}]])
   _ (bq-git w ["checkout" "-q" "ant"])
   g1 (calls-for "ant" [[2 "queue_gate" {"dir" (w 'repo)}]] "8")
   ok1 (bq-until (\ _ (has? (row "1") " green  #")) 300)
   args (bq-get (w 'repo + "/out/args"))
   _ (bq-git w ["checkout" "-q" "bob"])                              ; bob's change owes test_kore
   _ (hark ["mkdir" "-p" (w 'repo + "/src/apps/kore")])
   _ (bq-put (w 'repo + "/src/apps/kore/x.l") "x\n")
   _ (bq-git w ["add" "src"]) _ (bq-git w ["commit" "-q" "-m" "kore"])
   b (calls "bob" [[3 "queue_row" {"state" "waiting" "branch" "bob" "gated_on" (sha "ant") "gated_head" (sha "bob")}]])
   c (calls "carol" [[4 "queue_gate" {"dir" (w 'repo)}]])
   _ (bq-git w ["checkout" "-q" "bob"])
   _ (bq-put (w 'repo + "/f") "dirty\n")
   d (calls "bob" [[5 "queue_gate" {"dir" (w 'repo)}]])
   _ (bq-git w ["checkout" "-q" "--" "f"])
   _ (bq-put (w 'repo + "/red-test_kore") "")
   g2 (calls "bob" [[6 "queue_gate" {"dir" (w 'repo)}]])
   ok2 (bq-until (\ _ (has? (row "2") "test_kore=1")) 300)
   red (row "2")
   e (calls "carol" [[7 "queue_row" {"state" "waiting" "branch" "carol" "gated_on" (sha "bob") "gated_head" (sha "bob") "keep" "1"}]
                     [8 "queue_gate" {"dir" (w 'repo)}]])
   _ (hark ["rm" (w 'repo + "/red-test_kore")])
   g3 (calls "bob" [[9 "queue_gate" {"dir" (w 'repo) "lanes" "test_kore"}]])
   ok3 (bq-until (\ _ (has? (row "2") " green  #")) 300)
   args3 (bq-get (w 'repo + "/out/args"))
   ; a row gated on no commit plans test and test_slow alone: refused, never green on that
   n (calls "dan" [[10 "queue_row" {"state" "waiting" "branch" "dan" "keep" "1"}] [11 "queue_gate" {"dir" (w 'repo)}]])
   _ (test
      (has? (g1 2) "row 1 is gating at ")
      ok1 (has? (row "1") "  # gate ") (has? (row "1") "test_slow=0")
      (args = "-d out/lanes-gate --slow test test_slow\n")
      (has? (c 4) "you hold no row")
      (has? (d 5) "has changes not committed")
      (has? (g2 6) "row 2 is gating at ")
      ok2 (has? red " waiting  #") (has? red "test_kore=1") (has? red "| red: test_kore owed by 2 bob")
      (has? (e 8) "row 2 ahead is waiting")
      (has? (g3 9) "runs test_kore again")
      ok3 (args3 = "-d out/lanes-gate --slow test_kore test_slow\n")
      (has? (row "2") "test=0") (has? (row "2") "| stood: test") !(has? (row "2") "| red:")
      (has? (n 11) "is gated on -, not a commit") !(has? (row "4") " gating "))
   0)

; a heavy ticket needs a row carrying the tree's branch and HEAD, or --no-row, or no queue
(: w (bq-world "heavyrow") lq bq-q
   (sha r) (bq-out (bq-git w ["rev-parse" r]))
   (cli nm args) (bq-sh w ("env BEE_NAME=" + nm + " " + bq-sq bq-love + " " + bq-sq bq-app + " " + args))
   n0 (cli "ant" "--lock --heavy -- true")                                  ; no queue yet
   q0 (bq-put (w 'dir + "/q.in") (json-show {"jsonrpc" "2.0" "id" 1 "method" "tools/call"
                                            "params" {"name" "queue_row" "arguments" {"queue" lq "state" "waiting" "branch" "ant"}}}
                                 + "\n" + json-show {"jsonrpc" "2.0" "id" 2 "method" "tools/call"
                                                     "params" {"name" "lock_acquire" "arguments" {"name" "heavy" "kind" "heavy"}}}
                                 + "\n" + json-show {"jsonrpc" "2.0" "id" 3 "method" "tools/call"
                                                     "params" {"name" "lock_acquire" "arguments" {"name" "heavy" "kind" "heavy" "no_row" "a measurement"}}}
                                 + "\n"))
   t (cli "ant" ("--mcp < " + bq-sq (w 'dir + "/q.in")))
   n1 (cli "ant" "--lock --heavy -- true")                                  ; on test: no row carries it
   n2 (cli "ant" "--lock --heavy --no-row measure -- true")
   _ (bq-git w ["checkout" "-q" "ant"])
   n3 (cli "ant" "--lock --heavy -- true")                                  ; row 1 carries ant
   _ (test
      (<n0 = 0)
      (has? (t 1) "\"id\":2") (has? (t 1) "heavy lanes run only in the queue")
      (has? (t 1) "granted heavy")
      (<n1 = 1) (has? (n1 1) "no row of refs/queue/test carries test")
      (<n2 = 0) (<n3 = 0))
   0)

(hark ["rm" "-rf" bq-root])
(test_fin (), puts "beeq: ok", putc 10, 0)
