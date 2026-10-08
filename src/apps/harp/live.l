; live -- harp's repl: a pattern in a vi buffer, played as it is sent, and the words of it
; sounding now lit in the text, as strudel lights its own.
;
; C-e sends the buffer (and plays, if it stood), C-k stops; :send :play :stop :cps N are
; the same as ex words, and :w writes the file. a sent pattern takes over at a cycle's
; start, and a line edited since it was sent goes dark until it is sent again. the loop,
; the voices and the card are synth's; what is new here is which events sound now.
;
; run: love harp -i [FILE]   HORN=none plays silent on a seat with no card
(module (harplive live-main live-lit live-spans live-rc live-usage)
(borrow 'rove)                          ; the pacer and the song's rate
(borrow 'harp)                          ; evlocs, and lrev: harp's rev is the pattern one
(borrow 'synth)                         ; the loop: its state, send, feed and ex words
(borrow 'posix)                         ; close, for the horn
(:
 live-usage "usage: love harp -i [FILE]   (C-e sends the buffer, C-k stops, :q leaves)"
 ; a byte offset in t as [row col]
 (live-rc t o) (:- (go 0 0 0) (go i r c)
                 (? (i >= o || i >= #t) [r c]
                    (10 = t i) (go (i + 1) (r + 1) 0)
                    (go (i + 1) r (c + 1))))
 ; t's lines, as the buffer holds them
 (lines t) (:- (go 0 0 ()) (go i a acc)
             (? (i >= #t) (lrev (snip t a i . acc))
                (10 = t i) (go (i + 1) (i + 1) (snip t a i . acc))
                (go (i + 1) a acc)))
 ; the events of 'lit sounding at frame now: [start end locs text], start <= now < end
 (live-lit lit now) (filter (x \ <x <= now < <>x) lit)
 ; their words as vi's marks, [row c1 c2], on the rows that still read as they did when
 ; sent; a span over a line's end is cut to it
 (live-spans lit ls)
  (cmap (x \ (: t (x 3) tl (lines t)
                (filter two? (map (l \ (: a (live-rc t <l) b (live-rc t <>l) row <a
                                         (? (row != <b || tl row != ls row) ()
                                            [row <>a <>b])))
                                  (x 2)))))
        lit)

 (live-run vi f)
  (: _ (synth-warm ())
     st (synth-new ())
     _ (pin st 'lights 1)
     hn (horn song-rate 2 @ h (nom? h ? () h))
     pace (pacer ())
     buf (vi 'vi-open f)
     _ (pin buf 'exmore '("send" "play" "stop" "cps"))
     face (vi 'vi-face buf {'ex (synth-ex st)})
     ; with no card the loop is fed by the clock, into nothing
     t0 (clock 0)
     (dry _) (st 'fpos < clock t0 * song-rate // 1000 ? (synth-feed st (jug 0), dry ()))
     (feed _) (song-lead-of (pace! pace) @ l
                 (hn ? (song-fill hn l (_ \ synth-feed st hn)) (dry ())))
     ; the frames the card holds ahead of the speaker, so 'fpos less them is what sounds.
     ; the marks moved: a frame. events over are let go
     (light _) (: now (st 'fpos - (hn ? (horn-lag hn @ g (charm? g ? g 0)) 0))
                  _ (pin st 'lit (filter (x \ now < x 1) (st 'lit)))
                  g (buf 'markgen)
                  _ (vi 'vmarks buf (live-spans (live-lit (st 'lit) now) (buf 'lines)))
                  (g != buf 'markgen))
     (send _) (synth-send st (synth-text (buf 'lines)))
     (status w) (: m (st 'lmsg @ "" "" m "  \(m)")
                   ps (st 'on ? "playing" "stopped")
                   s " harp  \(ps)  cycle \(st 'cyc)  cps \(st 'cps)\(m)   C-e send  C-k stop  :q leave"
                   (snip s 0 w))
     ; vi lays all but the last row; the status goes there, the cursor kept where vi put it
     (frame w h) (face 0 w (h - 1) + "\e7\e[" + show h + ";1H\e[7m" + status w + "\e[0m\e[K\e8")
     (step c) (c @ 5 (send ()) 11 (synth-stop st) (face 1 c))
     ; the loop is synth's own: the card fed, the marks lit, a frame on a change, and
     ; every key waiting read without blocking, so the card never waits on the keys
     (keys _) (? (face 2 ()) 'quit
                 !(cue? 0) ()
                 (edkey in @ -7 'quit k (step k, pin st 'dirty 1, keys ())))
     (go sz) (: _ (feed ())
                g (ttysize 7 19)
                d (light () || st 'dirty || g != sz)
                (d ? (pin st 'dirty 0, say out (frame (g 1) <g), flush out),
                 keys () @ 'quit () (rest 4, go g)))
   (ttytake ['hide],
    mind go () (_ \ (hn ? (flush hn, close hn), ttygive ['hide])),
    0))
 (live-main as) (: vi (cite 'vi)
   (? (1 < #as) (say err ("harp: " + live-usage + "\n"), flush err, 2)
      !(tablet? vi) (say err "harp: no vi on this seat\n", flush err, 1)
      (live-run vi (two? as ? <as "")))))
) ; module harplive
