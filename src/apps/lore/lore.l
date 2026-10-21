; lore -- the game engine and its games, behind one verb, play (lore is the same door):
; `love play NAME ..` plays a game, `love play LEVEL.l ..` a level, `love play edit LEVEL.l`
; edits one, and `love play` alone lists the games. a game is not a verb of its own, so
; neither a shell nor PATH meets its name. the engine is the libraries the games borrow
; (rove, view, mesh, sky ..). a game registers with (lore-enlist NAME MAIN), MAIN taking the
; args after its name; (lore-shelve NAME MAIN) is one played by name only, unlisted; and
; (lore-alias OLD NAME) lets another name play it, unlisted.
(module (lore lore-enlist lore-shelve lore-alias lore-games lore-kind lore-main)
(:
 games {}
 shelf {}
 aliases {}
 (lore-enlist k f) (pin games k f)
 (lore-shelve k f) (pin shelf k f)
 (lore-alias k to) (pin aliases k to)
 ; the names, sorted: a tablet's order is its own
 (lore-games _) (sort (map string (keys games)))
 (game n) (peep aliases n n @ k (peep games k (shelf k)))
 ; a word with a slash or ending .l is a level's path, never a game's name
 (path? w) (#w @ n (elem 47 w || 2 < n && snip w (n - 2) n = ".l"))
 ; a level's kind, by its game and its editor: story's tiles when its first form is a story
 ; level or it names no .l (a directory is story's library), else a world of scenery.l's words
 (lore-kind p) (: tiles ((cite 'story 'load-level) p) l #p
             (lit? tiles || !(2 < l && snip p (l - 2) l = ".l") ? ['story 'design] ['world 'world-edit]))
 (run k as) (game k @ f (lit? f ? (f as) (say err ("play: no " + show k + " here\n"), flush err, 1)))
 lore-usage "usage: love play [GAME [ARGS ..] | LEVEL.l [ARGS ..] | edit LEVEL.l]   (alone, the games; GAME --help for its own)"
 (lore-main as)
  (? (atom? as) (: _ (each (lore-games ()) (n \ puts (n + "\n"))) (flush out, 0))
     (<as = "--help" || <as = "-h") (puts (lore-usage + "\n"), flush out, 0)
     (path? <as) (run (lore-kind <as 0) as)
     (<as = "edit" && two? >as) (run (lore-kind <>as 1) >as)
     (name <as @ n
        (game n @ f
           (lit? f ? (f >as)
              (say err ("play: no game " + <as + "\n" + lore-usage + "\n"), flush err, 2)))))
 _ (cite 'verbs 'enlist 'play lore-main ())
 _ (cite 'verbs 'enlist 'lore lore-main ()))
) ; module lore
