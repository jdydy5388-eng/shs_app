import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';
import '../database/database_service.dart';
import '../utils/response_helper.dart';
import '../logger/app_logger.dart';

class SuppliersHandler {
  Router get router {
    final router = Router();

    router.get('/', _getSuppliers);
    router.get('/<supplierId>', _getSupplier);
    router.post('/', _createSupplier);
    router.put('/<supplierId>', _updateSupplier);
    router.delete('/<supplierId>', _deleteSupplier);

    return router;
  }

  Future<Response> _getSuppliers(Request request) async {
    try {
      final conn = await DatabaseService().connection;

      final suppliers = await conn.query(
        '''
        SELECT id, name, contact_person, email, phone, address, notes, created_at, updated_at
        FROM suppliers
        ORDER BY name ASC
        ''',
      );

      final result = suppliers.map((s) => {
        'id': s[0],
        'name': s[1],
        'contactPerson': s[2],
        'email': s[3],
        'phone': s[4],
        'address': s[5],
        'notes': s[6],
        'createdAt': s[7],
        'updatedAt': s[8],
      }).toList();

      return ResponseHelper.list(data: result);
    } catch (e) {
      AppLogger.error('Get suppliers error', e);
      return ResponseHelper.error(message: 'Failed to get suppliers: $e');
    }
  }

  Future<Response> _getSupplier(Request request, String supplierId) async {
    try {
      final conn = await DatabaseService().connection;

      final result = await conn.query(
        '''
        SELECT id, name, contact_person, email, phone, address, notes, created_at, updated_at
        FROM suppliers
        WHERE id = @id
        ''',
        substitutionValues: {'id': supplierId},
      );

      if (result.isEmpty) {
        return ResponseHelper.error(message: 'Supplier not found', statusCode: 404);
      }

      final s = result.first;
      return ResponseHelper.success(data: {
        'id': s[0],
        'name': s[1],
        'contactPerson': s[2],
        'email': s[3],
        'phone': s[4],
        'address': s[5],
        'notes': s[6],
        'createdAt': s[7],
        'updatedAt': s[8],
      });
    } catch (e) {
      AppLogger.error('Get supplier error', e);
      return ResponseHelper.error(message: 'Failed to get supplier: $e');
    }
  }

  Future<Response> _createSupplier(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      await conn.execute(
        '''
        INSERT INTO suppliers 
        (id, name, contact_person, email, phone, address, notes, created_at, updated_at)
        VALUES 
        (@id, @name, @contactPerson, @email, @phone, @address, @notes, @createdAt, @updatedAt)
        ''',
        substitutionValues: {
          'id': body['id'],
          'name': body['name'],
          'contactPerson': body['contactPerson'],
          'email': body['email'],
          'phone': body['phone'],
          'address': body['address'],
          'notes': body['notes'],
          'createdAt': body['createdAt'],
          'updatedAt': body['updatedAt'],
        },
      );

      return ResponseHelper.success(data: {'message': 'Supplier created successfully'});
    } catch (e) {
      AppLogger.error('Create supplier error', e);
      return ResponseHelper.error(message: 'Failed to create supplier: $e');
    }
  }

  Future<Response> _updateSupplier(Request request, String supplierId) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      final updates = <String, dynamic>{
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      if (body.containsKey('name')) updates['name'] = body['name'];
      if (body.containsKey('contactPerson')) updates['contact_person'] = body['contactPerson'];
      if (body.containsKey('email')) updates['email'] = body['email'];
      if (body.containsKey('phone')) updates['phone'] = body['phone'];
      if (body.containsKey('address')) updates['address'] = body['address'];
      if (body.containsKey('notes')) updates['notes'] = body['notes'];

      final setClause = updates.keys.map((k) => '$k = @$k').join(', ');

      await conn.execute(
        '''
        UPDATE suppliers 
        SET $setClause
        WHERE id = @id
        ''',
        substitutionValues: {
          'id': supplierId,
          ...updates,
        },
      );

      return ResponseHelper.success(data: {'message': 'Supplier updated successfully'});
    } catch (e) {
      AppLogger.error('Update supplier error', e);
      return ResponseHelper.error(message: 'Failed to update supplier: $e');
    }
  }

  Future<Response> _deleteSupplier(Request request, String supplierId) async {
    try {
      final conn = await DatabaseService().connection;

      await conn.execute(
        'DELETE FROM suppliers WHERE id = @id',
        substitutionValues: {'id': supplierId},
      );

      return ResponseHelper.success(data: {'message': 'Supplier deleted successfully'});
    } catch (e) {
      AppLogger.error('Delete supplier error', e);
      return ResponseHelper.error(message: 'Failed to delete supplier: $e');
    }
  }
}

