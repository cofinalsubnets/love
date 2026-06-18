# ai blue paper

*The companion to the narrative. Where [CLAUDE.md](CLAUDE.md) explains and [README.md](README.md) pitches, this document states the laws as propositions and points each one at its evidence: the executable spec [test/spec.l](test/spec.l) (every claim assert-backed, green on every target) and the machine-checked theorems in [rocq/spec.v](rocq/spec.v) (axiom-free, in universe-checked Rocq). Theorem names below in `thm:green` are the actual lemmas in that file; you can step them.*

## 0 · abstract {#abstract}

ai is a fully-curried, dynamically-kinded language whose entire surface is one operation — **application** — over a single generic core. There are no separate "primitives" in the usual sense: a number, a string, a list, an array, a complex scalar, a hash, and a closure are all *operators*, total functions of their own kind, and `(f x)` dispatches on the kind of `f`. From this one idea the language derives Church numerals that are also integers, arrays, and iterators; a notion of truth that is a *measure* rather than a tag; a total order over every value; and an equality that bridges the numeric tower and decides α-equivalence of closures.

This paper develops the semantics in the order the core itself is built: combinator → absence → measure → order → generic algebra → tower. Three claims recur and are worth stating up front:

1. **One law, many faces.** A church numeral `n` is a single operator. On a numeral it exponentiates (`(n x) = xⁿ`); on a function it iterates (`(n f) = fⁿ`); these are the same map dispatched on the argument's kind (`thm:lanes_agree`).
2. **False is nothing, and nothing is measured.** Every value has a complex-valued **net**. A value is false iff its net is ≤ 0 in the total order. The sole observation of magnitude is one saturating clamp `$`, and `!x ≡ (0 = $x)` exactly (`thm:nilp_iff_sat0`).
3. **The type lattice *is* the dispatch structure *is* the total order.** The kinds form a lattice; the generic operators are N×N tables indexed by two kinds; the lattice is the diagonal of those tables; and the enum order of the kinds is the cross-kind total order (`thm:lt_trichotomy`, `thm:le_total`).

**Scope of proof.** The combinator / numeral / absence / measure / order / algebra core is machine-checked in [rocq/spec.v](rocq/spec.v) over exact integers. The transcendental floats are demonstrated in [test/spec.l](test/spec.l) but deliberately outside the Rocq slice; §10 says exactly where the line is, and why.

## 1 · the combinator core {#core}

Application is left-associative and nullary application is identity:

> **(1.1) Currying.** `(f x y) = ((f x) y)`. Evidence: `thm:curry`.

> **(1.2) Empty form.** `(f) = f` — a form with no operands is its head. Evidence: `thm:empty_form`.

These are definitional in the spine model: `spine f [] = f` and `spine f [x;y] = app (app f x) y`. (1.2) is not a convenience; it is load-bearing for the reader (`'x` is `(\ x)`, `(+)` is `+` as a value) and for the special forms (an empty `(:)`, `(?)`, `(\)` each read their head — see §2).

A **numeral** is an operator defined by a single equation:

> **(1.3) The numeral law.** `(n x) = xⁿ` for a numeric argument `x`. Equivalently `app n x = Nat.pow x n`.

Every familiar numeral fact is a corollary, *proved from this one definition*:

| claim | reading | theorem |
|---|---|---|
| `(0 x) = 1` | 0 is const-1 (`x⁰ = 1`) | `thm:const_one` |
| `(1 x) = x` | 1 is the identity (`x¹ = x`) | `thm:identity` |
| `(0 0 x) = x` | const of const is id | `thm:const_of_const` |
| `(3 2) = 8` | `2³` | `thm:pow_3_2` |
| `(2 3 4) = 262144` | left-assoc: `((2 3) 4) = (9 4) = 4⁹` | `thm:tower` |
| `(2 2 2 2) = 65536` | left-assoc `2↑↑4` (a base-2 coincidence) | `thm:tetration` |

The second face of the same numeral is iteration. Define `appf n f = fun x => Nat.iter n f x`. Then:

