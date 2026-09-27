import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_palette.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/feedback.dart';
import '../application/session_controller.dart';
import 'auth_scaffold.dart';
import 'login_screen.dart';

/// Deuxième étape de connexion : code de l'application ou code de secours.
///
/// Le défi expire 5 minutes après la saisie du mot de passe : un compte à rebours
/// l'indique, et un défi expiré renvoie à l'écran de connexion. Un code invalide
/// laisse le défi valable : on reste ici.
class TwoFactorScreen extends ConsumerStatefulWidget {
  const TwoFactorScreen({super.key, required this.challenge});

  static const challengeTtl = Duration(minutes: 5);
  static const expiredMessage = 'Ce défi a expiré, reconnectez-vous.';

  final String challenge;

  @override
  ConsumerState<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends ConsumerState<TwoFactorScreen> {
  final _code = TextEditingController();
  late final DateTime _expiresAt = DateTime.now().add(TwoFactorScreen.challengeTtl);
  late final Timer _ticker;

  bool _useRecovery = false;
  bool _submitting = false;
  String? _fieldError;
  String? _error;

  Duration get _remaining {
    final left = _expiresAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining == Duration.zero) {
        _backToLogin(TwoFactorScreen.expiredMessage);
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    _code.dispose();
    super.dispose();
  }

  void _backToLogin(String message) {
    _ticker.cancel();
    if (mounted) {
      context.go('/login', extra: message);
    }
  }

  void _toggleMode() {
    setState(() {
      _useRecovery = !_useRecovery;
      _code.clear();
      _fieldError = null;
    });
  }

  Future<void> _submit() async {
    final value = _code.text.trim();
    if (_submitting) {
      return;
    }
    if (value.isEmpty || (!_useRecovery && value.length != 6)) {
      setState(() => _fieldError = _useRecovery ? 'Saisissez un code de secours.' : 'Le code comporte 6 chiffres.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _fieldError = null;
      _error = null;
    });

    try {
      await ref.read(sessionProvider.notifier).confirmTwoFactor(
            challenge: widget.challenge,
            code: _useRecovery ? null : value,
            recoveryCode: _useRecovery ? value : null,
          );
      _ticker.cancel();
      // Session ouverte : le routeur redirige vers l'accueil.
    } on ValidationException catch (e) {
      final expired = e.errorFor('challenge');
      if (expired != null) {
        _backToLogin(expired);
        return;
      }
      setState(() => _fieldError = e.errorFor('code') ?? e.errorFor('recovery_code') ?? e.message);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = _remaining;
    final countdown = '${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';

    return AuthScaffold(
      title: 'Vérification',
      subtitle: _useRecovery
          ? 'Saisissez l\'un de vos codes de secours. Chaque code ne sert qu\'une fois.'
          : 'Saisissez le code à 6 chiffres de votre application d\'authentification.',
      leading: Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          tooltip: 'Retour à la connexion',
          color: context.appColors.onHero,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/login'),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
          TextField(
            key: ValueKey(_useRecovery),
            controller: _code,
            enabled: !_submitting,
            autofocus: true,
            keyboardType: _useRecovery ? TextInputType.text : TextInputType.number,
            inputFormatters: _useRecovery ? null : totpInputFormatters,
            autofillHints: _useRecovery ? null : const [AutofillHints.oneTimeCode],
            autocorrect: false,
            textAlign: _useRecovery ? TextAlign.start : TextAlign.center,
            style: _useRecovery
                ? null
                : AppTheme.fontMono.copyWith(
                    fontSize: theme.textTheme.headlineSmall?.fontSize,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: 8,
                  ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: _useRecovery ? 'Code de secours' : 'Code de vérification',
              errorText: _fieldError,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Ce défi expire dans $countdown',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('Valider'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _submitting ? null : _toggleMode,
            child: Text(_useRecovery ? 'Utiliser le code de l\'application' : 'Utiliser un code de secours'),
          ),
        ],
      ),
    );
  }
}
