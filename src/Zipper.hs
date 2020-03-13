module Zipper
( Zipper
, makeZipper
--, set
, push
, cur
, up
, down
, upMaybe
, downMaybe
, removeTop
, zwhere
, toList
, fromList ) where

-- Zipper top current bottom; top is reversed
data Zipper a = Zipper [a] a [a]
  deriving (Eq, Read, Show)

instance Functor Zipper where
  fmap f (Zipper top cur bot) = Zipper (f <$> top)(f cur)  (f <$> bot) 

--empty = Zipper [] []
makeZipper :: a -> Zipper a
makeZipper x = Zipper [] x []

cur (Zipper _ c _) = c

--set :: Zipper a -> a -> Zipper a
--set (Zipper top _ bot) x = Zipper top x bot

push :: Zipper a -> a -> Zipper a
push (Zipper top c bot) x = Zipper top x (c:bot)

up :: Zipper a -> Zipper a
up (Zipper (x:xs) c bot) = Zipper xs x (c:bot)

down :: Zipper a -> Zipper a
down (Zipper top c (x:xs)) = Zipper (c:top) x xs

upMaybe :: Zipper a -> Zipper a
upMaybe z@(Zipper [] _ _) = z
upMaybe z = up z

downMaybe :: Zipper a -> Zipper a
downMaybe z@(Zipper _ _ []) = z
downMaybe z = down z

removeTop :: Zipper a -> Zipper a
removeTop (Zipper _ c bot) = Zipper [] c bot

zwhere :: Zipper a -> (Int, Int)
zwhere (Zipper t _ b) = (length t, length b)

toList :: Zipper a -> [a]
toList (Zipper top c bot) = top ++ [c] ++ bot

fromList :: [a] -> Zipper a
fromList (x:xs) = Zipper [] x xs
