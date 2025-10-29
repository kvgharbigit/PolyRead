#!/usr/bin/env python3
"""
Create bidirectional language packs for PolyRead
Eliminates redundant companion pack system by storing both directions in a single database
"""

import os
import sqlite3
import zipfile
import shutil
import json
import hashlib
from pathlib import Path
from typing import Dict, List, Tuple

def create_bidirectional_pack(source_dict_path: str, source_lang: str, target_lang: str, output_dir: str):
    """Create a single bidirectional language pack from source dictionary data"""
    
    pack_id = f"{source_lang}-{target_lang}"
    output_path = Path(output_dir) / f"{pack_id}.sqlite.zip"
    temp_dir = Path(output_dir) / "temp"
    temp_dir.mkdir(exist_ok=True)
    
    print(f"Creating bidirectional pack: {pack_id}")
    print(f"Source: {source_dict_path}")
    print(f"Output: {output_path}")
    
    try:
        # Create bidirectional database
        db_path = temp_dir / f"{pack_id}.sqlite"
        create_bidirectional_database(source_dict_path, db_path, source_lang, target_lang)
        
        # Create zip file
        with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as zip_ref:
            zip_ref.write(db_path, f"{pack_id}.sqlite")
        
        # Calculate file info
        file_size = output_path.stat().st_size
        checksum = calculate_sha256(output_path)
        
        print(f"✅ Created bidirectional pack: {output_path}")
        print(f"   Size: {file_size:,} bytes ({file_size/1024/1024:.1f} MB)")
        print(f"   SHA-256: {checksum}")
        
        return {
            'id': pack_id,
            'file_path': str(output_path),
            'size_bytes': file_size,
            'size_mb': round(file_size / 1024 / 1024, 1),
            'checksum': checksum
        }
        
    finally:
        # Cleanup
        if temp_dir.exists():
            shutil.rmtree(temp_dir)

def create_bidirectional_database(source_path: str, output_path: str, source_lang: str, target_lang: str):
    """Create a bidirectional database with both lookup directions"""
    
    conn = sqlite3.connect(output_path)
    cursor = conn.cursor()
    
    try:
        # Create bidirectional schema
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
        metadata = [
            ('pack_id', f"{source_lang}-{target_lang}"),
            ('source_language', source_lang),
            ('target_language', target_lang),
            ('pack_type', 'bidirectional'),
            ('schema_version', '2.0'),
            ('created_at', 'CURRENT_TIMESTAMP')
        ]
        cursor.executemany('INSERT INTO pack_metadata (key, value) VALUES (?, ?)', metadata)
        
        # Load source data and create bidirectional entries
        forward_entries, reverse_entries = parse_source_dictionary(source_path, source_lang, target_lang)
        
        print(f"Creating {len(forward_entries)} forward entries ({source_lang}→{target_lang})")
        cursor.executemany('''
            INSERT INTO dictionary_entries (lemma, definition, direction, source_language, target_language)
            VALUES (?, ?, 'forward', ?, ?)
        ''', [(lemma, definition, source_lang, target_lang) for lemma, definition in forward_entries])
        
        print(f"Creating {len(reverse_entries)} reverse entries ({target_lang}→{source_lang})")
        cursor.executemany('''
            INSERT INTO dictionary_entries (lemma, definition, direction, source_language, target_language)
            VALUES (?, ?, 'reverse', ?, ?)
        ''', [(lemma, definition, target_lang, source_lang) for lemma, definition in reverse_entries])
        
        conn.commit()
        print(f"✅ Created bidirectional database with {len(forward_entries) + len(reverse_entries)} total entries")
        
    finally:
        conn.close()

def parse_source_dictionary(source_path: str, source_lang: str, target_lang: str) -> Tuple[List[Tuple[str, str]], List[Tuple[str, str]]]:
    """Parse source dictionary and extract both forward and reverse entries"""
    
    forward_entries = []
    reverse_entries = []
    
    # Handle different source formats
    if source_path.endswith('.zip'):
        # Extract and process zip file
        temp_dir = Path(source_path).parent / "parse_temp"
        temp_dir.mkdir(exist_ok=True)
        
        try:
            with zipfile.ZipFile(source_path, 'r') as zip_ref:
                zip_ref.extractall(temp_dir)
            
            # Find SQLite file in extracted content
            sqlite_files = list(temp_dir.glob("*.sqlite"))
            if sqlite_files:
                forward_entries, reverse_entries = parse_sqlite_dictionary(sqlite_files[0], source_lang, target_lang)
        
        finally:
            if temp_dir.exists():
                shutil.rmtree(temp_dir)
    
    elif source_path.endswith('.sqlite'):
        forward_entries, reverse_entries = parse_sqlite_dictionary(source_path, source_lang, target_lang)
    
    return forward_entries, reverse_entries

