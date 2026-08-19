import '../models/liturgical_psalm_usage_context.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'responsorial_psalm_source_pack_service.dart';

class NigeriaPsalmUsageEntry {
  final String usageId;
  final String territory;
  final LiturgicalPsalmUsageKind kind;
  final String celebrationId;
  final String massForm;
  final String season;
  final int? week;
  final int? weekday;
  final String specialDay;
  final String sundayCycle;
  final String weekdayCycle;
  final String referenceNormalized;
  final String referenceDisplay;
  final String responseText;
  final String sourceDate;
  final String sourceSelectionId;
  final String sourceEdition;
  final int choicePriority;
  final String reviewStatus;

  const NigeriaPsalmUsageEntry({
    required this.usageId,
    required this.territory,
    required this.kind,
    this.celebrationId = '',
    this.massForm = '',
    this.season = '',
    this.week,
    this.weekday,
    this.specialDay = '',
    this.sundayCycle = '',
    this.weekdayCycle = '',
    required this.referenceNormalized,
    required this.referenceDisplay,
    required this.responseText,
    required this.sourceDate,
    required this.sourceSelectionId,
    this.sourceEdition = '',
    required this.choicePriority,
    this.reviewStatus = 'verified',
  });

  String get stableKey => switch (kind) {
    LiturgicalPsalmUsageKind.temporal => <String>[
      territory,
      'temporal',
      season,
      week?.toString() ?? '',
      _weekdayName(weekday),
      sundayCycle,
      weekdayCycle,
    ].join('|'),
    LiturgicalPsalmUsageKind.celebration => <String>[
      territory,
      'celebration',
      celebrationId,
      massForm,
      sundayCycle,
      weekdayCycle,
    ].join('|'),
    LiturgicalPsalmUsageKind.specialPeriod => <String>[
      territory,
      'special-period',
      specialDay,
      massForm,
      sundayCycle,
      weekdayCycle,
    ].join('|'),
  };

  static String _weekdayName(int? value) => switch (value) {
    DateTime.monday => 'monday',
    DateTime.tuesday => 'tuesday',
    DateTime.wednesday => 'wednesday',
    DateTime.thursday => 'thursday',
    DateTime.friday => 'friday',
    DateTime.saturday => 'saturday',
    DateTime.sunday => 'sunday',
    _ => '',
  };
}

class NigeriaPsalmUsageService {
  final List<NigeriaPsalmUsageEntry> _entries;

  NigeriaPsalmUsageService.fromEntries(List<NigeriaPsalmUsageEntry> entries)
    : _entries = List.unmodifiable(entries);

  static Future<NigeriaPsalmUsageService> load({AssetBundle? bundle}) async {
    final raw = await (bundle ?? rootBundle).loadString(
      'assets/data/nigeria_psalm_usages.csv',
    );
    return NigeriaPsalmUsageService.fromEntries(parseCsv(raw));
  }

  static List<NigeriaPsalmUsageEntry> parseCsv(String raw) {
    final table = _parseCsv(raw);
    if (table.isEmpty || table.first.length != 19) {
      throw const FormatException('Invalid Nigeria psalm usage header');
    }
    return <NigeriaPsalmUsageEntry>[
      for (var index = 1; index < table.length; index++)
        if (table[index].any((value) => value.isNotEmpty))
          _entryFromColumns(table[index], index + 1),
    ];
  }

  List<NigeriaPsalmUsageEntry> resolve(LiturgicalPsalmUsageContext context) {
    final matches = _entries.where((entry) => _matches(entry, context)).toList()
      ..sort((left, right) {
        final sourceQuality = _sourceQuality(
          right,
        ).compareTo(_sourceQuality(left));
        if (sourceQuality != 0) return sourceQuality;
        final specificity = _specificity(
          right,
          context,
        ).compareTo(_specificity(left, context));
        if (specificity != 0) return specificity;
        final priority = left.choicePriority.compareTo(right.choicePriority);
        if (priority != 0) return priority;
        return left.usageId.compareTo(right.usageId);
      });
    final seen = <String>{};
    return List.unmodifiable(
      matches.where((entry) => seen.add(_selectionKey(entry))),
    );
  }

  int _sourceQuality(NigeriaPsalmUsageEntry entry) {
    // A dated Nigerian Missal selection is direct evidence for the local
    // lectionary wording and must precede reconstructed or fallback choices.
    if (entry.sourceDate.trim().isNotEmpty) return 3;
    if (entry.reviewStatus == 'verified') return 2;
    return 1;
  }

