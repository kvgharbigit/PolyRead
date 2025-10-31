// Premium Onboarding Experience
// Elegant welcome flow showcasing PolyRead's reading-focused capabilities

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:polyread/core/navigation/app_router.dart';
import 'package:polyread/core/providers/settings_provider.dart';
import 'package:polyread/core/utils/constants.dart';
import 'package:polyread/core/themes/polyread_spacing.dart';
import 'package:polyread/core/themes/polyread_typography.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    
    _fadeController.forward();
    _slideController.forward();
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge([_fadeAnimation, _slideAnimation]),
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    children: [
                      _buildElegantHeader(),
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          itemCount: _premiumOnboardingPages.length,
                          itemBuilder: (context, index) {
                            return _premiumOnboardingPages[index];
                          },
                        ),
                      ),
                      _buildElegantNavigation(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
  
  void _completeOnboarding() async {
    await ref.read(settingsProvider.notifier).setShowOnboarding(false);
    if (mounted) {
      context.go(AppRoutes.library);
    }
  }
  
  /// Build elegant header with app branding and progress indicators
  Widget _buildElegantHeader() {
    return Padding(
      padding: PolyReadSpacing.getResponsivePadding(context),
      child: Column(
        children: [
          const SizedBox(height: PolyReadSpacing.elementSpacing),
          
          // App branding
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(PolyReadSpacing.elementSpacing),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: PolyReadSpacing.elementSpacing),
              Expanded(
                child: Text(
                  AppConstants.appName,
                  style: PolyReadTypography.interfaceTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              
              // Skip button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _completeOnboarding,
                  borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PolyReadSpacing.elementSpacing,
                      vertical: PolyReadSpacing.smallSpacing,
                    ),
                    child: Text(
                      'Skip',
                      style: PolyReadTypography.interfaceButton.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: PolyReadSpacing.majorSpacing),
          
          // Elegant progress indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _premiumOnboardingPages.length,
              (index) {
                final isActive = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  /// Build elegant navigation with reading-focused actions
  Widget _buildElegantNavigation() {
    return Container(
      padding: PolyReadSpacing.getResponsivePadding(context),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button
          if (_currentPage > 0)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _pageController.previousPage(
                    duration: AppConstants.mediumAnimation,
                    curve: Curves.easeInOut,
                  );
                },
                borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PolyReadSpacing.sectionSpacing,
                    vertical: PolyReadSpacing.elementSpacing,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_back_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: PolyReadSpacing.smallSpacing),
                      Text(
                        'Back',
                        style: PolyReadTypography.interfaceButton.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 100),
          
          const Spacer(),
          
          // Next/Get Started button
          Material(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
            child: InkWell(
              onTap: () {
                if (_currentPage < _premiumOnboardingPages.length - 1) {
                  _pageController.nextPage(
                    duration: AppConstants.mediumAnimation,
                    curve: Curves.easeInOut,
                  );
                } else {
                  _completeOnboarding();
                }
              },
              borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: PolyReadSpacing.majorSpacing,
                  vertical: PolyReadSpacing.elementSpacing,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _currentPage < _premiumOnboardingPages.length - 1
                          ? 'Continue'
                          : 'Start Reading',
                      style: PolyReadTypography.interfaceButton.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: PolyReadSpacing.smallSpacing),
                    Icon(
                      _currentPage < _premiumOnboardingPages.length - 1
                          ? Icons.arrow_forward_rounded
                          : Icons.auto_stories_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  List<Widget> get _premiumOnboardingPages => [
    _PremiumOnboardingPage(
      icon: Icons.auto_stories_rounded,
      title: 'Welcome to Premium Reading',
      description: 'Transform any book into an interactive language learning experience with elegant, distraction-free design.',
      illustration: _buildPremiumIllustration(
        Icons.auto_stories_rounded,
        Theme.of(context).colorScheme.primary,
        'Read with style',
      ),
      features: [
        'Premium reading themes',
        'Immersive full-screen experience',
        'Auto-hiding elegant controls',
      ],
    ),
    _PremiumOnboardingPage(
      icon: Icons.translate_rounded,
      title: 'Instant Smart Translation',
      description: 'Tap any word for cycling dictionary meanings, or long-press for detailed context and sentence translation.',
      illustration: _buildPremiumIllustration(
        Icons.translate_rounded,
        Theme.of(context).colorScheme.secondary,
        'Tap to learn',
      ),
      features: [
        'Cycling word meanings',
        'Contextual sentence translation',
        'Reading-optimized popups',
      ],
    ),
    _PremiumOnboardingPage(
      icon: Icons.school_rounded,
      title: 'Intelligent Vocabulary',
      description: 'Build your vocabulary with spaced repetition and save favorite translations for review sessions.',
      illustration: _buildPremiumIllustration(
        Icons.school_rounded,
        Theme.of(context).colorScheme.tertiary,
        'Learn naturally',
      ),
      features: [
        'Spaced repetition system',
        'Progress tracking',
        'Personalized review sessions',
      ],
    ),
    _PremiumOnboardingPage(
      icon: Icons.offline_bolt_rounded,
      title: 'Offline Language Packs',
      description: 'Download comprehensive dictionaries for offline reading and translation without internet dependency.',
      illustration: _buildPremiumIllustration(
        Icons.offline_bolt_rounded,
        Theme.of(context).colorScheme.primary,
        'Always available',
      ),
      features: [
        'Complete offline dictionaries',
        'Bidirectional translation',
        'Multiple language support',
      ],
    ),
  ];
  
  /// Build premium illustration with elegant styling
  Widget _buildPremiumIllustration(IconData icon, Color color, String label) {
    return Column(
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: 0.2),
                color.withValues(alpha: 0.05),
                Colors.transparent,
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              size: 50,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: PolyReadSpacing.elementSpacing),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: PolyReadSpacing.elementSpacing,
            vertical: PolyReadSpacing.smallSpacing,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(PolyReadSpacing.buttonRadius),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            label,
            style: PolyReadTypography.interfaceCaption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// Premium onboarding page with elegant design and feature highlights
class _PremiumOnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget illustration;
  final List<String> features;
  
  const _PremiumOnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.illustration,
    required this.features,
  });
  
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: PolyReadSpacing.getResponsivePadding(context),
        child: Column(
          children: [
            const SizedBox(height: PolyReadSpacing.majorSpacing),
            
            // Illustration
            illustration,
            
            const SizedBox(height: PolyReadSpacing.majorSpacing * 2),
            
            // Title
            Text(
              title,
              style: PolyReadTypography.readingHeadline.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: PolyReadSpacing.elementSpacing),
            
            // Description
            Text(
              description,
              style: PolyReadTypography.readingBody.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: PolyReadSpacing.majorSpacing),
            
            // Feature highlights
            Container(
              padding: const EdgeInsets.all(PolyReadSpacing.sectionSpacing),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(PolyReadSpacing.cardRadius),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Key Features',
                    style: PolyReadTypography.interfaceSubheadline.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: PolyReadSpacing.elementSpacing),
                  ...features.map((feature) => _buildFeatureItem(context, feature)),
                ],
              ),
            ),
            
            const SizedBox(height: PolyReadSpacing.majorSpacing),
          ],
        ),
      ),
    );
  }
  
  /// Build individual feature item with elegant styling
  Widget _buildFeatureItem(BuildContext context, String feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PolyReadSpacing.smallSpacing),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: PolyReadSpacing.elementSpacing),
          Expanded(
            child: Text(
              feature,
              style: PolyReadTypography.interfaceBody.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}