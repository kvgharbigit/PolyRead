#!/usr/bin/env python3
"""
Create language packs using PolyBook's original Wiktionary sources
Uses the same Vuizur/Wiktionary-Dictionaries repository that PolyBook used
"""

import os
import sys
import sqlite3
import zipfile
import shutil
import json
import hashlib
import requests
import tempfile
import tarfile
import subprocess
from pathlib import Path
from typing import Dict, List, Tuple, Optional

# PolyBook's verified Wiktionary sources from Vuizur repository
POLYBOOK_SOURCES = {
    'fr-en': {
        'url': 'https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/French-English%20Wiktionary%20dictionary%20stardict.tar.gz',
        'size': '3.2MB',
        'description': 'French-English Wiktionary dictionary'
    },
    'it-en': {
        'url': 'https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/Italian-English%20Wiktionary%20dictionary%20stardict.tar.gz',
        'size': '5.3MB',
        'description': 'Italian-English Wiktionary dictionary'
    },
    'pt-en': {
        'url': 'https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/Portuguese-English%20Wiktionary%20dictionary%20stardict.tar.gz',
        'size': '2.6MB',
        'description': 'Portuguese-English Wiktionary dictionary'
    },
    'ru-en': {
        'url': 'https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/Russian-English%20Wiktionary%20dictionary%20stardict.tar.gz',
        'size': '8.2MB',
        'description': 'Russian-English Wiktionary dictionary'
    },
    'ko-en': {
        'url': 'https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/Korean-English%20Wiktionary%20dictionary%20stardict.tar.gz',
        'size': '2.1MB',
        'description': 'Korean-English Wiktionary dictionary'
    },
    'ja-en': {
        'url': 'https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/Japanese-English%20Wiktionary%20dictionary%20stardict.tar.gz',
        'size': '3.7MB',
        'description': 'Japanese-English Wiktionary dictionary'
    },
    'zh-en': {
        'url': 'https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/Chinese-English%20Wiktionary%20dictionary%20stardict.tar.gz',
        'size': '6.4MB',
        'description': 'Chinese-English Wiktionary dictionary'
    },
    'ar-en': {
        'url': 'https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/Arabic-English%20Wiktionary%20dictionary%20stardict.tar.gz',
        'size': '2.9MB',
        'description': 'Arabic-English Wiktionary dictionary'
    },
    'hi-en': {
        'url': 'https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/Hindi-English%20Wiktionary%20dictionary%20stardict.tar.gz',
        'size': '1.0MB',
        'description': 'Hindi-English Wiktionary dictionary'
    }
}

def download_and_extract_stardict(url: str, work_dir: Path) -> Path:
    """Download and extract StarDict archive from PolyBook's sources"""
    print(f"📥 Downloading from PolyBook source: {url}")
    
    # Download
    response = requests.get(url, stream=True)
    response.raise_for_status()
    
    archive_path = work_dir / "dictionary.tar.gz"
    with open(archive_path, 'wb') as f:
        for chunk in response.iter_content(chunk_size=8192):
            f.write(chunk)
    
    print(f"✅ Downloaded {archive_path.stat().st_size:,} bytes")
    
    # Extract
    with tarfile.open(archive_path, 'r:gz') as tar:
        tar.extractall(work_dir)
    
    # Find .ifo file
    ifo_files = list(work_dir.glob("**/*.ifo"))
    if not ifo_files:
        raise Exception("No .ifo files found in archive")
    
    ifo_path = ifo_files[0]
    dict_dir = ifo_path.parent
    
    print(f"🔍 Found StarDict dictionary: {ifo_path.stem}")
    return dict_dir

def decompress_stardict_files(dict_dir: Path, dict_base: str):
    """Decompress StarDict files if needed (following PolyBook's method)"""
    print("📜 Preparing StarDict files...")
    
    # Decompress .dict.dz if it exists
    dict_dz = dict_dir / f"{dict_base}.dict.dz"
    if dict_dz.exists():
        print(f"  Decompressing {dict_dz.name}...")
        try:
            # Try gzip decompression
            import gzip
            with gzip.open(dict_dz, 'rb') as f_in:
                with open(dict_dir / f"{dict_base}.dict", 'wb') as f_out:
                    f_out.write(f_in.read())
            dict_dz.unlink()
            print("  ✅ Decompressed with gzip")
        except Exception as e:
            print(f"  ❌ Failed to decompress .dict.dz: {e}")
            raise
    
    # Decompress .idx.gz if it exists
    idx_gz = dict_dir / f"{dict_base}.idx.gz"
    if idx_gz.exists():
        print(f"  Decompressing {idx_gz.name}...")
        try:
            import gzip
            with gzip.open(idx_gz, 'rb') as f_in:
                with open(dict_dir / f"{dict_base}.idx", 'wb') as f_out:
                    f_out.write(f_in.read())
            idx_gz.unlink()
            print("  ✅ Decompressed idx.gz")
        except Exception as e:
            print(f"  ❌ Failed to decompress .idx.gz: {e}")
            raise

