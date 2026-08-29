import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../data/services/bible_version_preference.dart';
import '../../data/services/liturgical_region_preference_service.dart';
import '../../data/services/narration_preferences.dart';
import '../../data/services/reading_narration_controller.dart';
import '../../data/services/reading_narration_queue_builder.dart';
import '../../data/services/responsorial_psalm_preference.dart';
import '../../data/services/speech_engine.dart';
import 'narration_mini_player.dart';

class ReadingNarrationSession extends ChangeNotifier {
  final ReadingNarrationController controller;
  final ReadingNarrationQueueBuilder queueBuilder;
  final NarrationPreferences preferences;

  SpeechEngineSettings _settings;
  bool _playerStarted = false;
  bool _playerDismissed = false;
  bool _disposed = false;
  NarrationContext? _activeContext;
  String? _uiErrorMessage;
  int _uiErrorRevision = 0;

  ReadingNarrationSession({
    required this.controller,
    required this.queueBuilder,
    NarrationPreferences? preferences,
    SpeechEngineSettings settings = const SpeechEngineSettings(),
  }) : preferences = preferences ?? NarrationPreferences(),
       _settings = settings {
    controller.addListener(_onControllerChanged);
  }

  ReadingNarrationState get state => controller.state;
  double get rate => _settings.rate;
  bool get playerVisible => _playerStarted && !_playerDismissed;
  String? get uiErrorMessage => _uiErrorMessage;
  int get uiErrorRevision => _uiErrorRevision;

  Future<void> initialize() async {
    try {
      final settings = await preferences.load();
      if (_disposed) return;
      _settings = settings;
      await controller.updateSettings(settings);
      if (!_disposed) notifyListeners();
    } catch (_) {
      // Conservative defaults remain usable when preference storage is down.
    }
  }

  Future<void> toggle(
    List<ReadingNarrationQueueItem> queue, {
    required NarrationPlaybackMode mode,
    required NarrationContext context,
  }) async {
    final item = queue.isEmpty ? null : queue.first;
    final sameItem = item != null && state.currentItem?.id == item.id;
    if (sameItem && state.status == NarrationStatus.playing) {
      await controller.pause();
      return;
    }
    if (sameItem && state.status == NarrationStatus.paused) {
      await controller.resume();
      return;
    }
    _playerDismissed = false;
    _activeContext = context;
    await controller.play(queue, mode: mode, context: context);
  }

  Future<void> playReadAll(
    List<ReadingNarrationQueueItem> queue, {
    required NarrationContext context,
  }) async {
    _playerDismissed = false;
    _activeContext = context;
    await controller.play(
      queue,
      mode: NarrationPlaybackMode.readAll,
      context: context,
    );
  }

  Future<void> togglePlayerPlayback() async {
    if (state.status == NarrationStatus.playing) {
      await controller.pause();
      return;
    }
    if (state.status == NarrationStatus.paused) {
      await controller.resume();
      return;
    }
    if (state.status == NarrationStatus.loading || state.queue.isEmpty) return;
    _playerDismissed = false;
    await controller.play(
      state.queue,
      mode: state.mode,
      context: _activeContext,
    );
  }

  Future<void> setRate(double rate) async {
    final next = _settings.copyWith(rate: rate);
    try {
      await preferences.setRate(rate);
      if (_disposed) return;
      _settings = next;
      _uiErrorMessage = null;
      await controller.updateSettings(next);
      if (!_disposed) notifyListeners();
    } catch (_) {
      if (_disposed) return;
      _uiErrorMessage = 'Unable to change speech speed.';
      _uiErrorRevision++;
      notifyListeners();
    }
  }

  void dismissPlayer() {
    if (_playerDismissed) return;
    _playerDismissed = true;
    notifyListeners();
  }

  bool isCurrentItem(ReadingNarrationQueueItem? item) =>
      item != null && state.currentItem?.id == item.id;

  NarrationStatus statusFor(ReadingNarrationQueueItem? item) =>
      isCurrentItem(item) ? state.status : NarrationStatus.idle;

  Future<NarrationContext> contextFor({
    required DateTime date,
    required String alternativeKey,
  }) async {
    final values = await Future.wait<Object>(<Future<Object>>[
      BibleVersionPreference.getInstance(),
      LiturgicalRegionPreferenceService.getInstance(),
      ResponsorialPsalmPreference.getInstance(),
    ]);
    final bible = values[0] as BibleVersionPreference;
    final region = values[1] as LiturgicalRegionPreferenceService;
    final psalm = values[2] as ResponsorialPsalmPreference;
    return NarrationContext(
      dateKey: _dateKey(date),
      regionCode: region.currentRegion.code,
      bibleEditionId: bible.currentDbName,
      psalmEditionId: psalm.currentEditionId,
      alternativeKey: alternativeKey,
    );
  }

