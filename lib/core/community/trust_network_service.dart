import 'package:drift/drift.dart' as drift;
import '../database/app_database.dart';
import 'models/community_models.dart' as community;
import 'trust_score_calculator.dart';

class TrustNetworkService {
  static final TrustNetworkService _instance = TrustNetworkService._internal();
  factory TrustNetworkService() => _instance;
  TrustNetworkService._internal();

  final _db = AppDatabase();
  final _calculator = TrustScoreCalculator();

  Future<community.TrustScore> getTrustScore(String userId) async {
    final scores = await _db.select(_db.trustScores).get();
    final userScore = scores.firstWhere((s) => s.userId == userId,
        orElse: () => throw Exception('User score not found'));

    return community.TrustScore(
      userId: userScore.userId,
      overallScore: userScore.overallScore,
      referralCount: userScore.referralCount,
      referredBy: userScore.referredBy,
      completedOrders: userScore.completedOrders,
      avgRating: userScore.avgRating,
      memberSince: userScore.memberSince,
      level: community.TrustLevel.values.firstWhere(
        (e) => e.name == userScore.level,
        orElse: () => community.TrustLevel.newcomer,
      ),
      kycVerified: userScore.kycVerified,
    );
  }

  Future<void> initializeUserScore(String userId, {String? referredBy}) async {
    await _db.into(_db.trustScores).insert(TrustScoresCompanion.insert(
          userId: userId,
          referredBy: drift.Value(referredBy),
        ));

    // Recalculate
    await recalculateScore(userId);
  }

  Future<void> recalculateScore(String userId) async {
    final scores = await _db.select(_db.trustScores).get();
    final userScore = scores.firstWhere((s) => s.userId == userId);

    double referrerScoreValue = 0.0;
    if (userScore.referredBy != null) {
      try {
        final rScore =
            scores.firstWhere((s) => s.userId == userScore.referredBy);
        referrerScoreValue = rScore.overallScore;
      } catch (e) {
        // Referrer might be deleted
      }
    }

    final newScore = _calculator.calculate(
      userId: userId,
      isKycVerified: userScore.kycVerified,
      referralCount: userScore.referralCount,
      referrerScore: referrerScoreValue,
      completedOrders: userScore.completedOrders,
      avgRating: userScore.avgRating,
      memberSince: userScore.memberSince,
    );

    await _db.update(_db.trustScores).replace(userScore.copyWith(
          overallScore: newScore.overallScore,
          level: newScore.level.name,
        ));
  }

  Future<void> updateScoreAfterReview(String orderId, double rating) async {
    // 1. Get Reviewee
    final orders = await _db.select(_db.serviceOrders).get();
    final order = orders.firstWhere((o) => o.id == orderId);

    final scores = await _db.select(_db.trustScores).get();
    final scoreRecord = scores.firstWhere((s) => s.userId == order.providerId);

    // 2. Calculate new avg
    final newCompleted = scoreRecord.completedOrders + 1;
    final newAvg =
        ((scoreRecord.avgRating * scoreRecord.completedOrders) + rating) /
            newCompleted;

    await _db.update(_db.trustScores).replace(scoreRecord.copyWith(
          completedOrders: newCompleted,
          avgRating: newAvg,
        ));

    // 3. Recalculate full score
    await recalculateScore(order.providerId);
  }
}
