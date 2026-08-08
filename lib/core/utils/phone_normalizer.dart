/// Phone number normalization, validation, and country detection.
///
/// ## Pipeline
///
/// Every raw phone string passes through the following stages in order:
///
/// 1. **Strip company-specific prefixes** — removes the spreadsheet apostrophe
///    trick (`'0898123456` → `0898123456`). See [_companySpecificRules].
/// 2. **Split multi-number cells** — splits on `/`, `,`, `;`, or whitespace
///    sequences and uses only the **first** token. Cold-calling requires
///    exactly one dialable number; extras are discarded.
/// 3. **Strip non-digit characters** — removes spaces, dashes, dots, parens.
/// 4. **Apply company-specific digit-level fixes** — e.g., restore the
///    Bulgarian leading zero when a numeric cell dropped it.
/// 5. **Detect country / normalize to E.164** — matches the digit string
///    against [_countryDialCodes] prefix table and prepends `+`.
/// 6. **Validate length** — numbers shorter than 7 or longer than 15 digits
///    (ITU-T E.164 bounds) after country-code removal are rejected.
///
/// ## Separation between generic and company-specific rules
///
/// Generic product logic lives in the pipeline methods that are prefixed with
/// NO comment. Rules that are specific to the current company's spreadsheet
/// are grouped under a `// ── COMPANY-SPECIFIC ──` block and documented with
/// a `// COMPANY-SPECIFIC:` inline comment. Removing all such lines produces
/// a fully generic normalizer ready for any other customer.
///
/// ## Adding a new country
///
/// Add one entry to [_countryDialCodes]:
///   ```dart
///   '49': 'DE', // Germany
///   ```
/// The rest of the pipeline handles it automatically.
class PhoneNormalizer {
  PhoneNormalizer._(); // Pure static utility — not instantiable.

  // ── Generic country dial-code table ────────────────────────────────────────
  //
  // Maps the ITU-T digit prefix to an ISO 3166-1 alpha-2 country code.
  // Ordered longest-prefix-first within each country-code group so that
  // more-specific codes (e.g., '1787' for Puerto Rico) do not collide with
  // broader ones (e.g., '1' for the US) — the table is scanned top-to-bottom.
  //
  // Only countries relevant to this product are listed. Extend freely.
  static const Map<String, String> _countryDialCodes = {
    // ── Europe ──
    '33': 'FR', // France
    '359': 'BG', // Bulgaria
    '44': 'GB', // United Kingdom
    '49': 'DE', // Germany
    '34': 'ES', // Spain
    '39': 'IT', // Italy
    '32': 'BE', // Belgium
    '31': 'NL', // Netherlands
    '41': 'CH', // Switzerland
    '43': 'AT', // Austria
    '351': 'PT', // Portugal
    '30': 'GR', // Greece
    '48': 'PL', // Poland
    '420': 'CZ', // Czech Republic
    '421': 'SK', // Slovakia
    '36': 'HU', // Hungary
    '40': 'RO', // Romania
    '380': 'UA', // Ukraine
    '353': 'IE', // Ireland
    '46': 'SE', // Sweden
    '47': 'NO', // Norway
    '45': 'DK', // Denmark
    '358': 'FI', // Finland
    '385': 'HR', // Croatia
    '381': 'RS', // Serbia
    '386': 'SI', // Slovenia
    '389': 'MK', // North Macedonia
    '355': 'AL', // Albania
    '370': 'LT', // Lithuania
    '371': 'LV', // Latvia
    '372': 'EE', // Estonia
    '373': 'MD', // Moldova
    '374': 'AM', // Armenia
    '995': 'GE', // Georgia
    '356': 'MT', // Malta
    '357': 'CY', // Cyprus
    '352': 'LU', // Luxembourg
    '354': 'IS', // Iceland
    '7': 'RU', // Russia
    // ── Americas ──
    '1': 'US', // United States / Canada (NANP)
    '52': 'MX', // Mexico
    '55': 'BR', // Brazil
    '54': 'AR', // Argentina
    '56': 'CL', // Chile
    '57': 'CO', // Colombia
    '51': 'PE', // Peru
    '58': 'VE', // Venezuela
    '593': 'EC', // Ecuador
    '598': 'UY', // Uruguay
    '595': 'PY', // Paraguay
    '502': 'GT', // Guatemala
    '503': 'SV', // El Salvador
    '504': 'HN', // Honduras
    '505': 'NI', // Nicaragua
    '506': 'CR', // Costa Rica
    '507': 'PA', // Panama
    '509': 'HT', // Haiti
    '591': 'BO', // Bolivia
    '592': 'GY', // Guyana
    '597': 'SR', // Suriname
    // ── Middle East & Africa ──
    '971': 'AE', // UAE
    '966': 'SA', // Saudi Arabia
    '972': 'IL', // Israel
    '961': 'LB', // Lebanon
    '962': 'JO', // Jordan
    '964': 'IQ', // Iraq
    '965': 'KW', // Kuwait
    '968': 'OM', // Oman
    '974': 'QA', // Qatar
    '973': 'BH', // Bahrain
    '90': 'TR', // Turkey
    '20': 'EG', // Egypt
    '212': 'MA', // Morocco
    '213': 'DZ', // Algeria
    '216': 'TN', // Tunisia
    '27': 'ZA', // South Africa
    '254': 'KE', // Kenya
    '234': 'NG', // Nigeria
    '233': 'GH', // Ghana
    '251': 'ET', // Ethiopia
    '255': 'TZ', // Tanzania
    '256': 'UG', // Uganda
    '221': 'SN', // Senegal
    '225': 'CI', // Ivory Coast
    '237': 'CM', // Cameroon
    '244': 'AO', // Angola
    '260': 'ZM', // Zambia
    '263': 'ZW', // Zimbabwe
    // ── Asia-Pacific ──
    '91': 'IN', // India
    '86': 'CN', // China
    '81': 'JP', // Japan
    '82': 'KR', // South Korea
    '61': 'AU', // Australia
    '64': 'NZ', // New Zealand
    '65': 'SG', // Singapore
    '60': 'MY', // Malaysia
    '62': 'ID', // Indonesia
    '63': 'PH', // Philippines
    '66': 'TH', // Thailand
    '84': 'VN', // Vietnam
    '92': 'PK', // Pakistan
    '880': 'BD', // Bangladesh
    '94': 'LK', // Sri Lanka
    '977': 'NP', // Nepal
    '852': 'HK', // Hong Kong
    '886': 'TW', // Taiwan
  };

