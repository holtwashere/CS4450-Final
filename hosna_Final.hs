{-# OPTIONS_GHC -fwarn-missing-signatures #-}
{-# OPTIONS_GHC -fno-warn-tabs #-}
module Final where

import Prelude hiding (LT, GT, EQ)
import System.IO
import Base
import Data.Maybe
import Data.List
import Operators
import RecursiveFunctionsAST
import RecursiveFunctionsParse
import Test.Hspec
import Control.Exception (evaluate,AsyncException(..))
-- Uncomment the following if you choose to do Problem 3.

import System.Environment
import System.Directory (doesFileExist)
import System.Process
import System.Exit
import System.Console.Haskeline
--        ^^ This requires installing haskeline: cabal update && cabal install haskeline


-----------------
-- The evaluation function for the recursive function language.
-----------------

eval :: Exp -> Env -> Value
eval (Literal v) env                = v
eval (Unary op a) env               = unary  op (eval a env)
eval (Binary op a b) env            = binary op (eval a env) (eval b env)
eval (If a b c) env                 = let BoolV test = eval a env
                                      in if test then  eval b env else eval c env
eval (Variable x) env               = fromJust x (lookup x env)
  where fromJust x (Just v)         = v
        fromJust x Nothing          = errorWithoutStackTrace ("Variable " ++ x ++ " unbound!")
eval (Function x body) env          = ClosureV x body env

eval (Declare decls body) env = eval body newEnv
  where vars = map fst decls
        exps = map snd decls
        values = map (\x -> eval x env) exps
        newEnv = zip vars values ++ env

eval (RecDeclare x exp body) env    = eval body newEnv
  where newEnv = (x, eval exp newEnv) : env
eval (Call fun arg) env = eval body newEnv
  where ClosureV x body closeEnv    = eval fun env
        newEnv = (x, eval arg env) : closeEnv
        
-- Use this function to run your eval solution.
execute :: Exp -> Value
execute exp = eval exp []
-- Example usage: execute exp1

{-

Hint: it may help to remember that:
  map :: (a -> b) -> [a] -> [b]
  concat :: [[a]] -> [a]
when doing the Declare case.

-}

-- Start with empty list and work through, adding variables to list

freeByRule2 :: [String] -> Exp -> [String]

 -- Literals have no variables
freeByRule2 seen (Literal _)	          = []
-- Strip off the operation, pass variable back into the function
freeByRule2 seen (Unary _ e)	          = freeByRule2 seen e
-- Ditto, but with two expressions
freeByRule2 seen (Binary _ e1 e2)	      = (freeByRule2 seen e1) ++ (freeByRule2 seen e2)
-- Stip off Comparison and pass exps back
freeByRule2 seen (If e1 e2 e3)	        = ((freeByRule2 seen e1) ++ (freeByRule2 seen e2)) ++ (freeByRule2 seen e3)
-- If we've seen the variable before, it's bounded, else it's free, add free variable to accumulator list
freeByRule2 seen (Variable x)           = if x `elem` seen then [] else [x]
-- Get all declared variables through accumulator passing
freeByRule2 seen (Declare decls body)   = freeHelper2 seen (Declare decls body) []
-- Multiple declarations are split up and variable is added to list of seen variables
freeByRule2 seen (RecDeclare x e1 e2) = (freeByRule2 (x:seen) e1) ++ (freeByRule2 (x:seen) e2)
-- Pass function body back into the function. Add variable to list of seen variables
freeByRule2 seen (Function x e) = freeByRule2 (x:seen) e
-- Split up expressions
freeByRule2 seen (Call e1 e2) = (freeByRule2 seen e1) ++ (freeByRule2 seen e2)

-- (Second List is acc)
freeHelper2 :: [String] -> Exp -> [String] -> [String]
-- Pull off variable name being declared, pass expression to check for more free variables
-- if not variable return acc, if variable check if variable has been seen, if not seen add to free
-- case 1 if not free add to list of seen, case 2 add to free
freeHelper2 seen (Declare ((x, e1):xs) e2) acc  = (freeByRule2 seen e1) ++ (freeHelper2 seen (Declare xs e2) (x:acc))
-- Plan expression, no new variable being declared
freeHelper2 seen (Declare [] e2) acc            = freeByRule2 (acc ++ seen) e2



-- Code courtesy of Justin Hofer, used with permission

---- Problem 3.
-- Did not do the file IO
repl :: IO ()
repl = do
         putStr "RecFun> "
         iline <- getLine
         process iline

process :: String -> IO ()
process "quit" = return ()
process iline  = do
  putStrLn (v ++ "\n")
  repl
   where e = parseExp iline
         parsed = freeByRule2 [] e -- remove free variables
         v = if (parsed == []) then show (eval e []) else ("Unbound Variables: " ++ show parsed) -- eval if no free variables, print free variables otherwise

exp1, exp2, exp3, exp4, exp5, exp6, facvar, facrec :: Exp

facvar   = parseExp ("var fac = function(n) { if (n==0) 1 else n * fac(n-1) };" ++
                   "fac(5)")

facrec   = parseExp ("rec fac = function(n) { if (n==0) 1 else n * fac(n-1) };" ++
                   "fac(5)")

exp1     = parseExp "var a = 3; var b = 8; var a = b, b = a; a + b"
exp2     = parseExp "var a = 3; var b = 8; var a = b; var b = a; a + b"
exp3     = parseExp "var a = 2, b = 7; (var m = 5 * a, n = b - 1; a * n + b / m) + a"
exp4     = parseExp "var a = 2, b = 7; (var m = 5 * a, n = m - 1; a * n + b / m) + a"         
-- N.b.,                                                  ^^^ is a free occurence of m (by Rule 2)

exp5 = parseExp "var m = 42, n = m; n + m"
exp6 = parseExp ("var n = 1, m = n; a + b")

test_prob1 :: IO ()
test_prob1 = hspec $ do
  describe "Prob1 from Final - Declare" $ do

    context "var a = 3; var b = 8; var a = b, b = a; a + b" $ do
      it "should equal 11" $ do
        execute exp1 `shouldBe` IntV 11

    context "var a = 3; var b = 8; var a = b; var b = a; a + b" $ do
      it "should equal 16" $ do
        execute exp2 `shouldBe` IntV 16

    context "var a = 2, b = 7; (var m = 5 * a, n = b - 1; a * n + b / m) + a" $ do
      it "should equal 14" $ do
        execute exp3 `shouldBe` IntV 14

    context "var a = 2, b = 7; (var m = 5 * a, n = m - 1; a * n + b / m) + a" $ do
      it "should throw *** Exception: Variable m unbound!" $ do
        evaluate (execute exp4) `shouldThrow` anyException
    
    context "var fac = function(n) { if (n==0) 1 else n * fac(n-1) }; fac(5)" $ do
      it "should throw *** Exception: Variable fac unbound!" $ do
        evaluate (execute facvar) `shouldThrow` anyException
    
    context "rec fac = function(n) { if (n==0) 1 else n * fac(n-1) }; fac(5)" $ do
      it "should equal 120" $ do
        execute facrec `shouldBe` IntV 120

test_free2:: IO ()
test_free2 = hspec $ do
  describe "Prob2 from Final - Free Variables Rule 2" $ do

    context "var m = 42, n = m; n + m" $ do
      it "m should be a free variable" $ do
        (freeByRule2 [] exp5) `shouldBe` ["m"]
    
    context "var a = 2, b = 7; (var m = 5 * a, n = m - 1; a * n + b / m) + a" $ do
      it "m should be a free variable" $ do
        (freeByRule2 [] exp4) `shouldBe` ["m"]

    context "var fac = function(n) { if (n==0) 1 else n * fac(n-1) }; fac(5)" $ do
      it "fac should be a free variable" $ do
        (freeByRule2 [] facvar) `shouldBe` ["fac"]

    context "rec fac = function(n) { if (n==0) 1 else n * fac(n-1) }; fac(5)" $ do
      it "fac should not be a free variable" $ do
        (freeByRule2 [] facrec) `shouldBe` []
    
    context "var n = 1, m = n; a + b" $ do
      it "n, a, b should be free variables" $ do
        (freeByRule2 [] exp6) `shouldBe` ["n", "a", "b"]

