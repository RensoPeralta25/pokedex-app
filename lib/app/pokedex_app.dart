import 'package:flutter/material.dart';

import 'app_dependencies.dart';
import 'app_shell.dart';

class PokedexApp extends StatelessWidget {
  const PokedexApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Pokédex',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.red, useMaterial3: true),
    home: AppShell(dependencies: dependencies),
  );
}
