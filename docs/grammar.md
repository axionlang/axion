# Gramática mínima da Axión — subconjunto L0/L1 (alvo da Fase 1)

Este é o subconjunto que o **esqueleto ambulante** da Fase 1 tem de fazer
`parse → typecheck → correr` (§17). Não cobre a linguagem toda: fixa o mínimo
cujos programas-alvo estão em [`../examples`](../examples). A sintaxe é herdada
do Haskell (§0: «herda-se a sintaxe e a linhagem, não o ecossistema»); a única
adição semântica em L1 é a **multiplicidade** `%1` / `%0.5` nas setas de função.

Extensão de ficheiro: `.axi`. Notação: EBNF; `{ x }` = zero-ou-mais,
`[ x ]` = opcional, `|` = alternativa.

```ebnf
module      = { decl } ;

decl        = dataDecl
            | typeSig
            | funDef ;

(* --- Declarações de tipo de dados (L0; campos lineares em L1) --- *)
dataDecl    = "data" conName { varName } "=" con { "|" con } ;
con         = conName ( recordBody | { atype } ) ; (* registo ou posicional *)
recordBody  = "{" fieldDecl { "," fieldDecl } "}" ;
fieldDecl   = varName "::" btype [ mult ] ;        (* campo %1 = linear     *)
mult        = "%1" | "%0.5" ;

(* --- Assinaturas: a multiplicidade vive na SETA (L1) --- *)
typeSig     = varName "::" type ;
type        = btype { arrow btype } ;
arrow       = "->"                         (* seta normal (%Many)         *)
            | "%1" "->"                     (* posse linear plena          *)
            | "%0.5" "->" ;                 (* permissão fraccionária (L2+) *)
btype       = atype { atype } ;             (* aplicação de tipos: Buffer U8 *)
atype       = conName                       (* Int, IO, Buffer, U8, U32 …  *)
            | varName                       (* variável de tipo            *)
            | "(" type { "," type } ")" ;   (* tuplo / parênteses          *)

(* --- Definições de função: equações com pattern matching --- *)
funDef      = varName { pat } rhs
            | varName { pat } guards ;
rhs         = "=" expr [ "where" "{" { funDef } "}" ] ;
guards      = { "|" expr "=" expr } [ "where" "{" { funDef } "}" ] ;

pat         = varName | "_" | literal
            | conName { pat }
            | "(" pat { "," pat } ")" ;

(* --- Expressões --- *)
expr        = "let" { funDef } "in" expr
            | "if" expr "then" expr "else" expr
            | "case" expr "of" { alt }
            | "do" { stmt }
            | opExpr ;
opExpr      = appExpr { binop appExpr } ;   (* +  -  *  ==  .  `mod` …      *)
appExpr     = atom { atom } ;               (* aplicação: f x y            *)
atom        = atomBase { recordFields } ;   (* registo liga mais forte que a aplicação *)
atomBase    = varName | conName | literal
            | "(" expr { "," expr } ")"
            | "[" [ expr [ ".." expr ] ] "]" ; (* literal/range de lista   *)
recordFields = "{" [ fieldAssign { "," fieldAssign } ] "}" ;
fieldAssign  = varName "=" expr ;
(* conName recordFields  → construção: Point { x = 1, y = 2 }              *)
(* expr    recordFields  → actualização: p { status = "Running" } (List. 2.1) *)
recordUpd   = atom "{" varName "=" expr { "," varName "=" expr } "}" ;

alt         = pat "->" expr ;
stmt        = pat "<-" expr | expr | "let" { funDef } ;

(* --- Léxico --- *)
literal     = intLit | stringLit | charLit ;
varName     = lower { alnum | "'" } ;
conName     = upper { alnum | "'" } ;
binop       = "+" | "-" | "*" | "==" | "." | "<>"
            | "`" varName "`" ;             (* função infixa: `mod`        *)
```

## Notas de nível (divulgação progressiva L0–L3, §8)

- **L0** — tudo acima *sem* `%1`/`%0.5`: Haskell estrito e familiar. Os alvos
  [`01_hello`](../examples/01_hello.axi) e [`02_fib`](../examples/02_fib.axi).
- **L1** — introduz a multiplicidade `%1` (posse linear) nas setas e campos.
  Alvos [`03_linear_buffer`](../examples/03_linear_buffer.axi),
  [`04_process_inplace`](../examples/04_process_inplace.axi),
  [`05_checksum_borrow`](../examples/05_checksum_borrow.axi).
- **L2+** — `%0.5`, `&`, `~`, session types: **fora** da Fase 1 e **não**
  exprimíveis na bancada EDSL (o `LinearTypes` do GHC só põe multiplicidades nas
  setas). Validam-se no trilho formal da Fase 3 e no typechecker próprio.

## Meta de aceitação da Fase 1

1. Os 5 programas em `examples/` fazem `parse → typecheck → correr`.
2. Um uso-após-consumo de um `%1` é **rejeitado** com `AX0001`
   (ver [`error-codes.md`](error-codes.md)) — o mesmo invariante que a bancada
   EDSL da Fase 0 já impõe em `prototype/test/negative/UseTwice.hs`.
