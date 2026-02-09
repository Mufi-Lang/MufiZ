# MuFi Dataset Generation - Quick Start

## 🎯 Generate 100K Dataset in 3 Steps

### Step 1: Build MuFi
```bash
cd MufiZ
zig build
```

### Step 2: Run Generation Script
```bash
./tools/generate_100k.sh
```

### Step 3: Done! 🎉
Archives are in `../mufiz-archives/`

---

## ⚡ Commands Cheat Sheet

### One-Line Full Generation
```bash
./tools/generate_100k.sh [optional_directory] [optional_cores]
```

### Manual Control
```bash
# Initialize
python3 tools/manage_dataset.py init --target 100000 --dir ../mufiz-dataset

# Generate
python3 tools/manage_dataset.py generate --count 100000 --cores 8 --dir ../mufiz-dataset

# Check status
python3 tools/manage_dataset.py status --dir ../mufiz-dataset

# Validate
python3 tools/manage_dataset.py validate --sample 1000 --dir ../mufiz-dataset

# Create archives
python3 tools/manage_dataset.py archive --format all --dir ../mufiz-dataset
```

### Resume Interrupted Generation
```bash
python3 tools/manage_dataset.py generate --count 100000 --resume --dir ../mufiz-dataset
```

---

## 📊 Quick Reference

### Estimated Times (100K programs)
- **4 cores**: ~5-6 hours
- **8 cores**: ~3-4 hours
- **16 cores**: ~2 hours

### Archive Sizes (100K programs)
- **Uncompressed**: ~300 MB
- **tar.gz**: ~90 MB
- **tar.xz**: ~60 MB (best compression)
- **zip**: ~95 MB

### Disk Space Required
- **Generation**: ~350 MB
- **Archives**: ~250 MB (all formats)
- **Total**: ~600 MB

---

## 🚀 What Gets Generated

```
../mufiz-dataset/
├── .git/                  # Separate git repo
├── README.md              # Dataset docs
├── metadata.json          # Statistics
└── programs/              # 100,000 .mufi files
    ├── prog_0.mufi
    ├── prog_1.mufi
    └── ...

../mufiz-archives/
├── mufiz-dataset-100000_TIMESTAMP.tar.gz
├── mufiz-dataset-100000_TIMESTAMP.tar.xz
└── mufiz-dataset-100000_TIMESTAMP.zip
```

---

## ✨ Code Quality Guarantee

All 100,000 programs are:
- ✅ **Syntactically valid** - Parse successfully
- ✅ **Semantically correct** - Type-safe operations
- ✅ **Executable** - Run without errors
- ✅ **Well-formed** - Proper structure
- ✅ **Diverse** - Various language features

---

## 🔧 Common Options

### Specify Location
```bash
./tools/generate_100k.sh /path/to/dataset
```

### Specify CPU Cores
```bash
./tools/generate_100k.sh ../mufiz-dataset 16
```

### Small Test Dataset
```bash
python3 tools/manage_dataset.py init --target 1000 --dir test-dataset
python3 tools/manage_dataset.py generate --count 1000 --dir test-dataset
```

---

## 🚨 Troubleshooting

### Problem: "MuFi binary not found"
```bash
# Solution: Build MuFi first
zig build
```

### Problem: Generation interrupted
```bash
# Solution: Resume with --resume flag
python3 tools/manage_dataset.py generate --count 100000 --resume
```

### Problem: Out of disk space
```bash
# Solution: Check space, need ~600MB
df -h
```

### Problem: Generation too slow
```bash
# Solution: Use more cores
python3 tools/manage_dataset.py generate --count 100000 --cores 16
```

---

## 📚 Full Documentation

- **[README.md](README.md)** - Complete tools overview
- **[DATASET_100K_GUIDE.md](DATASET_100K_GUIDE.md)** - Detailed guide
- **[DATASET_GEN_README.md](DATASET_GEN_README.md)** - Technical details

---

## 🎓 Example Session

```bash
$ cd MufiZ
$ zig build
info: All your codebase are belong to us.

$ ./tools/generate_100k.sh
╔════════════════════════════════════════════════════════════╗
║        MuFi 100K Dataset Generation Script                ║
╚════════════════════════════════════════════════════════════╝

Configuration:
  Dataset directory: ../mufiz-dataset-100k
  CPU cores:         8
  Target programs:   100000
  Batch size:        2000

Estimated time: ~214 minutes

Press Enter to start generation...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Step 1: Initializing Repository
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Repository initialized

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Step 2: Generating Programs
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Worker 12345 starting to generate 25000 valid files...
Worker 12346 starting to generate 25000 valid files...
[... generation progress ...]

Batch 50/50 completed in 12.3s
Progress: 100,000/100,000 (100.0%)
✓ Generation completed in 245 minutes

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Step 3: Validating Sample
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total: 1,000
Valid: 1,000 (100.0%)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Step 4: Creating Archives
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Created: mufiz-dataset-100000_20250115_144500.tar.gz (89.23 MB)
✓ Created: mufiz-dataset-100000_20250115_144500.tar.xz (58.67 MB)
✓ Created: mufiz-dataset-100000_20250115_144500.zip (93.45 MB)

╔════════════════════════════════════════════════════════════╗
║              Generation Complete! 🎉                       ║
╚════════════════════════════════════════════════════════════╝

Dataset location: ../mufiz-dataset-100k
Archives location: ../mufiz-archives
```

---

**Ready to generate? Run: `./tools/generate_100k.sh`**