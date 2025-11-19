import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';
import '../database/database_service.dart';
import '../utils/response_helper.dart';
import '../logger/app_logger.dart';

class MedicalInventoryHandler {
  Router get router {
    final router = Router();

    router.get('/', _getInventory);
    router.get('/<itemId>', _getItem);
    router.post('/', _createItem);
    router.put('/<itemId>', _updateItem);
    router.delete('/<itemId>', _deleteItem);

    return router;
  }

  Future<Response> _getInventory(Request request) async {
    try {
      final params = request.url.queryParameters;
      final type = params['type'];
      final status = params['status'];
      final category = params['category'];

      final conn = await DatabaseService().connection;

      String query = '''
        SELECT id, name, type, category, description, quantity, min_stock_level,
               unit, unit_price, manufacturer, model, serial_number, purchase_date,
               expiry_date, location, status, last_maintenance_date, next_maintenance_date,
               supplier_id, supplier_name, created_at, updated_at
        FROM medical_inventory
        WHERE 1=1
      ''';

      final parameters = <String, dynamic>{};

      if (type != null) {
        query += ' AND type = @type';
        parameters['type'] = type;
      }
      if (status != null) {
        query += ' AND status = @status';
        parameters['status'] = status;
      }
      if (category != null) {
        query += ' AND category = @category';
        parameters['category'] = category;
      }

      query += ' ORDER BY name ASC';

      final items = await conn.query(
        query,
        substitutionValues: parameters.isEmpty ? null : parameters,
      );

      final result = items.map((i) => {
        'id': i[0],
        'name': i[1],
        'type': i[2],
        'category': i[3],
        'description': i[4],
        'quantity': i[5],
        'minStockLevel': i[6],
        'unit': i[7],
        'unitPrice': i[8],
        'manufacturer': i[9],
        'model': i[10],
        'serialNumber': i[11],
        'purchaseDate': i[12],
        'expiryDate': i[13],
        'location': i[14],
        'status': i[15],
        'lastMaintenanceDate': i[16],
        'nextMaintenanceDate': i[17],
        'supplierId': i[18],
        'supplierName': i[19],
        'createdAt': i[20],
        'updatedAt': i[21],
      }).toList();

      return ResponseHelper.list(data: result);
    } catch (e) {
      AppLogger.error('Get medical inventory error', e);
      return ResponseHelper.error(message: 'Failed to get inventory: $e');
    }
  }

  Future<Response> _getItem(Request request, String itemId) async {
    try {
      final conn = await DatabaseService().connection;

      final result = await conn.query(
        '''
        SELECT id, name, type, category, description, quantity, min_stock_level,
               unit, unit_price, manufacturer, model, serial_number, purchase_date,
               expiry_date, location, status, last_maintenance_date, next_maintenance_date,
               supplier_id, supplier_name, created_at, updated_at
        FROM medical_inventory
        WHERE id = @id
        ''',
        substitutionValues: {'id': itemId},
      );

      if (result.isEmpty) {
        return ResponseHelper.error(message: 'Item not found', statusCode: 404);
      }

      final i = result.first;
      return ResponseHelper.success(data: {
        'id': i[0],
        'name': i[1],
        'type': i[2],
        'category': i[3],
        'description': i[4],
        'quantity': i[5],
        'minStockLevel': i[6],
        'unit': i[7],
        'unitPrice': i[8],
        'manufacturer': i[9],
        'model': i[10],
        'serialNumber': i[11],
        'purchaseDate': i[12],
        'expiryDate': i[13],
        'location': i[14],
        'status': i[15],
        'lastMaintenanceDate': i[16],
        'nextMaintenanceDate': i[17],
        'supplierId': i[18],
        'supplierName': i[19],
        'createdAt': i[20],
        'updatedAt': i[21],
      });
    } catch (e) {
      AppLogger.error('Get inventory item error', e);
      return ResponseHelper.error(message: 'Failed to get item: $e');
    }
  }

  Future<Response> _createItem(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      await conn.execute(
        '''
        INSERT INTO medical_inventory 
        (id, name, type, category, description, quantity, min_stock_level, unit, unit_price,
         manufacturer, model, serial_number, purchase_date, expiry_date, location, status,
         last_maintenance_date, next_maintenance_date, supplier_id, supplier_name, created_at, updated_at)
        VALUES 
        (@id, @name, @type, @category, @description, @quantity, @minStockLevel, @unit, @unitPrice,
         @manufacturer, @model, @serialNumber, @purchaseDate, @expiryDate, @location, @status,
         @lastMaintenanceDate, @nextMaintenanceDate, @supplierId, @supplierName, @createdAt, @updatedAt)
        ''',
        substitutionValues: {
          'id': body['id'],
          'name': body['name'],
          'type': body['type'],
          'category': body['category'],
          'description': body['description'],
          'quantity': body['quantity'],
          'minStockLevel': body['minStockLevel'],
          'unit': body['unit'],
          'unitPrice': body['unitPrice'],
          'manufacturer': body['manufacturer'],
          'model': body['model'],
          'serialNumber': body['serialNumber'],
          'purchaseDate': body['purchaseDate'],
          'expiryDate': body['expiryDate'],
          'location': body['location'],
          'status': body['status'],
          'lastMaintenanceDate': body['lastMaintenanceDate'],
          'nextMaintenanceDate': body['nextMaintenanceDate'],
          'supplierId': body['supplierId'],
          'supplierName': body['supplierName'],
          'createdAt': body['createdAt'],
          'updatedAt': body['updatedAt'],
        },
      );

      return ResponseHelper.success(data: {'message': 'Item created successfully'});
    } catch (e) {
      AppLogger.error('Create inventory item error', e);
      return ResponseHelper.error(message: 'Failed to create item: $e');
    }
  }

  Future<Response> _updateItem(Request request, String itemId) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      final updates = <String, dynamic>{
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      if (body.containsKey('quantity')) updates['quantity'] = body['quantity'];
      if (body.containsKey('status')) updates['status'] = body['status'];
      if (body.containsKey('nextMaintenanceDate')) {
        updates['next_maintenance_date'] = body['nextMaintenanceDate'];
      }

      final setClause = updates.keys.map((k) => '$k = @$k').join(', ');

      await conn.execute(
        '''
        UPDATE medical_inventory 
        SET $setClause
        WHERE id = @id
        ''',
        substitutionValues: {
          'id': itemId,
          ...updates,
        },
      );

      return ResponseHelper.success(data: {'message': 'Item updated successfully'});
    } catch (e) {
      AppLogger.error('Update inventory item error', e);
      return ResponseHelper.error(message: 'Failed to update item: $e');
    }
  }

  Future<Response> _deleteItem(Request request, String itemId) async {
    try {
      final conn = await DatabaseService().connection;

      await conn.execute(
        'DELETE FROM medical_inventory WHERE id = @id',
        substitutionValues: {'id': itemId},
      );

      return ResponseHelper.success(data: {'message': 'Item deleted successfully'});
    } catch (e) {
      AppLogger.error('Delete inventory item error', e);
      return ResponseHelper.error(message: 'Failed to delete item: $e');
    }
  }
}

