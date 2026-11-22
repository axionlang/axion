   --> axionc/tests/fixtures/total_reject.axi:10:27
   --> axionc/tests/fixtures/total_reject.axi:13:16
   --> axionc/tests/fixtures/total_reject.axi:18:1
   --> axionc/tests/fixtures/total_reject.axi:23:31
   --> axionc/tests/fixtures/total_reject.axi:26:13
   --> axionc/tests/fixtures/total_reject.axi:29:12
   --> axionc/tests/fixtures/total_reject.axi:32:1
   --> axionc/tests/fixtures/total_reject.axi:39:43
   --> axionc/tests/fixtures/total_reject.axi:43:1
   --> axionc/tests/fixtures/total_reject.axi:48:33
   |
   |
   |
   |
   |
   |
   |
   |
   |
   |
   |                                           ^^^^^^^^^ this call may not terminate
   |                                 ^^^^^^^^^^^^^^^^^^^ this call may not terminate
   |                               ^^^^^^^^^^^^^^ calls a function that is not total
   |                           ^^^^^^^^^^^^^^ this call may not terminate
   |                ^ may fail at run time
   |             ^^^^^^ calls a function that is not total
   |            ^^^^^^^^^ may fail at run time
   | ^ may fail at run time
   | ^ may fail at run time
   | ^ may fail at run time
  --> axionc/tests/fixtures/total_reject.axi:6:10
  = help: a total function must return on every input: cover every pattern, guard against an out-of-range index or a zero divisor (`if i < lenArray a then …`), and do not end the program
  = help: a total function must return on every input: cover every pattern, guard against an out-of-range index or a zero divisor (`if i < lenArray a then …`), and do not end the program
  = help: a total function must return on every input: cover every pattern, guard against an out-of-range index or a zero divisor (`if i < lenArray a then …`), and do not end the program
  = help: a total function must return on every input: cover every pattern, guard against an out-of-range index or a zero divisor (`if i < lenArray a then …`), and do not end the program
  = help: a total function must return on every input: cover every pattern, guard against an out-of-range index or a zero divisor (`if i < lenArray a then …`), and do not end the program
  = help: a total function's recursive calls must make some argument smaller: a value a pattern took apart, or an `Int` that is `>= 0` there and decreases (or counts up to a bound: `if i < n then go (i + 1) n`). The facts on the path to the call — `if`/guard conditions and refinements — are what is known.
  = help: a total function's recursive calls must make some argument smaller: a value a pattern took apart, or an `Int` that is `>= 0` there and decreases (or counts up to a bound: `if i < n then go (i + 1) n`). The facts on the path to the call — `if`/guard conditions and refinements — are what is known.
  = help: a total function's recursive calls must make some argument smaller: a value a pattern took apart, or an `Int` that is `>= 0` there and decreases (or counts up to a bound: `if i < n then go (i + 1) n`). The facts on the path to the call — `if`/guard conditions and refinements — are what is known.
  = help: a total function's recursive calls must make some argument smaller: a value a pattern took apart, or an `Int` that is `>= 0` there and decreases (or counts up to a bound: `if i < n then go (i + 1) n`). The facts on the path to the call — `if`/guard conditions and refinements — are what is known.
  = help: everything a total function uses must be total too; declare it total to see why it is not, or use another function
  = help: everything a total function uses must be total too; declare it total to see why it is not, or use another function
  |
  |          ^^^^^^^^^^^ this call may not terminate
10 | upTo i n = if i <= n then upTo (i + 1) n else i
13 | firstJust xs = case xs of
18 | sign x
23 | quit n = if n > 0 then n else die "negative"
26 | useSpin n = spin n + 1
29 | half a b = a `div` b
32 | sel (Circle r) = r
39 | selfApply n = if n <= 0 then 0 else apply selfApply (n - 1)
43 | floatGuard x
48 | floatLoop x = if x <. 10.0 then floatLoop (x +. 1.0) else x
6 | spin n = spin (n + 1)
error[AX0700]: `floatLoop` is declared total, but cannot show that the recursion of `floatLoop` terminates: no argument gets smaller on every cycle of calls
error[AX0700]: `selfApply` is declared total, but `selfApply` is used as a value inside its own recursion, so its calls cannot be followed
error[AX0700]: `spin` is declared total, but cannot show that the recursion of `spin` terminates: no argument gets smaller on every cycle of calls (tried the size of each argument, and `n`)
error[AX0700]: `upTo` is declared total, but cannot show that the recursion of `upTo` terminates: no argument gets smaller on every cycle of calls (tried the size of each argument, and `i`, `n`, `n - i`, `i - n`)
error[AX0701]: `firstJust` is declared total, but this pattern match does not cover every value (a nested pattern may fail)
error[AX0701]: `floatGuard` is declared total, but its clauses (and their guards) do not cover every argument
error[AX0701]: `half` is declared total, but the divisor `b` may be zero
error[AX0701]: `sel` is declared total, but its clauses (and their guards) do not cover every argument
error[AX0701]: `sign` is declared total, but its clauses (and their guards) do not cover every argument
error[AX0702]: `quit` is declared total, but it calls `die`, which is not total: `exitWith` ends the program
error[AX0702]: `useSpin` is declared total, but it calls `spin`, which is not total: cannot show that the recursion of `spin` terminates: no argument gets smaller on every cycle of calls (tried the size of each argument, and `n`)
