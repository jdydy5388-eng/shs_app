import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import '../models/user_model.dart';
import '../models/prescription_model.dart';
import '../models/order_model.dart';
import '../models/doctor_appointment_model.dart';
import '../models/medical_record_model.dart';
import '../models/medication_inventory_model.dart';
import '../models/lab_request_model.dart';
import '../models/entity_model.dart';
import '../models/audit_log_model.dart';
import '../models/system_settings_model.dart';
import '../models/doctor_task_model.dart';

/// خدمة البيانات الشبكية - الاتصال بالخادم المركزي عبر REST API
class NetworkDataService {
  final Uuid _uuid = const Uuid();
  
  /// الحصول على عنوان API (مع اكتشاف تلقائي)
  Future<String> get _baseUrl async => await AppConfig.apiBaseUrl;

  String _extractServerError(String body) {
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map<String, dynamic>) {
        final err = parsed['error'];
        if (err is String && err.trim().isNotEmpty) return err.trim();
        if (err is Map && err['message'] is String) return (err['message'] as String).trim();
      }
    } catch (_) {
      // ignore parse error
    }
    return body;
  }

  String _mapErrorText(String? errorText, String endpoint) {
    final text = (errorText ?? '').trim();
    final lower = text.toLowerCase();

    if (lower.contains('invalid email or password')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    }
    if (lower.contains('not a subtype of type') || lower.contains('type cast')) {
      return 'حدث خلل داخلي في الخادم أثناء معالجة البيانات.';
    }
    if (endpoint.contains('medical-records') ||
        lower.contains('failed to get medical records')) {
      return 'تعذّر تحميل السجل الصحي. حاول لاحقاً.';
    }
    if (lower.contains('already exists') || lower.contains('duplicate')) {
      return 'العنصر موجود مسبقاً.';
    }
    if (lower.contains('timed out')) {
      return 'انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى.';
    }
    if (lower.contains('failed host lookup') || lower.contains('connection refused')) {
      return 'تعذّر الاتصال بالخادم. تحقق من اتصال الإنترنت أو إعدادات الخادم.';
    }
    return text;
  }

  String _friendlyHttpError({
    required int statusCode,
    required String body,
    required String endpoint,
  }) {
    final serverError = _extractServerError(body);
    final mapped = _mapErrorText(serverError, endpoint);

    String generic;
    if (statusCode == 400) {
      generic = 'تعذّر معالجة الطلب.';
    } else if (statusCode == 401) {
      generic = 'غير مصرح. يرجى تسجيل الدخول.';
    } else if (statusCode == 403) {
      generic = 'لا تملك صلاحية الوصول.';
    } else if (statusCode == 404) {
      generic = 'المورد المطلوب غير موجود.';
    } else if (statusCode == 408) {
      generic = 'انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى.';
    } else if (statusCode >= 500 && statusCode < 600) {
      generic = 'حدث خطأ في الخادم. حاول لاحقاً.';
    } else {
      generic = 'حدث خطأ غير متوقع.';
    }

    // إن وُجدت رسالة مفهومة، نعيدها، وإلا نعيد العامة
    return mapped.isNotEmpty ? mapped : generic;
  }

  static const Duration _requestTimeout = Duration(seconds: 15);

  Future<http.Response> _sendRequest(
    Future<http.Response> Function() request,
    String description,
  ) async {
    try {
      return await request().timeout(_requestTimeout);
    } on SocketException {
      throw Exception('لا يوجد اتصال بالشبكة. تحقق من اتصال الإنترنت وحاول مرة أخرى.');
    } on TimeoutException {
      throw Exception('انتهت مهلة الاتصال بالخادم. حاول مرة أخرى خلال لحظات.');
    } on http.ClientException {
      throw Exception('تعذّر الوصول إلى الخادم. تأكد من تشغيل الخادم أو حاول لاحقاً.');
    } catch (e) {
      throw Exception('تعذّر إكمال الطلب ($description). يرجى المحاولة لاحقاً.');
    }
  }

  Future<Map<String, dynamic>> _get(String endpoint, {Map<String, String>? queryParams}) async {
    final baseUrl = await _baseUrl;
    final uri = Uri.parse('$baseUrl/$endpoint').replace(queryParameters: queryParams);
    final response = await _sendRequest(() => http.get(uri), 'GET $endpoint');
    
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['success'] == true) {
        return json['data'] as Map<String, dynamic>;
      }
      final message = _mapErrorText('${json['error'] ?? ''}', endpoint);
      throw Exception(message.isNotEmpty ? message : 'حدث خطأ غير متوقع.');
    }
    throw Exception(_friendlyHttpError(
      statusCode: response.statusCode,
      body: response.body,
      endpoint: endpoint,
    ));
  }

  Future<List<Map<String, dynamic>>> _getList(String endpoint, {Map<String, String>? queryParams}) async {
    final baseUrl = await _baseUrl;
    final uri = Uri.parse('$baseUrl/$endpoint').replace(queryParameters: queryParams);
    final response = await _sendRequest(() => http.get(uri), 'GET $endpoint');
    
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['success'] == true) {
        return List<Map<String, dynamic>>.from(json['data'] as List);
      }
      final message = _mapErrorText('${json['error'] ?? ''}', endpoint);
      throw Exception(message.isNotEmpty ? message : 'حدث خطأ غير متوقع.');
    }
    throw Exception(_friendlyHttpError(
      statusCode: response.statusCode,
      body: response.body,
      endpoint: endpoint,
    ));
  }

  Future<Map<String, dynamic>> _post(String endpoint, Map<String, dynamic> body) async {
    final baseUrl = await _baseUrl;
    final uri = Uri.parse('$baseUrl/$endpoint');
    final response = await _sendRequest(
      () => http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
      'POST $endpoint',
    );
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['success'] == true) {
        return json['data'] as Map<String, dynamic>;
      }
      final message = _mapErrorText('${json['error'] ?? ''}', endpoint);
      throw Exception(message.isNotEmpty ? message : 'حدث خطأ غير متوقع.');
    }
    throw Exception(_friendlyHttpError(
      statusCode: response.statusCode,
      body: response.body,
      endpoint: endpoint,
    ));
  }

  Future<Map<String, dynamic>> _put(String endpoint, Map<String, dynamic> body) async {
    final baseUrl = await _baseUrl;
    final uri = Uri.parse('$baseUrl/$endpoint');
    final response = await _sendRequest(
      () => http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
      'PUT $endpoint',
    );
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['success'] == true) {
        return json['data'] as Map<String, dynamic>;
      }
      final message = _mapErrorText('${json['error'] ?? ''}', endpoint);
      throw Exception(message.isNotEmpty ? message : 'حدث خطأ غير متوقع.');
    }
    throw Exception(_friendlyHttpError(
      statusCode: response.statusCode,
      body: response.body,
      endpoint: endpoint,
    ));
  }

  Future<Map<String, dynamic>> _delete(String endpoint) async {
    final baseUrl = await _baseUrl;
    final uri = Uri.parse('$baseUrl/$endpoint');
    final response = await _sendRequest(() => http.delete(uri), 'DELETE $endpoint');
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['success'] == true) {
        return json['data'] as Map<String, dynamic>;
      }
      final message = _mapErrorText('${json['error'] ?? ''}', endpoint);
      throw Exception(message.isNotEmpty ? message : 'حدث خطأ غير متوقع.');
    }
    throw Exception(_friendlyHttpError(
      statusCode: response.statusCode,
      body: response.body,
      endpoint: endpoint,
    ));
  }

  // Users
  Future<List<UserModel>> getUsers({UserRole? role}) async {
    final queryParams = role != null ? {'role': role.toString().split('.').last} : null;
    final data = await _getList('users', queryParams: queryParams);
    return data.map((map) => UserModel.fromMap(map, map['id'] as String)).toList();
  }

  Future<List<UserModel>> getPatients() async {
    final data = await _getList('users/patients');
    return data.map((map) => UserModel.fromMap(map, map['id'] as String)).toList();
  }

  Future<UserModel> getUser(String userId) async {
    final data = await _get('users/$userId');
    return UserModel.fromMap(data, data['id'] as String);
  }

  Future<void> createUser(UserModel user, String password) async {
    await _post('users', {
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'phone': user.phone,
      'role': user.role.toString().split('.').last,
      'additionalInfo': user.additionalInfo,
      'password': password,
    });
  }

  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    await _put('users/$userId', updates);
  }

  Future<void> deleteUser(String userId) async {
    await _delete('users/$userId');
  }

  // Prescriptions
  Future<List<PrescriptionModel>> getPrescriptions({String? patientId, String? doctorId}) async {
    final queryParams = <String, String>{};
    if (patientId != null) queryParams['patientId'] = patientId;
    if (doctorId != null) queryParams['doctorId'] = doctorId;
    
    final data = await _getList('prescriptions', queryParams: queryParams);
    return data.map((map) => PrescriptionModel.fromMap(map, map['id'] as String)).toList();
  }

  Future<void> createPrescription(PrescriptionModel prescription) async {
    await _post('prescriptions', {
      'id': prescription.id,
      'doctorId': prescription.doctorId,
      'doctorName': prescription.doctorName,
      'patientId': prescription.patientId,
      'patientName': prescription.patientName,
      'diagnosis': prescription.diagnosis,
      'notes': prescription.notes,
      'status': prescription.status.toString().split('.').last,
      'createdAt': prescription.createdAt.millisecondsSinceEpoch,
      'expiresAt': prescription.expiresAt?.millisecondsSinceEpoch,
      'medications': prescription.medications.map((m) => m.toMap()).toList(),
      'drugInteractions': prescription.drugInteractions,
    });
  }

  Future<void> updatePrescriptionStatus(String prescriptionId, PrescriptionStatus status) async {
    await _put('prescriptions/$prescriptionId/status', {
      'status': status.toString().split('.').last,
    });
  }

  // Orders
  Future<List<MedicationOrderModel>> getOrders({String? patientId, String? pharmacyId}) async {
    final queryParams = <String, String>{};
    if (patientId != null) queryParams['patientId'] = patientId;
    if (pharmacyId != null) queryParams['pharmacyId'] = pharmacyId;
    
    final data = await _getList('orders', queryParams: queryParams);
    return data.map((map) => MedicationOrderModel.fromMap(map, map['id'] as String)).toList();
  }

  Future<String> createOrderFromPrescription({
    required UserModel patient,
    required UserModel pharmacy,
    required PrescriptionModel prescription,
    String? deliveryAddress,
    String? notes,
  }) async {
    final orderId = _uuid.v4();
    
    final items = prescription.medications.map((med) => {
      'id': _uuid.v4(),
      'medicationId': med.id,
      'medicationName': med.name,
      'quantity': med.quantity > 0 ? med.quantity : 1,
      'price': 0.0, // سيتم تحديثه من المخزون
      'alternativeMedicationId': null,
      'alternativeMedicationName': null,
      'alternativePrice': null,
    }).toList();

    await _post('orders', {
      'id': orderId,
      'patientId': patient.id,
      'patientName': patient.name,
      'pharmacyId': pharmacy.id,
      'pharmacyName': pharmacy.pharmacyName ?? pharmacy.name,
      'prescriptionId': prescription.id,
      'status': 'pending',
      'totalAmount': 0.0,
      'deliveryAddress': deliveryAddress,
      'notes': notes,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'deliveredAt': null,
      'items': items,
    });

    return orderId;
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status, {String? notes}) async {
    await _put('orders/$orderId/status', {
      'status': status.toString().split('.').last,
      if (notes != null) 'notes': notes,
    });
  }

  Future<void> suggestOrderAlternative({
    required String orderId,
    required String orderItemId,
    required MedicationInventoryModel alternative,
  }) async {
    await _put('orders/$orderId/alternative', {
      'itemId': orderItemId,
      'alternative': {
        'id': alternative.id,
        'medicationName': alternative.medicationName,
        'price': alternative.price,
      },
    });
  }

  Future<void> approveOrderAlternative({
    required String orderId,
    required String orderItemId,
  }) async {
    await _put('orders/$orderId/approve-alternative', {
      'itemId': orderItemId,
    });
  }

  Future<void> rejectOrderAlternative({
    required String orderId,
    required String orderItemId,
  }) async {
    await _put('orders/$orderId/reject-alternative', {
      'itemId': orderItemId,
    });
  }

  // Appointments
  Future<List<DoctorAppointment>> getDoctorAppointments(String doctorId, {
    AppointmentStatus? status,
    DateTime? from,
    DateTime? to,
  }) async {
    final queryParams = <String, String>{'doctorId': doctorId};
    if (status != null) queryParams['status'] = status.toString().split('.').last;
    if (from != null) queryParams['from'] = from.millisecondsSinceEpoch.toString();
    if (to != null) queryParams['to'] = to.millisecondsSinceEpoch.toString();
    
    final data = await _getList('appointments', queryParams: queryParams);
    return data.map((map) {
      // معالجة آمنة للتواريخ
      int? parseDate(dynamic value) {
        if (value == null) return null;
        if (value is int) return value;
        if (value is DateTime) return value.millisecondsSinceEpoch;
        return null;
      }
      
      return DoctorAppointment.fromMap({
        'id': map['id'],
        'doctor_id': map['doctorId'],
        'patient_id': map['patientId'],
        'patient_name': map['patientName'],
        'date': parseDate(map['date']) ?? DateTime.now().millisecondsSinceEpoch,
        'status': map['status'],
        'type': map['type'],
        'notes': map['notes'],
        'created_at': parseDate(map['createdAt']) ?? DateTime.now().millisecondsSinceEpoch,
        'updated_at': parseDate(map['updatedAt']),
      });
    }).toList();
  }

  Future<List<DoctorAppointment>> getPatientAppointments(String patientId, {
    AppointmentStatus? status,
    DateTime? from,
    DateTime? to,
  }) async {
    final queryParams = <String, String>{'patientId': patientId};
    if (status != null) queryParams['status'] = status.toString().split('.').last;
    if (from != null) queryParams['from'] = from.millisecondsSinceEpoch.toString();
    if (to != null) queryParams['to'] = to.millisecondsSinceEpoch.toString();
    
    final data = await _getList('appointments', queryParams: queryParams);
    return data.map((map) {
      // معالجة آمنة للتواريخ
      int? parseDate(dynamic value) {
        if (value == null) return null;
        if (value is int) return value;
        if (value is DateTime) return value.millisecondsSinceEpoch;
        return null;
      }
      
      return DoctorAppointment.fromMap({
        'id': map['id'],
        'doctor_id': map['doctorId'],
        'patient_id': map['patientId'],
        'patient_name': map['patientName'],
        'date': parseDate(map['date']) ?? DateTime.now().millisecondsSinceEpoch,
        'status': map['status'],
        'type': map['type'],
        'notes': map['notes'],
        'created_at': parseDate(map['createdAt']) ?? DateTime.now().millisecondsSinceEpoch,
        'updated_at': parseDate(map['updatedAt']),
      });
    }).toList();
  }

  Future<void> createAppointment(DoctorAppointment appointment) async {
    await _post('appointments', {
      'id': appointment.id,
      'doctorId': appointment.doctorId,
      'patientId': appointment.patientId,
      'patientName': appointment.patientName,
      'date': appointment.date.millisecondsSinceEpoch,
      'status': appointment.status.toString().split('.').last,
      'type': appointment.type,
      'notes': appointment.notes,
      'createdAt': appointment.createdAt.millisecondsSinceEpoch,
      'updatedAt': appointment.updatedAt?.millisecondsSinceEpoch,
    });
  }

  Future<void> updateAppointmentStatus(String appointmentId, AppointmentStatus status) async {
    await _put('appointments/$appointmentId/status', {
      'status': status.toString().split('.').last,
    });
  }

  Future<void> updateAppointment(String appointmentId, {
    DateTime? date,
    AppointmentStatus? status,
    String? patientName,
    String? type,
    String? notes,
  }) async {
    final updates = <String, dynamic>{};
    if (date != null) updates['date'] = date.millisecondsSinceEpoch;
    if (status != null) updates['status'] = status.toString().split('.').last;
    if (patientName != null) updates['patientName'] = patientName;
    if (type != null) updates['type'] = type;
    if (notes != null) updates['notes'] = notes;
    
    await _put('appointments/$appointmentId', updates);
  }

  Future<void> deleteAppointment(String appointmentId) async {
    await _delete('appointments/$appointmentId');
  }

  // Medical Records
  Future<List<MedicalRecordModel>> getMedicalRecords({String? patientId}) async {
    final queryParams = patientId != null ? {'patientId': patientId} : null;
    final data = await _getList('medical-records', queryParams: queryParams);
    return data.map((map) {
      final normalizedMap = Map<String, dynamic>.from(map);
      // تحويل التواريخ من milliseconds إلى DateTime
      if (normalizedMap['date'] is int) {
        normalizedMap['date'] = DateTime.fromMillisecondsSinceEpoch(normalizedMap['date'] as int);
      }
      if (normalizedMap['createdAt'] is int) {
        normalizedMap['createdAt'] = DateTime.fromMillisecondsSinceEpoch(normalizedMap['createdAt'] as int);
      }
      return MedicalRecordModel.fromMap(normalizedMap, normalizedMap['id'] as String);
    }).toList();
  }

  Future<void> addMedicalRecord(MedicalRecordModel record) async {
    await _post('medical-records', {
      'id': record.id,
      'patientId': record.patientId,
      'doctorId': record.doctorId,
      'doctorName': record.doctorName,
      'type': record.type.toString().split('.').last,
      'title': record.title,
      'description': record.description,
      'date': record.date.millisecondsSinceEpoch,
      'fileUrls': record.fileUrls,
      'additionalData': record.additionalData,
      'createdAt': record.createdAt.millisecondsSinceEpoch,
    });
  }

  // Inventory
  Future<List<MedicationInventoryModel>> getInventory({String? pharmacyId}) async {
    final queryParams = pharmacyId != null ? {'pharmacyId': pharmacyId} : null;
    final data = await _getList('inventory', queryParams: queryParams);
    return data.map((map) {
      final normalizedMap = Map<String, dynamic>.from(map);
      // تحويل التواريخ من milliseconds
      if (normalizedMap['expiryDate'] is int) {
        normalizedMap['expiryDate'] = DateTime.fromMillisecondsSinceEpoch(normalizedMap['expiryDate'] as int);
      }
      if (normalizedMap['lastUpdated'] is int) {
        normalizedMap['lastUpdated'] = DateTime.fromMillisecondsSinceEpoch(normalizedMap['lastUpdated'] as int);
      }
      return MedicationInventoryModel.fromMap(normalizedMap, normalizedMap['id'] as String);
    }).toList();
  }

  Future<void> addInventoryItem(MedicationInventoryModel item) async {
    await _post('inventory', {
      'id': item.id,
      'pharmacyId': item.pharmacyId,
      'medicationName': item.medicationName,
      'medicationId': item.medicationId,
      'quantity': item.quantity,
      'price': item.price,
      'manufacturer': item.manufacturer,
      'expiryDate': item.expiryDate?.millisecondsSinceEpoch,
      'batchNumber': item.batchNumber,
      'lastUpdated': item.lastUpdated.millisecondsSinceEpoch,
    });
  }

  Future<void> updateInventoryItem(String itemId, {
    int? quantity,
    double? price,
    String? manufacturer,
    DateTime? expiryDate,
    String? batchNumber,
  }) async {
    final updates = <String, dynamic>{};
    if (quantity != null) updates['quantity'] = quantity;
    if (price != null) updates['price'] = price;
    if (manufacturer != null) updates['manufacturer'] = manufacturer;
    if (expiryDate != null) updates['expiryDate'] = expiryDate.millisecondsSinceEpoch;
    if (batchNumber != null) updates['batchNumber'] = batchNumber;
    
    await _put('inventory/$itemId', updates);
  }

  Future<void> deleteInventoryItem(String itemId) async {
    await _delete('inventory/$itemId');
  }

  // Lab Requests
  Future<List<LabRequestModel>> getLabRequests({String? doctorId, String? patientId}) async {
    final queryParams = <String, String>{};
    if (doctorId != null) queryParams['doctorId'] = doctorId;
    if (patientId != null) queryParams['patientId'] = patientId;
    
    final data = await _getList('lab-requests', queryParams: queryParams);
    return data.map((map) {
      // تحويل الحقول من snake_case إلى camelCase
      final convertedMap = <String, dynamic>{
        'id': map['id'],
        'doctor_id': map['doctorId'] ?? map['doctor_id'],
        'patient_id': map['patientId'] ?? map['patient_id'],
        'patient_name': map['patientName'] ?? map['patient_name'],
        'test_type': map['testType'] ?? map['test_type'],
        'status': map['status'],
        'notes': map['notes'],
        'result_notes': map['resultNotes'] ?? map['result_notes'],
        'attachments': map['attachments'] ?? map['resultAttachments'] ?? map['result_attachments'],
        'requested_at': map['requestedAt'] ?? map['requested_at'],
        'completed_at': map['completedAt'] ?? map['completed_at'],
      };
      return LabRequestModel.fromMap(convertedMap);
    }).toList();
  }

  Future<void> createLabRequest(LabRequestModel request) async {
    await _post('lab-requests', {
      'id': request.id,
      'doctorId': request.doctorId,
      'patientId': request.patientId,
      'patientName': request.patientName,
      'testType': request.testType,
      'status': request.status.toString().split('.').last,
      'notes': request.notes,
      'resultNotes': request.resultNotes,
      'attachments': request.attachments,
      'requestedAt': request.requestedAt.millisecondsSinceEpoch,
      'completedAt': request.completedAt?.millisecondsSinceEpoch,
    });
  }

  Future<void> updateLabRequest(String requestId, {
    LabRequestStatus? status,
    String? resultNotes,
    List<String>? resultAttachments,
  }) async {
    final updates = <String, dynamic>{};
    if (status != null) updates['status'] = status.toString().split('.').last;
    if (resultNotes != null) updates['resultNotes'] = resultNotes;
    if (resultAttachments != null) updates['attachments'] = resultAttachments;
    if (status == LabRequestStatus.completed) {
      updates['completedAt'] = DateTime.now().millisecondsSinceEpoch;
    }
    
    await _put('lab-requests/$requestId', updates);
  }

  // Entities
  Future<List<EntityModel>> getEntities({String? type}) async {
    final queryParams = type != null ? {'type': type} : null;
    final data = await _getList('entities', queryParams: queryParams);
    return data.map((map) {
      // تحويل الحقول من camelCase إلى snake_case
      final convertedMap = <String, dynamic>{
        'id': map['id'],
        'name': map['name'],
        'type': map['type'],
        'address': map['address'],
        'phone': map['phone'],
        'email': map['email'],
        'latitude': map['latitude'] ?? map['locationLat'],
        'longitude': map['longitude'] ?? map['locationLng'],
        'license_number': map['licenseNumber'] ?? map['license_number'],
        'notes': map['notes'],
        'created_at': map['createdAt'] ?? map['created_at'],
      };
      return EntityModel.fromMap(convertedMap);
    }).toList();
  }

  Future<void> createEntity(EntityModel entity) async {
    await _post('entities', {
      'id': entity.id,
      'name': entity.name,
      'type': entity.type.toString().split('.').last,
      'address': entity.address,
      'phone': entity.phone,
      'email': entity.email,
      'latitude': entity.latitude,
      'longitude': entity.longitude,
      'createdAt': entity.createdAt.millisecondsSinceEpoch,
    });
  }

  Future<void> updateEntity(String entityId, {
    String? name,
    String? address,
    String? phone,
    String? email,
    double? locationLat,
    double? locationLng,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (address != null) updates['address'] = address;
    if (phone != null) updates['phone'] = phone;
    if (email != null) updates['email'] = email;
    if (locationLat != null) updates['locationLat'] = locationLat;
    if (locationLng != null) updates['locationLng'] = locationLng;
    
    await _put('entities/$entityId', updates);
  }

  Future<void> deleteEntity(String entityId) async {
    await _delete('entities/$entityId');
  }

  // Audit Logs
  Future<List<AuditLogModel>> getAuditLogs({
    String? userId,
    String? resourceType,
    int limit = 100,
  }) async {
    final queryParams = <String, String>{'limit': limit.toString()};
    if (userId != null) queryParams['userId'] = userId;
    if (resourceType != null) queryParams['resourceType'] = resourceType;
    
    final data = await _getList('audit-logs', queryParams: queryParams);
    return data.map((map) {
      // تحويل الحقول من camelCase إلى snake_case
      final convertedMap = <String, dynamic>{
        'id': map['id'],
        'user_id': map['userId'] ?? map['user_id'],
        'user_name': map['userName'] ?? map['user_name'],
        'action': map['action'],
        'resource_type': map['resourceType'] ?? map['resource_type'],
        'resource_id': map['resourceId'] ?? map['resource_id'],
        'timestamp': map['timestamp'] ?? map['createdAt'] ?? map['created_at'],
        'details': map['details'],
        'ip_address': map['ipAddress'] ?? map['ip_address'],
      };
      return AuditLogModel.fromMap(convertedMap);
    }).toList();
  }

  Future<void> createAuditLog(AuditLogModel log) async {
    await _post('audit-logs', {
      'id': log.id,
      'userId': log.userId,
      'userName': log.userName,
      'action': log.action,
      'resourceType': log.resourceType,
      'resourceId': log.resourceId,
      'details': log.details,
      'ipAddress': log.ipAddress,
      'timestamp': log.timestamp.millisecondsSinceEpoch,
    });
  }

  // System Settings
  Future<SystemSettingsModel?> getSystemSetting(String key) async {
    try {
      final data = await _get('system-settings/$key');
      // تحويل الحقول
      final convertedData = <String, dynamic>{
        'id': data['id'] ?? key,
        'key': data['key'] ?? key,
        'value': data['value'],
        'description': data['description'] ?? '',
        'updated_at': data['updatedAt'] ?? data['updated_at'],
        'updated_by': data['updatedBy'] ?? data['updated_by'],
      };
      return SystemSettingsModel.fromMap(convertedData);
    } catch (e) {
      return null;
    }
  }

  Future<List<SystemSettingsModel>> getAllSystemSettings() async {
    final data = await _getList('system-settings');
    return data.map((map) {
      // تحويل الحقول
      final convertedMap = <String, dynamic>{
        'id': map['id'] ?? map['key'],
        'key': map['key'],
        'value': map['value'],
        'description': map['description'] ?? '',
        'updated_at': map['updatedAt'] ?? map['updated_at'],
        'updated_by': map['updatedBy'] ?? map['updated_by'],
      };
      return SystemSettingsModel.fromMap(convertedMap);
    }).toList();
  }

  Future<void> updateSystemSetting(String key, String value, {String? description}) async {
    await _put('system-settings/$key', {
      'value': value,
      if (description != null) 'description': description,
    });
  }

  // Doctor Tasks
  Future<List<DoctorTask>> getDoctorTasks(String doctorId, {bool? isCompleted}) async {
    // TODO: إضافة endpoint في الخادم
    throw UnimplementedError('Doctor tasks endpoint not implemented in server');
  }

  Future<void> createTask(DoctorTask task) async {
    // TODO: إضافة endpoint في الخادم
    throw UnimplementedError('Doctor tasks endpoint not implemented in server');
  }

  String generateId() => _uuid.v4();

  // Authentication methods
  Future<Map<String, dynamic>> registerUser({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
    Map<String, dynamic>? additionalInfo,
  }) async {
    final userId = generateId();
    final data = await _post('auth/register', {
      'id': userId,
      'email': email,
      'password': password,
      'name': name,
      'phone': phone,
      'role': role,
      'additionalInfo': additionalInfo ?? {},
    });
    return data;
  }

  Future<Map<String, dynamic>> loginUser({
    required String email,
    required String password,
  }) async {
    final data = await _post('auth/login', {
      'email': email,
      'password': password,
    });
    return data;
  }

  Future<void> logoutUser() async {
    await _post('auth/logout', {});
  }
}

