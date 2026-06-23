{-# LANGUAGE BangPatterns #-}
import Bench
import qualified Data.Map.Strict as M

-- Bell numbers in base 36 (see bench/benches/bell.py). Fresh memo per rep.
-- checksum = total characters across all rendered lines until one exceeds the
-- limit. Needs bignums -- Integer (native) handles the large intermediates.

base :: Integer
base = 36

-- factorial (Python memoises only for speed; the direct product is exact).
fact :: Integer -> Integer
fact n = product [2 .. n]

choose :: Integer -> Integer -> Integer
choose n k = fact n `div` (fact k * fact (n - k))

-- bell i from a memo holding bell 0 .. i-1.
bellAt :: M.Map Int Integer -> Int -> Integer
bellAt m i
  | i < 2     = 1
  | otherwise = sum [ choose (fromIntegral i - 1) (fromIntegral k) * (m M.! k)
                    | k <- [0 .. i - 1] ]

-- base-36 rendered length of n (>=1); 0 -> 0, matching `while n > 0`.
show36len :: Integer -> Int
show36len = go 0
  where
    go !acc n | n <= 0    = acc
              | otherwise = go (acc + 1) (n `div` base)

-- Drive i upward, growing the memo on demand (fresh per rep), summing the
-- rendered lengths until one exceeds the limit.
bellRun :: Int -> Integer
bellRun limit = go 0 M.empty 0
  where
    go i memo !total =
      let v     = bellAt memo i
          memo' = M.insert i v memo
          len   = show36len v
      in if len > limit
           then total
           else go (i + 1) memo' (total + fromIntegral len)

main :: IO ()
main = bench "bell" (\u -> bellRun (with u 280))
