import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';
import '../database/database_service.dart';
import '../utils/response_helper.dart';
import '../logger/app_logger.dart';

class LabRequestsHandler {
  Router get router {
    final router = Router();

    router.get('/', _getLabRequests);
    router.get('/<requestId>', _getLabRequest);
    router.post('/', _createLabRequest);
    router.put('/<requestId>', _updateLabRequest);
    router.delete('/<requestId>', _deleteLabRequest);

    return router;
  }

  Future<Response> _getLabRequests(Request request) async {
    try {
      final params = request.url.queryParameters;
      final doctorId = params['doctorId'];
      final patientId = params['patientId'];
      final status = params['status'];

      final conn = await DatabaseService().connection;
      
      String query = '''
        SELECT id, doctor_id, patient_id, patient_name, test_type, status, notes,
               result_notes, result_attachments, requested_at, completed_at
        FROM lab_requests
        WHERE 1=1
      ''';
      
      final parameters = <String, dynamic>{};
      
      if (doctorId != null) {
        query += ' AND doctor_id = @doctorId';
        parameters['doctorId'] = doctorId;
      }
      
      if (patientId != null) {
        query += ' AND patient_id = @patientId';
        parameters['patientId'] = patientId;
      }
      
      if (status != null) {
        query += ' AND status = @status';
        parameters['status'] = status;
      }
      
      query += ' ORDER BY requested_at DESC';

      final requests = await conn.query(
        query,
        substitutionValues: parameters.isEmpty ? null : parameters,
      );

      final result = requests.map((req) => {
        'id': req[0],
        'doctorId': req[1],
        'patientId': req[2],
        'patientName': req[3],
        'testType': req[4],
        'status': req[5],
        'notes': req[6],
        'resultNotes': req[7],
        'resultAttachments': req[8] != null ? jsonDecode(req[8] as String) : null,
        'requestedAt': req[9],
        'completedAt': req[10],
      }).toList();

      return ResponseHelper.list(data: result);
    } catch (e) {
      AppLogger.error('Get lab requests error', e);
      return ResponseHelper.error(message: 'Failed to get lab requests: $e');
    }
  }

  Future<Response> _getLabRequest(Request request, String requestId) async {
    try {
      final conn = await DatabaseService().connection;
      
      final req = await conn.query(
        '''
        SELECT id, doctor_id, patient_id, patient_name, test_type, status, notes,
               result_notes, result_attachments, requested_at, completed_at
        FROM lab_requests
        WHERE id = @id
        ''',
        substitutionValues: {'id': requestId},
      );

      if (req.isEmpty) {
        return ResponseHelper.error(
          message: 'Lab request not found',
          statusCode: 404,
        );
      }

      final r = req.first;
      return ResponseHelper.success(data: {
        'id': r[0],
        'doctorId': r[1],
        'patientId': r[2],
        'patientName': r[3],
        'testType': r[4],
        'status': r[5],
        'notes': r[6],
        'resultNotes': r[7],
        'resultAttachments': r[8] != null ? jsonDecode(r[8] as String) : null,
        'requestedAt': r[9],
        'completedAt': r[10],
      });
    } catch (e) {
      AppLogger.error('Get lab request error', e);
      return ResponseHelper.error(message: 'Failed to get lab request: $e');
    }
  }

  Future<Response> _createLabRequest(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      await conn.execute(
        '''
        INSERT INTO lab_requests 
        (id, doctor_id, patient_id, patient_name, test_type, status, notes,
         result_notes, result_attachments, requested_at, completed_at)
        VALUES (@id, @doctorId, @patientId, @patientName, @testType, @status, @notes,
                @resultNotes, @resultAttachments, @requestedAt, @completedAt)
        ''',
        substitutionValues: {
          'id': body['id'],
          'doctorId': body['doctorId'],
          'patientId': body['patientId'],
          'patientName': body['patientName'],
          'testType': body['testType'],
          'status': body['status'],
          'notes': body['notes'],
          'resultNotes': body['resultNotes'],
          'resultAttachments': body['resultAttachments'] != null 
              ? jsonEncode(body['resultAttachments']) 
              : null,
          'requestedAt': body['requestedAt'],
          'completedAt': body['completedAt'],
        },
      );

      return ResponseHelper.success(data: {'message': 'Lab request created successfully'});
    } catch (e) {
      AppLogger.error('Create lab request error', e);
      return ResponseHelper.error(message: 'Failed to create lab request: $e');
    }
  }

  Future<Response> _updateLabRequest(Request request, String requestId) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      final updates = <String, dynamic>{};
      if (body.containsKey('status')) updates['status'] = body['status'];
      if (body.containsKey('resultNotes')) updates['resultNotes'] = body['resultNotes'];
      if (body.containsKey('resultAttachments')) {
        updates['resultAttachments'] = jsonEncode(body['resultAttachments']);
      }
      if (body.containsKey('completedAt')) updates['completedAt'] = body['completedAt'];

      if (updates.isEmpty) {
        return ResponseHelper.error(message: 'No fields to update');
      }

      final setClause = updates.keys.map((k) => '$k = @$k').join(', ');
      
      await conn.execute(
        '''
        UPDATE lab_requests 
        SET $setClause
        WHERE id = @id
        ''',
        substitutionValues: {
          'id': requestId,
          ...updates,
        },
      );

      return ResponseHelper.success(data: {'message': 'Lab request updated successfully'});
    } catch (e) {
      AppLogger.error('Update lab request error', e);
      return ResponseHelper.error(message: 'Failed to update lab request: $e');
    }
  }

  Future<Response> _deleteLabRequest(Request request, String requestId) async {
    try {
      final conn = await DatabaseService().connection;
      
      await conn.execute(
        'DELETE FROM lab_requests WHERE id = @id',
        substitutionValues: {'id': requestId},
      );

      return ResponseHelper.success(data: {'message': 'Lab request deleted successfully'});
    } catch (e) {
      AppLogger.error('Delete lab request error', e);
      return ResponseHelper.error(message: 'Failed to delete lab request: $e');
    }
  }
}

