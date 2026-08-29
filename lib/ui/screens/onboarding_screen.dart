import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/liturgical_region.dart';
import '../../data/services/feast_reminder_preferences.dart';
import '../../data/services/feast_reminder_background_service.dart';
import '../../data/services/feast_reminder_service.dart';
import '../../data/services/feast_reminder_schedule_policy.dart';
import '../../data/services/incipit_preference_service.dart';
import '../../data/services/liturgical_region_preference_service.dart';
import '../../data/services/notification_installation_sync_service.dart';
import '../../data/services/notification_occurrence_sync_service.dart';

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

/// Notification slot options. Day-before slots fire the EVENING BEFORE the
/// celebration; day-of slots fire on the actual feast day.
class _NotificationSlot {
  final int hour;
  final int minute;
  final bool dayBefore;
  final String label;
  const _NotificationSlot(this.hour, this.minute, this.dayBefore, this.label);
}

const _kNotificationSlots = <_NotificationSlot>[
  _NotificationSlot(20, 0, true, '8:00 PM'),
  _NotificationSlot(21, 0, true, '9:00 PM'),
  _NotificationSlot(22, 0, true, '10:00 PM'),
  _NotificationSlot(23, 0, true, '11:00 PM'),
  _NotificationSlot(6, 0, false, '6:00 AM'),
  _NotificationSlot(9, 0, false, '9:00 AM'),
  _NotificationSlot(12, 0, false, '12:00 PM'),
  _NotificationSlot(15, 0, false, '3:00 PM'),
  _NotificationSlot(18, 0, false, '6:00 PM'),
];

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  /// Selected notification slot. null = user skipped (no reminders).
  _NotificationSlot? _selectedSlot;
  LiturgicalRegion _selectedRegion = LiturgicalRegion.generalRoman;
  bool _isRegionLoading = true;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.church,
      title: 'Welcome to\nCatholic Daily',
      subtitle: 'Your faithful companion for the liturgical life',
      description:
          'Mass readings, prayers, and Scripture — beautifully presented for daily devotion.\n\nA distraction free digital missal that does not expire.',
      accentIcon: Icons.auto_awesome,
    ),
    _OnboardingPage(
      icon: Icons.calendar_month,
      title: 'Liturgical Calendar',
      subtitle: 'Every day through 2038',
      description:
          'Follow the Church\'s liturgical year with complete daily readings, feast days, liturgical colors, and seasonal context — all available and ready offline.',
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

  // Region and notification steps are appended after the generic intro pages.
  int get _totalPages => _pages.length + 2;
  bool _isRegionStep(int index) => index == _pages.length;
  bool _isNotificationsStep(int index) => index == _pages.length + 1;

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
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
    _fadeController.forward();
    _slideController.forward();
    _loadRegion();
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

  Future<void> _loadRegion() async {
    try {
      final prefs = await LiturgicalRegionPreferenceService.getInstance();
      final region = await prefs.detectAndSetIfUnset();
      if (!mounted) return;
      setState(() {
        _selectedRegion = region;
        _isRegionLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isRegionLoading = false);
    }
  }

  Future<void> _complete() async {
    try {
      final regionPrefs = await LiturgicalRegionPreferenceService.getInstance();
      await regionPrefs.setRegion(_selectedRegion);
      await IncipitPreferenceService().clearLocaleOverride();
    } catch (e) {
      debugPrint('[Onboarding] Liturgical region setup failed: $e');
    }

    // Persist notification choice, if any. Skipping leaves reminders disabled.
    try {
      final prefs = await FeastReminderPreferences.getInstance();
      final svc = FeastReminderService.instance;
      await svc.initialize();
      FeastReminderScheduleResult? scheduleResult;
      if (_selectedSlot != null) {
        final slot = _selectedSlot!;
        await prefs.setEnabled(true);
        await prefs.setRank(FeastReminderRank.feastsDays);
        await prefs.setTime(slot.hour, slot.minute);
        await prefs.setNotifyDayBefore(slot.dayBefore);
        try {
          await svc.requestPermission();
        } catch (_) {}
        scheduleResult = await svc.scheduleAheadMonths(15, prefs);
      } else {
        // User explicitly chose not to enable notifications.
        await prefs.setEnabled(false);
      }
      // Mark auto-setup done so main.dart doesn't override the user's choice.
      await prefs.markAutoSetupCompleted();
      NotificationScheduleSyncCoordinator(
        syncInstallation:
            NotificationInstallationSyncService.instance.syncCurrentToken,
        syncOccurrences: () => NotificationOccurrenceSyncService.instance
            .syncPending(installationAbsenceIsSuccess: _selectedSlot == null),
        enqueueRepair: FeastReminderBackgroundService.instance.enqueueRepair,
      ).dispatch(
        installationFirst: _selectedSlot != null,
        forceRepair: scheduleResult?.needsImmediateRepair ?? false,
      );
    } catch (e) {
      // Non-fatal — onboarding completes regardless of notification setup.
      debugPrint('[Onboarding] Notification setup failed: $e');
    }

    await OnboardingScreen.markComplete();
    widget.onComplete();
  }

  void _next() {
    if (_currentPage < _totalPages - 1) {
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
    final isLastPage = _currentPage == _totalPages - 1;
    final isNotificationsStep = _isNotificationsStep(_currentPage);
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
                    itemCount: _totalPages,
                    itemBuilder: (context, index) {
                      if (_isNotificationsStep(index)) {
                        return _buildNotificationsStep(index);
                      }
                      if (_isRegionStep(index)) {
                        return _buildRegionStep(index);
                      }
                      return _buildPage(_pages[index], index);
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
                          _totalPages,
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
                              _buttonLabel(isLastPage, isNotificationsStep),
                              key: ValueKey(
                                '$isLastPage-$isNotificationsStep-${_selectedSlot?.label}',
                              ),
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
      opacity: _currentPage == index
          ? _fadeAnimation
          : const AlwaysStoppedAnimation(1.0),
      child: SlideTransition(
        position: _currentPage == index
            ? _slideAnimation
            : const AlwaysStoppedAnimation(Offset.zero),
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
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.5,
                      ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
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

  String _buttonLabel(bool isLastPage, bool isNotificationsStep) {
    if (!isLastPage) return 'Continue';
    if (isNotificationsStep) {
      return _selectedSlot != null ? 'Begin Your Journey' : 'Skip Reminders';
    }
    return 'Begin Your Journey';
  }

  Widget _buildRegionStep(int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FadeTransition(
      opacity: _currentPage == index
          ? _fadeAnimation
          : const AlwaysStoppedAnimation(1.0),
      child: SlideTransition(
        position: _currentPage == index
            ? _slideAnimation
            : const AlwaysStoppedAnimation(Offset.zero),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.18),
                    width: 2,
                  ),
                ),
                child: Icon(Icons.public, size: 42, color: colorScheme.primary),
              ),
              const SizedBox(height: 28),
              Text(
                'Liturgical Calendar',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose the calendar used for holy days and feast reminders.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              DropdownButtonFormField<LiturgicalRegion>(
                key: ValueKey(_selectedRegion),
                initialValue: _selectedRegion,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Country or region',
                  border: OutlineInputBorder(),
                ),
                items: LiturgicalRegion.selectable.map((region) {
                  return DropdownMenuItem(
                    value: region,
                    child: Text(region.label, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: _isRegionLoading
                    ? null
                    : (region) {
                        if (region == null) return;
                        setState(() => _selectedRegion = region);
                      },
              ),
              const SizedBox(height: 12),
              Text(
                _selectedRegion.subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsStep(int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FadeTransition(
      opacity: _currentPage == index
          ? _fadeAnimation
          : const AlwaysStoppedAnimation(1.0),
      child: SlideTransition(
        position: _currentPage == index
            ? _slideAnimation
            : const AlwaysStoppedAnimation(Offset.zero),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              // Header icon
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.18),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.notifications_active_outlined,
                  size: 38,
                  color: colorScheme.primary,
                ),
              ),

              const SizedBox(height: 18),

              Text(
                'Feast Day Reminders',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'When should we let you know?',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 18),

              // Two grouped sections: evening before / day of.
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSlotGroup(
                        theme,
                        title: 'Evening before',
                        subtitle: 'A quiet preview, the night prior',
                        slots: _kNotificationSlots
                            .where((s) => s.dayBefore)
                            .toList(),
                      ),
                      const SizedBox(height: 18),
                      _buildSlotGroup(
                        theme,
                        title: 'On the day',
                        subtitle: 'A reminder during the celebration itself',
                        slots: _kNotificationSlots
                            .where((s) => !s.dayBefore)
                            .toList(),
                      ),
                      const SizedBox(height: 14),
                      // None / skip option
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _selectedSlot = null),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedSlot == null
                                  ? colorScheme.primary.withValues(alpha: 0.5)
                                  : colorScheme.outline.withValues(alpha: 0.25),
                              width: _selectedSlot == null ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _selectedSlot == null
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                size: 20,
                                color: _selectedSlot == null
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'No reminders for now',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    Text(
                                      'You can enable them later in Settings',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlotGroup(
    ThemeData theme, {
    required String title,
    required String subtitle,
    required List<_NotificationSlot> slots,
  }) {
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: slots.map((slot) => _buildSlotChip(theme, slot)).toList(),
        ),
      ],
    );
  }

  Widget _buildSlotChip(ThemeData theme, _NotificationSlot slot) {
    final colorScheme = theme.colorScheme;
    final selected =
        _selectedSlot != null &&
        _selectedSlot!.hour == slot.hour &&
        _selectedSlot!.dayBefore == slot.dayBefore;
    return GestureDetector(
      onTap: () => setState(() => _selectedSlot = slot),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: selected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Text(
          slot.label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
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
