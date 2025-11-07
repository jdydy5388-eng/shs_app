import '../config/app_config.dart';
import '../models/system_settings_model.dart';
import 'local_data_service.dart';
import 'network_data_service.dart';

/// خدمة موحدة للبيانات - تتبدل تلقائياً بين الوضع المحلي والشبكي
class DataService {
  static DataService? _instance;
  
  final LocalDataService _localService = LocalDataService();
  final NetworkDataService _networkService = NetworkDataService();

  DataService._internal();
  
  factory DataService() {
    _instance ??= DataService._internal();
    return _instance!;
  }

  // اختيار الخدمة المناسبة
  dynamic get _service => AppConfig.isLocalMode ? _localService : _networkService;

  // Users
  Future<List> getUsers({role}) => _service.getUsers(role: role);
  Future<List> getPatients() => _service.getPatients();
  Future getUser(String userId) => _service.getUser(userId);
  Future<void> createUser(user, password) => _service.createUser(user, password);
  Future<void> updateUser(String userId, updates) => _service.updateUser(userId, updates);
  Future<void> deleteUser(String userId) => _service.deleteUser(userId);

  // Prescriptions
  Future<List> getPrescriptions({String? patientId, String? doctorId}) => 
      _service.getPrescriptions(patientId: patientId, doctorId: doctorId);
  Future<void> createPrescription(prescription) => _service.createPrescription(prescription);
  Future<void> updatePrescriptionStatus(String id, status) => 
      _service.updatePrescriptionStatus(id, status);

  // Orders
  Future<List> getOrders({String? patientId, String? pharmacyId}) => 
      _service.getOrders(patientId: patientId, pharmacyId: pharmacyId);
  Future<String> createOrderFromPrescription({
    required patient,
    required pharmacy,
    required prescription,
    String? deliveryAddress,
    String? notes,
  }) => _service.createOrderFromPrescription(
    patient: patient,
    pharmacy: pharmacy,
    prescription: prescription,
    deliveryAddress: deliveryAddress,
    notes: notes,
  );
  Future<void> updateOrderStatus(String id, status, {String? notes}) => 
      _service.updateOrderStatus(id, status, notes: notes);
  Future<void> suggestOrderAlternative({
    required String orderId,
    required String orderItemId,
    required alternative,
  }) => _service.suggestOrderAlternative(
    orderId: orderId,
    orderItemId: orderItemId,
    alternative: alternative,
  );
  Future<void> approveOrderAlternative({
    required String orderId,
    required String orderItemId,
  }) => _service.approveOrderAlternative(
    orderId: orderId,
    orderItemId: orderItemId,
  );
  Future<void> rejectOrderAlternative({
    required String orderId,
    required String orderItemId,
  }) => _service.rejectOrderAlternative(
    orderId: orderId,
    orderItemId: orderItemId,
  );

  // Appointments
  Future<List> getDoctorAppointments(String doctorId, {
    status,
    DateTime? from,
    DateTime? to,
  }) => _service.getDoctorAppointments(doctorId, status: status, from: from, to: to);
  
  Future<List> getPatientAppointments(String patientId, {
    status,
    DateTime? from,
    DateTime? to,
  }) => _service.getPatientAppointments(patientId, status: status, from: from, to: to);
  
  Future<void> createAppointment(appointment) => _service.createAppointment(appointment);
  Future<void> updateAppointmentStatus(String id, status) => 
      _service.updateAppointmentStatus(id, status);
  Future<void> updateAppointment(String id, {date, status, patientName, type, notes}) => 
      _service.updateAppointment(id, date: date, status: status, patientName: patientName, type: type, notes: notes);
  Future<void> deleteAppointment(String id) => _service.deleteAppointment(id);

  // Medical Records
  Future<List> getMedicalRecords({String? patientId}) => 
      _service.getMedicalRecords(patientId: patientId);
  Future<void> addMedicalRecord(record) => _service.addMedicalRecord(record);

  // Inventory
  Future<List> getInventory({String? pharmacyId}) => 
      _service.getInventory(pharmacyId: pharmacyId);
  Future<void> addInventoryItem(item) => _service.addInventoryItem(item);
  Future<void> updateInventoryItem(String id, {quantity, price, manufacturer, expiryDate, batchNumber}) => 
      _service.updateInventoryItem(id, quantity: quantity, price: price, manufacturer: manufacturer, expiryDate: expiryDate, batchNumber: batchNumber);
  Future<void> deleteInventoryItem(String id) => _service.deleteInventoryItem(id);

