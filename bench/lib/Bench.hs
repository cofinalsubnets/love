-- haskell benchmark harness -- mirrors bench/bench.l, lib/bench.py, lib/bench.jl.
-- bench name work auto-scales the repetition count (doubling until one timed
-- batch clears MIN_MS), then prints one line matching the other harnesses:
--     <name> <lang> <reps> <ms> <checksum>
-- work is `Int -> Integer`, fed the VARYING rep index, so each call is opaque and
-- GHC's -O2 (full-laziness / CSE) cannot share one result across reps -- the work
-- genuinely re-runs every rep (it is also forced with `evaluate`). Compiled with
-- -fno-full-laziness as a second guard. BENCH_LANG sets the column label, default
-- "haskell".
{-# LANGUAGE BangPatterns #-}
module Bench (bench, with) where

import Control.Exception (evaluate)
import Data.Time.Clock (getCurrentTime, diffUTCTime)
import System.Environment (lookupEnv)
import System.IO (hSetBuffering, stdout, BufferMode(LineBuffering))
import Numeric (showFFloat)

minMs :: Double
minMs = 200.0

-- A benchmark's `work` body must DEPEND on its `()`
-- argument, or GHC's full-laziness floats the (argument-free) body out of the
-- lambda into a single shared CAF -- computed once, so every rep after the
-- first measures ~0. `with u x` returns `x` unchanged but takes the unit `u`
-- the rep loop feeds in; threading the lambda's argument through `with` pins the
-- body inside the lambda, so the full work re-runs every rep. NOINLINE also
-- keeps `x` opaque (no constant-folding / scalar-evolution of an index range).
-- It is polymorphic, so it pins an Int bound, a list source, or a shared input.
-- `work` is fed the VARYING iteration index, and every bench threads it through
-- `with idx <input>` -- `with` returns its 2nd arg but, being NOINLINE and STRICT
-- in the index (the bang), is opaque: GHC can neither prove the result is
-- index-independent (so it can't CSE `work k` across reps into one shared thunk,
-- nor float the body out to a single CAF) nor drop the index as absent. So the
-- full work genuinely re-runs every rep. `with` is polymorphic: an Int bound, a
-- list source, a shared input -- all get pinned to the live index.
{-# NOINLINE with #-}
with :: Int -> a -> a
with !_k x = x

-- One forced call of work AT THE GIVEN INDEX. `evaluate` forces the result in IO
-- so the call really happens; NOINLINE + the live index keep the call site opaque.
{-# NOINLINE runOnce #-}
runOnce :: Int -> (Int -> Integer) -> IO Integer
runOnce !k work = evaluate (work k)

-- Run work over indices 1..reps, threading the result through `sink` so it stays
-- a live data dependency. Return the last checksum.
runReps :: (Int -> Integer) -> Int -> IO Integer
runReps work reps = go 0 1
  where
    go !sink k
      | k > reps  = return sink
      | otherwise = do
          c <- runOnce k work
          go c (k + 1)

bench :: String -> (Int -> Integer) -> IO ()
bench name work = do
  hSetBuffering stdout LineBuffering
  lang <- maybe "haskell" id <$> lookupEnv "BENCH_LANG"
  let loop reps = do
        t0 <- getCurrentTime
        chk <- runReps work reps
        t1 <- getCurrentTime
        let ms = realToFrac (diffUTCTime t1 t0) * 1000.0 :: Double
        if ms >= minMs
          then putStrLn (name ++ " " ++ lang ++ " " ++ show reps ++ " "
                              ++ showFFloat (Just 3) ms "" ++ " " ++ show chk)
          else loop (reps * 2)
  loop 1
