# PolyRead - Language Learning Flutter App

## Project Overview
PolyRead is a Flutter-based language learning application that enables users to read books in foreign languages with integrated translation and dictionary support. The app supports PDF and EPUB formats with real-time translation capabilities using both local dictionaries and ML Kit translation models.

## Recent Major Updates

### ✅ Language Pack System Overhaul (Completed)
- **Consolidated UI**: Simplified from 3-tab structure (Available/Installed/Storage) to 2-tab structure (Language Packs/Storage)
- **Real-time Progress**: Fixed UI to show live download progress with StreamBuilder integration
- **Database Fixes**: Resolved UNIQUE constraint conflicts in language pack registration
- **Broken State Handling**: Implemented comprehensive validation and auto-repair for corrupted installations
- **Error Recovery**: Added retry mechanisms and force-remove options for failed installations

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
- `DictionaryLoaderService`: Wiktionary dictionary parsing and import
- `ReaderTranslationService`: In-reader translation functionality

## Language Pack System

### Features
- **Bidirectional Support**: Single download provides both language directions
- **Progress Tracking**: Real-time download progress with stage descriptions
- **Validation**: Automatic detection and repair of broken installations
- **Force Removal**: Complete cleanup of corrupted installations
- **Auto-Repair**: Startup validation with automatic fix suggestions

### Installation Flow
1. User selects language pair (e.g., English ↔ Spanish)
2. Downloads dictionary data from GitHub releases
3. Extracts and imports Wiktionary data to SQLite
4. Downloads ML Kit translation models
5. Registers both directions in database
6. Provides validation and recovery options

### Recovery Mechanisms
- **Startup Validation**: Automatically detects broken packs on app start
- **Manual Validation**: Storage tab → "Validate All Packs" button
- **Auto-Repair**: Marks broken packs for clean reinstall
- **Force Remove**: Complete cleanup including files and database entries

## Current Status

### ✅ Completed Features
- Language pack download and installation system
- Real-time progress tracking with UI updates
- Broken state detection and recovery
- Bidirectional dictionary support
- ML Kit integration for offline translation
- Database schema with proper constraints
- Error handling and logging throughout
- iOS build compatibility with expanded language support
- German and additional Spanish language variants

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