import 'dart:async';

import '../domain/sync_activity_monitor.dart';

final class SyncActivityTracker implements SyncActivityMonitor {
  int _running = 0;
  final _changes = StreamController<SyncActivity>.broadcast(sync: true);

  SyncActivity get current =>
      _running > 0 ? SyncActivity.syncing : SyncActivity.idle;

  @override
  Stream<SyncActivity> watchActivity() =>
      Stream<SyncActivity>.multi((listener) {
        final subscription = _changes.stream.listen(listener.addSync);
        listener.add(current);
        listener.onCancel = subscription.cancel;
      });

  Future<T> track<T>(Future<T> Function() operation) async {
    if (_running++ == 0) _changes.add(SyncActivity.syncing);
    try {
      return await operation();
    } finally {
      if (--_running == 0) _changes.add(SyncActivity.idle);
    }
  }

  Future<void> dispose() => _changes.close();
}
