import 'models/community_models.dart' as community;

class TrustScoreCalculator {
  /// Tính toán điểm tin cậy dựa trên các tiêu chí
  community.TrustScore calculate({
    required String userId,
    required bool isKycVerified,
    required int referralCount,
    required double referrerScore, // Điểm của người giới thiệu
    required int completedOrders,
    required double avgRating,
    required DateTime memberSince,
  }) {
    double score = 0.0;

    // 1. KYC Base Score (max 1.0)
    if (isKycVerified) score += 1.0;

    // 2. Account Age (max 0.5)
    final ageInDays = DateTime.now().difference(memberSince).inDays;
    score += (ageInDays / 365).clamp(0.0, 0.5);

    // 3. Referral Quality (max 1.0)
    // Hưởng lợi 30% từ điểm của người giới thiệu
    if (referrerScore > 0) {
      score += (referrerScore * 0.2);
    }
    // Căn cứ vào số lượng người mình giới thiệu (tối đa 0.5 điểm)
    score += (referralCount * 0.1).clamp(0.0, 0.5);

    // 4. Rating & Order Completion (max 2.0)
    if (completedOrders > 0) {
      score += (avgRating / 5.0) * 1.5;
      score += (completedOrders / 50).clamp(0.0, 0.5); // Thưởng kinh nghiệm
    }

    final finalScore = score.clamp(0.0, 5.0);

    return community.TrustScore(
      userId: userId,
      overallScore: finalScore,
      kycVerified: isKycVerified,
      referralCount: referralCount,
      completedOrders: completedOrders,
      avgRating: avgRating,
      memberSince: memberSince,
      level: _getLevelForScore(finalScore),
    );
  }

  community.TrustLevel _getLevelForScore(double score) {
    if (score >= 4.0) return community.TrustLevel.elite;
    if (score >= 3.0) return community.TrustLevel.verified;
    if (score >= 1.5) return community.TrustLevel.trusted;
    return community.TrustLevel.newcomer;
  }
}
