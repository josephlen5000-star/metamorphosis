/// UPC-A, EAN-8, EAN-13, and GTIN-14 helpers for barcode lookup.
///
/// Camera decoding stays elsewhere. This file only normalizes and matches
/// codes so USDA lookup can be tested without a device camera.
class ParsedBarcode {
  const ParsedBarcode({
    required this.digits,
    required this.lookupQueries,
  });

  /// Canonical digits used for GTIN comparison (no leading-zero padding).
  final String digits;

  /// Distinct USDA search queries to try, most likely first.
  final List<String> lookupQueries;
}

final _nonDigits = RegExp(r'\D');

/// Parses a UPC/EAN/GTIN from scanner or typed input.
///
/// Returns null for empty, non-numeric, wrong-length, or bad checksum values.
ParsedBarcode? parseUpcEan(String raw) {
  final digits = raw.replaceAll(_nonDigits, '');
  if (digits.isEmpty) return null;

  final expanded = _expandUpcE(digits) ?? digits;
  if (!_hasSupportedLength(expanded) || !_hasValidGtinCheck(expanded)) {
    return null;
  }

  return ParsedBarcode(
    digits: _stripLeadingZeros(expanded),
    lookupQueries: _lookupQueries(expanded),
  );
}

/// True when [gtinUpc] from FDC is the same product as [digits].
bool gtinMatches(String? gtinUpc, String digits) {
  final left = (gtinUpc ?? '').replaceAll(_nonDigits, '');
  final right = digits.replaceAll(_nonDigits, '');
  if (left.isEmpty || right.isEmpty) return false;
  return _toGtin14(left) == _toGtin14(right);
}

String _toGtin14(String digits) => digits.padLeft(14, '0');

String _stripLeadingZeros(String digits) {
  final stripped = digits.replaceFirst(RegExp(r'^0+'), '');
  return stripped.isEmpty ? '0' : stripped;
}

bool _hasSupportedLength(String digits) {
  return digits.length == 8 ||
      digits.length == 12 ||
      digits.length == 13 ||
      digits.length == 14;
}

/// GS1 check digit, counting from the right.
bool _hasValidGtinCheck(String digits) {
  if (!_hasSupportedLength(digits)) return false;
  var sum = 0;
  for (var i = 0; i < digits.length - 1; i++) {
    final value = int.parse(digits[digits.length - 2 - i]);
    sum += i.isEven ? value * 3 : value;
  }
  final check = (10 - (sum % 10)) % 10;
  return check == int.parse(digits[digits.length - 1]);
}

List<String> _lookupQueries(String digits) {
  final queries = <String>[digits];
  if (digits.length == 12) {
    queries.add('0$digits');
    queries.add('00$digits');
  } else if (digits.length == 13) {
    if (digits.startsWith('0')) {
      queries.add(digits.substring(1));
    }
    queries.add('0$digits');
  } else if (digits.length == 14) {
    var trimmed = digits;
    while (trimmed.startsWith('0') && trimmed.length > 8) {
      trimmed = trimmed.substring(1);
      if (_hasSupportedLength(trimmed)) queries.add(trimmed);
    }
  } else if (digits.length == 8) {
    queries.add(digits.padLeft(12, '0'));
    queries.add(digits.padLeft(13, '0'));
    queries.add(digits.padLeft(14, '0'));
  }

  final seen = <String>{};
  return [
    for (final query in queries)
      if (seen.add(query)) query,
  ];
}

/// Expands UPC-E (6–8 digits) to a 12-digit UPC-A when possible.
String? _expandUpcE(String digits) {
  late final String numberSystem;
  late final String body;
  if (digits.length == 6) {
    numberSystem = '0';
    body = digits;
  } else if (digits.length == 7) {
    numberSystem = digits[0];
    body = digits.substring(1);
  } else if (digits.length == 8) {
    numberSystem = digits[0];
    body = digits.substring(1, 7);
  } else {
    return null;
  }

  if (numberSystem != '0' && numberSystem != '1') return null;

  final d1 = body[0];
  final d2 = body[1];
  final d3 = body[2];
  final d4 = body[3];
  final d5 = body[4];
  final d6 = body[5];

  final String manufacturer;
  final String product;
  switch (d6) {
    case '0':
    case '1':
    case '2':
      manufacturer = '$d1$d2$d6';
      product = '000$d3$d4$d5';
    case '3':
      manufacturer = '$d1$d2$d3';
      product = '0000$d4$d5';
    case '4':
      manufacturer = '$d1$d2$d3$d4';
      product = '00000$d5';
    default:
      manufacturer = '$d1$d2$d3$d4$d5';
      product = '0000$d6';
  }

  final withoutCheck = '$numberSystem$manufacturer$product';
  return '$withoutCheck${_gtinCheckDigit(withoutCheck)}';
}

String _gtinCheckDigit(String digitsWithoutCheck) {
  var sum = 0;
  final padded = digitsWithoutCheck;
  for (var i = 0; i < padded.length; i++) {
    final value = int.parse(padded[padded.length - 1 - i]);
    sum += i.isEven ? value * 3 : value;
  }
  return '${(10 - (sum % 10)) % 10}';
}
