# PolyRead Implementation Plan - Detailed Flutter Migration

## 📦 Package Selection Matrix (Final Decisions)

### Core Architecture - Locked In ✅

| Feature | Primary Package | Why This Choice | Backup/Alternative |
|---------|----------------|-----------------|-------------------|
| **State Management** | `riverpod` (6.0.5+) | Simple, testable, no boilerplate, excellent dev tools | `bloc` (heavier but great tooling) |
| **Dependency Injection** | `riverpod` handles it | Co-located with state, clean architecture | `get_it` (service locator pattern) |
| **Local Database** | `sqflite` (2.3.0+) + `drift` (2.14.0+) | Battle-tested SQLite, FTS support, type-safe queries | `isar` (faster but no FTS) |
| **Key-Value Cache** | `hive` (4.0.0+) | Fast, simple, works offline | `shared_preferences` (config only) |
| **HTTP & Downloads** | `dio` (5.3.0+) + `background_downloader` (8.3.0+) | Robust, resumable downloads, progress tracking | `http` package (basic use cases) |
| **File Management** | `path_provider` (2.1.0+), `file_picker` (6.1.0+) | Standard Flutter approach | Native platform APIs |

### Reading Stack - Validated Choices ✅

| Feature | Primary Package | Why This Choice | Implementation Notes |
|---------|----------------|-----------------|---------------------|
| **EPUB Rendering** | `epub_view` (3.6.0+) | Good text selection, maintained, clean API | Test with complex books first |
| **PDF Viewing** | `syncfusion_flutter_pdfviewer` (23.2.7+) | Professional features, text selection, search | **License cost**: Check budget vs `pdfx` |
| **PDF Text Extraction** | `syncfusion_flutter_pdf` + `pdf_text` fallback | Reliable extraction for search/translation | Platform-specific implementation needed |
| **Text Selection UI** | Custom widgets + `flutter/services` | Fine-grained control for translation popups | Build on Flutter's SelectableText |

### Translation & Dictionary - Multi-Platform Strategy ✅

| Platform | Translation Engine | Dictionary Engine | Fallback Strategy |
|----------|-------------------|-------------------|-------------------|
| **iOS/Android** | `google_ml_kit` (0.16.0+) | `sqflite` + StarDict conversion | Dictionary → ML Kit → Error message |
| **Web** | Bergamot WASM + WebView bridge | `sqflite` (Web compatible) | Dictionary → Bergamot → Server API (opt-in) |
| **All Platforms** | Dictionary lookups (instant) | SQLite FTS (~5ms response) | Always available, no network |

### Platform-Specific Considerations 🚨

| Feature | iOS Implementation | Android Implementation | Web Implementation |
|---------|-------------------|----------------------|-------------------|
| **Background Downloads** | `background_fetch` + iOS Background Modes | `workmanager` + Android Services | Service Workers (limited) |
| **File System Access** | iOS Documents directory | Android External Storage | IndexedDB via `sqflite` |
| **PDF Text Extraction** | Native iOS PDFKit bridge | Android PdfRenderer + ML Kit OCR | PDF.js + Web Workers |
| **Translation Models** | ML Kit on-device models | ML Kit on-device models | Bergamot WASM models |

## 🏗 Architecture Interfaces (Implementation Ready)

### Translation Provider Interface

```dart
// lib/core/translation/translation_provider.dart
abstract class TranslationProvider {
  Future<bool> isLanguagePairSupported(String from, String to);
  Future<void> ensureModelsDownloaded(String from, String to, {bool wifiOnly = true});
  Future<String> translateText(String text, String from, String to);
  Future<List<String>> getAvailableLanguages();
  Future<double> getModelDownloadProgress(String from, String to);
  Future<void> deleteLanguageModel(String from, String to);
  String get providerName;
}

// Platform-specific implementations
class MlKitTranslationProvider implements TranslationProvider { /* mobile */ }
class BergamotTranslationProvider implements TranslationProvider { /* web */ }
class ServerTranslationProvider implements TranslationProvider { /* fallback */ }
```

### Reader Engine Interface

```dart
// lib/core/reader/reader_engine.dart
abstract class ReaderEngine {
  Future<List<Chapter>> getChapters();
  Future<List<TextSpan>> getPageContent(int pageIndex);
  Future<String> extractSelectionText(TextRange range);
  Future<Offset?> hitTest(double x, double y);
  Future<List<SearchResult>> searchText(String query);
  String get engineType; // 'pdf', 'epub', 'txt'
}

class PdfReaderEngine implements ReaderEngine { /* Syncfusion implementation */ }
class EpubReaderEngine implements ReaderEngine { /* epub_view implementation */ }
class PlainTextReaderEngine implements ReaderEngine { /* simple text */ }
```

