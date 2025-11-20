import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';
import '../database/database_service.dart';
import '../utils/response_helper.dart';
import '../logger/app_logger.dart';

class NotificationsHandler {
  Router get router {
    final router = Router();

    router.get('/', _getNotifications);
    router.get('/<id>', _getNotification);
    router.post('/', _scheduleNotification);
    router.put('/<id>/status', _updateStatus);
    router.delete('/<id>', _cancelNotification);
    router.post('/send-fcm', _sendFCMNotification);

    return router;
  }

  Future<Response> _getNotifications(Request request) async {
    try {
      final params = request.url.queryParameters;
      final status = params['status'];
      final relatedType = params['relatedType'];
      final relatedId = params['relatedId'];

      final conn = await DatabaseService().connection;
      String query = '''
        SELECT id, type, recipient, subject, message, scheduled_at, status, related_type, related_id, created_at, sent_at, error
        FROM notifications WHERE 1=1
      ''';
      final values = <String, dynamic>{};
      if (status != null) { query += ' AND status = @status'; values['status'] = status; }
      if (relatedType != null) { query += ' AND related_type = @relatedType'; values['relatedType'] = relatedType; }
      if (relatedId != null) { query += ' AND related_id = @relatedId'; values['relatedId'] = relatedId; }
      query += ' ORDER BY scheduled_at ASC';

      final rows = await conn.query(query, substitutionValues: values.isEmpty ? null : values);
      final data = rows.map((r) => {
        'id': r[0], 'type': r[1], 'recipient': r[2], 'subject': r[3], 'message': r[4],
        'scheduledAt': r[5], 'status': r[6], 'relatedType': r[7], 'relatedId': r[8],
        'createdAt': r[9], 'sentAt': r[10], 'error': r[11],
      }).toList();
      return ResponseHelper.list(data: data);
    } catch (e) {
      AppLogger.error('Get notifications error', e);
      return ResponseHelper.error(message: 'Failed to get notifications: $e');
    }
  }

  Future<Response> _getNotification(Request request, String id) async {
    try {
      final conn = await DatabaseService().connection;
      final rows = await conn.query(
        '''
        SELECT id, type, recipient, subject, message, scheduled_at, status, related_type, related_id, created_at, sent_at, error
        FROM notifications WHERE id = @id
        ''', substitutionValues: {'id': id});
      if (rows.isEmpty) return ResponseHelper.error(message: 'Notification not found', statusCode: 404);
      final r = rows.first;
      final data = {
        'id': r[0], 'type': r[1], 'recipient': r[2], 'subject': r[3], 'message': r[4],
        'scheduledAt': r[5], 'status': r[6], 'relatedType': r[7], 'relatedId': r[8],
        'createdAt': r[9], 'sentAt': r[10], 'error': r[11],
      };
      return ResponseHelper.success(data: data);
    } catch (e) {
      AppLogger.error('Get notification error', e);
      return ResponseHelper.error(message: 'Failed to get notification: $e');
    }
  }

  Future<Response> _scheduleNotification(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;
      await conn.execute(
        '''
        INSERT INTO notifications (id, type, recipient, subject, message, scheduled_at, status, related_type, related_id, created_at, sent_at, error)
        VALUES (@id, @type, @recipient, @subject, @message, @scheduledAt, @status, @relatedType, @relatedId, @createdAt, @sentAt, @error)
        ''',
        substitutionValues: {
          'id': body['id'],
          'type': body['type'],
          'recipient': body['recipient'],
          'subject': body['subject'],
          'message': body['message'],
          'scheduledAt': body['scheduledAt'],
          'status': body['status'] ?? 'scheduled',
          'relatedType': body['relatedType'],
          'relatedId': body['relatedId'],
          'createdAt': body['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
          'sentAt': null,
          'error': null,
        },
      );
      return ResponseHelper.success(data: {'message': 'Notification scheduled'});
    } catch (e) {
      AppLogger.error('Schedule notification error', e);
      return ResponseHelper.error(message: 'Failed to schedule notification: $e');
    }
  }

