; test/kernel/pipe.l -- pipes over one kernel-heap queue (a reader parks while a writer lives),
; dup/dup2 as row aliases, spawn/wait over tasks. kernel corpus only, after the kore subset

; the pair, the bytes, the end
(: pp (pipe 0) rfd <pp wfd >pp
   wp (fdopen wfd) rp (fdopen rfd)
   _ (say wp "hello pipe", close wp)            ; the last writer leaves at the close
   s (slurp rp) (close rp,
                 test (two? pp) (charm? rfd) (charm? wfd)
       (port? wp) (port? rp)
       (s = "hello pipe")))

; the raw-fd lane: say/put/see/chug/slurp take a charm, unbuffered, no fdopen
(: pp (pipe 0) rfd <pp wfd >pp
   _ (say wfd "hello pipe", put wfd 33)
   a (see rfd)
   x (chug rfd)                                 ; what the row still holds
   _ (close wfd)
   e (see rfd)
   s (slurp rfd) (close rfd,
                  test (104 = a) ("ello pipe!" = x) (-1 = e) ("" = s)))

; a pipe end wears its own kind; stat off the fd is the one door
(: pp (pipe 0) rfd <pp wfd >pp
   s (stat rfd)
   (close rfd, close wfd,
    test (4096 = 61440 & <>>s)))

; a missing row swallows writes and reads as the end, so a closed seat's output never faults
(test ("into the void" = say 4096 "into the void")
      (-1 = see 4096) ("" = slurp 4096)
      (4096 = flush 4096))

; a parked reader wakes on the write, and ends on the close
(: pp (pipe 0) rp (fdopen <pp)
   p (twirl (_ \ slurp rp) 0)
   _ (rest 0)                                   ; let the reader park on the quiet pipe
   wp (fdopen >pp)
   _ (say wp "wake", close wp)
   r (catch p) (close rp,
                test (r = "wake")))

; dup is a row alias: the end comes at the last writer's close, not the first
(: pp (pipe 0) rfd <pp wfd >pp
   w2 (dup wfd)
   wp (fdopen wfd)
   _ (say wp "one", close wp)
   rp (fdopen rfd)
   p (twirl (_ \ slurp rp) 0)
   _ (rest 0)
   w2p (fdopen w2)
   _ (say w2p ", two", close w2p)
   r (catch p) (close rp,
                test (charm? w2) (2 < w2) (r = "one, two")))

; dup2 lands the alias in the named slot, closing what sat there
(: pa (pipe 0) pb (pipe 0)
   e (dup2 >pa >pb)                             ; b's write slot now feeds a
   wp (fdopen >pb) _ (say wp "crossed", close wp)
   _ (close >pa)                                ; a's own write end steps out too
   sb (slurp (fdopen <pb))                      ; b lost its one writer at the dup2
   sa (slurp (fdopen <pa))
 (test !e (sb = "") (sa = "crossed")))

; a slot past the table's ceiling is refused, however far past
(test ('ebadf = dup2 0 70000) ('ebadf = dup2 0 2000000000))

; spawn maps argv onto a love main, the pid is the task pid, wait is catch; the corpus runs
; unseated in the main task
(spawn ["kore" "echo" "rung4"] @ p
 (test (charm? (getpid 0)) (0 = getpid 0)
       (charm? p) (0 < p) (0 = wait p)))

; an unknown program still answers a pid; its exit is 127, the host's face
(spawn ["no-such-tool"] @ p
 (test (127 = wait p)))

; the seat: a stage's out rides the pipe; the parent closes its end and still reads it whole
(: pp (pipe 0) rfd <pp wfd >pp
   p (spawnmap ["kore" "echo" "seated"] [(1 . wfd)] [rfd wfd] -1 0)
   _ (close wfd)
   s (slurp (fdopen rfd))
 (test (0 = wait p) (s = "seated\n")))

; echo | wc -l by hand: the seat carries fd 0 as well as fd 1
(: pa (pipe 0) pb (pipe 0)
   p1 (spawnmap ["kore" "echo" "a b"] [(1 . >pa)] () -1 0)
   p2 (spawnmap ["kore" "wc" "-l"]
                [(0 . <pa) (1 . >pb)] () -1 0)
   _ (close >pa, close <pa, close >pb)
   s (slurp (fdopen <pb))
   r1 (wait p1) r2 (wait p2)
 (test (0 = r1) (0 = r2) (s = "1\n")))
