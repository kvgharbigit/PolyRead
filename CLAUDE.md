# PolyRead - Language Learning Flutter App

## Project Overview
PolyRead is a Flutter-based language learning application that enables users to read books in foreign languages with integrated translation and dictionary support. The app supports PDF and EPUB formats with real-time translation capabilities using both local dictionaries and ML Kit translation models.

## 🌟 Key Achievement: Modern Dictionary System v2.1

- **Revolutionary Scale**: 2,172,196 dictionary entries for Spanish-English
- **Data Source**: Vuizur Wiktionary-Dictionaries for comprehensive vocabulary coverage
- **Performance**: Sub-millisecond lookups with 5 database indexes + FTS5 search
- **Quality**: Complete vocabulary with all common words, idioms, and technical terms
- **Architecture**: ✅ **FULLY UNIFIED** modern Wiktionary schema (written_rep, sense, trans_list, pos)
- **Consistency**: ✅ **ZERO legacy field references** - complete audit completed
- **Field Format**: All services use modern format with pipe-separated translations

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

### ✅ Completed (v2.1) - **AUDIT COMPLETE** 
- **Spanish-English Dictionary**: 2,172,196 entries deployed
- **Performance Optimization**: 5 database indexes + FTS5 search
- **GitHub Distribution**: Automated release system
- **App Integration**: Complete language pack management UI
- **Quality Assurance**: Comprehensive validation and testing
- **✅ Field Consistency**: **COMPLETE** - All legacy references eliminated
- **✅ Modern Schema**: **UNIFIED** - written_rep, sense, trans_list, pos format throughout
- **✅ Service Integration**: **CONSISTENT** - All UI components use modern field access

### 🚧 Development Pipeline
- **French-English**: Ready for generation (~1M+ entries)
- **German-English**: Ready for generation (~1M+ entries)
- **Portuguese-English**: Ready for generation (~1M+ entries)

### 🔧 Tools & Generation
- **Builder Script**: `tools/vuizur-dict-builder.sh` generates modern Wiktionary format
- **Data Source**: Vuizur Wiktionary-Dictionaries repository
- **Output**: Production-ready `.sqlite.zip` packages

## 🎯 **MAJOR MILESTONE: Complete Dictionary Field Audit (v2.1)**

**✅ AUDIT COMPLETED** - Full codebase consistency achieved:

### **Modernization Summary:**
- **DictionaryEntry Model**: Completely rewritten using modern Wiktionary format
- **Database Schema**: Unified `written_rep`, `sense`, `trans_list`, `pos` fields
- **Service Layer**: All services updated to modern field access patterns
- **UI Components**: Translation popups parse pipe-separated `trans_list` format
- **GitHub Workflows**: Validation queries updated for modern field names
- **Documentation**: All field references updated to modern naming

### **Legacy Elimination:**
- **Zero Legacy References**: No `.word`, `.definition`, `.partOfSpeech`, `.synonyms`, `.translations` access
- **Clean Constructors**: All `DictionaryEntry()` calls use modern parameters
- **Consistent Imports**: All external data properly converted to modern format
- **Verified Compilation**: Core dictionary system compiles without field errors

### **Modern Format Specification:**
```sql
-- Modern Wiktionary Schema (UNIFIED)
CREATE TABLE dictionary_entries (
    written_rep TEXT NOT NULL,     -- Headword (Wiktionary standard)
    sense TEXT,                    -- Definition/meaning
    trans_list TEXT NOT NULL,      -- Pipe-separated translations
    pos TEXT,                      -- Part of speech
    source_language TEXT NOT NULL,
    target_language TEXT NOT NULL
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