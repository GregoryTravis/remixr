{-# LANGUAGE BlockArguments #-}

module State
  ( State(..)
  , LikeStrategy(..)
  , DislikeStrategy(..)
  , affinities
  , skip
  , like
  , dislike
  --, pushCurrentGroup
  , nextFromStack
  --, combineAffinities
  , pushStack
  , pushStackN
  , edlog
  , renderEdLog
  , loadLoopZound
  , loadLoopZounds
  ) where

import Control.Monad (replicateM)
import Control.Monad.Random.Lazy
import Data.IORef
import Data.List (elemIndex, intercalate)
import Data.Maybe (fromJust)
import qualified Data.Set as S
import Graph
import System.Random

import Hypercube
import Loop
import Looper
import Rand
import Zounds
import Util

editorLogLength = 10

data State =
  State { projectDir :: String
        , collections :: [(Double, String)]
        , loops :: [Loop]
        , likes :: [[Loop]]
        , dislikes :: S.Set [Loop]
        , currentGroup :: [Loop]
        , looper :: Looper
        , soundLoader :: String -> IO Zound
        , editorLog :: [String]
        , stack :: [[Loop]]
        , currentSong :: Maybe (Zound, Zound)  -- First is mix, second is rendered
        , affinityCycle :: Int
        , currentHypercubeMat :: IORef Mat
        , rand :: StdGen
        , strategy :: Maybe String
        , useFiz :: Bool }

-- This is not used; it is required so that KHResults can be compared
instance Eq State where
  a == b = (likes a) == (likes b) && (dislikes a) == (dislikes b) && (currentGroup a == currentGroup b) && (editorLog a) == (editorLog b) && (stack a) == (stack b)
  -- _ == _ = undefined

instance Show State where
  show _ = "[State]"

-- This feels very foolish
instance RandomGen State where
  next s = let (x, newRand) = next (rand s) in (x, s { rand = newRand })
  split s = let (r0, r1) = split (rand s) in (s { rand = r0 }, s { rand = r1})
  -- randomR range s =
  --   let (result, newRand) = randomR range (rand s)
  --       newState = s { rand = newRand }
  --    in (result, newState)
  -- random s =
  --   let (result, newRand) = random (rand s)
  --       newState = s { rand = newRand }
  --    in (result, newState)

-- randomGroup :: State -> IO [Loop]
-- randomGroup s = do
--   groupSize <- getStdRandom (randomR (2,4)) :: IO Int
--   replicateM groupSize (randFromList (loops s))

affinities :: State -> [[Loop]]
affinities s = ((map S.toList) . removeDislikes s . components . fromComponents . likes) s

-- Removing a dislike group from a group means removing of its elements, but
-- *only* if the group contains all of them
removeDislikes :: State -> [S.Set Loop] -> [S.Set Loop]
removeDislikes s groups = filter (not . S.null) (map removeEm groups)
  where removeEm :: S.Set Loop -> S.Set Loop
        removeEm group = foldr (flip removeOneIfContained) group dslikes
        dslikes = map S.fromList $ S.toList $ dislikes s

loopToNums :: State -> S.Set Loop -> [Int]
loopToNums s loops' = map fromJust $ map (flip elemIndex (loops s)) $ S.toList loops'

-- If b is a subset of a, remove just one of its elements from a
removeOneIfContained :: Ord a => S.Set a -> S.Set a -> S.Set a
removeOneIfContained a b = if b `S.isSubsetOf` a then withoutB else a
  where withoutB = S.delete someB a
        someB = head $ S.toList b

-- Remove b from a, but only if b is a subset of a
differenceIfContained :: Ord a => S.Set a -> S.Set a -> S.Set a
differenceIfContained a b = if b `S.isSubsetOf` a then a `S.difference` b else a

-- if no and >2, split and push
-- if no and <=1, record and pop
-- if yes, record, and incremental or random (choose randomly, 50/50)
-- if pop on stack empty, random
-- plus explicit yes-and-strategy and no-and-strategy
-- - subsets too, even if one probably wouldn't use it
--
-- random
-- incremental
-- subs
-- dnc

-- Set the current group and clear the current song
setCurrentGroup :: State -> [Loop] -> State
setCurrentGroup s group = s { currentGroup = group, currentSong = Nothing }

data LikeStrategy = IncrementalStrategy | RandomStrategy | Incremental2Strategy | Random2Strategy
  deriving Show
data DislikeStrategy = SubsetsStrategy | DNCStrategy
  deriving Show

-- This is just wrong, wrong, wrong
_strat :: Show a => a -> State -> State
_strat strat s = s { strategy = Just $ show strat }

skip :: State -> Maybe LikeStrategy -> State
skip = flip doLikeStrategy

like :: State -> Maybe LikeStrategy -> State
like s strategy | length (currentGroup s) < 2 = doLikeStrategy strategy s 
                | otherwise = doLikeStrategy strategy $ s { likes = currentGroup s : likes s }

dislike :: State -> Maybe DislikeStrategy -> State
-- Don't store a dislike unless it's 2 or 1
dislike s strategy | len >= 1 && len <= 2 = doDislikeStrategy strategy $ s { dislikes = S.insert (currentGroup s) (dislikes s) }
  where len = length $ currentGroup s
dislike s strategy | otherwise = doDislikeStrategy strategy s

doDislikeStrategy :: Maybe DislikeStrategy -> State -> State
-- Can't do this with less than 3
doDislikeStrategy (Just strategy) s | length (currentGroup s) < 3 = doLikeStrategy Nothing s
doDislikeStrategy (Just strategy) s | otherwise = _strat strategy $ nextFromStack $ pushStackN s (theStrategy (currentGroup s))
  where theStrategy = case strategy of SubsetsStrategy -> allSubs
                                       DNCStrategy -> dncs
        -- A sub is the list with one element removed
        allSubs :: [Loop] -> [[Loop]]
        allSubs (x : xs) = [xs] ++ map (x:) (allSubs xs)
        allSubs [] = []
        dncs :: [Loop] -> [[Loop]]
        dncs xs = filter ((>= 2) . length) $ case splitAt (length xs `div` 2) xs of (a, b) -> [a, b]
-- Otherwise, default to DNC
doDislikeStrategy Nothing s | (length $ stack s) > 0 = nextFromStack s
                            | otherwise = doDislikeStrategy (Just DNCStrategy) s

doLikeStrategy :: Maybe LikeStrategy -> State -> State
-- If explicit, do that
doLikeStrategy (Just strategy) s =
  let (group, s') = doStrategy strategy s
   in _strat strategy $ setCurrentGroup s' group
  where doStrategy IncrementalStrategy = incrementallyDifferentGroup
        doStrategy RandomStrategy = randomGroup
        doStrategy Incremental2Strategy = incrementallyDifferentGroup2
        doStrategy Random2Strategy = randomGroup2
-- ORIG DEMO
-- -- If not, pop if you can
-- doLikeStrategy Nothing s | (length $ stack s) > 0 = nextFromStack s
-- -- Otherwise, pick randomly
-- doLikeStrategy Nothing s | otherwise =
--   let (strategy, s') = randFromListPure s [IncrementalStrategy, RandomStrategy]
--    in doLikeStrategy (Just strategy) s'
-- AFF 2.0
doLikeStrategy Nothing s = doLikeStrategy (Just Incremental2Strategy) s

incrementallyDifferentGroup :: State -> ([Loop], State)
incrementallyDifferentGroup s
  | length (currentGroup s) == 0 = ([], s)
  | otherwise = flip runRand s $ do
      loopToReplace <- liftRand $ flip randFromListPure [0..length (currentGroup s)-1]
      newLoop <- liftRand $ flip randFromListPure (loops s)
      return $ replaceInList (currentGroup s) loopToReplace newLoop

randomGroup :: State -> ([Loop], State)
randomGroup s =
  let foo :: State -> (Int, State)
      foo s = randomR (4, 8) s
      fooR :: Rand State Int
      fooR = liftRand foo
      ai :: Int
      ss' :: State
      lrr :: (Int, Int) -> Rand State Int
      lrr (a, b) = liftRand (randomR (a, b))
      --(ai, ss') = runRand (liftRand (randomR (4, 8))) s
      (ai, ss') = runRand (lrr (4, 8)) s
      --(ai, ss') = runRand (lrr (4, 8) >>= lrr (20, 20000)) s
   in flip runRand s $ do
        count <- liftRand $ randomR (4::Int, 8)
        seed <- liftRand $ randomR (20::Int, 20000)
        let group = take count (shuffleList seed (loops s))
        return (eesp ("randomGroup", length group, group) group)

-- 4-8 loops:
--   1/2 from most recent like
--   1/4 from set of all liked loops
--   1/4 from pool
incrementallyDifferentGroup2 :: State -> ([Loop], State)
incrementallyDifferentGroup2 = undefined
-- incrementallyDifferentGroup2 s =
--   -- this is dumb, I should use ST, or
--   -- https://hackage.haskell.org/package/MonadRandom-0.5.2/docs/Control-Monad-Random-Lazy.html#v:evalRand
--   let count :: Int
--       s' :: State
--       (count, s') = randomR (4, 8) s
--       numFromMostRecent = count `div` 2
--       numFromLiked = (count - numFromMostRecent) `div` 2
--       numRandom = count - numFromMostRecent - numFromLiked
--       group :: [Loop]

randomGroup2 :: State -> ([Loop], State)
randomGroup2 = undefined

-- pushCurrentGroup :: State -> State
-- pushCurrentGroup s = s { stack = map p2l $ allPairs (currentGroup s) }
--   where p2l (x, y) = [x, y]

nextFromStack :: State -> State
nextFromStack s | (stack s) /= [] = setCurrentGroup (s { stack = gs }) g
                | otherwise = s
  where (g:gs) = stack s

-- -- Take the first two affinities and produce proposals by mixing pairs from
-- -- each of them.
-- combineAffinities :: State -> State
-- combineAffinities s =
--   case acceptable s of (a : b : _) -> nextFromStack $ replaceStack s (combos a b)
--                        _ -> s
--   where combos :: [Loop] -> [Loop] -> [[Loop]]
--         combos xs ys = [xs' ++ ys' | xs' <- clump 2 xs, ys' <- clump 2 ys]

pushStack :: State -> [Loop] -> State
pushStack s x = s { stack = x : stack s }

pushStackN :: State -> [[Loop]] -> State
pushStackN s (x : xs) = pushStack (pushStackN s xs) x
pushStackN s [] = s

replaceStack :: State -> [[Loop]] -> State
replaceStack s stack_ = s { stack = stack_ }

edlog :: State -> String -> State
edlog st msg = st { editorLog = take editorLogLength (msg : editorLog st) }

renderEdLog :: State -> [String]
renderEdLog (State { editorLog = lines }) = reverse lines

loadLoopZound ::State -> Loop -> IO Zound
loadLoopZound s loop = (soundLoader s) (fn loop)
  where fn (Loop filename) = projectDir s ++ "/loops/" ++ filename
loadLoopZounds ::State -> [Loop] -> IO [Zound] 
loadLoopZounds s loops = mapM (loadLoopZound s) loops

