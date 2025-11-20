enum UserRole { patient, doctor, pharmacist, admin, labTechnician, radiologist, nurse, receptionist }

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String? profileImageUrl;
  final Map<String, dynamic>? additionalInfo;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.profileImageUrl,
    this.additionalInfo,
    required this.createdAt,
    this.lastLoginAt,
  });

  // For Doctor
  String? get specialization => additionalInfo?['specialization'] as String?;
  String? get licenseNumber => additionalInfo?['licenseNumber'] as String?;
  
  // For Pharmacist
  String? get pharmacyName => additionalInfo?['pharmacyName'] as String?;
  String? get pharmacyAddress => additionalInfo?['pharmacyAddress'] as String?;
  
  // For Patient
  String? get dateOfBirth => additionalInfo?['dateOfBirth'] as String?;
  String? get bloodType => additionalInfo?['bloodType'] as String?;
  List<String>? get allergies => (additionalInfo?['allergies'] as List?)?.cast<String>();

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    // التعامل مع createdAt - قد يكون int (milliseconds) أو DateTime
    DateTime createdAt;
    final createdAtValue = map['createdAt'];
    if (createdAtValue is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtValue);
    } else if (createdAtValue is DateTime) {
      createdAt = createdAtValue;
    } else if (createdAtValue != null && createdAtValue.runtimeType.toString().contains('Timestamp')) {
      // Firebase Timestamp فقط
      createdAt = (createdAtValue as dynamic).toDate();
    } else {
      createdAt = DateTime.now();
    }

    // التعامل مع lastLoginAt
    DateTime? lastLoginAt;
    final lastLoginAtValue = map['lastLoginAt'];
    if (lastLoginAtValue != null) {
      if (lastLoginAtValue is int) {
        lastLoginAt = DateTime.fromMillisecondsSinceEpoch(lastLoginAtValue);
      } else if (lastLoginAtValue is DateTime) {
        lastLoginAt = lastLoginAtValue;
      } else if (lastLoginAtValue.runtimeType.toString().contains('Timestamp')) {
        // Firebase Timestamp فقط
        lastLoginAt = (lastLoginAtValue as dynamic).toDate();
      }
    }

    return UserModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == map['role'],
        orElse: () => UserRole.patient,
      ),
      profileImageUrl: map['profileImageUrl'],
      additionalInfo: map['additionalInfo'] != null
          ? Map<String, dynamic>.from(map['additionalInfo'])
          : null,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.toString().split('.').last,
      'profileImageUrl': profileImageUrl,
      'additionalInfo': additionalInfo,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastLoginAt': lastLoginAt?.millisecondsSinceEpoch,
    };
  }
}

