; src/love/compress/deflate.l -- RFC 1951 as data, and its readers: the tables inf.l lays, and the
; reference decoder. test/host/deflate.l writes streams off it and holds the C and gz-puff to it.
; a field is (name bits plus), its low bit first; a code's high bit comes first.
(:
   df-head '((last 1 0) (type 2 0))
   df-stored '((len 16 0) (nlen 16 0))                   ; from the next byte, nlen ~len
   df-dyn '((hlit 5 257) (hdist 5 1) (hclen 4 4))        ; then hclen lengths of df-clbits, in df-clord
   df-clbits 3
   df-clord '(16 17 18 0 8 7 9 6 10 5 11 4 12 3 13 2 14 1 15)
   ; a length symbol under 16 is that length; these repeat one: (symbol what bits plus)
   df-clops '((16 prev 2 3) (17 zero 3 3) (18 zero 7 11))
   ; the fixed code's lengths, as (count length) runs
   df-fixlit '((144 8) (112 9) (24 7) (8 8))
   df-fixdist '((32 5))
   df-end 256                                            ; under it a byte, past it a match's length
   df-hlit 286
   df-hdist 30
   df-maxbits 15
   ; a ladder: the first value, (codes extra-bits) runs, and the (value extra) rows after them
   df-lens '(3 ((8 0) (4 1) (4 2) (4 3) (4 4) (4 5)) ((258 0)))
   df-dists '(1 ((4 0) (2 1) (2 2) (2 3) (2 4) (2 5) (2 6) (2 7) (2 8) (2 9) (2 10) (2 11) (2 12) (2 13)) ())

   ; every way a stream is refused. an incomplete code is refused but for a lone one-bit symbol and
   ; a distance code of none. zlib refuses hdist past 30, which the rfc only says never occurs
   df-refusals '(torn type nlen hlit hdist cl-over cl-short rep-first rep-past noend
                 lit-over lit-short dist-over dist-short nocode sym dsym far)
   ; what inflate.h and gz-puff let by
   df-lenient '(hlit hdist cl-over cl-short rep-first rep-past lit-over lit-short dist-over dist-short)

   ; --- read off it ---------------------------------------------------------------------------------
   (df-runs l) (catmap (r \ map (_ \ r 1) ^(r 0)) l)
   ; a ladder's rows, [value extra] by code
   (df-ladder l)
    (: (go v es) (two? es ? ([v <es] . go (v + (1 << <es)) >es))
       (go (l 0) (df-runs (l 1)) + l 2))
   ; the canonical rule, 3.2.2: a code a symbol of some length, [symbol code length]
   (df-canon lens)
    (: cnt (foldl (\ t l (l ? (pin t l (1 + peep t l 0)) t)) {} lens)
       nx {}
       (nxt l c) (l <= df-maxbits ? (: c2 (c + peep cnt (l - 1) 0 << 1) (pin nx l c2, nxt (l + 1) c2)) 0)
       _ (nxt 1 0)
       (go i ls) (? !(two? ls) ()
                    !<ls (go (i + 1) >ls)
                    (: l <ls c (nx l) _ (pin nx l (c + 1)) ([i c l] . go (i + 1) >ls)))
       (go 0 lens))
   ; what a code leaves unsaid, in 2^-15ths: 0 complete, under it oversubscribed
   (df-left lens) (foldl (\ a l (? l (a - (1 << df-maxbits - l)) a)) (1 << df-maxbits) lens)
   (df-lone? lens) ([1] = filter (l \ 0 < l) lens)
   (df-none? lens) (all (l \ l = 0) lens)
   ; a code to walk: 1 and the bits so far -> its symbol
   (df-walk lens) (foldl (\ t r (pin t (1 << r 2 | r 1) (r 0))) {} (df-canon lens))

   ; --- the reference decoder ------------------------------------------------------------------------
   ; s's stream, at most cap bytes of it -> [1 out bits-read], or [0 why]. a refusal in skip is let
   ; by; (see kind value) hears what the stream uses
   df-lent (df-ladder df-lens)
   df-distt (df-ladder df-dists)
   df-flit (df-runs df-fixlit)
   df-fdist (df-runs df-fixdist)
   (df-no why) (scare 'deflate why)
   (df-run s cap skip see)
    (: st {'p 0 'n 0}  o (cask cap)  n (8 * #s)
       (need c why) (? c 1 (elem why skip) 1 (df-no why))
       (bit _) (: p (st 'p) (p < n ? (pin st 'p (p + 1), s (p >> 3) >> (p & 7) & 1) (df-no 'torn)))
       (bits k) (: (go i a) (i < k ? (: b (bit 0) (go (i + 1) (a | b << i))) a) (go 0 0))
       (field f) (: v (bits (f 1)) w (v + f 2) _ (see (f 0) w) w)
       (out b) (: k (st 'n) (k < cap ? (pin o k b, pin st 'n (k + 1), 0) (df-no 'cap)))
       (sym kind c)
        (: (go l k) (df-maxbits < l ? (df-no 'nocode)
                       (: b (bit 0) k2 (k << 1 | b) v (peep c k2 -1)
                          (v < 0 ? (go (l + 1) k2) (see kind v, see 'bits l, v))))
           (go 1 1))
       (code lens over short lone none)
        (: left (df-left lens)
           _ (need (0 <= left) over)
           _ (need (? (left = 0) 1 (lone && df-lone? lens) 1 (none && df-none? lens) 1 0) short)
         (df-walk lens))
       (stored _)
        (: _ (pin st 'p (st 'p + 7 >> 3 << 3))
           len (field (df-stored 0))  nlen (field (df-stored 1))
           _ (need (len + nlen = 65535) 'nlen)
           (go i) (i < len ? (: b (bits 8) (out b, go (i + 1))) 0)
         (go 0))
       (copy d len) (: k (st 'n) (len ? (out (peep o (k - d) 0), copy d (len - 1)) 0))
       (toks lit dist)
        (: v (sym 'lit lit)
         (? (v < df-end) (out v, toks lit dist)
            (v = df-end) 0
            (df-hlit <= v) (df-no 'sym)
            (: r (df-lent (v - df-end - 1))
               x (bits (r 1)) len (r 0 + x)
               dv (sym 'dist dist)
               _ (need (dv < df-hdist) 'dsym)
               e (df-distt dv)
               y (bits (e 1)) d (e 0 + y)
               _ (need (d <= st 'n) 'far)
             (see 'len len, see 'far d, copy d len, toks lit dist))))
       (dyn _)
        (: hl (field (df-dyn 0)) _ (need (hl <= df-hlit) 'hlit)
           hd (field (df-dyn 1)) _ (need (hd <= df-hdist) 'hdist)
           hc (field (df-dyn 2))
           cl {}
           (rd i) (i < hc ? (: v (bits df-clbits) (pin cl (df-clord i) v, rd (i + 1))) 0)
           _ (rd 0)
           cc (code (map (i \ peep cl i 0) ^19) 'cl-over 'cl-short 0 0)
           tot (hl + hd)
           (lens i prev)
            (tot <= i ? ()
             (: v (sym 'cl cc)
              (v < 16 ? (v . lens (i + 1) v)
               (: op (find-op v df-clops)  x (bits (op 2))  k (op 3 + x)
                  _ (see 'rep (v . k))
                  w (op 1 == 'zero ? 0 (need i 'rep-first, prev))
                  _ (need (i + k <= tot) 'rep-past)
                  _ (? (i < hl && hl < i + k) (see 'cross v) 0)
                (map (_ \ w) ^k + lens (i + k) w)))))
           (find-op v l) (v = <<l ? <l (find-op v >l))
           all2 (lens 0 0)
           ll (take hl all2)  dl (take hd (drop hl all2))
           _ (need (ll df-end) 'noend)
           lit (code ll 'lit-over 'lit-short 1 0)
           dist (code dl 'dist-over 'dist-short 1 1)
         (toks lit dist))
       (blocks _)
        (: last (field (df-head 0))  type (field (df-head 1))
           _ (type @ 0 (stored 0)
                     1 (toks (df-walk df-flit) (df-walk df-fdist))
                     2 (dyn 0)
                     (df-no 'type))
         (last ? [1 (snip (string o) 0 (st 'n)) (st 'p)] (blocks 0)))
     (trap blocks 0 (a \ b \ (a == 'deflate ? [0 b] (scare a b)))))
   (df-decode s cap) (df-run s cap () (_ \ _ \ 0)))
