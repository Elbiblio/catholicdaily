import 'package:catholic_daily/data/services/bible_version_preference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a stale downloaded-source failure preserves a newer selection', () {
    expect(
      BibleVersionRecoveryPolicy.versionAfterFailure(
        failedVersion: BibleVersionType.douayRheims,
        currentVersion: BibleVersionType.nabre,
      ),
      BibleVersionType.nabre,
    );
  });

  test('the still-selected failed download recovers to RSVCE', () {
    expect(
      BibleVersionRecoveryPolicy.versionAfterFailure(
        failedVersion: BibleVersionType.douayRheims,
        currentVersion: BibleVersionType.douayRheims,
      ),
      BibleVersionType.rsvce,
    );
  });
}
