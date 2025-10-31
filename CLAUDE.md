# PolyRead - Language Learning Flutter App

## Project Overview
PolyRead is a Flutter-based language learning application that enables users to read books in foreign languages with integrated translation and dictionary support. The app supports PDF and EPUB formats with real-time translation capabilities using both local dictionaries and ML Kit translation models.

## 🌟 Key Achievement: Cycling Dictionary System v2.1

- **Revolutionary UI**: One-level meaning cycling with tap-to-cycle + long-press-to-expand
- **Generalized Schema**: Supports any language pair (es-en, fr-en, de-en, etc.)
- **Bidirectional**: Both source→target and target→source cycling with quality ranking
- **Production Scale**: 94,334 word groups, 126,914 meanings, 66,768 target words
- **Data Source**: Vuizur Wiktionary-Dictionaries with meaning-based processing
- **Performance**: Sub-millisecond lookups with optimized indexes
- **UI Ready**: Part-of-speech tags, context expansion, primary indicators
- **Quality Filtered**: No proper nouns, conjugations, or acronym pollution

## 🏗️ System Architecture

**Core Stack:**
- **Frontend**: Flutter with Material 3 design
- **State Management**: Riverpod providers
- **Database**: Drift ORM with SQLite backend
- **Translation**: Multi-provider (Dictionary → ML Kit → Server fallback)
- **Navigation**: Go Router for type-safe routing

**Key Features:**
- Multi-format reader (PDF/EPUB/HTML/TXT)
- Offline-first dictionary system
- Spaced repetition vocabulary learning
- Real-time translation overlay
- Language pack management

## 📊 Production Status

### ✅ **COMPLETED v2.2 - TAP-TO-TRANSLATE FUNCTIONAL** 🎯
- **🗂️ Complete Legacy Removal**: ALL legacy dictionary code removed - ZERO backward compatibility
- **🧹 Deep Code Cleanup**: Unused imports removed, legacy fallbacks eliminated, deprecated proofs disabled
- **🏗️ Clean Architecture**: Single cycling dictionary paradigm throughout entire codebase
- **🎨 Working Translation**: Tap-to-translate functionality fully operational in EPUB reader
- **🔄 Bidirectional Support**: Both source→target and target→source with quality-ranked cycling
- **⚡ Production Scale**: 94K+ word groups, 126K+ meanings, 66K+ reverse lookups
- **🚀 Zero Compilation Errors**: Core translation flow builds and runs perfectly
- **📱 Ready for Use**: Users can tap words for precise translation with WebView text selection
- **🔧 Clean Database**: Only cycling tables exist (WordGroups, Meanings, TargetReverseLookup)
- **🎯 Service Integration**: EPUB WebView → CyclingDictionaryService → TranslationService pipeline
- **📋 Updated Documentation**: All docs reflect current implementation state
- **🗑️ Legacy Artifacts Removed**: DatabaseAdapter deleted, SQLite proof disabled, JSON fallbacks removed
- **🧽 Code Optimization**: Unused imports cleaned, commented code removed, unused variables fixed
- **📐 Style Consistency**: Error handling patterns verified, TODO comments audited, dead code eliminated
- **⚡ Performance Optimizations**: Parallel provider status checks, optimized async operations, resource cleanup
- **🎯 Immersive Mode Removed**: Gesture overlays removed to prevent interference with text selection

### 🚧 Development Pipeline
- **French-English**: Ready for generation (~1M+ entries)
- **German-English**: Ready for generation (~1M+ entries)
- **Portuguese-English**: Ready for generation (~1M+ entries)

### 🔧 Tools & Generation
- **Builder Script**: `tools/vuizur-meaning-dict-builder.sh` generates cycling dictionaries
- **Data Source**: Vuizur Wiktionary-Dictionaries repository  
- **GitHub Actions**: `.github/workflows/dictionary-release.yml` for automated builds
- **Output**: Production-ready `.sqlite.zip` packages with cycling support

## 🎯 **MAJOR MILESTONE: Cycling Dictionary System v2.1**

**✅ IMPLEMENTATION COMPLETE** - Revolutionary cycling interface achieved:

### **Core Achievements:**
- **One-Level Cycling**: Simple tap-to-cycle through meanings without complex hierarchies
- **Generalized Schema**: Support for any language pair (es-en, fr-en, de-en, etc.)
- **Bidirectional Support**: Both source→target and target→source lookup with quality ranking
- **UI Innovation**: Tap-to-cycle + long-press-to-expand interaction pattern
- **Production Scale**: 94K+ word groups, 126K+ meanings, 66K+ target words

### **Technical Implementation:**
- **Database Schema v6**: Generalized field names (`target_meaning`, `target_reverse_lookup`)
- **Service Layer**: `CyclingDictionaryService` with complete cycling functionality
- **UI Components**: `CyclingTranslationPopup` with cycling and expansion capabilities
- **GitHub Pipeline**: Automated multi-language dictionary generation
- **Quality Filtering**: Proper noun removal, context preservation, quality scoring

### **Cycling Schema Specification:**
```sql
-- Generalized Cycling Dictionary Schema
CREATE TABLE word_groups (
    base_word TEXT NOT NULL,        -- "agua", "faire", "machen"
    source_language TEXT NOT NULL,  -- "es", "fr", "de"
    target_language TEXT NOT NULL   -- "en", "es", etc.
);

CREATE TABLE meanings (
    meaning_order INTEGER NOT NULL, -- 1, 2, 3... for cycling
    target_meaning TEXT NOT NULL,   -- "water", "faire", "machen"  
    context TEXT,                   -- "(archaic)", "(slang)"
    part_of_speech TEXT,            -- "noun", "verb", "adj"
    is_primary BOOLEAN              -- Primary meaning flag
);

CREATE TABLE target_reverse_lookup (
    target_word TEXT NOT NULL,      -- "water", "house"
    lookup_order INTEGER NOT NULL,  -- Quality-ranked cycling order
    quality_score INTEGER           -- Higher = better translation
);
```

## 📚 Documentation

For detailed technical information:

- **[Dictionary System](docs/DICTIONARY_SYSTEM.md)** - Complete database schema, service architecture, and usage examples
- **[Development Guide](DEVELOPMENT.md)** - Setup instructions, technical details, and current implementation status  
- **[Main README](README.md)** - Project overview, features, and quick start guide
- **[Tools Documentation](tools/README.md)** - Vuizur dictionary builder usage

## 🚀 Quick Start

```bash
# Clone and setup
git clone https://github.com/kvgharbigit/PolyRead.git
cd PolyRead
flutter pub get

# Generate database code
flutter packages pub run build_runner build

# Run the app
flutter run
```

---

*For complete technical documentation, architecture details, and development instructions, see [DEVELOPMENT.md](DEVELOPMENT.md)*