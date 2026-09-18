:Namespace bench
⍝ Dyalog APL benchmark harness -- mirrors lib/bench.py.
⍝ (work Run) name  auto-scales the repetition count (doubling until the timed
⍝ batch clears MIN_MS = 200), then times that count ONCE MORE and writes the
⍝ SECOND run -- the scaling runs pay the fixed per-process costs (JIT warm-up,
⍝ the heap's first growth), which otherwise ride on whichever power of two the
⍝ doubling landed on. one line per bench, matching the other harnesses:
⍝     <name> <lang> <reps> <ms> <checksum>
⍝ `work` is the work function (a dfn or tradfn), called as `work 0` and returning
⍝ the checksum; its dummy argument is ignored. BENCH_LANG sets the column label
⍝ (default "apl"). Wall-clock comes from ⎕AI[3] (elapsed ms; ⎕IO←1 so the index
⍝ selects the elapsed-time element). The line is written with ⎕NPUT so it ends in
⍝ a clean LF (a bare ⎕← terminates with CR under dyalogscript, which would taint
⍝ the trailing checksum field). The result is returned shy-style: assign it (or
⍝ ⎕← it) at the call site if you also want it echoed.

∇ z←(work Run)name;reps;t0;ms;chk;i;lang;⎕PP;⎕IO
  ⎕IO←1 ⋄ ⎕PP←17
  lang←2 ⎕NQ'.' 'GetEnvironment' 'BENCH_LANG'
  :If 0=≢lang ⋄ lang←'apl' ⋄ :EndIf
  reps←1
  :Repeat
    t0←⎕AI[3]
    :For i :In ⍳reps ⋄ chk←work 0 ⋄ :EndFor
    ms←⎕AI[3]-t0
    :If ms≥200
      t0←⎕AI[3]                                    ⍝ warm: time the settled count again
      :For i :In ⍳reps ⋄ chk←work 0 ⋄ :EndFor
      ms←⎕AI[3]-t0
      :Leave
    :EndIf
    reps←reps×2
  :Until 0
  z←name,' ',lang,' ',(⍕reps),' ',(⍕ms),' ',(⍕chk)
  (⊂z)⎕NPUT'/dev/stdout' 1
∇
:EndNamespace
