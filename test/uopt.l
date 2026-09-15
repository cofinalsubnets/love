; the option walk, which 105 kore applets and the crew's verbs read their flags through
; and which had no test of its own. three doors: uopt1 explodes ONE word into the letters
; it clusters, uopt walks a whole argv into a tablet, and uoptv reads a value back out.
;
; the answer shape is [tablet stacked rest]: read it with `two?` and never for truth,
; because () is the one refusal -- a value flag left with nothing behind it -- and a
; tablet of no flags nets 0. <o is that tablet and <>>o the operands.
(: keysof (sort * keys * cap)
   ; the map a long name is read through: to a letter's key, so --width and -w are one
   ; option with one reader, or to anything else where there is no letter to share
   L {"width" 119 "text" 116 "no-build" 'nb "port" 112}
   (walk as) (: t {} (uopt as t '(119 116 112) '(101) L))
   (short as) (: t {} (uopt as t '(109) '(101) ())))

(test
 ; --- uopt1: one word into its letters ------------------------------------------------
 (["-q" "-e"] = (uopt1 "-qe" () "e"))           ; the chain ends on a value letter
 (["-q" "-e" "X"] = (uopt1 "-qeX" () "e"))      ; ..taking the rest of its own word
 (["-l" "-a"] = (uopt1 "-la" () ""))
 !(uopt1 "-qz" "qe" "")                   ; z is in neither set: the word is not ours
 !(uopt1 "--" () "")                      ; nor is the end-of-flags mark
 !(uopt1 "file" () "")
 !(uopt1 "-" () "")

 ; --- uopt: the short lane, which the long one leaves alone ---------------------------
 ([119] = (keysof (walk ["-w" "4" "f"])))
 ("4" = (uoptv <(walk ["-w" "4" "f"]) 119))
 ("4" = (uoptv <(walk ["-w4" "f"]) 119))                ; the value glued to its letter
 (["f"] = <>>(walk ["-w" "4" "f"]))
 (["f" "g"] = <>>(walk ["-w4" "f" "g"]))
 !(walk ["-w"])                                         ; a value flag with nothing behind
 (["--width" "2"] = <>>(walk ["--" "--width" "2"]))     ; -- ends the flags

 ; --- the long lane -------------------------------------------------------------------
 ("20" = (uoptv <(walk ["--width" "20" "f"]) 119))
 ("20" = (uoptv <(walk ["--width=20" "f"]) 119))        ; ..or glued behind its =
 (["f"] = <>>(walk ["--width=20" "f"]))
 ; a name with no letter to share stands on a key of its own
 (1 = (peep <(walk ["--no-build" "f"]) 'nb 0))
 ; the two lanes mix, and the shorts still cluster
 ([116 119] = (keysof (walk ["-w20" "--text=x" "f"])))
 ("x" = (uoptv <(walk ["-w20" "--text=x" "f"]) 116))
 ([112 119] = (keysof (walk ["--port" "80" "-w" "4"])))

 ; --- what the long lane refuses ------------------------------------------------------
 ; a name the map does not carry is not ours: that word ends the flags and is an operand,
 ; which is what an unknown long flag did here before there was a map at all
 (["--nope" "f"] = <>>(walk ["--nope" "f"]))
 !(keysof (walk ["--nope" "f"]))
 ; a glued value on a flag that takes none, rather than a value silently dropped
 (["--no-build=7" "f"] = <>>(walk ["--no-build=7" "f"]))
 !(walk ["--width"])                                    ; and a value flag left empty
 ; an applet that carries no long flags is exactly what it was: () is no map
 (["--width" "9" "f"] = <>>(short ["--width" "9" "f"]))

 ; --- uoptv, and the stacking lane ----------------------------------------------------
 !(uoptv <(walk ["-w" "4"]) 116)                        ; a flag that was never given
 !(uoptv <(walk ["--no-build"]) 'nb)                    ; a flag with no value is not one
 ; a key in `reps` stacks into the second slot instead of pinning, that being the option
 ; a tool spells more than once (sed -e, grep -e)
 (["a" "b"] = <>(: t {} (uopt ["-e" "a" "-e" "b" "f"] t '(101) '(101) ())))

 ; --- the three readings an applet owes over the walk ---------------------------------
 ; the short lane takes ANY letter, so the alphabet is the applet's to state and the key
 ; it did not name comes back for the refusal to spell
 (122 = (uoptun <(walk ["-w" "4" "-z" "f"]) '(119 116 112)))
 !(uoptun <(walk ["-w" "4" "f"]) '(119 116 112))
 !(uoptun <(walk ["f"]) '(119))                         ; nothing pinned is nothing unknown
 ('nb = (uoptun <(walk ["--no-build" "f"]) '(119)))     ; a long name's key, likewise
 ; an operand that still looks like a flag, the walk having stopped at the first that is
 ; not one -- and nothing at all once `--` has been spelled
 ("-q" = (uoptstray ["f" "-q"] <>>(walk ["f" "-q"])))
 !(uoptstray ["f" "g"] <>>(walk ["f" "g"]))
 !(uoptstray ["--" "-q"] <>>(walk ["--" "-q"]))
 !(uoptstray ["-"] ["-"])                               ; a bare dash is an operand, not a flag
 ; a flag's text as a number: `charm?` is the test, since 0 is a number and () is not
 (8080 = (unum "8080"))
 (0 = (unum "0"))
 !(unum "80a")
 !(unum "abc")
 !(unum "")
 !(unum ())
 !(unum "-5")                                           ; whole numbers, no sign
 !(charm? (unum "abc")))
