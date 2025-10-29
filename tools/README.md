# PolyRead Language Pack Tools

This directory contains tools for creating and managing language packs, copied from the original PolyBook project for future use.

## Scripts Overview

### `build-unified-pack.sh`
- **Source**: PolyBook's verified Wiktionary build system
- **Purpose**: Creates language packs from Vuizur/Wiktionary-Dictionaries repository
- **Features**: 
  - Downloads StarDict archives from verified URLs
  - Handles decompression of .dict.dz and .idx.gz files
  - Converts using PyGlossary with UTF-8 encoding support
  - Applies mobile optimization (journal_mode=OFF, etc.)
  - Creates `dict` table schema for app compatibility

**Usage:**
```bash
./build-unified-pack.sh fr-en    # French-English
./build-unified-pack.sh it-en    # Italian-English  
./build-unified-pack.sh pt-en    # Portuguese-English
./build-unified-pack.sh ru-en    # Russian-English
./build-unified-pack.sh ko-en    # Korean-English
./build-unified-pack.sh ja-en    # Japanese-English
./build-unified-pack.sh zh-en    # Chinese-English
./build-unified-pack.sh ar-en    # Arabic-English
./build-unified-pack.sh hi-en    # Hindi-English
```

### `scrape-wiktionary.py` & `scrape-wiktionary-top10.py`
- **Purpose**: Alternative Wiktionary data scrapers
- **Features**: Direct Wiktionary parsing for custom data extraction

### `install_deps.py`
- **Purpose**: Install required dependencies for language pack creation
- **Dependencies**: PyGlossary, requests, sqlite3, etc.

### `test_basic.py`
- **Purpose**: Basic testing framework for language pack validation

## PolyBook's Original Data Sources

The build script uses these verified Wiktionary sources from Vuizur repository:

- **French-English**: 3.2MB → ~20,000+ entries
- **Italian-English**: 5.3MB → ~30,000+ entries  
- **Portuguese-English**: 2.6MB → ~15,000+ entries
- **Russian-English**: 8.2MB → ~50,000+ entries
- **Korean-English**: 2.1MB → ~10,000+ entries
- **Japanese-English**: 3.7MB → ~25,000+ entries
- **Chinese-English**: 6.4MB → ~40,000+ entries
- **Arabic-English**: 2.9MB → ~18,000+ entries
- **Hindi-English**: 1.0MB → ~8,000+ entries

## Size Comparison Analysis

**Current PolyRead packs vs PolyBook sources:**
- German: ✅ 12,130 entries (matches PolyBook)
- Spanish: ⚠️ Two versions exist:
  - `es-en.sqlite.zip`: 0.4MB with 11,598 entries (newer)
  - `eng-spa.sqlite.zip`: 3.0MB with 11,598 entries (PolyBook-style)

**Why sizes differ:**
1. **PolyBook used rich StarDict format**: Contains HTML definitions, examples, pronunciation
2. **Current packs may be simplified**: Basic lemma→definition mapping
3. **Compression differences**: StarDict→SQLite optimization vs direct conversion

## Future Usage

To create language packs using PolyBook's exact sources and processing:

1. **Install dependencies**:
   ```bash
   python3 install_deps.py
   brew install pyglossary  # or pip install pyglossary
   ```

2. **Create individual language pack**:
   ```bash
   ./build-unified-pack.sh fr-en
   ```

3. **Convert to bidirectional format** (for PolyRead compatibility):
   - Use the created SQLite file as input to your bidirectional conversion script
   - Apply the new schema with `direction` field
   - Create forward/reverse entries

## Integration with PolyRead

These tools can be integrated with PolyRead's new bidirectional system by:
1. Using `build-unified-pack.sh` to create rich Wiktionary-based SQLite files
2. Converting the output to PolyRead's bidirectional schema
3. Creating zip files compatible with PolyRead's download system
4. Updating the comprehensive registry with proper metadata

This maintains the rich content from PolyBook while supporting PolyRead's improved bidirectional architecture.