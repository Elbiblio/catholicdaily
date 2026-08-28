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
    var selected = limit == null || items.length <= limit
        ? List<T>.of(items)
        : List<T>.of(items.take(limit));

    if (limit != null && items.length > limit && selected.isNotEmpty) {
      final boundaryDate = _dateOnly(celebrationDate(selected.last));
      final nextDate = _dateOnly(celebrationDate(items[limit]));
      if (boundaryDate == nextDate) {
        selected = selected
            .where((item) => _dateOnly(celebrationDate(item)) != boundaryDate)
            .toList(growable: false);
      }
    }

    return FeastReminderCapacitySelection<T>(
      selected: selected,
      coverageThrough: selected.isEmpty
          ? null
          : _dateOnly(celebrationDate(selected.last)),
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
