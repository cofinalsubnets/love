```ai
; ai -- a lisp-surfaced, fully-curried language over a tiny generic C core.
; a portable C runtime (ai.c + ai.h) plus a self-hosting compiler written in ai
; (the ai/{prel,ev,bao}.l layers). the canonical source suffixes are `.l`, `.ai`, and `.tl`; the host binary is `ai`. see README.md.
;
; this file is the NARRATIVE: the prose spec, my working notes, and runnable demonstrations --
; CLAUDE.md is my context file. the EXECUTABLE spec -- every claim below, assert-backed on
; every target -- lives in test/spec.l, a real test in the corpus (`make test` keeps it green).
; the core laws are ALSO machine-checked, axiom-free, in rocq/spec.v (Rocq/Coq), wired into
; `make test` as test_proof (+ test_gen, an auto-generated rocq/gen.v from tools/spec2coq.l).
; when in doubt, this file EXPLAINS, test/spec.l PROVES (by assertion), and rocq/spec.v PROVES
; (by machine-checked theorem); either way the way to settle a doubt is to PROBE THE BINARY --
; never trust a prior over a one-line experiment. the demos show results inline (`expr ; value`).

; --- how to work here (read this first) ---
; * `make test` is the gate: host + the self-hosted bootstrap ai0, BOTH required to print
;   the zz-fin "tests pass" summary (ai0 exactly twice -- a silent reader stop exits 0
;   without reaching zz-fin, so exit code alone proves nothing). `make test_all` adds the
;   qemu kernel + tool diffs; `make valg` for memory. one file at a time: `out/host/ai
;   test/x.l` -- but the corpus runs CONCATENATED in one global scope, so keep helpers
;   local (give `:` a body) and remember single-file runs lack the assert harness.
; * gum: `make clean` nukes the out/dl downloads (ovmf/limine) -- stash them first if you
;   need the kernel tests. editing ai.h no longer needs a clean: every object deps on
;   $(ai_h) and the lcat'd headers re-lay on ai0, so incremental builds stay consistent.
; * C files EMBED lisp the .l sweeps cannot see: ai.c (g_evals_'s driver string), main.c
;   (s2cl + runner), kmain.c (the K_TEST runner), wasm/. grep them on every rename.
;   the docs EMBED rocq theorem names + ai vocab the sweeps also miss: blue.md (the
;   blue-paper source, rendered to blue.html by tools/site.l + site.css) cites
;   rocq/spec.v lemmas as `thm:name` chips, and index.html runs live demos -- grep
;   blue.md + index.html on a theorem rename or a vocab change.
; * a bare all-punct symbol mid-list captures its left operand when code compiles (the
;   opfix pass) -- escape it in parens ((+) is + as a value); GLUED to a datum it is
;   monadic instead (the valence law: space your dyadics); quoted lists are data and
;   keep their operators plain.
; * a corpus test that spawns must (wait p) its task: an orphan stalls the kernel runner.
; * the repl reads each LINE as one expression (1 = 1 answers 1); files read forms. the
;   interactive shell installs a default help when none is present (ai/bao.l shell-help):
;   a scare prints `;; a b` and answers the zero point, so the session survives every raise and a
;   missing nom or apcap is VISIBLE; the more bits keep the read protocol (port back when
;   incomplete, sentinel at eof). file mode stays helpless -- terminal, per the law.
; * python \b-sweeps treat - as a boundary: kebab names with capital segments mangle.
; * the CREW (crew/*.md) drives dev: the apps over the core -- aineko (netcat,
;   tools/aineko.l + host/net.c), bao (the shell/rlwrap/debugger, ai/bao.l + host/pty.c),
;   cook (make-in-ai, cook/cook.l), kship (the freestanding agent-kernel, port/kship/).
;   each crew/<app>.md is an AGENT BRIEF -- a personality a dedicated session is pointed
;   at, owning a NON-OVERLAPPING file territory so the sessions run in parallel. the apps
;   add nifs through the host/*.c glob + AI_NIF (no core edit); ai.c/ai.h/host/main.c are
;   CORE territory -- a crew session that needs a core change stops and asks the core
;   thread (this session), never reaches in. crew/README.md is the roster; the runnable
;   ones install on PATH via `make install`.

; --- vocabulary & house style --- the words here are a VOCABULARY -- we never say
; "terminology" or "nomenclature"; a vocabulary is living and chosen, warm not clinical.
; the house style is COZY: lowercase, plain, a touch playful, names that earn their keep
; (you eat a toast; $ keeps the green charms; a set of stars is a galaxy). we frame in the
; GREEN -- name what a value IS and KEEPS, not what it lacks; green, not red. the surface
; stays small and deliberate ((names ()) is the whole vocabulary). the celestial numerics:
; a CHARM is a fixnum (a word); a STAR is a self-netting scalar (charm/full/big/gem/twin-gem);
; a GALAXY is a set of stars (a numeric array); a CONSTELLATION is any numeric (a star or a
; galaxy) -- a charm is a star is a constellation. the global env is the `book` -- *the* book,
; the outermost one; a map is a book, a tablet a little book, and a global is "pinned in the book under <name>".
; the jewels under the star: a CHARM is a fixnum, a whole little word; a GEM is a float, the
; smooth kind that falls between the charms; a TWIN GEM is a complex, two gems paired (re, im),
; and `twin` is what pairs them.

; --- the shape of it --- one cell is one word: a fixnum is a tagged odd word, anything else
; is a heap object whose first word is its hot -- a live external reference, the wire out of
; the heap to the ap that runs it. the VM is tail-threaded (aps tail-jump, never return --
; `make vmret` checks it) over a two-space copying heap. every operation is *fully generic* --
; it dispatches on a value's *kind*, and the kinds form a lattice that is literally the
; diagonal of the dispatch tables. the C core is tiny; most of the language is ai closures
; installed reflectively from the prel, then laid into a heap image (the *egg*) at
; compile time. the gritty details sit at the bottom.

; --- the type lattice --- two axes. the *tier* spine, low to high:
;   N the green charms (the naturals, the range of $)  <  Z integers (fixnum -> wide int -> bignum)
;     <  R gems (the reals, as floats)  <  C twin gems (complex)  <  O objects (string < chain < map < top)
; (the POINTS -- mints and noms -- are not O objects; they FLOOR the total order, below string, see order below)
; numbers nest as usual (N in Z in R in C). a fixnum is a CHARM, and every value wears a COLOR --
; the order-sign of its net: GREEN nets nonnegative (what $ keeps), RED nets negative (what $
; clamps to nothing), and BLUE is green's FLOOR -- net exactly zero, kept like a green yet nothing.
; so $ passes the green and stops the red at nothing, and a value is true iff it is POSITIVE green
; (above the blue floor; blue and red both net false). the GREEN charms are N (the nonnegatives),
; the RED charms the negatives below, and 0 is the ONE BLUE CHARM -- green by sign yet blue by
; measure, the floor where green meets nothing. color spans the UNSTARS too, by the same net:
; '(1) is green, '(0)/()/""/~(0 0) are blue (every nothing is blue), '(-2 1) is red, while a box
; stays green (#0 nets 1: presence over nothing). the *rank* axis is scalar (0) vs array (>= 1, one
; per tier: arrZ/R/C/O). the total order < flattens this lattice into BANDS, the TRUE-BLUE
; order: the POINTS at the floor (() < bare mints < named syms -- mints by serial, names by
; name-lex then serial), then string, then all CONSTELLATIONS as ONE band ordered by NET
; (stars and galaxies INTERLEAVE -- a galaxy seats exactly where its net's scalar sits, a
; star below the galaxy on a net tie; representations interleave too: 1 < 1.5 < 2 whatever
; the rep), then chain < tray (object array) < map < top, each band ordered within itself
; (text and chains lexicographically, maps and tops by an alpha-invariant hash). a map has
; its own rung just under the tops, though it still acts as a lookup top for +/*/apply. so
; the points are the floor, string sits below the numbers, and a chain (a 1-D set) just below
; the general trays -- NOTE surface `<`/`=` on an array BROADCAST to a mask, so this scalar
; total order is observed through `sort` and map-key ordering, not infix `<` on a galaxy. the
; opaque hots (cask/port -- `hot?`) sit in the top band: a cask measures by content
; (zeroed -> nothing), a port is present ($out = 1, drained or not), compared by
; identity, and applying one acts like 0 (const-1). every predicate ends in `?`;
; they are enumerated below.

; --- everything is a function --- (f x y) == ((f x) y) and (f) == f, so application is just
; left-to-right currying. numbers are church numerals, a list of numbers is an exponential
; tower, and data self-applies (indexes). asserts in spec.l read INFIX -- (3 = 1 + 2) is
; ((= 3 (+ 1 2))), folding right-associatively, sound by (f) == f; the reader-operators
; section below has the rules. the two pillars:
; demo:
(0 5)                ; 1       0 is const-1
(1 5)                ; 5       1 is the identity
(0 0 x)              ; x       const of const is id: (0 0 x) = ((0 0) x) = (1 x) = x
(3 2)                ; 8       (n x) = x**n
(2 3 4)              ; 262144  the tower 4**(3**2)
(map (+ 1) '(1 2 3)) ; (2 3 4) currying *is* partial application
((/ 1 2) 9)          ; 3.0     (1/2 x) = sqrt x
(i love you)         ; 1       love is not in the book, and absence absorbs

; --- three special forms --- `:` is letrec*/sequence, `?` is cond, `\` is lambda (and, with a
; single operand, quote). everything else is a function call.
; demo:
(: a 1 b 2 (a + b))          ; 3     : binds in source order; the last form is the result
((\ x y (x + y)) 3 4)        ; 7     \ args.. body -- a lambda, auto-curried
(\ (1 2))                    ; (1 2) one operand: \ is quote, so 'x is just (\ x)
(? 0 'a (1 < 2) 'big 'else)  ; big   ? -- test/result pairs, then a final else
; `:` doubles as sequencing (bind `_` for effect); `(f x)` on the left is define-sugar; a
; body-less top-level `:` leaks its bindings to the global scope (that's how tests share helpers).
; a body-having `:` is ONE SCOPE: every name binds over the whole form, so a read before the
; pin is the MISSING CONDITION (see control) with the binding site's nom as payload -- a call for
; help, the zero point helpless; no read ever escapes to an outer binding of the same name. rebinding a name
; later in the form still reads the previous value (the sequence law); recursion among lambda
; bindings resolves lazily. an EMPTY form is its head's value -- (f) == f at zero operands --
; and the heads are missing, so (:) (?) (\) all read the zero point.
; demo:
(: (twice f x) (f (f x)))    ; defines twice; (twice inc 10) ; 12
(: x 1 x (x + 1) x)          ; 2     the sequence law: a rebind reads the previous value
(:)                          ; ()    an empty special form reads its head: the zero point

; --- true and false --- false is *nothing*: whatever NETS <= 0. every value has a net
; measure, COMPLEX-VALUED: a number is its own value -- a complex nets ITSELF, phase
; intact -- text SUMS ITS CHARMS (a string is packed chars, measured by content -- a
; NUL contributes nothing, so an all-NUL text or zeroed cask is nothing), a symbol nets
; its spelling, a list or array is the SUM of its elements' nets -- a TRUE complex sum,
; recursive and unclamped, the SPINE only (a dotted tail is not an element) -- so
; negatives cancel positives, opposite phases cancel as VECTORS (never by the order's
; tiebreak), and a CHAIN OF NOTHINGS is nothing too. the law of saturation holds at
; every rank: positive to positive, zero-or-negative to zero, so a list or array of
; negatives is nothing, exactly like a negative scalar. maps stay key-counted: presence
; is information there, and #0 must stay truthy. there is no "truthy"/"falsy" -- true
; and false are the bits 1 and 0 of the `!!$` projection. the net is OBSERVED through
; one retraction at the boundary: `!` (the nif `nil?`, the classical name; `non` is its
; normal alias) reads the net's sign in the total order (re, then im -- applied ONCE,
; never per element), and `$` (sat) is ONE saturating clamp over the net's order-signed
; magnitude, max(0, ceil), with the invariant !x == (0 = $x). `$` is the SOLE clamp, retracting
; ANY value onto the green charms, so a clamped fold is mere composition -- $*x the clamped
; product, $(prod v) the clamped reduction, no per-fold saturator (the measure is additive,
; $ its only observation). net is additive wherever
; + is total -- EXACTLY, complex included: $(a + b) saturates net a + net b over
; numbers, text, and lists alike, the byte law included (a string + a byte nets the
; byte: + is a true measure homomorphism), and the ARRANGEMENT does not matter: a
; packed complex array and the list of the same values net the same
; sum. the COUNT -- how many, not how much -- is `tally`: a string or cask counts its
; charms, a list its spine, an array its cells, a map its keys, a symbol its spelling,
; a scalar nothing. tally is what "length" always was; $ never was.
; demo:
!0  !""  !()  !0.0  !~(0 0)   ; nothing -> false
!-5  !'(-5)  !@(-3 -4)        ; net <= 0 at every rank -> false
!!5  !!"x"  !!'a  !!#0        ; positive / nonempty / a box -> true
$'(1 2 3)            ; 6       $ sums the nets, then clamps once
$@(3 4)              ; 7
+'(-2 1)             ; -1      the net is unclamped: '(-2 1) is red
(!"" = 0 = $"")      ; true    the invariant !x == (0 = $x)

; --- types & predicates --- a fixnum is a tagged word; everything else is a heap object whose
; first word dispatches. the storage predicates:
;   charm? big? full?  -- the integer reps (fixnum, bignum, wide int)
;   float? twin? set?  -- float, complex scalar, array; all three share one heap type (the internal `pack` kind)
;   string? nom? name? two? book?  -- string, point (a non-() mint or a name), named point (KNom), chain, map
; derived: `constellation?` (any number: fix/wide/big/float/complex/array), `whole?` (any integer), `atom?`
; (anything but a chain). the NUMERIC vocab refines the numbers: a STAR is a self-netting
; SCALAR (`star? x` == `id? x (net x)`: charm/wide/big/float/complex), a SET is an array of
; any kind (`set?`, the renamed arrp), and a GALAXY is a numeric set -- a set of stars
; (`galaxy?`). star? and galaxy? are DISJOINT (a set's net is a fresh scalar, so no set
; self-nets); a galaxy is COMPOSED of stars, not a kind of star -- it nets DOWN to a scalar star.
; `i` is ~(0 1). `lit?` is the TOP REGION (the upper lattice segment, ai_kind >= map): a map
; (mutable) and the tops above it -- closures, nifs, and the opaque hots -- so `hot? ⟹ lit?`.
; NOT the data leaves below (numbers, strings, points, chains, trays), so the () a missing nom
; reads is NOT lit?. the opaque hots (cask/port) answer `hot?`, the refinement that names the
; zoo; a task is referenced by a fixnum id, not a handle object. among the POINTS: `nom?` is a
; REAL point -- a non-() mint or a named nom -- and `name?` is a NAMED point alone (name? => nom?;
; the gap nom? \ name? is the anonymous mints, the gensyms). () is NEITHER: the absence stands
; apart, anonymous and empty. `!` (nil?) and `done?` are truth/task tests, not type tests.
; demo:
(charm? 5) (two? '(1 2)) (string? "hi") (nom? 'x) (name? 'x) (book? #(1 2))   ; the storage predicates
(constellation? i) (whole? (62 2)) (atom? 'x)                            ; derived
(lit? #(1 2)) (lit? cap) !(lit? "s") !(lit? '(1))           ; lit? = the top region (map/fn/hot), not data leaves
(nom? (mint 0)) !(name? (mint 0)) !(nom? ())                ; a fresh mint: a point yet anonymous; () is neither
(hot? (cask 4)) (hot? out) !(hot? cap)                       ; the hot zoo: cask/port only
((64 2) = 2 * (63 2))        ; true   fixnum overflow -> exact bignum ((k b) = b**k)

; --- arithmetic --- + - * / // % (infix, like the rest). fixnum fast path; a float makes it
; float; integer
; overflow grows fixnum -> wide int -> bignum; a non-number gives nil. `/` is *true* division --
; an inexact integer quotient promotes to float ((/ 1 2) is 0.5) but an exact one stays integer
; ((/ 4 2) is 2); 1/0 gives IEEE infinity (ieee-inf, lexed as a float -- a float token
; otherwise leads with a digit), but 0/0 gives 0: NaN COLLAPSES to the zero numeral, so
; ai's "undefined is nothing" (a type error is nil) reaches the floats -- the total order
; stays total, and 0/0 nets 0 like its value now says. inf/nan/ieee-nan are honest symbols,
; free for binding. `//` truncates toward zero (the partner of `%`).
; bitwise << >> & | ^ on integers (complement is (^ x -1)). the MONADIC readings ride
; the VALENCE LAW (see reader operators): glued is monadic -- -(f x) is neg, /4 is
; reciprocal, |x abs, %x frac -- while the sections ((- 0), (/ 1)) remain their
; word-level spellings, generic like their operators, and the numerals carry the
; power family ((-1 x) = 1/x, ((/ 1 2) x) = sqrt; see numeric functions). the two
; monoid folds are notation now -- +l is the net, *l the product -- and general
; higher-order stays words: (foldl f z l), $ = the net's charm.
; demo:
1 + 2                ; 3
5 / 2                ; 2.5     true division (an exact quotient stays integer: 4 / 2 ; 2)
(// 5 2)             ; 2       truncating quotient, partner of %
1 / 0                ; ieee-inf
(/ 0 0)              ; 0       NaN collapses to the zero numeral
8 | 4 | 2 | 1        ; 15      bitwise

; --- order & equality --- < <= > >= is a *total order over all values*: across kinds by the
; true-blue lattice (point < string < number < chain < tray < map < top -- the POINTS, mints
; and noms, floor it; a galaxy folds into the number band by its net), within a kind by value/
; lexicographic order (complex by (re,im); maps and lambdas by an alpha-invariant hash; an
; array operand broadcasts to a 0/1 mask -- so the scalar order is observed through `sort`, not
; infix `<` on a galaxy). `=` is value equality and bridges the whole
; numeric tower; `id?` is identity; for "not equal", write `!(a = b)`.
; demo:
3 = 3.0              ; true    = bridges the numeric tower
1 < 1.5              ; true
'x < "a"             ; true    the floor: point (mint/nom) < string < number < chain < map < top
"a" < 1              ; true    ... and string sits below the numbers
(show (sort (L @(2 4) 5 "s")))   ; "(\"s\" 5 @(2 4))"   a galaxy (net 6) interleaves with the stars
#(1 10) < cap        ; true    the map rung: chain < map < top
(id? 'a 'a)          ; true    id? is identity; !(id? '(1) '(1))

; --- comparing functions --- `=` on two functions is alpha + structural: their source \-exprs
; match up to renaming of bound variables (binders by position, free vars by name) and their
; captured values match pairwise. `<` agrees (the hash is alpha-invariant); `id?` stays
; identity. eta ((\ x (f x)) = f) and beta are *not* bridged -- a closure versus its operator is
; a representation-crossing edge that stays false. two exceptions cross into the numerals:
; 1 = (\ x x) (the identity) and 0 = (\ _ 1) (const-1), each up to alpha.
; demo:
(\ x x) = (\ y y)            ; true   alpha: bound vars by position
(\ x (+ x 1)) = (\ x (+ x 1)); true   ... yet distinct objects (id? false)
(\ x x) = (\ y z)            ; false  free /= bound
1 = (\ x x)                  ; true   1 is the identity numeral, up to alpha
0 = (\ _ 1)                  ; true   0 is const-1 (and only that)

; --- + and * are generic --- `+` adds numbers, concatenates strings, and appends
; lists; `-` is numeric only. the BYTE LAW: a string + a number is one byte, strictly --
; the value must be an exact integer 0..255 (rep-blind, like `=`: 66.0 is 66); anything
; else is nil, like `-` on strings. SYMBOLS LEFT THE STRING ALGEBRA (the mint round):
; + and * on a symbol are nil -- a symbol is a point with a spelling attribute, and
; intern/string are the explicit bridge, not operators. a BARE MINT is +'s IDENTITY
; on lists -- nothing adjoins nothing, so `'(3) + ()` is `'(3)` either side (the zero
; point too: it is a mint); a NAMED symbol still adjoins as an element. `*` is repeated
; `+`: a sequence times a count repeats it, and the count SATURATES (($ c), the count
; law shared with numeral-apply and array shapes): a non-positive count gives the empty
; sequence, a float ceils.
; demo:
"ab" + "cd"          ; "abcd"
"x" + 66             ; "xB"      the byte law: exact 0..255 or nil
'(1 2) + '(3 4)      ; (1 2 3 4)
5 + '(1 2)           ; (5 1 2)   + adjoins (the measure homomorphism)
'(3) + ()            ; (3)       a bare mint is +'s identity on lists, either side
"ab" * 3             ; "ababab"  * is repeated +; the count saturates

; --- numeric functions --- abs and int are type-aware; the constants are e pi i; also gcd and
; modpow. the only irreducible transcendental nifs are pow sine cosine log (float; bignums widen,
; arrays map elementwise; log and pow climb tiers -- log of a negative/complex argument gives
; the complex principal value ~((log |z|) (arg z)), and a finite negative base to a non-integer
; power gives its principal root, the angle pi*e factored exactly (sinpi/cospi), so the derived
; sqrt is total: ((/ 1 2) -1) = i). everything else is *derived* from numerals
; and complex -- no nif:
;   power (k b) = b**k    sqrt ((/ 1 2) x)    exp (x e)    nth root ((/ 1 n) x)
;   tan (/ (sine x) (cosine x))    atan (arg ~(1 x))    atan2 (arg ~(x y))
; demo:
(abs -5)             ; 5         type-aware: (abs ~(3 4)) ; 5.0
((/ 1 2) 4)          ; 2.0       sqrt, derived from the numeral
(pow 2 10)           ; 1024.0
(gcd 1071 462)       ; 21
(modpow 2 100 1000000007)    ; 976371285
e                    ; 2.718281828459045

; --- a few identities --- tetration is just the tower with one base: (3 3) = 3^3, (3 3 3) =
; 3^(3^3), (2 2 2 2) = 2^2^2^2. i*i = -1 -- the algebraic heart of euler's e^(i*pi) = -1 -- and
; e^(i*0) = 1. the textbook (-1 = i * pi e) does *not* hold forward: `=` is exact and e^(i*pi)
; carries a ~1.22e-16 imaginary residue -- cosine rounds to exactly -1.0, but sine of the nearest
; double to pi cannot land on 0, so what survives is pi's OWN representation error surfaced
; through sine (~1.22e-16 = pi - the double nearest pi). the honest price of an irrational pi in
; floats. read it backwards instead -- the principal log IS exact: atan2(0 -1) is pi by IEEE fiat and i moves
; it with exact 0/1 products, so ((log -1) = i * pi) bit-exactly. pow climbs the same way: a
; finite negative base to a non-integer power is its principal root, the angle pi*e factored
; exactly (sinpi/cospi), so ((/ 1 2) -1) = i on the nose. (i only assert what's bit-exact on
; every target: the freestanding math lib is coarser than glibc, so nothing else that pits a
; transcendental against a literal or a differently-computed transcendental.)
; demo:
(3 3)                ; 27        tetration: 3^3
(3 3 3)              ; 7625597484987
i * i                ; -1        the algebraic heart of euler
(log -1) = i * pi    ; true      euler, in the EXACT direction
((/ 1 2) -1)         ; i         sqrt of -1: principal, exact

; --- complex (the twin gems) --- a discrete scalar at the top numeric tier (twin?), two gems
; matched. the `~` reader sigil: ~(re im) builds (twin re im) (3+ operands curry); a bare ~x
; lifts a gem (~r = ~(r 0)) or conjugates a twin gem (~~(r i) = ~(r -i)), so `~` is conjugation
; and an involution. i = ~(0 1). + - * / promote a gem and stick (no demotion); order is
; lexicographic by (re,im) and `=` bridges the gems. `twin` and `arg` broadcast over arrays,
; so the derived forms stay elementwise.
; a rank-N complex array packs (re,im) into a `c`-typed array: peep yields a ~(..) box,
; + - * / broadcast numpy-style, `=` gives a mask, and net/prod fold complex. the net
; is the complex SUM of the cells, so $v = $(net v) and a packed array nets exactly
; like the list of the same values -- the arrangement does not matter.
; demo:
i                    ; ~(0.0 1.0)   i = ~(0 1)
~(1 2) * ~(3 4)      ; ~(-5 10)
(conj ~(2 3))        ; ~(2 -3)      ~ is conjugation, an involution
(re ~(2 3))          ; 2.0
(net (array 2 ~(1 2) ~(3 4)))   ; ~(4 6)   complex arrays fold complex

; --- arrays --- star-tray / gem-tray / twin-tray / top-tray are THE typed constructors,
; one per z/r/c/o tier: (star-tray shape vals) -- vals 0 zero-fills, a list fills row-major
; (the generic witness ctor `tray` underneath them is off the surface, mopped); (array
; shape elem..) infers the type and curries; @(..) is a rank-1
; literal; (iota n) is jot's array twin -- the z-array '(0 .. n-1) filled in one C loop,
; no link spine, so (net (iota n)) reduces a range end to end in C.
; a ONE-CELL array DEMOTES to its lone scalar star -- a rank-0 (empty-shape) array, a
; rank-1-len-1 like @(5), or a 1x1 contraction IS the value (so @(5) = 5, (gem-tray '(1)
; '(3.5)) = 3.5, (iota 1) = 0): an array exists only at tally >= 2. there is thus NO
; rank-0 array kind; a scalar star (charm/float/wide/complex) is the rank-0 point, and
; the array accessors (rank/tally/shape) read nil on it. EMPTIES are the exception
; (a 0-axis has tally 0, not 1): they STAY arrays, carrying the reduction units below.
; rank/tally/shape/tier; peep (out of bounds -> the default). + - * // < =
; broadcast numpy-style to the widest type
; (compare -> a z mask); `/` promotes the whole result to r the moment any element divides
; inexactly. reduce with net prod max min aall (a conjunction); CONTRACT with inner
; (+.x -- a's last axis against b's first: 1D.1D is the dot product, 2D.2D matrix multiply)
; and outer (o.x -- all pairwise products, rank ra+rb). an array nets the SUM of its elements
; ($ = max(0, ceil(net)), like a list), so an all-zero or net-negative array is false.
; sine/cosine/log/pow and the derived forms map elementwise. a 0-axis is real:
; broadcast keeps it empty (a 1-axis takes the OTHER size, 0 included), an empty
; rank-1 prints (array '(0)) (@ has no empty spelling), and EMPTY REDUCTIONS ANSWER
; THEIR MONOID UNITS -- (net e) = 0, (prod e) = 1, (aall e) true: the floor
; appears as the values of empty reductions.
; demo:
@(1 2 3) + @(10 20 30)   ; @(11 22 33)   broadcast numpy-style
@(1 2 3) * 2             ; @(2 4 6)
(net @(10 20 30))       ; 60
(iota 3)                 ; @(0 1 2)      the z-array 0..n-1
(inner @(1 2 3) @(4 5 6)); 32            +.x dot product
(net (star-tray '(0) 0)) ; 0            empty reduction = the monoid unit

; --- chains & lists --- link builds the chain (the cartesian-product kind, classically the
; pair); cap and cup are its two projections -- the matched pair the string diagrams bend,
; cap the head and cup the rest, each the other's mirror (no cap: you have reached the end
; of the list); caap caup .. cuuup are the compounds, read right to left like their classic
; c[ad]+r ancestors -- the lineage runs cap/cup <- cap/cbp <- car/cdr, the older names gone
; now, as is the X alias.
; (sort l) orders by the total order, in C (descending = rev); (msort le l)
; takes a predicate. (jot n) counts out the first n charms, '(0 .. n-1).
; the other higher-order functions live in the prel.
; demo:
(cap '(1 2 3))       ; 1
(cup '(1 2 3))       ; (2 3)
(map inc '(1 2 3))   ; (2 3 4)
(foldl (*) 1 '(1 2 3 4))     ; 24
(sort '(3 1 2))      ; (1 2 3)
(jot 3)              ; (0 1 2)   the first n charms

; --- strings, symbols & mints --- a symbol is interned ('x): one canonical atom per
; spelling. a MINT ((mint 0), arg ignored) adjoins a fresh POINT to the value space:
; nameless, materially empty ($mint = 0, false), applying as every unit does (const-1),
; identity its only property -- the unforgeable thing. a NOM is a NAMED point -- its OWN
; kind (KNom: a spelling + a serial), NOT a chain -- so `(nom "x")` is a fresh uninterned
; named atom, McCarthy's symbol restored as its own atom; `intern`/`'x` give the canonical
; one per spelling, and `(string nom)` reads the name back. `()` reads as 0 -- nothing's plain spelling --
; and (intern "") is 0: the empty spelling names nothing. ABSENCE is another
; matter: a helpless missing read answers the ZERO POINT, the mint at serial 0 --
; nameless, $0, false, printed as () (the face of absence; like any point, no
; spelling carries it back), and a UNIT: it absorbs application where a number
; would exponentiate, which is what keeps (1 = (i love you)). every mint draws a SERIAL
; from the one mint stream (task pids draw from it too): symbols order by name first
; (mints below every named symbol), then by serial -- creation order -- so the total
; order is TOTAL, GC-stable; the serial is also the point's hash. a NOM carries a name +
; a serial in its own cell (KNom): it orders by (name lex, then serial), stays identity-sharp
; by serial, and makes distinct map keys for free -- no chain, no special-casing. SYMBOLS
; HAVE NO STRING ALGEBRA (+/* nil, apply const-1); intern and string are the explicit
; bridge, and a nom's name is (string nom).
; a string indexes its bytes ("abc" 0 -> 97). $ (sat) clamps the net measure once,
; max(0, ceil(net)): a string's CHARM SUM, a symbol's spelling sum, a number's own value
; ($-3.9 = 0), a list's or array's element sum -- so $ and abs diverge ((abs -5) = 5 but
; $-5 = 0, and $@(3 4) = 7 where (abs @(3 4)) is the norm 5). the count is tally.
; snip takes a half-open snip; + concatenates ("" is the identity); string makes text of
; any value; \n escapes.
; demo:
()                   ; 0           nothing's plain spelling; (intern "") ; 0
(intern "asdf")      ; asdf
(string 'asdf)       ; "asdf"      the explicit bridge (symbols have no string algebra)
("abc" 0)            ; 97          a string indexes its bytes
(mint 0)             ; $<serial>   a fresh nameless point ($(mint 0) ; 0); the $face is diagnostic, not a reparse
(string (nom 'x))    ; "x"         a nom is a named point (KNom), not a chain; read its name with string

; --- hashes --- #(k v ..) or (hash ..) build; the empty hash is (tablet 0) (and prints so);
; mutable. a map is a BOOK -- a tablet is a little book, and `the` book is just the
; outermost one. # on any non-list datum BOXES it: #x = #(0 x), a fresh mutable hash
; pinning x at 0 (a 1-entry box, truthy) -- and () IS 0, so #() is #0, the box of
; nothing: the # law has no empty exception. the accessors are
; collection-first: (peep coll k default) reads, (pin coll k v) sets, (pull coll k default) removes-
; and-returns. peep and pull share the default-if-absent fallback; only pull mutates a key away.
; also keys (the key list), $ is the key count. (t k) == (peep t k 0) -- a map is a lookup
; function. THREE ABSENCE LANES, one miss machinery: peep (the caller names what absence
; means), apply (absence is 0), and (missing t k) -- the book read as a value: a present k
; answers, a miss is the missing condition (the help's result, the zero point helpless, k the payload).
; (dig k) digests any key to a fixnum. a hash is MUTABLE, so `=` on hashes is
; identity (like buffers); infix, the accessors are (t <- k v) and (t -> k d).
; demo:
(book? #())                   ; true   #() IS #0, the box of nothing (present)
$#(1 10 2 20)                ; 2      $ is the key count
(peep #(1 10 2 20) 2 0)      ; 20
(#(1 10 2 20) 2)             ; 20     a map is a lookup function: (t k) == (peep t k 0)
(missing #(1 10) 1)          ; 10     the conditioned read; a miss is the missing condition
(: t #(1 10) _ (t <- 4 40) (t -> 4 0))   ; 40   the infix accessors

; --- casks --- (cask n) gives n mutable zeroed bytes; peep/pin a byte (0..255); $ nets
; the charms (a zeroed cask is nothing); pour; identity equality.
; demo:
(: b (cask 3) _ (pin b 0 65) (peep b 0 0))   ; 65
$(cask 4)             ; 0       a zeroed cask is nothing
(tally (cask 4))      ; 4       tally counts the bytes

; --- reader operators --- `;` line comment, `#!` pinbang (no block comments). reading is
; STRUCTURAL and environment-free: the reader knows tokens, parens, strings, and the value
; surface -- ' quote (= one-operand \), ` list (the element-eval ctor), # hash, @ tup
; (array), ~ twin (complex/conjugate: ~(re im) splices to (twin re im), a bare ~x is
; (twin x)) -- and NO operator tables, so the same reader serves data (read) and code.
; the LEXER LAW splits tokens by leading char: a name token (alnum/_) keeps - ? ! etc
; inside (kebab law) AND a trailing/internal ' (the prime: a', n'' -- a LEADING ' is still
; quote, dispatched before the name sounder), while a punctuation-led token is a SIGIL -- a maximal run
; of operator chars (value-surface chars and delimiters break the run), read as ONE PLAIN
; SYMBOL when spaced, or fused to its datum as (mono (run datum)) when GLUED mid-list
; (the valence law below; head position and \ never fuse, - and + only to ( ' " @ ~ #).
; code then factors sigils against the ONE `operators` table at COMPILE time:
; `opfix`, a source->source prepass hooked by both compilers (c0 probes book['opfix] like
; boxfix; ev runs it before wev -- ev is opfix after read, so the two input lanes, data
; and characters, meet at one core). the table: symbol -> arity (the symbol names itself)
; | (name . arity) (an alias), arity 1-7, extended with a plain pin -- live for the next
; form, since opfix probes at compile time (see test/operator.l, test/infixop.l).
; the FACTORIZATION LAW: greedy longest-prefix, no backtracking; every factor but the
; last must be arity ONE (a prefix on the next datum, never capturing left); the
; last factor takes the positional valence -- with a left operand it captures it and
; collects arity-1 more, nesting RIGHT-associatively; with none it reads plain, so
; (+ 1 2), '+, and (+)-as-a-value still work. a token that doesn't factor is a plain
; symbol (&&, >>=, :-, ?- stay atomic); != factors to ! and =, !! double-negates. a
; sigil at one binds TIGHTEST (folds the moment its operand lands), so $"ab" + 2 is
; (+ ($ "ab") 2) = 197; only infix defers, which is what makes it right-associative. the
; CURRY LAW: operands missing at the end of a list fold to the partial application.
; quote interiors are DATA -- operators inside ' stay plain symbols. shipped at one:
; $ sat, ! nil?, . dot; at two: + - * / %
; = < <= > >= | &; ? at three -- the cond form infix, (t ? a b); aliases: <- pin and
; -> peep, collection-first -- (t <- k v) pins (giving back t, so it chains), (t -> k d)
; peeps. (1 + 2) factors to ((+ 1 2)) and evaluates via (f) == f.
; the VALENCE LAW: every operator is two operators -- GLUED IS MONADIC, SPACED IS
; DYADIC. a run glued to a following datum reads as (mono (run datum)) (a plain list,
; so data round-trips); opfix factors the run greedily against `monadics` (then the
; operators table at one, so live pins keep the dynamic lane), all factors monadic --
; <>x is (cap (cup x)). HEAD POSITION NEVER FUSES: a run right after an open delimiter
; is the form's operator (the section/escape law, and what keeps minified source
; legal); + and - lead numbers and kebab names, fusing only to ( ' " @ ~ # -- so -3 is
; a number and -x a name, while -(f x) is neg. the monadic words: < cap, > cup
; (<< >> <> >< the compounds, riding the shifts' free slots), + net (the content
; measure -- the true sum, + turned inward), * prod, | abs, - neg, / recip, % frac,
; ? bit (the Iverson bracket); $ ! . ride the same lane. \ never fuses (form space).
; demo:
1 + 2 * 3            ; 7       infix, right-associative
$"ab" + 2            ; 197     a sigil at one binds tightest: (+ ($ "ab") 2)
(1 +) 2              ; 3       the curry law: (1 +) folds to (+ 1)
<>'(1 2 3)           ; 2       glued runs are MONADIC: (cap (cup x))
+'(1 2 3)            ; 6       +/ the net, unclamped
(monadics '<)        ; cap

; --- macros --- a macro maps an argument list to code; install with `::`. the prel ships
; do/let/if/cond/quote, && and || (short-circuiting), L/list, tuple/map/array, the body-first
; :- and ?-, and the pipes >>= <=<.
; demo:
(:: 'unless (\ a `(? ,(cap a) 0 ,(caup a))))   ; install a macro; (unless 0 'ok) ; ok
(&& 1 2 3)           ; 3       short-circuiting; (&& 1 0 3) ; 0
(|| 0 2 3)           ; 2
(let a 1 b 2 (a + b))            ; 3
((<=< inc (\ x (x * 2))) 4)      ; 9   the pipe

; --- control --- ev compiles and runs; call-cc is a one-shot escape; tasks are
; spawn/wait/yield/sleep/done?/hush/key?; the RNG is xoshiro256++: C ships only rng-seed and
; the pure rand-next/randf-next over explicit state -- the global rand/randf stream is
; prel lisp over hidden rng state. a global `help` function receives every
; raise as (help s a b) -- s = the status word, two bits: scare (1, something wrong) and
; more (2, read control flow); more alone = incomplete, eof = more|scare. a/b = the
; condition data; the result is delivered per the bits (the more bit: to the reader's
; resume; a bare scare: observed). scare?/more?/eof? read s. `welp` is the FLOOR
; HANDLER -- help that has given up: it keeps the read protocol (eof -> the sentinel,
; more -> the port back) and answers the zero point on a bare scare, the fromempty the
; introductions (scare, missing) never named -- from any condition, a value. a policy
; that runs out of cases delegates to it ((\ s a b (? (mine? a) .. (welp s a b)))), and
; the shell's default help is welp WITH A FACE (it prints `;; a b` first, then welps).
; help is present the way
; everything is present: by its net ((: help 0) uninstalls). (scare a b) raises
; deliberately -- the scare bit set unconditionally, and the help's result comes back
; as its value (no help installed -> terminal: the exit face prints `;; a b`, show
; forms, from the condition data stashed at the raise -- the bare data-less scare,
; oom, prints ;; oom@len instead). see test/help.l. a nom not
; in the `book` (the global table) is MISSING -- a call for help: reading one raises
; (scare 'missing nom) under an installed help (the help's result is the value); helpless
; it reads the zero point -- a nameless unit. the read happens where the code says it does:
; a closure captures its free globals at creation, so a missing read in a lambda body fires
; the condition at the define, not the call. see test/missing.l. THE CONDITION IS ONE LAW
; AT EVERY DEPTH: a `:` binding read before its pin raises it with the binding site's
; nom as payload (one scope, see the special forms), (missing t k) raises it for a miss on
; any tablet (k the payload), and an empty special form reads its head -- the same missing.
; numeral counts are
; CAPPED: a compose count or exact-power exponent above the `apcap` box (a public
; runtime tunable, default 2^20) raises (scare 'apcap k) instead of allocating O(k) --
; (bignum f) asks for help where it would oom. retune with (pin apcap 0 n); see test/apcap.l.
; demo:
(ev '(+ 1 2))                ; 3
(call-cc (\ k (k 41)))       ; 41   a one-shot escape
(: p (spawn (\ x (x + 1)) 41) (wait p))   ; 42   tasks (always wait an orphan)
(apcap 0)            ; 1048576   the count ceiling, a tunable box
not-in-the-book      ; ()        a missing nom reads the zero point (helpless)
(welp 1 'a 'b)       ; ()        the floor: a bare scare welps to the zero point

; --- i/o & ports --- `in`/`out` are the default ports; the prel wraps getc and
; putc/puts/putn/putx, with per-port get/put/.../read plus open/close/sip/pad/slurp.
; `read` (the renamed fread) is port-first -- (read in x) -- and reads one datum per
; call; its end conditions route through the help continuation via
; the status more bit, and the default help delivers a sentinel at EOF, the port back when
; incomplete (a global `help` function takes over that dispatch). `dot` (the `.` operator)
; prints x to `out` -- raw bytes for a string, else the show form -- and returns
; x, so .x taps a value mid-expression.
; demo:
(slurp (sip '(104 105)))     ; "hi"
(read (sip '(49)) 99)        ; 1      one datum per call
(read (sip 0) 'eof)          ; eof    the sentinel at EOF
(. 42)                       ; 42     prints "42" to out, returns x -- a tap

; --- bootstrapping --- the C core is minimal; the key semantics are l closures installed
; from the prel and shared by both compilers:
;   numap -- fixnum/number application (x**n, or compose ($ n) times), an n-fold text.
;   add/mul -- `+` and `*` of functions are church add and compose, so numerals agree.
;   opfix -- the operator factor pass (see reader operators above): sigil surface -> core
;     source, run FIRST, one source of truth shared with the C bootstrap compiler.
;   boxfix -- the letrec* "capture by location" rewrite (one scope): a forward-referenced
;     binding indirects through a CELL, a fresh tablet keyed by the binding site's nom --
;     pin fills it, (missing cell 'nom) reads it, so a pre-fill read IS the missing condition.
;     a wev source pass run after macroexpansion, one source of truth shared with the C
;     bootstrap compiler; it emits nif VALUES (pin/missing/tablet), immune to shadowing.
;   wev -- the source->source pre-pass before analysis: expand macros, apply boxfix, fold pure
;     globals, mark apply strategy, and flip (? !e a b) to (? e b a).
;   maps -- #(..)/map expand to nested pins; a map is a lookup function.
; the *egg* (ai/egg.l): you WARM the egg (the quoted prel+ev corpus) and the evaluator SITS
; on it twice -- compile the compiler with the C bootstrap, recompile the whole corpus through
; itself -- then the hatchling installs as `ev` in the image at C compile time, no allocation;
; `born` records the hatch time (unbound pre-egg: ai0's first corpus pass runs PRE-egg, and an
; unbound nom is missing, reading the zero point). just before it is born the egg MOPS UP every runtime-
; internal nom: the raw cell nifs (peek poke seek spin -- (spin 2 3) is a segfault, big
; scare; spin is still there for real, it's ultimate), the compiler's machinery
; (boxfix, wev, the num-ap and array-ctor helpers, the macro expanders -- the macro TABLE
; lives on inside the compiler's closures), every hot lvm_* pointer,
; and finally the `book` itself. compiled references were folded, so only the noms die.
; noms the printer, the reader, or an expander EMITS (spread link pin
; tablet mono list ..) stay, as do the C-resolved hooks (num-ap add mul help). the shell
; core (ai/bao.l) no longer needs mopping: its editor + repl internals are
; closure-private (off the book by construction), and only its entry points --
; shell/welp/edraw/wrap/bao + the stream shell zev/zevs -- are globals (the `char`
; colist lift is closure-private inside zev now).
; demo:
(lit? ev)            ; true    ev is installed in the image
born                 ; a fixnum (the hatch time) post-egg; unbound pre-egg
macros               ; ()      mopped up after birth -- off the book, so the nom reads nothing

; --- under the hood --- a generic op dispatches on a value's kind (an enum whose order is the
; lattice above). an op at two is an NxN table indexed by the two kinds; an op at one is its
; diagonal; the three core tables are + , * , and apply. a both-fixnum fast path skips the
; table; otherwise one indexed jump picks a lane that widens only as far as the operands need
; (array, complex, bignum, float, ...). the VM is tail-threaded over a two-space copying
; collector; out-of-pool constants are immortal. the ai/ layer (prel ev bao cli egg) drips
; into every frontend: the host (out/host/ai), the freestanding kernel (x86_64/aarch64),
; and wasm. build codegen lives in ai under tools/; the C is
; freestanding, -Wall -Wextra -Werror.

; --- odds & ends --- show renders a value as its reparsable printed form; (clock t) is
; milliseconds since t and (gauge 0) reports a VM stat. an opaque handle acts as a constant
; function -- applying it ignores the argument.
; demo:
(show @(1 2 3))      ; "@(1 2 3)"   the reparsable printed form
(clock 0)            ; a fixnum (ms)
((cask 4) 'x)        ; 1            an opaque handle is a constant function
```
