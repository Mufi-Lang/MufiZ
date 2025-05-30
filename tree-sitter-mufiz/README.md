# Tree-sitter MufiZ

A Tree-sitter grammar for the MufiZ programming language.

## Features

- Complete syntax highlighting for MufiZ language constructs
- Support for all MufiZ language features including:
  - Variables and functions
  - Classes and inheritance
  - Control flow (if/else, while, for, foreach)
  - Data types (numbers, strings, booleans, complex numbers)
  - Collections (vectors, hash tables, linked lists)
  - Comments (single-line and multi-line)
- Semantic analysis support with locals queries
- Language injection support for embedded languages

## Installation

### Node.js

```bash
npm install tree-sitter-mufiz
```

### From Source

1. Clone this repository
2. Install dependencies:
   ```bash
   npm install
   ```
3. Generate the parser:
   ```bash
   npm run build
   ```

## Usage

### Node.js

```javascript
const Parser = require('tree-sitter');
const MufiZ = require('tree-sitter-mufiz');

const parser = new Parser();
parser.setLanguage(MufiZ);

const sourceCode = `
var x = 5;
foreach (item in {1.0, 2.0, 3.0}) {
    print item * x;
}
`;

const tree = parser.parse(sourceCode);
console.log(tree.rootNode.toString());
```

### Neovim

Add to your Tree-sitter configuration:

```lua
require'nvim-treesitter.configs'.setup {
  ensure_installed = { "mufiz" },
  highlight = {
    enable = true,
  },
}
```

### Emacs

```elisp
(use-package tree-sitter-langs
  :config
  (tree-sitter-require 'mufiz))
```

### VS Code

Install the MufiZ language extension that includes this Tree-sitter grammar.

## Language Support

### Syntax Highlighting

The grammar provides comprehensive syntax highlighting for:

- **Keywords**: `var`, `fun`, `class`, `if`, `else`, `while`, `for`, `foreach`, etc.
- **Operators**: `+`, `-`, `*`, `/`, `==`, `!=`, `and`, `or`, etc.
- **Literals**: Numbers, strings, booleans, complex numbers
- **Collections**: Vector literals `{}`, hash tables, linked lists
- **Comments**: Both `//` and `/* */` styles

### Semantic Features

- **Scope tracking**: Proper handling of variable and function scopes
- **Symbol resolution**: Accurate identification of definitions and references
- **Error recovery**: Robust parsing with good error handling

## Grammar Overview

The grammar supports the complete MufiZ language syntax:

```mufiz
// Variables and basic types
var name = "MufiZ";
var version = 0.8;
var active = true;
var complex = 3.0 + 4.0i;

// Collections
var vector = {1.0, 2.0, 3.0};
var table = table{"key": "value", "count": 42};
var list = list{1, 2, 3};

// Functions
fun fibonacci(n) {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

// Classes
class Person {
    init(name, age) {
        self.name = name;
        self.age = age;
    }
    
    greet() {
        print "Hello, I'm " + self.name;
    }
}

// Control flow
foreach (item in vector) {
    if (item > 1.5) {
        print "Large: " + item;
    }
}

while (active) {
    print "Running...";
    active = false;
}
```

## Development

### Testing

Run the test suite:

```bash
npm test
```

Add test cases to `test/corpus/` directory.

### Grammar Development

1. Edit `grammar.js` to modify the grammar rules
2. Regenerate the parser:
   ```bash
   tree-sitter generate
   ```
3. Test your changes:
   ```bash
   tree-sitter test
   ```
4. Parse example files:
   ```bash
   tree-sitter parse examples/example.mufi
   ```

### Query Development

Modify highlighting and other queries in the `queries/` directory:

- `highlights.scm`: Syntax highlighting rules
- `locals.scm`: Scope and variable tracking
- `injections.scm`: Language injection rules

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new features
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Related Projects

- [MufiZ Language](https://github.com/Mustafif/MufiZ) - The main MufiZ compiler
- [Tree-sitter](https://tree-sitter.github.io/tree-sitter/) - The parsing framework