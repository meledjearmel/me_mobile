import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/push/push_service.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class MeAdminApp extends ConsumerStatefulWidget {
  const MeAdminApp({super.key});

  @override
  ConsumerState<MeAdminApp> createState() => _MeAdminAppState();
}

class _MeAdminAppState extends ConsumerState<MeAdminApp> {
  @override
  void initState() {
    super.initState();
    // Écoute les messages et les taps sur notification dès le lancement,
    // avant même une éventuelle connexion (message reçu app fermée).
    ref.read(pushServiceProvider).init();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Me Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
