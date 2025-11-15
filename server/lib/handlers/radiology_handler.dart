import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';
import '../database/database_service.dart';
import '../utils/response_helper.dart';
import '../logger/app_logger.dart';
import '../utils/auth_guard.dart';
import '../utils/rbac.dart';

class RadiologyHandler {
  Router get router {
    final router = Router();

    // Requests
    router.get('/requests', _getRequests);
    router.get('/requests/<id>', _getRequest);
    router.post('/requests', _createRequest);
    router.put('/requests/<id>', _updateRequest);
    router.put('/requests/<id>/status', _updateRequestStatus);

    // Reports
    router.get('/reports', _getReports);
    router.get('/reports/<id>', _getReport);
    router.post('/reports', _createReport);

    return router;
  }

  Future<Response> _getRequests(Request request) async {
    try {
      final user = getRequestUser(request);
      if (!isAuthenticated(user)) return Response.forbidden('Unauthorized');
      if (!(user.isAdmin || Rbac.has(user.role, Permission.readRadiology))) {
        return Response.forbidden('Unauthorized');
      }
      final params = request.url.queryParameters;
      final doctorId = params['doctorId'];
      final patientId = params['patientId'];
      final status = params['status'];
      final modality = params['modality'];

      final conn = await DatabaseService().connection;
      String query = '''
        SELECT id, doctor_id, patient_id, patient_name, modality, body_part, status, notes,
               requested_at, scheduled_at, completed_at
        FROM radiology_requests WHERE 1=1
      ''';
      final values = <String, dynamic>{};
      // تقييد حسب الدور
      if (user.isAdmin) {
        if (doctorId != null) { query += ' AND doctor_id = @doctorId'; values['doctorId'] = doctorId; }
        if (patientId != null) { query += ' AND patient_id = @patientId'; values['patientId'] = patientId; }
      } else if (user.isDoctor) {
        final dId = doctorId ?? user.id;
        query += ' AND doctor_id = @doctorId';
        values['doctorId'] = dId;
        if (patientId != null) { query += ' AND patient_id = @patientId'; values['patientId'] = patientId; }
      } else if (user.isPatient) {
        final pId = patientId ?? user.id;
        query += ' AND patient_id = @patientId';
        values['patientId'] = pId;
      } else {
        return Response.forbidden('Unauthorized');
      }
      if (status != null) { query += ' AND status = @status'; values['status'] = status; }
      if (modality != null) { query += ' AND modality = @modality'; values['modality'] = modality; }
      query += ' ORDER BY requested_at DESC';

      final rows = await conn.query(query, substitutionValues: values.isEmpty ? null : values);
      final data = rows.map((r) => {
        'id': r[0], 'doctorId': r[1], 'patientId': r[2], 'patientName': r[3],
        'modality': r[4], 'bodyPart': r[5], 'status': r[6], 'notes': r[7],
        'requestedAt': r[8], 'scheduledAt': r[9], 'completedAt': r[10],
      }).toList();
      return ResponseHelper.list(data: data);
    } catch (e) {
      AppLogger.error('Get radiology requests error', e);
      return ResponseHelper.error(message: 'Failed to get requests: $e');
    }
  }

  Future<Response> _getRequest(Request request, String id) async {
    try {
      final conn = await DatabaseService().connection;
      final rows = await conn.query(
        '''
        SELECT id, doctor_id, patient_id, patient_name, modality, body_part, status, notes,
               requested_at, scheduled_at, completed_at
        FROM radiology_requests WHERE id = @id
        ''', substitutionValues: {'id': id});
      if (rows.isEmpty) return ResponseHelper.error(message: 'Request not found', statusCode: 404);
      final r = rows.first;
      final data = {
        'id': r[0], 'doctorId': r[1], 'patientId': r[2], 'patientName': r[3],
        'modality': r[4], 'bodyPart': r[5], 'status': r[6], 'notes': r[7],
        'requestedAt': r[8], 'scheduledAt': r[9], 'completedAt': r[10],
      };
      return ResponseHelper.success(data: data);
    } catch (e) {
      AppLogger.error('Get radiology request error', e);
      return ResponseHelper.error(message: 'Failed to get request: $e');
    }
  }

