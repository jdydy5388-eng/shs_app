import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';
import '../database/database_service.dart';
import '../utils/response_helper.dart';
import '../logger/app_logger.dart';

class OrdersHandler {
  Router get router {
    final router = Router();

    router.get('/', _getOrders);
    router.get('/<orderId>', _getOrder);
    router.post('/', _createOrder);
    router.put('/<orderId>/status', _updateOrderStatus);
    router.put('/<orderId>/alternative', _suggestAlternative);
    router.put('/<orderId>/approve-alternative', _approveAlternative);
    router.put('/<orderId>/reject-alternative', _rejectAlternative);

    return router;
  }

  Future<Response> _getOrders(Request request) async {
    try {
      final params = request.url.queryParameters;
      final patientId = params['patientId'];
      final pharmacyId = params['pharmacyId'];

      final conn = await DatabaseService().connection;
      
      String query = '''
        SELECT id, patient_id, patient_name, pharmacy_id, pharmacy_name, prescription_id,
               status, total_amount, delivery_address, notes, created_at, updated_at, delivered_at
        FROM orders
        WHERE 1=1
      ''';
      
      final parameters = <String, dynamic>{};
      
      if (patientId != null) {
        query += ' AND patient_id = @patientId';
        parameters['patientId'] = patientId;
      }
      
      if (pharmacyId != null) {
        query += ' AND pharmacy_id = @pharmacyId';
        parameters['pharmacyId'] = pharmacyId;
      }
      
      query += ' ORDER BY created_at DESC';

      final orders = await conn.query(
        query,
        substitutionValues: parameters.isEmpty ? null : parameters,
      );

      final result = <Map<String, dynamic>>[];
      
      for (final order in orders) {
        final orderId = order[0] as String;
        
        // جلب عناصر الطلب
        final items = await conn.query(
          '''
          SELECT id, medication_id, medication_name, quantity, price,
                 alternative_medication_id, alternative_medication_name, alternative_price
          FROM order_items
          WHERE order_id = @orderId
          ''',
          substitutionValues: {'orderId': orderId},
        );

        result.add({
          'id': order[0],
          'patientId': order[1],
          'patientName': order[2],
          'pharmacyId': order[3],
          'pharmacyName': order[4],
          'prescriptionId': order[5],
          'status': order[6],
          'totalAmount': order[7],
          'deliveryAddress': order[8],
          'notes': order[9],
          'createdAt': order[10],
          'updatedAt': order[11],
          'deliveredAt': order[12],
          'items': items.map((item) => {
            'id': item[0],
            'medicationId': item[1],
            'medicationName': item[2],
            'quantity': item[3],
            'price': item[4],
            'alternativeMedicationId': item[5],
            'alternativeMedicationName': item[6],
            'alternativePrice': item[7],
          }).toList(),
        });
      }

      return ResponseHelper.list(data: result);
    } catch (e) {
      AppLogger.error('Get orders error', e);
      return ResponseHelper.error(message: 'Failed to get orders: $e');
    }
  }

  Future<Response> _getOrder(Request request, String orderId) async {
    try {
      final conn = await DatabaseService().connection;
      
      final order = await conn.query(
        '''
        SELECT id, patient_id, patient_name, pharmacy_id, pharmacy_name, prescription_id,
               status, total_amount, delivery_address, notes, created_at, updated_at, delivered_at
        FROM orders
        WHERE id = @id
        ''',
        substitutionValues: {'id': orderId},
      );

      if (order.isEmpty) {
        return ResponseHelper.error(
          message: 'Order not found',
          statusCode: 404,
        );
      }

      final o = order.first;

      // جلب عناصر الطلب
      final items = await conn.query(
        '''
        SELECT id, medication_id, medication_name, quantity, price,
               alternative_medication_id, alternative_medication_name, alternative_price
        FROM order_items
        WHERE order_id = @orderId
        ''',
        substitutionValues: {'orderId': orderId},
      );

      return ResponseHelper.success(data: {
        'id': o[0],
        'patientId': o[1],
        'patientName': o[2],
        'pharmacyId': o[3],
        'pharmacyName': o[4],
        'prescriptionId': o[5],
        'status': o[6],
        'totalAmount': o[7],
        'deliveryAddress': o[8],
        'notes': o[9],
        'createdAt': o[10],
        'updatedAt': o[11],
        'deliveredAt': o[12],
        'items': items.map((item) => {
          'id': item[0],
          'medicationId': item[1],
          'medicationName': item[2],
          'quantity': item[3],
          'price': item[4],
          'alternativeMedicationId': item[5],
          'alternativeMedicationName': item[6],
          'alternativePrice': item[7],
        }).toList(),
      });
    } catch (e) {
      AppLogger.error('Get order error', e);
      return ResponseHelper.error(message: 'Failed to get order: $e');
    }
  }

