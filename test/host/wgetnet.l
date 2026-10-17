; test/host/wgetnet.l -- wget against github over TLS 1.3; opt-in, needs the internet
;   make test_wgetnet
(: wget (cite 'kore 'wget-main)
   out1 ("out/.wget-net-" + show (getpid 0) + ".html")
   rc (wget ["-q" "-O" out1 "https://github.com/"])
   got (open out1 "r" @ p (hot? p ? (slurp p @ s (close p, s)) ""))
   (unlink out1,
    test (0 = rc) (10000 < #got) (0 <= fsub (snip got 0 200) "<!DOCTYPE html>" 0)))

(test_fin (), puts "wgetnet: ok", putc 10, 0)
