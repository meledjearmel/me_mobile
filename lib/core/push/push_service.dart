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
import 'push_target.dart';
import 'push_token_repository.dart';

final pushServiceProvider = Provider<PushService>((ref) => PushService(ref));

/// Notifications push : jeton FCM, réception au premier plan (affichage
/// manuel via `flutter_local_notifications`) et en arrière-plan (affichage
/// automatique par FCM), et ouverture du bon onglet au tap (§4.6).
///
/// Se met en veille silencieusement si Firebase n'est pas configuré
/// (`google-services.json` absent) : le reste de l'app continue de fonctionner.
class PushService {
  PushService(this._ref);

  static const _channel = AndroidNotificationChannel(
    'me_admin_todo',
    'À traiter',
    description: 'Nouveaux messages, demandes de collaboration et avis déposés.',
    importance: Importance.high,
  );

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
        ?.createNotificationChannel(_channel);
    await _localNotifications.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('ic_launcher_monochrome')),
      onDidReceiveNotificationResponse: (response) => _handlePayload(response.payload),
    );

    FirebaseMessaging.onMessage.listen(_showForeground);
    FirebaseMessaging.onMessageOpenedApp.listen((message) => _handleTap(message.data));
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // App lancée depuis fermée en tapant sur la notification.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _handleTap(initial.data);
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
            'collaboration ou un avis arrive sur votre portfolio.',
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

    final notification = message.notification;
    if (notification == null) {
      return;
    }
    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handlePayload(String? payload) {
    if (payload == null) {
      return;
    }
    _handleTap(jsonDecode(payload) as Map<String, dynamic>);
  }

  /// Ouvre directement le détail de l'élément visé dans la boîte de réception.
  void _handleTap(Map<String, dynamic> data) {
    final target = PushTarget.fromData(data);
    if (target == null) {
      return;
    }
    _ref.read(pendingPushTargetProvider.notifier).state = target;
    _ref.read(routerProvider).go('/inbox');
  }
}
