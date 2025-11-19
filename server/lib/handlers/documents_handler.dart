import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database/database_service.dart';
import '../utils/rbac.dart';
import '../utils/response_helper.dart';
import '../logger/app_logger.dart';

class DocumentsHandler {
  final DatabaseService _db = DatabaseService();

  Router get router {
    final router = Router();

    router.get('/', _getDocuments);
    router.get('/<documentId>', _getDocument);
    router.get('/<documentId>/signature', _getDocumentSignature);
    router.post('/', _createDocument);
    router.put('/<documentId>', _updateDocument);
    router.delete('/<documentId>', _deleteDocument);
    router.post('/signatures', _createDocumentSignature);
    router.get('/signatures', _getDocumentSignatures);

    return router;
  }

  Map<String, dynamic>? _getUser(Request request) {
    return request.context['user'] as Map<String, dynamic>?;
  }

  Future<Response> _getDocuments(Request request) async {
    final user = _getUser(request);
    if (user == null) {
      return ResponseHelper.unauthorized('يجب تسجيل الدخول');
    }

    final userRole = user['role'] as String;
    if (!hasPermission(userRole, Permission.readStorage)) {
      return ResponseHelper.forbidden('ليس لديك صلاحية للوصول إلى الوثائق');
    }
    try {
      final queryParams = request.url.queryParameters;
      final conn = await _db.connection;

      String query = '''
        SELECT * FROM documents WHERE status != 'deleted'
      ''';
      final values = <String, dynamic>{};

      // فلترة حسب الفئة
      if (queryParams.containsKey('category')) {
        query += ' AND category = @category';
        values['category'] = queryParams['category']!;
      }

      // فلترة حسب الحالة
      if (queryParams.containsKey('status')) {
        query += ' AND status = @status';
        values['status'] = queryParams['status']!;
      }

      // فلترة حسب مستوى الوصول
      if (queryParams.containsKey('accessLevel')) {
        query += ' AND access_level = @accessLevel';
        values['accessLevel'] = queryParams['accessLevel']!;
      }

      // فلترة حسب المريض
      if (queryParams.containsKey('patientId')) {
        query += ' AND patient_id = @patientId';
        values['patientId'] = queryParams['patientId']!;
      }

      // فلترة حسب الطبيب
      if (queryParams.containsKey('doctorId')) {
        query += ' AND doctor_id = @doctorId';
        values['doctorId'] = queryParams['doctorId']!;
      }

      // فلترة حسب المستخدم (الوثائق التي أنشأها أو مشتركة معه)
      if (queryParams.containsKey('userId')) {
        final userId = queryParams['userId']!;
        query += ' AND (created_by = @userId OR shared_with_user_ids::text LIKE @userIdPattern)';
        values['userId'] = userId;
        values['userIdPattern'] = '%$userId%';
      }

      // البحث في العنوان والوصف والعلامات
      if (queryParams.containsKey('searchQuery')) {
        final searchQuery = queryParams['searchQuery']!;
        query += ' AND (title ILIKE @searchPattern OR description ILIKE @searchPattern OR tags::text ILIKE @searchPattern)';
        values['searchPattern'] = '%$searchQuery%';
      }

      query += ' ORDER BY created_at DESC';

      final results = await conn.query(query, substitutionValues: values.isEmpty ? null : values);

      final documents = results.map((row) {
        return {
          'id': row[0],
          'title': row[1],
          'description': row[2],
          'category': row[3],
          'status': row[4],
          'accessLevel': row[5],
          'patientId': row[6],
          'patientName': row[7],
          'doctorId': row[8],
          'doctorName': row[9],
          'sharedWithUserIds': row[10] != null ? jsonDecode(row[10] as String) : null,
          'tags': row[11] != null ? jsonDecode(row[11] as String) : null,
          'fileUrl': row[12],
          'fileName': row[13],
          'fileType': row[14],
          'fileSize': row[15],
          'thumbnailUrl': row[16],
          'metadata': row[17] != null ? jsonDecode(row[17] as String) : null,
          'signatureId': row[18],
          'signedAt': row[19],
          'signedBy': row[20],
          'archivedAt': row[21],
          'archivedBy': row[22],
          'createdAt': row[23],
          'updatedAt': row[24],
          'createdBy': row[25],
        };
      }).toList();

      return ResponseHelper.list(data: documents);
    } catch (e, stackTrace) {
      AppLogger.error('Get documents error', e, stackTrace);
      return ResponseHelper.error('خطأ في جلب الوثائق: $e', stackTrace);
    }
  }

