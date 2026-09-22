/// `type → (label, icon, editor, starter payload)`, in one table.
///
/// G13 §1.2: *"Adding a fifteenth type is a registry entry plus a widget — no
/// route, no screen, no migration."* This is that registry. B02 reads it to
/// draw a row, B03 reads it to draw the add-a-section grid, and the renderer
/// reads it to pick a widget. None of the three has a switch on [BlockType] of
/// its own, which is what stops a new type needing three edits in three files.
///
/// ## Labels are getter names, not strings
///
/// The dictionary is generated and must not be hand-edited, and a widget may
/// never hardcode English. So a registry entry names the **l10n getter** it
/// reads, as a function from `AppL10n`. A type whose label has not been minted
/// carries a null label and B03 omits its tile — which is a visible gap rather
/// than an invented English word in front of an Arabic reader.
///
/// ## B03 shows twelve tiles, and the registry holds fourteen
///
/// `cover` and `about` are already on the starter page, so the grid lists the
/// other twelve. That is a property of [Portfolio.addableTypes] plus `cover`'s
/// cap of one — not a hardcoded list of twelve.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import 'portfolio_block.dart';

/// One row of the table.
@immutable
class BlockTypeEntry {
  const BlockTypeEntry({
    required this.type,
    required this.icon,
    required this.label,
    required this.starter,
    this.subtitle,
    this.editorScreenId,
  });

  final BlockType type;

  /// The glyph the mockup uses for this type.
  final IconData icon;

  /// The dictionary getter for the section's name.
  ///
  /// Null when the string has not been minted. The caller omits the element;
  /// it does not invent one.
  final String Function(AppL10n)? label;

  /// A one-line description under the name on B02, where one exists.
  final String Function(AppL10n)? subtitle;

  /// An empty payload of this type, for "add a section".
  final BlockPayload Function() starter;

  /// The screen that edits it. Null means the generic editor.
  final String? editorScreenId;

  String? labelOf(AppL10n l10n) => label?.call(l10n);
  String? subtitleOf(AppL10n l10n) => subtitle?.call(l10n);
}

/// The table. Declaration order is B03's grid order, which follows the mockup.
abstract final class BlockRegistry {
  static const Map<BlockType, BlockTypeEntry> entries =
      <BlockType, BlockTypeEntry>{
        BlockType.cover: BlockTypeEntry(
          type: BlockType.cover,
          icon: Icons.image,
          label: _coverLabel,
          subtitle: _coverSubtitle,
          starter: _coverStarter,
          editorScreenId: 'B04',
        ),
        BlockType.about: BlockTypeEntry(
          type: BlockType.about,
          icon: Icons.person,
          label: _aboutLabel,
          starter: _aboutStarter,
          editorScreenId: 'B04',
        ),
        BlockType.method: BlockTypeEntry(
          type: BlockType.method,
          icon: Icons.checklist,
          label: _methodLabel,
          starter: _methodStarter,
          editorScreenId: 'B07',
        ),
        BlockType.offers: BlockTypeEntry(
          type: BlockType.offers,
          icon: Icons.payments,
          label: _offersLabel,
          starter: _offersStarter,
          editorScreenId: 'B06',
        ),
        BlockType.results: BlockTypeEntry(
          type: BlockType.results,
          icon: Icons.trending_up,
          label: _resultsLabel,
          starter: _resultsStarter,
          editorScreenId: 'B08',
        ),
        BlockType.testimonials: BlockTypeEntry(
          type: BlockType.testimonials,
          icon: Icons.forum,
          label: _testimonialsLabel,
          starter: _testimonialsStarter,
        ),
        BlockType.video: BlockTypeEntry(
          type: BlockType.video,
          icon: Icons.videocam,
          label: _videoLabel,
          starter: _videoStarter,
          editorScreenId: 'B13',
        ),
        BlockType.gallery: BlockTypeEntry(
          type: BlockType.gallery,
          icon: Icons.photo_library,
          label: _galleryLabel,
          starter: _galleryStarter,
          editorScreenId: 'B13',
        ),
        BlockType.certificates: BlockTypeEntry(
          type: BlockType.certificates,
          icon: Icons.verified_user,
          label: _certificatesLabel,
          starter: _certificatesStarter,
        ),
        BlockType.faq: BlockTypeEntry(
          type: BlockType.faq,
          icon: Icons.help,
          label: _faqLabel,
          starter: _faqStarter,
        ),
        BlockType.availability: BlockTypeEntry(
          type: BlockType.availability,
          icon: Icons.schedule,
          label: _availabilityLabel,
          starter: _availabilityStarter,
        ),
        BlockType.freebie: BlockTypeEntry(
          type: BlockType.freebie,
          icon: Icons.menu_book,
          label: _freebieLabel,
          starter: _freebieStarter,
        ),
        BlockType.numbers: BlockTypeEntry(
          type: BlockType.numbers,
          icon: Icons.bar_chart,
          label: _numbersLabel,
          starter: _numbersStarter,
        ),
        BlockType.cta: BlockTypeEntry(
          type: BlockType.cta,
          icon: Icons.send,
          label: _ctaLabel,
          starter: _ctaStarter,
        ),
      };

  static BlockTypeEntry of(BlockType type) => entries[type]!;

  /// Every type, in registry order.
  static List<BlockTypeEntry> get all =>
      List.unmodifiable(BlockType.values.map(of));

  /// The tiles B03 draws for [addable], skipping any type whose label has not
  /// been minted.
  static List<BlockTypeEntry> tilesFor(
    Iterable<BlockType> addable,
    AppL10n l10n,
  ) => List.unmodifiable(addable.map(of).where((e) => e.labelOf(l10n) != null));
}

// The dictionary getters, named once. A tear-off keeps the table const.
String _coverLabel(AppL10n l) => l.cover;
String _coverSubtitle(AppL10n l) => l.photoHeadlineOneLine;
String _aboutLabel(AppL10n l) => l.whoIAm;
String _methodLabel(AppL10n l) => l.howIWork;
String _offersLabel(AppL10n l) => l.whatIOffer;
String _resultsLabel(AppL10n l) => l.clientResults;
String _testimonialsLabel(AppL10n l) => l.whatTheySaid;
String _videoLabel(AppL10n l) => l.video;
String _galleryLabel(AppL10n l) => l.gallery;
String _certificatesLabel(AppL10n l) => l.certificates;
String _faqLabel(AppL10n l) => l.questions;
String _availabilityLabel(AppL10n l) => l.whenIAmFree;
String _freebieLabel(AppL10n l) => l.somethingFree;
String _numbersLabel(AppL10n l) => l.numbers;
String _ctaLabel(AppL10n l) => l.askMe;

BlockPayload _coverStarter() =>
    const CoverPayload(layout: CoverLayout.textOverPhoto);
BlockPayload _aboutStarter() => const AboutPayload();
BlockPayload _methodStarter() => const MethodPayload();
BlockPayload _offersStarter() => const OffersPayload();
BlockPayload _resultsStarter() => const ResultsPayload();
BlockPayload _testimonialsStarter() => const TestimonialsPayload();
BlockPayload _videoStarter() => const VideoPayload(mediaId: '');
BlockPayload _galleryStarter() => const GalleryPayload();
BlockPayload _certificatesStarter() => const CertificatesPayload();
BlockPayload _faqStarter() => const FaqPayload();
BlockPayload _availabilityStarter() => const AvailabilityPayload();
BlockPayload _freebieStarter() => const FreebiePayload();
BlockPayload _numbersStarter() => const NumbersPayload();
BlockPayload _ctaStarter() => const CtaPayload();
