# PolyRead Dictionary Tools

This directory contains the **Vuizur Dictionary Builder** - a simple, reliable tool for creating PolyRead-compatible language pack databases.

## ✅ Current Tool: `vuizur-dict-builder.sh`

**Purpose**: Creates language pack databases from Vuizur Wiktionary-Dictionaries repository

**Features**:
- Downloads comprehensive bilingual dictionaries from [Vuizur/Wiktionary-Dictionaries](https://github.com/Vuizur/Wiktionary-Dictionaries)
- Creates PolyRead-compatible SQLite databases with proper schema
- Handles multiple word forms (pipe-separated headwords)
- Generates metadata for pack identification
- Over 1M+ dictionary entries per language pair
- Full common vocabulary coverage

## Usage

```bash
# Build Spanish-English dictionary
./vuizur-dict-builder.sh es-en

# Build French-English dictionary  
./vuizur-dict-builder.sh fr-en

# Build German-English dictionary
./vuizur-dict-builder.sh de-en
```

## Output

- **Database**: SQLite file with `dictionary_entries` and `pack_metadata` tables
- **Package**: Compressed `.sqlite.zip` file ready for PolyRead
- **Size**: ~14MB compressed (from ~125MB uncompressed database)
- **Entries**: 1M+ dictionary entries with full vocabulary coverage

## Database Schema

```sql
-- Main dictionary table
CREATE TABLE dictionary_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    lemma TEXT NOT NULL,                    -- Headword/term
    definition TEXT NOT NULL,              -- HTML-formatted definition  
    direction TEXT NOT NULL CHECK (direction IN ('forward', 'reverse')),
    source_language TEXT NOT NULL,        -- ISO language codes
    target_language TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Pack metadata
CREATE TABLE pack_metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
```

## Verification Results

**✅ Spanish-English Dictionary:**
- **Entries**: 1,086,098 dictionary entries
- **Common words**: All basic vocabulary found (agua, casa, hacer, tener, ser, hola, tiempo, año, día, vez)
- **Quality**: Comprehensive coverage with conjugated forms, synonyms, and specialized terms
- **Schema**: PolyRead-compatible with proper metadata

## Supported Language Pairs

Currently supported language pairs from Vuizur repository:
- **es-en**: Spanish → English
- **fr-en**: French → English  
- **de-en**: German → English
- **en-es**: English → Spanish (if available)

## Data Source

**Vuizur Wiktionary-Dictionaries**: https://github.com/Vuizur/Wiktionary-Dictionaries
- High-quality bilingual dictionaries extracted from Wiktionary
- TSV format with comprehensive word forms and definitions
- Regular updates and community maintenance
- Creative Commons licensed

## Legacy Cleanup

**Removed legacy tools** (as of 2025-10-29):
- `build-unified-pack.sh` - Complex, unreliable pipeline
- `simple-build.sh` - Incomplete implementation  
- `scrape-wiktionary*.py` - Direct scraping approach
- All `tmp-unified-*` directories - Old processing artifacts

The new `vuizur-dict-builder.sh` replaces all previous approaches with a simple, reliable solution.