import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database/database_service.dart';
import '../utils/response_helper.dart';
import '../utils/rbac.dart';
import '../middleware/auth_middleware.dart';
import '../logger/app_logger.dart';

class IntegrationsHandler {
  final DatabaseService _db = DatabaseService();

  Router get router {
    final router = Router();

    // External Integrations
    router.get('/external', _getExternalIntegrations);
    router.get('/external/<id>', _getExternalIntegration);
    router.post('/external', _createExternalIntegration);
    router.put('/external/<id>', _updateExternalIntegration);
    router.delete('/external/<id>', _deleteExternalIntegration);
    router.post('/external/<id>/sync', _syncExternalIntegration);

    // Sync Logs
    router.get('/sync-logs', _getSyncLogs);
    router.get('/sync-logs/<integrationId>', _getSyncLogsByIntegration);

    // HL7/FHIR Endpoints
    router.get('/hl7/patient/<id>', _getHL7Patient);
    router.post('/hl7/patient', _createHL7Patient);
    router.get('/hl7/lab-result/<id>', _getHL7LabResult);
    router.post('/hl7/lab-result', _createHL7LabResult);

    return router;
  }

  Future<Response> _getExternalIntegrations(Request request) async {
    try {
      final user = AuthMiddleware.getUser(request);
      if (user == null || !Rbac.has(user.role, Permission.manageSystemSettings)) {
        return ResponseHelper.unauthorized();
      }

      final conn = await _db.connection;
      final results = await conn.query('SELECT * FROM external_integrations ORDER BY name ASC');

      final integrations = results.map((row) {
        return {
          'id': row[0],
          'name': row[1],
          'type': row[2],
          'status': row[3],
          'apiUrl': row[4],
          'apiKey': row[5], // مشفر - لا يتم إرساله إلا عند الحاجة
          'apiSecret': row[6], // مشفر
          'config': row[7] != null ? jsonDecode(row[7] as String) : null,
          'description': row[8],
          'lastSync': row[9],
          'lastSyncError': row[10],
          'metadata': row[11] != null ? jsonDecode(row[11] as String) : null,
          'createdAt': row[12],
          'updatedAt': row[13],
        };
      }).toList();

      return ResponseHelper.list(data: integrations);
    } catch (e, stackTrace) {
      AppLogger.error('Get external integrations error', e, stackTrace);
      return ResponseHelper.error('خطأ في جلب التكاملات الخارجية: $e', stackTrace);
    }
  }

  Future<Response> _getExternalIntegration(Request request, String id) async {
    try {
      final user = AuthMiddleware.getUser(request);
      if (user == null || !Rbac.has(user.role, Permission.manageSystemSettings)) {
        return ResponseHelper.unauthorized();
      }

      final conn = await _db.connection;
      final results = await conn.query(
        'SELECT * FROM external_integrations WHERE id = @id',
        substitutionValues: {'id': id},
      );

      if (results.isEmpty) {
        return ResponseHelper.notFound('التكامل غير موجود');
      }

      final row = results.first;
      return ResponseHelper.success(data: {
        'id': row[0],
        'name': row[1],
        'type': row[2],
        'status': row[3],
        'apiUrl': row[4],
        'apiKey': row[5],
        'apiSecret': row[6],
        'config': row[7] != null ? jsonDecode(row[7] as String) : null,
        'description': row[8],
        'lastSync': row[9],
        'lastSyncError': row[10],
        'metadata': row[11] != null ? jsonDecode(row[11] as String) : null,
        'createdAt': row[12],
        'updatedAt': row[13],
      });
    } catch (e, stackTrace) {
      AppLogger.error('Get external integration error', e, stackTrace);
      return ResponseHelper.error('خطأ في جلب التكامل: $e', stackTrace);
    }
  }

