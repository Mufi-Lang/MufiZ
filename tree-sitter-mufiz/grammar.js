module.exports = grammar({
  name: 'mufiz',

  extras: $ => [
    /\s/,
    $.comment,
  ],

  conflicts: $ => [
    [$.block_statement, $.vector_literal],
    [$._expression, $.complex_number],
  ],

  rules: {
    source_file: $ => repeat($._statement),

    _statement: $ => choice(
      $.expression_statement,
      $.variable_declaration,
      $.print_statement,
      $.if_statement,
      $.while_statement,
      $.for_statement,
      $.foreach_statement,
      $.function_declaration,
      $.class_declaration,
      $.return_statement,
      $.block_statement,
    ),

    expression_statement: $ => seq(
      $._expression,
      ';'
    ),

    variable_declaration: $ => seq(
      'var',
      field('name', $.identifier),
      optional(seq('=', field('value', $._expression))),
      ';'
    ),

    print_statement: $ => seq(
      'print',
      field('value', $._expression),
      ';'
    ),

    if_statement: $ => prec.right(seq(
      'if',
      '(',
      field('condition', $._expression),
      ')',
      field('then', $._statement),
      optional(seq('else', field('else', $._statement)))
    )),

    while_statement: $ => seq(
      'while',
      '(',
      field('condition', $._expression),
      ')',
      field('body', $._statement)
    ),

    for_statement: $ => seq(
      'for',
      '(',
      optional(field('init', choice(
        $.variable_declaration,
        seq($._expression, ';')
      ))),
      optional(field('condition', $._expression)),
      ';',
      optional(field('update', $._expression)),
      ')',
      field('body', $._statement)
    ),

    foreach_statement: $ => seq(
      'foreach',
      '(',
      field('variable', $.identifier),
      'in',
      field('iterable', $._expression),
      ')',
      field('body', $._statement)
    ),

    function_declaration: $ => seq(
      'fun',
      field('name', $.identifier),
      '(',
      field('parameters', optional($.parameter_list)),
      ')',
      field('body', $.block_statement)
    ),

    class_declaration: $ => seq(
      'class',
      field('name', $.identifier),
      optional(seq('<', field('superclass', $.identifier))),
      field('body', $.class_body)
    ),

    class_body: $ => seq(
      '{',
      repeat(choice(
        $.method_declaration,
        $.function_declaration
      )),
      '}'
    ),

    method_declaration: $ => seq(
      field('name', $.identifier),
      '(',
      field('parameters', optional($.parameter_list)),
      ')',
      field('body', $.block_statement)
    ),

    parameter_list: $ => seq(
      $.identifier,
      repeat(seq(',', $.identifier))
    ),

    return_statement: $ => seq(
      'return',
      optional(field('value', $._expression)),
      ';'
    ),

    block_statement: $ => seq(
      '{',
      repeat($._statement),
      '}'
    ),

    _expression: $ => choice(
      $.assignment_expression,
      $.logical_or_expression,
      $.logical_and_expression,
      $.equality_expression,
      $.comparison_expression,
      $.addition_expression,
      $.multiplication_expression,
      $.unary_expression,
      $.call_expression,
      $.member_expression,
      $.index_expression,
      $.identifier,
      $.number,
      $.string,
      $.boolean,
      $.nil,
      $.complex_number,
      $.vector_literal,
      $.hash_table_literal,
      $.linked_list_literal,
      $.parenthesized_expression,
      $.self,
      $.super,
    ),

    assignment_expression: $ => prec.right(1, seq(
      field('left', choice($.identifier, $.member_expression, $.index_expression)),
      '=',
      field('right', $._expression)
    )),

    logical_or_expression: $ => prec.left(2, seq(
      field('left', $._expression),
      field('operator', 'or'),
      field('right', $._expression)
    )),
 
    logical_and_expression: $ => prec.left(3, seq(
      field('left', $._expression),
      field('operator', 'and'),
      field('right', $._expression)
    )),
 
    equality_expression: $ => prec.left(4, seq(
      field('left', $._expression),
      field('operator', choice('==', '!=')),
      field('right', $._expression)
    )),
 
    comparison_expression: $ => prec.left(5, seq(
      field('left', $._expression),
      field('operator', choice('>', '>=', '<', '<=')),
      field('right', $._expression)
    )),
 
    addition_expression: $ => prec.left(6, seq(
      field('left', $._expression),
      field('operator', choice('+', '-')),
      field('right', $._expression)
    )),
 
    multiplication_expression: $ => prec.left(7, seq(
      field('left', $._expression),
      field('operator', choice('*', '/', '%')),
      field('right', $._expression)
    )),
 
    unary_expression: $ => prec(8, seq(
      field('operator', choice('!', '-', '+')),
      field('operand', $._expression)
    )),

    call_expression: $ => prec.left(9, seq(
      field('function', $._expression),
      '(',
      field('arguments', optional($.argument_list)),
      ')'
    )),

    member_expression: $ => prec.left(10, seq(
      field('object', $._expression),
      '.',
      field('property', $.identifier)
    )),

    index_expression: $ => prec.left(11, seq(
      field('object', $._expression),
      '[',
      field('index', $._expression),
      ']'
    )),

    argument_list: $ => seq(
      $._expression,
      repeat(seq(',', $._expression))
    ),

    vector_literal: $ => seq(
      '{',
      optional(seq(
        $._expression,
        repeat(seq(',', $._expression)),
        optional(',')
      )),
      '}'
    ),

    hash_table_literal: $ => seq(
      'table',
      '{',
      optional(seq(
        $.hash_pair,
        repeat(seq(',', $.hash_pair)),
        optional(',')
      )),
      '}'
    ),

    hash_pair: $ => seq(
      field('key', $._expression),
      ':',
      field('value', $._expression)
    ),

    linked_list_literal: $ => seq(
      'list',
      '{',
      optional(seq(
        $._expression,
        repeat(seq(',', $._expression)),
        optional(',')
      )),
      '}'
    ),

    parenthesized_expression: $ => seq(
      '(',
      $._expression,
      ')'
    ),

    complex_number: $ => prec(2, seq(
      field('real', $.number),
      choice('+', '-'),
      field('imaginary', $.number),
      'i'
    )),

    identifier: $ => /[a-zA-Z_][a-zA-Z0-9_]*/,

    number: $ => choice(
      /\d+\.\d+/,
      /\d+/
    ),

    string: $ => choice(
      seq('"', repeat(choice(/[^"\\]/, $.escape_sequence)), '"'),
      seq("'", repeat(choice(/[^'\\]/, $.escape_sequence)), "'")
    ),

    escape_sequence: $ => seq(
      '\\',
      choice(
        /[\\'"nrtbf]/,
        /u[0-9a-fA-F]{4}/,
        /x[0-9a-fA-F]{2}/,
        /[0-7]{1,3}/
      )
    ),

    boolean: $ => choice('true', 'false'),

    nil: $ => 'nil',
    self: $ => 'self',

    super: $ => 'super',

    comment: $ => token(choice(
      seq('//', /[^\r\n]*/),
      seq(
        '/*',
        /[^*]*\*+([^/*][^*]*\*+)*/,
        '/'
      )
    )),
  }
});