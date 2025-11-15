import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';
import '../database/database_service.dart';
import '../utils/response_helper.dart';
import '../logger/app_logger.dart';

class RoomsHandler {
  Router get router {
    final router = Router();

    // Rooms
    router.get('/rooms', _getRooms);
    router.get('/rooms/<roomId>', _getRoom);
    router.post('/rooms', _createRoom);
    router.put('/rooms/<roomId>', _updateRoom);
    router.delete('/rooms/<roomId>', _deleteRoom);

    // Beds
    router.get('/beds', _getBeds);
    router.get('/beds/<bedId>', _getBed);
    router.post('/beds', _createBed);
    router.put('/beds/<bedId>', _updateBed);
    router.put('/beds/<bedId>/assign', _assignBed);
    router.put('/beds/<bedId>/release', _releaseBed);
    router.delete('/beds/<bedId>', _deleteBed);

    // Transfers
    router.get('/transfers', _getTransfers);
    router.post('/transfers', _createTransfer);

    return router;
  }

  // Rooms
  Future<Response> _getRooms(Request request) async {
    try {
      final conn = await DatabaseService().connection;
      final rows = await conn.query('''
        SELECT id, name, type, floor, notes, created_at, updated_at
        FROM rooms ORDER BY name ASC
      ''');
      final data = rows.map((r) => {
        'id': r[0],
        'name': r[1],
        'type': r[2],
        'floor': r[3],
        'notes': r[4],
        'createdAt': r[5],
        'updatedAt': r[6],
      }).toList();
      return ResponseHelper.list(data: data);
    } catch (e) {
      AppLogger.error('Get rooms error', e);
      return ResponseHelper.error(message: 'Failed to get rooms: $e');
    }
  }

  Future<Response> _getRoom(Request request, String roomId) async {
    try {
      final conn = await DatabaseService().connection;
      final rows = await conn.query(
        'SELECT id, name, type, floor, notes, created_at, updated_at FROM rooms WHERE id = @id',
        substitutionValues: {'id': roomId},
      );
      if (rows.isEmpty) return ResponseHelper.error(message: 'Room not found', statusCode: 404);
      final r = rows.first;
      final data = {
        'id': r[0],
        'name': r[1],
        'type': r[2],
        'floor': r[3],
        'notes': r[4],
        'createdAt': r[5],
        'updatedAt': r[6],
      };
      return ResponseHelper.success(data: data);
    } catch (e) {
      AppLogger.error('Get room error', e);
      return ResponseHelper.error(message: 'Failed to get room: $e');
    }
  }

  Future<Response> _createRoom(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;
      await conn.execute(
        '''
        INSERT INTO rooms (id, name, type, floor, notes, created_at, updated_at)
        VALUES (@id, @name, @type, @floor, @notes, @createdAt, @updatedAt)
        ''',
        substitutionValues: {
          'id': body['id'],
          'name': body['name'],
          'type': body['type'],
          'floor': body['floor'],
          'notes': body['notes'],
          'createdAt': body['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
          'updatedAt': body['updatedAt'],
        },
      );
      return ResponseHelper.success(data: {'message': 'Room created'});
    } catch (e) {
      AppLogger.error('Create room error', e);
      return ResponseHelper.error(message: 'Failed to create room: $e');
    }
  }

  Future<Response> _updateRoom(Request request, String roomId) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;
      final fields = <String>[];
      final values = <String, dynamic>{'id': roomId};
      void setField(String key, dynamic val) {
        fields.add('$key = @$key');
        values[key] = val;
      }
      if (body.containsKey('name')) setField('name', body['name']);
      if (body.containsKey('type')) setField('type', body['type']);
      if (body.containsKey('floor')) setField('floor', body['floor']);
      if (body.containsKey('notes')) setField('notes', body['notes']);
      setField('updated_at', DateTime.now().millisecondsSinceEpoch);

      if (fields.isEmpty) return ResponseHelper.success(data: {'message': 'Nothing to update'});

