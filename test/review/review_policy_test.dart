import 'package:carrete/core/settings/review_state.dart';
import 'package:carrete/review/review_policy.dart';
import 'package:flutter_test/flutter_test.dart';

const CivilDay _first = CivilDay(2026, 11, 1);
const String _version = '0.2.0';

CivilDay _after(CivilDay day, int days) {
  final moment = DateTime.utc(day.year, day.month, day.day + days);
  return CivilDay(moment.year, moment.month, moment.day);
}

/// A state that passes every rule on [_after] 7 days of [_first].
ReviewState _ready({
  int openDays = 5,
  List<String> requested = const <String>[],
  CivilDay? lastRequest,
  CivilDay? lastImport,
}) => ReviewState(
  firstOpenDay: _first,
  lastOpenDay: _after(_first, 7),
  openDays: openDays,
  requestedVersions: requested,
  lastRequestDay: lastRequest,
  lastImportDay: lastImport,
);

bool _ask(
  ReviewState state, {
  int daysAfterFirst = 7,
  bool work = true,
  bool firstUse = false,
  String version = _version,
}) => ReviewPolicy.shouldAsk(
  state: state,
  today: _after(_first, daysAfterFirst),
  appVersion: version,
  hasOwnWork: work,
  inFirstUse: firstUse,
);

