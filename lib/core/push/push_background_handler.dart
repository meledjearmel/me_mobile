import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'push_notification_channel.dart';
import 'push_target.dart';

/// Handler appelé dans un isolate séparé quand un message arrive alors que
/// l'app est en arrière-plan ou fermée.
///
/// Si le message a un bloc `notification`, FCM l'affiche déjà tout seul via
/// le canal par défaut déclaré dans `AndroidManifest.xml` : on ne fait rien
/// de plus (sous peine de l'afficher deux fois). Si le message est
/// « data-only » (juste `data: { type, id }`, sans bloc `notification`),
/// rien n'est jamais affiché automatiquement : c'est à nous de le faire ici,
/// sinon les trois types de push (message, collaboration, avis) restent
/// invisibles tant que l'app n'est pas rouverte (§4.6).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } on Object {
    // google-services.json absent : rien à faire, l'app fonctionne sans push.
    return;
  }

  if (message.notification != null) {
    return;
  }

  final target = PushTarget.fromData(message.data);
  if (target == null) {
    return;
  }

  final localNotifications = FlutterLocalNotificationsPlugin();
  await localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(pushNotificationChannel);
  await localNotifications.initialize(
    const InitializationSettings(android: AndroidInitializationSettings('ic_launcher_monochrome')),
  );
  await localNotifications.show(
    message.hashCode,
    target.type.notificationTitle,
    null,
    buildPushNotificationDetails(),
    payload: jsonEncode(message.data),
  );
}
