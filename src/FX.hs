module FX
( FX(..)
, applyFX ) where

import External
import Sound
import Util

data FX = NoFX | Highpass Int | Lowpass Int | Chorus | Band Int Int
  deriving Show

--ssRun :: (String -> String -> [String]) -> (Sound -> IO Sound)
ssRun :: [String] -> (Sound -> IO Sound)
ssRun subcommand sound = runViaFilesCmd "wav" writeSound readSound commander sound
  where commander = \s d -> ["sox", "-G", s, d] ++ subcommand

applyFX :: FX -> Sound -> IO Sound

applyFX NoFX = return

applyFX (Highpass freq) = ssRun ["highpass", "-2", show freq]
applyFX (Lowpass freq) = ssRun ["lowpass", "-2", show freq]

applyFX Chorus = ssRun ["chorus", "0.7", "0.9", "55", "0.4", "0.25", "2", "-t", "60", "0.32", "0.4", "2.3", "-t", "40", "0.3", "0.3", "1.3", "-s"]

applyFX (Band center width) = ssRun ["band", "-n", show center, show width]
