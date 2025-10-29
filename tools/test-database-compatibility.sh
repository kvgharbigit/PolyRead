#!/bin/bash
# Database Compatibility Testing Script
# Tests dictionary databases for PolyRead import service compatibility

DB_FILE="$1"
if [ -z "$DB_FILE" ]; then
    echo "Usage: $0 <database-file.db>"
    echo "Example: $0 vuizur-es-en/es-en.db"
    exit 1
fi

if [ ! -f "$DB_FILE" ]; then
    echo "❌ Database file not found: $DB_FILE"
    exit 1
fi

echo "🔍 Testing PolyRead Database Compatibility: $DB_FILE"
echo "=================================================="

# Test 1: Required columns check (what import service validates)
echo
echo "📋 Test 1: Import Service Schema Validation"
echo "-------------------------------------------"
REQUIRED_COLS=$(sqlite3 "$DB_FILE" "
SELECT COUNT(*) FROM pragma_table_info('dictionary_entries') 
WHERE name IN ('lemma', 'definition', 'direction', 'source_language', 'target_language');
")

if [ "$REQUIRED_COLS" -eq 5 ]; then
    echo "✅ PASS: All required columns present (lemma, definition, direction, source_language, target_language)"
else
    echo "❌ FAIL: Missing required columns. Found $REQUIRED_COLS/5"
    echo "   Required by import service: lemma, definition, direction, source_language, target_language"
fi

# Test 2: Direction field validation
echo
echo "🔄 Test 2: Direction Field Validation"
echo "------------------------------------"
sqlite3 "$DB_FILE" "
SELECT 'Direction distribution:' as label;
SELECT '  ' || direction || ': ' || COUNT(*) || ' entries' as result 
FROM dictionary_entries GROUP BY direction ORDER BY direction;
"

VALID_DIRECTIONS=$(sqlite3 "$DB_FILE" "
SELECT COUNT(DISTINCT direction) FROM dictionary_entries 
WHERE direction IN ('forward', 'reverse');
")

if [ "$VALID_DIRECTIONS" -gt 0 ]; then
    echo "✅ PASS: Valid direction values found"
else
    echo "❌ FAIL: No valid direction values (forward/reverse)"
fi

# Test 3: Language pair validation  
echo
echo "🌍 Test 3: Language Pair Configuration"
echo "-------------------------------------"
sqlite3 "$DB_FILE" "
SELECT 'Language pairs found:' as label;
SELECT '  ' || source_language || ' → ' || target_language || ' (' || direction || ')' as result
FROM (SELECT DISTINCT source_language, target_language, direction FROM dictionary_entries ORDER BY direction);
"

# Test 4: Data quality check
echo
echo "📊 Test 4: Data Quality Validation"
echo "---------------------------------"
TOTAL_ENTRIES=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM dictionary_entries;")
NON_EMPTY=$(sqlite3 "$DB_FILE" "
SELECT COUNT(*) FROM dictionary_entries 
WHERE length(lemma) > 0 AND length(definition) > 0;
")

echo "Total entries: $TOTAL_ENTRIES"
echo "Non-empty entries: $NON_EMPTY"

if [ "$NON_EMPTY" -eq "$TOTAL_ENTRIES" ]; then
    echo "✅ PASS: All entries have non-empty lemma and definition"
else
    echo "⚠️  WARNING: $((TOTAL_ENTRIES - NON_EMPTY)) entries have empty lemma or definition"
fi

# Test 5: Sample data preview
echo
echo "🔍 Test 5: Sample Data Preview"
echo "-----------------------------"
echo "Forward entries (first 3):"
sqlite3 "$DB_FILE" "
SELECT '  ' || lemma || ' → ' || substr(definition, 1, 40) || '...' as sample
FROM dictionary_entries 
WHERE direction = 'forward' AND length(lemma) > 1 
ORDER BY id LIMIT 3;
"

echo
echo "Reverse entries (first 3):"
sqlite3 "$DB_FILE" "
SELECT '  ' || lemma || ' → ' || substr(definition, 1, 40) || '...' as sample
FROM dictionary_entries 
WHERE direction = 'reverse' AND length(lemma) > 1 
ORDER BY id LIMIT 3;
"

# Test 6: Metadata validation
echo
echo "📋 Test 6: Pack Metadata Validation"
echo "----------------------------------"
METADATA_COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM pack_metadata WHERE key IN ('language_pair', 'source_language', 'target_language', 'format_version');")

if [ "$METADATA_COUNT" -ge 4 ]; then
    echo "✅ PASS: Essential metadata present"
    sqlite3 "$DB_FILE" "
    SELECT '  ' || key || ': ' || value as metadata 
    FROM pack_metadata ORDER BY key;
    "
else
    echo "⚠️  WARNING: Missing some metadata fields"
fi

# Test 7: Performance indicators
echo
echo "⚡ Test 7: Performance Indicators"
echo "-------------------------------"
INDEXES=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_%';")
FTS_TABLES=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name LIKE '%_fts';")

echo "Database indexes: $INDEXES"
echo "FTS tables: $FTS_TABLES"

if [ "$INDEXES" -gt 0 ]; then
    echo "✅ Performance indexes present"
else
    echo "⚠️  No performance indexes found"
fi

# Test 8: Common word spot check (for Spanish-English)
echo
echo "🎯 Test 8: Common Word Spot Check"
echo "--------------------------------"
LANG_PAIR=$(sqlite3 "$DB_FILE" "SELECT value FROM pack_metadata WHERE key = 'language_pair' LIMIT 1;")

if [ "$LANG_PAIR" = "es-en" ]; then
    COMMON_WORDS="casa agua hacer tener ser hola tiempo"
    echo "Testing common Spanish words..."
    
    for word in $COMMON_WORDS; do
        COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM dictionary_entries WHERE lemma = '$word';")
        if [ "$COUNT" -gt 0 ]; then
            echo "  ✅ $word: found ($COUNT entries)"
        else
            echo "  ❌ $word: not found"
        fi
    done
else
    echo "Skipping common word test (not Spanish-English)"
fi

# Final Summary
echo
echo "🏁 Compatibility Test Summary"
echo "============================"

# Calculate overall score
PASS_COUNT=0
if [ "$REQUIRED_COLS" -eq 5 ]; then PASS_COUNT=$((PASS_COUNT + 1)); fi
if [ "$VALID_DIRECTIONS" -gt 0 ]; then PASS_COUNT=$((PASS_COUNT + 1)); fi
if [ "$NON_EMPTY" -eq "$TOTAL_ENTRIES" ]; then PASS_COUNT=$((PASS_COUNT + 1)); fi
if [ "$METADATA_COUNT" -ge 4 ]; then PASS_COUNT=$((PASS_COUNT + 1)); fi

TOTAL_TESTS=4
SCORE=$((PASS_COUNT * 100 / TOTAL_TESTS))

echo "Score: $PASS_COUNT/$TOTAL_TESTS tests passed ($SCORE%)"

if [ "$SCORE" -ge 100 ]; then
    echo "🟢 EXCELLENT: Database is fully compatible with PolyRead import service"
elif [ "$SCORE" -ge 75 ]; then
    echo "🟡 GOOD: Database is mostly compatible, minor issues detected"
else
    echo "🔴 POOR: Database has compatibility issues that need fixing"
fi

echo
echo "Database: $DB_FILE"
echo "Total entries: $TOTAL_ENTRIES"
echo "Language pair: $LANG_PAIR"
echo "Tested: $(date)"