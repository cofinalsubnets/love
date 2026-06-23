{-# LANGUAGE BangPatterns #-}
import Bench
import qualified Data.Map.Strict as M
import Data.List (foldl')

-- mutable hash-table throughput (see bench/benches/hash.py). checksum = N*N.
-- Data.Map.Strict (functional, stdlib `containers`) stands in for the mutable
-- dict; the workload (build, sum lookups, increment all, sum again) is the same.
n :: Int
n = 10000

key :: Int -> Int
key i = 97 * i + 1

work :: [Int] -> Integer
work idx =
  let h0 = foldl' (\ !m i -> M.insert (key i) i m) M.empty idx
      a1 = foldl' (\ !a i -> a + fromIntegral (h0 M.! key i)) 0 idx
      h1 = foldl' (\ !m i -> M.adjust (+ 1) (key i) m) h0 idx
      a2 = foldl' (\ !a i -> a + fromIntegral (h1 M.! key i)) a1 idx
  in a2

main :: IO ()
main = bench "hash" (\u -> work (with u [0 .. n - 1]))
