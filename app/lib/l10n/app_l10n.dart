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

  /// No description provided for @n31212Kg.
  ///
  /// In en, this message translates to:
  /// **'3 × 12 · 12 kg'**
  String get n31212Kg;

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

  /// No description provided for @finishHere.
  ///
  /// In en, this message translates to:
  /// **'Finish here'**
  String get finishHere;

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

  /// R13 undo snackbar after a whole move.
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

  /// R13 primary button. The move she goes back to, replacing the fixed 'Next move · step-back lunge'.
  ///
  /// In en, this message translates to:
  /// **'Next move · {move}'**
  String nextMoveMove(String move);

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

  /// No description provided for @movingKitten.
  ///
  /// In en, this message translates to:
  /// **'Moving kitten'**
  String get movingKitten;

  /// No description provided for @theKittenShowsYouAroundAndMoves.
  ///
  /// In en, this message translates to:
  /// **'The kitten shows you around and moves once when it appears.'**
  String get theKittenShowsYouAroundAndMoves;

  /// No description provided for @theKittenStaysStill.
  ///
  /// In en, this message translates to:
  /// **'The kitten stays still.'**
  String get theKittenStaysStill;

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

  /// R07/R08/R09/R13 set bar: sets of today's session behind her, out of all of them.
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

  /// T01 week line while sessions are still to go. A plural message because Arabic says تمرين واحد, تمرينين, 3 تمارين and 11 تمرين.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 more and the week counts.} other{{count} more and the week counts.}}'**
  String countPluralOne1MoreAndThe(int count);

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