      await conn.execute('UPDATE rooms SET ${fields.join(', ')} WHERE id = @id', substitutionValues: values);
      return ResponseHelper.success(data: {'message': 'Room updated'});
    } catch (e) {
      AppLogger.error('Update room error', e);
      return ResponseHelper.error(message: 'Failed to update room: $e');
    }
  }

  Future<Response> _deleteRoom(Request request, String roomId) async {
    try {
      final conn = await DatabaseService().connection;
      await conn.execute('DELETE FROM rooms WHERE id = @id', substitutionValues: {'id': roomId});
      return ResponseHelper.success(data: {'message': 'Room deleted'});
    } catch (e) {
      AppLogger.error('Delete room error', e);
      return ResponseHelper.error(message: 'Failed to delete room: $e');
    }
  }

  // Beds
  Future<Response> _getBeds(Request request) async {
    try {
      final params = request.url.queryParameters;
      final roomId = params['roomId'];
      final status = params['status'];
      final conn = await DatabaseService().connection;

      String query = '''
        SELECT id, room_id, label, status, patient_id, occupied_since, updated_at
        FROM beds WHERE 1=1
      ''';
      final values = <String, dynamic>{};
      if (roomId != null) {
        query += ' AND room_id = @roomId';
        values['roomId'] = roomId;
      }
      if (status != null) {
        query += ' AND status = @status';
        values['status'] = status;
      }
      query += ' ORDER BY label ASC';

      final rows = await conn.query(query, substitutionValues: values.isEmpty ? null : values);
      final data = rows.map((r) => {
        'id': r[0],
        'roomId': r[1],
        'label': r[2],
        'status': r[3],
        'patientId': r[4],
        'occupiedSince': r[5],
        'updatedAt': r[6],
      }).toList();
      return ResponseHelper.list(data: data);
    } catch (e) {
      AppLogger.error('Get beds error', e);
      return ResponseHelper.error(message: 'Failed to get beds: $e');
    }
  }

  Future<Response> _getBed(Request request, String bedId) async {
    try {
      final conn = await DatabaseService().connection;
      final rows = await conn.query('''
        SELECT id, room_id, label, status, patient_id, occupied_since, updated_at
        FROM beds WHERE id = @id
      ''', substitutionValues: {'id': bedId});
      if (rows.isEmpty) return ResponseHelper.error(message: 'Bed not found', statusCode: 404);
      final r = rows.first;
      final data = {
        'id': r[0],
        'roomId': r[1],
        'label': r[2],
        'status': r[3],
        'patientId': r[4],
        'occupiedSince': r[5],
        'updatedAt': r[6],
      };
      return ResponseHelper.success(data: data);
    } catch (e) {
      AppLogger.error('Get bed error', e);
      return ResponseHelper.error(message: 'Failed to get bed: $e');
    }
  }

  Future<Response> _createBed(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;
      await conn.execute(
        '''
        INSERT INTO beds (id, room_id, label, status, patient_id, occupied_since, updated_at)
        VALUES (@id, @roomId, @label, @status, @patientId, @occupiedSince, @updatedAt)
        ''',
        substitutionValues: {
          'id': body['id'],
          'roomId': body['roomId'],
          'label': body['label'],
          'status': body['status'] ?? 'available',
          'patientId': body['patientId'],
          'occupiedSince': body['occupiedSince'],
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
      );
      return ResponseHelper.success(data: {'message': 'Bed created'});
    } catch (e) {
      AppLogger.error('Create bed error', e);
      return ResponseHelper.error(message: 'Failed to create bed: $e');
    }
  }

  Future<Response> _updateBed(Request request, String bedId) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;
      final fields = <String>[];
      final values = <String, dynamic>{'id': bedId};
      void setField(String key, dynamic val) {
        fields.add('$key = @$key');
        values[key] = val;
      }
      if (body.containsKey('label')) setField('label', body['label']);
      if (body.containsKey('status')) setField('status', body['status']);
      if (body.containsKey('patientId')) setField('patient_id', body['patientId']);
      if (body.containsKey('occupiedSince')) setField('occupied_since', body['occupiedSince']);
      setField('updated_at', DateTime.now().millisecondsSinceEpoch);

      if (fields.isEmpty) return ResponseHelper.success(data: {'message': 'Nothing to update'});

      await conn.execute('UPDATE beds SET ${fields.join(', ')} WHERE id = @id', substitutionValues: values);
      return ResponseHelper.success(data: {'message': 'Bed updated'});
    } catch (e) {
      AppLogger.error('Update bed error', e);
      return ResponseHelper.error(message: 'Failed to update bed: $e');
    }
  }

  Future<Response> _assignBed(Request request, String bedId) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final patientId = body['patientId'] as String;
      final conn = await DatabaseService().connection;

      await conn.execute(
        '''
        UPDATE beds 
        SET status = 'occupied', patient_id = @patientId, occupied_since = @since, updated_at = @since
        WHERE id = @id
        ''',
        substitutionValues: {
          'id': bedId,
          'patientId': patientId,
          'since': DateTime.now().millisecondsSinceEpoch,
        },
      );

      return ResponseHelper.success(data: {'message': 'Bed assigned'});
    } catch (e) {
      AppLogger.error('Assign bed error', e);
      return ResponseHelper.error(message: 'Failed to assign bed: $e');
    }
  }

  Future<Response> _releaseBed(Request request, String bedId) async {
    try {
      final conn = await DatabaseService().connection;
      await conn.execute(
        '''
        UPDATE beds 
        SET status = 'available', patient_id = NULL, occupied_since = NULL, updated_at = @updatedAt
        WHERE id = @id
        ''',
        substitutionValues: {
          'id': bedId,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
      );
      return ResponseHelper.success(data: {'message': 'Bed released'});
    } catch (e) {
      AppLogger.error('Release bed error', e);
      return ResponseHelper.error(message: 'Failed to release bed: $e');
    }
  }

  Future<Response> _deleteBed(Request request, String bedId) async {
    try {
      final conn = await DatabaseService().connection;
      await conn.execute('DELETE FROM beds WHERE id = @id', substitutionValues: {'id': bedId});
      return ResponseHelper.success(data: {'message': 'Bed deleted'});
    } catch (e) {
      AppLogger.error('Delete bed error', e);
      return ResponseHelper.error(message: 'Failed to delete bed: $e');
    }
  }

  // Transfers
  Future<Response> _getTransfers(Request request) async {
    try {
      final params = request.url.queryParameters;
      final patientId = params['patientId'];
      final conn = await DatabaseService().connection;
      String query = '''
        SELECT id, patient_id, from_bed_id, to_bed_id, reason, created_at
        FROM bed_transfers WHERE 1=1
      ''';
      final values = <String, dynamic>{};
      if (patientId != null) {
        query += ' AND patient_id = @patientId';
        values['patientId'] = patientId;
      }
      query += ' ORDER BY created_at DESC';
      final rows = await conn.query(query, substitutionValues: values.isEmpty ? null : values);
      final data = rows.map((r) => {
        'id': r[0],
        'patientId': r[1],
        'fromBedId': r[2],
        'toBedId': r[3],
        'reason': r[4],
        'createdAt': r[5],
      }).toList();
      return ResponseHelper.list(data: data);
    } catch (e) {
      AppLogger.error('Get transfers error', e);
      return ResponseHelper.error(message: 'Failed to get transfers: $e');
    }
  }

  Future<Response> _createTransfer(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      await conn.execute(
        '''
        INSERT INTO bed_transfers (id, patient_id, from_bed_id, to_bed_id, reason, created_at)
        VALUES (@id, @patientId, @fromBedId, @toBedId, @reason, @createdAt)
        ''',
        substitutionValues: {
          'id': body['id'],
          'patientId': body['patientId'],
          'fromBedId': body['fromBedId'],
          'toBedId': body['toBedId'],
          'reason': body['reason'],
          'createdAt': body['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
        },
      );

      // تحديث حالة السريرين: تحرير السابق، إشغال الجديد
      final now = DateTime.now().millisecondsSinceEpoch;
      if (body['fromBedId'] != null) {
        await conn.execute(
          '''
          UPDATE beds SET status = 'available', patient_id = NULL, occupied_since = NULL, updated_at = @now
          WHERE id = @fromId
          ''',
          substitutionValues: {'fromId': body['fromBedId'], 'now': now},
        );
      }
      await conn.execute(
        '''
        UPDATE beds SET status = 'occupied', patient_id = @patientId, occupied_since = @now, updated_at = @now
        WHERE id = @toId
        ''',
        substitutionValues: {'toId': body['toBedId'], 'patientId': body['patientId'], 'now': now},
      );

      return ResponseHelper.success(data: {'message': 'Transfer created'});
    } catch (e) {
      AppLogger.error('Create transfer error', e);
      return ResponseHelper.error(message: 'Failed to create transfer: $e');
    }
  }
}


