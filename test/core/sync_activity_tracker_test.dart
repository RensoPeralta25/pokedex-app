import 'dart:async';

import 'package:dart_final_project/core/data/sync_activity_tracker.dart';
import 'package:dart_final_project/core/domain/sync_activity_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SyncActivityTracker tracker;

  setUp(() {
    tracker = SyncActivityTracker();
    addTearDown(tracker.dispose);
  });

  test('marca syncing mientras hay operaciones, incluso simultáneas', () async {
    final emitted = <SyncActivity>[];
    final subscription = tracker.watchActivity().listen(emitted.add);
    addTearDown(subscription.cancel);

    final first = Completer<void>();
    final second = Completer<void>();
    final a = tracker.track(() => first.future);
    final b = tracker.track(() => second.future);
    expect(tracker.current, SyncActivity.syncing);

    first.complete();
    await a;
    expect(tracker.current, SyncActivity.syncing);

    second.complete();
    await b;
    expect(tracker.current, SyncActivity.idle);
    expect(emitted, [
      SyncActivity.idle,
      SyncActivity.syncing,
      SyncActivity.idle,
    ]);
  });

  test('vuelve a idle si la operación falla y propaga el error', () async {
    await expectLater(
      tracker.track<void>(() async => throw StateError('fallo')),
      throwsStateError,
    );
    expect(tracker.current, SyncActivity.idle);
  });
}
