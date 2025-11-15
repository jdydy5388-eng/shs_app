import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';
import '../database/database_service.dart';
import '../utils/response_helper.dart';
import '../logger/app_logger.dart';
import '../utils/auth_guard.dart';
import '../utils/rbac.dart';

class AttendanceHandler {
  Router get router {
    final router = Router();

    // Attendance
    router.get('/attendance', _getAttendance);
    router.post('/attendance', _createAttendance);
    router.put('/attendance/<id>', _updateAttendance);

    // Shifts
    router.get('/shifts', _getShifts);
    router.post('/shifts', _createShift);
    router.put('/shifts/<id>', _updateShift);
    router.delete('/shifts/<id>', _deleteShift);

    return router;
  }

  Future<Response> _getAttendance(Request request) async {
    try {
      final user = getRequestUser(request);
      if (!isAuthenticated(user)) return Response.forbidden('Unauthorized');
      if (!(user.isAdmin || Rbac.has(user.role, Permission.readAttendance))) {
        // يمكن السماح للمستخدم بقراءة سجلاته فقط حتى دون تصريح عام
      }
      final params = request.url.queryParameters;
      String? userId = params['userId'];
      final from = int.tryParse(params['from'] ?? '');
      final to = int.tryParse(params['to'] ?? '');
      final conn = await DatabaseService().connection;

      String query = '''
        SELECT id, user_id, role, check_in, check_out, location_lat, location_lng, notes, created_at
        FROM attendance_records WHERE 1=1
      ''';
      final values = <String, dynamic>{};
      if (!user.isAdmin) {
        userId = userId ?? user.id;
      }
      if (userId != null) { query += ' AND user_id = @userId'; values['userId'] = userId; }
      if (from != null) { query += ' AND check_in >= @from'; values['from'] = from; }
      if (to != null) { query += ' AND check_in <= @to'; values['to'] = to; }
      query += ' ORDER BY check_in DESC';

      final rows = await conn.query(query, substitutionValues: values.isEmpty ? null : values);
      final data = rows.map((r) => {
        'id': r[0], 'userId': r[1], 'role': r[2], 'checkIn': r[3], 'checkOut': r[4],
        'locationLat': r[5], 'locationLng': r[6], 'notes': r[7], 'createdAt': r[8],
      }).toList();
      return ResponseHelper.list(data: data);
    } catch (e) {
      AppLogger.error('Get attendance error', e);
      return ResponseHelper.error(message: 'Failed to get attendance: $e');
    }
  }

