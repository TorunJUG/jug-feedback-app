import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const FeedbackApp());
}

enum Rating { poor, neutral, good, superRating }

extension RatingLabel on Rating {
  String get code => switch (this) {
    Rating.poor => 'poor',
    Rating.neutral => 'neutral',
    Rating.good => 'good',
    Rating.superRating => 'super',
  };
  String get label => switch (this) {
    Rating.poor => '😞',
    Rating.neutral => '😐',
    Rating.good => '😀',
    Rating.superRating => '🤩',
  };

  String get semanticLabel => switch (this) {
    Rating.poor => 'Słabo',
    Rating.neutral => 'Neutralnie',
    Rating.good => 'Dobrze',
    Rating.superRating => 'Super',
  };
}

Rating? ratingFromCode(String? value) => switch (value) {
  'poor' => Rating.poor,
  'neutral' => Rating.neutral,
  'good' => Rating.good,
  'super' => Rating.superRating,
  _ => null,
};

class Presentation {
  const Presentation({
    required this.id,
    required this.title,
    required this.speaker,
  });
  final String id;
  final String title;
  final String speaker;

  factory Presentation.fromJson(Map<String, dynamic> json) => Presentation(
    id: json['id'] as String,
    title: json['title'] as String,
    speaker: json['speaker'] as String,
  );
}

class EventConfig {
  const EventConfig({
    required this.id,
    required this.title,
    required this.date,
    required this.pin,
    required this.presentations,
  });
  final String id;
  final String title;
  final String date;
  final String pin;
  final List<Presentation> presentations;

  factory EventConfig.fromJson(Map<String, dynamic> json) {
    final presentations = (json['presentations'] as List<dynamic>)
        .map((item) => Presentation.fromJson(item as Map<String, dynamic>))
        .toList();
    if (presentations.length > 5) {
      throw const FormatException(
        'Konfiguracja może zawierać maksymalnie 5 prezentacji.',
      );
    }
    if (presentations.map((item) => item.id).toSet().length !=
        presentations.length) {
      throw const FormatException(
        'Identyfikatory prezentacji muszą być unikalne.',
      );
    }
    return EventConfig(
      id: (json['event'] as Map<String, dynamic>)['id'] as String,
      title: (json['event'] as Map<String, dynamic>)['title'] as String,
      date: (json['event'] as Map<String, dynamic>)['date'] as String,
      pin: (json['admin'] as Map<String, dynamic>)['pin'] as String,
      presentations: presentations,
    );
  }
}

Map<String, dynamic> presentationToJson(Presentation presentation) => {
  'id': presentation.id,
  'title': presentation.title,
  'speaker': presentation.speaker,
};

List<Presentation> activePresentations(
  List<Presentation> presentations,
  List<String> activeIds,
) => presentations
    .where((presentation) => activeIds.contains(presentation.id))
    .toList();

class FeedbackRound {
  const FeedbackRound({
    required this.id,
    required this.createdAt,
    required this.ratings,
  });
  final String id;
  final DateTime createdAt;
  final Map<String, Rating> ratings;

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'ratings': ratings.map((key, value) => MapEntry(key, value.code)),
  };

  factory FeedbackRound.fromJson(Map<String, dynamic> json) => FeedbackRound(
    id: json['id'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    ratings: (json['ratings'] as Map<String, dynamic>).map((key, value) {
      final rating = ratingFromCode(value as String);
      if (rating == null) throw const FormatException('Nieznana ocena.');
      return MapEntry(key, rating);
    }),
  );
}

abstract interface class FeedbackRepository {
  Future<List<FeedbackRound>> loadRounds();
  Future<void> saveRound(FeedbackRound round);
  Future<void> clearRatingsForPresentation(String presentationId);
  Future<List<Presentation>?> loadPresentations();
  Future<void> savePresentations(List<Presentation> presentations);
  Future<List<String>?> loadActivePresentationIds();
  Future<void> saveActivePresentationIds(List<String> ids);
}

