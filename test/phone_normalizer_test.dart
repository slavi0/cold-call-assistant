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
