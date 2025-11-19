import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';
import '../database/database_service.dart';
import '../utils/response_helper.dart';
import '../logger/app_logger.dart';

class HospitalPharmacyHandler {
  Router get router {
    final router = Router();

    router.get('/dispenses', _getDispenses);
    router.get('/dispenses/<dispenseId>', _getDispense);
    router.post('/dispenses', _createDispense);
    router.put('/dispenses/<dispenseId>', _updateDispense);
    router.delete('/dispenses/<dispenseId>', _deleteDispense);

    router.get('/schedules', _getSchedules);
    router.get('/schedules/<scheduleId>', _getSchedule);
    router.post('/schedules', _createSchedule);
    router.put('/schedules/<scheduleId>', _updateSchedule);
    router.delete('/schedules/<scheduleId>', _deleteSchedule);

    return router;
  }

  Future<Response> _getDispenses(Request request) async {
    try {
      final params = request.url.queryParameters;
      final patientId = params['patientId'];
      final status = params['status'];
      final from = params['from'];
      final to = params['to'];

      final conn = await DatabaseService().connection;

      String query = '''
        SELECT id, patient_id, patient_name, bed_id, room_id, prescription_id,
               medication_id, medication_name, dosage, frequency, quantity,
               status, schedule_type, scheduled_time, dispensed_at, dispensed_by,
               notes, created_at, updated_at
        FROM hospital_pharmacy_dispenses
        WHERE 1=1
      ''';

      final parameters = <String, dynamic>{};

      if (patientId != null) {
        query += ' AND patient_id = @patientId';
        parameters['patientId'] = patientId;
      }
      if (status != null) {
        query += ' AND status = @status';
        parameters['status'] = status;
      }
      if (from != null) {
        query += ' AND scheduled_time >= @from';
        parameters['from'] = int.parse(from);
      }
      if (to != null) {
        query += ' AND scheduled_time <= @to';
        parameters['to'] = int.parse(to);
      }

      query += ' ORDER BY scheduled_time ASC';

      final dispenses = await conn.query(
        query,
        substitutionValues: parameters.isEmpty ? null : parameters,
      );

      final result = dispenses.map((d) => {
        'id': d[0],
        'patientId': d[1],
        'patientName': d[2],
        'bedId': d[3],
        'roomId': d[4],
        'prescriptionId': d[5],
        'medicationId': d[6],
        'medicationName': d[7],
        'dosage': d[8],
        'frequency': d[9],
        'quantity': d[10],
        'status': d[11],
        'scheduleType': d[12],
        'scheduledTime': d[13],
        'dispensedAt': d[14],
        'dispensedBy': d[15],
        'notes': d[16],
        'createdAt': d[17],
        'updatedAt': d[18],
      }).toList();

      return ResponseHelper.list(data: result);
    } catch (e) {
      AppLogger.error('Get dispenses error', e);
      return ResponseHelper.error(message: 'Failed to get dispenses: $e');
    }
  }

  Future<Response> _getDispense(Request request, String dispenseId) async {
    try {
      final conn = await DatabaseService().connection;

      final result = await conn.query(
        '''
        SELECT id, patient_id, patient_name, bed_id, room_id, prescription_id,
               medication_id, medication_name, dosage, frequency, quantity,
               status, schedule_type, scheduled_time, dispensed_at, dispensed_by,
               notes, created_at, updated_at
        FROM hospital_pharmacy_dispenses
        WHERE id = @id
        ''',
        substitutionValues: {'id': dispenseId},
      );

      if (result.isEmpty) {
        return ResponseHelper.error(message: 'Dispense not found', statusCode: 404);
      }

      final d = result.first;
      return ResponseHelper.success(data: {
        'id': d[0],
        'patientId': d[1],
        'patientName': d[2],
        'bedId': d[3],
        'roomId': d[4],
        'prescriptionId': d[5],
        'medicationId': d[6],
        'medicationName': d[7],
        'dosage': d[8],
        'frequency': d[9],
        'quantity': d[10],
        'status': d[11],
        'scheduleType': d[12],
        'scheduledTime': d[13],
        'dispensedAt': d[14],
        'dispensedBy': d[15],
        'notes': d[16],
        'createdAt': d[17],
        'updatedAt': d[18],
      });
    } catch (e) {
      AppLogger.error('Get dispense error', e);
      return ResponseHelper.error(message: 'Failed to get dispense: $e');
    }
  }

