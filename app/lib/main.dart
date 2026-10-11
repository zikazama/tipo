import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'presentation/routing/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: TipoApp()));
}

class TipoApp extends StatelessWidget {
  const TipoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TIPO — Read the signs. Act first.',
      debugShowCheckedModeBanner: false,
      theme: citizenTheme(),
      darkTheme: citizenDarkTheme(),
      themeMode: ThemeMode.system,
      routerConfig: createRouter(),
    );
  }
}
