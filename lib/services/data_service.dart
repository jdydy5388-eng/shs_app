import '../config/app_config.dart';
import '../models/system_settings_model.dart';
import '../models/doctor_appointment_model.dart';
import '../models/user_model.dart';
import '../models/notification_model.dart';
import '../models/radiology_model.dart';
import '../models/attendance_model.dart';
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
  Future<void> updateAppointment(String id, {date, status, patientName, type, notes}) async {
    // إذا تم تغيير تاريخ الموعد، نلغي التذكيرات السابقة ثم نعيد جدولتها
    final bool isReschedule = date != null;
    await _service.updateAppointment(id, date: date, status: status, patientName: patientName, type: type, notes: notes);
    if (isReschedule) {
      try {
        // إلغاء التذكيرات المجدولة السابقة
        final existing = await getNotifications(status: NotificationStatus.scheduled, relatedType: 'appointment', relatedId: id);
        for (final n in existing) {
          await updateNotificationStatus((n as dynamic).id as String, NotificationStatus.cancelled);
        }
      } catch (_) {}
      // جلب الموعد بعد التحديث لإعادة الجدولة
      try {
        // محليًا لا يوجد endpoint مباشر لجلب موعد واحد، لذا لنحاول عبر قوائم الطبيب/المريض لو توفر لدينا معلومات
        // في السيناريو العام، سنكتفي بإعادة الجدولة اعتمادًا على التاريخ الجديد المرسل (date) مع بيانات سابقة محفوظة لدينا إن لزم
      } catch (_) {}
    }
  }
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

  // Billing
  Future<List> getInvoices({String? patientId, status}) => _service.getInvoices(patientId: patientId, status: status);
  Future getInvoice(String id) => _service.getInvoice(id);
  Future<void> createInvoice(invoice) => _service.createInvoice(invoice);
  Future<void> updateInvoice(String id, {items, subtotal, discount, tax, total, currency, insuranceProvider, insurancePolicy}) => 
      _service.updateInvoice(id, items: items, subtotal: subtotal, discount: discount, tax: tax, total: total, currency: currency, insuranceProvider: insuranceProvider, insurancePolicy: insurancePolicy);
  Future<void> updateInvoiceStatus(String id, status) => _service.updateInvoiceStatus(id, status);
  
  // Payments
  Future<List> getPayments({String? invoiceId}) => _service.getPayments(invoiceId: invoiceId);
  Future<void> createPayment(payment) => _service.createPayment(payment);

  // Rooms & Beds
  Future<List> getRooms() => _service.getRooms();
  Future<void> createRoom(room) => _service.createRoom(room);
  Future<void> updateRoom(String id, {name, type, floor, notes}) => _service.updateRoom(id, name: name, type: type, floor: floor, notes: notes);

  Future<List> getBeds({String? roomId, status}) => _service.getBeds(roomId: roomId, status: status);
  Future<void> createBed(bed) => _service.createBed(bed);
  Future<void> updateBed(String id, {label, status, patientId, occupiedSince}) => 
      _service.updateBed(id, label: label, status: status, patientId: patientId, occupiedSince: occupiedSince);
  Future<void> assignBed(String bedId, String patientId) => _service.assignBed(bedId, patientId);
  Future<void> releaseBed(String bedId) => _service.releaseBed(bedId);
  Future<void> createTransfer({required String id, required String patientId, String? fromBedId, required String toBedId, String? reason}) => 
      _service.createTransfer(id: id, patientId: patientId, fromBedId: fromBedId, toBedId: toBedId, reason: reason);

  // Emergency
  Future<List> getEmergencyCases({status, triage}) => _service.getEmergencyCases(status: status, triage: triage);
  Future<void> createEmergencyCase(c) => _service.createEmergencyCase(c);
  Future<void> updateEmergencyCase(String id, {patientId, patientName, triageLevel, status, vitalSigns, symptoms, notes}) =>
      _service.updateEmergencyCase(id, patientId: patientId, patientName: patientName, triageLevel: triageLevel, status: status, vitalSigns: vitalSigns, symptoms: symptoms, notes: notes);
  Future<void> updateEmergencyStatus(String id, status) => _service.updateEmergencyStatus(id, status);
  Future<List> getEmergencyEvents({String? caseId}) => _service.getEmergencyEvents(caseId: caseId);
  Future<void> createEmergencyEvent(e) => _service.createEmergencyEvent(e);

  // Surgeries
  Future<List> getSurgeries({patientId, surgeonId, status, from, to}) => 
      _service.getSurgeries(patientId: patientId, surgeonId: surgeonId, status: status, from: from, to: to);
  Future<void> createSurgery(surgery) => _service.createSurgery(surgery);
  Future<void> updateSurgery(String id, {status, startTime, endTime, preOperativeNotes, operativeNotes, postOperativeNotes}) =>
      _service.updateSurgery(id, status: status, startTime: startTime, endTime: endTime, preOperativeNotes: preOperativeNotes, operativeNotes: operativeNotes, postOperativeNotes: postOperativeNotes);

  // Medical Inventory
  Future<List> getMedicalInventory({type, status, category}) => 
      _service.getMedicalInventory(type: type, status: status, category: category);
  Future<void> createMedicalInventoryItem(item) => _service.createMedicalInventoryItem(item);
  Future<void> updateMedicalInventoryItem(String id, {quantity, status, nextMaintenanceDate}) =>
      _service.updateMedicalInventoryItem(id, quantity: quantity, status: status, nextMaintenanceDate: nextMaintenanceDate);

  // Suppliers
  Future<List> getSuppliers() => _service.getSuppliers();
  Future<void> createSupplier(supplier) => _service.createSupplier(supplier);

  // Purchase Orders
  Future<List> getPurchaseOrders({status}) => _service.getPurchaseOrders(status: status);
  Future<void> createPurchaseOrder(order) => _service.createPurchaseOrder(order);

  // Maintenance Records
  Future<List> getMaintenanceRecords({equipmentId}) => _service.getMaintenanceRecords(equipmentId: equipmentId);
  Future<void> createMaintenanceRecord(record) => _service.createMaintenanceRecord(record);

  // Hospital Pharmacy
  Future<List> getHospitalPharmacyDispenses({patientId, status, from, to}) =>
      _service.getHospitalPharmacyDispenses(patientId: patientId, status: status, from: from, to: to);
  Future<void> createHospitalPharmacyDispense(dispense) => _service.createHospitalPharmacyDispense(dispense);
  Future<void> updateDispenseStatus(String id, status, {dispensedBy}) =>
      _service.updateDispenseStatus(id, status, dispensedBy: dispensedBy);
  Future<List> getMedicationSchedules({patientId, isActive}) =>
      _service.getMedicationSchedules(patientId: patientId, isActive: isActive);
  Future<void> createMedicationSchedule(schedule) => _service.createMedicationSchedule(schedule);

  // Lab Test Types
  Future<List> getLabTestTypes({category, isActive}) =>
      _service.getLabTestTypes(category: category, isActive: isActive);
  Future<void> createLabTestType(testType) => _service.createLabTestType(testType);

  // Lab Samples
  Future<List> getLabSamples({labRequestId}) => _service.getLabSamples(labRequestId: labRequestId);
  Future<void> createLabSample(sample) => _service.createLabSample(sample);
  Future<void> updateLabSampleStatus(String id, status, {receivedBy}) =>
      _service.updateLabSampleStatus(id, status, receivedBy: receivedBy);

  // Lab Results
  Future getLabResult(String labRequestId) => _service.getLabResult(labRequestId);
  Future<void> createLabResult(result) => _service.createLabResult(result);
  Future<void> updateLabResult(String id, {results, interpretation, isCritical}) =>
      _service.updateLabResult(id, results: results, interpretation: interpretation, isCritical: isCritical);

  // Lab Schedules
  Future<List> getLabSchedules({from, to, priority}) =>
      _service.getLabSchedules(from: from, to: to, priority: priority);
  Future<void> createLabSchedule(schedule) => _service.createLabSchedule(schedule);

  // Notifications (SMS/Email)
  Future<List> getNotifications({status, String? relatedType, String? relatedId}) => 
      _service.getNotifications(status: status, relatedType: relatedType, relatedId: relatedId);
  Future<void> scheduleNotification(notification) => _service.scheduleNotification(notification);
  Future<void> updateNotificationStatus(String id, status, {String? error}) => 
      _service.updateNotificationStatus(id, status, error: error);

  // Helpers: Auto-schedule appointment reminders (24h & 2h before)
  Future<void> createAppointmentWithReminders(DoctorAppointment appointment) async {
    await _service.createAppointment(appointment);
    await _tryScheduleAppointmentReminders(appointment);
  }

  // Radiology
  Future<List> getRadiologyRequests({String? doctorId, String? patientId, String? status, String? modality}) =>
      _service.getRadiologyRequests(doctorId: doctorId, patientId: patientId, status: status, modality: modality);
  Future<void> createRadiologyRequest(request) => _service.createRadiologyRequest(request);
  Future<void> updateRadiologyRequest(String id, {modality, bodyPart, notes, scheduledAt, completedAt}) =>
      _service.updateRadiologyRequest(id, modality: modality, bodyPart: bodyPart, notes: notes, scheduledAt: scheduledAt, completedAt: completedAt);
  Future<void> updateRadiologyStatus(String id, status) => _service.updateRadiologyStatus(id, status);
  Future<List> getRadiologyReports({String? requestId}) => _service.getRadiologyReports(requestId: requestId);
  Future<void> createRadiologyReport(report) => _service.createRadiologyReport(report);

  // File Uploads
  Future<String> uploadFile({required String filename, required List<int> bytes, String? contentType}) =>
      _service.uploadFile(filename: filename, bytes: bytes, contentType: contentType);

  // Signed file URLs (network only; locally نعيد المدخل كما هو)
  Future<String> getSignedFileUrl(String fileUrlOrName, {int expiresSeconds = 300}) async {
    if (AppConfig.isLocalMode) return fileUrlOrName;
    return _networkService.getSignedFileUrl(fileUrlOrName, expiresSeconds: expiresSeconds);
  }

  Future<void> _tryScheduleAppointmentReminders(DoctorAppointment appointment) async {
    try {
      if ((appointment.patientId ?? '').isEmpty) return;
      final user = await getUser(appointment.patientId as String) as UserModel;
      final date = appointment.date;
      final now = DateTime.now();

      final List<DateTime> scheduleTimes = [
        date.subtract(const Duration(hours: 24)),
        date.subtract(const Duration(hours: 2)),
      ].where((t) => t.isAfter(now)).toList();
      if (scheduleTimes.isEmpty) return;

      // إنشاء رسائل SMS إذا توفر رقم هاتف
      if ((user.phone).trim().isNotEmpty) {
        for (final t in scheduleTimes) {
          final id = generateId();
          final sms = NotificationModel(
            id: id,
            type: NotificationType.sms,
            recipient: user.phone,
            subject: null,
            message: 'تذكير بالموعد الطبي مع الطبيب يوم ${date.toLocal()} للمريض ${appointment.patientName}.',
            scheduledAt: t,
            status: NotificationStatus.scheduled,
            relatedType: 'appointment',
            relatedId: appointment.id,
            createdAt: DateTime.now(),
            sentAt: null,
            error: null,
          );
          await scheduleNotification(sms);
        }
      }

      // إنشاء رسائل Email إذا توفر بريد
      if ((user.email).trim().isNotEmpty) {
        for (final t in scheduleTimes) {
          final id = generateId();
          final email = NotificationModel(
            id: id,
            type: NotificationType.email,
            recipient: user.email,
            subject: 'تذكير بموعدك الطبي',
            message: 'مرحبًا ${user.name}, لديك موعد طبي بتاريخ ${date.toLocal()} لدى ${appointment.type ?? 'العيادة'}.',
            scheduledAt: t,
            status: NotificationStatus.scheduled,
            relatedType: 'appointment',
            relatedId: appointment.id,
            createdAt: DateTime.now(),
            sentAt: null,
            error: null,
          );
          await scheduleNotification(email);
        }
      }
    } catch (_) {
      // لا نُفشل العملية الأساسية في حال فشل جدولة التذكير
    }
  }

  // Attendance & Shifts
  Future<List> getAttendance({String? userId, DateTime? from, DateTime? to}) => _service.getAttendance(userId: userId, from: from, to: to);
  Future<void> createAttendance(attendance) => _service.createAttendance(attendance);
  Future<void> updateAttendance(String id, {DateTime? checkOut, double? locationLat, double? locationLng, String? notes}) => 
      _service.updateAttendance(id, checkOut: checkOut, locationLat: locationLat, locationLng: locationLng, notes: notes);

  Future<List> getShifts({String? userId}) => _service.getShifts(userId: userId);
  Future<void> createShift(shift) => _service.createShift(shift);
  Future<void> updateShift(String id, {DateTime? startTime, DateTime? endTime, String? department, String? recurrence}) => 
      _service.updateShift(id, startTime: startTime, endTime: endTime, department: department, recurrence: recurrence);
  Future<void> deleteShift(String id) => _service.deleteShift(id);

  // Documents
  Future<List> getDocuments({category, status, accessLevel, patientId, doctorId, searchQuery, userId}) =>
      _service.getDocuments(category: category, status: status, accessLevel: accessLevel, patientId: patientId, doctorId: doctorId, searchQuery: searchQuery, userId: userId);
  Future getDocument(String id) => _service.getDocument(id);
  Future<void> createDocument(document) => _service.createDocument(document);
  Future<void> updateDocument(String id, {title, description, category, status, accessLevel, sharedWithUserIds, tags, signatureId, signedAt, signedBy, archivedAt, archivedBy}) =>
      _service.updateDocument(id, title: title, description: description, category: category, status: status, accessLevel: accessLevel, sharedWithUserIds: sharedWithUserIds, tags: tags, signatureId: signatureId, signedAt: signedAt, signedBy: signedBy, archivedAt: archivedAt, archivedBy: archivedBy);
  Future<void> deleteDocument(String id) => _service.deleteDocument(id);
  Future<void> createDocumentSignature(signature) => _service.createDocumentSignature(signature);
  Future getDocumentSignature(String documentId) => _service.getDocumentSignature(documentId);

  // Quality Management - KPIs
  Future<List> getKPIs({category}) => _service.getKPIs(category: category);
  Future getKPI(String id) => _service.getKPI(id);
  Future<void> createKPI(kpi) => _service.createKPI(kpi);
  Future<void> updateKPI(String id, {currentValue, lastUpdated, updatedBy}) =>
      _service.updateKPI(id, currentValue: currentValue, lastUpdated: lastUpdated, updatedBy: updatedBy);

  // Medical Incidents
  Future<List> getMedicalIncidents() => _service.getMedicalIncidents();
  Future<void> createMedicalIncident(incident) => _service.createMedicalIncident(incident);

  // Complaints
  Future<List> getComplaints() => _service.getComplaints();

  // Accreditation Requirements
  Future<List> getAccreditationRequirements() => _service.getAccreditationRequirements();

  // HR Management - Employees
  Future<List> getEmployees({status}) => _service.getEmployees(status: status);
  Future getEmployee(String id) => _service.getEmployee(id);
  Future<void> createEmployee(employee) => _service.createEmployee(employee);

  // Leave Requests
  Future<List> getLeaveRequests({status}) => _service.getLeaveRequests(status: status);
  Future<void> createLeaveRequest(leave) => _service.createLeaveRequest(leave);

  // Payroll
  Future<List> getPayrolls({status}) => _service.getPayrolls(status: status);
  Future<void> createPayroll(payroll) => _service.createPayroll(payroll);

  // Training
  Future<List> getTrainings() => _service.getTrainings();
  Future<void> createTraining(training) => _service.createTraining(training);

  // Certifications
  Future<List> getCertifications() => _service.getCertifications();
  Future<void> createCertification(cert) => _service.createCertification(cert);

  // Maintenance Management - Maintenance Requests
  Future<List> getMaintenanceRequests({status}) => _service.getMaintenanceRequests(status: status);
  Future<void> createMaintenanceRequest(request) => _service.createMaintenanceRequest(request);

  // Scheduled Maintenance
  Future<List> getScheduledMaintenances() => _service.getScheduledMaintenances();
  Future<void> createScheduledMaintenance(maintenance) => _service.createScheduledMaintenance(maintenance);

  // Equipment Status
  Future<List> getEquipmentStatuses() => _service.getEquipmentStatuses();
  Future<void> createEquipmentStatus(status) => _service.createEquipmentStatus(status);

  // Maintenance Vendors
  Future<List> getMaintenanceVendors() => _service.getMaintenanceVendors();
  Future<void> createMaintenanceVendor(vendor) => _service.createMaintenanceVendor(vendor);
}