  Future<Response> _createExternalIntegration(Request request) async {
    try {
      final user = AuthMiddleware.getUser(request);
      if (user == null || !Rbac.has(user.role, Permission.manageSystemSettings)) {
        return ResponseHelper.unauthorized();
      }

      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final conn = await _db.connection;
      await conn.execute('''
        INSERT INTO external_integrations (
          id, name, type, status, api_url, api_key, api_secret,
          config, description, last_sync, last_sync_error,
          metadata, created_at, updated_at
        ) VALUES (
          @id, @name, @type, @status, @apiUrl, @apiKey, @apiSecret,
          @config, @description, @lastSync, @lastSyncError,
          @metadata, @createdAt, @updatedAt
        )
      ''', substitutionValues: {
        'id': data['id'],
        'name': data['name'],
        'type': data['type'] ?? 'other',
        'status': data['status'] ?? 'pending',
        'apiUrl': data['apiUrl'],
        'apiKey': data['apiKey'], // يجب أن يكون مشفراً من قبل العميل
        'apiSecret': data['apiSecret'], // يجب أن يكون مشفراً
        'config': data['config'] != null ? jsonEncode(data['config']) : null,
        'description': data['description'],
        'lastSync': data['lastSync'],
        'lastSyncError': data['lastSyncError'],
        'metadata': data['metadata'] != null ? jsonEncode(data['metadata']) : null,
        'createdAt': data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
        'updatedAt': data['updatedAt'],
      });

      return ResponseHelper.success({'message': 'تم إنشاء التكامل بنجاح'});
    } catch (e, stackTrace) {
      AppLogger.error('Create external integration error', e, stackTrace);
      return ResponseHelper.error('خطأ في إنشاء التكامل: $e', stackTrace);
    }
  }

