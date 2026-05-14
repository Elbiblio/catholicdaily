enum LiturgicalRegion {
  generalRoman('general', 'General Roman Calendar', 'Universal baseline'),
  brazil('BR', 'Brazil', 'CNBB: Ascension on Sunday, Corpus Christi Thursday'),
  mexico('MX', 'Mexico', 'CEM: Ascension on Sunday, Corpus Christi Thursday'),
  nigeria('NG', 'Nigeria', 'Catholic Bishops Conference of Nigeria'),
  unitedStates('US', 'United States', 'Most dioceses: Ascension on Sunday'),
  unitedStatesAscensionThursday(
    'US_ASC_THU',
    'United States - Ascension Thursday',
    'Boston, Hartford, New York, Omaha, Philadelphia',
  ),
  englandWales(
    'GB_EW',
    'England & Wales',
    'Calendar of the Bishops\' Conference',
  );

  final String code;
  final String label;
  final String subtitle;

  const LiturgicalRegion(this.code, this.label, this.subtitle);

  static const selectable = <LiturgicalRegion>[
    brazil,
    mexico,
    nigeria,
    unitedStates,
    unitedStatesAscensionThursday,
    englandWales,
    generalRoman,
  ];

  static LiturgicalRegion fromCode(String? code) {
    final normalized = (code ?? '').trim().toUpperCase();
    return LiturgicalRegion.values.firstWhere(
      (region) => region.code.toUpperCase() == normalized,
      orElse: () => LiturgicalRegion.generalRoman,
    );
  }

  static LiturgicalRegion fromCountryCode(String? countryCode) {
    switch ((countryCode ?? '').trim().toUpperCase()) {
      case 'NG':
        return LiturgicalRegion.nigeria;
      case 'BR':
        return LiturgicalRegion.brazil;
      case 'MX':
        return LiturgicalRegion.mexico;
      case 'US':
        return LiturgicalRegion.unitedStates;
      case 'GB':
      case 'UK':
      case 'EN':
      case 'WA':
        return LiturgicalRegion.englandWales;
      default:
        return LiturgicalRegion.generalRoman;
    }
  }

  bool get celebratesAscensionOnThursday =>
      this != LiturgicalRegion.unitedStates &&
      this != LiturgicalRegion.brazil &&
      this != LiturgicalRegion.mexico;

  bool get celebratesEpiphanyOnFixedDate =>
      this == LiturgicalRegion.generalRoman ||
      this == LiturgicalRegion.englandWales;

  bool get celebratesCorpusChristiOnSunday =>
      this == LiturgicalRegion.nigeria ||
      this == LiturgicalRegion.unitedStates ||
      this == LiturgicalRegion.unitedStatesAscensionThursday ||
      this == LiturgicalRegion.englandWales;

  bool get transfersSaturdayMondayHolydaysToSunday =>
      this == LiturgicalRegion.englandWales;

  bool get transfersFixedSolemnitiesToFollowingSunday =>
      this == LiturgicalRegion.brazil;

  String get defaultIncipitLocale {
    switch (this) {
      case LiturgicalRegion.brazil:
      case LiturgicalRegion.mexico:
        return 'en';
      case LiturgicalRegion.nigeria:
        return 'en-NG';
      case LiturgicalRegion.unitedStates:
      case LiturgicalRegion.unitedStatesAscensionThursday:
        return 'en-US';
      case LiturgicalRegion.englandWales:
        return 'en-GB';
      case LiturgicalRegion.generalRoman:
        return 'en';
    }
  }
}
