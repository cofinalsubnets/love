; test/host/lore.l -- `love lore`: the games behind one verb. alone it lists them, a
; name plays one, an unknown name exits 2, and no game is a verb of its own.
;   cat test/00-init.l test/host/lore.l | out/love
(borrow 'lore)
(borrow 'posix)
(: lo-love (: l <cmdline (l 0 = 47 ? l (cwd 0 + "/" + l)))
   (lo-has? s t) (: n #t (go i) (i + n <= #s && (snip s i (i + n) = t || go (i + 1))) (go 0))
   ; a run on a pty: its status and its lines
   (lo-run argv) (: md (tether argv) o (slurp >md)
                    (wf p) (gather p @ g (two? g ? g (rest 2, wf p)))
                    st (wf <md)
                    _ (close >md)
                    [<st (split "\r\n" o) o])
   games ["apartment" "design" "dusk" "garage" "grass" "shaft" "slop" "story" "tower" "tree" "wade"]
   ls (lo-run [lo-love "lore"])
   help (lo-run [lo-love "lore" "--help"])
   bad (lo-run [lo-love "lore" "nope"])
   vs (lo-run ["sh" "-c" (lo-love + " verbs | cat")])
   gh (lo-run [lo-love "lore" "tree" "--help"])
   (test (games = lore-games ())
         (0 = <ls) (all (n \ elem n (ls 1)) games)
         (0 = <help) (lo-has? (help 2) "usage: love lore")
         (2 = <bad) (lo-has? (bad 2) "no game nope")
         (elem "lore" (vs 1)) !(any (n \ elem n (vs 1)) games)
         (0 = <gh) (lo-has? (gh 2) "usage: love lore tree"),
    puts "lore: ok\n"))
