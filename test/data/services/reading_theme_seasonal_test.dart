import 'package:catholic_daily/data/services/reading_theme_index.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catholic_daily/data/models/hymn.dart';

void main() {
  test('seasonal Gospel passages resolve their central themes', () {
    final index = ReadingThemeIndex();
    const cases = <String, String>{
      'Matt 24:37-44': 'watchfulness',
      'Mk 13:33-37': 'watchfulness',
      'Luke 21:25-28, 34-36': 'watchfulness',
      'Matt 3:1-12': 'repentance',
      'Mark 1:1-8': 'repentance',
      'Luke 3:10-18': 'repentance',
      'Luke 1:26-38': 'incarnation',
      'Luke 2:1-14': 'incarnation',
      'Matt 2:1-12': 'epiphany',
      'Matt 3:13-17': 'baptism',
      'Mark 1:12-15': 'temptation',
      'Luke 4:1-13': 'temptation',
      'Matt 17:1-9': 'transfiguration',
      'Mark 9:2-10': 'transfiguration',
      'Luke 15:1-3, 11-32': 'reconciliation',
      'John 20:19-31': 'resurrection',
      'John 10:1-10': 'shepherd',
      'John 10:27-30': 'shepherd',
      'John 15:1-8': 'abiding_in_christ',
      'John 15:9-17': 'neighbor_love',
      'Matt 5:1-12a': 'beatitudes',
      'Luke 6:17, 20-26': 'beatitudes',
      'Matt 5:13-16': 'witness',
      'Luke 5:1-11': 'discipleship',
      'Matt 5:38-48': 'neighbor_love',
      'Luke 6:27-38': 'neighbor_love',
      'Matt 6:24-34': 'trust',
      'Mark 4:35-41': 'trust',
      'Luke 10:1-12, 17-20': 'mission',
      'John 6:24-35': 'eucharist',
      'Matt 18:21-35': 'forgiveness',
      'Matt 22:34-40': 'neighbor_love',
      'Mark 12:28b-34': 'neighbor_love',
      'Matt 25:1-13': 'watchfulness',
      'Matt 25:31-46': 'neighbor_love',
      'Luke 15:1-10': 'mercy',
      'Luke 17:11-19': 'thanksgiving',
      'Luke 18:1-8': 'prayer',
      'Luke 18:9-14': 'humility',
      'Mark 10:35-45': 'service',
      'Matt 11:25-30': 'trust',
      'Mark 8:27-35': 'discipleship',
    };
    for (final entry in cases.entries) {
      expect(
        index.themesFor(entry.key),
        contains(entry.value),
        reason: entry.key,
      );
    }
  });

  test('discontinuous verse ranges require an exact matching selection', () {
    final index = ReadingThemeIndex();
    expect(index.themesFor('Lk 21:25–28,34–36'), contains('watchfulness'));
    expect(index.themesFor('Jo 6:51-58'), contains('eucharist'));
    expect(index.themesFor('Luke 21:25-28'), isEmpty);
    expect(index.themesFor('Luke 21:25-28,34-37'), isEmpty);
    expect(index.themesFor('Luke 21:25-28,34-36,40'), isEmpty);
  });
  test('curated hymn themes match without relying on phrase overlap', () {
    final index = ReadingThemeIndex();
    final indexed = Hymn(
      id: 590,
      slug: 'wake_awake',
      title: 'Wake, Awake',
      category: 'advent',
      lyrics: ['The watchmen are crying'],
    );
    final unrelated = Hymn(
      id: 999,
      slug: 'unrelated',
      title: 'Morning',
      category: 'entrance',
      lyrics: ['The watchmen are crying'],
    );
    expect(index.hymnScore(indexed, {'watchfulness': 1}), greaterThan(0));
    expect(index.hymnScore(unrelated, {'watchfulness': 1}), 0);
  });
}
