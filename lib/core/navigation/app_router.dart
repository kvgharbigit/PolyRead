// App Router
// Go Router configuration for navigation throughout the app

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:polyread/core/providers/settings_provider.dart';
import 'package:polyread/presentation/library/library_screen.dart';
import 'package:polyread/presentation/onboarding/onboarding_screen.dart';
import 'package:polyread/presentation/reader/reader_screen.dart';
import 'package:polyread/presentation/settings/settings_screen.dart';
import 'package:polyread/features/language_packs/widgets/language_pack_manager.dart';
import 'package:polyread/core/providers/immersive_mode_provider.dart';

// Route paths
class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String library = '/';
  static const String reader = '/reader';
  static const String settings = '/settings';
  static const String languagePacks = '/language-packs';
  static const String vocabulary = '/vocabulary';
}

// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  final settings = ref.watch(settingsProvider);
  
  final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: settings.showOnboarding ? AppRoutes.onboarding : AppRoutes.library,
    routes: [
      // Onboarding flow
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      
      // Main shell with bottom navigation
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) {
          print('MainShell: Building with bottom navigation bar for path: ${state.uri}');
          return MainShell(child: child);
        },
        routes: [
          // Library (home) screen
          GoRoute(
            path: AppRoutes.library,
            name: 'library',
            builder: (context, state) => const LibraryScreen(),
          ),
          
          // Settings screen
          GoRoute(
            path: AppRoutes.settings,
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          
          // Language packs screen
          GoRoute(
            path: AppRoutes.languagePacks,
            name: 'language-packs',
            builder: (context, state) => const LanguagePackManager(),
          ),
          
          // Vocabulary screen
          GoRoute(
            path: AppRoutes.vocabulary,
            name: 'vocabulary',
            builder: (context, state) => const VocabularyPlaceholderScreen(),
          ),
          
          // Reader screen (now inside shell, will conditionally hide bottom nav)
          GoRoute(
            path: '${AppRoutes.reader}/:bookId',
            name: 'reader',
            builder: (context, state) {
              print('Router: Building reader route for path: ${state.uri}');
              final bookIdStr = state.pathParameters['bookId'];
              if (bookIdStr == null) {
                return const ErrorScreen(message: 'Invalid book ID');
              }
              
              final bookId = int.tryParse(bookIdStr);
              if (bookId == null) {
                return ErrorScreen(message: 'Invalid book ID: $bookIdStr');
              }
              
              print('Router: Reader route in shell - bottom nav controlled by immersive mode');
              return ReaderScreen(bookId: bookId);
            },
          ),
        ],
      ),
    ],
    
    // Error handling
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'The page "${state.uri}" could not be found.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.library),
              child: const Text('Go to Library'),
            ),
          ],
        ),
      ),
    ),
  );
});

// Main shell with bottom navigation
class MainShell extends StatelessWidget {
  final Widget child;
  
  const MainShell({super.key, required this.child});
  
  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final isImmersive = ref.watch(immersiveModeProvider);
        print('MainShell: Building with immersive mode: $isImmersive');
        
        return Scaffold(
          body: child,
          bottomNavigationBar: isImmersive ? null : const MainBottomNavigationBar(),
        );
      },
    );
  }
}

// Bottom navigation bar
class MainBottomNavigationBar extends ConsumerWidget {
  const MainBottomNavigationBar({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    
    int getCurrentIndex() {
      switch (location) {
        case AppRoutes.library:
          return 0;
        case AppRoutes.languagePacks:
          return 1;
        case AppRoutes.vocabulary:
          return 2;
        case AppRoutes.settings:
          return 3;
        default:
          return 0;
      }
    }
    
    return NavigationBar(
      selectedIndex: getCurrentIndex(),
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            context.go(AppRoutes.library);
            break;
          case 1:
            context.go(AppRoutes.languagePacks);
            break;
          case 2:
            context.go(AppRoutes.vocabulary);
            break;
          case 3:
            context.go(AppRoutes.settings);
            break;
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.library_books_outlined),
          selectedIcon: Icon(Icons.library_books),
          label: 'Library',
        ),
        NavigationDestination(
          icon: Icon(Icons.language_outlined),
          selectedIcon: Icon(Icons.language),
          label: 'Languages',
        ),
        NavigationDestination(
          icon: Icon(Icons.school_outlined),
          selectedIcon: Icon(Icons.school),
          label: 'Vocabulary',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }
}

// Error screen for navigation issues
class ErrorScreen extends StatelessWidget {
  final String message;
  
  const ErrorScreen({super.key, required this.message});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Navigation Error',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.library),
              child: const Text('Go to Library'),
            ),
          ],
        ),
      ),
    );
  }
}

// Placeholder for vocabulary screen (to be implemented)
class VocabularyPlaceholderScreen extends StatelessWidget {
  const VocabularyPlaceholderScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Vocabulary Screen\n(Coming Soon)'),
      ),
    );
  }
}