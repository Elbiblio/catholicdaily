import 'dart:async';
import 'dart:io';

import 'package:catholic_daily/data/services/feast_reminder_schedule_lock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes overlapping schedule updates', () async {
    final lockFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'catholic-daily-feast-lock-test-${DateTime.now().microsecondsSinceEpoch}',
    );
    final lock = FeastReminderScheduleLock(file: lockFile);
    final firstEntered = Completer<void>();
    final releaseFirst = Completer<void>();
    var secondEntered = false;

    final first = lock.synchronized(() async {
      firstEntered.complete();
      await releaseFirst.future;
    });
    await firstEntered.future;
    final second = lock.synchronized(() async {
      secondEntered = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(secondEntered, isFalse);
    releaseFirst.complete();
    await Future.wait([first, second]);
    expect(secondEntered, isTrue);

    if (await lockFile.exists()) {
      await lockFile.delete();
    }
  });
}
