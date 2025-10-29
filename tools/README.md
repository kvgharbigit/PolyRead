# PolyRead Vuizur Dictionary Builder

Simple, reliable tool for creating PolyRead-compatible language pack databases from Vuizur Wiktionary-Dictionaries.

## ✅ Quick Usage

### Generate Language Packs

```bash
# Spanish-English dictionary
./vuizur-dict-builder.sh es-en

# French-English dictionary  
./vuizur-dict-builder.sh fr-en

# German-English dictionary
./vuizur-dict-builder.sh de-en
```

### Output

Each command generates:
- **Database**: SQLite file with dictionary entries and FTS5 search
- **Package**: Compressed `.sqlite.zip` file ready for PolyRead
- **Location**: `dist/<language-pair>.sqlite.zip`

## 📊 Current Results

### Spanish-English (es-en)
- **Entries**: 2,172,196 dictionary entries
- **Size**: 80.5MB compressed
- **Status**: ✅ **Production ready**
- **Coverage**: Complete vocabulary with common words, idioms, technical terms

### Ready for Generation
- **French-English** (fr-en): ~1M+ entries expected
- **German-English** (de-en): ~1M+ entries expected  
- **Portuguese-English** (pt-en): ~1M+ entries expected

## 🔧 Requirements

- **Bash shell** (macOS/Linux)
- **curl** for downloading source data
- **sqlite3** for database operations
- **GitHub CLI** (optional, for deployment)

## 📦 Data Source

**Vuizur Wiktionary-Dictionaries**: https://github.com/Vuizur/Wiktionary-Dictionaries
- High-quality bilingual dictionaries from Wiktionary
- TSV format with comprehensive word forms and definitions
- Regular updates and community maintenance
- Creative Commons licensed

## 🏗️ Technical Details

For complete database schema, service architecture, and integration details, see:
**[Dictionary System Documentation](../docs/DICTIONARY_SYSTEM.md)**

## 🚀 Deployment

```bash
# After generation, deploy to GitHub releases
gh release upload language-packs-v2.1 dist/es-en.sqlite.zip

# Update registry metadata
# (See Dictionary System docs for registry format)
```

## ⚡ Performance Features

- **5 database indexes** for fast lookups
- **FTS5 full-text search** with BM25 ranking
- **Legacy compatibility** fields for backward compatibility
- **Automatic triggers** for search synchronization
- **Sub-millisecond** exact lookups
- **<100ms** fuzzy search performance

---

*For detailed technical documentation, troubleshooting, and architecture details, see [Dictionary System Documentation](../docs/DICTIONARY_SYSTEM.md)*