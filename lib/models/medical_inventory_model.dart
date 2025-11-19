import 'dart:convert';

enum InventoryItemType {
  equipment, // معدات (أجهزة، آلات)
  supplies, // مستلزمات (أدوات، مواد)
  consumables, // مواد استهلاكية
}

enum EquipmentStatus {
  available, // متاحة
  inUse, // قيد الاستخدام
  maintenance, // صيانة
  outOfOrder, // معطلة
}

class MedicalInventoryItemModel {
  final String id;
  final String name;
  final InventoryItemType type;
  final String? category;
  final String? description;
  final int quantity;
  final int? minStockLevel; // الحد الأدنى للمخزون
  final String? unit; // وحدة القياس (قطعة، علبة، لتر، إلخ)
  final double? unitPrice;
  final String? manufacturer;
  final String? model;
  final String? serialNumber;
  final DateTime? purchaseDate;
  final DateTime? expiryDate;
  final String? location; // موقع التخزين
  final EquipmentStatus? status; // للمعدات فقط
  final DateTime? lastMaintenanceDate;
  final DateTime? nextMaintenanceDate;
  final String? supplierId;
  final String? supplierName;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MedicalInventoryItemModel({
    required this.id,
    required this.name,
    required this.type,
    this.category,
    this.description,
    required this.quantity,
    this.minStockLevel,
    this.unit,
    this.unitPrice,
    this.manufacturer,
    this.model,
    this.serialNumber,
    this.purchaseDate,
    this.expiryDate,
    this.location,
    this.status,
    this.lastMaintenanceDate,
    this.nextMaintenanceDate,
    this.supplierId,
    this.supplierName,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isLowStock => minStockLevel != null && quantity <= minStockLevel!;
  bool get isOutOfStock => quantity <= 0;
  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());
  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final daysUntilExpiry = expiryDate!.difference(DateTime.now()).inDays;
    return daysUntilExpiry <= 30 && daysUntilExpiry > 0;
  }
  bool get needsMaintenance {
    if (nextMaintenanceDate == null) return false;
    return nextMaintenanceDate!.isBefore(DateTime.now()) ||
        nextMaintenanceDate!.difference(DateTime.now()).inDays <= 7;
  }

