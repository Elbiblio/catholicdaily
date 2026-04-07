import 'package:flutter/material.dart';
import '../../data/services/improved_liturgical_calendar_service.dart';
import '../../data/services/order_of_mass_service.dart';
import '../../data/services/order_of_mass_preference_service.dart';
import '../../data/services/language_preference_service.dart';
import '../../data/services/prayer_of_faithful_loader_service.dart';
import '../widgets/parchment_background.dart';
import '../widgets/language_switcher_widget.dart';

class MassFlowScreen extends StatefulWidget {
  final DateTime? date;

  const MassFlowScreen({
    super.key,
    this.date,
  });

  @override
  State<MassFlowScreen> createState() => _MassFlowScreenState();
}

class _MassFlowScreenState extends State<MassFlowScreen> {
  final OrderOfMassService _orderOfMassService = OrderOfMassService();
  final OrderOfMassPreferenceService _orderOfMassPreference = OrderOfMassPreferenceService();
  final LanguagePreferenceService _languageService = LanguagePreferenceService();
  final ImprovedLiturgicalCalendarService _calendarService = ImprovedLiturgicalCalendarService.instance;
  final PrayerOfFaithfulLoaderService _prayerLoader = PrayerOfFaithfulLoaderService();

  late DateTime _selectedDate;
  String _primaryLanguage = 'en';
  String _secondaryLanguage = 'en';
  List<ResolvedOrderOfMassSection>? _sections;
  LiturgicalDay? _liturgicalDay;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.date ?? DateTime.now();
    _initialize();
  }

  Future<void> _initialize() async {
    final primaryLang = await _languageService.getPreferredLanguage();
    final secondaryLang = await _orderOfMassPreference.getPreferredLanguage();

    if (mounted) {
      setState(() {
        _primaryLanguage = primaryLang;
        _secondaryLanguage = secondaryLang;
      });
    }

    await _loadMassForDate(_selectedDate);
  }

  Future<void> _loadMassForDate(DateTime date) async {
    setState(() => _isLoading = true);

    try {
      final liturgicalDay = await _calendarService.getLiturgicalDay(date);
      final sections = await _orderOfMassService.getSectionsForDate(
        date,
        languageCode: _secondaryLanguage,
      );

      if (mounted) {
        setState(() {
          _selectedDate = date;
          _liturgicalDay = liturgicalDay;
          _sections = sections;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading mass: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      await _loadMassForDate(picked);
    }
  }

  void _onPrimaryLanguageChanged(String language) async {
    await _languageService.setPreferredLanguage(language);
    setState(() => _primaryLanguage = language);
  }

  void _onSecondaryLanguageChanged(String language) async {
    await _orderOfMassPreference.setPreferredLanguage(language);
    setState(() => _secondaryLanguage = language);
    await _loadMassForDate(_selectedDate);
  }

  Future<void> _populatePrayerDatabase() async {
    setState(() => _isLoading = true);
    
    try {
      await _prayerLoader.populateDatabase(
        year: _selectedDate.year,
        languageCode: _secondaryLanguage,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prayer database populated successfully')),
        );
        await _loadMassForDate(_selectedDate);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error populating database: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Order of Mass'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
            tooltip: 'Select Date',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'download') {
                _populatePrayerDatabase();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'download',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 12),
                    Text('Populate Prayer Database'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ParchmentBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _sections == null || _sections!.isEmpty
                ? _buildEmptyState()
                : _buildMassContent(theme),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No mass content available',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Try selecting a different date',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMassContent(ThemeData theme) {
    return CustomScrollView(
      slivers: [
        if (_liturgicalDay != null) _buildLiturgicalHeader(theme),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildLanguageSwitchers(theme),
          ),
        ),
        ..._sections!.map((section) => _buildSection(section)),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildLiturgicalHeader(ThemeData theme) {
    final ordoColor = _liturgicalDay!.colorValue;

    return SliverToBoxAdapter(
      child: Container(
        color: ordoColor.withValues(alpha: 0.15),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedDate.toString().split(' ')[0],
              style: theme.textTheme.labelLarge?.copyWith(
                color: ordoColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _liturgicalDay!.fullDescription,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: ordoColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _liturgicalDay!.weekDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSwitchers(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Language',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LanguageSwitcherWidget(
                    currentLanguage: _primaryLanguage,
                    availableLanguages: _languageService.availableLanguages,
                    onLanguageChanged: _onPrimaryLanguageChanged,
                    showLabels: true,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mass Prayers',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LanguageSwitcherWidget(
                    currentLanguage: _secondaryLanguage,
                    availableLanguages: _orderOfMassPreference.availableLanguages,
                    onLanguageChanged: _onSecondaryLanguageChanged,
                    showLabels: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSection(ResolvedOrderOfMassSection section) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: _MassFlowSectionWidget(
          section: section,
          language: _secondaryLanguage,
          liturgicalColor: _liturgicalDay?.colorValue,
        ),
      ),
    );
  }
}

class _MassFlowSectionWidget extends StatefulWidget {
  final ResolvedOrderOfMassSection section;
  final String language;
  final Color? liturgicalColor;

  const _MassFlowSectionWidget({
    required this.section,
    required this.language,
    this.liturgicalColor,
  });

  @override
  State<_MassFlowSectionWidget> createState() => _MassFlowSectionWidgetState();
}

class _MassFlowSectionWidgetState extends State<_MassFlowSectionWidget> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sectionColor = widget.liturgicalColor ?? theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: sectionColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Section header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: sectionColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.section.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: sectionColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.section.items.length} part${widget.section.items.length == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: sectionColor,
                  ),
                ],
              ),
            ),
          ),
          // Section items
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: widget.section.items.map((item) {
                  return _MassFlowItemCard(
                    item: item,
                    language: widget.language,
                    sectionColor: sectionColor,
                  );
                }).toList(),
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}

class _MassFlowItemCard extends StatelessWidget {
  final ResolvedOrderOfMassItem item;
  final String language;
  final Color sectionColor;

  const _MassFlowItemCard({
    required this.item,
    required this.language,
    required this.sectionColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = item.getContentForLanguage(language) ?? const <String>[];
    
    if (content.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: sectionColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (item.isOptional)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Optional',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (item.role != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: sectionColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _formatRole(item.role!),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: sectionColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ...content.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                line,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatRole(String role) {
    switch (role.toLowerCase()) {
      case 'priest':
        return 'Priest';
      case 'deacon':
      case 'deacon_or_priest':
        return 'Deacon/Priest';
      case 'lector':
        return 'Lector';
      case 'cantor':
        return 'Cantor';
      case 'choir':
        return 'Choir';
      case 'all':
        return 'All';
      default:
        return role;
    }
  }
}
