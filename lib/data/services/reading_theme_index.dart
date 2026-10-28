import '../models/daily_reading.dart';
import '../models/hymn.dart';

/// A deliberately small, reviewable seed index, keyed by complete passages.
/// Themes are interpretive labels, not a claim of complete lectionary coverage.
/// Unlisted or partial passages produce no indexed themes.
/// Passage wording and context can be reviewed against the USCCB text:
/// https://bible.usccb.org/bible/matthew/4
/// https://bible.usccb.org/bible/matthew/19
/// https://bible.usccb.org/bible/john/1
/// https://bible.usccb.org/bible/john/6
/// https://bible.usccb.org/bible/john/10
/// https://bible.usccb.org/bible/john/20
/// https://bible.usccb.org/bible/luke/10
/// https://bible.usccb.org/bible/luke/24
class ReadingThemeIndex {
  static const Map<String, Map<String, double>> _passages = {
    // Advent: readiness for the Lord and John the Baptist's call to repent.
    'matt:24:37-44': {'watchfulness': 1},
    'mark:13:33-37': {'watchfulness': 1},
    'luke:21:25-28,34-36': {'watchfulness': 1},
    'matt:3:1-12': {'repentance': 1},
    'mark:1:1-8': {'repentance': 1},
    'luke:3:1-6': {'repentance': 1},
    'luke:3:10-18': {'repentance': 1, 'neighbor_love': 0.5},
    // The annunciation, birth, manifestation and baptism of Jesus.
    'matt:1:18-24': {'incarnation': 1},
    'luke:1:26-38': {'incarnation': 1},
    'luke:2:1-14': {'incarnation': 1},
    'luke:2:15-20': {'incarnation': 1},
    'matt:2:1-12': {'epiphany': 1, 'incarnation': 0.6},
    'matt:3:13-17': {'baptism': 1},
    'mark:1:7-11': {'baptism': 1},
    'luke:3:15-16,21-22': {'baptism': 1},
    // Lent: temptation, the transfiguration and the father's welcome.
    'mark:1:12-15': {'temptation': 1, 'repentance': 0.7},
    'luke:4:1-13': {'temptation': 1, 'trust': 0.7},
    'matt:17:1-9': {'transfiguration': 1},
    'mark:9:2-10': {'transfiguration': 1},
    'luke:9:28b-36': {'transfiguration': 1},
    'luke:15:1-3,11-32': {'reconciliation': 1, 'mercy': 0.7},
    // Easter: resurrection, the shepherd, and life in Christ's love.
    'matt:28:1-10': {'resurrection': 1},
    'mark:16:1-7': {'resurrection': 1},
    'john:20:19-31': {'resurrection': 1, 'faith': 0.7},
    'luke:24:35-48': {'resurrection': 1},
    'john:10:1-10': {'shepherd': 1},
    'john:10:27-30': {'shepherd': 1},
    'john:15:1-8': {'abiding_in_christ': 1},
    'john:15:9-17': {'neighbor_love': 1, 'self_giving': 0.6},
    // Ordinary Time: teaching and parables of Christian discipleship.
    'matt:5:1-12a': {'beatitudes': 1},
    'luke:6:17,20-26': {'beatitudes': 1},
    'matt:5:13-16': {'witness': 1},
    'luke:5:1-11': {'discipleship': 1},
    'matt:5:38-48': {'neighbor_love': 1, 'mercy': 0.5},
    'luke:6:27-38': {'neighbor_love': 1, 'mercy': 0.6},
    'matt:6:24-34': {'trust': 1, 'detachment': 0.5},
    'mark:4:35-41': {'trust': 1, 'faith': 0.5},
    'luke:10:1-12,17-20': {'mission': 1},
    'john:6:24-35': {'eucharist': 1},
    'matt:18:21-35': {'forgiveness': 1, 'mercy': 0.5},
    'matt:22:34-40': {'neighbor_love': 1},
    'mark:12:28b-34': {'neighbor_love': 1},
    'matt:25:1-13': {'watchfulness': 1},
    'matt:25:31-46': {'neighbor_love': 1, 'service': 0.7},
    'luke:15:1-10': {'mercy': 1, 'repentance': 0.5},
    'luke:17:11-19': {'thanksgiving': 1, 'faith': 0.5},
    'luke:18:1-8': {'prayer': 1},
    'luke:18:9-14': {'humility': 1, 'prayer': 0.5},
    'mark:10:35-45': {'service': 1, 'self_giving': 0.6},
    'matt:11:25-30': {'trust': 1},
    'mark:8:27-35': {'discipleship': 1, 'self_giving': 0.6},
    // Matthew 4:1–11: Jesus resists temptation in the wilderness.
    'matt:4:1-11': {'temptation': 1, 'trust': 0.7},
    // Matthew 19:16–22: following Jesus and leaving possessions for the poor.
    'matt:19:16-22': {'discipleship': 1, 'detachment': 1},
    // John 20:1–9: the empty tomb, resurrection and belief.
    'john:20:1-9': {'resurrection': 1, 'faith': 0.5},
    // John 1:1–18: the Word became flesh.
    'john:1:1-18': {'incarnation': 1, 'word': 0.5},
    // John 10:11–18: the good shepherd lays down his life for his sheep.
    'john:10:11-18': {'shepherd': 1, 'self_giving': 0.7},
    // John 6:51–58: the living bread, flesh and blood.
    'john:6:51-58': {'eucharist': 1, 'eternal_life': 0.5},
    // Luke 10:25–37: love of neighbour shown through merciful care.
    'luke:10:25-37': {'neighbor_love': 1, 'mercy': 0.7},
    // Luke 24:13–35: recognition of the risen Lord in breaking bread.
    'luke:24:13-35': {'resurrection': 1, 'breaking_bread': 0.8},
  };

