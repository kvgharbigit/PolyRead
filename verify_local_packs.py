#!/usr/bin/env python3
"""
Verify the local German and Spanish language packs before GitHub upload
Test structure, data integrity, and lookup functionality
"""

import sqlite3
import zipfile
import json
import time
from pathlib import Path
from typing import Dict, List, Tuple

def verify_local_zip_file(zip_path: Path) -> Dict:
    """Verify zip file structure and contents"""
    print(f"📦 Verifying zip file: {zip_path.name}")
    
    if not zip_path.exists():
        return {'valid': False, 'error': 'File does not exist'}
    
    try:
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            file_list = zip_ref.namelist()
            
            # Should contain exactly one .sqlite file
            sqlite_files = [f for f in file_list if f.endswith('.sqlite')]
            
            if len(sqlite_files) != 1:
                return {'valid': False, 'error': f'Expected 1 sqlite file, found {len(sqlite_files)}: {sqlite_files}'}
            
            sqlite_file = sqlite_files[0]
            file_info = zip_ref.getinfo(sqlite_file)
            
            print(f"   ✅ Contains: {sqlite_file}")
            print(f"   📊 Compressed: {file_info.compress_size:,} bytes")
            print(f"   📊 Uncompressed: {file_info.file_size:,} bytes")
            print(f"   📊 Compression: {file_info.compress_size/file_info.file_size:.1%}")
            
            return {
                'valid': True,
                'sqlite_file': sqlite_file,
                'compressed_size': file_info.compress_size,
                'uncompressed_size': file_info.file_size,
                'compression_ratio': file_info.compress_size / file_info.file_size
            }
            
    except Exception as e:
        return {'valid': False, 'error': str(e)}

def verify_local_database(db_path: Path) -> Dict:
    """Verify local database structure and content"""
    print(f"🔍 Verifying database: {db_path.name}")
    
    if not db_path.exists():
        return {'valid': False, 'error': 'Database file does not exist'}
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        # Check schema
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = [row[0] for row in cursor.fetchall()]
        
        required_tables = {'dictionary_entries', 'pack_metadata'}
        has_required = required_tables.issubset(set(tables))
        
        print(f"   📋 Tables: {tables}")
        print(f"   ✅ Required tables: {'Yes' if has_required else 'No'}")
        
        if not has_required:
            return {'valid': False, 'error': f'Missing tables: {required_tables - set(tables)}'}
        
        # Check data counts
        cursor.execute("SELECT COUNT(*) FROM dictionary_entries")
        total_entries = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE direction = 'forward'")
        forward_entries = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE direction = 'reverse'")
        reverse_entries = cursor.fetchone()[0]
        
        print(f"   📈 Total entries: {total_entries:,}")
        print(f"   📈 Forward: {forward_entries:,}")
        print(f"   📈 Reverse: {reverse_entries:,}")
        
        # Check metadata
        cursor.execute("SELECT key, value FROM pack_metadata")
        metadata = dict(cursor.fetchall())
        
        print(f"   📋 Metadata:")
        for key, value in metadata.items():
            print(f"      {key}: {value}")
        
        # Test lookup performance
        cursor.execute("SELECT lemma FROM dictionary_entries WHERE direction = 'forward' LIMIT 1")
        test_word = cursor.fetchone()
        
        if test_word:
            test_lemma = test_word[0]
            start_time = time.time()
            cursor.execute("SELECT definition FROM dictionary_entries WHERE lemma = ? AND direction = 'forward'", (test_lemma,))
            result = cursor.fetchone()
            lookup_time = (time.time() - start_time) * 1000
            
            print(f"   ⚡ Lookup test: {lookup_time:.2f}ms for '{test_lemma}'")
            print(f"   ✅ Result found: {'Yes' if result else 'No'}")
        
        # Sample entries
        cursor.execute("SELECT lemma, definition, direction FROM dictionary_entries LIMIT 3")
        samples = cursor.fetchall()
        
        print(f"   📝 Sample entries:")
        for lemma, definition, direction in samples:
            def_preview = (definition[:40] + "...") if len(definition) > 40 else definition
            print(f"      {direction}: {lemma} → {def_preview}")
        
        return {
            'valid': True,
            'total_entries': total_entries,
            'forward_entries': forward_entries,
            'reverse_entries': reverse_entries,
            'metadata': metadata,
            'lookup_time_ms': lookup_time if test_word else 0,
            'sample_entries': samples
        }
        
    finally:
        conn.close()

