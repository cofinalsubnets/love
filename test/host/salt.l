; test/host/salt.l -- salt, the config door (src/apps/libra/salt.l), on real files under out/.
; salt-file takes the path, so no test fakes HOME.
;   cat test/00-init.l test/host/salt.l | out/love

(borrow 'salt)

; paths are the pid's own, so two runs over one out/ keep apart
(: st-dir ("out/.salt-" + show (getpid 0))
   _ (mkdir "out" 493, mkdir st-dir 493)
   (st-put nm text) (: p (st-dir + "/" + nm)
                       q (open p "w")
                       (say q text,
                        close q,
                        p))
   st-gone (st-dir + "/no-such-file.l"))

; a setting is `(key operand ..)`: the head names it, the tail is the value
(: st-a (st-put "a.l" "(singleton 1)\n(deprecated old-thing (worse \"say better\"))\n"))
(test
 (salt-file st-a {} @ c
    (&& (1 = salt-one c 'singleton 0)
        (2 = #(salt-all c 'deprecated))
        ('old-thing = <(salt-all c 'deprecated)))))

; a config is data, never evaluated: were this evaled the test would quit here
(: st-q (st-put "quit.l" "(danger (quit 1))\n"))
(test
 (: c (salt-file st-q {})
    v (salt-one c 'danger ())
    (two? v && 'quit = <v)))

; an absent file and an empty one both mean no overrides, and disturb nothing
(: st-e (st-put "empty.l" ""))
(test
 (salt-file st-e (salt-file st-a {}) @ c (1 = salt-one c 'singleton 0))
 (salt-file st-gone (salt-file st-a {}) @ c (1 = salt-one c 'singleton 0))
 !(salt-all (salt-file st-e {}) 'singleton)
 !(salt-all (salt-file st-gone {}) 'singleton))

; the overlay: later wins, key by key; a key it does not mention stays
(: st-b (st-put "b.l" "(singleton 0)\n"))
(test
 (salt-file st-b (salt-file st-a {}) @ c
    (0 = salt-one c 'singleton 9 && 2 = #(salt-all c 'deprecated)))
 (salt-file st-a (salt-file st-b {}) @ c
    (1 = salt-one c 'singleton 9)))

; a form that is not a setting is skipped in silence; the rest lands
(: st-j (st-put "junk.l" "loose-symbol\n42\n\"a string\"\n(singleton 1)\n((f x) 2)\n(deprecated a)\n"))
(test
 (salt-file st-j {} @ c
    (1 = salt-one c 'singleton 0 && 1 = #(salt-all c 'deprecated))))

; a dropped paren ends the read: `sound` answers `torn`, neither a datum nor the end
(: st-t (st-put "trunc.l" "(singleton 1)\n(deprecated foo\n"))
(test
 (salt-file st-t {} @ c
    (1 = salt-one c 'singleton 0 && !(salt-all c 'deprecated))))

; salt-all answers () for an absent key and a bare `(singleton)` alike
(: st-n (st-put "none.l" "(singleton)\n"))
(test
 (salt-file st-n {} @ c
    (!(salt-all c 'singleton) && 'dflt = salt-one c 'singleton 'dflt))
 (salt-file st-a {} @ c
    ('dflt = salt-one c 'never-written 'dflt && !(salt-all c 'never-written))))

; a roster entry is a name or `(name "hint")`, answered wrapped: presence out of band
(test
 (salt-file st-a {} @ c
    (&& (two? (salt-has? c 'deprecated 'old-thing))
        ('old-thing = <>(salt-has? c 'deprecated 'old-thing))
        (two? (salt-has? c 'deprecated 'worse))
        ('worse = <<>(salt-has? c 'deprecated 'worse))   ; the (name "hint") pair
        !(salt-has? c 'deprecated 'never-listed)
        !(salt-has? c 'no-such-key 'old-thing))))

; (salt 'app) is salt-file over the two well-known paths
(test
 (tablet? (salt 'salt-test-no-such-app))
 !(salt-all (salt 'salt-test-no-such-app) 'singleton))

(hark ["rm" "-rf" st-dir])
(test_fin ())
(puts "salt: ok")
(putc 10)
