// Stub file for Windows builds to avoid Firebase imports
// This file is used when building for Windows platform

class DefaultFirebaseOptions {
  static dynamic get currentPlatform {
    throw UnsupportedError('Firebase is not supported on Windows');
  }
}

