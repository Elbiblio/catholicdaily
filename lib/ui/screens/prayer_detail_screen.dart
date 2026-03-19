import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../data/models/prayer.dart';
import '../../data/services/prayer_service.dart';

class PrayerDetailScreen extends StatefulWidget {
  final Prayer prayer;

  const PrayerDetailScreen({super.key, required this.prayer});

  @override
  State<PrayerDetailScreen> createState() => _PrayerDetailScreenState();
}

class _PrayerDetailScreenState extends State<PrayerDetailScreen> {
  final PrayerService _prayerService = PrayerService();
  bool _isBookmarked = false;

  @override
  void initState() {
    super.initState();
    _loadBookmarkStatus();
    _markAsUsed();
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

  Widget _buildPrayerContent() {
    if (widget.prayer.htmlContent != null && widget.prayer.htmlContent!.isNotEmpty) {
      return Html(
        data: widget.prayer.htmlContent!,
        style: {
          "body": Style(
            fontSize: FontSize(16),
            lineHeight: LineHeight(1.5),
            fontFamily: 'Canterbury',
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
          ),
          "br": Style(margin: Margins.only(bottom: 4)),
          "b": Style(
            fontWeight: FontWeight.bold,
            fontSize: FontSize(17),
            margin: Margins.only(top: 12, bottom: 8),
          ),
          "font": Style(
            fontSize: FontSize(16),
            fontFamily: 'Canterbury',
            color: widget.prayer.htmlContent!.contains('#FF0000') 
                ? Color(0xFF8C1D2F) 
                : null,
          ),
          "html": Style(
            fontSize: FontSize(16),
            fontFamily: 'Canterbury',
          ),
        },
      );
    } else {
      return Text(
        widget.prayer.displayText,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          height: 1.1,
          fontFamily: 'Canterbury',
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
