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
import '../models/room_bed_model.dart';
import '../models/emergency_case_model.dart';
import '../models/notification_model.dart';
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
    // حفظ الملف محليًا ضمن مجلد التطبيق
    // لعدم إضافة تبعيات هنا، سنحاول استخدام مجلد قاعدة البيانات كمرجع قريب
    final db = await _db.database; // يضمن تهيئة المسار
    (db); // لتجنب التحذير
    final dir = await LocalDatabaseService().database; // نضمن التهيئة
    (dir); // لا يستخدم مباشرة
    // بديل: حفظ داخل مجلد التشغيل الحالي
    final safeName = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = 'uploads_local_$safeName';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}

