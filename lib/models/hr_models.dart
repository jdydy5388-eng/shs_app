import 'dart:convert';

// الموظفين
enum EmploymentStatus {
  active, // نشط
  onLeave, // في إجازة
  suspended, // موقوف
  terminated, // منتهي الخدمة
}

enum EmploymentType {
  fullTime, // دوام كامل
  partTime, // دوام جزئي
  contract, // عقد
  temporary, // مؤقت
}

class EmployeeModel {
  final String id;
  final String userId; // ربط بحساب المستخدم
  final String employeeNumber; // رقم الموظف
  final String department; // القسم
  final String position; // المنصب
  final EmploymentType employmentType;
  final EmploymentStatus status;
  final DateTime hireDate; // تاريخ التعيين
  final DateTime? terminationDate; // تاريخ إنهاء الخدمة
  final double? salary; // الراتب
  final String? managerId; // المدير المباشر
  final String? managerName;
  final Map<String, dynamic>? additionalInfo;
  final DateTime createdAt;
  final DateTime? updatedAt;

  EmployeeModel({
    required this.id,
    required this.userId,
    required this.employeeNumber,
    required this.department,
    required this.position,
    required this.employmentType,
    this.status = EmploymentStatus.active,
    required this.hireDate,
    this.terminationDate,
    this.salary,
    this.managerId,
    this.managerName,
    this.additionalInfo,
    required this.createdAt,
    this.updatedAt,
  });

  factory EmployeeModel.fromMap(Map<String, dynamic> map, String id) {
    final typeStr = (map['employmentType'] ?? map['employment_type'] ?? 'fullTime') as String;
    final statusStr = (map['status'] ?? 'active') as String;

    final type = EmploymentType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => EmploymentType.fullTime,
    );
    final status = EmploymentStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => EmploymentStatus.active,
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

    return EmployeeModel(
      id: id,
      userId: map['userId'] as String? ?? map['user_id'] as String? ?? '',
      employeeNumber: map['employeeNumber'] as String? ?? map['employee_number'] as String? ?? '',
      department: map['department'] as String? ?? '',
      position: map['position'] as String? ?? '',
      employmentType: type,
      status: status,
      hireDate: parseDt(map['hireDate'] ?? map['hire_date']) ?? DateTime.now(),
      terminationDate: parseDt(map['terminationDate'] ?? map['termination_date']),
      salary: (map['salary'] as num?)?.toDouble(),
      managerId: map['managerId'] as String? ?? map['manager_id'] as String?,
      managerName: map['managerName'] as String? ?? map['manager_name'] as String?,
      additionalInfo: parseJson(map['additionalInfo'] ?? map['additional_info']),
      createdAt: parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      updatedAt: parseDt(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'employeeNumber': employeeNumber,
      'department': department,
      'position': position,
      'employmentType': employmentType.toString().split('.').last,
      'status': status.toString().split('.').last,
      'hireDate': hireDate.millisecondsSinceEpoch,
      'terminationDate': terminationDate?.millisecondsSinceEpoch,
      'salary': salary,
      'managerId': managerId,
      'managerName': managerName,
      'additionalInfo': additionalInfo != null ? jsonEncode(additionalInfo) : null,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

// الإجازات
enum LeaveType {
  annual, // سنوية
  sick, // مرضية
  emergency, // طارئة
  maternity, // أمومة
  paternity, // أبوة
  unpaid, // بدون راتب
  other, // أخرى
}

enum LeaveStatus {
  pending, // قيد المراجعة
  approved, // موافق عليها
  rejected, // مرفوضة
  cancelled, // ملغاة
}

class LeaveRequestModel {
  final String id;
  final String employeeId;
  final String? employeeName;
  final LeaveType type;
  final LeaveStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final int days; // عدد الأيام
  final String? reason;
  final String? notes;
  final String? approvedBy;
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime? updatedAt;

  LeaveRequestModel({
    required this.id,
    required this.employeeId,
    this.employeeName,
    required this.type,
    this.status = LeaveStatus.pending,
    required this.startDate,
    required this.endDate,
    required this.days,
    this.reason,
    this.notes,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    this.rejectionReason,
    required this.createdAt,
    this.updatedAt,
  });

  factory LeaveRequestModel.fromMap(Map<String, dynamic> map, String id) {
    final typeStr = (map['type'] ?? 'annual') as String;
    final statusStr = (map['status'] ?? 'pending') as String;

    final type = LeaveType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => LeaveType.annual,
    );
    final status = LeaveStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => LeaveStatus.pending,
    );

    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is DateTime) return v;
      return null;
    }