  Future<Response> _createOrder(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      await conn.transaction((ctx) async {
        // إنشاء الطلب
        await ctx.execute(
          '''
          INSERT INTO orders (id, patient_id, patient_name, pharmacy_id, pharmacy_name,
                             prescription_id, status, total_amount, delivery_address, notes,
                             created_at, updated_at, delivered_at)
          VALUES (@id, @patientId, @patientName, @pharmacyId, @pharmacyName,
                  @prescriptionId, @status, @totalAmount, @deliveryAddress, @notes,
                  @createdAt, @updatedAt, @deliveredAt)
          ''',
          substitutionValues: {
            'id': body['id'],
            'patientId': body['patientId'],
            'patientName': body['patientName'],
            'pharmacyId': body['pharmacyId'],
            'pharmacyName': body['pharmacyName'],
            'prescriptionId': body['prescriptionId'],
            'status': body['status'],
            'totalAmount': body['totalAmount'],
            'deliveryAddress': body['deliveryAddress'],
            'notes': body['notes'],
            'createdAt': body['createdAt'],
            'updatedAt': body['updatedAt'],
            'deliveredAt': body['deliveredAt'],
          },
        );

        // إضافة عناصر الطلب
        final items = body['items'] as List;
        for (final item in items) {
          await ctx.execute(
            '''
            INSERT INTO order_items 
            (id, order_id, medication_id, medication_name, quantity, price,
             alternative_medication_id, alternative_medication_name, alternative_price)
            VALUES (@id, @orderId, @medicationId, @medicationName, @quantity, @price,
                    @alternativeMedicationId, @alternativeMedicationName, @alternativePrice)
            ''',
            substitutionValues: {
              'id': item['id'],
              'orderId': body['id'],
              'medicationId': item['medicationId'],
              'medicationName': item['medicationName'],
              'quantity': item['quantity'],
              'price': item['price'],
              'alternativeMedicationId': item['alternativeMedicationId'],
              'alternativeMedicationName': item['alternativeMedicationName'],
              'alternativePrice': item['alternativePrice'],
            },
          );
        }
      });

      return ResponseHelper.success(data: {'message': 'Order created successfully'});
    } catch (e) {
      AppLogger.error('Create order error', e);
      return ResponseHelper.error(message: 'Failed to create order: $e');
    }
  }

  Future<Response> _updateOrderStatus(Request request, String orderId) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final status = body['status'] as String;
      final notes = body['notes'] as String?;

      final conn = await DatabaseService().connection;
      
      final updates = <String, dynamic>{
        'status': status,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };
      
      if (notes != null) {
        updates['notes'] = notes;
      }
      
      if (status == 'delivered') {
        updates['deliveredAt'] = DateTime.now().millisecondsSinceEpoch;
      }

      final setParts = <String>['status = @status', 'updated_at = @updatedAt'];
      if (notes != null) {
        setParts.add('notes = @notes');
      }
      if (status == 'delivered') {
        setParts.add('delivered_at = @deliveredAt');
      }

      await conn.execute(
        '''
        UPDATE orders 
        SET ${setParts.join(', ')}
        WHERE id = @id
        ''',
        substitutionValues: {
          'id': orderId,
          'status': status,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
          if (notes != null) 'notes': notes,
          if (status == 'delivered') 'deliveredAt': DateTime.now().millisecondsSinceEpoch,
        },
      );

      return ResponseHelper.success(data: {'message': 'Order status updated'});
    } catch (e) {
      AppLogger.error('Update order status error', e);
      return ResponseHelper.error(message: 'Failed to update order status: $e');
    }
  }

  Future<Response> _suggestAlternative(Request request, String orderId) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final itemId = body['itemId'] as String;
      final alternative = body['alternative'] as Map<String, dynamic>;

      final conn = await DatabaseService().connection;
      
      await conn.execute(
        '''
        UPDATE order_items 
        SET alternative_medication_id = @altId,
            alternative_medication_name = @altName,
            alternative_price = @altPrice
        WHERE id = @itemId AND order_id = @orderId
        ''',
        substitutionValues: {
          'itemId': itemId,
          'orderId': orderId,
          'altId': alternative['id'],
          'altName': alternative['medicationName'],
          'altPrice': alternative['price'],
        },
      );

      await conn.execute(
        '''
        UPDATE orders 
        SET updated_at = @updatedAt
        WHERE id = @orderId
        ''',
        substitutionValues: {
          'orderId': orderId,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
      );

      return ResponseHelper.success(data: {'message': 'Alternative suggested'});
    } catch (e) {
      AppLogger.error('Suggest alternative error', e);
      return ResponseHelper.error(message: 'Failed to suggest alternative: $e');
    }
  }

  Future<Response> _approveAlternative(Request request, String orderId) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final itemId = body['itemId'] as String;

      final conn = await DatabaseService().connection;
      
      // جلب بيانات البديل
      final item = await conn.query(
        '''
        SELECT alternative_medication_id, alternative_medication_name, alternative_price
        FROM order_items
        WHERE id = @itemId AND order_id = @orderId
        ''',
        substitutionValues: {'itemId': itemId, 'orderId': orderId},
      );

      if (item.isEmpty || item.first[0] == null) {
        return ResponseHelper.error(message: 'No alternative found');
      }

      final alt = item.first;

      // تحديث العنصر بالبديل
      await conn.execute(
        '''
        UPDATE order_items 
        SET medication_id = @altId,
            medication_name = @altName,
            price = @altPrice,
            alternative_medication_id = NULL,
            alternative_medication_name = NULL,
            alternative_price = NULL
        WHERE id = @itemId AND order_id = @orderId
        ''',
        substitutionValues: {
          'itemId': itemId,
          'orderId': orderId,
          'altId': alt[0],
          'altName': alt[1],
          'altPrice': alt[2],
        },
      );

      // إعادة حساب المجموع
      final total = await conn.query(
        '''
        SELECT SUM(price * quantity)
        FROM order_items
        WHERE order_id = @orderId
        ''',
        substitutionValues: {'orderId': orderId},
      );

      await conn.execute(
        '''
        UPDATE orders 
        SET total_amount = @totalAmount, updated_at = @updatedAt
        WHERE id = @orderId
        ''',
        substitutionValues: {
          'orderId': orderId,
          'totalAmount': total.first[0] ?? 0.0,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
      );

      return ResponseHelper.success(data: {'message': 'Alternative approved'});
    } catch (e) {
      AppLogger.error('Approve alternative error', e);
      return ResponseHelper.error(message: 'Failed to approve alternative: $e');
    }
  }

  Future<Response> _rejectAlternative(Request request, String orderId) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final itemId = body['itemId'] as String;

      final conn = await DatabaseService().connection;
      
      await conn.execute(
        '''
        UPDATE order_items 
        SET alternative_medication_id = NULL,
            alternative_medication_name = NULL,
            alternative_price = NULL
        WHERE id = @itemId AND order_id = @orderId
        ''',
        substitutionValues: {
          'itemId': itemId,
          'orderId': orderId,
        },
      );

      await conn.execute(
        '''
        UPDATE orders 
        SET updated_at = @updatedAt
        WHERE id = @orderId
        ''',
        substitutionValues: {
          'orderId': orderId,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
      );

      return ResponseHelper.success(data: {'message': 'Alternative rejected'});
    } catch (e) {
      AppLogger.error('Reject alternative error', e);
      return ResponseHelper.error(message: 'Failed to reject alternative: $e');
    }
  }
}

