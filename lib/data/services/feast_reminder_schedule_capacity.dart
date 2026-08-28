class FeastReminderCapacitySelection<T> {
  const FeastReminderCapacitySelection({
    required this.selected,
    required this.coverageThrough,
  });

  final List<T> selected;
  final DateTime? coverageThrough;
}

class FeastReminderScheduleCapacity {
  const FeastReminderScheduleCapacity._({required this.maximumPending});

  factory FeastReminderScheduleCapacity.forAndroid() =>
      const FeastReminderScheduleCapacity._(maximumPending: null);

  factory FeastReminderScheduleCapacity.forIos() =>
      const FeastReminderScheduleCapacity._(maximumPending: 60);

  final int? maximumPending;

  FeastReminderCapacitySelection<T> select<T>(
    List<T> items, {
    required DateTime Function(T item) celebrationDate,
  }) {
    if (items.isEmpty) {
      return FeastReminderCapacitySelection<T>(
        selected: List<T>.empty(growable: false),
        coverageThrough: null,
      );
    }

    final limit = maximumPending;
    if (limit == null) {
      return FeastReminderCapacitySelection<T>(
        selected: List<T>.of(items),
        coverageThrough: _dateOnly(celebrationDate(items.last)),
      );
    }

    final buckets = <DateTime, List<T>>{};
    for (final item in items) {
      final date = _dateOnly(celebrationDate(item));
      (buckets[date] ??= <T>[]).add(item);
    }
    final dates = buckets.keys.toList()..sort();
    final selectedDates = <DateTime>{};
    var selectedCount = 0;
    for (final date in dates) {
      final bucket = buckets[date]!;
      if (selectedCount + bucket.length > limit) break;
      selectedDates.add(date);
      selectedCount += bucket.length;
    }
    final selected = items
        .where(
          (item) => selectedDates.contains(_dateOnly(celebrationDate(item))),
        )
        .toList(growable: false);

    return FeastReminderCapacitySelection<T>(
      selected: selected,
      coverageThrough: selectedDates.isEmpty
          ? null
          : dates[selectedDates.length - 1],
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
