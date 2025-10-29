#!/usr/bin/env python3
"""
Convert French-English StarDict to bidirectional SQLite format
Uses the exact same schema as German and Spanish packs
"""

import os
import sqlite3
import zipfile
import hashlib
import json
import struct
import gzip
from pathlib import Path
from typing import List, Tuple, Dict
import re

def read_ifo_file(ifo_path: str) -> Dict[str, str]:
    """Read StarDict .ifo file to get dictionary metadata"""
    metadata = {}
    
    with open(ifo_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if '=' in line:
                key, value = line.split('=', 1)
                metadata[key] = value
    
    return metadata

def read_idx_file(idx_path: str) -> List[Tuple[str, int, int]]:
    """Read StarDict .idx file to get word index"""
    words = []
    
    with open(idx_path, 'rb') as f:
        while True:
            # Read null-terminated word
            word_bytes = b''
            while True:
                byte = f.read(1)
                if not byte or byte == b'\x00':
                    break
                word_bytes += byte
            
            if not word_bytes:
                break
                
            try:
                word = word_bytes.decode('utf-8')
            except:
                continue
            
            # Read offset and size
            offset_data = f.read(4)
            size_data = f.read(4)
            
            if len(offset_data) != 4 or len(size_data) != 4:
                break
                
            offset = struct.unpack('>I', offset_data)[0]
            size = struct.unpack('>I', size_data)[0]
            
            words.append((word, offset, size))
    
    return words

def read_dict_file(dict_path: str, offset: int, size: int) -> str:
    """Read definition from StarDict .dict file"""
    # Handle both compressed (.dict.dz) and uncompressed (.dict) files
    if dict_path.endswith('.dz'):
        with gzip.open(dict_path, 'rb') as f:
            f.seek(offset)
            data = f.read(size)
    else:
        with open(dict_path, 'rb') as f:
            f.seek(offset)
            data = f.read(size)
    
    try:
        # Try UTF-8 first
        return data.decode('utf-8').strip()
    except:
        try:
            # Fallback to latin-1
            return data.decode('latin-1').strip()
        except:
            return str(data).strip()

def parse_stardict_entry(definition: str) -> Tuple[str, str]:
    """Parse StarDict definition to extract clean translation"""
    # Remove HTML tags but keep content
    definition = re.sub(r'<[^>]+>', '', definition)
    
    # Remove pronunciation guides in brackets
    definition = re.sub(r'\[([^\]]+)\]', '', definition)
    
    # Extract main translation (often the first line or before semicolon)
    lines = definition.split('\n')
    main_def = lines[0].strip()
    
    # If there's a semicolon, take the part before it as primary translation
    if ';' in main_def:
        main_def = main_def.split(';')[0].strip()
    
    # Remove leading numbers (1., 2., etc.)
    main_def = re.sub(r'^\d+\.\s*', '', main_def)
    
    # Clean up extra whitespace
    main_def = ' '.join(main_def.split())
    
    return main_def, definition

def convert_stardict_to_bidirectional(stardict_dir: str, output_path: str):
    """Convert StarDict dictionary to bidirectional SQLite format"""
    
    stardict_path = Path(stardict_dir)
    dict_files = list(stardict_path.glob("*.dict*"))
    ifo_files = list(stardict_path.glob("*.ifo"))
    idx_files = list(stardict_path.glob("*.idx"))
    
    if not dict_files or not ifo_files or not idx_files:
        raise ValueError(f"StarDict files not found in {stardict_dir}")
    
    dict_file = dict_files[0]
    ifo_file = ifo_files[0]
    idx_file = idx_files[0]
    
    print(f"📖 Converting StarDict files:")
    print(f"   📄 Dictionary: {dict_file.name}")
    print(f"   📋 Index: {idx_file.name}")
    print(f"   ℹ️ Info: {ifo_file.name}")
    
    # Read metadata
    metadata = read_ifo_file(str(ifo_file))
    print(f"   📊 Dictionary: {metadata.get('bookname', 'Unknown')}")
    print(f"   📈 Word count: {metadata.get('wordcount', 'Unknown')}")
    
    # Read word index
    words = read_idx_file(str(idx_file))
    print(f"   📝 Loaded {len(words)} word entries")
    
    # Create bidirectional database
    conn = sqlite3.connect(output_path)
    cursor = conn.cursor()
    
    try:
        # Create bidirectional schema (same as German/Spanish)
        cursor.execute('''
            CREATE TABLE dictionary_entries (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                lemma TEXT NOT NULL,
                definition TEXT NOT NULL,
                direction TEXT NOT NULL CHECK (direction IN ('forward', 'reverse')),
                source_language TEXT NOT NULL,
                target_language TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        ''')
        
        # Create indexes for fast bidirectional lookup
        cursor.execute('CREATE INDEX idx_lemma_direction ON dictionary_entries(lemma, direction);')
        cursor.execute('CREATE INDEX idx_direction ON dictionary_entries(direction);')
        cursor.execute('CREATE INDEX idx_languages ON dictionary_entries(source_language, target_language);')
        
        # Create metadata table
        cursor.execute('''
            CREATE TABLE pack_metadata (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
        ''')
        
        # Insert metadata
        pack_metadata = [
            ('pack_id', 'fr-en'),
            ('source_language', 'fr'),
            ('target_language', 'en'),
            ('pack_type', 'bidirectional'),
            ('schema_version', '2.0'),
            ('created_at', 'CURRENT_TIMESTAMP'),
            ('converted_from', 'stardict'),
            ('source_dict', metadata.get('bookname', 'French-English Wiktionary'))
        ]
        cursor.executemany('INSERT INTO pack_metadata (key, value) VALUES (?, ?)', pack_metadata)
        
        forward_entries = []
        reverse_entries = []
        
        # Process each word entry
        for i, (word, offset, size) in enumerate(words):
            if i % 1000 == 0:
                print(f"   Processing {i}/{len(words)} entries...")
            
            try:
                # Read definition from dict file
                definition = read_dict_file(str(dict_file), offset, size)
                
                if not definition or len(definition.strip()) == 0:
                    continue
                
                # Parse the definition
                clean_def, full_def = parse_stardict_entry(definition)
                
                if not clean_def or len(clean_def.strip()) == 0:
                    continue
                
                # Add forward entry (French → English)
                forward_entries.append((word.strip(), clean_def.strip()))
                
                # Create reverse entry (English → French)
                # Use the clean definition as the lemma and the word as the definition
                if clean_def != word:  # Avoid circular definitions
                    reverse_entries.append((clean_def.strip(), word.strip()))
                
            except Exception as e:
                print(f"Error processing {word}: {e}")
                continue
        
        # Insert forward entries (French → English)
        print(f"📝 Inserting {len(forward_entries)} forward entries (fr→en)...")
        cursor.executemany('''
            INSERT INTO dictionary_entries (lemma, definition, direction, source_language, target_language)
            VALUES (?, ?, 'forward', 'fr', 'en')
        ''', forward_entries)
        
        # Insert reverse entries (English → French) 
        print(f"📝 Inserting {len(reverse_entries)} reverse entries (en→fr)...")
        cursor.executemany('''
            INSERT INTO dictionary_entries (lemma, definition, direction, source_language, target_language)
            VALUES (?, ?, 'reverse', 'en', 'fr')
        ''', reverse_entries)
        
        conn.commit()
        
        # Get final counts
        cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE direction = 'forward'")
        forward_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE direction = 'reverse'")
        reverse_count = cursor.fetchone()[0]
        
        print(f"✅ Created bidirectional database:")
        print(f"   Forward (fr→en): {forward_count:,} entries")
        print(f"   Reverse (en→fr): {reverse_count:,} entries")
        print(f"   Total: {forward_count + reverse_count:,} entries")
        
        return forward_count, reverse_count
        
    finally:
        conn.close()

def calculate_sha256(file_path: Path) -> str:
    """Calculate SHA-256 checksum of file"""
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            sha256_hash.update(chunk)
    return sha256_hash.hexdigest()

def main():
    """Convert French StarDict to bidirectional language pack"""
    print("🇫🇷🇬🇧 Converting French-English StarDict to Bidirectional Pack")
    print("=" * 80)
    
    stardict_dir = "temp_french/French-English Wiktionary dictionary stardict"
    output_dir = Path("assets/language_packs")
    output_dir.mkdir(exist_ok=True)
    
    # Convert StarDict to SQLite
    temp_db = output_dir / "fr-en.sqlite"
    forward_count, reverse_count = convert_stardict_to_bidirectional(stardict_dir, str(temp_db))
    
    # Create zip package
    zip_path = output_dir / "fr-en.sqlite.zip"
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zip_ref:
        zip_ref.write(temp_db, "fr-en.sqlite")
    
    # Calculate file info
    file_size = zip_path.stat().st_size
    checksum = calculate_sha256(zip_path)
    
    print(f"\n📦 Package created:")
    print(f"   Database: {temp_db}")
    print(f"   Package: {zip_path}")
    print(f"   Size: {file_size:,} bytes ({file_size/1024/1024:.1f} MB)")
    print(f"   Entries: {forward_count + reverse_count:,} total")
    print(f"   SHA-256: {checksum}")
    
    # Create manifest entry
    manifest_entry = {
        "id": "fr-en",
        "name": "French ↔ English Dictionary (Bidirectional)",
        "language": "fr",
        "version": "2.0.0",
        "description": "Single bidirectional dictionary with optimized lookup for both French ↔ English directions",
        "pack_type": "bidirectional",
        "total_entries": forward_count + reverse_count,
        "forward_entries": forward_count,
        "reverse_entries": reverse_count,
        "size_bytes": file_size,
        "size_mb": round(file_size / 1024 / 1024, 1),
        "checksum": checksum,
        "source": "wiktionary-stardict",
        "created_date": "2025-10-29"
    }
    
    # Save manifest entry
    manifest_path = output_dir / "fr-en-manifest.json"
    with open(manifest_path, 'w', encoding='utf-8') as f:
        json.dump(manifest_entry, f, indent=2, ensure_ascii=False)
    
    print(f"\n✅ French↔English pack created successfully!")
    print(f"📋 Manifest: {manifest_path}")
    
    return True

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)