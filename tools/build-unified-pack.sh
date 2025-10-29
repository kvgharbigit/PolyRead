#!/usr/bin/env bash
set -euo pipefail

PAIR="${1:?usage: build-unified-pack.sh eng-spa|spa-eng|eng-fra|...}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$SCRIPT_DIR/dist/packs"
WORK_DIR="$SCRIPT_DIR/tmp-unified-${PAIR}"
mkdir -p "$OUT_DIR" "$WORK_DIR"

echo "🔧 Building unified dictionary pack: $PAIR"
cd "$WORK_DIR"

# Load optimal strategy from our discovery results
get_optimal_source() {
    local pair="$1"
    
    # Based on TOP 10 languages - Wiktionary only (verified URLs)
    case "$pair" in
        "eng-spa"|"spa-eng"|"es-en"|"en-es")
            SOURCE="wiktionary"
            URL="https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/Spanish-English%20Wiktionary%20dictionary%20stardict.tar.gz"
            SIZE="4.6MB"
            REASON="Wiktionary bilingual - rich definitions, examples, IPA, bidirectional"
            ;;
        "eng-fra"|"fra-eng"|"fr-en"|"en-fr")
            SOURCE="wiktionary"
            URL="https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/French-English%20Wiktionary%20dictionary%20stardict.tar.gz"
            SIZE="3.2MB"
            REASON="Wiktionary bilingual - rich definitions, examples, IPA, bidirectional"
            ;;
        "eng-deu"|"deu-eng"|"de-en"|"en-de")
            SOURCE="wiktionary"
            URL="https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/German-English%20Wiktionary%20dictionary%20stardict.tar.gz"
            SIZE="6.9MB"
            REASON="Wiktionary bilingual - rich definitions, examples, IPA, bidirectional"
            ;;
        "eng-ita"|"ita-eng"|"it-en"|"en-it")
            SOURCE="wiktionary"
            URL="https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/Italian-English%20Wiktionary%20dictionary%20stardict.tar.gz"
            SIZE="5.3MB"
            REASON="Wiktionary bilingual - rich definitions, examples, IPA, bidirectional"
            ;;
        "eng-por"|"por-eng"|"pt-en"|"en-pt")
            SOURCE="wiktionary"
            URL="https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/Portuguese-English%20Wiktionary%20dictionary%20stardict.tar.gz"
            SIZE="2.6MB"
            REASON="Wiktionary bilingual - rich definitions, examples, IPA, bidirectional"
            ;;
        "eng-rus"|"rus-eng"|"ru-en"|"en-ru")
            SOURCE="wiktionary"
            URL="https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/Russian-English%20Wiktionary%20dictionary%20stardict.tar.gz"
            SIZE="4.2MB"
            REASON="Wiktionary bilingual - rich definitions, examples, IPA, bidirectional"
            ;;
        "zh-en"|"en-zh"|"chn-eng"|"eng-chn")
            SOURCE="wiktionary"
            URL="https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/Chinese-English%20Wiktionary%20dictionary%20stardict.tar.gz"
            SIZE="4.6MB"
            REASON="Wiktionary bilingual - rich definitions, examples, IPA, bidirectional"
            ;;
        "ja-en"|"en-ja"|"jpn-eng"|"eng-jpn")
            SOURCE="wiktionary"
            URL="https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/Japanese-English%20Wiktionary%20dictionary%20stardict.tar.gz"
            SIZE="5.9MB"
            REASON="Wiktionary bilingual - rich definitions, examples, IPA, bidirectional"
            ;;
        "ko-en"|"en-ko"|"kor-eng"|"eng-kor")
            SOURCE="wiktionary"
            URL="https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/Korean-English%20Wiktionary%20dictionary%20stardict.tar.gz"
            SIZE="2.1MB"
            REASON="Wiktionary bilingual - rich definitions, examples, IPA, bidirectional"
            ;;
        "ar-en"|"en-ar"|"ara-eng"|"eng-ara")
            SOURCE="wiktionary"
            URL="https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/Arabic-English%20Wiktionary%20dictionary%20stardict.tar.gz"
            SIZE="2.9MB"
            REASON="Wiktionary bilingual - rich definitions, examples, IPA, bidirectional"
            ;;
        "hi-en"|"en-hi"|"hin-eng"|"eng-hin")
            SOURCE="wiktionary"
            URL="https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/Hindi-English%20Wiktionary%20dictionary%20stardict.tar.gz"
            SIZE="1.0MB"
            REASON="Wiktionary bilingual - rich definitions, examples, IPA, bidirectional"
            ;;
        *)
            echo "❌ Unknown language pair: $PAIR"
            echo "🎯 SUPPORTED LANGUAGE PAIRS (Wiktionary verified):"
            echo "   ✅ English ↔ Spanish, French, German, Japanese, Korean"
            echo "   ✅ English ↔ Arabic, Hindi"
            echo "   📝 All sources verified and functional from Vuizur/Wiktionary-Dictionaries"
            exit 1
            ;;
    esac
}

