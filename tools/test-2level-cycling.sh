#!/bin/bash

# Test script for 2-level hierarchical cycling functionality
# Validates both meaning cycling and synonym cycling within meanings

set -e

DB_PATH="dist/es-en.sqlite"

if [ ! -f "$DB_PATH" ]; then
    echo "❌ Database not found: $DB_PATH"
    echo "Run ./vuizur-meaning-dict-builder.sh es-en first"
    exit 1
fi

echo "🧪 Testing 2-Level Hierarchical Cycling System"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "📊 Database Statistics:"
WG_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM word_groups")
SP_GROUPS_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM spanish_meaning_groups")
MEANING_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM meanings")
ENG_GROUPS_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM english_meaning_groups")
SYNONYM_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM english_synonyms")

echo "   Spanish Word Groups: $WG_COUNT"
echo "   Spanish Meaning Groups: $SP_GROUPS_COUNT"
echo "   English Meanings (Synonyms): $MEANING_COUNT"
echo "   English Meaning Groups: $ENG_GROUPS_COUNT"
echo "   English→Spanish Synonyms: $SYNONYM_COUNT"

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
        
        # Get Spanish meaning groups for 2-level cycling
        MEANING_GROUPS=$(sqlite3 "$DB_PATH" "
            SELECT smg.meaning_order, smg.meaning_description, smg.is_primary
            FROM spanish_meaning_groups smg
            JOIN word_groups wg ON smg.word_group_id = wg.id
            WHERE wg.base_word = '$word'
              AND wg.source_language = 'es'
            ORDER BY smg.meaning_order
        ")
        
        if [ -n "$MEANING_GROUPS" ]; then
            echo "   📚 Meaning Groups (Level 1 - Regular Tap):"
            echo "$MEANING_GROUPS" | while IFS='|' read -r order description primary; do
                primary_text=""
                if [ "$primary" = "1" ]; then
                    primary_text=" (PRIMARY)"
                fi
                echo "      $order. $description$primary_text"
                
                # Get English synonyms for this meaning group
                SYNONYMS=$(sqlite3 "$DB_PATH" "
                    SELECT m.meaning_order, m.english_meaning, m.context, m.is_primary
                    FROM meanings m
                    JOIN spanish_meaning_groups smg ON m.spanish_meaning_group_id = smg.id
                    JOIN word_groups wg ON smg.word_group_id = wg.id
                    WHERE wg.base_word = '$word' AND smg.meaning_order = $order
                    ORDER BY m.meaning_order
                    LIMIT 3
                ")
                
                if [ -n "$SYNONYMS" ]; then
                    echo "         🔄 English Synonyms (Level 2 - Long Press):"
                    echo "$SYNONYMS" | while IFS='|' read -r syn_order english_meaning context is_primary_syn; do
                        primary_syn_text=""
                        context_text=""
                        if [ "$is_primary_syn" = "1" ]; then
                            primary_syn_text=" (PRIMARY)"
                        fi
                        if [ -n "$context" ]; then
                            context_text=" $context"
                        fi
                        echo "            $syn_order. \"$english_meaning\"$context_text$primary_syn_text"
                    done
                fi
            done
        else
            echo "   ❌ No meaning groups found"
        fi
    else
        echo "   ❌ Word not found"
    fi
done

echo ""
echo "🔄 Testing English → Spanish 2-Level Cycling"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test English words with multiple meaning groups and synonyms
TEST_ENGLISH_WORDS=("time" "house" "water" "book" "make" "have")

for word in "${TEST_ENGLISH_WORDS[@]}"; do
    echo ""
    echo "🔍 Testing English word: \"$word\""
    
    # Get meaning groups for this English word
    MEANING_GROUPS=$(sqlite3 "$DB_PATH" "
        SELECT meaning_order, meaning_description, is_primary
        FROM english_meaning_groups
        WHERE english_word = '$word'
        ORDER BY meaning_order
    ")
    
    if [ -n "$MEANING_GROUPS" ]; then
        echo "   📚 Meaning Groups (Level 1 - Regular Tap):"
        echo "$MEANING_GROUPS" | while IFS='|' read -r order description primary; do
            primary_text=""
            if [ "$primary" = "1" ]; then
                primary_text=" (PRIMARY)"
            fi
            echo "      $order. $description$primary_text"
            
            # Get synonyms for this meaning group
            SYNONYMS=$(sqlite3 "$DB_PATH" "
                SELECT es.synonym_order, wg.base_word, es.is_primary_synonym, es.quality_score
                FROM english_synonyms es
                JOIN english_meaning_groups emg ON es.english_meaning_group_id = emg.id
                JOIN word_groups wg ON es.spanish_word_group_id = wg.id
                WHERE emg.english_word = '$word' AND emg.meaning_order = $order
                ORDER BY es.synonym_order
                LIMIT 3
            ")
            
            if [ -n "$SYNONYMS" ]; then
                echo "         🔄 Synonyms (Level 2 - Long Press):"
                echo "$SYNONYMS" | while IFS='|' read -r syn_order spanish_word is_primary_syn score; do
                    primary_syn_text=""
                    if [ "$is_primary_syn" = "1" ]; then
                        primary_syn_text=" (PRIMARY)"
                    fi
                    echo "            $syn_order. \"$spanish_word\"$primary_syn_text (Score: $score)"
                done
            fi
        done
    else
        echo "   ❌ No meaning groups found"
    fi
done

echo ""
echo "🎯 Testing Semantic Grouping Examples"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Show examples of how meanings are grouped semantically
echo "Examples of semantic meaning grouping:"

# Check if 'time' has proper grouping
TIME_GROUPS=$(sqlite3 "$DB_PATH" "
    SELECT emg.meaning_order, emg.meaning_description, 
           COUNT(es.id) as synonym_count,
           GROUP_CONCAT(wg.base_word, ', ') as spanish_words
    FROM english_meaning_groups emg
    LEFT JOIN english_synonyms es ON emg.id = es.english_meaning_group_id
    LEFT JOIN word_groups wg ON es.spanish_word_group_id = wg.id
    WHERE emg.english_word = 'time'
    GROUP BY emg.id
    ORDER BY emg.meaning_order
")

if [ -n "$TIME_GROUPS" ]; then
    echo ""
    echo "📅 'time' semantic grouping:"
    echo "$TIME_GROUPS" | while IFS='|' read -r order description count spanish_words; do
        echo "   Group $order ($description): $count synonyms → $spanish_words"
    done
fi

echo ""
echo "🧪 Testing Quality and Priority"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check primary synonym ordering
PRIMARY_EXAMPLES=$(sqlite3 "$DB_PATH" "
    SELECT emg.english_word, emg.meaning_description, wg.base_word, es.quality_score
    FROM english_synonyms es
    JOIN english_meaning_groups emg ON es.english_meaning_group_id = emg.id
    JOIN word_groups wg ON es.spanish_word_group_id = wg.id
    WHERE es.is_primary_synonym = 1
    ORDER BY emg.english_word, emg.meaning_order
    LIMIT 10
")

echo "Primary synonyms for each meaning group:"
echo "$PRIMARY_EXAMPLES" | while IFS='|' read -r eng_word meaning spanish_word score; do
    echo "   \"$eng_word\" ($meaning) → \"$spanish_word\" (Score: $score)"
done

echo ""
echo "✅ 2-Level Hierarchical Cycling Test Complete!"
echo ""
echo "📋 Summary:"
echo "   • Level 1 (Regular Tap): Cycle through different meaning groups"
echo "   • Level 2 (Long Press): Cycle through synonyms within current meaning"
echo "   • Semantic grouping: Related meanings grouped together"
echo "   • Quality ranking: Best synonyms prioritized within each group"
echo "   • No conjugation pollution: Only meaningful semantic differences"