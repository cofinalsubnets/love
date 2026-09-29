; apps/crow.l -- a coding agent: claude over the messages api, and four tools it may
; call here -- read_file, write_file, edit_file, lush. all but a read ask y/n first.
;
;   out/love apps/crow.l [-y] [prompt ..]     one prompt, or a > loop on stdin
;
; wants ANTHROPIC_API_KEY. the answer streams: text prints as it comes. the key goes out
; only once tls-vouch has the host's certificate naming it, in date, and signed by a
; pinned issuer (crow-pins).
(borrow 'posix)
(borrow 'json)

(:
   dial (cite 'tls 'tls-dial)
   tsay (cite 'tls 'tls-say)
   hear (cite 'tls 'tls-hear)
   vouch (cite 'tls 'tls-vouch)
   find (cite 'kore 'wg-find)
   header (cite 'kore 'wg-header)
   digits (cite 'kore 'wg-digits)

   crow-model "claude-opus-5"
   crow-host "api.anthropic.com"
   crow-cap 30000                                           ; a tool answer's bytes, at most
   ; the issuers whose signature on the host's certificate lets the key go: google trust
   ; services' WE1, by its spki's sha-256. CROW_PINS adds more, space-separated
   crow-pins ("908769e8d34477cc2cba0632c88605b22d7294c0840f78596d247c645b1afc0e"
              . (: e (getenv "CROW_PINS") (? (string? e) (words e))))

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
     (tool "lush" ("Run a command line in lush, love's POSIX shell. The commands the system prompt "
                   + "names are love's own userland (kore) and win over PATH; anything else comes "
                   + "from PATH. Answers stdout and stderr, then the exit status.")
           {"command" (prop "the command line")} ["command"])]

   ; the shell is this binary's own, with its verbs ahead of PATH (lush -a)
   crow-self ((cite 'posix 'selfpath) 0)
   (lush-argv cmd) [crow-self "lush" "-a" "-c" cmd]
   crow-verbs (foldl (\ a v (a + " " + v)) "" (sort (map show (keys (cite 'verbs 'tab)))))

   crow-system
    ("You are crow, a coding agent in a terminal. The working directory is " + getenv "PWD"
     + ". Use the tools to look before you change things, and keep replies short. Commands run "
     + "in lush, a POSIX shell, not bash: write POSIX sh. These commands are love's own "
     + "implementations, POSIX in their flags, so a GNU-only option may be refused:" + crow-verbs + ".")

   ; --- the wire ---
   ; a pull reader over the session: 'h holds bytes heard and not yet taken
   (feed r) (: s (hear (r 't)) (? (string? s) (pin r 'h (r 'h + s), 1) 0))
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

   ; one POST, its head read -> a reader carrying 'code, or () for a dead wire. the key goes
   ; only to a peer tls-vouch answers 1 for; else 'code is its reason
   (crow-open key body)
    (: t (dial crow-host 443)
       v (? (tablet? t) (vouch t crow-host crow-pins))
       (? (tablet? t && v != 1) (close (t 's), {'code v})
          (tablet? t)
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


   ; --- the turn, told to a face ---
   ; a face is a tablet of doors the turn reports through, so one core serves the plain
   ; stdout loop and the full screen alike:
   ;   'text x        a piece of streamed text        'break _    a text block ended
   ;   'note s        something the user should know  'wire s     the socket, while it is open
   ;   'tool name in  a tool call begins -> a handle  'ask h      may it run? -> 1 | 0
   ;   'done h r      it ran, r [ok? text]            'yes        run without asking
   ;   'shell h cmd   run cmd in lush for tool h -> its output and exit status

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
                    "thinking_delta" (pin b "thinking" (peep b "thinking" "" + d "thinking"), go stop)
                    "signature_delta" (pin b "signature" (peep b "signature" "" + d "signature"), go stop)
                    (go stop))
                  "content_block_stop"
                   (b "type" @
                    "text" ((f 'break) 0, go stop)
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

   ; the child's output read by see, which parks this task alone, and its exit by gather,
   ; which never blocks: the screen keeps painting while a command runs. stdin is /dev/null
   (lush-out cmd)
    (: pp (pipe 0) nul (openfd "/dev/null" 0)
       p (spawnio (lush-argv cmd) nul >pp >pp [<pp] -1 0)
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

   ; a tool call -> [ok? text]. the face runs lush, so the screen can show it running
   (run f h name in)
    (? !(valid? name in) [0 ("no such tool, or its input is missing a field: " + name)]
       (name @
        "read_file"  (: s (slurp-file (in "path")) (? (string? s) [1 (clip s)] [0 ("cannot read " + in "path")]))
        "write_file" (? (spit-file (in "path") (in "content")) [1 ("wrote " + in "path")] [0 ("cannot write " + in "path")])
        "edit_file"  (edit (in "path") (in "old_text") (in "new_text"))
        "lush"       [1 (clip ((f 'shell) h (in "command")))]))

   (brief name in)
    (? !(valid? name in) "(malformed input)"
       (name @ "lush" (in "command")
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
           ((f 'note) (crow-host + " is not vouched for (" + show (r 'code) + "); the key stays here"), ())
          !(r 'code = 200)
           (: j (json-read (drain r)) _ (close (r 't 's))
              ((f 'note) (show (r 'code) + " " + (two? j ? (json-show (j 1 "error")) "")), ()))
          (: _ ((f 'wire) (r 't 's))
             s (stream f r) _ (close (r 't 's)) _ ((f 'wire) ())
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
   (plain yes)
    {'yes yes
     'text (\ x (puts x, flush out))
     'break (\ _ (puts "\n"))
     'note (\ s (puts ("\ncrow: " + s + "\n")))
     'wire (\ s 0)
     'tool (\ name in (puts ("  " + name + " " + brief name in + "\n")))
     'ask (\ h (? (ask "  run? [y/N] ") 1 0))
     'done (\ h r 0)
     'shell (\ h cmd (lush-out cmd))}
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
     'tool (: st (b 'st)
              mark (st @ 'ask (sgr "1;33" "[y/n]") 'run (sgr "33" "running…")
                         'ok (sgr "32" "✓") 'err (sgr "31" "✗") 'cut (sgr "2" "stopped") "")
              head (" " + (sgr "1" ("▸ " + b 'name)) + " " + (sgr "2" (b 'brief)) + "  " + mark)
              out (peep b 'out "")
              tail (b 'name @
                    "lush" (? (peep b 'scr () != ())
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
                        " enter send · alt-enter newline · ↑↓ ^b ^f scroll · ^d quit"))
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
     'break (\ _ (: b (? (two? (c 'blocks)) <(c 'blocks)) (? (tablet? b) (pin b 'open 0) 0)))
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
                       md (tether (lush-argv cmd))
                       (? (atom? md) (lush-out cmd)
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
    (: key (getenv "ANTHROPIC_API_KEY")
       yes (elem "-y" as)
       pl (elem "--plain" as)
       words (filter (\ w (w != "-y" && w != "--plain")) as)
       (? !(string? key && 0 < #key) (say err "crow: set ANTHROPIC_API_KEY\n", 1)
          (two? words) (: p (foldl (\ a w (a + " " + w)) <words >words)
                          _ (turn key (plain yes) [(user p)])
                          0)
          (!pl && two? (tty 1)) (tui key yes)
          (repl key (plain yes) ())))

   _ (crow-main >argv)
   0)
