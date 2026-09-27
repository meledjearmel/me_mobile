import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Nom de l'appareil envoyé à la connexion (`device_name`), pour reconnaître
/// le jeton dans la liste des sessions côté web. Ex. « Samsung SM-S918B ».
final deviceNameProvider = FutureProvider<String>((ref) async {
  try {
    final info = await DeviceInfoPlugin().androidInfo;
    final brand = info.manufacturer.isEmpty
        ? ''
        : '${info.manufacturer[0].toUpperCase()}${info.manufacturer.substring(1)} ';
    return 'Me Admin · $brand${info.model}'.trim();
  } on Object {
    return 'Me Admin · Android';
  }
});