  // ── ISO 3166-1 alpha-2 Code to English Country Name Map ─────────────────────
  static const Map<String, String> _countryNames = {
    'AF': 'Afghanistan',
    'AL': 'Albania',
    'DZ': 'Algeria',
    'AO': 'Angola',
    'AR': 'Argentina',
    'AM': 'Armenia',
    'AU': 'Australia',
    'AT': 'Austria',
    'AZ': 'Azerbaijan',
    'BH': 'Bahrain',
    'BD': 'Bangladesh',
    'BY': 'Belarus',
    'BE': 'Belgium',
    'BO': 'Bolivia',
    'BA': 'Bosnia and Herzegovina',
    'BR': 'Brazil',
    'BG': 'Bulgaria',
    'KH': 'Cambodia',
    'CM': 'Cameroon',
    'CA': 'Canada',
    'CL': 'Chile',
    'CN': 'China',
    'CO': 'Colombia',
    'CR': 'Costa Rica',
    'HR': 'Croatia',
    'CY': 'Cyprus',
    'CZ': 'Czech Republic',
    'DK': 'Denmark',
    'EC': 'Ecuador',
    'EG': 'Egypt',
    'SV': 'El Salvador',
    'EE': 'Estonia',
    'ET': 'Ethiopia',
    'FI': 'Finland',
    'FR': 'France',
    'GE': 'Georgia',
    'DE': 'Germany',
    'GH': 'Ghana',
    'GR': 'Greece',
    'GT': 'Guatemala',
    'GY': 'Guyana',
    'HT': 'Haiti',
    'HN': 'Honduras',
    'HK': 'Hong Kong',
    'HU': 'Hungary',
    'IS': 'Iceland',
    'IN': 'India',
    'ID': 'Indonesia',
    'IQ': 'Iraq',
    'IE': 'Ireland',
    'IL': 'Israel',
    'IT': 'Italy',
    'CI': 'Ivory Coast',
    'JP': 'Japan',
    'JO': 'Jordan',
    'KE': 'Kenya',
    'KW': 'Kuwait',
    'LV': 'Latvia',
    'LB': 'Lebanon',
    'LT': 'Lithuania',
    'LU': 'Luxembourg',
    'MK': 'North Macedonia',
    'MY': 'Malaysia',
    'MT': 'Malta',
    'MX': 'Mexico',
    'MD': 'Moldova',
    'MA': 'Morocco',
    'NP': 'Nepal',
    'NL': 'Netherlands',
    'NZ': 'New Zealand',
    'NI': 'Nicaragua',
    'NG': 'Nigeria',
    'NO': 'Norway',
    'OM': 'Oman',
    'PK': 'Pakistan',
    'PA': 'Panama',
    'PY': 'Paraguay',
    'PE': 'Peru',
    'PH': 'Philippines',
    'PL': 'Poland',
    'PT': 'Portugal',
    'QA': 'Qatar',
    'RO': 'Romania',
    'RU': 'Russia',
    'SA': 'Saudi Arabia',
    'SN': 'Senegal',
    'RS': 'Serbia',
    'SG': 'Singapore',
    'SK': 'Slovakia',
    'SI': 'Slovenia',
    'ZA': 'South Africa',
    'KR': 'South Korea',
    'ES': 'Spain',
    'LK': 'Sri Lanka',
    'SR': 'Suriname',
    'SE': 'Sweden',
    'CH': 'Switzerland',
    'TW': 'Taiwan',
    'TZ': 'Tanzania',
    'TH': 'Thailand',
    'TN': 'Tunisia',
    'TR': 'Turkey',
    'UG': 'Uganda',
    'UA': 'Ukraine',
    'AE': 'United Arab Emirates',
    'GB': 'United Kingdom',
    'US': 'United States',
    'UY': 'Uruguay',
    'VE': 'Venezuela',
    'VN': 'Vietnam',
    'ZM': 'Zambia',
    'ZW': 'Zimbabwe',
  };

