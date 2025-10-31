#!/bin/bash

# Vuizur Meaning-Based Dictionary Builder
# Creates proper meaning + synonym cycling structure for PolyRead

set -e

PAIR="$1"
if [ -z "$PAIR" ]; then
    echo "Usage: $0 <language-pair>"
    echo "Example: $0 es-en"
    exit 1
fi

WORK_DIR="vuizur-$PAIR"
OUTPUT_DIR="dist"
OUTPUT_DB="../$OUTPUT_DIR/$PAIR.sqlite"

echo "🔧 Building Meaning-Based Vuizur dictionary for: $PAIR"

# Clean start
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$OUTPUT_DIR"
cd "$WORK_DIR"

# Map language pair to Vuizur format
case "$PAIR" in
    "es-en"|"spa-en")
        DICT_NAME="Spanish-English"
        ;;
    "en-es"|"en-spa")
        DICT_NAME="English-Spanish"
        ;;
    "fr-en")
        DICT_NAME="French-English"
        ;;
    "de-en")
        DICT_NAME="German-English"
        ;;
    *)
        echo "❌ Unsupported language pair: $PAIR"
        echo "Supported: es-en, fr-en, de-en"
        exit 1
        ;;
esac

echo "📥 Downloading $DICT_NAME dictionary (TSV format)..."
TSV_URL="https://github.com/Vuizur/Wiktionary-Dictionaries/raw/master/${DICT_NAME}%20Wiktionary%20dictionary.tsv"
curl -L "$TSV_URL" -o "dict.tsv"

if [ ! -f "dict.tsv" ] || [ ! -s "dict.tsv" ]; then
    echo "❌ Failed to download TSV file"
    exit 1
fi

echo "📊 Downloaded $(wc -l < dict.tsv) dictionary entries"

echo "🗃️ Creating meaning-based database structure..."

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
    target_language TEXT NOT NULL,     -- "en"
    created_at INTEGER DEFAULT (strftime('%s', 'now') * 1000)  -- Unix timestamp in milliseconds
);

-- Simple one-level meaning cycling for source→target language
CREATE TABLE meanings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    word_group_id INTEGER NOT NULL REFERENCES word_groups(id),
    meaning_order INTEGER NOT NULL,    -- 1, 2, 3, 4... for cycling through meanings
    target_meaning TEXT NOT NULL,      -- "water", "body of water", "rain", "faire", "machen"
    context TEXT,                      -- "(archaic)", "(slang)", "(Guatemala)", "(transitive)"
    part_of_speech TEXT,               -- "noun", "verb", "adj" - preserved from original data
    is_primary BOOLEAN DEFAULT FALSE,  -- Mark first meaning as primary
    created_at INTEGER DEFAULT (strftime('%s', 'now') * 1000)  -- Unix timestamp in milliseconds
);

-- Simple reverse lookup for target→source (one-level cycling)
CREATE TABLE target_reverse_lookup (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    target_word TEXT NOT NULL,         -- "water", "house", "time", "do" (target language)
    source_word_group_id INTEGER NOT NULL REFERENCES word_groups(id),
    source_meaning_id INTEGER NOT NULL REFERENCES meanings(id),
    lookup_order INTEGER NOT NULL,     -- 1, 2, 3... for cycling through source words
    quality_score INTEGER DEFAULT 100, -- For ranking (higher = better)
    created_at INTEGER DEFAULT (strftime('%s', 'now') * 1000)  -- Unix timestamp in milliseconds
);

-- Indexes for performance
CREATE INDEX idx_word_groups_base ON word_groups(base_word);
CREATE INDEX idx_word_groups_forms ON word_groups(word_forms);
CREATE INDEX idx_word_groups_lang_pair ON word_groups(source_language, target_language);
CREATE INDEX idx_meanings_word_group ON meanings(word_group_id);
CREATE INDEX idx_meanings_order ON meanings(meaning_order);
CREATE INDEX idx_meanings_primary ON meanings(is_primary);
CREATE INDEX idx_meanings_pos ON meanings(part_of_speech);
CREATE INDEX idx_reverse_lookup_target ON target_reverse_lookup(target_word);
CREATE INDEX idx_reverse_lookup_order ON target_reverse_lookup(lookup_order);
CREATE INDEX idx_reverse_lookup_quality ON target_reverse_lookup(quality_score DESC);
CREATE INDEX idx_reverse_lookup_lang_pair ON target_reverse_lookup(target_word, source_word_group_id);
EOF

