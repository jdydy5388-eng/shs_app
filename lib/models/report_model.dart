import 'dart:convert';

class ReportModel {
  final String id;
  final String title;
  final ReportType type;
  final DateTime fromDate;
  final DateTime toDate;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final String? createdBy;

  ReportModel({
    required this.id,
    required this.title,
    required this.type,
    required this.fromDate,
    required this.toDate,
    required this.data,
    required this.createdAt,
    this.createdBy,
  });

  factory ReportModel.fromMap(Map<String, dynamic> map, String id) {
    final typeStr = (map['type'] ?? 'statistical') as String;
    final type = ReportType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => ReportType.statistical,
    );

    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is DateTime) return v;
      return null;
    }

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

    return ReportModel(
      id: id,
      title: map['title'] as String? ?? '',
      type: type,
      fromDate: parseDt(map['fromDate'] ?? map['from_date']) ?? DateTime.now(),
      toDate: parseDt(map['toDate'] ?? map['to_date']) ?? DateTime.now(),
      data: parseJson(map['data']) ?? {},
      createdAt: parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      createdBy: map['createdBy'] as String? ?? map['created_by'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type.toString().split('.').last,
      'fromDate': fromDate.millisecondsSinceEpoch,
      'toDate': toDate.millisecondsSinceEpoch,
      'data': jsonEncode(data),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'createdBy': createdBy,
    };
  }
}

enum ReportType {
  statistical, // إحصائي
  performance, // أداء
  quality, // جودة
  financial, // مالي
  operational, // تشغيلي
}

class DashboardStats {
  final int totalPatients;
  final int totalDoctors;
  final int totalAppointments;
  final int totalPrescriptions;
  final double totalRevenue;
  final int occupiedBeds;
  final int totalBeds;
  final int pendingLabRequests;
  final int completedLabRequests;
  final int emergencyCases;
  final int activeSurgeries;

  DashboardStats({
    required this.totalPatients,
    required this.totalDoctors,
    required this.totalAppointments,
    required this.totalPrescriptions,
    required this.totalRevenue,
    required this.occupiedBeds,
    required this.totalBeds,
    required this.pendingLabRequests,
    required this.completedLabRequests,
    required this.emergencyCases,
    required this.activeSurgeries,
  });

  double get bedOccupancyRate {
    if (totalBeds == 0) return 0.0;
    return (occupiedBeds / totalBeds) * 100;
  }

  double get labCompletionRate {
    final total = pendingLabRequests + completedLabRequests;
    if (total == 0) return 0.0;
    return (completedLabRequests / total) * 100;
  }
}

class PerformanceReport {
  final String userId;
  final String userName;
  final String userRole;
  final int totalAppointments;
  final int completedAppointments;
  final int totalPrescriptions;
  final int totalLabRequests;
  final double averageRating;
  final DateTime reportDate;

  PerformanceReport({
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.totalAppointments,
    required this.completedAppointments,
    required this.totalPrescriptions,
    required this.totalLabRequests,
    required this.averageRating,
    required this.reportDate,
  });

  double get appointmentCompletionRate {
    if (totalAppointments == 0) return 0.0;
    return (completedAppointments / totalAppointments) * 100;
  }
}

class QualityReport {
  final String category;
  final int totalCases;
  final int compliantCases;
  final int nonCompliantCases;
  final Map<String, dynamic> metrics;
  final DateTime reportDate;

  QualityReport({
    required this.category,
    required this.totalCases,
    required this.compliantCases,
    required this.nonCompliantCases,
    required this.metrics,
    required this.reportDate,
  });

  double get complianceRate {
    if (totalCases == 0) return 0.0;
    return (compliantCases / totalCases) * 100;
  }
}

