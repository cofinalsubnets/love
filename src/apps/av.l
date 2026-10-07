; src/apps/av.l -- the decoder door's one list: a stream in, whichever codec claims it, out the
; horn. each codec module NAME answers NAME-sniff NAME-meta NAME-format NAME-pump (notes/plan/av.md).
; `(borrow 'av)`, then:
;
;   (av-codecs)        -> [[name sniff meta format pump] ..], the codecs in sniffing order
;   (av-codec nm)      -> the codec named nm, as av-codecs lays it
;   (av-open q)        -> [name m h], the codec, its meta and the audio bytes held | why not
;   (av-play q)        -> 0 when q has played out the horn to its end | why not
;   (av-pcm f emit)    -> an emit that turns f-shaped samples into the horn's s16 for emit
;   (av-uri u)         -> [q info] for a path or an http(s) stream (src/apps/icy.l), info its
;                         tablet ({} for a file) | why not
;   (av-head q f h0)   -> [r h]: the head of q, h0 what is held already, read until f answers
;                         r of h -- 'short when the stream ended first, or why when the head
;                         passes av-cap. every tool reads a head through it (av.md, the door's
;                         reading). f may answer ['more N] (nothing decides before byte N),
;                         'more (twice what is held), or ['skip A B R]: bytes A..B hold nothing
;                         wanted, R takes their place, and they leave the port without being held
;   (av-patch path at s) -> 0 | why: s laid over the file at byte at, in place -- the header a
;                         tool wrote ahead of what it streamed, its sizes known at the end
;   (av-head-all q f h0), (av-open-all q)  the same, skipping nothing: for what keeps every
;                         byte of a head (metaflac, the flac encoder copying blocks)
(module (av av-codecs av-codec av-open av-open-all av-play av-pcm av-uri av-head av-head-all av-cap av-patch)
(borrow 'wav)
(:
   open (cite 'posix 'open) close (cite 'posix 'close)
   ; cited when asked, so a codec's module may bake after this one. a wav's meta is its
   ; own format: wav-format looks one up by name
   (av-codecs _) [["wav" (cite 'wav 'wav-sniff) (cite 'wav 'wav-meta) (m \ m) (cite 'wav 'wav-pump)]
                  ["flac" (cite 'flac 'flac-sniff) (cite 'flac 'flac-meta) (cite 'flac 'flac-format) (cite 'flac 'flac-pump)]
                  ["ogg" (cite 'ogg 'ogg-sniff) (cite 'ogg 'ogg-meta) (cite 'ogg 'ogg-format) (cite 'ogg 'ogg-pump)]
                  ["mp3" (cite 'mp3 'mp3-sniff) (cite 'mp3 'mp3-meta) (cite 'mp3 'mp3-format) (cite 'mp3 'mp3-pump)]]
   (av-codec nm) <(filter (c \ <c = nm) (av-codecs ()))
   av-cap 16777216
   ; a raw fd, since lseek takes one and a port's buffer would desync under it
   (av-patch path at s)
    ((cite 'posix 'openfd) path 4 @ fd
      (? !(charm? fd) ("cannot write " + path)
         (charm? ((cite 'posix 'lseek) fd at 0))
          (: p (fdopen fd) _ (say p s) _ (flush p) (close p, 0))
         (: _ (close fd) ("cannot seek in " + path))))
   ; gulps are kept as a list and joined once a step; f runs only when the head has grown to
   ; what it asked, so a head costs a parse a block, not a parse a gulp
   (av-head q f h0) (av-read q f h0 1)
   (av-head-all q f h0) (av-read q f h0 0)
   (av-read q f h0 skip?)
    (: ; h grown to n bytes, or as far as the stream goes
       (fill h n) (: (go acc len) (? (len >= n) (cats (rev acc))
                                     (wav-gulp q @ g (string? g ? (go (g . acc) (len + #g)) (cats (rev acc)))))
                     (go [h] #h))
       ; n bytes taken off the port and let go -> what was read past them | () at the end
       (drop n) (wav-gulp q @ g (? !(string? g) () (#g > n) (snip g n #g) (#g = n) "" (drop (n - #g))))
       (grow h n) (? (n > av-cap) ["the head of this stream is past 16 MiB" h]
                     (fill h n @ h2 (#h2 < n && #h2 = #h ? ['short h] (step h2))))
       (step h)
        (f h @
          'more (grow h (2 * #h + 4096))
          ['more n] (grow h (max n (#h + 1)))
          ['skip a b r] (? !skip? (grow h b)
                           (b <= #h) (step (snip h 0 a + r + snip h b #h))
                           (drop (b - #h) @ () ['short h] t (step (snip h 0 a + r + t))))
          r [r h])
       (step h0))
   ; the first codec that says 1; 'more while one might and the stream has more
   (av-claim cs h) (: (go l more?) (? (atom? l) (more? ? 'more ())
                                      ((<l 1) h @ 1 <l 'more (go >l 1) _ (go >l more?)))
                      (go cs 0))
   (av-open q) (av-opens q 1)
   (av-open-all q) (av-opens q 0)
   (av-opens q skip?)
    (: cs (av-codecs ())
       (av-read q (h \ av-claim cs h) "" skip? @
         ['short _] "no codec here reads this stream"
         [() _] "no codec here reads this stream"
         [c h] (? (string? c) c
                  (av-read q (c 2) h skip? @
                    ['short _] "cut short ahead of the audio"
                    [m h2] (tablet? m ? [(<c) m (snip h2 (m 'at) #h2)] m)))))
   (av-pcm f emit)
    (pcm \ (: n (#pcm // f 'align) c (cask #pcm)
              (pour c 0 pcm 0 #pcm, emit (string (wav-pcm f n c)))))
   (av-uri u)
    (? (starts? u "http://" || starts? u "https://")
        ((cite 'icy 'icy-open) u @ [q info] [q info] why why)
       (open u "r" @ q (hot? q ? [q {}] ("cannot open " + u))))
   (av-play q)
    (av-open q @
      [nm m h] (: c (av-codec nm)
                  f ((c 3) m)
                  (horn (f 'rate) (min 2 (f 'ch)) @ hn
                     (nom? hn ? ("no horn: " + show hn)
                      ((c 4) q h m (av-pcm f (say hn)) @ r
                         (flush hn, wav-drain hn, close hn, r)))))
      why why))
) ; module av