  void _onControllerChanged() {
    if (_disposed) return;
    if (state.status == NarrationStatus.playing) _playerStarted = true;
    notifyListeners();
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    controller.removeListener(_onControllerChanged);
    controller.dispose();
    super.dispose();
  }
}

class ReadingNarrationScope extends InheritedNotifier<ReadingNarrationSession> {
  const ReadingNarrationScope({
    super.key,
    required ReadingNarrationSession session,
    required super.child,
  }) : super(notifier: session);

  static ReadingNarrationSession of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ReadingNarrationScope>();
    assert(
      scope != null,
      'ReadingNarrationScope is missing above this widget.',
    );
    return scope!.notifier!;
  }

  static ReadingNarrationSession? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ReadingNarrationScope>()
      ?.notifier;
}

class ReadingNarrationHost extends StatefulWidget {
  final Widget child;

  const ReadingNarrationHost({super.key, required this.child});

  @override
  State<ReadingNarrationHost> createState() => _ReadingNarrationHostState();
}

class _ReadingNarrationHostState extends State<ReadingNarrationHost>
    with WidgetsBindingObserver {
  ReadingNarrationSession? _session;
  String? _lastAnnouncementKey;
  int _announcementGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = ReadingNarrationScope.of(context);
    if (identical(session, _session)) return;
    _session?.removeListener(_onSessionChanged);
    _session = session..addListener(_onSessionChanged);
  }

  void _onSessionChanged() {
    final session = _session;
    if (session == null) return;
    final state = session.state;
    final message = _accessibilityMessage(session, state);
    if (message == null) {
      _lastAnnouncementKey = null;
      _announcementGeneration++;
      return;
    }
    final announcementKey =
        '${state.status.name}:${session.uiErrorRevision}:$message';
    if (_lastAnnouncementKey == announcementKey) return;
    _lastAnnouncementKey = announcementKey;
    final generation = ++_announcementGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentSession = _session;
      if (!mounted ||
          currentSession == null ||
          generation != _announcementGeneration ||
          _lastAnnouncementKey != announcementKey ||
          _accessibilityMessage(currentSession, currentSession.state) !=
              message) {
        return;
      }
      SemanticsService.announce(message, Directionality.of(context));
      if (state.status == NarrationStatus.error ||
          state.status == NarrationStatus.unavailable ||
          currentSession.uiErrorMessage != null) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _session?.controller;
    if (controller == null) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        unawaited(controller.onAppPaused());
        break;
      case AppLifecycleState.detached:
        unawaited(controller.onAppDetached());
        break;
      case AppLifecycleState.resumed:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ReadingNarrationScope.of(context);
    return Overlay(
      initialEntries: <OverlayEntry>[
        OverlayEntry(
          builder: (context) => AnimatedBuilder(
            animation: session,
            child: widget.child,
            builder: (context, child) {
              final state = session.state;
              return Column(
                children: <Widget>[
                  Expanded(child: child!),
                  if (_accessibilityMessage(session, state) case final message?)
                    Semantics(
                      container: true,
                      liveRegion: true,
                      label: message,
                      child: const SizedBox.shrink(),
                    ),
                  NarrationMiniPlayer(
                    visible: session.playerVisible,
                    state: state,
                    canGoPrevious: state.currentIndex > 0,
                    canGoNext:
                        state.queue.isNotEmpty &&
                        state.currentIndex < state.queue.length - 1,
                    rate: session.rate,
                    onPrevious: controllerCallback(session.controller.previous),
                    onPlayPause: state.status == NarrationStatus.loading
                        ? null
                        : controllerCallback(session.togglePlayerPlayback),
                    onNext: controllerCallback(session.controller.next),
                    onStop: controllerCallback(session.controller.stop),
                    onDismiss: session.dismissPlayer,
                    onRateChanged: (value) => unawaited(session.setRate(value)),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  VoidCallback controllerCallback(Future<void> Function() action) =>
      () => unawaited(action());

  String? _accessibilityMessage(
    ReadingNarrationSession session,
    ReadingNarrationState state,
  ) =>
      session.uiErrorMessage ??
      switch (state.status) {
        NarrationStatus.loading => 'Loading reading aloud',
        NarrationStatus.paused => 'Reading paused',
        NarrationStatus.completed => 'Reading complete',
        NarrationStatus.error || NarrationStatus.unavailable =>
          state.errorMessage ?? 'Reading aloud is unavailable',
        _ => null,
      };

  @override
  void dispose() {
    _session?.removeListener(_onSessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