void main() {
  test('asks when every rule holds', () {
    expect(_ask(_ready()), isTrue);
  });

  group('days since the first open', () {
    test('6 days is too soon, 7 is enough', () {
      expect(_ask(_ready(), daysAfterFirst: 6), isFalse);
      expect(_ask(_ready(), daysAfterFirst: 7), isTrue);
    });

    test('nothing recorded yet never asks', () {
      expect(_ask(const ReviewState(openDays: 9)), isFalse);
    });

    test('a month boundary counts real days', () {
      const first = CivilDay(2026, 2, 25);
      final state = ReviewState(firstOpenDay: first, openDays: 5);
      expect(
        ReviewPolicy.shouldAsk(
          state: state,
          today: const CivilDay(2026, 3, 3),
          appVersion: _version,
          hasOwnWork: true,
          inFirstUse: false,
        ),
        isFalse,
        reason: '25 February to 3 March 2026 is 6 days (February has 28)',
      );
      expect(
        ReviewPolicy.shouldAsk(
          state: state,
          today: const CivilDay(2026, 3, 4),
          appVersion: _version,
          hasOwnWork: true,
          inFirstUse: false,
        ),
        isTrue,
      );
    });
  });

  group('days the app was opened', () {
    test('4 days is too few, 5 is enough', () {
      expect(_ask(_ready(openDays: 4)), isFalse);
      expect(_ask(_ready(openDays: 5)), isTrue);
    });
  });

  group('own work', () {
    test('no work never asks', () {
      expect(_ask(_ready(), work: false), isFalse);
    });

    test('a developed roll or 10 loose photos is work, 9 photos is not', () {
      expect(ReviewPolicy.ownWork(developedRolls: 0, loosePhotos: 0), isFalse);
      expect(ReviewPolicy.ownWork(developedRolls: 0, loosePhotos: 9), isFalse);
      expect(ReviewPolicy.ownWork(developedRolls: 0, loosePhotos: 10), isTrue);
      expect(ReviewPolicy.ownWork(developedRolls: 1, loosePhotos: 0), isTrue);
    });
  });

  group('first use and imports', () {
    test('the first use never asks', () {
      expect(_ask(_ready(), firstUse: true), isFalse);
    });

    test('the day of an import and the 2 days after stay quiet', () {
      final today = _after(_first, 7);
      expect(_ask(_ready(lastImport: today)), isFalse);
      expect(_ask(_ready(lastImport: _after(today, -1))), isFalse);
      expect(_ask(_ready(lastImport: _after(today, -2))), isFalse);
    });

    test(
      '3 days after an import it asks again (import on day 1, ask on 4)',
      () {
        final today = _after(_first, 7);
        expect(_ask(_ready(lastImport: _after(today, -3))), isTrue);
        expect(_ask(_ready(lastImport: _after(today, -4))), isTrue);
        expect(
          ReviewPolicy.inImportSilence(
            const CivilDay(2026, 11, 1),
            const CivilDay(2026, 11, 3),
          ),
          isTrue,
        );
        expect(
          ReviewPolicy.inImportSilence(
            const CivilDay(2026, 11, 1),
            const CivilDay(2026, 11, 4),
          ),
          isFalse,
        );
      },
    );

    test('an import dated in the future (clock went back) stays quiet', () {
      expect(_ask(_ready(lastImport: _after(_first, 9))), isFalse);
    });
  });

  group('requests', () {
    test('3 requests is the limit, 2 still allows one', () {
      final long = _after(_first, 400);
      ReviewState state(List<String> versions) => ReviewState(
        firstOpenDay: _first,
        openDays: 9,
        requestedVersions: versions,
        lastRequestDay: _after(long, -200),
      );
      expect(
        ReviewPolicy.shouldAsk(
          state: state(['0.1.0', '0.1.5']),
          today: long,
          appVersion: _version,
          hasOwnWork: true,
          inFirstUse: false,
        ),
        isTrue,
      );
      expect(
        ReviewPolicy.shouldAsk(
          state: state(['0.1.0', '0.1.5', '0.1.9']),
          today: long,
          appVersion: _version,
          hasOwnWork: true,
          inFirstUse: false,
        ),
        isFalse,
      );
    });

    test('one request per app version', () {
      final state = _ready(
        requested: ['0.1.0'],
        lastRequest: _after(_first, -200),
      );
      expect(_ask(state, version: '0.1.0'), isFalse);
      expect(_ask(state, version: '0.2.0'), isTrue);
    });

    test('90 days between requests: 89 is too soon, 90 is enough', () {
      final last = _after(_first, 7 - 89);
      final state = _ready(requested: ['0.1.0'], lastRequest: last);
      expect(_ask(state), isFalse);
      final older = _ready(
        requested: ['0.1.0'],
        lastRequest: _after(_first, 7 - 90),
      );
      expect(_ask(older), isTrue);
    });
  });

  group('CivilDay and the counters', () {
    test('a day is counted once and a clock going back adds nothing', () {
      var state = ReviewState.empty;
      state = state.withOpenOn(const CivilDay(2026, 11, 3));
      state = state.withOpenOn(const CivilDay(2026, 11, 3));
      expect(state.openDays, 1);
      state = state.withOpenOn(const CivilDay(2026, 11, 4));
      expect(state.openDays, 2);
      state = state.withOpenOn(const CivilDay(2026, 11, 2));
      expect(state.openDays, 2);
      expect(state.firstOpenDay, const CivilDay(2026, 11, 3));
      expect(state.lastOpenDay, const CivilDay(2026, 11, 4));
    });

    test('it survives a round trip through json, and bad json is empty', () {
      final state = ReviewState.empty
          .withOpenOn(const CivilDay(2026, 11, 3))
          .withRequestOn(const CivilDay(2026, 11, 20), '0.2.0')
          .withImportOn(const CivilDay(2026, 11, 21));
      final back = ReviewState.fromJson(state.toJson());
      expect(back.toJson(), state.toJson());
      expect(back.requestCount, 1);
      final bad = ReviewState.fromJson({
        'firstOpenDay': 'yesterday',
        'openDays': -4,
        'requestedVersions': 'x',
      });
      expect(bad.toJson(), ReviewState.empty.toJson());
    });

    test('an impossible date is not read', () {
      expect(CivilDay.tryParse('2026-02-30'), isNull);
      expect(CivilDay.tryParse('2026-2-3'), isNull);
      expect(CivilDay.tryParse(null), isNull);
      expect(CivilDay.tryParse('2026-02-28'), const CivilDay(2026, 2, 28));
    });
  });
}
