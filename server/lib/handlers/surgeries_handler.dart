import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';
import '../database/database_service.dart';
import '../utils/response_helper.dart';
import '../logger/app_logger.dart';

class SurgeriesHandler {
  Router get router {
    final router = Router();

    router.get('/', _getSurgeries);
    router.get('/<surgeryId>', _getSurgery);
    router.post('/', _createSurgery);
    router.put('/<surgeryId>', _updateSurgery);
    router.delete('/<surgeryId>', _deleteSurgery);

    return router;
  }

  Future<Response> _getSurgeries(Request request) async {
    try {
      final params = request.url.queryParameters;
      final patientId = params['patientId'];
      final surgeonId = params['surgeonId'];
      final status = params['status'];
      final from = params['from'];
      final to = params['to'];

      final conn = await DatabaseService().connection;

      String query = '''
        SELECT id, patient_id, patient_name, surgery_name, type, status,
               scheduled_date, start_time, end_time, operation_room_id, operation_room_name,
               surgeon_id, surgeon_name, assistant_surgeon_id, assistant_surgeon_name,
               anesthesiologist_id, anesthesiologist_name, nurse_ids, nurse_names,
               pre_operative_notes, operative_notes, post_operative_notes,
               diagnosis, procedure, notes, equipment, created_at, updated_at
        FROM surgeries
        WHERE 1=1
      ''';

      final parameters = <String, dynamic>{};

      if (patientId != null) {
        query += ' AND patient_id = @patientId';
        parameters['patientId'] = patientId;
      }
      if (surgeonId != null) {
        query += ' AND surgeon_id = @surgeonId';
        parameters['surgeonId'] = surgeonId;
      }
      if (status != null) {
        query += ' AND status = @status';
        parameters['status'] = status;
      }
      if (from != null) {
        query += ' AND scheduled_date >= @from';
        parameters['from'] = int.parse(from);
      }
      if (to != null) {
        query += ' AND scheduled_date <= @to';
        parameters['to'] = int.parse(to);
      }

      query += ' ORDER BY scheduled_date DESC';

      final surgeries = await conn.query(
        query,
        substitutionValues: parameters.isEmpty ? null : parameters,
      );

      final result = surgeries.map((s) => {
        'id': s[0],
        'patientId': s[1],
        'patientName': s[2],
        'surgeryName': s[3],
        'type': s[4],
        'status': s[5],
        'scheduledDate': s[6],
        'startTime': s[7],
        'endTime': s[8],
        'operationRoomId': s[9],
        'operationRoomName': s[10],
        'surgeonId': s[11],
        'surgeonName': s[12],
        'assistantSurgeonId': s[13],
        'assistantSurgeonName': s[14],
        'anesthesiologistId': s[15],
        'anesthesiologistName': s[16],
        'nurseIds': s[17],
        'nurseNames': s[18],
        'preOperativeNotes': s[19],
        'operativeNotes': s[20],
        'postOperativeNotes': s[21],
        'diagnosis': s[22],
        'procedure': s[23],
        'notes': s[24],
        'equipment': s[25],
        'createdAt': s[26],
        'updatedAt': s[27],
      }).toList();

      return ResponseHelper.list(data: result);
    } catch (e) {
      AppLogger.error('Get surgeries error', e);
      return ResponseHelper.error(message: 'Failed to get surgeries: $e');
    }
  }

  Future<Response> _getSurgery(Request request, String surgeryId) async {
    try {
      final conn = await DatabaseService().connection;

      final result = await conn.query(
        '''
        SELECT id, patient_id, patient_name, surgery_name, type, status,
               scheduled_date, start_time, end_time, operation_room_id, operation_room_name,
               surgeon_id, surgeon_name, assistant_surgeon_id, assistant_surgeon_name,
               anesthesiologist_id, anesthesiologist_name, nurse_ids, nurse_names,
               pre_operative_notes, operative_notes, post_operative_notes,
               diagnosis, procedure, notes, equipment, created_at, updated_at
        FROM surgeries
        WHERE id = @id
        ''',
        substitutionValues: {'id': surgeryId},
      );

      if (result.isEmpty) {
        return ResponseHelper.error(message: 'Surgery not found', statusCode: 404);
      }

      final s = result.first;
      final data = {
        'id': s[0],
        'patientId': s[1],
        'patientName': s[2],
        'surgeryName': s[3],
        'type': s[4],
        'status': s[5],
        'scheduledDate': s[6],
        'startTime': s[7],
        'endTime': s[8],
        'operationRoomId': s[9],
        'operationRoomName': s[10],
        'surgeonId': s[11],
        'surgeonName': s[12],
        'assistantSurgeonId': s[13],
        'assistantSurgeonName': s[14],
        'anesthesiologistId': s[15],
        'anesthesiologistName': s[16],
        'nurseIds': s[17],
        'nurseNames': s[18],
        'preOperativeNotes': s[19],
        'operativeNotes': s[20],
        'postOperativeNotes': s[21],
        'diagnosis': s[22],
        'procedure': s[23],
        'notes': s[24],
        'equipment': s[25],
        'createdAt': s[26],
        'updatedAt': s[27],
      };

      return ResponseHelper.success(data: data);
    } catch (e) {
      AppLogger.error('Get surgery error', e);
      return ResponseHelper.error(message: 'Failed to get surgery: $e');
    }
  }

