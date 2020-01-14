{-# LANGUAGE BlockArguments #-}
module TUI (tui) where

import Control.Exception (finally)
import System.Posix.IO (stdInput)
import System.Posix.Terminal

import Util

---- jditor

-- Bool is exit?
type KeyboardHandler s = s -> Char -> (s, Bool)
type Displayer s = s -> String

editor :: s -> KeyboardHandler s -> Displayer s -> IO ()
editor initState keyboardHandler displayer = do
  let loop s = do
        c <- getChar
        msp $ "char " ++ (show c)
        let (s', exitP) = keyboardHandler s c
        msp $ displayer s'
        if exitP then return () else loop s'
   in loop initState
  msp "editor done"

----

-- Taken from https://stackoverflow.com/questions/23068218/haskell-read-raw-keyboard-input/36297897#36297897
withRawInput :: Int -> Int -> IO a -> IO a
withRawInput vmin vtime action = do

  {- retrieve current settings -}
  oldTermSettings <- getTerminalAttributes stdInput

  {- modify settings -}
  let newTermSettings = 
        flip withoutMode  EnableEcho   . -- don't echo keystrokes
        flip withoutMode  ProcessInput . -- turn on non-canonical mode
        flip withTime     vtime        . -- wait at most vtime decisecs per read
        flip withMinInput vmin         $ -- wait for >= vmin bytes per read
        oldTermSettings

  {- when we're done -}
  let revert = do setTerminalAttributes stdInput oldTermSettings Immediately
                  return ()

  {- install new settings -}
  setTerminalAttributes stdInput newTermSettings Immediately

  {- restore old settings no matter what; this prevents the terminal
   - from becoming borked if the application halts with an exception
   -}
  action `finally` revert

data State = State [Char]

keyboardHandler :: KeyboardHandler State
keyboardHandler (State cs) c = do
  let cs' = cs ++ [c]
      exitP = c == '\ESC'
   in (State cs', exitP)

displayer :: Displayer State
displayer (State cs) = show cs

tui = withRawInput 0 1 $ do
  -- let loop = do
  --       c <- getChar
  --       msp $ "char " ++ (show c)
  --       if c /= '\ESC' then loop else return ()
  --  in loop
  editor (State []) keyboardHandler displayer
  msp "tui"
