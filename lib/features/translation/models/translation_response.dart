// Translation Response Model
// Represents the result of a translation request with multiple sources

import 'package:polyread/features/translation/models/translation_request.dart';
import 'package:polyread/features/translation/models/dictionary_entry.dart';

/// ML Kit translation result
class MlKitResult {
  final String translatedText;
  final String providerId;
  final int latencyMs;
  final bool success;
  final String? error;
  
  const MlKitResult({
    required this.translatedText,
    required this.providerId,
    this.latencyMs = 0,
    this.success = true,
    this.error,
  });
  
  Map<String, dynamic> toJson() => {
    'translatedText': translatedText,
    'providerId': providerId,
    'latencyMs': latencyMs,
    'success': success,
    'error': error,
  };
  
  factory MlKitResult.fromJson(Map<String, dynamic> json) => MlKitResult(
    translatedText: json['translatedText'] as String,
    providerId: json['providerId'] as String,
    latencyMs: json['latencyMs'] as int? ?? 0,
    success: json['success'] as bool? ?? true,
    error: json['error'] as String?,
  );
}

/// Server translation result
class ServerResult {
  final String translatedText;
  final String providerId;
  final int latencyMs;
  final bool success;
  final String? error;
  
  const ServerResult({
    required this.translatedText,
    required this.providerId,
    this.latencyMs = 0,
    this.success = true,
    this.error,
  });
  
  Map<String, dynamic> toJson() => {
    'translatedText': translatedText,
    'providerId': providerId,
    'latencyMs': latencyMs,
    'success': success,
    'error': error,
  };
  
  factory ServerResult.fromJson(Map<String, dynamic> json) => ServerResult(
    translatedText: json['translatedText'] as String,
    providerId: json['providerId'] as String,
    latencyMs: json['latencyMs'] as int? ?? 0,
    success: json['success'] as bool? ?? true,
    error: json['error'] as String?,
  );
}

enum TranslationSource {
  dictionary,
  mlKit,
  server,
  cache,
  error,
  modelsNotDownloaded,
}

class TranslationResponse {
  final TranslationRequest request;
  final String translatedText;
  final TranslationSource source;
  final DateTime timestamp;
  final DictionaryLookupResult? dictionaryResult;
  final MlKitResult? mlKitResult;
  final ServerResult? serverResult;
  final Duration? responseTime;
  final String? error;
  final String? providerId;

  const TranslationResponse({
    required this.request,
    required this.translatedText,
    required this.source,
    required this.timestamp,
    this.dictionaryResult,
    this.mlKitResult,
    this.serverResult,
    this.responseTime,
    this.error,
    this.providerId,
  });

  /// Create response from dictionary lookup
  factory TranslationResponse.fromDictionary({
    required TranslationRequest request,
    required DictionaryLookupResult dictionaryResult,
  }) {
    final primaryTranslation = dictionaryResult.entries.isNotEmpty
        ? (dictionaryResult.entries.first.transList.split(' | ').first.trim().isNotEmpty 
           ? dictionaryResult.entries.first.transList.split(' | ').first.trim()
           : dictionaryResult.entries.first.sense ?? request.text)
        : request.text;

    return TranslationResponse(
      request: request,
      translatedText: primaryTranslation,
      source: TranslationSource.dictionary,
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

  /// Create response from any provider result
  factory TranslationResponse.fromProvider({
    required TranslationRequest request,
    required dynamic result,
  }) {
    if (result is MlKitResult) {
      return TranslationResponse.fromMlKit(request: request, mlKitResult: result);
    } else if (result is ServerResult) {
      return TranslationResponse.fromServer(request: request, serverResult: result);
    } else {
      throw ArgumentError('Unsupported provider result type: ${result.runtimeType}');
    }
  }

  /// Create error response
  factory TranslationResponse.error({
    required TranslationRequest request,
    required String error,
  }) {
    return TranslationResponse(
      request: request,
      translatedText: '',
      source: TranslationSource.error,
      timestamp: DateTime.now(),
      error: error,
    );
  }

  /// Create models not downloaded response
  factory TranslationResponse.modelsNotDownloaded({
    required TranslationRequest request,
    required String providerId,
  }) {
    return TranslationResponse(
      request: request,
      translatedText: '',
      source: TranslationSource.modelsNotDownloaded,
      timestamp: DateTime.now(),
      providerId: providerId,
      error: 'Translation models not downloaded for $providerId',
    );
  }

  /// Create a copy with modified values
  TranslationResponse copyWith({
    TranslationRequest? request,
    String? translatedText,
    TranslationSource? source,
    DateTime? timestamp,
    DictionaryLookupResult? dictionaryResult,
    MlKitResult? mlKitResult,
    ServerResult? serverResult,
    Duration? responseTime,
    String? error,
    String? providerId,
  }) {
    return TranslationResponse(
      request: request ?? this.request,
      translatedText: translatedText ?? this.translatedText,
      source: source ?? this.source,
      timestamp: timestamp ?? this.timestamp,
      dictionaryResult: dictionaryResult ?? this.dictionaryResult,
      mlKitResult: mlKitResult ?? this.mlKitResult,
      serverResult: serverResult ?? this.serverResult,
      responseTime: responseTime ?? this.responseTime,
      error: error ?? this.error,
      providerId: providerId ?? this.providerId,
    );
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'request': request.toMap(),
      'translatedText': translatedText,
      'source': source.name,
      'timestamp': timestamp.toIso8601String(),
      'dictionaryResult': dictionaryResult?.toJson(),
      'mlKitResult': mlKitResult?.toJson(),
      'serverResult': serverResult?.toJson(),
      'responseTime': responseTime?.inMilliseconds,
      'error': error,
      'providerId': providerId,
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
      timestamp: DateTime.parse(json['timestamp'] as String),
      dictionaryResult: json['dictionaryResult'] != null
          ? DictionaryLookupResult.fromJson(json['dictionaryResult'] as Map<String, dynamic>)
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
      error: json['error'] as String?,
      providerId: json['providerId'] as String?,
    );
  }

  @override
  String toString() {
    return 'TranslationResponse(${request.text} → $translatedText, source: $source)';
  }
}

