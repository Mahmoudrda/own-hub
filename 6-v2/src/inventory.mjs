// Every screen in the product, in the order a person meets them.
// flow ids group screens into wireframe rows and prototype chapters.
export const flows = [
  { id: 'signup', role: 'client', title: 'Sign-up and women-only verification' },
  { id: 'onboarding', role: 'client', title: 'Client setup' },
  { id: 'today', role: 'client', title: 'Today and logging' },
  { id: 'train', role: 'client', title: 'Train' },
  { id: 'eat', role: 'client', title: 'Eat' },
  { id: 'progress', role: 'client', title: 'Progress and rewards' },
  { id: 'cycle', role: 'client', title: 'My cycle' },
  { id: 'coached', role: 'client', title: 'Coached: plan, logging, chat' },
  { id: 'community', role: 'client', title: 'Community' },
  { id: 'coaching', role: 'client', title: 'Coaching' },
  { id: 'account', role: 'client', title: 'Profile, notifications and safety' },
  { id: 'coach-setup', role: 'coach', title: 'Coach setup' },
  { id: 'coach', role: 'coach', title: 'Coach app' },
  { id: 'coachbrand', role: 'coach', title: 'Coach: portfolio, ads and results' },
  { id: 'coachplan', role: 'coach', title: 'Coach: splits, plans, assessments' },
  { id: 'assistant', role: 'client', title: 'Assistant' },
  // DECISIONS.md D12. Staff, not a member — the only flow whose role is neither
  // client nor coach, and the only one gated on a server-minted `token.admin`
  // claim rather than on verification.
  { id: 'admin', role: 'admin', title: 'Admin: content library, import and export' },
  // Coach plans and reviews
];

