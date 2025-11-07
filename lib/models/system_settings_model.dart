class SystemSettingsModel {
  const SystemSettingsModel({
    required this.id,
    required this.key,
    required this.value,
    required this.description,
    required this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String key;
  final String value;
  final String description;
  final DateTime updatedAt;
  final String? updatedBy;

  bool get boolValue => value.toLowerCase() == 'true';
  int? get intValue => int.tryParse(value);
  double? get doubleValue => double.tryParse(value);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'key': key,
      'value': value,
      'description': description,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'updated_by': updatedBy,
    };
  }

  factory SystemSettingsModel.fromMap(Map<String, dynamic> map) {
    return SystemSettingsModel(
      id: map['id'] as String,
      key: map['key'] as String,
      value: map['value'] as String,
      description: map['description'] as String,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      updatedBy: map['updated_by'] as String?,
    );
  }
}

