import Bench
-- closures escape into an array, then applied through it (non-inlinable). checksum = sum 3i.
def twice (f : Int → Int) : Int → Int := fun x => f (f x)
def adder (i : Int) : Int → Int := fun x => x + i
def N : Nat := 100000
def main : IO Unit := bench "closure" (fun z => Id.run do
  let mut fns : Array (Int → Int) := Array.mkEmpty (N + z)
  for i in [0 : N + z] do
    fns := fns.push (twice (adder (Int.ofNat i)))
  let mut s : Int := 0
  for i in [0 : N + z] do
    s := s + fns[i]! (Int.ofNat i)
  return s)
