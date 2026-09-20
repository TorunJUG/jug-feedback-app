import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feedback_app/main.dart';

import 'test_fakes.dart';

void main() {
  group('Voting screen', () {
    testWidgets('shows only active talk and all four rating choices', (
      tester,
    ) async {
      await _openVoting(tester);
      expect(find.text('Talk one'), findsOneWidget);
      expect(find.text('Speaker one'), findsOneWidget);
      expect(find.text('Talk two'), findsNothing);
      expect(find.text('Oceń prezentację'), findsOneWidget);
      expect(
        find.text('Wybierz ocenę. Możesz ją zmienić przed zatwierdzeniem.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('rating-poor-p1')), findsOneWidget);
      expect(find.byKey(const ValueKey('rating-neutral-p1')), findsOneWidget);
      expect(find.byKey(const ValueKey('rating-good-p1')), findsOneWidget);
      expect(find.byKey(const ValueKey('rating-super-p1')), findsOneWidget);
      for (final label in ['Słabo', 'Neutralnie', 'Dobrze', 'Super']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('shows full long title wrapped in widget', (tester) async {
      const title =
          'Zmiana pod presją: dlaczego koszt zmiany rośnie i jak go zatrzymać';
      await _openVoting(
        tester,
        presentations: [
          const Presentation(id: 'p1', title: title, speaker: 'Łukasz Pięta'),
          const Presentation(
            id: 'p2',
            title: 'Talk two',
            speaker: 'Speaker two',
          ),
        ],
      );
      expect(find.text(title), findsOneWidget);
      final titleWidget = tester.widget<Text>(
        find.byKey(const ValueKey('presentation-title-p1')),
      );
      expect(titleWidget.softWrap, isTrue);
      expect(titleWidget.maxLines, isNull);
    });

    testWidgets('shows all rating and submit buttons without scrolling', (
      tester,
    ) async {
      for (final size in [const Size(800, 360), const Size(320, 480)]) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _openVoting(tester);

        final submit = find.byKey(const ValueKey('submit-rating'));
        expect(
          find.ancestor(
            of: submit,
            matching: find.byType(SingleChildScrollView),
          ),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('rating-options-menu')),
          findsOneWidget,
        );
        final title = tester.getRect(
          find.byKey(const ValueKey('voting-screen-title')),
        );
        if (size.width > size.height) {
          final header = tester.getRect(
            find.byKey(const ValueKey('landscape-voting-header')),
          );
          expect(title.left, closeTo(header.left, 1));
        } else {
          expect(title.left, closeTo(16, 1));
        }
        expect(tester.getRect(submit).bottom, lessThanOrEqualTo(size.height));
        expect(tester.getSize(submit).height, 48);
        if (size.width > size.height) {
          final grid = tester.widget<GridView>(
            find.byKey(const ValueKey('rating-grid')),
          );
          expect(
            (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
                .crossAxisCount,
            4,
          );
          final ratingGridRect = tester.getRect(
            find.byKey(const ValueKey('rating-grid')),
          );
          final infoRect = tester.getRect(
            find.byKey(const ValueKey('landscape-presentation-info')),
          );
          final instructionsRect = tester.getRect(
            find.byKey(const ValueKey('landscape-rating-instructions')),
          );
          final greenAccent = find.descendant(
            of: find.byKey(const ValueKey('landscape-presentation-info')),
            matching: find.byType(Container),
          );
          expect(greenAccent, findsWidgets);
          final menu = tester.getRect(
            find.byKey(const ValueKey('rating-options-menu')),
          );
          expect(instructionsRect.top, greaterThanOrEqualTo(menu.bottom));
          expect(instructionsRect.bottom, lessThanOrEqualTo(infoRect.top));
          final submitRect = tester.getRect(submit);
          final titleRect = tester.getRect(find.text('Oceń prezentację'));
          expect(titleRect.bottom, lessThanOrEqualTo(menu.bottom));
          expect(menu.bottom, lessThanOrEqualTo(infoRect.top));
          final speakerRect = tester.getRect(find.text('Speaker one'));
          expect(speakerRect.top, greaterThanOrEqualTo(infoRect.top));
          expect(speakerRect.bottom, lessThanOrEqualTo(infoRect.bottom));
          expect(infoRect.bottom, lessThanOrEqualTo(ratingGridRect.top));
          expect(
            find.text('Wybierz ocenę. Możesz ją zmienić przed zatwierdzeniem.'),
            findsOneWidget,
          );
          expect(ratingGridRect.bottom, lessThanOrEqualTo(submitRect.top));
          expect(submitRect.bottom, lessThanOrEqualTo(size.height));
          expect(submitRect.left, 20);
          expect(submitRect.right, size.width - 20);
          for (final rating in Rating.values) {
            final rect = tester.getRect(
              find.byKey(ValueKey('rating-${rating.code}-p1')),
            );
            expect(rect.top, greaterThanOrEqualTo(0));
            expect(rect.bottom, lessThanOrEqualTo(size.height));
            expect(rect.top, closeTo(ratingGridRect.top, 1));
            expect(rect.bottom, closeTo(ratingGridRect.bottom, 1));
          }
        } else {
          final titleRect = tester.getRect(
            find.byKey(const ValueKey('voting-screen-title')),
          );
          final menuRect = tester.getRect(
            find.byKey(const ValueKey('rating-options-menu')),
          );
          expect(menuRect.center.dy, closeTo(titleRect.center.dy, 1));
          expect(menuRect.left, greaterThanOrEqualTo(titleRect.right));
          final card = find
              .ancestor(
                of: find.byKey(const ValueKey('presentation-title-p1')),
                matching: find.byType(Card),
              )
              .first;
          expect(tester.getSize(card).height, greaterThan(size.height * 0.45));
          for (final rating in Rating.values) {
            final ratingButton = find.byKey(
              ValueKey('rating-${rating.code}-p1'),
            );
            final rect = tester.getRect(ratingButton);
            expect(rect.top, greaterThanOrEqualTo(0));
            expect(rect.bottom, lessThanOrEqualTo(size.height));
            expect(rect.height, greaterThan(45));
          }
          final menu = tester.getRect(
            find.byKey(const ValueKey('rating-options-menu')),
          );
          expect(menu.top, greaterThanOrEqualTo(0));
          expect(menu.bottom, lessThanOrEqualTo(size.height));
          expect(tester.getRect(submit).left, 16);
          expect(tester.getRect(submit).right, size.width - 16);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('limits rating button height on desktop web layout', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _openVoting(tester);

      final content = tester.getRect(
        find.byKey(const ValueKey('desktop-voting-content')),
      );
      final gridRect = tester.getRect(
        find.byKey(const ValueKey('rating-grid')),
      );
      expect(content.height, lessThanOrEqualTo(520));
      expect(content.center.dy, closeTo(450, 2));
      expect(gridRect.height, lessThanOrEqualTo(120));
      final infoRect = tester.getRect(
        find.byKey(const ValueKey('landscape-presentation-info')),
      );
      final submitRect = tester.getRect(
        find.byKey(const ValueKey('submit-rating')),
      );
      expect(infoRect.bottom, closeTo(gridRect.top, 5));
      expect(gridRect.bottom, closeTo(submitRect.top, 5));
      for (final rating in Rating.values) {
        final buttonRect = tester.getRect(
          find.byKey(ValueKey('rating-${rating.code}-p1')),
        );
        expect(buttonRect.height, lessThanOrEqualTo(120));
        expect(buttonRect.width, greaterThan(300));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('portrait rating targets meet Android touch size minimum', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _openVoting(tester);

      for (final rating in Rating.values) {
        final rect = tester.getRect(
          find.byKey(ValueKey('rating-${rating.code}-p1')),
        );
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('remains usable with large system text scaling', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = MemoryFeedbackRepository(
        presentations: const [
          Presentation(
            id: 'p1',
            title: 'Talk with accessibility',
            speaker: 'Speaker one',
          ),
          Presentation(id: 'p2', title: 'Talk two', speaker: 'Speaker two'),
        ],
        activeIds: const ['p1'],
      );
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: FeedbackApp(
            repository: repository,
            initialConfig: testEventConfig,
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();

      expect(find.text('Talk with accessibility'), findsOneWidget);
      final ratingButton = find.byKey(const ValueKey('rating-poor-p1'));
      expect(ratingButton, findsOneWidget);
      expect(find.text('Zatwierdź'), findsOneWidget);
      await tester.ensureVisible(ratingButton);
      await tester.tap(ratingButton);
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('submit-rating')));
      expect(_submitButton(tester).onPressed, isNotNull);
      for (final rating in Rating.values) {
        expect(
          tester
              .getSize(find.byKey(ValueKey('rating-${rating.code}-p1')))
              .height,
          greaterThanOrEqualTo(48),
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles long presentation title on compact mobile sizes', (
      tester,
    ) async {
      const title =
          'Jak projektować systemy, które pomagają zespołom podejmować lepsze decyzje';
      for (final size in [const Size(320, 480), const Size(568, 320)]) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _openVoting(
          tester,
          presentations: const [
            Presentation(id: 'p1', title: title, speaker: 'Łukasz Pięta'),
            Presentation(id: 'p2', title: 'Talk two', speaker: 'Speaker two'),
          ],
        );

        expect(find.text(title), findsOneWidget);
        expect(
          tester.getRect(find.byKey(const ValueKey('submit-rating'))).bottom,
          lessThanOrEqualTo(size.height),
        );
        for (final rating in Rating.values) {
          final rect = tester.getRect(
            find.byKey(ValueKey('rating-${rating.code}-p1')),
          );
          expect(rect.bottom, lessThanOrEqualTo(size.height));
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('requires choice and permits changing it before submit', (
      tester,
    ) async {
      await _openVoting(tester);
      expect(_submitButton(tester).onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('rating-poor-p1')));
      await tester.pump();
      expect(_submitButton(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('rating-super-p1')));
      await tester.pump();

      final superRating = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('rating-super-p1')),
      );
      expect(
        superRating.style?.backgroundColor?.resolve({}),
        const Color(0xffdce8ff),
      );
    });

    testWidgets(
      'persists selected rating and repeats same talk after countdown',
      (tester) async {
        final repository = await _openVoting(tester);
        await tester.tap(find.byKey(const ValueKey('rating-super-p1')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('submit-rating')));
        await tester.pump();

        expect(find.text('Przekaż telefon kolejnej osobie'), findsOneWidget);
        expect(find.text('5'), findsOneWidget);
        expect(repository.rounds, hasLength(1));
        expect(repository.rounds.single.ratings['p1'], Rating.superRating);

        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        await tester.pump();
        expect(find.text('Talk one'), findsOneWidget);
        expect(_submitButton(tester).onPressed, isNull);
      },
    );

    for (final rating in Rating.values) {
      testWidgets('persists ${rating.code} rating', (tester) async {
        final repository = await _openVoting(tester);
        await tester.tap(find.byKey(ValueKey('rating-${rating.code}-p1')));
        await tester.pump();
        expect(_submitButton(tester).onPressed, isNotNull);

        await tester.tap(find.byKey(const ValueKey('submit-rating')));
        await tester.pump();

        expect(repository.rounds, hasLength(1));
        expect(repository.rounds.single.ratings, {'p1': rating});
      });
    }

    testWidgets('shows waiting state when no voting is active', (tester) async {
      await _openVoting(tester, activeIds: []);
      expect(
        find.text('Głosowanie jeszcze się nie rozpoczęło'),
        findsOneWidget,
      );
      expect(find.text('Oceń prezentację'), findsNothing);
      expect(find.text('Zatwierdź'), findsNothing);
    });
  });
}

FilledButton _submitButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(const ValueKey('submit-rating')));

Future<MemoryFeedbackRepository> _openVoting(
  WidgetTester tester, {
  List<String> activeIds = const ['p1'],
  List<Presentation>? presentations,
}) async {
  final repository = MemoryFeedbackRepository(
    presentations:
        presentations ??
        const [
          Presentation(id: 'p1', title: 'Talk one', speaker: 'Speaker one'),
          Presentation(id: 'p2', title: 'Talk two', speaker: 'Speaker two'),
        ],
    activeIds: activeIds,
  );
  await tester.pumpWidget(
    FeedbackApp(repository: repository, initialConfig: testEventConfig),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump();
  return repository;
}
