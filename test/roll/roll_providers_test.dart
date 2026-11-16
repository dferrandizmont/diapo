import 'dart:async';

import 'package:diapo/core/database/app_database.dart';
import 'package:diapo/core/database/database_provider.dart';
import 'package:diapo/core/database/rolls_dao.dart';
import 'package:diapo/roll/roll_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_database.dart';

class _StreamingRolls extends RollsDao {
  _StreamingRolls(super.database, this.stream);

  final Stream<RollRow?> stream;

  @override
  Stream<RollRow?> watchRoll(int id) => stream;
}

void main() {
  test('the last roll listener leaving cancels its stream', () async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    var cancelled = false;
    final stream = StreamController<RollRow?>(onCancel: () => cancelled = true);
    addTearDown(stream.close);
    final container = ProviderContainer(
      overrides: [
        rollsDaoProvider.overrideWithValue(
          _StreamingRolls(database, stream.stream),
        ),
      ],
    );
    addTearDown(container.dispose);
    final first = container.listen(rollProvider(7), (_, _) {});
    final last = container.listen(rollProvider(7), (_, _) {});
    expect(stream.hasListener, isTrue);
    first.close();
    await container.pump();
    expect(cancelled, isFalse);
    last.close();
    await container.pump();
    expect(cancelled, isTrue);
    expect(stream.hasListener, isFalse);
  });
}