  Future<Response> _createDispense(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      await conn.execute(
        '''
        INSERT INTO hospital_pharmacy_dispenses 
        (id, patient_id, patient_name, bed_id, room_id, prescription_id,
         medication_id, medication_name, dosage, frequency, quantity,
         status, schedule_type, scheduled_time, dispensed_at, dispensed_by,
         notes, created_at, updated_at)
        VALUES 
        (@id, @patientId, @patientName, @bedId, @roomId, @prescriptionId,
         @medicationId, @medicationName, @dosage, @frequency, @quantity,
         @status, @scheduleType, @scheduledTime, @dispensedAt, @dispensedBy,
         @notes, @createdAt, @updatedAt)
        ''',
        substitutionValues: {
          'id': body['id'],
          'patientId': body['patientId'],
          'patientName': body['patientName'],
          'bedId': body['bedId'],
          'roomId': body['roomId'],
          'prescriptionId': body['prescriptionId'],
          'medicationId': body['medicationId'],
          'medicationName': body['medicationName'],
          'dosage': body['dosage'],
          'frequency': body['frequency'],
          'quantity': body['quantity'],
          'status': body['status'],
          'scheduleType': body['scheduleType'],
          'scheduledTime': body['scheduledTime'],
          'dispensedAt': body['dispensedAt'],
          'dispensedBy': body['dispensedBy'],
          'notes': body['notes'],
          'createdAt': body['createdAt'],
          'updatedAt': body['updatedAt'],
        },
      );

      return ResponseHelper.success(data: {'message': 'Dispense created successfully'});
    } catch (e) {
      AppLogger.error('Create dispense error', e);
      return ResponseHelper.error(message: 'Failed to create dispense: $e');
    }
  }

  Future<Response> _updateDispense(Request request, String dispenseId) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      final updates = <String, dynamic>{
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      if (body.containsKey('status')) updates['status'] = body['status'];
      if (body.containsKey('dispensedAt')) updates['dispensed_at'] = body['dispensedAt'];
      if (body.containsKey('dispensedBy')) updates['dispensed_by'] = body['dispensedBy'];
      if (body.containsKey('notes')) updates['notes'] = body['notes'];

      final setClause = updates.keys.map((k) => '$k = @$k').join(', ');

      await conn.execute(
        '''
        UPDATE hospital_pharmacy_dispenses 
        SET $setClause
        WHERE id = @id
        ''',
        substitutionValues: {
          'id': dispenseId,
          ...updates,
        },
      );

      return ResponseHelper.success(data: {'message': 'Dispense updated successfully'});
    } catch (e) {
      AppLogger.error('Update dispense error', e);
      return ResponseHelper.error(message: 'Failed to update dispense: $e');
    }
  }

  Future<Response> _deleteDispense(Request request, String dispenseId) async {
    try {
      final conn = await DatabaseService().connection;

      await conn.execute(
        'DELETE FROM hospital_pharmacy_dispenses WHERE id = @id',
        substitutionValues: {'id': dispenseId},
      );

      return ResponseHelper.success(data: {'message': 'Dispense deleted successfully'});
    } catch (e) {
      AppLogger.error('Delete dispense error', e);
      return ResponseHelper.error(message: 'Failed to delete dispense: $e');
    }
  }

  Future<Response> _getSchedules(Request request) async {
    try {
      final params = request.url.queryParameters;
      final patientId = params['patientId'];
      final isActive = params['isActive'];

      final conn = await DatabaseService().connection;

      String query = '''
        SELECT id, patient_id, patient_name, bed_id, room_id, prescription_id,
               medication_id, medication_name, dosage, frequency, quantity,
               schedule_type, start_date, end_date, scheduled_times, is_active,
               notes, created_at, updated_at
        FROM medication_schedules
        WHERE 1=1
      ''';

      final parameters = <String, dynamic>{};

      if (patientId != null) {
        query += ' AND patient_id = @patientId';
        parameters['patientId'] = patientId;
      }
      if (isActive != null) {
        query += ' AND is_active = @isActive';
        parameters['isActive'] = isActive.toLowerCase() == 'true';
      }

      query += ' ORDER BY start_date DESC';

      final schedules = await conn.query(
        query,
        substitutionValues: parameters.isEmpty ? null : parameters,
      );

      final result = schedules.map((s) {
        List<dynamic> scheduledTimes = [];
        if (s[14] != null) {
          try {
            scheduledTimes = jsonDecode(s[14] as String) as List;
          } catch (_) {}
        }

        return {
          'id': s[0],
          'patientId': s[1],
          'patientName': s[2],
          'bedId': s[3],
          'roomId': s[4],
          'prescriptionId': s[5],
          'medicationId': s[6],
          'medicationName': s[7],
          'dosage': s[8],
          'frequency': s[9],
          'quantity': s[10],
          'scheduleType': s[11],
          'startDate': s[12],
          'endDate': s[13],
          'scheduledTimes': scheduledTimes,
          'isActive': s[15],
          'notes': s[16],
          'createdAt': s[17],
          'updatedAt': s[18],
        };
      }).toList();

      return ResponseHelper.list(data: result);
    } catch (e) {
      AppLogger.error('Get schedules error', e);
      return ResponseHelper.error(message: 'Failed to get schedules: $e');
    }
  }

  Future<Response> _getSchedule(Request request, String scheduleId) async {
    try {
      final conn = await DatabaseService().connection;

      final result = await conn.query(
        '''
        SELECT id, patient_id, patient_name, bed_id, room_id, prescription_id,
               medication_id, medication_name, dosage, frequency, quantity,
               schedule_type, start_date, end_date, scheduled_times, is_active,
               notes, created_at, updated_at
        FROM medication_schedules
        WHERE id = @id
        ''',
        substitutionValues: {'id': scheduleId},
      );

      if (result.isEmpty) {
        return ResponseHelper.error(message: 'Schedule not found', statusCode: 404);
      }

      final s = result.first;
      List<dynamic> scheduledTimes = [];
      if (s[14] != null) {
        try {
          scheduledTimes = jsonDecode(s[14] as String) as List;
        } catch (_) {}
      }

      return ResponseHelper.success(data: {
        'id': s[0],
        'patientId': s[1],
        'patientName': s[2],
        'bedId': s[3],
        'roomId': s[4],
        'prescriptionId': s[5],
        'medicationId': s[6],
        'medicationName': s[7],
        'dosage': s[8],
        'frequency': s[9],
        'quantity': s[10],
        'scheduleType': s[11],
        'startDate': s[12],
        'endDate': s[13],
        'scheduledTimes': scheduledTimes,
        'isActive': s[15],
        'notes': s[16],
        'createdAt': s[17],
        'updatedAt': s[18],
      });
    } catch (e) {
      AppLogger.error('Get schedule error', e);
      return ResponseHelper.error(message: 'Failed to get schedule: $e');
    }
  }

  Future<Response> _createSchedule(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      await conn.execute(
        '''
        INSERT INTO medication_schedules 
        (id, patient_id, patient_name, bed_id, room_id, prescription_id,
         medication_id, medication_name, dosage, frequency, quantity,
         schedule_type, start_date, end_date, scheduled_times, is_active,
         notes, created_at, updated_at)
        VALUES 
        (@id, @patientId, @patientName, @bedId, @roomId, @prescriptionId,
         @medicationId, @medicationName, @dosage, @frequency, @quantity,
         @scheduleType, @startDate, @endDate, @scheduledTimes, @isActive,
         @notes, @createdAt, @updatedAt)
        ''',
        substitutionValues: {
          'id': body['id'],
          'patientId': body['patientId'],
          'patientName': body['patientName'],
          'bedId': body['bedId'],
          'roomId': body['roomId'],
          'prescriptionId': body['prescriptionId'],
          'medicationId': body['medicationId'],
          'medicationName': body['medicationName'],
          'dosage': body['dosage'],
          'frequency': body['frequency'],
          'quantity': body['quantity'],
          'scheduleType': body['scheduleType'],
          'startDate': body['startDate'],
          'endDate': body['endDate'],
          'scheduledTimes': jsonEncode(body['scheduledTimes']),
          'isActive': body['isActive'] ?? true,
          'notes': body['notes'],
          'createdAt': body['createdAt'],
          'updatedAt': body['updatedAt'],
        },
      );

      return ResponseHelper.success(data: {'message': 'Schedule created successfully'});
    } catch (e) {
      AppLogger.error('Create schedule error', e);
      return ResponseHelper.error(message: 'Failed to create schedule: $e');
    }
  }

  Future<Response> _updateSchedule(Request request, String scheduleId) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      final updates = <String, dynamic>{
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      if (body.containsKey('isActive')) updates['is_active'] = body['isActive'];
      if (body.containsKey('endDate')) updates['end_date'] = body['endDate'];
      if (body.containsKey('notes')) updates['notes'] = body['notes'];

      final setClause = updates.keys.map((k) => '$k = @$k').join(', ');

      await conn.execute(
        '''
        UPDATE medication_schedules 
        SET $setClause
        WHERE id = @id
        ''',
        substitutionValues: {
          'id': scheduleId,
          ...updates,
        },
      );

      return ResponseHelper.success(data: {'message': 'Schedule updated successfully'});
    } catch (e) {
      AppLogger.error('Update schedule error', e);
      return ResponseHelper.error(message: 'Failed to update schedule: $e');
    }
  }

  Future<Response> _deleteSchedule(Request request, String scheduleId) async {
    try {
      final conn = await DatabaseService().connection;

      await conn.execute(
        'DELETE FROM medication_schedules WHERE id = @id',
        substitutionValues: {'id': scheduleId},
      );

      return ResponseHelper.success(data: {'message': 'Schedule deleted successfully'});
    } catch (e) {
      AppLogger.error('Delete schedule error', e);
      return ResponseHelper.error(message: 'Failed to delete schedule: $e');
    }
  }
}

