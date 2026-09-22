/// Z10 — Media library.
///
/// Its design note: "Bulk upload, then linked by filename to the ids the CSV
/// named. **The list leads with files linked to nothing**, because those are the
/// ones that will break a row at validation. Read requires a signed-in account:
/// this is a women-only product and the library sits behind the same gate."
///
/// So the screen is ordered by what will fail, exactly as Z01 is. A file nothing
/// references is the one that turns into a rejected row at Z09, and it is the
/// only thing here worth looking at first — which is why the filter **opens on
/// Unlinked** rather than on All, matching `segmented([...], 1)` in the design.
///
/// ## The filter, now that it can be labelled
///
/// It was withheld for a release: of `All · Unlinked · Videos · Photos` only two
/// existed, and a control offering half its options — the least useful half —
/// would have been worse than none. All four exist now.
///
/// ## The size column says "12 MB" now, as the design always drew it
///
/// It said `12,000,000` for a release, because there was no `MB` and no `KB` in
/// either dictionary and a raw byte count was the true thing this screen could
/// say. Both units exist now, and so does `File` for the column header, which
/// was `Name` for the same reason.
///
/// The units are decimal, not binary: the design draws "12 MB" for a
/// twelve-million-byte clip, and so does the file list on her phone. Below a
/// megabyte the figure is rounded **up**, so a small file is never reported as
/// "0 KB" — a size of zero reads as a failed upload, which is a different and
/// alarming claim.
///
/// ## Uploading needs a file picker, and there is none
///
/// `pubspec.yaml` has no picker package, so [MediaPicker] is the seam and
/// [UnavailableMediaPicker] is the only implementation. When it reports itself
/// unavailable this screen draws [AdminUnavailableAction] instead of the live
/// control: the same word, visibly not live, and announced as disabled. An
/// upload button that opened nothing would be worse than none — see the note on
/// that widget, and the sentence saying *why* is still missing from the
/// dictionary and is reported.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
// AppCardVariant arrives with AppListItem, which re-exports it.
import '../../../ui/app_list_item.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_segmented.dart';
import '../domain/media_bundle.dart';
import '../domain/media_picker.dart';
import 'admin_nav.dart';
import 'admin_widgets.dart';

/// The four the design names, in its order.
enum _Filter { all, unlinked, videos, photos }

class MediaLibraryView extends StatefulWidget {
  const MediaLibraryView({
    super.key,
    this.bundle = const MediaBundle([]),
    this.referenced = const {},
    this.picker,
    this.onUpload,
    this.onBack,
    this.onSelectTab,
  });

  /// What has been uploaded.
  final MediaBundle bundle;

  /// File names the imported rows name. Anything outside this set is unlinked.
  final Set<String> referenced;

  /// What would open the device's files, and whether anything can.
  ///
  /// Null means the caller is driving [onUpload] itself and has not said — the
  /// control is offered, as it was before this seam existed. An
  /// [UnavailableMediaPicker] is a caller saying plainly that nothing can be
  /// picked, and the screen draws that rather than a live-looking button.
  final MediaPicker? picker;

  final VoidCallback? onUpload;
  final VoidCallback? onBack;
  final ValueChanged<String>? onSelectTab;

  @override
  State<MediaLibraryView> createState() => _MediaLibraryViewState();
}

class _MediaLibraryViewState extends State<MediaLibraryView> {
  /// Opens on what will break, not on everything. See the file note.
  _Filter _filter = _Filter.unlinked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final unlinked = widget.bundle.unlinked(widget.referenced);
    final visible = _visible(unlinked);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(title: l10n.mediaLibrary, onBack: widget.onBack),
      bottomNavigationBar: AdminNavBar(
        activeScreenId: 'Z10',
        onSelect: widget.onSelectTab,
      ),
      body: AppScaffold(
        children: [
          AppListItem(
            leading: const Icon(
              Icons.add_photo_alternate,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: l10n.uploadVideosAndPictures,
            variant: AppCardVariant.filled,
            onTap: _canUpload ? widget.onUpload : null,
          ),

          // The action itself, stated in a word rather than only as a tappable
          // card — and withheld as live when there is no picker behind it.
          if (_canUpload)
            AppButton(
              l10n.upload,
              icon: Icons.upload,
              variant: AppButtonVariant.tonal,
              onPressed: widget.onUpload,
            )
          else
            AdminUnavailableAction(l10n.upload),

          AppSegmented(
            items: [l10n.all, l10n.unlinked, l10n.videos, l10n.photos],
            selectedIndex: _Filter.values.indexOf(_filter),
            onChanged: (index) =>
                setState(() => _filter = _Filter.values[index]),
          ),

          // The alarm, said only when there is something to be alarmed about,
          // and only while looking at the list it is about.
          if (_filter == _Filter.unlinked && unlinked.isNotEmpty)
            AppListItem(
              leading: const Icon(
                Icons.link_off,
                size: 24,
                color: AppColors.amber,
              ),
              title: l10n.notLinkedToAnythingYet,
              trailing: AppPill(
                countLabel(unlinked.length),
                background: AppColors.amberContainer,
                foreground: AppColors.amber,
              ),
              variant: AppCardVariant.amber,
            ),

          if (visible.isNotEmpty)
            AdminTable(
              startHeader: l10n.file,
              endHeader: l10n.size,
              // A file name and a size are both data, not copy.
              rows: [
                for (final file in visible)
                  (file.name, _sizeLabel(l10n, file.bytes)),
              ],
            ),
        ],
      ),
    );
  }

  /// Whether anything can actually be picked. See the note on [widget.picker].
  bool get _canUpload => widget.picker?.isAvailable ?? true;

  /// "12 MB", "840 KB". See the file note on why the units are decimal and why
  /// the small end rounds up.
  ///
  /// `countLabel`, never `NumberFormat`: under `ar` intl renders Eastern digits
  /// and `P0-A11Y-01` fails.
  String _sizeLabel(AppL10n l10n, int bytes) => bytes >= 1000000
      ? l10n.sizeMb(countLabel((bytes / 1000000).round()))
      : l10n.sizeKb(countLabel((bytes / 1000).ceil()));

  List<MediaFile> _visible(List<MediaFile> unlinked) => switch (_filter) {
    _Filter.all => widget.bundle.files,
    _Filter.unlinked => unlinked,
    _Filter.videos => widget.bundle.ofKind(MediaKind.video),
    _Filter.photos => widget.bundle.ofKind(MediaKind.picture),
  };
}
