#!/usr/bin/env python3
"""
Wiktionary Dictionary Scraper  
Crawls the Vuizur/Wiktionary-Dictionaries repository for StarDict dictionaries
Focuses on top 10 dominant languages
"""

import requests
import json
import re
from bs4 import BeautifulSoup
from urllib.parse import urljoin, unquote
import time

# Top global languages by speakers + learning demand + digital content
TOP_LANGUAGES = {
    # Top 10 core languages
    'english': 'English',
    'spanish': 'Spanish',
    'french': 'French', 
    'german': 'German',
    'italian': 'Italian',
    'portuguese': 'Portuguese',
    'russian': 'Russian',
    'arabic': 'Arabic',
    'chinese': 'Chinese',
    'mandarin': 'Chinese',
    'japanese': 'Japanese',
    'korean': 'Korean',
    'hindi': 'Hindi',
    
    # Additional valuable languages for language learners
    'dutch': 'Dutch',
    'polish': 'Polish',
    'turkish': 'Turkish',
    'greek': 'Greek',
    'czech': 'Czech',
    'hungarian': 'Hungarian',
    'finnish': 'Finnish',
    'swedish': 'Swedish',
    'norwegian': 'Norwegian',
    'danish': 'Danish',
    'ukrainian': 'Ukrainian',
    'bulgarian': 'Bulgarian',
    'romanian': 'Romanian',
    'serbian': 'Serbian',
    'croatian': 'Croatian',
    'slovenian': 'Slovenian',
    'slovak': 'Slovak',
    'lithuanian': 'Lithuanian',
    'latvian': 'Latvian',
    'estonian': 'Estonian',
    
    # Asian languages
    'vietnamese': 'Vietnamese',
    'thai': 'Thai',
    'indonesian': 'Indonesian',
    'malay': 'Malay',
    'tagalog': 'Tagalog',
    'bengali': 'Bengali',
    'tamil': 'Tamil',
    'telugu': 'Telugu',
    'gujarati': 'Gujarati',
    'marathi': 'Marathi',
    'kannada': 'Kannada',
    'malayalam': 'Malayalam',
    'punjabi': 'Punjabi',
    'urdu': 'Urdu',
    'persian': 'Persian',
    'hebrew': 'Hebrew',
    
    # Classical/Academic languages
    'latin': 'Latin',
    'esperanto': 'Esperanto',
}

def scrape_wiktionary_repo():
    """Scrape the Vuizur Wiktionary-Dictionaries GitHub repository using API"""
    try:
        print("🕷️ Scraping Vuizur Wiktionary-Dictionaries repository using GitHub API...")
        
        # Use GitHub API to get repository contents
        api_url = 'https://api.github.com/repos/Vuizur/Wiktionary-Dictionaries/contents'
        response = requests.get(api_url, timeout=30)
        response.raise_for_status()
        
        files = response.json()
        dictionaries = []
        
        # Process each file
        for file_info in files:
            filename = file_info['name']
            
            if filename.endswith('stardict.tar.gz') and 'Wiktionary dictionary' in filename:
                # Extract language information from filename
                # Format: "Language1-Language2 Wiktionary dictionary stardict.tar.gz"
                match = re.match(r'^([^-]+)-([^-]+)\s+Wiktionary\s+dictionary\s+stardict\.tar\.gz$', filename)
                if match:
                    lang1 = match.group(1).lower()
                    lang2 = match.group(2).lower()
                    
                    # Check if either language is in our top languages
                    if lang1 in TOP_LANGUAGES or lang2 in TOP_LANGUAGES:
                        dictionaries.append({
                            'filename': filename,
                            'lang1': lang1,
                            'lang2': lang2,
                            'raw_url': file_info['download_url'],
                            'size_bytes': file_info.get('size', 0)
                        })
                        print(f"  📚 Found: {lang1.title()}-{lang2.title()}")
        
        return dictionaries
        
    except Exception as e:
        print(f"❌ Failed to scrape Wiktionary repository: {e}")
        return []

def get_file_size(url):
    """Get file size from URL without downloading"""
    try:
        response = requests.head(url, timeout=10, allow_redirects=True)
        if response.status_code == 200:
            content_length = response.headers.get('content-length')
            if content_length:
                return int(content_length)
        return None
    except Exception as e:
        print(f"⚠️ Failed to get size for {url}: {e}")
        return None

