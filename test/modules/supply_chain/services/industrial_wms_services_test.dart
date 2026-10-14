import 'package:flutter_test/flutter_test.dart';
import 'package:izii_app/modules/supply_chain/services/uom_converter.dart';
import 'package:izii_app/modules/supply_chain/services/lpn_service.dart';
import 'package:izii_app/modules/supply_chain/services/gs1_barcode_parser.dart';

void main() {
  group('UomConverter Tests', () {
    test('converts quantity accurately between packaging tiers', () {
      // 1 Pallet = 72 boxes, 1 Box = 4 kg. Total pallet = 288 kg.
      // Convert 2 Pallets to Boxes:
      final boxes = UomConverter.convert(
        quantity: 2,
        fromRatio: 288.0,
        toRatio: 4.0,
      );
      expect(boxes, 144.0);

      // Convert 144 Boxes back to Pallets:
      final pallets = UomConverter.convert(
        quantity: 144,
        fromRatio: 4.0,
        toRatio: 288.0,
      );
      expect(pallets, 2.0);
    });

    test('decomposes total packaging into pallets, boxes, and units', () {
      // 1 Box = 12 units, 1 Pallet = 40 boxes (480 units)
      // 1000 units => 2 Pallets (960 units) + 3 Boxes (36 units) + 4 units = 1000
      final breakdown = UomConverter.decomposePackaging(
        totalUnits: 1000,
        unitsPerBox: 12,
        boxesPerPallet: 40,
      );
      expect(breakdown['pallets'], 2);
      expect(breakdown['boxes'], 3);
      expect(breakdown['units'], 4);
    });
  });

  group('LpnService Tests', () {
    test('generates valid LPN codes with site and date components', () {
      final lpn = LpnService.generateLpnCode(
        plant: 'M1',
        prefix: 'LPN',
        date: DateTime(2026, 10, 5),
      );
      expect(lpn.startsWith('LPN-M1-20261005-'), isTrue);
      expect(lpn.length, 22);
    });

    test('calculates correct GS1 Modulo 10 check digit', () {
      // Known GS1 test vector:
      // Payload: 09312345000000001
      // Weights (alternating 3 and 1):
      // 0*3 + 9*1 + 3*3 + 1*1 + 2*3 + 3*1 + 4*3 + 5*1 + 0*3 + 0*1 + 0*3 + 0*1 + 0*3 + 0*1 + 0*3 + 0*1 + 1*3
      // = 0 + 9 + 9 + 1 + 6 + 3 + 12 + 5 + 3 = 48 => 50 - 48 = 2
      final checkDigit = LpnService.calculateGs1CheckDigit('09312345000000001');
      expect(checkDigit, 2);
    });

    test('generates and validates SSCC-18 barcodes', () {
      final sscc = LpnService.generateSscc18(
        extensionDigit: 0,
        companyPrefix: '9312345',
        serialNumber: 1,
      );
      expect(sscc.length, 18);
      expect(LpnService.isValidSscc18(sscc), isTrue);
    });
  });

  group('Gs1BarcodeParser Tests', () {
    test('parses bracketed GS1 barcode with GTIN, Lot, Expiry, Weight, and SSCC', () {
      const barcode =
          '(01)09312345000017(10)LOT20261005(17)261012(3102)025600(21)SN987654(00)093123450000000012';
      final result = Gs1BarcodeParser.parse(barcode);

      expect(result.gtin, '09312345000017');
      expect(result.lotNumber, 'LOT20261005');
      expect(result.expiryDate, DateTime(2026, 10, 12));
      expect(result.netWeightKg, 256.0); // 025600 / 100
      expect(result.serialNumber, 'SN987654');
      expect(result.sscc, '093123450000000012');
    });

    test('parses linear GS1 barcode', () {
      const linear = '01093123450000171726101210LOT-M1-001';
      final result = Gs1BarcodeParser.parse(linear);

      expect(result.gtin, '09312345000017');
      expect(result.expiryDate, DateTime(2026, 10, 12));
      expect(result.lotNumber, 'LOT-M1-001');
    });
  });
}
