#!/usr/bin/env python3
"""
Convert existing language pack databases to bidirectional format
This will consolidate the separate forward/reverse packs into single bidirectional databases
"""

import sqlite3
import zipfile
import shutil
import json
import hashlib
from pathlib import Path
from typing import Tuple, Dict, List

def convert_stardict_to_bidirectional(source_db_path: Path, pack_id: str, source_lang: str, target_lang: str) -> Tuple[int, int]:
    """Convert old StarDict format database to new bidirectional format"""
    
    bidirectional_path = source_db_path.with_name(f"{pack_id}_bidirectional.sqlite")
    
    print(f"Converting {source_db_path.name} to bidirectional format...")
    
    # Open source database
    source_conn = sqlite3.connect(source_db_path)
    dest_conn = sqlite3.connect(bidirectional_path)
    
    try:
        # Check if source has word table or dict table
        source_cursor = source_conn.cursor()
        tables = source_cursor.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
        table_names = [table[0] for table in tables]
        
        print(f"  Source tables: {table_names}")
        
        # Determine source table
        if 'dict' in table_names:
            source_table = 'dict'
            word_col = 'lemma'
            def_col = 'def'
        elif 'word' in table_names:
            source_table = 'word'
            word_col = 'w'
            def_col = 'm'
        else:
            raise Exception(f"No suitable source table found in {source_db_path}")
        
        print(f"  Using source table: {source_table}")
        
        # Create bidirectional schema
        dest_conn.executescript(f"""
        CREATE TABLE dictionary_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            lemma TEXT NOT NULL,
            definition TEXT NOT NULL,
            direction TEXT NOT NULL CHECK (direction IN ('forward', 'reverse')),
            source_language TEXT NOT NULL,
            target_language TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        
        CREATE INDEX idx_lemma_direction ON dictionary_entries(lemma, direction);
        CREATE INDEX idx_direction ON dictionary_entries(direction);
        CREATE INDEX idx_languages ON dictionary_entries(source_language, target_language);
        
        CREATE TABLE pack_metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        """)
        
        # Insert metadata
        metadata = [
            ('pack_id', pack_id),
            ('source_language', source_lang),
            ('target_language', target_lang),
            ('pack_type', 'bidirectional'),
            ('schema_version', '2.0'),
            ('created_at', 'CURRENT_TIMESTAMP'),
            ('converted_from', 'stardict')
        ]
        dest_conn.executemany('INSERT INTO pack_metadata (key, value) VALUES (?, ?)', metadata)
        
        # Copy data in forward direction
        print(f"  Copying data from {source_table} table...")
        source_cursor.execute(f"SELECT {word_col}, {def_col} FROM {source_table} WHERE {word_col} IS NOT NULL AND {def_col} IS NOT NULL")
        
        forward_count = 0
        reverse_count = 0
        
        for word, definition in source_cursor.fetchall():
            if not word or not definition:
                continue
                
            word = word.strip()
            definition = definition.strip()
            
            if not word or not definition:
                continue
            
            # Insert forward direction (source → target)
            dest_conn.execute("""
                INSERT INTO dictionary_entries (lemma, definition, direction, source_language, target_language)
                VALUES (?, ?, 'forward', ?, ?)
            """, (word, definition, source_lang, target_lang))
            forward_count += 1
            
            # For true bidirectional: create reverse entries
            # This creates reverse lookups from definition words back to the original word
            # Split definition on common separators to get individual translation words
            translations = []
            for sep in [' | ', '|', ';', ',']:
                if sep in definition:
                    translations = [t.strip() for t in definition.split(sep) if t.strip()]
                    break
            
            if not translations:
                translations = [definition]
            
            # Create reverse entries for each translation
            for translation in translations:
                if translation and translation != word:  # Avoid circular references
                    dest_conn.execute("""
                        INSERT OR IGNORE INTO dictionary_entries (lemma, definition, direction, source_language, target_language)
                        VALUES (?, ?, 'reverse', ?, ?)
                    """, (translation, word, target_lang, source_lang))
                    reverse_count += 1
        
        dest_conn.commit()
        
        print(f"  ✅ Converted: {forward_count} forward + {reverse_count} reverse = {forward_count + reverse_count} total entries")
        
        # Replace original with bidirectional
        source_db_path.unlink()
        bidirectional_path.rename(source_db_path)
        
        return forward_count, reverse_count
        
    finally:
        source_conn.close()
        dest_conn.close()

def create_bidirectional_zip(db_path: Path, pack_id: str) -> Dict:
    """Create zip file for bidirectional database"""
    zip_path = db_path.with_suffix('.sqlite.zip')
    
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zip_ref:
        zip_ref.write(db_path, f"{pack_id}.sqlite")
    
    # Calculate statistics
    file_size = zip_path.stat().st_size
    checksum = hashlib.sha256(zip_path.read_bytes()).hexdigest()
    
    # Get entry count
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE direction = 'forward'")
    forward_entries = cursor.fetchone()[0]
    cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE direction = 'reverse'")
    reverse_entries = cursor.fetchone()[0]
    cursor.execute("SELECT key, value FROM pack_metadata WHERE key IN ('source_language', 'target_language')")
    metadata_rows = cursor.fetchall()
    metadata = dict(metadata_rows)
    conn.close()
    
    return {
        'id': pack_id,
        'zip_path': str(zip_path),
        'size_bytes': file_size,
        'size_mb': round(file_size / 1024 / 1024, 1),
        'checksum': checksum,
        'forward_entries': forward_entries,
        'reverse_entries': reverse_entries,
        'total_entries': forward_entries + reverse_entries,
        'source_language': metadata.get('source_language', ''),
        'target_language': metadata.get('target_language', '')
    }