export const screens = [
  // Sign-up and verification
  { id: 'C01', flow: 'signup', title: 'Welcome' },
  { id: 'C02', flow: 'signup', title: 'Language' },
  { id: 'C03', flow: 'signup', title: "What's inside" },
  { id: 'C04', flow: 'signup', title: 'Look around first' },
  { id: 'C05', flow: 'signup', title: 'Join to save this' },
  { id: 'C06', flow: 'signup', title: 'Phone number' },
  { id: 'C07', flow: 'signup', title: 'The code' },
  { id: 'C08', flow: 'signup', title: 'Client or coach' },
  { id: 'C09', flow: 'signup', title: 'Why we check' },
  // Two screens whose ids carry a letter suffix, because they were inserted
  // into a numbered flow that is referenced by id in the specs, the plans and
  // the prototype. Renumbering C10 to C16 to make room would silently
  // repoint every one of those references at the wrong screen.
  //
  // C09b is the consent step. Nothing may open a camera before she has agreed
  // to where her face and her national ID go, and that agreement is written
  // down before C10 becomes reachable.
  { id: 'C09b', flow: 'signup', title: 'Before the camera opens', noMockup: true },
  { id: 'C10', flow: 'signup', title: 'Scan your ID' },
  // C10b is the second pass of the card: the back prints her sex as a word,
  // which is the independent reading the 13th digit is cross-checked against.
  { id: 'C10b', flow: 'signup', title: 'The back of your card', noMockup: true },
  { id: 'C11', flow: 'signup', title: 'Quick selfie' },
  { id: 'C12', flow: 'signup', title: 'Checking' },
  { id: 'C13', flow: 'signup', title: "You're in" },
  { id: 'C14', flow: 'signup', title: 'Waiting for a reviewer' },
  { id: 'C15', flow: 'signup', title: 'Verify with a woman reviewer' },
  { id: 'C16', flow: 'signup', title: 'Community pledge' },
  // Client setup
  { id: 'O01', flow: 'onboarding', title: 'Her goal' },
  { id: 'O02', flow: 'onboarding', title: 'Where and with what' },
  { id: 'O03', flow: 'onboarding', title: 'Days and minutes' },
  { id: 'O04', flow: 'onboarding', title: 'Life stage' },
  { id: 'O05', flow: 'onboarding', title: 'Your starting program' },
  // Today and logging
  { id: 'T01', flow: 'today', title: 'Today' },
  { id: 'T02', flow: 'today', title: 'I already did it' },
  { id: 'T03', flow: 'today', title: 'From the lock screen' },
  { id: 'T04', flow: 'today', title: 'After a quiet week' },
  { id: 'T05', flow: 'today', title: 'When a tier slips' },
  { id: 'T06', flow: 'today', title: 'Day one' },
  { id: 'T07', flow: 'today', title: 'Your first week' },
  { id: 'T08', flow: 'today', title: 'First week done' },
  // Feature.events. The owner's events, published from Z17/Z18; a card on
  // Home leads here. Off until she switches it on. Designed in Flutter.
  { id: 'T09', flow: 'today', title: 'Events', noMockup: true },
  // Train
  { id: 'R01', flow: 'train', title: 'Train' },
  { id: 'R02', flow: 'train', title: 'Program' },
  { id: 'R03', flow: 'train', title: 'Workout day' },
  { id: 'R04', flow: 'train', title: 'Exercise video' },
  { id: 'R05', flow: 'train', title: 'Swap a move' },
  { id: 'R06', flow: 'train', title: 'Follow-along move' },
  { id: 'R07', flow: 'train', title: 'Mid-set' },
  { id: 'R08', flow: 'train', title: 'Change a set' },
  { id: 'R09', flow: 'train', title: 'Resting' },
  { id: 'R10', flow: 'train', title: 'Finished' },
  { id: 'R11', flow: 'train', title: 'Workout library' },
  { id: 'R12', flow: 'train', title: 'Logged from memory' },
  { id: 'R13', flow: 'train', title: 'Move logged' },
  // Eat
  { id: 'E01', flow: 'eat', title: 'Eat' },
  { id: 'E02', flow: 'eat', title: 'Type it' },
  { id: 'E03', flow: 'eat', title: 'Say it' },
  { id: 'E04', flow: 'eat', title: 'After a log' },
  { id: 'E05', flow: 'eat', title: 'Recipes' },
  { id: 'E06', flow: 'eat', title: 'Recipe' },
  { id: 'E07', flow: 'eat', title: 'Week plan' },
  { id: 'E08', flow: 'eat', title: 'Grocery list' },
  { id: 'E09', flow: 'eat', title: 'Eat, day one' },
  // The one question the recipe library cannot be opened without.
  //
  // `DietaryConstraints.none` is a CLAIM: asked, and named nothing. It was true
  // of nobody, because nothing asked. The moment a dish carries an allergen that
  // claim makes the guard clear a sesame dish for a woman allergic to sesame,
  // silently, while looking live. E10 is what turns the claim into an answer, and
  // it stands in front of E05 rather than beside it.
  { id: 'E10', flow: 'eat', title: 'What you cannot eat', noMockup: true },
  // Rahma's closing letter, page 26 of her book. Her words, her sign-off, and
  // nothing else on the screen.
  { id: 'E11', flow: 'eat', title: 'A message from Rahma', noMockup: true },
  // Progress
  { id: 'P01', flow: 'progress', title: 'Your progress' },
  { id: 'P02', flow: 'progress', title: 'Milestones' },
  { id: 'P03', flow: 'progress', title: 'Personal bests' },
  { id: 'P04', flow: 'progress', title: 'Body, privately' },
  // My cycle
  { id: 'Y01', flow: 'cycle', title: 'Set up My cycle' },
  { id: 'Y02', flow: 'cycle', title: 'Dates and preferences' },
  { id: 'Y03', flow: 'cycle', title: 'My cycle today' },
  { id: 'Y04', flow: 'cycle', title: 'How are you feeling?' },
  { id: 'Y05', flow: 'cycle', title: 'Why this suggestion?' },
  { id: 'Y06', flow: 'cycle', title: 'Choose what feels right' },
  { id: 'Y07', flow: 'cycle', title: 'Meals for today' },
  { id: 'Y08', flow: 'cycle', title: 'Calendar' },
  { id: 'Y09', flow: 'cycle', title: 'Log a period' },
  { id: 'Y10', flow: 'cycle', title: 'Your patterns' },
  { id: 'Y11', flow: 'cycle', title: 'When it is severe' },
  { id: 'Y12', flow: 'cycle', title: 'Cycle settings and sharing' },
  { id: 'Y13', flow: 'cycle', title: 'About cycle phases' },
  { id: 'Y14', flow: 'cycle', title: 'Symptom-only mode' },
  // Coached client
  { id: 'G01', flow: 'coached', title: 'Coaching intake' },
  { id: 'G02', flow: 'coached', title: 'Support and sharing' },
  { id: 'G03', flow: 'coached', title: 'Preparing your plan' },
  { id: 'G04', flow: 'coached', title: 'Your coaching plan' },
  { id: 'G05', flow: 'coached', title: 'Your 30 days' },
  { id: 'G06', flow: 'coached', title: 'Assigned workout' },
  { id: 'G07', flow: 'coached', title: 'Rest between sets' },
  { id: 'G08', flow: 'coached', title: 'Swap an exercise' },
  { id: 'G09', flow: 'coached', title: 'Session done' },
  { id: 'G10', flow: 'coached', title: 'Log a planned meal' },
  { id: 'G11', flow: 'coached', title: 'Meal logged' },
  { id: 'G12', flow: 'coached', title: 'Weekly review' },
  { id: 'G13', flow: 'coached', title: 'Coach replied' },
  { id: 'G14', flow: 'coached', title: 'Chat with Sara' },
  { id: 'G15', flow: 'coached', title: 'Voice note' },
  { id: 'G16', flow: 'coached', title: 'When coaching ends' },
  { id: 'G17', flow: 'coached', title: 'Your food' },
  // Community
  { id: 'M01', flow: 'community', title: 'Community' },
  { id: 'M02', flow: 'community', title: 'Post' },
  { id: 'M03', flow: 'community', title: 'New post' },
  { id: 'M04', flow: 'community', title: 'Groups' },
  { id: 'M05', flow: 'community', title: 'Group' },
  { id: 'M06', flow: 'community', title: 'Group goal' },
  { id: 'M07', flow: 'community', title: 'Member' },
  { id: 'M08', flow: 'community', title: 'Report' },
  { id: 'M09', flow: 'community', title: 'Reels' },
  { id: 'M10', flow: 'community', title: 'Explore' },
  { id: 'M11', flow: 'community', title: 'Add a follow-up' },
  { id: 'M12', flow: 'community', title: 'Follow-up thread' },
  { id: 'M13', flow: 'community', title: 'Stories' },
  { id: 'M14', flow: 'community', title: 'Activity' },
  { id: 'M15', flow: 'community', title: 'Saved' },
  { id: 'M16', flow: 'community', title: 'Record' },
  { id: 'M17', flow: 'community', title: 'Community, day one' },
  // Coaching (client)
  { id: 'H01', flow: 'coaching', title: 'Find a coach' },
  { id: 'H02', flow: 'coaching', title: 'Coach profile' },
  { id: 'H03', flow: 'coaching', title: 'Choose a package' },
  { id: 'H04', flow: 'coaching', title: 'Pay' },
  { id: 'H05', flow: 'coaching', title: 'My coach' },
  { id: 'H06', flow: 'coaching', title: 'Chat' },
  // Account
  { id: 'A01', flow: 'account', title: 'Notifications' },
  { id: 'A02', flow: 'account', title: 'Profile and settings' },
  { id: 'A03', flow: 'account', title: 'Privacy' },
  { id: 'A04', flow: 'account', title: 'Safety Centre' },
  { id: 'X01', flow: 'assistant', title: 'Ask' },
  { id: 'X02', flow: 'assistant', title: 'When it will not answer' },
  { id: 'X03', flow: 'assistant', title: 'What it can and cannot do' },
  // Coach setup
  { id: 'K01', flow: 'coach-setup', title: 'Your basics' },
  { id: 'K02', flow: 'coach-setup', title: 'Certificates' },
  { id: 'K03', flow: 'coach-setup', title: 'What you coach' },
  { id: 'K04', flow: 'coach-setup', title: 'Your packages' },
  { id: 'K05', flow: 'coach-setup', title: 'Getting paid' },
  { id: 'K06', flow: 'coach-setup', title: 'Being checked' },
  // Coach app
  { id: 'K07', flow: 'coach', title: 'Today' },
  { id: 'K09', flow: 'coach', title: 'New enquiry' },
  { id: 'K16', flow: 'coach', title: 'Conversation' },
  { id: 'K17', flow: 'coach', title: 'Earnings' },
  { id: 'K18', flow: 'coach', title: 'Public profile' },
  { id: 'K24', flow: 'coach', title: 'Today, day one' },
  { id: 'K25', flow: 'coach', title: 'Coach first week' },
  // Coach portfolio, ads and results
  { id: 'B01', flow: 'coachbrand', title: 'My portfolio' },
  { id: 'B02', flow: 'coachbrand', title: 'Page builder' },
  { id: 'B03', flow: 'coachbrand', title: 'Add a section' },
  { id: 'B04', flow: 'coachbrand', title: 'Edit the cover' },
  { id: 'B05', flow: 'coachbrand', title: 'Your look' },
  { id: 'B06', flow: 'coachbrand', title: 'What I offer' },
  { id: 'B07', flow: 'coachbrand', title: 'How I work' },
  { id: 'B08', flow: 'coachbrand', title: 'Client results' },
  { id: 'B09', flow: 'coachbrand', title: 'Design an ad' },
  { id: 'B10', flow: 'coachbrand', title: 'Preview as a client' },
  { id: 'B11', flow: 'coachbrand', title: 'Publish' },
  { id: 'B12', flow: 'coachbrand', title: 'What it is doing' },
  { id: 'B13', flow: 'coachbrand', title: 'Your media' },
  { id: 'B14', flow: 'coachbrand', title: 'Portfolio, not built' },
  { id: 'W01', flow: 'coachplan', title: 'Clients and queue' },
  { id: 'W02', flow: 'coachplan', title: 'Client overview' },
  { id: 'W03', flow: 'coachplan', title: '30-day workout planner' },
  { id: 'W04', flow: 'coachplan', title: 'Edit a session' },
  { id: 'W05', flow: 'coachplan', title: 'Copy a week' },
  { id: 'W06', flow: 'coachplan', title: '30-day meal planner' },
  { id: 'W07', flow: 'coachplan', title: 'Create a meal' },
  { id: 'W08', flow: 'coachplan', title: 'Publish the plan' },
  { id: 'W09', flow: 'coachplan', title: 'Review and adjust' },
  { id: 'W10', flow: 'coachplan', title: 'Coach inbox' },
  { id: 'K19', flow: 'coachplan', title: 'My splits' },
  { id: 'K20', flow: 'coachplan', title: 'Build a split' },
  { id: 'K21', flow: 'coachplan', title: 'Assessment' },
  { id: 'K22', flow: 'coachplan', title: 'Re-assessment' },
  { id: 'K23', flow: 'coachplan', title: 'Movement screening' },
  { id: 'W11', flow: 'coachplan', title: 'Clients, none yet' },
  { id: 'K26', flow: 'coachplan', title: 'Plan draft' },
  { id: 'K27', flow: 'coachplan', title: 'Meal draft' },
  // Admin content console — DECISIONS.md D12, plan G16. Staff only, behind the
  // server-minted `token.admin` claim. Titles are the markup's own top bars, so
  // the inventory cannot drift from the screens it indexes.
  { id: 'Z01', flow: 'admin', title: 'Content library' },
  { id: 'Z02', flow: 'admin', title: 'Exercises' },
  { id: 'Z03', flow: 'admin', title: 'Edit an exercise' },
  { id: 'Z04', flow: 'admin', title: 'Foods' },
  { id: 'Z05', flow: 'admin', title: 'Edit a food' },
  { id: 'Z06', flow: 'admin', title: 'Recipes' },
  { id: 'Z07', flow: 'admin', title: 'Programmes' },
  { id: 'Z08', flow: 'admin', title: 'Bulk import' },
  { id: 'Z09', flow: 'admin', title: 'Import check' },
  { id: 'Z10', flow: 'admin', title: 'Media library' },
  { id: 'Z11', flow: 'admin', title: 'Export' },
  // DECISIONS.md D18. The owner asked for content to be authored "once at a
  // time or bulk" — both, for every collection. Exercises and foods had Z03 and
  // Z05; recipes and programmes had nothing, and the markup contradicted itself
  // about it (Z06's add action opened a FOOD form, Z07's opened the importer).
  { id: 'Z12', flow: 'admin', title: 'Edit a recipe' },
  { id: 'Z13', flow: 'admin', title: 'Edit a programme' },

  // D25 - the switchboard. Every feature in the product, on or off, so a
  // half-built flow can ship dark and be turned on when it is ready rather
  // than when the code happened to land.
  { id: 'Z14', flow: 'admin', title: 'Feature flags' },

  // The owner's operations: counts with no member named in them, the
  // operational logs in codes, and the events she runs. All four are served by
  // admin-only callables or by rules that accept the admin claim only.
  // Designed in Flutter, so no markup here by decision.
  { id: 'Z15', flow: 'admin', title: 'Dashboard', noMockup: true },
  { id: 'Z16', flow: 'admin', title: 'Logs', noMockup: true },
  { id: 'Z17', flow: 'admin', title: 'Events', noMockup: true },
  { id: 'Z18', flow: 'admin', title: 'Edit an event', noMockup: true },
];
