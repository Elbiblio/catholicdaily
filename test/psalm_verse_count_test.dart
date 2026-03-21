import 'package:flutter_test/flutter_test.dart';
import '../lib/data/services/lectionary_psalm_formatter.dart';

void main() {
  group('Psalm Verse Count Tests', () {
    test('Ps 89:2-3, 4-5, 27, 29 should format as 4 verses', () {
      final verses = {
        2: '2 The favors of the LORD I will sing forever; through all generations my mouth shall proclaim your faithfulness.',
        3: '3 For you have said: "My kindness is established forever"; in heaven you have confirmed your faithfulness.',
        4: '4 "I have made a covenant with my chosen one, I have sworn to David my servant,',
        5: '5 Your offspring I will make endure forever, and your throne, like the heavens, shall endure through all generations."',
        27: '27 He shall cry to me: \'You are my father, my God, the rock of my salvation!\'',
        29: '29 I will keep his love forever; my covenant with him shall never be broken.',
      };
      
      final result = LectionaryPsalmFormatter.format(
        reference: 'Ps 89:2-3, 4-5, 27, 29',
        verses: verses,
        refrain: 'Lord, hear our prayer.',
      );
      
      final lines = result.split('\n');
      final verseLines = lines.where((line) => RegExp(r'^\d+\s').hasMatch(line)).toList();
      
      expect(verseLines.length, 4, reason: 'Should have exactly 4 numbered verses');
      expect(verseLines[0], startsWith('1 '));
      expect(verseLines[1], startsWith('2 '));
      expect(verseLines[2], startsWith('3 '));
      expect(verseLines[3], startsWith('4 '));
    });
  });
}
