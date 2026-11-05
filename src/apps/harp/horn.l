; src/apps/harp/horn.l -- feeding the horn: the rate love plays at, and a pacer that keeps the
; card's queue a little longer than the gap between feeds. every sample is a closure call, so
; wasm plays at a third of the 48k and a small core at the 44.1k's half.

(module '(horn song-rate song-lead song-lead-max pacer pace! song-lead-of song-fill song-keep)
(:
 song-rate (love-arch @ 'wasm 16000 'other 22050 48000)
 ; the queue must outlast the gap between feeds, which on a slow machine is a frame's paint;
 ; the pacer holds the gap at its recent worst, halving every two seconds of clock, and the
 ; lead is two and a half gaps, clamped to song-lead .. song-lead-max
 song-lead (6 * (song-rate // 30))
 song-lead-max (120 * (song-rate // 30))
 (pacer _) (clock 0 @ t {'t t 'w t 'gap 0.0 'cap song-lead-max 'step 0})
 (pace! p) (: t (clock 0)
              d (1.0 * (t - p 't))
              v (((t - p 'w) / 2000.0) 0.5 * p 'gap)
              ((pins p 't t 'w t 'gap (v < d ? d v)),
               p 'gap))
 (song-lead-of gap) (int (2.5 * gap * song-rate / 1000.0) @ n
                       (n < song-lead ? song-lead (song-lead-max < n ? song-lead-max n)))
 ; the horn fed up to a lead, while each feed raises the lag: a full ring or run takes nothing,
 ; so a lead past them is never reached and the filler stops rather than loop. answers the feeds
 (song-fill hn lead feed) (:- (go (horn-lag hn) 0) (go l0 k)
                            (l0 < lead ? (: _ (feed ()) l1 (horn-lag hn) (l0 < l1 ? (go l1 (k + 1)) (k + 1)))
                               k))
 ; ..the horn kept a pacer's lead ahead, lo at least. a feed the ring parks raises the lag
 ; by under half a feed's: the ring is full there, and the lead stays a feed under it from
 ; then on. the pacer's clock taken again after, so a fill's own wait is never a gap
 (song-keep hn p lo feed) (: n (int (2.5 * pace! p * song-rate / 1000.0))
   lead (min (p 'cap) (n < lo ? lo (song-lead-max < n ? song-lead-max n)))
   (go l0 k) (? (l0 >= lead) k
      (: _ (feed ()) l1 (horn-lag hn) r (l1 - l0) st (p 'step)
         (? (r <= 0) (k + 1)
            (r * 2 < st) (pin p 'cap (max (2 * st) (l0 - st)), k + 1)
            (pin p 'step (max st r), go l1 (k + 1)))))
   k (go (horn-lag hn) 0)
   (pin p 't (clock 0), k)))
) ; module horn
