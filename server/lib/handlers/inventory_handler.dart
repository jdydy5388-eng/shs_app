import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';
import '../database/database_service.dart';
import '../utils/response_helper.dart';
import '../logger/app_logger.dart';

class InventoryHandler {
  Router get router {
    final router = Router();

    router.get('/', _getInventory);
    router.get('/<itemId>', _getInventoryItem);
    router.post('/', _createInventoryItem);
    router.put('/<itemId>', _updateInventoryItem);
    router.delete('/<itemId>', _deleteInventoryItem);

    return router;
  }

  Future<Response> _getInventory(Request request) async {
    try {
      final params = request.url.queryParameters;
      final pharmacyId = params['pharmacyId'];

      final conn = await DatabaseService().connection;
      
      String query = '''
        SELECT id, pharmacy_id, medication_name, medication_id, quantity, price,
               manufacturer, expiry_date, batch_number, last_updated
        FROM inventory
        WHERE 1=1
      ''';
      
      final parameters = <String, dynamic>{};
      
      if (pharmacyId != null) {
        query += ' AND pharmacy_id = @pharmacyId';
        parameters['pharmacyId'] = pharmacyId;
      }
      
      query += ' ORDER BY last_updated DESC';

      final inventory = await conn.query(
        query,
        substitutionValues: parameters.isEmpty ? null : parameters,
      );

      final result = inventory.map((item) => {
        'id': item[0],
        'pharmacyId': item[1],
        'medicationName': item[2],
        'medicationId': item[3],
        'quantity': item[4],
        'price': item[5],
        'manufacturer': item[6],
        'expiryDate': item[7],
        'batchNumber': item[8],
        'lastUpdated': item[9],
      }).toList();

      return ResponseHelper.list(data: result);
    } catch (e) {
      AppLogger.error('Get inventory error', e);
      return ResponseHelper.error(message: 'Failed to get inventory: $e');
    }
  }

  Future<Response> _getInventoryItem(Request request, String itemId) async {
    try {
      final conn = await DatabaseService().connection;
      
      final item = await conn.query(
        '''
        SELECT id, pharmacy_id, medication_name, medication_id, quantity, price,
               manufacturer, expiry_date, batch_number, last_updated
        FROM inventory
        WHERE id = @id
        ''',
        substitutionValues: {'id': itemId},
      );

      if (item.isEmpty) {
        return ResponseHelper.error(
          message: 'Inventory item not found',
          statusCode: 404,
        );
      }

      final i = item.first;
      return ResponseHelper.success(data: {
        'id': i[0],
        'pharmacyId': i[1],
        'medicationName': i[2],
        'medicationId': i[3],
        'quantity': i[4],
        'price': i[5],
        'manufacturer': i[6],
        'expiryDate': i[7],
        'batchNumber': i[8],
        'lastUpdated': i[9],
      });
    } catch (e) {
      AppLogger.error('Get inventory item error', e);
      return ResponseHelper.error(message: 'Failed to get inventory item: $e');
    }
  }

  Future<Response> _createInventoryItem(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      await conn.execute(
        '''
        INSERT INTO inventory 
        (id, pharmacy_id, medication_name, medication_id, quantity, price,
         manufacturer, expiry_date, batch_number, last_updated)
        VALUES (@id, @pharmacyId, @medicationName, @medicationId, @quantity, @price,
                @manufacturer, @expiryDate, @batchNumber, @lastUpdated)
        ''',
        substitutionValues: {
          'id': body['id'],
          'pharmacyId': body['pharmacyId'],
          'medicationName': body['medicationName'],
          'medicationId': body['medicationId'],
          'quantity': body['quantity'],
          'price': body['price'],
          'manufacturer': body['manufacturer'],
          'expiryDate': body['expiryDate'],
          'batchNumber': body['batchNumber'],
          'lastUpdated': body['lastUpdated'],
        },
      );

      return ResponseHelper.success(data: {'message': 'Inventory item created successfully'});
    } catch (e) {
      AppLogger.error('Create inventory item error', e);
      return ResponseHelper.error(message: 'Failed to create inventory item: $e');
    }
  }

  Future<Response> _updateInventoryItem(Request request, String itemId) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      final updates = <String, dynamic>{
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      };
      
      if (body.containsKey('quantity')) updates['quantity'] = body['quantity'];
      if (body.containsKey('price')) updates['price'] = body['price'];
      if (body.containsKey('manufacturer')) updates['manufacturer'] = body['manufacturer'];
      if (body.containsKey('expiryDate')) updates['expiryDate'] = body['expiryDate'];
      if (body.containsKey('batchNumber')) updates['batchNumber'] = body['batchNumber'];

      if (updates.length == 1) {
        return ResponseHelper.error(message: 'No fields to update');
      }

      final setClause = updates.keys.map((k) => '$k = @$k').join(', ');
      
      await conn.execute(
        '''
        UPDATE inventory 
        SET $setClause
        WHERE id = @id
        ''',
        substitutionValues: {
          'id': itemId,
          ...updates,
        },
      );

      return ResponseHelper.success(data: {'message': 'Inventory item updated successfully'});
    } catch (e) {
      AppLogger.error('Update inventory item error', e);
      return ResponseHelper.error(message: 'Failed to update inventory item: $e');
    }
  }

  Future<Response> _deleteInventoryItem(Request request, String itemId) async {
    try {
      final conn = await DatabaseService().connection;
      
      await conn.execute(
        'DELETE FROM inventory WHERE id = @id',
        substitutionValues: {'id': itemId},
      );

      return ResponseHelper.success(data: {'message': 'Inventory item deleted successfully'});
    } catch (e) {
      AppLogger.error('Delete inventory item error', e);
      return ResponseHelper.error(message: 'Failed to delete inventory item: $e');
    }
  }
}