class LocalRepository implements FeedbackRepository {
  static const _roundsKey = 'feedback_rounds';
  static const _presentationsKey = 'feedback_presentations';
  static const _activePresentationIdsKey = 'active_presentation_ids';
  @override
  Future<List<FeedbackRound>> loadRounds() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getStringList(_roundsKey) ?? [];
    return raw
        .map(
          (item) =>
              FeedbackRound.fromJson(jsonDecode(item) as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<void> saveRound(FeedbackRound round) async {
    final preferences = await SharedPreferences.getInstance();
    final rounds = preferences.getStringList(_roundsKey) ?? [];
    await preferences.setStringList(_roundsKey, [
      ...rounds,
      jsonEncode(round.toJson()),
    ]);
  }

  @override
  Future<void> clearRatingsForPresentation(String presentationId) async {
    final rounds = await loadRounds();
    final preferences = await SharedPreferences.getInstance();
    final filtered = rounds
        .map((round) {
          final ratings = Map<String, Rating>.from(round.ratings)
            ..remove(presentationId);
          return FeedbackRound(
            id: round.id,
            createdAt: round.createdAt,
            ratings: ratings,
          );
        })
        .where((round) => round.ratings.isNotEmpty)
        .map((round) => jsonEncode(round.toJson()))
        .toList();
    await preferences.setStringList(_roundsKey, filtered);
  }

  @override
  Future<List<Presentation>?> loadPresentations() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getStringList(_presentationsKey);
    if (raw == null) return null;
    return raw
        .map(
          (item) =>
              Presentation.fromJson(jsonDecode(item) as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<void> savePresentations(List<Presentation> presentations) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _presentationsKey,
      presentations
          .map((item) => jsonEncode(presentationToJson(item)))
          .toList(),
    );
  }

  @override
  Future<List<String>?> loadActivePresentationIds() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_activePresentationIdsKey);
  }

  @override
  Future<void> saveActivePresentationIds(List<String> ids) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_activePresentationIdsKey, ids);
  }
}

class ExportService {
  static List<String> csvRows(EventConfig config, List<FeedbackRound> rounds) {
    final rows = <List<String>>[
      [
        'roundId',
        'createdAt',
        'presentationId',
        'presentationTitle',
        'speaker',
        'rating',
      ],
    ];
    final presentationsById = {
      for (final presentation in config.presentations)
        presentation.id: presentation,
    };
    for (final round in rounds) {
      for (final entry in round.ratings.entries) {
        final presentation = presentationsById[entry.key];
        rows.add([
          round.id,
          round.createdAt.toIso8601String(),
          entry.key,
          presentation?.title ?? entry.key,
          presentation?.speaker ?? '',
          entry.value.code,
        ]);
      }
    }
    return rows
        .map(
          (row) =>
              row.map((value) => '"${value.replaceAll('"', '""')}"').join(','),
        )
        .toList();
  }

  static Future<bool> saveCsv(
    EventConfig config,
    List<FeedbackRound> rounds,
  ) async {
    final csv = csvRows(config, rounds).join('\n');
    if (kIsWeb) {
      final file = XFile.fromData(
        Uint8List.fromList(utf8.encode(csv)),
        mimeType: 'text/csv',
        name: 'jug-feedback.csv',
      );
      await SharePlus.instance.share(
        ShareParams(files: [file], text: 'Feedback z ${config.title}'),
      );
      return true;
    }
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/jug-feedback.csv';
    await File(path).writeAsString(csv);
    final savedPath = await FlutterFileDialog.saveFile(
      params: SaveFileDialogParams(
        sourceFilePath: path,
        fileName: 'feedback-results.csv',
      ),
    );
    return savedPath != null;
  }
}

class FeedbackApp extends StatelessWidget {
  const FeedbackApp({super.key, this.repository, this.initialConfig});
  final FeedbackRepository? repository;
  final EventConfig? initialConfig;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Feedback App',
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xfff6f7f4),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff16856f),
        brightness: Brightness.light,
        surface: const Color(0xffffffff),
      ),
      cardTheme: const CardThemeData(
        color: Color(0xffffffff),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xffdfe7e3),
        thickness: 1,
      ),
    ),
    home: FeedbackHome(repository: repository, initialConfig: initialConfig),
  );
}

class FeedbackHome extends StatefulWidget {
  const FeedbackHome({super.key, this.repository, this.initialConfig});
  final FeedbackRepository? repository;
  final EventConfig? initialConfig;
  @override
  State<FeedbackHome> createState() => _FeedbackHomeState();
}

