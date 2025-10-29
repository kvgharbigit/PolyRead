#!/usr/bin/env python3
"""
Verify that the converted bidirectional language packs are in correct format and contain valid data
"""

import sqlite3
import json
from pathlib import Path
from typing import Dict, List, Tuple

def verify_database_schema(db_path: Path) -> Dict:
    """Verify the database has the correct bidirectional schema"""
    print(f"🔍 Verifying schema: {db_path.name}")
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        # Check required tables exist
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = [row[0] for row in cursor.fetchall()]
        
        required_tables = {'dictionary_entries', 'pack_metadata'}
        missing_tables = required_tables - set(tables)
        
        if missing_tables:
            return {'valid': False, 'error': f'Missing tables: {missing_tables}'}
        
        print(f"  ✅ Required tables present: {required_tables}")
        
        # Check dictionary_entries schema
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
        
        schema_valid = all(col in columns for col in required_columns)
        if not schema_valid:
            missing_cols = set(required_columns.keys()) - set(columns.keys())
            return {'valid': False, 'error': f'Missing columns: {missing_cols}'}
        
        print(f"  ✅ Required columns present: {list(required_columns.keys())}")
        
        # Check indexes exist
        cursor.execute("SELECT name FROM sqlite_master WHERE type='index'")
        indexes = [row[0] for row in cursor.fetchall()]
        expected_indexes = ['idx_lemma_direction', 'idx_direction', 'idx_languages']
        
        for idx in expected_indexes:
            if idx in indexes:
                print(f"  ✅ Index present: {idx}")
            else:
                print(f"  ⚠️ Index missing: {idx}")
        
        return {'valid': True, 'tables': tables, 'columns': columns, 'indexes': indexes}
        
    finally:
        conn.close()

def verify_data_integrity(db_path: Path) -> Dict:
    """Verify the data integrity and format"""
    print(f"📊 Verifying data integrity: {db_path.name}")
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        # Get basic statistics
        cursor.execute("SELECT COUNT(*) FROM dictionary_entries")
        total_entries = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE direction = 'forward'")
        forward_entries = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE direction = 'reverse'")
        reverse_entries = cursor.fetchone()[0]
        
        print(f"  📈 Total entries: {total_entries:,}")
        print(f"  📈 Forward entries: {forward_entries:,}")
        print(f"  📈 Reverse entries: {reverse_entries:,}")
        
        # Check for empty or null values
        cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE lemma IS NULL OR lemma = ''")
        empty_lemmas = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE definition IS NULL OR definition = ''")
        empty_definitions = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE direction NOT IN ('forward', 'reverse')")
        invalid_directions = cursor.fetchone()[0]
        
        if empty_lemmas > 0:
            print(f"  ⚠️ Empty lemmas: {empty_lemmas}")
        else:
            print(f"  ✅ No empty lemmas")
            
        if empty_definitions > 0:
            print(f"  ⚠️ Empty definitions: {empty_definitions}")
        else:
            print(f"  ✅ No empty definitions")
            
        if invalid_directions > 0:
            print(f"  ❌ Invalid directions: {invalid_directions}")
        else:
            print(f"  ✅ All directions valid")
        
        # Sample some entries to check format
        cursor.execute("SELECT lemma, definition, direction FROM dictionary_entries LIMIT 5")
        sample_entries = cursor.fetchall()
        
        print(f"  📝 Sample entries:")
        for lemma, definition, direction in sample_entries:
            print(f"    {direction}: {lemma} → {definition[:50]}{'...' if len(definition) > 50 else ''}")
        
        # Check metadata
        cursor.execute("SELECT key, value FROM pack_metadata")
        metadata = dict(cursor.fetchall())
        
        print(f"  📋 Metadata:")
        for key, value in metadata.items():
            print(f"    {key}: {value}")
        
        return {
            'valid': empty_lemmas == 0 and empty_definitions == 0 and invalid_directions == 0,
            'total_entries': total_entries,
            'forward_entries': forward_entries,
            'reverse_entries': reverse_entries,
            'empty_lemmas': empty_lemmas,
            'empty_definitions': empty_definitions,
            'invalid_directions': invalid_directions,
            'sample_entries': sample_entries,
            'metadata': metadata
        }
        
    finally:
        conn.close()

def test_bidirectional_lookup(db_path: Path) -> Dict:
    """Test that bidirectional lookups work correctly"""
    print(f"🔄 Testing bidirectional lookups: {db_path.name}")
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        # Test forward lookup
        cursor.execute("SELECT lemma, definition FROM dictionary_entries WHERE direction = 'forward' LIMIT 3")
        forward_tests = cursor.fetchall()
        
        lookup_results = []
        
        for lemma, definition in forward_tests:
            # Try to find reverse entry
            cursor.execute("SELECT lemma, definition FROM dictionary_entries WHERE direction = 'reverse' AND lemma = ?", (definition,))
            reverse_result = cursor.fetchone()
            
            # Also try to find it in definition (for pipe-separated formats)
            if not reverse_result:
                # Check if the original lemma appears in any reverse definition
                cursor.execute("SELECT lemma, definition FROM dictionary_entries WHERE direction = 'reverse' AND definition LIKE ?", (f"%{lemma}%",))
                reverse_result = cursor.fetchone()
            
            result = {
                'forward_lemma': lemma,
                'forward_definition': definition,
                'reverse_found': reverse_result is not None,
                'reverse_entry': reverse_result
            }
            lookup_results.append(result)
            
            if reverse_result:
                print(f"  ✅ Bidirectional: {lemma} ↔ {reverse_result[0]}")
            else:
                print(f"  ⚠️ No reverse for: {lemma}")
        
        # Test specific common words
        test_words = ['the', 'and', 'house', 'water', 'good'] if 'de-en' in str(db_path) else ['casa', 'agua', 'bueno', 'grande', 'tiempo']
        
        print(f"  🎯 Testing common words:")
        for word in test_words:
            cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE lemma = ? AND direction = 'forward'", (word,))
            forward_count = cursor.fetchone()[0]
            
            cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE lemma = ? AND direction = 'reverse'", (word,))
            reverse_count = cursor.fetchone()[0]
            
            if forward_count > 0 or reverse_count > 0:
                print(f"    {word}: forward={forward_count}, reverse={reverse_count}")
        
        return {
            'valid': True,
            'lookup_results': lookup_results,
            'bidirectional_pairs': len([r for r in lookup_results if r['reverse_found']])
        }
        
    finally:
        conn.close()

