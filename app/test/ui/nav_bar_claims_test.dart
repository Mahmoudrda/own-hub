// A screen that is not a tab must not claim one.
//
// `AppNavBar` gives the active tab no `onTap` on purpose: a tab is not a link
// to itself. The consequence is easy to miss and impossible to see in a widget
// test of one screen: any screen that passes another screen's id draws a tab
// that looks available and does nothing. It shipped that way on Profile,
// Privacy, Progress, the whole of My cycle, the recipes list and the grocery
// list, and it was found by a person tapping Home on a settings screen and
// watching nothing happen.
//
// This is a source sweep rather than a widget test because the defect is one
// argument in a constructor, and the screens that have it render perfectly.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The flows the first release ships. A dark flow's screens cannot be reached,
/// so the same defect there is not yet a defect she can meet; add the folder
/// here on the release that switches the flow on.
const List<String> _shippingFeatures = [
  'today',
  'train',
  'eat',
  'cycle',
  'progress',
  'account',
];

/// The three tabs, and the one file each of them is.
const Map<String, String> _tabOwner = {
  'T01': 'today/presentation/today_view.dart',
  'R01': 'train/presentation/train_view.dart',
  'E01': 'eat/presentation/eat_view.dart',
};

void main() {
  test('only the tab itself claims the tab', () {
    final offenders = <String>[];
    final claim = RegExp(r"activeScreenId:\s*'([A-Z]\d{2})'");

    for (final feature in _shippingFeatures) {
      final dir = Directory('lib/features/$feature/presentation');
      if (!dir.existsSync()) continue;
      for (final file in dir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final relative = file.path.replaceFirst('lib/features/', '');
        for (final match in claim.allMatches(file.readAsStringSync())) {
          final claimed = match.group(1)!;
          final owner = _tabOwner[claimed];
          if (owner != null && owner != relative) {
            offenders.add('$relative claims $claimed');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Each of these draws the navigation bar telling it that another '
          'screen is the active tab, so that tab goes dead while looking '
          'available. A screen should name itself:\n  '
          '${offenders.join('\n  ')}',
    );
  });
}
