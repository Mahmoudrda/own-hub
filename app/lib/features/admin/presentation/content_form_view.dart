/// Z03 and Z05 — adding or editing one row, as one screen.
///
/// D12 asked for meals and workouts to be addable "from within the app". Bulk
/// import is half of that and the half that scales; this is the other half, and
/// without it a single new food means editing a CSV and re-importing the
/// library.
///
/// The design draws two screens. They differ only in which collection they are
/// about, and [ContentSchema] already knows every column, which of them are
/// required and which carry a mandatory safety tag — so the form is **generated
/// from the contract** rather than typed out twice. The next column added to a
/// CSV appears on this screen without anyone editing this file, which is the
/// same reason `collection_view.dart` serves four browse screens.
///
/// ## Blank is not "none", and this screen is where that is taught
///
/// Z03's design note: *"The contraindication field shows its error state
/// deliberately. Blank and 'none' are different facts: the guard cannot tell an
/// untagged row from a safe one, so the importer refuses to create the ambiguity
/// rather than accepting it quietly."*
///
/// §3.2 is the rule; this is the rule at the point of authorship. The importer
/// already refuses a blank safety cell, and if this form did not, staff would
/// have a supported way to create exactly the row the importer exists to reject.
/// So a safety column carries "Write 'none' when there are none. Blank is not
/// the same thing." as its helper **before** the mistake, and as its error
/// after.
///
/// `none` itself gets no special handling anywhere in this file. It is ordinary
/// content, exactly as it is in [ContentSchema], and that is the point: the only
/// thing refused is the absence of an answer.
///
/// ## What it cannot label, it does not ask for
///
/// A field needs a label, and the dictionary does not have one for every column.
/// Rendering `carbsG` under an invented English word, or under the raw column
/// name, would be a defect this codebase has already fixed once —
/// `body_privately_view.dart` records the identical situation and the identical
/// answer: *"Shipping an Add control whose form cannot be labelled would mean
/// either an inert control or hardcoded English, and both are defects this
/// codebase has already fixed once."*
///
/// So [_labelFor] returns null for a column with no string, and that column is
/// **not drawn**. Every one of them is reported to the owner. The consequence is
/// worth naming precisely rather than burying:
///
///   * Z03 is **complete**. Every required exercise column — `exerciseId`,
///     `name_en`, `name_ar`, `contraindicationTags`, `quiet`, `floorOnly` — has
///     a label, so this screen can author an exercise the importer would accept.
///   * Z05 is **complete too, now**. `carbsG` and `fatG` were the two required
///     food columns with no label in either language: the fields were not
///     drawn, the values went out empty, and `validateImport` refused the row —
///     a form that looked like it worked and could not produce an importable
///     food. Both strings were minted and [_labelFor] gained its two cases.
///
///     Worth noting for whoever adds the next column: minting the string is
///     **half** the change. [_labelFor] is a hardcoded table, not a dynamic
///     lookup, so a column with a dictionary entry and no case here is still
///     invisible.
///
///   * **Z06 and Z07 are complete now too.** Recipes and programmes could not
///     be authored here *at all* — not partly: `recipeId` and `programId` are
///     the id columns, so neither form could state which row it was even about,
///     and `minutes`, `weeks`, `daysPerWeek` and `sessionLength` are all
///     `required: true`. Twelve strings were minted and [_labelFor] gained
///     twelve cases, and `content_form_view_test.dart` now authors one of each
///     and runs the real `validateImport` over it.
///
/// ## Saving emits, and something finally writes it
///
/// [onSave] carries the whole row as the CSV shapes it, and it still does not
/// write: a screen is the wrong place for the library's only writer.
/// `domain/content_repository.dart` is the writer now, and it takes exactly this
/// map — `ContentRepository.saveValues` reads the document id out of the
/// collection's id column, which is the same id the importer writes through, so
/// a row added here and a row imported from a file land on the same document
/// rather than on two.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_toggle.dart';
import '../domain/content_schema.dart';

/// Whole numbers, zero or more.
///
/// Deliberately the same shape as `import_validator.dart`'s `_wholeNumber`, and
/// for the same reason recorded there: Dart's `\d` is `[0-9]`, so Eastern Arabic
/// numerals do not match and are refused rather than silently misread. A form
/// that accepted "٤٣٠" and an importer that rejected it would disagree about the
/// same library.
final RegExp _wholeNumber = RegExp(r'^\d+$');

class ContentFormView extends StatefulWidget {
  const ContentFormView({
    super.key,
    required this.collection,
    this.values = const <String, String>{},
    this.onSave,
    this.onClose,
  });

  final ContentCollection collection;

  /// The row being edited, keyed by CSV column. Empty means this is a new row,
  /// which is the case D12 actually asked for.
  final Map<String, String> values;

