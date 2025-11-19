import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database/database_service.dart';
import '../utils/response_helper.dart';
import '../logger/app_logger.dart';

class HRHandler {
  final DatabaseService _db = DatabaseService();

  Router get router {
    final router = Router();

    // Employees
    router.get('/employees', _getEmployees);
    router.get('/employees/<employeeId>', _getEmployee);
    router.post('/employees', _createEmployee);

    // Leave Requests
    router.get('/leave-requests', _getLeaveRequests);
    router.post('/leave-requests', _createLeaveRequest);

    // Payroll
    router.get('/payrolls', _getPayrolls);
    router.post('/payrolls', _createPayroll);

    // Training
    router.get('/trainings', _getTrainings);
    router.post('/trainings', _createTraining);

    // Certifications
    router.get('/certifications', _getCertifications);
    router.post('/certifications', _createCertification);

    return router;
  }

  Future<Response> _getEmployees(Request request) async {
    try {
      final queryParams = request.url.queryParameters;
      final conn = await _db.connection;

      String query = 'SELECT * FROM employees WHERE 1=1';
      final values = <String, dynamic>{};

      if (queryParams.containsKey('status')) {
        query += ' AND status = @status';
        values['status'] = queryParams['status']!;
      }

      query += ' ORDER BY hire_date DESC';

      final results = await conn.query(query, substitutionValues: values.isEmpty ? null : values);

      final employees = results.map((row) {
        return {
          'id': row[0],
          'userId': row[1],
          'employeeNumber': row[2],
          'department': row[3],
          'position': row[4],
          'employmentType': row[5],
          'status': row[6],
          'hireDate': row[7],
          'terminationDate': row[8],
          'salary': row[9],
          'managerId': row[10],
          'managerName': row[11],
          'additionalInfo': row[12] != null ? jsonDecode(row[12] as String) : null,
          'createdAt': row[13],
          'updatedAt': row[14],
        };
      }).toList();

      return ResponseHelper.list(data: employees);
    } catch (e, stackTrace) {
      AppLogger.error('Get employees error', e, stackTrace);
      return ResponseHelper.error(message: 'خطأ في جلب الموظفين: $e', error: stackTrace);
    }
  }

  Future<Response> _getEmployee(Request request, String employeeId) async {
    try {
      final conn = await _db.connection;
      final results = await conn.query(
        'SELECT * FROM employees WHERE id = @id',
        substitutionValues: {'id': employeeId},
      );

      if (results.isEmpty) {
        return ResponseHelper.notFound('الموظف غير موجود');
      }

      final row = results.first;
      final employee = {
        'id': row[0],
        'userId': row[1],
        'employeeNumber': row[2],
        'department': row[3],
        'position': row[4],
        'employmentType': row[5],
        'status': row[6],
        'hireDate': row[7],
        'terminationDate': row[8],
        'salary': row[9],
        'managerId': row[10],
        'managerName': row[11],
        'additionalInfo': row[12] != null ? jsonDecode(row[12] as String) : null,
        'createdAt': row[13],
        'updatedAt': row[14],
      };

      return ResponseHelper.success(data: employee);
    } catch (e, stackTrace) {
      AppLogger.error('Get employee error', e, stackTrace);
      return ResponseHelper.error(message: 'خطأ في جلب الموظف: $e', error: stackTrace);
    }
  }

