import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Handler appelé dans un isolate séparé quand un message arrive alors que
/// l'app est en arrière-plan ou fermée. Il ne fait rien de plus : c'est FCM
/// qui affiche la notification système, via le canal par défaut déclaré dans
/// `AndroidManifest.xml`. Ce point d'entrée existe uniquement pour que le
/// plugin ne signale pas d'avertissement au démarrage.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } on Object {
    // google-services.json absent : rien à faire, l'app fonctionne sans push.
  }
}