  Future<Response> _createAttendance(Request request) async {
    try {
      final user = getRequestUser(request);
      if (!isAuthenticated(user)) return Response.forbidden('Unauthorized');
      if (!(user.isAdmin || Rbac.has(user.role, Permission.writeAttendance))) {
        // السماح للمستخدم بإنشاء سجله فقط
      }
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;
      if (!user.isAdmin) {
        if (body['userId'] != user.id) return Response.forbidden('Unauthorized');
      }
      await conn.execute(
        '''
        INSERT INTO attendance_records (id, user_id, role, check_in, check_out, location_lat, location_lng, notes, created_at)
        VALUES (@id, @userId, @role, @checkIn, @checkOut, @locationLat, @locationLng, @notes, @createdAt)
        ''',
        substitutionValues: {
          'id': body['id'],
          'userId': body['userId'],
          'role': body['role'],
          'checkIn': body['checkIn'],
          'checkOut': body['checkOut'],
          'locationLat': body['locationLat'],
          'locationLng': body['locationLng'],
          'notes': body['notes'],
          'createdAt': body['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
        },
      );
      return ResponseHelper.success(data: {'message': 'Attendance record created'});
    } catch (e) {
      AppLogger.error('Create attendance error', e);
      return ResponseHelper.error(message: 'Failed to create attendance record: $e');
    }
  }

  Future<Response> _updateAttendance(Request request, String id) async {
    try {
      final user = getRequestUser(request);
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;
      if (!user.isAdmin) {
        final owns = await conn.query('SELECT 1 FROM attendance_records WHERE id=@id AND user_id=@uid LIMIT 1',
            substitutionValues: {'id': id, 'uid': user.id});
        if (owns.isEmpty) return Response.forbidden('Unauthorized');
      }
      final fields = <String>[];
      final values = <String, dynamic>{'id': id};
      void setField(String key, dynamic val) { fields.add('$key = @$key'); values[key] = val; }
      if (body.containsKey('checkOut')) setField('check_out', body['checkOut']);
      if (body.containsKey('locationLat')) setField('location_lat', body['locationLat']);
      if (body.containsKey('locationLng')) setField('location_lng', body['locationLng']);
      if (body.containsKey('notes')) setField('notes', body['notes']);
      if (fields.isEmpty) return ResponseHelper.success(data: {'message': 'Nothing to update'});
      await conn.execute('UPDATE attendance_records SET ${fields.join(', ')} WHERE id = @id', substitutionValues: values);
      return ResponseHelper.success(data: {'message': 'Attendance updated'});
    } catch (e) {
      AppLogger.error('Update attendance error', e);
      return ResponseHelper.error(message: 'Failed to update attendance: $e');
    }
  }

  Future<Response> _getShifts(Request request) async {
    try {
      final user = getRequestUser(request);
      if (!isAuthenticated(user)) return Response.forbidden('Unauthorized');
      final params = request.url.queryParameters;
      String? userId = params['userId'];
      final conn = await DatabaseService().connection;
      String query = '''
        SELECT id, user_id, role, start_time, end_time, department, recurrence, created_at
        FROM shifts WHERE 1=1
      ''';
      final values = <String, dynamic>{};
      if (!user.isAdmin) {
        userId = userId ?? user.id;
      }
      if (userId != null) { query += ' AND user_id = @userId'; values['userId'] = userId; }
      query += ' ORDER BY start_time DESC';

      final rows = await conn.query(query, substitutionValues: values.isEmpty ? null : values);
      final data = rows.map((r) => {
        'id': r[0], 'userId': r[1], 'role': r[2], 'startTime': r[3], 'endTime': r[4],
        'department': r[5], 'recurrence': r[6], 'createdAt': r[7],
      }).toList();
      return ResponseHelper.list(data: data);
    } catch (e) {
      AppLogger.error('Get shifts error', e);
      return ResponseHelper.error(message: 'Failed to get shifts: $e');
    }
  }

  Future<Response> _createShift(Request request) async {
    try {
      final user = getRequestUser(request);
      if (!(user.isAdmin || Rbac.has(user.role, Permission.manageShifts))) {
        return Response.forbidden('Unauthorized');
      }
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;
      await conn.execute(
        '''
        INSERT INTO shifts (id, user_id, role, start_time, end_time, department, recurrence, created_at)
        VALUES (@id, @userId, @role, @startTime, @endTime, @department, @recurrence, @createdAt)
        ''',
        substitutionValues: {
          'id': body['id'],
          'userId': body['userId'],
          'role': body['role'],
          'startTime': body['startTime'],
          'endTime': body['endTime'],
          'department': body['department'],
          'recurrence': body['recurrence'],
          'createdAt': body['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
        },
      );
      return ResponseHelper.success(data: {'message': 'Shift created'});
    } catch (e) {
      AppLogger.error('Create shift error', e);
      return ResponseHelper.error(message: 'Failed to create shift: $e');
    }
  }

  Future<Response> _updateShift(Request request, String id) async {
    try {
      final user = getRequestUser(request);
      if (!(user.isAdmin || Rbac.has(user.role, Permission.manageShifts))) {
        return Response.forbidden('Unauthorized');
      }
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;
      final fields = <String>[];
      final values = <String, dynamic>{'id': id};
      void setField(String key, dynamic val) { fields.add('$key = @$key'); values[key] = val; }
      if (body.containsKey('startTime')) setField('start_time', body['startTime']);
      if (body.containsKey('endTime')) setField('end_time', body['endTime']);
      if (body.containsKey('department')) setField('department', body['department']);
      if (body.containsKey('recurrence')) setField('recurrence', body['recurrence']);
      if (fields.isEmpty) return ResponseHelper.success(data: {'message': 'Nothing to update'});
      await conn.execute('UPDATE shifts SET ${fields.join(', ')} WHERE id = @id', substitutionValues: values);
      return ResponseHelper.success(data: {'message': 'Shift updated'});
    } catch (e) {
      AppLogger.error('Update shift error', e);
      return ResponseHelper.error(message: 'Failed to update shift: $e');
    }
  }

  Future<Response> _deleteShift(Request request, String id) async {
    try {
      final user = getRequestUser(request);
      if (!(user.isAdmin || Rbac.has(user.role, Permission.manageShifts))) {
        return Response.forbidden('Unauthorized');
      }
      final conn = await DatabaseService().connection;
      await conn.execute('DELETE FROM shifts WHERE id = @id', substitutionValues: {'id': id});
      return ResponseHelper.success(data: {'message': 'Shift deleted'});
    } catch (e) {
      AppLogger.error('Delete shift error', e);
      return ResponseHelper.error(message: 'Failed to delete shift: $e');
    }
  }
}


