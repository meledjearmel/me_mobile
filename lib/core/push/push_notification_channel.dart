import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Canal Android partagé entre l'avant-plan ([PushService], isolate
/// principal) et l'arrière-plan (isolate séparé, voir
/// `push_background_handler.dart`) : les deux doivent utiliser le même id
/// que celui déclaré dans `AndroidManifest.xml`
/// (`com.google.firebase.messaging.default_notification_channel_id`).
const pushNotificationChannel = AndroidNotificationChannel(
  'me_admin_todo',
  'À traiter',
  description: 'Nouveaux messages, demandes de collaboration et avis déposés.',
  importance: Importance.high,
);

NotificationDetails buildPushNotificationDetails() => NotificationDetails(
      android: AndroidNotificationDetails(
        pushNotificationChannel.id,
        pushNotificationChannel.name,
        channelDescription: pushNotificationChannel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
