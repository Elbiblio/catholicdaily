import 'dart:async';

import 'package:flutter/material.dart';
import '../../data/models/hymn.dart';
import '../../data/services/hymn_favorites_service.dart';
import '../../data/services/hymn_midi_service.dart';
import '../../data/services/hymn_user_preferences.dart';
import '../utils/sing_along_timeline.dart';
import '../utils/meter_parser.dart';
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
  final HymnMidiService _midiService = HymnMidiService();
  
  bool _isFavorite = false;
  bool _professionalMode = true; // Classic mode
  double _fontSize = 20.0;
  int _manualBpm = 0; // 0 means use hymn.bpm or default
  bool _showBpmSlider = false;
  
  SingAlongTimeline _timeline = const SingAlongTimeline.empty();
  final Stopwatch _karaokeWatch = Stopwatch();
  Timer? _karaokeTicker;
  int _currentWordGlobalIndex = 0;
  int _currentLineIndex = 0;
  StreamSubscription? _midiStateSubscription;

  @override
  void initState() {
    super.initState();
    _loadFavoriteStatus();
    _loadUserPreferences();
    _initializeTimeline();
    
    _midiStateSubscription = _midiService.stateStream.listen((state) {
      _onMidiStateChanged(state);
    });
  }

  @override
  void dispose() {
    _midiStateSubscription?.cancel();
    _karaokeTicker?.cancel();
    _karaokeWatch.stop();
    _midiService.dispose();
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
    setState(() {
      _professionalMode = HymnUserPreferences.professionalMode;
      _fontSize = HymnUserPreferences.defaultFontSize;
      _manualBpm = HymnUserPreferences.manualBpm.toInt();
      _showBpmSlider = HymnUserPreferences.showBpmSlider;
    });
  }

  Future<void> _saveUserPreferences() async {
    await HymnUserPreferences.setProfessionalMode(_professionalMode);
    await HymnUserPreferences.setDefaultFontSize(_fontSize);
    await HymnUserPreferences.setManualBpm(_manualBpm.toDouble());
    await HymnUserPreferences.setShowBpmSlider(_showBpmSlider);
  }

  void _initializeTimeline() {
    final bpm = _effectiveBpm();
    _timeline = SingAlongTimeline.fromLyrics(
      widget.hymn.displayLyrics,
      bpm: bpm,
      meterRaw: widget.hymn.meter,
      tunePhraseMap: widget.hymn.primaryTune != null 
          ? TunePhraseMap.fromMap(widget.hymn.primaryTune!)
          : null,
    );
  }

  int _effectiveBpm() {
    if (_manualBpm > 0) return _manualBpm;
    if (widget.hymn.bpm != null && widget.hymn.bpm! > 0) return widget.hymn.bpm!;
    return 120; // Default BPM
  }

  void _onMidiStateChanged(HymnMidiState state) {
    _syncKaraokeWithAudio(state);
    
    if (state.isCalibrating && state.detectedBpm != null) {
      // BPM detected from calibration
      setState(() {
        _manualBpm = state.detectedBpm!;
      });
      _saveUserPreferences();
      _rebuildTimeline(resetProgress: true);
    }
  }

  void _rebuildTimeline({bool resetProgress = true}) {
    final bpm = _effectiveBpm();
    setState(() {
      _timeline = SingAlongTimeline.fromLyrics(
        widget.hymn.displayLyrics,
        bpm: bpm,
        meterRaw: widget.hymn.meter,
        tunePhraseMap: widget.hymn.primaryTune != null 
            ? TunePhraseMap.fromMap(widget.hymn.primaryTune!)
            : null,
      );
      if (resetProgress) {
        _resetKaraokeProgress();
      }
    });
  }

  void _resetKaraokeProgress() {
    _karaokeTicker?.cancel();
    _karaokeWatch.stop();
    _currentWordGlobalIndex = 0;
    _currentLineIndex = 0;
  }

  void _syncKaraokeWithAudio(HymnMidiState audioState) {
    if (audioState.isPlaying && audioState.positionMs != null) {
      if (_karaokeWatch.isRunning) {
        _karaokeWatch.stop();
      }
      _karaokeTicker?.cancel();
      _updateKaraokeProgress(audioState.positionMs);
      return;
    }

    if (audioState.isPlaying && !_professionalMode) {
      if (!_karaokeWatch.isRunning) {
        _karaokeWatch.start();
        _karaokeTicker = Timer.periodic(
          const Duration(milliseconds: 50),
          (_) => _updateKaraokeProgress(),
        );
      }
    } else {
      _karaokeTicker?.cancel();
      _karaokeWatch.stop();
    }
  }

  void _updateKaraokeProgress([int? positionMs]) {
    final ms = positionMs ?? _karaokeWatch.elapsedMilliseconds;
    final wordIndex = _timeline.wordIndexAt(ms);
    
    if (wordIndex != _currentWordGlobalIndex) {
      setState(() {
        _currentWordGlobalIndex = wordIndex;
        _currentLineIndex = _timeline.lineIndexForWord(wordIndex);
      });
    }
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
      _resetKaraokeProgress();
      await _midiService.playAsset('assets/midi/${widget.hymn.midiFile}');
    }
  }

  void _stopMidi() async {
    await _midiService.stop();
    _resetKaraokeProgress();
  }

  void _startCalibration() {
    _midiService.startCalibration();
    _playMidi();
  }

  void _stopCalibration() {
    _midiService.stopCalibration();
  }

  void _recordCalibrationTap() {
    _midiService.recordTap();
  }

  void _resetCalibration() {
    _midiService.resetCalibration();
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
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final midiState = _midiService.state;

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
          const SizedBox(height: 10),
          _buildModeTabs(theme),
          if (!_professionalMode && _showBpmSlider) ...[
            const SizedBox(height: 8),
            _buildCompactBpmPanel(theme),
          ],
          if (midiState.isCalibrating) ...[
            const SizedBox(height: 8),
            _buildCalibrationPanel(theme, midiState),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                _professionalMode ? 'Lyrics' : 'Sing Along',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: isDark
                      ? const Color(0xFFF2E9D2)
                      : const Color(0xFF6A4A12),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (!_professionalMode && !midiState.isCalibrating)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showBpmSlider = !_showBpmSlider;
                    });
                    _saveUserPreferences();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_effectiveBpm()} BPM',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: isDark
                                ? const Color(0xFFEED9A0)
                                : const Color(0xFF8A5C00),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _showBpmSlider ? Icons.expand_less : Icons.expand_more,
                          size: 15,
                          color: isDark
                              ? const Color(0xFFEED9A0)
                              : const Color(0xFF8A5C00),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (!_professionalMode && !midiState.isCalibrating) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                GestureDetector(
                  onTap: _startCalibration,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app,
                          size: 16,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Calibrate Tempo',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],

          ..._buildLyricLines(theme),
        ],
      ),
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
              // MIDI button
              if (widget.hymn.midiFile != null)
                _buildCompactMediaIcon(
                  theme: theme,
                  icon: Icons.piano,
                  onTap: midiState.isPlaying ? _stopMidi : _playMidi,
                  tooltip: midiState.isPlaying ? 'Stop' : 'Play MIDI',
                  isActive: midiState.isPlaying,
                ),
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

  Widget _buildModeTabs(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeTab(
              theme: theme,
              label: 'Classic',
              icon: Icons.menu_book_rounded,
              selected: _professionalMode,
              onTap: () {
                setState(() {
                  _professionalMode = true;
                  _resetKaraokeProgress();
                });
                _saveUserPreferences();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildModeTab(
              theme: theme,
              label: 'Sing Along',
              icon: Icons.auto_awesome,
              selected: !_professionalMode,
              onTap: () {
                setState(() {
                  _professionalMode = false;
                  _syncKaraokeWithAudio(_midiService.state);
                });
                _saveUserPreferences();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required ThemeData theme,
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? scheme.primary.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary.withValues(alpha: 0.24) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactBpmPanel(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Slider(
            value: _manualBpm == 0 ? _effectiveBpm().toDouble() : _manualBpm.toDouble(),
            min: 56,
            max: 132,
            divisions: 76,
            onChanged: (value) {
              setState(() {
                _manualBpm = value.round();
              });
              _saveUserPreferences();
              _rebuildTimeline(resetProgress: false);
            },
          ),
          Center(
            child: Text(
              '${_manualBpm == 0 ? _effectiveBpm() : _manualBpm} BPM',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrationPanel(ThemeData theme, HymnMidiState midiState) {
    final scheme = theme.colorScheme;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tap to the beat',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: _resetCalibration,
                    child: Text(
                      'Reset',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _stopCalibration,
                    child: Text(
                      'Done',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _recordCalibrationTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.touch_app,
                    size: 32,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap here in rhythm',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (midiState.detectedBpm != null)
            Text(
              'Detected: ${midiState.detectedBpm} BPM (${midiState.tapTimestamps.length} taps)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildLyricLines(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    if (_professionalMode) {
      return [
        RichContentView(
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
        ),
      ];
    }

    final lineWidgets = <Widget>[];

    for (var i = 0; i < _timeline.lines.length; i++) {
      final line = _timeline.lines[i];
      final isActiveLine = !_professionalMode && _currentLineIndex == i;

      final baseColor = isDark
          ? const Color(0xFFE8ECF7)
          : const Color(0xFF2A2E35);
      final activeColor = isDark
          ? const Color(0xFFFFE7AD)
          : const Color(0xFF7C4F00);

      lineWidgets.add(
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: (!_professionalMode && line.words.isNotEmpty)
              ? () {
                  // Could add tap-to-seek functionality here
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isActiveLine
                  ? (isDark
                        ? const Color(0xFF2C3550).withValues(alpha: 0.55)
                        : const Color(0xFFECDDB8).withValues(alpha: 0.6))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: _fontSize,
                    height: 1.22,
                    color: baseColor,
                  ),
                  children: [
                    for (var w = 0; w < line.words.length; w++)
                      TextSpan(
                        text:
                            '${line.words[w].text}${w == line.words.length - 1 ? '' : ' '}',
                        style: TextStyle(
                          color:
                              line.words[w].globalIndex <= _currentWordGlobalIndex
                                  ? activeColor
                                  : baseColor,
                          fontWeight:
                              line.words[w].globalIndex <= _currentWordGlobalIndex
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      if (line.hasBreakAfter) {
        lineWidgets.add(const SizedBox(height: 14));
      }
    }

    return lineWidgets;
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
    ).then((_) => setState(() {}));
  }
}
