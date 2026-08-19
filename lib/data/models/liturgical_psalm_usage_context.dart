enum LiturgicalPsalmUsageKind { temporal, celebration, specialPeriod }

class LiturgicalPsalmUsageContext {
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

  const LiturgicalPsalmUsageContext._({
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
  });

  const LiturgicalPsalmUsageContext.temporal({
    required String territory,
    required String season,
    required int week,
    required int weekday,
    String sundayCycle = '',
    String weekdayCycle = '',
  }) : this._(
         territory: territory,
         kind: LiturgicalPsalmUsageKind.temporal,
         season: season,
         week: week,
         weekday: weekday,
         sundayCycle: sundayCycle,
         weekdayCycle: weekdayCycle,
       );

  const LiturgicalPsalmUsageContext.celebration({
    required String territory,
    required String celebrationId,
    String massForm = 'day',
    String sundayCycle = '',
    String weekdayCycle = '',
  }) : this._(
         territory: territory,
         kind: LiturgicalPsalmUsageKind.celebration,
         celebrationId: celebrationId,
         massForm: massForm,
         sundayCycle: sundayCycle,
         weekdayCycle: weekdayCycle,
       );

  const LiturgicalPsalmUsageContext.specialPeriod({
    required String territory,
    required String specialDay,
    String massForm = '',
    String sundayCycle = '',
    String weekdayCycle = '',
  }) : this._(
         territory: territory,
         kind: LiturgicalPsalmUsageKind.specialPeriod,
         specialDay: specialDay,
         massForm: massForm,
         sundayCycle: sundayCycle,
         weekdayCycle: weekdayCycle,
       );
}