  Future<Response> _updateStatus(Request request, String id) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final status = body['status'] as String;
      final error = body['error'];
      final isSent = status == 'sent';
      final conn = await DatabaseService().connection;
      await conn.execute(
        '''
        UPDATE notifications
        SET status = @status, sent_at = @sentAt, error = @error
        WHERE id = @id
        ''',
        substitutionValues: {
          'id': id,
          'status': status,
          'sentAt': isSent ? DateTime.now().millisecondsSinceEpoch : null,
          'error': error,
        },
      );
      return ResponseHelper.success(data: {'message': 'Notification status updated'});
    } catch (e) {
      AppLogger.error('Update notification status error', e);
      return ResponseHelper.error(message: 'Failed to update notification status: $e');
    }
  }

  Future<Response> _cancelNotification(Request request, String id) async {
    try {
      final conn = await DatabaseService().connection;
      await conn.execute(
        "UPDATE notifications SET status = 'cancelled' WHERE id = @id",
        substitutionValues: {'id': id},
      );
      return ResponseHelper.success(data: {'message': 'Notification cancelled'});
    } catch (e) {
      AppLogger.error('Cancel notification error', e);
      return ResponseHelper.error(message: 'Failed to cancel notification: $e');
    }
  }

  Future<Response> _sendFCMNotification(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final userId = body['userId'] as String?;
      final title = body['title'] as String?;
      final message = body['message'] as String?;
      final data = body['data'] as Map<String, dynamic>?;
      
      if (userId == null || title == null || message == null) {
        return ResponseHelper.error(
          message: 'userId, title, and message are required',
          statusCode: 400,
        );
      }

      final conn = await DatabaseService().connection;
      
      // الحصول على FCM Token للمستخدم
      final user = await conn.query(
        'SELECT additional_info FROM users WHERE id = @userId',
        substitutionValues: {'userId': userId},
      );
      
      if (user.isEmpty) {
        return ResponseHelper.error(message: 'User not found', statusCode: 404);
      }

      String? fcmToken;
      final additionalInfo = user.first[0];
      if (additionalInfo != null) {
        Map<String, dynamic> info = {};
        if (additionalInfo is Map) {
          info = Map<String, dynamic>.from(additionalInfo);
        } else if (additionalInfo is String) {
          info = jsonDecode(additionalInfo) as Map<String, dynamic>;
        }
        fcmToken = info['fcmToken'] as String?;
      }

      if (fcmToken == null || fcmToken.isEmpty) {
        return ResponseHelper.error(
          message: 'User does not have FCM token registered',
          statusCode: 400,
        );
      }

      // TODO: إرسال الإشعار عبر Firebase Admin SDK
      // يتطلب تثبيت firebase_admin package في الخادم
      // مثال:
      // await admin.messaging().sendToDevice(
      //   fcmToken,
      //   admin.messaging.Message(
      //     notification: admin.messaging.Notification(
      //       title: title,
      //       body: message,
      //     ),
      //     data: data?.map((k, v) => MapEntry(k.toString(), v.toString())),
      //   ),
      // );

      // حالياً: حفظ الإشعار في قاعدة البيانات
      final notificationId = DateTime.now().millisecondsSinceEpoch.toString();
      await conn.execute(
        '''
        INSERT INTO notifications (id, type, recipient, subject, message, scheduled_at, status, related_type, related_id, created_at, sent_at, error)
        VALUES (@id, 'push', @recipient, @subject, @message, @scheduledAt, 'sent', @relatedType, @relatedId, @createdAt, @sentAt, @error)
        ''',
        substitutionValues: {
          'id': notificationId,
          'recipient': userId,
          'subject': title,
          'message': message,
          'scheduledAt': DateTime.now().millisecondsSinceEpoch,
          'status': 'sent',
          'relatedType': data?['type'],
          'relatedId': data?['id'],
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'sentAt': DateTime.now().millisecondsSinceEpoch,
          'error': null,
        },
      );

      return ResponseHelper.success(data: {
        'message': 'FCM notification sent successfully',
        'notificationId': notificationId,
        'note': 'Firebase Admin SDK integration required for actual push notification',
      });
    } catch (e) {
      AppLogger.error('Send FCM notification error', e);
      return ResponseHelper.error(message: 'Failed to send FCM notification: $e');
    }
  }
}


