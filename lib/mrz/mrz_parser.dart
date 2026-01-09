import 'dart:ffi';

import 'package:mrz_parser/mrz_parser.dart';

// Only for TD-1 format !

enum MrzField {
  documentType,
  countryCode,
  surnames,
  givenNames,
  fullNames,
  documentNumber,
  nationalityCountryCode,
  birthDate,
  sex,
  expiryDate,
  personalNumber,
  personalNumber2,
  checkDigit,
}

class MRZForOCRMatcher {
  final MrzField field;
  final String pattern;
  final int length;

  RegExp get regExp => RegExp('($pattern)');

  const MRZForOCRMatcher(
    this.field, {
    required this.pattern,
    required this.length,
  });

  const MRZForOCRMatcher.countryCode()
    : this(MrzField.countryCode, pattern: '[A-Z]{2}[A-Z<]', length: 3);

  const MRZForOCRMatcher.alpha(MrzField field, {required int length})
    : this(field, pattern: '[A-Z<]{$length}', length: length);
  const MRZForOCRMatcher.num(
    MrzField field, {
    required bool variableLength,
    required int length,
  }) : this(
         field,
         pattern: (variableLength ? '[0-9<]{$length}' : '[0-9]{$length}'),
         length: length,
       );
  const MRZForOCRMatcher.alphaNum(MrzField field, {required int length})
    : this(field, pattern: '[A-Z0-9<]{$length}', length: length);
  const MRZForOCRMatcher.date(MrzField field)
    : this(field, pattern: '\\d{6}', length: 6);
  const MRZForOCRMatcher.checkDigit()
    : this(MrzField.checkDigit, pattern: '[0-9]<', length: 1);
  const MRZForOCRMatcher.mandatoryCheckDigit()
    : this(MrzField.checkDigit, pattern: '[0-9]', length: 1);

  RegExpMatch? match(String mrzString, {int pos = 0}) {
    return regExp.firstMatch(mrzString.substring(pos));
  }

  String value(String mrzString, {int pos = 0, String? defaultValue}) {
    if (mrzString.length < pos) {
      final match = regExp.firstMatch(mrzString.substring(pos));
      if (match != null) return match.group(1)!;
    }

    if (defaultValue == null) {
      defaultValue = "";
      while (defaultValue!.length < length) {
        defaultValue += '<';
      }
    }

    return defaultValue;
  }
}

class MRZForOCR {
  final List<MRZForOCRMatcher> firstLine;
  final List<MRZForOCRMatcher> secondLine;
  final List<MRZForOCRMatcher>? thirdLine;

  final MRZResult? Function(String raw)? fallback;

  const MRZForOCR({
    required this.firstLine,
    required this.secondLine,
    this.thirdLine,
    this.fallback,
  });

  factory MRZForOCR.td1({MRZResult? Function(String raw)? fallback}) =>
      MRZForOCR(
        firstLine: const [
          MRZForOCRMatcher(
            MrzField.documentType,
            pattern: '[IAC]<|[IAC][A-Z0-9<]',
            length: 2,
          ),
          MRZForOCRMatcher.countryCode(),
          MRZForOCRMatcher.alphaNum(MrzField.documentNumber, length: 9),
          MRZForOCRMatcher.checkDigit(),
          MRZForOCRMatcher.alphaNum(MrzField.personalNumber, length: 15),
        ],
        secondLine: const [
          MRZForOCRMatcher.date(MrzField.birthDate),
          MRZForOCRMatcher.mandatoryCheckDigit(),
          MRZForOCRMatcher(MrzField.sex, pattern: '[MF<]', length: 1),
          MRZForOCRMatcher.date(MrzField.expiryDate),
          MRZForOCRMatcher.mandatoryCheckDigit(),
          MRZForOCRMatcher.countryCode(),
          MRZForOCRMatcher.alphaNum(MrzField.personalNumber2, length: 11),
          MRZForOCRMatcher.checkDigit(),
        ],
        thirdLine: const [
          MRZForOCRMatcher.alpha(MrzField.fullNames, length: 30),
        ],
        fallback: fallback,
      );

  MRZResult? parse(final String mrzString, {bool goFurther = true}) {
    String mrzData = mrzString;
    mrzData = cleanup(mrzData);
    if (mrzData.length < 2) return null;

    final startMatch = firstLine[0].match(mrzData);
    if (startMatch == null) return null;

    // Seeking at real start
    mrzData = mrzData.substring(startMatch.start);

    // Attempt as is first
    MRZResult? parsed;
    if (mrzData.length == 90) {
      parsed = MRZParser.tryParse([
        mrzData.substring(0, 29),
        mrzData.substring(30, 59),
        mrzData.substring(60, 89),
      ]);

      if (parsed != nullptr) return parsed;
    }

    Map<MrzField, String?> found = {};

    final data = List<String>.generate(thirdLine == null ? 2 : 3, (index) {
      List<MRZForOCRMatcher> line;
      switch (index) {
        case 0:
          line = firstLine;
          break;
        case 1:
          line = secondLine;
          break;
        case 2:
          line = thirdLine!;
          break;

        default:
          return "";
      }

      String data = "";
      int pos = index * 30;
      for (final matcher in line) {
        final currentData = matcher.value(mrzData, pos: pos);
        found[matcher.field] = currentData;

        data += currentData;
        pos += matcher.length;
      }
      return data;
    });

    parsed = MRZParser.tryParse(data);
    if (parsed != null || !goFurther) return parsed;

    return MRZResult(
      documentType: found[MrzField.documentType] ?? '',
      countryCode: found[MrzField.countryCode] ?? '',
      surnames: found[MrzField.surnames] ?? '',
      givenNames: found[MrzField.givenNames] ?? '',
      documentNumber: found[MrzField.documentNumber] ?? '',
      nationalityCountryCode: found[MrzField.nationalityCountryCode] ?? '',
      birthDate: DateTime(2025),
      sex: Sex.none,
      expiryDate: DateTime(2025),
      personalNumber: found[MrzField.personalNumber] ?? '',
      personalNumber2: found[MrzField.personalNumber2],
    );
  }

  String cleanLine(RegExpMatch? match) {
    if (match == null) {
      return "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<";
    }

    String line = "";
    for (int group = 0; group < match.groupCount; ++group) {
      line += match.group(group) ?? "";
    }

    while (line.length < 30) {
      line += '<';
    }

    return line;
  }

  String cleanup(String raw) {
    final allowedCharacters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789<';

    // Replace common quirks of OCR
    final replacements = {' ': '', '\n': '', '«': '<<', '⟪': '<<', '⦓': '<<'};

    // Make uppercase first
    raw = raw.toUpperCase();

    for (final entry in replacements.entries) {
      raw = raw.replaceAll(entry.key, entry.value);
    }

    // Remove any character not allowed
    for (int i = 0; i < raw.length; i++) {
      if (!allowedCharacters.contains(raw[i])) {
        raw = raw.replaceAll(raw[i], '<');
      }
    }

    return raw;
  }
}
