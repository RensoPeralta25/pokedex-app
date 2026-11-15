import 'package:drift/drift.dart';

@DataClassName('PokemonRow')
@TableIndex(name: 'idx_pokemon_order', columns: {#nationalNumber, #id})
@TableIndex(name: 'idx_pokemon_name', columns: {#name})
class PokemonTable extends Table {
  @override
  String get tableName => 'pokemon';

  // ignore: recursive_getters
  IntColumn get id => integer().check(id.isBiggerThanValue(0))();
  TextColumn get name => text()();
  IntColumn get nationalNumber => integer().nullable()();
  TextColumn get artworkUrl => text().nullable()();
  TextColumn get spriteUrl => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// La consulta GraphQL solo trae el nombre del tipo, por eso es la clave.
@DataClassName('TypeRow')
class TypesTable extends Table {
  @override
  String get tableName => 'types';

  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {name};
}

@DataClassName('PokemonTypeRow')
@TableIndex(name: 'idx_pokemon_types_type', columns: {#typeName})
class PokemonTypesTable extends Table {
  @override
  String get tableName => 'pokemon_types';

  IntColumn get pokemonId =>
      integer().references(PokemonTable, #id, onDelete: KeyAction.cascade)();
  // ignore: recursive_getters
  IntColumn get slot => integer().check(slot.isBiggerThanValue(0))();
  TextColumn get typeName => text().references(TypesTable, #name)();

  @override
  Set<Column> get primaryKey => {pokemonId, slot};
}
