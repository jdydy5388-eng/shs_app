import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';
import '../database/database_service.dart';
import '../utils/response_helper.dart';
import '../logger/app_logger.dart';

class BillingHandler {
  Router get router {
    final router = Router();

    // Invoices
    router.get('/invoices', _getInvoices);
    router.get('/invoices/<invoiceId>', _getInvoice);
    router.post('/invoices', _createInvoice);
    router.put('/invoices/<invoiceId>', _updateInvoice);
    router.put('/invoices/<invoiceId>/status', _updateInvoiceStatus);
    router.delete('/invoices/<invoiceId>', _deleteInvoice);

    // Payments
    router.get('/payments', _getPayments);
    router.get('/payments/<paymentId>', _getPayment);
    router.post('/payments', _createPayment);

    return router;
  }

  // Invoices
  Future<Response> _getInvoices(Request request) async {
    try {
      final params = request.url.queryParameters;
      final patientId = params['patientId'];
      final status = params['status'];

      final conn = await DatabaseService().connection;

      String query = '''
        SELECT id, patient_id, patient_name, related_type, related_id, items, subtotal, discount, tax,
               total, currency, status, insurance_provider, insurance_policy, created_at, updated_at, paid_at
        FROM invoices
        WHERE 1=1
      ''';
      final substitutionValues = <String, dynamic>{};

      if (patientId != null) {
        query += ' AND patient_id = @patientId';
        substitutionValues['patientId'] = patientId;
      }
      if (status != null) {
        query += ' AND status = @status';
        substitutionValues['status'] = status;
      }

      query += ' ORDER BY created_at DESC';

      final rows = await conn.query(query, substitutionValues: substitutionValues.isEmpty ? null : substitutionValues);

      final data = rows.map((r) => {
        'id': r[0],
        'patientId': r[1],
        'patientName': r[2],
        'relatedType': r[3],
        'relatedId': r[4],
        'items': jsonDecode(r[5] as String),
        'subtotal': r[6],
        'discount': r[7],
        'tax': r[8],
        'total': r[9],
        'currency': r[10],
        'status': r[11],
        'insuranceProvider': r[12],
        'insurancePolicy': r[13],
        'createdAt': r[14],
        'updatedAt': r[15],
        'paidAt': r[16],
      }).toList();

      return ResponseHelper.list(data: data);
    } catch (e) {
      AppLogger.error('Get invoices error', e);
      return ResponseHelper.error(message: 'Failed to get invoices: $e');
    }
  }

  Future<Response> _getInvoice(Request request, String invoiceId) async {
    try {
      final conn = await DatabaseService().connection;
      final rows = await conn.query(
        '''
        SELECT id, patient_id, patient_name, related_type, related_id, items, subtotal, discount, tax,
               total, currency, status, insurance_provider, insurance_policy, created_at, updated_at, paid_at
        FROM invoices
        WHERE id = @id
        ''',
        substitutionValues: {'id': invoiceId},
      );

      if (rows.isEmpty) {
        return ResponseHelper.error(message: 'Invoice not found', statusCode: 404);
      }
      final r = rows.first;
      final data = {
        'id': r[0],
        'patientId': r[1],
        'patientName': r[2],
        'relatedType': r[3],
        'relatedId': r[4],
        'items': jsonDecode(r[5] as String),
        'subtotal': r[6],
        'discount': r[7],
        'tax': r[8],
        'total': r[9],
        'currency': r[10],
        'status': r[11],
        'insuranceProvider': r[12],
        'insurancePolicy': r[13],
        'createdAt': r[14],
        'updatedAt': r[15],
        'paidAt': r[16],
      };

      return ResponseHelper.success(data: data);
    } catch (e) {
      AppLogger.error('Get invoice error', e);
      return ResponseHelper.error(message: 'Failed to get invoice: $e');
    }
  }

