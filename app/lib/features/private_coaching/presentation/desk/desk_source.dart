/// Where the desk's screens read from: the coach's streams held by
/// [PrivateCoachingState], joined once per build into a [DeskModel].
library;

import '../../../../app_state/private_coaching_state.dart';
import 'desk_model.dart';

extension DeskSource on PrivateCoachingState {
  DeskModel deskModel(DateTime now) => DeskModel.build(
    subscriptions: coachSubscriptions,
    relationships: coachRelationships,
    myUid: repository?.uid,
    now: now,
  );
}
