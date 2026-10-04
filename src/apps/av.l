; src/apps/av.l -- the decoder door's one list: a stream in, whichever codec claims it, out the
; horn. each codec module NAME answers NAME-sniff NAME-meta NAME-format NAME-pump (notes/plan/av.md).
; `(borrow 'av)`, then:
;
;   (av-codecs)        -> [[name sniff meta format pump] ..], the codecs in sniffing order
;   (av-open q)        -> [name m h], the codec, its meta and the audio bytes held | why not
;   (av-play q)        -> 0 when q has played out the horn to its end | why not
;   (av-pcm f emit)    -> an emit that turns f-shaped samples into the horn's s16 for emit
(module (av av-codecs av-open av-play av-pcm)
(:
   close (cite 'posix 'close)
   ; cited when asked, so a codec's module may bake after this one. a wav's meta is its
   ; own format: wav-format looks one up by name
   (av-codecs _) [["wav" (cite 'wav 'wav-sniff) (cite 'wav 'wav-meta) (m \ m) (cite 'wav 'wav-pump)]
                  ["flac" (cite 'flac 'flac-sniff) (cite 'flac 'flac-meta) (cite 'flac 'flac-format) (cite 'flac 'flac-pump)]]
   (av-more q h) (see q @ -1 h c (unsee q c, h + chug q))
   ; the first codec that says 1; 'more while one might and the stream has more
   (av-claim cs h) (: (go l more?) (? (atom? l) (more? ? 'more ())
                                      ((<l 1) h @ 1 <l 'more (go >l 1) _ (go >l more?)))
                      (go cs 0))
   (av-open q)
    (: cs (av-codecs ())
       (meta c h) ((c 2) h @ 'more (av-more q h @ h2 (#h2 = #h ? "cut short ahead of the audio" (meta c h2)))
                          m (tablet? m ? [(<c) m (snip h (m 'at) #h)] m))
       (go h) (av-claim cs h @ 'more (av-more q h @ h2 (#h2 = #h ? "no codec here reads this stream" (go h2)))
                               () "no codec here reads this stream"
                               c (meta c h))
       (go (av-more q "")))
   (av-pcm f emit)
    (pcm \ (: n (#pcm // f 'align) c (cask #pcm)
              (pour c 0 pcm 0 #pcm, emit (string ((cite 'wav 'wav-pcm) f n c)))))
   ; the horn's close drops what it holds, so it is waited out first
   (av-drain hn) (horn-lag hn @ n (charm? n && 0 < n ? (rest 10, av-drain hn) 0))
   (av-play q)
    (av-open q @
      [nm m h] (: c (<(filter (c \ <c = nm) (av-codecs ())))
                  f ((c 3) m)
                  (horn (f 'rate) (min 2 (f 'ch)) @ hn
                     (nom? hn ? ("no horn: " + show hn)
                      ((c 4) q h m (av-pcm f (say hn)) @ r
                         (flush hn, av-drain hn, close hn, r)))))
      why why))
) ; module av
