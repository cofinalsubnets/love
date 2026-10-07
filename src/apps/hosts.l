; src/apps/hosts.l -- the other machines a session may run work on: a registry of hosts, each
; with how it is reached, what it can do and how many slots it has, and a door that takes a
; free slot on a host that can, lays a directory there, runs a command and answers its status.
;
;   (hosts-all 0)               every host the registry names
;   (hosts-with cap where)      the hosts with cap whose facts hold where, "key=value" or ()
;   (hosts-live hs)             those of hs that answer ssh now
;   (hosts-take hs who note)    a free slot on one of hs, waited for -> [host lockname]
;   (hosts-free slot who)       the slot given back
;   (hosts-line h dir argv)     the sh line that lays dir on h, runs argv there and cleans up
;   (hosts-on as)               love bee --on and --hosts, the door: its exit status
;
; the registry is ~/.love/etc/bee/hosts (BEE_HOSTS), a paragraph a host of `key value` lines:
; name, reach (the ssh words; ssh NAME unless given), slots (1), caps (words), and any other
; line a fact, which --where asks for. a slot is an exclusive lock, host-NAME-N, so no two
; lanes crowd a box. for a release the env still names hosts, and a cap it names takes its
; hosts over the registry's: KTEST_A64_HOSTS (a64-exec, kvm-a64), KTEST_VMX_HOSTS (vt-x),
; FBSD_SSH NBSD_SSH FBSD_ARM64_SSH NBSD_ARM64_SSH (freebsd-x64 netbsd-x64 freebsd-a64 netbsd-a64)
(module (hosts hosts-all hosts-with hosts-live hosts-take hosts-free hosts-line hosts-on)
(borrow 'posix)

(: sh-quote (cite 'lush 'sh-quote)
   (hs-env k) (getenv k @ v (string? v && 0 < #v ? v ()))
   hs-num (cite 'kore 'wg-digits)
   (hs-path _) (hs-env "BEE_HOSTS" @ p (string? p ? p (getenv "HOME" + "/.love/etc/bee/hosts")))

   ; a host's lines into a tablet: reach and caps are words, slots a count, the rest text
   (hs-val k ws) (k @ "reach" ws "caps" ws "slots" (hs-num <ws) (join " " ws))
   (hs-fill t) (: nm (t "name")
                  (pins t "reach" (peep t "reach" ["ssh" nm]) "slots" (peep t "slots" 1) "caps" (peep t "caps" ())))
   (hs-push t acc) (? (tablet? t && string? (peep t "name" ())) (hs-fill t . acc) acc)
   (hs-parse s)
    (: (go ls t acc)
        (? (atom? ls) (rev (hs-push t acc))
           (: w (words <ls)
              (? (atom? w) (go >ls () (hs-push t acc))
                 (starts? <w "#") (go >ls t acc)                                   ; a # comment
                 (go >ls (pin (tablet? t ? t {}) <w (hs-val <w >w)) acc))))
       (go (lines s) () ()))
   (hosts-all _) (uread (hs-path 0) @ [1 s] (hs-parse (s + "")) ())

   ; the env's hosts for a cap: "host:slots .." lists, or one ssh prefix a box
   hs-envs [["KTEST_A64_HOSTS" ["a64-exec" "kvm-a64"]] ["KTEST_A64_HOST" ["a64-exec" "kvm-a64"]]
            ["KTEST_VMX_HOSTS" ["vt-x"]]
            ["FBSD_SSH" ["freebsd-x64"]] ["NBSD_SSH" ["netbsd-x64"]]
            ["FBSD_ARM64_SSH" ["freebsd-a64"]] ["NBSD_ARM64_SSH" ["netbsd-a64"]]]
   (hs-of-env k v caps)
    (? (starts? k "KTEST_")
       (map (w \ (cite 'kore 'usplit 58 w @ p {"name" <p "reach" ["ssh" <p] "slots" (two? >p ? (hs-num <>p) 1) "caps" caps}))
            (words v))
       [{"name" <caps "reach" (words v) "slots" 1 "caps" caps}])
   (hs-env-hosts cap)
    (catmap (e \ (: v (hs-env <e) (? (string? v && elem cap (e 1)) (hs-of-env <e v (e 1)) ()))) hs-envs)

   ; ssh to a host: its own words, then batch mode and a short connect before the destination,
   ; so an option the registry gives comes first and stands (ssh keeps the first it reads)
   (hs-ssh h) (: r (h "reach") n #r (take (n - 1) r + ["-o" "BatchMode=yes" "-o" "ConnectTimeout=10"] + [(r (n - 1))]))
   (hs-ask h line) (hark (hs-ssh h + [line]))
   (hosts-live hs) (filter (h \ <(hs-ask h "true") = 0) hs)
   ; where is "key=value": a fact the registry says, else the page size asked of the host
   (hs-fits? h where)
    (? !(string? where) 1
       (: k (fsub where "=" 0) key (snip where 0 k) v (snip where (k + 1) #where) f (peep h key ())
          (? (k < 0) 0
             (string? f || charm? f) (show f = v || f = v)
             (key = "page") (hs-ask h "getconf PAGESIZE" @ r (<r = 0 && hs-num (r 1) = hs-num v))
             0)))
   (hosts-with cap where)
    (: ev (hs-env-hosts cap)
       hs (two? ev ? ev (filter (h \ elem cap (h "caps")) (hosts-all 0)))
       (filter (h \ hs-fits? h where) hs))

   ; a slot is the lock host-NAME-N; with every slot taken this waits, saying so once
   (hs-root _) ((cite 'locks 'locks-root) 0)                   ; read per call: this module is baked
   (hosts-take hs who note)
    (: (one h) (foldl (\ a i (two? a ? a (: nm ("host-" + h "name" + "-" + show i)
                                            g ((cite 'locks 'locks-acquire) (hs-root 0) nm 'exclusive who note () 1)
                                            (peep g "granted" 0 ? [h nm] ()))))
                      () (map (+ 1) (jot (h "slots"))))
       (go n) (: s (foldl (\ a h (two? a ? a (one h))) () hs)
                 (? (two? s) s
                    (: _ (? (n = 0) (say err "bee: every slot on those hosts is taken; waiting\n") 0)
                       _ (rest 5000)
                       (go (n + 1)))))
       (go 0))
   (hosts-free slot who) ((cite 'locks 'locks-release) (hs-root 0) (slot 1) 'exclusive who)

   ; dir (or ()) goes over as one tar on the one ssh, argv runs in a scratch dir there with
   ; only PATH HOME LANG=C, and the dir goes after, whatever argv answered
   (hosts-line h dir argv)
    (: d ("/tmp/bee-on-" + show (getpid 0))
       there ("mkdir -p " + d + " && cd " + d + (string? dir ? " && tar xf -" "")
              + " && env -i PATH=/usr/local/bin:/usr/bin:/bin HOME=\"$HOME\" LANG=C"
              + foldl (\ s w (s + " " + sh-quote w)) "" argv
              + "; r=$?; cd /; rm -rf " + d + "; exit $r")
       ((string? dir ? ("tar cf - -C " + sh-quote dir + " . | ") "")
        + foldl (\ s w (s + sh-quote w + " ")) "" (hs-ssh h) + sh-quote there))

   ; --hosts: the registry, a line a host
   (hs-text _)
    (: hs (hosts-all 0)
       (? !(two? hs) ("no hosts: " + hs-path 0 + " names none\n")
          (foldl (\ a h (a + h "name" + "  " + show (h "slots") + (h "slots" = 1 ? " slot  " " slots  ")
                         + join " " (h "caps") + "  " + join " " (h "reach") + "\n"))
                 "" hs)))
   ; --on CAP [--where K=V] [--ship DIR] (--probe | --ssh | -- CMD ..): CMD's status, 75 when
   ; no host with CAP answers, 255 when ssh or the host fails, 2 for a malformed line
   (hosts-on as)
    (: (opt k) (findsub as [k] @ i (0 <= i && i + 1 < #as ? (as (i + 1)) ()))
       cap (opt "--on") where (opt "--where") ship (opt "--ship")
       cmd (findsub as ["--"] @ i (0 <= i ? (drop (i + 1) as) ()))
       (? (elem "--hosts" as) (: _ (say out (hs-text 0)) 0)
          !(string? cap) (: _ (say err "usage: love bee --on CAP [--where K=V] [--ship DIR] (--probe | --ssh | -- CMD ..)\n") 2)
          (: live (hosts-live (hosts-with cap where))
             (? (elem "--probe" as) (two? live ? 0 75)
                (elem "--ssh" as) (? (two? live) (: _ (say out (join " " (hs-ssh <live) + "\n")) 0) 75)
                !(two? cmd) (: _ (say err "bee: --on wants -- and a command\n") 2)
                !(two? live) (: _ (say err ("bee: no host with " + cap + (string? where ? (" and " + where) "") + " answers\n")) 75)
                (: me (getpid 0)
                   slot (hosts-take live me ("bee --on " + cap))
                   p (spawn ["sh" "-c" (hosts-line <slot ship cmd)])
                   r (charm? p && 0 <= p ? (wait p) 255)
                   _ (hosts-free slot me)
                   r))))))
) ; module hosts