  /// Returns the human-readable English country name for an ISO 3166-1 alpha-2
  /// country code (e.g., `'BG'` → `'Bulgaria'`, `'FR'` → `'France'`, `'GB'` → `'United Kingdom'`).
  ///
  /// Returns `'Unknown'` if [countryCode] is null, empty, or not recognized.
  static String getCountryName(String? countryCode) {
    if (countryCode == null || countryCode.trim().isEmpty) {
      return 'Unknown';
    }
    return _countryNames[countryCode.trim().toUpperCase()] ?? 'Unknown';
  }

  // ── COMPANY-SPECIFIC ────────────────────────────────────────────────────────
  //
  // Rules below are specific to the current customer's Google Sheet.
  // They do not represent generic product behaviour.
  // Remove this block when onboarding a different customer whose data
  // does not exhibit these patterns.
  //
  // Rule 1: Apostrophe prefix
  //   Google Sheets inserts a leading apostrophe when a number is entered as
  //   text to preserve leading zeros. The cell value exported via the API
  //   includes the apostrophe literally.
  //   Example: '0898123456 → 0898123456
  //
  // Rule 2: Missing leading zero (Bulgarian numbers stored as numeric values)
  //   When a Bulgarian number is stored as a number (not text), the leading
  //   zero is dropped by Google Sheets.
  //   Example: 898123456 → 0898123456
  //   This is detected by checking that the digit string is 9 digits long AND
  //   starts with '8' or '9' — the valid ranges for Bulgarian mobile numbers.
  //
  // Rule 3: Missing '+' prefix on international numbers
  //   Some international numbers are stored without the '+' but still include
  //   the country code (e.g., 33177455329 → +33177455329).
  //   This is handled generically by the country detection step, which prepends
  //   '+' when it recognises the leading digits as a known country code.
  //   No separate rule is needed; it works automatically.

