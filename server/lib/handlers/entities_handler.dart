import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';
import '../database/database_service.dart';
import '../utils/response_helper.dart';
import '../logger/app_logger.dart';

class EntitiesHandler {
  Router get router {
    final router = Router();

    router.get('/', _getEntities);
    router.get('/<entityId>', _getEntity);
    router.post('/', _createEntity);
    router.put('/<entityId>', _updateEntity);
    router.delete('/<entityId>', _deleteEntity);

    return router;
  }

  Future<Response> _getEntities(Request request) async {
    try {
      final params = request.url.queryParameters;
      final type = params['type'];

      final conn = await DatabaseService().connection;
      
      String query = '''
        SELECT id, name, type, address, phone, email, location_lat, location_lng,
               created_at, updated_at
        FROM entities
        WHERE 1=1
      ''';
      
      final parameters = <String, dynamic>{};
      
      if (type != null) {
        query += ' AND type = @type';
        parameters['type'] = type;
      }
      
      query += ' ORDER BY created_at DESC';

      final entities = await conn.query(
        query,
        substitutionValues: parameters.isEmpty ? null : parameters,
      );

      final result = entities.map((entity) => {
        'id': entity[0],
        'name': entity[1],
        'type': entity[2],
        'address': entity[3],
        'phone': entity[4],
        'email': entity[5],
        'locationLat': entity[6],
        'locationLng': entity[7],
        'createdAt': entity[8],
        'updatedAt': entity[9],
      }).toList();

      return ResponseHelper.list(data: result);
    } catch (e) {
      AppLogger.error('Get entities error', e);
      return ResponseHelper.error(message: 'Failed to get entities: $e');
    }
  }

  Future<Response> _getEntity(Request request, String entityId) async {
    try {
      final conn = await DatabaseService().connection;
      
      final entity = await conn.query(
        '''
        SELECT id, name, type, address, phone, email, location_lat, location_lng,
               created_at, updated_at
        FROM entities
        WHERE id = @id
        ''',
        substitutionValues: {'id': entityId},
      );

      if (entity.isEmpty) {
        return ResponseHelper.error(
          message: 'Entity not found',
          statusCode: 404,
        );
      }

      final e = entity.first;
      return ResponseHelper.success(data: {
        'id': e[0],
        'name': e[1],
        'type': e[2],
        'address': e[3],
        'phone': e[4],
        'email': e[5],
        'locationLat': e[6],
        'locationLng': e[7],
        'createdAt': e[8],
        'updatedAt': e[9],
      });
    } catch (e) {
      AppLogger.error('Get entity error', e);
      return ResponseHelper.error(message: 'Failed to get entity: $e');
    }
  }

  Future<Response> _createEntity(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      await conn.execute(
        '''
        INSERT INTO entities 
        (id, name, type, address, phone, email, location_lat, location_lng,
         created_at, updated_at)
        VALUES (@id, @name, @type, @address, @phone, @email, @locationLat, @locationLng,
                @createdAt, @updatedAt)
        ''',
        substitutionValues: {
          'id': body['id'],
          'name': body['name'],
          'type': body['type'],
          'address': body['address'],
          'phone': body['phone'],
          'email': body['email'],
          'locationLat': body['locationLat'],
          'locationLng': body['locationLng'],
          'createdAt': body['createdAt'],
          'updatedAt': body['updatedAt'],
        },
      );

      return ResponseHelper.success(data: {'message': 'Entity created successfully'});
    } catch (e) {
      AppLogger.error('Create entity error', e);
      return ResponseHelper.error(message: 'Failed to create entity: $e');
    }
  }

  Future<Response> _updateEntity(Request request, String entityId) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      final updates = <String, dynamic>{
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };
      
      if (body.containsKey('name')) updates['name'] = body['name'];
      if (body.containsKey('address')) updates['address'] = body['address'];
      if (body.containsKey('phone')) updates['phone'] = body['phone'];
      if (body.containsKey('email')) updates['email'] = body['email'];
      if (body.containsKey('locationLat')) updates['locationLat'] = body['locationLat'];
      if (body.containsKey('locationLng')) updates['locationLng'] = body['locationLng'];

      if (updates.length == 1) {
        return ResponseHelper.error(message: 'No fields to update');
      }

      final setClause = updates.keys.map((k) => '$k = @$k').join(', ');
      
      await conn.execute(
        '''
        UPDATE entities 
        SET $setClause
        WHERE id = @id
        ''',
        substitutionValues: {
          'id': entityId,
          ...updates,
        },
      );

      return ResponseHelper.success(data: {'message': 'Entity updated successfully'});
    } catch (e) {
      AppLogger.error('Update entity error', e);
      return ResponseHelper.error(message: 'Failed to update entity: $e');
    }
  }

  Future<Response> _deleteEntity(Request request, String entityId) async {
    try {
      final conn = await DatabaseService().connection;
      
      await conn.execute(
        'DELETE FROM entities WHERE id = @id',
        substitutionValues: {'id': entityId},
      );

      return ResponseHelper.success(data: {'message': 'Entity deleted successfully'});
    } catch (e) {
      AppLogger.error('Delete entity error', e);
      return ResponseHelper.error(message: 'Failed to delete entity: $e');
    }
  }
}

