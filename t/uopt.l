; the option walk, which 105 kore applets and the crew's verbs read their flags through
; and which had no test of its own. three doors: uopt1 explodes ONE word into the letters
; it clusters, uopt walks a whole argv into a tablet, and uoptv reads a value back out.
;
; the answer shape is [tablet stacked rest]: read it with `two?` and never for truth,
; because () is the one refusal -- a value flag left with nothing behind it -- and a
; tablet of no flags nets 0.
(: (keysof o) (sort (keys (cap o)))
   (tabof o) (cap o)
   (restof o) (cap (cup (cup o)))
   ; the map a long name is read through: to a letter's key, so --width and -w are one
   ; option with one reader, or to anything else where there is no letter to share
   L {"width" 119 "text" 116 "no-build" 'nb "port" 112}
   (walk as) (: t (tablet 0) (uopt as t '(119 116 112) '(101) L))
   (short as) (: t (tablet 0) (uopt as t '(109) '(101) ())))

(test
 ; --- uopt1: one word into its letters ------------------------------------------------
 (["-q" "-e"] = (uopt1 "-qe" () "e"))           ; the chain ends on a value letter
 (["-q" "-e" "X"] = (uopt1 "-qeX" () "e"))      ; ..taking the rest of its own word
 (["-l" "-a"] = (uopt1 "-la" () ""))
 (nil? (uopt1 "-qz" "qe" ""))                   ; z is in neither set: the word is not ours
 (nil? (uopt1 "--" () ""))                      ; nor is the end-of-flags mark
 (nil? (uopt1 "file" () ""))
 (nil? (uopt1 "-" () ""))

 ; --- uopt: the short lane, which the long one leaves alone ---------------------------
 ([119] = (keysof (walk ["-w" "4" "f"])))
 ("4" = (uoptv (tabof (walk ["-w" "4" "f"])) 119))
 ("4" = (uoptv (tabof (walk ["-w4" "f"])) 119))         ; the value glued to its letter
 (["f"] = (restof (walk ["-w" "4" "f"])))
 (["f" "g"] = (restof (walk ["-w4" "f" "g"])))
 (nil? (walk ["-w"]))                                   ; a value flag with nothing behind
 (["--width" "2"] = (restof (walk ["--" "--width" "2"])))    ; -- ends the flags

 ; --- the long lane -------------------------------------------------------------------
 ("20" = (uoptv (tabof (walk ["--width" "20" "f"])) 119))
 ("20" = (uoptv (tabof (walk ["--width=20" "f"])) 119))      ; ..or glued behind its =
 (["f"] = (restof (walk ["--width=20" "f"])))
 ; a name with no letter to share stands on a key of its own
 (1 = (peep (tabof (walk ["--no-build" "f"])) 'nb 0))
 ; the two lanes mix, and the shorts still cluster
 ([116 119] = (keysof (walk ["-w20" "--text=x" "f"])))
 ("x" = (uoptv (tabof (walk ["-w20" "--text=x" "f"])) 116))
 ([112 119] = (keysof (walk ["--port" "80" "-w" "4"])))

 ; --- what the long lane refuses ------------------------------------------------------
 ; a name the map does not carry is not ours: that word ends the flags and is an operand,
 ; which is what an unknown long flag did here before there was a map at all
 (["--nope" "f"] = (restof (walk ["--nope" "f"])))
 (nil? (keysof (walk ["--nope" "f"])))
 ; a glued value on a flag that takes none, rather than a value silently dropped
 (["--no-build=7" "f"] = (restof (walk ["--no-build=7" "f"])))
 (nil? (walk ["--width"]))                              ; and a value flag left empty
 ; an applet that carries no long flags is exactly what it was: () is no map
 (["--width" "9" "f"] = (restof (short ["--width" "9" "f"])))

 ; --- uoptv, and the stacking lane ----------------------------------------------------
 (nil? (uoptv (tabof (walk ["-w" "4"])) 116))           ; a flag that was never given
 (nil? (uoptv (tabof (walk ["--no-build"])) 'nb))       ; a flag with no value is not one
 ; a key in `reps` stacks into the second slot instead of pinning, that being the option
 ; a tool spells more than once (sed -e, grep -e)
 (["a" "b"] = (cap (cup (: t (tablet 0) (uopt ["-e" "a" "-e" "b" "f"] t '(101) '(101) ()))))))
