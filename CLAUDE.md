# PolyRead - Language Learning Flutter App

## Project Overview
PolyRead is a Flutter-based language learning application that enables users to read books in foreign languages with integrated translation and dictionary support. The app supports PDF and EPUB formats with real-time translation capabilities using both local dictionaries and ML Kit translation models.

## Recent Major Updates

### ✅ Vuizur Dictionary System (Completed)
- **Data Source Revolution**: Switched to Vuizur Wiktionary-Dictionaries for comprehensive vocabulary
- **1M+ Entries**: Over 1,086,098 dictionary entries per language pair with full common vocabulary
- **Quality Verified**: All basic words found (agua, casa, hacer, tener, ser, hola, tiempo, año, día, vez)
- **Simple Pipeline**: Single reliable script replaces complex legacy build systems
- **PolyRead Compatible**: Proper `dictionary_entries` table schema with metadata
- **Storage Efficient**: ~14MB compressed packages from reliable source
- **Legacy Cleanup**: Removed all outdated tools and documentation

## Architecture

### Core Components
- **Database**: Drift ORM with SQLite backend (`lib/core/database/app_database.dart`)
- **Language Packs**: Complete dictionary + ML Kit model management system
- **Translation**: Dual-mode translation (offline dictionaries + online ML Kit)
- **Reader**: Multi-format reader supporting PDF/EPUB with translation overlay
- **Navigation**: Go Router with Riverpod state management

### Key Services
- `CombinedLanguagePackService`: Handles unified dictionary + ML Kit downloads
- `DriftLanguagePackService`: Database operations and validation
- `DictionaryLoaderService`: Vuizur dictionary parsing and import  
- `ReaderTranslationService`: In-reader translation functionality

## Vuizur Dictionary System

### Architecture Features
- **Comprehensive Vocabulary**: 1M+ entries per language pair from Vuizur Wiktionary-Dictionaries
- **Quality Data Source**: Community-maintained Wiktionary extracts with regular updates
- **Simple Pipeline**: Single reliable script (`vuizur-dict-builder.sh`) replaces complex legacy systems
- **PolyRead Schema**: Compatible `dictionary_entries` table with proper metadata
- **Efficient Storage**: ~14MB compressed packages with full vocabulary coverage

### Database Schema (Vuizur Compatible) ✅

**Language Pack Schema:**
```sql
CREATE TABLE dictionary_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    lemma TEXT NOT NULL,                    -- Headword/term
    definition TEXT NOT NULL,              -- HTML-formatted definition  
    direction TEXT NOT NULL CHECK (direction IN ('forward', 'reverse')),
    source_language TEXT NOT NULL,        -- ISO language codes (es, en, fr, de)
    target_language TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE pack_metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
```

**Sample Metadata:**
```
language_pair: es-en
source_language: es
target_language: en
format_version: 2.0
source: Vuizur Wiktionary
```

### Dictionary Generation Workflow
1. **Build Dictionary**: `./vuizur-dict-builder.sh es-en`
2. **Download Source**: Fetches TSV from Vuizur Wiktionary-Dictionaries
3. **Process Data**: Splits pipe-separated headwords, creates entries
4. **Generate Package**: Creates compressed `.sqlite.zip` with metadata
5. **Deploy**: Upload to GitHub releases for app distribution

### Recovery Mechanisms
- **Startup Validation**: Automatically detects broken packs on app start
- **Manual Validation**: Storage tab → "Validate All Packs" button
- **Auto-Repair**: Marks broken packs for clean reinstall
- **Force Remove**: Complete cleanup including files and database entries

## Current Status

### ✅ Completed Features (Vuizur Dictionary System)
- **✅ Spanish ↔ English**: 1,086,098 entries - Comprehensive vocabulary verified
- **✅ Common Words Verified**: All basic vocabulary found (agua, casa, hacer, tener, ser, hola, tiempo, año, día, vez)
- **✅ Quality Data Source**: Vuizur Wiktionary-Dictionaries with regular community updates
- **✅ Simple Pipeline**: Single reliable `vuizur-dict-builder.sh` script
- **✅ PolyRead Schema**: Compatible `dictionary_entries` table with proper metadata
- **✅ Storage Efficient**: ~14MB compressed packages (125MB uncompressed)
- **✅ Legacy Cleanup**: Removed all outdated tools and complex build systems

### ✅ Recently Completed (Dynamic Size Verification)
- **Dynamic File Size Calculation**: Replaced hardcoded 50MB claims with actual filesystem measurements
- **Separate Size Display**: Dictionary (~1.5MB) and ML Kit models (~60-70MB) shown separately
- **Real-time Size Verification**: Dynamic filesystem scanning for actual SQLite file sizes
- **Accurate Storage Reporting**: ML Kit model estimates based on Google's actual per-language sizes

### 🚧 In Progress
- **Language Pack Pipeline**: Systematic generation system with comprehensive logging and verification

### 📋 Remaining Languages (Ready for Vuizur Pipeline)
- **fr-en**: French → English (available in Vuizur)
- **de-en**: German → English (available in Vuizur)
- **en-es**: English → Spanish (if available in Vuizur)
- **en-fr**: English → French (if available in Vuizur)
- **en-de**: English → German (if available in Vuizur)

Use: `./vuizur-dict-builder.sh <language-pair>` for any supported pair

### 🔄 Development Commands
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

### 🏭 Dictionary Generation (Vuizur System)
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

### 📁 Key File Structure
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

## Database Schema Verification ✅

### Dictionary Interaction Services (All Using Correct Schema)
- **BidirectionalDictionaryService**: Uses `writtenRep` for queries, maps to legacy `lemma` for backward compatibility  
- **DriftDictionaryService**: Uses modern Wiktionary fields (`writtenRep`, `sense`, `transList`) with FTS integration
- **SqliteImportService**: Correctly maps external (`lemma`/`definition`) → internal (`writtenRep`/`transList`) 

### Database Tables
- **language_packs**: Pack metadata and installation status
- **dictionary_entries**: Verified Wiktionary-compatible format with legacy compatibility  
- **dictionary_fts**: FTS search using modern field names (`writtenRep`, `sense`, `transList`)
- **books**: Imported PDF/EPUB files
- **reading_progress**: User reading state per book  
- **vocabulary_items**: User's learned vocabulary with SRS

### Schema Validation Results
- ✅ **408,950 dictionary entries** across 5 language packs verified
- ✅ **Consistent schema v2.0** across all external databases
- ✅ **Proper field mapping** from external to internal format
- ✅ **Bidirectional lookups** working with direction field
- ✅ **FTS integration** using correct Wiktionary field names
- ✅ **Legacy compatibility** maintained through explicit field population

## Dependencies
- **flutter_riverpod**: State management
- **drift**: Database ORM
- **dio**: HTTP client for downloads
- **google_mlkit_translation**: Offline translation
- **go_router**: Navigation
- **pdfx**: PDF rendering
- **epub_parser**: EPUB support

## Recent Fixes Applied
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

## Testing
- Unit tests for translation services
- Integration tests for dictionary import
- Widget tests for UI components
- Database validation tests

## Next Potential Improvements
- Enhanced progress indicators with more granular stages
- Background download support
- Automatic language detection
- Reading statistics and progress tracking
- Vocabulary learning games and SRS optimization

---
*Last updated: $(date)*