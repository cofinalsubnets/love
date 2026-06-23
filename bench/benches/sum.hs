{-# LANGUAGE BangPatterns #-}
import Bench
import Data.List (foldl')

-- build the list 1..100000 then sum it. The whole list is routed through `with`
-- (which also depends on the rep loop's unit argument), so GHC cannot recognise
-- [1..n] as a closed-form arithmetic series and fold the sum to a literal, nor
-- float the body out of the lambda as a shared CAF -- it builds and folds the
-- real O(n) list on every rep.
n :: Int
n = 100000

sumRun :: [Int] -> Integer
sumRun = foldl' (\ !a x -> a + fromIntegral x) 0

main :: IO ()
main = bench "sum" (\u -> sumRun (with u [1 .. n]))
