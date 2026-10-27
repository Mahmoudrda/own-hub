// Generates the Flutter handoff: design tokens, route table, ARB localisation files.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { all, flows } from './all-screens.mjs';
import { C, TY, R, M, BRAND, ALIAS, SPACE, ICON_SIZE } from './tokens.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(here, '../flutter');
fs.mkdirSync(OUT, { recursive: true });

const dartColor = (hex) => `Color(0xFF${hex.replace('#', '').toUpperCase()})`;
const colorLines = Object.entries(C).filter(([, v]) => /^#([0-9a-f]{6})$/i.test(v)).map(([k, v]) => `  static const ${k} = ${dartColor(v)};`).join('\n');
const brandLines = Object.entries(BRAND).map(([k, v]) => `  static const ${k} = ${dartColor(v)};`).join('\n');
const aliasLines = Object.entries(ALIAS).map(([k, v]) => `  static const ${k} = ${v};`).join('\n');
const spaceLines = SPACE.map((v) => `  static const s${v} = ${v}.0;`).join('\n');
const iconLines = ICON_SIZE.map((v) => `  static const s${v} = ${v}.0;`).join('\n');
// petrolDark at 6% and 8%, as straight ARGB so the shadows stay const.
const petrolShadow = (pct) => `Color(0x${Math.round(pct * 2.55).toString(16).toUpperCase().padStart(2, '0')}${C.ink.replace('#', '').toUpperCase()})`;
const textLines = Object.entries(TY).map(([k, [size, lh, w]]) => `  static const ${k} = TextStyle(fontFamily: _family, fontSize: ${size}, height: ${(lh / size).toFixed(3)}, fontWeight: FontWeight.w${w});`).join('\n');
const radiusLines = Object.entries(R).map(([k, v]) => `  static const ${k} = ${v}.0;`).join('\n');
const motionLines = Object.entries(M).filter(([, v]) => typeof v === 'number').map(([k, v]) => `  static const ${k} = Duration(milliseconds: ${v});`).join('\n');

fs.writeFileSync(path.join(OUT, 'app_tokens.dart'), `// GENERATED from 6-v2/src/tokens.mjs — do not edit by hand.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
${colorLines}

${brandLines}

${aliasLines}
}

class AppSpace {
${spaceLines}
}

class AppIconSize {
${iconLines}
}

class AppShadow {
  static const List<BoxShadow> none = <BoxShadow>[];
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(color: ${petrolShadow(6)}, blurRadius: 3, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> raised = <BoxShadow>[
    BoxShadow(color: ${petrolShadow(8)}, blurRadius: 8, offset: Offset(0, 2)),
  ];
}

class AppText {
  static const _family = 'Rubik';
${textLines}
}

class AppRadius {
${radiusLines}
}

class AppMotion {
${motionLines}
  static const emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const decelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const accelerate = Cubic(0.3, 0.0, 0.8, 0.15);
  static const spring = Cubic(0.34, 1.56, 0.64, 1.0);
}

ThemeData buildTheme(Locale locale) => ThemeData(
      useMaterial3: true,
      fontFamily: 'Rubik',
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        tertiaryContainer: AppColors.tertiaryContainer,
        onTertiaryContainer: AppColors.onTertiaryContainer,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: AppColors.onErrorContainer,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        surfaceContainerLowest: AppColors.surfaceLowest,
        surfaceContainerLow: AppColors.surfaceLow,
        surfaceContainer: AppColors.surfaceContainer,
        surfaceContainerHigh: AppColors.surfaceHigh,
        surfaceContainerHighest: AppColors.surfaceHighest,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
        inverseSurface: AppColors.inverseSurface,
        onInverseSurface: AppColors.inverseOnSurface,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w700),
        displayMedium: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w700),
        displaySmall: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w700),
        headlineLarge: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w700),
        headlineSmall: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w700),
      ),
      scaffoldBackgroundColor: AppColors.surface,
      // Dark status-bar content, always.
      //
      // Nothing set this, and AppBar derives the status-bar style from its own
      // background colour when none is given. Both of this product's top bars
      // are deliberately transparent, so most screens asked iOS for LIGHT
      // status-bar content and drew a near-white clock, wifi and battery on the
      // pale surface colour. Unreadable, on most screens in the app, and
      // invisible to every widget test — a screenshot caught it.
      //
      // statusBarBrightness describes the BACKGROUND (light, so iOS draws dark
      // text); statusBarIconBrightness describes the ICONS (dark, for Android).
      // They read as contradictory and are not.
      appBarTheme: const AppBarTheme(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
    );
`);

const routeName = (s) => '/' + s.flow + '/' + s.id.toLowerCase();
const routeLines = all.map(s => `  '${s.id}': AppRoute(name: '${routeName(s)}', flow: '${s.flow}', title: ${JSON.stringify(s.title)}),`).join('\n');
fs.writeFileSync(path.join(OUT, 'app_routes.dart'), `// GENERATED from 6-v2/src/inventory.mjs — one entry per mockup screen.
class AppRoute {
  final String name;
  final String flow;
  final String title;
  const AppRoute({required this.name, required this.flow, required this.title});
}

/// ${all.length} screens across ${flows.length} flows.
const Map<String, AppRoute> appRoutes = {
${routeLines}
};
`);

// ARB files, if the dictionary exists
const dictPath = path.join(here, '../i18n/ar.json');
if (fs.existsSync(dictPath)) {
  const dict = JSON.parse(fs.readFileSync(dictPath, 'utf8'));
  // Semantic ARB keys, derived from the English source string. A hash like
  // "s4nkxmp" compiles perfectly well, but nobody reading a screen can tell what
  // it renders, which makes 1,789 strings unreviewable and leaves QA unable to
  // spot-check a translation. The key is the only documentation a getter gets.
  const RESERVED = new Set([
    'assert', 'break', 'case', 'catch', 'class', 'const', 'continue', 'default', 'do', 'else',
    'enum', 'extends', 'false', 'final', 'finally', 'for', 'if', 'in', 'is', 'new', 'null',
    'rethrow', 'return', 'super', 'switch', 'this', 'throw', 'true', 'try', 'var', 'void',
    'while', 'with', 'abstract', 'as', 'covariant', 'deferred', 'dynamic', 'export', 'external',
    'factory', 'get', 'set', 'implements', 'import', 'interface', 'late', 'library', 'mixin',
    'on', 'operator', 'part', 'required', 'static', 'sync', 'typedef', 'yield', 'await', 'async',
    'base', 'sealed', 'show', 'hide', 'when',
    // These would collide with Object members or gen_l10n's own fields on the
    // generated class, which fails to compile rather than failing visibly.
    'toString', 'hashCode', 'runtimeType', 'noSuchMethod', 'localeName',
  ]);
  const slugFor = (s) => {
    const words = String(s)
      .replace(/['’]/g, '')
      .replace(/[^A-Za-z0-9]+/g, ' ')
      .trim().split(/\s+/).filter(Boolean).slice(0, 7);
    let k = words.map((w, i) => {
      const l = w.toLowerCase();
      return i === 0 ? l : l[0].toUpperCase() + l.slice(1);
    }).join('');
    if (!k) return null;                     // no Latin characters to name it by
    if (!/^[A-Za-z]/.test(k)) k = 'n' + k;   // a Dart getter must start with a letter
    if (RESERVED.has(k)) k += 'Label';
    return k.slice(0, 48);
  };
  // A short, stable fingerprint of the source string. Used to disambiguate, so a
  // key never depends on where a string happens to sit in the dictionary.
  const fingerprint = (s) => [...String(s)]
    .reduce((h, ch) => (h * 31 + ch.charCodeAt(0)) >>> 0, 7).toString(36).slice(0, 5);
  const taken = new Set();
  const uniqueKey = (base, src) => {
    // Strings with no Latin characters (an Arabic sample shown identically in both
    // locales, for instance) get a named fingerprint rather than the useless
    // catch-all the first version produced.
    let k = base === null ? `arabicText_${fingerprint(src)}` : base;
    // Collisions are resolved by fingerprinting the SOURCE, never by a positional
    // counter: 'Train' and 'train' slug alike, and an order-assigned _2 would
    // silently repoint to the other string if the dictionary were ever reordered.
    if (taken.has(k)) k = `${k}_${fingerprint(src)}`;
    while (taken.has(k)) k = `${k}x`;
    taken.add(k);
    return k;
  };
  // Placeholders. A message carrying {name} or a plural REQUIRES an "@key"
  // metadata block declaring each placeholder's type — Flutter's gen_l10n will
  // not infer it. Without this the dictionary can only ever ship frozen sample
  // data: "You're in, Mai" instead of her name.
  //
  // Declared here, keyed by the ENGLISH SOURCE STRING, because that is what the
  // dictionary is keyed by. The generated key is derived, so listing keys would
  // break the moment a slug changed.
  const PARAMETERISED = {
    "{weight} kg": {"description": "A weight or a weight change on P05, e.g. −2.5 kg. weight is already signed and in Western digits.", "placeholders": {"weight": {"type": "String", "example": "−2.5"}}},
    "Send it again in {time}": {"description": "C07, while the resend waits after a code was sent. time is minutes:seconds in Western digits, e.g. 0:27.", "placeholders": {"time": {"type": "String", "example": "0:27"}}},
    '{amount} EGP': {
      description:
        'A price. Every other EGP string in the dictionary bakes a sample ' +
        'figure into the sentence, so a one-off package had no way to state ' +
        'its own price and rendered none at all.',
      placeholders: { amount: { type: 'String', example: '1,800' } },
    },
    'Under {n} EGP': {
      description:
        "H01's price-band facet. `under2000Egp` bakes 2,000, so the chip " +
        'was absent from the directory even though the filter behind it works.',
      placeholders: { n: { type: 'String', example: '2,000' } },
    },
    '{size} MB': {
      description:
        "Z10's media library. The file size, which the screen currently shows "
        + 'as a raw byte count — 12,000,000 — because no unit string existed. '
        + 'True, Western-digit, and harder to read than the design intends.',
      placeholders: { size: { type: 'String', example: '12' } },
    },
    '{size} KB': {
      description: "Z10's media library, for a file under a megabyte.",
      placeholders: { size: { type: 'String', example: '840' } },
    },
    '{n} rows ready': {
      description:
        "Z09's dry-run summary. Deliberately its own string rather than `{n} "
        + "rows`: the admin console avoided that one here because it renders "
        + '"1 rows" in the commonest case of all, a single-row fix.',
      placeholders: { n: { type: 'String', example: '118' } },
    },
    'Week {week} of {total}': {
      description:
        "T01's workout badge and R01's programme header. The worst of the "
        + 'remaining baked-in samples: `week3Of8` states "Week 3 of 8" to every '
        + 'woman, and `train_view` uses it as a FALLBACK '
        + '(`programWeek ?? week3Of8`) — so it asserts a week precisely when '
        + 'the real one is unknown, which is the one moment it should say '
        + 'nothing.',
      placeholders: {
        week: { type: 'String', example: '3' },
        total: { type: 'String', example: '8' },
      },
    },
    'Walk this morning · {minutes} min': {
      description:
        "T01's walk card. Her phone counted the minutes; the card stated 32 "
        + 'regardless. The undo bar quotes this same line, so the number she is '
        + 'offered a chance to take back has to be the number she walked.',
      placeholders: { minutes: { type: 'String', example: '32' } },
    },
    '{kcal} kcal': {
      description:
        "T01's meal-card chips and E06's recipe facts. A TOTAL, never a "
        + 'countdown, and never a remainder — G5 §1.5. The fixed `n410Kcal` and '
        + '`n290Kcal` named the mockup\'s breakfast whatever she had eaten.',
      placeholders: { kcal: { type: 'String', example: '410' } },
    },
    '{label} {value} cm': {
      description:
        'P04 measurement chips. The label is Waist/Hips/Arm/Thigh and the value '
        + 'is hers. Withheld entirely until now: the four labels did not exist, '
        + 'so the add control could not be drawn and the chips were display-only.',
      placeholders: {
        label: { type: 'String', example: 'Waist' },
        value: { type: 'String', example: '82' },
      },
    },
    '{weight} kg saved': {
      description:
        "P04's undo bar. Must name the weight SHE saved. The screen previously "
        + 'used the bare word "Saved", which is true of every measurement and '
        + 'therefore tells her nothing about the one she can still take back.',
      placeholders: { weight: { type: 'String', example: '63.5' } },
    },
    'Period day {day}': {
      description:
        'Y03/Y11. `periodDay2` bakes the mockup\'s day two into the sentence, so '
        + 'the hub rendered the bare number for every other day rather than lie. '
        + 'This is the form that lets the sentence be true on any day.',
      placeholders: { day: { type: 'String', example: '2' } },
    },
    '{logged} of {total} noted days': {
      description:
        "Y10's chart caption. The fixed string named the mockup's 4 of 6, so the "
        + 'caption was withheld and the chart drew with no sentence beside it.',
      placeholders: {
        logged: { type: 'String', example: '4' },
        total: { type: 'String', example: '6' },
      },
    },
    'Level {n}': {
      description:
        "P01 and T01. `level7Regular` freezes the mockup's level 7 into the "
        + 'pill, so it announced level 7 to a woman on level 1.',
      placeholders: { n: { type: 'String', example: '7' } },
    },
    '{count} of {total}': {
      description:
        'P02 milestones and P03 bests — the generic "4 of 12" the counted-weeks '
        + 'and bests tiles need. Both previously rendered nothing rather than a '
        + "constant, which is why P02's heading does not appear.",
      placeholders: {
        count: { type: 'String', example: '4' },
        total: { type: 'String', example: '12' },
      },
    },
    '{n} rows': {
      description:
        "Z01 collection subtitles and Z09's row count. `CollectionStatus.rows` "
        + 'is already carried for exactly this and was never rendered.',
      placeholders: { n: { type: 'String', example: '118' } },
    },
    '+{n} kg': {
      description: 'P03 personal-best delta. Hers, not a sample.',
      placeholders: { n: { type: 'String', example: '2.5' } },
    },
    '+{n} reps': {
      description: 'P03 personal-best delta, repetitions.',
      placeholders: { n: { type: 'String', example: '3' } },
    },
    '+{n} s': {
      description:
        'P03 personal-best delta, a hold in seconds. Note G4 publishes no '
        + '`actualHoldSec`, so nothing populates this yet — the string exists so '
        + 'the branch is complete the day it does.',
      placeholders: { n: { type: 'String', example: '8' } },
    },
    '{kcal} kcal · {protein} g protein': {
      description:
        'E01/E04 suggestion rows. _metaOf switched on foodId over six cases '
        + 'with `_ => n540Kcal18GProtein` as the default, so any food outside '
        + 'the list reported koshari\'s macros. Its own doc comment claimed the '
        + 'value was "picked from the dictionary by the row it describes, so '
        + 'the row and its macros cannot disagree" — which was exactly what it '
        + 'could not guarantee.',
      placeholders: {
        kcal: { type: 'String', example: '460' },
        protein: { type: 'String', example: '34' },
      },
    },
    '{slot} · {kcal} kcal · {protein} g protein': {
      description:
        'E01 starter rows. The food SHE is looking at, not the mockup. '
        + '_starterMeta switched on foodId over three hardcoded cases with '
        + '`_ => lunch540Kcal18GProtein` as the default, so every other food — '
        + 'boiled eggs included — claimed koshari\'s 540 kcal and 18 g. Wrong '
        + 'nutrition, stated confidently, on the screen where she decides what '
        + 'to eat.',
      placeholders: {
        // Strings, not num: gen-l10n interpolates a bare placeholder directly,
        // and NumberFormat emits Eastern digits under `ar`, which breaks
        // P0-A11Y-01. The caller formats with countLabel().
        slot: { type: 'String', example: 'Lunch' },
        kcal: { type: 'String', example: '540' },
        protein: { type: 'String', example: '18' },
      },
    },
    "You're in, {name}": {
      description: 'C13. The first sentence the product says to her personally.',
      placeholders: { name: { type: 'String', example: 'Mai' } },
    },
    'Verified in {seconds} seconds. Your ID photo and selfie have been deleted. We kept the result and nothing else.': {
      description: 'C13. Her actual verification time, not the mockup 74.',
      placeholders: { seconds: { type: 'int', example: '74' } },
    },
    'Set {setNumber} saved · {weight} kg × {reps}': {
      description: 'R09 undo snackbar. Must name the numbers SHE logged, not the prescription.',
      placeholders: {
        setNumber: { type: 'int', example: '2' },
        // String, not num, and deliberately so. gen-l10n interpolates a
        // placeholder with no `format` straight into the message, so a num 14.0
        // renders "14.0 kg" on the undo bar. The obvious repair — adding
        // format: decimalPattern — is worse: NumberFormat emits Eastern digits
        // under an Arabic locale, which breaks P0-A11Y-01. The caller formats
        // with weightLabel(), the same plain-Dart rule clockLabel() follows.
        weight: { type: 'String', example: '12' },
        reps: { type: 'int', example: '10' },
      },
    },
    '{move} saved · {sets} sets': {
      description: 'Undo snackbar after a whole move (I did them all).',
      placeholders: {
        move: { type: 'String', example: 'Goblet squat' },
        sets: { type: 'int', example: '3' },
      },
    },
    'Done · {weight} kg × {reps}': {
      description:
        'R07 primary button. Names the numbers it is about to save — HER '
        + 'prescription, not the prototype set. The undo bar on R09 then '
        + 'repeats the same numbers, which is the point of rule 9.',
      placeholders: {
        // String, not num, for the same reason as the set-saved message:
        // gen-l10n interpolates a bare placeholder, so a num 12.0 renders
        // "12.0 kg", and decimalPattern would emit Eastern digits in Arabic.
        weight: { type: 'String', example: '12' },
        reps: { type: 'int', example: '10' },
      },
    },
    'We sent six digits to {phone}.': {
      description: 'C07. Her number, so a mistyped one is obvious before she waits.',
      placeholders: { phone: { type: 'String', example: '+20 100 555 0132' } },
    },

    // ---- Phase 2, Eat. Every numeric placeholder is a String, formatted by
    // the caller. A num renders "53.0", and `decimalPattern` would emit Eastern
    // digits under Arabic and break P0-A11Y-01 — the same reasoning as the
    // weight and set-number messages above.
    'This week, {done} of {target}': {
      description:
        'T01 week card. Her real target, not the prototype 3 — a woman whose '
        + 'goal is 4 sessions read "This week, 0 of 3". The card already had '
        + 'the numbers; only the sentence was fixed.',
      placeholders: {
        done: { type: 'int', example: '1' },
        target: { type: 'int', example: '3' },
      },
    },
    '{soFar} of {target} g': {
      description: 'E01/E04 protein bar. Her real intake, never the mockup 53.',
      placeholders: {
        soFar: { type: 'String', example: '53' },
        target: { type: 'String', example: '95' },
      },
    },
    'About {kcal} kcal so far today': {
      description:
        'E04 running total. A TOTAL, never a countdown — there is no target '
        + 'here and no remainder, by design (G5 1.5).',
      placeholders: { kcal: { type: 'String', example: '1,106' } },
    },
    '+{grams} g': {
      description: 'E04. What this meal added to her protein.',
      placeholders: { grams: { type: 'String', example: '31' } },
    },
    '{count} items · about {egp} EGP': {
      description: 'E07/E08 grocery list. "About", because prices move.',
      placeholders: {
        count: { type: 'int', example: '23' },
        egp: { type: 'String', example: '640' },
      },
    },
    '{meal} added · {kcal} kcal': {
      description:
        'E04 undo bar. Names what SHE logged. The fixed "Lunch logged — 696 '
        + 'kcal" would announce 696 whatever she ate, which is the defect '
        + 'PHASE1-FIXES.md 8 removed from R07.',
      placeholders: {
        meal: { type: 'String', example: 'Lunch' },
        kcal: { type: 'String', example: '696' },
      },
    },
    'This dish has {allergen}. You told us to avoid that.': {
      description:
        'E02/E04 allergen sheet (G5 5.1). Names the allergen SHE told us '
        + 'about, so the sheet is about her and not a generic warning.',
      placeholders: { allergen: { type: 'String', example: 'sesame' } },
    },
    "Week {n}": {"description": "M12's follow-up strip: which week of her own chain a moment is. The only minted forms (Week 1, Week 4) bake the prototype's weeks.", "placeholders": {"n": {"type": "String", "example": "4"}}},
    "Test build: no text message is sent. The code is {code}.": {"description": "C07, only while no account is required. Names the one code the in-memory sign-in accepts, so the sign-up chain can be walked by hand without SMS.", "placeholders": {"code": {"type": "String", "example": "417293"}}},
    "Blocked: {count}": {"description": "A04's blocked-members row. A label form so the Arabic needs no number agreement; the count is the members she actually blocked.", "placeholders": {"count": {"type": "String", "example": "2"}}},
    "Test reports: {count}": {"description": "A04's reports row while no account is required: how many test reports are held on this phone. Nothing is sent anywhere in this build.", "placeholders": {"count": {"type": "String", "example": "1"}}},
    "CSV files copied to the clipboard: {count}. Saving files is not connected in this build yet.": {"description": "Z11 after Export: the chosen collections' CSVs were copied to the clipboard, because this build has no file saving.", "placeholders": {"count": {"type": "String", "example": "4"}}},
    "Days a week: {days} · Minutes a session: {minutes} · At home": {"description": "O05's headline read back from her own O02/O03 answers. Label form so the Arabic is grammatical for every allowed count.", "placeholders": {"days": {"type": "String", "example": "3"}, "minutes": {"type": "String", "example": "15"}}},
    "Days a week: {days} · Minutes a session: {minutes} · At a ladies-only gym": {"description": "O05's headline read back from her own O02/O03 answers, gym variant.", "placeholders": {"days": {"type": "String", "example": "3"}, "minutes": {"type": "String", "example": "15"}}},
    "Days a week: {days} · Minutes a session: {minutes} · At home and the gym": {"description": "O05's headline read back from her own O02/O03 answers, home-and-gym variant.", "placeholders": {"days": {"type": "String", "example": "3"}, "minutes": {"type": "String", "example": "15"}}},
    "Nobody has listed what is in {dish} yet, so we cannot check it against what you avoid.": {"description": "Eat allergen sheet (G5 5.1), for a dish whose allergens are unknown while she has told us she avoids something. Unknown is treated as unsafe, so the log waits for her explicit choice. {dish} is the food's name in her language.", "placeholders": {"dish": {"type": "String", "example": "Koshari bowl"}}},
    "Move {move} of {total}": {"description": "R07/R08/R09 title. Her position in the day's moves, replacing the fixed 'Move 2 of 5'.", "placeholders": {"move": {"type": "String", "example": "2"}, "total": {"type": "String", "example": "5"}}},
    "{move}, set {set}": {"description": "R09 'Up next' card: the move and set she returns to after resting.", "placeholders": {"move": {"type": "String", "example": "Goblet squat"}, "set": {"type": "String", "example": "3"}}},
    "{weight} kg × {reps}": {"description": "One set's figure — what was asked, or what she did. Western digits in both languages.", "placeholders": {"weight": {"type": "String", "example": "12"}, "reps": {"type": "String", "example": "10"}}},
    "{reps} reps": {"description": "A bodyweight set's figure — no load to state, never '0 kg'.", "placeholders": {"reps": {"type": "String", "example": "12"}}},
    "{seconds} seconds": {"description": "A timed hold's figure.", "placeholders": {"seconds": {"type": "String", "example": "30"}}},
    "Done · {reps} reps": {"description": "R07/R08 primary button for a bodyweight set. Names the numbers it is about to save.", "placeholders": {"reps": {"type": "String", "example": "12"}}},
    "Done · {seconds} seconds": {"description": "R07/R08 primary button for a timed hold.", "placeholders": {"seconds": {"type": "String", "example": "30"}}},
    "Set {setNumber} saved · {reps} reps": {"description": "Undo bar after a bodyweight set is logged. Repeats the button's numbers.", "placeholders": {"setNumber": {"type": "String", "example": "2"}, "reps": {"type": "String", "example": "12"}}},
    "Set {setNumber} saved · {seconds} seconds": {"description": "Undo bar after a timed hold is logged.", "placeholders": {"setNumber": {"type": "String", "example": "2"}, "seconds": {"type": "String", "example": "30"}}},
    "That's {day} done": {"description": "R10/R12 heading. The day she trained, replacing the fixed Tuesday.", "placeholders": {"day": {"type": "String", "example": "Tuesday"}}},
    "+{points} points": {"description": "R10/R12: the points this session actually earned her, from the award ledger.", "placeholders": {"points": {"type": "String", "example": "30"}}},
    "{count} more and the week counts.": {"description": "Week line when three or more sessions are still to go. One and two have their own sentences.", "placeholders": {"count": {"type": "String", "example": "3"}}},
    "{done} done, {waiting} waiting": {"description": "T07: the first-week arc counted from the arc, replacing the fixed 'Two done, three waiting'.", "placeholders": {"done": {"type": "String", "example": "2"}, "waiting": {"type": "String", "example": "3"}}},
    "{count} so far": {"description": "P01 bests tile: her lifetime personal bests, replacing the fixed '8 so far'.", "placeholders": {"count": {"type": "String", "example": "8"}}},
    "{from} to {to}": {"description": "A range of two values the screen already knows: opening hours on a coach's page, or the number of clients she may take. Written out in each language rather than joined with a dash in code, which would read as English punctuation inside an Arabic line.", "placeholders": {"from": {"type": "String", "example": "9:00"}, "to": {"type": "String", "example": "17:00"}}},
    "of {total}": {"description": "The small half of the ring on her first week: how many steps the arc has. The number is a value, and the arc is shorter when a step belongs to a feature this build has switched off, so it cannot be frozen into the sentence.", "placeholders": {"total": {"type": "String", "example": "3"}}},
    "{minutes} minutes, {moves} moves": {"description": "R03's summary of today's session. Counted off the day's own moves, never a fixed '5 moves'.", "placeholders": {"minutes": {"type": "String", "example": "15"}, "moves": {"type": "String", "example": "4"}}},
    "Last time: {last}. So we added {added} kg.": {"description": "R07's progression note, drawn only when she has a logged set for this move and today's prescription is heavier.", "placeholders": {"last": {"type": "String", "example": "10 kg × 10"}, "added": {"type": "String", "example": "2"}}},
    "Last time: {last}.": {"description": "R07's progression note when she has a logged set for this move and nothing was added.", "placeholders": {"last": {"type": "String", "example": "10 kg × 10"}}},
    "Step {step} of {total}": {"description": "Progress through the server-chosen liveness challenge on C11. The number of steps is decided by the server per session, so it cannot be baked into the sentence the way the other Step strings in this dictionary are.", "placeholders": {"step": {"type": "String", "example": "2"}, "total": {"type": "String", "example": "4"}}},
    "{n} min": {"description": "A cooking time on a recipe card. The figure comes from the recipe, never from the dictionary.", "placeholders": {"n": {"type": "String", "example": "20"}}},
    "{n} g protein": {"description": "Protein per serving on a recipe card, only when the recipe states it.", "placeholders": {"n": {"type": "String", "example": "24"}}},
    "{n} EGP a serving": {"description": "Cost per serving, shown beside the month it was priced in.", "placeholders": {"n": {"type": "String", "example": "14"}}},
    "{n} kcal a serving": {"description": "Energy per serving, only when it was summed from verified foods.", "placeholders": {"n": {"type": "String", "example": "410"}}},
    "Priced {month}": {"description": "The month an EGP figure was priced in. An undated price in Egypt is wrong within a quarter.", "placeholders": {"month": {"type": "String", "example": "October 2026"}}},
    "{n} g": {"description": "A gram figure beside an ingredient, in her own words' shadow.", "placeholders": {"n": {"type": "String", "example": "40"}}},
    "Step {n} of {total}": {"description": "Cook mode's position line.", "placeholders": {"n": {"type": "String", "example": "2"}, "total": {"type": "String", "example": "6"}}},
    "{temp} degrees": {"description": "An oven temperature chip on a step.", "placeholders": {"temp": {"type": "String", "example": "200"}}},
    "Serves {n}": {"description": "How many the recipe feeds, only when the book says.", "placeholders": {"n": {"type": "String", "example": "2"}}},
    "{count, plural, one{1 dish is hidden because nobody has checked what is in it yet.} other{{count} dishes are hidden because nobody has checked what is in them yet.}}": {"description": "E05, at the foot of Rahma's book. The reason the app is holding dishes back is that nobody has signed the allergen check, NOT anything she named. Arabic counts do not agree the way English ones do, so this is a plural message rather than one sentence with a number dropped into it: 39 takes the singular accusative.", "placeholders": {"count": {"type": "int", "example": "39"}}},
    "{count, plural, one{1 dish is hidden because it contains something you avoid.} other{{count} dishes are hidden because they contain something you avoid.}}": {"description": "E05, at the foot of Rahma's book. The other reason a dish is held back, and it must read differently from the unchecked one: this one IS about her body.", "placeholders": {"count": {"type": "int", "example": "3"}}},
    "{n} min hands on": {"description": "A recipe's active time. Overnight oats is five minutes of work and a day in the fridge, and the card stated 1,445.", "placeholders": {"n": {"type": "String", "example": "5"}}},
    "{n} min in all": {"description": "A recipe's total time, beside the hands-on figure, for a dish under two hours.", "placeholders": {"n": {"type": "String", "example": "50"}}},
    "{count, plural, one{About 1 hour in all} other{About {count} hours in all}}": {"description": "A recipe's total time once it passes two hours. Rounded to the hour and said to be rounded, because 1,445 minutes is true and unreadable.", "placeholders": {"count": {"type": "int", "example": "24"}}},
    "Your video call is booked for {time}.": {"description": "C14 once a woman reviewer has booked the live video check. time is the booked date and time, already formatted for her locale.", "placeholders": {"time": {"type": "String", "example": "Mon, 5 Oct, 10:00"}}},
    "You can also delete your account on our website: {url}": {"description": "Shown when this copy of the app cannot reach Own Hub to delete her account. The address of the public delete-account page.", "placeholders": {"url": {"type": "String", "example": "https://ownhub.app/delete-account"}}},
    "Next: session {number}, on any day this week": {"description": "R10's next step after a finished session. The number is the next session of her week, in Western digits.", "placeholders": {"number": {"type": "String", "example": "2"}}},
    "A woman from Own Hub will contact you on {time}.": {"description": "C14 once a woman reviewer has booked a time to contact her. time is the booked date and time, already formatted for her locale.", "placeholders": {"time": {"type": "String", "example": "Mon, 5 Oct, 10:00"}}},
    "Days a week: {days} · Minutes a session: {minutes}": {"description": "Her setup answers read back when she was never asked where she trains (the one-screen 'Your week'), so no place is claimed.", "placeholders": {"days": {"type": "String", "example": "3"}, "minutes": {"type": "String", "example": "15"}}},
    "Pick a dinner for {day}": {"description": "E05 opened from a day on E07: tapping a recipe puts it on that day. day is the weekday name from the dictionary.", "placeholders": {"day": {"type": "String", "example": "Monday"}}},
    "Verified in {seconds} seconds. Your ID photo and selfie have been deleted. We keep the result, its reasons and a keyed code of your ID number.": {"description": "C13. Her actual verification time, and what the server really keeps: the result, its reasons for 180 days and the keyed code of her ID number.", "placeholders": {"seconds": {"type": "int", "example": "74"}}},
    "Sessions in your week: {count}. Pick the days that suit you.": {"description": "Training reminders sheet. count is her sessions a week (2 to 4), Western digits.", "placeholders": {"count": {"type": "String", "example": "3"}}},
    "Join me on Own Hub, the training app for women only. When you sign up, tap I have a code from my coach and enter {code}.": {"description": "The WhatsApp message a coach sends to invite a client. {code} is her eight-character invite code.", "placeholders": {"code": {"type": "String", "example": "ABCD2345"}}},
    "We could not open WhatsApp. Your code is {code}.": {"description": "Shown when WhatsApp could not open, so the coach can share her code another way.", "placeholders": {"code": {"type": "String", "example": "ABCD2345"}}},
    "I coach women and would like to coach on Own Hub. Name: {name}. City: {city}. I coach: {specialty}.": {"description": "The message a coach sends to the team from the interest form while coaching is closed.", "placeholders": {"name": {"type": "String", "example": "Salma"}, "city": {"type": "String", "example": "Cairo"}, "specialty": {"type": "String", "example": "postpartum strength"}}},
    "{done} of {target} this week": {"description": "Lock Screen inline widget. Sessions this week against her weekly target. Never a daily count.", "placeholders": {"done": {"type": "int", "example": "1"}, "target": {"type": "int", "example": "3"}}},
    "Sessions this week: {done} of {target}": {"description": "VoiceOver label for the widget's week segments and gauge.", "placeholders": {"done": {"type": "int", "example": "1"}, "target": {"type": "int", "example": "3"}}},
    "{count} past the {hours}-hour promise": {"description": "Z15, human reviews older than the review SLA. Both values are Western-digit labels.", "placeholders": {"count": {"type": "String", "example": "3"}, "hours": {"type": "String", "example": "72"}}},
    "Oldest has waited {hours} hours": {"description": "Z15, the age of the oldest open human review in whole hours.", "placeholders": {"hours": {"type": "String", "example": "41"}}},
    "Updated {time}": {"description": "Z15, when the counts were computed, Cairo time.", "placeholders": {"time": {"type": "String", "example": "2026-10-07 14:05"}}},
    "Case {ref}": {"description": "Z16, a short reference standing for a verification case. Eight hex characters, never an id.", "placeholders": {"ref": {"type": "String", "example": "3fa91c0e"}}},
    "Reviewer {ref}": {"description": "Z16, a short reference standing for a reviewer account.", "placeholders": {"ref": {"type": "String", "example": "9b2d41aa"}}},
    "Admin {ref}": {"description": "Z16, a short reference standing for an admin account.", "placeholders": {"ref": {"type": "String", "example": "c01d2e3f"}}},
    "{count} joined": {"description": "Z16, waitlist joins on one day. Counts only.", "placeholders": {"count": {"type": "String", "example": "12"}}},
    "{start} to {end}": {"description": "An event's time span, both in Cairo time, Western digits.", "placeholders": {"start": {"type": "String", "example": "18:30"}, "end": {"type": "String", "example": "20:00"}}},
    "Places: {count}": {"description": "An event's capacity, when the owner set one.", "placeholders": {"count": {"type": "String", "example": "20"}}},
    "{sets} × {reps}": {"description": "A move's prescription: sets times reps, Western digits.", "placeholders": {"sets": {"type": "String", "example": "3"}, "reps": {"type": "String", "example": "12"}}},
    "{sets} × {seconds} seconds": {"description": "A held move's prescription: sets times seconds.", "placeholders": {"sets": {"type": "String", "example": "3"}, "seconds": {"type": "String", "example": "30"}}},
    "Rest {seconds} seconds": {"description": "Rest between sets, as the owner wrote it.", "placeholders": {"seconds": {"type": "String", "example": "60"}}},
    "Upload its pictures under this id: {id}": {"description": "Z18, the event id the owner passes to tool/admin_access.sh upload-media for its cover.", "placeholders": {"id": {"type": "String", "example": "AbC123xyz"}}},
    "{sets} × {reps}": {"description": "A move's prescription: sets times reps, Western digits.", "placeholders": {"sets": {"type": "String", "example": "3"}, "reps": {"type": "String", "example": "12"}}},
    "{sets} × {seconds} seconds": {"description": "A held move's prescription: sets times seconds.", "placeholders": {"sets": {"type": "String", "example": "3"}, "seconds": {"type": "String", "example": "30"}}},
    "Between {min} and {max} days, or leave it empty": {"description": "Y02, under the usual cycle length when what she typed is not a cycle length.", "placeholders": {"min": {"type": "String", "example": "15"}, "max": {"type": "String", "example": "60"}}},
    "Sets done: {done} of {total}": {"description": "R07/R08/R09 set bar: sets of today's session behind her, out of all of them.", "placeholders": {"done": {"type": "String", "example": "4"}, "total": {"type": "String", "example": "12"}}},
    "Training streak: {days} days": {"description": "T01 week block: her training streak (D37). Never shown when she has switched it off.", "placeholders": {"days": {"type": "String", "example": "12"}}},
    "{days} days": {"description": "P01 and the streak sheet: the length of her current training streak.", "placeholders": {"days": {"type": "String", "example": "12"}}},
    "Your best: {days} days": {"description": "P01 and the streak sheet: her longest training streak. Never taken away.", "placeholders": {"days": {"type": "String", "example": "21"}}},
    "Paused until {date}": {"description": "Streak sheet and P01 while a pause with an end date runs.", "placeholders": {"date": {"type": "String", "example": "Monday 20 October"}}},
    "{move}: more than last week's {amount}": {"description": "T01/R03 weekly challenge (D38): beat her own last-week total on one move.", "placeholders": {"move": {"type": "String", "example": "Glute bridge"}, "amount": {"type": "String", "example": "24 reps"}}},
    "{move}: match last week's {amount}": {"description": "T01/R03 weekly challenge (D38): match her own last-week total on one move.", "placeholders": {"move": {"type": "String", "example": "Glute bridge"}, "amount": {"type": "String", "example": "30 reps"}}},
    "You beat last week on {move}: {amount}": {"description": "R10 reveal: the weekly challenge, met by beating last week. Her total this week.", "placeholders": {"move": {"type": "String", "example": "Glute bridge"}, "amount": {"type": "String", "example": "32 reps"}}},
    "You matched last week on {move}: {amount}": {"description": "R10 reveal: the weekly challenge, met by matching last week. Her total this week.", "placeholders": {"move": {"type": "String", "example": "Glute bridge"}, "amount": {"type": "String", "example": "30 reps"}}},
    "{moves} moves · {sets} sets · {minutes} min": {"description": "R10 reveal: the effort she actually logged in this session.", "placeholders": {"moves": {"type": "String", "example": "4"}, "sets": {"type": "String", "example": "11"}, "minutes": {"type": "String", "example": "24"}}},
    "{move}: {now}, up from {before}": {"description": "R10 reveal: a real personal best, with her previous best on the same move.", "placeholders": {"move": {"type": "String", "example": "Goblet squat"}, "now": {"type": "String", "example": "14 kg × 10"}, "before": {"type": "String", "example": "12 kg × 10"}}},
    "{move}: a harder version than before": {"description": "R10 reveal: a personal best that is a harder variation rather than a bigger number.", "placeholders": {"move": {"type": "String", "example": "Push-up"}}},
    "First marks set on {count} moves.": {"description": "R10 reveal: moves she logged for the first time ever. A first mark, not a best.", "placeholders": {"count": {"type": "String", "example": "4"}}},
    "{days, plural, one{Training streak: 1 day} other{Training streak: {days} days}}": {"description": "T01 week block and R10: her training streak (D37). A plural message because Arabic counts agree differently at 1, 2, 3 to 10 and 11 and up. Never shown when she has switched it off.", "placeholders": {"days": {"type": "int", "example": "12"}}},
    "{days, plural, one{Your best: 1 day} other{Your best: {days} days}}": {"description": "P01 and the streak sheet: her longest training streak. Never taken away.", "placeholders": {"days": {"type": "int", "example": "21"}}},
    "{count, plural, one{First mark set on 1 move.} other{First marks set on {count} moves.}}": {"description": "R10 reveal: moves she logged for the first time ever. A first mark, not a best.", "placeholders": {"count": {"type": "int", "example": "4"}}},
    "Moves: {moves} · Sets: {sets} · Time: {minutes} min": {"description": "R10 reveal: the effort she actually logged in this session. Labels before each figure so no noun has to agree with its number.", "placeholders": {"moves": {"type": "String", "example": "4"}, "sets": {"type": "String", "example": "11"}, "minutes": {"type": "String", "example": "24"}}},
    "{minutes, plural, one{Moves: {moves} · Sets: {sets} · Time: 1 min} other{Moves: {moves} · Sets: {sets} · Time: {minutes} min}}": {"description": "R10 reveal: the effort she actually logged in this session. Moves and sets are labelled so they need no agreement; the minutes are a plural because Arabic says دقيقة واحدة, دقيقتين, 3 دقايق and 11 دقيقة.", "placeholders": {"minutes": {"type": "int", "example": "24"}, "moves": {"type": "String", "example": "4"}, "sets": {"type": "String", "example": "11"}}},
    "You finished every set at {weight}. Try {next} today.": {"description": "R07 and R08: her last session's weight for a loaded move, and the next weight up.", "placeholders": {"weight": {"type": "String", "example": "10 kg"}, "next": {"type": "String", "example": "12 kg"}}},
    "Last time you did {weight}. Stay there until every set is done.": {"description": "R07 and R08: why the weight is not going up yet.", "placeholders": {"weight": {"type": "String", "example": "10 kg"}}},
    "It has been a while since {weight}. Start a little lighter and build back.": {"description": "R07 and R08: she is coming back to a loaded move after a break.", "placeholders": {"weight": {"type": "String", "example": "10 kg"}}},
    "Swap to {name}": {"description": "R05 confirm button, names the move she picked.", "placeholders": {"name": {"type": "String", "example": "Glute bridge"}}},
    "Your first week: {done} of {total} steps": {"description": "Home: the first-week arc, counted in steps so it is never read against this week's sessions.", "placeholders": {"done": {"type": "String", "example": "2"}, "total": {"type": "String", "example": "3"}}},
    "{days} days a week · {minutes} min a session": {"description": "O05 headline: her days and minutes.", "placeholders": {"days": {"type": "String", "example": "3"}, "minutes": {"type": "String", "example": "15"}}},
    "{days} days a week · {minutes} min a session · At home": {"description": "Her answers read back: days and minutes, trained at home.", "placeholders": {"days": {"type": "String", "example": "3"}, "minutes": {"type": "String", "example": "15"}}},
    "{days} days a week · {minutes} min a session · At a ladies-only gym": {"description": "Her answers read back: days and minutes, at a ladies-only gym.", "placeholders": {"days": {"type": "String", "example": "3"}, "minutes": {"type": "String", "example": "15"}}},
    "{days} days a week · {minutes} min a session · At home and the gym": {"description": "Her answers read back: days and minutes, at home and the gym.", "placeholders": {"days": {"type": "String", "example": "3"}, "minutes": {"type": "String", "example": "15"}}},
    "Photo {number} of {total}": {"description": "Screen reader label on each selfie thumbnail on the C11 review. The count comes from the server's liveness challenge, so it cannot be baked into the sentence.", "placeholders": {"number": {"type": "String", "example": "2"}, "total": {"type": "String", "example": "4"}}},
    "Last trained: {day}": {"description": "P06: the last day she logged a set for this muscle group. {day} is Today, Yesterday, a weekday name, or 'N days ago'.", "placeholders": {"day": {"type": "String", "example": "Tuesday"}}},
    "{days, plural, one{1 day ago} other{{days} days ago}}": {"description": "P06: how long since a muscle group last had a set, when it is more than a week. A plural message because Arabic counts agree differently at 1, 2, 3 to 10 and 11 and up.", "placeholders": {"days": {"type": "int", "example": "12"}}},
    "In sets: {list}": {"description": "P06 most trained: her top muscle groups with their weighted sets, joined with a middle dot, e.g. 'Glutes 9 · Front of thighs 6'.", "placeholders": {"list": {"type": "String", "example": "Glutes 9 · Front of thighs 6"}}},
    "{times, plural, =0{All of these sets went to your lower body.} =1{Your lower body got a little more than your upper body.} =2{Your lower body got about twice as much as your upper body.} other{Your lower body got about {times} times as much as your upper body.}}": {"description": "P06 balance: her lower body had more sets than her upper body. 0 means every set went to the lower body, 1 a little more, otherwise about how many times as much. Never a judgement.", "placeholders": {"times": {"type": "int", "example": "2"}}},
    "{times, plural, =0{All of these sets went to your upper body.} =1{Your upper body got a little more than your lower body.} =2{Your upper body got about twice as much as your lower body.} other{Your upper body got about {times} times as much as your lower body.}}": {"description": "P06 balance: her upper body had more sets than her lower body. 0 means every set, 1 a little more, otherwise about how many times as much.", "placeholders": {"times": {"type": "int", "example": "2"}}},
    "{times, plural, =0{All of these sets went to the front of your body.} =1{The front of your body got a little more than the back.} =2{The front of your body got about twice as much as the back.} other{The front of your body got about {times} times as much as the back.}}": {"description": "P06 balance: the front of her body had more sets than the back. 0 means every set, 1 a little more, otherwise about how many times as much.", "placeholders": {"times": {"type": "int", "example": "2"}}},
    "{times, plural, =0{All of these sets went to the back of your body.} =1{The back of your body got a little more than the front.} =2{The back of your body got about twice as much as the front.} other{The back of your body got about {times} times as much as the front.}}": {"description": "P06 balance: the back of her body had more sets than the front. 0 means every set, 1 a little more, otherwise about how many times as much.", "placeholders": {"times": {"type": "int", "example": "3"}}},
    "In sets: upper body {upper} · lower body {lower}": {"description": "P06 balance: weighted sets for her upper and lower body in the window. Numbers can be halves.", "placeholders": {"upper": {"type": "String", "example": "6"}, "lower": {"type": "String", "example": "18.5"}}},
    "In sets: front {front} · back {back}": {"description": "P06 balance: weighted sets for the front and back of her body in the window. Numbers can be halves.", "placeholders": {"front": {"type": "String", "example": "8"}, "back": {"type": "String", "example": "16.5"}}},
    "Body map. In sets: {list}": {"description": "P06: what a screen reader hears for the 3D figure: every muscle group with its weighted sets.", "placeholders": {"list": {"type": "String", "example": "Glutes 9, Chest 0"}}},
    "{days, plural, one{1 day} other{{days} days}}": {"description": "P06 window switch: 7 days or 30 days, each a rolling window ending today. A plural message because Arabic says 7 أيام but 30 يوم.", "placeholders": {"days": {"type": "int", "example": "7"}}},
    "{days, plural, one{Sets in 1 day: {sets}} other{Sets in {days} days: {sets}}}": {"description": "P06 tap card: weighted sets for one muscle group over the rolling window (7 or 30 days, ending today; not the calendar week Home counts). {sets} can be a half, like 7.5.", "placeholders": {"days": {"type": "int", "example": "7"}, "sets": {"type": "String", "example": "7.5"}}},
    "{days, plural, one{Sets in 1 day} other{Sets in {days} days}}": {"description": "P06: the heading over the numbers in the list of muscle groups, for the rolling 7 or 30 days.", "placeholders": {"days": {"type": "int", "example": "30"}}},
    "{days, plural, one{No sets logged today.} other{No sets logged in the last {days} days.}}": {"description": "P06: the window she chose holds no sets, though she has logged before.", "placeholders": {"days": {"type": "int", "example": "7"}}},
    "Protein {grams} g": {"description": "E01 and E13: protein in grams, for one item, a meal or the day. Whole number, Western digits.", "placeholders": {"grams": {"type": "String", "example": "22"}}},
    "Carbs {grams} g": {"description": "E01 and E13: carbohydrates in grams. Shown only when known. Whole number, Western digits.", "placeholders": {"grams": {"type": "String", "example": "120"}}},
    "Fat {grams} g": {"description": "E01 and E13: fat in grams. Shown only when known.", "placeholders": {"grams": {"type": "String", "example": "45"}}},
    "Fibre {grams} g": {"description": "E01 and E13: dietary fibre in grams. Shown only when known.", "placeholders": {"grams": {"type": "String", "example": "18"}}},
    "{grams} g": {"description": "E13: a weight in grams, for an item or one part of a dish.", "placeholders": {"grams": {"type": "String", "example": "150"}}},
    "Remove {name}": {"description": "E13: screen reader label on the button that takes one food off the plate before it is logged.", "placeholders": {"name": {"type": "String", "example": "Koshary"}}},
    "{count, plural, one{Also worked: 1 set} other{Also worked: {count} sets}}": {"description": "P06 card on one muscle: whole sets in the rolling window where this muscle helped a move without being its main muscle. These sets never colour the body map. A plural message because Arabic says مجموعة واحدة, مجموعتين, 3 مجموعات and 11 مجموعة.", "placeholders": {"count": {"type": "int", "example": "6"}}},
    "Added from memory · {title}": {"description": "T02 undo bar after a session logged from memory. title is the session's own name.", "placeholders": {"title": {"type": "String", "example": "Legs and glutes"}}},
    "Taken back. Your week is at {count} of {target}.": {"description": "T02 after Undo on a recalled session. Numbers in Western digits.", "placeholders": {"count": {"type": "String", "example": "1"}, "target": {"type": "String", "example": "3"}}},
    "Session removed · your week is at {count} of {target}": {"description": "R10/R12 undo bar after she removes a logged session. Numbers in Western digits.", "placeholders": {"count": {"type": "String", "example": "1"}, "target": {"type": "String", "example": "3"}}},
    "{food} added to {slot}": {"description": "Meal undo bar. food is the first food's name, slot is Breakfast, Lunch, Dinner or Snack.", "placeholders": {"food": {"type": "String", "example": "Ful"}, "slot": {"type": "String", "example": "Breakfast"}}},
    "{food} and {count} more added to {slot}": {"description": "Meal undo bar for a plate of several foods. count in Western digits.", "placeholders": {"food": {"type": "String", "example": "Ful"}, "count": {"type": "String", "example": "2"}, "slot": {"type": "String", "example": "Breakfast"}}},
    "{food} removed from {slot}": {"description": "E01/E04 undo bar after she removes a logged food from a slot.", "placeholders": {"food": {"type": "String", "example": "Ful"}, "slot": {"type": "String", "example": "Breakfast"}}},
    "Saved. Dishes with {allergens} are hidden now.": {"description": "E10 and A02 after saving allergies. allergens is a comma-separated list of allergen names.", "placeholders": {"allergens": {"type": "String", "example": "nuts, eggs"}}},
    "Unblocked {name}": {"description": "A04 undo bar after unblocking a member.", "placeholders": {"name": {"type": "String", "example": "Mai"}}},
    "Swapped to {name} for today": {"description": "R05 undo bar after a swap. name is the move she swapped to.", "placeholders": {"name": {"type": "String", "example": "Glute bridge"}}},
    "Skipped {name}": {"description": "R06 undo bar after skipping a move. name is the move.", "placeholders": {"name": {"type": "String", "example": "Plank"}}},
    "Your week is updated · {days} days, {minutes} minutes.": {"description": "O05 after saving changed setup answers from the profile. Numbers in Western digits.", "placeholders": {"days": {"type": "String", "example": "3"}, "minutes": {"type": "String", "example": "30"}}},
    "Check-in saved · {summary}": {"description": "Y04 undo bar. summary is label: value pairs joined by a middle dot.", "placeholders": {"summary": {"type": "String", "example": "Energy: Low · Cramps: Mild"}}},
    "Today: {summary}": {"description": "Y03 line under How are you feeling. summary is label: value pairs.", "placeholders": {"summary": {"type": "String", "example": "Energy: Low · Cramps: Mild"}}},
    "Period saved · {start} to {end}": {"description": "Y09 after saving a period. Dates as yyyy-MM-dd.", "placeholders": {"start": {"type": "String", "example": "2026-10-01"}, "end": {"type": "String", "example": "2026-10-05"}}},
    "Period saved · from {start}": {"description": "Y09 after saving a period with no end date yet.", "placeholders": {"start": {"type": "String", "example": "2026-10-01"}}},
    "Period removed · {start} to {end}": {"description": "Y09 undo bar after deleting a period.", "placeholders": {"start": {"type": "String", "example": "2026-10-01"}, "end": {"type": "String", "example": "2026-10-05"}}},
    "Period removed · from {start}": {"description": "Y09 undo bar after deleting a period with no end date.", "placeholders": {"start": {"type": "String", "example": "2026-10-01"}}},
    "If the pain is severe or sudden, see a doctor today. In an emergency call {number}.": {"description": "Y11, the severe-pain card. number is Egypt's ambulance line, 123, in Western digits.", "placeholders": {"number": {"type": "String", "example": "123"}}},
    "{list}, {item}": {"description": "Adds one more name to a list of names, e.g. allergens. The comma is the language's own.", "placeholders": {"list": {"type": "String", "example": "Tree nuts"}, "item": {"type": "String", "example": "Eggs"}}},
    "Good morning, {name}": {"description": "T01 greeting before noon, with her first name.", "placeholders": {"name": {"type": "String", "example": "Mai"}}},
    "Good afternoon, {name}": {"description": "T01 greeting from noon to five, with her first name.", "placeholders": {"name": {"type": "String", "example": "Mai"}}},
    "Good evening, {name}": {"description": "T01 greeting from five in the afternoon, with her first name.", "placeholders": {"name": {"type": "String", "example": "Mai"}}},
    "Contains {allergens}": {"description": "A small note under a logged food that is known to contain something she told us she avoids. Logging is never blocked.", "placeholders": {"allergens": {"type": "String", "example": "nuts"}}},
    "Add {name}": {"description": "Screen reader label of the plus button on a food row that logs it.", "placeholders": {"name": {"type": "String", "example": "Koshari"}}},
    "About {grams} g": {"description": "A portion's weight in grams when the unit is an estimate.", "placeholders": {"grams": {"type": "String", "example": "150"}}},
    "of {target} kcal": {"description": "The day's kcal target, under the kcal eaten in the ring.", "placeholders": {"target": {"type": "String", "example": "1,700"}}},
    "{training} training · {recovery} recovery": {"description": "O03 custom schedule summary: how many weekdays are training and how many are recovery.", "placeholders": {"training": {"type": "String", "example": "4"}, "recovery": {"type": "String", "example": "3"}}},
    "About {minutes} minutes": {"description": "How long the ID route takes.", "placeholders": {"minutes": {"type": "String", "example": "2"}}},
    "There are no free times in the next {days} days. A woman from Own Hub will still contact you.": {"description": "No review call slots in the window.", "placeholders": {"days": {"type": "String", "example": "7"}}},
    "Pick any length from {min} to {max} minutes.": {"description": "Custom session length range.", "placeholders": {"min": {"type": "String", "example": "10"}, "max": {"type": "String", "example": "180"}}},
    "Between {min} and {max} kg": {"description": "Weight range error.", "placeholders": {"min": {"type": "String", "example": "30"}, "max": {"type": "String", "example": "250"}}},
    "Between {min} and {max} cm": {"description": "Height range error.", "placeholders": {"min": {"type": "String", "example": "120"}, "max": {"type": "String", "example": "230"}}},
    "Between {min} and {max} years": {"description": "Age range error.", "placeholders": {"min": {"type": "String", "example": "14"}, "max": {"type": "String", "example": "90"}}},
    "{remaining} of {capacity} seats left": {"description": "How many seats are left on an event with a limit. Western digits.", "placeholders": {"remaining": {"type": "String", "example": "4"}, "capacity": {"type": "String", "example": "20"}}},
    "{minutes} min a session": {"description": "A chip on a programme card: how long each session lasts.", "placeholders": {"minutes": {"type": "String", "example": "20"}}},
    "Add selected ({n})": {"description": "The button that adds the moves she ticked to her workout.", "placeholders": {"n": {"type": "String", "example": "3"}}},
    "Removed {name}": {"description": "The undo bar after she takes a move out of today's workout.", "placeholders": {"name": {"type": "String", "example": "Glute bridge"}}},
    "Deleted {name}": {"description": "The undo bar after she deletes one of her saved workouts.", "placeholders": {"name": {"type": "String", "example": "My workout"}}},
    "Log {meal}": {"description": "Screen-reader name of the Log pill on a meal row in the Eat diary.", "placeholders": {"meal": {"type": "String", "example": "Lunch"}}},
    "{percent}%": {"description": "A share of a daily target, as a whole-number percentage.", "placeholders": {"percent": {"type": "String", "example": "12"}}},
    "{percent}% of your target today": {"description": "Screen-reader reading of an Impact on today ring, after the nutrient name.", "placeholders": {"percent": {"type": "String", "example": "12"}}},
    "Decrease {label}": {"description": "Tooltip of a minus button on a stepper; label names what it changes, such as Sets.", "placeholders": {"label": {"type": "String", "example": "Sets"}}},
    "Increase {label}": {"description": "Tooltip of a plus button on a stepper; label names what it changes, such as Sets.", "placeholders": {"label": {"type": "String", "example": "Sets"}}},
    "{n} seats are already reserved, so the limit cannot be lower than that.": {"description": "Z18 capacity error when the owner sets a limit under the seats already reserved.", "placeholders": {"n": {"type": "String", "example": "12"}}},
    "{count, plural, one{Show 1 result} other{Show {count} results}}": {"description": "The apply button of the Explore filters. A plural message because Arabic says نتيجة واحدة, نتيجتين, 3 نتايج and 11 نتيجة. The figure is how many workouts and moves match what she has picked.", "placeholders": {"count": {"type": "int", "example": "12"}}},
    "{count, plural, one{Show 1 move} other{Show {count} moves}}": {"description": "The apply button of the move filters. A plural message because Arabic says حركة واحدة, حركتين, 3 حركات and 11 حركة. The figure is how many moves match what she has picked.", "placeholders": {"count": {"type": "int", "example": "12"}}},
    "You can keep up to {max} workouts. Delete one to save a new one.": {"description": "Shown when she tries to save past the cap on her own workouts. max is the real cap, in Western digits.", "placeholders": {"max": {"type": "String", "example": "30"}}},
    "Choose at most {pictures} pictures and {clips} videos.": {"description": "Z18 file-count error. pictures and clips are the real limits of an event, in Western digits.", "placeholders": {"pictures": {"type": "String", "example": "6"}, "clips": {"type": "String", "example": "2"}}},
    "{month} {year}": {"description": "Month and year title, e.g. October 2026.", "placeholders": {"month": {"type": "String", "example": "October"}, "year": {"type": "String", "example": "2026"}}},
    "{day} {month} {year}": {"description": "A calendar date, e.g. 12 October 2026.", "placeholders": {"day": {"type": "String", "example": "12"}, "month": {"type": "String", "example": "October"}, "year": {"type": "String", "example": "2026"}}},
    "{minutes} min · your program": {"description": "Length of the session in her programme.", "placeholders": {"minutes": {"type": "String", "example": "15"}}},
    "Full-body strength, {minutes} min": {"description": "Planned session title with its length.", "placeholders": {"minutes": {"type": "String", "example": "15"}}},
    "Moves: {moves} · Sets: {sets}": {"description": "Home follow-up after a session: what she logged, with a label before each figure so no noun has to agree with its number.", "placeholders": {"moves": {"type": "String", "example": "4"}, "sets": {"type": "String", "example": "11"}}},
    "Up to {weight} on {move}": {"description": "Home follow-up: her heaviest weight in the last session. The move name stays English in both languages.", "placeholders": {"weight": {"type": "String", "example": "12.5 kg"}, "move": {"type": "String", "example": "Goblet squat"}}},
    "New bests: {count}": {"description": "Week review on Home: new personal bests this week. Labelled so the number needs no agreement.", "placeholders": {"count": {"type": "String", "example": "2"}}},
    "Average protein: {grams} g": {"description": "Week review on Home: her average protein on the days she logged this week.", "placeholders": {"grams": {"type": "String", "example": "78"}}},
    "{days, plural, one{Your last session was 1 day ago. A short one today?} other{Your last session was {days} days ago. A short one today?}}": {"description": "Home welcome-back card. A plural message because Arabic says من يوم, من يومين, من 7 أيام and من 11 يوم.", "placeholders": {"days": {"type": "int", "example": "9"}}},
    "Under your target on {lowDays} of your last 5 logged days. {food} is one you already have, {grams} g of protein.": {"description": "Home protein idea: how many of her last five logged days were under target, and a food she already eats with its protein.", "placeholders": {"lowDays": {"type": "String", "example": "3"}, "food": {"type": "String", "example": "Ful medames"}, "grams": {"type": "String", "example": "14"}}},
    "Days a week: {days}": {"description": "Week review suggestion: a new number of training days.", "placeholders": {"days": {"type": "String", "example": "3"}}},
    "Session length: {minutes} min": {"description": "Week review suggestion: a new session length.", "placeholders": {"minutes": {"type": "String", "example": "30"}}},
    "Focus: {goal}": {"description": "Week review suggestion: a new goal, named as the goal screen names it.", "placeholders": {"goal": {"type": "String", "example": "Get stronger"}}},
    "{current} of {total}": {"description": "Progress hint above each of the three week review questions.", "placeholders": {"current": {"type": "String", "example": "1"}, "total": {"type": "String", "example": "3"}}},
    "Sets saved so far: {count}": {"description": "The end-workout sheet: how many sets she has logged in this workout.", "placeholders": {"count": {"type": "String", "example": "5"}}},
    "{count, plural, one{1 move} other{{count} moves}}": {"description": "Home and Train: how many moves the viewed level's session holds. Plural because Arabic counts agree differently at 1, 2, 3 to 10 and 11 and up.", "placeholders": {"count": {"type": "int", "example": "8"}}},
    "{seconds} s rest": {"description": "Home and Train: the rest between sets of the viewed level's session.", "placeholders": {"seconds": {"type": "String", "example": "70"}}},
    "{minutes, plural, one{About 1 min} other{About {minutes} min}}": {"description": "Home and Train: about how long the viewed level's session takes, rounded to 5 minutes. Plural for Arabic.", "placeholders": {"minutes": {"type": "int", "example": "40"}}},
    "{count, plural, one{1 more set} other{{count} more sets}}": {"description": "Home and Train: the viewed level has this many more sets per move than her own level.", "placeholders": {"count": {"type": "int", "example": "1"}}},
    "{count, plural, one{1 set less} other{{count} sets less}}": {"description": "Home and Train: the viewed level has this many fewer sets per move than her own level.", "placeholders": {"count": {"type": "int", "example": "1"}}},
    "{count, plural, one{1 more move} other{{count} more moves}}": {"description": "Home and Train: the viewed level has this many more moves than her own level.", "placeholders": {"count": {"type": "int", "example": "2"}}},
    "{count, plural, one{1 move less} other{{count} moves less}}": {"description": "Home and Train: the viewed level has this many fewer moves than her own level.", "placeholders": {"count": {"type": "int", "example": "2"}}},
    "{seconds} s more rest": {"description": "Home and Train: the viewed level rests this many seconds longer than her own level.", "placeholders": {"seconds": {"type": "String", "example": "20"}}},
    "{seconds} s less rest": {"description": "Home and Train: the viewed level rests this many seconds less than her own level.", "placeholders": {"seconds": {"type": "String", "example": "20"}}},
    "{minutes, plural, one{1 min longer} other{{minutes} min longer}}": {"description": "Home and Train: the viewed level's session is this much longer than her own level's.", "placeholders": {"minutes": {"type": "int", "example": "10"}}},
    "{minutes, plural, one{1 min shorter} other{{minutes} min shorter}}": {"description": "Home and Train: the viewed level's session is this much shorter than her own level's.", "placeholders": {"minutes": {"type": "int", "example": "10"}}},
    "Compared with your level: {changes}": {"description": "Home and Train: under the facts of the level she is looking at, what is different from the level she set. The changes are a short list joined with a middle dot.", "placeholders": {"changes": {"type": "String", "example": "1 more set · 20 s less rest"}}},
    "of {target} g": {"description": "Home macros: the target under a macro's eaten grams, for example 'of 120 g'.", "placeholders": {"target": {"type": "String", "example": "120"}}},
    "{n} min · short day": {"description": "O03: the 15 minute preset, named as a short day.", "placeholders": {"n": {"type": "String", "example": "15"}}},
    "Your plan will be {plan}.": {"description": "Preview in the quick training sheet. plan is the plan name, where she trains and her level.", "placeholders": {"plan": {"type": "String", "example": "Build muscle · At the gym · Intermediate"}}},
    "Adding to {meal}": {"description": "Shown under the search bar after she taps Log on a meal row, so she knows which meal the next food goes to.", "placeholders": {"meal": {"type": "String", "example": "Lunch"}}},
    "{day} workout": {"description": "Default title of the share card when the workout has no name; the day is the weekday she trained.", "placeholders": {"day": {"type": "String", "example": "Tuesday"}}},
    "Copy of {name}": {"description": "Option that adds a copy of one of her own days to her plan.", "placeholders": {"name": {"type": "String", "example": "Upper"}}},
    "Day {number}": {"description": "A day's number in her plan.", "placeholders": {"number": {"type": "String", "example": "2"}}},
    "Done · warm-up {figure}": {"description": "R07 button while the warm-up switch is on; names the set it saves.", "placeholders": {"figure": {"type": "String", "example": "6 kg × 10"}}},
    "Warm-up saved · {figure}": {"description": "R09 bar after a warm-up set is saved.", "placeholders": {"figure": {"type": "String", "example": "6 kg × 10"}}},
    "Warm up with about {weight} first, around half your working weight.": {"description": "Quiet suggestion on R07 before the first set of a loaded move.", "placeholders": {"weight": {"type": "String", "example": "6 kg"}}},
    "Heaviest weight yet: {weight}": {"description": "What improved, on the New best chip.", "placeholders": {"weight": {"type": "String", "example": "14 kg"}}},
    "Most reps at {weight}: {reps}": {"description": "What improved, on the New best chip.", "placeholders": {"weight": {"type": "String", "example": "12 kg"}, "reps": {"type": "String", "example": "11"}}},
    "Most reps yet: {reps}": {"description": "What improved on a bodyweight move.", "placeholders": {"reps": {"type": "String", "example": "15"}}},
    "Longest hold yet: {time}": {"description": "What improved on a timed hold.", "placeholders": {"time": {"type": "String", "example": "45 seconds"}}},
    "You logged food on {logged} of 7 days": {"description": "Under the 7-day food chart: how many of the last 7 days have a meal logged.", "placeholders": {"logged": {"type": "String", "example": "4"}}},
    "{n}-day split": {"description": "Name of a coach split: the number of training days a week, 3, 4 or 5.", "placeholders": {"n": {"type": "String", "example": "4"}}},
    "{n} days": {"description": "A number of training days a week, 3, 4 or 5.", "placeholders": {"n": {"type": "String", "example": "4"}}},
    "{seconds} s less": {"description": "R09's shorter-rest button. seconds is the rest step in Western digits, e.g. 15.", "placeholders": {"seconds": {"type": "String", "example": "15"}}},
    "{seconds} s more": {"description": "R09's longer-rest button. seconds is the rest step in Western digits, e.g. 15.", "placeholders": {"seconds": {"type": "String", "example": "15"}}},
    "Shorten the rest by {seconds} seconds": {"description": "Spoken label of R09's shorter-rest button. seconds is the rest step in Western digits.", "placeholders": {"seconds": {"type": "String", "example": "15"}}},
    "Add {seconds} seconds to the rest": {"description": "Spoken label of R09's longer-rest button. seconds is the rest step in Western digits.", "placeholders": {"seconds": {"type": "String", "example": "15"}}},
    "Food, last {days} days": {"description": "The heading of Insights' food chart. days is the number of days it covers, in Western digits.", "placeholders": {"days": {"type": "String", "example": "7"}}},
    "{seconds} s": {"description": "A hold in seconds.", "placeholders": {"seconds": {"type": "String", "example": "45"}}},
    "Best set on {date}: {set}": {"description": "Screen reader label for one bar of a move's history.", "placeholders": {"date": {"type": "String", "example": "12 October 2026"}, "set": {"type": "String", "example": "40 kg × 10"}}},
    "Set {n}": {"description": "A set number in a finished session.", "placeholders": {"n": {"type": "String", "example": "2"}}},
    "Set {n} is now {set}": {"description": "Undo bar after fixing a set.", "placeholders": {"n": {"type": "String", "example": "2"}, "set": {"type": "String", "example": "40 kg × 10"}}},
    "{kg} kg bar": {"description": "A bar weight choice.", "placeholders": {"kg": {"type": "String", "example": "20"}}},
    "{bar} kg bar + {side} kg each side": {"description": "How to load a barbell.", "placeholders": {"bar": {"type": "String", "example": "20"}, "side": {"type": "String", "example": "10"}}},
    "Just the {bar} kg bar": {"description": "Empty bar.", "placeholders": {"bar": {"type": "String", "example": "20"}}},
    "Closest you can load: {total} kg. {bar} kg bar + {side} kg each side.": {"description": "Total not loadable exactly.", "placeholders": {"total": {"type": "String", "example": "41.5"}, "bar": {"type": "String", "example": "20"}, "side": {"type": "String", "example": "10.5"}}},
    "Plates on one side: {plates} kg": {"description": "Screen reader label of the plate diagram.", "placeholders": {"plates": {"type": "String", "example": "20, 10"}}},
    "Weight must be 0 to {max} kg": {"description": "Range error on the set editor's weight field.", "placeholders": {"max": {"type": "String", "example": "300"}}},
    "Reps must be 0 to {max}": {"description": "Range error on the set editor's reps field.", "placeholders": {"max": {"type": "String", "example": "100"}}},
    "Seconds must be 0 to {max}": {"description": "Range error on the set editor's seconds field.", "placeholders": {"max": {"type": "String", "example": "600"}}},
    "From EGP {price} a month": {"description": "Coach browsing.", "placeholders": {"price": {"type": "String", "example": "1,800"}}},
    "Open the profile of {name}": {"description": "Coach browsing.", "placeholders": {"name": {"type": "String", "example": "Sara"}}},
    "Years coaching: {n}": {"description": "Coach browsing.", "placeholders": {"n": {"type": "int", "example": "6"}}},
    "Languages: {list}": {"description": "Coach browsing.", "placeholders": {"list": {"type": "String", "example": "Arabic, English"}}},
    "Usually replies within {n} hours": {"description": "Coach browsing.", "placeholders": {"n": {"type": "int", "example": "12"}}},
    "Duration: {n} days": {"description": "Coach browsing.", "placeholders": {"n": {"type": "int", "example": "28"}}},
    "Live sessions a month: {n}": {"description": "Coach browsing.", "placeholders": {"n": {"type": "int", "example": "4"}}},
    "EGP {price}": {"description": "Coach browsing.", "placeholders": {"price": {"type": "String", "example": "1,800"}}},
    "Photo of {name}": {"description": "Coach browsing.", "placeholders": {"name": {"type": "String", "example": "Sara"}}},
    "{count} of 6 packages": {"description": "How many packages the coach has made, out of the 6 she may make.", "placeholders": {"count": {"type": "String", "example": "2"}}},
    "Pick a price between EGP {low} and EGP {high}.": {"description": "The range a coach may price a package in.", "placeholders": {"low": {"type": "String", "example": "200"}, "high": {"type": "String", "example": "30,000"}}},
    "Use {low} to {high} characters.": {"description": "The length a text field accepts.", "placeholders": {"low": {"type": "String", "example": "10"}, "high": {"type": "String", "example": "120"}}},
    "{count} days": {"description": "A length of time in days.", "placeholders": {"count": {"type": "String", "example": "28"}}},
    "{count} live video sessions a month": {"description": "How many live video sessions a package includes each month.", "placeholders": {"count": {"type": "String", "example": "2"}}},
    "{count} min": {"description": "A length in minutes.", "placeholders": {"count": {"type": "String", "example": "30"}}},
    "Whole pounds, from {low} to {high}.": {"description": "Hint under the price field.", "placeholders": {"low": {"type": "String", "example": "200"}, "high": {"type": "String", "example": "30,000"}}},
    "Saved. You receive EGP {amount}.": {"description": "Shown after a package is saved: what the coach receives, in whole pounds.", "placeholders": {"amount": {"type": "String", "example": "200"}}},
    "Add 1 to {max} lines, each {low} to {high} characters.": {"description": "Rule for the list of what a package includes.", "placeholders": {"max": {"type": "String", "example": "8"}, "low": {"type": "String", "example": "2"}, "high": {"type": "String", "example": "80"}}},
    "New requests wait once you reach {count} clients at once.": {"description": "Explains the most-clients setting.", "placeholders": {"count": {"type": "String", "example": "15"}}},
    "Members see EGP {price}": {"description": "The price a member pays for a package, in whole Egyptian pounds.", "placeholders": {"price": {"type": "String", "example": "230"}}},
    "{count} new requests": {"description": "Requests from members waiting for the coach.", "placeholders": {"count": {"type": "String", "example": "3"}}},
    "{count} unread chats": {"description": "Chats with something the coach has not read.", "placeholders": {"count": {"type": "String", "example": "2"}}},
    "{count} clients": {"description": "Clients being coached now.", "placeholders": {"count": {"type": "String", "example": "5"}}},
    "Tell {name} about you": {"description": "Joining a coach.", "placeholders": {"name": {"type": "String", "example": "Sara"}}},
    "I share these answers with {name}, my coach.": {"description": "Joining a coach.", "placeholders": {"name": {"type": "String", "example": "Sara"}}},
    "{name} usually replies within {hours} hours": {"description": "Joining a coach.", "placeholders": {"name": {"type": "String", "example": "Sara"}, "hours": {"type": "int", "example": "12"}}},
    "{name} will get back to you soon.": {"description": "Joining a coach.", "placeholders": {"name": {"type": "String", "example": "Sara"}}},
    "Use at least {min} characters": {"description": "A text field is too short.", "placeholders": {"min": {"type": "String", "example": "20"}}},
    "Use at most {max} characters": {"description": "A text field is too long.", "placeholders": {"max": {"type": "String", "example": "120"}}},
    "{min} to {max} characters": {"description": "Helper under a text field.", "placeholders": {"min": {"type": "String", "example": "10"}, "max": {"type": "String", "example": "120"}}},
    "Enter a year from {from} to {to}": {"description": "Year field out of range.", "placeholders": {"from": {"type": "String", "example": "1960"}, "to": {"type": "String", "example": "2026"}}},
    "Enter a whole number from {min} to {max}": {"description": "Number field out of range.", "placeholders": {"min": {"type": "String", "example": "0"}, "max": {"type": "String", "example": "50"}}},
    "Add at least {min}": {"description": "A list needs more rows.", "placeholders": {"min": {"type": "String", "example": "2"}}},
    "Choose between {min} and {max}": {"description": "A chip group needs a count in range.", "placeholders": {"min": {"type": "String", "example": "1"}, "max": {"type": "String", "example": "5"}}},
    "Education {n}": {"description": "Row title.", "placeholders": {"n": {"type": "String", "example": "1"}}},
    "Certificate {n}": {"description": "Row title.", "placeholders": {"n": {"type": "String", "example": "1"}}},
    "Feedback {n}": {"description": "Row title.", "placeholders": {"n": {"type": "String", "example": "1"}}},
    "Transformation {n}": {"description": "Row title.", "placeholders": {"n": {"type": "String", "example": "1"}}},
    "Within {hours} hours": {"description": "Reply time chip.", "placeholders": {"hours": {"type": "String", "example": "12"}}},
    "Uploading photo {done} of {total}": {"description": "Send progress.", "placeholders": {"done": {"type": "String", "example": "2"}, "total": {"type": "String", "example": "7"}}},
    "You can apply again on {date}.": {"description": "Rejected application, date already formatted.", "placeholders": {"date": {"type": "String", "example": "20 Nov 2026"}}},
    "You: {text}": {"description": "Chat list preview: the last line was written by her. text is the start of that line.", "placeholders": {"text": {"type": "String", "example": "See you at 6"}}},
    "{count} unread": {"description": "Spoken label of the unread badge on a chat row. count is a number.", "placeholders": {"count": {"type": "String", "example": "3"}}},
    "{package} · {days} days left": {"description": "Chat header line under the other person's name. package is the package name, days a whole number above zero.", "placeholders": {"package": {"type": "String", "example": "Monthly coaching"}, "days": {"type": "String", "example": "12"}}},
    "{package} · ends today": {"description": "Chat header line on the last day of the coaching. package is the package name.", "placeholders": {"package": {"type": "String", "example": "Monthly coaching"}}},
    "Block {name}?": {"description": "Title of the sheet that asks her to confirm blocking the other person in a chat.", "placeholders": {"name": {"type": "String", "example": "Mona"}}},
    "{name} cannot write to you after this, and you will not see her messages. You can undo it later.": {"description": "Body of the block confirmation in a chat. name is the other person.", "placeholders": {"name": {"type": "String", "example": "Mona"}}},
    "{name} is blocked.": {"description": "Shown once the other person in a chat is blocked.", "placeholders": {"name": {"type": "String", "example": "Mona"}}},
    "{minutes} min": {"description": "Length of a live session card in a chat.", "placeholders": {"minutes": {"type": "String", "example": "45"}}},
    "{day} at {time}": {"description": "When a live session starts. day is Today, Tomorrow-style or a date; time is hh:mm.", "placeholders": {"day": {"type": "String", "example": "Friday"}, "time": {"type": "String", "example": "18:30"}}},
    "Show all {count}": {"description": "Coach desk", "placeholders": {"count": {"type": "String", "example": "12"}}},
    "{name} asked to join": {"description": "Coach desk", "placeholders": {"name": {"type": "String", "example": "Mona"}}},
    "{goal} · {level} · {days} days a week · {place}": {"description": "Coach desk", "placeholders": {"goal": {"type": "String", "example": "Get stronger"}, "level": {"type": "String", "example": "Beginner"}, "days": {"type": "String", "example": "3"}, "place": {"type": "String", "example": "At home"}}},
    "Client {tag}": {"description": "Coach desk", "placeholders": {"tag": {"type": "String", "example": "#a1b2"}}},
    "Live session today at {time}": {"description": "Coach desk", "placeholders": {"time": {"type": "String", "example": "18:30"}}},
    "No message for {days} days": {"description": "Coach desk", "placeholders": {"days": {"type": "String", "example": "8"}}},
    "{days} days left": {"description": "Coach desk", "placeholders": {"days": {"type": "String", "example": "12"}}},
    "Open the details of {name}": {"description": "Coach desk", "placeholders": {"name": {"type": "String", "example": "Mona"}}},
    "Open the chat with {name}": {"description": "Coach desk", "placeholders": {"name": {"type": "String", "example": "Mona"}}},
    "{used} of {included}": {"description": "Coach desk", "placeholders": {"used": {"type": "String", "example": "2"}, "included": {"type": "String", "example": "4"}}},
    "With you since {start} · ends {end}": {"description": "Coach desk", "placeholders": {"start": {"type": "String", "example": "2/10/2026"}, "end": {"type": "String", "example": "30/10/2026"}}},
    "Plan for {name}": {"description": "The client's first name.", "placeholders": {"name": {"type": "String", "example": "Mai"}}},
    "Publish to {name}": {"description": "The client's first name.", "placeholders": {"name": {"type": "String", "example": "Mai"}}},
    "Published. {name} can see it now.": {"description": "The client's first name.", "placeholders": {"name": {"type": "String", "example": "Mai"}}},
    "Version {n}": {"description": "A plan's revision number.", "placeholders": {"n": {"type": "String", "example": "2"}}},
    "Add to {slot}": {"description": "A meal slot: breakfast, lunch, dinner or snack.", "placeholders": {"slot": {"type": "String", "example": "Lunch"}}},
    "{name} avoids: {list}": {"description": "The client's name, then the allergies she declared.", "placeholders": {"name": {"type": "String", "example": "Mai"}, "list": {"type": "String", "example": "sesame, nuts"}}},
    "Contains {allergens}, which she avoids.": {"description": "Allergens in a meal item.", "placeholders": {"allergens": {"type": "String", "example": "sesame"}}},
    "About {kcal} kcal, {protein} g protein": {"description": "A day's nutrition worked out from the food tables.", "placeholders": {"kcal": {"type": "String", "example": "1,850"}, "protein": {"type": "String", "example": "92"}}},
    "Servings: {n}": {"description": "Servings of a recipe.", "placeholders": {"n": {"type": "String", "example": "1.5"}}},
    "Sessions used: {used} of {included}": {"description": "Live sessions used out of the package's.", "placeholders": {"used": {"type": "String", "example": "1"}, "included": {"type": "String", "example": "4"}}},
    "Send to {name}": {"description": "The client's first name.", "placeholders": {"name": {"type": "String", "example": "Mai"}}},
    "Session sent. {name} can confirm it.": {"description": "The client's first name.", "placeholders": {"name": {"type": "String", "example": "Mai"}}},
    "Your coaching with {coach} has ended. Your plans stay here to read.": {"description": "The coach's name.", "placeholders": {"coach": {"type": "String", "example": "Sara"}}},
    "Days left: {n}": {"description": "Days left in a coaching package.", "placeholders": {"n": {"type": "String", "example": "12"}}},
    "Today's workout: {name}": {"description": "The name of the coach's workout for today.", "placeholders": {"name": {"type": "String", "example": "Lower body"}}},
    "Next session: {when}": {"description": "Day and time of the next live session.", "placeholders": {"when": {"type": "String", "example": "Sat 24 Oct, 18:30"}}},
    "Contains {allergens}, which you avoid.": {"description": "Allergens in a meal item, for the client.", "placeholders": {"allergens": {"type": "String", "example": "sesame"}}},
    "{minutes} min session": {"description": "Length of a live session in minutes.", "placeholders": {"minutes": {"type": "String", "example": "45"}}},
    "{count} of 30 items": {"description": "How many photos and results she has added, out of the 30 allowed.", "placeholders": {"count": {"type": "String", "example": "4"}}},
    "Transformation, {weeks} weeks": {"description": "Title of a before and after item.", "placeholders": {"weeks": {"type": "String", "example": "8"}}},
    "Feedback from {name}": {"description": "Title of a client feedback item.", "placeholders": {"name": {"type": "String", "example": "Mona"}}},
    "Write {low} to {high} characters.": {"description": "Length rule for a text.", "placeholders": {"low": {"type": "String", "example": "10"}, "high": {"type": "String", "example": "600"}}},
    "Over {n} weeks": {"description": "Weeks a transformation took.", "placeholders": {"n": {"type": "int", "example": "12"}}},
    "{days, plural, one{1 day left} other{{days} days left}}": {"description": "A coaching package's countdown. A plural message because Arabic counts agree differently at 1, 2, 3 to 10 and 11 and up.", "placeholders": {"days": {"type": "int", "example": "12"}}},
    "{count, plural, one{1 week} other{{count} weeks}}": {"description": "A package length in weeks, taken from the template's own duration.", "placeholders": {"count": {"type": "int", "example": "4"}}},
    "{count, plural, one{1 live session a month} other{{count} live sessions a month}}": {"description": "Live sessions a month, taken from the template's own number.", "placeholders": {"count": {"type": "int", "example": "4"}}},
    "{weeks}, {sessions}": {"description": "The package template picker label: length, then live sessions a month, both already worded.", "placeholders": {"weeks": {"type": "String", "example": "4 weeks"}, "sessions": {"type": "String", "example": "2 live sessions a month"}}},
    "{weeks} of coaching with me": {"description": "A package template's title. weeks is already worded, e.g. 4 weeks.", "placeholders": {"weeks": {"type": "String", "example": "4 weeks"}}},
    "You already have {count} packages. Edit one of them instead.": {"description": "Refusal when she is at the package limit.", "placeholders": {"count": {"type": "String", "example": "6"}}},
    "You have all {count} packages.": {"description": "Shown instead of the add button at the package limit.", "placeholders": {"count": {"type": "String", "example": "6"}}},
    "You have {count} items. Remove one to add another.": {"description": "Portfolio media at its limit.", "placeholders": {"count": {"type": "String", "example": "30"}}},
    "Review takes up to {days} working days.": {"description": "Coach application review time.", "placeholders": {"days": {"type": "String", "example": "5"}}},
    "Own Hub's reviewer is reading it. This takes up to {days} working days, and we will tell you here.": {"description": "Coach application status while it is in review.", "placeholders": {"days": {"type": "String", "example": "5"}}},
    "You can apply again {days} days after the decision.": {"description": "Coach re-apply wait, from the contract's own number.", "placeholders": {"days": {"type": "String", "example": "30"}}},
    "That photo could not be used. Choose a JPEG or PNG under {mb} MB.": {"description": "Application photo refused; mb is the upload limit.", "placeholders": {"mb": {"type": "String", "example": "10"}}},
    "Add {min} to {max}. A photo of the degree is optional.": {"description": "Application step 2, education.", "placeholders": {"min": {"type": "String", "example": "1"}, "max": {"type": "String", "example": "6"}}},
    "Add {min} to {max}. Each one needs a photo.": {"description": "Application step 3, certificates.", "placeholders": {"min": {"type": "String", "example": "1"}, "max": {"type": "String", "example": "10"}}},
    "Choose {min} to {max}, then tell us about your experience.": {"description": "Application step 4, specialties.", "placeholders": {"min": {"type": "String", "example": "1"}, "max": {"type": "String", "example": "5"}}},
    "Add {min} to {max} messages from women you trained.": {"description": "Application step 5, testimonials.", "placeholders": {"min": {"type": "String", "example": "2"}, "max": {"type": "String", "example": "10"}}},
    "Add {min} to {max}. The photos are seen only by Own Hub's woman reviewer.": {"description": "Application step 6, transformations.", "placeholders": {"min": {"type": "String", "example": "1"}, "max": {"type": "String", "example": "6"}}},
    "You added too many certificates. The most is {max}.": {"description": "Refusal for too many certificates.", "placeholders": {"max": {"type": "String", "example": "10"}}},
    "Pick a time at least {minutes} minutes from now.": {"description": "Session scheduling lead time.", "placeholders": {"minutes": {"type": "String", "example": "15"}}},
    "Type the date and time like {example}.": {"description": "Session date field hint; example is a format sample.", "placeholders": {"example": {"type": "String", "example": "2026-11-05 18:30"}}},
    "Under EGP {n}": {"description": "The lowest budget band for a coach search; n is the band's own upper bound.", "placeholders": {"n": {"type": "String", "example": "1,500"}}},
    "Over EGP {n}": {"description": "The highest budget band for a coach search; n is the band's own lower bound.", "placeholders": {"n": {"type": "String", "example": "3,000"}}},
    "EGP {low} to {high}": {"description": "The middle budget band for a coach search, from the band's own bounds.", "placeholders": {"low": {"type": "String", "example": "1,500"}, "high": {"type": "String", "example": "3,000"}}},
    "The chat becomes read only. Your plans stay with you. {coach} will no longer see your answers.": {"description": "Shown when a member confirms ending her coaching. coach is the coach's name.", "placeholders": {"coach": {"type": "String", "example": "Sara"}}},
    "Waiting for {coach}'s answer": {"description": "A member's coaching request that the coach has not answered yet. coach is the coach's name.", "placeholders": {"coach": {"type": "String", "example": "Sara"}}},
    "{coach} could not take you this time": {"description": "A member's request was declined. coach is the coach's name.", "placeholders": {"coach": {"type": "String", "example": "Sara"}}},
    "No message from you in {days} days": {"description": "Why a client is on the coach's follow up list. days is a number.", "placeholders": {"days": {"type": "String", "example": "7"}}},
    "EGP {price} when payments open": {"description": "Coach browsing while payments are off: the package price as it will be.", "placeholders": {"price": {"type": "String", "example": "2,000"}}},
    "{count, plural, one{1 client} other{{count} clients}}": {"description": "Coach space pill. A plural message because Arabic counts agree differently at 1, 2, 3 to 10 and 11 and up.", "placeholders": {"count": {"type": "int", "example": "12"}}},
    "{count, plural, one{1 new request} other{{count} new requests}}": {"description": "Coach space pill. A plural message because Arabic counts agree differently at 1, 2, 3 to 10 and 11 and up.", "placeholders": {"count": {"type": "int", "example": "2"}}},
    "{count, plural, one{1 unread chat} other{{count} unread chats}}": {"description": "Coach space pill. A plural message because Arabic counts agree differently at 1, 2, 3 to 10 and 11 and up.", "placeholders": {"count": {"type": "int", "example": "3"}}},
    "Duration: {days, plural, one{1 day} other{{days} days}}": {"description": "A package length on a coach's page. A plural message because Arabic counts agree differently at 1, 2, 3 to 10 and 11 and up.", "placeholders": {"days": {"type": "int", "example": "28"}}},
    "Over {weeks, plural, one{1 week} other{{weeks} weeks}}": {"description": "A transformation's length on a coach's page. A plural message because Arabic counts agree differently at 1, 2, 3 to 10 and 11 and up.", "placeholders": {"weeks": {"type": "int", "example": "12"}}},
    "Transformation, {weeks, plural, one{1 week} other{{weeks} weeks}}": {"description": "A transformation's title in the coach's list. A plural message because Arabic counts agree differently at 1, 2, 3 to 10 and 11 and up.", "placeholders": {"weeks": {"type": "int", "example": "12"}}},
    "{eaten} of {target} kcal": {"description": "Home's one Eat line: calories eaten so far against today's target, in Western digits, e.g. 1,240 of 1,624 kcal.", "placeholders": {"eaten": {"type": "String", "example": "1,240"}, "target": {"type": "String", "example": "1,624"}}},
    "Set {n} of {total}": {"description": "R07: which set of the move she is on.", "placeholders": {"n": {"type": "String", "example": "2"}, "total": {"type": "String", "example": "3"}}},
    "Today: {weight} on {name}": {"description": "R03 weights line: the step up she has earned on a loaded move, from her last session.", "placeholders": {"weight": {"type": "String", "example": "22.5 kg"}, "name": {"type": "String", "example": "Hip thrust"}}},
    "Same weight on {name} as last time, until it feels steady": {"description": "R03 weights line: a loaded move that stays at last time's weight.", "placeholders": {"name": {"type": "String", "example": "Leg press"}}},
    "{n} weeks": {"description": "Weeks in a plan", "placeholders": {"n": {"type": "String", "example": "4"}}},
    "Week {n} of {total}": {"description": "Which week of her plan she is in", "placeholders": {"n": {"type": "String", "example": "2"}, "total": {"type": "String", "example": "4"}}},
    "Your plan starts {date}": {"description": "When her multi-week plan starts", "placeholders": {"date": {"type": "String", "example": "1 Nov"}}},
    "Swaps ({n})": {"description": "Number of approved swaps for a meal item", "placeholders": {"n": {"type": "String", "example": "2"}}},
    "Your coach's target: {kcal} calories and {protein} g protein": {"description": "Daily target set by coach for client", "placeholders": {"kcal": {"type": "String", "example": "1600"}, "protein": {"type": "String", "example": "110"}}},
    "{amount} {unit} remaining": {"description": "Under a progress bar: how much of the day's target is left, for example 80 g remaining.", "placeholders": {"amount": {"type": "String", "example": "80"}, "unit": {"type": "String", "example": "g"}}},
    "{label}: {current} of {target} {unit}. {status}.": {"description": "Screen reader text for a progress bar: name, amount against target, then the status line.", "placeholders": {"label": {"type": "String", "example": "Protein"}, "current": {"type": "String", "example": "30"}, "target": {"type": "String", "example": "120"}, "unit": {"type": "String", "example": "g"}, "status": {"type": "String", "example": "90 g remaining"}}},
    "Record a video (up to {seconds} seconds)": {"description": "Chat attach sheet: the longest video she can send, from the coaching limits.", "placeholders": {"seconds": {"type": "String", "example": "30"}}},
    "That file is too big. A photo is up to {photoMb} MB and a video is up to {videoMb} MB.": {"description": "Chat: the two size limits, from the coaching limits.", "placeholders": {"photoMb": {"type": "String", "example": "3"}, "videoMb": {"type": "String", "example": "25"}}},
    "Videos can be up to {seconds} seconds. Choose a shorter one.": {"description": "Chat: the longest video she can send, from the coaching limits.", "placeholders": {"seconds": {"type": "String", "example": "30"}}},
    "Your new address starts working at {time}.": {"description": "When the coach's new InstaPay address starts.", "placeholders": {"time": {"type": "String", "example": "14:30"}}},
    "{name} (name as shown by your bank)": {"description": "The coach's account name to check on the bank screen.", "placeholders": {"name": {"type": "String", "example": "Rahma M."}}},
    "Time left {time}": {"description": "Countdown to the end of a payment request.", "placeholders": {"time": {"type": "String", "example": "23:41"}}},
    "Pictures added: {count}": {"description": "How many screenshots she picked.", "placeholders": {"count": {"type": "String", "example": "2"}}},
    "Your coach received {amount}. Pay the rest to start.": {"description": "Shown when the coach received less than the price.", "placeholders": {"amount": {"type": "String", "example": "300 EGP"}}},
    "Your coach accepted {amount} instead. Do you agree?": {"description": "Shown when the coach takes a lower amount in writing.", "placeholders": {"amount": {"type": "String", "example": "450 EGP"}}},
    "You can start now. This stays open until {date} while your coach confirms.": {"description": "Bounded access while the coach confirms.", "placeholders": {"date": {"type": "String", "example": "27/10 14:32"}}},
    "Your coach says you paid {reference}. Is that right?": {"description": "The coach reported a payment for the client to confirm.", "placeholders": {"reference": {"type": "String", "example": "OH-4821"}}},
    "A new address starts working after {hours} hours. Clients with a payment waiting keep paying the old one, and we tell them.": {"description": "Coach InstaPay address screen: how long a new address waits before it works. hours is the server's address delay.", "placeholders": {"hours": {"type": "String", "example": "24"}}},
    "For a client who is pregnant or after a birth, the lowest daily goal is {kcal} kcal.": {"description": "Meal plan editor: why a goal is refused for a pregnant or postpartum client. kcal is the stage floor from the calorie safety rules, with thousands separators.", "placeholders": {"kcal": {"type": "String", "example": "1,800"}}},
    "Protein can be at most {percent}% of the day's calories.": {"description": "Meal plan editor: why a protein goal is refused. percent is the largest protein share from the calorie safety rules.", "placeholders": {"percent": {"type": "String", "example": "35"}}},
    "This request has expired. If you already paid, you can still send your proof for {days} days.": {"description": "Payment screen after the 24 hour request ran out. days is how long a late proof is still accepted.", "placeholders": {"days": {"type": "String", "example": "7"}}},
    "We do not set weight-loss targets under {age}. Your target keeps your weight where it is. Please talk to your doctor before changing how you eat.": {"description": "Eat tab note for a woman under the adult age. age is the adult age from the calorie safety rules.", "placeholders": {"age": {"type": "String", "example": "18"}}},
    "We never set a target below {kcal} kcal.": {"description": "Eat tab note when her target was lifted to the floor. kcal is the floor from the calorie safety rules, with thousands separators.", "placeholders": {"kcal": {"type": "String", "example": "1,200"}}},
  };

  const en = { '@@locale': 'en' }; const ar = { '@@locale': 'ar' };
  for (const [src, tgt] of Object.entries(dict)) {
    const k = uniqueKey(slugFor(src), src);
    en[k] = src; ar[k] = tgt;
    const meta = PARAMETERISED[src];
    if (meta) {
      // Arabic needs its own metadata block too, or gen_l10n treats the ar
      // message as a plain string and the placeholder never substitutes.
      en['@' + k] = meta; ar['@' + k] = meta;
    }
  }
  const declared = Object.keys(PARAMETERISED);
  const missing = declared.filter(d => !(d in dict));
  if (missing.length) {
    console.log('  WARNING: parameterised strings not found in the dictionary:');
    for (const m of missing) console.log('    ' + m.slice(0, 70));
  }
  console.log('  parameterised messages:', declared.length - missing.length, 'of', declared.length);
  fs.writeFileSync(path.join(OUT, 'app_en.arb'), JSON.stringify(en, null, 2));
  fs.writeFileSync(path.join(OUT, 'app_ar.arb'), JSON.stringify(ar, null, 2));
  console.log('ARB files written:', Object.keys(dict).length, 'strings');
} else {
  console.log('no dictionary yet — ARB files skipped');
}
console.log('tokens and routes written for', all.length, 'screens');

// Write through to the app, rather than trusting anyone to copy by hand.
//
// These files are generated here and CONSUMED by `app/`. The copy between the
// two used to be manual, and forgetting it fails **silently**: `flutter
// gen-l10n` happily re-reads the stale ARB still sitting in app/lib/l10n, so a
// string that was corrected here appears not to have been corrected at all.
// That cost an hour of debugging a generator that was already right. A
// documented step can be forgotten; this cannot.
const APP = path.join(here, '../../app');
const SYNC = [
  ['app_en.arb', 'lib/l10n'],
  ['app_ar.arb', 'lib/l10n'],
  ['app_routes.dart', 'lib/routing'],
  ['app_tokens.dart', 'lib/theme'],
];
let synced = 0;
let arbChanged = false;
for (const [file, dest] of SYNC) {
  const from = path.join(OUT, file);
  const to = path.join(APP, dest, file);
  // Absent app checkout, or a folder that has moved: say so, do not create it.
  if (!fs.existsSync(from) || !fs.existsSync(path.dirname(to))) continue;
  const next = fs.readFileSync(from);
  if (fs.existsSync(to) && fs.readFileSync(to).equals(next)) continue;
  fs.writeFileSync(to, next);
  synced++;
  if (file.endsWith('.arb')) arbChanged = true;
  console.log('  synced ->', path.relative(path.join(here, '../..'), to));
}
console.log('app files synced:', synced);
if (arbChanged) {
  console.log('  ARB changed — run `flutter gen-l10n` in app/ to regenerate AppL10n');
}
