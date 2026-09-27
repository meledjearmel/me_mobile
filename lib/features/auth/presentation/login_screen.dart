import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/feedback.dart';
import '../application/session_controller.dart';
import '../data/auth_repository.dart';
import 'auth_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.notice});

  /// Message à afficher à l'arrivée, par ex. « Ce défi a expiré, reconnectez-vous. ».
  final String? notice;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _obscure = true;
  bool _submitting = false;
  ValidationException? _validation;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.notice;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() {
        _error = 'Renseignez votre adresse e-mail et votre mot de passe.';
        _validation = null;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
      _validation = null;
    });

    try {
      final result = await ref.read(sessionProvider.notifier).login(email: _email.text, password: _password.text);
      if (!mounted) {
        return;
      }
      if (result is TwoFactorRequired) {
        _password.clear();
        await context.push('/login/two-factor', extra: result.challenge);
      }
      // LoginSucceeded : le routeur redirige vers l'accueil.
    } on ValidationException catch (e) {
      setState(() => _validation = e);
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
    return AuthScaffold(
      title: 'Bon retour',
      subtitle: 'Connectez-vous pour gérer votre portfolio.',
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
            TextField(
              controller: _email,
              enabled: !_submitting,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              autofillHints: const [AutofillHints.email, AutofillHints.username],
              onSubmitted: (_) => _passwordFocus.requestFocus(),
              decoration: InputDecoration(
                labelText: 'Adresse e-mail',
                prefixIcon: const Icon(Icons.alternate_email_rounded),
                errorText: _validation?.errorFor('email'),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              focusNode: _passwordFocus,
              enabled: !_submitting,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                errorText: _validation?.errorFor('password'),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Se connecter'),
            ),
            const SizedBox(height: 20),
            Text(
              'Mot de passe, double authentification et passkeys se gèrent depuis le back-office web.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Code TOTP : chiffres uniquement, 6 au maximum.
final totpInputFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(6),
];
