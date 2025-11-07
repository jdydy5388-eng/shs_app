class DoctorTask {
  const DoctorTask({
    required this.id,
    required this.doctorId,
    required this.title,
    required this.createdAt,
    this.description,
    this.dueDate,
    this.isCompleted = false,
    this.completedAt,
  });

  final String id;
  final String doctorId;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? completedAt;

  DoctorTask copyWith({
    String? id,
    String? doctorId,
    String? title,
    String? description,
    DateTime? dueDate,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return DoctorTask(
      id: id ?? this.id,
      doctorId: doctorId ?? this.doctorId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'doctor_id': doctorId,
      'title': title,
      'description': description,
      'due_date': dueDate?.millisecondsSinceEpoch,
      'is_completed': isCompleted ? 1 : 0,
      'completed_at': completedAt?.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory DoctorTask.fromMap(Map<String, dynamic> map) {
    return DoctorTask(
      id: map['id'] as String,
      doctorId: map['doctor_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      dueDate: map['due_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['due_date'] as int)
          : null,
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      completedAt: map['completed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completed_at'] as int)
          : null,
    );
  }
}
