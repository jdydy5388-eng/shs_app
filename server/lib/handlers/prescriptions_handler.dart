import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../database/database_service.dart';
import '../config/server_config.dart';
import '../utils/response_helper.dart';
import '../logger/app_logger.dart';

class PrescriptionsHandler {
  Router get router {
    final router = Router();

    router.get('/', _getPrescriptions);
    router.get('/<prescriptionId>', _getPrescription);
    router.post('/', _createPrescription);
    router.put('/<prescriptionId>/status', _updatePrescriptionStatus);

    return router;
  }

  Future<Response> _getPrescriptions(Request request) async {
    try {
      final params = request.url.queryParameters;
      final patientId = params['patientId'];
      final doctorId = params['doctorId'];

      final conn = await DatabaseService().connection;
      
      String query = '''
        SELECT p.id, p.doctor_id, p.doctor_name, p.patient_id, p.patient_name,
               p.diagnosis, p.notes, p.status, p.created_at, p.expires_at
        FROM prescriptions p
        WHERE 1=1
      ''';
      
      final parameters = <String, dynamic>{};
      
      if (patientId != null) {
        query += ' AND p.patient_id = @patientId';
        parameters['patientId'] = patientId;
      }
      
      if (doctorId != null) {
        query += ' AND p.doctor_id = @doctorId';
        parameters['doctorId'] = doctorId;
      }
      
      query += ' ORDER BY p.created_at DESC';

      final prescriptions = await conn.query(
        query,
        substitutionValues: parameters.isEmpty ? null : parameters,
      );

      final result = <Map<String, dynamic>>[];
      
      for (final prescription in prescriptions) {
        final prescriptionId = prescription[0] as String;
        
        // جلب الأدوية
        final medications = await conn.query(
          '''
          SELECT id, name, dosage, frequency, duration, instructions, quantity
          FROM prescription_medications
          WHERE prescription_id = @prescriptionId
          ''',
          substitutionValues: {'prescriptionId': prescriptionId},
        );

        // جلب التفاعلات الدوائية
        final interactions = await conn.query(
          '''
          SELECT interaction
          FROM prescription_drug_interactions
          WHERE prescription_id = @prescriptionId
          ''',
          substitutionValues: {'prescriptionId': prescriptionId},
        );

        result.add({
          'id': prescription[0],
          'doctorId': prescription[1],
          'doctorName': prescription[2],
          'patientId': prescription[3],
          'patientName': prescription[4],
          'diagnosis': prescription[5],
          'notes': prescription[6],
          'status': prescription[7],
          'createdAt': prescription[8],
          'expiresAt': prescription[9],
          'medications': medications.map((m) => {
            'id': m[0],
            'name': m[1],
            'dosage': m[2],
            'frequency': m[3],
            'duration': m[4],
            'instructions': m[5],
            'quantity': m[6],
          }).toList(),
          'drugInteractions': interactions.map((i) => i[0]).toList(),
        });
      }

      return ResponseHelper.list(data: result);
    } catch (e) {
      AppLogger.error('Get prescriptions error', e);
      return ResponseHelper.error(message: 'Failed to get prescriptions: $e');
    }
  }

  Future<Response> _getPrescription(Request request, String prescriptionId) async {
    try {
      final conn = await DatabaseService().connection;
      
      final prescription = await conn.query(
        '''
        SELECT id, doctor_id, doctor_name, patient_id, patient_name,
               diagnosis, notes, status, created_at, expires_at
        FROM prescriptions
        WHERE id = @id
        ''',
        substitutionValues: {'id': prescriptionId},
      );

      if (prescription.isEmpty) {
        return ResponseHelper.error(
          message: 'Prescription not found',
          statusCode: 404,
        );
      }

      final p = prescription.first;

      // جلب الأدوية
      final medications = await conn.query(
        '''
        SELECT id, name, dosage, frequency, duration, instructions, quantity
        FROM prescription_medications
        WHERE prescription_id = @prescriptionId
        ''',
        substitutionValues: {'prescriptionId': prescriptionId},
      );

      // جلب التفاعلات الدوائية
      final interactions = await conn.query(
        '''
        SELECT interaction
        FROM prescription_drug_interactions
        WHERE prescription_id = @prescriptionId
        ''',
        substitutionValues: {'prescriptionId': prescriptionId},
      );

      return ResponseHelper.success(data: {
        'id': p[0],
        'doctorId': p[1],
        'doctorName': p[2],
        'patientId': p[3],
        'patientName': p[4],
        'diagnosis': p[5],
        'notes': p[6],
        'status': p[7],
        'createdAt': p[8],
        'expiresAt': p[9],
        'medications': medications.map((m) => {
          'id': m[0],
          'name': m[1],
          'dosage': m[2],
          'frequency': m[3],
          'duration': m[4],
          'instructions': m[5],
          'quantity': m[6],
        }).toList(),
        'drugInteractions': interactions.map((i) => i[0]).toList(),
      });
    } catch (e) {
      AppLogger.error('Get prescription error', e);
      return ResponseHelper.error(message: 'Failed to get prescription: $e');
    }
  }

