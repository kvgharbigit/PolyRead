# PolyRead Development Guide

## 🎯 Project Overview

PolyRead is a Flutter-based language learning application with integrated translation and dictionary support. This guide covers development setup, architecture decisions, and current implementation status.

## 🔧 Development Setup

### Prerequisites
- Flutter 3.10+
- Dart 3.0+
- iOS 12+ / Android API 21+

### Installation
```bash
# Clone the repository
git clone https://github.com/kvgharbigit/PolyRead.git
cd PolyRead

# Install dependencies
flutter pub get

# Generate database code
flutter packages pub run build_runner build

# Run on device/simulator
flutter run
```

### Development Commands
```bash
# Run the app
flutter run

# Analyze code
flutter analyze

# Run tests
flutter test

# Build for release
flutter build apk

# Build for iOS (no codesigning)
flutter build ios --no-codesign
```

## 🏗️ Architecture

### Core Components
- **Database**: Drift ORM with SQLite backend (`lib/core/database/app_database.dart`)
- **Language Packs**: Complete dictionary + ML Kit model management system
- **Translation**: Dual-mode translation (offline dictionaries + online ML Kit)
- **Reader**: Multi-format reader supporting PDF/EPUB with translation overlay
- **Navigation**: Go Router with Riverpod state management

### Key Services
- `CombinedLanguagePackService`: Handles unified dictionary + ML Kit downloads (`lib/features/language_packs/services/`)
- `DriftLanguagePackService`: Database operations and validation (`lib/features/language_packs/services/`)
- `DictionaryLoaderService`: Sample dictionary generation and testing (`lib/core/services/`)
- `ReaderTranslationService`: In-reader translation functionality (`lib/features/reader/services/`)

### File Structure
```
lib/
├── core/
│   ├── database/app_database.dart        # Main database schema
│   └── providers/database_provider.dart  # Riverpod database provider
├── features/
│   └── language_packs/
│       ├── widgets/language_pack_manager.dart    # Main UI
│       ├── services/combined_language_pack_service.dart  # Core service
│       ├── services/drift_language_pack_service.dart     # Database ops
│       └── providers/language_packs_provider.dart        # State management
└── main.dart
```

## 📦 Vuizur Dictionary System

### Architecture Features
- **Comprehensive Vocabulary**: 1M+ entries per language pair from Vuizur Wiktionary-Dictionaries
- **Quality Data Source**: Community-maintained Wiktionary extracts with regular updates
- **Simple Pipeline**: Single reliable script (`vuizur-dict-builder.sh`) replaces complex legacy systems
- **PolyRead Schema**: Compatible `dictionary_entries` table with proper metadata
- **Efficient Storage**: ~80.5MB compressed packages with full vocabulary coverage

### Database Schema (Vuizur Compatible) ✅

**Language Pack Schema:**
```sql
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
    
    -- Legacy Compatibility Fields (Maintained for data migration only)
    lemma TEXT DEFAULT '',                -- Deprecated: Use written_rep
    definition TEXT DEFAULT '',           -- Deprecated: Use sense or trans_list
    part_of_speech TEXT,                  -- Deprecated: Use pos
    language_pair TEXT DEFAULT ''         -- Deprecated: Use source_language + target_language
);
```

### Database Tables
- **language_packs**: Pack metadata and installation status
- **dictionary_entries**: Verified Wiktionary-compatible format with legacy compatibility  
- **dictionary_fts**: FTS search using modern field names (`writtenRep`, `sense`, `transList`)
- **books**: Imported PDF/EPUB files
- **reading_progress**: User reading state per book  
- **vocabulary_items**: User's learned vocabulary with SRS

### Schema Validation Results
- ✅ **2,172,196 dictionary entries** in Spanish-English v2.1 verified
- ✅ **Consistent schema v2.0** across all external databases
- ✅ **Proper field mapping** from external to internal format
- ✅ **Bidirectional lookups** working with direction field
- ✅ **FTS integration** using correct Wiktionary field names
- ✅ **Legacy compatibility** maintained through explicit field population

## 📊 Current Status

