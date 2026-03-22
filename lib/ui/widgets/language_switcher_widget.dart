import 'package:flutter/material.dart';
import '../../data/services/language_preference_service.dart';

class LanguageSwitcherWidget extends StatefulWidget {
  final String? currentLanguage;
  final List<String>? availableLanguages;
  final ValueChanged<String>? onLanguageChanged;
  final bool showLabels;

  const LanguageSwitcherWidget({
    super.key,
    this.currentLanguage,
    this.availableLanguages,
    this.onLanguageChanged,
    this.showLabels = true,
  });

  @override
  State<LanguageSwitcherWidget> createState() => _LanguageSwitcherWidgetState();
}

class _LanguageSwitcherWidgetState extends State<LanguageSwitcherWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late String _currentLanguage;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _currentLanguage = widget.currentLanguage ?? LanguagePreferenceService.english;
  }

  @override
  void didUpdateWidget(LanguageSwitcherWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentLanguage != null && widget.currentLanguage != _currentLanguage) {
      _currentLanguage = widget.currentLanguage!;
      _animationController.forward().then((_) {
        _animationController.reverse();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = LanguagePreferenceService();
    final languages = widget.availableLanguages ?? service.availableLanguages;
    
    if (languages.length < 2) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: languages.map((language) {
              final isSelected = language == _currentLanguage;
              
              return Flexible(
                fit: FlexFit.loose,
                child: GestureDetector(
                  onTap: () => _switchLanguage(language),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.all(4.0),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.showLabels) ...[
                          Text(
                            service.getLanguageDisplayName(language),
                            style: TextStyle(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Icon(
                          language == LanguagePreferenceService.english 
                              ? Icons.translate_outlined
                              : Icons.menu_book,
                          size: 16,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _switchLanguage(String language) async {
    if (language == _currentLanguage) return;

    setState(() {
      _currentLanguage = language;
    });

    await _animationController.forward();
    await _animationController.reverse();

    widget.onLanguageChanged?.call(language);
  }
}

class CompactLanguageSwitcher extends StatelessWidget {
  final String currentLanguage;
  final VoidCallback? onTap;

  const CompactLanguageSwitcher({
    super.key,
    required this.currentLanguage,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final service = LanguagePreferenceService();
    final displayName = service.getLanguageDisplayName(currentLanguage);
    final isLatin = currentLanguage == LanguagePreferenceService.latin;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLatin ? Icons.menu_book : Icons.translate_outlined,
              size: 14,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 4),
            Text(
              displayName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                fontFamily: isLatin ? 'Canterbury' : null,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 14,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}
