# PolyRead Dictionary Tools

This directory contains the **Vuizur Dictionary Builder** - a simple, reliable tool for creating PolyRead-compatible language pack databases.

## ✅ Current Tool: `vuizur-dict-builder.sh`

**Purpose**: Creates language pack databases from Vuizur Wiktionary-Dictionaries repository

**Features**:
- Downloads comprehensive bilingual dictionaries from [Vuizur/Wiktionary-Dictionaries](https://github.com/Vuizur/Wiktionary-Dictionaries)
- Creates PolyRead-compatible SQLite databases with proper Drift/Wiktionary schema
- Handles multiple word forms (pipe-separated headwords)
- Generates metadata for pack identification
- Over 1M+ dictionary entries per language pair with full common vocabulary coverage
- **Performance optimized** with 6 database indexes for fast lookups
- **Full-text search (FTS5)** with BM25 ranking for fuzzy search
- **Legacy compatibility** fields for backward compatibility
- **Automatic triggers** for FTS synchronization

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

- **Database**: SQLite file with `dictionary_entries`, `pack_metadata`, and `dictionary_fts` tables
- **Package**: Compressed `.sqlite.zip` file ready for PolyRead
- **Size**: ~74MB compressed (from ~650MB uncompressed database with FTS indexes)
- **Entries**: 1M+ dictionary entries with full vocabulary coverage
- **Performance**: 6 optimized indexes + FTS5 for sub-100ms lookups

## Database Schema

```sql
-- Main dictionary table (Drift/Wiktionary compatible schema)
CREATE TABLE dictionary_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    
    -- Core Wiktionary Fields (Primary)
    written_rep TEXT NOT NULL,            -- Headword/lemma (Wiktionary standard)
    lexentry TEXT,                        -- Lexical entry ID (e.g., cold_ADJ_01)
    sense TEXT,                           -- Definition/meaning description
    trans_list TEXT NOT NULL,             -- Pipe-separated translations
    pos TEXT,                             -- Part of speech (noun, verb, etc.)
    domain TEXT,                          -- Semantic domain (optional)
    
    -- Language Pair Information
    source_language TEXT NOT NULL,        -- Source language code (ISO)
    target_language TEXT NOT NULL,        -- Target language code (ISO)
    
    -- Additional Metadata
    pronunciation TEXT,                   -- IPA or phonetic pronunciation
    examples TEXT,                        -- JSON array of example sentences
    frequency INTEGER DEFAULT 0,          -- Usage frequency ranking
    source TEXT,                          -- Dictionary pack source name
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    -- Legacy Compatibility Fields (Maintained for backward compatibility)
    lemma TEXT DEFAULT '',                -- Legacy alias for written_rep
    definition TEXT DEFAULT '',           -- Legacy alias for sense
    part_of_speech TEXT,                  -- Legacy alias for pos
    language_pair TEXT DEFAULT ''         -- Legacy computed field (e.g., en-es)
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