# MuFi 100K Dataset Generation Guide

Complete guide for generating, managing, and distributing a 100,000 program dataset.

## Quick Start

```bash
# 1. Navigate to MufiZ directory
cd MufiZ

# 2. Build MuFi (if not already built)
zig build

# 3. Initialize dataset (creates separate git repo)
python3 tools/manage_dataset.py init \
  --target 100000 \
  --dir ../mufiz-dataset

# 4. Generate the full dataset (takes ~3-4 hours on 8 cores)
python3 tools/manage_dataset.py generate \
  --count 100000 \
  --cores 8 \
  --dir ../mufiz-dataset

# 5. Check status
python3 tools/manage_dataset.py status --dir ../mufiz-dataset

# 6. Create compressed archives
python3 tools/manage_dataset.py archive \
  --format all \
  --dir ../mufiz-dataset
```

## Detailed Instructions

### 1. Initialize Dataset Repository

Create a new, separate git repository for the dataset:

```bash
python3 tools/manage_dataset.py init \
  --target 100000 \
  --dir /path/to/mufiz-dataset
```

This creates:
```
mufiz-dataset/
├── .git/              # Separate git repository
├── .gitignore         # Configured for datasets
├── README.md          # Dataset documentation
├── metadata.json      # Statistics and tracking
└── programs/          # Generated .mufi files
```

**Options:**
- `--target`: Total number of programs (default: 100000)
- `--dir`: Dataset location (default: ../mufiz-dataset)
- `--mufiz`: Path to mufiz binary (default: ./zig-out/bin/mufiz)

### 2. Generate Programs

Generate valid MuFi programs efficiently:

```bash
python3 tools/manage_dataset.py generate \
  --count 100000 \
  --cores 8 \
  --batch 1000 \
  --dir ../mufiz-dataset
```

**Options:**
- `--count`: Number of programs to generate
- `--cores`: CPU cores to use (default: all available)
- `--batch`: Programs per git commit (default: 1000)
- `--resume`: Continue interrupted generation

**Performance Estimates:**

| Programs | Cores | Estimated Time |
|----------|-------|----------------|
| 1,000    | 4     | ~3 minutes     |
| 10,000   | 8     | ~20 minutes    |
| 100,000  | 8     | ~3-4 hours     |
| 100,000  | 16    | ~2 hours       |

**Progress Tracking:**
- Real-time progress updates
- Automatic git commits per batch
- Metadata tracking
- Resumable on interruption

### 3. Resume Interrupted Generation

If generation is interrupted, resume from where you left off:

```bash
python3 tools/manage_dataset.py generate \
  --count 100000 \
  --resume \
  --dir ../mufiz-dataset
```

The tool automatically:
- Detects current program count
- Continues from the last completed batch
- Maintains git history integrity
- Updates metadata correctly

### 4. Check Status

Monitor dataset progress and statistics:

```bash
python3 tools/manage_dataset.py status --dir ../mufiz-dataset
```

Output includes:
- Current program count vs target
- Generation progress percentage
- Total generation time
- Session history
- Statistics (functions, statements, avg size)
- Disk usage

Example output:
```
============================================================
Dataset Status
============================================================
Location: /path/to/mufiz-dataset
Programs: 100,000 / 100,000
Progress: 100.0%
Created: 2025-01-15T10:30:00
Last Updated: 2025-01-15T14:45:00

Total Generation Time: 245.3 minutes

Generation Sessions: 2
  Session 1: 50,000 programs @ 6.8 files/sec
  Session 2: 50,000 programs @ 7.2 files/sec

Statistics:
  Total Functions: 250,000
  Total Statements: 850,000
  Avg Program Size: 28.5 lines

Disk Usage: 285.3 MB
============================================================
```

### 5. Validate Dataset

Verify all programs are valid:

```bash
# Validate all programs (slow for 100K)
python3 tools/manage_dataset.py validate --dir ../mufiz-dataset

# Validate random sample (faster)
python3 tools/manage_dataset.py validate \
  --sample 1000 \
  --dir ../mufiz-dataset
```

This checks that all programs:
- ✅ Parse successfully
- ✅ Type-check correctly
- ✅ Execute without errors
- ✅ Follow MuFi grammar

### 6. Create Archives

Generate compressed archives for distribution:

