; test/host/casks.l -- a nif's state where its bytes lie at any word's alignment and a collection moves
; them: each in a child, so a crash is a red with its name. CASK_LOVE is the child's command, out/love unset
;   cat test/00-init.l test/host/casks.l | out/love
(borrow '(posix))
(: love (getenv "CASK_LOVE" @ c (string? c ? (: (cut s i j) (? (= i #s) [(snip s j i)] (s i = 32) (snip s j i . cut s (i + 1) (i + 1)) (cut s (i + 1) j)) (cut c 0 0)) ["out/love"]))
   (run src) (hark (love + ["-e" src]))
   ; forty moves: pad a word's garbage more or less, then a major, between one call and the next
   head "(: (pad k) (map (j \\ j) ^k) (mv i) (: _ (pad (i % 5)) (please 1)) "
   space (head + "K (cite 'dsp 'space) n 4000 z (iota n * 0.0) imp ((iota n = 0) * 1.0) P (gem-tray [16] [44100.0 0.0 0.0 0.0 0.0 0.0 0.0 0.01 0.0 1.0 1.0 1.0 1.0 1.0 0.0 0.0]) "
          + "sz (K z z () P) (one f) (: m (cask sz) _ (K z z m P) _ (K imp z m P) (map (i \\ (: _ (f i) (K z z m P))) ^40)) "
          + "a (one (\\ 0)) b (one mv) (puts (all (i \\ two? (b i) && aall (<(a i) = <(b i)) && aall (>(a i) = >(b i))) ^40 ? \"same\" \"not the same\")))")
   limit (head + "L (cite 'dsp 'limit) n 512 z (iota n * 0.9) P (gem-tray [4] [44100.0 1.0 0.5 0.4]) sz (L z z () P) "
          + "(one f) (: m (cask sz) (map (i \\ (: _ (f i) (L z z m P))) ^40)) "
          + "a (one (\\ 0)) b (one mv) (puts (all (i \\ two? (b i) && aall (<(a i) = <(b i))) ^40 ? \"same\" \"not the same\")))")
   opus (head + "on (cite 'ogg 'opus-new) op (cite 'ogg 'opus-packet) (one f) (: s (on 2 0) (map (i \\ (: _ (f i) (op s \"\" 0))) ^40)) "
         + "a (one (\\ 0)) b (one mv) (puts (all (i \\ string? (b i) && 0 < #(b i) && a i = b i) ^40 ? \"same\" \"not the same\")))")
   (ok? r) (<r = 0 && has? >r "same" && !(has? >r "not the same"))
   rs (map (q \ [(q 0) (run (q 1))]) [['space space] ['limit limit] ['opus opus]])
   _ (each rs (q \ (ok? (q 1) ? 0 (puts "casks: \(q 0): \(show (q 1))\n"))))
 (test (ok? (rs 0 1)) (ok? (rs 1 1)) (ok? (rs 2 1))))
(test_fin (), puts "casks: ok", putc 10, 0)