def consolidate_language_packs():
    """Consolidate all existing language packs to bidirectional format"""
    assets_dir = Path("assets/language_packs")
    
    print("🔄 Consolidating language packs to bidirectional format")
    print("=" * 60)
    
    # Define the conversions needed
    conversions = [
        {
            'pack_id': 'de-en',
            'source_file': 'de-en.sqlite',
            'source_lang': 'de',
            'target_lang': 'en',
            'description': 'German-English Wiktionary dictionary'
        },
        {
            'pack_id': 'es-en', 
            'source_file': 'eng-spa.sqlite',  # Use the larger Spanish pack
            'source_lang': 'es',
            'target_lang': 'en',
            'description': 'Spanish-English Wiktionary dictionary'
        }
    ]
    
    results = []
    
    for conversion in conversions:
        pack_id = conversion['pack_id']
        source_file = conversion['source_file']
        source_path = assets_dir / source_file
        
        print(f"\n📦 Processing {pack_id}...")
        print(f"   Source: {source_file}")
        
        if not source_path.exists():
            print(f"   ❌ Source file not found: {source_path}")
            continue
        
        try:
            # Convert to bidirectional
            forward_count, reverse_count = convert_stardict_to_bidirectional(
                source_path,
                pack_id,
                conversion['source_lang'],
                conversion['target_lang']
            )
            
            # Create zip file
            pack_info = create_bidirectional_zip(source_path, pack_id)
            pack_info.update({
                'name': f"{conversion['source_lang'].upper()} ↔ {conversion['target_lang'].upper()}",
                'description': conversion['description'],
                'pack_type': 'bidirectional'
            })
            
            results.append(pack_info)
            
            print(f"   ✅ Success: {pack_info['zip_path']}")
            print(f"   📊 {pack_info['forward_entries']} forward + {pack_info['reverse_entries']} reverse = {pack_info['total_entries']} total")
            print(f"   💾 {pack_info['size_mb']} MB")
            
        except Exception as e:
            print(f"   ❌ Failed: {e}")
            continue
    
    # Clean up old files
    print(f"\n🧹 Cleaning up old format files...")
    old_files = [
        'en-de.sqlite', 'en-de.sqlite.zip',
        'en-es.sqlite.zip', 'es-en.sqlite.zip'
    ]
    
    for old_file in old_files:
        old_path = assets_dir / old_file
        if old_path.exists():
            old_path.unlink()
            print(f"   🗑️ Removed: {old_file}")
    
    # Update registry with bidirectional packs
    print(f"\n📋 Updating comprehensive registry...")
    registry_path = assets_dir / "comprehensive-registry.json"
    
    if registry_path.exists():
        with open(registry_path, 'r') as f:
            registry = json.load(f)
    else:
        registry = {
            "version": "2.0",
            "description": "PolyRead Language Packs - Bidirectional Wiktionary Dictionaries",
            "packs": []
        }
    
    # Remove old pack entries and add new bidirectional ones
    registry['packs'] = [pack for pack in registry.get('packs', []) if pack.get('pack_type') != 'main']
    
    for result in results:
        registry['packs'].append({
            'id': result['id'],
            'name': result['name'],
            'description': result['description'],
            'source_language': result['source_language'],
            'target_language': result['target_language'],
            'entries': result['forward_entries'],
            'total_entries': result['total_entries'],
            'size_bytes': result['size_bytes'],
            'size_mb': result['size_mb'],
            'checksum': result['checksum'],
            'pack_type': 'bidirectional',
            'schema_version': '2.0',
            'download_url': f"https://github.com/kvgharbigit/PolyRead/releases/download/language-packs-v2.0/{result['id']}.sqlite.zip"
        })
    
    # Update registry metadata
    registry.update({
        'pack_count': len(registry['packs']),
        'total_entries': sum(pack.get('total_entries', 0) for pack in registry['packs']),
        'schema_version': '2.0',
        'timestamp': 'auto-generated'
    })
    
    with open(registry_path, 'w') as f:
        json.dump(registry, f, indent=2)
    
    print(f"   ✅ Registry updated: {len(results)} bidirectional packs")
    
    # Summary
    print(f"\n📊 CONSOLIDATION SUMMARY")
    print("=" * 60)
    print(f"✅ Successfully converted: {len(results)} language packs")
    print(f"📈 Total entries: {sum(r['total_entries'] for r in results):,}")
    print(f"💾 Total size: {sum(r['size_mb'] for r in results):.1f} MB")
    print(f"📋 Registry: {registry_path}")
    
    if results:
        print(f"\n🎯 Converted packs:")
        for result in results:
            print(f"   {result['id']}: {result['forward_entries']:,} entries → {result['size_mb']} MB")
    
    return results

if __name__ == "__main__":
    try:
        results = consolidate_language_packs()
        if results:
            print(f"\n✅ Consolidation completed successfully!")
        else:
            print(f"\n❌ No packs were converted")
    except Exception as e:
        print(f"\n❌ Consolidation failed: {e}")
        import traceback
        traceback.print_exc()