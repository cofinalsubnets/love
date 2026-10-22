; test/host/lore.l -- `love play` (and `love lore`, the same door): alone it lists the games,
; a name plays one, a level's path plays it by its kind, an unknown name exits 2, and no game
; is a verb of its own.
;   cat test/00-init.l test/host/00-host.l test/host/lore.l | out/love
(borrow 'lore)
(borrow 'posix)
(: lo-love (: l <cmdline (l 0 = 47 ? l (cwd 0 + "/" + l)))
   ; a run on a pty: its status and its lines
   (lo-run argv) (: md (tether argv) o (slurp >md)
                    st (h-wf <md)
                    _ (close >md)
                    [<st (split "\r\n" o) o])
   games ["apartment" "court" "dusk" "garage" "grass88" "grass99" "shaft" "slop" "stones" "tower" "wad" "wade"]
   ls (lo-run [lo-love "play"])
   old (lo-run [lo-love "lore"])
   help (lo-run [lo-love "play" "--help"])
   bad (lo-run [lo-love "play" "nope"])
   vs (lo-run ["sh" "-c" (lo-love + " verbs | cat")])
   gh (lo-run [lo-love "lore" "court" "--help"])
   ga (lo-run [lo-love "play" "grass" "--help"])          ; an alias plays its game, unlisted
   wh (lo-run [lo-love "play" "test/lore/hall.l" "--nope"])  ; a world's path, to its usage
   eh (lo-run [lo-love "lore" "edit"])
   (test (games = lore-games ())
         (0 = <ls) (all (n \ elem n (ls 1)) games) !(any (n \ elem n (ls 1)) ["story" "design" "world" "corridor" "edit"])
         (0 = <old) (ls 1 = old 1)
         (0 = <help) (has? (help 2) "usage: love play")
         (2 = <bad) (has? (bad 2) "no game nope")
         (elem "play" (vs 1)) (elem "lore" (vs 1)) !(any (n \ elem n (vs 1)) games)
         (0 = <gh) (has? (gh 2) "usage: love play court")
         (0 = <ga) (has? (ga 2) "usage: love play grass88") !(elem "grass" (ls 1))
         (2 = <wh) (has? (wh 2) "usage: love play LEVEL.l")
         (2 = <eh) (has? (eh 2) "no game edit")
         (lore-kind "src/apps/lore/levels/lighthouse.l" = ['story 'design])
         (lore-kind "src/apps/lore/levels/station.l" = ['world 'world-edit])
         (lore-kind "test/lore/hall.l" = ['world 'world-edit])
         (lore-kind "src/apps/lore/levels" = ['story 'design]),
    puts "lore: ok\n"))