  Future<Response> _getDocument(Request request, String documentId) async {
    final user = _getUser(request);
    if (user == null) {
      return ResponseHelper.unauthorized('يجب تسجيل الدخول');
    }

    final userRole = user['role'] as String;
    if (!hasPermission(userRole, Permission.readStorage)) {
      return ResponseHelper.forbidden('ليس لديك صلاحية للوصول إلى الوثائق');
    }
    try {
      final conn = await _db.connection;
      final results = await conn.query(
        'SELECT * FROM documents WHERE id = @id',
        substitutionValues: {'id': documentId},
      );

      if (results.isEmpty) {
        return ResponseHelper.notFound('الوثيقة غير موجودة');
      }

      final row = results.first;
      final document = {
        'id': row[0],
        'title': row[1],
        'description': row[2],
        'category': row[3],
        'status': row[4],
        'accessLevel': row[5],
        'patientId': row[6],
        'patientName': row[7],
        'doctorId': row[8],
        'doctorName': row[9],
        'sharedWithUserIds': row[10] != null ? jsonDecode(row[10] as String) : null,
        'tags': row[11] != null ? jsonDecode(row[11] as String) : null,
        'fileUrl': row[12],
        'fileName': row[13],
        'fileType': row[14],
        'fileSize': row[15],
        'thumbnailUrl': row[16],
        'metadata': row[17] != null ? jsonDecode(row[17] as String) : null,
        'signatureId': row[18],
        'signedAt': row[19],
        'signedBy': row[20],
        'archivedAt': row[21],
        'archivedBy': row[22],
        'createdAt': row[23],
        'updatedAt': row[24],
        'createdBy': row[25],
      };

      return ResponseHelper.success(document);
    } catch (e, stackTrace) {
      AppLogger.error('Get document error', e, stackTrace);
      return ResponseHelper.error('خطأ في جلب الوثيقة: $e', stackTrace);
    }
  }

