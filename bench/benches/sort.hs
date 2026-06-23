{-# LANGUAGE BangPatterns #-}
import Bench
import Data.List (sort, foldl')

-- sort N pseudo-random ints (MINSTD LCG), order-dependent rolling-hash checksum.
n :: Int
n = 5000

-- build the N LCG values: x_{k+1} = (16807 * x_k) mod 2147483647, x_0 = 1.
gen :: Int -> [Int]
gen cnt = go 1 cnt
  where
    go _ 0 = []
    go !x k = let x' = (16807 * x) `mod` 2147483647 in x' : go x' (k - 1)

work :: Int -> Integer
work cnt =
  let dat = sort (gen cnt)
  in foldl' (\ !h v -> (h * 31 + fromIntegral v) `mod` 1000000007) 0 dat

main :: IO ()
main = bench "sort" (\u -> work (with u n))
