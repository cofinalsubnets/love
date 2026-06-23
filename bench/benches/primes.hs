{-# LANGUAGE BangPatterns #-}
import Bench

isPrime :: Int -> Bool
isPrime n = go 2
  where
    go !d
      | d * d > n      = True
      | n `mod` d == 0 = False
      | otherwise      = go (d + 1)

count :: Int -> Int -> Integer
count lo hi = go lo 0
  where
    go !n !c
      | n >= hi   = c
      | isPrime n = go (n + 1) (c + 1)
      | otherwise = go (n + 1) c

main :: IO ()
main = bench "primes" (\u -> count (with u 2) (with u 30000))
