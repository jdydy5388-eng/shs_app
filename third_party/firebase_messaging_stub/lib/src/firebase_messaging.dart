// Stub implementation for Windows
import 'remote_message.dart';

class FirebaseMessaging {
  static FirebaseMessaging get instance {
    throw UnsupportedError('Firebase Messaging is not supported on Windows');
  }
  
  Future<String?> getToken() {
    throw UnsupportedError('Firebase Messaging is not supported on Windows');
  }
  
  Stream<String> get onTokenRefresh {
    throw UnsupportedError('Firebase Messaging is not supported on Windows');
  }
  
  static Stream<RemoteMessage> get onMessage {
    throw UnsupportedError('Firebase Messaging is not supported on Windows');
  }
  
  static Stream<RemoteMessage> get onMessageOpenedApp {
    throw UnsupportedError('Firebase Messaging is not supported on Windows');
  }
  
  Future<RemoteMessage?> getInitialMessage() {
    throw UnsupportedError('Firebase Messaging is not supported on Windows');
  }
  
  Future<NotificationSettings> requestPermission({
    bool? alert,
    bool? badge,
    bool? sound,
    bool? provisional,
  }) {
    throw UnsupportedError('Firebase Messaging is not supported on Windows');
  }
}

class NotificationSettings {
  final AuthorizationStatus authorizationStatus;
  
  NotificationSettings({required this.authorizationStatus});
}

enum AuthorizationStatus {
  notDetermined,
  denied,
  authorized,
  provisional,
}

