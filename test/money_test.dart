import 'package:expense_tracker/core/domain/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money construction and arithmetic', () {
    test('equality includes currency and hash code agrees', () {
      expect(const Money(125075, 'INR'), const Money(125075, 'INR'));
      expect(const Money(125075, 'INR'), isNot(const Money(125075, 'USD')));
      expect(
        const Money(125075, 'INR').hashCode,
        const Money(125075, 'INR').hashCode,
      );
    });

    test('zero, sign, and absolute value', () {
      const zero = Money.zero('INR');
      expect(zero.isZero, isTrue);
      expect(zero.isPositive, isFalse);
      expect(const Money(1, 'INR').isPositive, isTrue);
      expect(const Money(-1, 'INR').isNegative, isTrue);
      expect(const Money(-125075, 'INR').abs(), const Money(125075, 'INR'));
    });

    test('addition, subtraction, and negation require one currency', () {
      const a = Money(10000, 'INR');
      const b = Money(250, 'INR');
      expect(a + b, const Money(10250, 'INR'));
      expect(a - b, const Money(9750, 'INR'));
      expect(-a, const Money(-10000, 'INR'));
      expect(() => a + const Money(1, 'USD'), throwsA(isA<ArgumentError>()));
      expect(() => a - const Money(1, 'USD'), throwsA(isA<ArgumentError>()));
    });

    test('comparison uses minor units only', () {
      expect(const Money(99, 'INR') < const Money(100, 'INR'), isTrue);
      expect(const Money(100, 'INR') <= const Money(100, 'INR'), isTrue);
      expect(const Money(101, 'INR') > const Money(100, 'INR'), isTrue);
      expect(const Money(100, 'INR') >= const Money(100, 'INR'), isTrue);
      expect(
        const Money(100, 'INR').compareTo(const Money(200, 'INR')),
        lessThan(0),
      );
      expect(
        () => const Money(1, 'INR').compareTo(const Money(1, 'USD')),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Money formatting', () {
    test('formats with Indian grouping and two decimals', () {
      expect(const Money(0, 'INR').format(), '₹0.00');
      expect(const Money(1, 'INR').format(), '₹0.01');
      expect(const Money(99, 'INR').format(), '₹0.99');
      expect(const Money(100, 'INR').format(), '₹1.00');
      expect(const Money(125075, 'INR').format(), '₹1,250.75');
      expect(const Money(10000000, 'INR').format(), '₹1,00,000.00');
      expect(const Money(123456789, 'INR').format(), '₹12,34,567.89');
      expect(const Money(100000, 'INR').format(), '₹1,000.00');
      expect(const Money(-125075, 'INR').format(), '-₹1,250.75');
      expect(
        const Money(7036874417766399, 'INR').format(),
        '₹7,03,68,74,41,77,663.99',
      );
    });

    test('formats zero-decimal currencies without a fraction', () {
      expect(const Money(1250, 'JPY').format(), '¥1,250');
      expect(const Money(-1250, 'JPY').format(), '-¥1,250');
    });

    test('toDecimalString has no grouping or symbol', () {
      expect(const Money(125075, 'INR').toDecimalString(), '1250.75');
      expect(const Money(-125075, 'INR').toDecimalString(), '-1250.75');
      expect(const Money(100, 'INR').toDecimalString(), '1.00');
      expect(const Money(1250, 'JPY').toDecimalString(), '1250');
    });

    test('toString returns the display format', () {
      expect(const Money(125075, 'INR').toString(), '₹1,250.75');
    });
  });

  group('Money.parse is strict', () {
    test('parses plain, signed, and zero-fraction values', () {
      expect(Money.parse('1250.75'), const Money(125075, 'INR'));
      expect(Money.parse('+1250.75'), const Money(125075, 'INR'));
      expect(Money.parse('-1250.75'), const Money(-125075, 'INR'));
      expect(Money.parse('0'), const Money(0, 'INR'));
      expect(Money.parse('0.01'), const Money(1, 'INR'));
      expect(Money.parse('.75'), const Money(75, 'INR'));
      expect(Money.parse('  1250.75  '), const Money(125075, 'INR'));
      expect(Money.parse('-0.00'), const Money(0, 'INR'));
      expect(
        Money.parse('1250', currencyCode: 'JPY'),
        const Money(1250, 'JPY'),
      );
    });

    test('rejects over-precise values instead of rounding', () {
      expect(() => Money.parse('1250.755'), throwsFormatException);
      expect(() => Money.parse('1250.751'), throwsFormatException);
      expect(() => Money.parse('1.001'), throwsFormatException);
      expect(Money.tryParse('1250.755'), isNull);
    });

    test('rejects malformed input', () {
      const invalid = [
        '',
        ' ',
        'abc',
        '1,250.75',
        '1250.',
        '.',
        '12e3',
        '₹1250',
        r'$1250',
        '12.34.56',
        '--5',
        '++5',
        '+-5',
        '1_000',
        '12 50',
        '1 250.75',
        'NaN',
        'Infinity',
      ];
      for (final value in invalid) {
        expect(
          () => Money.parse(value),
          throwsFormatException,
          reason: 'input: $value',
        );
        expect(Money.tryParse(value), isNull, reason: 'input: $value');
      }
    });

    test('rejects values that overflow 64-bit minor units', () {
      expect(
        () => Money.parse('99999999999999999999999999.99'),
        throwsFormatException,
      );
    });
  });

  group('Money.parseNormalised rounds half away from zero', () {
    test('rounds at the minor-unit boundary only', () {
      expect(Money.parseNormalised('1250.755'), const Money(125076, 'INR'));
      expect(Money.parseNormalised('1250.754'), const Money(125075, 'INR'));
      expect(Money.parseNormalised('1250.745'), const Money(125075, 'INR'));
      expect(Money.parseNormalised('1250.744'), const Money(125074, 'INR'));
      expect(Money.parseNormalised('-1250.755'), const Money(-125076, 'INR'));
      expect(Money.parseNormalised('-1250.754'), const Money(-125075, 'INR'));
      expect(
        Money.parseNormalised('1250.5', currencyCode: 'JPY'),
        const Money(1251, 'JPY'),
      );
      expect(
        Money.parseNormalised('1250.4', currencyCode: 'JPY'),
        const Money(1250, 'JPY'),
      );
      expect(Money.tryParseNormalised('1250.755'), const Money(125076, 'INR'));
      expect(Money.tryParseNormalised('abc'), isNull);
    });

    test('normalisation still rejects malformed input', () {
      expect(() => Money.parseNormalised('1,250.755'), throwsFormatException);
      expect(() => Money.parseNormalised(''), throwsFormatException);
    });
  });

  group('currency helpers', () {
    test('minor-unit digits and symbols', () {
      expect(minorUnitDigitsForCurrency('INR'), 2);
      expect(minorUnitDigitsForCurrency('JPY'), 0);
      expect(minorUnitDigitsForCurrency('XXX'), 2);
      expect(currencySymbolFor('INR'), '₹');
      expect(currencySymbolFor('USD'), r'$');
      expect(currencySymbolFor('XXX'), 'XXX');
    });
  });
}