    return LeaveRequestModel(
      id: id,
      employeeId: map['employeeId'] as String? ?? map['employee_id'] as String? ?? '',
      employeeName: map['employeeName'] as String? ?? map['employee_name'] as String?,
      type: type,
      status: status,
      startDate: parseDt(map['startDate'] ?? map['start_date']) ?? DateTime.now(),
      endDate: parseDt(map['endDate'] ?? map['end_date']) ?? DateTime.now(),
      days: (map['days'] as num?)?.toInt() ?? 0,
      reason: map['reason'] as String?,
      notes: map['notes'] as String?,
      approvedBy: map['approvedBy'] as String? ?? map['approved_by'] as String?,
      approvedByName: map['approvedByName'] as String? ?? map['approved_by_name'] as String?,
      approvedAt: parseDt(map['approvedAt'] ?? map['approved_at']),
      rejectionReason: map['rejectionReason'] as String? ?? map['rejection_reason'] as String?,
      createdAt: parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      updatedAt: parseDt(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'startDate': startDate.millisecondsSinceEpoch,
      'endDate': endDate.millisecondsSinceEpoch,
      'days': days,
      'reason': reason,
      'notes': notes,
      'approvedBy': approvedBy,
      'approvedByName': approvedByName,
      'approvedAt': approvedAt?.millisecondsSinceEpoch,
      'rejectionReason': rejectionReason,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

// الرواتب
enum PayrollStatus {
  draft, // مسودة
  processed, // معالجة
  paid, // مدفوعة
  cancelled, // ملغاة
}

class PayrollModel {
  final String id;
  final String employeeId;
  final String? employeeName;
  final DateTime payPeriodStart; // بداية فترة الراتب
  final DateTime payPeriodEnd; // نهاية فترة الراتب
  final double baseSalary; // الراتب الأساسي
  final double? allowances; // البدلات
  final double? deductions; // الخصومات
  final double? bonuses; // المكافآت
  final double? overtime; // ساعات إضافية
  final double netSalary; // الراتب الصافي
  final PayrollStatus status;
  final DateTime? paidDate; // تاريخ الدفع
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PayrollModel({
    required this.id,
    required this.employeeId,
    this.employeeName,
    required this.payPeriodStart,
    required this.payPeriodEnd,
    required this.baseSalary,
    this.allowances,
    this.deductions,
    this.bonuses,
    this.overtime,
    required this.netSalary,
    this.status = PayrollStatus.draft,
    this.paidDate,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  factory PayrollModel.fromMap(Map<String, dynamic> map, String id) {
    final statusStr = (map['status'] ?? 'draft') as String;

    final status = PayrollStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => PayrollStatus.draft,
    );

    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is DateTime) return v;
      return null;
    }

    return PayrollModel(
      id: id,
      employeeId: map['employeeId'] as String? ?? map['employee_id'] as String? ?? '',
      employeeName: map['employeeName'] as String? ?? map['employee_name'] as String?,
      payPeriodStart: parseDt(map['payPeriodStart'] ?? map['pay_period_start']) ?? DateTime.now(),
      payPeriodEnd: parseDt(map['payPeriodEnd'] ?? map['pay_period_end']) ?? DateTime.now(),
      baseSalary: (map['baseSalary'] ?? map['base_salary'] as num?)?.toDouble() ?? 0.0,
      allowances: (map['allowances'] as num?)?.toDouble(),
      deductions: (map['deductions'] as num?)?.toDouble(),
      bonuses: (map['bonuses'] as num?)?.toDouble(),
      overtime: (map['overtime'] as num?)?.toDouble(),
      netSalary: (map['netSalary'] ?? map['net_salary'] as num?)?.toDouble() ?? 0.0,
      status: status,
      paidDate: parseDt(map['paidDate'] ?? map['paid_date']),
      notes: map['notes'] as String?,
      createdAt: parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      updatedAt: parseDt(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'payPeriodStart': payPeriodStart.millisecondsSinceEpoch,
      'payPeriodEnd': payPeriodEnd.millisecondsSinceEpoch,
      'baseSalary': baseSalary,
      'allowances': allowances,
      'deductions': deductions,
      'bonuses': bonuses,
      'overtime': overtime,
      'netSalary': netSalary,
      'status': status.toString().split('.').last,
      'paidDate': paidDate?.millisecondsSinceEpoch,
      'notes': notes,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

// التدريب
enum TrainingStatus {
  scheduled, // مجدول
  inProgress, // قيد التنفيذ
  completed, // مكتمل
  cancelled, // ملغى
}

class TrainingModel {
  final String id;
  final String title;
  final String? description;
  final String? trainer; // المدرب
  final String? location; // المكان
  final DateTime startDate;
  final DateTime endDate;
  final int? maxParticipants; // الحد الأقصى للمشاركين
  final List<String>? participantIds; // معرفات المشاركين
  final TrainingStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  TrainingModel({
    required this.id,
    required this.title,
    this.description,
    this.trainer,
    this.location,
    required this.startDate,
    required this.endDate,
    this.maxParticipants,
    this.participantIds,
    this.status = TrainingStatus.scheduled,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  factory TrainingModel.fromMap(Map<String, dynamic> map, String id) {
    final statusStr = (map['status'] ?? 'scheduled') as String;

    final status = TrainingStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => TrainingStatus.scheduled,
    );

    List<String>? parseStringList(dynamic v) {
      if (v == null) return null;
      if (v is String) {
        try {
          return List<String>.from(jsonDecode(v) as List);
        } catch (_) {
          return null;
        }
      }
      if (v is List) return v.map((e) => e.toString()).toList();
      return null;
    }

    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is DateTime) return v;
      return null;
    }

    return TrainingModel(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      trainer: map['trainer'] as String?,
      location: map['location'] as String?,
      startDate: parseDt(map['startDate'] ?? map['start_date']) ?? DateTime.now(),
      endDate: parseDt(map['endDate'] ?? map['end_date']) ?? DateTime.now(),
      maxParticipants: (map['maxParticipants'] ?? map['max_participants'] as num?)?.toInt(),
      participantIds: parseStringList(map['participantIds'] ?? map['participant_ids']),
      status: status,
      notes: map['notes'] as String?,
      createdAt: parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      updatedAt: parseDt(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'trainer': trainer,
      'location': location,
      'startDate': startDate.millisecondsSinceEpoch,
      'endDate': endDate.millisecondsSinceEpoch,
      'maxParticipants': maxParticipants,
      'participantIds': participantIds != null ? jsonEncode(participantIds) : null,
      'status': status.toString().split('.').last,
      'notes': notes,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

// الشهادات والتراخيص
enum CertificationStatus {
  active, // نشط
  expired, // منتهي
  pending, // قيد التجديد
  revoked, // ملغى
}

class CertificationModel {
  final String id;
  final String employeeId;
  final String? employeeName;
  final String certificateName; // اسم الشهادة
  final String issuingOrganization; // الجهة المانحة
  final DateTime issueDate; // تاريخ الإصدار
  final DateTime expiryDate; // تاريخ الانتهاء
  final String? certificateNumber; // رقم الشهادة
  final String? certificateUrl; // رابط الشهادة (PDF, Image)
  final CertificationStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CertificationModel({
    required this.id,
    required this.employeeId,
    this.employeeName,
    required this.certificateName,
    required this.issuingOrganization,
    required this.issueDate,
    required this.expiryDate,
    this.certificateNumber,
    this.certificateUrl,
    this.status = CertificationStatus.active,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  factory CertificationModel.fromMap(Map<String, dynamic> map, String id) {
    final statusStr = (map['status'] ?? 'active') as String;

    final status = CertificationStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => CertificationStatus.active,
    );

    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is DateTime) return v;
      return null;
    }

    return CertificationModel(
      id: id,
      employeeId: map['employeeId'] as String? ?? map['employee_id'] as String? ?? '',
      employeeName: map['employeeName'] as String? ?? map['employee_name'] as String?,
      certificateName: map['certificateName'] as String? ?? map['certificate_name'] as String? ?? '',
      issuingOrganization: map['issuingOrganization'] as String? ?? map['issuing_organization'] as String? ?? '',
      issueDate: parseDt(map['issueDate'] ?? map['issue_date']) ?? DateTime.now(),
      expiryDate: parseDt(map['expiryDate'] ?? map['expiry_date']) ?? DateTime.now(),
      certificateNumber: map['certificateNumber'] as String? ?? map['certificate_number'] as String?,
      certificateUrl: map['certificateUrl'] as String? ?? map['certificate_url'] as String?,
      status: status,
      notes: map['notes'] as String?,
      createdAt: parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      updatedAt: parseDt(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'certificateName': certificateName,
      'issuingOrganization': issuingOrganization,
      'issueDate': issueDate.millisecondsSinceEpoch,
      'expiryDate': expiryDate.millisecondsSinceEpoch,
      'certificateNumber': certificateNumber,
      'certificateUrl': certificateUrl,
      'status': status.toString().split('.').last,
      'notes': notes,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

// تقييم الأداء
enum PerformanceRating {
  excellent, // ممتاز
  veryGood, // جيد جداً
  good, // جيد
  satisfactory, // مقبول
  needsImprovement, // يحتاج تحسين
}

class PerformanceReviewModel {
  final String id;
  final String employeeId;
  final String? employeeName;
  final String reviewerId; // من قام بالتقييم
  final String? reviewerName;
  final DateTime reviewDate; // تاريخ التقييم
  final PerformanceRating rating;
  final String? strengths; // نقاط القوة
  final String? weaknesses; // نقاط الضعف
  final String? goals; // الأهداف
  final String? comments; // ملاحظات
  final DateTime createdAt;
  final DateTime? updatedAt;

  PerformanceReviewModel({
    required this.id,
    required this.employeeId,
    this.employeeName,
    required this.reviewerId,
    this.reviewerName,
    required this.reviewDate,
    required this.rating,
    this.strengths,
    this.weaknesses,
    this.goals,
    this.comments,
    required this.createdAt,
    this.updatedAt,
  });

  factory PerformanceReviewModel.fromMap(Map<String, dynamic> map, String id) {
    final ratingStr = (map['rating'] ?? 'good') as String;

    final rating = PerformanceRating.values.firstWhere(
      (e) => e.toString().split('.').last == ratingStr,
      orElse: () => PerformanceRating.good,
    );

    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is DateTime) return v;
      return null;
    }

    return PerformanceReviewModel(
      id: id,
      employeeId: map['employeeId'] as String? ?? map['employee_id'] as String? ?? '',
      employeeName: map['employeeName'] as String? ?? map['employee_name'] as String?,
      reviewerId: map['reviewerId'] as String? ?? map['reviewer_id'] as String? ?? '',
      reviewerName: map['reviewerName'] as String? ?? map['reviewer_name'] as String?,
      reviewDate: parseDt(map['reviewDate'] ?? map['review_date']) ?? DateTime.now(),
      rating: rating,
      strengths: map['strengths'] as String?,
      weaknesses: map['weaknesses'] as String?,
      goals: map['goals'] as String?,
      comments: map['comments'] as String?,
      createdAt: parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      updatedAt: parseDt(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'reviewDate': reviewDate.millisecondsSinceEpoch,
      'rating': rating.toString().split('.').last,
      'strengths': strengths,
      'weaknesses': weaknesses,
      'goals': goals,
      'comments': comments,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

