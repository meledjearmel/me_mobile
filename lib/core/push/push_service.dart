import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../features/auth/application/session_controller.dart';
import '../../features/dashboard/data/dashboard_repository.dart';
import '../api/api_exception.dart';
import 'push_background_handler.dart';
import 'push_notification_channel.dart';
import 'push_target.dart';
import 'push_token_repository.dart';

final pushServiceProvider = Provider<PushService>((ref) => PushService(ref));

/// Notifications push : jeton FCM, réception au premier plan (affichage
/// manuel via `flutter_local_notifications`) et en arrière-plan (affichage
/// automatique par FCM pour les messages avec un bloc `notification`,
/// affichage manuel dans [firebaseMessagingBackgroundHandler] sinon), et
/// ouverture du bon onglet au tap (§4.6).
///
/// Se met en veille silencieusement si Firebase n'est pas configuré
/// (`google-services.json` absent) : le reste de l'app continue de fonctionner.
class PushService {
  PushService(this._ref);

  final Ref _ref;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get _firebaseReady => Firebase.apps.isNotEmpty;

  /// À appeler une fois au démarrage de l'app, avant toute connexion.
  Future<void> init() async {
    if (_initialized || !_firebaseReady) {
      return;
    }
    _initialized = true;

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(pushNotificationChannel);
    await _localNotifications.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('ic_launcher_monochrome')),
      onDidReceiveNotificationResponse: (response) => _handlePayload(response.payload),
    );

    FirebaseMessaging.onMessage.listen(_showForeground);
    FirebaseMessaging.onMessageOpenedApp.listen((message) => _handleTap(message.data));
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // App lancée depuis fermée en tapant sur une notification affichée par FCM
    // (message avec bloc `notification`).
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _handleTap(initial.data);
    }

    // App lancée depuis fermée en tapant sur une notification affichée
    // manuellement (message « data-only », voir [firebaseMessagingBackgroundHandler]).
    final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _handlePayload(launchDetails!.notificationResponse?.payload);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      if (_ref.read(sessionProvider).value != null) {
        _register(token);
      }
    });
  }

  /// À appeler après une connexion réussie et à chaque démarrage tant que la
  /// session est ouverte : le jeton FCM a pu changer.
  ///
  /// [context] permet une courte explication avant la demande système, la
  /// première fois seulement (§5 : « pas au premier lancement à froid »).
  Future<void> registerForCurrentSession([BuildContext? context]) async {
    if (!_firebaseReady) {
      return;
    }

    final current = await FirebaseMessaging.instance.getNotificationSettings();
    if (current.authorizationStatus == AuthorizationStatus.notDetermined && context != null && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Recevoir des notifications'),
          content: const Text(
            'Me Admin peut vous prévenir dès qu\'un nouveau message, une demande de '
            'collaboration, un avis ou des félicitations arrivent sur votre portfolio.',
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Continuer'))],
        ),
      );
    }

    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _register(token);
    }
  }

  /// À appeler à la déconnexion, avant de révoquer le jeton d'API.
  Future<void> unregisterCurrentDevice() async {
    if (!_firebaseReady) {
      return;
    }
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) {
      return;
    }
    try {
      await _ref.read(pushTokenRepositoryProvider).unregister(token);
    } on ApiException {
      // Hors ligne ou jeton déjà oublié côté serveur : sans conséquence.
    }
  }

  Future<void> _register(String token) async {
    try {
      await _ref.read(pushTokenRepositoryProvider).register(token);
    } on ApiException {
      // Sera retenté au prochain démarrage ou au prochain rafraîchissement du jeton.
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    // Le compteur « à traiter » vient de bouger côté serveur (§5 : rafraîchir
    // le tableau de bord à la réception d'une notification push).
    _ref.invalidate(dashboardProvider);

    // Certains push sont « data-only » (pas de bloc `notification` : c'est au
    // client de l'afficher). On retombe alors sur un titre générique selon le
    // type visé, sinon rien ne s'affiche jamais en premier plan (§4.6).
    final notification = message.notification;
    final target = PushTarget.fromData(message.data);
    final title = notification?.title ?? target?.type.notificationTitle;
    if (title == null) {
      return;
    }
    await _localNotifications.show(
      message.hashCode,
      title,
      notification?.body,
      buildPushNotificationDetails(),
      payload: jsonEncode(message.data),
    );
  }

  void _handlePayload(String? payload) {
    if (payload == null) {
      return;
    }
    _handleTap(jsonDecode(payload) as Map<String, dynamic>);
  }

  /// Ouvre directement le détail de l'élément visé dans la boîte de réception,
  /// ou l'historique des félicitations depuis l'accueil.
  void _handleTap(Map<String, dynamic> data) {
    final target = PushTarget.fromData(data);
    if (target == null) {
      return;
    }
    _ref.read(pendingPushTargetProvider.notifier).state = target;
    _ref.read(routerProvider).go(target.type.location);
  }
}
