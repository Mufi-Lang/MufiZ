# Grammar and Data Generation Updates

## Summary

Updated the MufiZ grammar and dataset generator to reflect the actual implemented features of the language and include comprehensive standard library function usage.

## Changes Made

### 1. Grammar Updates (PEG and EBNF)

#### Removed Class Support
Classes are **not implemented** in MufiZ, so they have been removed from the grammar:

**Before:**
```
Declaration <- ClassDecl / FunDecl / VarDecl / ConstDecl / ImportStmt

ClassDecl <- "class" _ Identifier (_ "<" _ Identifier)? _ "{" _ Method* "}" _
Method <- Identifier _ "(" _ Parameters? ")" _ Block
```

**After:**
```
Declaration <- FunDecl / VarDecl / ConstDecl / ImportStmt
```

#### Removed Class-Related Keywords
The following keywords were removed as they're not implemented:
- `class` - Class declaration