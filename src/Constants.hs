module Constants where

bpm :: Int
bpm = 100

meter :: Int
meter = 4

toLoopLengthSeconds :: Int -> Double
toLoopLengthSeconds bpm = (60.0 / fromIntegral bpm) * (fromIntegral meter)

loopLengthSeconds :: Double
loopLengthSeconds = toLoopLengthSeconds bpm

standardSR :: Int
standardSR = 44100

toLoopLengthFrames :: Int -> Int
toLoopLengthFrames bpm = floor $ (fromIntegral standardSR) * (toLoopLengthSeconds bpm)

loopLengthFrames :: Int
loopLengthFrames = toLoopLengthFrames bpm

desiredLength :: Int
desiredLength = (2 * 60) + 45

desiredLengthLoops :: Int
desiredLengthLoops =
  let loopsPerMinute = (fromIntegral bpm / fromIntegral meter)
      loopsPerSecond = loopsPerMinute / 60.0
      loops = floor (fromIntegral desiredLength * loopsPerSecond)
   in loops