  Future<Response> _createInvoice(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      await conn.execute(
        '''
        INSERT INTO invoices 
        (id, patient_id, patient_name, related_type, related_id, items, subtotal, discount, tax, total, currency, status,
         insurance_provider, insurance_policy, created_at, updated_at, paid_at)
        VALUES (@id, @patientId, @patientName, @relatedType, @relatedId, @items, @subtotal, @discount, @tax, @total, @currency, @status,
                @insuranceProvider, @insurancePolicy, @createdAt, @updatedAt, @paidAt)
        ''',
        substitutionValues: {
          'id': body['id'],
          'patientId': body['patientId'],
          'patientName': body['patientName'],
          'relatedType': body['relatedType'],
          'relatedId': body['relatedId'],
          'items': jsonEncode(body['items'] ?? const []),
          'subtotal': body['subtotal'] ?? 0.0,
          'discount': body['discount'] ?? 0.0,
          'tax': body['tax'] ?? 0.0,
          'total': body['total'] ?? 0.0,
          'currency': body['currency'] ?? 'SAR',
          'status': body['status'] ?? 'issued',
          'insuranceProvider': body['insuranceProvider'],
          'insurancePolicy': body['insurancePolicy'],
          'createdAt': body['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
          'updatedAt': body['updatedAt'],
          'paidAt': body['paidAt'],
        },
      );

      return ResponseHelper.success(data: {'message': 'Invoice created successfully'});
    } catch (e) {
      AppLogger.error('Create invoice error', e);
      return ResponseHelper.error(message: 'Failed to create invoice: $e');
    }
  }

  Future<Response> _updateInvoice(Request request, String invoiceId) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      final updates = <String, dynamic>{};
      final fields = <String>[];

      void addField(String key, dynamic value) {
        fields.add('$key = @$key');
        updates[key] = value;
      }

      if (body.containsKey('items')) addField('items', jsonEncode(body['items'] ?? []));
      if (body.containsKey('subtotal')) addField('subtotal', body['subtotal']);
      if (body.containsKey('discount')) addField('discount', body['discount']);
      if (body.containsKey('tax')) addField('tax', body['tax']);
      if (body.containsKey('total')) addField('total', body['total']);
      if (body.containsKey('currency')) addField('currency', body['currency']);
      if (body.containsKey('insuranceProvider')) addField('insurance_provider', body['insuranceProvider']);
      if (body.containsKey('insurancePolicy')) addField('insurance_policy', body['insurancePolicy']);

      if (fields.isEmpty) {
        return ResponseHelper.success(data: {'message': 'Nothing to update'});
      }
      addField('updated_at', DateTime.now().millisecondsSinceEpoch);
      updates['id'] = invoiceId;

      await conn.execute(
        'UPDATE invoices SET ${fields.join(', ')} WHERE id = @id',
        substitutionValues: updates,
      );