  Future<Response> _createEmployee(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final conn = await _db.connection;
      await conn.execute('''
        INSERT INTO employees (
          id, user_id, employee_number, department, position,
          employment_type, status, hire_date, termination_date,
          salary, manager_id, manager_name, additional_info,
          created_at, updated_at
        ) VALUES (
          @id, @userId, @employeeNumber, @department, @position,
          @employmentType, @status, @hireDate, @terminationDate,
          @salary, @managerId, @managerName, @additionalInfo,
          @createdAt, @updatedAt
        )
      ''', substitutionValues: {
        'id': data['id'],
        'userId': data['userId'],
        'employeeNumber': data['employeeNumber'],
        'department': data['department'],
        'position': data['position'],
        'employmentType': data['employmentType'],
        'status': data['status'] ?? 'active',
        'hireDate': data['hireDate'],
        'terminationDate': data['terminationDate'],
        'salary': data['salary'],
        'managerId': data['managerId'],
        'managerName': data['managerName'],
        'additionalInfo': data['additionalInfo'] != null ? jsonEncode(data['additionalInfo']) : null,
        'createdAt': data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
        'updatedAt': data['updatedAt'],
      });

      return ResponseHelper.success(data: {'message': 'تم إنشاء الموظف بنجاح'});
    } catch (e, stackTrace) {
      AppLogger.error('Create employee error', e, stackTrace);
      return ResponseHelper.error(message: 'خطأ في إنشاء الموظف: $e', error: stackTrace);
    }
  }

  Future<Response> _getLeaveRequests(Request request) async {
    try {
      final queryParams = request.url.queryParameters;
      final conn = await _db.connection;

      String query = 'SELECT * FROM leave_requests WHERE 1=1';
      final values = <String, dynamic>{};

      if (queryParams.containsKey('status')) {
        query += ' AND status = @status';
        values['status'] = queryParams['status']!;
      }

      query += ' ORDER BY start_date DESC';

      final results = await conn.query(query, substitutionValues: values.isEmpty ? null : values);

      final leaves = results.map((row) {
        return {
          'id': row[0],
          'employeeId': row[1],
          'employeeName': row[2],
          'type': row[3],
          'status': row[4],
          'startDate': row[5],
          'endDate': row[6],
          'days': row[7],
          'reason': row[8],
          'notes': row[9],
          'approvedBy': row[10],
          'approvedByName': row[11],
          'approvedAt': row[12],
          'rejectionReason': row[13],
          'createdAt': row[14],
          'updatedAt': row[15],
        };
      }).toList();

      return ResponseHelper.list(data: leaves);
    } catch (e, stackTrace) {
      AppLogger.error('Get leave requests error', e, stackTrace);
      return ResponseHelper.error(message: 'خطأ في جلب طلبات الإجازة: $e', error: stackTrace);
    }
  }

  Future<Response> _createLeaveRequest(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final conn = await _db.connection;
      await conn.execute('''
        INSERT INTO leave_requests (
          id, employee_id, employee_name, type, status,
          start_date, end_date, days, reason, notes,
          approved_by, approved_by_name, approved_at,
          rejection_reason, created_at, updated_at
        ) VALUES (
          @id, @employeeId, @employeeName, @type, @status,
          @startDate, @endDate, @days, @reason, @notes,
          @approvedBy, @approvedByName, @approvedAt,
          @rejectionReason, @createdAt, @updatedAt
        )
      ''', substitutionValues: {
        'id': data['id'],
        'employeeId': data['employeeId'],
        'employeeName': data['employeeName'],
        'type': data['type'],
        'status': data['status'] ?? 'pending',
        'startDate': data['startDate'],
        'endDate': data['endDate'],
        'days': data['days'],
        'reason': data['reason'],
        'notes': data['notes'],
        'approvedBy': data['approvedBy'],
        'approvedByName': data['approvedByName'],
        'approvedAt': data['approvedAt'],
        'rejectionReason': data['rejectionReason'],
        'createdAt': data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
        'updatedAt': data['updatedAt'],
      });

      return ResponseHelper.success(data: {'message': 'تم إنشاء طلب الإجازة بنجاح'});
    } catch (e, stackTrace) {
      AppLogger.error('Create leave request error', e, stackTrace);
      return ResponseHelper.error(message: 'خطأ في إنشاء طلب الإجازة: $e', error: stackTrace);
    }
  }

  Future<Response> _getPayrolls(Request request) async {
    try {
      final queryParams = request.url.queryParameters;
      final conn = await _db.connection;

      String query = 'SELECT * FROM payrolls WHERE 1=1';
      final values = <String, dynamic>{};

      if (queryParams.containsKey('status')) {
        query += ' AND status = @status';
        values['status'] = queryParams['status']!;
      }

      query += ' ORDER BY pay_period_start DESC';

      final results = await conn.query(query, substitutionValues: values.isEmpty ? null : values);

      final payrolls = results.map((row) {
        return {
          'id': row[0],
          'employeeId': row[1],
          'employeeName': row[2],
          'payPeriodStart': row[3],
          'payPeriodEnd': row[4],
          'baseSalary': row[5],
          'allowances': row[6],
          'deductions': row[7],
          'bonuses': row[8],
          'overtime': row[9],
          'netSalary': row[10],
          'status': row[11],
          'paidDate': row[12],
          'notes': row[13],
          'createdAt': row[14],
          'updatedAt': row[15],
        };
      }).toList();

      return ResponseHelper.list(data: payrolls);
    } catch (e, stackTrace) {
      AppLogger.error('Get payrolls error', e, stackTrace);
      return ResponseHelper.error(message: 'خطأ في جلب الرواتب: $e', error: stackTrace);
    }
  }

  Future<Response> _createPayroll(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final conn = await _db.connection;
      await conn.execute('''
        INSERT INTO payrolls (
          id, employee_id, employee_name, pay_period_start, pay_period_end,
          base_salary, allowances, deductions, bonuses, overtime,
          net_salary, status, paid_date, notes, created_at, updated_at
        ) VALUES (
          @id, @employeeId, @employeeName, @payPeriodStart, @payPeriodEnd,
          @baseSalary, @allowances, @deductions, @bonuses, @overtime,
          @netSalary, @status, @paidDate, @notes, @createdAt, @updatedAt
        )
      ''', substitutionValues: {
        'id': data['id'],
        'employeeId': data['employeeId'],
        'employeeName': data['employeeName'],
        'payPeriodStart': data['payPeriodStart'],
        'payPeriodEnd': data['payPeriodEnd'],
        'baseSalary': data['baseSalary'],
        'allowances': data['allowances'],
        'deductions': data['deductions'],
        'bonuses': data['bonuses'],
        'overtime': data['overtime'],
        'netSalary': data['netSalary'],
        'status': data['status'] ?? 'draft',
        'paidDate': data['paidDate'],
        'notes': data['notes'],
        'createdAt': data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
        'updatedAt': data['updatedAt'],
      });

      return ResponseHelper.success(data: {'message': 'تم إنشاء الراتب بنجاح'});
    } catch (e, stackTrace) {
      AppLogger.error('Create payroll error', e, stackTrace);
      return ResponseHelper.error(message: 'خطأ في إنشاء الراتب: $e', error: stackTrace);
    }
  }

  Future<Response> _getTrainings(Request request) async {
    try {
      final conn = await _db.connection;
      final results = await conn.query(
        'SELECT * FROM trainings ORDER BY start_date DESC',
      );

      final trainings = results.map((row) {
        return {
          'id': row[0],
          'title': row[1],
          'description': row[2],
          'trainer': row[3],
          'location': row[4],
          'startDate': row[5],
          'endDate': row[6],
          'maxParticipants': row[7],
          'participantIds': row[8] != null ? jsonDecode(row[8] as String) : null,
          'status': row[9],
          'notes': row[10],
          'createdAt': row[11],
          'updatedAt': row[12],
        };
      }).toList();

      return ResponseHelper.list(data: trainings);
    } catch (e, stackTrace) {
      AppLogger.error('Get trainings error', e, stackTrace);
      return ResponseHelper.error(message: 'خطأ في جلب البرامج التدريبية: $e', error: stackTrace);
    }
  }

  Future<Response> _createTraining(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final conn = await _db.connection;
      await conn.execute('''
        INSERT INTO trainings (
          id, title, description, trainer, location,
          start_date, end_date, max_participants, participant_ids,
          status, notes, created_at, updated_at
        ) VALUES (
          @id, @title, @description, @trainer, @location,
          @startDate, @endDate, @maxParticipants, @participantIds,
          @status, @notes, @createdAt, @updatedAt
        )
      ''', substitutionValues: {
        'id': data['id'],
        'title': data['title'],
        'description': data['description'],
        'trainer': data['trainer'],
        'location': data['location'],
        'startDate': data['startDate'],
        'endDate': data['endDate'],
        'maxParticipants': data['maxParticipants'],
        'participantIds': data['participantIds'] != null ? jsonEncode(data['participantIds']) : null,
        'status': data['status'] ?? 'scheduled',
        'notes': data['notes'],
        'createdAt': data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
        'updatedAt': data['updatedAt'],
      });

      return ResponseHelper.success(data: {'message': 'تم إنشاء البرنامج التدريبي بنجاح'});
    } catch (e, stackTrace) {
      AppLogger.error('Create training error', e, stackTrace);
      return ResponseHelper.error(message: 'خطأ في إنشاء البرنامج التدريبي: $e', error: stackTrace);
    }
  }

  Future<Response> _getCertifications(Request request) async {
    try {
      final conn = await _db.connection;
      final results = await conn.query(
        'SELECT * FROM certifications ORDER BY expiry_date ASC',
      );

      final certifications = results.map((row) {
        return {
          'id': row[0],
          'employeeId': row[1],
          'employeeName': row[2],
          'certificateName': row[3],
          'issuingOrganization': row[4],
          'issueDate': row[5],
          'expiryDate': row[6],
          'certificateNumber': row[7],
          'certificateUrl': row[8],
          'status': row[9],
          'notes': row[10],
          'createdAt': row[11],
          'updatedAt': row[12],
        };
      }).toList();

      return ResponseHelper.list(data: certifications);
    } catch (e, stackTrace) {
      AppLogger.error('Get certifications error', e, stackTrace);
      return ResponseHelper.error(message: 'خطأ في جلب الشهادات: $e', error: stackTrace);
    }
  }

  Future<Response> _createCertification(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final conn = await _db.connection;
      await conn.execute('''
        INSERT INTO certifications (
          id, employee_id, employee_name, certificate_name,
          issuing_organization, issue_date, expiry_date,
          certificate_number, certificate_url, status,
          notes, created_at, updated_at
        ) VALUES (
          @id, @employeeId, @employeeName, @certificateName,
          @issuingOrganization, @issueDate, @expiryDate,
          @certificateNumber, @certificateUrl, @status,
          @notes, @createdAt, @updatedAt
        )
      ''', substitutionValues: {
        'id': data['id'],
        'employeeId': data['employeeId'],
        'employeeName': data['employeeName'],
        'certificateName': data['certificateName'],
        'issuingOrganization': data['issuingOrganization'],
        'issueDate': data['issueDate'],
        'expiryDate': data['expiryDate'],
        'certificateNumber': data['certificateNumber'],
        'certificateUrl': data['certificateUrl'],
        'status': data['status'] ?? 'active',
        'notes': data['notes'],
        'createdAt': data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
        'updatedAt': data['updatedAt'],
      });

      return ResponseHelper.success(data: {'message': 'تم إنشاء الشهادة بنجاح'});
    } catch (e, stackTrace) {
      AppLogger.error('Create certification error', e, stackTrace);
      return ResponseHelper.error(message: 'خطأ في إنشاء الشهادة: $e', error: stackTrace);
    }
  }
}

