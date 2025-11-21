import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../database/database_service.dart';
import '../config/server_config.dart';
import '../utils/response_helper.dart';
import '../utils/firebase_auth_helper.dart';
import '../logger/app_logger.dart';

class LabRequestsHandler {
  Router get router {
    final router = Router();

    router.get('/', _getLabRequests);
    router.get('/<requestId>', _getLabRequest);
    router.post('/', _createLabRequest);
    router.put('/<requestId>', _updateLabRequest);
    router.delete('/<requestId>', _deleteLabRequest);

    return router;
  }

  Future<Response> _getLabRequests(Request request) async {
    try {
      final params = request.url.queryParameters;
      final doctorId = params['doctorId'];
      final patientId = params['patientId'];
      final status = params['status'];

      final conn = await DatabaseService().connection;
      
      String query = '''
        SELECT id, doctor_id, patient_id, patient_name, test_type, status, notes,
               result_notes, result_attachments, requested_at, completed_at
        FROM lab_requests
        WHERE 1=1
      ''';
      
      final parameters = <String, dynamic>{};
      
      if (doctorId != null) {
        query += ' AND doctor_id = @doctorId';
        parameters['doctorId'] = doctorId;
      }
      
      if (patientId != null) {
        query += ' AND patient_id = @patientId';
        parameters['patientId'] = patientId;
      }
      
      if (status != null) {
        query += ' AND status = @status';
        parameters['status'] = status;
      }
      
      query += ' ORDER BY requested_at DESC';

      final requests = await conn.query(
        query,
        substitutionValues: parameters.isEmpty ? null : parameters,
      );

      final result = requests.map((req) => {
        'id': req[0],
        'doctorId': req[1],
        'patientId': req[2],
        'patientName': req[3],
        'testType': req[4],
        'status': req[5],
        'notes': req[6],
        'resultNotes': req[7],
        'resultAttachments': req[8] != null ? jsonDecode(req[8] as String) : null,
        'requestedAt': req[9],
        'completedAt': req[10],
      }).toList();

      return ResponseHelper.list(data: result);
    } catch (e) {
      AppLogger.error('Get lab requests error', e);
      return ResponseHelper.error(message: 'Failed to get lab requests: $e');
    }
  }

  Future<Response> _getLabRequest(Request request, String requestId) async {
    try {
      final conn = await DatabaseService().connection;
      
      final req = await conn.query(
        '''
        SELECT id, doctor_id, patient_id, patient_name, test_type, status, notes,
               result_notes, result_attachments, requested_at, completed_at
        FROM lab_requests
        WHERE id = @id
        ''',
        substitutionValues: {'id': requestId},
      );

      if (req.isEmpty) {
        return ResponseHelper.error(
          message: 'Lab request not found',
          statusCode: 404,
        );
      }

      final r = req.first;
      return ResponseHelper.success(data: {
        'id': r[0],
        'doctorId': r[1],
        'patientId': r[2],
        'patientName': r[3],
        'testType': r[4],
        'status': r[5],
        'notes': r[6],
        'resultNotes': r[7],
        'resultAttachments': r[8] != null ? jsonDecode(r[8] as String) : null,
        'requestedAt': r[9],
        'completedAt': r[10],
      });
    } catch (e) {
      AppLogger.error('Get lab request error', e);
      return ResponseHelper.error(message: 'Failed to get lab request: $e');
    }
  }