def parse_sqlite_dictionary(db_path: str, source_lang: str, target_lang: str) -> Tuple[List[Tuple[str, str]], List[Tuple[str, str]]]:
    """Parse SQLite dictionary and extract bidirectional entries"""
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    forward_entries = []
    reverse_entries = []
    
    try:
        # Check database structure
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
        tables = [row[0] for row in cursor.fetchall()]
        
        if 'word' in tables:
            # StarDict format
            cursor.execute("SELECT w, m FROM word WHERE w IS NOT NULL AND m IS NOT NULL")
            rows = cursor.fetchall()
            
            for word, meaning in rows:
                # Forward entry (source → target)
                forward_entries.append((word, meaning))
                
                # Create reverse entries by parsing definitions
                reverse_words = extract_reverse_translations(meaning, target_lang)
                for reverse_word in reverse_words:
                    if reverse_word and len(reverse_word.strip()) > 0:
                        reverse_entries.append((reverse_word.strip(), word))
        
        elif 'dict' in tables:
            # PolyRead format
            cursor.execute("SELECT lemma, def FROM dict WHERE lemma IS NOT NULL AND def IS NOT NULL")
            rows = cursor.fetchall()
            
            for lemma, definition in rows:
                forward_entries.append((lemma, definition))
                
                # Create reverse entries
                reverse_words = extract_reverse_translations(definition, target_lang)
                for reverse_word in reverse_words:
                    if reverse_word and len(reverse_word.strip()) > 0:
                        reverse_entries.append((reverse_word.strip(), lemma))
    
    finally:
        conn.close()
    
    # Remove duplicates while preserving order
    forward_entries = list(dict.fromkeys(forward_entries))
    reverse_entries = list(dict.fromkeys(reverse_entries))
    
    return forward_entries, reverse_entries

def extract_reverse_translations(definition: str, target_lang: str) -> List[str]:
    """Extract reverse translation words from definition text"""
    
    # Simple extraction for common patterns
    # This is a basic implementation - could be enhanced with NLP
    
    reverse_words = []
    
    # Remove HTML tags
    import re
    clean_def = re.sub(r'<[^>]+>', '', definition)
    
    # Split by common separators
    separators = [';', '|', ',', '\n']
    words = [clean_def]
    
    for sep in separators:
        new_words = []
        for word in words:
            new_words.extend(word.split(sep))
        words = new_words
    
    # Clean and filter words
    for word in words:
        word = word.strip()
        # Filter out very short words, numbers, and common non-words
        if len(word) > 2 and not word.isdigit() and word.isalpha():
            # Basic filtering for common target languages
            if target_lang == 'en':
                # English words
                if not any(char in word for char in ['ä', 'ö', 'ü', 'ß', 'ñ', 'á', 'é', 'í', 'ó', 'ú']):
                    reverse_words.append(word)
            else:
                reverse_words.append(word)
    
    return reverse_words[:10]  # Limit to avoid too many reverse entries

def calculate_sha256(file_path: Path) -> str:
    """Calculate SHA-256 checksum of a file"""
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            sha256_hash.update(chunk)
    return sha256_hash.hexdigest()

def update_registry_for_bidirectional_packs(pack_infos: List[Dict], registry_path: str):
    """Update registry to reflect new bidirectional pack system"""
    
    # Load existing registry
    with open(registry_path, 'r') as f:
        registry = json.load(f)
    
    # Update strategy and version
    registry['strategy'] = 'single_pack_bidirectional'
    registry['schema_version'] = '2.0'
    registry['timestamp'] = '2024-10-29T12:00:00Z'
    
    # Replace old packs with new bidirectional ones
    new_packs = []
    for pack_info in pack_infos:
        pack_data = {
            'id': pack_info['id'],
            'name': f"{pack_info['id'].split('-')[0].title()} ↔ {pack_info['id'].split('-')[1].upper()}",
            'description': f"Bidirectional dictionary with optimized lookup performance",
            'source_language': pack_info['id'].split('-')[0],
            'target_language': pack_info['id'].split('-')[1],
            'type': 'bidirectional',
            'pack_type': 'main',
            'companion_pack_id': None,  # No longer needed
            'hidden': False,
            'format': 'sqlite',
            'file': f"{pack_info['id']}.sqlite.zip",
            'size_bytes': pack_info['size_bytes'],
            'size_mb': pack_info['size_mb'],
            'entries': 0,  # Will be calculated from database
            'source': 'Wiktionary',
            'version': '2.0.0',
            'checksum': pack_info['checksum'],
            'download_url': f"https://github.com/kvgharbigit/PolyRead/releases/download/language-packs-v2.0/{pack_info['id']}.sqlite.zip",
            'created': '2024-10-29T12:00:00Z',
            'supports_bidirectional': True,
            'ml_kit_supported': True,
            'schema_version': '2.0'
        }
        new_packs.append(pack_data)
    
    # Update packs list (remove old companion packs)
    registry['packs'] = [pack for pack in registry.get('packs', []) if pack.get('pack_type') != 'companion'] + new_packs
    
    # Save updated registry
    with open(registry_path, 'w') as f:
        json.dump(registry, f, indent=2)
    
    print(f"✅ Updated registry with {len(new_packs)} bidirectional packs")

if __name__ == "__main__":
    # Example usage
    assets_dir = "/Users/kayvangharbi/PycharmProjects/PolyRead/assets/language_packs"
    
    # Create new bidirectional packs
    pack_infos = []
    
    # Create French-English bidirectional pack (as example for new language pair)
    print("Creating new bidirectional language packs...")
    
    # Note: This would require actual Wiktionary data for French
    # For now, we'll focus on updating the system architecture
    print("Bidirectional pack creation system ready!")
    print("To create new language packs:")
    print("1. Extract Wiktionary data for target language pair")
    print("2. Call create_bidirectional_pack() with source data")
    print("3. Upload new pack to GitHub releases")
    print("4. Update registry with new pack information")