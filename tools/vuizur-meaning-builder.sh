#!/bin/bash

# Vuizur Meaning-Based Dictionary Builder
# Extracts discrete meanings for proper cycling support

set -e

SOURCE_TSV="/Users/kayvangharbi/PycharmProjects/PolyRead/tools/vuizur-es-en/dict.tsv"
OUTPUT_DB="/Users/kayvangharbi/PycharmProjects/PolyRead/tools/es-en-meanings.db"

echo "🔧 BUILDING MEANING-BASED DICTIONARY"
echo "===================================="
echo "Source: $SOURCE_TSV"
echo "Output: $OUTPUT_DB"
echo ""

# Remove old database
rm -f "$OUTPUT_DB"

# Create new schema
sqlite3 "$OUTPUT_DB" << 'EOF'
-- Word groups (eliminates conjugation cycling)
CREATE TABLE word_groups (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    base_word TEXT NOT NULL,           -- "agua" (canonical form)
    word_forms TEXT NOT NULL,          -- "agua|agüita|aguas|agüitas"
    part_of_speech TEXT,               -- "noun", "verb", "adj"
    source_language TEXT NOT NULL,     -- "es"
    target_language TEXT NOT NULL      -- "en"
);

-- Discrete meanings (enables meaning cycling)
CREATE TABLE meanings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    word_group_id INTEGER NOT NULL REFERENCES word_groups(id),
    meaning_order INTEGER NOT NULL,    -- 1, 2, 3, 4...
    english_meaning TEXT NOT NULL,     -- "water", "body of water", "rain"
    context TEXT,                      -- "(archaic)", "(slang)", "(Guatemala)"
    is_primary BOOLEAN DEFAULT FALSE   -- Mark primary meaning
);

-- English to Spanish mappings (enables synonym cycling)
CREATE TABLE english_synonyms (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    english_word TEXT NOT NULL,        -- "house"
    word_group_id INTEGER NOT NULL REFERENCES word_groups(id),
    meaning_id INTEGER NOT NULL REFERENCES meanings(id),
    quality_score INTEGER DEFAULT 100  -- For ranking (higher = better)
);

-- Indexes for performance
CREATE INDEX idx_word_groups_base ON word_groups(base_word);
CREATE INDEX idx_word_groups_forms ON word_groups(word_forms);
CREATE INDEX idx_meanings_group ON meanings(word_group_id);
CREATE INDEX idx_meanings_primary ON meanings(is_primary);
CREATE INDEX idx_synonyms_english ON english_synonyms(english_word);
CREATE INDEX idx_synonyms_quality ON english_synonyms(quality_score DESC);
EOF

echo "✅ Database schema created"

# Python script to parse Vuizur data properly
python3 << 'EOF'
import sqlite3
import re
import sys

def clean_meaning(meaning):
    """Extract clean English meaning from HTML"""
    # Remove HTML tags
    clean = re.sub(r'<[^>]*>', '', meaning)
    # Remove extra whitespace
    clean = re.sub(r'\s+', ' ', clean).strip()
    return clean

def extract_context(meaning):
    """Extract context markers like (archaic), (slang), etc."""
    contexts = re.findall(r'\([^)]*\)', meaning)
    return ', '.join(contexts) if contexts else None

def extract_meanings(html_def):
    """Extract individual meanings from HTML definition"""
    # Find all <li>content</li> patterns
    meanings = re.findall(r'<li>([^<]+?)(?:</li>|<)', html_def)
    
    result = []
    for i, meaning in enumerate(meanings):
        clean = clean_meaning(meaning)
        if clean and len(clean) > 0:
            context = extract_context(meaning)
            is_primary = (i == 0)  # First meaning is primary
            result.append((clean, context, is_primary))
    
    return result

def get_part_of_speech(html_def):
    """Extract part of speech from HTML"""
    match = re.search(r'<i>([^<]+)</i>', html_def)
    return match.group(1) if match else None

