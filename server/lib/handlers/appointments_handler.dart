import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';
import '../database/database_service.dart';
import '../utils/response_helper.dart';
import '../logger/app_logger.dart';

class AppointmentsHandler {
  Router get router {
    final router = Router();

    router.get('/', _getAppointments);
    router.get('/<appointmentId>', _getAppointment);
    router.post('/', _createAppointment);
    router.put('/<appointmentId>/status', _updateAppointmentStatus);
    router.put('/<appointmentId>', _updateAppointment);
    router.delete('/<appointmentId>', _deleteAppointment);

    return router;
  }

  Future<Response> _getAppointments(Request request) async {
    try {
      final params = request.url.queryParameters;
      final doctorId = params['doctorId'];
      final patientId = params['patientId'];
      final status = params['status'];

      final conn = await DatabaseService().connection;
      
      String query = '''
        SELECT id, doctor_id, patient_id, patient_name, date, status, type, notes,
               created_at, updated_at
        FROM doctor_appointments
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
      
      query += ' ORDER BY date ASC';

      final appointments = await conn.query(
        query,
        substitutionValues: parameters.isEmpty ? null : parameters,
      );

      final result = appointments.map((apt) => {
        'id': apt[0],
        'doctorId': apt[1],
        'patientId': apt[2],
        'patientName': apt[3],
        'date': apt[4],
        'status': apt[5],
        'type': apt[6],
        'notes': apt[7],
        'createdAt': apt[8],
        'updatedAt': apt[9],
      }).toList();

      return ResponseHelper.list(data: result);
    } catch (e) {
      AppLogger.error('Get appointments error', e);
      return ResponseHelper.error(message: 'Failed to get appointments: $e');
    }
  }

  Future<Response> _getAppointment(Request request, String appointmentId) async {
    try {
      final conn = await DatabaseService().connection;
      
      final appointment = await conn.query(
        '''
        SELECT id, doctor_id, patient_id, patient_name, date, status, type, notes,
               created_at, updated_at
        FROM doctor_appointments
        WHERE id = @id
        ''',
        substitutionValues: {'id': appointmentId},
      );

      if (appointment.isEmpty) {
        return ResponseHelper.error(
          message: 'Appointment not found',
          statusCode: 404,
        );
      }

      final apt = appointment.first;
      return ResponseHelper.success(data: {
        'id': apt[0],
        'doctorId': apt[1],
        'patientId': apt[2],
        'patientName': apt[3],
        'date': apt[4],
        'status': apt[5],
        'type': apt[6],
        'notes': apt[7],
        'createdAt': apt[8],
        'updatedAt': apt[9],
      });
    } catch (e) {
      AppLogger.error('Get appointment error', e);
      return ResponseHelper.error(message: 'Failed to get appointment: $e');
    }
  }

  Future<Response> _createAppointment(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      await conn.execute(
        '''
        INSERT INTO doctor_appointments 
        (id, doctor_id, patient_id, patient_name, date, status, type, notes, created_at, updated_at)
        VALUES (@id, @doctorId, @patientId, @patientName, @date, @status, @type, @notes, @createdAt, @updatedAt)
        ''',
        substitutionValues: {
          'id': body['id'],
          'doctorId': body['doctorId'],
          'patientId': body['patientId'],
          'patientName': body['patientName'],
          'date': body['date'],
          'status': body['status'],
          'type': body['type'],
          'notes': body['notes'],
          'createdAt': body['createdAt'],
          'updatedAt': body['updatedAt'],
        },
      );

      return ResponseHelper.success(data: {'message': 'Appointment created successfully'});
    } catch (e) {
      AppLogger.error('Create appointment error', e);
      return ResponseHelper.error(message: 'Failed to create appointment: $e');
    }
  }

  Future<Response> _updateAppointmentStatus(Request request, String appointmentId) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final status = body['status'] as String;

      final conn = await DatabaseService().connection;
      
      await conn.execute(
        '''
        UPDATE doctor_appointments 
        SET status = @status, updated_at = @updatedAt
        WHERE id = @id
        ''',
        substitutionValues: {
          'id': appointmentId,
          'status': status,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
      );

      return ResponseHelper.success(data: {'message': 'Appointment status updated'});
    } catch (e) {
      AppLogger.error('Update appointment status error', e);
      return ResponseHelper.error(message: 'Failed to update appointment status: $e');
    }
  }

  Future<Response> _updateAppointment(Request request, String appointmentId) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      // تحويل camelCase إلى snake_case
      String toSnakeCase(String camelCase) {
        // إذا كان الحقل بالفعل lowercase، لا نحتاج تحويل
        if (camelCase == camelCase.toLowerCase()) {
          return camelCase;
        }
        return camelCase.replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => '_${match.group(1)!.toLowerCase()}',
        );
      }

      final updates = <String, dynamic>{
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };
      
      if (body.containsKey('date')) updates['date'] = body['date'];
      if (body.containsKey('status')) updates['status'] = body['status'];
      if (body.containsKey('patientName')) updates['patientName'] = body['patientName'];
      if (body.containsKey('type')) updates['type'] = body['type'];
      if (body.containsKey('notes')) updates['notes'] = body['notes'];

      // بناء SET clause مع تحويل camelCase إلى snake_case
      final setClause = updates.keys.map((k) {
        final dbColumn = toSnakeCase(k);
        return '$dbColumn = @$k';
      }).join(', ');
      
      await conn.execute(
        '''
        UPDATE doctor_appointments 
        SET $setClause
        WHERE id = @id
        ''',
        substitutionValues: {
          'id': appointmentId,
          ...updates,
        },
      );

      return ResponseHelper.success(data: {'message': 'Appointment updated successfully'});
    } catch (e) {
      AppLogger.error('Update appointment error', e);
      return ResponseHelper.error(message: 'Failed to update appointment: $e');
    }
  }

  Future<Response> _deleteAppointment(Request request, String appointmentId) async {
    try {
      final conn = await DatabaseService().connection;
      
      await conn.execute(
        'DELETE FROM doctor_appointments WHERE id = @id',
        substitutionValues: {'id': appointmentId},
      );

      return ResponseHelper.success(data: {'message': 'Appointment deleted successfully'});
    } catch (e) {
      AppLogger.error('Delete appointment error', e);
      return ResponseHelper.error(message: 'Failed to delete appointment: $e');
    }
  }
}

