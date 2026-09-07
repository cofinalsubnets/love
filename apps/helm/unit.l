#!/usr/bin/env -S love -l
; apps/helm/unit.l -- the unit language: what a helm config says.
;
; a config is DATA, never code (salt's law): the file is read with `sound` and
; no part of it is evaluated, so nothing in it needs quoting. one form per unit:
;
;   (service sshd
;     (exec "/usr/sbin/sshd" "-D")
;     (after network)
;     (restart always)
;     (log "/var/log/sshd.log")
;     (env "PATH" "/bin:/usr/bin"))
;
;   (oneshot hostname (exec "/bin/hostname" "moon"))
;   (target  default  (wants sshd getty))
;
; three kinds. a service is long-running and supervised; a oneshot runs to
; completion and is done; a target is a name for a set of them, and nothing
; else. the clauses:
;
;   (exec ARG ..)      the argv, execvp'd. a service and a oneshot need one.
;   (after NAME ..)    these come up first, and we wait for them.
;   (wants NAME ..)    these come up too -- a target's whole content.
;   (restart R)        no | on-fail | always. a service defaults on-fail.
;   (tries N)          give up after N restarts in a row. default 3.
;   (log PATH)         the child's stdout and stderr, appended.
;   (dir PATH)         the child's working directory.
;   (env K V ..)       environment pairs, set for the child alone.
;
; a unit is a TABLET keyed by exactly those clause names plus 'name and 'kind,
; so the language and the record are one vocabulary and a new clause is one row
; of `hkeys`. every complaint is collected rather than raised: a config is read
; once and `helm check` owes you all of it at once, not the first line.
(module 'helm
(: hkinds    ['service 'oneshot 'target]
   hrestarts ['no 'on-fail 'always]
   ; clause -> how its tail folds: 'all the whole tail, 'one the first operand
   hkeys {'exec 'all 'after 'all 'wants 'all 'env 'all
          'restart 'one 'tries 'one 'log 'one 'dir 'one}

   ; --- reading ---------------------------------------------------------------
   (hslurp path) (: q (open path "r") (? !q () (: t (slurp q) _ (close q) t)))
   ; text -> [forms torn?]. a dropped paren hides every unit under it, so it is
   ; answered and not swallowed.
   (hforms t)
    (: (go x acc) (: r (sound x)
                     (? (two? r)     (go >r (<r . acc))
                        (id? r 'torn) [(rev acc) 1]
                        [(rev acc) 0]))
       (go t ()))

   ; --- one unit --------------------------------------------------------------
   (hclause u c gs)
    (? !(two? c) (("a clause is a form, not " + show c) . gs)
       (: k <c v >c m (peep hkeys k ())
          (? !m           (("unknown clause " + string k) . gs)
             (id? m 'one) (? !(two? v) (("(" + string k + ") wants an operand") . gs)
                             (pin u k <v, gs))
             (pin u k v, gs))))

   ; (KIND NAME clause..) -> [unit gripes]
   (hunit kind nm cs gs)
    (: u (pins {} 'name nm 'kind kind 'exec [] 'after [] 'wants [] 'env []
                  'restart (kind == 'service ? 'on-fail 'no) 'tries 3)
       [u (foldl (\ g c (hclause u c g)) gs cs)])

   ; --- a whole config --------------------------------------------------------
   ; forms -> [units gripes], units in file order.
   (hunits fs)
    (: (go fs us gs)
        (? !(two? fs) [(rev us) (rev gs)]
           (: f <fs
              (? !(two? f)              (go >fs us (("not a unit form: " + show f) . gs))
                 !(member? <f hkinds)   (go >fs us (("unknown kind " + show <f) . gs))
                 !(two? >f)             (go >fs us (("a " + string <f + " wants a name") . gs))
                 !(name? <>f)           (go >fs us (("a unit name is a name, not " + show <>f) . gs))
                 (: nm <>f  cs >>f
                    r (hunit <f nm cs gs)
                    (go >fs (<r . us) <>r)))))
       (go fs () ()))

   ; --- the unit by name ------------------------------------------------------
   (hby us nm) (? !(two? us) () (: u <us (peep u 'name () == nm ? u (hby >us nm))))
   (hnames us) (map (\ u (peep u 'name ())) us)

   ; --- what is wrong with it -------------------------------------------------
   ; every check answers a list of complaints, and `hcheck` is their concatenation
   ; in reading order. nothing here raises: a bad config is a report, not a fault.
   (happend a b) (foldl (\ l x (x . l)) b (rev a))
   (hdedup l seen) (? !(two? l) (rev seen)
                      (member? <l seen ? (hdedup >l seen) (hdedup >l (<l . seen))))
   (hstrings? l) (? !(two? l) 1 (string? <l ? (hstrings? >l) 0))

   ; a cycle in `after` is the one error the supervisor cannot survive: the dep
   ; walk would never bottom out. answers the name the walk came back to, or ().
   (hcycle us nm seen)
    (? (member? nm seen) nm
       (: u (hby us nm)
          (? !u ()
             (: path (nm . seen)
                (go ds) (? !(two? ds) ()
                           (: r (hcycle us <ds path) (? r r (go >ds))))
                (go (peep u 'after []))))))

   (hcheck1 us u)
    (: nm  (peep u 'name ())    kind (peep u 'kind ())
       ex  (peep u 'exec [])    tag  ("unit " + string nm + ": ")
       run? (kind !== 'target)
       (deps k) (: bad (filter (\ d !(hby us d)) (peep u k []))
                   (map (\ d (tag + string k + " " + string d + " is not a unit")) bad))
       (happend
        (happend
         (: r (peep u 'restart ())
            (? !(member? r hrestarts) [(tag + "restart " + show r + " is not no|on-fail|always")]
               (: n (peep u 'tries 0)
                  (? (charm? n && 0 < n) () [(tag + "tries wants a positive count")]))))
         (? (run? && !(two? ex))       [(tag + "no (exec ..) -- nothing to run")]
            (run? && !(hstrings? ex))  [(tag + "(exec ..) wants strings")]
            (!run? && (two? ex))       [(tag + "a target has nothing to exec")]
            ()))
        (happend (deps 'after) (deps 'wants))))

   (hcheck us)
    (: ns  (hnames us)
       dup (hdedup (filter (\ n (1 < tally (filter (\ m (m == n)) ns))) ns) [])
       cyc (filter (\ n (hcycle us n [])) (hdedup ns []))
       (happend (map (\ n ("duplicate unit " + string n)) dup)
                (happend (map (\ n ("unit " + string n + ": after cycles back to itself")) cyc)
                         (foldl (\ g u (happend g (hcheck1 us u))) () us))))

   ; --- the door --------------------------------------------------------------
   ; path -> [units gripes]. an unreadable file is one gripe and no units, which
   ; is what a supervisor with nothing to run should say rather than raise.
   (hconf path)
    (: t (hslurp path)
       (? !t [() [("cannot read " + path)]]
          (: r (hforms t)
             p (hunits <r)
             us <p
             torn (<>r ? [(path + ": a form is unfinished -- a dropped paren")] ())
             [us (happend <>p (happend torn (hcheck us)))])))

   ; --- showing ---------------------------------------------------------------
   (hargv-line l) (? !(two? l) "" !(two? >l) <l (<l + " " + hargv-line >l))
   (hunit-line u)
    (: nm (peep u 'name ()) kind (peep u 'kind ())
       af (peep u 'after [])  ex (peep u 'exec [])
       head (string kind + " " + string nm)
       body (kind == 'target
             ? (" wants " + hargv-line (map string (peep u 'wants [])))
               (" restart " + string (peep u 'restart ()) + " tries " + show (peep u 'tries 0)))
       dep  (two? af ? (" after " + hargv-line (map string af)) "")
       run  (two? ex ? ("\n    exec " + hargv-line ex) "")
       (head + body + dep + run))))
