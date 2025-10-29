#!/usr/bin/env python3
"""
Simple Portuguese Generator - Run build script and check result
"""

import subprocess
import time
import sys
from pathlib import Path

def main():
    print("🇵🇹 SIMPLE PORTUGUESE GENERATION")
    print("=" * 50)
    
    # Paths
    tools_dir = Path(__file__).parent.parent.parent / "tools"
    build_script = tools_dir / "build-unified-pack.sh"
    
    print(f"📁 Tools directory: {tools_dir}")
    print(f"📜 Build script: {build_script}")
    
    if not build_script.exists():
        print(f"❌ Build script not found: {build_script}")
        return 1
    
    # Run the build script
    print(f"🚀 Running: bash {build_script} pt-en")
    print("📥 This will take 1-2 minutes... please wait")
    
    start_time = time.time()
    
    try:
        result = subprocess.run(
            ["bash", str(build_script), "pt-en"],
            cwd=tools_dir,
            capture_output=True,
            text=True,
            timeout=300  # 5 minutes
        )
        
        duration = time.time() - start_time
        print(f"⏱️ Build completed in {duration:.1f}s")
        
        if result.returncode == 0:
            print("✅ Build successful!")
            
            # Check result
            expected_db = tools_dir / "tmp-unified-pt-en" / "pt-en.sqlite"
            if expected_db.exists():
                size_mb = expected_db.stat().st_size / 1024 / 1024
                print(f"✅ Database created: {expected_db} ({size_mb:.1f}MB)")
                
                # Quick verification
                import sqlite3
                conn = sqlite3.connect(expected_db)
                cursor = conn.cursor()
                cursor.execute("SELECT COUNT(*) FROM entries")
                entry_count = cursor.fetchone()[0]
                conn.close()
                
                print(f"✅ Entries: {entry_count:,}")
                
                if entry_count > 5000:
                    print("🎉 Portuguese StarDict build successful!")
                    return 0
                else:
                    print("⚠️ Low entry count, may have issues")
                    return 1
            else:
                print(f"❌ Expected database not found: {expected_db}")
                return 1
        else:
            print(f"❌ Build failed with return code: {result.returncode}")
            print("STDOUT:", result.stdout[-1000:])  # Last 1000 chars
            print("STDERR:", result.stderr[-1000:])  # Last 1000 chars
            return 1
            
    except subprocess.TimeoutExpired:
        print("❌ Build timed out after 5 minutes")
        return 1
    except Exception as e:
        print(f"❌ Build error: {e}")
        return 1

if __name__ == "__main__":
    exit(main())