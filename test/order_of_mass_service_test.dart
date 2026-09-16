import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:catholic_daily/data/models/daily_reading.dart';
import 'package:catholic_daily/data/services/mass_flow_composer.dart';
import 'package:catholic_daily/data/services/order_of_mass_service.dart';
import 'package:catholic_daily/data/services/prayer_service.dart';

import 'helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();
  mockMethodChannels();
  SharedPreferences.setMockInitialValues({});

  group('OrderOfMassService', () {
    test('loads and resolves configured sections', () async {
      final prayerService = PrayerService();
      await prayerService.initialize();

      final service = OrderOfMassService();
      final sections = await service.getSectionsForDate(DateTime(2026, 1, 11));

      expect(sections, isNotEmpty);
      expect(
        sections.any((section) => section.insertionPoint == 'introductory_rites'),
        isTrue,
      );
      expect(
        sections.any((section) => section.insertionPoint == 'after_gospel'),
        isTrue,
      );

      final introductory = sections.firstWhere(
        (section) => section.insertionPoint == 'introductory_rites',
      );
      expect(
        introductory.items.any((item) => item.id == 'sign_of_the_cross'),
        isTrue,
      );
    });

    test('filters Sunday-only items on weekdays', () async {
      final service = OrderOfMassService();
      final sections = await service.getSectionsForDate(DateTime(2026, 1, 12));

      final afterGospel =
          sections.where((section) => section.insertionPoint == 'after_gospel');
      if (afterGospel.isEmpty) {
        expect(afterGospel, isEmpty);
        return;
      }

      expect(
        afterGospel.every(
          (section) => section.items.every((item) => item.id != 'creed'),
        ),
        isTrue,
      );
    });

    test('substitutes Gospel dialogue [N] when lectionary readings are provided',
        () async {
      final service = OrderOfMassService();
      final readings = [
        DailyReading(
          reading: 'Matt 4:1-11',
          position: 'Gospel',
          date: DateTime(2026, 1, 12),
        ),
      ];
      final sections = await service.getSectionsForDate(
        DateTime(2026, 1, 12),
        lectionaryReadings: readings,
      );
      final beforeGospel = sections.where((s) => s.insertionPoint == 'before_gospel');
      expect(beforeGospel, isNotEmpty);
      final gospelIntro = beforeGospel.first.items.where((i) => i.id == 'gospel');
      expect(gospelIntro, isNotEmpty);
      final en = gospelIntro.first.getContentForLanguage('en');
      expect(en, isNotNull);
      expect(
        en!.any((line) => line.contains('Matthew') && !line.contains('[N]')),
        isTrue,
      );
    });
  });

  group('MassFlowComposer', () {
    Widget _sectionWidget(String name) => SizedBox(key: ValueKey(name));
    Widget _readingsWidget(int count) => SizedBox(key: ValueKey('readings_$count'));
    Widget _gospelWidget() => SizedBox(key: const ValueKey('gospel'));

    ResolvedOrderOfMassSection _section(String insertionPoint) {
      return ResolvedOrderOfMassSection(
        insertionPoint: insertionPoint,
        title: insertionPoint,
        items: [
          ResolvedOrderOfMassItem(
            id: 'item_$insertionPoint',
            title: insertionPoint,
            insertionPoint: insertionPoint,
            order: 1,
            contentByLanguage: {'en': ['text']},
            availableLanguages: ['en'],
            isOptional: false,
          ),
        ],
      );
    }

    test('orders pre-Gospel readings before before_gospel section', () {
      final sections = [
        _section('introductory_rites'),
        _section('before_gospel'),
      ];
      final readings = [
        DailyReading(
          reading: 'Gen 1:1-5',
          position: 'First Reading',
          date: DateTime(2026, 1, 12),
        ),
        DailyReading(
          reading: 'Matt 5:1-12',
          position: 'Gospel',
          date: DateTime(2026, 1, 12),
        ),
      ];

      final composer = MassFlowComposer(sections: sections, readings: readings);
      final widgets = composer.compose(
        buildSection: (_) => _sectionWidget('section'),
        buildReadings: (preGospel) => _readingsWidget(preGospel.length),
        buildGospelReading: (_) => _gospelWidget(),
      );

      final keys = widgets.map((w) => (w as SizedBox).key).toList();
      final readingsIndex = keys.indexOf(const ValueKey('readings_1'));
      final gospelIndex = keys.indexOf(const ValueKey('gospel'));

      expect(readingsIndex, lessThan(gospelIndex));
    });

    test('Gospel reading appears after before_gospel section', () {
      final sections = [_section('before_gospel')];
      final readings = [
        DailyReading(
          reading: 'Matt 5:1-12',
          position: 'Gospel',
          date: DateTime(2026, 1, 12),
        ),
      ];

      final composer = MassFlowComposer(sections: sections, readings: readings);
      final widgets = composer.compose(
        buildSection: (_) => _sectionWidget('section'),
        buildReadings: (preGospel) => _readingsWidget(preGospel.length),
        buildGospelReading: (_) => _gospelWidget(),
      );

      final keys = widgets.map((w) => (w as SizedBox).key).toList();
      final sectionIndex = keys.indexOf(const ValueKey('section'));
      final gospelIndex = keys.indexOf(const ValueKey('gospel'));
      expect(sectionIndex, lessThan(gospelIndex));
    });

    test('after_gospel section appears after the Gospel reading', () {
      final sections = [_section('before_gospel'), _section('after_gospel')];
      final readings = [
        DailyReading(
          reading: 'Matt 5:1-12',
          position: 'Gospel',
          date: DateTime(2026, 1, 12),
        ),
      ];

      final composer = MassFlowComposer(sections: sections, readings: readings);
      final widgets = composer.compose(
        buildSection: (section) => _sectionWidget(section.insertionPoint),
        buildReadings: (preGospel) => _readingsWidget(preGospel.length),
        buildGospelReading: (_) => _gospelWidget(),
      );

      final keys = widgets.map((w) => (w as SizedBox).key).toList();
      final gospelIndex = keys.indexOf(const ValueKey('gospel'));
      final afterGospelIndex = keys.indexOf(const ValueKey('after_gospel'));
      expect(afterGospelIndex, greaterThan(gospelIndex));
    });

    test('between_readings section appears between pre-Gospel readings and before_gospel', () {
      final sections = [_section('between_readings'), _section('before_gospel')];
      final readings = [
        DailyReading(
          reading: 'Gen 1:1-5',
          position: 'First Reading',
          date: DateTime(2026, 1, 12),
        ),
        DailyReading(
          reading: 'Matt 5:1-12',
          position: 'Gospel',
          date: DateTime(2026, 1, 12),
        ),
      ];

      final composer = MassFlowComposer(sections: sections, readings: readings);
      final widgets = composer.compose(
        buildSection: (section) => _sectionWidget(section.insertionPoint),
        buildReadings: (preGospel) => _readingsWidget(preGospel.length),
        buildGospelReading: (_) => _gospelWidget(),
      );

      final keys = widgets.map((w) => (w as SizedBox).key).toList();
      final readingsIndex = keys.indexOf(const ValueKey('readings_1'));
      final betweenIndex = keys.indexOf(const ValueKey('between_readings'));
      final gospelIndex = keys.indexOf(const ValueKey('gospel'));

      expect(readingsIndex, lessThan(betweenIndex));
      expect(betweenIndex, lessThan(gospelIndex));
    });

    test('handles empty readings gracefully', () {
      final sections = [_section('introductory_rites')];

      final composer = MassFlowComposer(sections: sections, readings: null);
      final widgets = composer.compose(
        buildSection: (_) => _sectionWidget('section'),
        buildReadings: (preGospel) => _readingsWidget(preGospel.length),
        buildGospelReading: (_) => _gospelWidget(),
      );

      expect(widgets.isNotEmpty, isTrue);
      expect(widgets.whereType<SizedBox>().any((w) => (w.key as ValueKey).value.toString().startsWith('readings_')), isFalse);
    });

    test('handles no before_gospel section', () {
      final sections = [_section('introductory_rites')];
      final readings = [
        DailyReading(
          reading: 'Matt 5:1-12',
          position: 'Gospel',
          date: DateTime(2026, 1, 12),
        ),
      ];

      final composer = MassFlowComposer(sections: sections, readings: readings);
      final widgets = composer.compose(
        buildSection: (_) => _sectionWidget('section'),
        buildReadings: (preGospel) => _readingsWidget(preGospel.length),
        buildGospelReading: (_) => _gospelWidget(),
      );

      final keys = widgets.map((w) => (w as SizedBox).key).toList();
      expect(keys.contains(const ValueKey('gospel')), isTrue);
      expect(keys.where((k) => k == const ValueKey('gospel')).length, 1);
    });

    test('excludes acclamation position from pre-Gospel readings', () {
      final readings = [
        DailyReading(
          reading: 'Gen 1:1-5',
          position: 'First Reading',
          date: DateTime(2026, 1, 12),
        ),
        DailyReading(
          reading: 'Alleluia',
          position: 'Gospel Acclamation',
          date: DateTime(2026, 1, 12),
        ),
      ];

      final composer = MassFlowComposer(sections: [], readings: readings);
      final widgets = composer.compose(
        buildSection: (_) => _sectionWidget('section'),
        buildReadings: (preGospel) => _readingsWidget(preGospel.length),
        buildGospelReading: (_) => _gospelWidget(),
      );

      final readingsWidgets = widgets.whereType<SizedBox>().where((w) => (w.key as ValueKey).value.toString().startsWith('readings_'));
      expect(readingsWidgets.length, 1);
      expect((readingsWidgets.first.key as ValueKey).value, 'readings_1');
    });
  });
}