> **(1.4) The numeral iterates functions.** `(2 f x) = f (f x)` (`thm:church_two`), `(3 (+1) 9) = 12` (`thm:inc_three`).

> **(1.5) The two faces are one map.** `app n x = appf n (mul x) 1` — exponentiation is iteration of multiply-by-`x` from 1. Evidence: `thm:lanes_agree`.

(1.5) is the statement of "every value is an operator": `xⁿ` is not the *meaning* of a numeral, only its numeral-on-numeral face. The numeral is the iterator; the tower is what you get when the thing iterated is itself a numeral — so "any recursive operator may be boundedly applied by integers, which act transparently as iterators" (README).

## 2 · absence and totality {#absence}

A name not in the **bag** (the global table) is *missing*. Reading it does not crash and does not return an error token; helpless (no `help` installed) it reads **the zero point**: a nameless unit `Pt` — the **mint** (a fresh, nameless point with an identity and nothing else; §9) at serial 0, printed `()`. The zero point absorbs application in both directions:

> **(2.1) The unit as operator is const-1.** `(Pt x) = 1`. Evidence: `thm:unit_is_const_one`.

> **(2.2) The unit absorbs under any numeric head.** `(g Pt) = Pt` for every numeral *and* every numeric operator `g` — the unit is the fixed point of all of them.

From these two facts a sentence becomes a theorem. `i` is present and numeric (a complex scalar, not a nat — so the explicit quantifier in (2.2) is what licenses the `(i Pt)` step); `love` and `you` are missing, hence `Pt`:

> **(2.3) Absence absorbs.** `(i love you) = ((i Pt) Pt) = (Pt Pt) = 1`. Evidence: `thm:love_theorem`.

The model's value space `value := Num n | Cx | Pt` makes the evaluation function `vapp` **total** by exhaustive case analysis — Rocq checks the exhaustiveness, so there is no stuck state and no undefined behaviour over this fragment:

> **(2.4) Totality (no UB).** `∀ f a, ∃ v, vapp f a = v`. Evidence: `thm:total`.

Totality licenses the language's safety claim that applicative order may vary at will: a total, side-effect-confined operator may be evaluated eagerly or lazily without changing its value, and cooperative preemption bounds every thread regardless of program behaviour.

The same missing-read law operates at every depth (this is the "one condition" discipline): a `:` binding read before its pin raises with the binding site's nom as payload; `(missing t k)` raises for a hash miss with `k` as payload; an empty special form reads its head. Helpless, all three land on the zero point; with a `help` installed, the help's result is delivered as the value.

## 3 · the net measure, truth, and color {#net}

ai has no "truthy/falsy" tag. Instead every value carries a **net**, a complex-valued content measure, and truth is the sign of the net in the total order. ℂ has no native order or sign of its own, so "`≤ 0`" and "sign" here mean *position relative to the zero point in the §4 total order* — lexicographically by `(re, im)`, read once at the boundary — not a numeric comparison. The Rocq slice models the real fragment `net : V → ℤ` over `V := Vnum z | Vnil | Vcons a b`:

```
net (Vnum z)               = z
net Vnil                   = 0
net (Vcons a Vnil)         = net a                 -- end of a proper list
net (Vcons a (Vnum _))     = net a                 -- a DOTTED tail is not a spine element
net (Vcons a (Vcons b r))  = net a + net (Vcons b r)  -- the car counts; continue the spine
```

So a number is its own value, `()` nets 0, and a list nets the **sum of its spine** (a dotted tail atom is "not an element"). Three observations sit on top:

```
sat  v = max 0 (net v)       -- $  : the SOLE clamp, max(0, ceil net)
nil? v = (net v <=? 0)       -- !  : false is nothing
tru  v = (0 <? net v)        -- !! : the truth bit
```

> **(3.1) The invariant.** `!x ≡ (0 = $x)` — the nif and the clamp agree on nothing, exactly. Evidence: `thm:nilp_iff_sat0` (mirrors `(!"" = 0 = $"")` in spec.l).

