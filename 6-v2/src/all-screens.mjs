import { screens as signup } from './screens-signup.mjs';
import { screens as onboarding } from './screens-onboarding.mjs';
import { screens as today } from './screens-today.mjs';
import { screens as train } from './screens-train.mjs';
import { screens as eat } from './screens-eat.mjs';
import { screens as progress } from './screens-progress.mjs';
import { screens as cycle } from './screens-cycle.mjs';
import { screens as coached } from './screens-coached.mjs';
import { screens as coachplan } from './screens-coachplan.mjs';
import { screens as community } from './screens-community.mjs';
import { screens as coaching } from './screens-coaching.mjs';
import { screens as account } from './screens-account.mjs';
import { screens as coach } from './screens-coach.mjs';
import { screens as coachbrand } from './screens-coachbrand.mjs';
import { screens as coachbuild } from './screens-coachbuild.mjs';
import { screens as firstrun } from './screens-firstrun.mjs';
import { screens as firstweek } from './screens-firstweek.mjs';
import { screens as assistant } from './screens-assistant.mjs';
import { screens as admin } from './screens-admin.mjs';
import { screens as inventory, flows } from './inventory.mjs';

const built = [...signup, ...onboarding, ...today, ...train, ...eat, ...progress, ...cycle, ...coached, ...community, ...coaching, ...account, ...coach, ...coachbrand, ...coachplan, ...coachbuild, ...firstrun, ...firstweek, ...assistant, ...admin];
const byId = new Map(built.map(s => [s.id, s]));

// A screen designed after the mockup was drawn has no markup here, and saying so
// is the honest answer rather than a throw.
//
// The throw below is the integrity check that stops an inventory row being added
// and then forgotten — a route to a screen nobody drew. It was right until two
// screens arrived the other way round: C09b and C10b were designed straight into
// Flutter during the verification build, so the inventory and the Dart both have
// them and the mockup never will. The generator then refused to run AT ALL, which
// took `app_routes.dart`, `app_tokens.dart` and both ARB files with it: nobody
// could add a UI string to this project until this line changed.
//
// So the exception is per screen and explicit. `noMockup: true` in inventory.mjs
// is a claim someone had to write down, which is what makes it different from a
// silent fallback that would let a genuinely forgotten screen through.
export const all = inventory.map(inv => {
  const b = byId.get(inv.id);
  if (!b && inv.noMockup) {
    return { ...inv, html: '', metric: '', note: 'Designed in Flutter, after the mockup. No markup here by decision; see inventory.mjs.' };
  }
  if (!b) throw new Error(`no markup for screen ${inv.id}`);
  return { ...inv, ...b };
});
export { flows };
export const missingMarkup = inventory.filter(i => !byId.has(i.id)).map(i => i.id);
export const orphanMarkup = built.filter(b => !inventory.some(i => i.id === b.id)).map(b => b.id);
export function linkReport() {
  const ids = new Set(all.map(s => s.id));
  const broken = [];
  const outgoing = {};
  for (const s of all) {
    const targets = [...s.html.matchAll(/data-go="([^"]+)"/g)].map(m => m[1]).filter(Boolean);
    outgoing[s.id] = [...new Set(targets)];
    for (const t of outgoing[s.id]) if (!ids.has(t)) broken.push(`${s.id} → ${t}`);
  }
  const reachable = new Set(['C01']);
  let grew = true;
  while (grew) { grew = false; for (const id of [...reachable]) for (const t of (outgoing[id] || [])) if (!reachable.has(t)) { reachable.add(t); grew = true; } }
  const unreachable = all.map(s => s.id).filter(id => !reachable.has(id));
  const deadEnds = all.filter(s => (outgoing[s.id] || []).length === 0).map(s => s.id);
  return { broken, unreachable, deadEnds, outgoing };
}
