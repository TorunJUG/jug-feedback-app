import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:feedback_app/main.dart';

import 'test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const kioskChannel = MethodChannel('com.feedbackapp.feedback_app/kiosk');
  var deviceOwner = false;
  var screenPinningActive = false;
  var lockTaskActive = false;
  final messenger = TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(kioskChannel, (call) async {
        switch (call.method) {
          case 'isDeviceOwner':
            return deviceOwner;
          case 'isLockTaskActive':
            return lockTaskActive;
          case 'isScreenPinningActive':
            return screenPinningActive;
          case 'enableLockTask':
            if (!deviceOwner) return false;
            lockTaskActive = true;
            return true;
          case 'disableLockTask':
            if (!lockTaskActive) return false;
            lockTaskActive = false;
            return true;
          default:
            return null;
        }
      });
  setUp(() {
    deviceOwner = false;
    screenPinningActive = false;
    lockTaskActive = false;
    kioskShakeEventsOverride = null;
  });

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
          password: 'kochamjug',
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

  testWidgets('rejects incorrect organizer password and accepts correct one', (
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
      find.byKey(const ValueKey('admin-password-input')),
      '0000',
    );
    await tester.tap(find.text('Odblokuj'));
    await tester.pumpAndSettle();
    expect(find.text('Nieprawidłowe hasło. Spróbuj ponownie.'), findsOneWidget);
    expect(find.text('Asset talk one'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rating-options-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-admin-panel')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('admin-password-input')),
      'kochamjug',
    );
    await tester.tap(find.text('Odblokuj'));
    await tester.pumpAndSettle();
    expect(find.text('Panel organizatora'), findsOneWidget);
    expect(find.text('Prezentacje'), findsOneWidget);
    final back = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Wróć'),
    );
    final side = back.style!.side!.resolve({})!;
    expect(side.color, const Color(0xffa9cbbb));
    expect(side.width, 1.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('organizer can open and return from rating results', (
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
      find.byKey(const ValueKey('admin-password-input')),
      'kochamjug',
    );
    await tester.tap(find.text('Odblokuj'));
    await tester.pumpAndSettle();

    final showResults = find.byKey(const ValueKey('show-results'));
    final exportResults = find.byKey(AdminPresentationPanel.exportCsvKey);
    await tester.ensureVisible(showResults);
    expect(tester.getRect(showResults).center.dy, greaterThan(0));
    expect(tester.getRect(exportResults).center.dy, greaterThan(0));
    await tester.tap(showResults);
    await tester.pumpAndSettle();
    expect(find.text('Wyniki'), findsOneWidget);
    expect(find.text('Dobrze: 1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('result-asset-talk-1-good')),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Panel organizatora'), findsOneWidget);
    expect(find.text('Prezentacje'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('device owner can enable and disable Android kiosk mode', (
    tester,
  ) async {
    deviceOwner = true;
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
      find.byKey(const ValueKey('admin-password-input')),
      'kochamjug',
    );
    await tester.tap(find.text('Odblokuj'));
    await tester.pumpAndSettle();

    expect(find.text('Włącz kiosk'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('kiosk-mode-toggle')));
    await tester.tap(find.byKey(const ValueKey('kiosk-mode-toggle')));
    await tester.pump();
    expect(find.text('Tryb kiosku włączony.'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(lockTaskActive, isTrue);
    expect(find.text('Tryb kiosku włączony.'), findsOneWidget);
    expect(find.text('Wyłącz kiosk'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('kiosk-mode-toggle')));
    await tester.pump();
    expect(find.text('Tryb kiosku wyłączony.'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(lockTaskActive, isFalse);
    expect(find.text('Włącz kiosk'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed kiosk enable restores off state and reports failure', (
    tester,
  ) async {
    deviceOwner = true;
    final repository = MemoryFeedbackRepository();
    await tester.pumpWidget(
      FeedbackApp(repository: repository, initialConfig: testEventConfig),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Panel organizatora'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('admin-password-input')),
      'kochamjug',
    );
    await tester.tap(find.text('Odblokuj'));
    await tester.pumpAndSettle();

    lockTaskActive = false;
    kioskEnableOverride = () async => false;
    await tester.tap(find.byKey(const ValueKey('kiosk-mode-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Włącz kiosk'), findsOneWidget);
    expect(find.text('Nie można włączyć kiosku. To urządzenie musi być skonfigurowane jako Device Owner.'), findsOneWidget);
    expect(lockTaskActive, isFalse);
    expect(tester.takeException(), isNull);
    kioskEnableOverride = null;
  });

  testWidgets('failed kiosk disable restores active state and reports failure', (
    tester,
  ) async {
    enableKioskShakeEventsForTesting = true;
    final failedDisableShakeEvents = StreamController<dynamic>.broadcast();
    addTearDown(() {
      enableKioskShakeEventsForTesting = false;
      kioskShakeEventsOverride = null;
      failedDisableShakeEvents.close();
    });
    deviceOwner = true;
    lockTaskActive = true;
    kioskShakeEventsOverride = failedDisableShakeEvents.stream;
    final repository = MemoryFeedbackRepository();
    await tester.pumpWidget(
      FeedbackApp(repository: repository, initialConfig: testEventConfig),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Panel organizatora'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('admin-password-input')),
      'kochamjug',
    );
    await tester.tap(find.text('Odblokuj'));
    await tester.pumpAndSettle();

    kioskDisableOverride = () async => false;
    await tester.tap(find.byKey(const ValueKey('kiosk-mode-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Wyłącz kiosk'), findsOneWidget);
    expect(find.text('Nie można wyłączyć trybu kiosku.'), findsOneWidget);
    expect(lockTaskActive, isTrue);
    expect(tester.takeException(), isNull);
    kioskDisableOverride = null;
  });

  testWidgets('non-device-owner cannot enable Lock Task from kiosk toggle', (
    tester,
  ) async {
    deviceOwner = false;
    final repository = MemoryFeedbackRepository();
    await tester.pumpWidget(
      FeedbackApp(repository: repository, initialConfig: testEventConfig),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Panel organizatora'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('admin-password-input')),
      'kochamjug',
    );
    await tester.tap(find.text('Odblokuj'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('kiosk-mode-toggle')), findsNothing);
    expect(find.text('Przypnij ekran'), findsNothing);
    expect(lockTaskActive, isFalse);
  });

  testWidgets('kiosk action asks to unpin Android screen first', (
    tester,
  ) async {
    deviceOwner = true;
    screenPinningActive = true;
    final repository = MemoryFeedbackRepository();
    await tester.pumpWidget(
      FeedbackApp(repository: repository, initialConfig: testEventConfig),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Panel organizatora'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('admin-password-input')),
      'kochamjug',
    );
    await tester.tap(find.text('Odblokuj'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('kiosk-mode-toggle')));
    await tester.pump();
    expect(
      find.text(
        'Najpierw odepnij przypięty ekran gestem Androida, potem włącz kiosk.',
      ),
      findsOneWidget,
    );
    expect(lockTaskActive, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shake opens password-protected emergency kiosk exit', (
    tester,
  ) async {
    enableKioskShakeEventsForTesting = true;
    addTearDown(() => enableKioskShakeEventsForTesting = false);
    final emergencyShakeEvents = StreamController<dynamic>.broadcast();
    kioskShakeEventsOverride = emergencyShakeEvents.stream;
    addTearDown(() {
      kioskShakeEventsOverride = null;
      emergencyShakeEvents.close();
    });
    deviceOwner = true;
    lockTaskActive = true;
    var allowEmergencyDisable = false;
    kioskDeviceOwnerOverride = () async => true;
    kioskActiveOverride = () async => true;
    kioskDisableOverride = () async {
      if (!allowEmergencyDisable) return false;
      lockTaskActive = false;
      return true;
    };
    addTearDown(() {
      kioskDeviceOwnerOverride = null;
      kioskActiveOverride = null;
      kioskDisableOverride = null;
    });
    final repository = MemoryFeedbackRepository();
    await tester.pumpWidget(
      FeedbackApp(repository: repository, initialConfig: testEventConfig),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Panel organizatora'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('admin-password-input')),
      'kochamjug',
    );
    await tester.tap(find.text('Odblokuj'));
    await tester.pumpAndSettle();
    expect(find.text('Wyłącz kiosk'), findsOneWidget);

    emergencyShakeEvents.add(DateTime.now().millisecondsSinceEpoch);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('emergency-kiosk-exit-dialog')), findsOneWidget);
    await tester.tap(find.text('Anuluj'));
    await tester.pumpAndSettle();
    expect(lockTaskActive, isTrue);
    expect(find.byKey(const ValueKey('emergency-kiosk-exit-dialog')), findsNothing);

    emergencyShakeEvents.add(DateTime.now().millisecondsSinceEpoch);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('emergency-kiosk-exit-dialog')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('emergency-kiosk-password-input')),
      'wrong-password',
    );
    await tester.tap(find.byKey(const ValueKey('emergency-kiosk-exit-confirm')));
    await tester.pumpAndSettle();
    expect(lockTaskActive, isTrue);
    expect(find.text('Nieprawidłowe hasło organizatora.'), findsOneWidget);

    emergencyShakeEvents.add(DateTime.now().millisecondsSinceEpoch);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('emergency-kiosk-password-input')),
      'kochamjug',
    );
    await tester.tap(find.byKey(const ValueKey('emergency-kiosk-exit-confirm')));
    await tester.pumpAndSettle();
    expect(lockTaskActive, isTrue);
    expect(find.text('Nie można wyłączyć trybu kiosku.'), findsOneWidget);

    allowEmergencyDisable = true;
    emergencyShakeEvents.add(DateTime.now().millisecondsSinceEpoch);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('emergency-kiosk-exit-dialog')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('emergency-kiosk-password-input')),
      'kochamjug',
    );
    await tester.tap(find.byKey(const ValueKey('emergency-kiosk-exit-confirm')));
    await tester.pumpAndSettle();
    expect(lockTaskActive, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shake cannot open emergency exit when kiosk is inactive', (
    tester,
  ) async {
    enableKioskShakeEventsForTesting = true;
    addTearDown(() => enableKioskShakeEventsForTesting = false);
    final inactiveShakeEvents = StreamController<dynamic>.broadcast();
    kioskShakeEventsOverride = inactiveShakeEvents.stream;
    addTearDown(() {
      kioskShakeEventsOverride = null;
      inactiveShakeEvents.close();
    });
    deviceOwner = true;
    lockTaskActive = false;
    final repository = MemoryFeedbackRepository();
    await tester.pumpWidget(
      FeedbackApp(repository: repository, initialConfig: testEventConfig),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    inactiveShakeEvents.add(DateTime.now().millisecondsSinceEpoch);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('emergency-kiosk-exit-dialog')), findsNothing);
    expect(lockTaskActive, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('organizer enables and disables lock task from admin panel', (
    tester,
  ) async {
    deviceOwner = true;
    final repository = MemoryFeedbackRepository();
    await tester.pumpWidget(
      FeedbackApp(repository: repository, initialConfig: testEventConfig),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Panel organizatora'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('admin-password-input')),
      'kochamjug',
    );
    await tester.tap(find.text('Odblokuj'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('kiosk-mode-toggle')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('kiosk-mode-toggle')));
    await tester.tap(find.byKey(const ValueKey('kiosk-mode-toggle')));
    await tester.pumpAndSettle();
    expect(lockTaskActive, isTrue);
    expect(find.text('Wyłącz kiosk'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('kiosk-mode-toggle')));
    await tester.tap(find.byKey(const ValueKey('kiosk-mode-toggle')));
    await tester.pumpAndSettle();
    expect(lockTaskActive, isFalse);
    expect(find.text('Włącz kiosk'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deleting presentation removes its ratings from results', (
    tester,
  ) async {
    final repository = MemoryFeedbackRepository(
      presentations: testEventConfig.presentations,
      activeIds: const ['asset-talk-2'],
      rounds: [
        FeedbackRound(
          id: 'round-1',
          createdAt: DateTime.utc(2026),
          ratings: const {
            'asset-talk-1': Rating.good,
            'asset-talk-2': Rating.superRating,
          },
        ),
        FeedbackRound(
          id: 'round-2',
          createdAt: DateTime.utc(2026, 1, 2),
          ratings: const {'asset-talk-1': Rating.neutral},
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
      find.byKey(const ValueKey('admin-password-input')),
      'kochamjug',
    );
    await tester.tap(find.text('Odblokuj'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('delete-presentation-asset-talk-2')),
    );
    await tester.tap(
      find.byKey(const ValueKey('delete-presentation-asset-talk-2')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usuń prezentację'));
    await tester.pumpAndSettle();

    expect(repository.presentations.map((presentation) => presentation.id), [
      'asset-talk-1',
    ]);
    expect(repository.activeIds, isEmpty);
    expect(repository.rounds, hasLength(2));
    expect(repository.rounds[0].ratings, {'asset-talk-1': Rating.good});
    expect(repository.rounds[1].ratings, {'asset-talk-1': Rating.neutral});

    final showResults = find.byKey(const ValueKey('show-results'));
    final exportResults = find.byKey(AdminPresentationPanel.exportCsvKey);
    await tester.ensureVisible(showResults);
    expect(tester.getRect(showResults).center.dy, greaterThan(0));
    expect(tester.getRect(exportResults).center.dy, greaterThan(0));
    await tester.tap(showResults);
    await tester.pumpAndSettle();
    expect(find.text('Asset talk one'), findsOneWidget);
    expect(find.text('Asset talk two'), findsNothing);
    expect(
      find.byKey(const ValueKey('result-asset-talk-1-good')),
      findsOneWidget,
    );
    expect(find.text('Dobrze: 1'), findsOneWidget);
    expect(find.text('Neutralnie: 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('startup removes orphaned ratings from stored rounds', (
    tester,
  ) async {
    final repository = MemoryFeedbackRepository(
      presentations: const [
        Presentation(
          id: 'current-talk',
          title: 'Current talk',
          speaker: 'Speaker',
        ),
      ],
      rounds: [
        FeedbackRound(
          id: 'mixed-round',
          createdAt: DateTime.utc(2026),
          ratings: const {
            'current-talk': Rating.good,
            'deleted-talk': Rating.superRating,
          },
        ),
        FeedbackRound(
          id: 'orphaned-round',
          createdAt: DateTime.utc(2026, 1, 2),
          ratings: const {'deleted-talk': Rating.poor},
        ),
      ],
    );

    await tester.pumpWidget(
      FeedbackApp(
        repository: repository,
        initialConfig: const EventConfig(
          id: 'event-test',
          title: 'Test event',
          date: '2026-01-01',
          password: 'kochamjug',
          presentations: [],
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(repository.rounds, hasLength(1));
    expect(repository.rounds.single.id, 'mixed-round');
    expect(repository.rounds.single.ratings, {'current-talk': Rating.good});
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
    expect(_selectedRating(tester), Rating.poor);

    repository.saveRoundError = null;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('submit-rating')))
          .onPressed,
      isNotNull,
    );
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
      find.byKey(const ValueKey('admin-password-input')),
      'kochamjug',
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

  testWidgets('disables results and export when presentation list is empty', (
    tester,
  ) async {
    final repository = MemoryFeedbackRepository(
      rounds: [
        FeedbackRound(
          id: 'orphaned-round',
          createdAt: DateTime.utc(2026),
          ratings: const {'removed-presentation': Rating.good},
        ),
      ],
    );
    await tester.pumpWidget(
      FeedbackApp(
        repository: repository,
        initialConfig: const EventConfig(
          id: 'empty-event',
          title: 'Empty event',
          date: '2026-01-01',
          password: 'kochamjug',
          presentations: [],
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Panel organizatora'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('admin-password-input')),
      'kochamjug',
    );
    await tester.tap(find.text('Odblokuj'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('show-results')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(AdminPresentationPanel.exportCsvKey),
          )
          .onPressed,
      isNull,
    );
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
      find.byKey(const ValueKey('admin-password-input')),
      'kochamjug',
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

Rating? _selectedRating(WidgetTester tester) {
  for (final rating in Rating.values) {
    final buttonMaterial = tester.widget<Material>(
      find.descendant(
        of: find.byKey(ValueKey('rating-${rating.code}-asset-talk-1')),
        matching: find.byType(Material),
      ),
    );
    if (buttonMaterial.color != Colors.white) return rating;
  }
  return null;
}
