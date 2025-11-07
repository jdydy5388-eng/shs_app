import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';
import '../database/database_service.dart';
import '../utils/response_helper.dart';
import '../logger/app_logger.dart';

class MedicalRecordsHandler {
  Router get router {
    final router = Router();

    router.get('/', _getMedicalRecords);
    router.get('/<recordId>', _getMedicalRecord);
    router.post('/', _createMedicalRecord);
    router.put('/<recordId>', _updateMedicalRecord);
    router.delete('/<recordId>', _deleteMedicalRecord);

    return router;
  }

  Future<Response> _getMedicalRecords(Request request) async {
    try {
      final params = request.url.queryParameters;
      final patientId = params['patientId'];

      final conn = await DatabaseService().connection;
      
      String query = '''
        SELECT id, patient_id, doctor_id, doctor_name, type, title, description,
               date, file_urls, additional_data, created_at
        FROM medical_records
        WHERE 1=1
      ''';
      
      final parameters = <String, dynamic>{};
      
      if (patientId != null) {
        query += ' AND patient_id = @patientId';
        parameters['patientId'] = patientId;
      }
      
      query += ' ORDER BY date DESC';

      final records = await conn.query(
        query,
        substitutionValues: parameters.isEmpty ? null : parameters,
      );

      final result = records.map((record) {
        // file_urls و additional_data قد تكون JSONB (Map/List) أو String
        dynamic fileUrlsRaw = record[8];
        List<dynamic>? fileUrls;
        if (fileUrlsRaw != null) {
          if (fileUrlsRaw is String) {
            try {
              final decoded = jsonDecode(fileUrlsRaw);
              if (decoded is List) fileUrls = decoded;
            } catch (_) {
              fileUrls = null;
            }
          } else if (fileUrlsRaw is List) {
            fileUrls = fileUrlsRaw;
          }
        }

        dynamic additionalDataRaw = record[9];
        Map<String, dynamic>? additionalData;
        if (additionalDataRaw != null) {
          if (additionalDataRaw is String) {
            try {
              final decoded = jsonDecode(additionalDataRaw);
              if (decoded is Map<String, dynamic>) additionalData = decoded;
            } catch (_) {
              additionalData = null;
            }
          } else if (additionalDataRaw is Map) {
            additionalData = Map<String, dynamic>.from(additionalDataRaw as Map);
          }
        }

        return {
          'id': record[0],
          'patientId': record[1],
          'doctorId': record[2],
          'doctorName': record[3],
          'type': record[4],
          'title': record[5],
          'description': record[6],
          'date': record[7],
          'fileUrls': fileUrls,
          'additionalData': additionalData,
          'createdAt': record[10],
        };
      }).toList();

      return ResponseHelper.list(data: result);
    } catch (e) {
      AppLogger.error('Get medical records error', e);
      return ResponseHelper.error(message: 'Failed to get medical records: $e');
    }
  }

