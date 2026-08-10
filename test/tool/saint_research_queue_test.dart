import '../../tool/saint_research_queue.dart';
import 'package:test/test.dart';

void main() {
  test('queue preserves legacy order across migration states', () {
    final result = SaintResearchQueue.compute(
      legacyIds: const ['a', 'b', 'c'],
      indexedProfiles: const [
        IndexedSaintProfile(id: 'b', state: 'researched'),
        IndexedSaintProfile(id: 'a', state: 'published'),
      ],
    );

    expect(result.published, ['a']);
    expect(result.inProgress, ['b']);
    expect(result.remaining, ['c']);
    expect(result.unknownIndexedIds, isEmpty);
  });

  test('queue reports duplicate and unknown indexed ids', () {
    final result = SaintResearchQueue.compute(
      legacyIds: const ['a'],
      indexedProfiles: const [
        IndexedSaintProfile(id: 'x', state: 'published'),
        IndexedSaintProfile(id: 'x', state: 'published'),
      ],
    );

    expect(result.duplicateIndexedIds, ['x']);
    expect(result.unknownIndexedIds, ['x']);
    expect(result.isComplete, isFalse);
  });

  test('queue does not treat duplicate published entries as completion', () {
    final result = SaintResearchQueue.compute(
      legacyIds: const ['a', 'b'],
      indexedProfiles: const [
        IndexedSaintProfile(id: 'a', state: 'published'),
        IndexedSaintProfile(id: 'b', state: 'published'),
        IndexedSaintProfile(id: 'b', state: 'published'),
      ],
    );

    expect(result.published, ['a', 'b']);
    expect(result.duplicateIndexedIds, ['b']);
    expect(result.isComplete, isFalse);
  });
}