class _FeedbackHomeState extends State<FeedbackHome> {
  late final FeedbackRepository _repository;
  EventConfig? _config;
  List<FeedbackRound> _rounds = [];
  List<Presentation> _presentations = [];
  List<String> _activePresentationIds = [];
  Map<String, Rating> _draft = {};
  bool _loading = true;
  String? _error;
  bool _admin = false;
  bool _savingRound = false;
  int? _countdown;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? LocalRepository();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final config =
          widget.initialConfig ??
          EventConfig.fromJson(
            jsonDecode(await rootBundle.loadString('assets/config/event.json'))
                as Map<String, dynamic>,
          );
      final rounds = await _repository.loadRounds();
      final presentations =
          await _repository.loadPresentations() ?? config.presentations;
      final activeIds = await _repository.loadActivePresentationIds() ?? [];
      if (mounted) {
        setState(() {
          _config = config;
          _rounds = rounds;
          _presentations = presentations;
          _activePresentationIds = activeIds;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  void _choose(String id, Rating rating) => setState(() => _draft[id] = rating);

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _submitRound() async {
    final visiblePresentations = _visiblePresentations;
    if (_savingRound ||
        _config == null ||
        visiblePresentations.isEmpty ||
        _draft.length != visiblePresentations.length) {
      return;
    }
    setState(() => _savingRound = true);
    final round = FeedbackRound(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      ratings: Map.of(_draft),
    );
    try {
      await _repository.saveRound(round);
    } catch (error) {
      if (mounted) {
        setState(() => _savingRound = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nie udało się zapisać oceny. Spróbuj ponownie.'),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _rounds = [..._rounds, round];
      _draft = {};
      _savingRound = false;
      _countdown = 5;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown == null || _countdown! <= 1) {
        timer.cancel();
        setState(() => _countdown = null);
      } else {
        setState(() => _countdown = _countdown! - 1);
      }
    });
  }

  Future<void> _openAdmin() async {
    final pin = await _askPin();
    if (pin == _config?.pin && mounted) {
      setState(() {
        _admin = true;
      });
    } else if (pin != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nieprawidłowy PIN. Spróbuj ponownie.')),
      );
    }
  }

  Future<void> _startNewVoting(List<String> ids) async {
    late final List<FeedbackRound> rounds;
    try {
      for (final id in ids) {
        await _repository.clearRatingsForPresentation(id);
      }
      rounds = await _repository.loadRounds();
      await _repository.saveActivePresentationIds(ids);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nie udało się rozpocząć głosowania. Spróbuj ponownie.',
            ),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _rounds = rounds;
      _activePresentationIds = ids;
      _draft = {};
      _admin = false;
    });
  }

  List<Presentation> get _visiblePresentations =>
      activePresentations(_presentations, _activePresentationIds);

  Future<void> _savePresentationsAutomatically(
    List<Presentation> presentations,
  ) async {
    await _repository.savePresentations(presentations);
    final activeIds = _activePresentationIds
        .where((id) => presentations.any((item) => item.id == id))
        .toList();
    await _repository.saveActivePresentationIds(activeIds);
    if (!mounted) return;
    setState(() {
      _presentations = presentations;
      _activePresentationIds = activeIds;
      _draft = {};
    });
  }

  Future<void> _deletePresentation(
    String presentationId,
    List<Presentation> presentations,
  ) async {
    await _repository.clearRatingsForPresentation(presentationId);
    await _repository.savePresentations(presentations);
    final rounds = await _repository.loadRounds();
    if (!mounted) return;
    setState(() {
      _presentations = presentations;
      _activePresentationIds = _activePresentationIds
          .where((id) => id != presentationId)
          .toList();
      _rounds = rounds;
      _draft.remove(presentationId);
    });
  }

