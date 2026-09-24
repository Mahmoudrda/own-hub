// Generates the Flutter handoff: design tokens, route table, ARB localisation files.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { all, flows } from './all-screens.mjs';
import { C, TY, R, M } from './tokens.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(here, '../flutter');
fs.mkdirSync(OUT, { recursive: true });

const dartColor = (hex) => `Color(0xFF${hex.replace('#', '').toUpperCase()})`;
const colorLines = Object.entries(C).filter(([, v]) => /^#([0-9a-f]{6})$/i.test(v)).map(([k, v]) => `  static const ${k} = ${dartColor(v)};`).join('\n');
const textLines = Object.entries(TY).map(([k, [size, lh, w]]) => `  static const ${k} = TextStyle(fontFamily: _family, fontSize: ${size}, height: ${(lh / size).toFixed(3)}, fontWeight: FontWeight.w${w});`).join('\n');
const radiusLines = Object.entries(R).map(([k, v]) => `  static const ${k} = ${v}.0;`).join('\n');
const motionLines = Object.entries(M).filter(([, v]) => typeof v === 'number').map(([k, v]) => `  static const ${k} = Duration(milliseconds: ${v});`).join('\n');

fs.writeFileSync(path.join(OUT, 'app_tokens.dart'), `// GENERATED from 6-v2/src/tokens.mjs — do not edit by hand.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
${colorLines}
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
        secondaryContainer: AppColors.secondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        tertiaryContainer: AppColors.tertiaryContainer,
        onTertiaryContainer: AppColors.onTertiaryContainer,
        error: AppColors.error,
        onError: AppColors.onError,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        outlineVariant: AppColors.outlineVariant,
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
    '{logged} of {total} logged days': {
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
    '{meal} logged · {kcal} kcal': {
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
