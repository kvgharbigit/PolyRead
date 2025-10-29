#!/usr/bin/env python3
"""
Create French↔English bidirectional language pack from Wiktionary data
Uses similar extraction strategy as German and Spanish packs
"""

import sqlite3
import zipfile
import hashlib
import json
import requests
import time
import re
from pathlib import Path
from typing import Dict, List, Tuple, Set
from urllib.parse import quote

def extract_french_to_english() -> List[Tuple[str, str]]:
    """Extract French→English translations from Wiktionary"""
    print("🇫🇷 Extracting French→English translations from Wiktionary...")
    
    # French Wiktionary API for English translations
    base_url = "https://fr.wiktionary.org/w/api.php"
    
    # Common French words to start with
    french_words = [
        # Basic vocabulary
        "le", "de", "et", "à", "un", "il", "être", "et", "en", "avoir", "que", "pour",
        "dans", "ce", "son", "une", "sur", "avec", "ne", "se", "pas", "tout", "plus",
        "par", "grand", "en", "me", "bien", "te", "si", "tout", "mais", "y",
        
        # Common nouns
        "maison", "eau", "feu", "terre", "air", "temps", "jour", "nuit", "homme", "femme",
        "enfant", "père", "mère", "frère", "soeur", "ami", "amie", "travail", "école",
        "livre", "voiture", "chien", "chat", "arbre", "fleur", "pain", "lait", "café",
        
        # Verbs
        "aller", "venir", "faire", "dire", "voir", "savoir", "pouvoir", "falloir",
        "devoir", "vouloir", "donner", "prendre", "partir", "sortir", "mettre", "tenir",
        "sembler", "laisser", "devenir", "porter", "parler", "montrer", "demander",
        
        # Adjectives  
        "grand", "petit", "bon", "mauvais", "beau", "nouveau", "vieux", "jeune",
        "blanc", "noir", "rouge", "bleu", "vert", "jaune", "français", "autre",
        "même", "premier", "dernier", "seul", "vrai", "possible", "libre", "sûr"
    ]
    
    entries = []
    processed = set()
    
    for word in french_words:
        if word in processed:
            continue
            
        try:
            # Get Wiktionary page content
            params = {
                'action': 'query',
                'format': 'json',
                'titles': word,
                'prop': 'wikitext',
                'formatversion': 2
            }
            
            response = requests.get(base_url, params=params)
            data = response.json()
            
            if 'query' in data and 'pages' in data['query']:
                for page in data['query']['pages']:
                    if 'wikitext' in page:
                        wikitext = page['wikitext']
                        translations = parse_french_wikitext(wikitext, word)
                        
                        for translation in translations:
                            if translation and translation != word:
                                entries.append((word, translation))
                                processed.add(word)
            
            time.sleep(0.1)  # Rate limiting
            
        except Exception as e:
            print(f"Error processing {word}: {e}")
            continue
    
    print(f"✅ Extracted {len(entries)} French→English entries")
    return entries

def extract_english_to_french() -> List[Tuple[str, str]]:
    """Extract English→French translations from Wiktionary"""
    print("🇬🇧 Extracting English→French translations from Wiktionary...")
    
    # English Wiktionary API for French translations
    base_url = "https://en.wiktionary.org/w/api.php"
    
    # Common English words
    english_words = [
        # Basic vocabulary
        "the", "of", "and", "to", "a", "in", "is", "it", "you", "that", "he", "was",
        "for", "on", "are", "as", "with", "his", "they", "i", "at", "be", "this",
        "have", "from", "or", "one", "had", "by", "word", "but", "not", "what",
        
        # Common nouns
        "house", "water", "fire", "earth", "air", "time", "day", "night", "man", "woman",
        "child", "father", "mother", "brother", "sister", "friend", "work", "school",
        "book", "car", "dog", "cat", "tree", "flower", "bread", "milk", "coffee",
        
        # Verbs
        "go", "come", "make", "say", "see", "know", "can", "should", "must", "want",
        "give", "take", "leave", "put", "hold", "seem", "let", "become", "carry",
        "speak", "show", "ask", "tell", "think", "feel", "look", "find", "get",
        
        # Adjectives
        "big", "small", "good", "bad", "beautiful", "new", "old", "young", "white",
        "black", "red", "blue", "green", "yellow", "french", "other", "same",
        "first", "last", "only", "true", "possible", "free", "sure", "right"
    ]
    
    entries = []
    processed = set()
    
    for word in english_words:
        if word in processed:
            continue
            
        try:
            # Get Wiktionary page content
            params = {
                'action': 'query',
                'format': 'json',
                'titles': word,
                'prop': 'wikitext',
                'formatversion': 2
            }
            
            response = requests.get(base_url, params=params)
            data = response.json()
            
            if 'query' in data and 'pages' in data['query']:
                for page in data['query']['pages']:
                    if 'wikitext' in page:
                        wikitext = page['wikitext']
                        translations = parse_english_wikitext_for_french(wikitext, word)
                        
                        for translation in translations:
                            if translation and translation != word:
                                entries.append((word, translation))
                                processed.add(word)
            
            time.sleep(0.1)  # Rate limiting
            
        except Exception as e:
            print(f"Error processing {word}: {e}")
            continue
    
    print(f"✅ Extracted {len(entries)} English→French entries")
    return entries

