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
module      = { decl } ;

decl        = dataDecl
            | typeSig
            | funDef ;

(* --- Data type declarations (L0; linear fields in L1) --- *)
dataDecl    = "data" conName { varName } "=" con { "|" con } ;
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
atype       = conName                       (* Int, IO, Buffer, U8, U32 …   *)
            | varName                       (* type variable                *)
            | "(" type { "," type } ")" ;   (* tuple / parentheses           *)

(* --- Function definitions: equations with pattern matching --- *)
funDef      = varName { pat } rhs
            | varName { pat } guards ;
rhs         = "=" expr [ "where" "{" { funDef } "}" ] ;
guards      = { "|" expr "=" expr } [ "where" "{" { funDef } "}" ] ;

pat         = varName | "_" | literal
            | conName { pat }
            | "(" pat { "," pat } ")" ;      (* parentheses or tuple pattern *)

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

alt         = pat "->" expr ;
stmt        = pat "<-" expr | expr | "let" { funDef } ;

(* --- Lexical --- *)
literal     = intLit | stringLit | charLit ;
varName     = lower { alnum | "'" } ;
conName     = upper { alnum | "'" } ;
binop       = "+" | "-" | "*" | "==" | "." | "<>"
            | "`" varName "`" ;             (* infix function: `mod`        *)
```

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
