import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';
import '../database/database_service.dart';
import '../utils/response_helper.dart';
import '../logger/app_logger.dart';

class EmergencyHandler {
  Router get router {
    final router = Router();

    router.get('/cases', _getCases);
    router.get('/cases/<caseId>', _getCase);
    router.post('/cases', _createCase);
    router.put('/cases/<caseId>', _updateCase);
    router.put('/cases/<caseId>/status', _updateCaseStatus);

    router.get('/events', _getEvents);
    router.post('/events', _createEvent);

    return router;
  }

  Future<Response> _getCases(Request request) async {
    try {
      final params = request.url.queryParameters;
      final status = params['status'];
      final triage = params['triage'];

      final conn = await DatabaseService().connection;
      String query = '''
        SELECT id, patient_id, patient_name, triage_level, status, vital_signs, symptoms, notes, created_at, updated_at
        FROM emergency_cases WHERE 1=1
      ''';
      final values = <String, dynamic>{};
      if (status != null) {
        query += ' AND status = @status';
        values['status'] = status;
      }
      if (triage != null) {
        query += ' AND triage_level = @triage';
        values['triage'] = triage;
      }
      query += ' ORDER BY created_at DESC';

      final rows = await conn.query(query, substitutionValues: values.isEmpty ? null : values);
      final data = rows.map((r) => {
        'id': r[0],
        'patientId': r[1],
        'patientName': r[2],
        'triageLevel': r[3],
        'status': r[4],
        'vitalSigns': r[5] != null ? jsonDecode(r[5] as String) : null,
        'symptoms': r[6],
        'notes': r[7],
        'createdAt': r[8],
        'updatedAt': r[9],
      }).toList();
      return ResponseHelper.list(data: data);
    } catch (e) {
      AppLogger.error('Get emergency cases error', e);
      return ResponseHelper.error(message: 'Failed to get cases: $e');
    }
  }

  Future<Response> _getCase(Request request, String caseId) async {
    try {
      final conn = await DatabaseService().connection;
      final rows = await conn.query(
        '''
        SELECT id, patient_id, patient_name, triage_level, status, vital_signs, symptoms, notes, created_at, updated_at
        FROM emergency_cases WHERE id = @id
        ''',
        substitutionValues: {'id': caseId},
      );
      if (rows.isEmpty) return ResponseHelper.error(message: 'Case not found', statusCode: 404);
      final r = rows.first;
      final data = {
        'id': r[0],
        'patientId': r[1],
        'patientName': r[2],
        'triageLevel': r[3],
        'status': r[4],
        'vitalSigns': r[5] != null ? jsonDecode(r[5] as String) : null,
        'symptoms': r[6],
        'notes': r[7],
        'createdAt': r[8],
        'updatedAt': r[9],
      };
      return ResponseHelper.success(data: data);
    } catch (e) {
      AppLogger.error('Get emergency case error', e);
      return ResponseHelper.error(message: 'Failed to get case: $e');
    }
  }

  Future<Response> _createCase(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;
      await conn.execute(
        '''
        INSERT INTO emergency_cases (id, patient_id, patient_name, triage_level, status, vital_signs, symptoms, notes, created_at, updated_at)
        VALUES (@id, @patientId, @patientName, @triageLevel, @status, @vitalSigns, @symptoms, @notes, @createdAt, @updatedAt)
        ''',
        substitutionValues: {
          'id': body['id'],
          'patientId': body['patientId'],
          'patientName': body['patientName'],
          'triageLevel': body['triageLevel'],
          'status': body['status'] ?? 'waiting',
          'vitalSigns': body['vitalSigns'] != null ? jsonEncode(body['vitalSigns']) : null,
          'symptoms': body['symptoms'],
          'notes': body['notes'],
          'createdAt': body['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
          'updatedAt': body['updatedAt'],
        },
      );
      return ResponseHelper.success(data: {'message': 'Emergency case created'});
    } catch (e) {
      AppLogger.error('Create emergency case error', e);
      return ResponseHelper.error(message: 'Failed to create case: $e');
    }
  }

