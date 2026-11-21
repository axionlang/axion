# Ownership specification

This page states Axion's ownership rules as numbered, normative rules. [`ownership.md`](ownership.md)
explains them with examples; this page is the reference. Each rule names the fixture under
`axionc/tests/fixtures/` that pins it, and every ownership error prints the rule it enforces
(`= rule: R5 (docs/spec.md#r5)`). A test (`spec_rules_are_pinned`) keeps the rule numbers, the
error codes and the fixtures in step.

Rule numbers are stable: a rule may be reworded, but a number is never reused for another rule.

## 1. Values

<a id="r1"></a>
### R1. Scalars are copied

`Int`, `Float` and `Bool` are copied on every use. No ownership rule applies to them.

Pinned by: `borrow_twice_ok.axi`

<a id="r2"></a>
### R2. Data is affine and freed by the compiler

A `String`, `List`, tuple, record, `data` value with fields, `Integer`, `Array`, `Buffer` or
closure has one owner. The compiler frees it after its last use, on every path, including the
early return of a `<-!`/`<-?` bind. A program never frees data itself.

Pinned by: `linear_move.axi`

<a id="r3"></a>
### R3. Resources are linear

A `Handle a`, `Sock`, `Listener` or session endpoint `Ep s`, and any value with a field of such a
type, is a resource. From where it is bound (`let`, `x <- …` in a `do`, a `%1` parameter), a
resource is consumed **exactly once on every path**, by a function that takes it with `Own` or
`%1`. Not consuming it, on any path, or discarding it (`_ <- …`, a bare statement) is **AX0002**.

Pinned by: `drop_linear.axi`, `struct_mustuse.axi`

## 2. Uses

<a id="r4"></a>
### R4. Reading is free

Passing a value to a position that only reads it (a borrowed parameter, a primitive such as
`strLen`, a `case` scrutinee) lends it. A value can be lent any number of times.

Pinned by: `borrow_twice_ok.axi`

<a id="r5"></a>
### R5. A value moves at most once

Putting a value in an *owned position* moves it: a constructor field, a `%1` argument, an
argument the callee owns (R9–R11), a closure capture, the function result. A value of kind R2
or R3 moved twice (`Pair xs xs`) is **AX0001**.

Pinned by: `heap_duplication.axi`

<a id="r6"></a>
### R6. No use after a move

After a value moved, the program may not read or move it again: **AX0004**. The compiler inserts
a copy instead when the move is its own choice (an owning callee, R10–R11, followed by a later
read); a `%1` parameter written by the user is never copied.

Pinned by: `let_use_after_move.axi`

<a id="r7"></a>
### R7. A lent resource is not consumed

A resource parameter whose type has no `%1` is lent by the caller, who still consumes it.
Consuming it in the callee is **AX0007**. (Data has no such error: the compiler copies, R6.)

Pinned by: `bracket_handle.axi`

## 3. Function signatures

<a id="r8"></a>
### R8. `%1` parameters are owned

A parameter written `%1` belongs to the callee. The caller may not use the argument afterwards
(R6), and the callee consumes it (R3) or lets the compiler free it (R2).

Pinned by: `linear_move.axi`

<a id="r9"></a>
### R9. Other data parameters are borrowed unless the body keeps them

A data parameter without `%1` is borrowed, and the caller keeps its value, unless the body keeps
it. The compiler infers the parameter as owned when the body:

1. stores the parameter whole in a new value or the result (Rule A′);
2. stores a part of it, brought out by a pattern, in a new value, and the parameter's type is
   concrete (Rule A);
3. passes it whole to an owned position of another function (Rule C);
4. returns its own spine (a *view*, such as `tail` or `dropWhile`) (Rule V);
5. is generic in the element type and moves every part it brings out on (Rule B).

`axionc --emit ownership` shows the result for every parameter.

Pinned by: `embed_param_consume.axi`, `field_handoff_consume.axi`, `view_consumes_reclaim.axi`,
`generic_consume_box.axi`, `tuple_param_borrow.axi`

