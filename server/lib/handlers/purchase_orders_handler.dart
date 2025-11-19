import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';
import '../database/database_service.dart';
import '../utils/response_helper.dart';
import '../logger/app_logger.dart';

class PurchaseOrdersHandler {
  Router get router {
    final router = Router();

    router.get('/', _getOrders);
    router.get('/<orderId>', _getOrder);
    router.post('/', _createOrder);
    router.put('/<orderId>', _updateOrder);
    router.delete('/<orderId>', _deleteOrder);

    return router;
  }

  Future<Response> _getOrders(Request request) async {
    try {
      final params = request.url.queryParameters;
      final status = params['status'];

      final conn = await DatabaseService().connection;

      String query = '''
        SELECT id, order_number, supplier_id, supplier_name, items, total_amount, status,
               notes, requested_by, requested_date, approved_by, approved_date,
               ordered_date, received_date, created_at, updated_at
        FROM purchase_orders
        WHERE 1=1
      ''';

      final parameters = <String, dynamic>{};

      if (status != null) {
        query += ' AND status = @status';
        parameters['status'] = status;
      }

      query += ' ORDER BY created_at DESC';

      final orders = await conn.query(
        query,
        substitutionValues: parameters.isEmpty ? null : parameters,
      );

      final result = orders.map((o) {
        Map<String, dynamic>? itemsMap;
        if (o[4] != null) {
          try {
            itemsMap = Map<String, dynamic>.from(jsonDecode(o[4] as String) as Map);
          } catch (_) {}
        }

        return {
          'id': o[0],
          'orderNumber': o[1],
          'supplierId': o[2],
          'supplierName': o[3],
          'items': itemsMap?['items'] ?? [],
          'totalAmount': o[5],
          'status': o[6],
          'notes': o[7],
          'requestedBy': o[8],
          'requestedDate': o[9],
          'approvedBy': o[10],
          'approvedDate': o[11],
          'orderedDate': o[12],
          'receivedDate': o[13],
          'createdAt': o[14],
          'updatedAt': o[15],
        };
      }).toList();

      return ResponseHelper.list(data: result);
    } catch (e) {
      AppLogger.error('Get purchase orders error', e);
      return ResponseHelper.error(message: 'Failed to get orders: $e');
    }
  }

  Future<Response> _getOrder(Request request, String orderId) async {
    try {
      final conn = await DatabaseService().connection;

      final result = await conn.query(
        '''
        SELECT id, order_number, supplier_id, supplier_name, items, total_amount, status,
               notes, requested_by, requested_date, approved_by, approved_date,
               ordered_date, received_date, created_at, updated_at
        FROM purchase_orders
        WHERE id = @id
        ''',
        substitutionValues: {'id': orderId},
      );

      if (result.isEmpty) {
        return ResponseHelper.error(message: 'Order not found', statusCode: 404);
      }

      final o = result.first;
      Map<String, dynamic>? itemsMap;
      if (o[4] != null) {
        try {
          itemsMap = Map<String, dynamic>.from(jsonDecode(o[4] as String) as Map);
        } catch (_) {}
      }

      return ResponseHelper.success(data: {
        'id': o[0],
        'orderNumber': o[1],
        'supplierId': o[2],
        'supplierName': o[3],
        'items': itemsMap?['items'] ?? [],
        'totalAmount': o[5],
        'status': o[6],
        'notes': o[7],
        'requestedBy': o[8],
        'requestedDate': o[9],
        'approvedBy': o[10],
        'approvedDate': o[11],
        'orderedDate': o[12],
        'receivedDate': o[13],
        'createdAt': o[14],
        'updatedAt': o[15],
      });
    } catch (e) {
      AppLogger.error('Get purchase order error', e);
      return ResponseHelper.error(message: 'Failed to get order: $e');
    }
  }

  Future<Response> _createOrder(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      await conn.execute(
        '''
        INSERT INTO purchase_orders 
        (id, order_number, supplier_id, supplier_name, items, total_amount, status,
         notes, requested_by, requested_date, approved_by, approved_date,
         ordered_date, received_date, created_at, updated_at)
        VALUES 
        (@id, @orderNumber, @supplierId, @supplierName, @items, @totalAmount, @status,
         @notes, @requestedBy, @requestedDate, @approvedBy, @approvedDate,
         @orderedDate, @receivedDate, @createdAt, @updatedAt)
        ''',
        substitutionValues: {
          'id': body['id'],
          'orderNumber': body['orderNumber'],
          'supplierId': body['supplierId'],
          'supplierName': body['supplierName'],
          'items': jsonEncode({'items': body['items']}),
          'totalAmount': body['totalAmount'],
          'status': body['status'],
          'notes': body['notes'],
          'requestedBy': body['requestedBy'],
          'requestedDate': body['requestedDate'],
          'approvedBy': body['approvedBy'],
          'approvedDate': body['approvedDate'],
          'orderedDate': body['orderedDate'],
          'receivedDate': body['receivedDate'],
          'createdAt': body['createdAt'],
          'updatedAt': body['updatedAt'],
        },
      );

      return ResponseHelper.success(data: {'message': 'Order created successfully'});
    } catch (e) {
      AppLogger.error('Create purchase order error', e);
      return ResponseHelper.error(message: 'Failed to create order: $e');
    }
  }

  Future<Response> _updateOrder(Request request, String orderId) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      final updates = <String, dynamic>{
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      if (body.containsKey('status')) updates['status'] = body['status'];
      if (body.containsKey('approvedBy')) updates['approved_by'] = body['approvedBy'];
      if (body.containsKey('approvedDate')) updates['approved_date'] = body['approvedDate'];
      if (body.containsKey('orderedDate')) updates['ordered_date'] = body['orderedDate'];
      if (body.containsKey('receivedDate')) updates['received_date'] = body['receivedDate'];

      final setClause = updates.keys.map((k) => '$k = @$k').join(', ');

      await conn.execute(
        '''
        UPDATE purchase_orders 
        SET $setClause
        WHERE id = @id
        ''',
        substitutionValues: {
          'id': orderId,
          ...updates,
        },
      );

      return ResponseHelper.success(data: {'message': 'Order updated successfully'});
    } catch (e) {
      AppLogger.error('Update purchase order error', e);
      return ResponseHelper.error(message: 'Failed to update order: $e');
    }
  }

  Future<Response> _deleteOrder(Request request, String orderId) async {
    try {
      final conn = await DatabaseService().connection;

      await conn.execute(
        'DELETE FROM purchase_orders WHERE id = @id',
        substitutionValues: {'id': orderId},
      );

      return ResponseHelper.success(data: {'message': 'Order deleted successfully'});
    } catch (e) {
      AppLogger.error('Delete purchase order error', e);
      return ResponseHelper.error(message: 'Failed to delete order: $e');
    }
  }
}

