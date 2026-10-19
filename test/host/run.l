; test/host/run.l -- the hark / herald nifs (src/love/main.c), process and fd laws
;   cat test/00-init.l test/host/run.l | out/love
; herald tees what it captures, so payloads stay tiny; the >64KB lane is checked by hand:
;   (: c `("sh" "-c" "i=0; while [ $i -lt 20000 ]; do echo abcdefgh; i=$((i+1)); done")
;      (test ((>(hark c)) = (>(herald c)))))
(: cmd ["sh" "-c" "printf 'tee-me\n'"]

   ; teeing changes when the bytes reach stdout, never what the caller is handed
   a (hark cmd) b (herald cmd)
   _ (test (two? a) (two? b))
   _ (test (<a = <b) (<a = 0))
   _ (test (>a = >b) (>a = "tee-me\n"))

   bad (herald ["sh" "-c" "printf 'nope\n'; exit 3"])
   _ (test (two? bad) (<bad = 3) (>bad = "nope\n"))

   quiet (herald ["sh" "-c" "exit 0"])
   _ (test (two? quiet) (<quiet = 0) !>quiet)

   (puts "run: ok\n"))

; a write to a full pipe does not stop the vm: the residue rides the port; the wall clock is the law.
; the reader is another process: in-process, a blocking writer would deadlock, not redden
(: pr (pipe 0)
   rfd <pr wfd >pr
   pid (spawnio ["sh" "-c" "sleep 1; cat >/dev/null"] rfd 1 2 [wfd] -1 0)
   _ (close rfd)
   w (fdopen wfd)
   t0 (clock 0)
   _ (say w ("x" * 200000))          ; 200K against a 64K pipe
   ms (clock t0)
   _ (test (charm? pid) (0 < pid)
             (ms < 500))             ; a blocking door sits here for the child's whole nap
   _ (close w)                       ; the residue lands before the fd dies
   _ (wait pid))

(puts "run rung4: ok\n")

; love ignores sigpipe, yet the console dies on a closed pipe and a child never inherits the
; ignore. the spewer is bounded so a regression is slow, not wedged
(: spew "( echo '(: (go n) (? (n = 0) 0 (: _ (putc 120) _ (putc 10) (go (n - 1)))) _ (go 300000) 0)' | out/love; echo $? > out/.sigst ) | head -1 > /dev/null; cat out/.sigst; rm -f out/.sigst"
   st >(hark ["sh" "-c" spew])
   sig >(hark ["sh" "-c" "grep SigIgn /proc/self/status"])
   _ (test
      (st = "141\n")                       ; 128 + sigpipe
      (sig = "SigIgn:\t0000000000000000\n")))

(puts "run sigpipe: ok\n")

; close-on-exec: a child sees its 0/1/2 and what it was handed, nothing love holds
(: (fdls _) (: r (hark ["ls" "/proc/self/fd"]) (lines >r))
   base (fdls 0)
   q (open "test/host/run.l" "r")
   f (openfd "test/host/run.l" 0)
   p (pipe 0)
   d (dup f)
   t (tether ["sleep" "1"])
   _ (test (base != ()) (fdls 0 = base))
   o (openfd "out/.fdlaw" 1)
   pid (spawnmap ["ls" "/proc/self/fd"] [(1 . o) (f . f) (9 . <p)] () -1 0)
   _ (wait pid)
   got (: r (hark ["cat" "out/.fdlaw"]) (lines >r))
   _ (test (#got = #base + 2) (elem (show f) got) (elem "9" got))
   _ (map close [f <p >p d o])
   _ (close q)
   (wait <t))

(puts "run cloexec: ok\n")

; test/host/parked.l, seventeen parked tasks, under a timeout: its regression is a hang
(: rc <(hark ["sh" "-c" "timeout 20 out/love test/host/parked.l"])
   _ (test (rc = 0)))

(puts "run parked: ok\n")

; test/host/nifpark.l, accept / recv / wait all park, under a timeout
(: rc <(hark ["sh" "-c" "cat test/00-init.l test/host/nifpark.l | timeout 20 out/love"])
   _ (test (rc = 0)))

(puts "run nifpark: ok\n")

; test/host/dns.l, a lookup and its deadline park, against a loopback nameserver
(: rc <(hark ["sh" "-c" "cat test/00-init.l test/host/dns.l | timeout 20 out/love"])
   _ (test (rc = 0)))

(test_fin ())
(puts "run dns: ok\n")

; a wait nothing could wake scares (deadlock); each its own process under a timeout
(: (dead e) (hark ["sh" "-c" ("timeout 10 out/love -e '" + e + "' 2>&1")])
   (scared? r) (<r = 1 && 2 = #(split ";; deadlock" >r))
   cont (dead """(: t {} p (twirl (\ _ (call-cc (c \ (pin t 0 c)))) 0) _ (catch p) ((t 0) 1))""")
   pair (dead """(: t {} a (twirl (\ _ (catch (t (quote b)))) 0) b (twirl (\ _ (catch a)) 0) _ (pin t (quote b) b) (putx (catch a)))""")
   frz (dead """(: m (myself 0) p (twirl (\ _ (putx (freeze m))) 0) _ (catch p) (putx (quote back)))""")
   pse (dead """(: m (myself 0) p (twirl (\ _ (putx (pause m))) 0) _ (catch p) (putx (quote back)))""")
   ; a catch whose task sleeps is no deadlock: the clock wakes it
   slept (dead """(: p (twirl (\ _ (rest 50, 7)) 0) (putx (catch p)))""")
   _ (test (scared? cont) (scared? pair) (scared? frz) (scared? pse)
           (<slept = 0) (>slept = "77\n"))
   (puts "run deadlock: ok\n"))
