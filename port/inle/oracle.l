; oracle.l -- inle's milestone-5 BRAIN, in ai (the companion to oracle.py).
; inle's NETBRAIN build (port/inle/kmain.c) dials a UDP oracle at 10.0.2.2:9999
; on its own clock and narrates the reply (`oracle <- ...`). This is that oracle,
; written in ai: `udp-recv` a question, ask claude over `(run curl)` -- curl does
; the TLS, so there is no TLS in the core -- and `udp-send` the answer back. Pure
; ai + curl; no python. The wire nifs live in host/net.c (udp-bind/recv/send);
; the peer rides as a fixnum (host-order ipv4 << 16 | port). 10.0.2.2 is the SLIRP
; gateway alias for the host, so a server bound here on :9999 receives the guest's
; datagrams and its replies route back automatically.
;
; This file only DEFINES (a body-less `:` leaks the helpers); drive it with:
;   out/host/love -l port/inle/oracle.l -e "(oracle 0)"      ; then: make run-netbrain
;
; With no ANTHROPIC_API_KEY it runs the ECHO brain ("<3 ping") -- a free wire
; smoke-test (does SLIRP route? does the reply come back?). With a key it asks
; claude-opus-4-8. Two rules hold the design, both from inle's `slurp`: the reply
; must fit ONE datagram (we clip to 1400 < DG_MAX 1472), and we ALWAYS reply (any
; parse miss returns "?? <raw>" rather than nothing, so inle never blocks forever).
;
; NB: the baked NETBRAIN asks the standing question "ping" every ~3s (kmain.c). For
; real questions, edit that `quest` call, or drive the inbound NETAGENT path
; (make run-netagent + nc). The brain here is the same either way.

(: (note s) (: _ (puts s) (puts "\n"))

   ; --- the system prompt (kept terse: one datagram, one line) ---
   sys (+ "You are inle's remote brain, a tiny bare-metal agent reaching you over "
          "one UDP datagram. Answer in ONE short line of plain ascii, no newlines.")

   ; --- json string codec: escape a question in, read a reply out ---
   ; escape one byte for a json string body; everything else passes through. the
   ; literals use the reader's \" and \\ escapes (verified: \" is one quote byte).
   (esc1 c) (? (= c 34) "\\\""                            ; "  -> \"
               (= c 92) "\\\\"                            ; \  -> \\
               (= c 10) "\\n"  (= c 13) "\\r"  (= c 9) "\\t"
               (+ "" c))                                  ; else the raw byte (the byte law)
   (jesc s) (: (go i acc) (? (< i (tally s)) (go (+ 1 i) (+ acc (esc1 (s i)))) acc)
               (go 0 ""))

   ; find needle in hay -> first index, or -1. (a small scan; the response is small.)
   (find hay nee)
     (: n (tally nee)
        (hit i) (: (m j) (? (= j n) 1 (? (= (hay (+ i j)) (nee j)) (m (+ 1 j)) 0)) (m 0))
        (go i)  (? (> (+ i n) (tally hay)) -1 (? (hit i) i (go (+ 1 i))))
        (go 0))

   ; decode a json string body from `start` (just past the opening quote) to the
   ; first unescaped quote. enough of the escape set for claude's text replies.
   (dec1 d) (? (= d 110) (+ "" 10) (= d 116) (+ "" 9) (= d 114) (+ "" 13) (+ "" d))
   (unesc hay start)
     (: (go i acc)
          (? (< i (tally hay))
             (: c (hay i)
                (? (= c 34) acc                                       ; closing quote
                   (= c 92) (go (+ 2 i) (+ acc (dec1 (hay (+ 1 i))))) ; \x -> decode
                   (go (+ 1 i) (+ acc (+ "" c)))))
             acc)
        (go start ""))

   ; pull the first {"type":"text","text":"..."} value out of a response. the
   ; needle "text":" cannot collide with "type":"text" (no colon after that text).
   ; a thinking block carries "thinking":", not "text":", so this lands on the answer.
   (xtext resp)
     (: nee "\"text\":\""
        i (find resp nee)
        (? (< i 0) (+ "?? " resp) (unesc resp (+ i (tally nee)))))

   ; build the request json for one question.
   (mkbody q)
     (+ "{\"model\":\"claude-opus-4-8\",\"max_tokens\":256,\"thinking\":{\"type\":\"adaptive\"},\"system\":\""
        (+ (jesc sys)
           (+ "\",\"messages\":[{\"role\":\"user\",\"content\":\""
              (+ (jesc q) "\"}]}"))))

   ; clip a reply to one datagram (1400 < inle's DG_MAX 1472), on a byte boundary.
   (clip s) (: lim (? (< (tally s) 1400) (tally s) 1400)
               (go i acc) (? (< i lim) (go (+ 1 i) (+ acc (+ "" (s i)))) acc)
               (go 0 ""))

   ; --- the brain: real claude over curl, or echo when there's no key ---
   (ask q)
     (: r (run (L "curl" "-s" "https://api.anthropic.com/v1/messages"
                   "-H" (+ "x-api-key: " (getenv "ANTHROPIC_API_KEY"))
                   "-H" "anthropic-version: 2023-06-01"
                   "-H" "content-type: application/json"
                   "-d" (mkbody q)))
        (xtext (cup r)))                                  ; (cup r) = curl's stdout
   (brain q) (? (! (getenv "ANTHROPIC_API_KEY")) (+ "<3 " q) (ask q))

   ; --- the loop: perceive a datagram, decide via brain, act by replying ---
   (serve p)
     (: d (udp-recv p)                                    ; BLOCKS for one datagram
        peer (cap d)
        q (cup d)
        ans (brain q)
        a (? (< (tally ans) 1400) ans (clip ans))         ; one datagram, always reply
        _ (note (+ "  " (+ q (+ " -> " a))))
        _ (udp-send p peer a)
        (serve p))
   (oracle _)
     (: p (udp-bind 9999)
        _ (note "oracle: udp :9999 (guest dials 10.0.2.2:9999)")
        _ (note (? (! (getenv "ANTHROPIC_API_KEY")) "oracle: echo brain (no key)"
                   "oracle: claude brain (claude-opus-4-8)"))
        (serve p)))
