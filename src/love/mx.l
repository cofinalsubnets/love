; mx.l -- love.c's `+` and `*` dispatch matrices as data, the kind lattice they index, and
; what derives from it: mx.h and kinds.h (through clay), love_data.ld, and the Rocq model.
; edit this file, not mx.h / kinds.h / love_data.ld. `make mx` refreshes, test_clay diffs.
(borrow 'posix)
(:
   ; --- the kinds: `enum q`, so this order is the dispatch lattice, each lane a contiguous
   ; block. a tray enters as its four tiers, never as the bare rep.
   mx-kinds '(KMint KNom KCharm KSun KGem KTwin KTrayZ KTrayR KTrayC KTrayO
              KString KChain KTablet KHot)
   ; the rows' love names: what `kind` answers. hot is every non-data heap object but a
   ; tablet, which `kind` refines: a struck coin's own name, else lambda, cask, port.
   mx-kind-noms '(mint nom charm sun gem twin trayz trayr trayc trayo string chain tablet hot)
   _ (assert (#mx-kind-noms = #mx-kinds))
   ; the arithmetic lane: every numeric kind routes identically
   mx-numk '(KCharm KSun KGem KTwin KTrayZ KTrayR KTrayC KTrayO)

   ; --- the reps: what a heap object's hot says it is; `love_typ` answers these eight only.
   ; one tray rep, refined by element tier into four kinds.
   mx-reps '(DMint DNom DGem DTwin DBig DTray DString DChain)
   ; each rep's dispatch kind. DTray's entry is never read (kind adds the tier itself).
   ; DBig -> KSun: one boxed integer, limbs in C, `sun` to love.
   mx-repq '((DMint KMint) (DNom KNom) (DGem KGem) (DTwin KTwin)
             (DBig KSun) (DTray KTrayZ) (DString KString) (DChain KChain))

   ; --- the rows, (name numk KMint KNom KString KChain KTablet KHot): total by construction.
   ; precedence, high to low: lambda > tablet > chain > text > number (incl. tray).
   mx-rows
    '(; `+`: numbers add, lists and text concatenate, lambdas and maps Church-add.
      ;      () and every point (a bare mint or name) is the identity, and two points join to the
      ;      greater in love's order: a semilattice. the dispatchers early-out on a point and
      ;      must agree. mixed bands: the lower arrives as its unit. order NUM < STR < CHAIN.
      (ADD_MINT  lvm_bin_unit   lvm_bin_unit lvm_bin_unit   lvm_bin_unit   lvm_bin_unit lvm_bin_unit lvm_bin_unit)
      (ADD_NUM   lvm_addn       lvm_bin_unit lvm_bin_unit   lvm_bin_b      lvm_bin_b    lvm_addh     lvm_addh)
      (ADD_STR   lvm_bin_a      lvm_bin_unit lvm_bin_unit   lvm_add_string lvm_add_seq  lvm_addh     lvm_addh)
      (ADD_TWO   lvm_bin_a      lvm_bin_unit lvm_bin_unit   lvm_add_seq    lvm_add_seq  lvm_addh     lvm_addh)
      (ADD_H     lvm_addh       lvm_bin_unit lvm_bin_unit   lvm_addh       lvm_addh     lvm_addh     lvm_addh)
      ; `*`: the semiring product over the lane above. sequence * count repeats, lambdas
      ;      and maps compose. () is the zero and annihilates.
      (MUL_MINT  lvm_0          lvm_0        lvm_0          lvm_0          lvm_0        lvm_0        lvm_0)
      (MUL_NUM   lvm_muln       lvm_0        lvm_0          lvm_mul_rep    lvm_mul_rep  lvm_mulh     lvm_mulh)
      ; str*str stays lvm_0, the absorbing zero; a number against a string repeats it
      (MUL_REP   lvm_mul_rep    lvm_0        lvm_0          lvm_0          lvm_0        lvm_mulh     lvm_mulh)
      ; MUL_REP but chain*chain is the cartesian product: the list lane is a semiring.
      (MUL_CHAIN lvm_mul_rep    lvm_0        lvm_0          lvm_0          lvm_mul_cart lvm_mulh     lvm_mulh)
      (MUL_H     lvm_mulh       lvm_0        lvm_0          lvm_mulh       lvm_mulh     lvm_mulh     lvm_mulh))

   ; --- which row each kind takes. KTablet or KHot wins over everything: a tablet is a
   ; lookup lambda here.
   mx-add-of '((ADD_MINT KMint KNom)
               (ADD_NUM KCharm KSun KGem KTwin KTrayZ KTrayR KTrayC KTrayO)
               (ADD_STR KString) (ADD_TWO KChain) (ADD_H KTablet KHot))
   mx-mul-of '((MUL_MINT KMint KNom) (MUL_REP KString)
               (MUL_NUM KCharm KSun KGem KTwin KTrayZ KTrayR KTrayC KTrayO)
               (MUL_CHAIN KChain) (MUL_H KTablet KHot))

   ; --- expanding the table ------------------------------------------------------
   (mx-rowof asg k)                                   ; which row does kind k take?
    (: (go (r . u)) (elem k >r ? <r (go u))
     (go asg))
   (mx-col c)                                         ; column c's index in a row's seven
    (elem c mx-numk ? 0 (c @ 'KMint 1 'KNom 2 'KString 3 'KChain 4 'KTablet 5 6))
   (mx-lanes rw) (: (go (e . u)) (<e @ ^rw >e (go u))  ; the row's seven
                  (go mx-rows))
   (mx-lane rw c) (mx-lanes rw (mx-col c))            ; the lane at (row rw, column c)
   ; the whole square of lane noms in enum order, for mx2coq.l and the C
   (mx-grid asg) (map (k \ (map (c \ (mx-lane (mx-rowof asg k) c)) mx-kinds)) mx-kinds)
   mx-add (mx-grid mx-add-of)
   mx-mul (mx-grid mx-mul-of)

   ; --- the C, through clay ------------------------------------------------------
   _ (borrow "src/apps/moon/clay.l")
   ; arrays of const pointers: clay places the const on the declarator, not the base
   mx-ty '(arr (arr (const (ptr (named "lvm_t"))) KN) KN)
   ; mx_row fans a row's seven out to every column; one macro per row, a grid per kind
   mx-nl (string 10)
   mx-params '("num" "mint" "nom" "str" "chain" "tab" "hot")
   (mx-cont l) (l @ (h . t) (foldl (a \ s \ a + " \\" + mx-nl + " " + s) ("\\" + mx-nl + " " + h) t) "")
   (mx-chunk n l)
    (: (go i cur l) (two? l ? (i = n ? (rev cur . go 0 () l) (go (i + 1) (<l . cur) >l))
                       (two? cur ? [(rev cur)]))
     (go 0 () l))
   mx-rowdef
    ['cpp-def ("mx_row(" + sepby ", " mx-params + ")")
     ("{ " + mx-cont (map (sepby " ")
                          (mx-chunk 5 (map (c \ "[" + string c + "] = " + mx-params (mx-col c) + ",")
                                           mx-kinds)))
      + " }")]
   (mx-rowname rw) ("mx_" + string rw)
   mx-rowdefs
    (map (e \ ['cpp-def (mx-rowname <e) ['call ['var "mx_row"] (map (x \ ['var (string x)]) >e)]])
         mx-rows)
   (mx-clay1 nm asg)
    ['gdecl [[(string nm) mx-ty
              ['var ("{" + mx-nl + cats (map (k \ " [" + string k + "] = " + mx-rowname (mx-rowof asg k)
                                                  + "," + mx-nl) mx-kinds) + "}")]]]
     '(static)]
   mx-undefs (map (n \ ['cpp-undef n]) ("mx_row" . map (e \ mx-rowname <e) mx-rows))
   (zip a b) (two? a ? ([<a <b] . zip >a >b))   ; these are 2-lists, not pairs

   ; --- the enums the matrices are indexed by -------------------------------------
   ; KN closes `enum q` and is not a kind: the roster's length, for [KN][KN]. enum d gets no
   ; such tail: the C switches over it, and -Wswitch would demand a case.
   kinds-clay ['edef "q" (mx-kinds + '(KN))]
   reps-clay ['edef "d" mx-reps]
   ; rep -> kind, the only crossing between the rosters (edef has no `= n`). in mx.h, not
   ; kinds.h, where a static table would sit unread under -Werror.
   repq-clay
    ['gdecl [["kind_of_d" '(arr (const (named "enum q")) 0)
                 ['init (map (p \ ['didx <p ['var (string <>p)]]) mx-repq)]]]
      '(static)]

   ; --- the same roster, laid for the LINKER ---------------------------------------
   ; enum d is a slot index: each sentinel in its own love.data.N, a rep read as arithmetic
   ; on the ap. tiling tighter than the C's stride answers slot 0 for every value in silence;
   ; looser drives ld's counter backwards, so `. =` per slot is also a check.
   ; one row per class: the stride the C compiles under and ld is told. it must clear the
   ; fattest sentinel body (a64 4, x64 8, thumb2 60, rv64 88); lean's 16 leaves room for endbr64.
   mx-strides '((lean 16  ("__x86_64__" "__aarch64__"))
                (fat  128 ()))              ; no predicate: the #else
   ; whether the sections are laid: 0 asks the sentinels by name (wasm, love0). the image
   ; carries an ap as its index in image_extra_aps, so no layout crosses binaries.
   mx-sections '((byname 0 ("__wasm__"))
                 (tiled  1 ()))
   (mx-stride cls) (: (go l) (l @ (r . u) (<r @ ^cls <>r (go u)) (scare 'mx-stride cls))
                    (go mx-strides))
   ; --- the classes as C: `#ifndef NAME` over `#if defined(..) / #elif / #else`, so a -D
   ; overrides (love0's data_section=0).
   (mx-defd n) ['call ['var "defined"] [['var n]]]
   (mx-ors l) (atom? >l ? (mx-defd <l) ['lor (mx-defd <l) (mx-ors >l)])
   (mx-knob nm rows)
    (: (arms l) (two? l ?
                   (<l @ r (two? (r 2) ? ([(mx-ors (r 2)) [['cpp-def nm <>r]]] . arms >l)
                            (arms >l))))
       (els l) (atom? l ? (scare 'mx-knob nm)
                  (<l @ r (two? (r 2) ? (els >l) [['cpp-def nm <>r]])))
       ['cpp-if [[['un 'not (mx-defd nm)] [['cpp-if (arms rows) (els rows)]]]]])
   (mx-tile base stride p)                        ; one KEEP per rep, each slot pinned
    (: (go i) (i = #mx-reps ? ""
               (p + "KEEP(*(love.data." + show i + "))  . = " + base + " + "
                  + show (stride * (i + 1)) + ";" + mx-nl + go (i + 1)))
       (go 0))
   ; the host link's -T fragment, laid whole
   mx-ld
    (mx-stride 'lean @ s
       ("/* love_data.ld -- generated by mx.l. do not edit; edit the table there." + mx-nl
       + "   the data sentinels' tiling for the host link (love.c's DSENT, love.h's love_typ)." + mx-nl
       + "   INSERT augments the default script rather than replacing it, so this drops onto" + mx-nl
       + "   a host link as a plain -T fragment; the output name leads with a dot, so ld" + mx-nl
       + "   defines no bounds and the two symbols here are the ASSERT's. holo needs no" + mx-nl
       + "   script: it lays each section on the grain the object declares. */" + mx-nl
       + "SECTIONS {" + mx-nl
       + "  .love.data : ALIGN(" + show s + ") {" + mx-nl
       + "    __start_love_data = .;" + mx-nl
       + mx-tile "__start_love_data" s "    "
       + "    __stop_love_data = .;" + mx-nl + "  }" + mx-nl + "} INSERT AFTER .text;" + mx-nl
       + "ASSERT(__stop_love_data - __start_love_data == "
       + show #mx-reps + " * " + show s + "," + mx-nl
       + "       \"love_data: slot count moved -- sync love.h's data_n and mx.l\")" + mx-nl))

   mx-forms
    ([['note "mx.h -- +/* dispatch matrices. generated by mx.l, do not edit"]
      ['note "a row names its lanes: every numeric kind, then mint nom string chain tablet hot"]
      mx-rowdef]
     + mx-rowdefs
     + [(mx-clay1 "add_mx" mx-add-of) (mx-clay1 "mul_mx" mx-mul-of) repq-clay]
     + mx-undefs)
   mx-h (cats (map clay-show mx-forms))
   ; the slot layout rides kinds.h, beside the roster it is a layout of
   slots-clay
    (string 10 @ nl
       [['note ("the data slot layout: the sentinels tile one section at data_stride in" + nl
                 + "enum d order, so a value's rep is arithmetic on its ap -- love.c's DSENT," + nl
                 + "love.h's love_typ, src/love/love_data.ld. each #if is a default, the guard a -D door.")]
         (mx-knob "data_section" mx-sections)
         (mx-knob "data_stride" mx-strides)
         ['cpp-def "data_n" #mx-reps]])
   kinds-h
    (string 10 @ nl2
       (cats (map clay-show
        [['note ("kinds.h -- generated by mx.l. do not edit; edit the table there." + nl2)]
         kinds-clay
         reps-clay
         ['cpp-def "kind_names" (: ns (map show mx-kind-noms)   ; one C literal, space-separated
                                      (string 34 + foldl (a \ n \ a + " " + n) <ns >ns + string 34))]
         '(note "")])
        + cats (map clay-show slots-clay)))
   ; a shape check first: a malformed tree arrives as a codegen error naming nothing
   mx-ok
    (: a (foldl (a \ x \ a && clay-ok? x) 1 mx-forms)
       c (clay-ok? kinds-clay)
       d (clay-ok? reps-clay)
       f (foldl (a \ x \ a && clay-ok? x) 1 slots-clay)
       (a = c = d = f = 1)))
