# PolyRead Cycling Dictionary Builder

Creates PolyRead-compatible cycling dictionary packages from Vuizur Wiktionary-Dictionaries with revolutionary one-level meaning cycling support.

## ✅ Quick Usage

### Generate Cycling Dictionary Packs

```bash
# Spanish-English cycling dictionary
./vuizur-meaning-dict-builder.sh es-en

# French-English cycling dictionary  
./vuizur-meaning-dict-builder.sh fr-en

# German-English cycling dictionary
./vuizur-meaning-dict-builder.sh de-en
```

### Output

Each command generates:
- **Database**: SQLite file with cycling dictionary schema v6
- **Package**: Compressed `.sqlite.zip` file ready for PolyRead
- **Location**: `dist/<language-pair>.sqlite.zip`

## 🏗️ **Architecture: Cycling Dictionary System v2.1**

### **Revolutionary Cycling Approach**
- **Source→Target**: Tap to cycle through meanings (94K+ word groups)
- **Target→Source**: Quality-ranked reverse lookup (66K+ target words)
- **One-Level Cycling**: No complex hierarchies, simple tap-to-cycle
- **UI Innovation**: Tap-to-cycle + long-press-to-expand interaction

### **Why Cycling Design?**
1. **Eliminates conjugation pollution** (discrete meaning-based cycling)
2. **Preserves semantic context** with part-of-speech tags
3. **Quality-ranked cycling order** for optimal translation discovery
4. **Generalized schema** supports any language pair

## 📊 Cycling Dictionary Results

### Spanish-English (es-en) - Cycling Dictionary v2.1
- **Word Groups**: 94,334 (canonical forms)
- **Meanings**: 126,914 (cycling meanings)
- **Target Words**: 66,768 (reverse lookup)
- **Size**: Optimized with cycling schema
- **Status**: ✅ **Production ready with cycling UI**
- **Features**: Tap-to-cycle + long-press-to-expand

### Ready for Cycling Generation
- **French-English** (fr-en): Ready for cycling dictionary generation
- **German-English** (de-en): Ready for cycling dictionary generation  
- **Portuguese-English** (pt-en): Ready for cycling dictionary generation

## 🔧 Requirements

- **Bash shell** (macOS/Linux)
- **curl** for downloading source data
- **sqlite3** for database operations
- **Python 3** for data processing
- **GitHub CLI** (optional, for deployment)

## 📦 Data Source

**Vuizur Wiktionary-Dictionaries**: https://github.com/Vuizur/Wiktionary-Dictionaries
- High-quality bilingual dictionaries from Wiktionary
- TSV format with comprehensive word forms and definitions
- Regular updates and community maintenance
- Creative Commons licensed

## 🔍 **Cycling Translation Flow**

### **Spanish→English (Meaning Cycling)**
```sql
-- Cycle through meanings: <1ms
SELECT m.target_meaning, m.context, m.part_of_speech
FROM word_groups wg
JOIN meanings m ON wg.id = m.word_group_id
WHERE wg.base_word = 'casa' OR wg.word_forms LIKE '%casa%'
ORDER BY m.meaning_order
-- Result: Cycle through: house → dwelling → home
```

### **English→Spanish (Reverse Cycling)**
```sql
-- Quality-ranked reverse cycling: <1ms
SELECT wg.base_word, m.target_meaning
FROM target_reverse_lookup trl
JOIN word_groups wg ON trl.source_word_group_id = wg.id
JOIN meanings m ON trl.source_meaning_id = m.id
WHERE trl.target_word = 'house'
ORDER BY trl.lookup_order
-- Result: Cycle through: casa → hogar → vivienda
```

## 🏗️ Technical Details

### **Cycling Dictionary Schema v6**
```sql
CREATE TABLE word_groups (
    base_word TEXT NOT NULL,           -- "agua" (canonical form)
    word_forms TEXT NOT NULL,          -- "agua|agüita|aguas|agüitas"
    part_of_speech TEXT,               -- "noun", "verb", "adj"
    source_language TEXT NOT NULL,     -- "es"
    target_language TEXT NOT NULL      -- "en"
);

CREATE TABLE meanings (
    word_group_id INTEGER NOT NULL,
    meaning_order INTEGER NOT NULL,    -- 1, 2, 3, 4... for cycling
    target_meaning TEXT NOT NULL,      -- "water", "body of water", "rain"
    context TEXT,                      -- "(archaic)", "(slang)", "(Guatemala)"
    part_of_speech TEXT,               -- "noun", "verb", "adj"
    is_primary BOOLEAN DEFAULT FALSE   -- Mark primary meaning
);

CREATE TABLE target_reverse_lookup (
    target_word TEXT NOT NULL,         -- "water", "house", "time"
    source_word_group_id INTEGER,      -- Reference to word group
    source_meaning_id INTEGER,         -- Reference to specific meaning
    lookup_order INTEGER NOT NULL,     -- 1, 2, 3... for cycling
    quality_score INTEGER DEFAULT 100  -- Higher = better translation
);
```

### **Cycling Performance Optimization**
```sql
-- Indexes for sub-millisecond cycling
CREATE INDEX idx_word_groups_base ON word_groups(base_word);
CREATE INDEX idx_word_groups_forms ON word_groups(word_forms);
CREATE INDEX idx_meanings_word_group ON meanings(word_group_id);
CREATE INDEX idx_meanings_order ON meanings(meaning_order);
CREATE INDEX idx_reverse_lookup_target ON target_reverse_lookup(target_word);
CREATE INDEX idx_reverse_lookup_order ON target_reverse_lookup(lookup_order);
```

### **Cycling Performance Features**
- **6 optimized indexes** for sub-millisecond cycling operations
- **Quality-ranked cycling** with priority-based ordering
- **One-level structure** eliminates complex hierarchical navigation
- **Sub-millisecond** meaning cycling in both directions
- **Tap-to-cycle UI** with instant visual feedback

## 🚀 Deployment

```bash
# After cycling dictionary generation, deploy to GitHub releases
gh release upload cycling-dictionaries-v2.1 dist/es-en.sqlite.zip

# The cycling dictionary is automatically detected by PolyRead
# No registry updates needed - schema v6 enables auto-detection
```

## ⚡ Cycling System Benefits

- **Revolutionary UI**: Tap-to-cycle + long-press-to-expand interaction
- **Quality-filtered data**: No proper nouns or conjugation pollution
- **Generalized schema**: Support for any language pair
- **One-level cycling**: Simple, intuitive meaning discovery
- **Production scale**: 94K+ word groups, 126K+ meanings ready
- **Future-ready**: Extensible cycling architecture

---

*For detailed technical documentation, troubleshooting, and architecture details, see [Dictionary System Documentation](../docs/DICTIONARY_SYSTEM.md)*