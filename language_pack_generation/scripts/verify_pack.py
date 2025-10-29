#!/usr/bin/env python3
"""
Comprehensive Language Pack Verification
Standalone verification script for individual language packs
"""

import sqlite3
import argparse
import sys
from pathlib import Path
from typing import Dict, Optional

# Minimum entry thresholds by language
MINIMUM_THRESHOLDS = {
    'de-en': 15000,   # German
    'es-en': 12000,   # Spanish  
    'fr-en': 30000,   # French
    'it-en': 25000,   # Italian
    'pt-en': 10000,   # Portuguese
    'ru-en': 22500,   # Russian
    'ja-en': 15000,   # Japanese
    'ko-en': 7500,    # Korean
    'zh-en': 20000,   # Chinese
    'ar-en': 10000,   # Arabic
    'hi-en': 7500     # Hindi
}

def verify_pack_structure(db_path: Path, language_id: str) -> bool:
    """Verify pack has correct bidirectional structure"""
    print(f"🔍 VERIFYING {language_id.upper()} PACK")
    print("=" * 50)
    
    if not db_path.exists():
        print(f"❌ Database not found: {db_path}")
        return False
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        # Check schema
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = [row[0] for row in cursor.fetchall()]
        
        required_tables = {'dictionary_entries', 'pack_metadata'}
        has_required = required_tables.issubset(set(tables))
        
        print(f"📋 Tables: {tables}")
        print(f"✅ Required tables: {'Yes' if has_required else 'No'}")
        
        if not has_required:
            print(f"❌ Missing tables: {required_tables - set(tables)}")
            return False
        
        # Check columns
        cursor.execute("PRAGMA table_info(dictionary_entries)")
        columns = {row[1]: row[2] for row in cursor.fetchall()}
        
        required_columns = {
            'id': 'INTEGER',
            'lemma': 'TEXT',
            'definition': 'TEXT',
            'direction': 'TEXT',
            'source_language': 'TEXT',
            'target_language': 'TEXT'
        }
        
        missing_columns = set(required_columns.keys()) - set(columns.keys())
        if missing_columns:
            print(f"❌ Missing columns: {missing_columns}")
            return False
        
        print(f"✅ Schema: All required columns present")
        
        # Check data counts
        cursor.execute("SELECT COUNT(*) FROM dictionary_entries")
        total_entries = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE direction = 'forward'")
        forward_entries = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE direction = 'reverse'")
        reverse_entries = cursor.fetchone()[0]
        
        print(f"📊 Total entries: {total_entries:,}")
        print(f"📊 Forward entries: {forward_entries:,}")
        print(f"📊 Reverse entries: {reverse_entries:,}")
        
        # Check minimum threshold
        threshold = MINIMUM_THRESHOLDS.get(language_id, 5000)
        meets_threshold = total_entries >= threshold
        print(f"📊 Meets threshold ({threshold:,}): {'Yes' if meets_threshold else 'No'}")
        
        # Check metadata
        cursor.execute("SELECT key, value FROM pack_metadata")
        metadata = dict(cursor.fetchall())
        
        print(f"📋 Metadata:")
        for key, value in metadata.items():
            print(f"    {key}: {value}")
        
        # Test lookup functionality
        print(f"\n🔄 Testing bidirectional lookups...")
        
        # Get sample words
        cursor.execute("SELECT lemma, definition FROM dictionary_entries WHERE direction = 'forward' LIMIT 3")
        forward_samples = cursor.fetchall()
        
        cursor.execute("SELECT lemma, definition FROM dictionary_entries WHERE direction = 'reverse' LIMIT 3")
        reverse_samples = cursor.fetchall()
        
        print(f"✅ Forward samples: {len(forward_samples)}")
        for lemma, definition in forward_samples:
            def_preview = definition[:50] + "..." if len(definition) > 50 else definition
            print(f"    {lemma} → {def_preview}")
        
        print(f"✅ Reverse samples: {len(reverse_samples)}")
        for lemma, definition in reverse_samples:
            def_preview = definition[:30] + "..." if len(definition) > 30 else definition
            print(f"    {lemma} → {def_preview}")
        
        # Test app-style lookup
        if forward_samples:
            test_word = forward_samples[0][0]
            cursor.execute("""
                SELECT lemma, definition FROM dictionary_entries 
                WHERE LOWER(lemma) = LOWER(?) AND direction = 'forward'
                LIMIT 1
            """, (test_word,))
            
            forward_result = cursor.fetchone()
            print(f"🎯 Lookup test for '{test_word}': {'✅ Found' if forward_result else '❌ Not found'}")
        
        # Verify constraints and integrity
        cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE direction NOT IN ('forward', 'reverse')")
        invalid_directions = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE lemma IS NULL OR definition IS NULL")
        null_entries = cursor.fetchone()[0]
        
        print(f"\n🔍 Data integrity:")
        print(f"✅ Invalid directions: {invalid_directions} (should be 0)")
        print(f"✅ NULL entries: {null_entries} (should be 0)")
        
        success = (has_required and not missing_columns and meets_threshold 
                  and forward_entries > 0 and reverse_entries > 0 
                  and invalid_directions == 0 and null_entries == 0)
        
        return success
        
    finally:
        conn.close()

def main():
    parser = argparse.ArgumentParser(description="Verify language pack")
    parser.add_argument("language_id", help="Language ID (e.g., pt-en)")
    parser.add_argument("--db-path", help="Custom database path")
    
    args = parser.parse_args()
    
    # Determine database path
    if args.db_path:
        db_path = Path(args.db_path)
    else:
        # Try common locations
        base_dir = Path(__file__).parent.parent
        temp_path = base_dir / "temp" / args.language_id / f"{args.language_id}.sqlite"
        completed_path = base_dir / "completed_packs" / f"{args.language_id}.sqlite"
        assets_path = Path.cwd() / "assets" / "language_packs" / f"{args.language_id}.sqlite"
        
        for path in [temp_path, completed_path, assets_path]:
            if path.exists():
                db_path = path
                break
        else:
            print(f"❌ Database not found for {args.language_id}")
            print(f"Searched: {temp_path}, {completed_path}, {assets_path}")
            return 1
    
    print(f"📁 Using database: {db_path}")
    
    if verify_pack_structure(db_path, args.language_id):
        print(f"\n🎉 {args.language_id.upper()} VERIFICATION PASSED")
        print("✅ Pack is ready for deployment")
        return 0
    else:
        print(f"\n❌ {args.language_id.upper()} VERIFICATION FAILED")
        print("❌ Pack needs fixes before deployment")
        return 1

if __name__ == "__main__":
    exit(main())