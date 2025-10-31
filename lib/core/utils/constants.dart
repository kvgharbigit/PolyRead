// App Constants
// Centralized constants used throughout the application

import 'package:flutter/material.dart';

class AppConstants {
  // App Info
  static const String appName = 'PolyRead';
  static const String appVersion = '1.0.0';
  
  // Storage Limits
  static const int defaultMaxStorageMB = 500;
  static const int minStorageMB = 100;
  static const int maxStorageMB = 2048;
  
  // Language Codes
  static const List<String> supportedLanguages = [
    'auto', 'en', 'es', 'fr', 'de', 'it', 'pt', 'ru', 'zh', 'ja', 'ko', 'ar', 'hi'
  ];
  
  static const Map<String, String> languageNames = {
    'auto': 'Auto-detect',
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'pt': 'Portuguese',
    'ru': 'Russian',
    'zh': 'Chinese',
    'ja': 'Japanese',
    'ko': 'Korean',
    'ar': 'Arabic',
    'hi': 'Hindi',
  };
  
  // File Formats
  static const List<String> supportedBookFormats = ['.pdf', '.epub'];
  static const List<String> supportedImageFormats = ['.jpg', '.jpeg', '.png'];
  
  // Database
  static const String databaseName = 'polyread.db';
  static const int databaseVersion = 6;
  
  // Reading Settings
  static const double minFontSize = 12.0;
  static const double maxFontSize = 24.0;
  static const double defaultFontSize = 16.0;
  static const int progressSaveIntervalSeconds = 30;
  
  // Translation
  static const int maxTranslationLength = 500;
  static const int translationCacheExpiryDays = 7;
  
  // SRS (Spaced Repetition System)
  static const List<int> srsIntervals = [1, 3, 7, 14, 30, 90, 180]; // days
  static const double defaultSrsDifficulty = 2.5;
  static const double minSrsDifficulty = 1.0;
  static const double maxSrsDifficulty = 4.0;
  
  // UI
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 150);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  static const Duration microAnimation = Duration(milliseconds: 100);
  static const Duration slowAnimation = Duration(milliseconds: 800);
  
  // Animation Curves for premium feel
  static const Curve elegantCurve = Curves.easeOutQuart;
  static const Curve bouncyCurve = Curves.elasticOut;
  static const Curve smoothCurve = Curves.easeInOutCubic;
  
  // Error Messages
  static const String genericErrorMessage = 'An unexpected error occurred. Please try again.';
  static const String networkErrorMessage = 'Network connection error. Please check your internet connection.';
  static const String fileErrorMessage = 'File access error. Please check file permissions.';
  
  // User-friendly error messages
  static const String bookImportErrorMessage = 'Could not import this book. Please make sure it\'s a valid PDF or EPUB file.';
  static const String translationErrorMessage = 'Translation is temporarily unavailable. Please try again in a moment.';
  static const String dictionaryErrorMessage = 'Dictionary lookup failed. The word might not be in our database yet.';
  static const String modelDownloadErrorMessage = 'Could not download translation models. Please check your internet connection.';
  static const String vocabularyErrorMessage = 'Could not save to vocabulary. Please try again.';
  static const String readingProgressErrorMessage = 'Could not save reading progress. Your place in the book may not be remembered.';
  
  // URLs and Repository Configuration
  static const String githubOwner = 'kvgharbigit';
  static const String githubRepository = 'PolyRead';
  static const String githubRepoUrl = 'https://github.com/kvgharbigit/PolyRead';
  static const String issuesUrl = 'https://github.com/kvgharbigit/PolyRead/issues';
  static const String languagePacksUrl = 'https://github.com/kvgharbigit/PolyRead/releases';
  
  // Language Pack Configuration
  static const String languagePacksReleaseTag = 'language-packs-v2.1';
  static const String registryFileName = 'comprehensive-registry.json';
}