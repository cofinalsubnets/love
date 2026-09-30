; src/tools/mx2uu.l -- emit test/uumx.l: love's `+` and `*` dispatch matrices, read
; from the table (src/love/mx.l) and lifted to uu terms, so the band lattice is a
; theorem in the tree's own prover and not only in Rocq. Run on the host binary:
;
;   love src/tools/mx2uu.l > test/uumx.l        (or: make uumx)
;
; the uu twin of src/tools/mx2coq.l, deriving the band partition the same way (kinds grouped by
; row+column equality across both matrices), so the two exports cannot disagree about a band.
; a kind is its index in mx.l's enum roster, a lane its index in appearance order, a band its
; class id. a square is a grid (a list of rows), not a flat list: every walk rides `npred`,
; O(index) under the eager NbE. every kind and lane is emitted by name, so test/uumxlaw.l
; names a cell rather than counting to it: a bounded forall that stopped covering a grown
; roster would be green for the wrong reason. untrusted like every translator here.
;
; load the table first, in its own top-level form: the next form's bare mx-kinds /
; mx-add / mx-mul references resolve at its compile, which must follow this run.
(borrow 'posix)
(reads (open "src/love/mx.l" "r"), ())

(:
   (join l) (foldl (+) "" l)
   (pl s) (puts (s + "\n"))

   kinds mx-kinds                                    ; the kind noms, enum order
   addm mx-add                                       ; one row of lane noms per kind
   mulm mx-mul
   nk #kinds
   ridx ^nk
   (cell m i j) (m i j)                              ; a grid is indexed by application
   (rrow m i) (map (j \ cell m i j) ridx)
   (rcol m j) (map (i \ cell m i j) ridx)
   ; a kind's dispatch signature: its row and column in both matrices -- equal
   ; signature = same band. mx2coq derives the partition from this same datum.
   (sig i) [(rrow addm i) (rcol addm i) (rrow mulm i) (rcol mulm i)]
   (idxin x l k) (? (atom? l) -1 (<l = x) k (idxin x >l (k + 1)))
   sigs ((: (go is acc) (? (atom? is) (rev acc)
                           (sig <is @ s
                              (go >is (-1 < idxin s acc 0 ? acc (s . acc))))))
         ridx ())
   (band i) (idxin (sig i) sigs 0)                   ; class id, enum-appearance order
   nb #sigs
   reps (map (c \ ((: (go is) (c = band <is ? <is (go >is))) ridx)) ^nb)
   (members c) (filter (i \ c = band i) ridx)

   ; --- the noms the artifact wears ---
   (kn i) ("mx" + string (kinds i))                  ; mxkcharm ..
   ; the table spells a lane as its C symbol (lvm_addn); the prefix says nothing
   ; here, so it comes off -- mxLaddn, matching mx.v's Laddn.
   (ln x) (string x @ t ("mxL" + ("lvm_" = snip t 0 4 ? (snip t 4 #t) t)))
   lanes ((: (go rows acc)                           ; distinct lanes, appearance order
            (atom? rows ? (rev acc)
               (go >rows (foldl (\ a x (elem x a ? a (x . a))) acc <rows))))
          (addm + mulm) ())
   (lcode x) (idxin x lanes 0)
   ; mirror: the argument swap's action on lanes. the positional degenerate pair
   ; trades places (bin_a answers the a operand, bin_b the b); the rest are fixed.
   (mir x) (string x @ t (t @ "lvm_bin_a" 'lvm_bin_b "lvm_bin_b" 'lvm_bin_a x))

   ; --- literals: an nlist row, and a grid of them under their row names ---
   (rowlit cs) (: (go l) (two? l ? (join ["(ncons " (show <l) " " (go >l) ")"]) "nnil")
                  (go cs))
   (flatdef nm cs cmt)
    (join ["\n ; " cmt "\n (defn " nm " nlist\n   " (rowlit cs) ")\n"])
   (griddef nm rows labs cmt)
    (: n #rows
       (go r) (r = n ? (join ["\n    mnil" (")" * n) ")\n"])
                 (join ["\n   ; " (labs r) "\n   (mcons " (rowlit (rows r)) (go (r + 1))]))
       (join ["\n ; " cmt "\n (defn " nm " mlist" (go 0)]))
   (rowsof m is js) (map (i \ map (j \ lcode (cell m i j)) js) is)

   ; --- the header ---
   _ (pl "; test/uumx.l -- generated from src/love/mx.l by src/tools/mx2uu.l. Do not edit;")
   _ (pl "; refresh with `make uumx`. love's `+` and `*` dispatch matrices as uu terms:")
   _ (pl "; a kind is its index in mx.l's enum roster (which IS the dispatch lattice), a")
   _ (pl "; lane its index in appearance order, a band its class id under row+column")
   _ (pl "; equality across both matrices -- the partition src/tools/mx2coq.l derives too, off")
   _ (pl "; the same datum, so the Rocq model and this one cannot disagree about a band.")
   _ (pl "; test/uumxlaw.l then proves the laws OF this table -- the same love datum")
   _ (pl "; love.c's mx.h is laid from -- so a dispatch edit that breaks the band quotient,")
   _ (pl "; or the mirror symmetry, fails a proof at `make test`. Substrate: test/uu.l.")
   _ (pl "")
   _ (pl "(test (elem 'vof (names ())))")
   _ (pl "")
   _ (pl "; --- the codes ---")
   _ (pl "(test")
   _ (map (i \ pl (join [" (defn " (kn i) " nat " (show i) ")"])) ridx)
   _ (map (x \ pl (join [" (defn " (ln x) " nat " (show (lcode x)) ")"])) lanes)
   _ (pl (join [" (defn mxnk nat " (show nk) ")"]))
   _ (pl (join [" (defn mxnl nat " (show #lanes) ")"]))
   _ (pl (join [" (defn mxnb nat " (show nb) "))"]))
   _ (pl "")
   _ (pl "; --- mlist: nlist's shape one type up, a list of rows. the two walkers below")
   _ (pl "; --- take memb's form -- one nat_rect over the length, the index carried down")
   _ (pl "; --- -- and a grid keeps both of them short, which is the whole reason the")
   _ (pl "; --- square is not one flat list: npred is O(index) under the eager NbE ---")
   _ (pl "(test")
   _ (pl " (defn mvec (pi n nat UU)")
   _ (pl "   (lam n (nat_rect (lam q UU) unit (lam k (lam r (total2 h nlist r))) n)))")
   _ (pl " (defn mlist UU (total2 n nat (mvec n)))")
   _ (pl " (defn mnil mlist (tpair 0 tt))")
   _ (pl " (defn mcons (pi x nlist (pi l mlist mlist))")
   _ (pl "   (lam x (lam l (tpair (succ (pr1 l)) (tpair x (pr2 l))))))")
   _ (pl " (defn mxnth (pi i nat (pi l nlist nat))")
   _ (pl "   (lam i (lam l ((nat_rect (lam q (pi v (nvec q) (pi j nat nat)))")
   _ (pl "                     (lam v (lam j 0))")
   _ (pl "                     (lam k (lam IH (lam v (lam j (bool_rect (lam x nat)")
   _ (pl "                              (pr1 v)")
   _ (pl "                              (IH (pr2 v) (npred j))")
   _ (pl "                              (niszero j))))))")
   _ (pl "                     (pr1 l))")
   _ (pl "                  (pr2 l) i))))")
   _ (pl " (defn mxrow (pi i nat (pi l mlist nlist))")
   _ (pl "   (lam i (lam l ((nat_rect (lam q (pi v (mvec q) (pi j nat nlist)))")
   _ (pl "                     (lam v (lam j nnil))")
   _ (pl "                     (lam k (lam IH (lam v (lam j (bool_rect (lam x nlist)")
   _ (pl "                              (pr1 v)")
   _ (pl "                              (IH (pr2 v) (npred j))")
   _ (pl "                              (niszero j))))))")
   _ (pl "                     (pr1 l))")
   _ (pl "                  (pr2 l) i))))")
   _ (pl " (2 = (vof 0 '(mxnth 1 (ncons 5 (ncons 2 (ncons 9 nnil))))))")
   _ (pl " (0 = (vof 0 '(mxnth 7 (ncons 5 nnil))))                        ; 0 off the end")
   _ (pl " (9 = (vof 0 '(mxnth 0 (mxrow 1 (mcons (ncons 5 nnil) (mcons (ncons 9 nnil) mnil)))))))")

   ; --- the tables ---
   klabs (map (i \ string (kinds i)) ridx)
   blabs (map (c \ join ["band " (show c) " -- " (string (kinds (reps c)))]) ^nb)
   bidx ^nb
   bimg (map (c \ reps c) bidx)
   (pl "",
    pl "; --- the squares, one row per kind in enum order ---",
    puts "(test",
    puts (griddef "mxaddgrid" (rowsof addm ridx ridx) klabs
                  (join ["`+`: " (show nk) " kinds square, " (show (nk * nk)) " cells"])),
    puts (griddef "mxmulgrid" (rowsof mulm ridx ridx) klabs
                  (join ["`*`: " (show nk) " kinds square, " (show (nk * nk)) " cells"])),
    puts (flatdef "mxbandtbl" (map band ridx)
                  "the band partition, DERIVED by row+column equality over both squares"),
    puts (flatdef "mxnumtbl" (map (i \ (elem (kinds i) mx-numk ? 1 0)) ridx)
                  "mx.l's own mx-numk roster: which kinds take the arithmetic lane"),
    puts (flatdef "mxmirtbl" (map (x \ lcode (mir x)) lanes)
                  "mirror: the argument swap's action on lanes, in code order"),
    puts (griddef "mxaddbgrid" (rowsof addm bimg bimg) blabs
                  (join ["`+` on the band quotient, " (show (nb * nb)) " cells"])),
    puts (griddef "mxmulbgrid" (rowsof mulm bimg bimg) blabs
                  (join ["`*` on the band quotient, " (show (nb * nb)) " cells"])),
    pl "",
    pl " ; --- and the seven lookups they carry ---",
    pl " (defn mxadd (pi a nat (pi b nat nat)) (lam a (lam b (mxnth b (mxrow a mxaddgrid)))))",
    pl " (defn mxmul (pi a nat (pi b nat nat)) (lam a (lam b (mxnth b (mxrow a mxmulgrid)))))",
    pl " (defn mxband (pi k nat nat) (lam k (mxnth k mxbandtbl)))",
    pl " (defn mxnumeric (pi k nat bool) (lam k (nateqb (mxnth k mxnumtbl) 1)))",
    pl " (defn mxmirror (pi l nat nat) (lam l (mxnth l mxmirtbl)))",
    pl " (defn mxaddband (pi x nat (pi y nat nat))",
    pl "   (lam x (lam y (mxnth y (mxrow x mxaddbgrid)))))",
    pl " (defn mxmulband (pi x nat (pi y nat nat))",
    pl "   (lam x (lam y (mxnth y (mxrow x mxmulbgrid))))))",
    pl "",
    pl "; --- the bounded forall the theorems close by: every kind, then the square ---",
    pl "(test",
    pl " (defn mxall (pi n nat (pi f (pi k nat bool) bool))",
    pl "   (lam n (lam f (nat_rect (lam q bool) true (lam k (lam r (andb (f k) r))) n))))",
    pl " (defn mxsq (pi f (pi a nat (pi b nat bool)) bool)",
    pl "   (lam f (mxall mxnk (lam a (mxall mxnk (lam b (f a b))))))))",
    quit 0))
