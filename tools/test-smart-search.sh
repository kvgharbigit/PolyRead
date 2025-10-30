#!/bin/bash

# Smart Search Test - Simulates DriftDictionaryService Smart Algorithm
# Tests the improved search-based reverse lookup with quality filtering

set -e

# Configuration
DB_FILE="/Users/kayvangharbi/PycharmProjects/PolyRead/tools/es-en.db"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test word sets - words that should have good Spanish equivalents
ENGLISH_TEST_WORDS=("house" "water" "good" "red" "eat" "sleep" "work" "family" "book" "table")

echo -e "${BLUE}🧠 SMART SEARCH ALGORITHM TEST${NC}"
echo "================================================"
echo "Testing improved reverse lookup with quality filtering"
echo "Database: $DB_FILE"
echo ""

# Check if database exists
if [[ ! -f "$DB_FILE" ]]; then
    echo -e "${RED}❌ ERROR: Database not found at $DB_FILE${NC}"
    exit 1
fi

# Function to check if a word is a proper noun
is_proper_noun() {
    local word="$1"
    # Check if starts with capital letter
    if [[ "$word" =~ ^[A-Z] ]]; then
        return 0  # true
    fi
    # Check if contains multiple capitals (compound proper nouns)
    if [[ "$word" =~ [A-Z].*[A-Z] ]]; then
        return 0  # true
    fi
    return 1  # false
}

# Function to extract clean translation from HTML
extract_clean_translation() {
    local html="$1"
    local search_term="$2"
    
    # Remove HTML tags and extract first meaningful translation
    echo "$html" | sed 's/<[^>]*>//g' | sed 's/&[^;]*;//g' | \
    tr '\n' ' ' | sed 's/  */ /g' | \
    grep -i "$search_term" | head -1 | cut -c1-50
}

# Function to score translation quality
score_translation() {
    local spanish_word="$1"
    local html_definition="$2"
    local search_term="$3"
    local pos="$4"
    
    local score=0
    
    # Filter out proper nouns
    if is_proper_noun "$spanish_word"; then
        echo "0"
        return
    fi
    
    # Filter out very long compound terms
    local word_count=$(echo "$spanish_word" | wc -w)
    if [[ $word_count -gt 3 ]]; then
        echo "0"
        return
    fi
    
    # Extract clean translations
    local clean_translations=$(echo "$html_definition" | sed 's/<[^>]*>//g' | tr '\n' ' ')
    
    # Check for exact word match
    if echo "$clean_translations" | grep -q "\\b$search_term\\b"; then
        if echo "$clean_translations" | grep -q "^$search_term$" || echo "$clean_translations" | grep -q "^$search_term[^a-zA-Z]"; then
            score=$((score + 100))
        else
            score=$((score + 60))
        fi
    elif echo "$clean_translations" | grep -qi "$search_term"; then
        score=$((score + 20))
    fi
    
    # Bonus for common parts of speech
    if [[ "$pos" =~ (noun|verb|adj) ]]; then
        score=$((score + 10))
    fi
    
    # Bonus for simple Spanish words
    if [[ ${#spanish_word} -le 8 && ! "$spanish_word" =~ " " ]]; then
        score=$((score + 15))
    fi
    
    echo "$score"
}

echo -e "${BLUE}🔍 Smart English→Spanish Reverse Lookup${NC}"
echo "================================================"

successful_smart=0
total_smart=0

for word in "${ENGLISH_TEST_WORDS[@]}"; do
    total_smart=$((total_smart + 1))
    echo -n "Testing '$word'... "
    
    # Get all potential matches from FTS search
    raw_results=$(sqlite3 "$DB_FILE" "
        SELECT d.written_rep, d.trans_list, d.pos
        FROM dictionary_entries d
        WHERE d.id IN (
            SELECT rowid FROM dictionary_fts 
            WHERE dictionary_fts MATCH '$word'
        )
          AND d.source_language = 'es' 
          AND d.target_language = 'en'
        LIMIT 20;
    ")
    
    if [[ -z "$raw_results" ]]; then
        echo -e "${RED}✗ NO MATCHES${NC}"
        continue
    fi
    
    echo -e "${YELLOW}FILTERING...${NC}"
    
    # Process and score each candidate
    best_score=0
    best_spanish=""
    best_translation=""
    best_pos=""
    candidates_count=0
    
    while IFS='|' read -r spanish_word html_def pos; do
        candidates_count=$((candidates_count + 1))
        
        # Score this candidate
        quality_score=$(score_translation "$spanish_word" "$html_def" "$word" "$pos")
        
        # Extract clean translation for display
        clean_trans=$(extract_clean_translation "$html_def" "$word")
        
        echo "    Candidate: '$spanish_word' (Score: $quality_score)"
        echo "      Translation: $clean_trans"
        
        # Check if this is the best so far
        if [[ $quality_score -gt $best_score ]]; then
            best_score=$quality_score
            best_spanish="$spanish_word"
            best_translation="$clean_trans"
            best_pos="$pos"
        fi
        
        # Limit output
        if [[ $candidates_count -ge 5 ]]; then
            break
        fi
        
    done <<< "$raw_results"
    
    echo ""
    
    # Check if we found a good match (score >= 50)
    if [[ $best_score -ge 50 ]]; then
        echo -e "    ${GREEN}✓ BEST MATCH: '$word' → '$best_spanish' (Score: $best_score)${NC}"
        echo -e "    ${GREEN}  Translation: $best_translation${NC}"
        successful_smart=$((successful_smart + 1))
    else
        echo -e "    ${RED}✗ NO QUALITY MATCH (Best score: $best_score)${NC}"
    fi
    
    echo ""
done

echo ""
echo -e "${BLUE}📋 SMART ALGORITHM RESULTS${NC}"
echo "================================================"
echo "Smart filtered success rate: $successful_smart/$total_smart"

# Calculate success rate percentage
if [[ $total_smart -gt 0 ]]; then
    smart_rate=$((successful_smart * 100 / total_smart))
    echo "Success percentage: ${smart_rate}%"
    
    if [[ $smart_rate -ge 70 ]]; then
        echo -e "${GREEN}✅ EXCELLENT: Smart algorithm working well${NC}"
    elif [[ $smart_rate -ge 50 ]]; then
        echo -e "${YELLOW}⚠️  GOOD: Smart algorithm needs minor improvements${NC}"
    else
        echo -e "${RED}❌ POOR: Smart algorithm needs major improvements${NC}"
    fi
else
    echo "No tests performed"
fi

echo ""
echo "Key improvements:"
echo "- Proper nouns filtered out"
echo "- Quality scoring based on exact word matches"  
echo "- Preference for simple Spanish words"
echo "- Bonus for common parts of speech"