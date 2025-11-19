import 'dart:convert';
import 'dart:async';
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
import '../models/invoice_model.dart';
import '../models/payment_model.dart';
import '../models/room_bed_model.dart';
import '../models/emergency_case_model.dart';
import '../models/notification_model.dart';
import '../models/radiology_model.dart';
import '../models/attendance_model.dart';
import '../models/surgery_model.dart';
import '../models/medical_inventory_model.dart';
import '../models/hospital_pharmacy_model.dart';
import '../models/lab_test_type_model.dart';
import 'network_auth_context.dart';

/// خدمة البيانات الشبكية - الاتصال بالخادم المركزي عبر REST API
class NetworkDataService {
  final Uuid _uuid = const Uuid();
  static bool _serverWokenUp = false;
  static DateTime? _lastWakeUpAttempt;
  
  /// الحصول على عنوان API (مع اكتشاف تلقائي)
  Future<String> get _baseUrl async => await AppConfig.apiBaseUrl;
  
  /// إيقاظ الخادم تلقائياً (لـ Render Free Tier)
  Future<void> _wakeUpServerIfNeeded() async {
    // إذا تم إيقاظه مؤخراً (خلال آخر 3 دقائق)، لا نحتاج إعادة إيقاظ
    if (_serverWokenUp && _lastWakeUpAttempt != null) {
      final elapsed = DateTime.now().difference(_lastWakeUpAttempt!);
      if (elapsed.inMinutes < 3) return;
    }
    
    try {
      final baseUrl = await AppConfig.serverBaseUrl;
      final healthUrl = Uri.parse('$baseUrl/health');
      
      // محاولة إيقاظ الخادم مع timeout أطول (60 ثانية)
      // نستخدم await بدون catch هنا لأننا نريد أن ينتظر حتى يستيقظ الخادم
      try {
        await http.get(healthUrl, headers: NetworkAuthContext.headers()).timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            // حتى لو timeout، نعتبر أننا حاولنا
            _lastWakeUpAttempt = DateTime.now();
            return http.Response('', 408);
          },
        );
        _serverWokenUp = true;
        _lastWakeUpAttempt = DateTime.now();
      } catch (e) {
        // حتى لو فشل، نعتبر أننا حاولنا
        _lastWakeUpAttempt = DateTime.now();
        // لا نرمي الاستثناء - سنحاول الطلب الفعلي بعد ذلك
      }
    } catch (_) {
      // تجاهل الأخطاء - سنحاول مرة أخرى في الطلب التالي
      _lastWakeUpAttempt = DateTime.now();
    }
  }

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
      generic = 'غير مصرح. يرجى تسجيل الدخول بالحساب الصحيح والمحاولة مجددًا.';
    } else if (statusCode == 403) {
      generic = 'لا تملك صلاحية الوصول. تأكد من تسجيل الدخول بالحساب الصحيح أو تواصل مع المسؤول لمنح الصلاحية.';
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

  static const Duration _requestTimeout = Duration(seconds: 60);
  static const int _maxRetries = 2;
  static const Duration _retryDelay = Duration(seconds: 5);

  Future<http.Response> _sendRequest(
    Future<http.Response> Function() request,
    String description, {
    bool retryOnFailure = true,
    int attempt = 0,
  }) async {
    // إيقاظ الخادم قبل أول محاولة
    if (attempt == 0) {
      await _wakeUpServerIfNeeded();
      // انتظار أطول بعد إيقاظ الخادم (لإعطاء الخادم وقت للاستيقاظ)
      await Future.delayed(const Duration(seconds: 5));
    }
    
    try {
      return await request().timeout(_requestTimeout);
    } on TimeoutException {
      // إذا كان timeout وكانت هناك محاولات متبقية، نعيد المحاولة
      if (retryOnFailure && attempt < _maxRetries) {
        await Future.delayed(_retryDelay * (attempt + 1));
        return _sendRequest(request, description, retryOnFailure: retryOnFailure, attempt: attempt + 1);
      }
      throw Exception('الخادم يستيقظ من حالة السكون. يرجى الانتظار 30-60 ثانية ثم المحاولة مرة أخرى.');
    } on http.ClientException catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('socket') || message.contains('connection') || message.contains('network')) {
        // إعادة المحاولة مرة واحدة في حالة فشل الاتصال
        if (retryOnFailure && attempt < _maxRetries) {
          await Future.delayed(_retryDelay * (attempt + 1));
          return _sendRequest(request, description, retryOnFailure: retryOnFailure, attempt: attempt + 1);
        }
        throw Exception('لا يوجد اتصال بالشبكة. تحقق من اتصال الإنترنت وحاول مرة أخرى.');
      }
      throw Exception('تعذّر الوصول إلى الخادم. تأكد من تشغيل الخادم أو حاول لاحقاً.');
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('socket') || errorStr.contains('connection') || errorStr.contains('network')) {
        // إعادة المحاولة مرة واحدة في حالة فشل الاتصال
        if (retryOnFailure && attempt < _maxRetries) {
          await Future.delayed(_retryDelay * (attempt + 1));
          return _sendRequest(request, description, retryOnFailure: retryOnFailure, attempt: attempt + 1);
        }
        throw Exception('لا يوجد اتصال بالشبكة. تحقق من اتصال الإنترنت وحاول مرة أخرى.');
      }
      if (errorStr.contains('timeout')) {
        // إعادة المحاولة مرة واحدة في حالة timeout
        if (retryOnFailure && attempt < _maxRetries) {
          await Future.delayed(_retryDelay * (attempt + 1));
          return _sendRequest(request, description, retryOnFailure: retryOnFailure, attempt: attempt + 1);
        }
        throw Exception('انتهت مهلة الاتصال بالخادم. حاول مرة أخرى خلال لحظات.');
      }
      throw Exception('تعذّر إكمال الطلب ($description). يرجى المحاولة لاحقاً.');
    }
  }

  Future<Map<String, dynamic>> _get(String endpoint, {Map<String, String>? queryParams}) async {
    final baseUrl = await _baseUrl;
    final uri = Uri.parse('$baseUrl/$endpoint').replace(queryParameters: queryParams);
    final response = await _sendRequest(() => http.get(uri, headers: NetworkAuthContext.headers()), 'GET $endpoint');
    
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
    final response = await _sendRequest(() => http.get(uri, headers: NetworkAuthContext.headers()), 'GET $endpoint');
    
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
      headers: {
        'Content-Type': 'application/json',
        ...NetworkAuthContext.headers(),
      },
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
      headers: {
        'Content-Type': 'application/json',
        ...NetworkAuthContext.headers(),
      },
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
    final response = await _sendRequest(() => http.delete(uri, headers: NetworkAuthContext.headers()), 'DELETE $endpoint');
    
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

  // Billing - Invoices
  Future<List<InvoiceModel>> getInvoices({String? patientId, InvoiceStatus? status}) async {
    final query = <String, String>{};
    if (patientId != null) query['patientId'] = patientId;
    if (status != null) query['status'] = status.toString().split('.').last;
    final data = await _getList('billing/invoices', queryParams: query);
    return data.map((map) => InvoiceModel.fromMap(map, map['id'] as String)).toList();
  }

  Future<void> createInvoice(InvoiceModel invoice) async {
    await _post('billing/invoices', invoice.toMap());
  }

  Future<void> updateInvoice(String invoiceId, {
    List<InvoiceItem>? items,
    double? subtotal,
    double? discount,
    double? tax,
    double? total,
    String? currency,
    String? insuranceProvider,
    String? insurancePolicy,
  }) async {
    final body = <String, dynamic>{};
    if (items != null) body['items'] = items.map((e) => e.toMap()).toList();
    if (subtotal != null) body['subtotal'] = subtotal;
    if (discount != null) body['discount'] = discount;
    if (tax != null) body['tax'] = tax;
    if (total != null) body['total'] = total;
    if (currency != null) body['currency'] = currency;
    if (insuranceProvider != null) body['insuranceProvider'] = insuranceProvider;
    if (insurancePolicy != null) body['insurancePolicy'] = insurancePolicy;
    await _put('billing/invoices/$invoiceId', body);
  }

  Future<void> updateInvoiceStatus(String invoiceId, InvoiceStatus status) async {
    await _put('billing/invoices/$invoiceId/status', {
      'status': status.toString().split('.').last,
    });
  }

  Future<InvoiceModel?> getInvoice(String invoiceId) async {
    final data = await _get('billing/invoices/$invoiceId');
    if (data == null) return null;
    return InvoiceModel.fromMap(data, data['id'] as String);
  }

  // Payments
  Future<List<PaymentModel>> getPayments({String? invoiceId}) async {
    final query = <String, String>{};
    if (invoiceId != null) query['invoiceId'] = invoiceId;
    final data = await _getList('billing/payments', queryParams: query);
    return data.map((map) => PaymentModel.fromMap(map, map['id'] as String)).toList();
  }

  Future<void> createPayment(PaymentModel payment) async {
    await _post('billing/payments', payment.toMap());
  }

  // Rooms & Beds
  Future<List<RoomModel>> getRooms() async {
    final data = await _getList('rooms/rooms');
    return data.map((m) => RoomModel.fromMap({
      'id': m['id'],
      'name': m['name'],
      'type': m['type'],
      'floor': m['floor'],
      'notes': m['notes'],
      'createdAt': m['createdAt'],
      'updatedAt': m['updatedAt'],
    })).toList();
  }

  Future<void> createRoom(RoomModel room) async {
    await _post('rooms/rooms', room.toMap());
  }

  Future<void> updateRoom(String roomId, {String? name, RoomType? type, int? floor, String? notes}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (type != null) body['type'] = type.toString().split('.').last;
    if (floor != null) body['floor'] = floor;
    if (notes != null) body['notes'] = notes;
    await _put('rooms/rooms/$roomId', body);
  }

  Future<List<BedModel>> getBeds({String? roomId, BedStatus? status}) async {
    final query = <String, String>{};
    if (roomId != null) query['roomId'] = roomId;
    if (status != null) query['status'] = status.toString().split('.').last;
    final data = await _getList('rooms/beds', queryParams: query);
    return data.map((m) => BedModel.fromMap(m)).toList();
  }

  Future<void> createBed(BedModel bed) async {
    await _post('rooms/beds', bed.toMap());
  }

  Future<void> updateBed(String bedId, {String? label, BedStatus? status, String? patientId, DateTime? occupiedSince}) async {
    final body = <String, dynamic>{};
    if (label != null) body['label'] = label;
    if (status != null) body['status'] = status.toString().split('.').last;
    if (patientId != null) body['patientId'] = patientId;
    if (occupiedSince != null) body['occupiedSince'] = occupiedSince.millisecondsSinceEpoch;
    await _put('rooms/beds/$bedId', body);
  }

  Future<void> assignBed(String bedId, String patientId) async {
    await _put('rooms/beds/$bedId/assign', {'patientId': patientId});
  }

  Future<void> releaseBed(String bedId) async {
    await _put('rooms/beds/$bedId/release', {});
  }

  Future<void> createTransfer({
    required String id,
    required String patientId,
    String? fromBedId,
    required String toBedId,
    String? reason,
  }) async {
    await _post('rooms/transfers', {
      'id': id,
      'patientId': patientId,
      'fromBedId': fromBedId,
      'toBedId': toBedId,
      'reason': reason,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Emergency
  Future<List<EmergencyCaseModel>> getEmergencyCases({EmergencyStatus? status, TriageLevel? triage}) async {
    final query = <String, String>{};
    if (status != null) query['status'] = status.toString().split('.').last;
    if (triage != null) query['triage'] = triage.toString().split('.').last;
    final data = await _getList('emergency/cases', queryParams: query);
    return data.map((m) => EmergencyCaseModel.fromMap(m, m['id'] as String)).toList();
  }

  Future<void> createEmergencyCase(EmergencyCaseModel c) async {
    await _post('emergency/cases', c.toMap());
  }

  Future<void> updateEmergencyCase(String caseId, {
    String? patientId,
    String? patientName,
    TriageLevel? triageLevel,
    EmergencyStatus? status,
    Map<String, dynamic>? vitalSigns,
    String? symptoms,
    String? notes,
  }) async {
    final body = <String, dynamic>{};
    if (patientId != null) body['patientId'] = patientId;
    if (patientName != null) body['patientName'] = patientName;
    if (triageLevel != null) body['triageLevel'] = triageLevel.toString().split('.').last;
    if (status != null) body['status'] = status.toString().split('.').last;
    if (vitalSigns != null) body['vitalSigns'] = vitalSigns;
    if (symptoms != null) body['symptoms'] = symptoms;
    if (notes != null) body['notes'] = notes;
    await _put('emergency/cases/$caseId', body);
  }

  Future<void> updateEmergencyStatus(String caseId, EmergencyStatus status) async {
    await _put('emergency/cases/$caseId/status', {'status': status.toString().split('.').last});
  }

  Future<List<EmergencyEventModel>> getEmergencyEvents({String? caseId}) async {
    final query = <String, String>{};
    if (caseId != null) query['caseId'] = caseId;
    final data = await _getList('emergency/events', queryParams: query);
    return data.map((m) => EmergencyEventModel.fromMap(m, m['id'] as String)).toList();
  }

  Future<void> createEmergencyEvent(EmergencyEventModel e) async {
    await _post('emergency/events', e.toMap());
  }

  // Notifications (SMS/Email)
  Future<List<NotificationModel>> getNotifications({NotificationStatus? status, String? relatedType, String? relatedId}) async {
    final query = <String, String>{};
    if (status != null) query['status'] = status.toString().split('.').last;
    if (relatedType != null) query['relatedType'] = relatedType;
    if (relatedId != null) query['relatedId'] = relatedId;
    final data = await _getList('notifications', queryParams: query);
    return data.map((m) => NotificationModel.fromMap(m, m['id'] as String)).toList();
  }

  Future<void> scheduleNotification(NotificationModel n) async {
    await _post('notifications', n.toMap());
  }

  Future<void> updateNotificationStatus(String id, NotificationStatus status, {String? error}) async {
    final body = <String, dynamic>{'status': status.toString().split('.').last};
    if (error != null) body['error'] = error;
    await _put('notifications/$id/status', body);
  }

  // Radiology
  Future<List<RadiologyRequestModel>> getRadiologyRequests({String? doctorId, String? patientId, String? status, String? modality}) async {
    final query = <String, String>{};
    if (doctorId != null) query['doctorId'] = doctorId;
    if (patientId != null) query['patientId'] = patientId;
    if (status != null) query['status'] = status;
    if (modality != null) query['modality'] = modality;
    final data = await _getList('radiology/requests', queryParams: query);
    return data.map((m) => RadiologyRequestModel.fromMap(m, m['id'] as String)).toList();
  }

  Future<void> createRadiologyRequest(RadiologyRequestModel r) async {
    await _post('radiology/requests', r.toMap());
  }

  Future<void> updateRadiologyRequest(String id, {String? modality, String? bodyPart, String? notes, DateTime? scheduledAt, DateTime? completedAt}) async {
    final body = <String, dynamic>{};
    if (modality != null) body['modality'] = modality;
    if (bodyPart != null) body['bodyPart'] = bodyPart;
    if (notes != null) body['notes'] = notes;
    if (scheduledAt != null) body['scheduledAt'] = scheduledAt.millisecondsSinceEpoch;
    if (completedAt != null) body['completedAt'] = completedAt.millisecondsSinceEpoch;
    await _put('radiology/requests/$id', body);
  }

  Future<void> updateRadiologyStatus(String id, RadiologyStatus status) async {
    await _put('radiology/requests/$id/status', {'status': status.toString().split('.').last});
  }

  Future<List<RadiologyReportModel>> getRadiologyReports({String? requestId}) async {
    final query = <String, String>{};
    if (requestId != null) query['requestId'] = requestId;
    final data = await _getList('radiology/reports', queryParams: query);
    return data.map((m) => RadiologyReportModel.fromMap(m, m['id'] as String)).toList();
  }

  Future<void> createRadiologyReport(RadiologyReportModel report) async {
    await _post('radiology/reports', report.toMap());
  }

  // Attendance & Shifts
  Future<List<AttendanceRecord>> getAttendance({String? userId, DateTime? from, DateTime? to}) async {
    final query = <String, String>{};
    if (userId != null) query['userId'] = userId;
    if (from != null) query['from'] = from.millisecondsSinceEpoch.toString();
    if (to != null) query['to'] = to.millisecondsSinceEpoch.toString();
    final data = await _getList('attendance/attendance', queryParams: query);
    return data.map((m) => AttendanceRecord.fromMap(m, m['id'] as String)).toList();
  }

  Future<void> createAttendance(AttendanceRecord r) async {
    await _post('attendance/attendance', r.toMap());
  }

  Future<void> updateAttendance(String id, {DateTime? checkOut, double? locationLat, double? locationLng, String? notes}) async {
    final body = <String, dynamic>{};
    if (checkOut != null) body['checkOut'] = checkOut.millisecondsSinceEpoch;
    if (locationLat != null) body['locationLat'] = locationLat;
    if (locationLng != null) body['locationLng'] = locationLng;
    if (notes != null) body['notes'] = notes;
    await _put('attendance/attendance/$id', body);
  }

  Future<List<ShiftModel>> getShifts({String? userId}) async {
    final query = <String, String>{};
    if (userId != null) query['userId'] = userId;
    final data = await _getList('attendance/shifts', queryParams: query);
    return data.map((m) => ShiftModel.fromMap(m, m['id'] as String)).toList();
  }

  Future<void> createShift(ShiftModel s) async {
    await _post('attendance/shifts', s.toMap());
  }

  Future<void> updateShift(String id, {DateTime? startTime, DateTime? endTime, String? department, String? recurrence}) async {
    final body = <String, dynamic>{};
    if (startTime != null) body['startTime'] = startTime.millisecondsSinceEpoch;
    if (endTime != null) body['endTime'] = endTime.millisecondsSinceEpoch;
    if (department != null) body['department'] = department;
    if (recurrence != null) body['recurrence'] = recurrence;
    await _put('attendance/shifts/$id', body);
  }

  Future<void> deleteShift(String id) async {
    await _delete('attendance/shifts/$id');
  }

  // File Uploads
  Future<String> uploadFile({
    required String filename,
    required List<int> bytes,
    String? contentType,
  }) async {
    final id = _uuid.v4();
    final data = await _post('storage/upload', {
      'id': id,
      'filename': filename,
      'contentBase64': base64Encode(bytes),
      if (contentType != null) 'contentType': contentType,
    });
    return data['url'] as String;
  }

  Future<String> getSignedFileUrl(String fileUrlOrName, {int expiresSeconds = 300}) async {
    // إذا كان الإدخال URL على شكل /api/storage/files/<name> نستخرج الاسم فقط
    String path = fileUrlOrName;
    final idx = fileUrlOrName.indexOf('/api/storage/files/');
    if (idx >= 0) {
      path = fileUrlOrName.substring(idx + '/api/storage/files/'.length);
    }
    final data = await _post('storage/sign', {
      'path': path,
      'expiresSeconds': expiresSeconds,
    });
    return data['url'] as String;
  }

  // Surgeries
  Future<List<SurgeryModel>> getSurgeries({
    String? patientId,
    String? surgeonId,
    SurgeryStatus? status,
    DateTime? from,
    DateTime? to,
  }) async {
    final query = <String, String>{};
    if (patientId != null) query['patientId'] = patientId;
    if (surgeonId != null) query['surgeonId'] = surgeonId;
    if (status != null) query['status'] = status.toString().split('.').last;
    if (from != null) query['from'] = from.millisecondsSinceEpoch.toString();
    if (to != null) query['to'] = to.millisecondsSinceEpoch.toString();
    
    final data = await _getList('surgeries', queryParams: query);
    return data.map((m) => SurgeryModel.fromMap(m, m['id'] as String)).toList();
  }

  Future<void> createSurgery(SurgeryModel surgery) async {
    await _post('surgeries', surgery.toMap());
  }

  Future<void> updateSurgery(String surgeryId, {
    SurgeryStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    Map<String, dynamic>? preOperativeNotes,
    Map<String, dynamic>? operativeNotes,
    Map<String, dynamic>? postOperativeNotes,
  }) async {
    final body = <String, dynamic>{};
    if (status != null) body['status'] = status.toString().split('.').last;
    if (startTime != null) body['startTime'] = startTime.millisecondsSinceEpoch;
    if (endTime != null) body['endTime'] = endTime.millisecondsSinceEpoch;
    if (preOperativeNotes != null) body['preOperativeNotes'] = preOperativeNotes;
    if (operativeNotes != null) body['operativeNotes'] = operativeNotes;
    if (postOperativeNotes != null) body['postOperativeNotes'] = postOperativeNotes;
    await _put('surgeries/$surgeryId', body);
  }

  // Medical Inventory
  Future<List<MedicalInventoryItemModel>> getMedicalInventory({
    InventoryItemType? type,
    EquipmentStatus? status,
    String? category,
  }) async {
    final query = <String, String>{};
    if (type != null) query['type'] = type.toString().split('.').last;
    if (status != null) query['status'] = status.toString().split('.').last;
    if (category != null) query['category'] = category;
    
    final data = await _getList('medical-inventory', queryParams: query);
    return data.map((m) => MedicalInventoryItemModel.fromMap(m, m['id'] as String)).toList();
  }

  Future<void> createMedicalInventoryItem(MedicalInventoryItemModel item) async {
    await _post('medical-inventory', item.toMap());
  }

  Future<void> updateMedicalInventoryItem(String itemId, {
    int? quantity,
    EquipmentStatus? status,
    DateTime? nextMaintenanceDate,
  }) async {
    final body = <String, dynamic>{};
    if (quantity != null) body['quantity'] = quantity;
    if (status != null) body['status'] = status.toString().split('.').last;
    if (nextMaintenanceDate != null) body['nextMaintenanceDate'] = nextMaintenanceDate.millisecondsSinceEpoch;
    await _put('medical-inventory/$itemId', body);
  }

  // Suppliers
  Future<List<SupplierModel>> getSuppliers() async {
    final data = await _getList('suppliers');
    return data.map((m) => SupplierModel.fromMap(m, m['id'] as String)).toList();
  }

  Future<void> createSupplier(SupplierModel supplier) async {
    await _post('suppliers', supplier.toMap());
  }

  // Purchase Orders
  Future<List<PurchaseOrderModel>> getPurchaseOrders({PurchaseOrderStatus? status}) async {
    final query = <String, String>{};
    if (status != null) query['status'] = status.toString().split('.').last;
    
    final data = await _getList('purchase-orders', queryParams: query);
    return data.map((m) => PurchaseOrderModel.fromMap(m, m['id'] as String)).toList();
  }

  Future<void> createPurchaseOrder(PurchaseOrderModel order) async {
    await _post('purchase-orders', order.toMap());
  }

  // Maintenance Records
  Future<List<MaintenanceRecordModel>> getMaintenanceRecords({String? equipmentId}) async {
    final query = <String, String>{};
    if (equipmentId != null) query['equipmentId'] = equipmentId;
    
    final data = await _getList('maintenance-records', queryParams: query);
    return data.map((m) => MaintenanceRecordModel.fromMap(m, m['id'] as String)).toList();
  }

  Future<void> createMaintenanceRecord(MaintenanceRecordModel record) async {
    await _post('maintenance-records', record.toMap());
  }

  // Hospital Pharmacy
  Future<List<HospitalPharmacyDispenseModel>> getHospitalPharmacyDispenses({
    String? patientId,
    MedicationDispenseStatus? status,
    DateTime? from,
    DateTime? to,
  }) async {
    final query = <String, String>{};
    if (patientId != null) query['patientId'] = patientId;
    if (status != null) query['status'] = status.toString().split('.').last;
    if (from != null) query['from'] = from.millisecondsSinceEpoch.toString();
    if (to != null) query['to'] = to.millisecondsSinceEpoch.toString();
    
    final data = await _getList('hospital-pharmacy-dispenses', queryParams: query);
    return data.map((m) => HospitalPharmacyDispenseModel.fromMap(m, m['id'] as String)).toList();
  }

  Future<void> createHospitalPharmacyDispense(HospitalPharmacyDispenseModel dispense) async {
    await _post('hospital-pharmacy-dispenses', dispense.toMap());
  }

  Future<void> updateDispenseStatus(String id, MedicationDispenseStatus status, {String? dispensedBy}) async {
    final body = <String, dynamic>{
      'status': status.toString().split('.').last,
    };
    if (dispensedBy != null) body['dispensedBy'] = dispensedBy;
    await _put('hospital-pharmacy-dispenses/$id', body);
  }

  Future<List<MedicationScheduleModel>> getMedicationSchedules({
    String? patientId,
    bool? isActive,
  }) async {
    final query = <String, String>{};
    if (patientId != null) query['patientId'] = patientId;
    if (isActive != null) query['isActive'] = isActive.toString();
    
    final data = await _getList('medication-schedules', queryParams: query);
    return data.map((m) => MedicationScheduleModel.fromMap(m, m['id'] as String)).toList();
  }

  Future<void> createMedicationSchedule(MedicationScheduleModel schedule) async {
    await _post('medication-schedules', schedule.toMap());
  }

  // Lab Test Types
  Future<List<LabTestTypeModel>> getLabTestTypes({
    LabTestCategory? category,
    bool? isActive,
  }) async {
    final query = <String, String>{};
    if (category != null) query['category'] = category.toString().split('.').last;
    if (isActive != null) query['isActive'] = isActive.toString();
    
    final data = await _getList('lab-test-types', queryParams: query);
    return data.map((m) => LabTestTypeModel.fromMap(m, m['id'] as String)).toList();
  }

  Future<void> createLabTestType(LabTestTypeModel testType) async {
    await _post('lab-test-types', testType.toMap());
  }

  // Lab Samples
  Future<List<LabSampleModel>> getLabSamples({String? labRequestId}) async {
    final query = <String, String>{};
    if (labRequestId != null) query['labRequestId'] = labRequestId;
    
    final data = await _getList('lab-samples', queryParams: query);
    return data.map((m) => LabSampleModel.fromMap(m, m['id'] as String)).toList();
  }

  Future<void> createLabSample(LabSampleModel sample) async {
    await _post('lab-samples', sample.toMap());
  }

  Future<void> updateLabSampleStatus(String id, LabSampleStatus status, {String? receivedBy}) async {
    final body = <String, dynamic>{
      'status': status.toString().split('.').last,
    };
    if (receivedBy != null) body['receivedBy'] = receivedBy;
    await _put('lab-samples/$id', body);
  }

  // Lab Results
  Future<LabResultModel?> getLabResult(String labRequestId) async {
    try {
      final data = await _get('lab-results/$labRequestId');
      return LabResultModel.fromMap(data, data['id'] as String);
    } catch (e) {
      return null;
    }
  }

  Future<void> createLabResult(LabResultModel result) async {
    await _post('lab-results', result.toMap());
  }

  Future<void> updateLabResult(String id, {
    Map<String, dynamic>? results,
    String? interpretation,
    bool? isCritical,
  }) async {
    final body = <String, dynamic>{};
    if (results != null) body['results'] = results;
    if (interpretation != null) body['interpretation'] = interpretation;
    if (isCritical != null) body['isCritical'] = isCritical;
    await _put('lab-results/$id', body);
  }

  // Lab Schedules
  Future<List<Map<String, dynamic>>> getLabSchedules({
    DateTime? from,
    DateTime? to,
    LabTestPriority? priority,
  }) async {
    final query = <String, String>{};
    if (from != null) query['from'] = from.millisecondsSinceEpoch.toString();
    if (to != null) query['to'] = to.millisecondsSinceEpoch.toString();
    if (priority != null) query['priority'] = priority.toString().split('.').last;
    
    return await _getList('lab-schedules', queryParams: query);
  }

  Future<void> createLabSchedule(Map<String, dynamic> schedule) async {
    await _post('lab-schedules', schedule);
  }
}

