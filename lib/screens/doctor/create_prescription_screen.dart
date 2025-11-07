import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/medical_record_model.dart';
import '../../models/prescription_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider_local.dart';
import '../../services/data_service.dart';

class CreatePrescriptionScreen extends StatefulWidget {
  const CreatePrescriptionScreen({super.key});

  @override
  State<CreatePrescriptionScreen> createState() =>
      _CreatePrescriptionScreenState();
}

class _CreatePrescriptionScreenState extends State<CreatePrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _diagnosisController = TextEditingController();
  final _notesController = TextEditingController();
  final _patientIdController = TextEditingController();
  final _patientNameController = TextEditingController();
  final List<Medication> _medications = [];
  final _dataService = DataService();
  bool _isSaving = false;

  static const Set<List<String>> _interactionPairs = {
    ['aspirin', 'warfarin'],
    ['ibuprofen', 'warfarin'],
    ['metformin', 'contrast'],
    ['nitroglycerin', 'sildenafil'],
    ['clopidogrel', 'omeprazole'],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء وصفة طبية جديدة'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _patientIdController,
                decoration: const InputDecoration(
                  labelText: 'رقم المريض',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: _showPatientPicker,
                  icon: const Icon(Icons.search),
                  label: const Text('اختيار من قائمة المرضى'),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _patientNameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المريض',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال اسم المريض';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _diagnosisController,
                decoration: const InputDecoration(
                  labelText: 'التشخيص',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال التشخيص';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'الأدوية:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._medications.asMap().entries.map((entry) {
                final index = entry.key;
                final medication = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(medication.name),
                    subtitle: Text('${medication.dosage} - ${medication.frequency}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          _medications.removeAt(index);
                        });
                      },
                    ),
                  ),
                );
              }),
              ElevatedButton.icon(
                onPressed: () => _showAddMedicationDialog(),
                icon: const Icon(Icons.add),
                label: const Text('إضافة دواء'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _handleCreatePrescription,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('إنشاء الوصفة', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddMedicationDialog() {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    final frequencyController = TextEditingController();
    final durationController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final instructionsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة دواء جديد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'اسم الدواء'),
              ),
              TextField(
                controller: dosageController,
                decoration: const InputDecoration(labelText: 'الجرعة'),
              ),
              TextField(
                controller: frequencyController,
                decoration: const InputDecoration(labelText: 'التكرار'),
              ),
              TextField(
                controller: durationController,
                decoration: const InputDecoration(labelText: 'المدة'),
              ),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: 'الكمية'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: instructionsController,
                decoration: const InputDecoration(labelText: 'تعليمات إضافية'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty ||
                  dosageController.text.trim().isEmpty ||
                  frequencyController.text.trim().isEmpty ||
                  durationController.text.trim().isEmpty) {
                return;
              }
              setState(() {
                _medications.add(Medication(
                  id: const Uuid().v4(),
                  name: nameController.text,
                  dosage: dosageController.text,
                  frequency: frequencyController.text,
                  duration: durationController.text,
                  quantity: int.tryParse(quantityController.text) ?? 1,
                  instructions: instructionsController.text,
                ));
              });
              Navigator.pop(context);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCreatePrescription() async {
    if (!_formKey.currentState!.validate()) return;
    if (_medications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إضافة دواء واحد على الأقل')),
      );
      return;
    }

    final authProvider = Provider.of<AuthProviderLocal>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول أولاً')),
      );
      return;
    }

    final doctorName = user.name;
    setState(() => _isSaving = true);

    final prescription = PrescriptionModel(
      id: const Uuid().v4(),
      doctorId: user.id,
      doctorName: doctorName,
      patientId: _patientIdController.text.trim(),
      patientName: _patientNameController.text.trim(),
      diagnosis: _diagnosisController.text.trim(),
      medications: _medications,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
      status: PrescriptionStatus.active,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );

    try {
      final warnings = await _detectInteractions(
        patientId: prescription.patientId,
        newMedications: prescription.medications,
      );

      final proceed = await _showInteractionWarnings(warnings);
      if (!proceed) {
        setState(() => _isSaving = false);
        return;
      }

      await _dataService.createPrescription(prescription);
      await _logPrescriptionToMedicalRecord(prescription, user);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء الوصفة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إنشاء الوصفة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showPatientPicker() async {
    try {
      final patients = await _dataService.getPatients();
      if (!mounted) return;

      if (patients.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يوجد مرضى مسجلين في النظام'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final searchController = TextEditingController();
      final patientsList = patients.cast<UserModel>();
      List<UserModel> filteredPatients = List.of(patientsList);

      final selectedPatient = await showModalBottomSheet<UserModel?>(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              void updateFilter(String query) {
                setModalState(() {
                  if (query.trim().isEmpty) {
                    filteredPatients = List.of(patientsList);
                  } else {
                    filteredPatients = patientsList
                        .where((patient) =>
                            patient.name.toLowerCase().contains(query.toLowerCase()) ||
                            patient.email.toLowerCase().contains(query.toLowerCase()) ||
                            patient.phone.contains(query))
                        .toList();
                  }
                });
              }

              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: searchController,
                          decoration: const InputDecoration(
                            labelText: 'بحث عن مريض',
                            hintText: 'ابحث بالاسم، البريد الإلكتروني، أو رقم الهاتف',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            updateFilter(value);
                          },
                          autofocus: true,
                        ),
                      ),
                      if (filteredPatients.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(Icons.person_off, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                searchController.text.trim().isEmpty
                                    ? 'لا يوجد مرضى مسجلين'
                                    : 'لا يوجد مرضى مطابقون للبحث',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      else
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredPatients.length,
                            itemBuilder: (context, index) {
                              final patient = filteredPatients[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                                  child: const Icon(Icons.person, color: Colors.blue),
                                ),
                                title: Text(
                                  patient.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(patient.email),
                                    if (patient.phone.isNotEmpty)
                                      Text('الهاتف: ${patient.phone}'),
                                  ],
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () {
                                  Navigator.pop(context, patient);
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

      if (selectedPatient != null && selectedPatient is UserModel) {
        setState(() {
          _patientIdController.text = selectedPatient.id;
          _patientNameController.text = selectedPatient.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في جلب قائمة المرضى: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<String>> _detectInteractions({
    required String patientId,
    required List<Medication> newMedications,
  }) async {
    final warnings = <String>[];

    final existingPrescriptions =
        await _dataService.getPrescriptions(patientId: patientId);
    final existingMedicationNames = existingPrescriptions
        .expand((prescription) => prescription.medications)
        .map((med) => med.name.toLowerCase())
        .toSet();

    final newNames = newMedications.map((med) => med.name.toLowerCase()).toList();

    // تحقق من التفاعلات بين الأدوية الجديدة وبين الأدوية السابقة
    for (final newMed in newNames) {
      for (final existing in existingMedicationNames) {
        if (_isInteraction(newMed, existing)) {
          warnings.add('تفاعل محتمل بين $newMed و $existing في سجلات المريض.');
        }
      }
    }

    // تحقق من التفاعلات داخل الوصفة نفسها
    for (var i = 0; i < newNames.length; i++) {
      for (var j = i + 1; j < newNames.length; j++) {
        if (_isInteraction(newNames[i], newNames[j])) {
          warnings.add('تفاعل محتمل بين ${newMedications[i].name} و ${newMedications[j].name}.');
        }
      }
    }

    return warnings;
  }

  bool _isInteraction(String a, String b) {
    final normalized = [a.toLowerCase(), b.toLowerCase()]..sort();
    return _interactionPairs.any((pair) {
      final sorted = pair.map((med) => med.toLowerCase()).toList()..sort();
      return sorted.length == normalized.length &&
          sorted[0] == normalized[0] &&
          sorted[1] == normalized[1];
    });
  }

  Future<bool> _showInteractionWarnings(List<String> warnings) async {
    if (warnings.isEmpty) {
      return true;
    }

    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تحذيرات التفاعلات الدوائية'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تم اكتشاف التفاعلات التالية:'),
              const SizedBox(height: 12),
              ...warnings.map((warning) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_outlined,
                            color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(child: Text(warning)),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
              const Text('هل ترغب في المتابعة على أي حال؟'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('المتابعة'),
          ),
        ],
      ),
    );

    return proceed == true;
  }

  Future<void> _logPrescriptionToMedicalRecord(
    PrescriptionModel prescription,
    UserModel doctor,
  ) async {
    final record = MedicalRecordModel(
      id: _dataService.generateId(),
      patientId: prescription.patientId,
      doctorId: doctor.id,
      doctorName: doctor.name,
      type: RecordType.prescription,
      title: 'وصفة طبية جديدة',
      description:
          'تشخيص: ${prescription.diagnosis}\nالأدوية: ${prescription.medications.map((m) => m.name).join(', ')}',
      date: DateTime.now(),
      fileUrls: null,
      additionalData: {
        'prescriptionId': prescription.id,
        'notes': prescription.notes,
        'expiresAt': prescription.expiresAt?.toIso8601String(),
      },
      createdAt: DateTime.now(),
    );

    await _dataService.addMedicalRecord(record);
  }

  @override
  void dispose() {
    _diagnosisController.dispose();
    _notesController.dispose();
    _patientIdController.dispose();
    _patientNameController.dispose();
    super.dispose();
  }
}

