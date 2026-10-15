; test/host/lore.l -- `love lore`: alone it lists the games, a name plays one, an
; unknown name exits 2, and no game is a verb of its own.
;   cat test/00-init.l test/host/00-host.l test/host/lore.l | out/love
(borrow 'lore)
(borrow 'posix)
(: lo-love (: l <cmdline (l 0 = 47 ? l (cwd 0 + "/" + l)))
   ; a run on a pty: its status and its lines
   (lo-run argv) (: md (tether argv) o (slurp >md)
                    st (h-wf <md)
                    _ (close >md)
                    [<st (split "\r\n" o) o])
   games ["apartment" "corridor" "court" "design" "dusk" "garage" "grass88" "grass99" "shaft" "slop" "stones" "story" "tower" "wade"]
   ls (lo-run [lo-love "lore"])
   help (lo-run [lo-love "lore" "--help"])
   bad (lo-run [lo-love "lore" "nope"])
   vs (lo-run ["sh" "-c" (lo-love + " verbs | cat")])
   gh (lo-run [lo-love "lore" "court" "--help"])
   ga (lo-run [lo-love "lore" "grass" "--help"])          ; an alias plays its game, unlisted
   (test (games = lore-games ())
         (0 = <ls) (all (n \ elem n (ls 1)) games)
         (0 = <help) (has? (help 2) "usage: love lore")
         (2 = <bad) (has? (bad 2) "no game nope")
         (elem "lore" (vs 1)) !(any (n \ elem n (vs 1)) games)
         (0 = <gh) (has? (gh 2) "usage: love lore court")
         (0 = <ga) (has? (ga 2) "usage: love lore grass88") !(elem "grass" (ls 1)),
    puts "lore: ok\n"))
