; the rung-4 gate: a lush pipeline of kore tools on the kernel.
; the engine parts (job..eval, in cat order) load just before this file, so
; sh-line is the shell -- the same door test/host/sh.l reads on the host. the
; tail redirects onto the rung-2 tree and is read back; the tree is restored.

(borrow 'lush) ; the engine parts above just registered module 'lush
(: shS (sh-new 0))    ; the one shell these laws drive: its state, threaded through

(: (rd p) (open p "r" @ q (port? q ? (slurp q @ s (close q, s))))
   ; wc pads its counts to the byte total's width, so read the number, not the face
   (numof s) ((: (go i acc) (tally s <= i ? acc
                  (s i @ c (48 <= c <= 57 ?
                            (go (i + 1) (10 * acc + (c - 48)))
                            (go (i + 1) acc)))))
              0 0)

   ; the doc's own spelling: kore ls | kore wc -l, the line count = the tree's
   r1 (sh-line shS "kore ls src/apps/kore | kore wc -l > /tmp/l-sh-pipe")
   s1 (rd "/tmp/l-sh-pipe")
   _  (unlink "/tmp/l-sh-pipe")

   ; and a byte-exact tail, where wc's padding is width one
   r2 (sh-line shS "kore echo hi | kore wc -c > /tmp/l-sh-wc")
   s2 (rd "/tmp/l-sh-wc")
   (unlink "/tmp/l-sh-wc",

    test (r1 = 0) (string? s1) (numof s1 = #(readdir "src/apps/kore"))
           (r2 = 0) (s2 = "3\n")))

; no fork aboard: a compound stage -- a function, a ( ) -- runs as a task on a copy of the
; shell's state, so it runs in a pipe and in the background, and what it sets stays its own
(: (lush-krd p) (open p "r" @ q (port? q ? (slurp q @ s (close q, s))))   ; rd is the form above's alone
   _  (sh-line shS "lush_kf() { echo fn; }; lush_kf | kore cat > /tmp/l-sh-fnp")
   s1 (lush-krd "/tmp/l-sh-fnp")
   _  (sh-line shS "lush_kv=p; ( lush_kv=s ); echo $lush_kv > /tmp/l-sh-sub")
   s2 (lush-krd "/tmp/l-sh-sub")
   _  (sh-line shS "( lush_kv=bg; echo $lush_kv > /tmp/l-sh-bg ) & wait; echo $lush_kv >> /tmp/l-sh-bg")
   s3 (lush-krd "/tmp/l-sh-bg")
   ; ..and two shells aboard are two states: one's positionals are not the other's
   ka (sh-new 0) kb (sh-new 0)
   _  (sh-line ka "set -- one") _ (sh-line kb "set -- two three")
   (each ["/tmp/l-sh-fnp" "/tmp/l-sh-sub" "/tmp/l-sh-bg"] unlink,
    test (s1 = "fn\n") (s2 = "p\n") (s3 = "bg\np\n") ((ka 'sh-pos) = ["one"]) ((kb 'sh-pos) = ["two" "three"])))
