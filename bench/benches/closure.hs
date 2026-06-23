{-# LANGUAGE BangPatterns #-}
import Bench
import Data.List (foldl')

-- closure / higher-order stress (see bench/benches/closure.py). checksum = sum 3i.
-- We fold over `with u [0..N-1]` (a runtime-built list pinned to the rep loop's
-- argument) rather than a literal range, so GHC cannot recognise the loop as the
-- closed-form series sum(3i) and reduce the whole benchmark to an O(1) literal,
-- nor float it out as a shared CAF. GHC still inlines the monomorphic closures
-- -- an honest "these closures are ~free here" result over an actual O(n) loop.
twice :: (a -> a) -> a -> a
twice f = \x -> f (f x)

adder :: Int -> Int -> Int
adder i = \x -> x + i

n :: Int
n = 100000

work :: [Int] -> Integer
work = foldl' (\ !s i -> s + fromIntegral (twice (adder i) i)) 0

main :: IO ()
main = bench "closure" (\u -> work (with u [0 .. n - 1]))
