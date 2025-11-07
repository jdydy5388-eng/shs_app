import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';
import '../database/database_service.dart';
import '../utils/response_helper.dart';
import '../logger/app_logger.dart';

class UsersHandler {
  Router get router {
    final router = Router();

    // Route للجذر - الحصول على جميع المستخدمين (مع query parameter للـ role)
    router.get('/', _getUsers);
    // Route للحصول على المرضى فقط
    router.get('/patients', _getPatients);
    // Route للحصول على مستخدم محدد
    router.get('/<userId>', _getUser);
    router.put('/<userId>', _updateUser);
    router.delete('/<userId>', _deleteUser);

    return router;
  }

  Future<Response> _getUsers(Request request) async {
    try {
      final params = request.url.queryParameters;
      final role = params['role'];
      
      final conn = await DatabaseService().connection;
      
      String query = '''
        SELECT id, name, email, phone, role, profile_image_url, additional_info, 
               created_at, last_login_at
        FROM users
      ''';
      
      if (role != null && role.isNotEmpty) {
        query += ' WHERE role = @role';
      }
      
      query += ' ORDER BY created_at DESC';

      final result = await conn.query(
        query,
        substitutionValues: role != null && role.isNotEmpty ? {'role': role} : null,
      );

      final users = result.map((row) {
        // معالجة additionalInfo - قد يكون String (JSON) أو Map مباشرة من JSONB
        dynamic additionalInfo = row[6];
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
        
        return {
          'id': row[0],
          'name': row[1],
          'email': row[2],
          'phone': row[3],
          'role': row[4],
          'profileImageUrl': row[5],
          'additionalInfo': additionalInfo,
          'createdAt': row[7],
          'lastLoginAt': row[8],
        };
      }).toList();

      return ResponseHelper.list(data: users);
    } catch (e) {
      AppLogger.error('Get users error', e);
      return ResponseHelper.error(message: 'Failed to get users: $e');
    }
  }

  Future<Response> _getPatients(Request request) async {
    // استدعاء _getUsers مباشرة مع role=patient
    return _getUsersWithRole(request, 'patient');
  }
  
  Future<Response> _getUsersWithRole(Request request, String role) async {
    try {
      final conn = await DatabaseService().connection;
      
      String query = '''
        SELECT id, name, email, phone, role, profile_image_url, additional_info, 
               created_at, last_login_at
        FROM users
        WHERE role = @role
        ORDER BY created_at DESC
      ''';

      final result = await conn.query(
        query,
        substitutionValues: {'role': role},
      );

      final users = result.map((row) {
        // معالجة additionalInfo - قد يكون String (JSON) أو Map مباشرة من JSONB
        dynamic additionalInfo = row[6];
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
        
        return {
          'id': row[0],
          'name': row[1],
          'email': row[2],
          'phone': row[3],
          'role': row[4],
          'profileImageUrl': row[5],
          'additionalInfo': additionalInfo,
          'createdAt': row[7],
          'lastLoginAt': row[8],
        };
      }).toList();

      return ResponseHelper.list(data: users);
    } catch (e) {
      AppLogger.error('Get patients error', e);
      return ResponseHelper.error(message: 'Failed to get patients: $e');
    }
  }

  Future<Response> _getUser(Request request, String userId) async {
    try {
      final conn = await DatabaseService().connection;
      
      final result = await conn.query(
        '''
        SELECT id, name, email, phone, role, profile_image_url, additional_info, 
               created_at, last_login_at
        FROM users
        WHERE id = @id
        ''',
        substitutionValues: {'id': userId},
      );

      if (result.isEmpty) {
        return ResponseHelper.error(
          message: 'User not found',
          statusCode: 404,
        );
      }

      final user = result.first;
      
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
        'id': user[0],
        'name': user[1],
        'email': user[2],
        'phone': user[3],
        'role': user[4],
        'profileImageUrl': user[5],
        'additionalInfo': additionalInfo,
        'createdAt': user[7],
        'lastLoginAt': user[8],
      });
    } catch (e) {
      AppLogger.error('Get user error', e);
      return ResponseHelper.error(message: 'Failed to get user: $e');
    }
  }

  Future<Response> _updateUser(Request request, String userId) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      final updates = <String, dynamic>{};
      final substitutionValues = <String, dynamic>{'id': userId};
      
      if (body.containsKey('name')) {
        updates['name'] = body['name'];
        substitutionValues['name'] = body['name'];
      }
      if (body.containsKey('email')) {
        updates['email'] = body['email'];
        substitutionValues['email'] = body['email'];
      }
      if (body.containsKey('phone')) {
        updates['phone'] = body['phone'];
        substitutionValues['phone'] = body['phone'];
      }
      if (body.containsKey('additionalInfo')) {
        updates['additional_info'] = jsonEncode(body['additionalInfo']);
        substitutionValues['additional_info'] = jsonEncode(body['additionalInfo']);
      }
      if (body.containsKey('profileImageUrl')) {
        updates['profile_image_url'] = body['profileImageUrl'];
        substitutionValues['profile_image_url'] = body['profileImageUrl'];
      }

      if (updates.isEmpty) {
        return ResponseHelper.error(message: 'No fields to update');
      }

      // بناء SET clause مع أسماء الأعمدة الصحيحة
      final setClause = updates.keys.map((k) => '$k = @$k').join(', ');
      
      await conn.execute(
        '''
        UPDATE users 
        SET $setClause
        WHERE id = @id
        ''',
        substitutionValues: substitutionValues,
      );

      return ResponseHelper.success(data: {'message': 'User updated successfully'});
    } catch (e) {
      AppLogger.error('Update user error', e);
      return ResponseHelper.error(message: 'Failed to update user: $e');
    }
  }

  Future<Response> _deleteUser(Request request, String userId) async {
    try {
      final conn = await DatabaseService().connection;
      
      await conn.execute(
        'DELETE FROM users WHERE id = @id',
        substitutionValues: {'id': userId},
      );

      return ResponseHelper.success(data: {'message': 'User deleted successfully'});
    } catch (e) {
      AppLogger.error('Delete user error', e);
      return ResponseHelper.error(message: 'Failed to delete user: $e');
    }
  }
}

