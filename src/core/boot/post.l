
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
  ; q applied to 2, which is not the number and was never a coin. a rational wears the
  ; twin's face instead, (n /// d), which reads back through the operator.
  (pcoin o x sn) (: p (load x)
    (? (kind x = '/// && two? p) (put o 40, px o <p sn, say o " /// ", px o <>p sn, put o 41)
       (put o 40, px o (kind x) sn,
     put o 32, two? p || nom? p ? (put o 39) 0,
     px o p sn, put o 41)))

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

; --- the library layers, sat here with post so every seat carries them: rng and q are
; --- globals, and the rest register as modules a seat splices as it wants ---

; rng -- the random layer, two faces over the pure C steps; C holds no state.
; (wheel n) -> a fresh 256-bit state, turn/turnf step it. src/core/boot/prel.l first.
;
; functional, reproducible: (random st n) draws once -> (value . st'), the value's type
; by n -- float -> float in [0,n), positive int -> int in [0,n), n <= 0 -> full-width int.
; global, one hidden stream lazily clock-seeded: (rand n) -> int in [0,n), (randf n) ->
; float in [0,n); n <= 0 widens both. rng-get reads the stream, (rng-set (wheel n)) pins
; it so rand/randf reproduce -- a bad state answers 0 and leaves the stream alone.
;
; the stream is private mutable state: rng-box is bound once, not inlined --
; separate copies would be separate streams.
(: rng-box {}
   (random st n) (? (gem? n) (turnf st @ (a . u) (n * a . u))
                    (0 < n)  (turn  st @ (a . u) (a % n . u))
                    (turn st))
   (rng-get _) (: st (rng-box ()) (? (tray? st) st
                (: f (wheel (clock 0)) (pin rng-box () f, f))))
   ; a valid state is rank-1, length 4, and the platform's own limb type -- compare
   ; against a fresh seed's tier, never a baked-in `z` (a 32-bit word rides a C array)
   (rng-set st) (tray? st && rank st = 1 && tally st = 4 && tier (wheel 0) = tier st ?
                 (pin rng-box () st, st) 0)
   (rand n) (: r (turn (rng-get 0))
             (pin rng-box () >r,
              charm? n && 0 < n ? (<r % n) <r))
   (randf n) (: r (turnf (rng-get 0))
              (pin rng-box () >r,
               constellation? n && 0 < n ? (n * <r) <r)))

; /// -- rationals: an exact field as a coin over reduced (num den). the twin's peer: 3 /// 4
; builds one, and one prints that way
(: /// (: (reduce n d)
         (0 = n ? [0 1]                           ; gcd out, sign on num, den > 0
          (: g (gcd (abs n) (abs d)) s (? (d < 0) -1 1)
           [(s * n // g) (s * d // g)]))
        (parts v) (two? v ? v [v 1])                          ; a bare star is n/1
        ; the domain test is the closed star (the fixpoint minus coins): star?
        ; is open now, and an open star as an (n d) component would drag gcd
        ; off the tower it terminates on -- a coin is never a coefficient.
        (nstar? v) ((nil? * coin?) v && v = +v)
        (ok? v) (nstar? v || (two? v && all nstar? v))
        c (coin '/// (z \ {'star 1 'net 'ratio                   ; a rational is a star; C truth by value
         '+ (\ a b (: x (load a) y (load b)                    ; (n1 d1) + (n2 d2)
             (? (ok? x && ok? y)
              (: p (parts x) r (parts y)
               (z (reduce (<p * <>r + <r * <>p) (<>p * <>r)))))))
         '* (\ a b (: x (load a) y (load b)                    ; (n1 d1) * (n2 d2)
             (? (ok? x && ok? y)
              (: p (parts x) r (parts y)
               (z (reduce (<p * <r) (<>p * <>r)))))))
         '- (\ a b (: x (load a) y (load b)                    ; (n1 d1) - (n2 d2)
             (? (ok? x && ok? y)
              (: p (parts x) r (parts y)
               (z (reduce (<p * <>r - <r * <>p) (<>p * <>r)))))))
         '/ (\ a b (: x (load a) y (load b)                    ; (n1 d1) / (n2 d2): invert and
             (? (ok? x && ok? y && <y != 0)                  ; multiply; by zero -> () (no inf in Q; cap of a bare star is itself)
              (: p (parts x) r (parts y)
               (z (reduce (<p * <>r) (<>p * <r)))))))}))
        (\ n (two? n ? (c (reduce <n <>n))                    ; (/// (n d)) -- the list form
                       (c * reduce n)))))                     ; (/// n d) -- the curried form, and 3 /// 4 spaced


; glob -- fnmatch, pure love and no filesystem. the pattern law only: pathname
; expansion (readdir, the dotfile rule at the directory scan) stays in src/apps/lush/glob.l,
; where the substrate belongs. this half is a predicate over two strings, and more than
; the shell asks it -- lush's case patterns, kore's find -name, the sb ignore law, the
; selfpack walk. selfpack runs on love0, which carries no lush: that is why this is a
; core/boot module and not an app one.
;
; patterns travel as (text . mask) -- the mask a parallel string of '1'/'0' bytes, '1'
; where the char came in unquoted (glob-live), '0' where a quote shielded it ('*' matches
; a literal star) -- absence-of-specialness carried out of band, the quoting law made
; byte-addressable. a caller with no quoting to express asks `match`, which is all-live.
;   (fmatch pat mask s) -> 1 | 0     * ? [a-z] [!..], quoted chars literal
;   (match pat s)       -> the all-live face
;   (anyglob t)         -> does t hold any * ? [ at all (the cheap pre-scan)
;   (ones k)            -> an all-live mask of width k

(module '(glob match fmatch anyglob ones)
(: (anyglob t)
     (: n #t
        (go i) (i != n && (t i @ (42 || 63 || 91) 1 (go (i + 1))))
        (go 0))
   (ones k) (k < 1 ? "" (ones (k - 1) + "1"))
   (match p s) (fmatch p (ones #p) s)
   (fmatch p m s)
   (: np #p ns #s
      (act? i) (i < #m && m i = 49)
      ; [..] at i against (s j) -> (hit . j-past-class) | () unterminated
      (cls i j)
        (: neg (i + 1 < np && (p (i + 1) = 33 || p (i + 1) = 94))
           st (? neg (i + 2) (i + 1))
           (fnd k first hit) (k != np ?  (: b (p k)
            (? (b = 93 && !first) (hit . (k + 1))
               (k + 2 < np && p (k + 1) = 45 && p (k + 2) != 93)
                (fnd (k + 3) 0 (hit || b <= s j && s j <= p (k + 2)))
               (fnd (k + 1) 0 (hit || b = s j)))))
           r (fnd st 1 0)
           ; presence is `two?`, never truth. a class that misses answers
           ; (0 . past), and net drops an improper tail, so a falsy r would read
           ; as "no class here" -- which negation then never gets to invert.
           (two? r ? ((neg ? !<r <r) . >r)))
      (fm i j)
        (? (i = np) (j = ns)
           (: b (p i)
              (? (act? i && (b = 42))
                   (fm (i + 1) j || ((j < ns) && fm i (j + 1)))
                 (act? i && (b = 63)) ((j < ns) && fm (i + 1) (j + 1))
                 (&& (act? i) (b = 91) (j < ns))
                   (: c (cls i j)
                      (? (one? c) (((s j) = 91) && fm (i + 1) (j + 1))  ; lone [ is itself
                         (<c && fm >c (j + 1))))
                 (j < ns && s j = b) (fm (i + 1) (j + 1)))))
      (bit (fm 0 0))))

) ; module glob

; kanren -- first-order unification + a lazy-colist search monad.
; a post-egg layer: prel stays the language, this registers as a module. needs prel and
; pat's @. overlay below reads unify/ufail?/var
; from here and reaches the rest through the registry, so this must be evaled and
; registered before overlay -- cat order.
;
; `unify s u v` is pure -- a substitution or `ufail` -- with no occurs check: love's values
; are non-well-founded (a chain is a mu-type, the book holds the book), so a self-referential
; binding is a rational tree, and walk_star mu-marks a back-edge to reify it without looping.
; a goal is (\ st stream) over a state (substitution . constraints); est/=== unify, +
; interleaves (disjunction), * binds (conjunction), so a relation is a polynomial in
; unifications. a boot says (use 'kanren) to splice the bare names; internals -- subst,
; walk, query, the dict kit -- answer to (from 'kanren ..).
(module '(kanren =/= === absent apt closed? con dif empty_dict est ifte inside mintp naf nay query rel
   residual rewrite s_app scount slist smap sno sole s_plus s_star st0 stake subst sun
   sX tie ufail ufail? unify untie var var? walk)
   ; the scan asks two?, never ?: a key list is data, and `?` reads it for net -- a key that
   ; sums to nothing (a var labelled 0, a bare nom) would end the scan early
(: (dict_has d k) (: (loop k ks vs) (? (two? ks) (? (k = <ks) vs (loop k >ks >vs))) (loop k <d >d))
   (dict_set d k v) ((k . <d) . v . >d)
   empty_dict '(())
   has_s dict_has
   ext_s dict_set
   (mintp x) (mint? x)
   (var x) (x . nom 0)                         ; (label . fresh-nom) -- identity by the nom
   ; the tail is the nom, and the test says so: a nom anywhere else in a term -- an atom
   ; under `tie`, say -- is data, not a variable. `?`, not &&: a predicate owes a bit.
   (var? x) (? (two? x) (nom? >x) 0)
   (walk s u) (? (nil? (var? u)) u (: t (has_s s u) (? (two? t) (walk s <t) u)))
   ufail (nom 0)
   (ufail? x) (= x ufail)
   ; a binder, and the whole nominal half: the abstraction is a love lambda, so
   ; alpha-equivalence is the language's and instantiation is application -- nothing
   ; to swap, rename, or capture.
   (tie f) ('tie . f)
   (tie? t) (? (two? t) (= <t 'tie) 0)
   (untie t a) (>t a)                            ; open the binder at a
   (unify s u v) (: x (walk s u) y (walk s v)       ; pure: a substitution, or ufail
     (? (x = y) s                                   ; alpha-equal binders land here, for free
        (var? x) (ext_s s x y)
        (var? y) (ext_s s y x)
        (tie? x && tie? y) (: a (nom 0) (unify s (untie x a) (untie y a)))   ; one fresh nom opens both
        (two? x && two? y) (: s1 (unify s <x <y) (? (ufail? s1) ufail (unify s1 >x >y)))
        ufail))
   (subst s t) (? (var? t) (: w (walk s t) (? (var? w) w (subst s w)))   ; instantiate a template under s
                  (tie? t) (tie (\ a (subst s (untie t a))))             ; under a binder: at its opening
                  (two? t) (subst s <t . subst s >t)
                  t)
   (rewrite pat tpl x) (: r (unify '(()) pat x) (? (ufail? r) x (subst r tpl)))   ; pattern -> template, or x unchanged

   ; --- the constraint store -------------------------------------------------
   ; the store rides beside `unify`, which keeps its signature and its purity. a
   ; constraint is (kind . payload), re-verified against the whole store after every
   ; successful unification -- cKanren's design.
   st0 (empty_dict . ())
   (unify_all s p) (? (two? p) (: r (unify s <<p ><p) (? (ufail? r) ufail (unify_all r >p))) s)
   ; the bindings r has and s does not, as a (u . v) list -- ext_s prepends, so they lead
   (residual r s) (: (go k ks vs acc) (? k (go (k - 1) >ks >vs ((<ks . <vs) . acc)) acc)
                     (go ((tally <r) - (tally <s)) <r >r ()))
   ; does x occur in the (walked) term t? a tie is opened at a fresh nom, which is
   ; exactly what freshness means: an outer atom is never the bound one.
   (inside s x t) (? (x = t) 1
                     (var? t) 0
                     (tie? t) (inside s x (walk s (untie t (nom 0))))
                     (two? t) (? (inside s x (walk s <t)) 1 (inside s x (walk s >t)))
                     0)
   (closed? s t) (? (var? t) 0
                    (tie? t) (closed? s (walk s (untie t (nom 0))))
                    (two? t) (? (closed? s (walk s <t)) (closed? s (walk s >t)) 0)
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
    (: (go (a . u)) (vet1 s a @ ^ufail ufail r (: t (go u) (t == ufail || r == 'drop ? t (r . t)))) go)
   (con st c) (: d (vet <st c) (? (ufail? d) ufail (<st . d)))   ; a state with c added, or ufail

   ; --- streams: a colist, love's lazy list (src/core/boot/p1.l's shape) --------------
   ; () is empty, (x . s) is mature, a thunk is immature -- three shapes told apart by
   ; lit?/two?. the church encoding this replaces cost 26-35% more instructions on every
   ; shape measured; doc/misc/kanren.md carries the numbers.
   sno ()
   (sX x s) (x . s)
   (sun x) [x]
   (s_plus s t) (s @ (f && lit? f) (s_plus t * f)       ; interleave (disj): the swap is the fairness
                     (x . r)       (x . s_plus r t)
                     t)
   (s_star s g) (s @ (f && lit? f) (_ \ s_star (f _) g)       ; bind (conj)
                     (x . r)       (s_plus (g x) (s_star r g)))
   (s_app s t)  (s @ (f && lit? f) (_ \ s_app (f _) t)        ; ordered disj: no swap, so the left
                     (x . r)       (x . s_app r t)              ; side runs dry first -- incomplete
                     t)                                          ; by construction, and that is the point
   (sfire s) (lit? s ? (sfire (s ())) s)                ; force to a mature shape: () or a cons
   (stake i s) (i @ 0 () (sfire s @ (a . u) (a . stake (i - 1) u)))
   (smap f s) (s @ (g && lit? g) (_ \ smap f (g _)) (x . r) (f x . smap f r) ())
   (sfold f z s) (: m (sfire s) (? (two? m) (f <m (sfold f z >m)) z))
   slist (sfold (.) ())
   (scount s) (: (go a s) (: m (sfire s) (? (two? m) (go (a + 1) >m) a)) (go 0 s))

   ; --- goals ----------------------------------------------------------------
   ; conj2/disj2 are the whole of the goal algebra: &&& and ||| expand to them, and the
   ; ring's * and + are them under the coin. `load` at construction is what lets either
   ; spelling take either operand, a bare goal or a rel-wrapped one.
   (conj2 a b) (: g (load a) h (load b) (\ st (s_star (g st) h)))
   (disj2 a b) (: g (load a) h (load b) (\ st (s_plus (g st) (h st))))
   yea sun                               ; the goal that holds, once
   nay ()                                ; the goal that never does
   (est u v st) (: r (unify <st u v)
                   (ufail? r ? ()
                    (: c (vet r >st) (? (ufail? c) () (sun (r . c))))))
   ; unify on a copy and read the outcome three ways -- ufail means the two can never be
   ; equal and there is nothing to remember; no new binding means they are equal, so the
   ; goal fails; anything else keeps the residual bindings as the constraint.
   (dif u v st) (: r (unify <st u v)
                   (? (ufail? r) (sun st)
                      (: p (residual r <st)
                         (? (two? p) (: t (con st (('dif . p) . >st)) (? (ufail? t) () (sun t)))
                            ()))))
   ; absento, and nominal freshness by the same machinery: x occurs nowhere in t, now or
   ; ever. for a nom x under `tie` this is alphaKanren's a # t.
   (absent x t st) (: r (con st (('abs . x . t) . >st)) (? (ufail? r) () (sun r)))
   ; a type constraint over any predicate -- symbolo/numbero and their kin in one goal
   (apt p x st) (: r (con st (('apt . p . x) . >st)) (? (ufail? r) () (sun r)))
   ; --- the extra-logical three. `ifte` is the primitive (the soft cut): if c
   ; holds at all, t runs over every answer of c and e is dropped. `sole` commits
   ; to the first answer. `naf` is negation as failure -- it answers "not proved",
   ; never "false", and only a ground terminating goal lets you read the two as one.
   (ifte c t e st) (: m (sfire (c st)) (? (two? m) (s_star m t) (e st)))
   (sole g st) (: m (sfire (g st)) (? (two? m) (sun <m) ()))
   (naf g st) (ifte g nay yea st)

   ; --- query: run a goal, reify the answers ---------------------------------
   (query n ks g) (:
    (walk_star s u path) (?                          ; cycle-safe: (mu label) on a back-edge
     (var? u) (: t (has_s s u)
                 (? (atom? t) u
                    (member? u path) ['mu <u]
                    (walk_star s <t (u . path))))
     (tie? u) (: a (nom 0) ['tie a (walk_star s (untie u a) path)])
     (two? u) (walk_star s <u path . walk_star s >u  path)
     u)
    ; the noms an answer carries -- a tie's binder, an atom a relation minted -- are
    ; renamed a1 a2 .. in first-sight order, so an answer reads back and compares.
    (noms t acc) (? (var? t) acc
                    (mint? t) (? (member? t acc) acc (t . acc))
                    (two? t) (noms >t (noms <t acc))
                    acc)
    (renom d t) (? (var? t) t
                   (mint? t) (: v (dict_has d t) (? (two? v) <v t))
                   (two? t) (renom d <t . renom d >t)
                   t)
    (dename t) (: ns (rev (noms t ()))
                  (? (two? ns)
                     (renom (foldl (\ d p (dict_set d <p <>p)) empty_dict
                                   (zip ns (map (\ i (intern (+ "a" (show (i + 1))))) (jot (tally ns)))))
                            t)
                     t))
    (keyvar keys k) (? (atom? keys) 0 (: kv <keys (? (k = <kv) kv (keyvar >keys k))))
    (reify1 st) (dename (flip catmap ks (\ k (: kv (keyvar <<st k) (? (two? kv) [k (walk_star <st kv ())])))))
    (map reify1 ((? n (stake n) slist) (g st0))))
   rel (coin 'goal (z \ {'+ (\ A B (z (disj2 A B)))   ; the goal coin: + = disj = |||, * = conj = &&&
                         '* (\ A B (z (conj2 A B)))})))
(: (=== u v) (rel (est u v))                        ; the relation's infix unify -- it needs no row
   (=/= u v) (rel (dif u v)))                       ; in prel's `operators`, which holds only the
; exceptions, and any all-punct head is already infix-dyadic at house band. =/= shares a band
; with ===, so a chain folds by hand and wants parens.
; the goal language: `::` writes the head layer's macro table, so these four live in kanren's
; own book, and a consumer's (use 'kanren) splice carries them -- macroget walks the chain's
; macro slots, so &&&/|||/\\\/zz expand at the caller and the names their expansions emit
; (var, s_plus, s_star) resolve down the same splice.
; the tripled spellings are the point: a relation is the ordinary operator said three times --
; === is =, =/= its negation, &&& and ||| are && and ||, \\\ is \ with its params minted fresh
; as logic vars. all-punct, so all of them are infix at house band for free.
(:: 'zz (\ x (: s (nom 0) u (nom 0) x2 <x ['\ s u [x2 s]])))   ; delay a goal: the curried tail is the thunk
(:: '&&& (\ xs (foldl (\ a b [conj2 a b]) <xs >xs)))   ; conj of goals -- the ring's *
(:: '||| (\ xs (foldl (\ a b [disj2 a b]) <xs >xs)))   ; disj of goals -- the ring's +
(:: '\\\ (\ a (('\ . a) . map (\ a [var ['\ a]]) (init a))))                         ; lambda w/ fresh logic vars

) ; module kanren

; overlay -- an optional, observe-only static-type overlay hooked at the ev seam
(module '(overlay ov-check ov-eng overlay-off overlay-set ov-hook ov-slot)
(use 'kanren)                                         ; subst unify ufail ufail? var, scoped to this compile
(: ov-both
    (: (ov-sigof sigs nm) (sigs @ (((aa . ua) @ a) . u) (nm @ ^aa a (ov-sigof u nm)))
       (ov-look env x) (env @ ((ap . up) . env') (x @ ^ap up (ov-look env' x)) 'bot)
       (ov2-var? dom d) (nom? d && !(member? d (dom 'dice)) && !(member? d (dom 'ctors)))   ; a sig variable: not concrete, not a constructor
       (ov2-vars dom d acc) (one? d ?
        (ov2-var? dom d && !(member? d acc) ? (d . acc) acc)
        (foldl (flip $ ov2-vars dom) acc d))
       (ov2-lk vm d) (? (one? vm) d
                        (d = <<vm) ><vm
                        (ov2-lk >vm d))   ; ><vm is glued: cuap, not the cons
       (ov2-term vm d)    (one? d ? (ov2-lk vm d) (map (ov2-term vm) d))
       (ov2-uall ps as s) (? (one? ps || one? as) s
                             (member? <as '(top bot)) (ov2-uall >ps >as s)   ; an unknown arg is gradual: consistent with any param, binds nothing
                             (: s1 (unify s <ps <as) (ufail? s1 ? ufail (ov2-uall >ps >as s1))))
       (ov2-inst dom sg args)                                          ; sg = (name (param-dies) result): structured caller instantiation
        (: params <>sg result <>>sg
           vm (map (nm \ nm . var nm) (ov2-vars dom (params . result) ()))            ; one fresh logic var per sig variable
           s  (ov2-uall (map (ov2-term vm) params) args '(()))   ; unify param patterns (fresh vars) vs arg dies as-is (a caller's rigid symbol is a constant here -- no capture)
           (? (ufail? s) 'clash                                        ; args contradict the params: the one hard verdict
              (#args != #params) 'top                        ; partial/over-application: a closure/re-application, die unknown
              (: r (subst s (ov2-term vm result)) nf (dom 'norm) (lit? nf ? (nf r) r))))   ; reify + normalize (dependent index)
       (ov-kindof dom sigs env e)
          (? (nom? e) (ov-look env e)
             (one? e) (dom 'litdie e)
             (: h <e as (map (ov-kindof dom sigs env) >e)
                (? (member? h '(+ *)) (dom 'tr h <as <>as)
                   (h = '? && #e = 4) (dom 'join <>as <>>as)
                   (: sg (ov-sigof sigs h) (one? sg ? 'top (ov2-inst dom sg as))))))
       (ov-zip (ap . up)  (ad . ud))     ((ap . ad) . ov-zip up ud)
       (ov-clash dom sigs env e) (two? e ? (: d (ov-kindof dom sigs env e) sub (catmap (ov-clash dom sigs env) >e)
                                            (d @- sub 'clash ((e . map (ov-kindof dom sigs env) >e) . sub))))   ; a clash site = (expr . operand-dies)
                                                    ; the ternary is parenthesized: bare in a `:`
                                                    ; element list it does not factor at all
       (ov-pairs (a . b . c)) ((a . b) . ov-pairs c)
       (ov2-okr dom bd decl) (: f (dom 'okr) (lit? f ? (f bd decl) (dom 'join bd decl = decl)))   ; result acceptable? domain `okr` (dependent = up to conv/norm), else structural join
       (ov-check1 dom sigs prog)
          (catmap (p @ ((nm . ps) . body) \                          ; parenthesize the `:`: it is
                     (: sg (ov-sigof sigs nm)                       ; looser than `?`, so unwrapped it
                        (two? sg ?                                  ; eats `two? sg` as a second pair
                         (: env (ov-zip ps <>sg) cl (ov-clash dom sigs env body)
                            bd (ov-kindof dom sigs env body) decl <>>sg
                          (two? cl || !(ov2-okr dom bd decl) ? [(nm . (one? cl ? ['result bd decl] cl))])))))
                  (filter (two? * cap) (ov-pairs >prog)))
       (ov-djoin dies) (? (one? dies) "?" (one? >dies) (show <dies) (show <dies + " vs " + ov-djoin >dies))
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
     (: v (ov-slot 0) (two? v ? (ov-eng <v <>v e, e0 e) (e0 e))))
) ; module overlay

; uu -- the uu kernel's HOME: MLTT with the UniMath Preamble's seven
; inductives (empty unit bool coprod nat paths total2), bidirectional checking,
; NbE conversion (de bruijn levels as fresh vars, sigma- and pi-eta),
; type-in-type -- the universe stance of the reference
; (UniMath/Foundations/Init.v: Unset Universe Checking). an axiom is a book
; entry with a type and no value: a sanctioned missing. names follow UniMath so
; the port reads literally.
;
; terms are quoted lists: UU nat bool unit empty zero tt true false <fixnum>
;   (pi x A B) (lam x b) (total2 x A B) (tpair a b) (pr1 w) (pr2 w) (succ n)
;   (coprod A B) (ii1 a) (ii2 b) (paths a a b) (idpath a) (the T t)
;   (nat_rect P z s n) (bool_rect P t f b) (unit_rect P u x)
;   (coprod_rect P f g v) (empty_rect P e) (paths_rect P pr e)
;   (let x a b) -- definitional: x binds the VALUE of a, transparent to conv
; and any other list is an application spine. (f) == f here too.
;
; a module on every corpus target (host + love0 + the inle kernel + wasm): the
; frontend lists this source in its ai_libs table and its boot says (use 'uu), then
; rebinds `uu` to the accessor -- (: uu (from 'uu)) -- so the surface stays
; (uu 'vof), (uu 'defn), (uu 'chk), (uu 'lof), and every internal a probe away.
; the layer is the module boundary now: the old uu-mark/sweep trailer retired
; with the brackets. the UniMath theorem corpus rides in test/uu.l (and the
; test/uu*.l ladder over it), binding this surface at its head; the defn/defq/
; axm macros land in this layer's macro slot and ride the boot splice.

; --- the kernel: values, evaluation, conversion, checking ---
; the surface: what `from`/`use` see. everything else is internal, a probe away.
(module '(uu axm bridge capp chk conv defn defq GLOB HELPC lof rejects vof)
(: GLOB {} HELPC {} SRC {} CMEM {} BRIDGE {})

(: (vsucc v) (charm? v ? (v + 1) ['succ v])

   ; a uu closure carries a love function, so applying one is an application and not a
   ; re-walk of the body's syntax. ('clo f) is opaque above this line: conv reaches a
   ; closure only through capp (its lam/pi/sig branches all come before the spine case), and
   ; lof prints terms, so these two lines plus comp's three ('clo ..) sites are the whole
   ; representation.
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

   ; --- comp: the term walked once, into a love function of the env ---
   ; every case below reads `(\ en ..)` where the old vof read the value directly, and that is
   ; the whole change: the head dispatch, the destructuring and the arity all happen here, once
   ; per term, where they used to happen once per evaluation. a lam's body becomes a love
   ; closure over the compiled body, so capp is an application.
   ; vof-sym stays dynamic. it reads glob, and a defn later in the corpus must be visible to
   ; a term compiled earlier -- so the lookup rides the `(\ en ..)`, never the compile.
   ; ordered by measured frequency, and the tail is never reached at all: over the UniMath
   ; corpus lam and succ are 550740 and 526521 of 1102646 head dispatches, while total2 pr1 pr2
   ; ii1 ii2 are zero -- the reader spells them, but every use arrives through a spine or a
   ; rect. succ once sat at position 8 behind four of those zeros. The tests are mutually
   ; exclusive symbols so the order is free; only `(two? h)` must stay first, the spine last.
   ; the order matters less than it did (once per term, not per evaluation) and is kept
   ; because compiling is itself on the hot path: chk and inf compile each subterm they visit.
   (comp t)
   (? (charm? t) (en \ t)
      (nom? t) (? (memq t '(UU nat bool unit empty tt true false)) (en \ t)
                  (= t 'zero) (en \ 0)
                  (en \ vof-sym en t))
      ; a pattern is the TERM grammar, so this dispatch now reads like the header's own
      ; list of shapes. It costs the arity guards, and here they are nearly free: comp runs
      ; 14778 times over the corpus where the old vof ran 1102646, so this whole chain is
      ; 1.3% of one capp's traffic. the (two? h) fast PATH is gone with it: a list head is
      ; never id? to a tag, so a spine falls through every arm to the else on its own -- and
      ; it is 259 of those 14778, which is not worth a branch or a second copy of the body.
      (t @
         ['lam x b]             (: cb (comp b) (en \ ['lam ['clo (v \ cb ([x v] . en))]]))
         ['succ a]              (: ca (comp a) (en \ vsucc (ca en)))
         ['pi x A B]            (: cA (comp A) cB (comp B)
                                 (en \ ['pi (cA en) ['clo (v \ cB ([x v] . en))]]))
         ['paths A a b]         (: cA (comp A) ca (comp a) cb (comp b)
                                 (en \ ['paths (cA en) (ca en) (cb en)]))
         ['nat_rect P z s n]    (: cP (comp P) cz (comp z) cs (comp s) cn (comp n)
                                 (en \ donr (cP en) (cz en) (cs en) (cn en)))
         ['tpair a b]           (: ca (comp a) cb (comp b) (en \ ['chain (ca en) (cb en)]))
         ['idpath a]            (: ca (comp a) (en \ ['refl (ca en)]))
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
         ['pr1 w]               (: ca (comp w) (en \ dop1 (ca en)))
         ['pr2 w]               (: ca (comp w) (en \ dop2 (ca en)))
         ['ii1 a]               (: ca (comp a) (en \ ['i1 (ca en)]))
         ['ii2 b]               (: ca (comp b) (en \ ['i2 (ca en)]))
         (: cf (comp <t) cas (map comp >t) (en \ spine en (cf en) cas))))

   (spine en f cas) (cas @ (a . u) (spine en (vapp f (a en)) u) f)

   ; the old door, kept for every caller (chk, inf, the globals, test/uu.l): compile, then run.
   vof (flip comp)

   ; the scrutinee is a pair, which is why this one stays a `?`: an arm reads both
   ; sides, and a pattern would build the [a b] per call to say less than the tests do.
   ; id?, the one use outside the egg: same object -> 1 at once, else the arms convert.
   ; `=` cannot stand in -- on two different terms it walks their closures, and the
   ; shared environments make that exponential. the atom arm is a guard: reaching it
   ; means unequal, and it keeps `<a` off a non-list below.
   (conv d a b)
   (? (id? a b) 1
      (atom? a || atom? b) 0
      (<a = 'lam || <b = 'lam)
       (: fr ['nv d] (conv (d + 1) (vapp a fr) (vapp b fr)))
      (<a = 'chain && <b != 'chain)
       (conv d <>a (dop1 b) && conv d <>>a (dop2 b))
      (<b = 'chain && <a != 'chain)
       (conv d (dop1 a) <>b && conv d (dop2 a) <>>b)
      (<a = 'pi && <b = 'pi)
       (conv d <>a <>b && (: fr ['nv d] (conv (d + 1) (capp <>>a fr) (capp <>>b fr))))
      (<a = 'sig && <b = 'sig)
       (conv d <>a <>b && (: fr ['nv d] (conv (d + 1) (capp <>>a fr) (capp <>>b fr))))
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

   ; checking is two shapes at once -- the term's and the type's -- so every arm here
   ; is an `@` inside an `@`, and the inner else is the mismatch that names both.
   (chk cx en d t T)
   (t @
      ['lam x b]   (T @ ('pi A q) (: fr ['nv d]
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
      (: Ti (inf cx en d t)
       (conv d T Ti || scare 'uu-type-mismatch t)))

   ; the else is the spine and needs no head test in front of it: a list head is never
   ; id? to a tag, and (inf .. <t) answers for a nom head and a nested spine alike.
   ; a pattern carries the arity the old head test did not, so a tag at the wrong
   ; length reaches the spine and comes back unbound instead of reading () for operands.
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

; --- drivers: a definition is checked then pinned; an axiom is a book entry
; --- with a type and no value (its value is its own neutral name); rejects
; --- runs a thunk expecting the kernel to refuse (the help cell escapes).
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
   ; the Qed driver: checked like defn, then sealed -- pinned with its own
   ; neutral as value, so applying the proof never evaluates it. Coq's
   ; Qed/Defined distinction, here because strict NbE would otherwise build
   ; the proof's whole beta-normal form at every use.
   (defq nm T t)
   (: Tv (chk 0 0 0 T 'UU,
          vof 0 T)
    (chk 0 0 0 t Tv,
     pin GLOB nm [Tv ['nv nm]],
     nm))
   (rejects th)
   (: r (call-cc (\ k (pin HELPC () (\ a b (k 'rejected)), th 0, 'accepted)))
    (pin HELPC () 0, r)))

; --- uu2l: the uu-to-l leg. uu2coq and uu2lean re-certify the corpus in two
; --- foreign kernels; uu2l runs it HOME -- a closed term compiles to a love
; --- form whose value is vof's answer (charms for nats, ('chain a b) for
; --- pairs), at compiled-love speed; lof (l-of, vof's fast twin) evaluates one.
; --- untrusted by design: chk/conv never touch it, so a uu2l bug can miss a
; --- demo, never fake a theorem -- and the corpus asserts (vof t = lof t)
; --- differentially wherever both lanes are tractable. generated code has no
; --- free names: the runtime kit and every global embed as live literals
; --- under the quote sigil, so nothing a uu binder spells can capture.
; --- bridge maps standard names to native love (add is +, the eager-NbE O(n)
; --- niszero is (= m 0)) -- each bridge rides the same differential gate.
; --- defn feeds src; a defq/axm name compiles to its own neutral, exactly
; --- the sealed book value.
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
     (SRC nm @ (src) (: v (ev (u2 src ())) (pin CMEM nm ['hit v], v))
               ['nv nm])))

   (u2app t bs) (map (a \ u2 a bs) t)

   ; the tag does not pick the order: nat_rect and friends take their operands
   ; the way knrec wants them, not the way the term spells them.
   (u2 t bs)
   (? (charm? t) t
      (nom? t)
      (? (= t 'zero) 0
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

; --- the arity door. defn/defq/axm are fully curried, so a paren slip that
; --- hands one too few operands is not an error -- it is a truthy closure one
; --- curry away from running, an assert paints it green, and nothing pins
; --- (the (f)==f trap at proof grain; too many operands feed the returned nom
; --- and vanish the same way). the macros guard call position: exactly the
; --- right operand count, or the form scares carrying itself. the expansion
; --- heads (1 defn) -- the identity's head is no macro, so no re-expansion --
; --- and the functions keep their names, so the baked book still serves them
; --- ((uu 'defn) is boot/post.l's door, and book calls bypass the macro).
(: q (map qlit)
 (:: 'defn (l \ l @ [_ _ _] (defn . q l) (scare 'uu-defn-arity l)),
  :: 'defq (l \ l @ [_ _ _] (defq . q l) (scare 'uu-defq-arity l)),
  :: 'axm  (l \ l @ [_ _]   (axm  . q l) (scare 'uu-axm-arity  l))))

) ; module uu

; peg -- gw.js-style parser combinators. a parser is (\ s y n) over a string s, with a success
; continuation y = (\ rest payload) and a failure continuation n = (\ rest); payloads are lists that
; `seq` concatenates. The leaves are `lit` (a literal prefix), `one` (one char by predicate) and `span`
; (a maximal run) -- love has no regex. `parse` requires the whole input consumed; `runp` is the lenient
; twin (keeps the payload, ignores trailing slack). An empty payload is the unit, never the 0 nil-tail
; fossil: `cat` propagates whatever tail it is handed, so a single 0 from eps/opt/skip/many rides all the
; way out and `=` tells the two terminators apart -- a payload that should equal a map-built list would
; not. The unit is the only nil that leaves here.
;
; a module the boot never splices: it is registered with the rest, and each consumer opens with
; its own top-level (use 'peg), then reads the names bare off that splice -- src/core/holo/text.l,
; src/apps/cook/cook.l, src/apps/lapiz/lapiz.l, src/apps/sat/dimacs.l. the (use ..) must be its own
; top-level form: a `:` body compiles as one unit, so a use nested inside the form that reads
; the names runs too late to serve it.

(module 'peg
(: (eps s y n) (y s ())
   (lit l s y n) (? (#l <= #s && l = snip s 0 #l)
                  (y (snip s #l #s) [l])
                  (n s))
   ; the payload element is a one-char string, not the charm: every element a peg
   ; parser yields is then a string fragment, so a consumer's join is pure concat.
   ; the predicate still sees the charm.
   (one p s y n) (? (0 < #s && p (s 0))
                  (y (snip s 1 #s) [(snip s 0 1)])
                  (n s))
   (span p s y n) (:
    (g j)(j < #s && p (s j) ? (g (1 + j)) j)
    i (g 0)
    (y (snip s i #s) [(snip s 0 i)]))
   (alt a b s y n) (a s y (_ \ b s y n))
   (seq a b s y n) (a s (s1 \ p1 \ b s1 (s2 \ p2 \ y s2 (p1 + p2)) n) n)
   (seqs l) (foldr seq eps l)
   (opt a s y n) (a s y (_ \ y s ()))
   (skip a s y n) (a s (\ s1 _ (y s1 ())) n)
   (pmap f a s y n) (a s (\ s1 x (y s1 (f x))) n)
   (many a s y n) (a s
    (s1 \ p1 \ many a s1 (s2 \ p2 \ y s2 (p1 + p2)) (_ \ y s1 p1))
    (_ \ y s ()))
   ; --- the set the consumers kept re-deriving (src/apps/lapiz/lapiz.l had all of these
   ; --- under a comment reading "the combinators peg's set lacked") ------------
   (nope s y n) (n s)                                            ; the always-failing parser: alts' unit
   (notp a s y n) (a s (_ \ _ \ n s) (_ \ y s ()))              ; negative lookahead -- consumes nothing either way
   (many1 a) (seq a (many a))
   alts (foldr alt nope)
   (pack a) (pmap (p \ [p]) a)                                   ; a whole payload folded to one element
   (tag f a) (pmap (p \ [(f p)]) a)                              ; ..and that element built into a node
   (dflt a v) (alt a (pmap (_ \ [v]) eps))                       ; a always yields one element, v when absent
   (parse p s) (p s (r \ x \ r @ "" x) ())     ; strict: whole input must parse
   (runp p s)  (p s 0 ()))                           ; lenient: keep the payload, ignore trailing slack

) ; module peg

; re -- the POSIX regex engine, BRE and ERE. love has no regex syntax, so this is
; the door: (rebre p) / (reere p) compile a pattern, (rehas ns s) and
; (refind ns s i) run it. pure -- no i/o, no seat -- and peg's peer: a module the
; boot never splices, so each consumer opens with its own top-level (use 're).
; grep lives on in src/apps/kore/re.l, which reads four names off this splice.
;
; lawed in src/apps/kore/law.l: hand laws plus a seeded differential fuzz against an
; independent Brzozowski-derivative oracle, and grep is smoked byte-identical
; against GNU in `make test_kore`.
;
; two dialects, one parser: BRE and ERE differ only in which sigils wear a
; backslash, so `reparse` takes the dialect as a flag and `esc?` is the whole
; seam -- ( ) | { } + ? are bare in ERE and \-escaped in BRE, while * . [ ^ $
; are bare in both. (rebre p) and (reere p) are its two doors.
;
; the surface: literals, `.`, `*`, `+`, `?`, `{n,m}` intervals, `|` alternation,
; `^` and `$` (anchors anywhere in ERE; in BRE where nothing is read yet or left,
; which is GNU's rule -- see `bol?` and `eol?`),
; ( ) groups, and [..] classes with ranges, ^-negation, and the twelve POSIX
; [:name:] classes (a first `]` is literal, an edge `-` is literal). out of
; scope, refused by the parser in both dialects: backrefs (\1..\9).
;
; the ragged edges were read off GNU, not guessed, because the differential is
; what says so: a repeat with nothing to repeat is a literal in BRE (`\{2\}` is
; the text {2}) and dropped in ERE (`-E '*a'` is `a`, GNU warns and carries on);
; a brace that never closes and a `)` with nothing open are literals in ERE and
; malformed in BRE. an empty alternative branch is legal in both and matches the
; empty text. an inverted interval (`{3,2}`) is malformed in both.
;
; shapes: (rebre p) / (reere p) answer (1 nodes ngroups) or () on a malformed
; pattern -- uread's success shape, since the empty pattern's nodes are
; legitimately (). a node is ['chr c] | ['any] | ['cls neg ([lo hi]..)] | ['bol]
; | ['eol] | ['grp idx nodes] | ['rep atom lo hi] | ['alt (nodes..)], hi () for
; unbounded; groups number in ( order from 1. (rehas nodes s) answers the
; boolean face; (refind nodes s i) the leftmost match at-or-after i as
; (1 start end spans), spans an ([idx start end]..) with the newest pin of each
; group first -- (..)*'s \1 is the last iteration, like GNU; read it with assoc.
; matching is greedy backtracking in continuation style, so alternation is just
; one more node that tries its branches in order on the winning path.
(module 're
(:
   ; -- the twelve POSIX [:name:] classes, each written once as its ranges --
   cnames '(("alnum" (48 57) (65 90) (97 122))  ("alpha" (65 90) (97 122))
            ("blank" (9 9) (32 32))             ("cntrl" (0 31) (127 127))
            ("digit" (48 57))                   ("graph" (33 126))
            ("lower" (97 122))                  ("print" (32 126))
            ("punct" (33 47) (58 64) (91 96) (123 126))
            ("space" (9 13) (32 32))            ("upper" (65 90))
            ("xdigit" (48 57) (65 70) (97 102)))
   ; the `:` of a closing `:]` at-or-after j -> (1 j) | (). the presence wrapper,
   ; not a bare index: a `:]` can legitimately sit at 0 and 0 nets blue
   (recend p n j)
    (? (n <= j + 1) ()
       (p j = 58 && p (j + 1) = 93) [1 j]
       (recend p n (j + 1)))
   ; a class body at i (past [ and any ^): `first` keeps a leading ] literal.
   ; answers (items j) | (), items an ([lo hi]..). one scanner, both dialects --
   ; POSIX spells the bracket expression the same in BRE and ERE
   (recitems p n i first acc) (n > i ? (: c (p i)
    (? (c = 93 && !first) [acc (i + 1)]
       (c = 91 && i + 1 < n && p (i + 1) = 58)
        (recend p n (i + 2) @ [_ e]
          (assoc (snip p (i + 2) e) cnames @
           (_ . rs) (recitems p n (e + 2) 0 (cat rs acc))))
       (i + 2 < n && p (i + 1) = 45 && p (i + 2) != 93)
        (recitems p n (i + 3) 0 ([c (p (i + 2))] . acc))
       (recitems p n (i + 1) 0 ([c c] . acc)))))

   ; -- the parser, both dialects: pattern text -> (1 nodes ngroups) | () --
   (reparse p ere?)
    (: n #p
       ; the one seam between the dialects: ( ) | { } + ? are bare in ERE and
       ; \-escaped in BRE, so they are asked for here and nowhere else. * . [ ^ $
       ; are bare in both and are read straight off the byte.
       bw (ere? ? 1 2)
       ; an if/else, not (ere? && bare) || escaped: the || falls through to the
       ; BRE arm whenever ERE's own test fails, and `\(` is a literal paren in ERE
       (esc? i ch) (ere? ? (i < n && p i = ch) (i + 1 < n && p i = 92 && p (i + 1) = ch))
       (dig? c) (48 <= c <= 57)
       (rnum i v got) (? (i < n && dig? (p i)) (rnum (i + 1) (v * 10 + p i - 48) 1) got [1 v i])
       ; the interval body at i (past the opening brace) -> (lo hi j) | (), j past
       ; the close. {n} is (n n), {n,} unbounded, {n,m} both ends
       (rivl i)
        (: (clo j) (esc? j 125)
           (rnum i 0 0 @ [_ lo j]
             (? (clo j) [lo lo (j + bw)]
                (j < n && p j = 44)
                 (rnum (j + 1) 0 0 @ [_ hi j2] (clo j2 ? [lo hi (j2 + bw)])
                                    (clo (j + 1) ? [lo () (j + 1 + bw)])))))
       ; can a repeat land? nothing repeats an anchor or an empty head
       (repable acc) (two? acc && !(member? <<acc '(bol eol)))
       ; where a sigil is an anchor. POSIX leaves BRE's answer undefined outside
       ; the head and the tail; GNU and busybox both read `^` wherever nothing has
       ; been read yet -- the head, or just past `\(` or `\|`, which is exactly an
       ; empty acc, since a group and a branch each open a fresh pseq -- and `$`
       ; wherever nothing is left to read: the tail, or a `\)` or `\|` next. that
       ; is purely syntactic, so `\(a$\)b` anchors and then cannot match. anywhere
       ; else the sigil is ink. ERE anchors anywhere, so ere? short-circuits both
       (bol? acc) (ere? || !(two? acc))
       (eol? i) (ere? || (i + 1 = n) || (esc? (i + 1) 41) || (esc? (i + 1) 124))
       ; where it cannot: BRE keeps the sigil as a literal charm, ERE drops it
       (nofit i acc lvl gi c w)
        (? ere? (pseq (i + w) acc lvl gi)
           (pseq (i + w) (['chr c] . acc) lvl gi))
       ; a brace that never closes, and a `)` with nothing open: literal in ERE,
       ; malformed in BRE
       (loose i acc lvl gi c w)
        (? ere? (pseq (i + w) (['chr c] . acc) lvl gi) ())
       ; one alternative: stops at the bar, the group close, or the end. acc is
       ; reversed; lvl counts open groups, gi the groups seen (their ( order
       ; numbers them). answers (nodes j gi why), why = end | close | bar
       (pseq i acc lvl gi)
        (? (n <= i) [(rev acc) i gi 'end]
           (esc? i 124) [(rev acc) (i + bw) gi 'bar]
           (esc? i 41) (? (0 < lvl) [(rev acc) (i + bw) gi 'close]
                          (loose i acc lvl gi 41 bw))
           (esc? i 40)
            (: g2 (gi + 1)
               (palt (i + bw) (lvl + 1) g2 @ [nds j g 'close]
                 (pseq j (['grp g2 nds] . acc) lvl g)))
           (esc? i 43) (? (repable acc)
                          (pseq (i + bw) (['rep <acc 1 ()] . >acc) lvl gi)
                          (nofit i acc lvl gi 43 bw))
           (esc? i 63) (? (repable acc)
                          (pseq (i + bw) (['rep <acc 0 1] . >acc) lvl gi)
                          (nofit i acc lvl gi 63 bw))
           ; the ere drop is of the whole {n,m}, which is why rivl runs first even
           ; when nothing can be repeated: skipping just the brace leaves `2}` behind
           ; as literals, and `-E '{2}'` would match nothing where GNU matches all
           (esc? i 123)
            (rivl (i + bw) @ [lo hi j]
              (? (hi && lo > hi) ()                    ; {3,2}: malformed in both
                 (repable acc) (pseq j (['rep <acc lo hi] . >acc) lvl gi)
                 ere? (pseq j acc lvl gi)
                 (nofit i acc lvl gi 123 bw))
              (loose i acc lvl gi 123 bw))
           (: c (p i)
              (? (c = 42) (? (repable acc)
                             (pseq (i + 1) (['rep <acc 0 ()] . >acc) lvl gi)
                             (nofit i acc lvl gi 42 1))
                 (c = 46) (pseq (i + 1) ('(any) >< acc) lvl gi)
                 (c = 94 && bol? acc) (pseq (i + 1) ('(bol) . acc) lvl gi)
                 (c = 36 && eol? i) (pseq (i + 1) ('(eol) . acc) lvl gi)
                 (c = 91)
                  (: j (i + 1)
                     neg (j < n && p j = 94)
                     (recitems p n (? neg (j + 1) j) 1 () @ [items j2]
                       (pseq j2 (['cls (? neg 1 0) items] . acc) lvl gi)))
                 (c = 92)
                  (n <= i + 1 ? ()
                     (: d (p (i + 1))
                        (49 <= d <= 57 ? () ; backrefs: refused, both dialects
                           (pseq (i + 2) (['chr d] . acc) lvl gi))))
                 (pseq (i + 1) (['chr c] . acc) lvl gi))))
       ; the alternation above the sequence: branches joined by the bar, kept flat
       ; in one ['alt ..] node so a three-way reads as three branches
       (palt i lvl gi)
        (: (go j g acc)
            (pseq j () lvl g @ [nds j2 g2 why]
              (: acc2 (nds >< acc)
                 (? (why = 'bar) (go j2 g2 acc2)
                    (: brs (rev acc2)
                       [(two? >brs ? [['alt brs]] <brs) j2 g2 why]))))
           (go i gi ()))
       (palt 0 0 0 @ [nds _ g 'end] [1 nds g] ()))
   (rebre p) (reparse p ())
   (reere p) (reparse p 1)

   ; -- case folding, as an AST pass: -i never reaches the matcher --
   ; the other case of a letter, or () for anything else
   (recase c) (? (65 <= c <= 90) (c + 32) (97 <= c <= 122) (c - 32))
   ; the part of [lo hi] lying in [a b], shifted by d -- how a range gains its mirror
   (rovl lo hi a b d)
    (: x (lo < a ? a lo)
       y (b < hi ? b hi)
     (x <= y ? [[(x + d) (y + d)]]))
   (refoldr rs)
    (catmap (\ [lo hi] (cat (rovl lo hi 97 122 -32) (rovl lo hi 65 90 32))) rs)
   ; a literal becomes the two-charm class, a class gains its mirror ranges, and
   ; everything with children recurses. the matcher is untouched by -i
   (refold nds)
    (map (\ nd
           ; not (recase c @ () .. m ..): pat.l reads () as the form at zero, which
           ; asks nothing and so fits everything. presence here is a plain test
           (nd @ ['chr c]      (: m (recase c) (? m ['cls 0 [[c c] [m m]]] nd))
                 ['cls neg rs] ['cls neg (cat rs (refoldr rs))]
                 ['grp gi sub] ['grp gi (refold sub)]
                 ['alt brs]    ['alt (map refold brs)]
                 ['rep a lo hi] ['rep <(refold [a]) lo hi]
                 nd))
         nds)

   ; -- the matcher: greedy backtracking in continuation style, compiled --
   ; a node list becomes one lambda of (s i sp k), once, before any text is read.
   ; the shape walk and the class ranges are spent there, so what a character costs
   ; at match time is a call and a compare. the node vocabulary is renode's arm list
   ; -- a shape with no arm there cannot be built above
   ; does charm c sit in a class of these ranges, negated or not?
   (rcls neg rs c)
    (: hit (any (\ [lo hi] (lo <= c <= hi)) rs) (? neg !hit hit))
   ; the class as a 256-wide membership table: a range walk per charm was the whole
   ; cost of [a-z], and the table is one native string index
   (recls neg rs)
    (: o (jug 0)
       (go c) (? (255 < c) (slurp o)
                 (: _ (put o (? (rcls neg rs c) 1 0)) (go (c + 1))))
       tbl (go 0)
       (\ c (? (c <= 255) (tbl c) (rcls neg rs c))))
   ; the program a caller holds: the matcher, whether the pattern can only match at
   ; 0, and a skipper -- the walk's way of reaching the next position that could
   ; start a match instead of asking the matcher about every one. `^` used to be
   ; asked its one failing question at every byte of the line, and a literal used to
   ; be asked its first charm at every byte too
   (recomp ns) (: c (refirst ns)
                  [(recompm ns) (reanch ns)
                   (? (nil? c) ()
                      (: sc ((from 'scan 'scanner) ())      ; at compile time: never at a
                         (\ s i n (: j (sc s c i)          ; module binding, which bakes
                                     (j < 0 ? n j)))))])
   ; the charm a match must open with, or (). only ever answered for a first node
   ; that has to consume one -- a repeat that can take nothing answers (), so the
   ; skip never steps over a match. nil? is zero?, so a NUL needle reads as absent
   ; here and simply declines the skip
   (refirst ns)
    (ns @ (nd >< _)
       (nd @ ['chr c]       c
             ['grp _ sub]   (refirst sub)
             ['rep a lo hi] (0 < lo ? (refirst [a]) ())
             ['alt brs]     (: cs (map refirst brs)         ; every branch, or nothing
                               (? (any nil? cs) ()
                                  (all (\ c (c = <cs)) cs) <cs
                                  ()))
             ())
       ())
   (recompm ns)
    (ns @ (nd >< rest) (renode nd (recompm rest))
          (\ s i sp k (k i sp)))
   ; anchored: a leading `^`, or a shape whose every path opens with one. a `^`
   ; anywhere else is not the head of this list and answers 0, which is the walk
   (reanch ns)
    (ns @ (nd >< _)
       (nd @ ['bol]       1
             ['grp _ sub] (reanch sub)
             ['alt brs]   (all reanch brs)
             0)
       0)
   (renode nd tail)
    (nd @ ['chr c]      (\ s i sp k (i < #s && s i = c ? (tail s (i + 1) sp k)))
          ['any]        (\ s i sp k (i < #s ? (tail s (i + 1) sp k)))
          ['cls neg rs] (: p (recls neg rs)
                           (\ s i sp k (i < #s && p (s i) ? (tail s (i + 1) sp k))))
          ['bol]        (\ s i sp k (i = 0 ? (tail s i sp k)))
          ['eol]        (\ s i sp k (i = #s ? (tail s i sp k)))
          ['grp gi sub] (: b (recompm sub)
                           (\ s i sp k
                              (b s i sp (\ j sp2 (tail s j ([gi i j] . sp2) k)))))
          ; alternation: the branches in order on the winning path, each with the
          ; tail as its onward; a branch that fails answers () so the next is asked
          ['alt brs]    (: bs (map recompm brs)
                           (\ s i sp k
                              (: (try l)
                                  (l @ (b . more)
                                     (b s i sp (\ j sp2 (tail s j sp2 k)) || try more))
                                 (try bs))))
          ['rep a lo hi] (: ab (recompm [a])
                            (\ s i sp k (rrepc ab lo hi tail s i sp k 0))))
   ; the repeat: try one more (progress required), else the tail once fed.
   ; an empty iteration cannot repeat -- that guard is what stops `\(\)*` spinning
   ; -- but it still satisfies the minimum, all at once. without that second half
   ; `a*\+\+` demands an `a`, because the inner a* matches empty, the empty is
   ; refused, and the outer's lo=1 is never met: GNU matches every line there and
   ; we matched only the ones with an a. (the seeded fuzz found it, not a human.)
   (rrepc ab lo hi tail s i sp k cnt)
    (: more (? (!hi || cnt < hi)
               (ab s i sp
                   (\ j sp2 (j = i ? (cnt < lo ? (tail s j sp2 k))
                              (rrepc ab lo hi tail s j sp2 k (cnt + 1)))))
               ())
       (? more more
          (cnt < lo) ()
          (tail s i sp k)))
   ; the boolean face: does s contain a match anywhere. the continuation answers
   ; (1 j), never (j): a match ending at 0 would net blue and read as absence
   (rehasm m s)
    (: f <m n (<>m ? 0 #s)                        ; anchored: the walk ends where it starts
       sk <>>m
       (from i) (? (f s i () (\ j sp [1 j])) 1
                   (i < n) (from (i + 1)))
       (jump i) (: j (sk s i n)                   ; only the positions that could open
                   (? (n <= j) ()
                      (? (f s j () (\ e sp [1 e])) 1 (jump (j + 1)))))
       ((nil? sk || <>m) ? (from 0) (jump 0)))
   ; the node-list faces: they compile and then match, for a caller with one text to
   ; ask about. a caller with many -- grep, sed, awk -- holds the matcher instead
   (rehas ns s) (rehasm (recomp ns) s)
   ; the leftmost span at-or-after i: (1 start end spans) | () -- uread's success
   ; shape, since the empty match at 0 is the span (0 0), blue by measure. greedy
   ; end: the span the substitution tools take; spans feed \1
   ; the leftmost span at-or-after i whose (start end) passes p. p rides inside
   ; the continuation, which is the whole trick: a span it rejects makes `rem`
   ; answer (), and the greedy backtracker then tries the other lengths at that
   ; start before the start moves on. a filter applied to refind's answer cannot
   ; do that -- it only ever sees the greedy span. -w is where it shows: `a*.` on
   ; "a._c_" is word-bounded at "a" and not at the greedy "a.", and the outside
   ; filter calls that line a miss where GNU calls it a hit
   (refindpm m s i p)
    (: f <m n (<>m ? i #s)                        ; anchored: the walk ends where it starts
       sk <>>m
       (from j) (f s j () (\ e sp (p j e ? [1 e sp])) @ [_ e sp] [1 j e sp]
                  (? (j < n) (from (j + 1)) ()))
       (jump j) (: j2 (sk s j n)                  ; only the positions that could open
                   (? (n <= j2) ()
                      (f s j2 () (\ e sp (p j2 e ? [1 e sp])) @ [_ e sp] [1 j2 e sp]
                        (jump (j2 + 1)))))
       ((nil? sk || <>m) ? (from i) (jump i)))
   (refindm m s i) (refindpm m s i (\ a b 1))
   (refindp ns s i p) (refindpm (recomp ns) s i p)
   (refind ns s i) (refindm (recomp ns) s i)
)

) ; module 're

; verbs -- the registry behind `love mooncc ..`, `love cook ..`, and a `sed` symlink onto
; the artifact. one symbol-keyed tablet, mutated in place: (from 'verbs 'tab) hands the
; real tablet, not a copy, and `pin` is the door. registered, never spliced -- tab/word/
; seat are not names to reach bare, and `get` would shadow half the tree.
;
; two front doors, because the two dispatch lanes carry different shadow rules:
;   (word w)  a leading positional -- cli's rail. refuses a `/` or a `.l`, so with
;             fifty applets registered `make`, `env`, `true` and `cmp` cannot eat a local
;             script of the same name; `love ./up` and `love -- up` stay the file.
;   (seat p)  argv[0] -- src/host/main.c's door, which fires before the cli runs at all (a bare
;             `seed` at argc 1 wants its usage). always a path, so the basename decides.
; a verb takes the args after its name and answers a status charm; the rail quits with it.
; that is kore's convention, and it is why `love kore sed ..` nests.
(module '(verbs any? bn dash fire get seat seatof tab word)
(: tab {}   ; nil? when empty, like every empty -- ask it with peep, not by testing it
   get tab
   (bn p)    (: n #p
                (go k r) (k < n ? (go (k + 1) (p k @ 47 (k + 1) r)) (snip p r n))
                (go 0 0))
   (dotl? w) (: n #w (2 < n && snip w (n - 2) n = ".l"))
   (sl? w)   (: n #w (go i) (? (n <= i) 0 (w i = 47) 1 (go (i + 1))) (go 0))
   (word w)  (sl? w || dotl? w ? () (get (name w)))
   seat  (get * name * bn)
   (putln k) (puts (string k), putc 10)
   ; `love verbs` -- one name per line, for a pipe. sorted: a tablet's key order is its own
   ; business and would read like a change.
   (vsort ws) (ws @- ws (p . s)
               (: r (vsort s)
                (ins x l) (l @- [x] (a . u) (string x < string a ? (x . l) (a . ins x u)))
                (ins p r)))
   _ (pin tab 'verbs (\ as (map putln * vsort $ keys tab,
                            flush out)))

   ; --- the seat scan, the third door ---
   ; a file that is the program seats itself: `love src/apps/moon/moon.l foo.c`, the installed
   ; shebang's `-l`, a catted script under its own name. no name was typed, a path was.
   ;   (fire ws)      -> (seat-word . args-after) over this invocation's line, else ()
   ;   (seatof ws a)  the same over a list handed in
   ; a bake pins no `cmdline` (src/host/main.c), which leaves the read below a lookup: nothing
   ; typed, nothing seats. () means "not seated", the presence answer -- ask it with two?.
   (dash w)    (0 < #w && w 0 = 45 ? (snip w 1 #w) w)   ; -sh: login(1)'s mark
   (any? w (a . u)) (a = w || any? w u)
   (mine? ws w) (any? (dash (bn w)) ws)
   ; no arm answers () -- seats someone else, not me
   (seatof ws a) (? (one? a) ()
                    (<a = "-l") (two? >a ?                     ; a preload named for me seats
                                 (mine? ws <>a ? (<>a . >>a) (seatof ws >>a)))  ; me -- the shebang's lane
                    (mine? ws <a) (<a . >a))
   (fire ws)   (seatof ws (? (member? 'cmdline (names ())) >cmdline ())))

) ; module verbs

; cli -- the console and command line: the read-eval-print loop, its multi-line line
; editor, the stream shell (read/reads), the floor handler (welp), the port-driven line
; reader (edraw/edln/edlnc) that lush drives, and the host command line, read left to
; right after the program-name head:
;   (cli-rail ln)     the walk over ln = (program-name . args)
;   (cli-line ln tty) a frontend's whole tail: the argv[0] door, the rail, the repl, stdin
; src/host/main.c calls cli-line, and so does a forked lush child -- a word whose PATH winner
; is this binary need not exec, and what it would have exec'd is (cli-line its-line) on a
; warm heap. the shadow rule lives in one place, verbs' `word`. prel and pat
; must be up before this compiles: @ reads here, and a macro reaches a reader only once its
; layer is spliced.

(module '(cli read reads forms shell welp edraw edln edlnc cli-rail cli-line
          edleft edright edbsp eddel edhome edend edtop edbot edup eddown uphist downhist
          detach emptybuf mkframe parses joinln flatten splitat parseall)
(: (read s) (sound (hot? s ? (flow s) s) @ (x . _) (ev x)))
(: (reads p)
   (: (walk cl z) (sound cl @ 'torn (scare 'unfinished-form p)
                              (a . b) (walk b (ev a))
                              z)
      ; the shared lane, for `in`: gulp for speed, hold nothing across an eval. box slot 0 counts
      ; every byte drawn off p, so the walk can put the port where it belongs. no window on purpose:
      ; a straddling `;` comment would end one cleanly and the next reads the prose as code.
      box {}
      (drew u) (peep box 0 0)
      ; absolute, not relative -- p is already behind us, so a plain (unchug p rem) re-reads the run
      (drop n) (unchug p (n - inhand p))     ; the port to n pending; we hold the rest
      ; flow, plus the count: one chug per gulp, the run laid down as plain conses.
      (feed u)
       (see p @ -1 () c
        (: _ (unsee p c)
           t (chug p)
           _ (pin box 0 (drew () + #t))
           (go k l) (0 >= k ? l (: j (k - 1) (go j (t j . l))))
         (go #t (once (\ u (feed ()))))))
      ; consumed, forwards and by identity. never (tally >r) -- the residue is lazy, so that
      ; forces the whole rest; and force at every step, or a plain `cup` walk stops dead at a
      ; gulp boundary and spins on () forever. `once` memoizes, so re-forcing is free.
      (frc x) (lit? x ? (x ()) x)
      (upto a b n) (: aa (frc a) bb (frc b)
                      (? (= aa bb) n
                         (two? aa)   (upto (cup aa) bb (n + 1))
                         n))
      ; with no window both endings are honest -- they can only mean the stream itself ended
      (step cl walked z)
       (sound cl @
         'torn (scare 'unfinished-form p)
         (a . b) (: k (upto cl b 0)
                    w2 (walked + k)
                    rem (drew () - w2)
                    ; one byte short on purpose -- the byte-exact lane runs one ahead, and test_stdincorpus diffs it
                    _ (drop (0 < rem ? (rem - 1) 0))
                    h (inhand p)
                    v (ev a)
                    (h = inhand p ? (drop 0, step b w2 v)
                                    (start (two? b ? [<b]) v)))
         (drop 0, z))
      (start pre z)
       (see p @
        -1 (atom? pre ? z (walk pre z))
        c (unsee p c,
           inhand p ? (pin box 0 #pre, step (cat pre (feed ())) 0 z)
                      (walk (cat pre (trickle p)) z)))
      ; never rebind `in` -- this identity folded at egg-compile, so a fresh port fails it in silence
      (? (= p in) (start () 0) (walk (flow p) 0))))
(: (forms p)
   ((: (g cl acc) (sound cl @ 'torn (scare 'unfinished-form p)
                              (a . b) (g b (a . acc))
                              (rev acc)))
    (flow p) ()))

(: m (nom 0) eofsym (nom 0)

   (want n) (member? n (names ()) ? (ev n) ())
   raw (want 'raw)


   (rdall cl acc)
    (sound cl @ 'torn m                            ; unfinished shape -> more
                (a . b) (rdall b (a . acc))
                (rev acc))                         ; a clean end -> the datums, in order
   (parseall cl)
    (rdall cl () @ ^m  m                           ; unfinished shape
                   [a] [a]                         ; one datum: as-is (leading monadic preserved)
                   ds  (two? ds ? [ds]))           ; many: the application; a blank line: ()

   ; --- editor ---

   ; intersperse a list of charlists with newlines, in order
   (joinln ls)
    (ls @ (a . b) (atom? b ? a (a + (10 . joinln b))))

   ; flatten the editor state into one charlist suitable for parseall
   (flatten u l r d)
     (joinln (revcat u (revcat l r . d)))

   ; walk xs forward taking n chars into acc (reversed); when done
   ; call k with (rev (take n xs)) and (drop n xs). stops cleanly at
   ; end-of-xs even if n exceeds the list length.
   (splitat k acc n xs)
    (xs @ ((ax . ux) && 0 < n) (splitat k (ax . acc) (n - 1) ux)
     (k acc xs))

   ; map non-printables to space; otherwise pass through
   (prc c) (putc $ 32 <= c < 127 ? c 32)

   ; line editor buffer zipper arguments
   ; u up (reversed), l left (reversed), r right, d down
   (edleft k u l r d)
    (l @ (al . ul) (k u ul (al . r) d)
     (u @ (au . uu) (k uu (rev au) () (revcat l r . d))
      (k u l r d)))
   (edright k u l r d)
    (r @ (ar . ur) (k u (ar . l) ur d)
     (d @ (ad . ud) (k (revcat l r . u) () ad ud)
      (k u l r d)))
   (edbsp k u l r d)
    (l @ (_ . ul) (k u ul r d)
     (u @ (au . uu) (k uu (rev au) r d)
      (k u l r d)))
   (eddel k u l r d)
    (r @ (_ . ur) (k u l ur d)
     (d @ (ad . ud) (k u l ad ud)
      (k u l r d)))
   (edhome k u l r d) (k u () (revcat l r) d)
   (edend  k u l r d) (k u (revcat r l) () d)

   ; edtop / edbot jump across the whole buffer: cursor at the start of
   ; the topmost line / end of the bottommost line. on a single-line
   ; buffer they degenerate to edhome / edend.
   (edtop k u l r d)
    (rev u @ (au . uu) (k () () au (uu + (revcat l r . d)))
     (k u () (revcat l r) d))
   (edbot k u l r d)
    (rev d @ (ad . ud) (k (ud + (revcat l r . u)) (revcat ad ()) () ())
     (k u (revcat r l) () d))
   (edup k u l r d)
    (u @ (au . uu)(splitat (\ lz rr (k uu lz rr (revcat l r . d))) () #l au)
     (k u l r d))
   (eddown k u l r d)
    (d @ (ad . ud) (splitat (\ lz rr (k (revcat l r . u) lz rr ud)) () #l ad)
     (k u l r d))

   ; --- history zipper ---

   ; pack the buffer's four halves into one slot for history storage.
   (mkframe u l r d) (u . l . r . d)

   ; if cur holds a pristine recall, restore it at its slot in hu;
   ; called before any mutating edit so the original survives.
   (detach hu cur) (two? cur ? (cur . hu) hu)

   (emptybuf u l r d) (!u && !l && !r && !d)
   (parses u l r d)   (two? (parseall (flatten u l r d)))

   ; up/down through the history zipper. on a normal pop, push the
   ; current buffer onto the other side (skipping if empty); if the
   ; other side is empty (hu or hd) but we're on a real recall (cur
   ; non-nil) and the buffer parses, push and scroll into a fresh
   ; empty line.
   (uphist k u l r d hu hd cur)
     (? (two? hu)
        (: e <hu
           nhd (? (emptybuf u l r d) hd (mkframe u l r d . hd))
           (k <e <>e <>>e >>>e >hu nhd e))
        (two? cur && parses u l r d)
        (: nhd (mkframe u l r d . hd)
           (k () () () () hu nhd ()))
        (k u l r d hu hd cur))
   (downhist k u l r d hu hd cur)
     (? (two? hd)
        (: e <hd
           nhu (? (emptybuf u l r d) hu (mkframe u l r d . hu))
           (k <e <>e <>>e >>>e nhu >hd e))
        (two? cur && parses u l r d)
        (: nhu (mkframe u l r d . hu)
           (k () () () () nhu hd ()))
        (k u l r d hu hd cur))

   ; 0 is the miss, read with id? -- an event code nets red, so truth cannot tell hit from miss
   arrow    {68 -1 67 -2 65 -8 66 -9 72 -5 70 -6}    ; ESC [ F -- the plain finals
   modarrow {68 -1 67 -2 65 -8 66 -9 72 -10 70 -11}  ; ESC [ 1 ; M F -- modified home/end jump the buffer
   evk      {-1 -7 4 -7 3 -12 13 10 10 10 8 -3 127 -3 1 -5 5 -6}   ; the raw control bytes
   (edesc1 c) (? (c = 126) -5
                 (c = 59)  (getc 0, peep modarrow (getc 0) 0))
   (edesc x)
    (? !(91 = getc 0) 0
     (: c (getc 0) e (peep arrow c 0)
      (? !(= e 0) e
       (c @ 49 (edesc1 (getc 0))
            55 (getc 0, -5)
            (52 || 56) (getc 0, -6)
            51 (getc 0, -4)
            0))))

   (edev x)
    (: c (getc 0) e (peep evk c 0)
     (? !(= e 0) e
        (c = 27) (edesc 0)
        (32 <= c < 127 ? c)))

   ; redraw the buffer in place. pra is rows above the cursor from the previous
   ; render -- move up that many first, so we land back on the prompt's row. all
   ; motion is relative, so terminal scrolling never desyncs us. pl is the prompt's
   ; column; the topmost line shares it, later lines start at column 0.
   (csi n f) (putc 27, putc 91, putn n, putc f)   ; ESC [ n f -- the one cursor verb
   (edrender pl pra u l r d)
     (: _ (0 < pra ? (csi pra 65),
           putc 13,
           0 < pl ? (csi pl 67),
           putc 27, putc 91, putc 74, ; clear to end of screen
           each (rev u) (\ ln (each ln prc, putc 10)),
           each (revcat l r) prc,
           each d (\ ln (putc 10, each ln prc)))
        ld (tally d)
        col ((two? u ? 0 pl) + tally l)
        (0 < ld ? (csi ld 65),
         putc 13,
         0 < col ? (csi col 67),
         flush out))

   ps1 "> "
   ; the helm glows in the crew's cyan (256-colour 117 ~ #7dcfff), reset after.
   ; SGR is zero-width to both the host terminal and the inle console (src/core/quay/quay.c),
   ; so `pl` below stays (tally ps1) and the cursor math is undisturbed.
   ps1c (string 27 + "[38;5;117m" + ps1 + string 27 + "[39m")

   ; print the prompt, then dispatch events until ^D or a submitted buffer.
   ; returns eofsym on ^D, else (vs . nhu) so the repl can thread history.
   (edline hu hd)
     (: pr ps1
        _ (puts ps1c)
        pl (tally pr)
        (loop pra u l r d hu hd cur)
          (: _ (edrender pl pra u l r d)
             npra (tally u)
             (kloop uu lz rr dd) (loop npra uu lz rr dd hu hd cur)
             (kedit uu lz rr dd) (loop npra uu lz rr dd (detach hu cur) hd ())
             (khist uu lz rr dd nhu nhd ncur) (loop npra uu lz rr dd nhu nhd ncur)
             ; the dispatch stays a chain, not a table: every arm runs a different
             ; continuation over the live buffer, so a table would hold closures
             ; built per keystroke. the tables above work because their arms are constants.
             (edev 0 @
              -7 eofsym
              ; enter cashes the buffer as long as it parses complete
              10 (parseall (flatten u l r d) @
                  ^m (loop npra (rev l . u) () r d (detach hu cur) hd ())
                  vs (two? d ? (csi (tally d) 66) (),
                      putc 10,
                      [vs (!vs ? (revcat hd (detach hu cur))
                           (take 100 (mkframe u l r d . revcat hd (detach hu cur)))) ]))
              (c && 0 < c) (loop npra u (c . l) r d (detach hu cur) hd ())
              -1 (edleft  kloop u l r d)
              -2 (edright kloop u l r d)
              -3 (edbsp   kedit u l r d)
              -4 (eddel   kedit u l r d)
              -5 (edhome  kloop u l r d)
              -6 (edend   kloop u l r d)
              -8 (two? u ? (edup    kloop u l r d)
                           (uphist   khist u l r d hu hd cur))
              -9 (two? d ? (eddown  kloop u l r d)
                           (downhist khist u l r d hu hd cur))
              -10 (edtop kloop u l r d)
              -11 (edbot kloop u l r d)
              -12 (puts "^C\n", emptybuf u l r d ? eofsym (edline hu hd))
              (loop npra u l r d hu hd cur)))
        (loop 0 () () () () hu hd ()))

   ; evaluate a single parsed datum cooperatively.
   (do_eval v)
     (: pid (twirl ev v)
        (poll _)
          (? (landed? pid) (putx (catch pid), -1)   ; the answer
             (cue? 0) 
             (getc 0 @ 3 (puts "^C", freeze pid, -1) (poll ()))
             (rest 0, poll ()))
        (poll ()))

   ; the read-eval-print loop proper. the host and kernel frontends start the
   ; shell via (shell 0), which calls (repl 0 0).
   (repl hu hd)
    (edline hu hd @ ^eofsym 0
                    (vs . nhu . nhd) (each vs (\ v (do_eval v, putc 10)), repl nhu nhd))

   ; no-op () returning scare handler
   (welp a b) ()

   ; the face a raise wears -- ;; a b. a program's raise wears no help at all: it leaves
   ; the eval as a scare, and the frontend prints the same face and quits 1
   (hface a b) (say err ";; ", print err a, say err " ", print err b, put err 10)
   (shell-help a b) (hface a b, welp a b)
   (shell _)
    (hear shell-help,             ; the prompt survives every raise; a script must not
     raw 1,
     puts $ ";3 love " love-version "\n",
     repl 0 0)

   (besc1 ip c)
    (c @ 126 -5                               ; a line reader never jumps the buffer:
         59  (see ip, peep arrow (see ip) 0)) ;   the plain finals
   (besc ip) (see ip != 91 ? 0
    (: c (see ip) e (peep arrow c 0)
     (? !(= e 0) e
      (c @ 49        (besc1 ip (see ip))
           55        (see ip, -5)
           (52 || 56) (see ip, -6)
           51        (see ip, -4)
           0))))
   ; the `see` comes first and exactly once -- evk is indexed by the byte, so peeping before
   ; reading has nothing to peep with
   (bev ip) (: c (see ip) e (peep evk c 0)
               (? !(= e 0) e
                  (c @ 27 (besc ip)
                       9  -13          ; Tab -> the completion event (edlnc's; others ignore)
                       (32 <= c < 127 ? c))))

   ; (edraw ip pr) -- read one line off port `ip`, with in-line editing
   (edraw ip pr)
     (: pl (tally (puts pr))
        (loop l r)
          (: _ (edrender pl 0 () l r ())
             (km uu ll rr dd) (loop ll rr)         ; motion: edleft/.. give (k u l r d), keep l r
           (bev ip @
            -7 eofsym
            10 (putc 10, revcat l r)
            (c && 0 < c) (loop (c . l) r)            ; insert a printable
            -1 (edleft  km () l r ())
            -2 (edright km () l r ())
            -3 (edbsp   km () l r ())
            -4 (eddel   km () l r ())
            -5 (edhome  km () l r ())
            -6 (edend   km () l r ())
            (loop l r)))
        (loop () ()))

   ; the shell line reader: edraw + command history
   (edlnc ip pr hist comp)
     (: pl (tally (puts pr)) hn (tally hist)
        (hnth k) <(drop k hist)                       ; hist[k], 0-based (k < hn)
        (loop l r i draft)
          (: _ (edrender pl 0 () l r ())
             (km uu ll rr dd) (loop ll rr i draft)     ; motion: index + draft kept
             (recall ni)                               ; jump to view index ni (0 = the draft)
               (: nd (i = 0 ? (revcat l r) draft)    ; save the live draft once, the instant up leaves it
                  ln (ni = 0 ? nd (hnth (ni - 1)))
                  (loop (rev ln) () ni nd))

             (bev ip @ -7 'eof
                10 (: ln (putc 10, revcat l r)
                      nh (!ln ? hist (take 100 (ln . hist)))
                    (ln . nh))
                (c && 0 < c) (loop (c . l) r i draft)
                -12 (puts "^C\n", () . hist)   ; ^C: abandon the line, hist untouched
                -13
                  (? !comp (loop l r i draft)
                     (: t (comp (revcat l ()))
                        (? !(two? t) (loop l r i draft)
                           (: l2 (foldl (a \ ch \ ch . a) l <t)
                              cs >t
                            (two? cs && two? >cs ?
                              (puts $ "\n" + foldl (a \ s \ 0 = #a ? s (a + "  " + s)) "" cs + "\n"),
                             loop l2 r i draft)))))
                -1 (edleft  km () l r ())
                -2 (edright km () l r ())
                -3 (edbsp   km () l r ())
                -4 (eddel   km () l r ())
                -5 (edhome  km () l r ())
                -6 (edend   km () l r ())
                -8 (recall (i >= hn ? i (i + 1)))   ; up: older
                -9 (recall (0 >= i  ? i (i - 1)))    ; down: newer
                (loop l r i draft)))
        (loop () () 0 ()))
   (edln ip pr hist) (edlnc ip pr hist ())
)


; the command line. the defglobs go through `ev` of a built (: nm 'v), and the inner quote
; is load-bearing -- without it ev takes the value apart as a form to run. argv reaches the
; program's view before (run ()) fires, which a loaded program reads.
;
; the exit door: every leave -- a bad -m, a missing operand, an unopenable file, a
; torn -e, a verb's own status -- scares 'cli-leave, and the trap handler answers its
; charm: the rail's answer is the status, and the frontend quits with it (or a caller in
; the same image reads it, where a spawn would hand it a dead process). nothing here
; quits -- the core spells no host word. the handler is written twice because a leave
; lands in either of two spans, `pre` and `run`, and the defglob has to sit between them.
(: (cli-rail ln)
 (: (charm0 x) (charm? x ? x 0)
    cli2
 (trap (\ x
 (: (cli-leave c) (scare 'cli-leave c)
    ; a kind test, not a match on (): a refusal answers a nom, and a nom is truthy
    (load1 p) (: q (open p "r")
                 (? (hot? q) (reads q) (say err $ "love: cannot open " + p, cli-leave 1)))
    (eval1 s) (: m (nom 0)                           ; a fresh nom: the unfinished shape, id?-safe
       (rdl x acc) (sound x @ 'torn      m           ; every top-level datum off the string, in order
                               (a . b)  (rdl b (a . acc))
                               (rev acc))
       (rdl s () @ ^m (say err "love: -e: unfinished form", cli-leave 2)
                   (d @ (a . u)) (ev $ atom? u ? a d))) ; many datums fold to one application
    (say1 s) (puts s, putc 10)             ; -v and -h each print and keep walking argv
    (version _) ("love " + love-version)   ; _ arg: love has no nullary calls
    (usage _)
    ("usage: love [wake IMAGE] [-l FILE] [-e EXPR] [-q] [-m SIZE] [-v] [-h] [--] [VERB|FILE] [ARG ...]\n" +
     "  -l, --load FILE   preload FILE (read-eval) before the program\n" +
     "  -e, --eval EXPR   eval EXPR as one expression (infix works), print the answer\n" +
     "  -q, --quiet       with -e: do not print the answer\n" +
     "  -m  --memory N    max heap in {k,m,g} default = 0m = unlimited\n" +
     "  -v, --version     print the version\n" +
     "  -h, --help        print this help\n" +
     "  --                end of options; the rest are files, and none of them is stdin\n" +
     "with no arguments at all love reads stdin; with arguments and no program it stops\n" +
     "when the command line runs out, so -v and -h compose and neither is terminal.\n" +
     "`love verbs` names the verbs this binary carries.\n")
    (need h '()) (say err $ "love: " + h + " needs an argument", cli-leave 2)
    K 1024 M 1048576 G 1073741824
    wordsz (charm? G ? 8 4)             ; 2^30 is a charm only where a fixnum is 62-bit
    ; validate here: a bad value reaching `tune` writes a non-Z tray, which the nif refuses
    ; whole and in silence, so the flag would read as accepted and do nothing. 0 is the
    ; unbounded spelling, which is why this floors at 0 rather than 1.
    (size h s) (: n #s
                  u (peep s (n - 1) 0 @ (107 || 75) K
                                        (109 || 77) M
                                        (103 || 71) G)
                  d (u && snip s 0 (n - 1) || s)
                  v <(sound d)                   ; bound, not inlined: a bare infix `//` in the
                                                 ; `:` body slot folds into the binding chain
                  (charm? v && v >= 0 ?
                   (v * (u || M) // wordsz)
                   (say err $ "love: " + h + ": not a size: " + s,
                    cli-leave 2)))
    ; -> (kind . rest): 'eval code.args / 'verb fn.args / 'file prog.args / 'stdin / 'none.
    ; 'none is the command line running out with no program named: -v and -h are not
    ; terminal, so `love -v -h` prints both, reaches the end, and leaves 0.
    (pre a) (a @ (h . t)
      (h @ ("-l" || "--load")    (need h t, load1 <t, pre >t)
           ("-v" || "--version") (say1 (version 0), pre t)
           ("-h" || "--help")    (say1 (usage 0), pre t)
           ("-e" || "--eval")    (need h t, 'eval . t)
           ("-q" || "--quiet")   (pre t @ ('eval . r) ('evalq . r) r r)
           ; slot 0 of a fresh `tune` read, so the other knobs ride and the last -m wins. it
           ; lands at the next collection: the opening pool was sized before argv was read.
           ("-m" || "--memory")  (need h t, tune (pin (tune ()) 0 (size h <t)), pre >t)
           "--"                 (t @ (_ . _) ('file . t) '(stdin))
           (from 'verbs 'word h @ '() ('file . a) f ('verb . f . a)))
      '(none))
    ; stdin is the answer to an empty command line, or to `--` with nothing after it --
    ; never to a line that carried flags and named no program.
    p (two? >ln ? (pre >ln) '(stdin))   ; runs -l preloads + -v/-h + -m; the program kind
    k <p
    av (k @ ('eval || 'evalq || 'verb) >>p >p)   ; the program's view of argv
    run (\ _
      (k @ 'eval  (puts * show $ eval1 <>p, putc 10, 0)  ; -e answers out loud through `show`, the
           'evalq (eval1 <>p, 0)      ; repl's face, not dot's raw one; -q mutes
           'verb  (: r (<>p >>>p)     ; a verb takes the args after its name and answers a status,
                     (cli-leave $ charm0 r))  ; out the one door
           'file  (load1 <>p, 0)
           'none  0                   ; the flags did their printing; leaving is the answer
           (reads in, 0)))
    [av run]))
       () (\ a b (a == 'cli-leave ? (charm0 b) (scare a b))))
 (? (charm? cli2) cli2                  ; a leave in pre: the status is the answer
    (ev [': 'argv ['\ <cli2]], ; the program's view, before the run
     trap (\ x (<>cli2 ()))    ; (run ()): dispatch, argv now the program's view
      () (\ a b (a == 'cli-leave ? (charm0 b) (scare a b))))))

 (cli-line ln tty)
   (: (charm0 x) (charm? x ? x 0)
      V  (from 'verbs)
      _  (ev [': 'cmdline ['\ ln] 'argv ['\ ln] ])   ; C's line is already past the primes
      f  (V 'seat <ln)
      (charm0 (? f          (f >ln)
                 (two? >ln) (cli-rail ln)
                 tty        (shell 0)
                 (reads in)))))            ; non-tty stdin: the stream face drinks the in port
) ; module cli
