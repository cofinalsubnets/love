; --- test/host/wgetnet.l: wget against a live https peer -- opt-in, it needs the internet ---
; the whole tls client at once: resolve, x25519, the schedule, chacha20-poly1305 records,
; a chunked body, a redirect. the peer is github, which speaks nothing but TLS 1.3 with
; this suite and answers a plain page.
;   make test_wgetnet
(: wget (cite 'kore 'wget-main)
   out1 "out/.wget-net.html"
   rc (wget ["-q" "-O" out1 "https://github.com/"])
   got (: p (open out1 "r") (hot? p ? (: s (slurp p) _ (close p) s) ""))
   ; the page opens with a few blank lines before its doctype
   (test (0 = rc) (10000 < #got) (0 <= (cite 'kore 'wg-find) (snip got 0 200) "<!DOCTYPE html>" 0)))

(test_fin (), puts "wgetnet: ok", putc 10, 0)
