; src/apps/libra/salt.l -- salt, the config door every crew app can share. (salt 'libra)
; answers a tablet of that app's settings, the second file overlaying the first:
;
;   ~/.love/etc/<app>.l    your taste, wherever the binary happens to live
;   ./.<app>.l             this tree's own, and it travels in git
;
; the search is the cwd only, no walk upward; absent files are the same as empty ones.
;
; a config is data, read with `sound` and never evaluated, so nothing needs quoting; a form
; that is not a setting is skipped and the rest still lands.
;
; a setting is `(key operand ..)`: (singleton 1) a switch, (deprecated a b c) a roster; a
; repeated key replaces.

; salt-file takes a path, where `salt` reads the two the environment names
(module (salt salt salt-all salt-one salt-has? salt-file)
(borrow 'posix)
(:
 ; --- reading one file ------------------------------------------------------
 ; overlay path's settings onto the tablet c, mutated and answered. `sound` answers the datum
 ; consed onto the rest, () at a clean end, or `torn` on a dropped paren, so ask two?
 (salt-file path c)
  ; a kind test, not a match on (): a refusal answers a nom, and a nom is truthy
  (open path "r" @ q
     (? !(hot? q) c
        (: t (slurp q)
           (go x) (sound x @ (d . u) (two? d && name? <d && pin c <d >d, go u))
         (go t, close q, c))))

 ; --- the door --------------------------------------------------------------
 ; HOME, not the seat: /usr/bin/love seats at /usr, and nobody's settings live in /usr/etc
 (salt-user a) (getenv "HOME" @ h (string? h && h + "/.love/etc/" + string a + ".l"))
 (salt-here a) ("." + string a + ".l")

 (salt app) (: c {} u (salt-user app)
             (string? u && salt-file u c,
              salt-file (salt-here app) c,
              c))

 ; --- reading a setting -----------------------------------------------------
 ; the whole tail, or (); and the first operand, or a default. a switch is `(singleton 1)`.
 salt-all 1
 (salt-one c k d) (c k @ (a . _) a d)

 ; is nm listed under k? a roster entry is a bare name or `(name "hint")`
 (salt-has? c k nm)
  (: (go (e . u)) (<e @ ^nm [1 e] (go u))
   (go (salt-all c k)))))
