import 'package:catholic_daily/data/services/reading_narration_controller.dart';
import 'package:catholic_daily/ui/widgets/narration_mini_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('is absent until playback has started', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NarrationMiniPlayer(
            visible: false,
            state: ReadingNarrationState(),
          ),
        ),
      ),
    );

    expect(find.byKey(NarrationMiniPlayer.playerKey), findsNothing);
  });

  testWidgets('offers compact playback, stop, dismiss, and speed controls', (
    tester,
  ) async {
    var previous = 0;
    var toggle = 0;
    var next = 0;
    var stop = 0;
    var dismiss = 0;
    double? rate;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NarrationMiniPlayer(
            visible: true,
            state: const ReadingNarrationState(
              status: NarrationStatus.playing,
              currentIndex: 1,
              queue: [],
              progress: 0.4,
              supportsNativePause: true,
            ),
            canGoPrevious: true,
            canGoNext: true,
            rate: 0.5,
            onPrevious: () => previous++,
            onPlayPause: () => toggle++,
            onNext: () => next++,
            onStop: () => stop++,
            onDismiss: () => dismiss++,
            onRateChanged: (value) => rate = value,
          ),
        ),
      ),
    );

    expect(find.byKey(NarrationMiniPlayer.playerKey), findsOneWidget);
    expect(find.byTooltip('Previous reading'), findsOneWidget);
    expect(find.byTooltip('Pause reading'), findsOneWidget);
    expect(find.byTooltip('Next reading'), findsOneWidget);
    expect(find.byTooltip('Stop reading'), findsOneWidget);
    expect(find.byTooltip('Dismiss player'), findsOneWidget);
    expect(find.text('0.5×'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.tap(find.byTooltip('Previous reading'));
    await tester.tap(find.byTooltip('Pause reading'));
    await tester.tap(find.byTooltip('Next reading'));
    await tester.tap(find.byTooltip('Stop reading'));
    await tester.tap(find.byTooltip('Dismiss player'));
    expect((previous, toggle, next, stop, dismiss), (1, 1, 1, 1, 1));

    await tester.tap(find.text('0.5×'));
    expect(rate, 0.75);
  });

  testWidgets('paused state exposes resume', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NarrationMiniPlayer(
            visible: true,
            state: ReadingNarrationState(
              status: NarrationStatus.paused,
              supportsNativePause: true,
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Resume reading'), findsOneWidget);
  });

  testWidgets('fallback playback labels its primary action stop and restart', (
    tester,
  ) async {
    Future<void> pump(NarrationStatus status) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NarrationMiniPlayer(
            visible: true,
            state: ReadingNarrationState(
              status: status,
              supportsNativePause: false,
            ),
          ),
        ),
      ),
    );

    await pump(NarrationStatus.playing);
    expect(find.byTooltip('Stop and keep position'), findsOneWidget);
    expect(find.byTooltip('Pause reading'), findsNothing);

    await pump(NarrationStatus.paused);
    expect(find.byTooltip('Restart from position'), findsOneWidget);
    expect(find.byTooltip('Resume reading'), findsNothing);
  });

  testWidgets('compact controls fit a narrow phone without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NarrationMiniPlayer(
            visible: true,
            state: ReadingNarrationState(status: NarrationStatus.playing),
            canGoPrevious: true,
            canGoNext: true,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(NarrationMiniPlayer.playerKey), findsOneWidget);
  });

  testWidgets('unknown engine speed offers recovery using the safe fallback', (
    tester,
  ) async {
    final changes = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NarrationMiniPlayer(
            visible: true,
            state: const ReadingNarrationState(status: NarrationStatus.stopped),
            rate: null,
            fallbackRate: 0.75,
            onRateChanged: changes.add,
          ),
        ),
      ),
    );

    expect(find.byTooltip('Speech speed unavailable'), findsOneWidget);
    expect(find.text('—×'), findsOneWidget);
    await tester.tap(find.text('—×'));
    expect(changes, <double>[0.75]);
  });
}
