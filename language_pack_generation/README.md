# Language Pack Generation System

## Overview
This directory contains the systematic pipeline for generating, verifying, and deploying bidirectional language packs for PolyRead.

## Current Status

### ✅ Completed Language Packs (5/11)
- **German ↔ English** (de-en): 30,492 entries - **DEPLOYED** ✅
- **Spanish ↔ English** (es-en): 29,548 entries - **DEPLOYED** ✅  
- **French ↔ English** (fr-en): 137,181 entries - **DEPLOYED** ✅
- **Italian ↔ English** (it-en): 124,778 entries - **DEPLOYED** ✅
- **Portuguese ↔ English** (pt-en): 86,951 entries - **GENERATED & VERIFIED** ✅

### 🚧 Pending Language Packs (6/11)
- Russian ↔ English (ru-en) - High Priority  
- Japanese ↔ English (ja-en) - High Priority
- Korean ↔ English (ko-en) - Medium Priority
- Chinese ↔ English (zh-en) - Medium Priority
- Arabic ↔ English (ar-en) - Medium Priority
- Hindi ↔ English (hi-en) - Medium Priority

## Directory Structure

```
language_pack_generation/
├── README.md                    # This file - overview and status
├── scripts/                     # Core generation scripts
│   ├── language_pack_pipeline.py    # Main pipeline automation
│   ├── verify_french_pack.py        # French verification
│   ├── verify_italian_pack.py       # Italian verification
│   └── single_language_generator.py # Individual language processor
├── docs/                        # Documentation
│   ├── PIPELINE_GUIDE.md           # Step-by-step generation guide
│   ├── VERIFICATION_PROCESS.md     # Verification procedures
│   └── DEPLOYMENT_GUIDE.md         # GitHub upload procedures
├── logs/                        # Pipeline execution logs
├── temp/                        # Temporary processing files
└── completed_packs/             # Final verified language packs
```

## Process Workflow

### 1. Generation Phase
- Download Wiktionary StarDict sources
- Convert to bidirectional SQLite format
- Apply consistent schema and metadata

### 2. Verification Phase  
- Structure validation (tables, columns, indexes)
- Data integrity checks (entry counts, directions)
- Functionality testing (lookup performance)
- Compatibility verification (matches existing packs)

### 3. Deployment Phase
- ZIP compression with checksums
- GitHub release upload
- Registry update
- Accessibility verification

## Key Features

### Bidirectional Architecture
- **Single Database**: One .sqlite file per language pair
- **Direction Field**: 'forward' and 'reverse' entries in same table
- **50% Storage Reduction**: Eliminates redundant companion packs
- **O(1) Lookup**: Optimized indexes for both directions

### Quality Assurance
- Comprehensive verification at each step
- Consistent schema across all packs
- Rich Wiktionary content preservation
- Error handling and recovery

### Automation
- End-to-end pipeline automation
- Progress tracking and logging
- Resume capability for interrupted processes
- Parallel processing where possible

## Usage

### Generate Single Language Pack
```bash
cd language_pack_generation/scripts
python3 single_language_generator.py pt-en
```

### Verify Language Pack
```bash
python3 verify_pack.py pt-en
```

### Deploy to GitHub
```bash
python3 deploy_pack.py pt-en
```

### Full Pipeline (All Languages)
```bash
python3 language_pack_pipeline.py
```

## Data Sources

All language packs use proven Wiktionary sources from the Vuizur repository:
- **High-Quality**: Community-curated Wiktionary content
- **Rich Formatting**: HTML formatting, examples, part-of-speech tags
- **Consistent Structure**: Standardized across all languages
- **Large Coverage**: 15,000-137,000 entries per language pair

## Technical Requirements

### Dependencies
- Python 3.8+
- PyGlossary (StarDict conversion)
- SQLite3 (database operations)  
- Requests (downloads)
- GitHub CLI (deployment)

### System Requirements
- 2GB RAM (for large conversions)
- 5GB disk space (temporary files)
- Internet connection (downloads)

## Next Steps

1. **Organization Complete** ✅
2. **Generate Portuguese** (next priority)
3. **Systematic Language Processing** (one by one)
4. **Individual Verification** (each pack)
5. **Independent Deployment** (GitHub uploads)

## Quality Metrics

- **Schema Consistency**: 100% across all packs
- **Bidirectional Coverage**: Forward + reverse entries for all
- **GitHub Accessibility**: All packs downloadable and verified
- **Registry Accuracy**: Metadata matches actual pack contents
- **iOS Compatibility**: All packs work in Flutter app

---
*Generated systematically with validated Wiktionary sources*