-- Must FAIL (AX0101): a symbolic operator with no definition. `a <?> b` lowers
-- to a call to the function `<?>`, which is not in scope — caught at compile time
-- (like any unbound name) rather than surfacing as a runtime "name not found".
main :: Int
main = 1 <?> 2
