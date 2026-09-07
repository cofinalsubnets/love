(level "the lighthouse" (start 6 8)
  (map
   "  #########  "
   "  #.......#  "
   "  #...*...#  "
   "  #.......#  "
   "  ####.####  "
   "  #.......#  "
   "  #.......#  "
   "  ####.####  "
   "  #.......#  "
   "  #...?...#  "
   "  #.......#  "
   "  #########  "
   "~~~~~~~~~~~~~"
   "~~~~~~~~~~~~~")
  (tiles
   (" " " " -1 -1 wall)
   ("#" "#" 245 236 wall)
   ("." "." 240 -1 ())
   ("~" "~" 27 17 wall))
  (things
   (lamp 6 2 "*" 220 -1 "the lamp" (say "a fresnel lens the size of a rowboat, humming.") (say "glass on every side, and the sea below. the lamp turns."))
   (sign 6 9 "?" 214 -1 "the sign" (say "KEEPER OUT.") (say "BACK BY THE NEXT TIDE."))))
