{-# LANGUAGE BangPatterns #-}
import Bench
import Data.List (foldl')

-- sum of squares of the odd numbers in [0, N) -- a map/filter/fold pipeline.
-- checksum = 1333333330000. The index source is pinned through `with` (the rep
-- loop's argument) so GHC runs the real O(n) pipeline each rep rather than fold
-- it to a closed form or share it as a CAF.
n :: Int
n = 20000

work :: [Int] -> Integer
work xs = foldl' (\ !a x -> a + x) 0
            [ sq | x <- xs, odd x
                 , let sq = fromIntegral x * fromIntegral x :: Integer ]

main :: IO ()
main = bench "deforest" (\u -> work (with u [0 .. n - 1]))
