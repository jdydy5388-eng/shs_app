import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database/database_service.dart';
import '../utils/response_helper.dart';
import '../logger/app_logger.dart';

class MaintenanceHandler {
  final DatabaseService _db = DatabaseService();

  Router get router {
    final router = Router();

    // Maintenance Requests
    router.get('/requests', _getMaintenanceRequests);
    router.post('/requests', _createMaintenanceRequest);

    // Scheduled Maintenance
    router.get('/scheduled', _getScheduledMaintenances);
    router.post('/scheduled', _createScheduledMaintenance);

    // Equipment Status
    router.get('/equipment-status', _getEquipmentStatuses);
    router.post('/equipment-status', _createEquipmentStatus);

    // Maintenance Vendors
    router.get('/vendors', _getMaintenanceVendors);
    router.post('/vendors', _createMaintenanceVendor);

    return router;
  }

  Future<Response> _getMaintenanceRequests(Request request) async {
    try {
      final queryParams = request.url.queryParameters;
      final conn = await _db.connection;

      String query = 'SELECT * FROM maintenance_requests WHERE 1=1';
      final values = <String, dynamic>{};

      if (queryParams.containsKey('status')) {
        query += ' AND status = @status';
        values['status'] = queryParams['status']!;
      }

      query += ' ORDER BY reported_date DESC';

      final results = await conn.query(query, substitutionValues: values.isEmpty ? null : values);

      final requests = results.map((row) {
        return {
          'id': row[0],
          'equipmentId': row[1],
          'equipmentName': row[2],
          'location': row[3],
          'type': row[4],
          'status': row[5],
          'priority': row[6],
          'description': row[7],
          'reportedBy': row[8],
          'reportedByName': row[9],
          'reportedDate': row[10],
          'assignedTo': row[11],
          'assignedToName': row[12],
          'assignedDate': row[13],
          'scheduledDate': row[14],
          'completedDate': row[15],
          'completedBy': row[16],
          'completedByName': row[17],
          'workPerformed': row[18],
          'notes': row[19],
          'cost': row[20],
          'attachments': row[21] != null ? jsonDecode(row[21] as String) : null,
          'additionalData': row[22] != null ? jsonDecode(row[22] as String) : null,
          'createdAt': row[23],
          'updatedAt': row[24],
        };
      }).toList();

      return ResponseHelper.list(data: requests);
    } catch (e, stackTrace) {
      AppLogger.error('Get maintenance requests error', e, stackTrace);
      return ResponseHelper.error('خطأ في جلب طلبات الصيانة: $e', stackTrace);
    }
  }

