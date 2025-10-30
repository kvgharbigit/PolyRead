#!/bin/bash

# Analyze how to restructure for discrete meanings + synonym cycling

DB_FILE="/Users/kayvangharbi/PycharmProjects/PolyRead/tools/vuizur-es-en/dict.tsv"

echo "🔍 ANALYZING VUIZUR STRUCTURE FOR BETTER EXTRACTION"
echo "=================================================="

echo ""
echo "1. Current Vuizur Format Analysis:"
echo "--------------------------------"

# Show how Vuizur groups word forms
echo "Example 1 - Word form grouping:"
grep "^agua|" "$DB_FILE" | head -1
echo ""

echo "Example 2 - Meaning separation within HTML:"
grep "^agua|" "$DB_FILE" | head -1 | sed 's/|/\n  Forms: /' | tail -1 | sed 's/<li>/\n    Meaning: /g' | head -5

echo ""
echo "2. Proposed Better Database Schema:"
echo "--------------------------------"
cat << 'EOF'
CREATE TABLE word_groups (
    id INTEGER PRIMARY KEY,
    base_word TEXT NOT NULL,           -- "agua" (canonical form)
    word_forms TEXT NOT NULL,          -- "agua|agüita|aguas|agüitas" (pipe-separated)
    part_of_speech TEXT,               -- "noun", "verb", "adj"
    source_language TEXT NOT NULL,     -- "es"
    target_language TEXT NOT NULL      -- "en"
);

CREATE TABLE meanings (
    id INTEGER PRIMARY KEY,
    word_group_id INTEGER REFERENCES word_groups(id),
    meaning_order INTEGER NOT NULL,    -- 1, 2, 3, 4...
    english_meaning TEXT NOT NULL,     -- "water", "body of water", "rain"
    context TEXT,                      -- "(archaic)", "(slang)", "(Guatemala)"
    is_primary BOOLEAN DEFAULT FALSE   -- Mark primary meaning
);

CREATE TABLE english_synonyms (
    id INTEGER PRIMARY KEY,
    english_word TEXT NOT NULL,        -- "house"
    spanish_word_group_id INTEGER REFERENCES word_groups(id),
    meaning_id INTEGER REFERENCES meanings(id),
    quality_score INTEGER DEFAULT 100  -- For ranking
);
EOF

echo ""
echo "3. How This Solves Cycling Problems:"
echo "--------------------------------"
echo "✅ MEANING CYCLING: User taps 'agua'"
echo "   Cycle 1: agua → 'water' (meaning 1)"
echo "   Cycle 2: agua → 'body of water' (meaning 2)" 
echo "   Cycle 3: agua → 'rain' (meaning 3)"
echo ""
echo "✅ SYNONYM CYCLING: User taps 'house' in English"
echo "   Cycle 1: house → 'casa' (word group 1, meaning 1)"
echo "   Cycle 2: house → 'hogar' (word group 2, meaning 1)"
echo "   Cycle 3: house → 'vivienda' (word group 3, meaning 1)"
echo ""

echo "4. Sample Extraction Logic:"
echo "-------------------------"
cat << 'EOF'
For line: "agua|agüita|aguas|agüitas<tab><i>noun</i><br><ol><li>water</li><li>body of water</li><li>rain</li>..."

Extract as:
word_groups: 
  - base_word: "agua"
  - word_forms: "agua|agüita|aguas|agüitas"
  - part_of_speech: "noun"

meanings:
  - meaning_order: 1, english_meaning: "water", is_primary: true
  - meaning_order: 2, english_meaning: "body of water"
  - meaning_order: 3, english_meaning: "rain"

english_synonyms:
  - english_word: "water" → spanish_word_group_id: agua_group_id, meaning_id: meaning_1_id
EOF

echo ""
echo "5. Testing Current Data for Better Extraction:"
echo "--------------------------------------------"

echo "Finding Spanish words that translate to 'house':"
grep -i 'house' "$DB_FILE" | grep -v "house" | head -3

echo ""
echo "Finding different word groups for 'water':"
grep -E '\bwater\b' "$DB_FILE" | cut -f1 | head -5

echo ""
echo "✅ CONCLUSION: Vuizur data structure supports:"
echo "- Grouped word forms (eliminates conjugation cycling)"  
echo "- Separated meanings (enables meaning cycling)"
echo "- Multiple Spanish words per English word (enables synonym cycling)"
echo ""
echo "💡 RECOMMENDATION: Rebuild database with meaning-based structure"