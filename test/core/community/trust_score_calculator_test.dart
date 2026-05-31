import 'package:izii_app/core/community/models/community_models.dart';
import 'package:izii_app/core/community/trust_score_calculator.dart';
import 'package:test/test.dart';

void main() {
  group('TrustScoreCalculator', () {
    test('keeps a brand-new unverified user at newcomer level', () {
      final score = TrustScoreCalculator().calculate(
        userId: 'user-new',
        isKycVerified: false,
        referralCount: 0,
        referrerScore: 0,
        completedOrders: 0,
        avgRating: 0,
        memberSince: DateTime.now(),
      );

      expect(score.overallScore, 0);
      expect(score.level, TrustLevel.newcomer);
    });

    test('promotes a verified active provider to elite level', () {
      final score = TrustScoreCalculator().calculate(
        userId: 'provider-elite',
        isKycVerified: true,
        referralCount: 10,
        referrerScore: 5,
        completedOrders: 50,
        avgRating: 5,
        memberSince: DateTime.now().subtract(const Duration(days: 365)),
      );

      expect(score.overallScore, 5);
      expect(score.level, TrustLevel.elite);
    });
  });
}