  Future<Response> _getMedicalRecord(Request request, String recordId) async {
    try {
      final conn = await DatabaseService().connection;
      
      final record = await conn.query(
        '''
        SELECT id, patient_id, doctor_id, doctor_name, type, title, description,
               date, file_urls, additional_data, created_at
        FROM medical_records
        WHERE id = @id
        ''',
        substitutionValues: {'id': recordId},
      );

      if (record.isEmpty) {
        return ResponseHelper.error(
          message: 'Medical record not found',
          statusCode: 404,
        );
      }

      final r = record.first;
      // file_urls و additional_data قد تكون JSONB (Map/List) أو String
      dynamic fileUrlsRaw = r[8];
      List<dynamic>? fileUrls;
      if (fileUrlsRaw != null) {
        if (fileUrlsRaw is String) {
          try {
            final decoded = jsonDecode(fileUrlsRaw);
            if (decoded is List) fileUrls = decoded;
          } catch (_) {
            fileUrls = null;
          }
        } else if (fileUrlsRaw is List) {
          fileUrls = fileUrlsRaw;
        }
      }

      dynamic additionalDataRaw = r[9];
      Map<String, dynamic>? additionalData;
      if (additionalDataRaw != null) {
        if (additionalDataRaw is String) {
          try {
            final decoded = jsonDecode(additionalDataRaw);
            if (decoded is Map<String, dynamic>) additionalData = decoded;
          } catch (_) {
            additionalData = null;
          }
        } else if (additionalDataRaw is Map) {
          additionalData = Map<String, dynamic>.from(additionalDataRaw as Map);
        }
      }

      return ResponseHelper.success(data: {
        'id': r[0],
        'patientId': r[1],
        'doctorId': r[2],
        'doctorName': r[3],
        'type': r[4],
        'title': r[5],
        'description': r[6],
        'date': r[7],
        'fileUrls': fileUrls,
        'additionalData': additionalData,
        'createdAt': r[10],
      });
    } catch (e) {
      AppLogger.error('Get medical record error', e);
      return ResponseHelper.error(message: 'Failed to get medical record: $e');
    }
  }

  Future<Response> _createMedicalRecord(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      await conn.execute(
        '''
        INSERT INTO medical_records 
        (id, patient_id, doctor_id, doctor_name, type, title, description,
         date, file_urls, additional_data, created_at)
        VALUES (@id, @patientId, @doctorId, @doctorName, @type, @title, @description,
                @date, @fileUrls, @additionalData, @createdAt)
        ''',
        substitutionValues: {
          'id': body['id'],
          'patientId': body['patientId'],
          'doctorId': body['doctorId'],
          'doctorName': body['doctorName'],
          'type': body['type'],
          'title': body['title'],
          'description': body['description'],
          'date': body['date'],
          'fileUrls': body['fileUrls'] != null ? jsonEncode(body['fileUrls']) : null,
          'additionalData': body['additionalData'] != null ? jsonEncode(body['additionalData']) : null,
          'createdAt': body['createdAt'],
        },
      );

      return ResponseHelper.success(data: {'message': 'Medical record created successfully'});
    } catch (e) {
      AppLogger.error('Create medical record error', e);
      return ResponseHelper.error(message: 'Failed to create medical record: $e');
    }
  }

  Future<Response> _updateMedicalRecord(Request request, String recordId) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      final updates = <String, dynamic>{};
      if (body.containsKey('title')) updates['title'] = body['title'];
      if (body.containsKey('description')) updates['description'] = body['description'];
      if (body.containsKey('fileUrls')) {
        updates['file_urls'] = jsonEncode(body['fileUrls']);
      }
      if (body.containsKey('additionalData')) {
        updates['additional_data'] = jsonEncode(body['additionalData']);
      }

      if (updates.isEmpty) {
        return ResponseHelper.error(message: 'No fields to update');
      }

      final setClause = updates.keys.map((k) => '$k = @$k').join(', ');
      
      await conn.execute(
        '''
        UPDATE medical_records 
        SET $setClause
        WHERE id = @id
        ''',
        substitutionValues: {
          'id': recordId,
          ...updates,
        },
      );

      return ResponseHelper.success(data: {'message': 'Medical record updated successfully'});
    } catch (e) {
      AppLogger.error('Update medical record error', e);
      return ResponseHelper.error(message: 'Failed to update medical record: $e');
    }
  }

  Future<Response> _deleteMedicalRecord(Request request, String recordId) async {
    try {
      final conn = await DatabaseService().connection;
      
      await conn.execute(
        'DELETE FROM medical_records WHERE id = @id',
        substitutionValues: {'id': recordId},
      );

      return ResponseHelper.success(data: {'message': 'Medical record deleted successfully'});
    } catch (e) {
      AppLogger.error('Delete medical record error', e);
      return ResponseHelper.error(message: 'Failed to delete medical record: $e');
    }
  }
}