echo "✅ Database schema created"

echo "🔄 Processing Vuizur data with meaning extraction..."

# Python script to parse Vuizur data properly
python3 << 'PYTHON_EOF'
import sqlite3
import re
import sys

def clean_meaning(meaning):
    """Extract clean core meaning without context brackets"""
    # Remove HTML tags
    clean = re.sub(r'<[^>]*>', '', meaning)
    # Remove parenthetical context (will be extracted separately)
    clean = re.sub(r'\s*\([^)]*\)', '', clean)
    # Remove extra whitespace and clean up punctuation
    clean = re.sub(r'\s+', ' ', clean).strip()
    # Clean up any trailing commas or periods left after removing context
    clean = re.sub(r'[,\s]+$', '', clean)
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

def extract_english_meanings_from_definitions(definitions_list):
    """Extract and group English meanings from Spanish word definitions"""
    english_meanings = {}  # {base_english_word: [(full_meaning, context, spanish_word, is_primary)]}
    
    for spanish_word, html_def, pos in definitions_list:
        meanings = extract_meanings(html_def)
        
        for meaning, context, is_primary in meanings:
            # Extract base English word (first word before parentheses or commas)
            base_english = meaning.split('(')[0].split(',')[0].strip().lower()
            
            # Skip very short or non-alphabetic base words
            if len(base_english) < 2 or not base_english.replace(' ', '').isalpha():
                continue
            
            if base_english not in english_meanings:
                english_meanings[base_english] = []
            
            # Add this meaning with its Spanish word
            english_meanings[base_english].append((meaning, context, spanish_word, is_primary))
    
    return english_meanings

def group_by_semantic_meaning(english_word, meaning_entries):
    """Group English meanings by semantic similarity (for English→Spanish)"""
    # Group meanings that are semantically similar
    semantic_groups = []
    
    for meaning, context, spanish_word, is_primary in meaning_entries:
        # Look for semantic indicators in the meaning text
        meaning_lower = meaning.lower()
        
        # Find existing group or create new one
        assigned = False
        for group in semantic_groups:
            group_sample = group[0][0].lower()  # First meaning in group
            
            # Check if meanings are semantically similar
            if (
                # Same basic meaning with different contexts
                meaning_lower.split('(')[0].strip() == group_sample.split('(')[0].strip() or
                # Both have similar context indicators  
                extract_semantic_category(meaning) == extract_semantic_category(group[0][0])
            ):
                group.append((meaning, context, spanish_word, is_primary))
                assigned = True
                break
        
        if not assigned:
            semantic_groups.append([(meaning, context, spanish_word, is_primary)])
    
    return semantic_groups

def group_spanish_meanings_semantically(spanish_word, meanings_list):
    """Group Spanish word's English meanings - only group TRUE synonyms, not different meanings"""
    semantic_groups = []
    
    for meaning, context, is_primary in meanings_list:
        # Extract the core meaning without parenthetical context
        core_meaning = meaning.split('(')[0].strip().lower()
        
        # Only group if the core meaning is essentially identical
        assigned = False
        for group in semantic_groups:
            group_core = group[0][0].split('(')[0].strip().lower()
            
            # Only group if they're essentially the same meaning with different contexts
            if (
                core_meaning == group_core or
                # Allow very similar meanings (like "friend" and "buddy")
                (core_meaning in ['friend', 'buddy', 'pal', 'mate', 'bro'] and 
                 group_core in ['friend', 'buddy', 'pal', 'mate', 'bro']) or
                # Allow water-related true synonyms
                (core_meaning in ['water', 'h2o'] and group_core in ['water', 'h2o']) or
                # Allow house-related true synonyms  
                (core_meaning in ['house', 'home', 'dwelling'] and group_core in ['house', 'home', 'dwelling'])
            ):
                group.append((meaning, context, is_primary))
                assigned = True
                break
        
        if not assigned:
            # Each distinct meaning gets its own group
            semantic_groups.append([(meaning, context, is_primary)])
    
    return semantic_groups

