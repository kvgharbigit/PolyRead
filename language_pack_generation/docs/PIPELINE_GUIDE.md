# Language Pack Pipeline Guide

## Overview
This guide provides step-by-step instructions for generating, verifying, and deploying individual language packs for PolyRead.

## Prerequisites

### System Requirements
- Python 3.8+
- GitHub CLI (`gh`) authenticated
- 2GB RAM minimum
- 5GB free disk space
- Internet connection

### Dependencies Installation
```bash
# Install required Python packages
pip3 install pyglossary requests

# Install GitHub CLI (if not already installed)
brew install gh  # macOS
# or follow: https://cli.github.com/manual/installation

# Authenticate GitHub CLI
gh auth login
```

## Process Overview

The pipeline consists of 3 main phases:
1. **Generation** - Create bidirectional SQLite database from Wiktionary sources
2. **Verification** - Comprehensive validation of structure and data integrity
3. **Deployment** - Upload to GitHub and update registry

## Detailed Steps

### Phase 1: Generation

#### Step 1: Choose Language
Available languages with proven Wiktionary sources:
- `pt-en` - Portuguese ↔ English (~20,000 entries)
- `ru-en` - Russian ↔ English (~45,000 entries)
- `ja-en` - Japanese ↔ English (~30,000 entries)
- `ko-en` - Korean ↔ English (~15,000 entries)
- `zh-en` - Chinese ↔ English (~40,000 entries)
- `ar-en` - Arabic ↔ English (~20,000 entries)
- `hi-en` - Hindi ↔ English (~15,000 entries)

#### Step 2: Generate Language Pack
```bash
cd language_pack_generation/scripts
python3 single_language_generator.py pt-en
```

**What this does:**
1. Downloads StarDict from Vuizur repository
2. Converts using PyGlossary with error tolerance
3. Creates bidirectional SQLite schema
4. Populates forward and reverse entries
5. Adds comprehensive indexing
6. Creates compressed ZIP package
7. Generates detailed summary

**Expected output:**
```
🇵🇹 GENERATING PORTUGUESE ↔ ENGLISH
================================================================================
[1/6 - 16.7%] Building StarDict pack for pt-en
[2/6 - 33.3%] Converting to bidirectional format: pt-en
[3/6 - 50.0%] Verifying pt-en
[4/6 - 66.7%] Creating zip package for pt-en
[5/6 - 83.3%] Generating summary for pt-en
[6/6 - 100.0%] Cleaning up temporary files for pt-en

🎉 SUCCESS: Portuguese ↔ English language pack completed!
📊 Entries: 25,487 (12,345 forward + 13,142 reverse)
📦 Size: 3.2MB compressed
⏱️ Duration: 45.2s
```

#### Step 3: Verify Generation Results
Check generated files:
```bash
ls -la ../completed_packs/
# Should show:
# pt-en.sqlite.zip     (compressed language pack)
# pt-en_summary.json   (metadata and statistics)
```

### Phase 2: Verification

#### Step 1: Automatic Verification
Verification happens automatically during generation, but can be run independently:

```bash
python3 single_language_generator.py pt-en --verify-only
```

#### Step 2: Manual Inspection
```bash
# Check summary details
cat ../completed_packs/pt-en_summary.json

# Verify ZIP integrity
unzip -t ../completed_packs/pt-en.sqlite.zip

# Check database structure (optional)
sqlite3 ../temp/pt-en/pt-en.sqlite "SELECT COUNT(*) FROM dictionary_entries;"
```

**Verification Checklist:**
- ✅ Required tables present (`dictionary_entries`, `pack_metadata`)
- ✅ Correct column schema with constraints
- ✅ Bidirectional direction field ('forward', 'reverse')
- ✅ Proper indexing for O(1) lookups
- ✅ Entry count meets minimum threshold
- ✅ Lookup functionality working
- ✅ ZIP compression successful
- ✅ SHA-256 checksum generated

### Phase 3: Deployment

#### Step 1: Deploy to GitHub
```bash
python3 deploy_pack.py pt-en
```

**What this does:**
1. Verifies pack integrity
2. Uploads ZIP to GitHub release
3. Updates comprehensive registry
4. Uploads updated registry
5. Verifies accessibility

