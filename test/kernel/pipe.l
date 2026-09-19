; rung-4 laws: the pipe pair over one kernel-heap queue, its EOF
; protocol (a reader parks while a writer lives, reads the end at the last
; close), dup/dup2 as row aliases, and the spawn/wait shim over tasks -- a
; spawned tool's stdio seated under the folded ports. kernel corpus only
; (test/kernel/all.l's roster), after the kore subset: the spawn laws drive echo-main and
; wc-main as processes. (their console output mid-corpus is the smoke, not a
; mess -- test/kernel/kore.l's precedent.)

; the pair, the bytes, the end
(: pp (pipe 0) rfd <pp wfd >pp
   wp (fdopen wfd) rp (fdopen rfd)
   _ (say wp "hello pipe") _ (close wp)         ; the run drains at the close; the last writer leaves
   s (slurp rp) _ (close rp)
 (test (two? pp) (charm? rfd) (charm? wfd)
       (port? wp) (port? rp)
       (s = "hello pipe")))

; the same pair through the raw-fd lane: say/put/see/chug/slurp take a charm
; where they take a port, unbuffered and straight at the row -- no fdopen, so no
; finalizer to hand the end over to
(: pp (pipe 0) rfd <pp wfd >pp
   _ (say wfd "hello pipe") _ (put wfd 33)
   a (see rfd)
   x (chug rfd)                                 ; what the row still has in hand
   _ (close wfd)
   e (see rfd)
   s (slurp rfd) _ (close rfd)
 (test (104 = a) ("ello pipe!" = x) (-1 = e) ("" = s)))

; a pipe end wears its own kind, where a ramfs fd wears a file's -- stat off the
; fd is the one door either way
(: pp (pipe 0) rfd <pp wfd >pp
   s (stat rfd)
   _ (close rfd) _ (close wfd)
 (test (4096 = 61440 & <>>s)))

; a row that is not there swallows what is written and reads as the end. that is
; what keeps a closed seat's output from faulting a task which cannot know, and
; it is the same answer on both seats
(test ("into the void" = say 4096 "into the void")
      (-1 = see 4096) ("" = slurp 4096)
      (4096 = flush 4096))

; a parked reader wakes on the write, and ends on the close
(: pp (pipe 0) rp (fdopen <pp)
   p (twirl (_ \ slurp rp) 0)
   _ (rest 0)                                   ; let the reader park on the quiet pipe
   wp (fdopen >pp)
   _ (say wp "wake") _ (close wp)
   r (catch p) _ (close rp)
 (test (r = "wake")))

; dup is a row alias: the end comes at the last writer's close, not the first
(: pp (pipe 0) rfd <pp wfd >pp
   w2 (dup wfd)
   wp (fdopen wfd)
   _ (say wp "one") _ (close wp)
   rp (fdopen rfd)
   p (twirl (_ \ slurp rp) 0)
   _ (rest 0)
   w2p (fdopen w2)
   _ (say w2p ", two") _ (close w2p)
   r (catch p) _ (close rp)
 (test (charm? w2) (2 < w2) (r = "one, two")))

; dup2 lands the alias in the named slot, closing what sat there
(: pa (pipe 0) pb (pipe 0)
   e (dup2 >pa >pb)                             ; b's write slot now feeds a
   wp (fdopen >pb) _ (say wp "crossed") _ (close wp)
   _ (close >pa)                                ; a's own write end steps out too
   sb (slurp (fdopen <pb))                      ; b lost its one writer at the dup2
   sa (slurp (fdopen <pa))
 (test !e (sb = "") (sa = "crossed")))

; spawn maps argv onto a love main, the pid is the task pid, wait is catch;
; the corpus itself runs unseated in the main task
(: p (spawn ["kore" "echo" "rung4"])
 (test (charm? (getpid 0)) (0 = getpid 0)
       (charm? p) (0 < p) (0 = wait p)))

; an unknown program still answers a pid; its exit is 127, the host's face
(: p (spawn ["no-such-tool"])
 (test (127 = wait p)))

; the seat: a stage's out rides the pipe while the parent keeps the console --
; the parent closes its end and still reads the child whole
(: pp (pipe 0) rfd <pp wfd >pp
   p (spawnmap ["kore" "echo" "seated"] [(1 . wfd)] [rfd wfd] -1 0)
   _ (close wfd)
   s (slurp (fdopen rfd))
 (test (0 = wait p) (s = "seated\n")))

; two stages plumbed by hand -- echo | wc -l -- the parent reading the tail;
; the seat carries fd 0 as well as fd 1
(: pa (pipe 0) pb (pipe 0)
   p1 (spawnmap ["kore" "echo" "a b"] [(1 . >pa)] () -1 0)
   p2 (spawnmap ["kore" "wc" "-l"]
                [(0 . <pa) (1 . >pb)] () -1 0)
   _ (close >pa) _ (close <pa) _ (close >pb)
   s (slurp (fdopen <pb))
   r1 (wait p1) r2 (wait p2)
 (test (0 = r1) (0 = r2) (s = "1\n")))
