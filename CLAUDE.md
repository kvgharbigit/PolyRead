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

### ✅ **COMPLETED v2.5 - HYPERLINKED DICTIONARY INTEGRATION** 🔗

- **🔗 Bidirectional Dictionary Links**: Tap original words to open home-language-specific dictionary explanations
- **🎯 Smart Service Selection**: WordReference for quality pairs, Reverso for context, Google Translate fallback
- **🖱️ Conflict-Free Tap Handling**: Original word→dictionary, translated word→cycling, no interaction conflicts
- **🌍 Universal Language Support**: Any source→home language pair with intelligent URL generation
- **🎨 Visual Distinction**: Underlined original words (dictionary), dotted translated words (cycling)
- **⚙️ Intelligent Availability**: Dictionary links only when home ≠ source language, seamless UX
- **📱 External App Launch**: Opens browser/dictionary apps for comprehensive word explanations
- **🔧 Production Ready**: Full integration with existing Smart Contextual Translation v2.4 system

### ✅ **COMPLETED v2.4 - SMART CONTEXTUAL TRANSLATION** 🧠
- **🧠 Smart Word Prioritization**: AI-powered ranking using ML Kit sentence translation as ground truth
- **🎯 Fuzzy Matching Algorithm**: Handles conjugations, accents, and spelling variations (80% similarity + 20% position weight)
- **📍 Position-Aware Scoring**: Prioritizes translations based on expected word position in sentence context
- **⚡ Real-Time Sentence Translation**: Parallel word + sentence translation with automatic context extraction  
- **🎨 Visual Match Highlighting**: Bold matching words in sentence translation for immediate visual feedback
- **🔄 Dynamic Updates**: Highlighting updates seamlessly when cycling through different translation options
- **📊 Comprehensive Logging**: Detailed scoring breakdown with 🧠 SmartPrioritization and 🎯 highlighting logs
- **⚙️ Performance Optimized**: Smart caching of match results, no redundant calculations in UI layer
- **🎨 Ultra-Minimal Design**: Clean cycling translations without bracketed clutter
- **🔄 Smart Context Expansion**: Long-press reveals contextual information only when available
- **🌍 Home Language Translation**: Expanded context automatically translated to user's home language
- **🎯 Part-of-Speech Emojis**: Visual indicators for word types (📦 noun, ⚡ verb, 🎨 adjective, etc.)
- **💡 Visual Expansion Cues**: Small dot indicator shows when long-press expansion is available
- **🔧 Clean Data Parsing**: Separated core meanings from contextual brackets in dictionary generation
- **📊 Quality Filtering**: Context extraction properly distinguishes grammatical info from semantic context
- **⚡ Production Ready**: Working with 126K+ meanings, proper context separation, home language support
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

## 🧠 **BREAKTHROUGH: Smart Contextual Translation v2.4**

**✅ IMPLEMENTATION COMPLETE** - AI-powered contextual translation prioritization achieved:

### **Smart Prioritization Algorithm:**
- **Ground Truth**: Uses ML Kit sentence translation to rank dictionary candidates
- **Two-Factor Scoring**: 80% fuzzy similarity + 20% positional distance weighting
- **Fuzzy Matching**: Handles conjugations (beber→bebiendo), accents (desesperación→desperacion), case differences
- **Position Mapping**: Maps expected word position from source to target sentence  
- **Real-Time Processing**: Parallel sentence translation + word lookup with smart ranking
- **Visual Feedback**: Bolds matching words in sentence translation for immediate confirmation
- **Performance Optimized**: Caches match results, eliminates redundant calculations

### **Example Success Case:**
```
English: "How is he my master?" 
Spanish: "¿Cómo es él mi maestro?"
User taps: "master"

Before: Random order → amo, dueño, maestro, señor...
After:  Smart order → maestro (1.000), maestre (0.611), others (0.000)
Visual: "¿Cómo es él mi **maestro**?" (bolded for confirmation)
```

## 🎯 **MAJOR MILESTONE: Enhanced Translation Popup v2.3**

**✅ IMPLEMENTATION COMPLETE** - Revolutionary user experience achieved:

### **Core Achievements:**
- **Ultra-Minimal Interface**: Clean translations without bracketed clutter (📦 water vs ⚡ to be (auxiliary verb...))
- **Smart Context Expansion**: Long-press reveals meaningful context only when available
- **Home Language Translation**: Contextual information automatically translated to user's preferred language
- **Visual Word Type Indicators**: Part-of-speech emojis (📦 noun, ⚡ verb, 🎨 adjective, 👤 pronoun, etc.)
- **Intelligent Expansion Cues**: Small dot indicator shows when additional context is available
- **Clean Data Separation**: Core meanings vs contextual brackets properly parsed and stored
- **One-Level Cycling**: Simple tap-to-cycle through meanings without complex hierarchies
- **Generalized Schema**: Support for any language pair (es-en, fr-en, de-en, etc.)
- **Bidirectional Support**: Both source→target and target→source lookup with quality ranking
- **Production Scale**: 94K+ word groups, 126K+ meanings, 66K+ target words

### **Technical Implementation:**
- **Enhanced UI Components**: `CyclingTranslationPopup` with smart expansion logic and emoji indicators
- **Part-of-Speech System**: `PartOfSpeechEmojis` with comprehensive language-specific mappings
- **Improved Data Parsing**: Clean meaning extraction separating core translations from contextual brackets
- **Context Detection**: Intelligent expansion availability based on actual semantic context vs grammatical info
- **ML Kit Integration**: Automatic translation of expanded context to user's home language
- **Database Schema v6**: Generalized field names (`target_meaning`, `target_reverse_lookup`)
- **Service Layer**: `CyclingDictionaryService` with complete cycling functionality
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

## 🔗 **Dictionary Link Integration v2.5**

**✅ IMPLEMENTATION COMPLETE** - Universal dictionary hyperlinking achieved:

### **Smart Dictionary Service Selection:**
- **WordReference**: Best quality for major language pairs (EN↔ES, FR↔EN, DE↔EN, etc.)
- **Reverso Context**: European languages with contextual examples and usage
- **Google Translate**: Universal fallback supporting 100+ language pairs

### **Conflict-Free Interaction Design:**
```
Original Word (before →) ═══> Dictionary Link (underlined, primary color)
    ↓ perro → dog ↑
Translated Word (after →) ═══> Cycling Translations (dotted underline)
```

### **URL Generation Examples:**
```dart
// English→Spanish (Spanish speaker)
"dog" → https://www.wordreference.com/enes/translation.asp?spen=dog

// French→Spanish (Spanish speaker) 
"chien" → https://www.wordreference.com/fres/translation.asp?spen=chien

// Japanese→English (English speaker)
"犬" → https://translate.google.com/?sl=ja&tl=en&text=犬&op=translate
```

### **Technical Implementation:**
- **Service**: `DictionaryLinkService` with language pair detection and URL generation
- **UI Integration**: Conflict-free tap handling in `CyclingTranslationPopup`
- **Smart Availability**: Only shows links when home language ≠ source language
- **Visual Cues**: Clear distinction between dictionary (solid underline) and cycling (dotted underline)
- **External Launch**: Uses `url_launcher` for seamless browser/app integration

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