**Expected output:**
```
🚀 DEPLOYING PT-EN
============================================================
🔍 Verifying pt-en is ready for deployment
📤 Uploading pt-en to GitHub release language-packs-v2.0
📝 Updating registry with pt-en
📤 Uploading updated registry to GitHub
🔍 Verifying deployment accessibility

🎉 DEPLOYMENT SUCCESS: pt-en
📦 Pack: Portuguese ↔ English
📊 Entries: 25,487
📏 Size: 3.2MB
⏱️ Deploy time: 12.3s
🔗 Available at: https://github.com/kvgharbigit/PolyRead/releases/tag/language-packs-v2.0
```

#### Step 2: Verify Deployment
```bash
python3 deploy_pack.py pt-en --verify-only
```

## Directory Structure After Completion

```
language_pack_generation/
├── completed_packs/
│   ├── pt-en.sqlite.zip         # Compressed language pack
│   └── pt-en_summary.json       # Pack metadata
├── temp/
│   └── pt-en/
│       └── pt-en.sqlite         # Uncompressed database
├── logs/
│   ├── pt-en_20251029_143022.log      # Generation log
│   └── deploy_pt-en_20251029_143515.log # Deployment log
└── scripts/
    ├── single_language_generator.py
    └── deploy_pack.py
```

## Quality Assurance

### Database Schema Validation
Each pack must have identical schema:
```sql
-- Required tables
dictionary_entries    (id, lemma, definition, direction, source_language, target_language, created_at)
pack_metadata        (key, value)

-- Required indexes
idx_lemma_direction  (lemma, direction)
idx_direction        (direction)
idx_source_lang      (source_language)
idx_target_lang      (target_language)
```

### Data Integrity Checks
- Entry count must exceed 50% of expected entries
- Forward and reverse directions properly populated
- No NULL or empty values in critical fields
- Lookup queries return expected results
- HTML formatting preserved in definitions

### Deployment Verification
- GitHub download URLs accessible (200 response)
- ZIP file integrity confirmed
- Registry accurately reflects pack contents
- Checksums match between local and remote

## Troubleshooting

### Common Issues

#### StarDict Download Fails
```bash
# Check internet connection and URL
curl -I https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/Portuguese-English%20Wiktionary%20dictionary%20stardict.tar.gz
```

#### PyGlossary Conversion Errors
- Some corruption errors are expected and handled
- Check logs for excessive error rates (>50%)
- Verify minimum entry count is still met

#### GitHub Upload Fails
```bash
# Check authentication
gh auth status

# Check release exists
gh release view language-packs-v2.0
```

#### Low Entry Count
- Check source dictionary size
- Verify conversion didn't fail silently
- Compare with expected entry counts

### Log Analysis
```bash
# View generation logs
tail -f ../logs/pt-en_*.log

# Check for specific errors
grep -i error ../logs/pt-en_*.log
grep -i warning ../logs/pt-en_*.log
```

## Next Language Recommendations

### Priority Order (by app usage)
1. **Portuguese** (pt-en) - Romance language, large user base
2. **Russian** (ru-en) - Cyrillic script, different language family
3. **Japanese** (ja-en) - Complex writing system, high demand
4. **Korean** (ko-en) - Hangul script, growing popularity
5. **Chinese** (zh-en) - Character-based, largest potential user base
6. **Arabic** (ar-en) - Right-to-left script, unique requirements
7. **Hindi** (hi-en) - Devanagari script, large native speaker population

### Technical Considerations
- **Romance languages** (Portuguese): Similar to Spanish, expected smooth conversion
- **Cyrillic scripts** (Russian): May require special character handling
- **Asian languages** (Japanese, Korean, Chinese): Complex character sets, larger dictionaries
- **RTL languages** (Arabic): Right-to-left text considerations
- **Complex scripts** (Hindi): Devanagari character combinations

## Success Metrics

### Generation Success
- ✅ Process completes without fatal errors
- ✅ Entry count meets minimum threshold
- ✅ File sizes within expected ranges
- ✅ Verification passes all checks

### Deployment Success
- ✅ GitHub upload successful
- ✅ Registry update complete
- ✅ Download URLs accessible
- ✅ iOS app compatibility maintained

### Quality Success
- ✅ Bidirectional lookups functional
- ✅ Schema consistency maintained
- ✅ Rich content preservation
- ✅ Performance requirements met

---
*This guide ensures systematic, high-quality language pack generation with comprehensive verification at each step.*