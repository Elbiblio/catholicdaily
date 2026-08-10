import '../models/liturgical_region.dart';
import 'feast_reminder_payload.dart';
import 'liturgical_region_preference_service.dart';
import 'offline_ordo_lookup_service.dart';
import 'optional_memorial_service.dart';
import 'saint_profile_service.dart';

/// Resolves notification payloads into stable saint-page destinations.
///
/// Payloads scheduled by releases before schema v1 contain only the date and
/// timing. Those reminders may still be retained by the operating system, so
/// their destination is reconstructed from the offline calendar on tap.
class FeastReminderDestinationResolver {
  static final FeastReminderDestinationResolver instance =
      FeastReminderDestinationResolver._();

  FeastReminderDestinationResolver._();

  Future<OptionalCelebration?> resolve(
    FeastReminderPayload payload, {
    LiturgicalRegion? region,
  }) async {
    final direct = payload.toSaintCelebration();
    if (direct != null) return direct;

    final selectedRegion =
        region ??
        (await LiturgicalRegionPreferenceService.getInstance()).currentRegion;
    final day = OfflineOrdoLookupService.instance.resolve(
      payload.celebrationDate,
      region: selectedRegion,
    );
    if (!SaintProfileService.isSaintLikeTitle(day.title)) return null;

    final profile = await SaintProfileService.instance.findCuratedByTitle(
      day.title,
    );
    if (profile == null) return null;

    return OptionalCelebration(
      id: profile.id,
      title: day.title,
      rank: _rank(day.rank),
      color: day.color,
      month: payload.celebrationDate.month,
      day: payload.celebrationDate.day,
      commonType: null,
    );
  }

  CelebrationRank _rank(String? value) => switch (value) {
    'Solemnity' => CelebrationRank.solemnity,
    'Feast' => CelebrationRank.feast,
    'Memorial' => CelebrationRank.obligatoryMemorial,
    _ => CelebrationRank.optionalMemorial,
  };
}
