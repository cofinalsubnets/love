; src/apps/seal.l -- the hive's keys and cards. a key is an ed25519 pair a box or a session
; holds; a card is `key value` lines, signed by the key above it, saying whose a public key
; is. a chain is a leaf's card, then its signer's, up to a card the lineage's root signed,
; and checking one needs only that root's public key (doc/bee.md, KEYS).
;
;   (seal-key 0)                        a fresh [seed pub], off /dev/urandom
;   (seal-keytext k) (seal-keyof s)     a key as text, and back -> [seed pub] | ()
;   (seal-keywrite path k)              a new file, 0600, never over one -> 1 | a reason
;   (seal-keyread path)                 -> [seed pub] | a reason
;   (seal-card k fields)                fields, [key value] pairs, signed by k: the card's text
;   (seal-chain s)                      a chain's text -> its cards | a reason
;   (seal-check s root now revoked)     the leaf's fields as a tablet | a reason
;
; a card's fields are lineage, name, kind (cell | box), pub, issued and expires (seconds),
; then the signer's parent and sig, which seal-card writes. keys are lowercase hex, 64
; digits; sig is 128. cards in a chain are parted by a blank line. a cell's name is
; NAME@BOX, BOX its signer's name, so no box speaks for another's sessions.
(module (seal seal-key seal-keytext seal-keyof seal-keywrite seal-keyread seal-card seal-chain seal-check)
(borrow 'posix)

(: sl-hex (cite 'tls 'hex)
   sl-unhex (cite 'tls 'unhex)
   sl-rnd (cite 'tls 'rnd)
   sl-pub (cite 'ssh 'ed-pub)
   sl-sign (cite 'ssh 'ed-sign)
   sl-verify (cite 'ssh 'ed-verify)
   sl-fields ["lineage" "name" "kind" "pub" "issued" "expires"]

   ; n bytes of lowercase hex and nothing else: hex of its bytes spells it back
   (sl-hex? s n) (string? s && #s = 2 * n && sl-hex (sl-unhex s) = s)
   (sl-num? s) (string? s && 0 < #s && all (c \ 47 < c < 58) (map s ^#s))
   (sl-num s) (foldl (\ a c (a * 10 + c - 48)) 0 (map s ^#s))
   ; a line's key and value, split at the first space -> [k v] | ()
   (sl-sp l i) (? (#l <= i) -1 (l i = 32) i (sl-sp l (i + 1)))
   (sl-kv l) (: i (sl-sp l 0) (? (0 < i && i + 1 < #l) [(snip l 0 i) (snip l (i + 1) #l)]))
   (sl-dup? ks) (: s (sort ks) (any (i \ s i = s (i + 1)) ^(#s - 1)))
   (sl-text ls) (foldl (\ a l (a + l + "\n")) "" ls)

   (seal-key _) (: s (sl-rnd 32) [s (sl-pub s)])
   (seal-keytext k) ("seed " + sl-hex <k + "\npub " + sl-hex (k 1) + "\n")
   (seal-keyof s)
    (: kv (map sl-kv (filter (l \ 0 < #l) (lines s)))
       (? (#kv = 2 && all two? kv && <<kv = "seed" && <(kv 1) = "pub"
           && sl-hex? (<kv 1) 32 && sl-hex? (kv 1 1) 32)
          (: sd (sl-unhex (<kv 1)) pb (sl-unhex (kv 1 1))
             (? (sl-pub sd = pb) [sd pb]))))
   ; written beside itself and renamed in, so a reader never meets half a key
   (seal-keywrite path k)
    (? (two? (stat path)) (path + " is already there")
       (: tmp (path + ".new" + show (getpid 0))
          fd (openfd tmp 3)
          (? !(charm? fd) ("cannot create " + tmp)
             (: p (fdopen fd) _ (say p (seal-keytext k)) _ (close p)
                (? (nom? (rename tmp path)) (: _ (unlink tmp) ("cannot rename to " + path)) 1)))))
   (seal-keyread path)
    (: r (uread path)
       (? !(two? r) ("cannot read " + path)
          (: k (seal-keyof <>r) (two? k ? k (path + " is not a key")))))

   ; the fields as given, then parent, then sig over every line above it
   (seal-card k fields)
    (: body (sl-text (map (f \ <f + " " + f 1) (fields + [["parent" (sl-hex (k 1))]])))
       (body + "sig " + sl-hex (sl-sign <k (k 1) body) + "\n"))

   ; one card's lines -> [fields-tablet signed-text sig-bytes] | a reason
   (sl-card ls)
    (: kv (map sl-kv ls) last (kv (#kv - 1))
       ks (map cap (filter two? kv))
       (? !(all two? kv) "a card line is not `key value`"
          (sl-dup? ks) "a card names a field twice"
          !(<last = "sig" && sl-hex? (last 1) 64) "a card does not end in its sig"
          [(foldl (\ t f (pin t <f (f 1))) {} kv) (sl-text (take (#ls - 1) ls)) (sl-unhex (last 1))]))
   (seal-chain s)
    (: ps (foldl (\ a l (? (#l = 0) (two? <a ? ([] . a) a) ((<a + [l]) . >a))) [[]] (lines s))
       cs (map sl-card (rev (filter two? ps)))
       (? !(two? cs) "no cards"
          (any string? cs) <(filter string? cs)
          cs))

   ; each card in date, unrevoked, of this lineage and signed by the next one's key; the
   ; last signed by the root itself
   (seal-check s root now revoked)
    (: cs (seal-chain s)
       (link i)
        (: c (cs i) t <c top (i + 1 = #cs) up (? !top <(cs (i + 1)) {})
           (? !(all (f \ string? (peep t f ())) sl-fields) ("card " + show i + " lacks a field")
              (t "lineage" != root) ("card " + show i + " is of another lineage")
              !(sl-hex? (t "pub") 32 && sl-hex? (peep t "parent" "") 32) ("card " + show i + " has a bad key")
              !(sl-num? (t "issued") && sl-num? (t "expires")) ("card " + show i + " has a bad date")
              !(sl-num (t "issued") <= now < sl-num (t "expires")) ("card " + show i + " is out of date")
              (elem (t "pub") revoked || elem (t "parent") revoked) ("card " + show i + " is revoked")
              !(elem (t "kind") ["cell" "box"]) ("card " + show i + " is of no kind")
              (!top && (up "kind" != "box" || up "pub" != t "parent")) ("card " + show i + " is not signed by the next")
              (top && t "parent" != root) ("card " + show i + " is not signed by the root")
              (t "kind" = "cell" && !(!top && ends? (t "name") ("@" + up "name"))) ("card " + show i + " names another box")
              !(sl-verify (sl-unhex (t "parent")) (c 1) (c 2)) ("card " + show i + " has a bad sig")
              ()))
       (? (string? cs) cs
          !(sl-hex? root 32) "the root is not a key"
          (: e (filter string? (map link ^#cs)) (two? e ? <e <<cs)))))
) ; module seal
