(level "the lighthouse" lamp
  (room lamp "the lamp room" 2 0
    "glass on every side, and the sea below. the lamp turns.\nstairs lead down."
    (exits (down stair))
    (things (lamp "the lamp" "a fresnel lens the size of a rowboat, humming." ())))
  (room stair "the stair" 2 1
    "a spiral of iron steps. up is light; down is the door."
    (exits (up lamp) (down door))
    (things))
  (room door "the door" 2 2
    "the keeper's door, ajar on the rocks. the stair climbs back up."
    (exits (up stair))
    (things (sign "the sign" "KEEPER OUT. BACK BY THE NEXT TIDE." ()))))
