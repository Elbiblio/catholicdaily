import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  static const _keyOnboardingComplete = 'onboarding_complete';

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_keyOnboardingComplete) ?? false);
  }

  static Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingComplete, true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.church,
      title: 'Welcome to\nCatholic Daily',
      subtitle: 'Your faithful companion for the liturgical life',
      description:
          'Mass readings, prayers, and Scripture — beautifully presented for daily devotion.',
      accentIcon: Icons.auto_awesome,
    ),
    _OnboardingPage(
      icon: Icons.calendar_month,
      title: 'Liturgical Calendar',
      subtitle: 'Every day through 2038',
      description:
          'Follow the Church\'s liturgical year with complete daily readings, feast days, liturgical colors, and seasonal context — all calculated and ready offline.',
      accentIcon: Icons.event_available,
    ),
    _OnboardingPage(
      icon: Icons.menu_book,
      title: 'Scripture & Bible',
      subtitle: 'The complete Catholic Bible, offline',
      description:
          'Read the RSV Catholic Edition with full search, bookmarks, text-to-speech, and adjustable text. Download additional translations anytime.',
      accentIcon: Icons.bookmark_added,
    ),
    _OnboardingPage(
      icon: Icons.favorite,
      title: 'Prayers & Rosary',
      subtitle: 'Over 100 traditional prayers',
      description:
          'Pray with the Church — from the complete Rosary with all four mysteries to classic devotions in multiple languages. Bookmark your favorites.',
      accentIcon: Icons.translate,
    ),
    _OnboardingPage(
      icon: Icons.lightbulb,
      title: 'Insights & Reflection',
      subtitle: 'Deepen your understanding',
      description:
          'Explore context and meaning behind the readings. Let the Word of God speak to your heart with thoughtful, faith-informed insights.',
      accentIcon: Icons.psychology,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
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

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _fadeController.reset();
    _slideController.reset();
    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _complete() async {
    await OnboardingScreen.markComplete();
    widget.onComplete();
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLastPage = _currentPage == _pages.length - 1;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          // Subtle gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.surface,
                  colorScheme.surface,
                  colorScheme.primaryContainer.withValues(alpha: 0.15),
                ],
              ),
            ),
          ),

          // Page content
          SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, right: 8),
                    child: TextButton(
                      onPressed: _complete,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                // Pages
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      return _buildPage(page, index);
                    },
                  ),
                ),

                // Page indicator + button
                Padding(
                  padding: EdgeInsets.only(
                    left: 32,
                    right: 32,
                    bottom: 24 + bottomPadding,
                    top: 16,
                  ),
                  child: Column(
                    children: [
                      // Page dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (index) => _buildDot(index, colorScheme),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Action button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: _next,
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              isLastPage ? 'Begin Your Journey' : 'Continue',
                              key: ValueKey(isLastPage),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FadeTransition(
      opacity: _currentPage == index ? _fadeAnimation : const AlwaysStoppedAnimation(1.0),
      child: SlideTransition(
        position: _currentPage == index ? _slideAnimation : const AlwaysStoppedAnimation(Offset.zero),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 1),

              // Icon with decorative ring
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow ring
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        width: 2,
                      ),
                    ),
                  ),
                  // Inner filled circle
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                    ),
                    child: Icon(
                      page.icon,
                      size: 52,
                      color: colorScheme.primary,
                    ),
                  ),
                  // Small accent icon
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.secondaryContainer,
                        border: Border.all(
                          color: colorScheme.surface,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        page.accentIcon,
                        size: 18,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Title
              Text(
                page.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 12),

              // Subtitle badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  page.subtitle,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Description
              Text(
                page.description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot(int index, ColorScheme colorScheme) {
    final isActive = index == _currentPage;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 28 : 8,
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: isActive
            ? colorScheme.primary
            : colorScheme.outline.withValues(alpha: 0.3),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final IconData accentIcon;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.accentIcon,
  });
}