  static DateTime? _parseDt(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is DateTime) return v;
    return null;
  }

  factory MedicalInventoryItemModel.fromMap(Map<String, dynamic> map, String id) {
    final typeStr = (map['type'] ?? 'supplies') as String;
    final statusStr = map['status'] as String?;

    final type = InventoryItemType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => InventoryItemType.supplies,
    );

    EquipmentStatus? status;
    if (statusStr != null) {
      status = EquipmentStatus.values.firstWhere(
        (e) => e.toString().split('.').last == statusStr,
        orElse: () => EquipmentStatus.available,
      );
    }

    return MedicalInventoryItemModel(
      id: id,
      name: map['name'] as String? ?? map['name'] as String? ?? '',
      type: type,
      category: map['category'] as String?,
      description: map['description'] as String?,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      minStockLevel: (map['minStockLevel'] as num?)?.toInt() ?? map['min_stock_level'] as int?,
      unit: map['unit'] as String?,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? (map['unit_price'] as num?)?.toDouble(),
      manufacturer: map['manufacturer'] as String?,
      model: map['model'] as String?,
      serialNumber: map['serialNumber'] as String? ?? map['serial_number'] as String?,
      purchaseDate: _parseDt(map['purchaseDate'] ?? map['purchase_date']),
      expiryDate: _parseDt(map['expiryDate'] ?? map['expiry_date']),
      location: map['location'] as String?,
      status: status,
      lastMaintenanceDate: _parseDt(map['lastMaintenanceDate'] ?? map['last_maintenance_date']),
      nextMaintenanceDate: _parseDt(map['nextMaintenanceDate'] ?? map['next_maintenance_date']),
      supplierId: map['supplierId'] as String? ?? map['supplier_id'] as String?,
      supplierName: map['supplierName'] as String? ?? map['supplier_name'] as String?,
      createdAt: _parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      updatedAt: _parseDt(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last,
      'category': category,
      'description': description,
      'quantity': quantity,
      'minStockLevel': minStockLevel,
      'unit': unit,
      'unitPrice': unitPrice,
      'manufacturer': manufacturer,
      'model': model,
      'serialNumber': serialNumber,
      'purchaseDate': purchaseDate?.millisecondsSinceEpoch,
      'expiryDate': expiryDate?.millisecondsSinceEpoch,
      'location': location,
      'status': status?.toString().split('.').last,
      'lastMaintenanceDate': lastMaintenanceDate?.millisecondsSinceEpoch,
      'nextMaintenanceDate': nextMaintenanceDate?.millisecondsSinceEpoch,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

class SupplierModel {
  final String id;
  final String name;
  final String? contactPerson;
  final String? email;
  final String? phone;
  final String? address;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  SupplierModel({
    required this.id,
    required this.name,
    this.contactPerson,
    this.email,
    this.phone,
    this.address,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  static DateTime? _parseDt(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is DateTime) return v;
    return null;
  }

  factory SupplierModel.fromMap(Map<String, dynamic> map, String id) {
    return SupplierModel(
      id: id,
      name: map['name'] as String? ?? '',
      contactPerson: map['contactPerson'] as String? ?? map['contact_person'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      notes: map['notes'] as String?,
      createdAt: _parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      updatedAt: _parseDt(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'contactPerson': contactPerson,
      'email': email,
      'phone': phone,
      'address': address,
      'notes': notes,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

enum PurchaseOrderStatus {
  draft, // مسودة
  pending, // قيد الانتظار
  approved, // معتمدة
  ordered, // تم الطلب
  received, // مستلمة
  cancelled, // ملغاة
}

class PurchaseOrderModel {
  final String id;
  final String orderNumber;
  final String? supplierId;
  final String? supplierName;
  final List<PurchaseOrderItem> items;
  final double totalAmount;
  final PurchaseOrderStatus status;
  final String? notes;
  final String? requestedBy;
  final DateTime? requestedDate;
  final String? approvedBy;
  final DateTime? approvedDate;
  final DateTime? orderedDate;
  final DateTime? receivedDate;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PurchaseOrderModel({
    required this.id,
    required this.orderNumber,
    this.supplierId,
    this.supplierName,
    required this.items,
    required this.totalAmount,
    required this.status,
    this.notes,
    this.requestedBy,
    this.requestedDate,
    this.approvedBy,
    this.approvedDate,
    this.orderedDate,
    this.receivedDate,
    required this.createdAt,
    this.updatedAt,
  });

  static DateTime? _parseDt(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is DateTime) return v;
    return null;
  }

  factory PurchaseOrderModel.fromMap(Map<String, dynamic> map, String id) {
    final statusStr = (map['status'] ?? 'draft') as String;
    final status = PurchaseOrderStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => PurchaseOrderStatus.draft,
    );

    List<PurchaseOrderItem> items = [];
    if (map['items'] != null) {
      if (map['items'] is List) {
        items = (map['items'] as List)
            .map((i) => PurchaseOrderItem.fromMap(i as Map<String, dynamic>))
            .toList();
      } else if (map['items'] is String) {
        try {
          final decoded = jsonDecode(map['items'] as String) as List;
          items = decoded
              .map((i) => PurchaseOrderItem.fromMap(i as Map<String, dynamic>))
              .toList();
        } catch (_) {}
      }
    }

    return PurchaseOrderModel(
      id: id,
      orderNumber: map['orderNumber'] as String? ?? map['order_number'] as String? ?? '',
      supplierId: map['supplierId'] as String? ?? map['supplier_id'] as String?,
      supplierName: map['supplierName'] as String? ?? map['supplier_name'] as String?,
      items: items,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      status: status,
      notes: map['notes'] as String?,
      requestedBy: map['requestedBy'] as String? ?? map['requested_by'] as String?,
      requestedDate: _parseDt(map['requestedDate'] ?? map['requested_date']),
      approvedBy: map['approvedBy'] as String? ?? map['approved_by'] as String?,
      approvedDate: _parseDt(map['approvedDate'] ?? map['approved_date']),
      orderedDate: _parseDt(map['orderedDate'] ?? map['ordered_date']),
      receivedDate: _parseDt(map['receivedDate'] ?? map['received_date']),
      createdAt: _parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      updatedAt: _parseDt(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'items': items.map((i) => i.toMap()).toList(),
      'totalAmount': totalAmount,
      'status': status.toString().split('.').last,
      'notes': notes,
      'requestedBy': requestedBy,
      'requestedDate': requestedDate?.millisecondsSinceEpoch,
      'approvedBy': approvedBy,
      'approvedDate': approvedDate?.millisecondsSinceEpoch,
      'orderedDate': orderedDate?.millisecondsSinceEpoch,
      'receivedDate': receivedDate?.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

class PurchaseOrderItem {
  final String itemId;
  final String itemName;
  final int quantity;
  final double unitPrice;
  final double total;

  PurchaseOrderItem({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  factory PurchaseOrderItem.fromMap(Map<String, dynamic> map) {
    return PurchaseOrderItem(
      itemId: map['itemId'] as String? ?? map['item_id'] as String? ?? '',
      itemName: map['itemName'] as String? ?? map['item_name'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'total': total,
    };
  }
}

class MaintenanceRecordModel {
  final String id;
  final String equipmentId;
  final String equipmentName;
  final DateTime maintenanceDate;
  final String maintenanceType; // scheduled / repair / inspection
  final String? description;
  final String? performedBy;
  final double? cost;
  final DateTime? nextMaintenanceDate;
  final DateTime createdAt;

  MaintenanceRecordModel({
    required this.id,
    required this.equipmentId,
    required this.equipmentName,
    required this.maintenanceDate,
    required this.maintenanceType,
    this.description,
    this.performedBy,
    this.cost,
    this.nextMaintenanceDate,
    required this.createdAt,
  });

  static DateTime? _parseDt(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is DateTime) return v;
    return null;
  }

  factory MaintenanceRecordModel.fromMap(Map<String, dynamic> map, String id) {
    return MaintenanceRecordModel(
      id: id,
      equipmentId: map['equipmentId'] as String? ?? map['equipment_id'] as String? ?? '',
      equipmentName: map['equipmentName'] as String? ?? map['equipment_name'] as String? ?? '',
      maintenanceDate: _parseDt(map['maintenanceDate'] ?? map['maintenance_date']) ?? DateTime.now(),
      maintenanceType: map['maintenanceType'] as String? ?? map['maintenance_type'] as String? ?? 'scheduled',
      description: map['description'] as String?,
      performedBy: map['performedBy'] as String? ?? map['performed_by'] as String?,
      cost: (map['cost'] as num?)?.toDouble(),
      nextMaintenanceDate: _parseDt(map['nextMaintenanceDate'] ?? map['next_maintenance_date']),
      createdAt: _parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'equipmentId': equipmentId,
      'equipmentName': equipmentName,
      'maintenanceDate': maintenanceDate.millisecondsSinceEpoch,
      'maintenanceType': maintenanceType,
      'description': description,
      'performedBy': performedBy,
      'cost': cost,
      'nextMaintenanceDate': nextMaintenanceDate?.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}

