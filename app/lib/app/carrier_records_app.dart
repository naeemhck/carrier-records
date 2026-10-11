import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'strings.dart';

final _router = GoRouter(
  routes: [GoRoute(path: '/', builder: (context, state) => const _SetupPage())],
);

class CarrierRecordsApp extends StatelessWidget {
  const CarrierRecordsApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: AppStrings.title,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00695C)),
      scaffoldBackgroundColor: const Color(0xFFF5F7F8),
      useMaterial3: true,
    ),
    routerConfig: _router,
  );
}

class _SetupPage extends StatelessWidget {
  const _SetupPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(AppStrings.title)),
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(AppStrings.setupPending, textAlign: TextAlign.center),
      ),
    ),
  );
}
