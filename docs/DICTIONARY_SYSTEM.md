# PolyRead Dictionary System Documentation

## 🎯 Overview

PolyRead features a comprehensive bilingual dictionary system supporting offline translation across multiple language pairs. The system uses revolutionary cycling dictionary architecture serving **126,914 verified dictionary entries** with sub-millisecond lookups and automatic installation verification.

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     POLYREAD DICTIONARY SYSTEM                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐    ┌──────────────────┐    ┌─────────────┐ │
│  │   UI LAYER      │    │   SERVICE LAYER   │    │  DATA LAYER │ │
│  │                 │    │                  │    │             │ │
│  │ • Translation   │◄──►│ • Bidirectional  │◄──►│ • SQLite    │ │
│  │   Overlay       │    │   Dictionary     │    │   Databases │ │
│  │ • Language Pack │    │ • Import Service │    │ • FTS Index │ │
│  │   Manager       │    │ • Pack Manager   │    │ • Metadata  │ │
│  │ • Reader        │    │ • Translation    │    │ • Registry  │ │
│  │   Integration   │    │   Coordinator    │    │             │ │
│  └─────────────────┘    └──────────────────┘    └─────────────┘ │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│                    EXTERNAL INTEGRATION                         │
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐  │
│  │  GITHUB     │    │  VUIZUR     │    │    ML KIT           │  │
│  │  RELEASES   │    │  WIKTIONARY │    │  TRANSLATION        │  │
│  │             │    │  SOURCES    │    │                     │  │
│  │ • Pack      │    │ • Rich      │    │ • Online Fallback   │  │
│  │   Downloads │    │   Content   │    │ • 60+ Languages     │  │
│  │ • Registry  │    │ • Verified  │    │ • Offline Models    │  │
│  │   Updates   │    │   Sources   │    │                     │  │
│  └─────────────┘    └─────────────┘    └─────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## 📊 Current System Status

### ✅ Production Ready
- **Spanish-English Pack**: 2,172,196 entries with complete vocabulary coverage
- **Performance**: Sub-millisecond lookups with 5 database indexes + FTS5 search
- **Quality**: 4-level verification process with comprehensive testing
- **Architecture**: Vuizur Wiktionary system with modern Drift/Wiktionary schema

### 🚧 Development Pipeline
- **French-English**: Ready for Vuizur generation
- **German-English**: Ready for Vuizur generation  
- **Portuguese-English**: Ready for Vuizur generation

## 🗄️ Database Schema

### Schema Version: 4
- **ORM**: Drift (type-safe SQL generation)
- **Storage**: SQLite with FTS5 full-text search
- **Migration Strategy**: Automatic schema upgrades with legacy field compatibility

### Core Tables

#### 1. Dictionary Entries (Wiktionary Compatible)
```sql
CREATE TABLE dictionary_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    
    -- Core Wiktionary Fields (Primary)
    written_rep TEXT NOT NULL,            -- Headword/lemma (Wiktionary standard)
    lexentry TEXT,                        -- Lexical entry ID (e.g., "cold_ADJ_01")
    sense TEXT,                           -- Definition/meaning description
    trans_list TEXT NOT NULL,             -- Pipe-separated translations ("frío | helado | gélido")
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
    
    -- Legacy Compatibility Fields (Maintained via triggers)
    lemma TEXT DEFAULT '',                -- Legacy alias for written_rep
    definition TEXT DEFAULT '',           -- Legacy alias for sense
    part_of_speech TEXT,                  -- Legacy alias for pos
    language_pair TEXT DEFAULT ''         -- Legacy computed field (e.g., "en-es")
);
```

#### 2. Full-Text Search (FTS5)
```sql
CREATE VIRTUAL TABLE dictionary_fts USING fts5(
    written_rep,                          -- Searchable headword
    sense,                                -- Searchable definition
    trans_list,                           -- Searchable translations
    content='dictionary_entries',         -- Source table
    content_rowid='id'                    -- Link to main table
);
```

