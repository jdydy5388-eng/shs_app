import 'package:flutter/foundation.dart';
import 'package:local_auth_platform_interface/types/auth_messages.dart';

/// Windows-specific authentication messages (unused in the stub).
@immutable
class WindowsAuthMessages extends AuthMessages {
  /// Creates an instance of [WindowsAuthMessages].
  const WindowsAuthMessages();

  @override
  Map<String, String> get args => <String, String>{};
}

