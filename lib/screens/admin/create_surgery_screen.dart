import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../models/surgery_model.dart';
import '../../models/user_model.dart';
import '../../models/room_bed_model.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';

class CreateSurgeryScreen extends StatefulWidget {
  const CreateSurgeryScreen({super.key});

  @override
  State<CreateSurgeryScreen> createState() => _CreateSurgeryScreenState();
}

class _CreateSurgeryScreenState extends State<CreateSurgeryScreen> {
  final DataService _dataService = DataService();
  final _formKey = GlobalKey<FormState>();
  final Uuid _uuid = const Uuid();

  // معلومات أساسية
  UserModel? _selectedPatient;
  final _surgeryNameController = TextEditingController();
  SurgeryType _surgeryType = SurgeryType.elective;
  final _diagnosisController = TextEditingController();
  final _procedureController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _scheduledDate = DateTime.now();
  TimeOfDay _scheduledTime = TimeOfDay.now();

  // غرفة العمليات
  RoomModel? _selectedRoom;

  // فريق العملية
  UserModel? _selectedSurgeon;
  UserModel? _selectedAssistantSurgeon;
  UserModel? _selectedAnesthesiologist;
  List<UserModel> _selectedNurses = [];
  List<UserModel> _availableNurses = [];

  // المعدات
  final List<String> _equipment = [];
  final _equipmentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNurses();
  }

  @override
  void dispose() {
    _surgeryNameController.dispose();
    _diagnosisController.dispose();
    _procedureController.dispose();
    _notesController.dispose();
    _equipmentController.dispose();
    super.dispose();
  }

  Future<void> _loadNurses() async {
    try {
      final users = await _dataService.getUsers(role: UserRole.nurse);
      setState(() {
        _availableNurses = users.cast<UserModel>();
      });
    } catch (e) {
      debugPrint('خطأ في تحميل الممرضين: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة عملية جراحية'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBasicInfoSection(),
              const SizedBox(height: 24),
              _buildOperationRoomSection(),
              const SizedBox(height: 24),
              _buildTeamSection(),
              const SizedBox(height: 24),
              _buildEquipmentSection(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveSurgery,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('حفظ العملية الجراحية'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'المعلومات الأساسية',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildPatientSelector(),
            const SizedBox(height: 16),
            TextFormField(
              controller: _surgeryNameController,
              decoration: const InputDecoration(
                labelText: 'اسم العملية الجراحية',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.medical_services),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال اسم العملية';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text('نوع العملية'),
            RadioListTile<SurgeryType>(
              title: const Text('اختياري'),
              value: SurgeryType.elective,
              groupValue: _surgeryType,
              onChanged: (value) => setState(() => _surgeryType = value!),
            ),
            RadioListTile<SurgeryType>(
              title: const Text('طارئ'),
              value: SurgeryType.emergency,
              groupValue: _surgeryType,
              onChanged: (value) => setState(() => _surgeryType = value!),
            ),
            RadioListTile<SurgeryType>(
              title: const Text('عاجل'),
              value: SurgeryType.urgent,
              groupValue: _surgeryType,
              onChanged: (value) => setState(() => _surgeryType = value!),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('التاريخ'),
                    subtitle: Text(DateFormat('yyyy-MM-dd', 'ar').format(_scheduledDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _scheduledDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => _scheduledDate = date);
                      }
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('الوقت'),
                    subtitle: Text(_scheduledTime.format(context)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _scheduledTime,
                      );
                      if (time != null) {
                        setState(() => _scheduledTime = time);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _diagnosisController,
              decoration: const InputDecoration(
                labelText: 'التشخيص',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _procedureController,
              decoration: const InputDecoration(
                labelText: 'الإجراء المطلوب',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientSelector() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اختيار المريض',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
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
                  onPressed: () => setState(() => _selectedPatient = null),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationRoomSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'غرفة العمليات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_selectedRoom == null)
              ElevatedButton.icon(
                onPressed: _selectOperationRoom,
                icon: const Icon(Icons.room),
                label: const Text('اختر غرفة عمليات'),
              )
            else
              ListTile(
                leading: const Icon(Icons.room, color: Colors.orange),
                title: Text(_selectedRoom!.name),
                subtitle: Text({
                  RoomType.ward: 'عادية',
                  RoomType.icu: 'عناية مركزة',
                  RoomType.operation: 'عمليات',
                  RoomType.isolation: 'عزل',
                }[_selectedRoom!.type]!),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selectedRoom = null),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'فريق العملية',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildTeamMemberSelector(
              'الجراح الرئيسي',
              _selectedSurgeon,
              (user) => setState(() => _selectedSurgeon = user),
              () => setState(() => _selectedSurgeon = null),
              UserRole.doctor,
              required: true,
            ),
            const SizedBox(height: 16),
            _buildTeamMemberSelector(
              'الجراح المساعد (اختياري)',
              _selectedAssistantSurgeon,
              (user) => setState(() => _selectedAssistantSurgeon = user),
              () => setState(() => _selectedAssistantSurgeon = null),
              UserRole.doctor,
            ),
            const SizedBox(height: 16),
            _buildTeamMemberSelector(
              'طبيب التخدير (اختياري)',
              _selectedAnesthesiologist,
              (user) => setState(() => _selectedAnesthesiologist = user),
              () => setState(() => _selectedAnesthesiologist = null),
              UserRole.doctor,
            ),
            const SizedBox(height: 16),
            const Text('الممرضون'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedNurses.map((nurse) {
                return Chip(
                  label: Text(nurse.name),
                  onDeleted: () {
                    setState(() => _selectedNurses.remove(nurse));
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _selectNurses,
              icon: const Icon(Icons.person_add),
              label: const Text('إضافة ممرضين'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamMemberSelector(
    String label,
    UserModel? selected,
    Function(UserModel) onSelect,
    Function() onRemove,
    UserRole role, {
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: required ? FontWeight.bold : null)),
        const SizedBox(height: 8),
        if (selected == null)
          ElevatedButton.icon(
            onPressed: () => _selectTeamMember(role, onSelect),
            icon: const Icon(Icons.person_add, size: 18),
            label: Text('اختر ${label.split(' ').last}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: required ? Colors.blue : Colors.grey,
            ),
          )
        else
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(selected.name),
            subtitle: Text(selected.email ?? ''),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: onRemove,
            ),
          ),
      ],
    );
  }

  Widget _buildEquipmentSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'المعدات الجراحية',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _equipment.map((eq) {
                return Chip(
                  label: Text(eq),
                  onDeleted: () {
                    setState(() => _equipment.remove(eq));
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _equipmentController,
                    decoration: const InputDecoration(
                      labelText: 'إضافة معدات',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (_equipmentController.text.trim().isNotEmpty) {
                      setState(() {
                        _equipment.add(_equipmentController.text.trim());
                        _equipmentController.clear();
                      });
                    }
                  },
                  child: const Text('إضافة'),
                ),
              ],
            ),
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

  Future<void> _selectOperationRoom() async {
    try {
      final rooms = await _dataService.getRooms();
      final roomsList = rooms.cast<RoomModel>();
      final operationRooms = roomsList.where((r) => r.type == RoomType.operation).toList();

      if (!mounted) return;
      final selected = await showDialog<RoomModel>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('اختر غرفة عمليات'),
          content: SizedBox(
            width: double.maxFinite,
            child: operationRooms.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('لا توجد غرف عمليات متاحة'),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: operationRooms.length,
                    itemBuilder: (context, index) {
                      final room = operationRooms[index];
                      return ListTile(
                        leading: const Icon(Icons.room),
                        title: Text(room.name),
                        subtitle: room.floor != null ? Text('الطابق: ${room.floor}') : null,
                        onTap: () => Navigator.pop(context, room),
                      );
                    },
                  ),
          ),
        ),
      );

      if (selected != null) {
        setState(() => _selectedRoom = selected);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الغرف: $e')),
        );
      }
    }
  }

  Future<void> _selectTeamMember(UserRole role, Function(UserModel) onSelect) async {
    try {
      final users = await _dataService.getUsers(role: role);
      final userList = users.cast<UserModel>();

      if (!mounted) return;
      final selected = await showDialog<UserModel>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('اختر ${role == UserRole.doctor ? 'طبيب' : 'ممرض'}'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: userList.length,
              itemBuilder: (context, index) {
                final user = userList[index];
                return ListTile(
                  title: Text(user.name),
                  subtitle: Text(user.email ?? ''),
                  onTap: () => Navigator.pop(context, user),
                );
              },
            ),
          ),
        ),
      );

      if (selected != null) {
        onSelect(selected);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل المستخدمين: $e')),
        );
      }
    }
  }

  Future<void> _selectNurses() async {
    try {
      final available = _availableNurses.where((n) => !_selectedNurses.contains(n)).toList();

      if (!mounted) return;
      
      final selectedNurses = <UserModel>[];
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('اختر الممرضين'),
            content: SizedBox(
              width: double.maxFinite,
              child: available.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('لا توجد ممرضين متاحين'),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...available.map((nurse) {
                          return CheckboxListTile(
                            title: Text(nurse.name),
                            value: selectedNurses.contains(nurse),
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked == true) {
                                  selectedNurses.add(nurse);
                                } else {
                                  selectedNurses.remove(nurse);
                                }
                              });
                            },
                          );
                        }).toList(),
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
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      );

      if (result == true && selectedNurses.isNotEmpty) {
        setState(() {
          _selectedNurses.addAll(selectedNurses);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    }
  }

  Future<void> _saveSurgery() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار مريض')),
      );
      return;
    }

    if (_selectedSurgeon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الجراح الرئيسي')),
      );
      return;
    }

    try {
      final scheduledDateTime = DateTime(
        _scheduledDate.year,
        _scheduledDate.month,
        _scheduledDate.day,
        _scheduledTime.hour,
        _scheduledTime.minute,
      );

      final surgery = SurgeryModel(
        id: _uuid.v4(),
        patientId: _selectedPatient!.id,
        patientName: _selectedPatient!.name,
        surgeryName: _surgeryNameController.text.trim(),
        type: _surgeryType,
        status: SurgeryStatus.scheduled,
        scheduledDate: scheduledDateTime,
        operationRoomId: _selectedRoom?.id,
        operationRoomName: _selectedRoom?.name,
        surgeonId: _selectedSurgeon!.id,
        surgeonName: _selectedSurgeon!.name,
        assistantSurgeonId: _selectedAssistantSurgeon?.id,
        assistantSurgeonName: _selectedAssistantSurgeon?.name,
        anesthesiologistId: _selectedAnesthesiologist?.id,
        anesthesiologistName: _selectedAnesthesiologist?.name,
        nurseIds: _selectedNurses.map((n) => n.id).toList(),
        nurseNames: _selectedNurses.map((n) => n.name).toList(),
        diagnosis: _diagnosisController.text.trim().isEmpty
            ? null
            : _diagnosisController.text.trim(),
        procedure: _procedureController.text.trim().isEmpty
            ? null
            : _procedureController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        equipment: _equipment.isEmpty ? null : _equipment,
        createdAt: DateTime.now(),
      );

      await _dataService.createSurgery(surgery);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة العملية الجراحية بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إضافة العملية: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

