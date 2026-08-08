import 'package:flutter_test/flutter_test.dart';
import 'package:cold_call_assistant/core/utils/phone_normalizer.dart';

void main() {
  group('PhoneNormalizer', () {
    // ── Already-valid E.164 ──────────────────────────────────────────────────

    test('already E.164 French number passes through unchanged', () {
      final result = PhoneNormalizer.normalize('+33177455329');
      expect(result.isValid, isTrue);
      expect(result.normalizedNumber, '+33177455329');
      expect(result.country, 'FR');
    });

    test('already E.164 Bulgarian number passes through unchanged', () {
      final result = PhoneNormalizer.normalize('+359898123456');
      expect(result.isValid, isTrue);
      expect(result.normalizedNumber, '+359898123456');
      expect(result.country, 'BG');
    });

    // ── Missing '+' prefix ───────────────────────────────────────────────────

    test('international French number missing + prefix is normalized', () {
      final result = PhoneNormalizer.normalize('33177455329');
      expect(result.isValid, isTrue);
      expect(result.normalizedNumber, '+33177455329');
      expect(result.country, 'FR');
    });

    test('international Bulgarian number missing + prefix is normalized', () {
      final result = PhoneNormalizer.normalize('359898123456');
      expect(result.isValid, isTrue);
      expect(result.normalizedNumber, '+359898123456');
      expect(result.country, 'BG');
    });

    // ── Bulgarian leading zero missing ───────────────────────────────────────

    test('Bulgarian number missing leading zero (9-digit starting with 8) is fixed', () {
      // COMPANY-SPECIFIC rule: 898123456 → 0898123456 → +359898123456
      final result = PhoneNormalizer.normalize('898123456');
      expect(result.isValid, isTrue);
      expect(result.normalizedNumber, '+359898123456');
      expect(result.country, 'BG');
    });

    test('Bulgarian number missing leading zero (9-digit starting with 9) is fixed', () {
      // COMPANY-SPECIFIC rule: 988123456 → 0988123456 → +359988123456
      final result = PhoneNormalizer.normalize('988123456');
      expect(result.isValid, isTrue);
      expect(result.normalizedNumber, '+359988123456');
      expect(result.country, 'BG');
    });

    // ── Apostrophe prefix (COMPANY-SPECIFIC) ─────────────────────────────────

    test("apostrophe-prefixed Bulgarian national number is normalized", () {
      // COMPANY-SPECIFIC: '0898123456 → 0898123456 → +359898123456
      final result = PhoneNormalizer.normalize("'0898123456");
      expect(result.isValid, isTrue);
      expect(result.normalizedNumber, '+359898123456');
      expect(result.country, 'BG');
    });

    test("apostrophe-prefixed Bulgarian number missing leading zero is normalized", () {
      // COMPANY-SPECIFIC: '898123456 → 898123456 → 0898123456 → +359898123456
      final result = PhoneNormalizer.normalize("'898123456");
      expect(result.isValid, isTrue);
      expect(result.normalizedNumber, '+359898123456');
      expect(result.country, 'BG');
    });

    test("smart quote (right single quote U+2019) prefixed Bulgarian number is normalized", () {
      // COMPANY-SPECIFIC: ’0877123456 → 0877123456 → +359877123456
      final result = PhoneNormalizer.normalize("’0877123456");
      expect(result.isValid, isTrue);
      expect(result.normalizedNumber, '+359877123456');
      expect(result.country, 'BG');
    });

    test("left single quote (U+2018) prefixed Bulgarian number is normalized", () {
      final result = PhoneNormalizer.normalize("‘0898123456");
      expect(result.isValid, isTrue);
      expect(result.normalizedNumber, '+359898123456');
      expect(result.country, 'BG');
    });

    test("numeric float string (.0 from Google Sheets double value) is normalized", () {
      // REAL-WORLD CASE: 898123456.0 → 0898123456 → +359898123456
      final result = PhoneNormalizer.normalize("898123456.0");
      expect(result.isValid, isTrue);
      expect(result.normalizedNumber, '+359898123456');
      expect(result.country, 'BG');
    });

    test("numeric float string with 877 prefix is normalized", () {
      // REAL-WORLD CASE: 877123456.0 → 0877123456 → +359877123456
      final result = PhoneNormalizer.normalize("877123456.0");
      expect(result.isValid, isTrue);
      expect(result.normalizedNumber, '+359877123456');
      expect(result.country, 'BG');
    });

    test("number surrounded by non-breaking spaces or unicode whitespace is normalized", () {
      final result = PhoneNormalizer.normalize("\u00a0'0898123456\u200b");
      expect(result.isValid, isTrue);
      expect(result.normalizedNumber, '+359898123456');
      expect(result.country, 'BG');
    });

    // ── National format ──────────────────────────────────────────────────────

    test('French national format is converted to E.164', () {
      final result = PhoneNormalizer.normalize('0177455329');
      expect(result.isValid, isTrue);
      expect(result.normalizedNumber, '+33177455329');
      expect(result.country, 'FR');
    });

    test('Bulgarian national format is converted to E.164', () {
      final result = PhoneNormalizer.normalize('0898123456');
      expect(result.isValid, isTrue);
      expect(result.normalizedNumber, '+359898123456');
      expect(result.country, 'BG');
    });

    // ── Multiple numbers in one cell ─────────────────────────────────────────

    test('slash-separated numbers: only first is used', () {
      final result = PhoneNormalizer.normalize('0898123456 / 0888123456');
      expect(result.isValid, isTrue);
      expect(result.normalizedNumber, '+359898123456');
    });

    test('comma-separated numbers: only first is used', () {
      final result = PhoneNormalizer.normalize('0898123456, +359887123456');
      expect(result.isValid, isTrue);
      expect(result.normalizedNumber, '+359898123456');
    });

    test('semicolon-separated numbers: only first is used', () {
      final result = PhoneNormalizer.normalize('0898123456;0888123456');
      expect(result.isValid, isTrue);
      expect(result.normalizedNumber, '+359898123456');
    });

    // ── Formatting noise ─────────────────────────────────────────────────────

    test('spaces and dashes in number are stripped', () {
      final result = PhoneNormalizer.normalize('+33 1 77 45 53 29');
      expect(result.isValid, isTrue);
      expect(result.normalizedNumber, '+33177455329');
    });

    // ── Country detection ────────────────────────────────────────────────────

    test('French number returns country FR', () {
      expect(PhoneNormalizer.normalize('+33177455329').country, 'FR');
    });

    test('Bulgarian number returns country BG', () {
      expect(PhoneNormalizer.normalize('+359898123456').country, 'BG');
    });

    test('UK number returns country GB', () {
      expect(PhoneNormalizer.normalize('+442079460912').country, 'GB');
    });

    test('US number returns country US', () {
      expect(PhoneNormalizer.normalize('+12125550199').country, 'US');
    });

    test('German number returns country DE', () {
      expect(PhoneNormalizer.normalize('+4930123456').country, 'DE');
    });

    // ── Country Name Resolution ──────────────────────────────────────────────

    test('getCountryName maps ISO alpha-2 codes to full country names', () {
      expect(PhoneNormalizer.getCountryName('BG'), 'Bulgaria');
      expect(PhoneNormalizer.getCountryName('FR'), 'France');
      expect(PhoneNormalizer.getCountryName('GB'), 'United Kingdom');
      expect(PhoneNormalizer.getCountryName('US'), 'United States');
      expect(PhoneNormalizer.getCountryName('DE'), 'Germany');
    });

    test('getCountryName handles lowercase codes and whitespace', () {
      expect(PhoneNormalizer.getCountryName(' bg '), 'Bulgaria');
      expect(PhoneNormalizer.getCountryName('fr'), 'France');
    });

    test('getCountryName returns Unknown for null, empty, or unmapped codes', () {
      expect(PhoneNormalizer.getCountryName(null), 'Unknown');
      expect(PhoneNormalizer.getCountryName(''), 'Unknown');
      expect(PhoneNormalizer.getCountryName('   '), 'Unknown');
      expect(PhoneNormalizer.getCountryName('XX'), 'Unknown');
    });

    // ── Invalid / edge cases ─────────────────────────────────────────────────

    test('empty string returns invalid result', () {
      final result = PhoneNormalizer.normalize('');
      expect(result.isValid, isFalse);
      expect(result.normalizedNumber, isNull);
      expect(result.country, isNull);
    });

    test('non-numeric string returns invalid result', () {
      final result = PhoneNormalizer.normalize('abc');
      expect(result.isValid, isFalse);
    });

    test('too-short digit string returns invalid result', () {
      // 6 digits — below 7-digit ITU minimum
      final result = PhoneNormalizer.normalize('123456');
      expect(result.isValid, isFalse);
    });

    test('unknown country prefix returns invalid result', () {
      // '999' is not a valid ITU country code
      final result = PhoneNormalizer.normalize('99912345678');
      expect(result.isValid, isFalse);
    });

    // ── rawFirst preserved ───────────────────────────────────────────────────

    test('rawFirst contains original input for valid number', () {
      final result = PhoneNormalizer.normalize("'0898123456");
      expect(result.rawFirst, "'0898123456");
    });

    test('rawFirst contains original input for invalid number', () {
      final result = PhoneNormalizer.normalize('abc');
      expect(result.rawFirst, 'abc');
    });
  });
}
