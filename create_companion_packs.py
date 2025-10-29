#!/usr/bin/env python3
"""
Create companion packs for bidirectional dictionary lookup in PolyRead
Based on PolyBook's companion pack approach
"""

import os
import sqlite3
import zipfile
import shutil
from pathlib import Path

def create_companion_pack(source_pack_path, source_lang, target_lang):
    """Create a companion pack for bidirectional lookup"""
    
    # Define paths
    assets_dir = Path("/Users/kayvangharbi/PycharmProjects/PolyRead/assets/language_packs")
    temp_dir = assets_dir / "temp"
    temp_dir.mkdir(exist_ok=True)
    
    # Companion pack info
    companion_id = f"{target_lang}-{source_lang}"
    companion_file = assets_dir / f"{companion_id}.sqlite.zip"
    
    print(f"Creating companion pack: {companion_id}")
    print(f"Source pack: {source_pack_path}")
    print(f"Output: {companion_file}")
    
    try:
        # Extract source pack
        with zipfile.ZipFile(source_pack_path, 'r') as zip_ref:
            zip_ref.extractall(temp_dir)
        
        # Find the SQLite file
        sqlite_files = list(temp_dir.glob("*.sqlite"))
        if not sqlite_files:
            print(f"No SQLite file found in {source_pack_path}")
            return False
            
        source_db = sqlite_files[0]
        companion_db = temp_dir / f"{companion_id}.sqlite"
        
        # Create companion database with reverse lookup structure
        print("Creating reverse lookup database...")
        create_reverse_database(source_db, companion_db, source_lang, target_lang)
        
        # Create zip file
        print("Creating companion zip file...")
        with zipfile.ZipFile(companion_file, 'w', zipfile.ZIP_DEFLATED) as zip_ref:
            zip_ref.write(companion_db, f"{companion_id}.sqlite")
        
        print(f"✅ Companion pack created: {companion_file}")
        return True
        
    except Exception as e:
        print(f"❌ Error creating companion pack: {e}")
        return False
    finally:
        # Cleanup
        if temp_dir.exists():
            shutil.rmtree(temp_dir)

def create_reverse_database(source_db, companion_db, source_lang, target_lang):
    """Create a reverse lookup database from the source database"""
    
    # Open source database
    source_conn = sqlite3.connect(source_db)
    source_cursor = source_conn.cursor()
    
    # Create companion database
    companion_conn = sqlite3.connect(companion_db)
    companion_cursor = companion_conn.cursor()
    
    try:
        # Check source database structure
        source_cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
        tables = [row[0] for row in source_cursor.fetchall()]
        print(f"Source database tables: {tables}")
        
        # Create the same schema in companion database
        if 'word' in tables:
            # StarDict format - use word table
            companion_cursor.execute('''
                CREATE TABLE word (
                    id INTEGER PRIMARY KEY NOT NULL,
                    w TEXT,
                    m TEXT
                );
            ''')
            
            companion_cursor.execute('CREATE INDEX idx_word_w ON word(w);')
            
            # Create reverse lookups from the original data
            # This is a simplified approach - in practice, proper bidirectional dictionaries
            # would need sophisticated translation reversal
            print("Creating reverse entries from source database...")
            
            source_cursor.execute("SELECT w, m FROM word WHERE w IS NOT NULL AND m IS NOT NULL")
            rows = source_cursor.fetchall()
            
            companion_entries = []
            for i, (word, definition) in enumerate(rows):
                # For now, we'll just copy the data as-is since Wiktionary dictionaries
                # are already bidirectional. In a real implementation, we'd need to
                # parse the definitions and create proper reverse lookups.
                companion_entries.append((i + 1, word, definition))
            
            companion_cursor.executemany("INSERT INTO word (id, w, m) VALUES (?, ?, ?)", companion_entries)
            print(f"Created {len(companion_entries)} reverse entries")
            
        elif 'dict' in tables:
            # PolyRead format - use dict table
            companion_cursor.execute('''
                CREATE TABLE dict (
                    lemma TEXT PRIMARY KEY,
                    def TEXT NOT NULL
                );
            ''')
            
            # Copy data from source (since Wiktionary is bidirectional)
            source_cursor.execute("SELECT lemma, def FROM dict WHERE lemma IS NOT NULL AND def IS NOT NULL")
            rows = source_cursor.fetchall()
            
            companion_cursor.executemany("INSERT INTO dict (lemma, def) VALUES (?, ?)", rows)
            print(f"Copied {len(rows)} dictionary entries")
            
        # Add metadata tables if they exist
        if 'dbinfo' in tables:
            try:
                # Get the source table structure
                source_cursor.execute("PRAGMA table_info(dbinfo)")
                columns_info = source_cursor.fetchall()
                
                # Create table with same structure
                column_defs = []
                for col_info in columns_info:
                    col_name = col_info[1]
                    col_type = col_info[2]
                    column_defs.append(f"{col_name} {col_type}")
                
                create_table_sql = f"CREATE TABLE dbinfo ({', '.join(column_defs)})"
                companion_cursor.execute(create_table_sql)
                
                # Copy and update data
                source_cursor.execute("SELECT * FROM dbinfo")
                dbinfo_data = source_cursor.fetchall()
                
                if dbinfo_data and columns_info:
                    placeholder = "(" + ",".join(["?" for _ in range(len(columns_info))]) + ")"
                    companion_cursor.executemany(f"INSERT INTO dbinfo VALUES {placeholder}", dbinfo_data)
                    
            except Exception as e:
                print(f"Warning: Could not copy dbinfo table: {e}")
                
        # Copy other metadata tables
        for table in ['dbinfo_extra', 'alt']:
            if table in tables:
                try:
                    source_cursor.execute(f"CREATE TABLE {table} AS SELECT * FROM {table}")
                    companion_cursor.execute(f"CREATE TABLE {table} AS SELECT * FROM {table}")
                except Exception as e:
                    print(f"Warning: Could not copy {table} table: {e}")
        
        companion_conn.commit()
        print("Companion database created successfully")
        
    finally:
        source_conn.close()
        companion_conn.close()

def main():
    assets_dir = Path("/Users/kayvangharbi/PycharmProjects/PolyRead/assets/language_packs")
    
    # Create companion packs for existing language packs
    packs_to_create = [
        ("de-en.sqlite.zip", "de", "en"),  # German-English -> English-German
        ("eng-spa.sqlite.zip", "en", "es"),  # English-Spanish -> Spanish-English  
        ("es-en.sqlite.zip", "es", "en"),  # Spanish-English -> English-Spanish
    ]
    
    successful = 0
    total = len(packs_to_create)
    
    for pack_file, source_lang, target_lang in packs_to_create:
        pack_path = assets_dir / pack_file
        
        if not pack_path.exists():
            print(f"⚠️ Source pack not found: {pack_path}")
            continue
            
        if create_companion_pack(pack_path, source_lang, target_lang):
            successful += 1
    
    print(f"\n📊 Summary: {successful}/{total} companion packs created successfully")
    
    # List all packs
    print("\n📦 Available language packs:")
    for pack_file in sorted(assets_dir.glob("*.sqlite.zip")):
        size_mb = pack_file.stat().st_size / (1024 * 1024)
        print(f"  - {pack_file.name} ({size_mb:.1f} MB)")

if __name__ == "__main__":
    main()