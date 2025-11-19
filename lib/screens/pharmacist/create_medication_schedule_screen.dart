import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../models/hospital_pharmacy_model.dart';
import '../../models/prescription_model.dart';
import '../../services/data_service.dart';
import '../../models/user_model.dart';
import '../../models/room_bed_model.dart';

class CreateMedicationScheduleScreen extends StatefulWidget {
  const CreateMedicationScheduleScreen({super.key});

  @override
  State<CreateMedicationScheduleScreen> createState() => _CreateMedicationScheduleScreenState();
}

class _CreateMedicationScheduleScreenState extends State<CreateMedicationScheduleScreen> {
  final DataService _dataService = DataService();
  final Uuid _uuid = const Uuid();
  final _formKey = GlobalKey<FormState>();

  UserModel? _selectedPatient;
  PrescriptionModel? _selectedPrescription;
  BedModel? _selectedBed;
  MedicationScheduleType _scheduleType = MedicationScheduleType.scheduled;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  final List<TimeOfDay> _scheduledTimes = [];
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء جدول أدوية'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPatientSelector(),
              const SizedBox(height: 24),
              if (_selectedPatient != null) ...[
                _buildPrescriptionSelector(),
                const SizedBox(height: 24),
                _buildBedSelector(),
                const SizedBox(height: 24),
                _buildScheduleTypeSection(),
                const SizedBox(height: 24),
                _buildDatesSection(),
                if (_scheduleType == MedicationScheduleType.scheduled) ...[
                  const SizedBox(height: 24),
                  _buildTimesSection(),
                ],
                const SizedBox(height: 24),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveSchedule,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('حفظ الجدول'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اختيار المريض',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_selectedPatient == null)
              ElevatedButton.icon(
                onPressed: _selectPatient,
                icon: const Icon(Icons.person_add),
                label: const Text('اختر مريض'),
              )
            else
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(_selectedPatient!.name),
                subtitle: Text(_selectedPatient!.email ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _selectedPatient = null;
                    _selectedPrescription = null;
                    _selectedBed = null;
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اختيار الوصفة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_selectedPrescription == null)
              ElevatedButton.icon(
                onPressed: _selectPrescription,
                icon: const Icon(Icons.description),
                label: const Text('اختر وصفة طبية'),
              )
            else
              ListTile(
                leading: const Icon(Icons.description),
                title: Text('وصفة ${_selectedPrescription!.id.substring(0, 8)}'),
                subtitle: Text('${_selectedPrescription!.medications.length} دواء'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selectedPrescription = null),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBedSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اختيار السرير (اختياري)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_selectedBed == null)
              ElevatedButton.icon(
                onPressed: _selectBed,
                icon: const Icon(Icons.bed),
                label: const Text('اختر سرير'),
              )
            else
              ListTile(
                leading: const Icon(Icons.bed),
                title: Text(_selectedBed!.label),
                subtitle: Text('الغرفة: ${_selectedBed!.roomId}'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selectedBed = null),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleTypeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نوع الجدولة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            RadioListTile<MedicationScheduleType>(
              title: const Text('مجدولة'),
              value: MedicationScheduleType.scheduled,
              groupValue: _scheduleType,
              onChanged: (value) => setState(() => _scheduleType = value!),
            ),
            RadioListTile<MedicationScheduleType>(
              title: const Text('عند الحاجة (PRN)'),
              value: MedicationScheduleType.prn,
              groupValue: _scheduleType,
              onChanged: (value) => setState(() => _scheduleType = value!),
            ),
            RadioListTile<MedicationScheduleType>(
              title: const Text('فورية (STAT)'),
              value: MedicationScheduleType.stat,
              groupValue: _scheduleType,
              onChanged: (value) => setState(() => _scheduleType = value!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatesSection() {
    final dateFormat = DateFormat('yyyy-MM-dd', 'ar');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'التواريخ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('تاريخ البدء'),
              subtitle: Text(dateFormat.format(_startDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  setState(() => _startDate = date);
                }
              },
            ),
            ListTile(
              title: const Text('تاريخ الانتهاء (اختياري)'),
              subtitle: Text(_endDate != null ? dateFormat.format(_endDate!) : 'غير محدد'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _endDate ?? _startDate,
                  firstDate: _startDate,
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  setState(() => _endDate = date);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'الأوقات المجدولة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _addTime,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة وقت'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_scheduledTimes.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('لا توجد أوقات مجدولة'),
                ),
              )
            else
              ..._scheduledTimes.asMap().entries.map((entry) {
                final index = entry.key;
                final time = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(time.format(context)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() => _scheduledTimes.removeAt(index));
                      },
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _selectPatient() async {
    try {
      final patients = await _dataService.getPatients();
      final patientList = patients.cast<UserModel>();

      if (!mounted) return;
      final selected = await showDialog<UserModel>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('اختر مريض'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: patientList.length,
              itemBuilder: (context, index) {
                final patient = patientList[index];
                return ListTile(
                  title: Text(patient.name),
                  subtitle: Text(patient.email ?? ''),
                  onTap: () => Navigator.pop(context, patient),
                );
              },
            ),
          ),
        ),
      );

      if (selected != null) {
        setState(() => _selectedPatient = selected);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل المرضى: $e')),
        );
      }
    }
  }

  Future<void> _selectPrescription() async {
    if (_selectedPatient == null) return;

    try {
      final prescriptions = await _dataService.getPrescriptions(
        patientId: _selectedPatient!.id,
      );
      final prescriptionList = prescriptions.cast<PrescriptionModel>();

      if (!mounted) return;
      final selected = await showDialog<PrescriptionModel>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('اختر وصفة طبية'),
          content: SizedBox(
            width: double.maxFinite,
            child: prescriptionList.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('لا توجد وصفات طبية'),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: prescriptionList.length,
                    itemBuilder: (context, index) {
                      final prescription = prescriptionList[index];
                      return ListTile(
                        title: Text('وصفة ${prescription.id.substring(0, 8)}'),
                        subtitle: Text('${prescription.medications.length} دواء'),
                        onTap: () => Navigator.pop(context, prescription),
                      );
                    },
                  ),
          ),
        ),
      );

      if (selected != null) {
        setState(() => _selectedPrescription = selected);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الوصفات: $e')),
        );
      }
    }
  }

  Future<void> _selectBed() async {
    try {
      final beds = await _dataService.getBeds(status: BedStatus.occupied);
      final bedsList = beds.cast<BedModel>();

      if (!mounted) return;
      final selected = await showDialog<BedModel>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('اختر سرير'),
          content: SizedBox(
            width: double.maxFinite,
            child: bedsList.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('لا توجد أسرة مشغولة'),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: bedsList.length,
                    itemBuilder: (context, index) {
                      final bed = bedsList[index];
                      return ListTile(
                        title: Text(bed.label),
                        subtitle: Text('الغرفة: ${bed.roomId}'),
                        onTap: () => Navigator.pop(context, bed),
                      );
                    },
                  ),
          ),
        ),
      );

      if (selected != null) {
        setState(() => _selectedBed = selected);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الأسرة: $e')),
        );
      }
    }
  }

  Future<void> _addTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time != null) {
      setState(() {
        if (!_scheduledTimes.contains(time)) {
          _scheduledTimes.add(time);
          _scheduledTimes.sort((a, b) {
            final aMinutes = a.hour * 60 + a.minute;
            final bMinutes = b.hour * 60 + b.minute;
            return aMinutes.compareTo(bMinutes);
          });
        }
      });
    }
  }

  Future<void> _saveSchedule() async {
    if (_selectedPatient == null || _selectedPrescription == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار المريض والوصفة')),
      );
      return;
    }

    if (_scheduleType == MedicationScheduleType.scheduled && _scheduledTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إضافة أوقات مجدولة')),
      );
      return;
    }

    try {
      // إنشاء جداول للأدوية في الوصفة
      for (final medication in _selectedPrescription!.medications) {
        List<DateTime> scheduledTimes = [];
        if (_scheduleType == MedicationScheduleType.scheduled) {
          // تحويل TimeOfDay إلى DateTime
          scheduledTimes = _scheduledTimes.map((time) {
            final now = DateTime.now();
            return DateTime(
              _startDate.year,
              _startDate.month,
              _startDate.day,
              time.hour,
              time.minute,
            );
          }).toList();
        } else {
          // للـ PRN و STAT، نضيف وقت واحد فقط
          scheduledTimes = [DateTime.now()];
        }

        final schedule = MedicationScheduleModel(
          id: _uuid.v4(),
          patientId: _selectedPatient!.id,
          patientName: _selectedPatient!.name,
          bedId: _selectedBed?.id,
          roomId: _selectedBed?.roomId,
          prescriptionId: _selectedPrescription!.id,
          medicationId: medication.id,
          medicationName: medication.name,
          dosage: medication.dosage,
          frequency: medication.frequency,
          quantity: medication.quantity,
          scheduleType: _scheduleType,
          startDate: _startDate,
          endDate: _endDate,
          scheduledTimes: scheduledTimes,
          isActive: true,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          createdAt: DateTime.now(),
        );

        await _dataService.createMedicationSchedule(schedule);

        // إنشاء سجلات الصرف المجدولة
        if (_scheduleType == MedicationScheduleType.scheduled) {
          for (final scheduledTime in scheduledTimes) {
            final dispense = HospitalPharmacyDispenseModel(
              id: _uuid.v4(),
              patientId: _selectedPatient!.id,
              patientName: _selectedPatient!.name,
              bedId: _selectedBed?.id,
              roomId: _selectedBed?.roomId,
              prescriptionId: _selectedPrescription!.id,
              medicationId: medication.id,
              medicationName: medication.name,
              dosage: medication.dosage,
              frequency: medication.frequency,
              quantity: medication.quantity,
              status: MedicationDispenseStatus.scheduled,
              scheduleType: _scheduleType,
              scheduledTime: scheduledTime,
              createdAt: DateTime.now(),
            );

            await _dataService.createHospitalPharmacyDispense(dispense);
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء الجدول بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إنشاء الجدول: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

