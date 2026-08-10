import 'package:catholic_daily/core/latest_request_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only the latest request token remains current', () {
    final guard = LatestRequestGuard();

    final first = guard.begin();
    final second = guard.begin();

    expect(guard.isCurrent(first), isFalse);
    expect(guard.isCurrent(second), isTrue);
  });

  test('captured generation becomes stale after a newer request', () {
    final guard = LatestRequestGuard();
    guard.begin();
    final captured = guard.capture();

    guard.begin();

    expect(guard.isCurrent(captured), isFalse);
  });
}
