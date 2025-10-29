#!/usr/bin/env python3
"""
Single Language Pack Generator
Generates, verifies, and prepares one language pack at a time for systematic deployment
"""

import subprocess
import sqlite3
import zipfile
import hashlib
import json
import shutil
import time
import re
import logging
import sys
import argparse
from pathlib import Path
from typing import Dict, List, Tuple, Optional

# Language pack configuration - proven Wiktionary sources
LANGUAGE_CONFIGS = {
    'pt-en': {
        'name': 'Portuguese ↔ English',
        'source_lang': 'pt',
        'target_lang': 'en',
        'url': 'https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/Portuguese-English%20Wiktionary%20dictionary%20stardict.tar.gz',
        'expected_entries': 20000,
        'emoji': '🇵🇹'
    },
    'ru-en': {
        'name': 'Russian ↔ English',
        'source_lang': 'ru',
        'target_lang': 'en',
        'url': 'https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/Russian-English%20Wiktionary%20dictionary%20stardict.tar.gz',
        'expected_entries': 45000,
        'emoji': '🇷🇺'
    },
    'ja-en': {
        'name': 'Japanese ↔ English',
        'source_lang': 'ja',
        'target_lang': 'en',
        'url': 'https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/Japanese-English%20Wiktionary%20dictionary%20stardict.tar.gz',
        'expected_entries': 30000,
        'emoji': '🇯🇵'
    },
    'ko-en': {
        'name': 'Korean ↔ English',
        'source_lang': 'ko',
        'target_lang': 'en',
        'url': 'https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/Korean-English%20Wiktionary%20dictionary%20stardict.tar.gz',
        'expected_entries': 15000,
        'emoji': '🇰🇷'
    },
    'zh-en': {
        'name': 'Chinese ↔ English',
        'source_lang': 'zh',
        'target_lang': 'en',
        'url': 'https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/Chinese-English%20Wiktionary%20dictionary%20stardict.tar.gz',
        'expected_entries': 40000,
        'emoji': '🇨🇳'
    },
    'ar-en': {
        'name': 'Arabic ↔ English',
        'source_lang': 'ar',
        'target_lang': 'en',
        'url': 'https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/Arabic-English%20Wiktionary%20dictionary%20stardict.tar.gz',
        'expected_entries': 20000,
        'emoji': '🇸🇦'
    },
    'hi-en': {
        'name': 'Hindi ↔ English',
        'source_lang': 'hi',
        'target_lang': 'en',
        'url': 'https://raw.githubusercontent.com/Vuizur/Wiktionary-Dictionaries/master/Hindi-English%20Wiktionary%20dictionary%20stardict.tar.gz',
        'expected_entries': 15000,
        'emoji': '🇮🇳'
    }
}