def test_bidirectional_functionality(db_path: Path) -> Dict:
    """Test bidirectional lookup functionality specifically"""
    print(f"🔄 Testing bidirectional functionality: {db_path.name}")
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        # Get source and target languages
        cursor.execute("SELECT value FROM pack_metadata WHERE key = 'source_language'")
        source_lang = cursor.fetchone()[0]
        
        cursor.execute("SELECT value FROM pack_metadata WHERE key = 'target_language'")
        target_lang = cursor.fetchone()[0]
        
        print(f"   🌐 Languages: {source_lang} ↔ {target_lang}")
        
        # Test forward lookup
        cursor.execute("SELECT lemma, definition FROM dictionary_entries WHERE direction = 'forward' LIMIT 2")
        forward_tests = cursor.fetchall()
        
        bidirectional_pairs = 0
        total_tests = 0
        
        for lemma, definition in forward_tests:
            total_tests += 1
            
            # Check if there's a reverse entry
            cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE direction = 'reverse' AND lemma = ?", (definition,))
            exact_reverse = cursor.fetchone()[0]
            
            # Check if original lemma appears in reverse definitions
            cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE direction = 'reverse' AND definition LIKE ?", (f"%{lemma}%",))
            contains_reverse = cursor.fetchone()[0]
            
            has_bidirectional = exact_reverse > 0 or contains_reverse > 0
            if has_bidirectional:
                bidirectional_pairs += 1
            
            print(f"   {'✅' if has_bidirectional else '⚠️'} {lemma}: exact_reverse={exact_reverse}, contains_reverse={contains_reverse}")
        
        # Test the BidirectionalDictionaryService query pattern
        print(f"   🎯 Testing app-style queries:")
        
        test_queries = [forward_tests[0][0]] if forward_tests else []
        app_test_results = []
        
        for query in test_queries:
            # Forward direction query (like our app does)
            cursor.execute("""
                SELECT lemma, definition FROM dictionary_entries 
                WHERE LOWER(lemma) = LOWER(?) AND direction = ? AND source_language = ? AND target_language = ?
                LIMIT 1
            """, (query, 'forward', source_lang, target_lang))
            
            forward_result = cursor.fetchone()
            
            # Reverse direction query
            cursor.execute("""
                SELECT lemma, definition FROM dictionary_entries 
                WHERE LOWER(lemma) = LOWER(?) AND direction = ? AND source_language = ? AND target_language = ?
                LIMIT 1
            """, (query, 'reverse', target_lang, source_lang))
            
            reverse_result = cursor.fetchone()
            
            app_test_results.append({
                'query': query,
                'forward_found': forward_result is not None,
                'reverse_found': reverse_result is not None,
                'forward_result': forward_result,
                'reverse_result': reverse_result
            })
            
            print(f"      Query '{query}':")
            print(f"         Forward ({source_lang}→{target_lang}): {'✅' if forward_result else '❌'}")
            print(f"         Reverse ({target_lang}→{source_lang}): {'✅' if reverse_result else '❌'}")
        
        coverage_percent = (bidirectional_pairs / total_tests * 100) if total_tests > 0 else 0
        
        return {
            'valid': True,
            'source_language': source_lang,
            'target_language': target_lang,
            'bidirectional_pairs': bidirectional_pairs,
            'total_tests': total_tests,
            'coverage_percent': coverage_percent,
            'app_test_results': app_test_results
        }
        
    finally:
        conn.close()

