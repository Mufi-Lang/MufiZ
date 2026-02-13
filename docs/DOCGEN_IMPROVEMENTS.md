# Documentation Generator Improvements

## Summary

Fixed three major issues with the MufiZ documentation generator (`mufiz pm docs`):

1. **Incorrect Syntax in Generated Docs**
2. **Limited Search Functionality**
3. **Missing Sidebar on Module Pages**

---

## 1. Fixed Incorrect Syntax

### Problem
Function signatures in generated documentation showed `fn` instead of the correct MufiZ keyword `fun`.

**Before:**
```html
<code class="signature">fn factorial(n)</code>
<code class="signature">fn add(a, b)</code>
```

**After:**
```html
<code class="signature">fun factorial(n)</code>
<code class="signature">fun add(a, b)</code>
```

### Fix
Changed line 497 in `src/docgen.zig`:
```zig
// Before
try signature.appendSlice(self.allocator, "fn ");

// After
try signature.appendSlice(self.allocator, "fun ");
```

---

## 2. Enhanced Search Functionality

### Problems
- Search only worked on the index page
- Only filtered sidebar module list
- Could not search within functions, classes, or descriptions
- No keyboard shortcuts

### Improvements

#### Search Features Added:
1. **Content-Aware Search**: Now searches through:
   - Module names in sidebar
   - Function signatures (names and parameters)
   - Class names
   - Documentation descriptions

2. **Universal Search**: Search bar now appears and works on all pages:
   - Index page
   - Module pages

3. **Keyboard Shortcut**: Press `/` to focus the search input (like GitHub, docs.rs)

4. **Real-time Filtering**: Shows/hides items as you type with no lag

### Implementation
Enhanced `search.js` with:
```javascript
// Search in page content (functions, classes)
const items = document.querySelectorAll('.item-row');
items.forEach(item => {
    const signature = item.querySelector('.signature');
    const desc = item.querySelector('.item-desc');
    const sigText = signature ? signature.textContent.toLowerCase() : '';
    const descText = desc ? desc.textContent.toLowerCase() : '';

    if (sigText.includes(query) || descText.includes(query)) {
        item.style.display = '';
    } else {
        item.style.display = 'none';
    }
});
```

---

## 3. Persistent Sidebar with Navigation

### Problems
- Sidebar only appeared on index page
- Module pages had no navigation
- No way to jump between modules without going back to index
- No quick links to functions/classes within a module

### Improvements

#### Sidebar Now Includes:

1. **Modules List** (on all pages):
   - Shows all project modules
   - Current module highlighted with "active" state
   - Quick navigation between modules

2. **"On This Page" Section** (on module pages):
   - Quick links to all functions in the module
   - Quick links to all classes in the module
   - Organized by category
   - Uses anchor links for instant navigation

3. **Visual Hierarchy**:
   - Categories shown in uppercase with muted color
   - Nested items indented for clarity
   - Active module highlighted in accent color

### Example Sidebar Structure
```html
<nav class="sidebar">
    <div class="sidebar-section">
        <h3>Modules</h3>
        <ul class="module-list">
            <li class="active"><a href="main.html">main.mufi</a></li>
            <li><a href="utils.html">utils.mufi</a></li>
        </ul>
    </div>
    <div class="sidebar-section">
        <h3>On This Page</h3>
        <ul class="module-list">
            <li class="sidebar-category">Functions</li>
            <li class="sidebar-item"><a href="#fn-factorial">factorial</a></li>
            <li class="sidebar-item"><a href="#fn-add">add</a></li>
            <li class="sidebar-category">Classes</li>
            <li class="sidebar-item"><a href="#class-Calculator">Calculator</a></li>
        </ul>
    </div>
</nav>
```

### CSS Additions
```css
.module-list li.active a {
    background: var(--bg-tertiary);
    color: var(--accent);
    font-weight: 600;
}

.sidebar-section + .sidebar-section {
    margin-top: 2rem;
    padding-top: 1.5rem;
    border-top: 1px solid var(--border);
}

.sidebar-category {
    color: var(--text-muted);
    font-size: 0.8rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    padding: 0.5rem 0.75rem;
    margin-top: 0.5rem;
}

.sidebar-item a {
    font-size: 0.875rem;
    padding-left: 1.5rem;
}
```

---

## Usage

Generate documentation for any MufiZ project:

```bash
cd your-mufiz-project
mufiz pm docs
```

Then open `docs/index.html` in your browser or run:
```bash
python3 -m http.server -d docs
```

---

## Benefits

### For Users:
- **Accurate syntax** matching MufiZ language spec
- **Faster navigation** with persistent sidebar
- **Better discoverability** with enhanced search
- **Improved UX** with keyboard shortcuts and visual hierarchy

### For Documentation:
- **More professional** appearance
- **Easier to browse** large projects with many modules
- **Consistent** with popular doc tools (cargo doc, rustdoc, zig doc)

---

## Files Modified

- `src/docgen.zig`:
  - Fixed function signature keyword (line ~497)
  - Added sidebar to module pages (lines ~461-521)
  - Added anchor IDs to functions and classes
  - Enhanced CSS with active states and navigation styles
  - Improved search.js with content-aware searching

---

## Testing

To test the improvements:

1. Create a test project:
```bash
mkdir -p /tmp/mufiz_test/src
cd /tmp/mufiz_test
echo '.{ .name = "test", .version = "0.1.0" }' > mufi.zon
```

2. Create a sample `.mufi` file with docs:
```mufi
/// This module demonstrates the doc generator

/// Calculates factorial
fun factorial(n) {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
}

/// A simple class
class Math {
    /// Constructor
    fun init() {
        this.value = 0;
    }
}
```

3. Generate docs:
```bash
mufiz pm docs
```

4. Verify:
   - Functions show `fun` not `fn`
   - Sidebar appears on all pages
   - Search filters both modules and content
   - Pressing `/` focuses search
   - "On This Page" shows quick links

---

## Future Enhancements

Potential improvements for future iterations:

1. **Source Links**: Add links to source code lines
2. **Type Information**: Show parameter and return types when available
3. **Markdown Support**: Render markdown in doc comments
4. **Syntax Highlighting**: Highlight code examples in docs
5. **Cross-References**: Link between related functions/classes
6. **Search Index**: Add fuzzy search with scoring
7. **Mobile Responsive**: Improve sidebar behavior on small screens
8. **Dark/Light Toggle**: Add theme switcher (currently uses mufi-lang.org theme)

---

## Comparison: Before vs After

### Before
- ❌ Wrong syntax (`fn` instead of `fun`)
- ❌ No sidebar on module pages
- ❌ Search only worked on index page
- ❌ Search only filtered module list
- ❌ No way to jump to functions/classes quickly
- ❌ Had to navigate back to index to switch modules

### After
- ✅ Correct MufiZ syntax (`fun`)
- ✅ Persistent sidebar on all pages
- ✅ Search works everywhere
- ✅ Search filters all content (modules, functions, classes, descriptions)
- ✅ Quick navigation with "On This Page" section
- ✅ Keyboard shortcut (`/`) to focus search
- ✅ Active module highlighted
- ✅ Anchor links for direct navigation