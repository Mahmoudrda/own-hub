import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_l10n_ar.dart';
import 'app_l10n_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @coaching.
  ///
  /// In en, this message translates to:
  /// **'Coaching'**
  String get coaching;

  /// No description provided for @eat.
  ///
  /// In en, this message translates to:
  /// **'Eat'**
  String get eat;

  /// No description provided for @train.
  ///
  /// In en, this message translates to:
  /// **'Train'**
  String get train;

  /// No description provided for @community.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get community;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @train_556cm.
  ///
  /// In en, this message translates to:
  /// **'train'**
  String get train_556cm;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @myCycle.
  ///
  /// In en, this message translates to:
  /// **'My cycle'**
  String get myCycle;

  /// No description provided for @n.
  ///
  /// In en, this message translates to:
  /// **'N'**
  String get n;

  /// No description provided for @clients.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get clients;

  /// No description provided for @s.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get s;

  /// No description provided for @chats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chats;

  /// No description provided for @earnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get earnings;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// No description provided for @m.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get m;

  /// No description provided for @rest.
  ///
  /// In en, this message translates to:
  /// **'rest'**
  String get rest;

  /// No description provided for @gobletSquat.
  ///
  /// In en, this message translates to:
  /// **'Goblet squat'**
  String get gobletSquat;

  /// No description provided for @maiFarouk.
  ///
  /// In en, this message translates to:
  /// **'Mai Farouk'**
  String get maiFarouk;

  /// No description provided for @nourhanElSayed.
  ///
  /// In en, this message translates to:
  /// **'Nourhan El-Sayed'**
  String get nourhanElSayed;

  /// No description provided for @patterns.
  ///
  /// In en, this message translates to:
  /// **'Patterns'**
  String get patterns;

  /// No description provided for @quiet.
  ///
  /// In en, this message translates to:
  /// **'Quiet'**
  String get quiet;

  /// No description provided for @beginnersGroup.
  ///
  /// In en, this message translates to:
  /// **'Beginners group'**
  String get beginnersGroup;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'done'**
  String get done;

  /// No description provided for @gluteBridge.
  ///
  /// In en, this message translates to:
  /// **'Glute bridge'**
  String get gluteBridge;

  /// No description provided for @iAteThis.
  ///
  /// In en, this message translates to:
  /// **'I ate this'**
  String get iAteThis;

  /// No description provided for @saraAdel.
  ///
  /// In en, this message translates to:
  /// **'Sara Adel'**
  String get saraAdel;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @fulAndBaladi.
  ///
  /// In en, this message translates to:
  /// **'Ful and baladi'**
  String get fulAndBaladi;

  /// No description provided for @h.
  ///
  /// In en, this message translates to:
  /// **'H'**
  String get h;

  /// No description provided for @move2Of5.
  ///
  /// In en, this message translates to:
  /// **'Move 2 of 5'**
  String get move2Of5;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @fullBodyStrength.
  ///
  /// In en, this message translates to:
  /// **'Full-body strength'**
  String get fullBodyStrength;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @koshariBowlMedium.
  ///
  /// In en, this message translates to:
  /// **'Koshari bowl, medium'**
  String get koshariBowlMedium;

  /// No description provided for @low.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get low;

  /// No description provided for @nadaSamir.
  ///
  /// In en, this message translates to:
  /// **'Nada Samir'**
  String get nadaSamir;

  /// No description provided for @postpartumRebuild.
  ///
  /// In en, this message translates to:
  /// **'Postpartum rebuild'**
  String get postpartumRebuild;

  /// No description provided for @saveAndClose.
  ///
  /// In en, this message translates to:
  /// **'Save and close'**
  String get saveAndClose;

  /// No description provided for @stepBackLunge.
  ///
  /// In en, this message translates to:
  /// **'Step-back lunge'**
  String get stepBackLunge;

  /// No description provided for @thu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get thu;

  /// No description provided for @n10Min.
  ///
  /// In en, this message translates to:
  /// **'10 min'**
  String get n10Min;

  /// No description provided for @n12Kg10.
  ///
  /// In en, this message translates to:
  /// **'12 kg × 10'**
  String get n12Kg10;

  /// No description provided for @n12Kg12.
  ///
  /// In en, this message translates to:
  /// **'12 kg × 12'**
  String get n12Kg12;

  /// No description provided for @atHome.
  ///
  /// In en, this message translates to:
  /// **'At home'**
  String get atHome;

  /// No description provided for @breakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get breakfast;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @dinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get dinner;

  /// No description provided for @energyAndAppetite.
  ///
  /// In en, this message translates to:
  /// **'Energy and appetite'**
  String get energyAndAppetite;

  /// No description provided for @fromSara.
  ///
  /// In en, this message translates to:
  /// **'From Sara'**
  String get fromSara;

  /// No description provided for @habibaNasr.
  ///
  /// In en, this message translates to:
  /// **'Habiba Nasr'**
  String get habibaNasr;

  /// No description provided for @iAlreadyDidIt.
  ///
  /// In en, this message translates to:
  /// **'I already did it'**
  String get iAlreadyDidIt;

  /// No description provided for @level7Regular.
  ///
  /// In en, this message translates to:
  /// **'Level 7 · Regular'**
  String get level7Regular;

  /// No description provided for @lunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get lunch;

  /// No description provided for @mon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get mon;

  /// No description provided for @nourAdel.
  ///
  /// In en, this message translates to:
  /// **'Nour Adel'**
  String get nourAdel;

  /// No description provided for @personalBests.
  ///
  /// In en, this message translates to:
  /// **'Personal bests'**
  String get personalBests;

  /// No description provided for @protein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get protein;

  /// No description provided for @recipes.
  ///
  /// In en, this message translates to:
  /// **'Recipes'**
  String get recipes;

  /// No description provided for @startEverythingsReady.
  ///
  /// In en, this message translates to:
  /// **'Start, everything\'s ready'**
  String get startEverythingsReady;

  /// No description provided for @tue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get tue;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @workouts.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get workouts;

  /// No description provided for @n1800Egp.
  ///
  /// In en, this message translates to:
  /// **'1,800 EGP'**
  String get n1800Egp;

  /// No description provided for @n20Min.
  ///
  /// In en, this message translates to:
  /// **'20 min'**
  String get n20Min;

  /// No description provided for @n290Kcal.
  ///
  /// In en, this message translates to:
  /// **'290 kcal'**
  String get n290Kcal;

  /// No description provided for @n310EachSide.
  ///
  /// In en, this message translates to:
  /// **'3 × 10 each side'**
  String get n310EachSide;

  /// No description provided for @n312Bodyweight.
  ///
  /// In en, this message translates to:
  /// **'3 × 12 · bodyweight'**
  String get n312Bodyweight;

  /// No description provided for @n35MinHerNoteKeepTheSquat.
  ///
  /// In en, this message translates to:
  /// **'35 min · her note: “Keep the squat at 12 kg, aim for 12 reps.”'**
  String get n35MinHerNoteKeepTheSquat;

  /// No description provided for @n410Kcal.
  ///
  /// In en, this message translates to:
  /// **'410 kcal'**
  String get n410Kcal;

  /// No description provided for @aboutRight.
  ///
  /// In en, this message translates to:
  /// **'About right'**
  String get aboutRight;

  /// No description provided for @cycleSymptoms.
  ///
  /// In en, this message translates to:
  /// **'Cycle symptoms'**
  String get cycleSymptoms;

  /// No description provided for @eggsAndTea.
  ///
  /// In en, this message translates to:
  /// **'Eggs and tea'**
  String get eggsAndTea;

  /// No description provided for @herPhotoFaceBlurred.
  ///
  /// In en, this message translates to:
  /// **'her photo, face blurred'**
  String get herPhotoFaceBlurred;

  /// No description provided for @howAreYouFeeling.
  ///
  /// In en, this message translates to:
  /// **'How are you feeling?'**
  String get howAreYouFeeling;

  /// No description provided for @koshariPortioned.
  ///
  /// In en, this message translates to:
  /// **'Koshari, portioned'**
  String get koshariPortioned;

  /// No description provided for @lentilSoupAndEggs.
  ///
  /// In en, this message translates to:
  /// **'Lentil soup and eggs'**
  String get lentilSoupAndEggs;

  /// No description provided for @notedByYou.
  ///
  /// In en, this message translates to:
  /// **'Noted by you'**
  String get notedByYou;

  /// No description provided for @molokhiaWithChicken.
  ///
  /// In en, this message translates to:
  /// **'Molokhia with chicken'**
  String get molokhiaWithChicken;

  /// No description provided for @monday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monday;

  /// No description provided for @monthlyCoaching.
  ///
  /// In en, this message translates to:
  /// **'Monthly coaching'**
  String get monthlyCoaching;

  /// No description provided for @noEquipment.
  ///
  /// In en, this message translates to:
  /// **'No equipment'**
  String get noEquipment;

  /// No description provided for @okay.
  ///
  /// In en, this message translates to:
  /// **'Okay'**
  String get okay;

  /// No description provided for @periodDay2.
  ///
  /// In en, this message translates to:
  /// **'Period day 2'**
  String get periodDay2;

  /// No description provided for @postpartum.
  ///
  /// In en, this message translates to:
  /// **'Postpartum'**
  String get postpartum;

  /// No description provided for @prescribed.
  ///
  /// In en, this message translates to:
  /// **'prescribed'**
  String get prescribed;

  /// No description provided for @saraHany.
  ///
  /// In en, this message translates to:
  /// **'Sara Hany'**
  String get saraHany;

  /// No description provided for @september2026.
  ///
  /// In en, this message translates to:
  /// **'September 2026'**
  String get september2026;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @tuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get tuesday;

  /// No description provided for @vegetarian.
  ///
  /// In en, this message translates to:
  /// **'Vegetarian'**
  String get vegetarian;

  /// No description provided for @week3.
  ///
  /// In en, this message translates to:
  /// **'Week 3'**
  String get week3;

  /// No description provided for @youDid.
  ///
  /// In en, this message translates to:
  /// **'you did'**
  String get youDid;

  /// No description provided for @youNotedLowEnergyAndMildCramps.
  ///
  /// In en, this message translates to:
  /// **'You noted low energy and mild cramps.'**
  String get youNotedLowEnergyAndMildCramps;

  /// No description provided for @n14Of20.
  ///
  /// In en, this message translates to:
  /// **'14 of 20'**
  String get n14Of20;

  /// No description provided for @n15Min.
  ///
  /// In en, this message translates to:
  /// **'15 min'**
  String get n15Min;

  /// No description provided for @n15September2026.
  ///
  /// In en, this message translates to:
  /// **'15 September 2026'**
  String get n15September2026;

  /// No description provided for @n156Kcal13GProtein.
  ///
  /// In en, this message translates to:
  /// **'156 kcal · 13 g protein'**
  String get n156Kcal13GProtein;

  /// No description provided for @n2Of3.
  ///
  /// In en, this message translates to:
  /// **'2 of 3'**
  String get n2Of3;

  /// No description provided for @n21600Egp.
  ///
  /// In en, this message translates to:
  /// **'21,600 EGP'**
  String get n21600Egp;

  /// No description provided for @n3Of3.
  ///
  /// In en, this message translates to:
  /// **'3 of 3'**
  String get n3Of3;

  /// No description provided for @n30Min.
  ///
  /// In en, this message translates to:
  /// **'30 min'**
  String get n30Min;

  /// No description provided for @n53Of95G.
  ///
  /// In en, this message translates to:
  /// **'53 of 95 g'**
  String get n53Of95G;

  /// No description provided for @n540Kcal18GProtein.
  ///
  /// In en, this message translates to:
  /// **'540 kcal · 18 g protein'**
  String get n540Kcal18GProtein;

  /// No description provided for @n8SepTo7Oct30Days.
  ///
  /// In en, this message translates to:
  /// **'8 Sep to 7 Oct · 30 days'**
  String get n8SepTo7Oct30Days;

  /// No description provided for @n900Egp.
  ///
  /// In en, this message translates to:
  /// **'900 EGP'**
  String get n900Egp;

  /// No description provided for @aGentlerOptionToday.
  ///
  /// In en, this message translates to:
  /// **'A gentler option today'**
  String get aGentlerOptionToday;

  /// No description provided for @aProgramNoCheckIns.
  ///
  /// In en, this message translates to:
  /// **'A program, no check-ins'**
  String get aProgramNoCheckIns;

  /// No description provided for @aboutCyclePhases.
  ///
  /// In en, this message translates to:
  /// **'About cycle phases'**
  String get aboutCyclePhases;

  /// No description provided for @addToTodaysPlan.
  ///
  /// In en, this message translates to:
  /// **'Add to today\'s plan'**
  String get addToTodaysPlan;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @backToToday.
  ///
  /// In en, this message translates to:
  /// **'Back to today'**
  String get backToToday;

  /// No description provided for @beginners.
  ///
  /// In en, this message translates to:
  /// **'Beginners'**
  String get beginners;

  /// No description provided for @breakfastYourUsual.
  ///
  /// In en, this message translates to:
  /// **'Breakfast, your usual'**
  String get breakfastYourUsual;

  /// No description provided for @breakfastYourUsual_1lb0u.
  ///
  /// In en, this message translates to:
  /// **'Breakfast, your usual?'**
  String get breakfastYourUsual_1lb0u;

  /// No description provided for @cairoWestSide.
  ///
  /// In en, this message translates to:
  /// **'Cairo, west side'**
  String get cairoWestSide;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @coachDemoStill.
  ///
  /// In en, this message translates to:
  /// **'coach demo still'**
  String get coachDemoStill;

  /// No description provided for @coachSaraHany.
  ///
  /// In en, this message translates to:
  /// **'Coach Sara Hany'**
  String get coachSaraHany;

  /// No description provided for @coaches.
  ///
  /// In en, this message translates to:
  /// **'Coaches'**
  String get coaches;

  /// No description provided for @day9.
  ///
  /// In en, this message translates to:
  /// **'Day 9'**
  String get day9;

  /// No description provided for @deadBug.
  ///
  /// In en, this message translates to:
  /// **'Dead bug'**
  String get deadBug;

  /// No description provided for @draft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get draft;

  /// No description provided for @dumbbells.
  ///
  /// In en, this message translates to:
  /// **'Dumbbells'**
  String get dumbbells;

  /// No description provided for @easy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get easy;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @firstWeekDoneMyKneesDidNot.
  ///
  /// In en, this message translates to:
  /// **'First week done. My knees did not hurt once.'**
  String get firstWeekDoneMyKneesDidNot;

  /// No description provided for @floorLegsNoJumping.
  ///
  /// In en, this message translates to:
  /// **'Floor legs, no jumping'**
  String get floorLegsNoJumping;

  /// No description provided for @mealAdded.
  ///
  /// In en, this message translates to:
  /// **'Meal added'**
  String get mealAdded;

  /// No description provided for @foodPhoto.
  ///
  /// In en, this message translates to:
  /// **'food photo'**
  String get foodPhoto;

  /// No description provided for @fourWeeksInAndICarriedBoth.
  ///
  /// In en, this message translates to:
  /// **'Four weeks in and I carried both kids up the stairs.'**
  String get fourWeeksInAndICarriedBoth;

  /// No description provided for @fromCoachSara.
  ///
  /// In en, this message translates to:
  /// **'From Coach Sara'**
  String get fromCoachSara;

  /// No description provided for @fromYourPlan.
  ///
  /// In en, this message translates to:
  /// **'From your plan'**
  String get fromYourPlan;

  /// No description provided for @fullBodyStrength35Min.
  ///
  /// In en, this message translates to:
  /// **'Full-body strength · 35 min'**
  String get fullBodyStrength35Min;

  /// No description provided for @getStronger.
  ///
  /// In en, this message translates to:
  /// **'Get stronger'**
  String get getStronger;

  /// No description provided for @goal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get goal;

  /// No description provided for @gobletSquat12Kg10TwoKilos.
  ///
  /// In en, this message translates to:
  /// **'Goblet squat, 12 kg × 10. Two kilos more than my best.'**
  String get gobletSquat12Kg10TwoKilos;

  /// No description provided for @halaMostafa.
  ///
  /// In en, this message translates to:
  /// **'Hala Mostafa'**
  String get halaMostafa;

  /// No description provided for @highProtein.
  ///
  /// In en, this message translates to:
  /// **'High protein'**
  String get highProtein;

  /// No description provided for @hipThrustHold.
  ///
  /// In en, this message translates to:
  /// **'Hip thrust hold'**
  String get hipThrustHold;

  /// No description provided for @holdToReplyByVoice.
  ///
  /// In en, this message translates to:
  /// **'Hold to reply by voice'**
  String get holdToReplyByVoice;

  /// No description provided for @imReadyNextSet.
  ///
  /// In en, this message translates to:
  /// **'I\'m ready, next set'**
  String get imReadyNextSet;

  /// No description provided for @inbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get inbox;

  /// No description provided for @koshariBowlAndSalad.
  ///
  /// In en, this message translates to:
  /// **'Koshari bowl and salad'**
  String get koshariBowlAndSalad;

  /// No description provided for @large.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get large;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @legs.
  ///
  /// In en, this message translates to:
  /// **'Legs'**
  String get legs;

  /// No description provided for @legsAndGlutes.
  ///
  /// In en, this message translates to:
  /// **'Legs and glutes'**
  String get legsAndGlutes;

  /// No description provided for @noteAPeriod.
  ///
  /// In en, this message translates to:
  /// **'Note a period'**
  String get noteAPeriod;

  /// No description provided for @eaten.
  ///
  /// In en, this message translates to:
  /// **'eaten'**
  String get eaten;

  /// No description provided for @logotype.
  ///
  /// In en, this message translates to:
  /// **'logotype'**
  String get logotype;

  /// No description provided for @lookAround.
  ///
  /// In en, this message translates to:
  /// **'Look around'**
  String get lookAround;

  /// No description provided for @meals.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get meals;

  /// No description provided for @medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get medium;

  /// No description provided for @messageSara.
  ///
  /// In en, this message translates to:
  /// **'Message Sara'**
  String get messageSara;

  /// No description provided for @milestones.
  ///
  /// In en, this message translates to:
  /// **'Milestones'**
  String get milestones;

  /// No description provided for @mobileWallet.
  ///
  /// In en, this message translates to:
  /// **'Mobile wallet'**
  String get mobileWallet;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @noteForHer.
  ///
  /// In en, this message translates to:
  /// **'Note for her'**
  String get noteForHer;

  /// No description provided for @nothingAssigned.
  ///
  /// In en, this message translates to:
  /// **'Nothing assigned'**
  String get nothingAssigned;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @nourWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Nour · workouts'**
  String get nourWorkouts;

  /// No description provided for @onTrack.
  ///
  /// In en, this message translates to:
  /// **'On track'**
  String get onTrack;

  /// No description provided for @periodDatesAndPatterns.
  ///
  /// In en, this message translates to:
  /// **'Period dates and patterns'**
  String get periodDatesAndPatterns;

  /// No description provided for @planOnly.
  ///
  /// In en, this message translates to:
  /// **'Plan only'**
  String get planOnly;

  /// No description provided for @planWeeklyCheckInChat.
  ///
  /// In en, this message translates to:
  /// **'Plan, weekly check-in, chat'**
  String get planWeeklyCheckInChat;

  /// No description provided for @post.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get post;

  /// No description provided for @postpartumStrengthGiza.
  ///
  /// In en, this message translates to:
  /// **'Postpartum strength · Giza'**
  String get postpartumStrengthGiza;

  /// No description provided for @previewAndPublish.
  ///
  /// In en, this message translates to:
  /// **'Preview and publish'**
  String get previewAndPublish;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @quick.
  ///
  /// In en, this message translates to:
  /// **'Quick'**
  String get quick;

  /// No description provided for @quietFullBody.
  ///
  /// In en, this message translates to:
  /// **'Quiet full body'**
  String get quietFullBody;

  /// No description provided for @r.
  ///
  /// In en, this message translates to:
  /// **'R'**
  String get r;

  /// No description provided for @ranaTarek.
  ///
  /// In en, this message translates to:
  /// **'Rana Tarek'**
  String get ranaTarek;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @restDay.
  ///
  /// In en, this message translates to:
  /// **'Rest day'**
  String get restDay;

  /// No description provided for @restToday.
  ///
  /// In en, this message translates to:
  /// **'Rest today'**
  String get restToday;

  /// No description provided for @safetyCentre.
  ///
  /// In en, this message translates to:
  /// **'Safety Centre'**
  String get safetyCentre;

  /// No description provided for @sat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get sat;

  /// No description provided for @sayOrTypeWhatYouAte.
  ///
  /// In en, this message translates to:
  /// **'Say or type what you ate'**
  String get sayOrTypeWhatYouAte;

  /// No description provided for @sendToSara.
  ///
  /// In en, this message translates to:
  /// **'Send to Sara'**
  String get sendToSara;

  /// No description provided for @set1.
  ///
  /// In en, this message translates to:
  /// **'Set 1'**
  String get set1;

  /// No description provided for @set2.
  ///
  /// In en, this message translates to:
  /// **'Set 2'**
  String get set2;

  /// No description provided for @set2Of3.
  ///
  /// In en, this message translates to:
  /// **'Set 2 of 3'**
  String get set2Of3;

  /// No description provided for @set3.
  ///
  /// In en, this message translates to:
  /// **'Set 3'**
  String get set3;

  /// No description provided for @showTheCycleCardOnHome.
  ///
  /// In en, this message translates to:
  /// **'Show the cycle card on Home'**
  String get showTheCycleCardOnHome;

  /// No description provided for @small.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get small;

  /// No description provided for @somethingElse.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get somethingElse;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @stillBleeding.
  ///
  /// In en, this message translates to:
  /// **'Still bleeding'**
  String get stillBleeding;

  /// No description provided for @sun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get sun;

  /// No description provided for @swapThisMove.
  ///
  /// In en, this message translates to:
  /// **'Swap this move'**
  String get swapThisMove;

  /// No description provided for @t.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get t;

  /// No description provided for @tuesday16September.
  ///
  /// In en, this message translates to:
  /// **'Tuesday 16 September'**
  String get tuesday16September;

  /// No description provided for @upNext.
  ///
  /// In en, this message translates to:
  /// **'Up next'**
  String get upNext;

  /// No description provided for @week2.
  ///
  /// In en, this message translates to:
  /// **'Week 2'**
  String get week2;

  /// No description provided for @week4.
  ///
  /// In en, this message translates to:
  /// **'Week 4'**
  String get week4;

  /// No description provided for @week4Mai.
  ///
  /// In en, this message translates to:
  /// **'Week 4 · Mai'**
  String get week4Mai;

  /// No description provided for @weeklyReview.
  ///
  /// In en, this message translates to:
  /// **'Weekly review'**
  String get weeklyReview;

  /// No description provided for @weeklyReviewDue.
  ///
  /// In en, this message translates to:
  /// **'Weekly review due'**
  String get weeklyReviewDue;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @whatDidYouDo.
  ///
  /// In en, this message translates to:
  /// **'What did you do?'**
  String get whatDidYouDo;

  /// No description provided for @whyThisSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Why this suggestion?'**
  String get whyThisSuggestion;

  /// No description provided for @yesIHaveUpdatedThursdayTheNew.
  ///
  /// In en, this message translates to:
  /// **'Yes, I have updated Thursday. The new session is in your plan.'**
  String get yesIHaveUpdatedThursdayTheNew;

  /// No description provided for @youKeep12KgOnThursday.
  ///
  /// In en, this message translates to:
  /// **'You: keep 12 kg on Thursday'**
  String get youKeep12KgOnThursday;

  /// No description provided for @yourCoaching.
  ///
  /// In en, this message translates to:
  /// **'Your coaching'**
  String get yourCoaching;

  /// No description provided for @cameBackIsEarnedByReturningAfter.
  ///
  /// In en, this message translates to:
  /// **'\"Came back\" is earned by returning after a break. It is the one we most want you to have.'**
  String get cameBackIsEarnedByReturningAfter;

  /// No description provided for @iWantToFeelStrongEnoughTo.
  ///
  /// In en, this message translates to:
  /// **'\"I want to feel strong enough to carry my son without my back hurting.\"'**
  String get iWantToFeelStrongEnoughTo;

  /// No description provided for @keep12KgAndAimFor12.
  ///
  /// In en, this message translates to:
  /// **'“Keep 12 kg and aim for 12 reps. Stop at 10 if your knees complain.”'**
  String get keep12KgAndAimFor12;

  /// No description provided for @morningSessionsBeforeTheKidsWakeUp.
  ///
  /// In en, this message translates to:
  /// **'“Morning sessions before the kids wake up worked. Thursday is too long.”'**
  String get morningSessionsBeforeTheKidsWakeUp;

  /// No description provided for @notSharedNeverMeansNoSymptomsShe.
  ///
  /// In en, this message translates to:
  /// **'“Not shared” never means “no symptoms”. She chose what you see.'**
  String get notSharedNeverMeansNoSymptomsShe;

  /// No description provided for @theSquatFeltHeavyAt12Kg.
  ///
  /// In en, this message translates to:
  /// **'\"The squat felt heavy at 12 kg but I finished all three sets.\"'**
  String get theSquatFeltHeavyAt12Kg;

  /// No description provided for @n15S.
  ///
  /// In en, this message translates to:
  /// **'+15 s'**
  String get n15S;

  /// No description provided for @n2Kg.
  ///
  /// In en, this message translates to:
  /// **'+2 kg'**
  String get n2Kg;

  /// No description provided for @n20.
  ///
  /// In en, this message translates to:
  /// **'+20'**
  String get n20;

  /// No description provided for @n3Reps.
  ///
  /// In en, this message translates to:
  /// **'+3 reps'**
  String get n3Reps;

  /// No description provided for @n30Points.
  ///
  /// In en, this message translates to:
  /// **'+30 points'**
  String get n30Points;

  /// No description provided for @n31G.
  ///
  /// In en, this message translates to:
  /// **'+31 g'**
  String get n31G;

  /// No description provided for @n5Points.
  ///
  /// In en, this message translates to:
  /// **'+5 points'**
  String get n5Points;

  /// No description provided for @best.
  ///
  /// In en, this message translates to:
  /// **'★ Best'**
  String get best;

  /// No description provided for @n1GobletSquat12Kg.
  ///
  /// In en, this message translates to:
  /// **'1 · goblet squat 12 kg'**
  String get n1GobletSquat12Kg;

  /// No description provided for @n1GobletSquat12Kg12.
  ///
  /// In en, this message translates to:
  /// **'1 · goblet squat 12 kg × 12'**
  String get n1GobletSquat12Kg12;

  /// No description provided for @n1ResolvedIn40Minutes.
  ///
  /// In en, this message translates to:
  /// **'1 · resolved in 40 minutes'**
  String get n1ResolvedIn40Minutes;

  /// No description provided for @n1WhatIsSaidHereStaysHere.
  ///
  /// In en, this message translates to:
  /// **'1 · What is said here stays here'**
  String get n1WhatIsSaidHereStaysHere;

  /// No description provided for @n1Hour.
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get n1Hour;

  /// No description provided for @n1Jul.
  ///
  /// In en, this message translates to:
  /// **'1 Jul'**
  String get n1Jul;

  /// No description provided for @n1RenewalFromAugust.
  ///
  /// In en, this message translates to:
  /// **'1 renewal from August'**
  String get n1RenewalFromAugust;

  /// No description provided for @n1Saved.
  ///
  /// In en, this message translates to:
  /// **'1 saved'**
  String get n1Saved;

  /// No description provided for @n1SepTo30SepOnTrack.
  ///
  /// In en, this message translates to:
  /// **'1 Sep to 30 Sep · on track · day 16'**
  String get n1SepTo30SepOnTrack;

  /// No description provided for @n1Serving.
  ///
  /// In en, this message translates to:
  /// **'1 serving'**
  String get n1Serving;

  /// No description provided for @n1Serving540Kcal18GProtein.
  ///
  /// In en, this message translates to:
  /// **'1 serving · 540 kcal · 18 g protein'**
  String get n1Serving540Kcal18GProtein;

  /// No description provided for @n1ServingFromYourPlan.
  ///
  /// In en, this message translates to:
  /// **'1 serving · from your plan'**
  String get n1ServingFromYourPlan;

  /// No description provided for @n1440Egp.
  ///
  /// In en, this message translates to:
  /// **'1,440 EGP'**
  String get n1440Egp;

  /// No description provided for @n1800EgpYourShare1440.
  ///
  /// In en, this message translates to:
  /// **'1,800 EGP · your share 1,440'**
  String get n1800EgpYourShare1440;

  /// No description provided for @n1800EgpMonthly900EgpPlan.
  ///
  /// In en, this message translates to:
  /// **'1,800 EGP monthly · 900 EGP plan only'**
  String get n1800EgpMonthly900EgpPlan;

  /// No description provided for @n1860Women12PostsToday.
  ///
  /// In en, this message translates to:
  /// **'1,860 women · 12 posts today'**
  String get n1860Women12PostsToday;

  /// No description provided for @serving.
  ///
  /// In en, this message translates to:
  /// **'½ serving'**
  String get serving;

  /// No description provided for @n10Kg.
  ///
  /// In en, this message translates to:
  /// **'10 kg'**
  String get n10Kg;

  /// No description provided for @n10Min310Kcal19GProtein.
  ///
  /// In en, this message translates to:
  /// **'10 min · 310 kcal · 19 g protein · 8 EGP'**
  String get n10Min310Kcal19GProtein;

  /// No description provided for @n10MinBeginner.
  ///
  /// In en, this message translates to:
  /// **'10 min · beginner'**
  String get n10MinBeginner;

  /// No description provided for @n10MinBeginnerNour.
  ///
  /// In en, this message translates to:
  /// **'10 min · beginner · Nour'**
  String get n10MinBeginnerNour;

  /// No description provided for @n10MonthlyPackages.
  ///
  /// In en, this message translates to:
  /// **'10 monthly packages'**
  String get n10MonthlyPackages;

  /// No description provided for @n10Sessions.
  ///
  /// In en, this message translates to:
  /// **'10 sessions'**
  String get n10Sessions;

  /// No description provided for @n1.
  ///
  /// In en, this message translates to:
  /// **'1½'**
  String get n1;

  /// No description provided for @n116Of120SlotsAssigned.
  ///
  /// In en, this message translates to:
  /// **'116 of 120 slots assigned'**
  String get n116Of120SlotsAssigned;

  /// No description provided for @n1210.
  ///
  /// In en, this message translates to:
  /// **'12 × 10'**
  String get n1210;

  /// No description provided for @n12ClientsPayoutOn1October.
  ///
  /// In en, this message translates to:
  /// **'12 clients · payout on 1 October'**
  String get n12ClientsPayoutOn1October;

  /// No description provided for @n12Kg.
  ///
  /// In en, this message translates to:
  /// **'12 kg'**
  String get n12Kg;

  /// No description provided for @n12Kg1016SeptemberWas10.
  ///
  /// In en, this message translates to:
  /// **'12 kg × 10 · 16 September · was 10 kg'**
  String get n12Kg1016SeptemberWas10;

  /// No description provided for @n12Of14.
  ///
  /// In en, this message translates to:
  /// **'12 of 14'**
  String get n12Of14;

  /// No description provided for @n12Of20.
  ///
  /// In en, this message translates to:
  /// **'12 of 20'**
  String get n12Of20;

  /// No description provided for @n12Of20Spots.
  ///
  /// In en, this message translates to:
  /// **'12 of 20 spots'**
  String get n12Of20Spots;

  /// No description provided for @n12Of20Taken.
  ///
  /// In en, this message translates to:
  /// **'12 of 20 taken'**
  String get n12Of20Taken;

  /// No description provided for @n12SepTo11Oct1Session.
  ///
  /// In en, this message translates to:
  /// **'12 Sep to 11 Oct · 1 session in 2 weeks'**
  String get n12SepTo11Oct1Session;

  /// No description provided for @n12SpotsLeft.
  ///
  /// In en, this message translates to:
  /// **'12 spots left'**
  String get n12SpotsLeft;

  /// No description provided for @n124Videos.
  ///
  /// In en, this message translates to:
  /// **'124 videos'**
  String get n124Videos;

  /// No description provided for @n14Kg.
  ///
  /// In en, this message translates to:
  /// **'14 kg'**
  String get n14Kg;

  /// No description provided for @n14WeeksCountedBestRun9.
  ///
  /// In en, this message translates to:
  /// **'14 weeks counted · best run 9'**
  String get n14WeeksCountedBestRun9;

  /// No description provided for @n146Done5DaysLeft.
  ///
  /// In en, this message translates to:
  /// **'146 done · 5 days left'**
  String get n146Done5DaysLeft;

  /// No description provided for @n15Min5MovesLastWeeksWeights.
  ///
  /// In en, this message translates to:
  /// **'15 min · 5 moves · last week\'s weights'**
  String get n15Min5MovesLastWeeksWeights;

  /// No description provided for @n15MinBeginnerMariam.
  ///
  /// In en, this message translates to:
  /// **'15 min · beginner · Mariam'**
  String get n15MinBeginnerMariam;

  /// No description provided for @n15MinBeginnerNoEquipment.
  ///
  /// In en, this message translates to:
  /// **'15 min · beginner · no equipment'**
  String get n15MinBeginnerNoEquipment;

  /// No description provided for @n15MinDoneMonday.
  ///
  /// In en, this message translates to:
  /// **'15 min · done Monday'**
  String get n15MinDoneMonday;

  /// No description provided for @n15MinFloorOnlyCoachApproved.
  ///
  /// In en, this message translates to:
  /// **'15 min · floor only · coach-approved'**
  String get n15MinFloorOnlyCoachApproved;

  /// No description provided for @n15MinToday.
  ///
  /// In en, this message translates to:
  /// **'15 min · today'**
  String get n15MinToday;

  /// No description provided for @n15Minutes5Moves.
  ///
  /// In en, this message translates to:
  /// **'15 minutes, 5 moves'**
  String get n15Minutes5Moves;

  /// No description provided for @n15Minutes5Moves14SetsYou.
  ///
  /// In en, this message translates to:
  /// **'15 minutes, 5 moves, 14 sets. You typed nothing.'**
  String get n15Minutes5Moves14SetsYou;

  /// No description provided for @n17Jun.
  ///
  /// In en, this message translates to:
  /// **'17 Jun'**
  String get n17Jun;

  /// No description provided for @n18GProtein.
  ///
  /// In en, this message translates to:
  /// **'18 g protein'**
  String get n18GProtein;

  /// No description provided for @n18Sessions8RestDays.
  ///
  /// In en, this message translates to:
  /// **'18 sessions · 8 rest days'**
  String get n18Sessions8RestDays;

  /// No description provided for @n18WorkoutsQuietAndNoEquipment.
  ///
  /// In en, this message translates to:
  /// **'18 workouts, quiet and no equipment'**
  String get n18WorkoutsQuietAndNoEquipment;

  /// No description provided for @n18000EgpYourShare14400.
  ///
  /// In en, this message translates to:
  /// **'18,000 EGP · your share 14,400'**
  String get n18000EgpYourShare14400;

  /// No description provided for @n2Lunges.
  ///
  /// In en, this message translates to:
  /// **'2 · lunges'**
  String get n2Lunges;

  /// No description provided for @n2NoCommentsOnAnyoneElsesBody.
  ///
  /// In en, this message translates to:
  /// **'2 · No comments on anyone else\'s body'**
  String get n2NoCommentsOnAnyoneElsesBody;

  /// No description provided for @n2Sun20Tue22.
  ///
  /// In en, this message translates to:
  /// **'2 · Sun 20, Tue 22'**
  String get n2Sun20Tue22;

  /// No description provided for @n2Blocked.
  ///
  /// In en, this message translates to:
  /// **'2 blocked'**
  String get n2Blocked;

  /// No description provided for @n2HoursAfterYouSentIt.
  ///
  /// In en, this message translates to:
  /// **'2 hours after you sent it'**
  String get n2HoursAfterYouSentIt;

  /// No description provided for @n2HoursAgoVoiceNote.
  ///
  /// In en, this message translates to:
  /// **'2 hours ago · voice note'**
  String get n2HoursAgoVoiceNote;

  /// No description provided for @n2Of3Done.
  ///
  /// In en, this message translates to:
  /// **'2 of 3 done'**
  String get n2Of3Done;

  /// No description provided for @n2PlanOnlyPackages.
  ///
  /// In en, this message translates to:
  /// **'2 plan-only packages'**
  String get n2PlanOnlyPackages;

  /// No description provided for @n2RecipesThatCoverYourProtein.
  ///
  /// In en, this message translates to:
  /// **'2 recipes that cover your protein'**
  String get n2RecipesThatCoverYourProtein;

  /// No description provided for @n23.
  ///
  /// In en, this message translates to:
  /// **'2/3'**
  String get n23;

  /// No description provided for @n20CountedWeeks.
  ///
  /// In en, this message translates to:
  /// **'20 counted weeks'**
  String get n20CountedWeeks;

  /// No description provided for @n20Min6Moves.
  ///
  /// In en, this message translates to:
  /// **'20 min · 6 moves'**
  String get n20Min6Moves;

  /// No description provided for @n20MinASimpleOptionForA.
  ///
  /// In en, this message translates to:
  /// **'20 min · a simple option for a low-energy day'**
  String get n20MinASimpleOptionForA;

  /// No description provided for @n20MinEasyHabiba.
  ///
  /// In en, this message translates to:
  /// **'20 min · easy · Habiba'**
  String get n20MinEasyHabiba;

  /// No description provided for @n20MinThursday.
  ///
  /// In en, this message translates to:
  /// **'20 min · Thursday'**
  String get n20MinThursday;

  /// No description provided for @n20MinVegetarianLentilsProvideIronPeppers.
  ///
  /// In en, this message translates to:
  /// **'20 min · vegetarian · lentils provide iron, peppers provide vitamin C'**
  String get n20MinVegetarianLentilsProvideIronPeppers;

  /// No description provided for @n200GYogurt3Dates5G.
  ///
  /// In en, this message translates to:
  /// **'200 g yogurt · 3 dates · 5 g cinnamon'**
  String get n200GYogurt3Dates5G;

  /// No description provided for @n200SessionsInTwoWeeks.
  ///
  /// In en, this message translates to:
  /// **'200 sessions in two weeks'**
  String get n200SessionsInTwoWeeks;

  /// No description provided for @n200SessionsTogether.
  ///
  /// In en, this message translates to:
  /// **'200 sessions together'**
  String get n200SessionsTogether;

  /// No description provided for @n21Of25PlannedSessions.
  ///
  /// In en, this message translates to:
  /// **'21 of 25 planned sessions'**
  String get n21Of25PlannedSessions;

  /// No description provided for @n22Min4Servings14EgpA.
  ///
  /// In en, this message translates to:
  /// **'22 min · 4 servings · 14 EGP a serving'**
  String get n22Min4Servings14EgpA;

  /// No description provided for @n22Min540Kcal18GProtein.
  ///
  /// In en, this message translates to:
  /// **'22 min · 540 kcal · 18 g protein · 14 EGP'**
  String get n22Min540Kcal18GProtein;

  /// No description provided for @n22Of95G.
  ///
  /// In en, this message translates to:
  /// **'22 of 95 g'**
  String get n22Of95G;

  /// No description provided for @n23ItemsAbout640Egp.
  ///
  /// In en, this message translates to:
  /// **'23 items · about 640 EGP'**
  String get n23ItemsAbout640Egp;

  /// No description provided for @n23Of50.
  ///
  /// In en, this message translates to:
  /// **'23 of 50'**
  String get n23Of50;

  /// No description provided for @n27Comments.
  ///
  /// In en, this message translates to:
  /// **'27 comments'**
  String get n27Comments;

  /// No description provided for @n3NoSellingNoRecruiting.
  ///
  /// In en, this message translates to:
  /// **'3 · No selling, no recruiting'**
  String get n3NoSellingNoRecruiting;

  /// No description provided for @n31012Kg.
  ///
  /// In en, this message translates to:
  /// **'3 × 10 · 12 kg'**
  String get n31012Kg;

  /// No description provided for @n31012KgSuggested.
  ///
  /// In en, this message translates to:
  /// **'3 × 10 · 12 kg suggested'**
  String get n31012KgSuggested;

  /// No description provided for @n3159SeptemberWas312.
  ///
  /// In en, this message translates to:
  /// **'3 × 15 · 9 September · was 3 × 12'**
  String get n3159SeptemberWas312;

  /// No description provided for @n330Seconds.
  ///
  /// In en, this message translates to:
  /// **'3 × 30 seconds'**
  String get n330Seconds;

  /// No description provided for @n38EachSide.
  ///
  /// In en, this message translates to:
  /// **'3 × 8 each side'**
  String get n38EachSide;

  /// No description provided for @n3CheckInsWaiting.
  ///
  /// In en, this message translates to:
  /// **'3 check-ins waiting'**
  String get n3CheckInsWaiting;

  /// No description provided for @n3DaysAWeek.
  ///
  /// In en, this message translates to:
  /// **'3 days a week'**
  String get n3DaysAWeek;

  /// No description provided for @n3Jun.
  ///
  /// In en, this message translates to:
  /// **'3 Jun'**
  String get n3Jun;

  /// No description provided for @n3Min.
  ///
  /// In en, this message translates to:
  /// **'3 min'**
  String get n3Min;

  /// No description provided for @n3Min280Kcal14GProtein.
  ///
  /// In en, this message translates to:
  /// **'3 min · 280 kcal · 14 g protein · 12 EGP'**
  String get n3Min280Kcal14GProtein;

  /// No description provided for @n3Of3OneSwappedForAn.
  ///
  /// In en, this message translates to:
  /// **'3 of 3 · one swapped for an easier option'**
  String get n3Of3OneSwappedForAn;

  /// No description provided for @n3Of4Sessions.
  ///
  /// In en, this message translates to:
  /// **'3 of 4 sessions'**
  String get n3Of4Sessions;

  /// No description provided for @n3Options.
  ///
  /// In en, this message translates to:
  /// **'3 options'**
  String get n3Options;

  /// No description provided for @n3SessionsProtein95GADay.
  ///
  /// In en, this message translates to:
  /// **'3 sessions · protein 95 g a day'**
  String get n3SessionsProtein95GADay;

  /// No description provided for @n3ThingsWaiting.
  ///
  /// In en, this message translates to:
  /// **'3 things waiting'**
  String get n3ThingsWaiting;

  /// No description provided for @n30Days8SepTo7Oct.
  ///
  /// In en, this message translates to:
  /// **'30 days · 8 Sep to 7 Oct'**
  String get n30Days8SepTo7Oct;

  /// No description provided for @n30S.
  ///
  /// In en, this message translates to:
  /// **'30 s'**
  String get n30S;

  /// No description provided for @n31Of48WomenHaveFinishedTheir.
  ///
  /// In en, this message translates to:
  /// **'31 of 48 women have finished their part.'**
  String get n31Of48WomenHaveFinishedTheir;

  /// No description provided for @n32MinCountedByYourPhone.
  ///
  /// In en, this message translates to:
  /// **'32 min, counted by your phone'**
  String get n32MinCountedByYourPhone;

  /// No description provided for @n35Min.
  ///
  /// In en, this message translates to:
  /// **'35 min'**
  String get n35Min;

  /// No description provided for @n35MinYourProgram.
  ///
  /// In en, this message translates to:
  /// **'35 min · your program'**
  String get n35MinYourProgram;

  /// No description provided for @n380Kcal26GProtein.
  ///
  /// In en, this message translates to:
  /// **'380 kcal · 26 g protein'**
  String get n380Kcal26GProtein;

  /// No description provided for @n4MealSlotsAreStillEmptyPublish.
  ///
  /// In en, this message translates to:
  /// **'4 meal slots are still empty. Publish them as a free choice, or go back and fill them.'**
  String get n4MealSlotsAreStillEmptyPublish;

  /// No description provided for @n4Of12.
  ///
  /// In en, this message translates to:
  /// **'4 of 12'**
  String get n4Of12;

  /// No description provided for @n4Of30DaysStillNeedA.
  ///
  /// In en, this message translates to:
  /// **'4 of 30 days still need a meal or an explicit free choice.'**
  String get n4Of30DaysStillNeedA;

  /// No description provided for @n4ReviewsAndTheDay30Wrap.
  ///
  /// In en, this message translates to:
  /// **'4 reviews and the day-30 wrap-up'**
  String get n4ReviewsAndTheDay30Wrap;

  /// No description provided for @n4210Women.
  ///
  /// In en, this message translates to:
  /// **'4,210 women'**
  String get n4210Women;

  /// No description provided for @n4210Women38PostsToday.
  ///
  /// In en, this message translates to:
  /// **'4,210 women · 38 posts today'**
  String get n4210Women38PostsToday;

  /// No description provided for @n4754From2200Egp.
  ///
  /// In en, this message translates to:
  /// **'4.7 ★ (54) · from 2,200 EGP · replies in ~1h'**
  String get n4754From2200Egp;

  /// No description provided for @n48126.
  ///
  /// In en, this message translates to:
  /// **'4.8 ★ (126)'**
  String get n48126;

  /// No description provided for @n48126From1800Egp.
  ///
  /// In en, this message translates to:
  /// **'4.8 ★ (126) · from 1,800 EGP · replies in ~2h'**
  String get n48126From1800Egp;

  /// No description provided for @n4988From1500Egp.
  ///
  /// In en, this message translates to:
  /// **'4.9 ★ (88) · from 1,500 EGP · replies in ~4h'**
  String get n4988From1500Egp;

  /// No description provided for @n45Min.
  ///
  /// In en, this message translates to:
  /// **'45 min'**
  String get n45Min;

  /// No description provided for @n45Min460Kcal34GProtein.
  ///
  /// In en, this message translates to:
  /// **'45 min · 460 kcal · 34 g protein · 26 EGP'**
  String get n45Min460Kcal34GProtein;

  /// No description provided for @n45S.
  ///
  /// In en, this message translates to:
  /// **'45 s'**
  String get n45S;

  /// No description provided for @n45Seconds2SeptemberWas30.
  ///
  /// In en, this message translates to:
  /// **'45 seconds · 2 September · was 30'**
  String get n45Seconds2SeptemberWas30;

  /// No description provided for @n460Kcal34GProtein.
  ///
  /// In en, this message translates to:
  /// **'460 kcal · 34 g protein'**
  String get n460Kcal34GProtein;

  /// No description provided for @n490Total.
  ///
  /// In en, this message translates to:
  /// **'490 total'**
  String get n490Total;

  /// No description provided for @n5Days.
  ///
  /// In en, this message translates to:
  /// **'5 days'**
  String get n5Days;

  /// No description provided for @n5Days2DaysNotNoted.
  ///
  /// In en, this message translates to:
  /// **'5 days · 2 days not noted'**
  String get n5Days2DaysNotNoted;

  /// No description provided for @n5DaysLeft.
  ///
  /// In en, this message translates to:
  /// **'5 days left'**
  String get n5DaysLeft;

  /// No description provided for @n5DinnersOneShop.
  ///
  /// In en, this message translates to:
  /// **'5 dinners · one shop'**
  String get n5DinnersOneShop;

  /// No description provided for @n5MinDairyFreeSwapAvailable.
  ///
  /// In en, this message translates to:
  /// **'5 min · dairy-free swap available'**
  String get n5MinDairyFreeSwapAvailable;

  /// No description provided for @n50Sessions.
  ///
  /// In en, this message translates to:
  /// **'50 sessions'**
  String get n50Sessions;

  /// No description provided for @n520Kcal38GProtein.
  ///
  /// In en, this message translates to:
  /// **'520 kcal · 38 g protein'**
  String get n520Kcal38GProtein;

  /// No description provided for @n540Kcal.
  ///
  /// In en, this message translates to:
  /// **'540 kcal'**
  String get n540Kcal;

  /// No description provided for @n6EasierSessions.
  ///
  /// In en, this message translates to:
  /// **'6 easier sessions'**
  String get n6EasierSessions;

  /// No description provided for @n6NotedDays2Cycles.
  ///
  /// In en, this message translates to:
  /// **'6 noted days · 2 cycles'**
  String get n6NotedDays2Cycles;

  /// No description provided for @n60S.
  ///
  /// In en, this message translates to:
  /// **'60 s'**
  String get n60S;

  /// No description provided for @n7200EgpYourShare5760.
  ///
  /// In en, this message translates to:
  /// **'7,200 EGP · your share 5,760'**
  String get n7200EgpYourShare5760;

  /// No description provided for @n730InTheMorning.
  ///
  /// In en, this message translates to:
  /// **'7:30 in the morning'**
  String get n730InTheMorning;

  /// No description provided for @n70PointsToLevel8.
  ///
  /// In en, this message translates to:
  /// **'70 points to level 8.'**
  String get n70PointsToLevel8;

  /// No description provided for @n78G.
  ///
  /// In en, this message translates to:
  /// **'78 g'**
  String get n78G;

  /// No description provided for @n8AllAnswered.
  ///
  /// In en, this message translates to:
  /// **'8 · all answered'**
  String get n8AllAnswered;

  /// No description provided for @n8Of10.
  ///
  /// In en, this message translates to:
  /// **'8 of 10'**
  String get n8Of10;

  /// No description provided for @n8SepTo7OctReviewDue.
  ///
  /// In en, this message translates to:
  /// **'8 Sep to 7 Oct · review due today · day 9'**
  String get n8SepTo7OctReviewDue;

  /// No description provided for @n8SepTo7Oct2026.
  ///
  /// In en, this message translates to:
  /// **'8 Sep to 7 Oct 2026'**
  String get n8SepTo7Oct2026;

  /// No description provided for @n8SoFar.
  ///
  /// In en, this message translates to:
  /// **'8 so far'**
  String get n8SoFar;

  /// No description provided for @n8Weeks.
  ///
  /// In en, this message translates to:
  /// **'8 weeks'**
  String get n8Weeks;

  /// No description provided for @n8WeeksQuietNoEquipment.
  ///
  /// In en, this message translates to:
  /// **'8 weeks · quiet · no equipment'**
  String get n8WeeksQuietNoEquipment;

  /// No description provided for @n8WeeksWithYou.
  ///
  /// In en, this message translates to:
  /// **'8 weeks with you'**
  String get n8WeeksWithYou;

  /// No description provided for @n84.
  ///
  /// In en, this message translates to:
  /// **'84%'**
  String get n84;

  /// No description provided for @n9Jun.
  ///
  /// In en, this message translates to:
  /// **'9 Jun'**
  String get n9Jun;

  /// No description provided for @n95G.
  ///
  /// In en, this message translates to:
  /// **'95 g'**
  String get n95G;

  /// No description provided for @aClassOrAWalk.
  ///
  /// In en, this message translates to:
  /// **'A class or a walk'**
  String get aClassOrAWalk;

  /// No description provided for @aKneeBackOrShoulder.
  ///
  /// In en, this message translates to:
  /// **'A knee, back or shoulder'**
  String get aKneeBackOrShoulder;

  /// No description provided for @aLadiesOnlyGym.
  ///
  /// In en, this message translates to:
  /// **'A ladies-only gym'**
  String get aLadiesOnlyGym;

  /// No description provided for @aMat.
  ///
  /// In en, this message translates to:
  /// **'A mat'**
  String get aMat;

  /// No description provided for @aPersonalBest.
  ///
  /// In en, this message translates to:
  /// **'A personal best'**
  String get aPersonalBest;

  /// No description provided for @aPlanBuiltForYourDaysAnd.
  ///
  /// In en, this message translates to:
  /// **'A plan built for your days and equipment'**
  String get aPlanBuiltForYourDaysAnd;

  /// No description provided for @aRestWeekCoveredLastWeekSo.
  ///
  /// In en, this message translates to:
  /// **'A rest week covered last week, so nothing changed. The next one comes after four counted weeks.'**
  String get aRestWeekCoveredLastWeekSo;

  /// No description provided for @aRoomFullOfWomenTrainingLike.
  ///
  /// In en, this message translates to:
  /// **'A room full of women training like you'**
  String get aRoomFullOfWomenTrainingLike;

  /// No description provided for @aSelfieIsMatchedToThePhoto.
  ///
  /// In en, this message translates to:
  /// **'A selfie is matched to the photo on the card, only to prove the card is yours.'**
  String get aSelfieIsMatchedToThePhoto;

  /// No description provided for @aShortVideoCheck.
  ///
  /// In en, this message translates to:
  /// **'A short video check'**
  String get aShortVideoCheck;

  /// No description provided for @aSimpleOptionForALowEnergy.
  ///
  /// In en, this message translates to:
  /// **'A simple option for a low-energy day.'**
  String get aSimpleOptionForALowEnergy;

  /// No description provided for @aWeeklyCheckInSheAnswersBy.
  ///
  /// In en, this message translates to:
  /// **'A weekly check-in she answers by voice'**
  String get aWeeklyCheckInSheAnswersBy;

  /// No description provided for @aWomanModeratorReadsItWithinAn.
  ///
  /// In en, this message translates to:
  /// **'A woman moderator reads it within an hour'**
  String get aWomanModeratorReadsItWithinAn;

  /// No description provided for @aWomanModeratorReadsItUsuallyWithin.
  ///
  /// In en, this message translates to:
  /// **'A woman moderator reads it, usually within an hour'**
  String get aWomanModeratorReadsItUsuallyWithin;

  /// No description provided for @aWomanOnOurTeamChecksThem.
  ///
  /// In en, this message translates to:
  /// **'A woman on our team checks them, usually the same day.'**
  String get aWomanOnOurTeamChecksThem;

  /// No description provided for @aWomanOnTheTeam9amTo.
  ///
  /// In en, this message translates to:
  /// **'A woman on the team, 9am to 9pm'**
  String get aWomanOnTheTeam9amTo;

  /// No description provided for @aWomanReviewerIsLooking.
  ///
  /// In en, this message translates to:
  /// **'A woman reviewer is looking'**
  String get aWomanReviewerIsLooking;

  /// No description provided for @about1106KcalSoFarToday.
  ///
  /// In en, this message translates to:
  /// **'About 1,106 kcal so far today'**
  String get about1106KcalSoFarToday;

  /// No description provided for @about2HoursMeasuredNotTyped.
  ///
  /// In en, this message translates to:
  /// **'About 2 hours · measured, not typed'**
  String get about2HoursMeasuredNotTyped;

  /// No description provided for @about410KcalSoFarToday.
  ///
  /// In en, this message translates to:
  /// **'About 410 kcal so far today'**
  String get about410KcalSoFarToday;

  /// No description provided for @about6WeeksAway.
  ///
  /// In en, this message translates to:
  /// **'about 6 weeks away'**
  String get about6WeeksAway;

  /// No description provided for @acceptAndSendAWelcome.
  ///
  /// In en, this message translates to:
  /// **'Accept and send a welcome'**
  String get acceptAndSendAWelcome;

  /// No description provided for @acceptingTakesOneSpotOfYour20.
  ///
  /// In en, this message translates to:
  /// **'Accepting takes one spot of your 20. She pays only when you accept.'**
  String get acceptingTakesOneSpotOfYour20;

  /// No description provided for @add30Seconds.
  ///
  /// In en, this message translates to:
  /// **'Add 30 seconds'**
  String get add30Seconds;

  /// No description provided for @addADay.
  ///
  /// In en, this message translates to:
  /// **'Add a day'**
  String get addADay;

  /// No description provided for @addAMove.
  ///
  /// In en, this message translates to:
  /// **'Add a move'**
  String get addAMove;

  /// No description provided for @addAnEasierOption.
  ///
  /// In en, this message translates to:
  /// **'Add an easier option'**
  String get addAnEasierOption;

  /// No description provided for @addAnotherCertificate.
  ///
  /// In en, this message translates to:
  /// **'Add another certificate'**
  String get addAnotherCertificate;

  /// No description provided for @addAnotherExercise.
  ///
  /// In en, this message translates to:
  /// **'Add another exercise'**
  String get addAnotherExercise;

  /// No description provided for @addAnotherServing.
  ///
  /// In en, this message translates to:
  /// **'Add another serving'**
  String get addAnotherServing;

  /// No description provided for @addPeriodDates.
  ///
  /// In en, this message translates to:
  /// **'Add period dates'**
  String get addPeriodDates;

  /// No description provided for @addReps.
  ///
  /// In en, this message translates to:
  /// **'Add reps'**
  String get addReps;

  /// No description provided for @addWeightOrPhotos.
  ///
  /// In en, this message translates to:
  /// **'Add weight or photos?'**
  String get addWeightOrPhotos;

  /// No description provided for @addWorkout.
  ///
  /// In en, this message translates to:
  /// **'Add workout'**
  String get addWorkout;

  /// No description provided for @addYourPersonalBest.
  ///
  /// In en, this message translates to:
  /// **'Add your personal best'**
  String get addYourPersonalBest;

  /// No description provided for @addYoghurtDatesAndNuts.
  ///
  /// In en, this message translates to:
  /// **'Add: yoghurt, dates and nuts'**
  String get addYoghurtDatesAndNuts;

  /// No description provided for @addingUpdatesYourPlanItDoesNot.
  ///
  /// In en, this message translates to:
  /// **'Adding updates your plan. It does not mark the meal as eaten.'**
  String get addingUpdatesYourPlanItDoesNot;

  /// No description provided for @adds14GProteinFor12Egp.
  ///
  /// In en, this message translates to:
  /// **'Adds 14 g protein for 12 EGP'**
  String get adds14GProteinFor12Egp;

  /// No description provided for @adjustHerPlan.
  ///
  /// In en, this message translates to:
  /// **'Adjust her plan'**
  String get adjustHerPlan;

  /// No description provided for @adjustMeals.
  ///
  /// In en, this message translates to:
  /// **'Adjust meals'**
  String get adjustMeals;

  /// No description provided for @adjustPortion.
  ///
  /// In en, this message translates to:
  /// **'Adjust portion'**
  String get adjustPortion;

  /// No description provided for @adjustWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Adjust workouts'**
  String get adjustWorkouts;

  /// No description provided for @afterABirth.
  ///
  /// In en, this message translates to:
  /// **'After a birth'**
  String get afterABirth;

  /// No description provided for @afterABreakABirthOrAn.
  ///
  /// In en, this message translates to:
  /// **'After a break, a birth, or an injury'**
  String get afterABreakABirthOrAn;

  /// No description provided for @afterOvulationUntilTheNextPeriodStarts.
  ///
  /// In en, this message translates to:
  /// **'After ovulation, until the next period starts.'**
  String get afterOvulationUntilTheNextPeriodStarts;

  /// No description provided for @all124IncludingTheQuietOnes.
  ///
  /// In en, this message translates to:
  /// **'All 124, including the quiet ones'**
  String get all124IncludingTheQuietOnes;

  /// No description provided for @allFoods4100InTheList.
  ///
  /// In en, this message translates to:
  /// **'All foods, 4,100 in the list'**
  String get allFoods4100InTheList;

  /// No description provided for @allOfThisIsOptionalNothingIs.
  ///
  /// In en, this message translates to:
  /// **'All of this is optional. Nothing is carried over from yesterday.'**
  String get allOfThisIsOptionalNothingIs;

  /// No description provided for @allWorkouts.
  ///
  /// In en, this message translates to:
  /// **'All workouts'**
  String get allWorkouts;

  /// No description provided for @allergiesAndDietaryPreferences.
  ///
  /// In en, this message translates to:
  /// **'Allergies and dietary preferences'**
  String get allergiesAndDietaryPreferences;

  /// No description provided for @alreadySavedEditInYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Already saved, edit in your profile'**
  String get alreadySavedEditInYourProfile;

  /// No description provided for @anAlternative.
  ///
  /// In en, this message translates to:
  /// **'An alternative'**
  String get anAlternative;

  /// No description provided for @anEggIsReleasedACalendarCannot.
  ///
  /// In en, this message translates to:
  /// **'An egg is released. A calendar cannot confirm it.'**
  String get anEggIsReleasedACalendarCannot;

  /// No description provided for @anyEgyptianBank.
  ///
  /// In en, this message translates to:
  /// **'Any Egyptian bank'**
  String get anyEgyptianBank;

  /// No description provided for @anyoneElseTrainingAt11pmSoThe.
  ///
  /// In en, this message translates to:
  /// **'Anyone else training at 11pm so the flat is quiet?'**
  String get anyoneElseTrainingAt11pmSoThe;

  /// No description provided for @anythingSaraShouldKnowOptional.
  ///
  /// In en, this message translates to:
  /// **'Anything Sara should know? Optional'**
  String get anythingSaraShouldKnowOptional;

  /// No description provided for @anythingWeShouldKnowOptional.
  ///
  /// In en, this message translates to:
  /// **'Anything we should know? Optional.'**
  String get anythingWeShouldKnowOptional;

  /// No description provided for @anythingWeShouldTrainAround.
  ///
  /// In en, this message translates to:
  /// **'Anything we should train around?'**
  String get anythingWeShouldTrainAround;

  /// No description provided for @appSuggestion.
  ///
  /// In en, this message translates to:
  /// **'App suggestion'**
  String get appSuggestion;

  /// No description provided for @appetite.
  ///
  /// In en, this message translates to:
  /// **'Appetite'**
  String get appetite;

  /// No description provided for @approvedOptions.
  ///
  /// In en, this message translates to:
  /// **'Approved options'**
  String get approvedOptions;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @askAboutThis.
  ///
  /// In en, this message translates to:
  /// **'Ask about this'**
  String get askAboutThis;

  /// No description provided for @askSaraForSomethingElse.
  ///
  /// In en, this message translates to:
  /// **'Ask Sara for something else'**
  String get askSaraForSomethingElse;

  /// No description provided for @atHome3KgDumbbells.
  ///
  /// In en, this message translates to:
  /// **'At home · 3 kg dumbbells'**
  String get atHome3KgDumbbells;

  /// No description provided for @ateThis.
  ///
  /// In en, this message translates to:
  /// **'Ate this'**
  String get ateThis;

  /// No description provided for @avoid.
  ///
  /// In en, this message translates to:
  /// **'Avoid'**
  String get avoid;

  /// No description provided for @awaitingReply.
  ///
  /// In en, this message translates to:
  /// **'Awaiting reply'**
  String get awaitingReply;

  /// No description provided for @backToTheWorkout.
  ///
  /// In en, this message translates to:
  /// **'Back to the workout'**
  String get backToTheWorkout;

  /// No description provided for @bands.
  ///
  /// In en, this message translates to:
  /// **'Bands'**
  String get bands;

  /// No description provided for @bankAccount.
  ///
  /// In en, this message translates to:
  /// **'Bank account'**
  String get bankAccount;

  /// No description provided for @beHonestThisBecomesYourWeeklyGoal.
  ///
  /// In en, this message translates to:
  /// **'Be honest. This becomes your weekly goal.'**
  String get beHonestThisBecomesYourWeeklyGoal;

  /// No description provided for @beginnerFoundations.
  ///
  /// In en, this message translates to:
  /// **'Beginner foundations'**
  String get beginnerFoundations;

  /// No description provided for @beginnersAndHomeTrainingCairo.
  ///
  /// In en, this message translates to:
  /// **'Beginners and home training · Cairo'**
  String get beginnersAndHomeTrainingCairo;

  /// No description provided for @beginnersGroupReached146Sessions.
  ///
  /// In en, this message translates to:
  /// **'Beginners group reached 146 sessions'**
  String get beginnersGroupReached146Sessions;

  /// No description provided for @beingChecked.
  ///
  /// In en, this message translates to:
  /// **'Being checked'**
  String get beingChecked;

  /// No description provided for @bests.
  ///
  /// In en, this message translates to:
  /// **'Bests'**
  String get bests;

  /// No description provided for @bleedingItHappensDuringTheFollicularPhase.
  ///
  /// In en, this message translates to:
  /// **'Bleeding. It happens during the follicular phase.'**
  String get bleedingItHappensDuringTheFollicularPhase;

  /// No description provided for @blockNada.
  ///
  /// In en, this message translates to:
  /// **'Block Nada'**
  String get blockNada;

  /// No description provided for @blockedMembers.
  ///
  /// In en, this message translates to:
  /// **'Blocked members'**
  String get blockedMembers;

  /// No description provided for @blurFacesInMyPhotos.
  ///
  /// In en, this message translates to:
  /// **'Blur faces in my photos'**
  String get blurFacesInMyPhotos;

  /// No description provided for @body.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get body;

  /// No description provided for @bodyPrivately.
  ///
  /// In en, this message translates to:
  /// **'Body, privately'**
  String get bodyPrivately;

  /// No description provided for @boiledEggs.
  ///
  /// In en, this message translates to:
  /// **'Boiled eggs'**
  String get boiledEggs;

  /// No description provided for @both.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get both;

  /// No description provided for @bothImagesAreDeletedAfterTheCheck.
  ///
  /// In en, this message translates to:
  /// **'Both images are deleted after the check. We keep the result, nothing else.'**
  String get bothImagesAreDeletedAfterTheCheck;

  /// No description provided for @boxSquatToAChair.
  ///
  /// In en, this message translates to:
  /// **'Box squat to a chair'**
  String get boxSquatToAChair;

  /// No description provided for @boxSquatToAChairApprovedSubstitution.
  ///
  /// In en, this message translates to:
  /// **'Box squat to a chair · approved substitution'**
  String get boxSquatToAChairApprovedSubstitution;

  /// No description provided for @breakOneAndYouLoseYourPlace.
  ///
  /// In en, this message translates to:
  /// **'Break one and you lose your place. You can read them again any time.'**
  String get breakOneAndYouLoseYourPlace;

  /// No description provided for @breakfast22GProtein4AWeek.
  ///
  /// In en, this message translates to:
  /// **'Breakfast · 22 g protein · 4× a week'**
  String get breakfast22GProtein4AWeek;

  /// No description provided for @browseMessageWhenYouAreVerified.
  ///
  /// In en, this message translates to:
  /// **'Browse, message when you are verified'**
  String get browseMessageWhenYouAreVerified;

  /// No description provided for @buildAPlan.
  ///
  /// In en, this message translates to:
  /// **'Build a plan'**
  String get buildAPlan;

  /// No description provided for @buildFromWhatSheAlreadyEatsA.
  ///
  /// In en, this message translates to:
  /// **'Build from what she already eats. A meal plan she has never cooked is a meal plan she will not follow.'**
  String get buildFromWhatSheAlreadyEatsA;

  /// No description provided for @buildMyFirstPlan.
  ///
  /// In en, this message translates to:
  /// **'Build my first plan'**
  String get buildMyFirstPlan;

  /// No description provided for @buildPlan.
  ///
  /// In en, this message translates to:
  /// **'Build plan'**
  String get buildPlan;

  /// No description provided for @buildUpLiftABitMoreEach.
  ///
  /// In en, this message translates to:
  /// **'Build up, lift a bit more each week'**
  String get buildUpLiftABitMoreEach;

  /// No description provided for @buildYourFirstPlanAndAMeal.
  ///
  /// In en, this message translates to:
  /// **'Build your first plan and a meal template so your first client gets it on day one.'**
  String get buildYourFirstPlanAndAMeal;

  /// No description provided for @builtFromYourFourAnswers.
  ///
  /// In en, this message translates to:
  /// **'Built from your four answers'**
  String get builtFromYourFourAnswers;

  /// No description provided for @byJoiningYouAgreeToTheCommunity.
  ///
  /// In en, this message translates to:
  /// **'By joining you agree to the community rules.'**
  String get byJoiningYouAgreeToTheCommunity;

  /// No description provided for @canWeMakeThursdayShorterIHave.
  ///
  /// In en, this message translates to:
  /// **'Can we make Thursday shorter? I have 20 minutes.'**
  String get canWeMakeThursdayShorterIHave;

  /// No description provided for @cancelAnyTimeRenewsMonthly.
  ///
  /// In en, this message translates to:
  /// **'Cancel any time · renews monthly'**
  String get cancelAnyTimeRenewsMonthly;

  /// No description provided for @card.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get card;

  /// No description provided for @cardRead.
  ///
  /// In en, this message translates to:
  /// **'Card read'**
  String get cardRead;

  /// No description provided for @catchYourBreathThisStartsAndStops.
  ///
  /// In en, this message translates to:
  /// **'Catch your breath. This starts and stops on its own.'**
  String get catchYourBreathThisStartsAndStops;

  /// No description provided for @certificates.
  ///
  /// In en, this message translates to:
  /// **'Certificates'**
  String get certificates;

  /// No description provided for @certificatesChecked.
  ///
  /// In en, this message translates to:
  /// **'Certificates checked'**
  String get certificatesChecked;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @changeHowYouUseMyCycle.
  ///
  /// In en, this message translates to:
  /// **'Change how you use My cycle'**
  String get changeHowYouUseMyCycle;

  /// No description provided for @changeProgram.
  ///
  /// In en, this message translates to:
  /// **'Change program'**
  String get changeProgram;

  /// No description provided for @changesWhatWeSuggestNeverYourPlan.
  ///
  /// In en, this message translates to:
  /// **'Changes what we suggest, never your plan'**
  String get changesWhatWeSuggestNeverYourPlan;

  /// No description provided for @changingThePlanNeverChangesAMeal.
  ///
  /// In en, this message translates to:
  /// **'Changing the plan never changes a meal you already added. Tapping twice does not add it twice.'**
  String get changingThePlanNeverChangesAMeal;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @chatRepliesInAbout2Hours.
  ///
  /// In en, this message translates to:
  /// **'Chat, replies in about 2 hours'**
  String get chatRepliesInAbout2Hours;

  /// No description provided for @cheap.
  ///
  /// In en, this message translates to:
  /// **'Cheap'**
  String get cheap;

  /// No description provided for @checkIn1Of3SessionsSecond.
  ///
  /// In en, this message translates to:
  /// **'Check-in · 1 of 3 sessions · second quiet week'**
  String get checkIn1Of3SessionsSecond;

  /// No description provided for @checkIns.
  ///
  /// In en, this message translates to:
  /// **'Check-ins'**
  String get checkIns;

  /// No description provided for @checkedByAWomanNoPhotoKept.
  ///
  /// In en, this message translates to:
  /// **'Checked by a woman, no photo kept'**
  String get checkedByAWomanNoPhotoKept;

  /// No description provided for @checking.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get checking;

  /// No description provided for @checkingYourCard.
  ///
  /// In en, this message translates to:
  /// **'Checking your card'**
  String get checkingYourCard;

  /// No description provided for @chestUpWeightHeldAtYourChest.
  ///
  /// In en, this message translates to:
  /// **'Chest up, weight held at your chest'**
  String get chestUpWeightHeldAtYourChest;

  /// No description provided for @chicken1Kg.
  ///
  /// In en, this message translates to:
  /// **'Chicken 1 kg'**
  String get chicken1Kg;

  /// No description provided for @chickenAndRice.
  ///
  /// In en, this message translates to:
  /// **'Chicken and rice'**
  String get chickenAndRice;

  /// No description provided for @chooseWhatFeelsRightToday.
  ///
  /// In en, this message translates to:
  /// **'Choose what feels right today'**
  String get chooseWhatFeelsRightToday;

  /// No description provided for @chooseWhereItGoesYouCanTailor.
  ///
  /// In en, this message translates to:
  /// **'Choose where it goes. You can tailor individual sessions afterwards.'**
  String get chooseWhereItGoesYouCanTailor;

  /// No description provided for @chooseYourLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get chooseYourLanguage;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @coach.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get coach;

  /// No description provided for @coachProfiles.
  ///
  /// In en, this message translates to:
  /// **'Coach profiles'**
  String get coachProfiles;

  /// No description provided for @coachReplied.
  ///
  /// In en, this message translates to:
  /// **'Coach replied'**
  String get coachReplied;

  /// No description provided for @coachApprovedNothingStanding.
  ///
  /// In en, this message translates to:
  /// **'Coach-approved · nothing standing'**
  String get coachApprovedNothingStanding;

  /// No description provided for @coachApprovedSameMusclesLessDepth.
  ///
  /// In en, this message translates to:
  /// **'Coach-approved · same muscles, less depth'**
  String get coachApprovedSameMusclesLessDepth;

  /// No description provided for @coachesHaveProfilesForThat.
  ///
  /// In en, this message translates to:
  /// **'Coaches have profiles for that.'**
  String get coachesHaveProfilesForThat;

  /// No description provided for @coachesWhoGetIt.
  ///
  /// In en, this message translates to:
  /// **'Coaches who get it'**
  String get coachesWhoGetIt;

  /// No description provided for @completeSet2.
  ///
  /// In en, this message translates to:
  /// **'Complete set 2'**
  String get completeSet2;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @continue1800Egp.
  ///
  /// In en, this message translates to:
  /// **'Continue · 1,800 EGP'**
  String get continue1800Egp;

  /// No description provided for @continueFromSara.
  ///
  /// In en, this message translates to:
  /// **'Continue · from Sara'**
  String get continueFromSara;

  /// No description provided for @iCookedItAndAteABowl.
  ///
  /// In en, this message translates to:
  /// **'I cooked it and ate a bowl'**
  String get iCookedItAndAteABowl;

  /// No description provided for @copyAndReplaceThose2Days.
  ///
  /// In en, this message translates to:
  /// **'Copy and replace those 2 days'**
  String get copyAndReplaceThose2Days;

  /// No description provided for @copyThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Copy this week'**
  String get copyThisWeek;

  /// No description provided for @copyWeek2.
  ///
  /// In en, this message translates to:
  /// **'Copy week 2'**
  String get copyWeek2;

  /// No description provided for @coreFloorQuiet.
  ///
  /// In en, this message translates to:
  /// **'Core · floor · quiet'**
  String get coreFloorQuiet;

  /// No description provided for @countFromTheFirstDayOfOne.
  ///
  /// In en, this message translates to:
  /// **'Count from the first day of one period to the first day of the next.'**
  String get countFromTheFirstDayOfOne;

  /// No description provided for @countIt.
  ///
  /// In en, this message translates to:
  /// **'Count it'**
  String get countIt;

  /// No description provided for @countedWeeks.
  ///
  /// In en, this message translates to:
  /// **'Counted weeks'**
  String get countedWeeks;

  /// No description provided for @countsByTimeAlone.
  ///
  /// In en, this message translates to:
  /// **'Counts by time alone'**
  String get countsByTimeAlone;

  /// No description provided for @cramps.
  ///
  /// In en, this message translates to:
  /// **'Cramps'**
  String get cramps;

  /// No description provided for @createAMeal.
  ///
  /// In en, this message translates to:
  /// **'Create a meal'**
  String get createAMeal;

  /// No description provided for @createMeal.
  ///
  /// In en, this message translates to:
  /// **'Create meal'**
  String get createMeal;

  /// No description provided for @createMyAccount.
  ///
  /// In en, this message translates to:
  /// **'Create my account'**
  String get createMyAccount;

  /// No description provided for @cumin.
  ///
  /// In en, this message translates to:
  /// **'Cumin'**
  String get cumin;

  /// No description provided for @cupboard.
  ///
  /// In en, this message translates to:
  /// **'Cupboard'**
  String get cupboard;

  /// No description provided for @cycleDatesAreEstimatesThisFeatureIs.
  ///
  /// In en, this message translates to:
  /// **'Cycle dates are estimates. This feature is for general wellbeing, not diagnosis or contraception.'**
  String get cycleDatesAreEstimatesThisFeatureIs;

  /// No description provided for @cycleInformation.
  ///
  /// In en, this message translates to:
  /// **'Cycle information'**
  String get cycleInformation;

  /// No description provided for @cycleSettings.
  ///
  /// In en, this message translates to:
  /// **'Cycle settings'**
  String get cycleSettings;

  /// No description provided for @d.
  ///
  /// In en, this message translates to:
  /// **'D'**
  String get d;

  /// No description provided for @dailyCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Daily check-in'**
  String get dailyCheckIn;

  /// No description provided for @dates.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get dates;

  /// No description provided for @datesAndSymptomsOrSymptomsOnly.
  ///
  /// In en, this message translates to:
  /// **'Dates and symptoms, or symptoms only'**
  String get datesAndSymptomsOrSymptomsOnly;

  /// No description provided for @datesBleedingAndHowYouFeel.
  ///
  /// In en, this message translates to:
  /// **'Dates, bleeding and how you feel'**
  String get datesBleedingAndHowYouFeel;

  /// No description provided for @day1.
  ///
  /// In en, this message translates to:
  /// **'day 1'**
  String get day1;

  /// No description provided for @day1FullBody.
  ///
  /// In en, this message translates to:
  /// **'Day 1 · Full body'**
  String get day1FullBody;

  /// No description provided for @day10.
  ///
  /// In en, this message translates to:
  /// **'Day 10'**
  String get day10;

  /// No description provided for @day11.
  ///
  /// In en, this message translates to:
  /// **'Day 11'**
  String get day11;

  /// No description provided for @day11Of18.
  ///
  /// In en, this message translates to:
  /// **'day 11 of 18'**
  String get day11Of18;

  /// No description provided for @day2LegsAndGlutes.
  ///
  /// In en, this message translates to:
  /// **'Day 2 · Legs and glutes'**
  String get day2LegsAndGlutes;

  /// No description provided for @day3UpperBody.
  ///
  /// In en, this message translates to:
  /// **'Day 3 · Upper body'**
  String get day3UpperBody;

  /// No description provided for @day8.
  ///
  /// In en, this message translates to:
  /// **'Day 8'**
  String get day8;

  /// No description provided for @day9Of30.
  ///
  /// In en, this message translates to:
  /// **'Day 9 of 30'**
  String get day9Of30;

  /// No description provided for @daysAWeek.
  ///
  /// In en, this message translates to:
  /// **'Days a week'**
  String get daysAWeek;

  /// No description provided for @daysWritten.
  ///
  /// In en, this message translates to:
  /// **'Days written'**
  String get daysWritten;

  /// No description provided for @daysYouCanTrain.
  ///
  /// In en, this message translates to:
  /// **'Days you can train'**
  String get daysYouCanTrain;

  /// No description provided for @daysYouAddedWhatYouAte.
  ///
  /// In en, this message translates to:
  /// **'Days you added what you ate'**
  String get daysYouAddedWhatYouAte;

  /// No description provided for @deleteCycleData.
  ///
  /// In en, this message translates to:
  /// **'Delete cycle data'**
  String get deleteCycleData;

  /// No description provided for @deleteThisPeriod.
  ///
  /// In en, this message translates to:
  /// **'Delete this period'**
  String get deleteThisPeriod;

  /// No description provided for @delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get delivered;

  /// No description provided for @demoVideoWomanCoach.
  ///
  /// In en, this message translates to:
  /// **'demo video, woman coach'**
  String get demoVideoWomanCoach;

  /// No description provided for @difficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get difficulty;

  /// No description provided for @dinaFarid.
  ///
  /// In en, this message translates to:
  /// **'Dina Farid'**
  String get dinaFarid;

  /// No description provided for @dinnerYourUsual.
  ///
  /// In en, this message translates to:
  /// **'Dinner, your usual'**
  String get dinnerYourUsual;

  /// No description provided for @doItNow.
  ///
  /// In en, this message translates to:
  /// **'Do it now'**
  String get doItNow;

  /// No description provided for @done_54ca1.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done_54ca1;

  /// No description provided for @done12Kg10.
  ///
  /// In en, this message translates to:
  /// **'Done · 12 kg × 10'**
  String get done12Kg10;

  /// No description provided for @downloadEverythingOrDeleteYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Download everything, or delete your account'**
  String get downloadEverythingOrDeleteYourAccount;

  /// No description provided for @dumbbells3Kg.
  ///
  /// In en, this message translates to:
  /// **'Dumbbells 3 kg'**
  String get dumbbells3Kg;

  /// No description provided for @earned.
  ///
  /// In en, this message translates to:
  /// **'Earned'**
  String get earned;

  /// No description provided for @earningsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Earnings this month'**
  String get earningsThisMonth;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @editingHereNeverChangesTheLibraryWorkout.
  ///
  /// In en, this message translates to:
  /// **'Editing here never changes the library workout, only what Nour is assigned.'**
  String get editingHereNeverChangesTheLibraryWorkout;

  /// No description provided for @eggs20.
  ///
  /// In en, this message translates to:
  /// **'Eggs 20'**
  String get eggs20;

  /// No description provided for @egpAMonth.
  ///
  /// In en, this message translates to:
  /// **'EGP a month'**
  String get egpAMonth;

  /// No description provided for @endDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get endDate;

  /// No description provided for @ended7Oct.
  ///
  /// In en, this message translates to:
  /// **'Ended 7 Oct'**
  String get ended7Oct;

  /// No description provided for @energy.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get energy;

  /// No description provided for @energyAndAppetiteOnlyYouChoose.
  ///
  /// In en, this message translates to:
  /// **'Energy and appetite only · you choose'**
  String get energyAndAppetiteOnlyYouChoose;

  /// No description provided for @energyOnTheFirstThreeDaysOf.
  ///
  /// In en, this message translates to:
  /// **'Energy on the first three days of your last two periods'**
  String get energyOnTheFirstThreeDaysOf;

  /// No description provided for @energySleepLessBackPain.
  ///
  /// In en, this message translates to:
  /// **'Energy, sleep, less back pain'**
  String get energySleepLessBackPain;

  /// No description provided for @energyLowOn2Days.
  ///
  /// In en, this message translates to:
  /// **'Energy: low on 2 days'**
  String get energyLowOn2Days;

  /// No description provided for @english_imxmn.
  ///
  /// In en, this message translates to:
  /// **'English · العربية'**
  String get english_imxmn;

  /// No description provided for @estimated.
  ///
  /// In en, this message translates to:
  /// **'Estimated'**
  String get estimated;

  /// No description provided for @every7DaysAndOnDay30.
  ///
  /// In en, this message translates to:
  /// **'Every 7 days, and on day 30'**
  String get every7DaysAndOnDay30;

  /// No description provided for @everyAccountIsVerifiedWithIdBefore.
  ///
  /// In en, this message translates to:
  /// **'Every account is verified with ID before she can see a single post.'**
  String get everyAccountIsVerifiedWithIdBefore;

  /// No description provided for @everyCoachHereIsAVerifiedWoman.
  ///
  /// In en, this message translates to:
  /// **'Every coach here is a verified woman with checked certificates.'**
  String get everyCoachHereIsAVerifiedWoman;

  /// No description provided for @everyMemberIsVerified.
  ///
  /// In en, this message translates to:
  /// **'Every member is verified'**
  String get everyMemberIsVerified;

  /// No description provided for @everyWomanHereWentThroughTheSame.
  ///
  /// In en, this message translates to:
  /// **'Every woman here went through the same check.'**
  String get everyWomanHereWentThroughTheSame;

  /// No description provided for @everythingInTheApp.
  ///
  /// In en, this message translates to:
  /// **'Everything in the app'**
  String get everythingInTheApp;

  /// No description provided for @everythingRegularOpened.
  ///
  /// In en, this message translates to:
  /// **'Everything Regular opened'**
  String get everythingRegularOpened;

  /// No description provided for @everythingYouDidIsStillHereTo.
  ///
  /// In en, this message translates to:
  /// **'Everything you did is still here to read.'**
  String get everythingYouDidIsStillHereTo;

  /// No description provided for @existingAssignmentsReplaced.
  ///
  /// In en, this message translates to:
  /// **'Existing assignments replaced'**
  String get existingAssignmentsReplaced;

  /// No description provided for @f.
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get f;

  /// No description provided for @faceVisibleClientsPickAPersonNot.
  ///
  /// In en, this message translates to:
  /// **'Face visible. Clients pick a person, not a logo.'**
  String get faceVisibleClientsPickAPersonNot;

  /// No description provided for @facesBlurred.
  ///
  /// In en, this message translates to:
  /// **'Faces blurred'**
  String get facesBlurred;

  /// No description provided for @fawry.
  ///
  /// In en, this message translates to:
  /// **'Fawry'**
  String get fawry;

  /// No description provided for @feelBetter.
  ///
  /// In en, this message translates to:
  /// **'Feel better'**
  String get feelBetter;

  /// No description provided for @feelBetterInMyBody.
  ///
  /// In en, this message translates to:
  /// **'Feel better in my body'**
  String get feelBetterInMyBody;

  /// No description provided for @fillTheGaps.
  ///
  /// In en, this message translates to:
  /// **'Fill the gaps'**
  String get fillTheGaps;

  /// No description provided for @finalCheck.
  ///
  /// In en, this message translates to:
  /// **'Final check'**
  String get finalCheck;

  /// No description provided for @findCareNearYou.
  ///
  /// In en, this message translates to:
  /// **'Find care near you'**
  String get findCareNearYou;

  /// No description provided for @finishWorkout.
  ///
  /// In en, this message translates to:
  /// **'Finish workout'**
  String get finishWorkout;

  /// No description provided for @firstCountedWeek.
  ///
  /// In en, this message translates to:
  /// **'First counted week'**
  String get firstCountedWeek;

  /// No description provided for @firstPersonalBest.
  ///
  /// In en, this message translates to:
  /// **'First personal best'**
  String get firstPersonalBest;

  /// No description provided for @firstProgramFinished.
  ///
  /// In en, this message translates to:
  /// **'First program finished'**
  String get firstProgramFinished;

  /// No description provided for @firstSession.
  ///
  /// In en, this message translates to:
  /// **'First session'**
  String get firstSession;

  /// No description provided for @firstWeekCheck.
  ///
  /// In en, this message translates to:
  /// **'First week check'**
  String get firstWeekCheck;

  /// No description provided for @firstWeekDoneAndNoKneePain.
  ///
  /// In en, this message translates to:
  /// **'First week done, and no knee pain.'**
  String get firstWeekDoneAndNoKneePain;

  /// No description provided for @fiveDinnersBuiltFromRecipesYouHave.
  ///
  /// In en, this message translates to:
  /// **'Five dinners, built from recipes you have eaten before. Swap any of them.'**
  String get fiveDinnersBuiltFromRecipesYouHave;

  /// No description provided for @floorOnly.
  ///
  /// In en, this message translates to:
  /// **'Floor only'**
  String get floorOnly;

  /// No description provided for @follicularPhase.
  ///
  /// In en, this message translates to:
  /// **'Follicular phase'**
  String get follicularPhase;

  /// No description provided for @followAlongVideo.
  ///
  /// In en, this message translates to:
  /// **'follow-along video'**
  String get followAlongVideo;

  /// No description provided for @mealsAdded46DaysAWeek.
  ///
  /// In en, this message translates to:
  /// **'Meals added 4.6 days a week'**
  String get mealsAdded46DaysAWeek;

  /// No description provided for @foodYouAlreadyCook.
  ///
  /// In en, this message translates to:
  /// **'Food you already cook'**
  String get foodYouAlreadyCook;

  /// No description provided for @foodNoNutsVegetarianOnWeekdaysCooks.
  ///
  /// In en, this message translates to:
  /// **'Food: no nuts · vegetarian on weekdays · cooks in 20 minutes'**
  String get foodNoNutsVegetarianOnWeekdaysCooks;

  /// No description provided for @formClip.
  ///
  /// In en, this message translates to:
  /// **'Form clip'**
  String get formClip;

  /// No description provided for @fourMovesFloorOnlyNothingToCarry.
  ///
  /// In en, this message translates to:
  /// **'Four moves, floor only, nothing to carry. It counts toward your week like any session.'**
  String get fourMovesFloorOnlyNothingToCarry;

  /// No description provided for @fourWeeksInAndICarriedBoth_1e0cy.
  ///
  /// In en, this message translates to:
  /// **'Four weeks in and I carried both kids up the stairs without stopping. Started at ten minutes a day on the floor.'**
  String get fourWeeksInAndICarriedBoth_1e0cy;

  /// No description provided for @friday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get friday;

  /// No description provided for @fromSaraDumbbells3KgKeepThe.
  ///
  /// In en, this message translates to:
  /// **'From Sara · dumbbells 3 kg · “Keep the squat at 12 kg, aim for 12 reps.”'**
  String get fromSaraDumbbells3KgKeepThe;

  /// No description provided for @fromTheFirstDayOfBleedingUntil.
  ///
  /// In en, this message translates to:
  /// **'From the first day of bleeding until an egg is released.'**
  String get fromTheFirstDayOfBleedingUntil;

  /// No description provided for @fromYourCoachUnchanged.
  ///
  /// In en, this message translates to:
  /// **'From your coach · unchanged'**
  String get fromYourCoachUnchanged;

  /// No description provided for @frontOfTheCard.
  ///
  /// In en, this message translates to:
  /// **'front of the card'**
  String get frontOfTheCard;

  /// No description provided for @fulAndBaladi410Kcal22G.
  ///
  /// In en, this message translates to:
  /// **'Ful and baladi · 410 kcal · 22 g protein'**
  String get fulAndBaladi410Kcal22G;

  /// No description provided for @fulWithEgg.
  ///
  /// In en, this message translates to:
  /// **'Ful with egg'**
  String get fulWithEgg;

  /// No description provided for @fulWithEggAndCumin.
  ///
  /// In en, this message translates to:
  /// **'Ful with egg and cumin'**
  String get fulWithEggAndCumin;

  /// No description provided for @fulWithOilAndCumin.
  ///
  /// In en, this message translates to:
  /// **'Ful with oil and cumin'**
  String get fulWithOilAndCumin;

  /// No description provided for @fullNameAsOnTheAccount.
  ///
  /// In en, this message translates to:
  /// **'Full name as on the account'**
  String get fullNameAsOnTheAccount;

  /// No description provided for @fullBodyStrength34MinutesFromCoach.
  ///
  /// In en, this message translates to:
  /// **'Full-body strength · 34 minutes · from Coach Sara'**
  String get fullBodyStrength34MinutesFromCoach;

  /// No description provided for @fullBodyStrength35Min_1jwg4.
  ///
  /// In en, this message translates to:
  /// **'Full-body strength, 35 min'**
  String get fullBodyStrength35Min_1jwg4;

  /// No description provided for @futureDatesAreNotAcceptedAndAn.
  ///
  /// In en, this message translates to:
  /// **'Future dates are not accepted, and an end date cannot come before a start date.'**
  String get futureDatesAreNotAcceptedAndAn;

  /// No description provided for @gentleMobility15MinInsteadOfFull.
  ///
  /// In en, this message translates to:
  /// **'Gentle mobility, 15 min · instead of full-body strength, 35 min'**
  String get gentleMobility15MinInsteadOfFull;

  /// No description provided for @gentleMovementMayHelpSomePeopleWith.
  ///
  /// In en, this message translates to:
  /// **'Gentle movement may help some people with period pain. You can keep your plan, take the easier option, or rest. All three are fine.'**
  String get gentleMovementMayHelpSomePeopleWith;

  /// No description provided for @getBackIntoIt.
  ///
  /// In en, this message translates to:
  /// **'Get back into it'**
  String get getBackIntoIt;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @getStrongerAfterBirth.
  ///
  /// In en, this message translates to:
  /// **'Get stronger after birth'**
  String get getStrongerAfterBirth;

  /// No description provided for @giza.
  ///
  /// In en, this message translates to:
  /// **'Giza'**
  String get giza;

  /// No description provided for @gluteBridge312.
  ///
  /// In en, this message translates to:
  /// **'Glute bridge · 3 × 12'**
  String get gluteBridge312;

  /// No description provided for @glutesNoEquipmentQuiet.
  ///
  /// In en, this message translates to:
  /// **'Glutes · no equipment · quiet'**
  String get glutesNoEquipmentQuiet;

  /// No description provided for @gobletSquat31212Kg.
  ///
  /// In en, this message translates to:
  /// **'Goblet squat · 3 × 12 · 12 kg'**
  String get gobletSquat31212Kg;

  /// No description provided for @gobletSquat12KgGluteBridge3.
  ///
  /// In en, this message translates to:
  /// **'Goblet squat 12 kg · glute bridge 3 × 15 · plank 45 s'**
  String get gobletSquat12KgGluteBridge3;

  /// No description provided for @gobletSquat12Kg10TwoKilos_a8afn.
  ///
  /// In en, this message translates to:
  /// **'Goblet squat, 12 kg × 10. Two kilos more than your best.'**
  String get gobletSquat12Kg10TwoKilos_a8afn;

  /// No description provided for @gobletSquatSet3.
  ///
  /// In en, this message translates to:
  /// **'Goblet squat, set 3'**
  String get gobletSquatSet3;

  /// No description provided for @goodBeforeAnEveningSession.
  ///
  /// In en, this message translates to:
  /// **'Good before an evening session.'**
  String get goodBeforeAnEveningSession;

  /// No description provided for @grilledChickenAndSalad.
  ///
  /// In en, this message translates to:
  /// **'Grilled chicken and salad'**
  String get grilledChickenAndSalad;

  /// No description provided for @groceryList.
  ///
  /// In en, this message translates to:
  /// **'Grocery list'**
  String get groceryList;

  /// No description provided for @groupedTheWayYouShopTickAs.
  ///
  /// In en, this message translates to:
  /// **'Grouped the way you shop. Tick as you go. It remembers.'**
  String get groupedTheWayYouShopTickAs;

  /// No description provided for @groups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groups;

  /// No description provided for @habibaAnd12OthersLikedYourBest.
  ///
  /// In en, this message translates to:
  /// **'Habiba and 12 others liked your best'**
  String get habibaAnd12OthersLikedYourBest;

  /// No description provided for @hard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get hard;

  /// No description provided for @hardToFitIn.
  ///
  /// In en, this message translates to:
  /// **'Hard to fit in'**
  String get hardToFitIn;

  /// No description provided for @heelsFlatKneesOutOverYourToes.
  ///
  /// In en, this message translates to:
  /// **'Heels flat, knees out over your toes'**
  String get heelsFlatKneesOutOverYourToes;

  /// No description provided for @her30DayPlan.
  ///
  /// In en, this message translates to:
  /// **'Her 30-day plan'**
  String get her30DayPlan;

  /// No description provided for @herChoice.
  ///
  /// In en, this message translates to:
  /// **'Her choice'**
  String get herChoice;

  /// No description provided for @herFaceLive.
  ///
  /// In en, this message translates to:
  /// **'her face, live'**
  String get herFaceLive;

  /// No description provided for @herMeals.
  ///
  /// In en, this message translates to:
  /// **'Her meals'**
  String get herMeals;

  /// No description provided for @herNote.
  ///
  /// In en, this message translates to:
  /// **'Her note'**
  String get herNote;

  /// No description provided for @herTierWeeksCountedNotWeightLifted.
  ///
  /// In en, this message translates to:
  /// **'Her tier. Weeks counted, not weight lifted.'**
  String get herTierWeeksCountedNotWeightLifted;

  /// No description provided for @herWeek.
  ///
  /// In en, this message translates to:
  /// **'Her week'**
  String get herWeek;

  /// No description provided for @herWeekFromWhatSheAdded.
  ///
  /// In en, this message translates to:
  /// **'Her week, from what she added'**
  String get herWeekFromWhatSheAdded;

  /// No description provided for @high.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get high;

  /// No description provided for @highImpactDeepKneeBends.
  ///
  /// In en, this message translates to:
  /// **'High impact, deep knee bends'**
  String get highImpactDeepKneeBends;

  /// No description provided for @hips96Cm.
  ///
  /// In en, this message translates to:
  /// **'Hips 96 cm'**
  String get hips96Cm;

  /// No description provided for @holdItFlatAllFourCornersInside.
  ///
  /// In en, this message translates to:
  /// **'Hold it flat, all four corners inside'**
  String get holdItFlatAllFourCornersInside;

  /// No description provided for @holdToTalk.
  ///
  /// In en, this message translates to:
  /// **'Hold to talk'**
  String get holdToTalk;

  /// No description provided for @homeOnWeekdaysGymWhenICan.
  ///
  /// In en, this message translates to:
  /// **'Home on weekdays, gym when I can'**
  String get homeOnWeekdaysGymWhenICan;

  /// No description provided for @homeWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Home workouts'**
  String get homeWorkouts;

  /// No description provided for @homeWorkoutsGroup.
  ///
  /// In en, this message translates to:
  /// **'Home workouts group'**
  String get homeWorkoutsGroup;

  /// No description provided for @hormonalContraception.
  ///
  /// In en, this message translates to:
  /// **'Hormonal contraception'**
  String get hormonalContraception;

  /// No description provided for @howAreYouFeelingToday.
  ///
  /// In en, this message translates to:
  /// **'How are you feeling today?'**
  String get howAreYouFeelingToday;

  /// No description provided for @howHardWasIt.
  ///
  /// In en, this message translates to:
  /// **'How hard was it?'**
  String get howHardWasIt;

  /// No description provided for @howManageableWasYourPlan.
  ///
  /// In en, this message translates to:
  /// **'How manageable was your plan?'**
  String get howManageableWasYourPlan;

  /// No description provided for @howManyClientsCanYouTake.
  ///
  /// In en, this message translates to:
  /// **'How many clients can you take?'**
  String get howManyClientsCanYouTake;

  /// No description provided for @howMuchTimeDoYouReallyHave.
  ///
  /// In en, this message translates to:
  /// **'How much time do you really have?'**
  String get howMuchTimeDoYouReallyHave;

  /// No description provided for @howWeTreatEachOther.
  ///
  /// In en, this message translates to:
  /// **'How we treat each other'**
  String get howWeTreatEachOther;

  /// No description provided for @howWouldYouLikeToPay.
  ///
  /// In en, this message translates to:
  /// **'How would you like to pay?'**
  String get howWouldYouLikeToPay;

  /// No description provided for @iAgreeLetMeIn.
  ///
  /// In en, this message translates to:
  /// **'I agree, let me in'**
  String get iAgreeLetMeIn;

  /// No description provided for @iAlreadyHaveAnAccount.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get iAlreadyHaveAnAccount;

  /// No description provided for @iCoachWomen.
  ///
  /// In en, this message translates to:
  /// **'I coach women'**
  String get iCoachWomen;

  /// No description provided for @iCouldNotTrainThisWeekWork.
  ///
  /// In en, this message translates to:
  /// **'I could not train this week, work was impossible.'**
  String get iCouldNotTrainThisWeekWork;

  /// No description provided for @iDidAll3Sets.
  ///
  /// In en, this message translates to:
  /// **'I did all 3 sets'**
  String get iDidAll3Sets;

  /// No description provided for @iDontKnow.
  ///
  /// In en, this message translates to:
  /// **'I don\'t know'**
  String get iDontKnow;

  /// No description provided for @iTakeWomenBackToLiftingAfter.
  ///
  /// In en, this message translates to:
  /// **'I take women back to lifting after birth.'**
  String get iTakeWomenBackToLiftingAfter;

  /// No description provided for @iTakeWomenFromSixWeeksAfter.
  ///
  /// In en, this message translates to:
  /// **'I take women from six weeks after birth back to lifting, slowly. Most of my clients train at home with two dumbbells and 20 minutes.'**
  String get iTakeWomenFromSixWeeksAfter;

  /// No description provided for @iWearNiqabCheckMeAnotherWay.
  ///
  /// In en, this message translates to:
  /// **'I wear niqab, check me another way'**
  String get iWearNiqabCheckMeAnotherWay;

  /// No description provided for @imACoachSetUpMyProfile.
  ///
  /// In en, this message translates to:
  /// **'I\'m a coach, set up my profile'**
  String get imACoachSetUpMyProfile;

  /// No description provided for @imHereToTrain.
  ///
  /// In en, this message translates to:
  /// **'I\'m here to train'**
  String get imHereToTrain;

  /// No description provided for @idCheckedWomenOnlyReviewedByWomen.
  ///
  /// In en, this message translates to:
  /// **'ID checked, women only, reviewed by women'**
  String get idCheckedWomenOnlyReviewedByWomen;

  /// No description provided for @ifYouAreInDangerRightNow.
  ///
  /// In en, this message translates to:
  /// **'If you are in danger right now, call 122. This app cannot reach the police for you.'**
  String get ifYouAreInDangerRightNow;

  /// No description provided for @ingredientsAndAmounts.
  ///
  /// In en, this message translates to:
  /// **'Ingredients and amounts'**
  String get ingredientsAndAmounts;

  /// No description provided for @irregularCyclesHormonalContraceptionAndPerimenop.
  ///
  /// In en, this message translates to:
  /// **'Irregular cycles, hormonal contraception and perimenopause all use this mode: what you noted, no forecast.'**
  String get irregularCyclesHormonalContraceptionAndPerimenop;

  /// No description provided for @irregularPeriods.
  ///
  /// In en, this message translates to:
  /// **'Irregular periods'**
  String get irregularPeriods;

  /// No description provided for @itChecksItselfTheMomentTheSixth.
  ///
  /// In en, this message translates to:
  /// **'It checks itself the moment the sixth digit lands. On Android we read the message for you.'**
  String get itChecksItselfTheMomentTheSixth;

  /// No description provided for @itPhotographsItselfWhenItIsSharp.
  ///
  /// In en, this message translates to:
  /// **'It photographs itself when it is sharp. Nothing is uploaded until you tap send.'**
  String get itPhotographsItselfWhenItIsSharp;

  /// No description provided for @itTakesAbout90Seconds.
  ///
  /// In en, this message translates to:
  /// **'It takes about 90 seconds.'**
  String get itTakesAbout90Seconds;

  /// No description provided for @joinAboutTwoMinutes.
  ///
  /// In en, this message translates to:
  /// **'Join · about two minutes'**
  String get joinAboutTwoMinutes;

  /// No description provided for @joined.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get joined;

  /// No description provided for @june.
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get june;

  /// No description provided for @keep12KgAndAimFor12_25smx.
  ///
  /// In en, this message translates to:
  /// **'Keep 12 kg and aim for 12 reps.'**
  String get keep12KgAndAimFor12_25smx;

  /// No description provided for @keep12KgOnSquatsAddReps.
  ///
  /// In en, this message translates to:
  /// **'Keep 12 kg on squats, add reps instead'**
  String get keep12KgOnSquatsAddReps;

  /// No description provided for @keepMine.
  ///
  /// In en, this message translates to:
  /// **'Keep mine'**
  String get keepMine;

  /// No description provided for @keepMyWorkout.
  ///
  /// In en, this message translates to:
  /// **'Keep my workout'**
  String get keepMyWorkout;

  /// No description provided for @keepWeight.
  ///
  /// In en, this message translates to:
  /// **'Keep weight'**
  String get keepWeight;

  /// No description provided for @keptAllOfIt.
  ///
  /// In en, this message translates to:
  /// **'Kept, all of it'**
  String get keptAllOfIt;

  /// No description provided for @kneesFeltFineToday.
  ///
  /// In en, this message translates to:
  /// **'Knees felt fine today.'**
  String get kneesFeltFineToday;

  /// No description provided for @kneesSoreSwapItForAGlute.
  ///
  /// In en, this message translates to:
  /// **'Knees sore? Swap it for a glute bridge. Same muscles, nothing on the floor.'**
  String get kneesSoreSwapItForAGlute;

  /// No description provided for @koshariAnd2Eggs.
  ///
  /// In en, this message translates to:
  /// **'koshari and 2 eggs'**
  String get koshariAnd2Eggs;

  /// No description provided for @koshariBowl.
  ///
  /// In en, this message translates to:
  /// **'Koshari bowl'**
  String get koshariBowl;

  /// No description provided for @koshari2Eggs.
  ///
  /// In en, this message translates to:
  /// **'Koshari, 2 eggs'**
  String get koshari2Eggs;

  /// No description provided for @koshariFulAndMolokhiaInThePortions.
  ///
  /// In en, this message translates to:
  /// **'Koshari, ful and molokhia in the portions you actually serve. No grams, no calorie shaming.'**
  String get koshariFulAndMolokhiaInThePortions;

  /// No description provided for @l.
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get l;

  /// No description provided for @labels.
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get labels;

  /// No description provided for @ladiesGymStrengthAlexandria.
  ///
  /// In en, this message translates to:
  /// **'Ladies-gym strength · Alexandria'**
  String get ladiesGymStrengthAlexandria;

  /// No description provided for @ladiesOnlyGym.
  ///
  /// In en, this message translates to:
  /// **'Ladies-only gym'**
  String get ladiesOnlyGym;

  /// No description provided for @ladiesOnlyGymsAndWalkingGroups.
  ///
  /// In en, this message translates to:
  /// **'Ladies-only gyms and walking groups'**
  String get ladiesOnlyGymsAndWalkingGroups;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languages.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get languages;

  /// No description provided for @last2Days.
  ///
  /// In en, this message translates to:
  /// **'Last 2 days'**
  String get last2Days;

  /// No description provided for @last7Days3Of3Workouts.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days: 3 of 3 workouts, one lighter session she chose. Meals added on 5 days.'**
  String get last7Days3Of3Workouts;

  /// No description provided for @lastEightWeeksThePaleOneWas.
  ///
  /// In en, this message translates to:
  /// **'Last eight weeks · the pale one was a rest week'**
  String get lastEightWeeksThePaleOneWas;

  /// No description provided for @lastPeriodStart.
  ///
  /// In en, this message translates to:
  /// **'Last period start'**
  String get lastPeriodStart;

  /// No description provided for @lastReview.
  ///
  /// In en, this message translates to:
  /// **'Last review'**
  String get lastReview;

  /// No description provided for @lastTuesday10Kg10EverySet.
  ///
  /// In en, this message translates to:
  /// **'Last Tuesday: 10 kg × 10, every set finished. So we added 2 kg.'**
  String get lastTuesday10Kg10EverySet;

  /// No description provided for @left.
  ///
  /// In en, this message translates to:
  /// **'left'**
  String get left;

  /// No description provided for @legsNoEquipment.
  ///
  /// In en, this message translates to:
  /// **'Legs · no equipment'**
  String get legsNoEquipment;

  /// No description provided for @legsAndGlutesTodaysPlan.
  ///
  /// In en, this message translates to:
  /// **'Legs and glutes, today\'s plan'**
  String get legsAndGlutesTodaysPlan;

  /// No description provided for @lentilSoupAndToast.
  ///
  /// In en, this message translates to:
  /// **'Lentil soup and toast'**
  String get lentilSoupAndToast;

  /// No description provided for @lentilSoupTomatoAndToast.
  ///
  /// In en, this message translates to:
  /// **'Lentil soup, tomato and toast'**
  String get lentilSoupTomatoAndToast;

  /// No description provided for @lentils500G.
  ///
  /// In en, this message translates to:
  /// **'Lentils 500 g'**
  String get lentils500G;

  /// No description provided for @lessHungry.
  ///
  /// In en, this message translates to:
  /// **'Less hungry'**
  String get lessHungry;

  /// No description provided for @level7.
  ///
  /// In en, this message translates to:
  /// **'Level 7'**
  String get level7;

  /// No description provided for @level7AndEveryPoint.
  ///
  /// In en, this message translates to:
  /// **'Level 7 and every point'**
  String get level7AndEveryPoint;

  /// No description provided for @levelUp.
  ///
  /// In en, this message translates to:
  /// **'level up'**
  String get levelUp;

  /// No description provided for @iAteBoth696Kcal.
  ///
  /// In en, this message translates to:
  /// **'I ate both · 696 kcal'**
  String get iAteBoth696Kcal;

  /// No description provided for @addIt.
  ///
  /// In en, this message translates to:
  /// **'Add it'**
  String get addIt;

  /// No description provided for @iAteLunch.
  ///
  /// In en, this message translates to:
  /// **'I ate lunch'**
  String get iAteLunch;

  /// No description provided for @added1131Serving.
  ///
  /// In en, this message translates to:
  /// **'Added 1:13 · 1 serving'**
  String get added1131Serving;

  /// No description provided for @noted15SeptEstimated12To14.
  ///
  /// In en, this message translates to:
  /// **'Noted 15 Sept · estimated 12 to 14 Oct'**
  String get noted15SeptEstimated12To14;

  /// No description provided for @countsItself.
  ///
  /// In en, this message translates to:
  /// **'counts itself'**
  String get countsItself;

  /// No description provided for @lookAroundFirst.
  ///
  /// In en, this message translates to:
  /// **'Look around first'**
  String get lookAroundFirst;

  /// No description provided for @lookStraightAheadNoSmileNeeded.
  ///
  /// In en, this message translates to:
  /// **'Look straight ahead. No smile needed.'**
  String get lookStraightAheadNoSmileNeeded;

  /// No description provided for @loseWeight.
  ///
  /// In en, this message translates to:
  /// **'Lose weight'**
  String get loseWeight;

  /// No description provided for @loseWeightSteadily.
  ///
  /// In en, this message translates to:
  /// **'Lose weight steadily'**
  String get loseWeightSteadily;

  /// No description provided for @lowEnergyMildCrampsTodayOnly.
  ///
  /// In en, this message translates to:
  /// **'Low energy, mild cramps. Today only.'**
  String get lowEnergyMildCrampsTodayOnly;

  /// No description provided for @lunch18GProtein2AWeek.
  ///
  /// In en, this message translates to:
  /// **'Lunch · 18 g protein · 2× a week'**
  String get lunch18GProtein2AWeek;

  /// No description provided for @lunchKoshariBowlMedium.
  ///
  /// In en, this message translates to:
  /// **'Lunch · koshari bowl, medium'**
  String get lunchKoshariBowlMedium;

  /// No description provided for @lunchAdded1Serving.
  ///
  /// In en, this message translates to:
  /// **'Lunch added · 1 serving'**
  String get lunchAdded1Serving;

  /// No description provided for @lunchAdded696Kcal.
  ///
  /// In en, this message translates to:
  /// **'Lunch added · 696 kcal'**
  String get lunchAdded696Kcal;

  /// No description provided for @lunchFromYourPlan.
  ///
  /// In en, this message translates to:
  /// **'Lunch, from your plan'**
  String get lunchFromYourPlan;

  /// No description provided for @lutealPhase.
  ///
  /// In en, this message translates to:
  /// **'Luteal phase'**
  String get lutealPhase;

  /// No description provided for @machinesAndFreeWeights.
  ///
  /// In en, this message translates to:
  /// **'Machines and free weights'**
  String get machinesAndFreeWeights;

  /// No description provided for @makeItWorkForYou.
  ///
  /// In en, this message translates to:
  /// **'Make it work for you'**
  String get makeItWorkForYou;

  /// No description provided for @makeThisWeek2Sessions.
  ///
  /// In en, this message translates to:
  /// **'Make this week 2 sessions'**
  String get makeThisWeek2Sessions;

  /// No description provided for @manageable.
  ///
  /// In en, this message translates to:
  /// **'Manageable?'**
  String get manageable;

  /// No description provided for @mariamHassan.
  ///
  /// In en, this message translates to:
  /// **'Mariam Hassan'**
  String get mariamHassan;

  /// No description provided for @markedAsPlannedRestItCostsYou.
  ///
  /// In en, this message translates to:
  /// **'Marked as planned rest, it costs you nothing'**
  String get markedAsPlannedRestItCostsYou;

  /// No description provided for @matchedToThePhotoOnYourCard.
  ///
  /// In en, this message translates to:
  /// **'Matched to the photo on your card, then deleted. A woman reviews anything the check cannot decide.'**
  String get matchedToThePhotoOnYourCard;

  /// No description provided for @mealSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Meal suggestions'**
  String get mealSuggestions;

  /// No description provided for @mealsMai.
  ///
  /// In en, this message translates to:
  /// **'Meals · Mai'**
  String get mealsMai;

  /// No description provided for @mealsForToday.
  ///
  /// In en, this message translates to:
  /// **'Meals for today'**
  String get mealsForToday;

  /// No description provided for @measuredAgainstYourOwnHistoryOnlyMore.
  ///
  /// In en, this message translates to:
  /// **'Measured against your own history only. More reps, more weight, a longer hold, or a harder version. A 3 kg dumbbell counts like a 30 kg barbell.'**
  String get measuredAgainstYourOwnHistoryOnlyMore;

  /// No description provided for @measurements.
  ///
  /// In en, this message translates to:
  /// **'Measurements'**
  String get measurements;

  /// No description provided for @mediumBowlTheOneYouUsuallyServe.
  ///
  /// In en, this message translates to:
  /// **'Medium bowl, the one you usually serve'**
  String get mediumBowlTheOneYouUsuallyServe;

  /// No description provided for @membersAndTheirPostsAreBehindThe.
  ///
  /// In en, this message translates to:
  /// **'Members and their posts are behind the check'**
  String get membersAndTheirPostsAreBehindThe;

  /// No description provided for @menstruation.
  ///
  /// In en, this message translates to:
  /// **'Menstruation'**
  String get menstruation;

  /// No description provided for @messageBeforeYouDecide.
  ///
  /// In en, this message translates to:
  /// **'Message before you decide'**
  String get messageBeforeYouDecide;

  /// No description provided for @messageOrHoldToTalk.
  ///
  /// In en, this message translates to:
  /// **'Message or hold to talk'**
  String get messageOrHoldToTalk;

  /// No description provided for @mild.
  ///
  /// In en, this message translates to:
  /// **'Mild'**
  String get mild;

  /// No description provided for @minutesASession.
  ///
  /// In en, this message translates to:
  /// **'Minutes a session'**
  String get minutesASession;

  /// No description provided for @missedSessions.
  ///
  /// In en, this message translates to:
  /// **'Missed sessions'**
  String get missedSessions;

  /// No description provided for @moderate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get moderate;

  /// No description provided for @molokhiaFrozen400G.
  ///
  /// In en, this message translates to:
  /// **'Molokhia, frozen 400 g'**
  String get molokhiaFrozen400G;

  /// No description provided for @mon_4jow1.
  ///
  /// In en, this message translates to:
  /// **'Mon ✓'**
  String get mon_4jow1;

  /// No description provided for @mon14.
  ///
  /// In en, this message translates to:
  /// **'Mon 14'**
  String get mon14;

  /// No description provided for @monthlyCoachingWithNourhan.
  ///
  /// In en, this message translates to:
  /// **'Monthly coaching with Nourhan'**
  String get monthlyCoachingWithNourhan;

  /// No description provided for @moreHungry.
  ///
  /// In en, this message translates to:
  /// **'More hungry'**
  String get moreHungry;

  /// No description provided for @moreToNoteSleepBloatingBleeding.
  ///
  /// In en, this message translates to:
  /// **'More to note: sleep, bloating, bleeding'**
  String get moreToNoteSleepBloatingBleeding;

  /// No description provided for @morningSessionsBeforeTheKidsWakeUp_1m46g.
  ///
  /// In en, this message translates to:
  /// **'Morning sessions before the kids wake up.'**
  String get morningSessionsBeforeTheKidsWakeUp_1m46g;

  /// No description provided for @move3Of5.
  ///
  /// In en, this message translates to:
  /// **'Move 3 of 5'**
  String get move3Of5;

  /// No description provided for @movedToTheHarderVersion26August.
  ///
  /// In en, this message translates to:
  /// **'moved to the harder version · 26 August'**
  String get movedToTheHarderVersion26August;

  /// No description provided for @muteThisGroupForAWeek.
  ///
  /// In en, this message translates to:
  /// **'Mute this group for a week'**
  String get muteThisGroupForAWeek;

  /// No description provided for @myCoach.
  ///
  /// In en, this message translates to:
  /// **'My coach'**
  String get myCoach;

  /// No description provided for @myCoachCanSeeMyMealsAnd.
  ///
  /// In en, this message translates to:
  /// **'My coach can see my meals and workouts'**
  String get myCoachCanSeeMyMealsAnd;

  /// No description provided for @myCyclePeriodDay2.
  ///
  /// In en, this message translates to:
  /// **'My cycle · period day 2'**
  String get myCyclePeriodDay2;

  /// No description provided for @nameTierAndGroups.
  ///
  /// In en, this message translates to:
  /// **'Name, tier and groups'**
  String get nameTierAndGroups;

  /// No description provided for @nasmCpt.
  ///
  /// In en, this message translates to:
  /// **'NASM CPT'**
  String get nasmCpt;

  /// No description provided for @nasmCptPreAndPostnatalVerified.
  ///
  /// In en, this message translates to:
  /// **'NASM CPT · pre and postnatal · verified'**
  String get nasmCptPreAndPostnatalVerified;

  /// No description provided for @nasmCptPreAndPostnatalSpecialistVerified.
  ///
  /// In en, this message translates to:
  /// **'NASM CPT · Pre and postnatal specialist · verified 12 March'**
  String get nasmCptPreAndPostnatalSpecialistVerified;

  /// No description provided for @needAnIdeaForDinner.
  ///
  /// In en, this message translates to:
  /// **'Need an idea for dinner?'**
  String get needAnIdeaForDinner;

  /// No description provided for @needsAReply.
  ///
  /// In en, this message translates to:
  /// **'Needs a reply'**
  String get needsAReply;

  /// No description provided for @needsReply.
  ///
  /// In en, this message translates to:
  /// **'Needs reply'**
  String get needsReply;

  /// No description provided for @newEnquiry.
  ///
  /// In en, this message translates to:
  /// **'New enquiry'**
  String get newEnquiry;

  /// No description provided for @newEnquiryPostpartumHome20Min.
  ///
  /// In en, this message translates to:
  /// **'New enquiry · postpartum, home, 20 min'**
  String get newEnquiryPostpartumHome20Min;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @nextPeriodEstimate12To14October.
  ///
  /// In en, this message translates to:
  /// **'Next period estimate: 12 to 14 October, based on your recorded cycles. Timing can change.'**
  String get nextPeriodEstimate12To14October;

  /// No description provided for @nextTimeWeKeep12KgAnd.
  ///
  /// In en, this message translates to:
  /// **'Next time we keep 12 kg and aim for 10 again. A hard set never drops your weight by itself.'**
  String get nextTimeWeKeep12KgAnd;

  /// No description provided for @nextStrong.
  ///
  /// In en, this message translates to:
  /// **'Next: Strong'**
  String get nextStrong;

  /// No description provided for @nhsPeriodPain.
  ///
  /// In en, this message translates to:
  /// **'NHS: period pain'**
  String get nhsPeriodPain;

  /// No description provided for @noDatesNoEstimates.
  ///
  /// In en, this message translates to:
  /// **'No dates, no estimates'**
  String get noDatesNoEstimates;

  /// No description provided for @noDatesNoEstimatesJustHowYou.
  ///
  /// In en, this message translates to:
  /// **'No dates, no estimates · just how you feel'**
  String get noDatesNoEstimatesJustHowYou;

  /// No description provided for @noDayRangesNoYouAreHere.
  ///
  /// In en, this message translates to:
  /// **'No day ranges, no “you are here”, and no hormone chart, because none of that can be measured from dates.'**
  String get noDayRangesNoYouAreHere;

  /// No description provided for @noJumping.
  ///
  /// In en, this message translates to:
  /// **'No jumping'**
  String get noJumping;

  /// No description provided for @noJumpingNoEquipmentTenMinutesCounts.
  ///
  /// In en, this message translates to:
  /// **'No jumping, no equipment, ten minutes counts. Your neighbours will never know.'**
  String get noJumpingNoEquipmentTenMinutesCounts;

  /// No description provided for @noNutsVegetarianOnWeekdays.
  ///
  /// In en, this message translates to:
  /// **'No nuts. Vegetarian on weekdays.'**
  String get noNutsVegetarianOnWeekdays;

  /// No description provided for @noScreenshotsNoSharingAnyoneElseOutside.
  ///
  /// In en, this message translates to:
  /// **'No screenshots, no sharing anyone else outside.'**
  String get noScreenshotsNoSharingAnyoneElseOutside;

  /// No description provided for @noStandingNothingToHold.
  ///
  /// In en, this message translates to:
  /// **'No standing, nothing to hold'**
  String get noStandingNothingToHold;

  /// No description provided for @nobodyHereHasBeenTrainingMoreThan.
  ///
  /// In en, this message translates to:
  /// **'Nobody here has been training more than a year.'**
  String get nobodyHereHasBeenTrainingMoreThan;

  /// No description provided for @nobodySeesThisNotTheCommunityNot.
  ///
  /// In en, this message translates to:
  /// **'Nobody sees this. Not the community, not your coach unless you send it.'**
  String get nobodySeesThisNotTheCommunityNot;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @noneOfThese.
  ///
  /// In en, this message translates to:
  /// **'None of these'**
  String get noneOfThese;

  /// No description provided for @notAFitForMe.
  ///
  /// In en, this message translates to:
  /// **'Not a fit for me'**
  String get notAFitForMe;

  /// No description provided for @notEvenAComplimentTalkAboutThe.
  ///
  /// In en, this message translates to:
  /// **'Not even a compliment. Talk about the work instead.'**
  String get notEvenAComplimentTalkAboutThe;

  /// No description provided for @notFeelingItToday.
  ///
  /// In en, this message translates to:
  /// **'Not feeling it today?'**
  String get notFeelingItToday;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @notShared.
  ///
  /// In en, this message translates to:
  /// **'Not shared'**
  String get notShared;

  /// No description provided for @notSure.
  ///
  /// In en, this message translates to:
  /// **'Not sure'**
  String get notSure;

  /// No description provided for @nothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing'**
  String get nothing;

  /// No description provided for @nothingChangesUntilYouTellUsHow.
  ///
  /// In en, this message translates to:
  /// **'Nothing changes until you tell us how you feel.'**
  String get nothingChangesUntilYouTellUsHow;

  /// No description provided for @nothingIsLostOneSessionStartsIt.
  ///
  /// In en, this message translates to:
  /// **'Nothing is lost. One session starts it.'**
  String get nothingIsLostOneSessionStartsIt;

  /// No description provided for @nothingIsScheduledYetSoNothingIs.
  ///
  /// In en, this message translates to:
  /// **'Nothing is scheduled yet, so nothing is shown as assigned. Your own workouts and recipes still work.'**
  String get nothingIsScheduledYetSoNothingIs;

  /// No description provided for @nothingIsSentWhenYouPickIt.
  ///
  /// In en, this message translates to:
  /// **'Nothing is sent when you pick it. You preview first, then send.'**
  String get nothingIsSentWhenYouPickIt;

  /// No description provided for @nothingRightNow.
  ///
  /// In en, this message translates to:
  /// **'Nothing right now'**
  String get nothingRightNow;

  /// No description provided for @nourMeals.
  ///
  /// In en, this message translates to:
  /// **'Nour · meals'**
  String get nourMeals;

  /// No description provided for @nourReview.
  ///
  /// In en, this message translates to:
  /// **'Nour · review'**
  String get nourReview;

  /// No description provided for @now.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get now;

  /// No description provided for @now_65hr.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get now_65hr;

  /// No description provided for @numbersOnlyNeverAWeightFromThe.
  ///
  /// In en, this message translates to:
  /// **'Numbers only, never a weight from the scale.'**
  String get numbersOnlyNeverAWeightFromThe;

  /// No description provided for @numbersOnlyNeverWeightFromAScale.
  ///
  /// In en, this message translates to:
  /// **'Numbers only, never weight from a scale'**
  String get numbersOnlyNeverWeightFromAScale;

  /// No description provided for @nutFree.
  ///
  /// In en, this message translates to:
  /// **'Nut-free'**
  String get nutFree;

  /// No description provided for @nutritionDetailsUnavailableThisMealUsesIngredien.
  ///
  /// In en, this message translates to:
  /// **'Nutrition details unavailable. This meal uses ingredients without verified values, so no totals are shown.'**
  String get nutritionDetailsUnavailableThisMealUsesIngredien;

  /// No description provided for @offByDefaultCoachingNeverRequiresIt.
  ///
  /// In en, this message translates to:
  /// **'Off by default. Coaching never requires it.'**
  String get offByDefaultCoachingNeverRequiresIt;

  /// No description provided for @offUnlessYouTurnItOnCoaching.
  ///
  /// In en, this message translates to:
  /// **'Off unless you turn it on. Coaching never requires it.'**
  String get offUnlessYouTurnItOnCoaching;

  /// No description provided for @offerAnEasierWorkoutWhenINote.
  ///
  /// In en, this message translates to:
  /// **'Offer an easier workout when I note low energy'**
  String get offerAnEasierWorkoutWhenINote;

  /// No description provided for @oldest19HoursYouPromiseOneWorking.
  ///
  /// In en, this message translates to:
  /// **'Oldest 19 hours · you promise one working day'**
  String get oldest19HoursYouPromiseOneWorking;

  /// No description provided for @oldest19HoursYouPromise24.
  ///
  /// In en, this message translates to:
  /// **'Oldest: 19 hours · you promise 24'**
  String get oldest19HoursYouPromise24;

  /// No description provided for @onByDefaultForEveryPost.
  ///
  /// In en, this message translates to:
  /// **'On by default for every post'**
  String get onByDefaultForEveryPost;

  /// No description provided for @onByDefaultTapToShowYours.
  ///
  /// In en, this message translates to:
  /// **'On by default. Tap to show yours.'**
  String get onByDefaultTapToShowYours;

  /// No description provided for @onTrack3Of3ThisWeek.
  ///
  /// In en, this message translates to:
  /// **'On track · 3 of 3 this week'**
  String get onTrack3Of3ThisWeek;

  /// No description provided for @onTrackFinishedHerProgram.
  ///
  /// In en, this message translates to:
  /// **'On track · finished her program'**
  String get onTrackFinishedHerProgram;

  /// No description provided for @onTrackWeek4Of8.
  ///
  /// In en, this message translates to:
  /// **'On track · week 4 of 8'**
  String get onTrackWeek4Of8;

  /// No description provided for @oneADayQuiet10pmTo8am.
  ///
  /// In en, this message translates to:
  /// **'One a day, quiet 10pm to 8am'**
  String get oneADayQuiet10pmTo8am;

  /// No description provided for @oneCheckThenYouAreIn.
  ///
  /// In en, this message translates to:
  /// **'One check, then you are in'**
  String get oneCheckThenYouAreIn;

  /// No description provided for @oneLegAtATimeHoldsThe.
  ///
  /// In en, this message translates to:
  /// **'One leg at a time, holds the weight'**
  String get oneLegAtATimeHoldsThe;

  /// No description provided for @oneLineAboutYou.
  ///
  /// In en, this message translates to:
  /// **'One line about you'**
  String get oneLineAboutYou;

  /// No description provided for @oneMinuteItIsFilledInFrom.
  ///
  /// In en, this message translates to:
  /// **'One minute · it is filled in from what you added'**
  String get oneMinuteItIsFilledInFrom;

  /// No description provided for @oneMinuteMostlyFilledInAlready.
  ///
  /// In en, this message translates to:
  /// **'One minute · mostly filled in already'**
  String get oneMinuteMostlyFilledInAlready;

  /// No description provided for @oneMoreAndYouHaveFinishedWhatever.
  ///
  /// In en, this message translates to:
  /// **'One more and you have finished, whatever anyone else does.'**
  String get oneMoreAndYouHaveFinishedWhatever;

  /// No description provided for @oneMoreSessionAndThisWeekCounts.
  ///
  /// In en, this message translates to:
  /// **'One more session and this week counts.'**
  String get oneMoreSessionAndThisWeekCounts;

  /// No description provided for @oneNudgeADayAtMostAt.
  ///
  /// In en, this message translates to:
  /// **'One nudge a day at most, at your usual time. Ignore three and they stop by themselves.'**
  String get oneNudgeADayAtMostAt;

  /// No description provided for @oneShopCoversIt.
  ///
  /// In en, this message translates to:
  /// **'One shop covers it'**
  String get oneShopCoversIt;

  /// No description provided for @oneShortSheetItDoesNotMean.
  ///
  /// In en, this message translates to:
  /// **'One short sheet. It does not mean a daily reply.'**
  String get oneShortSheetItDoesNotMean;

  /// No description provided for @onions1Kg.
  ///
  /// In en, this message translates to:
  /// **'Onions 1 kg'**
  String get onions1Kg;

  /// No description provided for @onlyIfYouWantEstimatesLater.
  ///
  /// In en, this message translates to:
  /// **'Only if you want estimates later'**
  String get onlyIfYouWantEstimatesLater;

  /// No description provided for @onlyWomenReviewTheseChecksNoMan.
  ///
  /// In en, this message translates to:
  /// **'Only women review these checks. No man ever sees your face, your card or your name.'**
  String get onlyWomenReviewTheseChecksNoMan;

  /// No description provided for @onlyYouAndYourCoachEverSee.
  ///
  /// In en, this message translates to:
  /// **'Only you and your coach ever see this.'**
  String get onlyYouAndYourCoachEverSee;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @openAsAnEditableDraftNothingIs.
  ///
  /// In en, this message translates to:
  /// **'Open as an editable draft. Nothing is sent automatically as personal feedback.'**
  String get openAsAnEditableDraftNothingIs;

  /// No description provided for @opensWithRamadan6400Women.
  ///
  /// In en, this message translates to:
  /// **'Opens with Ramadan · 6,400 women'**
  String get opensWithRamadan6400Women;

  /// No description provided for @optionGentleMobility.
  ///
  /// In en, this message translates to:
  /// **'Option: gentle mobility'**
  String get optionGentleMobility;

  /// No description provided for @optionalNeverRequired.
  ///
  /// In en, this message translates to:
  /// **'Optional. Never required.'**
  String get optionalNeverRequired;

  /// No description provided for @optionalYouCanUseTheAppForever.
  ///
  /// In en, this message translates to:
  /// **'Optional. You can use the app forever without it.'**
  String get optionalYouCanUseTheAppForever;

  /// No description provided for @orJustAddBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Or just add breakfast'**
  String get orJustAddBreakfast;

  /// No description provided for @orOneYouveHadBefore.
  ///
  /// In en, this message translates to:
  /// **'Or one you\'ve had before'**
  String get orOneYouveHadBefore;

  /// No description provided for @orSayItZumba40Minutes.
  ///
  /// In en, this message translates to:
  /// **'Or say it: \"Zumba, 40 minutes\"'**
  String get orSayItZumba40Minutes;

  /// No description provided for @ovulation.
  ///
  /// In en, this message translates to:
  /// **'Ovulation'**
  String get ovulation;

  /// No description provided for @package.
  ///
  /// In en, this message translates to:
  /// **'Package'**
  String get package;

  /// No description provided for @packages.
  ///
  /// In en, this message translates to:
  /// **'Packages'**
  String get packages;

  /// No description provided for @paidOutOnThe1stOfEach.
  ///
  /// In en, this message translates to:
  /// **'Paid out on the 1st of each month.'**
  String get paidOutOnThe1stOfEach;

  /// No description provided for @pasta500G.
  ///
  /// In en, this message translates to:
  /// **'Pasta 500 g'**
  String get pasta500G;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @pay.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get pay;

  /// No description provided for @pay1800Egp.
  ///
  /// In en, this message translates to:
  /// **'Pay 1,800 EGP'**
  String get pay1800Egp;

  /// No description provided for @payWithACodeAtAnyFawry.
  ///
  /// In en, this message translates to:
  /// **'Pay with a code at any Fawry point'**
  String get payWithACodeAtAnyFawry;

  /// No description provided for @payoutMethod.
  ///
  /// In en, this message translates to:
  /// **'Payout method'**
  String get payoutMethod;

  /// No description provided for @payoutOn1OctoberToVodafoneCash.
  ///
  /// In en, this message translates to:
  /// **'Payout on 1 October to Vodafone Cash · 010 xxx xx32'**
  String get payoutOn1OctoberToVodafoneCash;

  /// No description provided for @perimenopause.
  ///
  /// In en, this message translates to:
  /// **'Perimenopause'**
  String get perimenopause;

  /// No description provided for @periodDay2SymptomTracking.
  ///
  /// In en, this message translates to:
  /// **'Period day 2 · symptom tracking'**
  String get periodDay2SymptomTracking;

  /// No description provided for @personalBest.
  ///
  /// In en, this message translates to:
  /// **'Personal best'**
  String get personalBest;

  /// No description provided for @photo.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photo;

  /// No description provided for @photosOfTheCertificateAreEnoughWe.
  ///
  /// In en, this message translates to:
  /// **'Photos of the certificate are enough. We check the issuing body ourselves, and unverified coaches cannot take clients.'**
  String get photosOfTheCertificateAreEnoughWe;

  /// No description provided for @pickADifferentProgram.
  ///
  /// In en, this message translates to:
  /// **'Pick a different program'**
  String get pickADifferentProgram;

  /// No description provided for @pickOneItChangesTheProgramNot.
  ///
  /// In en, this message translates to:
  /// **'Pick one. It changes the program, not the app.'**
  String get pickOneItChangesTheProgramNot;

  /// No description provided for @pickUpToThreeClientsFilterBy.
  ///
  /// In en, this message translates to:
  /// **'Pick up to three. Clients filter by these.'**
  String get pickUpToThreeClientsFilterBy;

  /// No description provided for @planNeeded.
  ///
  /// In en, this message translates to:
  /// **'Plan needed'**
  String get planNeeded;

  /// No description provided for @planUpdated.
  ///
  /// In en, this message translates to:
  /// **'Plan updated'**
  String get planUpdated;

  /// No description provided for @planUpdatedThursday18September.
  ///
  /// In en, this message translates to:
  /// **'Plan updated · Thursday 18 September'**
  String get planUpdatedThursday18September;

  /// No description provided for @plankHold.
  ///
  /// In en, this message translates to:
  /// **'Plank hold'**
  String get plankHold;

  /// No description provided for @planned.
  ///
  /// In en, this message translates to:
  /// **'planned'**
  String get planned;

  /// No description provided for @plannedBySara1Serving540Kcal.
  ///
  /// In en, this message translates to:
  /// **'Planned by Sara · 1 serving · 540 kcal'**
  String get plannedBySara1Serving540Kcal;

  /// No description provided for @plannedFullBodyStrength.
  ///
  /// In en, this message translates to:
  /// **'Planned: full-body strength'**
  String get plannedFullBodyStrength;

  /// No description provided for @platesSheAlreadyEats.
  ///
  /// In en, this message translates to:
  /// **'Plates she already eats'**
  String get platesSheAlreadyEats;

  /// No description provided for @postToHomeWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Post to Home workouts'**
  String get postToHomeWorkouts;

  /// No description provided for @postpartumRebuild2HoursAgo.
  ///
  /// In en, this message translates to:
  /// **'Postpartum rebuild · 2 hours ago'**
  String get postpartumRebuild2HoursAgo;

  /// No description provided for @postpartumRebuildWeek3.
  ///
  /// In en, this message translates to:
  /// **'Postpartum rebuild · week 3'**
  String get postpartumRebuildWeek3;

  /// No description provided for @postpartumStrengthGizaArabicAndEnglish.
  ///
  /// In en, this message translates to:
  /// **'Postpartum strength · Giza · Arabic and English'**
  String get postpartumStrengthGizaArabicAndEnglish;

  /// No description provided for @postpartum4MonthsTrainsAtHome20.
  ///
  /// In en, this message translates to:
  /// **'Postpartum, 4 months · trains at home · 20 minutes · 3 days a week'**
  String get postpartum4MonthsTrainsAtHome20;

  /// No description provided for @preferNotToSay.
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get preferNotToSay;

  /// No description provided for @pregnancy.
  ///
  /// In en, this message translates to:
  /// **'Pregnancy'**
  String get pregnancy;

  /// No description provided for @pregnant.
  ///
  /// In en, this message translates to:
  /// **'Pregnant'**
  String get pregnant;

  /// No description provided for @pregnantOrPostpartum.
  ///
  /// In en, this message translates to:
  /// **'Pregnant or postpartum'**
  String get pregnantOrPostpartum;

  /// No description provided for @prepTime.
  ///
  /// In en, this message translates to:
  /// **'Prep time'**
  String get prepTime;

  /// No description provided for @preparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get preparing;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @previewHerDay.
  ///
  /// In en, this message translates to:
  /// **'Preview her day'**
  String get previewHerDay;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @priceAMonth.
  ///
  /// In en, this message translates to:
  /// **'Price a month'**
  String get priceAMonth;

  /// No description provided for @private.
  ///
  /// In en, this message translates to:
  /// **'private'**
  String get private;

  /// No description provided for @profileVisibleToMembers.
  ///
  /// In en, this message translates to:
  /// **'Profile visible to members'**
  String get profileVisibleToMembers;

  /// No description provided for @protein78GAverageTarget95G.
  ///
  /// In en, this message translates to:
  /// **'Protein 78 g average · target 95 g'**
  String get protein78GAverageTarget95G;

  /// No description provided for @proteinAverage.
  ///
  /// In en, this message translates to:
  /// **'Protein average'**
  String get proteinAverage;

  /// No description provided for @proteinTarget.
  ///
  /// In en, this message translates to:
  /// **'Protein target'**
  String get proteinTarget;

  /// No description provided for @publishPlan.
  ///
  /// In en, this message translates to:
  /// **'Publish plan'**
  String get publishPlan;

  /// No description provided for @publishToNour.
  ///
  /// In en, this message translates to:
  /// **'Publish to Nour'**
  String get publishToNour;

  /// No description provided for @quickSelfie.
  ///
  /// In en, this message translates to:
  /// **'Quick selfie'**
  String get quickSelfie;

  /// No description provided for @quiet1SessionIn2Weeks.
  ///
  /// In en, this message translates to:
  /// **'Quiet · 1 session in 2 weeks'**
  String get quiet1SessionIn2Weeks;

  /// No description provided for @quietNoEquipmentFloor.
  ///
  /// In en, this message translates to:
  /// **'Quiet · no equipment · floor'**
  String get quietNoEquipmentFloor;

  /// No description provided for @quietMovesFloorNothingToCarry.
  ///
  /// In en, this message translates to:
  /// **'Quiet moves, floor, nothing to carry'**
  String get quietMovesFloorNothingToCarry;

  /// No description provided for @quietWorkoutsForHome.
  ///
  /// In en, this message translates to:
  /// **'Quiet workouts for home'**
  String get quietWorkoutsForHome;

  /// No description provided for @quietWorkoutsForHomeFoodYouAlready.
  ///
  /// In en, this message translates to:
  /// **'Quiet workouts for home, food you already cook, and a community only women can enter.'**
  String get quietWorkoutsForHomeFoodYouAlready;

  /// No description provided for @ramadan.
  ///
  /// In en, this message translates to:
  /// **'Ramadan'**
  String get ramadan;

  /// No description provided for @ramadanModeOff.
  ///
  /// In en, this message translates to:
  /// **'Ramadan mode off'**
  String get ramadanModeOff;

  /// No description provided for @ramadanTraining.
  ///
  /// In en, this message translates to:
  /// **'Ramadan training'**
  String get ramadanTraining;

  /// No description provided for @read.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get read;

  /// No description provided for @readNhsGuidanceOnPeriodPain.
  ///
  /// In en, this message translates to:
  /// **'Read NHS guidance on period pain'**
  String get readNhsGuidanceOnPeriodPain;

  /// No description provided for @readTheThreeRules.
  ///
  /// In en, this message translates to:
  /// **'Read the three rules'**
  String get readTheThreeRules;

  /// No description provided for @readableNewMessagesAreClosed.
  ///
  /// In en, this message translates to:
  /// **'Readable · new messages are closed'**
  String get readableNewMessagesAreClosed;

  /// No description provided for @readableNoNewAssignments.
  ///
  /// In en, this message translates to:
  /// **'Readable · no new assignments'**
  String get readableNoNewAssignments;

  /// No description provided for @rebuiltAroundThePelvicFloorFirstCleared.
  ///
  /// In en, this message translates to:
  /// **'Rebuilt around the pelvic floor first. Cleared for postpartum from week six, with your doctor\'s go-ahead.'**
  String get rebuiltAroundThePelvicFloorFirstCleared;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// No description provided for @recording.
  ///
  /// In en, this message translates to:
  /// **'Recording…'**
  String get recording;

  /// No description provided for @registeredDietitianAndCoachPostpartumStrength.
  ///
  /// In en, this message translates to:
  /// **'Registered dietitian and coach · postpartum strength'**
  String get registeredDietitianAndCoachPostpartumStrength;

  /// No description provided for @regular.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get regular;

  /// No description provided for @regularAsksForFourOfYourLast.
  ///
  /// In en, this message translates to:
  /// **'Regular asks for four of your last eight weeks, and three counted. One more counted week brings it back.'**
  String get regularAsksForFourOfYourLast;

  /// No description provided for @regularHoldsWhileFourOfYourLast.
  ///
  /// In en, this message translates to:
  /// **'Regular holds while four of your last eight weeks count. Six did.'**
  String get regularHoldsWhileFourOfYourLast;

  /// No description provided for @reminderTime.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get reminderTime;

  /// No description provided for @repliesIn2h.
  ///
  /// In en, this message translates to:
  /// **'Replies in ~2h'**
  String get repliesIn2h;

  /// No description provided for @replyInChat.
  ///
  /// In en, this message translates to:
  /// **'Reply in chat'**
  String get replyInChat;

  /// No description provided for @replyTimeShownToClients.
  ///
  /// In en, this message translates to:
  /// **'Reply time shown to clients'**
  String get replyTimeShownToClients;

  /// No description provided for @reportSomeone.
  ///
  /// In en, this message translates to:
  /// **'Report someone'**
  String get reportSomeone;

  /// No description provided for @reportThisPost.
  ///
  /// In en, this message translates to:
  /// **'Report this post'**
  String get reportThisPost;

  /// No description provided for @reportsYouMade.
  ///
  /// In en, this message translates to:
  /// **'Reports you made'**
  String get reportsYouMade;

  /// No description provided for @reportsBlockedMembersHelp.
  ///
  /// In en, this message translates to:
  /// **'Reports, blocked members, help'**
  String get reportsBlockedMembersHelp;

  /// No description provided for @reps.
  ///
  /// In en, this message translates to:
  /// **'Reps'**
  String get reps;

  /// No description provided for @restBetweenSets.
  ///
  /// In en, this message translates to:
  /// **'Rest between sets'**
  String get restBetweenSets;

  /// No description provided for @restStartsItself.
  ///
  /// In en, this message translates to:
  /// **'Rest starts itself'**
  String get restStartsItself;

  /// No description provided for @restTimerStartsItself.
  ///
  /// In en, this message translates to:
  /// **'Rest timer starts itself'**
  String get restTimerStartsItself;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @reviewDueDay9Of30Waiting.
  ///
  /// In en, this message translates to:
  /// **'Review due · day 9 of 30 · waiting 19 hours'**
  String get reviewDueDay9Of30Waiting;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @reviewsDue.
  ///
  /// In en, this message translates to:
  /// **'Reviews due'**
  String get reviewsDue;

  /// No description provided for @revisionsDefaultToFutureDatesASession.
  ///
  /// In en, this message translates to:
  /// **'Revisions default to future dates. A session she has already started, and anything she has already added, stay on the version she used.'**
  String get revisionsDefaultToFutureDatesASession;

  /// No description provided for @rice1Kg.
  ///
  /// In en, this message translates to:
  /// **'Rice 1 kg'**
  String get rice1Kg;

  /// No description provided for @riceLentilsAndPastaCookedTogetherWith.
  ///
  /// In en, this message translates to:
  /// **'Rice, lentils and pasta cooked together, with the fried onions on top and the sauce on the side so you decide how much goes on.'**
  String get riceLentilsAndPastaCookedTogetherWith;

  /// No description provided for @riceLentilsPasta.
  ///
  /// In en, this message translates to:
  /// **'Rice, lentils, pasta'**
  String get riceLentilsPasta;

  /// No description provided for @sameMusclesQuieterOnTheFloor.
  ///
  /// In en, this message translates to:
  /// **'Same muscles, quieter on the floor.'**
  String get sameMusclesQuieterOnTheFloor;

  /// No description provided for @saraApprovedTheseInAdvanceSoYou.
  ///
  /// In en, this message translates to:
  /// **'Sara approved these in advance, so you do not have to wait for a reply.'**
  String get saraApprovedTheseInAdvanceSoYou;

  /// No description provided for @saraHanyDay9Of30.
  ///
  /// In en, this message translates to:
  /// **'Sara Hany · day 9 of 30'**
  String get saraHanyDay9Of30;

  /// No description provided for @saraIsPreparingYourPlan.
  ///
  /// In en, this message translates to:
  /// **'Sara is preparing your plan'**
  String get saraIsPreparingYourPlan;

  /// No description provided for @saraRepliedToYourReview.
  ///
  /// In en, this message translates to:
  /// **'Sara replied to your review'**
  String get saraRepliedToYourReview;

  /// No description provided for @saraRepliedWithAVoiceNote.
  ///
  /// In en, this message translates to:
  /// **'Sara replied with a voice note'**
  String get saraRepliedWithAVoiceNote;

  /// No description provided for @saraSet45SecondsBetweenTheseSets.
  ///
  /// In en, this message translates to:
  /// **'Sara set 45 seconds between these sets.'**
  String get saraSet45SecondsBetweenTheseSets;

  /// No description provided for @saraShortenedItTo20Minutes.
  ///
  /// In en, this message translates to:
  /// **'Sara shortened it to 20 minutes'**
  String get saraShortenedItTo20Minutes;

  /// No description provided for @saraWouldSeeEnergyLowAppetiteUsual.
  ///
  /// In en, this message translates to:
  /// **'Sara would see: energy low, appetite usual, and “client selected a lighter session”.'**
  String get saraWouldSeeEnergyLowAppetiteUsual;

  /// No description provided for @sarasNoteAddTheSaladIfYou.
  ///
  /// In en, this message translates to:
  /// **'Sara’s note: “Add the salad if you are still hungry after.”'**
  String get sarasNoteAddTheSaladIfYou;

  /// No description provided for @save12Kg8.
  ///
  /// In en, this message translates to:
  /// **'Save · 12 kg × 8'**
  String get save12Kg8;

  /// No description provided for @saveAndSendToSara.
  ///
  /// In en, this message translates to:
  /// **'Save and send to Sara'**
  String get saveAndSendToSara;

  /// No description provided for @saveCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Save check-in'**
  String get saveCheckIn;

  /// No description provided for @saveFeedbackAndPublishChanges.
  ///
  /// In en, this message translates to:
  /// **'Save feedback and publish changes'**
  String get saveFeedbackAndPublishChanges;

  /// No description provided for @savePreferences.
  ///
  /// In en, this message translates to:
  /// **'Save preferences'**
  String get savePreferences;

  /// No description provided for @saveThisWorkout.
  ///
  /// In en, this message translates to:
  /// **'Save this workout?'**
  String get saveThisWorkout;

  /// No description provided for @saveToMyMealsAndAssign.
  ///
  /// In en, this message translates to:
  /// **'Save to my meals and assign'**
  String get saveToMyMealsAndAssign;

  /// No description provided for @saveToTuesday.
  ///
  /// In en, this message translates to:
  /// **'Save to Tuesday'**
  String get saveToTuesday;

  /// No description provided for @savedReplies.
  ///
  /// In en, this message translates to:
  /// **'Saved replies'**
  String get savedReplies;

  /// No description provided for @savedToYourOwnCollectionItIs.
  ///
  /// In en, this message translates to:
  /// **'Saved to your own collection. It is not added to the app’s public library.'**
  String get savedToYourOwnCollectionItIs;

  /// No description provided for @sayItAgain.
  ///
  /// In en, this message translates to:
  /// **'Say it again'**
  String get sayItAgain;

  /// No description provided for @saySomethingKind.
  ///
  /// In en, this message translates to:
  /// **'Say something kind'**
  String get saySomethingKind;

  /// No description provided for @scanMyId.
  ///
  /// In en, this message translates to:
  /// **'Scan my ID'**
  String get scanMyId;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @search124Moves.
  ///
  /// In en, this message translates to:
  /// **'Search 124 moves'**
  String get search124Moves;

  /// No description provided for @search124Workouts.
  ///
  /// In en, this message translates to:
  /// **'Search 124 workouts'**
  String get search124Workouts;

  /// No description provided for @secondQuietWeekHerRestWeekIs.
  ///
  /// In en, this message translates to:
  /// **'Second quiet week. Her rest week is already used.'**
  String get secondQuietWeekHerRestWeekIs;

  /// No description provided for @seeAGentlerOptionBasedOnYour.
  ///
  /// In en, this message translates to:
  /// **'See a gentler option based on your check-in'**
  String get seeAGentlerOptionBasedOnYour;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @seeAnExampleDay.
  ///
  /// In en, this message translates to:
  /// **'See an example day'**
  String get seeAnExampleDay;

  /// No description provided for @seeExactlyWhatSheWouldSee.
  ///
  /// In en, this message translates to:
  /// **'See exactly what she would see'**
  String get seeExactlyWhatSheWouldSee;

  /// No description provided for @seeHerPackages.
  ///
  /// In en, this message translates to:
  /// **'See her packages'**
  String get seeHerPackages;

  /// No description provided for @seeMyToday.
  ///
  /// In en, this message translates to:
  /// **'See my Today'**
  String get seeMyToday;

  /// No description provided for @seeTheGroceryList.
  ///
  /// In en, this message translates to:
  /// **'See the grocery list'**
  String get seeTheGroceryList;

  /// No description provided for @seeTheSteps.
  ///
  /// In en, this message translates to:
  /// **'See the steps'**
  String get seeTheSteps;

  /// No description provided for @seeTheWholeProgram.
  ///
  /// In en, this message translates to:
  /// **'See the whole program'**
  String get seeTheWholeProgram;

  /// No description provided for @selectAppMeal.
  ///
  /// In en, this message translates to:
  /// **'Select app meal'**
  String get selectAppMeal;

  /// No description provided for @selfieMatchedToTheCard.
  ///
  /// In en, this message translates to:
  /// **'Selfie matched to the card'**
  String get selfieMatchedToTheCard;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @sendItAgain.
  ///
  /// In en, this message translates to:
  /// **'Send it again'**
  String get sendItAgain;

  /// No description provided for @sendMeACode.
  ///
  /// In en, this message translates to:
  /// **'Send me a code'**
  String get sendMeACode;

  /// No description provided for @sendReplyAndPlanChange.
  ///
  /// In en, this message translates to:
  /// **'Send reply and plan change'**
  String get sendReplyAndPlanChange;

  /// No description provided for @sendThisWeekToMai.
  ///
  /// In en, this message translates to:
  /// **'Send this week to Mai'**
  String get sendThisWeekToMai;

  /// No description provided for @sendToMai.
  ///
  /// In en, this message translates to:
  /// **'Send to Mai'**
  String get sendToMai;

  /// No description provided for @september.
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get september;

  /// No description provided for @septemberSoFar.
  ///
  /// In en, this message translates to:
  /// **'September so far'**
  String get septemberSoFar;

  /// No description provided for @servings.
  ///
  /// In en, this message translates to:
  /// **'Servings'**
  String get servings;

  /// No description provided for @session20PersonalBest10.
  ///
  /// In en, this message translates to:
  /// **'Session 20 · personal best 10'**
  String get session20PersonalBest10;

  /// No description provided for @sessionDone.
  ///
  /// In en, this message translates to:
  /// **'Session done'**
  String get sessionDone;

  /// No description provided for @sessionName.
  ///
  /// In en, this message translates to:
  /// **'Session name'**
  String get sessionName;

  /// No description provided for @sessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessions;

  /// No description provided for @sessionsYouAddedWithIAlreadyDid.
  ///
  /// In en, this message translates to:
  /// **'Sessions you added with \"I already did it\" never set a best, because the numbers were copied.'**
  String get sessionsYouAddedWithIAlreadyDid;

  /// No description provided for @sessionsFoodDaysAndBests.
  ///
  /// In en, this message translates to:
  /// **'Sessions, food days and bests'**
  String get sessionsFoodDaysAndBests;

  /// No description provided for @set2GobletSquat.
  ///
  /// In en, this message translates to:
  /// **'Set 2 · Goblet squat'**
  String get set2GobletSquat;

  /// R09 undo snackbar. Must name the numbers SHE logged, not the prescription.
  ///
  /// In en, this message translates to:
  /// **'Set {setNumber} saved · {weight} kg × {reps}'**
  String setSetnumberSavedWeightKgReps(int setNumber, String weight, int reps);

  /// No description provided for @set2Saved12Kg12.
  ///
  /// In en, this message translates to:
  /// **'Set 2 saved · 12 kg × 12'**
  String get set2Saved12Kg12;

  /// No description provided for @set312Kg12.
  ///
  /// In en, this message translates to:
  /// **'Set 3 · 12 kg × 12'**
  String get set312Kg12;

  /// No description provided for @setsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Sets completed'**
  String get setsCompleted;

  /// No description provided for @severe.
  ///
  /// In en, this message translates to:
  /// **'Severe'**
  String get severe;

  /// No description provided for @severeCrampsNoted.
  ///
  /// In en, this message translates to:
  /// **'Severe cramps noted'**
  String get severeCrampsNoted;

  /// No description provided for @severeOrUnusualPainDeservesMedicalAdvice.
  ///
  /// In en, this message translates to:
  /// **'Severe or unusual pain deserves medical advice. If the pain is worse than usual and pain relief has not helped, seek urgent care.'**
  String get severeOrUnusualPainDeservesMedicalAdvice;

  /// No description provided for @shareCycleInformationWithSara.
  ///
  /// In en, this message translates to:
  /// **'Share cycle information with Sara'**
  String get shareCycleInformationWithSara;

  /// No description provided for @shareFormVideo.
  ///
  /// In en, this message translates to:
  /// **'Share form video'**
  String get shareFormVideo;

  /// No description provided for @shareTheSquatWithYourGroup.
  ///
  /// In en, this message translates to:
  /// **'Share the squat with your group'**
  String get shareTheSquatWithYourGroup;

  /// No description provided for @shareWithMyCoach.
  ///
  /// In en, this message translates to:
  /// **'Share with my coach'**
  String get shareWithMyCoach;

  /// No description provided for @shared.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get shared;

  /// No description provided for @sharedByNour.
  ///
  /// In en, this message translates to:
  /// **'Shared by Nour'**
  String get sharedByNour;

  /// No description provided for @sharedWellbeing.
  ///
  /// In en, this message translates to:
  /// **'Shared wellbeing'**
  String get sharedWellbeing;

  /// No description provided for @sharedWithSara.
  ///
  /// In en, this message translates to:
  /// **'Shared with Sara'**
  String get sharedWithSara;

  /// No description provided for @sheAverages78G.
  ///
  /// In en, this message translates to:
  /// **'She averages 78 g'**
  String get sheAverages78G;

  /// No description provided for @sheChoosesWhatShowsHereMealsWorkouts.
  ///
  /// In en, this message translates to:
  /// **'She chooses what shows here. Meals, workouts, weight and photos are never on a profile.'**
  String get sheChoosesWhatShowsHereMealsWorkouts;

  /// No description provided for @sheDisappearsFromYourFeedAndCannot.
  ///
  /// In en, this message translates to:
  /// **'She disappears from your feed and cannot message you'**
  String get sheDisappearsFromYourFeedAndCannot;

  /// No description provided for @sheHasYourIntakeMostPlansArrive.
  ///
  /// In en, this message translates to:
  /// **'She has your intake. Most plans arrive within a working day.'**
  String get sheHasYourIntakeMostPlansArrive;

  /// No description provided for @shortOnesThatStillCount.
  ///
  /// In en, this message translates to:
  /// **'Short ones that still count'**
  String get shortOnesThatStillCount;

  /// No description provided for @showMealSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Show meal suggestions'**
  String get showMealSuggestions;

  /// No description provided for @showMyPersonalBests.
  ///
  /// In en, this message translates to:
  /// **'Show my personal bests'**
  String get showMyPersonalBests;

  /// No description provided for @showUsYourCertificates.
  ///
  /// In en, this message translates to:
  /// **'Show us your certificates'**
  String get showUsYourCertificates;

  /// No description provided for @showWorkoutSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Show workout suggestions'**
  String get showWorkoutSuggestions;

  /// No description provided for @showingUp.
  ///
  /// In en, this message translates to:
  /// **'Showing up'**
  String get showingUp;

  /// No description provided for @skipSetup.
  ///
  /// In en, this message translates to:
  /// **'Skip setup'**
  String get skipSetup;

  /// No description provided for @skipThisExercise.
  ///
  /// In en, this message translates to:
  /// **'Skip this exercise'**
  String get skipThisExercise;

  /// No description provided for @skipThisMove.
  ///
  /// In en, this message translates to:
  /// **'Skip this move'**
  String get skipThisMove;

  /// No description provided for @skipTimer.
  ///
  /// In en, this message translates to:
  /// **'Skip timer'**
  String get skipTimer;

  /// No description provided for @skipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get skipped;

  /// No description provided for @slowlyWithoutCuttingFoodYouLove.
  ///
  /// In en, this message translates to:
  /// **'Slowly, without cutting food you love'**
  String get slowlyWithoutCuttingFoodYouLove;

  /// No description provided for @snack.
  ///
  /// In en, this message translates to:
  /// **'Snack'**
  String get snack;

  /// No description provided for @soWereAdding.
  ///
  /// In en, this message translates to:
  /// **'So we\'re adding'**
  String get soWereAdding;

  /// No description provided for @spots.
  ///
  /// In en, this message translates to:
  /// **'Spots'**
  String get spots;

  /// No description provided for @standUpStrongSqueezeAtTheTop.
  ///
  /// In en, this message translates to:
  /// **'Stand up strong, squeeze at the top'**
  String get standUpStrongSqueezeAtTheTop;

  /// No description provided for @start10Minutes.
  ///
  /// In en, this message translates to:
  /// **'Start 10 minutes'**
  String get start10Minutes;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get startDate;

  /// No description provided for @startDay1Now.
  ///
  /// In en, this message translates to:
  /// **'Start day 1 now'**
  String get startDay1Now;

  /// No description provided for @startDay2.
  ///
  /// In en, this message translates to:
  /// **'Start day 2'**
  String get startDay2;

  /// No description provided for @startFromATemplateChangeWhatMatters.
  ///
  /// In en, this message translates to:
  /// **'Start from a template, change what matters, send. Her app updates tonight and she sees it as today\'s session.'**
  String get startFromATemplateChangeWhatMatters;

  /// No description provided for @startThe10Minutes.
  ///
  /// In en, this message translates to:
  /// **'Start the 10 minutes'**
  String get startThe10Minutes;

  /// No description provided for @startTodaysSession.
  ///
  /// In en, this message translates to:
  /// **'Start today\'s session'**
  String get startTodaysSession;

  /// No description provided for @startWorkout.
  ///
  /// In en, this message translates to:
  /// **'Start workout'**
  String get startWorkout;

  /// No description provided for @startsTodayRenews16October.
  ///
  /// In en, this message translates to:
  /// **'Starts today · renews 16 October'**
  String get startsTodayRenews16October;

  /// No description provided for @step1Of2.
  ///
  /// In en, this message translates to:
  /// **'Step 1 of 2'**
  String get step1Of2;

  /// No description provided for @step1Of3SavedAsYou.
  ///
  /// In en, this message translates to:
  /// **'Step 1 of 3 · saved as you go'**
  String get step1Of3SavedAsYou;

  /// No description provided for @step1Of4.
  ///
  /// In en, this message translates to:
  /// **'Step 1 of 4'**
  String get step1Of4;

  /// No description provided for @step1Of6.
  ///
  /// In en, this message translates to:
  /// **'Step 1 of 6'**
  String get step1Of6;

  /// No description provided for @step2Of2.
  ///
  /// In en, this message translates to:
  /// **'Step 2 of 2'**
  String get step2Of2;

  /// No description provided for @step2Of4.
  ///
  /// In en, this message translates to:
  /// **'Step 2 of 4'**
  String get step2Of4;

  /// No description provided for @step2Of6.
  ///
  /// In en, this message translates to:
  /// **'Step 2 of 6'**
  String get step2Of6;

  /// No description provided for @step3Of3.
  ///
  /// In en, this message translates to:
  /// **'Step 3 of 3'**
  String get step3Of3;

  /// No description provided for @step3Of4.
  ///
  /// In en, this message translates to:
  /// **'Step 3 of 4'**
  String get step3Of4;

  /// No description provided for @step3Of6.
  ///
  /// In en, this message translates to:
  /// **'Step 3 of 6'**
  String get step3Of6;

  /// No description provided for @step4Of4.
  ///
  /// In en, this message translates to:
  /// **'Step 4 of 4'**
  String get step4Of4;

  /// No description provided for @step4Of6.
  ///
  /// In en, this message translates to:
  /// **'Step 4 of 6'**
  String get step4Of6;

  /// No description provided for @step5Of6.
  ///
  /// In en, this message translates to:
  /// **'Step 5 of 6'**
  String get step5Of6;

  /// No description provided for @step6Of6.
  ///
  /// In en, this message translates to:
  /// **'Step 6 of 6'**
  String get step6Of6;

  /// No description provided for @stepBackLunge310.
  ///
  /// In en, this message translates to:
  /// **'Step-back lunge · 3 × 10'**
  String get stepBackLunge310;

  /// No description provided for @stillAMemberJustQuiet.
  ///
  /// In en, this message translates to:
  /// **'Still a member, just quiet'**
  String get stillAMemberJustQuiet;

  /// No description provided for @stopIfMovementMakesYourSymptomsWorse.
  ///
  /// In en, this message translates to:
  /// **'Stop if movement makes your symptoms worse.'**
  String get stopIfMovementMakesYourSymptomsWorse;

  /// No description provided for @strength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get strength;

  /// No description provided for @subscription8SepTo7Oct.
  ///
  /// In en, this message translates to:
  /// **'Subscription · 8 Sep to 7 Oct'**
  String get subscription8SepTo7Oct;

  /// No description provided for @suggestedForYou.
  ///
  /// In en, this message translates to:
  /// **'Suggested for you'**
  String get suggestedForYou;

  /// No description provided for @sun13.
  ///
  /// In en, this message translates to:
  /// **'Sun 13'**
  String get sun13;

  /// No description provided for @sunToThu900To17.
  ///
  /// In en, this message translates to:
  /// **'Sun to Thu, 9:00 to 17:00 Cairo · replies within one working day. Not monitored at night.'**
  String get sunToThu900To17;

  /// No description provided for @sunTueThu20Min.
  ///
  /// In en, this message translates to:
  /// **'Sun, Tue, Thu · 20 min'**
  String get sunTueThu20Min;

  /// No description provided for @sunday20September.
  ///
  /// In en, this message translates to:
  /// **'Sunday 20 September'**
  String get sunday20September;

  /// No description provided for @sundayToThursday900To17.
  ///
  /// In en, this message translates to:
  /// **'Sunday to Thursday, 9:00 to 17:00 · replies within one working day'**
  String get sundayToThursday900To17;

  /// No description provided for @swap.
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get swap;

  /// No description provided for @swapExercise.
  ///
  /// In en, this message translates to:
  /// **'Swap exercise'**
  String get swapExercise;

  /// No description provided for @swapIt.
  ///
  /// In en, this message translates to:
  /// **'Swap it'**
  String get swapIt;

  /// No description provided for @swapThisExercise.
  ///
  /// In en, this message translates to:
  /// **'Swap this exercise'**
  String get swapThisExercise;

  /// No description provided for @symptomOnlyMode.
  ///
  /// In en, this message translates to:
  /// **'Symptom-only mode'**
  String get symptomOnlyMode;

  /// No description provided for @symptomOnlyModeNoDatesNoEstimates.
  ///
  /// In en, this message translates to:
  /// **'Symptom-only mode. No dates, no estimates.'**
  String get symptomOnlyModeNoDatesNoEstimates;

  /// No description provided for @taameyaSaladBaladi520Kcal.
  ///
  /// In en, this message translates to:
  /// **'Ta\'ameya, salad, baladi · 520 kcal'**
  String get taameyaSaladBaladi520Kcal;

  /// No description provided for @takeClientsSetYourPackagesKeep80.
  ///
  /// In en, this message translates to:
  /// **'Take clients, set your packages, keep 80%.'**
  String get takeClientsSetYourPackagesKeep80;

  /// No description provided for @takeItMyself.
  ///
  /// In en, this message translates to:
  /// **'Take it myself'**
  String get takeItMyself;

  /// No description provided for @talkToAHuman.
  ///
  /// In en, this message translates to:
  /// **'Talk to a human'**
  String get talkToAHuman;

  /// No description provided for @tapAnyMoveToWatchItOr.
  ///
  /// In en, this message translates to:
  /// **'Tap any move to watch it or swap it.'**
  String get tapAnyMoveToWatchItOr;

  /// No description provided for @tapOneAndItIsSavedUndo.
  ///
  /// In en, this message translates to:
  /// **'Tap one and it is saved. Undo for five seconds.'**
  String get tapOneAndItIsSavedUndo;

  /// No description provided for @tellClientsWhoYouAre.
  ///
  /// In en, this message translates to:
  /// **'Tell clients who you are'**
  String get tellClientsWhoYouAre;

  /// No description provided for @thatIsExactlyRightKeep12Kg.
  ///
  /// In en, this message translates to:
  /// **'That is exactly right. Keep 12 kg on Thursday and we add reps, not weight.'**
  String get thatIsExactlyRightKeep12Kg;

  /// No description provided for @thatsRightAdd696Kcal.
  ///
  /// In en, this message translates to:
  /// **'That\'s right · add 696 kcal'**
  String get thatsRightAdd696Kcal;

  /// No description provided for @thatsTuesdayDone.
  ///
  /// In en, this message translates to:
  /// **'That\'s Tuesday done'**
  String get thatsTuesdayDone;

  /// No description provided for @theCommunityStaysClosedUntilTheCheck.
  ///
  /// In en, this message translates to:
  /// **'The community stays closed until the check is done. That is the point of it.'**
  String get theCommunityStaysClosedUntilTheCheck;

  /// No description provided for @theLibraryIsOpenAsUsual.
  ///
  /// In en, this message translates to:
  /// **'The library is open as usual'**
  String get theLibraryIsOpenAsUsual;

  /// No description provided for @theShortestOneWeHave.
  ///
  /// In en, this message translates to:
  /// **'The shortest one we have'**
  String get theShortestOneWeHave;

  /// No description provided for @theSquatFeltHeavyAt12Kg_wg4mi.
  ///
  /// In en, this message translates to:
  /// **'The squat felt heavy at 12 kg but I finished all three sets.'**
  String get theSquatFeltHeavyAt12Kg_wg4mi;

  /// No description provided for @theThreeStepsPlainly.
  ///
  /// In en, this message translates to:
  /// **'The three steps, plainly'**
  String get theThreeStepsPlainly;

  /// No description provided for @thenThisWeekIsTwoSessionsTen.
  ///
  /// In en, this message translates to:
  /// **'Then this week is two sessions, ten minutes each. I moved them to Sunday and Wednesday.'**
  String get thenThisWeekIsTwoSessionsTen;

  /// No description provided for @thisDescribesWhatYouNotedItDoes.
  ///
  /// In en, this message translates to:
  /// **'This describes what you noted. It does not explain the cause or predict every cycle.'**
  String get thisDescribesWhatYouNotedItDoes;

  /// No description provided for @thisIsExactlyWhatAClientSees.
  ///
  /// In en, this message translates to:
  /// **'This is exactly what a client sees. Tap the eye to open it as she would.'**
  String get thisIsExactlyWhatAClientSees;

  /// No description provided for @thisIsTheExactThingINeeded.
  ///
  /// In en, this message translates to:
  /// **'This is the exact thing I needed to read today.'**
  String get thisIsTheExactThingINeeded;

  /// No description provided for @thisIsTheTopOfYourPublic.
  ///
  /// In en, this message translates to:
  /// **'This is the top of your public profile.'**
  String get thisIsTheTopOfYourPublic;

  /// No description provided for @thisIsTheWholeReasonTheCommunity.
  ///
  /// In en, this message translates to:
  /// **'This is the whole reason the community feels safe: every member is verified before she can see or say anything.'**
  String get thisIsTheWholeReasonTheCommunity;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get thisMonth;

  /// No description provided for @thisMove.
  ///
  /// In en, this message translates to:
  /// **'This move'**
  String get thisMove;

  /// No description provided for @thisNeedsMoreThanAWorkoutChange.
  ///
  /// In en, this message translates to:
  /// **'This needs more than a workout change'**
  String get thisNeedsMoreThanAWorkoutChange;

  /// No description provided for @thisWeekFromSara.
  ///
  /// In en, this message translates to:
  /// **'This week from Sara'**
  String get thisWeekFromSara;

  /// No description provided for @thisWeek0Of3.
  ///
  /// In en, this message translates to:
  /// **'This week, 0 of 3'**
  String get thisWeek0Of3;

  /// No description provided for @thisWeek1Of3.
  ///
  /// In en, this message translates to:
  /// **'This week, 1 of 3'**
  String get thisWeek1Of3;

  /// No description provided for @thisWeeksPlanAndList.
  ///
  /// In en, this message translates to:
  /// **'This week\'s plan and list'**
  String get thisWeeksPlanAndList;

  /// No description provided for @threeDaysAWeek15MinutesAt.
  ///
  /// In en, this message translates to:
  /// **'Three days a week, 15 minutes, at home'**
  String get threeDaysAWeek15MinutesAt;

  /// No description provided for @threeRulesTheyAreTheWholeReason.
  ///
  /// In en, this message translates to:
  /// **'Three rules. They are the whole reason this place works.'**
  String get threeRulesTheyAreTheWholeReason;

  /// No description provided for @thu18.
  ///
  /// In en, this message translates to:
  /// **'Thu 18'**
  String get thu18;

  /// No description provided for @thursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get thursday;

  /// No description provided for @thursdayFullBodyStrength.
  ///
  /// In en, this message translates to:
  /// **'Thursday · full-body strength'**
  String get thursdayFullBodyStrength;

  /// No description provided for @thursday18SeptemberOnwardsPublishedBySara.
  ///
  /// In en, this message translates to:
  /// **'Thursday 18 September onwards · published by Sara'**
  String get thursday18SeptemberOnwardsPublishedBySara;

  /// No description provided for @thursdayDropsTo20Minutes.
  ///
  /// In en, this message translates to:
  /// **'Thursday drops to 20 minutes'**
  String get thursdayDropsTo20Minutes;

  /// No description provided for @timePerSession.
  ///
  /// In en, this message translates to:
  /// **'Time per session'**
  String get timePerSession;

  /// No description provided for @today_554hp.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get today_554hp;

  /// No description provided for @todaysMeals.
  ///
  /// In en, this message translates to:
  /// **'Today\'s meals'**
  String get todaysMeals;

  /// No description provided for @todaysWorkout.
  ///
  /// In en, this message translates to:
  /// **'Today\'s workout'**
  String get todaysWorkout;

  /// No description provided for @togetherSoFar.
  ///
  /// In en, this message translates to:
  /// **'together so far'**
  String get togetherSoFar;

  /// No description provided for @tomatoSauce.
  ///
  /// In en, this message translates to:
  /// **'Tomato sauce'**
  String get tomatoSauce;

  /// No description provided for @tomatoes1Kg.
  ///
  /// In en, this message translates to:
  /// **'Tomatoes 1 kg'**
  String get tomatoes1Kg;

  /// No description provided for @trackPeriodsAndSymptoms.
  ///
  /// In en, this message translates to:
  /// **'Track periods and symptoms'**
  String get trackPeriodsAndSymptoms;

  /// No description provided for @trackSymptomsOnly.
  ///
  /// In en, this message translates to:
  /// **'Track symptoms only'**
  String get trackSymptomsOnly;

  /// No description provided for @trainOnYourOwnMeanwhile.
  ///
  /// In en, this message translates to:
  /// **'Train on your own meanwhile'**
  String get trainOnYourOwnMeanwhile;

  /// No description provided for @trains.
  ///
  /// In en, this message translates to:
  /// **'Trains'**
  String get trains;

  /// No description provided for @tue16.
  ///
  /// In en, this message translates to:
  /// **'Tue 16'**
  String get tue16;

  /// No description provided for @tue16Session.
  ///
  /// In en, this message translates to:
  /// **'Tue 16 · session'**
  String get tue16Session;

  /// No description provided for @tuesday840AddedFromTheLock.
  ///
  /// In en, this message translates to:
  /// **'Tuesday 8:40 · added from the lock screen'**
  String get tuesday840AddedFromTheLock;

  /// No description provided for @tuesdays.
  ///
  /// In en, this message translates to:
  /// **'Tuesdays'**
  String get tuesdays;

  /// No description provided for @twelveInAllNoneAreSecretAnd.
  ///
  /// In en, this message translates to:
  /// **'Twelve in all. None are secret, and none are for filling in a profile.'**
  String get twelveInAllNoneAreSecretAnd;

  /// No description provided for @twoBoiledEggs.
  ///
  /// In en, this message translates to:
  /// **'Two boiled eggs'**
  String get twoBoiledEggs;

  /// No description provided for @twoDaysWithNoMealAddedAre.
  ///
  /// In en, this message translates to:
  /// **'Two days with no meal added are shown as nothing added, not as meals skipped.'**
  String get twoDaysWithNoMealAddedAre;

  /// No description provided for @twoMinutesWithAWomanReviewerNothing.
  ///
  /// In en, this message translates to:
  /// **'Two minutes with a woman reviewer. Nothing is recorded or kept.'**
  String get twoMinutesWithAWomanReviewerNothing;

  /// No description provided for @twoMoreAndTheWeekCounts.
  ///
  /// In en, this message translates to:
  /// **'Two more and the week counts.'**
  String get twoMoreAndTheWeekCounts;

  /// No description provided for @typeADifferentNumber.
  ///
  /// In en, this message translates to:
  /// **'Type a different number'**
  String get typeADifferentNumber;

  /// No description provided for @typeTheCode.
  ///
  /// In en, this message translates to:
  /// **'Type the code'**
  String get typeTheCode;

  /// No description provided for @under2000Egp.
  ///
  /// In en, this message translates to:
  /// **'Under 2,000 EGP'**
  String get under2000Egp;

  /// No description provided for @under20Min.
  ///
  /// In en, this message translates to:
  /// **'Under 20 min'**
  String get under20Min;

  /// No description provided for @unread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get unread;

  /// No description provided for @uploadedChecking.
  ///
  /// In en, this message translates to:
  /// **'Uploaded · checking'**
  String get uploadedChecking;

  /// No description provided for @upperBody20Min.
  ///
  /// In en, this message translates to:
  /// **'Upper body · 20 min'**
  String get upperBody20Min;

  /// No description provided for @upperBodyAtHome.
  ///
  /// In en, this message translates to:
  /// **'Upper body at home'**
  String get upperBodyAtHome;

  /// No description provided for @upperBodyLikeLastThursday.
  ///
  /// In en, this message translates to:
  /// **'Upper body, like last Thursday'**
  String get upperBodyLikeLastThursday;

  /// No description provided for @useThisOption.
  ///
  /// In en, this message translates to:
  /// **'Use this option'**
  String get useThisOption;

  /// No description provided for @usual.
  ///
  /// In en, this message translates to:
  /// **'Usual'**
  String get usual;

  /// No description provided for @usualCycleLength.
  ///
  /// In en, this message translates to:
  /// **'Usual cycle length'**
  String get usualCycleLength;

  /// No description provided for @usuallySecondsIfItNeedsAPerson.
  ///
  /// In en, this message translates to:
  /// **'Usually seconds. If it needs a person, a woman reviewer takes it from here.'**
  String get usuallySecondsIfItNeedsAPerson;

  /// No description provided for @usuallyTheSameDayWeWillText.
  ///
  /// In en, this message translates to:
  /// **'Usually the same day. We will text you the moment your profile is live.'**
  String get usuallyTheSameDayWeWillText;

  /// No description provided for @usuallyUnderTwoHoursWeWillText.
  ///
  /// In en, this message translates to:
  /// **'Usually under two hours. We will text you.'**
  String get usuallyUnderTwoHoursWeWillText;

  /// No description provided for @vegetables.
  ///
  /// In en, this message translates to:
  /// **'Vegetables'**
  String get vegetables;

  /// C13. Her actual verification time, not the mockup 74.
  ///
  /// In en, this message translates to:
  /// **'Verified in {seconds} seconds. Your ID photo and selfie have been deleted. We kept the result and nothing else.'**
  String verifiedInSecondsSecondsYourIdPhoto(int seconds);

  /// No description provided for @verifiedWomanJoined3DaysAgo.
  ///
  /// In en, this message translates to:
  /// **'Verified woman · joined 3 days ago'**
  String get verifiedWomanJoined3DaysAgo;

  /// No description provided for @verifiedWomanJoinedMarch.
  ///
  /// In en, this message translates to:
  /// **'Verified woman · joined March'**
  String get verifiedWomanJoinedMarch;

  /// No description provided for @verifiedWomanRegularLevel7.
  ///
  /// In en, this message translates to:
  /// **'Verified woman · Regular · level 7'**
  String get verifiedWomanRegularLevel7;

  /// No description provided for @verifiedWomenCoachesPaidMonthlyInEgyptian.
  ///
  /// In en, this message translates to:
  /// **'Verified women coaches, paid monthly in Egyptian pounds.'**
  String get verifiedWomenCoachesPaidMonthlyInEgyptian;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @viewOption.
  ///
  /// In en, this message translates to:
  /// **'View option'**
  String get viewOption;

  /// No description provided for @viewRecipe.
  ///
  /// In en, this message translates to:
  /// **'View recipe'**
  String get viewRecipe;

  /// No description provided for @visaMastercardMeeza.
  ///
  /// In en, this message translates to:
  /// **'Visa, Mastercard, Meeza'**
  String get visaMastercardMeeza;

  /// No description provided for @vodafoneCash010XxxXx32.
  ///
  /// In en, this message translates to:
  /// **'Vodafone Cash · 010 xxx xx32'**
  String get vodafoneCash010XxxXx32;

  /// No description provided for @vodafoneCashChangeAnyTime.
  ///
  /// In en, this message translates to:
  /// **'Vodafone Cash · change any time'**
  String get vodafoneCashChangeAnyTime;

  /// No description provided for @vodafoneCashOrangeMoneyEtisalatInstapay.
  ///
  /// In en, this message translates to:
  /// **'Vodafone Cash, Orange Money, Etisalat, InstaPay'**
  String get vodafoneCashOrangeMoneyEtisalatInstapay;

  /// No description provided for @voiceNote.
  ///
  /// In en, this message translates to:
  /// **'Voice note'**
  String get voiceNote;

  /// No description provided for @voiceNote042.
  ///
  /// In en, this message translates to:
  /// **'Voice note · 0:42'**
  String get voiceNote042;

  /// No description provided for @w.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get w;

  /// No description provided for @waist82Cm.
  ///
  /// In en, this message translates to:
  /// **'Waist 82 cm'**
  String get waist82Cm;

  /// No description provided for @waistHipsArmEvery4WeeksIs.
  ///
  /// In en, this message translates to:
  /// **'Waist, hips, arm. Every 4 weeks is plenty.'**
  String get waistHipsArmEvery4WeeksIs;

  /// No description provided for @waiting19HoursCanWeMakeThursday.
  ///
  /// In en, this message translates to:
  /// **'Waiting 19 hours · “Can we make Thursday shorter?”'**
  String get waiting19HoursCanWeMakeThursday;

  /// No description provided for @waiting19HoursICouldNotTrain.
  ///
  /// In en, this message translates to:
  /// **'Waiting 19 hours · \"I could not train this week\"'**
  String get waiting19HoursICouldNotTrain;

  /// No description provided for @waiting6HoursVoiceNote042.
  ///
  /// In en, this message translates to:
  /// **'Waiting 6 hours · voice note 0:42'**
  String get waiting6HoursVoiceNote042;

  /// No description provided for @waitingThereThePostpartumRebuildProgramAnd.
  ///
  /// In en, this message translates to:
  /// **'Waiting there: the postpartum rebuild program and your Strong label.'**
  String get waitingThereThePostpartumRebuildProgramAnd;

  /// No description provided for @walkThisMorning.
  ///
  /// In en, this message translates to:
  /// **'Walk this morning'**
  String get walkThisMorning;

  /// No description provided for @wallSit.
  ///
  /// In en, this message translates to:
  /// **'Wall sit'**
  String get wallSit;

  /// No description provided for @weAreNotSuggestingAWorkoutToday.
  ///
  /// In en, this message translates to:
  /// **'We are not suggesting a workout today. Your plan is still there when you want it.'**
  String get weAreNotSuggestingAWorkoutToday;

  /// No description provided for @weAvoidWhatHurtsWeDoNot.
  ///
  /// In en, this message translates to:
  /// **'We avoid what hurts, we do not diagnose'**
  String get weAvoidWhatHurtsWeDoNot;

  /// No description provided for @weHeardThis.
  ///
  /// In en, this message translates to:
  /// **'We heard this'**
  String get weHeardThis;

  /// No description provided for @weJustNeedYourNumberAndA.
  ///
  /// In en, this message translates to:
  /// **'We just need your number and a quick check that you are a woman. It takes about two minutes, once.'**
  String get weJustNeedYourNumberAndA;

  /// No description provided for @weKeepTheCommunityForVerifiedWomen.
  ///
  /// In en, this message translates to:
  /// **'We keep the community for verified women. Join and you will see all of it.'**
  String get weKeepTheCommunityForVerifiedWomen;

  /// No description provided for @weNeverShowYourWalletNumberOr.
  ///
  /// In en, this message translates to:
  /// **'We never show your wallet number or your address to clients.'**
  String get weNeverShowYourWalletNumberOr;

  /// No description provided for @weReadYourNationalIdCardThe.
  ///
  /// In en, this message translates to:
  /// **'We read your national ID card. The card itself says you are a woman. We never guess from your face.'**
  String get weReadYourNationalIdCardThe;

  /// C07. Her number, so a mistyped one is obvious before she waits.
  ///
  /// In en, this message translates to:
  /// **'We sent six digits to {phone}.'**
  String weSentSixDigitsToPhone(String phone);

  /// No description provided for @weTextYouASixDigitCode.
  ///
  /// In en, this message translates to:
  /// **'We text you a six-digit code. We never show your number to anyone.'**
  String get weTextYouASixDigitCode;

  /// No description provided for @wellAdd.
  ///
  /// In en, this message translates to:
  /// **'We\'ll add'**
  String get wellAdd;

  /// No description provided for @wereCheckingYourCertificates.
  ///
  /// In en, this message translates to:
  /// **'We\'re checking your certificates'**
  String get wereCheckingYourCertificates;

  /// No description provided for @wed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get wed;

  /// No description provided for @wed17.
  ///
  /// In en, this message translates to:
  /// **'Wed 17'**
  String get wed17;

  /// No description provided for @wednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get wednesday;

  /// No description provided for @week.
  ///
  /// In en, this message translates to:
  /// **'week'**
  String get week;

  /// No description provided for @week1.
  ///
  /// In en, this message translates to:
  /// **'Week 1'**
  String get week1;

  /// No description provided for @week1StartsWithFourMovesOn.
  ///
  /// In en, this message translates to:
  /// **'Week 1 starts with four moves on the floor. Nothing jumps, nothing needs a neighbour to be out.'**
  String get week1StartsWithFourMovesOn;

  /// No description provided for @week3Of8.
  ///
  /// In en, this message translates to:
  /// **'Week 3 of 8'**
  String get week3Of8;

  /// No description provided for @weekFiveAddsTheStandingMovesMessage.
  ///
  /// In en, this message translates to:
  /// **'Week five adds the standing moves. Message me if your back complains.'**
  String get weekFiveAddsTheStandingMovesMessage;

  /// No description provided for @weightLoss.
  ///
  /// In en, this message translates to:
  /// **'Weight loss'**
  String get weightLoss;

  /// No description provided for @welcomeMaiILookedAtYourAnswers.
  ///
  /// In en, this message translates to:
  /// **'Welcome Mai! I looked at your answers, so we start on the floor this week, nothing standing.'**
  String get welcomeMaiILookedAtYourAnswers;

  /// No description provided for @whatDoYouCoach.
  ///
  /// In en, this message translates to:
  /// **'What do you coach?'**
  String get whatDoYouCoach;

  /// No description provided for @whatDoYouHaveAtHome.
  ///
  /// In en, this message translates to:
  /// **'What do you have at home?'**
  String get whatDoYouHaveAtHome;

  /// No description provided for @whatDoYouWantMost.
  ///
  /// In en, this message translates to:
  /// **'What do you want most?'**
  String get whatDoYouWantMost;

  /// No description provided for @whatHappensWhenIReport.
  ///
  /// In en, this message translates to:
  /// **'What happens when I report?'**
  String get whatHappensWhenIReport;

  /// No description provided for @whatHappensWhenItEnds.
  ///
  /// In en, this message translates to:
  /// **'What happens when it ends'**
  String get whatHappensWhenItEnds;

  /// No description provided for @whatNourWillGet.
  ///
  /// In en, this message translates to:
  /// **'What Nour will get'**
  String get whatNourWillGet;

  /// No description provided for @whatSheIsAskingFor.
  ///
  /// In en, this message translates to:
  /// **'What she is asking for'**
  String get whatSheIsAskingFor;

  /// No description provided for @whatTodayLooksLikeOnceShePublishes.
  ///
  /// In en, this message translates to:
  /// **'What today looks like once she publishes'**
  String get whatTodayLooksLikeOnceShePublishes;

  /// No description provided for @whatWeAgreed.
  ///
  /// In en, this message translates to:
  /// **'What we agreed'**
  String get whatWeAgreed;

  /// No description provided for @whatWillChange.
  ///
  /// In en, this message translates to:
  /// **'What will change'**
  String get whatWillChange;

  /// No description provided for @whatWorkedWellOptional.
  ///
  /// In en, this message translates to:
  /// **'What worked well? Optional'**
  String get whatWorkedWellOptional;

  /// No description provided for @whatWouldYouLikeToChange.
  ///
  /// In en, this message translates to:
  /// **'What would you like to change?'**
  String get whatWouldYouLikeToChange;

  /// No description provided for @whatWouldYouLikeToDo.
  ///
  /// In en, this message translates to:
  /// **'What would you like to do?'**
  String get whatWouldYouLikeToDo;

  /// No description provided for @whatYouCharge.
  ///
  /// In en, this message translates to:
  /// **'What you charge'**
  String get whatYouCharge;

  /// No description provided for @whatYouAdded.
  ///
  /// In en, this message translates to:
  /// **'What you added'**
  String get whatYouAdded;

  /// No description provided for @whatsInside.
  ///
  /// In en, this message translates to:
  /// **'What\'s inside'**
  String get whatsInside;

  /// No description provided for @whatsYourNumber.
  ///
  /// In en, this message translates to:
  /// **'What\'s your number?'**
  String get whatsYourNumber;

  /// No description provided for @where.
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get where;

  /// No description provided for @whereAndWithWhat.
  ///
  /// In en, this message translates to:
  /// **'Where and with what'**
  String get whereAndWithWhat;

  /// No description provided for @whereShouldWeSendYourMoney.
  ///
  /// In en, this message translates to:
  /// **'Where should we send your money?'**
  String get whereShouldWeSendYourMoney;

  /// No description provided for @whereWillYouTrain.
  ///
  /// In en, this message translates to:
  /// **'Where will you train?'**
  String get whereWillYouTrain;

  /// No description provided for @whereYourClientsTrain.
  ///
  /// In en, this message translates to:
  /// **'Where your clients train'**
  String get whereYourClientsTrain;

  /// No description provided for @whichOneAreYou.
  ///
  /// In en, this message translates to:
  /// **'Which one are you?'**
  String get whichOneAreYou;

  /// No description provided for @whileYouWaitEverythingHereIsOpen.
  ///
  /// In en, this message translates to:
  /// **'While you wait, everything here is open'**
  String get whileYouWaitEverythingHereIsOpen;

  /// No description provided for @whoSeesYourProfileAndWins.
  ///
  /// In en, this message translates to:
  /// **'Who sees your profile and wins'**
  String get whoSeesYourProfileAndWins;

  /// No description provided for @withPortionsAndCostPerServing.
  ///
  /// In en, this message translates to:
  /// **'With portions and cost per serving'**
  String get withPortionsAndCostPerServing;

  /// No description provided for @womenOnlyEveryMemberChecked.
  ///
  /// In en, this message translates to:
  /// **'Women only, every member checked'**
  String get womenOnlyEveryMemberChecked;

  /// No description provided for @workWithSaraAgain.
  ///
  /// In en, this message translates to:
  /// **'Work with Sara again'**
  String get workWithSaraAgain;

  /// No description provided for @workoutSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Workout suggestions'**
  String get workoutSuggestions;

  /// No description provided for @workoutTime.
  ///
  /// In en, this message translates to:
  /// **'Workout time'**
  String get workoutTime;

  /// No description provided for @workoutsAndMealsDraftForWeek3.
  ///
  /// In en, this message translates to:
  /// **'Workouts and meals · draft for week 3'**
  String get workoutsAndMealsDraftForWeek3;

  /// No description provided for @workoutsAndVideos.
  ///
  /// In en, this message translates to:
  /// **'Workouts and videos'**
  String get workoutsAndVideos;

  /// No description provided for @workoutsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Workouts completed'**
  String get workoutsCompleted;

  /// No description provided for @workoutsRecipesAndTheCommunityFree.
  ///
  /// In en, this message translates to:
  /// **'Workouts, recipes and the community. Free.'**
  String get workoutsRecipesAndTheCommunityFree;

  /// No description provided for @worksWithOrWithoutACoach.
  ///
  /// In en, this message translates to:
  /// **'Works with or without a coach'**
  String get worksWithOrWithoutACoach;

  /// No description provided for @y.
  ///
  /// In en, this message translates to:
  /// **'Y'**
  String get y;

  /// No description provided for @yasminAdel.
  ///
  /// In en, this message translates to:
  /// **'Yasmin Adel'**
  String get yasminAdel;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @yesterday5DaysLeft.
  ///
  /// In en, this message translates to:
  /// **'Yesterday · 5 days left'**
  String get yesterday5DaysLeft;

  /// No description provided for @whatYouAddedYesterdayAndAnySession.
  ///
  /// In en, this message translates to:
  /// **'What you added yesterday and any session you already started stay as they were.'**
  String get whatYouAddedYesterdayAndAnySession;

  /// No description provided for @yesterdaysLunchAgain.
  ///
  /// In en, this message translates to:
  /// **'Yesterday\'s lunch again'**
  String get yesterdaysLunchAgain;

  /// No description provided for @yoghurtDatesAndNuts.
  ///
  /// In en, this message translates to:
  /// **'Yoghurt, dates and nuts'**
  String get yoghurtDatesAndNuts;

  /// No description provided for @yogurtDatesAndCinnamon.
  ///
  /// In en, this message translates to:
  /// **'Yogurt, dates and cinnamon'**
  String get yogurtDatesAndCinnamon;

  /// No description provided for @yogurtOatsAndFruit.
  ///
  /// In en, this message translates to:
  /// **'Yogurt, oats and fruit'**
  String get yogurtOatsAndFruit;

  /// No description provided for @youArePayingAPersonNotA.
  ///
  /// In en, this message translates to:
  /// **'You are paying a person, not a subscription: she keeps 80% of it.'**
  String get youArePayingAPersonNotA;

  /// No description provided for @youAreShowingUpForNow.
  ///
  /// In en, this message translates to:
  /// **'You are Showing up for now'**
  String get youAreShowingUpForNow;

  /// No description provided for @youCanChangeItOnAnyDay.
  ///
  /// In en, this message translates to:
  /// **'You can change it on any day.'**
  String get youCanChangeItOnAnyDay;

  /// No description provided for @youCanChangeThisAnyTimeIn.
  ///
  /// In en, this message translates to:
  /// **'You can change this any time in settings.'**
  String get youCanChangeThisAnyTimeIn;

  /// No description provided for @youCanChangeThisLaterByMessaging.
  ///
  /// In en, this message translates to:
  /// **'You can change this later by messaging us.'**
  String get youCanChangeThisLaterByMessaging;

  /// No description provided for @youCanStartNow.
  ///
  /// In en, this message translates to:
  /// **'You can start now'**
  String get youCanStartNow;

  /// No description provided for @youChooseWhatToAddYouCan.
  ///
  /// In en, this message translates to:
  /// **'You choose what to add. You can change or delete it any time.'**
  String get youChooseWhatToAddYouCan;

  /// No description provided for @youKeep.
  ///
  /// In en, this message translates to:
  /// **'You keep'**
  String get youKeep;

  /// No description provided for @youKeep80OfEverythingAClient.
  ///
  /// In en, this message translates to:
  /// **'You keep 80% of everything a client pays.'**
  String get youKeep80OfEverythingAClient;

  /// No description provided for @youNotedLowEnergyOn4Of.
  ///
  /// In en, this message translates to:
  /// **'You noted low energy on 4 of 6 noted days in the first 3 days of your last 2 periods.'**
  String get youNotedLowEnergyOn4Of;

  /// No description provided for @youNotedMoreHungerAddASnack.
  ///
  /// In en, this message translates to:
  /// **'You noted more hunger. Add a snack if you want one.'**
  String get youNotedMoreHungerAddASnack;

  /// No description provided for @youSentWeek4.
  ///
  /// In en, this message translates to:
  /// **'You: sent week 4'**
  String get youSentWeek4;

  /// C13. The first sentence the product says to her personally.
  ///
  /// In en, this message translates to:
  /// **'You\'re in, {name}'**
  String youreInName(String name);

  /// No description provided for @your14CountedWeeks.
  ///
  /// In en, this message translates to:
  /// **'Your 14 counted weeks'**
  String get your14CountedWeeks;

  /// No description provided for @your14WeeksAreSafe.
  ///
  /// In en, this message translates to:
  /// **'Your 14 weeks are safe'**
  String get your14WeeksAreSafe;

  /// No description provided for @your30Days.
  ///
  /// In en, this message translates to:
  /// **'Your 30 days'**
  String get your30Days;

  /// No description provided for @your30DaysWithSaraHaveEnded.
  ///
  /// In en, this message translates to:
  /// **'Your 30 days with Sara have ended'**
  String get your30DaysWithSaraHaveEnded;

  /// No description provided for @your30DayPlan.
  ///
  /// In en, this message translates to:
  /// **'Your 30-day plan'**
  String get your30DayPlan;

  /// No description provided for @your80Of27000Egp12.
  ///
  /// In en, this message translates to:
  /// **'Your 80% of 27,000 EGP · 12 clients'**
  String get your80Of27000Egp12;

  /// No description provided for @yourActualNumbersGoToSaraPrescribed.
  ///
  /// In en, this message translates to:
  /// **'Your actual numbers go to Sara. Prescribed values are never counted as completed work.'**
  String get yourActualNumbersGoToSaraPrescribed;

  /// No description provided for @yourCheckInGuidesToday.
  ///
  /// In en, this message translates to:
  /// **'Your check-in guides today'**
  String get yourCheckInGuidesToday;

  /// No description provided for @yourCoachIsPaidAfterYourFirst.
  ///
  /// In en, this message translates to:
  /// **'Your coach is paid after your first check-in. If she never replies, you get your money back.'**
  String get yourCoachIsPaidAfterYourFirst;

  /// No description provided for @yourCoachSinceTodayRepliesIn2h.
  ///
  /// In en, this message translates to:
  /// **'Your coach since today · replies in ~2h'**
  String get yourCoachSinceTodayRepliesIn2h;

  /// No description provided for @yourConversation.
  ///
  /// In en, this message translates to:
  /// **'Your conversation'**
  String get yourConversation;

  /// No description provided for @yourData.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get yourData;

  /// No description provided for @yourDatesIfYouHaveThem.
  ///
  /// In en, this message translates to:
  /// **'Your dates, if you have them'**
  String get yourDatesIfYouHaveThem;

  /// No description provided for @yourIdAndSelfieWereDeletedAfter.
  ///
  /// In en, this message translates to:
  /// **'Your ID and selfie were deleted after the check. Only the result is kept.'**
  String get yourIdAndSelfieWereDeletedAfter;

  /// No description provided for @yourIdCard.
  ///
  /// In en, this message translates to:
  /// **'Your ID card'**
  String get yourIdCard;

  /// No description provided for @yourMealsWorkoutsWeightPhotosAndPhone.
  ///
  /// In en, this message translates to:
  /// **'Your meals, workouts, weight, photos and phone number are never visible to another member. These settings are only about what you choose to show.'**
  String get yourMealsWorkoutsWeightPhotosAndPhone;

  /// No description provided for @yourMealsReviewedOnceAWeek.
  ///
  /// In en, this message translates to:
  /// **'Your meals reviewed once a week'**
  String get yourMealsReviewedOnceAWeek;

  /// No description provided for @yourNumberYourIdYourMealsAnd.
  ///
  /// In en, this message translates to:
  /// **'Your number, your ID, your meals and your workouts are never shown to members.'**
  String get yourNumberYourIdYourMealsAnd;

  /// No description provided for @yourOwnWorkoutsRecipesMealsAndMy.
  ///
  /// In en, this message translates to:
  /// **'Your own workouts, recipes, meals and My cycle carry on exactly as before. Cycle sharing switched itself off when the coaching ended.'**
  String get yourOwnWorkoutsRecipesMealsAndMy;

  /// No description provided for @yourPart.
  ///
  /// In en, this message translates to:
  /// **'Your part'**
  String get yourPart;

  /// No description provided for @yourPatterns.
  ///
  /// In en, this message translates to:
  /// **'Your patterns'**
  String get yourPatterns;

  /// No description provided for @yourPhoto.
  ///
  /// In en, this message translates to:
  /// **'Your photo'**
  String get yourPhoto;

  /// No description provided for @yourPlannedWorkout.
  ///
  /// In en, this message translates to:
  /// **'Your planned workout'**
  String get yourPlannedWorkout;

  /// No description provided for @yourPlate600Kcal.
  ///
  /// In en, this message translates to:
  /// **'Your plate · 600 kcal'**
  String get yourPlate600Kcal;

  /// No description provided for @yourPortion.
  ///
  /// In en, this message translates to:
  /// **'Your portion'**
  String get yourPortion;

  /// No description provided for @yourProgramContinuesTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Your program continues tomorrow'**
  String get yourProgramContinuesTomorrow;

  /// No description provided for @yourProgress.
  ///
  /// In en, this message translates to:
  /// **'Your progress'**
  String get yourProgress;

  /// No description provided for @yourPublicProfile.
  ///
  /// In en, this message translates to:
  /// **'Your public profile'**
  String get yourPublicProfile;

  /// No description provided for @yourReviews.
  ///
  /// In en, this message translates to:
  /// **'Your reviews'**
  String get yourReviews;

  /// No description provided for @yourSessionsCountHereAsYouSave.
  ///
  /// In en, this message translates to:
  /// **'Your sessions count here as you save them. There is nothing extra to do. Nobody sees your weights, only that a session happened.'**
  String get yourSessionsCountHereAsYouSave;

  /// No description provided for @yourSupport.
  ///
  /// In en, this message translates to:
  /// **'Your support'**
  String get yourSupport;

  /// No description provided for @yourThursdayWorkoutWasUpdated.
  ///
  /// In en, this message translates to:
  /// **'Your Thursday workout was updated'**
  String get yourThursdayWorkoutWasUpdated;

  /// No description provided for @yourTraining.
  ///
  /// In en, this message translates to:
  /// **'Your training'**
  String get yourTraining;

  /// No description provided for @yourWeekFromWhatYouAdded.
  ///
  /// In en, this message translates to:
  /// **'Your week, from what you added'**
  String get yourWeekFromWhatYouAdded;

  /// No description provided for @yourWeekMondayTuesdayAndThursdayChange.
  ///
  /// In en, this message translates to:
  /// **'Your week: Monday, Tuesday and Thursday. Change any day by tapping it.'**
  String get yourWeekMondayTuesdayAndThursdayChange;

  /// No description provided for @yourWorkoutResultsAndTheMealsYou.
  ///
  /// In en, this message translates to:
  /// **'Your workout results and the meals you add are part of coaching. Cycle information is separate, and yours.'**
  String get yourWorkoutResultsAndTheMealsYou;

  /// No description provided for @yours.
  ///
  /// In en, this message translates to:
  /// **'Yours'**
  String get yours;

  /// No description provided for @youreIn.
  ///
  /// In en, this message translates to:
  /// **'You\'re in'**
  String get youreIn;

  /// No description provided for @clientResults.
  ///
  /// In en, this message translates to:
  /// **'Client results'**
  String get clientResults;

  /// No description provided for @howIWork.
  ///
  /// In en, this message translates to:
  /// **'How I work'**
  String get howIWork;

  /// No description provided for @follow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get follow;

  /// No description provided for @whatIOffer.
  ///
  /// In en, this message translates to:
  /// **'What I offer'**
  String get whatIOffer;

  /// No description provided for @backToLiftingAfterBirth.
  ///
  /// In en, this message translates to:
  /// **'Back to lifting, after birth'**
  String get backToLiftingAfterBirth;

  /// No description provided for @cover.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get cover;

  /// No description provided for @gizaAtHome20Minutes.
  ///
  /// In en, this message translates to:
  /// **'Giza · at home · 20 minutes'**
  String get gizaAtHome20Minutes;

  /// No description provided for @aa.
  ///
  /// In en, this message translates to:
  /// **'Aa'**
  String get aa;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get live;

  /// No description provided for @planWeeklyReviewChat.
  ///
  /// In en, this message translates to:
  /// **'Plan, weekly review, chat'**
  String get planWeeklyReviewChat;

  /// No description provided for @publish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get publish;

  /// No description provided for @n2DaysAgo.
  ///
  /// In en, this message translates to:
  /// **'2 days ago'**
  String get n2DaysAgo;

  /// No description provided for @aMinuteWithMe.
  ///
  /// In en, this message translates to:
  /// **'A minute with me'**
  String get aMinuteWithMe;

  /// No description provided for @addASection.
  ///
  /// In en, this message translates to:
  /// **'Add a section'**
  String get addASection;

  /// No description provided for @askMe.
  ///
  /// In en, this message translates to:
  /// **'Ask me'**
  String get askMe;

  /// No description provided for @backUnderAWeight.
  ///
  /// In en, this message translates to:
  /// **'Back under a weight'**
  String get backUnderAWeight;

  /// No description provided for @designAnAd.
  ///
  /// In en, this message translates to:
  /// **'Design an ad'**
  String get designAnAd;

  /// No description provided for @eightWeeksSameFlatSame15Minutes.
  ///
  /// In en, this message translates to:
  /// **'Eight weeks. Same flat, same 15 minutes.'**
  String get eightWeeksSameFlatSame15Minutes;

  /// No description provided for @myPortfolio.
  ///
  /// In en, this message translates to:
  /// **'My portfolio'**
  String get myPortfolio;

  /// No description provided for @photoHeadlineOneLine.
  ///
  /// In en, this message translates to:
  /// **'Photo, headline, one line'**
  String get photoHeadlineOneLine;

  /// No description provided for @reel.
  ///
  /// In en, this message translates to:
  /// **'Reel'**
  String get reel;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @story.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get story;

  /// No description provided for @theFloorWeeks.
  ///
  /// In en, this message translates to:
  /// **'The floor weeks'**
  String get theFloorWeeks;

  /// No description provided for @threeShortParagraphs.
  ///
  /// In en, this message translates to:
  /// **'Three short paragraphs'**
  String get threeShortParagraphs;

  /// No description provided for @video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// No description provided for @weTalkFirst.
  ///
  /// In en, this message translates to:
  /// **'We talk first'**
  String get weTalkFirst;

  /// No description provided for @week8.
  ///
  /// In en, this message translates to:
  /// **'Week 8'**
  String get week8;

  /// No description provided for @whoIAm.
  ///
  /// In en, this message translates to:
  /// **'Who I am'**
  String get whoIAm;

  /// No description provided for @yourLook.
  ///
  /// In en, this message translates to:
  /// **'Your look'**
  String get yourLook;

  /// No description provided for @yourPage.
  ///
  /// In en, this message translates to:
  /// **'Your page'**
  String get yourPage;

  /// No description provided for @n012100.
  ///
  /// In en, this message translates to:
  /// **'0:12 / 1:00'**
  String get n012100;

  /// No description provided for @n1204Views.
  ///
  /// In en, this message translates to:
  /// **'1,204 views'**
  String get n1204Views;

  /// No description provided for @n1204Views9EnquiriesThisMonth.
  ///
  /// In en, this message translates to:
  /// **'1,204 views · 9 enquiries this month'**
  String get n1204Views9EnquiriesThisMonth;

  /// No description provided for @n16501800Egp.
  ///
  /// In en, this message translates to:
  /// **'1,650 → 1,800 EGP'**
  String get n16501800Egp;

  /// No description provided for @n12Weeks.
  ///
  /// In en, this message translates to:
  /// **'12 weeks'**
  String get n12Weeks;

  /// No description provided for @n15s.
  ///
  /// In en, this message translates to:
  /// **'15s'**
  String get n15s;

  /// No description provided for @n2HoursAgo.
  ///
  /// In en, this message translates to:
  /// **'2 hours ago'**
  String get n2HoursAgo;

  /// No description provided for @n2OffersWrittenByYou.
  ///
  /// In en, this message translates to:
  /// **'2 offers, written by you'**
  String get n2OffersWrittenByYou;

  /// No description provided for @n24Sessions8CountedWeeks.
  ///
  /// In en, this message translates to:
  /// **'24 sessions · 8 counted weeks'**
  String get n24Sessions8CountedWeeks;

  /// No description provided for @n24Sessions8CountedWeeksNoWeight.
  ///
  /// In en, this message translates to:
  /// **'24 sessions · 8 counted weeks · no weight shown'**
  String get n24Sessions8CountedWeeksNoWeight;

  /// No description provided for @n3DaysAgo5DaysLeft.
  ///
  /// In en, this message translates to:
  /// **'3 days ago · 5 days left'**
  String get n3DaysAgo5DaysLeft;

  /// No description provided for @n3HoursAgo.
  ///
  /// In en, this message translates to:
  /// **'3 hours ago'**
  String get n3HoursAgo;

  /// No description provided for @n32MinutesCountedByHerPhone.
  ///
  /// In en, this message translates to:
  /// **'32 minutes · counted by her phone'**
  String get n32MinutesCountedByHerPhone;

  /// No description provided for @n38.
  ///
  /// In en, this message translates to:
  /// **'38%'**
  String get n38;

  /// No description provided for @n4PublishedEachOneConsented.
  ///
  /// In en, this message translates to:
  /// **'4 published · each one consented'**
  String get n4PublishedEachOneConsented;

  /// No description provided for @n4StoriesConsented.
  ///
  /// In en, this message translates to:
  /// **'4 stories · consented'**
  String get n4StoriesConsented;

  /// No description provided for @n48126RepliesIn2h.
  ///
  /// In en, this message translates to:
  /// **'4.8 ★ (126) · replies in ~2h'**
  String get n48126RepliesIn2h;

  /// No description provided for @n48126RepliesIn2h12.
  ///
  /// In en, this message translates to:
  /// **'4.8 ★ (126) · replies in ~2h · 12 spots left'**
  String get n48126RepliesIn2h12;

  /// No description provided for @n54.
  ///
  /// In en, this message translates to:
  /// **'54%'**
  String get n54;

  /// No description provided for @n6Sections.
  ///
  /// In en, this message translates to:
  /// **'6 sections'**
  String get n6Sections;

  /// No description provided for @n71.
  ///
  /// In en, this message translates to:
  /// **'71%'**
  String get n71;

  /// No description provided for @n86OpenedYourPage9AskedTo.
  ///
  /// In en, this message translates to:
  /// **'86 opened your page · 9 asked to work with you'**
  String get n86OpenedYourPage9AskedTo;

  /// No description provided for @n92.
  ///
  /// In en, this message translates to:
  /// **'92%'**
  String get n92;

  /// No description provided for @aFollowUpStaysOnTheFirst.
  ///
  /// In en, this message translates to:
  /// **'A follow-up stays on the first post, so a thread is one woman over time, never two women side by side.'**
  String get aFollowUpStaysOnTheFirst;

  /// No description provided for @aPlanBuiltForYourDays.
  ///
  /// In en, this message translates to:
  /// **'A plan built for your days'**
  String get aPlanBuiltForYourDays;

  /// No description provided for @aProgramNoCheckIns900Egp.
  ///
  /// In en, this message translates to:
  /// **'A program, no check-ins · 900 EGP'**
  String get aProgramNoCheckIns900Egp;

  /// No description provided for @aResultCanBePicturesNumbersOr.
  ///
  /// In en, this message translates to:
  /// **'A result can be pictures, numbers, or her sentence, whichever she agreed to.'**
  String get aResultCanBePicturesNumbersOr;

  /// No description provided for @aVoiceNote.
  ///
  /// In en, this message translates to:
  /// **'A voice note'**
  String get aVoiceNote;

  /// No description provided for @aWeeklyReviewAnsweredByVoice.
  ///
  /// In en, this message translates to:
  /// **'A weekly review answered by voice'**
  String get aWeeklyReviewAnsweredByVoice;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @addAFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Add a follow-up'**
  String get addAFollowUp;

  /// No description provided for @addAFollowUpPictureToIt.
  ///
  /// In en, this message translates to:
  /// **'Add a follow-up picture to it'**
  String get addAFollowUpPictureToIt;

  /// No description provided for @addALine.
  ///
  /// In en, this message translates to:
  /// **'Add a line'**
  String get addALine;

  /// No description provided for @addAStep.
  ///
  /// In en, this message translates to:
  /// **'Add a step'**
  String get addAStep;

  /// No description provided for @addAnotherOffer.
  ///
  /// In en, this message translates to:
  /// **'Add another offer'**
  String get addAnotherOffer;

  /// No description provided for @addPhotosOrAVideo.
  ///
  /// In en, this message translates to:
  /// **'Add photos or a video'**
  String get addPhotosOrAVideo;

  /// No description provided for @addWhatItCostYou.
  ///
  /// In en, this message translates to:
  /// **'Add what it cost you'**
  String get addWhatItCostYou;

  /// No description provided for @added.
  ///
  /// In en, this message translates to:
  /// **'added'**
  String get added;

  /// No description provided for @askAnotherClient.
  ///
  /// In en, this message translates to:
  /// **'Ask another client'**
  String get askAnotherClient;

  /// No description provided for @backToEditing.
  ///
  /// In en, this message translates to:
  /// **'Back to editing'**
  String get backToEditing;

  /// No description provided for @badgeMostPicked.
  ///
  /// In en, this message translates to:
  /// **'Badge: most picked'**
  String get badgeMostPicked;

  /// No description provided for @beginnersGroupJustNow.
  ///
  /// In en, this message translates to:
  /// **'Beginners group · just now'**
  String get beginnersGroupJustNow;

  /// No description provided for @blur.
  ///
  /// In en, this message translates to:
  /// **'Blur'**
  String get blur;

  /// No description provided for @blurAnyClientWhoIsInShot.
  ///
  /// In en, this message translates to:
  /// **'Blur any client who is in shot'**
  String get blurAnyClientWhoIsInShot;

  /// No description provided for @calmAndPlain.
  ///
  /// In en, this message translates to:
  /// **'Calm and plain'**
  String get calmAndPlain;

  /// No description provided for @carriedBothKidsUpTheStairs24.
  ///
  /// In en, this message translates to:
  /// **'Carried both kids up the stairs. 24 sessions, no weight ever discussed.'**
  String get carriedBothKidsUpTheStairs24;

  /// No description provided for @changePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get changePhoto;

  /// No description provided for @coachSara.
  ///
  /// In en, this message translates to:
  /// **'Coach Sara'**
  String get coachSara;

  /// No description provided for @colour.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get colour;

  /// No description provided for @colourTypeAndShapeChangeEverySection.
  ///
  /// In en, this message translates to:
  /// **'Colour, type and shape change every section at once. Nothing you write moves.'**
  String get colourTypeAndShapeChangeEverySection;

  /// No description provided for @consented2SeptemberSheChoseBlur.
  ///
  /// In en, this message translates to:
  /// **'Consented 2 September · she chose blur'**
  String get consented2SeptemberSheChoseBlur;

  /// No description provided for @contrastIsCheckedForYou.
  ///
  /// In en, this message translates to:
  /// **'Contrast is checked for you'**
  String get contrastIsCheckedForYou;

  /// No description provided for @corners.
  ///
  /// In en, this message translates to:
  /// **'Corners'**
  String get corners;

  /// No description provided for @coverPhoto.
  ///
  /// In en, this message translates to:
  /// **'Cover photo'**
  String get coverPhoto;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @darkenThePhoto.
  ///
  /// In en, this message translates to:
  /// **'Darken the photo'**
  String get darkenThePhoto;

  /// No description provided for @designIt.
  ///
  /// In en, this message translates to:
  /// **'Design it'**
  String get designIt;

  /// No description provided for @designYourPage.
  ///
  /// In en, this message translates to:
  /// **'Design your page'**
  String get designYourPage;

  /// No description provided for @dragToReorderTheEyeHidesA.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder. The eye hides a section without deleting what is in it.'**
  String get dragToReorderTheEyeHidesA;

  /// No description provided for @editWords.
  ///
  /// In en, this message translates to:
  /// **'Edit words'**
  String get editWords;

  /// No description provided for @eightWeeks.
  ///
  /// In en, this message translates to:
  /// **'Eight weeks'**
  String get eightWeeks;

  /// No description provided for @eightWeeksSinceYourFirstPost.
  ///
  /// In en, this message translates to:
  /// **'Eight weeks since your first post'**
  String get eightWeeksSinceYourFirstPost;

  /// No description provided for @enquiries.
  ///
  /// In en, this message translates to:
  /// **'enquiries'**
  String get enquiries;

  /// No description provided for @facesBlurredBeforeItUploads.
  ///
  /// In en, this message translates to:
  /// **'Faces blurred before it uploads'**
  String get facesBlurredBeforeItUploads;

  /// No description provided for @facesBlurredInBoth.
  ///
  /// In en, this message translates to:
  /// **'Faces blurred in both'**
  String get facesBlurredInBoth;

  /// No description provided for @feed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get feed;

  /// No description provided for @followBack.
  ///
  /// In en, this message translates to:
  /// **'Follow back'**
  String get followBack;

  /// No description provided for @followUp.
  ///
  /// In en, this message translates to:
  /// **'Follow-up'**
  String get followUp;

  /// No description provided for @followers.
  ///
  /// In en, this message translates to:
  /// **'followers'**
  String get followers;

  /// No description provided for @following.
  ///
  /// In en, this message translates to:
  /// **'following'**
  String get following;

  /// No description provided for @forYou.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get forYou;

  /// No description provided for @fourWeeksInAndICarriedBoth_4oed7.
  ///
  /// In en, this message translates to:
  /// **'Four weeks in and I carried both kids up the stairs without stopping.'**
  String get fourWeeksInAndICarriedBoth_4oed7;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @goBackToItAnyTime.
  ///
  /// In en, this message translates to:
  /// **'Go back to it any time.'**
  String get goBackToItAnyTime;

  /// No description provided for @habiba.
  ///
  /// In en, this message translates to:
  /// **'Habiba'**
  String get habiba;

  /// No description provided for @headline.
  ///
  /// In en, this message translates to:
  /// **'Headline'**
  String get headline;

  /// No description provided for @herVoice034.
  ///
  /// In en, this message translates to:
  /// **'Her voice · 0:34'**
  String get herVoice034;

  /// No description provided for @hidden.
  ///
  /// In en, this message translates to:
  /// **'hidden'**
  String get hidden;

  /// No description provided for @hiddenForNow.
  ///
  /// In en, this message translates to:
  /// **'Hidden for now'**
  String get hiddenForNow;

  /// No description provided for @iTakeWomenFromSixWeeksAfter_wduev.
  ///
  /// In en, this message translates to:
  /// **'I take women from six weeks after birth back to lifting, slowly.'**
  String get iTakeWomenFromSixWeeksAfter_wduev;

  /// No description provided for @keepAsADraft.
  ///
  /// In en, this message translates to:
  /// **'Keep as a draft'**
  String get keepAsADraft;

  /// No description provided for @last30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get last30Days;

  /// No description provided for @layout.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get layout;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @liveWithinAMinute.
  ///
  /// In en, this message translates to:
  /// **'Live within a minute'**
  String get liveWithinAMinute;

  /// No description provided for @maiAgreedToShowTheseChoseThe.
  ///
  /// In en, this message translates to:
  /// **'Mai agreed to show these, chose the pictures, and can withdraw them.'**
  String get maiAgreedToShowTheseChoseThe;

  /// No description provided for @media.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get media;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @nada.
  ///
  /// In en, this message translates to:
  /// **'Nada'**
  String get nada;

  /// No description provided for @nadaCommentedThisIsTheExactThing.
  ///
  /// In en, this message translates to:
  /// **'Nada commented: “This is the exact thing I needed.”'**
  String get nadaCommentedThisIsTheExactThing;

  /// No description provided for @nasmCptPreAndPostnatalCheckedBy.
  ///
  /// In en, this message translates to:
  /// **'NASM CPT · pre and postnatal · checked by us 12 March'**
  String get nasmCptPreAndPostnatalCheckedBy;

  /// No description provided for @noPhoto.
  ///
  /// In en, this message translates to:
  /// **'No photo'**
  String get noPhoto;

  /// No description provided for @noWeightLossPromisesAndNoTimelines.
  ///
  /// In en, this message translates to:
  /// **'No weight-loss promises and no timelines. We check every ad against the same rules before it runs.'**
  String get noWeightLossPromisesAndNoTimelines;

  /// No description provided for @nothingAboutThisPageIsATemplate.
  ///
  /// In en, this message translates to:
  /// **'Nothing about this page is a template we hand you. The sections, the order, the colours and the words are yours. We only check the certificates behind the badge.'**
  String get nothingAboutThisPageIsATemplate;

  /// No description provided for @nothingHereIsANumberGoingUp.
  ///
  /// In en, this message translates to:
  /// **'Nothing here is a number going up. Every line is a woman who did something, or a thing you can act on.'**
  String get nothingHereIsANumberGoingUp;

  /// No description provided for @nourhanGizaFrom1800Egp.
  ///
  /// In en, this message translates to:
  /// **'Nourhan · Giza · from 1,800 EGP'**
  String get nourhanGizaFrom1800Egp;

  /// No description provided for @now16September.
  ///
  /// In en, this message translates to:
  /// **'Now · 16 September'**
  String get now16September;

  /// No description provided for @numbers.
  ///
  /// In en, this message translates to:
  /// **'Numbers'**
  String get numbers;

  /// No description provided for @numbersOnlyNeverAWeightFromThe_1oov4.
  ///
  /// In en, this message translates to:
  /// **'Numbers only, never a weight from the scale'**
  String get numbersOnlyNeverAWeightFromThe_1oov4;

  /// No description provided for @numbersOnlySheDeclinedPhotos.
  ///
  /// In en, this message translates to:
  /// **'Numbers only · she declined photos'**
  String get numbersOnlySheDeclinedPhotos;

  /// No description provided for @onBeforeYouAskTapToShow.
  ///
  /// In en, this message translates to:
  /// **'On before you ask. Tap to show yours.'**
  String get onBeforeYouAskTapToShow;

  /// No description provided for @onByDefaultOnTheOldOne.
  ///
  /// In en, this message translates to:
  /// **'On by default, on the old one too.'**
  String get onByDefaultOnTheOldOne;

  /// No description provided for @onUnlessSheConsentedToHerFace.
  ///
  /// In en, this message translates to:
  /// **'On unless she consented to her face.'**
  String get onUnlessSheConsentedToHerFace;

  /// No description provided for @oneLineUnderIt.
  ///
  /// In en, this message translates to:
  /// **'One line under it'**
  String get oneLineUnderIt;

  /// No description provided for @onlyVerifiedWomenCanSeeAnythingYou.
  ///
  /// In en, this message translates to:
  /// **'Only verified women can see anything you post here, and screenshots are against the pledge everyone agreed to.'**
  String get onlyVerifiedWomenCanSeeAnythingYou;

  /// No description provided for @onlyYouCanSeeWhatYouSaved.
  ///
  /// In en, this message translates to:
  /// **'Only you can see what you saved.'**
  String get onlyYouCanSeeWhatYouSaved;

  /// No description provided for @opened.
  ///
  /// In en, this message translates to:
  /// **'opened'**
  String get opened;

  /// No description provided for @pelvicFloorAndBreathingBeforeASingle.
  ///
  /// In en, this message translates to:
  /// **'Pelvic floor and breathing before a single squat.'**
  String get pelvicFloorAndBreathingBeforeASingle;

  /// No description provided for @photoAbove.
  ///
  /// In en, this message translates to:
  /// **'Photo above'**
  String get photoAbove;

  /// No description provided for @photoOrPost.
  ///
  /// In en, this message translates to:
  /// **'Photo or post'**
  String get photoOrPost;

  /// No description provided for @photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @pickAsManyAsYouWantIn.
  ///
  /// In en, this message translates to:
  /// **'Pick as many as you want, in any order. A section can appear more than once.'**
  String get pickAsManyAsYouWantIn;

  /// No description provided for @pickThePostYouAreFollowingUp.
  ///
  /// In en, this message translates to:
  /// **'Pick the post you are following up on. The new picture joins it instead of starting again.'**
  String get pickThePostYouAreFollowingUp;

  /// No description provided for @plank20s75s.
  ///
  /// In en, this message translates to:
  /// **'Plank 20s → 75s'**
  String get plank20s75s;

  /// No description provided for @postTheFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Post the follow-up'**
  String get postTheFollowUp;

  /// No description provided for @posted8WeeksAgo96Likes.
  ///
  /// In en, this message translates to:
  /// **'Posted 8 weeks ago · 96 likes'**
  String get posted8WeeksAgo96Likes;

  /// No description provided for @posts.
  ///
  /// In en, this message translates to:
  /// **'posts'**
  String get posts;

  /// No description provided for @publishVersion4.
  ///
  /// In en, this message translates to:
  /// **'Publish version 4'**
  String get publishVersion4;

  /// No description provided for @published4DaysAgoVersion3.
  ///
  /// In en, this message translates to:
  /// **'Published 4 days ago · version 3'**
  String get published4DaysAgoVersion3;

  /// No description provided for @questions.
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get questions;

  /// No description provided for @quietMoves.
  ///
  /// In en, this message translates to:
  /// **'Quiet moves'**
  String get quietMoves;

  /// No description provided for @reelCover.
  ///
  /// In en, this message translates to:
  /// **'Reel cover'**
  String get reelCover;

  /// No description provided for @reels.
  ///
  /// In en, this message translates to:
  /// **'Reels'**
  String get reels;

  /// No description provided for @replaced.
  ///
  /// In en, this message translates to:
  /// **'replaced'**
  String get replaced;

  /// No description provided for @round.
  ///
  /// In en, this message translates to:
  /// **'Round'**
  String get round;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @sayWhatChanged.
  ///
  /// In en, this message translates to:
  /// **'Say what changed'**
  String get sayWhatChanged;

  /// No description provided for @searchWomenGroupsAndMoves.
  ///
  /// In en, this message translates to:
  /// **'Search women, groups and moves'**
  String get searchWomenGroupsAndMoves;

  /// No description provided for @sections.
  ///
  /// In en, this message translates to:
  /// **'Sections'**
  String get sections;

  /// No description provided for @sectionsColoursAndWordsAllYours.
  ///
  /// In en, this message translates to:
  /// **'Sections, colours and words · all yours'**
  String get sectionsColoursAndWordsAllYours;

  /// No description provided for @seeAll27Comments.
  ///
  /// In en, this message translates to:
  /// **'See all 27 comments'**
  String get seeAll27Comments;

  /// No description provided for @seeAll41Comments.
  ///
  /// In en, this message translates to:
  /// **'See all 41 comments'**
  String get seeAll41Comments;

  /// No description provided for @sendHerSomethingKind.
  ///
  /// In en, this message translates to:
  /// **'Send her something kind'**
  String get sendHerSomethingKind;

  /// No description provided for @sevenWomenInAHundredWhoSee.
  ///
  /// In en, this message translates to:
  /// **'Seven women in a hundred who see you ask. The average here is four.'**
  String get sevenWomenInAHundredWhoSee;

  /// No description provided for @sharp.
  ///
  /// In en, this message translates to:
  /// **'Sharp'**
  String get sharp;

  /// No description provided for @sheHasToAgreeInTheApp.
  ///
  /// In en, this message translates to:
  /// **'She has to agree, in the app'**
  String get sheHasToAgreeInTheApp;

  /// No description provided for @sixWeeksAfterBirthOnTheFloor.
  ///
  /// In en, this message translates to:
  /// **'Six weeks after birth, on the floor'**
  String get sixWeeksAfterBirthOnTheFloor;

  /// No description provided for @slowlyWithYourDoctorsClearance.
  ///
  /// In en, this message translates to:
  /// **'Slowly, with your doctor’s clearance.'**
  String get slowlyWithYourDoctorsClearance;

  /// No description provided for @soTheWordsStayReadable.
  ///
  /// In en, this message translates to:
  /// **'So the words stay readable'**
  String get soTheWordsStayReadable;

  /// No description provided for @soft.
  ///
  /// In en, this message translates to:
  /// **'Soft'**
  String get soft;

  /// No description provided for @softAndRound.
  ///
  /// In en, this message translates to:
  /// **'Soft and round'**
  String get softAndRound;

  /// No description provided for @somethingFree.
  ///
  /// In en, this message translates to:
  /// **'Something free'**
  String get somethingFree;

  /// No description provided for @strongAndWide.
  ///
  /// In en, this message translates to:
  /// **'Strong and wide'**
  String get strongAndWide;

  /// No description provided for @textOverPhoto.
  ///
  /// In en, this message translates to:
  /// **'Text over photo'**
  String get textOverPhoto;

  /// No description provided for @theLastMonthYouRunThePlan.
  ///
  /// In en, this message translates to:
  /// **'The last month you run the plan, I only watch.'**
  String get theLastMonthYouRunThePlan;

  /// No description provided for @then21July.
  ///
  /// In en, this message translates to:
  /// **'Then · 21 July'**
  String get then21July;

  /// No description provided for @thisIsYoursNotOurs.
  ///
  /// In en, this message translates to:
  /// **'This is yours, not ours'**
  String get thisIsYoursNotOurs;

  /// No description provided for @threeFloorMovesForAFlatWith.
  ///
  /// In en, this message translates to:
  /// **'Three floor moves for a flat with thin walls. No jumping, nothing to carry.'**
  String get threeFloorMovesForAFlatWith;

  /// No description provided for @trainingInASmallFlatQuietlyBeginners.
  ///
  /// In en, this message translates to:
  /// **'Training in a small flat, quietly. Beginners group.'**
  String get trainingInASmallFlatQuietlyBeginners;

  /// No description provided for @twentyMinutesNoChargeBeforeYouPay.
  ///
  /// In en, this message translates to:
  /// **'Twenty minutes, no charge, before you pay anything.'**
  String get twentyMinutesNoChargeBeforeYouPay;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @upToAMinuteForTheGroup.
  ///
  /// In en, this message translates to:
  /// **'Up to a minute, for the group'**
  String get upToAMinuteForTheGroup;

  /// No description provided for @verifiedWomanJoinedMarchShowingUp.
  ///
  /// In en, this message translates to:
  /// **'Verified woman · joined March · Showing up'**
  String get verifiedWomanJoinedMarchShowingUp;

  /// No description provided for @version3IsKept.
  ///
  /// In en, this message translates to:
  /// **'Version 3 is kept'**
  String get version3IsKept;

  /// No description provided for @views.
  ///
  /// In en, this message translates to:
  /// **'views'**
  String get views;

  /// No description provided for @viewsProfileEnquiries.
  ///
  /// In en, this message translates to:
  /// **'Views → profile → enquiries'**
  String get viewsProfileEnquiries;

  /// No description provided for @voice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voice;

  /// No description provided for @walkBeforeTheSchoolRun.
  ///
  /// In en, this message translates to:
  /// **'Walk before the school run'**
  String get walkBeforeTheSchoolRun;

  /// No description provided for @weAskHerShePicksThePictures.
  ///
  /// In en, this message translates to:
  /// **'We ask her, she picks the pictures, and she can withdraw it later.'**
  String get weAskHerShePicksThePictures;

  /// No description provided for @weWillNotLetYouPickText.
  ///
  /// In en, this message translates to:
  /// **'We will not let you pick text a client cannot read.'**
  String get weWillNotLetYouPickText;

  /// No description provided for @whatChangedSinceVersion3.
  ///
  /// In en, this message translates to:
  /// **'What changed since version 3'**
  String get whatChangedSinceVersion3;

  /// No description provided for @whatItCostHer.
  ///
  /// In en, this message translates to:
  /// **'What it cost her'**
  String get whatItCostHer;

  /// No description provided for @whatItIsDoing.
  ///
  /// In en, this message translates to:
  /// **'What it is doing'**
  String get whatItIsDoing;

  /// No description provided for @whatTheySaid.
  ///
  /// In en, this message translates to:
  /// **'What they said'**
  String get whatTheySaid;

  /// No description provided for @whenIAmFree.
  ///
  /// In en, this message translates to:
  /// **'When I am free'**
  String get whenIAmFree;

  /// No description provided for @whichSectionTheyStopOn.
  ///
  /// In en, this message translates to:
  /// **'Which section they stop on'**
  String get whichSectionTheyStopOn;

  /// No description provided for @womenAlreadyReadingItSeeTheOld.
  ///
  /// In en, this message translates to:
  /// **'Women already reading it see the old one until it swaps.'**
  String get womenAlreadyReadingItSeeTheOld;

  /// No description provided for @womenWhoReachClientResultsAskTwice.
  ///
  /// In en, this message translates to:
  /// **'Women who reach Client results ask twice as often. It sits fifth. Try moving it up.'**
  String get womenWhoReachClientResultsAskTwice;

  /// No description provided for @writeYourOwnOffersTwoIsCommon.
  ///
  /// In en, this message translates to:
  /// **'Write your own offers. Two is common, one is fine, and nothing forces them to look alike.'**
  String get writeYourOwnOffersTwoIsCommon;

  /// No description provided for @yasmin.
  ///
  /// In en, this message translates to:
  /// **'Yasmin'**
  String get yasmin;

  /// No description provided for @yasminStartedFollowingYou.
  ///
  /// In en, this message translates to:
  /// **'Yasmin started following you'**
  String get yasminStartedFollowingYou;

  /// No description provided for @youKeep80OfEveryPriceYou.
  ///
  /// In en, this message translates to:
  /// **'You keep 80% of every price you write here. The client sees the price; she never sees our share.'**
  String get youKeep80OfEveryPriceYou;

  /// No description provided for @youKeepIt.
  ///
  /// In en, this message translates to:
  /// **'You keep it'**
  String get youKeepIt;

  /// No description provided for @yourColours.
  ///
  /// In en, this message translates to:
  /// **'Your colours'**
  String get yourColours;

  /// No description provided for @yourDay.
  ///
  /// In en, this message translates to:
  /// **'Your day'**
  String get yourDay;

  /// No description provided for @yourFourSteps.
  ///
  /// In en, this message translates to:
  /// **'Your four steps'**
  String get yourFourSteps;

  /// No description provided for @yourLookSizedForTheFeedA.
  ///
  /// In en, this message translates to:
  /// **'Your look, sized for the feed, a story or a reel cover'**
  String get yourLookSizedForTheFeedA;

  /// No description provided for @yourMedia.
  ///
  /// In en, this message translates to:
  /// **'Your media'**
  String get yourMedia;

  /// No description provided for @yourMethodInYourOwnStepsName.
  ///
  /// In en, this message translates to:
  /// **'Your method, in your own steps. Name them whatever you call them with clients.'**
  String get yourMethodInYourOwnStepsName;

  /// No description provided for @yourPriceChangeAppliesToNewClients.
  ///
  /// In en, this message translates to:
  /// **'Your price change applies to new clients only. Everyone already with you keeps what she agreed to.'**
  String get yourPriceChangeAppliesToNewClients;

  /// No description provided for @atIntake.
  ///
  /// In en, this message translates to:
  /// **'at intake'**
  String get atIntake;

  /// No description provided for @n15Min5MovesQuietNoEquipment.
  ///
  /// In en, this message translates to:
  /// **'15 min · 5 moves · quiet, no equipment, last week’s weights'**
  String get n15Min5MovesQuietNoEquipment;

  /// No description provided for @modify.
  ///
  /// In en, this message translates to:
  /// **'Modify'**
  String get modify;

  /// No description provided for @pass.
  ///
  /// In en, this message translates to:
  /// **'Pass'**
  String get pass;

  /// No description provided for @refer.
  ///
  /// In en, this message translates to:
  /// **'Refer'**
  String get refer;

  /// No description provided for @buildASplit.
  ///
  /// In en, this message translates to:
  /// **'Build a split'**
  String get buildASplit;

  /// No description provided for @clientsAtOnce.
  ///
  /// In en, this message translates to:
  /// **'Clients at once'**
  String get clientsAtOnce;

  /// No description provided for @egyptianDishesWithPortionsAndCostPer.
  ///
  /// In en, this message translates to:
  /// **'Egyptian dishes with portions and cost per serving'**
  String get egyptianDishesWithPortionsAndCostPer;

  /// No description provided for @mySplits.
  ///
  /// In en, this message translates to:
  /// **'My splits'**
  String get mySplits;

  /// No description provided for @singleLegBalance.
  ///
  /// In en, this message translates to:
  /// **'Single-leg balance'**
  String get singleLegBalance;

  /// No description provided for @sitToStand.
  ///
  /// In en, this message translates to:
  /// **'Sit to stand'**
  String get sitToStand;

  /// No description provided for @upperLower.
  ///
  /// In en, this message translates to:
  /// **'Upper / lower'**
  String get upperLower;

  /// No description provided for @n15Points.
  ///
  /// In en, this message translates to:
  /// **'+15 points'**
  String get n15Points;

  /// No description provided for @n0To6Weeks.
  ///
  /// In en, this message translates to:
  /// **'0 to 6 weeks'**
  String get n0To6Weeks;

  /// No description provided for @n11S.
  ///
  /// In en, this message translates to:
  /// **'11 s'**
  String get n11S;

  /// No description provided for @n2Of5MovesDone.
  ///
  /// In en, this message translates to:
  /// **'2 of 5 moves done'**
  String get n2Of5MovesDone;

  /// No description provided for @n20S.
  ///
  /// In en, this message translates to:
  /// **'20 s'**
  String get n20S;

  /// No description provided for @n3DaysSunTueThuOn7.
  ///
  /// In en, this message translates to:
  /// **'3 days · Sun, Tue, Thu · on 7 clients'**
  String get n3DaysSunTueThuOn7;

  /// No description provided for @n3DaysWeeks1To4On.
  ///
  /// In en, this message translates to:
  /// **'3 days · weeks 1 to 4 · on 5 clients'**
  String get n3DaysWeeks1To4On;

  /// No description provided for @n4Days2On1OffOn.
  ///
  /// In en, this message translates to:
  /// **'4 days · 2 on, 1 off · on 3 clients'**
  String get n4Days2On1OffOn;

  /// No description provided for @n4S.
  ///
  /// In en, this message translates to:
  /// **'4 s'**
  String get n4S;

  /// No description provided for @n475Total.
  ///
  /// In en, this message translates to:
  /// **'475 total'**
  String get n475Total;

  /// No description provided for @n5NoHands.
  ///
  /// In en, this message translates to:
  /// **'5 no hands'**
  String get n5NoHands;

  /// No description provided for @n5WithHands.
  ///
  /// In en, this message translates to:
  /// **'5 with hands'**
  String get n5WithHands;

  /// No description provided for @n6DaysAdvancedOn1Client.
  ///
  /// In en, this message translates to:
  /// **'6 days · advanced · on 1 client'**
  String get n6DaysAdvancedOn1Client;

  /// No description provided for @n6WeeksTo1Year.
  ///
  /// In en, this message translates to:
  /// **'6 weeks to 1 year'**
  String get n6WeeksTo1Year;

  /// No description provided for @n75S.
  ///
  /// In en, this message translates to:
  /// **'75 s'**
  String get n75S;

  /// No description provided for @n85PointsToLevel8.
  ///
  /// In en, this message translates to:
  /// **'85 points to level 8.'**
  String get n85PointsToLevel8;

  /// No description provided for @aReAssessmentNeverEditsAPublished.
  ///
  /// In en, this message translates to:
  /// **'A re-assessment never edits a published plan by itself. Save it, then adjust her weeks, the same way a message never changes a plan.'**
  String get aReAssessmentNeverEditsAPublished;

  /// No description provided for @aSplitIsAWeekShapeYou.
  ///
  /// In en, this message translates to:
  /// **'A split is a week shape you write once and apply to any client. Editing a split never changes a plan you already published.'**
  String get aSplitIsAWeekShapeYou;

  /// No description provided for @anyLeakingHeavinessOrDoming.
  ///
  /// In en, this message translates to:
  /// **'Any leaking, heaviness or doming'**
  String get anyLeakingHeavinessOrDoming;

  /// No description provided for @anythingYouCannotEat.
  ///
  /// In en, this message translates to:
  /// **'Anything you cannot eat'**
  String get anythingYouCannotEat;

  /// No description provided for @applyASplit.
  ///
  /// In en, this message translates to:
  /// **'Apply a split'**
  String get applyASplit;

  /// No description provided for @applyingASplitWritesTheseDaysAcross.
  ///
  /// In en, this message translates to:
  /// **'Applying a split writes these days across the month. You still tailor sets, weights and notes per client.'**
  String get applyingASplitWritesTheseDaysAcross;

  /// No description provided for @approvedSubstitutionsCarryIntoEveryClientYou.
  ///
  /// In en, this message translates to:
  /// **'Approved substitutions carry into every client you apply this to.'**
  String get approvedSubstitutionsCarryIntoEveryClientYou;

  /// No description provided for @assessment.
  ///
  /// In en, this message translates to:
  /// **'Assessment'**
  String get assessment;

  /// No description provided for @assessmentNour.
  ///
  /// In en, this message translates to:
  /// **'Assessment · Nour'**
  String get assessmentNour;

  /// No description provided for @assessmentDue.
  ///
  /// In en, this message translates to:
  /// **'Assessment due'**
  String get assessmentDue;

  /// No description provided for @baseline.
  ///
  /// In en, this message translates to:
  /// **'Baseline'**
  String get baseline;

  /// No description provided for @bestsSquat12KgPlank45S.
  ///
  /// In en, this message translates to:
  /// **'Bests: squat 12 kg · plank 45 s'**
  String get bestsSquat12KgPlank45S;

  /// No description provided for @birth.
  ///
  /// In en, this message translates to:
  /// **'Birth'**
  String get birth;

  /// No description provided for @caesarean.
  ///
  /// In en, this message translates to:
  /// **'Caesarean'**
  String get caesarean;

  /// No description provided for @day1_4ehtd.
  ///
  /// In en, this message translates to:
  /// **'Day 1'**
  String get day1_4ehtd;

  /// No description provided for @day2.
  ///
  /// In en, this message translates to:
  /// **'Day 2'**
  String get day2;

  /// No description provided for @day3.
  ///
  /// In en, this message translates to:
  /// **'Day 3'**
  String get day3;

  /// No description provided for @day4.
  ///
  /// In en, this message translates to:
  /// **'Day 4'**
  String get day4;

  /// No description provided for @deepKneeBends.
  ///
  /// In en, this message translates to:
  /// **'Deep knee bends'**
  String get deepKneeBends;

  /// No description provided for @doctorsClearanceToTrain.
  ///
  /// In en, this message translates to:
  /// **'Doctor\'s clearance to train'**
  String get doctorsClearanceToTrain;

  /// No description provided for @done2SeptemberReAssessIn2.
  ///
  /// In en, this message translates to:
  /// **'Done 2 September · re-assess in 2 weeks'**
  String get done2SeptemberReAssessIn2;

  /// No description provided for @everything.
  ///
  /// In en, this message translates to:
  /// **'Everything'**
  String get everything;

  /// No description provided for @filledInFromHerIntakeChangeWhat.
  ///
  /// In en, this message translates to:
  /// **'Filled in from her intake. Change what has moved, and nothing is overwritten until you save.'**
  String get filledInFromHerIntakeChangeWhat;

  /// No description provided for @fiveTimesNoHands.
  ///
  /// In en, this message translates to:
  /// **'Five times, no hands'**
  String get fiveTimesNoHands;

  /// No description provided for @fullBody3.
  ///
  /// In en, this message translates to:
  /// **'Full body ×3'**
  String get fullBody3;

  /// Undo snackbar after a whole move (I did them all).
  ///
  /// In en, this message translates to:
  /// **'{move} saved · {sets} sets'**
  String moveSavedSetsSets(String move, int sets);

  /// No description provided for @healthAndClearance.
  ///
  /// In en, this message translates to:
  /// **'Health and clearance'**
  String get healthAndClearance;

  /// No description provided for @highImpact.
  ///
  /// In en, this message translates to:
  /// **'High impact'**
  String get highImpact;

  /// No description provided for @howManyDaysBeforeItRepeats.
  ///
  /// In en, this message translates to:
  /// **'How many days before it repeats?'**
  String get howManyDaysBeforeItRepeats;

  /// No description provided for @howYouUsuallyEat.
  ///
  /// In en, this message translates to:
  /// **'How you usually eat'**
  String get howYouUsuallyEat;

  /// No description provided for @keepHerEasierOptions.
  ///
  /// In en, this message translates to:
  /// **'Keep her easier options'**
  String get keepHerEasierOptions;

  /// No description provided for @kneePainOnStairs.
  ///
  /// In en, this message translates to:
  /// **'Knee pain on stairs'**
  String get kneePainOnStairs;

  /// No description provided for @loadedTwisting.
  ///
  /// In en, this message translates to:
  /// **'Loaded twisting'**
  String get loadedTwisting;

  /// No description provided for @addedFromMemoryYourWeekCountsIt.
  ///
  /// In en, this message translates to:
  /// **'Added from memory. Your week counts it like any other session.'**
  String get addedFromMemoryYourWeekCountsIt;

  /// No description provided for @lowerBody20Min.
  ///
  /// In en, this message translates to:
  /// **'Lower body · 20 min'**
  String get lowerBody20Min;

  /// No description provided for @mostDays.
  ///
  /// In en, this message translates to:
  /// **'Most days'**
  String get mostDays;

  /// No description provided for @movementScreening.
  ///
  /// In en, this message translates to:
  /// **'Movement screening'**
  String get movementScreening;

  /// No description provided for @nameIt.
  ///
  /// In en, this message translates to:
  /// **'Name it'**
  String get nameIt;

  /// No description provided for @nextMoveStepBackLunge.
  ///
  /// In en, this message translates to:
  /// **'Next move · step-back lunge'**
  String get nextMoveStepBackLunge;

  /// No description provided for @noAssessmentOnFilePublishAnywayOr.
  ///
  /// In en, this message translates to:
  /// **'No assessment on file. Publish anyway, or complete it first.'**
  String get noAssessmentOnFilePublishAnywayOr;

  /// No description provided for @noDairy.
  ///
  /// In en, this message translates to:
  /// **'No dairy'**
  String get noDairy;

  /// No description provided for @noGluten.
  ///
  /// In en, this message translates to:
  /// **'No gluten'**
  String get noGluten;

  /// No description provided for @noNuts.
  ///
  /// In en, this message translates to:
  /// **'No nuts'**
  String get noNuts;

  /// No description provided for @noNutsVegetarianOnWeekdaysBothFrom.
  ///
  /// In en, this message translates to:
  /// **'No nuts. Vegetarian on weekdays. Both from her assessment.'**
  String get noNutsVegetarianOnWeekdaysBothFrom;

  /// No description provided for @noPersonalBestFromThisOneThe.
  ///
  /// In en, this message translates to:
  /// **'No personal best from this one. The numbers were copied, not measured.'**
  String get noPersonalBestFromThisOneThe;

  /// No description provided for @noShellfish.
  ///
  /// In en, this message translates to:
  /// **'No shellfish'**
  String get noShellfish;

  /// No description provided for @nothingHereIsShownToOtherMembers.
  ///
  /// In en, this message translates to:
  /// **'Nothing here is shown to other members, ever.'**
  String get nothingHereIsShownToOtherMembers;

  /// No description provided for @ofEveryPriceYouSetOnYour.
  ///
  /// In en, this message translates to:
  /// **'Of every price you set on your page.'**
  String get ofEveryPriceYouSetOnYour;

  /// No description provided for @overAYear.
  ///
  /// In en, this message translates to:
  /// **'Over a year'**
  String get overAYear;

  /// No description provided for @painInjuriesOrSurgery.
  ///
  /// In en, this message translates to:
  /// **'Pain, injuries or surgery'**
  String get painInjuriesOrSurgery;

  /// No description provided for @pelvicFloorSymptoms.
  ///
  /// In en, this message translates to:
  /// **'Pelvic floor symptoms'**
  String get pelvicFloorSymptoms;

  /// No description provided for @pelvicFloorStillReferred.
  ///
  /// In en, this message translates to:
  /// **'Pelvic floor: still referred'**
  String get pelvicFloorStillReferred;

  /// No description provided for @plan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get plan;

  /// No description provided for @postpartumFloorWeeks.
  ///
  /// In en, this message translates to:
  /// **'Postpartum floor weeks'**
  String get postpartumFloorWeeks;

  /// No description provided for @proneOnBelly.
  ///
  /// In en, this message translates to:
  /// **'Prone on belly'**
  String get proneOnBelly;

  /// No description provided for @pushPullLegs.
  ///
  /// In en, this message translates to:
  /// **'Push · pull · legs'**
  String get pushPullLegs;

  /// No description provided for @reAssessmentWeek4.
  ///
  /// In en, this message translates to:
  /// **'Re-assessment · week 4'**
  String get reAssessmentWeek4;

  /// No description provided for @recordABaselineInstead.
  ///
  /// In en, this message translates to:
  /// **'Record a baseline instead'**
  String get recordABaselineInstead;

  /// No description provided for @recorded2September.
  ///
  /// In en, this message translates to:
  /// **'Recorded 2 September'**
  String get recorded2September;

  /// No description provided for @rightKneeSoreOnStairsSinceMarch.
  ///
  /// In en, this message translates to:
  /// **'Right knee, sore on stairs since March'**
  String get rightKneeSoreOnStairsSinceMarch;

  /// No description provided for @saraWillPlanAroundTheFamilyPot.
  ///
  /// In en, this message translates to:
  /// **'Sara will plan around the family pot.'**
  String get saraWillPlanAroundTheFamilyPot;

  /// No description provided for @saveAndAdjustHerPlan.
  ///
  /// In en, this message translates to:
  /// **'Save and adjust her plan'**
  String get saveAndAdjustHerPlan;

  /// No description provided for @saveAndApply.
  ///
  /// In en, this message translates to:
  /// **'Save and apply'**
  String get saveAndApply;

  /// No description provided for @saveAsASplit.
  ///
  /// In en, this message translates to:
  /// **'Save as a split'**
  String get saveAsASplit;

  /// No description provided for @saveAssessment.
  ///
  /// In en, this message translates to:
  /// **'Save assessment'**
  String get saveAssessment;

  /// No description provided for @saveOnly.
  ///
  /// In en, this message translates to:
  /// **'Save only'**
  String get saveOnly;

  /// No description provided for @saveThisSplit.
  ///
  /// In en, this message translates to:
  /// **'Save this split'**
  String get saveThisSplit;

  /// No description provided for @saveToMedia.
  ///
  /// In en, this message translates to:
  /// **'Save to media'**
  String get saveToMedia;

  /// No description provided for @session20.
  ///
  /// In en, this message translates to:
  /// **'Session 20'**
  String get session20;

  /// No description provided for @sheIsSeeingAPhysiotherapistLoadedJumping.
  ///
  /// In en, this message translates to:
  /// **'She is seeing a physiotherapist. Loaded jumping stays off her plan.'**
  String get sheIsSeeingAPhysiotherapistLoadedJumping;

  /// No description provided for @shownOnYourPageAsSpotsLeft.
  ///
  /// In en, this message translates to:
  /// **'Shown on your page as spots left.'**
  String get shownOnYourPageAsSpotsLeft;

  /// No description provided for @someoneElseCooksAtHome.
  ///
  /// In en, this message translates to:
  /// **'Someone else cooks at home'**
  String get someoneElseCooksAtHome;

  /// No description provided for @stage.
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get stage;

  /// No description provided for @step2Of3.
  ///
  /// In en, this message translates to:
  /// **'Step 2 of 3'**
  String get step2Of3;

  /// No description provided for @tenSecondsEachSide.
  ///
  /// In en, this message translates to:
  /// **'Ten seconds each side'**
  String get tenSecondsEachSide;

  /// No description provided for @theseWriteStraightOntoHerPlanSo.
  ///
  /// In en, this message translates to:
  /// **'These write straight onto her plan, so a session can never prescribe them.'**
  String get theseWriteStraightOntoHerPlanSo;

  /// No description provided for @thisIsTheOnlyPlaceYourAllergies.
  ///
  /// In en, this message translates to:
  /// **'This is the only place your allergies come from. Sara sees them while she writes every meal.'**
  String get thisIsTheOnlyPlaceYourAllergies;

  /// No description provided for @timeYouHaveToCook.
  ///
  /// In en, this message translates to:
  /// **'Time you have to cook'**
  String get timeYouHaveToCook;

  /// No description provided for @twiceAWeek.
  ///
  /// In en, this message translates to:
  /// **'Twice a week'**
  String get twiceAWeek;

  /// No description provided for @vaginal.
  ///
  /// In en, this message translates to:
  /// **'Vaginal'**
  String get vaginal;

  /// No description provided for @vegetarianOnWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Vegetarian on weekdays'**
  String get vegetarianOnWeekdays;

  /// No description provided for @whatToAvoid.
  ///
  /// In en, this message translates to:
  /// **'What to avoid'**
  String get whatToAvoid;

  /// No description provided for @youKeep80.
  ///
  /// In en, this message translates to:
  /// **'You keep 80%'**
  String get youKeep80;

  /// No description provided for @youWillWriteYourOffersWhenYou.
  ///
  /// In en, this message translates to:
  /// **'You will write your offers when you design your page: what each one is called, what is in it and what it costs.'**
  String get youWillWriteYourOffersWhenYou;

  /// No description provided for @yourFood.
  ///
  /// In en, this message translates to:
  /// **'Your food'**
  String get yourFood;

  /// No description provided for @yourPricesLiveOnYourPageWhere.
  ///
  /// In en, this message translates to:
  /// **'Your prices live on your page, where you write them in your own words.'**
  String get yourPricesLiveOnYourPageWhere;

  /// No description provided for @whatARestWeekCovers.
  ///
  /// In en, this message translates to:
  /// **'What a rest week covers'**
  String get whatARestWeekCovers;

  /// No description provided for @aMissedWeekRepairedWithoutAsking.
  ///
  /// In en, this message translates to:
  /// **'A missed week, repaired without asking'**
  String get aMissedWeekRepairedWithoutAsking;

  /// No description provided for @ifATierSlips.
  ///
  /// In en, this message translates to:
  /// **'If a tier slips'**
  String get ifATierSlips;

  /// No description provided for @oneCountedWeekBringsItBack.
  ///
  /// In en, this message translates to:
  /// **'One counted week brings it back'**
  String get oneCountedWeekBringsItBack;

  /// No description provided for @n0Egp.
  ///
  /// In en, this message translates to:
  /// **'0 EGP'**
  String get n0Egp;

  /// No description provided for @n0Of20.
  ///
  /// In en, this message translates to:
  /// **'0 of 20'**
  String get n0Of20;

  /// No description provided for @n4210WomenNobodyOverAYear.
  ///
  /// In en, this message translates to:
  /// **'4,210 women · nobody over a year in'**
  String get n4210WomenNobodyOverAYear;

  /// No description provided for @n4210WomenInTheBeginnersGroup.
  ///
  /// In en, this message translates to:
  /// **'4,210 women in the beginners group'**
  String get n4210WomenInTheBeginnersGroup;

  /// No description provided for @aCover.
  ///
  /// In en, this message translates to:
  /// **'A cover'**
  String get aCover;

  /// No description provided for @acceptingAClientTakesOneOfYour.
  ///
  /// In en, this message translates to:
  /// **'Accepting a client takes one of your 20 places. She pays only once you accept.'**
  String get acceptingAClientTakesOneOfYour;

  /// No description provided for @addAMealYouAlwaysPrescribe.
  ///
  /// In en, this message translates to:
  /// **'Add a meal you always prescribe'**
  String get addAMealYouAlwaysPrescribe;

  /// No description provided for @breakfast290Kcal.
  ///
  /// In en, this message translates to:
  /// **'Breakfast · 290 kcal'**
  String get breakfast290Kcal;

  /// No description provided for @breakfast410Kcal22GProtein.
  ///
  /// In en, this message translates to:
  /// **'Breakfast · 410 kcal · 22 g protein'**
  String get breakfast410Kcal22GProtein;

  /// No description provided for @browseAll12Sections.
  ///
  /// In en, this message translates to:
  /// **'Browse all 12 sections'**
  String get browseAll12Sections;

  /// No description provided for @clientsDecideFromIt3SectionsSo.
  ///
  /// In en, this message translates to:
  /// **'Clients decide from it · 3 sections so far'**
  String get clientsDecideFromIt3SectionsSo;

  /// No description provided for @everyWomanYouWillSeeHerePassed.
  ///
  /// In en, this message translates to:
  /// **'Every woman you will see here passed the same check.'**
  String get everyWomanYouWillSeeHerePassed;

  /// No description provided for @facesArriveBlurredUnlessYouTurnThat.
  ///
  /// In en, this message translates to:
  /// **'Faces arrive blurred unless you turn that off yourself, and nothing you post leaves the room.'**
  String get facesArriveBlurredUnlessYouTurnThat;

  /// No description provided for @finishYourPage.
  ///
  /// In en, this message translates to:
  /// **'Finish your page'**
  String get finishYourPage;

  /// No description provided for @fourMovesOnTheFloorNothingJumps.
  ///
  /// In en, this message translates to:
  /// **'Four moves on the floor. Nothing jumps, nothing needs the neighbours out.'**
  String get fourMovesOnTheFloorNothingJumps;

  /// No description provided for @groupsForSomeoneStartingOut.
  ///
  /// In en, this message translates to:
  /// **'Groups for someone starting out'**
  String get groupsForSomeoneStartingOut;

  /// No description provided for @howYouWork.
  ///
  /// In en, this message translates to:
  /// **'How you work'**
  String get howYouWork;

  /// No description provided for @iWillStartTomorrow.
  ///
  /// In en, this message translates to:
  /// **'I will start tomorrow'**
  String get iWillStartTomorrow;

  /// No description provided for @itFillsWithTheGroupsYouJoin.
  ///
  /// In en, this message translates to:
  /// **'It fills with the groups you join, never a public timeline. Join one and its posts appear here.'**
  String get itFillsWithTheGroupsYouJoin;

  /// No description provided for @itIsLiveFor1204Women.
  ///
  /// In en, this message translates to:
  /// **'It is live for 1,204 women a month once published.'**
  String get itIsLiveFor1204Women;

  /// No description provided for @itWaitsInYourOwnCollection.
  ///
  /// In en, this message translates to:
  /// **'It waits in your own collection'**
  String get itWaitsInYourOwnCollection;

  /// No description provided for @addSomethingTwiceAndItBecomesA.
  ///
  /// In en, this message translates to:
  /// **'Add something twice and it becomes a one-tap plate here, in the size you actually serve, not in grams.'**
  String get addSomethingTwiceAndItBecomesA;

  /// No description provided for @lunch540Kcal18GProtein.
  ///
  /// In en, this message translates to:
  /// **'Lunch · 540 kcal · 18 g protein'**
  String get lunch540Kcal18GProtein;

  /// No description provided for @mondayTuesdayThursday15Min.
  ///
  /// In en, this message translates to:
  /// **'Monday, Tuesday, Thursday · 15 min'**
  String get mondayTuesdayThursday15Min;

  /// No description provided for @mostCoachesStartWithTheseThree.
  ///
  /// In en, this message translates to:
  /// **'Most coaches start with these three'**
  String get mostCoachesStartWithTheseThree;

  /// No description provided for @noClientsYet.
  ///
  /// In en, this message translates to:
  /// **'No clients yet'**
  String get noClientsYet;

  /// No description provided for @noCountdownNoRedNumbersProteinIs.
  ///
  /// In en, this message translates to:
  /// **'No countdown, no red numbers. Protein is the only target, and it is a bar that fills.'**
  String get noCountdownNoRedNumbersProteinIs;

  /// No description provided for @noPlatesYet.
  ///
  /// In en, this message translates to:
  /// **'No plates yet'**
  String get noPlatesYet;

  /// No description provided for @nobodyThereHasBeenTrainingOverA.
  ///
  /// In en, this message translates to:
  /// **'Nobody there has been training over a year'**
  String get nobodyThereHasBeenTrainingOverA;

  /// No description provided for @nobodyYet.
  ///
  /// In en, this message translates to:
  /// **'Nobody yet'**
  String get nobodyYet;

  /// No description provided for @notATemplateWithYourNameDropped.
  ///
  /// In en, this message translates to:
  /// **'Not a template with your name dropped in. A stack of sections you choose and order yourself.'**
  String get notATemplateWithYourNameDropped;

  /// No description provided for @nothingHereIsDecidedForYouTwo.
  ///
  /// In en, this message translates to:
  /// **'Nothing here is decided for you. Two coaches on this platform should not look alike.'**
  String get nothingHereIsDecidedForYouTwo;

  /// No description provided for @nothingAddedYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing added yet'**
  String get nothingAddedYet;

  /// No description provided for @nothingSavedYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing saved yet'**
  String get nothingSavedYet;

  /// No description provided for @oneMealIsEnoughToStartThe.
  ///
  /// In en, this message translates to:
  /// **'One meal is enough to start the guessing'**
  String get oneMealIsEnoughToStartThe;

  /// No description provided for @oneOffer.
  ///
  /// In en, this message translates to:
  /// **'One offer'**
  String get oneOffer;

  /// No description provided for @onePhotoOneSentenceAboutWhatYou.
  ///
  /// In en, this message translates to:
  /// **'One photo, one sentence about what you do'**
  String get onePhotoOneSentenceAboutWhatYou;

  /// No description provided for @orStartFromOneOfThese.
  ///
  /// In en, this message translates to:
  /// **'Or start from one of these'**
  String get orStartFromOneOfThese;

  /// No description provided for @readyForWhenSheArrives.
  ///
  /// In en, this message translates to:
  /// **'Ready for when she arrives'**
  String get readyForWhenSheArrives;

  /// No description provided for @runsBeforeHerFirstWeek.
  ///
  /// In en, this message translates to:
  /// **'Runs before her first week'**
  String get runsBeforeHerFirstWeek;

  /// No description provided for @saveASplit.
  ///
  /// In en, this message translates to:
  /// **'Save a split'**
  String get saveASplit;

  /// No description provided for @startDay1.
  ///
  /// In en, this message translates to:
  /// **'Start day 1'**
  String get startDay1;

  /// No description provided for @startWithACover.
  ///
  /// In en, this message translates to:
  /// **'Start with a cover'**
  String get startWithACover;

  /// No description provided for @tellUsOneThingYouEat.
  ///
  /// In en, this message translates to:
  /// **'Tell us one thing you eat'**
  String get tellUsOneThingYouEat;

  /// No description provided for @threeSessionsMakesTheWeekCountMiss.
  ///
  /// In en, this message translates to:
  /// **'Three sessions makes the week count. Miss one and a rest week covers it, once you have earned one.'**
  String get threeSessionsMakesTheWeekCountMiss;

  /// No description provided for @todaysSessionAndTheMealYouUsually.
  ///
  /// In en, this message translates to:
  /// **'Today\'s session and the meal you usually eat at this hour will sit here. Add one thing and it starts filling itself in.'**
  String get todaysSessionAndTheMealYouUsually;

  /// No description provided for @usuallyTheSameDayYouCanBuild.
  ///
  /// In en, this message translates to:
  /// **'Usually the same day. You can build everything else now.'**
  String get usuallyTheSameDayYouCanBuild;

  /// No description provided for @weAreCheckingYourCertificates.
  ///
  /// In en, this message translates to:
  /// **'We are checking your certificates'**
  String get weAreCheckingYourCertificates;

  /// No description provided for @whatItIsCalledWhatIsIn.
  ///
  /// In en, this message translates to:
  /// **'What it is called, what is in it, what it costs'**
  String get whatItIsCalledWhatIsIn;

  /// No description provided for @whenAWomanAsksToWorkWith.
  ///
  /// In en, this message translates to:
  /// **'When a woman asks to work with you she lands here, with what she wants and her own words. Your page is what brings her.'**
  String get whenAWomanAsksToWorkWith;

  /// No description provided for @womenWhoAskToWorkWithYou.
  ///
  /// In en, this message translates to:
  /// **'Women who ask to work with you appear here, the longest-waiting first, so you never have to hunt for who needs a reply.'**
  String get womenWhoAskToWorkWithYou;

  /// No description provided for @workOnMyPage.
  ///
  /// In en, this message translates to:
  /// **'Work on my page'**
  String get workOnMyPage;

  /// No description provided for @worthDoingBeforeYourFirstClient.
  ///
  /// In en, this message translates to:
  /// **'Worth doing before your first client'**
  String get worthDoingBeforeYourFirstClient;

  /// No description provided for @writeYourWeekOnceUseItOn.
  ///
  /// In en, this message translates to:
  /// **'Write your week once, use it on everyone'**
  String get writeYourWeekOnceUseItOn;

  /// No description provided for @youAreVerifiedTheRoomIsOpen.
  ///
  /// In en, this message translates to:
  /// **'You are verified · the room is open'**
  String get youAreVerifiedTheRoomIsOpen;

  /// No description provided for @youKeep80TheFirstPayoutLands.
  ///
  /// In en, this message translates to:
  /// **'You keep 80%. The first payout lands on the 1st of the month after your first client pays.'**
  String get youKeep80TheFirstPayoutLands;

  /// No description provided for @yourFeedIsEmptyOnPurpose.
  ///
  /// In en, this message translates to:
  /// **'Your feed is empty on purpose'**
  String get yourFeedIsEmptyOnPurpose;

  /// No description provided for @yourMethodInTheWordsYouAlready.
  ///
  /// In en, this message translates to:
  /// **'Your method, in the words you already use'**
  String get yourMethodInTheWordsYouAlready;

  /// No description provided for @yourPageIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your page is empty'**
  String get yourPageIsEmpty;

  /// No description provided for @yourPageIsHowTheyFindYou.
  ///
  /// In en, this message translates to:
  /// **'Your page is how they find you'**
  String get yourPageIsHowTheyFindYou;

  /// No description provided for @threeSessionsMakesTheWeekCountAnd.
  ///
  /// In en, this message translates to:
  /// **'Three sessions makes the week count, and a rest week covers one you miss.'**
  String get threeSessionsMakesTheWeekCountAnd;

  /// No description provided for @facesArriveBlurredAndNothingHereLeaves.
  ///
  /// In en, this message translates to:
  /// **'Faces arrive blurred, and nothing here leaves the room.'**
  String get facesArriveBlurredAndNothingHereLeaves;

  /// No description provided for @whenAWomanAsksToWorkWith_1j1kf.
  ///
  /// In en, this message translates to:
  /// **'When a woman asks to work with you she lands here, in her own words. Your page is what brings her.'**
  String get whenAWomanAsksToWorkWith_1j1kf;

  /// No description provided for @youKeep80FirstPayoutTheMonth.
  ///
  /// In en, this message translates to:
  /// **'You keep 80%. First payout the month after your first client pays.'**
  String get youKeep80FirstPayoutTheMonth;

  /// No description provided for @whenAWomanAsksToWorkWith_4vp4g.
  ///
  /// In en, this message translates to:
  /// **'When a woman asks to work with you she lands here, in her own words.'**
  String get whenAWomanAsksToWorkWith_4vp4g;

  /// No description provided for @youKeep80OfWhatShePays.
  ///
  /// In en, this message translates to:
  /// **'You keep 80% of what she pays.'**
  String get youKeep80OfWhatShePays;

  /// No description provided for @yourFirstWeek.
  ///
  /// In en, this message translates to:
  /// **'Your first week'**
  String get yourFirstWeek;

  /// No description provided for @assistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get assistant;

  /// No description provided for @discardTheDraft.
  ///
  /// In en, this message translates to:
  /// **'Discard the draft'**
  String get discardTheDraft;

  /// No description provided for @n124MoveLibrary.
  ///
  /// In en, this message translates to:
  /// **'124-move library'**
  String get n124MoveLibrary;

  /// No description provided for @n15MinutesFiveMoves.
  ///
  /// In en, this message translates to:
  /// **'15 minutes, five moves'**
  String get n15MinutesFiveMoves;

  /// No description provided for @n2Of4Done.
  ///
  /// In en, this message translates to:
  /// **'2 of 4 done'**
  String get n2Of4Done;

  /// No description provided for @n2Of5DoneNothingExpires.
  ///
  /// In en, this message translates to:
  /// **'2 of 5 done · nothing expires'**
  String get n2Of5DoneNothingExpires;

  /// No description provided for @n310LessDepth.
  ///
  /// In en, this message translates to:
  /// **'3 × 10 · less depth'**
  String get n310LessDepth;

  /// No description provided for @n312NothingOnTheKnee.
  ///
  /// In en, this message translates to:
  /// **'3 × 12 · nothing on the knee'**
  String get n312NothingOnTheKnee;

  /// No description provided for @n3Of3ItCounted.
  ///
  /// In en, this message translates to:
  /// **'3 of 3 · it counted'**
  String get n3Of3ItCounted;

  /// No description provided for @n3018Sessions8Rest.
  ///
  /// In en, this message translates to:
  /// **'30 · 18 sessions, 8 rest'**
  String get n3018Sessions8Rest;

  /// No description provided for @n35PointsSoFar.
  ///
  /// In en, this message translates to:
  /// **'35 points so far'**
  String get n35PointsSoFar;

  /// No description provided for @n7Days.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get n7Days;

  /// No description provided for @addAFollowUpPicture.
  ///
  /// In en, this message translates to:
  /// **'Add a follow-up picture'**
  String get addAFollowUpPicture;

  /// No description provided for @allFiveDone.
  ///
  /// In en, this message translates to:
  /// **'All five done'**
  String get allFiveDone;

  /// No description provided for @allFiveDoneNothingAboutTheApp.
  ///
  /// In en, this message translates to:
  /// **'All five done. Nothing about the app changes from here. You have just already used every part of it once.'**
  String get allFiveDoneNothingAboutTheApp;

  /// No description provided for @allFromYour124MoveLibrary.
  ///
  /// In en, this message translates to:
  /// **'All from your 124-move library'**
  String get allFromYour124MoveLibrary;

  /// No description provided for @answerYourFirstEnquiry.
  ///
  /// In en, this message translates to:
  /// **'Answer your first enquiry'**
  String get answerYourFirstEnquiry;

  /// No description provided for @askSaraInstead.
  ///
  /// In en, this message translates to:
  /// **'Ask Sara instead'**
  String get askSaraInstead;

  /// No description provided for @askSomething.
  ///
  /// In en, this message translates to:
  /// **'Ask something'**
  String get askSomething;

  /// No description provided for @askOrHoldToTalk.
  ///
  /// In en, this message translates to:
  /// **'Ask, or hold to talk'**
  String get askOrHoldToTalk;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @beginnersPostpartumOrYourCity.
  ///
  /// In en, this message translates to:
  /// **'Beginners, postpartum or your city'**
  String get beginnersPostpartumOrYourCity;

  /// No description provided for @bleedingBetweenPeriodsWithSharpPainShould.
  ///
  /// In en, this message translates to:
  /// **'Bleeding between periods with sharp pain should be looked at by a clinician.'**
  String get bleedingBetweenPeriodsWithSharpPainShould;

  /// No description provided for @certificatesClearedThisMorning.
  ///
  /// In en, this message translates to:
  /// **'Certificates cleared this morning'**
  String get certificatesClearedThisMorning;

  /// No description provided for @changeYourPlanOnlySaraPublishingDoes.
  ///
  /// In en, this message translates to:
  /// **'Change your plan · only Sara publishing does that'**
  String get changeYourPlanOnlySaraPublishingDoes;

  /// No description provided for @cost46Egp.
  ///
  /// In en, this message translates to:
  /// **'Cost 46 EGP'**
  String get cost46Egp;

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get days;

  /// No description provided for @diagnoseAnythingOrAnswerAMedicalQuestion.
  ///
  /// In en, this message translates to:
  /// **'Diagnose anything, or answer a medical question'**
  String get diagnoseAnythingOrAnswerAMedicalQuestion;

  /// No description provided for @draftNour.
  ///
  /// In en, this message translates to:
  /// **'Draft · Nour'**
  String get draftNour;

  /// No description provided for @draftAWeek.
  ///
  /// In en, this message translates to:
  /// **'Draft a week'**
  String get draftAWeek;

  /// No description provided for @draftItForMe.
  ///
  /// In en, this message translates to:
  /// **'Draft it for me'**
  String get draftItForMe;

  /// No description provided for @draftedFromWhatYouAlreadyWrote.
  ///
  /// In en, this message translates to:
  /// **'Drafted from what you already wrote'**
  String get draftedFromWhatYouAlreadyWrote;

  /// No description provided for @eachOneIsWorkAClientWill.
  ///
  /// In en, this message translates to:
  /// **'Each one is work a client will actually see. None of it is a tour.'**
  String get eachOneIsWorkAClientWill;

  /// No description provided for @everyNumberCameFromTheFoodLibrary.
  ///
  /// In en, this message translates to:
  /// **'Every number came from the food library'**
  String get everyNumberCameFromTheFoodLibrary;

  /// No description provided for @explainARuleWhyAWeekCounted.
  ///
  /// In en, this message translates to:
  /// **'Explain a rule: why a week counted, what a rest week covers'**
  String get explainARuleWhyAWeekCounted;

  /// No description provided for @findAMoveForYourEquipmentAnd.
  ///
  /// In en, this message translates to:
  /// **'Find a move for your equipment and your knee'**
  String get findAMoveForYourEquipmentAnd;

  /// No description provided for @finishOneSession.
  ///
  /// In en, this message translates to:
  /// **'Finish one session'**
  String get finishOneSession;

  /// No description provided for @finishingAllFiveIsNotADeadline.
  ///
  /// In en, this message translates to:
  /// **'Finishing all five is not a deadline. It is the shortest path to knowing where everything is.'**
  String get finishingAllFiveIsNotADeadline;

  /// No description provided for @fulWithOilAndCumin410Kcal.
  ///
  /// In en, this message translates to:
  /// **'Ful with oil and cumin · 410 kcal'**
  String get fulWithOilAndCumin410Kcal;

  /// No description provided for @herAvoidListWasAppliedFirstDeep.
  ///
  /// In en, this message translates to:
  /// **'Her avoid list was applied first: deep knee bends and high impact never appear.'**
  String get herAvoidListWasAppliedFirstDeep;

  /// No description provided for @herOwnPlatesAreUsedFirstBecause.
  ///
  /// In en, this message translates to:
  /// **'Her own plates are used first, because a meal plan she has never cooked is one she will not follow.'**
  String get herOwnPlatesAreUsedFirstBecause;

  /// No description provided for @iAmNotAbleToAnswerThat.
  ///
  /// In en, this message translates to:
  /// **'I am not able to answer that one. It is a medical question, and guessing at it would not be safe.'**
  String get iAmNotAbleToAnswerThat;

  /// No description provided for @iHaveSharpPainLowDownAnd.
  ///
  /// In en, this message translates to:
  /// **'I have sharp pain low down and bleeding between periods. Is that normal?'**
  String get iHaveSharpPainLowDownAnd;

  /// No description provided for @inventAMealOrAQuantityEvery.
  ///
  /// In en, this message translates to:
  /// **'Invent a meal or a quantity: every gram comes from the food library'**
  String get inventAMealOrAQuantityEvery;

  /// No description provided for @itCan.
  ///
  /// In en, this message translates to:
  /// **'It can'**
  String get itCan;

  /// No description provided for @itCannot.
  ///
  /// In en, this message translates to:
  /// **'It cannot'**
  String get itCannot;

  /// No description provided for @itCoversAWeekYouMissWithout.
  ///
  /// In en, this message translates to:
  /// **'It covers a week you miss, without being asked.'**
  String get itCoversAWeekYouMissWithout;

  /// No description provided for @itRefusesRatherThanHedgingAFitness.
  ///
  /// In en, this message translates to:
  /// **'It refuses rather than hedging. A fitness assistant that answers medical questions is the one thing this product will not ship.'**
  String get itRefusesRatherThanHedgingAFitness;

  /// No description provided for @itRunsBeforeAnyonesFirstWeek.
  ///
  /// In en, this message translates to:
  /// **'It runs before anyone’s first week'**
  String get itRunsBeforeAnyonesFirstWeek;

  /// No description provided for @joinOneGroup.
  ///
  /// In en, this message translates to:
  /// **'Join one group'**
  String get joinOneGroup;

  /// No description provided for @kneeNoDeepBends.
  ///
  /// In en, this message translates to:
  /// **'Knee · no deep bends'**
  String get kneeNoDeepBends;

  /// No description provided for @koshariBowlMedium540Kcal.
  ///
  /// In en, this message translates to:
  /// **'Koshari bowl, medium · 540 kcal'**
  String get koshariBowlMedium540Kcal;

  /// No description provided for @lentilSoupAndEggs380Kcal.
  ///
  /// In en, this message translates to:
  /// **'Lentil soup and eggs · 380 kcal'**
  String get lentilSoupAndEggs380Kcal;

  /// No description provided for @level.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get level;

  /// No description provided for @liveFor1204WomenAMonth.
  ///
  /// In en, this message translates to:
  /// **'Live for 1,204 women a month'**
  String get liveFor1204WomenAMonth;

  /// No description provided for @addOneMealYouAte.
  ///
  /// In en, this message translates to:
  /// **'Add one meal you ate'**
  String get addOneMealYouAte;

  /// No description provided for @finishOneSet.
  ///
  /// In en, this message translates to:
  /// **'Finish one set'**
  String get finishOneSet;

  /// No description provided for @lowerBodyBoxSquatNotGoblet.
  ///
  /// In en, this message translates to:
  /// **'Lower body · box squat, not goblet'**
  String get lowerBodyBoxSquatNotGoblet;

  /// No description provided for @mealDraftNour.
  ///
  /// In en, this message translates to:
  /// **'Meal draft · Nour'**
  String get mealDraftNour;

  /// No description provided for @moves.
  ///
  /// In en, this message translates to:
  /// **'Moves'**
  String get moves;

  /// No description provided for @myKneeHurtsOnTheSquatsToday.
  ///
  /// In en, this message translates to:
  /// **'My knee hurts on the squats today'**
  String get myKneeHurtsOnTheSquatsToday;

  /// No description provided for @noNutsVegetarianOnWeekdaysAppliedBefore.
  ///
  /// In en, this message translates to:
  /// **'No nuts. Vegetarian on weekdays. Applied before anything was chosen.'**
  String get noNutsVegetarianOnWeekdaysAppliedBefore;

  /// No description provided for @noTimerOnAnyOfThemMiss.
  ///
  /// In en, this message translates to:
  /// **'No timer on any of them. Miss a day and nothing here changes.'**
  String get noTimerOnAnyOfThemMiss;

  /// No description provided for @nothingHereExpiresAndNoClientSees.
  ///
  /// In en, this message translates to:
  /// **'Nothing here expires, and no client sees your progress through it.'**
  String get nothingHereExpiresAndNoClientSees;

  /// No description provided for @nothingIsPublishedThisOpensAsA.
  ///
  /// In en, this message translates to:
  /// **'Nothing is published. This opens as a draft in your planner, and you decide what she sees.'**
  String get nothingIsPublishedThisOpensAsA;

  /// No description provided for @nothingWasCalculatedADishWithoutVerified.
  ///
  /// In en, this message translates to:
  /// **'Nothing was calculated. A dish without verified values is offered without totals, never with invented ones.'**
  String get nothingWasCalculatedADishWithoutVerified;

  /// No description provided for @nothingWasSavedAndNothingWasShared.
  ///
  /// In en, this message translates to:
  /// **'Nothing was saved and nothing was shared. Your cycle information is not visible to me unless you turn that on.'**
  String get nothingWasSavedAndNothingWasShared;

  /// No description provided for @of4.
  ///
  /// In en, this message translates to:
  /// **'of 4'**
  String get of4;

  /// No description provided for @of5.
  ///
  /// In en, this message translates to:
  /// **'of 5'**
  String get of5;

  /// No description provided for @onceYouHaveAPostToFollow.
  ///
  /// In en, this message translates to:
  /// **'Once you have a post to follow up on'**
  String get onceYouHaveAPostToFollow;

  /// No description provided for @openInMyPlanner.
  ///
  /// In en, this message translates to:
  /// **'Open in my planner'**
  String get openInMyPlanner;

  /// No description provided for @openInTheMealPlanner.
  ///
  /// In en, this message translates to:
  /// **'Open in the meal planner'**
  String get openInTheMealPlanner;

  /// No description provided for @points.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get points;

  /// No description provided for @protein92G.
  ///
  /// In en, this message translates to:
  /// **'Protein 92 g'**
  String get protein92G;

  /// No description provided for @publishYourPage.
  ///
  /// In en, this message translates to:
  /// **'Publish your page'**
  String get publishYourPage;

  /// No description provided for @saveOneSplit.
  ///
  /// In en, this message translates to:
  /// **'Save one split'**
  String get saveOneSplit;

  /// No description provided for @seeYourCycleInformationUnlessYouShare.
  ///
  /// In en, this message translates to:
  /// **'See your cycle information unless you share it'**
  String get seeYourCycleInformationUnlessYouShare;

  /// No description provided for @seeYourProgress.
  ///
  /// In en, this message translates to:
  /// **'See your progress'**
  String get seeYourProgress;

  /// No description provided for @setUpAnAssessment.
  ///
  /// In en, this message translates to:
  /// **'Set up an assessment'**
  String get setUpAnAssessment;

  /// No description provided for @setUpTheAssessment.
  ///
  /// In en, this message translates to:
  /// **'Set up the assessment'**
  String get setUpTheAssessment;

  /// No description provided for @sharpOrNewPain.
  ///
  /// In en, this message translates to:
  /// **'Sharp or new pain?'**
  String get sharpOrNewPain;

  /// No description provided for @shePaysOnlyOnceYouAccept.
  ///
  /// In en, this message translates to:
  /// **'She pays only once you accept'**
  String get shePaysOnlyOnceYouAccept;

  /// No description provided for @someQuestionsItWillNotAnswerAnd.
  ///
  /// In en, this message translates to:
  /// **'Some questions it will not answer, and should not'**
  String get someQuestionsItWillNotAnswerAnd;

  /// No description provided for @split.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get split;

  /// No description provided for @swapTodaysExerciseForAnApprovedAlternative.
  ///
  /// In en, this message translates to:
  /// **'Swap today’s exercise for an approved alternative'**
  String get swapTodaysExerciseForAnApprovedAlternative;

  /// No description provided for @swappingChangesTodayOnlyYourPlanFrom.
  ///
  /// In en, this message translates to:
  /// **'Swapping changes today only. Your plan from Sara is untouched.'**
  String get swappingChangesTodayOnlyYourPlanFrom;

  /// No description provided for @tellYouThePortionOfADish.
  ///
  /// In en, this message translates to:
  /// **'Tell you the portion of a dish you already eat'**
  String get tellYouThePortionOfADish;

  /// No description provided for @theSamePointsTheRestOfThe.
  ///
  /// In en, this message translates to:
  /// **'The same points the rest of the app gives. Nothing extra for opening it.'**
  String get theSamePointsTheRestOfThe;

  /// No description provided for @thisNeedsADoctorNotAnApp.
  ///
  /// In en, this message translates to:
  /// **'This needs a doctor, not an app'**
  String get thisNeedsADoctorNotAnApp;

  /// No description provided for @twoDone.
  ///
  /// In en, this message translates to:
  /// **'Two done'**
  String get twoDone;

  /// No description provided for @twoDoneThreeWaiting.
  ///
  /// In en, this message translates to:
  /// **'Two done, three waiting'**
  String get twoDoneThreeWaiting;

  /// No description provided for @twoMovesInYourSessionWorkThe.
  ///
  /// In en, this message translates to:
  /// **'Two moves in your session work the same muscles without loading the knee. Both are already approved by Sara.'**
  String get twoMovesInYourSessionWorkThe;

  /// No description provided for @upperLowerOn3Clients.
  ///
  /// In en, this message translates to:
  /// **'Upper / lower · on 3 clients'**
  String get upperLowerOn3Clients;

  /// No description provided for @upperLower4Days.
  ///
  /// In en, this message translates to:
  /// **'Upper / lower · 4 days'**
  String get upperLower4Days;

  /// No description provided for @whatIDidWithThatMessage.
  ///
  /// In en, this message translates to:
  /// **'What I did with that message'**
  String get whatIDidWithThatMessage;

  /// No description provided for @whatItAddedUpTo.
  ///
  /// In en, this message translates to:
  /// **'What it added up to'**
  String get whatItAddedUpTo;

  /// No description provided for @whatItCanAndCannotDo.
  ///
  /// In en, this message translates to:
  /// **'What it can and cannot do'**
  String get whatItCanAndCannotDo;

  /// No description provided for @whatLeavesYourPhone.
  ///
  /// In en, this message translates to:
  /// **'What leaves your phone'**
  String get whatLeavesYourPhone;

  /// No description provided for @youDidFulAndBaladi.
  ///
  /// In en, this message translates to:
  /// **'You did · ful and baladi'**
  String get youDidFulAndBaladi;

  /// No description provided for @youDidGobletSquat12Kg.
  ///
  /// In en, this message translates to:
  /// **'You did · goblet squat, 12 kg'**
  String get youDidGobletSquat12Kg;

  /// No description provided for @youKnowYourWayAround.
  ///
  /// In en, this message translates to:
  /// **'You know your way around'**
  String get youKnowYourWayAround;

  /// No description provided for @yourFirstRestWeekIsBanked.
  ///
  /// In en, this message translates to:
  /// **'Your first rest week is banked'**
  String get yourFirstRestWeekIsBanked;

  /// No description provided for @yourPageIsVisibleAndYouCan.
  ///
  /// In en, this message translates to:
  /// **'Your page is visible and you can take clients.'**
  String get yourPageIsVisibleAndYouCan;

  /// No description provided for @yourQuestionYourEquipmentAndWhatYou.
  ///
  /// In en, this message translates to:
  /// **'Your question, your equipment and what you are avoiding. Never your name, your photos, your weight or your ID.'**
  String get yourQuestionYourEquipmentAndWhatYou;

  /// No description provided for @savedOnYourPhone.
  ///
  /// In en, this message translates to:
  /// **'Saved on your phone'**
  String get savedOnYourPhone;

  /// No description provided for @waitingForSignal.
  ///
  /// In en, this message translates to:
  /// **'Waiting for signal'**
  String get waitingForSignal;

  /// No description provided for @savedHereUntilYouHaveSignal.
  ///
  /// In en, this message translates to:
  /// **'Saved here until you have signal'**
  String get savedHereUntilYouHaveSignal;

  /// No description provided for @savedItWillSyncWhenYouHave.
  ///
  /// In en, this message translates to:
  /// **'Saved. It will sync when you have signal.'**
  String get savedItWillSyncWhenYouHave;

  /// No description provided for @youAreOfflineEverythingYouAddIs.
  ///
  /// In en, this message translates to:
  /// **'You are offline. Everything you add is saved here and sent when you reconnect.'**
  String get youAreOfflineEverythingYouAddIs;

  /// No description provided for @nothingWasLost.
  ///
  /// In en, this message translates to:
  /// **'Nothing was lost.'**
  String get nothingWasLost;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @thatDidNotSaveTapToTry.
  ///
  /// In en, this message translates to:
  /// **'That did not save. Tap to try again.'**
  String get thatDidNotSaveTapToTry;

  /// No description provided for @somethingWentWrongAtOurEndNothing.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong at our end. Nothing you did caused it.'**
  String get somethingWentWrongAtOurEndNothing;

  /// No description provided for @weCouldNotReachTheServerYour.
  ///
  /// In en, this message translates to:
  /// **'We could not reach the server. Your work is safe on this phone.'**
  String get weCouldNotReachTheServerYour;

  /// No description provided for @thisIsTakingLongerThanUsual.
  ///
  /// In en, this message translates to:
  /// **'This is taking longer than usual.'**
  String get thisIsTakingLongerThanUsual;

  /// No description provided for @thatCodeIsNotRightCheckThe.
  ///
  /// In en, this message translates to:
  /// **'That code is not right. Check the message and try again.'**
  String get thatCodeIsNotRightCheckThe;

  /// No description provided for @thatCodeHasExpiredAskForA.
  ///
  /// In en, this message translates to:
  /// **'That code has expired. Ask for a new one.'**
  String get thatCodeHasExpiredAskForA;

  /// No description provided for @tooManyTriesWaitAMinuteThen.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Wait a minute, then ask for a new code.'**
  String get tooManyTriesWaitAMinuteThen;

  /// No description provided for @checkTheNumberAndTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Check the number and try again.'**
  String get checkTheNumberAndTryAgain;

  /// No description provided for @thatDoesNotLookLikeAnEgyptian.
  ///
  /// In en, this message translates to:
  /// **'That does not look like an Egyptian mobile number.'**
  String get thatDoesNotLookLikeAnEgyptian;

  /// No description provided for @thePhotoDidNotUploadCheckYour.
  ///
  /// In en, this message translates to:
  /// **'The photo did not upload. Check your signal and try again.'**
  String get thePhotoDidNotUploadCheckYour;

  /// No description provided for @weCouldNotReadTheCardHold.
  ///
  /// In en, this message translates to:
  /// **'We could not read the card. Hold it flat and try again.'**
  String get weCouldNotReadTheCardHold;

  /// No description provided for @theCheckCouldNotFinishAWoman.
  ///
  /// In en, this message translates to:
  /// **'The check could not finish. A woman reviewer will take it from here.'**
  String get theCheckCouldNotFinishAWoman;

  /// No description provided for @allowCameraAccess.
  ///
  /// In en, this message translates to:
  /// **'Allow camera access'**
  String get allowCameraAccess;

  /// No description provided for @weNeedYourCameraToReadYour.
  ///
  /// In en, this message translates to:
  /// **'We need your camera to read your ID card. Nothing is uploaded until you tap send.'**
  String get weNeedYourCameraToReadYour;

  /// No description provided for @weNeedTheMicrophoneToHearWhat.
  ///
  /// In en, this message translates to:
  /// **'We need the microphone to hear what you ate.'**
  String get weNeedTheMicrophoneToHearWhat;

  /// No description provided for @turnOnNotificationsSoWeCanTell.
  ///
  /// In en, this message translates to:
  /// **'Turn on notifications so we can tell you when your check is done.'**
  String get turnOnNotificationsSoWeCanTell;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @cameraAccessIsOffYouCanTurn.
  ///
  /// In en, this message translates to:
  /// **'Camera access is off. You can turn it on in settings.'**
  String get cameraAccessIsOffYouCanTurn;

  /// No description provided for @notRightNow.
  ///
  /// In en, this message translates to:
  /// **'Not right now'**
  String get notRightNow;

  /// No description provided for @waitingToSync.
  ///
  /// In en, this message translates to:
  /// **'Waiting to sync'**
  String get waitingToSync;

  /// No description provided for @everythingHereIsSavedOnYourPhone.
  ///
  /// In en, this message translates to:
  /// **'Everything here is saved on your phone already.'**
  String get everythingHereIsSavedOnYourPhone;

  /// No description provided for @youCanKeepGoingItSendsItself.
  ///
  /// In en, this message translates to:
  /// **'You can keep going. It sends itself later.'**
  String get youCanKeepGoingItSendsItself;

  /// No description provided for @walkThisMorning32Min.
  ///
  /// In en, this message translates to:
  /// **'Walk this morning · 32 min'**
  String get walkThisMorning32Min;

  /// No description provided for @n20MinVegetarian.
  ///
  /// In en, this message translates to:
  /// **'20 min · vegetarian'**
  String get n20MinVegetarian;

  /// No description provided for @iTrainAndICoach.
  ///
  /// In en, this message translates to:
  /// **'I train and I coach'**
  String get iTrainAndICoach;

  /// No description provided for @twoAppsInOneSwitchBetweenThem.
  ///
  /// In en, this message translates to:
  /// **'Two apps in one. Switch between them whenever you like.'**
  String get twoAppsInOneSwitchBetweenThem;

  /// No description provided for @youCanChangeThisLaterInYour.
  ///
  /// In en, this message translates to:
  /// **'You can change this later in your profile.'**
  String get youCanChangeThisLaterInYour;

  /// No description provided for @switchApp.
  ///
  /// In en, this message translates to:
  /// **'Switch app'**
  String get switchApp;

  /// No description provided for @youAreATraineeAndACoach.
  ///
  /// In en, this message translates to:
  /// **'You are a trainee and a coach. This switches the whole app, not one tab.'**
  String get youAreATraineeAndACoach;

  /// No description provided for @training.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get training;

  /// No description provided for @switchToCoaching.
  ///
  /// In en, this message translates to:
  /// **'Switch to coaching'**
  String get switchToCoaching;

  /// No description provided for @switchToTraining.
  ///
  /// In en, this message translates to:
  /// **'Switch to training'**
  String get switchToTraining;

  /// No description provided for @yourProfile.
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get yourProfile;

  /// No description provided for @yourIdPhotoAndSelfieHaveBeen.
  ///
  /// In en, this message translates to:
  /// **'Your ID photo and selfie have been deleted. We kept the result and nothing else.'**
  String get yourIdPhotoAndSelfieHaveBeen;

  /// R07 primary button. Names the numbers it is about to save — HER prescription, not the prototype set. The undo bar on R09 then repeats the same numbers, which is the point of rule 9.
  ///
  /// In en, this message translates to:
  /// **'Done · {weight} kg × {reps}'**
  String doneWeightKgReps(String weight, int reps);

  /// No description provided for @contentLibrary.
  ///
  /// In en, this message translates to:
  /// **'Content library'**
  String get contentLibrary;

  /// No description provided for @exercises.
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get exercises;

  /// No description provided for @foods.
  ///
  /// In en, this message translates to:
  /// **'Foods'**
  String get foods;

  /// No description provided for @programmes.
  ///
  /// In en, this message translates to:
  /// **'Programmes'**
  String get programmes;

  /// No description provided for @importLabel.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importLabel;

  /// No description provided for @exportLabel.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportLabel;

  /// No description provided for @addAnExercise.
  ///
  /// In en, this message translates to:
  /// **'Add an exercise'**
  String get addAnExercise;

  /// No description provided for @addAFood.
  ///
  /// In en, this message translates to:
  /// **'Add a food'**
  String get addAFood;

  /// No description provided for @bulkImport.
  ///
  /// In en, this message translates to:
  /// **'Bulk import'**
  String get bulkImport;

  /// No description provided for @chooseACsvFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a CSV file'**
  String get chooseACsvFile;

  /// No description provided for @checkTheFile.
  ///
  /// In en, this message translates to:
  /// **'Check the file'**
  String get checkTheFile;

  /// No description provided for @importCheck.
  ///
  /// In en, this message translates to:
  /// **'Import check'**
  String get importCheck;

  /// No description provided for @nothingHasBeenWrittenYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been written yet.'**
  String get nothingHasBeenWrittenYet;

  /// No description provided for @rowsWithProblems.
  ///
  /// In en, this message translates to:
  /// **'Rows with problems'**
  String get rowsWithProblems;

  /// No description provided for @fixTheseRowsAndImportAgainNothing.
  ///
  /// In en, this message translates to:
  /// **'Fix these rows and import again. Nothing is saved until every row passes.'**
  String get fixTheseRowsAndImportAgainNothing;

  /// No description provided for @importEverything.
  ///
  /// In en, this message translates to:
  /// **'Import everything'**
  String get importEverything;

  /// No description provided for @missingASafetyTag.
  ///
  /// In en, this message translates to:
  /// **'Missing a safety tag'**
  String get missingASafetyTag;

  /// No description provided for @missingAllergens.
  ///
  /// In en, this message translates to:
  /// **'Missing allergens'**
  String get missingAllergens;

  /// No description provided for @missingContraindications.
  ///
  /// In en, this message translates to:
  /// **'Missing contraindications'**
  String get missingContraindications;

  /// No description provided for @writeNoneWhenThereAreNoneBlank.
  ///
  /// In en, this message translates to:
  /// **'Write “none” when there are none. Blank is not the same thing.'**
  String get writeNoneWhenThereAreNoneBlank;

  /// No description provided for @uploadVideosAndPictures.
  ///
  /// In en, this message translates to:
  /// **'Upload videos and pictures'**
  String get uploadVideosAndPictures;

  /// No description provided for @notLinkedToAnythingYet.
  ///
  /// In en, this message translates to:
  /// **'Not linked to anything yet'**
  String get notLinkedToAnythingYet;

  /// No description provided for @exportTheContentLibrary.
  ///
  /// In en, this message translates to:
  /// **'Export the content library'**
  String get exportTheContentLibrary;

  /// No description provided for @csvsAndMediaInTheSameShape.
  ///
  /// In en, this message translates to:
  /// **'CSVs and media, in the same shape you import them.'**
  String get csvsAndMediaInTheSameShape;

  /// No description provided for @noMemberDataIsEverIncludedNo.
  ///
  /// In en, this message translates to:
  /// **'No member data is ever included: no meals or workouts, no photos, no cycle.'**
  String get noMemberDataIsEverIncludedNo;

  /// E01/E04 protein bar. Her real intake, never the mockup 53.
  ///
  /// In en, this message translates to:
  /// **'{soFar} of {target} g'**
  String sofarOfTargetG(String soFar, String target);

  /// E04 running total. A TOTAL, never a countdown — there is no target here and no remainder, by design (G5 1.5).
  ///
  /// In en, this message translates to:
  /// **'About {kcal} kcal so far today'**
  String aboutKcalKcalSoFarToday(String kcal);

  /// E04. What this meal added to her protein.
  ///
  /// In en, this message translates to:
  /// **'+{grams} g'**
  String gramsG(String grams);

  /// E07/E08 grocery list. "About", because prices move.
  ///
  /// In en, this message translates to:
  /// **'{count} items · about {egp} EGP'**
  String countItemsAboutEgpEgp(int count, String egp);

  /// E04 undo bar. Names what SHE logged. The fixed "Lunch logged — 696 kcal" would announce 696 whatever she ate, which is the defect PHASE1-FIXES.md 8 removed from R07.
  ///
  /// In en, this message translates to:
  /// **'{meal} added · {kcal} kcal'**
  String mealAddedKcalKcal(String meal, String kcal);

  /// E02/E04 allergen sheet (G5 5.1). Names the allergen SHE told us about, so the sheet is about her and not a generic warning.
  ///
  /// In en, this message translates to:
  /// **'This dish has {allergen}. You told us to avoid that.'**
  String thisDishHasAllergenYouToldUs(String allergen);

  /// No description provided for @notThis.
  ///
  /// In en, this message translates to:
  /// **'Not this'**
  String get notThis;

  /// No description provided for @addItAnyway.
  ///
  /// In en, this message translates to:
  /// **'Add it anyway'**
  String get addItAnyway;

  /// T01 week card. Her real target, not the prototype 3 — a woman whose goal is 4 sessions read "This week, 0 of 3". The card already had the numbers; only the sentence was fixed.
  ///
  /// In en, this message translates to:
  /// **'This week, {done} of {target}'**
  String thisWeekDoneOfTarget(int done, int target);

  /// E01 starter rows. The food SHE is looking at, not the mockup. _starterMeta switched on foodId over three hardcoded cases with `_ => lunch540Kcal18GProtein` as the default, so every other food — boiled eggs included — claimed koshari's 540 kcal and 18 g. Wrong nutrition, stated confidently, on the screen where she decides what to eat.
  ///
  /// In en, this message translates to:
  /// **'{slot} · {kcal} kcal · {protein} g protein'**
  String slotKcalKcalProteinGProtein(String slot, String kcal, String protein);

  /// E01/E04 suggestion rows. _metaOf switched on foodId over six cases with `_ => n540Kcal18GProtein` as the default, so any food outside the list reported koshari's macros. Its own doc comment claimed the value was "picked from the dictionary by the row it describes, so the row and its macros cannot disagree" — which was exactly what it could not guarantee.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal · {protein} g protein'**
  String kcalKcalProteinGProtein(String kcal, String protein);

  /// No description provided for @waist.
  ///
  /// In en, this message translates to:
  /// **'Waist'**
  String get waist;

  /// No description provided for @hips.
  ///
  /// In en, this message translates to:
  /// **'Hips'**
  String get hips;

  /// No description provided for @arm.
  ///
  /// In en, this message translates to:
  /// **'Arm'**
  String get arm;

  /// No description provided for @thigh.
  ///
  /// In en, this message translates to:
  /// **'Thigh'**
  String get thigh;

  /// No description provided for @cm.
  ///
  /// In en, this message translates to:
  /// **'cm'**
  String get cm;

  /// No description provided for @kg.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get kg;

  /// P04 measurement chips. The label is Waist/Hips/Arm/Thigh and the value is hers. Withheld entirely until now: the four labels did not exist, so the add control could not be drawn and the chips were display-only.
  ///
  /// In en, this message translates to:
  /// **'{label} {value} cm'**
  String labelValueCm(String label, String value);

  /// P04's undo bar. Must name the weight SHE saved. The screen previously used the bare word "Saved", which is true of every measurement and therefore tells her nothing about the one she can still take back.
  ///
  /// In en, this message translates to:
  /// **'{weight} kg saved'**
  String weightKgSaved(String weight);

  /// No description provided for @sleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get sleep;

  /// No description provided for @bloating.
  ///
  /// In en, this message translates to:
  /// **'Bloating'**
  String get bloating;

  /// No description provided for @bleeding.
  ///
  /// In en, this message translates to:
  /// **'Bleeding'**
  String get bleeding;

  /// No description provided for @spotting.
  ///
  /// In en, this message translates to:
  /// **'Spotting'**
  String get spotting;

  /// No description provided for @heavy.
  ///
  /// In en, this message translates to:
  /// **'Heavy'**
  String get heavy;

  /// No description provided for @poor.
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get poor;

  /// No description provided for @good.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get good;

  /// No description provided for @est.
  ///
  /// In en, this message translates to:
  /// **'est.'**
  String get est;

  /// Y03/Y11. `periodDay2` bakes the mockup's day two into the sentence, so the hub rendered the bare number for every other day rather than lie. This is the form that lets the sentence be true on any day.
  ///
  /// In en, this message translates to:
  /// **'Period day {day}'**
  String periodDayDay(String day);

  /// Y10's chart caption. The fixed string named the mockup's 4 of 6, so the caption was withheld and the chart drew with no sentence beside it.
  ///
  /// In en, this message translates to:
  /// **'{logged} of {total} noted days'**
  String loggedOfTotalNotedDays(String logged, String total);

  /// No description provided for @cameBack.
  ///
  /// In en, this message translates to:
  /// **'Came back'**
  String get cameBack;

  /// No description provided for @firstSteps.
  ///
  /// In en, this message translates to:
  /// **'First steps'**
  String get firstSteps;

  /// No description provided for @strong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get strong;

  /// No description provided for @unshakeable.
  ///
  /// In en, this message translates to:
  /// **'Unshakeable'**
  String get unshakeable;

  /// P01 and T01. `level7Regular` freezes the mockup's level 7 into the pill, so it announced level 7 to a woman on level 1.
  ///
  /// In en, this message translates to:
  /// **'Level {n}'**
  String levelN(String n);

  /// P02 milestones and P03 bests — the generic "4 of 12" the counted-weeks and bests tiles need. Both previously rendered nothing rather than a constant, which is why P02's heading does not appear.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total}'**
  String countOfTotal(String count, String total);

  /// P03 personal-best delta. Hers, not a sample.
  ///
  /// In en, this message translates to:
  /// **'+{n} kg'**
  String nKg(String n);

  /// P03 personal-best delta, repetitions.
  ///
  /// In en, this message translates to:
  /// **'+{n} reps'**
  String nReps(String n);

  /// P03 personal-best delta, a hold in seconds. Note G4 publishes no `actualHoldSec`, so nothing populates this yet — the string exists so the branch is complete the day it does.
  ///
  /// In en, this message translates to:
  /// **'+{n} s'**
  String nS(String n);

  /// No description provided for @libraryLabel.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get libraryLabel;

  /// No description provided for @row.
  ///
  /// In en, this message translates to:
  /// **'Row'**
  String get row;

  /// No description provided for @problem.
  ///
  /// In en, this message translates to:
  /// **'Problem'**
  String get problem;

  /// No description provided for @column.
  ///
  /// In en, this message translates to:
  /// **'Column'**
  String get column;

  /// No description provided for @requiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredLabel;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'yes'**
  String get yes;

  /// No description provided for @yesBoth.
  ///
  /// In en, this message translates to:
  /// **'yes, both'**
  String get yesBoth;

  /// No description provided for @columnsItExpects.
  ///
  /// In en, this message translates to:
  /// **'Columns it expects'**
  String get columnsItExpects;

  /// Z01 collection subtitles and Z09's row count. `CollectionStatus.rows` is already carried for exactly this and was never rendered.
  ///
  /// In en, this message translates to:
  /// **'{n} rows'**
  String nRows(String n);

  /// No description provided for @importEverything_damon.
  ///
  /// In en, this message translates to:
  /// **'Import everything?'**
  String get importEverything_damon;

  /// No description provided for @backToTheFile.
  ///
  /// In en, this message translates to:
  /// **'Back to the file'**
  String get backToTheFile;

  /// No description provided for @noExercisesYet.
  ///
  /// In en, this message translates to:
  /// **'No exercises yet'**
  String get noExercisesYet;

  /// No description provided for @noFoodsYet.
  ///
  /// In en, this message translates to:
  /// **'No foods yet'**
  String get noFoodsYet;

  /// No description provided for @noRecipesYet.
  ///
  /// In en, this message translates to:
  /// **'No recipes yet'**
  String get noRecipesYet;

  /// No description provided for @noProgrammesYet.
  ///
  /// In en, this message translates to:
  /// **'No programmes yet'**
  String get noProgrammesYet;

  /// No description provided for @noVideo.
  ///
  /// In en, this message translates to:
  /// **'No video'**
  String get noVideo;

  /// No description provided for @noMacros.
  ///
  /// In en, this message translates to:
  /// **'No macros'**
  String get noMacros;

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// No description provided for @videos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get videos;

  /// No description provided for @unlinked.
  ///
  /// In en, this message translates to:
  /// **'Unlinked'**
  String get unlinked;

  /// No description provided for @mediaLibrary.
  ///
  /// In en, this message translates to:
  /// **'Media library'**
  String get mediaLibrary;

  /// No description provided for @whatToExport.
  ///
  /// In en, this message translates to:
  /// **'What to export'**
  String get whatToExport;

  /// No description provided for @csv.
  ///
  /// In en, this message translates to:
  /// **'CSV'**
  String get csv;

  /// No description provided for @csvVideos.
  ///
  /// In en, this message translates to:
  /// **'CSV + videos'**
  String get csvVideos;

  /// No description provided for @csvPhotos.
  ///
  /// In en, this message translates to:
  /// **'CSV + photos'**
  String get csvPhotos;

  /// No description provided for @exerciseId.
  ///
  /// In en, this message translates to:
  /// **'Exercise id'**
  String get exerciseId;

  /// No description provided for @foodId.
  ///
  /// In en, this message translates to:
  /// **'Food id'**
  String get foodId;

  /// No description provided for @nameEnglish.
  ///
  /// In en, this message translates to:
  /// **'Name (English)'**
  String get nameEnglish;

  /// No description provided for @nameArabic.
  ///
  /// In en, this message translates to:
  /// **'Name (Arabic)'**
  String get nameArabic;

  /// No description provided for @equipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get equipment;

  /// No description provided for @contraindicationTags.
  ///
  /// In en, this message translates to:
  /// **'Contraindication tags'**
  String get contraindicationTags;

  /// No description provided for @allergens.
  ///
  /// In en, this message translates to:
  /// **'Allergens'**
  String get allergens;

  /// No description provided for @dietTags.
  ///
  /// In en, this message translates to:
  /// **'Diet tags'**
  String get dietTags;

  /// No description provided for @proteinG.
  ///
  /// In en, this message translates to:
  /// **'Protein g'**
  String get proteinG;

  /// No description provided for @kcal.
  ///
  /// In en, this message translates to:
  /// **'kcal'**
  String get kcal;

  /// No description provided for @fri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get fri;

  /// T01's workout badge and R01's programme header. The worst of the remaining baked-in samples: `week3Of8` states "Week 3 of 8" to every woman, and `train_view` uses it as a FALLBACK (`programWeek ?? week3Of8`) — so it asserts a week precisely when the real one is unknown, which is the one moment it should say nothing.
  ///
  /// In en, this message translates to:
  /// **'Week {week} of {total}'**
  String weekWeekOfTotal(String week, String total);

  /// T01's walk card. Her phone counted the minutes; the card stated 32 regardless. The undo bar quotes this same line, so the number she is offered a chance to take back has to be the number she walked.
  ///
  /// In en, this message translates to:
  /// **'Walk this morning · {minutes} min'**
  String walkThisMorningMinutesMin(String minutes);

  /// T01's meal-card chips and E06's recipe facts. A TOTAL, never a countdown, and never a remainder — G5 §1.5. The fixed `n410Kcal` and `n290Kcal` named the mockup's breakfast whatever she had eaten.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal'**
  String kcalKcal(String kcal);

  /// No description provided for @carbsG.
  ///
  /// In en, this message translates to:
  /// **'Carbs g'**
  String get carbsG;

  /// No description provided for @fatG.
  ///
  /// In en, this message translates to:
  /// **'Fat g'**
  String get fatG;

  /// No description provided for @editAnExercise.
  ///
  /// In en, this message translates to:
  /// **'Edit an exercise'**
  String get editAnExercise;

  /// No description provided for @editAFood.
  ///
  /// In en, this message translates to:
  /// **'Edit a food'**
  String get editAFood;

  /// No description provided for @pattern.
  ///
  /// In en, this message translates to:
  /// **'Pattern'**
  String get pattern;

  /// No description provided for @portions.
  ///
  /// In en, this message translates to:
  /// **'Portions'**
  String get portions;

  /// No description provided for @videoFile.
  ///
  /// In en, this message translates to:
  /// **'Video file'**
  String get videoFile;

  /// No description provided for @thumbnail.
  ///
  /// In en, this message translates to:
  /// **'Thumbnail'**
  String get thumbnail;

  /// No description provided for @photoFile.
  ///
  /// In en, this message translates to:
  /// **'Photo file'**
  String get photoFile;

  /// No description provided for @recipeId.
  ///
  /// In en, this message translates to:
  /// **'Recipe id'**
  String get recipeId;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get minutes;

  /// No description provided for @ingredients.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get ingredients;

  /// No description provided for @addARecipe.
  ///
  /// In en, this message translates to:
  /// **'Add a recipe'**
  String get addARecipe;

  /// No description provided for @programmeId.
  ///
  /// In en, this message translates to:
  /// **'Programme id'**
  String get programmeId;

  /// No description provided for @weeks.
  ///
  /// In en, this message translates to:
  /// **'Weeks'**
  String get weeks;

  /// No description provided for @sessionLength.
  ///
  /// In en, this message translates to:
  /// **'Session length'**
  String get sessionLength;

  /// No description provided for @addAProgramme.
  ///
  /// In en, this message translates to:
  /// **'Add a programme'**
  String get addAProgramme;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @chooseAFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a file'**
  String get chooseAFile;

  /// No description provided for @file.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// Z10's media library. The file size, which the screen currently shows as a raw byte count — 12,000,000 — because no unit string existed. True, Western-digit, and harder to read than the design intends.
  ///
  /// In en, this message translates to:
  /// **'{size} MB'**
  String sizeMb(String size);

  /// Z10's media library, for a file under a megabyte.
  ///
  /// In en, this message translates to:
  /// **'{size} KB'**
  String sizeKb(String size);

  /// Z09's dry-run summary. Deliberately its own string rather than `{n} rows`: the admin console avoided that one here because it renders "1 rows" in the commonest case of all, a single-row fix.
  ///
  /// In en, this message translates to:
  /// **'{n} rows ready'**
  String nRowsReady(String n);

  /// No description provided for @nothingHereIsAMembersDataThis.
  ///
  /// In en, this message translates to:
  /// **'Nothing here is a member\'s data. This console manages the library only.'**
  String get nothingHereIsAMembersDataThis;

  /// No description provided for @editARecipe.
  ///
  /// In en, this message translates to:
  /// **'Edit a recipe'**
  String get editARecipe;

  /// No description provided for @editAProgramme.
  ///
  /// In en, this message translates to:
  /// **'Edit a programme'**
  String get editAProgramme;

  /// No description provided for @stableChangingItOrphansEverythingThatReferenced.
  ///
  /// In en, this message translates to:
  /// **'Stable. Changing it orphans everything that referenced it.'**
  String get stableChangingItOrphansEverythingThatReferenced;

  /// No description provided for @requiredWriteNoneIfThereAreNone.
  ///
  /// In en, this message translates to:
  /// **'Required. Write “none” if there are none. Blank is not the same thing.'**
  String get requiredWriteNoneIfThereAreNone;

  /// No description provided for @aRecipeThatNamesAPhotoNobody.
  ///
  /// In en, this message translates to:
  /// **'A recipe that names a photo nobody uploaded is refused at validation, rather than reaching a woman as a card with a missing image.'**
  String get aRecipeThatNamesAPhotoNobody;

  /// No description provided for @aProgrammeIsAShapeWeeksDays.
  ///
  /// In en, this message translates to:
  /// **'A programme is a shape: weeks, days, session length. It holds no ingredient and no movement of its own, so there is no safety column for a guard to read off it.'**
  String get aProgrammeIsAShapeWeeksDays;

  /// No description provided for @featureFlags.
  ///
  /// In en, this message translates to:
  /// **'Feature flags'**
  String get featureFlags;

  /// No description provided for @turningAFeatureOffHidesItEverywhere.
  ///
  /// In en, this message translates to:
  /// **'Turning a feature off hides it everywhere, for everyone.'**
  String get turningAFeatureOffHidesItEverywhere;

  /// No description provided for @builtAndLive.
  ///
  /// In en, this message translates to:
  /// **'Built and live'**
  String get builtAndLive;

  /// No description provided for @notSwitchedOnYet.
  ///
  /// In en, this message translates to:
  /// **'Not switched on yet'**
  String get notSwitchedOnYet;

  /// No description provided for @videoAndReels.
  ///
  /// In en, this message translates to:
  /// **'Video and reels'**
  String get videoAndReels;

  /// No description provided for @offBlurExportIsUnmeasuredOnA.
  ///
  /// In en, this message translates to:
  /// **'Off · blur export is unmeasured on a budget handset'**
  String get offBlurExportIsUnmeasuredOnA;

  /// No description provided for @offNoPaymentProviderIsConnected.
  ///
  /// In en, this message translates to:
  /// **'Off · no payment provider is connected'**
  String get offNoPaymentProviderIsConnected;

  /// No description provided for @aFeatureInsideAnotherOneCannotBe.
  ///
  /// In en, this message translates to:
  /// **'A feature inside another one cannot be on while the one around it is off. Switching Community off switches off everything inside it, so nothing is left reachable on its own.'**
  String get aFeatureInsideAnotherOneCannotBe;

  /// No description provided for @nothingFoundForThatIWouldRather.
  ///
  /// In en, this message translates to:
  /// **'Nothing found for that. I would rather say so than guess.'**
  String get nothingFoundForThatIWouldRather;

  /// No description provided for @askingNeedsAConnection.
  ///
  /// In en, this message translates to:
  /// **'Asking needs a connection.'**
  String get askingNeedsAConnection;

  /// No description provided for @draftingNeedsAConnection.
  ///
  /// In en, this message translates to:
  /// **'Drafting needs a connection.'**
  String get draftingNeedsAConnection;

  /// No description provided for @youHaveUsedTodaysQuestionsThereWill.
  ///
  /// In en, this message translates to:
  /// **'You have used today\'s questions. There will be more tomorrow.'**
  String get youHaveUsedTodaysQuestionsThereWill;

  /// No description provided for @saveFeedback.
  ///
  /// In en, this message translates to:
  /// **'Save feedback'**
  String get saveFeedback;

  /// No description provided for @publishChanges.
  ///
  /// In en, this message translates to:
  /// **'Publish changes'**
  String get publishChanges;

  /// No description provided for @wellPublishTheMomentYoureBackOnline.
  ///
  /// In en, this message translates to:
  /// **'We\'ll publish the moment you\'re back online'**
  String get wellPublishTheMomentYoureBackOnline;

  /// No description provided for @waitingToSend.
  ///
  /// In en, this message translates to:
  /// **'Waiting to send'**
  String get waitingToSend;

  /// A price. Every other EGP string in the dictionary bakes a sample figure into the sentence, so a one-off package had no way to state its own price and rendered none at all.
  ///
  /// In en, this message translates to:
  /// **'{amount} EGP'**
  String amountEgp(String amount);

  /// H01's price-band facet. `under2000Egp` bakes 2,000, so the chip was absent from the directory even though the filter behind it works.
  ///
  /// In en, this message translates to:
  /// **'Under {n} EGP'**
  String underNEgp(String n);

  /// No description provided for @youNeedAConnectionToPayNothing.
  ///
  /// In en, this message translates to:
  /// **'You need a connection to pay. Nothing is queued.'**
  String get youNeedAConnectionToPayNothing;

  /// No description provided for @thatPaymentWasDeclinedNothingWasCharged.
  ///
  /// In en, this message translates to:
  /// **'That payment was declined. Nothing was charged.'**
  String get thatPaymentWasDeclinedNothingWasCharged;

  /// No description provided for @yourMoneyIsOnItsWayBack.
  ///
  /// In en, this message translates to:
  /// **'Your money is on its way back. It can take a few days.'**
  String get yourMoneyIsOnItsWayBack;

  /// No description provided for @spotsLeft.
  ///
  /// In en, this message translates to:
  /// **'Spots left'**
  String get spotsLeft;

  /// No description provided for @sheIsNotTakingClientsRightNow.
  ///
  /// In en, this message translates to:
  /// **'She is not taking clients right now'**
  String get sheIsNotTakingClientsRightNow;

  /// No description provided for @preparingYourPayment.
  ///
  /// In en, this message translates to:
  /// **'Preparing your payment'**
  String get preparingYourPayment;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @bestMatch.
  ///
  /// In en, this message translates to:
  /// **'Best match'**
  String get bestMatch;

  /// No description provided for @repliesFastest.
  ///
  /// In en, this message translates to:
  /// **'Replies fastest'**
  String get repliesFastest;

  /// No description provided for @priceLowToHigh.
  ///
  /// In en, this message translates to:
  /// **'Price: low to high'**
  String get priceLowToHigh;

  /// No description provided for @priceHighToLow.
  ///
  /// In en, this message translates to:
  /// **'Price: high to low'**
  String get priceHighToLow;

  /// No description provided for @allScreens.
  ///
  /// In en, this message translates to:
  /// **'All screens'**
  String get allScreens;

  /// No description provided for @openAnyScreenForTesting.
  ///
  /// In en, this message translates to:
  /// **'Open any screen, for testing'**
  String get openAnyScreenForTesting;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @writeAPost.
  ///
  /// In en, this message translates to:
  /// **'Write a post'**
  String get writeAPost;

  /// No description provided for @addTopics.
  ///
  /// In en, this message translates to:
  /// **'Add topics'**
  String get addTopics;

  /// No description provided for @postTo.
  ///
  /// In en, this message translates to:
  /// **'Post to'**
  String get postTo;

  /// No description provided for @posted.
  ///
  /// In en, this message translates to:
  /// **'Posted'**
  String get posted;

  /// No description provided for @walking.
  ///
  /// In en, this message translates to:
  /// **'Walking'**
  String get walking;

  /// No description provided for @noReelsYet.
  ///
  /// In en, this message translates to:
  /// **'No reels yet'**
  String get noReelsYet;

  /// No description provided for @thereIsNoCameraInThisBuild.
  ///
  /// In en, this message translates to:
  /// **'There is no camera in this build yet, so nothing was taken. You can write a text post from Create.'**
  String get thereIsNoCameraInThisBuild;

  /// No description provided for @whyAreYouReportingThis.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting this?'**
  String get whyAreYouReportingThis;

  /// No description provided for @harassmentOrBullying.
  ///
  /// In en, this message translates to:
  /// **'Harassment or bullying'**
  String get harassmentOrBullying;

  /// No description provided for @thisIsAMansAccount.
  ///
  /// In en, this message translates to:
  /// **'This is a man\'s account'**
  String get thisIsAMansAccount;

  /// No description provided for @nudity.
  ///
  /// In en, this message translates to:
  /// **'Nudity'**
  String get nudity;

  /// No description provided for @spam.
  ///
  /// In en, this message translates to:
  /// **'Spam'**
  String get spam;

  /// No description provided for @pretendingToBeSomeoneElse.
  ///
  /// In en, this message translates to:
  /// **'Pretending to be someone else'**
  String get pretendingToBeSomeoneElse;

  /// No description provided for @selfHarm.
  ///
  /// In en, this message translates to:
  /// **'Self-harm'**
  String get selfHarm;

  /// No description provided for @reportSent.
  ///
  /// In en, this message translates to:
  /// **'Report sent'**
  String get reportSent;

  /// No description provided for @deleteThisPost.
  ///
  /// In en, this message translates to:
  /// **'Delete this post'**
  String get deleteThisPost;

  /// No description provided for @tapAgainToDeleteItEverywhere.
  ///
  /// In en, this message translates to:
  /// **'Tap again to delete it everywhere'**
  String get tapAgainToDeleteItEverywhere;

  /// No description provided for @unmuteThisGroup.
  ///
  /// In en, this message translates to:
  /// **'Unmute this group'**
  String get unmuteThisGroup;

  /// No description provided for @leaveGroup.
  ///
  /// In en, this message translates to:
  /// **'Leave group'**
  String get leaveGroup;

  /// M12's follow-up strip: which week of her own chain a moment is. The only minted forms (Week 1, Week 4) bake the prototype's weeks.
  ///
  /// In en, this message translates to:
  /// **'Week {n}'**
  String weekN(String n);

  /// No description provided for @mapsAreNotConnectedInThisBuild.
  ///
  /// In en, this message translates to:
  /// **'Maps are not connected in this build yet, so the app cannot look for care near you.'**
  String get mapsAreNotConnectedInThisBuild;

  /// No description provided for @openingWebLinksIsNotConnectedIn.
  ///
  /// In en, this message translates to:
  /// **'Opening web links is not connected in this build yet.'**
  String get openingWebLinksIsNotConnectedIn;

  /// No description provided for @restingTodayNothingInYourPlanChanges.
  ///
  /// In en, this message translates to:
  /// **'Resting today. Nothing in your plan changes.'**
  String get restingTodayNothingInYourPlanChanges;

  /// No description provided for @skipThisStepTestBuild.
  ///
  /// In en, this message translates to:
  /// **'Skip this step (test build)'**
  String get skipThisStepTestBuild;

  /// No description provided for @testBuildNothingIsPhotographedOrChecked.
  ///
  /// In en, this message translates to:
  /// **'Test build: nothing is photographed or checked here, and no ID is verified.'**
  String get testBuildNothingIsPhotographedOrChecked;

  /// C07, only while no account is required. Names the one code the in-memory sign-in accepts, so the sign-up chain can be walked by hand without SMS.
  ///
  /// In en, this message translates to:
  /// **'Test build: no text message is sent. The code is {code}.'**
  String testBuildNoTextMessageIsSent(String code);

  /// No description provided for @useTheTestCode.
  ///
  /// In en, this message translates to:
  /// **'Use the test code'**
  String get useTheTestCode;

  /// No description provided for @testBuildNobodyCheckedAnIdSo.
  ///
  /// In en, this message translates to:
  /// **'Test build: nobody checked an ID, so this account is not verified.'**
  String get testBuildNobodyCheckedAnIdSo;

  /// No description provided for @theAssistantIsNotConnectedYetSo.
  ///
  /// In en, this message translates to:
  /// **'The assistant is not connected yet, so it cannot answer questions. A person can: ask your coach below.'**
  String get theAssistantIsNotConnectedYetSo;

  /// No description provided for @draftingIsNotConnectedYetThePlanner.
  ///
  /// In en, this message translates to:
  /// **'Drafting is not connected yet. The planner works as usual.'**
  String get draftingIsNotConnectedYetThePlanner;

  /// No description provided for @exampleThisIsWhatTheAssistantShows.
  ///
  /// In en, this message translates to:
  /// **'Example: this is what the assistant shows when it will not answer a question.'**
  String get exampleThisIsWhatTheAssistantShows;

  /// No description provided for @notificationsAreNotConnectedInThisBuild.
  ///
  /// In en, this message translates to:
  /// **'Notifications are not connected in this build yet.'**
  String get notificationsAreNotConnectedInThisBuild;

  /// No description provided for @whyAreYouReporting.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting?'**
  String get whyAreYouReporting;

  /// No description provided for @harassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment'**
  String get harassment;

  /// No description provided for @aMansAccount.
  ///
  /// In en, this message translates to:
  /// **'A man\'s account'**
  String get aMansAccount;

  /// No description provided for @whoIsItAndWhatHappenedOptional.
  ///
  /// In en, this message translates to:
  /// **'Who is it, and what happened? Optional'**
  String get whoIsItAndWhatHappenedOptional;

  /// No description provided for @sendReport.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get sendReport;

  /// No description provided for @testBuildNoModerationTeamIsConnected.
  ///
  /// In en, this message translates to:
  /// **'Test build: no moderation team is connected, so this report stays on this phone and nobody reads it.'**
  String get testBuildNoModerationTeamIsConnected;

  /// No description provided for @testReportSavedNobodyReadsItIn.
  ///
  /// In en, this message translates to:
  /// **'Test report saved. Nobody reads it in this build.'**
  String get testReportSavedNobodyReadsItIn;

  /// No description provided for @testReportNotSent.
  ///
  /// In en, this message translates to:
  /// **'Test report, not sent'**
  String get testReportNotSent;

  /// A04's blocked-members row. A label form so the Arabic needs no number agreement; the count is the members she actually blocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked: {count}'**
  String blockedCount(String count);

  /// A04's reports row while no account is required: how many test reports are held on this phone. Nothing is sent anywhere in this build.
  ///
  /// In en, this message translates to:
  /// **'Test reports: {count}'**
  String testReportsCount(String count);

  /// No description provided for @unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// No description provided for @youHaveNotBlockedAnyone.
  ///
  /// In en, this message translates to:
  /// **'You have not blocked anyone.'**
  String get youHaveNotBlockedAnyone;

  /// No description provided for @pasteACsvFromTheClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste a CSV from the clipboard'**
  String get pasteACsvFromTheClipboard;

  /// No description provided for @pastedFromTheClipboard.
  ///
  /// In en, this message translates to:
  /// **'Pasted from the clipboard'**
  String get pastedFromTheClipboard;

  /// No description provided for @theClipboardHasNoTextToCheck.
  ///
  /// In en, this message translates to:
  /// **'The clipboard has no text to check.'**
  String get theClipboardHasNoTextToCheck;

  /// Z11 after Export: the chosen collections' CSVs were copied to the clipboard, because this build has no file saving.
  ///
  /// In en, this message translates to:
  /// **'CSV files copied to the clipboard: {count}. Saving files is not connected in this build yet.'**
  String csvFilesCopiedToTheClipboardCount(String count);

  /// O05's headline read back from her own O02/O03 answers. Label form so the Arabic is grammatical for every allowed count.
  ///
  /// In en, this message translates to:
  /// **'Days a week: {days} · Minutes a session: {minutes} · At home'**
  String daysAWeekDaysMinutesASession(String days, String minutes);

  /// O05's headline read back from her own O02/O03 answers, gym variant.
  ///
  /// In en, this message translates to:
  /// **'Days a week: {days} · Minutes a session: {minutes} · At a ladies-only gym'**
  String daysAWeekDaysMinutesASession_1qm7e(String days, String minutes);

  /// O05's headline read back from her own O02/O03 answers, home-and-gym variant.
  ///
  /// In en, this message translates to:
  /// **'Days a week: {days} · Minutes a session: {minutes} · At home and the gym'**
  String daysAWeekDaysMinutesASession_1cc8s(String days, String minutes);

  /// No description provided for @like.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get like;

  /// No description provided for @comment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get comment;

  /// Eat allergen sheet (G5 5.1), for a dish whose allergens are unknown while she has told us she avoids something. Unknown is treated as unsafe, so the log waits for her explicit choice. {dish} is the food's name in her language.
  ///
  /// In en, this message translates to:
  /// **'Nobody has listed what is in {dish} yet, so we cannot check it against what you avoid.'**
  String nobodyHasListedWhatIsInDish(String dish);

  /// No description provided for @nuts.
  ///
  /// In en, this message translates to:
  /// **'nuts'**
  String get nuts;

  /// No description provided for @dairy.
  ///
  /// In en, this message translates to:
  /// **'dairy'**
  String get dairy;

  /// No description provided for @gluten.
  ///
  /// In en, this message translates to:
  /// **'gluten'**
  String get gluten;

  /// No description provided for @shellfish.
  ///
  /// In en, this message translates to:
  /// **'shellfish'**
  String get shellfish;

  /// No description provided for @weCannotCheckTheseDishesForWhat.
  ///
  /// In en, this message translates to:
  /// **'We cannot check these dishes for what you avoid yet, so none are suggested.'**
  String get weCannotCheckTheseDishesForWhat;

  /// No description provided for @theStepsForThisDishHaveNot.
  ///
  /// In en, this message translates to:
  /// **'The steps for this dish have not been written yet.'**
  String get theStepsForThisDishHaveNot;

  /// No description provided for @rearrangeTheWeek.
  ///
  /// In en, this message translates to:
  /// **'Rearrange the week'**
  String get rearrangeTheWeek;

  /// No description provided for @youAreATestCoach.
  ///
  /// In en, this message translates to:
  /// **'You are a test coach'**
  String get youAreATestCoach;

  /// No description provided for @whileSignUpIsSwitchedOffYou.
  ///
  /// In en, this message translates to:
  /// **'While sign-up is switched off, you count as a checked coach so you can try everything. Nobody has looked at your certificates.'**
  String get whileSignUpIsSwitchedOffYou;

  /// No description provided for @testNotChecked.
  ///
  /// In en, this message translates to:
  /// **'Test · not checked'**
  String get testNotChecked;

  /// No description provided for @inTestModeACertificateIsRecorded.
  ///
  /// In en, this message translates to:
  /// **'In test mode a certificate is recorded without a photo, and nobody reviews it.'**
  String get inTestModeACertificateIsRecorded;

  /// No description provided for @walletOrAccountNumber.
  ///
  /// In en, this message translates to:
  /// **'Wallet or account number'**
  String get walletOrAccountNumber;

  /// No description provided for @testPayoutNoMoneyMovesAndNothing.
  ///
  /// In en, this message translates to:
  /// **'Test payout. No money moves, and nothing is sent to a real wallet or bank.'**
  String get testPayoutNoMoneyMovesAndNothing;

  /// No description provided for @whatIsInItOnePerLine.
  ///
  /// In en, this message translates to:
  /// **'What is in it, one per line'**
  String get whatIsInItOnePerLine;

  /// No description provided for @testPaymentNoMoneyMoves.
  ///
  /// In en, this message translates to:
  /// **'Test payment · no money moves'**
  String get testPaymentNoMoneyMoves;

  /// No description provided for @testModeCoachesSetUpOnThis.
  ///
  /// In en, this message translates to:
  /// **'Test mode: coaches set up on this phone appear here once they finish setup and publish their page. Nobody has checked their certificates.'**
  String get testModeCoachesSetUpOnThis;

  /// No description provided for @nothingIsCountedYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing is counted yet'**
  String get nothingIsCountedYet;

  /// No description provided for @viewsAndEnquiriesAreNotMeasuredIn.
  ///
  /// In en, this message translates to:
  /// **'Views and enquiries are not measured in this version, so there are no figures to show. A zero here would be a guess about your page, not a fact.'**
  String get viewsAndEnquiriesAreNotMeasuredIn;

  /// No description provided for @wordsOnTheButton.
  ///
  /// In en, this message translates to:
  /// **'Words on the button'**
  String get wordsOnTheButton;

  /// No description provided for @thisSectionNeedsAPhotoOrVideo.
  ///
  /// In en, this message translates to:
  /// **'This section needs a photo or video. Add one, choose a layout without one, or hide the section.'**
  String get thisSectionNeedsAPhotoOrVideo;

  /// No description provided for @addAtLeastOneStep.
  ///
  /// In en, this message translates to:
  /// **'Add at least one step.'**
  String get addAtLeastOneStep;

  /// R07/R08/R09 title. Her position in the day's moves, replacing the fixed 'Move 2 of 5'.
  ///
  /// In en, this message translates to:
  /// **'Move {move} of {total}'**
  String moveMoveOfTotal(String move, String total);

  /// R09 'Up next' card: the move and set she returns to after resting.
  ///
  /// In en, this message translates to:
  /// **'{move}, set {set}'**
  String moveSetSet(String move, String set);

  /// One set's figure — what was asked, or what she did. Western digits in both languages.
  ///
  /// In en, this message translates to:
  /// **'{weight} kg × {reps}'**
  String weightKgReps(String weight, String reps);

  /// A bodyweight set's figure — no load to state, never '0 kg'.
  ///
  /// In en, this message translates to:
  /// **'{reps} reps'**
  String repsReps(String reps);

  /// A timed hold's figure.
  ///
  /// In en, this message translates to:
  /// **'{seconds} seconds'**
  String secondsSeconds(String seconds);

  /// R07/R08 primary button for a bodyweight set. Names the numbers it is about to save.
  ///
  /// In en, this message translates to:
  /// **'Done · {reps} reps'**
  String doneRepsReps(String reps);

  /// R07/R08 primary button for a timed hold.
  ///
  /// In en, this message translates to:
  /// **'Done · {seconds} seconds'**
  String doneSecondsSeconds(String seconds);

  /// Undo bar after a bodyweight set is logged. Repeats the button's numbers.
  ///
  /// In en, this message translates to:
  /// **'Set {setNumber} saved · {reps} reps'**
  String setSetnumberSavedRepsReps(String setNumber, String reps);

  /// Undo bar after a timed hold is logged.
  ///
  /// In en, this message translates to:
  /// **'Set {setNumber} saved · {seconds} seconds'**
  String setSetnumberSavedSecondsSeconds(String setNumber, String seconds);

  /// R10/R12 heading. The day she trained, replacing the fixed Tuesday.
  ///
  /// In en, this message translates to:
  /// **'That\'s {day} done'**
  String thatsDayDone(String day);

  /// R10/R12: the points this session actually earned her, from the award ledger.
  ///
  /// In en, this message translates to:
  /// **'+{points} points'**
  String pointsPoints(String points);

  /// Week line when three or more sessions are still to go. One and two have their own sentences.
  ///
  /// In en, this message translates to:
  /// **'{count} more and the week counts.'**
  String countMoreAndTheWeekCounts(String count);

  /// No description provided for @thisWeekCounts.
  ///
  /// In en, this message translates to:
  /// **'This week counts.'**
  String get thisWeekCounts;

  /// T07: the first-week arc counted from the arc, replacing the fixed 'Two done, three waiting'.
  ///
  /// In en, this message translates to:
  /// **'{done} done, {waiting} waiting'**
  String doneDoneWaitingWaiting(String done, String waiting);

  /// P01 bests tile: her lifetime personal bests, replacing the fixed '8 so far'.
  ///
  /// In en, this message translates to:
  /// **'{count} so far'**
  String countSoFar(String count);

  /// No description provided for @shareItWithYourGroup.
  ///
  /// In en, this message translates to:
  /// **'Share it with your group'**
  String get shareItWithYourGroup;

  /// No description provided for @seconds.
  ///
  /// In en, this message translates to:
  /// **'Seconds'**
  String get seconds;

  /// No description provided for @anotherReason.
  ///
  /// In en, this message translates to:
  /// **'Another reason'**
  String get anotherReason;

  /// No description provided for @thereIsNoPhotoPickerInThis.
  ///
  /// In en, this message translates to:
  /// **'There is no photo picker in this build yet, so nothing can be added to your media.'**
  String get thereIsNoPhotoPickerInThis;

  /// No description provided for @savingAnImageToYourPhoneIs.
  ///
  /// In en, this message translates to:
  /// **'Saving an image to your phone is not connected in this build yet.'**
  String get savingAnImageToYourPhoneIs;

  /// No description provided for @testModeThisIsYourOwnCoach.
  ///
  /// In en, this message translates to:
  /// **'Test mode: this is your own coach page, so you can accept your own enquiry here.'**
  String get testModeThisIsYourOwnCoach;

  /// No description provided for @acceptAsTheCoachTest.
  ///
  /// In en, this message translates to:
  /// **'Accept as the coach (test)'**
  String get acceptAsTheCoachTest;

  /// No description provided for @sharingIsNotConnectedInThisBuild.
  ///
  /// In en, this message translates to:
  /// **'Sharing is not connected in this build yet, so nothing leaves this phone.'**
  String get sharingIsNotConnectedInThisBuild;

  /// No description provided for @noRecipeCarriesARamadanTagYet.
  ///
  /// In en, this message translates to:
  /// **'No recipe carries a Ramadan tag yet.'**
  String get noRecipeCarriesARamadanTagYet;

  /// No description provided for @removedFromSaved.
  ///
  /// In en, this message translates to:
  /// **'Removed from saved'**
  String get removedFromSaved;

  /// No description provided for @weDoNotKnowWhatYouAvoid.
  ///
  /// In en, this message translates to:
  /// **'We do not know what you avoid yet, so nothing can be added.'**
  String get weDoNotKnowWhatYouAvoid;

  /// No description provided for @endThisCoachingNowTest.
  ///
  /// In en, this message translates to:
  /// **'End this coaching now (test)'**
  String get endThisCoachingNowTest;

  /// No description provided for @thisDishIsNotInTheFood.
  ///
  /// In en, this message translates to:
  /// **'This dish is not in the food list yet, so it cannot be added from here.'**
  String get thisDishIsNotInTheFood;

  /// No description provided for @rose.
  ///
  /// In en, this message translates to:
  /// **'Rose'**
  String get rose;

  /// No description provided for @sage.
  ///
  /// In en, this message translates to:
  /// **'Sage'**
  String get sage;

  /// No description provided for @amber.
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get amber;

  /// No description provided for @blue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get blue;

  /// No description provided for @purple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get purple;

  /// No description provided for @teal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get teal;

  /// No description provided for @aNewCodeIsOnItsWay.
  ///
  /// In en, this message translates to:
  /// **'A new code is on its way.'**
  String get aNewCodeIsOnItsWay;

  /// A range of two values the screen already knows: opening hours on a coach's page, or the number of clients she may take. Written out in each language rather than joined with a dash in code, which would read as English punctuation inside an Arabic line.
  ///
  /// In en, this message translates to:
  /// **'{from} to {to}'**
  String fromToTo(String from, String to);

  /// No description provided for @notYet.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get notYet;

  /// No description provided for @itChecksItselfTheMomentTheSixth_1pr5i.
  ///
  /// In en, this message translates to:
  /// **'It checks itself the moment the sixth digit lands.'**
  String get itChecksItselfTheMomentTheSixth_1pr5i;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get termsOfUse;

  /// No description provided for @opensInYourBrowser.
  ///
  /// In en, this message translates to:
  /// **'Opens in your browser'**
  String get opensInYourBrowser;

  /// No description provided for @thatPageCouldNotBeOpenedTry.
  ///
  /// In en, this message translates to:
  /// **'That page could not be opened. Try again later.'**
  String get thatPageCouldNotBeOpenedTry;

  /// No description provided for @deleteYourAccountAndEverythingInIt.
  ///
  /// In en, this message translates to:
  /// **'Delete your account and everything in it'**
  String get deleteYourAccountAndEverythingInIt;

  /// No description provided for @deletingTakesAwayEverythingYouHavePut.
  ///
  /// In en, this message translates to:
  /// **'Deleting takes away everything you have put into the app: your meals, your workouts, your measurements, your cycle, your posts and your answers. It happens at once, and none of it can be brought back.'**
  String get deletingTakesAwayEverythingYouHavePut;

  /// No description provided for @downloadingACopyOfYourDataIs.
  ///
  /// In en, this message translates to:
  /// **'Downloading a copy of your data is not built yet, so there is no button for it here.'**
  String get downloadingACopyOfYourDataIs;

  /// No description provided for @deleteEverything.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get deleteEverything;

  /// No description provided for @yourDataIsGoneTheAppIs.
  ///
  /// In en, this message translates to:
  /// **'Your data is gone. The app is back to its first day.'**
  String get yourDataIsGoneTheAppIs;

  /// No description provided for @reportHerFromHerPostOrHer.
  ///
  /// In en, this message translates to:
  /// **'Report her from her post or her page.'**
  String get reportHerFromHerPostOrHer;

  /// No description provided for @youPickAReasonAndSendIt.
  ///
  /// In en, this message translates to:
  /// **'You pick a reason and send it.'**
  String get youPickAReasonAndSendIt;

  /// No description provided for @aWomanOnTheTeamReadsIt.
  ///
  /// In en, this message translates to:
  /// **'A woman on the team reads it.'**
  String get aWomanOnTheTeamReadsIt;

  /// No description provided for @sheTellsYouWhatSheDidAbout.
  ///
  /// In en, this message translates to:
  /// **'She tells you what she did about it.'**
  String get sheTellsYouWhatSheDidAbout;

  /// The small half of the ring on her first week: how many steps the arc has. The number is a value, and the arc is shorter when a step belongs to a feature this build has switched off, so it cannot be frozen into the sentence.
  ///
  /// In en, this message translates to:
  /// **'of {total}'**
  String ofTotal(String total);

  /// No description provided for @deletingTakesAwayEverythingYouHavePut_g3hy0.
  ///
  /// In en, this message translates to:
  /// **'Deleting takes away everything you have put into the app: your meals, your workouts, your measurements, your cycle and your answers. It happens at once, and none of it can be brought back.'**
  String get deletingTakesAwayEverythingYouHavePut_g3hy0;

  /// No description provided for @yourTrainingWeekByWeek.
  ///
  /// In en, this message translates to:
  /// **'Your training, week by week'**
  String get yourTrainingWeekByWeek;

  /// No description provided for @thisAppCountsWeeksNotDaysAnd.
  ///
  /// In en, this message translates to:
  /// **'This app counts weeks, not days, and only what you add yourself.'**
  String get thisAppCountsWeeksNotDaysAnd;

  /// No description provided for @fourShortQuestionsThenYourWeekIs.
  ///
  /// In en, this message translates to:
  /// **'Four short questions, then your week is ready. Skip any of them.'**
  String get fourShortQuestionsThenYourWeekIs;

  /// No description provided for @yourGoalYourDaysAndWhatYou.
  ///
  /// In en, this message translates to:
  /// **'Your goal, your days and what you train with'**
  String get yourGoalYourDaysAndWhatYou;

  /// No description provided for @reachYourGoalAndTheWeekCounts.
  ///
  /// In en, this message translates to:
  /// **'Reach your goal and the week counts, and a week you miss is covered by a rest week once you have earned one.'**
  String get reachYourGoalAndTheWeekCounts;

  /// No description provided for @yourWeekCountsWhenYouFinishYour.
  ///
  /// In en, this message translates to:
  /// **'Your week counts when you finish your sessions. No single day is the one you must train on.'**
  String get yourWeekCountsWhenYouFinishYour;

  /// No description provided for @onlyYouEverSeeThis.
  ///
  /// In en, this message translates to:
  /// **'Only you ever see this.'**
  String get onlyYouEverSeeThis;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @downloadThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Download this week'**
  String get downloadThisWeek;

  /// No description provided for @turnNotificationsOnSoWeCanNudge.
  ///
  /// In en, this message translates to:
  /// **'Turn notifications on, so we can nudge you at your usual time.'**
  String get turnNotificationsOnSoWeCanNudge;

  /// No description provided for @noHistoryForThisMoveYetWhat.
  ///
  /// In en, this message translates to:
  /// **'No history for this move yet. What you do today is what the next one is measured against.'**
  String get noHistoryForThisMoveYetWhat;

  /// No description provided for @theLibraryIsStillBeingWrittenWhat.
  ///
  /// In en, this message translates to:
  /// **'The library is still being written. What is here is what the app ships with today.'**
  String get theLibraryIsStillBeingWrittenWhat;

  /// No description provided for @nothingMatchesThoseFilters.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches those filters.'**
  String get nothingMatchesThoseFilters;

  /// R03's summary of today's session. Counted off the day's own moves, never a fixed '5 moves'.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes, {moves} moves'**
  String minutesMinutesMovesMoves(String minutes, String moves);

  /// R07's progression note, drawn only when she has a logged set for this move and today's prescription is heavier.
  ///
  /// In en, this message translates to:
  /// **'Last time: {last}. So we added {added} kg.'**
  String lastTimeLastSoWeAddedAdded(String last, String added);

  /// R07's progression note when she has a logged set for this move and nothing was added.
  ///
  /// In en, this message translates to:
  /// **'Last time: {last}.'**
  String lastTimeLast(String last);

  /// No description provided for @lunchYourUsual.
  ///
  /// In en, this message translates to:
  /// **'Lunch, your usual'**
  String get lunchYourUsual;

  /// No description provided for @snackYourUsual.
  ///
  /// In en, this message translates to:
  /// **'Snack, your usual'**
  String get snackYourUsual;

  /// No description provided for @saturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get saturday;

  /// No description provided for @sunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunday;

  /// No description provided for @noProgramYet.
  ///
  /// In en, this message translates to:
  /// **'No program yet'**
  String get noProgramYet;

  /// No description provided for @aProgramSetsOutYourWeeksAnd.
  ///
  /// In en, this message translates to:
  /// **'A program sets out your weeks and the days in them. Nothing is written for you yet. One session is ready now, and Start today\'s session opens it.'**
  String get aProgramSetsOutYourWeeksAnd;

  /// No description provided for @holdTheCardStill.
  ///
  /// In en, this message translates to:
  /// **'Hold the card still'**
  String get holdTheCardStill;

  /// No description provided for @moveALittleCloser.
  ///
  /// In en, this message translates to:
  /// **'Move a little closer'**
  String get moveALittleCloser;

  /// No description provided for @moveBackALittle.
  ///
  /// In en, this message translates to:
  /// **'Move back a little'**
  String get moveBackALittle;

  /// No description provided for @thereIsNotEnoughLight.
  ///
  /// In en, this message translates to:
  /// **'There is not enough light'**
  String get thereIsNotEnoughLight;

  /// No description provided for @bringYourFaceIntoTheCircle.
  ///
  /// In en, this message translates to:
  /// **'Bring your face into the circle'**
  String get bringYourFaceIntoTheCircle;

  /// No description provided for @lookStraightAhead.
  ///
  /// In en, this message translates to:
  /// **'Look straight ahead'**
  String get lookStraightAhead;

  /// No description provided for @blinkSlowly.
  ///
  /// In en, this message translates to:
  /// **'Blink slowly'**
  String get blinkSlowly;

  /// No description provided for @turnYourHeadSlightlyToTheRight.
  ///
  /// In en, this message translates to:
  /// **'Turn your head slightly to the right'**
  String get turnYourHeadSlightlyToTheRight;

  /// No description provided for @turnYourHeadSlightlyToTheLeft.
  ///
  /// In en, this message translates to:
  /// **'Turn your head slightly to the left'**
  String get turnYourHeadSlightlyToTheLeft;

  /// No description provided for @holdStill.
  ///
  /// In en, this message translates to:
  /// **'Hold still'**
  String get holdStill;

  /// No description provided for @tiltTheCardToCutTheGlare.
  ///
  /// In en, this message translates to:
  /// **'Tilt the card to cut the glare'**
  String get tiltTheCardToCutTheGlare;

  /// No description provided for @onlyOneFaceInTheFrame.
  ///
  /// In en, this message translates to:
  /// **'Only one face in the frame'**
  String get onlyOneFaceInTheFrame;

  /// No description provided for @showTheFrontOfTheCard.
  ///
  /// In en, this message translates to:
  /// **'Show the front of the card'**
  String get showTheFrontOfTheCard;

  /// No description provided for @theBackOfYourCard.
  ///
  /// In en, this message translates to:
  /// **'The back of your card'**
  String get theBackOfYourCard;

  /// No description provided for @backOfTheCard.
  ///
  /// In en, this message translates to:
  /// **'back of the card'**
  String get backOfTheCard;

  /// No description provided for @turnTheCardOver.
  ///
  /// In en, this message translates to:
  /// **'Turn the card over'**
  String get turnTheCardOver;

  /// No description provided for @weReadBothSidesNothingIsUploaded.
  ///
  /// In en, this message translates to:
  /// **'We read both sides. Nothing is uploaded until you tap send.'**
  String get weReadBothSidesNothingIsUploaded;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @underReview.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get underReview;

  /// No description provided for @verificationUnsuccessful.
  ///
  /// In en, this message translates to:
  /// **'Verification unsuccessful'**
  String get verificationUnsuccessful;

  /// No description provided for @pleaseRetakeThePhoto.
  ///
  /// In en, this message translates to:
  /// **'Please retake the photo'**
  String get pleaseRetakeThePhoto;

  /// No description provided for @beforeTheCameraOpens.
  ///
  /// In en, this message translates to:
  /// **'Before the camera opens'**
  String get beforeTheCameraOpens;

  /// No description provided for @youWillPhotographTheFrontAndBack.
  ///
  /// In en, this message translates to:
  /// **'You will photograph the front and back of your national ID card, then take a short selfie.'**
  String get youWillPhotographTheFrontAndBack;

  /// No description provided for @thePhotographsAreProcessedByGoogleCloud.
  ///
  /// In en, this message translates to:
  /// **'The photographs are processed by Google Cloud and Amazon Web Services, on servers outside Egypt.'**
  String get thePhotographsAreProcessedByGoogleCloud;

  /// No description provided for @ifYourCheckIsApprovedOrRefused.
  ///
  /// In en, this message translates to:
  /// **'If your check is approved or refused, nothing is kept except a one way keyed hash of your ID number. It cannot be turned back into the number.'**
  String get ifYourCheckIsApprovedOrRefused;

  /// No description provided for @theCameraIsTheOnlyWayIn.
  ///
  /// In en, this message translates to:
  /// **'The camera is the only way in. You cannot choose a picture you already have.'**
  String get theCameraIsTheOnlyWayIn;

  /// No description provided for @iAgreeStartTheCamera.
  ///
  /// In en, this message translates to:
  /// **'I agree, start the camera'**
  String get iAgreeStartTheCamera;

  /// No description provided for @iWouldRatherNot.
  ///
  /// In en, this message translates to:
  /// **'I would rather not'**
  String get iWouldRatherNot;

  /// No description provided for @weCannotRunThisStepOnYour.
  ///
  /// In en, this message translates to:
  /// **'We cannot run this step on your phone right now. A woman can check your card instead.'**
  String get weCannotRunThisStepOnYour;

  /// Progress through the server-chosen liveness challenge on C11. The number of steps is decided by the server per session, so it cannot be baked into the sentence the way the other Step strings in this dictionary are.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String stepStepOfTotal(String step, String total);

  /// No description provided for @aShortVideoCallWithAWoman.
  ///
  /// In en, this message translates to:
  /// **'A short video call with a woman'**
  String get aShortVideoCallWithAWoman;

  /// No description provided for @nothingYouPhotographedIsStoredItWas.
  ///
  /// In en, this message translates to:
  /// **'Nothing you photographed is stored. It was deleted the moment the check finished.'**
  String get nothingYouPhotographedIsStoredItWas;

  /// No description provided for @theAppOpensAsSoonAsYour.
  ///
  /// In en, this message translates to:
  /// **'The app opens as soon as your check is done.'**
  String get theAppOpensAsSoonAsYour;

  /// No description provided for @nothingYouPhotographIsKeptBothSides.
  ///
  /// In en, this message translates to:
  /// **'Nothing you photograph is kept. Both sides of the card and the selfie are deleted as soon as the check finishes, whatever the result.'**
  String get nothingYouPhotographIsKeptBothSides;

  /// No description provided for @ifAWomanNeedsToCheckIt.
  ///
  /// In en, this message translates to:
  /// **'If a woman needs to check, it is a short video call with you. Your photographs are never sent to anyone.'**
  String get ifAWomanNeedsToCheckIt;

  /// No description provided for @thePhotographsAreProcessedByGoogleCloud_tqchn.
  ///
  /// In en, this message translates to:
  /// **'The photographs are processed by Google Cloud, on servers outside Egypt.'**
  String get thePhotographsAreProcessedByGoogleCloud_tqchn;

  /// No description provided for @gluten_1v1e1.
  ///
  /// In en, this message translates to:
  /// **'Gluten'**
  String get gluten_1v1e1;

  /// No description provided for @crustaceans.
  ///
  /// In en, this message translates to:
  /// **'Crustaceans'**
  String get crustaceans;

  /// No description provided for @eggs.
  ///
  /// In en, this message translates to:
  /// **'Eggs'**
  String get eggs;

  /// No description provided for @fish.
  ///
  /// In en, this message translates to:
  /// **'Fish'**
  String get fish;

  /// No description provided for @peanuts.
  ///
  /// In en, this message translates to:
  /// **'Peanuts'**
  String get peanuts;

  /// No description provided for @soy.
  ///
  /// In en, this message translates to:
  /// **'Soy'**
  String get soy;

  /// No description provided for @milkAndDairy.
  ///
  /// In en, this message translates to:
  /// **'Milk and dairy'**
  String get milkAndDairy;

  /// No description provided for @treeNuts.
  ///
  /// In en, this message translates to:
  /// **'Tree nuts'**
  String get treeNuts;

  /// No description provided for @celery.
  ///
  /// In en, this message translates to:
  /// **'Celery'**
  String get celery;

  /// No description provided for @mustard.
  ///
  /// In en, this message translates to:
  /// **'Mustard'**
  String get mustard;

  /// No description provided for @sesame.
  ///
  /// In en, this message translates to:
  /// **'Sesame'**
  String get sesame;

  /// No description provided for @sulphites.
  ///
  /// In en, this message translates to:
  /// **'Sulphites'**
  String get sulphites;

  /// No description provided for @lupin.
  ///
  /// In en, this message translates to:
  /// **'Lupin'**
  String get lupin;

  /// No description provided for @molluscs.
  ///
  /// In en, this message translates to:
  /// **'Molluscs'**
  String get molluscs;

  /// No description provided for @favaBeans.
  ///
  /// In en, this message translates to:
  /// **'Fava beans'**
  String get favaBeans;

  /// No description provided for @coconut.
  ///
  /// In en, this message translates to:
  /// **'Coconut'**
  String get coconut;

  /// No description provided for @isThereAnythingYouCannotEat.
  ///
  /// In en, this message translates to:
  /// **'Is there anything you cannot eat?'**
  String get isThereAnythingYouCannotEat;

  /// No description provided for @tickAnythingYouAvoidDishesThatContain.
  ///
  /// In en, this message translates to:
  /// **'Tick anything you avoid. Dishes that contain it are hidden from your recipes.'**
  String get tickAnythingYouAvoidDishesThatContain;

  /// No description provided for @noNothing.
  ///
  /// In en, this message translates to:
  /// **'No, nothing'**
  String get noNothing;

  /// No description provided for @saveWhatIAvoid.
  ///
  /// In en, this message translates to:
  /// **'Save what I avoid'**
  String get saveWhatIAvoid;

  /// No description provided for @youCanChangeThisAnyTimeFrom.
  ///
  /// In en, this message translates to:
  /// **'You can change this any time from your account.'**
  String get youCanChangeThisAnyTimeFrom;

  /// No description provided for @favaBeansAreListedBecauseOfFavism.
  ///
  /// In en, this message translates to:
  /// **'Fava beans are listed because of favism, not because they are an allergen.'**
  String get favaBeansAreListedBecauseOfFavism;

  /// No description provided for @rahmasRecipes.
  ///
  /// In en, this message translates to:
  /// **'Rahma\'s recipes'**
  String get rahmasRecipes;

  /// No description provided for @searchRecipes.
  ///
  /// In en, this message translates to:
  /// **'Search recipes'**
  String get searchRecipes;

  /// No description provided for @noOven.
  ///
  /// In en, this message translates to:
  /// **'No oven'**
  String get noOven;

  /// No description provided for @readyInTheFridge.
  ///
  /// In en, this message translates to:
  /// **'Ready in the fridge'**
  String get readyInTheFridge;

  /// No description provided for @quickCombinations.
  ///
  /// In en, this message translates to:
  /// **'Quick combinations'**
  String get quickCombinations;

  /// No description provided for @aMessageFromRahma.
  ///
  /// In en, this message translates to:
  /// **'A message from Rahma'**
  String get aMessageFromRahma;

  /// No description provided for @nothingMatchesThat.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches that.'**
  String get nothingMatchesThat;

  /// No description provided for @noCombinationsAreBuiltYetEachOne.
  ///
  /// In en, this message translates to:
  /// **'No combinations are built yet. Each one needs foods whose values have been verified.'**
  String get noCombinationsAreBuiltYetEachOne;

  /// No description provided for @ingredientsAndSteps.
  ///
  /// In en, this message translates to:
  /// **'Ingredients and steps'**
  String get ingredientsAndSteps;

  /// No description provided for @asItIsInTheBook.
  ///
  /// In en, this message translates to:
  /// **'As it is in the book'**
  String get asItIsInTheBook;

  /// No description provided for @steps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get steps;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @servedWith.
  ///
  /// In en, this message translates to:
  /// **'Served with'**
  String get servedWith;

  /// No description provided for @cookMode.
  ///
  /// In en, this message translates to:
  /// **'Cook mode'**
  String get cookMode;

  /// No description provided for @nextStep.
  ///
  /// In en, this message translates to:
  /// **'Next step'**
  String get nextStep;

  /// No description provided for @previousStep.
  ///
  /// In en, this message translates to:
  /// **'Previous step'**
  String get previousStep;

  /// No description provided for @contains.
  ///
  /// In en, this message translates to:
  /// **'Contains'**
  String get contains;

  /// No description provided for @containsNoneOfTheSixteenWeCheck.
  ///
  /// In en, this message translates to:
  /// **'Contains none of the sixteen we check for.'**
  String get containsNoneOfTheSixteenWeCheck;

  /// No description provided for @nobodyHasSignedOffWhatIsIn.
  ///
  /// In en, this message translates to:
  /// **'Nobody has signed off what is in this dish. Read the label on each product yourself.'**
  String get nobodyHasSignedOffWhatIsIn;

  /// No description provided for @theWeightsAreEstimatesExceptWhereThe.
  ///
  /// In en, this message translates to:
  /// **'The weights are estimates except where the book states them.'**
  String get theWeightsAreEstimatesExceptWhereThe;

  /// No description provided for @theIngredientsAreRahmasReadTheLabel.
  ///
  /// In en, this message translates to:
  /// **'The ingredients are Rahma\'s. Read the label on each product yourself before use.'**
  String get theIngredientsAreRahmasReadTheLabel;

  /// No description provided for @howToTellItIsDone.
  ///
  /// In en, this message translates to:
  /// **'How to tell it is done'**
  String get howToTellItIsDone;

  /// No description provided for @chickenIsDoneWhenNoPinkIs.
  ///
  /// In en, this message translates to:
  /// **'Chicken is done when no pink is left and the juices run clear.'**
  String get chickenIsDoneWhenNoPinkIs;

  /// No description provided for @mincedMeatIsDoneWhenNoPink.
  ///
  /// In en, this message translates to:
  /// **'Minced meat is done when no pink is left anywhere in it.'**
  String get mincedMeatIsDoneWhenNoPink;

  /// No description provided for @liverIsDoneWhenItIsFirm.
  ///
  /// In en, this message translates to:
  /// **'Liver is done when it is firm and does not bleed when cut.'**
  String get liverIsDoneWhenItIsFirm;

  /// No description provided for @shrimpIsDoneWhenItTurnsOpaque.
  ///
  /// In en, this message translates to:
  /// **'Shrimp is done when it turns opaque all through and curls.'**
  String get shrimpIsDoneWhenItTurnsOpaque;

  /// No description provided for @eggIsDoneWhenTheWhiteIs.
  ///
  /// In en, this message translates to:
  /// **'Egg is done when the white is set right through.'**
  String get eggIsDoneWhenTheWhiteIs;

  /// No description provided for @liverIsVeryHighInVitaminA.
  ///
  /// In en, this message translates to:
  /// **'Liver is very high in vitamin A. If you are pregnant, ask your doctor before eating it.'**
  String get liverIsVeryHighInVitaminA;

  /// No description provided for @thisDishContainsFavaBeansIfYou.
  ///
  /// In en, this message translates to:
  /// **'This dish contains fava beans. If you have favism, an inherited enzyme condition, avoid it.'**
  String get thisDishContainsFavaBeansIfYou;

  /// No description provided for @thisRecipeIsFromRahmasBook.
  ///
  /// In en, this message translates to:
  /// **'This recipe is from Rahma\'s book.'**
  String get thisRecipeIsFromRahmasBook;

  /// No description provided for @aCombinationNotARecipeNothingIs.
  ///
  /// In en, this message translates to:
  /// **'A combination, not a recipe. Nothing is cooked.'**
  String get aCombinationNotARecipeNothingIs;

  /// No description provided for @theBookDoesNotSay.
  ///
  /// In en, this message translates to:
  /// **'The book does not say.'**
  String get theBookDoesNotSay;

  /// No description provided for @changeWhatYouAvoid.
  ///
  /// In en, this message translates to:
  /// **'Change what you avoid'**
  String get changeWhatYouAvoid;

  /// No description provided for @whatYouAvoid.
  ///
  /// In en, this message translates to:
  /// **'What you avoid'**
  String get whatYouAvoid;

  /// No description provided for @showTheBookPage.
  ///
  /// In en, this message translates to:
  /// **'Show the book page'**
  String get showTheBookPage;

  /// A cooking time on a recipe card. The figure comes from the recipe, never from the dictionary.
  ///
  /// In en, this message translates to:
  /// **'{n} min'**
  String nMin(String n);

  /// Protein per serving on a recipe card, only when the recipe states it.
  ///
  /// In en, this message translates to:
  /// **'{n} g protein'**
  String nGProtein(String n);

  /// Cost per serving, shown beside the month it was priced in.
  ///
  /// In en, this message translates to:
  /// **'{n} EGP a serving'**
  String nEgpAServing(String n);

  /// Energy per serving, only when it was summed from verified foods.
  ///
  /// In en, this message translates to:
  /// **'{n} kcal a serving'**
  String nKcalAServing(String n);

  /// The month an EGP figure was priced in. An undated price in Egypt is wrong within a quarter.
  ///
  /// In en, this message translates to:
  /// **'Priced {month}'**
  String pricedMonth(String month);

  /// A gram figure beside an ingredient, in her own words' shadow.
  ///
  /// In en, this message translates to:
  /// **'{n} g'**
  String nG(String n);

  /// Cook mode's position line.
  ///
  /// In en, this message translates to:
  /// **'Step {n} of {total}'**
  String stepNOfTotal(String n, String total);

  /// An oven temperature chip on a step.
  ///
  /// In en, this message translates to:
  /// **'{temp} degrees'**
  String tempDegrees(String temp);

  /// How many the recipe feeds, only when the book says.
  ///
  /// In en, this message translates to:
  /// **'Serves {n}'**
  String servesN(String n);

  /// E05, at the foot of Rahma's book. The reason the app is holding dishes back is that nobody has signed the allergen check, NOT anything she named. Arabic counts do not agree the way English ones do, so this is a plural message rather than one sentence with a number dropped into it: 39 takes the singular accusative.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 dish is hidden because nobody has checked what is in it yet.} other{{count} dishes are hidden because nobody has checked what is in them yet.}}'**
  String countPluralOne1DishIsHidden(int count);

  /// E05, at the foot of Rahma's book. The other reason a dish is held back, and it must read differently from the unchecked one: this one IS about her body.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 dish is hidden because it contains something you avoid.} other{{count} dishes are hidden because they contain something you avoid.}}'**
  String countPluralOne1DishIsHidden_1hlr5(int count);

  /// No description provided for @noDishHereHasBeenCheckedYet.
  ///
  /// In en, this message translates to:
  /// **'No dish here has been checked yet. This is not about what you avoid: nobody has signed off what is in these dishes, so the book waits.'**
  String get noDishHereHasBeenCheckedYet;

  /// No description provided for @everythingHereContainsSomethingYouToldUs.
  ///
  /// In en, this message translates to:
  /// **'Everything here contains something you told us you avoid.'**
  String get everythingHereContainsSomethingYouToldUs;

  /// No description provided for @nothingInTheBookHasBeenChecked.
  ///
  /// In en, this message translates to:
  /// **'Nothing in the book has been checked yet. Tell us about an allergy and the book waits until somebody has.'**
  String get nothingInTheBookHasBeenChecked;

  /// No description provided for @notCheckedYet.
  ///
  /// In en, this message translates to:
  /// **'Not checked yet'**
  String get notCheckedYet;

  /// No description provided for @discardWhatYouTicked.
  ///
  /// In en, this message translates to:
  /// **'Discard what you ticked?'**
  String get discardWhatYouTicked;

  /// No description provided for @youTickedSomethingYouAvoidTheOther.
  ///
  /// In en, this message translates to:
  /// **'You ticked something you avoid. The other answer saves an empty list instead.'**
  String get youTickedSomethingYouAvoidTheOther;

  /// No description provided for @keepWhatITicked.
  ///
  /// In en, this message translates to:
  /// **'Keep what I ticked'**
  String get keepWhatITicked;

  /// No description provided for @yesSaveNothing.
  ///
  /// In en, this message translates to:
  /// **'Yes, save nothing'**
  String get yesSaveNothing;

  /// No description provided for @theBookNamesWhatGoesInAnd.
  ///
  /// In en, this message translates to:
  /// **'The book names what goes in, and mostly not how much.'**
  String get theBookNamesWhatGoesInAnd;

  /// No description provided for @theBookWritesThisOneAsA.
  ///
  /// In en, this message translates to:
  /// **'The book writes this one as a method, with no ingredient list. What goes in is named in the steps.'**
  String get theBookWritesThisOneAsA;

  /// A recipe's active time. Overnight oats is five minutes of work and a day in the fridge, and the card stated 1,445.
  ///
  /// In en, this message translates to:
  /// **'{n} min hands on'**
  String nMinHandsOn(String n);

  /// A recipe's total time, beside the hands-on figure, for a dish under two hours.
  ///
  /// In en, this message translates to:
  /// **'{n} min in all'**
  String nMinInAll(String n);

  /// A recipe's total time once it passes two hours. Rounded to the hour and said to be rounded, because 1,445 minutes is true and unreadable.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{About 1 hour in all} other{About {count} hours in all}}'**
  String countPluralOneAbout1HourIn(int count);

  /// No description provided for @noRecipeHasBeenPricedYet.
  ///
  /// In en, this message translates to:
  /// **'No recipe has been priced yet.'**
  String get noRecipeHasBeenPricedYet;

  /// No description provided for @noRecipeCanBeCalledNutFree.
  ///
  /// In en, this message translates to:
  /// **'No recipe can be called nut free yet, because nobody has signed off what is in them.'**
  String get noRecipeCanBeCalledNutFree;

  /// No description provided for @noneOfTheseDishesHasBeenChecked.
  ///
  /// In en, this message translates to:
  /// **'None of these dishes has been checked for what you avoid, so none of them is shown.'**
  String get noneOfTheseDishesHasBeenChecked;

  /// No description provided for @pelvicFloorFirstOnceYourDoctorSays.
  ///
  /// In en, this message translates to:
  /// **'Pelvic floor first, once your doctor says you are ready'**
  String get pelvicFloorFirstOnceYourDoctorSays;

  /// No description provided for @gentlerMovementsNothingOnTheBelly.
  ///
  /// In en, this message translates to:
  /// **'Gentler movements, nothing on the belly'**
  String get gentlerMovementsNothingOnTheBelly;

  /// No description provided for @weDoNotHaveACareDirectory.
  ///
  /// In en, this message translates to:
  /// **'We do not have a care directory for your city yet.'**
  String get weDoNotHaveACareDirectory;

  /// No description provided for @weDoNotHaveAGuidancePage.
  ///
  /// In en, this message translates to:
  /// **'We do not have a guidance page to open yet.'**
  String get weDoNotHaveAGuidancePage;

  /// No description provided for @finishingThemAllIsNotADeadline.
  ///
  /// In en, this message translates to:
  /// **'Finishing them all is not a deadline. It is the shortest path to knowing where everything is.'**
  String get finishingThemAllIsNotADeadline;

  /// No description provided for @allDoneNothingAboutTheAppChanges.
  ///
  /// In en, this message translates to:
  /// **'All done. Nothing about the app changes from here. You have just already used every part of it once.'**
  String get allDoneNothingAboutTheAppChanges;

  /// No description provided for @notBuiltYetThisPartOfThe.
  ///
  /// In en, this message translates to:
  /// **'Not built yet. This part of the app is not in this release.'**
  String get notBuiltYetThisPartOfThe;

  /// No description provided for @weCannotFindThatPage.
  ///
  /// In en, this message translates to:
  /// **'We cannot find that page.'**
  String get weCannotFindThatPage;

  /// No description provided for @weCouldNotReadTheFrontOf.
  ///
  /// In en, this message translates to:
  /// **'We could not read the front of your card. Hold it flat and try again.'**
  String get weCouldNotReadTheFrontOf;

  /// No description provided for @weCouldNotReadTheBackOf.
  ///
  /// In en, this message translates to:
  /// **'We could not read the back of your card. Hold it flat and try again.'**
  String get weCouldNotReadTheBackOf;

  /// No description provided for @noneOfTheseDishesHasBeenChecked_9ic16.
  ///
  /// In en, this message translates to:
  /// **'None of these dishes has been checked for nuts.'**
  String get noneOfTheseDishesHasBeenChecked_9ic16;

  /// No description provided for @lunchYourUsual_1wxfd.
  ///
  /// In en, this message translates to:
  /// **'Lunch, your usual?'**
  String get lunchYourUsual_1wxfd;

  /// No description provided for @dinnerYourUsual_1rqgs.
  ///
  /// In en, this message translates to:
  /// **'Dinner, your usual?'**
  String get dinnerYourUsual_1rqgs;

  /// No description provided for @snackYourUsual_nkmpd.
  ///
  /// In en, this message translates to:
  /// **'Snack, your usual?'**
  String get snackYourUsual_nkmpd;

  /// No description provided for @weSaveYourAnswerWithTheRest.
  ///
  /// In en, this message translates to:
  /// **'We save your answer with the rest of your setup. Nothing in your sessions changes from it yet.'**
  String get weSaveYourAnswerWithTheRest;

  /// No description provided for @nobodyHasSignedOffWhatIsIn_127cj.
  ///
  /// In en, this message translates to:
  /// **'Nobody has signed off what is in these dishes yet, so none is shown. That is our check, not your list.'**
  String get nobodyHasSignedOffWhatIsIn_127cj;

  /// No description provided for @nothingIsPlannedForThisWeekYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing is planned for this week yet. Pick a dinner for any day below.'**
  String get nothingIsPlannedForThisWeekYet;

  /// No description provided for @lookingForWhatYouHaveAdded.
  ///
  /// In en, this message translates to:
  /// **'Looking for what you have added.'**
  String get lookingForWhatYouHaveAdded;

  /// No description provided for @weCouldNotSaveYourAgreementSo.
  ///
  /// In en, this message translates to:
  /// **'We could not save your agreement, so the camera has not opened. Check your connection and try again.'**
  String get weCouldNotSaveYourAgreementSo;

  /// No description provided for @backUpMyHealthData.
  ///
  /// In en, this message translates to:
  /// **'Back up my health data'**
  String get backUpMyHealthData;

  /// No description provided for @offYourCycleCheckInsMeasurementsLife.
  ///
  /// In en, this message translates to:
  /// **'Off. Your cycle, check-ins, measurements, life stage and allergies stay on this phone only.'**
  String get offYourCycleCheckInsMeasurementsLife;

  /// No description provided for @onACopyIsKeptInYour.
  ///
  /// In en, this message translates to:
  /// **'On. A copy is kept in your Own Hub account, stored in Germany.'**
  String get onACopyIsKeptInYour;

  /// No description provided for @backUpYourHealthData.
  ///
  /// In en, this message translates to:
  /// **'Back up your health data?'**
  String get backUpYourHealthData;

  /// No description provided for @ifYouTurnThisOnACopy.
  ///
  /// In en, this message translates to:
  /// **'If you turn this on, a copy of your cycle and period dates, daily check-ins, body measurements including weight, your pregnancy, postpartum or injury stage, and your allergies is kept in your Own Hub account, so it comes back if you change phones.'**
  String get ifYouTurnThisOnACopy;

  /// No description provided for @theCopyIsStoredOnGoogleCloud.
  ///
  /// In en, this message translates to:
  /// **'The copy is stored on Google Cloud in Frankfurt, Germany, which is outside Egypt. The phone number you sign in with is held by Firebase Authentication, which may store it in the United States.'**
  String get theCopyIsStoredOnGoogleCloud;

  /// No description provided for @thisIsHealthDataSoWeOnly.
  ///
  /// In en, this message translates to:
  /// **'This is health data, so we only back it up with your clear agreement. You can turn it off at any time, and turning it off deletes the copy from your account.'**
  String get thisIsHealthDataSoWeOnly;

  /// No description provided for @ifYouDoNotTurnItOn.
  ///
  /// In en, this message translates to:
  /// **'If you do not turn it on, nothing else changes. Your health data simply stays on this phone only.'**
  String get ifYouDoNotTurnItOn;

  /// No description provided for @iAgreeBackUpMyHealthData.
  ///
  /// In en, this message translates to:
  /// **'I agree, back up my health data'**
  String get iAgreeBackUpMyHealthData;

  /// No description provided for @weCouldNotReachOwnHubSo.
  ///
  /// In en, this message translates to:
  /// **'We could not reach Own Hub, so your health backup was not changed. Check your connection and try again.'**
  String get weCouldNotReachOwnHubSo;

  /// No description provided for @checkedByOwnHubsOwnSystemYour.
  ///
  /// In en, this message translates to:
  /// **'Checked by Own Hub\'s own system. Your ID and selfie photos are never stored. Tap to read exactly what is kept.'**
  String get checkedByOwnHubsOwnSystemYour;

  /// No description provided for @ifYouDoNotShowYourFace.
  ///
  /// In en, this message translates to:
  /// **'If you do not show your face to a camera, nothing here asks you to. A woman reviewer from Own Hub will phone you to arrange a short video call, and she will check your ID card with you on that call.'**
  String get ifYouDoNotShowYourFace;

  /// No description provided for @askForAVideoCheck.
  ///
  /// In en, this message translates to:
  /// **'Ask for a video check'**
  String get askForAVideoCheck;

  /// No description provided for @theAutomaticCheckCouldNotStartJust.
  ///
  /// In en, this message translates to:
  /// **'The automatic check could not start just now. You can ask a woman reviewer instead, or go back and try again.'**
  String get theAutomaticCheckCouldNotStartJust;

  /// No description provided for @weCouldNotReachOwnHubSo_3usbb.
  ///
  /// In en, this message translates to:
  /// **'We could not reach Own Hub, so you are not in the queue yet. Check your connection and try again.'**
  String get weCouldNotReachOwnHubSo_3usbb;

  /// No description provided for @youHaveAskedForAReviewerToo.
  ///
  /// In en, this message translates to:
  /// **'You have asked for a reviewer too many times today. Please try again tomorrow.'**
  String get youHaveAskedForAReviewerToo;

  /// No description provided for @aWomanReviewerFromOwnHubWill.
  ///
  /// In en, this message translates to:
  /// **'A woman reviewer from Own Hub will phone you to arrange a short video call. We do not send text messages about this.'**
  String get aWomanReviewerFromOwnHubWill;

  /// C14 once a woman reviewer has booked the live video check. time is the booked date and time, already formatted for her locale.
  ///
  /// In en, this message translates to:
  /// **'Your video call is booked for {time}.'**
  String yourVideoCallIsBookedForTime(String time);

  /// No description provided for @yourReviewTimeRanOut.
  ///
  /// In en, this message translates to:
  /// **'Your review time ran out'**
  String get yourReviewTimeRanOut;

  /// No description provided for @weDidNotReachYourReviewIn.
  ///
  /// In en, this message translates to:
  /// **'We did not reach your review in time. You can take the check again.'**
  String get weDidNotReachYourReviewIn;

  /// No description provided for @takeTheCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Take the check again'**
  String get takeTheCheckAgain;

  /// No description provided for @weCouldNotVerifyYourAccount.
  ///
  /// In en, this message translates to:
  /// **'We could not verify your account'**
  String get weCouldNotVerifyYourAccount;

  /// No description provided for @youCanDeleteYourAccountAndEverything.
  ///
  /// In en, this message translates to:
  /// **'You can delete your account and everything we hold about you from Profile and settings, under Your data.'**
  String get youCanDeleteYourAccountAndEverything;

  /// No description provided for @openProfileAndSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Profile and settings'**
  String get openProfileAndSettings;

  /// No description provided for @lookAroundWhileYouWait.
  ///
  /// In en, this message translates to:
  /// **'Look around while you wait'**
  String get lookAroundWhileYouWait;

  /// No description provided for @tryAgainTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Try again tomorrow'**
  String get tryAgainTomorrow;

  /// No description provided for @todaysLimitForIdentityChecksHasBeen.
  ///
  /// In en, this message translates to:
  /// **'Today\'s limit for identity checks has been reached. Nothing was decided, and nothing you photographed was kept. Please try again tomorrow.'**
  String get todaysLimitForIdentityChecksHasBeen;

  /// No description provided for @noAutomaticChecksLeft.
  ///
  /// In en, this message translates to:
  /// **'No automatic checks left'**
  String get noAutomaticChecksLeft;

  /// No description provided for @thisAccountHasUsedEveryAutomaticCheck.
  ///
  /// In en, this message translates to:
  /// **'This account has used every automatic check it can. Nothing you photographed was kept. A woman reviewer can check you on a short video call instead.'**
  String get thisAccountHasUsedEveryAutomaticCheck;

  /// No description provided for @askForAWomanReviewer.
  ///
  /// In en, this message translates to:
  /// **'Ask for a woman reviewer'**
  String get askForAWomanReviewer;

  /// No description provided for @weCouldNotReachOwnHub.
  ///
  /// In en, this message translates to:
  /// **'We could not reach Own Hub'**
  String get weCouldNotReachOwnHub;

  /// No description provided for @nothingWasDecidedAndYouAreNot.
  ///
  /// In en, this message translates to:
  /// **'Nothing was decided and you are not in a queue. Check your connection and try again.'**
  String get nothingWasDecidedAndYouAreNot;

  /// No description provided for @yourPhoneNumberIsUsedOnlyTo.
  ///
  /// In en, this message translates to:
  /// **'Your phone number is used only to arrange this call.'**
  String get yourPhoneNumberIsUsedOnlyTo;

  /// No description provided for @thisCopyOfTheAppCannotReach.
  ///
  /// In en, this message translates to:
  /// **'This copy of the app cannot reach Own Hub'**
  String get thisCopyOfTheAppCannotReach;

  /// No description provided for @pleaseInstallTheLatestVersionFromThe.
  ///
  /// In en, this message translates to:
  /// **'Please install the latest version from the App Store or Google Play, then try again. Nothing was decided.'**
  String get pleaseInstallTheLatestVersionFromThe;

  /// No description provided for @thisCopyOfTheAppCannotReach_agbhf.
  ///
  /// In en, this message translates to:
  /// **'This copy of the app cannot reach Own Hub, so you are not in the queue. Please install the latest version from the App Store or Google Play.'**
  String get thisCopyOfTheAppCannotReach_agbhf;

  /// No description provided for @deletingYourAccountRemovesItFromOur.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account removes it from our servers and clears this phone. Three things are kept: a closed record that your ID card was used, so it cannot open another account, reports with your name taken out, and a record that the deletion happened.'**
  String get deletingYourAccountRemovesItFromOur;

  /// No description provided for @youHaveNoAccountOnThisPhone.
  ///
  /// In en, this message translates to:
  /// **'You have no account on this phone, so everything is stored here, and deleting clears it.'**
  String get youHaveNoAccountOnThisPhone;

  /// No description provided for @deletingYourAccountThisCanTakeA.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account. This can take a minute.'**
  String get deletingYourAccountThisCanTakeA;

  /// No description provided for @weCouldNotReachOwnHubSo_yfi5n.
  ///
  /// In en, this message translates to:
  /// **'We could not reach Own Hub, so nothing was deleted. Check your connection and try again.'**
  String get weCouldNotReachOwnHubSo_yfi5n;

  /// No description provided for @thisCopyOfTheAppCannotReach_qzcpf.
  ///
  /// In en, this message translates to:
  /// **'This copy of the app cannot reach Own Hub, so nothing was deleted. Please install the latest version from the App Store or Google Play.'**
  String get thisCopyOfTheAppCannotReach_qzcpf;

  /// No description provided for @yourDeletionDidNotFinishOnOur.
  ///
  /// In en, this message translates to:
  /// **'Your deletion did not finish on our side. It will finish automatically within the hour. This phone has been cleared.'**
  String get yourDeletionDidNotFinishOnOur;

  /// No description provided for @yourWorkoutsMealsAndSetupAnswersAre.
  ///
  /// In en, this message translates to:
  /// **'Your workouts, meals and setup answers are saved to your Own Hub account once you are verified. Your cycle, check-ins, weight and other health details stay on this phone unless you turn on the health backup. Photos of your ID card and your selfie are never stored.'**
  String get yourWorkoutsMealsAndSetupAnswersAre;

  /// No description provided for @healthBackupIsOffOnThisPhone.
  ///
  /// In en, this message translates to:
  /// **'Health backup is off on this phone, so nothing more is uploaded. We could not reach Own Hub, so the copy in your account will be removed when you are back online.'**
  String get healthBackupIsOffOnThisPhone;

  /// No description provided for @yourCheckIsDone.
  ///
  /// In en, this message translates to:
  /// **'Your check is done'**
  String get yourCheckIsDone;

  /// No description provided for @youAreVerifiedOpenOwnHubTo.
  ///
  /// In en, this message translates to:
  /// **'You are verified. Open Own Hub to carry on.'**
  String get youAreVerifiedOpenOwnHubTo;

  /// No description provided for @openOwnHub.
  ///
  /// In en, this message translates to:
  /// **'Open Own Hub'**
  String get openOwnHub;

  /// No description provided for @thisCopyOfTheAppCannotReach_1dlg6.
  ///
  /// In en, this message translates to:
  /// **'This copy of the app cannot reach Own Hub, so your agreement was not saved and the camera has not opened. Please install the latest version from the App Store or Google Play.'**
  String get thisCopyOfTheAppCannotReach_1dlg6;

  /// No description provided for @thisCopyOfTheAppCannotReach_mr83s.
  ///
  /// In en, this message translates to:
  /// **'This copy of the app cannot reach Own Hub, so your health backup was not changed. Please install the latest version from the App Store or Google Play.'**
  String get thisCopyOfTheAppCannotReach_mr83s;

  /// Shown when this copy of the app cannot reach Own Hub to delete her account. The address of the public delete-account page.
  ///
  /// In en, this message translates to:
  /// **'You can also delete your account on our website: {url}'**
  String youCanAlsoDeleteYourAccountOn(String url);

  /// No description provided for @aReviewerCanOnlyCallYouAfter.
  ///
  /// In en, this message translates to:
  /// **'A reviewer can only call you after you ask for the call. If you ask, a woman reviewer from Own Hub will phone you to arrange a short video call, and she will check your ID card with you on that call.'**
  String get aReviewerCanOnlyCallYouAfter;

  /// No description provided for @askForTheCall.
  ///
  /// In en, this message translates to:
  /// **'Ask for the call'**
  String get askForTheCall;

  /// No description provided for @theCheckDidNotFinish.
  ///
  /// In en, this message translates to:
  /// **'The check did not finish'**
  String get theCheckDidNotFinish;

  /// No description provided for @pleaseSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again'**
  String get pleaseSignInAgain;

  /// No description provided for @signInAgain.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get signInAgain;

  /// No description provided for @yourSignInIsNoLongerValid.
  ///
  /// In en, this message translates to:
  /// **'Your sign-in is no longer valid, so nothing was decided. Sign in again with your phone number, then carry on with your check.'**
  String get yourSignInIsNoLongerValid;

  /// No description provided for @yourSignInIsNoLongerValid_1cfl5.
  ///
  /// In en, this message translates to:
  /// **'Your sign-in is no longer valid, so your agreement was not saved and the camera has not opened. Please sign in again with your phone number.'**
  String get yourSignInIsNoLongerValid_1cfl5;

  /// No description provided for @yourSignInIsNoLongerValid_1y16r.
  ///
  /// In en, this message translates to:
  /// **'Your sign-in is no longer valid, so you are not in the queue. Please sign in again with your phone number.'**
  String get yourSignInIsNoLongerValid_1y16r;

  /// No description provided for @yourSignInIsNoLongerValid_1ccq0.
  ///
  /// In en, this message translates to:
  /// **'Your sign-in is no longer valid, so your health backup was not changed. Please sign in again with your phone number.'**
  String get yourSignInIsNoLongerValid_1ccq0;

  /// No description provided for @yourSignInIsNoLongerValid_1g4zq.
  ///
  /// In en, this message translates to:
  /// **'Your sign-in is no longer valid, so nothing was deleted. Please sign in again with your phone number and try again.'**
  String get yourSignInIsNoLongerValid_1g4zq;

  /// No description provided for @healthBackupIsOffOnThisPhone_1x622.
  ///
  /// In en, this message translates to:
  /// **'Health backup is off on this phone, so nothing more is uploaded. This copy of the app cannot reach Own Hub, so the copy in your account has not been removed yet. Please install the latest version from the App Store or Google Play.'**
  String get healthBackupIsOffOnThisPhone_1x622;

  /// No description provided for @healthBackupIsOffOnThisPhone_1x3p3.
  ///
  /// In en, this message translates to:
  /// **'Health backup is off on this phone, so nothing more is uploaded. Your sign-in is no longer valid, so the copy in your account has not been removed yet. Please sign in again with your phone number.'**
  String get healthBackupIsOffOnThisPhone_1x3p3;

  /// No description provided for @theAutomaticCheckCouldNotStartJust_1od6p.
  ///
  /// In en, this message translates to:
  /// **'The automatic check could not start just now. You can ask a woman reviewer instead, or try again.'**
  String get theAutomaticCheckCouldNotStartJust_1od6p;

  /// No description provided for @quietWorkoutsForHomeFoodYouAlready_u7fo9.
  ///
  /// In en, this message translates to:
  /// **'Quiet workouts for home, food you already cook, and a space only verified women can enter.'**
  String get quietWorkoutsForHomeFoodYouAlready_u7fo9;

  /// No description provided for @everyAccountIsVerifiedWithIdBefore_p7ucu.
  ///
  /// In en, this message translates to:
  /// **'Every account is verified with ID before she gets in.'**
  String get everyAccountIsVerifiedWithIdBefore_p7ucu;

  /// No description provided for @yourFullProgramOpensAfterTheCheck.
  ///
  /// In en, this message translates to:
  /// **'Your full program opens after the check'**
  String get yourFullProgramOpensAfterTheCheck;

  /// No description provided for @joinAndPassTheCheckOnceThen.
  ///
  /// In en, this message translates to:
  /// **'Join and pass the check once. Then your plan, every workout and every recipe are yours.'**
  String get joinAndPassTheCheckOnceThen;

  /// No description provided for @byJoiningYouAgreeToTheOwn.
  ///
  /// In en, this message translates to:
  /// **'By joining you agree to the Own Hub rules.'**
  String get byJoiningYouAgreeToTheOwn;

  /// No description provided for @workoutsRecipesAndYourProgressFree.
  ///
  /// In en, this message translates to:
  /// **'Workouts, recipes and your progress. Free.'**
  String get workoutsRecipesAndYourProgressFree;

  /// No description provided for @thisIsWhatKeepsOwnHubWomen.
  ///
  /// In en, this message translates to:
  /// **'This is what keeps Own Hub women only: every woman is verified before she gets in.'**
  String get thisIsWhatKeepsOwnHubWomen;

  /// No description provided for @yourNumberYourIdYourMealsAnd_1ix08.
  ///
  /// In en, this message translates to:
  /// **'Your number, your ID, your meals and your workouts stay private.'**
  String get yourNumberYourIdYourMealsAnd_1ix08;

  /// No description provided for @ownHubIsForTrainingNotFor.
  ///
  /// In en, this message translates to:
  /// **'Own Hub is for training, not for selling.'**
  String get ownHubIsForTrainingNotFor;

  /// No description provided for @yourTrainingYourFoodYourCycleWomen.
  ///
  /// In en, this message translates to:
  /// **'Your training, your food, your cycle. Women only.'**
  String get yourTrainingYourFoodYourCycleWomen;

  /// No description provided for @setUpMyWeek.
  ///
  /// In en, this message translates to:
  /// **'Set up my week'**
  String get setUpMyWeek;

  /// No description provided for @n1Of3YourWeek.
  ///
  /// In en, this message translates to:
  /// **'1 of 3 · Your week'**
  String get n1Of3YourWeek;

  /// No description provided for @n2Of3YourNumber.
  ///
  /// In en, this message translates to:
  /// **'2 of 3 · Your number'**
  String get n2Of3YourNumber;

  /// No description provided for @n3Of3QuickCheck.
  ///
  /// In en, this message translates to:
  /// **'3 of 3 · Quick check'**
  String get n3Of3QuickCheck;

  /// No description provided for @onlyYouSeeThisItStaysOn.
  ///
  /// In en, this message translates to:
  /// **'Only you see this. It stays on this phone.'**
  String get onlyYouSeeThisItStaysOn;

  /// No description provided for @seeMyWeek.
  ///
  /// In en, this message translates to:
  /// **'See my week'**
  String get seeMyWeek;

  /// No description provided for @builtFromYourAnswers.
  ///
  /// In en, this message translates to:
  /// **'Built from your answers'**
  String get builtFromYourAnswers;

  /// No description provided for @oneQuickCheckKeepsOwnHubWomen.
  ///
  /// In en, this message translates to:
  /// **'One quick check keeps Own Hub women only. Then day 1 is yours.'**
  String get oneQuickCheckKeepsOwnHubWomen;

  /// No description provided for @saveMyWeekAndJoin.
  ///
  /// In en, this message translates to:
  /// **'Save my week and join'**
  String get saveMyWeekAndJoin;

  /// No description provided for @thatNumberDoesNotLookRightCheck.
  ///
  /// In en, this message translates to:
  /// **'That number does not look right. Check it and try again.'**
  String get thatNumberDoesNotLookRightCheck;

  /// No description provided for @noConnectionYourNumberIsStillHere.
  ///
  /// In en, this message translates to:
  /// **'No connection. Your number is still here, try again when you are back online.'**
  String get noConnectionYourNumberIsStillHere;

  /// No description provided for @weCouldNotSendTheCodeTry.
  ///
  /// In en, this message translates to:
  /// **'We could not send the code. Try again in a moment.'**
  String get weCouldNotSendTheCodeTry;

  /// No description provided for @thatCodeDidNotMatchCheckThe.
  ///
  /// In en, this message translates to:
  /// **'That code did not match. Check the message and type it again.'**
  String get thatCodeDidNotMatchCheckThe;

  /// No description provided for @thatCodeHasExpiredAskForA_1vzf3.
  ///
  /// In en, this message translates to:
  /// **'That code has expired. Ask for a new one below.'**
  String get thatCodeHasExpiredAskForA_1vzf3;

  /// No description provided for @noConnectionTryAgainWhenYouAre.
  ///
  /// In en, this message translates to:
  /// **'No connection. Try again when you are back online.'**
  String get noConnectionTryAgainWhenYouAre;

  /// No description provided for @weCouldNotCheckTheCodeTry.
  ///
  /// In en, this message translates to:
  /// **'We could not check the code. Try again in a moment.'**
  String get weCouldNotCheckTheCodeTry;

  /// No description provided for @checkingYourCode.
  ///
  /// In en, this message translates to:
  /// **'Checking your code'**
  String get checkingYourCode;

  /// No description provided for @editNumber.
  ///
  /// In en, this message translates to:
  /// **'Edit number'**
  String get editNumber;

  /// No description provided for @cameraAccessIsOff.
  ///
  /// In en, this message translates to:
  /// **'Camera access is off'**
  String get cameraAccessIsOff;

  /// No description provided for @ownHubNeedsTheCameraToRead.
  ///
  /// In en, this message translates to:
  /// **'Own Hub needs the camera to read your card. You can turn it on in Settings, or a woman from Own Hub can check you another way.'**
  String get ownHubNeedsTheCameraToRead;

  /// No description provided for @ownHubNeedsTheCameraForA.
  ///
  /// In en, this message translates to:
  /// **'Own Hub needs the camera for a short selfie. You can turn it on in Settings, or a woman from Own Hub can check you another way.'**
  String get ownHubNeedsTheCameraForA;

  /// No description provided for @theCameraCouldNotStartThisIs.
  ///
  /// In en, this message translates to:
  /// **'The camera could not start. This is not about you. Try again, or a woman from Own Hub can check you another way.'**
  String get theCameraCouldNotStartThisIs;

  /// No description provided for @checkMeAnotherWay.
  ///
  /// In en, this message translates to:
  /// **'Check me another way'**
  String get checkMeAnotherWay;

  /// No description provided for @noConnectionYourPhotosAreStillHere.
  ///
  /// In en, this message translates to:
  /// **'No connection. Your photos are still here, try again.'**
  String get noConnectionYourPhotosAreStillHere;

  /// No description provided for @bothSidesOfYourCardTaken.
  ///
  /// In en, this message translates to:
  /// **'Both sides of your card taken'**
  String get bothSidesOfYourCardTaken;

  /// No description provided for @selfieTaken.
  ///
  /// In en, this message translates to:
  /// **'Selfie taken'**
  String get selfieTaken;

  /// No description provided for @matchingYourSelfieToYourCard.
  ///
  /// In en, this message translates to:
  /// **'Matching your selfie to your card'**
  String get matchingYourSelfieToYourCard;

  /// No description provided for @takingLongerThanUsualYourConnectionMay.
  ///
  /// In en, this message translates to:
  /// **'Taking longer than usual. Your connection may be slow. You can keep waiting here.'**
  String get takingLongerThanUsualYourConnectionMay;

  /// No description provided for @goToHome.
  ///
  /// In en, this message translates to:
  /// **'Go to Home'**
  String get goToHome;

  /// No description provided for @planThisWeeksDinners.
  ///
  /// In en, this message translates to:
  /// **'Plan this week\'s dinners'**
  String get planThisWeeksDinners;

  /// No description provided for @fiveEgyptianDinnersAndOneShoppingList.
  ///
  /// In en, this message translates to:
  /// **'Five Egyptian dinners and one shopping list'**
  String get fiveEgyptianDinnersAndOneShoppingList;

  /// No description provided for @trackMyCycle.
  ///
  /// In en, this message translates to:
  /// **'Track my cycle'**
  String get trackMyCycle;

  /// No description provided for @optionalAndItStaysOnThisPhone.
  ///
  /// In en, this message translates to:
  /// **'Optional, and it stays on this phone'**
  String get optionalAndItStaysOnThisPhone;

  /// R10's next step after a finished session. The number is the next session of her week, in Western digits.
  ///
  /// In en, this message translates to:
  /// **'Next: session {number}, on any day this week'**
  String nextSessionNumberOnAnyDayThis(String number);

  /// No description provided for @day1WasNotWrittenForPregnancy.
  ///
  /// In en, this message translates to:
  /// **'Day 1 was not written for pregnancy. Please ask your doctor before you start, and skip any move that does not feel right.'**
  String get day1WasNotWrittenForPregnancy;

  /// No description provided for @day1WasNotWrittenForThe.
  ///
  /// In en, this message translates to:
  /// **'Day 1 was not written for the weeks after a birth. Please wait for your doctor\'s OK, and skip any move that does not feel right.'**
  String get day1WasNotWrittenForThe;

  /// No description provided for @iHaveMyDoctorsOkStart.
  ///
  /// In en, this message translates to:
  /// **'I have my doctor\'s OK, start'**
  String get iHaveMyDoctorsOkStart;

  /// No description provided for @notToday.
  ///
  /// In en, this message translates to:
  /// **'Not today'**
  String get notToday;

  /// No description provided for @yourWeekIsSaved.
  ///
  /// In en, this message translates to:
  /// **'Your week is saved'**
  String get yourWeekIsSaved;

  /// No description provided for @homeYourDayAtAGlance.
  ///
  /// In en, this message translates to:
  /// **'Home, your day at a glance'**
  String get homeYourDayAtAGlance;

  /// No description provided for @ownHubIsAFitnessAppFor.
  ///
  /// In en, this message translates to:
  /// **'Own Hub is a fitness app for women only. Home shows today\'s workout, what you have eaten and how your week is going. This week is a sample, so tap anything.'**
  String get ownHubIsAFitnessAppFor;

  /// No description provided for @quietSessionsYouCanDoAtHome.
  ///
  /// In en, this message translates to:
  /// **'Quiet sessions you can do at home. Each move shows its sets and what to aim for. Trained without your phone? You can add it afterwards.'**
  String get quietSessionsYouCanDoAtHome;

  /// No description provided for @duringAWorkout.
  ///
  /// In en, this message translates to:
  /// **'During a workout'**
  String get duringAWorkout;

  /// No description provided for @oneMoveAtATimeTapWhen.
  ///
  /// In en, this message translates to:
  /// **'One move at a time. Tap when a set is done, and Own Hub keeps count and times your rest.'**
  String get oneMoveAtATimeTapWhen;

  /// No description provided for @homeCookingYouAlreadyKnowWrittenBy.
  ///
  /// In en, this message translates to:
  /// **'Home cooking you already know, written by coach Rahma Mohsen. Open the first recipe to see one in full.'**
  String get homeCookingYouAlreadyKnowWrittenBy;

  /// No description provided for @yourWeekOfDinners.
  ///
  /// In en, this message translates to:
  /// **'Your week of dinners'**
  String get yourWeekOfDinners;

  /// No description provided for @aWeekOfDinnersPlannedForYou.
  ///
  /// In en, this message translates to:
  /// **'A week of dinners planned for you, with one shopping list that covers them all.'**
  String get aWeekOfDinnersPlannedForYou;

  /// No description provided for @yourCycleIfYouWantIt.
  ///
  /// In en, this message translates to:
  /// **'Your cycle, if you want it'**
  String get yourCycleIfYouWantIt;

  /// No description provided for @noteYourPeriodAndHowYouFeel.
  ///
  /// In en, this message translates to:
  /// **'Note your period and how you feel. On harder days Own Hub can suggest a gentler session. Cycle data stays on your phone unless you choose to back it up.'**
  String get noteYourPeriodAndHowYouFeel;

  /// No description provided for @yourWeeksYourPersonalBestsAndYour.
  ///
  /// In en, this message translates to:
  /// **'Your weeks, your personal bests and your milestones, counted only from what you add.'**
  String get yourWeeksYourPersonalBestsAndYour;

  /// No description provided for @thatIsOwnHub.
  ///
  /// In en, this message translates to:
  /// **'That is Own Hub'**
  String get thatIsOwnHub;

  /// No description provided for @toMakeItYoursJoinWithYour.
  ///
  /// In en, this message translates to:
  /// **'To make it yours, join with your phone number.'**
  String get toMakeItYoursJoinWithYour;

  /// No description provided for @ownHubIsForWomenOnlySo.
  ///
  /// In en, this message translates to:
  /// **'Own Hub is for women only, so we check your ID once, with a quick selfie. The photos are deleted after the check.'**
  String get ownHubIsForWomenOnlySo;

  /// No description provided for @firstOneScreenToBuildYourWeek.
  ///
  /// In en, this message translates to:
  /// **'First, one screen to build your week. Own Hub opens for you once the check is done.'**
  String get firstOneScreenToBuildYourWeek;

  /// No description provided for @makeItMine.
  ///
  /// In en, this message translates to:
  /// **'Make it mine'**
  String get makeItMine;

  /// No description provided for @seeTheTourAgain.
  ///
  /// In en, this message translates to:
  /// **'See the tour again'**
  String get seeTheTourAgain;

  /// No description provided for @sampleNothingIsSaved.
  ///
  /// In en, this message translates to:
  /// **'Sample · nothing is saved'**
  String get sampleNothingIsSaved;

  /// No description provided for @joinOwnHub.
  ///
  /// In en, this message translates to:
  /// **'Join Own Hub'**
  String get joinOwnHub;

  /// No description provided for @leaveTheTour.
  ///
  /// In en, this message translates to:
  /// **'Leave the tour'**
  String get leaveTheTour;

  /// No description provided for @backToMyCheck.
  ///
  /// In en, this message translates to:
  /// **'Back to my check'**
  String get backToMyCheck;

  /// No description provided for @joinToMakeThisYours.
  ///
  /// In en, this message translates to:
  /// **'Join to make this yours'**
  String get joinToMakeThisYours;

  /// No description provided for @keepLooking.
  ///
  /// In en, this message translates to:
  /// **'Keep looking'**
  String get keepLooking;

  /// No description provided for @showMeAround.
  ///
  /// In en, this message translates to:
  /// **'Show me around'**
  String get showMeAround;

  /// No description provided for @skipTheTourAndJoin.
  ///
  /// In en, this message translates to:
  /// **'Skip the tour and join'**
  String get skipTheTourAndJoin;

  /// No description provided for @theTourUsesASampleWeekNo.
  ///
  /// In en, this message translates to:
  /// **'The tour uses a sample week. No account, and nothing is saved.'**
  String get theTourUsesASampleWeekNo;

  /// No description provided for @firstYourWeekThenYourNumberAnd.
  ///
  /// In en, this message translates to:
  /// **'First your week, then your number and a quick check that you are a woman. About two minutes, once.'**
  String get firstYourWeekThenYourNumberAnd;

  /// No description provided for @homeCookingYouAlreadyKnowWrittenBy_7q8w1.
  ///
  /// In en, this message translates to:
  /// **'Home cooking you already know, written by coach Rahma Mohsen. The recipes open with your account.'**
  String get homeCookingYouAlreadyKnowWrittenBy_7q8w1;

  /// No description provided for @toSendYourCodeYourNumberGoes.
  ///
  /// In en, this message translates to:
  /// **'To send your code, your number goes to Google Firebase in the United States. Your account and training are kept by Google Cloud in Frankfurt, Germany.'**
  String get toSendYourCodeYourNumberGoes;

  /// No description provided for @sendCrashReports.
  ///
  /// In en, this message translates to:
  /// **'Send crash reports'**
  String get sendCrashReports;

  /// No description provided for @optionalHelpsUsFixTheAppNo.
  ///
  /// In en, this message translates to:
  /// **'Optional. Helps us fix the app. No name, number or account is attached. You can change this in Privacy.'**
  String get optionalHelpsUsFixTheAppNo;

  /// No description provided for @agreeAndSendMeACode.
  ///
  /// In en, this message translates to:
  /// **'Agree and send me a code'**
  String get agreeAndSendMeACode;

  /// No description provided for @byTappingAgreeAndSendMeA.
  ///
  /// In en, this message translates to:
  /// **'By tapping Agree and send me a code, you accept the Terms of Use and the Privacy Policy.'**
  String get byTappingAgreeAndSendMeA;

  /// No description provided for @weHaveUpdatedOurTermsAndPrivacy.
  ///
  /// In en, this message translates to:
  /// **'We have updated our Terms and Privacy Policy'**
  String get weHaveUpdatedOurTermsAndPrivacy;

  /// No description provided for @pleaseReadWhatChangedToKeepUsing.
  ///
  /// In en, this message translates to:
  /// **'Please read what changed. To keep using Own Hub, agree to the new versions.'**
  String get pleaseReadWhatChangedToKeepUsing;

  /// No description provided for @yourAgreementIsNowRecordedWhenYou.
  ///
  /// In en, this message translates to:
  /// **'Your agreement is now recorded when you sign up, with the language and the app version.'**
  String get yourAgreementIsNowRecordedWhenYou;

  /// No description provided for @crashReportsAreSentOnlyIfYou.
  ///
  /// In en, this message translates to:
  /// **'Crash reports are sent only if you allow them. They are off until you do.'**
  String get crashReportsAreSentOnlyIfYou;

  /// No description provided for @youCanAskForACopyOf.
  ///
  /// In en, this message translates to:
  /// **'You can ask for a copy of your data, and the policy says how long each kind is kept.'**
  String get youCanAskForACopyOf;

  /// No description provided for @agreeAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Agree and continue'**
  String get agreeAndContinue;

  /// No description provided for @deleteMyAccountInstead.
  ///
  /// In en, this message translates to:
  /// **'Delete my account instead'**
  String get deleteMyAccountInstead;

  /// No description provided for @weCouldNotSaveYourAgreementCheck.
  ///
  /// In en, this message translates to:
  /// **'We could not save your agreement. Check your connection and try again.'**
  String get weCouldNotSaveYourAgreementCheck;

  /// No description provided for @crashReports.
  ///
  /// In en, this message translates to:
  /// **'Crash reports'**
  String get crashReports;

  /// No description provided for @onIfTheAppCrashesTheError.
  ///
  /// In en, this message translates to:
  /// **'On. If the app crashes, the error and your phone model are sent to Firebase. Nothing about you is attached.'**
  String get onIfTheAppCrashesTheError;

  /// No description provided for @offNothingIsSentWhenTheApp.
  ///
  /// In en, this message translates to:
  /// **'Off. Nothing is sent when the app crashes.'**
  String get offNothingIsSentWhenTheApp;

  /// No description provided for @yourPhotosGoToOurServerIn.
  ///
  /// In en, this message translates to:
  /// **'Your photos go to our server in Frankfurt, Germany. Google Cloud Vision reads the text on the card in the European Union.'**
  String get yourPhotosGoToOurServerIn;

  /// No description provided for @yourFaceIsMatchedOnOurOwn.
  ///
  /// In en, this message translates to:
  /// **'Your face is matched on our own server. No outside face service sees it.'**
  String get yourFaceIsMatchedOnOurOwn;

  /// No description provided for @noPhotoIsEverStoredBothSides.
  ///
  /// In en, this message translates to:
  /// **'No photo is ever stored. Both sides of the card and the selfie are deleted from memory when the check ends, whatever the result.'**
  String get noPhotoIsEverStoredBothSides;

  /// No description provided for @weKeepTheResultAndItsReasons.
  ///
  /// In en, this message translates to:
  /// **'We keep the result and its reasons for 180 days, and a keyed code of your ID number so one card opens one account. The code cannot be turned back into your number.'**
  String get weKeepTheResultAndItsReasons;

  /// No description provided for @ifTheCheckCannotDecideYouCan.
  ///
  /// In en, this message translates to:
  /// **'If the check cannot decide, you can ask a woman from Own Hub to check you instead.'**
  String get ifTheCheckCannotDecideYouCan;

  /// No description provided for @readThePrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Read the Privacy Policy'**
  String get readThePrivacyPolicy;

  /// No description provided for @ownHubIsAFitnessAndWellbeing.
  ///
  /// In en, this message translates to:
  /// **'Own Hub is a fitness and wellbeing app. It is not a medical device and does not diagnose, treat, cure or prevent any condition. Check with your doctor before you start, especially if you are pregnant or have recently given birth.'**
  String get ownHubIsAFitnessAndWellbeing;

  /// No description provided for @usuallyACoupleOfMinutesIfA.
  ///
  /// In en, this message translates to:
  /// **'Usually a couple of minutes. If a woman needs to check, up to 3 days.'**
  String get usuallyACoupleOfMinutesIfA;

  /// No description provided for @bothImagesAreDeletedAfterTheCheck_8iuyd.
  ///
  /// In en, this message translates to:
  /// **'Both images are deleted after the check. We keep the result and a keyed code of your ID number.'**
  String get bothImagesAreDeletedAfterTheCheck_8iuyd;

  /// No description provided for @yourIdAndSelfieWereDeletedAfter_nl9hl.
  ///
  /// In en, this message translates to:
  /// **'Your ID and selfie were deleted after the check. We keep the result and a keyed code of your ID number.'**
  String get yourIdAndSelfieWereDeletedAfter_nl9hl;

  /// No description provided for @aWomanReviewerChecksYourCardWith.
  ///
  /// In en, this message translates to:
  /// **'A woman reviewer checks your card with you. Nothing is recorded. She keeps only her decision and the date.'**
  String get aWomanReviewerChecksYourCardWith;

  /// No description provided for @askAWomanToCheckMe.
  ///
  /// In en, this message translates to:
  /// **'Ask a woman to check me'**
  String get askAWomanToCheckMe;

  /// No description provided for @aCheckWithAWoman.
  ///
  /// In en, this message translates to:
  /// **'A check with a woman'**
  String get aCheckWithAWoman;

  /// No description provided for @emailUsReadSundayToThursday9.
  ///
  /// In en, this message translates to:
  /// **'Email us. Read Sunday to Thursday, 9:00 to 17:00 Cairo time.'**
  String get emailUsReadSundayToThursday9;

  /// No description provided for @wantACopyOfYourDataAsk.
  ///
  /// In en, this message translates to:
  /// **'Want a copy of your data? Ask us and we will send it to you.'**
  String get wantACopyOfYourDataAsk;

  /// No description provided for @askForACopy.
  ///
  /// In en, this message translates to:
  /// **'Ask for a copy'**
  String get askForACopy;

  /// No description provided for @copyOfMyOwnHubData.
  ///
  /// In en, this message translates to:
  /// **'Copy of my Own Hub data'**
  String get copyOfMyOwnHubData;

  /// No description provided for @thePhoneNumberOnMyAccount.
  ///
  /// In en, this message translates to:
  /// **'The phone number on my account:'**
  String get thePhoneNumberOnMyAccount;

  /// No description provided for @deletingTakesAwayEverythingYouHavePut_7ytu4.
  ///
  /// In en, this message translates to:
  /// **'Deleting takes away everything you have put into the app: your meals, your workouts, your measurements, your cycle and your answers.'**
  String get deletingTakesAwayEverythingYouHavePut_7ytu4;

  /// No description provided for @deletingTakesAwayEverythingYouHavePut_1uwbl.
  ///
  /// In en, this message translates to:
  /// **'Deleting takes away everything you have put into the app: your meals, your workouts, your measurements, your cycle, your posts and your answers.'**
  String get deletingTakesAwayEverythingYouHavePut_1uwbl;

  /// No description provided for @deletingUsuallyTakesUnderAMinuteIf.
  ///
  /// In en, this message translates to:
  /// **'Deleting usually takes under a minute. If it is interrupted, it finishes on its own within the hour, and none of it can be brought back.'**
  String get deletingUsuallyTakesUnderAMinuteIf;

  /// No description provided for @deletingYourAccountThisUsuallyTakesUnder.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account. This usually takes under a minute.'**
  String get deletingYourAccountThisUsuallyTakesUnder;

  /// No description provided for @deletingYourAccountRemovesItFromOur_1xldi.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account removes it from our servers and clears this phone. Some things are kept on purpose: a closed record that your ID card was used, so it cannot open another account, reports with your name taken out, and a record that the deletion happened. Failed check attempts and a scrambled code for this installation, linked to no account, are deleted 180 days after the last attempt, and the log of which reviewer opened your case after one year.'**
  String get deletingYourAccountRemovesItFromOur_1xldi;

  /// No description provided for @weTextYouASixDigitCode_18wn2.
  ///
  /// In en, this message translates to:
  /// **'We text you a six-digit code. No other member ever sees your number.'**
  String get weTextYouASixDigitCode_18wn2;

  /// No description provided for @yourPhoneNumberIsUsedOnlyTo_thda4.
  ///
  /// In en, this message translates to:
  /// **'Your phone number is used only to arrange your check.'**
  String get yourPhoneNumberIsUsedOnlyTo_thda4;

  /// No description provided for @aWomanFromOwnHubWillReview.
  ///
  /// In en, this message translates to:
  /// **'A woman from Own Hub will review your check'**
  String get aWomanFromOwnHubWillReview;

  /// No description provided for @aWomanFromOwnHubReviewsYour.
  ///
  /// In en, this message translates to:
  /// **'A woman from Own Hub reviews your case and contacts you by phone within 72 hours. We do not send text messages about this.'**
  String get aWomanFromOwnHubReviewsYour;

  /// C14 once a woman reviewer has booked a time to contact her. time is the booked date and time, already formatted for her locale.
  ///
  /// In en, this message translates to:
  /// **'A woman from Own Hub will contact you on {time}.'**
  String aWomanFromOwnHubWillContact(String time);

  /// No description provided for @aWomanFromOwnHubCanContact.
  ///
  /// In en, this message translates to:
  /// **'A woman from Own Hub can contact you only after you ask her to. If you ask, she reviews your case and contacts you by phone within 72 hours to finish your check.'**
  String get aWomanFromOwnHubCanContact;

  /// No description provided for @askAWomanToContactMe.
  ///
  /// In en, this message translates to:
  /// **'Ask a woman to contact me'**
  String get askAWomanToContactMe;

  /// No description provided for @ifYouDoNotShowYourFace_1pr0p.
  ///
  /// In en, this message translates to:
  /// **'If you do not show your face to a camera, nothing here asks you to. A woman from Own Hub reviews your case and contacts you by phone within 72 hours to check your ID card with you.'**
  String get ifYouDoNotShowYourFace_1pr0p;

  /// No description provided for @thisAccountHasUsedEveryAutomaticCheck_rc3un.
  ///
  /// In en, this message translates to:
  /// **'This account has used every automatic check it can. Nothing you photographed was kept. A woman from Own Hub can review your case instead and contact you within 72 hours.'**
  String get thisAccountHasUsedEveryAutomaticCheck_rc3un;

  /// No description provided for @yourAutomaticCheckIsStillRunningSo.
  ///
  /// In en, this message translates to:
  /// **'Your automatic check is still running, so nothing was sent. You will be moved on when it finishes. If nothing happens, ask again in a minute.'**
  String get yourAutomaticCheckIsStillRunningSo;

  /// No description provided for @theMatchUsuallyTakesUnderAMinute.
  ///
  /// In en, this message translates to:
  /// **'The match usually takes under a minute. If it needs a person, a woman reviewer takes it from here.'**
  String get theMatchUsuallyTakesUnderAMinute;

  /// No description provided for @buildYourWeekWhileWeCheck.
  ///
  /// In en, this message translates to:
  /// **'Build your week while we check'**
  String get buildYourWeekWhileWeCheck;

  /// No description provided for @saveMyWeek.
  ///
  /// In en, this message translates to:
  /// **'Save my week'**
  String get saveMyWeek;

  /// No description provided for @breakingThemCanCloseYourAccountYou.
  ///
  /// In en, this message translates to:
  /// **'Breaking them can close your account. You can read them again any time.'**
  String get breakingThemCanCloseYourAccountYou;

  /// No description provided for @firstYourWeekThenYourNumberAnd_flrzo.
  ///
  /// In en, this message translates to:
  /// **'First your week, then your number and a quick check that you are a woman.'**
  String get firstYourWeekThenYourNumberAnd_flrzo;

  /// No description provided for @weJustNeedYourNumberAndA_1jn4g.
  ///
  /// In en, this message translates to:
  /// **'We just need your number and a quick check that you are a woman.'**
  String get weJustNeedYourNumberAndA_1jn4g;

  /// Her setup answers read back when she was never asked where she trains (the one-screen 'Your week'), so no place is claimed.
  ///
  /// In en, this message translates to:
  /// **'Days a week: {days} · Minutes a session: {minutes}'**
  String daysAWeekDaysMinutesASession_1a2wl(String days, String minutes);

  /// No description provided for @n8WeeksForBeginners.
  ///
  /// In en, this message translates to:
  /// **'8 weeks · for beginners'**
  String get n8WeeksForBeginners;

  /// E05 opened from a day on E07: tapping a recipe puts it on that day. day is the weekday name from the dictionary.
  ///
  /// In en, this message translates to:
  /// **'Pick a dinner for {day}'**
  String pickADinnerForDay(String day);

  /// No description provided for @changeThisDinner.
  ///
  /// In en, this message translates to:
  /// **'Change this dinner'**
  String get changeThisDinner;

  /// No description provided for @fillMyWeekFromRahmasRecipes.
  ///
  /// In en, this message translates to:
  /// **'Fill my week from Rahma\'s recipes'**
  String get fillMyWeekFromRahmasRecipes;

  /// No description provided for @yourCycleOnThisPhone.
  ///
  /// In en, this message translates to:
  /// **'Your cycle, on this phone'**
  String get yourCycleOnThisPhone;

  /// No description provided for @yourIdPhotoAndSelfieHaveBeen_1qfoh.
  ///
  /// In en, this message translates to:
  /// **'Your ID photo and selfie have been deleted. We keep the result, its reasons and a keyed code of your ID number.'**
  String get yourIdPhotoAndSelfieHaveBeen_1qfoh;

  /// C13. Her actual verification time, and what the server really keeps: the result, its reasons for 180 days and the keyed code of her ID number.
  ///
  /// In en, this message translates to:
  /// **'Verified in {seconds} seconds. Your ID photo and selfie have been deleted. We keep the result, its reasons and a keyed code of your ID number.'**
  String verifiedInSecondsSecondsYourIdPhoto_mbpt8(int seconds);

  /// No description provided for @tellMeWhenImIn.
  ///
  /// In en, this message translates to:
  /// **'Tell me when I\'m in'**
  String get tellMeWhenImIn;

  /// No description provided for @weWillTellYouOnThisPhone.
  ///
  /// In en, this message translates to:
  /// **'We will tell you on this phone when your check is done.'**
  String get weWillTellYouOnThisPhone;

  /// No description provided for @notificationsAreOffForOwnHubOn.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off for Own Hub on this phone. You can turn them on in Settings.'**
  String get notificationsAreOffForOwnHubOn;

  /// No description provided for @notificationsCannotReachThisPhoneOpenOwn.
  ///
  /// In en, this message translates to:
  /// **'Notifications cannot reach this phone. Open Own Hub to see when your check is done.'**
  String get notificationsCannotReachThisPhoneOpenOwn;

  /// No description provided for @aReminderOnYourTrainingDays.
  ///
  /// In en, this message translates to:
  /// **'A reminder on your training days?'**
  String get aReminderOnYourTrainingDays;

  /// No description provided for @oneQuietNoteOnTheDaysYou.
  ///
  /// In en, this message translates to:
  /// **'One quiet note on the days you pick, at the time you pick. You can change it or turn it off in Notifications.'**
  String get oneQuietNoteOnTheDaysYou;

  /// No description provided for @chooseMyDays.
  ///
  /// In en, this message translates to:
  /// **'Choose my days'**
  String get chooseMyDays;

  /// No description provided for @trainingReminders.
  ///
  /// In en, this message translates to:
  /// **'Training reminders'**
  String get trainingReminders;

  /// Training reminders sheet. count is her sessions a week (2 to 4), Western digits.
  ///
  /// In en, this message translates to:
  /// **'Sessions in your week: {count}. Pick the days that suit you.'**
  String sessionsInYourWeekCountPickThe(String count);

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @changeTime.
  ///
  /// In en, this message translates to:
  /// **'Change time'**
  String get changeTime;

  /// No description provided for @remindMe.
  ///
  /// In en, this message translates to:
  /// **'Remind me'**
  String get remindMe;

  /// No description provided for @turnRemindersOff.
  ///
  /// In en, this message translates to:
  /// **'Turn reminders off'**
  String get turnRemindersOff;

  /// No description provided for @pickAtLeastOneDay.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one day.'**
  String get pickAtLeastOneDay;

  /// No description provided for @remindersAreOn.
  ///
  /// In en, this message translates to:
  /// **'Reminders are on.'**
  String get remindersAreOn;

  /// No description provided for @remindersAreOff.
  ///
  /// In en, this message translates to:
  /// **'Reminders are off.'**
  String get remindersAreOff;

  /// No description provided for @remindersCannotBeSetOnThisPhone.
  ///
  /// In en, this message translates to:
  /// **'Reminders cannot be set on this phone.'**
  String get remindersCannotBeSetOnThisPhone;

  /// No description provided for @yourSessionIsReadyWhenYouAre.
  ///
  /// In en, this message translates to:
  /// **'Your session is ready when you are.'**
  String get yourSessionIsReadyWhenYouAre;

  /// No description provided for @aNoteOnTheDaysYouChose.
  ///
  /// In en, this message translates to:
  /// **'A note on the days you chose to train.'**
  String get aNoteOnTheDaysYouChose;

  /// No description provided for @aSampleWeekOfFiveDinnersJoin.
  ///
  /// In en, this message translates to:
  /// **'A sample week of five dinners. Join to plan your own.'**
  String get aSampleWeekOfFiveDinnersJoin;

  /// No description provided for @deleteWhatISavedOnThisPhone.
  ///
  /// In en, this message translates to:
  /// **'Delete what I saved on this phone'**
  String get deleteWhatISavedOnThisPhone;

  /// No description provided for @deleteWhatYouSavedOnThisPhone.
  ///
  /// In en, this message translates to:
  /// **'Delete what you saved on this phone?'**
  String get deleteWhatYouSavedOnThisPhone;

  /// No description provided for @yourWeekYourLifeStageAndAnything.
  ///
  /// In en, this message translates to:
  /// **'Your week, your life stage and anything else you saved here are deleted from this phone. You can build your week again at any time.'**
  String get yourWeekYourLifeStageAndAnything;

  /// No description provided for @keepIt.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get keepIt;

  /// No description provided for @deleteIt.
  ///
  /// In en, this message translates to:
  /// **'Delete it'**
  String get deleteIt;

  /// No description provided for @deletedFromThisPhone.
  ///
  /// In en, this message translates to:
  /// **'Deleted from this phone.'**
  String get deletedFromThisPhone;

  /// No description provided for @setUpMyCoachProfile.
  ///
  /// In en, this message translates to:
  /// **'Set up my coach profile'**
  String get setUpMyCoachProfile;

  /// No description provided for @addPayoutLater.
  ///
  /// In en, this message translates to:
  /// **'Add payout later'**
  String get addPayoutLater;

  /// No description provided for @buildYourFirstPlan.
  ///
  /// In en, this message translates to:
  /// **'Build your first plan'**
  String get buildYourFirstPlan;

  /// No description provided for @readyForYourFirstClientWhileWe.
  ///
  /// In en, this message translates to:
  /// **'Ready for your first client while we check your certificates.'**
  String get readyForYourFirstClientWhileWe;

  /// No description provided for @inviteAClient.
  ///
  /// In en, this message translates to:
  /// **'Invite a client'**
  String get inviteAClient;

  /// No description provided for @alreadyCoachingSomeoneSendHerYourCode.
  ///
  /// In en, this message translates to:
  /// **'Already coaching someone? Send her your code on WhatsApp.'**
  String get alreadyCoachingSomeoneSendHerYourCode;

  /// The WhatsApp message a coach sends to invite a client. {code} is her eight-character invite code.
  ///
  /// In en, this message translates to:
  /// **'Join me on Own Hub, the training app for women only. When you sign up, tap I have a code from my coach and enter {code}.'**
  String joinMeOnOwnHubTheTraining(String code);

  /// No description provided for @iHaveACodeFromMyCoach.
  ///
  /// In en, this message translates to:
  /// **'I have a code from my coach'**
  String get iHaveACodeFromMyCoach;

  /// No description provided for @yourCoachsCode.
  ///
  /// In en, this message translates to:
  /// **'Your coach\'s code'**
  String get yourCoachsCode;

  /// No description provided for @saveTheCode.
  ///
  /// In en, this message translates to:
  /// **'Save the code'**
  String get saveTheCode;

  /// No description provided for @savedOnceYouAreInWeWill.
  ///
  /// In en, this message translates to:
  /// **'Saved. Once you are in, we will connect you with your coach.'**
  String get savedOnceYouAreInWeWill;

  /// No description provided for @thatCodeDoesNotLookRightCheck.
  ///
  /// In en, this message translates to:
  /// **'That code does not look right. Check it and try again.'**
  String get thatCodeDoesNotLookRightCheck;

  /// No description provided for @yourCoachHasYourRequest.
  ///
  /// In en, this message translates to:
  /// **'Your coach has your request.'**
  String get yourCoachHasYourRequest;

  /// No description provided for @yourCoachsCodeDidNotWorkAsk.
  ///
  /// In en, this message translates to:
  /// **'Your coach\'s code did not work. Ask her for a new one.'**
  String get yourCoachsCodeDidNotWorkAsk;

  /// No description provided for @weCouldNotMakeYourCodeTry.
  ///
  /// In en, this message translates to:
  /// **'We could not make your code. Try again in a moment.'**
  String get weCouldNotMakeYourCodeTry;

  /// Shown when WhatsApp could not open, so the coach can share her code another way.
  ///
  /// In en, this message translates to:
  /// **'We could not open WhatsApp. Your code is {code}.'**
  String weCouldNotOpenWhatsappYourCode(String code);

  /// No description provided for @weOpenCoachingSoon.
  ///
  /// In en, this message translates to:
  /// **'We open coaching soon'**
  String get weOpenCoachingSoon;

  /// No description provided for @tellUsAboutYouAndWeWill.
  ///
  /// In en, this message translates to:
  /// **'Tell us about you and we will call you.'**
  String get tellUsAboutYouAndWeWill;

  /// No description provided for @whatYouCoach.
  ///
  /// In en, this message translates to:
  /// **'What you coach'**
  String get whatYouCoach;

  /// No description provided for @sendOnWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'Send on WhatsApp'**
  String get sendOnWhatsapp;

  /// No description provided for @sendByEmail.
  ///
  /// In en, this message translates to:
  /// **'Send by email'**
  String get sendByEmail;

  /// No description provided for @thisOpensAMessageToOurTeam.
  ///
  /// In en, this message translates to:
  /// **'This opens a message to our team. Nothing is sent until you send it yourself.'**
  String get thisOpensAMessageToOurTeam;

  /// The message a coach sends to the team from the interest form while coaching is closed.
  ///
  /// In en, this message translates to:
  /// **'I coach women and would like to coach on Own Hub. Name: {name}. City: {city}. I coach: {specialty}.'**
  String iCoachWomenAndWouldLikeTo(String name, String city, String specialty);

  /// No description provided for @coachingOnOwnHub.
  ///
  /// In en, this message translates to:
  /// **'Coaching on Own Hub'**
  String get coachingOnOwnHub;

  /// No description provided for @weCouldNotOpenAMessageOn.
  ///
  /// In en, this message translates to:
  /// **'We could not open a message on this phone.'**
  String get weCouldNotOpenAMessageOn;

  /// No description provided for @iAgreeToTheseThreeRules.
  ///
  /// In en, this message translates to:
  /// **'I agree to these three rules'**
  String get iAgreeToTheseThreeRules;

  /// No description provided for @asACoachYouAgreeToThe.
  ///
  /// In en, this message translates to:
  /// **'As a coach you agree to the same three rules as every woman here.'**
  String get asACoachYouAgreeToThe;

  /// No description provided for @photographYourCertificate.
  ///
  /// In en, this message translates to:
  /// **'Photograph your certificate'**
  String get photographYourCertificate;

  /// No description provided for @takeThePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take the photo'**
  String get takeThePhoto;

  /// No description provided for @layItFlatInGoodLightWith.
  ///
  /// In en, this message translates to:
  /// **'Lay it flat in good light, with every word readable.'**
  String get layItFlatInGoodLightWith;

  /// No description provided for @theCameraCouldNotStartCloseThis.
  ///
  /// In en, this message translates to:
  /// **'The camera could not start. Close this and try again.'**
  String get theCameraCouldNotStartCloseThis;

  /// No description provided for @weCouldNotSendYourCertificateCheck.
  ///
  /// In en, this message translates to:
  /// **'We could not send your certificate. Check your connection and try again.'**
  String get weCouldNotSendYourCertificateCheck;

  /// No description provided for @coachingIsNotOpenYetSoYour.
  ///
  /// In en, this message translates to:
  /// **'Coaching is not open yet, so your certificate was not sent.'**
  String get coachingIsNotOpenYetSoYour;

  /// No description provided for @typeWhatYouAte.
  ///
  /// In en, this message translates to:
  /// **'Type what you ate'**
  String get typeWhatYouAte;

  /// No description provided for @yourWeek.
  ///
  /// In en, this message translates to:
  /// **'Your week'**
  String get yourWeek;

  /// No description provided for @sessionsThisWeekAtAGlanceNothing.
  ///
  /// In en, this message translates to:
  /// **'Sessions this week, at a glance. Nothing about your cycle or body.'**
  String get sessionsThisWeekAtAGlanceNothing;

  /// No description provided for @todaysWorkoutAndMealOneTapAway.
  ///
  /// In en, this message translates to:
  /// **'Today\'s workout and meal, one tap away.'**
  String get todaysWorkoutAndMealOneTapAway;

  /// Lock Screen inline widget. Sessions this week against her weekly target. Never a daily count.
  ///
  /// In en, this message translates to:
  /// **'{done} of {target} this week'**
  String doneOfTargetThisWeek(int done, int target);

  /// VoiceOver label for the widget's week segments and gauge.
  ///
  /// In en, this message translates to:
  /// **'Sessions this week: {done} of {target}'**
  String sessionsThisWeekDoneOfTarget(int done, int target);

  /// No description provided for @yourFirstSessionIsReady.
  ///
  /// In en, this message translates to:
  /// **'Your first session is ready'**
  String get yourFirstSessionIsReady;

  /// No description provided for @todaysWorkoutIsReady.
  ///
  /// In en, this message translates to:
  /// **'Today\'s workout is ready'**
  String get todaysWorkoutIsReady;

  /// No description provided for @todayIsUnderWay.
  ///
  /// In en, this message translates to:
  /// **'Today is under way'**
  String get todayIsUnderWay;

  /// No description provided for @sessionSaved.
  ///
  /// In en, this message translates to:
  /// **'Session saved'**
  String get sessionSaved;

  /// No description provided for @youAddedAMealToday.
  ///
  /// In en, this message translates to:
  /// **'You added a meal today'**
  String get youAddedAMealToday;

  /// No description provided for @addWhatIAte.
  ///
  /// In en, this message translates to:
  /// **'Add what I ate'**
  String get addWhatIAte;

  /// No description provided for @openOwnHubForToday.
  ///
  /// In en, this message translates to:
  /// **'Open Own Hub for today'**
  String get openOwnHubForToday;

  /// No description provided for @openOwnHubToStart.
  ///
  /// In en, this message translates to:
  /// **'Open Own Hub to start'**
  String get openOwnHubToStart;

  /// No description provided for @yourWeekShowsHere.
  ///
  /// In en, this message translates to:
  /// **'Your week shows here'**
  String get yourWeekShowsHere;

  /// No description provided for @helpImproveOwnHub.
  ///
  /// In en, this message translates to:
  /// **'Help improve Own Hub'**
  String get helpImproveOwnHub;

  /// No description provided for @offNothingAboutHowYouUseThe.
  ///
  /// In en, this message translates to:
  /// **'Off. Nothing about how you use the app is sent. Turning it off also clears the statistics ID on this phone.'**
  String get offNothingAboutHowYouUseThe;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @logs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logs;

  /// No description provided for @events.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get events;

  /// No description provided for @adminConsole.
  ///
  /// In en, this message translates to:
  /// **'Admin console'**
  String get adminConsole;

  /// No description provided for @contentEventsCountsAndLogs.
  ///
  /// In en, this message translates to:
  /// **'Content, events, counts and logs'**
  String get contentEventsCountsAndLogs;

  /// No description provided for @countsOnlyNothingHereNamesAMember.
  ///
  /// In en, this message translates to:
  /// **'Counts only. Nothing here names a member.'**
  String get countsOnlyNothingHereNamesAMember;

  /// No description provided for @accounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accounts;

  /// No description provided for @verifiedMembers.
  ///
  /// In en, this message translates to:
  /// **'Verified members'**
  String get verifiedMembers;

  /// No description provided for @humanReviewsWaiting.
  ///
  /// In en, this message translates to:
  /// **'Human reviews waiting'**
  String get humanReviewsWaiting;

  /// Z15, human reviews older than the review SLA. Both values are Western-digit labels.
  ///
  /// In en, this message translates to:
  /// **'{count} past the {hours}-hour promise'**
  String countPastTheHoursHourPromise(String count, String hours);

  /// Z15, the age of the oldest open human review in whole hours.
  ///
  /// In en, this message translates to:
  /// **'Oldest has waited {hours} hours'**
  String oldestHasWaitedHoursHours(String hours);

  /// No description provided for @checkOutcomesLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Check outcomes, last 7 days'**
  String get checkOutcomesLast7Days;

  /// No description provided for @checkOutcomesLast30Days.
  ///
  /// In en, this message translates to:
  /// **'Check outcomes, last 30 days'**
  String get checkOutcomesLast30Days;

  /// No description provided for @waitlist.
  ///
  /// In en, this message translates to:
  /// **'Waitlist'**
  String get waitlist;

  /// No description provided for @deletionRequests.
  ///
  /// In en, this message translates to:
  /// **'Deletion requests'**
  String get deletionRequests;

  /// No description provided for @stillRunning.
  ///
  /// In en, this message translates to:
  /// **'Still running'**
  String get stillRunning;

  /// No description provided for @finished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get finished;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @drafts.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get drafts;

  /// Z15, when the counts were computed, Cairo time.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String updatedTime(String time);

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @thisAccountDoesNotHaveAdminAccess.
  ///
  /// In en, this message translates to:
  /// **'This account does not have admin access.'**
  String get thisAccountDoesNotHaveAdminAccess;

  /// No description provided for @signInWithYourPhoneNumberTo.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your phone number to open the console.'**
  String get signInWithYourPhoneNumberTo;

  /// No description provided for @theConsoleNeedsAConnectionTryAgain.
  ///
  /// In en, this message translates to:
  /// **'The console needs a connection. Try again in a moment.'**
  String get theConsoleNeedsAConnectionTryAgain;

  /// No description provided for @approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// No description provided for @sentToAReviewer.
  ///
  /// In en, this message translates to:
  /// **'Sent to a reviewer'**
  String get sentToAReviewer;

  /// No description provided for @notEligible.
  ///
  /// In en, this message translates to:
  /// **'Not eligible'**
  String get notEligible;

  /// No description provided for @checkDidNotPass.
  ///
  /// In en, this message translates to:
  /// **'Check did not pass'**
  String get checkDidNotPass;

  /// No description provided for @cardAlreadyInUse.
  ///
  /// In en, this message translates to:
  /// **'Card already in use'**
  String get cardAlreadyInUse;

  /// No description provided for @askedToRetake.
  ///
  /// In en, this message translates to:
  /// **'Asked to retake'**
  String get askedToRetake;

  /// No description provided for @askedToTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Asked to try again'**
  String get askedToTryAgain;

  /// No description provided for @decisions.
  ///
  /// In en, this message translates to:
  /// **'Decisions'**
  String get decisions;

  /// No description provided for @deletions.
  ///
  /// In en, this message translates to:
  /// **'Deletions'**
  String get deletions;

  /// No description provided for @errors.
  ///
  /// In en, this message translates to:
  /// **'Errors'**
  String get errors;

  /// No description provided for @consoleReads.
  ///
  /// In en, this message translates to:
  /// **'Console reads'**
  String get consoleReads;

  /// No description provided for @allOutcomes.
  ///
  /// In en, this message translates to:
  /// **'All outcomes'**
  String get allOutcomes;

  /// Z16, a short reference standing for a verification case. Eight hex characters, never an id.
  ///
  /// In en, this message translates to:
  /// **'Case {ref}'**
  String caseRef(String ref);

  /// Z16, a short reference standing for a reviewer account.
  ///
  /// In en, this message translates to:
  /// **'Reviewer {ref}'**
  String reviewerRef(String ref);

  /// Z16, a short reference standing for an admin account.
  ///
  /// In en, this message translates to:
  /// **'Admin {ref}'**
  String adminRef(String ref);

  /// Z16, waitlist joins on one day. Counts only.
  ///
  /// In en, this message translates to:
  /// **'{count} joined'**
  String countJoined(String count);

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @openingALogIsRecordedToo.
  ///
  /// In en, this message translates to:
  /// **'Opening a log is recorded too.'**
  String get openingALogIsRecordedToo;

  /// No description provided for @lookedAtTheReviewQueue.
  ///
  /// In en, this message translates to:
  /// **'Looked at the review queue'**
  String get lookedAtTheReviewQueue;

  /// No description provided for @lookedUpAContact.
  ///
  /// In en, this message translates to:
  /// **'Looked up a contact'**
  String get lookedUpAContact;

  /// No description provided for @bookedAReview.
  ///
  /// In en, this message translates to:
  /// **'Booked a review'**
  String get bookedAReview;

  /// No description provided for @recordedADecision.
  ///
  /// In en, this message translates to:
  /// **'Recorded a decision'**
  String get recordedADecision;

  /// No description provided for @storeReviewAccount.
  ///
  /// In en, this message translates to:
  /// **'Store review account'**
  String get storeReviewAccount;

  /// No description provided for @willRetry.
  ///
  /// In en, this message translates to:
  /// **'Will retry'**
  String get willRetry;

  /// No description provided for @secondSweepDone.
  ///
  /// In en, this message translates to:
  /// **'Second sweep done'**
  String get secondSweepDone;

  /// No description provided for @openedTheDashboard.
  ///
  /// In en, this message translates to:
  /// **'Opened the dashboard'**
  String get openedTheDashboard;

  /// No description provided for @openedALog.
  ///
  /// In en, this message translates to:
  /// **'Opened a log'**
  String get openedALog;

  /// No description provided for @addAnEvent.
  ///
  /// In en, this message translates to:
  /// **'Add an event'**
  String get addAnEvent;

  /// No description provided for @editAnEvent.
  ///
  /// In en, this message translates to:
  /// **'Edit an event'**
  String get editAnEvent;

  /// No description provided for @titleEnglish.
  ///
  /// In en, this message translates to:
  /// **'Title (English)'**
  String get titleEnglish;

  /// No description provided for @titleArabic.
  ///
  /// In en, this message translates to:
  /// **'Title (Arabic)'**
  String get titleArabic;

  /// No description provided for @descriptionEnglish.
  ///
  /// In en, this message translates to:
  /// **'Description (English)'**
  String get descriptionEnglish;

  /// No description provided for @descriptionArabic.
  ///
  /// In en, this message translates to:
  /// **'Description (Arabic)'**
  String get descriptionArabic;

  /// No description provided for @startsCairoTime.
  ///
  /// In en, this message translates to:
  /// **'Starts, Cairo time'**
  String get startsCairoTime;

  /// No description provided for @endsCairoTime.
  ///
  /// In en, this message translates to:
  /// **'Ends, Cairo time'**
  String get endsCairoTime;

  /// No description provided for @dateAndTimeLike20261105.
  ///
  /// In en, this message translates to:
  /// **'Date and time, like 2026-11-05 18:30'**
  String get dateAndTimeLike20261105;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @inPerson.
  ///
  /// In en, this message translates to:
  /// **'In person'**
  String get inPerson;

  /// No description provided for @linkStartingWithHttps.
  ///
  /// In en, this message translates to:
  /// **'Link, starting with https://'**
  String get linkStartingWithHttps;

  /// No description provided for @placeName.
  ///
  /// In en, this message translates to:
  /// **'Place name'**
  String get placeName;

  /// No description provided for @aNameIsEnoughNoStreetAddress.
  ///
  /// In en, this message translates to:
  /// **'A name is enough. No street address needed.'**
  String get aNameIsEnoughNoStreetAddress;

  /// No description provided for @capacityOptional.
  ///
  /// In en, this message translates to:
  /// **'Capacity, optional'**
  String get capacityOptional;

  /// No description provided for @coverPicture.
  ///
  /// In en, this message translates to:
  /// **'Cover picture'**
  String get coverPicture;

  /// No description provided for @noPicturesInTheMediaLibraryYet.
  ///
  /// In en, this message translates to:
  /// **'No pictures in the media library yet.'**
  String get noPicturesInTheMediaLibraryYet;

  /// No description provided for @published.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get published;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @saveAsDraft.
  ///
  /// In en, this message translates to:
  /// **'Save as draft'**
  String get saveAsDraft;

  /// No description provided for @moveBackToDraft.
  ///
  /// In en, this message translates to:
  /// **'Move back to draft'**
  String get moveBackToDraft;

  /// No description provided for @cancelThisEvent.
  ///
  /// In en, this message translates to:
  /// **'Cancel this event'**
  String get cancelThisEvent;

  /// No description provided for @membersWillNoLongerSeeIt.
  ///
  /// In en, this message translates to:
  /// **'Members will no longer see it.'**
  String get membersWillNoLongerSeeIt;

  /// No description provided for @yesCancelIt.
  ///
  /// In en, this message translates to:
  /// **'Yes, cancel it'**
  String get yesCancelIt;

  /// No description provided for @useTheFormat2026110518.
  ///
  /// In en, this message translates to:
  /// **'Use the format 2026-11-05 18:30.'**
  String get useTheFormat2026110518;

  /// No description provided for @theEndMustComeAfterTheStart.
  ///
  /// In en, this message translates to:
  /// **'The end must come after the start.'**
  String get theEndMustComeAfterTheStart;

  /// No description provided for @useALinkThatStartsWithHttps.
  ///
  /// In en, this message translates to:
  /// **'Use a link that starts with https://'**
  String get useALinkThatStartsWithHttps;

  /// No description provided for @aWholeNumberAboveZero.
  ///
  /// In en, this message translates to:
  /// **'A whole number above zero.'**
  String get aWholeNumberAboveZero;

  /// No description provided for @noEventsYet.
  ///
  /// In en, this message translates to:
  /// **'No events yet'**
  String get noEventsYet;

  /// No description provided for @addOneThenPublishItWhenIt.
  ///
  /// In en, this message translates to:
  /// **'Add one, then publish it when it is ready.'**
  String get addOneThenPublishItWhenIt;

  /// No description provided for @couldNotSaveCheckTheConnectionAnd.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Check the connection and the admin access, then try again.'**
  String get couldNotSaveCheckTheConnectionAnd;

  /// No description provided for @upcomingEvents.
  ///
  /// In en, this message translates to:
  /// **'Upcoming events'**
  String get upcomingEvents;

  /// No description provided for @noEventsComingUp.
  ///
  /// In en, this message translates to:
  /// **'No events coming up'**
  String get noEventsComingUp;

  /// No description provided for @whenOwnHubPlansOneYouWill.
  ///
  /// In en, this message translates to:
  /// **'When Own Hub plans one, you will find it here.'**
  String get whenOwnHubPlansOneYouWill;

  /// No description provided for @cairoTime.
  ///
  /// In en, this message translates to:
  /// **'Cairo time'**
  String get cairoTime;

  /// An event's time span, both in Cairo time, Western digits.
  ///
  /// In en, this message translates to:
  /// **'{start} to {end}'**
  String startToEnd(String start, String end);

  /// No description provided for @openTheLink.
  ///
  /// In en, this message translates to:
  /// **'Open the link'**
  String get openTheLink;

  /// An event's capacity, when the owner set one.
  ///
  /// In en, this message translates to:
  /// **'Places: {count}'**
  String placesCount(String count);

  /// No description provided for @methodOneStepALineInArabic.
  ///
  /// In en, this message translates to:
  /// **'Method, one step a line, in Arabic'**
  String get methodOneStepALineInArabic;

  /// No description provided for @sectionOfTheBook.
  ///
  /// In en, this message translates to:
  /// **'Section of the book'**
  String get sectionOfTheBook;

  /// No description provided for @author.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get author;

  /// No description provided for @allergensCheckedBy.
  ///
  /// In en, this message translates to:
  /// **'Allergens checked by'**
  String get allergensCheckedBy;

  /// No description provided for @aSecondPersonChecksTheAllergensNever.
  ///
  /// In en, this message translates to:
  /// **'A second person checks the allergens, never the author.'**
  String get aSecondPersonChecksTheAllergensNever;

  /// No description provided for @showThisRecipeToMembers.
  ///
  /// In en, this message translates to:
  /// **'Show this recipe to members'**
  String get showThisRecipeToMembers;

  /// No description provided for @membersSeeItWithinADay.
  ///
  /// In en, this message translates to:
  /// **'Members see it within a day.'**
  String get membersSeeItWithinADay;

  /// No description provided for @fillInAllFourNumbersOrLeave.
  ///
  /// In en, this message translates to:
  /// **'Fill in all four numbers, or leave all four empty.'**
  String get fillInAllFourNumbersOrLeave;

  /// No description provided for @thisRecipeCannotGoToMembersYet.
  ///
  /// In en, this message translates to:
  /// **'This recipe cannot go to members yet. Check the steps, the section and both names.'**
  String get thisRecipeCannotGoToMembersYet;

  /// No description provided for @savedToTheLibrary.
  ///
  /// In en, this message translates to:
  /// **'Saved to the library'**
  String get savedToTheLibrary;

  /// No description provided for @savedOnThisPhoneOnlySignIn.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone only. Sign in with an admin account to save to the library.'**
  String get savedOnThisPhoneOnlySignIn;

  /// No description provided for @alsoSwitchesItForMembers.
  ///
  /// In en, this message translates to:
  /// **'Also switches it for members'**
  String get alsoSwitchesItForMembers;

  /// No description provided for @thisIsLongerThanTheAppAllows.
  ///
  /// In en, this message translates to:
  /// **'This is longer than the app allows.'**
  String get thisIsLongerThanTheAppAllows;

  /// No description provided for @methodOneStepALineInEnglish.
  ///
  /// In en, this message translates to:
  /// **'Method, one step a line, in English'**
  String get methodOneStepALineInEnglish;

  /// A move's prescription: sets times reps, Western digits.
  ///
  /// In en, this message translates to:
  /// **'{sets} × {reps}'**
  String setsReps(String sets, String reps);

  /// A held move's prescription: sets times seconds.
  ///
  /// In en, this message translates to:
  /// **'{sets} × {seconds} seconds'**
  String setsSecondsSeconds(String sets, String seconds);

  /// Rest between sets, as the owner wrote it.
  ///
  /// In en, this message translates to:
  /// **'Rest {seconds} seconds'**
  String restSecondsSeconds(String seconds);

  /// No description provided for @writtenForPregnancyCheckWithYourDoctor.
  ///
  /// In en, this message translates to:
  /// **'Written for pregnancy. Check with your doctor before you start, and stop if anything feels wrong.'**
  String get writtenForPregnancyCheckWithYourDoctor;

  /// No description provided for @writtenForAfterABirthCheckWith.
  ///
  /// In en, this message translates to:
  /// **'Written for after a birth. Check with your doctor before you start, and stop if anything feels wrong.'**
  String get writtenForAfterABirthCheckWith;

  /// No description provided for @addASession.
  ///
  /// In en, this message translates to:
  /// **'Add a session'**
  String get addASession;

  /// No description provided for @sessionTitleEnglish.
  ///
  /// In en, this message translates to:
  /// **'Session title (English)'**
  String get sessionTitleEnglish;

  /// No description provided for @sessionTitleArabic.
  ///
  /// In en, this message translates to:
  /// **'Session title (Arabic)'**
  String get sessionTitleArabic;

  /// No description provided for @whoItIsWrittenFor.
  ///
  /// In en, this message translates to:
  /// **'Who it is written for'**
  String get whoItIsWrittenFor;

  /// No description provided for @exercise.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get exercise;

  /// No description provided for @sets.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get sets;

  /// No description provided for @holdSeconds.
  ///
  /// In en, this message translates to:
  /// **'Hold, seconds'**
  String get holdSeconds;

  /// No description provided for @restSeconds.
  ///
  /// In en, this message translates to:
  /// **'Rest, seconds'**
  String get restSeconds;

  /// No description provided for @notesEnglish.
  ///
  /// In en, this message translates to:
  /// **'Notes (English)'**
  String get notesEnglish;

  /// No description provided for @notesArabic.
  ///
  /// In en, this message translates to:
  /// **'Notes (Arabic)'**
  String get notesArabic;

  /// No description provided for @safetyNoteEnglish.
  ///
  /// In en, this message translates to:
  /// **'Safety note (English)'**
  String get safetyNoteEnglish;

  /// No description provided for @safetyNoteArabic.
  ///
  /// In en, this message translates to:
  /// **'Safety note (Arabic)'**
  String get safetyNoteArabic;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @showThisProgrammeToMembers.
  ///
  /// In en, this message translates to:
  /// **'Show this programme to members'**
  String get showThisProgrammeToMembers;

  /// No description provided for @membersSeeEachSessionThatSuitsTheir.
  ///
  /// In en, this message translates to:
  /// **'Members see each session that suits their life stage, within a day.'**
  String get membersSeeEachSessionThatSuitsTheir;

  /// No description provided for @addExercisesToTheLibraryFirst.
  ///
  /// In en, this message translates to:
  /// **'Add exercises to the library first.'**
  String get addExercisesToTheLibraryFirst;

  /// No description provided for @repsOrAHoldNotBoth.
  ///
  /// In en, this message translates to:
  /// **'Reps or a hold, not both.'**
  String get repsOrAHoldNotBoth;

  /// No description provided for @thisProgrammeCannotGoToMembersYet.
  ///
  /// In en, this message translates to:
  /// **'This programme cannot go to members yet. Check that every session has moves, its numbers and who it is for, and that pregnancy and after-a-birth sessions hold no move tagged unsafe for them.'**
  String get thisProgrammeCannotGoToMembersYet;

  /// Z18, the event id the owner passes to tool/admin_access.sh upload-media for its cover.
  ///
  /// In en, this message translates to:
  /// **'Upload its pictures under this id: {id}'**
  String uploadItsPicturesUnderThisIdId(String id);

  /// No description provided for @iDidThemAll.
  ///
  /// In en, this message translates to:
  /// **'I did them all'**
  String get iDidThemAll;

  /// No description provided for @nothingInTheLogYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing in the log yet'**
  String get nothingInTheLogYet;

  /// C07, while the resend waits after a code was sent. time is minutes:seconds in Western digits, e.g. 0:27.
  ///
  /// In en, this message translates to:
  /// **'Send it again in {time}'**
  String sendItAgainInTime(String time);

  /// No description provided for @yourProgressCard.
  ///
  /// In en, this message translates to:
  /// **'Your progress card'**
  String get yourProgressCard;

  /// No description provided for @everythingYouHaveDoneOnOneCard.
  ///
  /// In en, this message translates to:
  /// **'Everything you have done, on one card. Only what is here is shared.'**
  String get everythingYouHaveDoneOnOneCard;

  /// No description provided for @showMyWeightChange.
  ///
  /// In en, this message translates to:
  /// **'Show my weight change'**
  String get showMyWeightChange;

  /// No description provided for @offUnlessYouTurnItOnAnd.
  ///
  /// In en, this message translates to:
  /// **'Off unless you turn it on, and only on this card.'**
  String get offUnlessYouTurnItOnAnd;

  /// No description provided for @yourCardFillsInAfterYourFirst.
  ///
  /// In en, this message translates to:
  /// **'Your card fills in after your first workout.'**
  String get yourCardFillsInAfterYourFirst;

  /// No description provided for @shareMyCard.
  ///
  /// In en, this message translates to:
  /// **'Share my card'**
  String get shareMyCard;

  /// No description provided for @weeksTrained.
  ///
  /// In en, this message translates to:
  /// **'Weeks trained'**
  String get weeksTrained;

  /// No description provided for @bestRunInWeeks.
  ///
  /// In en, this message translates to:
  /// **'Best run, in weeks'**
  String get bestRunInWeeks;

  /// No description provided for @mealsAdded.
  ///
  /// In en, this message translates to:
  /// **'Meals added'**
  String get mealsAdded;

  /// No description provided for @myProgressOnOwnHub.
  ///
  /// In en, this message translates to:
  /// **'My progress on Own Hub'**
  String get myProgressOnOwnHub;

  /// No description provided for @workoutsDone.
  ///
  /// In en, this message translates to:
  /// **'Workouts done'**
  String get workoutsDone;

  /// No description provided for @weightSinceMyFirstWeighIn.
  ///
  /// In en, this message translates to:
  /// **'Weight since my first weigh-in'**
  String get weightSinceMyFirstWeighIn;

  /// No description provided for @ownHubAppWomenOnly.
  ///
  /// In en, this message translates to:
  /// **'own-hub.app · Women only.'**
  String get ownHubAppWomenOnly;

  /// No description provided for @shareYourProgress.
  ///
  /// In en, this message translates to:
  /// **'Share your progress'**
  String get shareYourProgress;

  /// No description provided for @aCardOfWhatYouHaveDone.
  ///
  /// In en, this message translates to:
  /// **'A card of what you have done, ready to share'**
  String get aCardOfWhatYouHaveDone;

  /// A weight or a weight change on P05, e.g. −2.5 kg. weight is already signed and in Western digits.
  ///
  /// In en, this message translates to:
  /// **'{weight} kg'**
  String weightKg(String weight);

  /// No description provided for @forEveryMember.
  ///
  /// In en, this message translates to:
  /// **'For every member'**
  String get forEveryMember;

  /// No description provided for @switchingOneOffHereStopsItIn.
  ///
  /// In en, this message translates to:
  /// **'Switching one off here stops it in every member\'s app at her next launch. It cannot switch on anything this build does not ship.'**
  String get switchingOneOffHereStopsItIn;

  /// No description provided for @thatDidNotReachTheServer.
  ///
  /// In en, this message translates to:
  /// **'That did not reach the server'**
  String get thatDidNotReachTheServer;

  /// No description provided for @notOpenRightNow.
  ///
  /// In en, this message translates to:
  /// **'Not open right now'**
  String get notOpenRightNow;

  /// No description provided for @thisPartOfOwnHubIsNot.
  ///
  /// In en, this message translates to:
  /// **'This part of Own Hub is not open right now. Everything else works as usual.'**
  String get thisPartOfOwnHubIsNot;

  /// No description provided for @mostWomenStartWithNothingThatIs.
  ///
  /// In en, this message translates to:
  /// **'Most women start with nothing. That is plenty.'**
  String get mostWomenStartWithNothingThatIs;

  /// No description provided for @howManyDaysAWeek.
  ///
  /// In en, this message translates to:
  /// **'How many days a week?'**
  String get howManyDaysAWeek;

  /// No description provided for @howLongCanASessionBe.
  ///
  /// In en, this message translates to:
  /// **'How long can a session be?'**
  String get howLongCanASessionBe;

  /// No description provided for @shortIsFineFifteenMinutesDoneBeats.
  ///
  /// In en, this message translates to:
  /// **'Short is fine. Fifteen minutes done beats an hour planned.'**
  String get shortIsFineFifteenMinutesDoneBeats;

  /// No description provided for @aFewShortQuestionsOneAtA.
  ///
  /// In en, this message translates to:
  /// **'A few short questions, one at a time. Your week is ready at the end.'**
  String get aFewShortQuestionsOneAtA;

  /// No description provided for @addAPhotoOfYou.
  ///
  /// In en, this message translates to:
  /// **'Add a photo of you'**
  String get addAPhotoOfYou;

  /// No description provided for @womenChooseAPersonTheyCanSee.
  ///
  /// In en, this message translates to:
  /// **'Women choose a person they can see. Take it now, or add it later from your page.'**
  String get womenChooseAPersonTheyCanSee;

  /// No description provided for @takeAPhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get takeAPhoto;

  /// No description provided for @takeItAgain.
  ///
  /// In en, this message translates to:
  /// **'Take it again'**
  String get takeItAgain;

  /// No description provided for @takeYourPhoto.
  ///
  /// In en, this message translates to:
  /// **'Take your photo'**
  String get takeYourPhoto;

  /// No description provided for @faceTheLightWithAPlainWall.
  ///
  /// In en, this message translates to:
  /// **'Face the light, with a plain wall behind you.'**
  String get faceTheLightWithAPlainWall;

  /// No description provided for @howYouCoach.
  ///
  /// In en, this message translates to:
  /// **'How you coach'**
  String get howYouCoach;

  /// No description provided for @clientsLookForACoachByLanguage.
  ///
  /// In en, this message translates to:
  /// **'Clients look for a coach by language and by where they train.'**
  String get clientsLookForACoachByLanguage;

  /// No description provided for @yourClientsResults.
  ///
  /// In en, this message translates to:
  /// **'Your clients\' results'**
  String get yourClientsResults;

  /// No description provided for @eachResultIsABeforeAndAn.
  ///
  /// In en, this message translates to:
  /// **'Each result is a before and an after, laid out the same way on every coach\'s page. Your client adds her own photos and agrees in her own app, so it is always hers to share.'**
  String get eachResultIsABeforeAndAn;

  /// No description provided for @before.
  ///
  /// In en, this message translates to:
  /// **'Before'**
  String get before;

  /// No description provided for @after.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get after;

  /// No description provided for @howItWillLook.
  ///
  /// In en, this message translates to:
  /// **'How it will look'**
  String get howItWillLook;

  /// No description provided for @facesStayHiddenUnlessSheChoosesTo.
  ///
  /// In en, this message translates to:
  /// **'Faces stay hidden unless she chooses to show hers.'**
  String get facesStayHiddenUnlessSheChoosesTo;

  /// No description provided for @whenYourCheckIsDoneAskAny.
  ///
  /// In en, this message translates to:
  /// **'When your check is done, ask any client from her page on your desk.'**
  String get whenYourCheckIsDoneAskAny;

  /// No description provided for @whatYourClientsSay.
  ///
  /// In en, this message translates to:
  /// **'What your clients say'**
  String get whatYourClientsSay;

  /// No description provided for @onlyWomenYouCoachHereCanWrite.
  ///
  /// In en, this message translates to:
  /// **'Only women you coach here can write one, so every word is real.'**
  String get onlyWomenYouCoachHereCanWrite;

  /// No description provided for @coachedHere.
  ///
  /// In en, this message translates to:
  /// **'Coached here'**
  String get coachedHere;

  /// No description provided for @herWordsShowWithHerFirstName.
  ///
  /// In en, this message translates to:
  /// **'Her words show with her first name only, and she can take them back.'**
  String get herWordsShowWithHerFirstName;

  /// Y02, under the usual cycle length when what she typed is not a cycle length.
  ///
  /// In en, this message translates to:
  /// **'Between {min} and {max} days, or leave it empty'**
  String betweenMinAndMaxDaysOrLeave(String min, String max);

  /// No description provided for @theseSwitchesChangeOnlyThisPhoneSo.
  ///
  /// In en, this message translates to:
  /// **'These switches change only this phone, so you can look at a part before it ships. To stop a part for every member, use the list at the end.'**
  String get theseSwitchesChangeOnlyThisPhoneSo;

  /// No description provided for @optionalSharesBasicAppUsageWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Optional. Shares basic app usage with Google Analytics and PostHog in the US. Never your health details, name, number or messages. You can change this in Privacy.'**
  String get optionalSharesBasicAppUsageWithGoogle;

  /// No description provided for @onGoogleAnalyticsAndPosthogReceiveBasic.
  ///
  /// In en, this message translates to:
  /// **'On. Google Analytics and PostHog receive basic app usage outside Egypt, including in the US. Never your health details, name, number or messages.'**
  String get onGoogleAnalyticsAndPosthogReceiveBasic;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// R07/R08/R09 set bar: sets of today's session behind her, out of all of them.
  ///
  /// In en, this message translates to:
  /// **'Sets done: {done} of {total}'**
  String setsDoneDoneOfTotal(String done, String total);

  /// No description provided for @todaysSessionIsDone.
  ///
  /// In en, this message translates to:
  /// **'Today\'s session is done'**
  String get todaysSessionIsDone;

  /// No description provided for @anotherSession.
  ///
  /// In en, this message translates to:
  /// **'Another session'**
  String get anotherSession;

  /// No description provided for @trainingStreak.
  ///
  /// In en, this message translates to:
  /// **'Training streak'**
  String get trainingStreak;

  /// T01 week block: her training streak (D37). Never shown when she has switched it off.
  ///
  /// In en, this message translates to:
  /// **'Training streak: {days} days'**
  String trainingStreakDaysDays(String days);

  /// P01 and the streak sheet: the length of her current training streak.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String daysDays(String days);

  /// P01 and the streak sheet: her longest training streak. Never taken away.
  ///
  /// In en, this message translates to:
  /// **'Your best: {days} days'**
  String yourBestDaysDays(String days);

  /// No description provided for @day1StartsWithYourNextSession.
  ///
  /// In en, this message translates to:
  /// **'Day 1 starts with your next session.'**
  String get day1StartsWithYourNextSession;

  /// Streak sheet and P01 while a pause with an end date runs.
  ///
  /// In en, this message translates to:
  /// **'Paused until {date}'**
  String pausedUntilDate(String date);

  /// No description provided for @pausedUntilYouComeBack.
  ///
  /// In en, this message translates to:
  /// **'Paused until you come back'**
  String get pausedUntilYouComeBack;

  /// No description provided for @restDaysCountWhileYourWeekGoal.
  ///
  /// In en, this message translates to:
  /// **'Rest days count while your week goal is still in reach. A rest week you have earned covers a week that slips. Kept on this phone.'**
  String get restDaysCountWhileYourWeekGoal;

  /// No description provided for @pauseForAWeek.
  ///
  /// In en, this message translates to:
  /// **'Pause for a week'**
  String get pauseForAWeek;

  /// No description provided for @pauseForTwoWeeks.
  ///
  /// In en, this message translates to:
  /// **'Pause for two weeks'**
  String get pauseForTwoWeeks;

  /// No description provided for @pauseUntilIComeBack.
  ///
  /// In en, this message translates to:
  /// **'Pause until I come back'**
  String get pauseUntilIComeBack;

  /// No description provided for @resumeNow.
  ///
  /// In en, this message translates to:
  /// **'Resume now'**
  String get resumeNow;

  /// No description provided for @showMyTrainingStreak.
  ///
  /// In en, this message translates to:
  /// **'Show my training streak'**
  String get showMyTrainingStreak;

  /// No description provided for @keptOnThisPhoneTurnItOff.
  ///
  /// In en, this message translates to:
  /// **'Kept on this phone. Turn it off any time.'**
  String get keptOnThisPhoneTurnItOff;

  /// No description provided for @yourWeeksCountAndSoDoThe.
  ///
  /// In en, this message translates to:
  /// **'Your weeks count, and so do the days that keep your week in reach. Only what you add yourself.'**
  String get yourWeeksCountAndSoDoThe;

  /// No description provided for @thisWeeksChallenge.
  ///
  /// In en, this message translates to:
  /// **'This week\'s challenge'**
  String get thisWeeksChallenge;

  /// T01/R03 weekly challenge (D38): beat her own last-week total on one move.
  ///
  /// In en, this message translates to:
  /// **'{move}: more than last week\'s {amount}'**
  String moveMoreThanLastWeeksAmount(String move, String amount);

  /// T01/R03 weekly challenge (D38): match her own last-week total on one move.
  ///
  /// In en, this message translates to:
  /// **'{move}: match last week\'s {amount}'**
  String moveMatchLastWeeksAmount(String move, String amount);

  /// R10 reveal: the weekly challenge, met by beating last week. Her total this week.
  ///
  /// In en, this message translates to:
  /// **'You beat last week on {move}: {amount}'**
  String youBeatLastWeekOnMoveAmount(String move, String amount);

  /// R10 reveal: the weekly challenge, met by matching last week. Her total this week.
  ///
  /// In en, this message translates to:
  /// **'You matched last week on {move}: {amount}'**
  String youMatchedLastWeekOnMoveAmount(String move, String amount);

  /// No description provided for @nextMilestone.
  ///
  /// In en, this message translates to:
  /// **'Next milestone'**
  String get nextMilestone;

  /// R10 reveal: the effort she actually logged in this session.
  ///
  /// In en, this message translates to:
  /// **'{moves} moves · {sets} sets · {minutes} min'**
  String movesMovesSetsSetsMinutesMin(
    String moves,
    String sets,
    String minutes,
  );

  /// R10 reveal: a real personal best, with her previous best on the same move.
  ///
  /// In en, this message translates to:
  /// **'{move}: {now}, up from {before}'**
  String moveNowUpFromBefore(String move, String now, String before);

  /// R10 reveal: a personal best that is a harder variation rather than a bigger number.
  ///
  /// In en, this message translates to:
  /// **'{move}: a harder version than before'**
  String moveAHarderVersionThanBefore(String move);

  /// R10 reveal: moves she logged for the first time ever. A first mark, not a best.
  ///
  /// In en, this message translates to:
  /// **'First marks set on {count} moves.'**
  String firstMarksSetOnCountMoves(String count);

  /// No description provided for @readYourAnswers.
  ///
  /// In en, this message translates to:
  /// **'Read your answers'**
  String get readYourAnswers;

  /// No description provided for @checkedYourEquipment.
  ///
  /// In en, this message translates to:
  /// **'Checked your equipment'**
  String get checkedYourEquipment;

  /// No description provided for @matchedYourDaysAndMinutes.
  ///
  /// In en, this message translates to:
  /// **'Matched your days and minutes'**
  String get matchedYourDaysAndMinutes;

  /// No description provided for @preferredAQuietSessionForHome.
  ///
  /// In en, this message translates to:
  /// **'Preferred a quiet session for home'**
  String get preferredAQuietSessionForHome;

  /// No description provided for @moreYouCanDo.
  ///
  /// In en, this message translates to:
  /// **'More you can do'**
  String get moreYouCanDo;

  /// No description provided for @moreSessions.
  ///
  /// In en, this message translates to:
  /// **'More sessions'**
  String get moreSessions;

  /// T01 week block and R10: her training streak (D37). A plural message because Arabic counts agree differently at 1, 2, 3 to 10 and 11 and up. Never shown when she has switched it off.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{Training streak: 1 day} other{Training streak: {days} days}}'**
  String daysPluralOneTrainingStreak1Day(int days);

  /// P01 and the streak sheet: her longest training streak. Never taken away.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{Your best: 1 day} other{Your best: {days} days}}'**
  String daysPluralOneYourBest1Day(int days);

  /// R10 reveal: moves she logged for the first time ever. A first mark, not a best.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{First mark set on 1 move.} other{First marks set on {count} moves.}}'**
  String countPluralOneFirstMarkSetOn(int count);

  /// R10 reveal: the effort she actually logged in this session. Labels before each figure so no noun has to agree with its number.
  ///
  /// In en, this message translates to:
  /// **'Moves: {moves} · Sets: {sets} · Time: {minutes} min'**
  String movesMovesSetsSetsTimeMinutesMin(
    String moves,
    String sets,
    String minutes,
  );

  /// R10 reveal: the effort she actually logged in this session. Moves and sets are labelled so they need no agreement; the minutes are a plural because Arabic says دقيقة واحدة, دقيقتين, 3 دقايق and 11 دقيقة.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, one{Moves: {moves} · Sets: {sets} · Time: 1 min} other{Moves: {moves} · Sets: {sets} · Time: {minutes} min}}'**
  String minutesPluralOneMovesMovesSetsSets(
    int minutes,
    String moves,
    String sets,
  );

  /// No description provided for @exerciseLibrary.
  ///
  /// In en, this message translates to:
  /// **'Exercise library'**
  String get exerciseLibrary;

  /// No description provided for @seeHowEveryMoveIsDone.
  ///
  /// In en, this message translates to:
  /// **'See how every move is done'**
  String get seeHowEveryMoveIsDone;

  /// No description provided for @watchTheMoves.
  ///
  /// In en, this message translates to:
  /// **'Watch the moves'**
  String get watchTheMoves;

  /// No description provided for @searchMoves.
  ///
  /// In en, this message translates to:
  /// **'Search moves'**
  String get searchMoves;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @chooseAMoveFromTheLibrary.
  ///
  /// In en, this message translates to:
  /// **'Choose a move from the library'**
  String get chooseAMoveFromTheLibrary;

  /// No description provided for @openTheExerciseLibrary.
  ///
  /// In en, this message translates to:
  /// **'Open the exercise library'**
  String get openTheExerciseLibrary;

  /// No description provided for @stretchesAndWarmUps.
  ///
  /// In en, this message translates to:
  /// **'Stretches and warm-ups'**
  String get stretchesAndWarmUps;

  /// No description provided for @homeOrGym.
  ///
  /// In en, this message translates to:
  /// **'Home or gym'**
  String get homeOrGym;

  /// No description provided for @gymOnly.
  ///
  /// In en, this message translates to:
  /// **'Gym only'**
  String get gymOnly;

  /// No description provided for @gymMachines.
  ///
  /// In en, this message translates to:
  /// **'Gym machines'**
  String get gymMachines;

  /// No description provided for @mat.
  ///
  /// In en, this message translates to:
  /// **'Mat'**
  String get mat;

  /// No description provided for @machine.
  ///
  /// In en, this message translates to:
  /// **'Machine'**
  String get machine;

  /// No description provided for @cableMachine.
  ///
  /// In en, this message translates to:
  /// **'Cable machine'**
  String get cableMachine;

  /// No description provided for @barbell.
  ///
  /// In en, this message translates to:
  /// **'Barbell'**
  String get barbell;

  /// No description provided for @smithMachine.
  ///
  /// In en, this message translates to:
  /// **'Smith machine'**
  String get smithMachine;

  /// No description provided for @bench.
  ///
  /// In en, this message translates to:
  /// **'Bench'**
  String get bench;

  /// No description provided for @step.
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get step;

  /// No description provided for @kettlebell.
  ///
  /// In en, this message translates to:
  /// **'Kettlebell'**
  String get kettlebell;

  /// No description provided for @glutes.
  ///
  /// In en, this message translates to:
  /// **'Glutes'**
  String get glutes;

  /// No description provided for @frontOfThighs.
  ///
  /// In en, this message translates to:
  /// **'Front of thighs'**
  String get frontOfThighs;

  /// No description provided for @backOfThighs.
  ///
  /// In en, this message translates to:
  /// **'Back of thighs'**
  String get backOfThighs;

  /// No description provided for @innerAndOuterThighs.
  ///
  /// In en, this message translates to:
  /// **'Inner and outer thighs'**
  String get innerAndOuterThighs;

  /// No description provided for @innerThighs.
  ///
  /// In en, this message translates to:
  /// **'Inner thighs'**
  String get innerThighs;

  /// No description provided for @outerThighs.
  ///
  /// In en, this message translates to:
  /// **'Outer thighs'**
  String get outerThighs;

  /// No description provided for @calves.
  ///
  /// In en, this message translates to:
  /// **'Calves'**
  String get calves;

  /// No description provided for @absAndSides.
  ///
  /// In en, this message translates to:
  /// **'Abs and sides'**
  String get absAndSides;

  /// No description provided for @core.
  ///
  /// In en, this message translates to:
  /// **'Core'**
  String get core;

  /// No description provided for @sidesOfTheWaist.
  ///
  /// In en, this message translates to:
  /// **'Sides of the waist'**
  String get sidesOfTheWaist;

  /// No description provided for @lowerBack.
  ///
  /// In en, this message translates to:
  /// **'Lower back'**
  String get lowerBack;

  /// No description provided for @chest.
  ///
  /// In en, this message translates to:
  /// **'Chest'**
  String get chest;

  /// No description provided for @upperBack.
  ///
  /// In en, this message translates to:
  /// **'Upper back'**
  String get upperBack;

  /// No description provided for @sidesOfTheBack.
  ///
  /// In en, this message translates to:
  /// **'Sides of the back'**
  String get sidesOfTheBack;

  /// No description provided for @shoulders.
  ///
  /// In en, this message translates to:
  /// **'Shoulders'**
  String get shoulders;

  /// No description provided for @frontOfTheShoulders.
  ///
  /// In en, this message translates to:
  /// **'Front of the shoulders'**
  String get frontOfTheShoulders;

  /// No description provided for @sidesOfTheShoulders.
  ///
  /// In en, this message translates to:
  /// **'Sides of the shoulders'**
  String get sidesOfTheShoulders;

  /// No description provided for @backOfTheShoulders.
  ///
  /// In en, this message translates to:
  /// **'Back of the shoulders'**
  String get backOfTheShoulders;

  /// No description provided for @arms.
  ///
  /// In en, this message translates to:
  /// **'Arms'**
  String get arms;

  /// No description provided for @biceps.
  ///
  /// In en, this message translates to:
  /// **'Biceps'**
  String get biceps;

  /// No description provided for @triceps.
  ///
  /// In en, this message translates to:
  /// **'Triceps'**
  String get triceps;

  /// No description provided for @forearms.
  ///
  /// In en, this message translates to:
  /// **'Forearms'**
  String get forearms;

  /// No description provided for @musclesWorked.
  ///
  /// In en, this message translates to:
  /// **'Muscles worked'**
  String get musclesWorked;

  /// No description provided for @alsoWorks.
  ///
  /// In en, this message translates to:
  /// **'Also works'**
  String get alsoWorks;

  /// No description provided for @howToSetUp.
  ///
  /// In en, this message translates to:
  /// **'How to set up'**
  String get howToSetUp;

  /// No description provided for @beginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get beginner;

  /// No description provided for @intermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get intermediate;

  /// No description provided for @front.
  ///
  /// In en, this message translates to:
  /// **'Front'**
  String get front;

  /// No description provided for @side.
  ///
  /// In en, this message translates to:
  /// **'Side'**
  String get side;

  /// No description provided for @fromBehind.
  ///
  /// In en, this message translates to:
  /// **'From behind'**
  String get fromBehind;

  /// No description provided for @otherSide.
  ///
  /// In en, this message translates to:
  /// **'Other side'**
  String get otherSide;

  /// No description provided for @gettingTheVideo.
  ///
  /// In en, this message translates to:
  /// **'Getting the video'**
  String get gettingTheVideo;

  /// No description provided for @thisVideoNeedsAConnectionTheFirst.
  ///
  /// In en, this message translates to:
  /// **'This video needs a connection the first time. After that it plays without one.'**
  String get thisVideoNeedsAConnectionTheFirst;

  /// No description provided for @theExerciseLibraryIsOnItsWay.
  ///
  /// In en, this message translates to:
  /// **'The exercise library is on its way'**
  String get theExerciseLibraryIsOnItsWay;

  /// No description provided for @itArrivesTheNextTimeYouOpen.
  ///
  /// In en, this message translates to:
  /// **'It arrives the next time you open the app online.'**
  String get itArrivesTheNextTimeYouOpen;

  /// No description provided for @tryAnotherFilterOrClearTheSearch.
  ///
  /// In en, this message translates to:
  /// **'Try another filter, or clear the search.'**
  String get tryAnotherFilterOrClearTheSearch;

  /// No description provided for @someMovesAreHiddenWhileYouAre.
  ///
  /// In en, this message translates to:
  /// **'Some moves are hidden while you are pregnant. Ask your doctor before you try anything new.'**
  String get someMovesAreHiddenWhileYouAre;

  /// No description provided for @someMovesAreHiddenInTheWeeks.
  ///
  /// In en, this message translates to:
  /// **'Some moves are hidden in the weeks after a birth. Wait for your doctor\'s OK before you try them.'**
  String get someMovesAreHiddenInTheWeeks;

  /// No description provided for @feelGoodAndMove.
  ///
  /// In en, this message translates to:
  /// **'Feel good and move'**
  String get feelGoodAndMove;

  /// No description provided for @loseSteadily.
  ///
  /// In en, this message translates to:
  /// **'Lose steadily'**
  String get loseSteadily;

  /// No description provided for @atHomeQuietNothingToBuy.
  ///
  /// In en, this message translates to:
  /// **'At home · quiet · nothing to buy'**
  String get atHomeQuietNothingToBuy;

  /// No description provided for @atHomeQuietWithYourDumbbells.
  ///
  /// In en, this message translates to:
  /// **'At home · quiet · with your dumbbells'**
  String get atHomeQuietWithYourDumbbells;

  /// No description provided for @atTheGymWeightsAndMachines.
  ///
  /// In en, this message translates to:
  /// **'At the gym · weights and machines'**
  String get atTheGymWeightsAndMachines;

  /// R07 and R08: her last session's weight for a loaded move, and the next weight up.
  ///
  /// In en, this message translates to:
  /// **'You finished every set at {weight}. Try {next} today.'**
  String youFinishedEverySetAtWeightTry(String weight, String next);

  /// R07 and R08: why the weight is not going up yet.
  ///
  /// In en, this message translates to:
  /// **'Last time you did {weight}. Stay there until every set is done.'**
  String lastTimeYouDidWeightStayThere(String weight);

  /// R07 and R08: she is coming back to a loaded move after a break.
  ///
  /// In en, this message translates to:
  /// **'It has been a while since {weight}. Start a little lighter and build back.'**
  String itHasBeenAWhileSinceWeight(String weight);

  /// No description provided for @firstTimeAtTheGym.
  ///
  /// In en, this message translates to:
  /// **'First time at the gym?'**
  String get firstTimeAtTheGym;

  /// No description provided for @beforeYouStart.
  ///
  /// In en, this message translates to:
  /// **'Before you start'**
  String get beforeYouStart;

  /// No description provided for @todaysSessionIsShortBringWaterAnd.
  ///
  /// In en, this message translates to:
  /// **'Today\'s session is short. Bring water and a small towel, and wear shoes you can move in. The staff at the gym are happy to show you where things are.'**
  String get todaysSessionIsShortBringWaterAnd;

  /// No description provided for @findYourEquipment.
  ///
  /// In en, this message translates to:
  /// **'Find your equipment'**
  String get findYourEquipment;

  /// No description provided for @lookForTheStationYourFirstMove.
  ///
  /// In en, this message translates to:
  /// **'Look for the station your first move names. If you cannot find it, ask the staff. If it is busy, swap the move from the workout and come back to it later.'**
  String get lookForTheStationYourFirstMove;

  /// No description provided for @whatASetIs.
  ///
  /// In en, this message translates to:
  /// **'What a set is'**
  String get whatASetIs;

  /// No description provided for @aRepIsOneTimeThroughA.
  ///
  /// In en, this message translates to:
  /// **'A rep is one time through a move. A set is a few reps in a row. Rest between sets, then go again.'**
  String get aRepIsOneTimeThroughA;

  /// No description provided for @tryItLogAPracticeSet.
  ///
  /// In en, this message translates to:
  /// **'Try it: log a practice set'**
  String get tryItLogAPracticeSet;

  /// No description provided for @practiceSetLoggedNothingIsSaved.
  ///
  /// In en, this message translates to:
  /// **'Practice set logged. Nothing is saved.'**
  String get practiceSetLoggedNothingIsSaved;

  /// No description provided for @startWithConfidence.
  ///
  /// In en, this message translates to:
  /// **'Start with confidence'**
  String get startWithConfidence;

  /// No description provided for @goAtYourOwnPaceIfYou.
  ///
  /// In en, this message translates to:
  /// **'Go at your own pace. If you feel pain or feel unwell, stop and ask the gym staff for help.'**
  String get goAtYourOwnPaceIfYou;

  /// No description provided for @tapChangeToAddTheWeightYou.
  ///
  /// In en, this message translates to:
  /// **'Tap Change to add the weight you lifted, so next time starts from it.'**
  String get tapChangeToAddTheWeightYou;

  /// No description provided for @eachSessionIsAFullBodyWith.
  ///
  /// In en, this message translates to:
  /// **'Each session is a full body, with fewer, heavier reps and a long rest.'**
  String get eachSessionIsAFullBodyWith;

  /// No description provided for @eachSessionIsAGentleFullBody.
  ///
  /// In en, this message translates to:
  /// **'Each session is a gentle full body, with easy reps and short rests.'**
  String get eachSessionIsAGentleFullBody;

  /// No description provided for @eachSessionIsASteadyCircuitWith.
  ///
  /// In en, this message translates to:
  /// **'Each session is a steady circuit, with plenty of reps and short rests.'**
  String get eachSessionIsASteadyCircuitWith;

  /// No description provided for @yourEnergyIsLowToday.
  ///
  /// In en, this message translates to:
  /// **'Your energy is low today.'**
  String get yourEnergyIsLowToday;

  /// No description provided for @youHaveCrampsToday.
  ///
  /// In en, this message translates to:
  /// **'You have cramps today.'**
  String get youHaveCrampsToday;

  /// No description provided for @yourEnergyIsLowAndYouHave.
  ///
  /// In en, this message translates to:
  /// **'Your energy is low and you have cramps today.'**
  String get yourEnergyIsLowAndYouHave;

  /// No description provided for @aComfyDinnerHighInProtein.
  ///
  /// In en, this message translates to:
  /// **'A comfy dinner, high in protein.'**
  String get aComfyDinnerHighInProtein;

  /// No description provided for @aComfyDinner.
  ///
  /// In en, this message translates to:
  /// **'A comfy dinner.'**
  String get aComfyDinner;

  /// No description provided for @highInProtein.
  ///
  /// In en, this message translates to:
  /// **'High in protein.'**
  String get highInProtein;

  /// No description provided for @yourWeekIsFullSwapADinner.
  ///
  /// In en, this message translates to:
  /// **'Your week is full. Swap a dinner to fit this one in.'**
  String get yourWeekIsFullSwapADinner;

  /// No description provided for @planYourWeekFirst.
  ///
  /// In en, this message translates to:
  /// **'Plan your week first'**
  String get planYourWeekFirst;

  /// No description provided for @pickYourDinnersForTheWeekAnd.
  ///
  /// In en, this message translates to:
  /// **'Pick your dinners for the week and your shopping list builds itself.'**
  String get pickYourDinnersForTheWeekAnd;

  /// No description provided for @planMyWeek.
  ///
  /// In en, this message translates to:
  /// **'Plan my week'**
  String get planMyWeek;

  /// No description provided for @yourConnectionIsTooSlow.
  ///
  /// In en, this message translates to:
  /// **'Your connection is too slow'**
  String get yourConnectionIsTooSlow;

  /// No description provided for @stillWorkingASlowConnectionCanTake.
  ///
  /// In en, this message translates to:
  /// **'Still working. A slow connection can take a little longer.'**
  String get stillWorkingASlowConnectionCanTake;

  /// No description provided for @slowConnectionStillGettingTheVideo.
  ///
  /// In en, this message translates to:
  /// **'Slow connection, still getting the video'**
  String get slowConnectionStillGettingTheVideo;

  /// No description provided for @weCouldNotFinishTheCheckIn.
  ///
  /// In en, this message translates to:
  /// **'We could not finish the check in time. Your photos are already deleted from this phone. Move somewhere with a stronger signal and take them again.'**
  String get weCouldNotFinishTheCheckIn;

  /// No description provided for @arabicText_3cakp.
  ///
  /// In en, this message translates to:
  /// **'مصري · كل حاجة في التطبيق'**
  String get arabicText_3cakp;

  /// R05 confirm button, names the move she picked.
  ///
  /// In en, this message translates to:
  /// **'Swap to {name}'**
  String swapToName(String name);

  /// No description provided for @noSwapForThisMoveRightNow.
  ///
  /// In en, this message translates to:
  /// **'No swap for this move right now'**
  String get noSwapForThisMoveRightNow;

  /// No description provided for @tryFewerFiltersToSeeMoreWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Try fewer filters to see more workouts.'**
  String get tryFewerFiltersToSeeMoreWorkouts;

  /// No description provided for @gladYouShowedUpToday.
  ///
  /// In en, this message translates to:
  /// **'Glad you showed up today.'**
  String get gladYouShowedUpToday;

  /// No description provided for @dayOneStartsWithYourNextSession.
  ///
  /// In en, this message translates to:
  /// **'Day one starts with your next session.'**
  String get dayOneStartsWithYourNextSession;

  /// No description provided for @ramadanModeOn.
  ///
  /// In en, this message translates to:
  /// **'Ramadan mode on'**
  String get ramadanModeOn;

  /// No description provided for @dangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get dangerZone;

  /// No description provided for @readyWhenYouAre.
  ///
  /// In en, this message translates to:
  /// **'Ready when you are.'**
  String get readyWhenYouAre;

  /// No description provided for @trainedTodayAddItInATap.
  ///
  /// In en, this message translates to:
  /// **'Trained today? Add it in a tap.'**
  String get trainedTodayAddItInATap;

  /// No description provided for @aShortSessionStillCountsReadyWhen.
  ///
  /// In en, this message translates to:
  /// **'A short session still counts. Ready when you are.'**
  String get aShortSessionStillCountsReadyWhen;

  /// No description provided for @newMovesAreWaitingInTheLibrary.
  ///
  /// In en, this message translates to:
  /// **'New moves are waiting in the library.'**
  String get newMovesAreWaitingInTheLibrary;

  /// No description provided for @yourPlanIsWhereYouLeftIt.
  ///
  /// In en, this message translates to:
  /// **'Your plan is where you left it. Pick it up any time.'**
  String get yourPlanIsWhereYouLeftIt;

  /// No description provided for @aLittleMovementTodayNoPressure.
  ///
  /// In en, this message translates to:
  /// **'A little movement today? No pressure.'**
  String get aLittleMovementTodayNoPressure;

  /// No description provided for @restIsOverYourNextSetIs.
  ///
  /// In en, this message translates to:
  /// **'Rest is over. Your next set is ready.'**
  String get restIsOverYourNextSetIs;

  /// No description provided for @gentleCheckIns.
  ///
  /// In en, this message translates to:
  /// **'Gentle check-ins'**
  String get gentleCheckIns;

  /// No description provided for @aKindWordIfYouHaveBeen.
  ///
  /// In en, this message translates to:
  /// **'A kind word if you have been away for a while.'**
  String get aKindWordIfYouHaveBeen;

  /// No description provided for @restTimer.
  ///
  /// In en, this message translates to:
  /// **'Rest timer'**
  String get restTimer;

  /// No description provided for @tellsYouWhenYourRestBetweenSets.
  ///
  /// In en, this message translates to:
  /// **'Tells you when your rest between sets is over.'**
  String get tellsYouWhenYourRestBetweenSets;

  /// No description provided for @remindMeToAddASessionI.
  ///
  /// In en, this message translates to:
  /// **'Remind me to add a session I did'**
  String get remindMeToAddASessionI;

  /// No description provided for @gentleCheckInsWhenIveBeenAway.
  ///
  /// In en, this message translates to:
  /// **'Gentle check-ins when I\'ve been away'**
  String get gentleCheckInsWhenIveBeenAway;

  /// No description provided for @restTimerAlert.
  ///
  /// In en, this message translates to:
  /// **'Rest timer alert'**
  String get restTimerAlert;

  /// No description provided for @remindersThatFitYourDay.
  ///
  /// In en, this message translates to:
  /// **'Reminders that fit your day'**
  String get remindersThatFitYourDay;

  /// No description provided for @aQuietNoteOnTheDaysYou.
  ///
  /// In en, this message translates to:
  /// **'A quiet note on the days you pick'**
  String get aQuietNoteOnTheDaysYou;

  /// No description provided for @aPingWhenYourRestBetweenSets.
  ///
  /// In en, this message translates to:
  /// **'A ping when your rest between sets ends'**
  String get aPingWhenYourRestBetweenSets;

  /// No description provided for @turnOnReminders.
  ///
  /// In en, this message translates to:
  /// **'Turn on reminders'**
  String get turnOnReminders;

  /// No description provided for @yourTrainingYourFoodYourMonthWomen.
  ///
  /// In en, this message translates to:
  /// **'Your training, your food, your month. Women only.'**
  String get yourTrainingYourFoodYourMonthWomen;

  /// No description provided for @aPlanThatListensToYourBody.
  ///
  /// In en, this message translates to:
  /// **'A plan that listens to your body'**
  String get aPlanThatListensToYourBody;

  /// No description provided for @sayHowYouFeelTodayOnHarder.
  ///
  /// In en, this message translates to:
  /// **'Say how you feel today. On harder days Own Hub can suggest a gentler session. What you note stays on your phone unless you choose to back it up.'**
  String get sayHowYouFeelTodayOnHarder;

  /// No description provided for @yourDayAsYouFeelIt.
  ///
  /// In en, this message translates to:
  /// **'Your day, as you feel it'**
  String get yourDayAsYouFeelIt;

  /// No description provided for @howYouFeelToday.
  ///
  /// In en, this message translates to:
  /// **'How you feel today'**
  String get howYouFeelToday;

  /// No description provided for @lowOnEnergyALighterVersionOf.
  ///
  /// In en, this message translates to:
  /// **'Low on energy? A lighter version of today\'s session would show up here.'**
  String get lowOnEnergyALighterVersionOf;

  /// No description provided for @aFewGentleRemindersTurnAnyOf.
  ///
  /// In en, this message translates to:
  /// **'A few gentle reminders. Turn any of them off here.'**
  String get aFewGentleRemindersTurnAnyOf;

  /// Home: the first-week arc, counted in steps so it is never read against this week's sessions.
  ///
  /// In en, this message translates to:
  /// **'Your first week: {done} of {total} steps'**
  String yourFirstWeekDoneOfTotalSteps(String done, String total);

  /// No description provided for @crampsAppetiteSleepAndMore.
  ///
  /// In en, this message translates to:
  /// **'Cramps, appetite, sleep and more'**
  String get crampsAppetiteSleepAndMore;

  /// No description provided for @remindersAndExtras.
  ///
  /// In en, this message translates to:
  /// **'Reminders and extras'**
  String get remindersAndExtras;

  /// No description provided for @privacyAndData.
  ///
  /// In en, this message translates to:
  /// **'Privacy and data'**
  String get privacyAndData;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @howWeeksCount.
  ///
  /// In en, this message translates to:
  /// **'How weeks count'**
  String get howWeeksCount;

  /// O05 headline: her days and minutes.
  ///
  /// In en, this message translates to:
  /// **'{days} days a week · {minutes} min a session'**
  String daysDaysAWeekMinutesMinA(String days, String minutes);

  /// No description provided for @sweetToothBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Sweet Tooth Breakfast'**
  String get sweetToothBreakfast;

  /// No description provided for @saltyFullingBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Salty fulling Breakfast'**
  String get saltyFullingBreakfast;

  /// No description provided for @lunchyJunkyYum.
  ///
  /// In en, this message translates to:
  /// **'Lunchy junky yum'**
  String get lunchyJunkyYum;

  /// No description provided for @comfyDinner.
  ///
  /// In en, this message translates to:
  /// **'Comfy Dinner'**
  String get comfyDinner;

  /// Her answers read back: days and minutes, trained at home.
  ///
  /// In en, this message translates to:
  /// **'{days} days a week · {minutes} min a session · At home'**
  String daysDaysAWeekMinutesMinA_ew0mi(String days, String minutes);

  /// Her answers read back: days and minutes, at a ladies-only gym.
  ///
  /// In en, this message translates to:
  /// **'{days} days a week · {minutes} min a session · At a ladies-only gym'**
  String daysDaysAWeekMinutesMinA_q73s6(String days, String minutes);

  /// Her answers read back: days and minutes, at home and the gym.
  ///
  /// In en, this message translates to:
  /// **'{days} days a week · {minutes} min a session · At home and the gym'**
  String daysDaysAWeekMinutesMinA_3morb(String days, String minutes);

  /// No description provided for @remindersNeverComeBetween10PmAnd.
  ///
  /// In en, this message translates to:
  /// **'Reminders never come between 10 pm and 8 am. A rest timer you started, or word that your check is done, can still reach you.'**
  String get remindersNeverComeBetween10PmAnd;

  /// No description provided for @aQuickWayToAddASession.
  ///
  /// In en, this message translates to:
  /// **'A quick way to add a session you did'**
  String get aQuickWayToAddASession;

  /// No description provided for @pickOneItShapesYourProgram.
  ///
  /// In en, this message translates to:
  /// **'Pick one. It shapes your program.'**
  String get pickOneItShapesYourProgram;

  /// No description provided for @makeItLookLikeYou.
  ///
  /// In en, this message translates to:
  /// **'Make it look like you'**
  String get makeItLookLikeYou;

  /// No description provided for @bothSwitchBetweenThemWheneverYouLike.
  ///
  /// In en, this message translates to:
  /// **'Both. Switch between them whenever you like.'**
  String get bothSwitchBetweenThemWheneverYouLike;

  /// No description provided for @aPlanThatAdjustsToHowYou.
  ///
  /// In en, this message translates to:
  /// **'A plan that adjusts to how you feel'**
  String get aPlanThatAdjustsToHowYou;

  /// No description provided for @thatsOwnHub.
  ///
  /// In en, this message translates to:
  /// **'That\'s Own Hub'**
  String get thatsOwnHub;

  /// No description provided for @weJustNeedYourNumberAndA_1vu4x.
  ///
  /// In en, this message translates to:
  /// **'We just need your number and a quick check that you\'re a woman.'**
  String get weJustNeedYourNumberAndA_1vu4x;

  /// No description provided for @firstYourWeekThenYourNumberAnd_10ray.
  ///
  /// In en, this message translates to:
  /// **'First your week, then your number and a quick check that you\'re a woman.'**
  String get firstYourWeekThenYourNumberAnd_10ray;

  /// No description provided for @ownHubIsAFitnessAppFor_loijw.
  ///
  /// In en, this message translates to:
  /// **'Own Hub is a fitness app for women only. Home shows today\'s workout, what you\'ve eaten and how your week is going. It\'s a sample week, so tap anything.'**
  String get ownHubIsAFitnessAppFor_loijw;

  /// No description provided for @mostWomenStartWithNothingAndThats.
  ///
  /// In en, this message translates to:
  /// **'Most women start with nothing, and that\'s plenty.'**
  String get mostWomenStartWithNothingAndThats;

  /// No description provided for @hitYourGoalAndTheWeekCounts.
  ///
  /// In en, this message translates to:
  /// **'Hit your goal and the week counts. If you miss a week, a rest week you\'ve earned covers it.'**
  String get hitYourGoalAndTheWeekCounts;

  /// No description provided for @week1StartsWithFourMovesOn_9iwwr.
  ///
  /// In en, this message translates to:
  /// **'Week 1 starts with four moves on the floor. No jumping, so nobody next door will hear a thing.'**
  String get week1StartsWithFourMovesOn_9iwwr;

  /// No description provided for @theresNoDeadlineFinishingThemAllIs.
  ///
  /// In en, this message translates to:
  /// **'There\'s no deadline. Finishing them all is just the quickest way to learn where everything is.'**
  String get theresNoDeadlineFinishingThemAllIs;

  /// No description provided for @allDoneTheAppWontChangeFrom.
  ///
  /// In en, this message translates to:
  /// **'All done. The app won\'t change from here, you\'ve just used every part of it once.'**
  String get allDoneTheAppWontChangeFrom;

  /// No description provided for @nothingsLostOneSessionGetsItGoing.
  ///
  /// In en, this message translates to:
  /// **'Nothing\'s lost. One session gets it going again.'**
  String get nothingsLostOneSessionGetsItGoing;

  /// No description provided for @tapOneAndItsSavedYouCan.
  ///
  /// In en, this message translates to:
  /// **'Tap one and it\'s saved. You can undo for five seconds.'**
  String get tapOneAndItsSavedYouCan;

  /// No description provided for @ifYouDontTurnItOnNothing.
  ///
  /// In en, this message translates to:
  /// **'If you don\'t turn it on, nothing else changes. Your health data stays on this phone.'**
  String get ifYouDontTurnItOnNothing;

  /// No description provided for @takeItAtWhateverPaceFeelsRight.
  ///
  /// In en, this message translates to:
  /// **'Take it at whatever pace feels right. If something hurts or you feel unwell, stop and ask the gym staff for help.'**
  String get takeItAtWhateverPaceFeelsRight;

  /// No description provided for @aShortOneStillCountsWheneverYoure.
  ///
  /// In en, this message translates to:
  /// **'A short one still counts. Whenever you\'re ready.'**
  String get aShortOneStillCountsWheneverYoure;

  /// No description provided for @aFriendlyNudgeIfYouveBeenAway.
  ///
  /// In en, this message translates to:
  /// **'A friendly nudge if you\'ve been away a while.'**
  String get aFriendlyNudgeIfYouveBeenAway;

  /// No description provided for @remindersNeverComeBetween10PmAnd_z63uh.
  ///
  /// In en, this message translates to:
  /// **'Reminders never come between 10 pm and 8 am. A rest timer you started, or news that your check is done, can still get through.'**
  String get remindersNeverComeBetween10PmAnd_z63uh;

  /// No description provided for @remindersCantBeSetOnThisPhone.
  ///
  /// In en, this message translates to:
  /// **'Reminders can\'t be set on this phone.'**
  String get remindersCantBeSetOnThisPhone;

  /// No description provided for @joinAsACoach.
  ///
  /// In en, this message translates to:
  /// **'Join as a coach'**
  String get joinAsACoach;

  /// No description provided for @howManyDaysAndForHowLong.
  ///
  /// In en, this message translates to:
  /// **'How many days, and for how long?'**
  String get howManyDaysAndForHowLong;

  /// No description provided for @useADifferentNumber.
  ///
  /// In en, this message translates to:
  /// **'Use a different number'**
  String get useADifferentNumber;

  /// No description provided for @switchLanguageToArabic.
  ///
  /// In en, this message translates to:
  /// **'Switch language to Arabic'**
  String get switchLanguageToArabic;

  /// No description provided for @switchLanguageToEnglish.
  ///
  /// In en, this message translates to:
  /// **'Switch language to English'**
  String get switchLanguageToEnglish;

  /// No description provided for @lookStraightAtTheCamera.
  ///
  /// In en, this message translates to:
  /// **'Look straight at the camera'**
  String get lookStraightAtTheCamera;

  /// No description provided for @turnYourHeadALittleToYour.
  ///
  /// In en, this message translates to:
  /// **'Turn your head a little to your left'**
  String get turnYourHeadALittleToYour;

  /// No description provided for @turnYourHeadALittleToYour_g5o1x.
  ///
  /// In en, this message translates to:
  /// **'Turn your head a little to your right'**
  String get turnYourHeadALittleToYour_g5o1x;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @checkYourPhotos.
  ///
  /// In en, this message translates to:
  /// **'Check your photos'**
  String get checkYourPhotos;

  /// No description provided for @isYourFaceClearInEachOne.
  ///
  /// In en, this message translates to:
  /// **'Is your face clear in each one? If not, take them again.'**
  String get isYourFaceClearInEachOne;

  /// No description provided for @useThesePhotos.
  ///
  /// In en, this message translates to:
  /// **'Use these photos'**
  String get useThesePhotos;

  /// No description provided for @retake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get retake;

  /// No description provided for @checkYourPhoto.
  ///
  /// In en, this message translates to:
  /// **'Check your photo'**
  String get checkYourPhoto;

  /// No description provided for @canYouReadEveryWordIfNot.
  ///
  /// In en, this message translates to:
  /// **'Can you read every word? If not, take it again.'**
  String get canYouReadEveryWordIfNot;

  /// No description provided for @useThisPhoto.
  ///
  /// In en, this message translates to:
  /// **'Use this photo'**
  String get useThisPhoto;

  /// No description provided for @thisLooksLikeTheFrontOfThe.
  ///
  /// In en, this message translates to:
  /// **'This looks like the front of the card. Retake?'**
  String get thisLooksLikeTheFrontOfThe;

  /// No description provided for @nowTurnTheCardOver.
  ///
  /// In en, this message translates to:
  /// **'Now turn the card over'**
  String get nowTurnTheCardOver;

  /// No description provided for @theBackHasNoPhotoOnIt.
  ///
  /// In en, this message translates to:
  /// **'The back has no photo on it. Tap Ready when it is facing the camera.'**
  String get theBackHasNoPhotoOnIt;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @havingTroubleAskAWomanToCheck.
  ///
  /// In en, this message translates to:
  /// **'Having trouble? Ask a woman to check you'**
  String get havingTroubleAskAWomanToCheck;

  /// No description provided for @timeIsUpForThisStep.
  ///
  /// In en, this message translates to:
  /// **'Time is up for this step'**
  String get timeIsUpForThisStep;

  /// No description provided for @forYourSafetyItStaysOpenA.
  ///
  /// In en, this message translates to:
  /// **'For your safety it stays open a few minutes only. Start again, it is quick.'**
  String get forYourSafetyItStaysOpenA;

  /// No description provided for @startAgain.
  ///
  /// In en, this message translates to:
  /// **'Start again'**
  String get startAgain;

  /// Screen reader label on each selfie thumbnail on the C11 review. The count comes from the server's liveness challenge, so it cannot be baked into the sentence.
  ///
  /// In en, this message translates to:
  /// **'Photo {number} of {total}'**
  String photoNumberOfTotal(String number, String total);

  /// No description provided for @yourMuscles.
  ///
  /// In en, this message translates to:
  /// **'Your muscles'**
  String get yourMuscles;

  /// No description provided for @seeTheBack.
  ///
  /// In en, this message translates to:
  /// **'See the back'**
  String get seeTheBack;

  /// No description provided for @seeTheFront.
  ///
  /// In en, this message translates to:
  /// **'See the front'**
  String get seeTheFront;

  /// No description provided for @dragToTurnTapAMuscleFor.
  ///
  /// In en, this message translates to:
  /// **'Drag to turn. Tap a muscle for its sets.'**
  String get dragToTurnTapAMuscleFor;

  /// No description provided for @moreTraining.
  ///
  /// In en, this message translates to:
  /// **'More training'**
  String get moreTraining;

  /// P06: the last day she logged a set for this muscle group. {day} is Today, Yesterday, a weekday name, or 'N days ago'.
  ///
  /// In en, this message translates to:
  /// **'Last trained: {day}'**
  String lastTrainedDay(String day);

  /// No description provided for @notTrainedYet.
  ///
  /// In en, this message translates to:
  /// **'Not trained yet'**
  String get notTrainedYet;

  /// P06: how long since a muscle group last had a set, when it is more than a week. A plural message because Arabic counts agree differently at 1, 2, 3 to 10 and 11 and up.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{1 day ago} other{{days} days ago}}'**
  String daysPluralOne1DayAgoOther(int days);

  /// No description provided for @mostTrained.
  ///
  /// In en, this message translates to:
  /// **'Most trained'**
  String get mostTrained;

  /// P06 most trained: her top muscle groups with their weighted sets, joined with a middle dot, e.g. 'Glutes 9 · Front of thighs 6'.
  ///
  /// In en, this message translates to:
  /// **'In sets: {list}'**
  String inSetsList(String list);

  /// No description provided for @movesYouCouldAdd.
  ///
  /// In en, this message translates to:
  /// **'Moves you could add'**
  String get movesYouCouldAdd;

  /// No description provided for @beenAWhile.
  ///
  /// In en, this message translates to:
  /// **'Been a while'**
  String get beenAWhile;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @yourUpperAndLowerBodyGotAbout.
  ///
  /// In en, this message translates to:
  /// **'Your upper and lower body got about the same.'**
  String get yourUpperAndLowerBodyGotAbout;

  /// No description provided for @theFrontAndBackOfYourBody.
  ///
  /// In en, this message translates to:
  /// **'The front and back of your body got about the same.'**
  String get theFrontAndBackOfYourBody;

  /// P06 balance: her lower body had more sets than her upper body. 0 means every set went to the lower body, 1 a little more, otherwise about how many times as much. Never a judgement.
  ///
  /// In en, this message translates to:
  /// **'{times, plural, =0{All of these sets went to your lower body.} =1{Your lower body got a little more than your upper body.} =2{Your lower body got about twice as much as your upper body.} other{Your lower body got about {times} times as much as your upper body.}}'**
  String timesPlural0AllOfTheseSets(int times);

  /// P06 balance: her upper body had more sets than her lower body. 0 means every set, 1 a little more, otherwise about how many times as much.
  ///
  /// In en, this message translates to:
  /// **'{times, plural, =0{All of these sets went to your upper body.} =1{Your upper body got a little more than your lower body.} =2{Your upper body got about twice as much as your lower body.} other{Your upper body got about {times} times as much as your lower body.}}'**
  String timesPlural0AllOfTheseSets_izoa9(int times);

  /// P06 balance: the front of her body had more sets than the back. 0 means every set, 1 a little more, otherwise about how many times as much.
  ///
  /// In en, this message translates to:
  /// **'{times, plural, =0{All of these sets went to the front of your body.} =1{The front of your body got a little more than the back.} =2{The front of your body got about twice as much as the back.} other{The front of your body got about {times} times as much as the back.}}'**
  String timesPlural0AllOfTheseSets_2tsm2(int times);

  /// P06 balance: the back of her body had more sets than the front. 0 means every set, 1 a little more, otherwise about how many times as much.
  ///
  /// In en, this message translates to:
  /// **'{times, plural, =0{All of these sets went to the back of your body.} =1{The back of your body got a little more than the front.} =2{The back of your body got about twice as much as the front.} other{The back of your body got about {times} times as much as the front.}}'**
  String timesPlural0AllOfTheseSets_1ysmj(int times);

  /// P06 balance: weighted sets for her upper and lower body in the window. Numbers can be halves.
  ///
  /// In en, this message translates to:
  /// **'In sets: upper body {upper} · lower body {lower}'**
  String inSetsUpperBodyUpperLowerBody(String upper, String lower);

  /// P06 balance: weighted sets for the front and back of her body in the window. Numbers can be halves.
  ///
  /// In en, this message translates to:
  /// **'In sets: front {front} · back {back}'**
  String inSetsFrontFrontBackBack(String front, String back);

  /// No description provided for @ifYouWouldLikeItMoreEven.
  ///
  /// In en, this message translates to:
  /// **'If you would like it more even, an upper-body move or two would do it.'**
  String get ifYouWouldLikeItMoreEven;

  /// No description provided for @ifYouWouldLikeItMoreEven_fk4be.
  ///
  /// In en, this message translates to:
  /// **'If you would like it more even, a lower-body move or two would do it.'**
  String get ifYouWouldLikeItMoreEven_fk4be;

  /// No description provided for @ifYouWouldLikeItMoreEven_1jmf2.
  ///
  /// In en, this message translates to:
  /// **'If you would like it more even, a move for the front of your body would do it.'**
  String get ifYouWouldLikeItMoreEven_1jmf2;

  /// No description provided for @ifYouWouldLikeItMoreEven_v8jiq.
  ///
  /// In en, this message translates to:
  /// **'If you would like it more even, a move for the back of your body would do it.'**
  String get ifYouWouldLikeItMoreEven_v8jiq;

  /// No description provided for @logYourFirstWorkoutAndYourMuscles.
  ///
  /// In en, this message translates to:
  /// **'Log your first workout and your muscles light up here.'**
  String get logYourFirstWorkoutAndYourMuscles;

  /// No description provided for @allYourMuscles.
  ///
  /// In en, this message translates to:
  /// **'All your muscles'**
  String get allYourMuscles;

  /// No description provided for @howWeCountASetCountsIn.
  ///
  /// In en, this message translates to:
  /// **'How we count: a set counts in full for the muscle a move works most, and as half a set for each muscle that helps. Stretches are not counted.'**
  String get howWeCountASetCountsIn;

  /// P06: what a screen reader hears for the 3D figure: every muscle group with its weighted sets.
  ///
  /// In en, this message translates to:
  /// **'Body map. In sets: {list}'**
  String bodyMapInSetsList(String list);

  /// No description provided for @whatYouTrainedOnABodyMap.
  ///
  /// In en, this message translates to:
  /// **'What you trained, on a body map'**
  String get whatYouTrainedOnABodyMap;

  /// P06 window switch: 7 days or 30 days, each a rolling window ending today. A plural message because Arabic says 7 أيام but 30 يوم.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{1 day} other{{days} days}}'**
  String daysPluralOne1DayOtherDays(int days);

  /// P06 tap card: weighted sets for one muscle group over the rolling window (7 or 30 days, ending today; not the calendar week Home counts). {sets} can be a half, like 7.5.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{Sets in 1 day: {sets}} other{Sets in {days} days: {sets}}}'**
  String daysPluralOneSetsIn1Day(int days, String sets);

  /// P06: the heading over the numbers in the list of muscle groups, for the rolling 7 or 30 days.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{Sets in 1 day} other{Sets in {days} days}}'**
  String daysPluralOneSetsIn1Day_1w8hx(int days);

  /// P06: the window she chose holds no sets, though she has logged before.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{No sets logged today.} other{No sets logged in the last {days} days.}}'**
  String daysPluralOneNoSetsLoggedToday(int days);

  /// No description provided for @snapYourMeal.
  ///
  /// In en, this message translates to:
  /// **'Snap your meal'**
  String get snapYourMeal;

  /// No description provided for @checkYourMeal.
  ///
  /// In en, this message translates to:
  /// **'Check your meal'**
  String get checkYourMeal;

  /// No description provided for @beforeYourFirstPhoto.
  ///
  /// In en, this message translates to:
  /// **'Before your first photo'**
  String get beforeYourFirstPhoto;

  /// No description provided for @yourPhotoGoesToOurAiIn.
  ///
  /// In en, this message translates to:
  /// **'Your photo goes to our AI in the EU (Google Cloud, Frankfurt) to estimate what\'s on your plate. We don\'t keep the photo or use it to train anything. You check everything before it\'s logged.'**
  String get yourPhotoGoesToOurAiIn;

  /// No description provided for @upTo5PhotosADayYou.
  ///
  /// In en, this message translates to:
  /// **'Up to 5 photos a day. You can always type your meal instead.'**
  String get upTo5PhotosADayYou;

  /// No description provided for @agree.
  ///
  /// In en, this message translates to:
  /// **'Agree'**
  String get agree;

  /// No description provided for @weCouldntSaveYourAnswerCheckYour.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t save your answer. Check your connection and try again.'**
  String get weCouldntSaveYourAnswerCheckYour;

  /// No description provided for @takeItFromAboveWithTheWhole.
  ///
  /// In en, this message translates to:
  /// **'Take it from above, with the whole plate in the photo.'**
  String get takeItFromAboveWithTheWhole;

  /// No description provided for @useThisPhoto_6wkqn.
  ///
  /// In en, this message translates to:
  /// **'Use this photo?'**
  String get useThisPhoto_6wkqn;

  /// No description provided for @analyseMyMeal.
  ///
  /// In en, this message translates to:
  /// **'Analyse my meal'**
  String get analyseMyMeal;

  /// No description provided for @thisUses1OfYour5Photos.
  ///
  /// In en, this message translates to:
  /// **'This uses 1 of your 5 photos for today.'**
  String get thisUses1OfYour5Photos;

  /// No description provided for @readingYourPlate.
  ///
  /// In en, this message translates to:
  /// **'Reading your plate…'**
  String get readingYourPlate;

  /// No description provided for @thePhotoIsWipedAsSoonAs.
  ///
  /// In en, this message translates to:
  /// **'The photo is wiped as soon as we\'re done.'**
  String get thePhotoIsWipedAsSoonAs;

  /// No description provided for @youveUsedYour5ScansForToday.
  ///
  /// In en, this message translates to:
  /// **'You\'ve used your 5 scans for today. You can still type your meal.'**
  String get youveUsedYour5ScansForToday;

  /// No description provided for @weCouldntMakeOutTheFoodTry.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t make out the food. Try a clearer photo from above, or type it.'**
  String get weCouldntMakeOutTheFoodTry;

  /// No description provided for @scanningIsntAvailableRightNowTypeYour.
  ///
  /// In en, this message translates to:
  /// **'Scanning isn\'t available right now. Type your meal instead.'**
  String get scanningIsntAvailableRightNowTypeYour;

  /// No description provided for @weCouldntReadThatPhotoTakeIt.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t read that photo. Take it again, or type your meal.'**
  String get weCouldntReadThatPhotoTakeIt;

  /// No description provided for @mealPhotosOpenOnceYourAccountIs.
  ///
  /// In en, this message translates to:
  /// **'Meal photos open once your account is checked. You can type your meal now.'**
  String get mealPhotosOpenOnceYourAccountIs;

  /// No description provided for @updateOwnHubFromTheStoreTo.
  ///
  /// In en, this message translates to:
  /// **'Update Own Hub from the store to snap meals. You can type your meal now.'**
  String get updateOwnHubFromTheStoreTo;

  /// No description provided for @signInAgainToSnapMealsYou.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to snap meals. You can type your meal now.'**
  String get signInAgainToSnapMealsYou;

  /// No description provided for @typeItInstead.
  ///
  /// In en, this message translates to:
  /// **'Type it instead'**
  String get typeItInstead;

  /// No description provided for @ownHubNeedsTheCameraToPhotograph.
  ///
  /// In en, this message translates to:
  /// **'Own Hub needs the camera to photograph your plate. Turn it on in Settings, or type your meal.'**
  String get ownHubNeedsTheCameraToPhotograph;

  /// No description provided for @theCameraCouldntStartYouCanType.
  ///
  /// In en, this message translates to:
  /// **'The camera couldn\'t start. You can type your meal instead.'**
  String get theCameraCouldntStartYouCanType;

  /// No description provided for @yourMealPhoto.
  ///
  /// In en, this message translates to:
  /// **'Your meal photo'**
  String get yourMealPhoto;

  /// No description provided for @theseAreEstimatesCheckTheGrams.
  ///
  /// In en, this message translates to:
  /// **'These are estimates. Check the grams.'**
  String get theseAreEstimatesCheckTheGrams;

  /// No description provided for @weightInGrams.
  ///
  /// In en, this message translates to:
  /// **'Weight in grams'**
  String get weightInGrams;

  /// No description provided for @n10GLess.
  ///
  /// In en, this message translates to:
  /// **'10 g less'**
  String get n10GLess;

  /// No description provided for @n10GMore.
  ///
  /// In en, this message translates to:
  /// **'10 g more'**
  String get n10GMore;

  /// E01 and E13: protein in grams, for one item, a meal or the day. Whole number, Western digits.
  ///
  /// In en, this message translates to:
  /// **'Protein {grams} g'**
  String proteinGramsG(String grams);

  /// E01 and E13: carbohydrates in grams. Shown only when known. Whole number, Western digits.
  ///
  /// In en, this message translates to:
  /// **'Carbs {grams} g'**
  String carbsGramsG(String grams);

  /// E01 and E13: fat in grams. Shown only when known.
  ///
  /// In en, this message translates to:
  /// **'Fat {grams} g'**
  String fatGramsG(String grams);

  /// E01 and E13: dietary fibre in grams. Shown only when known.
  ///
  /// In en, this message translates to:
  /// **'Fibre {grams} g'**
  String fibreGramsG(String grams);

  /// E13: a weight in grams, for an item or one part of a dish.
  ///
  /// In en, this message translates to:
  /// **'{grams} g'**
  String gramsG_1usqy(String grams);

  /// No description provided for @editNumbers.
  ///
  /// In en, this message translates to:
  /// **'Edit numbers'**
  String get editNumbers;

  /// No description provided for @editedByYou.
  ///
  /// In en, this message translates to:
  /// **'Edited by you'**
  String get editedByYou;

  /// No description provided for @energyKcal.
  ///
  /// In en, this message translates to:
  /// **'Energy (kcal)'**
  String get energyKcal;

  /// No description provided for @proteinG_xt7ig.
  ///
  /// In en, this message translates to:
  /// **'Protein (g)'**
  String get proteinG_xt7ig;

  /// No description provided for @carbsG_5nlte.
  ///
  /// In en, this message translates to:
  /// **'Carbs (g)'**
  String get carbsG_5nlte;

  /// No description provided for @fatG_1xdz2.
  ///
  /// In en, this message translates to:
  /// **'Fat (g)'**
  String get fatG_1xdz2;

  /// No description provided for @fibreG.
  ///
  /// In en, this message translates to:
  /// **'Fibre (g)'**
  String get fibreG;

  /// No description provided for @weCouldntFindTheNutritionForThis.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find the nutrition for this. Enter it or remove it.'**
  String get weCouldntFindTheNutritionForThis;

  /// No description provided for @estimatedFromAStandardRecipe.
  ///
  /// In en, this message translates to:
  /// **'Estimated from a standard recipe'**
  String get estimatedFromAStandardRecipe;

  /// No description provided for @seeWhatsInIt.
  ///
  /// In en, this message translates to:
  /// **'See what\'s in it'**
  String get seeWhatsInIt;

  /// No description provided for @hideWhatsInIt.
  ///
  /// In en, this message translates to:
  /// **'Hide what\'s in it'**
  String get hideWhatsInIt;

  /// E13: screen reader label on the button that takes one food off the plate before it is logged.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String removeName(String name);

  /// No description provided for @addSomething.
  ///
  /// In en, this message translates to:
  /// **'Add something'**
  String get addSomething;

  /// No description provided for @searchTheFoodList.
  ///
  /// In en, this message translates to:
  /// **'Search the food list'**
  String get searchTheFoodList;

  /// No description provided for @orTypeItIn.
  ///
  /// In en, this message translates to:
  /// **'Or type it in'**
  String get orTypeItIn;

  /// No description provided for @whatIsIt.
  ///
  /// In en, this message translates to:
  /// **'What is it?'**
  String get whatIsIt;

  /// No description provided for @addedByYou.
  ///
  /// In en, this message translates to:
  /// **'Added by you'**
  String get addedByYou;

  /// No description provided for @thisMeal.
  ///
  /// In en, this message translates to:
  /// **'This meal'**
  String get thisMeal;

  /// No description provided for @whichMealIsIt.
  ///
  /// In en, this message translates to:
  /// **'Which meal is it?'**
  String get whichMealIsIt;

  /// No description provided for @logThisMeal.
  ///
  /// In en, this message translates to:
  /// **'Log this meal'**
  String get logThisMeal;

  /// No description provided for @enterTheNumbersForEachItemOr.
  ///
  /// In en, this message translates to:
  /// **'Enter the numbers for each item, or remove it, to log this meal.'**
  String get enterTheNumbersForEachItemOr;

  /// No description provided for @nothingToCheckYetSnapYourMeal.
  ///
  /// In en, this message translates to:
  /// **'Nothing to check yet. Snap your meal first.'**
  String get nothingToCheckYetSnapYourMeal;

  /// No description provided for @nothingOnThisPlateYetAddSomething.
  ///
  /// In en, this message translates to:
  /// **'Nothing on this plate yet. Add something, or cancel.'**
  String get nothingOnThisPlateYetAddSomething;

  /// No description provided for @weFoundOnlyPartOfThisSo.
  ///
  /// In en, this message translates to:
  /// **'We found only part of this, so these numbers may be low. Check them.'**
  String get weFoundOnlyPartOfThisSo;

  /// No description provided for @koshariFulAndMolokhiaInThePortions_1am39.
  ///
  /// In en, this message translates to:
  /// **'Koshari, ful and molokhia in the portions you actually serve, or snap your plate. No calorie shaming.'**
  String get koshariFulAndMolokhiaInThePortions_1am39;

  /// No description provided for @frontView.
  ///
  /// In en, this message translates to:
  /// **'Front view'**
  String get frontView;

  /// No description provided for @backView.
  ///
  /// In en, this message translates to:
  /// **'Back view'**
  String get backView;

  /// No description provided for @tapAMuscleForItsSets.
  ///
  /// In en, this message translates to:
  /// **'Tap a muscle for its sets.'**
  String get tapAMuscleForItsSets;

  /// P06 card on one muscle: whole sets in the rolling window where this muscle helped a move without being its main muscle. These sets never colour the body map. A plural message because Arabic says مجموعة واحدة, مجموعتين, 3 مجموعات and 11 مجموعة.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Also worked: 1 set} other{Also worked: {count} sets}}'**
  String countPluralOneAlsoWorked1Set(int count);

  /// No description provided for @aShortFirstWorkoutYouCanDo.
  ///
  /// In en, this message translates to:
  /// **'A short first workout you can do at home, nothing needed. Want to give it a go?'**
  String get aShortFirstWorkoutYouCanDo;

  /// No description provided for @everyMoveHasAShortVideoSo.
  ///
  /// In en, this message translates to:
  /// **'Every move has a short video, so you know the form before you start.'**
  String get everyMoveHasAShortVideoSo;

  /// No description provided for @snapYourPlateAndWellEstimateThe.
  ///
  /// In en, this message translates to:
  /// **'Snap your plate and we\'ll estimate the protein. You check it before it\'s saved.'**
  String get snapYourPlateAndWellEstimateThe;

  /// No description provided for @rahmasEgyptianRecipesKosharyAndMolokhiaIncluded.
  ///
  /// In en, this message translates to:
  /// **'Rahma\'s Egyptian recipes, koshary and molokhia included, for days you\'re not sure what to cook.'**
  String get rahmasEgyptianRecipesKosharyAndMolokhiaIncluded;

  /// No description provided for @firstTimeAtTheGymACalm.
  ///
  /// In en, this message translates to:
  /// **'First time at the gym? A calm guide, step by step, so you walk in knowing what to do.'**
  String get firstTimeAtTheGymACalm;

  /// No description provided for @eachSessionLightsUpTheMusclesYou.
  ///
  /// In en, this message translates to:
  /// **'Each session lights up the muscles you worked on your own muscle map. Take a look.'**
  String get eachSessionLightsUpTheMusclesYou;

  /// No description provided for @aTrainingWeekThatFitsTheDays.
  ///
  /// In en, this message translates to:
  /// **'A training week that fits the days you have. Change it any time.'**
  String get aTrainingWeekThatFitsTheDays;

  /// No description provided for @gettingStartedTips.
  ///
  /// In en, this message translates to:
  /// **'Getting started tips'**
  String get gettingStartedTips;

  /// No description provided for @aFewTipsInYourFirstWeeks.
  ///
  /// In en, this message translates to:
  /// **'A few tips in your first weeks, only on days you haven\'t opened the app.'**
  String get aFewTipsInYourFirstWeeks;

  /// No description provided for @wantAFewTipsAndYourWorkout.
  ///
  /// In en, this message translates to:
  /// **'Want a few tips and your workout reminders?'**
  String get wantAFewTipsAndYourWorkout;

  /// No description provided for @workoutRemindersOnTheDaysYouPick.
  ///
  /// In en, this message translates to:
  /// **'Workout reminders on the days you pick, once you choose them.'**
  String get workoutRemindersOnTheDaysYouPick;

  /// No description provided for @turnAnyOfThemOffInNotifications.
  ///
  /// In en, this message translates to:
  /// **'Turn any of them off in Notifications, any time.'**
  String get turnAnyOfThemOffInNotifications;

  /// No description provided for @turnOnNotifications.
  ///
  /// In en, this message translates to:
  /// **'Turn on notifications'**
  String get turnOnNotifications;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signOutOnThisPhone.
  ///
  /// In en, this message translates to:
  /// **'Sign out on this phone?'**
  String get signOutOnThisPhone;

  /// No description provided for @yourAccountAndEverythingInItStays.
  ///
  /// In en, this message translates to:
  /// **'Your account and everything in it stays safe. Sign in with your number any time.'**
  String get yourAccountAndEverythingInItStays;

  /// No description provided for @signedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out.'**
  String get signedOut;

  /// No description provided for @staySignedIn.
  ///
  /// In en, this message translates to:
  /// **'Stay signed in'**
  String get staySignedIn;

  /// No description provided for @removeThisSession.
  ///
  /// In en, this message translates to:
  /// **'Remove this session'**
  String get removeThisSession;

  /// No description provided for @removeThisSession_1qh67.
  ///
  /// In en, this message translates to:
  /// **'Remove this session?'**
  String get removeThisSession_1qh67;

  /// No description provided for @itComesOffThisWeeksCountAnd.
  ///
  /// In en, this message translates to:
  /// **'It comes off this week\'s count and your points.'**
  String get itComesOffThisWeeksCountAnd;

  /// No description provided for @removeIt.
  ///
  /// In en, this message translates to:
  /// **'Remove it'**
  String get removeIt;

  /// No description provided for @addToMyWeek.
  ///
  /// In en, this message translates to:
  /// **'Add to my week'**
  String get addToMyWeek;

  /// No description provided for @weekRearranged.
  ///
  /// In en, this message translates to:
  /// **'Week rearranged'**
  String get weekRearranged;

  /// No description provided for @savedChangeItAnyTimeInYour.
  ///
  /// In en, this message translates to:
  /// **'Saved. Change it any time in your profile.'**
  String get savedChangeItAnyTimeInYour;

  /// No description provided for @turnOffBackup.
  ///
  /// In en, this message translates to:
  /// **'Turn off backup?'**
  String get turnOffBackup;

  /// No description provided for @weDeleteTheCopyInYourAccount.
  ///
  /// In en, this message translates to:
  /// **'We delete the copy in your account. Everything stays on this phone.'**
  String get weDeleteTheCopyInYourAccount;

  /// No description provided for @turnItOff.
  ///
  /// In en, this message translates to:
  /// **'Turn it off'**
  String get turnItOff;

  /// No description provided for @keepItOn.
  ///
  /// In en, this message translates to:
  /// **'Keep it on'**
  String get keepItOn;

  /// No description provided for @backupOffTheCopyInYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Backup off. The copy in your account is deleted.'**
  String get backupOffTheCopyInYourAccount;

  /// No description provided for @thanksForAgreeingTheRulesAreIn.
  ///
  /// In en, this message translates to:
  /// **'Thanks for agreeing. The rules are in the Safety Centre any time.'**
  String get thanksForAgreeingTheRulesAreIn;

  /// No description provided for @saveMyChanges.
  ///
  /// In en, this message translates to:
  /// **'Save my changes'**
  String get saveMyChanges;

  /// No description provided for @streakHiddenTurnItBackOnIn.
  ///
  /// In en, this message translates to:
  /// **'Streak hidden. Turn it back on in Notifications, under Reminders and extras.'**
  String get streakHiddenTurnItBackOnIn;

  /// No description provided for @gentleMobilityTodayYourPlanPicksUp.
  ///
  /// In en, this message translates to:
  /// **'Gentle mobility today. Your plan picks up next time.'**
  String get gentleMobilityTodayYourPlanPicksUp;

  /// No description provided for @thisDeletesYourPeriodDatesCheckIns.
  ///
  /// In en, this message translates to:
  /// **'This deletes your period dates, check-ins and cycle settings from this phone. It cannot be undone.'**
  String get thisDeletesYourPeriodDatesCheckIns;

  /// No description provided for @yourCycleDataIsDeletedYouCan.
  ///
  /// In en, this message translates to:
  /// **'Your cycle data is deleted. You can set up My cycle again from your profile.'**
  String get yourCycleDataIsDeletedYouCan;

  /// No description provided for @ifThePainIsSevereOrSudden.
  ///
  /// In en, this message translates to:
  /// **'If the pain is severe or sudden, see a doctor today. In an emergency call 123.'**
  String get ifThePainIsSevereOrSudden;

  /// No description provided for @tapALoggedDayToChangeIt.
  ///
  /// In en, this message translates to:
  /// **'Tap a logged day to change it.'**
  String get tapALoggedDayToChangeIt;

  /// No description provided for @unblocked.
  ///
  /// In en, this message translates to:
  /// **'Unblocked'**
  String get unblocked;

  /// T02 undo bar after a session logged from memory. title is the session's own name.
  ///
  /// In en, this message translates to:
  /// **'Added from memory · {title}'**
  String addedFromMemoryTitle(String title);

  /// T02 after Undo on a recalled session. Numbers in Western digits.
  ///
  /// In en, this message translates to:
  /// **'Taken back. Your week is at {count} of {target}.'**
  String takenBackYourWeekIsAtCount(String count, String target);

  /// R10/R12 undo bar after she removes a logged session. Numbers in Western digits.
  ///
  /// In en, this message translates to:
  /// **'Session removed · your week is at {count} of {target}'**
  String sessionRemovedYourWeekIsAtCount(String count, String target);

  /// Meal undo bar. food is the first food's name, slot is Breakfast, Lunch, Dinner or Snack.
  ///
  /// In en, this message translates to:
  /// **'{food} added to {slot}'**
  String foodAddedToSlot(String food, String slot);

  /// Meal undo bar for a plate of several foods. count in Western digits.
  ///
  /// In en, this message translates to:
  /// **'{food} and {count} more added to {slot}'**
  String foodAndCountMoreAddedToSlot(String food, String count, String slot);

  /// E01/E04 undo bar after she removes a logged food from a slot.
  ///
  /// In en, this message translates to:
  /// **'{food} removed from {slot}'**
  String foodRemovedFromSlot(String food, String slot);

  /// E10 and A02 after saving allergies. allergens is a comma-separated list of allergen names.
  ///
  /// In en, this message translates to:
  /// **'Saved. Dishes with {allergens} are hidden now.'**
  String savedDishesWithAllergensAreHiddenNow(String allergens);

  /// A04 undo bar after unblocking a member.
  ///
  /// In en, this message translates to:
  /// **'Unblocked {name}'**
  String unblockedName(String name);

  /// R05 undo bar after a swap. name is the move she swapped to.
  ///
  /// In en, this message translates to:
  /// **'Swapped to {name} for today'**
  String swappedToNameForToday(String name);

  /// R06 undo bar after skipping a move. name is the move.
  ///
  /// In en, this message translates to:
  /// **'Skipped {name}'**
  String skippedName(String name);

  /// O05 after saving changed setup answers from the profile. Numbers in Western digits.
  ///
  /// In en, this message translates to:
  /// **'Your week is updated · {days} days, {minutes} minutes.'**
  String yourWeekIsUpdatedDaysDaysMinutes(String days, String minutes);

  /// Y04 undo bar. summary is label: value pairs joined by a middle dot.
  ///
  /// In en, this message translates to:
  /// **'Check-in saved · {summary}'**
  String checkInSavedSummary(String summary);

  /// Y03 line under How are you feeling. summary is label: value pairs.
  ///
  /// In en, this message translates to:
  /// **'Today: {summary}'**
  String todaySummary(String summary);

  /// Y09 after saving a period. Dates as yyyy-MM-dd.
  ///
  /// In en, this message translates to:
  /// **'Period saved · {start} to {end}'**
  String periodSavedStartToEnd(String start, String end);

  /// Y09 after saving a period with no end date yet.
  ///
  /// In en, this message translates to:
  /// **'Period saved · from {start}'**
  String periodSavedFromStart(String start);

  /// Y09 undo bar after deleting a period.
  ///
  /// In en, this message translates to:
  /// **'Period removed · {start} to {end}'**
  String periodRemovedStartToEnd(String start, String end);

  /// Y09 undo bar after deleting a period with no end date.
  ///
  /// In en, this message translates to:
  /// **'Period removed · from {start}'**
  String periodRemovedFromStart(String start);

  /// No description provided for @nothingWasDeletedTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Nothing was deleted. Try again.'**
  String get nothingWasDeletedTryAgain;

  /// Y11, the severe-pain card. number is Egypt's ambulance line, 123, in Western digits.
  ///
  /// In en, this message translates to:
  /// **'If the pain is severe or sudden, see a doctor today. In an emergency call {number}.'**
  String ifThePainIsSevereOrSudden_rd6j0(String number);

  /// Adds one more name to a list of names, e.g. allergens. The comma is the language's own.
  ///
  /// In en, this message translates to:
  /// **'{list}, {item}'**
  String listItem(String list, String item);

  /// No description provided for @donkeyKick.
  ///
  /// In en, this message translates to:
  /// **'Donkey kick'**
  String get donkeyKick;

  /// No description provided for @straightLegGluteKickback.
  ///
  /// In en, this message translates to:
  /// **'Straight-leg glute kickback'**
  String get straightLegGluteKickback;

  /// No description provided for @forearmPlank.
  ///
  /// In en, this message translates to:
  /// **'Forearm plank'**
  String get forearmPlank;

  /// No description provided for @heelTouches.
  ///
  /// In en, this message translates to:
  /// **'Heel touches'**
  String get heelTouches;

  /// No description provided for @explore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// No description provided for @searchWorkoutsAndMoves.
  ///
  /// In en, this message translates to:
  /// **'Search workouts and moves'**
  String get searchWorkoutsAndMoves;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// T01 greeting before noon, with her first name.
  ///
  /// In en, this message translates to:
  /// **'Good morning, {name}'**
  String goodMorningName(String name);

  /// T01 greeting from noon to five, with her first name.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon, {name}'**
  String goodAfternoonName(String name);

  /// T01 greeting from five in the afternoon, with her first name.
  ///
  /// In en, this message translates to:
  /// **'Good evening, {name}'**
  String goodEveningName(String name);

  /// No description provided for @carbs.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get carbs;

  /// No description provided for @fat.
  ///
  /// In en, this message translates to:
  /// **'Fat'**
  String get fat;

  /// No description provided for @logAMeal.
  ///
  /// In en, this message translates to:
  /// **'Log a meal'**
  String get logAMeal;

  /// No description provided for @searchOrTypeWhatYouAte.
  ///
  /// In en, this message translates to:
  /// **'Search or type what you ate'**
  String get searchOrTypeWhatYouAte;

  /// No description provided for @quickAdd.
  ///
  /// In en, this message translates to:
  /// **'Quick add'**
  String get quickAdd;

  /// No description provided for @youveHad.
  ///
  /// In en, this message translates to:
  /// **'You\'ve had'**
  String get youveHad;

  /// No description provided for @popularDishes.
  ///
  /// In en, this message translates to:
  /// **'Popular dishes'**
  String get popularDishes;

  /// A small note under a logged food that is known to contain something she told us she avoids. Logging is never blocked.
  ///
  /// In en, this message translates to:
  /// **'Contains {allergens}'**
  String containsAllergens(String allergens);

  /// No description provided for @fewerServings.
  ///
  /// In en, this message translates to:
  /// **'Fewer servings'**
  String get fewerServings;

  /// No description provided for @moreServings.
  ///
  /// In en, this message translates to:
  /// **'More servings'**
  String get moreServings;

  /// Screen reader label of the plus button on a food row that logs it.
  ///
  /// In en, this message translates to:
  /// **'Add {name}'**
  String addName(String name);

  /// No description provided for @capturePhoto.
  ///
  /// In en, this message translates to:
  /// **'Capture photo'**
  String get capturePhoto;

  /// No description provided for @fitTheCardInsideTheFrameThen.
  ///
  /// In en, this message translates to:
  /// **'Fit the card inside the frame, then tap Capture photo. Nothing is uploaded until you send it.'**
  String get fitTheCardInsideTheFrameThen;

  /// No description provided for @howWouldYouLikeToBeChecked.
  ///
  /// In en, this message translates to:
  /// **'How would you like to be checked?'**
  String get howWouldYouLikeToBeChecked;

  /// No description provided for @idCardAndASelfie.
  ///
  /// In en, this message translates to:
  /// **'ID card and a selfie'**
  String get idCardAndASelfie;

  /// No description provided for @about2Minutes.
  ///
  /// In en, this message translates to:
  /// **'About 2 minutes'**
  String get about2Minutes;

  /// No description provided for @talkToAWomanReviewer.
  ///
  /// In en, this message translates to:
  /// **'Talk to a woman reviewer'**
  String get talkToAWomanReviewer;

  /// No description provided for @aShortCall.
  ///
  /// In en, this message translates to:
  /// **'A short call'**
  String get aShortCall;

  /// No description provided for @iKnowOneOfTheReviewers.
  ///
  /// In en, this message translates to:
  /// **'I know one of the reviewers'**
  String get iKnowOneOfTheReviewers;

  /// No description provided for @pickHerNameIfSheKnowsYou.
  ///
  /// In en, this message translates to:
  /// **'Pick her name. If she knows you, you may be approved right away.'**
  String get pickHerNameIfSheKnowsYou;

  /// No description provided for @pickATimeForYourCall.
  ///
  /// In en, this message translates to:
  /// **'Pick a time for your call'**
  String get pickATimeForYourCall;

  /// No description provided for @changeTheTime.
  ///
  /// In en, this message translates to:
  /// **'Change the time'**
  String get changeTheTime;

  /// No description provided for @keepExploring.
  ///
  /// In en, this message translates to:
  /// **'Keep exploring'**
  String get keepExploring;

  /// No description provided for @weCouldNotLoadTheFreeTimes.
  ///
  /// In en, this message translates to:
  /// **'We could not load the free times. You do not need to do anything: a woman from Own Hub will still contact you.'**
  String get weCouldNotLoadTheFreeTimes;

  /// No description provided for @thereAreNoFreeTimesInThe.
  ///
  /// In en, this message translates to:
  /// **'There are no free times in the next 7 days. A woman from Own Hub will still contact you.'**
  String get thereAreNoFreeTimesInThe;

  /// No description provided for @weCouldNotBookThatTimePick.
  ///
  /// In en, this message translates to:
  /// **'We could not book that time. Pick another one.'**
  String get weCouldNotBookThatTimePick;

  /// No description provided for @logFood.
  ///
  /// In en, this message translates to:
  /// **'Log food'**
  String get logFood;

  /// No description provided for @frequent.
  ///
  /// In en, this message translates to:
  /// **'Frequent'**
  String get frequent;

  /// No description provided for @favourites.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get favourites;

  /// No description provided for @quickCustom.
  ///
  /// In en, this message translates to:
  /// **'Quick custom'**
  String get quickCustom;

  /// No description provided for @typeANameAndTheNumbersOff.
  ///
  /// In en, this message translates to:
  /// **'Type a name and the numbers off the packet'**
  String get typeANameAndTheNumbersOff;

  /// No description provided for @foodName.
  ///
  /// In en, this message translates to:
  /// **'Food name'**
  String get foodName;

  /// No description provided for @fibre.
  ///
  /// In en, this message translates to:
  /// **'Fibre'**
  String get fibre;

  /// No description provided for @saveAndLog.
  ///
  /// In en, this message translates to:
  /// **'Save and log'**
  String get saveAndLog;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @g.
  ///
  /// In en, this message translates to:
  /// **'g'**
  String get g;

  /// No description provided for @oz.
  ///
  /// In en, this message translates to:
  /// **'oz'**
  String get oz;

  /// No description provided for @ml.
  ///
  /// In en, this message translates to:
  /// **'ml'**
  String get ml;

  /// No description provided for @cup.
  ///
  /// In en, this message translates to:
  /// **'cup'**
  String get cup;

  /// No description provided for @piece.
  ///
  /// In en, this message translates to:
  /// **'piece'**
  String get piece;

  /// No description provided for @serving_1d0fq.
  ///
  /// In en, this message translates to:
  /// **'Serving'**
  String get serving_1d0fq;

  /// A portion's weight in grams when the unit is an estimate.
  ///
  /// In en, this message translates to:
  /// **'About {grams} g'**
  String aboutGramsG(String grams);

  /// No description provided for @addToFavourites.
  ///
  /// In en, this message translates to:
  /// **'Add to favourites'**
  String get addToFavourites;

  /// No description provided for @removeFromFavourites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favourites'**
  String get removeFromFavourites;

  /// No description provided for @foodsYouLogShowUpHere.
  ///
  /// In en, this message translates to:
  /// **'Foods you log show up here.'**
  String get foodsYouLogShowUpHere;

  /// No description provided for @tapTheStarOnAFoodTo.
  ///
  /// In en, this message translates to:
  /// **'Tap the star on a food to keep it here.'**
  String get tapTheStarOnAFoodTo;

  /// No description provided for @personalise.
  ///
  /// In en, this message translates to:
  /// **'Personalise'**
  String get personalise;

  /// No description provided for @targetsUseAStandardEstimateAddYour.
  ///
  /// In en, this message translates to:
  /// **'Targets use a standard estimate. Add your weight, height and age to make them yours.'**
  String get targetsUseAStandardEstimateAddYour;

  /// The day's kcal target, under the kcal eaten in the ring.
  ///
  /// In en, this message translates to:
  /// **'of {target} kcal'**
  String ofTargetKcal(String target);

  /// No description provided for @signInOrJoin.
  ///
  /// In en, this message translates to:
  /// **'Sign in or join'**
  String get signInOrJoin;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @aNoteFromRahma.
  ///
  /// In en, this message translates to:
  /// **'A note from Rahma'**
  String get aNoteFromRahma;

  /// No description provided for @rahmaMohsen.
  ///
  /// In en, this message translates to:
  /// **'Rahma Mohsen'**
  String get rahmaMohsen;

  /// No description provided for @heySoHappyYoureHereThankYou.
  ///
  /// In en, this message translates to:
  /// **'Hey! So happy you\'re here 💕 Thank you for downloading the app! I built this so you can train on your own terms and fuel your body without the stress. You\'ve already seen a preview of your custom workouts and nutrition targets. Create your quick account now so we can save your plan, track your meals in one tap, and start crushing your goals together!'**
  String get heySoHappyYoureHereThankYou;

  /// No description provided for @continueToSignUp.
  ///
  /// In en, this message translates to:
  /// **'Continue to sign up'**
  String get continueToSignUp;

  /// No description provided for @playTheVideo.
  ///
  /// In en, this message translates to:
  /// **'Play the video'**
  String get playTheVideo;

  /// No description provided for @pauseTheVideo.
  ///
  /// In en, this message translates to:
  /// **'Pause the video'**
  String get pauseTheVideo;

  /// No description provided for @turnSoundOn.
  ///
  /// In en, this message translates to:
  /// **'Turn sound on'**
  String get turnSoundOn;

  /// No description provided for @turnSoundOff.
  ///
  /// In en, this message translates to:
  /// **'Turn sound off'**
  String get turnSoundOff;

  /// No description provided for @rahmasVideoWillBeHereSoon.
  ///
  /// In en, this message translates to:
  /// **'Rahma\'s video will be here soon.'**
  String get rahmasVideoWillBeHereSoon;

  /// No description provided for @newHereCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'New here? Create account'**
  String get newHereCreateAccount;

  /// No description provided for @alreadyHaveAnAccountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get alreadyHaveAnAccountSignIn;

  /// No description provided for @signInWithYourNumber.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your number'**
  String get signInWithYourNumber;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @suggestedFromYourWeek.
  ///
  /// In en, this message translates to:
  /// **'Suggested from your week'**
  String get suggestedFromYourWeek;

  /// No description provided for @yourTrainingDays.
  ///
  /// In en, this message translates to:
  /// **'Your training days'**
  String get yourTrainingDays;

  /// No description provided for @customSchedule.
  ///
  /// In en, this message translates to:
  /// **'Custom schedule'**
  String get customSchedule;

  /// No description provided for @tapADayToSwitchItBetween.
  ///
  /// In en, this message translates to:
  /// **'Tap a day to switch it between training and recovery.'**
  String get tapADayToSwitchItBetween;

  /// No description provided for @recovery.
  ///
  /// In en, this message translates to:
  /// **'Recovery'**
  String get recovery;

  /// O03 custom schedule summary: how many weekdays are training and how many are recovery.
  ///
  /// In en, this message translates to:
  /// **'{training} training · {recovery} recovery'**
  String trainingTrainingRecoveryRecovery(String training, String recovery);

  /// No description provided for @fewerMinutes.
  ///
  /// In en, this message translates to:
  /// **'Fewer minutes'**
  String get fewerMinutes;

  /// No description provided for @moreMinutes.
  ///
  /// In en, this message translates to:
  /// **'More minutes'**
  String get moreMinutes;

  /// No description provided for @pickAnyLengthFrom10To180.
  ///
  /// In en, this message translates to:
  /// **'Pick any length from 10 to 180 minutes.'**
  String get pickAnyLengthFrom10To180;

  /// No description provided for @aboutYou.
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get aboutYou;

  /// No description provided for @optionalItStaysOnThisPhoneAnd.
  ///
  /// In en, this message translates to:
  /// **'Optional. It stays on this phone and is only used to work out your calorie and protein targets.'**
  String get optionalItStaysOnThisPhoneAnd;

  /// No description provided for @weightKg_4v662.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get weightKg_4v662;

  /// No description provided for @heightCm.
  ///
  /// In en, this message translates to:
  /// **'Height (cm)'**
  String get heightCm;

  /// No description provided for @ageYears.
  ///
  /// In en, this message translates to:
  /// **'Age (years)'**
  String get ageYears;

  /// No description provided for @between30And250Kg.
  ///
  /// In en, this message translates to:
  /// **'Between 30 and 250 kg'**
  String get between30And250Kg;

  /// No description provided for @between120And230Cm.
  ///
  /// In en, this message translates to:
  /// **'Between 120 and 230 cm'**
  String get between120And230Cm;

  /// No description provided for @between14And90Years.
  ///
  /// In en, this message translates to:
  /// **'Between 14 and 90 years'**
  String get between14And90Years;

  /// No description provided for @skipThis.
  ///
  /// In en, this message translates to:
  /// **'Skip this'**
  String get skipThis;

  /// How long the ID route takes.
  ///
  /// In en, this message translates to:
  /// **'About {minutes} minutes'**
  String aboutMinutesMinutes(String minutes);

  /// No review call slots in the window.
  ///
  /// In en, this message translates to:
  /// **'There are no free times in the next {days} days. A woman from Own Hub will still contact you.'**
  String thereAreNoFreeTimesInThe_bzb9s(String days);

  /// Custom session length range.
  ///
  /// In en, this message translates to:
  /// **'Pick any length from {min} to {max} minutes.'**
  String pickAnyLengthFromMinToMax(String min, String max);

  /// Weight range error.
  ///
  /// In en, this message translates to:
  /// **'Between {min} and {max} kg'**
  String betweenMinAndMaxKg(String min, String max);

  /// Height range error.
  ///
  /// In en, this message translates to:
  /// **'Between {min} and {max} cm'**
  String betweenMinAndMaxCm(String min, String max);

  /// Age range error.
  ///
  /// In en, this message translates to:
  /// **'Between {min} and {max} years'**
  String betweenMinAndMaxYears(String min, String max);

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// No description provided for @yourCoachRepliedToYourReview.
  ///
  /// In en, this message translates to:
  /// **'Your coach replied to your review'**
  String get yourCoachRepliedToYourReview;

  /// No description provided for @yourGroupReachedANewMilestone.
  ///
  /// In en, this message translates to:
  /// **'Your group reached a new milestone'**
  String get yourGroupReachedANewMilestone;

  /// No description provided for @yourBestGotAFewLikes.
  ///
  /// In en, this message translates to:
  /// **'Your best got a few likes'**
  String get yourBestGotAFewLikes;

  /// No description provided for @aGentleNudgeToLogYourMeal.
  ///
  /// In en, this message translates to:
  /// **'A gentle nudge to log your meal'**
  String get aGentleNudgeToLogYourMeal;

  /// No description provided for @yourWeekIsWrappedUpSeeHow.
  ///
  /// In en, this message translates to:
  /// **'Your week is wrapped up. See how it went'**
  String get yourWeekIsWrappedUpSeeHow;

  /// No description provided for @yourLevelHasChanged.
  ///
  /// In en, this message translates to:
  /// **'Your level has changed'**
  String get yourLevelHasChanged;

  /// No description provided for @thereIsAnUpdateOnYourVerification.
  ///
  /// In en, this message translates to:
  /// **'There is an update on your verification'**
  String get thereIsAnUpdateOnYourVerification;

  /// No description provided for @egyptianDishes.
  ///
  /// In en, this message translates to:
  /// **'Egyptian dishes'**
  String get egyptianDishes;

  /// No description provided for @proteins.
  ///
  /// In en, this message translates to:
  /// **'Proteins'**
  String get proteins;

  /// No description provided for @dairyAndCheese.
  ///
  /// In en, this message translates to:
  /// **'Dairy and cheese'**
  String get dairyAndCheese;

  /// No description provided for @grainsAndBreads.
  ///
  /// In en, this message translates to:
  /// **'Grains and breads'**
  String get grainsAndBreads;

  /// No description provided for @vegetablesAndSalads.
  ///
  /// In en, this message translates to:
  /// **'Vegetables and salads'**
  String get vegetablesAndSalads;

  /// No description provided for @fruitsAndNuts.
  ///
  /// In en, this message translates to:
  /// **'Fruits and nuts'**
  String get fruitsAndNuts;

  /// No description provided for @snacksAndDrinks.
  ///
  /// In en, this message translates to:
  /// **'Snacks and drinks'**
  String get snacksAndDrinks;

  /// No description provided for @foodCategories.
  ///
  /// In en, this message translates to:
  /// **'Food categories'**
  String get foodCategories;

  /// No description provided for @fishIsDoneWhenItTurnsOpaque.
  ///
  /// In en, this message translates to:
  /// **'Fish is done when it turns opaque all through and flakes easily with a fork.'**
  String get fishIsDoneWhenItTurnsOpaque;

  /// No description provided for @fromTheOwnHubKitchen.
  ///
  /// In en, this message translates to:
  /// **'From the Own Hub kitchen'**
  String get fromTheOwnHubKitchen;

  /// No description provided for @theIngredientsAreGenericReadTheLabel.
  ///
  /// In en, this message translates to:
  /// **'The ingredients are generic. Read the label on each product yourself before use.'**
  String get theIngredientsAreGenericReadTheLabel;

  /// No description provided for @theBookGivesThisOneAsA.
  ///
  /// In en, this message translates to:
  /// **'The book gives this one as a list of what goes in, with no method.'**
  String get theBookGivesThisOneAsA;

  /// No description provided for @reserveMySeat.
  ///
  /// In en, this message translates to:
  /// **'Reserve my seat'**
  String get reserveMySeat;

  /// No description provided for @cancelMyReservation.
  ///
  /// In en, this message translates to:
  /// **'Cancel my reservation'**
  String get cancelMyReservation;

  /// No description provided for @yourSeatIsReserved.
  ///
  /// In en, this message translates to:
  /// **'Your seat is reserved'**
  String get yourSeatIsReserved;

  /// No description provided for @openInMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Maps'**
  String get openInMaps;

  /// No description provided for @full.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get full;

  /// How many seats are left on an event with a limit. Western digits.
  ///
  /// In en, this message translates to:
  /// **'{remaining} of {capacity} seats left'**
  String remainingOfCapacitySeatsLeft(String remaining, String capacity);

  /// No description provided for @thisEventIsFull.
  ///
  /// In en, this message translates to:
  /// **'This event is full.'**
  String get thisEventIsFull;

  /// No description provided for @reservationsForThisEventAreClosed.
  ///
  /// In en, this message translates to:
  /// **'Reservations for this event are closed.'**
  String get reservationsForThisEventAreClosed;

  /// No description provided for @onlyVerifiedMembersCanReserveASeat.
  ///
  /// In en, this message translates to:
  /// **'Only verified members can reserve a seat.'**
  String get onlyVerifiedMembersCanReserveASeat;

  /// No description provided for @updateOwnHubToReserveASeat.
  ///
  /// In en, this message translates to:
  /// **'Update Own Hub to reserve a seat.'**
  String get updateOwnHubToReserveASeat;

  /// No description provided for @weCouldNotUpdateYourReservationCheck.
  ///
  /// In en, this message translates to:
  /// **'We could not update your reservation. Check your connection and try again.'**
  String get weCouldNotUpdateYourReservationCheck;

  /// No description provided for @streetAddressOptional.
  ///
  /// In en, this message translates to:
  /// **'Street address (optional)'**
  String get streetAddressOptional;

  /// No description provided for @googleMapsLinkOptional.
  ///
  /// In en, this message translates to:
  /// **'Google Maps link (optional)'**
  String get googleMapsLinkOptional;

  /// No description provided for @shareThePlaceFromGoogleMapsAnd.
  ///
  /// In en, this message translates to:
  /// **'Share the place from Google Maps and paste the link here.'**
  String get shareThePlaceFromGoogleMapsAnd;

  /// No description provided for @theVenuesNameLikeZamalekLadiesGym.
  ///
  /// In en, this message translates to:
  /// **'The venue\'s name, like Zamalek ladies gym.'**
  String get theVenuesNameLikeZamalekLadiesGym;

  /// No description provided for @seatsMembersCanReserveOptional.
  ///
  /// In en, this message translates to:
  /// **'Seats members can reserve (optional)'**
  String get seatsMembersCanReserveOptional;

  /// No description provided for @reservingWorksOnlyWhenThisIsSet.
  ///
  /// In en, this message translates to:
  /// **'Reserving works only when this is set.'**
  String get reservingWorksOnlyWhenThisIsSet;

  /// No description provided for @eventPictures.
  ///
  /// In en, this message translates to:
  /// **'Event pictures'**
  String get eventPictures;

  /// No description provided for @eventVideos.
  ///
  /// In en, this message translates to:
  /// **'Event videos'**
  String get eventVideos;

  /// No description provided for @noVideosInTheMediaLibraryYet.
  ///
  /// In en, this message translates to:
  /// **'No videos in the media library yet.'**
  String get noVideosInTheMediaLibraryYet;

  /// No description provided for @useALinkFromGoogleMaps.
  ///
  /// In en, this message translates to:
  /// **'Use a link from Google Maps.'**
  String get useALinkFromGoogleMaps;

  /// No description provided for @checkThisFileName.
  ///
  /// In en, this message translates to:
  /// **'Check this file name.'**
  String get checkThisFileName;

  /// No description provided for @thatPhotoIsTooDarkTryAgain.
  ///
  /// In en, this message translates to:
  /// **'That photo is too dark. Try again with more light.'**
  String get thatPhotoIsTooDarkTryAgain;

  /// No description provided for @helpOtherWomenLogThisDish.
  ///
  /// In en, this message translates to:
  /// **'Help other women log this dish'**
  String get helpOtherWomenLogThisDish;

  /// No description provided for @recommendedForYou.
  ///
  /// In en, this message translates to:
  /// **'Recommended for you'**
  String get recommendedForYou;

  /// No description provided for @buildMyOwnWorkout.
  ///
  /// In en, this message translates to:
  /// **'Build my own workout'**
  String get buildMyOwnWorkout;

  /// No description provided for @seeAllPrograms.
  ///
  /// In en, this message translates to:
  /// **'See all programs'**
  String get seeAllPrograms;

  /// No description provided for @videoAvailable.
  ///
  /// In en, this message translates to:
  /// **'Video available'**
  String get videoAvailable;

  /// No description provided for @formCues.
  ///
  /// In en, this message translates to:
  /// **'Form cues'**
  String get formCues;

  /// No description provided for @chooseYourProgram.
  ///
  /// In en, this message translates to:
  /// **'Choose your program'**
  String get chooseYourProgram;

  /// No description provided for @atALadiesOnlyGym.
  ///
  /// In en, this message translates to:
  /// **'At a ladies-only gym'**
  String get atALadiesOnlyGym;

  /// No description provided for @atHomeAndTheGym.
  ///
  /// In en, this message translates to:
  /// **'At home and the gym'**
  String get atHomeAndTheGym;

  /// A chip on a programme card: how long each session lasts.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min a session'**
  String minutesMinASession(String minutes);

  /// No description provided for @saveAsMyWorkout.
  ///
  /// In en, this message translates to:
  /// **'Save as my workout'**
  String get saveAsMyWorkout;

  /// No description provided for @myWorkouts.
  ///
  /// In en, this message translates to:
  /// **'My workouts'**
  String get myWorkouts;

  /// No description provided for @myWorkout.
  ///
  /// In en, this message translates to:
  /// **'My workout'**
  String get myWorkout;

  /// The button that adds the moves she ticked to her workout.
  ///
  /// In en, this message translates to:
  /// **'Add selected ({n})'**
  String addSelectedN(String n);

  /// The undo bar after she takes a move out of today's workout.
  ///
  /// In en, this message translates to:
  /// **'Removed {name}'**
  String removedName(String name);

  /// The undo bar after she deletes one of her saved workouts.
  ///
  /// In en, this message translates to:
  /// **'Deleted {name}'**
  String deletedName(String name);

  /// No description provided for @moveEarlier.
  ///
  /// In en, this message translates to:
  /// **'Move earlier'**
  String get moveEarlier;

  /// No description provided for @moveLater.
  ///
  /// In en, this message translates to:
  /// **'Move later'**
  String get moveLater;

  /// No description provided for @workoutName.
  ///
  /// In en, this message translates to:
  /// **'Workout name'**
  String get workoutName;

  /// No description provided for @startNow.
  ///
  /// In en, this message translates to:
  /// **'Start now'**
  String get startNow;

  /// No description provided for @deleteThisWorkout.
  ///
  /// In en, this message translates to:
  /// **'Delete this workout'**
  String get deleteThisWorkout;

  /// No description provided for @addAtLeastOneMove.
  ///
  /// In en, this message translates to:
  /// **'Add at least one move'**
  String get addAtLeastOneMove;

  /// No description provided for @savedToYourWorkouts.
  ///
  /// In en, this message translates to:
  /// **'Saved to your workouts'**
  String get savedToYourWorkouts;

  /// No description provided for @pickYourMoves.
  ///
  /// In en, this message translates to:
  /// **'Pick your moves'**
  String get pickYourMoves;

  /// No description provided for @buildYourWorkout.
  ///
  /// In en, this message translates to:
  /// **'Build your workout'**
  String get buildYourWorkout;

  /// No description provided for @editYourWorkout.
  ///
  /// In en, this message translates to:
  /// **'Edit your workout'**
  String get editYourWorkout;

  /// No description provided for @changesHereAreForTodayOnly.
  ///
  /// In en, this message translates to:
  /// **'Changes here are for today only'**
  String get changesHereAreForTodayOnly;

  /// No description provided for @nameYourWorkout.
  ///
  /// In en, this message translates to:
  /// **'Name your workout'**
  String get nameYourWorkout;

  /// No description provided for @decrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get decrease;

  /// No description provided for @increase.
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get increase;

  /// No description provided for @addingUpYourMeal.
  ///
  /// In en, this message translates to:
  /// **'Adding up your meal'**
  String get addingUpYourMeal;

  /// No description provided for @doesThisLookRight.
  ///
  /// In en, this message translates to:
  /// **'Does this look right?'**
  String get doesThisLookRight;

  /// No description provided for @yes_6deo.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes_6deo;

  /// No description provided for @log.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get log;

  /// No description provided for @snacks.
  ///
  /// In en, this message translates to:
  /// **'Snacks'**
  String get snacks;

  /// No description provided for @nothingYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet'**
  String get nothingYet;

  /// No description provided for @yourBreakfastPicks.
  ///
  /// In en, this message translates to:
  /// **'Your breakfast picks'**
  String get yourBreakfastPicks;

  /// No description provided for @yourLunchPicks.
  ///
  /// In en, this message translates to:
  /// **'Your lunch picks'**
  String get yourLunchPicks;

  /// No description provided for @yourDinnerPicks.
  ///
  /// In en, this message translates to:
  /// **'Your dinner picks'**
  String get yourDinnerPicks;

  /// No description provided for @yourSnackPicks.
  ///
  /// In en, this message translates to:
  /// **'Your snack picks'**
  String get yourSnackPicks;

  /// No description provided for @impactOnToday.
  ///
  /// In en, this message translates to:
  /// **'Impact on today'**
  String get impactOnToday;

  /// Screen-reader name of the Log pill on a meal row in the Eat diary.
  ///
  /// In en, this message translates to:
  /// **'Log {meal}'**
  String logMeal(String meal);

  /// A share of a daily target, as a whole-number percentage.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String percent(String percent);

  /// Screen-reader reading of an Impact on today ring, after the nutrient name.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of your target today'**
  String percentOfYourTargetToday(String percent);

  /// No description provided for @bodyweight.
  ///
  /// In en, this message translates to:
  /// **'Bodyweight'**
  String get bodyweight;

  /// Tooltip of a minus button on a stepper; label names what it changes, such as Sets.
  ///
  /// In en, this message translates to:
  /// **'Decrease {label}'**
  String decreaseLabel(String label);

  /// Tooltip of a plus button on a stepper; label names what it changes, such as Sets.
  ///
  /// In en, this message translates to:
  /// **'Increase {label}'**
  String increaseLabel(String label);

  /// No description provided for @noneOfTheseMovesSuitYouRight.
  ///
  /// In en, this message translates to:
  /// **'None of these moves suit you right now, so this workout was not started.'**
  String get noneOfTheseMovesSuitYouRight;

  /// No description provided for @weLeftOutMovesThatDoNot.
  ///
  /// In en, this message translates to:
  /// **'We left out moves that do not suit you right now.'**
  String get weLeftOutMovesThatDoNot;

  /// No description provided for @leaveWithoutSaving.
  ///
  /// In en, this message translates to:
  /// **'Leave without saving?'**
  String get leaveWithoutSaving;

  /// No description provided for @yourChangesToThisWorkoutWillBe.
  ///
  /// In en, this message translates to:
  /// **'Your changes to this workout will be lost.'**
  String get yourChangesToThisWorkoutWillBe;

  /// No description provided for @keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// No description provided for @discardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get discardChanges;

  /// Z18 capacity error when the owner sets a limit under the seats already reserved.
  ///
  /// In en, this message translates to:
  /// **'{n} seats are already reserved, so the limit cannot be lower than that.'**
  String nSeatsAreAlreadyReservedSoThe(String n);

  /// No description provided for @thatPhotoLooksBlankCheckTheLens.
  ///
  /// In en, this message translates to:
  /// **'That photo looks blank. Check the lens and try again.'**
  String get thatPhotoLooksBlankCheckTheLens;

  /// No description provided for @friendlyNudges.
  ///
  /// In en, this message translates to:
  /// **'Friendly nudges'**
  String get friendlyNudges;

  /// No description provided for @aShortFriendlyNoteAtMostOnce.
  ///
  /// In en, this message translates to:
  /// **'A short, friendly note at most once a day, never at night.'**
  String get aShortFriendlyNoteAtMostOnce;

  /// No description provided for @atMostOneADayAndNever.
  ///
  /// In en, this message translates to:
  /// **'At most one a day, and never at night.'**
  String get atMostOneADayAndNever;

  /// No description provided for @nothingMatchesYetTryTakingOneFilter.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches yet. Try taking one filter off.'**
  String get nothingMatchesYetTryTakingOneFilter;

  /// No description provided for @takeADeepBreath.
  ///
  /// In en, this message translates to:
  /// **'Take a deep breath'**
  String get takeADeepBreath;

  /// No description provided for @breatheIn.
  ///
  /// In en, this message translates to:
  /// **'Breathe in'**
  String get breatheIn;

  /// No description provided for @breatheOut.
  ///
  /// In en, this message translates to:
  /// **'Breathe out'**
  String get breatheOut;

  /// No description provided for @drawATickToPromiseYourself.
  ///
  /// In en, this message translates to:
  /// **'Draw a tick to promise yourself'**
  String get drawATickToPromiseYourself;

  /// No description provided for @iPromise.
  ///
  /// In en, this message translates to:
  /// **'I promise'**
  String get iPromise;

  /// No description provided for @drawItInTheBoxDownThen.
  ///
  /// In en, this message translates to:
  /// **'Draw it in the box: down, then up and to the right'**
  String get drawItInTheBoxDownThen;

  /// No description provided for @drawingBoxForYourTick.
  ///
  /// In en, this message translates to:
  /// **'Drawing box for your tick'**
  String get drawingBoxForYourTick;

  /// No description provided for @freshWeekAheadPickADayOr.
  ///
  /// In en, this message translates to:
  /// **'Fresh week ahead. Pick a day or two that suit you, only if you feel like it.'**
  String get freshWeekAheadPickADayOr;

  /// No description provided for @aNewWeekIsComingHaveA.
  ///
  /// In en, this message translates to:
  /// **'A new week is coming. Have a calm look at what could fit your days.'**
  String get aNewWeekIsComingHaveA;

  /// No description provided for @aNewWeekStartsTomorrowPlanIt.
  ///
  /// In en, this message translates to:
  /// **'A new week starts tomorrow. Plan it at your pace, or leave it for later.'**
  String get aNewWeekStartsTomorrowPlanIt;

  /// No description provided for @yourNextWeekIsWideOpenPick.
  ///
  /// In en, this message translates to:
  /// **'Your next week is wide open. Pick a day that suits you, no rush.'**
  String get yourNextWeekIsWideOpenPick;

  /// No description provided for @tryOnceMoreOrTapIPromise.
  ///
  /// In en, this message translates to:
  /// **'Try once more, or tap I promise'**
  String get tryOnceMoreOrTapIPromise;

  /// The apply button of the Explore filters. A plural message because Arabic says نتيجة واحدة, نتيجتين, 3 نتايج and 11 نتيجة. The figure is how many workouts and moves match what she has picked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Show 1 result} other{Show {count} results}}'**
  String countPluralOneShow1ResultOther(int count);

  /// The apply button of the move filters. A plural message because Arabic says حركة واحدة, حركتين, 3 حركات and 11 حركة. The figure is how many moves match what she has picked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Show 1 move} other{Show {count} moves}}'**
  String countPluralOneShow1MoveOther(int count);

  /// Shown when she tries to save past the cap on her own workouts. max is the real cap, in Western digits.
  ///
  /// In en, this message translates to:
  /// **'You can keep up to {max} workouts. Delete one to save a new one.'**
  String youCanKeepUpToMaxWorkouts(String max);

  /// Z18 file-count error. pictures and clips are the real limits of an event, in Western digits.
  ///
  /// In en, this message translates to:
  /// **'Choose at most {pictures} pictures and {clips} videos.'**
  String chooseAtMostPicturesPicturesAndClips(String pictures, String clips);

  /// No description provided for @inRahmasWordsAsWrittenInHer.
  ///
  /// In en, this message translates to:
  /// **'In Rahma\'s words, as written in her book'**
  String get inRahmasWordsAsWrittenInHer;

  /// No description provided for @readToTheEndToAgree.
  ///
  /// In en, this message translates to:
  /// **'Read to the end to agree.'**
  String get readToTheEndToAgree;

  /// No description provided for @january.
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get january;

  /// No description provided for @february.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get february;

  /// No description provided for @march.
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get march;

  /// No description provided for @april.
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get april;

  /// No description provided for @may.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get may;

  /// No description provided for @july.
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get july;

  /// No description provided for @august.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get august;

  /// No description provided for @october.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get october;

  /// No description provided for @november.
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get november;

  /// No description provided for @december.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get december;

  /// Month and year title, e.g. October 2026.
  ///
  /// In en, this message translates to:
  /// **'{month} {year}'**
  String monthYear(String month, String year);

  /// A calendar date, e.g. 12 October 2026.
  ///
  /// In en, this message translates to:
  /// **'{day} {month} {year}'**
  String dayMonthYear(String day, String month, String year);

  /// Length of the session in her programme.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min · your program'**
  String minutesMinYourProgram(String minutes);

  /// Planned session title with its length.
  ///
  /// In en, this message translates to:
  /// **'Full-body strength, {minutes} min'**
  String fullBodyStrengthMinutesMin(String minutes);

  /// No description provided for @onlyTheDishWhatsInItAnd.
  ///
  /// In en, this message translates to:
  /// **'Only the dish, what\'s in it and its numbers are shared, never your photo or your name.'**
  String get onlyTheDishWhatsInItAnd;

  /// No description provided for @yourMealsWorkoutsWeightPhotosAndPhone_z6z34.
  ///
  /// In en, this message translates to:
  /// **'Your meals, workouts, weight, photos and phone number are never visible to another member, except a dish you choose to share, without your name. These settings are only about what you choose to show.'**
  String get yourMealsWorkoutsWeightPhotosAndPhone_z6z34;

  /// No description provided for @weKeepAFingerprintOfThePhoto.
  ///
  /// In en, this message translates to:
  /// **'We keep a fingerprint of the photo and the foods found for 30 days, to answer the same photo again. Nothing in it identifies you.'**
  String get weKeepAFingerprintOfThePhoto;

  /// No description provided for @goodMorningLookingForABreakfastIdea.
  ///
  /// In en, this message translates to:
  /// **'Good morning. Looking for a breakfast idea? There are quick ones in the recipes.'**
  String get goodMorningLookingForABreakfastIdea;

  /// No description provided for @morningHadBreakfastYetLogItIn.
  ///
  /// In en, this message translates to:
  /// **'Morning. Had breakfast yet? Log it in a tap whenever you are ready.'**
  String get morningHadBreakfastYetLogItIn;

  /// No description provided for @teaFirstOrBreakfastAFewEasy.
  ///
  /// In en, this message translates to:
  /// **'Tea first, or breakfast? A few easy morning ideas are waiting in the recipes.'**
  String get teaFirstOrBreakfastAFewEasy;

  /// No description provided for @breakfastOnYourPlateOnePhotoOr.
  ///
  /// In en, this message translates to:
  /// **'Breakfast on your plate? One photo or one tap and it is logged.'**
  String get breakfastOnYourPlateOnePhotoOr;

  /// No description provided for @busyDayTenQuietMinutesOnYour.
  ///
  /// In en, this message translates to:
  /// **'Busy day? Ten quiet minutes on your mat still count for your week.'**
  String get busyDayTenQuietMinutesOnYour;

  /// No description provided for @notFeelingAFullSessionOneMove.
  ///
  /// In en, this message translates to:
  /// **'Not feeling a full session? One move on the mat is plenty today.'**
  String get notFeelingAFullSessionOneMove;

  /// No description provided for @aShortMoveAtHomeNoKit.
  ///
  /// In en, this message translates to:
  /// **'A short move at home, no kit, no rush. Only if it suits your afternoon.'**
  String get aShortMoveAtHomeNoKit;

  /// No description provided for @tenMinutesInYourLivingRoomIs.
  ///
  /// In en, this message translates to:
  /// **'Ten minutes in your living room is a real workout. Pick one move and begin.'**
  String get tenMinutesInYourLivingRoomIs;

  /// No description provided for @wonderingWhatIsForDinnerALight.
  ///
  /// In en, this message translates to:
  /// **'Wondering what is for dinner? A light recipe takes about ten minutes.'**
  String get wonderingWhatIsForDinnerALight;

  /// No description provided for @hadDinnerAddItToYourDay.
  ///
  /// In en, this message translates to:
  /// **'Had dinner? Add it to your day in a tap, or with one photo.'**
  String get hadDinnerAddItToYourDay;

  /// No description provided for @somethingWarmTonightHaveALookAt.
  ///
  /// In en, this message translates to:
  /// **'Something warm tonight? Have a look at the dinner ideas in the recipes.'**
  String get somethingWarmTonightHaveALookAt;

  /// No description provided for @eatingDinnerSoonLogItInOne.
  ///
  /// In en, this message translates to:
  /// **'Eating dinner soon? Log it in one tap and it joins your day.'**
  String get eatingDinnerSoonLogItInOne;

  /// No description provided for @openEventLink.
  ///
  /// In en, this message translates to:
  /// **'Open event link'**
  String get openEventLink;

  /// No description provided for @nothingLoggedSoThisOneIsNot.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged, so this one is not counted.'**
  String get nothingLoggedSoThisOneIsNot;

  /// No description provided for @onlyMovesScreenedForYouAndStop.
  ///
  /// In en, this message translates to:
  /// **'Only moves screened for you, and stop if anything feels off.'**
  String get onlyMovesScreenedForYouAndStop;

  /// No description provided for @todayCanBeAGentleDay.
  ///
  /// In en, this message translates to:
  /// **'Today can be a gentle day.'**
  String get todayCanBeAGentleDay;

  /// No description provided for @yourLastSession.
  ///
  /// In en, this message translates to:
  /// **'Your last session'**
  String get yourLastSession;

  /// Home follow-up after a session: what she logged, with a label before each figure so no noun has to agree with its number.
  ///
  /// In en, this message translates to:
  /// **'Moves: {moves} · Sets: {sets}'**
  String movesMovesSetsSets(String moves, String sets);

  /// Home follow-up: her heaviest weight in the last session. The move name stays English in both languages.
  ///
  /// In en, this message translates to:
  /// **'Up to {weight} on {move}'**
  String upToWeightOnMove(String weight, String move);

  /// No description provided for @howDoYouFeelToday.
  ///
  /// In en, this message translates to:
  /// **'How do you feel today?'**
  String get howDoYouFeelToday;

  /// No description provided for @fresh.
  ///
  /// In en, this message translates to:
  /// **'Fresh'**
  String get fresh;

  /// No description provided for @aBitSore.
  ///
  /// In en, this message translates to:
  /// **'A bit sore'**
  String get aBitSore;

  /// No description provided for @verySore.
  ///
  /// In en, this message translates to:
  /// **'Very sore'**
  String get verySore;

  /// No description provided for @thanksForTellingUs.
  ///
  /// In en, this message translates to:
  /// **'Thanks for telling us.'**
  String get thanksForTellingUs;

  /// No description provided for @nextTimeTheSameWeightsBuildUp.
  ///
  /// In en, this message translates to:
  /// **'Next time, the same weights. Build up again when you feel fresh.'**
  String get nextTimeTheSameWeightsBuildUp;

  /// No description provided for @aFewQuestionsAboutYourWeek.
  ///
  /// In en, this message translates to:
  /// **'A few questions about your week.'**
  String get aFewQuestionsAboutYourWeek;

  /// No description provided for @n3QuickQuestions.
  ///
  /// In en, this message translates to:
  /// **'3 quick questions'**
  String get n3QuickQuestions;

  /// Week review on Home: new personal bests this week. Labelled so the number needs no agreement.
  ///
  /// In en, this message translates to:
  /// **'New bests: {count}'**
  String newBestsCount(String count);

  /// Week review on Home: her average protein on the days she logged this week.
  ///
  /// In en, this message translates to:
  /// **'Average protein: {grams} g'**
  String averageProteinGramsG(String grams);

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// Home welcome-back card. A plural message because Arabic says من يوم, من يومين, من 7 أيام and من 11 يوم.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{Your last session was 1 day ago. A short one today?} other{Your last session was {days} days ago. A short one today?}}'**
  String daysPluralOneYourLastSessionWas(int days);

  /// No description provided for @proteinIdeas.
  ///
  /// In en, this message translates to:
  /// **'Protein ideas'**
  String get proteinIdeas;

  /// Home protein idea: how many of her last five logged days were under target, and a food she already eats with its protein.
  ///
  /// In en, this message translates to:
  /// **'Under your target on {lowDays} of your last 5 logged days. {food} is one you already have, {grams} g of protein.'**
  String underYourTargetOnLowdaysOfYour(
    String lowDays,
    String food,
    String grams,
  );

  /// No description provided for @howDidThisWeekFeel.
  ///
  /// In en, this message translates to:
  /// **'How did this week feel?'**
  String get howDidThisWeekFeel;

  /// No description provided for @didThePlanFitYourTime.
  ///
  /// In en, this message translates to:
  /// **'Did the plan fit your time?'**
  String get didThePlanFitYourTime;

  /// No description provided for @tooMuch.
  ///
  /// In en, this message translates to:
  /// **'Too much'**
  String get tooMuch;

  /// No description provided for @tooLittle.
  ///
  /// In en, this message translates to:
  /// **'Too little'**
  String get tooLittle;

  /// No description provided for @nextWeeksFocus.
  ///
  /// In en, this message translates to:
  /// **'Next week\'s focus'**
  String get nextWeeksFocus;

  /// No description provided for @feelGood.
  ///
  /// In en, this message translates to:
  /// **'Feel good'**
  String get feelGood;

  /// No description provided for @steadyLoss.
  ///
  /// In en, this message translates to:
  /// **'Steady loss'**
  String get steadyLoss;

  /// No description provided for @hereIsWhatWeSuggestNothingChanges.
  ///
  /// In en, this message translates to:
  /// **'Here is what we suggest. Nothing changes unless you tap.'**
  String get hereIsWhatWeSuggestNothingChanges;

  /// Week review suggestion: a new number of training days.
  ///
  /// In en, this message translates to:
  /// **'Days a week: {days}'**
  String daysAWeekDays(String days);

  /// Week review suggestion: a new session length.
  ///
  /// In en, this message translates to:
  /// **'Session length: {minutes} min'**
  String sessionLengthMinutesMin(String minutes);

  /// Week review suggestion: a new goal, named as the goal screen names it.
  ///
  /// In en, this message translates to:
  /// **'Focus: {goal}'**
  String focusGoal(String goal);

  /// No description provided for @useThis.
  ///
  /// In en, this message translates to:
  /// **'Use this'**
  String get useThis;

  /// No description provided for @keepMyPlan.
  ///
  /// In en, this message translates to:
  /// **'Keep my plan'**
  String get keepMyPlan;

  /// No description provided for @followUpsOnHome.
  ///
  /// In en, this message translates to:
  /// **'Follow-ups on Home'**
  String get followUpsOnHome;

  /// No description provided for @howYouFeelAfterASessionYour.
  ///
  /// In en, this message translates to:
  /// **'How you feel after a session, your week review and ideas. Kept on this phone.'**
  String get howYouFeelAfterASessionYour;

  /// Progress hint above each of the three week review questions.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String currentOfTotal(String current, String total);

  /// No description provided for @goodWeek.
  ///
  /// In en, this message translates to:
  /// **'Good week'**
  String get goodWeek;

  /// No description provided for @okayWeek.
  ///
  /// In en, this message translates to:
  /// **'Okay week'**
  String get okayWeek;

  /// No description provided for @hardWeek.
  ///
  /// In en, this message translates to:
  /// **'Hard week'**
  String get hardWeek;

  /// No description provided for @goToTrain.
  ///
  /// In en, this message translates to:
  /// **'Go to Train'**
  String get goToTrain;

  /// No description provided for @yourPlanStaysAsItIsSee.
  ///
  /// In en, this message translates to:
  /// **'Your plan stays as it is. See you next week.'**
  String get yourPlanStaysAsItIsSee;

  /// No description provided for @profilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Profile photo'**
  String get profilePhoto;

  /// No description provided for @yourPhotoStaysOnThisPhoneOnly.
  ///
  /// In en, this message translates to:
  /// **'Your photo stays on this phone. Only you see it.'**
  String get yourPhotoStaysOnThisPhoneOnly;

  /// No description provided for @addAPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get addAPhoto;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// No description provided for @chooseFromYourPhotos.
  ///
  /// In en, this message translates to:
  /// **'Choose from your photos'**
  String get chooseFromYourPhotos;

  /// No description provided for @fitYourPhoto.
  ///
  /// In en, this message translates to:
  /// **'Fit your photo'**
  String get fitYourPhoto;

  /// No description provided for @dragToMoveItPinchOrUse.
  ///
  /// In en, this message translates to:
  /// **'Drag to move it. Pinch or use the buttons to zoom.'**
  String get dragToMoveItPinchOrUse;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// No description provided for @yourPhotoIsSet.
  ///
  /// In en, this message translates to:
  /// **'Your photo is set.'**
  String get yourPhotoIsSet;

  /// No description provided for @yourPhotoWasRemoved.
  ///
  /// In en, this message translates to:
  /// **'Your photo was removed.'**
  String get yourPhotoWasRemoved;

  /// No description provided for @ownHubCouldNotOpenTheCamera.
  ///
  /// In en, this message translates to:
  /// **'Own Hub could not open the camera. You can allow it in your phone settings, or choose a photo instead.'**
  String get ownHubCouldNotOpenTheCamera;

  /// No description provided for @thatPhotoCouldNotBeUsedPlease.
  ///
  /// In en, this message translates to:
  /// **'That photo could not be used. Please try another one.'**
  String get thatPhotoCouldNotBeUsedPlease;

  /// No description provided for @anOwnHubEventIsComingUp.
  ///
  /// In en, this message translates to:
  /// **'An Own Hub event is coming up. Seats are limited.'**
  String get anOwnHubEventIsComingUp;

  /// No description provided for @aNewOwnHubEventIsOpen.
  ///
  /// In en, this message translates to:
  /// **'A new Own Hub event is open for booking. Have a look.'**
  String get aNewOwnHubEventIsOpen;

  /// No description provided for @yourSeatIsWaiting.
  ///
  /// In en, this message translates to:
  /// **'Your seat is waiting.'**
  String get yourSeatIsWaiting;

  /// No description provided for @yourOwnHubEventIsAlmostHere.
  ///
  /// In en, this message translates to:
  /// **'Your Own Hub event is almost here. See you there.'**
  String get yourOwnHubEventIsAlmostHere;

  /// No description provided for @eventReminders.
  ///
  /// In en, this message translates to:
  /// **'Event reminders'**
  String get eventReminders;

  /// No description provided for @aNoteBeforeEventsYouCanJoin.
  ///
  /// In en, this message translates to:
  /// **'A note before events you can join, and before the seat you booked.'**
  String get aNoteBeforeEventsYouCanJoin;

  /// No description provided for @endWorkout.
  ///
  /// In en, this message translates to:
  /// **'End workout'**
  String get endWorkout;

  /// No description provided for @endThisWorkout.
  ///
  /// In en, this message translates to:
  /// **'End this workout?'**
  String get endThisWorkout;

  /// No description provided for @finishAndSave.
  ///
  /// In en, this message translates to:
  /// **'Finish and save'**
  String get finishAndSave;

  /// The end-workout sheet: how many sets she has logged in this workout.
  ///
  /// In en, this message translates to:
  /// **'Sets saved so far: {count}'**
  String setsSavedSoFarCount(String count);

  /// No description provided for @discardThisWorkout.
  ///
  /// In en, this message translates to:
  /// **'Discard this workout'**
  String get discardThisWorkout;

  /// No description provided for @keepGoing.
  ///
  /// In en, this message translates to:
  /// **'Keep going'**
  String get keepGoing;

  /// No description provided for @nothingIsLoggedYetSoThisWorkout.
  ///
  /// In en, this message translates to:
  /// **'Nothing is logged yet, so this workout is not counted. Leave it, or keep going.'**
  String get nothingIsLoggedYetSoThisWorkout;

  /// No description provided for @workoutDiscardedItIsNotCounted.
  ///
  /// In en, this message translates to:
  /// **'Workout discarded. It is not counted.'**
  String get workoutDiscardedItIsNotCounted;

  /// No description provided for @fullScreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get fullScreen;

  /// No description provided for @restart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// No description provided for @halfSpeed.
  ///
  /// In en, this message translates to:
  /// **'Half speed'**
  String get halfSpeed;

  /// No description provided for @normalSpeed.
  ///
  /// In en, this message translates to:
  /// **'Normal speed'**
  String get normalSpeed;

  /// No description provided for @closeVideo.
  ///
  /// In en, this message translates to:
  /// **'Close video'**
  String get closeVideo;

  /// Home and Train: how many moves the viewed level's session holds. Plural because Arabic counts agree differently at 1, 2, 3 to 10 and 11 and up.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 move} other{{count} moves}}'**
  String countPluralOne1MoveOtherCount(int count);

  /// Home and Train: the rest between sets of the viewed level's session.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s rest'**
  String secondsSRest(String seconds);

  /// Home and Train: about how long the viewed level's session takes, rounded to 5 minutes. Plural for Arabic.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, one{About 1 min} other{About {minutes} min}}'**
  String minutesPluralOneAbout1MinOther(int minutes);

  /// Home and Train: the viewed level has this many more sets per move than her own level.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 more set} other{{count} more sets}}'**
  String countPluralOne1MoreSetOther(int count);

  /// Home and Train: the viewed level has this many fewer sets per move than her own level.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 set less} other{{count} sets less}}'**
  String countPluralOne1SetLessOther(int count);

  /// Home and Train: the viewed level has this many more moves than her own level.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 more move} other{{count} more moves}}'**
  String countPluralOne1MoreMoveOther(int count);

  /// Home and Train: the viewed level has this many fewer moves than her own level.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 move less} other{{count} moves less}}'**
  String countPluralOne1MoveLessOther(int count);

  /// Home and Train: the viewed level rests this many seconds longer than her own level.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s more rest'**
  String secondsSMoreRest(String seconds);

  /// Home and Train: the viewed level rests this many seconds less than her own level.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s less rest'**
  String secondsSLessRest(String seconds);

  /// Home and Train: the viewed level's session is this much longer than her own level's.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, one{1 min longer} other{{minutes} min longer}}'**
  String minutesPluralOne1MinLongerOther(int minutes);

  /// Home and Train: the viewed level's session is this much shorter than her own level's.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, one{1 min shorter} other{{minutes} min shorter}}'**
  String minutesPluralOne1MinShorterOther(int minutes);

  /// Home and Train: under the facts of the level she is looking at, what is different from the level she set. The changes are a short list joined with a middle dot.
  ///
  /// In en, this message translates to:
  /// **'Compared with your level: {changes}'**
  String comparedWithYourLevelChanges(String changes);

  /// No description provided for @thisIsYourLevel.
  ///
  /// In en, this message translates to:
  /// **'This is your level'**
  String get thisIsYourLevel;

  /// Home macros: the target under a macro's eaten grams, for example 'of 120 g'.
  ///
  /// In en, this message translates to:
  /// **'of {target} g'**
  String ofTargetG(String target);

  /// O03: the 15 minute preset, named as a short day.
  ///
  /// In en, this message translates to:
  /// **'{n} min · short day'**
  String nMinShortDay(String n);

  /// No description provided for @whatCantYouEat.
  ///
  /// In en, this message translates to:
  /// **'What can\'t you eat?'**
  String get whatCantYouEat;

  /// No description provided for @checkedByOwnHub.
  ///
  /// In en, this message translates to:
  /// **'Checked by Own Hub'**
  String get checkedByOwnHub;

  /// No description provided for @buildMuscle.
  ///
  /// In en, this message translates to:
  /// **'Build muscle'**
  String get buildMuscle;

  /// No description provided for @heavierLiftsBuiltUpALittleEach.
  ///
  /// In en, this message translates to:
  /// **'Heavier lifts, built up a little each week. Best with a gym or dumbbells.'**
  String get heavierLiftsBuiltUpALittleEach;

  /// No description provided for @eachSessionStartsWithTheBigLifts.
  ///
  /// In en, this message translates to:
  /// **'Each session starts with the big lifts, then the smaller ones. Add a rep, or a little weight, once every set is done.'**
  String get eachSessionStartsWithTheBigLifts;

  /// No description provided for @gym.
  ///
  /// In en, this message translates to:
  /// **'Gym'**
  String get gym;

  /// No description provided for @whereYouTrain.
  ///
  /// In en, this message translates to:
  /// **'Where you train'**
  String get whereYouTrain;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @changeTheseAndYourPlanChangesWith.
  ///
  /// In en, this message translates to:
  /// **'Change these and your plan changes with them.'**
  String get changeTheseAndYourPlanChangesWith;

  /// Preview in the quick training sheet. plan is the plan name, where she trains and her level.
  ///
  /// In en, this message translates to:
  /// **'Your plan will be {plan}.'**
  String yourPlanWillBePlan(String plan);

  /// No description provided for @samePlanAsNow.
  ///
  /// In en, this message translates to:
  /// **'Same plan as now.'**
  String get samePlanAsNow;

  /// No description provided for @buildMuscleNeedsAGymOrDumbbells.
  ///
  /// In en, this message translates to:
  /// **'Build muscle needs a gym or dumbbells. For now you get strength training with your body weight.'**
  String get buildMuscleNeedsAGymOrDumbbells;

  /// No description provided for @insights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insights;

  /// No description provided for @sweets.
  ///
  /// In en, this message translates to:
  /// **'Sweets'**
  String get sweets;

  /// No description provided for @safeForMe.
  ///
  /// In en, this message translates to:
  /// **'Safe for me'**
  String get safeForMe;

  /// No description provided for @showAllEgyptianDishes.
  ///
  /// In en, this message translates to:
  /// **'Show all Egyptian dishes'**
  String get showAllEgyptianDishes;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// Shown under the search bar after she taps Log on a meal row, so she knows which meal the next food goes to.
  ///
  /// In en, this message translates to:
  /// **'Adding to {meal}'**
  String addingToMeal(String meal);

  /// No description provided for @shareYourWorkout.
  ///
  /// In en, this message translates to:
  /// **'Share your workout'**
  String get shareYourWorkout;

  /// No description provided for @square.
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get square;

  /// No description provided for @linen.
  ///
  /// In en, this message translates to:
  /// **'Linen'**
  String get linen;

  /// No description provided for @petrol.
  ///
  /// In en, this message translates to:
  /// **'Petrol'**
  String get petrol;

  /// No description provided for @transparent.
  ///
  /// In en, this message translates to:
  /// **'Transparent'**
  String get transparent;

  /// No description provided for @caloriesEst.
  ///
  /// In en, this message translates to:
  /// **'Calories (est.)'**
  String get caloriesEst;

  /// No description provided for @weightLifted.
  ///
  /// In en, this message translates to:
  /// **'Weight lifted'**
  String get weightLifted;

  /// No description provided for @movesAndSets.
  ///
  /// In en, this message translates to:
  /// **'Moves and sets'**
  String get movesAndSets;

  /// No description provided for @myName.
  ///
  /// In en, this message translates to:
  /// **'My name'**
  String get myName;

  /// No description provided for @customiseTheCard.
  ///
  /// In en, this message translates to:
  /// **'Customise the card'**
  String get customiseTheCard;

  /// No description provided for @format.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get format;

  /// No description provided for @background.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get background;

  /// No description provided for @showOnTheCard.
  ///
  /// In en, this message translates to:
  /// **'Show on the card'**
  String get showOnTheCard;

  /// No description provided for @caloriesAreARoughEstimateFromYour.
  ///
  /// In en, this message translates to:
  /// **'Calories are a rough estimate from your time and your weight, not medical advice.'**
  String get caloriesAreARoughEstimateFromYour;

  /// No description provided for @thisIsThePictureYouWillShare.
  ///
  /// In en, this message translates to:
  /// **'This is the picture you will share. Nothing leaves your phone unless you tap Share.'**
  String get thisIsThePictureYouWillShare;

  /// Default title of the share card when the workout has no name; the day is the weekday she trained.
  ///
  /// In en, this message translates to:
  /// **'{day} workout'**
  String dayWorkout(String day);

  /// No description provided for @previewOfYourWorkoutCard.
  ///
  /// In en, this message translates to:
  /// **'Preview of your workout card'**
  String get previewOfYourWorkoutCard;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @setsAndReps.
  ///
  /// In en, this message translates to:
  /// **'Sets and reps'**
  String get setsAndReps;

  /// No description provided for @dragToReorder.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get dragToReorder;

  /// No description provided for @updateMySavedWorkout.
  ///
  /// In en, this message translates to:
  /// **'Update my saved workout?'**
  String get updateMySavedWorkout;

  /// No description provided for @updateMyPlan.
  ///
  /// In en, this message translates to:
  /// **'Update my plan?'**
  String get updateMyPlan;

  /// No description provided for @yourChangesWillReplaceTheSavedVersion.
  ///
  /// In en, this message translates to:
  /// **'Your changes will replace the saved version.'**
  String get yourChangesWillReplaceTheSavedVersion;

  /// No description provided for @thisDayInYourPlanWillChange.
  ///
  /// In en, this message translates to:
  /// **'This day in your plan will change. The original split stays available.'**
  String get thisDayInYourPlanWillChange;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @justThisTime.
  ///
  /// In en, this message translates to:
  /// **'Just this time'**
  String get justThisTime;

  /// No description provided for @updatedInYourPlan.
  ///
  /// In en, this message translates to:
  /// **'Updated in your plan'**
  String get updatedInYourPlan;

  /// No description provided for @useThisMove.
  ///
  /// In en, this message translates to:
  /// **'Use this move'**
  String get useThisMove;

  /// No description provided for @startFromScratch.
  ///
  /// In en, this message translates to:
  /// **'Start from scratch'**
  String get startFromScratch;

  /// No description provided for @editOneOfTheThreeSplits.
  ///
  /// In en, this message translates to:
  /// **'Edit one of the three splits'**
  String get editOneOfTheThreeSplits;

  /// No description provided for @customizeThisPlan.
  ///
  /// In en, this message translates to:
  /// **'Customize this plan'**
  String get customizeThisPlan;

  /// No description provided for @myPlan.
  ///
  /// In en, this message translates to:
  /// **'My plan'**
  String get myPlan;

  /// No description provided for @editMyPlan.
  ///
  /// In en, this message translates to:
  /// **'Edit my plan'**
  String get editMyPlan;

  /// No description provided for @changePlan.
  ///
  /// In en, this message translates to:
  /// **'Change plan'**
  String get changePlan;

  /// No description provided for @theseAreYourTrainingDaysOpenA.
  ///
  /// In en, this message translates to:
  /// **'These are your training days. Open a day to change its moves.'**
  String get theseAreYourTrainingDaysOpenA;

  /// No description provided for @noDaysYetAddYourFirstDay.
  ///
  /// In en, this message translates to:
  /// **'No days yet. Add your first day.'**
  String get noDaysYetAddYourFirstDay;

  /// No description provided for @removeDay.
  ///
  /// In en, this message translates to:
  /// **'Remove day'**
  String get removeDay;

  /// No description provided for @replace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replace;

  /// No description provided for @replaceThisDay.
  ///
  /// In en, this message translates to:
  /// **'Replace this day'**
  String get replaceThisDay;

  /// No description provided for @putThisDayBackAsItWas.
  ///
  /// In en, this message translates to:
  /// **'Put this day back as it was in the original split'**
  String get putThisDayBackAsItWas;

  /// No description provided for @orUseTheMovesOfAnotherDay.
  ///
  /// In en, this message translates to:
  /// **'Or use the moves of another day'**
  String get orUseTheMovesOfAnotherDay;

  /// No description provided for @blankDay.
  ///
  /// In en, this message translates to:
  /// **'Blank day'**
  String get blankDay;

  /// Option that adds a copy of one of her own days to her plan.
  ///
  /// In en, this message translates to:
  /// **'Copy of {name}'**
  String copyOfName(String name);

  /// No description provided for @addADayToMyPlan.
  ///
  /// In en, this message translates to:
  /// **'Add a day to my plan'**
  String get addADayToMyPlan;

  /// No description provided for @addToMyPlan.
  ///
  /// In en, this message translates to:
  /// **'Add to my plan'**
  String get addToMyPlan;

  /// No description provided for @addedToYourPlan.
  ///
  /// In en, this message translates to:
  /// **'Added to your plan'**
  String get addedToYourPlan;

  /// No description provided for @backToTheOriginalSplit.
  ///
  /// In en, this message translates to:
  /// **'Back to the original split'**
  String get backToTheOriginalSplit;

  /// No description provided for @goBackToTheOriginalSplit.
  ///
  /// In en, this message translates to:
  /// **'Go back to the original split?'**
  String get goBackToTheOriginalSplit;

  /// No description provided for @yourChangesToThePlanWillBe.
  ///
  /// In en, this message translates to:
  /// **'Your changes to the plan will be removed. Your saved workouts stay.'**
  String get yourChangesToThePlanWillBe;

  /// No description provided for @goBackToTheOriginal.
  ///
  /// In en, this message translates to:
  /// **'Go back to the original'**
  String get goBackToTheOriginal;

  /// No description provided for @startFromABlankPlan.
  ///
  /// In en, this message translates to:
  /// **'Start from a blank plan?'**
  String get startFromABlankPlan;

  /// No description provided for @thisRemovesEveryDayFromYourPlan.
  ///
  /// In en, this message translates to:
  /// **'This removes every day from your plan. You can still go back to the original split.'**
  String get thisRemovesEveryDayFromYourPlan;

  /// No description provided for @clearMyPlan.
  ///
  /// In en, this message translates to:
  /// **'Clear my plan'**
  String get clearMyPlan;

  /// A day's number in her plan.
  ///
  /// In en, this message translates to:
  /// **'Day {number}'**
  String dayNumber(String number);

  /// No description provided for @n15SLess.
  ///
  /// In en, this message translates to:
  /// **'15 s less'**
  String get n15SLess;

  /// No description provided for @n15SMore.
  ///
  /// In en, this message translates to:
  /// **'15 s more'**
  String get n15SMore;

  /// No description provided for @shortenTheRestBy15Seconds.
  ///
  /// In en, this message translates to:
  /// **'Shorten the rest by 15 seconds'**
  String get shortenTheRestBy15Seconds;

  /// No description provided for @add15SecondsToTheRest.
  ///
  /// In en, this message translates to:
  /// **'Add 15 seconds to the rest'**
  String get add15SecondsToTheRest;

  /// No description provided for @warmUpSet.
  ///
  /// In en, this message translates to:
  /// **'Warm-up set'**
  String get warmUpSet;

  /// No description provided for @notCountedInYourSetsOrRecords.
  ///
  /// In en, this message translates to:
  /// **'Not counted in your sets or records'**
  String get notCountedInYourSetsOrRecords;

  /// No description provided for @warmUp.
  ///
  /// In en, this message translates to:
  /// **'Warm-up'**
  String get warmUp;

  /// R07 button while the warm-up switch is on; names the set it saves.
  ///
  /// In en, this message translates to:
  /// **'Done · warm-up {figure}'**
  String doneWarmUpFigure(String figure);

  /// R09 bar after a warm-up set is saved.
  ///
  /// In en, this message translates to:
  /// **'Warm-up saved · {figure}'**
  String warmUpSavedFigure(String figure);

  /// Quiet suggestion on R07 before the first set of a loaded move.
  ///
  /// In en, this message translates to:
  /// **'Warm up with about {weight} first, around half your working weight.'**
  String warmUpWithAboutWeightFirstAround(String weight);

  /// No description provided for @newBest.
  ///
  /// In en, this message translates to:
  /// **'New best'**
  String get newBest;

  /// What improved, on the New best chip.
  ///
  /// In en, this message translates to:
  /// **'Heaviest weight yet: {weight}'**
  String heaviestWeightYetWeight(String weight);

  /// What improved, on the New best chip.
  ///
  /// In en, this message translates to:
  /// **'Most reps at {weight}: {reps}'**
  String mostRepsAtWeightReps(String weight, String reps);

  /// What improved on a bodyweight move.
  ///
  /// In en, this message translates to:
  /// **'Most reps yet: {reps}'**
  String mostRepsYetReps(String reps);

  /// What improved on a timed hold.
  ///
  /// In en, this message translates to:
  /// **'Longest hold yet: {time}'**
  String longestHoldYetTime(String time);

  /// No description provided for @aHarderVersionOfThisMove.
  ///
  /// In en, this message translates to:
  /// **'A harder version of this move'**
  String get aHarderVersionOfThisMove;

  /// No description provided for @foodLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Food, last 7 days'**
  String get foodLast7Days;

  /// No description provided for @logAMealAndYourProteinAnd.
  ///
  /// In en, this message translates to:
  /// **'Log a meal and your protein and calories show here, next to your target.'**
  String get logAMealAndYourProteinAnd;

  /// Under the 7-day food chart: how many of the last 7 days have a meal logged.
  ///
  /// In en, this message translates to:
  /// **'You logged food on {logged} of 7 days'**
  String youLoggedFoodOnLoggedOf7(String logged);

  /// No description provided for @proteinAverageOfTheDaysYouLogged.
  ///
  /// In en, this message translates to:
  /// **'Protein, average of the days you logged'**
  String get proteinAverageOfTheDaysYouLogged;

  /// No description provided for @caloriesAverageOfTheDaysYouLogged.
  ///
  /// In en, this message translates to:
  /// **'Calories, average of the days you logged'**
  String get caloriesAverageOfTheDaysYouLogged;

  /// No description provided for @trainOnceAndYourBodyMapRecords.
  ///
  /// In en, this message translates to:
  /// **'Train once and your body map, records and weekly sets fill in here.'**
  String get trainOnceAndYourBodyMapRecords;

  /// No description provided for @yourBodyMapAndSets.
  ///
  /// In en, this message translates to:
  /// **'Your body map and sets'**
  String get yourBodyMapAndSets;

  /// No description provided for @opensYourPrivateMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Opens your private measurements'**
  String get opensYourPrivateMeasurements;

  /// Name of a coach split: the number of training days a week, 3, 4 or 5.
  ///
  /// In en, this message translates to:
  /// **'{n}-day split'**
  String nDaySplit(String n);

  /// A number of training days a week, 3, 4 or 5.
  ///
  /// In en, this message translates to:
  /// **'{n} days'**
  String nDays(String n);

  /// No description provided for @recommendedForYourDays.
  ///
  /// In en, this message translates to:
  /// **'Recommended for your days'**
  String get recommendedForYourDays;

  /// No description provided for @choose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get choose;

  /// No description provided for @customize.
  ///
  /// In en, this message translates to:
  /// **'Customize'**
  String get customize;

  /// No description provided for @startFromScratchOrEditOneOf.
  ///
  /// In en, this message translates to:
  /// **'Start from scratch or edit one of the three.'**
  String get startFromScratchOrEditOneOf;

  /// No description provided for @replaceYourPlanWithThisSplit.
  ///
  /// In en, this message translates to:
  /// **'Replace your plan with this split?'**
  String get replaceYourPlanWithThisSplit;

  /// No description provided for @yourPlanIsSwappedForACopy.
  ///
  /// In en, this message translates to:
  /// **'Your plan is swapped for a copy of this split. You can change that copy as you like.'**
  String get yourPlanIsSwappedForACopy;

  /// No description provided for @thisDayUsesGymMachinesSwapA.
  ///
  /// In en, this message translates to:
  /// **'This day uses gym machines. Swap a move for one you can do at home.'**
  String get thisDayUsesGymMachinesSwapA;

  /// No description provided for @yourPhotoIsKeptOnThisPhone.
  ///
  /// In en, this message translates to:
  /// **'Your photo is kept on this phone and never uploaded by Own Hub. Only you see it.'**
  String get yourPhotoIsKeptOnThisPhone;

  /// R09's shorter-rest button. seconds is the rest step in Western digits, e.g. 15.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s less'**
  String secondsSLess(String seconds);

  /// R09's longer-rest button. seconds is the rest step in Western digits, e.g. 15.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s more'**
  String secondsSMore(String seconds);

  /// Spoken label of R09's shorter-rest button. seconds is the rest step in Western digits.
  ///
  /// In en, this message translates to:
  /// **'Shorten the rest by {seconds} seconds'**
  String shortenTheRestBySecondsSeconds(String seconds);

  /// Spoken label of R09's longer-rest button. seconds is the rest step in Western digits.
  ///
  /// In en, this message translates to:
  /// **'Add {seconds} seconds to the rest'**
  String addSecondsSecondsToTheRest(String seconds);

  /// The heading of Insights' food chart. days is the number of days it covers, in Western digits.
  ///
  /// In en, this message translates to:
  /// **'Food, last {days} days'**
  String foodLastDaysDays(String days);

  /// No description provided for @noSessionsOfThisMoveYet.
  ///
  /// In en, this message translates to:
  /// **'No sessions of this move yet'**
  String get noSessionsOfThisMoveYet;

  /// No description provided for @yourLastSessionsOfThisMove.
  ///
  /// In en, this message translates to:
  /// **'Your last sessions of this move'**
  String get yourLastSessionsOfThisMove;

  /// A hold in seconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String secondsS(String seconds);

  /// Screen reader label for one bar of a move's history.
  ///
  /// In en, this message translates to:
  /// **'Best set on {date}: {set}'**
  String bestSetOnDateSet(String date, String set);

  /// No description provided for @recentSessions.
  ///
  /// In en, this message translates to:
  /// **'Recent sessions'**
  String get recentSessions;

  /// No description provided for @fixingATypoUpdatesYourBestsPoints.
  ///
  /// In en, this message translates to:
  /// **'Fixing a typo updates your bests. Points stay as they are.'**
  String get fixingATypoUpdatesYourBestsPoints;

  /// No description provided for @noFinishedSessionsYet.
  ///
  /// In en, this message translates to:
  /// **'No finished sessions yet'**
  String get noFinishedSessionsYet;

  /// No description provided for @sessionsYouFinishShowUpHereAnd.
  ///
  /// In en, this message translates to:
  /// **'Sessions you finish show up here, and you can fix a set.'**
  String get sessionsYouFinishShowUpHereAnd;

  /// No description provided for @workout.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get workout;

  /// No description provided for @fixThisSet.
  ///
  /// In en, this message translates to:
  /// **'Fix this set'**
  String get fixThisSet;

  /// A set number in a finished session.
  ///
  /// In en, this message translates to:
  /// **'Set {n}'**
  String setN(String n);

  /// Undo bar after fixing a set.
  ///
  /// In en, this message translates to:
  /// **'Set {n} is now {set}'**
  String setNIsNowSet(String n, String set);

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get addNote;

  /// No description provided for @editNote.
  ///
  /// In en, this message translates to:
  /// **'Edit note'**
  String get editNote;

  /// No description provided for @noteForThisMove.
  ///
  /// In en, this message translates to:
  /// **'Note for this move'**
  String get noteForThisMove;

  /// No description provided for @keptOnThisPhoneOnly.
  ///
  /// In en, this message translates to:
  /// **'Kept on this phone only.'**
  String get keptOnThisPhoneOnly;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @whichBarDoYouUse.
  ///
  /// In en, this message translates to:
  /// **'Which bar do you use?'**
  String get whichBarDoYouUse;

  /// No description provided for @changeBar.
  ///
  /// In en, this message translates to:
  /// **'Change bar'**
  String get changeBar;

  /// A bar weight choice.
  ///
  /// In en, this message translates to:
  /// **'{kg} kg bar'**
  String kgKgBar(String kg);

  /// How to load a barbell.
  ///
  /// In en, this message translates to:
  /// **'{bar} kg bar + {side} kg each side'**
  String barKgBarSideKgEachSide(String bar, String side);

  /// Empty bar.
  ///
  /// In en, this message translates to:
  /// **'Just the {bar} kg bar'**
  String justTheBarKgBar(String bar);

  /// Total not loadable exactly.
  ///
  /// In en, this message translates to:
  /// **'Closest you can load: {total} kg. {bar} kg bar + {side} kg each side.'**
  String closestYouCanLoadTotalKgBar(String total, String bar, String side);

  /// Screen reader label of the plate diagram.
  ///
  /// In en, this message translates to:
  /// **'Plates on one side: {plates} kg'**
  String platesOnOneSidePlatesKg(String plates);

  /// No description provided for @logTheTotalBarIncluded.
  ///
  /// In en, this message translates to:
  /// **'Log the total, bar included.'**
  String get logTheTotalBarIncluded;

  /// Range error on the set editor's weight field.
  ///
  /// In en, this message translates to:
  /// **'Weight must be 0 to {max} kg'**
  String weightMustBe0ToMaxKg(String max);

  /// Range error on the set editor's reps field.
  ///
  /// In en, this message translates to:
  /// **'Reps must be 0 to {max}'**
  String repsMustBe0ToMax(String max);

  /// Range error on the set editor's seconds field.
  ///
  /// In en, this message translates to:
  /// **'Seconds must be 0 to {max}'**
  String secondsMustBe0ToMax(String max);

  /// No description provided for @seatAndPinNumbers.
  ///
  /// In en, this message translates to:
  /// **'Seat and pin numbers'**
  String get seatAndPinNumbers;

  /// No description provided for @findACoach.
  ///
  /// In en, this message translates to:
  /// **'Find a coach'**
  String get findACoach;

  /// No description provided for @threeQuickQuestionsThenTheCoachesWho.
  ///
  /// In en, this message translates to:
  /// **'Three quick questions, then the coaches who fit you best.'**
  String get threeQuickQuestionsThenTheCoachesWho;

  /// No description provided for @whereDoYouTrain.
  ///
  /// In en, this message translates to:
  /// **'Where do you train?'**
  String get whereDoYouTrain;

  /// No description provided for @atTheGym.
  ///
  /// In en, this message translates to:
  /// **'At the gym'**
  String get atTheGym;

  /// No description provided for @yourBudgetForAMonth.
  ///
  /// In en, this message translates to:
  /// **'Your budget for a month'**
  String get yourBudgetForAMonth;

  /// No description provided for @yourBestMatches.
  ///
  /// In en, this message translates to:
  /// **'Your best matches'**
  String get yourBestMatches;

  /// No description provided for @matchedOnYourThreeAnswersOnlyThen.
  ///
  /// In en, this message translates to:
  /// **'Matched on your three answers only, then by name A to Z.'**
  String get matchedOnYourThreeAnswersOnlyThen;

  /// No description provided for @noCloseMatchYetBrowseAllThe.
  ///
  /// In en, this message translates to:
  /// **'No close match yet. Browse all the coaches below.'**
  String get noCloseMatchYetBrowseAllThe;

  /// No description provided for @allCoachesAToZ.
  ///
  /// In en, this message translates to:
  /// **'All coaches A to Z'**
  String get allCoachesAToZ;

  /// No description provided for @coachesAreJoiningCheckBackSoon.
  ///
  /// In en, this message translates to:
  /// **'Coaches are joining. Check back soon.'**
  String get coachesAreJoiningCheckBackSoon;

  /// No description provided for @weCouldNotLoadTheCoachesCheck.
  ///
  /// In en, this message translates to:
  /// **'We could not load the coaches. Check your connection and try again.'**
  String get weCouldNotLoadTheCoachesCheck;

  /// No description provided for @loadingCoaches.
  ///
  /// In en, this message translates to:
  /// **'Loading coaches'**
  String get loadingCoaches;

  /// Coach browsing.
  ///
  /// In en, this message translates to:
  /// **'From EGP {price} a month'**
  String fromEgpPriceAMonth(String price);

  /// Coach browsing.
  ///
  /// In en, this message translates to:
  /// **'Open the profile of {name}'**
  String openTheProfileOfName(String name);

  /// No description provided for @verifiedCoach.
  ///
  /// In en, this message translates to:
  /// **'Verified coach'**
  String get verifiedCoach;

  /// No description provided for @yearsCoaching.
  ///
  /// In en, this message translates to:
  /// **'Years coaching'**
  String get yearsCoaching;

  /// No description provided for @fatLoss.
  ///
  /// In en, this message translates to:
  /// **'Fat loss'**
  String get fatLoss;

  /// No description provided for @muscleGain.
  ///
  /// In en, this message translates to:
  /// **'Muscle gain'**
  String get muscleGain;

  /// No description provided for @homeTraining.
  ///
  /// In en, this message translates to:
  /// **'Home training'**
  String get homeTraining;

  /// No description provided for @gymTraining.
  ///
  /// In en, this message translates to:
  /// **'Gym training'**
  String get gymTraining;

  /// No description provided for @mobility.
  ///
  /// In en, this message translates to:
  /// **'Mobility'**
  String get mobility;

  /// No description provided for @postnatalReturn.
  ///
  /// In en, this message translates to:
  /// **'Postnatal return'**
  String get postnatalReturn;

  /// No description provided for @healthyEating.
  ///
  /// In en, this message translates to:
  /// **'Healthy eating'**
  String get healthyEating;

  /// No description provided for @endurance.
  ///
  /// In en, this message translates to:
  /// **'Endurance'**
  String get endurance;

  /// No description provided for @coachProfile.
  ///
  /// In en, this message translates to:
  /// **'Coach profile'**
  String get coachProfile;

  /// No description provided for @thisIsHowMembersSeeYou.
  ///
  /// In en, this message translates to:
  /// **'This is how members see you'**
  String get thisIsHowMembersSeeYou;

  /// Coach browsing.
  ///
  /// In en, this message translates to:
  /// **'Years coaching: {n}'**
  String yearsCoachingN(int n);

  /// Coach browsing.
  ///
  /// In en, this message translates to:
  /// **'Languages: {list}'**
  String languagesList(String list);

  /// Coach browsing.
  ///
  /// In en, this message translates to:
  /// **'Usually replies within {n} hours'**
  String usuallyRepliesWithinNHours(int n);

  /// No description provided for @noPackagesYet.
  ///
  /// In en, this message translates to:
  /// **'No packages yet'**
  String get noPackagesYet;

  /// No description provided for @whatIsIncluded.
  ///
  /// In en, this message translates to:
  /// **'What is included'**
  String get whatIsIncluded;

  /// Coach browsing.
  ///
  /// In en, this message translates to:
  /// **'Duration: {n} days'**
  String durationNDays(int n);

  /// Coach browsing.
  ///
  /// In en, this message translates to:
  /// **'Live sessions a month: {n}'**
  String liveSessionsAMonthN(int n);

  /// Coach browsing.
  ///
  /// In en, this message translates to:
  /// **'EGP {price}'**
  String egpPrice(String price);

  /// No description provided for @finalPriceTaxesAndFeesIncluded.
  ///
  /// In en, this message translates to:
  /// **'Final price, taxes and fees included'**
  String get finalPriceTaxesAndFeesIncluded;

  /// No description provided for @youWillBeAbleToBookA.
  ///
  /// In en, this message translates to:
  /// **'You will be able to book a package here once booking opens.'**
  String get youWillBeAbleToBookA;

  /// No description provided for @approach.
  ///
  /// In en, this message translates to:
  /// **'Approach'**
  String get approach;

  /// No description provided for @whatMembersSay.
  ///
  /// In en, this message translates to:
  /// **'What members say'**
  String get whatMembersSay;

  /// No description provided for @checkedCertificates.
  ///
  /// In en, this message translates to:
  /// **'Checked certificates'**
  String get checkedCertificates;

  /// No description provided for @reportThisProfile.
  ///
  /// In en, this message translates to:
  /// **'Report this profile'**
  String get reportThisProfile;

  /// No description provided for @whyAreYouReportingThisProfile.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting this profile?'**
  String get whyAreYouReportingThisProfile;

  /// No description provided for @thisLooksLikeAMansAccount.
  ///
  /// In en, this message translates to:
  /// **'This looks like a man\'s account'**
  String get thisLooksLikeAMansAccount;

  /// No description provided for @nudityOrSexualContent.
  ///
  /// In en, this message translates to:
  /// **'Nudity or sexual content'**
  String get nudityOrSexualContent;

  /// No description provided for @spamOrAdvertising.
  ///
  /// In en, this message translates to:
  /// **'Spam or advertising'**
  String get spamOrAdvertising;

  /// No description provided for @selfHarmOrDanger.
  ///
  /// In en, this message translates to:
  /// **'Self-harm or danger'**
  String get selfHarmOrDanger;

  /// No description provided for @askingForPaymentOutsideOwnHub.
  ///
  /// In en, this message translates to:
  /// **'Asking for payment outside Own Hub'**
  String get askingForPaymentOutsideOwnHub;

  /// No description provided for @unsafeTrainingOrFoodAdvice.
  ///
  /// In en, this message translates to:
  /// **'Unsafe training or food advice'**
  String get unsafeTrainingOrFoodAdvice;

  /// No description provided for @addANoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Add a note (optional)'**
  String get addANoteOptional;

  /// No description provided for @thankYouWeWillLookAtThis.
  ///
  /// In en, this message translates to:
  /// **'Thank you. We will look at this.'**
  String get thankYouWeWillLookAtThis;

  /// No description provided for @yourReportIsPrivateTheCoachIs.
  ///
  /// In en, this message translates to:
  /// **'Your report is private. The coach is not told.'**
  String get yourReportIsPrivateTheCoachIs;

  /// No description provided for @weCouldNotSendYourReportTry.
  ///
  /// In en, this message translates to:
  /// **'We could not send your report. Try again.'**
  String get weCouldNotSendYourReportTry;

  /// Coach browsing.
  ///
  /// In en, this message translates to:
  /// **'Photo of {name}'**
  String photoOfName(String name);

  /// No description provided for @myCoachSpace.
  ///
  /// In en, this message translates to:
  /// **'My coach space'**
  String get myCoachSpace;

  /// No description provided for @yourPortfolioIsLive.
  ///
  /// In en, this message translates to:
  /// **'Your portfolio is live'**
  String get yourPortfolioIsLive;

  /// No description provided for @yourPortfolioIsNotLiveYet.
  ///
  /// In en, this message translates to:
  /// **'Your portfolio is not live yet'**
  String get yourPortfolioIsNotLiveYet;

  /// No description provided for @turnOnOnePackageAndMembersCan.
  ///
  /// In en, this message translates to:
  /// **'Turn on one package and members can see your portfolio.'**
  String get turnOnOnePackageAndMembersCan;

  /// No description provided for @acceptingNewClients.
  ///
  /// In en, this message translates to:
  /// **'Accepting new clients'**
  String get acceptingNewClients;

  /// No description provided for @photoHeadlineAndHowYouCoach.
  ///
  /// In en, this message translates to:
  /// **'Photo, headline and how you coach'**
  String get photoHeadlineAndHowYouCoach;

  /// No description provided for @myPackages.
  ///
  /// In en, this message translates to:
  /// **'My packages'**
  String get myPackages;

  /// No description provided for @upTo6PackagesEachWithYour.
  ///
  /// In en, this message translates to:
  /// **'Up to 6 packages, each with your own price'**
  String get upTo6PackagesEachWithYour;

  /// How many packages the coach has made, out of the 6 she may make.
  ///
  /// In en, this message translates to:
  /// **'{count} of 6 packages'**
  String countOf6Packages(String count);

  /// No description provided for @previewMyPortfolio.
  ///
  /// In en, this message translates to:
  /// **'Preview my portfolio'**
  String get previewMyPortfolio;

  /// No description provided for @seeItTheWayMembersDo.
  ///
  /// In en, this message translates to:
  /// **'See it the way members do'**
  String get seeItTheWayMembersDo;

  /// No description provided for @myApplication.
  ///
  /// In en, this message translates to:
  /// **'My application'**
  String get myApplication;

  /// No description provided for @whatWasApproved.
  ///
  /// In en, this message translates to:
  /// **'What was approved'**
  String get whatWasApproved;

  /// No description provided for @yourCoachSpaceIsPaused.
  ///
  /// In en, this message translates to:
  /// **'Your coach space is paused'**
  String get yourCoachSpaceIsPaused;

  /// No description provided for @pleaseContactOwnHubNothingCanBe.
  ///
  /// In en, this message translates to:
  /// **'Please contact Own Hub. Nothing can be changed while it is paused.'**
  String get pleaseContactOwnHubNothingCanBe;

  /// No description provided for @yourCoachSpaceIsNotReadyYet.
  ///
  /// In en, this message translates to:
  /// **'Your coach space is not ready yet'**
  String get yourCoachSpaceIsNotReadyYet;

  /// No description provided for @itOpensHereOnceYourApplicationIs.
  ///
  /// In en, this message translates to:
  /// **'It opens here once your application is approved.'**
  String get itOpensHereOnceYourApplicationIs;

  /// No description provided for @loadingYourCoachSpace.
  ///
  /// In en, this message translates to:
  /// **'Loading your coach space'**
  String get loadingYourCoachSpace;

  /// No description provided for @weCouldNotReachOwnHubCheck.
  ///
  /// In en, this message translates to:
  /// **'We could not reach Own Hub. Check your connection and try again.'**
  String get weCouldNotReachOwnHubCheck;

  /// No description provided for @somethingWentWrongPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get somethingWentWrongPleaseTryAgain;

  /// No description provided for @coachingIsNotOpenRightNowPlease.
  ///
  /// In en, this message translates to:
  /// **'Coaching is not open right now. Please try again later.'**
  String get coachingIsNotOpenRightNowPlease;

  /// No description provided for @yourAccountNeedsToBeVerifiedFirst.
  ///
  /// In en, this message translates to:
  /// **'Your account needs to be verified first.'**
  String get yourAccountNeedsToBeVerifiedFirst;

  /// No description provided for @thisAccountIsNotAnApprovedCoach.
  ///
  /// In en, this message translates to:
  /// **'This account is not an approved coach.'**
  String get thisAccountIsNotAnApprovedCoach;

  /// No description provided for @somethingInThisFormNeedsAnotherLook.
  ///
  /// In en, this message translates to:
  /// **'Something in this form needs another look.'**
  String get somethingInThisFormNeedsAnotherLook;

  /// The range a coach may price a package in.
  ///
  /// In en, this message translates to:
  /// **'Pick a price between EGP {low} and EGP {high}.'**
  String pickAPriceBetweenEgpLowAnd(String low, String high);

  /// No description provided for @weCouldNotFindThatPackageGo.
  ///
  /// In en, this message translates to:
  /// **'We could not find that package. Go back and open it again.'**
  String get weCouldNotFindThatPackageGo;

  /// No description provided for @thatPictureCouldNotBeUsedTry.
  ///
  /// In en, this message translates to:
  /// **'That picture could not be used. Try a different one.'**
  String get thatPictureCouldNotBeUsedTry;

  /// No description provided for @pleaseSignInAgain_3jocz.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again.'**
  String get pleaseSignInAgain_3jocz;

  /// No description provided for @oneLineMembersReadFirst.
  ///
  /// In en, this message translates to:
  /// **'One line members read first'**
  String get oneLineMembersReadFirst;

  /// No description provided for @tellMembersHowYouWorkWithA.
  ///
  /// In en, this message translates to:
  /// **'Tell members how you work with a client.'**
  String get tellMembersHowYouWorkWithA;

  /// The length a text field accepts.
  ///
  /// In en, this message translates to:
  /// **'Use {low} to {high} characters.'**
  String useLowToHighCharacters(String low, String high);

  /// No description provided for @acceptRequestsAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Accept requests automatically'**
  String get acceptRequestsAutomatically;

  /// No description provided for @mostClientsAtOnce.
  ///
  /// In en, this message translates to:
  /// **'Most clients at once'**
  String get mostClientsAtOnce;

  /// No description provided for @yourPhotoIsSaved.
  ///
  /// In en, this message translates to:
  /// **'Your photo is saved.'**
  String get yourPhotoIsSaved;

  /// No description provided for @theCameraIsTurnedOffForOwn.
  ///
  /// In en, this message translates to:
  /// **'The camera is turned off for Own Hub. You can turn it on in Settings.'**
  String get theCameraIsTurnedOffForOwn;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @yourPortfolioIsSaved.
  ///
  /// In en, this message translates to:
  /// **'Your portfolio is saved.'**
  String get yourPortfolioIsSaved;

  /// No description provided for @whatMembersSee.
  ///
  /// In en, this message translates to:
  /// **'What members see'**
  String get whatMembersSee;

  /// No description provided for @startFromATemplateThenSetYour.
  ///
  /// In en, this message translates to:
  /// **'Start from a template, then set your own price.'**
  String get startFromATemplateThenSetYour;

  /// No description provided for @addAPackage.
  ///
  /// In en, this message translates to:
  /// **'Add a package'**
  String get addAPackage;

  /// No description provided for @turnOnAtLeastOnePackageTo.
  ///
  /// In en, this message translates to:
  /// **'Turn on at least one package to show your portfolio to members.'**
  String get turnOnAtLeastOnePackageTo;

  /// No description provided for @onForMembers.
  ///
  /// In en, this message translates to:
  /// **'On for members'**
  String get onForMembers;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// A length of time in days.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String countDays(String count);

  /// How many live video sessions a package includes each month.
  ///
  /// In en, this message translates to:
  /// **'{count} live video sessions a month'**
  String countLiveVideoSessionsAMonth(String count);

  /// A length in minutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String countMin(String count);

  /// No description provided for @newPackage.
  ///
  /// In en, this message translates to:
  /// **'New package'**
  String get newPackage;

  /// No description provided for @editPackage.
  ///
  /// In en, this message translates to:
  /// **'Edit package'**
  String get editPackage;

  /// No description provided for @startFromATemplate.
  ///
  /// In en, this message translates to:
  /// **'Start from a template'**
  String get startFromATemplate;

  /// No description provided for @blankPackage.
  ///
  /// In en, this message translates to:
  /// **'Blank package'**
  String get blankPackage;

  /// No description provided for @fourWeeksBuiltAroundYouAPlan.
  ///
  /// In en, this message translates to:
  /// **'Four weeks built around you: a plan made for you, live video sessions and a weekly look at your progress.'**
  String get fourWeeksBuiltAroundYouAPlan;

  /// No description provided for @eightWeeksToBuildARoutineThat.
  ///
  /// In en, this message translates to:
  /// **'Eight weeks to build a routine that lasts, with a plan made for you, live video sessions and a weekly look at your progress.'**
  String get eightWeeksToBuildARoutineThat;

  /// No description provided for @twelveWeeksForARealChangeWith.
  ///
  /// In en, this message translates to:
  /// **'Twelve weeks for a real change, with a plan made for you, live video sessions and a weekly look at your progress.'**
  String get twelveWeeksForARealChangeWith;

  /// No description provided for @aWorkoutPlanMadeForYou.
  ///
  /// In en, this message translates to:
  /// **'A workout plan made for you'**
  String get aWorkoutPlanMadeForYou;

  /// No description provided for @liveVideoSessionsWithMe.
  ///
  /// In en, this message translates to:
  /// **'Live video sessions with me'**
  String get liveVideoSessionsWithMe;

  /// No description provided for @aWeeklyLookAtYourProgress.
  ///
  /// In en, this message translates to:
  /// **'A weekly look at your progress'**
  String get aWeeklyLookAtYourProgress;

  /// No description provided for @aPlanThatChangesAsYouDo.
  ///
  /// In en, this message translates to:
  /// **'A plan that changes as you do'**
  String get aPlanThatChangesAsYouDo;

  /// No description provided for @packageName.
  ///
  /// In en, this message translates to:
  /// **'Package name'**
  String get packageName;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @length.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get length;

  /// No description provided for @removeThisLine.
  ///
  /// In en, this message translates to:
  /// **'Remove this line'**
  String get removeThisLine;

  /// No description provided for @liveSessionsAMonth.
  ///
  /// In en, this message translates to:
  /// **'Live sessions a month'**
  String get liveSessionsAMonth;

  /// No description provided for @progressReviewsAWeek.
  ///
  /// In en, this message translates to:
  /// **'Progress reviews a week'**
  String get progressReviewsAWeek;

  /// No description provided for @yourPriceEgp.
  ///
  /// In en, this message translates to:
  /// **'Your price (EGP)'**
  String get yourPriceEgp;

  /// Hint under the price field.
  ///
  /// In en, this message translates to:
  /// **'Whole pounds, from {low} to {high}.'**
  String wholePoundsFromLowToHigh(String low, String high);

  /// No description provided for @showThisPackageToMembers.
  ///
  /// In en, this message translates to:
  /// **'Show this package to members'**
  String get showThisPackageToMembers;

  /// No description provided for @positionInYourList.
  ///
  /// In en, this message translates to:
  /// **'Position in your list'**
  String get positionInYourList;

  /// No description provided for @savePackage.
  ///
  /// In en, this message translates to:
  /// **'Save package'**
  String get savePackage;

  /// Shown after a package is saved: what the coach receives, in whole pounds.
  ///
  /// In en, this message translates to:
  /// **'Saved. You receive EGP {amount}.'**
  String savedYouReceiveEgpAmount(String amount);

  /// No description provided for @howMembersSeeIt.
  ///
  /// In en, this message translates to:
  /// **'How members see it'**
  String get howMembersSeeIt;

  /// Rule for the list of what a package includes.
  ///
  /// In en, this message translates to:
  /// **'Add 1 to {max} lines, each {low} to {high} characters.'**
  String add1ToMaxLinesEachLow(String max, String low, String high);

  /// No description provided for @less.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get less;

  /// No description provided for @yourApplication.
  ///
  /// In en, this message translates to:
  /// **'Your application'**
  String get yourApplication;

  /// No description provided for @specialties.
  ///
  /// In en, this message translates to:
  /// **'Specialties'**
  String get specialties;

  /// No description provided for @clientFeedback.
  ///
  /// In en, this message translates to:
  /// **'Client feedback'**
  String get clientFeedback;

  /// No description provided for @beforeAndAfterStories.
  ///
  /// In en, this message translates to:
  /// **'Before and after stories'**
  String get beforeAndAfterStories;

  /// No description provided for @returnAfterBirth.
  ///
  /// In en, this message translates to:
  /// **'Return after birth'**
  String get returnAfterBirth;

  /// No description provided for @membersCanAskToJoinYourPackages.
  ///
  /// In en, this message translates to:
  /// **'Members can ask to join your packages. Coaching is free until Own Hub opens payments.'**
  String get membersCanAskToJoinYourPackages;

  /// No description provided for @whenThisIsOnARequestGoes.
  ///
  /// In en, this message translates to:
  /// **'When this is on, a request goes straight through while you have room. When it is off, you answer each request yourself.'**
  String get whenThisIsOnARequestGoes;

  /// Explains the most-clients setting.
  ///
  /// In en, this message translates to:
  /// **'New requests wait once you reach {count} clients at once.'**
  String newRequestsWaitOnceYouReachCount(String count);

  /// No description provided for @fewer.
  ///
  /// In en, this message translates to:
  /// **'Fewer'**
  String get fewer;

  /// The price a member pays for a package, in whole Egyptian pounds.
  ///
  /// In en, this message translates to:
  /// **'Members see EGP {price}'**
  String membersSeeEgpPrice(String price);

  /// No description provided for @askToJoin.
  ///
  /// In en, this message translates to:
  /// **'Ask to join'**
  String get askToJoin;

  /// No description provided for @requestsChatsAndClientsInOnePlace.
  ///
  /// In en, this message translates to:
  /// **'Requests, chats and clients in one place'**
  String get requestsChatsAndClientsInOnePlace;

  /// Requests from members waiting for the coach.
  ///
  /// In en, this message translates to:
  /// **'{count} new requests'**
  String countNewRequests(String count);

  /// Chats with something the coach has not read.
  ///
  /// In en, this message translates to:
  /// **'{count} unread chats'**
  String countUnreadChats(String count);

  /// Clients being coached now.
  ///
  /// In en, this message translates to:
  /// **'{count} clients'**
  String countClients(String count);

  /// No description provided for @freeWhileOwnHubOpensCoaching.
  ///
  /// In en, this message translates to:
  /// **'Free while Own Hub opens coaching'**
  String get freeWhileOwnHubOpensCoaching;

  /// Joining a coach.
  ///
  /// In en, this message translates to:
  /// **'Tell {name} about you'**
  String tellNameAboutYou(String name);

  /// No description provided for @yourLevel.
  ///
  /// In en, this message translates to:
  /// **'Your level'**
  String get yourLevel;

  /// No description provided for @daysAWeekYouCanTrain.
  ///
  /// In en, this message translates to:
  /// **'Days a week you can train'**
  String get daysAWeekYouCanTrain;

  /// No description provided for @allergiesFromYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Allergies from your profile'**
  String get allergiesFromYourProfile;

  /// No description provided for @tapOneToTakeItOffThe.
  ///
  /// In en, this message translates to:
  /// **'Tap one to take it off the list.'**
  String get tapOneToTakeItOffThe;

  /// No description provided for @aFewQuestionsAboutYourHealth.
  ///
  /// In en, this message translates to:
  /// **'A few questions about your health'**
  String get aFewQuestionsAboutYourHealth;

  /// No description provided for @answerEachOneWithYesOrNo.
  ///
  /// In en, this message translates to:
  /// **'Answer each one with yes or no.'**
  String get answerEachOneWithYesOrNo;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @hasADoctorEverSaidYouHave.
  ///
  /// In en, this message translates to:
  /// **'Has a doctor ever said you have a heart condition?'**
  String get hasADoctorEverSaidYouHave;

  /// No description provided for @doYouFeelPainInYourChest.
  ///
  /// In en, this message translates to:
  /// **'Do you feel pain in your chest when you exercise?'**
  String get doYouFeelPainInYourChest;

  /// No description provided for @doYouFeelDizzyOrFaintWhen.
  ///
  /// In en, this message translates to:
  /// **'Do you feel dizzy or faint when you exercise?'**
  String get doYouFeelDizzyOrFaintWhen;

  /// No description provided for @doYouHaveALongTermCondition.
  ///
  /// In en, this message translates to:
  /// **'Do you have a long-term condition, such as diabetes or high blood pressure?'**
  String get doYouHaveALongTermCondition;

  /// No description provided for @doYouTakeMedicationEveryDay.
  ///
  /// In en, this message translates to:
  /// **'Do you take medication every day?'**
  String get doYouTakeMedicationEveryDay;

  /// No description provided for @doYouHaveABoneOrJoint.
  ///
  /// In en, this message translates to:
  /// **'Do you have a bone or joint problem that exercise could make worse?'**
  String get doYouHaveABoneOrJoint;

  /// No description provided for @hasADoctorToldYouToExercise.
  ///
  /// In en, this message translates to:
  /// **'Has a doctor told you to exercise only under supervision?'**
  String get hasADoctorToldYouToExercise;

  /// No description provided for @iWillCheckWithMyDoctorBefore.
  ///
  /// In en, this message translates to:
  /// **'I will check with my doctor before I start'**
  String get iWillCheckWithMyDoctorBefore;

  /// No description provided for @yourCoachWillReadYourAnswersBefore.
  ///
  /// In en, this message translates to:
  /// **'Your coach will read your answers before she accepts.'**
  String get yourCoachWillReadYourAnswersBefore;

  /// No description provided for @aNoteForTheCoachOptional.
  ///
  /// In en, this message translates to:
  /// **'A note for the coach (optional)'**
  String get aNoteForTheCoachOptional;

  /// Joining a coach.
  ///
  /// In en, this message translates to:
  /// **'I share these answers with {name}, my coach.'**
  String iShareTheseAnswersWithNameMy(String name);

  /// No description provided for @sendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get sendRequest;

  /// No description provided for @answerEveryQuestionAndTickTheBoxes.
  ///
  /// In en, this message translates to:
  /// **'Answer every question and tick the boxes at the end.'**
  String get answerEveryQuestionAndTickTheBoxes;

  /// No description provided for @requestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get requestSent;

  /// Joining a coach.
  ///
  /// In en, this message translates to:
  /// **'{name} usually replies within {hours} hours'**
  String nameUsuallyRepliesWithinHoursHours(String name, int hours);

  /// Joining a coach.
  ///
  /// In en, this message translates to:
  /// **'{name} will get back to you soon.'**
  String nameWillGetBackToYouSoon(String name);

  /// No description provided for @youAlreadyAskedToJoinThisCoach.
  ///
  /// In en, this message translates to:
  /// **'You already asked to join this coach.'**
  String get youAlreadyAskedToJoinThisCoach;

  /// No description provided for @thisCoachIsNotTakingNewClients.
  ///
  /// In en, this message translates to:
  /// **'This coach is not taking new clients right now.'**
  String get thisCoachIsNotTakingNewClients;

  /// No description provided for @weCouldNotSendYourRequestTry.
  ///
  /// In en, this message translates to:
  /// **'We could not send your request. Try again.'**
  String get weCouldNotSendYourRequestTry;

  /// No description provided for @coachWomenOnOwnHub.
  ///
  /// In en, this message translates to:
  /// **'Coach women on Own Hub'**
  String get coachWomenOnOwnHub;

  /// No description provided for @applyToJoinAsACoachOwn.
  ///
  /// In en, this message translates to:
  /// **'Apply to join as a coach. Own Hub\'s reviewer reads every application, and approved coaches get a page that members can find.'**
  String get applyToJoinAsACoachOwn;

  /// No description provided for @whatYouWillNeed.
  ///
  /// In en, this message translates to:
  /// **'What you will need'**
  String get whatYouWillNeed;

  /// No description provided for @aClearPhotoOfYou.
  ///
  /// In en, this message translates to:
  /// **'A clear photo of you'**
  String get aClearPhotoOfYou;

  /// No description provided for @photosOfYourDegreeAndCertificates.
  ///
  /// In en, this message translates to:
  /// **'Photos of your degree and certificates'**
  String get photosOfYourDegreeAndCertificates;

  /// No description provided for @twoMessagesFromWomenYouTrained.
  ///
  /// In en, this message translates to:
  /// **'Two messages from women you trained'**
  String get twoMessagesFromWomenYouTrained;

  /// No description provided for @aClientTransformationWithHerWrittenConsent.
  ///
  /// In en, this message translates to:
  /// **'A client transformation, with her written consent'**
  String get aClientTransformationWithHerWrittenConsent;

  /// No description provided for @ownHubIsForWomenOnlyOnly.
  ///
  /// In en, this message translates to:
  /// **'Own Hub is for women only. Only verified women can apply, and every client is a woman.'**
  String get ownHubIsForWomenOnlyOnly;

  /// No description provided for @continueMyApplication.
  ///
  /// In en, this message translates to:
  /// **'Continue my application'**
  String get continueMyApplication;

  /// No description provided for @verifyThatYouAreAWomanFirst.
  ///
  /// In en, this message translates to:
  /// **'Verify that you are a woman first'**
  String get verifyThatYouAreAWomanFirst;

  /// No description provided for @applyingNeedsAVerifiedAccountVerificationTakes.
  ///
  /// In en, this message translates to:
  /// **'Applying needs a verified account. Verification takes a few minutes.'**
  String get applyingNeedsAVerifiedAccountVerificationTakes;

  /// No description provided for @verifyMyAccount.
  ///
  /// In en, this message translates to:
  /// **'Verify my account'**
  String get verifyMyAccount;

  /// No description provided for @saveAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Save and continue'**
  String get saveAndContinue;

  /// No description provided for @yourAnswersAreSavedOnThisPhone.
  ///
  /// In en, this message translates to:
  /// **'Your answers are saved on this phone after every step.'**
  String get yourAnswersAreSavedOnThisPhone;

  /// No description provided for @thisIsNeeded.
  ///
  /// In en, this message translates to:
  /// **'This is needed'**
  String get thisIsNeeded;

  /// A text field is too short.
  ///
  /// In en, this message translates to:
  /// **'Use at least {min} characters'**
  String useAtLeastMinCharacters(String min);

  /// A text field is too long.
  ///
  /// In en, this message translates to:
  /// **'Use at most {max} characters'**
  String useAtMostMaxCharacters(String max);

  /// Helper under a text field.
  ///
  /// In en, this message translates to:
  /// **'{min} to {max} characters'**
  String minToMaxCharacters(String min, String max);

  /// Year field out of range.
  ///
  /// In en, this message translates to:
  /// **'Enter a year from {from} to {to}'**
  String enterAYearFromFromToTo(String from, String to);

  /// Number field out of range.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number from {min} to {max}'**
  String enterAWholeNumberFromMinTo(String min, String max);

  /// A list needs more rows.
  ///
  /// In en, this message translates to:
  /// **'Add at least {min}'**
  String addAtLeastMin(String min);

  /// A chip group needs a count in range.
  ///
  /// In en, this message translates to:
  /// **'Choose between {min} and {max}'**
  String chooseBetweenMinAndMax(String min, String max);

  /// No description provided for @tickThisToContinue.
  ///
  /// In en, this message translates to:
  /// **'Tick this to continue'**
  String get tickThisToContinue;

  /// No description provided for @chooseADifferentOne.
  ///
  /// In en, this message translates to:
  /// **'Choose a different one'**
  String get chooseADifferentOne;

  /// No description provided for @membersSeeYourDisplayNameHeadlineAnd.
  ///
  /// In en, this message translates to:
  /// **'Members see your display name, headline and photo. Your full name is for the review only and is never shown.'**
  String get membersSeeYourDisplayNameHeadlineAnd;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @forTheReviewOnlyNeverShownPublicly.
  ///
  /// In en, this message translates to:
  /// **'For the review only. Never shown publicly.'**
  String get forTheReviewOnlyNeverShownPublicly;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @governorate.
  ///
  /// In en, this message translates to:
  /// **'Governorate'**
  String get governorate;

  /// No description provided for @languagesYouCoachIn.
  ///
  /// In en, this message translates to:
  /// **'Languages you coach in'**
  String get languagesYouCoachIn;

  /// No description provided for @arabicLanguage.
  ///
  /// In en, this message translates to:
  /// **'Arabic language'**
  String get arabicLanguage;

  /// No description provided for @englishLanguage.
  ///
  /// In en, this message translates to:
  /// **'English language'**
  String get englishLanguage;

  /// No description provided for @photoAdded.
  ///
  /// In en, this message translates to:
  /// **'Photo added'**
  String get photoAdded;

  /// No description provided for @theCameraIsBlockedAllowItIn.
  ///
  /// In en, this message translates to:
  /// **'The camera is blocked. Allow it in Settings or choose a photo.'**
  String get theCameraIsBlockedAllowItIn;

  /// No description provided for @yourEducation.
  ///
  /// In en, this message translates to:
  /// **'Your education'**
  String get yourEducation;

  /// No description provided for @degreeOrCourse.
  ///
  /// In en, this message translates to:
  /// **'Degree or course'**
  String get degreeOrCourse;

  /// No description provided for @institution.
  ///
  /// In en, this message translates to:
  /// **'Institution'**
  String get institution;

  /// No description provided for @year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// No description provided for @addEducation.
  ///
  /// In en, this message translates to:
  /// **'Add education'**
  String get addEducation;

  /// Row title.
  ///
  /// In en, this message translates to:
  /// **'Education {n}'**
  String educationN(String n);

  /// No description provided for @proofPhotoOptional.
  ///
  /// In en, this message translates to:
  /// **'Proof photo, optional'**
  String get proofPhotoOptional;

  /// No description provided for @yourCertificates.
  ///
  /// In en, this message translates to:
  /// **'Your certificates'**
  String get yourCertificates;

  /// No description provided for @certificateTitle.
  ///
  /// In en, this message translates to:
  /// **'Certificate title'**
  String get certificateTitle;

  /// No description provided for @issuedBy.
  ///
  /// In en, this message translates to:
  /// **'Issued by'**
  String get issuedBy;

  /// No description provided for @addACertificate.
  ///
  /// In en, this message translates to:
  /// **'Add a certificate'**
  String get addACertificate;

  /// Row title.
  ///
  /// In en, this message translates to:
  /// **'Certificate {n}'**
  String certificateN(String n);

  /// No description provided for @certificatePhoto.
  ///
  /// In en, this message translates to:
  /// **'Certificate photo'**
  String get certificatePhoto;

  /// No description provided for @yourSpecialties.
  ///
  /// In en, this message translates to:
  /// **'Your specialties'**
  String get yourSpecialties;

  /// No description provided for @yearsOfExperience.
  ///
  /// In en, this message translates to:
  /// **'Years of experience'**
  String get yearsOfExperience;

  /// No description provided for @yourQualifications.
  ///
  /// In en, this message translates to:
  /// **'Your qualifications'**
  String get yourQualifications;

  /// No description provided for @whatYouStudiedAndTrainedIn.
  ///
  /// In en, this message translates to:
  /// **'What you studied and trained in.'**
  String get whatYouStudiedAndTrainedIn;

  /// No description provided for @feedbackFromClients.
  ///
  /// In en, this message translates to:
  /// **'Feedback from clients'**
  String get feedbackFromClients;

  /// No description provided for @screenshotsAreSeenOnlyByOwnHubs.
  ///
  /// In en, this message translates to:
  /// **'Screenshots are seen only by Own Hub\'s woman reviewer.'**
  String get screenshotsAreSeenOnlyByOwnHubs;

  /// No description provided for @whatSheSaid.
  ///
  /// In en, this message translates to:
  /// **'What she said'**
  String get whatSheSaid;

  /// No description provided for @herFirstName.
  ///
  /// In en, this message translates to:
  /// **'Her first name'**
  String get herFirstName;

  /// No description provided for @whereItCameFrom.
  ///
  /// In en, this message translates to:
  /// **'Where it came from'**
  String get whereItCameFrom;

  /// No description provided for @whatsapp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get whatsapp;

  /// No description provided for @instagram.
  ///
  /// In en, this message translates to:
  /// **'Instagram'**
  String get instagram;

  /// No description provided for @somewhereElse.
  ///
  /// In en, this message translates to:
  /// **'Somewhere else'**
  String get somewhereElse;

  /// No description provided for @screenshotOptional.
  ///
  /// In en, this message translates to:
  /// **'Screenshot, optional'**
  String get screenshotOptional;

  /// No description provided for @addFeedback.
  ///
  /// In en, this message translates to:
  /// **'Add feedback'**
  String get addFeedback;

  /// Row title.
  ///
  /// In en, this message translates to:
  /// **'Feedback {n}'**
  String feedbackN(String n);

  /// No description provided for @clientTransformations.
  ///
  /// In en, this message translates to:
  /// **'Client transformations'**
  String get clientTransformations;

  /// No description provided for @beforePhoto.
  ///
  /// In en, this message translates to:
  /// **'Before photo'**
  String get beforePhoto;

  /// No description provided for @afterPhoto.
  ///
  /// In en, this message translates to:
  /// **'After photo'**
  String get afterPhoto;

  /// No description provided for @weeksItTook.
  ///
  /// In en, this message translates to:
  /// **'Weeks it took'**
  String get weeksItTook;

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note, optional'**
  String get noteOptional;

  /// No description provided for @myClientAgreedInWritingThatOwn.
  ///
  /// In en, this message translates to:
  /// **'My client agreed in writing that Own Hub\'s reviewer may see these photos'**
  String get myClientAgreedInWritingThatOwn;

  /// No description provided for @addATransformation.
  ///
  /// In en, this message translates to:
  /// **'Add a transformation'**
  String get addATransformation;

  /// Row title.
  ///
  /// In en, this message translates to:
  /// **'Transformation {n}'**
  String transformationN(String n);

  /// No description provided for @yourApproach.
  ///
  /// In en, this message translates to:
  /// **'Your approach'**
  String get yourApproach;

  /// No description provided for @followUpsWithEachClientPerWeek.
  ///
  /// In en, this message translates to:
  /// **'Follow-ups with each client per week'**
  String get followUpsWithEachClientPerWeek;

  /// No description provided for @howFastYouReply.
  ///
  /// In en, this message translates to:
  /// **'How fast you reply'**
  String get howFastYouReply;

  /// Reply time chip.
  ///
  /// In en, this message translates to:
  /// **'Within {hours} hours'**
  String withinHoursHours(String hours);

  /// No description provided for @whereYouTrainClients.
  ///
  /// In en, this message translates to:
  /// **'Where you train clients'**
  String get whereYouTrainClients;

  /// No description provided for @inAGym.
  ///
  /// In en, this message translates to:
  /// **'In a gym'**
  String get inAGym;

  /// No description provided for @coachTerms.
  ///
  /// In en, this message translates to:
  /// **'Coach terms'**
  String get coachTerms;

  /// No description provided for @readThesePointsThenTickTheThree.
  ///
  /// In en, this message translates to:
  /// **'Read these points, then tick the three rules.'**
  String get readThesePointsThenTickTheThree;

  /// No description provided for @ownHubReviewsEveryCoachBeforeShe.
  ///
  /// In en, this message translates to:
  /// **'Own Hub reviews every coach before she is listed.'**
  String get ownHubReviewsEveryCoachBeforeShe;

  /// No description provided for @everythingYouTellUsMustBeAccurate.
  ///
  /// In en, this message translates to:
  /// **'Everything you tell us must be accurate.'**
  String get everythingYouTellUsMustBeAccurate;

  /// No description provided for @photosOfClientsAreSharedOnlyWith.
  ///
  /// In en, this message translates to:
  /// **'Photos of clients are shared only with their written consent.'**
  String get photosOfClientsAreSharedOnlyWith;

  /// No description provided for @clientsPayThroughOwnHubOnlyNever.
  ///
  /// In en, this message translates to:
  /// **'Clients pay through Own Hub only, never outside it.'**
  String get clientsPayThroughOwnHubOnlyNever;

  /// No description provided for @youCanWithdrawYourApplicationAtAny.
  ///
  /// In en, this message translates to:
  /// **'You can withdraw your application at any time.'**
  String get youCanWithdrawYourApplicationAtAny;

  /// No description provided for @readTheFullCoachTerms.
  ///
  /// In en, this message translates to:
  /// **'Read the full coach terms'**
  String get readTheFullCoachTerms;

  /// No description provided for @everythingIWroteIsAccurate.
  ///
  /// In en, this message translates to:
  /// **'Everything I wrote is accurate'**
  String get everythingIWroteIsAccurate;

  /// No description provided for @iShareClientPhotosOnlyWithTheir.
  ///
  /// In en, this message translates to:
  /// **'I share client photos only with their written consent'**
  String get iShareClientPhotosOnlyWithTheir;

  /// No description provided for @iWillNotTakePaymentFromClients.
  ///
  /// In en, this message translates to:
  /// **'I will not take payment from clients outside Own Hub'**
  String get iWillNotTakePaymentFromClients;

  /// No description provided for @reviewYourApplication.
  ///
  /// In en, this message translates to:
  /// **'Review your application'**
  String get reviewYourApplication;

  /// No description provided for @lookOverEachPartYouCanEdit.
  ///
  /// In en, this message translates to:
  /// **'Look over each part. You can edit any of it before you send.'**
  String get lookOverEachPartYouCanEdit;

  /// No description provided for @stillNeeded.
  ///
  /// In en, this message translates to:
  /// **'Still needed'**
  String get stillNeeded;

  /// No description provided for @complete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get complete;

  /// No description provided for @sendMyApplication.
  ///
  /// In en, this message translates to:
  /// **'Send my application'**
  String get sendMyApplication;

  /// No description provided for @sendingYourApplication.
  ///
  /// In en, this message translates to:
  /// **'Sending your application'**
  String get sendingYourApplication;

  /// Send progress.
  ///
  /// In en, this message translates to:
  /// **'Uploading photo {done} of {total}'**
  String uploadingPhotoDoneOfTotal(String done, String total);

  /// No description provided for @applicationSent.
  ///
  /// In en, this message translates to:
  /// **'Application sent'**
  String get applicationSent;

  /// No description provided for @onlyVerifiedWomenCanApplyVerifyYour.
  ///
  /// In en, this message translates to:
  /// **'Only verified women can apply. Verify your account first.'**
  String get onlyVerifiedWomenCanApplyVerifyYour;

  /// No description provided for @youAlreadyHaveAnApplicationWaitingFor.
  ///
  /// In en, this message translates to:
  /// **'You already have an application waiting for review.'**
  String get youAlreadyHaveAnApplicationWaitingFor;

  /// No description provided for @somethingIsStillMissingLookAtThe.
  ///
  /// In en, this message translates to:
  /// **'Something is still missing. Look at the parts marked below.'**
  String get somethingIsStillMissingLookAtThe;

  /// No description provided for @aPhotoDidNotReachUsTry.
  ///
  /// In en, this message translates to:
  /// **'A photo did not reach us. Try sending again.'**
  String get aPhotoDidNotReachUsTry;

  /// No description provided for @youAreAlreadyACoachOnOwn.
  ///
  /// In en, this message translates to:
  /// **'You are already a coach on Own Hub.'**
  String get youAreAlreadyACoachOnOwn;

  /// No description provided for @coachApplicationsAreClosedForNowTry.
  ///
  /// In en, this message translates to:
  /// **'Coach applications are closed for now. Try again later.'**
  String get coachApplicationsAreClosedForNowTry;

  /// No description provided for @yourCoachAccountIsPausedContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Your coach account is paused. Contact support.'**
  String get yourCoachAccountIsPausedContactSupport;

  /// No description provided for @someOfYourAnswersWereNotAccepted.
  ///
  /// In en, this message translates to:
  /// **'Some of your answers were not accepted. Check each part and try again.'**
  String get someOfYourAnswersWereNotAccepted;

  /// No description provided for @noConnectionYourAnswersAreSavedSo.
  ///
  /// In en, this message translates to:
  /// **'No connection. Your answers are saved, so try again when you are online.'**
  String get noConnectionYourAnswersAreSavedSo;

  /// No description provided for @signInToSendYourApplication.
  ///
  /// In en, this message translates to:
  /// **'Sign in to send your application.'**
  String get signInToSendYourApplication;

  /// No description provided for @somethingWentWrongYourAnswersAreSaved.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Your answers are saved. Try again.'**
  String get somethingWentWrongYourAnswersAreSaved;

  /// No description provided for @weHaveYourApplication.
  ///
  /// In en, this message translates to:
  /// **'We have your application'**
  String get weHaveYourApplication;

  /// No description provided for @whatHappensNext.
  ///
  /// In en, this message translates to:
  /// **'What happens next'**
  String get whatHappensNext;

  /// No description provided for @aWomanReviewerReadsEachPart.
  ///
  /// In en, this message translates to:
  /// **'A woman reviewer reads each part.'**
  String get aWomanReviewerReadsEachPart;

  /// No description provided for @sheMayAskYouToChangeSomething.
  ///
  /// In en, this message translates to:
  /// **'She may ask you to change something.'**
  String get sheMayAskYouToChangeSomething;

  /// No description provided for @whenYouAreApprovedYourCoachSpace.
  ///
  /// In en, this message translates to:
  /// **'When you are approved, your coach space opens.'**
  String get whenYouAreApprovedYourCoachSpace;

  /// No description provided for @aFewChangesPlease.
  ///
  /// In en, this message translates to:
  /// **'A few changes, please'**
  String get aFewChangesPlease;

  /// No description provided for @theReviewerAskedYouToUpdateThese.
  ///
  /// In en, this message translates to:
  /// **'The reviewer asked you to update these parts. Your other answers stay as they are.'**
  String get theReviewerAskedYouToUpdateThese;

  /// No description provided for @reviewersNote.
  ///
  /// In en, this message translates to:
  /// **'Reviewer\'s note'**
  String get reviewersNote;

  /// No description provided for @sendAgain.
  ///
  /// In en, this message translates to:
  /// **'Send again'**
  String get sendAgain;

  /// No description provided for @somethingIsMissingHere.
  ///
  /// In en, this message translates to:
  /// **'Something is missing here.'**
  String get somethingIsMissingHere;

  /// No description provided for @thisPartIsNotClearEnough.
  ///
  /// In en, this message translates to:
  /// **'This part is not clear enough.'**
  String get thisPartIsNotClearEnough;

  /// No description provided for @weCouldNotVerifyThis.
  ///
  /// In en, this message translates to:
  /// **'We could not verify this.'**
  String get weCouldNotVerifyThis;

  /// No description provided for @thisIsNotAllowedOnOwnHub.
  ///
  /// In en, this message translates to:
  /// **'This is not allowed on Own Hub.'**
  String get thisIsNotAllowedOnOwnHub;

  /// No description provided for @pleaseLookAtThisPartAgain.
  ///
  /// In en, this message translates to:
  /// **'Please look at this part again.'**
  String get pleaseLookAtThisPartAgain;

  /// No description provided for @notApprovedThisTime.
  ///
  /// In en, this message translates to:
  /// **'Not approved this time'**
  String get notApprovedThisTime;

  /// No description provided for @theReviewerCouldNotApproveThisApplication.
  ///
  /// In en, this message translates to:
  /// **'The reviewer could not approve this application.'**
  String get theReviewerCouldNotApproveThisApplication;

  /// Rejected application, date already formatted.
  ///
  /// In en, this message translates to:
  /// **'You can apply again on {date}.'**
  String youCanApplyAgainOnDate(String date);

  /// No description provided for @youAreApproved.
  ///
  /// In en, this message translates to:
  /// **'You are approved'**
  String get youAreApproved;

  /// No description provided for @welcomeToOwnHubsCoachesYourCoach.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Own Hub\'s coaches. Your coach space is ready.'**
  String get welcomeToOwnHubsCoachesYourCoach;

  /// No description provided for @openMyCoachSpace.
  ///
  /// In en, this message translates to:
  /// **'Open my coach space'**
  String get openMyCoachSpace;

  /// No description provided for @noApplicationYet.
  ///
  /// In en, this message translates to:
  /// **'No application yet'**
  String get noApplicationYet;

  /// No description provided for @startMyApplication.
  ///
  /// In en, this message translates to:
  /// **'Start my application'**
  String get startMyApplication;

  /// No description provided for @cairo.
  ///
  /// In en, this message translates to:
  /// **'Cairo'**
  String get cairo;

  /// No description provided for @alexandria.
  ///
  /// In en, this message translates to:
  /// **'Alexandria'**
  String get alexandria;

  /// No description provided for @qalyubia.
  ///
  /// In en, this message translates to:
  /// **'Qalyubia'**
  String get qalyubia;

  /// No description provided for @sharqia.
  ///
  /// In en, this message translates to:
  /// **'Sharqia'**
  String get sharqia;

  /// No description provided for @dakahlia.
  ///
  /// In en, this message translates to:
  /// **'Dakahlia'**
  String get dakahlia;

  /// No description provided for @gharbia.
  ///
  /// In en, this message translates to:
  /// **'Gharbia'**
  String get gharbia;

  /// No description provided for @monufia.
  ///
  /// In en, this message translates to:
  /// **'Monufia'**
  String get monufia;

  /// No description provided for @beheira.
  ///
  /// In en, this message translates to:
  /// **'Beheira'**
  String get beheira;

  /// No description provided for @kafrElSheikh.
  ///
  /// In en, this message translates to:
  /// **'Kafr El Sheikh'**
  String get kafrElSheikh;

  /// No description provided for @damietta.
  ///
  /// In en, this message translates to:
  /// **'Damietta'**
  String get damietta;

  /// No description provided for @portSaid.
  ///
  /// In en, this message translates to:
  /// **'Port Said'**
  String get portSaid;

  /// No description provided for @ismailia.
  ///
  /// In en, this message translates to:
  /// **'Ismailia'**
  String get ismailia;

  /// No description provided for @suez.
  ///
  /// In en, this message translates to:
  /// **'Suez'**
  String get suez;

  /// No description provided for @northSinai.
  ///
  /// In en, this message translates to:
  /// **'North Sinai'**
  String get northSinai;

  /// No description provided for @southSinai.
  ///
  /// In en, this message translates to:
  /// **'South Sinai'**
  String get southSinai;

  /// No description provided for @redSea.
  ///
  /// In en, this message translates to:
  /// **'Red Sea'**
  String get redSea;

  /// No description provided for @matrouh.
  ///
  /// In en, this message translates to:
  /// **'Matrouh'**
  String get matrouh;

  /// No description provided for @faiyum.
  ///
  /// In en, this message translates to:
  /// **'Faiyum'**
  String get faiyum;

  /// No description provided for @beniSuef.
  ///
  /// In en, this message translates to:
  /// **'Beni Suef'**
  String get beniSuef;

  /// No description provided for @minya.
  ///
  /// In en, this message translates to:
  /// **'Minya'**
  String get minya;

  /// No description provided for @asyut.
  ///
  /// In en, this message translates to:
  /// **'Asyut'**
  String get asyut;

  /// No description provided for @sohag.
  ///
  /// In en, this message translates to:
  /// **'Sohag'**
  String get sohag;

  /// No description provided for @qena.
  ///
  /// In en, this message translates to:
  /// **'Qena'**
  String get qena;

  /// No description provided for @luxor.
  ///
  /// In en, this message translates to:
  /// **'Luxor'**
  String get luxor;

  /// No description provided for @aswan.
  ///
  /// In en, this message translates to:
  /// **'Aswan'**
  String get aswan;

  /// No description provided for @newValley.
  ///
  /// In en, this message translates to:
  /// **'New Valley'**
  String get newValley;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @searchChats.
  ///
  /// In en, this message translates to:
  /// **'Search chats'**
  String get searchChats;

  /// No description provided for @noChatsYet.
  ///
  /// In en, this message translates to:
  /// **'No chats yet'**
  String get noChatsYet;

  /// No description provided for @yourChatsWithYourCoachOrYour.
  ///
  /// In en, this message translates to:
  /// **'Your chats with your coach or your clients show up here.'**
  String get yourChatsWithYourCoachOrYour;

  /// No description provided for @noChatsMatchYourSearch.
  ///
  /// In en, this message translates to:
  /// **'No chats match your search.'**
  String get noChatsMatchYourSearch;

  /// Chat list preview: the last line was written by her. text is the start of that line.
  ///
  /// In en, this message translates to:
  /// **'You: {text}'**
  String youText(String text);

  /// No description provided for @recipe.
  ///
  /// In en, this message translates to:
  /// **'Recipe'**
  String get recipe;

  /// No description provided for @workoutPlan.
  ///
  /// In en, this message translates to:
  /// **'Workout plan'**
  String get workoutPlan;

  /// No description provided for @mealPlan.
  ///
  /// In en, this message translates to:
  /// **'Meal plan'**
  String get mealPlan;

  /// No description provided for @liveSession.
  ///
  /// In en, this message translates to:
  /// **'Live session'**
  String get liveSession;

  /// No description provided for @messageHidden.
  ///
  /// In en, this message translates to:
  /// **'Message hidden'**
  String get messageHidden;

  /// Spoken label of the unread badge on a chat row. count is a number.
  ///
  /// In en, this message translates to:
  /// **'{count} unread'**
  String countUnread(String count);

  /// No description provided for @yourCoach.
  ///
  /// In en, this message translates to:
  /// **'Your coach'**
  String get yourCoach;

  /// No description provided for @yourClient.
  ///
  /// In en, this message translates to:
  /// **'Your client'**
  String get yourClient;

  /// Chat header line under the other person's name. package is the package name, days a whole number above zero.
  ///
  /// In en, this message translates to:
  /// **'{package} · {days} days left'**
  String packageDaysDaysLeft(String package, String days);

  /// Chat header line on the last day of the coaching. package is the package name.
  ///
  /// In en, this message translates to:
  /// **'{package} · ends today'**
  String packageEndsToday(String package);

  /// No description provided for @shareSomething.
  ///
  /// In en, this message translates to:
  /// **'Share something'**
  String get shareSomething;

  /// No description provided for @shareARecipe.
  ///
  /// In en, this message translates to:
  /// **'Share a recipe'**
  String get shareARecipe;

  /// No description provided for @shareAWorkoutPlan.
  ///
  /// In en, this message translates to:
  /// **'Share a workout plan'**
  String get shareAWorkoutPlan;

  /// No description provided for @shareAMealPlan.
  ///
  /// In en, this message translates to:
  /// **'Share a meal plan'**
  String get shareAMealPlan;

  /// No description provided for @scheduleALiveSession.
  ///
  /// In en, this message translates to:
  /// **'Schedule a live session'**
  String get scheduleALiveSession;

  /// No description provided for @phoneNumbersCantBeSentInThe.
  ///
  /// In en, this message translates to:
  /// **'Phone numbers can\'t be sent in the chat. Your message is still here if you want to change it.'**
  String get phoneNumbersCantBeSentInThe;

  /// No description provided for @paymentDetailsCantBeSharedInThe.
  ///
  /// In en, this message translates to:
  /// **'Payment details can\'t be shared in the chat. Your message is still here if you want to change it.'**
  String get paymentDetailsCantBeSharedInThe;

  /// No description provided for @linksCantBeSentInTheChat.
  ///
  /// In en, this message translates to:
  /// **'Links can\'t be sent in the chat. Your message is still here if you want to change it.'**
  String get linksCantBeSentInTheChat;

  /// No description provided for @someWordsInThisMessageArentAllowed.
  ///
  /// In en, this message translates to:
  /// **'Some words in this message aren\'t allowed here. Your message is still here if you want to change it.'**
  String get someWordsInThisMessageArentAllowed;

  /// No description provided for @yourMessageCouldNotBeSentTry.
  ///
  /// In en, this message translates to:
  /// **'Your message could not be sent. Try again in a moment.'**
  String get yourMessageCouldNotBeSentTry;

  /// No description provided for @newMessages.
  ///
  /// In en, this message translates to:
  /// **'New messages'**
  String get newMessages;

  /// No description provided for @thisCoachingHasEndedYouCanRead.
  ///
  /// In en, this message translates to:
  /// **'This coaching has ended. You can read the chat but not write in it.'**
  String get thisCoachingHasEndedYouCanRead;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @block.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get block;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// Title of the sheet that asks her to confirm blocking the other person in a chat.
  ///
  /// In en, this message translates to:
  /// **'Block {name}?'**
  String blockName(String name);

  /// Body of the block confirmation in a chat. name is the other person.
  ///
  /// In en, this message translates to:
  /// **'{name} cannot write to you after this, and you will not see her messages. You can undo it later.'**
  String nameCannotWriteToYouAfterThis(String name);

  /// Shown once the other person in a chat is blocked.
  ///
  /// In en, this message translates to:
  /// **'{name} is blocked.'**
  String nameIsBlocked(String name);

  /// No description provided for @yourReportIsPrivate.
  ///
  /// In en, this message translates to:
  /// **'Your report is private.'**
  String get yourReportIsPrivate;

  /// No description provided for @reportThisMessage.
  ///
  /// In en, this message translates to:
  /// **'Report this message'**
  String get reportThisMessage;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @thereIsNoMessageFromHerTo.
  ///
  /// In en, this message translates to:
  /// **'There is no message from her to report yet.'**
  String get thereIsNoMessageFromHerTo;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get sending;

  /// No description provided for @sent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get sent;

  /// No description provided for @seen.
  ///
  /// In en, this message translates to:
  /// **'Seen'**
  String get seen;

  /// Length of a live session card in a chat.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String minutesMin(String minutes);

  /// When a live session starts. day is Today, Tomorrow-style or a date; time is hh:mm.
  ///
  /// In en, this message translates to:
  /// **'{day} at {time}'**
  String dayAtTime(String day, String time);

  /// No description provided for @joinTheCall.
  ///
  /// In en, this message translates to:
  /// **'Join the call'**
  String get joinTheCall;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @waitingForConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Waiting for confirmation'**
  String get waitingForConfirmation;

  /// No description provided for @confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get confirmed;

  /// No description provided for @declined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get declined;

  /// No description provided for @coachingStarted.
  ///
  /// In en, this message translates to:
  /// **'Coaching started'**
  String get coachingStarted;

  /// No description provided for @coachingEnded.
  ///
  /// In en, this message translates to:
  /// **'Coaching ended'**
  String get coachingEnded;

  /// No description provided for @coachingEndsSoon.
  ///
  /// In en, this message translates to:
  /// **'Coaching ends soon'**
  String get coachingEndsSoon;

  /// No description provided for @aPlanWasUpdated.
  ///
  /// In en, this message translates to:
  /// **'A plan was updated'**
  String get aPlanWasUpdated;

  /// No description provided for @liveSessionConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Live session confirmed'**
  String get liveSessionConfirmed;

  /// No description provided for @liveSessionFinished.
  ///
  /// In en, this message translates to:
  /// **'Live session finished'**
  String get liveSessionFinished;

  /// No description provided for @weCouldNotLoadThisChatCheck.
  ///
  /// In en, this message translates to:
  /// **'We could not load this chat. Check your connection.'**
  String get weCouldNotLoadThisChatCheck;

  /// No description provided for @noMessagesYetSayHello.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Say hello.'**
  String get noMessagesYetSayHello;

  /// No description provided for @loadingOlderMessages.
  ///
  /// In en, this message translates to:
  /// **'Loading older messages'**
  String get loadingOlderMessages;

  /// No description provided for @coachDesk.
  ///
  /// In en, this message translates to:
  /// **'Coach desk'**
  String get coachDesk;

  /// No description provided for @newRequests.
  ///
  /// In en, this message translates to:
  /// **'New requests'**
  String get newRequests;

  /// No description provided for @unreadChats.
  ///
  /// In en, this message translates to:
  /// **'Unread chats'**
  String get unreadChats;

  /// No description provided for @toFollowUp.
  ///
  /// In en, this message translates to:
  /// **'To follow up'**
  String get toFollowUp;

  /// No description provided for @activeClients.
  ///
  /// In en, this message translates to:
  /// **'Active clients'**
  String get activeClients;

  /// No description provided for @followUp_n22yh.
  ///
  /// In en, this message translates to:
  /// **'Follow up'**
  String get followUp_n22yh;

  /// Coach desk
  ///
  /// In en, this message translates to:
  /// **'Show all {count}'**
  String showAllCount(String count);

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @whyAreYouDeclining.
  ///
  /// In en, this message translates to:
  /// **'Why are you declining?'**
  String get whyAreYouDeclining;

  /// No description provided for @myPlacesAreFull.
  ///
  /// In en, this message translates to:
  /// **'My places are full'**
  String get myPlacesAreFull;

  /// No description provided for @notTheRightFit.
  ///
  /// In en, this message translates to:
  /// **'Not the right fit'**
  String get notTheRightFit;

  /// No description provided for @sheShouldSeeHerDoctorFirst.
  ///
  /// In en, this message translates to:
  /// **'She should see her doctor first'**
  String get sheShouldSeeHerDoctorFirst;

  /// No description provided for @requestAccepted.
  ///
  /// In en, this message translates to:
  /// **'Request accepted'**
  String get requestAccepted;

  /// No description provided for @requestDeclined.
  ///
  /// In en, this message translates to:
  /// **'Request declined'**
  String get requestDeclined;

  /// Coach desk
  ///
  /// In en, this message translates to:
  /// **'{name} asked to join'**
  String nameAskedToJoin(String name);

  /// No description provided for @healthAnswersToReadFirst.
  ///
  /// In en, this message translates to:
  /// **'Health answers to read first'**
  String get healthAnswersToReadFirst;

  /// Coach desk
  ///
  /// In en, this message translates to:
  /// **'{goal} · {level} · {days} days a week · {place}'**
  String goalLevelDaysDaysAWeekPlace(
    String goal,
    String level,
    String days,
    String place,
  );

  /// Coach desk
  ///
  /// In en, this message translates to:
  /// **'Client {tag}'**
  String clientTag(String tag);

  /// Coach desk
  ///
  /// In en, this message translates to:
  /// **'Live session today at {time}'**
  String liveSessionTodayAtTime(String time);

  /// Coach desk
  ///
  /// In en, this message translates to:
  /// **'No message for {days} days'**
  String noMessageForDaysDays(String days);

  /// No description provided for @endsToday.
  ///
  /// In en, this message translates to:
  /// **'Ends today'**
  String get endsToday;

  /// Coach desk
  ///
  /// In en, this message translates to:
  /// **'{days} days left'**
  String daysDaysLeft(String days);

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @shareYourPortfolioLinkSoMembersCan.
  ///
  /// In en, this message translates to:
  /// **'Share your portfolio link so members can ask to join.'**
  String get shareYourPortfolioLinkSoMembersCan;

  /// No description provided for @youAreAllCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'You are all caught up'**
  String get youAreAllCaughtUp;

  /// No description provided for @nothingToAnswerOrFollowUpRight.
  ///
  /// In en, this message translates to:
  /// **'Nothing to answer or follow up right now.'**
  String get nothingToAnswerOrFollowUpRight;

  /// No description provided for @searchClients.
  ///
  /// In en, this message translates to:
  /// **'Search clients'**
  String get searchClients;

  /// No description provided for @nobodyMatchesThatSearch.
  ///
  /// In en, this message translates to:
  /// **'Nobody matches that search.'**
  String get nobodyMatchesThatSearch;

  /// No description provided for @noUnreadChatsRightNow.
  ///
  /// In en, this message translates to:
  /// **'No unread chats right now.'**
  String get noUnreadChatsRightNow;

  /// No description provided for @nobodyNeedsAFollowUpRightNow.
  ///
  /// In en, this message translates to:
  /// **'Nobody needs a follow up right now.'**
  String get nobodyNeedsAFollowUpRightNow;

  /// No description provided for @nobodyIsEndingSoon.
  ///
  /// In en, this message translates to:
  /// **'Nobody is ending soon.'**
  String get nobodyIsEndingSoon;

  /// No description provided for @endingSoon.
  ///
  /// In en, this message translates to:
  /// **'Ending soon'**
  String get endingSoon;

  /// Coach desk
  ///
  /// In en, this message translates to:
  /// **'Open the details of {name}'**
  String openTheDetailsOfName(String name);

  /// Coach desk
  ///
  /// In en, this message translates to:
  /// **'Open the chat with {name}'**
  String openTheChatWithName(String name);

  /// No description provided for @clientDetails.
  ///
  /// In en, this message translates to:
  /// **'Client details'**
  String get clientDetails;

  /// No description provided for @started.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get started;

  /// No description provided for @daysLeft.
  ///
  /// In en, this message translates to:
  /// **'Days left'**
  String get daysLeft;

  /// No description provided for @liveSessionsHeld.
  ///
  /// In en, this message translates to:
  /// **'Live sessions held'**
  String get liveSessionsHeld;

  /// Coach desk
  ///
  /// In en, this message translates to:
  /// **'{used} of {included}'**
  String usedOfIncluded(String used, String included);

  /// No description provided for @herAnswers.
  ///
  /// In en, this message translates to:
  /// **'Her answers'**
  String get herAnswers;

  /// No description provided for @sharedWithYouWhileYouCoachHer.
  ///
  /// In en, this message translates to:
  /// **'Shared with you while you coach her'**
  String get sharedWithYouWhileYouCoachHer;

  /// No description provided for @place.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get place;

  /// No description provided for @allergies.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get allergies;

  /// No description provided for @lifeStage.
  ///
  /// In en, this message translates to:
  /// **'Life stage'**
  String get lifeStage;

  /// No description provided for @healthQuestions.
  ///
  /// In en, this message translates to:
  /// **'Health questions'**
  String get healthQuestions;

  /// No description provided for @sheTickedThatSheWillCheckWith.
  ///
  /// In en, this message translates to:
  /// **'She ticked that she will check with her doctor'**
  String get sheTickedThatSheWillCheckWith;

  /// No description provided for @noHealthFlagsInHerAnswers.
  ///
  /// In en, this message translates to:
  /// **'No health flags in her answers'**
  String get noHealthFlagsInHerAnswers;

  /// No description provided for @yourPrivateNote.
  ///
  /// In en, this message translates to:
  /// **'Your private note'**
  String get yourPrivateNote;

  /// No description provided for @staysOnThisPhoneOnlySheNever.
  ///
  /// In en, this message translates to:
  /// **'Stays on this phone only. She never sees it and it is never synced.'**
  String get staysOnThisPhoneOnlySheNever;

  /// No description provided for @writeWhatYouWantToRemember.
  ///
  /// In en, this message translates to:
  /// **'Write what you want to remember'**
  String get writeWhatYouWantToRemember;

  /// No description provided for @saveNote.
  ///
  /// In en, this message translates to:
  /// **'Save note'**
  String get saveNote;

  /// No description provided for @noteSaved.
  ///
  /// In en, this message translates to:
  /// **'Note saved'**
  String get noteSaved;

  /// No description provided for @plansYouShared.
  ///
  /// In en, this message translates to:
  /// **'Plans you shared'**
  String get plansYouShared;

  /// No description provided for @nothingSharedYetShareAWorkoutOr.
  ///
  /// In en, this message translates to:
  /// **'Nothing shared yet. Share a workout or a meal plan below.'**
  String get nothingSharedYetShareAWorkoutOr;

  /// No description provided for @shareAWorkout.
  ///
  /// In en, this message translates to:
  /// **'Share a workout'**
  String get shareAWorkout;

  /// No description provided for @liveSessions.
  ///
  /// In en, this message translates to:
  /// **'Live sessions'**
  String get liveSessions;

  /// No description provided for @waitingForAnAnswer.
  ///
  /// In en, this message translates to:
  /// **'Waiting for an answer'**
  String get waitingForAnAnswer;

  /// No description provided for @closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// Coach desk
  ///
  /// In en, this message translates to:
  /// **'With you since {start} · ends {end}'**
  String withYouSinceStartEndsEnd(String start, String end);

  /// No description provided for @weCouldNotFindThisClient.
  ///
  /// In en, this message translates to:
  /// **'We could not find this client.'**
  String get weCouldNotFindThisClient;

  /// The client's first name.
  ///
  /// In en, this message translates to:
  /// **'Plan for {name}'**
  String planForName(String name);

  /// No description provided for @startFrom.
  ///
  /// In en, this message translates to:
  /// **'Start from'**
  String get startFrom;

  /// No description provided for @oneOfTheThreeSplits.
  ///
  /// In en, this message translates to:
  /// **'One of the three splits'**
  String get oneOfTheThreeSplits;

  /// No description provided for @yourTemplates.
  ///
  /// In en, this message translates to:
  /// **'Your templates'**
  String get yourTemplates;

  /// No description provided for @blankPlan.
  ///
  /// In en, this message translates to:
  /// **'Blank plan'**
  String get blankPlan;

  /// No description provided for @planName.
  ///
  /// In en, this message translates to:
  /// **'Plan name'**
  String get planName;

  /// No description provided for @editDaysAndMoves.
  ///
  /// In en, this message translates to:
  /// **'Edit days and moves'**
  String get editDaysAndMoves;

  /// The client's first name.
  ///
  /// In en, this message translates to:
  /// **'Publish to {name}'**
  String publishToName(String name);

  /// No description provided for @publishAsANewVersion.
  ///
  /// In en, this message translates to:
  /// **'Publish as a new version'**
  String get publishAsANewVersion;

  /// No description provided for @saveAsATemplate.
  ///
  /// In en, this message translates to:
  /// **'Save as a template'**
  String get saveAsATemplate;

  /// No description provided for @templateSaved.
  ///
  /// In en, this message translates to:
  /// **'Template saved.'**
  String get templateSaved;

  /// The client's first name.
  ///
  /// In en, this message translates to:
  /// **'Published. {name} can see it now.'**
  String publishedNameCanSeeItNow(String name);

  /// No description provided for @giveThePlanANameFirst.
  ///
  /// In en, this message translates to:
  /// **'Give the plan a name first.'**
  String get giveThePlanANameFirst;

  /// No description provided for @addAtLeastOneDayFirst.
  ///
  /// In en, this message translates to:
  /// **'Add at least one day first.'**
  String get addAtLeastOneDayFirst;

  /// No description provided for @thisPlanIsTooBigToSend.
  ///
  /// In en, this message translates to:
  /// **'This plan is too big to send. Take out a day or some moves.'**
  String get thisPlanIsTooBigToSend;

  /// No description provided for @aMoveInThisPlanIsNot.
  ///
  /// In en, this message translates to:
  /// **'A move in this plan is not in the exercise library any more.'**
  String get aMoveInThisPlanIsNot;

  /// A plan's revision number.
  ///
  /// In en, this message translates to:
  /// **'Version {n}'**
  String versionN(String n);

  /// No description provided for @dayName.
  ///
  /// In en, this message translates to:
  /// **'Day name'**
  String get dayName;

  /// No description provided for @addMoves.
  ///
  /// In en, this message translates to:
  /// **'Add moves'**
  String get addMoves;

  /// No description provided for @holdInSeconds.
  ///
  /// In en, this message translates to:
  /// **'Hold, in seconds'**
  String get holdInSeconds;

  /// No description provided for @watchTheClip.
  ///
  /// In en, this message translates to:
  /// **'Watch the clip'**
  String get watchTheClip;

  /// No description provided for @howManyDays.
  ///
  /// In en, this message translates to:
  /// **'How many days'**
  String get howManyDays;

  /// A meal slot: breakfast, lunch, dinner or snack.
  ///
  /// In en, this message translates to:
  /// **'Add to {slot}'**
  String addToSlot(String slot);

  /// No description provided for @aShortLineLikeFruitOfHer.
  ///
  /// In en, this message translates to:
  /// **'A short line, like fruit of her choice'**
  String get aShortLineLikeFruitOfHer;

  /// No description provided for @grams.
  ///
  /// In en, this message translates to:
  /// **'Grams'**
  String get grams;

  /// No description provided for @noteForHerIfYouLike.
  ///
  /// In en, this message translates to:
  /// **'Note for her, if you like'**
  String get noteForHerIfYouLike;

  /// The client's name, then the allergies she declared.
  ///
  /// In en, this message translates to:
  /// **'{name} avoids: {list}'**
  String nameAvoidsList(String name, String list);

  /// No description provided for @noAllergiesOnHerIntake.
  ///
  /// In en, this message translates to:
  /// **'No allergies on her intake.'**
  String get noAllergiesOnHerIntake;

  /// Allergens in a meal item.
  ///
  /// In en, this message translates to:
  /// **'Contains {allergens}, which she avoids.'**
  String containsAllergensWhichSheAvoids(String allergens);

  /// No description provided for @allergensNotCheckedForThisOne.
  ///
  /// In en, this message translates to:
  /// **'Allergens not checked for this one.'**
  String get allergensNotCheckedForThisOne;

  /// No description provided for @checkTheMarkedItemsBeforeYouPublish.
  ///
  /// In en, this message translates to:
  /// **'Check the marked items before you publish.'**
  String get checkTheMarkedItemsBeforeYouPublish;

  /// A day's nutrition worked out from the food tables.
  ///
  /// In en, this message translates to:
  /// **'About {kcal} kcal, {protein} g protein'**
  String aboutKcalKcalProteinGProtein(String kcal, String protein);

  /// No description provided for @figuresComeFromOwnHubsFoodTables.
  ///
  /// In en, this message translates to:
  /// **'Figures come from Own Hub\'s food tables.'**
  String get figuresComeFromOwnHubsFoodTables;

  /// No description provided for @someItemsHaveNoFigures.
  ///
  /// In en, this message translates to:
  /// **'Some items have no figures.'**
  String get someItemsHaveNoFigures;

  /// No description provided for @nothingPlannedYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned yet'**
  String get nothingPlannedYet;

  /// No description provided for @addAtLeastOneItemFirst.
  ///
  /// In en, this message translates to:
  /// **'Add at least one item first.'**
  String get addAtLeastOneItemFirst;

  /// No description provided for @noRecipesToPickFromYet.
  ///
  /// In en, this message translates to:
  /// **'No recipes to pick from yet.'**
  String get noRecipesToPickFromYet;

  /// Servings of a recipe.
  ///
  /// In en, this message translates to:
  /// **'Servings: {n}'**
  String servingsN(String n);

  /// No description provided for @scheduleASession.
  ///
  /// In en, this message translates to:
  /// **'Schedule a session'**
  String get scheduleASession;

  /// No description provided for @meetingLink.
  ///
  /// In en, this message translates to:
  /// **'Meeting link'**
  String get meetingLink;

  /// No description provided for @aGoogleMeetOrZoomLinkThat.
  ///
  /// In en, this message translates to:
  /// **'A Google Meet or Zoom link that starts with https'**
  String get aGoogleMeetOrZoomLinkThat;

  /// No description provided for @thatLinkIsNotAllowedUseGoogle.
  ///
  /// In en, this message translates to:
  /// **'That link is not allowed. Use Google Meet, Zoom or Teams.'**
  String get thatLinkIsNotAllowedUseGoogle;

  /// No description provided for @thatTimeIsAfterHerCoachingEnds.
  ///
  /// In en, this message translates to:
  /// **'That time is after her coaching ends.'**
  String get thatTimeIsAfterHerCoachingEnds;

  /// Live sessions used out of the package's.
  ///
  /// In en, this message translates to:
  /// **'Sessions used: {used} of {included}'**
  String sessionsUsedUsedOfIncluded(String used, String included);

  /// No description provided for @noSessionsLeftInThisPackage.
  ///
  /// In en, this message translates to:
  /// **'No sessions left in this package.'**
  String get noSessionsLeftInThisPackage;

  /// The client's first name.
  ///
  /// In en, this message translates to:
  /// **'Send to {name}'**
  String sendToName(String name);

  /// The client's first name.
  ///
  /// In en, this message translates to:
  /// **'Session sent. {name} can confirm it.'**
  String sessionSentNameCanConfirmIt(String name);

  /// The coach's name.
  ///
  /// In en, this message translates to:
  /// **'Your coaching with {coach} has ended. Your plans stay here to read.'**
  String yourCoachingWithCoachHasEndedYour(String coach);

  /// Days left in a coaching package.
  ///
  /// In en, this message translates to:
  /// **'Days left: {n}'**
  String daysLeftN(String n);

  /// No description provided for @lastDay.
  ///
  /// In en, this message translates to:
  /// **'Last day'**
  String get lastDay;

  /// No description provided for @plansFromYourCoach.
  ///
  /// In en, this message translates to:
  /// **'Plans from your coach'**
  String get plansFromYourCoach;

  /// No description provided for @yourCoachHasNotSharedAPlan.
  ///
  /// In en, this message translates to:
  /// **'Your coach has not shared a plan yet.'**
  String get yourCoachHasNotSharedAPlan;

  /// No description provided for @upcomingSession.
  ///
  /// In en, this message translates to:
  /// **'Upcoming session'**
  String get upcomingSession;

  /// No description provided for @markDone.
  ///
  /// In en, this message translates to:
  /// **'Mark done'**
  String get markDone;

  /// No description provided for @waitingForTheOtherSideToMark.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the other side to mark it done.'**
  String get waitingForTheOtherSideToMark;

  /// No description provided for @countedInYourSessions.
  ///
  /// In en, this message translates to:
  /// **'Counted in your sessions.'**
  String get countedInYourSessions;

  /// No description provided for @blockThisCoach.
  ///
  /// In en, this message translates to:
  /// **'Block this coach?'**
  String get blockThisCoach;

  /// No description provided for @sheWillNotBeAbleToMessage.
  ///
  /// In en, this message translates to:
  /// **'She will not be able to message you. You can still read your plans.'**
  String get sheWillNotBeAbleToMessage;

  /// No description provided for @newMessagesFromYourCoach.
  ///
  /// In en, this message translates to:
  /// **'New messages from your coach'**
  String get newMessagesFromYourCoach;

  /// No description provided for @fromYourCoach.
  ///
  /// In en, this message translates to:
  /// **'From your coach'**
  String get fromYourCoach;

  /// The name of the coach's workout for today.
  ///
  /// In en, this message translates to:
  /// **'Today\'s workout: {name}'**
  String todaysWorkoutName(String name);

  /// Day and time of the next live session.
  ///
  /// In en, this message translates to:
  /// **'Next session: {when}'**
  String nextSessionWhen(String when);

  /// No description provided for @startThisWorkout.
  ///
  /// In en, this message translates to:
  /// **'Start this workout'**
  String get startThisWorkout;

  /// No description provided for @heldBackForHowYouAreTraining.
  ///
  /// In en, this message translates to:
  /// **'Held back for how you are training now. Ask your coach or your doctor first.'**
  String get heldBackForHowYouAreTraining;

  /// Allergens in a meal item, for the client.
  ///
  /// In en, this message translates to:
  /// **'Contains {allergens}, which you avoid.'**
  String containsAllergensWhichYouAvoid(String allergens);

  /// No description provided for @notCheckedAgainstYourAllergies.
  ///
  /// In en, this message translates to:
  /// **'Not checked against your allergies.'**
  String get notCheckedAgainstYourAllergies;

  /// No description provided for @todaysMealsFromYourCoach.
  ///
  /// In en, this message translates to:
  /// **'Today\'s meals from your coach'**
  String get todaysMealsFromYourCoach;

  /// No description provided for @ifYouHaveAHealthConditionCheck.
  ///
  /// In en, this message translates to:
  /// **'If you have a health condition, check with your doctor before you follow a plan.'**
  String get ifYouHaveAHealthConditionCheck;

  /// No description provided for @youHaveNoCoachRightNow.
  ///
  /// In en, this message translates to:
  /// **'You have no coach right now.'**
  String get youHaveNoCoachRightNow;

  /// Length of a live session in minutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min session'**
  String minutesMinSession(String minutes);

  /// No description provided for @yourCoachHasNotSetAPlan.
  ///
  /// In en, this message translates to:
  /// **'Your coach has not set a plan for today.'**
  String get yourCoachHasNotSetAPlan;

  /// No description provided for @openMyCoach.
  ///
  /// In en, this message translates to:
  /// **'Open my coach'**
  String get openMyCoach;

  /// No description provided for @moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDown;

  /// No description provided for @logThis.
  ///
  /// In en, this message translates to:
  /// **'Log this'**
  String get logThis;

  /// No description provided for @photosAndResults.
  ///
  /// In en, this message translates to:
  /// **'Photos and results'**
  String get photosAndResults;

  /// No description provided for @whatMembersSeeAfterOwnHubChecks.
  ///
  /// In en, this message translates to:
  /// **'What members see after Own Hub checks it'**
  String get whatMembersSeeAfterOwnHubChecks;

  /// No description provided for @waitingForOwnHubsCheck.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Own Hub\'s check'**
  String get waitingForOwnHubsCheck;

  /// No description provided for @shownOnYourPortfolio.
  ///
  /// In en, this message translates to:
  /// **'Shown on your portfolio'**
  String get shownOnYourPortfolio;

  /// No description provided for @notApproved.
  ///
  /// In en, this message translates to:
  /// **'Not approved'**
  String get notApproved;

  /// No description provided for @needsYourClientsConsent.
  ///
  /// In en, this message translates to:
  /// **'Needs your client\'s consent'**
  String get needsYourClientsConsent;

  /// No description provided for @addAPhotoOfYouOrYour.
  ///
  /// In en, this message translates to:
  /// **'Add a photo of you or your work'**
  String get addAPhotoOfYouOrYour;

  /// No description provided for @nothingHereYetAddYourFirstResult.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. Add your first result.'**
  String get nothingHereYetAddYourFirstResult;

  /// How many photos and results she has added, out of the 30 allowed.
  ///
  /// In en, this message translates to:
  /// **'{count} of 30 items'**
  String countOf30Items(String count);

  /// Title of a before and after item.
  ///
  /// In en, this message translates to:
  /// **'Transformation, {weeks} weeks'**
  String transformationWeeksWeeks(String weeks);

  /// Title of a client feedback item.
  ///
  /// In en, this message translates to:
  /// **'Feedback from {name}'**
  String feedbackFromName(String name);

  /// No description provided for @keep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keep;

  /// No description provided for @removeThisFromYourPortfolio.
  ///
  /// In en, this message translates to:
  /// **'Remove this from your portfolio?'**
  String get removeThisFromYourPortfolio;

  /// No description provided for @confirmMyClientAgreed.
  ///
  /// In en, this message translates to:
  /// **'Confirm my client agreed'**
  String get confirmMyClientAgreed;

  /// No description provided for @chooseAPhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo'**
  String get chooseAPhoto;

  /// No description provided for @replacePhoto.
  ///
  /// In en, this message translates to:
  /// **'Replace photo'**
  String get replacePhoto;

  /// No description provided for @noteOptional_1l0x9.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteOptional_1l0x9;

  /// No description provided for @myClientAgreedInWritingThatOwn_c2wgd.
  ///
  /// In en, this message translates to:
  /// **'My client agreed in writing that Own Hub members may see these photos'**
  String get myClientAgreedInWritingThatOwn_c2wgd;

  /// No description provided for @sendForOwnHubsCheck.
  ///
  /// In en, this message translates to:
  /// **'Send for Own Hub\'s check'**
  String get sendForOwnHubsCheck;

  /// No description provided for @sentOwnHubChecksEveryPhotoBefore.
  ///
  /// In en, this message translates to:
  /// **'Sent. Own Hub checks every photo before members see it.'**
  String get sentOwnHubChecksEveryPhotoBefore;

  /// No description provided for @whatYourClientSaid.
  ///
  /// In en, this message translates to:
  /// **'What your client said'**
  String get whatYourClientSaid;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// No description provided for @screenshotOptional_x0klp.
  ///
  /// In en, this message translates to:
  /// **'Screenshot (optional)'**
  String get screenshotOptional_x0klp;

  /// No description provided for @captionOptional.
  ///
  /// In en, this message translates to:
  /// **'Caption (optional)'**
  String get captionOptional;

  /// No description provided for @addThePhotoFirst.
  ///
  /// In en, this message translates to:
  /// **'Add the photo first.'**
  String get addThePhotoFirst;

  /// No description provided for @addBothPhotos.
  ///
  /// In en, this message translates to:
  /// **'Add both photos.'**
  String get addBothPhotos;

  /// No description provided for @tickTheBoxToSayYourClient.
  ///
  /// In en, this message translates to:
  /// **'Tick the box to say your client agreed.'**
  String get tickTheBoxToSayYourClient;

  /// Length rule for a text.
  ///
  /// In en, this message translates to:
  /// **'Write {low} to {high} characters.'**
  String writeLowToHighCharacters(String low, String high);

  /// No description provided for @writeWhoItIsFrom.
  ///
  /// In en, this message translates to:
  /// **'Write who it is from.'**
  String get writeWhoItIsFrom;

  /// No description provided for @yourClientConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Your client confirmed.'**
  String get yourClientConfirmed;

  /// No description provided for @results.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get results;

  /// Weeks a transformation took.
  ///
  /// In en, this message translates to:
  /// **'Over {n} weeks'**
  String overNWeeks(int n);

  /// No description provided for @sharedWithHerClientsWrittenConsent.
  ///
  /// In en, this message translates to:
  /// **'Shared with her client\'s written consent'**
  String get sharedWithHerClientsWrittenConsent;

  /// No description provided for @nothingApprovedYetPhotosAndResultsShow.
  ///
  /// In en, this message translates to:
  /// **'Nothing approved yet. Photos and results show here after Own Hub checks them.'**
  String get nothingApprovedYetPhotosAndResultsShow;

  /// No description provided for @screenshotOfAMessageFromAClient.
  ///
  /// In en, this message translates to:
  /// **'Screenshot of a message from a client'**
  String get screenshotOfAMessageFromAClient;

  /// No description provided for @thePhotoWasNotClearEnough.
  ///
  /// In en, this message translates to:
  /// **'The photo was not clear enough.'**
  String get thePhotoWasNotClearEnough;

  /// No description provided for @itDoesNotFollowTheRulesFor.
  ///
  /// In en, this message translates to:
  /// **'It does not follow the rules for photos.'**
  String get itDoesNotFollowTheRulesFor;

  /// No description provided for @weNeedYourClientsWrittenAgreement.
  ///
  /// In en, this message translates to:
  /// **'We need your client\'s written agreement.'**
  String get weNeedYourClientsWrittenAgreement;

  /// No description provided for @ownHubCouldNotApproveIt.
  ///
  /// In en, this message translates to:
  /// **'Own Hub could not approve it.'**
  String get ownHubCouldNotApproveIt;

  /// No description provided for @newActivityInTheChat.
  ///
  /// In en, this message translates to:
  /// **'New activity in the chat'**
  String get newActivityInTheChat;

  /// No description provided for @thatItemIsNoLongerTherePull.
  ///
  /// In en, this message translates to:
  /// **'That item is no longer there. Pull down to refresh your list.'**
  String get thatItemIsNoLongerTherePull;

  /// A coaching package's countdown. A plural message because Arabic counts agree differently at 1, 2, 3 to 10 and 11 and up.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{1 day left} other{{days} days left}}'**
  String daysPluralOne1DayLeftOther(int days);

  /// A package length in weeks, taken from the template's own duration.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 week} other{{count} weeks}}'**
  String countPluralOne1WeekOtherCount(int count);

  /// Live sessions a month, taken from the template's own number.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 live session a month} other{{count} live sessions a month}}'**
  String countPluralOne1LiveSessionA(int count);

  /// The package template picker label: length, then live sessions a month, both already worded.
  ///
  /// In en, this message translates to:
  /// **'{weeks}, {sessions}'**
  String weeksSessions(String weeks, String sessions);

  /// A package template's title. weeks is already worded, e.g. 4 weeks.
  ///
  /// In en, this message translates to:
  /// **'{weeks} of coaching with me'**
  String weeksOfCoachingWithMe(String weeks);

  /// Refusal when she is at the package limit.
  ///
  /// In en, this message translates to:
  /// **'You already have {count} packages. Edit one of them instead.'**
  String youAlreadyHaveCountPackagesEditOne(String count);

  /// Shown instead of the add button at the package limit.
  ///
  /// In en, this message translates to:
  /// **'You have all {count} packages.'**
  String youHaveAllCountPackages(String count);

  /// Portfolio media at its limit.
  ///
  /// In en, this message translates to:
  /// **'You have {count} items. Remove one to add another.'**
  String youHaveCountItemsRemoveOneTo(String count);

  /// Coach application review time.
  ///
  /// In en, this message translates to:
  /// **'Review takes up to {days} working days.'**
  String reviewTakesUpToDaysWorkingDays(String days);

  /// Coach application status while it is in review.
  ///
  /// In en, this message translates to:
  /// **'Own Hub\'s reviewer is reading it. This takes up to {days} working days, and we will tell you here.'**
  String ownHubsReviewerIsReadingItThis(String days);

  /// Coach re-apply wait, from the contract's own number.
  ///
  /// In en, this message translates to:
  /// **'You can apply again {days} days after the decision.'**
  String youCanApplyAgainDaysDaysAfter(String days);

  /// Application photo refused; mb is the upload limit.
  ///
  /// In en, this message translates to:
  /// **'That photo could not be used. Choose a JPEG or PNG under {mb} MB.'**
  String thatPhotoCouldNotBeUsedChoose(String mb);

  /// Application step 2, education.
  ///
  /// In en, this message translates to:
  /// **'Add {min} to {max}. A photo of the degree is optional.'**
  String addMinToMaxAPhotoOf(String min, String max);

  /// Application step 3, certificates.
  ///
  /// In en, this message translates to:
  /// **'Add {min} to {max}. Each one needs a photo.'**
  String addMinToMaxEachOneNeeds(String min, String max);

  /// Application step 4, specialties.
  ///
  /// In en, this message translates to:
  /// **'Choose {min} to {max}, then tell us about your experience.'**
  String chooseMinToMaxThenTellUs(String min, String max);

  /// Application step 5, testimonials.
  ///
  /// In en, this message translates to:
  /// **'Add {min} to {max} messages from women you trained.'**
  String addMinToMaxMessagesFromWomen(String min, String max);

  /// Application step 6, transformations.
  ///
  /// In en, this message translates to:
  /// **'Add {min} to {max}. The photos are seen only by Own Hub\'s woman reviewer.'**
  String addMinToMaxThePhotosAre(String min, String max);

  /// Refusal for too many certificates.
  ///
  /// In en, this message translates to:
  /// **'You added too many certificates. The most is {max}.'**
  String youAddedTooManyCertificatesTheMost(String max);

  /// Session scheduling lead time.
  ///
  /// In en, this message translates to:
  /// **'Pick a time at least {minutes} minutes from now.'**
  String pickATimeAtLeastMinutesMinutes(String minutes);

  /// Session date field hint; example is a format sample.
  ///
  /// In en, this message translates to:
  /// **'Type the date and time like {example}.'**
  String typeTheDateAndTimeLikeExample(String example);

  /// The lowest budget band for a coach search; n is the band's own upper bound.
  ///
  /// In en, this message translates to:
  /// **'Under EGP {n}'**
  String underEgpN(String n);

  /// The highest budget band for a coach search; n is the band's own lower bound.
  ///
  /// In en, this message translates to:
  /// **'Over EGP {n}'**
  String overEgpN(String n);

  /// The middle budget band for a coach search, from the band's own bounds.
  ///
  /// In en, this message translates to:
  /// **'EGP {low} to {high}'**
  String egpLowToHigh(String low, String high);

  /// No description provided for @endCoaching.
  ///
  /// In en, this message translates to:
  /// **'End coaching'**
  String get endCoaching;

  /// No description provided for @endThisCoaching.
  ///
  /// In en, this message translates to:
  /// **'End this coaching?'**
  String get endThisCoaching;

  /// Shown when a member confirms ending her coaching. coach is the coach's name.
  ///
  /// In en, this message translates to:
  /// **'The chat becomes read only. Your plans stay with you. {coach} will no longer see your answers.'**
  String theChatBecomesReadOnlyYourPlans(String coach);

  /// No description provided for @theChatBecomesReadOnlyHerPlans.
  ///
  /// In en, this message translates to:
  /// **'The chat becomes read only. Her plans stay with her. You will no longer see her answers.'**
  String get theChatBecomesReadOnlyHerPlans;

  /// No description provided for @keepCoaching.
  ///
  /// In en, this message translates to:
  /// **'Keep coaching'**
  String get keepCoaching;

  /// A member's coaching request that the coach has not answered yet. coach is the coach's name.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {coach}\'s answer'**
  String waitingForCoachSAnswer(String coach);

  /// No description provided for @cancelRequest.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get cancelRequest;

  /// A member's request was declined. coach is the coach's name.
  ///
  /// In en, this message translates to:
  /// **'{coach} could not take you this time'**
  String coachCouldNotTakeYouThisTime(String coach);

  /// No description provided for @noAnswerInTime.
  ///
  /// In en, this message translates to:
  /// **'No answer in time'**
  String get noAnswerInTime;

  /// No description provided for @findAnotherCoach.
  ///
  /// In en, this message translates to:
  /// **'Find another coach'**
  String get findAnotherCoach;

  /// No description provided for @waitingForYourReply.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your reply'**
  String get waitingForYourReply;

  /// Why a client is on the coach's follow up list. days is a number.
  ///
  /// In en, this message translates to:
  /// **'No message from you in {days} days'**
  String noMessageFromYouInDaysDays(String days);

  /// No description provided for @youCanSeeItUnderMyCoach.
  ///
  /// In en, this message translates to:
  /// **'You can see it under My coach.'**
  String get youCanSeeItUnderMyCoach;

  /// No description provided for @freeForNow.
  ///
  /// In en, this message translates to:
  /// **'Free for now'**
  String get freeForNow;

  /// Coach browsing while payments are off: the package price as it will be.
  ///
  /// In en, this message translates to:
  /// **'EGP {price} when payments open'**
  String egpPriceWhenPaymentsOpen(String price);

  /// No description provided for @freeForMembersUntilPaymentsOpen.
  ///
  /// In en, this message translates to:
  /// **'Free for members until payments open'**
  String get freeForMembersUntilPaymentsOpen;

  /// No description provided for @notVisibleYetAddAPackage.
  ///
  /// In en, this message translates to:
  /// **'Not visible yet: add a package'**
  String get notVisibleYetAddAPackage;

  /// No description provided for @backToProfile.
  ///
  /// In en, this message translates to:
  /// **'Back to profile'**
  String get backToProfile;

  /// No description provided for @contactOwnHub.
  ///
  /// In en, this message translates to:
  /// **'Contact Own Hub'**
  String get contactOwnHub;

  /// No description provided for @chooseADateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Choose a date and time'**
  String get chooseADateAndTime;

  /// No description provided for @cantMakeIt.
  ///
  /// In en, this message translates to:
  /// **'Can\'t make it'**
  String get cantMakeIt;

  /// Coach space pill. A plural message because Arabic counts agree differently at 1, 2, 3 to 10 and 11 and up.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 client} other{{count} clients}}'**
  String countPluralOne1ClientOtherCount(int count);

  /// Coach space pill. A plural message because Arabic counts agree differently at 1, 2, 3 to 10 and 11 and up.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 new request} other{{count} new requests}}'**
  String countPluralOne1NewRequestOther(int count);

  /// Coach space pill. A plural message because Arabic counts agree differently at 1, 2, 3 to 10 and 11 and up.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 unread chat} other{{count} unread chats}}'**
  String countPluralOne1UnreadChatOther(int count);

  /// A package length on a coach's page. A plural message because Arabic counts agree differently at 1, 2, 3 to 10 and 11 and up.
  ///
  /// In en, this message translates to:
  /// **'Duration: {days, plural, one{1 day} other{{days} days}}'**
  String durationDaysPluralOne1DayOther(int days);

  /// A transformation's length on a coach's page. A plural message because Arabic counts agree differently at 1, 2, 3 to 10 and 11 and up.
  ///
  /// In en, this message translates to:
  /// **'Over {weeks, plural, one{1 week} other{{weeks} weeks}}'**
  String overWeeksPluralOne1WeekOther(int weeks);

  /// A transformation's title in the coach's list. A plural message because Arabic counts agree differently at 1, 2, 3 to 10 and 11 and up.
  ///
  /// In en, this message translates to:
  /// **'Transformation, {weeks, plural, one{1 week} other{{weeks} weeks}}'**
  String transformationWeeksPluralOne1WeekOther(int weeks);

  /// No description provided for @faceToFace.
  ///
  /// In en, this message translates to:
  /// **'Face to face'**
  String get faceToFace;

  /// No description provided for @seeItFirst.
  ///
  /// In en, this message translates to:
  /// **'See it first'**
  String get seeItFirst;

  /// No description provided for @am.
  ///
  /// In en, this message translates to:
  /// **'AM'**
  String get am;

  /// No description provided for @pm.
  ///
  /// In en, this message translates to:
  /// **'PM'**
  String get pm;

  /// No description provided for @pickHerNameIfSheKnowsYou_akwt2.
  ///
  /// In en, this message translates to:
  /// **'Pick her name if she knows you. Your request goes to her.'**
  String get pickHerNameIfSheKnowsYou_akwt2;

  /// No description provided for @nameYourCoachSees.
  ///
  /// In en, this message translates to:
  /// **'Name your coach sees'**
  String get nameYourCoachSees;

  /// No description provided for @yourFirstNameIsOptionalYourCoach.
  ///
  /// In en, this message translates to:
  /// **'Your first name is optional. Your coach sees it next to your answers.'**
  String get yourFirstNameIsOptionalYourCoach;

  /// No description provided for @iAgreeThatMyAnswersAreSent.
  ///
  /// In en, this message translates to:
  /// **'I agree that my answers are sent to Own Hub\'s servers in Frankfurt, Germany, outside Egypt, and stored there.'**
  String get iAgreeThatMyAnswersAreSent;

  /// No description provided for @aPictureOfYourClientsWrittenAgreement.
  ///
  /// In en, this message translates to:
  /// **'A picture of your client\'s written agreement'**
  String get aPictureOfYourClientsWrittenAgreement;

  /// No description provided for @onlyAWomanReviewerAtOwnHub.
  ///
  /// In en, this message translates to:
  /// **'Only a woman reviewer at Own Hub sees this. Add it before you send.'**
  String get onlyAWomanReviewerAtOwnHub;

  /// No description provided for @addHerWrittenAgreement.
  ///
  /// In en, this message translates to:
  /// **'Add her written agreement'**
  String get addHerWrittenAgreement;

  /// No description provided for @beforeYourFirstMessage.
  ///
  /// In en, this message translates to:
  /// **'Before your first message'**
  String get beforeYourFirstMessage;

  /// No description provided for @beRespectfulInsultsHarassmentAndHatefulWords.
  ///
  /// In en, this message translates to:
  /// **'Be respectful. Insults, harassment and hateful words are not allowed.'**
  String get beRespectfulInsultsHarassmentAndHatefulWords;

  /// No description provided for @keepTheChatInOwnHubPhone.
  ///
  /// In en, this message translates to:
  /// **'Keep the chat in Own Hub. Phone numbers, links and payment details are not allowed, and the app stops these messages.'**
  String get keepTheChatInOwnHubPhone;

  /// No description provided for @yourCoachSharesTrainingAndFoodIdeas.
  ///
  /// In en, this message translates to:
  /// **'Your coach shares training and food ideas. It is not medical advice. Ask your doctor about any health problem.'**
  String get yourCoachSharesTrainingAndFoodIdeas;

  /// No description provided for @messagesAreStoredOnOwnHubsServers.
  ///
  /// In en, this message translates to:
  /// **'Messages are stored on Own Hub\'s servers. If a message is reported, Own Hub staff can read it. You can report or block anyone from the menu.'**
  String get messagesAreStoredOnOwnHubsServers;

  /// No description provided for @iHaveReadTheseRulesAndI.
  ///
  /// In en, this message translates to:
  /// **'I have read these rules and I agree to follow them.'**
  String get iHaveReadTheseRulesAndI;

  /// No description provided for @agreeAndSend.
  ///
  /// In en, this message translates to:
  /// **'Agree and send'**
  String get agreeAndSend;

  /// No description provided for @weCouldNotSaveYourAnswerTry.
  ///
  /// In en, this message translates to:
  /// **'We could not save your answer. Try again.'**
  String get weCouldNotSaveYourAnswerTry;

  /// No description provided for @onTurnOffAndYourMealPhotos.
  ///
  /// In en, this message translates to:
  /// **'On. Turn off and your meal photos stop going to Google.'**
  String get onTurnOffAndYourMealPhotos;

  /// No description provided for @offYouAreAskedAgainBeforeYour.
  ///
  /// In en, this message translates to:
  /// **'Off. You are asked again before your next meal photo.'**
  String get offYouAreAskedAgainBeforeYour;

  /// No description provided for @weCouldNotTurnThisOffTry.
  ///
  /// In en, this message translates to:
  /// **'We could not turn this off. Try again.'**
  String get weCouldNotTurnThisOffTry;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @activities.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get activities;

  /// No description provided for @seeMore.
  ///
  /// In en, this message translates to:
  /// **'See more'**
  String get seeMore;

  /// No description provided for @sessionsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Sessions this week'**
  String get sessionsThisWeek;

  /// No description provided for @addAPictureOfYourClientsWritten.
  ///
  /// In en, this message translates to:
  /// **'Add a picture of your client\'s written agreement.'**
  String get addAPictureOfYourClientsWritten;

  /// No description provided for @mealPhotosSentToGoogleToRead.
  ///
  /// In en, this message translates to:
  /// **'Meal photos sent to Google to read the food'**
  String get mealPhotosSentToGoogleToRead;

  /// No description provided for @editToday.
  ///
  /// In en, this message translates to:
  /// **'Edit today'**
  String get editToday;

  /// No description provided for @shortVersion.
  ///
  /// In en, this message translates to:
  /// **'Short version'**
  String get shortVersion;

  /// No description provided for @doMyOwnPlanInstead.
  ///
  /// In en, this message translates to:
  /// **'Do my own plan instead'**
  String get doMyOwnPlanInstead;

  /// Home's one Eat line: calories eaten so far against today's target, in Western digits, e.g. 1,240 of 1,624 kcal.
  ///
  /// In en, this message translates to:
  /// **'{eaten} of {target} kcal'**
  String eatenOfTargetKcal(String eaten, String target);

  /// R07: which set of the move she is on.
  ///
  /// In en, this message translates to:
  /// **'Set {n} of {total}'**
  String setNOfTotal(String n, String total);

  /// No description provided for @plates.
  ///
  /// In en, this message translates to:
  /// **'Plates'**
  String get plates;

  /// No description provided for @allMoves.
  ///
  /// In en, this message translates to:
  /// **'All moves'**
  String get allMoves;

  /// No description provided for @nextMove.
  ///
  /// In en, this message translates to:
  /// **'Next move'**
  String get nextMove;

  /// No description provided for @seeDetails.
  ///
  /// In en, this message translates to:
  /// **'See details'**
  String get seeDetails;

  /// No description provided for @editMoves.
  ///
  /// In en, this message translates to:
  /// **'Edit moves'**
  String get editMoves;

  /// No description provided for @yourPlan.
  ///
  /// In en, this message translates to:
  /// **'Your plan'**
  String get yourPlan;

  /// No description provided for @gentler.
  ///
  /// In en, this message translates to:
  /// **'Gentler'**
  String get gentler;

  /// No description provided for @recordAVideoUpTo30Seconds.
  ///
  /// In en, this message translates to:
  /// **'Record a video (up to 30 seconds)'**
  String get recordAVideoUpTo30Seconds;

  /// No description provided for @chooseAVideo.
  ///
  /// In en, this message translates to:
  /// **'Choose a video'**
  String get chooseAVideo;

  /// No description provided for @weCouldNotSendThatTryAgain.
  ///
  /// In en, this message translates to:
  /// **'We could not send that. Try again.'**
  String get weCouldNotSendThatTryAgain;

  /// No description provided for @holdTheMicAndSpeak.
  ///
  /// In en, this message translates to:
  /// **'Hold the mic and speak'**
  String get holdTheMicAndSpeak;

  /// No description provided for @slideAwayToCancel.
  ///
  /// In en, this message translates to:
  /// **'Slide away to cancel'**
  String get slideAwayToCancel;

  /// No description provided for @releaseToCancel.
  ///
  /// In en, this message translates to:
  /// **'Release to cancel'**
  String get releaseToCancel;

  /// No description provided for @allowTheMicrophoneInSettingsToSend.
  ///
  /// In en, this message translates to:
  /// **'Allow the microphone in Settings to send voice notes.'**
  String get allowTheMicrophoneInSettingsToSend;

  /// No description provided for @weCouldNotPlayThatVoiceNote.
  ///
  /// In en, this message translates to:
  /// **'We could not play that voice note.'**
  String get weCouldNotPlayThatVoiceNote;

  /// No description provided for @editReply.
  ///
  /// In en, this message translates to:
  /// **'Edit reply'**
  String get editReply;

  /// No description provided for @addAReply.
  ///
  /// In en, this message translates to:
  /// **'Add a reply'**
  String get addAReply;

  /// No description provided for @newReply.
  ///
  /// In en, this message translates to:
  /// **'New reply'**
  String get newReply;

  /// No description provided for @writeYourReply.
  ///
  /// In en, this message translates to:
  /// **'Write your reply'**
  String get writeYourReply;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @greatWorkTodayIAmProudOf.
  ///
  /// In en, this message translates to:
  /// **'Great work today. I am proud of you.'**
  String get greatWorkTodayIAmProudOf;

  /// No description provided for @howDidTheSessionFeelTellMe.
  ///
  /// In en, this message translates to:
  /// **'How did the session feel? Tell me what was easy and what was hard.'**
  String get howDidTheSessionFeelTellMe;

  /// No description provided for @sendMeAShortVideoOfThat.
  ///
  /// In en, this message translates to:
  /// **'Send me a short video of that exercise from the side and I will check your form.'**
  String get sendMeAShortVideoOfThat;

  /// No description provided for @lowerTheWeightALittleAndFocus.
  ///
  /// In en, this message translates to:
  /// **'Lower the weight a little and focus on a slow, steady movement.'**
  String get lowerTheWeightALittleAndFocus;

  /// No description provided for @restWellTodayRecoveryIsPartOf.
  ///
  /// In en, this message translates to:
  /// **'Rest well today. Recovery is part of the plan.'**
  String get restWellTodayRecoveryIsPartOf;

  /// No description provided for @rememberToDrinkWaterAndEatYour.
  ///
  /// In en, this message translates to:
  /// **'Remember to drink water and eat your protein today.'**
  String get rememberToDrinkWaterAndEatYour;

  /// No description provided for @ifAnythingHurtsStopAndTellMe.
  ///
  /// In en, this message translates to:
  /// **'If anything hurts, stop and tell me. Do not push through pain.'**
  String get ifAnythingHurtsStopAndTellMe;

  /// No description provided for @iSawYourWeeklyCheckInThank.
  ///
  /// In en, this message translates to:
  /// **'I saw your weekly check-in. Thank you. I will update your plan.'**
  String get iSawYourWeeklyCheckInThank;

  /// No description provided for @missedADayNoProblemPickUp.
  ///
  /// In en, this message translates to:
  /// **'Missed a day? No problem. Pick up with the next session.'**
  String get missedADayNoProblemPickUp;

  /// No description provided for @sendMeAPhotoOfYourMeal.
  ///
  /// In en, this message translates to:
  /// **'Send me a photo of your meal and I will give you my notes.'**
  String get sendMeAPhotoOfYourMeal;

  /// R03 weights line: the step up she has earned on a loaded move, from her last session.
  ///
  /// In en, this message translates to:
  /// **'Today: {weight} on {name}'**
  String todayWeightOnName(String weight, String name);

  /// R03 weights line: a loaded move that stays at last time's weight.
  ///
  /// In en, this message translates to:
  /// **'Same weight on {name} as last time, until it feels steady'**
  String sameWeightOnNameAsLastTime(String name);

  /// No description provided for @supersetGoStraightToTheNextMove.
  ///
  /// In en, this message translates to:
  /// **'Superset: go straight to the next move, then rest.'**
  String get supersetGoStraightToTheNextMove;

  /// No description provided for @moveDetails.
  ///
  /// In en, this message translates to:
  /// **'Move details'**
  String get moveDetails;

  /// No description provided for @targetWeightKg.
  ///
  /// In en, this message translates to:
  /// **'Target weight (kg)'**
  String get targetWeightKg;

  /// No description provided for @leaveEmptyForBodyweight.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for bodyweight'**
  String get leaveEmptyForBodyweight;

  /// No description provided for @supersetWithTheNextMove.
  ///
  /// In en, this message translates to:
  /// **'Superset with the next move'**
  String get supersetWithTheNextMove;

  /// No description provided for @superset.
  ///
  /// In en, this message translates to:
  /// **'Superset'**
  String get superset;

  /// No description provided for @saveDetails.
  ///
  /// In en, this message translates to:
  /// **'Save details'**
  String get saveDetails;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @copy_1g7xp.
  ///
  /// In en, this message translates to:
  /// **'(copy)'**
  String get copy_1g7xp;

  /// No description provided for @repeatLastWeek.
  ///
  /// In en, this message translates to:
  /// **'Repeat last week'**
  String get repeatLastWeek;

  /// Weeks in a plan
  ///
  /// In en, this message translates to:
  /// **'{n} weeks'**
  String nWeeks(String n);

  /// Which week of her plan she is in
  ///
  /// In en, this message translates to:
  /// **'Week {n} of {total}'**
  String weekNOfTotal(String n, String total);

  /// When her multi-week plan starts
  ///
  /// In en, this message translates to:
  /// **'Your plan starts {date}'**
  String yourPlanStartsDate(String date);

  /// No description provided for @seeAllWeeks.
  ///
  /// In en, this message translates to:
  /// **'See all weeks'**
  String get seeAllWeeks;

  /// No description provided for @sendToMoreClients.
  ///
  /// In en, this message translates to:
  /// **'Send to more clients'**
  String get sendToMoreClients;

  /// No description provided for @whoGetsThisPlan.
  ///
  /// In en, this message translates to:
  /// **'Who gets this plan?'**
  String get whoGetsThisPlan;

  /// No description provided for @chooseNClients.
  ///
  /// In en, this message translates to:
  /// **'Choose {n} clients'**
  String chooseNClients(Object n);

  /// No description provided for @publishToNClients.
  ///
  /// In en, this message translates to:
  /// **'Publish to {n} clients'**
  String publishToNClients(Object n);

  /// No description provided for @sentToNClients.
  ///
  /// In en, this message translates to:
  /// **'Sent to {n} clients'**
  String sentToNClients(Object n);

  /// No description provided for @tryAgainForN.
  ///
  /// In en, this message translates to:
  /// **'Try again for {n}'**
  String tryAgainForN(Object n);

  /// No description provided for @someClientsDidNotGetThePlan.
  ///
  /// In en, this message translates to:
  /// **'Some clients did not get the plan.'**
  String get someClientsDidNotGetThePlan;

  /// No description provided for @startsDate.
  ///
  /// In en, this message translates to:
  /// **'Starts {date}'**
  String startsDate(Object date);

  /// No description provided for @joinMeOnOwnHubTheTraining_s0kkx.
  ///
  /// In en, this message translates to:
  /// **'Join me on Own Hub, the training app for women only. Open this link: {link} If it does not open the app, install Own Hub, tap I have a code from my coach when you sign up and enter {code}.'**
  String joinMeOnOwnHubTheTraining_s0kkx(Object code, Object link);

  /// No description provided for @shareMyProfileLink.
  ///
  /// In en, this message translates to:
  /// **'Share my profile link'**
  String get shareMyProfileLink;

  /// No description provided for @membersWhoOpenItLandOnYour.
  ///
  /// In en, this message translates to:
  /// **'Members who open it land on your page and can ask to join.'**
  String get membersWhoOpenItLandOnYour;

  /// No description provided for @trainWithMeOnOwnHubLink.
  ///
  /// In en, this message translates to:
  /// **'Train with me on Own Hub: {link}'**
  String trainWithMeOnOwnHubLink(Object link);

  /// No description provided for @yourCoachsInvitation.
  ///
  /// In en, this message translates to:
  /// **'Your coach\'s invitation'**
  String get yourCoachsInvitation;

  /// No description provided for @thisLinkDoesNotWorkAskYour.
  ///
  /// In en, this message translates to:
  /// **'This link does not work. Ask your coach to send it again.'**
  String get thisLinkDoesNotWorkAskYour;

  /// No description provided for @weeklyCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Weekly check-in'**
  String get weeklyCheckIn;

  /// No description provided for @fourQuickTapsItTakesUnderA.
  ///
  /// In en, this message translates to:
  /// **'Four quick taps. It takes under a minute.'**
  String get fourQuickTapsItTakesUnderA;

  /// No description provided for @answer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get answer;

  /// No description provided for @weeklyCheckInSent.
  ///
  /// In en, this message translates to:
  /// **'Weekly check-in sent'**
  String get weeklyCheckInSent;

  /// No description provided for @sentThankYou.
  ///
  /// In en, this message translates to:
  /// **'Sent. Thank you.'**
  String get sentThankYou;

  /// No description provided for @howDidYourTrainingGo.
  ///
  /// In en, this message translates to:
  /// **'How did your training go?'**
  String get howDidYourTrainingGo;

  /// No description provided for @most.
  ///
  /// In en, this message translates to:
  /// **'Most'**
  String get most;

  /// No description provided for @some.
  ///
  /// In en, this message translates to:
  /// **'Some'**
  String get some;

  /// No description provided for @howIsYourEnergy.
  ///
  /// In en, this message translates to:
  /// **'How is your energy?'**
  String get howIsYourEnergy;

  /// No description provided for @n1IsLow5IsHigh.
  ///
  /// In en, this message translates to:
  /// **'1 is low, 5 is high.'**
  String get n1IsLow5IsHigh;

  /// No description provided for @howDidEatingGo.
  ///
  /// In en, this message translates to:
  /// **'How did eating go?'**
  String get howDidEatingGo;

  /// No description provided for @n1IsHard5IsEasy.
  ///
  /// In en, this message translates to:
  /// **'1 is hard, 5 is easy.'**
  String get n1IsHard5IsEasy;

  /// No description provided for @anyPainOrInjuryThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Any pain or injury this week?'**
  String get anyPainOrInjuryThisWeek;

  /// No description provided for @tellYourCoachMoreBelowIfYou.
  ///
  /// In en, this message translates to:
  /// **'Tell your coach more below if you like. If it is sharp or getting worse, please see a doctor.'**
  String get tellYourCoachMoreBelowIfYou;

  /// No description provided for @anythingYouWantYourCoachToKnow.
  ///
  /// In en, this message translates to:
  /// **'Anything you want your coach to know? (optional)'**
  String get anythingYouWantYourCoachToKnow;

  /// No description provided for @sendToMyCoach.
  ///
  /// In en, this message translates to:
  /// **'Send to my coach'**
  String get sendToMyCoach;

  /// No description provided for @sentYourCoachWillSeeIt.
  ///
  /// In en, this message translates to:
  /// **'Sent. Your coach will see it.'**
  String get sentYourCoachWillSeeIt;

  /// No description provided for @youAlreadySentThisOne.
  ///
  /// In en, this message translates to:
  /// **'You already sent this one.'**
  String get youAlreadySentThisOne;

  /// No description provided for @weCouldNotSendItTryAgain.
  ///
  /// In en, this message translates to:
  /// **'We could not send it. Try again in a moment.'**
  String get weCouldNotSendItTryAgain;

  /// No description provided for @needsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get needsAttention;

  /// No description provided for @noCheckInYet.
  ///
  /// In en, this message translates to:
  /// **'No check-in yet'**
  String get noCheckInYet;

  /// No description provided for @trainingSlippedThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Training slipped this week'**
  String get trainingSlippedThisWeek;

  /// No description provided for @healthAnswerToRead.
  ///
  /// In en, this message translates to:
  /// **'Health answer to read'**
  String get healthAnswerToRead;

  /// No description provided for @unreadMessage.
  ///
  /// In en, this message translates to:
  /// **'Unread message'**
  String get unreadMessage;

  /// No description provided for @areYouPregnantOrDidYouHave.
  ///
  /// In en, this message translates to:
  /// **'Are you pregnant, or did you have a baby in the last 12 months?'**
  String get areYouPregnantOrDidYouHave;

  /// No description provided for @hadABaby.
  ///
  /// In en, this message translates to:
  /// **'Had a baby'**
  String get hadABaby;

  /// No description provided for @hasFoodOrWeightEverFeltOut.
  ///
  /// In en, this message translates to:
  /// **'Has food or weight ever felt out of control or worrying for you?'**
  String get hasFoodOrWeightEverFeltOut;

  /// No description provided for @yourCoachReadsThisFirstYouDo.
  ///
  /// In en, this message translates to:
  /// **'Your coach reads this first. You do not have to say more.'**
  String get yourCoachReadsThisFirstYouDo;

  /// No description provided for @hadABabyInTheLast12.
  ///
  /// In en, this message translates to:
  /// **'Had a baby in the last 12 months'**
  String get hadABabyInTheLast12;

  /// No description provided for @foodOrWeightHasFeltWorrying.
  ///
  /// In en, this message translates to:
  /// **'Food or weight has felt worrying'**
  String get foodOrWeightHasFeltWorrying;

  /// No description provided for @readHerHealthAnswersFirst.
  ///
  /// In en, this message translates to:
  /// **'Read her health answers first'**
  String get readHerHealthAnswersFirst;

  /// No description provided for @plansAreOnHoldUntilYouHave.
  ///
  /// In en, this message translates to:
  /// **'Plans are on hold until you have. Her answers are below.'**
  String get plansAreOnHoldUntilYouHave;

  /// No description provided for @iHaveReadThem.
  ///
  /// In en, this message translates to:
  /// **'I have read them'**
  String get iHaveReadThem;

  /// No description provided for @readHerHealthAnswersFirstOpenHer.
  ///
  /// In en, this message translates to:
  /// **'Read her health answers first. Open her page and tick that you have.'**
  String get readHerHealthAnswersFirstOpenHer;

  /// No description provided for @thisClientsAnswersOnEatingMeanYou.
  ///
  /// In en, this message translates to:
  /// **'This client\'s answers on eating mean you review her first. A plan with calorie or protein targets cannot be sent.'**
  String get thisClientsAnswersOnEatingMeanYou;

  /// No description provided for @dailyTargetForHer.
  ///
  /// In en, this message translates to:
  /// **'Daily target for her'**
  String get dailyTargetForHer;

  /// No description provided for @calories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get calories;

  /// No description provided for @between1200And4000Calories30To.
  ///
  /// In en, this message translates to:
  /// **'Between 1200 and 4000 calories, 30 to 250 g protein.'**
  String get between1200And4000Calories30To;

  /// No description provided for @fillInBothNumbersOrLeaveBoth.
  ///
  /// In en, this message translates to:
  /// **'Fill in both numbers, or leave both empty.'**
  String get fillInBothNumbersOrLeaveBoth;

  /// No description provided for @herAnswersOnEatingMeanYouReview.
  ///
  /// In en, this message translates to:
  /// **'Her answers on eating mean you review her first. You can send a menu without calorie or protein targets.'**
  String get herAnswersOnEatingMeanYouReview;

  /// No description provided for @swaps.
  ///
  /// In en, this message translates to:
  /// **'Swaps'**
  String get swaps;

  /// Number of approved swaps for a meal item
  ///
  /// In en, this message translates to:
  /// **'Swaps ({n})'**
  String swapsN(String n);

  /// No description provided for @approvedSwaps.
  ///
  /// In en, this message translates to:
  /// **'Approved swaps'**
  String get approvedSwaps;

  /// No description provided for @threeAtMost.
  ///
  /// In en, this message translates to:
  /// **'Three at most.'**
  String get threeAtMost;

  /// No description provided for @saveSwaps.
  ///
  /// In en, this message translates to:
  /// **'Save swaps'**
  String get saveSwaps;

  /// Daily target set by coach for client
  ///
  /// In en, this message translates to:
  /// **'Your coach\'s target: {kcal} calories and {protein} g protein'**
  String yourCoachsTargetKcalCaloriesAndProtein(String kcal, String protein);

  /// No description provided for @changeTo.
  ///
  /// In en, this message translates to:
  /// **'Change to'**
  String get changeTo;

  /// No description provided for @thePlannedDish.
  ///
  /// In en, this message translates to:
  /// **'The planned dish'**
  String get thePlannedDish;

  /// No description provided for @forTheWholePlanAsTheDishes.
  ///
  /// In en, this message translates to:
  /// **'For the whole plan, as the dishes are written'**
  String get forTheWholePlanAsTheDishes;

  /// No description provided for @nothingToBuyYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing to buy yet.'**
  String get nothingToBuyYet;

  /// No description provided for @thatFileIsTooBigAPhoto.
  ///
  /// In en, this message translates to:
  /// **'That file is too big. A photo is up to 3 MB and a video is up to 25 MB.'**
  String get thatFileIsTooBigAPhoto;

  /// No description provided for @thisMessageWasHiddenAndWasNot.
  ///
  /// In en, this message translates to:
  /// **'This message was hidden and was not delivered'**
  String get thisMessageWasHiddenAndWasNot;

  /// No description provided for @videosCanBeUpTo30Seconds.
  ///
  /// In en, this message translates to:
  /// **'Videos can be up to 30 seconds. Choose a shorter one.'**
  String get videosCanBeUpTo30Seconds;

  /// No description provided for @weCouldNotPlayThatVideo.
  ///
  /// In en, this message translates to:
  /// **'We could not play that video.'**
  String get weCouldNotPlayThatVideo;

  /// No description provided for @weCouldNotOpenThatPhoto.
  ///
  /// In en, this message translates to:
  /// **'We could not open that photo.'**
  String get weCouldNotOpenThatPhoto;

  /// No description provided for @painOrInjuryThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Pain or injury this week'**
  String get painOrInjuryThisWeek;

  /// No description provided for @inbodyScanData.
  ///
  /// In en, this message translates to:
  /// **'InBody Scan Data'**
  String get inbodyScanData;

  /// No description provided for @pasteScanTextOcr.
  ///
  /// In en, this message translates to:
  /// **'Paste scan text / OCR'**
  String get pasteScanTextOcr;

  /// No description provided for @theseNumbersHelpYourCoachCustomizeYour.
  ///
  /// In en, this message translates to:
  /// **'These numbers help your coach customize your nutrition and training plan.'**
  String get theseNumbersHelpYourCoachCustomizeYour;

  /// No description provided for @pasteInbodyScanTextOcr.
  ///
  /// In en, this message translates to:
  /// **'Paste InBody Scan Text (OCR)'**
  String get pasteInbodyScanTextOcr;

  /// No description provided for @pasteOcrTextHereToAutoExtract.
  ///
  /// In en, this message translates to:
  /// **'Paste OCR text here to auto-extract...'**
  String get pasteOcrTextHereToAutoExtract;

  /// No description provided for @extractMetrics.
  ///
  /// In en, this message translates to:
  /// **'Extract Metrics'**
  String get extractMetrics;

  /// No description provided for @muscleSmmKg.
  ///
  /// In en, this message translates to:
  /// **'Muscle SMM (kg)'**
  String get muscleSmmKg;

  /// No description provided for @bodyFat.
  ///
  /// In en, this message translates to:
  /// **'Body Fat %'**
  String get bodyFat;

  /// No description provided for @bmrKcal.
  ///
  /// In en, this message translates to:
  /// **'BMR (kcal)'**
  String get bmrKcal;

  /// No description provided for @saveScan.
  ///
  /// In en, this message translates to:
  /// **'Save Scan'**
  String get saveScan;

  /// Under a progress bar: how much of the day's target is left, for example 80 g remaining.
  ///
  /// In en, this message translates to:
  /// **'{amount} {unit} remaining'**
  String amountUnitRemaining(String amount, String unit);

  /// No description provided for @targetReached.
  ///
  /// In en, this message translates to:
  /// **'Target reached'**
  String get targetReached;

  /// Screen reader text for a progress bar: name, amount against target, then the status line.
  ///
  /// In en, this message translates to:
  /// **'{label}: {current} of {target} {unit}. {status}.'**
  String labelCurrentOfTargetUnitStatus(
    String label,
    String current,
    String target,
    String unit,
    String status,
  );

  /// Chat attach sheet: the longest video she can send, from the coaching limits.
  ///
  /// In en, this message translates to:
  /// **'Record a video (up to {seconds} seconds)'**
  String recordAVideoUpToSecondsSeconds(String seconds);

  /// Chat: the two size limits, from the coaching limits.
  ///
  /// In en, this message translates to:
  /// **'That file is too big. A photo is up to {photoMb} MB and a video is up to {videoMb} MB.'**
  String thatFileIsTooBigAPhoto_1rnt5(String photoMb, String videoMb);

  /// Chat: the longest video she can send, from the coaching limits.
  ///
  /// In en, this message translates to:
  /// **'Videos can be up to {seconds} seconds. Choose a shorter one.'**
  String videosCanBeUpToSecondsSeconds(String seconds);

  /// No description provided for @yourCoachSetsYourFoodPlanWith.
  ///
  /// In en, this message translates to:
  /// **'Your coach sets your food plan with you. Log what you eat and talk to her about it.'**
  String get yourCoachSetsYourFoodPlanWith;

  /// No description provided for @weNeverSetATargetBelow1.
  ///
  /// In en, this message translates to:
  /// **'We never set a target below 1,200 kcal.'**
  String get weNeverSetATargetBelow1;

  /// No description provided for @weDoNotSetWeightLossTargets.
  ///
  /// In en, this message translates to:
  /// **'We do not set weight-loss targets under 18. Your target keeps your weight where it is. Please talk to your doctor before changing how you eat.'**
  String get weDoNotSetWeightLossTargets;

  /// No description provided for @weDoNotSetWeightLossTargets_14owx.
  ///
  /// In en, this message translates to:
  /// **'We do not set weight-loss targets while you are pregnant or after a birth. Your target keeps your weight where it is. Please talk to your doctor before changing how you eat.'**
  String get weDoNotSetWeightLossTargets_14owx;

  /// No description provided for @forAClientWhoIsPregnantOr.
  ///
  /// In en, this message translates to:
  /// **'For a client who is pregnant or after a birth, the lowest daily goal is 1,800 kcal.'**
  String get forAClientWhoIsPregnantOr;

  /// No description provided for @proteinCanBeAtMost35Of.
  ///
  /// In en, this message translates to:
  /// **'Protein can be at most 35% of the day\'s calories.'**
  String get proteinCanBeAtMost35Of;

  /// No description provided for @pleaseSignInAgainThenTryOnce.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again, then try once more.'**
  String get pleaseSignInAgainThenTryOnce;

  /// No description provided for @theCodeIsNotRightTryAgain.
  ///
  /// In en, this message translates to:
  /// **'The code is not right. Try again.'**
  String get theCodeIsNotRightTryAgain;

  /// No description provided for @theCodeHasExpiredAskForA.
  ///
  /// In en, this message translates to:
  /// **'The code has expired. Ask for a new one.'**
  String get theCodeHasExpiredAskForA;

  /// No description provided for @tooManyTriesPleaseWaitAWhile.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Please wait a while.'**
  String get tooManyTriesPleaseWaitAWhile;

  /// No description provided for @thisPaymentChangedRefreshAndTryAgain.
  ///
  /// In en, this message translates to:
  /// **'This payment changed. Refresh and try again.'**
  String get thisPaymentChangedRefreshAndTryAgain;

  /// No description provided for @weCouldNotDoThatTryAgain.
  ///
  /// In en, this message translates to:
  /// **'We could not do that. Try again in a moment.'**
  String get weCouldNotDoThatTryAgain;

  /// No description provided for @thatLooksLikeAPhoneNumberUse.
  ///
  /// In en, this message translates to:
  /// **'That looks like a phone number. Use your @ address instead.'**
  String get thatLooksLikeAPhoneNumberUse;

  /// No description provided for @thisTransactionNumberWasAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'This transaction number was already used.'**
  String get thisTransactionNumberWasAlreadyUsed;

  /// No description provided for @youHaveSentTooManyPicturesFor.
  ///
  /// In en, this message translates to:
  /// **'You have sent too many pictures for this payment.'**
  String get youHaveSentTooManyPicturesFor;

  /// No description provided for @weCouldNotUseThatPicturePick.
  ///
  /// In en, this message translates to:
  /// **'We could not use that picture. Pick another.'**
  String get weCouldNotUseThatPicturePick;

  /// No description provided for @theTimeToSendAProofFor.
  ///
  /// In en, this message translates to:
  /// **'The time to send a proof for this payment has passed. Message your coach.'**
  String get theTimeToSendAProofFor;

  /// No description provided for @yourCoachCannotTakePaymentsHereRight.
  ///
  /// In en, this message translates to:
  /// **'Your coach cannot take payments here right now. Message her.'**
  String get yourCoachCannotTakePaymentsHereRight;

  /// No description provided for @paymentsByInstapayAreNotAvailableOn.
  ///
  /// In en, this message translates to:
  /// **'Payments by InstaPay are not available on your account right now. Please write to support.'**
  String get paymentsByInstapayAreNotAvailableOn;

  /// No description provided for @thisAmountIsAboveWhatInstapayAllows.
  ///
  /// In en, this message translates to:
  /// **'This amount is above what InstaPay allows here. Message your coach to agree another way.'**
  String get thisAmountIsAboveWhatInstapayAllows;

  /// No description provided for @forYourFirstPaymentPleaseChooseYour.
  ///
  /// In en, this message translates to:
  /// **'For your first payment, please choose your coach\'s shortest package. Message her if you want a longer one.'**
  String get forYourFirstPaymentPleaseChooseYour;

  /// No description provided for @youAlreadyHaveAPaymentOpenOpen.
  ///
  /// In en, this message translates to:
  /// **'You already have a payment open. Open it from your coach page.'**
  String get youAlreadyHaveAPaymentOpenOpen;

  /// No description provided for @paymentsArePausedForAMomentPlease.
  ///
  /// In en, this message translates to:
  /// **'Payments are paused for a moment. Please try again later.'**
  String get paymentsArePausedForAMomentPlease;

  /// No description provided for @myInstapayAddress.
  ///
  /// In en, this message translates to:
  /// **'My InstaPay address'**
  String get myInstapayAddress;

  /// No description provided for @whereClientsPayYou.
  ///
  /// In en, this message translates to:
  /// **'Where clients pay you'**
  String get whereClientsPayYou;

  /// No description provided for @yourInstapayAddress.
  ///
  /// In en, this message translates to:
  /// **'Your InstaPay address'**
  String get yourInstapayAddress;

  /// No description provided for @clientsPayYouDirectlyOwnHubNever.
  ///
  /// In en, this message translates to:
  /// **'Clients pay you directly. Own Hub never holds the money.'**
  String get clientsPayYouDirectlyOwnHubNever;

  /// When the coach's new InstaPay address starts.
  ///
  /// In en, this message translates to:
  /// **'Your new address starts working at {time}.'**
  String yourNewAddressStartsWorkingAtTime(String time);

  /// No description provided for @instapayAddress.
  ///
  /// In en, this message translates to:
  /// **'InstaPay address'**
  String get instapayAddress;

  /// No description provided for @useYourAddressNotAPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Use your @ address, not a phone number. A phone number would show on every client\'s receipt.'**
  String get useYourAddressNotAPhoneNumber;

  /// No description provided for @thatDoesNotLookLikeAnInstapay.
  ///
  /// In en, this message translates to:
  /// **'That does not look like an InstaPay address. It looks like name@instapay.'**
  String get thatDoesNotLookLikeAnInstapay;

  /// No description provided for @accountNameExactlyAsYourBankShows.
  ///
  /// In en, this message translates to:
  /// **'Account name, exactly as your bank shows it'**
  String get accountNameExactlyAsYourBankShows;

  /// No description provided for @aNewAddressStartsWorkingAfter24.
  ///
  /// In en, this message translates to:
  /// **'A new address starts working after 24 hours. Clients with a payment waiting keep paying the old one, and we tell them.'**
  String get aNewAddressStartsWorkingAfter24;

  /// No description provided for @code.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get code;

  /// No description provided for @weSentACodeToYourPhone.
  ///
  /// In en, this message translates to:
  /// **'We sent a code to your phone. Type it to confirm it is you.'**
  String get weSentACodeToYourPhone;

  /// No description provided for @yourAddressIsSavedAndReady.
  ///
  /// In en, this message translates to:
  /// **'Your address is saved and ready.'**
  String get yourAddressIsSavedAndReady;

  /// No description provided for @yourCoachAcceptedYouPayToStart.
  ///
  /// In en, this message translates to:
  /// **'Your coach accepted you. Pay to start.'**
  String get yourCoachAcceptedYouPayToStart;

  /// No description provided for @payNow.
  ///
  /// In en, this message translates to:
  /// **'Pay now'**
  String get payNow;

  /// No description provided for @payYourCoach.
  ///
  /// In en, this message translates to:
  /// **'Pay your coach'**
  String get payYourCoach;

  /// No description provided for @payExactly.
  ///
  /// In en, this message translates to:
  /// **'Pay exactly'**
  String get payExactly;

  /// No description provided for @payTo.
  ///
  /// In en, this message translates to:
  /// **'Pay to'**
  String get payTo;

  /// The coach's account name to check on the bank screen.
  ///
  /// In en, this message translates to:
  /// **'{name} (name as shown by your bank)'**
  String nameNameAsShownByYourBank(String name);

  /// No description provided for @reference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get reference;

  /// No description provided for @putTheReferenceInTheTransferNote.
  ///
  /// In en, this message translates to:
  /// **'Put the reference in the transfer note if your bank has one.'**
  String get putTheReferenceInTheTransferNote;

  /// No description provided for @n1OpenYourBankAppAndChoose.
  ///
  /// In en, this message translates to:
  /// **'1. Open your bank app and choose InstaPay.'**
  String get n1OpenYourBankAppAndChoose;

  /// No description provided for @n2SendTheExactAmountToThe.
  ///
  /// In en, this message translates to:
  /// **'2. Send the exact amount to the address above.'**
  String get n2SendTheExactAmountToThe;

  /// No description provided for @n3ComeBackHereAndTapI.
  ///
  /// In en, this message translates to:
  /// **'3. Come back here and tap I have paid.'**
  String get n3ComeBackHereAndTapI;

  /// Countdown to the end of a payment request.
  ///
  /// In en, this message translates to:
  /// **'Time left {time}'**
  String timeLeftTime(String time);

  /// No description provided for @thisRequestHasExpiredIfYouAlready.
  ///
  /// In en, this message translates to:
  /// **'This request has expired. If you already paid, you can still send your proof for 7 days.'**
  String get thisRequestHasExpiredIfYouAlready;

  /// No description provided for @ownHubCannotUndoAnInstapayTransfer.
  ///
  /// In en, this message translates to:
  /// **'Own Hub cannot undo an InstaPay transfer. Before you send, check that the name on your bank\'s confirmation screen matches the name above.'**
  String get ownHubCannotUndoAnInstapayTransfer;

  /// No description provided for @iHavePaid.
  ///
  /// In en, this message translates to:
  /// **'I have paid'**
  String get iHavePaid;

  /// No description provided for @yourCoachHasNotSetUpPayments.
  ///
  /// In en, this message translates to:
  /// **'Your coach has not set up payments yet. Message her.'**
  String get yourCoachHasNotSetUpPayments;

  /// No description provided for @copyAmount.
  ///
  /// In en, this message translates to:
  /// **'Copy amount'**
  String get copyAmount;

  /// No description provided for @copyAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get copyAddress;

  /// No description provided for @copyReference.
  ///
  /// In en, this message translates to:
  /// **'Copy reference'**
  String get copyReference;

  /// No description provided for @openInstapay.
  ///
  /// In en, this message translates to:
  /// **'Open InstaPay'**
  String get openInstapay;

  /// No description provided for @theAmountIsCopiedOpenYourBank.
  ///
  /// In en, this message translates to:
  /// **'The amount is copied. Open your bank app and choose InstaPay.'**
  String get theAmountIsCopiedOpenYourBank;

  /// No description provided for @hidePrivateDetails.
  ///
  /// In en, this message translates to:
  /// **'Hide private details'**
  String get hidePrivateDetails;

  /// No description provided for @dragOverAnythingPrivateLikeCardNumbers.
  ///
  /// In en, this message translates to:
  /// **'Drag over anything private, like card numbers or balances. The amount, transaction number and name stay visible.'**
  String get dragOverAnythingPrivateLikeCardNumbers;

  /// No description provided for @blackOut.
  ///
  /// In en, this message translates to:
  /// **'Black out'**
  String get blackOut;

  /// No description provided for @crop.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get crop;

  /// No description provided for @useThisPicture.
  ///
  /// In en, this message translates to:
  /// **'Use this picture'**
  String get useThisPicture;

  /// No description provided for @thatPartIsNeededToCheckYour.
  ///
  /// In en, this message translates to:
  /// **'That part is needed to check your payment.'**
  String get thatPartIsNeededToCheckYour;

  /// No description provided for @onlyTheHiddenDetailCopyLeavesYour.
  ///
  /// In en, this message translates to:
  /// **'Only the hidden-detail copy leaves your phone. The original stays here.'**
  String get onlyTheHiddenDetailCopyLeavesYour;

  /// No description provided for @thisPictureIsTooBigOrCould.
  ///
  /// In en, this message translates to:
  /// **'This picture is too big or could not be read. Pick another.'**
  String get thisPictureIsTooBigOrCould;

  /// No description provided for @sendYourProof.
  ///
  /// In en, this message translates to:
  /// **'Send your proof'**
  String get sendYourProof;

  /// No description provided for @addYourBankScreenshotsTheReceiptAnd.
  ///
  /// In en, this message translates to:
  /// **'Add your bank screenshots: the receipt, and the one with More Details open.'**
  String get addYourBankScreenshotsTheReceiptAnd;

  /// No description provided for @chooseScreenshots.
  ///
  /// In en, this message translates to:
  /// **'Choose screenshots'**
  String get chooseScreenshots;

  /// No description provided for @youCanHidePrivateDetailsBeforeAnything.
  ///
  /// In en, this message translates to:
  /// **'You can hide private details before anything is sent.'**
  String get youCanHidePrivateDetailsBeforeAnything;

  /// No description provided for @paymentAmount.
  ///
  /// In en, this message translates to:
  /// **'Payment amount'**
  String get paymentAmount;

  /// No description provided for @transactionNumber.
  ///
  /// In en, this message translates to:
  /// **'Transaction number'**
  String get transactionNumber;

  /// No description provided for @notFoundYet.
  ///
  /// In en, this message translates to:
  /// **'Not found yet'**
  String get notFoundYet;

  /// How many screenshots she picked.
  ///
  /// In en, this message translates to:
  /// **'Pictures added: {count}'**
  String picturesAddedCount(String count);

  /// No description provided for @yourOwnInstapayAddress.
  ///
  /// In en, this message translates to:
  /// **'Your own InstaPay address'**
  String get yourOwnInstapayAddress;

  /// No description provided for @weUseItToMatchYourReceipt.
  ///
  /// In en, this message translates to:
  /// **'We use it to match your receipt. Asked once.'**
  String get weUseItToMatchYourReceipt;

  /// No description provided for @aPhoneNumberWouldShowOnYour.
  ///
  /// In en, this message translates to:
  /// **'A phone number would show on your coach\'s receipt. Use your @ address if you have one.'**
  String get aPhoneNumberWouldShowOnYour;

  /// No description provided for @sendToCoach.
  ///
  /// In en, this message translates to:
  /// **'Send to coach'**
  String get sendToCoach;

  /// No description provided for @everythingMatchesTapSend.
  ///
  /// In en, this message translates to:
  /// **'Everything matches. Tap send.'**
  String get everythingMatchesTapSend;

  /// No description provided for @weCouldNotReadEverythingAddThe.
  ///
  /// In en, this message translates to:
  /// **'We could not read everything. Add the screenshot with More Details open, or type the transaction number.'**
  String get weCouldNotReadEverythingAddThe;

  /// No description provided for @thisDoesNotMatchYourPaymentYou.
  ///
  /// In en, this message translates to:
  /// **'This does not match your payment. You can still send it and Own Hub will check.'**
  String get thisDoesNotMatchYourPaymentYou;

  /// No description provided for @thisLooksLikeACardMessageNot.
  ///
  /// In en, this message translates to:
  /// **'This looks like a card message, not an InstaPay transfer receipt. Please send the transfer receipt.'**
  String get thisLooksLikeACardMessageNot;

  /// No description provided for @weNeedALittleMoreToCheck.
  ///
  /// In en, this message translates to:
  /// **'We need a little more to check your payment. Add the screenshot with More Details open, or type the transaction number.'**
  String get weNeedALittleMoreToCheck;

  /// No description provided for @weCouldNotReadTheAmountPick.
  ///
  /// In en, this message translates to:
  /// **'We could not read the amount. Pick a clearer screenshot or type the transaction number.'**
  String get weCouldNotReadTheAmountPick;

  /// No description provided for @thisPaymentCameFromADifferentInstapay.
  ///
  /// In en, this message translates to:
  /// **'This payment came from a different InstaPay address than yours. If someone else paid for you, tap the button below.'**
  String get thisPaymentCameFromADifferentInstapay;

  /// No description provided for @yesSomeoneElsePaidForMe.
  ///
  /// In en, this message translates to:
  /// **'Yes, someone else paid for me'**
  String get yesSomeoneElsePaidForMe;

  /// No description provided for @weCouldNotSeeYourReferenceOn.
  ///
  /// In en, this message translates to:
  /// **'We could not see your reference on the receipt. Add the screenshot that shows the transfer note, or send again.'**
  String get weCouldNotSeeYourReferenceOn;

  /// No description provided for @weCouldNotReadThisClearlyPick.
  ///
  /// In en, this message translates to:
  /// **'We could not read this clearly. Pick a clearer screenshot or type the transaction number.'**
  String get weCouldNotReadThisClearlyPick;

  /// No description provided for @savedWeWillSendItWhenYou.
  ///
  /// In en, this message translates to:
  /// **'Saved. We will send it when you have signal.'**
  String get savedWeWillSendItWhenYou;

  /// No description provided for @helpImproveReceiptReading.
  ///
  /// In en, this message translates to:
  /// **'Help improve receipt reading?'**
  String get helpImproveReceiptReading;

  /// No description provided for @weKeepOnlyTheTextFieldsWe.
  ///
  /// In en, this message translates to:
  /// **'We keep only the text fields we read, never your picture. You can say no.'**
  String get weKeepOnlyTheTextFieldsWe;

  /// No description provided for @yesHelp.
  ///
  /// In en, this message translates to:
  /// **'Yes, help'**
  String get yesHelp;

  /// No description provided for @noThanks.
  ///
  /// In en, this message translates to:
  /// **'No thanks'**
  String get noThanks;

  /// No description provided for @yourPayment.
  ///
  /// In en, this message translates to:
  /// **'Your payment'**
  String get yourPayment;

  /// No description provided for @waitingForYourPayment.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your payment'**
  String get waitingForYourPayment;

  /// No description provided for @proofSent.
  ///
  /// In en, this message translates to:
  /// **'Proof sent'**
  String get proofSent;

  /// No description provided for @paymentConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Payment confirmed'**
  String get paymentConfirmed;

  /// No description provided for @confirmedAfterReview.
  ///
  /// In en, this message translates to:
  /// **'Confirmed after review'**
  String get confirmedAfterReview;

  /// No description provided for @yourCoachSaysItHasNotArrived.
  ///
  /// In en, this message translates to:
  /// **'Your coach says it has not arrived'**
  String get yourCoachSaysItHasNotArrived;

  /// No description provided for @reviewDone.
  ///
  /// In en, this message translates to:
  /// **'Review done'**
  String get reviewDone;

  /// No description provided for @differentAmount.
  ///
  /// In en, this message translates to:
  /// **'Different amount'**
  String get differentAmount;

  /// No description provided for @theRequestExpired.
  ///
  /// In en, this message translates to:
  /// **'The request expired'**
  String get theRequestExpired;

  /// No description provided for @paymentCancelled.
  ///
  /// In en, this message translates to:
  /// **'Payment cancelled'**
  String get paymentCancelled;

  /// No description provided for @refundAsked.
  ///
  /// In en, this message translates to:
  /// **'Refund asked'**
  String get refundAsked;

  /// No description provided for @refundRecorded.
  ///
  /// In en, this message translates to:
  /// **'Refund recorded'**
  String get refundRecorded;

  /// No description provided for @refundNotAgreed.
  ///
  /// In en, this message translates to:
  /// **'Refund not agreed'**
  String get refundNotAgreed;

  /// No description provided for @problemReported.
  ///
  /// In en, this message translates to:
  /// **'Problem reported'**
  String get problemReported;

  /// No description provided for @payWithYourBankAppThenTap.
  ///
  /// In en, this message translates to:
  /// **'Pay with your bank app, then tap I have paid.'**
  String get payWithYourBankAppThenTap;

  /// No description provided for @yourCoachWillConfirmIfSheDoes.
  ///
  /// In en, this message translates to:
  /// **'Your coach will confirm. If she does not answer in 3 days, Own Hub reviews it.'**
  String get yourCoachWillConfirmIfSheDoes;

  /// No description provided for @allSetYourCoachingIsActive.
  ///
  /// In en, this message translates to:
  /// **'All set. Your coaching is active.'**
  String get allSetYourCoachingIsActive;

  /// No description provided for @addYourBanksTransactionScreenshotAndOwn.
  ///
  /// In en, this message translates to:
  /// **'Add your bank\'s transaction screenshot and Own Hub will look at it.'**
  String get addYourBanksTransactionScreenshotAndOwn;

  /// No description provided for @ownHubIsLookingAtBothSides.
  ///
  /// In en, this message translates to:
  /// **'Own Hub is looking at both sides. This usually takes up to two working days.'**
  String get ownHubIsLookingAtBothSides;

  /// No description provided for @weCouldNotFindThePaymentIf.
  ///
  /// In en, this message translates to:
  /// **'We could not find the payment. If you think this is wrong, write to support.'**
  String get weCouldNotFindThePaymentIf;

  /// Shown when the coach received less than the price.
  ///
  /// In en, this message translates to:
  /// **'Your coach received {amount}. Pay the rest to start.'**
  String yourCoachReceivedAmountPayTheRest(String amount);

  /// Shown when the coach takes a lower amount in writing.
  ///
  /// In en, this message translates to:
  /// **'Your coach accepted {amount} instead. Do you agree?'**
  String yourCoachAcceptedAmountInsteadDoYou(String amount);

  /// No description provided for @ifYouAlreadyPaidYouCanSend.
  ///
  /// In en, this message translates to:
  /// **'If you already paid, you can send your proof for 7 days.'**
  String get ifYouAlreadyPaidYouCanSend;

  /// No description provided for @nothingWasPaid.
  ///
  /// In en, this message translates to:
  /// **'Nothing was paid.'**
  String get nothingWasPaid;

  /// No description provided for @yourCoachHas3DaysToAnswer.
  ///
  /// In en, this message translates to:
  /// **'Your coach has 3 days to answer. Then Own Hub steps in.'**
  String get yourCoachHas3DaysToAnswer;

  /// No description provided for @yourCoachRecordedTheRefund.
  ///
  /// In en, this message translates to:
  /// **'Your coach recorded the refund.'**
  String get yourCoachRecordedTheRefund;

  /// No description provided for @ownHubWillLookAtIt.
  ///
  /// In en, this message translates to:
  /// **'Own Hub will look at it.'**
  String get ownHubWillLookAtIt;

  /// No description provided for @ownHubIsLookingIntoIt.
  ///
  /// In en, this message translates to:
  /// **'Own Hub is looking into it.'**
  String get ownHubIsLookingIntoIt;

  /// No description provided for @yourCoachIsCheckingHerBankThis.
  ///
  /// In en, this message translates to:
  /// **'Your coach is checking her bank. This can take up to a day.'**
  String get yourCoachIsCheckingHerBankThis;

  /// No description provided for @weCouldNotMatchThisPaymentAdd.
  ///
  /// In en, this message translates to:
  /// **'We could not match this payment. Add your bank\'s transaction history and Own Hub will look at it.'**
  String get weCouldNotMatchThisPaymentAdd;

  /// Bounded access while the coach confirms.
  ///
  /// In en, this message translates to:
  /// **'You can start now. This stays open until {date} while your coach confirms.'**
  String youCanStartNowThisStaysOpen(String date);

  /// The coach reported a payment for the client to confirm.
  ///
  /// In en, this message translates to:
  /// **'Your coach says you paid {reference}. Is that right?'**
  String yourCoachSaysYouPaidReferenceIs(String reference);

  /// No description provided for @yesIPaid.
  ///
  /// In en, this message translates to:
  /// **'Yes, I paid'**
  String get yesIPaid;

  /// No description provided for @paymentRequestCreated.
  ///
  /// In en, this message translates to:
  /// **'Payment request created'**
  String get paymentRequestCreated;

  /// No description provided for @youSentYourProof.
  ///
  /// In en, this message translates to:
  /// **'You sent your proof'**
  String get youSentYourProof;

  /// No description provided for @yourCoachConfirmedIt.
  ///
  /// In en, this message translates to:
  /// **'Your coach confirmed it'**
  String get yourCoachConfirmedIt;

  /// No description provided for @youConfirmedIt.
  ///
  /// In en, this message translates to:
  /// **'You confirmed it'**
  String get youConfirmedIt;

  /// No description provided for @ownHubStartedAReview.
  ///
  /// In en, this message translates to:
  /// **'Own Hub started a review'**
  String get ownHubStartedAReview;

  /// No description provided for @reviewDoneYourPaymentCounts.
  ///
  /// In en, this message translates to:
  /// **'Review done: your payment counts'**
  String get reviewDoneYourPaymentCounts;

  /// No description provided for @reviewDoneWeCouldNotFindThe.
  ///
  /// In en, this message translates to:
  /// **'Review done: we could not find the payment'**
  String get reviewDoneWeCouldNotFindThe;

  /// No description provided for @yourCoachReceivedADifferentAmount.
  ///
  /// In en, this message translates to:
  /// **'Your coach received a different amount'**
  String get yourCoachReceivedADifferentAmount;

  /// No description provided for @youAskedForARefund.
  ///
  /// In en, this message translates to:
  /// **'You asked for a refund'**
  String get youAskedForARefund;

  /// No description provided for @youReportedAProblemWithTheService.
  ///
  /// In en, this message translates to:
  /// **'You reported a problem with the service'**
  String get youReportedAProblemWithTheService;

  /// No description provided for @yourCoachSaysYouPaidPleaseCheck.
  ///
  /// In en, this message translates to:
  /// **'Your coach says you paid. Please check.'**
  String get yourCoachSaysYouPaidPleaseCheck;

  /// No description provided for @sendMyProof.
  ///
  /// In en, this message translates to:
  /// **'Send my proof'**
  String get sendMyProof;

  /// No description provided for @payTheRest.
  ///
  /// In en, this message translates to:
  /// **'Pay the rest'**
  String get payTheRest;

  /// No description provided for @addProof.
  ///
  /// In en, this message translates to:
  /// **'Add proof'**
  String get addProof;

  /// No description provided for @openMyCoaching.
  ///
  /// In en, this message translates to:
  /// **'Open my coaching'**
  String get openMyCoaching;

  /// No description provided for @iAgree.
  ///
  /// In en, this message translates to:
  /// **'I agree'**
  String get iAgree;

  /// No description provided for @iDoNotAgree.
  ///
  /// In en, this message translates to:
  /// **'I do not agree'**
  String get iDoNotAgree;

  /// No description provided for @yourPaymentIsOnItsWay.
  ///
  /// In en, this message translates to:
  /// **'Your payment is on its way'**
  String get yourPaymentIsOnItsWay;

  /// No description provided for @seeYourPayment.
  ///
  /// In en, this message translates to:
  /// **'See your payment'**
  String get seeYourPayment;

  /// No description provided for @addAScreenshotOfYourBanksTransaction.
  ///
  /// In en, this message translates to:
  /// **'Add a screenshot of your bank\'s transaction or receipt. You can hide private details first.'**
  String get addAScreenshotOfYourBanksTransaction;

  /// No description provided for @sentOwnHubWillLookAtIt.
  ///
  /// In en, this message translates to:
  /// **'Sent. Own Hub will look at it.'**
  String get sentOwnHubWillLookAtIt;

  /// Coach InstaPay address screen: how long a new address waits before it works. hours is the server's address delay.
  ///
  /// In en, this message translates to:
  /// **'A new address starts working after {hours} hours. Clients with a payment waiting keep paying the old one, and we tell them.'**
  String aNewAddressStartsWorkingAfterHours(String hours);

  /// Meal plan editor: why a goal is refused for a pregnant or postpartum client. kcal is the stage floor from the calorie safety rules, with thousands separators.
  ///
  /// In en, this message translates to:
  /// **'For a client who is pregnant or after a birth, the lowest daily goal is {kcal} kcal.'**
  String forAClientWhoIsPregnantOr_7nnjm(String kcal);

  /// No description provided for @openYourBankAppAndChooseInstapay.
  ///
  /// In en, this message translates to:
  /// **'Open your bank app and choose InstaPay.'**
  String get openYourBankAppAndChooseInstapay;

  /// No description provided for @sendTheExactAmountToTheAddress.
  ///
  /// In en, this message translates to:
  /// **'Send the exact amount to the address above.'**
  String get sendTheExactAmountToTheAddress;

  /// No description provided for @comeBackHereAndTapIHave.
  ///
  /// In en, this message translates to:
  /// **'Come back here and tap I have paid.'**
  String get comeBackHereAndTapIHave;

  /// Meal plan editor: why a protein goal is refused. percent is the largest protein share from the calorie safety rules.
  ///
  /// In en, this message translates to:
  /// **'Protein can be at most {percent}% of the day\'s calories.'**
  String proteinCanBeAtMostPercentOf(String percent);

  /// Payment screen after the 24 hour request ran out. days is how long a late proof is still accepted.
  ///
  /// In en, this message translates to:
  /// **'This request has expired. If you already paid, you can still send your proof for {days} days.'**
  String thisRequestHasExpiredIfYouAlready_1azdp(String days);

  /// Eat tab note for a woman under the adult age. age is the adult age from the calorie safety rules.
  ///
  /// In en, this message translates to:
  /// **'We do not set weight-loss targets under {age}. Your target keeps your weight where it is. Please talk to your doctor before changing how you eat.'**
  String weDoNotSetWeightLossTargets_1kp41(String age);

  /// Eat tab note when her target was lifted to the floor. kcal is the floor from the calorie safety rules, with thousands separators.
  ///
  /// In en, this message translates to:
  /// **'We never set a target below {kcal} kcal.'**
  String weNeverSetATargetBelowKcal(String kcal);

  /// No description provided for @payments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get payments;

  /// No description provided for @paymentsFromYourClients.
  ///
  /// In en, this message translates to:
  /// **'Payments from your clients'**
  String get paymentsFromYourClients;

  /// No description provided for @addYourInstapayAddressSoClientsCan.
  ///
  /// In en, this message translates to:
  /// **'Add your InstaPay address so clients can pay you.'**
  String get addYourInstapayAddressSoClientsCan;

  /// No description provided for @addAddress.
  ///
  /// In en, this message translates to:
  /// **'Add address'**
  String get addAddress;

  /// No description provided for @waitingForYou.
  ///
  /// In en, this message translates to:
  /// **'Waiting for you'**
  String get waitingForYou;

  /// No description provided for @nothingIsWaitingForYou.
  ///
  /// In en, this message translates to:
  /// **'Nothing is waiting for you.'**
  String get nothingIsWaitingForYou;

  /// No description provided for @earlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get earlier;

  /// No description provided for @matches.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get matches;

  /// No description provided for @checkYourBank.
  ///
  /// In en, this message translates to:
  /// **'Check your bank'**
  String get checkYourBank;

  /// A waiting payment in the coach's inbox: her reference, the amount and when the proof came.
  ///
  /// In en, this message translates to:
  /// **'{reference} · {amount} · proof sent {time}'**
  String referenceAmountProofSentTime(
    String reference,
    String amount,
    String time,
  );

  /// Title of the coach's decision sheet.
  ///
  /// In en, this message translates to:
  /// **'Payment {reference}'**
  String paymentReference(String reference);

  /// What the coach looks for in her bank.
  ///
  /// In en, this message translates to:
  /// **'Look for exactly {amount}'**
  String lookForExactlyAmount(String amount);

  /// The number read from the client's proof.
  ///
  /// In en, this message translates to:
  /// **'Transaction number {txn}'**
  String transactionNumberTxn(String txn);

  /// When the client says she paid.
  ///
  /// In en, this message translates to:
  /// **'Paid at {time}'**
  String paidAtTime(String time);

  /// No description provided for @herProofLooksRightStillCheckYour.
  ///
  /// In en, this message translates to:
  /// **'Her proof looks right. Still check your bank before you confirm.'**
  String get herProofLooksRightStillCheckYour;

  /// No description provided for @partOfHerProofDidNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Part of her proof did not match. Check your bank closely.'**
  String get partOfHerProofDidNotMatch;

  /// No description provided for @seeHerProof.
  ///
  /// In en, this message translates to:
  /// **'See her proof'**
  String get seeHerProof;

  /// No description provided for @weCouldNotLoadThisPicture.
  ///
  /// In en, this message translates to:
  /// **'We could not load this picture.'**
  String get weCouldNotLoadThisPicture;

  /// No description provided for @iReceivedIt.
  ///
  /// In en, this message translates to:
  /// **'I received it'**
  String get iReceivedIt;

  /// No description provided for @notReceived.
  ///
  /// In en, this message translates to:
  /// **'Not received'**
  String get notReceived;

  /// No description provided for @confirmedYourClientCanStart.
  ///
  /// In en, this message translates to:
  /// **'Confirmed. Your client can start.'**
  String get confirmedYourClientCanStart;

  /// No description provided for @whatDoYouSeeInYourBank.
  ///
  /// In en, this message translates to:
  /// **'What do you see in your bank?'**
  String get whatDoYouSeeInYourBank;

  /// No description provided for @iDoNotSeeItInMy.
  ///
  /// In en, this message translates to:
  /// **'I do not see it in my account'**
  String get iDoNotSeeItInMy;

  /// No description provided for @theAmountIsDifferent.
  ///
  /// In en, this message translates to:
  /// **'The amount is different'**
  String get theAmountIsDifferent;

  /// No description provided for @theNameIsDifferent.
  ///
  /// In en, this message translates to:
  /// **'The name is different'**
  String get theNameIsDifferent;

  /// No description provided for @someoneElsePaid.
  ///
  /// In en, this message translates to:
  /// **'Someone else paid'**
  String get someoneElsePaid;

  /// The tick on Not received.
  ///
  /// In en, this message translates to:
  /// **'I searched my bank for {amount}.'**
  String iSearchedMyBankForAmount(String amount);

  /// The tick on Not received when the number was read.
  ///
  /// In en, this message translates to:
  /// **'I searched my bank for {amount} and transaction number {txn}.'**
  String iSearchedMyBankForAmountAnd(String amount, String txn);

  /// No description provided for @tellUsWhatYouSaw.
  ///
  /// In en, this message translates to:
  /// **'Tell us what you saw'**
  String get tellUsWhatYouSaw;

  /// No description provided for @addYourBankListForThatDay.
  ///
  /// In en, this message translates to:
  /// **'Add your bank list for that day'**
  String get addYourBankListForThatDay;

  /// No description provided for @howMuchDidYouReceive.
  ///
  /// In en, this message translates to:
  /// **'How much did you receive?'**
  String get howMuchDidYouReceive;

  /// No description provided for @amountReceivedEgp.
  ///
  /// In en, this message translates to:
  /// **'Amount received (EGP)'**
  String get amountReceivedEgp;

  /// No description provided for @acceptThisLowerAmountAndStartThe.
  ///
  /// In en, this message translates to:
  /// **'Accept this lower amount and start the coaching'**
  String get acceptThisLowerAmountAndStartThe;

  /// No description provided for @ifYouAcceptHerPackageStartsOtherwise.
  ///
  /// In en, this message translates to:
  /// **'If you accept, her package starts. Otherwise she can pay the rest.'**
  String get ifYouAcceptHerPackageStartsOtherwise;

  /// No description provided for @sentYourClientWillSeeIt.
  ///
  /// In en, this message translates to:
  /// **'Sent. Your client will see it.'**
  String get sentYourClientWillSeeIt;

  /// No description provided for @confirmMatchingPaymentsForMe.
  ///
  /// In en, this message translates to:
  /// **'Confirm matching payments for me'**
  String get confirmMatchingPaymentsForMe;

  /// Under the auto-confirm switch. The hours are the server's window.
  ///
  /// In en, this message translates to:
  /// **'Only payments that match. You can still flag one within {hours} hours.'**
  String onlyPaymentsThatMatchYouCanStill(String hours);

  /// Why the auto-confirm switch was refused.
  ///
  /// In en, this message translates to:
  /// **'Automatic confirming opens after {n} payments that matched.'**
  String automaticConfirmingOpensAfterNPaymentsThat(String n);

  /// No description provided for @automaticConfirmingIsNotAvailableToYou.
  ///
  /// In en, this message translates to:
  /// **'Automatic confirming is not available to you yet.'**
  String get automaticConfirmingIsNotAvailableToYou;

  /// No description provided for @thisPaymentAppearsInYourStatementPlease.
  ///
  /// In en, this message translates to:
  /// **'This payment appears in your statement. Please check again.'**
  String get thisPaymentAppearsInYourStatementPlease;

  /// No description provided for @pleaseTickThatYouSearchedYourBank.
  ///
  /// In en, this message translates to:
  /// **'Please tick that you searched your bank and add your bank list.'**
  String get pleaseTickThatYouSearchedYourBank;

  /// No description provided for @pleaseTellUsWhatYouSawIn.
  ///
  /// In en, this message translates to:
  /// **'Please tell us what you saw, in a few words.'**
  String get pleaseTellUsWhatYouSawIn;

  /// No description provided for @thatIsTooFarBelowThePrice.
  ///
  /// In en, this message translates to:
  /// **'That is too far below the price to accept. Turn the switch off and she can pay the rest.'**
  String get thatIsTooFarBelowThePrice;

  /// No description provided for @aClientPaidMe.
  ///
  /// In en, this message translates to:
  /// **'A client paid me'**
  String get aClientPaidMe;

  /// No description provided for @pickThePaymentThenTypeTheTransaction.
  ///
  /// In en, this message translates to:
  /// **'Pick the payment, then type the transaction number from your bank.'**
  String get pickThePaymentThenTypeTheTransaction;

  /// No description provided for @noClientHasAnOpenPaymentRight.
  ///
  /// In en, this message translates to:
  /// **'No client has an open payment right now.'**
  String get noClientHasAnOpenPaymentRight;

  /// No description provided for @sentYourClientWillBeAskedTo.
  ///
  /// In en, this message translates to:
  /// **'Sent. Your client will be asked to confirm.'**
  String get sentYourClientWillBeAskedTo;

  /// No description provided for @waitingForHerPayment.
  ///
  /// In en, this message translates to:
  /// **'Waiting for her payment'**
  String get waitingForHerPayment;

  /// No description provided for @youSaidItHasNotArrived.
  ///
  /// In en, this message translates to:
  /// **'You said it has not arrived'**
  String get youSaidItHasNotArrived;

  /// No description provided for @sheAskedForARefund.
  ///
  /// In en, this message translates to:
  /// **'She asked for a refund'**
  String get sheAskedForARefund;

  /// No description provided for @askForARefund.
  ///
  /// In en, this message translates to:
  /// **'Ask for a refund'**
  String get askForARefund;

  /// No description provided for @iHaveAProblemWithTheService.
  ///
  /// In en, this message translates to:
  /// **'I have a problem with the service'**
  String get iHaveAProblemWithTheService;

  /// No description provided for @theRefundDidNotReachMe.
  ///
  /// In en, this message translates to:
  /// **'The refund did not reach me'**
  String get theRefundDidNotReachMe;

  /// No description provided for @askOwnHubToLookAgain.
  ///
  /// In en, this message translates to:
  /// **'Ask Own Hub to look again'**
  String get askOwnHubToLookAgain;

  /// No description provided for @cancelPayment.
  ///
  /// In en, this message translates to:
  /// **'Cancel payment'**
  String get cancelPayment;

  /// No description provided for @cancelThisPaymentOnlyDoThisIf.
  ///
  /// In en, this message translates to:
  /// **'Cancel this payment? Only do this if you have not paid. If you already sent the money, send your proof instead.'**
  String get cancelThisPaymentOnlyDoThisIf;

  /// Refund screen. days is the refund window and n is the days the coach has to answer, both from payments_rules.dart.
  ///
  /// In en, this message translates to:
  /// **'You can ask once in the first {days} days. Your coach has {n} days to answer, then Own Hub steps in.'**
  String youCanAskOnceInTheFirst(String days, String n);

  /// No description provided for @ownHubDoesNotMoveMoneyIf.
  ///
  /// In en, this message translates to:
  /// **'Own Hub does not move money. If your coach agrees, she sends it back by InstaPay and records it here.'**
  String get ownHubDoesNotMoveMoneyIf;

  /// Snackbar after a refund request. n is the days the coach has.
  ///
  /// In en, this message translates to:
  /// **'Sent. Your coach has {n} days to answer.'**
  String sentYourCoachHasNDaysTo(String n);

  /// No description provided for @serviceProblem.
  ///
  /// In en, this message translates to:
  /// **'Service problem'**
  String get serviceProblem;

  /// No description provided for @tellUsWhatWentWrongOwnHub.
  ///
  /// In en, this message translates to:
  /// **'Tell us what went wrong. Own Hub looks at your sessions and messages and decides.'**
  String get tellUsWhatWentWrongOwnHub;

  /// No description provided for @refundProblem.
  ///
  /// In en, this message translates to:
  /// **'Refund problem'**
  String get refundProblem;

  /// No description provided for @yourCoachSaysSheSentTheMoney.
  ///
  /// In en, this message translates to:
  /// **'Your coach says she sent the money back. If it did not reach you, tell us and Own Hub will look into it.'**
  String get yourCoachSaysSheSentTheMoney;

  /// No description provided for @yourCoachDidNotAgreeToThe.
  ///
  /// In en, this message translates to:
  /// **'Your coach did not agree to the refund. Tell us why you think Own Hub should look again.'**
  String get yourCoachDidNotAgreeToThe;

  /// No description provided for @tellUsMore.
  ///
  /// In en, this message translates to:
  /// **'Tell us more'**
  String get tellUsMore;

  /// No description provided for @yourCoachDidNotAgreeToThe_9dkzl.
  ///
  /// In en, this message translates to:
  /// **'Your coach did not agree to the refund. If you disagree, open the menu at the top and ask Own Hub to look again.'**
  String get yourCoachDidNotAgreeToThe_9dkzl;

  /// The server refused a refund request after the window. n is the window in days.
  ///
  /// In en, this message translates to:
  /// **'The first {n} days are over, so a refund can no longer be asked for here.'**
  String theFirstNDaysAreOverSo(String n);

  /// No description provided for @youAlreadyAskedForARefundOn.
  ///
  /// In en, this message translates to:
  /// **'You already asked for a refund on this payment.'**
  String get youAlreadyAskedForARefundOn;

  /// No description provided for @theTimeToReportAProblemOn.
  ///
  /// In en, this message translates to:
  /// **'The time to report a problem on this payment has passed.'**
  String get theTimeToReportAProblemOn;

  /// No description provided for @youAlreadyReportedThisOwnHubHas.
  ///
  /// In en, this message translates to:
  /// **'You already reported this. Own Hub has your note.'**
  String get youAlreadyReportedThisOwnHubHas;

  /// No description provided for @youHaveReachedTheNumberOfReports.
  ///
  /// In en, this message translates to:
  /// **'You have reached the number of reports you can send this month. Please try next month.'**
  String get youHaveReachedTheNumberOfReports;

  /// No description provided for @pleaseCheckTheTransactionNumberFromYour.
  ///
  /// In en, this message translates to:
  /// **'Please check the transaction number from your bank. It is made of digits only.'**
  String get pleaseCheckTheTransactionNumberFromYour;

  /// No description provided for @theDateOrTimeOnYourPhone.
  ///
  /// In en, this message translates to:
  /// **'The date or time on your phone looks wrong. Fix it and try again.'**
  String get theDateOrTimeOnYourPhone;

  /// No description provided for @pleaseCheckTheAmountItCannotBe.
  ///
  /// In en, this message translates to:
  /// **'Please check the amount. It cannot be more than the payment.'**
  String get pleaseCheckTheAmountItCannotBe;

  /// No description provided for @refundRequests.
  ///
  /// In en, this message translates to:
  /// **'Refund requests'**
  String get refundRequests;

  /// Refund request row in the coach inbox. time is when it was asked, date is when the coach has to answer (Cairo time).
  ///
  /// In en, this message translates to:
  /// **'Asked {time}. Answer by {date}.'**
  String askedTimeAnswerByDate(String time, String date);

  /// Refund request row after its answer date has passed.
  ///
  /// In en, this message translates to:
  /// **'Asked {time}. The answer was due {date}. Own Hub may step in.'**
  String askedTimeTheAnswerWasDueDate(String time, String date);

  /// No description provided for @recordRefund.
  ///
  /// In en, this message translates to:
  /// **'Record refund'**
  String get recordRefund;

  /// No description provided for @sendTheMoneyBackToYourClient.
  ///
  /// In en, this message translates to:
  /// **'Send the money back to your client by InstaPay, then record it here. Own Hub does not move money.'**
  String get sendTheMoneyBackToYourClient;

  /// No description provided for @amountSentBackEgp.
  ///
  /// In en, this message translates to:
  /// **'Amount sent back (EGP)'**
  String get amountSentBackEgp;

  /// Coach records a refund smaller than the payment.
  ///
  /// In en, this message translates to:
  /// **'Part of the payment: {amount} of {total}.'**
  String partOfThePaymentAmountOfTotal(String amount, String total);

  /// No description provided for @iDoNotAgreeToThisRefund.
  ///
  /// In en, this message translates to:
  /// **'I do not agree to this refund'**
  String get iDoNotAgreeToThisRefund;

  /// No description provided for @whyDoYouNotAgree.
  ///
  /// In en, this message translates to:
  /// **'Why do you not agree?'**
  String get whyDoYouNotAgree;

  /// No description provided for @yourClientCanThenAskOwnHub.
  ///
  /// In en, this message translates to:
  /// **'Your client can then ask Own Hub to look at it.'**
  String get yourClientCanThenAskOwnHub;

  /// No description provided for @iAlreadyGaveTheSessions.
  ///
  /// In en, this message translates to:
  /// **'I already gave the sessions'**
  String get iAlreadyGaveTheSessions;

  /// No description provided for @itIsOutsideTheTerms.
  ///
  /// In en, this message translates to:
  /// **'It is outside the terms'**
  String get itIsOutsideTheTerms;

  /// No description provided for @yourInbodySheet.
  ///
  /// In en, this message translates to:
  /// **'Your InBody sheet'**
  String get yourInbodySheet;

  /// No description provided for @chooseAPhotoOrScreenshotOfYour.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo or screenshot of your result sheet. It is read on your phone. The photo is not saved and never leaves your phone.'**
  String get chooseAPhotoOrScreenshotOfYour;

  /// No description provided for @typeTheNumbersInstead.
  ///
  /// In en, this message translates to:
  /// **'Type the numbers instead'**
  String get typeTheNumbersInstead;

  /// No description provided for @readingYourSheet.
  ///
  /// In en, this message translates to:
  /// **'Reading your sheet'**
  String get readingYourSheet;

  /// No description provided for @checkYourNumbers.
  ///
  /// In en, this message translates to:
  /// **'Check your numbers'**
  String get checkYourNumbers;

  /// No description provided for @weReadTheseFromYourSheetCheck.
  ///
  /// In en, this message translates to:
  /// **'We read these from your sheet. Check each one against the paper and fix anything wrong. Nothing is used until you confirm.'**
  String get weReadTheseFromYourSheetCheck;

  /// No description provided for @typeTheNumbersFromYourSheetLeave.
  ///
  /// In en, this message translates to:
  /// **'Type the numbers from your sheet. Leave blank what you do not have. Nothing is used until you confirm.'**
  String get typeTheNumbersFromYourSheetLeave;

  /// No description provided for @weCouldNotReadNumbersFromThat.
  ///
  /// In en, this message translates to:
  /// **'We could not read numbers from that picture. Try a clearer photo, or type them.'**
  String get weCouldNotReadNumbersFromThat;

  /// No description provided for @checkThisNumberItLooksOutsideThe.
  ///
  /// In en, this message translates to:
  /// **'Check this number, it looks outside the usual range.'**
  String get checkThisNumberItLooksOutsideThe;

  /// No description provided for @weightHeightAndBmiOnYourSheet.
  ///
  /// In en, this message translates to:
  /// **'Weight, height and BMI on your sheet do not agree. Check those three against the paper.'**
  String get weightHeightAndBmiOnYourSheet;

  /// No description provided for @weightFatAndLeanMassOnYour.
  ///
  /// In en, this message translates to:
  /// **'Weight, fat and lean mass on your sheet do not add up. Check them against the paper.'**
  String get weightFatAndLeanMassOnYour;

  /// No description provided for @yourSheetShowsPoundsSoTheWeight.
  ///
  /// In en, this message translates to:
  /// **'Your sheet shows pounds, so the weight was changed to kilograms.'**
  String get yourSheetShowsPoundsSoTheWeight;

  /// No description provided for @chooseAnotherPhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose another photo'**
  String get chooseAnotherPhoto;

  /// No description provided for @confirmTheseNumbers.
  ///
  /// In en, this message translates to:
  /// **'Confirm these numbers'**
  String get confirmTheseNumbers;

  /// No description provided for @yourWeightAndHeightStayOnThis.
  ///
  /// In en, this message translates to:
  /// **'Your weight and height stay on this phone.'**
  String get yourWeightAndHeightStayOnThis;

  /// No description provided for @yourCoachSeesTheseNumbersOnlyIf.
  ///
  /// In en, this message translates to:
  /// **'Your coach sees these numbers only if you tick the box on the request form. The photo is never sent.'**
  String get yourCoachSeesTheseNumbersOnlyIf;

  /// No description provided for @inbodyNumbers.
  ///
  /// In en, this message translates to:
  /// **'InBody numbers'**
  String get inbodyNumbers;

  /// The coach's starting point for a client's day, from her InBody numbers. Both figures are whole numbers.
  ///
  /// In en, this message translates to:
  /// **'A place to start: {kcal} kcal and {protein} g protein a day'**
  String aPlaceToStartKcalKcalAnd(String kcal, String protein);

  /// The button on the coach's meal goal that fills both fields from the client's InBody numbers.
  ///
  /// In en, this message translates to:
  /// **'Use the InBody suggestion: {kcal} kcal and {protein} g protein'**
  String useTheInbodySuggestionKcalKcalAnd(String kcal, String protein);

  /// No description provided for @noTargetIsSuggestedWhileSheIs.
  ///
  /// In en, this message translates to:
  /// **'No target is suggested while she is pregnant or after a birth. Set her food with her doctor.'**
  String get noTargetIsSuggestedWhileSheIs;

  /// No description provided for @noTargetIsSuggestedForHerHer.
  ///
  /// In en, this message translates to:
  /// **'No target is suggested for her. Her answers ask you to guide her food yourself.'**
  String get noTargetIsSuggestedForHerHer;

  /// No description provided for @thereIsNotEnoughOnHerSheet.
  ///
  /// In en, this message translates to:
  /// **'There is not enough on her sheet to suggest a target. Set it by hand.'**
  String get thereIsNotEnoughOnHerSheet;

  /// No description provided for @addYourInbodyNumbers.
  ///
  /// In en, this message translates to:
  /// **'Add your InBody numbers'**
  String get addYourInbodyNumbers;

  /// No description provided for @optionalYourCoachSeesTheNumbersNever.
  ///
  /// In en, this message translates to:
  /// **'Optional. Your coach sees the numbers, never the photo.'**
  String get optionalYourCoachSeesTheNumbersNever;

  /// No description provided for @inbodyNumbersAdded.
  ///
  /// In en, this message translates to:
  /// **'InBody numbers added'**
  String get inbodyNumbersAdded;

  /// The tick on the request form that lets the client send her InBody numbers to the coach. Its hash goes to the server with the request.
  ///
  /// In en, this message translates to:
  /// **'I share my InBody numbers with {name}. They are body measurements, stored with my other answers in Frankfurt, Germany, outside Egypt.'**
  String iShareMyInbodyNumbersWithName(String name);

  /// No description provided for @readMyInbodySheet.
  ///
  /// In en, this message translates to:
  /// **'Read my InBody sheet'**
  String get readMyInbodySheet;

  /// No description provided for @feeStatements.
  ///
  /// In en, this message translates to:
  /// **'Fee statements'**
  String get feeStatements;

  /// No description provided for @whatYouOweOwnHubEachMonth.
  ///
  /// In en, this message translates to:
  /// **'What you owe Own Hub each month'**
  String get whatYouOweOwnHubEachMonth;

  /// No description provided for @monthlyStatement.
  ///
  /// In en, this message translates to:
  /// **'Monthly statement'**
  String get monthlyStatement;

  /// Heading of a fee statement; month is YYYY-MM.
  ///
  /// In en, this message translates to:
  /// **'Fee for {month}'**
  String feeForMonth(String month);

  /// How many payments a fee statement lists.
  ///
  /// In en, this message translates to:
  /// **'Payments: {count}'**
  String paymentsCount(String count);

  /// One statement line: the fee and the package price it is on.
  ///
  /// In en, this message translates to:
  /// **'{fee} fee on {base}'**
  String feeFeeOnBase(String fee, String base);

  /// No description provided for @due.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get due;

  /// No description provided for @disputedPending.
  ///
  /// In en, this message translates to:
  /// **'Disputed, pending'**
  String get disputedPending;

  /// No description provided for @settled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get settled;

  /// No description provided for @waived.
  ///
  /// In en, this message translates to:
  /// **'Waived'**
  String get waived;

  /// No description provided for @totalDue.
  ///
  /// In en, this message translates to:
  /// **'Total due'**
  String get totalDue;

  /// No description provided for @payOwnHubsFeeByInstapayTo.
  ///
  /// In en, this message translates to:
  /// **'Pay Own Hub\'s fee by InstaPay to:'**
  String get payOwnHubsFeeByInstapayTo;

  /// The name on the InstaPay account the fee is paid to.
  ///
  /// In en, this message translates to:
  /// **'Account name: {name}'**
  String accountNameName(String name);

  /// No description provided for @ownHubWillSendYouTheAddress.
  ///
  /// In en, this message translates to:
  /// **'Own Hub will send you the address to pay to.'**
  String get ownHubWillSendYouTheAddress;

  /// The overdue rule, n from the server limit.
  ///
  /// In en, this message translates to:
  /// **'Fees unpaid for more than {n} days stop new clients. Your current clients are never cut off.'**
  String feesUnpaidForMoreThanNDays(String n);

  /// No description provided for @thisFeeIsLateNewClientsCannot.
  ///
  /// In en, this message translates to:
  /// **'This fee is late. New clients cannot join you until it is paid. Your current clients are not affected.'**
  String get thisFeeIsLateNewClientsCannot;

  /// The day a fee statement falls due, Cairo time.
  ///
  /// In en, this message translates to:
  /// **'Due by {date}'**
  String dueByDate(String date);

  /// No description provided for @markFeeAsPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark fee as paid'**
  String get markFeeAsPaid;

  /// No description provided for @useTheTransactionNumberFromYourInstapay.
  ///
  /// In en, this message translates to:
  /// **'Use the transaction number from your InstaPay transfer to Own Hub.'**
  String get useTheTransactionNumberFromYourInstapay;

  /// No description provided for @recordedOwnHubWillConfirmIt.
  ///
  /// In en, this message translates to:
  /// **'Recorded. Own Hub will confirm it.'**
  String get recordedOwnHubWillConfirmIt;

  /// No description provided for @paidOwnHubWillConfirm.
  ///
  /// In en, this message translates to:
  /// **'Paid. Own Hub will confirm.'**
  String get paidOwnHubWillConfirm;

  /// No description provided for @paidAndConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Paid and confirmed.'**
  String get paidAndConfirmed;

  /// No description provided for @thisStatementChangedGoBackAndOpen.
  ///
  /// In en, this message translates to:
  /// **'This statement changed. Go back and open it again.'**
  String get thisStatementChangedGoBackAndOpen;

  /// No description provided for @noStatementYetTheFirstOneComes.
  ///
  /// In en, this message translates to:
  /// **'No statement yet. The first one comes at the start of next month.'**
  String get noStatementYetTheFirstOneComes;

  /// No description provided for @otherMonths.
  ///
  /// In en, this message translates to:
  /// **'Other months'**
  String get otherMonths;

  /// No description provided for @pleaseCheckTheTransactionNumberFromYour_653l2.
  ///
  /// In en, this message translates to:
  /// **'Please check the transaction number from your transfer.'**
  String get pleaseCheckTheTransactionNumberFromYour_653l2;

  /// No description provided for @savePaymentRecord.
  ///
  /// In en, this message translates to:
  /// **'Save payment record'**
  String get savePaymentRecord;

  /// No description provided for @paymentRecord.
  ///
  /// In en, this message translates to:
  /// **'Payment record'**
  String get paymentRecord;

  /// No description provided for @ownHubPaymentRecord.
  ///
  /// In en, this message translates to:
  /// **'Own Hub payment record'**
  String get ownHubPaymentRecord;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @client.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get client;

  /// No description provided for @thisIsAPaymentRecordItIs.
  ///
  /// In en, this message translates to:
  /// **'This is a payment record. It is not a tax invoice.'**
  String get thisIsAPaymentRecordItIs;

  /// No description provided for @saveOrShare.
  ///
  /// In en, this message translates to:
  /// **'Save or share'**
  String get saveOrShare;

  /// A refund staff ordered, with the day it is due.
  ///
  /// In en, this message translates to:
  /// **'Own Hub decided you owe a refund. Send it by {date}.'**
  String ownHubDecidedYouOweARefund(String date);

  /// A refund staff ordered that is now late.
  ///
  /// In en, this message translates to:
  /// **'Own Hub decided you owe a refund. It was due on {date}.'**
  String ownHubDecidedYouOweARefund_c85m6(String date);

  /// No description provided for @ownHubSetThisAmount.
  ///
  /// In en, this message translates to:
  /// **'Own Hub set this amount.'**
  String get ownHubSetThisAmount;

  /// No description provided for @sayWhatYouAte.
  ///
  /// In en, this message translates to:
  /// **'Say what you ate'**
  String get sayWhatYouAte;

  /// No description provided for @tapToSpeak.
  ///
  /// In en, this message translates to:
  /// **'Tap to speak'**
  String get tapToSpeak;

  /// No description provided for @listeningTapWhenYouAreDone.
  ///
  /// In en, this message translates to:
  /// **'Listening, tap when you are done'**
  String get listeningTapWhenYouAreDone;

  /// No description provided for @ownHubListensOnlyWhileYouSpeak.
  ///
  /// In en, this message translates to:
  /// **'Own Hub listens only while you speak, to write down what you said so you can check it. Your phone\'s speech service (Apple on iPhone, Google on Android) may process what you say, and Own Hub never keeps the audio.'**
  String get ownHubListensOnlyWhileYouSpeak;

  /// No description provided for @fixAnyWordAndWeWillAdd.
  ///
  /// In en, this message translates to:
  /// **'Fix any word and we will add it up again.'**
  String get fixAnyWordAndWeWillAdd;

  /// No description provided for @ownHubCantUseTheMicrophoneOr.
  ///
  /// In en, this message translates to:
  /// **'Own Hub can\'t use the microphone or speech recognition on this phone right now. Turn them on in Settings, or type your meal.'**
  String get ownHubCantUseTheMicrophoneOr;

  /// No description provided for @weDidntCatchAnythingTryAgainA.
  ///
  /// In en, this message translates to:
  /// **'We didn\'t catch anything. Try again a little closer to the phone, or type your meal.'**
  String get weDidntCatchAnythingTryAgainA;

  /// No description provided for @sayingYourMealNeedsAnInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'Saying your meal needs an internet connection on this phone right now. Type it instead, or try again when you are back online.'**
  String get sayingYourMealNeedsAnInternetConnection;

  /// No description provided for @thisPhoneCantTurnSpeechIntoText.
  ///
  /// In en, this message translates to:
  /// **'This phone can\'t turn speech into text. Type your meal instead.'**
  String get thisPhoneCantTurnSpeechIntoText;

  /// No description provided for @somethingWentWrongWhileListeningTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while listening. Try again, or type your meal.'**
  String get somethingWentWrongWhileListeningTryAgain;

  /// No description provided for @weHeardYouButNoneOfIt.
  ///
  /// In en, this message translates to:
  /// **'We heard you, but none of it matched a food. Fix the words above, or type your meal.'**
  String get weHeardYouButNoneOfIt;

  /// No description provided for @speakIn.
  ///
  /// In en, this message translates to:
  /// **'Speak in'**
  String get speakIn;

  /// No description provided for @turnOnPaymentAlerts.
  ///
  /// In en, this message translates to:
  /// **'Turn on payment alerts'**
  String get turnOnPaymentAlerts;

  /// No description provided for @tellMeWhenItChanges.
  ///
  /// In en, this message translates to:
  /// **'Tell me when it changes'**
  String get tellMeWhenItChanges;

  /// No description provided for @ownHubCanTellYouOnThis.
  ///
  /// In en, this message translates to:
  /// **'Own Hub can tell you on this phone when a client pays or asks for a refund, and when your fee statement is ready. These are payment updates only, and no name or amount shows on the lock screen.'**
  String get ownHubCanTellYouOnThis;

  /// No description provided for @weWillSendANotificationToThis.
  ///
  /// In en, this message translates to:
  /// **'We will send a notification to this phone when your payment is confirmed or needs something from you. These are payment updates only, and no name or amount shows on the lock screen.'**
  String get weWillSendANotificationToThis;

  /// No description provided for @paymentAlertsAreOnForThisPhone.
  ///
  /// In en, this message translates to:
  /// **'Payment alerts are on for this phone.'**
  String get paymentAlertsAreOnForThisPhone;

  /// After a coach shares a plan with several clients at once: how many it reached. A plural message because Arabic counts agree differently at one, two, three to ten and eleven and up; the old sentence said 'Sent to 1 clients' when one got it and others did not.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, one{Sent to {n} client} other{Sent to {n} clients}}'**
  String nPluralOneSentToNClient(int n);

  /// No description provided for @thatWasForYou.
  ///
  /// In en, this message translates to:
  /// **'That was for you.'**
  String get thatWasForYou;

  /// No description provided for @restWellYouEarnedIt.
  ///
  /// In en, this message translates to:
  /// **'Rest well, you earned it.'**
  String get restWellYouEarnedIt;

  /// No description provided for @beProudOfThatOne.
  ///
  /// In en, this message translates to:
  /// **'Be proud of that one.'**
  String get beProudOfThatOne;

  /// No description provided for @strongWorkToday.
  ///
  /// In en, this message translates to:
  /// **'Strong work today.'**
  String get strongWorkToday;

  /// No description provided for @keepThisWorkout.
  ///
  /// In en, this message translates to:
  /// **'Keep this workout'**
  String get keepThisWorkout;

  /// No description provided for @createYourAccountAndThisWorkoutCounts.
  ///
  /// In en, this message translates to:
  /// **'Create your account and this workout counts in your week.'**
  String get createYourAccountAndThisWorkoutCounts;

  /// No description provided for @goForAWalk.
  ///
  /// In en, this message translates to:
  /// **'Go for a walk'**
  String get goForAWalk;

  /// No description provided for @walkAsLongAsYouLikeLog.
  ///
  /// In en, this message translates to:
  /// **'Walk as long as you like. Log it after, and Own Hub counts the calories you burned.'**
  String get walkAsLongAsYouLikeLog;

  /// No description provided for @theCaloriesAreAnEstimateTheyNever.
  ///
  /// In en, this message translates to:
  /// **'The calories are an estimate. They never change what you eat.'**
  String get theCaloriesAreAnEstimateTheyNever;

  /// No description provided for @startWalking.
  ///
  /// In en, this message translates to:
  /// **'Start walking'**
  String get startWalking;

  /// No description provided for @finishWalk.
  ///
  /// In en, this message translates to:
  /// **'Finish walk'**
  String get finishWalk;

  /// No description provided for @caloriesBurnedEstimate.
  ///
  /// In en, this message translates to:
  /// **'Calories burned, estimate'**
  String get caloriesBurnedEstimate;

  /// No description provided for @logThisWalk.
  ///
  /// In en, this message translates to:
  /// **'Log this walk'**
  String get logThisWalk;

  /// No description provided for @loggingCountsItInYourWeekAnd.
  ///
  /// In en, this message translates to:
  /// **'Logging counts it in your week and saves the calories you burned.'**
  String get loggingCountsItInYourWeekAnd;

  /// No description provided for @dontLogIt.
  ///
  /// In en, this message translates to:
  /// **'Don\'t log it'**
  String get dontLogIt;

  /// No description provided for @walkLogged.
  ///
  /// In en, this message translates to:
  /// **'Walk logged'**
  String get walkLogged;

  /// No description provided for @thatWasUnderAMinuteSoThere.
  ///
  /// In en, this message translates to:
  /// **'That was under a minute, so there is nothing to log.'**
  String get thatWasUnderAMinuteSoThere;

  /// No description provided for @workedOutWithATypicalWeightAdd.
  ///
  /// In en, this message translates to:
  /// **'Worked out with a typical weight. Add yours for a closer figure.'**
  String get workedOutWithATypicalWeightAdd;

  /// No description provided for @twoQuickQuestionsThenTheCoachesWho.
  ///
  /// In en, this message translates to:
  /// **'Two quick questions, then the coaches who fit you best.'**
  String get twoQuickQuestionsThenTheCoachesWho;

  /// No description provided for @matchedOnYourTwoAnswersOnlyThen.
  ///
  /// In en, this message translates to:
  /// **'Matched on your two answers only, then by name A to Z.'**
  String get matchedOnYourTwoAnswersOnlyThen;

  /// No description provided for @logItToCountTheCaloriesYou.
  ///
  /// In en, this message translates to:
  /// **'Log it to count the calories you burned'**
  String get logItToCountTheCaloriesYou;

  /// No description provided for @soundsAndTouch.
  ///
  /// In en, this message translates to:
  /// **'Sounds and touch'**
  String get soundsAndTouch;

  /// No description provided for @chooseWhatYouHearAndFeel.
  ///
  /// In en, this message translates to:
  /// **'Choose what you hear and feel'**
  String get chooseWhatYouHearAndFeel;

  /// No description provided for @sounds.
  ///
  /// In en, this message translates to:
  /// **'Sounds'**
  String get sounds;

  /// No description provided for @softSoundsWhenYouLogASet.
  ///
  /// In en, this message translates to:
  /// **'Soft sounds when you log a set, finish a workout or add a meal.'**
  String get softSoundsWhenYouLogASet;

  /// No description provided for @haptics.
  ///
  /// In en, this message translates to:
  /// **'Haptics'**
  String get haptics;

  /// No description provided for @aLightTapYouCanFeelAt.
  ///
  /// In en, this message translates to:
  /// **'A light tap you can feel at the same moments.'**
  String get aLightTapYouCanFeelAt;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppL10nAr();
    case 'en':
      return AppL10nEn();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