  /// The whole row, in the shape the CSV gives it. Called only once every field
  /// this screen drew is acceptable.
  final ValueChanged<Map<String, String>>? onSave;

  final VoidCallback? onClose;

  @override
  State<ContentFormView> createState() => _ContentFormViewState();
}

class _ContentFormViewState extends State<ContentFormView> {
  final Map<String, TextEditingController> _text = {};
  final Map<String, bool> _flags = {};

  /// Keyed by column. Empty until she has tried to save — a form that turns red
  /// before she has typed anything is a form that tells her she is wrong for
  /// opening it.
  Map<String, String> _errors = const {};

  ContentSchema get _schema => ContentSchema.of(widget.collection);

  bool get _isEditing => widget.values.isNotEmpty;

  @override
  void initState() {
    super.initState();
    for (final column in _schema.columns) {
      final current = widget.values[column.name] ?? '';
      if (column.boolean) {
        // A new row starts false for both of the booleans that exist, and that
        // is the safe direction rather than a shrug: `quiet` false means the
        // move is NOT offered to a woman training in a flat with neighbours
        // below, and `floorOnly` false means it is not promised as a floor
        // move. A default that claimed either would put jumping into a quiet
        // programme.
        _flags[column.name] = current.toLowerCase() == 'true';
      } else {
        _text[column.name] = TextEditingController(text: current);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _text.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      appBar: AppTopBar(
        title: _title(l10n),
        // The design's `lead: 'close'`. This screen sits over the list it came
        // from, so closing returns her to it rather than walking a history.
        leadingIcon: Icons.close,
        onBack: widget.onClose,
      ),
      footer: [AppButton(l10n.save, onPressed: () => _save(l10n))],
      children: [
        for (final column in _schema.columns) ?_fieldFor(l10n, column),
      ],
    );
  }

  /// Null for a column this screen has no label for. See the file note.
  Widget? _fieldFor(AppL10n l10n, ContentColumn column) {
    final label = _labelFor(l10n, column.name);
    if (label == null) return null;

    if (column.boolean) {
      final value = _flags[column.name]!;
      return AppListItem(
        title: label,
        variant: AppCardVariant.filled,
        trailing: AppToggle(
          value: value,
          semanticLabel: label,
          onChanged: (next) => setState(() => _flags[column.name] = next),
        ),
        // The whole row is the target, not just the 52pt track.
        onTap: () => setState(() => _flags[column.name] = !value),
      );
    }

    return AppField(
      controller: _text[column.name],
      label: label,
      // Said before the mistake as well as after it. §3.2 is not an error
      // message, it is the rule the column is under.
      helper: column.safetyTag ? l10n.writeNoneWhenThereAreNoneBlank : '',
      errorText: _errors[column.name] ?? '',
      keyboardType: column.numeric ? TextInputType.number : null,
      textDirection: _directionFor(column),
    );
  }

  /// The label, or null when the dictionary has no word for this column.
  ///
  /// Every null here is a reported gap, listed in the file note. There is
  /// deliberately no fallback to the raw column name: a screen is copy, and
  /// `carbsG` is not a word in either of this product's languages.
  String? _labelFor(AppL10n l10n, String column) => switch (column) {
    'exerciseId' => l10n.exerciseId,
    'foodId' => l10n.foodId,
    'name_en' => l10n.nameEnglish,
    'name_ar' => l10n.nameArabic,
    'equipment' => l10n.equipment,
    'contraindicationTags' => l10n.contraindicationTags,
    'allergens' => l10n.allergens,
    'dietTags' => l10n.dietTags,
    'kcal' => l10n.kcal,
    'proteinG' => l10n.proteinG,
    // The two that kept Z05 from authoring a complete food. Both are
    // `required: true`, so without labels the fields were not drawn, the values
    // went out empty, and `validateImport` refused the row — a form that
    // looked like it worked and produced nothing importable.
    'carbsG' => l10n.carbsG,
    'fatG' => l10n.fatG,
    'quiet' => l10n.quiet,
    'floorOnly' => l10n.floorOnly,
    // Z06 and Z07's columns, and the two optional exercise ones. Every one of
    // these was unlabelled when this screen was written, which is why recipes
    // and programmes could not be authored here at all — not "partly", but not
    // at all: `recipeId` and `programId` are the id columns, so neither form
    // could state which row it was even about. All twelve strings exist now.
    'pattern' => l10n.pattern,
    'portions' => l10n.portions,
    'videoFile' => l10n.videoFile,
    'thumbFile' => l10n.thumbnail,
    'photoFile' => l10n.photoFile,
    'recipeId' => l10n.recipeId,
    'minutes' => l10n.minutes,
    'ingredients' => l10n.ingredients,
    'programId' => l10n.programmeId,
    'weeks' => l10n.weeks,
    'daysPerWeek' => l10n.daysAWeek,
    'sessionLength' => l10n.sessionLength,
    _ => null,
  };

  /// Some cells are one direction whatever the interface is set to.
  ///
  /// `name_ar` is Arabic content and reads right-to-left even while staff work
  /// in English; `name_en` and the id are Latin and stay left-to-right in
  /// Arabic, exactly as `AppField` documents for a phone field. A number is
  /// Western digits in both languages (`P0-A11Y-01`) and belongs with them.
  TextDirection? _directionFor(ContentColumn column) {
    if (column.name == 'name_ar') return TextDirection.rtl;
    if (column.name == 'name_en' ||
        column.name == _schema.idColumn ||
        column.numeric) {
      return TextDirection.ltr;
    }
    return null;
  }

  String _title(AppL10n l10n) {
    // "Edit an exercise" and "Edit a food" now exist, so the title can say
    // which. It also settles a disagreement worth noting: `app_routes.dart`
    // has always titled Z03 and Z05 with exactly these two phrases, while the
    // dictionary did not contain them — the route table and the screen called
    // themselves different things.
    //
    // D18 minted "Edit a recipe" and "Edit a programme" alongside Z12 and Z13,
    // so the fallback to a bare `Edit` is gone and every collection now names
    // what it is editing.
    //
    // The switch is exhaustive on purpose — no `_` arm. A fifth collection
    // added tomorrow fails to compile here, rather than quietly titling itself
    // "Edit" and looking finished.
    if (_isEditing) {
      return switch (widget.collection) {
        ContentCollection.exercises => l10n.editAnExercise,
        ContentCollection.foods => l10n.editAFood,
        ContentCollection.recipes => l10n.editARecipe,
        ContentCollection.programmes => l10n.editAProgramme,
      };
    }

    return switch (widget.collection) {
      ContentCollection.exercises => l10n.addAnExercise,
      ContentCollection.foods => l10n.addAFood,
      // Both exist now. They were the collection's own name for a release —
      // "Recipes" as the title of a screen adding one — which was true rather
      // than right.
      ContentCollection.recipes => l10n.addARecipe,
      ContentCollection.programmes => l10n.addAProgramme,
    };
  }

  void _save(AppL10n l10n) {
    final errors = <String, String>{};

    for (final column in _schema.columns) {
      // A column that was never drawn cannot be wrong — she was not given the
      // chance to fill it in, and failing her for it would make this screen
      // unusable rather than honest.
      if (_labelFor(l10n, column.name) == null) continue;
      if (column.boolean) continue;

      final value = _text[column.name]!.text.trim();

      if (value.isEmpty) {
        if (column.safetyTag) {
          // The distinction this whole console exists to protect.
          errors[column.name] = l10n.writeNoneWhenThereAreNoneBlank;
        } else if (column.required) {
          errors[column.name] = l10n.requiredLabel;
        }
        continue;
      }

      if (column.numeric && !_wholeNumber.hasMatch(value)) {
        errors[column.name] = l10n.checkTheNumberAndTryAgain;
      }
    }

    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;

    widget.onSave?.call(_collected());
  }

  /// The whole row, every column of the contract, in the CSV's own vocabulary.
  ///
  /// Total over [ContentSchema.columns] rather than over the fields drawn, for
  /// two reasons. A column this screen cannot label still has to survive an
  /// edit — dropping `carbsG` because there is no English word for it would
  /// turn opening this form into data loss. And a caller receiving the full
  /// column set can hand it straight to the same validator the importer uses,
  /// which is what makes a row authored here and a row imported from a file the
  /// same kind of thing.
  Map<String, String> _collected() {
    final row = <String, String>{
      for (final column in _schema.columns)
        column.name: column.boolean
            ? (_flags[column.name]! ? 'true' : 'false')
            : _text[column.name]!.text.trim(),
    };
    row.forEach((name, value) {
      if (value.isEmpty && _defaults[name] != null) row[name] = _defaults[name]!;
    });
    return row;
  }

  /// What a column is worth when nobody was asked for it.
  ///
  /// Four recipe columns are `required: true` and have no field on this screen,
  /// because none of them is a question to put to a member of staff: they are
  /// the state a newly authored row is *in*. Without a default, the form would
  /// produce a row its own importer refuses, which is precisely the defect the
  /// comment above `carbsG` records.
  ///
  /// Every value here is the cautious one. `review`, not `published`: nobody has
  /// signed its allergen set. `withheld`, not `computed`: its macros were never
  /// summed from verified foods. `free`, because nothing is sold. `none` for
  /// advisories, which is the safety vocabulary's way of saying somebody
  /// answered rather than somebody skipped.
  static const Map<String, String> _defaults = {
    'source': 'authored',
    'status': 'review',
    'macroBasis': 'withheld',
    'tier': 'free',
    'advisories': 'none',
  };
}
