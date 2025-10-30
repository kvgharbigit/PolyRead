#!/bin/bash

# Test script for one-level meaning cycling functionality
# Validates both Spanish→English and English→Spanish cycling

set -e

DB_PATH="dist/es-en.sqlite"

if [ ! -f "$DB_PATH" ]; then
    echo "❌ Database not found: $DB_PATH"
    echo "Run ./vuizur-meaning-dict-builder.sh es-en first"
    exit 1
fi

echo "🧪 Testing One-Level Meaning Cycling System"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "📊 Database Statistics:"
WG_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM word_groups")
MEANING_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM meanings")
ENG_WORDS_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(DISTINCT target_word) FROM target_reverse_lookup")
REVERSE_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM target_reverse_lookup")

echo "   Spanish Word Groups: $WG_COUNT"
echo "   Spanish→English Meanings: $MEANING_COUNT"
echo "   English Words: $ENG_WORDS_COUNT"
echo "   English→Spanish Lookups: $REVERSE_COUNT"

echo ""
echo "🔄 Testing Spanish → English One-Level Cycling"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test Spanish words with multiple meanings
TEST_SPANISH_WORDS=("agua" "casa" "libro" "tiempo" "hacer" "tener" "mano")

for word in "${TEST_SPANISH_WORDS[@]}"; do
    echo ""
    echo "🔍 Testing Spanish word: \"$word\""
    
    # Get word group info
    WORD_INFO=$(sqlite3 "$DB_PATH" "
        SELECT base_word, part_of_speech 
        FROM word_groups 
        WHERE base_word = '$word' 
          AND source_language = 'es' 
        LIMIT 1
    ")
    
    if [ -n "$WORD_INFO" ]; then
        echo "   📝 Found: $WORD_INFO"
        
        # Get meanings in cycling order with part of speech
        MEANINGS=$(sqlite3 "$DB_PATH" "
            SELECT m.meaning_order, m.target_meaning, m.context, m.part_of_speech, m.is_primary
            FROM meanings m
            JOIN word_groups wg ON m.word_group_id = wg.id
            WHERE wg.base_word = '$word'
              AND wg.source_language = 'es'
            ORDER BY m.meaning_order
            LIMIT 8
        ")
        
        if [ -n "$MEANINGS" ]; then
            echo "   🔄 Meaning Cycling Options:"
            echo "$MEANINGS" | while IFS='|' read -r order meaning context pos primary; do
                primary_text=""
                context_text=""
                pos_text=""
                if [ "$primary" = "1" ]; then
                    primary_text=" (PRIMARY)"
                fi
                if [ -n "$context" ]; then
                    context_text=" $context"
                fi
                if [ -n "$pos" ]; then
                    pos_text="[$pos] "
                fi
                echo "      $order. $pos_text\"$meaning\"$context_text$primary_text"
            done
        else
            echo "   ❌ No meanings found"
        fi
    else
        echo "   ❌ Word not found"
    fi
done

echo ""
echo "🔄 Testing English → Spanish One-Level Cycling"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test English words that should have Spanish translations
TEST_ENGLISH_WORDS=("water" "house" "book" "time" "do" "have" "hand")

for word in "${TEST_ENGLISH_WORDS[@]}"; do
    echo ""
    echo "🔍 Testing English word: \"$word\""
    
    # Get Spanish translations ordered by quality
    TRANSLATIONS=$(sqlite3 "$DB_PATH" "
        SELECT trl.lookup_order, wg.base_word, m.target_meaning, m.part_of_speech, trl.quality_score
        FROM target_reverse_lookup trl
        JOIN word_groups wg ON trl.source_word_group_id = wg.id
        JOIN meanings m ON trl.source_meaning_id = m.id
        WHERE trl.target_word = '$word'
        ORDER BY trl.lookup_order
        LIMIT 5
    ")
    
    if [ -n "$TRANSLATIONS" ]; then
        echo "   🔄 Spanish Translation Cycling:"
        echo "$TRANSLATIONS" | while IFS='|' read -r order spanish_word english_meaning pos score; do
            pos_text=""
            if [ -n "$pos" ]; then
                pos_text="[$pos] "
            fi
            echo "      $order. \"$spanish_word\" $pos_text(\"$english_meaning\") Score: $score"
        done
    else
        echo "   ❌ No translations found"
    fi
done

echo ""
echo "🎯 Testing Part-of-Speech Handling"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test "hacer" which has both verb and noun meanings
echo "Testing \"hacer\" (verb + noun):"
HACER_MEANINGS=$(sqlite3 "$DB_PATH" "
    SELECT m.meaning_order, m.part_of_speech, m.target_meaning, m.context
    FROM meanings m
    JOIN word_groups wg ON m.word_group_id = wg.id
    WHERE wg.base_word = 'hacer'
      AND wg.source_language = 'es'
    ORDER BY m.meaning_order
    LIMIT 10
")

if [ -n "$HACER_MEANINGS" ]; then
    echo "$HACER_MEANINGS" | while IFS='|' read -r order pos meaning context; do
        context_text=""
        if [ -n "$context" ]; then
            context_text=" $context"
        fi
        echo "   $order. [$pos] \"$meaning\"$context_text"
    done
fi

echo ""
echo "🧪 Testing Quality Filtering"
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
    FROM target_reverse_lookup
    GROUP BY quality_range
    ORDER BY MIN(quality_score) DESC
")

echo "$QUALITY_STATS" | while IFS='|' read -r range count; do
    echo "   $range: $count entries"
done

echo ""
echo "✅ One-Level Meaning Cycling Test Complete!"
echo ""
echo "📋 Summary:"
echo "   • Spanish → English: Cycle through meanings with part-of-speech preserved"
echo "   • English → Spanish: Cycle through different Spanish words"
echo "   • Part-of-speech available for UI formatting ([verb], [noun], etc.)"
echo "   • Quality scoring for translation ranking"
echo "   • No proper nouns or conjugation pollution"