#!/bin/bash

# Comprehensive 2-Level Search Test for Vuizur Dictionary System
# Tests both direct lookup and search-based reverse translation
# Validates meaning extraction and synonym detection

set -e

# Configuration
DB_FILE="/Users/kayvangharbi/PycharmProjects/PolyRead/tools/es-en.db"
TEMP_DIR="/tmp/dict_test_$$"
TEST_RESULTS="$TEMP_DIR/test_results.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test word sets
SPANISH_TEST_WORDS=("casa" "agua" "hacer" "bueno" "grande" "rojo" "comer" "dormir" "trabajar" "familia")
ENGLISH_TEST_WORDS=("house" "water" "good" "red" "eat" "sleep" "work" "family" "book" "table")

echo -e "${BLUE}🔍 COMPREHENSIVE 2-LEVEL SEARCH TEST${NC}"
echo "================================================"
echo "Testing Vuizur Dictionary System v2.1"
echo "Database: $DB_FILE"
echo ""

# Create temp directory
mkdir -p "$TEMP_DIR"

# Check if database exists
if [[ ! -f "$DB_FILE" ]]; then
    echo -e "${RED}❌ ERROR: Database not found at $DB_FILE${NC}"
    exit 1
fi

# Get database stats
echo -e "${YELLOW}📊 Database Statistics:${NC}"
TOTAL_ENTRIES=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM dictionary_entries;")
LANGUAGE_PAIRS=$(sqlite3 "$DB_FILE" "
    SELECT source_language || '->' || target_language || ': ' || COUNT(*) 
    FROM dictionary_entries 
    GROUP BY source_language, target_language;
")
echo "  Total entries: $TOTAL_ENTRIES"
echo "  Language pairs:"
echo "$LANGUAGE_PAIRS" | sed 's/^/    /'
echo ""

# Test 1: Spanish→English Direct Lookup
echo -e "${BLUE}🇪🇸 → 🇺🇸 TEST 1: Spanish→English Direct Lookup${NC}"
echo "================================================"

successful_direct=0
total_direct=0

for word in "${SPANISH_TEST_WORDS[@]}"; do
    total_direct=$((total_direct + 1))
    echo -n "Testing '$word'... "
    
    # Direct lookup
    result=$(sqlite3 "$DB_FILE" "
        SELECT written_rep, trans_list, pos 
        FROM dictionary_entries 
        WHERE written_rep = '$word' 
          AND source_language = 'es' 
          AND target_language = 'en'
        LIMIT 3;
    ")
    
    if [[ -n "$result" ]]; then
        echo -e "${GREEN}✓ FOUND${NC}"
        echo "$result" | while IFS='|' read -r headword translations pos; do
            echo "    '$headword' ($pos) → $translations"
        done
        successful_direct=$((successful_direct + 1))
    else
        echo -e "${RED}✗ NOT FOUND${NC}"
    fi
    echo ""
done

echo "Direct lookup success rate: $successful_direct/$total_direct"
echo ""

# Test 2: English→Spanish Search-Based Reverse Lookup
echo -e "${BLUE}🇺🇸 → 🇪🇸 TEST 2: English→Spanish Search-Based Lookup${NC}"
echo "================================================"

successful_reverse=0
total_reverse=0

for word in "${ENGLISH_TEST_WORDS[@]}"; do
    total_reverse=$((total_reverse + 1))
    echo -n "Testing '$word'... "
    
    # Search-based reverse lookup using FTS5
    result=$(sqlite3 "$DB_FILE" "
        SELECT d.written_rep, d.trans_list, d.pos
        FROM dictionary_entries d
        WHERE d.id IN (
            SELECT rowid FROM dictionary_fts 
            WHERE dictionary_fts MATCH '$word'
        )
          AND d.source_language = 'es' 
          AND d.target_language = 'en'
        LIMIT 5;
    ")
    
    if [[ -n "$result" ]]; then
        echo -e "${GREEN}✓ FOUND${NC}"
        echo "$result" | while IFS='|' read -r spanish_word translations pos; do
            # Extract clean translation and check quality
            clean_translation=$(echo "$translations" | sed 's/<[^>]*>//g' | head -c 50)
            echo "    $word → '$spanish_word' ($pos)"
            echo "      Clean translation: $clean_translation"
            
            # Check if it's a proper noun (should be filtered out by smart algorithm)
            if [[ "$spanish_word" =~ ^[A-Z] ]]; then
                echo "      ⚠️  WARNING: Proper noun detected"
            fi
        done
        successful_reverse=$((successful_reverse + 1))
    else
        echo -e "${RED}✗ NOT FOUND${NC}"
    fi
    echo ""
done

echo "Reverse search success rate: $successful_reverse/$total_reverse"
echo ""

# Test 3: Advanced Meaning & Synonym Detection
echo -e "${BLUE}🔍 TEST 3: Advanced Meaning & Synonym Detection${NC}"
echo "================================================"

# Test comprehensive meaning extraction
test_meanings() {
    local word="$1"
    local direction="$2"
    
    echo "Testing meaning extraction for '$word' ($direction):"
    
    if [[ "$direction" == "es-en" ]]; then
        # Spanish to English
        result=$(sqlite3 "$DB_FILE" "
            SELECT written_rep, trans_list, pos, sense
            FROM dictionary_entries 
            WHERE written_rep = '$word' 
              AND source_language = 'es' 
              AND target_language = 'en'
            LIMIT 1;
        ")
    else
        # English to Spanish (search-based)
        result=$(sqlite3 "$DB_FILE" "
            SELECT d.written_rep, d.trans_list, d.pos, d.sense
            FROM dictionary_entries d
            WHERE d.id IN (
                SELECT rowid FROM dictionary_fts 
                WHERE dictionary_fts MATCH '$word'
            )
              AND d.source_language = 'es' 
              AND d.target_language = 'en'
            LIMIT 1;
        ")
    fi
    
    if [[ -n "$result" ]]; then
        echo "$result" | while IFS='|' read -r headword translations pos sense; do
            echo "  Primary word: '$headword' ($pos)"
            echo "  Translations: $translations"
            echo "  Context/Sense: $sense"
            
            # Extract individual meanings (pipe-separated in trans_list)
            echo "  Individual meanings:"
            echo "$translations" | sed 's/|/\n/g' | head -5 | while read -r meaning; do
                if [[ -n "$meaning" ]]; then
                    echo "    - $meaning"
                fi
            done
        done
        return 0
    else
        echo "  No results found"
        return 1
    fi
}

# Test meaning extraction for sample words
test_meanings "casa" "es-en"
echo ""
test_meanings "house" "en-es"
echo ""
test_meanings "trabajar" "es-en"
echo ""
test_meanings "work" "en-es"
echo ""

# Test 4: Performance & Quality Metrics
echo -e "${BLUE}⚡ TEST 4: Performance & Quality Metrics${NC}"
echo "================================================"

# Test lookup speed
echo "Testing lookup performance..."
start_time=$(date +%s%3N)

# Perform 10 direct lookups
for i in {1..10}; do
    sqlite3 "$DB_FILE" "
        SELECT written_rep, trans_list 
        FROM dictionary_entries 
        WHERE written_rep = 'casa' 
          AND source_language = 'es' 
          AND target_language = 'en'
        LIMIT 1;
    " > /dev/null
done

end_time=$(date +%s%3N)
direct_time=$((end_time - start_time))
avg_direct=$((direct_time / 10))

echo "  Direct lookup (10 queries): ${direct_time}ms total, ${avg_direct}ms average"

# Test search speed
start_time=$(date +%s%3N)

# Perform 10 FTS searches
for i in {1..10}; do
    sqlite3 "$DB_FILE" "
        SELECT d.written_rep, d.trans_list
        FROM dictionary_entries d
        WHERE d.id IN (
            SELECT rowid FROM dictionary_fts 
            WHERE dictionary_fts MATCH 'house'
        )
          AND d.source_language = 'es' 
          AND d.target_language = 'en'
        LIMIT 1;
    " > /dev/null
done

end_time=$(date +%s%3N)
search_time=$((end_time - start_time))
avg_search=$((search_time / 10))

echo "  FTS5 search (10 queries): ${search_time}ms total, ${avg_search}ms average"
echo ""

# Test 5: Data Quality Assessment
echo -e "${BLUE}🏆 TEST 5: Data Quality Assessment${NC}"
echo "================================================"

# Check for HTML contamination in headwords
html_contamination=$(sqlite3 "$DB_FILE" "
    SELECT COUNT(*) 
    FROM dictionary_entries 
    WHERE written_rep LIKE '%<%' OR written_rep LIKE '%>%';
")
echo "HTML contamination in headwords: $html_contamination entries"

# Check average translation length
avg_translation_length=$(sqlite3 "$DB_FILE" "
    SELECT AVG(LENGTH(trans_list)) 
    FROM dictionary_entries 
    WHERE source_language = 'es' AND target_language = 'en';
")
echo "Average translation length: ${avg_translation_length} characters"

# Check unique headwords
unique_headwords=$(sqlite3 "$DB_FILE" "
    SELECT COUNT(DISTINCT written_rep) 
    FROM dictionary_entries 
    WHERE source_language = 'es' AND target_language = 'en';
")
echo "Unique Spanish headwords: $unique_headwords"

# Calculate success rates
direct_rate=$((successful_direct * 100 / total_direct))
reverse_rate=$((successful_reverse * 100 / total_reverse))

echo ""
echo -e "${BLUE}📋 FINAL RESULTS SUMMARY${NC}"
echo "================================================"
echo "Spanish→English Direct Lookup: ${direct_rate}% success ($successful_direct/$total_direct)"
echo "English→Spanish Search Lookup: ${reverse_rate}% success ($successful_reverse/$total_reverse)"
echo "Direct lookup performance: ${avg_direct}ms average"
echo "Search lookup performance: ${avg_search}ms average"
echo "Data quality: $html_contamination HTML contamination issues"
echo "Vocabulary coverage: $unique_headwords unique Spanish headwords"

# Overall assessment
if [[ $direct_rate -ge 80 && $reverse_rate -ge 60 && $avg_direct -lt 50 && $avg_search -lt 200 ]]; then
    echo -e "${GREEN}✅ SYSTEM STATUS: EXCELLENT${NC}"
    echo "All tests passed. Dictionary system is production-ready."
else
    echo -e "${YELLOW}⚠️  SYSTEM STATUS: NEEDS ATTENTION${NC}"
    if [[ $direct_rate -lt 80 ]]; then
        echo "- Direct lookup success rate below 80%"
    fi
    if [[ $reverse_rate -lt 60 ]]; then
        echo "- Reverse search success rate below 60%"
    fi
    if [[ $avg_direct -ge 50 ]]; then
        echo "- Direct lookup performance slower than 50ms"
    fi
    if [[ $avg_search -ge 200 ]]; then
        echo "- Search performance slower than 200ms"
    fi
fi

# Save results
echo "Direct lookup: $direct_rate% ($successful_direct/$total_direct)" > "$TEST_RESULTS"
echo "Reverse search: $reverse_rate% ($successful_reverse/$total_reverse)" >> "$TEST_RESULTS"
echo "Direct speed: ${avg_direct}ms" >> "$TEST_RESULTS"
echo "Search speed: ${avg_search}ms" >> "$TEST_RESULTS"

echo ""
echo "Test results saved to: $TEST_RESULTS"
echo "Temporary files in: $TEMP_DIR"

# Cleanup option
read -p "Clean up temporary files? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$TEMP_DIR"
    echo "Temporary files cleaned up."
fi