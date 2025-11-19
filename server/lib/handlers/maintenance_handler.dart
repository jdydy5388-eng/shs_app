import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';
import '../database/database_service.dart';
import '../utils/response_helper.dart';
import '../logger/app_logger.dart';

class MaintenanceHandler {
  Router get router {
    final router = Router();

    router.get('/', _getRecords);
    router.get('/<recordId>', _getRecord);
    router.post('/', _createRecord);
    router.put('/<recordId>', _updateRecord);
    router.delete('/<recordId>', _deleteRecord);

    return router;
  }

  Future<Response> _getRecords(Request request) async {
    try {
      final params = request.url.queryParameters;
      final equipmentId = params['equipmentId'];

      final conn = await DatabaseService().connection;

      String query = '''
        SELECT id, equipment_id, equipment_name, maintenance_date, maintenance_type,
               description, performed_by, cost, next_maintenance_date, created_at
        FROM maintenance_records
        WHERE 1=1
      ''';

      final parameters = <String, dynamic>{};

      if (equipmentId != null) {
        query += ' AND equipment_id = @equipmentId';
        parameters['equipmentId'] = equipmentId;
      }

      query += ' ORDER BY maintenance_date DESC';

      final records = await conn.query(
        query,
        substitutionValues: parameters.isEmpty ? null : parameters,
      );

      final result = records.map((r) => {
        'id': r[0],
        'equipmentId': r[1],
        'equipmentName': r[2],
        'maintenanceDate': r[3],
        'maintenanceType': r[4],
        'description': r[5],
        'performedBy': r[6],
        'cost': r[7],
        'nextMaintenanceDate': r[8],
        'createdAt': r[9],
      }).toList();

      return ResponseHelper.list(data: result);
    } catch (e) {
      AppLogger.error('Get maintenance records error', e);
      return ResponseHelper.error(message: 'Failed to get records: $e');
    }
  }

  Future<Response> _getRecord(Request request, String recordId) async {
    try {
      final conn = await DatabaseService().connection;

      final result = await conn.query(
        '''
        SELECT id, equipment_id, equipment_name, maintenance_date, maintenance_type,
               description, performed_by, cost, next_maintenance_date, created_at
        FROM maintenance_records
        WHERE id = @id
        ''',
        substitutionValues: {'id': recordId},
      );

      if (result.isEmpty) {
        return ResponseHelper.error(message: 'Record not found', statusCode: 404);
      }

      final r = result.first;
      return ResponseHelper.success(data: {
        'id': r[0],
        'equipmentId': r[1],
        'equipmentName': r[2],
        'maintenanceDate': r[3],
        'maintenanceType': r[4],
        'description': r[5],
        'performedBy': r[6],
        'cost': r[7],
        'nextMaintenanceDate': r[8],
        'createdAt': r[9],
      });
    } catch (e) {
      AppLogger.error('Get maintenance record error', e);
      return ResponseHelper.error(message: 'Failed to get record: $e');
    }
  }

  Future<Response> _createRecord(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      await conn.execute(
        '''
        INSERT INTO maintenance_records 
        (id, equipment_id, equipment_name, maintenance_date, maintenance_type,
         description, performed_by, cost, next_maintenance_date, created_at)
        VALUES 
        (@id, @equipmentId, @equipmentName, @maintenanceDate, @maintenanceType,
         @description, @performedBy, @cost, @nextMaintenanceDate, @createdAt)
        ''',
        substitutionValues: {
          'id': body['id'],
          'equipmentId': body['equipmentId'],
          'equipmentName': body['equipmentName'],
          'maintenanceDate': body['maintenanceDate'],
          'maintenanceType': body['maintenanceType'],
          'description': body['description'],
          'performedBy': body['performedBy'],
          'cost': body['cost'],
          'nextMaintenanceDate': body['nextMaintenanceDate'],
          'createdAt': body['createdAt'],
        },
      );

      return ResponseHelper.success(data: {'message': 'Record created successfully'});
    } catch (e) {
      AppLogger.error('Create maintenance record error', e);
      return ResponseHelper.error(message: 'Failed to create record: $e');
    }
  }

  Future<Response> _updateRecord(Request request, String recordId) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      final updates = <String, dynamic>{};

      if (body.containsKey('description')) updates['description'] = body['description'];
      if (body.containsKey('cost')) updates['cost'] = body['cost'];
      if (body.containsKey('nextMaintenanceDate')) {
        updates['next_maintenance_date'] = body['nextMaintenanceDate'];
      }

      if (updates.isEmpty) {
        return ResponseHelper.error(message: 'No fields to update');
      }

      final setClause = updates.keys.map((k) => '$k = @$k').join(', ');

      await conn.execute(
        '''
        UPDATE maintenance_records 
        SET $setClause
        WHERE id = @id
        ''',
        substitutionValues: {
          'id': recordId,
          ...updates,
        },
      );

      return ResponseHelper.success(data: {'message': 'Record updated successfully'});
    } catch (e) {
      AppLogger.error('Update maintenance record error', e);
      return ResponseHelper.error(message: 'Failed to update record: $e');
    }
  }

  Future<Response> _deleteRecord(Request request, String recordId) async {
    try {
      final conn = await DatabaseService().connection;

      await conn.execute(
        'DELETE FROM maintenance_records WHERE id = @id',
        substitutionValues: {'id': recordId},
      );

      return ResponseHelper.success(data: {'message': 'Record deleted successfully'});
    } catch (e) {
      AppLogger.error('Delete maintenance record error', e);
      return ResponseHelper.error(message: 'Failed to delete record: $e');
    }
  }
}

