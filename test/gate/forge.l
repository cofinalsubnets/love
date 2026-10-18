; test/gate/forge.l -- forge's gate: a nif written in love, assembled through holo and installed
; through the `nif` seam, must agree with its C twin on every shape, natively and deopted. a
; wrong answer from an array kernel looks like data, so the differential is the whole gate.
; zero fitted is legal only with a reason in `forge-why`: else it reads like a pass
(: _ (borrow "src/apps/forge.l")
   (die m) (say err ("forge-gate: " + m + "\n"), flush err, quit 1)
   fitted (forge-fit 0)
   ; read before the bogus kernel below, whose decline would else answer for a fit that died silently
   why0 (forge-why 0)
   _ (say out ("forge: " + show fitted + " kernel(s) fitted, "
               + show (forge-fitted? 0) + " native, arch " + love-arch + "\n"))
   _ (why0 ? (say out ("  declines: " + show why0 + "\n")) 0)

   ; --- the shapes ---
   ; empty and all-nonzero catch a loop bound off by one at either end
   (seq sh) (foldl (*) 1 sh @ k (foldl (g \ j \ (g (j + 1))) (array sh) (jot k)))
   zs [(iota 0) (iota 1) (iota 2) (iota 9) (iota 64)
       (1 + iota 1) (1 + iota 2) (1 + iota 9) (1 + iota 64) (1 + iota 4096)
       (array '(3) -1 2 3) (array '(3) -1 0 3) (array '(3) 1 2 0) (array '(3) 0 2 3)
       (array '(2 2) 1 2 3 4) (array '(2 2) 1 2 3 0) (array '(2 3) 1 1 1 1 1 1)
       (array '(2 2 2) 1 1 1 1 1 1 1 0) (array '(4 0) )]
   ; the Z trays the two-argument kernels sweep, every rank and both orders of every shape
   ts [(seq '(1)) (seq '(3)) (seq '(4)) (seq '(6)) (seq '(2 2)) (seq '(2 3)) (seq '(3 2))
       (seq '(4 2)) (seq '(2 4)) (seq '(3 3)) (seq '(2 2 2)) (seq '(1 3)) (seq '(3 1)) (iota 0)]
   ; everything a kernel must hand back: floats, objects, scalars, the zero point, text, a list
   ds [(array '(2 2) 1.0 2.0 3.0 4.0) (array '(3) 1.0 0.0 2.0)
       (array '(2) 'a 'b) (array '(2) () ())
       5 0 -3 2.5 () "text" '(1 2 3)]

   ; `=` is a mask on a tray; aall asks the whole question
   (same? a b) (aall (a = b))
   (chk1 nm f g xs)
    (filter (x \ !(same? (f x) (g x))) xs @ bad
       (!bad ? (say out ("  " + nm + ": agrees on " + show #xs + " shapes\n"))
          (die (nm + " DISAGREES with its twin on " + show bad))))
   (chk2 nm f g xs)                                  ; every pair
    (filter (a \ any (b \ !(same? (f a b) (g a b))) xs) xs @ bad
       (!bad ?
          (say out ("  " + nm + ": agrees on " + show (#xs * #xs) + " pairs\n"))
          (each xs (a \ (each xs (b \ (same? (f a b) (g a b) ? 0
                 (say out ("    " + nm + " " + show (shape a) + " x " + show (shape b)
                           + "\n      twin " + show (g a b) + "\n      holo " + show (f a b) + "\n")))))),
           die (nm + " DISAGREES with its twin"))))
   (want nm) (forge-of nm @ v
                (lit? v ? v (die ("forge-of " + show nm + " answered nothing"))))

   _ (chk1 "aall  native" (want 'aall) aall zs)
   _ (chk1 "aall  deopt " (want 'aall) aall ds)
   _ (chk2 "outer native" (want 'outer) outer ts)
   _ (chk2 "outer deopt " (want 'outer) outer (ds + ts))
   _ (chk2 "inner native" (want 'inner) inner ts)
   _ (chk2 "inner deopt " (want 'inner) inner (ds + ts))

   ; --- the extras slot, which no roster kernel uses: a piece nobody exercises reads like a
   ; working one. `nifx` carries one love value at Ip+32, for a constant a kernel cannot spell;
   ; this kernel ignores its argument and answers it. a heap value on purpose: the collector
   ; walks the slot and the image codec encodes it, which an `li` immediate would not test
   (xt-ir _) (forge-extras 'r0 + forge-epi-ptr)
   xtval '(the extras slot)
   _ (forge-putx 'xt 1 xt-ir (q \ xtval) xtval)

   ; --- the arity>=2 shape: the curried cell is a different cell (8 words behind lvm_cur, not 6)
   ; and its deopt skips the twin's curry preamble. a law over plain fixnums, where nothing else
   ; can explain a disagreement
   (fx-and-ir _)
    (forge-fixg 0 + (forge-fixg 1
    + ('((ld r0 r1 0) (sar r0 1) (ld r7 r1 8) (sar r7 1) (and r0 r0 r7)) + forge-epi)))
   _ (forge-put 'fx-and 2 fx-and-ir (&))
   fitted2 (forge-fit 0)
   ; where nothing can install, `fitted` stays 0 and the row not growing is correct, not a red
   _ (fitted = 0 || fitted2 = fitted + 2 ? 0
      (die ("the roster did not grow: fit " + show fitted + " -> " + show fitted2)))
   _ (want 'xt 0 = xtval ? 0
      (die ("the extras slot answered " + show (want 'xt 0) + ", want " + show xtval)))
   _ (want 'xt '(anything at all) = xtval ? 0 (die "the extras kernel read its argument"))
   _ (say out ("  extras: the Ip+32 slot answers " + show xtval + "\n"))
   nat2 (want 'fx-and)
   pairs [[0 0] [1 1] [6 3] [255 15] [1023 992] [7 0] [65535 4096]
          [12345678 87654321] [1 2.5] ["a" 3] [() 7] [3 ()]]
   bad2 (filter (p \ !(nat2 <p <>p = <p & <>p)) pairs)
   _ (!bad2 ? (say out ("  arity 2: agrees on " + show #pairs + " pairs\n"))
        (die ("the arity-2 kernel DISAGREES with its twin on " + show bad2)))

   ; --- allocation: the room guard; no collection runs mid-body ---
   ; a native body's registers are not GC roots, so a kernel proves the room before any Hp or Sp
   ; motion and deopts when it is not there. gate-only: with no loop in the body the lane loses to
   ; the C nif. the churn makes the guard fire over and over; a collection mid-body would answer a
   ; cell in the old semispace, a wrong list, so the deep build is compared to the C one
   (link-ir _)
    (forge-room 96
    + ([['li 'r8 forge-chaink] '(st r2 0 r8)
         '(ld r0 r1 0) '(st r2 8 r0)
         '(ld r0 r1 8) '(st r2 16 r0)
         '(mov r0 r2) '(add r2 r2 24)]
       + forge-epi-ptr))
   _ (forge-put 'cons2 2 link-ir (.))
   fitted3 (forge-fit 0)
   _ (fitted = 0 || fitted3 = fitted2 + 1 ? 0
      (die ("the allocating kernel did not fit: " + show fitted2 + " -> " + show fitted3)))
   natc (want 'cons2)
   cx [1 0 -3 2.5 () "s" 'nom '(1 2) (iota 3)]
   badc (filter (a \ any (b \ !(natc a b = (a . b))) cx) cx)
   _ (!badc ? 0 (die ("the cons kernel DISAGREES with `.` on " + show badc)))
   deep (: (go i a) (i < 1 ? a (go (i - 1) (natc i a))) (go 5000 ()))
   deepc (: (go i a) (i < 1 ? a (go (i - 1) (i . a))) (go 5000 ()))
   _ (deep = deepc ? 0 (die "a 5000-deep native build differs from the C one"))
   _ (: (go i) (i < 1 ? 0 (go2 500, go (i - 1)))
        (go2 k) (: (g3 j a) (j < 1 ? #a (g3 (j - 1) (natc j a))) (g3 k ()))
        (go 4000))
   _ (natc 1 '(2 3) = '(1 2 3) ? 0 (die "the cons kernel is wrong after the churn"))
   _ (say out ("  allocation: " + show (#cx * #cx) + " pairs, a 5000-deep build and 2M conses\n"))

   ; --- a fit is idempotent: a native cell does not survive a bake (the codec reverts it to the
   ; twin), so a wake calls `forge-fit` again; twice must install twice, never a second roster
   again (forge-fit 0)
   _ (again = fitted3 ? 0 (die ("refit fitted " + show again + ", first fit " + show fitted3)))
   _ (fitted = 0 ? 0 (forge-fitted? 0 = again ? 0
      (die ("refit installed " + show again + " but " + show (forge-fitted? 0) + " are native"))))
   _ (chk1 "aall  refit" (want 'aall) aall zs)
   _ (chk2 "outer refit" (want 'outer) outer ts)

   ; --- a decline is data: holo raises on an op it cannot lower, and an untrapped assemble would
   ; end the fit for every later kernel. the bogus row must decline by name, keep its twin, and
   ; leave its neighbours native
   (bogus-ir _) '((no-such-op r0 r1))
   _ (forge-put 'bogus 1 bogus-ir aall)
   fitted4 (forge-fit 0)
   ((fitted4 = fitted3 ? 0
     (die ("a bogus kernel changed the fitted count: " + show fitted3 + " -> " + show fitted4))),
    (forge-why 0 ? 0 (die "the bogus kernel declined without naming a reason")),
    (forge-of 'bogus (1 + iota 4) = 1 ? 0 (die "the bogus kernel did not fall back to its twin")),
    chk1 "aall  after a decline" (want 'aall) aall zs,
    say out ("  decline: named " + show (forge-why 0) + ", roster intact\n"),

    ; last: forging nothing is a legal build (no glaze module, or a target the kit does not spell);
    ; a tree that thinks it forged and did not is not
    (? (fitted > 0) 0 why0 0
       (die "zero kernels fitted, and nothing named a reason -- the seam or the assemble died")),
    say out "forge: 0 failed\n",
    0))
