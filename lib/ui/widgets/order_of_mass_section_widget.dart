import 'package:flutter/material.dart';

import '../../data/services/language_preference_service.dart';
import '../../data/services/order_of_mass_service.dart';
import 'language_switcher_widget.dart';

class OrderOfMassSectionWidget extends StatelessWidget {
  final ResolvedOrderOfMassSection section;
  final String language;
  final ValueChanged<String> onLanguageChanged;

  const OrderOfMassSectionWidget({
    super.key,
    required this.section,
    required this.language,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availableLanguages = _collectAvailableLanguages();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          section.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${section.items.length} part${section.items.length == 1 ? '' : 's'}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          if (availableLanguages.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: LanguageSwitcherWidget(
                  currentLanguage: language,
                  availableLanguages: availableLanguages,
                  onLanguageChanged: onLanguageChanged,
                  showLabels: false,
                ),
              ),
            ),
          ...section.items.map(
            (item) => _OrderOfMassItemCard(
              item: item,
              language: item.hasLanguage(language)
                  ? language
                  : item.availableLanguages.firstOrNull ?? LanguagePreferenceService.english,
            ),
          ),
        ],
      ),
    );
  }

  List<String> _collectAvailableLanguages() {
    final ordered = <String>[];
    for (final item in section.items) {
      for (final languageCode in item.availableLanguages) {
        if (!ordered.contains(languageCode)) {
          ordered.add(languageCode);
        }
      }
    }
    return ordered;
  }
}

class _OrderOfMassItemCard extends StatelessWidget {
  final ResolvedOrderOfMassItem item;
  final String language;

  const _OrderOfMassItemCard({
    required this.item,
    required this.language,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.12),
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
            ],
          ),
          const SizedBox(height: 10),
          ...content.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                line,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
