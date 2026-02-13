# MufiZ Package Manager - Documentation Generation Feature

## Overview

The `mufiz pm docs` command generates beautiful HTML documentation for MufiZ projects, similar to `cargo doc` (Rust) and Zig's built-in documentation system. It creates a static website with an index page, module pages, and search functionality.

## Features

### ✨ What It Does

- **Parses MufiZ Source Files**: Scans `.mufi` files for doc comments
- **Extracts Documentation**: Captures `///` style doc comments
- **Generates HTML**: Creates a clean, modern documentation website
- **Module Organization**: Automatically organizes docs by module/file
- **Search Functionality**: Built-in JavaScript search
- **Responsive Design**: Works on desktop and mobile
- **Zero Configuration**: Works out of the box

### 📋 Documentation Comment Style

Use triple-slash comments (`///`) before functions and classes:

```mufi
/// Calculate the factorial of a number
/// Returns the factorial of n
fun factorial(n) {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
}

/// A calculator class
/// Provides basic arithmetic operations
class Calculator {
    /// Add two numbers
    fun add(a, b) {
        return a + b;
    }
}
```

## Usage

### Generate Documentation

From your project root directory:

```bash
mufiz pm docs
```

### View Documentation

The documentation is generated in the `docs/` directory:

```bash
# Open in browser
open docs/index.html

# Or start a local server
python3 -m http.server -d docs
# Then open http://localhost:8000
```

### C API Usage

```c
#include "mufiz.h"

int main(void) {
    int result = mufiz_pm_docs();
    if (result != MUFIZ_OK) {
        fprintf(stderr, "Failed to generate docs\n");
        return 1;
    }
    return 0;
}
```

## Generated Structure

```
docs/
├── index.html           # Main index with project overview
├── style.css           # Stylesheet (modern, clean design)
├── search.js           # Search functionality
└── [module].html       # One HTML file per source file
```

### Example Output

**Index Page** (`docs/index.html`):
- Project name and overview
- List of all modules
- Module grid with statistics
- Search box in sidebar

**Module Pages** (`docs/src_main.html`):
- Module name and description
- Functions section with doc comments
- Classes section with doc comments
- Line number references
- Back to index link

## Design Philosophy

### Similar to Cargo Doc

- Clean, modern interface
- Sidebar navigation
- Module-based organization
- Searchable content

### Similar to Zig Doc

- Simple, static HTML
- No external dependencies
- Fast loading
- Single-page design per module

### MufiZ Specific

- Understands MufiZ syntax
- Extracts `fun` and `class` definitions
- Parses `///` doc comments
- Links to source line numbers

## Technical Details

### Implementation

**Files**:
- `src/docgen.zig` - Documentation generator (802 lines)
- `src/pm.zig` - PM integration (adds `docs` command)
- `src/lib.zig` - Library export (`pmDocs` function)
- `src/c_api.zig` - C API export (`mufiz_pm_docs`)

**Process**:
1. Scan `src/` directory for `.mufi` files
2. Parse each file line by line
3. Extract `///` doc comments
4. Identify `fun` and `class` declarations
5. Build documentation tree
6. Generate HTML pages
7. Create index and navigation
8. Output to `docs/` directory

### Parser

The documentation parser:
- Reads `.mufi` files
- Recognizes `/// comment` syntax
- Associates comments with next declaration
- Handles multi-line doc comments
- Extracts function and class names
- Records source line numbers

### HTML Generator

Generates:
- Semantic HTML5
- Accessible markup
- Responsive CSS Grid layout
- Clean, readable styles
- Search functionality
- Navigation structure

## Requirements

### Project Structure

Your project must have:
- `mufi.zon` file (project metadata)
- `src/` directory with `.mufi` files

### Documentation Comments

Use `///` before declarations:

```mufi
/// This is a doc comment
/// It can span multiple lines
fun myFunction() {
    // Regular comments are ignored
}
```

## Examples

### Basic Project

```bash
# Create project
mufiz pm new calculator

# Add documentation
cat > src/main.mufi << 'EOF'
/// Main entry point
fun main() {
    println("Calculator");
}

/// Add two numbers
fun add(a, b) {
    return a + b;
}
EOF

# Generate docs
cd calculator
mufiz pm docs

# View
open docs/index.html
```

### Multi-Module Project

```
my-project/
├── mufi.zon
└── src/
    ├── main.mufi      # Entry point
    ├── math.mufi      # Math utilities
    └── string.mufi    # String utilities
```

Run `mufiz pm docs` to generate documentation for all modules.

## Styling

### Color Scheme

The default theme uses:
- **Background**: White (`#ffffff`) / Dark gray sidebar (`#2d2d2d`)
- **Text**: Dark gray (`#333333`) / Light text on dark
- **Accent**: Blue (`#007acc`)
- **Borders**: Light gray (`#e1e1e1`)
- **Code Background**: Off-white (`#f5f5f5`)

