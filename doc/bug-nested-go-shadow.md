# open bug: nested define shadowing a sibling nom miscompiles under unfolded pins

found 2026-07-06 building `au rm -r` (crew/utils/fs.l). CORE territory (boxfix /
frame layout / clause machinery) -- the aiutils thread worked around it (distinct
noms) and left this repro for the core thread. delete this file when fixed
(lessons to memory, per the house rule).

## the shape

a body-having `:` that pins, in order: a COMPUTED (non-literal) flag read off a
parsed list, a self-recursive helper (`zap`) whose body opens a nested `:` with a
loop named `go`, a second helper reading the flag, and a SIBLING pin also named
`go`. the inner walk then silently no-ops: `zap`'s recursion inside the nested
`:` answers truthy WITHOUT running zap's body (no effect, no scare), so the
directory never empties and `rmdir` answers ENOTEMPTY.

## the discriminators (all probed on out/host/ai, 2026-07-06)

* flags folded to literals (`r? 1 f? 0`)          -> CORRECT. the pin must stay a
  runtime read (`r? (cap p)` or `f? (caup p)`) to trigger; `fs (caup (cup p))`
  alone (read after the helpers) does NOT trigger.
* inner loop renamed `go` -> `gz`                 -> CORRECT. the sibling-nom
  collision is load-bearing.
* `fl` defined AND called but result unread       -> CORRECT.
* AI_NO_IMAGE=1                                   -> still WRONG (not the image).
* a pure transliteration (charms for paths, no fs nifs) -> CORRECT, so the repro
  below keeps the fs effects; the trigger has more preconditions than the shape
  alone.

## the repro

run: `mkdir t2; printf x > t2/f;` then feed this file to `out/host/ai`.
expect: t2 gone, "answer 1". observed: "rm: cannot remove t2", the inner walk
visits both list states (probed) but the recursive `zap` call between them never
runs zap's body -- k lands truthy without the unlink.

```lisp
(: (udie c m) (: _ (say err m) _ (put err 10) (nap c))
   (udirp q) (: st (stat q) (&& (two? st) (= 16384 (& 61440 (cauup st)))))
   (rm-main as)
    (: (fl a r f) (? (! (two? a)) (L r f a)
                     (= (cap a) "-r") (fl (cup a) 1 f)
                     (= (cap a) "-f") (fl (cup a) r 1)
                     (L r f a))
       p (fl as 0 0)
       r? (cap p) f? (caup p) fs (caup (cup p))
       (zap q)
        (? (udirp q)
           (: (go m ok) (? (! (two? m)) ok
                           (: k (zap (+ q (+ "/" (cap m))))
                              (go (cup m) (? k ok 0))))
              ok (go (readdir q) 1)
              e (rmdir q)
              (&& ok (! e)))
           (! (unlink q)))
       (one q ok)
        (: hit (? r? (zap q) (! (unlink q)))
           (? hit ok
              f? ok
              (: _ (say err (+ "rm: cannot remove " q)) _ (put err 10) 0)))
       (go a ok) (? (two? a) (go (cup a) (one (cap a) ok)) (nap (? ok 0 1)))
       (? (two? fs) (go fs 1)
          f? (nap 0)
          (udie 2 "usage")))
   (rm-main (L "-r" "t2")))
```

## where to look

boxfix claims immunity to shadowing (CLAUDE.md), but the failing read is the
recursive `zap` from INSIDE the nested `:` whose own loop nom collides with a
sibling pin, and only when the earlier flag pins survive folding -- so suspect
the interplay of the cell tablet keying (by nom), the frame slot layout when
kconst folds pins away, and the 3-clause `?` in `one` (the flip pass keeps a
longer clause tail unflipped). the pure transliteration passing says an effect
op (or the nif value shape) is also in the mix.
