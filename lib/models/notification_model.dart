enum NotificationType { sms, email }
enum NotificationStatus { scheduled, sent, failed, cancelled }

class NotificationModel {
  final String id;
  final NotificationType type;
  final String recipient;
  final String? subject;
  final String message;
  final DateTime scheduledAt;
  final NotificationStatus status;
  final String? relatedType;
  final String? relatedId;
  final DateTime createdAt;
  final DateTime? sentAt;
  final String? error;

  NotificationModel({
    required this.id,
    required this.type,
    required this.recipient,
    this.subject,
    required this.message,
    required this.scheduledAt,
    required this.status,
    this.relatedType,
    this.relatedId,
    required this.createdAt,
    this.sentAt,
    this.error,
  });

  static DateTime? _parseDt(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is DateTime) return v;
    return null;
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    final typeStr = (map['type'] as String?) ?? 'sms';
    final statusStr = (map['status'] as String?) ?? 'scheduled';
    final type = NotificationType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => NotificationType.sms,
    );
    final status = NotificationStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => NotificationStatus.scheduled,
    );
    return NotificationModel(
      id: id,
      type: type,
      recipient: map['recipient'] as String? ?? '',
      subject: map['subject'] as String?,
      message: map['message'] as String? ?? '',
      scheduledAt: _parseDt(map['scheduledAt'] ?? map['scheduled_at']) ?? DateTime.now(),
      status: status,
      relatedType: map['relatedType'] as String? ?? map['related_type'] as String?,
      relatedId: map['relatedId'] as String? ?? map['related_id'] as String?,
      createdAt: _parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      sentAt: _parseDt(map['sentAt'] ?? map['sent_at']),
      error: map['error'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.toString().split('.').last,
        'recipient': recipient,
        'subject': subject,
        'message': message,
        'scheduledAt': scheduledAt.millisecondsSinceEpoch,
        'status': status.toString().split('.').last,
        'relatedType': relatedType,
        'relatedId': relatedId,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'sentAt': sentAt?.millisecondsSinceEpoch,
        'error': error,
      };
}


