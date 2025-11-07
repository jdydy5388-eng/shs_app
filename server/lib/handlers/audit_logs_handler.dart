import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';
import '../database/database_service.dart';
import '../utils/response_helper.dart';
import '../logger/app_logger.dart';

class AuditLogsHandler {
  Router get router {
    final router = Router();

    router.get('/', _getAuditLogs);
    router.post('/', _createAuditLog);

    return router;
  }

  Future<Response> _getAuditLogs(Request request) async {
    try {
      final params = request.url.queryParameters;
      final userId = params['userId'];
      final resourceType = params['resourceType'];
      final limit = int.tryParse(params['limit'] ?? '100') ?? 100;

      final conn = await DatabaseService().connection;
      
      String query = '''
        SELECT id, user_id, user_name, action, resource_type, resource_id, details,
               ip_address, created_at
        FROM audit_logs
        WHERE 1=1
      ''';
      
      final parameters = <String, dynamic>{};
      
      if (userId != null) {
        query += ' AND user_id = @userId';
        parameters['userId'] = userId;
      }
      
      if (resourceType != null) {
        query += ' AND resource_type = @resourceType';
        parameters['resourceType'] = resourceType;
      }
      
      query += ' ORDER BY created_at DESC LIMIT @limit';
      parameters['limit'] = limit;

      final logs = await conn.query(
        query,
        substitutionValues: parameters,
      );

      final result = logs.map((log) => {
        'id': log[0],
        'userId': log[1],
        'userName': log[2],
        'action': log[3],
        'resourceType': log[4],
        'resourceId': log[5],
        'details': log[6] != null ? jsonDecode(log[6] as String) : null,
        'ipAddress': log[7],
        'createdAt': log[8],
      }).toList();

      return ResponseHelper.list(data: result);
    } catch (e) {
      AppLogger.error('Get audit logs error', e);
      return ResponseHelper.error(message: 'Failed to get audit logs: $e');
    }
  }

  Future<Response> _createAuditLog(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      await conn.execute(
        '''
        INSERT INTO audit_logs 
        (id, user_id, user_name, action, resource_type, resource_id, details,
         ip_address, created_at)
        VALUES (@id, @userId, @userName, @action, @resourceType, @resourceId, @details,
                @ipAddress, @createdAt)
        ''',
        substitutionValues: {
          'id': body['id'],
          'userId': body['userId'],
          'userName': body['userName'],
          'action': body['action'],
          'resourceType': body['resourceType'],
          'resourceId': body['resourceId'],
          'details': body['details'] != null ? jsonEncode(body['details']) : null,
          'ipAddress': body['ipAddress'],
          'createdAt': body['createdAt'],
        },
      );

      return ResponseHelper.success(data: {'message': 'Audit log created successfully'});
    } catch (e) {
      AppLogger.error('Create audit log error', e);
      return ResponseHelper.error(message: 'Failed to create audit log: $e');
    }
  }
}

