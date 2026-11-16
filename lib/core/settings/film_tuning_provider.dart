import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'film_tuning.dart';
import 'film_tuning_repository.dart';
import 'settings_provider.dart';

/// The repository that stores the fine tuning of the films.
final filmTuningRepositoryProvider = Provider<FilmTuningRepository>(
  (ref) => FilmTuningRepository(ref.watch(sharedPreferencesProvider)),
);

/// The fine tuning of every film that has one, keyed by film id.
///
/// A film that is not in the map is as its recipe says ([FilmTuning.defaults]).
final filmTuningsProvider =
    NotifierProvider<FilmTuningsNotifier, Map<String, FilmTuning>>(
      FilmTuningsNotifier.new,
    );

/// Changes the fine tuning of the films and stores it on the device.
class FilmTuningsNotifier extends Notifier<Map<String, FilmTuning>> {
  int _revision = 0;

  @override
  Map<String, FilmTuning> build() =>
      ref.watch(filmTuningRepositoryProvider).load();

  /// The tuning of the film [filmId].
  FilmTuning of(String filmId) => state[filmId] ?? FilmTuning.defaults;

  /// Replaces the tuning of the film [filmId] with `change(current)`.
  void update(String filmId, FilmTuning Function(FilmTuning current) change) {
    final revision = ++_revision;
    final next = change(of(filmId));
    final map = Map<String, FilmTuning>.of(state);
    if (next.isDefault) {
      map.remove(filmId);
    } else {
      map[filmId] = next;
    }
    state = map;
    final repository = ref.read(filmTuningRepositoryProvider);
    unawaited(
      repository
          .update(filmId, change)
          .then(
            (_) {
              if (ref.mounted && revision == _revision) {
                state = repository.load();
              }
            },
            onError: (Object _, StackTrace _) {
              if (ref.mounted && revision == _revision) {
                state = repository.load();
              }
            },
          ),
    );
  }
}