  // Hand-selected hymn associations supplement phrase matches. They record
  // themes of the whole hymn, not every word that happens to occur in it.
  static const Map<String, Set<String>> _hymnThemes = {
    'wake_awake': {'watchfulness'},
    'when_he_comes_back': {'watchfulness'},
    'what_star_is_this': {'epiphany', 'incarnation'},
    'come_ye_sinners': {'repentance', 'mercy'},
    'god_of_mercy': {'repentance', 'mercy', 'reconciliation'},
    'grant_to_us': {'repentance', 'reconciliation'},
    'hear_o_thou': {'repentance'},
    'lord_who_throughout': {'temptation', 'repentance', 'trust'},
    'sole_hope': {'repentance'},
    'christians_let_us_love': {'neighbor_love'},
    'loving_shepherd': {'shepherd'},
    'see_the_loving_shepherd': {'shepherd'},
    'my_shepherd_is_the_lord': {'shepherd'},
    'the_lords_my_shepherd': {'shepherd'},
  };

  // Phrase patterns are deliberately specific. A generic word such as "life"
  // does not establish that a hymn is about the resurrection.
  static final Map<String, RegExp> _hymnEvidence = {
    'beatitudes': RegExp(
      r'\b(beatitudes|blessed are (the|those|they)|poor in spirit)\b',
    ),
    'witness': RegExp(
      r'\b(light of the world|salt of the earth|let (your|our) light shine)\b',
    ),
    'mission': RegExp(
      r'\b(go (and|forth|into all the world)|send (us|me) (forth|out)|proclaim (the |your )?(gospel|good news))\b',
    ),
    'forgiveness': RegExp(
      r'\b(forgive|forgiven|forgiveness|pardon (me|us|our sins))\b',
    ),
    'thanksgiving': RegExp(
      r'\b(thanksgiving|give thanks|thank (you|thee|the lord|god))\b',
    ),
    'prayer': RegExp(r'\b(pray|prayer|praying)\b'),
    'humility': RegExp(r'\b(humble|humility|lowly of heart)\b'),
    'service': RegExp(
      r'\b(servant of all|serve (one another|the lord|our neighbor)|serving (others|one another))\b',
    ),
    'watchfulness': RegExp(
      r'\b(watch and pray|keep (your|our) watch|watchful|stay awake|be ready|lord.{0,12}coming again)\b',
    ),
    'repentance': RegExp(
      r'\b(repent|repentance|repenting|turn (back )?to (the )?lord|turn from sin)\b',
    ),
    'epiphany': RegExp(
      r'\b(epiphany|magi|wise men|star of bethlehem|three kings)\b',
    ),
    'baptism': RegExp(r'\b(baptis(m|ed|mal)|baptiz(e|ed)|waters of baptism)\b'),
    'transfiguration': RegExp(
      r'\b(transfiguration|transfigured|mount tabor)\b',
    ),
    'reconciliation': RegExp(
      r'\b(reconcil(e|ed|iation)|prodigal|return to (the |our )?father|father.{0,20}welcome.{0,20}home)\b',
    ),
    'abiding_in_christ': RegExp(
      r'\b(abide in (me|thee|you|christ)|vine and (the )?branches|true vine)\b',
    ),
    'temptation': RegExp(r'\b(temptation|tempted|tempter|forty days)\b'),
    'trust': RegExp(r'\b(trust|trusting|trusted)\b'),
    'discipleship': RegExp(
      r'\b(follow (me|thee|you|him|jesus|christ)|disciples?|take up (the|your|my) cross)\b',
    ),
    'detachment': RegExp(
      r'\b(surrender all|treasures? in heaven|give (to|all to) the poor|leave (all|everything))\b',
    ),
    'resurrection': RegExp(
      r'\b(risen|resurrection|rose from the dead|risen from the dead)\b',
    ),
    'faith': RegExp(r'\b(faith|believe|believing)\b'),
    'incarnation': RegExp(
      r'\b(word (was |is )?made flesh|god (became|made) man|born (in|at) bethlehem|incarnation)\b',
    ),
    'word': RegExp(r'\b(word of god|word made flesh|word of the lord)\b'),
    'shepherd': RegExp(r'\b(shepherd|sheep|flock)\b'),
    'self_giving': RegExp(
      r'\b(lay(s|ing)? down (his|my|your) life|gave (his|my) life)\b',
    ),
    'eucharist': RegExp(
      r'\b(eucharist|bread of (life|heaven)|body and blood|living bread)\b',
    ),
    'eternal_life': RegExp(r'\b(eternal life|everlasting life|life eternal)\b'),
    'neighbor_love': RegExp(
      r'\b(love (your|thy|our) neighbou?r|good samaritan|love one another)\b',
    ),
    'mercy': RegExp(r'\b(mercy|merciful|compassion)\b'),
    'breaking_bread': RegExp(
      r'\b(break(ing)? (the )?bread|bread (we )?break)\b',
    ),
  };