  /// Normalizes [raw] according to the pipeline described in the class doc.
  ///
  /// Returns a [PhoneNormalizationResult] with the E.164 form and detected
  /// country on success, or an invalid result with the original input on failure.
  static PhoneNormalizationResult normalize(String raw) {
    // ── Stage 1: company-specific prefix & format cleanup ─────────────────────
    // Strip leading/trailing Unicode whitespace, non-breaking space (\u00a0),
    // zero-width space (\u200b), and byte order mark (\ufeff).
    var working = raw.replaceAll(
        RegExp(r'^[\s\u00a0\u200b\ufeff]+|[\s\u00a0\u200b\ufeff]+$'), '');

    // COMPANY-SPECIFIC: strip leading quotes, apostrophes (ASCII ' U+0027,
    // right single quote ’ U+2019, left single quote ‘ U+2018, backtick ` U+0060,
    // acute ´ U+00B4, prime ′ U+2032, modifier ʼ U+02BC, double quotes " ” “),
    // and backslashes used in Google Sheets / Excel cell export.
    working = working
        .replaceAll(RegExp(r'''^['’‘`´′ʼ"”“\\]+'''), '')
        .replaceAll(RegExp(r'''['’‘`´′ʼ"”“\\]+$'''), '')
        .trim();

    // COMPANY-SPECIFIC: strip trailing .0 or .00 if cell was converted from
    // a double/float numeric value in Google Sheets (e.g. "898123456.0").
    working = working.replaceAll(RegExp(r'\.0+(?=$|\s|[/,;])'), '');

    // ── Stage 2: split multi-number cells; keep first token ─────────────────
    // Generic: a cell may contain several numbers separated by common delimiters.
    final firstToken = _extractFirstNumber(working);
    if (firstToken.isEmpty) {
      return PhoneNormalizationResult.invalid(raw);
    }
    working = firstToken;

    // ── Stage 3: strip all non-digit characters ──────────────────────────────
    final digits = working.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) {
      return PhoneNormalizationResult.invalid(raw);
    }

    // ── Stage 4: company-specific digit-level fixes ──────────────────────────
    // COMPANY-SPECIFIC: Bulgarian numbers (BG) without leading zero.
    // Bulgarian mobile numbers have 10 digits starting with 07, 08, 09.
    // When stored as numeric cells, the leading 0 is dropped leaving 9 digits
    // starting with 7, 8, or 9.
    // Bulgarian landline numbers have 9 digits starting with 0 (e.g. 02 Sofia).
    // When stored as numeric cells, the leading 0 is dropped leaving 8 digits.
    var normalizedDigits = digits;
    if (digits.length == 9 &&
        (digits.startsWith('7') ||
            digits.startsWith('8') ||
            digits.startsWith('9'))) {
      // COMPANY-SPECIFIC: restore leading zero for mobile numbers.
      normalizedDigits = '0$digits';
    } else if (digits.length == 8 && RegExp(r'^[2-9]').hasMatch(digits)) {
      // COMPANY-SPECIFIC: restore leading zero for landline numbers.
      normalizedDigits = '0$digits';
    }

    // ── Stage 5: country detection and E.164 conversion ─────────────────────
    // Case A: number already has a '+' prefix → E.164 candidate.
    if (raw.trimLeft().startsWith('+') || working.trimLeft().startsWith('+')) {
      return _fromE164Candidate('+$normalizedDigits', raw);
    }

    // Case B: number starts with '00' (international prefix in some locales).
    if (normalizedDigits.startsWith('00')) {
      final withoutIDD = normalizedDigits.substring(2);
      return _fromE164Candidate('+$withoutIDD', raw);
    }

    // Case C: number starts with a local trunk prefix ('0') → national number.
    if (normalizedDigits.startsWith('0')) {
      return _fromNational(normalizedDigits, raw);
    }

