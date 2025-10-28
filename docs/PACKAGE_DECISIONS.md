# Package Decision Matrix - Final Choices for PolyRead

This document provides definitive package choices for each feature, addressing the concerns raised about clarity and best-choice validation.

## 🎯 Decision Criteria

For each package selection, we evaluated:
1. **Maintenance Status**: Active development, recent updates, community support
2. **Platform Support**: iOS/Android/Web compatibility where needed
3. **Performance**: Benchmarks, memory usage, startup impact
4. **License Compatibility**: Commercial vs OSS requirements
5. **Fallback Options**: Backup packages if primary choice fails

## 📦 Core Architecture (Production Ready)

### State Management - LOCKED ✅
**Choice**: `riverpod: ^2.4.9`
**Why**: 
- Compile-time safety with code generation
- Excellent DevTools integration 
- No BuildContext dependency
- Built-in testing support

**Backup**: `flutter_bloc: ^8.1.3` (heavier but excellent tooling)

```yaml
dependencies:
  flutter_riverpod: ^2.4.9
  riverpod_annotation: ^2.3.3
dev_dependencies:
  riverpod_generator: ^2.3.9
  build_runner: ^2.4.7
```

### Database - LOCKED ✅
**Choice**: `sqflite: ^2.3.0` + `drift: ^2.14.1`
**Why**:
- Native SQLite performance with FTS (Full-Text Search)
- Type-safe queries with drift code generation
- Web support via `sqflite_common_ffi`
- Battle-tested with millions of apps

**Backup**: `isar: ^3.1.0` (faster but no FTS support)

```yaml
dependencies:
  sqflite: ^2.3.0
  drift: ^2.14.1
  sqlite3_flutter_libs: ^0.5.0
dev_dependencies:
  drift_dev: ^2.14.1
```

### HTTP & Downloads - VALIDATED ✅
**Choice**: `dio: ^5.3.2` + `background_downloader: ^8.3.1`
**Why**:
- Resumable downloads with progress tracking
- Background processing on both platforms
- Excellent error handling and retry logic
- Built-in caching and interceptors

**Web Fallback**: Standard `http: ^1.1.0` (background_downloader not supported)

```yaml
dependencies:
  dio: ^5.3.2
  background_downloader: ^8.3.1  # Mobile only
  http: ^1.1.0  # Web fallback
```

## 📖 Reading Stack (Validated with Samples)

### PDF Handling - SPLIT DECISION 🟡
**Primary Choice**: `syncfusion_flutter_pdfviewer: ^23.2.7`
**Why**:
- Professional text selection and search
- Excellent rendering quality
- Built-in annotation support
- Fast performance on large files

**License Note**: Commercial license required for production ($999/year)

**OSS Alternative**: `pdfx: ^2.4.0`
**Why**: 
- Free and open source
- Good basic rendering
- Text extraction via separate `pdf_text: ^0.4.0`
- Lighter feature set but sufficient for reading

**Recommendation**: Start with `pdfx` for MVP, upgrade to Syncfusion if revenue justifies cost

```yaml
dependencies:
  # Commercial option (better features)
  syncfusion_flutter_pdfviewer: ^23.2.7
  
  # OR OSS option (sufficient for MVP)
  pdfx: ^2.4.0
  pdf_text: ^0.4.0
```

### EPUB Rendering - TESTED ✅
**Choice**: `epub_view: ^3.6.0`
**Why**:
- Maintained and actively developed
- Good text selection implementation
- Handles complex CSS reasonably well
- Built-in chapter navigation

**Tested with**: Project Gutenberg books with footnotes, poetry, and complex formatting
**Performance**: Acceptable on mid-range devices

**Backup**: Custom WebView implementation with `webview_flutter: ^4.4.2`

```yaml
dependencies:
  epub_view: ^3.6.0
  epubx: ^4.0.0  # For EPUB parsing
```

### File Management - STANDARD ✅
**Choices**: Well-established packages with clear use cases

```yaml
dependencies:
  path_provider: ^2.1.1      # Platform directories
  file_picker: ^6.1.1        # File selection
  open_filex: ^4.3.4         # Open with external apps
  path: ^1.8.3               # Path manipulation
```

## 🌍 Translation Stack (Multi-Platform Strategy)

### Mobile Translation - LOCKED ✅
**Choice**: `google_ml_kit: ^0.16.0`
**Why**:
- Google's official on-device translation
- Excellent quality and performance
- 50+ language pairs supported
- Fully offline once models downloaded

**Model sizes**: 20-40MB per language pair
**Performance**: 100-300ms typical sentence translation

```yaml
dependencies:
  google_ml_kit: ^0.16.0
```

### Web Translation - CUSTOM IMPLEMENTATION 🚨
**Challenge**: `google_ml_kit` not available on web

**Solution**: Bergamot WASM + WebWorker implementation
```dart
// Custom web translation using Bergamot WASM
class BergamotWebTranslationProvider implements TranslationProvider {
  // Load Bergamot WASM in WebWorker
  // Download Mozilla Firefox translation models
  // Implement same interface as ML Kit provider
}
```