  Future<Response> _createMaintenanceRequest(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final conn = await _db.connection;
      await conn.execute('''
        INSERT INTO maintenance_requests (
          id, equipment_id, equipment_name, location, type, status, priority,
          description, reported_by, reported_by_name, reported_date,
          assigned_to, assigned_to_name, assigned_date, scheduled_date,
          completed_date, completed_by, completed_by_name, work_performed,
          notes, cost, attachments, additional_data, created_at, updated_at
        ) VALUES (
          @id, @equipmentId, @equipmentName, @location, @type, @status, @priority,
          @description, @reportedBy, @reportedByName, @reportedDate,
          @assignedTo, @assignedToName, @assignedDate, @scheduledDate,
          @completedDate, @completedBy, @completedByName, @workPerformed,
          @notes, @cost, @attachments, @additionalData, @createdAt, @updatedAt
        )
      ''', substitutionValues: {
        'id': data['id'],
        'equipmentId': data['equipmentId'],
        'equipmentName': data['equipmentName'],
        'location': data['location'],
        'type': data['type'],
        'status': data['status'] ?? 'pending',
        'priority': data['priority'] ?? 'medium',
        'description': data['description'],
        'reportedBy': data['reportedBy'],
        'reportedByName': data['reportedByName'],
        'reportedDate': data['reportedDate'] ?? DateTime.now().millisecondsSinceEpoch,
        'assignedTo': data['assignedTo'],
        'assignedToName': data['assignedToName'],
        'assignedDate': data['assignedDate'],
        'scheduledDate': data['scheduledDate'],
        'completedDate': data['completedDate'],
        'completedBy': data['completedBy'],
        'completedByName': data['completedByName'],
        'workPerformed': data['workPerformed'],
        'notes': data['notes'],
        'cost': data['cost'],
        'attachments': data['attachments'] != null ? jsonEncode(data['attachments']) : null,
        'additionalData': data['additionalData'] != null ? jsonEncode(data['additionalData']) : null,
        'createdAt': data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
        'updatedAt': data['updatedAt'],
      });

      return ResponseHelper.success({'message': 'تم إنشاء طلب الصيانة بنجاح'});
    } catch (e, stackTrace) {
      AppLogger.error('Create maintenance request error', e, stackTrace);
      return ResponseHelper.error('خطأ في إنشاء طلب الصيانة: $e', stackTrace);
    }
  }

  Future<Response> _getScheduledMaintenances(Request request) async {
    try {
      final conn = await _db.connection;
      final results = await conn.query(
        'SELECT * FROM scheduled_maintenances ORDER BY next_due_date ASC',
      );

      final maintenances = results.map((row) {
        return {
          'id': row[0],
          'equipmentId': row[1],
          'equipmentName': row[2],
          'maintenanceType': row[3],
          'description': row[4],
          'frequency': row[5],
          'intervalDays': row[6],
          'nextDueDate': row[7],
          'lastPerformedDate': row[8],
          'lastPerformedBy': row[9],
          'status': row[10],
          'assignedTo': row[11],
          'assignedToName': row[12],
          'notes': row[13],
          'metadata': row[14] != null ? jsonDecode(row[14] as String) : null,
          'createdAt': row[15],
          'updatedAt': row[16],
        };
      }).toList();

      return ResponseHelper.list(data: maintenances);
    } catch (e, stackTrace) {
      AppLogger.error('Get scheduled maintenances error', e, stackTrace);
      return ResponseHelper.error('خطأ في جلب الصيانة المجدولة: $e', stackTrace);
    }
  }

  Future<Response> _createScheduledMaintenance(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final conn = await _db.connection;
      await conn.execute('''
        INSERT INTO scheduled_maintenances (
          id, equipment_id, equipment_name, maintenance_type, description,
          frequency, interval_days, next_due_date, last_performed_date,
          last_performed_by, status, assigned_to, assigned_to_name,
          notes, metadata, created_at, updated_at
        ) VALUES (
          @id, @equipmentId, @equipmentName, @maintenanceType, @description,
          @frequency, @intervalDays, @nextDueDate, @lastPerformedDate,
          @lastPerformedBy, @status, @assignedTo, @assignedToName,
          @notes, @metadata, @createdAt, @updatedAt
        )
      ''', substitutionValues: {
        'id': data['id'],
        'equipmentId': data['equipmentId'],
        'equipmentName': data['equipmentName'],
        'maintenanceType': data['maintenanceType'],
        'description': data['description'],
        'frequency': data['frequency'],
        'intervalDays': data['intervalDays'],
        'nextDueDate': data['nextDueDate'],
        'lastPerformedDate': data['lastPerformedDate'],
        'lastPerformedBy': data['lastPerformedBy'],
        'status': data['status'] ?? 'scheduled',
        'assignedTo': data['assignedTo'],
        'assignedToName': data['assignedToName'],
        'notes': data['notes'],
        'metadata': data['metadata'] != null ? jsonEncode(data['metadata']) : null,
        'createdAt': data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
        'updatedAt': data['updatedAt'],
      });

      return ResponseHelper.success({'message': 'تم جدولة الصيانة بنجاح'});
    } catch (e, stackTrace) {
      AppLogger.error('Create scheduled maintenance error', e, stackTrace);
      return ResponseHelper.error('خطأ في جدولة الصيانة: $e', stackTrace);
    }
  }

  Future<Response> _getEquipmentStatuses(Request request) async {
    try {
      final conn = await _db.connection;
      final results = await conn.query(
        'SELECT * FROM equipment_statuses ORDER BY last_maintenance_date DESC',
      );

      final statuses = results.map((row) {
        return {
          'id': row[0],
          'equipmentId': row[1],
          'equipmentName': row[2],
          'condition': row[3],
          'location': row[4],
          'lastMaintenanceDate': row[5],
          'nextMaintenanceDate': row[6],
          'totalMaintenanceCount': row[7],
          'totalMaintenanceCost': row[8],
          'currentIssues': row[9],
          'notes': row[10],
          'statusData': row[11] != null ? jsonDecode(row[11] as String) : null,
          'createdAt': row[12],
          'updatedAt': row[13],
        };
      }).toList();

      return ResponseHelper.list(data: statuses);
    } catch (e, stackTrace) {
      AppLogger.error('Get equipment statuses error', e, stackTrace);
      return ResponseHelper.error('خطأ في جلب حالة المعدات: $e', stackTrace);
    }
  }

  Future<Response> _createEquipmentStatus(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final conn = await _db.connection;
      await conn.execute('''
        INSERT INTO equipment_statuses (
          id, equipment_id, equipment_name, condition, location,
          last_maintenance_date, next_maintenance_date,
          total_maintenance_count, total_maintenance_cost,
          current_issues, notes, status_data, created_at, updated_at
        ) VALUES (
          @id, @equipmentId, @equipmentName, @condition, @location,
          @lastMaintenanceDate, @nextMaintenanceDate,
          @totalMaintenanceCount, @totalMaintenanceCost,
          @currentIssues, @notes, @statusData, @createdAt, @updatedAt
        )
      ''', substitutionValues: {
        'id': data['id'],
        'equipmentId': data['equipmentId'],
        'equipmentName': data['equipmentName'],
        'condition': data['condition'],
        'location': data['location'],
        'lastMaintenanceDate': data['lastMaintenanceDate'] ?? DateTime.now().millisecondsSinceEpoch,
        'nextMaintenanceDate': data['nextMaintenanceDate'],
        'totalMaintenanceCount': data['totalMaintenanceCount'],
        'totalMaintenanceCost': data['totalMaintenanceCost'],
        'currentIssues': data['currentIssues'],
        'notes': data['notes'],
        'statusData': data['statusData'] != null ? jsonEncode(data['statusData']) : null,
        'createdAt': data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
        'updatedAt': data['updatedAt'],
      });

      return ResponseHelper.success({'message': 'تم إنشاء حالة المعدات بنجاح'});
    } catch (e, stackTrace) {
      AppLogger.error('Create equipment status error', e, stackTrace);
      return ResponseHelper.error('خطأ في إنشاء حالة المعدات: $e', stackTrace);
    }
  }

  Future<Response> _getMaintenanceVendors(Request request) async {
    try {
      final conn = await _db.connection;
      final results = await conn.query(
        'SELECT * FROM maintenance_vendors ORDER BY name ASC',
      );

      final vendors = results.map((row) {
        return {
          'id': row[0],
          'name': row[1],
          'type': row[2],
          'contactPerson': row[3],
          'email': row[4],
          'phone': row[5],
          'address': row[6],
          'specialization': row[7],
          'notes': row[8],
          'isActive': (row[9] as int) == 1,
          'additionalInfo': row[10] != null ? jsonDecode(row[10] as String) : null,
          'createdAt': row[11],
          'updatedAt': row[12],
        };
      }).toList();

      return ResponseHelper.list(data: vendors);
    } catch (e, stackTrace) {
      AppLogger.error('Get maintenance vendors error', e, stackTrace);
      return ResponseHelper.error('خطأ في جلب موردين الصيانة: $e', stackTrace);
    }
  }

  Future<Response> _createMaintenanceVendor(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final conn = await _db.connection;
      await conn.execute('''
        INSERT INTO maintenance_vendors (
          id, name, type, contact_person, email, phone,
          address, specialization, notes, is_active,
          additional_info, created_at, updated_at
        ) VALUES (
          @id, @name, @type, @contactPerson, @email, @phone,
          @address, @specialization, @notes, @isActive,
          @additionalInfo, @createdAt, @updatedAt
        )
      ''', substitutionValues: {
        'id': data['id'],
        'name': data['name'],
        'type': data['type'],
        'contactPerson': data['contactPerson'],
        'email': data['email'],
        'phone': data['phone'],
        'address': data['address'],
        'specialization': data['specialization'],
        'notes': data['notes'],
        'isActive': (data['isActive'] ?? true) ? 1 : 0,
        'additionalInfo': data['additionalInfo'] != null ? jsonEncode(data['additionalInfo']) : null,
        'createdAt': data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
        'updatedAt': data['updatedAt'],
      });

      return ResponseHelper.success({'message': 'تم إنشاء المورد بنجاح'});
    } catch (e, stackTrace) {
      AppLogger.error('Create maintenance vendor error', e, stackTrace);
      return ResponseHelper.error('خطأ في إنشاء المورد: $e', stackTrace);
    }
  }
}