### Language Pack Schema

```dart
// lib/core/language_packs/language_pack.dart
class LanguagePackManifest {
  final String id; // 'en-es'
  final String name; // 'English ↔ Spanish'
  final String version; // '1.2.0'
  final int totalSizeBytes; // 45_000_000
  final List<LanguagePackComponent> components;
  final String checksum; // SHA-256
  
  // Components: ML Kit models, SQLite dictionaries
  static const int MAX_TOTAL_SIZE = 500 * 1024 * 1024; // 500MB limit
}

class LanguagePackComponent {
  final String type; // 'mlkit_model', 'sqlite_dict'
  final String filename; // 'en-es.db'
  final int sizeBytes;
  final String checksum;
  final bool required; // Some components optional
}
```

## 🎯 Implementation Phases (12-Week Timeline)

### Phase 0: Architecture Validation (Week 1) 🔍

**Gate Criteria - Must Pass Before Phase 1**
- ✅ **ML Kit Proof**: EN↔ES translate 20 mixed sentences < 300ms, offline
- ✅ **PDF Text Extraction**: Selection accuracy ≥90% on 3 sample PDFs (novel, textbook, scanned)
- ✅ **EPUB Rendering**: Complex book rendering (footnotes, RTL, ruby text) acceptable
- ✅ **SQLite Performance**: Dictionary lookup < 10ms on 100K+ entry database

**Deliverables:**
```bash
lib/
├── core/proofs/
│   ├── ml_kit_proof.dart        # Translation round-trip test
│   ├── pdf_extraction_proof.dart # Text selection accuracy test  
│   ├── epub_rendering_proof.dart # Complex book rendering test
│   └── sqlite_performance_proof.dart # Dictionary lookup speed test
```

**Risk Mitigation:**
- If PDF extraction fails: Fall back to `pdfx` + manual OCR pipeline
- If EPUB rendering inadequate: Custom HTML renderer with `webview_flutter`
- If ML Kit latency too high: Reduce model size or add progressive loading

### Phase 1: Foundation Architecture (Weeks 2-3) 🏗️

**Core Services Implementation:**

```dart
lib/core/
├── database/
│   ├── app_database.dart        # Main SQLite database
│   ├── dictionary_database.dart # Dictionary lookups
│   └── migrations/              # Database version management
├── services/
│   ├── translation_service.dart # Multi-provider translation routing
│   ├── language_pack_service.dart # Download & installation management  
│   ├── reading_service.dart     # Book import & reading progress
│   └── settings_service.dart    # User preferences & language profiles
├── models/
│   ├── book.dart               # Book metadata & content structure
│   ├── translation_result.dart # Translation response models
│   └── user_profile.dart       # Language learning preferences
└── utils/
    ├── file_utils.dart         # File operations & validation
    ├── compression_utils.dart  # Language pack compression
    └── validation_utils.dart   # Input validation & sanitization
```

**State Management Setup:**
```dart
lib/providers/
├── translation_provider.dart   # Translation state & caching
├── library_provider.dart      # Book library state
├── reading_provider.dart      # Current reading session state
├── language_pack_provider.dart # Language pack installation state
└── settings_provider.dart     # User settings & preferences
```

### Phase 2: Reading Core (Weeks 4-5) 📖

**Reader Implementation:**

```dart
lib/features/reader/
├── engines/
│   ├── pdf_reader_engine.dart     # Syncfusion PDF implementation
│   ├── epub_reader_engine.dart    # epub_view implementation
│   └── text_reader_engine.dart    # Plain text reader
├── widgets/
│   ├── interactive_text_widget.dart # Tappable text with translation
│   ├── translation_popup.dart      # Translation overlay UI
│   ├── chapter_navigator.dart      # Chapter navigation controls
│   └── reading_progress.dart       # Progress tracking widget
├── services/
│   ├── text_selection_service.dart # Handle text selection logic
│   ├── reading_progress_service.dart # Persist reading position
│   └── bookmark_service.dart       # Bookmark management
└── models/
    ├── reading_session.dart        # Current reading state
    ├── text_selection.dart         # Selection range & metadata
    └── bookmark.dart               # Bookmark data structure
```

