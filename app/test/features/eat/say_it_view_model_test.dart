// P0-LOG-08 — "Log a meal by voice in Egyptian Arabic."
//
// From TEST-CASES.csv: "Transcript shown before saving so a misheard word is
// visible. Interface stays MSA; speech input accepts dialect."
//
// The half this file owns is "shown before saving", and it is tested as an
// impossibility rather than as a sequence: `canLog` is false in every state
// except `transcriptShown`, so there is no path from speaking to a saved log
// that does not pass through her reading it.
//
// Tier 2 (cloud STT) is off — G5 §9 Q4 is blocking and owner-track — so
// `refused` is a state real women will reach, and it routes to E02 rather than
// to a spinner.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/eat/domain/food_library.dart';
import 'package:own_hub/features/eat/domain/meal_sentence_parser.dart';
import 'package:own_hub/features/eat/presentation/say_it_view_model.dart';

final _koshari = Food(
  foodId: 'koshari_bowl',
  names: const ['Koshari bowl', 'koshari', 'كشري'],
  allergens: const <String>{},
  popularity: 90,
  sizes: const [
    FoodSize(id: 'S', label: 'Small', kcal: 380, proteinG: 13),
    FoodSize(id: 'M', label: 'Medium', kcal: 540, proteinG: 18),
    FoodSize(id: 'L', label: 'Large', kcal: 700, proteinG: 24),
  ],
);

final _eggs = Food(
  foodId: 'boiled_eggs',
  names: const ['Boiled eggs', 'eggs', 'بيض'],
  allergens: const <String>{'egg'},
  popularity: 80,
  sizes: const [
    FoodSize(id: '1', label: '1', kcal: 78, proteinG: 6),
    FoodSize(id: '2', label: '2', kcal: 156, proteinG: 13),
  ],
);

const _model = SayItViewModel(parser: MealSentenceParser(FoodLibrary.empty));

final _withPack = SayItViewModel(
  parser: MealSentenceParser(FoodLibrary([_koshari, _eggs])),
);

void main() {
  group('P0-LOG-08 — the transcript is shown before anything is saved', () {
    test('nothing can be logged until the transcript is on screen', () {
      expect(SayItState.idle.canLog, isFalse);
      expect(_model.start().canLog, isFalse);
      expect(_model.stopped().canLog, isFalse);
      expect(_model.failed().canLog, isFalse);
      expect(_model.refuse().canLog, isFalse);
    });

    test('hearing a transcript shows it rather than logging it', () {
      final view = _withPack.heard('كشري و بيض');

      expect(view.state, VoiceState.transcriptShown);
      expect(view.transcript, 'كشري و بيض');
      expect(view.canLog, isTrue);
    });

    test('a transcript that resolved to nothing cannot be logged', () {
      final view = _withPack.heard('qqq zzz');

      expect(view.state, VoiceState.transcriptShown);
      expect(
        view.canLog,
        isFalse,
        reason:
            'the transcript is visible so she can see what went wrong, but '
            'there is nothing to save',
      );
    });

    test('the transcript is the words she said, kept verbatim', () {
      final view = _withPack.heard('كشري و بيض');
      expect(view.transcript, 'كشري و بيض');
    });
  });

  group('no transcript is invented', () {
    test('the idle screen has none', () {
      expect(SayItState.idle.transcript, isNull);
      expect(SayItState.idle.parse.isEmpty, isTrue);
    });

    test('recording and transcribing have none either', () {
      // The prototype draws a sample Arabic sentence. That is a mockup value,
      // not copy — putting it here would show a woman words she never said on
      // the one screen whose entire purpose is showing her what was heard.
      expect(_model.start().transcript, isNull);
      expect(_model.stopped().transcript, isNull);
    });
  });

  group('the state machine — §3.3', () {
    test('idle → recording → transcribing → transcriptShown', () {
      expect(_model.start().state, VoiceState.recording);
      expect(_model.start().isRecording, isTrue);
      expect(_model.stopped().state, VoiceState.transcribing);
      expect(_withPack.heard('koshari').state, VoiceState.transcriptShown);
    });

    test('both recording and transcribing read as busy', () {
      expect(_model.start().isBusy, isTrue);
      expect(_model.stopped().isBusy, isTrue);
      expect(SayItState.idle.isBusy, isFalse);
      expect(_withPack.heard('koshari').isBusy, isFalse);
    });

    test('a timeout offers "say it again", not a dead screen', () {
      final view = _model.failed();

      expect(view.state, VoiceState.failed);
      expect(view.shouldOfferTyping, isTrue);
    });

    test('with no model and no signal it refuses clearly', () {
      // Tier 2 is off at launch (§9 Q4), so this is a real path. A spinner that
      // never resolves would be the alternative, and it is worse.
      final view = _model.refuse();

      expect(view.state, VoiceState.refused);
      expect(view.shouldOfferTyping, isTrue);
      expect(view.canLog, isFalse);
    });
  });

  group('she can fix a misheard row before confirming', () {
    test('resizing keeps the transcript and the state', () {
      final view = _withPack.heard('كشري و بيض');
      final resized = _withPack.resize(view, 0, _koshari.sizeById('L')!);

      expect(resized.state, VoiceState.transcriptShown);
      expect(resized.transcript, 'كشري و بيض');
      expect(resized.parse.items[0].size.id, 'L');
      expect(resized.canLog, isTrue);
    });

    test('removing a misheard row keeps the rest loggable', () {
      final view = _withPack.heard('كشري و بيض');
      expect(view.parse.items, hasLength(2));

      final fewer = _withPack.remove(view, 1);
      expect(fewer.parse.items, hasLength(1));
      expect(fewer.canLog, isTrue);
    });

    test('removing everything leaves nothing to log', () {
      var view = _withPack.heard('كشري');
      view = _withPack.remove(view, 0);

      expect(view.canLog, isFalse);
      expect(
        view.transcript,
        'كشري',
        reason: 'the transcript still explains what the screen is showing',
      );
    });
  });

  test('speaking and typing go through the same parser', () {
    // E03's transcript and E02's sentence must resolve identically, or the two
    // screens disagree about what a woman said she ate.
    const sentence = 'كشري و بيض';
    final spoken = _withPack.heard(sentence).parse;
    final typed = MealSentenceParser(FoodLibrary([_koshari, _eggs]))
        .parse(sentence);

    expect(
      spoken.items.map((i) => i.food.foodId),
      typed.items.map((i) => i.food.foodId),
    );
    expect(spoken.kcal, typed.kcal);
  });
}
