library local_auth_windows;

import 'package:flutter/foundation.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';

import 'types/auth_messages_windows.dart';

export 'package:local_auth_platform_interface/types/auth_messages.dart';
export 'package:local_auth_platform_interface/types/auth_options.dart';
export 'package:local_auth_platform_interface/types/biometric_type.dart';
export 'types/auth_messages_windows.dart';

/// Stub implementation of [LocalAuthPlatform] for Windows that always reports
/// that biometric features are unavailable.
class LocalAuthWindows extends LocalAuthPlatform {
  /// Registers this stub with the platform interface.
  static void registerWith() {
    LocalAuthPlatform.instance = LocalAuthWindows();
  }

  @visibleForTesting
  LocalAuthWindows();

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    return false;
  }

  @override
  Future<bool> deviceSupportsBiometrics() async => false;

  @override
  Future<List<BiometricType>> getEnrolledBiometrics() async => <BiometricType>[];

  @override
  Future<bool> isDeviceSupported() async => false;

  @override
  Future<bool> stopAuthentication() async => false;
}