  Future<Response> _createRequest(Request request) async {
    try {
      final user = getRequestUser(request);
      if (!(user.isAdmin || Rbac.has(user.role, Permission.writeRadiology))) {
        return Response.forbidden('Unauthorized');
      }
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;
      await conn.execute(
        '''
        INSERT INTO radiology_requests (id, doctor_id, patient_id, patient_name, modality, body_part, status, notes, requested_at, scheduled_at, completed_at)
        VALUES (@id, @doctorId, @patientId, @patientName, @modality, @bodyPart, @status, @notes, @requestedAt, @scheduledAt, @completedAt)
        ''',
        substitutionValues: {
          'id': body['id'],
          'doctorId': body['doctorId'],
          'patientId': body['patientId'],
          'patientName': body['patientName'],
          'modality': body['modality'],
          'bodyPart': body['bodyPart'],
          'status': body['status'] ?? 'requested',
          'notes': body['notes'],
          'requestedAt': body['requestedAt'] ?? DateTime.now().millisecondsSinceEpoch,
          'scheduledAt': body['scheduledAt'],
          'completedAt': body['completedAt'],
        },
      );
      return ResponseHelper.success(data: {'message': 'Radiology request created'});
    } catch (e) {
      AppLogger.error('Create radiology request error', e);
      return ResponseHelper.error(message: 'Failed to create request: $e');
    }
  }

  Future<Response> _updateRequest(Request request, String id) async {
    try {
      final user = getRequestUser(request);
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;
      // تحقق من ملكية الطلب للطبيب الحالي أو صلاحية المدير
      if (!user.isAdmin) {
        final owns = await conn.query('SELECT 1 FROM radiology_requests WHERE id=@id AND doctor_id=@doc LIMIT 1',
            substitutionValues: {'id': id, 'doc': user.id});
        if (owns.isEmpty) return Response.forbidden('Unauthorized');
      }
      final fields = <String>[];
      final values = <String, dynamic>{'id': id};
      void setField(String key, dynamic val) { fields.add('$key = @$key'); values[key] = val; }
      if (body.containsKey('modality')) setField('modality', body['modality']);
      if (body.containsKey('bodyPart')) setField('body_part', body['bodyPart']);
      if (body.containsKey('notes')) setField('notes', body['notes']);
      if (body.containsKey('scheduledAt')) setField('scheduled_at', body['scheduledAt']);
      if (body.containsKey('completedAt')) setField('completed_at', body['completedAt']);
      if (fields.isEmpty) return ResponseHelper.success(data: {'message': 'Nothing to update'});
      await conn.execute('UPDATE radiology_requests SET ${fields.join(', ')} WHERE id = @id', substitutionValues: values);
      return ResponseHelper.success(data: {'message': 'Radiology request updated'});
    } catch (e) {
      AppLogger.error('Update radiology request error', e);
      return ResponseHelper.error(message: 'Failed to update request: $e');
    }
  }

  Future<Response> _updateRequestStatus(Request request, String id) async {
    try {
      final user = getRequestUser(request);
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final status = body['status'] as String;
      final conn = await DatabaseService().connection;
      if (!user.isAdmin) {
        final owns = await conn.query('SELECT 1 FROM radiology_requests WHERE id=@id AND doctor_id=@doc LIMIT 1',
            substitutionValues: {'id': id, 'doc': user.id});
        if (owns.isEmpty) return Response.forbidden('Unauthorized');
      }
      await conn.execute(
        'UPDATE radiology_requests SET status = @status WHERE id = @id',
        substitutionValues: {'id': id, 'status': status},
      );
      return ResponseHelper.success(data: {'message': 'Radiology status updated'});
    } catch (e) {
      AppLogger.error('Update radiology status error', e);
      return ResponseHelper.error(message: 'Failed to update status: $e');
    }
  }