  int _specificity(
    NigeriaPsalmUsageEntry entry,
    LiturgicalPsalmUsageContext context,
  ) {
    var score = 0;
    if (context.sundayCycle.trim().isNotEmpty &&
        entry.sundayCycle.trim().isNotEmpty) {
      score++;
    }
    if (context.weekdayCycle.trim().isNotEmpty &&
        entry.weekdayCycle.trim().isNotEmpty) {
      score++;
    }
    return score;
  }

  String _selectionKey(NigeriaPsalmUsageEntry entry) {
    final reference = ResponsorialPsalmSourcePackService.normalizePackReference(
      entry.referenceNormalized,
    );
    final response = _normalized(
      entry.responseText,
    ).replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    return '$reference|$response';
  }

  bool _matches(
    NigeriaPsalmUsageEntry entry,
    LiturgicalPsalmUsageContext context,
  ) {
    if (entry.kind != context.kind) return false;
    if (_normalized(entry.territory) != _normalized(context.territory)) {
      return false;
    }
    switch (context.kind) {
      case LiturgicalPsalmUsageKind.celebration:
        return _normalized(entry.celebrationId) ==
                _normalized(context.celebrationId) &&
            _normalized(entry.massForm) == _normalized(context.massForm) &&
            _optionalMatches(entry.sundayCycle, context.sundayCycle) &&
            _optionalMatches(entry.weekdayCycle, context.weekdayCycle);
      case LiturgicalPsalmUsageKind.temporal:
        return _normalized(entry.season) == _normalized(context.season) &&
            entry.week == context.week &&
            entry.weekday == context.weekday &&
            _optionalMatches(entry.sundayCycle, context.sundayCycle) &&
            _optionalMatches(entry.weekdayCycle, context.weekdayCycle);
      case LiturgicalPsalmUsageKind.specialPeriod:
        return _normalized(entry.specialDay) ==
                _normalized(context.specialDay) &&
            _normalized(entry.massForm) == _normalized(context.massForm) &&
            _optionalMatches(entry.sundayCycle, context.sundayCycle) &&
            _optionalMatches(entry.weekdayCycle, context.weekdayCycle);
    }
  }

  bool _optionalMatches(String entryValue, String contextValue) {
    return entryValue.trim().isEmpty ||
        _normalized(entryValue) == _normalized(contextValue);
  }

  String _normalized(String value) => value.trim().toLowerCase();

  static NigeriaPsalmUsageEntry _entryFromColumns(
    List<String> columns,
    int rowNumber,
  ) {
    if (columns.length != 19) {
      throw FormatException('Invalid Nigeria psalm usage row $rowNumber');
    }
    return NigeriaPsalmUsageEntry(
      usageId: columns[0],
      territory: columns[1],
      kind: switch (columns[2]) {
        'temporal' => LiturgicalPsalmUsageKind.temporal,
        'celebration' => LiturgicalPsalmUsageKind.celebration,
        'special-period' => LiturgicalPsalmUsageKind.specialPeriod,
        _ => throw FormatException(
          'Invalid Nigeria psalm usage kind at row $rowNumber',
        ),
      },
      celebrationId: columns[3],
      massForm: columns[4],
      season: columns[5],
      week: int.tryParse(columns[6]),
      weekday: _weekdayNumber(columns[7]),
      specialDay: columns[8],
      sundayCycle: columns[9],
      weekdayCycle: columns[10],
      referenceNormalized: columns[11],
      referenceDisplay: columns[12],
      responseText: columns[13],
      sourceDate: columns[14],
      sourceSelectionId: columns[15],
      sourceEdition: columns[16],
      choicePriority: int.parse(columns[17]),
      reviewStatus: columns[18],
    );
  }

  static int? _weekdayNumber(String value) => switch (value) {
    'monday' => DateTime.monday,
    'tuesday' => DateTime.tuesday,
    'wednesday' => DateTime.wednesday,
    'thursday' => DateTime.thursday,
    'friday' => DateTime.friday,
    'saturday' => DateTime.saturday,
    'sunday' => DateTime.sunday,
    _ => null,
  };

  static List<List<String>> _parseCsv(String raw) {
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var quoted = false;
    for (var index = 0; index < raw.length; index++) {
      final char = raw[index];
      if (char == '"') {
        if (quoted && index + 1 < raw.length && raw[index + 1] == '"') {
          field.write('"');
          index++;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        row.add(field.toString());
        field = StringBuffer();
      } else if ((char == '\n' || char == '\r') && !quoted) {
        if (char == '\r' && index + 1 < raw.length && raw[index + 1] == '\n') {
          index++;
        }
        row.add(field.toString());
        field = StringBuffer();
        if (row.any((value) => value.isNotEmpty)) rows.add(row);
        row = <String>[];
      } else {
        field.write(char);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }
}