**Fallback**: Server API with user opt-in
```dart
class ServerTranslationProvider implements TranslationProvider {
  // Google Translate API or similar
  // Only with explicit user consent
  // Clear privacy implications
}
```

### Dictionary Services - BATTLE-TESTED ✅
**Choice**: `sqflite` with custom StarDict conversion
**Why**:
- Instant lookups (< 5ms target achieved in PolyBook)
- Full-text search with FTS4/FTS5
- Offline-first, always available
- Reuse existing PolyBook dictionary data

**Performance Target**: 100K+ entries, < 10ms average lookup

## 🎮 UI & UX Packages

### Navigation - MODERN ✅
**Choice**: `go_router: ^12.1.3`
**Why**:
- Declarative routing with type safety
- Deep linking support
- Excellent integration with Riverpod
- Flutter team recommended

```yaml
dependencies:
  go_router: ^12.1.3
```

### Internationalization - STANDARD ✅
**Choice**: Built-in Flutter i18n + `intl: ^0.19.0`
**Why**:
- Official Flutter solution
- ARB file support
- Pluralization and formatting
- IDE integration

```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: ^0.19.0
```

### Fonts & Icons - FLEXIBLE ✅
```yaml
dependencies:
  google_fonts: ^6.1.0       # Web fonts on-demand
  flutter_svg: ^2.0.9        # SVG icon support
  # Custom fonts for CJK/RTL languages added locally
```

## 🔧 Development & Quality Tools

### Testing Stack - COMPREHENSIVE ✅
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  mockito: ^5.4.2
  build_runner: ^2.4.7
  flutter_lints: ^3.0.1
```

### Performance & Analytics - PRODUCTION READY ✅
```yaml
dependencies:
  sentry_flutter: ^7.14.0     # Crash reporting
  firebase_analytics: ^10.7.4 # Usage analytics (opt-in)
  package_info_plus: ^4.2.0   # App version info
```

## 🚨 Platform-Specific Considerations

### iOS Specific
```yaml
dependencies:
  background_fetch: ^1.2.0    # Background app refresh
  # ML Kit models: Downloaded to iOS Documents directory
  # File access: iOS-scoped Documents directory
```

### Android Specific  
```yaml
dependencies:
  workmanager: ^0.5.2         # Background processing
  # ML Kit models: Android-specific cache directory
  # File access: Scoped storage compliance
```

### Web Specific
```yaml
dependencies:
  webview_flutter_web: ^0.2.2+4  # For Bergamot WASM
  # Translation: Custom Bergamot implementation
  # File access: IndexedDB via sqflite_common_ffi
  # Downloads: Standard HTTP, no background support
```

## 📊 Package Size Impact Analysis

### Base App (No Language Packs)
- **Flutter Framework**: ~4MB
- **Core Dependencies**: ~2MB  
- **Custom Code**: ~1MB
- **Total Base**: ~7MB

### Per Language Pack
- **ML Kit Model**: 20-40MB
- **SQLite Dictionary**: 2-8MB compressed
- **Total Per Pair**: 25-50MB

### Storage Limits
- **Total App Limit**: 500MB (user configurable)
- **Per Language Pair**: 50MB average
- **Max Language Pairs**: ~10 pairs simultaneously

## 🔄 Migration & Fallback Strategy

### Package Upgrade Path
1. **Start with OSS packages** where available (`pdfx`, `epub_view`, etc.)
2. **Validate core functionality** with lighter dependencies
3. **Upgrade to commercial** only when revenue justifies cost
4. **Maintain compatibility layers** for easy switching

### Fallback Implementations
Each major package has a documented fallback:
- PDF: Syncfusion → pdfx → WebView + PDF.js
- Translation: ML Kit → Bergamot → Server API → Dictionary-only
- State: Riverpod → Bloc → setState
- Database: Drift → Raw sqflite → Shared preferences

## ✅ Final Recommendations

### Start With (MVP Phase)
```yaml
dependencies:
  flutter_riverpod: ^2.4.9
  sqflite: ^2.3.0
  dio: ^5.3.2
  pdfx: ^2.4.0                 # OSS PDF solution
  epub_view: ^3.6.0
  google_ml_kit: ^0.16.0      # Mobile only
  go_router: ^12.1.3
```

### Upgrade Later (Revenue-Justified)
```yaml
dependencies:
  syncfusion_flutter_pdfviewer: ^23.2.7  # Better PDF features
  # Premium analytics, crash reporting, etc.
```

### Custom Implementations Required
- **Web Translation**: Bergamot WASM + WebWorker
- **Dictionary Conversion**: StarDict → SQLite (port from PolyBook)
- **Language Pack Management**: GitHub releases integration
- **Translation UI**: Two-level cycling popups

This package selection provides a clear path from MVP to production, with validated choices that solve PolyBook's complexity while maintaining feature parity.