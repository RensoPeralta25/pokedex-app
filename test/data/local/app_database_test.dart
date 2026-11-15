import 'package:dart_final_project/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
  });

  test('crea las tablas e índices del esquema v1', () async {
    final rows = await db
        .customSelect(
          "SELECT type, name FROM sqlite_master "
          "WHERE type IN ('table', 'index') AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    final names = {for (final row in rows) row.read<String>('name')};

    expect(
      names,
      containsAll({
        'pokemon',
        'types',
        'pokemon_types',
        'favorites',
        'sync_metadata',
        'idx_pokemon_order',
        'idx_pokemon_name',
        'idx_pokemon_types_type',
      }),
    );
  });

  test('activa las claves foráneas al abrir', () async {
    final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(row.read<int>('foreign_keys'), 1);
  });

  test('rechaza una relación de tipo hacia un Pokémon inexistente', () async {
    await db
        .into(db.typesTable)
        .insert(TypesTableCompanion.insert(name: 'fire'));

    await expectLater(
      db
          .into(db.pokemonTypesTable)
          .insert(
            PokemonTypesTableCompanion.insert(
              pokemonId: 999,
              slot: 1,
              typeName: 'fire',
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });
}
