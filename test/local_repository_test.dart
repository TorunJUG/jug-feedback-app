import 'package:flutter_test/flutter_test.dart';
import 'package:feedback_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saves and loads rounds', () async {
    final repository = LocalRepository();
    final round = FeedbackRound(
      id: 'round-1',
      createdAt: DateTime.utc(2026),
      ratings: {'p1': Rating.neutral},
    );

    await repository.saveRound(round);

    final loaded = await repository.loadRounds();
    expect(loaded, hasLength(1));
    expect(loaded.single.ratings['p1'], Rating.neutral);
  });

  test('preserves multiple rounds in order', () async {
    final repository = LocalRepository();
    await repository.saveRound(_round('one', Rating.poor));
    await repository.saveRound(_round('two', Rating.good));

    final loaded = await repository.loadRounds();
    expect(loaded.map((round) => round.id), ['one', 'two']);
  });

  test(
    'persists every rating level without changing its stable code',
    () async {
      final repository = LocalRepository();
      final allRatings = {
        for (final (index, rating) in Rating.values.indexed)
          'presentation-$index': rating,
      };
      final round = FeedbackRound(
        id: 'all-ratings',
        createdAt: DateTime.utc(2026),
        ratings: allRatings,
      );

      await repository.saveRound(round);
      final loaded = await repository.loadRounds();

      expect(loaded.single.ratings, allRatings);
      for (final rating in Rating.values) {
        expect(ratingFromCode(rating.code), rating);
      }
    },
  );

  test('saves and loads presentation configuration', () async {
    final repository = LocalRepository();
    final presentations = [
      const Presentation(id: 'p1', title: 'Talk', speaker: 'Speaker'),
    ];

    await repository.savePresentations(presentations);
    await repository.saveActivePresentationIds(['p1']);

    expect((await repository.loadPresentations())!.single.title, 'Talk');
    expect(await repository.loadActivePresentationIds(), ['p1']);
  });

  test('clears ratings only for selected presentation', () async {
    final repository = LocalRepository();
    await repository.saveRound(
      FeedbackRound(
        id: 'round-1',
        createdAt: DateTime.utc(2026),
        ratings: {'p1': Rating.good, 'p2': Rating.neutral},
      ),
    );

    await repository.clearRatingsForPresentation('p1');

    final loaded = await repository.loadRounds();
    expect(loaded, hasLength(1));
    expect(loaded.single.ratings, {'p2': Rating.neutral});
  });

  test('removes round containing only cleared rating', () async {
    final repository = LocalRepository();
    await repository.saveRound(_round('one', Rating.good));

    await repository.clearRatingsForPresentation('p1');

    expect(await repository.loadRounds(), isEmpty);
  });
}

FeedbackRound _round(String id, Rating rating) => FeedbackRound(
  id: id,
  createdAt: DateTime.utc(2026),
  ratings: {'p1': rating},
);
