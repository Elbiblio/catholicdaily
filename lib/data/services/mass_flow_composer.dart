import 'package:flutter/material.dart';

import '../models/daily_reading.dart';
import 'order_of_mass_service.dart';

class MassFlowComposer {
  MassFlowComposer({required this.sections, required this.readings});

  final List<ResolvedOrderOfMassSection> sections;
  final List<DailyReading>? readings;

  List<Widget> compose({
    required Widget Function(ResolvedOrderOfMassSection section) buildSection,
    required Widget Function(List<DailyReading> preGospelReadings)
    buildReadings,
    Widget Function(DailyReading acclamationReading)? buildAcclamationReading,
    required Widget Function(DailyReading gospelReading) buildGospelReading,
  }) {
    final widgets = <Widget>[];

    final introRites = sections
        .where((s) => s.insertionPoint == 'introductory_rites')
        .where((s) => s.items.isNotEmpty)
        .toList();
    for (final section in introRites) {
      widgets.add(buildSection(section));
    }

    final beforeFirstReading = sections
        .where((s) => s.insertionPoint == 'before_first_reading')
        .where((s) => s.items.isNotEmpty)
        .toList();
    for (final section in beforeFirstReading) {
      widgets.add(buildSection(section));
    }

    final preGospelReadings = _filterPreGospelReadings();
    if (preGospelReadings.isNotEmpty) {
      widgets.add(buildReadings(preGospelReadings));
    }

    final betweenReadings = sections
        .where((s) => s.insertionPoint == 'between_readings')
        .where((s) => s.items.isNotEmpty)
        .toList();
    for (final section in betweenReadings) {
      widgets.add(buildSection(section));
    }

    if (buildAcclamationReading != null) {
      for (final reading in _filterAcclamationReadings()) {
        widgets.add(buildAcclamationReading(reading));
      }
    }

    final beforeGospel = sections
        .where((s) => s.insertionPoint == 'before_gospel')
        .where((s) => s.items.isNotEmpty)
        .toList();
    for (final section in beforeGospel) {
      widgets.add(buildSection(section));
    }

    final gospelReadings = _filterGospelReadings();
    for (final reading in gospelReadings) {
      widgets.add(buildGospelReading(reading));
    }

    final afterGospel = sections
        .where((s) => s.insertionPoint == 'after_gospel')
        .where((s) => s.items.isNotEmpty)
        .toList();
    for (final section in afterGospel) {
      widgets.add(buildSection(section));
    }

    final eucharisticInsertionPoints = const [
      'offertory',
      'preface',
      'sanctus',
      'acclamation',
      'lords_prayer',
      'sign_of_peace',
      'fraction',
      'communion',
      'after_communion',
      'concluding_rites',
    ];
    for (final insertionPoint in eucharisticInsertionPoints) {
      final eucharisticSections = sections
          .where((s) => s.insertionPoint == insertionPoint)
          .where((s) => s.items.isNotEmpty)
          .toList();
      for (final section in eucharisticSections) {
        widgets.add(buildSection(section));
      }
    }

    return widgets;
  }

  List<DailyReading> _filterPreGospelReadings() {
    if (readings == null) return [];
    return readings!.where((r) {
      final pos = r.position?.toLowerCase() ?? '';
      return !pos.contains('gospel') && !pos.contains('acclamation');
    }).toList();
  }

  List<DailyReading> _filterGospelReadings() {
    if (readings == null) return [];
    return readings!.where((r) {
      final pos = r.position?.toLowerCase() ?? '';
      return pos.contains('gospel') && !pos.contains('acclamation');
    }).toList();
  }

  List<DailyReading> _filterAcclamationReadings() {
    if (readings == null) return [];
    return readings!.where((reading) {
      final position = reading.position?.toLowerCase() ?? '';
      return position.contains('acclamation');
    }).toList();
  }
}
