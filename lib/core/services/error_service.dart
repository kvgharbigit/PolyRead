// Error Service
// Centralized error handling and logging for the app

import 'package:flutter/foundation.dart';

enum ErrorType {
  network,
  fileSystem,
  database,
  translation,
  parsing,
  permission,
  storage,
  unknown,
}

enum ErrorSeverity {
  low,      // Minor issues, app continues normally
  medium,   // Noticeable issues, some features may be affected
  high,     // Major issues, significant functionality impacted
  critical, // App-breaking issues, immediate attention required
}

class AppError {
  final String message;
  final ErrorType type;
  final ErrorSeverity severity;
  final String? details;
  final StackTrace? stackTrace;
  final DateTime timestamp;
  final Map<String, dynamic>? context;
  
  AppError({
    required this.message,
    required this.type,
    required this.severity,
    this.details,
    this.stackTrace,
    DateTime? timestamp,
    this.context,
  }) : timestamp = timestamp ?? DateTime.now();
  
  @override
  String toString() {
    return 'AppError(${type.name}): $message';
  }
  
  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'type': type.name,
      'severity': severity.name,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
      'context': context,
    };
  }
}

class ErrorService {
  static final List<AppError> _errorLog = [];
  static const int _maxLogEntries = 100;
  
  // Error reporting callback for external services (like Crashlytics)
  static void Function(AppError error)? _errorReporter;
  
  static void setErrorReporter(void Function(AppError error) reporter) {
    _errorReporter = reporter;
  }
  
  static void logError(AppError error) {
    // Add to local log
    _errorLog.add(error);
    
    // Keep log size manageable
    if (_errorLog.length > _maxLogEntries) {
      _errorLog.removeAt(0);
    }
    
    // Log to console in debug mode
    if (kDebugMode) {
      print('🚨 ${error.severity.name.toUpperCase()}: ${error.message}');
      if (error.details != null) {
        print('   Details: ${error.details}');
      }
      if (error.context != null) {
        print('   Context: ${error.context}');
      }
    }
    
    // Report to external service
    _errorReporter?.call(error);
  }
  
  // Convenience methods for common error types
  static void logNetworkError(String message, {String? details, Map<String, dynamic>? context}) {
    logError(AppError(
      message: message,
      type: ErrorType.network,
      severity: ErrorSeverity.medium,
      details: details,
      context: context,
    ));
  }
  
  static void logFileSystemError(String message, {String? details, Map<String, dynamic>? context}) {
    logError(AppError(
      message: message,
      type: ErrorType.fileSystem,
      severity: ErrorSeverity.medium,
      details: details,
      context: context,
    ));
  }
  
  static void logDatabaseError(String message, {String? details, StackTrace? stackTrace}) {
    logError(AppError(
      message: message,
      type: ErrorType.database,
      severity: ErrorSeverity.high,
      details: details,
      stackTrace: stackTrace,
    ));
  }
  
  static void logTranslationError(String message, {String? details, Map<String, dynamic>? context}) {
    logError(AppError(
      message: message,
      type: ErrorType.translation,
      severity: ErrorSeverity.medium,
      details: details,
      context: context,
    ));
  }
  
  static void logParsingError(String message, {String? details, String? fileName}) {
    logError(AppError(
      message: message,
      type: ErrorType.parsing,
      severity: ErrorSeverity.medium,
      details: details,
      context: fileName != null ? {'fileName': fileName} : null,
    ));
  }
  
  static void logPermissionError(String message, {String? details}) {
    logError(AppError(
      message: message,
      type: ErrorType.permission,
      severity: ErrorSeverity.high,
      details: details,
    ));
  }
  
  static void logStorageError(String message, {String? details, Map<String, dynamic>? context}) {
    logError(AppError(
      message: message,
      type: ErrorType.storage,
      severity: ErrorSeverity.medium,
      details: details,
      context: context,
    ));
  }
  
  static void logCriticalError(String message, {String? details, StackTrace? stackTrace}) {
    logError(AppError(
      message: message,
      type: ErrorType.unknown,
      severity: ErrorSeverity.critical,
      details: details,
      stackTrace: stackTrace,
    ));
  }
  
  // Error retrieval and management
  static List<AppError> getRecentErrors({int? limit, ErrorSeverity? minSeverity}) {
    var errors = List<AppError>.from(_errorLog);
    
    if (minSeverity != null) {
      errors = errors.where((error) {
        return _getSeverityLevel(error.severity) >= _getSeverityLevel(minSeverity);
      }).toList();
    }
    
    if (limit != null && errors.length > limit) {
      errors = errors.sublist(errors.length - limit);
    }
    
    return errors.reversed.toList(); // Most recent first
  }
  
  static int _getSeverityLevel(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.low:
        return 1;
      case ErrorSeverity.medium:
        return 2;
      case ErrorSeverity.high:
        return 3;
      case ErrorSeverity.critical:
        return 4;
    }
  }
  
  static void clearErrorLog() {
    _errorLog.clear();
  }
  
  static Map<String, dynamic> getErrorSummary() {
    final errorCounts = <ErrorType, int>{};
    final severityCounts = <ErrorSeverity, int>{};
    
    for (final error in _errorLog) {
      errorCounts[error.type] = (errorCounts[error.type] ?? 0) + 1;
      severityCounts[error.severity] = (severityCounts[error.severity] ?? 0) + 1;
    }
    
    return {
      'totalErrors': _errorLog.length,
      'errorsByType': errorCounts.map((k, v) => MapEntry(k.name, v)),
      'errorsBySeverity': severityCounts.map((k, v) => MapEntry(k.name, v)),
      'lastError': _errorLog.isNotEmpty ? _errorLog.last.toJson() : null,
    };
  }
  
  // User-friendly error messages
  static String getUserFriendlyMessage(AppError error) {
    switch (error.type) {
      case ErrorType.network:
        return 'Network connection issue. Please check your internet connection and try again.';
      case ErrorType.fileSystem:
        return 'File access error. Please check file permissions and available storage.';
      case ErrorType.database:
        return 'Data storage error. The app may need to restart.';
      case ErrorType.translation:
        return 'Translation service unavailable. Please try again or check your language pack downloads.';
      case ErrorType.parsing:
        return 'File format error. This file may be corrupted or unsupported.';
      case ErrorType.permission:
        return 'Permission required. Please grant the necessary permissions in settings.';
      case ErrorType.storage:
        return 'Storage space issue. Please free up space or adjust storage limits.';
      case ErrorType.unknown:
        return 'An unexpected error occurred. Please restart the app and try again.';
    }
  }
}