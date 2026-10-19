#!/usr/bin/env -S love -l
; src/tools/waits.l -- who waits. the only code that blocks is the scheduler plus a
; roster of named exceptions, so a new wait reddens the build instead of hanging a test.
; every call to a hook below, in every tracked .c file, must be on the roster (keyed
; on file and function).
;
; it reads the C as written, not the binary: static io_* and z* functions inline away,
; and a call graph read off the image would answer green for want of a caller.
;
; a call is an identifier followed by `(`; the enclosing function is the nearest
; definition at column 0. `Ap(lvm_yield_sw, g)` names Ap: a tail-jump returns to the
; trampoline and the scheduler waits in its own frame, the shape this gate permits.
; `//` comments are stripped, so prose about a wait cannot redden it; block ones are not.
; it sees the hooks by NAME only: a raw read(2) or a hook through a pointer walks past.
; Usage: love src/tools/waits.l file ..   (paths as the roster spells them: repo-relative)
; Exit:  0 = the waits are exactly the roster, 1 = they are not, 2 = usage error.

(borrow 'posix)
(: (die m) (say err "waits: ", say err m, say err "\n", quit 2)

   ; --- what counts as a wait -------------------------------------------------
   hooks ["love_sleep" "wait_fds" "love_fd_drain" "wait_one"]
   (hook? nm) (any (= nm) hooks)
   ; the love.h contract symbols: their bodies are the wait, so only callers outside
   ; the family answer. the runtime's wait_one is ordinary code and answers on the roster.
   (impl? nm) (any (= nm) ["love_sleep" "wait_fds" "love_fd_drain"])

   ; --- the roster: (file function hook why) ---
   roster
   [["src/love/task.c" "wait_one" "wait_fds"
     "the scheduler's one-fd shim -- an lvm_ frame may hold no scratch"]
    ["src/love/task.c" "lvm_yield_sw_mono" "wait_one"
     "the monotask scheduler, parked on one fd"]
    ["src/love/task.c" "lvm_yield_sw_mono" "love_sleep"
     "the monotask scheduler, a timer and no fd"]
    ["src/love/task.c" "yield_sw_wait" "wait_fds"
     "THE wait: every parked task and the nearest timer, one call"]
    ["src/love/io.c" "io_close" "love_fd_drain"
     "the finalizer: a dying port's unsent run. runs inside gc, where nothing can park -- the write side's one remaining unbounded wait"]
    ["src/love/fd.c" "love_fd_say" "love_sleep"
     "a raw fd carries no write run of love's to park behind, so the busy device is waited on -- bounded by its drain"]
    ["test/front/main.c" "love_fd_say" "love_sleep"
     "the test frontend's copy of that row, over a synthetic device whose stall arm counts down per call"]
    ["src/inle/teensy41/main.c" "main" "love_sleep"
     "the panic blink after a fatal shell exit -- nothing runs after it"]
    ["src/inle/doom.c" "DG_SleepMs" "love_sleep"
     "doom's frame pacer: the game loop owns the frame and names the gap itself, with no love task behind it to park -- bounded by the frame, and the freestanding half waits the same way through k_sleep"]]

   ; --- character classes ---
   (idc? c) (97 <= c <= 122 || 65 <= c <= 90 || 48 <= c <= 57 || c = 95)
   (blank? c) (c = 32 || c = 9)
   (inch? s c) (: n #s (go k) (? (n <= k) () (s k = c) 1 (go (k + 1))) (go 0))

   ; --- line helpers ---
   (lines s) (: n #s
                (go start i acc)
                 (? (n <= i) (rev (start < i ? (snip s start i . acc) acc))
                    (s i = 10) (go (i + 1) (i + 1) (snip s start i . acc))
                    (go start (i + 1) acc))
                (go 0 0 ()))
   (rtrim s) (: (go e) (e > 0 && blank? (s (e - 1)) ? (go (e - 1)) e)
                (snip s 0 (go #s)))
   (uncomment s) (: n #s
                    (go i) (? (i + 1 >= n) s
                              (s i = 47 && s (i + 1) = 47) (snip s 0 i)
                              (go (i + 1)))
                    (go 0))

   ; every identifier in s that is immediately followed by `(`
   (calls s) (: n #s
                (end k) (k < n && idc? (s k) ? (end (k + 1)) k)
                (go i acc)
                 (? (n <= i) (rev acc)
                    (idc? (s i))
                     (end i @ j
                        (go j (j < n && s j = 40 ? (snip s i j . acc) acc)))
                    (go (i + 1) acc))
                (go 0 ()))

   ; --- naming the enclosing function ---
   ; a top-level line: column 0, has a paren, not a preprocessor line, comment or brace
   (top? s) (: n #s
               c (n < 1 ? 32 (s 0))
               (n > 0 && !(blank? c) && !(any (= c) [35 47 42 125 41]) && inch? s 40))
   ; the `{` half is load-bearing: the runtime puts the first statement on the header
   ; line, so "ends in ; means prototype" alone would drop the scheduler.
   (header? s) (#s @ n (top? s && (inch? s 123 || !(s (n - 1) = 59))))
   ; ..and the rest declare: a prototype names a hook and calls none.
   (proto? s) (top? s && !(header? s))
   ; a name that is a qualifier or a keyword, never the function being defined
   nonfn ["__attribute__" "if" "while" "for" "switch" "return" "sizeof" "defined"]
   (ident-from s i) (: n #s
                       (go k) (k < n && idc? (s k) ? (go (k + 1)) (snip s i k))
                       (go i))
   (at? s i p) (: m #p
                  (go k) (? (m <= k) 1 (s (i + k) = p k) (go (k + 1)) ())
                  (i + m <= #s && go 0))
   (find s p) (: n #s
                 (go i) (? (n <= i) () (at? s i p) i (go (i + 1)))
                 (go 0))
   ; the first call-shaped identifier not a qualifier -- except `lvm(name)`, love.h's
   ; definition macro, where the name is inside the parens.
   (hdr-name s)
    (: j (find s "lvm(")
       cs (filter (x \ !(any (= x) nonfn)) (calls s))
       (? (j != ()) (ident-from s (j + 4))
          (two? cs) <cs
          (rtrim s)))

   ; --- the scan ---
   ; -> ((file fn hook line) ..), one per distinct (file fn hook), at its first line
   (seen? l k) (any (= k) l)
   (key e) (<e + " " + e 1 + " " + e 2)
   (scan path)
    (: port (open path "r")
       _ (!(hot? port) ? (die ("cannot open " + path)))
       src (slurp port)
       _ (close port)
       (go ls n fn acc)
        (atom? ls ? (rev acc)
           (: line (uncomment (rtrim <ls))
              hdr (header? line)
              fn2 (hdr ? (hdr-name line) fn)
              ; a definition line names its own function, and that is not a call
              hits (impl? fn2 || proto? line ? ()
                    (filter (c \ hook? c && !(hdr && c = fn2)) (calls line)))
              acc2 (foldl (\ a c ([path fn2 c n] @ e
                                    (seen? (map key a) (key e) ? a (e . a))))
                          acc hits)
              (go >ls (n + 1) fn2 acc2)))
       (go (lines src) 1 "" ()))

   ; --- the report ---
   (show2 e) (say out "  ", say out (e 1), say out " -> ", say out (e 2), put out 10)
   ; a found wait points at its line; a roster entry carries its reason
   (showx e) (say out "  ", say out <e, put out 58,
              putbn out (e 3) 10, say out ":", show2 e, 0)
   (show3 r) (say out "  ", say out <r, show2 r,
              say out "      ", say out (r 3), put out 10)
   (llen l) (foldl (\ n _ (n + 1)) 0 l)

   paths >argv
   _ (atom? paths ? (die "usage: waits.l FILE .."))
   found (foldl (\ a p (a + scan p)) () paths)
   fkeys (map key found)
   rkeys (map key roster)
   extra (filter (e \ !(seen? rkeys (key e))) found)
   stale (filter (r \ !(seen? fkeys (key r))) roster)
   (two? extra || two? stale ?
      ((two? extra ?
          (say out "waits: ", putbn out (llen extra) 10,
           say out " call site(s) reach a wait hook and are NOT on the roster:\n",
           each extra showx,
           say out "  -- if this wait is right, put it on the roster in src/tools/waits.l with its reason.\n")
          0),
       (two? stale ?
            (say out "waits: ", putbn out (llen stale) 10,
             say out " roster entry(s) have no call site (stale -- delete them):\n",
             each stale show3)
            0),
       quit 1)
      (say out "waits: all ", putbn out (llen found) 10,
       say out " waits in ", putbn out (llen paths) 10,
       say out " files are the roster\n",
       quit 0)))