def verify_pack_complete(pack_id: str, assets_dir: Path) -> Dict:
    """Complete verification of a single pack"""
    print(f"\n{'='*20} VERIFYING LOCAL {pack_id.upper()} {'='*20}")
    
    # File paths
    db_path = assets_dir / f"{pack_id}.sqlite"
    zip_path = assets_dir / f"{pack_id}.sqlite.zip"
    
    results = {'pack_id': pack_id}
    
    # 1. Verify zip file
    if zip_path.exists():
        zip_result = verify_local_zip_file(zip_path)
        results['zip'] = zip_result
        
        if not zip_result['valid']:
            print(f"❌ Zip file invalid: {zip_result['error']}")
    else:
        print(f"⚠️ Zip file not found: {zip_path}")
        results['zip'] = {'valid': False, 'error': 'File not found'}
    
    # 2. Verify database
    if db_path.exists():
        db_result = verify_local_database(db_path)
        results['database'] = db_result
        
        if not db_result['valid']:
            print(f"❌ Database invalid: {db_result['error']}")
            return results
    else:
        print(f"❌ Database file not found: {db_path}")
        results['database'] = {'valid': False, 'error': 'File not found'}
        return results
    
    # 3. Test bidirectional functionality
    bidirectional_result = test_bidirectional_functionality(db_path)
    results['bidirectional'] = bidirectional_result
    
    # Overall assessment
    overall_valid = (results['zip']['valid'] and 
                    results['database']['valid'] and 
                    bidirectional_result['valid'])
    
    results['overall_valid'] = overall_valid
    
    if overall_valid:
        print(f"✅ {pack_id.upper()} PASSED ALL LOCAL VERIFICATION TESTS")
    else:
        print(f"❌ {pack_id.upper()} FAILED LOCAL VERIFICATION")
    
    return results

def main():
    """Verify all current local language packs"""
    print("🔍 LOCAL LANGUAGE PACK VERIFICATION")
    print("=" * 80)
    
    assets_dir = Path("assets/language_packs")
    packs_to_verify = ['de-en', 'eng-spa']
    
    all_results = {}
    
    for pack_id in packs_to_verify:
        results = verify_pack_complete(pack_id, assets_dir)
        all_results[pack_id] = results
    
    # Summary report
    print(f"\n📊 LOCAL VERIFICATION SUMMARY")
    print("=" * 80)
    
    valid_packs = 0
    total_entries = 0
    
    for pack_id, results in all_results.items():
        overall_valid = results.get('overall_valid', False)
        
        print(f"\n{pack_id.upper()}: {'✅ VALID' if overall_valid else '❌ INVALID'}")
        
        if 'database' in results and results['database']['valid']:
            db_info = results['database']
            entries = db_info['total_entries']
            total_entries += entries
            
            print(f"   📊 Entries: {entries:,} ({db_info['forward_entries']:,} forward + {db_info['reverse_entries']:,} reverse)")
            print(f"   ⚡ Performance: {db_info['lookup_time_ms']:.2f}ms lookup time")
            
            if 'bidirectional' in results:
                bid_info = results['bidirectional']
                print(f"   🔄 Bidirectional: {bid_info['coverage_percent']:.1f}% coverage ({bid_info['bidirectional_pairs']}/{bid_info['total_tests']})")
        
        if 'zip' in results and results['zip']['valid']:
            zip_info = results['zip']
            print(f"   📦 Zip: {zip_info['compressed_size']:,} bytes ({zip_info['compression_ratio']:.1%} compression)")
        
        if overall_valid:
            valid_packs += 1
    
    print(f"\n🎯 FINAL LOCAL ASSESSMENT:")
    print(f"Valid packs: {valid_packs}/{len(all_results)}")
    print(f"Total entries: {total_entries:,}")
    
    if valid_packs == len(all_results):
        print("🎉 ALL LOCAL PACKS VERIFIED SUCCESSFULLY!")
        print("✅ Ready for GitHub upload")
        
        # Show next steps
        print(f"\n📋 NEXT STEPS:")
        print(f"1. Upload .sqlite.zip files to GitHub releases")
        print(f"2. Update registry URLs to point to GitHub")
        print(f"3. Test download from GitHub")
        
        return True
    else:
        print("❌ Some local packs have issues")
        return False

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)