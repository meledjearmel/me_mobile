import 'package:me_mobile/core/biometrics/biometric_authenticator.dart';
import 'package:me_mobile/core/biometrics/biometric_preferences.dart';

class FakeBiometricPreferences implements BiometricPreferences {
  bool _enabled = false;

  @override
  Future<bool> isEnabled() async => _enabled;

  @override
  Future<void> setEnabled(bool value) async => _enabled = value;
}

class FakeBiometricAuthenticator implements BiometricAuthenticator {
  FakeBiometricAuthenticator({this.supported = true, this.succeeds = true});

  bool supported;
  bool succeeds;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<bool> authenticate(String reason) async => succeeds;
}