  Future<Response> _updateCase(Request request, String caseId) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;
      final fields = <String>[];
      final values = <String, dynamic>{'id': caseId};
      void setField(String key, dynamic val) {
        fields.add('$key = @$key');
        values[key] = val;
      }
      if (body.containsKey('patientId')) setField('patient_id', body['patientId']);
      if (body.containsKey('patientName')) setField('patient_name', body['patientName']);
      if (body.containsKey('triageLevel')) setField('triage_level', body['triageLevel']);
      if (body.containsKey('status')) setField('status', body['status']);
      if (body.containsKey('vitalSigns')) setField('vital_signs', body['vitalSigns'] != null ? jsonEncode(body['vitalSigns']) : null);
      if (body.containsKey('symptoms')) setField('symptoms', body['symptoms']);
      if (body.containsKey('notes')) setField('notes', body['notes']);
      setField('updated_at', DateTime.now().millisecondsSinceEpoch);

      if (fields.isEmpty) return ResponseHelper.success(data: {'message': 'Nothing to update'});

      await conn.execute('UPDATE emergency_cases SET ${fields.join(', ')} WHERE id = @id', substitutionValues: values);
      return ResponseHelper.success(data: {'message': 'Emergency case updated'});
    } catch (e) {
      AppLogger.error('Update emergency case error', e);
      return ResponseHelper.error(message: 'Failed to update case: $e');
    }
  }

  Future<Response> _updateCaseStatus(Request request, String caseId) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final status = body['status'] as String;
      final conn = await DatabaseService().connection;
      await conn.execute(
        '''
        UPDATE emergency_cases SET status = @status, updated_at = @updatedAt WHERE id = @id
        ''',
        substitutionValues: {
          'id': caseId,
          'status': status,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
      );
      return ResponseHelper.success(data: {'message': 'Emergency status updated'});
    } catch (e) {
      AppLogger.error('Update emergency status error', e);
      return ResponseHelper.error(message: 'Failed to update status: $e');
    }
  }

  Future<Response> _getEvents(Request request) async {
    try {
      final params = request.url.queryParameters;
      final caseId = params['caseId'];
      final conn = await DatabaseService().connection;
      String query = '''
        SELECT id, case_id, event_type, details, created_at
        FROM emergency_events WHERE 1=1
      ''';
      final values = <String, dynamic>{};
      if (caseId != null) {
        query += ' AND case_id = @caseId';
        values['caseId'] = caseId;
      }
      query += ' ORDER BY created_at DESC';
      final rows = await conn.query(query, substitutionValues: values.isEmpty ? null : values);
      final data = rows.map((r) => {
        'id': r[0],
        'caseId': r[1],
        'eventType': r[2],
        'details': r[3] != null ? jsonDecode(r[3] as String) : null,
        'createdAt': r[4],
      }).toList();
      return ResponseHelper.list(data: data);
    } catch (e) {
      AppLogger.error('Get emergency events error', e);
      return ResponseHelper.error(message: 'Failed to get events: $e');
    }
  }

  Future<Response> _createEvent(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;
      await conn.execute(
        '''
        INSERT INTO emergency_events (id, case_id, event_type, details, created_at)
        VALUES (@id, @caseId, @eventType, @details, @createdAt)
        ''',
        substitutionValues: {
          'id': body['id'],
          'caseId': body['caseId'],
          'eventType': body['eventType'],
          'details': body['details'] != null ? jsonEncode(body['details']) : null,
          'createdAt': body['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
        },
      );
      return ResponseHelper.success(data: {'message': 'Emergency event created'});
    } catch (e) {
      AppLogger.error('Create emergency event error', e);
      return ResponseHelper.error(message: 'Failed to create event: $e');
    }
  }
}


