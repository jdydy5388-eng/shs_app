enum RoomType { ward, icu, operation, isolation }

class RoomModel {
  final String id;
  final String name;
  final RoomType type;
  final int? floor;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  RoomModel({
    required this.id,
    required this.name,
    required this.type,
    this.floor,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  factory RoomModel.fromMap(Map<String, dynamic> map) {
    final typeStr = (map['type'] as String?) ?? 'ward';
    final type = RoomType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => RoomType.ward,
    );
    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is DateTime) return v;
      return null;
    }
    return RoomModel(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      type: type,
      floor: (map['floor'] as num?)?.toInt(),
      notes: map['notes'] as String?,
      createdAt: parseDt(map['createdAt']) ?? DateTime.now(),
      updatedAt: parseDt(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type.toString().split('.').last,
        'floor': floor,
        'notes': notes,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt?.millisecondsSinceEpoch,
      };
}

enum BedStatus { available, occupied, reserved, maintenance }

class BedModel {
  final String id;
  final String roomId;
  final String label;
  final BedStatus status;
  final String? patientId;
  final DateTime? occupiedSince;
  final DateTime? updatedAt;

  BedModel({
    required this.id,
    required this.roomId,
    required this.label,
    required this.status,
    this.patientId,
    this.occupiedSince,
    this.updatedAt,
  });

  factory BedModel.fromMap(Map<String, dynamic> map) {
    final statusStr = (map['status'] as String?) ?? 'available';
    final status = BedStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => BedStatus.available,
    );
    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is DateTime) return v;
      return null;
    }
    return BedModel(
      id: map['id'] as String,
      roomId: map['roomId'] as String? ?? map['room_id'] as String? ?? '',
      label: map['label'] as String? ?? '',
      status: status,
      patientId: map['patientId'] as String? ?? map['patient_id'] as String?,
      occupiedSince: parseDt(map['occupiedSince'] ?? map['occupied_since']),
      updatedAt: parseDt(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'roomId': roomId,
        'label': label,
        'status': status.toString().split('.').last,
        'patientId': patientId,
        'occupiedSince': occupiedSince?.millisecondsSinceEpoch,
        'updatedAt': updatedAt?.millisecondsSinceEpoch,
      };
}


