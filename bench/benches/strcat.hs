{-# LANGUAGE BangPatterns #-}
import Bench
import Data.List (foldl')
import Data.Char (chr, ord)

-- build an N-char string by repeated single-char concatenation, then hash it.
-- checksum = 222329890. The build appends a char to the END each step
-- (s ++ [c]), mirroring Python's `s += ch` -- an O(n^2) build, the point of
-- the bench -- rather than prepending.
hmod :: Integer
hmod = 1000000007

n :: Int
n = 4000

build :: Int -> String
build cnt = go 0 ""
  where
    go i s
      | i >= cnt  = s
      | otherwise = go (i + 1) (s ++ [chr (48 + i `mod` 10)])

hash :: String -> Integer
hash = foldl' (\ !h ch -> (h * 31 + fromIntegral (ord ch)) `mod` hmod) 0

work :: Int -> Integer
work cnt = hash (build cnt)

main :: IO ()
main = bench "strcat" (\u -> work (with u n))
