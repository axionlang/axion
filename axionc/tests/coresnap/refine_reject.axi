   --> axionc/tests/fixtures/refine_reject.axi:12:21
   --> axionc/tests/fixtures/refine_reject.axi:16:56
   --> axionc/tests/fixtures/refine_reject.axi:20:32
   --> axionc/tests/fixtures/refine_reject.axi:24:38
   --> axionc/tests/fixtures/refine_reject.axi:28:36
   --> axionc/tests/fixtures/refine_reject.axi:32:30
   |
   |
   |
   |
   |
   |
   |                                                        ^ must satisfy `0 <= i && i < (len a)`
   |                                      ^ must satisfy `0 <= i`
   |                                    ^ must satisfy `0 <= i`
   |                                ^^^^^ must satisfy `0 <= i`
   |                              ^ this result must satisfy `0 <= r`
   |                     ^ must satisfy `0 <= i && i < (len a)`
  = help: known here: 0 <= len a, len a <= 0 + 1152921504606846976
  = help: known here: i <= len a, 0 <= len a, len a <= 0 + 1152921504606846976
  = help: known here: k <= 0 - 1
  = help: known here: x <= 0
  = help: nothing is known here about these values; add a condition (`if i < len a then …`) or a refinement on the caller's parameters
  = help: nothing is known here about these values; add a condition (`if i < len a then …`) or a refinement on the caller's parameters
12 | noFacts a k = get a k
16 | offByOne a i = if 0 <= i && i <= lenArray a then get a i else 0
20 | wraps k = if k >= 0 then next (k + 1) else 0
24 | floatFact y k = if y > 0.0 then next k else 0
28 | wrongBranch k = if k < 0 then next k else 0
32 | neg x = if x > 0 then x else x
error[AX0600]: cannot prove `0 <= i && i < (len a)` for the argument `i` of `get`
error[AX0600]: cannot prove `0 <= i && i < (len a)` for the argument `i` of `get`
error[AX0600]: cannot prove `0 <= i` for the argument `i` of `next`
error[AX0600]: cannot prove `0 <= i` for the argument `i` of `next`
error[AX0600]: cannot prove `0 <= i` for the argument `i` of `next`
error[AX0600]: cannot prove the result refinement `0 <= r`
