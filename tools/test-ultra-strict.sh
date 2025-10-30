#!/bin/bash

# ULTRA STRICT - Only perfect obvious matches, ML Kit for everything else

set -e

DB_FILE="/Users/kayvangharbi/PycharmProjects/PolyRead/tools/es-en.db"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ENGLISH_TEST_WORDS=("house" "water" "good" "red" "eat" "sleep" "work" "family" "book" "table" "big" "love" "time" "hand" "eye")

echo -e "${BLUE}🔒 ULTRA STRICT QUALITY TEST${NC}"
echo "Only accept obvious, perfect matches"
echo ""

# Function for ultra-strict quality check
is_perfect_match() {
    local english_word="$1"
    local spanish_word="$2" 
    local definition="$3"
    
    # Must be reasonable length
    if [[ ${#spanish_word} -lt 3 || ${#spanish_word} -gt 8 ]]; then
        return 1
    fi
    
    # No abbreviations or symbols
    if [[ "$spanish_word" =~ [.!¡¿] ]]; then
        return 1
    fi
    
    # Extract the FIRST meaning only
    first_meaning=$(echo "$definition" | grep -o '<li>[^<]*</li>' | head -1 | sed 's/<[^>]*>//g')
    
    # Check if first meaning is exactly the English word or starts with it
    if [[ "$first_meaning" == "$english_word" ]] || [[ "$first_meaning" == "to $english_word" ]]; then
        echo "PERFECT: '$spanish_word' → '$first_meaning'"
        return 0
    fi
    
    # Allow some basic variations
    if [[ "$english_word" == "good" && ("$first_meaning" =~ ^"well" || "$first_meaning" =~ ^"fine") ]]; then
        echo "PERFECT: '$spanish_word' → '$first_meaning'"
        return 0
    fi
    
    if [[ "$english_word" == "red" && "$first_meaning" =~ ^"red" ]]; then
        echo "PERFECT: '$spanish_word' → '$first_meaning'"
        return 0
    fi
    
    return 1
}

successful=0
total=0

for english_word in "${ENGLISH_TEST_WORDS[@]}"; do
    total=$((total + 1))
    echo -e "${YELLOW}Testing '$english_word'...${NC}"
    
    # Only look for exact first-meaning matches
    results=$(sqlite3 "$DB_FILE" "
        SELECT written_rep, trans_list 
        FROM dictionary_entries 
        WHERE source_language = 'es' 
          AND target_language = 'en'
          AND (
            trans_list LIKE '%<li>$english_word</li>%' OR
            trans_list LIKE '%<li>to $english_word</li>%'
          )
          AND length(written_rep) BETWEEN 3 AND 8
          AND written_rep NOT LIKE '%.%'
          AND written_rep NOT LIKE '%!%'
          AND written_rep NOT LIKE '%¡%'
        ORDER BY 
          CASE 
            WHEN trans_list LIKE '%<i>noun</i>%' THEN 1
            WHEN trans_list LIKE '%<i>adj</i>%' THEN 2  
            WHEN trans_list LIKE '%<i>verb</i>%' THEN 3
            ELSE 4
          END,
          length(written_rep)
        LIMIT 3;
    ")
    
    if [[ -n "$results" ]]; then
        perfect_matches=()
        
        while IFS='|' read -r spanish_word definition; do
            if is_perfect_match "$english_word" "$spanish_word" "$definition"; then
                perfect_matches+=("$spanish_word")
            fi
        done <<< "$results"
        
        if [[ ${#perfect_matches[@]} -gt 0 ]]; then
            echo -e "  ${GREEN}✅ PERFECT MATCHES: ${perfect_matches[*]}${NC}"
            successful=$((successful + 1))
        else
            echo -e "  ${YELLOW}⚠️  NO PERFECT MATCH → ML KIT${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠️  NO CANDIDATES → ML KIT${NC}"
    fi
    echo ""
done

echo -e "${BLUE}📊 ULTRA STRICT RESULTS${NC}"
echo "============================================="
perfect_rate=$((successful * 100 / total))
fallback_rate=$((100 - perfect_rate))

echo "Perfect dictionary matches: $successful/$total ($perfect_rate%)"
echo "ML Kit fallback: $((total - successful))/$total ($fallback_rate%)"

echo ""
if [[ $perfect_rate -ge 80 ]]; then
    echo -e "${GREEN}🎯 OPTIMAL: High-quality dictionary + ML Kit backup${NC}"
elif [[ $perfect_rate -ge 60 ]]; then
    echo -e "${GREEN}✅ EXCELLENT: Clean dictionary, ML Kit handles edge cases${NC}"
elif [[ $perfect_rate -ge 40 ]]; then
    echo -e "${YELLOW}⚠️  CONSERVATIVE: Very clean but limited dictionary${NC}"
else
    echo -e "${YELLOW}⚠️  ULTRA-CONSERVATIVE: ML Kit does most work${NC}"
fi

echo ""
echo -e "${BLUE}🎯 RECOMMENDED APPROACH:${NC}"
echo "- Dictionary: Only obvious, perfect translations"
echo "- ML Kit: Everything else (complex, archaic, slang, etc.)"
echo "- User sees: Either perfect dictionary match or AI translation"
echo "- No garbage: Conservative filtering prevents bad results"