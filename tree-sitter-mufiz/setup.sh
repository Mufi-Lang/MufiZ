#!/bin/bash

# MufiZ Tree-sitter Grammar Setup Script
# This script sets up the Tree-sitter grammar for MufiZ language

set -e

echo "🌳 Setting up Tree-sitter grammar for MufiZ..."

# Check if we're in the right directory
if [ ! -f "grammar.js" ]; then
    echo "❌ Error: grammar.js not found. Please run this script from the tree-sitter-mufiz directory."
    exit 1
fi

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Error: Node.js is required but not installed."
    echo "Please install Node.js from https://nodejs.org/"
    exit 1
fi

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "❌ Error: npm is required but not installed."
    exit 1
fi

# Install tree-sitter-cli if not already installed
if ! command -v tree-sitter &> /dev/null; then
    echo "📦 Installing tree-sitter CLI..."
    npm install -g tree-sitter-cli
fi

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Generate the parser
echo "⚙️  Generating parser from grammar..."
tree-sitter generate

# Test the grammar
echo "🧪 Running tests..."
if [ -d "test" ]; then
    tree-sitter test
else
    echo "⚠️  No tests found, skipping test phase"
fi

# Build native bindings
echo "🔨 Building native bindings..."
if command -v node-gyp &> /dev/null; then
    node-gyp rebuild
else
    echo "⚠️  node-gyp not found, installing..."
    npm install -g node-gyp
    node-gyp rebuild
fi

# Create example files for testing
echo "📝 Creating example files..."
mkdir -p examples

cat > examples/basic.mufi << 'EOF'
// Basic MufiZ example
var greeting = "Hello, MufiZ!";
var numbers = {1.0, 2.0, 3.0, 4.0, 5.0};

fun factorial(n) {
    if (n <= 1) {
        return 1;
    }
    return n * factorial(n - 1);
}

class Calculator {
    init() {
        self.result = 0;
    }
    
    add(value) {
        self.result = self.result + value;
        return this;
    }
    
    multiply(value) {
        self.result = self.result * value;
        return this;
    }
}

// Main execution
print greeting;

foreach (num in numbers) {
    print "Factorial of " + num + " is " + factorial(num);
}

var calc = Calculator();
calc.add(10).multiply(2);
print "Calculator result: " + calc.result;

// Complex numbers
var complex1 = 3.0 + 4.0i;
var complex2 = 1.0 - 2.0i;
print "Complex numbers: " + complex1 + " and " + complex2;

// Hash table
var scores = table{
    "Alice": 95,
    "Bob": 87,
    "Charlie": 92
};

foreach (name in scores) {
    print name + " scored " + scores[name];
}
EOF

cat > examples/advanced.mufi << 'EOF'
// Advanced MufiZ features
class Shape {
    init(name) {
        self.name = name;
    }
    
    area() {
        return 0;
    }
    
    describe() {
        print "This is a " + self.name + " with area " + self.area();
    }
}

class Rectangle < Shape {
    init(width, height) {
        super.init("rectangle");
        self.width = width;
        self.height = height;
    }
    
    area() {
        return self.width * self.height;
    }
}

class Circle < Shape {
    init(radius) {
        super.init("circle");
        self.radius = radius;
    }
    
    area() {
        return 3.14159 * self.radius * self.radius;
    }
}

// Create shapes
var shapes = {
    Rectangle(10, 5),
    Circle(3),
    Rectangle(4, 4)
};

foreach (shape in shapes) {
    shape.describe();
}

// Nested loops and complex logic
for (var i = 1; i <= 3; i = i + 1) {
    print "Iteration " + i;
    
    var data = {i * 1.0, i * 2.0, i * 3.0};
    foreach (value in data) {
        if (value > 3.0) {
            print "  Large value: " + value;
        } else {
            print "  Small value: " + value;
        }
    }
}

// Function with complex return
fun processData(input) {
    if (input > 10) {
        return input * 2;
    } else if (input > 5) {
        return input + 10;
    } else {
        return input;
    }
}

var testValues = {3, 7, 15};
foreach (val in testValues) {
    var result = processData(val);
    print "Input: " + val + ", Output: " + result;
}
EOF

# Test parsing the example files
echo "🧪 Testing parser with example files..."
tree-sitter parse examples/basic.mufi > /dev/null && echo "✅ Basic example parsed successfully"
tree-sitter parse examples/advanced.mufi > /dev/null && echo "✅ Advanced example parsed successfully"

# Check highlighting
echo "🎨 Testing syntax highlighting..."
tree-sitter highlight examples/basic.mufi > /dev/null && echo "✅ Highlighting works"

echo ""
echo "🎉 Setup completed successfully!"
echo ""
echo "Next steps:"
echo "1. Install in your editor:"
echo "   - Neovim: Use the configuration in examples/neovim.lua"
echo "   - VS Code: Create an extension using examples/vscode-extension.json"
echo "   - Emacs: Add tree-sitter support for mufiz"
echo ""
echo "2. Test the parser:"
echo "   tree-sitter parse examples/basic.mufi"
echo ""
echo "3. View syntax highlighting:"
echo "   tree-sitter highlight examples/basic.mufi"
echo ""
echo "4. Run tests:"
echo "   tree-sitter test"
echo ""
echo "For more information, see README.md"