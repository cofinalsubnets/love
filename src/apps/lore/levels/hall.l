; the test corridor: `love lore corridor --level src/apps/lore/levels/hall.l`, read again
; whenever it is saved. metres; x east, z north, y up. the forms are listed at the top of
; src/apps/lore/corridor.l.
(level "the test corridor"
  (start 0 1 0)
  ; the hallway, and the room past the door; the 0.2 between them is the wall
  (room -1.2 0 1.2 12.4 2.6)
  (room -1.2 12.6 1.2 16.5 2.6)
  (door 0 12.5 1.2 2.2)
  ; the lights: four strips down the hall, the third failing, and the room's bulb
  (strip 0 2)
  (strip 0 5)
  (strip 0 8 stammer)
  (strip 0 11)
  (bulb 0 2.1 16.38 (1.6 0.12 0.06) breathe)
  ; on the walls
  (poster -1.2 4 1.1 0.6 0.9)
  (sign 1.2 7 1.75 0.3 "LOUNGE" (1 0.16 0.55) buzz))
