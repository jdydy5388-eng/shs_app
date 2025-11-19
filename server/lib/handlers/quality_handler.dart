import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database/database_service.dart';
import '../utils/response_helper.dart';
import '../logger/app_logger.dart';

class QualityHandler {
  final DatabaseService _db = DatabaseService();

  Router get router {
    final router = Router();

    // KPIs
    router.get('/kpis', _getKPIs);
    router.get('/kpis/<kpiId>', _getKPI);
    router.post('/kpis', _createKPI);
    router.put('/kpis/<kpiId>', _updateKPI);

    // Medical Incidents
    router.get('/incidents', _getIncidents);
    router.post('/incidents', _createIncident);

    // Complaints
    router.get('/complaints', _getComplaints);

    // Accreditation Requirements
    router.get('/accreditation-requirements', _getAccreditationRequirements);

    return router;
  }

  Future<Response> _getKPIs(Request request) async {
    try {
      final queryParams = request.url.queryParameters;
      final conn = await _db.connection;

      String query = 'SELECT * FROM quality_kpis WHERE 1=1';
      final values = <String, dynamic>{};

      if (queryParams.containsKey('category')) {
        query += ' AND category = @category';
        values['category'] = queryParams['category']!;
      }

      query += ' ORDER BY created_at DESC';

      final results = await conn.query(query, substitutionValues: values.isEmpty ? null : values);

      final kpis = results.map((row) {
        return {
          'id': row[0],
          'name': row[1],
          'arabicName': row[2],
          'description': row[3],
          'category': row[4],
          'type': row[5],
          'targetValue': row[6],
          'currentValue': row[7],
          'unit': row[8],
          'lastUpdated': row[9],
          'updatedBy': row[10],
          'metadata': row[11] != null ? jsonDecode(row[11] as String) : null,
          'createdAt': row[12],
          'updatedAt': row[13],
        };
      }).toList();

      return ResponseHelper.list(data: kpis);
    } catch (e, stackTrace) {
      AppLogger.error('Get KPIs error', e, stackTrace);
      return ResponseHelper.error(message: 'خطأ في جلب مؤشرات الجودة: $e', error: stackTrace);
    }
  }

  Future<Response> _getKPI(Request request, String kpiId) async {
    try {
      final conn = await _db.connection;
      final results = await conn.query(
        'SELECT * FROM quality_kpis WHERE id = @id',
        substitutionValues: {'id': kpiId},
      );

      if (results.isEmpty) {
        return ResponseHelper.notFound('المؤشر غير موجود');
      }

      final row = results.first;
      final kpi = {
        'id': row[0],
        'name': row[1],
        'arabicName': row[2],
        'description': row[3],
        'category': row[4],
        'type': row[5],
        'targetValue': row[6],
        'currentValue': row[7],
        'unit': row[8],
        'lastUpdated': row[9],
        'updatedBy': row[10],
        'metadata': row[11] != null ? jsonDecode(row[11] as String) : null,
        'createdAt': row[12],
        'updatedAt': row[13],
      };

      return ResponseHelper.success(data: kpi);
    } catch (e, stackTrace) {
      AppLogger.error('Get KPI error', e, stackTrace);
      return ResponseHelper.error(message: 'خطأ في جلب المؤشر: $e', error: stackTrace);
    }
  }

