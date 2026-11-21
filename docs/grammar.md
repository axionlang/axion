# Minimal Axion grammar — L0/L1 subset (Phase 1 target)

This is the subset the Phase 1 **walking skeleton** must
`parse → typecheck → run` (§17). It doesn't cover the whole language: it fixes the
minimum whose target programs live in [`../examples`](../examples). The syntax is
inherited from Haskell (§0: "inherit the syntax and lineage, not the ecosystem");
the only semantic addition in L1 is the **multiplicity** `%1` / `%0.5` on function
arrows.

File extension: `.axi`. Notation: EBNF; `{ x }` = zero-or-more, `[ x ]` = optional,
`|` = alternative.

```ebnf
module      = [ "module" modName "where" ] { importDecl | decl } ;

importDecl  = "import" [ "qualified" ] modName [ "as" conName ] ;
modName     = conName { "." conName } ;

decl        = dataDecl
            | foreignDecl
            | typeSig
            | funDef ;

(* --- FFI import (§18) --- *)
foreignDecl = "foreign" strLit varName "::" type ;     (* foreign "lib.so" func :: Int -> Int *)
            | "foreign" varName "::" type ;            (* foreign func :: Int -> Int       *)

(* --- Data type declarations (L0; linear fields in L1) --- *)
dataDecl    = "data" conName { varName } "=" con { "|" con } [ deriving ] ;
deriving    = "deriving" "(" conName { "," conName } ")" ; (* Eq, Ord (§tc) *)
con         = conName ( recordBody | { atype } ) ; (* record or positional *)
recordBody  = "{" fieldDecl { "," fieldDecl } "}" ;
fieldDecl   = varName "::" btype [ mult ] ;        (* %1 field = linear     *)
mult        = "%1" | "%0.5" ;

(* --- Signatures: the multiplicity lives on the ARROW (L1) --- *)
typeSig     = varName "::" type ;
type        = btype { arrow btype } ;
arrow       = "->"                         (* normal arrow (%Many)         *)
            | "%1" "->"                     (* full linear ownership        *)
            | "%0.5" "->" ;                 (* fractional permission (L2+)  *)
btype       = atype { atype } ;             (* type application: Buffer U8  *)
atype       = conName                       (* Int, Float, IO, Buffer, U8 … *)
            | varName                       (* type variable                *)
            | "(" type { "," type } ")" ;   (* tuple / parentheses           *)

(* --- Function definitions: equations with pattern matching --- *)
funDef      = varName { pat } rhs
            | varName { pat } guards ;
rhs         = "=" expr [ "where" "{" { funDef } "}" ] ;
guards      = { "|" expr "=" expr } [ "where" "{" { funDef } "}" ] ;

pat         = varName | "_" | literal
            | conName { pat }
            | "(" orPat { "," orPat } ")" ;  (* parentheses or tuple pattern *)
orPat       = pat { "|" pat } ;               (* alternatives: case arms only  *)

(* --- Expressions --- *)
expr        = "let" { funDef } "in" expr
            | "if" expr "then" expr "else" expr
            | "case" expr "of" { alt }
            | "\" { apat } "->" expr           (* lambda; arenas §3          *)
            | "do" { stmt }
            | opExpr ;
opExpr      = appExpr { binop appExpr } ;   (* +  -  *  ==  .  `mod` …       *)
appExpr     = atom { atom } ;               (* application: f x y           *)
atom        = atomBase { recordFields } ;   (* record binds tighter than application *)
atomBase    = varName | conName | literal
            | "(" expr { "," expr } ")"
            | "[" [ expr [ ".." expr ] ] "]" ; (* list literal/range        *)
recordFields = "{" [ fieldAssign { "," fieldAssign } ] "}" ;
fieldAssign  = varName "=" expr ;
(* conName recordFields  → construction: Point { x = 1, y = 2 }              *)
(* expr    recordFields  → update: p { status = "Running" } (Listing 2.1)    *)
recordUpd   = atom "{" varName "=" expr { "," varName "=" expr } "}" ;

alt         = orPat "->" expr ;
stmt        = pat "<-" expr | expr | "let" { funDef } ;

(* --- Lexical --- *)
literal     = intLit | stringLit | charLit ;
varName     = lower { alnum | "'" } ;
conName     = upper { alnum | "'" } ;
binop       = "+" | "-" | "*"                (* Num  (Int/Float): arithmetic     *)
            | "==" | "<" | ">"              (* Ord  (Int/Float): comparisons    *)
            | "." | "<>"                    (* compose / mappend                *)
            | "/."                          (* Float-only division (§4)         *)
            | ".&." | ".|."                 (* bitwise and / or (Int)           *)
            | "+." | "-." | "*."            (* dotted forms (internal rewrite)  *)
            | "<." | ">." | "==."           (* dotted comparisons (internal)    *)
            | "`" varName "`" ;             (* infix function: `mod`        *)
```

An or-pattern `p1 | p2` matches when either alternative does: `Red | Green -> 1`,
`Circle n | Square n -> n`, `Just (1 | 2 | 3) -> "small"`. It is allowed in a `case` arm, at the
top or inside parentheses there; a function's parameters take one pattern each (match with a
`case` instead). Every alternative binds the same variables, at the same type. The compiler gives
each alternative its own arm sharing the one body, so nested alternatives multiply out (at most
64 arms per or-pattern). A string literal can be a whole arm's alternative (`"a" | "b" -> …`)
but not a part of another pattern.

The bitwise `Int` operations use Haskell's `Data.Bits` names and fixities: `shiftL`/`shiftR`
(`infixl 8`), `.&.` (`infixl 7`), `xor` (`infixl 6`), `.|.` (`infixl 5`). The named ones work
prefix (`shiftL x 4`) or infix (`` x `shiftL` 4 ``); a program's own definition of one of those
names wins. A shift amount is taken modulo 64 on every backend, `shiftR` is arithmetic, and
`complement x` (= `xor x (-1)`) flips every bit, and `popCount x` counts the set bits of the 64-bit
two's-complement value (`popCount (-1)` is 64); both are prelude functions a program may redefine.

## Level notes (progressive disclosure L0–L3, §8)

- **L0** — everything above *without* `%1`/`%0.5`: strict, familiar Haskell. The
  targets [`01_hello`](../examples/01_hello.axi) and [`02_fib`](../examples/02_fib.axi).
- **L1** — introduces the multiplicity `%1` (linear ownership) on arrows and
  fields. Targets [`03_linear_buffer`](../examples/03_linear_buffer.axi),
  [`04_process_inplace`](../examples/04_process_inplace.axi),
  [`05_checksum_borrow`](../examples/05_checksum_borrow.axi).
- **L2+** — `%0.5`, `&`, `~`, session types: **outside** Phase 1 and **not**
  expressible in the EDSL bench (GHC's `LinearTypes` only puts multiplicities on
  arrows). They are validated on the Phase 3 formal trail and in the compiler's own
  typechecker.

## Phase 1 acceptance goal

1. The 5 programs in `examples/` do `parse → typecheck → run`.
2. A use-after-consume of a `%1` is **rejected** with `AX0001`
   (see [`error-codes.md`](error-codes.md)) — the same invariant the Phase 0 EDSL
   bench already enforces in `prototype/test/negative/UseTwice.hs`.
