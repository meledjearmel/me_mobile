import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/biometrics/biometric_lock_controller.dart';
import '../core/push/push_service.dart';
import '../features/auth/application/session_controller.dart';
import '../features/dashboard/data/dashboard_repository.dart';
import 'router.dart';
import 'theme/app_palette_variant.dart';
import 'theme/app_theme.dart';
import 'theme/theme_preferences.dart';

class MeAdminApp extends ConsumerStatefulWidget {
  const MeAdminApp({super.key});

  @override
  ConsumerState<MeAdminApp> createState() => _MeAdminAppState();
}

class _MeAdminAppState extends ConsumerState<MeAdminApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Écoute les messages et les taps sur notification dès le lancement,
    // avant même une éventuelle connexion (message reçu app fermée).
    ref.read(pushServiceProvider).init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Verrouille dès le passage en arrière-plan (pas seulement au retour) :
    // l'aperçu du multitâche ne doit pas montrer le contenu de l'app.
    if (state == AppLifecycleState.paused) {
      ref.read(biometricLockControllerProvider.notifier).lockIfEnabled();
    }
    // Retour au premier plan : les compteurs ont pu bouger pendant l'absence (§5).
    if (state == AppLifecycleState.resumed && ref.read(sessionProvider).value != null) {
      ref.invalidate(dashboardProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Suit le réglage système par défaut ; l'utilisateur peut le forcer en
    // clair ou sombre depuis Compte > Apparence (voir account_screen.dart).
    final themeMode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    // Palette choisie dans Compte > Apparence, déclinée en clair et en sombre.
    final palette = ref.watch(paletteProvider).value ?? AppPaletteVariant.fallback;

    return MaterialApp.router(
      title: 'Me Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(palette, Brightness.light),
      darkTheme: AppTheme.build(palette, Brightness.dark),
      themeMode: themeMode,
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