> **(3.2) `$` is a retraction onto the nonnegative numbers.** `0 ≤ $x` always (`thm:sat_nonneg`); `$x = net x` when `net x > 0` (`thm:sat_keeps`); `$x = 0` when `net x ≤ 0` (`thm:sat_clamps`).

**Color** is the order-sign of the net — a three-way classification, not a boolean:

| color | condition | meaning |
|---|---|---|
| green | `0 ≤ net` | nonnegative; what `$` keeps |
| red | `net < 0` | negative; what `$` clamps to nothing |
| green | `net = 0` | the floor — blue by sign yet nothing by measure |

> **(3.3) Color laws.** green ⟹ blue (`thm:green_is_blue`); every value is blue or red (`thm:blue_or_red`); the two are disjoint (`thm:blue_red_disjoint`); and **truth is positive blue** — above the green floor (`thm:truth_is_positive_blue`).

The floor matters: `0`, `()`, `""`, `@()`, `~(0 0)` are all green (net 0, false), while a box `#0` nets 1 (presence over nothing, true). `'(-2 1)` is red (net −1, `thm:net_red` / `thm:red_red`), false despite being non-empty — saturation holds at every rank, so a list of negatives is nothing exactly like a negative scalar.

The measure is a **homomorphism**: `+` is concatenation / adjunction at the value level, and the net distributes over it.

> **(3.4) `+` is the measure homomorphism.** `net (xs ++ ys) = net xs + net ys`. Evidence: `thm:net_homomorphism` (via `thm:netl_app`, `thm:net_vlist`).

This is what makes "`$` of a fold is mere composition" true: because net is additive wherever `+` is total, a clamped reduction is `$` *after* a plain sum; there is no per-fold saturator. Concrete corollaries the corpus pins: `$'(1 2 3) = 6` (`thm:sat_123`), a dotted tail drops (`thm:sat_dotted`, `$(cons 1 2) = 1`), a product of nothings is nothing (`thm:nothings`).

## 4 · the type lattice and the total order {#order}

The kinds form a lattice flattened into **bands**, low to high:

```
() < name < string < number < chain < set < map < hot
```

