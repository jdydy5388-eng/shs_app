import 'dart:convert';

/// نموذج HL7/FHIR للمريض
class HL7PatientModel {
  final String id;
  final String? identifier; // معرف المريض
  final String? name; // الاسم
  final String? gender; // الجنس (male, female, other)
  final DateTime? birthDate; // تاريخ الميلاد
  final String? address; // العنوان
  final String? phone; // الهاتف
  final String? email; // البريد الإلكتروني

  HL7PatientModel({
    required this.id,
    this.identifier,
    this.name,
    this.gender,
    this.birthDate,
    this.address,
    this.phone,
    this.email,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'identifier': identifier,
      'name': name,
      'gender': gender,
      'birthDate': birthDate?.toIso8601String(),
      'address': address,
      'phone': phone,
      'email': email,
    };
  }

  factory HL7PatientModel.fromMap(Map<String, dynamic> map) {
    return HL7PatientModel(
      id: map['id'] as String? ?? '',
      identifier: map['identifier'] as String?,
      name: map['name'] as String?,
      gender: map['gender'] as String?,
      birthDate: map['birthDate'] != null
          ? DateTime.parse(map['birthDate'] as String)
          : null,
      address: map['address'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
    );
  }

  /// تحويل إلى تنسيق FHIR JSON
  Map<String, dynamic> toFHIR() {
    return {
      'resourceType': 'Patient',
      'id': id,
      'identifier': identifier != null
          ? [
              {
                'system': 'http://hospital.example.org/patients',
                'value': identifier,
              }
            ]
          : null,
      'name': name != null
          ? [
              {
                'text': name,
              }
            ]
          : null,
      'gender': gender,
      'birthDate': birthDate?.toIso8601String().split('T')[0],
      'address': address != null
          ? [
              {
                'text': address,
              }
            ]
          : null,
      'telecom': [
        if (phone != null)
          {
            'system': 'phone',
            'value': phone,
          },
        if (email != null)
          {
            'system': 'email',
            'value': email,
          },
      ],
    };
  }
}

/// نموذج HL7/FHIR للفحص المختبر
class HL7LabResultModel {
  final String id;
  final String patientId; // معرف المريض
  final String? testName; // اسم الفحص
  final String? testCode; // كود الفحص
  final String? result; // النتيجة
  final String? unit; // الوحدة
  final String? referenceRange; // المدى المرجعي
  final DateTime? effectiveDateTime; // تاريخ ووقت الفحص
  final String? status; // الحالة (final, preliminary, etc.)

  HL7LabResultModel({
    required this.id,
    required this.patientId,
    this.testName,
    this.testCode,
    this.result,
    this.unit,
    this.referenceRange,
    this.effectiveDateTime,
    this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'testName': testName,
      'testCode': testCode,
      'result': result,
      'unit': unit,
      'referenceRange': referenceRange,
      'effectiveDateTime': effectiveDateTime?.toIso8601String(),
      'status': status,
    };
  }

  factory HL7LabResultModel.fromMap(Map<String, dynamic> map) {
    return HL7LabResultModel(
      id: map['id'] as String? ?? '',
      patientId: map['patientId'] as String? ?? '',
      testName: map['testName'] as String?,
      testCode: map['testCode'] as String?,
      result: map['result'] as String?,
      unit: map['unit'] as String?,
      referenceRange: map['referenceRange'] as String?,
      effectiveDateTime: map['effectiveDateTime'] != null
          ? DateTime.parse(map['effectiveDateTime'] as String)
          : null,
      status: map['status'] as String?,
    );
  }

  /// تحويل إلى تنسيق FHIR JSON
  Map<String, dynamic> toFHIR() {
    return {
      'resourceType': 'Observation',
      'id': id,
      'status': status ?? 'final',
      'category': [
        {
          'coding': [
            {
              'system': 'http://terminology.hl7.org/CodeSystem/observation-category',
              'code': 'laboratory',
              'display': 'Laboratory',
            }
          ]
        }
      ],
      'code': {
        'coding': [
          {
            'system': 'http://loinc.org',
            'code': testCode ?? '',
            'display': testName ?? '',
          }
        ],
        'text': testName,
      },
      'subject': {
        'reference': 'Patient/$patientId',
      },
      'effectiveDateTime': effectiveDateTime?.toIso8601String(),
      'valueQuantity': result != null
          ? {
              'value': double.tryParse(result ?? '0') ?? 0,
              'unit': unit,
              'system': 'http://unitsofmeasure.org',
              'code': unit,
            }
          : null,
      'referenceRange': referenceRange != null
          ? [
              {
                'text': referenceRange,
              }
            ]
          : null,
    };
  }
}

/// نموذج HL7/FHIR للوصفة الطبية
class HL7MedicationRequestModel {
  final String id;
  final String patientId; // معرف المريض
  final String? medicationName; // اسم الدواء
  final String? medicationCode; // كود الدواء
  final String? dosage; // الجرعة
  final String? frequency; // التكرار
  final DateTime? authoredOn; // تاريخ الوصفة
  final String? status; // الحالة (active, completed, etc.)

  HL7MedicationRequestModel({
    required this.id,
    required this.patientId,
    this.medicationName,
    this.medicationCode,
    this.dosage,
    this.frequency,
    this.authoredOn,
    this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'medicationName': medicationName,
      'medicationCode': medicationCode,
      'dosage': dosage,
      'frequency': frequency,
      'authoredOn': authoredOn?.toIso8601String(),
      'status': status,
    };
  }

  factory HL7MedicationRequestModel.fromMap(Map<String, dynamic> map) {
    return HL7MedicationRequestModel(
      id: map['id'] as String? ?? '',
      patientId: map['patientId'] as String? ?? '',
      medicationName: map['medicationName'] as String?,
      medicationCode: map['medicationCode'] as String?,
      dosage: map['dosage'] as String?,
      frequency: map['frequency'] as String?,
      authoredOn: map['authoredOn'] != null
          ? DateTime.parse(map['authoredOn'] as String)
          : null,
      status: map['status'] as String?,
    );
  }

  /// تحويل إلى تنسيق FHIR JSON
  Map<String, dynamic> toFHIR() {
    return {
      'resourceType': 'MedicationRequest',
      'id': id,
      'status': status ?? 'active',
      'intent': 'order',
      'medicationCodeableConcept': {
        'coding': [
          {
            'system': 'http://www.nlm.nih.gov/research/umls/rxnorm',
            'code': medicationCode ?? '',
            'display': medicationName ?? '',
          }
        ],
        'text': medicationName,
      },
      'subject': {
        'reference': 'Patient/$patientId',
      },
      'authoredOn': authoredOn?.toIso8601String(),
      'dosageInstruction': [
        {
          'text': '$dosage $frequency',
          'timing': {
            'repeat': {
              'frequency': 1,
            }
          },
        }
      ],
    };
  }
}