def calculate_quality_score(meaning, context, is_primary):
    """Calculate quality score for ranking"""
    score = 100
    
    # Primary meanings get bonus
    if is_primary:
        score += 50
    
    # Penalize archaic, slang, specialized terms
    if context:
        if 'archaic' in context.lower():
            score -= 40
        if 'slang' in context.lower():
            score -= 20
        if 'colloquial' in context.lower():
            score -= 10
        if any(region in context.lower() for region in ['guatemala', 'mexico', 'peru', 'chile']):
            score -= 5
    
    # Penalize very long meanings (likely complex/technical)
    if len(meaning) > 50:
        score -= 20
    
    # Bonus for simple, common words
    if len(meaning) <= 10 and meaning.isalpha():
        score += 10
    
    return max(score, 10)  # Minimum score of 10

# Connect to database
conn = sqlite3.connect('/Users/kayvangharbi/PycharmProjects/PolyRead/tools/es-en-meanings.db')
cursor = conn.cursor()

print("📊 Processing Vuizur data...")

# Read and process TSV file
with open('/Users/kayvangharbi/PycharmProjects/PolyRead/tools/vuizur-es-en/dict.tsv', 'r', encoding='utf-8') as f:
    for line_num, line in enumerate(f, 1):
        if line_num % 10000 == 0:
            print(f"  Processed {line_num} entries...")
        
        line = line.strip()
        if not line:
            continue
        
        parts = line.split('\t')
        if len(parts) != 2:
            continue
        
        word_forms, html_def = parts
        
        # Skip if no word forms
        if not word_forms:
            continue
        
        # Get base word (first form)
        forms = word_forms.split('|')
        base_word = forms[0].strip()
        
        # Skip very short or problematic words
        if len(base_word) < 2 or '.' in base_word:
            continue
        
        # Extract part of speech
        pos = get_part_of_speech(html_def)
        
        # Insert word group
        cursor.execute("""
            INSERT INTO word_groups (base_word, word_forms, part_of_speech, source_language, target_language)
            VALUES (?, ?, ?, 'es', 'en')
        """, (base_word, word_forms, pos))
        
        word_group_id = cursor.lastrowid
        
        # Extract meanings
        meanings = extract_meanings(html_def)
        
        if not meanings:
            continue
        
        # Insert meanings
        for order, (meaning, context, is_primary) in enumerate(meanings, 1):
            cursor.execute("""
                INSERT INTO meanings (word_group_id, meaning_order, english_meaning, context, is_primary)
                VALUES (?, ?, ?, ?, ?)
            """, (word_group_id, order, meaning, context, is_primary))
            
            meaning_id = cursor.lastrowid
            
            # Calculate quality score
            quality = calculate_quality_score(meaning, context, is_primary)
            
            # Insert into english_synonyms for reverse lookup
            cursor.execute("""
                INSERT INTO english_synonyms (english_word, word_group_id, meaning_id, quality_score)
                VALUES (?, ?, ?, ?)
            """, (meaning.lower().strip(), word_group_id, meaning_id, quality))

# Commit changes
conn.commit()

# Get statistics
total_groups = cursor.execute("SELECT COUNT(*) FROM word_groups").fetchone()[0]
total_meanings = cursor.execute("SELECT COUNT(*) FROM meanings").fetchone()[0]
total_synonyms = cursor.execute("SELECT COUNT(*) FROM english_synonyms").fetchone()[0]

print(f"\n✅ Database built successfully!")
print(f"   Word groups: {total_groups:,}")
print(f"   Meanings: {total_meanings:,}")
print(f"   English synonyms: {total_synonyms:,}")

conn.close()
EOF

echo ""
echo "🔍 Testing new structure..."

echo ""
echo "Spanish→English meaning cycling test (agua):"
sqlite3 "$OUTPUT_DB" "
SELECT m.meaning_order, m.english_meaning, m.context
FROM word_groups wg
JOIN meanings m ON wg.id = m.word_group_id
WHERE wg.base_word = 'agua'
ORDER BY m.meaning_order
LIMIT 5;
"

echo ""
echo "English→Spanish synonym cycling test (house):"
sqlite3 "$OUTPUT_DB" "
SELECT wg.base_word, m.english_meaning, es.quality_score
FROM english_synonyms es
JOIN word_groups wg ON es.word_group_id = wg.id
JOIN meanings m ON es.meaning_id = m.id
WHERE es.english_word = 'house'
ORDER BY es.quality_score DESC, wg.base_word
LIMIT 5;
"

echo ""
echo "✅ Meaning-based dictionary ready!"
echo "📍 Location: $OUTPUT_DB"