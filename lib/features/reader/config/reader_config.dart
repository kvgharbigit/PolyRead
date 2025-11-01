// Reader Configuration Constants
// Centralized configuration for book reader functionality

class ReaderConfig {
  // Text selection validation
  static const int maxTranslationTextLength = 200;
  static const int minTranslationTextLength = 1;
  static const int contextWordsCount = 8;
  
  // UI timing
  static const Duration immersiveModeAutoTimeout = Duration(seconds: 4);
  
  // Progress tracking
  static const Duration progressSaveInterval = Duration(seconds: 30);
  
  // Text validation patterns
  static const String validTextPattern = r'[a-zA-Z]';
  
  // Error messages
  static const String translationServiceNotAvailable = 'Translation service not available';
  static const String readerNotInitialized = 'Reader not initialized';
  
  // UI dimensions
  static const double progressIndicatorHeight = 2.0;
  static const double progressIndicatorOpacity = 0.3;
  static const double progressBarOpacity = 0.6;
}