def parse_french_wikitext(wikitext: str, word: str) -> List[str]:
    """Parse French Wiktionary page for English translations"""
    translations = []
    
    # Look for English translations in French Wiktionary format
    # Pattern: {{trad|en|translation}}
    en_pattern = r'\{\{trad\|en\|([^}]+)\}\}'
    matches = re.findall(en_pattern, wikitext)
    
    for match in matches:
        # Clean up the translation
        translation = match.strip()
        if translation and len(translation) > 0:
            translations.append(translation)
    
    # Also look for direct translation patterns
    # Pattern: '''English''': translation
    direct_pattern = r"'''[Aa]nglais'''[:\s]*([^<\n]+)"
    matches = re.findall(direct_pattern, wikitext)
    
    for match in matches:
        # Extract individual translations (often comma-separated)
        trans_list = [t.strip() for t in match.split(',')]
        for trans in trans_list:
            if trans and len(trans) > 0 and not re.search(r'[{}|\[\]]', trans):
                translations.append(trans)
    
    return translations[:5]  # Limit to top 5 translations

def parse_english_wikitext_for_french(wikitext: str, word: str) -> List[str]:
    """Parse English Wiktionary page for French translations"""
    translations = []
    
    # Look for French translations in English Wiktionary format
    # Pattern: * French: {{t|fr|translation}}
    fr_pattern = r'\* French:[^\n]*\{\{t\|fr\|([^}]+)\}\}'
    matches = re.findall(fr_pattern, wikitext)
    
    for match in matches:
        translation = match.strip()
        if translation and len(translation) > 0:
            translations.append(translation)
    
    # Also look for simpler patterns
    # Pattern: French: [[translation]]
    bracket_pattern = r'French:[^\n]*\[\[([^\]]+)\]\]'
    matches = re.findall(bracket_pattern, wikitext)
    
    for match in matches:
        translation = match.strip()
        if translation and len(translation) > 0:
            translations.append(translation)
    
    return translations[:5]  # Limit to top 5 translations

def create_french_bidirectional_database(output_path: str, french_entries: List[Tuple[str, str]], english_entries: List[Tuple[str, str]]):
    """Create bidirectional French↔English database"""
    print(f"🗄️ Creating bidirectional database: {output_path}")
    
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
            ('pack_id', 'fr-en'),
            ('source_language', 'fr'),
            ('target_language', 'en'),
            ('pack_type', 'bidirectional'),
            ('schema_version', '2.0'),
            ('created_at', 'CURRENT_TIMESTAMP'),
            ('converted_from', 'wiktionary')
        ]
        cursor.executemany('INSERT INTO pack_metadata (key, value) VALUES (?, ?)', metadata)
        
        # Insert French→English entries (forward direction)
        print(f"📝 Inserting {len(french_entries)} French→English entries...")
        for lemma, definition in french_entries:
            cursor.execute('''
                INSERT INTO dictionary_entries (lemma, definition, direction, source_language, target_language)
                VALUES (?, ?, 'forward', 'fr', 'en')
            ''', (lemma, definition))
        
        # Insert English→French entries (reverse direction)
        print(f"📝 Inserting {len(english_entries)} English→French entries...")
        for lemma, definition in english_entries:
            cursor.execute('''
                INSERT INTO dictionary_entries (lemma, definition, direction, source_language, target_language)
                VALUES (?, ?, 'reverse', 'en', 'fr')
            ''', (lemma, definition))
        
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
    """Create French↔English bidirectional language pack"""
    print("🇫🇷🇬🇧 Creating French↔English Bidirectional Language Pack")
    print("=" * 80)
    
    output_dir = Path("assets/language_packs")
    output_dir.mkdir(exist_ok=True)
    
    # Extract translations from Wiktionary
    french_entries = extract_french_to_english()
    english_entries = extract_english_to_french()
    
    if not french_entries and not english_entries:
        print("❌ No translations extracted. Check Wiktionary connectivity.")
        return False
    
    # Create temporary database
    temp_db = output_dir / "fr-en.sqlite"
    forward_count, reverse_count = create_french_bidirectional_database(
        str(temp_db), french_entries, english_entries
    )
    
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
        "source": "wiktionary",
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