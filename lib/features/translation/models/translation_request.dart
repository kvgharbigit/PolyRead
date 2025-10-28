// Translation Request model for caching and tracking

class TranslationRequest {
  final String text;
  final String sourceLanguage;
  final String targetLanguage;
  final DateTime timestamp;
  
  const TranslationRequest({
    required this.text,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.timestamp,
  });
  
  /// Create a cache key for this request
  String get cacheKey {
    final normalizedText = text.toLowerCase().trim();
    return '${sourceLanguage}_${targetLanguage}_${normalizedText.hashCode}';
  }
  
  /// Create TranslationRequest from map
  factory TranslationRequest.fromMap(Map<String, dynamic> map) {
    return TranslationRequest(
      text: map['text'] as String,
      sourceLanguage: map['source_language'] as String,
      targetLanguage: map['target_language'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
  
  /// Convert TranslationRequest to map
  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'source_language': sourceLanguage,
      'target_language': targetLanguage,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TranslationRequest &&
        other.text.toLowerCase().trim() == text.toLowerCase().trim() &&
        other.sourceLanguage == sourceLanguage &&
        other.targetLanguage == targetLanguage;
  }
  
  @override
  int get hashCode {
    return text.toLowerCase().trim().hashCode ^ 
           sourceLanguage.hashCode ^ 
           targetLanguage.hashCode;
  }
  
  @override
  String toString() {
    return 'TranslationRequest(text: $text, $sourceLanguage → $targetLanguage)';
  }
}