  Future<Response> _createSurgery(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      await conn.execute(
        '''
        INSERT INTO surgeries 
        (id, patient_id, patient_name, surgery_name, type, status, scheduled_date,
         start_time, end_time, operation_room_id, operation_room_name,
         surgeon_id, surgeon_name, assistant_surgeon_id, assistant_surgeon_name,
         anesthesiologist_id, anesthesiologist_name, nurse_ids, nurse_names,
         pre_operative_notes, operative_notes, post_operative_notes,
         diagnosis, procedure, notes, equipment, created_at, updated_at)
        VALUES 
        (@id, @patientId, @patientName, @surgeryName, @type, @status, @scheduledDate,
         @startTime, @endTime, @operationRoomId, @operationRoomName,
         @surgeonId, @surgeonName, @assistantSurgeonId, @assistantSurgeonName,
         @anesthesiologistId, @anesthesiologistName, @nurseIds, @nurseNames,
         @preOperativeNotes, @operativeNotes, @postOperativeNotes,
         @diagnosis, @procedure, @notes, @equipment, @createdAt, @updatedAt)
        ''',
        substitutionValues: {
          'id': body['id'],
          'patientId': body['patientId'],
          'patientName': body['patientName'],
          'surgeryName': body['surgeryName'],
          'type': body['type'],
          'status': body['status'],
          'scheduledDate': body['scheduledDate'],
          'startTime': body['startTime'],
          'endTime': body['endTime'],
          'operationRoomId': body['operationRoomId'],
          'operationRoomName': body['operationRoomName'],
          'surgeonId': body['surgeonId'],
          'surgeonName': body['surgeonName'],
          'assistantSurgeonId': body['assistantSurgeonId'],
          'assistantSurgeonName': body['assistantSurgeonName'],
          'anesthesiologistId': body['anesthesiologistId'],
          'anesthesiologistName': body['anesthesiologistName'],
          'nurseIds': body['nurseIds'] != null ? jsonEncode(body['nurseIds']) : null,
          'nurseNames': body['nurseNames'] != null ? jsonEncode(body['nurseNames']) : null,
          'preOperativeNotes': body['preOperativeNotes'] != null ? jsonEncode(body['preOperativeNotes']) : null,
          'operativeNotes': body['operativeNotes'] != null ? jsonEncode(body['operativeNotes']) : null,
          'postOperativeNotes': body['postOperativeNotes'] != null ? jsonEncode(body['postOperativeNotes']) : null,
          'diagnosis': body['diagnosis'],
          'procedure': body['procedure'],
          'notes': body['notes'],
          'equipment': body['equipment'] != null ? jsonEncode(body['equipment']) : null,
          'createdAt': body['createdAt'],
          'updatedAt': body['updatedAt'],
        },
      );

      return ResponseHelper.success(data: {'message': 'Surgery created successfully'});
    } catch (e) {
      AppLogger.error('Create surgery error', e);
      return ResponseHelper.error(message: 'Failed to create surgery: $e');
    }
  }

  Future<Response> _updateSurgery(Request request, String surgeryId) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      final updates = <String, dynamic>{
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      if (body.containsKey('status')) updates['status'] = body['status'];
      if (body.containsKey('startTime')) updates['startTime'] = body['startTime'];
      if (body.containsKey('endTime')) updates['endTime'] = body['endTime'];
      if (body.containsKey('preOperativeNotes')) {
        updates['preOperativeNotes'] = jsonEncode(body['preOperativeNotes']);
      }
      if (body.containsKey('operativeNotes')) {
        updates['operativeNotes'] = jsonEncode(body['operativeNotes']);
      }
      if (body.containsKey('postOperativeNotes')) {
        updates['postOperativeNotes'] = jsonEncode(body['postOperativeNotes']);
      }

      final setClause = updates.keys.map((k) => '$k = @$k').join(', ');

      await conn.execute(
        '''
        UPDATE surgeries 
        SET $setClause
        WHERE id = @id
        ''',
        substitutionValues: {
          'id': surgeryId,
          ...updates,
        },
      );

      return ResponseHelper.success(data: {'message': 'Surgery updated successfully'});
    } catch (e) {
      AppLogger.error('Update surgery error', e);
      return ResponseHelper.error(message: 'Failed to update surgery: $e');
    }
  }

  Future<Response> _deleteSurgery(Request request, String surgeryId) async {
    try {
      final conn = await DatabaseService().connection;

      await conn.execute(
        'DELETE FROM surgeries WHERE id = @id',
        substitutionValues: {'id': surgeryId},
      );

      return ResponseHelper.success(data: {'message': 'Surgery deleted successfully'});
    } catch (e) {
      AppLogger.error('Delete surgery error', e);
      return ResponseHelper.error(message: 'Failed to delete surgery: $e');
    }
  }
}

