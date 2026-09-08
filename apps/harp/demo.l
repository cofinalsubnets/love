; apps/harp/demo.l -- harp as a library rather than a verb: five patterns stacked,
; rendered to a .wav. What the mini-notation cannot say (a transform per layer, a
; control taken from a continuous pattern) is said in love around it.
;
;   love apps/harp/demo.l [OUT.wav]        default out/harp-demo.wav
;   love apps/harp/play.l -n 8 -c 0.55 -g 0.55 'bd ~ [~ bd] ~' 'hh*8?' '~ cp ~ [sn ~ sn]'
;
; the second line is the same shape from the shell, less the transforms: a bare
; argument is mini-notation, and several arguments stack.
(use (: m (from 'harp) (? m m "apps/harp/harp.l")))
(use "apps/harp/play.l")
(:
   ; every fourth cycle the kick doubles up -- `every` takes the transform, so the
   ; variation is a function of the pattern and not a second pattern to keep in step
   kick  (every 4 (\ q (fastcat [q (hit (mini "bd*2"))])) (hit (mini "bd ~ [~ bd] ~")))
   ; eight hats, half of them dropped, riding a slow swell: `sine` has no structure
   ; of its own, so `#` samples it wherever the hats put their onsets
   hats  (pset (hit (mini "hh*8?")) (gain (range 0.25 0.8 sine)))
   snare (pset (hit (mini "~ cp ~ [sn ~ sn]")) (gain (pure 0.8)))
   ; two cycles of bass under one of everything else, the third note alternating
   bass  (pset (pset (note (slow (qi 2) (mini "-24 -17 <-20 -25> -22")))
                     (hit (pure "saw")))
               (gain (pure 0.55)))
   ; jux plays the dry line hard left and the reversed one hard right
   lead  (jux rev (pset (pset (note (mini "<[0 7 12 7] [3 10 15 10]>*2 ~ [12 15]"))
                              (hit (pure "tri")))
                        (gain (pure 0.4))))
   song  (stack [kick hats snare bass lead])

   (demo-main as)
    (: w (? (two? as) <as "out/harp-demo.wav")
       _ (harp-wav song 0 8 48000 0.55 24000 11000.0 w)
       _ (say out $ w + "\n") 0))

(: s (from 'verbs 'fire ["harp-demo" "demo.l"])
   (two? s ? (quit (demo-main >s))))