def extract_semantic_category(meaning):
    """Extract semantic category from meaning text with much more precise categorization"""
    meaning_lower = meaning.lower()
    
    # Extract context clues
    context_markers = re.findall(r'\([^)]*\)', meaning_lower)
    context_text = ' '.join(context_markers)
    
    # Body parts and anatomy
    if any(word in meaning_lower for word in ['anatomy', 'body', 'limb', 'organ']) or any(word in context_text for word in ['anatomy', 'body part']):
        return f'anatomy_{meaning_lower.split("(")[0].split(",")[0].strip()}'
    
    # Animal anatomy (separate from human)
    if any(word in context_text for word in ['animal', 'of an animal', 'of animals']):
        return f'animal_anatomy_{meaning_lower.split("(")[0].split(",")[0].strip()}'
    
    # Games and sports
    if any(word in meaning_lower for word in ['game', 'round', 'turn', 'play']) or any(word in context_text for word in ['game', 'games', 'sport']):
        return f'games_{meaning_lower.split("(")[0].split(",")[0].strip()}'
    
    # Tools and objects
    if any(word in meaning_lower for word in ['tool', 'instrument', 'device', 'stone', 'grind', 'metate']):
        return f'tool_{meaning_lower.split("(")[0].split(",")[0].strip()}'
    
    # Clock/time instruments
    if any(word in meaning_lower for word in ['clock', 'watch', 'timepiece']) or any(word in context_text for word in ['clock', 'watch']):
        return f'timepiece_{meaning_lower.split("(")[0].split(",")[0].strip()}'
    
    # Paint/coating
    if any(word in meaning_lower for word in ['paint', 'coat', 'layer', 'lick', 'coating']) or any(word in context_text for word in ['paint', 'painting']):
        return f'coating_{meaning_lower.split("(")[0].split(",")[0].strip()}'
    
    # Social/informal terms
    if any(word in meaning_lower for word in ['buddy', 'friend', 'pal', 'mate', 'bro', 'man']) or any(word in context_text for word in ['slang', 'colloquial', 'informal']):
        return f'social_{meaning_lower.split("(")[0].split(",")[0].strip()}'
    
    # Weather
    if any(word in meaning_lower for word in ['weather', 'climate', 'meteorological', 'rain', 'storm']):
        return f'weather_{meaning_lower.split("(")[0].split(",")[0].strip()}'
    
    # Geography/water bodies
    if any(word in meaning_lower for word in ['body of water', 'river', 'lake', 'ocean', 'stream']):
        return f'geography_{meaning_lower.split("(")[0].split(",")[0].strip()}'
    
    # Liquids/beverages  
    if any(word in meaning_lower for word in ['liquid', 'drink', 'beverage', 'pop', 'soda']):
        return f'liquid_{meaning_lower.split("(")[0].split(",")[0].strip()}'
    
    # Time concepts
    if any(word in meaning_lower for word in ['time', 'schedule', 'timetable', 'appointment']):
        return f'time_{meaning_lower.split("(")[0].split(",")[0].strip()}'
    
    # Duration 
    if any(word in meaning_lower for word in ['period', 'duration', 'while', 'moment']):
        return f'duration_{meaning_lower.split("(")[0].split(",")[0].strip()}'
    
    # Grammar
    if any(word in meaning_lower for word in ['tense', 'grammar', 'verbal']):
        return f'grammar_{meaning_lower.split("(")[0].split(",")[0].strip()}'
    
    # Skills/abilities
    if any(word in meaning_lower for word in ['skill', 'talent', 'ability', 'expertise']):
        return f'skill_{meaning_lower.split("(")[0].split(",")[0].strip()}'
    
    # Buildings/structures
    if any(word in meaning_lower for word in ['building', 'structure', 'dwelling', 'house']):
        return f'building_{meaning_lower.split("(")[0].split(",")[0].strip()}'
    
    # Default: use the exact base meaning as unique category
    base_meaning = meaning_lower.split('(')[0].split(',')[0].strip()
    return f'unique_{base_meaning}'

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
    if len(meaning) <= 10 and meaning.replace(' ', '').isalpha():
        score += 10
    
    return max(score, 10)  # Minimum score of 10

