# ZON Quick Reference Card

**MufiZ Package Manager - ZON Format**

---

## TL;DR

```bash
# New project
mufiz pm new my-project

# Initialize existing directory
mufiz pm init my-project

# View project info
mufiz pm info

# Run project
mufiz pm run
```

Projects now use `mufi.zon` (not `mufi.toml`).

---

## Basic ZON Structure

```zon
.{
    .package = .{
        .name = "my-project",
        .version = "0.1.0",
        .authors = .{},
        .description = "A MufiZ project",
        .license = "MIT",
    },
    .project = .{
        .entry_point = "src/main.mufi",
    },
}
```

---

## Field Reference

| Field | Type | Example | Required |
|-------|------|---------|----------|
| `package.name` | String | `"my-app"` | ✅ |
| `package.version` | String | `"1.0.0"` | ✅ |
| `package.authors` | Array | `.{"Alice", "Bob"}` | ✅ |
| `package.description` | String | `"My app"` | ✅ |
| `package.license` | String | `"MIT"` | ✅ |
| `project.entry_point` | String | `"src/main.mufi"` | ✅ |

---

## Syntax Essentials

### Struct Literals
```zon
.{
    .field = "value",
}
```
**Always start with dot!**

### Empty Arrays
```zon
.authors = .{},
```

### String Arrays
```zon
.authors = .{
    "Alice",
    "Bob",
    "Charlie",
},
```
**Trailing comma is OK!**

### Strings
```zon
.name = "my-project",
.description = "A cool project",
```

### Multiline Strings
```zon
.description =
    \\This is a long description
    \\that spans multiple lines
    \\and doesn't need escaping
,
```

---

## Common Patterns

### Single Author
```zon
.authors = .{"Jane Developer"},
```

### Multiple Authors
```zon
.authors = .{
    "Jane Developer",
    "John Contributor",
},
```

### No Authors
```zon
.authors = .{},
```

### Different License
```zon
.license = "Apache-2.0",
// Or: "GPL-3.0", "BSD-3-Clause", etc.
```

### Custom Entry Point
```zon
.entry_point = "main.mufi",
// Or: "src/app.mufi", "lib/index.mufi", etc.
```

---

## Migration from TOML

### Before (TOML)
```toml
[package]
name = "my-project"
version = "0.1.0"
authors = []
description = "A project"
license = "MIT"

[project]
entry_point = "src/main.mufi"
```

### After (ZON)
```zon
.{
    .package = .{
        .name = "my-project",
        .version = "0.1.0",
        .authors = .{},
        .description = "A project",
        .license = "MIT",
    },
    .project = .{
        .entry_point = "src/main.mufi",
    },
}
```

### Key Differences
- Add dots before field names: `.name`
- Use `.{}` for structs: `.{ .field = value }`
- Empty arrays: `.{}` (not `[]`)
- Trailing commas allowed everywhere
- Quotes around strings always

---

## Common Mistakes

### ❌ Missing Dot
```zon
.{
    package = .{  // WRONG: missing dot
        name = "test",  // WRONG: missing dot
    },
}
```

### ✅ Correct
```zon
.{
    .package = .{
        .name = "test",
    },
}
```

### ❌ Missing Commas
```zon
.{
    .package = .{
        .name = "test"  // WRONG: missing comma
        .version = "1.0.0"
    }
}
```

### ✅ Correct
```zon
.{
    .package = .{
        .name = "test",
        .version = "1.0.0",
    },
}
```

### ❌ Wrong Brackets
```zon
.{
    .authors = [],  // WRONG: use .{} not []
}
```

### ✅ Correct
```zon
.{
    .authors = .{},
}
```

---

## Validation Checklist

- [ ] Dots before all field names
- [ ] Dots before struct/array literals
- [ ] Commas after each field (trailing OK)
- [ ] Matching braces `{ }`
- [ ] Strings in quotes `"..."`
- [ ] All required fields present

---

## Commands Quick Reference

### Create
```bash
# New directory + project
mufiz pm new my-project
cd my-project

# Initialize current directory
mufiz pm init my-project
```

### View
```bash
# Show project info
mufiz pm info
```

### Run
```bash
# Execute project
mufiz pm run
```

### Help
```bash
# Show help
mufiz pm help
```

---

## File Locations

```
my-project/
├── mufi.zon        ← Project config (ZON format)
└── src/
    └── main.mufi   ← Your code
```

---

## Complete Example

```zon
.{
    .package = .{
        .name = "awesome-app",
        .version = "2.1.0",
        .authors = .{
            "Jane Developer <jane@example.com>",
            "The MufiZ Team",
        },
        .description = "An awesome MufiZ application with cool features",
        .license = "Apache-2.0",
    },
    .project = .{
        .entry_point = "src/main.mufi",
    },
}
```

---

## Troubleshooting

### Error: "mufi.zon not found"
**Solution:** Run `mufiz pm init <name>` to create it

### Error: "Parse error"
**Solution:** Check syntax - common issues:
- Missing dots before field names
- Missing commas between fields
- Wrong brackets (use `.{}` not `[]`)
- Unquoted strings

### Error: "Invalid ZON"
**Solution:** Validate structure:
1. Every `{` has matching `}`
2. Every field starts with `.`
3. Every line ends with `,`
4. Strings in `"quotes"`

---

## Resources

- **Full Guide:** `docs/ZON_MIGRATION.md`
- **Technical Details:** `docs/PM_ZON_UPDATE_SUMMARY.md`
- **Zig ZON Docs:** [ziglang.org/documentation](https://ziglang.org/documentation/master/#zon)
- **GitHub Issues:** [github.com/mufiz-lang/mufiz/issues](https://github.com/mufiz-lang/mufiz/issues)

---

## Cheat Sheet

```zon
// Comments use //

.{                           // Root struct
    .field = "value",        // String field
    .number = 42,            // Number
    .bool = true,            // Boolean
    .empty = .{},            // Empty array/struct
    .array = .{ 1, 2, 3 },   // Array
    .nested = .{             // Nested struct
        .inner = "data",
    },
}
```

**Remember:** Dots, commas, quotes!

---

**MufiZ v0.11.0** • [mufi-lang.mokareads.org](https://mufi-lang.mokareads.org)