  static const Map<String, String> _books = {
    'matthew': 'matt',
    'matt': 'matt',
    'mt': 'matt',
    'mark': 'mark',
    'mk': 'mark',
    'john': 'john',
    'jn': 'john',
    'jo': 'john',
    'luke': 'luke',
    'lk': 'luke',
    'luch': 'luke',
  };

  Map<String, double> themesFor(String reference) {
    final normalized = reference
        .toLowerCase()
        .replaceAll(RegExp('[–—−]'), '-')
        .trim();
    final match = RegExp(
      r'^([a-z]+)\.?\s+(\d+)\s*:\s*(\d+[a-z]?(?:\s*-\s*\d+[a-z]?)?(?:\s*,\s*\d+[a-z]?(?:\s*-\s*\d+[a-z]?)?)*)$',
    ).firstMatch(normalized);
    if (match == null) return const {};
    final book = _books[match.group(1)];
    if (book == null) return const {};
    final verses = match.group(3)!.replaceAll(RegExp(r'\s+'), '');
    return _passages['$book:${match.group(2)}:$verses'] ?? const {};
  }

  /// Prefer a primary reading over alternatives of the same position, while
  /// preserving an alternative when it is the only selected reading.
  List<DailyReading> selectedReadings(List<DailyReading> readings) {
    final selected = <DailyReading>[];
    final seen = <String>{};
    String basePosition(String position) =>
        position.replaceAll(RegExp(r'\s*\(alternative[^)]*\)'), '').trim();
    final primaryPositions = readings
        .map((reading) => (reading.position ?? '').toLowerCase())
        .where((position) => !position.contains('alternative'))
        .map(basePosition)
        .toSet();
    for (final reading in readings) {
      final position = (reading.position ?? '').toLowerCase();
      if ((position.contains('alternative') &&
              primaryPositions.contains(basePosition(position))) ||
          !seen.add(reading.reading))
        continue;
      selected.add(reading);
    }
    return selected;
  }

  bool hasIndexedGospel(List<DailyReading> readings) =>
      selectedReadings(readings).any((reading) {
        final position = (reading.position ?? '').toLowerCase();
        return position.contains('gospel') &&
            !position.contains('acclamation') &&
            themesFor(reading.reading).isNotEmpty;
      });

  Map<String, double> themesForReadings(List<DailyReading> readings) {
    final result = <String, double>{};
    for (final reading in selectedReadings(readings)) {
      final position = (reading.position ?? '').toLowerCase();
      final weight =
          position.contains('gospel') && !position.contains('acclamation')
          ? 3.0
          : 1.0;
      for (final entry in themesFor(reading.reading).entries) {
        result[entry.key] = (result[entry.key] ?? 0) + entry.value * weight;
      }
    }
    return result;
  }

  /// Fraction of weighted indexed themes with specific evidence in the hymn.
  double hymnScore(Hymn hymn, Map<String, double> themes) {
    if (themes.isEmpty) return 0;
    final text =
        '${hymn.title} ${hymn.firstLine ?? ''} ${hymn.displayLyrics.join(' ')} ${hymn.themes ?? ''}'
            .toLowerCase()
            .replaceAll('’', "'");
    var total = 0.0;
    var matched = 0.0;
    for (final entry in themes.entries) {
      final pattern = _hymnEvidence[entry.key];
      if (pattern == null) continue;
      total += entry.value;
      if ((_hymnThemes[hymn.slug]?.contains(entry.key) ?? false) ||
          pattern.hasMatch(text)) {
        matched += entry.value;
      }
    }
    return total == 0 ? 0 : matched / total;
  }
}
