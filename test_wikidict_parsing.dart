// Simple test for WikiDict parsing functionality
// Tests the pipe-separated translation parsing

void main() {
  print('=== WikiDict Translation Parsing Test ===');
  
  // Test pipe-separated translation parsing
  testTranslationParsing();
  
  print('\n=== Test Complete ===');
}

void testTranslationParsing() {
  print('\n1. Testing pipe-separated translation parsing...');
  
  // Sample WikiDict data like from PolyBook
  final testData = [
    {
      'transList': 'frío | helado | gélido | frígido',
      'word': 'cold',
      'expected_primary': 'frío',
      'expected_synonyms': ['helado', 'gélido', 'frígido'],
    },
    {
      'transList': 'agua | liquid | H2O',
      'word': 'water', 
      'expected_primary': 'agua',
      'expected_synonyms': ['liquid', 'H2O'],
    },
    {
      'transList': 'resfriado | catarro | gripe',
      'word': 'cold_noun',
      'expected_primary': 'resfriado', 
      'expected_synonyms': ['catarro', 'gripe'],
    },
  ];
  
  for (final test in testData) {
    final transList = test['transList'] as String;
    final word = test['word'] as String;
    final expectedPrimary = test['expected_primary'] as String;
    final expectedSynonyms = test['expected_synonyms'] as List<String>;
    
    // Parse like DriftDictionaryService does
    final translations = transList.split(' | ')
        .where((t) => t.trim().isNotEmpty)
        .map((t) => t.trim())
        .toList();
    
    final primaryTranslation = translations.isNotEmpty ? translations.first : '';
    final synonyms = translations.length > 1 ? translations.skip(1).toList() : <String>[];
    
    print('   Word: "$word"');
    print('   TransList: "$transList"');
    print('   Primary: "$primaryTranslation" (expected: "$expectedPrimary")');
    print('   Synonyms: $synonyms (expected: $expectedSynonyms)');
    
    // Verify parsing
    final primaryMatch = primaryTranslation == expectedPrimary;
    final synonymsMatch = _listsEqual(synonyms, expectedSynonyms);
    
    if (primaryMatch && synonymsMatch) {
      print('   ✅ PASS - Correct parsing');
    } else {
      print('   ❌ FAIL - Parsing error');
      if (!primaryMatch) {
        print('      Primary mismatch: got "$primaryTranslation", expected "$expectedPrimary"');
      }
      if (!synonymsMatch) {
        print('      Synonyms mismatch: got $synonyms, expected $expectedSynonyms');
      }
    }
    print('');
  }
}

bool _listsEqual(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}