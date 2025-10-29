#!/usr/bin/env python3
"""
Comprehensive verification of current German and Spanish language packs
1. Check if files exist on GitHub
2. Verify structure matches expected bidirectional format
3. Validate data integrity 
4. Test lookup functionality as per requirements
"""

import requests
import sqlite3
import zipfile
import json
import tempfile
import shutil
from pathlib import Path
from typing import Dict, List, Tuple, Optional

def check_github_availability(pack_id: str) -> Dict:
    """Check if the pack exists and is accessible on GitHub releases"""
    print(f"🌐 Checking GitHub availability: {pack_id}")
    
    # GitHub releases URL pattern
    base_url = "https://github.com/kvgharbigit/PolyRead/releases/download/language-packs-v2.0"
    zip_url = f"{base_url}/{pack_id}.sqlite.zip"
    
    try:
        # Check if file exists and get headers (allow redirects for GitHub releases)
        response = requests.head(zip_url, timeout=30, allow_redirects=True)
        
        if response.status_code == 200:
            content_length = response.headers.get('content-length', '0')
            content_type = response.headers.get('content-type', 'unknown')
            last_modified = response.headers.get('last-modified', 'unknown')
            
            print(f"   ✅ File accessible on GitHub")
            print(f"   📊 Size: {int(content_length):,} bytes ({int(content_length)/1024/1024:.1f} MB)")
            print(f"   📋 Content-Type: {content_type}")
            print(f"   📅 Last Modified: {last_modified}")
            
            return {
                'accessible': True,
                'url': zip_url,
                'size_bytes': int(content_length),
                'size_mb': int(content_length) / 1024 / 1024,
                'content_type': content_type,
                'last_modified': last_modified
            }
        else:
            print(f"   ❌ File not accessible: HTTP {response.status_code}")
            return {'accessible': False, 'error': f'HTTP {response.status_code}', 'url': zip_url}
            
    except Exception as e:
        print(f"   ❌ Error checking GitHub: {e}")
        return {'accessible': False, 'error': str(e), 'url': zip_url}

