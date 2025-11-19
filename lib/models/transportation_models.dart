import 'dart:convert';

// سيارات الإسعاف
enum AmbulanceStatus {
  available, // متاحة
  onDuty, // في الخدمة
  maintenance, // صيانة
  outOfService, // خارج الخدمة
}

enum AmbulanceType {
  basic, // أساسي
  advanced, // متقدم
  critical, // حرج
}

class AmbulanceModel {
  final String id;
  final String vehicleNumber; // رقم المركبة
  final String? vehicleModel; // موديل المركبة
  final AmbulanceType type;
  final AmbulanceStatus status;
  final String? driverId; // معرف السائق
  final String? driverName; // اسم السائق
  final String? location; // الموقع الحالي
  final double? latitude; // خط العرض
  final double? longitude; // خط الطول
  final DateTime? lastLocationUpdate; // آخر تحديث للموقع
  final String? equipment; // المعدات المتوفرة
  final String? notes; // ملاحظات
  final Map<String, dynamic>? additionalInfo;
  final DateTime createdAt;
  final DateTime? updatedAt;

  AmbulanceModel({
    required this.id,
    required this.vehicleNumber,
    this.vehicleModel,
    required this.type,
    this.status = AmbulanceStatus.available,
    this.driverId,
    this.driverName,
    this.location,
    this.latitude,
    this.longitude,
    this.lastLocationUpdate,
    this.equipment,
    this.notes,
    this.additionalInfo,
    required this.createdAt,
    this.updatedAt,
  });

