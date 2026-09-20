import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:feedback_app/main.dart';

import 'test_fakes.dart';

void main() {
  testWidgets('renders loading state before configuration loads', (
    tester,
  ) async {
    await tester.pumpWidget(const FeedbackApp());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows waiting screen when initial configuration has no talks', (
    tester,
  ) async {
    await tester.pumpWidget(
      FeedbackApp(
        repository: MemoryFeedbackRepository(),
        initialConfig: const EventConfig(
          id: 'empty-event',
          title: 'Empty event',
          date: '2026-01-01',
          pin: '1234',
          presentations: [],
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Głosowanie jeszcze się nie rozpoczęło'), findsOneWidget);
    expect(find.text('Talk one'), findsNothing);
    expect(find.text('Talk two'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'shows load error and retries when repository becomes available',
    (tester) async {
      final repository = MemoryFeedbackRepository()
        ..loadError = StateError('offline');
      await tester.pumpWidget(
        FeedbackApp(repository: repository, initialConfig: testEventConfig),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nie udało się wczytać konfiguracji'), findsOneWidget);
      expect(find.textContaining('offline'), findsOneWidget);

      repository.loadError = null;
      await tester.tap(find.text('Spróbuj ponownie'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Głosowanie jeszcze się nie rozpoczęło'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rejects incorrect organizer PIN and accepts correct PIN', (
    tester,
  ) async {
    final repository = MemoryFeedbackRepository(
      presentations: testEventConfig.presentations,
      activeIds: const ['asset-talk-1'],
    );
    await tester.pumpWidget(
      FeedbackApp(repository: repository, initialConfig: testEventConfig),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('rating-options-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-admin-panel')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('admin-pin-input')),
      '0000',
    );
    await tester.tap(find.text('Odblokuj'));
    await tester.pumpAndSettle();
    expect(find.text('Nieprawidłowy PIN. Spróbuj ponownie.'), findsOneWidget);
    expect(find.text('Asset talk one'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rating-options-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-admin-panel')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('admin-pin-input')),
      '1234',
    );
    await tester.tap(find.text('Odblokuj'));
    await tester.pumpAndSettle();
    expect(find.text('Panel organizatora'), findsOneWidget);
    expect(find.text('Prezentacje'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reports a vote save error and allows retry', (tester) async {
    final repository = MemoryFeedbackRepository(
      presentations: testEventConfig.presentations,
      activeIds: const ['asset-talk-1'],
    )..saveRoundError = StateError('storage unavailable');
    await tester.pumpWidget(
      FeedbackApp(repository: repository, initialConfig: testEventConfig),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rating-poor-asset-talk-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('submit-rating')));
    await tester.pumpAndSettle();

    expect(
      find.text('Nie udało się zapisać oceny. Spróbuj ponownie.'),
      findsOneWidget,
    );
    expect(find.text('Oceń prezentację'), findsOneWidget);
    expect(repository.rounds, isEmpty);

    repository.saveRoundError = null;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('submit-rating')));
    await tester.pumpAndSettle();
    expect(repository.rounds, hasLength(1));
    expect(find.text('Przekaż telefon kolejnej osobie'), findsOneWidget);
  });

  testWidgets('CSV export returns to organizer panel after save', (
    tester,
  ) async {
    final repository = MemoryFeedbackRepository(
      presentations: testEventConfig.presentations,
      activeIds: const ['asset-talk-1'],
      rounds: [
        FeedbackRound(
          id: 'round-1',
          createdAt: DateTime.utc(2026),
          ratings: const {'asset-talk-1': Rating.good},
        ),
      ],
    );
    await tester.pumpWidget(
      FeedbackApp(repository: repository, initialConfig: testEventConfig),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rating-options-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-admin-panel')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('admin-pin-input')),
      '1234',
    );
    await tester.tap(find.text('Odblokuj'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(AdminPresentationPanel.exportCsvKey));
    await tester.tap(find.byKey(AdminPresentationPanel.exportCsvKey));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Panel organizatora'), findsOneWidget);
    expect(find.text('Prezentacje'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('starts voting only after storage reset succeeds', (
    tester,
  ) async {
    final repository = MemoryFeedbackRepository(
      presentations: testEventConfig.presentations,
      activeIds: const ['asset-talk-1'],
      rounds: [
        FeedbackRound(
          id: 'round-1',
          createdAt: DateTime.utc(2026),
          ratings: const {'asset-talk-1': Rating.good},
        ),
      ],
    );
    await tester.pumpWidget(
      FeedbackApp(repository: repository, initialConfig: testEventConfig),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rating-options-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-admin-panel')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('admin-pin-input')),
      '1234',
    );
    await tester.tap(find.text('Odblokuj'));
    await tester.pumpAndSettle();

    repository.clearRatingsError = StateError('cannot clear storage');
    await tester.tap(find.byKey(const ValueKey('start-voting-asset-talk-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rozpocznij od nowa'));
    await tester.pumpAndSettle();

    expect(repository.activeIds, ['asset-talk-1']);
    expect(repository.rounds, hasLength(1));
    expect(find.text('Panel organizatora'), findsOneWidget);
    expect(
      find.text('Nie udało się rozpocząć głosowania. Spróbuj ponownie.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
