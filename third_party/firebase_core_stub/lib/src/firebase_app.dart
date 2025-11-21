// Stub implementation for Windows
// هذا الملف يستخدم فقط على Windows لتجنب أخطاء الربط C++
import 'dart:io' show Platform;

class Firebase {
  static Future<void> initializeApp({required dynamic options}) async {
    // على Windows، لا نفعل شيئاً
    // على Android/iOS/Web، سيتم استخدام Firebase الحقيقي
    if (Platform.isWindows) {
      return;
    }
    // إذا لم يكن Windows، يجب أن يتم استخدام Firebase الحقيقي
    // لكن هذا لن يحدث لأن stub package يستخدم فقط على Windows
    throw UnsupportedError('Firebase stub should only be used on Windows');
  }
}

class FirebaseOptions {
  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
  final String? authDomain;
  final String? storageBucket;
  final String? iosBundleId;
  
  const FirebaseOptions({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
    this.authDomain,
    this.storageBucket,
    this.iosBundleId,
  });
}

