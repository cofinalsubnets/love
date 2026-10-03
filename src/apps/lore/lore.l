; lore -- the game engine and its games, behind one verb: `love lore NAME ..` plays one,
; and `love lore` alone lists them. a game is not a verb of its own, so neither a shell
; nor PATH meets its name.
;
; the engine is libraries the games borrow:
;   rove   the roguelike floor: tiles, fov, the painter, the signs, the paced keys
;   view   the first-person screen in half blocks: rays, pens, frames, the tty loop
;   vec    triples of numbers or trays: vectors, colours, and the hash's value noise
;   sky    the sun by date, hour and latitude, and the weather: clear to overcast, smooth or in pixels
;   grove  trees grown from a seed, drawn as wood and points, and the shade they cast
; a game registers with (lore-enlist NAME MAIN), MAIN taking the args after its name, and
; (lore-alias OLD NAME) lets another name play it, unlisted.
(module (lore lore-enlist lore-alias lore-games lore-main)
(:
 games {}
 aliases {}
 (lore-enlist k f) (pin games k f)
 (lore-alias k to) (pin aliases k to)
 ; the names, sorted: a tablet's order is its own
 (lore-games _) (sort (map string (keys games)))
 lore-usage "usage: love lore [GAME [ARGS ..]]   (alone, the games; GAME --help for its own)"
 (lore-main as)
  (? (atom? as) (: _ (each (lore-games ()) (n \ puts (n + "\n"))) (flush out, 0))
     (<as = "--help" || <as = "-h") (puts (lore-usage + "\n"), flush out, 0)
     (name <as @ n
        (peep games (peep aliases n n) () @ f
           (lit? f ? (f >as)
              (say err ("lore: no game " + <as + "\n" + lore-usage + "\n"), flush err, 2)))))
 _ (cite 'verbs 'enlist 'lore lore-main ()))
) ; module lore
