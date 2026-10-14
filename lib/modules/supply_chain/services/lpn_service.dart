import 'dart:math';

/// Service for generating, validating and managing Pallet License Plate Numbers (LPN)
/// and GS1 Serial Shipping Container Codes (SSCC-18).
class LpnService {
  /// Generates a standardized, human-readable License Plate Number (LPN)
  /// Format: LPN-[PLANT]-[YYYYMMDD]-[RANDOM/SEQ]
  /// Example: LPN-M1-20261005-A8F2
  static String generateLpnCode({
    String plant = 'M1',
    String prefix = 'LPN',
    DateTime? date,
  }) {
    final d = date ?? DateTime.now();
    final year = d.year.toString().padLeft(4, '0');
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final dateStr = '$year$month$day';

    final rng = Random();
    final randomHex = rng.nextInt(0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0');

    return '$prefix-$plant-$dateStr-$randomHex';
  }

  /// Calculates the GS1 Modulo 10 check digit for a given 17-digit numeric string.
  static int calculateGs1CheckDigit(String numeric17) {
    if (numeric17.length != 17 || int.tryParse(numeric17) == null) {
      throw ArgumentError('Input must be a 17-digit numeric string.');
    }

    int sum = 0;
    for (int i = 0; i < 17; i++) {
      final digit = int.parse(numeric17[i]);
      // Multipliers alternate 3 and 1 from right to left (for 17 digits: index 0 is * 3, 1 is * 1, ...)
      final weight = (i % 2 == 0) ? 3 : 1;
      sum += digit * weight;
    }

    final remainder = sum % 10;
    return (remainder == 0) ? 0 : 10 - remainder;
  }

  /// Generates an 18-digit GS1 SSCC-18 (Serial Shipping Container Code).
  /// [extensionDigit]: 0-9
  /// [companyPrefix]: 7-10 digits assigned by GS1
  /// [serialRef]: Sequence number to fill the 17 digits
  static String generateSscc18({
    int extensionDigit = 0,
    String companyPrefix = '9312345', // Default GS1 Australia format demo prefix
    required int serialNumber,
  }) {
    final availableDigits = 16 - companyPrefix.length;
    final serialPadded = serialNumber.toString().padLeft(availableDigits, '0');
    final payload17 = '$extensionDigit$companyPrefix$serialPadded';

    final checkDigit = calculateGs1CheckDigit(payload17);
    return '$payload17$checkDigit';
  }

  /// Validates whether a barcode string is a valid SSCC-18 code with matching check digit.
  static bool isValidSscc18(String sscc) {
    if (sscc.length != 18 || int.tryParse(sscc) == null) {
      return false;
    }
    final payload17 = sscc.substring(0, 17);
    final expectedCheckDigit = calculateGs1CheckDigit(payload17);
    final actualCheckDigit = int.parse(sscc[17]);
    return expectedCheckDigit == actualCheckDigit;
  }
}
