; gamelan -- a level's music played slow: a chime now and then on a five-note scale and a
; gong under it every so many seconds, a frame's chunk at a time into any port.
;   (gamelan-new h sd)       a song into port h, its die spun from sd
;   (gamelan-feed s tune)    one chunk. tune is {'scale five semitones from middle c, 'down the
;                            octaves under it, 'high one in high an octave over, 'gain a
;                            chime's least, 'odds its chance a chunk in thousandths, 'gong
;                            its note, 'gong-gain, 'gong-legato, 'gong-every least seconds apart}
(module (gamelan gamelan-new gamelan-feed)
(borrow 'rove)                          ; the die, the rate
(borrow 'play)                          ; the voices, the mix
(:
 fps 30
 chunk (song-rate // fps)                               ; a frame's worth
 gain 11000.0
 ; the song: its port, a die, frames written, voices ringing, the gong's next frame, strikes
 (gamelan-new h sd) {'h h 'sb {sd} 'fpos 0 'vs () 'gong 0 'struck 0}
 ; ..a chime by the die; a gong when due, the next some seconds on
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
