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
      description: 'R13 undo snackbar after a whole move.',
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
    "Next move · {move}": {"description": "R13 primary button. The move she goes back to, replacing the fixed 'Next move · step-back lunge'.", "placeholders": {"move": {"type": "String", "example": "step-back lunge"}}},
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
    "Sets done: {done} of {total}": {"description": "R07/R08/R09/R13 set bar: sets of today's session behind her, out of all of them.", "placeholders": {"done": {"type": "String", "example": "4"}, "total": {"type": "String", "example": "12"}}},
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
    "{count, plural, one{1 more and the week counts.} other{{count} more and the week counts.}}": {"description": "T01 week line while sessions are still to go. A plural message because Arabic says تمرين واحد, تمرينين, 3 تمارين and 11 تمرين.", "placeholders": {"count": {"type": "int", "example": "3"}}},
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
