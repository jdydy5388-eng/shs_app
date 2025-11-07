import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';
import '../database/database_service.dart';
import '../utils/response_helper.dart';
import '../logger/app_logger.dart';

class SystemSettingsHandler {
  Router get router {
    final router = Router();

    router.get('/', _getAllSettings);
    router.get('/<key>', _getSetting);
    router.put('/<key>', _updateSetting);

    return router;
  }

  Future<Response> _getAllSettings(Request request) async {
    try {
      final conn = await DatabaseService().connection;
      
      final settings = await conn.query(
        '''
        SELECT key, value, description, updated_at
        FROM system_settings
        ORDER BY key
        ''',
      );

      final result = settings.map((setting) => {
        'key': setting[0],
        'value': setting[1],
        'description': setting[2],
        'updatedAt': setting[3],
      }).toList();

      return ResponseHelper.list(data: result);
    } catch (e) {
      AppLogger.error('Get system settings error', e);
      return ResponseHelper.error(message: 'Failed to get system settings: $e');
    }
  }

  Future<Response> _getSetting(Request request, String key) async {
    try {
      final conn = await DatabaseService().connection;
      
      final setting = await conn.query(
        '''
        SELECT key, value, description, updated_at
        FROM system_settings
        WHERE key = @key
        ''',
        substitutionValues: {'key': key},
      );

      if (setting.isEmpty) {
        return ResponseHelper.error(
          message: 'Setting not found',
          statusCode: 404,
        );
      }

      final s = setting.first;
      return ResponseHelper.success(data: {
        'key': s[0],
        'value': s[1],
        'description': s[2],
        'updatedAt': s[3],
      });
    } catch (e) {
      AppLogger.error('Get system setting error', e);
      return ResponseHelper.error(message: 'Failed to get system setting: $e');
    }
  }

  Future<Response> _updateSetting(Request request, String key) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final value = body['value'] as String;
      final description = body['description'] as String?;

      final conn = await DatabaseService().connection;
      
      await conn.execute(
        '''
        INSERT INTO system_settings (key, value, description, updated_at)
        VALUES (@key, @value, @description, @updatedAt)
        ON CONFLICT (key) 
        DO UPDATE SET value = @value, description = @description, updated_at = @updatedAt
        ''',
        substitutionValues: {
          'key': key,
          'value': value,
          'description': description,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
      );

      return ResponseHelper.success(data: {'message': 'System setting updated successfully'});
    } catch (e) {
      AppLogger.error('Update system setting error', e);
      return ResponseHelper.error(message: 'Failed to update system setting: $e');
    }
  }
}

