// Translation Response Model
// Represents the result of a translation request with multiple sources

import 'package:polyread/features/translation/models/translation_request.dart';
import 'package:polyread/features/translation/models/dictionary_entry.dart';

enum TranslationSource {
  dictionary,
  mlKit,
  server,
  cache,
}

class TranslationResponse {
  final TranslationRequest request;
  final String translatedText;
  final TranslationSource source;
  final double confidence;
  final DateTime timestamp;
  final DictionaryResult? dictionaryResult;
  final MlKitResult? mlKitResult;
  final ServerResult? serverResult;
  final Duration? responseTime;

  const TranslationResponse({
    required this.request,
    required this.translatedText,
    required this.source,
    required this.confidence,
    required this.timestamp,
    this.dictionaryResult,
    this.mlKitResult,
    this.serverResult,
    this.responseTime,
  });

  /// Create response from dictionary lookup
  factory TranslationResponse.fromDictionary({
    required TranslationRequest request,
    required DictionaryResult dictionaryResult,
  }) {
    final primaryTranslation = dictionaryResult.entries.isNotEmpty
        ? dictionaryResult.entries.first.translations.first
        : request.text;

    return TranslationResponse(
      request: request,
      translatedText: primaryTranslation,
      source: TranslationSource.dictionary,
      confidence: 0.9,
      timestamp: DateTime.now(),
      dictionaryResult: dictionaryResult,
    );
  }

  /// Create response from ML Kit
  factory TranslationResponse.fromMlKit({
    required TranslationRequest request,
    required MlKitResult mlKitResult,
  }) {
    return TranslationResponse(
      request: request,
      translatedText: mlKitResult.translatedText,
      source: TranslationSource.mlKit,
      confidence: mlKitResult.confidence,
      timestamp: DateTime.now(),
      mlKitResult: mlKitResult,
    );
  }

  /// Create response from server
  factory TranslationResponse.fromServer({
    required TranslationRequest request,
    required ServerResult serverResult,
  }) {
    return TranslationResponse(
      request: request,
      translatedText: serverResult.translatedText,
      source: TranslationSource.server,
      confidence: serverResult.confidence,
      timestamp: DateTime.now(),
      serverResult: serverResult,
    );
  }

  /// Create response from cache
  factory TranslationResponse.fromCached(TranslationResponse cachedResponse) {
    return cachedResponse.copyWith(
      source: TranslationSource.cache,
      timestamp: DateTime.now(),
    );
  }

  /// Create a copy with modified values
  TranslationResponse copyWith({
    TranslationRequest? request,
    String? translatedText,
    TranslationSource? source,
    double? confidence,
    DateTime? timestamp,
    DictionaryResult? dictionaryResult,
    MlKitResult? mlKitResult,
    ServerResult? serverResult,
    Duration? responseTime,
  }) {
    return TranslationResponse(
      request: request ?? this.request,
      translatedText: translatedText ?? this.translatedText,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      timestamp: timestamp ?? this.timestamp,
      dictionaryResult: dictionaryResult ?? this.dictionaryResult,
      mlKitResult: mlKitResult ?? this.mlKitResult,
      serverResult: serverResult ?? this.serverResult,
      responseTime: responseTime ?? this.responseTime,
    );
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'request': request.toMap(),
      'translatedText': translatedText,
      'source': source.name,
      'confidence': confidence,
      'timestamp': timestamp.toIso8601String(),
      'dictionaryResult': dictionaryResult?.toJson(),
      'mlKitResult': mlKitResult?.toJson(),
      'serverResult': serverResult?.toJson(),
      'responseTime': responseTime?.inMilliseconds,
    };
  }

  /// Create from JSON
  factory TranslationResponse.fromJson(Map<String, dynamic> json) {
    return TranslationResponse(
      request: TranslationRequest.fromMap(json['request'] as Map<String, dynamic>),
      translatedText: json['translatedText'] as String,
      source: TranslationSource.values.firstWhere(
        (s) => s.name == json['source'],
        orElse: () => TranslationSource.server,
      ),
      confidence: (json['confidence'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      dictionaryResult: json['dictionaryResult'] != null
          ? DictionaryResult.fromJson(json['dictionaryResult'] as Map<String, dynamic>)
          : null,
      mlKitResult: json['mlKitResult'] != null
          ? MlKitResult.fromJson(json['mlKitResult'] as Map<String, dynamic>)
          : null,
      serverResult: json['serverResult'] != null
          ? ServerResult.fromJson(json['serverResult'] as Map<String, dynamic>)
          : null,
      responseTime: json['responseTime'] != null
          ? Duration(milliseconds: json['responseTime'] as int)
          : null,
    );
  }

  @override
  String toString() {
    return 'TranslationResponse(${request.text} → $translatedText, source: $source, confidence: $confidence)';
  }
}

/// ML Kit translation result
class MlKitResult {
  final String translatedText;
  final double confidence;
  final String modelVersion;

  const MlKitResult({
    required this.translatedText,
    required this.confidence,
    required this.modelVersion,
  });

  Map<String, dynamic> toJson() {
    return {
      'translatedText': translatedText,
      'confidence': confidence,
      'modelVersion': modelVersion,
    };
  }

  factory MlKitResult.fromJson(Map<String, dynamic> json) {
    return MlKitResult(
      translatedText: json['translatedText'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      modelVersion: json['modelVersion'] as String,
    );
  }
}

/// Server translation result
class ServerResult {
  final String translatedText;
  final double confidence;
  final String provider;

  const ServerResult({
    required this.translatedText,
    required this.confidence,
    required this.provider,
  });

  Map<String, dynamic> toJson() {
    return {
      'translatedText': translatedText,
      'confidence': confidence,
      'provider': provider,
    };
  }

  factory ServerResult.fromJson(Map<String, dynamic> json) {
    return ServerResult(
      translatedText: json['translatedText'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      provider: json['provider'] as String,
    );
  }
}