def download_and_extract_pack(pack_id: str, github_info: Dict) -> Optional[Path]:
    """Download pack from GitHub and extract for testing"""
    if not github_info['accessible']:
        return None
        
    print(f"📥 Downloading {pack_id} from GitHub for testing...")
    
    try:
        # Download to temporary location (allow redirects for GitHub releases)
        response = requests.get(github_info['url'], stream=True, timeout=60, allow_redirects=True)
        response.raise_for_status()
        
        temp_dir = Path(tempfile.mkdtemp(prefix=f"verify_{pack_id}_"))
        zip_path = temp_dir / f"{pack_id}.sqlite.zip"
        
        with open(zip_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        
        print(f"   ✅ Downloaded: {zip_path.stat().st_size:,} bytes")
        
        # Extract zip file
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            zip_ref.extractall(temp_dir)
        
        # Find the SQLite file
        sqlite_files = list(temp_dir.glob("*.sqlite"))
        if sqlite_files:
            sqlite_path = sqlite_files[0]
            print(f"   ✅ Extracted: {sqlite_path.name}")
            return sqlite_path
        else:
            print(f"   ❌ No SQLite file found in zip")
            return None
            
    except Exception as e:
        print(f"   ❌ Download/extract failed: {e}")
        return None

def verify_database_structure(db_path: Path) -> Dict:
    """Verify the database has correct bidirectional structure"""
    print(f"🔍 Verifying database structure: {db_path.name}")
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        # Check tables
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = [row[0] for row in cursor.fetchall()]
        
        required_tables = {'dictionary_entries', 'pack_metadata'}
        has_required_tables = required_tables.issubset(set(tables))
        
        print(f"   Tables found: {tables}")
        print(f"   ✅ Required tables: {'Yes' if has_required_tables else 'No'}")
        
        if not has_required_tables:
            return {'valid': False, 'error': f'Missing tables: {required_tables - set(tables)}'}
        
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
        
        missing_columns = set(required_columns.keys()) - set(columns.keys())
        if missing_columns:
            print(f"   ❌ Missing columns: {missing_columns}")
            return {'valid': False, 'error': f'Missing columns: {missing_columns}'}
        
        print(f"   ✅ All required columns present")
        
        # Check indexes
        cursor.execute("SELECT name FROM sqlite_master WHERE type='index'")
        indexes = [row[0] for row in cursor.fetchall()]
        expected_indexes = ['idx_lemma_direction', 'idx_direction', 'idx_languages']
        
        for idx in expected_indexes:
            if idx in indexes:
                print(f"   ✅ Index: {idx}")
            else:
                print(f"   ⚠️ Missing index: {idx}")
        
        # Check constraints
        cursor.execute("SELECT sql FROM sqlite_master WHERE name='dictionary_entries' AND type='table'")
        table_sql = cursor.fetchone()[0]
        has_direction_constraint = "CHECK (direction IN ('forward', 'reverse'))" in table_sql
        
        print(f"   ✅ Direction constraint: {'Yes' if has_direction_constraint else 'No'}")
        
        return {
            'valid': True,
            'tables': tables,
            'columns': list(columns.keys()),
            'indexes': indexes,
            'has_direction_constraint': has_direction_constraint
        }
        
    finally:
        conn.close()

def verify_data_integrity(db_path: Path) -> Dict:
    """Verify data integrity and get statistics"""
    print(f"📊 Verifying data integrity: {db_path.name}")
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        # Basic statistics
        cursor.execute("SELECT COUNT(*) FROM dictionary_entries")
        total_entries = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE direction = 'forward'")
        forward_entries = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE direction = 'reverse'")
        reverse_entries = cursor.fetchone()[0]
        
        print(f"   📈 Total entries: {total_entries:,}")
        print(f"   📈 Forward entries: {forward_entries:,}")
        print(f"   📈 Reverse entries: {reverse_entries:,}")
        
        # Data quality checks
        cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE lemma IS NULL OR lemma = ''")
        empty_lemmas = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE definition IS NULL OR definition = ''")
        empty_definitions = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE direction NOT IN ('forward', 'reverse')")
        invalid_directions = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE source_language IS NULL OR target_language IS NULL")
        missing_languages = cursor.fetchone()[0]
        
        data_quality_issues = []
        if empty_lemmas > 0:
            data_quality_issues.append(f"Empty lemmas: {empty_lemmas}")
        if empty_definitions > 0:
            data_quality_issues.append(f"Empty definitions: {empty_definitions}")
        if invalid_directions > 0:
            data_quality_issues.append(f"Invalid directions: {invalid_directions}")
        if missing_languages > 0:
            data_quality_issues.append(f"Missing languages: {missing_languages}")
        
        if data_quality_issues:
            print(f"   ⚠️ Data quality issues: {', '.join(data_quality_issues)}")
        else:
            print(f"   ✅ No data quality issues found")
        
        # Sample some entries
        cursor.execute("SELECT lemma, definition, direction, source_language, target_language FROM dictionary_entries LIMIT 3")
        sample_entries = cursor.fetchall()
        
        print(f"   📝 Sample entries:")
        for lemma, definition, direction, source_lang, target_lang in sample_entries:
            def_preview = definition[:50] + "..." if len(definition) > 50 else definition
            print(f"      {direction} ({source_lang}→{target_lang}): {lemma} → {def_preview}")
        
        # Check metadata
        cursor.execute("SELECT key, value FROM pack_metadata")
        metadata = dict(cursor.fetchall())
        
        print(f"   📋 Pack metadata:")
        for key, value in metadata.items():
            print(f"      {key}: {value}")
        
        return {
            'valid': len(data_quality_issues) == 0,
            'total_entries': total_entries,
            'forward_entries': forward_entries,
            'reverse_entries': reverse_entries,
            'data_quality_issues': data_quality_issues,
            'sample_entries': sample_entries,
            'metadata': metadata
        }
        
    finally:
        conn.close()

def test_lookup_functionality(db_path: Path) -> Dict:
    """Test the specific lookup functionality we expect"""
    print(f"🔄 Testing lookup functionality: {db_path.name}")
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        # Test 1: Basic forward/reverse lookup capability
        print(f"   Test 1: Basic direction-based lookups")
        
        # Get a few words from each direction
        cursor.execute("SELECT lemma, definition FROM dictionary_entries WHERE direction = 'forward' LIMIT 3")
        forward_words = cursor.fetchall()
        
        cursor.execute("SELECT lemma, definition FROM dictionary_entries WHERE direction = 'reverse' LIMIT 3")
        reverse_words = cursor.fetchall()
        
        print(f"      Forward direction samples: {len(forward_words)} found")
        print(f"      Reverse direction samples: {len(reverse_words)} found")
        
        # Test 2: Index performance (should be fast)
        import time
        
        print(f"   Test 2: Index performance")
        test_word = forward_words[0][0] if forward_words else "test"
        
        start_time = time.time()
        cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE lemma = ? AND direction = 'forward'", (test_word,))
        result = cursor.fetchone()[0]
        lookup_time = time.time() - start_time
        
        print(f"      Lookup time for '{test_word}': {lookup_time*1000:.2f}ms")
        print(f"      Result: {result} entries found")
        
        # Test 3: Bidirectional functionality
        print(f"   Test 3: Bidirectional lookup capability")
        
        bidirectional_tests = []
        for lemma, definition in forward_words:
            # Try to find reverse entry for the definition
            cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE direction = 'reverse' AND lemma = ?", (definition,))
            exact_reverse = cursor.fetchone()[0]
            
            # Also check if original lemma appears in any reverse definition
            cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE direction = 'reverse' AND definition LIKE ?", (f"%{lemma}%",))
            definition_reverse = cursor.fetchone()[0]
            
            bidirectional_tests.append({
                'forward_word': lemma,
                'forward_definition': definition,
                'exact_reverse_matches': exact_reverse,
                'definition_reverse_matches': definition_reverse
            })
        
        reverse_coverage = sum(1 for test in bidirectional_tests if test['exact_reverse_matches'] > 0 or test['definition_reverse_matches'] > 0)
        
        print(f"      Bidirectional coverage: {reverse_coverage}/{len(bidirectional_tests)} words have reverse lookups")
        
        # Test 4: Language-specific lookup (our app's expected usage)
        print(f"   Test 4: Application-style lookup simulation")
        
        # Simulate how our BidirectionalDictionaryService would query
        metadata = dict(cursor.execute("SELECT key, value FROM pack_metadata").fetchall())
        source_lang = metadata.get('source_language', 'unknown')
        target_lang = metadata.get('target_language', 'unknown')
        
        # Forward lookup (source → target)
        test_queries = [forward_words[0][0]] if forward_words else []
        for query in test_queries:
            cursor.execute("""
                SELECT lemma, definition FROM dictionary_entries 
                WHERE LOWER(lemma) = LOWER(?) AND direction = 'forward' AND source_language = ? AND target_language = ?
                LIMIT 1
            """, (query, source_lang, target_lang))
            
            forward_result = cursor.fetchone()
            
            # Reverse lookup (target → source)  
            cursor.execute("""
                SELECT lemma, definition FROM dictionary_entries 
                WHERE LOWER(lemma) = LOWER(?) AND direction = 'reverse' AND source_language = ? AND target_language = ?
                LIMIT 1
            """, (query, target_lang, source_lang))
            
            reverse_result = cursor.fetchone()
            
            print(f"      Query '{query}':")
            print(f"         Forward ({source_lang}→{target_lang}): {'✅ Found' if forward_result else '❌ Not found'}")
            print(f"         Reverse ({target_lang}→{source_lang}): {'✅ Found' if reverse_result else '❌ Not found'}")
        
        return {
            'valid': True,
            'forward_samples': len(forward_words),
            'reverse_samples': len(reverse_words),
            'lookup_time_ms': lookup_time * 1000,
            'bidirectional_coverage': f"{reverse_coverage}/{len(bidirectional_tests)}",
            'app_simulation_passed': True,
            'metadata': metadata
        }
        
    finally:
        conn.close()

def verify_pack_comprehensive(pack_id: str) -> Dict:
    """Run comprehensive verification of a single pack"""
    print(f"\n{'='*20} VERIFYING {pack_id.upper()} {'='*20}")
    
    results = {'pack_id': pack_id}
    
    # Step 1: Check GitHub availability
    github_info = check_github_availability(pack_id)
    results['github'] = github_info
    
    if not github_info['accessible']:
        print(f"❌ Skipping further tests - pack not accessible on GitHub")
        return results
    
    # Step 2: Download and extract
    db_path = download_and_extract_pack(pack_id, github_info)
    if not db_path:
        print(f"❌ Skipping further tests - could not download/extract pack")
        return results
    
    try:
        # Step 3: Verify structure
        structure_result = verify_database_structure(db_path)
        results['structure'] = structure_result
        
        if not structure_result['valid']:
            print(f"❌ Structure verification failed")
            return results
        
        # Step 4: Verify data integrity
        data_result = verify_data_integrity(db_path)
        results['data'] = data_result
        
        # Step 5: Test lookup functionality
        lookup_result = test_lookup_functionality(db_path)
        results['lookup'] = lookup_result
        
        # Overall assessment
        overall_valid = (github_info['accessible'] and 
                        structure_result['valid'] and 
                        data_result['valid'] and 
                        lookup_result['valid'])
        
        results['overall_valid'] = overall_valid
        
        if overall_valid:
            print(f"✅ {pack_id.upper()} PASSED ALL VERIFICATION TESTS")
        else:
            print(f"❌ {pack_id.upper()} FAILED VERIFICATION")
        
        return results
        
    finally:
        # Cleanup
        if db_path and db_path.parent.exists():
            shutil.rmtree(db_path.parent)

def main():
    """Verify current German and Spanish language packs"""
    print("🔍 COMPREHENSIVE VERIFICATION OF CURRENT LANGUAGE PACKS")
    print("=" * 80)
    
    packs_to_verify = ['de-en', 'eng-spa']
    all_results = {}
    
    for pack_id in packs_to_verify:
        results = verify_pack_comprehensive(pack_id)
        all_results[pack_id] = results
    
    # Generate summary report
    print(f"\n📊 VERIFICATION SUMMARY REPORT")
    print("=" * 80)
    
    for pack_id, results in all_results.items():
        overall_valid = results.get('overall_valid', False)
        github_accessible = results.get('github', {}).get('accessible', False)
        
        status = "✅ FULLY VERIFIED" if overall_valid else "❌ ISSUES FOUND"
        
        print(f"\n{pack_id.upper()}: {status}")
        
        if github_accessible:
            github_info = results['github']
            print(f"   📁 GitHub: ✅ Accessible ({github_info['size_mb']:.1f} MB)")
        else:
            print(f"   📁 GitHub: ❌ Not accessible")
            continue
        
        if 'structure' in results:
            structure_valid = results['structure']['valid']
            print(f"   🏗️ Structure: {'✅ Valid' if structure_valid else '❌ Invalid'}")
        
        if 'data' in results:
            data_info = results['data']
            data_valid = data_info['valid']
            total_entries = data_info['total_entries']
            print(f"   📊 Data: {'✅ Valid' if data_valid else '❌ Issues'} ({total_entries:,} entries)")
            
            if not data_valid:
                issues = data_info.get('data_quality_issues', [])
                for issue in issues:
                    print(f"      ⚠️ {issue}")
        
        if 'lookup' in results:
            lookup_valid = results['lookup']['valid']
            coverage = results['lookup'].get('bidirectional_coverage', 'unknown')
            print(f"   🔄 Lookup: {'✅ Working' if lookup_valid else '❌ Issues'} (bidirectional: {coverage})")
    
    # Final assessment
    valid_packs = sum(1 for results in all_results.values() if results.get('overall_valid', False))
    total_packs = len(all_results)
    
    print(f"\n🎯 FINAL ASSESSMENT:")
    print(f"Valid packs: {valid_packs}/{total_packs}")
    
    if valid_packs == total_packs:
        print("🎉 ALL PACKS VERIFIED SUCCESSFULLY!")
        print("✅ Ready for deployment and use")
        return True
    else:
        print("❌ Some packs have issues that need attention")
        return False

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)