**Text Interaction Pipeline:**
1. User taps/selects text → `TextSelectionService`
2. Extract selected text → Appropriate `ReaderEngine`
3. Route to translation → `TranslationService` (dictionary first, then ML Kit)
4. Display result → `TranslationPopup` with cycling UI
5. Optional: Save to vocabulary → `VocabularyService`

### Phase 3: Translation Services (Weeks 6-7) 🌍

**Multi-Engine Translation Implementation:**

```dart
lib/features/translation/
├── providers/
│   ├── ml_kit_translation_provider.dart    # Google ML Kit (iOS/Android)
│   ├── bergamot_translation_provider.dart  # Bergamot WASM (Web)
│   └── server_translation_provider.dart    # Server fallback (opt-in)
├── services/
│   ├── centralized_translation_service.dart # Route requests to providers
│   ├── dictionary_service.dart             # SQLite dictionary lookups
│   ├── translation_cache_service.dart      # Cache frequent translations
│   └── model_download_service.dart         # ML Kit model management
├── widgets/
│   ├── bilingual_translation_popup.dart    # Two-level cycling UI
│   ├── word_definition_popup.dart          # Dictionary lookup results
│   ├── translation_loading.dart            # Download progress UI
│   └── language_pair_selector.dart         # Language selection UI
└── models/
    ├── translation_request.dart            # Translation input/output
    ├── dictionary_entry.dart               # Dictionary lookup result
    └── language_model_info.dart            # ML Kit model metadata
```

**Translation Routing Logic:**
```dart
// Intelligent fallback strategy
1. Word tap → Dictionary lookup (instant, always available)
2. Sentence selection → ML Kit translation (if models downloaded)
3. Unsupported language pair → Bergamot WASM (Web) or error message
4. Network available + opt-in → Server translation (fallback only)
```

### Phase 4: Language Pack Management (Weeks 8-9) 📦

**Language Pack System:**

```dart
lib/features/language_packs/
├── services/
│   ├── language_pack_download_service.dart # Download with resume capability
│   ├── language_pack_validation_service.dart # Checksum & integrity
│   ├── language_pack_installation_service.dart # Install & activate packs
│   └── storage_management_service.dart     # Quota management & cleanup
├── widgets/
│   ├── language_pack_manager.dart          # Main management UI
│   ├── download_progress_card.dart         # Per-pack download progress
│   ├── storage_usage_chart.dart            # Storage visualization
│   └── pack_installation_wizard.dart       # First-time setup flow
├── models/
│   ├── language_pack_manifest.dart         # Pack metadata & components
│   ├── download_progress.dart              # Download state tracking
│   └── storage_quota.dart                  # Storage limit management
└── repositories/
    ├── github_releases_repository.dart     # GitHub-hosted pack downloads
    └── local_pack_repository.dart          # Local installed pack management
```

**Storage Management Features:**
- **Quota System**: 500MB total limit with user-configurable per-pack limits
- **Automatic Cleanup**: LRU eviction when approaching storage limits
- **Resume Downloads**: Handle interrupted downloads with chunk verification
- **Background Downloads**: Use platform-appropriate background processing

### Phase 5: Advanced Features (Weeks 10-11) 🚀

**Vocabulary & Progress Tracking:**

```dart
lib/features/vocabulary/
├── services/
│   ├── vocabulary_service.dart             # SRS vocabulary building
│   ├── spaced_repetition_service.dart      # SRS algorithm implementation
│   ├── anki_export_service.dart            # Export to Anki format
│   └── reading_statistics_service.dart     # Reading progress analytics
├── widgets/
│   ├── vocabulary_card.dart                # Individual word/phrase cards
│   ├── srs_review_session.dart             # Spaced repetition review UI
│   ├── reading_stats_dashboard.dart        # Progress visualization
│   └── vocabulary_search.dart              # Search saved vocabulary
└── models/
    ├── vocabulary_item.dart                # Saved word/phrase with context
    ├── srs_card.dart                       # Spaced repetition card data
    └── reading_session_stats.dart          # Session statistics
```

**Advanced Reading Features:**
- **Reading Statistics**: Words per minute, vocabulary encountered, etc.
- **Smart Highlighting**: Auto-highlight words at user's difficulty level
- **Context Preservation**: Save word/phrase with surrounding context
- **Cross-Reference**: Link vocabulary items to book passages

