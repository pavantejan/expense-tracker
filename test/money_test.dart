import 'package:expense_tracker/core/domain/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money construction and arithmetic', () {
    test('equality includes currency and hash code agrees', () {
      expect(Money(125075, 'INR'), Money(125075, 'INR'));
      expect(Money(125075, 'INR'), isNot(Money(125075, 'USD')));
      expect(Money(125075, 'INR').hashCode, Money(125075, 'INR').hashCode);
    });

    test('zero, sign, and absolute value', () {
      final zero = Money.zero('INR');
      expect(zero.isZero, isTrue);
      expect(zero.isPositive, isFalse);
      expect(Money(1, 'INR').isPositive, isTrue);
      expect(Money(-1, 'INR').isNegative, isTrue);
      expect(Money(-125075, 'INR').abs(), Money(125075, 'INR'));
    });

    test('addition, subtraction, and negation require one currency', () {
      final a = Money(10000, 'INR');
      final b = Money(250, 'INR');
      expect(a + b, Money(10250, 'INR'));
      expect(a - b, Money(9750, 'INR'));
      expect(-a, Money(-10000, 'INR'));
      expect(() => a + Money(1, 'USD'), throwsA(isA<ArgumentError>()));
      expect(() => a - Money(1, 'USD'), throwsA(isA<ArgumentError>()));
    });

    test('comparison uses minor units only', () {
      expect(Money(99, 'INR') < Money(100, 'INR'), isTrue);
      expect(Money(100, 'INR') <= Money(100, 'INR'), isTrue);
      expect(Money(101, 'INR') > Money(100, 'INR'), isTrue);
      expect(Money(100, 'INR') >= Money(100, 'INR'), isTrue);
      expect(Money(100, 'INR').compareTo(Money(200, 'INR')), lessThan(0));
      expect(
        () => Money(1, 'INR').compareTo(Money(1, 'USD')),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Money formatting', () {
    test('formats with Indian grouping and two decimals', () {
      expect(Money(0, 'INR').format(), '₹0.00');
      expect(Money(1, 'INR').format(), '₹0.01');
      expect(Money(99, 'INR').format(), '₹0.99');
      expect(Money(100, 'INR').format(), '₹1.00');
      expect(Money(125075, 'INR').format(), '₹1,250.75');
      expect(Money(10000000, 'INR').format(), '₹1,00,000.00');
      expect(Money(123456789, 'INR').format(), '₹12,34,567.89');
      expect(Money(100000, 'INR').format(), '₹1,000.00');
      expect(Money(-125075, 'INR').format(), '-₹1,250.75');
      expect(
        Money(7036874417766399, 'INR').format(),
        '₹7,03,68,74,41,77,663.99',
      );
    });

    test('formats zero-decimal currencies without a fraction', () {
      expect(Money(1250, 'JPY').format(), '¥1,250');
      expect(Money(-1250, 'JPY').format(), '-¥1,250');
    });

    test('toDecimalString has no grouping or symbol', () {
      expect(Money(125075, 'INR').toDecimalString(), '1250.75');
      expect(Money(-125075, 'INR').toDecimalString(), '-1250.75');
      expect(Money(100, 'INR').toDecimalString(), '1.00');
      expect(Money(1250, 'JPY').toDecimalString(), '1250');
    });

    test('toString returns the display format', () {
      expect(Money(125075, 'INR').toString(), '₹1,250.75');
    });
  });

  group('Money.parse is strict', () {
    test('parses plain, signed, and zero-fraction values', () {
      expect(Money.parse('1250.75'), Money(125075, 'INR'));
      expect(Money.parse('+1250.75'), Money(125075, 'INR'));
      expect(Money.parse('-1250.75'), Money(-125075, 'INR'));
      expect(Money.parse('0'), Money(0, 'INR'));
      expect(Money.parse('0.01'), Money(1, 'INR'));
      expect(Money.parse('.75'), Money(75, 'INR'));
      expect(Money.parse('  1250.75  '), Money(125075, 'INR'));
      expect(Money.parse('-0.00'), Money(0, 'INR'));
      expect(Money.parse('1250', currencyCode: 'JPY'), Money(1250, 'JPY'));
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
      expect(Money.parseNormalised('1250.755'), Money(125076, 'INR'));
      expect(Money.parseNormalised('1250.754'), Money(125075, 'INR'));
      expect(Money.parseNormalised('1250.745'), Money(125075, 'INR'));
      expect(Money.parseNormalised('1250.744'), Money(125074, 'INR'));
      expect(Money.parseNormalised('-1250.755'), Money(-125076, 'INR'));
      expect(Money.parseNormalised('-1250.754'), Money(-125075, 'INR'));
      expect(
        Money.parseNormalised('1250.5', currencyCode: 'JPY'),
        Money(1251, 'JPY'),
      );
      expect(
        Money.parseNormalised('1250.4', currencyCode: 'JPY'),
        Money(1250, 'JPY'),
      );
      expect(Money.tryParseNormalised('1250.755'), Money(125076, 'INR'));
      expect(Money.tryParseNormalised('abc'), isNull);
    });

    test('normalisation still rejects malformed input', () {
      expect(() => Money.parseNormalised('1,250.755'), throwsFormatException);
      expect(() => Money.parseNormalised(''), throwsFormatException);
    });
  });

  group('currency registry', () {
    test('registry covers exactly the supported codes', () {
      expect(supportedCurrencyCodes, <String>{
        'INR',
        'USD',
        'EUR',
        'GBP',
        'JPY',
        'KRW',
      });
      expect(isSupportedCurrencyCode('INR'), isTrue);
      expect(isSupportedCurrencyCode('JPY'), isTrue);
      expect(isSupportedCurrencyCode('XXX'), isFalse);
      expect(isSupportedCurrencyCode('AUD'), isFalse);
      expect(isSupportedCurrencyCode(''), isFalse);
      expect(isSupportedCurrencyCode('inr'), isFalse);
    });

    test('minor-unit digits and symbols come from the registry', () {
      expect(minorUnitDigitsForCurrency('INR'), 2);
      expect(minorUnitDigitsForCurrency('USD'), 2);
      expect(minorUnitDigitsForCurrency('EUR'), 2);
      expect(minorUnitDigitsForCurrency('GBP'), 2);
      expect(minorUnitDigitsForCurrency('JPY'), 0);
      expect(minorUnitDigitsForCurrency('KRW'), 0);
      expect(currencySymbolFor('INR'), '₹');
      expect(currencySymbolFor('USD'), r'$');
      expect(currencySymbolFor('EUR'), '€');
      expect(currencySymbolFor('GBP'), '£');
      expect(currencySymbolFor('JPY'), '¥');
      expect(currencySymbolFor('KRW'), '₩');
    });

    test('unsupported codes are rejected, never defaulted', () {
      for (final code in ['XXX', 'AUD', 'CAD', '', 'inr', 'Inr']) {
        expect(
          () => minorUnitDigitsForCurrency(code),
          throwsA(isA<ArgumentError>()),
          reason: 'code: $code',
        );
        expect(
          () => currencySymbolFor(code),
          throwsA(isA<ArgumentError>()),
          reason: 'code: $code',
        );
        expect(
          () => Money(1, code),
          throwsA(isA<ArgumentError>()),
          reason: 'code: $code',
        );
        expect(
          () => Money.zero(code),
          throwsA(isA<ArgumentError>()),
          reason: 'code: $code',
        );
        expect(
          () => Money.parse('1.00', currencyCode: code),
          throwsA(isA<ArgumentError>()),
          reason: 'code: $code',
        );
        expect(
          () => Money.tryParse('1.00', currencyCode: code),
          throwsA(isA<ArgumentError>()),
          reason: 'code: $code',
        );
      }
    });
  });

  group('Money arithmetic overflow protection', () {
    const maxMinorUnits = 9223372036854775807;
    const minMinorUnits = -9223372036854775808;

    test('throws on overflow past the maximum', () {
      final max = Money(maxMinorUnits, 'INR');
      expect(() => max + Money(1, 'INR'), throwsStateError);
      expect(() => Money(1, 'INR') + max, throwsStateError);
      expect(() => max - Money(-1, 'INR'), throwsStateError);
      expect(() => max + Money(maxMinorUnits, 'INR'), throwsStateError);
    });

    test('throws on overflow past the minimum', () {
      final min = Money(minMinorUnits, 'INR');
      expect(() => min - Money(1, 'INR'), throwsStateError);
      expect(() => min + Money(-1, 'INR'), throwsStateError);
      expect(() => min - Money(maxMinorUnits, 'INR'), throwsStateError);
    });

    test('throws when negating or taking the absolute value of minimum', () {
      final min = Money(minMinorUnits, 'INR');
      expect(() => -min, throwsStateError);
      expect(() => min.abs(), throwsStateError);
    });

    test('boundary values that remain valid', () {
      final max = Money(maxMinorUnits, 'INR');
      final min = Money(minMinorUnits, 'INR');
      expect(max + Money(0, 'INR'), max);
      expect(min + Money(0, 'INR'), min);
      expect(max - Money(1, 'INR'), Money(maxMinorUnits - 1, 'INR'));
      expect(min + Money(1, 'INR'), Money(minMinorUnits + 1, 'INR'));
      expect(-max, Money(minMinorUnits + 1, 'INR'));
      expect(max.abs(), max);
      expect(
        Money(minMinorUnits + 1, 'INR').abs(),
        Money(maxMinorUnits, 'INR'),
      );
      expect(Money(-100, 'INR').abs(), Money(100, 'INR'));
    });

    test('normal positive and negative arithmetic is unchanged', () {
      expect(Money(100, 'INR') + Money(250, 'INR'), Money(350, 'INR'));
      expect(Money(100, 'INR') - Money(250, 'INR'), Money(-150, 'INR'));
      expect(Money(-100, 'INR') + Money(-250, 'INR'), Money(-350, 'INR'));
      expect(-Money(100, 'INR'), Money(-100, 'INR'));
      expect(-Money(-100, 'INR'), Money(100, 'INR'));
      expect(Money(0, 'INR').abs(), Money(0, 'INR'));
    });

    test('boundary values parse and format exactly', () {
      expect(Money.parse('92233720368547758.07'), Money(maxMinorUnits, 'INR'));
      expect(Money.parse('-92233720368547758.08'), Money(minMinorUnits, 'INR'));
      expect(() => Money.parse('92233720368547758.08'), throwsFormatException);
      expect(() => Money.parse('-92233720368547758.09'), throwsFormatException);
      expect(
        Money(maxMinorUnits, 'INR').toDecimalString(),
        '92233720368547758.07',
      );
      expect(
        Money(minMinorUnits, 'INR').toDecimalString(),
        '-92233720368547758.08',
      );
      expect(
        Money(maxMinorUnits, 'INR').format(),
        '₹92,23,37,20,36,85,47,758.07',
      );
    });
  });
}
