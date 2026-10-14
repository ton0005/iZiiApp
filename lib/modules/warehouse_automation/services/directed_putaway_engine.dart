import '../../../core/database/app_database.dart';
import '../../supply_chain/repository.dart';
import '../models/putaway_fefo_models.dart';

class DirectedPutawayEngine {
  final AppDatabase _db;
  final SupplyChainRepository _supplyRepo;

  DirectedPutawayEngine([AppDatabase? database, SupplyChainRepository? repo])
      : _db = database ?? AppDatabase(),
        _supplyRepo = repo ?? SupplyChainRepository(database);

  /// Computes the optimal 3D rack position for a pallet based on weight, velocity, and affinity
  Future<PutawayRecommendation?> calculateOptimalPutaway(String lpnCode) async {
    final pallet = await _supplyRepo.getLpnByCode(lpnCode);
    if (pallet == null) return null;

    final palletGrossWeight = pallet.grossWeightKg ?? 323.0;

    // Get LPN contents to extract product & lot for affinity rules
    final contents = await _supplyRepo.getLpnContents(pallet.id);
    final productId = contents.isNotEmpty ? contents.first.productId : null;
    final lotId = contents.isNotEmpty ? contents.first.lotId : null;

    // Fetch all active storable bin locations
    await _supplyRepo.seedDefaultWarehouseLocations();
    final allLocations = await (_db.select(_db.locations)
          ..where((tbl) => tbl.status.equals('active'))
          ..where((tbl) => tbl.isStorable.equals(true)))
        .get();

    // Filter only storage bins (exclude staging, dock, quarantine)
    final candidateBins = allLocations.where((l) =>
        l.type == 'bin' &&
        !l.code.contains('STAGING') &&
        !l.code.contains('GATE') &&
        !l.code.contains('QUARANTINE')).toList();

    if (candidateBins.isEmpty) return null;

    // Evaluate each bin
    PutawayRecommendation? bestRecommendation;
    double highestScore = -1.0;

    for (final bin in candidateBins) {
      // 1. Calculate current occupied weight at this bin
      final lpnsAtBin = await (_db.select(_db.stockLpns)
            ..where((tbl) => tbl.locationId.equals(bin.code))
            ..where((tbl) => tbl.status.equals('stored')))
          .get();

      final currentWeight = lpnsAtBin.fold<double>(
        0.0,
        (sum, l) => sum + (l.grossWeightKg ?? 0.0),
      );

      final maxBinWeight = bin.maxWeightKg ?? 1500.0;
      final remainingCapacity = maxBinWeight - currentWeight;

      // Structural safety check: skip if bin cannot support additional pallet weight
      if (palletGrossWeight > remainingCapacity) {
        continue;
      }

      // 2. Calculate Heuristic Score
      double score = 100.0;
      final reasons = <String>[];

      final isLevel1 = bin.code.endsWith('-L1') || (bin.posZ != null && bin.posZ! <= 0.5);

      // Rule A: Heavy Pallet to Floor Level (Level 1)
      if (palletGrossWeight >= 300.0) {
        if (isLevel1) {
          score += 60.0;
          reasons.add('Tải trọng nặng (${palletGrossWeight.toStringAsFixed(1)} kg) ưu tiên chân kệ Tầng 1');
        } else {
          score -= 40.0; // Penalize high tiers for heavy loads
        }
      } else {
        if (!isLevel1) {
          score += 20.0; // Lighter pallets can utilize upper tiers
          reasons.add('Tải trọng nhẹ (${palletGrossWeight.toStringAsFixed(1)} kg) tối ưu tầng cao');
        }
      }

      // Rule B: Velocity / Fast-Moving SKU Proximity
      if (bin.code.contains('A02') || bin.path.contains('A02')) {
        score += 35.0;
        reasons.add('Dãy A2 (Fast-Moving) gần cửa xuất hàng');
      }

      // Rule C: Batch / Lot Affinity
      bool hasLotAffinity = false;
      for (final existingLpn in lpnsAtBin) {
        final existingContents = await _supplyRepo.getLpnContents(existingLpn.id);
        if (existingContents.any((c) => c.productId == productId && c.lotId == lotId)) {
          hasLotAffinity = true;
          break;
        }
      }
      if (hasLotAffinity) {
        score += 45.0;
        reasons.add('Tập trung cùng Lô sản xuất với pallet hiện hữu');
      }

      // Rule D: Proximity bonus based on path depth
      score += (8 - bin.depth) * 2.0;

      if (score > highestScore) {
        highestScore = score;
        bestRecommendation = PutawayRecommendation(
          targetLocation: bin,
          score: score,
          slotReason: reasons.isNotEmpty ? reasons.join(' • ') : 'Vị trí kệ tiêu chuẩn sẵn sàng tiếp nhận',
          palletGrossWeightKg: palletGrossWeight,
          availableCapacityKg: remainingCapacity,
          currentOccupiedWeightKg: currentWeight,
          navigationPath: 'Kho Lạnh WH1 ➔ ${bin.path.replaceAll('/', ' ➔ ').trim()}',
        );
      }
    }

    return bestRecommendation;
  }
}