  Future<Response> _createKPI(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final conn = await _db.connection;
      await conn.execute('''
        INSERT INTO quality_kpis (
          id, name, arabic_name, description, category, type,
          target_value, current_value, unit, last_updated, updated_by,
          metadata, created_at, updated_at
        ) VALUES (
          @id, @name, @arabicName, @description, @category, @type,
          @targetValue, @currentValue, @unit, @lastUpdated, @updatedBy,
          @metadata, @createdAt, @updatedAt
        )
      ''', substitutionValues: {
        'id': data['id'],
        'name': data['name'],
        'arabicName': data['arabicName'],
        'description': data['description'],
        'category': data['category'],
        'type': data['type'],
        'targetValue': data['targetValue'],
        'currentValue': data['currentValue'],
        'unit': data['unit'],
        'lastUpdated': data['lastUpdated'],
        'updatedBy': data['updatedBy'],
        'metadata': data['metadata'] != null ? jsonEncode(data['metadata']) : null,
        'createdAt': data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
        'updatedAt': data['updatedAt'],
      });

      return ResponseHelper.success(data: {'message': 'تم إنشاء مؤشر الجودة بنجاح'});
    } catch (e, stackTrace) {
      AppLogger.error('Create KPI error', e, stackTrace);
      return ResponseHelper.error(message: 'خطأ في إنشاء مؤشر الجودة: $e', error: stackTrace);
    }
  }

  Future<Response> _updateKPI(Request request, String kpiId) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final conn = await _db.connection;
      final updates = <String>[];
      final values = <String, dynamic>{};

      if (data.containsKey('currentValue')) {
        updates.add('current_value = @currentValue');
        values['currentValue'] = data['currentValue'];
      }
      if (data.containsKey('lastUpdated')) {
        updates.add('last_updated = @lastUpdated');
        values['lastUpdated'] = data['lastUpdated'];
      }
      if (data.containsKey('updatedBy')) {
        updates.add('updated_by = @updatedBy');
        values['updatedBy'] = data['updatedBy'];
      }

      updates.add('updated_at = @updatedAt');
      values['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
      values['id'] = kpiId;

      await conn.execute(
        'UPDATE quality_kpis SET ${updates.join(', ')} WHERE id = @id',
        substitutionValues: values,
      );

      return ResponseHelper.success(data: {'message': 'تم تحديث مؤشر الجودة بنجاح'});
    } catch (e, stackTrace) {
      AppLogger.error('Update KPI error', e, stackTrace);
      return ResponseHelper.error(message: 'خطأ في تحديث مؤشر الجودة: $e', error: stackTrace);
    }
  }

  Future<Response> _getIncidents(Request request) async {
    try {
      final conn = await _db.connection;
      final results = await conn.query(
        'SELECT * FROM medical_incidents ORDER BY incident_date DESC',
      );

      final incidents = results.map((row) {
        return {
          'id': row[0],
          'patientId': row[1],
          'patientName': row[2],
          'type': row[3],
          'severity': row[4],
          'status': row[5],
          'description': row[6],
          'location': row[7],
          'incidentDate': row[8],
          'reportedDate': row[9],
          'reportedBy': row[10],
          'reportedByName': row[11],
          'investigationNotes': row[12],
          'resolutionNotes': row[13],
          'resolvedBy': row[14],
          'resolvedAt': row[15],
          'affectedPersons': row[16] != null ? jsonDecode(row[16] as String) : null,
          'additionalData': row[17] != null ? jsonDecode(row[17] as String) : null,
          'createdAt': row[18],
          'updatedAt': row[19],
        };
      }).toList();

      return ResponseHelper.list(data: incidents);
    } catch (e, stackTrace) {
      AppLogger.error('Get incidents error', e, stackTrace);
      return ResponseHelper.error(message: 'خطأ في جلب الحوادث: $e', error: stackTrace);
    }
  }

  Future<Response> _createIncident(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final conn = await _db.connection;
      await conn.execute('''
        INSERT INTO medical_incidents (
          id, patient_id, patient_name, type, severity, status,
          description, location, incident_date, reported_date,
          reported_by, reported_by_name, investigation_notes,
          resolution_notes, resolved_by, resolved_at,
          affected_persons, additional_data, created_at, updated_at
        ) VALUES (
          @id, @patientId, @patientName, @type, @severity, @status,
          @description, @location, @incidentDate, @reportedDate,
          @reportedBy, @reportedByName, @investigationNotes,
          @resolutionNotes, @resolvedBy, @resolvedAt,
          @affectedPersons, @additionalData, @createdAt, @updatedAt
        )
      ''', substitutionValues: {
        'id': data['id'],
        'patientId': data['patientId'],
        'patientName': data['patientName'],
        'type': data['type'],
        'severity': data['severity'],
        'status': data['status'] ?? 'reported',
        'description': data['description'],
        'location': data['location'],
        'incidentDate': data['incidentDate'],
        'reportedDate': data['reportedDate'],
        'reportedBy': data['reportedBy'],
        'reportedByName': data['reportedByName'],
        'investigationNotes': data['investigationNotes'],
        'resolutionNotes': data['resolutionNotes'],
        'resolvedBy': data['resolvedBy'],
        'resolvedAt': data['resolvedAt'],
        'affectedPersons': data['affectedPersons'] != null ? jsonEncode(data['affectedPersons']) : null,
        'additionalData': data['additionalData'] != null ? jsonEncode(data['additionalData']) : null,
        'createdAt': data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
        'updatedAt': data['updatedAt'],
      });

      return ResponseHelper.success(data: {'message': 'تم إنشاء الحادث بنجاح'});
    } catch (e, stackTrace) {
      AppLogger.error('Create incident error', e, stackTrace);
      return ResponseHelper.error(message: 'خطأ في إنشاء الحادث: $e', error: stackTrace);
    }
  }

  Future<Response> _getComplaints(Request request) async {
    try {
      final conn = await _db.connection;
      final results = await conn.query(
        'SELECT * FROM complaints ORDER BY complaint_date DESC',
      );

      final complaints = results.map((row) {
        return {
          'id': row[0],
          'patientId': row[1],
          'patientName': row[2],
          'complainantName': row[3],
          'complainantPhone': row[4],
          'complainantEmail': row[5],
          'category': row[6],
          'status': row[7],
          'subject': row[8],
          'description': row[9],
          'department': row[10],
          'assignedTo': row[11],
          'assignedToName': row[12],
          'response': row[13],
          'respondedBy': row[14],
          'respondedAt': row[15],
          'complaintDate': row[16],
          'resolvedAt': row[17],
          'additionalData': row[18] != null ? jsonDecode(row[18] as String) : null,
          'createdAt': row[19],
          'updatedAt': row[20],
        };
      }).toList();

      return ResponseHelper.list(data: complaints);
    } catch (e, stackTrace) {
      AppLogger.error('Get complaints error', e, stackTrace);
      return ResponseHelper.error(message: 'خطأ في جلب الشكاوى: $e', error: stackTrace);
    }
  }

  Future<Response> _getAccreditationRequirements(Request request) async {
    try {
      final conn = await _db.connection;
      final results = await conn.query(
        'SELECT * FROM accreditation_requirements ORDER BY created_at DESC',
      );

      final requirements = results.map((row) {
        return {
          'id': row[0],
          'standard': row[1],
          'requirementCode': row[2],
          'title': row[3],
          'description': row[4],
          'status': row[5],
          'evidence': row[6],
          'notes': row[7],
          'complianceDate': row[8],
          'certificationDate': row[9],
          'assignedTo': row[10],
          'assignedToName': row[11],
          'dueDate': row[12],
          'metadata': row[13] != null ? jsonDecode(row[13] as String) : null,
          'createdAt': row[14],
          'updatedAt': row[15],
        };
      }).toList();

      return ResponseHelper.list(data: requirements);
    } catch (e, stackTrace) {
      AppLogger.error('Get accreditation requirements error', e, stackTrace);
      return ResponseHelper.error(message: 'خطأ في جلب متطلبات الاعتماد: $e', error: stackTrace);
    }
  }
}

