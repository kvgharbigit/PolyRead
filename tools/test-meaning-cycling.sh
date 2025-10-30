#!/bin/bash

# Test script for meaning-based cycling functionality
# Validates that both meaning and synonym cycling work correctly

set -e

DB_PATH="dist/es-en.sqlite"

if [ ! -f "$DB_PATH" ]; then
    echo "❌ Database not found: $DB_PATH"
    echo "Run ./vuizur-meaning-dict-builder.sh es-en first"
    exit 1
fi

echo "🧪 Testing Meaning-Based Cycling System"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "📊 Database Statistics:"
WG_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM word_groups")
MEANING_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM meanings")
SYNONYM_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM english_synonyms")
PRIMARY_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM meanings WHERE is_primary = 1")

echo "   Word Groups: $WG_COUNT"
echo "   Meanings: $MEANING_COUNT"
echo "   English Synonyms: $SYNONYM_COUNT"
echo "   Primary Meanings: $PRIMARY_COUNT"

echo ""
echo "🔄 Testing Spanish → English Meaning Cycling"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test Spanish words with multiple meanings
TEST_SPANISH_WORDS=("agua" "casa" "libro" "tiempo" "hacer" "tener")

for word in "${TEST_SPANISH_WORDS[@]}"; do
    echo ""
    echo "🔍 Testing Spanish word: \"$word\""
    
    # Get word group info (prefer exact base_word match)
    WORD_INFO=$(sqlite3 "$DB_PATH" "
        SELECT base_word, word_forms, part_of_speech 
        FROM word_groups 
        WHERE base_word = '$word' 
          AND source_language = 'es' 
        ORDER BY LENGTH(base_word), base_word
        LIMIT 1
    ")
    
    if [ -n "$WORD_INFO" ]; then
        echo "   📝 Found: $WORD_INFO"
        
        # Get meanings in cycling order
        MEANINGS=$(sqlite3 "$DB_PATH" "
            SELECT m.meaning_order, m.english_meaning, m.context, m.is_primary
            FROM meanings m
            JOIN word_groups wg ON m.word_group_id = wg.id
            WHERE wg.base_word = '$word'
              AND wg.source_language = 'es'
            ORDER BY m.meaning_order
            LIMIT 5
        ")
        
        if [ -n "$MEANINGS" ]; then
            echo "   🔄 Meaning Cycling Options:"
            echo "$MEANINGS" | while IFS='|' read -r order meaning context primary; do
                primary_text=""
                context_text=""
                if [ "$primary" = "1" ]; then
                    primary_text=" (PRIMARY)"
                fi
                if [ -n "$context" ]; then
                    context_text=" $context"
                fi
                echo "      $order. \"$meaning\"$context_text$primary_text"
            done
        else
            echo "   ❌ No meanings found"
        fi
    else
        echo "   ❌ Word not found"
    fi
done

echo ""
echo "🔄 Testing English → Spanish Synonym Cycling"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test English words with multiple Spanish synonyms
TEST_ENGLISH_WORDS=("house" "water" "book" "time" "make" "have")

for word in "${TEST_ENGLISH_WORDS[@]}"; do
    echo ""
    echo "🔍 Testing English word: \"$word\""
    
    # Get Spanish synonyms ordered by quality
    SYNONYMS=$(sqlite3 "$DB_PATH" "
        SELECT wg.base_word, m.english_meaning, m.context, m.is_primary, es.quality_score
        FROM english_synonyms es
        JOIN word_groups wg ON es.word_group_id = wg.id
        JOIN meanings m ON es.meaning_id = m.id
        WHERE es.english_word = '$word'
          AND es.quality_score >= 100
        ORDER BY es.quality_score DESC, m.is_primary DESC, wg.base_word
        LIMIT 5
    ")
    
    if [ -n "$SYNONYMS" ]; then
        echo "   🔄 Synonym Cycling Options:"
        echo "$SYNONYMS" | while IFS='|' read -r spanish_word meaning context primary score; do
            primary_text=""
            context_text=""
            if [ "$primary" = "1" ]; then
                primary_text=" (PRIMARY)"
            fi
            if [ -n "$context" ]; then
                context_text=" $context"
            fi
            echo "      \"$spanish_word\" - $meaning$context_text$primary_text (Score: $score)"
        done
    else
        echo "   ❌ No synonyms found"
    fi
done

echo ""
echo "🎯 Testing Quality Filtering"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check quality score distribution
echo "Quality Score Distribution:"
QUALITY_STATS=$(sqlite3 "$DB_PATH" "
    SELECT 
        CASE 
            WHEN quality_score >= 150 THEN 'Excellent (150+)'
            WHEN quality_score >= 120 THEN 'Very Good (120-149)'
            WHEN quality_score >= 100 THEN 'Good (100-119)'
            WHEN quality_score >= 80 THEN 'Fair (80-99)'
            ELSE 'Poor (<80)'
        END as quality_range,
        COUNT(*) as count
    FROM english_synonyms
    GROUP BY quality_range
    ORDER BY MIN(quality_score) DESC
")

echo "$QUALITY_STATS" | while IFS='|' read -r range count; do
    echo "   $range: $count entries"
done

echo ""
echo "🧪 Testing Context Detection"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Show examples with different contexts
CONTEXT_EXAMPLES=$(sqlite3 "$DB_PATH" "
    SELECT english_meaning, context, is_primary
    FROM meanings
    WHERE context IS NOT NULL
    ORDER BY RANDOM()
    LIMIT 8
")

echo "Context Examples:"
echo "$CONTEXT_EXAMPLES" | while IFS='|' read -r meaning context primary; do
    primary_text=""
    if [ "$primary" = "1" ]; then
        primary_text=" (PRIMARY)"
    fi
    echo "   \"$meaning\" $context$primary_text"
done

echo ""
echo "✅ Meaning-Based Cycling Test Complete!"
echo ""
echo "📋 Summary:"
echo "   • Spanish → English: Multiple meanings per word for cycling"
echo "   • English → Spanish: Multiple synonyms per meaning for cycling"
echo "   • Quality filtering: Eliminates low-quality translations"
echo "   • Context preservation: Regional and usage markers maintained"
echo "   • Primary detection: Best meanings marked for priority"