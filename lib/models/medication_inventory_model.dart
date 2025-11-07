class MedicationInventoryModel {
  final String id;
  final String pharmacyId;
  final String medicationName;
  final String medicationId;
  final int quantity;
  final double price;
  final String? manufacturer;
  final DateTime? expiryDate;
  final String? batchNumber;
  final DateTime lastUpdated;

  MedicationInventoryModel({
    required this.id,
    required this.pharmacyId,
    required this.medicationName,
    required this.medicationId,
    required this.quantity,
    required this.price,
    this.manufacturer,
    this.expiryDate,
    this.batchNumber,
    required this.lastUpdated,
  });

  bool get isLowStock => quantity < 10;
  bool get isOutOfStock => quantity <= 0;
  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());

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

  factory MedicationInventoryModel.fromMap(Map<String, dynamic> map, String id) {
    return MedicationInventoryModel(
      id: id,
      pharmacyId: map['pharmacyId'] ?? '',
      medicationName: map['medicationName'] ?? '',
      medicationId: map['medicationId'] ?? '',
      quantity: map['quantity'] ?? 0,
      price: (map['price'] ?? 0.0).toDouble(),
      manufacturer: map['manufacturer'],
      expiryDate: _parseDateTime(map['expiryDate']),
      batchNumber: map['batchNumber'],
      lastUpdated: _parseDateTime(map['lastUpdated']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pharmacyId': pharmacyId,
      'medicationName': medicationName,
      'medicationId': medicationId,
      'quantity': quantity,
      'price': price,
      'manufacturer': manufacturer,
      'expiryDate': expiryDate,
      'batchNumber': batchNumber,
      'lastUpdated': lastUpdated,
    };
  }
}