      return ResponseHelper.success(data: {'message': 'Invoice updated'});
    } catch (e) {
      AppLogger.error('Update invoice error', e);
      return ResponseHelper.error(message: 'Failed to update invoice: $e');
    }
  }

  Future<Response> _updateInvoiceStatus(Request request, String invoiceId) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final status = body['status'] as String;
      final conn = await DatabaseService().connection;

      await conn.execute(
        '''
        UPDATE invoices
        SET status = @status, 
            updated_at = @updatedAt,
            paid_at = CASE WHEN @status = 'paid' THEN @updatedAt ELSE paid_at END
        WHERE id = @id
        ''',
        substitutionValues: {
          'id': invoiceId,
          'status': status,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
      );

      return ResponseHelper.success(data: {'message': 'Invoice status updated'});
    } catch (e) {
      AppLogger.error('Update invoice status error', e);
      return ResponseHelper.error(message: 'Failed to update invoice status: $e');
    }
  }

  Future<Response> _deleteInvoice(Request request, String invoiceId) async {
    try {
      final conn = await DatabaseService().connection;
      await conn.execute('DELETE FROM invoices WHERE id = @id', substitutionValues: {'id': invoiceId});
      return ResponseHelper.success(data: {'message': 'Invoice deleted'});
    } catch (e) {
      AppLogger.error('Delete invoice error', e);
      return ResponseHelper.error(message: 'Failed to delete invoice: $e');
    }
  }

  // Payments
  Future<Response> _getPayments(Request request) async {
    try {
      final params = request.url.queryParameters;
      final invoiceId = params['invoiceId'];

      final conn = await DatabaseService().connection;
      String query = '''
        SELECT id, invoice_id, amount, method, reference, created_at, notes
        FROM payments
        WHERE 1=1
      ''';
      final values = <String, dynamic>{};
      if (invoiceId != null) {
        query += ' AND invoice_id = @invoiceId';
        values['invoiceId'] = invoiceId;
      }
      query += ' ORDER BY created_at DESC';

      final rows = await conn.query(query, substitutionValues: values.isEmpty ? null : values);
      final data = rows.map((r) => {
        'id': r[0],
        'invoiceId': r[1],
        'amount': r[2],
        'method': r[3],
        'reference': r[4],
        'createdAt': r[5],
        'notes': r[6],
      }).toList();

      return ResponseHelper.list(data: data);
    } catch (e) {
      AppLogger.error('Get payments error', e);
      return ResponseHelper.error(message: 'Failed to get payments: $e');
    }
  }

  Future<Response> _getPayment(Request request, String paymentId) async {
    try {
      final conn = await DatabaseService().connection;
      final rows = await conn.query(
        '''
        SELECT id, invoice_id, amount, method, reference, created_at, notes
        FROM payments
        WHERE id = @id
        ''',
        substitutionValues: {'id': paymentId},
      );
      if (rows.isEmpty) {
        return ResponseHelper.error(message: 'Payment not found', statusCode: 404);
      }
      final r = rows.first;
      final data = {
        'id': r[0],
        'invoiceId': r[1],
        'amount': r[2],
        'method': r[3],
        'reference': r[4],
        'createdAt': r[5],
        'notes': r[6],
      };
      return ResponseHelper.success(data: data);
    } catch (e) {
      AppLogger.error('Get payment error', e);
      return ResponseHelper.error(message: 'Failed to get payment: $e');
    }
  }

  Future<Response> _createPayment(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      await conn.execute(
        '''
        INSERT INTO payments (id, invoice_id, amount, method, reference, created_at, notes)
        VALUES (@id, @invoiceId, @amount, @method, @reference, @createdAt, @notes)
        ''',
        substitutionValues: {
          'id': body['id'],
          'invoiceId': body['invoiceId'],
          'amount': body['amount'],
          'method': body['method'],
          'reference': body['reference'],
          'createdAt': body['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
          'notes': body['notes'],
        },
      );

      // إذا كانت الدفعة تساوي الإجمالي، نحدد الفاتورة كمدفوعة
      try {
        final invoiceRows = await conn.query(
          'SELECT total FROM invoices WHERE id = @id',
          substitutionValues: {'id': body['invoiceId']},
        );
        if (invoiceRows.isNotEmpty) {
          final total = (invoiceRows.first[0] as num).toDouble();
          final amt = (body['amount'] as num).toDouble();
          if (amt >= total) {
            await conn.execute(
              '''
              UPDATE invoices SET status = 'paid', paid_at = @paidAt, updated_at = @paidAt
              WHERE id = @id
              ''',
              substitutionValues: {
                'id': body['invoiceId'],
                'paidAt': DateTime.now().millisecondsSinceEpoch,
              },
            );
          }
        }
      } catch (_) {}

      return ResponseHelper.success(data: {'message': 'Payment created successfully'});
    } catch (e) {
      AppLogger.error('Create payment error', e);
      return ResponseHelper.error(message: 'Failed to create payment: $e');
    }
  }
}


