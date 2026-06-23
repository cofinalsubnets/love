import Bench

-- binary-trees allocation/GC stress (see bench/benches/tree.py). checksum = 2^D-1.
data Tree = Leaf | Node Tree Tree

mk :: Int -> Tree
mk d = if d == 0 then Leaf else Node (mk (d - 1)) (mk (d - 1))

ck :: Tree -> Integer
ck Leaf         = 0
ck (Node l r)   = 1 + ck l + ck r

main :: IO ()
main = bench "tree" (\u -> ck (mk (with u 16)))
