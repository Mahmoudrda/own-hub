/// Price maths, the same integer arithmetic as `functions/coaching/common.py`.
///
/// Whole pounds only. Never use doubles here: 1.15 is not exact in binary and
/// the server and the app must agree to the pound.
library;

import 'coaching_contract.dart';

/// What the client pays for a coach price: coach price plus the margin,
/// rounded half up.
int finalPrice(int coachPriceEgp) =>
    (coachPriceEgp * (100 + CoachingLimits.marginPercent) + 50) ~/ 100;

/// Whether [coachPriceEgp] is a price a coach may set.
bool coachPriceInRange(int coachPriceEgp) =>
    coachPriceEgp >= CoachingLimits.coachPriceMinEgp &&
    coachPriceEgp <= CoachingLimits.coachPriceMaxEgp;

/// Live sessions in a whole package.
int sessionsIncluded(int liveSessionsPerMonth, int durationDays) =>
    liveSessionsPerMonth * durationDays ~/ 28;

/// What she gets back when she cancels inside the window: the price less the
/// share of live sessions already held.
int refundAmount(int priceFinalEgp, int sessionsUsed, int included) {
  if (included <= 0) return 0;
  final used = sessionsUsed.clamp(0, included);
  return priceFinalEgp - (priceFinalEgp * used) ~/ included;
}

/// What the coach is still owed after a refund.
int coachShareAfterRefund(int coachPriceEgp, int sessionsUsed, int included) {
  if (included <= 0) return 0;
  final used = sessionsUsed.clamp(0, included);
  return (coachPriceEgp * used) ~/ included;
}

/// The price of 28 days, for comparing packages of different lengths.
int monthlyEquivalent(int priceFinalEgp, int durationDays) =>
    priceFinalEgp * 28 ~/ durationDays;