#### 3. Language Packs Metadata
```sql
CREATE TABLE language_packs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pack_id TEXT UNIQUE NOT NULL,         -- Pack identifier (e.g., "es-en")
    name TEXT NOT NULL,                   -- Display name
    description TEXT,                     -- Pack description
    source_language TEXT NOT NULL,        -- Source language
    target_language TEXT NOT NULL,        -- Target language
    pack_type TEXT NOT NULL,              -- 'dictionary', 'translation_model', 'combined'
    version TEXT NOT NULL,                -- Semantic version
    size_bytes INTEGER NOT NULL,          -- Download size
    download_url TEXT NOT NULL,           -- GitHub release URL
    checksum TEXT NOT NULL,               -- SHA-256 checksum
    is_installed BOOLEAN DEFAULT FALSE,   -- Installation status
    is_active BOOLEAN DEFAULT FALSE,      -- Active status
    installed_at DATETIME,               -- Installation timestamp
    last_used_at DATETIME                -- Last usage timestamp
);
```

### Performance Optimization

#### Database Indexes (5 total)
```sql
-- Primary indexes for fast lookups
CREATE INDEX idx_dictionary_written_rep ON dictionary_entries(written_rep);
CREATE INDEX idx_dictionary_languages ON dictionary_entries(source_language, target_language);
CREATE INDEX idx_dictionary_pos ON dictionary_entries(pos);

-- Composite indexes for complex queries
CREATE INDEX idx_dictionary_lookup ON dictionary_entries(written_rep, source_language, target_language);
CREATE INDEX idx_reading_progress ON reading_progress(book_id, last_read_at);
```

#### Query Performance Targets
- **Dictionary Lookups**: <10ms average (with FTS fallback)
- **FTS Searches**: <50ms average with BM25 ranking
- **Reading Progress**: <5ms for position updates

## 🔧 Service Architecture

### Core Services

#### Dictionary Services (`lib/features/translation/services/`)
- **`DictionaryService`**: Main lookup interface
- **`DriftDictionaryService`**: Database-backed dictionary with Wiktionary field integration

#### Language Pack Services (`lib/features/language_packs/services/`)
- **`CombinedLanguagePackService`**: Unified dictionary + ML Kit downloads
- **`DriftLanguagePackService`**: Database operations and validation
- **`BidirectionalDictionaryService`**: Core lookup engine with direction support
- **`SqliteImportService`**: External database import with field mapping

#### Integration Services (`lib/core/services/`)
- **`DictionaryLoaderService`**: Sample dictionary generation and testing
- **`LanguagePackIntegrationService`**: Core system integration

### Service Architecture Pattern
```dart
Interface Layer (e.g., DictionaryService)
    ↓
Coordination Layer (e.g., BidirectionalDictionaryService)
    ↓
Data Access Layer (e.g., DriftDictionaryService)
    ↓
Database Layer (Drift ORM + SQLite)
```

### Bidirectional Lookup Strategy
1. **Primary Lookup**: Direct query in specified direction
2. **Reverse Lookup**: Automatic reverse direction query
3. **Fuzzy Matching**: FTS fallback for partial matches
4. **ML Kit Fallback**: Online translation for missing entries

## 📦 Language Pack System

### Vuizur Dictionary System v2.1

