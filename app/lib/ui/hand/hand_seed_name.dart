/// The name a widget gives the card it sits in, for that card's sketch.
///
/// A card is seeded from what it holds (`handSeedForChildren`), so the same
/// card is drawn the same way on every visit. That seed used to read each
/// child's `runtimeType.toString()`. Release builds are obfuscated, where the
/// name of a type is a minified token that changes from build to build: cards
/// would have looked different from debug, and from one release to the next.
///
/// So the name is written down instead. Flutter's own widgets are recognised
/// with `is` checks in [handSeedNameOf]; the app's widgets that sit directly
/// in a card implement [HandSeedName] and return their own class name as a
/// string literal, which no obfuscator touches. Anything else draws with
/// [kHandSeedFallbackName].
library;

import 'package:flutter/widgets.dart';

/// A widget that names itself for the card seed. Return the class name as a
/// literal, so the card draws the same as it always has.
abstract interface class HandSeedName {
  String get handSeedName;
}

/// The name used for a child nobody named.
const String kHandSeedFallbackName = 'Widget';

/// The name [child] contributes to its card's seed. Never reads a type name.
String handSeedNameOf(Widget child) {
  if (child is HandSeedName) return (child as HandSeedName).handSeedName;
  // Subclasses before the classes they extend: Center is an Align and
  // Expanded is a Flexible.
  if (child is Text) return 'Text';
  if (child is Row) return 'Row';
  if (child is Column) return 'Column';
  if (child is Wrap) return 'Wrap';
  if (child is Builder) return 'Builder';
  if (child is SizedBox) return 'SizedBox';
  if (child is Padding) return 'Padding';
  if (child is Icon) return 'Icon';
  if (child is Center) return 'Center';
  if (child is Align) return 'Align';
  if (child is Directionality) return 'Directionality';
  if (child is Expanded) return 'Expanded';
  if (child is Flexible) return 'Flexible';
  if (child is Stack) return 'Stack';
  if (child is Container) return 'Container';
  if (child is Image) return 'Image';
  if (child is GestureDetector) return 'GestureDetector';
  return kHandSeedFallbackName;
}