  factory AmbulanceModel.fromMap(Map<String, dynamic> map, String id) {
    final typeStr = (map['type'] ?? 'basic') as String;
    final statusStr = (map['status'] ?? 'available') as String;

    final type = AmbulanceType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => AmbulanceType.basic,
    );
    final status = AmbulanceStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => AmbulanceStatus.available,
    );

    Map<String, dynamic>? parseJson(dynamic v) {
      if (v == null) return null;
      if (v is String) {
        try {
          return jsonDecode(v) as Map<String, dynamic>;
        } catch (_) {
          return null;
        }
      }
      if (v is Map) return Map<String, dynamic>.from(v);
      return null;
    }

    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is DateTime) return v;
      return null;
    }

    return AmbulanceModel(
      id: id,
      vehicleNumber: map['vehicleNumber'] as String? ?? map['vehicle_number'] as String? ?? '',
      vehicleModel: map['vehicleModel'] as String? ?? map['vehicle_model'] as String?,
      type: type,
      status: status,
      driverId: map['driverId'] as String? ?? map['driver_id'] as String?,
      driverName: map['driverName'] as String? ?? map['driver_name'] as String?,
      location: map['location'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      lastLocationUpdate: parseDt(map['lastLocationUpdate'] ?? map['last_location_update']),
      equipment: map['equipment'] as String?,
      notes: map['notes'] as String?,
      additionalInfo: parseJson(map['additionalInfo'] ?? map['additional_info']),
      createdAt: parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      updatedAt: parseDt(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicleNumber': vehicleNumber,
      'vehicleModel': vehicleModel,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'driverId': driverId,
      'driverName': driverName,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'lastLocationUpdate': lastLocationUpdate?.millisecondsSinceEpoch,
      'equipment': equipment,
      'notes': notes,
      'additionalInfo': additionalInfo != null ? jsonEncode(additionalInfo) : null,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

// طلبات النقل
enum TransportationRequestStatus {
  pending, // قيد الانتظار
  assigned, // مكلفة
  inTransit, // قيد النقل
  completed, // مكتملة
  cancelled, // ملغاة
}

enum TransportationRequestType {
  pickup, // استلام
  dropoff, // توصيل
  transfer, // نقل
  emergency, // طوارئ
}

class TransportationRequestModel {
  final String id;
  final String? patientId; // معرف المريض
  final String? patientName; // اسم المريض
  final TransportationRequestType type;
  final TransportationRequestStatus status;
  final String? pickupLocation; // موقع الاستلام
  final double? pickupLatitude;
  final double? pickupLongitude;
  final String? dropoffLocation; // موقع التوصيل
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  final DateTime requestedDate; // تاريخ الطلب
  final DateTime? scheduledDate; // تاريخ مجدول
  final DateTime? pickupTime; // وقت الاستلام
  final DateTime? dropoffTime; // وقت التوصيل
  final String? ambulanceId; // معرف سيارة الإسعاف
  final String? ambulanceNumber; // رقم سيارة الإسعاف
  final String? driverId; // معرف السائق
  final String? driverName; // اسم السائق
  final String? reason; // سبب النقل
  final String? notes; // ملاحظات
  final String? requestedBy; // من طلب
  final String? requestedByName;
  final Map<String, dynamic>? additionalData;
  final DateTime createdAt;
  final DateTime? updatedAt;

  TransportationRequestModel({
    required this.id,
    this.patientId,
    this.patientName,
    required this.type,
    this.status = TransportationRequestStatus.pending,
    this.pickupLocation,
    this.pickupLatitude,
    this.pickupLongitude,
    this.dropoffLocation,
    this.dropoffLatitude,
    this.dropoffLongitude,
    required this.requestedDate,
    this.scheduledDate,
    this.pickupTime,
    this.dropoffTime,
    this.ambulanceId,
    this.ambulanceNumber,
    this.driverId,
    this.driverName,
    this.reason,
    this.notes,
    this.requestedBy,
    this.requestedByName,
    this.additionalData,
    required this.createdAt,
    this.updatedAt,
  });

  factory TransportationRequestModel.fromMap(Map<String, dynamic> map, String id) {
    final typeStr = (map['type'] ?? 'pickup') as String;
    final statusStr = (map['status'] ?? 'pending') as String;

    final type = TransportationRequestType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => TransportationRequestType.pickup,
    );
    final status = TransportationRequestStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => TransportationRequestStatus.pending,
    );

    Map<String, dynamic>? parseJson(dynamic v) {
      if (v == null) return null;
      if (v is String) {
        try {
          return jsonDecode(v) as Map<String, dynamic>;
        } catch (_) {
          return null;
        }
      }
      if (v is Map) return Map<String, dynamic>.from(v);
      return null;
    }

    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is DateTime) return v;
      return null;
    }

    return TransportationRequestModel(
      id: id,
      patientId: map['patientId'] as String? ?? map['patient_id'] as String?,
      patientName: map['patientName'] as String? ?? map['patient_name'] as String?,
      type: type,
      status: status,
      pickupLocation: map['pickupLocation'] as String? ?? map['pickup_location'] as String?,
      pickupLatitude: (map['pickupLatitude'] ?? map['pickup_latitude'] as num?)?.toDouble(),
      pickupLongitude: (map['pickupLongitude'] ?? map['pickup_longitude'] as num?)?.toDouble(),
      dropoffLocation: map['dropoffLocation'] as String? ?? map['dropoff_location'] as String?,
      dropoffLatitude: (map['dropoffLatitude'] ?? map['dropoff_latitude'] as num?)?.toDouble(),
      dropoffLongitude: (map['dropoffLongitude'] ?? map['dropoff_longitude'] as num?)?.toDouble(),
      requestedDate: parseDt(map['requestedDate'] ?? map['requested_date']) ?? DateTime.now(),
      scheduledDate: parseDt(map['scheduledDate'] ?? map['scheduled_date']),
      pickupTime: parseDt(map['pickupTime'] ?? map['pickup_time']),
      dropoffTime: parseDt(map['dropoffTime'] ?? map['dropoff_time']),
      ambulanceId: map['ambulanceId'] as String? ?? map['ambulance_id'] as String?,
      ambulanceNumber: map['ambulanceNumber'] as String? ?? map['ambulance_number'] as String?,
      driverId: map['driverId'] as String? ?? map['driver_id'] as String?,
      driverName: map['driverName'] as String? ?? map['driver_name'] as String?,
      reason: map['reason'] as String?,
      notes: map['notes'] as String?,
      requestedBy: map['requestedBy'] as String? ?? map['requested_by'] as String?,
      requestedByName: map['requestedByName'] as String? ?? map['requested_by_name'] as String?,
      additionalData: parseJson(map['additionalData'] ?? map['additional_data']),
      createdAt: parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      updatedAt: parseDt(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'pickupLocation': pickupLocation,
      'pickupLatitude': pickupLatitude,
      'pickupLongitude': pickupLongitude,
      'dropoffLocation': dropoffLocation,
      'dropoffLatitude': dropoffLatitude,
      'dropoffLongitude': dropoffLongitude,
      'requestedDate': requestedDate.millisecondsSinceEpoch,
      'scheduledDate': scheduledDate?.millisecondsSinceEpoch,
      'pickupTime': pickupTime?.millisecondsSinceEpoch,
      'dropoffTime': dropoffTime?.millisecondsSinceEpoch,
      'ambulanceId': ambulanceId,
      'ambulanceNumber': ambulanceNumber,
      'driverId': driverId,
      'driverName': driverName,
      'reason': reason,
      'notes': notes,
      'requestedBy': requestedBy,
      'requestedByName': requestedByName,
      'additionalData': additionalData != null ? jsonEncode(additionalData) : null,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

// تتبع الموقع
class LocationTrackingModel {
  final String id;
  final String ambulanceId; // معرف سيارة الإسعاف
  final String? ambulanceNumber; // رقم سيارة الإسعاف
  final double latitude; // خط العرض
  final double longitude; // خط الطول
  final String? address; // العنوان
  final double? speed; // السرعة (km/h)
  final double? heading; // الاتجاه (درجات)
  final DateTime timestamp; // الوقت
  final Map<String, dynamic>? metadata;

  LocationTrackingModel({
    required this.id,
    required this.ambulanceId,
    this.ambulanceNumber,
    required this.latitude,
    required this.longitude,
    this.address,
    this.speed,
    this.heading,
    required this.timestamp,
    this.metadata,
  });

  factory LocationTrackingModel.fromMap(Map<String, dynamic> map, String id) {
    Map<String, dynamic>? parseJson(dynamic v) {
      if (v == null) return null;
      if (v is String) {
        try {
          return jsonDecode(v) as Map<String, dynamic>;
        } catch (_) {
          return null;
        }
      }
      if (v is Map) return Map<String, dynamic>.from(v);
      return null;
    }

    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is DateTime) return v;
      return null;
    }

    return LocationTrackingModel(
      id: id,
      ambulanceId: map['ambulanceId'] as String? ?? map['ambulance_id'] as String? ?? '',
      ambulanceNumber: map['ambulanceNumber'] as String? ?? map['ambulance_number'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      address: map['address'] as String?,
      speed: (map['speed'] as num?)?.toDouble(),
      heading: (map['heading'] as num?)?.toDouble(),
      timestamp: parseDt(map['timestamp']) ?? DateTime.now(),
      metadata: parseJson(map['metadata']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ambulanceId': ambulanceId,
      'ambulanceNumber': ambulanceNumber,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'speed': speed,
      'heading': heading,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
    };
  }
}

