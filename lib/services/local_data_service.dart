import 'dart:async';
import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../models/doctor_appointment_model.dart';
import '../models/doctor_task_model.dart';
import '../models/lab_request_model.dart';
import '../models/medical_record_model.dart';
import '../models/medication_inventory_model.dart';
import '../models/order_model.dart';
import '../models/prescription_model.dart';
import '../models/user_model.dart';
import '../models/entity_model.dart';
import '../models/audit_log_model.dart';
import '../models/system_settings_model.dart';
import '../models/invoice_model.dart';
import '../models/payment_model.dart';
import '../models/room_bed_model.dart';
import '../models/emergency_case_model.dart';
import '../models/notification_model.dart';
import '../models/attendance_model.dart';
import '../models/surgery_model.dart';
import '../models/medical_inventory_model.dart';
import '../models/hospital_pharmacy_model.dart';
import '../models/lab_test_type_model.dart';
import '../models/document_model.dart';
import '../models/quality_models.dart';
import '../models/hr_models.dart';
import '../models/maintenance_models.dart';
import '../models/transportation_models.dart';
import '../models/integration_models.dart';
import 'local_database_service.dart';

class DoctorStats {
  const DoctorStats({
    required this.totalPatients,
    required this.totalPrescriptions,
    required this.activePrescriptions,
    required this.completedAppointments,
    required this.pendingAppointments,
    required this.pendingLabRequests,
  });

  final int totalPatients;
  final int totalPrescriptions;
  final int activePrescriptions;
  final int completedAppointments;
  final int pendingAppointments;
  final int pendingLabRequests;
}

/// خدمة البيانات المحلية - بديل لـ FirebaseService
class LocalDataService {
  LocalDataService();

  final LocalDatabaseService _db = LocalDatabaseService();
  final Uuid _uuid = const Uuid();

  Map<String, dynamic> _normalizeUserMap(Map<String, dynamic> map) {
    Map<String, dynamic>? decodedAdditionalInfo;
    if (map['additional_info'] != null) {
      try {
        decodedAdditionalInfo =
            Map<String, dynamic>.from(jsonDecode(map['additional_info'] as String));
      } catch (_) {
        decodedAdditionalInfo = null;
      }
    }

    return {
      'id': map['id'],
      'name': map['name'],
      'email': map['email'],
      'phone': map['phone'],
      'role': map['role'],
      'profileImageUrl': map['profile_image_url'],
      'additionalInfo': decodedAdditionalInfo,
      'createdAt': map['created_at'],
      'lastLoginAt': map['last_login_at'],
    };
  }

  Future<List<OrderItem>> _getOrderItems(Database db, String orderId) async {
    final itemMaps = await db.query(
      'order_items',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'quantity DESC',
    );

    return itemMaps.map((map) {
      final quantityValue = map['quantity'];
      final priceValue = map['price'];

      return OrderItem(
        id: map['id'] as String,
        medicationId: map['medication_id'] as String? ?? '',
        medicationName: map['medication_name'] as String? ?? '',
        quantity: quantityValue is num
            ? quantityValue.toInt()
            : int.tryParse('$quantityValue') ?? 0,
        price: priceValue is num
            ? priceValue.toDouble()
            : double.tryParse('$priceValue') ?? 0.0,
        alternativeMedicationId: map['alternative_medication_id'] as String?,
        alternativeMedicationName:
            map['alternative_medication_name'] as String?,
        alternativePrice: map['alternative_price'] is num
            ? (map['alternative_price'] as num).toDouble()
            : map['alternative_price'] != null
                ? double.tryParse('${map['alternative_price']}')
                : null,
      );
    }).toList();
  }

  Future<void> _recalculateOrderTotal(Database db, String orderId) async {
    final totals = await db.rawQuery(
      'SELECT SUM(price * quantity) as total FROM order_items WHERE order_id = ?',
      [orderId],
    );

    final total = (totals.first['total'] as num?)?.toDouble() ?? 0.0;

    await db.update(
      'orders',
      {
        'total_amount': total,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  // Users Collection
  Future<List<UserModel>> getUsers({UserRole? role}) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps;

    if (role != null) {
      final roleString = role.toString().split('.').last;
      maps = await db.query(
        'users',
        where: 'role = ?',
        whereArgs: [roleString],
      );
    } else {
      maps = await db.query('users');
    }

    return maps
        .map((map) => UserModel.fromMap(_normalizeUserMap(map), map['id'] as String))
        .toList();
  }

  Stream<List<UserModel>> watchUsers({UserRole? role}) {
    final controller = StreamController<List<UserModel>>();

    Timer.periodic(const Duration(seconds: 2), (timer) async {
      final users = await getUsers(role: role);
      controller.add(users);
    });

    return controller.stream;
  }

  Future<List<UserModel>> getPatients() async {
    return getUsers(role: UserRole.patient);
  }

  Future<List<UserModel>> searchPatients(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return getPatients();
    }
    final patients = await getPatients();
    return patients.where((patient) {
      return patient.name.toLowerCase().contains(normalizedQuery) ||
          patient.email.toLowerCase().contains(normalizedQuery) ||
          patient.phone.toLowerCase().contains(normalizedQuery) ||
          (patient.additionalInfo?['nationalId'] as String?)
                  ?.toLowerCase()
                  .contains(normalizedQuery) ==
              true;
    }).toList();
  }

  // Inventory Collection
  Future<List<MedicationInventoryModel>> getInventory({String? pharmacyId}) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps;

    if (pharmacyId != null) {
      maps = await db.query(
        'inventory',
        where: 'pharmacy_id = ?',
        whereArgs: [pharmacyId],
      );
    } else {
      maps = await db.query('inventory');
    }

    return maps.map((map) {
      final expiryDateMs = map['expiry_date'] as int?;
      final lastUpdatedMs = map['last_updated'] as int?;

      return MedicationInventoryModel(
        id: map['id'] as String,
        pharmacyId: map['pharmacy_id'] as String? ?? '',
        medicationName: map['medication_name'] as String? ?? '',
        medicationId: map['medication_id'] as String? ?? '',
        quantity: map['quantity'] as int? ?? 0,
        price: (map['price'] as num?)?.toDouble() ?? 0.0,
        manufacturer: map['manufacturer'] as String?,
        expiryDate: expiryDateMs != null
            ? DateTime.fromMillisecondsSinceEpoch(expiryDateMs)
            : null,
        batchNumber: map['batch_number'] as String?,
        lastUpdated: lastUpdatedMs != null
            ? DateTime.fromMillisecondsSinceEpoch(lastUpdatedMs)
            : DateTime.now(),
      );
    }).toList();
  }

  Stream<List<MedicationInventoryModel>> watchInventory({String? pharmacyId}) {
    final controller = StreamController<List<MedicationInventoryModel>>();

    Timer.periodic(const Duration(seconds: 2), (timer) async {
      final inventory = await getInventory(pharmacyId: pharmacyId);
      controller.add(inventory);
    });

    return controller.stream;
  }

