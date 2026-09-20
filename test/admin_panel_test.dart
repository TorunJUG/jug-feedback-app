import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feedback_app/main.dart';

void main() {
  group('Admin presentation panel', () {
    testWidgets('shows totals and starts voting for selected presentation', (
      tester,
    ) async {
      var activeIds = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminPresentationPanel(
                presentations: const [
                  Presentation(
                    id: 'p1',
                    title: 'Talk one',
                    speaker: 'Speaker one',
                  ),
                  Presentation(
                    id: 'p2',
                    title: 'Talk two',
                    speaker: 'Speaker two',
                  ),
                ],
                activePresentationIds: const ['p2'],
                roundCount: (id) => id == 'p2' ? 7 : 0,
                onAutoSave: (_) async {},
                onDelete: (_, _) async {},
                onNewVoting: (ids) async => activeIds = ids,
                onCsv: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Prezentacje'), findsOneWidget);
      expect(find.text('Zebrane oceny'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('start-voting-p2')))
            .onPressed,
        isNotNull,
      );
      expect(activeIds, isEmpty);
      await tester.tap(find.byKey(const ValueKey('start-voting-p2')));
      await tester.pumpAndSettle();
      expect(find.text('Rozpocząć głosowanie od nowa?'), findsOneWidget);
      await tester.tap(find.text('Anuluj'));
      await tester.pumpAndSettle();
      expect(activeIds, isEmpty);
      await tester.tap(find.byKey(const ValueKey('start-voting-p2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rozpocznij od nowa'));
      await tester.pumpAndSettle();
      expect(activeIds, ['p2']);
    });

    testWidgets('centers collected rating badge in landscape column', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminPresentationPanel(
              presentations: const [
                Presentation(
                  id: 'p1',
                  title: 'Talk one',
                  speaker: 'Speaker one',
                ),
              ],
              roundCount: (_) => 7,
              onAutoSave: (_) async {},
              onDelete: (_, _) async {},
              onNewVoting: (_) async {},
              onCsv: null,
            ),
          ),
        ),
      );

      final header = tester.getRect(
        find.byKey(const ValueKey('admin-rating-header')),
      );
      final badge = tester.getRect(
        find.byKey(const ValueKey('rating-count-p1')),
      );
      expect(badge.center.dx, closeTo(header.center.dx, 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('stacks presentation management actions vertically on phone', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminPresentationPanel(
              presentations: const [
                Presentation(
                  id: 'p1',
                  title: 'Talk one',
                  speaker: 'Speaker one',
                ),
              ],
              roundCount: (_) => 2,
              onAutoSave: (_) async {},
              onDelete: (_, _) async {},
              onNewVoting: (_) async {},
              onCsv: null,
            ),
          ),
        ),
      );

      final actions = find.byKey(const ValueKey('presentation-actions-p1'));
      expect(actions, findsOneWidget);
      final newVoting = tester.getRect(
        find.byKey(const ValueKey('start-voting-p1')),
      );
      final edit = tester.getRect(
        find.widgetWithText(OutlinedButton, 'Edytuj'),
      );
      final delete = tester.getRect(
        find.byKey(const ValueKey('delete-presentation-p1')),
      );
      expect(newVoting.center.dx, closeTo(edit.center.dx, 1));
      expect(edit.center.dx, closeTo(delete.center.dx, 1));
      expect(newVoting.bottom, lessThanOrEqualTo(edit.top));
      expect(edit.bottom, lessThanOrEqualTo(delete.top));
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps spacing between long title and rating count on phone', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const title =
          'Dlaczego podejmowanie decyzji w szybko zmieniającym się środowisku jest wyzwaniem';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminPresentationPanel(
                presentations: const [
                  Presentation(id: 'p1', title: title, speaker: 'Speaker one'),
                ],
                roundCount: (_) => 12,
                onAutoSave: (_) async {},
                onDelete: (_, _) async {},
                onNewVoting: (_) async {},
                onCsv: null,
              ),
            ),
          ),
        ),
      );

      final titleRect = tester.getRect(find.text(title));
      final countRect = tester.getRect(find.text('12'));
      expect(countRect.left - titleRect.right, greaterThanOrEqualTo(16));
      expect(tester.takeException(), isNull);
    });

    testWidgets('presentation editor fits short landscape viewport', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 360);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminPresentationPanel(
                presentations: const [
                  Presentation(
                    id: 'p1',
                    title: 'Talk one',
                    speaker: 'Speaker one',
                  ),
                ],
                roundCount: (_) => 0,
                onAutoSave: (_) async {},
                onDelete: (_, _) async {},
                onNewVoting: (_) async {},
                onCsv: null,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Edytuj'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('presentation-title-input')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('presentation-speaker-input')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('presentation editor remains accessible with keyboard open', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminPresentationPanel(
                presentations: const [
                  Presentation(
                    id: 'p1',
                    title: 'Talk one',
                    speaker: 'Speaker one',
                  ),
                ],
                roundCount: (_) => 0,
                onAutoSave: (_) async {},
                onDelete: (_, _) async {},
                onNewVoting: (_) async {},
                onCsv: null,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Edytuj'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('presentation-title-input')));
      await tester.pump();

      expect(tester.view.viewInsets.bottom, 320);
      expect(
        find.byKey(const ValueKey('presentation-title-input')),
        findsOneWidget,
      );
      expect(find.text('Zapisz'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('validates required presentation fields', (tester) async {
      await tester.pumpWidget(_adminPanelApp(presentations: const []));
      await tester.tap(find.byKey(AdminPresentationPanel.addPresentationKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zapisz'));
      await tester.pumpAndSettle();

      expect(find.text('Wpisz tytuł prezentacji'), findsOneWidget);
      expect(find.text('Wpisz imię i nazwisko prelegenta'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('adds a presentation and autosaves entered values', (
      tester,
    ) async {
      List<Presentation>? saved;
      await tester.pumpWidget(
        _adminPanelApp(
          presentations: const [],
          onAutoSave: (presentations) async => saved = presentations,
        ),
      );
      await tester.tap(find.byKey(AdminPresentationPanel.addPresentationKey));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('presentation-title-input')),
        'New talk',
      );
      await tester.enterText(
        find.byKey(const ValueKey('presentation-speaker-input')),
        'New speaker',
      );
      await tester.tap(find.text('Zapisz'));
      await tester.pumpAndSettle();

      expect(saved, hasLength(1));
      expect(saved!.single.title, 'New talk');
      expect(saved!.single.speaker, 'New speaker');
      expect(find.text('Prezentacja dodana'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not save a presentation when editor is canceled', (
      tester,
    ) async {
      var saveCalled = false;
      await tester.pumpWidget(
        _adminPanelApp(
          presentations: const [],
          onAutoSave: (_) async => saveCalled = true,
        ),
      );
      await tester.tap(find.byKey(AdminPresentationPanel.addPresentationKey));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('presentation-title-input')),
        'Draft talk',
      );
      await tester.tap(find.text('Anuluj'));
      await tester.pumpAndSettle();

      expect(saveCalled, isFalse);
      expect(find.text('Draft talk'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not save an edit when editor is canceled', (
      tester,
    ) async {
      var saveCalled = false;
      await tester.pumpWidget(
        _adminPanelApp(onAutoSave: (_) async => saveCalled = true),
      );
      await tester.tap(find.text('Edytuj'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('presentation-title-input')),
        'Unsaved title',
      );
      await tester.tap(find.text('Anuluj'));
      await tester.pumpAndSettle();

      expect(saveCalled, isFalse);
      expect(find.text('Talk one'), findsOneWidget);
      expect(find.text('Unsaved title'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('edits a presentation and autosaves updated values', (
      tester,
    ) async {
      List<Presentation>? saved;
      await tester.pumpWidget(
        _adminPanelApp(
          onAutoSave: (presentations) async => saved = presentations,
        ),
      );
      await tester.tap(find.text('Edytuj'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('presentation-title-input')),
        'Updated title',
      );
      await tester.tap(find.text('Zapisz'));
      await tester.pumpAndSettle();

      expect(saved, hasLength(1));
      expect(saved!.single.id, 'p1');
      expect(saved!.single.title, 'Updated title');
      expect(saved!.single.speaker, 'Speaker one');
      expect(find.text('Zmiany zapisane'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps saved title when autosave fails', (tester) async {
      await tester.pumpWidget(
        _adminPanelApp(onAutoSave: (_) async => throw StateError('disk full')),
      );
      await tester.tap(find.text('Edytuj'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('presentation-title-input')),
        'Unpersisted title',
      );
      await tester.tap(find.text('Zapisz'));
      await tester.pumpAndSettle();

      expect(find.text('Talk one'), findsOneWidget);
      expect(find.text('Unpersisted title'), findsNothing);
      expect(find.text('Nie udało się zapisać prezentacji.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps presentation visible when delete callback fails', (
      tester,
    ) async {
      await tester.pumpWidget(
        _adminPanelApp(onDelete: (_, _) async => throw StateError('disk full')),
      );
      await tester.tap(find.text('Usuń'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usuń prezentację'));
      await tester.pumpAndSettle();

      expect(find.text('Talk one'), findsOneWidget);
      expect(find.text('Nie udało się usunąć prezentacji.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps presentation visible when deleting cannot persist', (
      tester,
    ) async {
      await tester.pumpWidget(
        _adminPanelApp(
          onDelete: (_, _) async => throw StateError('storage unavailable'),
        ),
      );

      await tester.tap(find.text('Usuń'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usuń prezentację'));
      await tester.pumpAndSettle();

      expect(find.text('Talk one'), findsOneWidget);
      expect(find.text('Nie udało się usunąć prezentacji.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disables adding presentations at five-item limit', (
      tester,
    ) async {
      await tester.pumpWidget(
        _adminPanelApp(
          presentations: List.generate(
            5,
            (index) => Presentation(
              id: 'p$index',
              title: 'Talk $index',
              speaker: 'Speaker $index',
            ),
          ),
        ),
      );

      final add = tester.widget<FilledButton>(
        find.byKey(AdminPresentationPanel.addPresentationKey),
      );
      expect(add.onPressed, isNull);
      expect(find.text('Prezentacja dodana'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows useful empty state and disables export without votes', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminPresentationPanel(
              presentations: const [],
              activePresentationIds: const [],
              roundCount: (_) => 0,
              onAutoSave: (_) async {},
              onDelete: (_, _) async {},
              onNewVoting: (_) async {},
              onCsv: null,
            ),
          ),
        ),
      );

      expect(find.text('Nie ma jeszcze prezentacji'), findsOneWidget);
      expect(
        find.byKey(AdminPresentationPanel.addPresentationKey),
        findsOneWidget,
      );
      expect(find.text('Eksportuj wyniki do CSV'), findsOneWidget);
      final export = tester.widget<OutlinedButton>(
        find.byKey(AdminPresentationPanel.exportCsvKey),
      );
      expect(export.onPressed, isNull);
    });

    testWidgets('deletes a presentation only after confirmation', (
      tester,
    ) async {
      const talks = [
        Presentation(id: 'p1', title: 'Talk one', speaker: 'Speaker one'),
      ];
      List<Presentation>? deletedList;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminPresentationPanel(
              presentations: talks,
              roundCount: (_) => 0,
              onAutoSave: (_) async {},
              onDelete: (_, updated) async => deletedList = updated,
              onNewVoting: (_) async {},
              onCsv: null,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Usuń'));
      await tester.pumpAndSettle();
      expect(deletedList, isNull);
      expect(find.text('Usunąć prezentację?'), findsOneWidget);
      await tester.tap(find.text('Usuń prezentację'));
      await tester.pumpAndSettle();
      expect(deletedList, isEmpty);
    });

    testWidgets('canceling presentation delete leaves item untouched', (
      tester,
    ) async {
      var deleteCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminPresentationPanel(
              presentations: const [
                Presentation(
                  id: 'p1',
                  title: 'Talk one',
                  speaker: 'Speaker one',
                ),
              ],
              roundCount: (_) => 0,
              onAutoSave: (_) async {},
              onDelete: (_, _) async => deleteCalled = true,
              onNewVoting: (_) async {},
              onCsv: null,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Usuń'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anuluj'));
      await tester.pumpAndSettle();

      expect(deleteCalled, isFalse);
      expect(find.text('Talk one'), findsOneWidget);
    });

    testWidgets('canceling restart does not start voting again', (
      tester,
    ) async {
      var voteStarted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminPresentationPanel(
              presentations: const [
                Presentation(
                  id: 'p1',
                  title: 'Talk one',
                  speaker: 'Speaker one',
                ),
              ],
              roundCount: (_) => 3,
              onAutoSave: (_) async {},
              onDelete: (_, _) async {},
              onNewVoting: (_) async => voteStarted = true,
              onCsv: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('start-voting-p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anuluj'));
      await tester.pumpAndSettle();

      expect(voteStarted, isFalse);
    });
  });
}

Widget _adminPanelApp({
  List<Presentation> presentations = const [
    Presentation(id: 'p1', title: 'Talk one', speaker: 'Speaker one'),
  ],
  Future<void> Function(List<Presentation>)? onAutoSave,
  Future<void> Function(String, List<Presentation>)? onDelete,
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: AdminPresentationPanel(
        presentations: presentations,
        roundCount: (_) => 0,
        onAutoSave: onAutoSave ?? (_) async {},
        onDelete: onDelete ?? (_, _) async {},
        onNewVoting: (_) async {},
        onCsv: null,
      ),
    ),
  ),
);
