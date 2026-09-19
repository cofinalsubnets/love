; grid -- the column layout ls and `love verbs` share. every answer below is GNU
; ls's own, read off `COLUMNS=n ls -C` and `ls -x` over the same names: ragged
; columns, the widest count that fits, and a pad that elides onto tab stops.
; test/gate/lscmp.sh compares the whole flag matrix against a GNU that is installed;
; this is the part of the claim that runs without one.
(: grid-lay (cite 'grid 'lay)
   (grid-cells ns) (map (n \ n . #n) ns)
   (grid-d ns w) (grid-lay (grid-cells ns) w 1)        ; down the columns
   (grid-a ns w) (grid-lay (grid-cells ns) w 0)        ; across the rows
   grid-A ["a" "bb" "ccc" "dddd" "eeeee"]
   grid-B ["a" "bbb" "big" "dangling" "empty" "hello-there" "link" "old" "sub" "x" "zero"]
   grid-C ["alpha" "beta" "delta" "epsilon" "eta" "gamma" "theta" "zeta"])

(test
 ; --- the two fills, and the ragged widths ------------------------------------------
 (["a  bb  ccc  dddd  eeeee"] = grid-d grid-A 80)
 (["a  bb  ccc  dddd  eeeee"] = grid-a grid-A 80)
 (["a   ccc   eeeee" "bb  dddd"] = grid-d grid-A 20)
 (["a     bb     ccc" "dddd  eeeee"] = grid-a grid-A 20)
 (["a    dddd" "bb   eeeee" "ccc"] = grid-d grid-A 12)
 (["a      bb" "ccc    dddd" "eeeee"] = grid-a grid-A 12)

 ; --- the pad rides tab stops where two of them fit ----------------------------------
 (["a  bbb\tbig  dangling  empty  hello-there  link  old  sub  x  zero"]
  = grid-d grid-B 80)
 (["a    dangling\t  link\tx" "bbb  empty\t  old\tzero" "big  hello-there  sub"]
  = grid-d grid-B 40)
 (["a\t     bbb   big\tdangling  empty" "hello-there  link  old\tsub\t  x" "zero"]
  = grid-a grid-B 40)
 (["a\t     link" "bbb\t     old" "big\t     sub" "dangling     x" "empty\t     zero"
   "hello-there"]
  = grid-d grid-B 20)
 (["a      bbb" "big    dangling" "empty  hello-there" "link   old" "sub    x" "zero"]
  = grid-a grid-B 20)
 (["alpha  delta\teta    theta" "beta   epsilon\tgamma  zeta"] = grid-d grid-C 40)
 (["alpha\t eta" "beta\t gamma" "delta\t theta" "epsilon  zeta"] = grid-d grid-C 20)

 ; --- one column is always on offer, and nothing ever hangs off the end ---------------
 (grid-B = grid-d grid-B 12)            ; the widest name alone outgrows the screen
 (grid-B = grid-a grid-B 12)
 (grid-A = grid-d grid-A 9)
 (grid-A = grid-d grid-A 0)             ; ..a screen of no width included
 (["one"] = grid-d ["one"] 80)
 !(grid-d () 80)                          ; no cells, no lines

 ; --- a cell's width is its own and not its text's: sgr takes up no screen ------------
 (["\e[1;34ma\e[0m  bb"] = grid-lay [("\e[1;34ma\e[0m" . 1) ("bb" . 2)] 80 1))
