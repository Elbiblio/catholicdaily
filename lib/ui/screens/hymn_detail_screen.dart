import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/hymn.dart';
import '../../data/services/hymn_favorites_service.dart';
import '../../data/services/hymn_midi_service.dart';
import '../../data/services/hymn_user_preferences.dart';
import '../widgets/rich_content_view.dart';

class HymnDetailScreen extends StatefulWidget {
  final Hymn hymn;

  const HymnDetailScreen({
    super.key,
    required this.hymn,
  });

  @override
  State<HymnDetailScreen> createState() => _HymnDetailScreenState();
}

class _HymnDetailScreenState extends State<HymnDetailScreen> {
  final HymnFavoritesService _favoritesService = HymnFavoritesService.instance;
  final HymnMidiService _midiService = HymnMidiService.instance;
  StreamSubscription<HymnMidiState>? _midiSubscription;

  bool _isFavorite = false;
  double _fontSize = 20.0;

  @override
  void initState() {
    super.initState();
    _loadFavoriteStatus();
    _loadUserPreferences();
    _midiSubscription = _midiService.stateStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _midiSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadFavoriteStatus() async {
    final isFavorite = await _favoritesService.isFavorite(widget.hymn.id);
    if (mounted) {
      setState(() {
        _isFavorite = isFavorite;
      });
    }
  }

  Future<void> _loadUserPreferences() async {
    await HymnUserPreferences.init();
    if (mounted) {
      setState(() {
        _fontSize = HymnUserPreferences.defaultFontSize;
      });
    }
  }

  Future<void> _saveUserPreferences() async {
    await HymnUserPreferences.setDefaultFontSize(_fontSize);
  }

  Future<void> _toggleFavorite() async {
    await _favoritesService.toggleFavorite(widget.hymn.id);
    if (mounted) {
      setState(() {
        _isFavorite = !_isFavorite;
      });
    }
  }

  Future<void> _playMidi() async {
    if (widget.hymn.midiFile != null) {
      try {
        final state = _midiService.state;
        if (state.isPaused &&
            state.currentFile == 'assets/midi/${widget.hymn.midiFile}') {
          await _midiService.resume();
        } else {
          await _midiService.playAsset('assets/midi/${widget.hymn.midiFile}');
        }
      } catch (e) {
        if (mounted) {
          final errorState = _midiService.state;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorState.errorMessage ?? 'Audio file not available for this hymn')),
          );
        }
      }
    }
  }

  Future<void> _pauseMidi() async {
    await _midiService.pause();
  }

  Future<void> _stopMidi() async {
    await _midiService.stop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            toolbarHeight: 62,
            pinned: true,
            backgroundColor: scheme.primary,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.hymn.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 16, end: 16),
              background: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primary,
                      isDark
                          ? const Color(0xFF1B2332)
                          : const Color(0xFF2A5A7D),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                onPressed: _toggleFavorite,
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: Colors.white,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'font_size') {
                    _showFontSizeDialog();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'font_size',
                    child: Row(
                      children: [
                        Icon(Icons.text_fields),
                        SizedBox(width: 8),
                        Text('Font Size'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildLyricCard(theme),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildLyricCard(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF121621), const Color(0xFF181E2C)]
              : [const Color(0xFFFCF8EE), const Color(0xFFF7F2E6)],
        ),
        border: Border.all(
          color: isDark
              ? const Color(0xFF2E3A56).withValues(alpha: 0.8)
              : const Color(0xFFD8CFAF).withValues(alpha: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.34)
                : const Color(0xFFB7A06B).withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCompactHeaderPanel(theme),
          const SizedBox(height: 16),
          _buildLyricsSection(theme),
        ],
      ),
    );
  }

  Widget _buildLyricsSection(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return RichContentView(
      content: widget.hymn.content,
      fallbackLines: widget.hymn.displayLyrics,
      fontSize: _fontSize,
      centered: true,
      baseStyle: theme.textTheme.bodyLarge?.copyWith(
        fontSize: _fontSize,
        height: 1.18,
        color: isDark ? const Color(0xFFE8ECF7) : const Color(0xFF2A2E35),
        fontWeight: FontWeight.w400,
      ),
      accentColor: isDark ? const Color(0xFFFFE7AD) : const Color(0xFF7C4F00),
    );
  }

  Widget _buildCompactHeaderPanel(ThemeData theme) {
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final midiState = _midiService.state;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.hymn.hymnNumber != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFFEED9A0).withValues(alpha: 0.2)
                              : const Color(0xFF8A5C00).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#${widget.hymn.hymnNumber}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isDark
                                ? const Color(0xFFEED9A0)
                                : const Color(0xFF8A5C00),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (widget.hymn.hymnNumber != null) const SizedBox(height: 8),
                    Text(
                      widget.hymn.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isDark
                            ? const Color(0xFFF2E9D2)
                            : const Color(0xFF6A4A12),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (widget.hymn.author != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.hymn.author!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? const Color(0xFFEED9A0).withValues(alpha: 0.7)
                              : const Color(0xFF8A5C00).withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // MIDI controls
              if (widget.hymn.midiFile != null) ...[
                _buildCompactMediaIcon(
                  theme: theme,
                  icon: midiState.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  onTap: midiState.isPlaying ? _pauseMidi : _playMidi,
                  tooltip: midiState.isPlaying ? 'Pause' : 'Play',
                  isActive: midiState.isPlaying || midiState.isPaused,
                ),
                if (midiState.isPlaying || midiState.isPaused) ...[
                  const SizedBox(width: 6),
                  _buildCompactMediaIcon(
                    theme: theme,
                    icon: Icons.stop_rounded,
                    onTap: _stopMidi,
                    tooltip: 'Stop',
                    isActive: false,
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMediaIcon({
    required ThemeData theme,
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    required bool isActive,
  }) {
    final scheme = theme.colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive 
                ? scheme.primary.withValues(alpha: 0.2)
                : scheme.surface.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive 
                  ? scheme.primary.withValues(alpha: 0.4)
                  : scheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isActive ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Font Size'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: _fontSize,
                min: 15,
                max: 30,
                divisions: 15,
                onChanged: (value) {
                  setDialogState(() => _fontSize = value);
                },
              ),
              Text(
                '${_fontSize.toInt()}pt',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _saveUserPreferences();
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }
}