### Phase 6: Polish & Deployment (Week 12) ✨

**Production Readiness:**

```dart
lib/core/
├── error_handling/
│   ├── app_exceptions.dart                 # Standardized error types
│   ├── error_reporter.dart                 # Crash reporting integration
│   └── user_friendly_errors.dart          # User-facing error messages
├── analytics/
│   ├── analytics_service.dart              # Usage analytics (opt-in)
│   ├── performance_monitoring.dart         # Performance tracking
│   └── feature_usage_tracker.dart          # Feature adoption metrics
├── app_lifecycle/
│   ├── app_startup.dart                    # App initialization sequence
│   ├── background_tasks.dart               # Background processing
│   └── memory_management.dart              # Memory optimization
└── quality_assurance/
    ├── integration_tests/                  # End-to-end test suite
    ├── performance_tests/                  # Performance benchmarks
    └── accessibility_tests/                # A11y compliance tests
```

**Deployment Pipeline:**
- **Code Quality**: 90%+ test coverage, static analysis with `dart analyze`
- **Performance**: Memory usage profiling, startup time optimization
- **Accessibility**: VoiceOver/TalkBack testing, font scaling support
- **Internationalization**: RTL language support, locale-specific formatting

## 🚨 Risk Mitigation & Fallback Plans

### High-Risk Areas & Mitigation

| Risk Area | Probability | Impact | Mitigation Strategy |
|-----------|-------------|--------|-------------------|
| **PDF Text Extraction Quality** | Medium | High | Spike test with hard samples; fallback to manual OCR |
| **Web Translation Latency** | High | Medium | Bergamot WASM worker; server API opt-in fallback |
| **EPUB Rendering Compatibility** | Medium | Medium | Test with complex books; custom HTML renderer backup |
| **ML Kit Model Size/Performance** | Low | High | Progressive model loading; quality vs size tuning |
| **iOS Background Download Limits** | High | Low | Clear user communication; foreground-only fallback |

### Platform-Specific Fallbacks

**Web Limitations & Solutions:**
```dart
// Web-specific translation provider with fallbacks
class WebTranslationProvider {
  // Primary: Bergamot WASM in WebWorker
  // Fallback 1: Server API (user opt-in required)
  // Fallback 2: Dictionary-only mode
  // Always available: Local SQLite dictionaries
}
```

**Mobile Storage Constraints:**
```dart
// Intelligent storage management
class StorageManager {
  static const int DEFAULT_QUOTA = 500 * 1024 * 1024; // 500MB
  
  // LRU eviction when approaching limits
  // User-configurable per-language quotas
  // Background cleanup of unused models
}
```

## 📊 Success Metrics & KPIs

### Technical Performance Targets
- **Dictionary Lookup**: < 10ms (target: 5ms)
- **Translation Latency**: < 300ms for typical sentences
- **App Startup Time**: < 2 seconds cold start
- **Memory Usage**: < 150MB baseline, < 300MB with models loaded
- **Crash Rate**: < 0.1% sessions

### User Experience Targets
- **First Translation**: < 30 seconds from app install (including model download)
- **Offline Functionality**: 100% of core features work without internet
- **Storage Efficiency**: < 50MB per language pair average
- **User Retention**: > 70% Day 7 retention (vs PolyBook benchmark)

### Migration Success Criteria
- **Feature Parity**: 100% of PolyBook core features implemented
- **Performance Improvement**: > 2x faster dictionary lookups
- **Build Stability**: Zero native module/build system issues
- **User Satisfaction**: > 4.5★ app store rating within 3 months

---

## 🔄 Migration Strategy from PolyBook

### Data Migration Plan
1. **SQLite Schema Compatibility**: Maintain PolyBook dictionary format
2. **Reading Progress Export**: JSON export/import for user data
3. **Vocabulary Migration**: CSV export with context preservation
4. **Settings Migration**: Config file compatibility layer

### Phased Rollout Strategy
1. **Alpha**: Internal testing with original PolyBook test cases
2. **Beta**: Limited user group (power users willing to test)
3. **Gradual Rollout**: 10% → 50% → 100% user migration
4. **Fallback Plan**: Keep PolyBook available during transition period

This implementation plan provides a clear roadmap with specific package choices, risk mitigation strategies, and measurable success criteria. Each phase builds incrementally toward a production-ready Flutter application that solves PolyBook's native module complexity while preserving all core functionality.