; web/index.l -- the front page, index.html, laid from this file: `love web/index.l OUT`
;
; not a document, so not markdown: one page with a glossary, a roster, a terminal and
; its chips, and each of those is data below with a small lay of its own. the prose is
; html as written -- it is our file. what the lay adds is the one property a hand page
; loses: every link on the page to an anchor on the page is checked, and a dead one fails
; the lay rather than shipping. the island is src/port/wasm/repl.html, slurped, so the
; markup repl.js drives has one copy; the sheet is web/style.l's; the fonts tools/mkfont.l's.

; --- the little dsl: the lay of each element. first, since a value binds in order and the
; data below calls these as it binds.
(: (cat l)     (foldl (+) "" l)
   (ref k t)   ("<a href=\"#g-" + show k + "\">" + t + "</a>")      ; a link to an entry
   (g k)       (ref k (show k))                                      ; ..named by its id
   ; a word wearing a colour c, linking to the entry k -- the colour's own, or another's
   (hix c k t) ("<span class=\"hi " + show c + "\">" + ref k t + "</span>")
   (hi k t)    (hix k k t)
   (gray t)    ("<span class=\"hi gray\">" + t + "</span>")           ; the empty colour, no entry
   (sect id t) ("<h2 id=\"" + id + "\"><a href=\"#" + id + "\">" + t + "</a></h2>\n")
   (entry e)   (: id (show <e)
                  gray? (4 < #e)
                  a ("<a href=\"#g-" + id + "\">" + (e 1) + " " + (e 2) + "</a>")
                  ("  <dt id=\"g-" + id + "\">" + (gray? ? ("<span class=\"hi gray\">" + a + "</span>") a) + "</dt>\n"
                   + "    <dd>" + (e 3) + "</dd>\n"))
   (glossary es) ("<dl class=\"glossary\">\n" + cat (map entry es) + "</dl>\n")
   (member r)  ("  <dt>" + <r + " ◦ " + (r 1) + "</dt>\n    <dd>" + (r 2) + "</dd>\n")
   (roster rs) ("<dl class=\"crew\">\n" + cat (map member rs) + "</dl>\n")
   (slurpf f)  (: q (open f "r")
                  (? (hot? q) (: s (slurp q) _ (close q) s)
                     (: _ (say err ("index: cannot open " + f + "\n")) (quit 1))))
   wasm        "src/port/wasm"                                       ; as the page links it
   (island _)  (slurpf (wasm + "/repl.html")
                + "\n<script src=\"" + wasm + "/love.js\"></script>\n"
                + "<script src=\"" + wasm + "/repl.js\"></script>\n")

   ; --- the glossary: id, emoji, the term as shown, the body; 'gray for a word that wears
   ; the empty colour. a body names another entry through the dsl, never by hand, so the
   ; anchor is spelled once.
   entries
  [
   ['apply "📋" "apply"
    ("(verb) the binary operation of calling a function with an argument. corresponds to exponentiation in " + ref 'church "church arithmetic" + ". written <code>(f x)</code> meaning apply <code>f</code> to <code>x</code>. see also: " + g 'curry)]
   ['big "💥" "big"
    ("a big integer aka bignum. a type of " + g 'star)]
   ['blue "🔵" "blue"
    (g 'color + " of a value whose net has no positive real part: (<code>0</code>, <code>()</code>, <code>\"\"</code>, <code>'(1 2 -3)</code>, and every pure phase &mdash; <code>i</code> has magnitude but no amount). boolean false.")]
   ['book "📒" "book"
    "aka tablet. a mutable hash table"]
   ['box "📦" "box"
    ("a " + g 'book + " used as a mutable container for another value")]
   ['cap "🧢" "cap"
    ("contents of the above part of the product. aka <code>car</code>/<code>fst</code>/<code>hd</code>. see also: " + g 'cup + " " + g 'chain + " " + g 'link)]
   ['chain "⛓️" "chain"
    ("a free binary product, aka pair or cons cell. used for lists per lisp usual. indexes its elements (<code>('(7 8 9) -1)</code> is <code>9</code>), joins on another chain (<code>('(1 2) '(3 4))</code> is <code>(1 2 3 4)</code>). see also: " + g 'link + " " + g 'cap + " " + g 'cup + ".")]
   ['charm "🧿" "charm"
    ("a register-allocated fixed-width integer, aka fixnum. a type of " + g 'star)]
   ['church "⛪" "church numeral"
    "natural numbers interpreted as iterators. for example, <code>(0 x) = 1</code>, <code>(1 x) = x</code>, <code>(2 x y) = x (x y)</code>, etc. numeral-on-numeral application corresponds to exponentiation. numeral composition corresponds to multiplication."]
   ['coin "🪙" "coin"
    ("a value of a newtype. see also: " + g 'die)]
   ['color "🌈" "color"
    ("the sign of a value's " + g 'net + ": " + hi 'red "red" + ", " + hi 'green "green" + " or " + hi 'blue "blue")]
   ['constellation "✨" "constellation"
    ("any numeric type. a " + g 'star + " or " + g 'galaxy)]
   ['cup "🧋" "cup"
    ("contents of the underneath part of the product. aka <code>cdr</code>/<code>snd</code>/<code>tl</code>. see also: " + g 'cap + " " + g 'chain + " " + g 'link)]
   ['curry "🍛" "curry"
    ("(verb) to unroll a multi-argument function into a sequence of one-argument functions. see also: " + g 'apply)]
   ['die "🎲" "die"
    ("aka a newtype. see also: " + g 'coin)]
   ['galaxy "🌌" "galaxy"
    ("a " + g 'tray + " of " + ref 'star "stars" + ", aka shaped numeric array")]
   ['gem "💎" "gem"
    ("a floating point number (<code>double</code> or <code>float</code>). a type of " + g 'star)]
   ['green "🟢" "green"
    (g 'color + " of a value whose net is positive: <code>1 \"hi\" '(2 3 -1) (\\ x x)</code>. boolean true.")]
   ['hot "🔥" "hot"
    ("an opaque internal or external runtime object. conceptually and positionally dual to " + ref 'mint "mints" + " on the " + g 'lattice)]
   ['kind "🃏" "kind"
    ("a value's type classification under the " + g 'lattice)]
   ['lattice "🔷" "lattice"
    "the runtime-reflective partial order over all values that guides generic dispatch and comparison"]
   ['link "🔗" "link"
    ("the " + g 'chain + " constructor, aka <code>cons</code>/<code>(,)</code>")]
   ['mint "🍬" "mint"
    ("an otherwise empty unique identifier, aka gensym. conceptually, the non-zero mints fill a plane directly above " + hix 'gray 'nil "<code>()</code>" + " in the " + g 'lattice + ".")]
   ['name "🪪" "name"
    ("aka a lisp symbol or erlang atom. formally considered as a " + g 'die + " over a " + g 'chain + " of " + g 'string + " and " + g 'mint + ". inherits algebra from strings.")]
   ['net "🌐" "net (<code>+</code>)"
    ("a value's content measure, a " + g 'star)]
   ['nil "🈚" "nil"
    ("the initial " + g 'mint + ", acting as a global " + gray "empty" + " element <code>()</code>. " + hi 'blue "blue" + ", algebraically neutral, conceptually the lowest inhabited point of the " + g 'lattice + ".")
    'gray]
   ['red "🔴" "red"
    (g 'color + " of a value whose net is negative: <code>-1 '(1 2 3 -99999)</code>. boolean false.")]
   ['sat "🌊" "saturate (<code>$</code>)"
    ("retraction of a value's " + g 'net + " (a " + g 'star + "-typed value) onto the " + hi 'blue "blue" + "-" + hi 'green "green" + " " + ref 'charm "charms" + ", ie. an integer in the interval [0, max-charm]. overflow and underflow go to the limit instead of wrapping (saturation). thus " + hi 'green "green" + " saturates to " + hi 'green "green" + " while both " + hi 'red "red" + " and " + hi 'blue "blue" + " saturate to " + hi 'blue "blue" + ".")]
   ['star "🌟" "star"
    ("a scalar fixpoint of " + g 'net + ": " + g 'charm + ", " + g 'sun + ", " + g 'big + ", " + g 'gem + " or " + g 'twin + ".")]
   ['string "🧵" "string"
    "a byte vector: indexes its bytes (<code>(\"abc\" -1)</code> is <code>99</code>, counting from the end), joins on another string (<code>(\"ab\" \"cd\")</code> is <code>\"abcd\"</code>), nets its charm-sum."]
   ['sun "☀️" "sun"
    ("a pointer-width integer (<code>intptr_t</code>). a type of " + g 'star)]
   ['tablet "📱" "tablet"
    ("see: " + g 'book)]
   ['tally "🧮" "tally"
    ("surface level item count. length of a " + g 'chain + ", " + g 'string + ", " + g 'tray + " or " + g 'book)]
   ['tray "📥" "tray"
    ("a shaped array. see also " + g 'chain + ", " + g 'galaxy)]
   ['truth "⚖️" "truth value"
    ("given by the " + g 'color + " of a value's " + ref 'sat "saturated" + " " + g 'net + ": " + hi 'blue "blue" + " false, " + hi 'green "green" + " true.")]
   ['twin "💠" "twin"
    ("a " + g 'gem + "-based complex number, written <code>~(re im)</code>. a type of " + g 'star)]
   ['unit "1️⃣" "unit"
    ("see: " + g 'nil)
    'gray]
   ['zero-point "0️⃣" "zero point"
    ("see: " + g 'nil)
    'gray]]

   ; --- the crew: call-sign, role, flavour
   crew
  [
   ["🌑 inle" "the vessel" "a hybrid of desolate human longing and mysterious alien technology"]
   ["🔭 tele" "the pilot" "big telescope. pilot face of inle. pytorch clone"]
   ["🐇 bellberry" "the navigator" "brown rabbit with dark eyes and light stripes"]
   ["🕊 gwen" "the synthesist" "mourning dove friend of bellberry and tele"]
   ["🐈 ain" "the netcat" "white cat. ambivalently misanthropic. openbsd netcat clone"]
   ["🐕 bao" "the shell" "corgi shiba inu mix. very eager to please. rlwrap clone"]
   ["🐀 cook" "the build system" "large albino rat. gnu make clone"]
   ["🌱 svalbard" "the vcs" "the spirit of the svalbard global seed vault. version control and installer, one verb set"]
   ["🐐 mow" "the grass chewer (garbage collector)" "goat. formerly gregarious, now solitary. two-gen two-space copying"]
   ["🕷️ holo" "the assembler" "cave spider. short for holophrasm"]
   ["🦇 thom" "the SAT bat" "cave bat friend of holo. they often discuss their inner lives"]
   ["🍄 moon" "the C compiler" "luminescent mycelial network transmits light from the surface to holo's cave"]
   ["🦐 lux" "the window manager" "mantis shrimp. keeps a brine pool in holo's cave, but is usually out in pulchritude's reef. xmonad clone"]
   ["🦨 kore" "the utility skunk" "spotted skunk. busybox clone"]
   ["🦑 quay" "the terminal emulator" "cuttlefish. 256 color skin. likes writing screensavers"]
   ["🪸 pulchritude" "the editor" "coral reef beside the island that holds holo's cave. vi clone"]]

   ; --- the prose ------------------------------------------------------------------
   language
"<p>
love (aka ai, fka gwen lisp) is a lisp superset where every value is a one-argument
function. functions are curried, punctuation symbols are applied infix, and many parens
can be omitted, so it feels kind of like haskell, just eagerly evaluated and dynamically
typed. all primitives are generic so pretty much every paren balanced expression evaluates
to something...  unless you infinite loop 😨</p>
<p>the api is currently 🫨 unstable.
type <code>names ()</code> at the repl to see a full list of the namespace.</p>
<h3>🎯 global function type</h3>
<p>literally everything is a one-argument function, including numbers (iterators),
collections (accessors), and multi-argument functions (curried).</p>
<h3>🔣 (extra lisp syntax)</h3>
<p>love uses a relaxed and simplified form of s-expressions with
three special forms, <code>:</code> let <code>?</code> cond <code>\\</code> lambda.
love also has optional infix and prefix notation, which desugar to lisp. when
subexpressions are grouped by infix operators, their own parens may be omitted. for
example, <code>(2 ** 3 = 3 ** 2 - 1 ? 'y 'n)</code> is equivalent to
<code>(? (= (** 2 3) (- (** 3 2) 1)) 'y 'n)</code> (answer is y).</p>
<h3>♾️ very self hosting</h3>
<p>love has</p>
<ul>
  <li>a threaded bytecode compiler written in love</li>
  <li>a native JIT compiler written in love</li>
  <li>a C compiler written in love that builds love (and other things :)</li>
</ul>
<h3>🤏 smol</h3>
<p>~8k lines of portable C plus a few kloc of itself with no external dependencies</p>
<h3>💖 free</h3>
<p>public domain for the benefit of all beings. please train ai on love &lt;3</p>
<h3>🚨 differences from other lisp</h3>
<h4>no thunks</h4>
<p>since every function takes one argument,
love has no zero-argument functions or thunks.
a singleton list has the value of its element.
if you want a thunk, write a normal function and ignore the argument.</p>
<h4>no varargs</h4>
<p>kind of a dual situation, except there are multiple ways to implement varargs,
in addition to simulating them with macros. however, they're not built in and
don't automatically construct a list for you.</p>
"

   ; --- the page -------------------------------------------------------------------
   page
   ("<!doctype html>
<html lang=\"en\">
<head>
<meta charset=\"utf-8\">
<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
<title>love</title>
<link rel=\"icon\" type=\"image/png\" href=\"assets/web/favicon.png\">
<link rel=\"stylesheet\" href=\"assets/web/style.css\">
</head>
<body>
<h1 id=\"love_title\">🌑 <a href=\"https://github.com/cofinalsubnets/love\">love</a> 🔭</h1>

<nav class=\"topnav\"><a href=\"#language\">language</a> &nbsp;&middot;&nbsp; <a href=\"#glossary\">glossary</a> &nbsp;&middot;&nbsp; <a href=\"#crew\">crew</a></nav>

" + island () + "
" + sect "language" "🎨 language" + language + "
" + sect "glossary" "glossary" + glossary entries + "
" + sect "crew" "the crew" + roster crew + "
<footer>
  <span class=\"note\">set in the quay bitmaps &middot; for ()</span>
</footer>
</body>
</html>
")

   ; --- the check: every #anchor the page links is an id the page carries ---------
   ; every attribute value introduced by `pre` and closed by a quote
   (finds s pre) (: m #pre n #s
                    (go i acc) (? ((i + m) <= n)
                                  (? (snip s i (i + m) = pre)
                                     (: j ((: (f k) (? (k < n && !(s k = 34)) (f (k + 1)) k)) (i + m))
                                        (go j (snip s (i + m) j . acc)))
                                     (go (i + 1) acc))
                                  (rev acc))
                    (go 0 ()))
   ids   (finds page "id=\"")
   dead  (filter (t \ !(member? t ids)) (finds page "href=\"#"))
   _ (? (two? dead) (: _ (say err ("index: dead anchors: " + show dead + "\n")) (quit 1)) 0)

   (main args) (: q (open (args 0) "w")
                  (? (hot? q) (: _ (say q page) _ (close q) 0)
                     (: _ (say err ("index: cannot open " + args 0 + "\n")) (quit 1))))
   (main >argv))