def calculate_meaning_priority(meaning, context, is_primary):
    """Calculate priority for meaning ordering (lower = more important)"""
    priority = 100
    
    # Simple, common meanings first
    if len(meaning) <= 15 and not context:
        priority -= 50
    
    # Primary meanings get higher priority
    if is_primary:
        priority -= 30
    
    # Penalize specialized contexts
    if context:
        if any(marker in context.lower() for marker in ['archaic', 'obsolete', 'rare']):
            priority += 40
        if any(marker in context.lower() for marker in ['slang', 'colloquial', 'informal']):
            priority += 20
        if any(marker in context.lower() for marker in ['technical', 'formal', 'literary']):
            priority += 15
        if any(region in context.lower() for region in ['guatemala', 'mexico', 'peru', 'chile', 'colombia']):
            priority += 10
    
    # Penalize very long definitions (complex/technical)
    if len(meaning) > 60:
        priority += 25
    
    # Bonus for very simple definitions
    if len(meaning) <= 10 and meaning.replace(' ', '').isalpha():
        priority -= 20
    
    return priority

# Determine source and target languages from pair
import os
db_path = os.path.abspath('../dist/es-en.sqlite')
pair = os.path.basename(db_path).replace('.sqlite', '')

if pair.startswith('es-'):
    source_lang, target_lang = 'es', 'en'
elif pair.startswith('fr-'):
    source_lang, target_lang = 'fr', 'en'
elif pair.startswith('de-'):
    source_lang, target_lang = 'de', 'en'
else:
    source_lang, target_lang = 'es', 'en'  # default

print(f"📊 Processing {source_lang}→{target_lang} dictionary...")

# Connect to database
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# First pass: Collect all source words with their target meanings
source_data = []
with open('dict.tsv', 'r', encoding='utf-8') as f:
    for line_num, line in enumerate(f, 1):
        if line_num % 10000 == 0:
            print(f"  Collecting data: {line_num} entries...")
        
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
        
        # Extract part of speech first
        pos = get_part_of_speech(html_def)
        
        # Skip proper nouns and compound proper names
        if pos == 'name':
            continue
        
        # Skip capitalized compound words (likely proper nouns)
        if len(base_word.split()) > 1 and base_word[0].isupper():
            continue
        
        # Skip words that are all caps (acronyms)
        if base_word.isupper() and len(base_word) > 2:
            continue
        
        source_data.append((base_word, word_forms, pos, html_def))

print(f"✅ Collected {len(source_data)} {source_lang} entries")

# Second pass: Process source words and extract meanings with part-of-speech  
print(f"🔄 Processing {source_lang} words with one-level meaning cycling...")
source_word_mapping = {}  # {base_word: (word_group_id, [meaning_ids])}
target_meanings_collected = {}  # {target_word: [(source_word, meaning_id, quality)]}