  Future<void> addInventoryItem(MedicationInventoryModel item) async {
    final db = await _db.database;
    await db.insert(
      'inventory',
      {
        'id': item.id,
        'pharmacy_id': item.pharmacyId,
        'medication_name': item.medicationName,
        'medication_id': item.medicationId,
        'quantity': item.quantity,
        'price': item.price,
        'manufacturer': item.manufacturer,
        'expiry_date': item.expiryDate?.millisecondsSinceEpoch,
        'batch_number': item.batchNumber,
        'last_updated': item.lastUpdated.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateInventoryItem(String itemId, {
    int? quantity,
    double? price,
    String? manufacturer,
    DateTime? expiryDate,
    String? batchNumber,
  }) async {
    final db = await _db.database;
    final updates = <String, dynamic>{
      'last_updated': DateTime.now().millisecondsSinceEpoch,
    };
    
    if (quantity != null) updates['quantity'] = quantity;
    if (price != null) updates['price'] = price;
    if (manufacturer != null) updates['manufacturer'] = manufacturer;
    if (expiryDate != null) updates['expiry_date'] = expiryDate.millisecondsSinceEpoch;
    if (batchNumber != null) updates['batch_number'] = batchNumber;
    
    await db.update(
      'inventory',
      updates,
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  Future<void> deleteInventoryItem(String itemId) async {
    final db = await _db.database;
    await db.delete(
      'inventory',
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  // Prescriptions Collection
  Future<void> createPrescription(PrescriptionModel prescription) async {
    final db = await _db.database;

    await db.transaction((txn) async {
      await txn.insert(
        'prescriptions',
        {
          'id': prescription.id,
          'doctor_id': prescription.doctorId,
          'doctor_name': prescription.doctorName,
          'patient_id': prescription.patientId,
          'patient_name': prescription.patientName,
          'diagnosis': prescription.diagnosis,
          'notes': prescription.notes,
          'status': prescription.status.toString().split('.').last,
          'created_at': prescription.createdAt.millisecondsSinceEpoch,
          'expires_at': prescription.expiresAt?.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      for (final medication in prescription.medications) {
        await txn.insert(
          'prescription_medications',
          {
            'id': medication.id,
            'prescription_id': prescription.id,
            'name': medication.name,
            'dosage': medication.dosage,
            'frequency': medication.frequency,
            'duration': medication.duration,
            'instructions': medication.instructions,
            'quantity': medication.quantity,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      if (prescription.drugInteractions != null) {
        for (final interaction in prescription.drugInteractions!) {
          await txn.insert(
            'prescription_drug_interactions',
            {
              'prescription_id': prescription.id,
              'interaction': interaction,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  Future<List<PrescriptionModel>> getPrescriptions({String? patientId, String? doctorId}) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps;

    if (patientId != null) {
      maps = await db.query(
        'prescriptions',
        where: 'patient_id = ?',
        whereArgs: [patientId],
        orderBy: 'created_at DESC',
      );
    } else if (doctorId != null) {
      maps = await db.query(
        'prescriptions',
        where: 'doctor_id = ?',
        whereArgs: [doctorId],
        orderBy: 'created_at DESC',
      );
    } else {
      maps = await db.query(
        'prescriptions',
        orderBy: 'created_at DESC',
      );
    }

    final prescriptions = <PrescriptionModel>[];
    for (final map in maps) {
      final id = map['id'] as String;
      final createdAtMs = map['created_at'] as int?;
      final expiresAtMs = map['expires_at'] as int?;

      final medicationsMaps = await db.query(
        'prescription_medications',
        where: 'prescription_id = ?',
        whereArgs: [id],
      );
      final medications = medicationsMaps
          .map(
            (medication) => Medication(
              id: medication['id'] as String,
              name: medication['name'] as String? ?? '',
              dosage: medication['dosage'] as String? ?? '',
              frequency: medication['frequency'] as String? ?? '',
              duration: medication['duration'] as String? ?? '',
              instructions: medication['instructions'] as String? ?? '',
              quantity: medication['quantity'] as int? ?? 0,
            ),
          )
          .toList();

      final interactionMaps = await db.query(
        'prescription_drug_interactions',
        where: 'prescription_id = ?',
        whereArgs: [id],
      );
      final interactions = interactionMaps
          .map((interaction) => interaction['interaction'] as String)
          .toList();

      prescriptions.add(
        PrescriptionModel(
          id: id,
          doctorId: map['doctor_id'] as String? ?? '',
          doctorName: map['doctor_name'] as String? ?? '',
          patientId: map['patient_id'] as String? ?? '',
          patientName: map['patient_name'] as String? ?? '',
          diagnosis: map['diagnosis'] as String? ?? '',
          medications: medications,
          drugInteractions: interactions.isEmpty ? null : interactions,
          notes: map['notes'] as String?,
          status: PrescriptionStatus.values.firstWhere(
            (e) => e.toString().split('.').last == map['status'],
            orElse: () => PrescriptionStatus.pending,
          ),
          createdAt: createdAtMs != null
              ? DateTime.fromMillisecondsSinceEpoch(createdAtMs)
              : DateTime.now(),
          expiresAt: expiresAtMs != null
              ? DateTime.fromMillisecondsSinceEpoch(expiresAtMs)
              : null,
        ),
      );
    }

    return prescriptions;
  }

  Stream<List<PrescriptionModel>> watchPrescriptions({String? patientId, String? doctorId}) {
    final controller = StreamController<List<PrescriptionModel>>();

    Timer.periodic(const Duration(seconds: 2), (timer) async {
      final prescriptions = await getPrescriptions(patientId: patientId, doctorId: doctorId);
      controller.add(prescriptions);
    });

    return controller.stream;
  }

  Future<void> updatePrescriptionStatus(String prescriptionId, PrescriptionStatus status) async {
    final db = await _db.database;
    await db.update(
      'prescriptions',
      {'status': status.toString().split('.').last},
      where: 'id = ?',
      whereArgs: [prescriptionId],
    );
  }

  // Orders Collection
  Future<List<MedicationOrderModel>> getOrders({String? patientId, String? pharmacyId}) async {
    final db = await _db.database;
    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    if (patientId != null) {
      whereClauses.add('patient_id = ?');
      whereArgs.add(patientId);
    }

    if (pharmacyId != null) {
      whereClauses.add('pharmacy_id = ?');
      whereArgs.add(pharmacyId);
    }

    final maps = await db.query(
      'orders',
      where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
      whereArgs: whereClauses.isEmpty ? null : whereArgs,
      orderBy: 'created_at DESC',
    );

    final orders = <MedicationOrderModel>[];

    for (final map in maps) {
      final orderId = map['id'] as String;
      final createdAtMs = map['created_at'] as int?;
      final updatedAtMs = map['updated_at'] as int?;
      final deliveredAtMs = map['delivered_at'] as int?;
      final statusRaw = (map['status'] ?? '').toString();

      final items = await _getOrderItems(db, orderId);

      orders.add(
        MedicationOrderModel(
          id: orderId,
          patientId: map['patient_id'] as String? ?? '',
          patientName: map['patient_name'] as String? ?? '',
          pharmacyId: map['pharmacy_id'] as String? ?? '',
          pharmacyName: map['pharmacy_name'] as String? ?? '',
          prescriptionId: map['prescription_id'] as String?,
          items: items,
          status: OrderStatus.values.firstWhere(
            (e) => e.toString().split('.').last == statusRaw,
            orElse: () => OrderStatus.pending,
          ),
          totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
          deliveryAddress: map['delivery_address'] as String?,
          notes: map['notes'] as String?,
          createdAt: createdAtMs != null
              ? DateTime.fromMillisecondsSinceEpoch(createdAtMs)
              : DateTime.now(),
          updatedAt: updatedAtMs != null
              ? DateTime.fromMillisecondsSinceEpoch(updatedAtMs)
              : null,
          deliveredAt: deliveredAtMs != null
              ? DateTime.fromMillisecondsSinceEpoch(deliveredAtMs)
              : null,
        ),
      );
    }

    return orders;
  }

  Stream<List<MedicationOrderModel>> watchOrders({String? patientId, String? pharmacyId}) {
    final controller = StreamController<List<MedicationOrderModel>>();

    Timer.periodic(const Duration(seconds: 2), (timer) async {
      final orders = await getOrders(patientId: patientId, pharmacyId: pharmacyId);
      controller.add(orders);
    });

    return controller.stream;
  }

  Future<String> createOrderFromPrescription({
    required UserModel patient,
    required UserModel pharmacy,
    required PrescriptionModel prescription,
    String? deliveryAddress,
    String? notes,
  }) async {
    if (prescription.medications.isEmpty) {
      throw Exception('لا يوجد أدوية في هذه الوصفة الطبية');
    }

    final db = await _db.database;
    final orderId = _uuid.v4();
    final now = DateTime.now();

    final inventory = await getInventory(pharmacyId: pharmacy.id);
    final inventoryById = {
      for (final item in inventory) item.medicationId: item,
    };
    final inventoryByName = {
      for (final item in inventory) item.medicationName.toLowerCase(): item,
    };

    double totalAmount = 0;

    final batch = db.batch();

    for (final medication in prescription.medications) {
      final quantity = medication.quantity > 0 ? medication.quantity : 1;
      MedicationInventoryModel? matchedInventory = inventoryById[medication.id];
      matchedInventory ??=
          inventoryByName[medication.name.trim().toLowerCase()];

      final price = matchedInventory?.price ?? 0.0;
      totalAmount += price * quantity;

      batch.insert('order_items', {
        'id': _uuid.v4(),
        'order_id': orderId,
        'medication_id': medication.id,
        'medication_name': medication.name,
        'quantity': quantity,
        'price': price,
        'alternative_medication_id': null,
        'alternative_medication_name': null,
        'alternative_price': null,
      });
    }

    batch.insert('orders', {
      'id': orderId,
      'patient_id': patient.id,
      'patient_name': patient.name,
      'pharmacy_id': pharmacy.id,
      'pharmacy_name': pharmacy.pharmacyName ?? pharmacy.name,
      'prescription_id': prescription.id,
      'status': OrderStatus.pending.toString().split('.').last,
      'total_amount': totalAmount,
      'delivery_address': deliveryAddress,
      'notes': notes,
      'created_at': now.millisecondsSinceEpoch,
      'updated_at': now.millisecondsSinceEpoch,
      'delivered_at': null,
    });

    await batch.commit(noResult: true);

    return orderId;
  }

  Future<void> updateOrderStatus(
    String orderId,
    OrderStatus status, {
    String? notes,
  }) async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final values = <String, Object?>{
      'status': status.toString().split('.').last,
      'updated_at': now,
    };

    if (notes != null) {
      values['notes'] = notes;
    }

    if (status == OrderStatus.delivered) {
      values['delivered_at'] = now;
    } else if (status == OrderStatus.cancelled) {
      values['delivered_at'] = null;
    }

    await db.update(
      'orders',
      values,
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<void> suggestOrderAlternative({
    required String orderId,
    required String orderItemId,
    required MedicationInventoryModel alternative,
  }) async {
    final db = await _db.database;

    await db.update(
      'order_items',
      {
        'alternative_medication_id': alternative.id,
        'alternative_medication_name': alternative.medicationName,
        'alternative_price': alternative.price,
      },
      where: 'id = ? AND order_id = ?',
      whereArgs: [orderItemId, orderId],
    );

    await db.update(
      'orders',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<void> approveOrderAlternative({
    required String orderId,
    required String orderItemId,
  }) async {
    final db = await _db.database;
    final items = await db.query(
      'order_items',
      where: 'id = ? AND order_id = ?',
      whereArgs: [orderItemId, orderId],
      limit: 1,
    );

    if (items.isEmpty) {
      return;
    }

    final item = items.first;
    final alternativeId = item['alternative_medication_id'] as String?;
    final alternativeName = item['alternative_medication_name'] as String?;
    final alternativePriceRaw = item['alternative_price'];

    if (alternativeId == null) {
      return;
    }

    final alternativePrice = alternativePriceRaw is num
        ? alternativePriceRaw.toDouble()
        : alternativePriceRaw != null
            ? double.tryParse('$alternativePriceRaw') ?? 0.0
            : (item['price'] as num?)?.toDouble() ?? 0.0;

    await db.update(
      'order_items',
      {
        'medication_id': alternativeId,
        'medication_name': alternativeName ?? item['medication_name'],
        'price': alternativePrice,
        'alternative_medication_id': null,
        'alternative_medication_name': null,
        'alternative_price': null,
      },
      where: 'id = ? AND order_id = ?',
      whereArgs: [orderItemId, orderId],
    );

    await _recalculateOrderTotal(db, orderId);
  }

  Future<void> rejectOrderAlternative({
    required String orderId,
    required String orderItemId,
  }) async {
    final db = await _db.database;

    await db.update(
      'order_items',
      {
        'alternative_medication_id': null,
        'alternative_medication_name': null,
        'alternative_price': null,
      },
      where: 'id = ? AND order_id = ?',
      whereArgs: [orderItemId, orderId],
    );

    await db.update(
      'orders',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  // Medical Records Collection
  Future<void> addMedicalRecord(MedicalRecordModel record) async {
    final db = await _db.database;

    await db.insert(
      'medical_records',
      {
        'id': record.id,
        'patient_id': record.patientId,
        'doctor_id': record.doctorId,
        'doctor_name': record.doctorName,
        'type': record.type.toString().split('.').last,
        'title': record.title,
        'description': record.description,
        'date': record.date.millisecondsSinceEpoch,
        'file_urls': record.fileUrls != null ? jsonEncode(record.fileUrls) : null,
        'additional_data': record.additionalData != null ? jsonEncode(record.additionalData) : null,
        'created_at': record.createdAt.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MedicalRecordModel>> getMedicalRecords({String? patientId}) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps;

    if (patientId != null) {
      maps = await db.query(
        'medical_records',
        where: 'patient_id = ?',
        whereArgs: [patientId],
        orderBy: 'date DESC',
      );
    } else {
      maps = await db.query(
        'medical_records',
        orderBy: 'date DESC',
      );
    }

    return maps.map((map) {
      final dateMs = map['date'] as int?;
      final createdAtMs = map['created_at'] as int?;
      List<String>? fileUrls;
      Map<String, dynamic>? additionalData;

      if (map['file_urls'] != null) {
        try {
          fileUrls = List<String>.from(jsonDecode(map['file_urls'] as String));
        } catch (_) {
          fileUrls = null;
        }
      }

      if (map['additional_data'] != null) {
        try {
          additionalData =
              Map<String, dynamic>.from(jsonDecode(map['additional_data'] as String));
        } catch (_) {
          additionalData = null;
        }
      }

      return MedicalRecordModel(
        id: map['id'] as String,
        patientId: map['patient_id'] as String? ?? '',
        doctorId: map['doctor_id'] as String?,
        doctorName: map['doctor_name'] as String?,
        type: RecordType.values.firstWhere(
          (e) => e.toString().split('.').last == map['type'],
          orElse: () => RecordType.note,
        ),
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        date: dateMs != null
            ? DateTime.fromMillisecondsSinceEpoch(dateMs)
            : DateTime.now(),
        fileUrls: fileUrls,
        additionalData: additionalData,
        createdAt: createdAtMs != null
            ? DateTime.fromMillisecondsSinceEpoch(createdAtMs)
            : DateTime.now(),
      );
    }).toList();
  }

  Stream<List<MedicalRecordModel>> watchMedicalRecords({String? patientId}) {
    final controller = StreamController<List<MedicalRecordModel>>();

    Timer.periodic(const Duration(seconds: 2), (timer) async {
      final records = await getMedicalRecords(patientId: patientId);
      controller.add(records);
    });

    return controller.stream;
  }

  // Doctor Appointments
  Future<void> createAppointment(DoctorAppointment appointment) async {
    final db = await _db.database;
    await db.insert(
      'doctor_appointments',
      appointment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DoctorAppointment>> getDoctorAppointments(
    String doctorId, {
    AppointmentStatus? status,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _db.database;
    final whereClauses = <String>['doctor_id = ?'];
    final whereArgs = <Object>[doctorId];

    if (status != null) {
      whereClauses.add('status = ?');
      whereArgs.add(status.toString().split('.').last);
    }
    if (from != null) {
      whereClauses.add('date >= ?');
      whereArgs.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      whereClauses.add('date <= ?');
      whereArgs.add(to.millisecondsSinceEpoch);
    }

    final maps = await db.query(
      'doctor_appointments',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'date ASC',
    );

    return maps.map(DoctorAppointment.fromMap).toList();
  }

  Future<List<DoctorAppointment>> getPatientAppointments(
    String patientId, {
    AppointmentStatus? status,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _db.database;
    final whereClauses = <String>['patient_id = ?'];
    final whereArgs = <Object>[patientId];

    if (status != null) {
      whereClauses.add('status = ?');
      whereArgs.add(status.toString().split('.').last);
    }
    if (from != null) {
      whereClauses.add('date >= ?');
      whereArgs.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      whereClauses.add('date <= ?');
      whereArgs.add(to.millisecondsSinceEpoch);
    }

    final maps = await db.query(
      'doctor_appointments',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'date ASC',
    );

    return maps.map(DoctorAppointment.fromMap).toList();
  }

  Future<void> updateAppointmentStatus(
    String appointmentId,
    AppointmentStatus status,
  ) async {
    final db = await _db.database;
    await db.update(
      'doctor_appointments',
      {
        'status': status.toString().split('.').last,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [appointmentId],
    );
  }

  Future<void> updateAppointment(
    String appointmentId, {
    DateTime? date,
    AppointmentStatus? status,
    String? patientName,
    String? type,
    String? notes,
  }) async {
    final db = await _db.database;
    final values = <String, Object?>{};

    if (date != null) {
      values['date'] = date.millisecondsSinceEpoch;
    }
    if (status != null) {
      values['status'] = status.toString().split('.').last;
    }
    if (patientName != null) {
      values['patient_name'] = patientName;
    }
    if (type != null) {
      values['type'] = type;
    }
    if (notes != null) {
      values['notes'] = notes;
    }

    if (values.isEmpty) return;

    values['updated_at'] = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      'doctor_appointments',
      values,
      where: 'id = ?',
      whereArgs: [appointmentId],
    );
  }

  Future<void> deleteAppointment(String appointmentId) async {
    final db = await _db.database;
    await db.delete(
      'doctor_appointments',
      where: 'id = ?',
      whereArgs: [appointmentId],
    );
  }

  // Doctor Tasks
  Future<void> createTask(DoctorTask task) async {
    final db = await _db.database;
    await db.insert(
      'doctor_tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DoctorTask>> getDoctorTasks(String doctorId, {bool? isCompleted}) async {
    final db = await _db.database;
    final whereClauses = <String>['doctor_id = ?'];
    final whereArgs = <Object>[doctorId];

    if (isCompleted != null) {
      whereClauses.add('is_completed = ?');
      whereArgs.add(isCompleted ? 1 : 0);
    }

    final maps = await db.query(
      'doctor_tasks',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy:
          'is_completed ASC, (due_date IS NULL) ASC, due_date ASC, created_at DESC',
    );

    return maps.map(DoctorTask.fromMap).toList();
  }

  Future<void> toggleTaskCompletion(String taskId, bool isCompleted) async {
    final db = await _db.database;
    await db.update(
      'doctor_tasks',
      {
        'is_completed': isCompleted ? 1 : 0,
        'completed_at': isCompleted ? DateTime.now().millisecondsSinceEpoch : null,
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  Future<void> deleteTask(String taskId) async {
    final db = await _db.database;
    await db.delete(
      'doctor_tasks',
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  // Lab Requests
  Future<void> createLabRequest(LabRequestModel request) async {
    final db = await _db.database;
    await db.insert(
      'lab_requests',
      request.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<LabRequestModel>> getLabRequests({String? doctorId, String? patientId}) async {
    final db = await _db.database;
    final whereClauses = <String>[];
    final whereArgs = <Object>[];

    if (doctorId != null) {
      whereClauses.add('doctor_id = ?');
      whereArgs.add(doctorId);
    }
    if (patientId != null) {
      whereClauses.add('patient_id = ?');
      whereArgs.add(patientId);
    }

    final maps = await db.query(
      'lab_requests',
      where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
      whereArgs: whereClauses.isEmpty ? null : whereArgs,
      orderBy: 'requested_at DESC',
    );

    return maps.map(LabRequestModel.fromMap).toList();
  }

  Future<void> updateLabRequest(
    String requestId, {
    LabRequestStatus? status,
    String? resultNotes,
    List<String>? attachments,
  }) async {
    final db = await _db.database;
    final values = <String, Object?>{};

    if (status != null) {
      values['status'] = status.toString().split('.').last;
      if (status == LabRequestStatus.completed) {
        values['completed_at'] = DateTime.now().millisecondsSinceEpoch;
      }
    }
    if (resultNotes != null) {
      values['result_notes'] = resultNotes;
    }
    if (attachments != null) {
      values['attachments'] = attachments.join('|');
    }

    if (values.isEmpty) return;

    await db.update(
      'lab_requests',
      values,
      where: 'id = ?',
      whereArgs: [requestId],
    );
  }

  // Helper methods
  Future<void> updateUserLastLogin(String userId) async {
    final db = await _db.database;
    await db.update(
      'users',
      {'last_login_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<DoctorStats> getDoctorStats(String doctorId) async {
    final db = await _db.database;

    final patientsResult = await db.rawQuery(
      'SELECT COUNT(DISTINCT patient_id) as total FROM prescriptions WHERE doctor_id = ?',
      [doctorId],
    );
    final totalPatients = (patientsResult.first['total'] as int?) ?? 0;

    final prescriptionsResult = await db.rawQuery(
      'SELECT COUNT(*) as total FROM prescriptions WHERE doctor_id = ?',
      [doctorId],
    );
    final totalPrescriptions = (prescriptionsResult.first['total'] as int?) ?? 0;

    final activePrescriptionsResult = await db.rawQuery(
      'SELECT COUNT(*) as total FROM prescriptions WHERE doctor_id = ? AND status = ?',
      [doctorId, PrescriptionStatus.active.toString().split('.').last],
    );
    final activePrescriptions =
        (activePrescriptionsResult.first['total'] as int?) ?? 0;

    final completedAppointmentsResult = await db.rawQuery(
      'SELECT COUNT(*) as total FROM doctor_appointments WHERE doctor_id = ? AND status = ?',
      [doctorId, AppointmentStatus.completed.toString().split('.').last],
    );
    final completedAppointments =
        (completedAppointmentsResult.first['total'] as int?) ?? 0;

    final pendingAppointmentsResult = await db.rawQuery(
      'SELECT COUNT(*) as total FROM doctor_appointments WHERE doctor_id = ? AND status IN (?, ?)',
      [
        doctorId,
        AppointmentStatus.scheduled.toString().split('.').last,
        AppointmentStatus.confirmed.toString().split('.').last,
      ],
    );
    final pendingAppointments =
        (pendingAppointmentsResult.first['total'] as int?) ?? 0;

    final pendingLabRequestsResult = await db.rawQuery(
      'SELECT COUNT(*) as total FROM lab_requests WHERE doctor_id = ? AND status IN (?, ?)',
      [
        doctorId,
        LabRequestStatus.pending.toString().split('.').last,
        LabRequestStatus.inProgress.toString().split('.').last,
      ],
    );
    final pendingLabRequests =
        (pendingLabRequestsResult.first['total'] as int?) ?? 0;

    return DoctorStats(
      totalPatients: totalPatients,
      totalPrescriptions: totalPrescriptions,
      activePrescriptions: activePrescriptions,
      completedAppointments: completedAppointments,
      pendingAppointments: pendingAppointments,
      pendingLabRequests: pendingLabRequests,
    );
  }

  // Entities Collection
  Future<void> createEntity(EntityModel entity) async {
    final db = await _db.database;
    await db.insert('entities', entity.toMap());
  }

  Future<List<EntityModel>> getEntities({EntityType? type}) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps;

    if (type != null) {
      maps = await db.query(
        'entities',
        where: 'type = ?',
        whereArgs: [type.toString().split('.').last],
      );
    } else {
      maps = await db.query('entities');
    }

    return maps.map((map) => EntityModel.fromMap(map)).toList();
  }

  Future<void> updateEntity(EntityModel entity) async {
    final db = await _db.database;
    await db.update(
      'entities',
      entity.toMap(),
      where: 'id = ?',
      whereArgs: [entity.id],
    );
  }

  Future<void> deleteEntity(String entityId) async {
    final db = await _db.database;
    await db.delete(
      'entities',
      where: 'id = ?',
      whereArgs: [entityId],
    );
  }

  // Audit Logs Collection
  Future<void> createAuditLog(AuditLogModel log) async {
    final db = await _db.database;
    await db.insert('audit_logs', log.toMap());
  }

  Future<List<AuditLogModel>> getAuditLogs({
    String? userId,
    AuditAction? action,
    int? limit,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _db.database;
    String? where;
    List<dynamic>? whereArgs;

    final conditions = <String>[];
    final args = <dynamic>[];

    if (userId != null) {
      conditions.add('user_id = ?');
      args.add(userId);
    }

    if (action != null) {
      conditions.add('action = ?');
      args.add(action.toString().split('.').last);
    }

    if (startDate != null) {
      conditions.add('timestamp >= ?');
      args.add(startDate.millisecondsSinceEpoch);
    }

    if (endDate != null) {
      conditions.add('timestamp <= ?');
      args.add(endDate.millisecondsSinceEpoch);
    }

    if (conditions.isNotEmpty) {
      where = conditions.join(' AND ');
      whereArgs = args;
    }

    final maps = await db.query(
      'audit_logs',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return maps.map((map) => AuditLogModel.fromMap(map)).toList();
  }

  // System Settings Collection
  Future<SystemSettingsModel?> getSystemSetting(String key) async {
    final db = await _db.database;
    final maps = await db.query(
      'system_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return SystemSettingsModel.fromMap(maps.first);
  }

  Future<List<SystemSettingsModel>> getAllSystemSettings() async {
    final db = await _db.database;
    final maps = await db.query('system_settings');
    return maps.map((map) => SystemSettingsModel.fromMap(map)).toList();
  }

  Future<void> updateSystemSetting({
    required String key,
    required String value,
    String? updatedBy,
  }) async {
    final db = await _db.database;
    final existing = await getSystemSetting(key);

    if (existing != null) {
      // تحديث الإعداد الموجود
      await db.update(
        'system_settings',
        {
          'value': value,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
          'updated_by': updatedBy,
        },
        where: 'key = ?',
        whereArgs: [key],
      );
    } else {
      // إنشاء إعداد جديد
      final setting = SystemSettingsModel(
        id: _uuid.v4(),
        key: key,
        value: value,
        description: 'إعداد النظام',
        updatedAt: DateTime.now(),
        updatedBy: updatedBy,
      );
      await db.insert('system_settings', setting.toMap());
    }
  }

  Future<bool> isBiometricEnabled() async {
    final setting = await getSystemSetting('biometric_enabled');
    return setting?.boolValue ?? false;
  }

  Future<void> setBiometricEnabled(bool enabled, {String? updatedBy}) async {
    await updateSystemSetting(
      key: 'biometric_enabled',
      value: enabled.toString(),
      updatedBy: updatedBy,
    );
  }

  String generateId() => _uuid.v4();

  // Billing - Invoices
  Future<List<InvoiceModel>> getInvoices({String? patientId, InvoiceStatus? status}) async {
    final db = await _db.database;
    final where = <String>[];
    final args = <Object>[];
    if (patientId != null) {
      where.add('patient_id = ?');
      args.add(patientId);
    }
    if (status != null) {
      where.add('status = ?');
      args.add(status.toString().split('.').last);
    }
    final rows = await db.query(
      'invoices',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'created_at DESC',
    );
    return rows.map((r) {
      final itemsStr = r['items'] as String?;
      final items = itemsStr != null
          ? List<Map<String, dynamic>>.from(jsonDecode(itemsStr) as List)
          : <Map<String, dynamic>>[];
      return InvoiceModel.fromMap({
        'id': r['id'],
        'patientId': r['patient_id'],
        'patientName': r['patient_name'],
        'relatedType': r['related_type'],
        'relatedId': r['related_id'],
        'items': items,
        'subtotal': r['subtotal'],
        'discount': r['discount'],
        'tax': r['tax'],
        'total': r['total'],
        'currency': r['currency'],
        'status': r['status'],
        'insuranceProvider': r['insurance_provider'],
        'insurancePolicy': r['insurance_policy'],
        'createdAt': r['created_at'],
        'updatedAt': r['updated_at'],
        'paidAt': r['paid_at'],
      }, r['id'] as String);
    }).toList();
  }

  Future<void> createInvoice(InvoiceModel invoice) async {
    final db = await _db.database;
    await db.insert('invoices', {
      'id': invoice.id,
      'patient_id': invoice.patientId,
      'patient_name': invoice.patientName,
      'related_type': invoice.relatedType,
      'related_id': invoice.relatedId,
      'items': jsonEncode(invoice.items.map((e) => e.toMap()).toList()),
      'subtotal': invoice.subtotal,
      'discount': invoice.discount,
      'tax': invoice.tax,
      'total': invoice.total,
      'currency': invoice.currency,
      'status': invoice.status.toString().split('.').last,
      'insurance_provider': invoice.insuranceProvider,
      'insurance_policy': invoice.insurancePolicy,
      'created_at': invoice.createdAt.millisecondsSinceEpoch,
      'updated_at': invoice.updatedAt?.millisecondsSinceEpoch,
      'paid_at': invoice.paidAt?.millisecondsSinceEpoch,
    });
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
    final db = await _db.database;
    final updates = <String, Object?>{
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    if (items != null) updates['items'] = jsonEncode(items.map((e) => e.toMap()).toList());
    if (subtotal != null) updates['subtotal'] = subtotal;
    if (discount != null) updates['discount'] = discount;
    if (tax != null) updates['tax'] = tax;
    if (total != null) updates['total'] = total;
    if (currency != null) updates['currency'] = currency;
    if (insuranceProvider != null) updates['insurance_provider'] = insuranceProvider;
    if (insurancePolicy != null) updates['insurance_policy'] = insurancePolicy;

    await db.update('invoices', updates, where: 'id = ?', whereArgs: [invoiceId]);
  }

  Future<void> updateInvoiceStatus(String invoiceId, InvoiceStatus status) async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'invoices',
      {
        'status': status.toString().split('.').last,
        'updated_at': now,
        'paid_at': status == InvoiceStatus.paid ? now : null,
      },
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
  }

  Future<InvoiceModel?> getInvoice(String invoiceId) async {
    final db = await _db.database;
    final rows = await db.query(
      'invoices',
      where: 'id = ?',
      whereArgs: [invoiceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    final itemsStr = r['items'] as String?;
    final items = itemsStr != null
        ? List<Map<String, dynamic>>.from(jsonDecode(itemsStr) as List)
        : <Map<String, dynamic>>[];
    return InvoiceModel.fromMap({
      'id': r['id'],
      'patientId': r['patient_id'],
      'patientName': r['patient_name'],
      'relatedType': r['related_type'],
      'relatedId': r['related_id'],
      'items': items,
      'subtotal': r['subtotal'],
      'discount': r['discount'],
      'tax': r['tax'],
      'total': r['total'],
      'currency': r['currency'],
      'status': r['status'],
      'insuranceProvider': r['insurance_provider'],
      'insurancePolicy': r['insurance_policy'],
      'createdAt': r['created_at'],
      'updatedAt': r['updated_at'],
      'paidAt': r['paid_at'],
    }, r['id'] as String);
  }

  // Payments
  Future<List<PaymentModel>> getPayments({String? invoiceId}) async {
    final db = await _db.database;
    final where = <String>[];
    final args = <Object>[];
    if (invoiceId != null) {
      where.add('invoice_id = ?');
      args.add(invoiceId);
    }
    final rows = await db.query(
      'payments',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'created_at DESC',
    );
    return rows.map((r) {
      return PaymentModel.fromMap({
        'id': r['id'],
        'invoiceId': r['invoice_id'],
        'amount': r['amount'],
        'method': r['method'],
        'reference': r['reference'],
        'createdAt': r['created_at'],
        'notes': r['notes'],
      }, r['id'] as String);
    }).toList();
  }

  Future<void> createPayment(PaymentModel payment) async {
    final db = await _db.database;
    await db.insert('payments', {
      'id': payment.id,
      'invoice_id': payment.invoiceId,
      'amount': payment.amount,
      'method': payment.method.toString().split('.').last,
      'reference': payment.reference,
      'created_at': payment.createdAt.millisecondsSinceEpoch,
      'notes': payment.notes,
    });

    // التحقق من إجمالي المدفوعات وتحديث حالة الفاتورة إذا لزم الأمر
    final payments = await getPayments(invoiceId: payment.invoiceId);
    final totalPaid = payments.fold(0.0, (sum, p) => sum + p.amount);
    final invoice = await getInvoice(payment.invoiceId);
    
    if (invoice != null && totalPaid >= invoice.total) {
      await updateInvoiceStatus(payment.invoiceId, InvoiceStatus.paid);
    }
  }

  // Rooms & Beds
  Future<List<RoomModel>> getRooms() async {
    final db = await _db.database;
    final rows = await db.query('rooms', orderBy: 'name ASC');
    return rows.map((r) => RoomModel.fromMap({
      'id': r['id'],
      'name': r['name'],
      'type': r['type'],
      'floor': r['floor'],
      'notes': r['notes'],
      'createdAt': r['created_at'],
      'updatedAt': r['updated_at'],
    })).toList();
  }

  Future<void> createRoom(RoomModel room) async {
    final db = await _db.database;
    await db.insert('rooms', {
      'id': room.id,
      'name': room.name,
      'type': room.type.toString().split('.').last,
      'floor': room.floor,
      'notes': room.notes,
      'created_at': room.createdAt.millisecondsSinceEpoch,
      'updated_at': room.updatedAt?.millisecondsSinceEpoch,
    });
  }

  Future<void> updateRoom(String roomId, {String? name, RoomType? type, int? floor, String? notes}) async {
    final db = await _db.database;
    final updates = <String, Object?>{
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    if (name != null) updates['name'] = name;
    if (type != null) updates['type'] = type.toString().split('.').last;
    if (floor != null) updates['floor'] = floor;
    if (notes != null) updates['notes'] = notes;
    await db.update('rooms', updates, where: 'id = ?', whereArgs: [roomId]);
  }

  Future<List<BedModel>> getBeds({String? roomId, BedStatus? status}) async {
    final db = await _db.database;
    final where = <String>[];
    final args = <Object>[];
    if (roomId != null) {
      where.add('room_id = ?');
      args.add(roomId);
    }
    if (status != null) {
      where.add('status = ?');
      args.add(status.toString().split('.').last);
    }
    final rows = await db.query(
      'beds',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'label ASC',
    );
    return rows.map((r) => BedModel.fromMap({
      'id': r['id'],
      'roomId': r['room_id'],
      'label': r['label'],
      'status': r['status'],
      'patientId': r['patient_id'],
      'occupiedSince': r['occupied_since'],
      'updatedAt': r['updated_at'],
    })).toList();
  }

  Future<void> createBed(BedModel bed) async {
    final db = await _db.database;
    await db.insert('beds', {
      'id': bed.id,
      'room_id': bed.roomId,
      'label': bed.label,
      'status': bed.status.toString().split('.').last,
      'patient_id': bed.patientId,
      'occupied_since': bed.occupiedSince?.millisecondsSinceEpoch,
      'updated_at': bed.updatedAt?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updateBed(String bedId, {String? label, BedStatus? status, String? patientId, DateTime? occupiedSince}) async {
    final db = await _db.database;
    final updates = <String, Object?>{
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    if (label != null) updates['label'] = label;
    if (status != null) updates['status'] = status.toString().split('.').last;
    if (patientId != null) updates['patient_id'] = patientId;
    if (occupiedSince != null) updates['occupied_since'] = occupiedSince.millisecondsSinceEpoch;
    await db.update('beds', updates, where: 'id = ?', whereArgs: [bedId]);
  }

  Future<void> assignBed(String bedId, String patientId) async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'beds',
      {
        'status': BedStatus.occupied.toString().split('.').last,
        'patient_id': patientId,
        'occupied_since': now,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [bedId],
    );
  }

  Future<void> releaseBed(String bedId) async {
    final db = await _db.database;
    await db.update(
      'beds',
      {
        'status': BedStatus.available.toString().split('.').last,
        'patient_id': null,
        'occupied_since': null,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [bedId],
    );
  }

  Future<void> createTransfer({
    required String id,
    required String patientId,
    String? fromBedId,
    required String toBedId,
    String? reason,
  }) async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('bed_transfers', {
      'id': id,
      'patient_id': patientId,
      'from_bed_id': fromBedId,
      'to_bed_id': toBedId,
      'reason': reason,
      'created_at': now,
    });
    // تحديث حالة الأسرة
    if (fromBedId != null) {
      await releaseBed(fromBedId);
    }
    await assignBed(toBedId, patientId);
  }

  // Emergency
  Future<List<EmergencyCaseModel>> getEmergencyCases({EmergencyStatus? status, TriageLevel? triage}) async {
    final db = await _db.database;
    final where = <String>[];
    final args = <Object>[];
    if (status != null) {
      where.add('status = ?');
      args.add(status.toString().split('.').last);
    }
    if (triage != null) {
      where.add('triage_level = ?');
      args.add(triage.toString().split('.').last);
    }
    final rows = await db.query(
      'emergency_cases',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'created_at DESC',
    );
    return rows.map((r) {
      Map<String, dynamic>? vital;
      final vs = r['vital_signs'] as String?;
      if (vs != null) {
        try {
          vital = Map<String, dynamic>.from(jsonDecode(vs) as Map);
        } catch (_) {}
      }
      return EmergencyCaseModel.fromMap({
        'id': r['id'],
        'patientId': r['patient_id'],
        'patientName': r['patient_name'],
        'triage_level': r['triage_level'],
        'status': r['status'],
        'vitalSigns': vital,
        'symptoms': r['symptoms'],
        'notes': r['notes'],
        'createdAt': r['created_at'],
        'updatedAt': r['updated_at'],
      }, r['id'] as String);
    }).toList();
  }

  Future<void> createEmergencyCase(EmergencyCaseModel c) async {
    final db = await _db.database;
    await db.insert('emergency_cases', {
      'id': c.id,
      'patient_id': c.patientId,
      'patient_name': c.patientName,
      'triage_level': c.triageLevel.toString().split('.').last,
      'status': c.status.toString().split('.').last,
      'vital_signs': c.vitalSigns != null ? jsonEncode(c.vitalSigns) : null,
      'symptoms': c.symptoms,
      'notes': c.notes,
      'created_at': c.createdAt.millisecondsSinceEpoch,
      'updated_at': c.updatedAt?.millisecondsSinceEpoch,
    });
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
    final db = await _db.database;
    final updates = <String, Object?>{
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    if (patientId != null) updates['patient_id'] = patientId;
    if (patientName != null) updates['patient_name'] = patientName;
    if (triageLevel != null) updates['triage_level'] = triageLevel.toString().split('.').last;
    if (status != null) updates['status'] = status.toString().split('.').last;
    if (vitalSigns != null) updates['vital_signs'] = jsonEncode(vitalSigns);
    if (symptoms != null) updates['symptoms'] = symptoms;
    if (notes != null) updates['notes'] = notes;
    await db.update('emergency_cases', updates, where: 'id = ?', whereArgs: [caseId]);
  }

  Future<void> updateEmergencyStatus(String caseId, EmergencyStatus status) async {
    final db = await _db.database;
    await db.update(
      'emergency_cases',
      {
        'status': status.toString().split('.').last,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [caseId],
    );
  }

  Future<List<EmergencyEventModel>> getEmergencyEvents({String? caseId}) async {
    final db = await _db.database;
    final where = caseId != null ? 'case_id = ?' : null;
    final rows = await db.query(
      'emergency_events',
      where: where,
      whereArgs: where != null ? [caseId] : null,
      orderBy: 'created_at DESC',
    );
    return rows.map((r) {
      Map<String, dynamic>? details;
      final d = r['details'] as String?;
      if (d != null) {
        try {
          details = Map<String, dynamic>.from(jsonDecode(d) as Map);
        } catch (_) {}
      }
      return EmergencyEventModel.fromMap({
        'id': r['id'],
        'caseId': r['case_id'],
        'eventType': r['event_type'],
        'details': details,
        'createdAt': r['created_at'],
      }, r['id'] as String);
    }).toList();
  }

  Future<void> createEmergencyEvent(EmergencyEventModel e) async {
    final db = await _db.database;
    await db.insert('emergency_events', {
      'id': e.id,
      'case_id': e.caseId,
      'event_type': e.eventType,
      'details': e.details != null ? jsonEncode(e.details) : null,
      'created_at': e.createdAt.millisecondsSinceEpoch,
    });
  }

  // Notifications
  Future<List<NotificationModel>> getNotifications({NotificationStatus? status, String? relatedType, String? relatedId}) async {
    final db = await _db.database;
    final where = <String>[];
    final args = <Object>[];
    if (status != null) { where.add('status = ?'); args.add(status.toString().split('.').last); }
    if (relatedType != null) { where.add('related_type = ?'); args.add(relatedType); }
    if (relatedId != null) { where.add('related_id = ?'); args.add(relatedId); }
    final rows = await db.query(
      'notifications',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'scheduled_at ASC',
    );
    return rows.map((r) => NotificationModel.fromMap({
      'id': r['id'],
      'type': r['type'],
      'recipient': r['recipient'],
      'subject': r['subject'],
      'message': r['message'],
      'scheduledAt': r['scheduled_at'],
      'status': r['status'],
      'relatedType': r['related_type'],
      'relatedId': r['related_id'],
      'createdAt': r['created_at'],
      'sentAt': r['sent_at'],
      'error': r['error'],
    }, r['id'] as String)).toList();
  }

  Future<void> scheduleNotification(NotificationModel n) async {
    final db = await _db.database;
    await db.insert('notifications', {
      'id': n.id,
      'type': n.type.toString().split('.').last,
      'recipient': n.recipient,
      'subject': n.subject,
      'message': n.message,
      'scheduled_at': n.scheduledAt.millisecondsSinceEpoch,
      'status': n.status.toString().split('.').last,
      'related_type': n.relatedType,
      'related_id': n.relatedId,
      'created_at': n.createdAt.millisecondsSinceEpoch,
      'sent_at': n.sentAt?.millisecondsSinceEpoch,
      'error': n.error,
    });
  }

  Future<void> updateNotificationStatus(String id, NotificationStatus status, {String? error}) async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update('notifications', {
      'status': status.toString().split('.').last,
      'sent_at': status == NotificationStatus.sent ? now : null,
      'error': error,
    }, where: 'id = ?', whereArgs: [id]);
  }

  // Attendance & Shifts
  Future<List<AttendanceRecord>> getAttendance({String? userId, DateTime? from, DateTime? to}) async {
    final db = await _db.database;
    final where = <String>[];
    final args = <Object>[];
    if (userId != null) { where.add('user_id = ?'); args.add(userId); }
    if (from != null) { where.add('check_in >= ?'); args.add(from.millisecondsSinceEpoch); }
    if (to != null) { where.add('check_in <= ?'); args.add(to.millisecondsSinceEpoch); }
    final rows = await db.query(
      'attendance_records',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'check_in DESC',
    );
    return rows.map((r) => AttendanceRecord.fromMap({
      'id': r['id'],
      'userId': r['user_id'],
      'role': r['role'],
      'checkIn': r['check_in'],
      'checkOut': r['check_out'],
      'locationLat': r['location_lat'],
      'locationLng': r['location_lng'],
      'notes': r['notes'],
      'createdAt': r['created_at'],
    }, r['id'] as String)).toList();
  }

  Future<void> createAttendance(AttendanceRecord r) async {
    final db = await _db.database;
    await db.insert('attendance_records', {
      'id': r.id,
      'user_id': r.userId,
      'role': r.role,
      'check_in': r.checkIn.millisecondsSinceEpoch,
      'check_out': r.checkOut?.millisecondsSinceEpoch,
      'location_lat': r.locationLat,
      'location_lng': r.locationLng,
      'notes': r.notes,
      'created_at': r.createdAt.millisecondsSinceEpoch,
    });
  }

  Future<void> updateAttendance(String id, {DateTime? checkOut, double? locationLat, double? locationLng, String? notes}) async {
    final db = await _db.database;
    final updates = <String, Object?>{};
    if (checkOut != null) updates['check_out'] = checkOut.millisecondsSinceEpoch;
    if (locationLat != null) updates['location_lat'] = locationLat;
    if (locationLng != null) updates['location_lng'] = locationLng;
    if (notes != null) updates['notes'] = notes;
    if (updates.isEmpty) return;
    await db.update('attendance_records', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ShiftModel>> getShifts({String? userId}) async {
    final db = await _db.database;
    final rows = await db.query(
      'shifts',
      where: userId != null ? 'user_id = ?' : null,
      whereArgs: userId != null ? [userId] : null,
      orderBy: 'start_time DESC',
    );
    return rows.map((r) => ShiftModel.fromMap({
      'id': r['id'],
      'userId': r['user_id'],
      'role': r['role'],
      'startTime': r['start_time'],
      'endTime': r['end_time'],
      'department': r['department'],
      'recurrence': r['recurrence'],
      'createdAt': r['created_at'],
    }, r['id'] as String)).toList();
  }

  Future<void> createShift(ShiftModel s) async {
    final db = await _db.database;
    await db.insert('shifts', {
      'id': s.id,
      'user_id': s.userId,
      'role': s.role,
      'start_time': s.startTime.millisecondsSinceEpoch,
      'end_time': s.endTime.millisecondsSinceEpoch,
      'department': s.department,
      'recurrence': s.recurrence,
      'created_at': s.createdAt.millisecondsSinceEpoch,
    });
  }

  Future<void> updateShift(String id, {DateTime? startTime, DateTime? endTime, String? department, String? recurrence}) async {
    final db = await _db.database;
    final updates = <String, Object?>{};
    if (startTime != null) updates['start_time'] = startTime.millisecondsSinceEpoch;
    if (endTime != null) updates['end_time'] = endTime.millisecondsSinceEpoch;
    if (department != null) updates['department'] = department;
    if (recurrence != null) updates['recurrence'] = recurrence;
    if (updates.isEmpty) return;
    await db.update('shifts', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteShift(String id) async {
    final db = await _db.database;
    await db.delete('shifts', where: 'id = ?', whereArgs: [id]);
  }

  // File Upload (local)
  Future<String> uploadFile({
    required String filename,
    required List<int> bytes,
    String? contentType,
  }) async {
    // للويب: نعيد Data URL حتى تعمل المعاينة بدون dart:io
    final mime = contentType ?? 'application/octet-stream';
    final b64 = base64Encode(bytes);
    return 'data:$mime;base64,$b64';
  }

  // Surgeries
  Future<List<SurgeryModel>> getSurgeries({
    String? patientId,
    String? surgeonId,
    SurgeryStatus? status,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _db.database;
    final where = <String>[];
    final args = <Object>[];

    if (patientId != null) {
      where.add('patient_id = ?');
      args.add(patientId);
    }
    if (surgeonId != null) {
      where.add('surgeon_id = ?');
      args.add(surgeonId);
    }
    if (status != null) {
      where.add('status = ?');
      args.add(status.toString().split('.').last);
    }
    if (from != null) {
      where.add('scheduled_date >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('scheduled_date <= ?');
      args.add(to.millisecondsSinceEpoch);
    }

    final rows = await db.query(
      'surgeries',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'scheduled_date DESC',
    );

    return rows.map((r) {
      Map<String, dynamic>? preOp, op, postOp;
      List<String>? nurseIds, nurseNames, equipment;

      if (r['pre_operative_notes'] != null) {
        try {
          preOp = Map<String, dynamic>.from(jsonDecode(r['pre_operative_notes'] as String) as Map);
        } catch (_) {}
      }
      if (r['operative_notes'] != null) {
        try {
          op = Map<String, dynamic>.from(jsonDecode(r['operative_notes'] as String) as Map);
        } catch (_) {}
      }
      if (r['post_operative_notes'] != null) {
        try {
          postOp = Map<String, dynamic>.from(jsonDecode(r['post_operative_notes'] as String) as Map);
        } catch (_) {}
      }
      if (r['nurse_ids'] != null) {
        try {
          nurseIds = List<String>.from(jsonDecode(r['nurse_ids'] as String) as List);
        } catch (_) {}
      }
      if (r['nurse_names'] != null) {
        try {
          nurseNames = List<String>.from(jsonDecode(r['nurse_names'] as String) as List);
        } catch (_) {}
      }
      if (r['equipment'] != null) {
        try {
          equipment = List<String>.from(jsonDecode(r['equipment'] as String) as List);
        } catch (_) {}
      }

      return SurgeryModel.fromMap({
        'id': r['id'],
        'patient_id': r['patient_id'],
        'patient_name': r['patient_name'],
        'surgery_name': r['surgery_name'],
        'type': r['type'],
        'status': r['status'],
        'scheduled_date': r['scheduled_date'],
        'start_time': r['start_time'],
        'end_time': r['end_time'],
        'operation_room_id': r['operation_room_id'],
        'operation_room_name': r['operation_room_name'],
        'surgeon_id': r['surgeon_id'],
        'surgeon_name': r['surgeon_name'],
        'assistant_surgeon_id': r['assistant_surgeon_id'],
        'assistant_surgeon_name': r['assistant_surgeon_name'],
        'anesthesiologist_id': r['anesthesiologist_id'],
        'anesthesiologist_name': r['anesthesiologist_name'],
        'nurse_ids': nurseIds,
        'nurse_names': nurseNames,
        'pre_operative_notes': preOp,
        'operative_notes': op,
        'post_operative_notes': postOp,
        'diagnosis': r['diagnosis'],
        'procedure': r['procedure'],
        'notes': r['notes'],
        'equipment': equipment,
        'created_at': r['created_at'],
        'updated_at': r['updated_at'],
      }, r['id'] as String);
    }).toList();
  }

  Future<void> createSurgery(SurgeryModel surgery) async {
    final db = await _db.database;
    await db.insert('surgeries', {
      'id': surgery.id,
      'patient_id': surgery.patientId,
      'patient_name': surgery.patientName,
      'surgery_name': surgery.surgeryName,
      'type': surgery.type.toString().split('.').last,
      'status': surgery.status.toString().split('.').last,
      'scheduled_date': surgery.scheduledDate.millisecondsSinceEpoch,
      'start_time': surgery.startTime?.millisecondsSinceEpoch,
      'end_time': surgery.endTime?.millisecondsSinceEpoch,
      'operation_room_id': surgery.operationRoomId,
      'operation_room_name': surgery.operationRoomName,
      'surgeon_id': surgery.surgeonId,
      'surgeon_name': surgery.surgeonName,
      'assistant_surgeon_id': surgery.assistantSurgeonId,
      'assistant_surgeon_name': surgery.assistantSurgeonName,
      'anesthesiologist_id': surgery.anesthesiologistId,
      'anesthesiologist_name': surgery.anesthesiologistName,
      'nurse_ids': surgery.nurseIds != null ? jsonEncode(surgery.nurseIds) : null,
      'nurse_names': surgery.nurseNames != null ? jsonEncode(surgery.nurseNames) : null,
      'pre_operative_notes': surgery.preOperativeNotes != null ? jsonEncode(surgery.preOperativeNotes) : null,
      'operative_notes': surgery.operativeNotes != null ? jsonEncode(surgery.operativeNotes) : null,
      'post_operative_notes': surgery.postOperativeNotes != null ? jsonEncode(surgery.postOperativeNotes) : null,
      'diagnosis': surgery.diagnosis,
      'procedure': surgery.procedure,
      'notes': surgery.notes,
      'equipment': surgery.equipment != null ? jsonEncode(surgery.equipment) : null,
      'created_at': surgery.createdAt.millisecondsSinceEpoch,
      'updated_at': surgery.updatedAt?.millisecondsSinceEpoch,
    });
  }

  Future<void> updateSurgery(String surgeryId, {
    SurgeryStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    Map<String, dynamic>? preOperativeNotes,
    Map<String, dynamic>? operativeNotes,
    Map<String, dynamic>? postOperativeNotes,
  }) async {
    final db = await _db.database;
    final updates = <String, Object?>{
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };

    if (status != null) updates['status'] = status.toString().split('.').last;
    if (startTime != null) updates['start_time'] = startTime.millisecondsSinceEpoch;
    if (endTime != null) updates['end_time'] = endTime.millisecondsSinceEpoch;
    if (preOperativeNotes != null) updates['pre_operative_notes'] = jsonEncode(preOperativeNotes);
    if (operativeNotes != null) updates['operative_notes'] = jsonEncode(operativeNotes);
    if (postOperativeNotes != null) updates['post_operative_notes'] = jsonEncode(postOperativeNotes);

    await db.update('surgeries', updates, where: 'id = ?', whereArgs: [surgeryId]);
  }

  // Medical Inventory
  Future<List<MedicalInventoryItemModel>> getMedicalInventory({
    InventoryItemType? type,
    EquipmentStatus? status,
    String? category,
  }) async {
    final db = await _db.database;
    final where = <String>[];
    final args = <Object>[];

    if (type != null) {
      where.add('type = ?');
      args.add(type.toString().split('.').last);
    }
    if (status != null) {
      where.add('status = ?');
      args.add(status.toString().split('.').last);
    }
    if (category != null) {
      where.add('category = ?');
      args.add(category);
    }

    final rows = await db.query(
      'medical_inventory',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'name ASC',
    );

    return rows.map((r) => MedicalInventoryItemModel.fromMap({
      'id': r['id'],
      'name': r['name'],
      'type': r['type'],
      'category': r['category'],
      'description': r['description'],
      'quantity': r['quantity'],
      'minStockLevel': r['min_stock_level'],
      'unit': r['unit'],
      'unitPrice': r['unit_price'],
      'manufacturer': r['manufacturer'],
      'model': r['model'],
      'serialNumber': r['serial_number'],
      'purchaseDate': r['purchase_date'],
      'expiryDate': r['expiry_date'],
      'location': r['location'],
      'status': r['status'],
      'lastMaintenanceDate': r['last_maintenance_date'],
      'nextMaintenanceDate': r['next_maintenance_date'],
      'supplierId': r['supplier_id'],
      'supplierName': r['supplier_name'],
      'createdAt': r['created_at'],
      'updatedAt': r['updated_at'],
    }, r['id'] as String)).toList();
  }

  Future<void> createMedicalInventoryItem(MedicalInventoryItemModel item) async {
    final db = await _db.database;
    await db.insert('medical_inventory', {
      'id': item.id,
      'name': item.name,
      'type': item.type.toString().split('.').last,
      'category': item.category,
      'description': item.description,
      'quantity': item.quantity,
      'min_stock_level': item.minStockLevel,
      'unit': item.unit,
      'unit_price': item.unitPrice,
      'manufacturer': item.manufacturer,
      'model': item.model,
      'serial_number': item.serialNumber,
      'purchase_date': item.purchaseDate?.millisecondsSinceEpoch,
      'expiry_date': item.expiryDate?.millisecondsSinceEpoch,
      'location': item.location,
      'status': item.status?.toString().split('.').last,
      'last_maintenance_date': item.lastMaintenanceDate?.millisecondsSinceEpoch,
      'next_maintenance_date': item.nextMaintenanceDate?.millisecondsSinceEpoch,
      'supplier_id': item.supplierId,
      'supplier_name': item.supplierName,
      'created_at': item.createdAt.millisecondsSinceEpoch,
      'updated_at': item.updatedAt?.millisecondsSinceEpoch,
    });
  }

  Future<void> updateMedicalInventoryItem(String itemId, {
    int? quantity,
    EquipmentStatus? status,
    DateTime? nextMaintenanceDate,
  }) async {
    final db = await _db.database;
    final updates = <String, Object?>{
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };

    if (quantity != null) updates['quantity'] = quantity;
    if (status != null) updates['status'] = status.toString().split('.').last;
    if (nextMaintenanceDate != null) updates['next_maintenance_date'] = nextMaintenanceDate.millisecondsSinceEpoch;

    await db.update('medical_inventory', updates, where: 'id = ?', whereArgs: [itemId]);
  }

  // Suppliers
  Future<List<SupplierModel>> getSuppliers() async {
    final db = await _db.database;
    final rows = await db.query('suppliers', orderBy: 'name ASC');

    return rows.map((r) => SupplierModel.fromMap({
      'id': r['id'],
      'name': r['name'],
      'contactPerson': r['contact_person'],
      'email': r['email'],
      'phone': r['phone'],
      'address': r['address'],
      'notes': r['notes'],
      'createdAt': r['created_at'],
      'updatedAt': r['updated_at'],
    }, r['id'] as String)).toList();
  }

  Future<void> createSupplier(SupplierModel supplier) async {
    final db = await _db.database;
    await db.insert('suppliers', {
      'id': supplier.id,
      'name': supplier.name,
      'contact_person': supplier.contactPerson,
      'email': supplier.email,
      'phone': supplier.phone,
      'address': supplier.address,
      'notes': supplier.notes,
      'created_at': supplier.createdAt.millisecondsSinceEpoch,
      'updated_at': supplier.updatedAt?.millisecondsSinceEpoch,
    });
  }

  // Purchase Orders
  Future<List<PurchaseOrderModel>> getPurchaseOrders({PurchaseOrderStatus? status}) async {
    final db = await _db.database;
    final where = status != null ? 'status = ?' : null;
    final whereArgs = status != null ? [status.toString().split('.').last] : null;

    final rows = await db.query(
      'purchase_orders',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );

    return rows.map((r) {
      Map<String, dynamic>? itemsMap;
      if (r['items'] != null) {
        try {
          itemsMap = Map<String, dynamic>.from(jsonDecode(r['items'] as String) as Map);
        } catch (_) {}
      }

      return PurchaseOrderModel.fromMap({
        'id': r['id'],
        'orderNumber': r['order_number'],
        'supplierId': r['supplier_id'],
        'supplierName': r['supplier_name'],
        'items': itemsMap?['items'] ?? [],
        'totalAmount': r['total_amount'],
        'status': r['status'],
        'notes': r['notes'],
        'requestedBy': r['requested_by'],
        'requestedDate': r['requested_date'],
        'approvedBy': r['approved_by'],
        'approvedDate': r['approved_date'],
        'orderedDate': r['ordered_date'],
        'receivedDate': r['received_date'],
        'createdAt': r['created_at'],
        'updatedAt': r['updated_at'],
      }, r['id'] as String);
    }).toList();
  }

  Future<void> createPurchaseOrder(PurchaseOrderModel order) async {
    final db = await _db.database;
    await db.insert('purchase_orders', {
      'id': order.id,
      'order_number': order.orderNumber,
      'supplier_id': order.supplierId,
      'supplier_name': order.supplierName,
      'items': jsonEncode({'items': order.items.map((i) => i.toMap()).toList()}),
      'total_amount': order.totalAmount,
      'status': order.status.toString().split('.').last,
      'notes': order.notes,
      'requested_by': order.requestedBy,
      'requested_date': order.requestedDate?.millisecondsSinceEpoch,
      'approved_by': order.approvedBy,
      'approved_date': order.approvedDate?.millisecondsSinceEpoch,
      'ordered_date': order.orderedDate?.millisecondsSinceEpoch,
      'received_date': order.receivedDate?.millisecondsSinceEpoch,
      'created_at': order.createdAt.millisecondsSinceEpoch,
      'updated_at': order.updatedAt?.millisecondsSinceEpoch,
    });
  }

  // Maintenance Records
  Future<List<MaintenanceRecordModel>> getMaintenanceRecords({String? equipmentId}) async {
    final db = await _db.database;
    final where = equipmentId != null ? 'equipment_id = ?' : null;
    final whereArgs = equipmentId != null ? [equipmentId] : null;

    final rows = await db.query(
      'maintenance_records',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'maintenance_date DESC',
    );

    return rows.map((r) => MaintenanceRecordModel.fromMap({
      'id': r['id'],
      'equipmentId': r['equipment_id'],
      'equipmentName': r['equipment_name'],
      'maintenanceDate': r['maintenance_date'],
      'maintenanceType': r['maintenance_type'],
      'description': r['description'],
      'performedBy': r['performed_by'],
      'cost': r['cost'],
      'nextMaintenanceDate': r['next_maintenance_date'],
      'createdAt': r['created_at'],
    }, r['id'] as String)).toList();
  }

  Future<void> createMaintenanceRecord(MaintenanceRecordModel record) async {
    final db = await _db.database;
    await db.insert('maintenance_records', {
      'id': record.id,
      'equipment_id': record.equipmentId,
      'equipment_name': record.equipmentName,
      'maintenance_date': record.maintenanceDate.millisecondsSinceEpoch,
      'maintenance_type': record.maintenanceType,
      'description': record.description,
      'performed_by': record.performedBy,
      'cost': record.cost,
      'next_maintenance_date': record.nextMaintenanceDate?.millisecondsSinceEpoch,
      'created_at': record.createdAt.millisecondsSinceEpoch,
    });
  }

  // Hospital Pharmacy
  Future<List<HospitalPharmacyDispenseModel>> getHospitalPharmacyDispenses({
    String? patientId,
    MedicationDispenseStatus? status,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _db.database;
    final where = <String>[];
    final args = <Object>[];

    if (patientId != null) {
      where.add('patient_id = ?');
      args.add(patientId);
    }
    if (status != null) {
      where.add('status = ?');
      args.add(status.toString().split('.').last);
    }
    if (from != null) {
      where.add('scheduled_time >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('scheduled_time <= ?');
      args.add(to.millisecondsSinceEpoch);
    }

    final rows = await db.query(
      'hospital_pharmacy_dispenses',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'scheduled_time ASC',
    );

    return rows.map((r) => HospitalPharmacyDispenseModel.fromMap({
      'id': r['id'],
      'patientId': r['patient_id'],
      'patientName': r['patient_name'],
      'bedId': r['bed_id'],
      'roomId': r['room_id'],
      'prescriptionId': r['prescription_id'],
      'medicationId': r['medication_id'],
      'medicationName': r['medication_name'],
      'dosage': r['dosage'],
      'frequency': r['frequency'],
      'quantity': r['quantity'],
      'status': r['status'],
      'scheduleType': r['schedule_type'],
      'scheduledTime': r['scheduled_time'],
      'dispensedAt': r['dispensed_at'],
      'dispensedBy': r['dispensed_by'],
      'notes': r['notes'],
      'createdAt': r['created_at'],
      'updatedAt': r['updated_at'],
    }, r['id'] as String)).toList();
  }

  Future<void> createHospitalPharmacyDispense(HospitalPharmacyDispenseModel dispense) async {
    final db = await _db.database;
    await db.insert('hospital_pharmacy_dispenses', {
      'id': dispense.id,
      'patient_id': dispense.patientId,
      'patient_name': dispense.patientName,
      'bed_id': dispense.bedId,
      'room_id': dispense.roomId,
      'prescription_id': dispense.prescriptionId,
      'medication_id': dispense.medicationId,
      'medication_name': dispense.medicationName,
      'dosage': dispense.dosage,
      'frequency': dispense.frequency,
      'quantity': dispense.quantity,
      'status': dispense.status.toString().split('.').last,
      'schedule_type': dispense.scheduleType.toString().split('.').last,
      'scheduled_time': dispense.scheduledTime.millisecondsSinceEpoch,
      'dispensed_at': dispense.dispensedAt?.millisecondsSinceEpoch,
      'dispensed_by': dispense.dispensedBy,
      'notes': dispense.notes,
      'created_at': dispense.createdAt.millisecondsSinceEpoch,
      'updated_at': dispense.updatedAt?.millisecondsSinceEpoch,
    });
  }

  Future<void> updateDispenseStatus(String id, MedicationDispenseStatus status, {String? dispensedBy}) async {
    final db = await _db.database;
    final updates = <String, Object?>{
      'status': status.toString().split('.').last,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };

    if (status == MedicationDispenseStatus.dispensed) {
      updates['dispensed_at'] = DateTime.now().millisecondsSinceEpoch;
      if (dispensedBy != null) updates['dispensed_by'] = dispensedBy;
    }

    await db.update('hospital_pharmacy_dispenses', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<MedicationScheduleModel>> getMedicationSchedules({
    String? patientId,
    bool? isActive,
  }) async {
    final db = await _db.database;
    final where = <String>[];
    final args = <Object>[];

    if (patientId != null) {
      where.add('patient_id = ?');
      args.add(patientId);
    }
    if (isActive != null) {
      where.add('is_active = ?');
      args.add(isActive ? 1 : 0);
    }

    final rows = await db.query(
      'medication_schedules',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'start_date DESC',
    );

    return rows.map((r) {
      List<DateTime> scheduledTimes = [];
      if (r['scheduled_times'] != null) {
        try {
          final decoded = jsonDecode(r['scheduled_times'] as String) as List;
          scheduledTimes = decoded.map((t) {
            if (t is int) return DateTime.fromMillisecondsSinceEpoch(t);
            return DateTime.now();
          }).toList();
        } catch (_) {}
      }

      return MedicationScheduleModel.fromMap({
        'id': r['id'],
        'patientId': r['patient_id'],
        'patientName': r['patient_name'],
        'bedId': r['bed_id'],
        'roomId': r['room_id'],
        'prescriptionId': r['prescription_id'],
        'medicationId': r['medication_id'],
        'medicationName': r['medication_name'],
        'dosage': r['dosage'],
        'frequency': r['frequency'],
        'quantity': r['quantity'],
        'scheduleType': r['schedule_type'],
        'startDate': r['start_date'],
        'endDate': r['end_date'],
        'scheduledTimes': scheduledTimes,
        'isActive': (r['is_active'] as int?) == 1,
        'notes': r['notes'],
        'createdAt': r['created_at'],
        'updatedAt': r['updated_at'],
      }, r['id'] as String);
    }).toList();
  }

  Future<void> createMedicationSchedule(MedicationScheduleModel schedule) async {
    final db = await _db.database;
    await db.insert('medication_schedules', {
      'id': schedule.id,
      'patient_id': schedule.patientId,
      'patient_name': schedule.patientName,
      'bed_id': schedule.bedId,
      'room_id': schedule.roomId,
      'prescription_id': schedule.prescriptionId,
      'medication_id': schedule.medicationId,
      'medication_name': schedule.medicationName,
      'dosage': schedule.dosage,
      'frequency': schedule.frequency,
      'quantity': schedule.quantity,
      'schedule_type': schedule.scheduleType.toString().split('.').last,
      'start_date': schedule.startDate.millisecondsSinceEpoch,
      'end_date': schedule.endDate?.millisecondsSinceEpoch,
      'scheduled_times': jsonEncode(schedule.scheduledTimes.map((t) => t.millisecondsSinceEpoch).toList()),
      'is_active': schedule.isActive ? 1 : 0,
      'notes': schedule.notes,
      'created_at': schedule.createdAt.millisecondsSinceEpoch,
      'updated_at': schedule.updatedAt?.millisecondsSinceEpoch,
    });
  }

  // Lab Test Types
  Future<List<LabTestTypeModel>> getLabTestTypes({
    LabTestCategory? category,
    bool? isActive,
  }) async {
    final db = await _db.database;
    final where = <String>[];
    final args = <Object>[];

    if (category != null) {
      where.add('category = ?');
      args.add(category.toString().split('.').last);
    }
    if (isActive != null) {
      where.add('is_active = ?');
      args.add(isActive ? 1 : 0);
    }

    final rows = await db.query(
      'lab_test_types',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'name ASC',
    );

    return rows.map((r) => LabTestTypeModel.fromMap({
      'id': r['id'],
      'name': r['name'],
      'arabicName': r['arabic_name'],
      'category': r['category'],
      'description': r['description'],
      'price': r['price'],
      'estimatedDurationMinutes': r['estimated_duration_minutes'],
      'defaultPriority': r['default_priority'],
      'requiredSamples': r['required_samples'],
      'normalRanges': r['normal_ranges'],
      'criticalValues': r['critical_values'],
      'isActive': (r['is_active'] as int?) == 1,
      'createdAt': r['created_at'],
      'updatedAt': r['updated_at'],
    }, r['id'] as String)).toList();
  }

  Future<void> createLabTestType(LabTestTypeModel testType) async {
    final db = await _db.database;
    await db.insert('lab_test_types', {
      'id': testType.id,
      'name': testType.name,
      'arabic_name': testType.arabicName,
      'category': testType.category.toString().split('.').last,
      'description': testType.description,
      'price': testType.price,
      'estimated_duration_minutes': testType.estimatedDurationMinutes,
      'default_priority': testType.defaultPriority.toString().split('.').last,
      'required_samples': testType.requiredSamples != null ? jsonEncode(testType.requiredSamples) : null,
      'normal_ranges': testType.normalRanges != null ? jsonEncode(testType.normalRanges) : null,
      'critical_values': testType.criticalValues != null ? jsonEncode(testType.criticalValues) : null,
      'is_active': testType.isActive ? 1 : 0,
      'created_at': testType.createdAt.millisecondsSinceEpoch,
      'updated_at': testType.updatedAt?.millisecondsSinceEpoch,
    });
  }

  // Lab Samples
  Future<List<LabSampleModel>> getLabSamples({String? labRequestId}) async {
    final db = await _db.database;
    final where = labRequestId != null ? 'lab_request_id = ?' : null;
    final whereArgs = labRequestId != null ? [labRequestId] : null;

    final rows = await db.query(
      'lab_samples',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );

    return rows.map((r) => LabSampleModel.fromMap({
      'id': r['id'],
      'labRequestId': r['lab_request_id'],
      'type': r['type'],
      'status': r['status'],
      'collectionLocation': r['collection_location'],
      'collectedAt': r['collected_at'],
      'collectedBy': r['collected_by'],
      'receivedAt': r['received_at'],
      'receivedBy': r['received_by'],
      'notes': r['notes'],
      'createdAt': r['created_at'],
      'updatedAt': r['updated_at'],
    }, r['id'] as String)).toList();
  }

  Future<void> createLabSample(LabSampleModel sample) async {
    final db = await _db.database;
    await db.insert('lab_samples', {
      'id': sample.id,
      'lab_request_id': sample.labRequestId,
      'type': sample.type.toString().split('.').last,
      'status': sample.status.toString().split('.').last,
      'collection_location': sample.collectionLocation,
      'collected_at': sample.collectedAt?.millisecondsSinceEpoch,
      'collected_by': sample.collectedBy,
      'received_at': sample.receivedAt?.millisecondsSinceEpoch,
      'received_by': sample.receivedBy,
      'notes': sample.notes,
      'created_at': sample.createdAt.millisecondsSinceEpoch,
      'updated_at': sample.updatedAt?.millisecondsSinceEpoch,
    });
  }

  Future<void> updateLabSampleStatus(String id, LabSampleStatus status, {String? receivedBy}) async {
    final db = await _db.database;
    final updates = <String, Object?>{
      'status': status.toString().split('.').last,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };

    if (status == LabSampleStatus.received) {
      updates['received_at'] = DateTime.now().millisecondsSinceEpoch;
      if (receivedBy != null) updates['received_by'] = receivedBy;
    }

    await db.update('lab_samples', updates, where: 'id = ?', whereArgs: [id]);
  }

  // Lab Results
  Future<LabResultModel?> getLabResult(String labRequestId) async {
    final db = await _db.database;
    final rows = await db.query(
      'lab_results',
      where: 'lab_request_id = ?',
      whereArgs: [labRequestId],
    );

    if (rows.isEmpty) return null;

    final r = rows.first;
    return LabResultModel.fromMap({
      'id': r['id'],
      'labRequestId': r['lab_request_id'],
      'results': r['results'],
      'interpretation': r['interpretation'],
      'isCritical': (r['is_critical'] as int?) == 1,
      'reviewedBy': r['reviewed_by'],
      'reviewedAt': r['reviewed_at'],
      'createdAt': r['created_at'],
      'updatedAt': r['updated_at'],
    }, r['id'] as String);
  }

  Future<void> createLabResult(LabResultModel result) async {
    final db = await _db.database;
    await db.insert('lab_results', {
      'id': result.id,
      'lab_request_id': result.labRequestId,
      'results': jsonEncode(result.results),
      'interpretation': result.interpretation,
      'is_critical': result.isCritical ? 1 : 0,
      'reviewed_by': result.reviewedBy,
      'reviewed_at': result.reviewedAt?.millisecondsSinceEpoch,
      'created_at': result.createdAt.millisecondsSinceEpoch,
      'updated_at': result.updatedAt?.millisecondsSinceEpoch,
    });
  }

  Future<void> updateLabResult(String id, {Map<String, dynamic>? results, String? interpretation, bool? isCritical}) async {
    final db = await _db.database;
    final updates = <String, Object?>{
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };

    if (results != null) updates['results'] = jsonEncode(results);
    if (interpretation != null) updates['interpretation'] = interpretation;
    if (isCritical != null) updates['is_critical'] = isCritical ? 1 : 0;

    await db.update('lab_results', updates, where: 'id = ?', whereArgs: [id]);
  }

  // Lab Schedules
  Future<List<Map<String, dynamic>>> getLabSchedules({
    DateTime? from,
    DateTime? to,
    LabTestPriority? priority,
  }) async {
    final db = await _db.database;
    final where = <String>[];
    final args = <Object>[];

    if (from != null) {
      where.add('scheduled_date >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('scheduled_date <= ?');
      args.add(to.millisecondsSinceEpoch);
    }
    if (priority != null) {
      where.add('priority = ?');
      args.add(priority.toString().split('.').last);
    }

    final rows = await db.query(
      'lab_schedules',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'scheduled_date ASC, scheduled_time ASC',
    );

    return rows.map((r) => {
      'id': r['id'],
      'labRequestId': r['lab_request_id'],
      'scheduledDate': r['scheduled_date'],
      'scheduledTime': r['scheduled_time'],
      'priority': r['priority'],
      'notes': r['notes'],
      'createdAt': r['created_at'],
      'updatedAt': r['updated_at'],
    }).toList();
  }

  Future<void> createLabSchedule(Map<String, dynamic> schedule) async {
    final db = await _db.database;
    await db.insert('lab_schedules', {
      'id': schedule['id'],
      'lab_request_id': schedule['labRequestId'],
      'scheduled_date': schedule['scheduledDate'],
      'scheduled_time': schedule['scheduledTime'],
      'priority': schedule['priority'],
      'notes': schedule['notes'],
      'created_at': schedule['createdAt'],
      'updated_at': schedule['updatedAt'],
    });
  }

  // Documents
  Future<List<DocumentModel>> getDocuments({
    DocumentCategory? category,
    DocumentStatus? status,
    DocumentAccessLevel? accessLevel,
    String? patientId,
    String? doctorId,
    String? searchQuery,
    String? userId,
  }) async {
    final db = await _db.database;
    final where = <String>[];
    final args = <Object>[];

    if (category != null) {
      where.add('category = ?');
      args.add(category.toString().split('.').last);
    }
    if (status != null) {
      where.add('status = ?');
      args.add(status.toString().split('.').last);
    }
    if (accessLevel != null) {
      where.add('accessLevel = ?');
      args.add(accessLevel.toString().split('.').last);
    }
    if (patientId != null) {
      where.add('patient_id = ?');
      args.add(patientId);
    }
    if (doctorId != null) {
      where.add('doctor_id = ?');
      args.add(doctorId);
    }
    if (userId != null) {
      where.add('(created_by = ? OR shared_with_user_ids LIKE ?)');
      args.add(userId);
      args.add('%$userId%');
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      where.add('(title LIKE ? OR description LIKE ? OR tags LIKE ?)');
      final query = '%$searchQuery%';
      args.add(query);
      args.add(query);
      args.add(query);
    }

    final rows = await db.query(
      'documents',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'created_at DESC',
    );

    return rows.map((r) => DocumentModel.fromMap({
      'id': r['id'],
      'title': r['title'],
      'description': r['description'],
      'category': r['category'],
      'status': r['status'],
      'accessLevel': r['accessLevel'],
      'patientId': r['patient_id'],
      'patientName': r['patient_name'],
      'doctorId': r['doctor_id'],
      'doctorName': r['doctor_name'],
      'sharedWithUserIds': r['shared_with_user_ids'],
      'tags': r['tags'],
      'fileUrl': r['file_url'],
      'fileName': r['file_name'],
      'fileType': r['file_type'],
      'fileSize': r['file_size'],
      'thumbnailUrl': r['thumbnail_url'],
      'metadata': r['metadata'],
      'signatureId': r['signature_id'],
      'signedAt': r['signed_at'],
      'signedBy': r['signed_by'],
      'archivedAt': r['archived_at'],
      'archivedBy': r['archived_by'],
      'createdAt': r['created_at'],
      'updatedAt': r['updated_at'],
      'createdBy': r['created_by'],
    }, r['id'] as String)).toList();
  }

  Future<DocumentModel?> getDocument(String id) async {
    final db = await _db.database;
    final rows = await db.query(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final r = rows.first;
    return DocumentModel.fromMap({
      'id': r['id'],
      'title': r['title'],
      'description': r['description'],
      'category': r['category'],
      'status': r['status'],
      'accessLevel': r['accessLevel'],
      'patientId': r['patient_id'],
      'patientName': r['patient_name'],
      'doctorId': r['doctor_id'],
      'doctorName': r['doctor_name'],
      'sharedWithUserIds': r['shared_with_user_ids'],
      'tags': r['tags'],
      'fileUrl': r['file_url'],
      'fileName': r['file_name'],
      'fileType': r['file_type'],
      'fileSize': r['file_size'],
      'thumbnailUrl': r['thumbnail_url'],
      'metadata': r['metadata'],
      'signatureId': r['signature_id'],
      'signedAt': r['signed_at'],
      'signedBy': r['signed_by'],
      'archivedAt': r['archived_at'],
      'archivedBy': r['archived_by'],
      'createdAt': r['created_at'],
      'updatedAt': r['updated_at'],
      'createdBy': r['created_by'],
    }, r['id'] as String);
  }

  Future<void> createDocument(DocumentModel document) async {
    final db = await _db.database;
    await db.insert('documents', {
      'id': document.id,
      'title': document.title,
      'description': document.description,
      'category': document.category.toString().split('.').last,
      'status': document.status.toString().split('.').last,
      'accessLevel': document.accessLevel.toString().split('.').last,
      'patient_id': document.patientId,
      'patient_name': document.patientName,
      'doctor_id': document.doctorId,
      'doctor_name': document.doctorName,
      'shared_with_user_ids': document.sharedWithUserIds != null ? jsonEncode(document.sharedWithUserIds) : null,
      'tags': document.tags != null ? jsonEncode(document.tags) : null,
      'file_url': document.fileUrl,
      'file_name': document.fileName,
      'file_type': document.fileType,
      'file_size': document.fileSize,
      'thumbnail_url': document.thumbnailUrl,
      'metadata': document.metadata != null ? jsonEncode(document.metadata) : null,
      'signature_id': document.signatureId,
      'signed_at': document.signedAt?.millisecondsSinceEpoch,
      'signed_by': document.signedBy,
      'archived_at': document.archivedAt?.millisecondsSinceEpoch,
      'archived_by': document.archivedBy,
      'created_at': document.createdAt.millisecondsSinceEpoch,
      'updated_at': document.updatedAt?.millisecondsSinceEpoch,
      'created_by': document.createdBy,
    });
  }

  Future<void> updateDocument(String id, {
    String? title,
    String? description,
    DocumentCategory? category,
    DocumentStatus? status,
    DocumentAccessLevel? accessLevel,
    List<String>? sharedWithUserIds,
    List<String>? tags,
    String? signatureId,
    DateTime? signedAt,
    String? signedBy,
    DateTime? archivedAt,
    String? archivedBy,
  }) async {
    final db = await _db.database;
    final updates = <String, Object?>{
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };

    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (category != null) updates['category'] = category.toString().split('.').last;
    if (status != null) updates['status'] = status.toString().split('.').last;
    if (accessLevel != null) updates['accessLevel'] = accessLevel.toString().split('.').last;
    if (sharedWithUserIds != null) updates['shared_with_user_ids'] = jsonEncode(sharedWithUserIds);
    if (tags != null) updates['tags'] = jsonEncode(tags);
    if (signatureId != null) updates['signature_id'] = signatureId;
    if (signedAt != null) updates['signed_at'] = signedAt.millisecondsSinceEpoch;
    if (signedBy != null) updates['signed_by'] = signedBy;
    if (archivedAt != null) updates['archived_at'] = archivedAt.millisecondsSinceEpoch;
    if (archivedBy != null) updates['archived_by'] = archivedBy;

    await db.update('documents', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteDocument(String id) async {
    final db = await _db.database;
    await db.update(
      'documents',
      {'status': DocumentStatus.deleted.toString().split('.').last},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> createDocumentSignature(DocumentSignature signature) async {
    final db = await _db.database;
    await db.insert('document_signatures', {
      'id': signature.id,
      'document_id': signature.documentId,
      'signed_by': signature.signedBy,
      'signed_by_name': signature.signedByName,
      'signature_data': signature.signatureData,
      'signed_at': signature.signedAt.millisecondsSinceEpoch,
      'notes': signature.notes,
    });
  }

  Future<DocumentSignature?> getDocumentSignature(String documentId) async {
    final db = await _db.database;
    final rows = await db.query(
      'document_signatures',
      where: 'document_id = ?',
      whereArgs: [documentId],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final r = rows.first;
      return DocumentSignature.fromMap({
        'id': r['id'],
        'documentId': r['document_id'],
        'signedBy': r['signed_by'],
        'signedByName': r['signed_by_name'],
        'signatureData': r['signature_data'],
        'signedAt': r['signed_at'],
        'notes': r['notes'],
      }, r['id'] as String);
    }

  // Quality Management - KPIs
  Future<List<KPIModel>> getKPIs({KPICategory? category}) async {
    final db = await _db.database;
    final where = category != null ? 'category = ?' : null;
    final whereArgs = category != null ? [category.toString().split('.').last] : null;

    final rows = await db.query(
      'quality_kpis',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );

    return rows.map((r) => KPIModel.fromMap({
      'id': r['id'],
      'name': r['name'],
      'arabicName': r['arabic_name'],
      'description': r['description'],
      'category': r['category'],
      'type': r['type'],
      'targetValue': r['target_value'],
      'currentValue': r['current_value'],
      'unit': r['unit'],
      'lastUpdated': r['last_updated'],
      'updatedBy': r['updated_by'],
      'metadata': r['metadata'],
      'createdAt': r['created_at'],
      'updatedAt': r['updated_at'],
    }, r['id'] as String)).toList();
  }

  Future<KPIModel?> getKPI(String id) async {
    final db = await _db.database;
    final rows = await db.query(
      'quality_kpis',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final r = rows.first;
    return KPIModel.fromMap({
      'id': r['id'],
      'name': r['name'],
      'arabicName': r['arabic_name'],
      'description': r['description'],
      'category': r['category'],
      'type': r['type'],
      'targetValue': r['target_value'],
      'currentValue': r['current_value'],
      'unit': r['unit'],
      'lastUpdated': r['last_updated'],
      'updatedBy': r['updated_by'],
      'metadata': r['metadata'],
      'createdAt': r['created_at'],
      'updatedAt': r['updated_at'],
    }, r['id'] as String);
  }

  Future<void> createKPI(KPIModel kpi) async {
    final db = await _db.database;
    await db.insert('quality_kpis', {
      'id': kpi.id,
      'name': kpi.name,
      'arabic_name': kpi.arabicName,
      'description': kpi.description,
      'category': kpi.category.toString().split('.').last,
      'type': kpi.type.toString().split('.').last,
      'target_value': kpi.targetValue,
      'current_value': kpi.currentValue,
      'unit': kpi.unit,
      'last_updated': kpi.lastUpdated?.millisecondsSinceEpoch,
      'updated_by': kpi.updatedBy,
      'metadata': kpi.metadata != null ? jsonEncode(kpi.metadata) : null,
      'created_at': kpi.createdAt.millisecondsSinceEpoch,
      'updated_at': kpi.updatedAt?.millisecondsSinceEpoch,
    });
  }

  Future<void> updateKPI(String id, {
    double? currentValue,
    DateTime? lastUpdated,
    String? updatedBy,
  }) async {
    final db = await _db.database;
    final updates = <String, Object?>{
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };

    if (currentValue != null) updates['current_value'] = currentValue;
    if (lastUpdated != null) updates['last_updated'] = lastUpdated.millisecondsSinceEpoch;
    if (updatedBy != null) updates['updated_by'] = updatedBy;

    await db.update('quality_kpis', updates, where: 'id = ?', whereArgs: [id]);
  }

  // Medical Incidents
  Future<List<MedicalIncidentModel>> getMedicalIncidents() async {
    final db = await _db.database;
    final rows = await db.query(
      'medical_incidents',
      orderBy: 'incident_date DESC',
    );

    return rows.map((r) => MedicalIncidentModel.fromMap({
      'id': r['id'],
      'patientId': r['patient_id'],
      'patientName': r['patient_name'],
      'type': r['type'],
      'severity': r['severity'],
      'status': r['status'],
      'description': r['description'],
      'location': r['location'],
      'incidentDate': r['incident_date'],
      'reportedDate': r['reported_date'],
      'reportedBy': r['reported_by'],
      'reportedByName': r['reported_by_name'],
      'investigationNotes': r['investigation_notes'],
      'resolutionNotes': r['resolution_notes'],
      'resolvedBy': r['resolved_by'],
      'resolvedAt': r['resolved_at'],
      'affectedPersons': r['affected_persons'],
      'additionalData': r['additional_data'],
      'createdAt': r['created_at'],
      'updatedAt': r['updated_at'],
    }, r['id'] as String)).toList();
  }

  Future<void> createMedicalIncident(MedicalIncidentModel incident) async {
    final db = await _db.database;
    await db.insert('medical_incidents', {
      'id': incident.id,
      'patient_id': incident.patientId,
      'patient_name': incident.patientName,
      'type': incident.type.toString().split('.').last,
      'severity': incident.severity.toString().split('.').last,
      'status': incident.status.toString().split('.').last,
      'description': incident.description,
      'location': incident.location,
      'incident_date': incident.incidentDate.millisecondsSinceEpoch,
      'reported_date': incident.reportedDate?.millisecondsSinceEpoch,
      'reported_by': incident.reportedBy,
      'reported_by_name': incident.reportedByName,
      'investigation_notes': incident.investigationNotes,
      'resolution_notes': incident.resolutionNotes,
      'resolved_by': incident.resolvedBy,
      'resolved_at': incident.resolvedAt?.millisecondsSinceEpoch,
      'affected_persons': incident.affectedPersons != null ? jsonEncode(incident.affectedPersons) : null,
      'additional_data': incident.additionalData != null ? jsonEncode(incident.additionalData) : null,
      'created_at': incident.createdAt.millisecondsSinceEpoch,
      'updated_at': incident.updatedAt?.millisecondsSinceEpoch,
    });
  }

  // Complaints
  Future<List<ComplaintModel>> getComplaints() async {
    final db = await _db.database;
    final rows = await db.query(
      'complaints',
      orderBy: 'complaint_date DESC',
    );

    return rows.map((r) => ComplaintModel.fromMap({
      'id': r['id'],
      'patientId': r['patient_id'],
      'patientName': r['patient_name'],
      'complainantName': r['complainant_name'],
      'complainantPhone': r['complainant_phone'],
      'complainantEmail': r['complainant_email'],
      'category': r['category'],
      'status': r['status'],
      'subject': r['subject'],
      'description': r['description'],
      'department': r['department'],
      'assignedTo': r['assigned_to'],
      'assignedToName': r['assigned_to_name'],
      'response': r['response'],
      'respondedBy': r['responded_by'],
      'respondedAt': r['responded_at'],
      'complaintDate': r['complaint_date'],
      'resolvedAt': r['resolved_at'],
      'additionalData': r['additional_data'],
      'createdAt': r['created_at'],
      'updatedAt': r['updated_at'],
    }, r['id'] as String)).toList();
  }

  // Accreditation Requirements
  Future<List<AccreditationRequirementModel>> getAccreditationRequirements() async {
    final db = await _db.database;
    final rows = await db.query(
      'accreditation_requirements',
      orderBy: 'created_at DESC',
    );

      return rows.map((r) => AccreditationRequirementModel.fromMap({
      'id': r['id'],
      'standard': r['standard'],
      'requirementCode': r['requirement_code'],
      'title': r['title'],
      'description': r['description'],
      'status': r['status'],
      'evidence': r['evidence'],
      'notes': r['notes'],
      'complianceDate': r['compliance_date'],
      'certificationDate': r['certification_date'],
      'assignedTo': r['assigned_to'],
      'assignedToName': r['assigned_to_name'],
      'dueDate': r['due_date'],
      'metadata': r['metadata'],
      'createdAt': r['created_at'],
      'updatedAt': r['updated_at'],
    }, r['id'] as String)).toList();
  }

  // HR Management - Employees
  Future<List<EmployeeModel>> getEmployees({EmploymentStatus? status}) async {
    final db = await _db.database;
    final where = status != null ? 'status = ?' : null;
    final whereArgs = status != null ? [status.toString().split('.').last] : null;

    final rows = await db.query(
      'employees',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'hire_date DESC',
    );

    return rows.map((r) => EmployeeModel.fromMap({
      'id': r['id'],
      'userId': r['user_id'],
      'employeeNumber': r['employee_number'],
      'department': r['department'],
      'position': r['position'],
      'employmentType': r['employment_type'],
      'status': r['status'],
      'hireDate': r['hire_date'],
      'terminationDate': r['termination_date'],
      'salary': r['salary'],
      'managerId': r['manager_id'],
      'managerName': r['manager_name'],
      'additionalInfo': r['additional_info'],
      'createdAt': r['created_at'],
      'updatedAt': r['updated_at'],
    }, r['id'] as String)).toList();
  }

  Future<EmployeeModel?> getEmployee(String id) async {
    final db = await _db.database;
    final rows = await db.query(
      'employees',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final r = rows.first;
    return EmployeeModel.fromMap({
      'id': r['id'],
      'userId': r['user_id'],
      'employeeNumber': r['employee_number'],
      'department': r['department'],
      'position': r['position'],
      'employmentType': r['employment_type'],
      'status': r['status'],
      'hireDate': r['hire_date'],
      'terminationDate': r['termination_date'],
      'salary': r['salary'],
      'managerId': r['manager_id'],
      'managerName': r['manager_name'],
      'additionalInfo': r['additional_info'],
      'createdAt': r['created_at'],
      'updatedAt': r['updated_at'],
    }, r['id'] as String);
  }

  Future<void> createEmployee(EmployeeModel employee) async {
    final db = await _db.database;
    await db.insert('employees', {
      'id': employee.id,
      'user_id': employee.userId,
      'employee_number': employee.employeeNumber,
      'department': employee.department,
      'position': employee.position,
      'employment_type': employee.employmentType.toString().split('.').last,
      'status': employee.status.toString().split('.').last,
      'hire_date': employee.hireDate.millisecondsSinceEpoch,
      'termination_date': employee.terminationDate?.millisecondsSinceEpoch,
      'salary': employee.salary,
      'manager_id': employee.managerId,
      'manager_name': employee.managerName,
      'additional_info': employee.additionalInfo != null ? jsonEncode(employee.additionalInfo) : null,
      'created_at': employee.createdAt.millisecondsSinceEpoch,
      'updated_at': employee.updatedAt?.millisecondsSinceEpoch,
    });
  }

  // Leave Requests
  Future<List<LeaveRequestModel>> getLeaveRequests({LeaveStatus? status}) async {
    final db = await _db.database;
    final where = status != null ? 'status = ?' : null;
    final whereArgs = status != null ? [status.toString().split('.').last] : null;

    final rows = await db.query(
      'leave_requests',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'start_date DESC',
    );

    return rows.map((r) => LeaveRequestModel.fromMap({
      'id': r['id'],
      'employeeId': r['employee_id'],
      'employeeName': r['employee_name'],
      'type': r['type'],
      'status': r['status'],
      'startDate': r['start_date'],
      'endDate': r['end_date'],
      'days': r['days'],
      'reason': r['reason'],
      'notes': r['notes'],
      'approvedBy': r['approved_by'],
      'approvedByName': r['approved_by_name'],
      'approvedAt': r['approved_at'],
      'rejectionReason': r['rejection_reason'],
      'createdAt': r['created_at'],
      'updatedAt': r['updated_at'],
    }, r['id'] as String)).toList();
  }

  Future<void> createLeaveRequest(LeaveRequestModel leave) async {
    final db = await _db.database;
    await db.insert('leave_requests', {
      'id': leave.id,
      'employee_id': leave.employeeId,
      'employee_name': leave.employeeName,
      'type': leave.type.toString().split('.').last,
      'status': leave.status.toString().split('.').last,
      'start_date': leave.startDate.millisecondsSinceEpoch,
      'end_date': leave.endDate.millisecondsSinceEpoch,
      'days': leave.days,
      'reason': leave.reason,
      'notes': leave.notes,
      'approved_by': leave.approvedBy,
      'approved_by_name': leave.approvedByName,
      'approved_at': leave.approvedAt?.millisecondsSinceEpoch,
      'rejection_reason': leave.rejectionReason,
      'created_at': leave.createdAt.millisecondsSinceEpoch,
      'updated_at': leave.updatedAt?.millisecondsSinceEpoch,
    });
  }

  // Payroll
  Future<List<PayrollModel>> getPayrolls({PayrollStatus? status}) async {
    final db = await _db.database;
    final where = status != null ? 'status = ?' : null;
    final whereArgs = status != null ? [status.toString().split('.').last] : null;

    final rows = await db.query(
      'payrolls',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'pay_period_start DESC',
    );

    return rows.map((r) => PayrollModel.fromMap({
      'id': r['id'],
      'employeeId': r['employee_id'],
      'employeeName': r['employee_name'],
      'payPeriodStart': r['pay_period_start'],
      'payPeriodEnd': r['pay_period_end'],
      'baseSalary': r['base_salary'],
      'allowances': r['allowances'],
      'deductions': r['deductions'],
      'bonuses': r['bonuses'],
      'overtime': r['overtime'],
      'netSalary': r['net_salary'],
      'status': r['status'],
      'paidDate': r['paid_date'],
      'notes': r['notes'],
      'createdAt': r['created_at'],
      'updatedAt': r['updated_at'],
    }, r['id'] as String)).toList();
  }

  Future<void> createPayroll(PayrollModel payroll) async {
    final db = await _db.database;
    await db.insert('payrolls', {
      'id': payroll.id,
      'employee_id': payroll.employeeId,
      'employee_name': payroll.employeeName,
      'pay_period_start': payroll.payPeriodStart.millisecondsSinceEpoch,
      'pay_period_end': payroll.payPeriodEnd.millisecondsSinceEpoch,
      'base_salary': payroll.baseSalary,
      'allowances': payroll.allowances,
      'deductions': payroll.deductions,
      'bonuses': payroll.bonuses,
      'overtime': payroll.overtime,
      'net_salary': payroll.netSalary,
      'status': payroll.status.toString().split('.').last,
      'paid_date': payroll.paidDate?.millisecondsSinceEpoch,
      'notes': payroll.notes,
      'created_at': payroll.createdAt.millisecondsSinceEpoch,
      'updated_at': payroll.updatedAt?.millisecondsSinceEpoch,
    });
  }

  // Training
  Future<List<TrainingModel>> getTrainings() async {
    final db = await _db.database;
    final rows = await db.query(
      'trainings',
      orderBy: 'start_date DESC',
    );

    return rows.map((r) => TrainingModel.fromMap({
      'id': r['id'],
      'title': r['title'],
      'description': r['description'],
      'trainer': r['trainer'],
      'location': r['location'],
      'startDate': r['start_date'],
      'endDate': r['end_date'],
      'maxParticipants': r['max_participants'],
      'participantIds': r['participant_ids'],
      'status': r['status'],
      'notes': r['notes'],
      'createdAt': r['created_at'],
      'updatedAt': r['updated_at'],
    }, r['id'] as String)).toList();
  }

  Future<void> createTraining(TrainingModel training) async {
    final db = await _db.database;
    await db.insert('trainings', {
      'id': training.id,
      'title': training.title,
      'description': training.description,
      'trainer': training.trainer,
      'location': training.location,
      'start_date': training.startDate.millisecondsSinceEpoch,
      'end_date': training.endDate.millisecondsSinceEpoch,
      'max_participants': training.maxParticipants,
      'participant_ids': training.participantIds != null ? jsonEncode(training.participantIds) : null,
      'status': training.status.toString().split('.').last,
      'notes': training.notes,
      'created_at': training.createdAt.millisecondsSinceEpoch,
      'updated_at': training.updatedAt?.millisecondsSinceEpoch,
    });
  }

  // Certifications
  Future<List<CertificationModel>> getCertifications() async {
    final db = await _db.database;
    final rows = await db.query(
      'certifications',
      orderBy: 'expiry_date ASC',
    );

    return rows.map((r) => CertificationModel.fromMap({
      'id': r['id'],
      'employeeId': r['employee_id'],
      'employeeName': r['employee_name'],
      'certificateName': r['certificate_name'],
      'issuingOrganization': r['issuing_organization'],
      'issueDate': r['issue_date'],
      'expiryDate': r['expiry_date'],
      'certificateNumber': r['certificate_number'],
      'certificateUrl': r['certificate_url'],
      'status': r['status'],
      'notes': r['notes'],
      'createdAt': r['created_at'],
      'updatedAt': r['updated_at'],
    }, r['id'] as String)).toList();
  }

  Future<void> createCertification(CertificationModel cert) async {
    final db = await _db.database;
    await db.insert('certifications', {
      'id': cert.id,
      'employee_id': cert.employeeId,
      'employee_name': cert.employeeName,
      'certificate_name': cert.certificateName,
      'issuing_organization': cert.issuingOrganization,
      'issue_date': cert.issueDate.millisecondsSinceEpoch,
      'expiry_date': cert.expiryDate.millisecondsSinceEpoch,
      'certificate_number': cert.certificateNumber,
      'certificate_url': cert.certificateUrl,
      'status': cert.status.toString().split('.').last,
      'notes': cert.notes,
      'created_at': cert.createdAt.millisecondsSinceEpoch,
      'updated_at': cert.updatedAt?.millisecondsSinceEpoch,
    });
  }
}

