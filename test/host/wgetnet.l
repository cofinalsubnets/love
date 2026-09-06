; --- test/host/wgetnet.l: wget against a live https peer -- OPT-IN, it needs the internet ---
; the whole tls client at once: resolve, x25519, the schedule, chacha20-poly1305 records,
; a chunked body, a redirect. the peer is github, which speaks nothing but TLS 1.3 with
; this suite and answers a plain page.
;   make test_wgetnet
(: wget (from 'kore 'wget-main)
   out1 "out/.wget-net.html"
   rc (wget ["-q" "-O" out1 "https://github.com/"])
   got (: p (open out1 "r") (? (hot? p) (: s (slurp p) _ (close p) s) ""))
   ; the page opens with a few blank lines before its doctype
   (assert (0 = rc) (< 10000 (tally got)) (<= 0 ((from 'kore 'wg-find) (snip got 0 200) "<!DOCTYPE html>" 0))))

(: _ (test_fin ()) _ (puts "wgetnet: ok") _ (putc 10) 0)
