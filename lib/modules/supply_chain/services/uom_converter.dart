/// Utility class for Multi-Unit of Measure (UoM) conversions across supply chain entities.
class UomConverter {
  /// Converts a [quantity] from one unit to another using their respective ratios to the base unit.
  /// Example:
  ///   Base unit: Kg (ratio = 1.0)
  ///   Box: 4 Kg (ratio = 4.0)
  ///   Pallet: 288 Kg (ratio = 288.0)
  /// Convert 2 Pallets to Boxes: convert(quantity: 2, fromRatio: 288.0, toRatio: 4.0) => 144 Boxes.
  static double convert({
    required double quantity,
    required double fromRatio,
    required double toRatio,
  }) {
    if (toRatio == 0) {
      throw ArgumentError('Target UoM ratio cannot be zero.');
    }
    final baseQuantity = quantity * fromRatio;
    return baseQuantity / toRatio;
  }

  /// Converts a given [quantity] to base units.
  static double toBaseQuantity({
    required double quantity,
    required double ratioToBase,
  }) {
    return quantity * ratioToBase;
  }

  /// Converts a given [baseQuantity] into the target unit.
  static double fromBaseQuantity({
    required double baseQuantity,
    required double ratioToBase,
  }) {
    if (ratioToBase == 0) {
      throw ArgumentError('Target UoM ratio cannot be zero.');
    }
    return baseQuantity / ratioToBase;
  }

  /// Decomposes a total count of base packages (e.g., total boxes) into a human-readable breakdown:
  /// (e.g., "3 Pallets, 12 Boxes, 4 Units").
  static Map<String, int> decomposePackaging({
    required int totalUnits,
    required int unitsPerBox,
    required int boxesPerPallet,
  }) {
    if (unitsPerBox <= 0 || boxesPerPallet <= 0) {
      return {'pallets': 0, 'boxes': 0, 'units': totalUnits};
    }

    final unitsPerPallet = unitsPerBox * boxesPerPallet;
    final pallets = totalUnits ~/ unitsPerPallet;
    final remainingAfterPallets = totalUnits % unitsPerPallet;

    final boxes = remainingAfterPallets ~/ unitsPerBox;
    final units = remainingAfterPallets % unitsPerBox;

    return {
      'pallets': pallets,
      'boxes': boxes,
      'units': units,
    };
  }
}
