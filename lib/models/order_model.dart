enum OrderStatus { pending, confirmed, preparing, ready, delivered, cancelled }

class OrderItem {
  final String id;
  final String medicationId;
  final String medicationName;
  final int quantity;
  final double price;
  final String? alternativeMedicationId; // إذا كان الدواء البديل موجود
  final String? alternativeMedicationName;
  final double? alternativePrice;

  const OrderItem({
    required this.id,
    required this.medicationId,
    required this.medicationName,
    required this.quantity,
    required this.price,
    this.alternativeMedicationId,
    this.alternativeMedicationName,
    this.alternativePrice,
  });

  bool get hasPendingAlternative => alternativeMedicationId != null;

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    final dynamicId = map['id'] ?? map['orderItemId'] ?? map['medicationId'];
    final dynamicAltId =
        map['alternative_medication_id'] ?? map['alternativeMedicationId'];
    final dynamicAltName = map['alternative_medication_name'] ??
        map['alternativeMedicationName'];
    final dynamicAltPrice =
        map['alternative_price'] ?? map['alternativePrice'];

    return OrderItem(
      id: (dynamicId ?? '').toString(),
      medicationId:
          (map['medication_id'] ?? map['medicationId'] ?? '').toString(),
      medicationName:
          (map['medication_name'] ?? map['medicationName'] ?? '').toString(),
      quantity: (map['quantity'] is num)
          ? (map['quantity'] as num).toInt()
          : int.tryParse('${map['quantity']}') ?? 0,
      price: (map['price'] is num)
          ? (map['price'] as num).toDouble()
          : double.tryParse('${map['price']}') ?? 0.0,
      alternativeMedicationId:
          dynamicAltId != null ? dynamicAltId.toString() : null,
      alternativeMedicationName:
          dynamicAltName != null ? dynamicAltName.toString() : null,
      alternativePrice: dynamicAltPrice is num
          ? dynamicAltPrice.toDouble()
          : dynamicAltPrice != null
              ? double.tryParse(dynamicAltPrice.toString())
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicationId': medicationId,
      'medicationName': medicationName,
      'quantity': quantity,
      'price': price,
      'alternativeMedicationId': alternativeMedicationId,
      'alternativeMedicationName': alternativeMedicationName,
      'alternativePrice': alternativePrice,
    };
  }
}

class MedicationOrderModel {
  final String id;
  final String patientId;
  final String patientName;
  final String pharmacyId;
  final String pharmacyName;
  final String? prescriptionId;
  final List<OrderItem> items;
  final OrderStatus status;
  final double totalAmount;
  final String? deliveryAddress;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deliveredAt;

  MedicationOrderModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.pharmacyId,
    required this.pharmacyName,
    this.prescriptionId,
    required this.items,
    required this.status,
    required this.totalAmount,
    this.deliveryAddress,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.deliveredAt,
  });

  static DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is DateTime) return v;
    if (v is String) {
      final parsed = DateTime.tryParse(v);
      if (parsed != null) return parsed;
    }
    // فقط إذا كان Firebase Timestamp (وليس DateTime)
    try {
      if (v.runtimeType.toString().contains('Timestamp')) {
        final toDate = (v as dynamic).toDate();
        if (toDate is DateTime) return toDate;
      }
    } catch (_) {}
    return null;
  }

  factory MedicationOrderModel.fromMap(Map<String, dynamic> map, String id) {
    return MedicationOrderModel(
      id: id,
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? '',
      pharmacyId: map['pharmacyId'] ?? '',
      pharmacyName: map['pharmacyName'] ?? '',
      prescriptionId: map['prescriptionId'],
      items: (map['items'] as List?)
              ?.map((i) => OrderItem.fromMap(i as Map<String, dynamic>))
              .toList() ??
          [],
      status: OrderStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => OrderStatus.pending,
      ),
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      deliveryAddress: map['deliveryAddress'],
      notes: map['notes'],
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(map['updatedAt']),
      deliveredAt: _parseDateTime(map['deliveredAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'patientName': patientName,
      'pharmacyId': pharmacyId,
      'pharmacyName': pharmacyName,
      'prescriptionId': prescriptionId,
      'items': items.map((i) => i.toMap()).toList(),
      'status': status.toString().split('.').last,
      'totalAmount': totalAmount,
      'deliveryAddress': deliveryAddress,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'deliveredAt': deliveredAt,
    };
  }
}