  Future<String?> _askPin() async {
    return showDialog<String>(
      context: context,
      builder: (_) => const _AdminPinDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 44,
                        color: Color(0xffb5473c),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Nie udało się wczytać konfiguracji',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xff64736d)),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Spróbuj ponownie'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (_countdown != null) return _CountdownScreen(value: _countdown!);
    if (_admin) {
      return _AdminScreen(
        rounds: _rounds,
        presentations: _presentations,
        activePresentationIds: _activePresentationIds,
        onBack: () => setState(() => _admin = false),
        onAutoSave: _savePresentationsAutomatically,
        onDelete: _deletePresentation,
        onNewVoting: _startNewVoting,
        onCsv: _rounds.isEmpty
            ? null
            : () async {
                final messenger = ScaffoldMessenger.of(context);
                bool saved;
                try {
                  saved = await ExportService.saveCsv(
                    EventConfig(
                      id: _config!.id,
                      title: _config!.title,
                      date: _config!.date,
                      pin: _config!.pin,
                      presentations: _presentations,
                    ),
                    _rounds,
                  );
                } catch (_) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Nie udało się wyeksportować pliku CSV.'),
                    ),
                  );
                  return;
                }
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      saved
                          ? 'Plik CSV został zapisany.'
                          : 'Zapis pliku anulowany.',
                    ),
                  ),
                );
              },
      );
    }
    if (_visiblePresentations.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xffe4f1ec),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.how_to_vote_outlined,
                        color: Color(0xff147763),
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Głosowanie jeszcze się nie rozpoczęło',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xff172a25),
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Poczekaj, aż organizator wybierze prezentację i uruchomi głosowanie.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xff64736d),
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: _openAdmin,
                      child: const Text('Panel organizatora'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 560;
            final landscape = constraints.maxWidth > constraints.maxHeight;
            final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
            final horizontalPadding = constraints.maxWidth < 500 ? 16.0 : 24.0;
            final visible = _visiblePresentations;
            if (landscape && visible.length == 1) {
              return _LandscapeVotingLayout(
                constraints: constraints,
                presentation: visible.single,
                selected: _draft[visible.single.id],
                saving: _savingRound,
                canSubmit: !_savingRound && _draft.length == visible.length,
                onSelect: _choose,
                onOpenAdmin: _openAdmin,
                onSubmit: _submitRound,
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: compact ? 4 : 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: compact ? 44 : 52,
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 48),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Oceń prezentację',
                                  key: const ValueKey('voting-screen-title'),
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontSize: compact ? 24 : 34,
                                    fontWeight: FontWeight.w800,
                                    height: 1.05,
                                    color: const Color(0xff172a25),
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: PopupMenuButton<String>(
                                key: const ValueKey('rating-options-menu'),
                                tooltip: 'Opcje organizatora',
                                onSelected: (value) {
                                  if (value == 'admin') _openAdmin();
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    key: ValueKey('open-admin-panel'),
                                    value: 'admin',
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(
                                        Icons.admin_panel_settings_outlined,
                                      ),
                                      title: Text('Panel organizatora'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Wybierz ocenę. Możesz ją zmienić przed zatwierdzeniem.',
                          style: TextStyle(
                            color: Color(0xff64736d),
                            fontSize: 14,
                          ),
                        ),
                      ],
                      SizedBox(height: compact ? 4 : 12),
                      Expanded(
                        child: largeText && !landscape
                            ? SingleChildScrollView(
                                child: Column(
                                  children: [
                                    for (
                                      var index = 0;
                                      index < visible.length;
                                      index++
                                    ) ...[
                                      if (index > 0)
                                        SizedBox(height: compact ? 6 : 10),
                                      _PresentationCard(
                                        presentation: visible[index],
                                        selected: _draft[visible[index].id],
                                        onSelect: _choose,
                                        compact: compact,
                                        landscape: landscape,
                                        fillAvailableSpace: false,
                                        textScale: MediaQuery.textScalerOf(
                                          context,
                                        ).scale(1),
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            : Column(
                                children: [
                                  for (
                                    var index = 0;
                                    index < visible.length;
                                    index++
                                  ) ...[
                                    if (index > 0)
                                      SizedBox(height: compact ? 6 : 10),
                                    Expanded(
                                      child: _PresentationCard(
                                        presentation: visible[index],
                                        selected: _draft[visible[index].id],
                                        onSelect: _choose,
                                        compact: compact,
                                        landscape: landscape,
                                        fillAvailableSpace: true,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                      ),
                      SizedBox(height: compact ? 4 : 10),
                      Align(
                        alignment: landscape
                            ? Alignment.centerRight
                            : Alignment.center,
                        child: SizedBox(
                          width: landscape
                              ? (constraints.maxWidth - horizontalPadding * 2)
                                    .clamp(0, 240)
                              : double.infinity,
                          height: compact ? 48 : 56,
                          child: FilledButton(
                            key: const ValueKey('submit-rating'),
                            onPressed:
                                !_savingRound &&
                                    visible.isNotEmpty &&
                                    _draft.length == visible.length
                                ? _submitRound
                                : null,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            child: _savingRound
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Zatwierdź'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LandscapeVotingLayout extends StatelessWidget {
  const _LandscapeVotingLayout({
    required this.constraints,
    required this.presentation,
    required this.selected,
    required this.saving,
    required this.canSubmit,
    required this.onSelect,
    required this.onOpenAdmin,
    required this.onSubmit,
  });

  final BoxConstraints constraints;
  final Presentation presentation;
  final Rating? selected;
  final bool saving;
  final bool canSubmit;
  final void Function(String, Rating) onSelect;
  final VoidCallback onOpenAdmin;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final tight = constraints.maxHeight < 400;
    final desktop = constraints.maxWidth >= 900;
    final ratingGrid = LayoutBuilder(
      builder: (context, gridConstraints) {
        final spacing = desktop ? 4.0 : 8.0;
        final cellWidth = (gridConstraints.maxWidth - spacing * 3) / 4;
        final cellHeight = desktop ? 112.0 : gridConstraints.maxHeight;
        return GridView.count(
          key: const ValueKey('rating-grid'),
          crossAxisCount: 4,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: cellWidth / cellHeight,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: Rating.values.map((rating) {
            final isSelected = selected == rating;
            return OutlinedButton(
              key: ValueKey('rating-${rating.code}-${presentation.id}'),
              onPressed: () => onSelect(presentation.id, rating),
              style: OutlinedButton.styleFrom(
                backgroundColor: isSelected
                    ? _ratingColor(rating)
                    : Colors.white,
                foregroundColor: const Color(0xff283b35),
                side: BorderSide(
                  color: isSelected
                      ? _ratingBorderColor(rating)
                      : const Color(0xffd8e1dc),
                  width: isSelected ? 2 : 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(desktop ? 8 : 14),
                ),
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    rating.label,
                    style: TextStyle(fontSize: tight ? 22 : 26),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      rating.semanticLabel,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: tight ? 13 : 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: constraints.maxWidth < 500 ? 12 : 20,
        vertical: tight ? 4 : 8,
      ),
      child: Center(
        child: ConstrainedBox(
          key: desktop ? const ValueKey('desktop-voting-content') : null,
          constraints: BoxConstraints(
            maxWidth: desktop ? 1440 : double.infinity,
            maxHeight: desktop ? 520 : double.infinity,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: tight ? 36 : 42,
                child: Row(
                  key: const ValueKey('landscape-voting-header'),
                  children: [
                    Expanded(
                      child: Text(
                        'Oceń prezentację',
                        key: const ValueKey('voting-screen-title'),
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          fontSize: tight ? 22 : 26,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          color: const Color(0xff172a25),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: PopupMenuButton<String>(
                        key: const ValueKey('rating-options-menu'),
                        tooltip: 'Opcje organizatora',
                        onSelected: (value) {
                          if (value == 'admin') onOpenAdmin();
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            key: ValueKey('open-admin-panel'),
                            value: 'admin',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.admin_panel_settings_outlined,
                              ),
                              title: Text('Panel organizatora'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: tight ? 4 : 8),
              SizedBox(
                key: const ValueKey('landscape-rating-instructions'),
                height: tight ? 22 : 24,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Wybierz ocenę. Możesz ją zmienić przed zatwierdzeniem.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: tight ? 12 : 14,
                      color: const Color(0xff64736d),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: desktop
                    ? 4
                    : tight
                    ? 2
                    : 6,
              ),
              Container(
                key: const ValueKey('landscape-presentation-info'),
                padding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: tight ? 6 : 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xffe2e9e5)),
                  borderRadius: BorderRadius.circular(desktop ? 0 : 14),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              presentation.title,
                              key: ValueKey(
                                'presentation-title-${presentation.id}',
                              ),
                              softWrap: true,
                              style: TextStyle(
                                fontSize: tight ? 15 : 18,
                                height: 1.1,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xff172a25),
                              ),
                            ),
                            SizedBox(height: tight ? 2 : 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  size: 18,
                                  color: Color(0xff64736d),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    presentation.speaker,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: tight ? 12 : 14,
                                      color: const Color(0xff64736d),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: desktop
                    ? 4
                    : tight
                    ? 4
                    : 8,
              ),
              if (desktop)
                SizedBox(height: 112, child: ratingGrid)
              else
                Expanded(child: ratingGrid),
              SizedBox(
                height: desktop
                    ? 4
                    : tight
                    ? 4
                    : 8,
              ),
              SizedBox(
                height: 48,
                child: FilledButton(
                  key: const ValueKey('submit-rating'),
                  onPressed: canSubmit ? onSubmit : null,
                  style: FilledButton.styleFrom(
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Zatwierdź'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresentationCard extends StatelessWidget {
  const _PresentationCard({
    required this.presentation,
    required this.selected,
    required this.onSelect,
    this.compact = false,
    this.landscape = false,
    this.fillAvailableSpace = false,
    this.textScale = 1,
  });
  final Presentation presentation;
  final Rating? selected;
  final void Function(String, Rating) onSelect;
  final bool compact;
  final bool landscape;
  final bool fillAvailableSpace;
  final double textScale;
  @override
  Widget build(BuildContext context) {
    final details = Container(
      padding: EdgeInsets.only(left: compact ? 8 : 14),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 4,
          ),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            presentation.title,
            key: ValueKey('presentation-title-${presentation.id}'),
            softWrap: true,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: compact ? 16 : 21,
              height: compact ? 1.12 : 1.25,
              color: const Color(0xff172a25),
            ),
          ),
          SizedBox(height: compact ? 4 : 9),
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 18,
                color: Color(0xff64736d),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  presentation.speaker,
                  style: TextStyle(
                    color: const Color(0xff64736d),
                    fontSize: compact ? 12 : 15,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Expanded(child: details)],
    );
    final ratings = LayoutBuilder(
      builder: (context, constraints) {
        final columns = textScale > 1.3
            ? 1
            : landscape || constraints.maxWidth < 560
            ? 2
            : 4;
        final spacing = compact ? 8.0 : 10.0;
        final rows = (Rating.values.length / columns).ceil();
        final cellWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final cellHeight = fillAvailableSpace
            ? (constraints.maxHeight - spacing * (rows - 1)) / rows
            : 64.0 * textScale.clamp(1, 2);
        return GridView.count(
          key: const ValueKey('rating-grid'),
          crossAxisCount: columns,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: cellWidth / cellHeight,
          shrinkWrap: !fillAvailableSpace,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: Rating.values.map((rating) {
            final isSelected = selected == rating;
            return Semantics(
              label: rating.semanticLabel,
              button: true,
              selected: isSelected,
              child: OutlinedButton(
                key: ValueKey('rating-${rating.code}-${presentation.id}'),
                onPressed: () => onSelect(presentation.id, rating),
                style: OutlinedButton.styleFrom(
                  backgroundColor: isSelected
                      ? _ratingColor(rating)
                      : Colors.white,
                  foregroundColor: const Color(0xff283b35),
                  side: BorderSide(
                    color: isSelected
                        ? _ratingBorderColor(rating)
                        : const Color(0xffd8e1dc),
                    width: isSelected ? 2 : 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 8,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      rating.label,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(fontSize: compact ? 24 : 28),
                    ),
                    const SizedBox(height: 0),
                    Text(
                      rating.semanticLabel,
                      textScaler: TextScaler.noScaling,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: textScale > 1.3
                            ? 16
                            : compact
                            ? 12
                            : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );

    return Card(
      color: const Color(0xffffffff),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xffe2e9e5)),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 22),
        child: landscape
            ? Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [header, const Spacer()],
                    ),
                  ),
                  const SizedBox(width: 16),
                  const VerticalDivider(width: 1, color: Color(0xffe7eeea)),
                  const SizedBox(width: 16),
                  Expanded(flex: 6, child: ratings),
                ],
              )
            : Column(
                mainAxisSize: fillAvailableSpace
                    ? MainAxisSize.max
                    : MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  SizedBox(height: compact ? 10 : 20),
                  const Divider(height: 1, color: Color(0xffe7eeea)),
                  SizedBox(height: compact ? 8 : 16),
                  if (fillAvailableSpace) Expanded(child: ratings) else ratings,
                ],
              ),
      ),
    );
  }
}

Color _ratingColor(Rating rating) => switch (rating) {
  Rating.poor => const Color(0xffffe5e1),
  Rating.neutral => const Color(0xfffff1cf),
  Rating.good => const Color(0xffd8f2e8),
  Rating.superRating => const Color(0xffdce8ff),
};

Color _ratingBorderColor(Rating rating) => switch (rating) {
  Rating.poor => const Color(0xffc9685b),
  Rating.neutral => const Color(0xffbf8a22),
  Rating.good => const Color(0xff25866d),
  Rating.superRating => const Color(0xff5876b8),
};

class _CountdownScreen extends StatelessWidget {
  const _CountdownScreen({required this.value});
  final int value;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'TURA ZAPISANA',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 2,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Przekaż telefon kolejnej osobie',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 30),
          Text(
            '$value',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 150,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    ),
  );
}

class _AdminScreen extends StatelessWidget {
  const _AdminScreen({
    required this.rounds,
    required this.presentations,
    required this.activePresentationIds,
    required this.onBack,
    required this.onAutoSave,
    required this.onDelete,
    required this.onNewVoting,
    required this.onCsv,
  });
  final List<FeedbackRound> rounds;
  final List<Presentation> presentations;
  final List<String> activePresentationIds;
  final VoidCallback onBack;
  final Future<void> Function(List<Presentation> presentations) onAutoSave;
  final Future<void> Function(String id, List<Presentation> presentations)
  onDelete;
  final Future<void> Function(List<String> ids) onNewVoting;
  final VoidCallback? onCsv;
  @override
  Widget build(BuildContext context) {
    final ratingCounts = <String, int>{};
    for (final round in rounds) {
      for (final presentationId in round.ratings.keys) {
        ratingCounts.update(
          presentationId,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Panel organizatora',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: onBack,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              textStyle: const TextStyle(fontSize: 16),
                            ),
                            child: const Text('Wróć'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    AdminPresentationPanel(
                      presentations: presentations,
                      activePresentationIds: activePresentationIds,
                      roundCount: (id) => ratingCounts[id] ?? 0,
                      onAutoSave: onAutoSave,
                      onDelete: onDelete,
                      onNewVoting: onNewVoting,
                      onCsv: onCsv,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminPresentationPanel extends StatefulWidget {
  const AdminPresentationPanel({
    super.key,
    required this.presentations,
    this.activePresentationIds = const [],
    required this.onAutoSave,
    required this.onDelete,
    required this.onNewVoting,
    required this.onCsv,
    required this.roundCount,
  });
  final List<Presentation> presentations;
  final List<String> activePresentationIds;
  final Future<void> Function(List<Presentation> presentations) onAutoSave;
  final Future<void> Function(String id, List<Presentation> presentations)
  onDelete;
  final Future<void> Function(List<String> ids) onNewVoting;
  final VoidCallback? onCsv;
  final int Function(String presentationId) roundCount;
  static const addPresentationKey = ValueKey('admin-add-presentation');
  static const exportCsvKey = ValueKey('admin-export-csv');

  @override
  State<AdminPresentationPanel> createState() => _AdminPresentationPanelState();
}

class _AdminPresentationPanelState extends State<AdminPresentationPanel> {
  late List<Presentation> _presentations;

  @override
  void initState() {
    super.initState();
    _presentations = [...widget.presentations];
  }

  @override
  void didUpdateWidget(covariant AdminPresentationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.presentations != widget.presentations) {
      _presentations = [...widget.presentations];
    }
  }

  Future<void> _editPresentation({Presentation? existing, int? index}) async {
    final result = await showDialog<Presentation>(
      context: context,
      builder: (_) => _PresentationEditorDialog(presentation: existing),
    );
    if (result == null || !mounted) return;
    final updated = [..._presentations];
    if (index == null) {
      updated.add(result);
    } else {
      updated[index] = result;
    }
    try {
      await widget.onAutoSave(updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie udało się zapisać prezentacji.')),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() => _presentations = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existing == null ? 'Prezentacja dodana' : 'Zmiany zapisane',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _startVoting(Presentation presentation) async {
    if (widget.roundCount(presentation.id) > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rozpocząć głosowanie od nowa?'),
          content: Text(
            'Dotychczasowe oceny prezentacji „${presentation.title}” zostaną usunięte.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Rozpocznij od nowa'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await widget.onNewVoting([presentation.id]);
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final headerStyle = const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              );
              Widget columnHeader() => const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Divider(color: Color(0xffb8d8cd), thickness: 1.5),
              );
              final wide = constraints.maxWidth >= 900;
              final ratingColumnWidth = wide ? 210.0 : 112.0;
              final rows = _presentations.asMap().entries.map((entry) {
                final presentation = entry.value;
                final ratingCount = widget.roundCount(presentation.id);
                final actionButtons = [
                  FilledButton.tonal(
                    key: ValueKey('start-voting-${presentation.id}'),
                    onPressed: () => _startVoting(presentation),
                    child: const Text('Nowe głosowanie'),
                  ),
                  OutlinedButton(
                    onPressed: () => _editPresentation(
                      existing: presentation,
                      index: entry.key,
                    ),
                    child: const Text('Edytuj'),
                  ),
                  TextButton(
                    key: ValueKey('delete-presentation-${presentation.id}'),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final shouldDelete = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Usunąć prezentację?'),
                          content: Text(
                            '„${presentation.title}” oraz zebrane dla niej oceny zostaną usunięte.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('Anuluj'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('Usuń prezentację'),
                            ),
                          ],
                        ),
                      );
                      if (shouldDelete != true || !mounted) {
                        return;
                      }
                      final updated = [..._presentations]..removeAt(entry.key);
                      try {
                        await widget.onDelete(presentation.id, updated);
                      } catch (_) {
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Nie udało się usunąć prezentacji.',
                              ),
                            ),
                          );
                        }
                        return;
                      }
                      if (mounted) setState(() => _presentations = updated);
                    },
                    child: const Text('Usuń'),
                  ),
                ];
                final actions = wide
                    ? Wrap(spacing: 8, runSpacing: 4, children: actionButtons)
                    : Column(
                        key: ValueKey(
                          'presentation-actions-${presentation.id}',
                        ),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (
                            var index = 0;
                            index < actionButtons.length;
                            index++
                          ) ...[
                            if (index > 0) const SizedBox(height: 4),
                            actionButtons[index],
                          ],
                        ],
                      );
                final details = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      presentation.title,
                      key: ValueKey('presentation-title-${presentation.id}'),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      presentation.speaker,
                      style: const TextStyle(color: Color(0xff64736d)),
                    ),
                  ],
                );
                final card = DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xfff8faf8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xffe7eeea)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: details),
                              const SizedBox(width: 12),
                              actions,
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: details),
                                  const SizedBox(width: 16),
                                  _RatingCountBadge(count: ratingCount),
                                ],
                              ),
                              const SizedBox(height: 10),
                              actions,
                            ],
                          ),
                  ),
                );

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: card),
                            const SizedBox(width: 24),
                            SizedBox(
                              width: ratingColumnWidth,
                              child: Center(
                                child: _RatingCountBadge(
                                  key: ValueKey(
                                    'rating-count-${presentation.id}',
                                  ),
                                  count: ratingCount,
                                ),
                              ),
                            ),
                          ],
                        )
                      : card,
                );
              });

              final emptyState = Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.event_note_outlined,
                        size: 36,
                        color: Color(0xff718079),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Nie ma jeszcze prezentacji',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Dodaj tytuł i prelegenta, aby przygotować głosowanie.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xff64736d)),
                      ),
                    ],
                  ),
                ),
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Prezentacje', style: headerStyle)),
                      SizedBox(
                        width: ratingColumnWidth,
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              key: const ValueKey('admin-rating-header'),
                              'Zebrane oceny',
                              maxLines: 1,
                              softWrap: false,
                              style: headerStyle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: columnHeader()),
                      const SizedBox(width: 24),
                      SizedBox(width: ratingColumnWidth, child: columnHeader()),
                    ],
                  ),
                  if (_presentations.isEmpty) emptyState,
                  if (_presentations.isNotEmpty) ...rows,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              const dividerWidth = 210.0;
              return Row(
                children: [
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Divider(color: Color(0xffb8d8cd), thickness: 1.5),
                    ),
                  ),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: dividerWidth,
                    child: const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Divider(color: Color(0xffb8d8cd), thickness: 1.5),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 540;
              return Align(
                alignment: narrow ? Alignment.center : Alignment.centerRight,
                child: Wrap(
                  alignment: narrow ? WrapAlignment.center : WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      key: AdminPresentationPanel.addPresentationKey,
                      onPressed: _presentations.length >= 5
                          ? null
                          : () => _editPresentation(),
                      icon: const Icon(Icons.add),
                      label: const Text('Dodaj prezentację'),
                    ),
                    OutlinedButton(
                      key: AdminPresentationPanel.exportCsvKey,
                      onPressed: widget.onCsv,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: widget.onCsv == null
                            ? const Color(0xff8a9690)
                            : null,
                      ),
                      child: const Text('Eksportuj wyniki do CSV'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}

class _RatingCountBadge extends StatelessWidget {
  const _RatingCountBadge({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$count zebranych ocen',
    child: Container(
      constraints: const BoxConstraints(minWidth: 96, minHeight: 44),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: count == 0 ? const Color(0xfff1f4f2) : const Color(0xffe4f1ec),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '$count',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
  );
}

class _PresentationEditorDialog extends StatefulWidget {
  const _PresentationEditorDialog({this.presentation});
  final Presentation? presentation;

  @override
  State<_PresentationEditorDialog> createState() =>
      _PresentationEditorDialogState();
}

class _PresentationEditorDialogState extends State<_PresentationEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _speakerController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.presentation?.title ?? '',
    );
    _speakerController = TextEditingController(
      text: widget.presentation?.speaker ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _speakerController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      Presentation(
        id:
            widget.presentation?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        speaker: _speakerController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 500;
    return AlertDialog(
      title: Text(
        widget.presentation == null
            ? 'Dodaj prezentację'
            : 'Edytuj prezentację',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('presentation-title-input'),
                controller: _titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Tytuł prezentacji',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Wpisz tytuł prezentacji'
                    : null,
              ),
              SizedBox(height: compact ? 8 : 16),
              TextFormField(
                key: const ValueKey('presentation-speaker-input'),
                controller: _speakerController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  labelText: 'Prelegent',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Wpisz imię i nazwisko prelegenta'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        FilledButton(onPressed: _save, child: const Text('Zapisz')),
      ],
    );
  }
}

class _AdminPinDialog extends StatefulWidget {
  const _AdminPinDialog();

  @override
  State<_AdminPinDialog> createState() => _AdminPinDialogState();
}

class _AdminPinDialogState extends State<_AdminPinDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Panel organizatora'),
    content: TextField(
      key: const ValueKey('admin-pin-input'),
      controller: _controller,
      autofocus: true,
      obscureText: true,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 8,
      textInputAction: TextInputAction.done,
      onSubmitted: (value) => Navigator.pop(context, value),
      decoration: const InputDecoration(
        labelText: 'PIN organizatora',
        border: OutlineInputBorder(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Anuluj'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('Odblokuj'),
      ),
    ],
  );
}