```bash
# Create all archive formats
python3 tools/manage_dataset.py archive \
  --format all \
  --dir ../mufiz-dataset

# Create specific format
python3 tools/manage_dataset.py archive \
  --format tar.xz \
  --dir ../mufiz-dataset \
  --output ~/archives
```

**Archive Formats:**

| Format   | Compression | Size (est.) | Speed    | Use Case                    |
|----------|-------------|-------------|----------|-----------------------------|
| tar.gz   | Good        | ~90 MB      | Fast     | General distribution        |
| tar.xz   | Best        | ~60 MB      | Slow     | Maximum compression         |
| zip      | Good        | ~95 MB      | Fast     | Windows compatibility       |
| all      | -           | All above   | Slowest  | Complete package            |

**Archive Contents:**
- `programs/` - All .mufi files
- `metadata.json` - Dataset statistics
- `README.md` - Documentation

### 7. Git Repository Management

The dataset is its own git repository with proper versioning:

```bash
# Navigate to dataset
cd ../mufiz-dataset

# View commit history
git log --oneline

# See changes
git status

# View specific batch
git show HEAD~10

# Create a branch for experiments
git checkout -b experiment-v1

# Push to remote (if configured)
git remote add origin https://github.com/username/mufiz-dataset.git
git push -u origin main
```

**Commit Structure:**
- Initial commit: Repository setup
- Batch commits: Every 1000 programs
- Metadata commits: After completion
- Clear commit messages with counts

## Advanced Usage

### Parallel Generation on Multiple Machines

Split generation across machines:

**Machine 1:**
```bash
python3 tools/manage_dataset.py init --target 50000 --dir dataset-part1
python3 tools/manage_dataset.py generate --count 50000 --dir dataset-part1
```

**Machine 2:**
```bash
python3 tools/manage_dataset.py init --target 50000 --dir dataset-part2
python3 tools/manage_dataset.py generate --count 50000 --dir dataset-part2
```

**Merge:**
```bash
mkdir mufiz-dataset-100k/programs
cp dataset-part1/programs/* mufiz-dataset-100k/programs/
cp dataset-part2/programs/* mufiz-dataset-100k/programs/
# Rename files to ensure no conflicts
```

### Custom Generation Parameters

Modify `mufiz_dataset_gen.py` for custom characteristics:

```python
# Adjust complexity
generator = MufiGenerator(depth_limit=6)  # More complex programs

# Adjust statement counts
for _ in range(random.randint(10, 20)):  # Longer programs
    lines.append(self.generate_statement(depth=0))
```

### Continuous Integration

Automate generation with CI/CD:

```yaml
# .github/workflows/generate-dataset.yml
name: Generate Dataset
on:
  workflow_dispatch:
    inputs:
      count:
        description: 'Number of programs'
        required: true
        default: '10000'

jobs:
  generate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build MuFi
        run: zig build
      - name: Generate Dataset
        run: |
          python3 tools/manage_dataset.py init --target ${{ github.event.inputs.count }}
          python3 tools/manage_dataset.py generate --count ${{ github.event.inputs.count }}
      - name: Create Archive
        run: python3 tools/manage_dataset.py archive --format tar.xz
      - name: Upload Artifact
        uses: actions/upload-artifact@v2
        with:
          name: mufiz-dataset
          path: "*.tar.xz"
```

## Distribution

### Upload to GitHub Releases

```bash
# Create archive
python3 tools/manage_dataset.py archive --format tar.xz

# Upload via GitHub CLI
gh release create v1.0 \
  mufiz-dataset-100000_*.tar.xz \
  --title "MuFi Dataset v1.0 - 100K Programs" \
  --notes "Complete dataset of 100,000 valid MuFi programs"
```

### Host on Cloud Storage

```bash
# AWS S3
aws s3 cp mufiz-dataset-100000.tar.xz \
  s3://your-bucket/datasets/ \
  --acl public-read

# Google Cloud Storage
gsutil cp mufiz-dataset-100000.tar.xz \
  gs://your-bucket/datasets/
```

### Create Torrent

For peer-to-peer distribution:

```bash
# Create torrent
mktorrent -a udp://tracker.opentrackr.org:1337 \
  -o mufiz-dataset.torrent \
  mufiz-dataset-100000.tar.xz
```

## Troubleshooting

### Generation is Slow

