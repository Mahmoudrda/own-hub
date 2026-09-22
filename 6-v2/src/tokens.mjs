// v2 design language: Material 3 colour roles, pink, tuned for Egyptian light and cheap screens.
export const C = {
  primary: '#B4526E', onPrimary: '#FFFFFF', primaryContainer: '#FFD9E3', onPrimaryContainer: '#4A1C2E',
  primaryDim: '#A8455F', primarySoft: '#F8E1E7',
  secondary: '#75565E', onSecondary: '#FFFFFF', secondaryContainer: '#F5E3E8', onSecondaryContainer: '#412B32',
  tertiary: '#4F7359', onTertiary: '#FFFFFF', tertiaryContainer: '#DDEDE1', onTertiaryContainer: '#1E3826', tertiarySoft: '#6E9478',
  error: '#A84A4A', onError: '#FFFFFF', errorContainer: '#FBE0E0', onErrorContainer: '#4E1C1C',
  amber: '#8A5A17', amberContainer: '#FBEBD6',
  surface: '#FFF8F9', surfaceLowest: '#FFFFFF', surfaceLow: '#FFF1F4', surfaceContainer: '#FBEAEF',
  surfaceHigh: '#F6E3E9', surfaceHighest: '#F0DBE2',
  onSurface: '#241A1E', onSurfaceVariant: '#6B5C61', outline: '#9C838A', outlineVariant: '#EBDCDF',
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
