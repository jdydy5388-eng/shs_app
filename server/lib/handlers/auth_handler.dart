import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';
import '../database/database_service.dart';
import '../utils/response_helper.dart';
import '../logger/app_logger.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class AuthHandler {
  Router get router {
    final router = Router();

    router.post('/register', _register);
    router.post('/login', _login);
    router.post('/logout', _logout);

    return router;
  }

  Future<Response> _register(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      
      final id = body['id'] as String;
      final name = body['name'] as String;
      final email = body['email'] as String;
      final phone = body['phone'] as String;
      final role = body['role'] as String;
      final password = body['password'] as String;
      final additionalInfo = body['additionalInfo'] as Map<String, dynamic>?;

      // Hash password
      final passwordHash = _hashPassword(password);

      final conn = await DatabaseService().connection;
      
      await conn.execute(
        '''
        INSERT INTO users (id, name, email, phone, role, additional_info, created_at, password_hash)
        VALUES (@id, @name, @email, @phone, @role, @additionalInfo, @createdAt, @passwordHash)
        ON CONFLICT (email) DO NOTHING
        ''',
        substitutionValues: {
          'id': id,
          'name': name,
          'email': email,
          'phone': phone,
          'role': role,
          'additionalInfo': jsonEncode(additionalInfo ?? {}),
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'passwordHash': passwordHash,
        },
      );

      return ResponseHelper.success(data: {'message': 'User registered successfully'});
    } catch (e) {
      AppLogger.error('Registration error', e);
      return ResponseHelper.error(message: 'Registration failed: $e');
    }
  }

  Future<Response> _login(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final email = body['email'] as String;
      final password = body['password'] as String;

      final conn = await DatabaseService().connection;
      final passwordHash = _hashPassword(password);

      final result = await conn.query(
        '''
        SELECT id, name, email, phone, role, profile_image_url, additional_info, created_at, last_login_at
        FROM users
        WHERE email = @email AND password_hash = @passwordHash
        ''',
        substitutionValues: {
          'email': email,
          'passwordHash': passwordHash,
        },
      );

      if (result.isEmpty) {
        return ResponseHelper.error(
          message: 'Invalid email or password',
          statusCode: 401,
        );
      }

      final user = result.first;
      
      // Update last login
      await conn.execute(
        '''
        UPDATE users SET last_login_at = @lastLoginAt WHERE id = @id
        ''',
        substitutionValues: {
          'id': user[0],
          'lastLoginAt': DateTime.now().millisecondsSinceEpoch,
        },
      );

      // معالجة additionalInfo - قد يكون String (JSON) أو Map مباشرة من JSONB
      dynamic additionalInfo = user[6];
      if (additionalInfo != null) {
        if (additionalInfo is String) {
          try {
            additionalInfo = jsonDecode(additionalInfo);
          } catch (e) {
            additionalInfo = null;
          }
        } else if (additionalInfo is Map) {
          // بالفعل Map - لا حاجة لتحويل
          additionalInfo = additionalInfo;
        } else {
          additionalInfo = null;
        }
      }
      
      return ResponseHelper.success(data: {
        'user': {
          'id': user[0],
          'name': user[1],
          'email': user[2],
          'phone': user[3],
          'role': user[4],
          'profileImageUrl': user[5],
          'additionalInfo': additionalInfo,
          'createdAt': user[7],
          'lastLoginAt': user[8],
        },
      });
    } catch (e) {
      AppLogger.error('Login error', e);
      return ResponseHelper.error(message: 'Login failed: $e');
    }
  }

  Future<Response> _logout(Request request) async {
    // يمكن إضافة منطق تسجيل الخروج هنا
    return ResponseHelper.success(data: {'message': 'Logged out successfully'});
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }
}

