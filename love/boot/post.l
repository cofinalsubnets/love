
; post -- the third egg stage, sat once on the hatchling, after prel and ev and before
; the mop. the one seat that sees both the finished compiler and the runtime-internal
; noms (peek seek atype, nifnom) the mop is about to take off the book: a
; reference compiled here folds to a value and survives, so love that needs to read the
; heap raw belongs here.
; the printer is the bulk of it, the reader's mirror image -- love.c's facex is the
; floor, the grammar all below. `print` `dot` `show` `putx` and the `.` sigil are pinned
; at the foot, in holes prel leaves: a nif folded into prel's compile could not be replaced.


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
   ; splice a registered module just below the head, so its names resolve on the walk but
   ; never shadow yours. a miss scares rather than splicing (): only a tablet is ever spliced,
   ; and a book the walk cannot read is a fault in map_probe.
   (borrow m)    (: b (tablet? m ? m
                    (: r (lib () m) (? r r (scare 'no-module m))))
               (? (tablet? b) (setstack (<(stack ()) . b . >(stack ()))) b))
   ; a module is its tablet, and currying reaches a member: (cite 'holo 'assemble). (cite ())
   ; lists the registry, a missing module answers (). the tablet handed back is the real one,
   ; and members fold into consumers at their compile, so pinning over one changes only what
   ; is compiled after.
   (cite k)   (? k (lib () k) (keys (lib ()))))

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

(: ; the macro twin: each layer keeps its table at its nil key, so this walks the chain `macros`
   ; looks up through. same placement rule as `names`, and its `stack` folds at compile time.
   (macro-names _) (filter nom? (keys (foldl (\ t k (pin t k 1)) {}
                                             (catmap (b \ (: m (b 0)
                                                             (tablet? m ? (keys m))))
                                                     (stack ())))))
   (part p) (foldr (\ a m (p a ? ((a . <m) . >m)
                                 (<m . a . >m))) '(())))

; the port head is three words -- ap, vt, ungetc -- declared in love.h and built here. each poke
; answers the cell it wrote, so `poke -1` walks backwards; the vt is the port's whole kind, a
; value word (poke), while the head's ap is an instruction (place).
(: (tap cl)
 (place -1 (pick 0 in) (poke -1 ci-vt (poke -1 -1 (poke 3 cl (spin 4)))))
 (jug _)                                          ; the output dual of `tap`: say into it, slurp it back out
  ; the backing starts empty: a literal here is one string every jug would share, and
  ; to_writen fills a backing in place, so two live jugs would write over each other.
  (place -1 (pick 0 in) (poke -1 to-vt (poke -1 -1 (poke -1 "" (poke 4 0 (spin 5))))))
 ; hot? names the zoo, the head's ap word the species. hot? first, so the read only ever
 ; lands on a heap cell.
 (port? o) (? (hot? o) (pick 0 o == pick 0 in) 0)   ; the else arm is the bit: a two-armed ? answers the zero point
 ; drain a vessel to a value: a jug reads its backing, everything else a gulp at a time. it
 ; accumulates rather than recursing -- the stack depth would be the gulp count, and a parking
 ; port copies that stack per task switch. `see` is the one door that touches the device, so
 ; every turn either lands a byte in the jug or reads the end, which is what terminates it.
 (slurp o) (? (? (port? o) (to-vt == peek 1 o)) (snip (peek 3 o) 0 (peek 4 o))   ; a jug by its vt: a buffered fd port's word 3 is a string too
              (: j (jug 0)
                 (go u) (: c (see o) (c @ -1 (slurp j)
                                          (put j c, say j (chug o), go ())))
                 (go ())))
 ; the promise, through a tablet. the answer is wrapped (1 v) and read with two?: a promise of
 ; nothing is ordinary (eof gives ()), and a bare pin would read as unforced, so f would re-run.
 (once f) (: t (tablet 0) (u \ (: v (t 0) (two? v ? >v (: w (f ()) _ (pin t 0 (1 . w)) w)))))
 ; a port is a charlist: the run just gulped realized, the tail a promise for the next. the tail
 ; must be a `once` -- p1 forces a position twice, and a re-drinking tail would lose the bytes
 ; between. the `see` is what refills; chug never touches the device.
 (flow p) (: (gulp tl) (: c (see p)
                          (c @ -1 tl
                               (: t (unsee p c, chug p)
                                  (go k l) (? (0 >= k) l (: j (k - 1) (go j (. (t j) l))))
                                  (go #t tl))))
             c (see p)
             (c != -1 ? (unsee p c, gulp (once (_ \ flow p)))))
 ; flow at one byte per force, where a whole run would read too far ahead. the one door that
 ; reads stdin exactly: `in` holds nothing in hand, though the device may gulp behind it.
 (trickle p) (: c (see p) (c != -1 ? (c . once (_ \ trickle p)))))

(:: '>>= (l \ (. (last l) (init l))))
(:: '<=< (g \ (: y (nom 0) ['\ y (foldr (\ f x [f x]) y g)])))
(: pow ** power ** car cap cdr cup cons .)

; --- the loader: borrow on a path ---------------------------------------------
; the `borrow` up top splices a module the runtime already holds; here it also loads one
; from a path the caller writes out. the loader invents no path of its own, so a name it
; lacks is a miss: what a frontend baked and what a cat registered is all a name can mean.
; a load is one fresh layer -- enter, read-eval, leave registers it under the file's
; basename -- and a file that made its own (module nm ..) keeps that registration.
; the same path twice reads once, marked by path and not basename: several files register
; one module (sb's parts, lush's, tls's), and a name-keyed mark would drop every part after
; the first. `open` is captured off the posix module, so a fs-less frontend misses every path.
(: borrow
   (: prior borrow
      ; read-eval every form of a module source; a torn form scares. `flow`, never `slurp`:
      ; slurp conses, reverses and re-strings, and sound conses again -- four copies.
      (rdev q) ((: (go cl) (: r (sound cl)
                              (? (two? r) (ev <r, go >r)
                                 (r == 'torn) (scare 'unfinished-form q)
                                 0)))
                (flow q))
      ; a layer holding no nom of its own is not a module. the charm keys (0 the macros,
      ; 31337 the parent chain) sit in every layer and are not noms.
      (bare? t) ((: (go ks) (two? ks ? (nom? <ks ? 0 (go >ks)) 1)) (keys t))
      (mname s) (: n #s
                   b ((: (go k r) (k >= n ? r (go (k + 1) (? (47 = peep s k 0) (k + 1) r)))) 0 0)
                   e (? (2 < n - b ? (".l" = snip s (n - 2) n) 0) (n - 2) n)
                   (intern (snip s b e)))
      fsopen (cite 'posix 'open)       ; the host's open nif, off its module -- see above
      (m \ (? (tablet? m) (prior m)
              (string? m)
              (: nm (mname m)
                 (? (peep (lib ()) m ()) (prior nm)          ; read already -- the path is the mark
                    (: q (? !fsopen () (fsopen m "r"))
                       (? !(hot? q) (prior m)
                          ; a file whose own (module nm ..) registered wins over the loader's
                          ; wrapper layer, which leave would pin over it; the mark goes down
                          ; before the read, so a file naming itself stops. a bare wrapper
                          ; claiming nothing is no module: pull the name and answer ().
                          (: _ (pin (lib ()) m 1)
                             _ (enter nm) _ (rdev q) t (lib () nm) w (leave ())
                             _ (t && pin (lib ()) nm t)
                             (!t && bare? w ? (pull (lib ()) nm 0, ()) (prior nm)))))))
              (prior m)))))

; a module's macros in the head layer, without its names -- the only way to spell one when
; the module was reached through `cite` rather than a splice. ks names them, () takes the
; lot; a macro table is a module's key 0, the one the export prune keeps.
(: (transcribe m ks)
   (: M (cite m 0)
      (? (tablet? M)
         (each (two? ks ? ks (keys M)) (k \ (: v (M k) (v && :: k v)))))))

(: (chars s) (map s ^#s)                      ; a string is an atom, so map needs the indices
   (findsub s sub) (#sub = 0 ? 0 (fsub s sub 0))        ; -1 when absent
   (has? s sub)    (0 <= findsub s sub)
   (starts? s p)   (#p <= #s && snip s 0 #p = p ? 1 0)          ; a ?-name owes a bit, and && gives ()
   (ends? s p)     (#p <= #s && snip s (#s - #p) #s = p ? 1 0)
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
               (? (string? s && n) (go 0 0) ()))
   ; a port's text as its number, () for anything outside 1..65535
   (uport s) (: n (unum s) (? (charm? n && 0 < n < 65536) n ()))
   ; a duration text -> milliseconds | (): N or N.N, an optional s/m/h/d suffix
   ; (seconds the default). 0 is a real duration -- callers test charm?, not truth
   (udur s0)
    (: n0 #s0
       lc (? (0 < n0) (s0 (n0 - 1)) ())
       sfx (lc = 115 || lc = 109 || lc = 104 || lc = 100)
       mul (? (lc = 109) 60000 (lc = 104) 3600000 (lc = 100) 86400000 1000)
       s (? sfx (snip s0 0 (n0 - 1)) s0)
       n #s
       (ip i acc) (? (i < n && digit? (s i)) (ip (i + 1) ((10 * acc) + (s i - 48))) [acc i])
       r (ip 0 0)
       whole <r i <>r
       (? (i = n && 0 < n) (whole * mul)
          (i < n && (s i = 46))
           (: (fp j acc sc) (? (j < n && digit? (s j))
                               (fp (j + 1) ((10 * acc) + (s j - 48)) (sc * 10))
                               [acc sc j])
              fr (fp (i + 1) 0 1)
              (? (<>>fr = n && (0 < i || (i + 1) < n))
                 ((whole * mul) + ((<fr * mul) // <>fr))
                 ()))
          ()))
   ; lowercase digits past 9. putbn reads a charm only, so a big is split down to one
   (radix n b)
    (? (charm? n) (: o (jug 0) _ (putbn o n b) (slurp o))
       (n < 0) ("-" + radix (0 - n) b)
       (radix (n // b) b + string ("0123456789abcdefghijklmnopqrstuvwxyz" (n % b))))
   (zpad w s) (#s < w ? (zpad w ("0" + s)) s)
   (aup n a) ((n + a - 1) & -a)                   ; n up to a multiple of a, a power of two
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
   (uniq l)  (: (go seen l) (? (atom? l) () (peep seen <l 0) (go seen >l)
                              (<l . go (pin seen <l 1) >l))
                (go (tablet 0) l))
   (count p l) (foldl (\ a x (p x ? (a + 1) a)) 0 l))

; --- assert / suite: the strict checkers, baked so they work with no harness.
; a failure scares and the program dies; test/00-init.l's `test` records instead. ---
(:: 'assert (l \ (. 'do (map (e \ ['? e 0 ['scare ['\ 'assert] ['\ e]]]) l))))

(:: 'suite (l \ (. 'do (. (. 'assert >l) [['puts <l] ['puts ": ok\n"]]))))

(: (array s) (: sh (a-shape s) (a-coll sh (foldl (*) 1 sh) 0)))

; --- coin: a kind of the hot row -- a table of what its values answer to, keyed by the noms
; the C side reads (love.h's Kn rows): name + * ap hot - net star /, net one of payload tally
; ratio. (coin 'nm spec) registers the kind and answers its constructor; spec is a tablet, or
; a function of the constructor when a method strikes its own kind: (z \ {'+ ..}). a method
; takes both operands raw, (lift z f) lowers them and re-strikes. kinds sort by registration;
; (kinds ()) lists the names in that order, (kinds 'nm) answers the table.
(: (coin nm spec)
    (: t {'name nm} z (strike t)
       s (tablet? spec ? spec (!spec ? () (spec z)))
       _ (tablet? s ? (foldl (\ t k (pin t k (s k))) t (keys s)) 0)
       r (kreg 0) e (r nm)
       _ (pin r nm ((two? e ? <e #(keys r)) . t))   ; a re-registration keeps its serial
       z)
   (kinds k) (name? k ? (: e (kreg 0 k) (two? e ? >e ()))
                        (: r (kreg 0) (map (p \ <>p) (sort (map (n \ [<(r n) n]) (keys r))))))
   (lift z f) (\ a b (z (f (load a) (load b)))))

;;; FIXME help/io setters below here. redesign the API with more structure
; binary?: does f take exactly two operands? the arity off the n-ary closure marker; any other
; compiled lambda takes one. one-sided on purpose: a nif or a partial passes. the markers are
; read off known values rather than named.
(: hcur (pick 0 (\ a b a)) hunc (pick 0 (+ 1))
   (binary? f) (? (charm? f) 0                      ; a charm is no handler at all
                  (hcur == pick 0 f) (2 = peek 1 f)
                  (hunc == pick 0 f || string? (nifnom f)) 1
                  !(lit? f && !(tablet? f) && !(hot? f)))
   (hear f) (? !f (seal-hook 5 ())                  ; every nothing uninstalls
               (binary? f) (seal-hook 5 f)
               (scare 'help-arity f)))

; the stdio door, the help's twin: (wear (i o e)) re-seats in/out/err for this task,
(: (wear l) (seal-hook 6 l))

; trap -- (f x) under a help that escapes: the value on a clean run, (n a b) when a scare
; landed here. all three operands, always: two hand back a closure, which is truthy, and f
; never runs at all. nothing unwinds -- the escape jumps past every pending restore between
; the raise and here -- so a cleanup belongs in n, or in `mind`'s c.
(: (trap f x n)
     (: _ (? (binary? n) 0 (scare 'help-arity n))   ; refuse before f runs, under the ambient help
        prev (heard ())
        home (myself ())
        r (call-cc (k \ (: _ (hear (\ a b (? (myself () == home) (k (_ \ (n a b)))
                                             (hear prev, scare a b))))
                           v (f x)
                           (_ \ v))))
        _ (hear prev)
        (r ())))

; mind -- (f x) with c minded on the way out: c fires exactly once, clean or raised, the
; condition rides on to the help outside, and the answer is f's. the n hands back a marked
; condition rather than re-raising in place, so the one (c ()) below serves both paths -- a
; re-raise inside n returns through any help that answers and fires c a second time. `mark`
; is minted once and closure-private, so no value f answers can pose as the raise. raises
; only: a bare (k v) into a continuation captured outside jumps past every c between there
; and here. c runs with the displaced help back, so a raise of its own belongs to the trap
; outside and replaces the condition it was firing for.
(: mind (: mark (mint 0)
           (\ f x c
              (: r (trap f x (\ a b (mark . [a b])))
                 _ (c ())
                 (? (two? r && == <r mark) (scare <>r <>>r) r)))))

; the ISA vocabulary, one word per machine: 'x64 'a64 'rv64, with the embedded targets keeping
; theirs. every other spelling -- a -t flag, a `seed` argument, uname's answer, a gnu triple's
; head -- comes through `archof` and leaves canonical, so nothing downstream normalizes twice.
(: arch-canon {'x64 'x64  'amd64 'x64  'x86_64 'x64  'x86-64 'x64
               'a64 'a64  'arm64 'a64  'aarch64 'a64
               'rv64 'rv64  'riscv 'rv64  'riscv64 'rv64
               'wasm 'wasm  'wasm64 'wasm
               'thumb1 'thumb1  'cortex-m0 'thumb1
               'thumb2 'thumb2  'cortex-m7 'thumb2
               'thumb2sp 'thumb2sp  'playdate 'thumb2sp}
   ; the word the world outside says: uname's machine, and the head of a gnu triple. the
   ; embedded targets answer () -- no kernel is ever asked their name.
   arch-uname {'x64 "x86_64" 'a64 "aarch64" 'rv64 "riscv64"}
   ; and the same for the kernel -- only the respelling. main.c pins `love-os` per run off
   ; __ai_osv: one binary meets four, and the compile that made it cannot say which.
   os-uname {'linux "Linux" 'freebsd "FreeBSD" 'netbsd "NetBSD" 'inle "Inle"}
   ; any spelling -> the canonical nom, () for one nobody here knows. takes a nom or a
   ; string, since a flag arrives as text where a table key is a nom.
   archof (arch-canon * name)
   ; the total face: a spelling nobody here knows rides through as its own nom, so
   ; whoever refuses it names what it was handed
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
   ; the -q trio walks by identity and answers what it found, () for a miss --
   ; `elem`/`assoc` above stay love's, a bit and a pair by `=`.
   (memq x l)   (? (two? l) (? (x == cap l) l (memq x >l)))
   (member x l) (? (two? l) (? (x = cap l) l (member x >l))))

; lamform -- a function read back off its thread into a source form that evaluates to an `=`
; function, or 0 when the thread is not one ev writes (a nif's body, a continuation). a
; symbolic run of the stack machine: every value pushed is a slot, a fresh mint whose node
; says how it was made, and the nodes render as source once the run is done.
(: lamform (:
   cur (pick 0 (+)) ret0 (pick 1 cap) unc (pick 0 (+ 1)) gcache {}
   ; the load runs, a spec per load: a an arg operand, q a quote operand, a number an
   ; immediate arg, (q v) an immediate quote. the flag says the last load carries the apply
   lds (foldl (\ t r (pin t <r >r)) {}
        [[lvm_arg '(a) 0] [lvm_quote '(q) 0] [lvm_argap '(a) 1] [lvm_quoteap '(q) 1]
         [lvm_aa '(a a) 0] [lvm_aq '(a q) 0] [lvm_qa '(q a) 0] [lvm_qq '(q q) 0]
         [lvm_aap '(a a) 1] [lvm_aqp '(a q) 1] [lvm_qap '(q a) 1] [lvm_qqp '(q q) 1]
         [lvm_arg0 '(0) 0] [lvm_arg1 '(1) 0] [lvm_arg2 '(2) 0] [lvm_arg3 '(3) 0]
         [lvm_quo0 '((q 0)) 0] [lvm_quo1 '((q 1)) 0] [lvm_quo2 '((q 2)) 0]
         [lvm_quo3 '((q 3)) 0] [lvm_quom1 '((q -1)) 0] [lvm_quom2 '((q -2)) 0]])
   ; an arg load fused with the nif that consumes it
   fus (pins {} lvm_argcap 'cap lvm_argcup 'cup lvm_argtwo 'two?)
   ; a nif's body op -> (name . arity), the shape ev's opof reads
   nops (foldl (\ t v (: nm (nifnom v)
                         b (? (string? nm) (? (ret0 == pick 1 v) (pick 0 v)
                                              (cur == pick 0 v && ret0 == pick 3 v) (pick 2 v)))
                         (? (? b (nil? (peep t b ()))) (pin t b ((name nm) . (? (ret0 == pick 1 v) 1 (peek 1 v)))) t)))
               {} (catmap (\ l (map l (keys l))) (stack ())))
   ; ..and a nif's name -> the nif, to say one the egg moved off the book by its module
   nval (foldl (\ t v (: nm (nifnom v) (? (string? nm) (pin t (name nm) v) t)))
               {} (catmap (\ l (map l (keys l))) (stack ())))
   (onm n) (: v (peep nval n ()) (? (nil? v) n (nifn v n)))
   ; a nif by its own name while the book binds it, else by what does: another name, a cite
   (nifn v n) (? (any (\ l (!== (peep l n ()) ())) (stack ())) n (: g (glob v) (? (!== g ()) g n)))
   (tk n l) (? (0 < n) (<l . tk (n - 1) >l) ())
   (dp n l) (? (0 < n) (dp (n - 1) >l) l)
   (unw v) (? (nat? v) (unw (? (cur == pick 0 v) (peek 3 v) (peek 1 v))) v)   ; a native is its twin
   (fn? v) (lit? v && !(tablet? v) && !(hot? v))
   (arity e) (? (cur == pick 0 e) (peek 1 e) 1)
   (entry e) (? (cur == pick 0 e) (seek 2 e) e)
   (partp v) (unc == pick 0 v || cur == pick 0 v && unc == pick 2 v)
   (unc0 v) (? (cur == pick 0 v) (seek 2 v) v)
   (pargs v) (: (go u a) (: l (peek 2 u) (? (unc == pick 0 l) (go l (peek 1 u . a)) (peek 1 u . a))) (go (unc0 v) ()))
   (fbase v) (: (go u) (: l (peek 2 u) (? (unc == pick 0 l) (go l) (seek -2 l))) (go (unc0 v)))
   ; a row's value is a binding power, negative as often as not: ask for presence
   (infix? x) (? (name? x) (any (k \ (k != 0 && peep (operators k) x () !== ())) (keys operators)))

   ; C is one reading's state: D a slot's node, B the let names in scope, R a let-bound
   ; closure's (name captures), memo a lambda already read -> its name, F a name's form,
   ; want a name recursion asked for
   (lamform v) (: nm (nifnom v) r (? (string? nm) (nifn v (name nm)) (call-cc (\ k (: C {'k k 'D {} 'B {} 'R {} 'busy () 'memo {} 'F {} 'want {} 'pre {} 'obj {} 'objs () 'letE {} 'thene 0}
                                    (rename (cites (tie C (? (partp v) (rfn C (fbase v) . map (rk C) (pargs v)) (rlam C (unw v))))))))))
                 (? (== r 0) (: g (glob v) (? (!== g ()) g 0)) r))
   (fail C) (C 'k 0)
   ; e lies past p, short of t -- within the thread, whose words past p span counts
   (over p t e) (: (go q n) (? (n < 1) 0 (== q e) 1 (== q t) 0 (go (seek 1 q) (n - 1))) (go p (span p)))
   (push C n S) (: s (mint 0) _ (pin (C 'D) s n) (s . S))

   ; --- the run: S is the stack, a slot per value. it answers (r node), a return, or
   ; (j at S), a jump to a join, and st is the join this stretch ends at
   (run C p S st) (? (p == st) ['j p S] (step C p S st (pick 0 p)))
   (step C p S st op) (: l (lds op)
    (? (two? l) (: (go S sp i) (? (two? sp)
                                (: s <sp (go (push C (? (charm? s) (S s) (s = 'a) (S (peek i p))
                                                        (s = 'q) ['k (peek i p)] ['k <>s]) S)
                                             >sp (? (charm? s) i (two? s) i (1 + i))))
                                (? <>l (run C (seek i p) (push C ['a (S 1) [<S]] >>S) st)
                                      (run C (seek i p) S st)))
                    (go S <l 1))
       (== op lvm_ret) ['r <S]
       (== op lvm_tap) ['r ['a (S 1) [<S]]]
       (== op lvm_argtap) (: S2 (push C (S (peek 1 p)) S) ['r ['a (S2 1) [<S2]]])
       (== op lvm_tapn) (: n (peek 1 p) ['r ['a (S n) (tk n S)]])
       (== op lvm_ap) (run C (seek 1 p) (push C ['a (S 1) [<S]] >>S) st)
       (== op lvm_apn) (: n (peek 1 p) (run C (seek 2 p) (push C ['a (S n) (tk n S)] (dp (1 + n) S)) st))
       ; a jump over the else arm ends a then arm at its join; any other is a cond the
       ; compiler folded, its dead arm jumped over, and the reading goes on where it lands
       (== op lvm_jump) (: t (peek 1 p) e (C 'thene)
                         (? (== t st || (e && over p t e)) ['j t S] (run C t S st)))
       (== op lvm_cond) (branch C <S (seek 2 p) (peek 1 p) >S st)
       (== op lvm_argcond) (branch C (S (peek 1 p)) (seek 3 p) (peek 2 p) S st)
       (== op lvm_argtwocond) (branch C ['o 'two? [(S (peek 1 p))]] (seek 3 p) (peek 2 p) S st)
       (== op lvm_index) (run C (seek 2 p) (push C ['g (peek 1 p)] S) st)
       (: f (peep fus op ())
        (? f (run C (seek 2 p) (push C ['o f [(S (peek 1 p))]] S) st)
           (: n (nops op)
            (? (two? n) (run C (seek 1 p) (push C ['o <n (tk >n S)] (dp >n S)) st)
               (fail C)))))))
   ; a cond: the then arm first, which finds the join if there is one; the else arm runs to it
   (branch C t a e S st) (: th (C 'thene) _ (pin C 'thene e) r1 (run C a S st) _ (pin C 'thene th)
    (? (<r1 = 'j) (: J (r1 1) _ (pin C 'thene 0) r2 (run C e S J) _ (pin C 'thene th)
                   (? (<r2 = 'j) (run C J (push C ['c J t <(r1 2) <(r2 2)] S) st) (fail C)))
       (: r2 (run C e S st)
        (? (<r2 = 'r) ['r ['c 0 t (r1 1) (r2 1)]] (fail C)))))

   ; --- rendering: a node to a source form, the binders still mints
   (res C x) (? (mint? x) (: b (peep (C 'B) x 0) d (peep (C 'D) x C)
                           (? (b || == d C) x (res C d)))
                x)
   (var? C x) (mint? (res C x))
   (rv C x) (: y (res C x)
    (? (mint? y) y
       (y @ ('k v) (rk C v)
            ('g n) n
            ('o n as) (onm n . map (ra C) as)
            ('c . J . cl) ('? . rcl C J cl)
            ('a . _) (rapp C y)
            (fail C))))
   ; the same captures: a name bound to a slot is that slot, whether or not the name holds
   (sees C x) (: d (? (mint? x) (peep (C 'D) x C) C) (? (== d C) x (sees C d)))
   (alleq C xs ys) (? (two? ys) (== (sees C <xs) (sees C <ys) && alleq C >xs >ys) 1)
   ; an operator away from the head is parenthesised, or it reads as infix
   (ra C x) (: r (rv C x) (? (infix? r) [r] r))
   ; a cond whose else is a cond of the same join is one cond of more clauses
   (rcl C J cl) (: t <cl a <>cl e <>>cl y (res C e)
    (rv C t . rv C a . (? (two? y && <y = 'c && y 1 == J) (rcl C J >>y) [(rv C e)])))
   ; the application spine: the head, then each apply's group, outermost last
   (spine C x gs) (: y (res C x) (? (two? y && <y = 'a) (spine C (y 1) ((y 2) . gs)) (y . gs)))
   ; a lambda to read back: no name of its own, not a partial, not being read already
   (lam C h) (? (two? h && <h = 'k)
               (: v (unw (h 1)) (? (fn? v && !(partp v) && fname C v == 0 && !(busy? C v)) v)))
   (nlet C h) (? (two? h && <h = 'k) (named C (unw (h 1))))
   ; a lambda head: fewer args than params are its captures, a closure; the group that
   ; saturates it is a let's inits, the groups before it its captures
   (rapp C x) (: sp (spine C x ()) h <sp gs >sp E (lam C h) as (catmap id gs) nl (nlet C h)
    (? (two? nl) (: ic <>nl ni #ic
                  (? (ni <= #as && alleq C as ic)
                     (? (ni < #as) (<nl . map (ra C) (dp ni as)) <nl)
                     (flat C h as)))
       E (: n (arity E) m #as
          (? (m < n) (? (all (var? C) as) (rclo C E (map (res C) as)) (flat C h as))
             (: (cut gs acc k) (? (two? gs) (: a (acc + #<gs) (? (a = n) k (a < n) (cut >gs a (1 + k)) -1)) -1)
                k (cut gs 0 0) imps (catmap id (tk k gs)) la (? (0 <= k) (gs k)) rest (catmap id (dp (1 + k) gs))
              (? (0 <= k && all (var? C) imps)
                 (: lt (rlet C E (map (res C) imps) la) (? (two? rest) (lt . map (ra C) rest) lt))
                 (flat C h as)))))
       (: s (self C h as) (? (two? s) <s (flat C h as)))))
   ; a closure calling itself from inside its own reading passes its captures along first:
   ; its name stands for the closure, captures and all
   (self C h as) (? (two? h && <h = 'k)
                   (: u (unw (h 1)) p (peep (C 'pre) u ())
                    (? (two? p && busy? C u && #p <= #as && alleq C as p)
                       (: n (want C u)
                        (? (peep (C 'letE) u 0) [(n . map (ra C) as)]   ; a let's lambda is bound bare: every arg
                           (#p < #as) [(n . map (ra C) (dp #p as))] [n])))))
   (flat C h as) (rv C h . map (ra C) as)
   ; a let's names are the slots its inits sit in. an init that is a closure names its
   ; thread, so a reference back to it from its own body or a sibling's reads as the name.
   ; the names hold inside the let alone: a slot the thread reads before it, a cond's test
   ; with the let in each arm, reads as the value it holds. a lambda that called itself from
   ; its own reading was a function called, no let: it binds its name, (: n (\ ..) n), and
   ; takes its captures and inits as args
   (rlet C E imps la) (: B (C 'B) R (C 'R)
    rs (catmap (s \ (: cl (clo C (res C (peep (C 'D) s ()))) (? cl [[<cl (R <cl) s >cl]] ()))) la)
    _ (each rs (r \ (pin R <r [(r 2) (r 3)])))
    _ (each la (s \ (pin B s 1)))
    b (rbody C E (imps + la))
    n (peep (C 'want) E 0)
    f (? (mint? n) 0 (': . catmap (s \ [s (rinit C s)]) (rev la) + [<>b]))
    _ (each la (s \ (pin B s 0)))
    _ (each rs (r \ (pin R <r (r 1))))
    (? (mint? n) ([': n ('\ . imps + la + <b + [<>b]) n] . imps + map (rinit C) la) f))
   (rinit C s) (: d (res C (peep (C 'D) s ())) cl (clo C d)
    (? cl (unself s (eta (rclo C <cl >cl))) (rv C d)))
   ; a named closure over captures, ((: n (\ caps.. ps.. body) n) caps..), is a lambda over
   ; its ps, as a let's sibling must be to see the siblings after it
   (eta y) (: h <y
    (? (two? h && == <h ': && 4 = #h && two? (h 2) && == <(h 2) '\)
       (: m (#(h 2) - 2 - #>y) ps (map (\ _ (mint 0)) (jot m))
        (? (0 < m) ('\ . ps + [(y + ps)]) y))
       y))
   ; a closure bound by name that names itself, (: n (\ ..) n), is its lambda under that
   ; name: a value would see only the siblings bound before it
   (unself m y) (? (two? y && == <y ': && 4 = #y && mint? (y 1) && == (y 1) (y 3)) (sub (y 1) m (y 2)) y)
   (sub a b x) (? (== x a) b (atom? x || qot? x) x (map (\ e (sub a b e)) x))
   ; a closure node: (lambda . capture vars), or ()
   (clo C d) (? (two? d && <d = 'k) (: v (unw (d 1)) (? (fn? v && !(partp v) && !(nifnom v)) [v]))
                (two? d && <d = 'a)
                (: sp (spine C d ()) h <sp as (catmap id >sp) E (? (two? h && <h = 'k) (unw (h 1)))
                 (? (E && fn? E && !(partp E) && !(nifnom E) && #as < arity E && all (var? C) as)
                    (E . map (res C) as))))
   (named C v) (peep (C 'R) v ())
   ; read with captures, a lambda's own name is the bare lambda -- a call of it from inside
   ; can pass other captures (a walk up a chain) -- so a call through its self passes every arg
   (rbody C E pre) (: bz (C 'busy) le (peep (C 'letE) E 0)
    (inq l) (? (two? l) (== E <l || inq >l))
    _ (? (inq bz) (fail C))
    _ (pin C 'busy (E . bz))
    _ (pin (C 'pre) E pre)
    _ (? (two? pre) (pin (C 'letE) E 1) 0)
    S0 (: (ps i) (? (i < arity E) (? (i < #pre) (pre i . ps (1 + i)) (mint 0 . ps (1 + i))) ()) (ps 0))
    r (run C (entry E) S0 ())
    b (? (<r = 'r) [(dp #pre S0) (rv C (r 1))] (fail C))
    _ (pin (C 'letE) E le)
    _ (pin C 'busy bz)
    b)
   ; a body that is itself a lambda sits in a singleton, which reads as the lambda: bare,
   ; the reader would merge its params into ours, one closure where the thread has two
   ; one reached again from inside its own reading is recursion with no name to say it by: it
   ; takes one, and its form binds it, (: n (\ ..) n)
   ; with captures, the name binds the bare lambda and the closure is it applied to them
   (rclo C E pre) (: b (rbody C E pre) y <>b
                   yb (? (two? y && == <y '\ && two? >>y) [y] y)
                   f ('\ . <b + [yb])
                   n (peep (C 'want) E 0)
                   (? !(mint? n) f
                      (two? pre) ([': n ('\ . pre + <b + [yb]) n] . pre)
                      [': n f n]))
   (want C u) (: W (C 'want) n (peep W u 0) (? (mint? n) n (: n (mint 0) (pin W u n, n))))
   (rk C v) (? (charm? v) v
               (== v ()) ()
               ; a sentinel: the name that holds it, else one fresh mint said by one name
               (mint? v) (: g (glob v) (? (!== g ()) g (obj C v ['mint 0])))
               (nom? v || two? v) ['\ v]
               (fn? v) (rfn C v)
               ; a carrier is `=` to itself alone, so no spelling reads back as it: a big
               ; one, a cache the function keeps, is its size
               (tablet? v || hot? v) (: g (glob v) (? (!== g ()) g (tablet? v && 16 < #v) (name ("{.." + dec #v + "}")) v))
               v)
   ; an object only itself is `=` to, named once and bound over the whole to a fresh one
   (obj C v init) (: n (peep (C 'obj) v 0)
    (? (mint? n) n (: n (mint 0) _ (pin (C 'obj) v n) _ (pin C 'objs ([n init] . C 'objs)) n)))
   (dec n) (? (n < 10) (string (48 + n)) (dec (n // 10) + string (48 + n % 10)))   ; show is later
   ; a function's own name: a nif's, a glued sigil's, a let's, a global's. 0 for none, a
   ; let's name being a mint, and a mint falsy
   (fname C v) (: nm (nifnom v)
    (? (string? nm) (nifn v (name nm))
       (: gn (opnom v) u (unw v) r (named C u)
        (? gn gn
           (? (two? r) (atom? <>r)) <r                  ; a let's name, when it holds no captures
           (: g (glob v) (? (!== g ()) g (: g (glob u) (? (!== g ()) g 0))))))))
   (rfn C v) (: nm (fname C v)
    (? (nm !== 0) nm
       (partp v) (rfn C (fbase v) . map (rk C) (pargs v))
       (rlam C (unw v))))
   ; a lambda constant is read once and stands as a name for its form
   (rlam C u) (: n (peep (C 'memo) u 0)
    (? (mint? n) n (busy? C u) (want C u)
       (: n (mint 0) _ (pin (C 'memo) u n) _ (pin (C 'F) n (rclo C u ())) n)))
   ; a name met from one place outside its own form is that form in place, bound there,
   ; (: n (\ ..) n), when it recurs; one met from more is bound once, in a letrec over the
   ; whole, as a module binds its helpers. `on` holds the names whose forms are being walked.
   ; a name bound in place but met again from a helper over the whole is out of its scope
   ; there: it joins the helpers, and the form is laid again
   (tie C x) (: F (C 'F) out {} own {} seen {} O {'l ()}
    ON (foldl (\ t p (pin t <p 1)) {} (C 'objs))      ; rk's objects, bound first over the whole
    ob (catmap id (rev (C 'objs)))
    (inq x l) (? (two? l) (== x <l || inq x >l))
    (cw x on) (? (mint? x) (: _ (? (inq x on) (pin own x 1) (pin out x (1 + peep out x 0)))
                             (? (two? (peep F x ()) && !(peep seen x 0))
                                (: _ (pin seen x 1) _ (pin O 'l (x . O 'l)) (cw (F x) (x . on))) 0))
                 (atom? x || qot? x) 0
                 (each x (e \ (cw e on))))
    _ (cw x ())
    ; a form read inside a let may say that let's names, which hold nowhere else: it goes
    ; in place wherever it is met, never over the whole
    (fvs y) (: A {'l ()}
             (fw x sc) (? (mint? x) (? (!(two? (peep F x ())) && !(peep ON x 0) && !(inq x sc)) (pin A 'l (x . A 'l)) 0)
                          (atom? x || qot? x) 0
                          (<x == ':) (: sc2 (lets >x + sc) (each >x (e \ (fw e sc2))))
                          (<x == '\) (: sc2 (init >x + sc) (each >x (e \ (fw e sc2))))
                          (each x (e \ (fw e sc))))
             _ (fw y ())
             (A 'l))
    (nms y) (? (mint? y) (? (two? (F y)) [y] ()) (atom? y || qot? y) () (catmap nms y))
    ; ..and so is a form that holds one
    (spread t) (: n (foldl (\ n m (? (!(peep t m 0) && any (k \ (peep t k 0)) (nms (F m))) (pin t m 1, (1 + n)) n)) 0 (O 'l))
                (? (0 < n) (spread t) t))
    loc (spread (foldl (\ t m (? (two? (fvs (F m))) (pin t m 1) t)) {} (O 'l)))
    (ex H x on) (? (mint? x) (? (inq x on || (atom? (F x)) || peep H x 0) x
                                (: f (ex H (F x) (x . on)) (? (peep own x 0) [': x f x] f)))
                   (atom? x || qot? x) x
                   (: y (map (e \ (ex H e on)) x) (? (<y == '\) (sole y) y)))
    ; a lambda in place as a lambda's body sits in a singleton, as rclo leaves one
    (sole y) (: b (last y) (? (two? b && == <b '\ && two? >>b) (init y + [[b]]) y))
    (lay H) (: hs (filter (\ m (peep H m 0)) (rev (O 'l)))
             (? (two? hs || two? ob) (': . ob + catmap (\ m [m (unself m (ex H (F m) [m]))]) hs + [(ex H x ())]) (ex H x ())))
    ; the names met where no (: ..) around them binds them
    (free y) (: A {'l ()}
              (fw x sc) (? (mint? x) (? (two? (F x) && !(inq x sc)) (pin A 'l (x . A 'l)) 0)
                           (atom? x || qot? x) 0
                           (<x == ':) (: sc2 (lets >x + sc) (each >x (e \ (fw e sc2))))
                           (each x (e \ (fw e sc))))
              _ (fw y ())
              (A 'l))
    (fix H) (: y (lay H) fs (filter (\ m !(peep loc m 0) && !(peep H m 0)) (free y))
             (? (two? fs) (fix (foldl (\ H m (pin H m 1)) H fs)) y))
    (fix (foldl (\ H m (? (1 < peep out m 0 && !(peep loc m 0)) (pin H m 1) H)) {} (O 'l))))
   ; by `=`: an older compile of the same function is the same function
   (busy? C u) (: (go l) (? (two? l) (u = <l || go >l)) (go (C 'busy)))
   ; the globals and module names by value, the shortest spelling first, then the least. the
   ; table outlives a reading and is rebuilt when a layer or a module gains or loses a name;
   ; a hit is held to the binding it came from, so a name since rebound rebuilds too. the
   ; hit is by `=`, its binding held by what it held when the table was built. a module's
   ; name reads back as (cite 'module 'name), the book's as itself; () for none
   (glob v) (? (tablet? v || hot? v) (gcar v)
             (: e (peep (gtab 0) v ())
              (? (nil? e) ()
                 (== (<>e <e) (e 2)) (spell e)
                 (: e (peep (gtab 1) v ()) (? (two? e) (spell e) ())))))
   (spell e) (? (e 3) ['cite ['\ (e 3)] ['\ <e]] <e)
   ; a carrier is found by `==` down a list: its hash moves as it is written, so a table
   ; keyed by it misses one written since the build. the book's name first, then the best
   (gcar v) (: e (cbest v (: _ (gtab 0) (gcache 'c)))
    (? (nil? e) ()
       (== (<>e <e) v) (spell e)
       (: e (cbest v (: _ (gtab 1) (gcache 'c))) (? (two? e) (spell e) ()))))
   (cbest v l) (foldl (\ b e (? (!(== (e 2) v)) b
                                 (nil? b) e
                                 (!(e 3) && (b 3)) e
                                 (!(b 3) && (e 3)) b
                                 (better <e <b) e
                                 b)) () l)
   (better a b) (: x (string a) y (string b) (? (#x < #y) 1 (#x = #y) (x < y) 0))
   ; the book's count and the modules' apart: a name moved from one to the other moves it
   (gsig L) [(foldl (\ n l (n + #l)) 0 (stack ()))
             (foldl (\ n k (: l (L k) (n + 1 + (? (tablet? l) #l 0)))) 0 (keys L))]
   (gtab force) (: L (lib ()) s (gsig L)
    (? (? force 0 (s = peep gcache 's -1)) (gcache 't)
       (: t {} m {} seen {} cs {'l ()}
          (put t v k l n) (: old (peep t v ()) (? (? (nil? old) 1 (better k <old)) (pin t v [k l (l k) n]) 0))
          ; a native is keyed by its bytecode too: a thread quotes whichever the compiler held
          (add t n l k) (: v (l k)
                         (? !(name? k) 0
                            (tablet? v || hot? v) (pin cs 'l ([k l v n] . cs 'l))
                            (fn? v || mint? v || string? (nifnom v))
                            (: _ (put t v k l n) (? (fn? v) (put t (unw v) k l n) 0))
                            0))
          _ (each (stack ()) (\ l (each (keys l) (\ k (? (peep seen k 0) 0 (: _ (pin seen k 1) (add t 0 l k)))))))
          ; a module's names fill in where the book has none
          _ (each (keys L) (\ n (: l (L n) (? (tablet? l) (each (keys l) (add m n l)) 0))))
          _ (each (keys m) (\ v (? (nil? (peep t v ())) (pin t v (m v)) 0)))
          _ (pins gcache 's s 't t 'c (cs 'l))
          t)))
   ; --- naming: a binder is a letter by its depth, a b .. z aa ab .., skipping any name the
   ; form spells free, which a binder of that spelling would capture
   (sxch n a) (: q ((n - 1) // 26) c (97 + ((n - 1) % 26))
               (? (0 < q) (sxch q (c . a)) (c . a)))
   (lnom i) (name (string (sxch (1 + i) ())))
   (nxt i fv) (? (peep fv (lnom i) 0) (nxt (1 + i) fv) i)
   (qot? x) (two? x && == <x '\ && two? >x && (atom? >>x))
   (fvn x t) (? (name? x) (pin t x 1) (atom? x || qot? x) t (foldl (\ t e (fvn e t)) t x))
   (asg bs i m fv) (? (two? bs) (: j (nxt i fv) (asg >bs (1 + j) ((<bs . lnom j) . m) fv)) (i . m))
   (lets l) (? (two? >l) (<l . lets >>l) ())
   (ren x i m fv) (? (mint? x) (: p (assq x m) (? (two? p) >p x))
                     (atom? x || qot? x) x
                     (<x == '\) (: a (asg (init >x) i m fv)
                                 ('\ . map (e \ (ren e <a >a fv)) >x))
                     (<x == ':) (: a (asg (lets >x) i m fv)
                                 (': . map (e \ (ren e <a >a fv)) >x))
                     (map (e \ (ren e i m fv)) x))
   (rename f) (ren f 0 () (fvn f {}))
   ; a (cite 'module 'name) met more than once is bound once over the whole, by its own
   ; spelling where the form spells it nowhere else, else by a letter
   (cites y) (: T {} O {'l ()}
    (cite? x) (two? x && == <x 'cite && 3 = #x)
    (cc x) (? (atom? x || qot? x) 0
              (cite? x) (: c (peep T x 0) _ (? (c = 0) (pin O 'l (x . O 'l)) 0) (pin T x (1 + c)))
              (each x cc))
    _ (cc y)
    fv (fvn y {})
    bs (filter (\ c (1 < T c)) (rev (O 'l)))
    N (foldl (\ t c (: k (c 2 1) (pin t c (? (peep fv k 0) (mint 0) k)))) {} bs)
    (rp x) (? (atom? x || qot? x) x (cite? x) (: b (peep N x ()) (? (nil? b) x b)) (map rp x))
    (? (two? bs) (: z (rp y) ds (catmap (\ c [(N c) c]) bs)
                  (? (== <z ':) (': . ds + >z) (': . ds + [z])))
       y))
   lamform))

(: px (:
  ; every eager binding sits in this outer `:`. where boxfix engages (any forward
  ; or self reference -- the printer below is one), a sibling bound to an unfoldable
  ; call is boxed too and its cell never filled, so every read of it raises `missing`:
  ;   (: f (: (a o) (f o) c (tablet 0) (\ o c)))   -> ;; missing c
  cur (pick 0 (+)) ret0 (pick 1 cap) unc (pick 0 (+ 1))
  ; the float width is the seat's, never this file's: a 32-bit seat gets binary32 for
  ; ai_flo_t. so ask the arithmetic -- a hard-coded 2^53 sends norm's doubling loop past
  ; every float32 there is and it never returns.
  p53 (: (go m) (? (m = (1.0 + m)) m (go (m * 2.0))) (go 1.0))   ; where +1 is lost = 2^mantissa
  p52 (p53 / 2.0)
  emin (: (go v e) (: h (v / 2.0) (? (h = 0) e (go h (e - 1)))) (go 1.0 0))   ; the denormal floor
  inf (1.0 / 0.0)
 (:

  ; --- integers: the digits of a non-negative charm/sun/big, most significant first
  (dch n a) (: q (n // 10) d (48 + (n - (q * 10))) (? (0 < q) (dch q (d . a)) (d . a)))
  (dstr n) (string (dch n ()))
  (ndig n) (: q (n // 10) (? (0 < q) (1 + (ndig q)) 1))          ; the count, without building the list
  (pnum o n) (? (n < 0) (put o 45, say o (dstr (0 - n))) (say o (dstr n)))

  ; --- text ---
  (hexd d) (? (d < 10) (48 + d) (87 + d))
  ; post compiles before any layer is spliced, so `@` has to be in the book already -- it is,
  ; from the half of this file above. an unaccompanied `@` folds to a plain application.
  (esc o c)
   (c @ (92 || 34) (put o 92, put o c)
        10 (say o "\\n")   9  (say o "\\t")
        13 (say o "\\r")   27 (say o "\\e")
        0  (say o "\\0")
        (c >= 32 ? (put o c)
                   (say o "\\x", put o (hexd (c // 16)),
                    put o (hexd (c - (16 * (c // 16)))))))
  (pstr o s) (: n #s
                (go i) (? (i < n) (esc o (peep s i 0), go (1 + i)) 0)
                _ (put o 34) _ (go 0) (put o 34))

  ; --- gems: the shortest roundtrip, exact steele & white. 4m and the midpoints 4m±2 are
  ; bignums at one shared scale and `//` does the rest.
  ; v = m*2^e exactly, m an integer, normalized into [p52,p53) -- but never past the denormal
  ; floor, where the spacing stops halving and the search interval would come out far too narrow.
  (norm m e) (? (p53 <= m) (norm (m / 2.0) (1 + e))
                (m < p52 && emin < e) (norm (m * 2.0) (e - 1))
                (int m . e))
  ; inside the rounding interval? a midpoint counts only for an even mantissa --
  ; round-to-nearest-even is what reads it back.
  (fits c lo hi evn) ((lo < c ? 1 (evn && c = lo)) &&
                      (c < hi ? 1 (evn && c = hi)))
  ; the fewest digits whose rounded form sits inside: pk is the place being cut, walking down
  ; by ten a step, trying the truncation and the bump, the nearer first. at pk = 1 it
  ; terminates, dv itself being inside by construction.
  (fewest dv lo hi evn pk) (? (pk < 1) dv
    (: t ((dv // pk) * pk)
       up (1 < pk && 5 <= (dv // (pk // 10) - (10 * (dv // pk))))
       c1 (? up (t + pk) t) c2 (? up t (t + pk))
       (? (fits c1 lo hi evn) c1 (fits c2 lo hi evn) c2 (fewest dv lo hi evn (pk // 10)))))
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
    dc (fewest dv dlo dhi evn (** 10 ((ndig dv) - 1)))
    lead (ndig dc)
    ss (dstr (strip dc)) sig #ss
    dxp (lead + (sh < 0 ? sh 0))
    (? (1e16 <= a || a < 1e-4)
       (: e (dxp - 1)
          _ (put o (peep ss 0 0))
          _ (1 < sig ? (put o 46, say o (snip ss 1 sig)))
          _ (put o 101)
          _ (e < 0 ? (put o 45) 0)
          (say o (dstr (e < 0 ? -e e))))
       (0 < dxp)                                  ; 1 <= v < 1e16: the point sits inside or after
       (: (go i) (? (i < dxp) (put o (? (i < sig) (peep ss i 0) 48), go (1 + i)) 0)
          _ (go 0) _ (put o 46)
          (? (dxp < sig) (say o (snip ss dxp sig)) (put o 48)))   ; integral: force "X.0", never a fixnum face
       (say o "0.", zeros o (0 - dxp), say o ss)))
  ; the sign is the bit, not v < 0: -0.0 < 0 is false, and a comparison there prints "0.0".
  (pgem o v)
     (: _ (? (v < 0 || (v = 0 && (1.0 / v) < 0)) (put o 45) 0) a (abs v)
        (? (a = inf) (say o "infinity") (a = 0) (say o "0.0") (pgem2 o a)))
  ; a twin prints infix, parenthesized: (re ~ im) is self-delimiting, so it reads
  ; straight back wherever the printer put it.
  (ptwin o x) (put o 40, pgem o (re x), say o " ~ ", pgem o (im x), put o 41)

  ; --- chains. a one-operand `\` is quote, and a `(mono (run datum))` is a glued
  ; monadic -- print run+datum back the way opfix fused them.
  ; an improper tail prints as the ` . ` pair it is -- the dyadic `.` reads it straight back.
  (plist o x sn) (: (go l) (px o <l sn,
                            (? (two? >l) (put o 32, go >l)
                               !>l 0
                               (say o " . ", px o >l sn)))
                    _ (put o 40) _ (go x) (put o 41))
  (pchain o x sn) (: h <x t >x one (two? t && (atom? >t))
    (? (h == '\ && one) (put o 39, px o <t sn)
       (h == 'mono && one && (: m <t (two? m && two? >m && atom? >>m)))
         (: m <t _ (px o <m sn) (px o <>m sn))
       (plist o x sn)))

  ; --- trays. rank 1 is @(…); past that (array '(shape) elem…), since @ has no
  ; shape spelling. an object tray quotes what would otherwise re-evaluate.
  ; a tray is read by coordinate, so walk the flat index back into one, row-major
  (coord sh i) (? (atom? >sh) (i . ())
                  (: r (foldl (*) 1 >sh) q (i // r) (q . coord >sh (i - (q * r)))))
  (ptray o v sn) (: ty (atype v) sh (shape v) n (foldl (*) 1 sh)
    (pel i) (: e (peep v (coord sh i) 0)
               _ (? (ty = 3 && (nom? e || two? e)) (put o 39) 0) (px o e sn))
    (go i f) (? (i < n) ((? f 0 (put o 32)), pel i, go (1 + i) 0) 0)
    (gs l f) (? (two? l) ((? f 0 (put o 32)), pnum o <l, gs >l 0) 0)
    (? ((rank v) = 1) (say o "@(", go 0 1, put o 41)
       (: _ (say o "(array '(") _ (gs sh 1) _ (put o 41)
          (ge i) (? (i < n) (put o 32, pel i, ge (1 + i)) 0)
          _ (ge 0) (put o 41))))

  ; --- maps print {k v …}, the empty one {}; both read straight back. a map is
  ; mutable and can hold itself, so the path is carried and matched by identity.
  (onpath? x l) (? (atom? l) 0 (x == <l) 1 (onpath? x >l))
  (pmap o m sn) (? (onpath? m sn) (say o "<cycle>")
    (: ks (keys m) s2 (m . sn)
       (go l f) (? (two? l) ((? f 0 (put o 32)),
                             px o <l s2, put o 32, px o (m <l) s2,
                             go >l 0) 0)
       (? (atom? ks) (say o "{}") (put o 123, go ks 1, put o 125))))

  ; --- coins show as (name 'payload), so the form evals back to an equal coin where the name
  ; is a bound ctor. the payload is quoted where it would otherwise re-evaluate -- a chain
  ; reads as an application, a nom as a variable. a rational wears the twin's face, (n /// d).
  (pcoin o x sn) (: p (load x)
    (? (kind x = '/// && two? p) (put o 40, px o <p sn, say o " /// ", px o <>p sn, put o 41)
       (put o 40, px o (kind x) sn,
     put o 32, two? p || nom? p ? (put o 39) 0,
     px o p sn, put o 41)))

  ; --- closures. a partial's every unc cell holds its arg at [1] and the link at
  ; [2], so the base value sits at link-2.
  (partp v) (unc == pick 0 v || cur == pick 0 v && unc == pick 2 v)
  (unc0 v) (? (cur == pick 0 v) (seek 2 v) v)
  (nargs v) (: (go u n) (: l (peek 2 u) (? (unc == pick 0 l) (go l (1 + n)) n)) (go (unc0 v) 1))
  (fbase v) (: (go u) (: l (peek 2 u) (? (unc == pick 0 l) (go l) (seek -2 l))) (go (unc0 v)))
  (farg v i n) (: (go u w) (? (0 < w) (go (peek 2 u) (w - 1)) (peek 1 u)) (go (unc0 v) ((n - 1) - i)))

  (pfn o v sn) (: nm (nifnom v)
    (? (string? nm) (: s (lamform v) (? (== s (name nm)) (say o nm) (px o s sn)))   ; off the book: what binds it
       ; a glued sigil's backing value has no nif name but it has exactly one word;
       ; say that instead of inlining its whole body wherever `<x` was written.
       (: gn (opnom v)
          (? gn (say o (string gn))
             (: s (lamform v)
                (? (s !== 0) (px o s sn)
                   (partp v) (: n (nargs v)
                                (go i) (? (i < n) (put o 32, px o (farg v i n) sn, go (1 + i)) 0)
                                _ (put o 40) _ (pfn o (fbase v) sn) _ (go 0) (put o 41))
                   (put o 92, pnum o (abs (dig v)))))))))   ; opaque: the digest, a distinguisher and nothing more

  (px o x sn) (? (charm? x) (pnum o x)
                (coin? x) (pcoin o x sn)
                (tablet? x) (pmap o x sn)
                (lit? x) (pfn o x sn)
                (x == ()) (say o "()")
                (two? x) (pchain o x sn)
                (string? x) (pstr o x)
                (nom? x) (? (mint? x) (say o "(mint ", pnum o (dig x), put o 41)
                              (say o (string x)))
                (gem? x) (pgem o x)
                (tray? x) (ptray o x sn)
                (twin? x) (ptwin o x)
                (sun? x) (pnum o x)
                o)
  px)))

; the surface. `dot` takes a string or cask verbatim and everything else in external
; form; it answers its operand, so it drops into any sequence.
(: (print o x) (px o x (), x)
   (show x) (: o (jug 0) (px o x (), slurp o))
   (dot x) (string? x || hot? x && !(port? x) ? (say out x) (px out x ()), flush out, x)
   putx (print out))

; --- the u-floor's door: a whole file in and out, and the exit every tool leaves by.
; open and close are 'posix's, so they are cited; a module borrows them itself ---
(: ; a path -> (1 text) when it opens, () when it does not
   (uread p) (cite 'posix 'open p "r" @ q
              (? (hot? q) (: t (slurp q) _ (cite 'posix 'close q) [1 t]) ()))
   ; a path + text -> 1 when it lands, () when it will not open
   (uwrite p t) (cite 'posix 'open p "w" @ q
                 (? (hot? q) (say q t, (cite 'posix 'close q), 1) ()))
   ; a main answers its status as a charm, or leaves from deep inside by scaring 'leave
   ; with it. urun is the driver both come back through, so a caller in the same image
   ; gets a charm instead of a dead process. nothing unwinds through a scare, so a port
   ; held at the leave is lost, exactly as `quit` loses it.
   (uleave c) (scare 'leave c)
   (urun f as)
    (: (out! _) (flush out, flush err)
       (trap (_ \ (: r (f as) _ (out! ()) (? (charm? r) r 0))) ()
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
         (show e))
   ; say m on err and leave with code c
   (udie c m) (say err m, put err 10, uleave c))

(seal-hook 7 show)
(: (red? x) (+x < 0) (blue? x) (+x = 0) (green? x) (+x > 0))

; --- the disassembler: a thread read back as data. the bounds are structural -- stem reads
; --- the head off the terminator, span counts the cells to it, seek refuses a step over
; --- either -- so a walk stays inside the object whatever the cells hold. a cell's kind is
; --- only as good as the op table: read an operand cell with peek and a code cell with pick.
(: ret0 (pick 1 cap) cur (pick 0 (+))
   ; a nif's run is [impl][ret0], or [cur][arity][impl][ret0]: the shape ev's own `opof` reads
   (nifop v) (? (ret0 = pick 1 v)                     (pick 0 v)
                (cur = pick 0 v && ret0 = pick 3 v)   (pick 2 v))
   ; the instruction rows name themselves; a nif's body fn is an op no lvm_ name spells, so
   ; it takes the nif's own -- `+` over an index, and the roster is the book either way
   opnames (: ks (sort (keys book))                   ; sorted: two names on one op must not race
              T (foldl (\ t k (? (? (nom? k) ("lvm_" = snip (string k) 0 4))
                                 (pin t (book k) k) t))
                       {cur 'lvm_cur ret0 'lvm_ret0} ks)   ; neither of these is a book name
              (foldl (\ t k (: b (? (nom? k) (nifop (book k)))
                               (? (? b !(t b)) (pin t b k) t)))
                     T ks))
   (opname i) (peep opnames i i)                      ; an index with no name prints as itself
   (discell c) (: p (pick 0 c) (!p ? ['val (peek 0 c)] ['op (opname p)]))
   ; (dis v): every cell of the object v points into, from its head
   (dis v) (: h (stem v) (!h ? () (map (i \ discell (seek i h)) ^(span h))))
   ; (disp v): the same, one cell a line, `>` marking the cell v itself points at
   (disp v) (: h (stem v)
              _ (!h ? (puts "not on the heap\n")
                 ((? (nat? v) (puts "; native: a glazed body is code, and reads ()\n")),
                  each (jot (span h)) (i \ (: r (discell (seek i h))
                  (puts (show i), puts (seek i h = v ? " > " "   "),
                   puts (<r = 'op ? "" "= "), putx (r 1), puts "\n")))))
              ()))

; --- the library layers, sat here with post so every seat carries them: rng and q are
; --- globals, and the rest register as modules a seat splices as it wants ---

; rng -- the random layer, two faces over the pure C steps; C holds no state. (wheel n) -> a
; fresh 256-bit state, turn/turnf step it.
; functional, reproducible: (random st n) draws once -> (value . st'), the value's type by n --
; float -> float in [0,n), positive int -> int in [0,n), n <= 0 -> full-width int. global, one
; hidden clock-seeded stream: (rand n) and (randf n), the same widths; rng-get reads it,
; (rng-set (wheel n)) pins it so rand/randf reproduce, a bad state answering 0 and leaving the
; stream alone. rng-box is bound once, not inlined -- separate copies are separate streams.
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

; /// -- rationals: an exact field as a coin over reduced (num den), a whole one the integer
; itself, so the integers are its subset and = needs no lane of its own. the twin's peer:
; 3 /// 4 builds one, and one prints that way. C knows nothing of it: the die spells its
; measure ('net), its order ('<) and its integer rungs ('int 'ceil) beside its arithmetic
(: /// (: (reduce n d)
         (0 = n ? [0 1]                           ; gcd out, sign on num, den > 0
          (: g (gcd (abs n) (abs d)) s (? (d < 0) -1 1)
           [(s * n // g) (s * d // g)]))
        (arg v) (? (coin? v) (load v) (two? v) v [v 1])       ; an operand as (n d): a bare star is n/1
        ; the domain test is the closed star: an open star as an (n d) component would
        ; drag gcd off the tower it terminates on -- a coin is never a coefficient.
        (nstar? v) ((atom? v) && (nil? * coin?) v && v = +v)   ; a chain is no star, and may not reach =: its net
                                                            ; is a rational whose '= would ask this again
        (ok? v) (nstar? v || (two? v && all nstar? v))
        (q p) (? (1 = <>p) <p (c p))                          ; a reduced (n d): the integer when d is 1, else struck
        (measure c) (: p (load c) q (<p / <>p)                ; n/d: truth is the value's sign, so a quotient
                      (? (<p = 0) 0                             ; lost to underflow keeps it (nonzero at every
                         (q = 0) (? ((<p < 0) = (<>p < 0)) 1e-37 -1e-37)   ; gem width)
                         q))
        (val v) (? (coin? v && ok? (load v)) (measure v) v)   ; a rational as its measure, anything else itself
        c (coin '/// (z \ {'star 1                               ; a rational is a star
         'net measure
         '< (\ a b (: x (arg a) y (arg b)                      ; (n1 d1) < (n2 d2): cross-multiply, exact (d > 0)
             (? (ok? x && ok? y) ((<x * <>y) < (<y * <>x))
                (val a < val b))))                         ; against a non-number: by the measure's band
         '= (\ a b (: x (arg a) y (arg b)                      ; the same cross-multiply, so 7/2 = 3.5 as the
             (? (ok? x && ok? y) ((<x * <>y) = (<y * <>x))     ; order already says
                (val a = val b))))
         'int (c \ (: p (load c) (<p // <>p)))                 ; toward zero
         'ceil (c \ (: p (load c) k (<p // <>p)                ; d > 1 for every coin, so the quotient never
                     (? (0 < <p) (k + 1) k)))                  ; lands: up from a positive trunc, else it is the ceil
         '+ (\ a b (: x (arg a) y (arg b)                    ; (n1 d1) + (n2 d2)
             (? (ok? x && ok? y)
              (q (reduce (<x * <>y + <y * <>x) (<>x * <>y))))))
         '* (\ a b (: x (arg a) y (arg b)                    ; (n1 d1) * (n2 d2)
             (? (ok? x && ok? y)
              (q (reduce (<x * <y) (<>x * <>y))))))
         '- (\ a b (: x (arg a) y (arg b)                    ; (n1 d1) - (n2 d2)
             (? (ok? x && ok? y)
              (q (reduce (<x * <>y - <y * <>x) (<>x * <>y))))))
         '/ (\ a b (: x (arg a) y (arg b)                    ; (n1 d1) / (n2 d2): invert and
             (? (ok? x && ok? y && <y != 0)                  ; multiply; by zero -> () (no inf in Q; cap of a bare star is itself)
              (q (reduce (<x * <>y) (<>x * <y))))))}))
        (n \ (two? n ? (q (reduce <n <>n))                    ; (/// (n d)) -- the list form
                       (q * reduce n)))))                     ; (/// n d) -- the curried form, and 3 /// 4 spaced


; glob -- fnmatch, pure love and no filesystem. the pattern law only: pathname expansion
; (readdir, the dotfile rule at the directory scan) stays in apps/lush.l. this half is a
; predicate over two strings, and more than the shell asks it -- lush's case patterns, kore's
; find -name, the sb ignore law.
; patterns travel as (text . mask) -- the mask a parallel string of '1'/'0' bytes, '1' where
; the char came in unquoted (glob-live), '0' where a quote shielded it ('*' matches a literal
; star). a caller with no quoting to express asks `match`, which is all-live.
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
           ; presence is `two?`, never truth: a class that misses answers (0 . past),
           ; and net drops an improper tail, so a falsy r would read as no class here.
           (two? r ? ((neg ? !<r <r) . >r)))
      (fm i j)
        (? (i = np) (j = ns)
           (: b (p i)
              (? (act? i && b = 42)
                   (fm (i + 1) j || (j < ns && fm i (j + 1)))
                 (act? i && b = 63) (j < ns && fm (i + 1) (j + 1))
                 (act? i && b = 91 && j < ns)
                   (: c (cls i j)
                      (? (atom? c) ((s j) = 91 && fm (i + 1) (j + 1))  ; lone [ is itself
                         (<c && fm >c (j + 1))))
                 (j < ns && s j = b) (fm (i + 1) (j + 1)))))
      (bit (fm 0 0))))

) ; module glob

; path -- the primitives, not the faces. make's $(dir) and posix's dirname disagree about a
; bare name ("./" against "."), so a caller spells its own face over this one shared scan.
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
   (lastdot p) (: sl (lastslash p)
                  ((: (go j) (j > sl ? (p (j - 1) = 46 ? (j - 1) (go (j - 1))) #p)) #p))
   ; "/a/b/c" -> ("/a" "/a/b"): neither the leading '/' nor the leaf is a prefix, so `mkdir -p`
   ; is this walk plus the caller's own mind about the leaf. splitting on '/' and rejoining
   ; would not do -- it drops the leading slash, and /tmp/x becomes tmp/x.
   (pprefixes p)
    (: n #p
       (go i acc) (? (n <= i) (rev acc)
                     (0 < i && p i = 47) (go (i + 1) (snip p 0 i . acc))
                     (go (i + 1) acc))
       (go 0 ()))
   (segs s) ((: (go i st acc)
                (? (i >= #s) (rev (st < i ? (snip s st i . acc) acc))
                   (s i = 47) (go (1 + i) (1 + i) (st < i ? (snip s st i . acc) acc))
                   (go (1 + i) st acc))) 0 0 0)
   ; no filesystem asked: '..' pops lexically, which is what make's $(abspath) means and what
   ; a symlink makes a lie. lim is the climb this caller allows -- how many leading '..' survive:
   ;   ()  unbounded, a '..' with nothing to pop stays one (the shell's own face)
   ;   n   at most n survive; one that would climb past answers () -- refused, not clamped,
   ;       because a clamped path silently names a different file.
   ; a surviving '..' is not popped by the next -- "a/../../b" climbs once and stays (".." "b").
   ; () answers both a refusal and an empty path.
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

; bytes -- words in and out of byte strings, the conversions every codec and wire protocol
; keeps writing. a reader takes anything that indexes by application: a string, a cask, a
; list. & and >> are exact on a big and on a negative, so a 64-bit word needs no care.
;   (rdle s i n) (rdbe s i n) -> the n-byte word at i, little- and big-endian
;   (wrle v n) (wrbe v n)     -> v as n bytes, the low n kept (two's complement for v < 0)
;   (rdoct s i n) -> the octal text in the n bytes at i, to its first non-digit (tar's fields)
;   (padk n k)   -> the bytes from n to the next multiple of k
;   (zbytes n)   -> n NULs
;   (b2hex s) (hex2b h) -> bytes as lowercase hex, and hex (either case) back
;   (xorb a b)   -> a with b xored in, byte by byte, #a long

(module '(bytes rdle rdbe rdoct wrle wrbe padk zbytes b2hex hex2b xorb)
(: (rdle s i n) (? (n < 1) 0 (s i + (rdle s (i + 1) (n - 1) << 8)))
   (rdbe s i n) (: (go k a) (? (n <= k) a (go (k + 1) ((a << 8) + s (i + k)))) (go 0 0))
   (rdoct s i n) (: (go k a) (? (n <= k) a (: c (s (i + k)) (48 <= c < 56 ? (go (k + 1) (a * 8 + c - 48)) a)))
                    (go 0 0))
   (wrle v n) (? (n < 1) "" (string (v & 255) + wrle (v >> 8) (n - 1)))
   (wrbe v n) (? (n < 1) "" (wrbe (v >> 8) (n - 1) + string (v & 255)))
   (padk n k) ((k - n % k) % k)
   (zbytes n) (string (cask n))
   (b2hex s) (foldl (a \ i \ a + zpad 2 (radix (s i) 16)) "" ^#s)
   (hex2b h) (: n (#h // 2) b (cask n)
                _ (each ^n (i \ pin b i (hexv (h (2 * i)) * 16 + hexv (h (2 * i + 1)))))
                (string b))
   (xorb a b) (: n #a c (cask n) _ (each ^n (i \ pin c i (a i ^ b i))) (string c)))

) ; module bytes

; cal -- the proleptic gregorian calendar over days since 1970-01-01, utc. floor division
; throughout, so a day before 1970 reads right with no sign fix-up.
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

; text -- utf-8 read as characters and laid in terminal columns. a string stays its bytes and
; these walk it; a bad or torn sequence reads as U+FFFD and costs one byte, as a terminal draws it.
;   (cpat s i) (cpnext s i) -> the code point at byte i, and the byte after it
;   (cpn s i)               -> the bytes a valid character at i wears, else 0
;   (cps s) (cplen s)       -> the code points, and how many
;   (cpsnip s a b)          -> characters a to b
;   (cprev s)               -> s back to front by character
;   (wcwidth c)             -> the columns c takes: 0 1 or 2, -1 for a control, 0 for NUL
;   (swidth s)              -> the columns s takes, a control none
;   (scut s n)              -> the longest head of s at most n columns wide
;   (gcnext s i) (gcwidth s i) -> the byte after the grapheme cluster at i, and its columns, as
;                              quay measures under ?2027
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
   ; tools/mkwidth.l's runs, unicode 17: each entry cp * 4 + w opens a run of width w
(: cpw
   @(1 3072 3521 4620 4649 5700 5881 5884 5889 5892 5901 5904 5913 5916 5921 6208 6253 6256
     6261 6444 6529 6592 6597 7000 7029 7036 7061 7068 7077 7080 7097 7236 7241 7360 7469
     7832 7877 8108 8145 8180 8185 8280 8297 8300 8337 8340 8353 8356 8377 8548 8561 8796
     8833 9000 9097 9100 9229 9448 9453 9456 9461 9476 9509 9524 9529 9540 9569 9608 9617
     9732 9737 9968 9973 9988 10005 10036 10041 10120 10129 10232 10237 10244 10253 10480
     10485 10500 10509 10524 10533 10540 10553 10564 10569 10688 10697 10708 10713 10756
     10765 10992 10997 11012 11033 11036 11045 11060 11065 11144 11153 11240 11265 11268
     11273 11504 11509 11516 11521 11524 11541 11572 11577 11604 11613 11656 11665 11784
     11789 12032 12037 12084 12089 12288 12293 12304 12309 12528 12533 12536 12549 12568
     12581 12584 12601 12628 12637 12680 12689 12804 12809 13040 13045 13052 13057 13080
     13085 13104 13113 13192 13201 13312 13321 13548 13557 13572 13589 13620 13625 13704
     13713 13828 13833 14120 14125 14152 14165 14168 14173 14532 14537 14544 14573 14620
     14653 15044 15049 15056 15093 15136 15165 15456 15465 15572 15577 15580 15585 15588
     15593 15812 15869 15872 15893 15896 15905 15924 15969 15972 16117 16152 16157 16564
     16581 16584 16609 16612 16621 16628 16637 16736 16745 16760 16773 16836 16853 16904
     16909 16916 16925 16948 16953 17012 17017 17410 17792 18433 19828 19841 23624 23637
     23752 23761 23880 23889 24008 24017 24272 24281 24284 24313 24344 24349 24356 24401
     24436 24441 24620 24641 25108 25117 25252 25257 25728 25741 25756 25765 25800 25805
     25828 25841 26716 26725 26732 26737 26968 26973 26976 27005 27008 27013 27016 27021
     27028 27061 27084 27125 27132 27137 27328 27513 27520 27569 27648 27665 27856 27861
     27864 27885 27888 27893 27912 27917 28076 28113 28160 28169 28296 28313 28320 28329
     28332 28345 28568 28573 28576 28585 28596 28601 28604 28617 28848 28881 28888 28897
     29504 29517 29520 29573 29576 29605 29620 29625 29648 29653 29664 29673 30464 30721
     32812 32833 32936 32957 33152 33217 33600 33733 35946 35953 36006 36013 36774 36789
     36802 36805 36814 36817 38902 38909 38994 39001 39106 39137 39202 39249 39422 39425
     39466 39489 39502 39505 39558 39561 39594 39601 39670 39677 39698 39705 39738 39741
     39762 39765 39850 39853 39882 39889 39894 39897 39914 39917 39926 39929 39958 39961
     39978 39985 40098 40101 40242 40245 40250 40253 40270 40281 40286 40289 40534 40545
     40642 40645 40702 40705 44142 44149 44354 44357 44374 44377 46012 46025 46588 46593
     46976 47105 47618 47721 47726 48081 48130 48985 49090 49320 49338 49405 49414 49757
     49764 49774 50177 50198 50369 50374 50576 50582 50749 50754 51097 51134 51325 51330
     168501 168514 168733 170428 170445 170448 170489 170616 170625 170944 170953 172040
     172045 172056 172061 172076 172081 172180 172189 172208 172213 172816 172825 172928
     173001 173052 173057 173208 173241 173340 173385 173442 173557 173568 173581 173772
     173777 173784 173801 173808 173817 173972 173977 174244 174269 174276 174285 174292
     174301 174348 174353 174384 174389 174576 174581 174784 174789 174792 174805 174812
     174821 174840 174849 174852 174857 175024 175033 175064 175069 176020 176025 176032
     176037 176052 176057 176130 220817 220864 220957 220972 221169 254978 257025 257144
     257149 260096 260162 260201 260224 260290 260429 260434 260509 260514 260529 261116
     261121 261126 261509 261760 261765 262018 262045 262080 262117 264180 264185 265088
     265093 265688 265709 272388 272401 272404 272413 272432 272449 272608 272621 272636
     272641 273300 273309 275600 275617 275876 275897 277164 277173 277480 277505 277784
     277829 278024 278041 278532 278537 278752 278813 278976 278981 278988 278997 279036
     279049 279244 279261 279268 279277 279304 279309 279552 279565 279708 279729 279732
     279765 280012 280017 280064 280073 280280 280317 280356 280373 280380 280385 280764
     280777 280784 280789 280792 280801 280824 280829 280836 280841 281468 281473 281484
     281517 281600 281609 281836 281845 281856 281861 282008 282037 282048 282069 282348
     282373 282424 282429 282432 282437 282440 282445 282500 282509 282848 282881 282888
     282901 282904 282909 283000 283005 283340 283365 283368 283373 283388 283397 283400
     283409 284360 284377 284400 284409 284412 284421 284528 284537 284876 284909 284916
     284921 284924 284933 285356 285361 285364 285369 285376 285401 285404 285409 285812
     285817 285820 285825 285832 285849 285852 285873 286908 286945 286948 286957 287980
     287989 287992 287997 288012 288017 288592 288609 288616 288625 288640 288645 288772
     288813 288972 288997 289004 289021 289052 289057 289092 289117 289124 289137 289320
     289373 289376 289385 290176 290181 290184 290197 290200 290205 291008 291037 291040
     291065 291068 291073 291400 291489 291496 291525 291528 291537 291540 291549 292036
     292061 292072 292077 292080 292089 292092 292121 292124 292129 292416 292425 292436
     292441 292444 292449 293836 293845 293888 293897 294104 294125 294144 294149 294152
     294157 294248 294253 315648 315653 315676 315737 361592 361641 361652 361665 371648
     371669 371904 371933 376124 376129 376380 376397 376706 376720 376725 376770 376797
     376834 406361 406526 406653 407042 407501 442306 442321 442326 442353 442358 442365
     442370 443533 443594 443597 443714 443725 443734 443737 443794 443809 443842 445425
     455284 455293 455296 455313 474112 474297 474304 474397 476572 476585 476620 476685
     476692 476721 476840 476857 477448 477461 478210 478557 478594 478685 485376 485597
     485612 485813 485844 485849 485904 485909 485996 486017 486020 486081 491520 491549
     491552 491621 491628 491657 491660 491669 491672 491693 492092 492097 492736 492765
     494264 494269 494512 494529 496560 496577 497592 497601 498572 498577 498584 498589
     498616 498625 498644 498649 500544 500573 501008 501037 507922 507925 508734 508737
     509498 509501 509510 509549 509954 509965 510018 510193 510210 510245 510274 510281
     510338 510361 510978 511109 511158 511193 511198 511477 511482 511569 511618 511789
     511806 511825 511874 511941 511954 511957 511970 512253 512258 512261 512266 513013
     513022 513273 513326 513341 513346 513441 513514 513517 513622 513629 513682 513685
     514030 514369 514562 514841 514866 514869 514882 514893 514902 514917 514930 514945
     514990 514997 515026 515061 515970 516017 516034 516037 517170 517357 517362 517401
     517406 518145 518594 518645 518658 518701 518714 518941 518946 518949 518966 519029
     519038 519085 519102 519141 524290 786425 786434 1048569 3670016 3686401)
   ; tools/mkctype.l's classes, unicode 17 and equal to glibc 2.44's: each tray's entries open
   ; and close runs in turn. then the case maps, each as runs of start count stride delta
   cpalpha
   @(65 91 97 123 170 171 181 182 186 187 192 215 216 247 248 706 710 722 736 741 748 749 750
     751 837 838 867 885 886 888 890 894 895 896 902 903 904 907 908 909 910 930 931 1014
     1015 1154 1162 1328 1329 1367 1369 1370 1376 1417 1456 1470 1471 1472 1473 1475 1476
     1478 1479 1480 1488 1515 1519 1523 1552 1563 1568 1624 1625 1642 1646 1748 1749 1757
     1761 1769 1773 1789 1791 1792 1808 1856 1869 1970 1984 2027 2036 2038 2042 2043 2048
     2072 2074 2093 2112 2137 2144 2155 2160 2184 2185 2192 2199 2200 2208 2250 2260 2272
     2275 2282 2288 2364 2365 2381 2382 2385 2389 2404 2406 2416 2417 2436 2437 2445 2447
     2449 2451 2473 2474 2481 2482 2483 2486 2490 2493 2501 2503 2505 2507 2509 2510 2511
     2519 2520 2524 2526 2527 2532 2534 2546 2556 2557 2561 2564 2565 2571 2575 2577 2579
     2601 2602 2609 2610 2612 2613 2615 2616 2618 2622 2627 2631 2633 2635 2637 2641 2642
     2649 2653 2654 2655 2662 2678 2689 2692 2693 2702 2703 2706 2707 2729 2730 2737 2738
     2740 2741 2746 2749 2758 2759 2762 2763 2765 2768 2769 2784 2788 2790 2800 2809 2813
     2817 2820 2821 2829 2831 2833 2835 2857 2858 2865 2866 2868 2869 2874 2877 2885 2887
     2889 2891 2893 2902 2904 2908 2910 2911 2916 2918 2928 2929 2930 2946 2948 2949 2955
     2958 2961 2962 2966 2969 2971 2972 2973 2974 2976 2979 2981 2984 2987 2990 3002 3006
     3011 3014 3017 3018 3021 3024 3025 3031 3032 3046 3056 3072 3085 3086 3089 3090 3113
     3114 3130 3133 3141 3142 3145 3146 3149 3157 3159 3160 3163 3164 3166 3168 3172 3174
     3184 3200 3204 3205 3213 3214 3217 3218 3241 3242 3252 3253 3258 3261 3269 3270 3273
     3274 3277 3285 3287 3292 3295 3296 3300 3302 3312 3313 3316 3328 3341 3342 3345 3346
     3387 3389 3397 3398 3401 3402 3405 3406 3407 3412 3416 3423 3428 3430 3440 3450 3456
     3457 3460 3461 3479 3482 3506 3507 3516 3517 3518 3520 3527 3535 3541 3542 3543 3544
     3552 3558 3568 3570 3572 3585 3643 3648 3655 3661 3662 3664 3674 3713 3715 3716 3717
     3718 3723 3724 3748 3749 3750 3751 3770 3771 3774 3776 3781 3782 3783 3789 3790 3792
     3802 3804 3808 3840 3841 3872 3882 3904 3912 3913 3949 3953 3972 3976 3992 3993 4029
     4096 4151 4152 4153 4155 4170 4176 4254 4256 4294 4295 4296 4301 4302 4304 4347 4348
     4681 4682 4686 4688 4695 4696 4697 4698 4702 4704 4745 4746 4750 4752 4785 4786 4790
     4792 4799 4800 4801 4802 4806 4808 4823 4824 4881 4882 4886 4888 4955 4992 5008 5024
     5110 5112 5118 5121 5741 5743 5760 5761 5787 5792 5867 5870 5881 5888 5908 5919 5940
     5952 5972 5984 5997 5998 6001 6002 6004 6016 6068 6070 6089 6103 6104 6108 6109 6112
     6122 6160 6170 6176 6265 6272 6315 6320 6390 6400 6431 6432 6444 6448 6457 6470 6510
     6512 6517 6528 6572 6576 6602 6608 6618 6656 6684 6688 6751 6753 6773 6784 6794 6800
     6810 6823 6824 6847 6849 6860 6863 6912 6964 6965 6980 6981 6989 6992 7002 7040 7082
     7084 7142 7143 7154 7168 7223 7232 7242 7245 7294 7296 7307 7312 7355 7357 7360 7401
     7405 7406 7412 7413 7415 7418 7419 7424 7616 7635 7669 7680 7958 7960 7966 7968 8006
     8008 8014 8016 8024 8025 8026 8027 8028 8029 8030 8031 8062 8064 8117 8118 8125 8126
     8127 8130 8133 8134 8141 8144 8148 8150 8156 8160 8173 8178 8181 8182 8189 8305 8306
     8319 8320 8336 8349 8450 8451 8455 8456 8458 8468 8469 8470 8473 8478 8484 8485 8486
     8487 8488 8489 8490 8494 8495 8506 8508 8512 8517 8522 8526 8527 8544 8585 9398 9450
     11264 11493 11499 11503 11506 11508 11520 11558 11559 11560 11565 11566 11568 11624
     11631 11632 11648 11671 11680 11687 11688 11695 11696 11703 11704 11711 11712 11719
     11720 11727 11728 11735 11736 11743 11744 11776 11823 11824 12293 12296 12321 12330
     12337 12342 12344 12349 12353 12439 12445 12448 12449 12539 12540 12544 12549 12592
     12593 12687 12704 12736 12784 12800 13312 19904 19968 42125 42192 42238 42240 42509
     42512 42540 42560 42607 42612 42620 42623 42736 42775 42784 42786 42889 42891 42973
     42993 43014 43015 43048 43072 43124 43136 43204 43205 43206 43216 43226 43250 43256
     43259 43260 43261 43307 43312 43347 43360 43389 43392 43443 43444 43456 43471 43482
     43488 43519 43520 43575 43584 43598 43600 43610 43616 43639 43642 43711 43712 43713
     43714 43715 43739 43742 43744 43760 43762 43766 43777 43783 43785 43791 43793 43799
     43808 43815 43816 43823 43824 43867 43868 43882 43888 44011 44016 44026 44032 55204
     55216 55239 55243 55292 63744 64110 64112 64218 64256 64263 64275 64280 64285 64297
     64298 64311 64312 64317 64318 64319 64320 64322 64323 64325 64326 64434 64467 64830
     64848 64912 64914 64968 65008 65020 65136 65141 65142 65277 65296 65306 65313 65339
     65345 65371 65382 65471 65474 65480 65482 65488 65490 65496 65498 65501 65536 65548
     65549 65575 65576 65595 65596 65598 65599 65614 65616 65630 65664 65787 65856 65909
     66176 66205 66208 66257 66304 66336 66349 66379 66384 66427 66432 66462 66464 66500
     66504 66512 66513 66518 66560 66718 66720 66730 66736 66772 66776 66812 66816 66856
     66864 66916 66928 66939 66940 66955 66956 66963 66964 66966 66967 66978 66979 66994
     66995 67002 67003 67005 67008 67060 67072 67383 67392 67414 67424 67432 67456 67462
     67463 67505 67506 67515 67584 67590 67592 67593 67594 67638 67639 67641 67644 67645
     67647 67670 67680 67703 67712 67743 67808 67827 67828 67830 67840 67862 67872 67898
     67904 67930 67968 68024 68030 68032 68096 68100 68101 68103 68108 68116 68117 68120
     68121 68150 68192 68221 68224 68253 68288 68296 68297 68325 68352 68406 68416 68438
     68448 68467 68480 68498 68608 68681 68736 68787 68800 68851 68864 68904 68912 68922
     68928 68966 68969 68970 68975 68998 69248 69290 69291 69293 69296 69298 69314 69320
     69370 69373 69376 69405 69415 69416 69424 69446 69488 69506 69552 69573 69600 69623
     69632 69702 69734 69744 69745 69750 69760 69817 69826 69827 69840 69865 69872 69882
     69888 69939 69942 69952 69956 69960 69968 70003 70006 70007 70016 70080 70081 70085
     70094 70107 70108 70109 70144 70162 70163 70197 70199 70200 70206 70210 70272 70279
     70280 70281 70282 70286 70287 70302 70303 70313 70320 70377 70384 70394 70400 70404
     70405 70413 70415 70417 70419 70441 70442 70449 70450 70452 70453 70458 70461 70469
     70471 70473 70475 70477 70480 70481 70487 70488 70493 70500 70528 70538 70539 70540
     70542 70543 70544 70582 70583 70593 70594 70595 70597 70598 70599 70603 70604 70606
     70609 70610 70611 70612 70656 70722 70723 70726 70727 70731 70736 70746 70751 70754
     70784 70850 70852 70854 70855 70856 70864 70874 71040 71094 71096 71103 71128 71134
     71168 71231 71232 71233 71236 71237 71248 71258 71296 71350 71352 71353 71360 71370
     71376 71396 71424 71451 71453 71467 71472 71482 71488 71495 71680 71737 71840 71914
     71935 71943 71945 71946 71948 71956 71957 71959 71960 71990 71991 71993 71995 71997
     71999 72003 72016 72026 72096 72104 72106 72152 72154 72160 72161 72162 72163 72165
     72192 72243 72245 72255 72272 72344 72349 72350 72368 72441 72544 72552 72640 72673
     72688 72698 72704 72713 72714 72759 72760 72767 72768 72769 72784 72794 72818 72848
     72850 72872 72873 72887 72960 72967 72968 72970 72971 73015 73018 73019 73020 73022
     73023 73026 73027 73028 73030 73032 73040 73050 73056 73062 73063 73065 73066 73103
     73104 73106 73107 73111 73112 73113 73120 73130 73136 73180 73184 73194 73440 73463
     73472 73489 73490 73531 73534 73537 73552 73562 73648 73649 73728 74650 74752 74863
     74880 75076 77712 77809 77824 78896 78913 78919 78944 82939 82944 83527 90368 90415
     90416 90426 92160 92729 92736 92767 92768 92778 92784 92863 92864 92874 92880 92910
     92928 92976 92992 92996 93008 93018 93027 93048 93053 93072 93504 93549 93552 93562
     93760 93824 93856 93881 93883 93908 93952 94027 94031 94088 94095 94112 94176 94178
     94179 94180 94192 94199 94208 101590 101631 101663 101760 101875 110576 110580 110581
     110588 110589 110591 110592 110883 110898 110899 110928 110931 110933 110934 110948
     110952 110960 111356 113664 113771 113776 113789 113792 113801 113808 113818 113822
     113823 118000 118010 119808 119893 119894 119965 119966 119968 119970 119971 119973
     119975 119977 119981 119982 119994 119995 119996 119997 120004 120005 120070 120071
     120075 120077 120085 120086 120093 120094 120122 120123 120127 120128 120133 120134
     120135 120138 120145 120146 120486 120488 120513 120514 120539 120540 120571 120572
     120597 120598 120629 120630 120655 120656 120687 120688 120713 120714 120745 120746
     120771 120772 120780 120782 120832 122624 122655 122661 122667 122880 122887 122888
     122905 122907 122914 122915 122917 122918 122923 122928 122990 123023 123024 123136
     123181 123191 123198 123200 123210 123214 123215 123536 123566 123584 123628 123632
     123642 124112 124140 124144 124154 124368 124398 124400 124411 124608 124639 124640
     124662 124670 124672 124896 124903 124904 124908 124909 124911 124912 124927 124928
     125125 125184 125252 125255 125256 125259 125260 125264 125274 126464 126468 126469
     126496 126497 126499 126500 126501 126503 126504 126505 126515 126516 126520 126521
     126522 126523 126524 126530 126531 126535 126536 126537 126538 126539 126540 126541
     126544 126545 126547 126548 126549 126551 126552 126553 126554 126555 126556 126557
     126558 126559 126560 126561 126563 126564 126565 126567 126571 126572 126579 126580
     126584 126585 126589 126590 126591 126592 126602 126603 126620 126625 126628 126629
     126634 126635 126652 127280 127306 127312 127338 127344 127370 130032 130042 131072
     173792 173824 178206 178208 183982 183984 191457 191472 192094 194560 195102 196608
     201547 201552 210042)
   cpupc
   @(65 91 192 215 216 223 256 257 258 259 260 261 262 263 264 265 266 267 268 269 270 271
     272 273 274 275 276 277 278 279 280 281 282 283 284 285 286 287 288 289 290 291 292 293
     294 295 296 297 298 299 300 301 302 303 304 305 306 307 308 309 310 311 313 314 315 316
     317 318 319 320 321 322 323 324 325 326 327 328 330 331 332 333 334 335 336 337 338 339
     340 341 342 343 344 345 346 347 348 349 350 351 352 353 354 355 356 357 358 359 360 361
     362 363 364 365 366 367 368 369 370 371 372 373 374 375 376 378 379 380 381 382 385 387
     388 389 390 392 393 396 398 402 403 405 406 409 412 414 415 417 418 419 420 421 422 424
     425 426 428 429 430 432 433 436 437 438 439 441 444 445 452 454 455 457 458 460 461 462
     463 464 465 466 467 468 469 470 471 472 473 474 475 476 478 479 480 481 482 483 484 485
     486 487 488 489 490 491 492 493 494 495 497 499 500 501 502 505 506 507 508 509 510 511
     512 513 514 515 516 517 518 519 520 521 522 523 524 525 526 527 528 529 530 531 532 533
     534 535 536 537 538 539 540 541 542 543 544 545 546 547 548 549 550 551 552 553 554 555
     556 557 558 559 560 561 562 563 570 572 573 575 577 578 579 583 584 585 586 587 588 589
     590 591 880 881 882 883 886 887 895 896 902 903 904 907 908 909 910 912 913 930 931 940
     975 976 978 981 984 985 986 987 988 989 990 991 992 993 994 995 996 997 998 999 1000
     1001 1002 1003 1004 1005 1006 1007 1012 1013 1015 1016 1017 1019 1021 1072 1120 1121
     1122 1123 1124 1125 1126 1127 1128 1129 1130 1131 1132 1133 1134 1135 1136 1137 1138
     1139 1140 1141 1142 1143 1144 1145 1146 1147 1148 1149 1150 1151 1152 1153 1162 1163
     1164 1165 1166 1167 1168 1169 1170 1171 1172 1173 1174 1175 1176 1177 1178 1179 1180
     1181 1182 1183 1184 1185 1186 1187 1188 1189 1190 1191 1192 1193 1194 1195 1196 1197
     1198 1199 1200 1201 1202 1203 1204 1205 1206 1207 1208 1209 1210 1211 1212 1213 1214
     1215 1216 1218 1219 1220 1221 1222 1223 1224 1225 1226 1227 1228 1229 1230 1232 1233
     1234 1235 1236 1237 1238 1239 1240 1241 1242 1243 1244 1245 1246 1247 1248 1249 1250
     1251 1252 1253 1254 1255 1256 1257 1258 1259 1260 1261 1262 1263 1264 1265 1266 1267
     1268 1269 1270 1271 1272 1273 1274 1275 1276 1277 1278 1279 1280 1281 1282 1283 1284
     1285 1286 1287 1288 1289 1290 1291 1292 1293 1294 1295 1296 1297 1298 1299 1300 1301
     1302 1303 1304 1305 1306 1307 1308 1309 1310 1311 1312 1313 1314 1315 1316 1317 1318
     1319 1320 1321 1322 1323 1324 1325 1326 1327 1329 1367 4256 4294 4295 4296 4301 4302
     5024 5110 7305 7306 7312 7355 7357 7360 7680 7681 7682 7683 7684 7685 7686 7687 7688
     7689 7690 7691 7692 7693 7694 7695 7696 7697 7698 7699 7700 7701 7702 7703 7704 7705
     7706 7707 7708 7709 7710 7711 7712 7713 7714 7715 7716 7717 7718 7719 7720 7721 7722
     7723 7724 7725 7726 7727 7728 7729 7730 7731 7732 7733 7734 7735 7736 7737 7738 7739
     7740 7741 7742 7743 7744 7745 7746 7747 7748 7749 7750 7751 7752 7753 7754 7755 7756
     7757 7758 7759 7760 7761 7762 7763 7764 7765 7766 7767 7768 7769 7770 7771 7772 7773
     7774 7775 7776 7777 7778 7779 7780 7781 7782 7783 7784 7785 7786 7787 7788 7789 7790
     7791 7792 7793 7794 7795 7796 7797 7798 7799 7800 7801 7802 7803 7804 7805 7806 7807
     7808 7809 7810 7811 7812 7813 7814 7815 7816 7817 7818 7819 7820 7821 7822 7823 7824
     7825 7826 7827 7828 7829 7838 7839 7840 7841 7842 7843 7844 7845 7846 7847 7848 7849
     7850 7851 7852 7853 7854 7855 7856 7857 7858 7859 7860 7861 7862 7863 7864 7865 7866
     7867 7868 7869 7870 7871 7872 7873 7874 7875 7876 7877 7878 7879 7880 7881 7882 7883
     7884 7885 7886 7887 7888 7889 7890 7891 7892 7893 7894 7895 7896 7897 7898 7899 7900
     7901 7902 7903 7904 7905 7906 7907 7908 7909 7910 7911 7912 7913 7914 7915 7916 7917
     7918 7919 7920 7921 7922 7923 7924 7925 7926 7927 7928 7929 7930 7931 7932 7933 7934
     7935 7944 7952 7960 7966 7976 7984 7992 8000 8008 8014 8025 8026 8027 8028 8029 8030
     8031 8032 8040 8048 8072 8080 8088 8096 8104 8112 8120 8125 8136 8141 8152 8156 8168
     8173 8184 8189 8450 8451 8455 8456 8459 8462 8464 8467 8469 8470 8473 8478 8484 8485
     8486 8487 8488 8489 8490 8494 8496 8500 8510 8512 8517 8518 8544 8560 8579 8580 9398
     9424 11264 11312 11360 11361 11362 11365 11367 11368 11369 11370 11371 11372 11373 11377
     11378 11379 11381 11382 11390 11393 11394 11395 11396 11397 11398 11399 11400 11401
     11402 11403 11404 11405 11406 11407 11408 11409 11410 11411 11412 11413 11414 11415
     11416 11417 11418 11419 11420 11421 11422 11423 11424 11425 11426 11427 11428 11429
     11430 11431 11432 11433 11434 11435 11436 11437 11438 11439 11440 11441 11442 11443
     11444 11445 11446 11447 11448 11449 11450 11451 11452 11453 11454 11455 11456 11457
     11458 11459 11460 11461 11462 11463 11464 11465 11466 11467 11468 11469 11470 11471
     11472 11473 11474 11475 11476 11477 11478 11479 11480 11481 11482 11483 11484 11485
     11486 11487 11488 11489 11490 11491 11499 11500 11501 11502 11506 11507 42560 42561
     42562 42563 42564 42565 42566 42567 42568 42569 42570 42571 42572 42573 42574 42575
     42576 42577 42578 42579 42580 42581 42582 42583 42584 42585 42586 42587 42588 42589
     42590 42591 42592 42593 42594 42595 42596 42597 42598 42599 42600 42601 42602 42603
     42604 42605 42624 42625 42626 42627 42628 42629 42630 42631 42632 42633 42634 42635
     42636 42637 42638 42639 42640 42641 42642 42643 42644 42645 42646 42647 42648 42649
     42650 42651 42786 42787 42788 42789 42790 42791 42792 42793 42794 42795 42796 42797
     42798 42799 42802 42803 42804 42805 42806 42807 42808 42809 42810 42811 42812 42813
     42814 42815 42816 42817 42818 42819 42820 42821 42822 42823 42824 42825 42826 42827
     42828 42829 42830 42831 42832 42833 42834 42835 42836 42837 42838 42839 42840 42841
     42842 42843 42844 42845 42846 42847 42848 42849 42850 42851 42852 42853 42854 42855
     42856 42857 42858 42859 42860 42861 42862 42863 42873 42874 42875 42876 42877 42879
     42880 42881 42882 42883 42884 42885 42886 42887 42891 42892 42893 42894 42896 42897
     42898 42899 42902 42903 42904 42905 42906 42907 42908 42909 42910 42911 42912 42913
     42914 42915 42916 42917 42918 42919 42920 42921 42922 42927 42928 42933 42934 42935
     42936 42937 42938 42939 42940 42941 42942 42943 42944 42945 42946 42947 42948 42952
     42953 42954 42955 42957 42958 42959 42960 42961 42962 42963 42964 42965 42966 42967
     42968 42969 42970 42971 42972 42973 42997 42998 65313 65339 66560 66600 66736 66772
     66928 66939 66940 66955 66956 66963 66964 66966 68736 68787 68944 68966 71840 71872
     93760 93792 93856 93881 119808 119834 119860 119886 119912 119938 119964 119965 119966
     119968 119970 119971 119973 119975 119977 119981 119982 119990 120016 120042 120068
     120070 120071 120075 120077 120085 120086 120093 120120 120122 120123 120127 120128
     120133 120134 120135 120138 120145 120172 120198 120224 120250 120276 120302 120328
     120354 120380 120406 120432 120458 120488 120513 120546 120571 120604 120629 120662
     120687 120720 120745 120778 120779 125184 125218 127280 127306 127312 127338 127344
     127370)
   cplowc
   @(97 123 170 171 181 182 186 187 223 247 248 256 257 258 259 260 261 262 263 264 265 266
     267 268 269 270 271 272 273 274 275 276 277 278 279 280 281 282 283 284 285 286 287 288
     289 290 291 292 293 294 295 296 297 298 299 300 301 302 303 304 305 306 307 308 309 310
     311 313 314 315 316 317 318 319 320 321 322 323 324 325 326 327 328 330 331 332 333 334
     335 336 337 338 339 340 341 342 343 344 345 346 347 348 349 350 351 352 353 354 355 356
     357 358 359 360 361 362 363 364 365 366 367 368 369 370 371 372 373 374 375 376 378 379
     380 381 382 385 387 388 389 390 392 393 396 398 402 403 405 406 409 412 414 415 417 418
     419 420 421 422 424 425 426 428 429 430 432 433 436 437 438 439 441 443 445 448 453 455
     456 458 459 461 462 463 464 465 466 467 468 469 470 471 472 473 474 475 476 478 479 480
     481 482 483 484 485 486 487 488 489 490 491 492 493 494 495 497 498 500 501 502 505 506
     507 508 509 510 511 512 513 514 515 516 517 518 519 520 521 522 523 524 525 526 527 528
     529 530 531 532 533 534 535 536 537 538 539 540 541 542 543 544 545 546 547 548 549 550
     551 552 553 554 555 556 557 558 559 560 561 562 563 570 572 573 575 577 578 579 583 584
     585 586 587 588 589 590 591 660 662 697 704 706 736 741 837 838 881 882 883 884 887 888
     890 894 912 913 940 975 976 978 981 984 985 986 987 988 989 990 991 992 993 994 995 996
     997 998 999 1000 1001 1002 1003 1004 1005 1006 1007 1012 1013 1014 1016 1017 1019 1021
     1072 1120 1121 1122 1123 1124 1125 1126 1127 1128 1129 1130 1131 1132 1133 1134 1135
     1136 1137 1138 1139 1140 1141 1142 1143 1144 1145 1146 1147 1148 1149 1150 1151 1152
     1153 1154 1163 1164 1165 1166 1167 1168 1169 1170 1171 1172 1173 1174 1175 1176 1177
     1178 1179 1180 1181 1182 1183 1184 1185 1186 1187 1188 1189 1190 1191 1192 1193 1194
     1195 1196 1197 1198 1199 1200 1201 1202 1203 1204 1205 1206 1207 1208 1209 1210 1211
     1212 1213 1214 1215 1216 1218 1219 1220 1221 1222 1223 1224 1225 1226 1227 1228 1229
     1230 1232 1233 1234 1235 1236 1237 1238 1239 1240 1241 1242 1243 1244 1245 1246 1247
     1248 1249 1250 1251 1252 1253 1254 1255 1256 1257 1258 1259 1260 1261 1262 1263 1264
     1265 1266 1267 1268 1269 1270 1271 1272 1273 1274 1275 1276 1277 1278 1279 1280 1281
     1282 1283 1284 1285 1286 1287 1288 1289 1290 1291 1292 1293 1294 1295 1296 1297 1298
     1299 1300 1301 1302 1303 1304 1305 1306 1307 1308 1309 1310 1311 1312 1313 1314 1315
     1316 1317 1318 1319 1320 1321 1322 1323 1324 1325 1326 1327 1328 1376 1417 4304 4347
     4348 4352 5112 5118 7296 7305 7306 7307 7424 7616 7681 7682 7683 7684 7685 7686 7687
     7688 7689 7690 7691 7692 7693 7694 7695 7696 7697 7698 7699 7700 7701 7702 7703 7704
     7705 7706 7707 7708 7709 7710 7711 7712 7713 7714 7715 7716 7717 7718 7719 7720 7721
     7722 7723 7724 7725 7726 7727 7728 7729 7730 7731 7732 7733 7734 7735 7736 7737 7738
     7739 7740 7741 7742 7743 7744 7745 7746 7747 7748 7749 7750 7751 7752 7753 7754 7755
     7756 7757 7758 7759 7760 7761 7762 7763 7764 7765 7766 7767 7768 7769 7770 7771 7772
     7773 7774 7775 7776 7777 7778 7779 7780 7781 7782 7783 7784 7785 7786 7787 7788 7789
     7790 7791 7792 7793 7794 7795 7796 7797 7798 7799 7800 7801 7802 7803 7804 7805 7806
     7807 7808 7809 7810 7811 7812 7813 7814 7815 7816 7817 7818 7819 7820 7821 7822 7823
     7824 7825 7826 7827 7828 7829 7838 7839 7840 7841 7842 7843 7844 7845 7846 7847 7848
     7849 7850 7851 7852 7853 7854 7855 7856 7857 7858 7859 7860 7861 7862 7863 7864 7865
     7866 7867 7868 7869 7870 7871 7872 7873 7874 7875 7876 7877 7878 7879 7880 7881 7882
     7883 7884 7885 7886 7887 7888 7889 7890 7891 7892 7893 7894 7895 7896 7897 7898 7899
     7900 7901 7902 7903 7904 7905 7906 7907 7908 7909 7910 7911 7912 7913 7914 7915 7916
     7917 7918 7919 7920 7921 7922 7923 7924 7925 7926 7927 7928 7929 7930 7931 7932 7933
     7934 7935 7944 7952 7958 7968 7976 7984 7992 8000 8006 8016 8024 8032 8040 8048 8062
     8064 8072 8080 8088 8096 8104 8112 8117 8118 8120 8126 8127 8130 8133 8134 8136 8144
     8148 8150 8152 8160 8168 8178 8181 8182 8184 8305 8306 8319 8320 8336 8349 8458 8459
     8462 8464 8467 8468 8495 8496 8500 8501 8505 8506 8508 8510 8518 8522 8526 8527 8560
     8576 8580 8581 9424 9450 11312 11360 11361 11362 11365 11367 11368 11369 11370 11371
     11372 11373 11377 11378 11379 11381 11382 11390 11393 11394 11395 11396 11397 11398
     11399 11400 11401 11402 11403 11404 11405 11406 11407 11408 11409 11410 11411 11412
     11413 11414 11415 11416 11417 11418 11419 11420 11421 11422 11423 11424 11425 11426
     11427 11428 11429 11430 11431 11432 11433 11434 11435 11436 11437 11438 11439 11440
     11441 11442 11443 11444 11445 11446 11447 11448 11449 11450 11451 11452 11453 11454
     11455 11456 11457 11458 11459 11460 11461 11462 11463 11464 11465 11466 11467 11468
     11469 11470 11471 11472 11473 11474 11475 11476 11477 11478 11479 11480 11481 11482
     11483 11484 11485 11486 11487 11488 11489 11490 11491 11493 11500 11501 11502 11503
     11507 11508 11520 11558 11559 11560 11565 11566 42561 42562 42563 42564 42565 42566
     42567 42568 42569 42570 42571 42572 42573 42574 42575 42576 42577 42578 42579 42580
     42581 42582 42583 42584 42585 42586 42587 42588 42589 42590 42591 42592 42593 42594
     42595 42596 42597 42598 42599 42600 42601 42602 42603 42604 42605 42606 42625 42626
     42627 42628 42629 42630 42631 42632 42633 42634 42635 42636 42637 42638 42639 42640
     42641 42642 42643 42644 42645 42646 42647 42648 42649 42650 42651 42654 42787 42788
     42789 42790 42791 42792 42793 42794 42795 42796 42797 42798 42799 42802 42803 42804
     42805 42806 42807 42808 42809 42810 42811 42812 42813 42814 42815 42816 42817 42818
     42819 42820 42821 42822 42823 42824 42825 42826 42827 42828 42829 42830 42831 42832
     42833 42834 42835 42836 42837 42838 42839 42840 42841 42842 42843 42844 42845 42846
     42847 42848 42849 42850 42851 42852 42853 42854 42855 42856 42857 42858 42859 42860
     42861 42862 42863 42873 42874 42875 42876 42877 42879 42880 42881 42882 42883 42884
     42885 42886 42887 42888 42892 42893 42894 42895 42897 42898 42899 42902 42903 42904
     42905 42906 42907 42908 42909 42910 42911 42912 42913 42914 42915 42916 42917 42918
     42919 42920 42921 42922 42927 42928 42933 42934 42935 42936 42937 42938 42939 42940
     42941 42942 42943 42944 42945 42946 42947 42948 42952 42953 42954 42955 42957 42958
     42959 42960 42961 42962 42963 42964 42965 42966 42967 42968 42969 42970 42971 42972
     42993 42997 42998 42999 43000 43003 43824 43867 43868 43882 43888 43968 64256 64263
     64275 64280 65345 65371 66600 66640 66776 66812 66967 66978 66979 66994 66995 67002
     67003 67005 67456 67457 67459 67462 67463 67505 67506 67515 68800 68851 68976 68998
     71872 71904 93792 93824 93883 93908 119834 119860 119886 119893 119894 119912 119938
     119964 119990 119994 119995 119996 119997 120004 120005 120016 120042 120068 120094
     120120 120146 120172 120198 120224 120250 120276 120302 120328 120354 120380 120406
     120432 120458 120486 120514 120539 120540 120546 120572 120597 120598 120604 120630
     120655 120656 120662 120688 120713 120714 120720 120746 120771 120772 120778 120779
     120780 122624 122634 122635 122655 122661 122667 122928 122990 125218 125252)
   cpprint
   @(32 127 160 888 890 896 900 907 908 909 910 930 931 1328 1329 1367 1369 1419 1421 1424
     1425 1480 1488 1515 1519 1525 1536 1806 1807 1867 1869 1970 1984 2043 2045 2094 2096
     2111 2112 2140 2142 2143 2144 2155 2160 2194 2199 2436 2437 2445 2447 2449 2451 2473
     2474 2481 2482 2483 2486 2490 2492 2501 2503 2505 2507 2511 2519 2520 2524 2526 2527
     2532 2534 2559 2561 2564 2565 2571 2575 2577 2579 2601 2602 2609 2610 2612 2613 2615
     2616 2618 2620 2621 2622 2627 2631 2633 2635 2638 2641 2642 2649 2653 2654 2655 2662
     2679 2689 2692 2693 2702 2703 2706 2707 2729 2730 2737 2738 2740 2741 2746 2748 2758
     2759 2762 2763 2766 2768 2769 2784 2788 2790 2802 2809 2816 2817 2820 2821 2829 2831
     2833 2835 2857 2858 2865 2866 2868 2869 2874 2876 2885 2887 2889 2891 2894 2901 2904
     2908 2910 2911 2916 2918 2936 2946 2948 2949 2955 2958 2961 2962 2966 2969 2971 2972
     2973 2974 2976 2979 2981 2984 2987 2990 3002 3006 3011 3014 3017 3018 3022 3024 3025
     3031 3032 3046 3067 3072 3085 3086 3089 3090 3113 3114 3130 3132 3141 3142 3145 3146
     3150 3157 3159 3160 3163 3164 3166 3168 3172 3174 3184 3191 3213 3214 3217 3218 3241
     3242 3252 3253 3258 3260 3269 3270 3273 3274 3278 3285 3287 3292 3295 3296 3300 3302
     3312 3313 3316 3328 3341 3342 3345 3346 3397 3398 3401 3402 3408 3412 3428 3430 3456
     3457 3460 3461 3479 3482 3506 3507 3516 3517 3518 3520 3527 3530 3531 3535 3541 3542
     3543 3544 3552 3558 3568 3570 3573 3585 3643 3647 3676 3713 3715 3716 3717 3718 3723
     3724 3748 3749 3750 3751 3774 3776 3781 3782 3783 3784 3791 3792 3802 3804 3808 3840
     3912 3913 3949 3953 3992 3993 4029 4030 4045 4046 4059 4096 4294 4295 4296 4301 4302
     4304 4681 4682 4686 4688 4695 4696 4697 4698 4702 4704 4745 4746 4750 4752 4785 4786
     4790 4792 4799 4800 4801 4802 4806 4808 4823 4824 4881 4882 4886 4888 4955 4957 4989
     4992 5018 5024 5110 5112 5118 5120 5789 5792 5881 5888 5910 5919 5943 5952 5972 5984
     5997 5998 6001 6002 6004 6016 6110 6112 6122 6128 6138 6144 6170 6176 6265 6272 6315
     6320 6390 6400 6431 6432 6444 6448 6460 6464 6465 6468 6510 6512 6517 6528 6572 6576
     6602 6608 6619 6622 6684 6686 6751 6752 6781 6783 6794 6800 6810 6816 6830 6832 6878
     6880 6892 6912 6989 6990 7156 7164 7224 7227 7242 7245 7307 7312 7355 7357 7368 7376
     7419 7424 7958 7960 7966 7968 8006 8008 8014 8016 8024 8025 8026 8027 8028 8029 8030
     8031 8062 8064 8117 8118 8133 8134 8148 8150 8156 8157 8176 8178 8181 8182 8191 8192
     8232 8234 8293 8294 8306 8308 8335 8336 8349 8352 8386 8400 8433 8448 8588 8592 9258
     9280 9291 9312 11124 11126 11508 11513 11558 11559 11560 11565 11566 11568 11624 11631
     11633 11647 11671 11680 11687 11688 11695 11696 11703 11704 11711 11712 11719 11720
     11727 11728 11735 11736 11743 11744 11870 11904 11930 11931 12020 12032 12246 12272
     12352 12353 12439 12441 12544 12549 12592 12593 12687 12688 12774 12783 12831 12832
     42125 42128 42183 42192 42540 42560 42744 42752 42973 42993 43053 43056 43066 43072
     43128 43136 43206 43214 43226 43232 43348 43359 43389 43392 43470 43471 43482 43486
     43519 43520 43575 43584 43598 43600 43610 43612 43715 43739 43767 43777 43783 43785
     43791 43793 43799 43808 43815 43816 43823 43824 43884 43888 44014 44016 44026 44032
     55204 55216 55239 55243 55292 57344 64110 64112 64218 64256 64263 64275 64280 64285
     64311 64312 64317 64318 64319 64320 64322 64323 64325 64326 64976 65008 65050 65056
     65107 65108 65127 65128 65132 65136 65141 65142 65277 65279 65280 65281 65471 65474
     65480 65482 65488 65490 65496 65498 65501 65504 65511 65512 65519 65529 65534 65536
     65548 65549 65575 65576 65595 65596 65598 65599 65614 65616 65630 65664 65787 65792
     65795 65799 65844 65847 65935 65936 65949 65952 65953 66000 66046 66176 66205 66208
     66257 66272 66300 66304 66340 66349 66379 66384 66427 66432 66462 66463 66500 66504
     66518 66560 66718 66720 66730 66736 66772 66776 66812 66816 66856 66864 66916 66927
     66939 66940 66955 66956 66963 66964 66966 66967 66978 66979 66994 66995 67002 67003
     67005 67008 67060 67072 67383 67392 67414 67424 67432 67456 67462 67463 67505 67506
     67515 67584 67590 67592 67593 67594 67638 67639 67641 67644 67645 67647 67670 67671
     67743 67751 67760 67808 67827 67828 67830 67835 67868 67871 67898 67903 67930 67968
     68024 68028 68048 68050 68100 68101 68103 68108 68116 68117 68120 68121 68150 68152
     68155 68159 68169 68176 68185 68192 68256 68288 68327 68331 68343 68352 68406 68409
     68438 68440 68467 68472 68498 68505 68509 68521 68528 68608 68681 68736 68787 68800
     68851 68858 68904 68912 68922 68928 68966 68969 68998 69006 69008 69216 69247 69248
     69290 69291 69294 69296 69298 69314 69320 69328 69337 69370 69416 69424 69466 69488
     69514 69552 69580 69600 69623 69632 69710 69714 69750 69759 69827 69837 69838 69840
     69865 69872 69882 69888 69941 69942 69960 69968 70007 70016 70112 70113 70133 70144
     70162 70163 70210 70272 70279 70280 70281 70282 70286 70287 70302 70303 70314 70320
     70379 70384 70394 70400 70404 70405 70413 70415 70417 70419 70441 70442 70449 70450
     70452 70453 70458 70459 70469 70471 70473 70475 70478 70480 70481 70487 70488 70493
     70500 70502 70509 70512 70517 70528 70538 70539 70540 70542 70543 70544 70582 70583
     70593 70594 70595 70597 70598 70599 70603 70604 70614 70615 70617 70625 70627 70656
     70748 70749 70754 70784 70856 70864 70874 71040 71094 71096 71134 71168 71237 71248
     71258 71264 71277 71296 71354 71360 71370 71376 71396 71424 71451 71453 71468 71472
     71495 71680 71740 71840 71923 71935 71943 71945 71946 71948 71956 71957 71959 71960
     71990 71991 71993 71995 72007 72016 72026 72096 72104 72106 72152 72154 72165 72192
     72264 72272 72355 72368 72441 72448 72458 72544 72552 72640 72674 72688 72698 72704
     72713 72714 72759 72760 72774 72784 72813 72816 72848 72850 72872 72873 72887 72960
     72967 72968 72970 72971 73015 73018 73019 73020 73022 73023 73032 73040 73050 73056
     73062 73063 73065 73066 73103 73104 73106 73107 73113 73120 73130 73136 73180 73184
     73194 73440 73465 73472 73489 73490 73531 73534 73563 73648 73649 73664 73714 73727
     74650 74752 74863 74864 74869 74880 75076 77712 77811 77824 78934 78944 82939 82944
     83527 90368 90426 92160 92729 92736 92767 92768 92778 92782 92863 92864 92874 92880
     92910 92912 92918 92928 92998 93008 93018 93019 93026 93027 93048 93053 93072 93504
     93562 93760 93851 93856 93881 93883 93908 93952 94027 94031 94088 94095 94112 94176
     94181 94192 94199 94208 101590 101631 101663 101760 101875 110576 110580 110581 110588
     110589 110591 110592 110883 110898 110899 110928 110931 110933 110934 110948 110952
     110960 111356 113664 113771 113776 113789 113792 113801 113808 113818 113820 113828
     117760 118013 118016 118452 118458 118481 118496 118513 118528 118574 118576 118599
     118608 118724 118784 119030 119040 119079 119081 119275 119296 119366 119488 119508
     119520 119540 119552 119639 119648 119673 119808 119893 119894 119965 119966 119968
     119970 119971 119973 119975 119977 119981 119982 119994 119995 119996 119997 120004
     120005 120070 120071 120075 120077 120085 120086 120093 120094 120122 120123 120127
     120128 120133 120134 120135 120138 120145 120146 120486 120488 120780 120782 121484
     121499 121504 121505 121520 122624 122655 122661 122667 122880 122887 122888 122905
     122907 122914 122915 122917 122918 122923 122928 122990 123023 123024 123136 123181
     123184 123198 123200 123210 123214 123216 123536 123567 123584 123642 123647 123648
     124112 124154 124368 124411 124415 124416 124608 124639 124640 124662 124670 124672
     124896 124903 124904 124908 124909 124911 124912 124927 124928 125125 125127 125143
     125184 125260 125264 125274 125278 125280 126065 126133 126209 126270 126464 126468
     126469 126496 126497 126499 126500 126501 126503 126504 126505 126515 126516 126520
     126521 126522 126523 126524 126530 126531 126535 126536 126537 126538 126539 126540
     126541 126544 126545 126547 126548 126549 126551 126552 126553 126554 126555 126556
     126557 126558 126559 126560 126561 126563 126564 126565 126567 126571 126572 126579
     126580 126584 126585 126589 126590 126591 126592 126602 126603 126620 126625 126628
     126629 126634 126635 126652 126704 126706 126976 127020 127024 127124 127136 127151
     127153 127168 127169 127184 127185 127222 127232 127406 127462 127491 127504 127548
     127552 127561 127568 127570 127584 127590 127744 128729 128732 128749 128752 128765
     128768 128986 128992 129004 129008 129009 129024 129036 129040 129096 129104 129114
     129120 129160 129168 129198 129200 129212 129216 129218 129232 129241 129280 129624
     129632 129646 129648 129661 129664 129675 129678 129735 129736 129737 129741 129757
     129759 129771 129775 129785 129792 129939 129940 130043 131072 173792 173824 178206
     178208 183982 183984 191457 191472 192094 194560 195102 196608 201547 201552 210042
     917505 917506 917536 917632 917760 918000 983040 1048574 1048576 1114110)
   cpspace
   @(9 14 32 33 5760 5761 8192 8199 8200 8203 8232 8234 8287 8288 12288 12289)
   cpblank
   @(9 10 32 33 5760 5761 8192 8199 8200 8203 8287 8288 12288 12289)
   cpcntrl
   @(0 32 127 160 8232 8234)
   cptou
   @(97 26 1 -32 181 1 1 743 224 23 1 -32 248 7 1 -32 255 1 1 121 257 24 2 -1 305 1 1 -232
     307 3 2 -1 314 8 2 -1 331 23 2 -1 378 3 2 -1 383 1 1 -300 384 1 1 195 387 2 2 -1 392 1 1
     -1 396 1 1 -1 402 1 1 -1 405 1 1 97 409 1 1 -1 410 1 1 163 411 1 1 42561 414 1 1 130 417
     3 2 -1 424 1 1 -1 429 1 1 -1 432 1 1 -1 436 2 2 -1 441 1 1 -1 445 1 1 -1 447 1 1 56 453
     1 1 -1 454 1 1 -2 456 1 1 -1 457 1 1 -2 459 1 1 -1 460 1 1 -2 462 8 2 -1 477 1 1 -79 479
     9 2 -1 498 1 1 -1 499 1 1 -2 501 1 1 -1 505 20 2 -1 547 9 2 -1 572 1 1 -1 575 2 1 10815
     578 1 1 -1 583 5 2 -1 592 1 1 10783 593 1 1 10780 594 1 1 10782 595 1 1 -210 596 1 1
     -206 598 2 1 -205 601 1 1 -202 603 1 1 -203 604 1 1 42319 608 1 1 -205 609 1 1 42315 611
     1 1 -207 612 1 1 42343 613 1 1 42280 614 1 1 42308 616 1 1 -209 617 1 1 -211 618 1 1
     42308 619 1 1 10743 620 1 1 42305 623 1 1 -211 625 1 1 10749 626 1 1 -213 629 1 1 -214
     637 1 1 10727 640 1 1 -218 642 1 1 42307 643 1 1 -218 647 1 1 42282 648 1 1 -218 649 1 1
     -69 650 2 1 -217 652 1 1 -71 658 1 1 -219 669 1 1 42261 670 1 1 42258 837 1 1 84 881 2 2
     -1 887 1 1 -1 891 3 1 130 940 1 1 -38 941 3 1 -37 945 17 1 -32 962 1 1 -31 963 9 1 -32
     972 1 1 -64 973 2 1 -63 976 1 1 -62 977 1 1 -57 981 1 1 -47 982 1 1 -54 983 1 1 -8 985
     12 2 -1 1008 1 1 -86 1009 1 1 -80 1010 1 1 7 1011 1 1 -116 1013 1 1 -96 1016 1 1 -1 1019
     1 1 -1 1072 32 1 -32 1104 16 1 -80 1121 17 2 -1 1163 27 2 -1 1218 7 2 -1 1231 1 1 -15
     1233 48 2 -1 1377 38 1 -48 4304 43 1 3008 4349 3 1 3008 5112 6 1 -8 7296 1 1 -6254 7297
     1 1 -6253 7298 1 1 -6244 7299 2 1 -6242 7301 1 1 -6243 7302 1 1 -6236 7303 1 1 -6181
     7304 1 1 35266 7306 1 1 -1 7545 1 1 35332 7549 1 1 3814 7566 1 1 35384 7681 75 2 -1 7835
     1 1 -59 7841 48 2 -1 7936 8 1 8 7952 6 1 8 7968 8 1 8 7984 8 1 8 8000 6 1 8 8017 4 2 8
     8032 8 1 8 8048 2 1 74 8050 4 1 86 8054 2 1 100 8056 2 1 128 8058 2 1 112 8060 2 1 126
     8064 8 1 8 8080 8 1 8 8096 8 1 8 8112 2 1 8 8115 1 1 9 8126 1 1 -7205 8131 1 1 9 8144 2
     1 8 8160 2 1 8 8165 1 1 7 8179 1 1 9 8526 1 1 -28 8560 16 1 -16 8580 1 1 -1 9424 26 1
     -26 11312 48 1 -48 11361 1 1 -1 11365 1 1 -10795 11366 1 1 -10792 11368 3 2 -1 11379 1 1
     -1 11382 1 1 -1 11393 50 2 -1 11500 2 2 -1 11507 1 1 -1 11520 38 1 -7264 11559 1 1 -7264
     11565 1 1 -7264 42561 23 2 -1 42625 14 2 -1 42787 7 2 -1 42803 31 2 -1 42874 2 2 -1
     42879 5 2 -1 42892 1 1 -1 42897 2 2 -1 42900 1 1 48 42903 10 2 -1 42933 8 2 -1 42952 2 2
     -1 42957 8 2 -1 42998 1 1 -1 43859 1 1 -928 43888 80 1 -38864 65345 26 1 -32 66600 40 1
     -40 66776 36 1 -40 66967 11 1 -39 66979 15 1 -39 66995 7 1 -39 67003 2 1 -39 68800 51 1
     -64 68976 22 1 -32 71872 32 1 -32 93792 32 1 -32 93883 25 1 -27 125218 34 1 -34)
   cptol
   @(65 26 1 32 192 23 1 32 216 7 1 32 256 24 2 1 304 1 1 -199 306 3 2 1 313 8 2 1 330 23 2 1
     376 1 1 -121 377 3 2 1 385 1 1 210 386 2 2 1 390 1 1 206 391 1 1 1 393 2 1 205 395 1 1 1
     398 1 1 79 399 1 1 202 400 1 1 203 401 1 1 1 403 1 1 205 404 1 1 207 406 1 1 211 407 1 1
     209 408 1 1 1 412 1 1 211 413 1 1 213 415 1 1 214 416 3 2 1 422 1 1 218 423 1 1 1 425 1
     1 218 428 1 1 1 430 1 1 218 431 1 1 1 433 2 1 217 435 2 2 1 439 1 1 219 440 1 1 1 444 1
     1 1 452 1 1 2 453 1 1 1 455 1 1 2 456 1 1 1 458 1 1 2 459 9 2 1 478 9 2 1 497 1 1 2 498
     2 2 1 502 1 1 -97 503 1 1 -56 504 20 2 1 544 1 1 -130 546 9 2 1 570 1 1 10795 571 1 1 1
     573 1 1 -163 574 1 1 10792 577 1 1 1 579 1 1 -195 580 1 1 69 581 1 1 71 582 5 2 1 880 2
     2 1 886 1 1 1 895 1 1 116 902 1 1 38 904 3 1 37 908 1 1 64 910 2 1 63 913 17 1 32 931 9
     1 32 975 1 1 8 984 12 2 1 1012 1 1 -60 1015 1 1 1 1017 1 1 -7 1018 1 1 1 1021 3 1 -130
     1024 16 1 80 1040 32 1 32 1120 17 2 1 1162 27 2 1 1216 1 1 15 1217 7 2 1 1232 48 2 1
     1329 38 1 48 4256 38 1 7264 4295 1 1 7264 4301 1 1 7264 5024 80 1 38864 5104 6 1 8 7305
     1 1 1 7312 43 1 -3008 7357 3 1 -3008 7680 75 2 1 7838 1 1 -7615 7840 48 2 1 7944 8 1 -8
     7960 6 1 -8 7976 8 1 -8 7992 8 1 -8 8008 6 1 -8 8025 4 2 -8 8040 8 1 -8 8072 8 1 -8 8088
     8 1 -8 8104 8 1 -8 8120 2 1 -8 8122 2 1 -74 8124 1 1 -9 8136 4 1 -86 8140 1 1 -9 8152 2
     1 -8 8154 2 1 -100 8168 2 1 -8 8170 2 1 -112 8172 1 1 -7 8184 2 1 -128 8186 2 1 -126
     8188 1 1 -9 8486 1 1 -7517 8490 1 1 -8383 8491 1 1 -8262 8498 1 1 28 8544 16 1 16 8579 1
     1 1 9398 26 1 26 11264 48 1 48 11360 1 1 1 11362 1 1 -10743 11363 1 1 -3814 11364 1 1
     -10727 11367 3 2 1 11373 1 1 -10780 11374 1 1 -10749 11375 1 1 -10783 11376 1 1 -10782
     11378 1 1 1 11381 1 1 1 11390 2 1 -10815 11392 50 2 1 11499 2 2 1 11506 1 1 1 42560 23 2
     1 42624 14 2 1 42786 7 2 1 42802 31 2 1 42873 2 2 1 42877 1 1 -35332 42878 5 2 1 42891 1
     1 1 42893 1 1 -42280 42896 2 2 1 42902 10 2 1 42922 1 1 -42308 42923 1 1 -42319 42924 1
     1 -42315 42925 1 1 -42305 42926 1 1 -42308 42928 1 1 -42258 42929 1 1 -42282 42930 1 1
     -42261 42931 1 1 928 42932 8 2 1 42948 1 1 -48 42949 1 1 -42307 42950 1 1 -35384 42951 2
     2 1 42955 1 1 -42343 42956 8 2 1 42972 1 1 -42561 42997 1 1 1 65313 26 1 32 66560 40 1
     40 66736 36 1 40 66928 11 1 39 66940 15 1 39 66956 7 1 39 66964 2 1 39 68736 51 1 64
     68944 22 1 32 71840 32 1 32 93760 32 1 32 93856 25 1 27 125184 34 1 34)
   ; tools/mkemoji.l's, unicode 17, runs as the classes': the characters VS16 gives an emoji
   ; style, and the Extended_Pictographic ones
   cpvs
   @(35 36 42 43 48 58 169 170 174 175 8252 8253 8265 8266 8482 8483 8505 8506 8596 8602 8617
     8619 8986 8988 9000 9001 9167 9168 9193 9204 9208 9211 9410 9411 9642 9644 9654 9655
     9664 9665 9723 9727 9728 9733 9742 9743 9745 9746 9748 9750 9752 9753 9757 9758 9760
     9761 9762 9764 9766 9767 9770 9771 9774 9776 9784 9787 9792 9793 9794 9795 9800 9812
     9823 9825 9827 9828 9829 9831 9832 9833 9851 9852 9854 9856 9874 9880 9881 9882 9883
     9885 9888 9890 9895 9896 9898 9900 9904 9906 9917 9919 9924 9926 9928 9929 9934 9936
     9937 9938 9939 9941 9961 9963 9968 9974 9975 9979 9981 9982 9986 9987 9989 9990 9992
     9998 9999 10000 10002 10003 10004 10005 10006 10007 10013 10014 10017 10018 10024 10025
     10035 10037 10052 10053 10055 10056 10060 10061 10062 10063 10067 10070 10071 10072
     10083 10085 10133 10136 10145 10146 10160 10161 10175 10176 10548 10550 11013 11016
     11035 11037 11088 11089 11093 11094 12336 12337 12349 12350 12951 12952 12953 12954
     126980 126981 127344 127346 127358 127360 127490 127491 127514 127515 127535 127536
     127543 127544 127757 127760 127765 127766 127772 127773 127777 127778 127780 127789
     127798 127799 127864 127865 127869 127870 127891 127892 127894 127896 127897 127900
     127902 127904 127911 127912 127916 127919 127938 127939 127940 127941 127942 127943
     127946 127951 127956 127969 127981 127982 127987 127988 127989 127990 127991 127992
     128008 128009 128021 128022 128031 128032 128038 128039 128063 128064 128065 128067
     128070 128074 128077 128079 128083 128084 128106 128107 128125 128126 128163 128164
     128176 128177 128179 128180 128187 128188 128191 128192 128203 128204 128218 128219
     128223 128224 128228 128231 128234 128238 128247 128248 128249 128252 128253 128254
     128264 128265 128269 128270 128274 128276 128329 128331 128336 128360 128367 128369
     128371 128378 128391 128392 128394 128398 128400 128401 128421 128422 128424 128425
     128433 128435 128444 128445 128450 128453 128465 128468 128476 128479 128481 128482
     128483 128484 128488 128489 128495 128496 128499 128500 128506 128507 128528 128529
     128647 128648 128653 128654 128657 128658 128660 128661 128664 128665 128685 128686
     128690 128691 128697 128699 128700 128701 128715 128716 128717 128720 128736 128742
     128745 128746 128752 128753 128755 128756)
   cpxp
   @(169 170 174 175 8252 8253 8265 8266 8482 8483 8505 8506 8596 8602 8617 8619 8986 8988
     9000 9001 9167 9168 9193 9204 9208 9211 9410 9411 9642 9644 9654 9655 9664 9665 9723
     9727 9728 9733 9742 9743 9745 9746 9748 9750 9752 9753 9757 9758 9760 9761 9762 9764
     9766 9767 9770 9771 9774 9776 9784 9787 9792 9793 9794 9795 9800 9812 9823 9825 9827
     9828 9829 9831 9832 9833 9851 9852 9854 9856 9874 9880 9881 9882 9883 9885 9888 9890
     9895 9896 9898 9900 9904 9906 9917 9919 9924 9926 9928 9929 9934 9936 9937 9938 9939
     9941 9961 9963 9968 9974 9975 9979 9981 9982 9986 9987 9989 9990 9992 9998 9999 10000
     10002 10003 10004 10005 10006 10007 10013 10014 10017 10018 10024 10025 10035 10037
     10052 10053 10055 10056 10060 10061 10062 10063 10067 10070 10071 10072 10083 10085
     10133 10136 10145 10146 10160 10161 10175 10176 10548 10550 11013 11016 11035 11037
     11088 11089 11093 11094 12336 12337 12349 12350 12951 12952 12953 12954 126980 126981
     127020 127024 127124 127136 127151 127153 127168 127169 127183 127185 127222 127232
     127344 127346 127358 127360 127374 127375 127377 127387 127406 127462 127489 127504
     127514 127515 127535 127536 127538 127547 127548 127552 127561 127584 127590 127778
     127780 127892 127894 127896 127897 127900 127902 127985 127987 127990 127991 127995
     128000 128254 128255 128318 128329 128335 128336 128360 128367 128369 128371 128379
     128391 128392 128394 128398 128400 128401 128405 128407 128420 128422 128424 128425
     128433 128435 128444 128445 128450 128453 128465 128468 128476 128479 128481 128482
     128483 128484 128488 128489 128495 128496 128499 128500 128506 128592 128640 128710
     128715 128723 128725 128742 128745 128746 128747 128753 128755 128768 128986 129024
     129036 129040 129096 129104 129114 129120 129160 129168 129198 129200 129212 129216
     129218 129232 129241 129280 129292 129339 129340 129350 129351 129536 129624 129632
     129646 129792 130048 131070)
   (tl s k) (k < #s && (s k & 192) = 128)
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
       (go k a) (? (m <= k) a (go (k + 1) (a * 64 + (s (i + k) & 63))))
       (? (m = 0) 65533 (m = 1) (s i) (go 1 (s i & (127 >> m)))))
   (cps s) (: n #s (go i acc) (? (n <= i) (rev acc) (go (cpnext s i) (cpat s i . acc))) (go 0 ()))
   (cplen s) (: n #s (go i k) (? (n <= i) k (go (cpnext s i) (k + 1))) (go 0 0))
   (cpoff s i k) (: n #s (go i k) (? (n <= i || k < 1) i (go (cpnext s i) (k - 1))) (go i k))
   (cpsnip s a b) (: i (cpoff s 0 a) (snip s i (cpoff s i (b - a))))
   (cprev s)
    (: n #s o (jug 0)
       (go i acc) (? (n <= i) acc (go (cpnext s i) (i . acc)))
       (out j l) (? (atom? l) (slurp o) (say o (snip s <l j), out <l >l))
       (out n (go 0 ())))
   (wcwidth c)
    (? (c = 0) 0
       (c < 32 || 127 <= c < 160 || 1114111 < c) -1
       (c < 768) 1
       (: (go lo hi) (? (hi - lo < 2) (peep cpw lo 0 & 3)
                        (: m ((lo + hi) // 2) ((peep cpw m 0 >> 2) <= c ? (go m hi) (go lo m))))
          (go 0 #cpw)))
   (cpcols s i) (max 0 (wcwidth (cpat s i)))
   ; grapheme clusters as quay keeps them under ?2027: a character and what joins it -- a
   ; zero-width one, an emoji modifier after a pictograph, a pictograph after a ZWJ that ends
   ; one, a regional indicator after a lone one -- ten characters at most, zero-width ones past
   ; that dropped. a pictograph that took a join, or a narrow one VS16 gives an emoji style, is
   ; wide. [the byte after the cluster at i, its columns]
   (cpxp? c) (cpin cpxp c)
   (cpvs? c) (cpin cpvs c)
   (cpri? c) (127462 <= c <= 127487)
   (gcat s i)
    (: n #s b (cpat s i) xp (cpxp? b)
       (go j last k w)
        (: c (? (j < n) (cpat s j) 0) cw (wcwidth c)
           (on w) (go (cpnext s j) c (k + 1) w)
           (? (c = 0 || cw < 0) [j w]
              (cw = 0) (on (? (c = 65039 && w = 1 && cpvs? b) 2 w))
              (9 < k) [j w]
              (xp && 127995 <= c <= 127999) (on 2)
              (xp && last = 8205 && cpxp? c) (on 2)
              (k = 1 && cpri? b && cpri? c) (on 2)
              [j w]))
       (? (wcwidth b < 0) [(cpnext s i) 0] (go (cpnext s i) b 1 (wcwidth b))))
   (gcnext s i) <(gcat s i)
   (gcwidth s i) <>(gcat s i)
   (sgwidth s) (: n #s (go i a) (? (n <= i) a (: g (gcat s i) (go <g (a + <>g)))) (go 0 0))
   ; back over at most three tails; a byte that ends no whole character stands alone
   (cpback s i)
    (: (go j) (? (j < 1 || i - j > 2 || !(tl s j)) j (go (j - 1)))
       j (go (i - 1))
       (? (cpnext s j = i) j (i - 1)))
   (cpword? c) (c = 95 || cpis "alnum" c)
   ; is c inside one of a class tray's runs: an odd count of entries at or below it
   (cpin t c)
    (: (go lo hi) (? (hi <= lo) lo (: m ((lo + hi) // 2) (peep t m 0 <= c ? (go (m + 1) hi) (go lo m))))
       ((go 0 #t) % 2 = 1))
   ; c through a case map: the last run opening at or below c, if c is one of its steps
   (cpmap t c)
    (: (go lo hi) (? (hi - lo < 2) lo (: m ((lo + hi) // 2) (peep t (4 * m) 0 <= c ? (go m hi) (go lo m))))
       k (go 0 (#t // 4)) j (c - peep t (4 * k) 0) st (peep t (4 * k + 2) 0)
       (? (0 <= j && j % st = 0 && j // st < peep t (4 * k + 1) 0) (c + peep t (4 * k + 3) 0) c))
   (cpupper c) (? (c < 128) (97 <= c <= 122 ? (c - 32) c) (cpmap cptou c))
   (cplower c) (? (c < 128) (65 <= c <= 90 ? (c + 32) c) (cpmap cptol c))
   cpclasses ["alpha" "upper" "lower" "digit" "xdigit" "alnum" "punct" "graph" "print" "space"
              "blank" "cntrl"]
   (cpclass? nm) (elem nm cpclasses)
   (cpis nm c)
    (: dig (48 <= c <= 57)
       (nm @ "alpha" (cpin cpalpha c) "upper" (cpin cpupc c) "lower" (cpin cplowc c)
             "digit" dig "xdigit" (dig || 65 <= c <= 70 || 97 <= c <= 102)
             "alnum" (dig || cpin cpalpha c) "print" (cpin cpprint c)
             "graph" (cpin cpprint c && !(cpin cpspace c))
             "punct" (cpin cpprint c && !(cpin cpspace c) && !dig && !(cpin cpalpha c))
             "space" (cpin cpspace c) "blank" (cpin cpblank c) "cntrl" (cpin cpcntrl c)
             0))
   ; gnulib's case_folded_counterparts: c's uppercase, that one's lowercase if it comes back,
   ; and the lowercase letters with no way back, each only if it shares c's uppercase. not an
   ; equivalence: U+1C80 takes U+0412, which does not take it
   cplone [181 305 383 453 456 459 498 837 962 976 977 981 982 1008 1009 1010 1013 7835 8126]
   (cpfold c)
    (: uc (cpupper c) lc (cplower uc)
       (cat (? (uc != c) [uc] ())
            (cat (? (lc != uc && lc != c && cpupper lc = uc) [lc] ())
                 (filter (x \ x != lc && x != uc && x != c && cpupper x = uc) cplone))))
   ; only a character one of the maps moves, or a lonesome one, has any
   (cpfolds lo hi)
    (: (steps t) (catmap (k \ (: s (peep t (4 * k) 0) n (peep t (4 * k + 1) 0) st (peep t (4 * k + 2) 0)
                                 (? (hi < s || s + (n - 1) * st < lo) ()
                                    (filter (x \ lo <= x <= hi) (map (j \ s + j * st) (jot n))))))
                        (jot (#t // 4)))
       (catmap cpfold (cat (steps cptou) (cat (steps cptol) (filter (x \ lo <= x <= hi) cplone)))))
   (swidth s) (: n #s (go i w) (? (n <= i) w (go (cpnext s i) (w + cpcols s i))) (go 0 0))
   (scut s n)
    (: m #s
       (go i w) (? (m <= i) s (: v (w + cpcols s i) (n < v ? (snip s 0 i) (go (cpnext s i) v))))
       (go 0 0)))

) ; module text

; lush 🐚 the word -- a word back into a command line, and the mask law's other half. module
; 'lush begins here because two catted scripts carrying no apps/lush.l still need one: sb reads
; the ignore patterns, helm shows what a unit will run. what stands here has no substrate under
; it; everything that reads a directory or runs a process is apps/lush.l's.
; the pair is a retraction, not a bijection: (sh-read (sh-show ws)) = ws for every ws, while
; (sh-show (sh-read s)) is a canonical s. test/host/sh.l checks the two against each other.
;   (sh-quote w)  -> the word as a shell reads it back: bare where it can be, in '..'
;                    where it cannot. a word holding a newline keeps it.
;   (sh-show ws)  -> the words as one line. the head of a line is where a keyword reads
;                    as syntax, so it takes quotes there and nowhere else.

(module 'lush
(: ; the bare set: bytes no shell reads as anything but themselves, in any position and under
   ; every expansion. everything over 127 is out as well -- a locale may letter them.
   (sh-tame? c) (97 <= c <= 122 || 65 <= c <= 90 || 48 <= c <= 57 || elem c "_-.,:/@+%=")
   ; two shapes whose bytes are tame and whose reading is not: NAME=VAL is an assignment in
   ; command position, and a leading = is zsh's command-path lookup. both cost a pair of quotes.
   (sh-namec? c i) (97 <= c <= 122 || 65 <= c <= 90 || c = 95 || 0 < i && 48 <= c <= 57)
   (sh-plain? w)
    (: n #w
       (go i) (? (n <= i) 1 (w i = 61) 0 (sh-namec? (w i) i) (go (i + 1)) 1)
       (go 0))
   ; '..' holds every byte but ' itself, so that one leaves and comes back: a'b
   ; quotes as 'a'\''b' -- three adjacent words to a reader, one to the shell
   (sh-sqesc w) (cats (map (c \ c = 39 ? "'\\''" (string c)) (chars w)))
   (sh-quote w) (? !#w "''"
                   (all sh-tame? (chars w) && sh-plain? w) w
                   ("'" + sh-sqesc w + "'"))
   ; the one thing a word cannot judge alone: a keyword bare in command position is syntax and
   ; not a command name. only the line knows, and a later word pays nothing -- `grep -w in f`.
   sh-kw '("if" "then" "else" "elif" "fi" "do" "done" "case" "esac"
           "while" "until" "for" "in" "function" "select" "time")
   (sh-qhead w)  (elem w sh-kw ? ("'" + w + "'") (sh-quote w))
   (sh-qrest ws) ((atom? ws) ? "" (" " + sh-quote <ws + sh-qrest >ws))
   (sh-show ws)  ((atom? ws) ? "" (sh-qhead <ws + sh-qrest >ws)))

) ; module lush -- apps/lush.l carries the rest

; kanren -- first-order unification + a lazy-colist search monad. a post-egg layer: prel stays
; the language, this registers as a module. overlay below reads unify/ufail?/var from here and
; reaches the rest through the registry, so this must be evaled and registered before overlay.
; `unify s u v` is pure -- a substitution or `ufail` -- with no occurs check: love's values are
; non-well-founded, so a self-referential binding is a rational tree and walk_star mu-marks a
; back-edge to reify it without looping. a goal is (\ st stream) over a state (substitution .
; constraints); est/=== unify, + interleaves, * binds. a boot says (borrow 'kanren) to splice
; the bare names; internals -- subst, walk, query, the dict kit -- answer to (cite 'kanren ..).
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
   (walk s u) (? !(var? u) u (: t (has_s s u) (? (two? t) (walk s <t) u)))
   ufail (nom 0)
   (ufail? x) (x = ufail)
   ; a binder, and the whole nominal half: the abstraction is a love lambda, so alpha-equivalence
   ; is the language's and instantiation is application -- nothing to swap, rename, or capture.
   (tie f) ('tie . f)
   (tie? t) (? (two? t) (<t = 'tie) 0)
   (untie t a) (>t a)                            ; open the binder at a
   (unify s u v) (: x (walk s u) y (walk s v)       ; pure: a substitution, or ufail
     (? (x = y) s                                   ; alpha-equal binders land here, for free
        (var? x) (ext_s s x y)
        (var? y) (ext_s s y x)
        (tie? x && tie? y) (: a (nom 0) (unify s (untie x a) (untie y a)))   ; one fresh nom opens both
        (two? x && two? y) (: s1 (unify s <x <y) (? (ufail? s1) ufail (unify s1 >x >y)))
        ufail))
   (subst s t) (? (var? t) (: w (walk s t) (? (var? w) w (subst s w)))   ; instantiate a template under s
                  (tie? t) (tie (a \ (subst s (untie t a))))             ; under a binder: at its opening
                  (two? t) (subst s <t . subst s >t)
                  t)
   (rewrite pat tpl x) (: r (unify '(()) pat x) (? (ufail? r) x (subst r tpl)))   ; pattern -> template, or x unchanged

   ; --- the constraint store -------------------------------------------------
   ; the store rides beside `unify`, which keeps its signature and its purity. a constraint is
   ; (kind . payload), re-verified against the whole store after every successful unification.
   st0 (empty_dict . ())
   (unify_all s p) (? (two? p) (: r (unify s <<p ><p) (? (ufail? r) ufail (unify_all r >p))) s)
   ; the bindings r has and s does not, as a (u . v) list -- ext_s prepends, so they lead
   (residual r s) (: (go k ks vs acc) (? k (go (k - 1) >ks >vs ((<ks . <vs) . acc)) acc)
                     (go (#<r - #<s) <r >r ()))
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

   ; --- streams: a colist, love's lazy list (love/boot/p1.l's shape) --------------
   ; () is empty, (x . s) is mature, a thunk is immature -- three shapes told apart by lit?/two?.
   ; the church encoding this replaced cost 26-35% more instructions on every shape measured.
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
   ; conj2/disj2 are the whole of the goal algebra: &&& and ||| expand to them, and the ring's
   ; * and + are them under the coin. `load` at construction is what lets either spelling take
   ; either operand, a bare goal or a rel-wrapped one.
   (conj2 a b) (: g (load a) h (load b) (st \ (s_star (g st) h)))
   (disj2 a b) (: g (load a) h (load b) (st \ (s_plus (g st) (h st))))
   yea sun                               ; the goal that holds, once
   nay ()                                ; the goal that never does
   (est u v st) (: r (unify <st u v)
                   (ufail? r ? ()
                    (: c (vet r >st) (? (ufail? c) () (sun (r . c))))))
   ; unify on a copy, three outcomes: ufail means the two can never be equal and there is
   ; nothing to remember, no new binding means they are equal and the goal fails, anything
   ; else keeps the residual bindings as the constraint.
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
   ; --- the extra-logical three. `ifte` is the soft cut: if c holds at all, t runs over every
   ; answer of c and e is dropped. `sole` commits to the first answer. `naf` is negation as
   ; failure -- "not proved", never "false", the two one only for a ground terminating goal.
   (ifte c t e st) (: m (sfire (c st)) (? (two? m) (s_star m t) (e st)))
   (sole g st) (: m (sfire (g st)) (? (two? m) (sun <m) ()))
   (naf g st) (ifte g nay yea st)

   ; --- query: run a goal, reify the answers ---------------------------------
   (query n ks g) (:
    (walk_star s u path) (?                          ; cycle-safe: (mu label) on a back-edge
     (var? u) (: t (has_s s u)
                 (? (atom? t) u
                    (elem u path) ['mu <u]
                    (walk_star s <t (u . path))))
     (tie? u) (: a (nom 0) ['tie a (walk_star s (untie u a) path)])
     (two? u) (walk_star s <u path . walk_star s >u  path)
     u)
    ; the noms an answer carries -- a tie's binder, an atom a relation minted -- are
    ; renamed a1 a2 .. in first-sight order, so an answer reads back and compares.
    (noms t acc) (? (var? t) acc
                    (mint? t) (elem t acc ? acc (t . acc))
                    (two? t) (noms >t (noms <t acc))
                    acc)
    (renom d t) (? (var? t) t
                   (mint? t) (: v (dict_has d t) (? (two? v) <v t))
                   (two? t) (renom d <t . renom d >t)
                   t)
    (dename t) (: ns (rev (noms t ()))
                  (? (two? ns)
                     (renom (foldl (d \ p \ dict_set d <p <>p) empty_dict
                                   (zip ns (map (i \ nom $ "a" + show (i + 1)) ^#ns)))
                            t)
                     t))
    (keyvar keys k) (? (atom? keys) 0 (: kv <keys (? (k = <kv) kv (keyvar >keys k))))
    (reify1 st) (dename (flip catmap ks (k \ (: kv (keyvar <<st k) (? (two? kv) [k (walk_star <st kv ())])))))
    (map reify1 ((? n (stake n) slist) (g st0))))
   rel (coin 'goal (z \ {'+ (\ A B (z (disj2 A B)))   ; the goal coin: + = disj = |||, * = conj = &&&
                         '* (\ A B (z (conj2 A B)))})))
(: (=== u v) (rel (est u v))                        ; the relation's infix unify -- it needs no row
   (=/= u v) (rel (dif u v)))                       ; in prel's `operators`, which holds only the
; exceptions, and any all-punct head is already infix-dyadic at house band. =/= shares a band
; with ===, so a chain folds by hand and wants parens.
; the goal language: `::` writes the head layer's macro table, so these four live in kanren's own
; book and a consumer's (borrow 'kanren) splice carries them -- stacklook_macro walks the chain's
; macro slots, so the expansions and the names they emit resolve down the same splice.
; the tripled spellings: === is =, =/= its negation, &&& and ||| are && and ||, \\\ is \ with
; its params minted fresh as logic vars. all-punct, so all of them are infix at house band.
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
             (atom? e) (dom 'litdie e)
             (: h <e as (map (ov-kindof dom sigs env) >e)
                (? (elem h '(+ *)) (dom 'tr h <as <>as)
                   (h = '? && #e = 4) (dom 'join <>as <>>as)
                   (: sg (ov-sigof sigs h) (atom? sg ? 'top (ov2-inst dom sg as))))))
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
     (: v (ov-slot 0) (two? v ? (ov-eng <v <>v e, e0 e) (e0 e))))
) ; module overlay

; uu -- the uu kernel's home: MLTT with the UniMath Preamble's seven inductives (empty unit
; bool coprod nat paths total2), bidirectional checking, NbE conversion (de bruijn levels as
; fresh vars, sigma- and pi-eta), type-in-type -- the reference's own universe stance
; (UniMath/Foundations/Init.v: Unset Universe Checking). an axiom is a book entry with a type
; and no value: a sanctioned missing. names follow UniMath so the port reads literally.
;
; terms are quoted lists: UU nat bool unit empty zero tt true false <fixnum>
;   (pi x A B) (lam x b) (total2 x A B) (tpair a b) (pr1 w) (pr2 w) (succ n)
;   (coprod A B) (ii1 a) (ii2 b) (paths a a b) (idpath a) (the T t)
;   (nat_rect P z s n) (bool_rect P t f b) (unit_rect P u x)
;   (coprod_rect P f g v) (empty_rect P e) (paths_rect P pr e)
;   (let x a b) -- definitional: x binds the value of a, transparent to conv
; and any other list is an application spine. (f) == f here too.
;
; a module on every corpus target (host + love0 + the inle kernel + wasm): the frontend lists
; this source in its ai_libs table and its boot says (borrow 'uu), then rebinds `uu` to the
; accessor -- (: uu (cite 'uu)) -- so the surface stays (uu 'vof), (uu 'defn), (uu 'chk),
; (uu 'lof), every internal a probe away. the UniMath theorem corpus rides in test/uu.l and
; the test/uu*.l ladder over it; the defn/defq/axm macros land in this layer's macro slot.

; --- the kernel: values, evaluation, conversion, checking ---
; the surface: what `cite`/`borrow` see. everything else is internal, a probe away.
(module '(uu axm bridge capp chk conv defn defq GLOB HELPC lof rejects vof)
(: GLOB {} HELPC {} SRC {} CMEM {} BRIDGE {})

(: (vsucc v) (charm? v ? (v + 1) ['succ v])

   ; a uu closure carries a love function, so applying one is an application and not a re-walk
   ; of the body's syntax. ('clo f) is opaque above this line: conv reaches a closure only
   ; through capp, and lof prints terms.
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
   ; the head dispatch, the destructuring and the arity all happen here, once per term rather
   ; than once per evaluation; a lam's body becomes a love closure, so capp is an application.
   ; vof-sym stays dynamic: it reads glob, and a defn later in the corpus must be visible to a
   ; term compiled earlier, so the lookup rides the `(\ en ..)` and never the compile.
   ; the arms are ordered by measured frequency -- lam and succ are half the corpus's head
   ; dispatches -- and the tests are mutually exclusive symbols, so the order is free.
   (comp t)
   (? (charm? t) (en \ t)
      (nom? t) (? (memq t '(UU nat bool unit empty tt true false)) (en \ t)
                  (t = 'zero) (en \ 0)
                  (en \ vof-sym en t))
      ; a pattern is the term grammar, so this dispatch reads like the header's list of shapes.
      ; a spine needs no fast path: a list head is never == to a tag, so it falls through
      ; every arm to the else on its own.
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

   ; a `?` and not a pattern: an arm reads both sides, and a pattern would build the [a b] per
   ; call. `==` is the one use outside the egg, and `=` cannot stand in -- on two different
   ; terms it walks their closures, and the shared environments make that exponential. the
   ; atom arm is a guard: reaching it means unequal, and it keeps `<a` off a non-list.
   (conv d a b)
   (? (a == b) 1
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

   ; the else is the spine and needs no head test: a list head is never == to a tag, and a tag
   ; at the wrong length reaches it too, coming back unbound rather than reading () for operands.
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
   ; the Qed driver: checked like defn, then sealed -- pinned with its own neutral as value, so
   ; applying the proof never evaluates it. strict NbE would else build its beta-normal form.
   (defq nm T t)
   (: Tv (chk 0 0 0 T 'UU,
          vof 0 T)
    (chk 0 0 0 t Tv,
     pin GLOB nm [Tv ['nv nm]],
     nm))
   (rejects th)
   (: r (call-cc (k \ (pin HELPC () (\ a b (k 'rejected)), th 0, 'accepted)))
    (pin HELPC () 0, r)))

; --- uu2l: the uu-to-l leg. a closed term compiles to a love form whose value is vof's
; --- answer (charms for nats, ('chain a b) for pairs), at compiled-love speed; lof
; --- evaluates one. untrusted by design: chk/conv never touch it, so a uu2l bug can miss a
; --- demo and never fake a theorem, and the corpus asserts (vof t = lof t) wherever both
; --- lanes are tractable. generated code has no free names -- the runtime kit and every
; --- global embed as live literals under the quote sigil, so nothing a uu binder spells can
; --- capture. bridge maps standard names to native love. defn feeds src; a defq or axm name
; --- compiles to its own neutral, exactly the sealed book value.
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

; --- the arity door. defn/defq/axm are fully curried, so a paren slip handing one too few
; --- operands is not an error: it is a truthy closure one curry away from running, an assert
; --- paints it green, and nothing pins. too many operands feed the returned nom and vanish
; --- the same way. the macros guard call position -- the right count, or the form scares
; --- carrying itself -- and expand heading (1 defn), the identity's head being no macro so
; --- nothing re-expands. the functions keep their names, so the baked book still serves them.
(: q (map qlit)
 (:: 'defn (l \ l @ [_ _ _] (defn . q l) (scare 'uu-defn-arity l)),
  :: 'defq (l \ l @ [_ _ _] (defq . q l) (scare 'uu-defq-arity l)),
  :: 'axm  (l \ l @ [_ _]   (axm  . q l) (scare 'uu-axm-arity  l))))

) ; module uu

; peg -- gw.js-style parser combinators. a parser is (\ s y n) over a state s, with a success
; continuation y = (\ rest payload) and a failure continuation n = (\ rest); payloads are lists
; `seq` concatenates. a state is (text . i), the input and how far in: a step moves i, and the
; rest is never copied. `parse` and `runp` make the first one from a string; a hand-written
; leaf reads <s and >s and answers (<s . k).
; the leaves are `lit` (a literal prefix), `one` (one char by predicate) and
; `span` (a maximal run) -- love has no regex. `parse` requires the whole input consumed, `runp`
; keeps the payload and ignores trailing slack. an empty payload is the unit, never the 0
; nil-tail: `cat` propagates whatever tail it is handed, and `=` tells the two apart.
; a module the boot never splices -- each consumer opens with its own top-level (borrow 'peg),
; which must be its own top-level form: a `:` body compiles as one unit, so a borrow nested
; inside the form that reads the names runs too late to serve it.

(module 'peg
(: (eps s y n) (y s ())
   (lit l s y n) (: t <s i >s k (i + #l)
                  (? (k <= #t && l = snip t i k) (y (t . k) [l]) (n s)))
   ; the payload element is a one-char string, not the charm: every element a peg
   ; parser yields is then a string fragment, so a consumer's join is pure concat.
   ; the predicate still sees the charm.
   (one p s y n) (: t <s i >s
                  (? (i < #t && p (t i)) (y (t . (i + 1)) [(snip t i (i + 1))]) (n s)))
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
   ; --- the set the consumers kept re-deriving ---------------------------------
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

; re -- the POSIX regex engine, BRE and ERE. love has no regex syntax, so this is the door:
; (rebre p) / (reere p) compile a pattern, (rehas ns s) and (refind ns s i) run it. pure --
; no i/o, no seat -- and peg's peer: a module the boot never splices, so each consumer opens
; with its own top-level (borrow 're); grep reads four names off that splice, in apps/kore/re.l.
; lawed in test/law/kore.l: hand laws plus a seeded differential fuzz against an independent
; Brzozowski-derivative oracle, and grep is smoked byte-identical against GNU in test_kore.
;
; two dialects, one parser: BRE and ERE differ only in which sigils wear a backslash, so
; `reparse` takes the dialect as a flag and `esc?` is the whole seam -- ( ) | { } + ? are bare
; in ERE and \-escaped in BRE, while * . [ ^ $ are bare in both.
; the surface: literals, `.`, `*`, `+`, `?`, `{n,m}` intervals, `|` alternation (an empty
; branch is legal and matches the empty text), `^` and `$` (anchors anywhere in ERE; in BRE
; where nothing is read yet or left, which is GNU's rule), GNU's word edges \b \B \< \> and
; \w \W \s \S (both dialects), ( ) groups, and [..] classes with
; ranges, ^-negation and the twelve POSIX [:name:] classes. out of scope, refused by the
; parser in both dialects: backrefs (\1..\9). the ragged edges were read off GNU, not guessed,
; and each is commented where the parser makes it.
;
; shapes: (rebre p) / (reere p) answer (1 nodes ngroups) or () on a malformed pattern --
; uread's success shape, since the empty pattern's nodes are legitimately (). a node is
; ['chr c] | ['any] | ['cls neg items] | ['bol] | ['eol] | ['edge kind] | ['grp idx nodes] |
; ['rep atom lo hi] | ['alt (nodes..)], hi () for unbounded; groups number in ( order from 1.
; an edge is GNU's \b \B \< \>, its kind the escaped byte: a word boundary, none, a word's
; start, its end.
; (rehas nodes s) answers the boolean face, (refind nodes s i) the leftmost match at-or-after
; i as (1 start end spans), spans an ([idx start end]..) with the newest pin of each group
; first -- (..)*'s \1 is the last iteration, like GNU; read it with assoc.
(module 're
(borrow 'text)
(:
   ; the `:` of a closing `:]` at-or-after j -> (1 j) | (). the presence wrapper,
   ; not a bare index: a `:]` can legitimately sit at 0 and 0 nets blue
   (recend p n j)
    (? (n <= j + 1) ()
       (p j = 58 && p (j + 1) = 93) [1 j]
       (recend p n (j + 1)))
   ; a class body at i (past [ and any ^): `first` keeps a leading ] literal.
   ; answers (items j) | (), an item a range [lo hi] of code points or the name of one
   ; of the twelve POSIX classes, 'text's cpis. one scanner, both dialects -- POSIX
   ; spells the bracket expression the same in BRE and ERE
   (recitems p n i first acc) (n > i ? (: c (cpat p i) j (cpnext p i)
    (? (c = 93 && !first) [acc (i + 1)]
       (c = 91 && i + 1 < n && p (i + 1) = 58)
        (recend p n (i + 2) @ [_ e]
          (: nm (snip p (i + 2) e) (? (cpclass? nm) (recitems p n (e + 2) 0 (nm . acc)))))
       (j + 1 < n && p j = 45 && p (j + 1) != 93)
        (recitems p n (cpnext p (j + 1)) 0 ([c (cpat p (j + 1))] . acc))
       (recitems p n j 0 ([c c] . acc)))))

   ; -- the parser, both dialects: pattern text -> (1 nodes ngroups) | () --
   (reparse p ere?)
    (: n #p
       ; the one seam between the dialects: ( ) | { } + ? are asked for here and nowhere
       ; else; * . [ ^ $ are bare in both and are read straight off the byte.
       bw (ere? ? 1 2)
       ; an if/else, not (ere? && bare) || escaped: the || falls through to the
       ; BRE arm whenever ERE's own test fails, and `\(` is a literal paren in ERE
       (esc? i ch) (ere? ? (i < n && p i = ch) (i + 1 < n && p i = 92 && p (i + 1) = ch))
       (dig? c) (48 <= c <= 57)
       ; the literal at i and its width: a character past ascii is one class of itself,
       ; so a repeat after it takes the whole character and not its last byte
       (lit i) (: m (cpn p i) c (cpat p i) (? (1 < m) [['cls 0 [[c c]]] m] [['chr (p i)] 1]))
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
       (repable acc) (two? acc && !(elem <<acc '(bol eol edge)))
       ; where a sigil is an anchor. POSIX leaves BRE undefined outside the head and the
       ; tail; GNU reads `^` wherever nothing has been read yet -- an empty acc, since a
       ; group and a branch each open a fresh pseq -- and `$` wherever nothing is left to
       ; read. purely syntactic, so `\(a$\)b` anchors and then cannot match; anywhere else
       ; the sigil is ink. ERE anchors anywhere, so ere? short-circuits both
       (bol? acc) (ere? || (atom? acc))
       (eol? i) (ere? || (i + 1 = n) || esc? (i + 1) 41 || esc? (i + 1) 124)
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
           ; the ere drop is of the whole {n,m}, which is why rivl runs first even when
           ; nothing can be repeated: skipping just the brace leaves `2}` behind as literals
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
                 (c = 46) (pseq (i + 1) ('(any) . acc) lvl gi)
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
                        wd (d = 119 || d = 87) sd (d = 115 || d = 83)
                        (? (49 <= d <= 57) ()                 ; backrefs: refused, both dialects
                           (elem d [98 66 60 62]) (pseq (i + 2) (['edge d] . acc) lvl gi)
                           ; GNU's \w \W \s \S: a class of _ and alnum, or of space, the
                           ; capital negated
                           (wd || sd)
                            (pseq (i + 2) (['cls (? (d < 97) 1 0) (? wd ["alnum" [95 95]] ["space"])]
                                           . acc) lvl gi)
                           (lit (i + 1) @ [nd w] (pseq (i + 1 + w) (nd . acc) lvl gi)))))
                 (lit i @ [nd w] (pseq (i + w) (nd . acc) lvl gi)))))
       ; the alternation above the sequence: branches joined by the bar, kept flat
       ; in one ['alt ..] node so a three-way reads as three branches
       (palt i lvl gi)
        (: (go j g acc)
            (pseq j () lvl g @ [nds j2 g2 why]
              (: acc2 (nds . acc)
                 (? (why = 'bar) (go j2 g2 acc2)
                    (: brs (rev acc2)
                       [(two? >brs ? [['alt brs]] <brs) j2 g2 why]))))
           (go i gi ()))
       (palt 0 0 0 @ [nds _ g 'end] [1 nds g] ()))
   (rebre p) (reparse p ())
   (reere p) (reparse p 1)

   ; -- case folding, as an AST pass: -i never reaches the matcher --
   ; GNU's: each character also takes cpfold's, and upper and lower both widen to alpha,
   ; since a class cannot be walked for its members. a negation applies after the fold
   (refoldr rs)
    (cat (map (r \ (? (string? r) (? (r = "upper" || r = "lower") "alpha" r) r)) rs)
         (map (c \ [c c]) (catmap (r \ (? (string? r) () (cpfolds <r <>r))) rs)))
   ; a literal becomes the class of itself and its fold, a class gains its folds, and
   ; everything with children recurses. the matcher is untouched by -i
   (refold nds)
    (map (nd \
               (nd @ ['chr c]      (: f (cpfold c) (? (two? f) ['cls 0 (map (x \ [x x]) (c . f))] nd))
                     ['cls neg rs] ['cls neg (refoldr rs)]
                     ['grp gi sub] ['grp gi (refold sub)]
                     ['alt brs]    ['alt (map refold brs)]
                     ['rep a lo hi] ['rep <(refold [a]) lo hi]
                     nd))
         nds)

   ; -- the matcher: greedy backtracking in continuation style, compiled --
   ; a node list becomes one lambda of (s i sp k), once, before any text is read, so what a
   ; character costs at match time is a call and a compare. the node vocabulary is renode's
   ; arm list -- a shape with no arm there cannot be built above
   ; does charm c sit in a class of these items, negated or not?
   (rcls neg rs c)
    (: hit (any (r \ (? (string? r) (cpis r c) (<r <= c <= <>r))) rs) (? neg !hit hit))
   ; the class as a 256-wide table, one native string index: a range walk per charm was the
   ; whole cost of [a-z]. past ascii it can only say a lead byte might open a member
   (recls neg rs)
    (: o (jug 0)
       (go c) (? (255 < c) (slurp o)
                 (put o (? (c < 128) (? (rcls neg rs c) 1 0) (194 <= c <= 244) 1 0), go (c + 1)))
       (go 0))
   ; the program a caller holds: the matcher, whether the pattern can only match at 0, and a
   ; skipper -- the walk's way of reaching the next position that could start a match instead
   ; of asking the matcher about every one
   (recomp ns) (: c (refirst ns)
                  [(recompm ns) (reanch ns)
                   (? !c ()
                      (: sc (cite 'scan 'scanner ())      ; at compile time: never at a
                         (\ s i n (: j (sc s c i)          ; module binding, which bakes
                                     (j < 0 ? n j)))))])
   ; -- the budget, and the one shape that needs it -------------------------------
   ; this engine's one unbounded input: a repeat whose atom can match one span more than one
   ; way -- (a|aa)+ , (a*)* -- tries every split of a run and is exponential in its length.
   ; an automaton would walk the string once, but that is a different engine and not a repair,
   ; so instead there is a step count, spent only by the repeats that can nest, and a scare
   ; when it runs out.
   ; the cost lands on nothing else: `renests?` asks at compile time, so an ordinary repeat --
   ; [0-9]+, .*, a\{2,5\} -- compiles to the same rrepc it always did and its inner loop never
   ; reads the cell, and `recomp`'s fourth word says whether a matcher spends the budget at all.
   ; a function, not `relimit 200000`: module 're is walked while post.l is itself still
   ; loading, so a value binding here is read before the letrec reaches it and love0's boot
   ; floods `;; missing relimit`. a call defers, the rule a catted crew file lives under.
   (relimit _) 200000
   (renests? nd)                                 ; can this ATOM match a span two ways?
    (nd @ ['alt _]     1
          ['rep _ _ _] 1
          ['grp _ sub] (any renests? sub)
          0)
   ; the charm a match must open with, or (). only ever answered for a first node that has to
   ; consume one -- a repeat that can take nothing answers (), so the skip never steps over a
   ; match. nil? is zero?, so a NUL needle reads as absent and simply declines the skip. a
   ; character past ascii opens with its lead byte, which no tail byte can be
   (refirst ns)
    (ns @ (nd . _) (nd @
     ['chr c]       c
     ['cls 0 [[c d]]] (127 < c && c = d && utf8 c 0)
     ['grp _ sub]   (refirst sub)
     ['rep a lo hi] (0 < lo && refirst [a])
     ['alt brs]     (: cs (map refirst brs) k <cs
                     (all (c \ c @ ^k $c) cs && k))))
   (recompm ns)
    (ns @- (\ s i sp k (k i sp)) (nd . rest) (renode nd (recompm rest)))
   ; anchored: a leading `^`, or a shape whose every path opens with one. a `^`
   ; anywhere else is not the head of this list and answers 0, which is the walk
   (reanch ns)
    (ns @ (nd . _)
       (nd @ ['bol]       1
             ['grp _ sub] (reanch sub)
             ['alt brs]   (all reanch brs)))
   ; is the character at i a word's: _ or alnum. a byte no character wears reads as the
   ; latin-1 character of its value, as glibc's regex reads it: \377 is a word's, \200 is not
   (rewc s i) (: b (s i) (? (b < 128) (b = 95 || alnum? b) (cpword? (? (cpn s i < 1) b (cpat s i)))))
   ; is byte i a tail inside a character that opens before it
   (remid s i)
    (: (lead k) (? (k < 1 || i - k > 2 || (s k & 192) != 128) k (lead (k - 1)))
       (? (0 < i && i < #s && (s i & 192) = 128) (: k (lead (i - 1)) (k + cpn s k > i)) 0))
   (renode nd tail)
    (nd @ ['chr c]      (\ s i sp k (i < #s && s i = c ? (tail s (i + 1) sp k)))
          ; `.` and a class each take a character, and never a byte no character wears.
          ; ascii stays one compare, with the decode off in rewide
          ['any]        (\ s i sp k (i < #s && (s i < 128 ? (tail s (i + 1) sp k)
                                                  (rewide (c \ 1) s i sp k tail))))
          ['cls neg rs] (: t (recls neg rs) p (rcls neg rs)
                           (\ s i sp k (i < #s && t (s i) ? (s i < 128 ? (tail s (i + 1) sp k)
                                                               (rewide p s i sp k tail)))))
          ['bol]        (\ s i sp k (i = 0 && tail s i sp k))
          ; a word edge compares the characters either side (rewc); no edge stands inside
          ; a character
          ['edge kd]    (: (ok a z) (? (kd = 98) (a != z) (kd = 66) (a = z) (kd = 60) (a < z) (z < a))
                           (\ s i sp k (!(remid s i)
                                        && ok (bit (0 < i && rewc s (cpback s i))) (bit (i < #s && rewc s i))
                                        && tail s i sp k)))
          ['eol]        (\ s i sp k (i = #s && tail s i sp k))
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
          ; the budgeted twin is chosen here, once, off the atom's shape, and the counter is
          ; born in the closure -- one per entry to this repeat, with no module-level cell to
          ; bake or reset. a repeat inside another gets a fresh budget per outer step, a
          ; looser bound than one counter would give and still a bound.
          ['rep a lo hi] (: ab (recompm [a])
                            (? (renests? a)
                               (\ s i sp k (: b (tablet 0)
                                              _ (pin b 0 (relimit ()))
                                              (rrepb b ab lo hi tail s i sp k 0)))
                               (\ s i sp k (rrepc ab lo hi tail s i sp k 0)))))
   ; the character past ascii at i, if p takes its code point
   (rewide p s i sp k tail) (: m (cpn s i) (0 < m && p (cpat s i) ? (tail s (i + m) sp k)))
   ; the repeat: try one more (progress required), else the tail once fed. an empty iteration
   ; cannot repeat -- that guard is what stops `\(\)*` spinning -- but it still satisfies the
   ; minimum, all at once, or `a*\+\+` demands an `a`: the inner a* matches empty, the empty
   ; is refused, and the outer's lo=1 is never met.
   (rrepc ab lo hi tail s i sp k cnt)
    (: more (? (!hi || cnt < hi)
               (ab s i sp
                   (\ j sp2 (j = i ? (cnt < lo && tail s j sp2 k)
                             (rrepc ab lo hi tail s j sp2 k (cnt + 1))))))
       (? more more
          (cnt < lo) ()
          (tail s i sp k)))
   ; rrepc's twin, one step poorer each turn: the two lines at the top are the only
   ; difference. not folded together with a flag -- that would be read on every step of
   ; every ordinary pattern, which is the cost this arrangement exists to avoid.
   (rrepb b ab lo hi tail s i sp k cnt)
    (: n (peep b 0 0)
       _ (? (n < 1) (scare 'regex-too-costly (relimit ())) (pin b 0 (n - 1)))
       more (!hi || cnt < hi ?
             (ab s i sp
              (\ j sp2 (j = i ? (cnt < lo ? (tail s j sp2 k))
                         (rrepb b ab lo hi tail s j sp2 k (cnt + 1))))))
       (? more more
          (cnt < lo) ()
          (tail s i sp k)))
   ; the boolean face: does s contain a match anywhere. the continuation answers
   ; (1 j), never (j): a match ending at 0 would net blue and read as absence
   (rehasm m s)
    (: f <m n (<>m ? 0 #s)                        ; anchored: the walk ends where it starts
       sk <>>m
       (cite i) (? (f s i () (\ j sp [1 j])) 1
                   (i < n) (cite (i + 1)))
       (jump i) (: j (sk s i n)                   ; only the positions that could open
                   (? (n <= j) ()
                      (? (f s j () (\ e sp [1 e])) 1 (jump (j + 1)))))
       (!sk || <>m ? (cite 0) (jump 0)))
   ; the node-list faces: they compile and then match, for a caller with one text to
   ; ask about. a caller with many -- grep, sed, awk -- holds the matcher instead
   (rehas ns s) (rehasm (recomp ns) s)
   ; the leftmost span at-or-after i whose (start end) passes p: (1 start end spans) | () --
   ; uread's success shape, since the empty match at 0 is the span (0 0), blue by measure.
   ; p rides inside the continuation, which is the whole trick: a span it rejects makes `rem`
   ; answer (), and the greedy backtracker then tries the other lengths at that start before
   ; the start moves on. a filter over refind's answer only ever sees the greedy span.
   (refindpm m s i p)
    (: f <m n (<>m ? i #s)                        ; anchored: the walk ends where it starts
       sk <>>m
       (cite j) (f s j () (\ e sp (p j e ? [1 e sp])) @ [_ e sp] [1 j e sp]
                  (? (j < n) (cite (j + 1)) ()))
       (jump j) (: j2 (sk s j n)                  ; only the positions that could open
                   (? (n <= j2) ()
                      (f s j2 () (\ e sp (p j2 e ? [1 e sp])) @ [_ e sp] [1 j2 e sp]
                        (jump (j2 + 1)))))
       (!sk || <>m ? (cite i) (jump i)))
   (refindm m s i) (refindpm m s i (\ a b 1))
   (refindp ns s i p) (refindpm (recomp ns) s i p)
   (refind ns s i) (refindm (recomp ns) s i)
)

) ; module 're

; grid -- a list of cells laid across a terminal, ls's shape. the columns are ragged, each as
; wide as its own entries, and the count is the largest whose ragged widths still fit; the fill
; runs down the columns (ls's own order) or across the rows (ls -x). a cell is (text . width)
; because sgr colour parts the two -- the escape bytes take up no screen. answers the lines
; with no trailing blanks: a row's pad is written ahead of the next cell, never behind the last
; one on the row. GNU's own search and tab-eliding pad, so `ls -C` and `ls -x` compare byte for
; byte (test/kore/ls.sh).
(module '(grid lay screen)
(: gmin 3                            ; the narrowest a column may be: one char and its gap
   gpad 2                            ; the gap between two columns
   gtab 8                            ; the pad rides tab stops where two fit, as GNU's does
   (gind f t) (? (t <= f) ""
                 ((f + 1) // gtab < t // gtab) ("\t" + gind (f + gtab - (f % gtab)) t)
                 (" " + gind (f + 1) t))
   ; the cells by index: both walks jump, so a list would cost a walk per cell
   (gvec cs) (: t {}
                (go l j) (? (atom? l) t (pin t j <l, go >l (j + 1)))
                (go cs 0))
   ; the slot cell j takes when the row is i+1 columns wide
   (gslot j i n down?) (? down? (j // ((n + i) // (i + 1))) (j % (i + 1)))
   ; the search: every column count is measured over one pass of the cells, and a count dies the
   ; moment its running line outgrows w -- never revived, which keeps the pass single. the slot
   ; widths ride a tablet keyed (count * mx + slot). answers the widest count that lived.
   (gfit cs n w down?)
    (: mx (: m (w // gmin) (? (m < 1) 1 (m < n) m n))
       aw {}                         ; a slot's width so far, gmin until something widens it
       ln {}                         ; the line a count of i+1 has claimed
       ok {}                         ; is it still inside w?
       (gwide j i c)
        (: k (gslot j i n down?)
           r (>c + (? (k = i) 0 gpad))            ; the last column on a row owes no gap
           o (peep aw ((i * mx) + k) gmin)
           (? (o < r) (: l ((peep ln i (gmin * (i + 1))) + r - o)
                         _ (pin aw ((i * mx) + k) r)
                         _ (pin ln i l)
                         (pin ok i (l < w)))
              ()))
       (gone c j i) (? (mx <= i) ()
                       ((? (peep ok i 1) (gwide j i c) ()), gone c j (i + 1)))
       (gall l j) (two? l ? (gone <l j 0, gall >l (j + 1)))
       _ (gall cs 0)
       (gpick i) (? (i < 1) 1 (peep ok i 1) (i + 1) (gpick (i - 1)))
       k (gpick (mx - 1))
       (gwid j) (? (k <= j) () ((peep aw (((k - 1) * mx) + j) gmin) . (gwid (j + 1))))
       (gwid 0))
   ; down the columns: a row is cell r, r + rows, r + 2 * rows, ..
   (gdown v n cw)
    (: rows ((n + #cw - 1) // #cw)
       (row j col pos acc)
        (: c (v j) s (acc + <c) nj (j + rows)
           (? (n <= nj) s
              (: mw (cw col)
                 (row nj (col + 1) (pos + mw) (s + gind (pos + >c) (pos + mw))))))
       (go r) (? (rows <= r) () ((row r 0 0 "") . (go (r + 1))))
       (go 0))
   ; across the rows: a row is a run of #cw cells, in order
   (gacross v n cw)
    (: k #cw
       (row j col pos acc)
        (: c (v j) s (acc + <c) nj (j + 1)
           (? (n <= nj) s
              (k <= col + 1) s
              (: mw (cw col)
                 (row nj (col + 1) (pos + mw) (s + gind (pos + >c) (pos + mw))))))
       (go j) (? (n <= j) () ((row j 0 0 "") . (go (j + k))))
       (go 0))
   ; (screen fd) -- how wide the screen on fd is: $COLUMNS, then the terminal itself
   ; where fd is one (GNU's order, and what lets a gate pin a width with no terminal
   ; to ask), 80 where neither says. a COLUMNS that is not a plain count is ignored.
   (screen fd)
    (: e (getenv "COLUMNS")
       c (? (string? e) (: n (unum e) (? (charm? n && 0 < n) n 80)) 80)
       t (tty fd)
       (? (two? t && 0 < >t) >t c))
   ; (lay cs w down?) -- the cells over a terminal w columns wide, as lines
   (lay cs w down?)
    (: n #cs
       (? (n < 1) ()
          (: cw (gfit cs n w down?) v (gvec cs)
             (? down? (gdown v n cw) (gacross v n cw))))))

) ; module grid

; verbs -- the registry behind `love mooncc ..`, `love cook ..`, and a `sed` symlink onto the
; artifact. one symbol-keyed tablet, mutated in place: (cite 'verbs 'tab) hands the real tablet,
; not a copy, and `pin` is the door. registered, never spliced -- `get` would shadow half the tree.
; two front doors, because the two dispatch lanes carry different shadow rules:
;   (word w)  a leading positional -- cli's rail. refuses a `/` or a `.l`, so `make`, `env`,
;             `true` and `cmp` cannot eat a local script of the same name.
;   (seat p)  argv[0] -- love/main.c's door, which fires before the cli runs at all. always a
;             path, so the basename decides.
; a verb takes the args after its name and answers a status charm; the rail quits with it,
; which is kore's convention and why `love kore sed ..` nests.
(module '(verbs any? bn call dash enlist fills fire get holds seat seatof tab trait word)
(: tab {}   ; nil? when empty, like every empty -- ask it with peep, not by testing it
   ; what a verb says of itself, for a shell deciding where to run it -- name -> {trait v},
   ; v 1 or a function of the call's args (holds asks it of one call):
   ;   'builtin  run in the caller in every mode, ahead of PATH (echo, test ..)
   ;   'self     safe to run in the caller: BOUNDED (a shell ignores INT while it runs, so
   ;             sleep or yes could not be taken back), reads NO STDIN however it is called
   ;             (bare cat drinks the terminal), LEAVES THE CALLER AS IT FOUND IT (env X=1,
   ;             chroot), and ANSWERS THE SAME WHOEVER ASKS (pidof skips its own pid)
   ;   'exec     wants a fresh process, never a fork of a warm one (love bake: the image a
   ;             fork would carry is the one being made)
   ; a verb that says nothing is still ours, and a shell forks it warm
   traits {}
   ; a seat whose verbs are not all in the image installs a filler here, and the first miss runs
   ; it -- once, the slot cleared before the call so a fill registering through this same door
   ; cannot re-enter. a lazily-loaded verb must arrive at the miss, since the registry is what
   ; every asker walks: lush answers "not found" off the lookup and never spawns at all.
   fill {}
   (fills f) (pin fill 'f f)
   (get k)   (: v (tab k)
                (lit? v ? v
                 (: f (fill 'f)
                    (lit? f ? (pin fill 'f (), f (), tab k) ()))))
   ; a verb and what it says of itself, in one registration: ts a list of trait words, or
   ; (word . value) where the answer turns on the args -- value a function of them
   (enlist k f ts) (pin tab k f,
                    pin traits k (foldl (\ t x (? (two? x) (pin t <x >x) (pin t x 1))) {} ts))
   (trait k t) (peep (peep traits k {}) t 0)
   ; ..and the trait asked of one call: a function of the args answers for them
   ; a verb's parser may leave on a word it cannot read: that call is not the trait's
   (holds k t as) (: v (trait k t) (? (lit? v) (trap (_ \ (bit (v as))) () (\ a b 0)) v))
   ; the verb run in the caller as a builtin: urun is the driver, so a leave from deep in
   ; answers a status and never ends the caller. () when no verb has the name
   (call k as) (: f (get k) (? (lit? f) (urun f as) ()))
   bn (cite 'path 'pbase)
   (dotl? w) (: n #w (2 < n && snip w (n - 2) n = ".l"))
   (sl? w)   (: n #w (go i) (? (n <= i) 0 (w i = 47) 1 (go (i + 1))) (go 0))
   (word w)  (sl? w || dotl? w ? () (get (name w)))
   ; ..and never the artifact's own name: argv[0] `love` is this binary, not a verb called
   ; love, so the front door keeps its flags, its tty test and its stdin.
   (seat p)  (: w (bn p) (w = "love" ? () (get (name w))))
   ; the listing: ls's own grid onto a terminal, one name a line into a pipe, so
   ; `love verbs | grep` reads what it always read.
   (vlist ks) (: ns (map string ks)
                 G (cite 'grid)
                 (? (two? (tty 1))
                    (each (G 'lay (map (n \ (n . #n)) ns) (G 'screen 1) 1)
                          (l \ (puts l, putc 10)))
                    (each ns (n \ (puts n, putc 10)))))
   ; `love verbs` -- the names this artifact answers to. sorted: a tablet's key order is
   ; its own business and would read like a change.
   (vsort ws) (ws @- ws (p . s)
               (: r (vsort s)
                (ins x l) (l @- [x] (a . u) (string x < string a ? (x . l) (a . ins x u)))
                (ins p r)))
   ; the lister reads nothing: --help says the one line, any other word is a mistake
   _ (pin tab 'verbs
        (as \ (? (atom? as) (vlist (vsort (keys tab)), flush out)
                 (<as = "--help")
                  (puts "usage: verbs   (the names this artifact answers to)\n", flush out, 0)
                 (say err ("verbs: unknown option " + <as + "\n"), flush err, 2))))

   ; --- the seat scan, the third door ---
   ; a file that is the program seats itself: `love apps/moon/moon.l foo.c`, the installed
   ; shebang's `-l`, a catted script under its own name. no name was typed, a path was.
   ;   (fire ws)      -> (seat-word . args-after) over this invocation's line, else ()
   ;   (seatof ws a)  the same over a list handed in
   ; a bake pins no `cmdline`, so the read below is a lookup: nothing typed, nothing seats.
   ; () means not seated, the presence answer -- ask it with two?.
   (dash w)    (0 < #w && w 0 = 45 ? (snip w 1 #w) w)   ; -sh: login(1)'s mark
   (any? w (a . u)) (a = w || any? w u)
   (mine? ws w) (any? (dash (bn w)) ws)
   ; no arm answers () -- seats someone else, not me
   (seatof ws a) (? (atom? a) ()
                    (<a = "-l") (two? >a ?                     ; a preload named for me seats
                                 (mine? ws <>a ? (<>a . >>a) (seatof ws >>a)))  ; me -- the shebang's lane
                    (mine? ws <a) (<a . >a))
   (fire ws)   (seatof ws (? (elem 'cmdline (names ())) >cmdline ())))

) ; module verbs

; cli -- the console and command line: the read-eval-print loop, its multi-line editor, the
; stream shell (read/reads), the floor handler (welp), the port-driven line reader
; (edraw/edln/edlnc) that lush drives, and the host command line, read left to right after the
; program-name head:
;   (cli-rail ln)     the walk over ln = (program-name . args)
;   (cli-line ln tty) a frontend's whole tail: the argv[0] door, the rail, the repl, stdin
; love/main.c calls cli-line, and so does a forked lush child -- a word whose PATH winner is
; this binary need not exec, and what it would have exec'd is (cli-line its-line) on a warm
; heap. the shadow rule lives in one place, verbs' `word`.

(module '(cli read reads forms shell welp edraw edln edlnc edlay cli-rail cli-line stage edkey edtap edgc
          uopt uopt1 uoptv uoptun uoptstray uoptp uoptlast uask udoor edcmd edsgr edwide edcut edpad edfit
          ednew edstep edput ednl edclear edempty? edchars edtext edcol edparses? edframe edload
          edleft edright edbsp eddel edhome edend edtop edbot edup eddown uphist downhist eddetach
          joinln splitat parseall)
(borrow 'text)
(: (read s) (sound (hot? s ? (flow s) s) @ (x . _) (ev 'ev x)))
; ev late-binds -- (ev 'ev a): post is baked before the glaze rebinds ev, and a direct call would
; keep the egg's interpreter for every form the driver runs
(: (reads p)
   (: (walk cl z) (sound cl @ 'torn (scare 'unfinished-form p)
                              (a . b) (walk b (ev 'ev a))
                              z)
      ; the shared lane, for `in`: gulp for speed, hold nothing across an eval. box slot 0 counts
      ; every byte drawn off p, so the walk can put the port where it belongs. no window: a
      ; straddling `;` comment would end one cleanly and the next reads the prose as code.
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
         (go #t (once (u \ feed ())))))
      ; consumed, forwards and by identity. never (tally >r) -- the residue is lazy, so that
      ; forces the whole rest; and force at every step, or a plain `cup` walk stops dead at a
      ; gulp boundary and spins on () forever.
      (frc x) (lit? x ? (x ()) x)
      (upto a b n) (: aa (frc a) bb (frc b)
                      (? (aa = bb) n
                         (two? aa)   (upto >aa bb (n + 1))
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
                    v (ev 'ev a) ;;; FIXME i think this should be safe to drop to just (ev a), post evals 100% after ev is rebound, right?
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
      (p = in ? (start () 0) (walk (flow p) 0))))
(: (forms p)
   ((: (g cl acc) (sound cl @ 'torn (scare 'unfinished-form p)
                              (a . b) (g b (a . acc))
                              (rev acc)))
    (flow p) ()))

(: no (nom 0) eofsym (nom 0) edpasted {}   ; edpasted: a bracketed paste's bytes (edpaste)
   ; the terminal measures by grapheme cluster: it took ?2027, and said so (edrqm). the
   ; cursor then steps and deletes by cluster too, over the bytes edlast and edfirst count
   edgc {'on 0 'asked 0}

   ; a seat door, or (): the freestanding seats carry none of these
   (want n) (elem n (names ()) ? (ev n) ())
   raw (want 'raw)


   (rdall cl acc)
    (sound cl @ 'torn no                           ; unfinished shape -> more
                (a . b) (rdall b (a . acc))
                (rev acc))                         ; a clean end -> the datums, in order
   (parseall cl) (rdall cl () @
    ^no  no ; unfinished shape
    ((_ . ()) @ a) a                         ; one datum: as-is (leading monadic preserved)
    ((_ . _)  @ d) [d])           ; many: the application; a blank line: ()

   ; --- the editor: one buffer in a tablet, one key at a time -------------------------
   ; the buffer is a zipper of charlists: 'u the lines above (reversed), 'l the cursor's left
   ; (reversed), 'r its right, 'd the lines below. every motion and edit is a function of the
   ; tablet that answers it, so a caller with a loop of its own drives the editor the repl does.

   ; intersperse a list of charlists with newlines, in order
   (joinln ls)
    (ls @ (a . b) (atom? b ? a (a + (10 . joinln b))))

   ; walk xs forward taking n chars into acc (reversed), then call k with (rev (take n xs))
   ; and (drop n xs). stops cleanly at end-of-xs even where n exceeds the list length.
   (splitat k acc n xs)
    (xs @- (k acc xs) ((ax . ux) && 0 < n) (splitat k (ax . acc) (n - 1) ux))

   ; the same by character: a utf-8 tail byte goes with the lead before it
   (splitc k acc n xs)
    (xs @- (k acc xs) ((ax . ux) && (0 < n || edtail? ax))
     (splitc k (ax . acc) (edtail? ax ? n (n - 1)) ux))

   ; map non-printables to space; otherwise pass through. a utf-8 byte is printable: the
   ; terminal puts the character together
   (prc c) (putc (32 <= c < 127 || 127 < c ? c 32))

   ; the buffer holds bytes and the cursor moves by character
   (edtail? c) (128 <= c < 192)
   ; the columns a charlist of bytes takes: a control shows as a space (prc), a character
   ; its wcwidth -- a cluster its columns, while the terminal says it measures so (edgc) --
   ; and a sequence still arriving at the end none yet
   (edpend? s i)
    (: n #s need (? (s i < 224) 2 (s i < 240) 3 4)
       (go k) (? (n <= k) 1 (edtail? (s k)) (go (k + 1)) ())
       (n - i < need && go (i + 1)))
   (edw cs)
    (: s (string cs) n #s
       (go i a) (? (n <= i) a
                   (: b (s i)
                      (? (b < 32 || b = 127) (go (i + 1) (a + 1))
                         (192 <= b && cpnext s i = i + 1 && edpend? s i) a
                         (edgc 'on) (go (gcnext s i) (a + gcwidth s i))
                         (b < 128) (go (i + 1) (a + 1))
                         (go (cpnext s i) (a + max 0 (wcwidth (cpat s i)))))))
       (go 0 0))
   ; the bytes the last cluster of l (backwards) and the first of r take, under edgc
   (edlast l) (: s (string (rev l)) n #s (go i) (: j (gcnext s i) (? (n <= j) (n - i) (go j))) (go 0))
   (edfirst r) (gcnext (string r) 0)

   (ednew _) {'u () 'l () 'r () 'd () 'ev 0}
   (edleft t) (: l (t 'l) u (t 'u) (?- t
    (two? l && edgc 'on) (: k (edlast l) (pins t 'l (drop k l) 'r (revcat (take k l) (t 'r))))
    (two? l) (: (go l r) (: c <l (? (edtail? c && two? >l) (go >l (c . r)) [>l (c . r)]))
                p (go l (t 'r))
                (pins t 'l <p 'r <>p))
    (two? u) (pins t 'u >u 'l (rev <u) 'r () 'd (revcat l (t 'r) . t 'd))))
   (edright t) (: r (t 'r) d (t 'd) (?- t
    (two? r && edgc 'on) (: k (edfirst r) (pins t 'l (revcat (take k r) (t 'l)) 'r (drop k r)))
    (two? r) (: (go l r) (? (two? r && edtail? <r) (go (<r . l) >r) [l r])
                p (go (<r . t 'l) >r)
                (pins t 'l <p 'r <>p))
    (two? d) (pins t 'u (revcat (t 'l) r . t 'u) 'l () 'r <d 'd >d)))
   (edbsp t) (: l (t 'l) u (t 'u) (?- t
    (two? l && edgc 'on) (pin t 'l (drop (edlast l) l))
    (two? l) (: (go l) (? (two? >l && edtail? <l) (go >l) >l) (pin t 'l (go l)))
    (two? u) (pins t 'u >u 'l (rev <u))))
   (eddel t) (: r (t 'r) d (t 'd) (?- t
    (two? r && edgc 'on) (pin t 'r (drop (edfirst r) r))
    (two? r) (: (go r) (? (two? r && edtail? <r) (go >r) r) (pin t 'r (go >r)))
    (two? d) (pins t 'r <d 'd >d)))
   (edhome t) (pins t 'l () 'r (revcat (t 'l) (t 'r)))
   (edend t) (pins t 'l (revcat (t 'r) (t 'l)) 'r ())
   ; edtop / edbot jump across the whole buffer: the start of the topmost line, the end
   ; of the bottommost. on a single-line buffer they are edhome / edend
   (edtop t) (rev (t 'u) @- (edhome t) (au . uu) (pins t 'u () 'l () 'r au 'd (uu + (revcat (t 'l) (t 'r) . t 'd))))
   (edbot t) (rev (t 'd) @- (edend t)  (ad . ud) (pins t 'u (ud + (revcat (t 'l) (t 'r) . t 'u)) 'l (rev ad) 'r () 'd ()))
   ; up and down keep the column (in characters), clamped to the line
   (edn l) (foldl (a \ c \ edtail? c ? a (a + 1)) 0 l)
   (edup t) (t 'u @- t (au . uu) (splitc (\ lz rr (pins t 'u uu 'l lz 'r rr 'd (revcat (t 'l) (t 'r) . t 'd))) () (edn (t 'l)) au))
   (eddown t) (t 'd @- t (ad . ud) (splitc (\ lz rr (pins t 'u (revcat (t 'l) (t 'r) . t 'u) 'l lz 'r rr 'd ud)) () (edn (t 'l)) ad))
   (edput t c) (pin t 'l (c . t 'l))                       ; insert at the cursor
   (ednl t) (pins t 'u (rev (t 'l) . t 'u) 'l ())           ; break the line at the cursor
   ; pasted bytes in at the cursor: a line break breaks the line (a crlf once), a tab
   ; stays, and every other control goes
   (edpin t l)
    (: (go l prev) (? (atom? l) t
                      (: c <l
                         _ (? (c = 10 && prev = 13) 0
                              (c = 10 || c = 13) (ednl t)
                              (c = 9 || (32 <= c && c != 127)) (edput t c)
                              0)
                         (go >l c)))
       (go l 0))
   (edclear t) (pins t 'u () 'l () 'r () 'd ())
   (edchars t) (joinln (revcat (t 'u) (revcat (t 'l) (t 'r) . t 'd)))   ; the whole buffer, one charlist
   edempty? (nil? * edchars)
   edtext (string * edchars)
   (edcol t) (edw (rev (t 'l)))                            ; the cursor's screen column
   edparses? (two? * parseall * edchars)
   (edframe t) (t 'u . t 'l . t 'r . t 'd)           ; the buffer packed for history
   (edload t f) (pins t 'u <f 'l <>f 'r <>>f 'd >>>f)

   ; --- the history zipper, on the same tablet ---------------------------------------
   ; 'hu the older frames, 'hd the newer, 'cur a pristine recall: an edit gives it back to 'hu
   ; first, so the original survives. on a pop the buffer goes to the other side (skipped when
   ; empty); on a real recall with no further side it is pushed and a fresh line opens.
   (eddetach t) (atom? (t 'cur) ? t (pins t 'hu (t 'cur . t 'hu) 'cur ()))
   (uphist t) (: hu (t 'hu)
     (? (two? hu) (edempty? t ? () (pin t 'hd (edframe t . t 'hd)),
                   pins (edload t <hu) 'hu >hu 'cur <hu)
        (two? (t 'cur) && edparses? t) (pin t 'hd (edframe t . t 'hd), pin (edclear t) 'cur ())
        t))
   (downhist t) (: hd (t 'hd)
     (? (two? hd) (edempty? t ? () (pin t 'hu (edframe t . t 'hu)),
                   pins (edload t <hd) 'hd >hd 'cur <hd)
        (two? (t 'cur) && edparses? t) (pin t 'hu (edframe t . t 'hu), pin (edclear t) 'cur ())
        t))

   ; --- one key into the buffer ------------------------------------------------------
   ; motions and edits are taken here; what the editor does not decide -- enter (13 reads
   ; as 10), escape, tab, ^C, ^D, eof, up and down past the buffer -- is left in 'ev for
   ; the caller, 0 when the key was taken
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

   ; --- a prompt on the buffer -------------------------------------------------------
   ; the `:` line: the editor sits at key k of a state, the key is stepped into it, and an
   ; enter hands the caller the line while an escape backs out. a tab is a tab -- nothing here
   ; completes. any other key answers the state itself, and a fresh buffer is the caller's.
   (edcmd t k c enter esc)
    (: e (t k)
       _ (edstep e c)
       (e 'ev @ 10 (enter (edtext e))
                27 (esc ())
                9 (edput e 9, t)
                t))

   ; --- the key reader ---------------------------------------------------------------
   ; one key off port p: a byte as itself, -7 at eof, and the escape family decoded. a bare
   ; escape (no tail within a beat) is 27, the CSI arrows and jumps are the codes in the
   ; tables, alt with a letter is 256 + the letter, and any other byte after an escape goes
   ; back for the next read. an unknown sequence is 0 -- the miss, read with ==, since an
   ; event code nets red and truth cannot tell hit from miss
   arrow    {68 -1 67 -2 65 -8 66 -9 72 -5 70 -6}    ; ESC [ F -- the plain finals
   modarrow {68 -1 67 -2 65 -8 66 -9 72 -10 70 -11}  ; ESC [ 1 ; M F -- modified home/end jump the buffer
   ; a tap is a place and not a letter: xterm's SGR report (ESC [ < b ; col ; row M, m for
   ; the release) carries the cell it landed on. the press is the key -12 and the cell waits
   ; in edtap, 0-based in screen order, so an app with no arm for -12 simply drops it.
   edtap-at {'x 0 'y 0}
   (edtap _) [(edtap-at 'x) (edtap-at 'y)]
   (ednum p a) (: c (see p) (48 <= c <= 57 ? (ednum p (a * 10 + c - 48)) [a c]))
   (edmouse p) (: _ (ednum p 0)                     ; the button, which no app here reads
                  x (ednum p 0)
                  y (ednum p 0)
                  _ (pins edtap-at 'x (<x - 1) 'y (<y - 1))
                  (<>y = 77 ? -12 0))               ; M is the press, m the release
   ; a bracketed paste (ESC [ 200 ~ .. ESC [ 201 ~) is the key -13, its bytes waiting in
   ; edpasted; any other ESC [ 2 is a miss
   (edpaste p) (: a (see p) b (see p) f (see p)
                  (? !(a = 48 && b = 48 && f = 126) 0
                     (: (go acc) (: c (see p)
                                    (? (c < 0) acc
                                       (: q (c . acc)
                                          (? (c = 126 && [126 49 48 50 91 27] = take 6 q) (drop 6 q) (go q)))))
                        _ (pin edpasted () (rev (go ())))
                        -13)))
   ; a DECRQM answer (ESC [ ? Ps ; Pm $ y) is a miss too, ?2027 set or permanently set
   ; turning edgc on
   (edrqm p) (: m (ednum p 0) v (? (<>m = 59) (ednum p 0) [0 0])
                _ (? (<>v = 36) (see p) 0)
                _ (? (<m = 2027 && <>v = 36) (pin edgc 'on (? (<v = 1 || <v = 3) 1 0)) 0)
                0)
   (edcsi p) (: c (see p) e (peep arrow c 0)
               (? (e != 0) e
                  (c @ 49 (see p @ 126 -5  59 (see p, peep modarrow (see p) 0)  0)
                       55 (see p, -5)
                       (52 || 56) (see p, -6)
                       51 (see p, -4)
                       60 (edmouse p)
                       50 (edpaste p)
                       63 (edrqm p)
                       0)))
   (edkey p) (: c (see p)
               (? (c = -1) -7
                  (c != 27) c
                  !(rest 1, cue? p) 27
                  (: c2 (see p)
                     (? (c2 = 91) (edcsi p)
                        (97 <= c2 <= 122) (256 + c2)
                        (c2 = -1) 27
                        (unsee p c2, 27)))))

   ; --- the stage: a full-screen tty app ---------------------------------------------
   ; show answers the frame for a screen w by h, step takes a key, over? says when to leave.
   ; the frame lives on the alternate screen, the tty is raw for the visit and cooked after,
   ; and eof leaves too. a frame places or hides the cursor itself; it comes back shown
   (stage show step over?)
     (: (loop _) (: ws (tty 1)
                    h (two? ws && 7 < <ws ? <ws 24)
                    w (two? ws && 19 < <>ws ? <>ws 80)
                    _ (say out (show w h))
                    _ (flush out)
                    c (edkey in)
                    (? (c = -7) ()
                       (step c, over? () ? () (loop ()))))
        (raw 1, say out "\e[?1049h", loop (),
         say out "\e[0m\e[?25h\e[?1049l", flush out, raw 0, 0))

   ; redraw the buffer in place. the cursor's row from the previous render is kept on the
   ; buffer ('row) -- move up that many first, and all motion is relative, so terminal
   ; scrolling never desyncs us. pl is the prompt's column, shared by the topmost line only.
   (csi n f) (putc 27, putc 91, putn n, putc f)   ; ESC [ n f -- the one cursor verb
   (edbelow t) (: n (peep t 'below 0) (0 < n ? (csi n 66) ()))   ; down past the buffer's rows
   ; the buffer on a screen w wide: the cursor's row and column and the row the last character
   ; sits on, rows counted from the buffer's first. a line that ends on the margin leaves the
   ; cursor pending there, so a line of n from column s covers (s + n - 1) // w + 1 rows
   (edlay w pl u l r d)
     (: (rows s n) (0 < n ? (((s + n - 1) // w) + 1) 1)
        (span top s) (? (atom? top) 0 ((rows s (edw <top)) + (span >top 0)))
        above (span (rev u) pl)
        s0 (two? u ? 0 pl)
        k (s0 + edw (rev l))
        [(above + (k // w)) (k % w) (above + (rows s0 (edw (revcat l r))) + (span d 0) - 1)])
   ; the screen already carries this line but for its last character: nothing above or below
   ; it, the cursor at its end, and an l that is the drawn one with a character pushed on top.
   ; l grows by prepending, so the drawn one is the tail and the question is an identity.
   (edgrew t)
     (: l (t 'l)
        (!(t 'u) && !(t 'd) && !(t 'r) && two? l && cup l == (t 'was)))
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
        _ (pins t 'row crow 'below (erow - crow))
        (? grew (prc <l, 0 = ccol ? (putc 10), flush out)
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
    (: n #s
       (? !(i + 1 < n && s i = 27 && s (i + 1) = 91) 0
          ((: (g k) (? (n <= k) 0
                       (s k = 109) (k + 1 - i)
                       (47 < s k < 58 || s k = 59) (g (k + 1))
                       0)) (i + 2))))

   ; a prompt's width on the screen, which is not its tally: an sgr run costs no column, an
   ; ascii byte one (a tab or a control included, as the fields have always counted them) and
   ; any other character its wcwidth, a wide one two. edrender's cursor math is relative motion
   ; off this number, so a prompt measured in bytes lands the cursor one column per escape byte out.
   (edcw s i) (? (s i < 128) 1 (max 0 (wcwidth (cpat s i))))
   (edwide s)
    (: n #s
       (go i c) (? (n <= i) c
                   (: e (edsgr s i)
                      (? e (go (i + e) c) (go (cpnext s i) (c + edcw s i)))))
       (go 0 0))

   ; the first n columns of s, by the same measure, a wide character that would straddle the
   ; edge left out. a cut that dropped part of a coloured string ends in a reset, so a pen
   ; cannot run on into whatever is laid beside it.
   (edcut s n)
    (: m #s
       (cut i pen) (snip s 0 i + (pen ? "\e[0m" ""))
       (go i c pen)
        (? (m <= i) s
           (: e (edsgr s i)
              (? e (n <= c ? (cut i pen) (go (i + e) c 1))
                 (: v (c + edcw s i)
                    (n < v ? (cut i pen) (go (cpnext s i) v pen))))))
       (go 0 0 0))

   ; a string laid in a field n columns wide: edpad fills what the glyphs leave, edfit cuts
   ; first so the answer is exactly n wide -- both by column, not by byte.
   (edpad s n c) (: w (edwide s) (w < n ? (s + ((n - w) (t \ t + c) "")) s))
   (edfit s n c) (edpad (edcut s n) n c)

   ; --- the option walk, shared by kore's applets and love's own rail ----------------
   ; (uopt1 w flags vals) -- one word into its letters as words of their own, or () when the
   ; word is not ours to read. the short flags cluster, so `-qe X` is `-q -e X`; a letter in
   ; `vals` takes an argument and ends the chain, the rest of its own word being the value
   ; (-m4m). `flags` names the letters that chain, and () there means any letter not in `vals`
   ; does -- what an applet wants when it validates its own alphabet. a letter in neither set
   ; refuses the whole word, so `love -qz` stays one word and reaches the file lane.
   (uopt1 w flags vals)
    (: n #w
       ; `flags` empty means every letter chains. spelled as the predicate and not as
       ; !flags, which would glue to the arm behind it and read (nil? (flags 1)).
       (ours? c) (? (elem c vals) 1 flags (elem c flags) 1)
       (go k acc)
        (? (n <= k) (rev acc)
           (: c (w k)
              s ("-" + string c)
              g (snip w (k + 1) n)
              (? (elem c vals) (rev (#g ? (g . s . acc) (s . acc)))
                 (ours? c) (go (k + 1) (s . acc))
                 ())))
       (2 <= n && w 0 = 45 && !(w 1 = 45) ? (go 1 ()) ()))
   ; (uopt as t vals reps longs) -> [t stacked rest]: every flag pinned on t under its own key,
   ; a value flag pinning the (1 v) wrapper -- never the bare text, since `two?` is false for a
   ; one-element list and a bare "" would read as absent -- and a key in `reps` stacking into a
   ; list instead. `rest` is the operands, `--` ends the flags, and the whole answer is () when
   ; a value flag is left without one, so read it with `two?` and not for truth.
   ; `longs` maps a long flag's name, no dashes, to the key it pins under: a charm, so --width
   ; and -w are one option with one reader. () is an applet with no long flags, and a name the
   ; map does not carry is not ours -- that word ends the flags and becomes an operand.
   ; --name=VALUE is taken only where the name's key is in `vals`; a glued value on a flag that
   ; takes none is not ours either, rather than a value silently dropped.
   (uopt as t vals reps longs)
    (: (pinv c v es) (? (elem c reps) (v . es) (pin t c [1 v], es))
       (lgot nm) (? (tablet? longs) (longs nm) ())
       ; the key a flag word pins under: a long word's name through the map, a short word's
       ; own letter. one key per option however it was spelled.
       (ukey w) (? (w 1 = 45) (lgot (snip w 2 #w)) (w 1))
       ; one long word into the shape uopt1 answers for a short cluster, so `eat` walks
       ; either: the word alone, or the word and the value glued behind its `=`.
       (long1 a)
        (: n #a
           e ((: (go i) (? (n <= i) -1 (a i = 61) i (go (i + 1)))) 2)
           c (lgot (snip a 2 (e < 0 ? n e)))
           (? !c ()
              (e < 0) [a]
              (elem c vals) [(snip a 0 e) (snip a (e + 1) n)]
              ()))
       ; the exploded word, then the argv tail behind it. a value key ends its chain, so
       ; at most one element of `bs` is ever a value and it is the last.
       (eat bs rest es)
        (? (atom? bs) (walk rest es)
           (: w <bs c (ukey w)
              (? (elem c vals)
                 (? (two? >bs)  (walk rest (pinv c <>bs es))     ; the value rode along glued
                    (two? rest) (walk >rest (pinv c <rest es))   ; ..or it is the next word
                    ())                                          ; ..or there is none: a miss
                 (pin t c 1, eat >bs rest es))))
       (walk as es)
        (? (atom? as) [t (rev es) ()]
           (: a <as
              (? (a = "--") [t (rev es) >as]
                 (2 < #a && a 0 = 45 && a 1 = 45)
                  (: bs (long1 a) (? (two? bs) (eat bs >as es) [t (rev es) as]))
                 (: bs (uopt1 a () vals)
                    (? (two? bs) (eat bs >as es) [t (rev es) as])))))
       (walk as ()))
   ; a value option's text, or () -- the presence read that pairs with uopt
   (uoptv t c) (: r (t c) (? (two? r) <>r ()))
   ; the first key the walk pinned that `ok` does not name, or () when every one is the
   ; applet's own. the short lane takes any letter, an alphabet being the applet's to state,
   ; so the key comes back for a refusal to name it.
   (uoptun t ok) (<(filter (c \ (nelem c ok)) (sort (keys t))))
   ; an operand that still looks like a flag, or (). the walk stops at the first word that is
   ; not one, so an applet with positional operands would take `-x` for a filename. () once
   ; `--` has been spelled: the words behind it are literal by request.
   (uoptstray as rest) (? (elem "--" as) () (<(filter (w \ 1 < #w && w 0 = 45) rest)))
   ; (uoptp as t vals reps longs) -> [t stacked operands stray] | (): uopt in gnu order, a flag
   ; free to follow an operand and every word behind `--` an operand. stray is the first long
   ; word that was not ours (uopt reads it as an operand), or ()
   (uoptp as t vals reps longs)
    (: (go as es ops stray)
        (: r (uopt as t vals reps longs)
           (two? r ?
              (: es2 (es + r 1) rest (r 2) k (#as - #rest)
                 (? (atom? rest) [t es2 (rev ops) stray]
                    (0 < k && as (k - 1) = "--") [t es2 (rev ops + rest) stray]
                    (: w <rest
                       (go >rest es2 (w . ops)
                           (stray || (2 < #w && w 0 = 45 && w 1 = 45 ? w ()))))))))
       (go as () () ()))
   ; the last of `keys` spelled in the flag words before `--`, short or long, or (): the order
   ; uopt's tablet drops, for the flags where the later one wins (a level, a mode)
   (uoptlast as keys vals longs)
    (: (lkey w) (: e ((: (go i) (? (#w <= i || w i = 61) i (go (i + 1)))) 2)
                   (? (tablet? longs) (longs (snip w 2 e)) ()))
       (short w k got)                                   ; -> [got skip-the-next-word]
        (? (#w <= k) [got 0]
           (: c (w k)
              (? (elem c vals) [got (k + 1 = #w ? 1 0)]
                 (short w (k + 1) (elem c keys ? c got)))))
       (go as got)
        (? (atom? as) got
           (: w <as
              (? (w = "--") got
                 (2 < #w && w 0 = 45 && w 1 = 45)
                  (: c (lkey w) (go >as (elem c keys ? c got)))
                 (2 <= #w && w 0 = 45)
                  (: r (short w 1 got) (go (r 1 ? >>as >as) <r))
                 (go >as got))))
       (go as ()))

   ; --- the two flags every applet answers, and the one place that answers them ------
   ; the leading flag words only: the walk stops at the first operand and at `--`, so a file
   ; really called --help still opens once something else has been named. not getopt -- a
   ; value word that looks like a flag is walked over, so `grep -e --help f` answers the help.
   (uask as h? v?)
    (two? as ?
       (: w <as
          (? (w = "--") ()
             (w = "--help") 'help
             (w = "--version") 'vers
             (w = "-h" && h?) 'help
             (w = "-v" && v?) 'vers
             (1 < #w && (w 0 = 45)) (uask >as h? v?)
             ())))
   ; an applet as the world calls it: nm is its name, u its usage text, and h?/v? whether the
   ; bare letters are free -- posix or gnu has spoken for one in a few places, and there the
   ; long form is the only answer. answers the main a verb registry takes.
   (udoor nm f u h? v?)
    (: (say1 x) (: n #x                       ; a page that ends in a newline keeps just the one
                   (puts (? (n && (x (n - 1) = 10)) x (x + "\n")), flush out, 0))
       (as \ (uask as h? v?
              @ 'help (say1 (u || ("usage: " + string nm)))
                'vers (say1 (string nm + " (love " + love-version + ")"))
                (f as))))

   ps1 "> "
   ; the helm glows in the crew's cyan (256-colour 117 ~ #7dcfff), reset after.
   ps1c (string 27 + "[38;5;117m" + ps1 + string 27 + "[39m")

   ; print the prompt, then dispatch keys until ^D or a submitted buffer.
   ; returns eofsym on ^D, else (vs . nhu) so the repl can thread history.
   (edline hu hd)
     (: pl (edwide ps1c)
        _ (puts ps1c)
        t (pins (ednew ()) 'hu hu 'hd hd 'cur ())
        (loop _)
          (edrender pl t,
           edstep t (edkey in),
           (t 'ev @ 0 (loop ())
              ; ^D leaves the line ended, so whatever runs next starts on its own
              (-7 || 4) ((0 < (t 'below) ? (csi (t 'below) 66) ()), putc 10, eofsym)
              ; enter cashes the buffer as long as it parses complete
              10 (parseall (edchars t) @
                  ^no (ednl (eddetach t), loop ())
                  vs (: _ (eddetach t)
                        h (revcat (t 'hd) (t 'hu))
                        (0 < (t 'below) ? (csi (t 'below) 66) (),   ; past the rows below the cursor
                         putc 10,
                         [vs (!vs ? h (take 100 (edframe t . h)))])))
              -8 (uphist t, loop ())
              -9 (downhist t, loop ())
              3 (puts "^C\n", edempty? t ? eofsym (edline (t 'hu) (t 'hd)))
              (loop ())))
        (edbr loop))
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
                    (vs . nhu . nhd) (each vs (v \ (do_eval v, putc 10)), repl nhu nhd))

   ; no-op () returning scare handler
   (welp a b) ()

   ; the face a raise wears -- ;; a b. a program's raise wears no help at all: it leaves
   ; the eval as a scare, and the frontend prints the same face and quits 1
   (hface a b) (say err ";; ", print err a, say err " ", print err b, put err 10)
   (shell-help a b) (hface a b, welp a b)
   ; the handler is the repl's own and goes back on the way out: a rail that reached the repl
   ; through the `love` verb leaves by scaring 'cli-leave, which this would print as a raise.
   (shell _)
    (: prev (heard ())
       _ (hear shell-help)        ; the prompt survives every raise; a script must not
       _ (raw 1)
       _ (puts $ ";3 love " love-version "\n")
       r (repl 0 0)
       _ (hear prev)
     r)

   ; the terminal brackets pastes and measures by grapheme cluster (?2027) only while a line
   ; is edited, so a program run after it sees neither; the first line asks whether it
   ; measures so (DECRQM, edrqm)
   (edbr f) (: _ (puts (? (edgc 'asked) "\e[?2004h\e[?2027h" "\e[?2004h\e[?2027h\e[?2027$p"), pin edgc 'asked 1)
               r (f ())
               _ (puts "\e[?2004l\e[?2027l", flush out)
               r)
   ; (edraw ip pr) -- read one line off port `ip`, with in-line editing: the charlist, or eofsym
   (edraw ip pr) (:- (edbr loop)
    pl (puts pr, edwide pr) t (ednew ())
    (loop _) (edrender pl t,
              edstep t (edkey ip),
              t 'ev @- (loop ()) (-7 || 4) eofsym 10 (edbelow t, putc 10, edchars t)))

   ; the shell line reader: edraw + command history + tab completion
   (edlnc ip pr hist comp)
     (: pl (puts pr, edwide pr) hn #hist t (ednew ())
        (hnth k) <(drop k hist)                       ; hist[k], 0-based (k < hn)
        (recall i ni draft)                           ; jump to view index ni (0 = the draft)
          (: nd (i = 0 ? (revcat (t 'l) (t 'r)) draft)  ; save the live draft once, the instant up leaves it
             _ (pins t 'l (rev (ni = 0 ? nd (hnth (ni - 1)))) 'r ())
             (loop ni nd))
        (loop i draft)
          (edrender pl t,
           edstep t (edkey ip),
           (t 'ev @ 0 (loop i draft)
              (-7 || 4) 'eof
              10 (: ln (edbelow t, putc 10, edchars t)
                    nh (!ln ? hist (take 100 (ln . hist)))
                  (ln . nh))
              3 (puts "^C\n", () . hist)   ; ^C: abandon the line, hist untouched
              9 (? !comp (loop i draft)
                   (: cl (comp (revcat (t 'l) ()))
                      (? (atom? cl) (loop i draft)
                         (: _ (pin t 'l (foldl (a \ ch \ ch . a) (t 'l) <cl))
                            cs >cl
                          (two? cs && two? >cs ?
                            (puts $ "\n" + foldl (a \ s \ 0 = #a ? s (a + "  " + s)) "" cs + "\n"),
                           loop i draft)))))
              -8 (recall i (i >= hn ? i (i + 1)) draft)   ; up: older
              -9 (recall i (0 >= i  ? i (i - 1)) draft)    ; down: newer
              (loop i draft)))
        (edbr (_ \ loop 0 ())))
   (edln ip pr hist) (edlnc ip pr hist ())
)


; the command line. the defglobs go through `ev` of a built (: nm 'v), and the inner quote is
; load-bearing -- without it ev takes the value apart as a form to run. argv reaches the
; program's view before (run ()) fires.
; the exit door: every leave -- a bad -m, a missing operand, an unopenable file, a torn -e, a
; verb's own status -- scares 'cli-leave, and the trap handler answers its charm, which the
; frontend quits with. nothing here quits: the core spells no host word. the handler is
; written twice because a leave lands in either of two spans, `pre` and `run`, and the
; defglob has to sit between them.
(: (cli-rail ln)
 (: (charm0 x) (charm? x ? x 0)
    ; a program's own uleave ('leave, udie's) goes out the same door
    (door a b) (? (a == 'cli-leave || a == 'leave) (charm0 b) (scare a b))
    cli2
 (trap (x \
            (: (cli-leave c) (scare 'cli-leave c)
               ; a kind test, not a match on (): a refusal answers a nom, and a nom is truthy
               ; open is posix's, and a seat without it answers () here rather than at the bake
               (load1 p) (: q (cite 'posix 'open p "r")
                            (? (hot? q) (reads q) (say err $ "love: cannot open " + p + "\n", cli-leave 1)))
               (eval1 s) (: m (nom 0)                           ; a fresh nom: the unfinished shape, ==-safe
                  (rdl x acc) (sound x @ 'torn      m           ; every top-level datum off the string, in order
                                          (a . b)  (rdl b (a . acc))
                                          (rev acc))
                  (rdl s () @ ^m (say err "love: -e: unfinished form\n", cli-leave 2)
                              (d @ (a . u)) (ev 'ev (atom? u ? a d)))) ; many datums fold to one application
               v-msg ("love " + love-version + "\n")   ; _ arg: love has no nullary calls
               h-msg
               ("usage: love [wake IMAGE] [-l FILE] [-e EXPR] [-q] [-m SIZE] [-v] [-h] [--] [VERB|FILE] [ARG ...]\n" +
                "  -l, --load FILE   preload FILE (read-eval) before the program\n" +
                "  -e, --eval EXPR   eval EXPR as one expression (infix works), print the answer\n" +
                "  -q, --quiet       with -e: do not print the answer\n" +
                "  -m  --memory N    max heap in {k,m,g} default = 0m = unlimited\n" +
                "  -v, --version     print the version\n" +
                "  -h, --help        print this help\n" +
                "  --                end of options; the rest are files, and none of them is stdin\n" +
                "the short flags cluster -- `-qe EXPR` is `-q -e EXPR` -- and a letter taking an\n" +
                "argument ends the chain, on the rest of its word (-m8m) or the next one\n" +
                "with no arguments then start a repl if on a tty else eval expressions from stdin\n" +
                "try `love verbs` to see a list of commands\n")
               (need h '()) (say err $ "love: " + h + " needs an argument\n", cli-leave 2)
               K 1024 M 1048576 G 1073741824
               wordsz (charm? G ? 8 4)             ; 2^30 is a charm only where a fixnum is 62-bit
               ; validate here: a bad value reaching `tune` writes a non-Z tray, which the nif refuses
               ; whole and in silence, so the flag would read as accepted and do nothing. it floors at
               ; 0, not 1, because 0 is the unbounded spelling.
               (size h s) (: n #s
                             u (peep s (n - 1) 0 @ (107 || 75) K
                                                   (109 || 77) M
                                                   (103 || 71) G)
                             d (u && snip s 0 (n - 1) || s)
                             v <(sound d)                   ; bound, not inlined: a bare infix `//` in the
                                                            ; `:` body slot folds into the binding chain
                             (charm? v && v >= 0 ?
                              (v * (u || M) // wordsz)
                              (say err $ "love: " + h + ": not a size: " + s + "\n",
                               cli-leave 2)))
               ; -> (kind . rest): 'eval code.args / 'verb fn.args / 'file prog.args / 'stdin / 'none.
               ; 'none is the line running out with no program named: -v and -h are not terminal, so
               ; `love -v -h` prints both, reaches the end, and leaves 0.
               (pre a) (a @ (h . t)
                 (: bs (uopt1 h "vhq" "lem")
                  (two? >bs ? (pre (bs + t))
                   (h @ ("-l" || "--load")    (need h t, load1 <t, pre >t)
                        ("-v" || "--version") (puts v-msg, pre t)
                        ("-h" || "--help")    (puts h-msg, pre t)
                        ("-e" || "--eval")    (need h t, 'eval . t)
                        ("-q" || "--quiet")   (pre t @ ('eval . r) ('evalq . r) r r)
                        ; slot 0 of a fresh `tune` read, so the other knobs ride and the last -m wins. it
                        ; lands at the next collection: the opening pool was sized before argv was read.
                        ("-m" || "--memory")  (need h t, tune (pin (tune ()) 0 (size h <t)), pre >t)
                        "--"                 (t @ (_ . _) ('file . t) '(stdin))
                        (cite 'verbs 'word h @ '() ('file . a) f ('verb . f . a)))))
                 '(none))
               ; stdin is the answer to an empty command line, or to `--` with nothing after it --
               ; never to a line that carried flags and named no program.
               p (two? >ln ? (pre >ln) '(stdin))   ; runs -l preloads + -v/-h + -m; the program kind
               k <p
               av (k @ ('eval || 'evalq || 'verb) >>p >p)   ; the program's view of argv
               run (_ \
                        (k @ 'eval  (puts * show $ eval1 <>p, putc 10, 0)  ; -e answers out loud through `show`, the
                             'evalq (eval1 <>p, 0)      ; repl's face, not dot's raw one; -q mutes
                             'verb  (: r (<>p >>>p)     ; a verb takes the args after its name and answers a status,
                                       (cli-leave $ charm0 r))  ; out the one door
                             'file  (load1 <>p, 0)
                             'none  0                   ; the flags did their printing; leaving is the answer
                             (reads in, 0)))
               [av run]))
       () door)
 (? (charm? cli2) cli2                  ; a leave in pre: the status is the answer
    (ev [': 'argv ['\ <cli2]], ; the program's view, before the run
     trap (x \ <>cli2 ())    ; (run ()): dispatch, argv now the program's view
      () door)))

 (cli-line ln tty)
   (: (charm0 x) (charm? x ? x 0)
      V  (cite 'verbs)
      _  (ev [': 'cmdline ['\ ln] 'argv ['\ ln] ])   ; C's line is already past the primes
      f  (V 'seat <ln)
      (charm0 (? f          (trap (_ \ (f >ln)) () (\ a b (a == 'leave ? (charm0 b) (scare a b))))
                 (two? >ln) (cli-rail ln)
                 tty        (shell 0)
                 (reads in, 0)))))         ; non-tty stdin: the stream face drinks the in port

 ; `love` is a verb like every other program this binary carries, which is what lets a shell
 ; with no seat to exec reach the repl by name. last in the letrec: the closure takes its free
 ; names as they stand.
 _ (cite 'verbs 'enlist 'love
     (as \ (two? as ? (cli-rail (. "love" as)) (shell 0)))
     [('exec . (as \ (two? as && (<as = "bake" || <as = "wake"))))])
) ; module cli
