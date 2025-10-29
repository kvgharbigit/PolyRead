#!/usr/bin/env python3
"""
Test script for creating bidirectional language packs
Demonstrates the new single-pack approach with two-level meaning structure
"""

import sqlite3
import os
import tempfile
from pathlib import Path

def create_test_bidirectional_pack():
    """Create a test bidirectional language pack with sample data"""
    
    # Create temporary database
    with tempfile.NamedTemporaryFile(suffix='.sqlite', delete=False) as temp_file:
        db_path = temp_file.name
    
    print(f"Creating test bidirectional pack at: {db_path}")
    
    conn = sqlite3.connect(db_path)
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
        
        # Create indexes
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
            ('pack_id', 'en-es'),
            ('source_language', 'en'),
            ('target_language', 'es'),
            ('pack_type', 'bidirectional'),
            ('schema_version', '2.0'),
            ('created_at', 'CURRENT_TIMESTAMP')
        ]
        cursor.executemany('INSERT INTO pack_metadata (key, value) VALUES (?, ?)', metadata)
        
        # Insert sample bidirectional data with two-level structure
        sample_data = [
            # English → Spanish (forward direction)
            ('run', 'movement: correr, trotar, galopar | operate: funcionar, operar, marchar | manage: dirigir, administrar, manejar | politics: postularse, candidatearse | liquid: gotear, fluir, escurrir', 'forward', 'en', 'es'),
            ('bank', 'finance: banco, entidad financiera | geography: orilla, ribera, margen | aviation: inclinación, ladeamiento', 'forward', 'en', 'es'),
            ('break', 'fracture: romper, quebrar, partir | pause: descanso, pausa, intermedio | opportunity: oportunidad, ocasión', 'forward', 'en', 'es'),
            ('light', 'illumination: luz, iluminación | weight: ligero, liviano | color: claro, pálido', 'forward', 'en', 'es'),
            ('play', 'games: jugar, tocar (música) | theater: obra, representación | sports: jugar, practicar', 'forward', 'en', 'es'),
            
            # Spanish → English (reverse direction)
            ('correr', 'movement: to run, to jog, to sprint | liquid: to flow, to drip, to stream | urgency: to hurry, to rush, to dash', 'reverse', 'es', 'en'),
            ('banco', 'finance: bank, financial institution | furniture: bench, seat | nature: school of fish, shoal', 'reverse', 'es', 'en'),
            ('romper', 'fracture: to break, to shatter, to smash | interrupt: to interrupt, to break off | start: to break out, to burst', 'reverse', 'es', 'en'),
            ('luz', 'illumination: light, illumination, brightness | understanding: enlightenment, insight | electricity: power, electricity', 'reverse', 'es', 'en'),
            ('jugar', 'games: to play, to game | sports: to play, to compete | risk: to gamble, to bet', 'reverse', 'es', 'en'),
        ]
        
        cursor.executemany('''
            INSERT INTO dictionary_entries (lemma, definition, direction, source_language, target_language)
            VALUES (?, ?, ?, ?, ?)
        ''', sample_data)
        
        conn.commit()
        
        # Test the database structure
        print("\n✅ Database created successfully!")
        print("\n📊 Statistics:")
        
        cursor.execute("SELECT direction, COUNT(*) FROM dictionary_entries GROUP BY direction")
        for direction, count in cursor.fetchall():
            print(f"  {direction}: {count} entries")
        
        cursor.execute("SELECT COUNT(*) FROM dictionary_entries")
        total = cursor.fetchone()[0]
        print(f"  Total: {total} entries")
        
        # Test lookups
        print("\n🔍 Test Lookups:")
        
        # English → Spanish
        cursor.execute("SELECT definition FROM dictionary_entries WHERE lemma = ? AND direction = ?", ('run', 'forward'))
        result = cursor.fetchone()
        if result:
            print(f"  'run' (EN→ES): {result[0]}")
        
        # Spanish → English  
        cursor.execute("SELECT definition FROM dictionary_entries WHERE lemma = ? AND direction = ?", ('correr', 'reverse'))
        result = cursor.fetchone()
        if result:
            print(f"  'correr' (ES→EN): {result[0]}")
        
        print(f"\n📁 Test database created: {db_path}")
        print("You can use this database to test the bidirectional lookup system!")
        
        return db_path
        
    finally:
        conn.close()

def demonstrate_parsing():
    """Demonstrate how the definition parsing works"""
    
    print("\n🎯 Definition Parsing Demonstration:")
    
    sample_definition = "movement: correr, trotar, galopar | operate: funcionar, operar, marchar | manage: dirigir, administrar"
    
    print(f"Input: {sample_definition}")
    print("\nParsed structure:")
    
    # Split by | for different meanings
    meanings = sample_definition.split('|')
    
    for meaning in meanings:
        meaning = meaning.strip()
        if ':' in meaning:
            context, synonyms = meaning.split(':', 1)
            synonym_list = [s.strip() for s in synonyms.split(',')]
            print(f"  Context: {context.strip()}")
            print(f"  Synonyms: {synonym_list}")
            print()

if __name__ == "__main__":
    print("🚀 Testing Bidirectional Language Pack Creation")
    print("=" * 50)
    
    # Create test pack
    db_path = create_test_bidirectional_pack()
    
    # Demonstrate parsing
    demonstrate_parsing()
    
    print("\n✅ Test completed!")
    print(f"📄 Database file: {db_path}")
    print("\nNext steps:")
    print("1. Integrate this database format into the app")
    print("2. Update language pack creation scripts")
    print("3. Create new bidirectional packs for existing language pairs")
    print("4. Test the UI with the new bidirectional translation cards")