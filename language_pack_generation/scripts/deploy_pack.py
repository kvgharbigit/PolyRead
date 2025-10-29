#!/usr/bin/env python3
"""
Deploy Language Pack to GitHub
Uploads individual language packs to GitHub releases and updates registry
"""

import json
import hashlib
import subprocess
import argparse
import logging
import sys
import time
from pathlib import Path
from typing import Dict, Optional

class PackDeployer:
    def __init__(self, language_id: str):
        self.language_id = language_id
        self.base_dir = Path(__file__).parent.parent
        self.completed_dir = self.base_dir / "completed_packs"
        self.logs_dir = self.base_dir / "logs"
        
        # Set up logging
        self.setup_logging()
        
        # GitHub release tag
        self.release_tag = "language-packs-v2.0"
        
        self.logger.info(f"🚀 Initializing deployment for {language_id}")

    def setup_logging(self):
        """Set up deployment logging"""
        log_file = self.logs_dir / f"deploy_{self.language_id}_{time.strftime('%Y%m%d_%H%M%S')}.log"
        
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger(f"deploy_{self.language_id}")

    def load_pack_summary(self) -> Optional[Dict]:
        """Load pack summary from completed packs"""
        summary_path = self.completed_dir / f"{self.language_id}_summary.json"
        
        if not summary_path.exists():
            self.logger.error(f"Pack summary not found: {summary_path}")
            return None
        
        try:
            with open(summary_path, 'r') as f:
                return json.load(f)
        except Exception as e:
            self.logger.error(f"Failed to load pack summary: {e}")
            return None

    def verify_pack_ready(self) -> bool:
        """Verify pack is ready for deployment"""
        self.logger.info(f"🔍 Verifying {self.language_id} is ready for deployment")
        
        zip_path = self.completed_dir / f"{self.language_id}.sqlite.zip"
        summary_path = self.completed_dir / f"{self.language_id}_summary.json"
        
        # Check files exist
        if not zip_path.exists():
            self.logger.error(f"ZIP file not found: {zip_path}")
            return False
        
        if not summary_path.exists():
            self.logger.error(f"Summary file not found: {summary_path}")
            return False
        
        # Verify ZIP integrity
        try:
            with open(zip_path, 'rb') as f:
                actual_checksum = hashlib.sha256(f.read()).hexdigest()
            
            summary = self.load_pack_summary()
            if summary and summary.get('checksum') != actual_checksum:
                self.logger.error(f"Checksum mismatch! Expected: {summary.get('checksum')}, Got: {actual_checksum}")
                return False
            
            self.logger.info(f"✅ Pack verification passed")
            self.logger.info(f"   📦 ZIP: {zip_path.stat().st_size / 1024 / 1024:.1f}MB")
            self.logger.info(f"   🔒 Checksum: {actual_checksum}")
            
            return True
            
        except Exception as e:
            self.logger.error(f"Pack verification failed: {e}")
            return False

    def upload_to_github(self) -> bool:
        """Upload language pack to GitHub release"""
        self.logger.info(f"📤 Uploading {self.language_id} to GitHub release {self.release_tag}")
        
        zip_path = self.completed_dir / f"{self.language_id}.sqlite.zip"
        
        try:
            # Check if release exists
            result = subprocess.run(
                ["gh", "release", "view", self.release_tag],
                capture_output=True,
                text=True
            )
            
            if result.returncode != 0:
                self.logger.error(f"Release {self.release_tag} not found")
                return False
            
            # Upload the file
            result = subprocess.run(
                ["gh", "release", "upload", self.release_tag, str(zip_path)],
                capture_output=True,
                text=True
            )
            
            if result.returncode != 0:
                self.logger.error(f"Upload failed: {result.stderr}")
                return False
            
            # Verify upload
            github_url = f"https://github.com/kvgharbigit/PolyRead/releases/download/{self.release_tag}/{self.language_id}.sqlite.zip"
            
            self.logger.info(f"✅ Upload successful")
            self.logger.info(f"   🔗 URL: {github_url}")
            
            return True
            
        except Exception as e:
            self.logger.error(f"GitHub upload failed: {e}")
            return False

    def update_registry(self) -> bool:
        """Update comprehensive registry with new language pack"""
        self.logger.info(f"📝 Updating registry with {self.language_id}")
        
        # Load pack summary
        summary = self.load_pack_summary()
        if not summary:
            return False
        
        # Load current registry
        registry_path = self.base_dir.parent / "comprehensive-registry.json"
        
        if not registry_path.exists():
            self.logger.error(f"Registry not found: {registry_path}")
            return False
        
        try:
            with open(registry_path, 'r') as f:
                registry = json.load(f)
            
            # Create new pack entry
            pack_entry = {
                "id": self.language_id,
                "name": f"{summary['emoji']} {summary['name']}",
                "description": f"Bidirectional {summary['name']} dictionary with Wiktionary content",
                "source_language": summary['source_language'],
                "target_language": summary['target_language'],
                "type": "bidirectional",
                "pack_type": "main",
                "hidden": False,
                "format": "sqlite",
                "file": f"{self.language_id}.sqlite.zip",
                "size_bytes": summary['zip_size_bytes'],
                "size_mb": summary['zip_size_mb'],
                "entries": summary['total_entries'],
                "source": "Wiktionary",
                "version": "2.0.0",
                "checksum": summary['checksum'],
                "download_url": f"https://github.com/kvgharbigit/PolyRead/releases/download/{self.release_tag}/{self.language_id}.sqlite.zip",
                "created": summary['created_at'],
                "supports_bidirectional": True,
                "ml_kit_supported": True
            }
            
            # Check if pack already exists
            existing_index = None
            for i, pack in enumerate(registry['packs']):
                if pack['id'] == self.language_id:
                    existing_index = i
                    break
            
            if existing_index is not None:
                # Update existing pack
                registry['packs'][existing_index] = pack_entry
                self.logger.info(f"   ✏️ Updated existing pack entry")
            else:
                # Add new pack
                registry['packs'].append(pack_entry)
                self.logger.info(f"   ➕ Added new pack entry")
            
            # Update totals
            registry['total_language_pairs'] = len(registry['packs'])
            
            # Update supported languages
            source_lang = summary['source_language']
            target_lang = summary['target_language']
            
            # Update or add source language
            source_lang_entry = None
            for lang in registry['supported_languages']:
                if lang['code'] == source_lang:
                    source_lang_entry = lang
                    break
            
            if source_lang_entry:
                if target_lang not in source_lang_entry['supported_pairs']:
                    source_lang_entry['supported_pairs'].append(target_lang)
                if self.language_id not in source_lang_entry['main_packs']:
                    source_lang_entry['main_packs'].append(self.language_id)
            else:
                # Add new source language
                registry['supported_languages'].append({
                    "code": source_lang,
                    "name": summary['name'].split(' ↔ ')[0],
                    "supported_pairs": [target_lang],
                    "main_packs": [self.language_id],
                    "ml_kit_supported": True
                })
            
            # Update English (target language)
            for lang in registry['supported_languages']:
                if lang['code'] == target_lang:
                    if source_lang not in lang['supported_pairs']:
                        lang['supported_pairs'].append(source_lang)
                    if self.language_id not in lang['main_packs']:
                        lang['main_packs'].append(self.language_id)
                    break
            
            # Update coming_soon (remove if present)
            if 'coming_soon' in registry:
                registry['coming_soon'] = [
                    item for item in registry['coming_soon'] 
                    if summary['name'] not in item
                ]
            
            # Update total supported languages
            registry['total_languages_supported'] = len(registry['supported_languages'])
            
            # Update timestamp
            registry['timestamp'] = time.strftime('%Y-%m-%dT%H:%M:%SZ')
            
            # Save updated registry
            with open(registry_path, 'w') as f:
                json.dump(registry, f, indent=2)
            
            self.logger.info(f"✅ Registry updated successfully")
            self.logger.info(f"   📊 Total packs: {registry['total_language_pairs']}")
            self.logger.info(f"   🌍 Total languages: {registry['total_languages_supported']}")
            
            return True
            
        except Exception as e:
            self.logger.error(f"Registry update failed: {e}")
            return False

    def upload_registry(self) -> bool:
        """Upload updated registry to GitHub"""
        self.logger.info(f"📤 Uploading updated registry to GitHub")
        
        registry_path = Path.cwd() / "comprehensive-registry.json"
        
        try:
            result = subprocess.run(
                ["gh", "release", "upload", self.release_tag, str(registry_path), "--clobber"],
                capture_output=True,
                text=True
            )
            
            if result.returncode != 0:
                self.logger.error(f"Registry upload failed: {result.stderr}")
                return False
            
            self.logger.info(f"✅ Registry uploaded successfully")
            return True
            
        except Exception as e:
            self.logger.error(f"Registry upload failed: {e}")
            return False

    def verify_deployment(self) -> bool:
        """Verify deployment is accessible"""
        self.logger.info(f"🔍 Verifying deployment accessibility")
        
        try:
            import requests
            
            # Test pack download
            pack_url = f"https://github.com/kvgharbigit/PolyRead/releases/download/{self.release_tag}/{self.language_id}.sqlite.zip"
            
            response = requests.head(pack_url, timeout=10, allow_redirects=True)
            if response.status_code != 200:
                self.logger.error(f"Pack not accessible: {response.status_code}")
                return False
            
            # Test registry download
            registry_url = f"https://github.com/kvgharbigit/PolyRead/releases/download/{self.release_tag}/comprehensive-registry.json"
            
            response = requests.head(registry_url, timeout=10, allow_redirects=True)
            if response.status_code != 200:
                self.logger.error(f"Registry not accessible: {response.status_code}")
                return False
            
            self.logger.info(f"✅ Deployment verification passed")
            self.logger.info(f"   📦 Pack URL: {pack_url}")
            self.logger.info(f"   📋 Registry URL: {registry_url}")
            
            return True
            
        except Exception as e:
            self.logger.error(f"Deployment verification failed: {e}")
            return False

    def deploy(self) -> bool:
        """Main deployment pipeline"""
        self.logger.info(f"\n🚀 DEPLOYING {self.language_id.upper()}")
        self.logger.info("=" * 60)
        
        start_time = time.time()
        
        try:
            # Step 1: Verify pack is ready
            if not self.verify_pack_ready():
                return False
            
            # Step 2: Upload to GitHub
            if not self.upload_to_github():
                return False
            
            # Step 3: Update registry
            if not self.update_registry():
                return False
            
            # Step 4: Upload registry
            if not self.upload_registry():
                return False
            
            # Step 5: Verify deployment
            if not self.verify_deployment():
                return False
            
            # Success summary
            duration = time.time() - start_time
            summary = self.load_pack_summary()
            
            self.logger.info(f"\n🎉 DEPLOYMENT SUCCESS: {self.language_id}")
            self.logger.info("=" * 60)
            self.logger.info(f"📦 Pack: {summary['name']}")
            self.logger.info(f"📊 Entries: {summary['total_entries']:,}")
            self.logger.info(f"📏 Size: {summary['zip_size_mb']}MB")
            self.logger.info(f"⏱️ Deploy time: {duration:.1f}s")
            self.logger.info(f"🔗 Available at: https://github.com/kvgharbigit/PolyRead/releases/tag/{self.release_tag}")
            
            return True
            
        except Exception as e:
            self.logger.error(f"Deployment failed: {e}")
            return False

def main():
    parser = argparse.ArgumentParser(description="Deploy language pack to GitHub")
    parser.add_argument("language_id", help="Language ID (e.g., pt-en, ru-en)")
    parser.add_argument("--verify-only", action="store_true", help="Only verify deployment")
    
    args = parser.parse_args()
    
    try:
        deployer = PackDeployer(args.language_id)
        
        if args.verify_only:
            if deployer.verify_deployment():
                print(f"✅ {args.language_id} deployment verification passed")
                return 0
            else:
                print(f"❌ {args.language_id} deployment verification failed")
                return 1
        else:
            if deployer.deploy():
                print(f"\n✅ {args.language_id} deployment completed successfully")
                return 0
            else:
                print(f"\n❌ {args.language_id} deployment failed")
                return 1
                
    except Exception as e:
        print(f"❌ Error: {e}")
        return 1

if __name__ == "__main__":
    exit(main())