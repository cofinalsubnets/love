; apps/crow.l -- a coding agent: claude over the messages api, and four tools it may
; call here -- read_file, write_file, edit_file, bash. all but a read ask y/n first.
;
;   out/love apps/crow.l [-y] [prompt ..]     one prompt, or a > loop on stdin
;
; wants ANTHROPIC_API_KEY. the answer streams: text prints as it comes. the tls client
; does not verify the peer, so the key rides a channel that stops a passive wire, not
; an active one.
(borrow 'posix)
(borrow 'json)

(:
   dial (cite 'tls 'tls-dial)
   tsay (cite 'tls 'tls-say)
   hear (cite 'tls 'tls-hear)
   find (cite 'kore 'wg-find)
   header (cite 'kore 'wg-header)
   digits (cite 'kore 'wg-digits)

   crow-model "claude-opus-5"
   crow-host "api.anthropic.com"
   crow-cap 30000                                           ; a tool answer's bytes, at most

   (prop desc) {"type" "string" "description" desc}
   (tool name desc props req)
    {"name" name "description" desc "eager_input_streaming" json-true
     "input_schema" {"type" "object" "properties" props "required" req}}
   crow-tools
    [(tool "read_file" "Read a file and answer its text."
           {"path" (prop "the file's path")} ["path"])
     (tool "write_file" "Write text to a file, replacing it whole."
           {"path" (prop "the file's path") "content" (prop "the new text")} ["path" "content"])
     (tool "edit_file" "Replace old_text, which must occur exactly once, with new_text."
           {"path" (prop "the file's path") "old_text" (prop "the text now there")
            "new_text" (prop "its replacement")} ["path" "old_text" "new_text"])
     (tool "bash" "Run a shell command; answers its stdout and stderr, then its exit status."
           {"command" (prop "the command")} ["command"])]

   crow-system
    ("You are crow, a coding agent in a terminal. The working directory is "
     + getenv "PWD" + ". Use the tools to look before you change things, and keep replies short.")

   ; --- the wire ---
   ; a pull reader over the session: 'h holds bytes heard and not yet taken
   (feed r) (: s (hear (r 't)) (? (string? s) (pin r 'h (r 'h + s), 1) 0))
   (upto r sep)                                             ; the bytes before sep, both taken; () at the end
    (: h (r 'h) k (find h sep 0)
       (? (k < 0) (? (feed r) (upto r sep))
          (pin r 'h (snip h (k + #sep) #h), snip h 0 k)))
   (take r n)
    (: h (r 'h)
       (? (#h < n) (? (feed r) (take r n))
          (pin r 'h (snip h n #h), snip h 0 n)))
   (hexn s) (: (go i a) (: v (? (i < #s) (hexv (s i)) -1) (? (v < 0) a (go (i + 1) (a * 16 + v))))
               (go 0 0))
   ; the body's next run, unchunked when chunked; () at its end
   (piece r)
    (? (r 'ch)
       (: n (: l (upto r "\r\n") (? (string? l) (hexn l) 0))
          (? (0 < n) (: d (take r n) _ (upto r "\r\n") d)))
       (: h (r 'h) (? (0 < #h) (pin r 'h "", h) (feed r) (piece r))))
   (rest r) (: (go a) (: p (piece r) (? (string? p) (go (a + p)) a)) (go ""))

   ; one POST, its head read -> a reader carrying 'code, or () for a dead wire
   (crow-open key body)
    (: t (dial crow-host 443)
       (? (tablet? t)
          (: _ (tsay t ("POST /v1/messages HTTP/1.1\r\nHost: " + crow-host
                        + "\r\nx-api-key: " + key
                        + "\r\nanthropic-version: 2023-06-01"
                        + "\r\nanthropic-beta: server-side-fallback-2026-07-01"
                        + "\r\ncontent-type: application/json"
                        + "\r\ncontent-length: " + show #body
                        + "\r\nConnection: close\r\n\r\n" + body))
             r {'t t 'h ""}
             hd (upto r "\r\n\r\n")
             (? (string? hd)
                (: sp (find hd " " 0)
                   te (header hd "transfer-encoding")
                   (pins r 'code (digits (snip hd (sp + 1) (sp + 4)))
                           'ch (string? te && te = "chunked")))))))

   ; the next server-sent event's data -> a tablet, () at the end
   (event r)
    (: s (peep r 'sse "") k (find s "\n\n" 0)
       (? (k < 0) (: p (piece r) (? (string? p) (pin r 'sse (s + p), event r)))
          (: e (snip s 0 k)
             _ (pin r 'sse (snip s (k + 2) #s))
             d (find e "data: " 0)
             j (? (0 <= d) (: z (find e "\n" d) (json-read (snip e (d + 6) (z < 0 ? #e z)))))
             (? (two? j) (j 1) (event r)))))

   ; a streamed answer -> [stop blocks], text printed on the way; [() err] on an error event.
   ; a tool's input arrives as json pieces in js, read whole at its block's stop
   (stream r)
    (: bs (tablet 8) js (tablet 8)
       (go stop)
        (: e (event r)
           (? !(tablet? e) [stop (map bs (sort (keys bs)))]
              (: i (e "index") d (e "delta") b (bs i)
                 (e "type" @
                  "content_block_start" (pin bs i (e "content_block"), go stop)
                  "content_block_delta"
                   (d "type" @
                    "text_delta" (: x (d "text") _ (puts x) _ (flush out)
                                    (pin b "text" (peep b "text" "" + x), go stop))
                    "input_json_delta" (pin js i (peep js i "" + d "partial_json"), go stop)
                    "thinking_delta" (pin b "thinking" (peep b "thinking" "" + d "thinking"), go stop)
                    "signature_delta" (pin b "signature" (peep b "signature" "" + d "signature"), go stop)
                    (go stop))
                  "content_block_stop"
                   (b "type" @
                    "text" (puts "\n", go stop)
                    "tool_use" (: j (json-read (peep js i "{}")) (pin b "input" (two? j ? (j 1) {}), go stop))
                    (go stop))
                  "message_delta" (go (e "delta" "stop_reason"))
                  "message_stop" (go stop)
                  "error" [() (e "error")]
                  (go stop)))))
       (go ()))

   ; msgs newest first, as the loop keeps them
   (crow-body msgs)
    (json-show {"model" crow-model "max_tokens" 64000 "system" crow-system "stream" json-true
                "tools" crow-tools "messages" (rev msgs) "fallbacks" "default"
                "cache_control" {"type" "ephemeral"}})

   ; --- the tools ---
   (slurp-file p) (: f (open p "r") (? (hot? f) (: s (slurp f) _ (close f) s)))
   (spit-file p s) (: f (open p "w") (? (hot? f) (: _ (say f s) _ (close f) 1)))
   (clip s) (#s <= crow-cap ? s (snip s 0 crow-cap + "\n[cut at " + show crow-cap + " bytes]"))

   (sh-out cmd)
    (: pp (pipe 0)
       p (spawnio ["sh" "-c" cmd] -1 >pp >pp [<pp] -1 0)
       _ (close >pp)
       q (fdopen <pp) t (slurp q) _ (close q)
       w (? (charm? p && 0 <= p) (wait p) -1)
       ((string? t ? t "") + "[exit " + show w + "]"))

   (edit p old new)
    (: s (slurp-file p)
       k (? (string? s && 0 < #old) (find s old 0) -1)
       (? (k < 0) [0 ("not found in " + p)]
          (0 <= find s old (k + 1)) [0 ("more than once in " + p)]
          (spit-file p (snip s 0 k + new + snip s (k + #old) #s)) [1 ("edited " + p)]
          [0 ("cannot write " + p)]))

   ; a streamed input is unchecked by the api: every required field must be a string
   (valid? name in)
    (: t (filter (\ x (x "name" = name)) crow-tools)
       (two? t && tablet? in && !(two? (filter (\ k !(string? (in k))) (<t "input_schema" "required")))))

   ; a tool call -> [ok? text]
   (run name in)
    (? !(valid? name in) [0 ("no such tool, or its input is missing a field: " + name)]
       (name @
        "read_file"  (: s (slurp-file (in "path")) (? (string? s) [1 (clip s)] [0 ("cannot read " + in "path")]))
        "write_file" (? (spit-file (in "path") (in "content")) [1 ("wrote " + in "path")] [0 ("cannot write " + in "path")])
        "edit_file"  (edit (in "path") (in "old_text") (in "new_text"))
        "bash"       [1 (clip (sh-out (in "command")))]))

   ; --- the terminal ---
   (line _) (: (go acc) (see in @ -1 (? (two? acc) (string (rev acc))) 10 (string (rev acc)) c (go (c . acc)))
               (go ()))
   (ask q) (: _ (puts q) _ (flush out) l (line 0) (string? l && 0 < #l && (l 0 = 121 || l 0 = 89)))
   (brief name in)
    (name @ "bash" (in "command")
            "edit_file" (in "path" + ": " + show #(in "old_text") + " bytes -> " + show #(in "new_text"))
            (in "path"))

   ; one tool_use block -> its tool_result, asking first unless yes or a read
   (answer yes b)
    (: name (b "name") in (b "input")
       _ (puts ("  " + name + " " + (valid? name in ? (brief name in) "(malformed input)") + "\n"))
       r (? !(valid? name in) (run name in)
            (yes || name = "read_file" || ask "  run? [y/N] ") (run name in)
            [0 "the user declined"])
       t {"type" "tool_result" "tool_use_id" (b "id") "content" (r 1)}
       (? <r t (pin t "is_error" json-true)))

   ; a user turn to its end -> the messages after it, or () when the wire failed
   (turn key yes msgs)
    (: r (crow-open key (crow-body msgs))
       (? !(tablet? r) (puts "crow: no answer\n", ())
          !(r 'code = 200)
           (: j (json-read (rest r)) _ (close (r 't 's))
              (puts ("crow: " + show (r 'code) + " " + (two? j ? (json-show (j 1 "error")) "") + "\n"), ()))
          (: s (stream r) _ (close (r 't 's))
             stop <s blocks (s 1)
             (? !(string? stop)
                 (puts ("\ncrow: " + (tablet? blocks ? (json-show blocks) "the stream broke off") + "\n"), ())
              (: uses (filter (\ b (b "type" = "tool_use")) blocks)
                 ; a tool_use without its result would poison the next request: only a
                 ; tool_use stop keeps them
                 kept (? (stop = "tool_use") blocks (filter (\ b !(b "type" = "tool_use")) blocks))
                 m (? (two? kept) ({"role" "assistant" "content" kept} . msgs) msgs)
                 (stop @
                  "tool_use" (turn key yes ({"role" "user" "content" (map (answer yes) uses)} . m))
                  "refusal" (puts "crow: declined\n", m)
                  "max_tokens" (puts "crow: cut at max_tokens\n", m)
                  m))))))

   (user s) {"role" "user" "content" s}
   (repl key yes msgs)
    (: _ (puts "> ") _ (flush out) l (line 0)
       (? !(string? l) 0
          (#l = 0) (repl key yes msgs)
          (: m (turn key yes ((user l) . msgs)) (repl key yes (two? m ? m msgs)))))

   (crow-main as)
    (: key (getenv "ANTHROPIC_API_KEY")
       yes (elem "-y" as)
       words (filter (\ w (w != "-y")) as)
       (? !(string? key && 0 < #key) (say err "crow: set ANTHROPIC_API_KEY\n", 1)
          (two? words) (: p (foldl (\ a w (a + " " + w)) <words >words)
                          _ (turn key yes [(user p)])
                          0)
          (repl key yes ())))

   _ (crow-main >argv)
   0)
