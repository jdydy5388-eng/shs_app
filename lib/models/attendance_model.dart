class AttendanceRecord {
  final String id;
  final String userId;
  final String role;
  final DateTime checkIn;
  final DateTime? checkOut;
  final double? locationLat;
  final double? locationLng;
  final String? notes;
  final DateTime createdAt;

  AttendanceRecord({
    required this.id,
    required this.userId,
    required this.role,
    required this.checkIn,
    this.checkOut,
    this.locationLat,
    this.locationLng,
    this.notes,
    required this.createdAt,
  });

  static DateTime? _parse(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is DateTime) return v;
    return null;
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map, String id) {
    return AttendanceRecord(
      id: id,
      userId: map['userId'] as String? ?? map['user_id'] as String? ?? '',
      role: map['role'] as String? ?? '',
      checkIn: _parse(map['checkIn'] ?? map['check_in']) ?? DateTime.now(),
      checkOut: _parse(map['checkOut'] ?? map['check_out']),
      locationLat: (map['locationLat'] as num?)?.toDouble() ?? (map['location_lat'] as num?)?.toDouble(),
      locationLng: (map['locationLng'] as num?)?.toDouble() ?? (map['location_lng'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      createdAt: _parse(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'role': role,
        'checkIn': checkIn.millisecondsSinceEpoch,
        'checkOut': checkOut?.millisecondsSinceEpoch,
        'locationLat': locationLat,
        'locationLng': locationLng,
        'notes': notes,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };
}

class ShiftModel {
  final String id;
  final String userId;
  final String role;
  final DateTime startTime;
  final DateTime endTime;
  final String? department;
  final String? recurrence; // none/daily/weekly
  final DateTime createdAt;

  ShiftModel({
    required this.id,
    required this.userId,
    required this.role,
    required this.startTime,
    required this.endTime,
    this.department,
    this.recurrence,
    required this.createdAt,
  });

  static DateTime _parse(dynamic v) {
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is DateTime) return v;
    return DateTime.now();
  }

  factory ShiftModel.fromMap(Map<String, dynamic> map, String id) {
    return ShiftModel(
      id: id,
      userId: map['userId'] as String? ?? map['user_id'] as String? ?? '',
      role: map['role'] as String? ?? '',
      startTime: _parse(map['startTime'] ?? map['start_time']),
      endTime: _parse(map['endTime'] ?? map['end_time']),
      department: map['department'] as String?,
      recurrence: map['recurrence'] as String?,
      createdAt: _parse(map['createdAt'] ?? map['created_at']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'role': role,
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': endTime.millisecondsSinceEpoch,
        'department': department,
        'recurrence': recurrence,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };
}


