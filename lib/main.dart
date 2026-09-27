import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/push/push_background_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } on Object catch (error) {
    // google-services.json absent ou projet Firebase mal configuré : l'app
    // continue sans notifications plutôt que de planter au démarrage.
    debugPrint('Firebase indisponible, notifications désactivées : $error');
  }

  runApp(const ProviderScope(child: MeAdminApp()));
}
