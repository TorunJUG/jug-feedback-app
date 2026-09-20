import 'package:flutter_test/flutter_test.dart';
import 'package:feedback_app/main.dart';

void main() {
  test('CSV rows contain one row per presentation rating', () {
    final config = EventConfig(
      id: 'event-1',
      title: 'JUG',
      date: '2026-01-01',
      pin: '1234',
      presentations: const [
        Presentation(id: 'p1', title: 'Talk, one', speaker: 'Speaker "A"'),
      ],
    );
    final round = FeedbackRound(
      id: 'round-1',
      createdAt: DateTime.utc(2026),
      ratings: {'p1': Rating.good},
    );

    final rows = ExportService.csvRows(config, [round]);

    expect(rows, hasLength(2));
    expect(rows.first, contains('presentationTitle'));
    expect(rows.last, contains('"Talk, one"'));
    expect(rows.last, contains('"Speaker ""A"""'));
    expect(rows.last, endsWith('"good"'));
  });

  test('CSV preserves stable code for every rating level', () {
    final ratings = Rating.values;
    final config = EventConfig(
      id: 'event-1',
      title: 'Feedback App',
      date: '2026-01-01',
      pin: '1234',
      presentations: ratings
          .map(
            (rating) => Presentation(
              id: 'p-${rating.code}',
              title: 'Talk ${rating.semanticLabel}',
              speaker: 'Speaker',
            ),
          )
          .toList(),
    );
    final round = FeedbackRound(
      id: 'round-1',
      createdAt: DateTime.utc(2026),
      ratings: {for (final rating in ratings) 'p-${rating.code}': rating},
    );

    final rows = ExportService.csvRows(config, [round]);
    expect(rows, hasLength(Rating.values.length + 1));
    for (var index = 0; index < ratings.length; index++) {
      expect(rows[index + 1], endsWith('"${ratings[index].code}"'));
    }
  });

  test('exports ratings even when presentation was removed later', () {
    final config = EventConfig(
      id: 'event-1',
      title: 'Feedback App',
      date: '2026-01-01',
      pin: '1234',
      presentations: const [],
    );
    final round = FeedbackRound(
      id: 'round-1',
      createdAt: DateTime.utc(2026),
      ratings: {'removed-presentation': Rating.superRating},
    );

    final rows = ExportService.csvRows(config, [round]);

    expect(rows, hasLength(2));
    expect(rows.last, contains('"removed-presentation"'));
    expect(rows.last, contains('"super"'));
  });

  test('keeps CSV titles and speaker names for current talks', () {
    final config = EventConfig(
      id: 'event-1',
      title: 'Feedback App',
      date: '2026-01-01',
      pin: '1234',
      presentations: const [
        Presentation(id: 'p1', title: 'Talk one', speaker: 'Speaker one'),
      ],
    );
    final round = FeedbackRound(
      id: 'round-1',
      createdAt: DateTime.utc(2026),
      ratings: {'p1': Rating.good},
    );

    final row = ExportService.csvRows(config, [round]).last;

    expect(row, contains('"Talk one"'));
    expect(row, contains('"Speaker one"'));
  });
}