### Responsive Design

- Desktop: Sidebar + content
- Mobile: Stacked layout
- Readable font sizes
- Touch-friendly navigation

## Comparison with Other Tools

### vs. Cargo Doc

**Similarities**:
- HTML output
- Sidebar navigation
- Search functionality
- Module organization

**Differences**:
- Simpler (no trait/impl complexity)
- Single-page per module
- No dependency graph

### vs. Zig Doc

**Similarities**:
- Static HTML
- No external dependencies
- Clean, minimal design
- Fast generation

**Differences**:
- MufiZ-specific syntax
- Different comment style (`///` vs. `///`)
- Separate CSS file

### vs. JSDoc/Doxygen

**Advantages**:
- Zero configuration
- No special tags needed
- Integrated with PM
- Modern design

**Limitations**:
- Simple parser (no complex syntax)
- No cross-references yet
- No type annotations (MufiZ is dynamic)

## Future Enhancements

### Planned Features
- [ ] Cross-referencing between modules
- [ ] Example code blocks
- [ ] Syntax highlighting
- [ ] Dark mode toggle
- [ ] Export to PDF
- [ ] Custom themes
- [ ] Markdown support in doc comments
- [ ] Parameter documentation
- [ ] Return value documentation
- [ ] Type hints (if added to MufiZ)

### Potential Improvements
- [ ] Parse function parameters
- [ ] Detect return types (if available)
- [ ] Extract inline examples
- [ ] Generate API reference
- [ ] Include tutorials
- [ ] Add code examples from tests
- [ ] Create dependency diagrams
- [ ] Support for `@param`, `@returns` tags

## WASM Limitations

The `mufiz_pm_docs()` function is **not available in WASM** and will return `error.NotSupportedInWasm` because it requires:
- File system access
- Directory scanning
- File writing

## Troubleshooting

### "mufi.zon not found"

**Problem**: Running outside a MufiZ project.

**Solution**: 
```bash
cd your-project-directory
mufiz pm docs
```

### "src directory not found"

**Problem**: No source files to document.

**Solution**:
```bash
mkdir -p src
echo '/// Example\nfun main() {}' > src/main.mufi
mufiz pm docs
```

### No documentation generated

**Problem**: Source files have no doc comments.

**Solution**: Add `///` comments before functions and classes.

### Styling issues

**Problem**: CSS not loading.

**Solution**: Ensure `style.css` is in the same directory as HTML files.

## API Reference

### Zig API

```zig
const mufiz = @import("mufiz");

// Generate documentation
try mufiz.pmDocs(allocator);
```

### C API

```c
// Generate documentation
int32_t result = mufiz_pm_docs();
if (result == MUFIZ_OK) {
    printf("Documentation generated!\n");
}
```

### Return Values

- `MUFIZ_OK` (0) - Success
- `MUFIZ_ERR_GENERIC` (-3) - Error (file not found, parse error, etc.)

## Best Practices

### Writing Doc Comments

**Good**:
```mufi
/// Calculate the sum of an array
/// Returns the total of all elements
fun sum(arr) {
    // Implementation
}
```

**Better**:
```mufi
/// Calculate the sum of all elements in an array
/// 
/// This function iterates through the array and adds
/// each element to compute the total sum.
/// 
/// Returns the sum as a number
fun sum(arr) {
    // Implementation
}
```

### Organization

1. **One module per file**: Keep related functions together
2. **Clear names**: Use descriptive function/class names
3. **Document public APIs**: All exported functions should have docs
4. **Consistent style**: Use similar doc comment patterns

### Maintenance

- **Regenerate often**: Run `mufiz pm docs` after changes
- **Review output**: Check generated HTML periodically
- **Update comments**: Keep docs in sync with code
- **Link in README**: Add link to docs in project README

## Integration with CI/CD

### GitHub Actions

```yaml
- name: Generate Documentation
  run: mufiz pm docs

- name: Deploy to GitHub Pages
  uses: peaceiris/actions-gh-pages@v3
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    publish_dir: ./docs
```

### Local Development

```bash
# Watch for changes and regenerate
while true; do
    inotifywait -r src/
    mufiz pm docs
done
```

## Conclusion

The `mufiz pm docs` command provides a simple, powerful way to generate documentation for MufiZ projects. With zero configuration and a clean, modern design, it makes it easy to create and maintain API documentation.

**Key Benefits**:
- ✅ Zero configuration
- ✅ Beautiful, modern design
- ✅ Fast generation
- ✅ Searchable
- ✅ Responsive
- ✅ Integrated with PM
- ✅ Similar to cargo doc and zig doc

---

**Added**: February 12, 2024  
**Version**: 0.11.0+  
**Status**: ✅ Complete and functional