<a id="r10"></a>
### R10. A returned part is lent back

A function that returns a part of a borrowed parameter, and stores none, keeps the parameter
borrowed. The part comes back as a borrow when every path returns one; when another path returns
a fresh value, it is copied on the paths that return the part.

Pinned by: `accessor_keeps_arg.axi`, `mixed_param_return_reclaim.axi`

<a id="r11"></a>
### R11. `fst` and `snd` on a variable read it

`fst x` and `snd x`, applied to a variable, only read `x`. Applied to any other expression, they
take the tuple and free the other component.

Pinned by: `tuple_accessors_borrow.axi`

## 4. Patterns

<a id="r12"></a>
### R12. A pattern on an owned value moves its parts out

A `case` (or a clause head) on a value the function owns hands each bound part to its binder,
which then owns it (R2); parts bound to `_` are freed.

Pinned by: `case_extract_escape.axi`

<a id="r13"></a>
### R13. A pattern on a borrowed value lends its parts

The parts bound out of a borrowed value are borrowed too. Moving such a part into an owned
position copies it, so the caller's value and the new one each own their own.

Pinned by: `nested_borrowed_embed.axi`, `borrowed_tuple_field_consume.axi`

## 5. Closures and local functions

<a id="r14"></a>
### R14. A closure owns its captures

A lambda or partial application owns what it captures, keeps it alive until its last call, and
is freed after that.

Pinned by: `closure_reclaim.axi`

<a id="r15"></a>
### R15. Local functions follow the same rules

A `where` or `let` function is inferred by R8–R13 like a top-level one; a generic local function
is compiled at each type it is used at.

Pinned by: `local_function_ownership.axi`, `let_local_functions.axi`

## 6. The native back end

<a id="r16"></a>
### R16. A generic function may not alias a heap element out of a borrowed list

A generic function that keeps a borrowed parameter and puts one of its elements in its result
(`grabHead xs = case xs of Cons y _ -> Just y`) would leave the element with two owners at a heap
element type. A native build at such a type stops with **AX0912**; the interpreter runs it.
Prelude consumers (`filter`, `take`, `head`, …) avoid this by owning their list, and a `filter`
whose predicate is a known function or lambda, also through a closure parameter, is specialized
so its kept elements move.

Pinned by: `user_alias_borrow.axi`, `filter_heap_reject.axi` (now accepted)

<a id="r17"></a>
### R17. A native array of heap values needs a concrete element type

A native `Array` of heap values has value semantics (reads copy) at a concrete element type. A
generic `Array a` used at a heap type, or an array of values that cannot be copied, is
**AX0914**; the interpreter runs it.

Pinned by: `array_heap_elem_reject.axi`

## 7. What is checked

<a id="r18"></a>
### R18. Every native build passes the drop-balance verifier

After all inference and lowering, `axionc/src/verify.rs` re-checks the final program. A possible
double free or use after free is **AX0910**; a value not freed on some path is **AX0911**. The
code is emitted only if the verifier accepts it. `--allow-leaks` tolerates AX0911,
`--no-verify` skips the verifier, and `--certified` refuses both.

The rules R1–R17 are implemented by inference that is *not* trusted: a mistake in it is caught
here, as a refused build, not as unsafe code. The verifier's judgment is modeled in Lean
(`metatheory/`), and `metatheory/model-trace.sh` checks that the model and the verifier agree on
the corpus. [`GUARANTEE.md`](../metatheory/GUARANTEE.md) states exactly what is proven.

Pinned by: `cond_owned_temp.axi`, `borrowed_list_elem_consume.axi`

<a id="r19"></a>
### R19. Foreign code is trusted

`Own`/`Borrow` annotations on `foreign` imports, buffer sizes and the C functions themselves are
outside the checks. `axionc --emit ffi` lists every import and call site.

Pinned by: `ffi_handle.axi`
