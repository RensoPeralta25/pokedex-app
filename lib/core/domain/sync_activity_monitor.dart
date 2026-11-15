enum SyncActivity { idle, syncing }

abstract interface class SyncActivityMonitor {
  Stream<SyncActivity> watchActivity();
}
