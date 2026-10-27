
; post -- the third egg stage, after prel and ev, before the mop. the one stage that sees
; both the finished compiler and the internal noms the mop removes (peek seek atype nifnom):
; a reference compiled here folds to a value and survives, so raw heap readers belong here.
; most of it is the printer; `print` `dot` `show` `putx` and the `.` sigil are pinned at the
; foot, in holes prel leaves: a nif folded into prel's compile could not be replaced.


; --- words nothing in the egg reads ---
(: pi 3.141592653589793
   tau (2 * pi)
   true 1 false 0
   (caaap x) <<<x (caaup x) <<>x
   (cauap x) <><x (cauup x) <>>x
   (cuaap x) ><<x (cuaup x) ><>x
   (cuuap x) >><x
   stdin in stdout out stderr err
   sine sin cosine cos tangent tan fabs abs
   star-tray (tray 0) gem-tray (tray 0.0) twin-tray (tray (twin 0 0)) top-tray (tray ())  ; the four typed-tray ctors
   (tier v) (tray? v ? (atype v @ c (? (c = 0) star-tray (c = 1) gem-tray (c = 2) twin-tray top-tray)))  ; a tray's ctor; nil off a tray
   zero? nil?
   ; splice a module just below the head: its names resolve but never shadow yours. a miss
   ; scares rather than splicing (): a book the walk cannot read faults in map_probe.
   (borrow m)    (: b (tablet? m ? m
                    (lib () m @ r (r ? r (scare 'no-module m))))
               (tablet? b ? (setstack (<(stack ()) . b . >(stack ()))) b))
   ; a module's tablet, curried to a member: (cite 'holo 'assemble). (cite ()) lists the
   ; registry, a miss answers (). members fold in at compile, so a pin affects only later code.
   (cite k)   (k ? (lib () k) (keys (lib ()))))

(: putc (put out)
   puts (say out)
   (putn n) (putbn out n 10)
   (getc _) (see in)
   neg negate recip reciprocal frac fraction
   ; galaxy? keys on the cells, not the tier code, so an object tray of bignums still counts
   (galaxy? x) (tray? x ? (top-tray != tier x ? 1 (star? (peep x 0 0))) 0)
   (foldl1 f l) (foldl f <l >l)
   (foldr1 f l) (foldr f (last l) (init l))
   ap (foldl id))

(: ; each layer keeps its macros at its nil key; this walks the chain `macros` looks through
   (macro-names _) (filter nom? (keys (foldl (\ t k (pin t k 1)) {}
                                             (catmap (b \ (b 0 @ m
                                                             (tablet? m ? (keys m))))
                                                     (stack ())))))
   (part p) (foldr (\ a m (p a ? ((a . <m) . >m)
                                 (<m . a . >m))) '(())))

; a port head is three words: ap, vt, ungetc. each poke answers the cell it wrote, so
; `poke -1` walks backwards; the vt (a value, poke) is the port's kind, the ap an insn (place).
(: (tap cl)
 (place -1 (pick 0 in) (poke -1 ci-vt (poke -1 -1 (poke 3 cl (spin 4)))))
 (jug _)                                          ; the output dual of `tap`: say into it, slurp it back out
  ; the backing starts empty: a sized literal would be shared by every jug, and to_writen
  ; fills a backing in place
  (place -1 (pick 0 in) (poke -1 to-vt (poke -1 -1 (poke -1 "" (poke 4 0 (spin 5))))))
 ; hot? first, so the read only lands on a heap cell
 (port? o) (hot? o ? (pick 0 o == pick 0 in) 0)   ; the else arm is the bit: a two-armed ? answers the zero point
 ; drain a vessel to a value. it accumulates rather than recursing: a parking port copies
 ; its stack per task switch. each turn lands a byte in the jug or reads the end.
 (slurp o) ((port? o ? (to-vt == peek 1 o)) ? (snip (peek 3 o) 0 (peek 4 o))   ; a jug by its vt: a buffered fd port's word 3 is a string too
              (: j (jug 0)
                 (go u) (see o @ c (c @ -1 (slurp j)
                                        (put j c, say j (chug o), go ())))
                 (go ())))
 ; a promise. the answer is kept as (1 . v) so a forced () reads as forced
 (once f) (tablet 0 @ t (u \ (t 0 @ v (two? v ? >v (f () @ w (pin t 0 (1 . w), w))))))
 ; a port as a lazy charlist: the gulped run realized, the tail a promise. the tail must be a
 ; `once`, or a residue read twice would lose bytes. `see` refills; chug never reads the device.
 (flow p) (: (gulp tl) (see p @ c
                          (c @ -1 tl
                               (: t (unsee p c, chug p)
                                  (go k l) (0 >= k ? l (k - 1 @ j (go j (. (t j) l))))
                                  (go #t tl))))
             c (see p)
             (c != -1 ? (unsee p c, gulp (once (_ \ flow p)))))
 ; flow one byte per force, where a whole run would read too far ahead
 (trickle p) (see p @ c (c != -1 ? (c . once (_ \ trickle p)))))
(seal-hook 6 flow)   ; the reader's port door

(:: '>>= (l \ (. (last l) (init l))))
(:: '<=< (g \ (nom 0 @ y ['\ y (foldr (\ f x [f x]) y g)])))
(: pow ** power ** car cap cdr cup cons .)

; --- borrow on a path ---
; a string loads a file into a fresh layer; a name is never turned into a path. a file with no
; (module nm ..) is that layer, keyed by its path, and takes the name only when no module holds
; it; a file that made its own module keeps it, and the path remembers it. a path reads once,
; marked by path not name: several files may register one module. without the posix module's
; open, every path misses.
(: borrow
   (: prior borrow
      ; read-eval each form; a torn form scares. `flow`, not `slurp`, to avoid four copies
      (rdev q) ((: (go cl) (sound cl @ r
                              (? (two? r) (ev <r, go >r)
                                 (r == 'torn) (scare 'unfinished-form q)
                                 0)))
                (flow q))
      ; a layer with no nom key is not a module (charm keys 0 and 31337 sit in every layer)
      (bare? t) ((: (go ks) (two? ks ? (nom? <ks ? 0 (go >ks)) 1)) (keys t))
      (mname s) (: n #s
                   b (foldl (\ r k (47 = peep s k 0 ? (k + 1) r)) 0 ^n)
                   t (snip s b n)
                   (intern (t @ ((x && 0 < #x) + ".l") x t)))
      fsopen (cite 'posix 'open)
      (m \ (? (tablet? m) (prior m)
              (string? m)
              (mname m @ nm
                 ; the path's mark: its layer, the name its file registered, or 1 mid-read
                 (peep (lib ()) m () @ v
                   (? (v = 1) ()
                      (v != ()) (prior v)
                      (: q (!fsopen ? () (fsopen m "r"))
                         (!(hot? q) ? (prior m)
                            ; the mark goes down before the read, so a file naming itself stops
                            (: _ (pin (lib ()) m 1)
                               _ (enter ()) _ (rdev q) w (leave ())
                               (? !(bare? w)
                                   (: _ (pin (lib ()) m w)
                                      _ (? (nil? (lib () nm)) (pin (lib ()) nm w) 0)
                                      (prior w))
                                  ; a bare layer: the module the file made under its name, if any
                                  (lib () nm) (: _ (pin (lib ()) m nm) (prior nm))
                                  ())))))))
              (prior m)))))

; a module's macros (its key 0) into the head layer, without its names: ks names them, ()
; takes all. the way to get macros from a module reached by `cite`.
(: (transcribe m ks)
   (cite m 0 @ M
      (tablet? M ?
         (each (two? ks ? ks (keys M)) (k \ (M k @ v (v && :: k v)))))))

(: bigdigits (:
   ; a non-negative integer's digits in base r by halves: x = q r^k + m, each half alone, so
   ; the digits cost products, not a division a digit. a level is [r^k bits inv k], inv its
   ; reciprocal; the top's is laid as the top split needs it, at the quotient's width
   (dch n r a) (: q (n // r) d ("0123456789abcdefghijklmnopqrstuvwxyz" (n - q * r))
                  (0 < q ? (dch q r (d . a)) (d . a)))
   (dpad w s) (#s < w ? ("0" * (w - #s) + s) s)
   ; floor(4^b / p), 2^(b-1) <= p < 2^b: newton from the top half's, its correction from the
   ; top k bits of each factor, then a fix by the residue
   (drecip p b) (? (b <= 8192) ((1 << (2 * b)) // p)
                   (: h (b // 2 + 64) w (1 << (2 * b))
                      x ((drecip (p >> (b - h)) h) << (b - h))
                      e (w - p * x)
                      k (b - h + 64) t (b + 1 - k) u (max 0 (bitlen e - k))
                      y (x + (((x >> t) * (e >> u)) >> (2 * b - t - u)))
                      r (w - p * y)
                      (r < 0 ? (y - ((p - r - 1) // p)) (y + (r // p)))))
   ; the levels for n, most first: r^k0 the largest power a charm holds, squared while it fits
   (dlevels n r) (: nb (bitlen n)
                    (lay l) [<l (l 1) (l 1 > 8192 ? (drecip <l (l 1)) 0) (l 2)]
                    (go p k acc) (: b (bitlen p) (top _) ([p b 0 k] . map lay acc)
                                    (2 * b - 2 >= nb ? (top 0)
                                       (: pp (p * p) (pp > n ? (top 0) (go pp (2 * k) ([p b k] . acc))))))
                    (p0 p k) ((p * r) < (1 << 62) ? (p0 (p * r) (k + 1)) (go p k ()))
                    (p0 r 1))
   ; [q m] of x by p, b its bits, inv its reciprocal or 0. q's m bits are all a product needs:
   ; the estimate takes inv's top m + 64, or with none divides p's top m + 64 bits into x's
   (ddiv x p b inv) (: m (bitlen x - b + 1)
                       (adj q r) (? (r < 0) (adj (q - 1) (r + p)) (r >= p) (adj (q + 1) (r - p)) [q r])
                       (? (m < 1) [0 x]
                          (m < 2048 || b <= 8192) [(x // p) (x % p)]
                          (: q (? (inv != 0) (: s (max 0 (b + 1 - m - 64))
                                                (((x >> (b - 1)) * (inv >> s)) >> (b + 1 - s)))
                                  (b - m - 64 > 0) (: s (b - m - 64) ph (p >> s)
                                                     <(ddiv (x >> s) ph (b - s) (drecip ph (b - s))))
                                  <(ddiv x p b (drecip p b)))
                             (adj q (x - q * p)))))
   ; x's digits, w of them (0: as many as it has)
   (dsay o x r ls w) (? (atom? ls) (say o (dpad w (string (dch x r ()))))
                        (: l <ls k (l 3)
                           (w = 0 && x < <l ? (dsay o x r >ls 0)
                              (: qr (ddiv x <l (l 1) (l 2)) (dsay o <qr r >ls (w ? (w - k) 0), dsay o (qr 1) r >ls k)))))
   (go n r) (jug 0 @ o (dsay o n r (dlevels n r) 0, slurp o))
   go))

(: (chars s) (map s ^#s)                      ; a string is an atom, so map needs the indices
   (findsub s sub) (#sub = 0 ? 0 (fsub s sub 0))        ; -1 when absent
   (has? s sub)    (0 <= findsub s sub)
   (starts? s p)   (string? s && string? p ? (sits? s 0 p) (#p <= #s && snip s 0 #p = p ? 1 0))   ; a ?-name owes a bit, and && gives ()
   (ends? s p)     (string? s && string? p ? (sits? s (#s - #p) p) (#p <= #s && snip s (#s - #p) #s = p ? 1 0))
   (replace s cite to) (#cite = 0 ? s (join to (split cite s)))
   (ws? c)  (c = 32 || c = 9 || c = 10 || c = 13 ? 1 0)
   (digit? c) (48 <= c <= 57 ? 1 0)
   (alpha? c) (65 <= c <= 90 || 97 <= c <= 122 ? 1 0)
   (alnum? c) (digit? c || alpha? c ? 1 0)
   ; a hex digit's value, -1 for none: 0 is a digit and nets false, so () could not say it
   (hexv c) (? (48 <= c <= 57) (c - 48) (97 <= c <= 102) (c - 87) (65 <= c <= 70) (c - 55) -1)
   ; all-digits text as its number, () for anything else ("" and "abc" included)
   (unum s) (: n #s
               (go i a) (? (n <= i) a (48 <= s i < 58) (go (i + 1) (a * 10 + (s i - 48))) ())
               (string? s && n ? (go 0 0) ()))
   ; a port's text as its number, () for anything outside 1..65535
   (uport s) (unum s @ n (charm? n && 0 < n < 65536 ? n ()))
   ; a duration text -> milliseconds | (): N or N.N, an optional s/m/h/d suffix
   ; (seconds the default). 0 is a real duration -- callers test charm?, not truth
   (udur s0)
    (: n0 #s0
       lc (0 < n0 ? (s0 (n0 - 1)) ())
       sfx (lc = 115 || lc = 109 || lc = 104 || lc = 100)
       mul (? (lc = 109) 60000 (lc = 104) 3600000 (lc = 100) 86400000 1000)
       s (sfx ? (snip s0 0 (n0 - 1)) s0)
       n #s
       (ip i acc) (i < n && digit? (s i) ? (ip (i + 1) (10 * acc + (s i - 48))) [acc i])
       r (ip 0 0)
       whole <r i <>r
       (? (i = n && 0 < n) (whole * mul)
          (i < n && (s i = 46))
           (: (fp j acc sc) (j < n && digit? (s j) ?
                               (fp (j + 1) (10 * acc + (s j - 48)) (sc * 10))
                               [acc sc j])
              fr (fp (i + 1) 0 1)
              (<>>fr = n && (0 < i || i + 1 < n) ?
                 (whole * mul + (<fr * mul) // <>fr)
                 ()))
          ()))
   ; lowercase digits past 9. putbn reads a charm only; a big goes by halves
   (radix n b)
    (? (charm? n) (jug 0 @ o (putbn o n b, slurp o))
       (n < 0) ("-" + radix (0 - n) b)
       (bigdigits n b))
   (zpad w s) (#s < w ? (zpad w ("0" + s)) s)
   (aup n a) (n + a - 1 & -a)                   ; n up to a multiple of a, a power of two
   ; a code point as its utf-8 bytes, "" outside unicode. `string` on a number is one byte
   (utf8 v)
    (? (v < 0) ""
       (v < 128) (string v)
       (v < 2048) (string (192 + v // 64) + string (128 + v % 64))
       (v < 65536) (string (224 + v // 4096) + string (128 + v // 64 % 64) + string (128 + v % 64))
       (v < 1114112) (string (240 + v // 262144) + string (128 + v // 4096 % 64)
                      + string (128 + v // 64 % 64) + string (128 + v % 64))
       "")
   (lstrip s) (: (go i) (i < #s && ws? (s i) ? (go (i + 1)) i) (snip s (go 0) #s))
   (rstrip s) (: (go j) (0 < j && ws? (s (j - 1)) ? (go (j - 1)) j) (snip s 0 (go #s)))
   (strip s)  (lstrip (rstrip s))       ; not `trim`: that name is a port op
   (lines s) (split "\n" (#s && s (#s - 1) = 10 ? (snip s 0 (#s - 1)) s))
   (unlines ls) (: o (jug 0) (go m) (two? m ? (say o <m, put o 10, go >m) (slurp o)) (go ls))   ; each line ends in \n
   (words s) (: (go i st acc)                           ; whitespace runs, so no empty pieces
                 (: shut (st < i ? (snip s st i . acc) acc)
                    (? (i >= #s) (rev shut)
                       (ws? (s i)) (go (i + 1) (i + 1) shut)
                       (go (i + 1) st acc)))
                (go 0 0 ()))
   (upper s) (string (map (c \ 97 <= c <= 122 ? (c - 32) c) (chars s)))
   (lower s) (string (map (c \ 65 <= c <= 90 ? (c + 32) c) (chars s)))
   (padl s n) (#s >= n ? s (padl (" " + s) n))
   (padr s n) (#s >= n ? s (padr (s + " ") n))
   (uniq l)  (: (go seen l) (? (atom? l) () (peep seen <l 0) (go seen >l)
                              (<l . go (pin seen <l 1) >l))
                (go {} l))
   (count p l) (foldl (\ a x (p x ? (a + 1) a)) 0 l))

; --- assert / suite: strict checkers; a failure scares ---
(:: 'assert (l \ (. 'do (map (e \ ['? e 0 ['scare ['\ 'assert] ['\ e]]]) l))))

(:: 'suite (l \ (. 'do (. (. 'assert >l) [['puts <l] ['puts ": ok\n"]]))))

(: (array s) (a-shape s @ sh (a-coll sh (foldl (*) 1 sh) 0)))

; --- coin: a user kind, a table of methods keyed by the noms the C side reads:
; name + * ap hot - net star /, net one of payload tally ratio. (coin 'nm spec) registers
; it and answers its constructor; spec is a tablet, or (z \ {'+ ..}) of the constructor.
; a method takes both operands raw; (lift z f) lowers them and re-strikes.
; (kinds ()) lists names in registration order, (kinds 'nm) answers the table.
(: (coin nm spec)
    (: t {'name nm} z (strike t)
       s (tablet? spec ? spec (!spec ? () (spec z)))
       _ (tablet? s ? (foldl (\ t k (pin t k (s k))) t (keys s)) 0)
       r (kreg 0) e (r nm)
       (pin r nm ((two? e ? <e #(keys r)) . t),   ; a re-registration keeps its serial
        z))
   (kinds k) (name? k ? (kreg 0 k @ e (two? e ? >e))
                        (kreg 0 @ r (map (p \ <>p) (sort (map (n \ [<(r n) n]) (keys r))))))
   (lift z f) (\ a b (z (f (load a) (load b)))))

;;; FIXME help/io setters below here. redesign the API with more structure
; binary?: may f take two operands? an n-ary closure by its arity, any other lambda takes one;
; a nif or partial passes. the markers are read off known values.
(: hcur (pick 0 (\ a b a)) hunc (pick 0 (+ 1))
   (binary? f) (? (charm? f) 0                      ; a charm is no handler at all
                  (hcur == pick 0 f) (2 = peek 1 f)
                  (hunc == pick 0 f || string? (nifnom f)) 1
                  !(lit? f && !(tablet? f) && !(hot? f)))
   (hear f) (? !f (seal-hook -1 ())                  ; every nothing uninstalls
               (binary? f) (seal-hook -1 f)
               (scare 'help-arity f)))

; (wear (i o e)) sets in/out/err for this task
(: (wear l) (seal-hook -2 l))

; trap -- (f x), or (n a b) when a scare lands. pass all three: with two, f never runs and
; the closure answered is truthy. nothing unwinds, so a cleanup belongs in n or `mind`'s c.
(: (trap f x n)
     (: _ (binary? n ? 0 (scare 'help-arity n))   ; refuse before f runs, under the ambient help
        prev (heard ())
        home (myself ())
        r (call-cc (k \ (: _ (hear (\ a b (myself () == home ? (k (_ \ (n a b)))
                                             (hear prev, scare a b))))
                           v (f x)
                           (_ \ v))))
        (hear prev,
         r ())))

; mind -- (f x), with (c ()) run exactly once on the way out, clean or raised; a raise rides
; on outward. n answers a privately marked condition rather than re-raising in place, which
; could fire c twice. a (k v) to an outer continuation skips c. a raise inside c replaces
; the one it was firing for.
(: mind (mint 0 @ mark
           (\ f x c
              (trap f x (\ a b (mark . [a b])) @ r
                 (c (),
                  two? r && == <r mark ? (scare <>r <>>r) r)))))

; the ISA vocabulary, one word per machine. every outside spelling (a -t flag, uname, a gnu
; triple's head) goes through `archof` once.
(: arch-canon {'x64 'x64  'amd64 'x64  'x86_64 'x64  'x86-64 'x64
               'a64 'a64  'arm64 'a64  'aarch64 'a64
               'rv64 'rv64  'riscv 'rv64  'riscv64 'rv64
               'wasm 'wasm  'wasm64 'wasm
               'thumb1 'thumb1  'cortex-m0 'thumb1
               'thumb2 'thumb2  'cortex-m7 'thumb2
               'arm 'arm  'armv7l 'arm  'armv8l 'arm  'armhf 'arm
               'thumb2sp 'thumb2sp  'playdate 'thumb2sp
               'i386 'i386  'i686 'i386  'ia32 'i386  'x86 'i386
               'i386m16 'i386m16}
   ; uname's machine and a gnu triple's head; () for the embedded targets
   arch-uname {'x64 "x86_64" 'a64 "aarch64" 'rv64 "riscv64" 'arm "armv7l"}
   ; main.c pins `love-os` per run off __love_osv: one binary meets four kernels
   os-uname {'linux "Linux" 'freebsd "FreeBSD" 'netbsd "NetBSD" 'macos "Darwin" 'inle "Inle"}
   ; a nom or string -> the canonical nom, () for an unknown one
   archof (arch-canon * name)
   ; total: an unknown spelling passes through as its nom, for the refuser to name
   (arch-nom s) (: s (name s) (peep arch-canon s s))
   arch-mach arch-uname)

(: car cap cdr cup cons .
   caar caap cadr caup cdar cuap cddr cuup
   caaar caaap caadr caaup cadar cauap caddr cauup
   cdaar cuaap cdadr cuaup cddar cuuap cdddr cuuup
   eq? == length tally pair? two? atom atom? identity id
   reverse rev append + constantly const ceiling ceil
   fold-left foldl fold-right foldr append-map catmap flat-map catmap
   every all some any delete-duplicates uniq butlast init
   (for-each f l) (each l f)                     ; scheme takes the function first
   ; scheme's: the tail found, () for a miss; memq by identity
   (memq x l)   (two? l ? (x == cap l ? l (memq x >l)))
   (member x l) (two? l ? (x = cap l ? l (member x >l))))

; lamform -- a function read back off its thread into a source form for an `=` function, or 0
; for a thread ev did not write (a nif's body, a continuation). a symbolic run of thrun: each
; pushed value is a mint whose node says how it was made; the nodes render as source.
(: lamthr (:
   cur (pick 0 (+)) ret0 (pick 1 cap) unc (pick 0 (+ 1)) uncn lvm_uncn gcache {}
   ; what thrun reads: a nif -> its name, then the node tags and the fused loads' names
   thcfg [(foldl (\ t v (nifnom v @ nm (string? nm ? (pin t v (name nm)) t)))
                 {} (catmap (l \ (map l (keys l))) (stack ())))
          'k 'a 'o 'c 'g 'cap 'cup 'two?]
   ; ..and a nif's name -> the nif, to name one moved off the book by its module
   nval (foldl (\ t v (nifnom v @ nm (string? nm ? (pin t (name nm) v) t)))
               {} (catmap (l \ (map l (keys l))) (stack ())))
   (onm n) (peep nval n () @ v (!v ? n (nifn v n)))
   ; a nif by its own name while the book binds it, else by what does: another name, a cite
   (nifn v n) (any (l \ (peep l n () !== ())) (stack ()) ? n (glob v @ g (g !== () ? g n)))
   (tk n l) (0 < n ? (<l . tk (n - 1) >l) ())
   (dp n l) (0 < n ? (dp (n - 1) >l) l)
   (unw v) (nat? v ? (unw (cur == pick 0 v ? (peek 3 v) (peek 1 v))) v)   ; a native is its twin
   (fn? v) (lit? v && !(tablet? v) && !(hot? v))
   (arity e) (cur == pick 0 e ? (peek 1 e) 1)
   (entry e) (cur == pick 0 e ? (seek 2 e) e)
   (uncp o) (o == unc || o == uncn)
   (partp v) (uncp (pick 0 v) || cur == pick 0 v && uncp (pick 2 v))
   (unc0 v) (cur == pick 0 v ? (seek 2 v) v)
   (ulink u) (unc == pick 0 u ? (peek 2 u) (peek (2 + peek 1 u) u))
   (uargs u) (unc == pick 0 u ? [(peek 1 u)] (map (i \ peek (2 + i) u) ^(peek 1 u)))
   (pargs v) (: (go u a) (ulink u @ l (uncp (pick 0 l) ? (go l (uargs u + a)) (uargs u + a))) (go (unc0 v) ()))
   (fbase v) (: (go u) (ulink u @ l (uncp (pick 0 l) ? (go l) (seek -2 l))) (go (unc0 v)))
   ; a row's value is a binding power, negative as often as not: ask for presence
   (infix? x) (name? x ? (any (k \ (k != 0 && peep (operators k) x () !== ())) (keys operators)))

   ; C is one reading's state: D a slot's node, B the let names in scope, R a let-bound
   ; closure's (name captures), memo a lambda read -> its name, F a name's form, want a name
   ; recursion asked for, sites how many places quote a lambda, n the bodies read. past lim
   ; bodies, a named function answers its name, else it is read again naming shared lambdas
   (lamform v) (: nm (nifnom v)
                  (go S) (: r (call-cc (k \ (: C {'k k 'D {} 'B {} 'R {} 'busy () 'memo {} 'F {} 'want {} 'pre {} 'obj {} 'objs () 'letE {} 'sites (S ? S {}) 'n 0}
                                            (rename (cites (tie C (partp v ? (rfn C (fbase v) . map (rka C) (pargs v)) (rlam C (unw v)))))))))
                          (? (r !== 'big) r (tablet? S || !== (glob v) ()) 0 (go (sites v))))
                  r (string? nm ? (nifn v (name nm)) (go 0))
                 (r == 0 ? (glob v @ g (g !== () ? g 0)) r))
   lim 20000
   (fail C) (C 'k 0)
   ; the run from p over the frame's slots S0: its node, each slot it made pinned in D
   (run C p S0) (thrun p S0 0 thcfg @ t
                   (t == 0 ? (fail C) (each >t (q \ (pin (C 'D) <q >q))),
                    <t))
   ; a lambda quoted in one place reads back in place; one quoted in more is named, or a
   ; graph of them reads as a tree. sites: how many places quote each lambda v reaches
   (sites v) (: T {} seen {}
    (see me v) (charm? v || == v () || mint? v || nom? v || two? v || !(fn? v) || !== (glob v) () ? 0
                  (unw v @ u
                     (? (partp u) (part me u)
                        (string? (nifnom u) || opnom u || !== (glob u) ()) 0
                        (u == me ? 0 (pin T u (1 + peep T u 0)), walk u))))
    (part me u) (see me (fbase u), each (pargs u) (see me))
    (walk u) (peep seen u 0 ? 0
                (: _ (pin seen u 1)
                   t (thrun (entry u) (map (_ \ (mint 0)) ^(arity u)) 0 thcfg)
                   (wn x) (two? x ? (? (<x == 'k) (see u (x 1)) (name? <x) (each >x wn) (each x wn)) 0)
                 (t == 0 ? 0 (wn <t, each >t (q \ (wn >q))))))
    (partp v ? (part 0 v) (walk (unw v)),
     T))
   (one C v) (peep (C 'sites) v 0 < 2)

   ; --- rendering: a node to a source form, the binders still mints
   (res C x) (mint? x ? (: b (peep (C 'B) x 0) d (peep (C 'D) x C)
                         (b || == d C ? x (res C d)))
                x)
   (var? C x) (mint? (res C x))
   (rv C x) (res C x @ y
               (mint? y ? y
                  (y @ ('k v) (rk C v)
                       ('g n) n
                       ('o n as) (onm n . map (ra C) as)
                       ('c . J . cl) (cone ('? . rcl C J cl))
                       ('a . _) (rapp C y)
                       (fail C))))
   ; the same captures: a name bound to a slot is that slot, whether or not the name holds
   (sees C x) (: d (mint? x ? (peep (C 'D) x C) C) (d == C ? x (sees C d)))
   (alleq C xs ys) (two? ys ? (== (sees C <xs) (sees C <ys) && alleq C >xs >ys) 1)
   ; an operator away from the head is parenthesised, or it reads as infix
   (ra C x) (rv C x @ r (infix? r ? [r] r))
   ; a let whose last init is a cond tail-applies its body from each arm, so the arms read as
   ; the same let, each its own binders, but that init: one let again, the cond its init. the
   ; let may close a chain of more clauses, so its run of arms is the chain's tail
   (cone f) (cmerge >f @ r (atom? >r ? <r ('? . r)))
   (cmerge c) (atom? >c ? c (clet c @ m (two? m ? [m] (<c . <>c . cmerge >>c))))
   (clet c) (: as (arms c) a <as n #a
              (sk b) (tk (n - 2) b + [(last b)])
              (? (atom? a || <a != ': || n < 4) 0
                 (: ms (map (b \ two? b && #b = n && <b == ': ? (: M {} N {} (aeq (sk a) (sk b) M N ? N 0)) 0) >as)
                    (any (m \ m == 0) ms ? 0 (tk (n - 2) a + [('? . cinit c (0 . ms)) (last a)])))))
   (arms c) (atom? >c ? c (<>c . arms >>c))                     ; the results, the else last
   (cinit c rs) (: (li b) (rn <rs (b (#b - 2)))
                  (atom? >c ? [(li <c)] (<c . li <>c . cinit >>c >rs)))
   ; x and y alike but for their mints, which pair one to one: M x's to y's, N back
   (aeq x y M N) (? (mint? x) (mint? y && (peep M x () @ p (peep N y () @ q
                                 (p !== () || q !== () ? (p == y && q == x) (pin M x y, pin N y x, 1)))))
                    (two? x) (two? y && aeq <x <y M N && aeq >x >y M N)
                    (x = y))
   (rn N x) (? (N == 0) x (mint? x) (peep N x () @ y (y !== () ? y x)) (two? x) (rn N <x . rn N >x) x)
   ; a cond whose else is a cond of the same join is one cond of more clauses
   (rcl C J cl) (: t <cl a <>cl e <>>cl y (res C e)
    (rv C t . rv C a . (two? y && <y = 'c && y 1 == J ? (rcl C J >>y) [(rv C e)])))
   ; the application spine: the head, then each apply's group, outermost last
   (spine C x gs) (res C x @ y (two? y && <y = 'a ? (spine C (y 1) ((y 2) . gs)) (y . gs)))
   ; a lambda to read back: no name of its own, not a partial, not being read already
   (lam C h) (two? h && <h = 'k ?
               (unw (h 1) @ v (fn? v && !(partp v) && fname C v == 0 && !(busy? C v) && one C v ? v)))
   (nlet C h) (two? h && <h = 'k ? (named C (unw (h 1))))
   ; a lambda head: fewer args than params are its captures, a closure; the group that
   ; saturates it is a let's inits, the groups before it its captures
   (rapp C x) (: sp (spine C x ()) h <sp gs >sp E (lam C h) as (catmap id gs) nl (nlet C h)
    (? (two? nl) (: ic <>nl ni #ic
                  (ni <= #as && alleq C as ic ?
                     (ni < #as ? (<nl . map (ra C) (dp ni as)) <nl)
                     (flat C h as)))
       E (: n (arity E) m #as
          (m < n ? (all (var? C) as ? (rclo C E (map (res C) as)) (flat C h as))
             (: (cut gs acc k) (two? gs ? (acc + #<gs @ a (? (a = n) k (a < n) (cut >gs a (1 + k)) -1)) -1)
                k (cut gs 0 0) imps (catmap id (tk k gs)) la (0 <= k ? (gs k)) rest (catmap id (dp (1 + k) gs))
              (0 <= k && all (var? C) imps ?
                 (rlet C E (map (res C) imps) la @ lt (two? rest ? (lt . map (ra C) rest) lt))
                 (flat C h as)))))
       (self C h as @ s (two? s ? <s (flat C h as)))))
   ; a closure calling itself from inside its own reading passes its captures along first:
   ; its name stands for the closure, captures and all
   (self C h as) (two? h && <h = 'k ?
                   (: u (unw (h 1)) p (peep (C 'pre) u ())
                    (two? p && busy? C u && #p <= #as && alleq C as p ?
                       (want C u @ n
                          (? (peep (C 'letE) u 0) [(n . map (ra C) as)]   ; a let's lambda is bound bare: every arg
                             (#p < #as) [(n . map (ra C) (dp #p as))] [n])))))
   (flat C h as) (rv C h . map (ra C) as)
   ; a let's names are the slots its inits sit in; a closure init names its thread, so a
   ; reference back to it reads as the name. the names hold inside the let alone. a lambda
   ; that recursed is no let: it binds its name, (: n (\ ..) n), taking captures and inits as args
   (rlet C E imps la) (: B (C 'B) R (C 'R)
    rs (catmap (s \ (clo C (res C (peep (C 'D) s ())) @ cl (cl ? [[<cl (R <cl) s >cl]]))) la)
    _ (each rs (r \ (pin R <r [(r 2) (r 3)])))
    _ (each la (s \ (pin B s 1)))
    b (rbody C E (imps + la))
    n (peep (C 'want) E 0)
    f (mint? n ? 0 (': . catmap (s \ [s (rinit C s)]) (rev la) + [<>b]))
    (each la (s \ (pin B s 0)),
     each rs (r \ (pin R <r (r 1))),
     mint? n ? ([': n ('\ . imps + la + <b + [<>b]) n] . imps + map (rinit C) la) f))
   (rinit C s) (: d (res C (peep (C 'D) s ())) cl (clo C d)
    (cl ? (unself s (eta (rclo C <cl >cl))) (rv C d)))
   ; a named closure over captures, ((: n (\ caps.. ps.. body) n) caps..), is a lambda over
   ; its ps, as a let's sibling must be to see the siblings after it
   (eta y) (<y @ h
              (two? h && == <h ': && 4 = #h && two? (h 2) && == <(h 2) '\ ?
                 (: m (#(h 2) - 2 - #>y) ps (map (_ \ (mint 0)) ^m)
                  (0 < m ? ('\ . ps + [(y + ps)]) y))
                 y))
   ; a closure bound by name that names itself, (: n (\ ..) n), is its lambda under that
   ; name: a value would see only the siblings bound before it
   (unself m y) (two? y && == <y ': && 4 = #y && mint? (y 1) && == (y 1) (y 3) ? (sub (y 1) m (y 2)) y)
   (sub a b x) (? (x == a) b (atom? x || qot? x) x (map (e \ (sub a b e)) x))
   ; a closure node: (lambda . capture vars), or ()
   (clo C d) (? (two? d && <d = 'k) (unw (d 1) @ v (fn? v && !(partp v) && !(nifnom v) && one C v ? [v]))
                (two? d && <d = 'a)
                (: sp (spine C d ()) h <sp as (catmap id >sp) E (two? h && <h = 'k ? (unw (h 1)))
                 (E && fn? E && !(partp E) && !(nifnom E) && one C E && #as < arity E && all (var? C) as ?
                    (E . map (res C) as))))
   (named C v) (peep (C 'R) v ())
   ; with captures, a lambda's own name is the bare lambda (an inner call may pass other
   ; captures), so a call through itself passes every arg
   (rbody C E pre) (: bz (C 'busy) le (peep (C 'letE) E 0)
    (inq l) (two? l ? (== E <l || inq >l))
    _ (inq bz ? (fail C))
    _ (pin C 'n (1 + C 'n))
    _ (lim < C 'n ? (C 'k 'big) 0)
    _ (pin C 'busy (E . bz))
    _ (pin (C 'pre) E pre)
    _ (two? pre ? (pin (C 'letE) E 1) 0)
    S0 (: (ps i) (i < arity E ? (i < #pre ? (pre i . ps (1 + i)) (mint 0 . ps (1 + i))) ()) (ps 0))
    b [(dp #pre S0) (rv C (run C (entry E) S0))]
    (pin (C 'letE) E le,
     pin C 'busy bz,
     b))
   ; a body that is a lambda goes in a singleton: bare, the reader would merge its params.
   ; one reached from inside its own reading takes a name, (: n (\ ..) n); with captures the
   ; name binds the bare lambda, applied to them
   (rclo C E pre) (: b (rbody C E pre) y <>b
                   yb (two? y && == <y '\ && two? >>y ? [y] y)
                   f ('\ . <b + [yb])
                   n (peep (C 'want) E 0)
                   (? !(mint? n) f
                      (two? pre) ([': n ('\ . pre + <b + [yb]) n] . pre)
                      [': n f n]))
   (want C u) (: W (C 'want) n (peep W u 0) (mint? n ? n (mint 0 @ n (pin W u n, n))))
   (rk C v) (? (charm? v) v
               (v == ()) ()
               ; a sentinel: the name that holds it, else one fresh mint said by one name
               (mint? v) (glob v @ g (g !== () ? g (obj C v ['mint 0])))
               (nom? v || two? v) ['\ v]
               (fn? v) (rfn C v)
               ; a carrier is `=` only to itself: a tablet too big to walk shows as its size
               (tablet? v || hot? v) (glob v @ g (? (g !== ()) g (tablet? v && (16 < #v || wee 64 v < 0)) (name ("{.." + dec #v + "}")) v))
               v)
   ; a partial's argument: an operator by value is parenthesised, or it reads as infix
   (rka C v) (rk C v @ r (infix? r ? [r] r))
   ; what is left of n once v is walked, negative past it: a cycle ends there too
   (wee n v) (? (n < 0) n
                (tablet? v) (n < #v ? -1 (foldl (\ m k (wee (wee (m - 1) k) (v k))) n (keys v)))
                (two? v) (wee (wee (n - 1) <v) >v)
                (n - 1))
   ; an object only itself is `=` to, named once and bound over the whole to a fresh one
   (obj C v init) (peep (C 'obj) v 0 @ n
                     (mint? n ? n (mint 0 @ n (pin (C 'obj) v n, pin C 'objs ([n init] . C 'objs), n))))
   (dec n) (n < 10 ? (string (48 + n)) (dec (n // 10) + string (48 + n % 10)))   ; show is later
   ; a function's own name: a nif's, a glued sigil's, a let's, a global's; 0 for none (a
   ; let's name is a mint, and a mint is falsy)
   (fname C v) (nifnom v @ nm
                  (string? nm ? (nifn v (name nm))
                     (: gn (opnom v) u (unw v) r (named C u)
                      (? gn gn
                         (two? r ? (atom? <>r)) <r                  ; a let's name, when it holds no captures
                         (glob v @ g (g !== () ? g (glob u @ g (g !== () ? g 0))))))))
   (rfn C v) (fname C v @ nm
                (? (nm !== 0) nm
                   (partp v) (rfn C (fbase v) . map (rka C) (pargs v))
                   (rlam C (unw v))))
   ; a lambda constant is read once and stands as a name for its form
   (rlam C u) (peep (C 'memo) u 0 @ n
                 (? (mint? n) n (busy? C u) (want C u)
                    (mint 0 @ n (pin (C 'memo) u n, pin (C 'F) n (rclo C u ()), n))))
   ; a name met from one place is its form in place, (: n (\ ..) n) when it recurs; one met
   ; from more is bound once in a letrec over the whole. `on` holds the names being walked.
   ; a name in place but met again from a helper joins the helpers, and the form is laid again
   (tie C x) (: F (C 'F) out {} own {} seen {} O {'l ()}
    ON (foldl (\ t p (pin t <p 1)) {} (C 'objs))      ; rk's objects, bound first over the whole
    ob (catmap id (rev (C 'objs)))
    (inq x l) (two? l ? (== x <l || inq x >l))
    (cw x on) (? (mint? x) (inq x on ? (pin own x 1) (pin out x (1 + peep out x 0)),
                            two? (peep F x ()) && !(peep seen x 0) ?
                              (pin seen x 1, pin O 'l (x . O 'l), cw (F x) (x . on)) 0)
                 (atom? x || qot? x) 0
                 (each x (e \ (cw e on))))
    _ (cw x ())
    ; a form that says a let's names goes in place, never over the whole
    (fvs y) (: A {'l ()}
             (fw x sc) (? (mint? x) (!(two? (peep F x ())) && !(peep ON x 0) && !(inq x sc) ? (pin A 'l (x . A 'l)) 0)
                          (atom? x || qot? x) 0
                          (<x == ':) (lets >x + sc @ sc2 (each >x (e \ (fw e sc2))))
                          (<x == '\) (init >x + sc @ sc2 (each >x (e \ (fw e sc2))))
                          (each x (e \ (fw e sc))))
             (fw y (),
              A 'l))
    (nms y) (? (mint? y) (two? (F y) ? [y]) (atom? y || qot? y) () (catmap nms y))
    ; ..and so is a form that holds one
    (spread t) (: n (foldl (\ n m (!(peep t m 0) && any (k \ (peep t k 0)) (nms (F m)) ? (pin t m 1, (1 + n)) n)) 0 (O 'l))
                (0 < n ? (spread t) t))
    loc (spread (foldl (\ t m (two? (fvs (F m)) ? (pin t m 1) t)) {} (O 'l)))
    (ex H x on) (? (mint? x) (inq x on || atom? (F x) || peep H x 0 ? x
                                (ex H (F x) (x . on) @ f (peep own x 0 ? [': x f x] f)))
                   (atom? x || qot? x) x
                   (map (e \ (ex H e on)) x @ y (<y == '\ ? (sole y) y)))
    ; a lambda in place as a lambda's body sits in a singleton, as rclo leaves one
    (sole y) (last y @ b (two? b && == <b '\ && two? >>b ? (init y + [[b]]) y))
    (lay H) (filter (m \ (peep H m 0)) (rev (O 'l)) @ hs
               (two? hs || two? ob ? (': . ob + catmap (m \ [m (unself m (ex H (F m) [m]))]) hs + [(ex H x ())]) (ex H x ())))
    ; the names met where no (: ..) around them binds them
    (free y) (: A {'l ()}
              (fw x sc) (? (mint? x) (two? (F x) && !(inq x sc) ? (pin A 'l (x . A 'l)) 0)
                           (atom? x || qot? x) 0
                           (<x == ':) (lets >x + sc @ sc2 (each >x (e \ (fw e sc2))))
                           (each x (e \ (fw e sc))))
              (fw y (),
               A 'l))
    (fix H) (: y (lay H) fs (filter (\ m !(peep loc m 0) && !(peep H m 0)) (free y))
             (two? fs ? (fix (foldl (\ H m (pin H m 1)) H fs)) y))
    (fix (foldl (\ H m (1 < peep out m 0 && !(peep loc m 0) ? (pin H m 1) H)) {} (O 'l))))
   ; by `=`: an older compile of the same function is the same function
   (busy? C u) (: (go l) (two? l ? (u = <l || go >l)) (go (C 'busy)))
   ; a value's global or module name, shortest spelling first, then least; () for none. the
   ; table is cached and rebuilt when a layer or module gains or loses a name; a hit by `=`
   ; must still hold its binding. a module name, (cite 'm 'n), names only the bound value
   ; itself, never a lambda merely `=` to it
   (glob v) (tablet? v || hot? v ? (gcar v)
             (peep (gtab 0) v () @ e
                (? !e ()
                   (<>e <e == e 2) (held? v e ? (spell e) ())
                   (peep (gtab 1) v () @ e (two? e && held? v e ? (spell e))))))
   (held? v e) (!(e 3) || v == e 2 || v == unw (e 2))        ; a book name, or the bound value itself or its twin
   (spell e) (e 3 ? ['cite ['\ (e 3)] ['\ <e]] <e)
   ; a carrier is found by `==` down a list: its hash moves as it is written. book names first
   (gcar v) (cbest v (gtab 0, gcache 'c) @ e
               (? !e ()
                  (<>e <e == v) (spell e)
                  (cbest v (gtab 1, gcache 'c) @ e (two? e ? (spell e)))))
   (cbest v l) (foldl (\ b e (? (!(e 2 == v)) b
                                 !b e
                                 (!(e 3) && b 3) e
                                 (!(b 3) && e 3) b
                                 (better <e <b) e
                                 b)) () l)
   (better a b) (: x (string a) y (string b) (? (#x < #y) 1 (#x = #y) (x < y) 0))
   ; the book's count and the modules' apart, so a name moving between them changes it
   (gsig L) [(foldl (\ n l (n + #l)) 0 (stack ()))
             (foldl (\ n k (L k @ l (n + 1 + (tablet? l ? #l 0)))) 0 (keys L))]
   (gtab force) (: L (lib ()) s (gsig L)
    ((force ? 0 (s = peep gcache 's -1)) ? (gcache 't)
       (: t {} m {} seen {} cs {'l ()}
          (put t v k l n) (peep t v () @ old ((!old ? 1 (better k <old)) ? (pin t v [k l (l k) n]) 0))
          ; a native is keyed by its bytecode too: a thread quotes whichever the compiler held
          (add t n l k) (l k @ v
                           (? !(name? k) 0
                              (tablet? v || hot? v) (pin cs 'l ([k l v n] . cs 'l))
                              (fn? v || mint? v || string? (nifnom v))
                              (put t v k l n, fn? v ? (put t (unw v) k l n) 0)
                              0))
          (each (stack ()) (l \ (each (keys l) (k \ (peep seen k 0 ? 0 (pin seen k 1, add t 0 l k))))),
          ; a module's names fill in where the book has none
           each (keys L) (n \ (L n @ l (tablet? l ? (each (keys l) (add m n l)) 0))),
           each (keys m) (v \ (!(peep t v ()) ? (pin t v (m v)) 0)),
           pins gcache 's s 't t 'c (cs 'l),
           t))))
   ; --- naming: a binder is a letter by depth, a b .. z aa ab .., skipping names free in the form
   (sxch n a) (: q ((n - 1) // 26) c (97 + (n - 1) % 26)
               (0 < q ? (sxch q (c . a)) (c . a)))
   (lnom i) (name (string (sxch (1 + i) ())))
   (nxt i fv) (peep fv (lnom i) 0 ? (nxt (1 + i) fv) i)
   (qot? x) (two? x && == <x '\ && two? >x && atom? >>x)
   (fvn x t) (? (name? x) (pin t x 1) (atom? x || qot? x) t (foldl (\ t e (fvn e t)) t x))
   (asg bs i m fv) (two? bs ? (nxt i fv @ j (asg >bs (1 + j) ((<bs . lnom j) . m) fv)) (i . m))
   (lets l) (two? >l ? (<l . lets >>l))
   (ren x i m fv) (? (mint? x) (assq x m @ p (two? p ? >p x))
                     (atom? x || qot? x) x
                     (<x == '\) (asg (init >x) i m fv @ a
                                   ('\ . map (e \ (ren e <a >a fv)) >x))
                     (<x == ':) (asg (lets >x) i m fv @ a
                                   (': . map (e \ (ren e <a >a fv)) >x))
                     (map (e \ (ren e i m fv)) x))
   (rename f) (ren f 0 () (fvn f {}))
   ; a (cite 'module 'name) met more than once is bound once over the whole, by its own
   ; name unless the form spells it elsewhere, else by a letter
   (cites y) (: T {} O {'l ()}
    (cite? x) (two? x && == <x 'cite && 3 = #x)
    (cc x) (? (atom? x || qot? x) 0
              (cite? x) (peep T x 0 @ c (c = 0 ? (pin O 'l (x . O 'l)) 0, pin T x (1 + c)))
              (each x cc))
    _ (cc y)
    fv (fvn y {})
    bs (filter (c \ (1 < T c)) (rev (O 'l)))
    N (foldl (\ t c (c 2 1 @ k (pin t c (peep fv k 0 ? (mint 0) k)))) {} bs)
    (rp x) (? (atom? x || qot? x) x (cite? x) (peep N x () @ b (!b ? x b)) (map rp x))
    (two? bs ? (: z (rp y) ds (catmap (c \ [(N c) c]) bs)
                (<z == ': ? (': . ds + >z) (': . ds + [z])))
       y))
   ; threadir -- for a compiler: a function as [arity node], the node one of ['p i] the ith
   ; param, ['k v] a quote, ['o name args] a book op, ['a f args] an apply, ['c t then else]
   ; a cond, ['g n] a slot. 0 for a nif, a non-function or an unreadable thread. a slot read
   ; twice is its node twice. ops is 0 for any thread, or the op names the caller can use
   (threadir v ops) (unw v @ e
                       (!(fn? e) || string? (nifnom e) ? 0
                          (: S0 (map (_ \ (mint 0)) ^(arity e))
                             t (thrun (entry e) S0 ops thcfg)
                             (t == 0 ? 0 [#S0 (tnode (foldl (\ D q (pin D <q >q)) {} >t) S0 <t)]))))
   (tnode D ps x) (: (ix m l i) (two? l ? (m == <l ? i (ix m >l (1 + i))) -1)
                     (go x) (mint? x ? (peep D x D @ d (d == D ? ['p (ix x ps 0)] (go d)))
                               (x @ ('k v) x
                                    ('g n) x
                                    ('o n as) ['o n (map go as)]
                                    ('a f as) ['a (go f) (map go as)]
                                    ('c _ t a b) ['c (go t) (go a) (go b)]
                                    ['x]))
                     (go x))
   [lamform threadir]))
(: lamform (lamthr 0)  threadir (lamthr 1))

(: px (:
  ; every eager binding sits in this outer `:`. where boxfix engages (any forward
  ; or self reference -- the printer below is one), a sibling bound to an unfoldable
  ; call is boxed too and its cell never filled, so every read of it raises `missing`:
  ;   (: f (: (a o) (f o) c (tablet 0) (\ o c)))   -> ;; missing c
  cur (pick 0 (+)) ret0 (pick 1 cap) unc (pick 0 (+ 1)) uncn lvm_uncn
  ; the float width is the seat's, never this file's: a 32-bit seat gets binary32 for
  ; flo_t. so ask the arithmetic -- a hard-coded 2^53 sends norm's doubling loop past
  ; every float32 there is and it never returns.
  p53 (: (go m) (m = 1.0 + m ? m (go (m * 2.0))) (go 1.0))   ; where +1 is lost = 2^mantissa
  p52 (p53 / 2.0)
  emin (: (go v e) (v / 2.0 @ h (h = 0 ? e (go h (e - 1)))) (go 1.0 0))   ; the denormal floor
  inf (1.0 / 0.0)
 (:

  ; --- integers: the digits of a non-negative charm/sun/big, most significant first
  (dch n a) (: q (n // 10) d (48 + (n - q * 10)) (0 < q ? (dch q (d . a)) (d . a)))
  (dstr n) (n < (1 << 256) ? (string (dch n ())) (bigdigits n 10))
  (ndig n) (n // 10 @ q (0 < q ? (1 + ndig q) 1))          ; the count, without building the list
  (pnum o n) (n < 0 ? (put o 45, say o (dstr (0 - n))) (say o (dstr n)))

  ; --- text ---
  (hexd d) (d < 10 ? (48 + d) (87 + d))
  (esc o c)
   (c @ (92 || 34) (put o 92, put o c)
        10 (say o "\\n")   9  (say o "\\t")
        13 (say o "\\r")   27 (say o "\\e")
        0  (say o "\\0")
        (c >= 32 ? (put o c)
                   (say o "\\x", put o (hexd (c // 16)),
                    put o (hexd (c - 16 * (c // 16))))))
  (pstr o s) (put o 34, each ^#s (i \ esc o (peep s i 0)), put o 34)

  ; --- gems: the shortest roundtrip, exact steele & white: 4m and the midpoints 4m±2 as
  ; bignums at one scale.
  ; v = m*2^e, m an integer in [p52,p53), but never below the denormal floor
  (norm m e) (? (p53 <= m) (norm (m / 2.0) (1 + e))
                (m < p52 && emin < e) (norm (m * 2.0) (e - 1))
                (int m . e))
  ; inside the rounding interval? a midpoint counts only for an even mantissa (round-half-even)
  (fits c lo hi evn) ((lo < c ? 1 (evn && c = lo)) &&
                      (c < hi ? 1 (evn && c = hi)))
  ; the fewest digits inside: pk is the place cut, down by ten a step, trying truncation and
  ; bump, nearer first. dv itself is inside, so it ends.
  (fewest dv lo hi evn pk) (pk < 1 ? dv
    (: t ((dv // pk) * pk)
       up (1 < pk && 5 <= dv // (pk // 10) - (10 * (dv // pk)))
       c1 (up ? (t + pk) t) c2 (up ? t (t + pk))
       (? (fits c1 lo hi evn) c1 (fits c2 lo hi evn) c2 (fewest dv lo hi evn (pk // 10)))))
  ; strip trailing zeros, keeping one digit
  (strip n) (n // 10 @ q (0 < q && (n - q * 10) = 0 ? (strip q) n))
  (zeros o n) (0 < n ? (put o 48, zeros o (n - 1)) 0)
  (pgem2 o a) (: me (norm a 0) m <me e2 >me sh (e2 - 2)
    up (sh < 0 ? (5 ** -sh) (2 ** sh))   ; one shared scale: 2^sh, or 5^-sh with the point moved
    flo (m = p52 && emin < e2)                ; at a binade floor the gap below is already half
    dv (4 * m * up)
    dlo ((4 * m - (flo ? 1 2)) * up)
    dhi ((4 * m + 2) * up)
    evn (m = 2 * (m // 2))
    dc (fewest dv dlo dhi evn (** 10 (ndig dv - 1)))
    lead (ndig dc)
    ss (dstr (strip dc)) sig #ss
    dxp (lead + (sh < 0 ? sh 0))
    (? (1e16 <= a || a < 1e-4)
       (dxp - 1 @ e
          (put o (peep ss 0 0),
           1 < sig ? (put o 46, say o (snip ss 1 sig)),
           put o 101,
           e < 0 ? (put o 45) 0,
           say o (dstr (e < 0 ? -e e))))
       (0 < dxp)                                  ; 1 <= v < 1e16: the point sits inside or after
       (each ^dxp (i \ put o (i < sig ? (peep ss i 0) 48)), put o 46,
        dxp < sig ? (say o (snip ss dxp sig)) (put o 48))   ; integral: force "X.0", never a fixnum face
       (say o "0.", zeros o (0 - dxp), say o ss)))
  ; -0.0 < 0 is false, so -0.0 is caught by 1/v
  (pgem o v)
     (: _ (v < 0 || (v = 0 && 1.0 / v < 0) ? (put o 45) 0) a (abs v)
        (? (a = inf) (say o "infinity") (a = 0) (say o "0.0") (pgem2 o a)))
  ; (re ~ im) is self-delimiting, so it reads back anywhere
  (ptwin o x) (put o 40, pgem o (re x), say o " ~ ", pgem o (im x), put o 41)

  ; --- chains. a one-operand `\` is quote; `(mono (run datum))` is a glued monadic, printed
  ; glued back. an improper chain prints all-dot, (1 . 2 . 3), since (1 2 . 3) reads as
  ; (2 . 3). only () ends a list: a tail of 0 or "" is a tail
  (plist o x sn) (: (tl l) (two? l ? (tl >l) l)
                    dot (tl x == () ? 0 1)
                    (go l) (px o <l sn,
                            (? (two? >l) ((dot ? (say o " . ") (put o 32)), go >l)
                               (>l == ()) 0
                               (say o " . ", px o >l sn)))
                    (put o 40, go x, put o 41))
  (pchain o x sn) (: h <x t >x one (two? t && atom? >t)
    (? (h == '\ && one) (put o 39, px o <t sn)
       (h == 'mono && one && (<t @ m (two? m && two? >m && atom? >>m)))
         (<t @ m (px o <m sn, px o <>m sn))
       (plist o x sn)))

  ; --- trays. rank 1 is @(…), past that (array '(shape) elem…). an object tray quotes
  ; what would otherwise re-evaluate.
  ; a flat index to its row-major coordinate
  (coord sh i) (atom? >sh ? (i . ())
                  (: r (foldl (*) 1 >sh) q (i // r) (q . coord >sh (i - q * r))))
  (ptray o v sn) (: ty (atype v) sh (shape v) n (foldl (*) 1 sh)
    (pel i) (peep v (coord sh i) 0 @ e
               (ty = 3 && (nom? e || two? e) ? (put o 39) 0, px o e sn))
    (gs l f) (two? l ? ((f ? 0 (put o 32)), pnum o <l, gs >l 0) 0)
    (rank v = 1 ? (say o "@(", each ^n (i \ ((0 < i ? (put o 32) 0), pel i)), put o 41)
       (say o "(array '(", gs sh 1, put o 41, each ^n (i \ (put o 32, pel i)), put o 41)))

  ; --- maps print {k v …}. a map can hold itself, so the path rides as [maps depth mark],
  ; matched by identity: the nearest 64 maps, and the mark, the map at the last power-of-two
  ; depth, which a longer cycle reaches within twice its length
  (onpath? x l k) (? (atom? l || k = 0) 0 (x == <l) 1 (onpath? x >l (k - 1)))
  (pmap o m sn) (: p (sn 0) d (peep sn 1 0) (m == sn 2 || onpath? m p 64 ? (say o "<cycle>")
    (: ks (keys m) s2 [(m . p) (d + 1) (d + 1 & d = 0 ? m (sn 2))]
       (go l f) (two? l ? ((f ? 0 (put o 32)),
                           px o <l s2, put o 32, px o (m <l) s2,
                           go >l 0) 0)
       (atom? ks ? (say o "{}") (put o 123, go ks 1, put o 125)))))

  ; --- coins show as (name 'payload), which evals back where the name is a bound ctor; a
  ; chain or nom payload is quoted. a rational shows as (n /// d).
  (pcoin o x sn) (load x @ p
                    (kind x = '/// && two? p ? (put o 40, px o <p sn, say o " /// ", px o <>p sn, put o 41)
                       (put o 40, px o (kind x) sn,
                     put o 32, two? p || nom? p ? (put o 39) 0,
                     px o p sn, put o 41)))

  ; --- closures. a partial's every unc cell holds its arg at [1] and the link at
  ; [2], an uncn cell its n args from [2] and the link after them, so the base value
  ; sits at link-2.
  (uncp o) (o == unc || o == uncn)
  (partp v) (uncp (pick 0 v) || cur == pick 0 v && uncp (pick 2 v))
  (unc0 v) (cur == pick 0 v ? (seek 2 v) v)
  (ulink u) (unc == pick 0 u ? (peek 2 u) (peek (2 + peek 1 u) u))
  (uargs u) (unc == pick 0 u ? [(peek 1 u)] (map (i \ peek (2 + i) u) ^(peek 1 u)))
  (pargs v) (: (go u a) (ulink u @ l (uncp (pick 0 l) ? (go l (uargs u + a)) (uargs u + a))) (go (unc0 v) ()))
  (fbase v) (: (go u) (ulink u @ l (uncp (pick 0 l) ? (go l) (seek -2 l))) (go (unc0 v)))
  (nargs v) #(pargs v)
  (farg v i n) (pargs v i)

  (pfn o v sn) (nifnom v @ nm
                  (string? nm ? (lamform v @ s (s == name nm ? (say o nm) (px o (tpins s) sn)))   ; off the book: what binds it
                     ; a glued sigil's backing value prints as its one word, not its body
                     (opnom v @ gn
                        (gn ? (say o (string gn))
                           (lamform v @ s
                              (? (s !== 0) (px o (tpins s) sn)
                                 (partp v) (nargs v @ n (put o 40, pfn o (fbase v) sn,
                                                         each ^n (i \ (put o 32, px o (farg v i n) sn)), put o 41))
                                 (put o 92, pnum o (abs (dig v)))))))))   ; opaque: the digest, a distinguisher and nothing more

  ; a tablet a read-back form holds, as the pins that build it: a form reads its keys
  (tpins x) (? (tablet? x) (foldl (\ f k ['pin f (tq k) (tq (x k))]) ['tablet 0] (sort (keys x)))
               (atom? x || <x == '\ && two? >x && atom? >>x) x
               (tpins <x . tpins >x))
  (tq v) (? (tablet? v) (tpins v) (nom? v || two? v) ['\ v] v)
  (px o x sn) (? (charm? x) (pnum o x)
                (coin? x) (pcoin o x sn)
                (tablet? x) (pmap o x sn)
                (lit? x) (pfn o x sn)
                (x == ()) (say o "()")
                (two? x) (pchain o x sn)
                (string? x) (pstr o x)
                (nom? x) (mint? x ? (say o "(mint ", pnum o (dig x), put o 41)
                              (say o (string x)))
                (gem? x) (pgem o x)
                (tray? x) (ptray o x sn)
                (twin? x) (ptwin o x)
                (sun? x) (pnum o x)
                o)
  px)))

; `dot` says a string or cask verbatim, anything else shown, and answers its operand
(: (print o x) (px o x (), x)
   (show x) (jug 0 @ o (px o x (), slurp o))
   ; a text with holes, "a \(x) b": its runs verbatim, a string verbatim, the rest shown
   (weave l) (jug 0 @ o (each l (x \ string? x ? (say o x) (px o x ())), slurp o))
   (dot x) (string? x || hot? x && !(port? x) ? (say out x) (px out x ()), flush out, x)
   putx (print out))

; --- whole-file io, and the exit every tool leaves by ---
(: ; a path -> (1 text) when it opens, () when it does not
   (uread p) (cite 'posix 'open p "r" @ q
              (hot? q ? (slurp q @ t (cite 'posix 'close q, [1 t]))))
   ; a path + text -> 1 when it lands, () when it will not open
   (uwrite p t) (cite 'posix 'open p "w" @ q
                 (hot? q ? (say q t, (cite 'posix 'close q), 1)))
   ; mkdir -p: each directory prefix of p, then p, made at mode where missing -> p
   (umkdirs p mode) (: mk (cite 'posix 'mkdir) (each ((cite 'path 'pprefixes) p + [p]) (d \ mk d mode), p))
   ; at an offset: n bytes from off -> (1 text), short at eof; text over the bytes at off,
   ; the rest kept -> 1. () where it will not open or seek. the seek is on the raw fd
   (u-at p m off) (cite 'posix 'openfd p m @ fd
                   (charm? fd && 0 <= fd ?
                      (charm? (cite 'posix 'lseek fd off 0) ? (fdopen fd) (cite 'posix 'close fd, ()))))
   (uread-at p off n) (u-at p 0 off @ q
     (hot? q ? (: b (cask (n < 65536 ? n 65536))
                  (go k acc) (k < 1 ? acc
                                 (cite 'posix 'swig q b @ r (charm? r && 0 < r ?
                                    (go (k - r) ((snip b 0 (r < k ? r k)) . acc)) acc)))
                  t (cats (rev (go n ())))
                  (cite 'posix 'close q, [1 t]))))
   (uwrite-at p off t) (u-at p 4 off @ q (hot? q ? (say q t, (cite 'posix 'close q), 1)))
   ; a main answers its status as a charm, or leaves from deep inside by (uleave c). urun
   ; answers the status either way, not a dead process. nothing unwinds, so a port held at
   ; the leave is lost.
   (uleave c) (scare 'leave c)
   (urun f as)
    (: (out! _) (flush out, flush err)
       (trap (_ \ (f as @ r (out! (), charm? r ? r 0))) ()
             (\ a b (out! (),
                     (a @ 'leave b
                        (say err ";; ", print err a, say err " ",
                         print err b, put err 10, flush err, 1))))))
   ; a nom -> strerror's sentence, for the few a tool meets; another says its name
   (uerrno e)
    (e @ 'enoent "No such file or directory" 'eacces "Permission denied"
         'eperm "Operation not permitted" 'esrch "No such process"
         'enotty "Inappropriate ioctl for device" 'eisdir "Is a directory"
         'enotdir "Not a directory" 'enametoolong "File name too long"
         'eloop "Too many levels of symbolic links" 'einval "Invalid argument" 'erofs "Read-only file system"
         'efbig "File too large" 'ebadf "Bad file descriptor" 'enxio "No such device or address"
         'econnrefused "Connection refused" 'etimedout "Connection timed out"
         'ehostunreach "No route to host" 'enetunreach "Network is unreachable"
         'econnreset "Connection reset by peer" 'eaddrinuse "Address already in use"
         'eaddrnotavail "Cannot assign requested address"
         'enotconn "Transport endpoint is not connected"
         (show e))
   ; say m on err and leave with code c
   (udie c m) (say err m, put err 10, uleave c))

(seal-hook 4 show)
(: (red? x) (+x < 0) (blue? x) (+x = 0) (green? x) (+x > 0))

; --- the disassembler: a thread read back as data. stem, span and seek keep a walk inside
; the object whatever the cells hold. read an operand cell with peek, a code cell with pick.
(: ret0 (pick 1 cap) cur (pick 0 (+))
   ; a nif's run is [impl][ret0], or [cur][arity][impl][ret0]
   (nifop v) (? (ret0 = pick 1 v)                     (pick 0 v)
                (cur = pick 0 v && ret0 = pick 3 v)   (pick 2 v))
   ; an op by its lvm_ name, else by the nif whose body it is
   opnames (: ks (sort (keys book))                   ; sorted: two names on one op must not race
              T (foldl (\ t k ((nom? k ? ("lvm_" = snip (string k) 0 4)) ?
                                 (pin t (book k) k) t))
                       {cur 'lvm_cur ret0 'lvm_ret0} ks)   ; neither of these is a book name
              (foldl (\ t k (: b (nom? k ? (nifop (book k)))
                               ((b ? !(t b)) ? (pin t b k) t)))
                     T ks))
   (opname i) (peep opnames i i)                      ; an index with no name prints as itself
   (discell c) (pick 0 c @ p (!p ? ['val (peek 0 c)] ['op (opname p)]))
   ; (dis v): every cell of the object v points into, from its head
   (dis v) (stem v @ h (!h ? () (map (i \ discell (seek i h)) ^(span h))))
   ; (disp v): the same, one cell a line, `>` marking the cell v itself points at
   (disp v) (stem v @ h
               (!h ? (puts "not on the heap\n")
                ((nat? v ? (puts "; native: a glazed body is code, and reads ()\n")),
                 each ^(span h) (i \ (discell (seek i h) @ r
                                        (puts (show i), puts (seek i h = v ? " > " "   "),
                                         puts (<r = 'op ? "" "= "), putx (r 1), puts "\n")))),
                ())))

; --- library layers: rng and /// are globals, the rest register as modules ---

; rng -- over the stateless C steps: (wheel n) -> a fresh 256-bit state, turn/turnf step it.
; (random st n) -> (value . st'): a float n -> float in [0,n), a positive int -> int in [0,n),
; else a full-width int. (rand n) (randf n) draw from one hidden clock-seeded stream; rng-get
; reads it, (rng-set (wheel n)) pins it (a bad state answers 0, the stream untouched).
; rng-box is bound once, not inlined: separate copies are separate streams.
(: rng-box {}
   (random st n) (? (gem? n) (turnf st @ (a . u) (n * a . u))
                    (0 < n)  (turn  st @ (a . u) (a % n . u))
                    (turn st))
   (rng-get _) (rng-box () @ st (tray? st ? st
              (wheel (clock 0) @ f (pin rng-box () f, f))))
   ; a valid state is rank 1, length 4, of a fresh state's tier (the limb type varies by platform)
   (rng-set st) (tray? st && rank st = 1 && tally st = 4 && tier (wheel 0) = tier st ?
                 (pin rng-box () st, st) 0)
   (rand n) (turn (rng-get 0) @ r
               (pin rng-box () >r,
                charm? n && 0 < n ? (<r % n) <r))
   (randf n) (turnf (rng-get 0) @ r
                (pin rng-box () >r,
                 constellation? n && 0 < n ? (n * <r) <r)))

; /// -- rationals: a coin over reduced (num den), a whole one the integer itself. 3 /// 4
; builds one and prints that way. C knows nothing of it: the coin spells its measure,
; order and integer rungs beside its arithmetic
(: /// (: (reduce n d)
         (0 = n ? [0 1]                           ; gcd out, sign on num, den > 0
          (: g (gcd (abs n) (abs d)) s (d < 0 ? -1 1)
           [(s * n // g) (s * d // g)]))
        (arg v) (? (coin? v) (load v) (two? v) v [v 1])       ; an operand as (n d): a bare star is n/1
        ; a plain number, never a coin: atom? first, a chain's net is a rational whose '= asks this again
        (pnum? v) (atom? v && (nil? * coin?) v && v = +v)
        ; a component is an exact integer: a float or a twin has no gcd to reduce by
        (nstar? v) (pnum? v && !(gem? v || twin? v))
        (ok? v) (nstar? v || two? v && all nstar? v)
        (q p) (1 = <>p ? <p (c p))                          ; a reduced (n d): the integer when d is 1, else struck
        (measure c) (: p (load c) q (<p / <>p)                ; n/d; a quotient lost to underflow
                      (? (<p = 0) 0                             ; keeps its sign, which is its truth
                         (q = 0) ((<p < 0) = (<>p < 0) ? 1e-37 -1e-37)
                         q))
        (val v) (coin? v && ok? (load v) ? (measure v) v)   ; a rational as its measure, anything else itself
        (num? v) (nstar? v || coin? v && ok? (load v))      ; a number or a rational, never a text or a list
        (div x y) (ok? x && ok? y && <y != 0 ?              ; invert and multiply; by zero -> ()
                   (q (reduce (<x * <>y) (<>x * <y))))
        ; an inexact operand: the op over the measures, and the inexact answer wins
        (inex f a b) (: u (val a) w (val b) (pnum? u && pnum? w ? (f u w)))
        (fquot a b) (inex (\ u w (w = 0 ? () (u / w))) a b)
        c (coin '/// (z \ {'star 1                               ; a rational is a star
         'net measure
         '< (\ a b (: x (arg a) y (arg b)                      ; cross-multiply, exact (d > 0)
             (ok? x && ok? y ? (<x * <>y < <y * <>x)
                (val a < val b))))                         ; against a non-number: by the measure
         '= (\ a b (: x (arg a) y (arg b)                      ; cross-multiply, so 7/2 = 3.5
             (ok? x && ok? y ? (<x * <>y = <y * <>x)
                (val a = val b))))
         'int (c \ (load c @ p (<p // <>p)))                 ; toward zero
         'ceil (c \ (: p (load c) k (<p // <>p)                ; d > 1, so the quotient is never whole:
                     (0 < <p ? (k + 1) k)))                  ; up from a positive trunc
         '+ (\ a b (: x (arg a) y (arg b)
             (ok? x && ok? y ?
              (q (reduce (<x * <>y + <y * <>x) (<>x * <>y)))
              (inex (+) a b))))
         '* (\ a b (: x (arg a) y (arg b)
             (ok? x && ok? y ?
              (q (reduce (<x * <y) (<>x * <>y)))
              (inex (*) a b))))
         '- (\ a b (: x (arg a) y (arg b)
             (ok? x && ok? y ?
              (q (reduce (<x * <>y - <y * <>x) (<>x * <>y)))
              (inex (-) a b))))
         '/ (\ a b (: x (arg a) y (arg b) (ok? x && ok? y ? (div x y) (fquot a b))))}))
        (strike a b) (num? a && num? b ? (div (arg a) (arg b)) (fquot a b))  ; a zero or non-number operand -> (), a float the quotient
        (n \ (two? n ? (strike <n <>n)                         ; (/// (n d)) -- the list form
                       (strike n)))))                         ; (/// n d) -- the curried form, and 3 /// 4 spaced


; glob -- fnmatch through posix's nif, a predicate over two strings; no filesystem.
; a mask is a parallel string of '1'/'0' bytes: '1' where the char is live, '0' where a
; quote shielded it.
;   (fmatch pat mask s) -> 1 | 0     * ? [a-z] [!..] [[:alpha:]] \x, quoted chars literal
;   (match pat s)       -> the all-live face
;   (anyglob t)         -> does t hold any * ? [ at all (the cheap pre-scan)
;   (ones k)            -> an all-live mask of width k

(module '(glob match fmatch anyglob ones)
(: (anyglob t)
     (: n #t
        (go i) (i != n && (t i @ (42 || 63 || 91) 1 (go (i + 1))))
        (go 0))
   (ones k) (k < 1 ? "" (ones (k - 1) + "1"))
   (match p s) (cite 'posix 'fnmatch p s)
   ; a shielded char goes to fnmatch behind a backslash, which makes any char itself
   (fmatch p m s) (match (foldl (\ a i (a + (? (i < #m && m i = 49) "" "\\") + string [(p i)])) "" ^#p) s))
) ; module glob

; path -- the primitives; callers spell their own dirname over them
;   (lastslash p) -> index just past the last '/', 0 for none
;   (lastdot p)   -> index of the last '.' after that, #p for none
;   (segs p)      -> the '/'-separated components, empties dropped
;   (pclean l lim)-> that list cleaned, lim bounding how far '..' may climb out of it
;   (pprefixes p) -> the directory prefixes of p, outermost first

(module '(path lastslash lastdot pbase phead segs pclean pprefixes)
(: (lastslash p) ((: (go j) (0 < j ? (p (j - 1) = 47 ? j (go (j - 1))) 0)) #p)
   ; the leaf after the last '/', and the head before it with the slash kept ("" for none)
   (pbase p) (snip p (lastslash p) #p)
   (phead p) (snip p 0 (lastslash p))
   (lastdot p) (lastslash p @ sl
                  ((: (go j) (j > sl ? (p (j - 1) = 46 ? (j - 1) (go (j - 1))) #p)) #p))
   ; "/a/b/c" -> ("/a" "/a/b"): neither the leading '/' nor the leaf is a prefix
   (pprefixes p)
    (: n #p
       (go i acc) (? (n <= i) (rev acc)
                     (0 < i && p i = 47) (go (i + 1) (snip p 0 i . acc))
                     (go (i + 1) acc))
       (go 0 ()))
   (segs s) ((: (go i st acc)
                (? (i >= #s) (rev (st < i ? (snip s st i . acc) acc))
                   (s i = 47) (go (1 + i) (1 + i) (st < i ? (snip s st i . acc) acc))
                   (go (1 + i) st acc))) 0 0 ())
   ; lexical: '..' pops without asking the filesystem. lim bounds the leading '..' kept:
   ; () unbounded, n at most n, past that () -- refused, not clamped. a kept '..' is not
   ; popped by the next: "a/../../b" -> (".." "b"). () is both a refusal and an empty path.
   (pclean l lim)
   ((: (go l acc up)
       (? (atom? l) (rev acc)
          (<l = ".") (go >l acc up)
          (<l = "..") (? (two? acc && <acc != "..") (go >l >acc up)
                         (charm? lim && up >= lim) ()      ; the climb runs out: refused
                         (go >l (".." . acc) (1 + up)))
          (go >l (<l . acc) up)))
    l () 0))

) ; module path

; bytes -- words in and out of byte strings. a reader takes anything that indexes by
; application: a string, a cask, a list.
;   (rdle s i n) (rdbe s i n) -> the n-byte word at i, little- and big-endian
;   (wrle v n) (wrbe v n)     -> v as n bytes, the low n kept (two's complement for v < 0)
;   (rdoct s i n) -> the octal text in the n bytes at i, to its first non-digit (tar's fields)
;   (padk n k)   -> the bytes from n to the next multiple of k
;   (zbytes n)   -> n NULs
;   (b2hex s) (hex2b h) -> bytes as lowercase hex, and hex (either case) back
;   (xorb a b)   -> a with b xored in, byte by byte, #a long
;   (b64e s pad?) (b64d t) -> base64 (rfc 4648), = padded when pad?; decode skips non-alphabet bytes

(module '(bytes rdle rdbe rdoct wrle wrbe padk zbytes b2hex hex2b xorb b64e b64d)
(: (rdle s i n) (n < 1 ? 0 (s i + (rdle s (i + 1) (n - 1) << 8)))
   (rdbe s i n) (foldl (\ a k ((a << 8) + s (i + k))) 0 ^n)
   (rdoct s i n) (: (go k a) (n <= k ? a (s (i + k) @ c (48 <= c < 56 ? (go (k + 1) (a * 8 + c - 48)) a)))
                    (go 0 0))
   (wrle v n) (n < 1 ? "" (string (v & 255) + wrle (v >> 8) (n - 1)))
   (wrbe v n) (n < 1 ? "" (wrbe (v >> 8) (n - 1) + string (v & 255)))
   (padk n k) ((k - n % k) % k)
   (zbytes n) (string (cask n))
   (b2hex s) (foldl (a \ i \ a + zpad 2 (radix (s i) 16)) "" ^#s)
   (hex2b h) (: n (#h // 2) b (cask n)
                (each ^n (i \ pin b i (hexv (h (2 * i)) * 16 + hexv (h (2 * i + 1)))),
                 string b))
   (xorb a b) (: n #a c (cask n) (each ^n (i \ pin c i (a i ^ b i)), string c))
   b64set "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
   (b64e s pad?)
    (: j (jug 0) n #s
       (ch v) (put j (b64set (v & 63)))
       (go i)
        (n <= i ? (slurp j)
           (: b0 (s i) b1 (i + 1 < n ? (s (i + 1)) 0) b2 (i + 2 < n ? (s (i + 2)) 0)
              v ((b0 << 16) | (b1 << 8) | b2)
              (ch (v >> 18), ch (v >> 12),
               (? (i + 1 < n) (ch (v >> 6)) pad? (put j 61) 0),
               (? (i + 2 < n) (ch v) pad? (put j 61) 0),
               go (i + 3))))
       (go 0))
   (b64v c) (? (65 <= c <= 90) (c - 65) (97 <= c <= 122) (c - 71) (48 <= c <= 57) (c + 4)
               (c = 43) 62 (c = 47) 63 -1)
   (b64d t)
    (: j (jug 0) n #t
       (go i a m)
        (n <= i ? (slurp j)
           (b64v (t i) @ d
              (? (d < 0) (go (i + 1) a m)
                 (: a2 ((a << 6) | d) m2 (m + 6)
                    (m2 < 8 ? (go (i + 1) a2 m2)
                       (: k (m2 - 8)
                          (put j ((a2 >> k) & 255), go (i + 1) (a2 & ((1 << k) - 1)) k)))))))
       (go 0 0 0)))

) ; module bytes

; cal -- the proleptic gregorian calendar over days since 1970-01-01, utc; floor division,
; so days before 1970 need no fix-up
;   (civil z)           -> [y m d] for day z
;   (epoch-days y m d)  -> its inverse
;   (wday z)            -> 0 for sunday .. 6
;   (mdays y m)         -> the month's length, leap years included
;   mon3 monl wd3 wdl   -> the month and weekday names, short and long, january and sunday first

(module '(cal civil epoch-days wday mdays mon3 monl wd3 wdl)
(: (civil z0)
    (: z (z0 + 719468)
       era (z // 146097)
       doe (z - era * 146097)
       yoe ((doe - doe // 1460 + doe // 36524 - doe // 146096) // 365)
       y (era * 400 + yoe)
       doy (doe - (365 * yoe + yoe // 4 - yoe // 100))
       mp ((5 * doy + 2) // 153)
       d (doy - (153 * mp + 2) // 5 + 1)
       m (mp < 10 ? (mp + 3) (mp - 9))
       [(m <= 2 ? (y + 1) y) m d])
   (epoch-days y0 m d)
    (: y (m <= 2 ? (y0 - 1) y0)
       era (y // 400)
       yoe (y - era * 400)
       doy ((153 * (m + (2 < m ? -3 9)) + 2) // 5 + d - 1)
       doe (yoe * 365 + yoe // 4 - yoe // 100 + doy)
       (era * 146097 + doe - 719468))
   (wday z) (((z + 4) % 7 + 7) % 7)                   ; 1970-01-01 was a thursday
   ; the gap to the next 1st, so a leap year needs no test
   (mdays y m) (epoch-days (m = 12 ? (y + 1) y) (m = 12 ? 1 (m + 1)) 1 - epoch-days y m 1)
   mon3 ["Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec"]
   monl ["January" "February" "March" "April" "May" "June" "July" "August" "September"
         "October" "November" "December"]
   wd3 ["Sun" "Mon" "Tue" "Wed" "Thu" "Fri" "Sat"]
   wdl ["Sunday" "Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday"])

) ; module cal

; text -- utf-8 as characters and terminal columns. a bad or torn sequence reads as U+FFFD
; and costs one byte.
;   (cpat s i) (cpnext s i) -> the code point at byte i, and the byte after it
;   (cpn s i)               -> the bytes a valid character at i wears, else 0
;   (cps s) (cplen s)       -> the code points, and how many
;   (cpsnip s a b)          -> characters a to b
;   (cprev s)               -> s back to front by character
;   (wcwidth c)             -> the columns c takes: 0 1 or 2, -1 for a control, 0 for NUL
;   (swidth s)              -> the columns s takes, a control none
;   (scut s n)              -> the longest head of s at most n columns wide
;   (gcnext s i) (gcwidth s i) -> the byte after the grapheme cluster at i, and its columns
;   (sgwidth s)             -> the columns s takes by cluster
;   (cpxp? c) (cpvs? c)     -> is c Extended_Pictographic; does VS16 give c an emoji style
;   (cpupper c) (cplower c) -> c's simple case mapping, c where it has none
;   (cpis nm c)             -> is c in the POSIX class named nm ("alpha" .. "xdigit"), glibc's
;   (cpfold c)              -> the characters grep -i takes for c, c not among them
;   (cpfolds lo hi)         -> cpfold of every character lo..hi, together
;   (cpback s i)            -> the byte where the character ending at i opens
;   (cpword? c)             -> is c a word character: _ or alnum, grep's \w

(module '(text cpat cpnext cpn cps cplen cpsnip cprev wcwidth swidth scut gcnext gcwidth sgwidth cpxp? cpvs?
          cpupper cplower cpis cpclass? cpfold cpfolds cpback cpword?)
(: uin (cite 'ucd 'in) umap (cite 'ucd 'map) umoved (cite 'ucd 'moved)
   (tl s k) (k < #s && s k & 192 = 128)
   ; the bytes the character at i wears, 0 when it is none: an overlong, a surrogate or a torn tail
   (cpn s i)
    (: b (s i) c (i + 1 < #s ? (s (i + 1)) 0)
       (? (b < 128) 1
          (b < 194) 0
          (b < 224) (tl s (i + 1) ? 2 0)
          (b < 240) (tl s (i + 1) && tl s (i + 2) && (b != 224 || 160 <= c)
                     && (b != 237 || c < 160) ? 3 0)
          (b < 245) (tl s (i + 1) && tl s (i + 2) && tl s (i + 3) && (b != 240 || 144 <= c)
                     && (b != 244 || c < 144) ? 4 0)
          0))
   (cpnext s i) (i + max 1 (cpn s i))
   (cpat s i)
    (: m (cpn s i)
       (? (m = 0) 65533 (m = 1) (s i)
          (foldl (\ a k (a * 64 + (s (i + k + 1) & 63))) (s i & 127 >> m) ^(m - 1))))
   (cps s) (: n #s (go i acc) (n <= i ? (rev acc) (go (cpnext s i) (cpat s i . acc))) (go 0 ()))
   (cplen s) (: n #s (go i k) (n <= i ? k (go (cpnext s i) (k + 1))) (go 0 0))
   (cpoff s i k) (: n #s (go i k) (n <= i || k < 1 ? i (go (cpnext s i) (k - 1))) (go i k))
   (cpsnip s a b) (cpoff s 0 a @ i (snip s i (cpoff s i (b - a))))
   (cprev s)
    (: n #s o (jug 0)
       (go i acc) (n <= i ? acc (go (cpnext s i) (i . acc)))
       (out j l) (atom? l ? (slurp o) (say o (snip s <l j), out <l >l))
       (out n (go 0 ())))
   wcwidth (cite 'ucd 'width)
   (cpcols s i) (max 0 (wcwidth (cpat s i)))
   ; a grapheme cluster: a character and what joins it -- a zero-width one, an emoji modifier
   ; after a pictograph, a pictograph after a ZWJ, a second regional indicator. ten at most,
   ; zero-width ones past that absorbed. a joined pictograph, or VS16 on a narrow one, is
   ; wide. [the byte after the cluster at i, its columns]
   (cpxp? c) (uin 8 c)
   (cpvs? c) (uin 7 c)
   (cpri? c) (127462 <= c <= 127487)
   (gcat s i)
    (: n #s b (cpat s i) xp (cpxp? b)
       (go j last k w)
        (: c (j < n ? (cpat s j) 0) cw (wcwidth c)
           (on w) (go (cpnext s j) c (k + 1) w)
           (? (c = 0 || cw < 0) [j w]
              (cw = 0) (on (c = 65039 && w = 1 && cpvs? b ? 2 w))
              (9 < k) [j w]
              (xp && 127995 <= c <= 127999) (on 2)
              (xp && last = 8205 && cpxp? c) (on 2)
              (k = 1 && cpri? b && cpri? c) (on 2)
              [j w]))
       (wcwidth b < 0 ? [(cpnext s i) 0] (go (cpnext s i) b 1 (wcwidth b))))
   (gcnext s i) <(gcat s i)
   (gcwidth s i) <>(gcat s i)
   (sgwidth s) (: n #s (go i a) (n <= i ? a (gcat s i @ g (go <g (a + <>g)))) (go 0 0))
   ; back over at most three tails; a byte that ends no whole character stands alone
   (cpback s i)
    (: (go j) (j < 1 || i - j > 2 || !(tl s j) ? j (go (j - 1)))
       j (go (i - 1))
       (cpnext s j = i ? j (i - 1)))
   (cpword? c) (c = 95 || cpis "alnum" c)
   (cpupper c) (c < 128 ? (97 <= c <= 122 ? (c - 32) c) (umap 1 c))
   (cplower c) (c < 128 ? (65 <= c <= 90 ? (c + 32) c) (umap 0 c))
   cpclasses ["alpha" "upper" "lower" "digit" "xdigit" "alnum" "punct" "graph" "print" "space"
              "blank" "cntrl"]
   (cpclass? nm) (elem nm cpclasses)
   (cpis nm c)
    (48 <= c <= 57 @ dig
       (nm @ "alpha" (uin 0 c) "upper" (uin 1 c) "lower" (uin 2 c)
             "digit" dig "xdigit" (dig || 65 <= c <= 70 || 97 <= c <= 102)
             "alnum" (dig || uin 0 c) "print" (uin 3 c)
             "graph" (uin 3 c && !(uin 4 c))
             "punct" (uin 3 c && !(uin 4 c) && !dig && !(uin 0 c))
             "space" (uin 4 c) "blank" (uin 5 c) "cntrl" (uin 6 c)
             0))
   ; gnulib's case_folded_counterparts: c's uppercase, that one's lowercase if it comes back,
   ; and the lowercase letters with no way back, each only if it shares c's uppercase. not an
   ; equivalence: U+1C80 takes U+0412, which does not take it
   cplone [181 305 383 453 456 459 498 837 962 976 977 981 982 1008 1009 1010 1013 7835 8126]
   (cpfold c)
    (: uc (cpupper c) lc (cplower uc)
       (cat (uc != c ? [uc] ())
            (cat (lc != uc && lc != c && cpupper lc = uc ? [lc] ())
                 (filter (x \ x != lc && x != uc && x != c && cpupper x = uc) cplone))))
   ; only a character one of the maps moves, or a lonesome one, has any
   (cpfolds lo hi)
    (: (steps c) (umoved c @ m (hi < m ? () (m . steps (m + 1))))
       (catmap cpfold (cat (steps lo) (filter (x \ lo <= x <= hi) cplone))))
   (swidth s) (: n #s (go i w) (n <= i ? w (go (cpnext s i) (w + cpcols s i))) (go 0 0))
   (scut s n)
    (: m #s
       (go i w) (m <= i ? s (w + cpcols s i @ v (n < v ? (snip s 0 i) (go (cpnext s i) v))))
       (go 0 0)))

) ; module text

; lush -- words back into a command line; the part of module 'lush that needs no os.
; (sh-read (sh-show ws)) = ws for every ws.
;   (sh-quote w)  -> the word as a shell reads it back: bare where it can be, else in '..'
;   (sh-show ws)  -> the words as one line; a keyword is quoted only at the head

(module 'lush
(: ; bytes no shell reads as anything but themselves; none over 127, which a locale may letter
   (sh-tame? c) (97 <= c <= 122 || 65 <= c <= 90 || 48 <= c <= 57 || elem c "_-.,:/@+%=")
   ; tame bytes that still read as syntax, so quoted: NAME=VAL (an assignment) and a leading =
   ; (zsh's command lookup)
   (sh-namec? c i) (97 <= c <= 122 || 65 <= c <= 90 || c = 95 || 0 < i && 48 <= c <= 57)
   (sh-plain? w)
    (: n #w
       (go i) (? (n <= i) 1 (w i = 61) 0 (sh-namec? (w i) i) (go (i + 1)) 1)
       (go 0))
   ; '..' holds every byte but ' itself: a'b quotes as 'a'\''b'
   (sh-sqesc w) (cats (map (c \ c = 39 ? "'\\''" (string c)) (chars w)))
   (sh-quote w) (? !#w "''"
                   (all sh-tame? (chars w) && sh-plain? w) w
                   ("'" + sh-sqesc w + "'"))
   ; a keyword bare in command position is syntax; later on the line it is a plain word
   sh-kw '("if" "then" "else" "elif" "fi" "do" "done" "case" "esac"
           "while" "until" "for" "in" "function" "select" "time")
   (sh-qhead w)  (elem w sh-kw ? ("'" + w + "'") (sh-quote w))
   (sh-qrest ws) ((atom? ws) ? "" (" " + sh-quote <ws + sh-qrest >ws))
   (sh-show ws)  ((atom? ws) ? "" (sh-qhead <ws + sh-qrest >ws)))

) ; module lush

; kanren -- first-order unification + a lazy-colist search monad. overlay below reads it, so
; it registers first. `unify s u v` is pure -- a substitution or `ufail` -- with no occurs
; check: a self-referential binding is a rational tree, and reify marks the back-edge. a goal
; is (\ st stream) over a state (substitution . constraints); est/=== unify, + interleaves,
; * binds.
(module '(kanren =/= === absent apt closed? con dif empty_dict est ifte inside mintp naf nay query rel
   residual rewrite s_app scount slist smap sno sole s_plus s_star st0 stake subst sun
   sX tie ufail ufail? unify untie var var? walk)
   ; the scan asks two?, never ?: a key that nets to nothing would end it early
(: (dict_has d k) (: (loop k ks vs) (two? ks ? (k = <ks ? vs (loop k >ks >vs))) (loop k <d >d))
   (dict_set d k v) ((k . <d) . v . >d)
   empty_dict '(())
   has_s dict_has
   ext_s dict_set
   (mintp x) (mint? x)
   (var x) (x . nom 0)                         ; (label . fresh-nom) -- identity by the nom
   ; a nom anywhere but a pair's tail is data. `?`, not &&: a predicate owes a bit
   (var? x) (two? x ? (nom? >x) 0)
   (walk s u) (!(var? u) ? u (has_s s u @ t (two? t ? (walk s <t) u)))
   ufail (nom 0)
   (ufail? x) (x = ufail)
   ; a binder: the abstraction is a love lambda, so instantiation is application
   (tie f) ('tie . f)
   (tie? t) (two? t ? (<t = 'tie) 0)
   (untie t a) (>t a)                            ; open the binder at a
   (unify s u v) (: x (walk s u) y (walk s v)       ; pure: a substitution, or ufail
     (? (x = y) s                                   ; alpha-equal binders land here, for free
        (var? x) (ext_s s x y)
        (var? y) (ext_s s y x)
        (tie? x && tie? y) (nom 0 @ a (unify s (untie x a) (untie y a)))   ; one fresh nom opens both
        (two? x && two? y) (unify s <x <y @ s1 (ufail? s1 ? ufail (unify s1 >x >y)))
        ufail))
   (subst s t) (? (var? t) (walk s t @ w (var? w ? w (subst s w)))   ; instantiate a template under s
                  (tie? t) (tie (a \ (subst s (untie t a))))             ; under a binder: at its opening
                  (two? t) (subst s <t . subst s >t)
                  t)
   (rewrite pat tpl x) (unify '(()) pat x @ r (ufail? r ? x (subst r tpl)))   ; pattern -> template, or x unchanged

   ; --- the constraint store, beside the substitution: a constraint is (kind . payload),
   ; re-checked against the store after every successful unification
   st0 (empty_dict . ())
   (unify_all s p) (two? p ? (unify s <<p ><p @ r (ufail? r ? ufail (unify_all r >p))) s)
   ; the bindings r has and s does not, as a (u . v) list -- ext_s prepends, so they lead
   (residual r s) (: (go k ks vs acc) (k ? (go (k - 1) >ks >vs ((<ks . <vs) . acc)) acc)
                     (go (#<r - #<s) <r >r ()))
   ; does x occur in the (walked) term t? a tie opens at a fresh nom, never an outer atom
   (inside s x t) (? (x = t) 1
                     (var? t) 0
                     (tie? t) (inside s x (walk s (untie t (nom 0))))
                     (two? t) (inside s x (walk s <t) ? 1 (inside s x (walk s >t)))
                     0)
   (closed? s t) (? (var? t) 0
                    (tie? t) (closed? s (walk s (untie t (nom 0))))
                    (two? t) (closed? s (walk s <t) ? (closed? s (walk s >t)) 0)
                    1)
   ; one constraint against s -> 'drop (satisfied for good), ufail (violated), or itself
   (vet1 s c)
    (<c @ 'dif (: r (unify_all s >c)                    ; unify the prefix on a copy and read it three ways
                (ufail? r ? 'drop                   ;   can never hold -> nothing left to watch
                 (: q (residual r s)                ;   holds with no new binding -> violated
                  (two? q ? ('dif . q) ufail))))
          'abs (: x (walk s <>c) t (walk s >>c)         ; absento, and nominal freshness by the same door
                (? (inside s x t) ufail
                   (closed? s t) 'drop
                   ('abs . x . t)))
          'apt (: w (walk s >>c)                        ; a type constraint over any predicate
                (? (var? w) ('apt . <>c . w)
                   (<>c w) 'drop
                   ufail))
          c)
   (vet s)
    (: (go (a . u)) (vet1 s a @ ^ufail ufail r (go u @ t (t == ufail || r == 'drop ? t (r . t)))) go)
   (con st c) (vet <st c @ d (ufail? d ? ufail (<st . d)))   ; a state with c added, or ufail

   ; --- streams: () empty, (x . s) mature, a thunk immature, told apart by lit?/two?
   sno ()
   (sX x s) (x . s)
   (sun x) [x]
   (s_plus s t) (s @ (f && lit? f) (s_plus t * f)       ; interleave (disj): the swap is the fairness
                     (x . r)       (x . s_plus r t)
                     t)
   (s_star s g) (s @ (f && lit? f) (v \ s_star (f v) g)       ; bind (conj)
                     (x . r)       (s_plus (g x) (s_star r g)))
   (s_app s t)  (s @ (f && lit? f) (v \ s_app (f v) t)        ; ordered disj: no swap, the left runs
                     (x . r)       (x . s_app r t)              ; dry first -- incomplete on purpose
                     t)
   (sfire s) (lit? s ? (sfire (s ())) s)                ; force to a mature shape: () or a cons
   (stake i s) (i @ 0 () (sfire s @ (a . u) (a . stake (i - 1) u)))
   (smap f s) (s @ (g && lit? g) (v \ smap f (g v)) (x . r) (f x . smap f r) ())
   (sfold f z s) (sfire s @ m (two? m ? (f <m (sfold f z >m)) z))
   slist (sfold (.) ())
   (scount s) (: (go a s) (sfire s @ m (two? m ? (go (a + 1) >m) a)) (go 0 s))

   ; --- goals. &&& ||| and the coin's * + are conj2/disj2; `load` takes a bare or rel-wrapped goal
   (conj2 a b) (: g (load a) h (load b) (st \ (s_star (g st) h)))
   (disj2 a b) (: g (load a) h (load b) (st \ (s_plus (g st) (h st))))
   yea sun                               ; the goal that holds, once
   nay ()                                ; the goal that never does
   (est u v st) (unify <st u v @ r
                   (ufail? r ? ()
                    (vet r >st @ c (ufail? c ? () (sun (r . c))))))
   ; unify on a copy: ufail -> holds for good; no new binding -> fails; else the residual
   ; bindings are the constraint
   (dif u v st) (unify <st u v @ r
                   (ufail? r ? (sun st)
                      (residual r <st @ p
                         (two? p ? (con st (('dif . p) . >st) @ t (ufail? t ? () (sun t)))))))
   ; absento: x occurs nowhere in t, now or ever; for a nom x, alphaKanren's a # t
   (absent x t st) (con st (('abs . x . t) . >st) @ r (ufail? r ? () (sun r)))
   ; a type constraint over any predicate -- symbolo/numbero and their kin in one goal
   (apt p x st) (con st (('apt . p . x) . >st) @ r (ufail? r ? () (sun r)))
   ; --- extra-logical. `ifte` is the soft cut: if c holds at all, t runs over its answers and
   ; e is dropped. `sole` commits to the first answer. `naf` is negation as failure: "not
   ; proved", which is "false" only for a ground terminating goal.
   (ifte c t e st) (sfire (c st) @ m (two? m ? (s_star m t) (e st)))
   (sole g st) (sfire (g st) @ m (two? m ? (sun <m)))
   (naf g st) (ifte g nay yea st)

   ; --- query: run a goal, reify the answers
   (query n ks g) (:
    (walk_star s u path) (?                          ; cycle-safe: (mu label) on a back-edge
     (var? u) (has_s s u @ t
                 (? (atom? t) u
                    (elem u path) ['mu <u]
                    (walk_star s <t (u . path))))
     (tie? u) (nom 0 @ a ['tie a (walk_star s (untie u a) path)])
     (two? u) (walk_star s <u path . walk_star s >u  path)
     u)
    ; an answer's mints are renamed a1 a2 .. in first-sight order, so answers compare
    (noms t acc) (? (var? t) acc
                    (mint? t) (elem t acc ? acc (t . acc))
                    (two? t) (noms >t (noms <t acc))
                    acc)
    (renom d t) (? (var? t) t
                   (mint? t) (dict_has d t @ v (two? v ? <v t))
                   (two? t) (renom d <t . renom d >t)
                   t)
    (dename t) (rev (noms t ()) @ ns
                  (two? ns ?
                     (renom (foldl (d \ p \ dict_set d <p <>p) empty_dict
                                   (zip ns (map (i \ nom $ "a" + show (i + 1)) ^#ns)))
                            t)
                     t))
    (keyvar keys k) (atom? keys ? 0 (<keys @ kv (k = <kv ? kv (keyvar >keys k))))
    (reify1 st) (dename (flip catmap ks (k \ (keyvar <<st k @ kv (two? kv ? [k (walk_star <st kv ())])))))
    (map reify1 ((n ? (stake n) slist) (g st0))))
   rel (coin 'goal (z \ {'+ (\ A B (z (disj2 A B)))   ; the goal coin: + = disj = |||, * = conj = &&&
                         '* (\ A B (z (conj2 A B)))})))
(: (=== u v) (rel (est u v))                        ; all-punct, so infix at house band; a chain
   (=/= u v) (rel (dif u v)))                       ; of the two wants parens
; the goal macros live in kanren's own macro table, so (borrow 'kanren) carries them.
; &&& and ||| are && and ||, \\\ is \ with its params fresh logic vars.
(:: 'zz (x \ (: s (nom 0) u (nom 0) x2 <x ['\ s u [x2 s]])))   ; delay a goal: the curried tail is the thunk
(:: '&&& (xs \ (foldl (\ a b [conj2 a b]) <xs >xs)))   ; conj of goals -- the ring's *
(:: '||| (xs \ (foldl (\ a b [disj2 a b]) <xs >xs)))   ; disj of goals -- the ring's +
(:: '\\\ (a \ (('\ . a) . map (a \ [var ['\ a]]) (init a))))                         ; lambda w/ fresh logic vars

) ; module kanren

; overlay -- an optional, observe-only static-type overlay hooked at the ev seam
(module '(overlay ov-check ov-eng overlay-off overlay-set ov-hook ov-slot)
(borrow 'kanren)                                         ; subst unify ufail ufail? var, scoped to this compile
(: ov-both
    (: (ov-sigof sigs nm) (sigs @ (((aa . ua) @ a) . u) (nm @ ^aa a (ov-sigof u nm)))
       (ov-look env x) (env @ ((ap . up) . env') (x @ ^ap up (ov-look env' x)) 'bot)
       (ov2-var? dom d) (nom? d && nelem d (dom 'dice) && nelem d (dom 'ctors))   ; a sig variable: not concrete, not a constructor
       (ov2-vars dom d acc) (atom? d ?
        (ov2-var? dom d && (nelem d acc) ? (d . acc) acc)
        (foldl (flip $ ov2-vars dom) acc d))
       (ov2-lk vm d) (? (atom? vm) d
                        (d = <<vm) ><vm
                        (ov2-lk >vm d))   ; ><vm is glued: cuap, not the cons
       (ov2-term vm d)    (atom? d ? (ov2-lk vm d) (map (ov2-term vm) d))
       (ov2-uall ps as s) (? (atom? ps || atom? as) s
                             (elem <as '(top bot)) (ov2-uall >ps >as s)   ; an unknown arg is gradual: consistent with any param, binds nothing
                             (unify s <ps <as @ s1 (ufail? s1 ? ufail (ov2-uall >ps >as s1))))
       (ov2-inst dom sg args)                                          ; sg = (name (param-dies) result): structured caller instantiation
        (: params <>sg result <>>sg
           vm (map (nm \ nm . var nm) (ov2-vars dom (params . result) ()))            ; one fresh logic var per sig variable
           s  (ov2-uall (map (ov2-term vm) params) args '(()))   ; a caller's rigid symbol is a constant here
           (? (ufail? s) 'clash                                        ; args contradict the params: the one hard verdict
              (#args != #params) 'top                        ; partial/over-application: a closure/re-application, die unknown
              (: r (subst s (ov2-term vm result)) nf (dom 'norm) (lit? nf ? (nf r) r))))   ; reify + normalize (dependent index)
       (ov-kindof dom sigs env e)
          (? (nom? e) (ov-look env e)
             (atom? e) (dom 'litdie e)
             (: h <e as (map (ov-kindof dom sigs env) >e)
                (? (elem h '(+ *)) (dom 'tr h <as <>as)
                   (h = '? && #e = 4) (dom 'join <>as <>>as)
                   (ov-sigof sigs h @ sg (atom? sg ? 'top (ov2-inst dom sg as))))))
       (ov-zip (ap . up)  (ad . ud))     ((ap . ad) . ov-zip up ud)
       (ov-clash dom sigs env e) (two? e ? (: d (ov-kindof dom sigs env e) sub (catmap (ov-clash dom sigs env) >e)
                                            (d @- sub 'clash ((e . map (ov-kindof dom sigs env) >e) . sub))))   ; a clash site = (expr . operand-dies)
                                                    ; the ternary is parenthesized: bare in a `:`
                                                    ; element list it does not factor at all
       (ov-pairs (a . b . c)) ((a . b) . ov-pairs c)
       (ov2-okr dom bd decl) (dom 'okr @ f (lit? f ? (f bd decl) (dom 'join bd decl = decl)))   ; result acceptable? domain `okr` (dependent = up to conv/norm), else structural join
       (ov-check1 dom sigs prog)
          (catmap (p @ ((nm . ps) . body) \                          ; parenthesize the `:`: it is
                     (: sg (ov-sigof sigs nm)                       ; looser than `?`, so unwrapped it
                        (two? sg ?                                  ; eats `two? sg` as a second pair
                         (: env (ov-zip ps <>sg) cl (ov-clash dom sigs env body)
                            bd (ov-kindof dom sigs env body) decl <>>sg
                          (two? cl || !(ov2-okr dom bd decl) ? [(nm . (atom? cl ? ['result bd decl] cl))])))))
                  (filter (two? * cap) (ov-pairs >prog)))
       (ov-djoin dies) (? (atom? dies) "?" (atom? >dies) (show <dies) (show <dies + " vs " + ov-djoin >dies))
       (ov-report nm detail) (detail @ ; detail = (result BD DECL) | ((expr . opdies) ..)
        ['result bd decl]
         (puts $ ";; overlay: " + string nm + " -- returns " + show bd + ", declared " + show decl + "\n")
        ((expr . opdies) . _)
         (puts $ ";; overlay: " + string nm + " -- clash in " + show expr + "  (" + ov-djoin opdies + ")\n"))
       (ov-reps ((aa . ua) . u)) (ov-report aa ua, ov-reps u)
       (ov-run dom sigs form)
        (form @ (': . _) (ov-check1 dom sigs form @ (r @ (_ . _)) (ov-reps r)))
     [ov-run ov-check1])                           ; the run entry + the pure checker (internals private)
   ov-eng      <ov-both
   ov-check    <>ov-both                           ; (ov-check dom sigs form) -> () clean | ((name . detail)..) -- the report as data (a gate's leg)
   ov-slot     {}                          ; install slot: peep 0 -> (DOM SIGS) or ()
   (overlay-set dom sigs) (pin ov-slot 0 [dom sigs])
   (overlay-off _) (pin ov-slot 0 ())

   (ov-hook e0 e)
     (ov-slot 0 @ v (two? v ? (ov-eng <v <>v e, e0 e) (e0 e))))
) ; module overlay

; uu -- MLTT with the UniMath Preamble's seven inductives (empty unit bool coprod nat paths
; total2), bidirectional checking, NbE conversion (de bruijn levels as fresh vars, sigma- and
; pi-eta), type-in-type as UniMath has it. an axiom is a book entry with a type and no value.
; names follow UniMath.
;
; terms are quoted lists: UU nat bool unit empty zero tt true false <fixnum>
;   (pi x A B) (lam x b) (total2 x A B) (tpair a b) (pr1 w) (pr2 w) (succ n)
;   (coprod A B) (ii1 a) (ii2 b) (paths a a b) (idpath a) (the T t)
;   (nat_rect P z s n) (bool_rect P t f b) (unit_rect P u x)
;   (coprod_rect P f g v) (empty_rect P e) (paths_rect P pr e)
;   (let x a b) -- definitional: x binds the value of a, transparent to conv
; and any other list is an application spine. (f) == f here too.
; the defn/defq/axm macros live in this module's macro table.

; --- the kernel: values, evaluation, conversion, checking ---
(module '(uu axm bridge capp chk conv defn defq GLOB HELPC lof rejects vof)
(: GLOB {} HELPC {} SRC {} CMEM {} BRIDGE {})

(: (vsucc v) (charm? v ? (v + 1) ['succ v])

   ; a uu closure ('clo f) carries a love function, so applying one is an application, not a
   ; re-walk of syntax. only capp opens one.
   (capp cl v) (<>cl v)
   (vapp f a) (f @ ['lam cl] (capp cl a) ['na f a])
   (dop1 v) (v @ ['chain a _] a ['np1 v])
   (dop2 v) (v @ ['chain _ b] b ['np2 v])
   (donr P z s m) (charm? m ?
    (: (go k acc) (k = m ? acc (go (k + 1) (vapp (vapp s k) acc))) (go 0 z))
    (m @ ['succ n] (vapp (vapp s n) (donr P z s n)) ['nnr P z s m]))
   (dobr P x y v) (v @ 'true x  'false y  ['nbr P x y v])
   (dour P x v) (v @ 'tt x ['nur P x v])
   (docr P f g v) (v @ ['i1 a] (vapp f a) ['i2 b] (vapp g b) ['ncr P f g v])
   (doer P v) ['ner P v]
   (dojr P r ev) (ev @ ['refl _] r ['njr P r ev])
   (vof-sym en x) (assq x en @ (_ y) y (GLOB x @ (_ y) y (scare 'uu-unbound x)))

   ; --- comp: a term walked once into a love function of the env. vof-sym stays inside the
   ; (\ en ..): a later defn must be visible to a term compiled earlier.
   ; arms run most frequent first (lam and succ are half); they are exclusive, so order is free.
   (comp t)
   (? (charm? t) (en \ t)
      (nom? t) (? (memq t '(UU nat bool unit empty tt true false)) (en \ t)
                  (t = 'zero) (en \ 0)
                  (en \ vof-sym en t))
      ; a spine's list head matches no tag, so it falls through to the else
      (t @
         ['lam x b]             (comp b @ cb (en \ ['lam ['clo (v \ cb ([x v] . en))]]))
         ['succ a]              (comp a @ ca (en \ vsucc (ca en)))
         ['pi x A B]            (: cA (comp A) cB (comp B)
                                 (en \ ['pi (cA en) ['clo (v \ cB ([x v] . en))]]))
         ['paths A a b]         (: cA (comp A) ca (comp a) cb (comp b)
                                 (en \ ['paths (cA en) (ca en) (cb en)]))
         ['nat_rect P z s n]    (: cP (comp P) cz (comp z) cs (comp s) cn (comp n)
                                 (en \ donr (cP en) (cz en) (cs en) (cn en)))
         ['tpair a b]           (: ca (comp a) cb (comp b) (en \ ['chain (ca en) (cb en)]))
         ['idpath a]            (comp a @ ca (en \ ['refl (ca en)]))
         ['paths_rect P r e]    (: cP (comp P) cr (comp r) ce (comp e)
                                 (en \ dojr (cP en) (cr en) (ce en)))
         ['bool_rect P x y w]   (: cP (comp P) cx (comp x) cy (comp y) cw (comp w)
                                 (en \ dobr (cP en) (cx en) (cy en) (cw en)))
         ['coprod A B]          (: cA (comp A) cB (comp B) (en \ ['coprod (cA en) (cB en)]))
         ['coprod_rect P f g w] (: cP (comp P) cf (comp f) cg (comp g) cw (comp w)
                                 (en \ docr (cP en) (cf en) (cg en) (cw en)))
         ['empty_rect P e]      (: cP (comp P) ce (comp e) (en \ doer (cP en) (ce en)))
         ['unit_rect P u x]     (: cP (comp P) cu (comp u) cx (comp x)
                                 (en \ dour (cP en) (cu en) (cx en)))
         ['UU 0]                (en \ 'UU)
         ['UU l]                (en \ ['U l])
         ['the T u]             (comp u)                    ; the ascription is the term
         ['let x a b]           (: ca (comp a) cb (comp b) (en \ cb ([x (ca en)] . en)))
         ['total2 x A B]        (: cA (comp A) cB (comp B)
                                 (en \ ['sig (cA en) ['clo (v \ cB ([x v] . en))]]))
         ['pr1 w]               (comp w @ ca (en \ dop1 (ca en)))
         ['pr2 w]               (comp w @ ca (en \ dop2 (ca en)))
         ['ii1 a]               (comp a @ ca (en \ ['i1 (ca en)]))
         ['ii2 b]               (comp b @ ca (en \ ['i2 (ca en)]))
         (: cf (comp <t) cas (map comp >t) (en \ spine en (cf en) cas))))

   (spine en f cas) (cas @ (a . u) (spine en (vapp f (a en)) u) f)

   vof (flip comp)                               ; compile, then run

   ; `==`, not `=`: `=` walks closures, exponential over shared environments. a `?`, not a
   ; pattern, which would build [a b] per call
   (conv d a b)
   (? (a == b) 1
      (atom? a || atom? b) 0
      (<a = 'lam || <b = 'lam)
       (['nv d] @ fr (conv (d + 1) (vapp a fr) (vapp b fr)))
      (<a = 'chain && <b != 'chain)
       (conv d <>a (dop1 b) && conv d <>>a (dop2 b))
      (<b = 'chain && <a != 'chain)
       (conv d (dop1 a) <>b && conv d (dop2 a) <>>b)
      (<a = 'pi && <b = 'pi)
       (conv d <>a <>b && (['nv d] @ fr (conv (d + 1) (capp <>>a fr) (capp <>>b fr))))
      (<a = 'sig && <b = 'sig)
       (conv d <>a <>b && (['nv d] @ fr (conv (d + 1) (capp <>>a fr) (capp <>>b fr))))
      (<a = <b)
       (conv-args d >a >b))

   (conv-args d as bs)
   (atom? as && atom? bs || two? as && two? bs && conv d <as <bs && conv-args d >as >bs)

   (inf-sym cx x)
   (x @ ('UU || 'nat || 'bool || 'unit || 'empty) 'UU
        'zero 'nat
        'tt 'unit
        ('true || 'false) 'bool
        (assq x cx @ (_ T) T (GLOB x @ (g . _) g (scare 'uu-unbound x))))

   (inf-spine cx en d f as)
   (as @ (a . u) (f @ ('pi A q) (chk cx en d a A, inf-spine cx en d (capp q (vof en a)) u)
                   (scare 'uu-not-a-pi as)) f)

   ; each arm matches the term, then the type; the inner else is the mismatch
   (chk cx en d t T)
   (t @
      ['lam x b]   (T @ ('pi A q) (['nv d] @ fr
                                     (chk ([x A] . cx) ([x fr] . en) (d + 1) b (capp q fr)))
                        (scare 'uu-lam-needs-pi t))
      ['tpair a b] (T @ ['sig A q] (chk cx en d a A,
                                    chk cx en d b (capp q (vof en a)))
                        (scare 'uu-tpair-needs-total2 t))
      ['ii1 a]     (T @ ['coprod A _] (chk cx en d a A) (scare 'uu-ii1-needs-coprod t))
      ['ii2 b]     (T @ ['coprod _ B] (chk cx en d b B) (scare 'uu-ii2-needs-coprod t))
      ['idpath a]  (T @ ['paths A av bv]
                          (: v (chk cx en d a A, vof en a)
                           (conv d v av && conv d v bv || scare 'uu-idpath-mismatch t))
                        (scare 'uu-idpath-needs-paths t))
      ['let x a b] (: Av (inf cx en d a)
                      va (vof en a)
                    (chk ([x Av] . cx) ([x va] . en) d b T))
      (inf cx en d t @ Ti
         (conv d T Ti || scare 'uu-type-mismatch t)))

   ; the else is the spine; a tag at the wrong length reaches it too and scares unbound
   (inf cx en d t)
   (? (charm? t) 'nat
      (nom? t) (inf-sym cx t)
      (t @
         [('pi || 'total2) x A B]
          (: fr (chk cx en d A 'UU, ['nv d])
           (chk ([x (vof en A)] . cx) ([x fr] . en) (d + 1) B 'UU, 'UU))
         ['coprod A B] (chk cx en d A 'UU, chk cx en d B 'UU, 'UU)
         ['paths A a b]
          (: Av (chk cx en d A 'UU, vof en A)
           (chk cx en d a Av, chk cx en d b Av, 'UU))
         ['succ n] (chk cx en d n 'nat, 'nat)
         ['idpath a]
          (: Av (inf cx en d a) v (vof en a) ['paths Av v v])
         ['pr1 w]
          (inf cx en d w @ ['sig A _] A (scare 'uu-pr1-needs-total2 t))
         ['pr2 w]
          (inf cx en d w @ ['sig _ q] (capp q (dop1 (vof en w))) (scare 'uu-pr2-needs-total2 t))
         ['the T u]
          (: Tv (chk cx en d T 'UU, vof en T) (chk cx en d u Tv, Tv))
         ['let x a b]
          (: Av (inf cx en d a) va (vof en a) (inf ([x Av] . cx) ([x va] . en) d b))
         ['nat_rect P z s n]
          (: Pv (chk cx en d n 'nat,
                 chk cx en d P (vof 0 '(pi x nat UU)),
                 vof en P)
           (chk cx en d z (vapp Pv 0),
            chk cx en d s (vof [['P Pv]] '(pi k nat (pi r (P k) (P (succ k))))),
            vapp Pv (vof en n)))
         ['bool_rect P x y w]
          (: Pv (chk cx en d w 'bool,
                 chk cx en d P (vof 0 '(pi x bool UU)),
                 vof en P)
           (chk cx en d x (vapp Pv 'true),
            chk cx en d y (vapp Pv 'false),
            vapp Pv (vof en w)))
         ['unit_rect P u w]
          (: Pv (chk cx en d w 'unit,
                 chk cx en d P (vof 0 '(pi x unit UU)),
                 vof en P)
           (chk cx en d u (vapp Pv 'tt),
            vapp Pv (vof en w)))
         ['empty_rect P e]
          (chk cx en d e 'empty,
           chk cx en d P (vof 0 '(pi x empty UU)),
           vapp (vof en P) (vof en e))
         ['coprod_rect P f g w]
          (inf cx en d w @
           ['coprod A B]
            (: Pv (chk cx en d P (vof [['A A] ['B B]] '(pi x (coprod A B) UU)),
                   vof en P)
             (chk cx en d f (vof [['A A] ['P Pv]] '(pi a A (P (ii1 a)))),
              chk cx en d g (vof [['B B] ['P Pv]] '(pi b B (P (ii2 b)))),
              vapp Pv (vof en w)))
           (scare 'uu-coprod_rect t))
         ['paths_rect P r e]
          (inf cx en d e @
           ['paths A av bv]
            (: Pv (chk cx en d P (vof [['A A] ['a av]] '(pi b A (pi e (paths A a b) UU))),
                   vof en P)
             (chk cx en d r (vapp (vapp Pv av) ['refl av]),
              vapp (vapp Pv bv) (vof en e)))
           (scare 'uu-paths_rect t))
         (('lam || 'tpair || 'ii1 || 'ii2) . _) (scare 'uu-cannot-infer t)
         (inf-spine cx en d (inf cx en d <t) >t))))

; --- drivers: defn checks then pins; an axiom's value is its own neutral name; rejects runs a
; thunk expecting the kernel to refuse
(: (defn nm T t)
   (: Tv (chk 0 0 0 T 'UU,
          vof 0 T)
    (chk 0 0 0 t Tv,
     pin GLOB nm [Tv (vof 0 t)],
     pin SRC nm [t],
     nm))
   (axm nm T)
   (chk 0 0 0 T 'UU,
    pin GLOB nm [(vof 0 T) ['nv nm]],
    nm)
   ; Qed: checked like defn, then sealed with its own neutral as value, so applying the proof
   ; never builds its beta-normal form
   (defq nm T t)
   (: Tv (chk 0 0 0 T 'UU,
          vof 0 T)
    (chk 0 0 0 t Tv,
     pin GLOB nm [Tv ['nv nm]],
     nm))
   (rejects th)
   (: r (call-cc (k \ (pin HELPC () (\ a b (k 'rejected)), th 0, 'accepted)))
    (pin HELPC () 0, r)))

; --- uu2l: a closed term to a love form whose value is vof's answer (charms for nats,
; ('chain a b) for pairs); lof evaluates one. untrusted: chk/conv never use it, so a bug
; cannot fake a theorem. globals embed as quoted literals, so no uu binder can capture them.
; bridge maps names to native love; a defq or axm name compiles to its own neutral.
(: (qlit v) ['\ v]
   (kchain a b) ['chain a b]
   (kp1 v) (v @ ['chain a _] a ['np1 v])
   (kp2 v) (v @ ['chain _ b] b ['np2 v])
   (ksucc v) (v + 1)
   (ki1 a) ['i1 a]
   (ki2 a) ['i2 a]
   (krefl a) ['refl a]
   (knrec s z n) (foldl (flip s) z ^n)
   (kbrec x y b) (b @ 'true x y)
   (kcrec f g v) (v @ ['i1 a] (f a) ['i2 b] (g b))
   (kseq e r) r

   (uglo nm)
   (CMEM nm @ (_ v) v
    (BRIDGE nm @ (_ v) v
     (SRC nm @ (src) (ev (u2 src ()) @ v (pin CMEM nm ['hit v], v))
               ['nv nm])))

   (u2app t bs) (map (a \ u2 a bs) t)

   ; the eliminators reorder their operands to the k- helpers'
   (u2 t bs)
   (? (charm? t) t
      (nom? t)
      (? (t = 'zero) 0
         (memq t '(UU nat bool unit empty tt true false)) (qlit t)
         (memq t bs) t
         (qlit (uglo t)))
      (t @
         ['lam x b]   ['\ x (u2 b (x . bs))]
         ['let x a b] [': x (u2 a bs) (u2 b (x . bs))]
         ['the T u]   (u2 u bs)
         (('pi || 'total2 || 'coprod || 'paths) . _) (qlit ['ty <t])
         ['tpair a b] [kchain (u2 a bs) (u2 b bs)]
         ['pr1 w]     [kp1 (u2 w bs)]
         ['pr2 w]     [kp2 (u2 w bs)]
         ['succ n]    [ksucc (u2 n bs)]
         ['ii1 a]     [ki1 (u2 a bs)]
         ['ii2 b]     [ki2 (u2 b bs)]
         ['idpath a]  [krefl (u2 a bs)]
         ['nat_rect _ z s n]     [knrec (u2 s bs) (u2 z bs) (u2 n bs)]
         ['bool_rect _ x y w]    [kbrec (u2 x bs) (u2 y bs) (u2 w bs)]
         ['unit_rect _ u w]      [kseq (u2 w bs) (u2 u bs)]
         ['coprod_rect _ f g w]  [kcrec (u2 f bs) (u2 g bs) (u2 w bs)]
         ['paths_rect _ r e]     [kseq (u2 e bs) (u2 r bs)]
         ['empty_rect _ e]       [kseq (u2 e bs) (qlit 'ner)]
         (u2app t bs)))

   (uu2l t) (u2 t ())
   (lof t) (ev (u2 t ()))
   (bridge nm f) (pin BRIDGE nm ['hit f], nm))

; --- arity guards: curried defn/defq/axm given too few operands would answer a truthy
; closure and pin nothing. the macros scare on a wrong count in call position.
(: q (map qlit)
 (:: 'defn (l \ l @ [_ _ _] (defn . q l) (scare 'uu-defn-arity l)),
  :: 'defq (l \ l @ [_ _ _] (defq . q l) (scare 'uu-defq-arity l)),
  :: 'axm  (l \ l @ [_ _]   (axm  . q l) (scare 'uu-axm-arity  l))))

) ; module uu

; peg -- parser combinators. a parser is (\ s y n) over a state s = (text . i), with success
; y = (\ rest payload) and failure n = (\ rest); payloads are lists `seq` concatenates, and
; the empty payload is (). leaves: `lit` (a literal prefix), `one` (a char by predicate),
; `span` (a maximal run). `parse` wants the whole input consumed, `runp` ignores the rest.
; a consumer's (borrow 'peg) must be its own top-level form: a `:` body compiles as one unit.

(module 'peg
(: (eps s y n) (y s ())
   (lit l s y n) (: t <s i >s k (i + #l)
                  (k <= #t && l = snip t i k ? (y (t . k) [l]) (n s)))
   ; yields a one-char string, so payloads join by concat; the predicate sees the charm
   (one p s y n) (: t <s i >s
                  (i < #t && p (t i) ? (y (t . (i + 1)) [(snip t i (i + 1))]) (n s)))
   (span p s y n) (:
    t <s i >s
    (g j) (j < #t && p (t j) ? (g (1 + j)) j)
    k (g i)
    (y (t . k) [(snip t i k)]))
   (alt a b s y n) (a s y (_ \ b s y n))
   (seq a b s y n) (a s (s1 \ p1 \ b s1 (s2 \ p2 \ y s2 (p1 + p2)) n) n)
   (seqs l) (foldr seq eps l)
   (opt a s y n) (a s y (_ \ y s ()))
   (skip a s y n) (a s (\ s1 _ (y s1 ())) n)
   (pmap f a s y n) (a s (\ s1 x (y s1 (f x))) n)
   (many a s y n) (a s
    (s1 \ p1 \ many a s1 (s2 \ p2 \ y s2 (p1 + p2)) (_ \ y s1 p1))
    (_ \ y s ()))
   (nope s y n) (n s)                                            ; the always-failing parser: alts' unit
   (notp a s y n) (a s (_ \ _ \ n s) (_ \ y s ()))              ; negative lookahead -- consumes nothing either way
   (many1 a) (seq a (many a))
   alts (foldr alt nope)
   (pack a) (pmap (p \ [p]) a)                                   ; a whole payload folded to one element
   (tag f a) (pmap (p \ [(f p)]) a)                              ; ..and that element built into a node
   (dflt a v) (alt a (pmap (_ \ [v]) eps))                       ; a always yields one element, v when absent
   (parse p s) (p (s . 0) (r \ x \ (>r = #s ? x ())) ())      ; strict: whole input must parse
   (runp p s)  (p (s . 0) 0 ()))                               ; lenient: keep the payload, ignore trailing slack

) ; module peg

; re -- posix BRE and ERE through posix's regcomp/regexec nifs, utf-8 and in gnu grep's dialect.
; (rebre p) / (reere p) -> (1 m ngroups), or () for a malformed p; (refold m) is m caseless.
; (refind m s i) -> the leftmost-longest match at or after i as (1 start end spans), spans
; ([k start end]..) for the groups that took part; ^ and \b see the text before i.
; (rehas m s) is the boolean. a matcher is (pattern flags program); flags past 255 are
; regexec's, shifted 8 left.
(module 're
(: rc (cite 'posix 'regcomp)
   rx (cite 'posix 'regexec)
   (rex p fl) (rc p fl @ [b n] [1 [p fl b] n])
   (rebre p) (rex p 48)
   (reere p) (rex p 49)
   (refold m) <>(rex <m (m 1 | 2))
   (respans l k) (l @ (a . (b . u)) (a < 0 ? (respans u (k + 1)) ([k a b] . (respans u (k + 1)))))
   (refind m s i) (rx (m 2) s i (m 1 >> 8) @ (a . (b . u)) [1 a b (respans u 1)])
   (rehas m s) (two? (rx (m 2) s 0 0)))
) ; module 're

; grid -- cells laid across a terminal as ls does: ragged columns, the most that fit, filled
; down (ls -C) or across (ls -x), byte for byte as GNU's. a cell is (text . width), since sgr
; escapes take no screen. lines carry no trailing blanks.
(module '(grid lay screen)
(: gmin 3                            ; the narrowest a column may be: one char and its gap
   gpad 2                            ; the gap between two columns
   gtab 8                            ; the pad rides tab stops where two fit, as GNU's does
   (gind f t) (? (t <= f) ""
                 ((f + 1) // gtab < t // gtab) ("\t" + gind (f + gtab - f % gtab) t)
                 (" " + gind (f + 1) t))
   ; the cells by index: both walks jump, so a list would cost a walk per cell
   (gvec cs) (: t {}
                (go l j) (atom? l ? t (pin t j <l, go >l (j + 1)))
                (go cs 0))
   ; the slot cell j takes when the row is i+1 columns wide
   (gslot j i n down?) (down? ? (j // ((n + i) // (i + 1))) (j % (i + 1)))
   ; every column count measured in one pass; a count dies once its line outgrows w. slot
   ; widths keyed (count * mx + slot). answers the widths of the widest count that lived.
   (gfit cs n w down?)
    (: mx ((w + gpad) // gmin @ m (? (m < 1) 1 (m < n) m n))     ; k columns fill 3k - 2
       aw {}                         ; a slot's width so far, gmin until something widens it
       ln {}                         ; the line a count of i+1 has claimed
       ok {}                         ; is it still inside w?
       (gwide j i c)
        (: k (gslot j i n down?)
           r (>c + (k = i ? 0 gpad))            ; the last column on a row owes no gap
           o (peep aw (i * mx + k) gmin)
           (o < r ? (peep ln i (gmin * (i + 1)) + r - o @ l
                       (pin aw (i * mx + k) r,
                        pin ln i l,
                        pin ok i (l <= w)))                ; a line may fill the screen
              ()))
       (gone c j i) (mx <= i ? ()
                       ((peep ok i 1 ? (gwide j i c)), gone c j (i + 1)))
       (gall l j) (two? l ? (gone <l j 0, gall >l (j + 1)))
       _ (gall cs 0)
       (gpick i) (? (i < 1) 1 (peep ok i 1) (i + 1) (gpick (i - 1)))
       k (gpick (mx - 1))
       (map (j \ peep aw ((k - 1) * mx + j) gmin) ^k))
   ; down the columns: a row is cell r, r + rows, r + 2 * rows, ..
   (gdown v n cw)
    (: rows ((n + #cw - 1) // #cw)
       (row j col pos acc)
        (: c (v j) s (acc + <c) nj (j + rows)
           (n <= nj ? s
              (cw col @ mw
                 (row nj (col + 1) (pos + mw) (s + gind (pos + >c) (pos + mw))))))
       (map (r \ row r 0 0 "") ^rows))
   ; across the rows: a row is a run of #cw cells, in order
   (gacross v n cw)
    (: k #cw
       (row j col pos acc)
        (: c (v j) s (acc + <c) nj (j + 1)
           (? (n <= nj) s
              (k <= col + 1) s
              (cw col @ mw
                 (row nj (col + 1) (pos + mw) (s + gind (pos + >c) (pos + mw))))))
       (go j) (n <= j ? () ((row j 0 0 "") . (go (j + k))))
       (go 0))
   ; (screen fd) -- the terminal's width on fd, else $COLUMNS when a plain count, else 80
   (screen fd)
    (: e (getenv "COLUMNS")
       c (string? e ? (unum e @ n (charm? n && 0 < n ? n 80)) 80)
       t (tty fd)
       (two? t && 0 < >t ? >t c))
   ; (lay cs w down?) -- the cells over a terminal w columns wide, as lines
   (lay cs w down?)
    (#cs @ n
       (n < 1 ? ()
          (: cw (gfit cs n w down?) v (gvec cs)
             (down? ? (gdown v n cw) (gacross v n cw))))))

) ; module grid

; verbs -- the registry behind `love mooncc ..` and a `sed` symlink onto the artifact: one
; name-keyed tablet, (cite 'verbs 'tab) the real one, mutated by `pin`. never spliced, or
; `get` would shadow half the tree. two lookups, with different shadow rules:
;   (word w)  a leading positional; refuses a `/` or a `.l`, so a verb cannot eat a local
;             script of the same name
;   (seat p)  argv[0], by its basename
; a verb takes the args after its name and answers a status charm.
(module '(verbs any? bn call dash enlist fills fire get holds seat seatof tab trait word)
(: tab {}   ; nil? when empty: ask it with peep, not by testing it
   ; what a verb says of itself -- name -> {trait v}, v 1 or a function of the call's args:
   ;   'builtin  run in the caller in every mode, ahead of PATH (echo, test ..)
   ;   'self     safe to run in the caller: bounded, reads no stdin, leaves the caller as it
   ;             found it, and answers the same whoever asks
   ;   'exec     wants a fresh process, never a fork of a warm one
   ;   'login    a shell: named by a dash-led argv[0], it is handed --login
   ; a verb with no traits is forked warm
   traits {}
   ; a filler, run once at the first miss to register lazily-loaded verbs; the slot is
   ; cleared before the call so it cannot re-enter
   fill {}
   (fills f) (pin fill 'f f)
   (get k)   (tab k @ v
                (lit? v ? v
                 (fill 'f @ f
                    (lit? f ? (pin fill 'f (), f (), tab k)))))
   ; register a verb: ts a list of trait words, or (word . f) with f a function of the args
   (enlist k f ts) (pin tab k f,
                    pin traits k (foldl (\ t x (two? x ? (pin t <x >x) (pin t x 1))) {} ts))
   (trait k t) (peep (peep traits k {}) t 0)
   ; the trait for one call; a function that scares answers 0
   (holds k t as) (trait k t @ v (lit? v ? (trap (_ \ (bit (v as))) () (\ a b 0)) v))
   ; run a verb in the caller under urun; () when no verb has the name
   (call k as) (get k @ f (lit? f ? (urun f as)))
   bn (cite 'path 'pbase)
   (dotl? w) (#w @ n (2 < n && snip w (n - 2) n = ".l"))
   (sl? w)   (: n #w (go i) (? (n <= i) 0 (w i = 47) 1 (go (i + 1))) (go 0))
   (word w)  (sl? w || dotl? w ? () (get (name w)))
   ; never for argv[0] `love`. a dash-led name (login(1)'s mark) finds the verb past the
   ; dash, which hears --login first when it says 'login
   (seat p)  (bn p @ b (dash b @ w
                (w = "love" ? ()
                   (get (name w) @ f
                      (lit? f && b != w && 1 = trait (name w) 'login ? (as \ f ("--login" . as)) f)))))
   ; a grid onto a terminal, one name a line into a pipe
   (vlist ks) (: ns (map string ks)
                 G (cite 'grid)
                 (two? (tty 1) ?
                    (each (G 'lay (map (n \ (n . #n)) ns) (G 'screen 1) 1)
                          (l \ (puts l, putc 10)))
                    (each ns (n \ (puts n, putc 10)))))
   ; sorted: a tablet's key order is unstable
   (vsort ws) (ws @- ws (p . s)
               (: r (vsort s)
                (ins x l) (l @- [x] (a . u) (string x < string a ? (x . l) (a . ins x u)))
                (ins p r)))
   _ (pin tab 'verbs
        (as \ (? (atom? as) (vlist (vsort (keys tab)), flush out)
                 (<as = "--help")
                  (puts "usage: verbs   (the names this artifact answers to)\n", flush out, 0)
                 (say err "verbs: unknown option \(<as)\n", flush err, 2))))

   ; --- the path lookup: a program run by path, `love src/apps/moon/moon.l foo.c` or a
   ; shebang's `-l`, finds its own entry when its basename is one of ws.
   ;   (fire ws)      -> (path . args-after) over this invocation's line, else ()
   ;   (seatof ws a)  the same over a list handed in
   ; a bake pins no `cmdline`, so there nothing matches. ask the answer with two?.
   (dash w)    (0 < #w && w 0 = 45 ? (snip w 1 #w) w)   ; -sh: login(1)'s mark
   (any? w (a . u)) (a = w || any? w u)
   (mine? ws w) (any? (dash (bn w)) ws)
   (seatof ws a) (? (atom? a) ()
                    (<a = "-l") (two? >a ?                     ; a preload named for me: the shebang's lane
                                 (mine? ws <>a ? (<>a . >>a) (seatof ws >>a)))
                    (mine? ws <a) (<a . >a))
   (fire ws)   (seatof ws (elem 'cmdline (names ()) ? >cmdline)))

) ; module verbs

; cli -- the console and command line: the repl and its multi-line editor, the stream shell
; (read/reads), the floor handler (welp), the port-driven line reader (edraw/edln/edlnc), and
; the host command line, read left to right after the program name:
;   (cli-rail ln)     the walk over ln = (program-name . args)
;   (cli-line ln tty) a frontend's whole tail: the argv[0] lookup, the rail, the repl, stdin
; a forked lush child calls cli-line too, in place of exec'ing this binary.

(module '(cli read reads forms shell welp edraw edln edlnc edlay cli-rail cli-line stage stage-run ttysize ttytake ttygive edkey edtap edgc
          uopt uopt1 uoptv uoptun uoptbad uoptstray uoptp uoptlast uask uvers love-build udoor edcmd edsgr edwide edcut edpad edfit sgr
          ednew edstep edput ednl edclear edempty? edchars edtext edcol edparses? edframe edload
          edleft edright edbsp eddel edhome edend edtop edbot edup eddown uphist downhist eddetach
          joinln splitat parseall)
(borrow 'text)
(: (read s) (sound (hot? s ? (flow s) s) @ (x . _) (ev 'ev x)))
; (ev 'ev a) late-binds: post is evaluated before the glaze rebinds ev (and LOVE_NO_GLAZE re-pins it)
(: (reads p)
   (: (walk cl z) (sound cl @ 'torn (scare 'unfinished-form p)
                              (a . b) (walk b (ev 'ev a))
                              z)
      ; for `in`, shared with the forms evaluated: gulp for speed, but hold nothing across an
      ; eval. box 0 counts every byte drawn off p, so the walk can put the port back.
      box {}
      (drew u) (peep box 0 0)
      (drop n) (unchug p (n - inhand p))     ; the port to n pending; we hold the rest
      ; flow, plus the count
      (feed u)
       (see p @ -1 () c
        (: _ (unsee p c)
           t (chug p)
           _ (pin box 0 (drew () + #t))
           (go k l) (0 >= k ? l (k - 1 @ j (go j (t j . l))))
         (go #t (once (u \ feed ())))))
      ; bytes consumed from a to b, by identity, forcing each step: tallying the lazy residue
      ; would force the whole rest
      (frc x) (lit? x ? (x ()) x)
      (upto a b n) (: aa (frc a) bb (frc b)
                      (? (aa = bb) n
                         (two? aa)   (upto >aa bb (n + 1))
                         n))
      (step cl walked z)
       (sound cl @
         'torn (scare 'unfinished-form p)
         (a . b) (: k (upto cl b 0)
                    w2 (walked + k)
                    rem (drew () - w2)
                    ; one byte short on purpose: the reader has read one ahead
                    _ (drop (0 < rem ? (rem - 1) 0))
                    h (inhand p)
                    v (ev 'ev a)
                    (h = inhand p ? (drop 0, step b w2 v)
                                    (start (two? b ? [<b]) v)))
         (drop 0, z))
      (start pre z)
       (see p @
        -1 (atom? pre ? z (walk pre z))
        c (unsee p c,
           inhand p ? (pin box 0 #pre, step (cat pre (feed ())) 0 z)
                      (walk (cat pre (trickle p)) z)))
      ; `in` folded at compile: a rebound `in` fails this in silence
      (p = in ? (start () 0) (walk (flow p) 0))))
(: (forms p)
   ((: (g cl acc) (sound cl @ 'torn (scare 'unfinished-form p)
                              (a . b) (g b (a . acc))
                              (rev acc)))
    (flow p) ()))

(: no (nom 0) eofsym (nom 0) edpasted {}   ; edpasted: a bracketed paste's bytes (edpaste)
   ; on when the terminal confirms mode ?2027 (grapheme clusters): the cursor then steps and
   ; deletes by cluster
   edgc {'on 0 'asked 0}

   ; a host binding, or () where it is absent (freestanding)
   (want n) (elem n (names ()) ? (ev n))
   raw (want 'raw)


   (parseall cl) (sounds cl @
    'torn no ; unfinished shape: more
    ((_ . ()) @ a) a                         ; one datum: as-is (leading monadic preserved)
    ((_ . _)  @ d) [d])           ; many: the application; a blank line: ()

   ; --- the editor: one buffer in a tablet, a zipper of charlists: 'u the lines above
   ; (reversed), 'l the cursor's left (reversed), 'r its right, 'd the lines below. each
   ; motion and edit takes the tablet and answers it.

   ; join charlists with newlines
   (joinln ls)
    (ls @ (a . b) (atom? b ? a (a + (10 . joinln b))))

   ; take n of xs onto acc, then (k acc rest); stops at the end of xs
   (splitat k acc n xs)
    (xs @- (k acc xs) ((ax . ux) && 0 < n) (splitat k (ax . acc) (n - 1) ux))

   ; the same by character: a utf-8 tail byte goes with the lead before it
   (splitc k acc n xs)
    (xs @- (k acc xs) ((ax . ux) && (0 < n || edtail? ax))
     (splitc k (ax . acc) (edtail? ax ? n (n - 1)) ux))

   ; a control prints as a space; a utf-8 byte passes
   (prc c) (putc (32 <= c < 127 || 127 < c ? c 32))

   ; the buffer holds bytes and the cursor moves by character
   (edtail? c) (128 <= c < 192)
   ; the columns a charlist of bytes takes: a control one, a character its wcwidth (a
   ; cluster's under edgc), a sequence still arriving at the end none
   (edpend? s i)
    (: n #s need (? (s i < 224) 2 (s i < 240) 3 4)
       (go k) (? (n <= k) 1 (edtail? (s k)) (go (k + 1)) ())
       (n - i < need && go (i + 1)))
   (edw cs)
    (: s (string cs) n #s
       (go i a) (n <= i ? a
                   (s i @ b
                      (? (b < 32 || b = 127) (go (i + 1) (a + 1))
                         (192 <= b && cpnext s i = i + 1 && edpend? s i) a
                         (edgc 'on) (go (gcnext s i) (a + gcwidth s i))
                         (b < 128) (go (i + 1) (a + 1))
                         (go (cpnext s i) (a + max 0 (wcwidth (cpat s i)))))))
       (go 0 0))
   ; the bytes the last cluster of l (backwards) and the first of r take, under edgc
   (edlast l) (: s (string (rev l)) n #s (go i) (gcnext s i @ j (n <= j ? (n - i) (go j))) (go 0))
   (edfirst r) (gcnext (string r) 0)

   (ednew _) {'u () 'l () 'r () 'd () 'ev 0}
   (edleft t) (: l (t 'l) u (t 'u) (?- t
    (two? l && edgc 'on) (edlast l @ k (pins t 'l (drop k l) 'r (revcat (take k l) (t 'r))))
    (two? l) (: (go l r) (<l @ c (edtail? c && two? >l ? (go >l (c . r)) [>l (c . r)]))
                p (go l (t 'r))
                (pins t 'l <p 'r <>p))
    (two? u) (pins t 'u >u 'l (rev <u) 'r () 'd (revcat l (t 'r) . t 'd))))
   (edright t) (: r (t 'r) d (t 'd) (?- t
    (two? r && edgc 'on) (edfirst r @ k (pins t 'l (revcat (take k r) (t 'l)) 'r (drop k r)))
    (two? r) (: (go l r) (two? r && edtail? <r ? (go (<r . l) >r) [l r])
                p (go (<r . t 'l) >r)
                (pins t 'l <p 'r <>p))
    (two? d) (pins t 'u (revcat (t 'l) r . t 'u) 'l () 'r <d 'd >d)))
   (edbsp t) (: l (t 'l) u (t 'u) (?- t
    (two? l && edgc 'on) (pin t 'l (drop (edlast l) l))
    (two? l) (: (go l) (two? >l && edtail? <l ? (go >l) >l) (pin t 'l (go l)))
    (two? u) (pins t 'u >u 'l (rev <u))))
   (eddel t) (: r (t 'r) d (t 'd) (?- t
    (two? r && edgc 'on) (pin t 'r (drop (edfirst r) r))
    (two? r) (: (go r) (two? r && edtail? <r ? (go >r) r) (pin t 'r (go >r)))
    (two? d) (pins t 'r <d 'd >d)))
   (edhome t) (pins t 'l () 'r (revcat (t 'l) (t 'r)))
   (edend t) (pins t 'l (revcat (t 'r) (t 'l)) 'r ())
   ; the start of the top line, the end of the bottom one
   (edtop t) (rev (t 'u) @- (edhome t) (au . uu) (pins t 'u () 'l () 'r au 'd (uu + (revcat (t 'l) (t 'r) . t 'd))))
   (edbot t) (rev (t 'd) @- (edend t)  (ad . ud) (pins t 'u (ud + (revcat (t 'l) (t 'r) . t 'u)) 'l (rev ad) 'r () 'd ()))
   ; up and down keep the column (in characters), clamped to the line
   (edn l) (foldl (a \ c \ edtail? c ? a (a + 1)) 0 l)
   (edup t) (t 'u @- t (au . uu) (splitc (\ lz rr (pins t 'u uu 'l lz 'r rr 'd (revcat (t 'l) (t 'r) . t 'd))) () (edn (t 'l)) au))
   (eddown t) (t 'd @- t (ad . ud) (splitc (\ lz rr (pins t 'u (revcat (t 'l) (t 'r) . t 'u) 'l lz 'r rr 'd ud)) () (edn (t 'l)) ad))
   (edput t c) (pin t 'l (c . t 'l))                       ; insert at the cursor
   (ednl t) (pins t 'u (rev (t 'l) . t 'u) 'l ())           ; break the line at the cursor
   ; pasted bytes at the cursor: cr, lf or crlf breaks the line, a tab stays, other controls go
   (edpin t l)
    (: (go l prev) (atom? l ? t
                      (<l @ c
                         ((? (c = 10 && prev = 13) 0
                             (c = 10 || c = 13) (ednl t)
                             (c = 9 || (32 <= c && c != 127)) (edput t c)
                             0),
                          go >l c)))
       (go l 0))
   (edclear t) (pins t 'u () 'l () 'r () 'd ())
   (edchars t) (joinln (revcat (t 'u) (revcat (t 'l) (t 'r) . t 'd)))   ; the whole buffer, one charlist
   edempty? (nil? * edchars)
   edtext (string * edchars)
   (edcol t) (edw (rev (t 'l)))                            ; the cursor's screen column
   edparses? (two? * parseall * edchars)
   (edframe t) (t 'u . t 'l . t 'r . t 'd)           ; the buffer packed for history
   (edload t f) (pins t 'u <f 'l <>f 'r <>>f 'd >>>f)

   ; --- history, on the same tablet: 'hu older frames, 'hd newer, 'cur a pristine recall,
   ; given back to 'hu on an edit so the original survives. a move pushes the buffer to the
   ; other side (unless empty); past the end, a parsing recall is pushed and a fresh line opens.
   (eddetach t) (atom? (t 'cur) ? t (pins t 'hu (t 'cur . t 'hu) 'cur ()))
   (uphist t) (t 'hu @ hu
                 (? (two? hu) (edempty? t ? () (pin t 'hd (edframe t . t 'hd)),
                               pins (edload t <hu) 'hu >hu 'cur <hu)
                    (two? (t 'cur) && edparses? t) (pin t 'hd (edframe t . t 'hd), pin (edclear t) 'cur ())
                    t))
   (downhist t) (t 'hd @ hd
                   (? (two? hd) (edempty? t ? () (pin t 'hu (edframe t . t 'hu)),
                                 pins (edload t <hd) 'hd >hd 'cur <hd)
                      (two? (t 'cur) && edparses? t) (pin t 'hu (edframe t . t 'hu), pin (edclear t) 'cur ())
                      t))

   ; --- one key into the buffer. a key the editor does not take -- enter (13 reads as 10),
   ; escape, tab, ^C, ^D, eof, up or down past the buffer -- is left in 'ev, else 'ev is 0
   (edstep t c)
    (: (took f) (pin (f t) 'ev 0)
       (edit f) (took (f * eddetach))
     (32 <= c < 127 || 127 < c < 256 ? (edit (b \ edput b c))   ; a utf-8 byte too
      (c @ -1 (took edleft)
           -2 (took edright)
           (127 || 8 || -3) (edit edbsp)
           -4 (edit eddel)
           (1 || -5) (took edhome)
           (5 || -6) (took edend)
           -10 (took edtop)
           -11 (took edbot)
           -13 (edit (b \ edpin b (peep edpasted () ())))
           (-8 && two? (t 'u)) (took edup)
           (-9 && two? (t 'd)) (took eddown)
           (pin t 'ev (c @ 13 10 c)))))

   ; --- a `:` prompt: the editor at key k of t takes c; enter calls (enter line), escape
   ; (esc ()), a tab is inserted, anything else answers t
   (edcmd t k c enter esc)
    (t k @ e
       (edstep e c,
        e 'ev @ 10 (enter (edtext e))
                27 (esc ())
                9 (edput e 9, t)
                t))

   ; --- the key reader: one key off port p, a byte as itself, -7 at eof. a bare escape (no
   ; tail within a beat) is 27, CSI keys the codes in the tables, alt-letter 256 + the letter;
   ; any other byte after an escape goes back. an unknown sequence is 0: test it with ==,
   ; since key codes are negative and truth cannot tell
   arrow    {68 -1 67 -2 65 -8 66 -9 72 -5 70 -6}    ; ESC [ F -- the plain finals
   modarrow {68 -1 67 -2 65 -8 66 -9 72 -10 70 -11}  ; ESC [ 1 ; M F -- modified home/end jump the buffer
   ; an sgr mouse report (ESC [ < b ; col ; row M, m on release): a press is key -12, its
   ; cell waiting in edtap, 0-based
   edtap-at {'x 0 'y 0}
   (edtap _) [(edtap-at 'x) (edtap-at 'y)]
   (ednum p a) (see p @ c (48 <= c <= 57 ? (ednum p (a * 10 + c - 48)) [a c]))
   (edmouse p) (: _ (ednum p 0)                     ; the button, which no app here reads
                  x (ednum p 0)
                  y (ednum p 0)
                  (pins edtap-at 'x (<x - 1) 'y (<y - 1),
                   <>y = 77 ? -12 0))               ; M is the press, m the release
   ; a bracketed paste (ESC [ 200 ~ .. ESC [ 201 ~) is the key -13, its bytes waiting in
   ; edpasted; any other ESC [ 2 is a miss
   (edpaste p) (: a (see p) b (see p) f (see p)
                  (!(a = 48 && b = 48 && f = 126) ? 0
                     (: (go acc) (see p @ c
                                    (c < 0 ? acc
                                       (c . acc @ q
                                          (c = 126 && [126 49 48 50 91 27] = take 6 q ? (drop 6 q) (go q)))))
                        (pin edpasted () (rev (go ())),
                         -13))))
   ; a DECRQM answer (ESC [ ? Ps ; Pm $ y) is a miss; ?2027 set (1 or 3) turns edgc on
   (edrqm p) (: m (ednum p 0) v (<>m = 59 ? (ednum p 0) [0 0])
                (<>v = 36 ? (see p) 0,
                 <m = 2027 && <>v = 36 ? (pin edgc 'on (<v = 1 || <v = 3 ? 1 0)) 0,
                 0))
   (edcsi p) (: c (see p) e (peep arrow c 0)
               (e != 0 ? e
                  (c @ 49 (see p @ 126 -5  59 (see p, peep modarrow (see p) 0)  0)
                       55 (see p, -5)
                       (52 || 56) (see p, -6)
                       51 (see p, -4)
                       60 (edmouse p)
                       50 (edpaste p)
                       63 (edrqm p)
                       0)))
   (edkey p) (see p @ c
                (? (c = -1) -7
                   (c != 27) c
                   !(rest 1, cue? p) 27
                   (see p @ c2
                      (? (c2 = 91) (edcsi p)
                         (c2 = 79) (peep arrow (see p) 0)    ; SS3: application cursor mode's arrows, home, end
                         (97 <= c2 <= 122) (256 + c2)
                         (c2 = -1) 27
                         (unsee p c2, 27)))))

   ; --- the tty, taken and given back
   ; its [rows cols], 24 and 80 where it says no more than rmin and cmin (a fresh pty says 0)
   (ttysize rmin cmin) (tty 1 @ ws [(two? ws && rmin < <ws ? <ws 24) (two? ws && cmin < <>ws ? <>ws 80)])
   ; raw, on the alternate screen, with modes: 'mouse (sgr reports), 'tap (a press alone,
   ; sgr), 'paste (bracketed), 'hide (the cursor), ('title t) (pushed, popped on the way out).
   ; ttygive undoes what ttytake set and shows the cursor
   (ttyon m) (m @ 'mouse "\e[?1000h\e[?1006h" 'tap "\e[?9h\e[?1006h" 'paste "\e[?2004h" 'hide "\e[?25l"
                  ('title t) ("\e[22;0t\e]2;\(t)\a") "")
   (ttyoff m) (m @ 'mouse "\e[?1003l\e[?1002l\e[?1000l\e[?1006l" 'tap "\e[?1006l\e[?9l" 'paste "\e[?2004l" ('title _) "\e[23;0t" "")
   (ttytake ms) (raw 1, say out ("\e[?1049h\e[2J" + catmap ttyon ms), flush out)
   (ttygive ms) (say out ("\e[0m" + catmap ttyoff (rev ms) + "\e[?25h\e[?1049l"), flush out, raw 0)

   ; --- the stage: a full-screen tty app as a tablet of functions
   ;   'show w h -> the frame for a w by h screen     'step k    a key
   ;   'over? _ -> 1 to leave                          'shut _    on the way out (optional)
   ;   'tick _ -> 1 when a frame is wanted, asked every 'every ms (33); without it a frame
   ;             follows each key and nothing runs between them
   ;   'modes   ttytake's
   ; eof leaves too, and the tty comes back whatever way the visit ends
   (stage-run d)
    (: ms (d 'modes) tk (d 'tick) per (peep d 'every 33)
       st {'over 0 'dirt 1 'size ()}
       (over? _) (st 'over || (d 'over?) ())
       (key c) (? (c = -7) (pin st 'over 1) (: _ (d 'step c) (pin st 'dirt 1)))
       (paint g) (: _ (pins st 'dirt 0 'size g) (say out (d 'show (g 1) <g), flush out))
       ; no tick: the frame, then a key, in turn
       (turns _) (: _ (paint (ttysize 7 19)) _ (key (edkey in)) (over? () ? 0 (turns ())))
       ; a tick: the keys on a task of their own, a frame when a key, the tick or the size says
       (keys _) (: _ (key (edkey in)) (over? () ? 0 (keys ())))
       (beats _) (: g (ttysize 7 19)
                    _ (? (st 'dirt || g != st 'size || tk ()) (paint g) 0)
                    (over? () ? 0 (: _ (rest per) (beats ()))))
       (visit _) (? !tk (turns ())
                    (: up (twirl keys 0) _ (beats ()) (landed? up ? 0 (freeze up))))
       (ttytake ms,
        mind visit () (_ \ ((peep d 'shut (_ \ 0)) (), ttygive ms)),
        0))
   ; show answers the frame for a screen w by h, step takes a key, over? says when to leave
   (stage show step over?) (stage-run {'show show 'step step 'over? over?})

   ; redraw in place: 'row keeps the cursor's row from the last render, and all motion is
   ; relative, so scrolling cannot desync. pl is the prompt's column, on the top line only.
   (csi n f) (putc 27, putc 91, putn n, putc f)   ; ESC [ n f -- the one cursor verb
   (edbelow t) (peep t 'below 0 @ n (0 < n ? (csi n 66) ()))   ; down past the buffer's rows
   ; on a screen w wide: [cursor row, cursor column, last character's row], from the buffer's
   ; first row. a line ending on the margin leaves the cursor pending, so n columns from s
   ; cover (s + n - 1) // w + 1 rows
   (edlay w pl u l r d)
     (: (rows s n) (0 < n ? ((s + n - 1) // w + 1) 1)
        (span top s) (atom? top ? 0 (rows s (edw <top) + span >top 0))
        above (span (rev u) pl)
        s0 (two? u ? 0 pl)
        k (s0 + edw (rev l))
        [(above + k // w) (k % w) (above + rows s0 (edw (revcat l r)) + span d 0 - 1)])
   ; one line, cursor at its end, and l the drawn one with one byte pushed (an identity test)
   (edgrew t)
     (t 'l @ l
        (!(t 'u) && !(t 'd) && !(t 'r) && two? l && >l == t 'was))
   ; a repaint puts the whole line out again, costing the line's length a keystroke --
   ; quadratic over a pasted run, and a seat painting that into a framebuffer looks hung -- so
   ; the one grown character is worth telling from the line. a character landing on the margin
   ; is followed by a newline, so the cursor stands where the layout says and not pending on
   ; the row above; a cursor past the last row gets its row by a newline the same way, the
   ; screen scrolling where a move would not
   (edrender pl t)
     (: ws (tty 1)
        w (two? ws && 19 < <>ws ? <>ws 80)
        u (t 'u) l (t 'l) r (t 'r) d (t 'd)
        pra (peep t 'row 0)
        grew (edgrew t)
        _ (pin t 'was l)
        lay (edlay w pl u l r d)
        crow <lay ccol <>lay erow (lay 2)
        (pins t 'row crow 'below (erow - crow),
         grew ? (prc <l, 0 = ccol ? (putc 10), flush out)
           ((0 < pra ? (csi pra 65),
             putc 13,
             0 < pl ? (csi pl 67),
             putc 27, putc 91, putc 74, ; clear to end of screen
             each (rev u) (ln \ (each ln prc, putc 10)),
             each (revcat l r) prc,
             each d (ln \ (putc 10, each ln prc)),
             putc 13),
            (crow > erow ? (putc 10, flush out)
             (crow < erow ? (csi (erow - crow) 65),
              0 < ccol ? (csi ccol 67),
              flush out)))))

   ; an sgr run at i -- ESC [ digits-and-semicolons m -- as its length, or 0 for no run
   (edsgr s i)
    (#s @ n
       (!(i + 1 < n && s i = 27 && s (i + 1) = 91) ? 0
          ((: (g k) (? (n <= k) 0
                       (s k = 109) (k + 1 - i)
                       (47 < s k < 58 || s k = 59) (g (k + 1))
                       0)) (i + 2))))

   ; a prompt's screen width: an sgr run none, an ascii byte one (a control too), any other
   ; character its wcwidth
   (edcw s i) (s i < 128 ? 1 (max 0 (wcwidth (cpat s i))))
   (edwide s)
    (: n #s
       (go i c) (n <= i ? c
                   (edsgr s i @ e
                      (e ? (go (i + e) c) (go (cpnext s i) (c + edcw s i)))))
       (go 0 0))

   ; the first n columns of s, a straddling wide character left out; a cut after an sgr run
   ; ends in a reset
   (edcut s n)
    (: m #s
       (cut i pen) (snip s 0 i + (pen ? "\e[0m" ""))
       (go i c pen)
        (m <= i ? s
           (edsgr s i @ e
              (e ? (n <= c ? (cut i pen) (go (i + e) c 1))
                 (c + edcw s i @ v
                    (n < v ? (cut i pen) (go (cpnext s i) v pen))))))
       (go 0 0 0))

   ; a field n columns wide: edpad fills with c, edfit cuts first so it is exactly n
   (edpad s n c) (edwide s @ w (w < n ? (s + ((n - w) (t \ t + c) "")) s))
   (edfit s n c) (edpad (edcut s n) n c)
   (sgr code s) "\e[\(code)m\(s)\e[0m"       ; s in the pen code, reset after

   ; --- the option walk, for kore's applets and love's own rail
   ; (uopt1 w flags vals) -- a short cluster into one word per letter, or () when not ours:
   ; `-qe X` is `-q -e X`. a letter in `vals` takes an argument and ends the chain, the rest
   ; of its word the value (-m4m). `flags` names the letters that chain, () any letter; a
   ; letter in neither set refuses the whole word.
   (uopt1 w flags vals)
    (: n #w
       ; `flags` as the bare predicate: !flags would glue to the arm behind it
       (ours? c) (? (elem c vals) 1 flags (elem c flags) 1)
       (go k acc)
        (n <= k ? (rev acc)
           (: c (w k)
              s "-\(string c)"
              g (snip w (k + 1) n)
              (? (elem c vals) (rev (#g ? (g . s . acc) (s . acc)))
                 (ours? c) (go (k + 1) (s . acc))
                 ())))
       (2 <= n && w 0 = 45 && !(w 1 = 45) ? (go 1 ()) ()))
   ; (uopt as t vals reps longs) -> [t stacked rest], or () when a value flag lacks its value
   ; (read it with two?). each flag pins 1 on t under its key, a value flag (1 v) so "" reads
   ; present; a key in `reps` stacks its values into `stacked` instead. `--` ends the flags.
   ; `longs` maps a long name, no dashes, to its key (so --width and -w are one option); a long
   ; name not in it, or --name=VALUE on a key not in `vals`, ends the flags as an operand.
   (uopt as t vals reps longs)
    (: (pinv c v es) (elem c reps ? (v . es) (pin t c [1 v], es))
       (lgot nm) (tablet? longs ? (longs nm))
       ; a flag word's key: a long name through the map, a short word's letter
       (ukey w) (w 1 = 45 ? (lgot (snip w 2 #w)) (w 1))
       ; a long word as uopt1's shape: the word, or the word and its glued `=` value
       (long1 a)
        (a @ ("--" + nm + "=" + v) (lgot nm @ c (c && elem c vals ? ["--\(nm)" v] ()))
             ("--" + nm) (lgot nm @ c (c ? [a] ())) )
       ; the exploded word, then the argv tail behind it. a value key ends its chain, so
       ; at most one element of `bs` is ever a value and it is the last.
       (eat bs rest es)
        (atom? bs ? (walk rest es)
           (: w <bs c (ukey w)
              (elem c vals ?
                 (? (two? >bs)  (walk rest (pinv c <>bs es))     ; the value rode along glued
                    (two? rest) (walk >rest (pinv c <rest es))   ; ..or it is the next word
                    ())                                          ; ..or there is none: a miss
                 (pin t c 1, eat >bs rest es))))
       (walk as es)
        (atom? as ? [t (rev es) ()]
           (<as @ a
              (? (a = "--") [t (rev es) >as]
                 (2 < #a && a 0 = 45 && a 1 = 45)
                  (long1 a @ bs (two? bs ? (eat bs >as es) [t (rev es) as]))
                 (uopt1 a () vals @ bs
                    (two? bs ? (eat bs >as es) [t (rev es) as])))))
       (walk as ()))
   ; a value option's text, or () -- the presence read that pairs with uopt
   (uoptv t c) (t c @ r (two? r ? <>r))
   ; the first pinned key (sorted) that `ok` does not name, or ()
   (uoptun t ok) (<(filter (c \ (nelem c ok)) (sort (keys t))))
   ; the same in typed order: `-ba` names b. a long key comes back as uoptun has it
   (uoptbad as t ok)
    (: bad (uoptun t ok)
       (word w k) (#w <= k ? () (w k @ c (t c && nelem c ok ? c (word w (k + 1)))))
       (go a) (atom? a ? bad
                 (<a @ w
                    (? (w = "--") bad
                       (1 < #w && w 0 = 45 && !(w 1 = 45)) (word w 1 @ c (c ? c (go >a)))
                       (go >a))))
       (bad ? (go as)))
   ; the first operand that looks like a flag, or (); () once `--` was spelled
   (uoptstray as rest) (elem "--" as ? () (<(filter (w \ 1 < #w && w 0 = 45) rest)))
   ; (uoptp as t vals reps longs) -> [t stacked operands stray] | (): uopt in gnu order, a flag
   ; free to follow an operand and every word behind `--` an operand. stray is the first long
   ; word that was not ours (uopt reads it as an operand), or ()
   (uoptp as t vals reps longs)
    (: (go as es ops stray)
        (uopt as t vals reps longs @ r
           (two? r ?
              (: es2 (es + r 1) rest (r 2) k (#as - #rest)
                 (? (atom? rest) [t es2 (rev ops) stray]
                    (0 < k && as (k - 1) = "--") [t es2 (rev ops + rest) stray]
                    (<rest @ w
                       (go >rest es2 (w . ops)
                           (stray || (2 < #w && w 0 = 45 && w 1 = 45 ? w ()))))))))
       (go as () () ()))
   ; the last of `keys` spelled before `--`, short or long, or (): for flags where the later wins
   (uoptlast as keys vals longs)
    (: (lkey w) (: e ((: (go i) (#w <= i || w i = 61 ? i (go (i + 1)))) 2)
                   (tablet? longs ? (longs (snip w 2 e))))
       (short w k got)                                   ; -> [got skip-the-next-word]
        (#w <= k ? [got 0]
           (w k @ c
              (elem c vals ? [got (k + 1 = #w ? 1 0)]
                 (short w (k + 1) (elem c keys ? c got)))))
       (go as got)
        (atom? as ? got
           (<as @ w
              (? (w = "--") got
                 (2 < #w && w 0 = 45 && w 1 = 45)
                  (lkey w @ c (go >as (elem c keys ? c got)))
                 (2 <= #w && w 0 = 45)
                  (short w 1 got @ r (go (r 1 ? >>as >as) <r))
                 (go >as got))))
       (go as ()))

   ; --- the two flags every applet answers, and the one place that answers them ------
   ; the leading flag words only: the walk stops at the first operand and at `--`, so a file
   ; really called --help still opens once something else has been named. not getopt -- a
   ; value word that looks like a flag is walked over, so `grep -e --help f` answers the help.
   (uask (w . u) h? v?)
    (w @ "--" ()
         "--help" 'help
         "--version" 'vers
         ("-h" && h?) 'help
         ("-v" && v?) 'vers
         (1 < #w && w 0 = 45 && uask u h? v?))
   ; an applet as the world calls it: nm is its name, u its usage text, and h?/v? whether the
   ; bare letters are free -- posix or gnu has spoken for one in a few places, and there the
   ; long form is the only answer. answers the main a verb registry takes.
   (uvers nm) "\(nm) / love \(love-version)"                           ; the --version answer, one spelling for every tool
   ; this build's name: the version and a short hash of the source it carries, off the
   ; carried tree's section crcs. same source, same name; no source, the version alone
   (love-build _)
    (tree-head 0 @ () "love \(love-version)"
       h "love \(love-version) \(snip (cite 'hashes 'sha256 (show (map (s \ [<s (s 2) (s 4)]) h))) 0 8)")
   (udoor nm f u h? v?)
    (: (say1 x) (: n #x                       ; a page that ends in a newline keeps just the one
                   (puts (n && x (n - 1) = 10 ? x "\(x)\n"), flush out, 0))
       (as \ (uask as h? v?
              @ 'help (say1 (u || "usage: \(nm)"))
                'vers (say1 (uvers nm))
                (f as))))

   ps1 "> "
   ; the helm glows in the crew's cyan (256-colour 117 ~ #7dcfff), reset after.
   ps1c "\e[38;5;117m\(ps1)\e[39m"

   ; prompt, then keys until ^D or a submitted buffer: eofsym on ^D, else [vs history]
   (edline hu hd)
     (: pl (edwide ps1c)
        _ (puts ps1c)
        t (pins (ednew ()) 'hu hu 'hd hd 'cur ())
        (loop _)
          (edrender pl t,
           edstep t (edkey in),
           (t 'ev @ 0 (loop ())
              ; ^D leaves the line ended, so whatever runs next starts on its own
              (-7 || 4) ((0 < t 'below ? (csi (t 'below) 66) ()), putc 10, eofsym)
              ; enter cashes the buffer as long as it parses complete
              10 (parseall (edchars t) @
                  ^no (ednl (eddetach t), loop ())
                  vs (: _ (eddetach t)
                        h (revcat (t 'hd) (t 'hu))
                        (0 < t 'below ? (csi (t 'below) 66) (),   ; past the rows below the cursor
                         putc 10,
                         [vs (!vs ? h (take 100 (edframe t . h)))])))
              -8 (uphist t, loop ())
              -9 (downhist t, loop ())
              3 (puts "^C\n", edempty? t ? eofsym (edline (t 'hu) (t 'hd)))
              (loop ())))
        (edbr loop))
   ; evaluate one datum on its own task, so ^C can stop it
   (do_eval v)
     (: pid (twirl (show * ev) v)              ; shown aboard: ^C stops a long print too
        (poll _)
          (? (landed? pid) ((catch pid @ s (string? s ? (puts s) (putx s))), -1)   ; the answer; a raise's ()
             (cue? 0) 
             (getc 0 @ 3 (puts "^C", freeze pid, -1) (poll ()))
             (rest 0, poll ()))
        (poll ()))

   (repl hu hd)
    (edline hu hd @ ^eofsym 0
                    (vs . nhu . nhd) (each vs (v \ (do_eval v, putc 10)), repl nhu nhd))

   (welp a b) ()

   ; a raise printed as ;; a b
   (hface a b) (say err ";; ", print err a, say err " ", print err b, put err 10)
   (shell-help a b) (hface a b, welp a b)
   ; the previous help goes back on the way out, or a later 'cli-leave would print as a raise
   (shell _)
    (: prev (heard ())
       _ (hear shell-help)        ; the prompt survives every raise; a script must not
       _ (raw 1)
       _ (puts ";3 love \(love-version)\n")
       r (repl 0 0)
       (hear prev,
        r))

   ; bracketed paste and grapheme clusters (?2027) only while a line is edited; the first
   ; line asks whether the terminal supports ?2027 (DECRQM)
   (edbr f) (: _ (puts (edgc 'asked ? "\e[?2004h\e[?2027h" "\e[?2004h\e[?2027h\e[?2027$p"), pin edgc 'asked 1)
               r (f ())
               ((puts "\e[?2004l\e[?2027l", flush out),
                r))
   ; (edraw ip pr) -- read one line off port `ip`, with in-line editing: the charlist, or eofsym
   (edraw ip pr) (:- (edbr loop)
    pl (puts pr, edwide pr) t (ednew ())
    (loop _) (edrender pl t,
              edstep t (edkey ip),
              t 'ev @- (loop ()) (-7 || 4) eofsym 10 (edbelow t, putc 10, edchars t)))

   ; back to the buffer's top row, cleared, prompt pr drawn again: its width
   (edreprompt t pr)
     ((0 < peep t 'row 0 ? (csi (t 'row) 65) ()),
      putc 13, putc 27, putc 91, putc 74,
      puts pr, pins t 'row 0 'was 0,
      edwide pr)

   ; the shell line reader: edraw + command history + tab completion + ^R search
   (edlnc ip pr hist comp)
     (: pl (puts pr, edwide pr) hn #hist t (ednew ())
        (hnth k) <(drop k hist)                       ; hist[k], 0-based (k < hn)
        (recall i ni draft)                           ; jump to view index ni (0 = the draft)
          (: nd (i = 0 ? (revcat (t 'l) (t 'r)) draft)  ; save the live draft once, the instant up leaves it
             (pins t 'l (rev (ni = 0 ? nd (hnth (ni - 1)))) 'r (),
              loop ni nd))
        (hfrom q k)                                   ; the first hist index from k holding q, or -1
          (: (go j h) (? (atom? h) -1 (0 <= findsub (string <h) q) j (go (j + 1) >h))
             (go k (drop k hist)))
        (rlabel q ok) ("(" + (ok ? "" "failed ") + "reverse-i-search)`" + q + "': ")
        ; ^R: fs the search's [query match found] frames, newest first, a backspace popping one.
        ; sv the line as it was, back on ^G; any other key takes the match and goes to the line
        (hunt i draft sv fs)
          (: q (<fs 0) j (<fs 1)
             _ (j < 0 ? (edload t sv)
                  (: h (hnth j) at (findsub (string h) q)
                     (pins t 'u () 'l (rev (take at h)) 'r (drop at h) 'd ())))
             _ (edrender (edreprompt t (rlabel q (<fs 2))) t)
             c (edkey ip)
             (more q2 k) (hfrom q2 k @ m (hunt i draft sv ([q2 (m < 0 ? j m) (0 <= m)] . fs)))
             (? (32 <= c < 127 || 127 < c < 256) (more (q + string c) (max j 0))
                (c = 18) (q = "" ? (hunt i draft sv fs) (more q (j + 1)))
                (c = 127 || c = 8) (hunt i draft sv (two? >fs ? >fs fs))
                (c = 7) (edload t sv, edreprompt t pr, loop i draft)
                (edreprompt t pr,
                 key (j < 0 ? i (j + 1)) (j < 0 || 0 < i ? draft (revcat (sv 1) (sv 2))) c)))
        (loop i draft) (edrender pl t, key i draft (edkey ip))
        (key i draft c)
          (edstep t c,
           (t 'ev @ 0 (loop i draft)
              (-7 || 4) 'eof
              10 (: ln (edbelow t, putc 10, edchars t)
                    nh (!ln ? hist (take 100 (ln . hist)))
                  (ln . nh))
              3 (puts "^C\n", () . hist)   ; ^C: abandon the line, hist untouched
              9 (!comp ? (loop i draft)
                   (comp (revcat (t 'l) ()) @ cl
                      (atom? cl ? (loop i draft)
                         (: _ (pin t 'l (foldl (a \ ch \ ch . a) (t 'l) <cl))
                            cs >cl
                          (two? cs && two? >cs ?
                            (edbelow t,
                             puts $ "\n" + foldl (a \ s \ 0 = #a ? s "\(a)  \(s)") "" cs + "\n",
                             pin t 'row 0, edreprompt t pr),   ; the list, then the prompt under it
                           loop i draft)))))
              18 (hunt i draft (edframe t) [["" -1 1]])
              -8 (recall i (i >= hn ? i (i + 1)) draft)   ; up: older
              -9 (recall i (0 >= i  ? i (i - 1)) draft)    ; down: newer
              (loop i draft)))
        (edbr (_ \ loop 0 ())))
   (edln ip pr hist) (edlnc ip pr hist ())
)


; the command line. a defglob evals a built (: nm 'v); without the quote ev would run the
; value as a form. every leave scares 'cli-leave, and the trap answers its charm for the
; frontend to quit with; nothing here quits. the handler is written twice, for the two spans
; `pre` and `run` with the defglob between them.
(: (cli-rail ln)
 (: (charm0 x) (charm? x ? x 0)
    ; a program's own uleave ('leave, udie's) goes out the same door
    (door a b) (a @ ('cli-leave || 'leave) (charm0 b) (scare a b))
    cli2
 (trap (x \
            (: (cli-leave c) (scare 'cli-leave c)
               ; hot?, not truth: a refused open answers a nom, which is truthy
               (load1 p) (cite 'posix 'open p "r" @ q
                            (hot? q ? (reads q) (say err "love: cannot open \(p)\n", cli-leave 1)))
               (eval1 s) (sounds s @ 'torn (say err "love: -e: unfinished form\n", cli-leave 2)
                                    (d @ (a . u)) (ev 'ev (atom? u ? a d)))   ; many datums fold to one application
               v-msg "\(love-build 0)\n"
               h-msg
               """
               usage: love [wake IMAGE] [-l FILE] [-e EXPR] [-q] [-m SIZE] [-v] [-h] [--] [VERB|FILE] [ARG ...]
                 -l, --load FILE   preload FILE (read-eval) before the program
                 -e, --eval EXPR   eval EXPR as one expression (infix works), print the answer
                 -q, --quiet       with -e: do not print the answer
                 -m  --memory N    max heap in {k,m,g} default = 0m = unlimited
                 -v, --version     print the version
                 -h, --help        print this help
                 --                end of options; the rest are files, and none of them is stdin
               the short flags cluster -- `-qe EXPR` is `-q -e EXPR` -- and a letter taking an
               argument ends the chain, on the rest of its word (-m8m) or the next one
               with no arguments then start a repl if on a tty else eval expressions from stdin
               try `love verbs` to see a list of commands

               """
               (need h '()) (say err "love: \(h) needs an argument\n", cli-leave 2)
               K 1024 M 1048576 G 1073741824
               wordsz (charm? G ? 8 4)             ; 2^30 is a charm only where a fixnum is 62-bit
               ; validate here: `tune` refuses a bad value in silence. 0 is unbounded, so it is allowed
               (size h s) (: n #s
                             u (peep s (n - 1) 0 @ (107 || 75) K
                                                   (109 || 77) M
                                                   (103 || 71) G)
                             d (u && snip s 0 (n - 1) || s)
                             v <(sound d)
                             (charm? v && v >= 0 ?
                              (v * (u || M) // wordsz)
                              (say err "love: \(h): not a size: \(s)\n",
                               cli-leave 2)))
               ; -> (kind . rest): 'eval code.args / 'evalq / 'verb fn.args / 'file prog.args /
               ; 'stdin / 'none, the line running out with no program (-v and -h do not end it)
               (pre a) (a @ (h . t)
                 (uopt1 h "vhq" "lem" @ bs
                    (two? >bs ? (pre (bs + t))
                     (h @ ("-l" || "--load")    (need h t, load1 <t, pre >t)
                          ("-v" || "--version") (puts v-msg, pre t)
                          ("-h" || "--help")    (puts h-msg, pre t)
                          ("-e" || "--eval")    (need h t, 'eval . t)
                          ("-q" || "--quiet")   (pre t @ ('eval . r) ('evalq . r) r r)
                          ; tune's slot 0, the last -m winning; it lands at the next collection
                          ("-m" || "--memory")  (need h t, tune (pin (tune ()) 0 (size h <t)), pre >t)
                          "--"                 (t @ (_ . _) ('file . t) '(stdin))
                          (cite 'verbs 'word h @ '() ('file . a) f ('verb . f . a)))))
                 '(none))
               ; stdin for an empty line or a bare `--`, never for flags with no program
               p (two? >ln ? (pre >ln) '(stdin))   ; runs -l preloads + -v/-h + -m; the program kind
               k <p
               av (k @ ('eval || 'evalq || 'verb) >>p >p)   ; the program's view of argv
               run (_ \
                        (k @ 'eval  (puts * show $ eval1 <>p, putc 10, 0)  ; shown, not dot's raw face
                             'evalq (eval1 <>p, 0)
                             'verb  (: r (<>p >>>p)     ; the args after its name -> a status
                                       (cli-leave $ charm0 r))
                             'file  (load1 <>p, 0)
                             'none  0
                             (reads in, 0)))
               [av run]))
       () door)
 (charm? cli2 ? cli2                  ; a leave in pre: the status is the answer
    (ev [': 'argv ['\ <cli2]], ; the program's argv, before the run
     trap (x \ <>cli2 ())
      () door)))

 (cli-line ln tty)
   (: (charm0 x) (charm? x ? x 0)
      V  (cite 'verbs)
      _  (ev [': 'cmdline ['\ ln] 'argv ['\ ln] ])   ; C's line is already past the primes
      f  (V 'seat <ln)
      (charm0 (? f          (trap (_ \ (f >ln)) () (\ a b (a @ 'leave (charm0 b) (scare a b))))
                 (two? >ln) (cli-rail ln)
                 tty        (shell 0)
                 (reads in, 0))))         ; non-tty stdin: the stream face drinks the in port

 ; `love` is a verb too, so a shell with nothing to exec reaches the repl by name
 _ (cite 'verbs 'enlist 'love
     (as \ (two? as ? (cli-rail ("love" . as)) (shell 0)))
     [('exec . (as \ (two? as && (<as = "bake" || <as = "wake"))))]))
) ; module cli
