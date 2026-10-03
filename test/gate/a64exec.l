; test/gate/a64exec.l -- a stand-in for `love bee --on CAP`, until bee's host registry
; answers it. the lanes call this file where they will call bee, so the swap is one word.
;
;   a64exec.l --on a64-exec [--where page=N] --probe
;   a64exec.l --on a64-exec [--where page=N] [--ship DIR] -- CMD ..
;
; the hosts are KTEST_A64_HOSTS ("host:slots .."), the boxes the kvm lane boots on, and a
; slot is the same exclusive lock it takes, a64host-HOST-N, so the two never crowd one box.
; --ship lays DIR in a scratch dir there in one tar over one ssh, CMD runs in it with only
; PATH HOME LANG=C, its output comes back on ours, and the dir goes. the answer is CMD's
; status, 75 when no host has the cap (the lane's fallback, never a skip), 255 when ssh or
; the host fails. --probe answers 0 or 75 and runs nothing.
(borrow 'posix)
(: a    >argv
   (env-of k) (getenv k @ v (string? v && 0 < #v ? v ()))
   (num s) (foldl (\ a i (a * 10 + s i - 48)) 0 ^#s)
   (at l x i) (? !(two? l) -1 (<l = x) i (at >l x (i + 1)))      ; x's index in l, else -1
   (opt k) (at a k 0 @ i (0 <= i && i + 1 < #a ? (a (i + 1)) ()))
   cap   (opt "--on")
   where (opt "--where")
   ship  (opt "--ship")
   cmd   (at a "--" 0 @ i (0 <= i ? (drop (i + 1) a) ()))
   (sq w) ("'" + foldl (\ s i (s + (w i = 39 ? "'\\''" (string (w i))))) "" ^#w + "'")
   (sh1 h line) (hark ["ssh" "-o" "BatchMode=yes" "-o" "ConnectTimeout=5" h line])
   ; a host answers ssh, and --where page=N reads its page size there
   (fits? h) (? !(string? where) (<(sh1 h "true") = 0)
                (starts? where "page=")
                 (sh1 h "getconf PAGESIZE" @ r
                    (<r = 0 && num (snip >r 0 (#>r - 1)) = num (snip where 5 #where)))
                 0)
   all   (env-of "KTEST_A64_HOSTS" @ l
            (string? l ? (map (w \ (cite 'kore 'usplit 58 w @ p [<p (two? >p ? (num <>p) 1)]))
                              (filter (w \ 0 < #w) (cite 'kore 'usplit 32 l)))
                         ()))
   hosts (cap = "a64-exec" ? (filter (h \ fits? <h) all) ())
   _     (? (two? all && !(two? hosts) && cap = "a64-exec")
            (say err ("a64exec: no host in KTEST_A64_HOSTS answers" + (string? where ? " with " + where "")
                      + "; the lane falls back\n"))
            0)
   lroot ((cite 'locks 'locks-root) 0)
   (try-slot h i) (: nm ("a64host-" + <h + "-" + show i)
                     g ((cite 'locks 'locks-acquire) lroot nm 'exclusive (getpid 0) "a64exec" () 1)
                     (peep g "granted" 0 ? [<h nm] ()))
   (try-host h) (foldl (\ a i (two? a ? a (try-slot h i))) () (map (+ 1) (jot (h 1))))
   (take-slot n) (: s (foldl (\ a h (two? a ? a (try-host h))) () hosts)
                    (? (two? s) s
                       (: _ (? (n = 0) (say err "a64exec: every a64 host slot is taken; waiting\n") 0)
                          _ (rest 5000)
                          (take-slot (n + 1)))))
   (run slot)
    (: d ("/tmp/a64x-" + show (getpid 0))
       far (foldl (\ s w (s + " " + sq w)) "" cmd)
       there ("mkdir -p " + d + " && cd " + d + (string? ship ? " && tar xf -" "")
              + " && env -i PATH=/usr/local/bin:/usr/bin:/bin HOME=\"$HOME\" LANG=C" + far
              + "; r=$?; cd /; rm -rf " + d + "; exit $r")
       line ((string? ship ? "tar cf - -C " + sq ship + " . | " "")
             + "ssh -o BatchMode=yes " + sq <slot + " " + sq there)
       p (spawn ["sh" "-c" line])
       r (charm? p && 0 <= p ? (wait p) 255)
       _ ((cite 'locks 'locks-release) lroot (slot 1) 'exclusive (getpid 0))
       r)
   (? !(string? cap) (say err "usage: a64exec.l --on CAP [--where K=V] [--ship DIR] (--probe | -- CMD ..)\n", quit 2)
      (elem "--probe" a) (quit (two? hosts ? 0 75))
      !(two? cmd) (say err "a64exec: no command after --\n", quit 2)
      !(two? hosts) (quit 75)
      (quit (run (take-slot 0)))))
