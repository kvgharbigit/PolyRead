#!/usr/bin/env python3
"""
Create all missing language packs using PolyBook's original sources
This will create French, Italian, Portuguese, Russian, Korean, Japanese, Chinese, Arabic, and Hindi packs
"""

import sys
import json
from pathlib import Path
from create_polybook_language_packs import create_language_pack, POLYBOOK_SOURCES

def create_all_packs():
    """Create all available language packs from PolyBook sources"""
    output_dir = Path("assets/language_packs")
    output_dir.mkdir(exist_ok=True)
    
    all_pack_info = []
    successful_packs = []
    failed_packs = []
    
    print("🚀 Creating ALL language packs from PolyBook's Wiktionary sources")
    print("=" * 80)
    
    for pack_id in POLYBOOK_SOURCES.keys():
        try:
            print(f"\n{'='*20} Processing {pack_id.upper()} {'='*20}")
            pack_info = create_language_pack(pack_id, output_dir)
            all_pack_info.append(pack_info)
            successful_packs.append(pack_id)
            
            # Save individual pack info
            info_path = output_dir / f"{pack_id}_info.json"
            with open(info_path, 'w') as f:
                json.dump(pack_info, f, indent=2)
            
        except Exception as e:
            print(f"❌ Failed to create {pack_id}: {e}")
            failed_packs.append((pack_id, str(e)))
            continue
    
    # Create comprehensive registry
    registry = {
        "version": "2.0",
        "description": "PolyRead Language Packs - Bidirectional Wiktionary Dictionaries",
        "schema_version": "2.0",
        "timestamp": "auto-generated",
        "source": "Vuizur/Wiktionary-Dictionaries (PolyBook compatible)",
        "pack_count": len(all_pack_info),
        "total_entries": sum(pack['total_entries'] for pack in all_pack_info),
        "packs": all_pack_info,
        "language_support": {
            "supported_pairs": len(all_pack_info),
            "total_languages": len(set(p['source_language'] for p in all_pack_info) | 
                                  set(p['target_language'] for p in all_pack_info)),
            "bidirectional": True
        }
    }
    
    # Save comprehensive registry
    registry_path = output_dir / "comprehensive-registry.json"
    with open(registry_path, 'w') as f:
        json.dump(registry, f, indent=2)
    
    # Print summary
    print("\n" + "="*80)
    print("📊 FINAL SUMMARY")
    print("="*80)
    
    if successful_packs:
        print(f"✅ Successfully created {len(successful_packs)} language packs:")
        total_size_mb = sum(pack['size_mb'] for pack in all_pack_info)
        total_entries = sum(pack['total_entries'] for pack in all_pack_info)
        
        for pack_id in successful_packs:
            pack = next(p for p in all_pack_info if p['id'] == pack_id)
            print(f"   {pack_id}: {pack['entries']:,} entries, {pack['size_mb']} MB")
        
        print(f"\n📈 Total Statistics:")
        print(f"   Languages: {len(successful_packs)} pairs")
        print(f"   Entries: {total_entries:,} total dictionary entries") 
        print(f"   Size: {total_size_mb:.1f} MB total compressed")
        print(f"   Registry: {registry_path}")
    
    if failed_packs:
        print(f"\n❌ Failed to create {len(failed_packs)} language packs:")
        for pack_id, error in failed_packs:
            print(f"   {pack_id}: {error}")
    
    print(f"\n📁 All files saved to: {output_dir.absolute()}")
    
    if successful_packs:
        print(f"\n🎯 Next steps:")
        print(f"   1. Update your app's language registry to use the new comprehensive-registry.json")
        print(f"   2. Upload the .sqlite.zip files to your GitHub releases")
        print(f"   3. Test the new bidirectional language packs in your app")
        
        return True
    else:
        print(f"\n❌ No language packs were created successfully")
        return False

if __name__ == "__main__":
    try:
        success = create_all_packs()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n⚠️ Process interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        sys.exit(1)