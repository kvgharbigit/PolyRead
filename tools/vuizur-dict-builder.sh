#!/bin/bash
set -e

PAIR="$1"
if [ -z "$PAIR" ]; then
    echo "Usage: $0 <language-pair>"
    echo "Example: $0 es-en"
    exit 1
fi

WORK_DIR="vuizur-$PAIR"
OUTPUT_DIR="dist"

echo "🔧 Building Vuizur dictionary for: $PAIR"

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

echo "📊 Checking TSV format..."
head -3 "dict.tsv"

echo "🔄 Converting TSV to SQLite..."
python3 -c "
import sqlite3
import csv
import sys

# Create database
conn = sqlite3.connect('$PAIR.db')
cursor = conn.cursor()

# Create dictionary_entries table (PolyRead compatible schema)
cursor.execute('''
CREATE TABLE dictionary_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    lemma TEXT NOT NULL,                    -- Simple headword
    definition TEXT NOT NULL,              -- HTML-formatted definition  
    direction TEXT NOT NULL CHECK (direction IN ('forward', 'reverse')),
    source_language TEXT NOT NULL,        -- ISO language codes
    target_language TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
''')

# Create metadata table
cursor.execute('''
CREATE TABLE pack_metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
)
''')

# Determine languages from pair
if '$PAIR' == 'es-en':
    source_lang, target_lang = 'es', 'en'
elif '$PAIR' == 'en-es':
    source_lang, target_lang = 'en', 'es'
elif '$PAIR' == 'fr-en':
    source_lang, target_lang = 'fr', 'en'
elif '$PAIR' == 'de-en':
    source_lang, target_lang = 'de', 'en'
else:
    source_lang, target_lang = '$PAIR'.split('-')

# Insert metadata
cursor.execute('INSERT INTO pack_metadata VALUES (?, ?)', ('language_pair', '$PAIR'))
cursor.execute('INSERT INTO pack_metadata VALUES (?, ?)', ('source_language', source_lang))
cursor.execute('INSERT INTO pack_metadata VALUES (?, ?)', ('target_language', target_lang))
cursor.execute('INSERT INTO pack_metadata VALUES (?, ?)', ('format_version', '2.0'))
cursor.execute('INSERT INTO pack_metadata VALUES (?, ?)', ('source', 'Vuizur Wiktionary'))

# Read TSV and import
count = 0
with open('dict.tsv', 'r', encoding='utf-8') as f:
    reader = csv.reader(f, delimiter='\t')
    for row in reader:
        if len(row) >= 2 and row[0].strip() and row[1].strip():
            headwords = row[0].strip()
            definition = row[1].strip()
            
            # Split multiple headwords and create separate entries
            for headword in headwords.split('|'):
                headword = headword.strip()
                if headword:
                    cursor.execute('''
                        INSERT INTO dictionary_entries 
                        (lemma, definition, direction, source_language, target_language) 
                        VALUES (?, ?, ?, ?, ?)
                    ''', (headword, definition, 'forward', source_lang, target_lang))
                    count += 1
            
            if count % 10000 == 0:
                print(f'Processed {count} entries...')

conn.commit()
conn.close()
print(f'✅ Imported {count} entries')
"

if [ ! -f "$PAIR.db" ]; then
    echo "❌ No database file created"
    exit 1
fi

echo "📈 Checking results..."
WORD_COUNT=$(sqlite3 "$PAIR.db" "SELECT COUNT(*) FROM dictionary_entries;")
echo "Dictionary contains: $WORD_COUNT entries"

echo "📊 Checking schema..."
sqlite3 "$PAIR.db" ".tables"

echo "📋 Checking metadata..."
sqlite3 "$PAIR.db" "SELECT key, value FROM pack_metadata;"

if [ "$WORD_COUNT" -lt 1000 ]; then
    echo "⚠️  Warning: Low word count, checking sample entries..."
    sqlite3 "$PAIR.db" "SELECT lemma, substr(definition, 1, 80) FROM dictionary_entries LIMIT 5;"
fi

echo "🧪 Testing common words..."
COMMON_FOUND=$(sqlite3 "$PAIR.db" "SELECT COUNT(*) FROM dictionary_entries WHERE lemma IN ('casa', 'agua', 'hacer', 'tener', 'ser', 'hola', 'tiempo', 'año', 'día', 'vez');")
echo "Found $COMMON_FOUND common Spanish words out of 10 tested"

echo "🔍 Sample lookup test..."
sqlite3 "$PAIR.db" "SELECT lemma, substr(definition, 1, 60) as definition, direction, source_language, target_language FROM dictionary_entries WHERE lemma = 'agua' LIMIT 1;"

echo "📦 Packaging..."
zip "../$OUTPUT_DIR/${PAIR}.sqlite.zip" "$PAIR.db"

echo "✅ Success!"
echo "📁 Package: $OUTPUT_DIR/${PAIR}.sqlite.zip"
echo "📊 Entries: $WORD_COUNT"
echo "🔍 Common words: $COMMON_FOUND/10"