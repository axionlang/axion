/**
 * Tree-sitter grammar for Axión — highlighting-grade (see README).
 *
 * Mirrors docs/grammar.md and axionc/src/lexer.rs. No external scanner: Haskell-style
 * layout (indentation → blocks) is NOT resolved structurally, so deeply-nested
 * where/let/do/case bodies may parse approximately. The lexical layer — keywords, type
 * vs data constructors, variables, strings, numbers, comments, the `%1` linearity mark —
 * is exact, which is what drives coloring.
 */

const sep1 = (rule, s) => seq(rule, repeat(seq(s, rule)));

module.exports = grammar({
  name: 'axion',

  word: $ => $.variable,
  extras: $ => [/[ \t\r\n]/, $.comment],

  conflicts: $ => [
    [$._aexpr, $._apattern],
    [$._constraint, $._atype],
    [$.constructor_pattern, $._aexpr],
  ],

  rules: {
    source_file: $ => repeat($._declaration),

    // ---- declarations ---------------------------------------------------
    _declaration: $ => choice(
      $.module_header,
      $.import,
      $.data_declaration,
      $.class_declaration,
      $.instance_declaration,
      $.foreign_declaration,
      $.type_signature,
      $.function_equation,
    ),

    module_header: $ => seq('module', $.module_name, 'where'),
    module_name: $ => sep1($.type_constructor, '.'),

    import: $ => seq(
      'import',
      optional('qualified'),
      $.module_name,
      optional(seq('as', $.type_constructor)),
    ),

    data_declaration: $ => seq(
      'data',
      field('name', $.type_constructor),
      repeat($.variable),
      '=',
      sep1($.data_constructor, '|'),
      optional($.deriving),
    ),
    data_constructor: $ => prec.left(seq(
      field('name', $.constructor),
      optional(choice($.record_fields, repeat1($._atype))),
    )),
    record_fields: $ => seq('{', optional(sep1($.field_declaration, ',')), '}'),
    field_declaration: $ => seq($.variable, '::', $._type, optional($.multiplicity)),
    deriving: $ => seq('deriving', '(', sep1($.type_constructor, ','), ')'),

    class_declaration: $ => prec.right(seq(
      'class', optional($.context), field('name', $.type_constructor), $.variable,
      optional(seq('where', repeat($.type_signature))),
    )),
    instance_declaration: $ => prec.right(seq(
      'instance', optional($.context), field('name', $.type_constructor), $._type,
      optional(seq('where', repeat($.function_equation))),
    )),
    context: $ => prec(1, seq(
      choice($._constraint, seq('(', sep1($._constraint, ','), ')')),
      '=>',
    )),
    _constraint: $ => seq($.type_constructor, $.variable),

    foreign_declaration: $ => seq(
      'foreign', optional($.string), field('name', $.variable), '::', $._type,
    ),

    type_signature: $ => prec(2, seq(
      field('name', $.variable), '::', optional($.context), $._type,
    )),

    // ---- types ----------------------------------------------------------
    _type: $ => prec.right(seq($._btype, repeat(seq($.arrow, $._btype)))),
    arrow: $ => choice('->', seq($.multiplicity, '->')),
    _btype: $ => prec.left(repeat1($._atype)),
    _atype: $ => choice(
      $.type_constructor,
      $.variable,
      seq('(', optional(sep1($._type, ',')), ')'),
    ),

    // ---- function equations ---------------------------------------------
    function_equation: $ => prec.right(seq(
      field('name', $.variable),
      repeat($._apattern),
      choice($._rhs, repeat1($.guard)),
      optional($.where_clause),
    )),
    _rhs: $ => seq('=', $._expression),
    guard: $ => prec.right(seq('|', $._expression, '=', $._expression)),
    where_clause: $ => prec.right(seq('where', repeat($.function_equation))),

    // ---- patterns -------------------------------------------------------
    _apattern: $ => choice(
      $.variable,
      $.wildcard,
      $._literal,
      $.constructor,
      seq('(', optional(sep1($._pattern, ',')), ')'),
    ),
    _pattern: $ => choice($.constructor_pattern, $._apattern),
    constructor_pattern: $ => prec.left(seq($.constructor, repeat1($._apattern))),
    wildcard: $ => '_',

    // ---- expressions ----------------------------------------------------
    _expression: $ => choice(
      $.let_expression,
      $.if_expression,
      $.case_expression,
      $.lambda,
      $.do_expression,
      $._op_expression,
    ),

    let_expression: $ => prec.right(seq('let', repeat($.function_equation), 'in', $._expression)),
    if_expression: $ => seq('if', $._expression, 'then', $._expression, 'else', $._expression),
    case_expression: $ => prec.right(seq('case', $._expression, 'of', repeat($.case_alternative))),
    case_alternative: $ => prec.right(seq($._pattern, '->', $._expression)),
    lambda: $ => prec.right(seq('\\', repeat1($._apattern), '->', $._expression)),
    do_expression: $ => prec.right(seq('do', repeat($._statement))),
    _statement: $ => choice(
      $.bind_statement,
      $.let_statement,
      $._expression,
    ),
    let_statement: $ => prec.right(seq('let', repeat($.function_equation))),
    bind_statement: $ => prec(1, seq($._pattern, '<-', $._expression)),

    _op_expression: $ => prec.left(sep1($.application, $.operator)),
    application: $ => prec.left(repeat1($._aexpr)),
    _aexpr: $ => choice(
      $.variable,
      $.constructor,
      $._literal,
      $.record_expression,
      seq('(', optional(sep1($._expression, ',')), ')'),
      $.list_expression,
    ),
    record_expression: $ => prec(1, seq(
      choice($.constructor, $.variable),
      '{', optional(sep1($.field_assignment, ',')), '}',
    )),
    field_assignment: $ => seq($.variable, '=', $._expression),
    list_expression: $ => seq('[', optional(seq($._expression, optional(seq('..', $._expression)))), ']'),

    // ---- lexical --------------------------------------------------------
    _literal: $ => choice($.integer, $.float, $.string, $.char),

    operator: $ => choice(
      '+', '-', '*', '==', '<', '>', '.', '<>', '/.',
      '+.', '-.', '*.', '<.', '>.', '==.', '++', ':', '$',
      seq('`', $.variable, '`'),
    ),

    multiplicity: $ => /%[0-9]+(\.[0-9]+)?/,
    // One lexical `CONID`; the two rules label the same token by position (type vs
    // data constructor) so `highlights.scm` can colour them `@type` vs `@constructor`.
    _conid: $ => /[A-Z][A-Za-z0-9_']*/,
    type_constructor: $ => $._conid,
    constructor: $ => $._conid,
    variable: $ => /[a-z_][A-Za-z0-9_']*/,
    float: $ => /[0-9]+\.[0-9]+/,
    integer: $ => /[0-9]+|0x[0-9a-fA-F]+/,
    string: $ => /"([^"\\]|\\.)*"/,
    char: $ => /'([^'\\]|\\.)'/,
    comment: $ => token(choice(
      seq('--', /[^\n]*/),
      seq('{-', /[^-]*-+([^-}][^-]*-+)*/, '}'),
    )),
  },
});