class SingleLanguageGenerator:
    def __init__(self, language_id: str):
        self.language_id = language_id
        self.config = LANGUAGE_CONFIGS.get(language_id)
        if not self.config:
            raise ValueError(f"Language {language_id} not supported. Available: {list(LANGUAGE_CONFIGS.keys())}")
        
        # Set up directories
        self.base_dir = Path(__file__).parent.parent
        self.temp_dir = self.base_dir / "temp" / language_id
        self.logs_dir = self.base_dir / "logs"
        self.completed_dir = self.base_dir / "completed_packs"
        self.tools_dir = self.base_dir.parent / "tools"
        
        # Create directories
        for dir_path in [self.temp_dir, self.logs_dir, self.completed_dir]:
            dir_path.mkdir(parents=True, exist_ok=True)
        
        # Set up logging
        self.setup_logging()
        
        self.logger.info(f"🚀 Initializing Single Language Generator for {self.config['name']}")
        self.logger.info(f"📁 Working directories created")
        self.logger.info(f"🎯 Target: {self.config['expected_entries']:,} expected entries")

    def setup_logging(self):
        """Set up comprehensive logging"""
        log_file = self.logs_dir / f"{self.language_id}_{time.strftime('%Y%m%d_%H%M%S')}.log"
        
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger(f"single_gen_{self.language_id}")

    def step(self, step_num: int, total_steps: int, description: str):
        """Log step progress"""
        progress = (step_num / total_steps) * 100
        self.logger.info(f"[{step_num}/{total_steps} - {progress:.1f}%] {description}")

    def build_stardict_pack(self) -> bool:
        """Build StarDict pack using proven tools/build-unified-pack.sh"""
        self.step(1, 6, f"Building StarDict pack for {self.language_id}")
        
        # Check if tools directory exists
        if not self.tools_dir.exists():
            self.logger.error(f"Tools directory not found: {self.tools_dir}")
            return False
        
        build_script = self.tools_dir / "build-unified-pack.sh"
        if not build_script.exists():
            self.logger.error(f"Build script not found: {build_script}")
            return False
        
        self.logger.info(f"📁 Using tools directory: {self.tools_dir}")
        self.logger.info(f"📜 Using build script: {build_script}")
        
        try:
            # Use the proven build script with real-time output
            cmd = [
                "bash", str(build_script),
                self.language_id
            ]
            
            self.logger.info(f"🚀 Running command: {' '.join(cmd)}")
            self.logger.info(f"📥 Downloading and processing {self.config['name']} dictionary...")
            
            # Run with real-time output streaming and longer timeout
            process = subprocess.Popen(
                cmd,
                cwd=self.tools_dir,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                universal_newlines=True
            )
            
            # Stream output in real-time with timeout protection
            output_lines = []
            import select
            import time
            
            start_time = time.time()
            timeout_seconds = 600  # 10 minutes
            
            while True:
                # Check if process is still running
                if process.poll() is not None:
                    break
                
                # Check timeout
                if time.time() - start_time > timeout_seconds:
                    self.logger.error("Build process timed out, terminating...")
                    process.terminate()
                    time.sleep(5)
                    if process.poll() is None:
                        process.kill()
                    return False
                
                # Read output with timeout
                try:
                    if process.stdout in select.select([process.stdout], [], [], 1)[0]:
                        output = process.stdout.readline()
                        if output:
                            line = output.strip()
                            output_lines.append(line)
                            self.logger.info(f"Build: {line}")
                            
                            # Reset timeout on activity
                            start_time = time.time()
                except:
                    # Fallback for systems without select
                    try:
                        output = process.stdout.readline()
                        if output:
                            line = output.strip()
                            output_lines.append(line)
                            self.logger.info(f"Build: {line}")
                            start_time = time.time()
                    except:
                        time.sleep(0.1)
            
            # Ensure process completion
            return_code = process.wait()
            
            if return_code != 0:
                self.logger.error(f"StarDict build failed with return code: {return_code}")
                self.logger.error(f"Last 10 output lines:")
                for line in output_lines[-10:]:
                    self.logger.error(f"  {line}")
                return False
            
            # Check if SQLite file was created
            stardict_sqlite = self.tools_dir / f"tmp-unified-{self.language_id}" / f"{self.language_id}.sqlite"
            if not stardict_sqlite.exists():
                self.logger.error(f"StarDict SQLite not found: {stardict_sqlite}")
                self.logger.info(f"📁 Contents of tools directory:")
                for item in self.tools_dir.iterdir():
                    self.logger.info(f"  {item.name}")
                return False
            
            # Get file size for verification
            size_mb = stardict_sqlite.stat().st_size / 1024 / 1024
            self.logger.info(f"✅ StarDict pack built successfully: {stardict_sqlite} ({size_mb:.1f}MB)")
            return True
            
        except subprocess.TimeoutExpired:
            self.logger.error("StarDict build timed out after 10 minutes")
            return False
        except FileNotFoundError as e:
            self.logger.error(f"File not found during build: {e}")
            return False
        except Exception as e:
            self.logger.error(f"StarDict build error: {e}")
            import traceback
            self.logger.error(f"Full traceback: {traceback.format_exc()}")
            return False

    def convert_to_bidirectional(self) -> Tuple[int, int]:
        """Convert StarDict database to bidirectional format"""
        self.step(2, 6, f"Converting to bidirectional format: {self.language_id}")
        
        source_db = self.tools_dir / f"tmp-unified-{self.language_id}" / f"{self.language_id}.sqlite"
        dest_db = self.temp_dir / f"{self.language_id}.sqlite"
        
        if not source_db.exists():
            self.logger.error(f"Source database not found: {source_db}")
            self.logger.info("📁 Looking for alternative source locations...")
            
            # Try alternative locations
            alt_locations = [
                self.tools_dir / f"{self.language_id}.sqlite",
                self.tools_dir / f"tmp-{self.language_id}" / f"{self.language_id}.sqlite"
            ]
            
            for alt_path in alt_locations:
                if alt_path.exists():
                    self.logger.info(f"✅ Found alternative source: {alt_path}")
                    source_db = alt_path
                    break
            else:
                raise FileNotFoundError(f"Source database not found in any location")
        
        self.logger.info(f"📁 Using source database: {source_db}")
        
        # Connect to source database
        try:
            source_conn = sqlite3.connect(source_db)
            source_cursor = source_conn.cursor()
        except Exception as e:
            self.logger.error(f"Failed to connect to source database: {e}")
            raise
        
        # Get entry count
        source_cursor.execute("SELECT COUNT(*) FROM entries")
        total_source = source_cursor.fetchone()[0]
        self.logger.info(f"Converting {total_source:,} source entries to bidirectional format")
        
        # Create destination database with bidirectional schema
        dest_conn = sqlite3.connect(dest_db)
        dest_cursor = dest_conn.cursor()
        
        # Create bidirectional schema
        dest_conn.executescript("""
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
        CREATE INDEX idx_source_lang ON dictionary_entries(source_language);
        CREATE INDEX idx_target_lang ON dictionary_entries(target_language);
        
        CREATE TABLE pack_metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        """)
        
        # Insert metadata
        metadata = [
            ('pack_id', self.language_id),
            ('source_language', self.config['source_lang']),
            ('target_language', self.config['target_lang']),
            ('pack_type', 'bidirectional'),
            ('schema_version', '2.0'),
            ('created_at', 'CURRENT_TIMESTAMP'),
            ('converted_from', 'stardict')
        ]
        
        dest_cursor.executemany("INSERT INTO pack_metadata (key, value) VALUES (?, ?)", metadata)
        
        # Convert entries to bidirectional format
        self.logger.info("🔄 Starting bidirectional conversion...")
        source_cursor.execute("SELECT word, definition FROM entries")
        forward_count = 0
        reverse_count = 0
        
        batch_size = 1000
        batch = []
        processed = 0
        
        for word, definition in source_cursor:
            processed += 1
            
            # Progress logging every 5000 entries
            if processed % 5000 == 0:
                self.logger.info(f"📊 Processed {processed:,}/{total_source:,} entries ({processed/total_source*100:.1f}%)")
            if not word or not definition:
                continue
            
            # Forward entry (source → target)
            batch.append((
                word.strip(),
                definition.strip(),
                'forward',
                self.config['source_lang'],
                self.config['target_lang']
            ))
            forward_count += 1
            
            # Create reverse entries from HTML content
            if '<' in definition and '>' in definition:
                # Extract English terms from HTML for reverse lookup
                english_terms = re.findall(r'<[^>]*>([^<]+)</[^>]*>', definition)
                for term in english_terms:
                    term = term.strip()
                    if len(term) > 2 and term.replace(' ', '').isalpha():
                        batch.append((
                            term,
                            word.strip(),
                            'reverse',
                            self.config['target_lang'],
                            self.config['source_lang']
                        ))
                        reverse_count += 1
            
            # Process batch
            if len(batch) >= batch_size:
                dest_cursor.executemany(
                    "INSERT INTO dictionary_entries (lemma, definition, direction, source_language, target_language) VALUES (?, ?, ?, ?, ?)",
                    batch
                )
                batch = []
        
        # Process remaining batch
        if batch:
            dest_cursor.executemany(
                "INSERT INTO dictionary_entries (lemma, definition, direction, source_language, target_language) VALUES (?, ?, ?, ?, ?)",
                batch
            )
        
        # Commit and close
        dest_conn.commit()
        source_conn.close()
        dest_conn.close()
        
        total_entries = forward_count + reverse_count
        
        self.logger.info(f"✅ Conversion completed: {forward_count:,} forward + {reverse_count:,} reverse = {total_entries:,} total")
        
        return forward_count, reverse_count

    def verify_pack(self) -> bool:
        """Comprehensive verification of the language pack"""
        self.step(3, 6, f"Verifying {self.language_id}")
        
        db_path = self.temp_dir / f"{self.language_id}.sqlite"
        
        if not db_path.exists():
            self.logger.error(f"Database not found: {db_path}")
            return False
        
        try:
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            
            # Verify schema
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
            tables = [row[0] for row in cursor.fetchall()]
            
            required_tables = {'dictionary_entries', 'pack_metadata'}
            if not required_tables.issubset(set(tables)):
                self.logger.error(f"Missing required tables. Found: {tables}")
                return False
            
            # Verify columns
            cursor.execute("PRAGMA table_info(dictionary_entries)")
            columns = {row[1]: row[2] for row in cursor.fetchall()}
            
            required_columns = {
                'id', 'lemma', 'definition', 'direction', 
                'source_language', 'target_language'
            }
            
            if not required_columns.issubset(set(columns.keys())):
                missing = required_columns - set(columns.keys())
                self.logger.error(f"Missing columns: {missing}")
                return False
            
            # Verify data integrity
            cursor.execute("SELECT COUNT(*) FROM dictionary_entries")
            total_entries = cursor.fetchone()[0]
            
            cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE direction = 'forward'")
            forward_entries = cursor.fetchone()[0]
            
            cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE direction = 'reverse'")
            reverse_entries = cursor.fetchone()[0]
            
            # Check minimum entry threshold
            if total_entries < self.config['expected_entries'] * 0.5:
                self.logger.warning(f"Entry count below expected: {total_entries} < {self.config['expected_entries']}")
            
            # Test lookup functionality
            cursor.execute("SELECT lemma, definition FROM dictionary_entries WHERE direction = 'forward' LIMIT 1")
            forward_test = cursor.fetchone()
            
            if forward_test:
                test_word = forward_test[0]
                cursor.execute(
                    "SELECT lemma, definition FROM dictionary_entries WHERE LOWER(lemma) = LOWER(?) AND direction = 'forward' LIMIT 1",
                    (test_word,)
                )
                lookup_result = cursor.fetchone()
                if not lookup_result:
                    self.logger.error("Forward lookup test failed")
                    return False
            
            conn.close()
            
            self.logger.info(f"✅ Verification passed:")
            self.logger.info(f"   📊 Total entries: {total_entries:,}")
            self.logger.info(f"   📊 Forward entries: {forward_entries:,}")
            self.logger.info(f"   📊 Reverse entries: {reverse_entries:,}")
            self.logger.info(f"   🔍 Schema: Valid")
            self.logger.info(f"   🎯 Lookups: Working")
            
            return True
            
        except Exception as e:
            self.logger.error(f"Verification failed: {e}")
            return False

    def create_zip_package(self) -> bool:
        """Create compressed zip package"""
        self.step(4, 6, f"Creating zip package for {self.language_id}")
        
        db_path = self.temp_dir / f"{self.language_id}.sqlite"
        zip_path = self.completed_dir / f"{self.language_id}.sqlite.zip"
        
        try:
            with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
                zipf.write(db_path, f"{self.language_id}.sqlite")
            
            # Calculate file sizes and checksum
            db_size = db_path.stat().st_size
            zip_size = zip_path.stat().st_size
            compression_ratio = (1 - zip_size / db_size) * 100
            
            with open(zip_path, 'rb') as f:
                checksum = hashlib.sha256(f.read()).hexdigest()
            
            self.logger.info(f"✅ Zip package created:")
            self.logger.info(f"   📦 Original: {db_size / 1024 / 1024:.1f}MB")
            self.logger.info(f"   📦 Compressed: {zip_size / 1024 / 1024:.1f}MB ({compression_ratio:.1f}% reduction)")
            self.logger.info(f"   🔒 SHA-256: {checksum}")
            
            return True
            
        except Exception as e:
            self.logger.error(f"Zip creation failed: {e}")
            return False

    def generate_pack_summary(self) -> Dict:
        """Generate comprehensive pack summary"""
        self.step(5, 6, f"Generating summary for {self.language_id}")
        
        db_path = self.temp_dir / f"{self.language_id}.sqlite"
        zip_path = self.completed_dir / f"{self.language_id}.sqlite.zip"
        
        # Get database stats
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        cursor.execute("SELECT COUNT(*) FROM dictionary_entries")
        total_entries = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE direction = 'forward'")
        forward_entries = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM dictionary_entries WHERE direction = 'reverse'")
        reverse_entries = cursor.fetchone()[0]
        
        conn.close()
        
        # Get file stats
        zip_size = zip_path.stat().st_size
        
        with open(zip_path, 'rb') as f:
            checksum = hashlib.sha256(f.read()).hexdigest()
        
        summary = {
            'language_id': self.language_id,
            'name': self.config['name'],
            'emoji': self.config['emoji'],
            'source_language': self.config['source_lang'],
            'target_language': self.config['target_lang'],
            'total_entries': total_entries,
            'forward_entries': forward_entries,
            'reverse_entries': reverse_entries,
            'zip_size_bytes': zip_size,
            'zip_size_mb': round(zip_size / 1024 / 1024, 1),
            'checksum': checksum,
            'status': 'completed',
            'created_at': time.strftime('%Y-%m-%dT%H:%M:%SZ'),
            'source': 'Wiktionary',
            'schema_version': '2.0'
        }
        
        # Save summary
        summary_path = self.completed_dir / f"{self.language_id}_summary.json"
        with open(summary_path, 'w') as f:
            json.dump(summary, f, indent=2)
        
        self.logger.info(f"✅ Summary generated: {summary_path}")
        return summary

    def cleanup_temp_files(self) -> bool:
        """Clean up temporary files"""
        self.step(6, 6, f"Cleaning up temporary files for {self.language_id}")
        
        try:
            # Remove StarDict temp directory
            stardict_temp = self.tools_dir / f"tmp-unified-{self.language_id}"
            if stardict_temp.exists():
                shutil.rmtree(stardict_temp)
            
            # Keep the converted SQLite in temp for verification but clean up StarDict files
            self.logger.info(f"✅ Temporary files cleaned up")
            return True
            
        except Exception as e:
            self.logger.error(f"Cleanup failed: {e}")
            return False

    def generate(self) -> bool:
        """Main generation pipeline"""
        self.logger.info(f"\n{self.config['emoji']} GENERATING {self.config['name'].upper()}")
        self.logger.info("=" * 80)
        
        start_time = time.time()
        
        try:
            # Step 1: Build StarDict pack
            if not self.build_stardict_pack():
                return False
            
            # Step 2: Convert to bidirectional
            forward_count, reverse_count = self.convert_to_bidirectional()
            
            # Step 3: Verify pack
            if not self.verify_pack():
                return False
            
            # Step 4: Create zip package
            if not self.create_zip_package():
                return False
            
            # Step 5: Generate summary
            summary = self.generate_pack_summary()
            
            # Step 6: Cleanup
            if not self.cleanup_temp_files():
                return False
            
            # Success summary
            duration = time.time() - start_time
            
            self.logger.info(f"\n🎉 SUCCESS: {self.config['name']} language pack completed!")
            self.logger.info("=" * 80)
            self.logger.info(f"📊 Entries: {summary['total_entries']:,} ({summary['forward_entries']:,} forward + {summary['reverse_entries']:,} reverse)")
            self.logger.info(f"📦 Size: {summary['zip_size_mb']}MB compressed")
            self.logger.info(f"⏱️ Duration: {duration:.1f}s")
            self.logger.info(f"📁 Location: {self.completed_dir / f'{self.language_id}.sqlite.zip'}")
            self.logger.info(f"🔒 SHA-256: {summary['checksum']}")
            
            return True
            
        except Exception as e:
            self.logger.error(f"Generation failed: {e}")
            return False

def main():
    parser = argparse.ArgumentParser(description="Generate single language pack")
    parser.add_argument("language_id", help="Language ID (e.g., pt-en, ru-en)")
    parser.add_argument("--verify-only", action="store_true", help="Only verify existing pack")
    
    args = parser.parse_args()
    
    if args.language_id not in LANGUAGE_CONFIGS:
        print(f"❌ Unsupported language: {args.language_id}")
        print(f"Available languages: {', '.join(LANGUAGE_CONFIGS.keys())}")
        return 1
    
    try:
        generator = SingleLanguageGenerator(args.language_id)
        
        if args.verify_only:
            # Just verify existing pack
            if generator.verify_pack():
                print(f"✅ {args.language_id} verification passed")
                return 0
            else:
                print(f"❌ {args.language_id} verification failed")
                return 1
        else:
            # Full generation
            if generator.generate():
                print(f"\n✅ {args.language_id} generation completed successfully")
                return 0
            else:
                print(f"\n❌ {args.language_id} generation failed")
                return 1
                
    except Exception as e:
        print(f"❌ Error: {e}")
        return 1

if __name__ == "__main__":
    exit(main())