/// Result structure representing parsed Application Identifiers (AIs) from a GS1 barcode.
class Gs1ParseResult {
  final String? gtin; // AI (01)
  final String? lotNumber; // AI (10)
  final DateTime? expiryDate; // AI (17) YYMMDD
  final String? serialNumber; // AI (21)
  final double? netWeightKg; // AI (3102)
  final String? sscc; // AI (00)
  final Map<String, String> rawAis;

  const Gs1ParseResult({
    this.gtin,
    this.lotNumber,
    this.expiryDate,
    this.serialNumber,
    this.netWeightKg,
    this.sscc,
    this.rawAis = const {},
  });

  @override
  String toString() {
    return 'Gs1ParseResult(gtin: $gtin, lot: $lotNumber, expiry: $expiryDate, sn: $serialNumber, weight: $netWeightKg, sscc: $sscc)';
  }
}

/// Offline GS1-128 & GS1 DataMatrix Barcode Parser
class Gs1BarcodeParser {
  /// Parses a raw barcode string with bracketed or FNC1-separated GS1 Application Identifiers.
  /// Example input with brackets: "(01)09312345000017(10)LOT202610(17)261012(3102)025600"
  /// Example input plain text: "01093123450000171726101210LOT202610"
  static Gs1ParseResult parse(String barcode) {
    final cleaned = barcode.trim();
    final rawAis = <String, String>{};

    if (cleaned.startsWith('(')) {
      // Bracket-formatted representation
      final regex = RegExp(r'\((\d{2,4})\)([^()]+)');
      final matches = regex.allMatches(cleaned);
      for (final match in matches) {
        final ai = match.group(1);
        final value = match.group(2);
        if (ai != null && value != null) {
          rawAis[ai] = value.trim();
        }
      }
    } else {
      // Basic linear GS1 parsing for fixed-length standard AIs
      int index = 0;
      while (index < cleaned.length) {
        if (cleaned.startsWith('01', index) && index + 16 <= cleaned.length) {
          rawAis['01'] = cleaned.substring(index + 2, index + 16);
          index += 16;
        } else if (cleaned.startsWith('00', index) && index + 20 <= cleaned.length) {
          rawAis['00'] = cleaned.substring(index + 2, index + 20);
          index += 20;
        } else if (cleaned.startsWith('17', index) && index + 8 <= cleaned.length) {
          rawAis['17'] = cleaned.substring(index + 2, index + 8);
          index += 8;
        } else if (cleaned.startsWith('3102', index) && index + 10 <= cleaned.length) {
          rawAis['3102'] = cleaned.substring(index + 4, index + 10);
          index += 10;
        } else if (cleaned.startsWith('10', index)) {
          // Variable length lot, capture remaining if no separator
          rawAis['10'] = cleaned.substring(index + 2);
          break;
        } else if (cleaned.startsWith('21', index)) {
          // Variable length serial number
          rawAis['21'] = cleaned.substring(index + 2);
          break;
        } else {
          // Unknown token, advance 1 character
          index++;
        }
      }
    }

    // Extract typed fields
    final gtin = rawAis['01'];
    final sscc = rawAis['00'];
    final lot = rawAis['10'];
    final sn = rawAis['21'];

    DateTime? expiry;
    final expiryStr = rawAis['17'];
    if (expiryStr != null && expiryStr.length == 6) {
      try {
        final yy = int.parse(expiryStr.substring(0, 2));
        final mm = int.parse(expiryStr.substring(2, 4));
        final dd = int.parse(expiryStr.substring(4, 6));
        final fullYear = 2000 + yy;
        expiry = DateTime(fullYear, mm, dd == 0 ? 1 : dd);
      } catch (_) {}
    }

    double? weight;
    final weightStr = rawAis['3102'];
    if (weightStr != null) {
      try {
        final rawVal = double.parse(weightStr);
        weight = rawVal / 100.0; // Two decimal places
      } catch (_) {}
    }

    return Gs1ParseResult(
      gtin: gtin,
      lotNumber: lot,
      expiryDate: expiry,
      serialNumber: sn,
      netWeightKg: weight,
      sscc: sscc,
      rawAis: rawAis,
    );
  }
}
