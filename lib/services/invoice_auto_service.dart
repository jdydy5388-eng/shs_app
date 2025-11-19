import 'package:uuid/uuid.dart';
import '../models/invoice_model.dart';
import '../models/user_model.dart';
import '../models/doctor_appointment_model.dart';
import 'data_service.dart';

/// خدمة إنشاء الفواتير تلقائياً
class InvoiceAutoService {
  final DataService _dataService = DataService();
  final Uuid _uuid = const Uuid();

  /// إنشاء فاتورة تلقائية للموعد
  Future<InvoiceModel> createAppointmentInvoice({
    required DoctorAppointment appointment,
    required UserModel patient,
    double appointmentFee = 100.0, // رسوم الموعد الافتراضية
    String? insuranceProvider,
    String? insurancePolicy,
  }) async {
    final items = [
      InvoiceItem(
        description: 'رسوم الموعد الطبي - ${appointment.type}',
        quantity: 1,
        unitPrice: appointmentFee,
      ),
    ];

    final subtotal = items.fold(0.0, (sum, item) => sum + item.total);
    final tax = subtotal * 0.15; // ضريبة 15%
    final total = subtotal + tax;

    final invoice = InvoiceModel(
      id: _uuid.v4(),
      patientId: patient.id,
      patientName: patient.name,
      relatedType: 'appointment',
      relatedId: appointment.id,
      items: items,
      subtotal: subtotal,
      discount: 0,
      tax: tax,
      total: total,
      currency: 'SAR',
      status: InvoiceStatus.issued,
      insuranceProvider: insuranceProvider,
      insurancePolicy: insurancePolicy,
      createdAt: DateTime.now(),
    );

    await _dataService.createInvoice(invoice);
    return invoice;
  }

  /// إنشاء فاتورة تلقائية للعملية الجراحية
  Future<InvoiceModel> createSurgeryInvoice({
    required UserModel patient,
    required String surgeryName,
    required double surgeryFee,
    String? surgeryId,
    String? insuranceProvider,
    String? insurancePolicy,
    List<InvoiceItem>? additionalItems,
  }) async {
    final items = [
      InvoiceItem(
        description: 'رسوم العملية الجراحية - $surgeryName',
        quantity: 1,
        unitPrice: surgeryFee,
      ),
      ...?additionalItems,
    ];

    final subtotal = items.fold(0.0, (sum, item) => sum + item.total);
    final tax = subtotal * 0.15; // ضريبة 15%
    final total = subtotal + tax;

    final invoice = InvoiceModel(
      id: _uuid.v4(),
      patientId: patient.id,
      patientName: patient.name,
      relatedType: 'surgery',
      relatedId: surgeryId,
      items: items,
      subtotal: subtotal,
      discount: 0,
      tax: tax,
      total: total,
      currency: 'SAR',
      status: InvoiceStatus.issued,
      insuranceProvider: insuranceProvider,
      insurancePolicy: insurancePolicy,
      createdAt: DateTime.now(),
    );

    await _dataService.createInvoice(invoice);
    return invoice;
  }

  /// إنشاء فاتورة تلقائية للإقامة في المستشفى
  Future<InvoiceModel> createStayInvoice({
    required UserModel patient,
    required String roomId,
    required String roomName,
    required int days,
    required double dailyRate,
    String? stayId,
    String? insuranceProvider,
    String? insurancePolicy,
    List<InvoiceItem>? additionalItems,
  }) async {
    final items = [
      InvoiceItem(
        description: 'رسوم الإقامة - $roomName',
        quantity: days,
        unitPrice: dailyRate,
      ),
      ...?additionalItems,
    ];

    final subtotal = items.fold(0.0, (sum, item) => sum + item.total);
    final tax = subtotal * 0.15; // ضريبة 15%
    final total = subtotal + tax;

    final invoice = InvoiceModel(
      id: _uuid.v4(),
      patientId: patient.id,
      patientName: patient.name,
      relatedType: 'stay',
      relatedId: stayId,
      items: items,
      subtotal: subtotal,
      discount: 0,
      tax: tax,
      total: total,
      currency: 'SAR',
      status: InvoiceStatus.issued,
      insuranceProvider: insuranceProvider,
      insurancePolicy: insurancePolicy,
      createdAt: DateTime.now(),
    );

    await _dataService.createInvoice(invoice);
    return invoice;
  }

  /// إنشاء فاتورة تلقائية للفحوصات المخبرية
  Future<InvoiceModel> createLabInvoice({
    required UserModel patient,
    required String labRequestId,
    required List<Map<String, dynamic>> tests, // [{name, price}]
    String? insuranceProvider,
    String? insurancePolicy,
  }) async {
    final items = tests.map((test) => InvoiceItem(
          description: test['name'] as String,
          quantity: 1,
          unitPrice: (test['price'] as num).toDouble(),
        )).toList();

    final subtotal = items.fold(0.0, (sum, item) => sum + item.total);
    final tax = subtotal * 0.15; // ضريبة 15%
    final total = subtotal + tax;

    final invoice = InvoiceModel(
      id: _uuid.v4(),
      patientId: patient.id,
      patientName: patient.name,
      relatedType: 'lab',
      relatedId: labRequestId,
      items: items,
      subtotal: subtotal,
      discount: 0,
      tax: tax,
      total: total,
      currency: 'SAR',
      status: InvoiceStatus.issued,
      insuranceProvider: insuranceProvider,
      insurancePolicy: insurancePolicy,
      createdAt: DateTime.now(),
    );

    await _dataService.createInvoice(invoice);
    return invoice;
  }

  /// إنشاء فاتورة تلقائية للأشعة
  Future<InvoiceModel> createRadiologyInvoice({
    required UserModel patient,
    required String radiologyRequestId,
    required String radiologyType,
    required double fee,
    String? insuranceProvider,
    String? insurancePolicy,
  }) async {
    final items = [
      InvoiceItem(
        description: 'رسوم الأشعة - $radiologyType',
        quantity: 1,
        unitPrice: fee,
      ),
    ];

    final subtotal = items.fold(0.0, (sum, item) => sum + item.total);
    final tax = subtotal * 0.15; // ضريبة 15%
    final total = subtotal + tax;

    final invoice = InvoiceModel(
      id: _uuid.v4(),
      patientId: patient.id,
      patientName: patient.name,
      relatedType: 'radiology',
      relatedId: radiologyRequestId,
      items: items,
      subtotal: subtotal,
      discount: 0,
      tax: tax,
      total: total,
      currency: 'SAR',
      status: InvoiceStatus.issued,
      insuranceProvider: insuranceProvider,
      insurancePolicy: insurancePolicy,
      createdAt: DateTime.now(),
    );

    await _dataService.createInvoice(invoice);
    return invoice;
  }
}

