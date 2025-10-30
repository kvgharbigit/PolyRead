#!/bin/bash

# Bidirectional Cycling Test - Tests both Spanish→English and English→Spanish
# Validates that we get multiple meaningful synonyms for cycling in both directions

set -e

DB_FILE="/Users/kayvangharbi/PycharmProjects/PolyRead/tools/es-en.db"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Diverse test word sets
SPANISH_TEST_WORDS=("casa" "agua" "comer" "bueno" "grande" "trabajar" "libro" "mesa" "familia" "amor" "tiempo" "vida" "mano" "ojo" "corazón")
ENGLISH_TEST_WORDS=("house" "water" "eat" "good" "big" "work" "book" "table" "family" "love" "time" "life" "hand" "eye" "heart")

echo -e "${BLUE}🔄 BIDIRECTIONAL CYCLING TEST${NC}"
echo "Testing quality and variety of synonyms for UI cycling"
echo "Database: $DB_FILE"
echo ""

# Function to clean HTML and extract meanings
extract_meanings() {
    local html="$1"
    echo "$html" | sed 's/<[^>]*>//g' | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-80
}

# Function to check word quality (not proper noun, reasonable length)
is_good_word() {
    local word="$1"
    
    # Reject proper nouns (start with capital)
    if [[ "$word" =~ ^[A-Z] ]]; then
        return 1
    fi
    
    # Reject very long compound words
    if [[ ${#word} -gt 15 ]]; then
        return 1
    fi
    
    # Reject words with too many spaces
    local word_count=$(echo "$word" | wc -w)
    if [[ $word_count -gt 2 ]]; then
        return 1
    fi
    
    return 0
}

# Test 1: Spanish → English Cycling
echo -e "${CYAN}━━━ TEST 1: SPANISH → ENGLISH CYCLING ━━━${NC}"
echo "Testing: Fixed Spanish word, cycle through English synonyms"
echo ""

spanish_success=0
spanish_total=0

for spanish_word in "${SPANISH_TEST_WORDS[@]}"; do
    spanish_total=$((spanish_total + 1))
    echo -e "${YELLOW}Testing Spanish word: '$spanish_word'${NC}"
    
    # Find English translations
    results=$(sqlite3 "$DB_FILE" "
        SELECT written_rep, trans_list 
        FROM dictionary_entries 
        WHERE source_language = 'es' 
          AND target_language = 'en'
          AND written_rep = '$spanish_word'
        LIMIT 1;
    ")
    
    if [[ -n "$results" ]]; then
        while IFS='|' read -r spanish trans_html; do
            # Extract individual English meanings from HTML
            meanings=$(echo "$trans_html" | grep -o '<li>[^<]*' | sed 's/<li>//' | head -5)
            
            if [[ -n "$meanings" ]]; then
                echo -e "  ${GREEN}✓ CYCLING OPTIONS FOUND:${NC}"
                count=1
                echo "$meanings" | while read -r meaning; do
                    clean_meaning=$(echo "$meaning" | sed 's/([^)]*)//g' | sed 's/  */ /g' | cut -c1-40)
                    echo "    Cycle $count: $spanish_word → \"$clean_meaning\""
                    count=$((count + 1))
                done
                spanish_success=$((spanish_success + 1))
            else
                echo -e "  ${RED}✗ NO CYCLING OPTIONS${NC}"
            fi
        done <<< "$results"
    else
        echo -e "  ${RED}✗ WORD NOT FOUND${NC}"
    fi
    echo ""
done

# Test 2: English → Spanish Cycling  
echo -e "${CYAN}━━━ TEST 2: ENGLISH → SPANISH CYCLING ━━━${NC}"
echo "Testing: Fixed English word, cycle through Spanish synonyms"
echo ""

english_success=0
english_total=0

for english_word in "${ENGLISH_TEST_WORDS[@]}"; do
    english_total=$((english_total + 1))
    echo -e "${YELLOW}Testing English word: '$english_word'${NC}"
    
    # Find Spanish words that translate to this English word
    # Improved patterns + part-of-speech priority + conjugation filtering
    results=$(sqlite3 "$DB_FILE" "
        SELECT DISTINCT written_rep, trans_list 
        FROM dictionary_entries 
        WHERE source_language = 'es' 
          AND target_language = 'en'
          AND (
            trans_list LIKE '%<li>$english_word</li>%' OR 
            trans_list LIKE '%<li>$english_word (%' OR
            trans_list LIKE '%<li>to $english_word</li>%' OR
            trans_list LIKE '%<li>(intransitive) to $english_word</li>%' OR
            trans_list LIKE '%<li>(transitive) to $english_word</li>%' OR
            trans_list LIKE '%) $english_word,%' OR
            trans_list LIKE '%) $english_word</li>%' OR
            trans_list LIKE '%$english_word, %'
          )
          AND length(written_rep) <= 12
          AND written_rep NOT LIKE '%í'   -- Filter conjugations
          AND written_rep NOT LIKE '%é'   -- Filter conjugations
          AND written_rep NOT LIKE '%ó'   -- Filter conjugations
        ORDER BY 
          -- Prioritize nouns/adjectives over verbs
          CASE 
            WHEN trans_list LIKE '%<i>noun</i>%' THEN 1
            WHEN trans_list LIKE '%<i>adj</i>%' THEN 2  
            WHEN trans_list LIKE '%<i>verb</i>%' THEN 3
            ELSE 4
          END,
          -- Then prefer shorter base forms (avoid plurals/diminutives)
          length(written_rep),
          -- Then alphabetical
          written_rep
        LIMIT 8;
    ")
    
    if [[ -n "$results" ]]; then
        good_words=()
        
        while IFS='|' read -r spanish_word spanish_def; do
            if is_good_word "$spanish_word"; then
                good_words+=("$spanish_word|$spanish_def")
            fi
        done <<< "$results"
        
        if [[ ${#good_words[@]} -gt 0 ]]; then
            echo -e "  ${GREEN}✓ CYCLING OPTIONS FOUND:${NC}"
            count=1
            for entry in "${good_words[@]}"; do
                IFS='|' read -r spanish_word spanish_def <<< "$entry"
                clean_context=$(extract_meanings "$spanish_def")
                echo "    Cycle $count: $english_word → '$spanish_word' ($clean_context)"
                count=$((count + 1))
                if [[ $count -gt 4 ]]; then break; fi
            done
            english_success=$((english_success + 1))
        else
            echo -e "  ${RED}✗ NO QUALITY CYCLING OPTIONS${NC}"
        fi
    else
        echo -e "  ${RED}✗ NO MATCHES FOUND${NC}"
    fi
    echo ""
done

# Summary and Quality Assessment
echo -e "${BLUE}━━━ QUALITATIVE ASSESSMENT ━━━${NC}"
echo ""

spanish_rate=$((spanish_success * 100 / spanish_total))
english_rate=$((english_success * 100 / english_total))

echo "Spanish → English cycling: $spanish_success/$spanish_total ($spanish_rate%)"
echo "English → Spanish cycling: $english_success/$english_total ($english_rate%)"
echo ""

# Overall assessment
if [[ $spanish_rate -ge 80 && $english_rate -ge 60 ]]; then
    echo -e "${GREEN}🏆 EXCELLENT: Bidirectional cycling ready for production${NC}"
    echo "- Rich synonym variety in both directions"
    echo "- Quality translations with distinct meanings"
    echo "- Good coverage of common vocabulary"
elif [[ $spanish_rate -ge 60 && $english_rate -ge 40 ]]; then
    echo -e "${YELLOW}⚠️  GOOD: Cycling works but could be improved${NC}"
    echo "- Decent synonym coverage"
    echo "- Some gaps in less common words"
elif [[ $spanish_rate -ge 40 || $english_rate -ge 30 ]]; then
    echo -e "${YELLOW}⚠️  FAIR: Basic cycling functionality${NC}"
    echo "- Limited synonym variety"
    echo "- Works for core vocabulary"
else
    echo -e "${RED}❌ POOR: Cycling needs significant work${NC}"
    echo "- Insufficient synonym coverage"
    echo "- Missing core vocabulary"
fi

echo ""
echo -e "${BLUE}📋 KEY INSIGHTS:${NC}"
echo ""

# Identify strengths
echo -e "${GREEN}✅ STRENGTHS:${NC}"
echo "- Spanish→English: Rich meaning extraction from HTML definitions"
echo "- English→Spanish: Multiple Spanish synonyms with cultural contexts"
echo "- Quality filtering removes proper nouns and complex compounds"

echo ""
echo -e "${YELLOW}💡 AREAS FOR IMPROVEMENT:${NC}"
echo "- Some verbs need better infinitive handling"
echo "- Regional variations could be better categorized"
echo "- Frequency-based ordering could improve synonym priority"

echo ""
echo -e "${CYAN}🎯 CYCLING READINESS:${NC}"
if [[ $spanish_rate -ge 70 && $english_rate -ge 50 ]]; then
    echo "✅ Ready for UI implementation"
else
    echo "⚠️  Needs refinement before UI implementation"
fi