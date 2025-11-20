import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/doctor_appointment_model.dart';
import '../../models/user_model.dart';
import '../../services/data_service.dart';
import '../../widgets/loading_widgets.dart';
import '../../utils/ui_snackbar.dart';
import 'package:uuid/uuid.dart';

class ReceptionistAppointmentsScreen extends StatefulWidget {
  const ReceptionistAppointmentsScreen({super.key});

  @override
  State<ReceptionistAppointmentsScreen> createState() => _ReceptionistAppointmentsScreenState();
}

class _ReceptionistAppointmentsScreenState extends State<ReceptionistAppointmentsScreen> {
  final DataService _dataService = DataService();
  final Uuid _uuid = const Uuid();
  List<DoctorAppointment> _appointments = [];
  List<UserModel> _doctors = [];
  List<UserModel> _patients = [];
  bool _isLoading = true;
  AppointmentStatus? _filterStatus;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadAppointments(),
        _loadDoctors(),
        _loadPatients(),
      ]);
    } catch (e) {
      if (mounted) {
        showFriendlyAuthError(context, e);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAppointments() async {
    try {
      final allDoctors = await _dataService.getUsers(role: UserRole.doctor);
      final appointments = <DoctorAppointment>[];
      
      for (final doctor in allDoctors) {
        final doctorAppointments = await _dataService.getDoctorAppointments(doctor.id);
        appointments.addAll(doctorAppointments);
      }
      
      setState(() {
        _appointments = appointments;
      });
    } catch (e) {
      if (mounted) {
        showFriendlyAuthError(context, e);
      }
    }
  }

  Future<void> _loadDoctors() async {
    try {
      final doctors = await _dataService.getUsers(role: UserRole.doctor);
      setState(() {
        _doctors = doctors.cast<UserModel>();
      });
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _loadPatients() async {
    try {
      final patients = await _dataService.getPatients();
      setState(() {
        _patients = patients.cast<UserModel>();
      });
    } catch (e) {
      // Ignore
    }
  }

  List<DoctorAppointment> get _filteredAppointments {
    var filtered = _appointments;
    
    if (_filterStatus != null) {
      filtered = filtered.where((a) => a.status == _filterStatus).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((a) {
        return a.patientName.toLowerCase().contains(query) ||
            a.doctorId.toLowerCase().contains(query);
      }).toList();
    }
    
    return filtered..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المواعيد'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateAppointmentDialog,
            tooltip: 'حجز موعد جديد',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          // فلاتر
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'بحث...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<AppointmentStatus?>(
                  value: _filterStatus,
                  hint: const Text('الحالة'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('الكل')),
                    ...AppointmentStatus.values.map((status) => DropdownMenuItem(
                      value: status,
                      child: Text(_getStatusText(status)),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() => _filterStatus = value);
                  },
                ),
              ],
            ),
          ),
          // القائمة
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredAppointments.isEmpty
                    ? const Center(
                        child: Text('لا توجد مواعيد'),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredAppointments.length,
                          itemBuilder: (context, index) {
                            final appointment = _filteredAppointments[index];
                            return _buildAppointmentCard(appointment);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(DoctorAppointment appointment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(appointment.status).withValues(alpha: 0.2),
          child: Icon(
            Icons.calendar_today,
            color: _getStatusColor(appointment.status),
          ),
        ),
        title: Text(
          appointment.patientName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('التاريخ: ${DateFormat('yyyy-MM-dd HH:mm').format(appointment.date)}'),
            Text('الحالة: ${_getStatusText(appointment.status)}'),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            if (appointment.status != AppointmentStatus.cancelled)
              PopupMenuItem(
                child: const Text('تعديل'),
                onTap: () => _showEditAppointmentDialog(appointment),
              ),
            if (appointment.status != AppointmentStatus.cancelled)
              PopupMenuItem(
                child: const Text('إلغاء'),
                onTap: () => _cancelAppointment(appointment),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.pending:
        return Colors.orange;
      case AppointmentStatus.confirmed:
        return Colors.green;
      case AppointmentStatus.completed:
        return Colors.blue;
      case AppointmentStatus.cancelled:
        return Colors.red;
    }
  }

  String _getStatusText(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.pending:
        return 'قيد الانتظار';
      case AppointmentStatus.confirmed:
        return 'مؤكد';
      case AppointmentStatus.completed:
        return 'مكتمل';
      case AppointmentStatus.cancelled:
        return 'ملغى';
    }
  }

  Future<void> _showCreateAppointmentDialog() async {
    UserModel? selectedPatient;
    UserModel? selectedDoctor;
    DateTime selectedDate = DateTime.now();
    AppointmentType selectedType = AppointmentType.consultation;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('حجز موعد جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<UserModel>(
                  decoration: const InputDecoration(labelText: 'المريض'),
                  items: _patients.map((p) => DropdownMenuItem(
                    value: p,
                    child: Text(p.name),
                  )).toList(),
                  onChanged: (value) => setState(() => selectedPatient = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<UserModel>(
                  decoration: const InputDecoration(labelText: 'الطبيب'),
                  items: _doctors.map((d) => DropdownMenuItem(
                    value: d,
                    child: Text(d.name),
                  )).toList(),
                  onChanged: (value) => setState(() => selectedDoctor = value),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text('التاريخ: ${DateFormat('yyyy-MM-dd HH:mm').format(selectedDate)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                      );
                      if (time != null) {
                        setState(() {
                          selectedDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: selectedPatient != null && selectedDoctor != null
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('حجز'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedPatient != null && selectedDoctor != null) {
      try {
        final appointment = DoctorAppointment(
          id: _uuid.v4(),
          doctorId: selectedDoctor.id,
          patientId: selectedPatient.id,
          patientName: selectedPatient.name,
          date: selectedDate,
          status: AppointmentStatus.pending,
          type: selectedType,
          notes: 'تم الحجز من قبل موظف الاستقبال',
          createdAt: DateTime.now(),
        );

        await _dataService.createAppointmentWithReminders(appointment);
        await _loadData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حجز الموعد بنجاح')),
          );
        }
      } catch (e) {
        if (mounted) {
          showFriendlyAuthError(context, e);
        }
      }
    }
  }

  Future<void> _showEditAppointmentDialog(DoctorAppointment appointment) async {
    // TODO: Implement edit appointment
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ميزة التعديل قيد التطوير')),
    );
  }

  Future<void> _cancelAppointment(DoctorAppointment appointment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الموعد'),
        content: const Text('هل أنت متأكد من إلغاء هذا الموعد؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('نعم، إلغاء'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dataService.updateAppointmentStatus(
          appointment.id,
          AppointmentStatus.cancelled,
        );
        await _loadData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إلغاء الموعد')),
          );
        }
      } catch (e) {
        if (mounted) {
          showFriendlyAuthError(context, e);
        }
      }
    }
  }
}