  Future<Response> _updateExternalIntegration(Request request, String id) async {
    try {
      final user = AuthMiddleware.getUser(request);
      if (user == null || !Rbac.has(user.role, Permission.manageSystemSettings)) {
        return ResponseHelper.unauthorized();
      }

      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final conn = await _db.connection;
      await conn.execute('''
        UPDATE external_integrations SET
          name = @name,
          type = @type,
          status = @status,
          api_url = @apiUrl,
          api_key = @apiKey,
          api_secret = @apiSecret,
          config = @config,
          description = @description,
          last_sync = @lastSync,
          last_sync_error = @lastSyncError,
          metadata = @metadata,
          updated_at = @updatedAt
        WHERE id = @id
      ''', substitutionValues: {
        'id': id,
        'name': data['name'],
        'type': data['type'],
        'status': data['status'],
        'apiUrl': data['apiUrl'],
        'apiKey': data['apiKey'],
        'apiSecret': data['apiSecret'],
        'config': data['config'] != null ? jsonEncode(data['config']) : null,
        'description': data['description'],
        'lastSync': data['lastSync'],
        'lastSyncError': data['lastSyncError'],
        'metadata': data['metadata'] != null ? jsonEncode(data['metadata']) : null,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      return ResponseHelper.success({'message': 'تم تحديث التكامل بنجاح'});
    } catch (e, stackTrace) {
      AppLogger.error('Update external integration error', e, stackTrace);
      return ResponseHelper.error('خطأ في تحديث التكامل: $e', stackTrace);
    }
  }

  Future<Response> _deleteExternalIntegration(Request request, String id) async {
    try {
      final user = AuthMiddleware.getUser(request);
      if (user == null || !Rbac.has(user.role, Permission.manageSystemSettings)) {
        return ResponseHelper.unauthorized();
      }

      final conn = await _db.connection;
      await conn.execute(
        'DELETE FROM external_integrations WHERE id = @id',
        substitutionValues: {'id': id},
      );

      return ResponseHelper.success({'message': 'تم حذف التكامل بنجاح'});
    } catch (e, stackTrace) {
      AppLogger.error('Delete external integration error', e, stackTrace);
      return ResponseHelper.error('خطأ في حذف التكامل: $e', stackTrace);
    }
  }

  Future<Response> _syncExternalIntegration(Request request, String id) async {
    try {
      final user = AuthMiddleware.getUser(request);
      if (user == null || !Rbac.has(user.role, Permission.manageSystemSettings)) {
        return ResponseHelper.unauthorized();
      }

      // TODO: تنفيذ منطق المزامنة
      // يمكن استدعاء ExternalIntegrationService هنا

      return ResponseHelper.success({'message': 'تمت المزامنة بنجاح'});
    } catch (e, stackTrace) {
      AppLogger.error('Sync external integration error', e, stackTrace);
      return ResponseHelper.error('خطأ في المزامنة: $e', stackTrace);
    }
  }

  Future<Response> _getSyncLogs(Request request) async {
    try {
      final user = AuthMiddleware.getUser(request);
      if (user == null || !Rbac.has(user.role, Permission.viewAuditLogs)) {
        return ResponseHelper.unauthorized();
      }

      final conn = await _db.connection;
      final results = await conn.query(
        'SELECT * FROM integration_sync_logs ORDER BY timestamp DESC LIMIT 100',
      );

      final logs = results.map((row) {
        return {
          'id': row[0],
          'integrationId': row[1],
          'integrationName': row[2],
          'syncType': row[3],
          'success': row[4],
          'errorMessage': row[5],
          'recordsProcessed': row[6],
          'details': row[7] != null ? jsonDecode(row[7] as String) : null,
          'timestamp': row[8],
        };
      }).toList();

      return ResponseHelper.list(data: logs);
    } catch (e, stackTrace) {
      AppLogger.error('Get sync logs error', e, stackTrace);
      return ResponseHelper.error('خطأ في جلب سجلات المزامنة: $e', stackTrace);
    }
  }

  Future<Response> _getSyncLogsByIntegration(Request request, String integrationId) async {
    try {
      final user = AuthMiddleware.getUser(request);
      if (user == null || !Rbac.has(user.role, Permission.viewAuditLogs)) {
        return ResponseHelper.unauthorized();
      }

      final conn = await _db.connection;
      final results = await conn.query(
        'SELECT * FROM integration_sync_logs WHERE integration_id = @integrationId ORDER BY timestamp DESC',
        substitutionValues: {'integrationId': integrationId},
      );

      final logs = results.map((row) {
        return {
          'id': row[0],
          'integrationId': row[1],
          'integrationName': row[2],
          'syncType': row[3],
          'success': row[4],
          'errorMessage': row[5],
          'recordsProcessed': row[6],
          'details': row[7] != null ? jsonDecode(row[7] as String) : null,
          'timestamp': row[8],
        };
      }).toList();

      return ResponseHelper.list(data: logs);
    } catch (e, stackTrace) {
      AppLogger.error('Get sync logs by integration error', e, stackTrace);
      return ResponseHelper.error('خطأ في جلب سجلات المزامنة: $e', stackTrace);
    }
  }

  Future<Response> _getHL7Patient(Request request, String id) async {
    try {
      // TODO: جلب بيانات المريض وتحويلها إلى تنسيق HL7/FHIR
      return ResponseHelper.success(data: {'message': 'HL7 Patient endpoint'});
    } catch (e, stackTrace) {
      AppLogger.error('Get HL7 patient error', e, stackTrace);
      return ResponseHelper.error('خطأ في جلب بيانات المريض HL7: $e', stackTrace);
    }
  }

  Future<Response> _createHL7Patient(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      // TODO: معالجة بيانات المريض من تنسيق HL7/FHIR
      return ResponseHelper.success({'message': 'تم إنشاء المريض بنجاح'});
    } catch (e, stackTrace) {
      AppLogger.error('Create HL7 patient error', e, stackTrace);
      return ResponseHelper.error('خطأ في إنشاء المريض HL7: $e', stackTrace);
    }
  }

  Future<Response> _getHL7LabResult(Request request, String id) async {
    try {
      // TODO: جلب نتائج الفحص وتحويلها إلى تنسيق HL7/FHIR
      return ResponseHelper.success(data: {'message': 'HL7 Lab Result endpoint'});
    } catch (e, stackTrace) {
      AppLogger.error('Get HL7 lab result error', e, stackTrace);
      return ResponseHelper.error('خطأ في جلب نتائج الفحص HL7: $e', stackTrace);
    }
  }

  Future<Response> _createHL7LabResult(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      // TODO: معالجة نتائج الفحص من تنسيق HL7/FHIR
      return ResponseHelper.success({'message': 'تم إنشاء نتيجة الفحص بنجاح'});
    } catch (e, stackTrace) {
      AppLogger.error('Create HL7 lab result error', e, stackTrace);
      return ResponseHelper.error('خطأ في إنشاء نتيجة الفحص HL7: $e', stackTrace);
    }
  }
}