#### Data Source
- **Source**: [Vuizur Wiktionary-Dictionaries](https://github.com/Vuizur/Wiktionary-Dictionaries)
- **Quality**: Community-maintained Wiktionary extracts with regular updates
- **Coverage**: 1M+ entries per language pair with full common vocabulary
- **Format**: TSV with comprehensive word forms and definitions

#### Generation Pipeline
```bash
# Build Spanish-English dictionary
cd tools
./vuizur-dict-builder.sh es-en

# Output: dist/es-en.sqlite.zip ready for deployment
```

#### Pack Distribution
- **GitHub Releases**: Automated distribution via GitHub releases
- **Registry**: `comprehensive-registry.json` with pack metadata
- **Download Size**: ~80.5MB compressed per pack
- **Installation**: Automatic via Language Pack Manager

### Available Language Packs

| Language Pack | Word Groups | Meanings | Target Words | Status |
|---------------|-------------|----------|--------------|--------|
| 🇪🇸 Spanish ↔ English | 94,334 | 126,914 | 66,768 | ✅ **Cycling v2.1** |
| 🇫🇷 French ↔ English | ~90,000+ | ~120,000+ | ~60,000+ | 📋 **Ready** |
| 🇩🇪 German ↔ English | ~90,000+ | ~120,000+ | ~60,000+ | 📋 **Ready** |
| 🇵🇹 Portuguese ↔ English | ~90,000+ | ~120,000+ | ~60,000+ | 📋 **Ready** |

## 🔍 Usage Examples

### Basic Dictionary Lookup
```dart
// Get the cycling dictionary service
final dictionaryService = ref.read(cyclingDictionaryServiceProvider);

// Perform source → target lookup
final result = await dictionaryService.lookupSourceMeanings(
  "agua",
  "es",
  "en",
);

print(result.meanings.first.displayTranslation); // "water"
print(result.meanings.length); // 7 meanings available for cycling
```

### FTS Search Query
```sql
-- Full-text search with BM25 ranking
SELECT de.* FROM dictionary_entries de
JOIN dictionary_fts fts ON de.id = fts.rowid
WHERE dictionary_fts MATCH ?
  AND de.source_language = ?
  AND de.target_language = ?
ORDER BY bm25(dictionary_fts) ASC, de.frequency DESC
LIMIT 20;
```

### Translation List Processing
```dart
// Parse pipe-separated translations
final translations = entry.transList.split(' | ')
    .where((t) => t.trim().isNotEmpty)
    .map((t) => t.trim())
    .toList();

final primaryTranslation = translations.isNotEmpty ? translations.first : '';
final synonyms = translations.length > 1 ? translations.skip(1).toList() : <String>[];
```

## 🛡️ Quality Assurance

### Verification Process
1. **Structural Verification**: Schema consistency across all language packs
2. **Data Integrity**: Entry count verification and duplicate detection
3. **Functional Testing**: Lookup performance and accuracy validation
4. **Deployment Testing**: Installation and integration verification

### Quality Metrics
- **Schema Consistency**: 100% across all language packs
- **Data Integrity**: 2,172,196 verified entries with complete vocabulary coverage
- **Performance**: <1ms exact lookups, <100ms FTS searches
- **Test Coverage**: Comprehensive lookup and FTS testing

## 🔄 Migration & Compatibility

### Schema Migration
- **Current Version**: 4
- **Migration Path**: Automatic upgrades from previous versions
- **Data Preservation**: All migrations preserve existing data
- **Legacy Support**: Backward compatibility maintained through field mapping

### Field Mapping Strategy
**External → Internal Mapping (Modern Wiktionary Format):**
```
written_rep (external) → writtenRep (primary)
sense (external)       → sense (definition/meaning)
trans_list (external)  → transList (pipe-separated translations)
pos (external)         → pos (part of speech)
```

## 📞 Development Support

### Adding New Language Packs
```bash
# Generate new pack using Vuizur pipeline
./vuizur-dict-builder.sh <language-pair>

# Deploy to GitHub releases
gh release upload language-packs-v2.1 dist/<language-pair>.sqlite.zip
```

### Performance Tuning
- Check database indexes are properly utilized
- Monitor FTS query performance with EXPLAIN QUERY PLAN
- Use caching for frequently accessed entries
- Optimize batch operations for large imports

### Troubleshooting
- **Broken Pack Installation**: Use validation and auto-repair functionality
- **Slow Lookups**: Check index usage and FTS configuration
- **Missing Translations**: Verify pack installation and data integrity
- **Schema Errors**: Review migration logs and field mapping

## 🚀 Recent Improvements (v2.1.1)

### Enhanced Installation Process
- **Database Verification**: Rebuilt and re-uploaded corrupted database files
- **Test Lookups**: Automatic sample word testing after installation
- **Progress Granularity**: Updates every 10K entries (was 50K+) for better UX
- **Installation Validation**: Real-time verification of cycling dictionary functionality

### Performance Optimizations
- **Progress Updates**: 10x more frequent progress callbacks (every 10K vs 100K)
- **Batch Processing**: Optimized logging frequency (every 20 batches vs 100)
- **UI Responsiveness**: More granular progress bars and status updates
- **Error Recovery**: Improved error handling and database corruption detection

### Database Quality
- **Validated Schema**: All cycling dictionary tables verified and functional  
- **Sample Testing**: Automatic "agua → water" lookups confirm installation success
- **Clean Generation**: Rebuilt database with proper compression (17MB vs 49MB broken)
- **Production Ready**: 126,914 entries with 7 meanings for common words like "agua"

---

*This documentation covers the complete PolyRead dictionary system architecture, from database schema to service integration. For implementation details, refer to the specific service files in the codebase.*