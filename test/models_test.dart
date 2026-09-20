import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:feedback_app/main.dart';

void main() {
  group('Rating', () {
    test('maps stable codes to enum values', () {
      expect(ratingFromCode('poor'), Rating.poor);
      expect(ratingFromCode('neutral'), Rating.neutral);
      expect(ratingFromCode('good'), Rating.good);
      expect(ratingFromCode('super'), Rating.superRating);
      expect(ratingFromCode('unknown'), isNull);
    });
  });

  group('EventConfig', () {
    test('loads an empty presentation list', () {
      final config = EventConfig.fromJson(_configJson(0));

      expect(config.presentations, isEmpty);
    });

    test('loads config with up to five presentations', () {
      final config = EventConfig.fromJson(_configJson(5));
      expect(config.pin, '1234');
      expect(config.presentations, hasLength(5));
    });

    test('allows a single presentation', () {
      final config = EventConfig.fromJson(_configJson(1));

      expect(config.presentations, hasLength(1));
    });

    test('rejects more than five presentations', () {
      expect(() => EventConfig.fromJson(_configJson(6)), throwsFormatException);
    });

    test('rejects duplicate presentation ids', () {
      final json = _configJson(2);
      json['presentations'][1]['id'] = json['presentations'][0]['id'];
      expect(() => EventConfig.fromJson(json), throwsFormatException);
    });
  });

  group('FeedbackRound', () {
    test('round survives json round trip', () {
      final original = FeedbackRound(
        id: 'round-1',
        createdAt: DateTime.utc(2026, 1, 1),
        ratings: {'p1': Rating.good},
      );
      final restored = FeedbackRound.fromJson(
        jsonDecode(jsonEncode(original.toJson())),
      );
      expect(restored.id, original.id);
      expect(restored.createdAt, original.createdAt);
      expect(restored.ratings['p1'], Rating.good);
    });

    test('rejects unknown rating code', () {
      expect(
        () => FeedbackRound.fromJson({
          'id': 'round-1',
          'createdAt': DateTime.utc(2026).toIso8601String(),
          'ratings': {'p1': 'invalid'},
        }),
        throwsFormatException,
      );
    });
  });
}

Map<String, dynamic> _configJson(int count) => {
  'event': {'id': 'event-1', 'title': 'JUG', 'date': '2026-01-01'},
  'admin': {'pin': '1234'},
  'presentations': List.generate(
    count,
    (index) => {
      'id': 'p$index',
      'title': 'Talk $index',
      'speaker': 'Speaker $index',
    },
  ),
};