def main():
    print("🔍 Wiktionary Dictionary Scraper (Vuizur Repository)")
    print("=" * 60)
    
    # Scrape repository for dictionary files
    dictionaries = scrape_wiktionary_repo()
    print(f"📋 Found {len(dictionaries)} relevant Wiktionary dictionaries")
    
    # Get file sizes and create detailed entries
    results = {}
    
    for i, dict_info in enumerate(dictionaries, 1):
        filename = dict_info['filename']
        lang1 = dict_info['lang1']
        lang2 = dict_info['lang2']
        url = dict_info['raw_url']
        
        print(f"🔍 [{i}/{len(dictionaries)}] Checking {filename}...")
        
        # Get file size (from API response or HEAD request)
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
                'name': TOP_LANGUAGES.get(lang1, lang1.title()),
                'full_name': lang1.title()
            },
            'lang2': {
                'code': lang2_code, 
                'name': TOP_LANGUAGES.get(lang2, lang2.title()),
                'full_name': lang2.title()
            },
            'source': 'wiktionary_vuizur',
            'filename': filename,
            'url': url,
            'size_bytes': file_size,
            'size_mb': size_mb,
            'type': 'bilingual' if lang1 != lang2 else 'monolingual'
        }
        
        size_str = f" ({size_mb}MB)" if size_mb else " (size unknown)"
        dict_type = "monolingual" if lang1 == lang2 else "bilingual"
        print(f"  ✅ {lang1.title()} → {lang2.title()} ({dict_type}){size_str}")
        
        # Rate limiting
        time.sleep(0.5)
    
    # Sort by size (largest first)
    sorted_results = dict(sorted(results.items(), 
                                key=lambda x: x[1]['size_mb'] or 0, 
                                reverse=True))
    
    # Save results
    output = {
        'source': 'wiktionary_vuizur',
        'scraped_at': time.strftime('%Y-%m-%d %H:%M:%S UTC'),
        'total_dictionaries_found': len(sorted_results),
        'languages_covered': list(set([pair.split('-')[0] for pair in sorted_results.keys()] + 
                                    [pair.split('-')[1] for pair in sorted_results.keys()])),
        'dictionaries': sorted_results
    }
    
    with open('wiktionary-scraped.json', 'w', encoding='utf-8') as f:
        json.dump(output, f, indent=2, ensure_ascii=False)
    
    print(f"\n✅ Scraping complete!")
    print(f"📊 Found {len(sorted_results)} usable dictionaries")
    print(f"💾 Results saved to wiktionary-scraped.json")
    
    # Print summary
    print(f"\n📈 TOP DICTIONARIES BY SIZE:")
    for pair, data in list(sorted_results.items())[:15]:
        size_str = f"{data['size_mb']}MB" if data['size_mb'] else "unknown"
        dict_type = data['type']
        print(f"  {data['lang1']['name']} → {data['lang2']['name']} ({dict_type}): {size_str}")
    
    # Print coverage summary
    print(f"\n🌍 LANGUAGE COVERAGE:")
    lang_counts = {}
    for data in sorted_results.values():
        for lang_key in ['lang1', 'lang2']:
            lang_name = data[lang_key]['name']
            lang_counts[lang_name] = lang_counts.get(lang_name, 0) + 1
    
    for lang, count in sorted(lang_counts.items(), key=lambda x: x[1], reverse=True):
        print(f"  {lang}: {count} dictionaries")

def get_language_code(language_name):
    """Convert language name to standard 2-letter codes for our app"""
    code_map = {
        'english': 'en',
        'spanish': 'es', 
        'french': 'fr',
        'german': 'de',
        'italian': 'it',
        'portuguese': 'pt',
        'russian': 'ru',
        'arabic': 'ar',
        'hindi': 'hi',
        'chinese': 'zh',
        'mandarin': 'zh',
        'japanese': 'ja',
        'korean': 'ko',
        'dutch': 'nl',
        'polish': 'pl',
        'turkish': 'tr',
        'greek': 'el',
        'latin': 'la',
        'esperanto': 'eo',
        'czech': 'cs',
        'slovak': 'sk',
        'hungarian': 'hu',
        'finnish': 'fi',
        'swedish': 'sv',
        'norwegian': 'no',
        'danish': 'da',
        'ukrainian': 'uk',
        'bulgarian': 'bg',
        'serbian': 'sr',
        'croatian': 'hr',
        'romanian': 'ro',
        'lithuanian': 'lt',
        'latvian': 'lv',
        'estonian': 'et',
        'slovenian': 'sl',
        'vietnamese': 'vi',
        'thai': 'th',
        'indonesian': 'id',
        'malay': 'ms',
        'tagalog': 'tl',
        'hebrew': 'he',
        'persian': 'fa',
        'urdu': 'ur',
        'bengali': 'bn',
        'tamil': 'ta',
        'telugu': 'te',
        'gujarati': 'gu',
        'marathi': 'mr',
        'kannada': 'kn',
        'malayalam': 'ml',
        'punjabi': 'pa',
    }
    return code_map.get(language_name.lower(), language_name[:2].lower())

if __name__ == '__main__':
    main()