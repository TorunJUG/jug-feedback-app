import 'package:feedback_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rating results screen', () {
    const presentations = [
      Presentation(id: 'p1', title: 'Talk one', speaker: 'Speaker one'),
      Presentation(id: 'p2', title: 'Talk two', speaker: 'Speaker two'),
    ];

    test('aggregates each rating per presentation and ignores unknown IDs', () {
      final counts = RatingResultsPage.aggregateRatings(presentations, [
        _round('r1', {'p1': Rating.good, 'p2': Rating.poor}),
        _round('r2', {
          'p1': Rating.good,
          'removed-presentation': Rating.superRating,
        }),
        _round('r3', {'p1': Rating.superRating, 'p2': Rating.neutral}),
      ]);

      expect(counts['p1'], {
        Rating.poor: 0,
        Rating.neutral: 0,
        Rating.good: 2,
        Rating.superRating: 1,
      });
      expect(counts['p2'], {
        Rating.poor: 1,
        Rating.neutral: 1,
        Rating.good: 0,
        Rating.superRating: 0,
      });
      expect(counts.containsKey('removed-presentation'), isFalse);
    });

    testWidgets('shows counts in compact mobile cards', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: RatingResultsPage(
            presentations: presentations,
            rounds: [
              _round('r1', {'p1': Rating.good, 'p2': Rating.poor}),
              _round('r2', {'p1': Rating.superRating}),
            ],
          ),
        ),
      );

      expect(find.text('Wyniki'), findsOneWidget);
      expect(find.byKey(const ValueKey('result-p1-good')), findsOneWidget);
      expect(find.byKey(const ValueKey('result-p1-super')), findsOneWidget);
      expect(find.text('Dobrze: 1'), findsOneWidget);
      expect(find.text('Super: 1'), findsOneWidget);
      expect(find.text('Neutralnie: 0'), findsNWidgets(2));
      final ratingResult = tester.widget<CustomPaint>(
        find.byKey(const ValueKey('result-p1-good')),
      );
      expect(ratingResult.foregroundPainter, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows results table on wide screens', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: RatingResultsPage(
            presentations: presentations,
            rounds: [
              _round('r1', {'p1': Rating.good}),
            ],
          ),
        ),
      );

      expect(find.text('Prezentacja'), findsOneWidget);
      expect(find.text('Słabo'), findsOneWidget);
      expect(find.text('Neutralnie'), findsOneWidget);
      expect(find.text('Dobrze'), findsOneWidget);
      expect(find.text('Super'), findsOneWidget);
      for (final rating in Rating.values) {
        expect(find.text(rating.label), findsOneWidget);
      }
      expect(find.text('Talk one'), findsOneWidget);
      expect(find.text('Talk two'), findsOneWidget);
      expect(find.byKey(const ValueKey('result-p1-good')), findsOneWidget);
      expect(find.byKey(const ValueKey('result-p2-super')), findsOneWidget);
      for (final rating in Rating.values) {
        final headerRect = tester.getRect(
          find.byKey(ValueKey('results-header-${rating.code}')),
        );
        final countRect = tester.getRect(
          find.byKey(ValueKey('result-p1-${rating.code}')),
        );
        expect(countRect.center.dx, closeTo(headerRect.center.dx, 1));
        expect(
          tester
              .widget<CustomPaint>(
                find.byKey(ValueKey('result-p1-${rating.code}')),
              )
              .foregroundPainter,
          isNotNull,
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses cards at narrow tablet widths to avoid column overflow', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: RatingResultsPage(
            presentations: presentations,
            rounds: [
              _round('r1', {'p1': Rating.superRating}),
            ],
          ),
        ),
      );

      expect(find.text('Super: 1'), findsOneWidget);
      expect(find.text('Prezentacja'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows empty state when there are no presentations', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RatingResultsPage(presentations: [], rounds: []),
        ),
      );

      expect(find.text('Brak prezentacji do wyświetlenia.'), findsOneWidget);
      expect(find.byKey(const ValueKey('rating-results-list')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

FeedbackRound _round(String id, Map<String, Rating> ratings) =>
    FeedbackRound(id: id, createdAt: DateTime.utc(2026), ratings: ratings);
