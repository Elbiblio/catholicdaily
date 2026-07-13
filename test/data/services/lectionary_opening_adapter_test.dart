import 'package:catholic_daily/data/services/lectionary_opening_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LectionaryOpeningAdapter', () {
    test('patches a liturgical opening before a strong early anchor', () {
      final result = LectionaryOpeningAdapter().adapt(
        sourceOpening:
            'At that time Jesus said to his disciples, '
            'Love one another as I have loved you. '
            'No one has greater love than this, to lay down one\'s life.',
        renderedText:
            '12 Love one another as I have loved you. '
            'No one has greater love than this, to lay down one\'s life. '
            'You are my friends if you do what I command you.',
      );

      expect(result.applied, isTrue);
      expect(result.reason, 'adapted');
      expect(
        result.text,
        startsWith('At that time Jesus said to his disciples, '),
      );
      expect(result.text, isNot(startsWith('12 ')));
      expect(result.text, contains('You are my friends'));
    });

    test('refuses to adapt when there is no strong word-sequence anchor', () {
      final result = LectionaryOpeningAdapter().adapt(
        sourceOpening:
            'At that time Jesus said, I thank you, Father, Lord of heaven '
            'and earth, because you have revealed these things to infants.',
        renderedText:
            '25 At that time Jesus declared, "I thank thee, Father, Lord of '
            'heaven and earth, that thou hast hidden these things."',
      );

      expect(result.applied, isFalse);
      expect(result.reason, 'no-strong-anchor');
      expect(result.text, startsWith('25 At that time'));
    });

    test('patches when a strong word sequence is shorter than 50 characters', () {
      final result = LectionaryOpeningAdapter().adapt(
        sourceOpening:
            'At that time Jesus said to his disciples, '
            'I am vine you are branches my father loves me.',
        renderedText:
            '5 I am vine you are branches my father loves me. '
            'By this my Father is glorified, that you bear much fruit.',
      );

      expect(result.applied, isTrue);
      expect(result.reason, 'adapted');
      expect(result.anchorTokens, greaterThanOrEqualTo(10));
      expect(result.text, startsWith('At that time Jesus said to his disciples'));
    });

    test('refuses to adapt when the anchor is outside the early window', () {
      final result = LectionaryOpeningAdapter().adapt(
        sourceOpening:
            'In those days, Paul stood up and said to the people, '
            'The God of this people Israel chose our ancestors and made '
            'the people great during their stay in Egypt.',
        renderedText:
            '${'preface text. ' * 40}'
            'The God of this people Israel chose our ancestors and made '
            'the people great during their stay in Egypt.',
      );

      expect(result.applied, isFalse);
      expect(result.reason, 'no-early-anchor');
    });

    test('refuses to adapt when the strongest anchor is ambiguous', () {
      final repeated =
          'Blessed are the poor in spirit for theirs is the kingdom of heaven';
      final result = LectionaryOpeningAdapter().adapt(
        sourceOpening: 'At that time Jesus said to his disciples, $repeated.',
        renderedText: '$repeated. $repeated.',
      );

      expect(result.applied, isFalse);
      expect(result.reason, 'ambiguous-anchor');
    });
  });
}
