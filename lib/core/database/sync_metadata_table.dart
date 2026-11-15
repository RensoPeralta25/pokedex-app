import 'package:drift/drift.dart';

@DataClassName('SyncMetadataRow')
class SyncMetadataTable extends Table {
  @override
  String get tableName => 'sync_metadata';

  TextColumn get resourceKey => text()();
  DateTimeColumn get lastSuccessAt => dateTime().nullable()();

  /// Null antes de la primera descarga o cuando ya no hay más páginas.
  IntColumn get nextOffset =>
      // ignore: recursive_getters
      integer().nullable().check(nextOffset.isBiggerOrEqualValue(0))();
  TextColumn get status => text()();

  @override
  Set<Column> get primaryKey => {resourceKey};
}

abstract final class SyncStatus {
  static const success = 'success';
}