**Symptoms:** Less than 5 files/sec per core

**Solutions:**
1. Check CPU usage: `top` or `htop`
2. Reduce `--cores` if CPU is maxed
3. Check disk I/O: `iostat`
4. Use SSD instead of HDD
5. Disable debug mode

### Out of Disk Space

**Symptoms:** Generation fails, disk full

**Solutions:**
1. Check space: `df -h`
2. 100K programs ≈ 300MB uncompressed
3. Move to larger disk
4. Generate in batches, archive, then delete

### Generation Interrupted

**Symptoms:** Process killed, power loss, etc.

**Solutions:**
1. Use `--resume` flag
2. Check status to see progress
3. Generation continues from last batch
4. Git history preserved

### Invalid Programs Generated

**Symptoms:** Validation fails

**Solutions:**
1. Update to latest generator code
2. Check MuFi binary version
3. Run with `--debug` to see errors
4. Report issue with failing program

### Git Repository Too Large

**Symptoms:** Slow git operations, large .git folder

**Solutions:**
1. Use larger batch sizes (`--batch 5000`)
2. Use git shallow clone for distribution
3. Consider git-lfs for archives
4. Squash commits if needed:
   ```bash
   git rebase -i --root
   ```

## Performance Optimization

### Maximize Generation Speed

```bash
# Use all cores
python3 tools/manage_dataset.py generate \
  --count 100000 \
  --cores $(nproc) \
  --batch 5000

# Run on dedicated server
nice -n -20 python3 tools/manage_dataset.py generate ...

# Disable unnecessary services
# Monitor with: watch -n 1 'python3 tools/manage_dataset.py status'
```

### Memory Management

For systems with limited RAM:

```bash
# Reduce workers
python3 tools/manage_dataset.py generate \
  --cores 4 \
  --batch 500

# Monitor memory
watch -n 1 'free -h'
```

## Dataset Quality Metrics

Expected characteristics of generated dataset:

- **Syntax Validity:** 100%
- **Semantic Correctness:** 100%
- **Program Size:** 20-40 lines average
- **Functions per Program:** 2-3 average
- **Statements per Program:** 8-12 average
- **Features Coverage:**
  - Variables (var/const): 100%
  - Functions: 100%
  - Loops (for/while/foreach): ~90%
  - Conditionals (if/else): ~70%
  - Collections (vectors/hashes): ~40%

## Best Practices

1. **Always initialize first:** Run `init` before `generate`
2. **Use resume:** Never restart from scratch if interrupted
3. **Validate samples:** Check quality during generation
4. **Commit batches:** Don't use batch size > 10000
5. **Create archives:** Compress before distribution
6. **Document versions:** Tag releases in git
7. **Test extraction:** Verify archives work correctly
8. **Share metadata:** Include metadata.json with archives

## Example Complete Workflow

```bash
#!/bin/bash
# complete_generation.sh - Full 100K dataset generation

set -e  # Exit on error

echo "=== MuFi 100K Dataset Generation ==="
echo

# Step 1: Initialize
echo "Step 1: Initializing repository..."
python3 tools/manage_dataset.py init \
  --target 100000 \
  --dir ../mufiz-dataset-100k

# Step 2: Generate
echo "Step 2: Generating programs..."
python3 tools/manage_dataset.py generate \
  --count 100000 \
  --cores 8 \
  --batch 2000 \
  --dir ../mufiz-dataset-100k

# Step 3: Validate sample
echo "Step 3: Validating sample..."
python3 tools/manage_dataset.py validate \
  --sample 1000 \
  --dir ../mufiz-dataset-100k

# Step 4: Create archives
echo "Step 4: Creating archives..."
python3 tools/manage_dataset.py archive \
  --format all \
  --dir ../mufiz-dataset-100k \
  --output ~/mufiz-archives

# Step 5: Status report
echo "Step 5: Final status..."
python3 tools/manage_dataset.py status \
  --dir ../mufiz-dataset-100k

echo
echo "=== Generation Complete! ==="
echo "Archives location: ~/mufiz-archives"
```

## Support

For issues or questions:
- Check this guide first
- Review `tools/DATASET_GEN_README.md`
- Run with `--help` for command options
- Enable `--debug` for troubleshooting
- Check GitHub issues

## License

This dataset and tools are part of the MufiZ project.