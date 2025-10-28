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
  
  return GoRouter(
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
        builder: (context, state, child) {
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
            builder: (context, state) => const LanguagePacksScreen(),
          ),
          
          // Vocabulary screen
          GoRoute(
            path: AppRoutes.vocabulary,
            name: 'vocabulary',
            builder: (context, state) => const VocabularyScreen(),
          ),
        ],
      ),
      
      // Reader screen (full screen, no bottom nav)
      GoRoute(
        path: '${AppRoutes.reader}/:bookId',
        name: 'reader',
        builder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          return ReaderScreen(bookId: int.parse(bookId));
        },
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
    return Scaffold(
      body: child,
      bottomNavigationBar: const MainBottomNavigationBar(),
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

// Placeholder screens (to be implemented in later phases)
class LanguagePacksScreen extends StatelessWidget {
  const LanguagePacksScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Language Packs Screen\n(Phase 4)'),
      ),
    );
  }
}

class VocabularyScreen extends StatelessWidget {
  const VocabularyScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Vocabulary Screen\n(Phase 5)'),
      ),
    );
  }
}