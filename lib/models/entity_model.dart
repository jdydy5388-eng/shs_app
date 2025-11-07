enum EntityType { pharmacy, hospital }

class EntityModel {
  const EntityModel({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    required this.phone,
    required this.email,
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.licenseNumber,
    this.notes,
  });

  final String id;
  final String name;
  final EntityType type;
  final String address;
  final String phone;
  final String email;
  final double? latitude;
  final double? longitude;
  final String? licenseNumber;
  final String? notes;
  final DateTime createdAt;

  String get typeName => type == EntityType.pharmacy ? 'صيدلية' : 'مستشفى';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last,
      'address': address,
      'phone': phone,
      'email': email,
      'latitude': latitude,
      'longitude': longitude,
      'license_number': licenseNumber,
      'notes': notes,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory EntityModel.fromMap(Map<String, dynamic> map) {
    return EntityModel(
      id: map['id'] as String,
      name: map['name'] as String,
      type: EntityType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => EntityType.pharmacy,
      ),
      address: map['address'] as String,
      phone: map['phone'] as String,
      email: map['email'] as String,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      licenseNumber: map['license_number'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}

