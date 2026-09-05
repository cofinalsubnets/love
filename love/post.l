
; post -- the third egg stage. prel and ev are sat twice (ev compiles itself);
; post is sat once, on the hatchling, after that and before the mop. it is the
; one seat that sees both the finished compiler and the runtime-internal noms
; (peek seek atype, and lamsrc/nifnom below) the mop is about to take off the book -- a
; reference compiled here folds to a value and survives, the way ev's own
; `feels` does. so: love that needs to read the heap raw belongs here.
;
; what lives here is the printer. it is the reader's mirror image: p0 is a floor
; in C and p1 the real thing in love, and the printer splits the same way -- the
; floor is love.c's facex (the scare face, which runs when the VM has stopped and
; there is nobody left to call), the grammar is all below. `print` `dot` `show`
; `putx` and the `.` sigil are pinned at the foot; prel leaves those four holes
; for us, because a nif folded into prel's own compile could never be replaced.


; --- lowered from prel: nothing in the egg reads these, so they are sat once, here ---
(: pi 3.141592653589793
   tau (2 * pi)
   true 1 false 0
   (caaap x) <<<x (caaup x) <<>x
   (cauap x) <><x (cauup x) <>>x
   (cuaap x) ><<x (cuaup x) ><>x
   (cuuap x) >><x
   stdin in stdout out stderr err
   sine sin cosine cos tangent tan fabs abs
   star-tray (tray 0) gem-tray (tray 0.0) twin-tray (tray (twin 0 0)) top-tray (tray ())  ; the four typed-tray ctors (witness baked in)
   (tier v) (tray? v ? (: c (atype v) (? (c = 0) star-tray (c = 1) gem-tray (c = 2) twin-tray top-tray)))  ; a tray's tier is its ctor; nil off a tray
   zero? nil?
   ; use: splice a registered module just below the head, so its names resolve on the walk but
   ; never shadow yours. a missing name scares -- a silent ()-splice would be a silent no-op.
   (use m)    (: b (tablet? m ? m
                    (: r (mods () m) (? r r (scare 'no-module m))))
               (setbooks (<(books ()) . b . >(books ()))))
   ; from: a module is its tablet. currying reaches a member because a tablet already indexes
   ; itself, so (from 'holo 'assemble) reads the same as ever; `keys` is the ordinary function,
   ; not a reserved key; (from ()) lists the registry; a missing module answers ().
   ; the tablet is the real one -- pin it and you are doing surgery on a live runtime, which is
   ; yours to do. it was never a safety wrapper: a module's members are folded into its consumers
   ; at their compile, so gutting one changes nothing already compiled and everything compiled
   ; after -- the hazard is divergence, and no closure here could have caught it.
   (from k)   (? k (mods () k) (keys (mods ()))))

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

(: (merge le a b) (? (one? a) b (one? b) a
                     (le <a <b) (<a . merge le >a b)
                     (<b . merge le a >b))
   (sortby le l) (? (one? l) l (one? >l) l
                  (: s (sortsplit l) (merge le (sortby le <s) (sortby le >s)))))

(: ; the macro twin: each layer keeps its table at its nil key, so this walks the chain `macros`
   ; looks up through. same placement rule as `names`, and its `books` folds at compile time.
   (macro-names _) (filter nom? (keys (foldl (\ t k (pin t k 1)) {}
                                             (catmap (\ b (: m (b 0)
                                                             (tablet? m ? (keys m))))
                                                     (books ())))))
   (part p) (foldr (\ a m (p a ? ((a . <m) . >m)
                                 (<m . a . >m))) '(())))

; the port head is three words -- ap, vt, ungetc -- and both languages know it: love.h declares
; it, these build it. each poke answers the cell it wrote, so `poke -1` walks backwards. the vt
; is the port's whole kind, so these stamp the one they mean; C hands the address over as ci-vt
; and to-vt, the way it hands over lvm_quote, and the egg mops both noms.
(: (tap cl)
 (poke -1 (peek 0 in) (poke -1 ci-vt (poke -1 -1 (poke 3 cl (spin 4)))))
 (jug _)                                          ; the output dual of `tap`: say into it, slurp it back out
  ; the backing starts empty, and that is the whole isolation: a literal here is
  ; one string every jug would share, and to_writen fills a backing in place -- two
  ; live jugs then write over each other until the first one grows.
  (poke -1 (peek 0 in) (poke -1 to-vt (poke -1 -1 (poke -1 "" (poke 4 0 (spin 5))))))
 ; hot? names the zoo (a buf or a port), the head's ap word the species -- the recognition C's iop
 ; does. hot? goes first so the peek only ever lands on a heap cell.
 (port? o) (? (hot? o) (id? (peek 0 o) (peek 0 in)) 0)   ; the else arm is the bit: a two-armed ? answers the zero point
 ; drain a vessel to a value: a jug reads its backing buffer, everything else a gulp at a time.
 ; the drain accumulates, it does not recurse -- a recursion's stack depth is the gulp count, and
 ; on a parking port every task switch copies that stack.
 ; `see` is what makes the loop terminate: it is the one door that touches the device (chug
 ; never does), so every turn either lands its byte in the jug or reads the end. the byte goes
 ; to the jug rather than back to the vessel because a raw fd holds no pushback of its own.
 (slurp o) (? (? (port? o) (id? to-vt (peek 1 o))) (snip (peek 3 o) 0 (peek 4 o))   ; a jug by its vt: a buffered fd port's word 3 is a string too
              (: j (jug 0)
                 (go u) (: c (see o) (? (= c -1) (slurp j)
                                        (: _ (put j c) _ (say j (chug o)) (go ()))))
                 (go ())))
 ; the promise, through a tablet -- the mutation door this tree sanctions. the answer is wrapped
 ; (1 v) and read with two?: a promise of nothing is ordinary (eof gives ()), and a bare pin would
 ; leave the slot reading like an unforced one, so f would re-run forever.
 (once f) (: t (tablet 0) (\ u (: v (t 0) (two? v ? >v (: w (f ()) _ (pin t 0 (1 . w)) w)))))
 ; a port is a charlist: the run just gulped is realized, the tail a promise for the next.
 ; the tail must be a `once` -- p1 forces a position twice, and a re-drinking tail would lose the
 ; bytes between. one chug per gulp, and the run is whatever the port has in hand; the `see` is
 ; what refills, since chug never touches the device.
 (flow p) (: (gulp tl) (: c (see p)
                          (? (= c -1) tl
                             (: t (unsee p c, chug p)
                                (go k l) (? (0 >= k) l (: j (k - 1) (go j (link (t j) l))))
                                (go #t tl))))
             c (see p)
             (c != -1 ? (unsee p c, gulp (once (_ \ flow p)))))
 ; flow at one byte per force, for taking a port slowly where a whole run would read too far
 ; ahead. `in` already flows that way: it holds nothing in hand -- and still holds nothing
 ; where the device gulps behind it (chug asks the port, which is the static, not the run
 ; borrowed under it), so this stays the only door that reads stdin exactly.
 (trickle p) (: c (see p) (c != -1 ? (c . once (_ \ trickle p)))))

(:: '>>= (\ l (link (last l) (init l))))
(:: '<=< (\ g (: y (nom 0) ['\ y (foldr (\ f x [f x]) y g)])))
(: pow ** power ** car cap cdr cup cons .)

; --- the loader: use on a path ------------------------------------------------
; the `use` up top splices a module the runtime already holds; here it also loads one
; from a PATH the caller writes out. the loader invents no path of its own, so a NAME
; it lacks is a miss and the splice raises by name: what a frontend baked, and what a
; cat registered, is the whole of what a name can mean.
; a load is one fresh layer: enter, read-eval, leave registers it under the file's
; basename -- and a file that made its own (module nm ..) keeps that registration, the
; wrapper going out with the name it never wrote to.
; the same path twice reads once, and the PATH is what marks it: a basename cannot,
; because several files register one module (sb's parts, lush's, tls's) and a name-keyed
; mark would drop every part after the first. it also reads what it is pointed at -- a
; tree's own file over a baked older copy of it, which is what papel's want asks for.
; `open` is captured by peep, so a fs-less frontend holds () there and every path misses.
(: use
   (: prior use
      ; read-eval every form of a module source; a torn form scares.
      ; `flow`, never `slurp`: slurp conses the bytes, reverses, re-strings, and sound would cons
      ; them again -- four copies of the module.
      (rdev q) ((: (go cl) (: r (sound cl)
                              (? (two? r) (ev <r, go >r)
                                 (id? r 'torn) (scare 'unfinished-form q)
                                 0)))
                (flow q))
      ; a layer holding no nom of its own is not a module: the file wrapped itself in a
      ; (module nm ..) and registered elsewhere. the charm keys (0 the macros, 31337 the
      ; parent chain) sit in every layer and are not noms.
      (bare? t) ((: (go ks) (two? ks ? (nom? <ks ? 0 (go >ks)) 1)) (keys t))
      (mname s) (: n #s
                   b ((: (go k r) (k >= n ? r (go (k + 1) (? (47 = peep s k 0) (k + 1) r)))) 0 0)
                   e (? (2 < n - b ? (".l" = snip s (n - 2) n) 0) (n - 2) n)
                   (intern (snip s b e)))
      fsopen (peep book 'open ())      ; the host's open nif, by peep -- see above
      (\ m (? (tablet? m) (prior m)
              (string? m)
              (: nm (mname m)
                 (? (peep (mods ()) m ()) (prior nm)          ; read already -- the path is the mark
                    (: q (? !fsopen () (fsopen m "r"))
                       (? !(hot? q) (prior m)
                          ; a file whose own (module nm ..) registered wins: keep its tablet
                          ; over the loader's wrapper layer, which leave would pin over it.
                          ; the mark goes down before the read, so a file naming itself stops.
                          ; t is read after the eval, so it holds either claim on the name --
                          ; the file's, or a module that already stood there. a bare wrapper
                          ; with neither is no module: pull the name and answer ().
                          (: _ (pin (mods ()) m 1)
                             _ (enter nm) _ (rdev q) t (mods () nm) w (leave ())
                             _ (t && pin (mods ()) nm t)
                             (!t && bare? w ? (pull (mods ()) nm 0, ()) (prior nm)))))))
              (prior m)))))

; a module's macros in the head layer, without its names. a macro rides its own
; layer's table, which `macros` walks, so a consumer reaching a module through
; `from` rather than a splice has no other way to spell one. ks names them, ()
; takes the lot; a macro table is a module's key 0, the one the export prune keeps.
(: (hoist m ks)
   (: M (from m 0)
      (? (tablet? M)
         (each (two? ks ? ks (keys M)) (\ k (: v (M k) (v && :: k v)))))))

(: (chars s) (map s ^#s)                      ; a string is an atom, so map needs the indices
   (findsub s sub) (#sub = 0 ? 0 (fsub s sub 0))        ; -1 when absent
   (has? s sub)    (0 <= findsub s sub)
   (starts? s p)   (#p <= #s && snip s 0 #p = p ? 1 0)          ; a ?-name owes a bit, and && gives ()
   (ends? s p)     (#p <= #s && snip s (#s - #p) #s = p ? 1 0)
   (replace s from to) (#from = 0 ? s (join to (split from s)))
   (ws? c)  (c = 32 || c = 9 || c = 10 || c = 13 ? 1 0)
   (lstrip s) (: (go i) (i < #s && ws? (s i) ? (go (i + 1)) i) (snip s (go 0) #s))
   (rstrip s) (: (go j) (0 < j && ws? (s (j - 1)) ? (go (j - 1)) j) (snip s 0 (go #s)))
   (strip s)  (lstrip (rstrip s))       ; not `trim`: that name is ev.l's port op, mopped by egg.l
   (lines s) (split "\n" (#s && s (#s - 1) = 10 ? (snip s 0 (#s - 1)) s))
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
   (cats ls) (foldr (+) () ls)                          ; the band-general fold: net is its number case
   (uniq l)  (: (go seen l) (? (one? l) () (peep seen <l 0) (go seen >l)
                              (<l . go (pin seen <l 1) >l))
                (go (tablet 0) l))
   (count p l) (foldl (\ a x (p x ? (a + 1) a)) 0 l))

; --- assert / suite: the strict checkers, baked so they work with no harness ---
;;; FIXME how are these used at the moment?
(:: 'assert (\ l (. 'do (map (\ e (list '? e 0 (list 'scare (list '\ 'assert) (list '\ e)))) l))))

(:: 'suite (\ l (. 'do (. (. 'assert (cup l)) (list (list 'puts (cap l)) (list 'puts ": ok\n"))))))

(: (array s) (: sh (a-shape s) (a-coll sh (foldl (*) 1 sh) 0)))

; --- coin: a kind of the coin row -- a table of what its values answer to, keyed by the
; noms the C side reads (love.h's Kn rows): name + * ap hot - net star /, net one of
; payload tally ratio. (coin 'nm spec) registers the kind and answers its constructor; spec
; is a tablet, or a function of the constructor when a method strikes its own kind:
; (z \ {'+ ..}). a method takes both operands raw; (lift z f) lowers them and re-strikes
; f's answer. the registry orders kinds by registration, which is their order under sort;
; (kinds ()) lists the names in that order, (kinds 'nm) answers the table.
(: (coin nm spec)
    (: t {'name nm} z (strike t)
       s (tablet? spec ? spec (nil? spec ? () (spec z)))
       _ (tablet? s ? (foldl (\ t k (pin t k (s k))) t (keys s)) 0)
       r (kreg 0) e (r nm)
       _ (pin r nm ((two? e ? <e #(keys r)) . t))   ; a re-registration keeps its serial
       z)
   (kinds k) (name? k ? (: e (kreg 0 k) (two? e ? >e ()))
                        (: r (kreg 0) (map (\ p <>p) (sort (map (\ n [<(r n) n]) (keys r))))))
   (lift z f) (\ a b (z (f (load a) (load b)))))

;;; FIXME help/io setters below here. redesign the API with more structure
; binary?: does f take exactly two operands? read two ways -- the arity off the n-ary closure
; marker, else the param count off the source a compiled lambda stashes. one-sided on purpose:
; a shape neither reads (a nif, a partial) passes.
; the marker is read off a known binary rather than named: `peek`'s nom dies at the hatch but
; the folded reference lives. and it must be lvm_cur -- the ap table has it. binding lvm_ret0
; the same way (to catch a one-armed nif) segfaults the image bake, so the nif case stays open.
(: hcur (peek 0 (\ a b a))
   (binary? f) (? (charm? f) 0                      ; a charm is no handler at all
                  (id? hcur (peek 0 f)) (2 = peek 1 f)
                  (: s (lamsrc f) (? (two? s) (4 = #s) 1)))
   (hear f) (? !f (seal-hook 5 f)                   ; every nothing uninstalls
               (binary? f) (seal-hook 5 f)
               (scare 'help-arity f)))

; the stdio door, the help's twin: (wear (i o e)) re-seats in/out/err for this task,
(: (wear l) (seal-hook 6 l))

; trap -- (f x) under a help that escapes: the value on a clean run, (n a b) when a
; scare landed here.
; all three operands, always: two hand back a closure, which is truthy, and f never runs at
; all. n's own arity is checked (binary?) before f runs -- so the refusal lands under the
; ambient help, not inside the raise this form exists to catch.
; nothing unwinds: the escape jumps past every pending restore between the raise and here, so
; a cleanup belongs in n, never inside f -- or in `mind`'s c, which is the same cleanup owned by
; the resource instead of by the catcher.
(: (trap f x n)
     (: _ (? (binary? n) 0 (scare 'help-arity n))   ; refuse before f runs, under the ambient help
        prev (heard ())
        home (myself ())
        r (call-cc (\ k (: _ (hear (\ a b (? (id? (myself ()) home) (k (\ _ (n a b)))
                                             (: _ (hear prev) (scare a b)))))
                           v (f x)
                           (\ _ v))))
        _ (hear prev)
        (r ())))

; mind -- (f x) with c minded on the way out: c fires exactly once, clean or raised, the
; condition rides on to the help outside, and the answer is f's. so a helper holds its own
; port or its own restore, however far under a catcher it sits.
; the n hands back a marked condition rather than re-raising in place, so the one (c ())
; below serves both paths -- re-raise inside the n and a help that answers (the shell's
; default, welp, any plain (hear f)) returns through it and the tail fires c a second time.
; `mark` is minted once and closure-private, so no value f answers can pose as the raise.
; all three operands, like trap, and c is a thunk fired with the unit.
; raises only: a scare is what reaches a help, so a bare (k v) into a continuation
; captured outside jumps clean past every c between there and here.
; c runs with the displaced help back, so its own raise belongs to the trap outside --
; and replaces the condition c was firing for, which is the one way out of a lost raise.
(: mind (: mark (mint 0)
           (\ f x c
              (: r (trap f x (\ a b (mark . [a b])))
                 _ (c ())
                 (? (two? r && id? <r mark) (scare <>r <>>r) r)))))

; the ISA vocabulary, and it is one word per machine: 'x64 'a64 'rv64, with the
; embedded targets keeping theirs. Every other spelling anyone says -- a -t flag, a `seed`
; argument, uname's answer, a gnu triple's head -- comes through `archof` and leaves
; canonical, so nothing downstream normalizes a second time.
; here because no crew file sits under all the readers: moon, holo, kore, source, forge
; and sat share only the prel, which is also where love-arch is pinned.
(: arch-canon {'x64 'x64  'amd64 'x64  'x86_64 'x64  'x86-64 'x64
               'a64 'a64  'arm64 'a64  'aarch64 'a64
               'rv64 'rv64  'riscv 'rv64  'riscv64 'rv64
               'thumb1 'thumb1  'cortex-m0 'thumb1
               'thumb2 'thumb2  'cortex-m7 'thumb2
               'thumb2sp 'thumb2sp  'playdate 'thumb2sp}
   ; the word the world outside says: uname's machine, and the head of a gnu triple. the
   ; embedded targets answer () -- no kernel is ever asked their name.
   arch-uname {'x64 "x86_64" 'a64 "aarch64" 'rv64 "riscv64"}
   ; any spelling -> the canonical nom, () for one nobody here knows. takes a nom or a
   ; string, since a flag arrives as text where a table key is a nom.
   archof (arch-canon * name)
   ; the total face: a spelling nobody here knows rides through as its own nom, so
   ; whoever refuses it names what it was handed
   (arch-nom s) (: s (name s) (peep arch-canon s s))
   arch-mach arch-uname)

(: car cap cdr cup cons link
   caar caap cadr caup cdar cuap cddr cuup
   caaar caaap caadr caaup cadar cauap caddr cauup
   cdaar cuaap cdadr cuaup cddar cuuap cdddr cuuup
   eq? id? length tally pair? two? atom atom? identity id
   reverse rev append + constantly const ceiling ceil
   fold-left foldl fold-right foldr append-map catmap flat-map catmap
   every all some any delete-duplicates uniq butlast init
   (for-each f l) (each l f)                     ; scheme takes the function first
   ; the -q trio walks by identity and answers what it found, () for a miss --
   ; `member?`/`assoc` above stay love's, a bit and a pair by `=`.
   (memq x l)   (? (two? l) (? (id? x (cap l)) l (memq x (cup l))))
   (member x l) (? (two? l) (? (= x (cap l)) l (member x (cup l)))))

(: px (:
  ; every eager binding sits in this outer `:`. where boxfix engages (any forward
  ; or self reference -- the printer below is one), a sibling bound to an unfoldable
  ; call is boxed too and its cell never filled, so every read of it raises `missing`:
  ;   (: f (: (a o) (f o) c (tablet 0) (\ o c)))   -> ;; missing c
  cur (peek 0 (+)) ret0 (peek 1 cap) unc (peek 0 (+ 1))
  ; the float width is the seat's, never this file's: love.c gives a 32-bit seat
  ; (wasm, mps2, teensy41, playdate, rp2040) binary32 for ai_flo_t. so ask the
  ; arithmetic instead of spelling binary64's numbers -- a hard-coded 2^53 sends
  ; norm's doubling loop past every float32 there is and it never returns.
  p53 (: (go m) (? (m = (1.0 + m)) m (go (m * 2.0))) (go 1.0))   ; where +1 is lost = 2^mantissa
  p52 (p53 / 2.0)
  emin (: (go v e) (: h (v / 2.0) (? (h = 0) e (go h (e - 1)))) (go 1.0 0))   ; the denormal floor
  inf (1.0 / 0.0)
 (:

  ; --- integers: the digits of a non-negative charm/sun/big, most significant first
  (dch n a) (: q (n // 10) d (48 + (n - (q * 10))) (? (0 < q) (dch q (d >< a)) (d >< a)))
  (dstr n) (string (dch n ()))
  (ndig n) (: q (n // 10) (? (0 < q) (1 + (ndig q)) 1))          ; the count, without building the list
  (pnum o n) (? (n < 0) (: _ (put o 45) (say o (dstr (0 - n)))) (say o (dstr n)))

  ; --- text ---
  (hexd d) (? (d < 10) (48 + d) (87 + d))
  ; post compiles before any layer is spliced, so `@` has to be in the book already --
  ; it is, from the half of this file above. an unaccompanied `@` folds to a plain
  ; application and a run of charms church-towers into an apcap naming no seat.
  (esc o c)
   (c @ (92 || 34) (put o 92, put o c)
        10 (say o "\\n")   9  (say o "\\t")
        13 (say o "\\r")   27 (say o "\\e")
        0  (say o "\\0")
        (c >= 32 ? (put o c)
                   (say o "\\x", put o (hexd (c // 16)),
                    put o (hexd (c - (16 * (c // 16)))))))
  (pstr o s) (: n (tally s)
                (go i) (? (i < n) (: _ (esc o (peep s i 0)) (go (1 + i))) 0)
                _ (put o 34) _ (go 0) (put o 34))

  ; --- gems: the shortest roundtrip, exact steele & white. C had to carry digit
  ; arrays and its own x2/x5 carry walks; here 4m and the midpoints 4m±2 are
  ; bignums at one shared scale and `//` does the rest.
  ; v = m*2^e exactly, m an integer, normalized into [p52,p53) -- but never past the
  ; denormal floor, where the true spacing stops halving and one more step would hand
  ; the search an interval far too narrow.
  (norm m e) (? (p53 <= m) (norm (m / 2.0) (1 + e))
                (m < p52 && emin < e) (norm (m * 2.0) (e - 1))
                (int m >< e))
  ; inside the rounding interval? a midpoint counts only for an even mantissa --
  ; round-to-nearest-even is what reads it back.
  (fits c lo hi evn) ((lo < c ? 1 (evn && c = lo)) &&
                      (c < hi ? 1 (evn && c = hi)))
  ; the fewest digits whose rounded form sits inside: pk is the place being cut,
  ; walking down by ten a step, and at each one try the truncation and the bump,
  ; the nearer first (a display nicety). at pk = 1 it terminates, dv itself being
  ; inside by construction.
  (pick dv lo hi evn pk) (? (pk < 1) dv
    (: t ((dv // pk) * pk)
       up (1 < pk && 5 <= (dv // (pk // 10) - (10 * (dv // pk))))
       c1 (? up (t + pk) t) c2 (? up t (t + pk))
       (? (fits c1 lo hi evn) c1 (fits c2 lo hi evn) c2 (pick dv lo hi evn (pk // 10)))))
  ; strip trailing zeros, keeping one digit
  (strip n) (: q (n // 10) (0 < q && (n - (q * 10)) = 0 ? (strip q) n))
  (zeros o n) (0 < n ? (put o 48, zeros o (n - 1)) 0)
  (pgem2 o a) (: me (norm a 0) m <me e2 >me sh (e2 - 2)
    up (sh < 0 ? (5 ** -sh) (2 ** sh))   ; one shared scale: 2^sh, or 5^-sh with the point moved
    flo (m = p52 && emin < e2)                ; at a binade floor the gap below is already half
    dv (4 * m * up)
    dlo ((4 * m - (flo ? 1 2)) * up)
    dhi ((4 * m + 2) * up)
    evn (m = 2 * (m // 2))
    dc (pick dv dlo dhi evn (** 10 ((ndig dv) - 1)))
    lead (ndig dc)
    ss (dstr (strip dc)) sig (tally ss)
    dxp (lead + (sh < 0 ? sh 0))
    (? (1e16 <= a || a < 1e-4)
       (: e (dxp - 1)
          _ (put o (peep ss 0 0))
          _ (1 < sig ? (put o 46, say o (snip ss 1 sig)))
          _ (put o 101)
          _ (e < 0 ? (put o 45) 0)
          (say o (dstr (e < 0 ? -e e))))
       (0 < dxp)                                  ; 1 <= v < 1e16: the point sits inside or after
       (: (go i) (? (i < dxp) (: _ (put o (? (i < sig) (peep ss i 0) 48)) (go (1 + i))) 0)
          _ (go 0) _ (put o 46)
          (? (dxp < sig) (say o (snip ss dxp sig)) (put o 48)))   ; integral: force "X.0", never a fixnum face
       (: _ (say o "0.") _ (zeros o (0 - dxp)) (say o ss))))
  ; the sign is the bit, not v < 0: -0.0 < 0 is false, and a comparison there
  ; printed "0.0" -- the one value the roundtrip law lost.
  (pgem o v)
     (: _ (? (v < 0 || (v = 0 && (1.0 / v) < 0)) (put o 45) 0) a (abs v)
        (? (a = inf) (say o "infinity") (a = 0) (say o "0.0") (pgem2 o a)))
  ; a twin prints infix, parenthesized: (re ~ im) is self-delimiting, so it reads
  ; straight back wherever the printer put it.
  (ptwin o x) (: _ (put o 40) _ (pgem o (re x)) _ (say o " ~ ") _ (pgem o (im x)) (put o 41))

  ; --- chains. a one-operand `\` is quote, and a `(mono (run datum))` is a glued
  ; monadic -- print run+datum back the way opfix fused them.
  ; an improper tail prints as the ` . ` pair it is -- the dyadic `.` reads it straight back.
  (plist o x sn) (: (go l) (: _ (px o <l sn)
                              (? (two? >l) (: _ (put o 32) (go >l))
                                 (nil? >l) 0
                                 (: _ (say o " . ") (px o >l sn))))
                    _ (put o 40) _ (go x) (put o 41))
  (pchain o x sn) (: h <x t >x one (two? t && !(two? >t))
    (? (id? h '\ && one) (: _ (put o 39) (px o <t sn))
       (id? h 'mono && one && (: m <t (two? m && two? >m && !(two? >>m))))
         (: m <t _ (px o <m sn) (px o <>m sn))
       (plist o x sn)))

  ; --- trays. rank 1 is @(…); past that (array '(shape) elem…), since @ has no
  ; shape spelling. an object tray quotes what would otherwise re-evaluate.
  ; a tray is read by coordinate, so walk the flat index back into one, row-major
  (coord sh i) (? !(two? >sh) (i >< ())
                  (: r (foldl (*) 1 >sh) q (i // r) (q >< coord >sh (i - (q * r)))))
  (ptray o v sn) (: ty (atype v) sh (shape v) n (foldl (*) 1 sh)
    (pel i) (: e (peep v (coord sh i) 0)
               _ (? (ty = 3 && (nom? e || two? e)) (put o 39) 0) (px o e sn))
    (go i f) (? (i < n) (: _ (? f 0 (put o 32)) _ (pel i) (go (1 + i) 0)) 0)
    (gs l f) (? (two? l) (: _ (? f 0 (put o 32)) _ (pnum o <l) (gs >l 0)) 0)
    (? ((rank v) = 1) (: _ (say o "@(") _ (go 0 1) (put o 41))
       (: _ (say o "(array '(") _ (gs sh 1) _ (put o 41)
          (ge i) (? (i < n) (: _ (put o 32) _ (pel i) (ge (1 + i))) 0)
          _ (ge 0) (put o 41))))

  ; --- maps print {k v …}, the empty one {}; both read straight back. a map is
  ; mutable and can hold itself, so the path is carried and matched by identity.
  (onpath? x l) (? !(two? l) 0 (id? x <l) 1 (onpath? x >l))
  (pmap o m sn) (? (onpath? m sn) (say o "<cycle>")
    (: ks (keys m) s2 (m >< sn)
       (go l f) (? (two? l) (: _ (? f 0 (put o 32))
                                _ (px o <l s2) _ (put o 32) _ (px o (peep m <l ()) s2)
                                (go >l 0)) 0)
       (? !(two? ks) (say o "{}") (: _ (put o 123) _ (go ks 1) (put o 125)))))

  ; --- coins show as (name 'payload): the kind's name applied
  ; to what it was given, so the form evals back to an equal coin when the name is a
  ; bound ctor. the payload is quoted where it would otherwise re-evaluate -- a chain
  ; reads as an application and a nom as a variable. without that (q (1 2)) read back as
  ; q applied to 2, which is not the number and was never a coin.
  (pcoin o x sn) (: p (load x)
    (put o 40, px o (kind x) sn,
     put o 32, two? p || nom? p ? (put o 39) 0,
     px o p sn, put o 41))

  ; --- closures. a partial's every unc cell holds its arg at [1] and the link at
  ; [2], so the base value sits at link-2.
  (partp v) (id? unc (peek 0 v) || (id? cur (peek 0 v) && id? unc (peek 2 v)))
  (unc0 v) (? (id? cur (peek 0 v)) (seek 2 v) v)
  (nargs v) (: (go u n) (: l (peek 2 u) (? (id? unc (peek 0 l)) (go l (1 + n)) n)) (go (unc0 v) 1))
  (fbase v) (: (go u) (: l (peek 2 u) (? (id? unc (peek 0 l)) (go l) (seek -2 l))) (go (unc0 v)))
  (farg v i n) (: (go u w) (? (0 < w) (go (peek 2 u) (w - 1)) (peek 1 u)) (go (unc0 v) ((n - 1) - i)))
  ; --- a lambda's source, de Bruijn renamed: a \-bound variable prints as its level's
  ; letter, so a-equivalent lambdas print alike and inspect agrees with `=`. free, global
  ; and :-bound names keep their spelling; quoted data is shared verbatim.
  (inq x l) (? !(two? l) 0 (id? x <l) 1 (inq x >l))
  ; the shortlex letters: a b .. z aa ab .. , one-based so the digits carry no zero
  (sxch n a) (: q ((n - 1) // 26) c (97 + ((n - 1) % 26))
              (? (0 < q) (sxch q (c >< a)) (c >< a)))
  (lnom i) (name (string (sxch (1 + i) ())))
  ; a binder takes the next letter not spelled free anywhere in the source -- a name kept
  ; as written is a name a rename would capture, and skipping it is the whole guard.
  ; (\ a b (+ a b)) canonicalizes to itself; a body naming e takes f in e's place. the
  ; candidate index is what threads, so the letters are walked once across the whole term.
  (nxt i fv) (? (peep fv (lnom i) 0) (nxt (1 + i) fv) i)
  (lam? x) (two? x && id? <x '\ && two? >x && two? >>x)
  (qot? x) (two? x && id? <x '\ && two? >x && !(two? >>x))
  ; the noms canon leaves spelled as written: free, global and :-bound. quoted data is
  ; data, never a reference, so a binder cannot capture into it. one walk, into a tablet
  ; the proposals then read by key; bd is the binders in scope, a stack, so it stays a list.
  (fvs x bd t) (? (one? x) (? (nom? x) (? (inq x bd) t (pin t x 1)) t)
                  (qot? x) t
                  (lam? x) (fvl >x bd t)
                  (fvs >x bd (fvs <x bd t)))
  (fvl l bd t) (? (one? >l) (fvs <l bd t)
                  (fvl >l (<l . bd) t))
  (canon x sc i fv) (? (one? x) (? (nom? x) (: r (assoc x sc) (? r >r x)) x)
                       (qot? x) x
                       (lam? x) ('\ . cops >x sc i fv)
                       (canon <x sc i fv . canon >x sc i fv))
  (cops l sc i fv) (? !(two? >l) [(canon <l sc i fv)]          ; the last operand is the body
                      (: j (nxt i fv) nm (lnom j)
                       (nm . cops >l ((<l . nm) . sc) (1 + j) fv)))

  (pfn o v sn) (? (partp v)
    (: n (nargs v)
       (go i) (? (i < n) (: _ (put o 32) _ (px o (farg v i n) sn) (go (1 + i))) 0)
       _ (put o 40) _ (pfn o (fbase v) sn) _ (go 0) (put o 41))
    (: nm (nifnom v)
       (? (string? nm) (say o nm)
          ; a glued sigil's backing value has no nif name but it has exactly one word;
          ; say that instead of inlining its whole body wherever `<x` was written.
          (: gn (opnom v)
             (? gn (say o (string gn))
                (: s (lamsrc v)
                   (? (two? s) (px o (canon s 0 0 (fvs s () {})) sn)
                      (: _ (put o 92) (pnum o (abs (dig v)))))))))))   ; opaque: a distinguisher, nothing more -- C spelled the address here, this is the digest, which at least survives a collection

  (px o x sn) (? (charm? x) (pnum o x)
                (coin? x && !(x = load x)) (pcoin o x sn)   ; struck: a native loads as itself
                (tablet? x) (pmap o x sn)
                (lit? x) (pfn o x sn)
                (id? x ()) (say o "()")
                (two? x) (pchain o x sn)
                (string? x) (pstr o x)
                (nom? x) (? (mint? x) (: _ (say o "(mint ") _ (pnum o (dig x)) (put o 41))
                              (say o (string x)))
                (gem? x) (pgem o x)
                (tray? x) (ptray o x sn)
                (twin? x) (ptwin o x)
                (sun? x || big? x) (pnum o x)
                o)
  px)))

; the surface. `dot` takes a string or cask verbatim and everything else in external
; form; it answers its operand, so it drops into any sequence.
(: (print o x) (: _ (px o x ()) x)
   (show x) (: o (jug 0) _ (px o x ()) (slurp o))
   (dot x) (: _ (? (string? x || hot? x && !(port? x)) (say out x) (px out x ())) _ (flush out) x))
(: putx (print out)
   _ (seal-hook 7 show))                           ; `string` coerces through it from here on
(: (red? x) (+x < 0) (blue? x) (+x = 0) (green? x) (+x > 0))