  // Lab Requests
  Future<List> getLabRequests({String? doctorId, String? patientId}) => 
      _service.getLabRequests(doctorId: doctorId, patientId: patientId);
  Future<void> createLabRequest(request) => _service.createLabRequest(request);
  Future<void> updateLabRequest(String id, {status, resultNotes, resultAttachments}) => 
      _service.updateLabRequest(id, status: status, resultNotes: resultNotes, resultAttachments: resultAttachments);

  // Entities
  Future<List> getEntities({String? type}) => _service.getEntities(type: type);
  Future<void> createEntity(entity) => _service.createEntity(entity);
  Future<void> updateEntity(String id, {name, address, phone, email, locationLat, locationLng}) => 
      _service.updateEntity(id, name: name, address: address, phone: phone, email: email, locationLat: locationLat, locationLng: locationLng);
  Future<void> deleteEntity(String id) => _service.deleteEntity(id);

  // Audit Logs
  Future<List> getAuditLogs({String? userId, String? resourceType, int limit = 100}) => 
      _service.getAuditLogs(userId: userId, resourceType: resourceType, limit: limit);
  Future<void> createAuditLog(log) => _service.createAuditLog(log);

  // System Settings
  Future getSystemSetting(String key) => _service.getSystemSetting(key);
  Future<List> getAllSystemSettings() => _service.getAllSystemSettings();
  Future<void> updateSystemSetting(String key, String value, {String? description}) => 
      _service.updateSystemSetting(key, value, description: description);
  
  // Biometric Settings
  Future<bool> isBiometricEnabled() {
    if (AppConfig.isLocalMode) {
      return _service.isBiometricEnabled();
    }
    // في الوضع الشبكي، نستخدم system settings
    return _service.getSystemSetting('biometric_enabled').then((setting) {
      if (setting == null) return false;
      return (setting as SystemSettingsModel).boolValue;
    }).catchError((_) => false);
  }
  
  Future<void> setBiometricEnabled(bool enabled, {String? updatedBy}) {
    if (AppConfig.isLocalMode) {
      return _service.setBiometricEnabled(enabled, updatedBy: updatedBy);
    }
    // في الوضع الشبكي، نستخدم system settings
    return _service.updateSystemSetting(
      'biometric_enabled',
      enabled.toString(),
      description: 'Biometric authentication enabled/disabled',
    );
  }
  
  // Doctor Stats
  Future<DoctorStats> getDoctorStats(String doctorId) {
    if (AppConfig.isLocalMode) {
      return _service.getDoctorStats(doctorId);
    }
    throw UnimplementedError('Doctor stats not available in network mode yet');
  }

  // Doctor Tasks (محلي فقط في الوقت الحالي)
  Future<List> getDoctorTasks(String doctorId, {bool? isCompleted}) {
    if (AppConfig.isLocalMode) {
      return _service.getDoctorTasks(doctorId, isCompleted: isCompleted);
    }
    throw UnimplementedError('Doctor tasks not available in network mode yet');
  }

  Future<void> createTask(task) {
    if (AppConfig.isLocalMode) {
      return _service.createTask(task);
    }
    throw UnimplementedError('Doctor tasks not available in network mode yet');
  }

  Future<void> toggleTaskCompletion(String taskId, bool isCompleted) {
    if (AppConfig.isLocalMode) {
      return _service.toggleTaskCompletion(taskId, isCompleted);
    }
    throw UnimplementedError('Doctor tasks not available in network mode yet');
  }

  Future<void> deleteTask(String taskId) {
    if (AppConfig.isLocalMode) {
      return _service.deleteTask(taskId);
    }
    throw UnimplementedError('Doctor tasks not available in network mode yet');
  }

  String generateId() => _service.generateId();

  // Authentication methods
  Future<Map<String, dynamic>> registerUser({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
    Map<String, dynamic>? additionalInfo,
  }) {
    if (AppConfig.isLocalMode) {
      throw UnimplementedError('Register should use AuthProvider in local mode');
    }
    return _service.registerUser(
      email: email,
      password: password,
      name: name,
      phone: phone,
      role: role,
      additionalInfo: additionalInfo,
    );
  }

  Future<Map<String, dynamic>> loginUser({
    required String email,
    required String password,
  }) {
    if (AppConfig.isLocalMode) {
      throw UnimplementedError('Login should use AuthProvider in local mode');
    }
    return _service.loginUser(email: email, password: password);
  }

  Future<void> logoutUser() {
    if (AppConfig.isLocalMode) {
      throw UnimplementedError('Logout should use AuthProvider in local mode');
    }
    return _service.logoutUser();
  }
}