processed = 0
for base_word, word_forms, pos, html_def in source_data:
    if processed % 5000 == 0 and processed > 0:
        print(f"  Processed {processed} {source_lang} entries...")
    
    # Insert word group
    cursor.execute("""
        INSERT INTO word_groups (base_word, word_forms, part_of_speech, source_language, target_language)
        VALUES (?, ?, ?, ?, ?)
    """, (base_word, word_forms, pos, source_lang, target_lang))
    
    word_group_id = cursor.lastrowid
    
    # Parse HTML to extract meanings with part of speech
    meaning_ids = []
    meaning_order = 1
    
    # Split by <i>part_of_speech</i><br><ol> sections
    sections = re.split(r'<i>([^<]+)</i><br><ol>', html_def)
    
    for i in range(1, len(sections), 2):
        if i + 1 >= len(sections):
            break
            
        current_pos = sections[i]  # part of speech
        meanings_html = sections[i + 1]  # meanings list
        
        # Extract individual meanings from <li> tags
        meaning_matches = re.findall(r'<li>([^<]+?)(?:</li>|<)', meanings_html)
        
        for meaning_text in meaning_matches:
            cleaned_meaning = clean_meaning(meaning_text)
            if not cleaned_meaning or len(cleaned_meaning) < 2:
                continue
            
            context = extract_context(meaning_text)
            is_primary = (meaning_order == 1)
            
            # Insert meaning with part of speech
            cursor.execute("""
                INSERT INTO meanings 
                (word_group_id, meaning_order, target_meaning, context, part_of_speech, is_primary)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (word_group_id, meaning_order, cleaned_meaning, context, current_pos, is_primary))
            
            meaning_id = cursor.lastrowid
            meaning_ids.append(meaning_id)
            
            # Collect for target language reverse lookup
            base_target = cleaned_meaning.split('(')[0].split(',')[0].strip().lower()
            if len(base_target) >= 2 and base_target.replace(' ', '').isalpha():
                if base_target not in target_meanings_collected:
                    target_meanings_collected[base_target] = []
                
                quality = calculate_quality_score(cleaned_meaning, context, is_primary)
                target_meanings_collected[base_target].append((base_word, meaning_id, quality))
            
            meaning_order += 1
    
    source_word_mapping[base_word] = (word_group_id, meaning_ids)
    processed += 1

print(f"✅ Inserted {processed} {source_lang} word groups with one-level meaning cycling")

# Third pass: Create target language reverse lookup for cycling
print(f"🔄 Creating {target_lang}→{source_lang} reverse lookup...")
for target_word, source_mappings in target_meanings_collected.items():
    # Sort by quality score (higher = better)
    source_mappings.sort(key=lambda x: x[2], reverse=True)
    
    for lookup_order, (source_word, meaning_id, quality) in enumerate(source_mappings, 1):
        if source_word in source_word_mapping:
            word_group_id = source_word_mapping[source_word][0]
            
            cursor.execute("""
                INSERT INTO target_reverse_lookup 
                (target_word, source_word_group_id, source_meaning_id, lookup_order, quality_score)
                VALUES (?, ?, ?, ?, ?)
            """, (target_word, word_group_id, meaning_id, lookup_order, quality))

print(f"✅ Created {target_lang}→{source_lang} reverse lookup for {len(target_meanings_collected)} {target_lang} words")

# Commit changes
conn.commit()

# Get statistics
total_word_groups = cursor.execute("SELECT COUNT(*) FROM word_groups").fetchone()[0]
total_meanings = cursor.execute("SELECT COUNT(*) FROM meanings").fetchone()[0]
total_reverse_lookups = cursor.execute("SELECT COUNT(*) FROM target_reverse_lookup").fetchone()[0]
total_target_words = cursor.execute("SELECT COUNT(DISTINCT target_word) FROM target_reverse_lookup").fetchone()[0]

print(f"\n✅ One-Level Cycling Processing completed!")
print(f"   {source_lang} word groups: {total_word_groups:,}")
print(f"   {source_lang}→{target_lang} meanings: {total_meanings:,}")
print(f"   {target_lang} words: {total_target_words:,}")
print(f"   {target_lang}→{source_lang} lookups: {total_reverse_lookups:,}")

conn.close()
PYTHON_EOF

echo ""
echo "📦 Creating compressed package..."

# Create ZIP package
cd ..
zip -9 "$OUTPUT_DIR/$PAIR.sqlite.zip" "$OUTPUT_DIR/$PAIR.sqlite"

# Get file sizes
UNCOMPRESSED_SIZE=$(stat -f%z "$OUTPUT_DIR/$PAIR.sqlite" 2>/dev/null || stat -c%s "$OUTPUT_DIR/$PAIR.sqlite")
COMPRESSED_SIZE=$(stat -f%z "$OUTPUT_DIR/$PAIR.sqlite.zip" 2>/dev/null || stat -c%s "$OUTPUT_DIR/$PAIR.sqlite.zip")

echo ""
echo "✅ Meaning-Based Dictionary Package Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📄 Database: dist/$PAIR.sqlite"
echo "📦 Package: dist/$PAIR.sqlite.zip"
echo "💾 Uncompressed: $(echo "scale=1; $UNCOMPRESSED_SIZE/1024/1024" | bc)MB"
echo "🗜️ Compressed: $(echo "scale=1; $COMPRESSED_SIZE/1024/1024" | bc)MB"
echo ""
echo "🔄 Features:"
echo "   • One-Level Meaning Cycling (both directions)"
echo "   • Source → Target: Cycle through meanings with part-of-speech"
echo "   • Target → Source: Cycle through different source words"
echo "   • No proper nouns or conjugation pollution"
echo "   • Quality-ranked translations"
echo "   • Part-of-speech preserved for UI formatting"

# Cleanup
rm -rf "$WORK_DIR"