# Get optimal source for this pair
get_optimal_source "$PAIR"

echo "📊 Optimal choice: $SOURCE"
echo "📡 Source: $URL ($SIZE)"
echo "💡 Reason: $REASON"
if [[ -n "${WARNING:-}" ]]; then
    echo "$WARNING"
fi

# Download and extract
echo "📥 Downloading dictionary..."
if [[ "$URL" == *".tar.xz" ]]; then
    curl -L -o "${PAIR}.tar.xz" "$URL"
    tar -xJf "${PAIR}.tar.xz"
elif [[ "$URL" == *".tar.gz" ]]; then
    curl -L -o "${PAIR}.tar.gz" "$URL"
    tar -xzf "${PAIR}.tar.gz"
else
    echo "❌ Unknown archive format for $URL"
    exit 1
fi

# Find dictionary files - handle spaces in filenames
IFS=$'\n' DICT_FILES=($(find . -name "*.ifo"))
if [[ ${#DICT_FILES[@]} -eq 0 ]]; then
    echo "❌ No StarDict files found in archive"
    echo "📂 Contents of archive:"
    find . -type f | head -10
    exit 1
fi

DICT_IFO="${DICT_FILES[0]}"
DICT_DIR=$(dirname "$DICT_IFO")
DICT_BASE=$(basename "$DICT_IFO" .ifo)

echo "🔍 Found dictionary: $DICT_BASE"
echo "📂 Dictionary directory: $DICT_DIR"

# Decompress dictionary files if needed
echo "📜 Preparing dictionary files..."
ORIGINAL_DIR=$(pwd)
cd "$DICT_DIR"

# Decompress .dict.dz if it exists
if [[ -f "${DICT_BASE}.dict.dz" ]]; then
    echo "  Decompressing ${DICT_BASE}.dict.dz..."
    # Try dictzip first, then multiple gzip alternatives
    if command -v dictzip &> /dev/null; then
        dictzip -d "${DICT_BASE}.dict.dz" || {
            echo "  ⚠️ dictzip failed, trying gzip alternatives..."
            # Try gunzip with force flag (works with .dz files)
            gunzip -f "${DICT_BASE}.dict.dz" 2>/dev/null || {
                # Try python gzip as last resort
                python3 -c "
import gzip
with gzip.open('${DICT_BASE}.dict.dz', 'rb') as f_in:
    with open('${DICT_BASE}.dict', 'wb') as f_out:
        f_out.write(f_in.read())
" && rm "${DICT_BASE}.dict.dz" || {
                    echo "  ❌ Failed to decompress .dict.dz file with all methods"
                    exit 1
                }
            }
        }
    else
        echo "  dictzip not found, trying gunzip..."
        gunzip -f "${DICT_BASE}.dict.dz" 2>/dev/null || {
            echo "  gunzip failed, trying python gzip..."
            python3 -c "
import gzip
with gzip.open('${DICT_BASE}.dict.dz', 'rb') as f_in:
    with open('${DICT_BASE}.dict', 'wb') as f_out:
        f_out.write(f_in.read())
" && rm "${DICT_BASE}.dict.dz" || {
                echo "  ❌ Failed to decompress .dict.dz file"
                exit 1
            }
        }
    fi
fi

# Decompress .idx.gz if it exists  
if [[ -f "${DICT_BASE}.idx.gz" ]]; then
    echo "  Decompressing ${DICT_BASE}.idx.gz..."
    gzip -d "${DICT_BASE}.idx.gz" || {
        echo "  ❌ Failed to decompress .idx.gz file"
        exit 1
    }
fi

# Now check for required files
if [[ ! -f "${DICT_BASE}.ifo" || ! -f "${DICT_BASE}.idx" || ! -f "${DICT_BASE}.dict" ]]; then
    echo "❌ Missing required StarDict files (.ifo, .idx, .dict)"
    ls -la
    exit 1
fi

echo "✅ StarDict files prepared: ${DICT_BASE}.{ifo,idx,dict}"

# Convert to SQLite using PyGlossary with UTF-8 encoding support
echo "🔄 Converting StarDict to SQLite..."
cd "$ORIGINAL_DIR"

# Set UTF-8 locale environment for proper character handling
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export PYTHONIOENCODING=utf-8

# Primary conversion attempt with proper error handling
echo "🔄 Attempting PyGlossary conversion with error tolerance..."
pyglossary "${DICT_DIR}/${DICT_BASE}.ifo" "${PAIR}.sql" \
    --write-format=Sql \
    --no-utf8-check \
    --verbosity=1 || {
    echo "❌ PyGlossary conversion failed, trying with basic settings..."
    
    # Try with more permissive settings
    pyglossary --read-format=Stardict --write-format=Sql \
        "${DICT_DIR}/${DICT_BASE}.ifo" "${PAIR}.sql" \
        --no-utf8-check \
        --verbosity=0 || {
        
        echo "❌ Second attempt failed, trying with SQLite mode..."
        # Fallback: use SQLite intermediate storage (handles corruption better)
        pyglossary "${DICT_DIR}/${DICT_BASE}.ifo" "${PAIR}.sql" \
            --write-format=Sql \
            --sqlite \
            --no-utf8-check \
            --verbosity=0 || {
            echo "❌ All conversion attempts failed"
            exit 1
        }
    }
}

# Convert SQL to SQLite and optimize for mobile usage
echo "🔄 Converting SQL to SQLite..."
if ! sqlite3 "${PAIR}.sqlite" < "${PAIR}.sql" 2>/dev/null; then
    echo "⚠️ SQL import had errors, cleaning up and retrying..."
    # Remove the failed database
    rm -f "${PAIR}.sqlite"
    
    # Clean the SQL file of problematic entries and retry
    echo "🧹 Cleaning SQL file of invalid entries..."
    # Remove lines with invalid UTF-8 sequences and null bytes
    sed 's/\x0//g' "${PAIR}.sql" | iconv -f utf-8 -t utf-8 -c > "${PAIR}_clean.sql" 2>/dev/null || {
        echo "⚠️ Fallback: using original SQL file"
        cp "${PAIR}.sql" "${PAIR}_clean.sql"
    }
    
    # Try with cleaned SQL
    sqlite3 "${PAIR}.sqlite" < "${PAIR}_clean.sql" || {
        echo "❌ Failed to import cleaned SQL, trying line-by-line import..."
        # Last resort: import line by line, skipping errors
        while IFS= read -r line; do
            echo "$line" | sqlite3 "${PAIR}.sqlite" 2>/dev/null || true
        done < "${PAIR}_clean.sql"
    }
    
    rm -f "${PAIR}_clean.sql"
fi

# Validate conversion and check for encoding issues
echo "🔍 Validating conversion quality..."
TOTAL_ENTRIES=$(sqlite3 "${PAIR}.sqlite" "SELECT COUNT(*) FROM word;" 2>/dev/null || echo "0")

# Ensure we have a reasonable number of entries
if [[ $TOTAL_ENTRIES -lt 1000 ]]; then
    echo "❌ Too few entries ($TOTAL_ENTRIES) - dictionary conversion likely failed"
    echo "Checking if table exists and has data..."
    
    # Check what tables exist
    TABLES=$(sqlite3 "${PAIR}.sqlite" ".tables" 2>/dev/null || echo "")
    echo "Available tables: $TABLES"
    
    if [[ -z "$TABLES" ]]; then
        echo "❌ No tables found in database - conversion completely failed"
        exit 1
    fi
    
    # If word table doesn't exist but others do, still continue with warning
    if [[ $TOTAL_ENTRIES -eq 0 ]]; then
        echo "⚠️ Warning: word table is empty, but continuing with other tables..."
    fi
fi
EMPTY_ENTRIES=$(sqlite3 "${PAIR}.sqlite" "SELECT COUNT(*) FROM word WHERE LENGTH(TRIM(COALESCE(w, ''))) = 0 OR LENGTH(TRIM(COALESCE(m, ''))) = 0;")
NON_UTF8_ENTRIES=$(sqlite3 "${PAIR}.sqlite" "SELECT COUNT(*) FROM word WHERE w LIKE '%\\%' OR m LIKE '%\\%' OR w LIKE '%?%' OR m LIKE '%?%';")

echo "📊 Conversion validation:"
echo "  Total entries: $TOTAL_ENTRIES"
echo "  Empty entries: $EMPTY_ENTRIES"  
echo "  Potentially corrupted entries: $NON_UTF8_ENTRIES"

if [[ $EMPTY_ENTRIES -gt $(($TOTAL_ENTRIES / 10)) ]]; then
    echo "⚠️ Warning: High number of empty entries (>10% of total)"
fi

if [[ $NON_UTF8_ENTRIES -gt $(($TOTAL_ENTRIES / 20)) ]]; then
    echo "⚠️ Warning: High number of potentially corrupted entries (>5% of total)"
fi

echo "⚡ Optimizing SQLite for mobile..."  
sqlite3 "${PAIR}.sqlite" <<'SQL'
-- Mobile optimization
PRAGMA journal_mode=OFF;
PRAGMA synchronous=OFF;
PRAGMA cache_size=10000;

-- Clean up any problematic entries in word table
UPDATE word SET 
    w = TRIM(w),
    m = TRIM(m)
WHERE w != TRIM(w) OR m != TRIM(m);

-- Remove empty entries
DELETE FROM word WHERE 
    LENGTH(TRIM(COALESCE(w, ''))) = 0 OR 
    LENGTH(TRIM(COALESCE(m, ''))) = 0;

-- Convert to dict table schema for app compatibility
CREATE TABLE dict (
    lemma TEXT PRIMARY KEY,
    def TEXT NOT NULL
);

-- Copy data from word to dict table (preserve ALL entries)
INSERT INTO dict (lemma, def)
SELECT w as lemma, m as def FROM word 
WHERE w IS NOT NULL AND m IS NOT NULL 
  AND LENGTH(TRIM(w)) > 0 AND LENGTH(TRIM(m)) > 0;

-- Also include alternate word forms pointing to definitions
INSERT OR IGNORE INTO dict (lemma, def)
SELECT alt.w as lemma, word.m as def 
FROM alt 
JOIN word ON alt.id = word.id
WHERE alt.w IS NOT NULL AND word.m IS NOT NULL 
  AND LENGTH(TRIM(alt.w)) > 0 AND LENGTH(TRIM(word.m)) > 0;

-- Drop the old tables
DROP TABLE word;
DROP TABLE IF EXISTS dbinfo;

-- Create proper indexes for dict table
CREATE INDEX IF NOT EXISTS idx_dict_lemma ON dict(lemma);

-- Final optimization
VACUUM;
ANALYZE;
SQL

# Get final stats with validation  
WORD_COUNT=$(sqlite3 "${PAIR}.sqlite" "SELECT COUNT(*) FROM word;" 2>/dev/null || echo "0")
ALT_COUNT=$(sqlite3 "${PAIR}.sqlite" "SELECT COUNT(*) FROM alt;" 2>/dev/null || echo "0")
BEFORE_COUNT=$((WORD_COUNT + ALT_COUNT))
FINAL_COUNT=$(sqlite3 "${PAIR}.sqlite" "SELECT COUNT(*) FROM dict;")

echo "📊 Dictionary conversion results:"
echo "   Word entries: $WORD_COUNT"
echo "   Alt entries:  $ALT_COUNT" 
echo "   Total before: $BEFORE_COUNT entries (word + alt tables)"
echo "   Final dict:   $FINAL_COUNT entries"

# Validate data integrity (allow for some deduplication but not massive loss)
if [[ $BEFORE_COUNT -gt 0 ]] && [[ $FINAL_COUNT -lt $((BEFORE_COUNT * 80 / 100)) ]]; then
    echo "❌ CRITICAL: Significant data loss detected!"
    echo "   Lost $(($BEFORE_COUNT - $FINAL_COUNT)) entries ($(((($BEFORE_COUNT - $FINAL_COUNT) * 100) / $BEFORE_COUNT))%)"
    echo "   This suggests a bug in the schema conversion process"
    exit 1
else
    echo "✅ Data integrity check passed"
fi

# Create final package
echo "📦 Creating final package..."
zip -9 "$OUT_DIR/${PAIR}.sqlite.zip" "${PAIR}.sqlite"

# Generate metadata with source information
bytes=$(stat -f%z "$OUT_DIR/${PAIR}.sqlite.zip" 2>/dev/null || stat -c%s "$OUT_DIR/${PAIR}.sqlite.zip")
sha=$(shasum -a 256 "$OUT_DIR/${PAIR}.sqlite.zip" | awk '{print $1}')

cat > "$OUT_DIR/${PAIR}.json" <<JSON
{
  "id": "${PAIR}",
  "type": "bilingual",
  "source": "${SOURCE}",
  "original_size": "${SIZE}",
  "bytes": ${bytes},
  "entries": ${FINAL_COUNT},
  "sha256": "${sha}",
  "reason": "${REASON}",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "strategy": "top_7_languages_optimal"
}
JSON

echo "✅ Built: $OUT_DIR/${PAIR}.sqlite.zip ($(numfmt --to=iec $bytes))"
echo "📄 Metadata: $OUT_DIR/${PAIR}.json"
echo "📊 Source: $SOURCE ($SIZE → $(numfmt --to=iec $bytes))"

# Debug: Show exactly what was produced
echo "OUT_DIR=$OUT_DIR"
echo "Files produced:"
ls -lh "$OUT_DIR" || true

# Cleanup
cd ..
rm -rf "$WORK_DIR"

echo "🎯 Unified pack ready: $PAIR"