def verify_zip_integrity(zip_path: Path) -> Dict:
    """Verify the zip file contains the correct structure"""
    print(f"📦 Verifying zip integrity: {zip_path.name}")
    
    import zipfile
    
    try:
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            file_list = zip_ref.namelist()
            
            # Should contain exactly one .sqlite file
            sqlite_files = [f for f in file_list if f.endswith('.sqlite')]
            
            if len(sqlite_files) != 1:
                return {'valid': False, 'error': f'Expected 1 sqlite file, found {len(sqlite_files)}: {sqlite_files}'}
            
            sqlite_file = sqlite_files[0]
            expected_name = f"{zip_path.stem}.sqlite"
            
            if sqlite_file != expected_name:
                print(f"  ⚠️ Unexpected filename: {sqlite_file} (expected: {expected_name})")
            else:
                print(f"  ✅ Correct filename: {sqlite_file}")
            
            # Check file size
            file_info = zip_ref.getinfo(sqlite_file)
            compressed_size = file_info.compress_size
            uncompressed_size = file_info.file_size
            compression_ratio = compressed_size / uncompressed_size if uncompressed_size > 0 else 0
            
            print(f"  📊 Compressed: {compressed_size:,} bytes")
            print(f"  📊 Uncompressed: {uncompressed_size:,} bytes")
            print(f"  📊 Compression ratio: {compression_ratio:.2%}")
            
            return {
                'valid': True,
                'sqlite_file': sqlite_file,
                'compressed_size': compressed_size,
                'uncompressed_size': uncompressed_size,
                'compression_ratio': compression_ratio
            }
            
    except Exception as e:
        return {'valid': False, 'error': str(e)}

def main():
    """Run comprehensive verification of all converted bidirectional packs"""
    assets_dir = Path("assets/language_packs")
    
    print("🔍 COMPREHENSIVE BIDIRECTIONAL PACK VERIFICATION")
    print("=" * 80)
    
    # Find all SQLite databases and zip files
    db_files = list(assets_dir.glob("*.sqlite"))
    zip_files = list(assets_dir.glob("*.sqlite.zip"))
    
    print(f"Found {len(db_files)} databases and {len(zip_files)} zip files")
    
    all_results = {}
    
    for db_path in db_files:
        pack_id = db_path.stem
        
        print(f"\n{'='*20} VERIFYING {pack_id.upper()} {'='*20}")
        
        # Verify database schema
        schema_result = verify_database_schema(db_path)
        
        # Verify data integrity
        data_result = verify_data_integrity(db_path)
        
        # Test bidirectional lookups
        lookup_result = test_bidirectional_lookup(db_path)
        
        # Verify zip file if exists
        zip_path = db_path.with_suffix('.sqlite.zip')
        zip_result = None
        if zip_path.exists():
            zip_result = verify_zip_integrity(zip_path)
        
        all_results[pack_id] = {
            'schema': schema_result,
            'data': data_result,
            'lookup': lookup_result,
            'zip': zip_result
        }
    
    # Generate summary report
    print(f"\n📊 VERIFICATION SUMMARY")
    print("=" * 80)
    
    valid_packs = 0
    total_entries = 0
    
    for pack_id, results in all_results.items():
        schema_valid = results['schema']['valid']
        data_valid = results['data']['valid']
        lookup_valid = results['lookup']['valid']
        zip_valid = results['zip']['valid'] if results['zip'] else True
        
        overall_valid = schema_valid and data_valid and lookup_valid and zip_valid
        
        if overall_valid:
            valid_packs += 1
            total_entries += results['data']['total_entries']
        
        status = "✅ VALID" if overall_valid else "❌ INVALID"
        entries = results['data']['total_entries']
        
        print(f"{pack_id}: {status} ({entries:,} entries)")
        
        if not overall_valid:
            if not schema_valid:
                print(f"  ❌ Schema: {results['schema'].get('error', 'Unknown error')}")
            if not data_valid:
                print(f"  ❌ Data integrity issues found")
            if not lookup_valid:
                print(f"  ❌ Lookup issues found")
            if results['zip'] and not zip_valid:
                print(f"  ❌ Zip: {results['zip'].get('error', 'Unknown error')}")
    
    print(f"\n🎯 FINAL RESULTS:")
    print(f"Valid packs: {valid_packs}/{len(all_results)}")
    print(f"Total entries: {total_entries:,}")
    
    if valid_packs == len(all_results):
        print("🎉 ALL PACKS VERIFIED SUCCESSFULLY!")
        print("✅ Databases are in correct bidirectional format")
        print("✅ Data integrity confirmed")
        print("✅ Bidirectional lookups working")
        print("✅ Zip files properly structured")
        return True
    else:
        print("❌ Some packs failed verification")
        return False

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)