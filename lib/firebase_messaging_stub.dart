// Stub file for Windows builds to avoid Firebase Messaging imports
// This file is used when building for Windows platform

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
  
  Stream<RemoteMessage> get onMessage {
    throw UnsupportedError('Firebase Messaging is not supported on Windows');
  }
  
  Stream<RemoteMessage> get onMessageOpenedApp {
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

class RemoteMessage {
  final RemoteNotification? notification;
  final Map<String, dynamic> data;
  
  RemoteMessage({this.notification, this.data = const {}});
}

class RemoteNotification {
  final String? title;
  final String? body;
  
  RemoteNotification({this.title, this.body});
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

