import 'dart:math';
import '../database/app_database.dart';
import 'models/community_models.dart' as community;
import 'trust_network_service.dart';
import '../sync/sharing_repository.dart';

class MatchResult {
  final String providerId;
  final String providerName;
  final String serviceListingId;
  final double matchScore;
  final double distanceKm;
  final community.TrustScore trustScore;

  MatchResult({
    required this.providerId,
    required this.providerName,
    required this.serviceListingId,
    required this.matchScore,
    required this.distanceKm,
    required this.trustScore,
  });
}

class MatchingEngine {
  static final MatchingEngine _instance = MatchingEngine._internal();
  factory MatchingEngine() => _instance;
  MatchingEngine._internal();

  final _db = AppDatabase();

  Future<List<MatchResult>> findProviders({
    required String serviceType,
    String? location,
    double? maxBudget,
    String? visitorId,
  }) async {
    final listings = await _db.select(_db.serviceListings).get();
    final sharingRepo = SharingRepository();

    // Filter by availability, service type and visibility permissions
    final matchedListings = <ServiceListing>[];
    for (var l in listings) {
      if (!l.isAvailable) continue;
      if (l.serviceType.toLowerCase() != serviceType.toLowerCase()) continue;

      if (visitorId != null) {
        final hasPerm = await sharingRepo.hasPermission(
          userId: visitorId,
          recordType: 'services',
          recordId: l.id,
          requiredLevel: 'view',
        );
        if (!hasPerm) continue;
      } else {
        if (l.visibility != 'community') continue;
      }
      matchedListings.add(l);
    }

    final results = <MatchResult>[];
    final users = await _db.select(_db.users).get();

    for (var listing in matchedListings) {
      // 1. Check budget if specified
      if (maxBudget != null && listing.priceMin != null) {
        if (listing.priceMin! > maxBudget) continue;
      }

      // 2. Location & Distance (mock distance for now)
      final distance = (Random().nextDouble() * 10); // Mock 0-10km

      // 3. Trust Score
      final trustScore =
          await TrustNetworkService().getTrustScore(listing.providerId);

      // 4. Provider Name
      final providerUser = users.firstWhere((u) => u.id == listing.providerId,
          orElse: () => throw Exception('User not found'));

      // 5. Calculate Match Score
      // Trọng số:
      // - Trust Score: 40% (max 2.0 / 5.0)
      // - Khoảng cách: 30% (càng gần càng tốt)
      // - Giá cả: 20%
      // - Đánh giá dịch vụ cụ thể: 10%

      double score = 0.0;

      // Trust component
      score += (trustScore.overallScore / 5.0) * 40;

      // Distance component (0km = 30 pts, 10km = 0 pts)
      score += max(0, 30 - (distance * 3));

      // Rating component
      score += (listing.rating / 5.0) * 10;

      // Bonus: 20pts base for matching the service type exactly
      score += 20;

      results.add(MatchResult(
        providerId: listing.providerId,
        providerName: providerUser.name,
        serviceListingId: listing.id,
        matchScore: score,
        distanceKm: distance,
        trustScore: trustScore,
      ));
    }

    // Sắp xếp theo matchScore giảm dần
    results.sort((a, b) => b.matchScore.compareTo(a.matchScore));

    return results;
  }
}
