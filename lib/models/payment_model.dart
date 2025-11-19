enum PaymentMethod { cash, card, transfer, insurance }

class PaymentModel {
  final String id;
  final String invoiceId;
  final double amount;
  final PaymentMethod method;
  final String? reference;
  final DateTime createdAt;
  final String? notes;

  PaymentModel({
    required this.id,
    required this.invoiceId,
    required this.amount,
    required this.method,
    this.reference,
    required this.createdAt,
    this.notes,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> map, String id) {
    final methodStr = (map['method'] as String?) ?? 'cash';
    final method = PaymentMethod.values.firstWhere(
      (e) => e.toString().split('.').last == methodStr,
      orElse: () => PaymentMethod.cash,
    );

    DateTime? parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is DateTime) return value;
      return DateTime.now();
    }

    return PaymentModel(
      id: id,
      invoiceId: map['invoiceId'] as String? ?? map['invoice_id'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      method: method,
      reference: map['reference'] as String?,
      createdAt: parseDateTime(map['createdAt'] ?? map['created_at']),
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceId': invoiceId,
      'amount': amount,
      'method': method.toString().split('.').last,
      'reference': reference,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'notes': notes,
    };
  }
}

