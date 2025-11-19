import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// خدمة التشفير للبيانات الحساسة
class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  encrypt.Encrypter? _encrypter;
  encrypt.IV? _iv;

  /// تهيئة خدمة التشفير
  Future<void> initialize() async {
    try {
      // الحصول على أو إنشاء مفتاح التشفير
      String? keyString = await _secureStorage.read(key: 'encryption_key');
      
      if (keyString == null) {
        // إنشاء مفتاح جديد
        final key = encrypt.Key.fromSecureRandom(32);
        keyString = key.base64;
        await _secureStorage.write(key: 'encryption_key', value: keyString);
      }

      final key = encrypt.Key.fromBase64(keyString);
      _encrypter = encrypt.Encrypter(encrypt.AES(key));

      // الحصول على أو إنشاء IV
      String? ivString = await _secureStorage.read(key: 'encryption_iv');
      
      if (ivString == null) {
        // إنشاء IV جديد
        _iv = encrypt.IV.fromSecureRandom(16);
        await _secureStorage.write(key: 'encryption_iv', value: _iv!.base64);
      } else {
        _iv = encrypt.IV.fromBase64(ivString);
      }
    } catch (e) {
      // في حالة الفشل، استخدام مفتاح افتراضي (للتطوير فقط)
      final key = encrypt.Key.fromLength(32);
      _encrypter = encrypt.Encrypter(encrypt.AES(key));
      _iv = encrypt.IV.fromLength(16);
    }
  }

  /// تشفير نص
  String encryptText(String plainText) {
    if (_encrypter == null || _iv == null) {
      throw Exception('Encryption service not initialized');
    }
    final encrypted = _encrypter!.encrypt(plainText, iv: _iv!);
    return encrypted.base64;
  }

  /// فك تشفير نص
  String decryptText(String encryptedText) {
    if (_encrypter == null || _iv == null) {
      throw Exception('Encryption service not initialized');
    }
    final encrypted = encrypt.Encrypted.fromBase64(encryptedText);
    return _encrypter!.decrypt(encrypted, iv: _iv!);
  }

  /// تشفير خريطة بيانات
  Map<String, dynamic> encryptMap(Map<String, dynamic> data) {
    final jsonString = jsonEncode(data);
    final encrypted = encryptText(jsonString);
    return {'encrypted': encrypted};
  }

  /// فك تشفير خريطة بيانات
  Map<String, dynamic> decryptMap(Map<String, dynamic> encryptedData) {
    final encrypted = encryptedData['encrypted'] as String;
    final decrypted = decryptText(encrypted);
    return jsonDecode(decrypted) as Map<String, dynamic>;
  }

  /// إنشاء hash للبيانات (للمقارنة فقط، لا يمكن فك التشفير)
  String hashData(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// التحقق من hash
  bool verifyHash(String data, String hash) {
    return hashData(data) == hash;
  }

  /// تشفير كلمة المرور (bcrypt-like)
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    // إضافة salt بسيط
    final salt = 'shs_salt_2024';
    final salted = utf8.encode('$digest$salt');
    final finalHash = sha256.convert(salted);
    return finalHash.toString();
  }

  /// التحقق من كلمة المرور
  bool verifyPassword(String password, String hashedPassword) {
    return hashPassword(password) == hashedPassword;
  }
}

