import 'package:flutter/material.dart';

import 'app_dependencies.dart';
import 'app_shell.dart';
import 'connectivity_indicator.dart';

class PokedexApp extends StatelessWidget {
  const PokedexApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Pokédex',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.red, useMaterial3: true),
    // Orden invertido: el indicador se pinta después de las rutas porque su
    // BlockSemantics ocultaría a TalkBack lo pintado antes.
    builder: (context, child) => Column(
      verticalDirection: VerticalDirection.up,
      children: [
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child!,
          ),
        ),
        ConnectivityIndicator(
          connectivity: dependencies.connectivity,
          syncActivity: dependencies.syncActivity,
          catalog: dependencies.catalog,
        ),
      ],
    ),
    home: AppShell(dependencies: dependencies),
  );
}
