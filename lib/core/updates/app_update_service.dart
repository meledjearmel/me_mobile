import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../api/api_exception.dart';
import 'app_release.dart';
import 'app_update_repository.dart';

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) => AppUpdateService(ref));

/// Mise à jour hors store (Android seulement) : compare le build installé à la
/// dernière version publiée sur le portfolio, propose la mise à jour, télécharge
/// l'APK, vérifie son SHA-256 puis ouvre l'installeur système.
///
/// L'APK doit être signé avec la même clé de release que l'app installée,
/// sinon Android refuse de l'installer par-dessus.
class AppUpdateService {
  AppUpdateService(this._ref);

  /// Délai minimal entre deux vérifications (retours au premier plan).
  static const checkInterval = Duration(hours: 6);

  final Ref _ref;
  DateTime? _lastCheck;
  bool _busy = false;

  /// [contextOf] est relu après chaque attente : la route a pu changer.
  /// [force] ignore le délai de [checkInterval] (démarrage, connexion).
  Future<void> checkForUpdate(BuildContext? Function() contextOf, {bool force = false}) async {
    if (kIsWeb || !Platform.isAndroid || _busy) {
      return;
    }
    final now = DateTime.now();
    if (!force && _lastCheck != null && now.difference(_lastCheck!) < checkInterval) {
      return;
    }
    _busy = true;
    _lastCheck = now;
    try {
      final release = await _ref.read(appUpdateRepositoryProvider).latest();
      if (release == null) {
        return;
      }
      final info = await PackageInfo.fromPlatform();
      if (!release.isNewerThan(parseBuildNumber(info.buildNumber))) {
        return;
      }
      final context = contextOf();
      if (context == null || !context.mounted) {
        return;
      }
      final accepted = await _askToUpdate(context, release);
      if (accepted ?? false) {
        await _downloadAndInstall(contextOf, release);
      }
    } on ApiException {
      // Hors ligne ou serveur indisponible : on réessaiera au prochain retour.
      _lastCheck = null;
    } finally {
      _busy = false;
    }
  }

  Future<bool?> _askToUpdate(BuildContext context, AppRelease release) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Version ${release.versionName} disponible'),
      content: SingleChildScrollView(
        child: Text(release.notes.trim().isEmpty ? 'Une nouvelle version de Me Admin est prête.' : release.notes.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Plus tard')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Mettre à jour')),
      ],
    ),
  );

  Future<void> _downloadAndInstall(BuildContext? Function() contextOf, AppRelease release) async {
    final context = contextOf();
    if (context == null || !context.mounted) {
      return;
    }
    final progress = ValueNotifier<double?>(null);
    final cancel = CancelToken();
    final file = File('${(await getTemporaryDirectory()).path}/me-admin-${release.buildNumber}.apk');

    if (!context.mounted) {
      return;
    }
    final dialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DownloadDialog(progress: progress, onCancel: () => cancel.cancel()),
    );

    String? error;
    try {
      // Client séparé : l'URL est signée, sans jeton ni URL de base de l'API.
      await Dio().download(
        release.downloadUrl,
        file.path,
        cancelToken: cancel,
        onReceiveProgress: (received, total) {
          final expected = total > 0 ? total : release.size;
          progress.value = expected > 0 ? received / expected : null;
        },
      );
      if (!await fileMatchesSha256(file, release.sha256)) {
        error = 'Le fichier téléchargé est corrompu ou a été modifié (empreinte SHA-256 différente). Réessayez plus tard.';
      }
    } on DioException catch (e) {
      if (!CancelToken.isCancel(e)) {
        error = 'Le téléchargement a échoué. Vérifiez votre connexion et réessayez.';
      }
    }

    final dialogContext = contextOf();
    if (dialogContext != null && dialogContext.mounted) {
      Navigator.of(dialogContext, rootNavigator: true).pop();
    }
    await dialog;
    progress.dispose();

    if (cancel.isCancelled || error != null) {
      if (await file.exists()) {
        await file.delete();
      }
      final errorContext = contextOf();
      if (error != null && errorContext != null && errorContext.mounted) {
        await _showError(errorContext, error);
      }
      return;
    }

    final result = await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
    final resultContext = contextOf();
    if (result.type != ResultType.done && resultContext != null && resultContext.mounted) {
      await _showError(
        resultContext,
        'Impossible d\'ouvrir l\'installeur. Autorisez Me Admin à installer des applications inconnues dans les réglages Android, puis réessayez.',
      );
    }
  }

  Future<void> _showError(BuildContext context, String message) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Mise à jour impossible'),
      content: Text(message),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
    ),
  );
}

class _DownloadDialog extends StatelessWidget {
  const _DownloadDialog({required this.progress, required this.onCancel});

  final ValueNotifier<double?> progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AlertDialog(
      title: const Text('Téléchargement…'),
      content: ValueListenableBuilder<double?>(
        valueListenable: progress,
        builder: (context, value, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: value),
            const SizedBox(height: 12),
            Text(value == null ? 'Préparation…' : '${(value * 100).clamp(0, 100).round()} %'),
          ],
        ),
      ),
      actions: [TextButton(onPressed: onCancel, child: const Text('Annuler'))],
    ),
  );
}
