module Affinity (affinityMain) where

import System.Directory (listDirectory)
import System.Random

import Arrangement
import Constants
import Graph
import Looper
import Sound
import Util

affinityMain :: Int -> IO ()
affinityMain seed = do
  let g :: Graph Int
      --g = add (add (add empty 3 4) 1 2) 1 3
      g = add (add empty 3 4) 1 2
  msp g
  msp $ showComponents $ components g
  startLooper
  msp "aff hi"

_affinityMain seed = do
  let rand = mkStdGen seed
  loopFilenames <- fmap (map ("loops/"++)) $ listDirectory "loops"
  let someLoopFilenames = map (loopFilenames !!) $ take 4 $ randomRs (0, length loopFilenames - 1) rand
  msp someLoopFilenames
  loops <- mapM readSound someLoopFilenames
  msp loops
  let arrangement :: Arrangement
      arrangement = rep 4 $ parArrangement (map (singleSoundArrangement loopLengthFrames) loops)
  msp arrangement
  stack <- renderArrangement arrangement
  msp "aff hi"
  writeSound "group.wav" stack
  where rep n arr = seqArrangement (take n $ repeat arr)
