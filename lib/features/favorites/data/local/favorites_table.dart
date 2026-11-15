import 'package:drift/drift.dart';

/// Sin clave foránea hacia `pokemon`: la sincronización del catálogo nunca
/// debe borrar ni modificar favoritos (PS-11).
@DataClassName('FavoriteRow')
class FavoritesTable extends Table {
  @override
  String get tableName => 'favorites';

  // ignore: recursive_getters
  IntColumn get pokemonId => integer().check(pokemonId.isBiggerThanValue(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {pokemonId};
}
