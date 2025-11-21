// Stub implementation for Windows
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

