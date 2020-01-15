{-# LANGUAGE TupleSections #-}

module Graph
( Graph
, empty
, add
, addMulti
, components
, showComponents
, showGraphAsComponents ) where

---- Really dumb undirected graph: extremely slow!!

import Data.List (intercalate, nub)
import qualified Data.Map.Strict as M
import qualified Data.Set as S
import Util

data Graph a = Graph (M.Map a (S.Set a))
  --deriving Show

instance (Eq a, Ord a, Show a) => Show (Graph a) where
  show g = show $ edges g

empty = Graph (M.empty)

add :: (Ord a, Show a) => Graph a -> a -> a -> Graph a
add g x y =
  let g' = addKeyIfMissing g x
      g'' = addKeyIfMissing g' y
      (Graph m) = g''
      m' = M.adjust (S.insert x) y m
      m'' = M.adjust (S.insert y) x m'
   -- in eesp (show ("hoy", m, m', m'')) $ Graph m''
   in Graph m''

-- TODO this is a fold
addMulti :: (Ord a, Show a) => Graph a -> [(a, a)] -> Graph a
addMulti g ((x, y) : ps) = addMulti (add g x y) ps
addMulti g [] = g

edges :: (Eq a, Ord a) => Graph a -> [(a, a)]
edges g = nub $ map sortEdge $ directedEdges g

sortEdge :: Ord a => (a, a) -> (a, a)
sortEdge (a, b) | a > b = (b, a)
sortEdge (a, b) | otherwise = (a, b)

-- Includes duplicates
directedEdges :: Ord a => Graph a -> [(a, a)]
directedEdges g@(Graph m) = concat (Prelude.map (nodeEdges g) (M.keys m))

nodeEdges :: Ord a => Graph a -> a -> [(a, a)]
nodeEdges (Graph m) x = map (x,) $ S.toList (m M.! x)

-- This is extremely inefficient; it constructs a size-n component n times
components :: (Eq a, Ord a, Show a) => Graph a -> [S.Set a]
components g = nub $ Prelude.map (closure g) (S.toList (elements g))

showComponents :: Show a => [S.Set a] -> String
showComponents sets = intercalate " " $ map show (map S.toList sets)

showGraphAsComponents :: (Eq a, Ord a, Show a) => Graph a -> String
showGraphAsComponents = showComponents . components

elements :: Ord a => Graph a -> S.Set a
elements (Graph m) = flatten (M.elems m)

closure :: (Ord a, Show a) => Graph a -> a -> S.Set a
closure g x = converge (closure' g) (S.singleton x)

closure' :: (Ord a, Show a) => Graph a -> S.Set a -> S.Set a
closure' (Graph m) xs = xs `S.union` (flatten $ Prelude.map (m M.!) (S.toList xs))

flatten :: Ord a => [S.Set a] -> S.Set a
flatten sets = S.fromList (concat (Prelude.map S.toList sets))

-- I wonder if this doesn't recompute (f x)
converge :: Eq a => (a -> a) -> a -> a
converge f x | (f x) == x = x
converge f x | otherwise = converge f (f x)

addKeyIfMissing :: Ord a => Graph a -> a -> Graph a
addKeyIfMissing g x | graphMember x g = g
addKeyIfMissing (Graph m) x | otherwise = Graph $ M.insert x S.empty m

graphMember :: Ord a => a -> Graph a -> Bool
graphMember x (Graph m) = M.member x m
