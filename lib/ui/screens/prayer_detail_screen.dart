import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../data/models/prayer.dart';
import '../../data/services/prayer_service.dart';
import '../../data/services/language_preference_service.dart';
import '../widgets/language_switcher_widget.dart';

class PrayerDetailScreen extends StatefulWidget {
  final Prayer prayer;

  const PrayerDetailScreen({super.key, required this.prayer});

  @override
  State<PrayerDetailScreen> createState() => _PrayerDetailScreenState();
}

class _PrayerDetailScreenState extends State<PrayerDetailScreen> {
  final PrayerService _prayerService = PrayerService();
  final LanguagePreferenceService _languageService = LanguagePreferenceService();
  bool _isBookmarked = false;
  String _currentLanguage = 'en';

  @override
  void initState() {
    super.initState();
    _loadBookmarkStatus();
    _markAsUsed();
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    final language = await _languageService.getPreferredLanguage();
    if (mounted) {
      setState(() {
        _currentLanguage = language;
      });
    }
  }

  Future<void> _loadBookmarkStatus() async {
    final bookmarked = await _prayerService.isBookmarked(widget.prayer);
    if (mounted) {
      setState(() {
        _isBookmarked = bookmarked;
      });
    }
  }

  Future<void> _markAsUsed() async {
    await _prayerService.markPrayerAsUsed(widget.prayer);
  }

  Future<void> _toggleBookmark() async {
    await _prayerService.toggleBookmark(widget.prayer);
    setState(() {
      _isBookmarked = !_isBookmarked;
    });
  }

  Future<void> _onLanguageChanged(String language) async {
    await _languageService.setPreferredLanguage(language);
    if (mounted) {
      setState(() {
        _currentLanguage = language;
      });
    }
  }

  Widget _buildPrayerContent() {
    // Check if prayer has language-separated content
    if (widget.prayer.contentByLanguage != null && 
        widget.prayer.contentByLanguage!.isNotEmpty) {
      
      final languageContent = widget.prayer.getContentForLanguage(_currentLanguage);
      if (languageContent != null) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            languageContent.join('\n\n'),
            key: ValueKey(_currentLanguage),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.1,
              fontSize: _currentLanguage == 'la' ? 18 : 16,
            ),
          ),
        );
      }
    }

    // Fallback to original HTML or text content
    if (widget.prayer.htmlContent != null && widget.prayer.htmlContent!.isNotEmpty) {
      return Html(
        data: widget.prayer.htmlContent!,
        style: {
          "body": Style(
            fontSize: FontSize(16),
            lineHeight: LineHeight(1.5),
            fontFamily: null, // Default readable font for body
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
          ),
          "h1": Style(
            fontSize: FontSize(20),
            fontFamily: 'Canterbury', // Canterbury font for titles
            fontWeight: FontWeight.bold,
            margin: Margins.only(bottom: 16),
          ),
          "h2": Style(
            fontSize: FontSize(18),
            fontFamily: 'Canterbury', // Canterbury font for titles
            fontWeight: FontWeight.bold,
            margin: Margins.only(bottom: 12),
          ),
          "h3": Style(
            fontSize: FontSize(17),
            fontFamily: 'Canterbury', // Canterbury font for titles
            fontWeight: FontWeight.bold,
            margin: Margins.only(bottom: 10),
          ),
          "br": Style(margin: Margins.only(bottom: 4)),
          "b": Style(
            fontWeight: FontWeight.bold,
            fontSize: FontSize(17),
            margin: Margins.only(top: 12, bottom: 8),
          ),
          "font": Style(
            fontSize: FontSize(16),
            fontFamily: null, // Default readable font for regular text
            color: widget.prayer.htmlContent!.contains('#FF0000') 
                ? Color(0xFF8C1D2F) 
                : null,
          ),
          "html": Style(
            fontSize: FontSize(16),
            fontFamily: null, // Default readable font for content
          ),
          "img": Style(
            width: Width(200, Unit.px),
            height: Height(150, Unit.px),
            margin: Margins.only(top: 8, bottom: 16),
            alignment: Alignment.center,
          ),
        },
      );
    } else {
      return Text(
        widget.prayer.displayText,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          height: 1.1,
          fontFamily: null, // Default readable font for body text
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.prayer.title),
        actions: [
          // Add language switcher if prayer has multiple languages
          if (widget.prayer.availableLanguages != null && 
              widget.prayer.availableLanguages!.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: LanguageSwitcherWidget(
                currentLanguage: _currentLanguage,
                availableLanguages: widget.prayer.availableLanguages,
                onLanguageChanged: _onLanguageChanged,
                showLabels: false,
              ),
            ),
          IconButton(
            icon: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_border),
            onPressed: _toggleBookmark,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _sharePrayer,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.prayer.firstLine.isNotEmpty && 
                widget.prayer.firstLine != widget.prayer.displayText.split('\n')[0])
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.prayer.firstLine,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            _buildPrayerContent(),
          ],
        ),
      ),
    );
  }

  void _sharePrayer() {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality coming soon')),
    );
  }
}
