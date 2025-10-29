# PolyRead Documentation Index

Welcome to the comprehensive documentation for PolyRead's dictionary and translation system.

## 🚀 Quick Start

**New to PolyRead?** Start here:
1. **[Project Overview](../README.md)** - Main project documentation with installation guide
2. **[Dictionary System](DICTIONARY_SYSTEM.md)** - Complete architecture and technical overview ⭐
3. **[Development Setup](../CLAUDE.md)** - Detailed development instructions and project status

## 📚 Core Documentation

### **System Architecture**
| Document | Description | Audience |
|----------|-------------|----------|
| **[DICTIONARY_SYSTEM.md](DICTIONARY_SYSTEM.md)** | Complete database schema, service architecture, and usage examples | All |

### **Tools & Generation**
| Document | Description | Audience |
|----------|-------------|----------|
| **[Vuizur Builder](../tools/README.md)** | Language pack generation using Vuizur dictionary system | Developers |

## 🎯 By Use Case

### **👨‍💻 For Developers**

**Getting Started:**
1. [Dictionary System](DICTIONARY_SYSTEM.md) - Complete system architecture
2. [Main README](../README.md) - Project setup and dependencies
3. Service Code - Implementation details in `lib/features/translation/services/`

**Key Services:**
- `BidirectionalDictionaryService` - Core lookup engine (`lib/features/language_packs/services/`)
- `DriftDictionaryService` - Database integration (`lib/features/translation/services/`)
- `CombinedLanguagePackService` - Pack management (`lib/features/language_packs/services/`)

### **🏗️ For System Architects**

**Architecture Overview:**
1. [Dictionary System](DICTIONARY_SYSTEM.md) - Complete technical architecture
2. [Project Overview](../README.md) - High-level system design
3. [Development Details](../CLAUDE.md) - Internal architecture decisions

### **📦 For Language Pack Creators**

**Generation Workflow:**
1. [Vuizur Builder Guide](../tools/README.md) - Complete generation process
2. [Dictionary System](DICTIONARY_SYSTEM.md) - Database schema and requirements
3. [Vuizur Source](https://github.com/Vuizur/Wiktionary-Dictionaries) - Primary data source

**Requirements:**
- Bash shell environment
- curl for data fetching
- sqlite3 for database operations
- GitHub CLI for deployment

### **🔍 For Quality Assurance**

**Verification Process:**
1. [Dictionary System](DICTIONARY_SYSTEM.md) - Quality metrics and verification process
2. Service Tests - Quality validation in test suites
3. [Project Status](../CLAUDE.md) - Current verification results

**Quality Metrics:**
- **Schema Consistency**: 100% Drift/Wiktionary compatibility
- **Performance**: <1ms exact lookups, <100ms FTS searches
- **Data Integrity**: 2,172,196 verified entries with complete vocabulary coverage

## 📊 System Status

### **✅ Production Ready Components**
- **Vuizur Dictionary System v2.1**: Spanish-English deployed (2,172,196 entries)
- **Translation Services**: Multi-provider architecture with dictionary-first fallbacks
- **Database Schema**: Drift/Wiktionary compatible with FTS5 and performance indexes
- **Performance**: Sub-millisecond lookups with optimized search

### **🚧 Active Development**
- **Additional Languages**: French, German, Portuguese ready for Vuizur pipeline
- **FTS5 Search**: BM25-ranked fuzzy search with comprehensive coverage
- **Performance Optimization**: 5 database indexes for optimal speed

### **📈 Current Metrics**
- **Dictionary Entries**: 2,172,196 verified entries (Spanish-English)
- **Language Pairs**: 1 deployed, 3 ready for generation
- **Performance**: <1ms exact lookups, <100ms FTS searches

## 🔗 External Resources

### **Dependencies & Tools**
- **Flutter & Dart**: Core application framework
- **Drift ORM**: Database management
- **Vuizur Wiktionary-Dictionaries**: Primary data source
- **GitHub Releases**: Distribution system

### **Data Sources**
- **Wiktionary**: Primary dictionary content source
- **Vuizur TSV Format**: Processed Wiktionary data
- **Google ML Kit**: Online translation fallback

## 🤝 Contributing

### **Documentation**
- All docs are in Markdown format
- Follow existing structure and style
- Update this index when adding new docs

### **Code Contributions**
- Follow service architecture patterns in [Dictionary System](DICTIONARY_SYSTEM.md)
- Maintain test coverage
- Update relevant documentation

### **Language Packs**
- Use Vuizur generation pipeline for consistency
- Follow verification process in [Dictionary System](DICTIONARY_SYSTEM.md)
- Document any new language-specific requirements

---

## 📞 Support

**For technical questions:**
- Database/schema issues → [Dictionary System](DICTIONARY_SYSTEM.md)
- Setup/installation → [Main README](../README.md)
- Development details → [CLAUDE.md](../CLAUDE.md)

**For development issues:**
- Service architecture → [Dictionary System](DICTIONARY_SYSTEM.md)
- Build problems → [Main README](../README.md)
- Language pack generation → [Tools README](../tools/README.md)

---

*Last updated: October 2025 - Vuizur Dictionary System v2.1*
*Total dictionary entries: 2,172,196 for Spanish-English*
*Documentation: Consolidated and verified for accuracy*