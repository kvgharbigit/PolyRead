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

# Create dictionary_entries table (Drift/Wiktionary compatible schema)
cursor.execute('''
CREATE TABLE dictionary_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    
    -- Core Wiktionary Fields (Primary)
    written_rep TEXT NOT NULL,            -- Headword/lemma (Wiktionary standard)
    lexentry TEXT,                        -- Lexical entry ID (e.g., cold_ADJ_01)
    sense TEXT,                           -- Definition/meaning description
    trans_list TEXT NOT NULL,             -- Pipe-separated translations
    pos TEXT,                             -- Part of speech (noun, verb, etc.)
    domain TEXT,                          -- Semantic domain (optional)
    
    -- Language Pair Information
    source_language TEXT NOT NULL,        -- Source language code (ISO)
    target_language TEXT NOT NULL,        -- Target language code (ISO)
    
    -- Additional Metadata
    pronunciation TEXT,                   -- IPA or phonetic pronunciation
    examples TEXT,                        -- JSON array of example sentences
    frequency INTEGER DEFAULT 0,          -- Usage frequency ranking
    source TEXT,                          -- Dictionary pack source name
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    -- Legacy Compatibility Fields (Maintained for backward compatibility)
    lemma TEXT DEFAULT '',                -- Legacy alias for written_rep
    definition TEXT DEFAULT '',           -- Legacy alias for sense
    part_of_speech TEXT,                  -- Legacy alias for pos
    language_pair TEXT DEFAULT ''         -- Legacy computed field (e.g., en-es)
)
''')

# Create metadata table
cursor.execute('''
CREATE TABLE pack_metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
)
''')

# Create performance indexes (matching app expectations)
cursor.execute('''CREATE INDEX idx_dictionary_written_rep ON dictionary_entries(written_rep)''')
cursor.execute('''CREATE INDEX idx_dictionary_languages ON dictionary_entries(source_language, target_language)''')
cursor.execute('''CREATE INDEX idx_dictionary_lookup ON dictionary_entries(written_rep, source_language, target_language)''')
cursor.execute('''CREATE INDEX idx_dictionary_pos ON dictionary_entries(pos)''')
cursor.execute('''CREATE INDEX idx_dictionary_source_lang ON dictionary_entries(source_language)''')
cursor.execute('''CREATE INDEX idx_dictionary_target_lang ON dictionary_entries(target_language)''')

# Create FTS5 virtual table for fast search (matching app implementation)
cursor.execute('''
CREATE VIRTUAL TABLE dictionary_fts USING fts5(
    written_rep,
    sense,
    trans_list,
    content='dictionary_entries',
    content_rowid='id'
)
''')

# Create FTS triggers for automatic synchronization
cursor.execute('''
CREATE TRIGGER dictionary_entries_ai AFTER INSERT ON dictionary_entries
BEGIN
  INSERT INTO dictionary_fts(written_rep, sense, trans_list)
  VALUES (new.written_rep, COALESCE(new.sense, ''), new.trans_list);
END
''')

cursor.execute('''
CREATE TRIGGER dictionary_entries_ad AFTER DELETE ON dictionary_entries
BEGIN
  INSERT INTO dictionary_fts(dictionary_fts, rowid, written_rep, sense, trans_list)
  VALUES ('delete', old.id, old.written_rep, COALESCE(old.sense, ''), old.trans_list);
END
''')

cursor.execute('''
CREATE TRIGGER dictionary_entries_au AFTER UPDATE ON dictionary_entries
BEGIN
  INSERT INTO dictionary_fts(dictionary_fts, rowid, written_rep, sense, trans_list)
  VALUES ('delete', old.id, old.written_rep, COALESCE(old.sense, ''), old.trans_list);
  INSERT INTO dictionary_fts(written_rep, sense, trans_list)
  VALUES (new.written_rep, COALESCE(new.sense, ''), new.trans_list);
END
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
                        (written_rep, sense, trans_list, source_language, target_language, source, lemma, definition, language_pair) 
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ''', (headword, definition, definition, source_lang, target_lang, 'Vuizur Wiktionary', headword, definition, '$PAIR'))
                    count += 1
            
            if count % 10000 == 0:
                print(f'Processed {count} entries...')

conn.commit()

# Rebuild FTS index to ensure consistency
cursor.execute('''INSERT INTO dictionary_fts(dictionary_fts) VALUES('rebuild')''')
conn.commit()

conn.close()
print(f'✅ Imported {count} entries')
print(f'✅ FTS index built for fast search')
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

echo "🔍 Checking indexes..."
sqlite3 "$PAIR.db" ".indexes dictionary_entries"

echo "📝 Checking FTS table..."
FTS_COUNT=$(sqlite3 "$PAIR.db" "SELECT COUNT(*) FROM dictionary_fts;")
echo "FTS index contains: $FTS_COUNT entries"

echo "📋 Checking metadata..."
sqlite3 "$PAIR.db" "SELECT key, value FROM pack_metadata;"

if [ "$WORD_COUNT" -lt 1000 ]; then
    echo "⚠️  Warning: Low word count, checking sample entries..."
    sqlite3 "$PAIR.db" "SELECT written_rep, substr(sense, 1, 80) FROM dictionary_entries LIMIT 5;"
fi

echo "🧪 Testing common words..."
COMMON_FOUND=$(sqlite3 "$PAIR.db" "SELECT COUNT(*) FROM dictionary_entries WHERE written_rep IN ('casa', 'agua', 'hacer', 'tener', 'ser', 'hola', 'tiempo', 'año', 'día', 'vez');")
echo "Found $COMMON_FOUND common Spanish words out of 10 tested"

echo "🔍 Sample lookup test..."
sqlite3 "$PAIR.db" "SELECT written_rep, substr(sense, 1, 60) as definition, source_language, target_language FROM dictionary_entries WHERE written_rep = 'agua' LIMIT 1;"

echo "📦 Packaging..."
zip "../$OUTPUT_DIR/${PAIR}.sqlite.zip" "$PAIR.db"

echo "✅ Success!"
echo "📁 Package: $OUTPUT_DIR/${PAIR}.sqlite.zip"
echo "📊 Entries: $WORD_COUNT"
echo "🔍 Common words: $COMMON_FOUND/10"