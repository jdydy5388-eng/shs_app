class InvoiceItem {
  final String description;
  final int quantity;
  final double unitPrice;

  InvoiceItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => unitPrice * quantity;

  Map<String, dynamic> toMap() => {
        'description': description,
        'qty': quantity,
        'unitPrice': unitPrice,
        'total': total,
      };

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      description: map['description'] as String? ?? '',
      quantity: (map['qty'] as num?)?.toInt() ?? (map['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

enum InvoiceStatus { draft, issued, paid, cancelled }

class InvoiceModel {
  final String id;
  final String patientId;
  final String patientName;
  final String? relatedType;
  final String? relatedId;
  final List<InvoiceItem> items;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String currency;
  final InvoiceStatus status;
  final String? insuranceProvider;
  final String? insurancePolicy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? paidAt;

  InvoiceModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    this.relatedType,
    this.relatedId,
    required this.items,
    required this.subtotal,
    this.discount = 0,
    this.tax = 0,
    required this.total,
    this.currency = 'SAR',
    required this.status,
    this.insuranceProvider,
    this.insurancePolicy,
    required this.createdAt,
    this.updatedAt,
    this.paidAt,
  });

  factory InvoiceModel.fromMap(Map<String, dynamic> map, String id) {
    List<InvoiceItem> parseItems(dynamic v) {
      if (v == null) return [];
      if (v is List) {
        return v.map((e) => InvoiceItem.fromMap(Map<String, dynamic>.from(e as Map))).toList();
      }
      return [];
    }

    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is DateTime) return v;
      return null;
    }

    final statusStr = (map['status'] as String?) ?? 'issued';
    final status = InvoiceStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => InvoiceStatus.issued,
    );

    final items = parseItems(map['items']);

    return InvoiceModel(
      id: id,
      patientId: map['patientId'] as String? ?? '',
      patientName: map['patientName'] as String? ?? '',
      relatedType: map['relatedType'] as String?,
      relatedId: map['relatedId'] as String?,
      items: items,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? items.fold(0.0, (s, i) => s + i.total),
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      tax: (map['tax'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ??
          ((map['subtotal'] as num?)?.toDouble() ?? 0) - ((map['discount'] as num?)?.toDouble() ?? 0) + ((map['tax'] as num?)?.toDouble() ?? 0),
      currency: map['currency'] as String? ?? 'SAR',
      status: status,
      insuranceProvider: map['insuranceProvider'] as String?,
      insurancePolicy: map['insurancePolicy'] as String?,
      createdAt: parseDt(map['createdAt']) ?? DateTime.now(),
      updatedAt: parseDt(map['updatedAt']),
      paidAt: parseDt(map['paidAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'relatedType': relatedType,
      'relatedId': relatedId,
      'items': items.map((e) => e.toMap()).toList(),
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'total': total,
      'currency': currency,
      'status': status.toString().split('.').last,
      'insuranceProvider': insuranceProvider,
      'insurancePolicy': insurancePolicy,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'paidAt': paidAt?.millisecondsSinceEpoch,
    };
  }
}


