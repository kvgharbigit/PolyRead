#!/bin/bash

# SINGLE PERFECT MATCH - One best Spanish word per English word
# No conjugations, no plurals, no diminutives - just the perfect base form

set -e

DB_FILE="/Users/kayvangharbi/PycharmProjects/PolyRead/tools/es-en.db"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ENGLISH_TEST_WORDS=("house" "water" "good" "red" "eat" "sleep" "work" "family" "book" "table" "big" "love" "time" "hand" "eye")

echo -e "${BLUE}🎯 SINGLE PERFECT MATCH TEST${NC}"
echo "One perfect base form per English word - no conjugations"
echo ""

# Function to check if a Spanish word is a base form (not conjugated)
is_base_form() {
    local word="$1"
    
    # Reject plurals (most end in 's')
    if [[ "$word" =~ s$ && ${#word} -gt 4 ]]; then
        return 1
    fi
    
    # Reject diminutives
    if [[ "$word" =~ (ito|ita|illo|illa|ete|eta)$ ]]; then
        return 1
    fi
    
    # Reject augmentatives  
    if [[ "$word" =~ (ote|ota|azo|aza)$ ]]; then
        return 1
    fi
    
    # Reject verb conjugations (common endings)
    if [[ "$word" =~ (í|é|ó|ás|és|ís|an|en)$ ]]; then
        return 1
    fi
    
    # Reject feminine forms if we can detect them
    # (This is tricky, but some patterns)
    
    return 0
}

successful=0
total=0

for english_word in "${ENGLISH_TEST_WORDS[@]}"; do
    total=$((total + 1))
    echo -e "${YELLOW}Testing '$english_word'...${NC}"
    
    # Get candidates and find the best base form
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
        ORDER BY 
          CASE 
            WHEN trans_list LIKE '%<i>noun</i>%' THEN 1
            WHEN trans_list LIKE '%<i>adj</i>%' THEN 2  
            WHEN trans_list LIKE '%<i>verb</i>%' THEN 3
            ELSE 4
          END,
          length(written_rep)
        LIMIT 10;
    ")
    
    if [[ -n "$results" ]]; then
        perfect_match=""
        
        while IFS='|' read -r spanish_word definition; do
            # Check if first meaning is exactly what we want
            first_meaning=$(echo "$definition" | grep -o '<li>[^<]*</li>' | head -1 | sed 's/<[^>]*>//g')
            
            # Must be exact match and base form
            if ([[ "$first_meaning" == "$english_word" ]] || [[ "$first_meaning" == "to $english_word" ]]) && is_base_form "$spanish_word"; then
                perfect_match="$spanish_word"
                break
            fi
        done <<< "$results"
        
        if [[ -n "$perfect_match" ]]; then
            echo -e "  ${GREEN}✅ PERFECT: '$english_word' → '$perfect_match'${NC}"
            successful=$((successful + 1))
        else
            echo -e "  ${YELLOW}⚠️  NO BASE FORM MATCH → ML KIT${NC}"
            
            # Debug: show what we found
            echo "    Candidates found:"
            while IFS='|' read -r spanish_word definition; do
                first_meaning=$(echo "$definition" | grep -o '<li>[^<]*</li>' | head -1 | sed 's/<[^>]*>//g')
                if [[ "$first_meaning" == "$english_word" ]] || [[ "$first_meaning" == "to $english_word" ]]; then
                    if is_base_form "$spanish_word"; then
                        echo "      '$spanish_word' (base form) ✓"
                    else
                        echo "      '$spanish_word' (conjugated) ❌"
                    fi
                fi
            done <<< "$results"
        fi
    else
        echo -e "  ${YELLOW}⚠️  NO CANDIDATES → ML KIT${NC}"
    fi
    echo ""
done

echo -e "${BLUE}📊 SINGLE PERFECT MATCH RESULTS${NC}"
echo "============================================="
perfect_rate=$((successful * 100 / total))
fallback_rate=$((100 - perfect_rate))

echo "Perfect base form matches: $successful/$total ($perfect_rate%)"
echo "ML Kit fallback needed: $((total - successful))/$total ($fallback_rate%)"

echo ""
if [[ $perfect_rate -ge 70 ]]; then
    echo -e "${GREEN}🎯 EXCELLENT: High base form coverage${NC}"
elif [[ $perfect_rate -ge 50 ]]; then
    echo -e "${GREEN}✅ GOOD: Decent base form coverage${NC}"
elif [[ $perfect_rate -ge 30 ]]; then
    echo -e "${YELLOW}⚠️  FAIR: Limited but clean base forms${NC}"
else
    echo -e "${YELLOW}⚠️  CONSERVATIVE: Mostly ML Kit${NC}"
fi

echo ""
echo -e "${BLUE}💡 ANTI-CONJUGATION STRATEGY:${NC}"
echo "- Dictionary: Only ONE perfect base form per English word"
echo "- NO plurals, diminutives, conjugations, inflections"
echo "- ML Kit: Handles everything else"
echo "- Result: Clean, unambiguous translation pairs"