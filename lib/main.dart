import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/navigation/app_router.dart';
import 'core/providers/settings_provider.dart';
import 'core/services/settings_service.dart';
import 'core/services/file_service.dart';
import 'core/providers/file_service_provider.dart';
import 'core/utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  final settingsService = SettingsService();
  await settingsService.initialize();
  
  final fileService = FileService();
  await fileService.initialize();
  
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