def convert_stardict_to_sqlite(dict_dir: Path, dict_base: str, output_path: Path) -> Tuple[int, int]:
    """Convert StarDict to SQLite using PyGlossary (PolyBook's method)"""
    print("🔄 Converting StarDict to SQLite using PyGlossary...")
    
    # Check required files exist
    required_files = [f"{dict_base}.ifo", f"{dict_base}.idx", f"{dict_base}.dict"]
    for file in required_files:
        if not (dict_dir / file).exists():
            raise Exception(f"Missing required StarDict file: {file}")
    
    # Set UTF-8 environment (PolyBook's approach)
    env = os.environ.copy()
    env.update({
        'LC_ALL': 'en_US.UTF-8',
        'LANG': 'en_US.UTF-8',
        'PYTHONIOENCODING': 'utf-8'
    })
    
    # Convert using PyGlossary
    sql_path = output_path.with_suffix('.sql')
    ifo_path = dict_dir / f"{dict_base}.ifo"
    
    try:
        subprocess.run([
            'pyglossary', str(ifo_path), str(sql_path),
            '--write-format=Sql',
            '--no-utf8-check',
            '--verbosity=1'
        ], check=True, env=env)
        print("✅ PyGlossary conversion successful")
    except subprocess.CalledProcessError as e:
        print(f"❌ PyGlossary conversion failed: {e}")
        raise
    
    # Import SQL to SQLite and optimize (PolyBook's mobile optimization)
    print("🔄 Importing to SQLite and optimizing for mobile...")
    
    # Create database
    conn = sqlite3.connect(output_path)
    
    try:
        # Import SQL file
        with open(sql_path, 'r', encoding='utf-8', errors='ignore') as f:
            sql_content = f.read()
            conn.executescript(sql_content)
        
        # PolyBook's mobile optimization
        conn.executescript("""
        -- Mobile optimization
        PRAGMA journal_mode=OFF;
        PRAGMA synchronous=OFF;
        PRAGMA cache_size=10000;
        
        -- Clean up any problematic entries in word table
        UPDATE word SET 
            w = TRIM(w),
            m = TRIM(m)
        WHERE w != TRIM(w) OR m != TRIM(m);
        
        -- Remove empty entries
        DELETE FROM word WHERE 
            LENGTH(TRIM(COALESCE(w, ''))) = 0 OR 
            LENGTH(TRIM(COALESCE(m, ''))) = 0;
        
        -- Convert to dict table schema for app compatibility
        CREATE TABLE dict (
            lemma TEXT PRIMARY KEY,
            def TEXT NOT NULL
        );
        
        -- Copy data from word to dict table
        INSERT INTO dict (lemma, def)
        SELECT w as lemma, m as def FROM word 
        WHERE w IS NOT NULL AND m IS NOT NULL 
          AND LENGTH(TRIM(w)) > 0 AND LENGTH(TRIM(m)) > 0;
        """)
        
        # Get statistics
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM dict")
        entry_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM word WHERE LENGTH(TRIM(COALESCE(w, ''))) = 0 OR LENGTH(TRIM(COALESCE(m, ''))) = 0")
        empty_count = cursor.fetchone()[0]
        
        conn.commit()
        print(f"✅ SQLite optimization complete: {entry_count} entries, {empty_count} empty entries removed")
        
        return entry_count, empty_count
        
    finally:
        conn.close()
        # Clean up SQL file
        sql_path.unlink()

def create_bidirectional_database(sqlite_path: Path, source_lang: str, target_lang: str, pack_id: str) -> Tuple[int, int]:
    """Convert the dictionary to bidirectional format with direction field"""
    print("🔄 Converting to bidirectional format...")
    
    bidirectional_path = sqlite_path.with_name(f"{pack_id}_bidirectional.sqlite")
    
    # Open source database
    source_conn = sqlite3.connect(sqlite_path)
    dest_conn = sqlite3.connect(bidirectional_path)
    
    try:
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
            ('created_at', 'CURRENT_TIMESTAMP')
        ]
        dest_conn.executemany('INSERT INTO pack_metadata (key, value) VALUES (?, ?)', metadata)
        
        # Copy data in both directions
        source_cursor = source_conn.cursor()
        source_cursor.execute("SELECT lemma, def FROM dict")
        
        forward_count = 0
        reverse_count = 0
        
        for lemma, definition in source_cursor.fetchall():
            # Insert forward direction (source → target)
            dest_conn.execute("""
                INSERT INTO dictionary_entries (lemma, definition, direction, source_language, target_language)
                VALUES (?, ?, 'forward', ?, ?)
            """, (lemma, definition, source_lang, target_lang))
            forward_count += 1
            
            # For bidirectional: create reverse entries by swapping lemma/definition
            # This assumes the dictionary has both directions in the data
            dest_conn.execute("""
                INSERT INTO dictionary_entries (lemma, definition, direction, source_language, target_language)
                VALUES (?, ?, 'reverse', ?, ?)
            """, (definition, lemma, target_lang, source_lang))
            reverse_count += 1
        
        dest_conn.commit()
        
        print(f"✅ Bidirectional database created: {forward_count} forward + {reverse_count} reverse entries")
        
        # Replace original with bidirectional
        sqlite_path.unlink()
        bidirectional_path.rename(sqlite_path)
        
        return forward_count, reverse_count
        
    finally:
        source_conn.close()
        dest_conn.close()