  Future<Response> _createDocument(Request request) async {
    final user = _getUser(request);
    if (user == null) {
      return ResponseHelper.unauthorized('يجب تسجيل الدخول');
    }

    final userRole = user['role'] as String;
    if (!hasPermission(userRole, Permission.writeStorage)) {
      return ResponseHelper.forbidden('ليس لديك صلاحية لإنشاء وثائق');
    }
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final conn = await _db.connection;
      await conn.execute('''
        INSERT INTO documents (
          id, title, description, category, status, access_level,
          patient_id, patient_name, doctor_id, doctor_name,
          shared_with_user_ids, tags, file_url, file_name, file_type,
          file_size, thumbnail_url, metadata, signature_id, signed_at,
          signed_by, archived_at, archived_by, created_at, updated_at, created_by
        ) VALUES (
          @id, @title, @description, @category, @status, @accessLevel,
          @patientId, @patientName, @doctorId, @doctorName,
          @sharedWithUserIds, @tags, @fileUrl, @fileName, @fileType,
          @fileSize, @thumbnailUrl, @metadata, @signatureId, @signedAt,
          @signedBy, @archivedAt, @archivedBy, @createdAt, @updatedAt, @createdBy
        )
      ''', substitutionValues: {
        'id': data['id'],
        'title': data['title'],
        'description': data['description'],
        'category': data['category'],
        'status': data['status'] ?? 'active',
        'accessLevel': data['accessLevel'] ?? 'private',
        'patientId': data['patientId'],
        'patientName': data['patientName'],
        'doctorId': data['doctorId'],
        'doctorName': data['doctorName'],
        'sharedWithUserIds': data['sharedWithUserIds'] != null ? jsonEncode(data['sharedWithUserIds']) : null,
        'tags': data['tags'] != null ? jsonEncode(data['tags']) : null,
        'fileUrl': data['fileUrl'],
        'fileName': data['fileName'],
        'fileType': data['fileType'],
        'fileSize': data['fileSize'],
        'thumbnailUrl': data['thumbnailUrl'],
        'metadata': data['metadata'] != null ? jsonEncode(data['metadata']) : null,
        'signatureId': data['signatureId'],
        'signedAt': data['signedAt'],
        'signedBy': data['signedBy'],
        'archivedAt': data['archivedAt'],
        'archivedBy': data['archivedBy'],
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': null,
        'createdBy': user['id'],
      });

      return ResponseHelper.success({'message': 'تم إنشاء الوثيقة بنجاح'});
    } catch (e, stackTrace) {
      AppLogger.error('Create document error', e, stackTrace);
      return ResponseHelper.error('خطأ في إنشاء الوثيقة: $e', stackTrace);
    }
  }

  Future<Response> _updateDocument(Request request, String documentId) async {
    final user = _getUser(request);
    if (user == null) {
      return ResponseHelper.unauthorized('يجب تسجيل الدخول');
    }

    final userRole = user['role'] as String;
    if (!hasPermission(userRole, Permission.writeStorage)) {
      return ResponseHelper.forbidden('ليس لديك صلاحية لتحديث الوثائق');
    }
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final conn = await _db.connection;
      final updates = <String>[];
      final values = <String, dynamic>{};

      if (data.containsKey('title')) {
        updates.add('title = @title');
        values['title'] = data['title'];
      }
      if (data.containsKey('description')) {
        updates.add('description = @description');
        values['description'] = data['description'];
      }
      if (data.containsKey('category')) {
        updates.add('category = @category');
        values['category'] = data['category'];
      }
      if (data.containsKey('status')) {
        updates.add('status = @status');
        values['status'] = data['status'];
      }
      if (data.containsKey('accessLevel')) {
        updates.add('access_level = @accessLevel');
        values['accessLevel'] = data['accessLevel'];
      }
      if (data.containsKey('sharedWithUserIds')) {
        updates.add('shared_with_user_ids = @sharedWithUserIds');
        values['sharedWithUserIds'] = jsonEncode(data['sharedWithUserIds']);
      }
      if (data.containsKey('tags')) {
        updates.add('tags = @tags');
        values['tags'] = jsonEncode(data['tags']);
      }
      if (data.containsKey('signatureId')) {
        updates.add('signature_id = @signatureId');
        values['signatureId'] = data['signatureId'];
      }
      if (data.containsKey('signedAt')) {
        updates.add('signed_at = @signedAt');
        values['signedAt'] = data['signedAt'];
      }
      if (data.containsKey('signedBy')) {
        updates.add('signed_by = @signedBy');
        values['signedBy'] = data['signedBy'];
      }
      if (data.containsKey('archivedAt')) {
        updates.add('archived_at = @archivedAt');
        values['archivedAt'] = data['archivedAt'];
      }
      if (data.containsKey('archivedBy')) {
        updates.add('archived_by = @archivedBy');
        values['archivedBy'] = data['archivedBy'];
      }

      updates.add('updated_at = @updatedAt');
      values['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
      values['id'] = documentId;

      await conn.execute(
        'UPDATE documents SET ${updates.join(', ')} WHERE id = @id',
        substitutionValues: values,
      );

      return ResponseHelper.success({'message': 'تم تحديث الوثيقة بنجاح'});
    } catch (e, stackTrace) {
      AppLogger.error('Update document error', e, stackTrace);
      return ResponseHelper.error('خطأ في تحديث الوثيقة: $e', stackTrace);
    }
  }

  Future<Response> _deleteDocument(Request request, String documentId) async {
    final user = _getUser(request);
    if (user == null) {
      return ResponseHelper.unauthorized('يجب تسجيل الدخول');
    }

    final userRole = user['role'] as String;
    if (!hasPermission(userRole, Permission.writeStorage)) {
      return ResponseHelper.forbidden('ليس لديك صلاحية لحذف الوثائق');
    }
    try {
      final conn = await _db.connection;
      await conn.execute(
        'UPDATE documents SET status = @status, updated_at = @updatedAt WHERE id = @id',
        substitutionValues: {
          'status': 'deleted',
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
          'id': documentId,
        },
      );

      return ResponseHelper.success({'message': 'تم حذف الوثيقة بنجاح'});
    } catch (e, stackTrace) {
      AppLogger.error('Delete document error', e, stackTrace);
      return ResponseHelper.error('خطأ في حذف الوثيقة: $e', stackTrace);
    }
  }

  Future<Response> _createDocumentSignature(Request request) async {
    final user = _getUser(request);
    if (user == null) {
      return ResponseHelper.unauthorized('يجب تسجيل الدخول');
    }

    final userRole = user['role'] as String;
    if (!hasPermission(userRole, Permission.writeStorage)) {
      return ResponseHelper.forbidden('ليس لديك صلاحية لتوقيع الوثائق');
    }
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final conn = await _db.connection;
      await conn.execute('''
        INSERT INTO document_signatures (
          id, document_id, signed_by, signed_by_name, signature_data, signed_at, notes
        ) VALUES (
          @id, @documentId, @signedBy, @signedByName, @signatureData, @signedAt, @notes
        )
      ''', substitutionValues: {
        'id': data['id'],
        'documentId': data['documentId'],
        'signedBy': data['signedBy'],
        'signedByName': data['signedByName'],
        'signatureData': data['signatureData'],
        'signedAt': data['signedAt'] ?? DateTime.now().millisecondsSinceEpoch,
        'notes': data['notes'],
      });

      return ResponseHelper.success({'message': 'تم إنشاء التوقيع بنجاح'});
    } catch (e, stackTrace) {
      AppLogger.error('Create document signature error', e, stackTrace);
      return ResponseHelper.error('خطأ في إنشاء التوقيع: $e', stackTrace);
    }
  }

  Future<Response> _getDocumentSignature(Request request, String documentId) async {
    final user = _getUser(request);
    if (user == null) {
      return ResponseHelper.unauthorized('يجب تسجيل الدخول');
    }

    final userRole = user['role'] as String;
    if (!hasPermission(userRole, Permission.readStorage)) {
      return ResponseHelper.forbidden('ليس لديك صلاحية للوصول إلى التوقيعات');
    }
    try {
      final conn = await _db.connection;
      final results = await conn.query(
        'SELECT * FROM document_signatures WHERE document_id = @documentId ORDER BY signed_at DESC LIMIT 1',
        substitutionValues: {'documentId': documentId},
      );

      if (results.isEmpty) {
        return ResponseHelper.notFound('التوقيع غير موجود');
      }

      final row = results.first;
      final signature = {
        'id': row[0],
        'documentId': row[1],
        'signedBy': row[2],
        'signedByName': row[3],
        'signatureData': row[4],
        'signedAt': row[5],
        'notes': row[6],
      };

      return ResponseHelper.success(signature);
    } catch (e, stackTrace) {
      AppLogger.error('Get document signature error', e, stackTrace);
      return ResponseHelper.error('خطأ في جلب التوقيع: $e', stackTrace);
    }
  }

  Future<Response> _getDocumentSignatures(Request request) async {
    final user = _getUser(request);
    if (user == null) {
      return ResponseHelper.unauthorized('يجب تسجيل الدخول');
    }

    final userRole = user['role'] as String;
    if (!hasPermission(userRole, Permission.readStorage)) {
      return ResponseHelper.forbidden('ليس لديك صلاحية للوصول إلى التوقيعات');
    }
    try {
      final queryParams = request.url.queryParameters;
      final conn = await _db.connection;

      String query = 'SELECT * FROM document_signatures WHERE 1=1';
      final values = <String, dynamic>{};

      if (queryParams.containsKey('documentId')) {
        query += ' AND document_id = @documentId';
        values['documentId'] = queryParams['documentId']!;
      }

      query += ' ORDER BY signed_at DESC';

      final results = await conn.query(query, substitutionValues: values.isEmpty ? null : values);

      final signatures = results.map((row) {
        return {
          'id': row[0],
          'documentId': row[1],
          'signedBy': row[2],
          'signedByName': row[3],
          'signatureData': row[4],
          'signedAt': row[5],
          'notes': row[6],
        };
      }).toList();

      return ResponseHelper.list(data: signatures);
    } catch (e, stackTrace) {
      AppLogger.error('Get document signatures error', e, stackTrace);
      return ResponseHelper.error('خطأ في جلب التوقيعات: $e', stackTrace);
    }
  }
}

