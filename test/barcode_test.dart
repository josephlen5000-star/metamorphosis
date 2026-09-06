import 'package:flutter_test/flutter_test.dart';
import 'package:metamorphosis/services/barcode.dart';

void main() {
  test('accepts a valid UPC-A and builds padded lookup queries', () {
    final parsed = parseUpcEan('012345678905');

    expect(parsed, isNotNull);
    expect(parsed!.digits, '12345678905');
    expect(parsed.lookupQueries, containsAll(['012345678905', '0012345678905']));
  });

  test('accepts a valid EAN-13 and a spaced GTIN-14', () {
    expect(parseUpcEan('0012345678905'), isNotNull);
    expect(parseUpcEan('00 01234 567890 5'), isNotNull);
  });

  test('expands UPC-E to UPC-A before lookup', () {
    final parsed = parseUpcEan('02345675');

    expect(parsed, isNotNull);
    expect(parsed!.lookupQueries.first, '023456000073');
    expect(gtinMatches('023456000073', parsed.digits), isTrue);
  });

  test('rejects empty, non-digit, short, and bad-checksum codes', () {
    expect(parseUpcEan(''), isNull);
    expect(parseUpcEan('QR-NOT-A-UPC'), isNull);
    expect(parseUpcEan('123'), isNull);
    expect(parseUpcEan('012345678906'), isNull);
  });

  test('matches FDC gtinUpc values that differ only by leading zeros', () {
    expect(gtinMatches('012345678905', '12345678905'), isTrue);
    expect(gtinMatches('0012345678905', '012345678905'), isTrue);
    expect(gtinMatches('999999999999', '012345678905'), isFalse);
    expect(gtinMatches(null, '012345678905'), isFalse);
  });
}