def create_language_pack(pack_id: str, output_dir: Path) -> Dict:
    """Create a language pack using PolyBook's original Wiktionary sources"""
    if pack_id not in POLYBOOK_SOURCES:
        raise ValueError(f"Unknown pack ID: {pack_id}. Available: {list(POLYBOOK_SOURCES.keys())}")
    
    source_info = POLYBOOK_SOURCES[pack_id]
    source_lang, target_lang = pack_id.split('-')
    
    print(f"\n🚀 Creating {pack_id} language pack from PolyBook sources")
    print(f"📊 Source: {source_info['description']} ({source_info['size']})")
    print(f"📡 URL: {source_info['url']}")
    
    # Create working directory
    work_dir = Path(tempfile.mkdtemp(prefix=f"polybook_{pack_id}_"))
    output_dir.mkdir(exist_ok=True)
    
    try:
        # Step 1: Download and extract StarDict
        dict_dir = download_and_extract_stardict(source_info['url'], work_dir)
        dict_base = next(dict_dir.glob("*.ifo")).stem
        
        # Step 2: Decompress StarDict files if needed
        decompress_stardict_files(dict_dir, dict_base)
        
        # Step 3: Convert to SQLite
        sqlite_path = work_dir / f"{pack_id}.sqlite"
        entry_count, empty_count = convert_stardict_to_sqlite(dict_dir, dict_base, sqlite_path)
        
        # Step 4: Convert to bidirectional format
        forward_count, reverse_count = create_bidirectional_database(sqlite_path, source_lang, target_lang, pack_id)
        
        # Step 5: Create final zip file
        zip_path = output_dir / f"{pack_id}.sqlite.zip"
        with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zip_ref:
            zip_ref.write(sqlite_path, f"{pack_id}.sqlite")
        
        # Calculate final statistics
        file_size = zip_path.stat().st_size
        checksum = hashlib.sha256(zip_path.read_bytes()).hexdigest()
        
        pack_info = {
            'id': pack_id,
            'name': f'{source_lang.upper()} ↔ {target_lang.upper()}',
            'description': f'{source_info["description"]} • Bidirectional',
            'source_language': source_lang,
            'target_language': target_lang,
            'entries': forward_count,  # Total unique words in forward direction
            'total_entries': forward_count + reverse_count,
            'size_bytes': file_size,
            'size_mb': round(file_size / 1024 / 1024, 1),
            'checksum': checksum,
            'source_url': source_info['url'],
            'source_size': source_info['size'],
            'pack_type': 'bidirectional',
            'schema_version': '2.0'
        }
        
        print(f"\n✅ Language pack created successfully!")
        print(f"📄 File: {zip_path}")
        print(f"📊 Size: {file_size:,} bytes ({pack_info['size_mb']} MB)")
        print(f"📈 Entries: {forward_count:,} forward + {reverse_count:,} reverse = {forward_count + reverse_count:,} total")
        print(f"🔐 SHA-256: {checksum}")
        
        return pack_info
        
    finally:
        # Clean up
        shutil.rmtree(work_dir)

def main():
    if len(sys.argv) < 2:
        print("Usage: create_polybook_language_packs.py <pack_id> [output_dir]")
        print(f"Available pack IDs: {', '.join(POLYBOOK_SOURCES.keys())}")
        sys.exit(1)
    
    pack_id = sys.argv[1]
    output_dir = Path(sys.argv[2] if len(sys.argv) > 2 else "assets/language_packs")
    
    try:
        pack_info = create_language_pack(pack_id, output_dir)
        
        # Save pack info to JSON
        info_path = output_dir / f"{pack_id}_info.json"
        with open(info_path, 'w') as f:
            json.dump(pack_info, f, indent=2)
        print(f"📋 Pack info saved to: {info_path}")
        
    except Exception as e:
        print(f"❌ Error creating language pack: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()