  Future<Response> _createPrescription(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final conn = await DatabaseService().connection;

      await conn.transaction((ctx) async {
        // إنشاء الوصفة
        await ctx.execute(
          '''
          INSERT INTO prescriptions (id, doctor_id, doctor_name, patient_id, patient_name,
                                    diagnosis, notes, status, created_at, expires_at)
          VALUES (@id, @doctorId, @doctorName, @patientId, @patientName,
                  @diagnosis, @notes, @status, @createdAt, @expiresAt)
          ''',
          substitutionValues: {
            'id': body['id'],
            'doctorId': body['doctorId'],
            'doctorName': body['doctorName'],
            'patientId': body['patientId'],
            'patientName': body['patientName'],
            'diagnosis': body['diagnosis'],
            'notes': body['notes'],
            'status': body['status'],
            'createdAt': body['createdAt'],
            'expiresAt': body['expiresAt'],
          },
        );

        // إضافة الأدوية
        final medications = body['medications'] as List;
        for (final med in medications) {
          await ctx.execute(
            '''
            INSERT INTO prescription_medications 
            (id, prescription_id, name, dosage, frequency, duration, instructions, quantity)
            VALUES (@id, @prescriptionId, @name, @dosage, @frequency, @duration, @instructions, @quantity)
            ''',
            substitutionValues: {
              'id': med['id'],
              'prescriptionId': body['id'],
              'name': med['name'],
              'dosage': med['dosage'],
              'frequency': med['frequency'],
              'duration': med['duration'],
              'instructions': med['instructions'] ?? '',
              'quantity': med['quantity'],
            },
          );
        }

        // إضافة التفاعلات الدوائية
        if (body['drugInteractions'] != null) {
          final interactions = body['drugInteractions'] as List;
          for (final interaction in interactions) {
            await ctx.execute(
              '''
              INSERT INTO prescription_drug_interactions (prescription_id, interaction)
              VALUES (@prescriptionId, @interaction)
              ''',
              substitutionValues: {
                'prescriptionId': body['id'],
                'interaction': interaction,
              },
            );
          }
        }
      });

      return ResponseHelper.success(data: {'message': 'Prescription created successfully'});
    } catch (e) {
      AppLogger.error('Create prescription error', e);
      return ResponseHelper.error(message: 'Failed to create prescription: $e');
    }
  }

  Future<Response> _updatePrescriptionStatus(Request request, String prescriptionId) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final status = body['status'] as String;

      final conn = await DatabaseService().connection;
      
      await conn.execute(
        '''
        UPDATE prescriptions 
        SET status = @status
        WHERE id = @id
        ''',
        substitutionValues: {
          'id': prescriptionId,
          'status': status,
        },
      );

      return ResponseHelper.success(data: {'message': 'Prescription status updated'});
    } catch (e) {
      AppLogger.error('Update prescription status error', e);
      return ResponseHelper.error(message: 'Failed to update prescription status: $e');
    }
  }

  // إرسال إشعارات عند إنشاء وصفة طبية
  Future<void> _sendPrescriptionNotifications({
    required String prescriptionId,
    required String doctorId,
    required String doctorName,
    required String patientId,
    required String patientName,
  }) async {
    try {
      final conn = await DatabaseService().connection;
      
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
            title: 'وصفة طبية جديدة',
            message: 'لديك وصفة طبية جديدة من د. $doctorName',
            data: {
              'type': 'prescription',
              'id': prescriptionId,
            },
          );
        }
      }

      // إرسال إشعار للصيدلي (pharmacist)
      final pharmacists = await conn.query(
        'SELECT id, additional_info FROM users WHERE role = @role',
        substitutionValues: {'role': 'pharmacist'},
      );

      for (final pharm in pharmacists) {
        final pharmId = pharm[0] as String;
        final additionalInfo = pharm[1];
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
            title: 'وصفة طبية جديدة',
            message: 'وصفة طبية جديدة للمريض $patientName من د. $doctorName',
            data: {
              'type': 'prescription',
              'id': prescriptionId,
            },
          );
        }
      }
    } catch (e) {
      AppLogger.error('Error sending prescription notifications', e);
    }
  }

  // إرسال إشعار Firebase
  Future<void> _sendFCMNotification({
    required String fcmToken,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      final serverConfig = ServerConfig();
      final serverKey = serverConfig.firebaseServerKey;
      
      if (serverKey == null || serverKey.isEmpty) {
        AppLogger.warning('FIREBASE_SERVER_KEY not configured');
        return;
      }

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
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        AppLogger.info('FCM notification sent: $title');
      } else {
        AppLogger.error('FCM notification failed', 'HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      AppLogger.error('FCM notification error', e);
    }
  }
}

