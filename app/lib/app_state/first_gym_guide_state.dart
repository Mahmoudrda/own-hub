/// Whether she has been offered "First time at the gym?".
///
/// Once, before her first session at a gym, whether she read it or skipped it.
/// It lives in her snapshot, so it is gone with everything else when she
/// deletes her data, and it never leaves the phone.
library;

class FirstGymGuideState {
  FirstGymGuideState._();

  static final FirstGymGuideState instance = FirstGymGuideState._();

  /// The guide has been shown, finished or skipped.
  bool seen = false;

  /// Account deletion and sign-out.
  void reset() => seen = false;
}
