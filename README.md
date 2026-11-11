# Pokédex — Proyecto final de Desarrollo de Aplicaciones Móviles

Aplicación Flutter. Esta base corresponde únicamente a **KAN-7 / PKD-01**:
estructura por funcionalidades, navegación inicial y contratos entre módulos.

## Requisitos y ejecución

Usar una instalación de Flutter que incluya Dart compatible con `^3.13.5`,
según `pubspec.yaml`, y un simulador/dispositivo configurado.

```sh
flutter pub get
flutter run
```

La app abre un catálogo de tres Pokémon de demostración. Se puede abrir su
destino de detalle y navegar entre Catálogo, Favoritos y Trivia. Las pantallas
restantes son bases para los siguientes tickets. No hay red ni persistencia.

## Estructura

- `lib/app/`: aplicación, navegación e inyección por constructor.
- `lib/core/`: identidad y servicios compartidos.
- `lib/features/`: catálogo, detalle, favoritos y trivia.
- `test/`: pruebas de contratos, navegación y sustitución de dependencias.
- `docs/architecture.md`: acuerdos, límites y criterios pendientes de KAN-7.

Cada funcionalidad incorpora `domain`, `data` y `presentation` según su necesidad.
El dominio utiliza Dart puro. Las pantallas dependen de interfaces; las
implementaciones se seleccionan en `AppDependencies`.

## Validación

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Consultar [Arquitectura y contratos](docs/architecture.md) antes de implementar
los siguientes tickets. El acuerdo y la contribución verificable del segundo
integrante siguen pendientes de revisión conjunta.
