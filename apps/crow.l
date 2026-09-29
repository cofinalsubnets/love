; apps/crow.l -- a coding agent: claude over the messages api, and four tools it may
; call here -- read_file, write_file, edit_file, bash. all but a read ask y/n first.
;
;   out/love apps/crow.l [-y] [prompt ..]     one prompt, or a > loop on stdin
;
; wants ANTHROPIC_API_KEY. the tls client does not verify the peer, so the key rides a
; channel that stops a passive wire, not an active one.
(borrow 'posix)
(borrow 'json)

(:
   dial (cite 'tls 'tls-dial)
   tsay (cite 'tls 'tls-say)
   tslurp (cite 'tls 'tls-slurp)
   find (cite 'kore 'wg-find)
   header (cite 'kore 'wg-header)
   digits (cite 'kore 'wg-digits)
   unchunk (cite 'kore 'wg-unchunk)

   crow-model "claude-opus-5"
   crow-host "api.anthropic.com"
   crow-cap 30000                                           ; a tool answer's bytes, at most

   (prop desc) {"type" "string" "description" desc}
   (tool name desc props req)
    {"name" name "description" desc
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
   ; one POST -> [code doc], doc the json answer; () for a dead wire or a torn answer
   (crow-post key body)
    (: req ("POST /v1/messages HTTP/1.1\r\nHost: " + crow-host
            + "\r\nx-api-key: " + key
            + "\r\nanthropic-version: 2023-06-01"
            + "\r\nanthropic-beta: server-side-fallback-2026-07-01"
            + "\r\ncontent-type: application/json"
            + "\r\ncontent-length: " + show #body
            + "\r\nConnection: close\r\n\r\n" + body)
       t (dial crow-host 443)
       raw (? (tablet? t) (: _ (tsay t req) r (tslurp t) _ (close (t 's)) r))
       k (? (string? raw) (find raw "\r\n\r\n" 0) -1)
       (? (k < 0) ()
          (: hd (snip raw 0 k)
             sp (find hd " " 0)
             te (header hd "transfer-encoding")
             b (snip raw (k + 4) #raw)
             doc (json-read (string? te && te = "chunked" ? (unchunk b) b))
             (? (two? doc) [(digits (snip hd (sp + 1) (sp + 4))) (doc 1)]))))

   ; msgs newest first, as the loop keeps them
   (crow-ask key msgs)
    (crow-post key
     (json-show {"model" crow-model "max_tokens" 16000 "system" crow-system
                 "tools" crow-tools "messages" (rev msgs) "fallbacks" "default"
                 "cache_control" {"type" "ephemeral"}}))

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

   ; a tool call -> [ok? text]
   (run name in)
    (name @
     "read_file"  (: s (slurp-file (in "path")) (? (string? s) [1 (clip s)] [0 ("cannot read " + in "path")]))
     "write_file" (? (spit-file (in "path") (in "content")) [1 ("wrote " + in "path")] [0 ("cannot write " + in "path")])
     "edit_file"  (edit (in "path") (in "old_text") (in "new_text"))
     "bash"       [1 (clip (sh-out (in "command")))]
     [0 ("no tool " + name)])

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
       _ (puts ("  " + name + " " + brief name in + "\n"))
       r (? (yes || name = "read_file" || ask "  run? [y/N] ") (run name in) [0 "the user declined"])
       t {"type" "tool_result" "tool_use_id" (b "id") "content" (r 1)}
       (? <r t (pin t "is_error" json-true)))

   ; a user turn to its end -> the messages after it, or () when the wire failed
   (turn key yes msgs)
    (: r (crow-ask key msgs)
       (? (atom? r) (puts "crow: no answer\n", ())
          !(<r = 200) (puts ("crow: " + show <r + " " + json-show (r 1 "error") + "\n"), ())
          (: doc (r 1)
             blocks (doc "content")
             stop (doc "stop_reason")
             _ (map (\ b (? (b "type" = "text") (puts (b "text" + "\n")) 0)) blocks)
             m ({"role" "assistant" "content" blocks} . msgs)
             (stop @
              "tool_use" (: uses (filter (\ b (b "type" = "tool_use")) blocks)
                            (turn key yes ({"role" "user" "content" (map (answer yes) uses)} . m)))
              "refusal" (puts "crow: declined\n", m)
              "max_tokens" (puts "crow: cut at max_tokens\n", m)
              m))))

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
