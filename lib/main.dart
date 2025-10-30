import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/navigation/app_router.dart';
import 'core/providers/settings_provider.dart';
import 'core/database/app_database.dart';
import 'core/services/settings_service.dart';
import 'core/services/file_service.dart';
import 'core/services/migration_service.dart';
import 'core/providers/file_service_provider.dart';
import 'features/translation/services/cycling_dictionary_service.dart';
// Dictionary loader service removed - using cycling dictionary system
import 'core/utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize core services with error handling
  late final SettingsService settingsService;
  late final FileService fileService;
  late final AppDatabase database;
  
  try {
    settingsService = SettingsService();
    await settingsService.initialize();
    print('✅ Settings service initialized');
    
    fileService = FileService();
    await fileService.initialize();
    print('✅ File service initialized');
    
    // Initialize database
    database = AppDatabase();
    print('✅ Database initialized');
  } catch (e) {
    print('❌ Critical service initialization failed: $e');
    // Use fallback services
    settingsService = SettingsService();
    fileService = FileService();
    database = AppDatabase();
  }
  
  // Run data migrations
  try {
    final migrationService = MigrationService(
      database: database,
      fileService: fileService,
    );
    await migrationService.runMigrations();
    
    // Get migration stats
    final stats = await migrationService.getFileStatusStats();
    print('📊 File Status: $stats');
  } catch (e) {
    print('📊 Migration failed: $e');
    // Continue app startup even if migration fails
  }
  
  // Dictionary initialization removed - cycling dictionary system handles all dictionary operations
  print('📚 Dictionary: Using cycling dictionary system - real dictionaries will be downloaded when needed');
  
  // Pre-warm critical services for better performance
  await _prewarmServices(database);
  
  runApp(
    ProviderScope(
      overrides: [
        // Override service providers with initialized instances
        settingsServiceProvider.overrideWithValue(settingsService),
        fileServiceProvider.overrideWithValue(fileService),
      ],
      child: const PolyReadApp(),
    ),
  );
}

/// Pre-warm critical services during app startup
Future<void> _prewarmServices(AppDatabase database) async {
  try {
    print('🔄 Pre-warming services...');
    
    // Pre-warm database connections by running a simple query with timeout
    final queryFuture = database.customSelect('SELECT COUNT(*) as count FROM books').getSingle();
    final booksCount = await queryFuture.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        print('⚠️ Database query timeout during pre-warming');
        // Return a default value if query times out
        throw TimeoutException('Database query timeout', const Duration(seconds: 5));
      },
    );
    print('📊 Database: ${booksCount.read<int>('count')} books loaded');
    
    // Pre-warm cycling dictionary service with error handling
    try {
      final cyclingService = CyclingDictionaryService(database);
      final stats = await cyclingService.getStats('es', 'en').timeout(
        const Duration(seconds: 3),
        onTimeout: () => {'wordGroups': 0, 'totalMeanings': 0},
      );
      print('📚 Cycling Dictionary: ${stats['wordGroups']} word groups ready');
    } catch (dictError) {
      print('⚠️ Dictionary service pre-warming failed: $dictError');
      // Continue without failing the entire pre-warming
    }
    
    print('✅ Service pre-warming completed');
  } catch (e) {
    print('⚠️ Service pre-warming failed: $e');
    // Continue startup even if pre-warming fails
  }
}

class PolyReadApp extends ConsumerWidget {
  const PolyReadApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      
      // Theme configuration based on settings
      theme: _buildTheme(Brightness.light, settings.fontSize),
      darkTheme: _buildTheme(Brightness.dark, settings.fontSize),
      themeMode: _getThemeMode(settings.themeMode),
      
      // Router configuration
      routerConfig: router,
    );
  }
  
  ThemeData _buildTheme(Brightness brightness, double fontSize) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: brightness,
    );
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: _buildTextTheme(fontSize),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            );
          }
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          );
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
      ),
    );
  }
  
  TextTheme _buildTextTheme(double baseFontSize) {
    return TextTheme(
      displayLarge: TextStyle(fontSize: baseFontSize + 24),
      displayMedium: TextStyle(fontSize: baseFontSize + 20),
      displaySmall: TextStyle(fontSize: baseFontSize + 16),
      headlineLarge: TextStyle(fontSize: baseFontSize + 12),
      headlineMedium: TextStyle(fontSize: baseFontSize + 8),
      headlineSmall: TextStyle(fontSize: baseFontSize + 4),
      titleLarge: TextStyle(fontSize: baseFontSize + 6),
      titleMedium: TextStyle(fontSize: baseFontSize + 2),
      titleSmall: TextStyle(fontSize: baseFontSize),
      bodyLarge: TextStyle(fontSize: baseFontSize + 2),
      bodyMedium: TextStyle(fontSize: baseFontSize),
      bodySmall: TextStyle(fontSize: baseFontSize - 2),
      labelLarge: TextStyle(fontSize: baseFontSize),
      labelMedium: TextStyle(fontSize: baseFontSize - 1),
      labelSmall: TextStyle(fontSize: baseFontSize - 2),
    );
  }
  
  ThemeMode _getThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}