#!/bin/bash

# STRICT Match Test - Conservative filtering, prefer ML Kit over garbage
# Only accept high-quality exact matches, reject everything else

set -e

DB_FILE="/Users/kayvangharbi/PycharmProjects/PolyRead/tools/es-en.db"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test words
ENGLISH_TEST_WORDS=("house" "water" "good" "red" "eat" "sleep" "work" "family" "book" "table" "big" "love" "time")

echo -e "${BLUE}🔒 STRICT QUALITY FILTER TEST${NC}"
echo "Conservative approach: High quality matches only, ML Kit for everything else"
echo ""

# Function to check if a match is high quality
is_high_quality_match() {
    local english_word="$1"
    local spanish_word="$2"
    local definition="$3"
    
    # Reject if Spanish word is too short (likely abbreviation)
    if [[ ${#spanish_word} -lt 3 ]]; then
        echo "REJECT: Too short ($spanish_word)"
        return 1
    fi
    
    # Reject if contains archaic
    if echo "$definition" | grep -qi "archaic"; then
        echo "REJECT: Archaic term"
        return 1
    fi
    
    # Reject if contains slang/colloquial unless it's very common
    if echo "$definition" | grep -qi "slang\|colloquial" && [[ ${#spanish_word} -gt 6 ]]; then
        echo "REJECT: Slang/colloquial"
        return 1
    fi
    
    # Reject if it's a title or proper reference
    if echo "$definition" | grep -qi "title of\|lady of\|lord of"; then
        echo "REJECT: Title/reference"
        return 1
    fi
    
    # Reject if English word only appears in parenthetical explanation
    if echo "$definition" | grep -o "<li>[^<]*</li>" | grep -v "($english_word" | grep -qw "$english_word"; then
        # Good - word appears in main definition
        :
    else
        echo "REJECT: Only in parenthetical"
        return 1
    fi
    
    # Accept if we got this far
    echo "ACCEPT: High quality"
    return 0
}

successful=0
total=0
ml_kit_needed=0

for english_word in "${ENGLISH_TEST_WORDS[@]}"; do
    total=$((total + 1))
    echo -e "${YELLOW}Testing '$english_word'...${NC}"
    
    # Get potential matches with strict patterns
    results=$(sqlite3 "$DB_FILE" "
        SELECT written_rep, trans_list 
        FROM dictionary_entries 
        WHERE source_language = 'es' 
          AND target_language = 'en'
          AND (
            trans_list LIKE '%<li>$english_word</li>%' OR
            trans_list LIKE '%<li>$english_word (%' OR
            trans_list LIKE '%<li>to $english_word</li>%'
          )
          AND length(written_rep) <= 10
          AND length(written_rep) >= 3
          AND written_rep NOT LIKE '%í'
          AND written_rep NOT LIKE '%é' 
          AND written_rep NOT LIKE '%ó'
          AND written_rep NOT LIKE '%.%'  -- No abbreviations
        ORDER BY 
          CASE 
            WHEN trans_list LIKE '%<i>noun</i>%' THEN 1
            WHEN trans_list LIKE '%<i>adj</i>%' THEN 2  
            WHEN trans_list LIKE '%<i>verb</i>%' THEN 3
            ELSE 4
          END,
          length(written_rep)
        LIMIT 5;
    ")
    
    if [[ -n "$results" ]]; then
        quality_matches=()
        
        while IFS='|' read -r spanish_word definition; do
            echo -n "  Evaluating '$spanish_word': "
            if is_high_quality_match "$english_word" "$spanish_word" "$definition"; then
                quality_matches+=("$spanish_word|$definition")
            fi
        done <<< "$results"
        
        if [[ ${#quality_matches[@]} -gt 0 ]]; then
            echo -e "  ${GREEN}✅ HIGH QUALITY MATCHES FOUND${NC}"
            for match in "${quality_matches[@]}"; do
                IFS='|' read -r spanish_word definition <<< "$match"
                clean_def=$(echo "$definition" | sed 's/<[^>]*>//g' | cut -c1-60)
                echo "    $english_word → '$spanish_word' ($clean_def)"
            done
            successful=$((successful + 1))
        else
            echo -e "  ${YELLOW}⚠️  NO QUALITY MATCHES - FALLBACK TO ML KIT${NC}"
            ml_kit_needed=$((ml_kit_needed + 1))
        fi
    else
        echo -e "  ${YELLOW}⚠️  NO MATCHES FOUND - FALLBACK TO ML KIT${NC}"
        ml_kit_needed=$((ml_kit_needed + 1))
    fi
    echo ""
done

echo -e "${BLUE}📊 STRICT QUALITY RESULTS${NC}"
echo "================================================="
echo "High-quality dictionary matches: $successful/$total"
echo "ML Kit fallback needed: $ml_kit_needed/$total"

quality_rate=$((successful * 100 / total))
fallback_rate=$((ml_kit_needed * 100 / total))

echo ""
echo "Quality match rate: ${quality_rate}%"
echo "ML Kit fallback rate: ${fallback_rate}%"

echo ""
if [[ $quality_rate -ge 50 ]]; then
    echo -e "${GREEN}✅ EXCELLENT: Good balance of quality vs coverage${NC}"
    echo "Dictionary provides high-quality matches, ML Kit handles edge cases"
elif [[ $quality_rate -ge 30 ]]; then
    echo -e "${YELLOW}⚠️  GOOD: Conservative but reliable${NC}"
    echo "Few but high-quality dictionary matches, ML Kit does heavy lifting"
else
    echo -e "${YELLOW}⚠️  CONSERVATIVE: Very strict filtering${NC}"
    echo "Most words use ML Kit, but dictionary matches are excellent quality"
fi

echo ""
echo -e "${BLUE}💡 STRATEGY: Tight dictionary + ML Kit fallback${NC}"
echo "- Dictionary: Only perfect, common, non-archaic matches"
echo "- ML Kit: Everything else (slang, archaic, complex cases)"
echo "- Result: Clean, reliable translation experience"