; src/apps/hosts.l -- the other machines a session may run work on: a registry of hosts
; (reach, caps, slots), and a door that takes a free slot on a capable host, lays a
; directory there, runs a command and answers its status.
;
;   (hosts-all 0)               every host the registry names
;   (hosts-with cap where)      the hosts with cap whose facts hold where, "key=value" or ()
;   (hosts-live hs)             those of hs that answer ssh now
;   (hosts-take hs who note)    a free slot on one of hs, waited for -> [host lockname]
;   (hosts-free slot who)       the slot given back
;   (hosts-line h dir argv)     the sh line that lays dir on h, runs argv there and cleans up
;   (hosts-on as)               love bee --on and --hosts, the door: its exit status
;
; the registry is ~/.love/etc/bee/hosts (BEE_HOSTS), a paragraph a host of `key value`:
; name, reach (ssh words; ssh NAME by default), slots (1), caps, slots-CAP (that cap's own
; slots), apart-CAP (hosts its work never runs beside), and any other line a fact for --where.
; a slot is an exclusive lock, host-NAME-N or host-NAME-CAP-N. an env cap list takes its hosts
; over the registry's: KTEST_A64_HOSTS (a64-exec, kvm-a64), KTEST_VMX_HOSTS (vt-x),
; FBSD_SSH NBSD_SSH FBSD_ARM64_SSH NBSD_ARM64_SSH (freebsd-x64 netbsd-x64 freebsd-a64 netbsd-a64)
(module (hosts hosts-all hosts-with hosts-live hosts-take hosts-free hosts-line hosts-on)
(borrow 'posix)

(: sh-quote (cite 'lush 'sh-quote)
   (hs-env k) (getenv k @ v (string? v && 0 < #v ? v ()))
   hs-num (cite 'kore 'wg-digits)
   (hs-path _) (hs-env "BEE_HOSTS" @ p (string? p ? p (cite 'path 'nest 0 + "/etc/bee/hosts")))

   ; a host's lines into a tablet: reach and caps are words, slots a count, the rest text
   (hs-val k ws) (? (starts? k "slots") (hs-num <ws) (starts? k "apart") ws (k @ "reach" ws "caps" ws (join " " ws)))
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

   ; ssh to a host: its own words first (ssh keeps the first it reads), then batch mode and
   ; a short connect
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
       (map (h \ pin h "want" cap) (filter (h \ hs-fits? h where) hs)))

   ; a slot is the lock host-NAME-N; with every slot taken this waits, saying so once
   (hs-root _) ((cite 'locks 'locks-root) 0)                   ; read per call: this module is baked
   ; a cap with a slots-CAP line has slots of its own, host-NAME-CAP-N; an apart-CAP host's
   ; slots are all held beside one, so its lanes never run with that cap's
   (hs-lock h i) (: c (peep h "want" ()) per (string? c && charm? (peep h ("slots-" + c) ()))
                    ("host-" + h "name" + (per ? ("-" + c) "") + "-" + show i))
   (hs-count h) (: c (peep h "want" ()) (charm? (peep h ("slots-" + c) ()) ? (h ("slots-" + c)) (h "slots")))
   (hs-grab nm who note) (peep ((cite 'locks 'locks-acquire) (hs-root 0) nm 'exclusive who note () 1) "granted" 0)
   (hs-drop nm who) ((cite 'locks 'locks-release) (hs-root 0) nm 'exclusive who)
   (hs-apart h) (catmap (n \ (: o (filter (x \ x "name" = n) (hosts-all 0))
                             (? (two? o) (map (i \ "host-" + n + "-" + show (i + 1)) (jot (<o "slots"))) ())))
                        (peep h ("apart-" + peep h "want" "") ()))
   (hosts-take hs who note)
    (: (both h nm) (: ap (hs-apart h)
                      got (foldl (\ a l (? (hs-grab l who note) (l . a) a)) () ap)
                      (? (#got = #ap) (h . nm . got)
                         (: _ (map (l \ hs-drop l who) got) _ (hs-drop nm who) ())))
       (one h) (foldl (\ a i (two? a ? a (: nm (hs-lock h i) (hs-grab nm who note ? (both h nm) ()))))
                      () (map (+ 1) (jot (hs-count h))))
       (go n) (: s (foldl (\ a h (two? a ? a (one h))) () hs)
                 (? (two? s) s
                    (: _ (? (n = 0) (say err "bee: every slot on those hosts is taken; waiting\n") 0)
                       _ (rest 5000)
                       (go (n + 1)))))
       (go 0))
   (hosts-free slot who) (map (l \ hs-drop l who) >slot)

   ; dir (or ()) goes as one tar on the one ssh; argv runs in a scratch dir with only PATH
   ; HOME LANG=C, and the dir goes after, whatever argv answered
   (hosts-line h dir argv)
    (: d ("/tmp/bee-on-" + show (getpid 0))
       there ("mkdir -p " + d + " && cd " + d + (string? dir ? " && tar xf -" "")
              + " && env -i PATH=/usr/local/bin:/usr/bin:/bin HOME=\"$HOME\" LANG=C"
              + foldl (\ s w (s + " " + sh-quote w)) "" argv
              + "; r=$?; cd /; rm -rf " + d + "; exit $r")
       ((string? dir ? ("tar cf - -C " + sh-quote dir + " . | ") "")
        + foldl (\ s w (s + sh-quote w + " ")) "" (hs-ssh h) + sh-quote there))

   ; a kept directory on h, under its home unless absolute: argv runs there with the same
   ; three words of env, and nothing is cleaned after. with at, only while the directory's
   ; checkout is that commit, its tracked files untouched; else 97
   (hs-at at) (? !(string? at) ""
                 (" && { test \"$(git rev-parse HEAD 2>/dev/null)\" = " + sh-quote at
                  + " && git diff --quiet HEAD || { echo 'bee: not at " + at + "' >&2; exit 97; }; }"))
   (hs-in-line h in at argv)
    (foldl (\ s w (s + sh-quote w + " ")) "" (hs-ssh h)
     + sh-quote ("mkdir -p " + sh-quote in + " && cd " + sh-quote in + hs-at at
                 + " && env -i PATH=/usr/local/bin:/usr/bin:/bin HOME=\"$HOME\" LANG=C"
                 + foldl (\ s w (s + " " + sh-quote w)) "" argv))
   ; this repo's commit sha into h's kept directory: pushed, checked out over whatever was
   ; there, untracked files but out/ cleaned. a file the commit keeps keeps its time, so a
   ; make there rebuilds what moved and only that
   (hs-push-line h sha in)
    (: r (hs-ssh h) n #r q (sh-quote in)
       (hs-in-line h in () ["sh" "-c" "{ [ -d .git ] || git init -q; } && git config receive.denyCurrentBranch ignore"]
        + " && GIT_SSH_COMMAND=" + sh-quote (join " " (map sh-quote (take (n - 1) r)))
        + " git push -q --force " + sh-quote (r (n - 1) + ":" + in) + " " + sh-quote (sha + ":refs/heads/gate")
        + " && " + hs-in-line h in () ["sh" "-c" ("git update-index -q --refresh; git checkout -q --force " + sha + " && git clean -fdq -e /out/")]))

   ; --hosts: the registry, a line a host
   (hs-text _)
    (: hs (hosts-all 0)
       (? !(two? hs) ("no hosts: " + hs-path 0 + " names none\n")
          (foldl (\ a h (a + h "name" + "  " + show (h "slots") + (h "slots" = 1 ? " slot  " " slots  ")
                         + join " " (h "caps") + "  " + join " " (h "reach") + "\n"))
                 "" hs)))
   ; --on CAP [--where K=V] [--ship DIR | --in DIR [--push SHA | --at SHA]] (--probe | --ssh | --list | -- CMD ..):
   ; CMD's status, 75 when no host with CAP answers, 255 when ssh or the host fails, 97 when DIR
   ; is not at SHA, 2 for a malformed line. --in keeps DIR on the host, which --push lays this
   ; repo's SHA in first (alone, no slot taken); --list is the live hosts, `name slots isa` a line
   (hosts-on as)
    (: (opt k) (findsub as [k] @ i (0 <= i && i + 1 < #as ? (as (i + 1)) ()))
       cap (opt "--on") where (opt "--where") ship (opt "--ship") in (opt "--in")
       src (opt "--push") at (opt "--at" @ a (string? a ? a src))
       cmd (findsub as ["--"] @ i (0 <= i ? (drop (i + 1) as) ()))
       (run line) (: p (spawn ["sh" "-c" line]) (charm? p && 0 <= p ? (wait p) 255))
       (? (elem "--hosts" as) (: _ (say out (hs-text 0)) 0)
          !(string? cap) (: _ (say err "usage: love bee --on CAP [--where K=V] [--ship DIR | --in DIR [--push SHA | --at SHA]] (--probe | --ssh | --list | -- CMD ..)\n") 2)
          (string? at && !(string? in)) (: _ (say err "bee: --push and --at want --in\n") 2)
          (: live (hosts-live (hosts-with cap where))
             (? (elem "--probe" as) (two? live ? 0 75)
                (elem "--ssh" as) (? (two? live) (: _ (say out (join " " (hs-ssh <live) + "\n")) 0) 75)
                (elem "--list" as)
                 (: _ (map (h \ say out (h "name" + " " + show (hs-count h) + " " + peep h "isa" "?" + "\n")) live)
                    (two? live ? 0 75))
                (string? src && !(two? cmd))
                 (? (two? live) (: r (run (hs-push-line <live src in))
                                   (r = 0 ? (run (hs-in-line <live in at ["true"])) r))
                    (: _ (say err ("bee: no host with " + cap + " answers\n")) 75))
                !(two? cmd) (: _ (say err "bee: --on wants -- and a command\n") 2)
                !(two? live) (: _ (say err ("bee: no host with " + cap + (string? where ? (" and " + where) "") + " answers\n")) 75)
                (: me (getpid 0)
                   slot (hosts-take live me ("bee --on " + cap))
                   s0 (string? src ? (run (hs-push-line <slot src in)) 0)
                   r (? (s0 != 0) s0
                        (run (string? in ? (hs-in-line <slot in at cmd) (hosts-line <slot ship cmd))))
                   _ (hosts-free slot me)
                   r))))))
) ; module hosts