  Future<Response> _getReports(Request request) async {
    try {
      final user = getRequestUser(request);
      if (!isAuthenticated(user)) return Response.forbidden('Unauthorized');
      if (!(user.isAdmin || Rbac.has(user.role, Permission.readRadiology))) {
        return Response.forbidden('Unauthorized');
      }
      final params = request.url.queryParameters;
      final requestId = params['requestId'];
      final conn = await DatabaseService().connection;
      String query = '''
        SELECT id, request_id, findings, impression, attachments, created_at
        FROM radiology_reports WHERE 1=1
      ''';
      final values = <String, dynamic>{};
      if (requestId != null) { query += ' AND request_id = @requestId'; values['requestId'] = requestId; }
      // تقييد حسب الدور (انضمام مع طلبات الأشعة)
      if (!user.isAdmin && requestId == null) {
        if (user.isDoctor) {
          query += ' AND request_id IN (SELECT id FROM radiology_requests WHERE doctor_id=@doc)';
          values['doc'] = user.id;
        } else if (user.isPatient) {
          query += ' AND request_id IN (SELECT id FROM radiology_requests WHERE patient_id=@pat)';
          values['pat'] = user.id;
        } else {
          return Response.forbidden('Unauthorized');
        }
      }
      query += ' ORDER BY created_at DESC';

      final rows = await conn.query(query, substitutionValues: values.isEmpty ? null : values);
      final data = rows.map((r) => {
        'id': r[0], 'requestId': r[1], 'findings': r[2], 'impression': r[3],
        'attachments': r[4] != null ? jsonDecode(r[4] as String) : null,
        'createdAt': r[5],
      }).toList();
      return ResponseHelper.list(data: data);
    } catch (e) {
      AppLogger.error('Get radiology reports error', e);
      return ResponseHelper.error(message: 'Failed to get reports: $e');
    }
  }

  Future<Response> _createReport(Request request) async {
    try {
      final user = getRequestUser(request);
      if (!(user.isAdmin || Rbac.has(user.role, Permission.writeRadiology))) {
        return Response.forbidden('Unauthorized');
      }
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;
      // تحقق أن الطبيب مالك الطلب
      if (!user.isAdmin) {
        final owns = await conn.query('SELECT 1 FROM radiology_requests WHERE id=@rid AND doctor_id=@doc LIMIT 1',
            substitutionValues: {'rid': body['requestId'], 'doc': user.id});
        if (owns.isEmpty) return Response.forbidden('Unauthorized');
      }
      await conn.execute(
        '''
        INSERT INTO radiology_reports (id, request_id, findings, impression, attachments, created_at)
        VALUES (@id, @requestId, @findings, @impression, @attachments, @createdAt)
        ''',
        substitutionValues: {
          'id': body['id'],
          'requestId': body['requestId'],
          'findings': body['findings'],
          'impression': body['impression'],
          'attachments': body['attachments'] != null ? jsonEncode(body['attachments']) : null,
          'createdAt': body['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
        },
      );
      return ResponseHelper.success(data: {'message': 'Radiology report created'});
    } catch (e) {
      AppLogger.error('Create radiology report error', e);
      return ResponseHelper.error(message: 'Failed to create report: $e');
    }
  }

  Future<Response> _getReport(Request request, String id) async {
    try {
      final user = getRequestUser(request);
      if (!isAuthenticated(user)) return Response.forbidden('Unauthorized');
      if (!(user.isAdmin || Rbac.has(user.role, Permission.readRadiology))) {
        return Response.forbidden('Unauthorized');
      }
      final conn = await DatabaseService().connection;
      final rows = await conn.query(
        '''
        SELECT id, request_id, findings, impression, attachments, created_at
        FROM radiology_reports WHERE id = @id
        ''',
        substitutionValues: {'id': id},
      );
      if (rows.isEmpty) return ResponseHelper.error(message: 'Report not found', statusCode: 404);
      final r = rows.first;
      final data = {
        'id': r[0],
        'requestId': r[1],
        'findings': r[2],
        'impression': r[3],
        'attachments': r[4] != null ? jsonDecode(r[4] as String) : null,
        'createdAt': r[5],
      };
      return ResponseHelper.success(data: data);
    } catch (e) {
      AppLogger.error('Get radiology report error', e);
      return ResponseHelper.error(message: 'Failed to get report: $e');
    }
  }
}


