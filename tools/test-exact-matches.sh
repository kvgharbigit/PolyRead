#!/bin/bash

# Simple Exact Match Test - No Complex Scoring
# Finds Spanish words that have English word as PRIMARY translation

set -e

DB_FILE="/Users/kayvangharbi/PycharmProjects/PolyRead/tools/es-en.db"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'  
BLUE='\033[0;34m'
NC='\033[0m'

ENGLISH_TEST_WORDS=("house" "water" "good" "red" "eat" "sleep" "work" "family" "book" "table")

echo -e "${BLUE}🎯 EXACT MATCH ALGORITHM TEST${NC}"
echo "Find Spanish words with English word as PRIMARY translation"
echo ""

successful=0
total=0

for word in "${ENGLISH_TEST_WORDS[@]}"; do
    total=$((total + 1))
    echo -n "Testing '$word'... "
    
    # Find Spanish words that have this English word as primary translation
    # Improved patterns + part-of-speech priority + conjugation filtering
    results=$(sqlite3 "$DB_FILE" "
        SELECT written_rep, trans_list 
        FROM dictionary_entries 
        WHERE source_language = 'es' 
          AND target_language = 'en'
          AND (
            trans_list LIKE '%<li>$word</li>%' OR 
            trans_list LIKE '%<li>$word (%' OR
            trans_list LIKE '%<li>to $word</li>%' OR
            trans_list LIKE '%<li>(intransitive) to $word</li>%' OR
            trans_list LIKE '%<li>(transitive) to $word</li>%' OR
            trans_list LIKE '%) $word,%' OR
            trans_list LIKE '%) $word</li>%' OR
            trans_list LIKE '%$word, %'
          )
          AND length(written_rep) <= 12  -- Reasonable word length
          AND written_rep NOT LIKE '%í'   -- Filter conjugations (past tense)
          AND written_rep NOT LIKE '%é'   -- Filter conjugations (past tense)
          AND written_rep NOT LIKE '%ó'   -- Filter conjugations (past tense)
        ORDER BY 
          -- Prioritize nouns/adjectives over verbs
          CASE 
            WHEN trans_list LIKE '%<i>noun</i>%' THEN 1
            WHEN trans_list LIKE '%<i>adj</i>%' THEN 2  
            WHEN trans_list LIKE '%<i>verb</i>%' THEN 3
            ELSE 4
          END,
          -- Then prefer shorter base forms
          length(written_rep),
          -- Then alphabetical
          written_rep
        LIMIT 5;
    ")
    
    if [[ -n "$results" ]]; then
        echo -e "${GREEN}✓ EXACT MATCHES FOUND${NC}"
        
        echo "$results" | while IFS='|' read -r spanish_word full_def; do
            # Extract just the translations, clean up HTML
            clean_def=$(echo "$full_def" | sed 's/<[^>]*>//g' | tr '\n' ' ' | sed 's/  */ /g')
            echo "    $word → '$spanish_word'"
            echo "      Full meanings: $clean_def"
        done
        successful=$((successful + 1))
    else
        echo -e "${RED}✗ NO EXACT MATCH${NC}"
    fi
    echo ""
done

echo ""
echo -e "${BLUE}📋 EXACT MATCH RESULTS${NC}"
echo "Success rate: $successful/$total"

if [[ $successful -ge 8 ]]; then
    echo -e "${GREEN}✅ EXCELLENT: Most words have exact Spanish matches${NC}"
elif [[ $successful -ge 5 ]]; then
    echo -e "${GREEN}✅ GOOD: Many words have exact Spanish matches${NC}"
else
    echo -e "${RED}❌ POOR: Few exact matches found${NC}"
fi