### ✅ Completed Features (Vuizur Dictionary System v2.1)
- **✅ Spanish ↔ English**: 2,172,196 entries - Complete vocabulary with FTS5 search
- **✅ Performance Optimized**: Sub-millisecond lookups with 5 database indexes  
- **✅ Quality Data Source**: Vuizur Wiktionary-Dictionaries with regular community updates
- **✅ Production Pipeline**: Reliable `vuizur-dict-builder.sh` with automated FTS5 + indexing
- **✅ Perfect Compatibility**: Drift/Wiktionary schema with legacy compatibility fields
- **✅ GitHub Deployment**: v2.1 release with 80.5MB optimized package ready for download
- **✅ Frontend Integration**: All download URLs and fallbacks updated to v2.1
- **✅ Complete Cleanup**: Removed all v2.0 bidirectional system references

### ✅ Recently Completed (Dynamic Size Verification)
- **Dynamic File Size Calculation**: Replaced hardcoded 50MB claims with actual filesystem measurements
- **Separate Size Display**: Dictionary (~1.5MB) and ML Kit models (~60-70MB) shown separately
- **Real-time Size Verification**: Dynamic filesystem scanning for actual SQLite file sizes
- **Accurate Storage Reporting**: ML Kit model estimates based on Google's actual per-language sizes

### 🚧 In Progress
- **Language Pack Pipeline**: Systematic generation system with comprehensive logging and verification

### 📋 Next Languages (Ready for Vuizur Pipeline)
- **fr-en**: French → English (~1M+ entries, pipeline ready)
- **de-en**: German → English (~1M+ entries, pipeline ready)  
- **pt-en**: Portuguese → English (~1M+ entries, pipeline ready)

Use: `./vuizur-dict-builder.sh <language-pair>` for any supported pair

## 🏭 Dictionary Generation (Vuizur System)
```bash
# Build Spanish-English dictionary
cd tools
./vuizur-dict-builder.sh es-en

# Build French-English dictionary  
./vuizur-dict-builder.sh fr-en

# Build German-English dictionary
./vuizur-dict-builder.sh de-en

# Output: dist/<language-pair>.sqlite.zip ready for deployment
```

## 🧰 Dependencies
- **flutter_riverpod**: State management
- **drift**: Database ORM
- **dio**: HTTP client for downloads
- **google_ml_kit**: Offline translation and ML services
- **go_router**: Navigation
- **pdfx**: PDF rendering
- **epubx**: EPUB parsing
- **epub_view**: EPUB display

## 🛠️ Recent Fixes Applied
1. **UNIQUE Constraint Fix**: Proper upsert handling in language pack registration
2. **Progress Stream**: StreamBuilder integration for real-time UI updates
3. **Broken State Detection**: Comprehensive validation with file and database checks
4. **Auto-Recovery**: Startup validation with automatic repair suggestions
5. **UI Consolidation**: Simplified language pack management interface
6. **Error Handling**: Robust error recovery and user feedback
7. **iOS Build Compatibility**: Fixed import conflicts and Drift syntax for successful iOS compilation
8. **Expanded Language Support**: Added German (de-en) and additional Spanish variants compatibility
9. **Dynamic Size Calculation**: Replaced misleading hardcoded 50MB with real file sizes (~1.5MB dict + ~60-70MB ML Kit)
10. **Accurate Progress Tracking**: Fixed suspicious 1-second downloads with actual GitHub file sizes

## 🧪 Testing
- Unit tests for translation services
- Integration tests for dictionary import
- Widget tests for UI components
- Database validation tests

## 🔮 Next Potential Improvements
- Enhanced progress indicators with more granular stages
- Background download support
- Automatic language detection
- Reading statistics and progress tracking
- Vocabulary learning games and SRS optimization

## 📞 Development Support

### Common Issues
- **Build Runner**: Use `flutter packages pub run build_runner build --delete-conflicting-outputs` for clean generation
- **Database Issues**: Check migration logs and field mapping in `app_database.dart`
- **Language Pack Problems**: Use validation functions in `DriftLanguagePackService`

### Performance Optimization
- Database indexes are automatically created - see schema documentation
- FTS queries use BM25 ranking for optimal results
- Caching is implemented at service level

### Adding New Features
- Follow existing service architecture patterns
- Use Riverpod for state management
- Maintain backward compatibility for database changes
- Update relevant documentation

---

*For complete system architecture and database details, see [Dictionary System Documentation](docs/DICTIONARY_SYSTEM.md)*