The organizing axis is the **net** with the **charm as hinge**: the char-built kinds (name, string — measured by their charm sum) net *up* into the numbers, the numbers *self*-net (the fixpoint, the middle), and the value-built kinds (chain, set, map — measured by their elements' sum) net *down*. The floor `()` is the bluest point of all, below even the number `0`. Within a band the order is by value (numbers by magnitude, rep-blindly), or lexicographically (text and chains), or by an α-invariant hash (maps and hots). The Rocq model takes one comparable key per band (`O := Osym z | Ostr z | Onum z | Oprod z | Omap z | Otop z`, in band order — name/string/number/chain/map/hot) and orders lexicographically on `(band, key)`. The result:

> **(4.1) `<` is a strict total order.** irreflexive (`thm:lt_irrefl`), transitive (`thm:lt_trans`), asymmetric (`thm:lt_asym`), and trichotomous (`thm:lt_trichotomy`).

> **(4.2) `<=` is a total order.** reflexive (`thm:le_refl`), transitive (`thm:le_trans`), antisymmetric (`thm:le_antisym`), total (`thm:le_total`).

> **(4.3) `=` is the Eq cell.** band and key together pin a value down (`thm:eq_from_band_key`): `=` is propositional equality, a linear order's equality and not a mere preorder.

The band chain itself is proved link by link: `thm:symbol_lt_string`, `thm:string_lt_number`, `thm:number_lt_product`, `thm:product_lt_map`, `thm:map_lt_top` — and the floor sits below even the number 0, `() < 0` (`thm:unit_lt_zero`). The set (a numeric array) sorts in the value-built region just above its chain. (The Rocq identifiers keep the older spellings — `symbol`/`product`/`top` — for what the prose now calls name/chain/hot.)

Two refinements the model is explicit about *not* covering:

- **`=` bridges the numeric tower** (`3 = 3.0`): a number band carries the mathematical value rep-blindly, so the float `3.0` and the fixnum `3` are the *same* `Onum` — there is no separate representation to model, by design.
- **`id?` (pointer identity) is strictly finer than `=`**: `'(1) = '(1)` yet `!(id? '(1) '(1))`. Identity has no model in a setting where nothing is shared; this is a deliberate omission, not an oversight.

This single order is the engine of `sort` — one comparison per chain, the comparator *is* the total order — and of map / hash key ordering.

## 5 · generic dispatch {#dispatch}

A value's **kind** is an enum whose order is the lattice of §4. A generic operator at two arguments is an N×N table indexed by the two kinds; an operator at one argument is that table's *diagonal*; the three core tables are `+`, `*`, and **apply**. A both-charm (both-fixnum) fast path skips the table; otherwise one indexed jump selects a lane that widens only as far as the operands require (array ⊃ complex ⊃ bignum ⊃ float ⊃ …).

The lattice, the dispatch, and the order are *the same object*: the diagonal of the dispatch matrix is the kind lattice, and the enum order of the kinds is the cross-kind comparison order. You maintain one structure and read it three ways. This section cites no Rocq lemmas on purpose: the dispatch matrix and the tail-threading are implementation invariants the runtime checks and the corpus exercises, not theorems in the Rocq slice — they live at the demonstrate layer (§11), where the chips go quiet.

## 6 · + and * are generic {#algebra}

`+` adds numbers, concatenates strings, and appends lists; `-` is numeric only — `+ - *` are the ring algebra that closes the numbers (§4). On sequences `+` is a **monoid**:

> **(6.1) Sequence monoid.** `++` is associative (`thm:cat_assoc`) with the empty sequence as left and right identity (`thm:cat_nil_l`, `thm:cat_nil_r`). Concretely `"ab"+"cd"="abcd"` (`thm:cat_strings`), `'(1 2)+'(3 4)='(1 2 3 4)` (`thm:cat_lists`), and `5+'(1 2)='(5 1 2)` — `+` adjoins (`thm:adjoin`).

`*` is **repeated `+`**, and the repetition count saturates:

> **(6.2) `*` is repeated `+`.** `srep (n+1) s = s ++ srep n s` (`thm:star_is_repeated_plus`).

> **(6.3) The count saturates.** `max(0, ceil)`: a non-positive count gives the empty sequence (`thm:star_neg`, `thm:star_zero`), an integer count keeps (`thm:count_keeps`, `thm:count_saturates`). E.g. `"ab"*3 = "ababab"` (`thm:star_ab_3`).

The measure homomorphism extends through both:

> **(6.4) Net through `+` and `*`.** `sum (x ++ y) = sum x + sum y` (`thm:sum_cat`); `sum (srep n s) = n · sum s` (`thm:sum_srep`).

The one **partial** case is the byte law, modelled as an option (None = nil):

> **(6.5) The byte law.** a string `+` an exact integer in `0..255` is one byte, rep-blind (so `66` and `66.0` alike); anything else is nil. `"x"+66 = "xB"` (`thm:byte_in_range`), `"x"+(-66)` and `"x"+256` are nil (`thm:byte_neg_nil`, `thm:byte_over_nil`), and `byte_add s n ≠ None ⟺ 0 ≤ n ≤ 255` (`thm:byte_iff`).

Names left the string algebra (the "mint round"): `+` / `*` on a name are nil, `intern` / `string` are the explicit bridge. The model folds name-`+` and string-`-` into the same None lane rather than duplicating the proof.

## 7 · function equality {#funeq}

`=` on two closures is **α-equivalence of their source** — binders matched by position, free variables by name, captured values compared pairwise. With de Bruijn indices α-equivalence *is* syntactic equality (names are gone), so it is decidable and structural:

> **(7.1) Decidable α-equality.** `∀ s t : tm, {s = t} + {s ≠ t}` (`thm:alpha_dec`), over `tm := Var n | Lam b | App f a`.

> **(7.2) α by position.** `(\ x x) = (\ y y)` (`thm:id_alpha`); same de Bruijn skeleton ⟹ equal (`thm:binders_by_position`); a free var ≠ a bound var (`thm:free_neq_bound`).

The numerals bridge into the term language, but no further:

> **(7.3) The numeral bridge.** `1 = (\ x x)` (`thm:id_alpha`: 1 is the identity) and `0 = (\ _ 1)` (`thm:zero_is_const_one`) — and 0 is **only** const-1 (`thm:zero_ne_const_two`, `thm:one_ne_zero`).

> **(7.4) η is not bridged.** `(\ x (f x)) ≠ f` (`thm:eta_not_bridged`): a closure and its operator are a representation-crossing edge that stays false.

`<` agrees with `=` here because the comparison hash is α-invariant; `id?` stays identity (finer than both).

## 8 · numerics {#numerics}

The numeric carriers earn their own short names — each names a predicate you can probe, and they carry through the array laws below. They split the **number** band by rank.

A **number** (`constellation?`) is any numeric value, scalar or array — the bottom band, closed under the ring algebra `+ - *`. A **star** (`star?`) is a *scalar* number, one that nets itself (`net x = x`, i.e. `id? x (net x)`): a fixnum, wide int, bignum, float, or complex scalar — the rank-0 point. The word-sized star, a fixnum, is a **charm** (`charm?`). A **set** (`set?`) is an array, numeric or not; a **galaxy** (`galaxy?`) is a set *of stars* — a numeric array. So a number is a star or a galaxy, and `$` lands every value on the **green charms** — the nonnegative integers (§3); a word-sized result is a charm, but a saturated bignum is a green star too.

| name | predicate | what it is |
|---|---|---|
| `constellation` | `constellation?` | any numeric value, scalar or array — the bottom band |
| `star` | `star?` | a scalar number, one that nets itself (rank 0) |
| `charm` | `charm?` | a word-sized star — a fixnum |
| `set` | `set?` | an array, numeric or not (rank ≥ 1) |
| `galaxy` | `galaxy?` | a set of stars — a numeric array (rank ≥ 1) |

A galaxy is *not* a star (`star?` is false on a set, whose net is a fresh sum): it is a set whose cells are stars. A charm is the smallest star; a number is a star or a galaxy.

The stars have a structural twin. A star is fixed under `net` (`id? x (net x)` — its own measure); an **atom** (`atom?`) is fixed under `cap` (`x = (cap x)` — its own head). The non-atom is a **pair** — the chain that `link` builds, whose `cap` and `cup` split a head from a rest. Every star is an atom (a number is its own head too), so a star is a *special* atom — fixed under `net` as well as `cap`. `net` is what carves the stars out of the atoms.

The **set** is the APL half of the language. A shape is its list of axis sizes; the **cell count** is the product of the shape (`alen`), the **rank** its length (`arank`): `alen [2;3] = 6` (`thm:alen_23`), `arank [2;3] = 2` (`thm:arank_23`), and a 0-axis yields 0 cells (`thm:alen_empty_axis`). Indexing is row-major and out-of-bounds reads the default:

> **(8.1) peep.** in-bounds reads the cell (`thm:peep_in`), OOB reads the default (`thm:peep_oob`); 2-D row-major is `i·cols + j` (`thm:peep_22`).

Reductions fold, and **empty reductions answer their monoid units**:

> **(8.2) Empty = unit.** `asum [] = 0` (`thm:asum_empty`), `aprod [] = 1` (`thm:aprod_empty`), `aall [] = true` (`thm:aall_empty`). Non-empty: `asum [10;20;30]=60` (`thm:asum_123`), `amax [10;30;20]=30` (`thm:amax_30`).

Broadcasting needs conforming shapes (else nil); scalar-`*` scales; and the measure homomorphism of §3 reappears at array rank:

> **(8.3) Broadcast `+`.** conforming ⟹ elementwise (`thm:vadd_ok`), mismatch ⟹ nil (`thm:vadd_mismatch`); scalar scale `thm:vscale_123`.

> **(8.4) Net through arrays.** `asum (vadd a b) = asum a + asum b` (`thm:asum_vadd`) and `asum (vscale c v) = c · asum v` (`thm:asum_vscale`) — so a **galaxy** nets exactly like the list of the same values; *the arrangement does not matter*.

`iota n` is the z-array `0..n-1` filled in one C loop (no link spine), so a range reduces end-to-end in C. Its Gauss sum is proved:

> **(8.5) iota and Gauss.** `iota 3 = [0;1;2]` (`thm:iota_3`), `iota 0 = []` (`thm:iota_0`), and `2 · asum (iota n) = n·(n-1)` (`thm:asum_iota`), whence `asum (iota 100) = 4950` (`thm:asum_iota_100`).

Contraction is the inner / outer product. The dot product is commutative and length-checked:

> **(8.6) Contraction.** `dot [1;2;3] [4;5;6] = 32` (`thm:dot_123_456`), `dot a b = dot b a` (`thm:dot_comm`); `inner` is nil on a length mismatch (`thm:inner_mismatch`). The matmul cell `M[i][j] = rowᵢ(A) · colⱼ(B)` checks at `thm:matmul_cell` (= 154).

A one-cell array **demotes** to its lone scalar (`@(5) = 5`): an array exists only at tally ≥ 2. Empties are the exception (a 0-axis has tally 0, not 1) — they stay arrays, carrying the reduction units of (8.2). There is thus no rank-0 array kind; a scalar star *is* the rank-0 point.

## 9 · strings, names, and mints {#mints}

A **string** is its bytes: it indexes them (`thm:str_index`, `("abc" 0)=97`; OOB applies as the unit 1, `thm:str_index_oob`), its net is the **sum of its bytes** (`thm:str_net`, `$"abc"=294`), and `tally` counts them (`thm:str_tally`). The NUL byte nets nothing, so `+` reaches the bytes and an all-NUL text is nothing:

> **(9.1) NUL is free.** `$(+ "a" 0) = 97` (`thm:nul_appends_free`); an all-NUL text is nothing (`thm:all_nul_nothing`); `!(string 0)` vs `!!(string 1)` (`thm:string_nul`, `thm:string_one`).

A **mint** is a fresh, nameless point — the unforgeable thing:

> **(9.2) Mint laws.** materially empty, `$(mint 0)=0` (`thm:mint_empty`); applies const-1, `((mint 0) x)=1` (`thm:mint_const1`); equal only to itself (`thm:mint_self`); distinct iff serials agree (`thm:mint_distinct`). The **zero point** is `Mint 0`, the face of absence.

A **nom** is McCarthy's atom restored as the chain it always was — a spelling paired with a mint: the chain `(spelling . mint)`, the spelling its cap (`thm:nom_cap`, `(cap (nom 'x))="x"`), ordered lexicographically by spelling then serial:

> **(9.3) Nom order.** same-name noms are distinct (`thm:same_name_distinct`) and ordered by serial (`thm:same_name_serial`) — so the total order stays total and GC-stable, and structurally a nom is identity-sharp (the mint inside) for free distinct map keys.

The bands place these exactly. The **name** band is the bare mint, seated between string and chain; a **nom**, being the chain `(spelling . mint)`, lives one band up in chain. So number `<` mint `<` nom — the mint above nothing, the nom (a chain) above the mint. `thm:point_above_nothing` (`0 < (mint 0)`) pins the mint *above* nothing, not at the floor; `thm:point_below_nom` (`(mint 0) < (nom 'x)`) seats a bare mint below a named one — both via the §4 order.

The phrase "the chain it always was" is precise, not rhetorical: a symbol must do exactly two things — carry a **spelling** and stay **identity-distinct** even when spellings coincide — and each demand is a universal property the language already realizes, so the representation is *forced*:

- the **spelling** is a **string**, the free monoid on bytes (`+` concatenates, `""` is the unit, §6.1); interning factors through it — equal spelling ⟹ equal symbol is just the statement that the symbol is a function of this free-monoid element.
- the **identity** is a **mint**, a point drawn from the one mint stream — the natural-numbers object, the zero point its `0` and a fresh draw its successor. A mint *is* its serial, with `=` the only structure (`thm:mint_distinct`).
- the **symbol** is their **link** — the categorical product, `cap` and `cup` the two projections (`thm:nom_cap` projects the spelling; `cup` the mint). The product's universal property says any value carrying a spelling-map and an identity-map factors *uniquely* through `(spelling . mint)`.

So McCarthy's atom is not *re-encoded* as a chain; the chain is the object the atom's own operations already characterize, unique up to the iso the universal property guarantees. `string × mint` is the terminal thing that carries a name and an identity — and the symbol was only ever its description.

## 10 · the numeric tower {#tower}

The integer net of §3 is exact, and the tower above it is built to *stay* exact wherever exactness is reachable. `i*i = -1` is exact, algebraically. `(log -1) = i·π` is exact in the principal-log direction, because `atan2(0,-1)` is π by IEEE fiat and `i` moves it with exact 0/1 products. `sqrt` factors its angle through `sinpi` / `cospi`, so `(1/2)·(-1) = i` on the nose. `/` is true division (an inexact integer quotient promotes to float, an exact one stays integer); `0/0` collapses to `0` (NaN is nothing, keeping the order total); overflow grows fixnum → wide → bignum.

The one place floats bite is the *forward* transcendental: `(-1 = ((* i pi) e))` — that is, `e^{iπ} = -1`, since `exp` is `(\ x (x e))` — does **not** hold, because `=` is exact and the nearest double to π cannot make `sine` land on 0, so `e^{iπ}` keeps a ~1.22×10⁻¹⁶ residue. ai keeps that residue rather than rounding it away. The Rocq slice (§11) proves the algebra over exact ℤ and leaves the transcendentals to [test/spec.l](test/spec.l), which asserts a float against a literal only where it is bit-exact on every target.

## 11 · metatheory: three layers of evidence {#meta}

A claim about ai can be believed at three escalating strengths, and this document is careful to say which applies where:

1. **Probe.** The way to settle any doubt is a one-line experiment at the binary; the demonstrations are reproducible, never taken on trust.
2. **Demonstrate ([test/spec.l](test/spec.l)).** Every law is assert-backed and runs green on every target — host, the self-hosted bootstrap, the freestanding kernel, and wasm — exhibiting the laws at runtime across the whole tower, floats included.
3. **Prove ([rocq/spec.v](rocq/spec.v)).** The combinator / numeral / absence / measure / order / algebra core is restated as theorems in **universe-checked Rocq, axiom-free**. These are the lemmas cited throughout.

The caveat every formal demonstration carries: the consistency of its own metatheory. The Rocq layer lives in universe-checked Rocq, so its theorems are unconditional — "the world does not explode here." Drop universe checking (type-in-type) and `empty` becomes inhabited, ex falso giving everything; the blue-paper theorems are stated where the world does *not* explode.

What is **not** proved in Rocq, by design, lives at the demonstrate layer: the float / complex / bignum *values* of the tower (the algebra of §1–9 is proved over exact ℤ; §10 is demonstrated, not proved), pointer identity `id?` (nothing is shared in the model), and the implementation invariants of §5 (the dispatch matrix, the tail-threading), which the runtime checks rather than Rocq. A fourth bridge keeps the demonstrate and prove layers in step automatically: `tools/spec2coq.l` generates Rocq straight from the spec (see also, below).

## 12 · implementation, in one breath {#impl}

One word is one value: a fixnum is a tagged odd word; anything else is a heap object whose first word is its **hot** — a live external reference, the wire out of the heap to the ap that runs it. The VM is **tail-threaded** (aps tail-jump, never return) over a **two-space copying** collector; out-of-pool constants are immortal. No interpreter state lives outside the heap: the **bag** (an ordinary ai hash) carries the globals, macros, the operators table, the `help` function, and the rng; C finds its own hooks by name, allocation-free.

The compiler is written in ai. At build time the evaluator sits on the **egg** (the quoted compiler source) twice — the C bootstrap compiles the compiler, which recompiles itself — and the hatchling bakes into the binary (`born` records the hatch time). The same image runs on Linux, wasm, and — as **kship** — bare metal (x86_64 / aarch64 via limine): a freestanding kernel that boots with no OS and runs the language over UDP, a bare-metal network REPL. A small crew of real programs rides on it: a netcat clone in ~50 lines (**aineko**), an interactive shell + pty wrapper (**bao**), a GNU-make-compatible build tool written in ai (**cook**), and **siri**, the synthesist, who keeps the human words matched to the ai words. Just before birth the egg mops up every compiler-internal name — the bag itself included — so a runtime-internal name is missing, and a missing name reads the zero point. The language closes over its own construction.

## · see also {#see-also}

- [test/spec.l](test/spec.l) — the executable spec; every law assert-backed, green on every target
- [rocq/spec.v](rocq/spec.v) — the machine-checked theorems cited above as the green chips
- [tools/spec2coq.l](tools/spec2coq.l) — generates Rocq straight from the spec, keeping the demonstrate and prove layers in step
- [crew/](crew/) — the **kship crew**, the programs that ride on kship: **aineko** (netcat), **bao** (the shell + pty wrapper), **cook** (make-in-ai), **kship** (the ship — bare-metal agent-kernel), **siri** (the synthesist, docs matched to the surface)
- [CLAUDE.md](CLAUDE.md) — the narrative spec with runnable demonstrations, and [README.md](README.md) — the overview
- [blue.md](blue.md), its ai generator [tools/blue.l](tools/blue.l), and the single stylesheet [blue.css](blue.css) — this page's source

## · the laws at a glance {#glance}

| § | law | theorem(s) |
|---|---|---|
| 1 | numeral law `(n x)=xⁿ` | `thm:const_one` `thm:identity` `thm:tower` `thm:tetration` |
| 1 | one map, two faces | `thm:lanes_agree` `thm:church_two` |
| 1 | currying, empty form | `thm:curry` `thm:empty_form` |
| 2 | absence absorbs `1=(i love you)` | `thm:love_theorem` `thm:unit_is_const_one` |
| 2 | totality (no UB) | `thm:total` |
| 3 | the invariant `!x ≡ (0=$x)` | `thm:nilp_iff_sat0` |
| 3 | saturation | `thm:sat_nonneg` `thm:sat_keeps` `thm:sat_clamps` |
| 3 | color | `thm:green_is_blue` `thm:blue_or_red` `thm:truth_is_positive_blue` |
| 3 | `+` is the measure homomorphism | `thm:net_homomorphism` |
| 4 | `<` strict total order | `thm:lt_irrefl` `thm:lt_trans` `thm:lt_asym` `thm:lt_trichotomy` |
| 4 | `<=` total order | `thm:le_refl` `thm:le_trans` `thm:le_antisym` `thm:le_total` |
| 4 | the band chain | `thm:symbol_lt_string` `thm:map_lt_top` `thm:unit_lt_zero` |
| 6 | sequence monoid; `*` is repeated `+` | `thm:cat_assoc` `thm:star_is_repeated_plus` |
| 6 | count saturates; byte law | `thm:count_saturates` `thm:byte_iff` |
| 7 | α-equality; numeral bridge; η not bridged | `thm:alpha_dec` `thm:zero_is_const_one` `thm:eta_not_bridged` |
| 8 | empty reduction = monoid unit | `thm:asum_empty` `thm:aprod_empty` `thm:aall_empty` |
| 8 | net through arrays; Gauss | `thm:asum_vadd` `thm:asum_vscale` `thm:asum_iota` |
| 9 | mint laws; nom order | `thm:mint_const1` `thm:mint_distinct` `thm:same_name_serial` |

*Step any of these in [rocq/spec.v](rocq/spec.v); run all of them in [test/spec.l](test/spec.l); doubt any of them at the binary. The three agree.*
