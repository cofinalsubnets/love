; apps/crow.l -- a coding agent: a model over its api, and four tools it may call here --
; read_file, write_file, edit_file, shell. all but a read ask y/n first.
;
;   out/love apps/crow.l [-y] [--plain] [prompt ..]     one prompt, the screen, or a > loop
;
; the settings are salt's: ~/.love/etc/crow.l, then ./.crow.l over it, each a form per line:
;   (api anthropic)       or openai: chat completions, what ollama, llama-server and most hosts speak
;   (url "https://..")    the endpoint, http only to this machine
;   (model NAME)          claude-opus-5 on anthropic; openai has no default
;   (key-env VAR)         where the key is: ANTHROPIC_API_KEY, or OPENAI_API_KEY
;   (max-tokens N)        64000 on anthropic; openai leaves it to the server
;   (shell WORD ..)       the shell a command line runs in; lush -a, this binary's own
; the answer streams: text prints as it comes. a key goes out only over tls, and only to a
; peer tls-open verified: its chain to a root the host trusts, and its name.
(borrow 'posix)
(borrow 'json)

(:
   dial (cite 'tls 'tls-dial)
   tsay (cite 'tls 'tls-say)
   hear (cite 'tls 'tls-hear)
   topen (cite 'tls 'tls-open)                             ; () on a binary that cannot verify
   find (cite 'kore 'wg-find)
   header (cite 'kore 'wg-header)
   digits (cite 'kore 'wg-digits)

   crow-salt ((cite 'salt 'salt) 'crow)
   (word w) (string? w ? w (show w))
   (setting k d) (: v (peep crow-salt k ()) (two? v ? (word <v) d))
   (slurp-file p) (: f (open p "r") (? (hot? f) (: s (slurp f) _ (close f) s)))
   (spit-file p s) (: f (open p "w") (? (hot? f) (: _ (say f s) _ (close f) 1)))

   ; --- where the model is ---
   crow-api (setting 'api "anthropic")
   crow-oai? (crow-api = "openai")
   crow-model (setting 'model (crow-oai? ? "" "claude-opus-5"))
   crow-url (setting 'url (crow-oai? ? "https://api.openai.com/v1/chat/completions"
                                       "https://api.anthropic.com/v1/messages"))
   crow-at ((cite 'kore 'wg-url) crow-url)                   ; [tls? host port path] | ()
   crow-host (? (two? crow-at) (crow-at 1) "")
   crow-key-env (setting 'key-env (crow-oai? ? "OPENAI_API_KEY" "ANTHROPIC_API_KEY"))
   crow-max (: m (peep crow-salt 'max-tokens ()) (? (two? m) <m (crow-oai? ? () 64000)))
   ; this machine, where plain http is allowed and no key is wanted
   crow-local? (elem crow-host ["localhost" "127.0.0.1" "::1"])
   ; claude's newest take the server-side fallback on a refusal
   crow-fallbacks? (!crow-oai? && (starts? crow-model "claude-opus-5" || starts? crow-model "claude-fable"
                                   || starts? crow-model "claude-mythos"))
   ; the models whose thinking comes back empty unless a summary is asked for; (thinking off)
   ; leaves the request as it is
   crow-summarize? (!crow-oai? && setting 'thinking "on" != "off"
                    && (starts? crow-model "claude-opus-5" || starts? crow-model "claude-fable"
                        || starts? crow-model "claude-mythos" || starts? crow-model "claude-sonnet-5"
                        || starts? crow-model "claude-opus-4-8" || starts? crow-model "claude-opus-4-7"))
   crow-cap 30000                                           ; a tool answer's bytes, at most

   (prop desc) {"type" "string" "description" desc}
   (tool name desc props req)
    {"name" name "description" desc "eager_input_streaming" json-true
     "input_schema" {"type" "object" "properties" props "required" req}}
   ; --- the shell ---
   ; (shell WORD ..) is the argv a command line follows after -c, (shell lush -a) when
   ; unset: lush first is this binary's own, -a its verbs ahead of PATH; any other word
   ; runs as written
   crow-shell (: s (peep crow-salt 'shell ()) (two? s ? (map word s) ["lush" "-a"]))
   crow-ours? (<crow-shell = "lush")
   ; lush's verbs lead only in its autonomous mode; gregarious (its default) puts PATH first
   crow-verbs-lead? (crow-ours? && (elem "-a" crow-shell || elem "--autonomous" crow-shell))
   crow-self ((cite 'posix 'selfpath) 0)
   (shell-argv cmd) ((crow-ours? ? (crow-self . crow-shell) crow-shell) + ["-c" cmd])
   crow-shname (foldl (\ a w (a + " " + w)) <crow-shell >crow-shell)
   crow-verbs (foldl (\ a v (a + " " + v)) "" (sort (map show (keys (cite 'verbs 'tab)))))

   crow-tools
    [(tool "read_file" "Read a file and answer its text."
           {"path" (prop "the file's path")} ["path"])
     (tool "write_file" "Write text to a file, replacing it whole."
           {"path" (prop "the file's path") "content" (prop "the new text")} ["path" "content"])
     (tool "edit_file" "Replace old_text, which must occur exactly once, with new_text."
           {"path" (prop "the file's path") "old_text" (prop "the text now there")
            "new_text" (prop "its replacement")} ["path" "old_text" "new_text"])
     (tool "shell" ("Run a command line in " + crow-shname + ". Answers stdout and stderr, then "
                    + "the exit status." + (crow-verbs-lead? ? (" The commands the system prompt names "
                    + "are love's own userland (kore); anything else comes from PATH.") ""))
           {"command" (prop "the command line")} ["command"])]

   ; --- the project's own instructions ---
   ; from / down to the working directory, each directory's AGENTS.md, else its CLAUDE.md:
   ; the files other agents read, so one file instructs them all
   crow-cwd (: d (getenv "PWD") (? (string? d && 0 < #d) d "."))
   ; "" for the root, then "/home", "/home/gwen" .. the working directory
   crow-dirs (foldl (\ a p (a + [(a (#a - 1) + "/" + p)]))
                    [""] (filter (\ p (0 < #p)) ((cite 'kore 'usplit) 47 crow-cwd)))
   (instr-in d) (: a (slurp-file (d + "/AGENTS.md"))
                   (? (string? a) [(d + "/AGENTS.md") a]
                      (: c (slurp-file (d + "/CLAUDE.md")) (? (string? c) [(d + "/CLAUDE.md") c]))))
   crow-instr (filter two? (map instr-in crow-dirs))
   (clip0 s) (#s <= 40000 ? s (snip s 0 40000 + "\n[cut]"))

   crow-system
    ("You are crow, a coding agent in a terminal. The working directory is " + crow-cwd
     + ". Use the tools to look before you change things, and keep replies short. Commands run in `"
     + crow-shname + "`."
     + (crow-ours? ? " That is lush, a POSIX shell, not bash: write POSIX sh." "")
     + (crow-verbs-lead? ? (" These commands are love's own implementations, POSIX in their "
        + "flags, so a GNU-only option may be refused:" + crow-verbs + ".") "")
     + (two? crow-instr
        ? ("\n\nThe project's instructions follow, from the root down; the nearer file wins.\n"
           + foldl (\ a p (a + "\n--- " + <p + " ---\n" + clip0 (p 1))) "" crow-instr)
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
    (: tls? <crow-at port (crow-at 2)
       keyed (tls? && string? key && 0 < #key)
       ("POST " + crow-at 3 + " HTTP/1.1\r\nHost: " + crow-host
        + (port = (tls? ? 443 80) ? "" (":" + show port))
        + (? crow-oai? (keyed ? ("\r\nauthorization: Bearer " + key) "")
             ((keyed ? ("\r\nx-api-key: " + key) "")
              + "\r\nanthropic-version: 2023-06-01"
              + (crow-fallbacks? ? "\r\nanthropic-beta: server-side-fallback-2026-07-01" "")))
        + "\r\ncontent-type: application/json"
        + "\r\ncontent-length: " + show #body
        + "\r\nConnection: close\r\n\r\n" + body))

   ; one POST, its head read -> a reader carrying 'code, or () for a dead wire. plain http
   ; reaches this machine alone and carries no key; a key goes over tls only to a peer
   ; tls-open verified, and not at all from a binary without it. a refusal is a reader
   ; whose 'code is the reason
   (crow-open key body)
    (: tls? <crow-at keyed (string? key && 0 < #key) port (crow-at 2)
       (? (!tls? && !crow-local?) {'code "plain http reaches this machine alone"}
          (tls? && keyed && !(lit? topen)) {'code "this binary's tls cannot verify a certificate"}
          (: t (? !tls? ((cite 'dns 'dial) crow-host port)
                  (lit? topen) (topen crow-host port 'verify)
                  (dial crow-host port))
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

   ; a streamed answer -> [stop blocks]; [() err] on an error event. a tool's input arrives
   ; as json pieces in js, read whole at its block's stop
   (stream f r)
    (: bs (tablet 8) js (tablet 8)
       (go stop)
        (: e (event r)
           (? !(tablet? e) [stop (map bs (sort (keys bs)))]
              (: i (e "index") d (e "delta") b (bs i)
                 (e "type" @
                  "content_block_start" (pin bs i (e "content_block"), go stop)
                  "content_block_delta"
                   (d "type" @
                    "text_delta" (: x (d "text") _ ((f 'text) x)
                                    (pin b "text" (peep b "text" "" + x), go stop))
                    "input_json_delta" (pin js i (peep js i "" + d "partial_json"), go stop)
                    "thinking_delta" (: x (d "thinking") _ ((f 'think) x)
                                        (pin b "thinking" (peep b "thinking" "" + x), go stop))
                    "signature_delta" (pin b "signature" (peep b "signature" "" + d "signature"), go stop)
                    (go stop))
                  "content_block_stop"
                   (b "type" @
                    ("text" || "thinking") ((f 'break) 0, go stop)
                    "tool_use" (: j (json-read (peep js i "{}")) (pin b "input" (two? j ? (j 1) {}), go stop))
                    (go stop))
                  "message_delta" (go (e "delta" "stop_reason"))
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
          (map (\ b {"role" "tool" "tool_call_id" (b "tool_use_id") "content" (b "content")})
               (filter (\ b (b "type" = "tool_result")) c))))

   ; its stream as the same [stop blocks]: the content pieces one text block, each tool
   ; call a tool_use block gathered by its index, the finish said as claude says it. the
   ; reasoning (ollama's reasoning, deepseek's and vllm's reasoning_content) is shown and
   ; kept nowhere: chat completions takes no reasoning back. st 'in is what is open, a
   ; reasoning run or a text one, and a turn from one to the other breaks it
   (stream-oai f r)
    (: txt {"type" "text" "text" ""} calls (tablet 4) js (tablet 4) st {'in 0}
       (into k) (? (st 'in = k) 0 (: _ (? (st 'in != 0) ((f 'break) 0) 0) (pin st 'in k)))
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
                 _ (? (string? rz && 0 < #rz) (: _ (into 'think) ((f 'think) rz)) 0)
                 x (? (tablet? d) (d "content"))
                 _ (? (string? x && 0 < #x)
                      (: _ (into 'text) _ ((f 'text) x) (pin txt "text" (txt "text" + x)))
                      0)
                 tcs (? (tablet? d) (d "tool_calls"))
                 _ (? (two? tcs) (: _ (into 0) (map (\ tc (call (peep tc "index" 0) tc)) tcs)) 0)
                 fr (? (tablet? c) (c "finish_reason"))
                 (go (? (string? fr)
                        (fr @ "tool_calls" "tool_use" "stop" "end_turn" "length" "max_tokens"
                              "content_filter" "refusal" fr)
                        stop)))))
       (go ()))

   ; msgs newest first, as the loop keeps them
   (crow-body msgs)
    (: b (? crow-oai?
            {"model" crow-model "stream" json-true "tools" (map oai-tool crow-tools)
             "messages" ({"role" "system" "content" crow-system} . catmap oai-msg (rev msgs))}
            {"model" crow-model "system" crow-system "stream" json-true
             "tools" crow-tools "messages" (rev msgs) "cache_control" {"type" "ephemeral"}})
       _ (? (crow-max != ()) (pin b (crow-oai? ? "max_tokens" "max_tokens") crow-max) 0)
       _ (? crow-fallbacks? (pin b "fallbacks" "default") 0)
       _ (? crow-summarize? (pin b "thinking" {"type" "adaptive" "display" "summarized"}) 0)
       (json-show b))

   ; --- the tools ---
   (clip s) (#s <= crow-cap ? s (snip s 0 crow-cap + "\n[cut at " + show crow-cap + " bytes]"))

   ; the child's output read by see, which parks this task alone, and its exit by gather,
   ; which never blocks: the screen keeps painting while a command runs. stdin is /dev/null
   (shell-out cmd)
    (: pp (pipe 0) nul (openfd "/dev/null" 0)
       p (spawnio (shell-argv cmd) nul >pp >pp [<pp] -1 0)
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
    (: t (filter (\ x (x "name" = name)) crow-tools)
       (two? t && tablet? in && !(two? (filter (\ k !(string? (in k))) (<t "input_schema" "required")))))

   ; a tool call -> [ok? text]. the face runs the shell, so the screen can show it running
   (run f h name in)
    (? !(valid? name in) [0 ("no such tool, or its input is missing a field: " + name)]
       (name @
        "read_file"  (: s (slurp-file (in "path")) (? (string? s) [1 (clip s)] [0 ("cannot read " + in "path")]))
        "write_file" (? (spit-file (in "path") (in "content")) [1 ("wrote " + in "path")] [0 ("cannot write " + in "path")])
        "edit_file"  (edit (in "path") (in "old_text") (in "new_text"))
        "shell"      [1 (clip ((f 'shell) h (in "command")))]))

   ; a tool as the transcript names it: the shell by its own name
   (shown name) (name = "shell" ? <crow-shell name)
   (brief name in)
    (? !(valid? name in) "(malformed input)"
       (name @ "shell" (in "command")
               "edit_file" (in "path" + ": " + show #(in "old_text") + " bytes -> " + show #(in "new_text"))
               (in "path")))

   ; one tool_use block -> its tool_result, asking first unless yes or a read
   (answer f b)
    (: name (b "name") in (b "input")
       h ((f 'tool) name in)
       r (? !(valid? name in) (run f h name in)
            (f 'yes || name = "read_file" || ((f 'ask) h) = 1) (run f h name in)
            [0 "the user declined"])
       _ ((f 'done) h r)
       t {"type" "tool_result" "tool_use_id" (b "id") "content" (r 1)}
       (? <r t (pin t "is_error" json-true)))

   ; a user turn to its end -> the messages after it, or () when the wire failed
   (turn key f msgs)
    (: r (crow-open key (crow-body msgs))
       (? !(tablet? r) ((f 'note) "no answer", ())
          !(charm? (r 'code))
           ((f 'note) (crow-host + " refused: " + (r 'code) + "; the key stays here"), ())
          !(r 'code = 200)
           (: j (json-read (drain r)) _ (close (sock r))
              ((f 'note) (show (r 'code) + " " + (two? j ? (json-show (j 1 "error")) "")), ()))
          (: _ ((f 'wire) (sock r))
             s (? crow-oai? (stream-oai f r) (stream f r)) _ (close (sock r)) _ ((f 'wire) ())
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
   crow-tty? (two? (tty 1))
   (plain yes)
    {'yes yes
     'text (\ x (puts x, flush out))
     'think (\ x (? crow-tty? (: _ (puts (esc + "[2;3m" + x + esc + "[0m")) (flush out)) 0))
     'break (\ _ (puts "\n"))
     'note (\ s (puts ("\ncrow: " + s + "\n")))
     'wire (\ s 0)
     'tool (\ name in (puts ("  " + shown name + " " + brief name in + "\n")))
     'ask (\ h (? (ask "  run? [y/N] ") 1 0))
     'done (\ h r 0)
     'shell (\ h cmd (shell-out cmd))}
   (repl key f msgs)
    (: _ (puts "> ") _ (flush out) l (line 0)
       (? !(string? l) 0
          (#l = 0) (repl key f msgs)
          (: m (turn key f ((user l) . msgs)) (repl key f (two? m ? m msgs)))))

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

   ; a unified diff, coloured, at most n lines
   (diffs a b n)
    (: ls (lines ((cite 'kore 'udiff) "a" "b" a b))
       body (drop 2 ls)                                 ; the --- +++ pair says nothing here
       (paint l) (? (#l = 0) l
                    (l 0 = 43) (sgr "32" l) (l 0 = 45) (sgr "31" l) (l 0 = 64) (sgr "36" l)
                    (sgr "2" l))
       (map (\ l ("   " + paint l)) (#body <= n ? body (take n body + [("… " + show (#body - n) + " more")]))))

   ; what a tool will do, shown while it asks: an edit or a write as its diff
   (preview name in)
    (? !(valid? name in) ()
       (name @
        "edit_file" (: s (slurp-file (in "path")) e (edited s (in "old_text") (in "new_text"))
                       (? <e (diffs s (e 1) 16) [(sgr "31" (e 1))]))
        "write_file" (: s (slurp-file (in "path")) (diffs (string? s ? s "") (in "content") 16))
        ()))

   ; --- a command on a pty, its screen live in its block ---
   crow-pty-rows 24
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
       (map (\ i (: j (jug 0) _ ((cite 'limn 'limn-row) j s w i 0 -1 0) (slurp j + esc + "[0m")))
            (map (\ d (lo + d)) ^(max 0 (hi - lo + 1)))))
   ; everything the command wrote, as text, for the model
   (scr-text s) (: w (gaze s 2) (copied s (0 - ((gaze s 9) * w)) (gaze s 0)))

   ; a block's lines at width w, cached on the block by [w its version]
   (label s) (sgr "1;35" s)
   (blines b w)
    (: k [w (peep b 'v 0)]
       (? (peep b 'lk () = k) (b 'lines)
          (: ls (blines0 b w) _ (pins b 'lk k 'lines ls) ls)))
   (blines0 b w)
    (b 'k @
     'you (: ls (catmap (\ l (wrap l (w - 6))) (lines (b 'text)))
             (((sgr "1;36" "you") + "   " + <ls) . map (\ l ("      " + l)) >ls))
     'crow (: md (lines ((cite 'lapiz 'md->tty) (b 'text) (w - 1)))
              ls (two? md ? md [""])
              (((label "crow") + snip <ls (min 4 #<ls) #<ls) . >ls))
     'note [(sgr "2;3" ("      ⋯ " + b 'text))]
     ; thinking streams dim while it runs, its last eight lines; done, it folds to one line
     ; unless ^t has them all open
     'think (: ls (catmap (\ l (wrap l (w - 8))) (lines (b 'text)))
               n #(words (b 'text))
               body (map (\ l (sgr "2;3" ("      " + l))) ls)
               (? (b 'open) ((sgr "35" " ∴ thinking…") . (8 < #body ? (drop (#body - 8) body) body))
                  (b 'x) ((sgr "2;35" (" ∴ thought · " + show n + " words")) . body)
                  [(sgr "2;35" (" ∴ thought · " + show n + " words  ^t"))]))
     'tool (: st (b 'st)
              mark (st @ 'ask (sgr "1;33" "[y/n]") 'run (sgr "33" "running…")
                         'ok (sgr "32" "✓") 'err (sgr "31" "✗") 'cut (sgr "2" "stopped") "")
              head (" " + (sgr "1" ("▸ " + shown (b 'name))) + " " + (sgr "2" (b 'brief)) + "  " + mark)
              out (peep b 'out "")
              tail (b 'name @
                    "shell" (? (peep b 'scr () != ())
                              (map (\ l ((sgr "2" "   ┆ ") + l)) (scr-rows (b 'scr) 12))
                              (: ls (filter (\ l (0 < #l)) (lines out)) n #ls
                                 (map (\ l (sgr "2" ("   ┆ " + l))) (8 < n ? (drop (n - 8) ls) ls))))
                    "read_file" (? (st = 'ok) [(sgr "2" ("   " + show #(lines out) + " lines"))] ())
                    (? (st = 'err) [(sgr "31" ("   " + out))] ()))
              (head . (peep b 'pre () + tail)))
     [""])

   ; the transcript, oldest first, a blank line between blocks
   (tlines c w) (catmap (\ b ("" . blines b w)) (rev (c 'blocks)))

   (frame c)
    (: w (c 'cols) h (c 'rows) e (c 'ed)
       il (lines (edtext e)) il2 (two? il ? il [""])
       bh (min 6 #il2)
       top (max 0 (#il2 - bh))
       box (map (\ i ((i = 0 && top = 0 ? (sgr "1;36" "› ") "  ") + il2 (top + i))) ^bh)
       th (h - 3 - bh)
       all (tlines c w)
       end (max 0 (#all - c 'scroll))
       win (drop (max 0 (end - th)) (take end all))
       pad (map (\ _ "") ^(th - #win))
       busy (c 'busy != ())
       head (sgr "7" (edfit (" crow · " + crow-model + " · " + getenv "PWD"
                           + (busy ? "  · working…" "")) w " "))
       sep (sgr "2" (edfit "" w "─"))
       stat (sgr "2" (? (tablet? (c 'asking)) " y run · n decline"
                        busy " esc interrupt · ↑↓ scroll"
                        " enter send · alt-enter newline · ↑↓ ^b ^f scroll · ^t thoughts · ^d quit"))
       rows (map (\ l (edfit l w " ")) (head . (win + pad + [sep] + box)))
       cr (h - bh + #(e 'u) - top)
       cc (1 + 2 + edcol e)
       ((cite 'tui 'tui-fresh) c h [w h] () rows (edfit stat w " ") cr cc))

   ; the tui face: the turn's reports become blocks
   (tface c)
    {'yes (c 'yes)
     'text (\ x (: b (? (two? (c 'blocks)) <(c 'blocks))
                   _ (? (tablet? b && b 'k = 'crow && b 'open)
                      (pins b 'text (b 'text + x) 'v (b 'v + 1))
                      (push c {'k 'crow 'text x 'v 1 'open 1}))
                   (soil c)))
     'think (\ x (: b (? (two? (c 'blocks)) <(c 'blocks))
                    _ (? (tablet? b && b 'k = 'think && b 'open)
                         (pins b 'text (b 'text + x) 'v (b 'v + 1))
                         (push c {'k 'think 'text x 'v 1 'open 1 'x (c 'thinkall)}))
                    (soil c)))
     'break (\ _ (: b (? (two? (c 'blocks)) <(c 'blocks))
                    (? (tablet? b) (: _ (pins b 'open 0 'v (peep b 'v 0 + 1)) (soil c)) 0)))
     'note (\ s (push c {'k 'note 'text s}, soil c))
     'wire (\ s (pin c 'sock s))
     'tool (\ name in (: b {'k 'tool 'name name 'brief (brief name in) 'st 'run 'v 0
                             'pre (? (name = "edit_file" || name = "write_file") (preview name in) ())}
                        (push c b, soil c, b)))
     'ask (\ b (: _ (pins b 'st 'ask 'v (b 'v + 1)) _ (pin c 'asking b) _ (soil c)
                  (wait _) (? (charm? (peep b 'ans ())) (b 'ans) (: _ (rest 30) (wait 0)))
                  a (wait 0)
                  _ (pins b 'st 'run 'v (b 'v + 1)) _ (pin c 'asking ()) _ (soil c)
                  a))
     'done (\ b r (pins b 'st (<r ? 'ok 'err) 'out (r 1) 'v (b 'v + 1), soil c))
     ; on a pty of its own, its screen in the block as it runs; the pipe when no pty opens
     'shell (\ b cmd (: w (max 20 (c 'cols - 8)) r crow-pty-rows
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
   (send c s)
    (: m0 (c 'msgs)
       _ (push c {'k 'you 'text s})
       t (twirl (\ _ (: m (turn (c 'key) (c 'face) ((user s) . m0))
                        _ (pins c 'msgs (two? m ? m m0) 'busy ())
                        (soil c))) 0)
       (pin c 'busy t))
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
       (push c {'k 'note 'text "interrupted"}))

   (onkey c k)
    (: a (c 'asking) e (c 'ed) busy (c 'busy != ())
       (? (tablet? a) (? (k = 121 || k = 89) (pin a 'ans 1) (k = 110 || k = 78 || k = 27) (pin a 'ans 0) 0)
          (busy && (k = 27 || k = 3)) (halt c)
          (k = 20)                                             ; ^t: every thought open, or folded
           (: x (!(c 'thinkall) ? 1 0)
              _ (pin c 'thinkall x)
              (map (\ b (? (b 'k = 'think) (pins b 'x x 'v (b 'v + 1)) 0)) (c 'blocks)))
          (k = 3 || k = -7) (pin c 'over 1)
          (k = 269) (ednl e)                                   ; alt-enter
          (: _ (edstep e k) v (e 'ev) page (c 'rows // 2)
             (v @ 10 (: s (edtext e)
                        (? (busy || #s = 0) 0 (: _ (edclear e) (send c s))))
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
       _ (rest 33)
       (? (c 'over) 0 (swim c (tick + 1))))

   (tui key yes)
    (: c {'blocks () 'ed (ednew 0) 'scroll 0 'dirt {() 1} 'busy () 'asking () 'msgs ()
          'sock () 'over 0 'key key 'yes yes 'rows 24 'cols 80}
       _ (pin c 'face (tface c))
       _ (tide c)
       _ (raw 1)
       _ (say out (esc + "[?1049h" + esc + "[2J" + esc + "[?2004h"))
       _ (flush out)
       up (twirl (\ _ (keyloop c)) 0)
       _ (swim c 1)
       _ (? (c 'busy != ()) (halt c) 0)
       _ (? (landed? up) 0 (freeze up))
       _ (say out (esc + "[0m" + esc + "[?2004l" + esc + "[?1049l"))
       _ (flush out)
       _ (raw 0)
       0)

   ; --- the door ---
   ; a prompt on the command line runs once, plainly; with none, a terminal gets the full
   ; screen and anything else the > loop. --plain asks for the loop on a terminal too
   (crow-main as)
    (: key (getenv crow-key-env)
       yes (elem "-y" as)
       pl (elem "--plain" as)
       words (filter (\ w (w != "-y" && w != "--plain")) as)
       (? (atom? crow-at) (say err ("crow: cannot read the url " + crow-url + "\n"), 1)
          (#crow-model = 0) (say err "crow: name the model, (model NAME) in ~/.love/etc/crow.l\n", 1)
          (!crow-local? && !(string? key && 0 < #key)) (say err ("crow: set " + crow-key-env + "\n"), 1)
          (two? words) (: p (foldl (\ a w (a + " " + w)) <words >words)
                          _ (turn key (plain yes) [(user p)])
                          0)
          (!pl && two? (tty 1)) (tui key yes)
          (repl key (plain yes) ())))

   _ (: s (crow-main >argv) (quit (charm? s ? s 0)))
   0)
