import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/integration_models.dart';
import '../models/hl7_fhir_models.dart';
import '../models/lab_request_model.dart';
import '../models/prescription_model.dart';
import '../services/encryption_service.dart';
import '../config/app_config.dart';

/// خدمة التكامل مع الأنظمة الخارجية
class ExternalIntegrationService {
  final EncryptionService _encryptionService = EncryptionService();

  /// إرسال طلب فحص مختبر إلى مختبر خارجي
  Future<bool> sendLabRequestToExternalLab({
    required ExternalIntegrationModel integration,
    required LabRequestModel labRequest,
  }) async {
    try {
      await _encryptionService.initialize();
      
      // فك تشفير API key و secret
      final apiKey = integration.apiKey != null
          ? _encryptionService.decryptText(integration.apiKey!)
          : null;
      final apiSecret = integration.apiSecret != null
          ? _encryptionService.decryptText(integration.apiSecret!)
          : null;

      if (integration.apiUrl == null || apiKey == null) {
        throw Exception('API URL or API Key missing');
      }

      // تحويل إلى تنسيق HL7/FHIR
      final hl7LabRequest = {
        'resourceType': 'ServiceRequest',
        'id': labRequest.id,
        'status': 'active',
        'intent': 'order',
        'code': {
          'coding': [
            {
              'system': 'http://loinc.org',
              'code': labRequest.testType,
              'display': labRequest.testType,
            }
          ],
          'text': labRequest.testType,
        },
        'subject': {
          'reference': 'Patient/${labRequest.patientId}',
        },
        'requester': {
          'reference': 'Practitioner/${labRequest.doctorId}',
        },
        'authoredOn': labRequest.requestedAt.toIso8601String(),
        'note': labRequest.notes != null
            ? [
                {
                  'text': labRequest.notes,
                }
              ]
            : null,
      };

      // إرسال الطلب
      final response = await http.post(
        Uri.parse('${integration.apiUrl}/lab-requests'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          if (apiSecret != null) 'X-API-Secret': apiSecret,
        },
        body: jsonEncode(hl7LabRequest),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        throw Exception('Failed to send lab request: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error sending lab request to external lab: $e');
      return false;
    }
  }

  /// استقبال نتائج فحص من مختبر خارجي
  Future<List<HL7LabResultModel>> receiveLabResultsFromExternalLab({
    required ExternalIntegrationModel integration,
    String? patientId,
    DateTime? since,
  }) async {
    try {
      await _encryptionService.initialize();
      
      final apiKey = integration.apiKey != null
          ? _encryptionService.decryptText(integration.apiKey!)
          : null;

      if (integration.apiUrl == null || apiKey == null) {
        throw Exception('API URL or API Key missing');
      }

      final queryParams = <String, String>{};
      if (patientId != null) queryParams['patientId'] = patientId;
      if (since != null) queryParams['since'] = since.toIso8601String();

      final uri = Uri.parse('${integration.apiUrl}/lab-results')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $apiKey',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = (data['results'] as List? ?? [])
            .map((r) => HL7LabResultModel.fromMap(r as Map<String, dynamic>))
            .toList();
        return results;
      } else {
        throw Exception('Failed to receive lab results: ${response.statusCode}');
      }
    } catch (e) {
      print('Error receiving lab results from external lab: $e');
      return [];
    }
  }

  /// إرسال طلب دفع إلى البنك
  Future<bool> sendPaymentRequestToBank({
    required ExternalIntegrationModel integration,
    required String invoiceId,
    required double amount,
    required String patientId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      await _encryptionService.initialize();
      
      final apiKey = integration.apiKey != null
          ? _encryptionService.decryptText(integration.apiKey!)
          : null;

      if (integration.apiUrl == null || apiKey == null) {
        throw Exception('API URL or API Key missing');
      }

      final paymentRequest = {
        'invoiceId': invoiceId,
        'amount': amount,
        'patientId': patientId,
        'timestamp': DateTime.now().toIso8601String(),
        if (additionalData != null) ...additionalData,
      };

      final response = await http.post(
        Uri.parse('${integration.apiUrl}/payment-requests'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(paymentRequest),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        throw Exception('Failed to send payment request: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending payment request to bank: $e');
      return false;
    }
  }

  /// استقبال حالة الدفع من البنك
  Future<Map<String, dynamic>?> getPaymentStatusFromBank({
    required ExternalIntegrationModel integration,
    required String paymentId,
  }) async {
    try {
      await _encryptionService.initialize();
      
      final apiKey = integration.apiKey != null
          ? _encryptionService.decryptText(integration.apiKey!)
          : null;

      if (integration.apiUrl == null || apiKey == null) {
        throw Exception('API URL or API Key missing');
      }

      final response = await http.get(
        Uri.parse('${integration.apiUrl}/payment-status/$paymentId'),
        headers: {
          'Authorization': 'Bearer $apiKey',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get payment status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting payment status from bank: $e');
      return null;
    }
  }

  /// تحويل بيانات المريض إلى تنسيق HL7/FHIR
  Map<String, dynamic> convertPatientToFHIR(Map<String, dynamic> patientData) {
    return HL7PatientModel(
      id: patientData['id'] as String? ?? '',
      identifier: patientData['id'] as String?,
      name: patientData['name'] as String?,
      gender: patientData['gender'] as String?,
      birthDate: patientData['birthDate'] != null
          ? DateTime.parse(patientData['birthDate'] as String)
          : null,
      address: patientData['address'] as String?,
      phone: patientData['phone'] as String?,
      email: patientData['email'] as String?,
    ).toFHIR();
  }

  /// تحويل وصفة طبية إلى تنسيق HL7/FHIR
  Map<String, dynamic> convertPrescriptionToFHIR(PrescriptionModel prescription) {
    return HL7MedicationRequestModel(
      id: prescription.id,
      patientId: prescription.patientId,
      medicationName: prescription.medications.isNotEmpty
          ? prescription.medications.first.name
          : null,
      medicationCode: prescription.medications.isNotEmpty
          ? prescription.medications.first.name
          : null,
      dosage: prescription.medications.isNotEmpty
          ? prescription.medications.first.dosage
          : null,
      frequency: prescription.medications.isNotEmpty
          ? prescription.medications.first.frequency
          : null,
      authoredOn: prescription.createdAt,
      status: 'active',
    ).toFHIR();
  }
}

