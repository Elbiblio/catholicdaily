import 'dart:async';

import 'package:catholic_daily/app_startup_maintenance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coalesces concurrent maintenance requests', () async {
    final gate = Completer<void>();
    var calls = 0;
    final maintenance = AppStartupMaintenance(() async {
      calls++;
      await gate.future;
    });

    final first = maintenance.run();
    final second = maintenance.run();

    expect(calls, 1);
    expect(identical(first, second), isTrue);

    gate.complete();
    await first;
  });

  test('isolates maintenance failure', () async {
    await AppStartupMaintenance(() async {
      throw StateError('offline');
    }).run();
  });
}
