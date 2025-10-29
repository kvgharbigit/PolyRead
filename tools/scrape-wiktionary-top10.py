#!/usr/bin/env python3
"""
Focused Wiktionary Dictionary Scraper  
Only crawls TOP 10 languages from Vuizur/Wiktionary-Dictionaries repository
"""

import requests
import json
import re
import time

# TOP 10 LANGUAGES ONLY - most important for language learning
TOP_10_LANGUAGES = {
    'english': 'English',
    'spanish': 'Spanish', 
    'french': 'French',
    'german': 'German',
    'italian': 'Italian',
    'portuguese': 'Portuguese',
    'russian': 'Russian',
    'chinese': 'Chinese',
    'japanese': 'Japanese',
    'korean': 'Korean'
}

def get_language_code(language_name):
    """Convert language name to standard 2-letter codes"""
    code_map = {
        'english': 'en',
        'spanish': 'es', 
        'french': 'fr',
        'german': 'de',
        'italian': 'it',
        'portuguese': 'pt',
        'russian': 'ru',
        'chinese': 'zh',
        'mandarin': 'zh',
        'japanese': 'ja',
        'korean': 'ko'
    }
    return code_map.get(language_name.lower(), language_name[:2].lower())

def scrape_top10_wiktionary():
    """Scrape only TOP 10 language dictionaries from Wiktionary"""
    try:
        print("🎯 Scraping TOP 10 languages from Wiktionary...")
        
        # Use GitHub API to get repository contents
        api_url = 'https://api.github.com/repos/Vuizur/Wiktionary-Dictionaries/contents'
        response = requests.get(api_url, timeout=30)
        response.raise_for_status()
        
        files = response.json()
        dictionaries = []
        
        # Process each file - focus on TOP 10 only
        for file_info in files:
            filename = file_info['name']
            
            if filename.endswith('stardict.tar.gz') and 'Wiktionary dictionary' in filename:
                # Extract language information from filename
                # Format: "Language1-Language2 Wiktionary dictionary stardict.tar.gz"
                match = re.match(r'^([^-]+)-([^-]+)\s+Wiktionary\s+dictionary\s+stardict\.tar\.gz$', filename)
                if match:
                    lang1 = match.group(1).lower()
                    lang2 = match.group(2).lower()
                    
                    # ONLY include if BOTH languages are in our TOP 10
                    if (lang1 in TOP_10_LANGUAGES and lang2 in TOP_10_LANGUAGES):
                        dictionaries.append({
                            'filename': filename,
                            'lang1': lang1,
                            'lang2': lang2,
                            'raw_url': file_info['download_url'],
                            'size_bytes': file_info.get('size', 0)
                        })
                        print(f"  ✅ {lang1.title()}-{lang2.title()}")
        
        return dictionaries
        
    except Exception as e:
        print(f"❌ Failed to scrape Wiktionary repository: {e}")
        return []

def get_file_size(url):
    """Get file size from URL"""
    try:
        response = requests.head(url, timeout=10, allow_redirects=True)
        if response.status_code == 200:
            content_length = response.headers.get('content-length')
            if content_length:
                return int(content_length)
        return None
    except:
        return None

def main():
    print("🔍 TOP 10 Languages Wiktionary Dictionary Scraper")
    print("=" * 55)
    print("🎯 Target languages:", ", ".join(TOP_10_LANGUAGES.values()))
    print()
    
    # Scrape repository for TOP 10 dictionaries only
    dictionaries = scrape_top10_wiktionary()
    print(f"\n📋 Found {len(dictionaries)} TOP 10 language dictionaries")
    
    # Process and create detailed entries
    results = {}
    
    for i, dict_info in enumerate(dictionaries, 1):
        filename = dict_info['filename']
        lang1 = dict_info['lang1']
        lang2 = dict_info['lang2']
        url = dict_info['raw_url']
        
        print(f"🔍 [{i}/{len(dictionaries)}] Processing {filename}...")
        
        # Get file size (from API or HEAD request)
        file_size = dict_info.get('size_bytes', 0) or get_file_size(url)
        size_mb = round(file_size / (1024 * 1024), 1) if file_size else None
        
        # Create dictionary key
        lang1_code = get_language_code(lang1)
        lang2_code = get_language_code(lang2)
        dict_key = f"{lang1_code}-{lang2_code}"
        
        results[dict_key] = {
            'pair': dict_key,
            'lang1': {
                'code': lang1_code,
                'name': TOP_10_LANGUAGES.get(lang1, lang1.title()),
                'full_name': lang1.title()
            },
            'lang2': {
                'code': lang2_code, 
                'name': TOP_10_LANGUAGES.get(lang2, lang2.title()),
                'full_name': lang2.title()
            },
            'source': 'wiktionary_vuizur',
            'filename': filename,
            'url': url,
            'size_bytes': file_size,
            'size_mb': size_mb,
            'type': 'bilingual' if lang1 != lang2 else 'monolingual',
            'bidirectional': True,  # Wiktionary packs are typically bidirectional
            'priority': 'high'  # All TOP 10 languages get high priority
        }
        
        size_str = f" ({size_mb}MB)" if size_mb else " (size unknown)"
        dict_type = "monolingual" if lang1 == lang2 else "bilingual"
        print(f"  ✅ {lang1.title()} ↔ {lang2.title()} ({dict_type}){size_str}")
    
    # Sort by size (largest first)
    sorted_results = dict(sorted(results.items(), 
                                key=lambda x: x[1]['size_mb'] or 0, 
                                reverse=True))
    
    # Save results
    output = {
        'source': 'wiktionary_vuizur_top10',
        'scraped_at': time.strftime('%Y-%m-%d %H:%M:%S UTC'),
        'target_languages': list(TOP_10_LANGUAGES.values()),
        'total_dictionaries_found': len(sorted_results),
        'languages_covered': list(set([pair.split('-')[0] for pair in sorted_results.keys()] + 
                                    [pair.split('-')[1] for pair in sorted_results.keys()])),
        'dictionaries': sorted_results
    }
    
    with open('wiktionary-top10-scraped.json', 'w', encoding='utf-8') as f:
        json.dump(output, f, indent=2, ensure_ascii=False)
    
    print(f"\n✅ Scraping complete!")
    print(f"📊 Found {len(sorted_results)} TOP 10 language dictionaries")
    print(f"💾 Results saved to wiktionary-top10-scraped.json")
    
    # Print summary
    print(f"\n📈 TOP 10 DICTIONARIES BY SIZE:")
    for pair, data in sorted_results.items():
        size_str = f"{data['size_mb']}MB" if data['size_mb'] else "unknown"
        dict_type = data['type']
        print(f"  {data['lang1']['name']} ↔ {data['lang2']['name']} ({dict_type}): {size_str}")
    
    # Print language coverage
    print(f"\n🌍 TOP 10 LANGUAGE COVERAGE:")
    lang_counts = {}
    for data in sorted_results.values():
        for lang_key in ['lang1', 'lang2']:
            lang_name = data[lang_key]['name']
            lang_counts[lang_name] = lang_counts.get(lang_name, 0) + 1
    
    for lang, count in sorted(lang_counts.items(), key=lambda x: x[1], reverse=True):
        print(f"  {lang}: {count} dictionaries")

if __name__ == '__main__':
    main()