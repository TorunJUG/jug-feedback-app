import 'package:feedback_app/main.dart';

class MemoryFeedbackRepository implements FeedbackRepository {
  MemoryFeedbackRepository({
    List<Presentation> presentations = const [],
    List<String> activeIds = const [],
    List<FeedbackRound> rounds = const [],
    this.loadError,
    this.saveRoundError,
    this.clearRatingsError,
    this.savePresentationsError,
    this.saveActiveIdsError,
  }) : presentations = [...presentations],
       activeIds = [...activeIds],
       rounds = [...rounds];

  List<Presentation> presentations;
  List<String> activeIds;
  List<FeedbackRound> rounds;
  Object? loadError;
  Object? saveRoundError;
  Object? clearRatingsError;
  Object? savePresentationsError;
  Object? saveActiveIdsError;

  @override
  Future<List<FeedbackRound>> loadRounds() async {
    if (loadError case final error?) throw error;
    return [...rounds];
  }

  @override
  Future<void> saveRound(FeedbackRound round) async {
    if (saveRoundError case final error?) throw error;
    rounds.add(round);
  }

  @override
  Future<void> clearRatingsForPresentation(String presentationId) async {
    if (clearRatingsError case final error?) throw error;
    rounds = rounds
        .map((round) {
          final updatedRatings = Map<String, Rating>.from(round.ratings)
            ..remove(presentationId);
          return FeedbackRound(
            id: round.id,
            createdAt: round.createdAt,
            ratings: updatedRatings,
          );
        })
        .where((round) => round.ratings.isNotEmpty)
        .toList();
  }

  @override
  Future<List<Presentation>?> loadPresentations() async => [...presentations];

  @override
  Future<void> savePresentations(List<Presentation> value) async {
    if (savePresentationsError case final error?) throw error;
    presentations = [...value];
  }

  @override
  Future<List<String>?> loadActivePresentationIds() async => [...activeIds];

  @override
  Future<void> saveActivePresentationIds(List<String> ids) async {
    if (saveActiveIdsError case final error?) throw error;
    activeIds = [...ids];
  }
}

const testEventConfig = EventConfig(
  id: 'event-test',
  title: 'Feedback App Test',
  date: '2026-01-01',
  pin: '1234',
  presentations: [
    Presentation(
      id: 'asset-talk-1',
      title: 'Asset talk one',
      speaker: 'Speaker one',
    ),
    Presentation(
      id: 'asset-talk-2',
      title: 'Asset talk two',
      speaker: 'Speaker two',
    ),
  ],
);
