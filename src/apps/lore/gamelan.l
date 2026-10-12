; gamelan -- a level's music as a gamelan plays it slow: a chime struck now and then on a
; five-note scale, and a gong under it every so many seconds, out the horn a frame at a
; time. the port is any jug, so a song gates headless.
;
;   (gamelan-new h sd)       a song into port h, its die spun from sd
;   (gamelan-feed s tune)    one frame's chunk of it: a chime by the die and a gong when it
;                            is due. tune is {'scale the five steps in semitones from
;                            middle c 'down the octaves under it 'high one in high the
;                            octave over 'gain a chime's least 'odds a chime's chance a
;                            chunk, in thousandths 'gong the gong's note 'gong-gain
;                            'gong-legato 'gong-every its least seconds apart}
(module (gamelan gamelan-new gamelan-feed)
(borrow 'rove)                          ; the die, the rate
(borrow 'play)                          ; the voices, the mix
(:
 fps 30
 chunk (song-rate // fps)                               ; a frame's worth
 gain 11000.0
 ; the song: its port, a spun die, the frames written, the voices ringing, when the gong
 ; is next due, and how many strikes there have been
 (gamelan-new h sd) {'h h 'sb {sd} 'fpos 0 'vs () 'gong 0 'struck 0}
 ; ..a chime by the die, its degree and octave off the die too; a gong when it is due,
 ; the next some seconds on
 (gamelan-feed s tune) (: sb (s 'sb) base (s 'fpos)
   (strike v) (base + roll sb chunk @ at
                 (pins s 'vs (s 'vs + [[at (mkvoice at v song-rate)]]) 'struck (s 'struck + 1)))
   (roll sb 1000 < tune 'odds ?
      (strike {'s "chime" 'note (tune 'scale (roll sb 5) + tune 'down + 12 * (roll sb (tune 'high) = 0))
               'gain (tune 'gain + roll sb 40 / 100.0) 'pan (0.2 + roll sb 60 / 100.0) 'legato 5.0}),
    s 'gong <= base ?
      (strike {'s "tri" 'note (tune 'gong) 'gain (tune 'gong-gain) 'pan 0.5 'legato (tune 'gong-legato)},
       pin s 'gong (base + song-rate * (tune 'gong-every + roll sb 6))),
    song-out s chunk gain)))
) ; module gamelan