  Future<Response> _createLabRequest(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      await conn.execute(
        '''
        INSERT INTO lab_requests 
        (id, doctor_id, patient_id, patient_name, test_type, status, notes,
         result_notes, result_attachments, requested_at, completed_at)
        VALUES (@id, @doctorId, @patientId, @patientName, @testType, @status, @notes,
                @resultNotes, @resultAttachments, @requestedAt, @completedAt)
        ''',
        substitutionValues: {
          'id': body['id'],
          'doctorId': body['doctorId'],
          'patientId': body['patientId'],
          'patientName': body['patientName'],
          'testType': body['testType'],
          'status': body['status'],
          'notes': body['notes'],
          'resultNotes': body['resultNotes'],
          'resultAttachments': body['resultAttachments'] != null 
              ? jsonEncode(body['resultAttachments']) 
              : null,
          'requestedAt': body['requestedAt'],
          'completedAt': body['completedAt'],
        },
      );

      // إرسال إشعارات تلقائية (غير متزامن - لا ننتظر)
      _sendLabRequestNotifications(
        labRequestId: body['id'] as String,
        doctorId: body['doctorId'] as String,
        patientId: body['patientId'] as String,
        patientName: body['patientName'] as String,
        testType: body['testType'] as String,
      ).catchError((e) {
        AppLogger.error('Error in async lab request notifications', e);
      });

      return ResponseHelper.success(data: {'message': 'Lab request created successfully'});
    } catch (e) {
      AppLogger.error('Create lab request error', e);
      return ResponseHelper.error(message: 'Failed to create lab request: $e');
    }
  }

  Future<Response> _updateLabRequest(Request request, String requestId) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      final updates = <String, dynamic>{};
      if (body.containsKey('status')) updates['status'] = body['status'];
      if (body.containsKey('resultNotes')) updates['resultNotes'] = body['resultNotes'];
      if (body.containsKey('resultAttachments')) {
        updates['resultAttachments'] = jsonEncode(body['resultAttachments']);
      }
      if (body.containsKey('completedAt')) updates['completedAt'] = body['completedAt'];

      if (updates.isEmpty) {
        return ResponseHelper.error(message: 'No fields to update');
      }

      final setClause = updates.keys.map((k) => '$k = @$k').join(', ');
      
      // الحصول على بيانات الطلب قبل التحديث
      final oldRequest = await conn.query(
        'SELECT doctor_id, patient_id, patient_name, test_type, status FROM lab_requests WHERE id = @id',
        substitutionValues: {'id': requestId},
      );
      
      if (oldRequest.isEmpty) {
        return ResponseHelper.error(message: 'Lab request not found', statusCode: 404);
      }
      
      final oldStatus = oldRequest.first[4] as String;
      final newStatus = updates['status'] as String?;
      
      await conn.execute(
        '''
        UPDATE lab_requests 
        SET $setClause
        WHERE id = @id
        ''',
        substitutionValues: {
          'id': requestId,
          ...updates,
        },
      );

      // إرسال إشعارات عند إكمال الفحص
      if (newStatus == 'completed' && oldStatus != 'completed') {
        _sendLabCompletedNotifications(
          labRequestId: requestId,
          doctorId: oldRequest.first[0] as String,
          patientId: oldRequest.first[1] as String,
          patientName: oldRequest.first[2] as String,
          testType: oldRequest.first[3] as String,
        );
      }

      return ResponseHelper.success(data: {'message': 'Lab request updated successfully'});
    } catch (e) {
      AppLogger.error('Update lab request error', e);
      return ResponseHelper.error(message: 'Failed to update lab request: $e');
    }
  }

  Future<Response> _deleteLabRequest(Request request, String requestId) async {
    try {
      final conn = await DatabaseService().connection;
      
      await conn.execute(
        'DELETE FROM lab_requests WHERE id = @id',
        substitutionValues: {'id': requestId},
      );

      return ResponseHelper.success(data: {'message': 'Lab request deleted successfully'});
    } catch (e) {
      AppLogger.error('Delete lab request error', e);
      return ResponseHelper.error(message: 'Failed to delete lab request: $e');
    }
  }

  // إرسال إشعارات عند إنشاء طلب فحص جديد
  Future<void> _sendLabRequestNotifications({
    required String labRequestId,
    required String doctorId,
    required String patientId,
    required String patientName,
    required String testType,
  }) async {
    try {
      final conn = await DatabaseService().connection;
      
      // الحصول على اسم الطبيب
      final doctor = await conn.query(
        'SELECT name, additional_info FROM users WHERE id = @doctorId',
        substitutionValues: {'doctorId': doctorId},
      );

      String doctorName = 'الطبيب';
      if (doctor.isNotEmpty) {
        doctorName = doctor.first[0] as String? ?? 'الطبيب';
      }

      // إرسال إشعار للمختبر
      final labTechnicians = await conn.query(
        'SELECT id, name, additional_info FROM users WHERE role = @role',
        substitutionValues: {'role': 'lab_technician'},
      );

      for (final tech in labTechnicians) {
        final techId = tech[0] as String;
        final additionalInfo = tech[2];
        String? fcmToken;
        
        if (additionalInfo != null) {
          Map<String, dynamic> info = {};
          if (additionalInfo is Map) {
            info = Map<String, dynamic>.from(additionalInfo);
          } else if (additionalInfo is String) {
            info = jsonDecode(additionalInfo) as Map<String, dynamic>;
          }
          fcmToken = info['fcmToken'] as String?;
        }

        if (fcmToken != null && fcmToken.isNotEmpty) {
          await _sendFCMNotification(
            fcmToken: fcmToken,
            title: 'طلب فحص جديد',
            message: 'طلب فحص $testType للمريض $patientName من د. $doctorName',
            data: {
              'type': 'lab_request',
              'id': labRequestId,
            },
          );
        }
      }

      // إرسال إشعار للمريض
      final patient = await conn.query(
        'SELECT additional_info FROM users WHERE id = @patientId',
        substitutionValues: {'patientId': patientId},
      );

      if (patient.isNotEmpty) {
        final additionalInfo = patient.first[0];
        String? fcmToken;
        
        if (additionalInfo != null) {
          Map<String, dynamic> info = {};
          if (additionalInfo is Map) {
            info = Map<String, dynamic>.from(additionalInfo);
          } else if (additionalInfo is String) {
            info = jsonDecode(additionalInfo) as Map<String, dynamic>;
          }
          fcmToken = info['fcmToken'] as String?;
        }

        if (fcmToken != null && fcmToken.isNotEmpty) {
          AppLogger.info('Sending lab request notification to patient $patientId');
          await _sendFCMNotification(
            fcmToken: fcmToken,
            title: 'طلب فحص جديد',
            message: 'تم إرسال طلب فحص $testType لك من د. $doctorName',
            data: {
              'type': 'lab_request',
              'id': labRequestId,
            },
          );
          AppLogger.info('Lab request notification sent to patient $patientId');
        } else {
          AppLogger.warning('Patient $patientId does not have FCM token - notification not sent');
        }
      }
    } catch (e) {
      AppLogger.error('Error sending lab request notifications', e);
    }
  }

  // إرسال إشعارات عند إكمال الفحص
  Future<void> _sendLabCompletedNotifications({
    required String labRequestId,
    required String doctorId,
    required String patientId,
    required String patientName,
    required String testType,
  }) async {
    try {
      final conn = await DatabaseService().connection;
      
      // إرسال إشعار للطبيب
      final doctor = await conn.query(
        'SELECT additional_info FROM users WHERE id = @doctorId',
        substitutionValues: {'doctorId': doctorId},
      );

      if (doctor.isNotEmpty) {
        final additionalInfo = doctor.first[0];
        String? fcmToken;
        
        if (additionalInfo != null) {
          Map<String, dynamic> info = {};
          if (additionalInfo is Map) {
            info = Map<String, dynamic>.from(additionalInfo);
          } else if (additionalInfo is String) {
            info = jsonDecode(additionalInfo) as Map<String, dynamic>;
          }
          fcmToken = info['fcmToken'] as String?;
        }

        if (fcmToken != null && fcmToken.isNotEmpty) {
          await _sendFCMNotification(
            fcmToken: fcmToken,
            title: 'تم إكمال الفحص',
            message: 'تم إكمال فحص $testType للمريض $patientName',
            data: {
              'type': 'lab_result',
              'id': labRequestId,
            },
          );
        }
      }

      // إرسال إشعار للمريض
      final patient = await conn.query(
        'SELECT additional_info FROM users WHERE id = @patientId',
        substitutionValues: {'patientId': patientId},
      );

      if (patient.isNotEmpty) {
        final additionalInfo = patient.first[0];
        String? fcmToken;
        
        if (additionalInfo != null) {
          Map<String, dynamic> info = {};
          if (additionalInfo is Map) {
            info = Map<String, dynamic>.from(additionalInfo);
          } else if (additionalInfo is String) {
            info = jsonDecode(additionalInfo) as Map<String, dynamic>;
          }
          fcmToken = info['fcmToken'] as String?;
        }

        if (fcmToken != null && fcmToken.isNotEmpty) {
          await _sendFCMNotification(
            fcmToken: fcmToken,
            title: 'نتائج الفحص جاهزة',
            message: 'نتائج فحص $testType جاهزة',
            data: {
              'type': 'lab_result',
              'id': labRequestId,
            },
          );
        }
      }
    } catch (e) {
      AppLogger.error('Error sending lab completed notifications', e);
    }
  }

  // إرسال إشعار FCM
  Future<void> _sendFCMNotification({
    required String fcmToken,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      final serverConfig = ServerConfig();
      final projectId = serverConfig.firebaseProjectId;
      
      // محاولة استخدام V1 API أولاً
      String? accessToken = await FirebaseAuthHelper.getAccessToken();
      
      if (accessToken != null && projectId != null) {
        // استخدام V1 API
        final fcmUrl = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';
        
        // بناء payload حسب V1 API format
        final messagePayload = <String, dynamic>{
          'token': fcmToken,
          'notification': {
            'title': title,
            'body': message,
          },
        };
        
        // إضافة data (يجب أن تكون strings في V1 API)
        if (data != null && data.isNotEmpty) {
          final dataMap = <String, String>{};
          data.forEach((key, value) {
            // في V1 API، يجب تحويل JSON nested إلى string
            if (value is Map || value is List) {
              dataMap[key.toString()] = jsonEncode(value);
            } else {
              dataMap[key.toString()] = value.toString();
            }
          });
          messagePayload['data'] = dataMap;
        }
        
        final payload = <String, dynamic>{
          'message': messagePayload,
        };
        
        final response = await http.post(
          Uri.parse(fcmUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode(payload),
        );
        
        if (response.statusCode == 200) {
          AppLogger.info('FCM V1 notification sent successfully');
        } else {
          final errorBody = response.body;
          AppLogger.error('FCM V1 notification HTTP error: HTTP ${response.statusCode}: $errorBody', null);
        }
      } else {
        // Fallback to Legacy API إذا كان متاحاً
        final serverKey = serverConfig.firebaseServerKey;
        
        if (serverKey == null || serverKey.isEmpty) {
          AppLogger.warning('Neither V1 API nor Legacy API configured - notification not sent');
        } else {
          // استخدام Legacy API (fallback)
          final fcmUrl = 'https://fcm.googleapis.com/fcm/send';
          
          final payload = <String, dynamic>{
            'to': fcmToken,
            'notification': {
              'title': title,
              'body': message,
              'sound': 'default',
            },
          };
          
          if (data != null && data.isNotEmpty) {
            payload['data'] = data.map((k, v) => MapEntry(k.toString(), v.toString()));
          }
          
          final response = await http.post(
            Uri.parse(fcmUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'key=$serverKey',
            },
            body: jsonEncode(payload),
          );
          
          if (response.statusCode == 200) {
            final responseData = jsonDecode(response.body) as Map<String, dynamic>;
            if (responseData['success'] == 1) {
              AppLogger.info('FCM Legacy notification sent successfully');
            } else {
              final error = responseData['results']?[0]?['error']?.toString() ?? 'Unknown error';
              AppLogger.error('FCM Legacy notification failed: $error', null);
            }
          } else {
            AppLogger.error('FCM Legacy notification HTTP error: HTTP ${response.statusCode}: ${response.body}', null);
          }
        }
      }
    } catch (e) {
      AppLogger.error('FCM notification error', e);
    }
  }
}

