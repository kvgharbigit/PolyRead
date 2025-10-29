# PolyRead - Language Learning Flutter App

## Project Overview
PolyRead is a Flutter-based language learning application that enables users to read books in foreign languages with integrated translation and dictionary support. The app supports PDF and EPUB formats with real-time translation capabilities using both local dictionaries and ML Kit translation models.

## Recent Major Updates

### ✅ Bidirectional Language Pack System (Completed)
- **Architecture Redesign**: Eliminated redundant companion pack system - single database per language pair
- **50% Storage Reduction**: One bidirectional database instead of separate forward/reverse packs
- **True Bidirectional**: O(1) lookup performance in both directions with direction field
- **Enhanced Schema**: New `dictionary_entries` table with direction, source_language, target_language fields
- **Verified Data Quality**: 60,040+ entries across German/Spanish with rich Wiktionary content
- **iOS Build Compatible**: All compilation errors resolved, successful iOS builds
- **PolyBook Source Integration**: Copied proven data sources and processing tools for future expansions

## Architecture

### Core Components
- **Database**: Drift ORM with SQLite backend (`lib/core/database/app_database.dart`)
- **Language Packs**: Complete dictionary + ML Kit model management system
- **Translation**: Dual-mode translation (offline dictionaries + online ML Kit)
- **Reader**: Multi-format reader supporting PDF/EPUB with translation overlay
- **Navigation**: Go Router with Riverpod state management

### Key Services
- `CombinedLanguagePackService`: Handles unified dictionary + ML Kit downloads with bidirectional support
- `BidirectionalDictionaryService`: New service for O(1) bidirectional dictionary lookups
- `DriftLanguagePackService`: Database operations and validation for single-pack system
- `DictionaryLoaderService`: Wiktionary dictionary parsing and import
- `ReaderTranslationService`: In-reader translation functionality

## Bidirectional Language Pack System

### Architecture Features
- **Single Database Architecture**: One `.sqlite` file per language pair instead of separate companion packs
- **Bidirectional Schema**: `dictionary_entries` table with `direction` field ('forward'/'reverse')
- **Rich Wiktionary Content**: HTML formatting, part-of-speech tags, examples preserved
- **Optimized Lookups**: Indexed by lemma+direction for O(1) performance in both directions
- **50% Storage Savings**: Eliminated redundant companion pack approach

### New Database Schema (v2.0)
```sql
CREATE TABLE dictionary_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    lemma TEXT NOT NULL,
    definition TEXT NOT NULL,
    direction TEXT NOT NULL CHECK (direction IN ('forward', 'reverse')),
    source_language TEXT NOT NULL,
    target_language TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE pack_metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
```

### Installation Flow
1. User selects language pair (e.g., English ↔ German)
2. Downloads single bidirectional `.sqlite.zip` from GitHub releases
3. Extracts bidirectional database with both directions
4. Downloads ML Kit translation models
5. Registers pack in database with bidirectional flag
6. Provides validation and recovery options

### Recovery Mechanisms
- **Startup Validation**: Automatically detects broken packs on app start
- **Manual Validation**: Storage tab → "Validate All Packs" button
- **Auto-Repair**: Marks broken packs for clean reinstall
- **Force Remove**: Complete cleanup including files and database entries

## Current Status

### ✅ Completed Features (Bidirectional System v2.0)
- **✅ German ↔ English**: 30,492 entries (12,130 forward + 18,362 reverse) - Verified
- **✅ Spanish ↔ English**: 29,548 entries (11,598 forward + 17,950 reverse) - Verified  
- **✅ Bidirectional Architecture**: Single database per language pair with direction field
- **✅ iOS Build Compatibility**: All compilation errors resolved, successful builds
- **✅ UI Transition**: Companion pack logic removed, single pack display
- **✅ Data Sources**: PolyBook's Wiktionary sources integrated for future expansion
- **✅ Verification System**: Comprehensive validation of schema, data integrity, and lookups

### 🚧 In Progress
- **French ↔ English**: Next high priority language pack using PolyBook sources
- **Italian ↔ English**: High priority language pack  
- **Portuguese ↔ English**: Medium priority language pack

### 📋 Available from PolyBook Sources
- French (3.2MB source → ~20,000+ entries)
- Italian (5.3MB source → ~30,000+ entries)
- Portuguese (2.6MB source → ~15,000+ entries)
- Russian (8.2MB source → ~50,000+ entries)
- Korean (2.1MB source → ~10,000+ entries)
- Japanese (3.7MB source → ~25,000+ entries)
- Chinese (6.4MB source → ~40,000+ entries)
- Arabic (2.9MB source → ~18,000+ entries)
- Hindi (1.0MB source → ~8,000+ entries)

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

## Database Schema
- **language_packs**: Pack metadata and installation status
- **dictionary_entries**: Wiktionary word definitions and translations
- **books**: Imported PDF/EPUB files
- **reading_progress**: User reading state per book
- **vocabulary_items**: User's learned vocabulary with SRS

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