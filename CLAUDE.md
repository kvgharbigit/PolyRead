# PolyRead - Language Learning Flutter App

## Project Overview
PolyRead is a Flutter-based language learning application that enables users to read books in foreign languages with integrated translation and dictionary support. The app supports PDF and EPUB formats with real-time translation capabilities using both local dictionaries and ML Kit translation models.

## 🌟 Key Achievement: Vuizur Dictionary System v2.1

- **Revolutionary Scale**: 2,172,196 dictionary entries for Spanish-English
- **Data Source**: Vuizur Wiktionary-Dictionaries for comprehensive vocabulary coverage
- **Performance**: Sub-millisecond lookups with 5 database indexes + FTS5 search
- **Quality**: Complete vocabulary with all common words, idioms, and technical terms
- **Architecture**: Modern Drift/Wiktionary schema with legacy compatibility

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

### ✅ Completed (v2.1)
- **Spanish-English Dictionary**: 2,172,196 entries deployed
- **Performance Optimization**: 5 database indexes + FTS5 search
- **GitHub Distribution**: Automated release system
- **App Integration**: Complete language pack management UI
- **Quality Assurance**: Comprehensive validation and testing

### 🚧 Development Pipeline
- **French-English**: Ready for generation (~1M+ entries)
- **German-English**: Ready for generation (~1M+ entries)
- **Portuguese-English**: Ready for generation (~1M+ entries)

### 🔧 Tools & Generation
- **Builder Script**: `tools/vuizur-dict-builder.sh` for automated generation
- **Data Source**: Vuizur Wiktionary-Dictionaries repository
- **Output**: Production-ready `.sqlite.zip` packages

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