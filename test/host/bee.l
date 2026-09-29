; --- test/host/bee.l: bee, the coding agent, against a model played here -----------
; a twirled listener plays the model on loopback, each connection answered by the next
; canned stream, and bee runs as a child of its own in a scratch directory with HOME
; there too, so no one's ~/.love/etc/bee.l speaks. the wire is plain http to this
; machine, which bee allows and carries no key over.
;   cat test/00-init.l test/host/bee.l | out/love
(borrow 'json)

(: cr-home (cwd 0)
   cr-love (: l <cmdline (l 0 = 47 ? l (cr-home + "/" + l)))
   cr-app (cr-home + "/apps/bee.l")
   ; every path this lays is the pid's own, so two runs over one out/ keep apart
   cr-root (cr-home + "/out/.bee-" + show (getpid 0))
   _ (mkdir cr-root 493)
   (cr-put d nm s) (: p (open (d + "/" + nm) "w") _ (say p s) (close p))
   (cr-get p) (: f (open p "r") (hot? f ? (: s (slurp f) _ (close f) s) ()))
   (cr-dir nm cfg) (: d (cr-root + "/" + nm) _ (mkdir d 493) _ (cr-put d ".bee.l" cfg) d)

   ; --- the model: 'q the answers still to give, 'got the requests heard, newest first ---
   cr-box {'q () 'got ()}
   ; a port of this run's own: two gates at once must not share a mock, so start from the
   ; pid and step past any port already taken
   cr-pl (: (try p n) (: l (listen p) (? (!(nom? l) || n <= 0) [p l] (try (p + 1) (n - 1))))
            (try (20000 + getpid 0 % 20000) 200))
   cr-port <cr-pl
   cr-l (cr-pl 1)
   cr-header (cite 'kore 'wg-header)
   cr-digits (cite 'kore 'wg-digits)
   cr-find (cite 'kore 'wg-find)
   (cr-in s p) (0 <= cr-find s p 0)
   (cr-hex n) (? (n < 16) (string ("0123456789abcdef" n)) (cr-hex (n // 16) + cr-hex (n % 16)))
   (cr-head c a) (: b (see c) (? (b < 0) a
                                 (: a2 (a + string b) (? (cr-in a2 "\r\n\r\n") a2 (cr-head c a2)))))
   (cr-take c n a) (? (#a < n) (: b (see c) (? (b < 0) a (cr-take c n (a + string b)))) a)
   (cr-serve c)
    (: hd (cr-head c "")
       n (: v (cr-header hd "content-length") (? (string? v) (cr-digits v) 0))
       q (cr-box 'q)
       _ (pins cr-box 'q >q 'got ((hd + cr-take c n "") . cr-box 'got))
       _ (say c (two? q ? <q "HTTP/1.1 500 no more\r\ncontent-length: 0\r\n\r\n"))
       _ (flush c)
       (close c))
   cr-srv (twirl (\ _ ((: (g k) (: _ (await cr-l) c (accept cr-l) _ (cr-serve c) (g k))) 0)) 0)
   (cr-body req) (: k (cr-find req "\r\n\r\n" 0) ((json-read (snip req (k + 4) #req)) 1))

   ; a stream said as server-sent events, whole or chunked
   (cr-sse evs) (foldl (\ a e (a + "data: " + (string? e ? e (json-show e)) + "\n\n")) "" evs)
   (cr-ok s) ("HTTP/1.1 200 OK\r\ncontent-type: text/event-stream\r\n\r\n" + s)
   (cr-chunked s)
    ("HTTP/1.1 200 OK\r\ncontent-type: text/event-stream\r\ntransfer-encoding: chunked\r\n\r\n"
     + (: (go i a) (? (#s <= i) (a + "0\r\n\r\n")
                      (: d (snip s i (min #s (i + 29)))
                         (go (i + 29) (a + (cr-hex #d) + "\r\n" + d + "\r\n"))))
          (go 0 "")))

   ; bee in its directory -> [exit output], its stdout and err one pipe. the model is
   ; served meanwhile: see parks only this task, gather never blocks
   (cr-reap p) (: s (gather p) (? (two? s) <s (nom? s) -1 (: _ (rest 5) (cr-reap p))))
   (cr-run d env args)
    (: pp (pipe 0) nul (openfd "/dev/null" 0)
       cmd ("cd '" + d + "' && exec env HOME='" + d + "' " + env + " '" + cr-love + "' '" + cr-app + "' " + args)
       p (spawnio ["sh" "-c" cmd] nul >pp >pp [<pp] -1 0)
       _ (close >pp) _ (close nul)
       q (fdopen <pp)
       (go a) (: c (see q) (? (c < 0) a (: _ (unsee q c) (go (a + chug q)))))
       o (go "")
       _ (close q)
       [(cr-reap p) o])
   (cr-serves rs) (pins cr-box 'q rs 'got ())
   (cr-heard _) (rev (cr-box 'got))
   cr-url ("http://127.0.0.1:" + show cr-port))

; --- chat completions: a thought, a shell call in our lush, then the answer ----------
; the call's arguments come in two pieces, the first stream chunked; the tool runs in
; this binary's lush, and its output goes back as a tool message on the call's id
(: cr-a (cr-dir "oai" ("(api openai)\n(url \"" + cr-url + "/v1/chat/completions\")\n(model mock-model)\n"))
   _ (cr-put cr-a "AGENTS.md" "the frog rule: always croak twice\n")
   _ (cr-put cr-a "CLAUDE.md" "the toad rule: hop once\n@AGENTS.md\n")
   call1 "{\"command\": \"printf hi > ma"
   call2 "de.txt; echo made\"}"
   _ (cr-serves
      [(cr-chunked (cr-sse
         [{"choices" [{"delta" {"reasoning" "the user wants a file"}}]}
          {"choices" [{"delta" {"content" "Making it."}}]}
          {"choices" [{"delta" {"tool_calls" [{"index" 0 "id" "c1" "type" "function"
                                               "function" {"name" "shell" "arguments" call1}}]}}]}
          {"choices" [{"delta" {"tool_calls" [{"index" 0 "function" {"arguments" call2}}]}}]}
          {"choices" [{"delta" {} "finish_reason" "tool_calls"}]}
          "[DONE]"]))
       (cr-ok (cr-sse [{"choices" [{"delta" {"content" "All done."}}]}
                       {"choices" [{"delta" {} "finish_reason" "stop"}]}
                       {"choices" [] "usage" {"prompt_tokens" 900 "completion_tokens" 12}}
                       "[DONE]"]))])
   r (cr-run cr-a "OPENAI_API_KEY=sk-never-sent" "-y 'make the file'")
   o (r 1)
   h (cr-heard 0)
   b1 (cr-body (h 0)) b2 (cr-body (h 1))
   m1 (b1 "messages") m2 (b2 "messages")
   tm (: t (filter (\ m (m "role" = "tool")) m2) (two? t ? <t {}))
   _ (test
      (0 = <r)
      (2 = #h)
      (cr-in o "Making it.") (cr-in o "All done.")
      !(cr-in o "the user wants a file")                     ; thinking is not said down a pipe
      ("hi" = cr-get (cr-a + "/made.txt"))
      ("mock-model" = b1 "model")
      (json-true = b1 "stream")
      (json-true = b1 "stream_options" "include_usage")       ; the gauge's count
      ("system" = m1 0 "role")
      (cr-in (m1 0 "content") "the frog rule")               ; the directory's AGENTS.md
      (cr-in (m1 0 "content") "the toad rule")               ; ..and its CLAUDE.md beside it
      (cr-in (m1 0 "content") "platform: ")                  ; the environment, from love's own verbs
      (cr-in (m1 0 "content") "date: 20")
      (cr-in (m1 0 "content") " source DIR")                 ; the briefing: how to lay the source
      (elem "shell" (map (\ t (t "function" "name")) (b1 "tools")))
      ("c1" = tm "tool_call_id")
      (cr-in (tm "content") "made") (cr-in (tm "content") "[exit 0]")
      ("c1" = (: a (filter (\ m (m "role" = "assistant")) m2) (<a "tool_calls" 0 "id")))
      !(cr-in (h 0) "sk-never-sent") !(cr-in (h 1) "sk-never-sent"))
   0)

; --- the messages api: thinking, an edit, and the answer ------------------------------
; the thinking block goes back as it came, signature and all, ahead of the tool_use
(: cr-b (cr-dir "anth" ("(api anthropic)\n(url \"" + cr-url + "/v1/messages\")\n(model claude-mock)\n"))
   _ (cr-put cr-b "notes.txt" "one\ntwo\nthree\n")
   ed (json-show {"path" "notes.txt" "old_text" "two" "new_text" "TWO"})
   (ev t x) (pin x "type" t)
   _ (cr-serves
      [(cr-ok (cr-sse
         [(ev "message_start" {"message" {"id" "m1" "content" []
                                           "usage" {"input_tokens" 40 "cache_read_input_tokens" 800
                                                    "cache_creation_input_tokens" json-null "output_tokens" 1}}})
          (ev "content_block_start" {"index" 0 "content_block" {"type" "thinking" "thinking" "" "signature" ""}})
          (ev "content_block_delta" {"index" 0 "delta" {"type" "thinking_delta" "thinking" "an edit will do"}})
          (ev "content_block_delta" {"index" 0 "delta" {"type" "signature_delta" "signature" "sig=="}})
          (ev "content_block_stop" {"index" 0})
          (ev "content_block_start" {"index" 1 "content_block" {"type" "tool_use" "id" "t1" "name" "edit_file" "input" {}}})
          (ev "content_block_delta" {"index" 1 "delta" {"type" "input_json_delta" "partial_json" (snip ed 0 11)}})
          (ev "content_block_delta" {"index" 1 "delta" {"type" "input_json_delta" "partial_json" (snip ed 11 #ed)}})
          (ev "content_block_stop" {"index" 1})
          (ev "message_delta" {"delta" {"stop_reason" "tool_use"} "usage" {"output_tokens" 30}})
          (ev "message_stop" {})]))
       (cr-chunked (cr-sse
         [(ev "content_block_start" {"index" 0 "content_block" {"type" "text" "text" ""}})
          (ev "content_block_delta" {"index" 0 "delta" {"type" "text_delta" "text" "Edited: é."}})
          (ev "content_block_stop" {"index" 0})
          (ev "message_delta" {"delta" {"stop_reason" "end_turn"}})
          (ev "message_stop" {})]))])
   r (cr-run cr-b "ANTHROPIC_API_KEY=sk-never-sent" "-y 'fix the notes'")
   o (r 1)
   h (cr-heard 0)
   b2 (cr-body (h 1))
   back (: a (filter (\ m (m "role" = "assistant")) (b2 "messages")) (<a "content"))
   res (: u (filter (\ m (m "role" = "user" && !(string? (m "content")))) (b2 "messages"))
          (<u "content" 0))
   _ (test
      (0 = <r)
      (2 = #h)
      (cr-in o "Edited: é.")
      ("one\nTWO\nthree\n" = cr-get (cr-b + "/notes.txt"))
      (cr-in (h 0) "anthropic-version: 2023-06-01")
      ("claude-mock" = cr-body (h 0) "model")
      ("thinking" = back 0 "type") ("sig==" = back 0 "signature") ("an edit will do" = back 0 "thinking")
      ("tool_use" = back 1 "type") ("TWO" = back 1 "input" "new_text")
      ("t1" = res "tool_use_id") !(res "is_error")
      !(cr-in (h 0) "sk-never-sent") !(cr-in (h 1) "sk-never-sent"))
   0)

; --- sessions and messages -----------------------------------------------------------------
; a session named by BEE_NAME settles in HOME's hive for its run. its shell sends it a
; message through the verb, and list_sessions finds it; the message rides the next request
; beside the tool results, and the cell is gone once the run ends
(: cr-m (cr-dir "talk" ("(api anthropic)\n(url \"" + cr-url + "/v1/messages\")\n(model claude-mock)\n"))
   (ev t x) (pin x "type" t)
   (use i id nm in)
    [(ev "content_block_start" {"index" i "content_block" {"type" "tool_use" "id" id "name" nm "input" {}}})
     (ev "content_block_delta" {"index" i "delta" {"type" "input_json_delta" "partial_json" (json-show in)}})
     (ev "content_block_stop" {"index" i})]
   _ (cr-serves
      [(cr-ok (cr-sse ([(ev "message_start" {"message" {"id" "m1" "content" []}})]
                       + use 0 "s1" "shell" {"command" "love bee --send tester 'hello from a shell'"}
                       + use 1 "s2" "list_sessions" {}
                       + [(ev "message_delta" {"delta" {"stop_reason" "tool_use"}}) (ev "message_stop" {})])))
       (cr-ok (cr-sse [(ev "content_block_start" {"index" 0 "content_block" {"type" "text" "text" ""}})
                       (ev "content_block_delta" {"index" 0 "delta" {"type" "text_delta" "text" "Heard."}})
                       (ev "content_block_stop" {"index" 0})
                       (ev "message_delta" {"delta" {"stop_reason" "end_turn"}})
                       (ev "message_stop" {})]))])
   ; an sb hub whose queue/ ledger the prompt should quote
   hub (cr-root + "/hub")
   _ (mkdir hub 493)
   _ (cr-put hub "q" "leader tester\n66 tester bee green\n")
   _ (hark [cr-love "sb" "-C" hub "ledger" "queue/main" "--was" "none" (hub + "/q")])
   r (cr-run cr-m ("BEE_NAME=tester SB_HUB='" + hub + "'") "-y 'talk to yourself'")
   h (cr-heard 0)
   b1 (cr-body (h 0))
   u2 (: us (filter (\ m (m "role" = "user" && !(string? (m "content")))) (cr-body (h 1) "messages"))
         (<us "content"))
   (block ty) (filter (\ b (b "type" = ty)) u2)
   res (map (\ b (b "content")) (block "tool_result"))
   txt (foldl (\ a b (a + b "text")) "" (block "text"))
   after (cr-run cr-m "" "--list")
   _ (test
      (0 = <r)
      (2 = #h)
      (cr-in (b1 "system") "session named tester")            ; the prompt names the session
      (cr-in (b1 "system") "--- sb ledger queue/main")        ; and quotes the hub's queue
      (cr-in (b1 "system") "66 tester bee green")
      (elem "send_message" (map (\ t (t "name")) (b1 "tools")))
      (cr-in (res 0) "[exit 0]")
      (cr-in (res 1) "tester (you)")
      (cr-in txt "<message from=\"tester\">") (cr-in txt "hello from a shell")
      (cr-in (after 1) "no bee sessions are running"))
   0)

; --- jobs and workers -----------------------------------------------------------------------
; a job starts at once and runs in its own group; check_job sees it running and stop_job ends
; it. a worker spawned from a shell settles in its own directory, serves, and stops
(: cr-j (cr-dir "jobs" ("(api anthropic)\n(url \"" + cr-url + "/v1/messages\")\n(model claude-mock)\n"))
   (ev t x) (pin x "type" t)
   (one id nm in)
    (cr-ok (cr-sse [(ev "content_block_start" {"index" 0 "content_block" {"type" "tool_use" "id" id "name" nm "input" {}}})
                    (ev "content_block_delta" {"index" 0 "delta" {"type" "input_json_delta" "partial_json" (json-show in)}})
                    (ev "content_block_stop" {"index" 0})
                    (ev "message_delta" {"delta" {"stop_reason" "tool_use"}})]))
   (done _) (cr-ok (cr-sse [(ev "message_delta" {"delta" {"stop_reason" "end_turn"}})]))
   _ (cr-serves [(one "a" "start_job" {"command" "sleep 30; echo never"})
                 (one "b" "check_job" {"id" "j1"})
                 (one "c" "stop_job" {"id" "j1"})
                 (done 0)])
   r (cr-run cr-j "BEE_NAME=jobber" "-y 'run and stop a job'")
   h (cr-heard 0)
   (res k) (: u (filter (\ m (m "role" = "user" && !(string? (m "content")))) (cr-body (h k) "messages"))
              ((u (#u - 1)) "content" 0 "content"))
   wt (cr-j + "/wt")
   _ (mkdir wt 493)
   _ (cr-put wt ".bee.l" ("(api anthropic)\n(url \"" + cr-url + "/v1/messages\")\n(model claude-mock)\n"))
   _ (cr-serves [(done 0)])
   sp (cr-run cr-j "" ("--spawn w1 '" + wt + "' 'look around'"))
   ls (cr-run cr-j "" "--list")
   st (cr-run cr-j "" "--stop w1")
   _ (rest 300)
   gone (cr-run cr-j "" "--list")
   _ (test
      (0 = <r) (4 = #h)
      (cr-in (res 1) "started j1")
      (cr-in (res 2) "running for") (cr-in (res 2) "sleep 30")
      (cr-in (res 3) "stopped j1")
      (0 = <sp) (cr-in (sp 1) "w1 is serving")
      (cr-in (ls 1) "w1  idle") (cr-in (ls 1) "/wt")
      (0 = <st) (cr-in (st 1) "stopped w1")
      !(cr-in (gone 1) "w1"))
   0)

; --- queue watching ---------------------------------------------------------------------------
; a serving bee with a row in its hub's queue hears the row it stacks on move and the leader
; change, and hears nothing of its own edits
(: cr-w (cr-dir "watch" "")
   hub (cr-w + "/hub") wt (cr-w + "/wt")
   _ (mkdir hub 493) _ (mkdir wt 493)
   _ (cr-put wt ".bee.l" ("(api anthropic)\n(url \"" + cr-url + "/v1/messages\")\n(model claude-mock)\n(queue-watch 1)\n"))
   (ok0 _) (cr-ok (cr-sse [{"type" "message_delta" "delta" {"stop_reason" "end_turn"}}]))
   (queue ls) (: _ (cr-put cr-w "q" (foldl (\ a l (a + l + "\n")) "" ls))
                 id (: r (hark [cr-love "sb" "-C" hub "ledger" "queue/main" "--id"]) (? (two? r) (: s >r (snip s 0 (#s - 1))) "none"))
                 (hark [cr-love "sb" "-C" hub "ledger" "queue/main" "--was" id (cr-w + "/q")]))
   _ (queue ["leader bob" "4 bob b1 aaa h1 gating" "5 alice b2 h1 h2 waiting"])
   _ (cr-serves [(ok0 0) (ok0 0) (ok0 0)])
   sp (cr-run cr-w ("SB_HUB='" + hub + "'") ("--spawn alice '" + wt + "' 'wait for the queue'"))
   _ (rest 2500)
   _ (queue ["leader carol" "4 bob b1 aaa h9 green" "5 alice b2 h1 h2 waiting"])
   _ (rest 3500)
   _ (queue ["leader carol" "4 bob b1 aaa h9 green" "5 alice b2 h9 h4 gating"])  ; her own edit
   _ (rest 3500)
   h (cr-heard 0)
   st (cr-run cr-w "" "--stop alice")
   said (foldl (\ a r (a + r)) "" h)
   _ (test
      (0 = <sp)
      (2 = #h)                                                  ; the prompt, then one wake
      (cr-in said "from=\\\"queue-watch\\\"")
      (cr-in said "the row yours stacks on moved: 4 (bob, b1) at h9, green (was h1, gating)")
      (cr-in said "the leader is now carol")
      (0 = <st))
   0)

; --- what bee will not do ---------------------------------------------------------------
; plain http off this machine is refused before any dial; a model that says no is told;
; a remote endpoint wants its key before anything is sent
(: cr-c (cr-dir "far" "(api openai)\n(url \"http://192.0.2.1:9/v1/chat/completions\")\n(model m)\n")
   rf (cr-run cr-c "OPENAI_API_KEY=sk-never-sent" "'hello'")
   cr-d (cr-dir "no" ("(api openai)\n(url \"" + cr-url + "/v1/chat/completions\")\n(model m)\n"))
   _ (cr-serves ["HTTP/1.1 400 Bad Request\r\ncontent-type: application/json\r\n\r\n{\"error\": {\"message\": \"no such model\"}}"])
   rn (cr-run cr-d "" "'hello'")
   cr-e (cr-dir "key" "(key-env BEE_TEST_NO_KEY)\n")
   rk (cr-run cr-e "" "'hello'")
   _ (test
      (cr-in (rf 1) "plain http reaches this machine alone")
      (cr-in (rn 1) "400") (cr-in (rn 1) "no such model")
      (1 = <rk) (cr-in (rk 1) "set BEE_TEST_NO_KEY"))
   0)

(hark ["rm" "-rf" cr-root])
(test_fin (), puts "bee: ok", putc 10, 0)
