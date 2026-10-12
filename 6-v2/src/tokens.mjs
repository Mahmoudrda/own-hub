// v2 design language: Material 3 colour roles, pink, tuned for Egyptian light and cheap screens.
//
// SIX FOREGROUND ROLES WERE DARKENED IN QA ROUND TWO (R2-41), AND NOT ONE HUE
// MOVED. A SEVENTH WAS, AND ROUND THREE PUT IT BACK.
//
// `contrast.dart` is a complete WCAG 2.1 implementation and it had only ever
// been pointed at coach-authored portfolio themes; the product's own palette
// had never been measured. Run through it, nine shipping pairs were under
// threshold — rose on every raised surface (3.91 on surfaceHigh, 4.01 on
// canvas, 4.14 on surfaceContainer against a 4.50 floor), sage on its own sage
// card (4.40), the error tone on its own card (4.4988, under by a rounding
// error), the progress fill on sage (2.80 against a 3.00 non-text floor) and
// outlineVariant on every page (1.27, which was reported as an outlined card
// with no visible border at all — see the note below on why that was the card
// asking for the wrong role rather than the role being wrong).
//
// Six were fixed by lowering HSL lightness with hue and saturation held
// exactly, so this is the same rose and the same sage, a shade deeper:
//   primary        #B4526E -> #A24661   primaryDim   #A8455F -> #9A3F57
//   tertiary       #4F7359 -> #4C6E55   tertiarySoft #6E9478 -> #65896F
//   error          #A84A4A -> #A34848   outline      #9C838A -> #977C84
//
// OUTLINEVARIANT WAS THE SEVENTH AND IT HAS BEEN PUT BACK.
//
// It went #EBDCDF -> #B47B87, thirty points of L* while the other six moved one
// to six, and it landed at 3.27:1 against the page: a near-white hairline
// became a mid rose. What that bought was a number. What it cost was measured
// in QA round three — a missed week became the brightest, most saturated bar on
// P01's chart at 1.14:1 from a repaired one, an unselected answer ring sat
// 1.71:1 from the selected tick it has to be told apart from, the two boundary
// roles were 1.11:1 from each other, and thirteen outlined cards across twelve
// shipping screens grew a rose border.
//
// `contrast.dart` already argued the other way, in its own words: 1.4.11
// applies to boundaries that CARRY MEANING, `outlineVariant` exists in M3 for
// decoration, and `outline` (tone 50) is the role for a boundary that means
// something. So the meaningful boundaries moved to `outline` — the outlined
// card border, the missed-week bar, the unselected answer ring, the story ring,
// the slider track, the two waveforms — and `outlineVariant` went back to what
// it was. It is now only ever a hairline between rows, which is the one thing
// 1.4.11 does not ask about.
//
// Surfaces were deliberately NOT lightened to buy the ratios. They are an
// elevation ladder and moving them would flatten depth across every screen.
//
// After any edit here, re-run `node 6-v2/src/build-flutter.mjs` and then
// `flutter test test/qa/round2/r2_41_app_palette_contrast_test.dart`, which
// measures every pair the shipping code actually draws.
export const C = {
  primary: '#A24661', onPrimary: '#FFFFFF', primaryContainer: '#FFD9E3', onPrimaryContainer: '#4A1C2E',
  primaryDim: '#9A3F57', primarySoft: '#F8E1E7',
  secondary: '#75565E', onSecondary: '#FFFFFF', secondaryContainer: '#F5E3E8', onSecondaryContainer: '#412B32',
  tertiary: '#4C6E55', onTertiary: '#FFFFFF', tertiaryContainer: '#DDEDE1', onTertiaryContainer: '#1E3826', tertiarySoft: '#65896F',
  error: '#A34848', onError: '#FFFFFF', errorContainer: '#FBE0E0', onErrorContainer: '#4E1C1C',
  amber: '#8A5A17', amberContainer: '#FBEBD6',
  surface: '#FFF8F9', surfaceLowest: '#FFFFFF', surfaceLow: '#FFF1F4', surfaceContainer: '#FBEAEF',
  surfaceHigh: '#F6E3E9', surfaceHighest: '#F0DBE2',
  onSurface: '#241A1E', onSurfaceVariant: '#6B5C61', outline: '#977C84', outlineVariant: '#EBDCDF',
  inverseSurface: '#37292E', inverseOnSurface: '#FFECF0', scrim: 'rgba(36,26,30,.45)',
  canvas: '#F2E8EB', ink: '#241A1E',
};
export const F = {
  ui: "'Rubik',system-ui,-apple-system,sans-serif",
  mono: "'IBM Plex Mono',ui-monospace,monospace",
};
// size / line-height / weight
export const TY = {
  display: [32, 40, 600], headline: [26, 33, 600], titleL: [20, 26, 600], titleM: [17, 23, 600],
  titleS: [15, 20, 600], body: [16, 24, 400], bodyM: [15, 22, 400], label: [15, 20, 500], nav: [12, 16, 500],
};
export const R = { xs: 8, sm: 12, md: 16, lg: 20, xl: 28, full: 999 };
export const E = {
  e1: '0 1px 2px rgba(36,26,30,.06),0 1px 3px rgba(36,26,30,.05)',
  e2: '0 2px 8px rgba(36,26,30,.08)',
  e3: '0 8px 24px rgba(36,26,30,.12)',
};
export const M = {
  fast: 150, short: 220, med: 320, long: 460,
  emphasized: 'cubic-bezier(.2,0,0,1)', decel: 'cubic-bezier(.05,.7,.1,1)', accel: 'cubic-bezier(.3,0,.8,.15)',
  spring: 'cubic-bezier(.34,1.56,.64,1)',
};