    // Case D: number has no leading zero/00/+ → may be a country-code-prefixed
    // number without the '+' (e.g., 33177455329 for France or 359898123456 for BG).
    return _fromDigitsOnly(normalizedDigits, raw);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Splits [raw] on common multi-number separators and returns the first
  /// non-empty token. Returns empty string if nothing usable is found.
  static String _extractFirstNumber(String raw) {
    // Separators: slash, comma, semicolon, or whitespace runs.
    final tokens = raw.split(RegExp(r'[/,;]+|\s{2,}'));
    for (final t in tokens) {
      final trimmed = t.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  /// Tries to interpret [e164] (already `+` + digits) as a valid E.164 number.
  static PhoneNormalizationResult _fromE164Candidate(
      String e164, String raw) {
    final digits = e164.substring(1); // drop leading '+'
    final country = _detectCountry(digits);
    if (!_isValidLength(digits)) {
      return PhoneNormalizationResult.invalid(raw);
    }
    return PhoneNormalizationResult(
      normalizedNumber: e164,
      country: country,
      rawFirst: raw,
      isValid: true,
    );
  }

  /// Interprets [national] (a number starting with '0') as a national-format
  /// number and looks up the country from a heuristic: Bulgarian national
  /// numbers start with '07x', '08x', '09x' (mobile) or '02'..'09' (landline);
  /// French numbers start with '01'..'09'.
  ///
  /// Because national format is inherently ambiguous without a default country
  /// configured by the user, this method performs a best-effort detection.
  static PhoneNormalizationResult _fromNational(String national, String raw) {
    // COMPANY-SPECIFIC: Bulgarian national → E.164 conversion.
    // BG national mobile: 07x, 08x, 09x (10 digits starting with 07, 08, 09).
    // BG national landline: 02 (Sofia, 9 digits), 032, 052, etc. (9 digits).
    if ((national.length == 10 && RegExp(r'^0[789]').hasMatch(national)) ||
        (national.length == 9 && national.startsWith('0'))) {
      final e164 = '+359${national.substring(1)}';
      return PhoneNormalizationResult(
        normalizedNumber: e164,
        country: 'BG',
        rawFirst: raw,
        isValid: true,
      );
    }

    // COMPANY-SPECIFIC: French national → E.164 conversion.
    // FR national: 0x xx xx xx xx (10 digits starting with 01–09).
    if (national.length == 10 && national.startsWith('0')) {
      final e164 = '+33${national.substring(1)}';
      return PhoneNormalizationResult(
        normalizedNumber: e164,
        country: 'FR',
        rawFirst: raw,
        isValid: true,
      );
    }

    // Fallback: unknown national number — return invalid.
    return PhoneNormalizationResult.invalid(raw);
  }

  /// Interprets a bare digit string (no leading zero, no '+') as a potential
  /// international number without the '+' prefix (e.g., `33177455329`).
  static PhoneNormalizationResult _fromDigitsOnly(String digits, String raw) {
    final country = _detectCountry(digits);
    if (country == null || !_isValidLength(digits)) {
      return PhoneNormalizationResult.invalid(raw);
    }
    return PhoneNormalizationResult(
      normalizedNumber: '+$digits',
      country: country,
      rawFirst: raw,
      isValid: true,
    );
  }

  /// Returns the ISO 3166-1 alpha-2 country code by matching the longest
  /// known dial-code prefix in [digits]. Returns null if not recognized.
  static String? _detectCountry(String digits) {
    // Try longest prefix first (up to 4 digits for country codes like '1767').
    for (var len = 4; len >= 1; len--) {
      if (digits.length < len) continue;
      final prefix = digits.substring(0, len);
      if (_countryDialCodes.containsKey(prefix)) {
        return _countryDialCodes[prefix];
      }
    }
    return null;
  }

  /// Validates that [digits] (without the '+') satisfy E.164 bounds:
  /// minimum 7 digits (shortest ITU numbers), maximum 15 digits.
  static bool _isValidLength(String digits) =>
      digits.length >= 7 && digits.length <= 15;
}

/// The result of a [PhoneNormalizer.normalize] call.
///
/// Immutable value object. Use [isValid] to check before accessing
/// [normalizedNumber] and [country].
class PhoneNormalizationResult {
  const PhoneNormalizationResult({
    required this.normalizedNumber,
    required this.country,
    required this.rawFirst,
    required this.isValid,
  });

  /// Constructs an invalid result from the original [raw] input.
  const PhoneNormalizationResult.invalid(String raw)
      : normalizedNumber = null,
        country = null,
        rawFirst = raw,
        isValid = false;

  /// E.164 formatted number (e.g., `+33177455329`). Null when [isValid] is false.
  final String? normalizedNumber;

  /// ISO 3166-1 alpha-2 country code (e.g., `'FR'`, `'BG'`).
  /// Null when [isValid] is false or the country could not be determined.
  final String? country;

  /// The first token extracted from the raw input before normalization.
  /// Preserved for debugging and for the [ContactModel.rawSourcePhoneNumber]
  /// field that is used by the sync adapter to locate the original sheet row.
  final String rawFirst;

  /// True when normalization succeeded and [normalizedNumber] is usable.
  final bool isValid;
}
