/// Days of prayer and public observances, independent of liturgical rank.
/// These never select or replace Mass readings.
class CalendarObservance {
  final String title;
  final String description;
  final int month;
  final int day;
  final int firstYear;
  final String sourceUrl;

  const CalendarObservance({
    required this.title,
    required this.description,
    required this.month,
    required this.day,
    required this.firstYear,
    required this.sourceUrl,
  });
}

class CalendarObservanceService {
  static List<CalendarObservance> forDate(DateTime date) => [
    for (final observance in _observances)
      if (date.month == observance.month &&
          date.day == observance.day &&
          date.year >= observance.firstYear)
        observance,
  ];

  static const _observances = [
    CalendarObservance(
      title: 'World Day of Peace',
      description:
          'A day of prayer for peace, observed alongside the Solemnity of Mary, the Holy Mother of God.',
      month: 1,
      day: 1,
      firstYear: 1968,
      sourceUrl:
          'https://www.vatican.va/content/leo-xiv/en/messages/peace/documents/20251208-messaggio-pace.html',
    ),
    CalendarObservance(
      title: 'Earth Day',
      description:
          'An international environmental observance inviting care for our common home. The Mass readings follow the liturgical day.',
      month: 4,
      day: 22,
      firstYear: 1970,
      sourceUrl:
          'https://www.vaticanobservatory.org/event/international-earth-day/2025-04-22/',
    ),
    CalendarObservance(
      title: 'World Day of Prayer for the Care of Creation',
      description:
          'The Church joins in prayer for the protection of creation. The Mass readings follow the liturgical day.',
      month: 9,
      day: 1,
      firstYear: 2015,
      sourceUrl:
          'https://www.vatican.va/content/francesco/en/messages/cura-creato/documents/papa-francesco_20150806_lettera-giornata-cura-creato.html',
    ),
  ];
}
