import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/doctor_appointment_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider_local.dart';
import '../../services/data_service.dart';
import '../../services/invoice_auto_service.dart';
import '../../utils/auth_helper.dart';
import 'package:intl/intl.dart';

class NotificationsAppointmentsScreen extends StatefulWidget {
  const NotificationsAppointmentsScreen({super.key});

  @override
  State<NotificationsAppointmentsScreen> createState() =>
      _NotificationsAppointmentsScreenState();
}

class _NotificationsAppointmentsScreenState
    extends State<NotificationsAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  final _dataService = DataService();
  late TabController _tabController;
  List<Map<String, dynamic>> _medicationReminders = [];
  List<DoctorAppointment> _appointments = [];
  Map<String, String> _doctorNamesCache = {}; // Cache for doctor names
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // تحديث القائمة عند التبديل بين التبويبات
      if (_tabController.index == 1 && !_isLoading) {
        _loadAppointments();
      }
    });
    _loadReminders();
    _loadAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProviderLocal>(context, listen: false);
      final patientId = authProvider.currentUser?.id ?? '';
      final prescriptions = await _dataService.getPrescriptions(patientId: patientId);

      final reminders = <Map<String, dynamic>>[];
      for (final prescription in prescriptions) {
        for (final medication in prescription.medications) {
          // تحليل التكرار لإنشاء تنبيهات
          final times = _parseFrequency(medication.frequency);
          for (final time in times) {
            reminders.add({
              'id': const Uuid().v4(),
              'medicationName': medication.name,
              'dosage': medication.dosage,
              'time': time,
              'prescriptionId': prescription.id,
              'isCompleted': false,
            });
          }
        }
      }

      setState(() {
        _medicationReminders = reminders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل التنبيهات: $e')),
        );
      }
    }
  }

  List<String> _parseFrequency(String frequency) {
    // تحويل التكرار إلى أوقات (مثال: "مرتين يومياً" -> ["08:00", "20:00"])
    if (frequency.contains('مرتين')) {
      return ['08:00', '20:00'];
    } else if (frequency.contains('ثلاث مرات')) {
      return ['08:00', '14:00', '20:00'];
    } else if (frequency.contains('أربع مرات')) {
      return ['08:00', '12:00', '16:00', '20:00'];
    }
    return ['08:00']; // افتراضي
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProviderLocal>(context, listen: false);
      final patientId = authProvider.currentUser?.id ?? '';
      if (patientId.isEmpty) {
        setState(() {
          _appointments = [];
          _isLoading = false;
        });
        return;
      }

      final appointments = await _dataService.getPatientAppointments(patientId);
      
      // جلب أسماء الأطباء للمواعيد
      final doctorIds = appointments.map((apt) => apt.doctorId).toSet();
      final doctors = await _dataService.getUsers(role: UserRole.doctor);
      final doctorNamesMap = {
        for (final doctor in doctors) doctor.id: doctor.name
      };
      
      setState(() {
        _appointments = appointments.cast<DoctorAppointment>();
        _doctorNamesCache = Map<String, String>.from(doctorNamesMap);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل المواعيد: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التنبيهات والمواعيد'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'تنبيهات الجرعات', icon: Icon(Icons.medication)),
            Tab(text: 'حجز موعد', icon: Icon(Icons.calendar_today)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRemindersTab(),
                _buildAppointmentsTab(),
              ],
            ),
    );
  }

  Widget _buildRemindersTab() {
    final todayReminders = _medicationReminders.where((reminder) {
      // مقارنة بسيطة - في التطبيق الحقيقي يجب أن تكون أكثر دقة
      return true; // اليوم
    }).toList();

    final upcomingReminders = _medicationReminders.where((reminder) {
      return !(reminder['isCompleted'] as bool);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadReminders,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (todayReminders.isNotEmpty) ...[
            const Text(
              'تنبيهات اليوم',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...todayReminders.map((reminder) => _buildReminderCard(reminder)),
            const SizedBox(height: 16),
          ],
          if (upcomingReminders.isNotEmpty) ...[
            const Text(
              'التنبيهات القادمة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...upcomingReminders.map((reminder) => _buildReminderCard(reminder)),
          ],
          if (_medicationReminders.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('لا توجد تنبيهات'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(Map<String, dynamic> reminder) {
    final isCompleted = reminder['isCompleted'] as bool;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isCompleted ? Colors.grey[100] : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCompleted
              ? Colors.grey.withValues(alpha: 0.2)
              : Colors.blue.withValues(alpha: 0.2),
          child: Icon(
            isCompleted ? Icons.check_circle : Icons.medication,
            color: isCompleted ? Colors.grey : Colors.blue,
          ),
        ),
        title: Text(
          reminder['medicationName'] as String,
          style: TextStyle(
            decoration: isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الجرعة: ${reminder['dosage']}'),
            Text('الوقت: ${reminder['time']}'),
          ],
        ),
        trailing: isCompleted
            ? const Icon(Icons.check, color: Colors.green)
            : IconButton(
                icon: const Icon(Icons.check_circle_outline),
                onPressed: () => _markReminderCompleted(reminder['id'] as String),
              ),
      ),
    );
  }

  Widget _buildAppointmentsTab() {
    return RefreshIndicator(
      onRefresh: _loadAppointments,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('حجز موعد جديد'),
            onPressed: () => _showBookAppointmentDialog(),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          if (_appointments.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('لا توجد مواعيد محجوزة'),
              ),
            )
          else
            ..._appointments.map((apt) => _buildAppointmentCard(apt)),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(DoctorAppointment appointment) {
    final statusColor = {
      AppointmentStatus.scheduled: Colors.blue,
      AppointmentStatus.confirmed: Colors.green,
      AppointmentStatus.cancelled: Colors.red,
      AppointmentStatus.completed: Colors.grey,
    }[appointment.status]!;

    final statusText = {
      AppointmentStatus.scheduled: 'مجدول',
      AppointmentStatus.confirmed: 'مؤكد',
      AppointmentStatus.cancelled: 'ملغي',
      AppointmentStatus.completed: 'مكتمل',
    }[appointment.status]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(Icons.calendar_today, color: statusColor),
        ),
        title: Text(_getDoctorNameForAppointment(appointment)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('التاريخ: ${DateFormat('yyyy-MM-dd').format(appointment.date)}'),
            Text('الوقت: ${DateFormat('HH:mm').format(appointment.date)}'),
            if (appointment.type != null) Text('النوع: ${appointment.type}'),
            Chip(
              label: Text(statusText, style: const TextStyle(fontSize: 12)),
              backgroundColor: statusColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(color: statusColor),
            ),
          ],
        ),
        trailing: appointment.status != AppointmentStatus.cancelled &&
                appointment.status != AppointmentStatus.completed
            ? IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red),
                onPressed: () => _cancelAppointment(appointment.id),
              )
            : null,
      ),
    );
  }

  String _getDoctorNameForAppointment(DoctorAppointment appointment) {
    return _doctorNamesCache[appointment.doctorId] ?? 
           appointment.patientName ?? 
           'طبيب';
  }

  Future<void> _showBookAppointmentDialog() async {
    try {
      final doctors = await _dataService.getUsers(role: UserRole.doctor);
      
      if (doctors.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا توجد أطباء متاحين'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      UserModel? selectedDoctor;
      DateTime? selectedDate;
      TimeOfDay? selectedTime;

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
                    decoration: const InputDecoration(
                      labelText: 'اختر الطبيب *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    value: selectedDoctor,
                    items: doctors.map((doctor) {
                      return DropdownMenuItem<UserModel>(
                        value: doctor,
                        child: Text('${doctor.name}${doctor.specialization != null ? ' - ${doctor.specialization}' : ''}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedDoctor = value);
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'يرجى اختيار طبيب';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (date != null) {
                        setState(() => selectedDate = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: selectedDate == null ? Colors.grey : Colors.blue),
                        borderRadius: BorderRadius.circular(8),
                        color: selectedDate == null ? null : Colors.blue.withValues(alpha: 0.05),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: selectedDate == null ? Colors.grey : Colors.blue,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'التاريخ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  selectedDate == null
                                      ? 'اختر التاريخ *'
                                      : DateFormat('yyyy-MM-dd').format(selectedDate!),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: selectedDate == null ? FontWeight.normal : FontWeight.bold,
                                    color: selectedDate == null ? Colors.grey : Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (selectedDate != null)
                            Icon(Icons.check_circle, color: Colors.green),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        setState(() => selectedTime = time);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: selectedTime == null ? Colors.grey : Colors.blue),
                        borderRadius: BorderRadius.circular(8),
                        color: selectedTime == null ? null : Colors.blue.withValues(alpha: 0.05),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: selectedTime == null ? Colors.grey : Colors.blue,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'الوقت',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  selectedTime == null
                                      ? 'اختر الوقت *'
                                      : selectedTime!.format(context),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: selectedTime == null ? FontWeight.normal : FontWeight.bold,
                                    color: selectedTime == null ? Colors.grey : Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (selectedTime != null)
                            Icon(Icons.check_circle, color: Colors.green),
                        ],
                      ),
                    ),
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
                onPressed: () {
                  if (selectedDoctor == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('يرجى اختيار الطبيب'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  if (selectedDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('يرجى اختيار التاريخ'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  if (selectedTime == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('يرجى اختيار الوقت'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('حجز الموعد', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      );

      if (result == true && selectedDoctor != null && selectedDate != null && selectedTime != null) {
        // عرض مؤشر تحميل
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('جاري حجز الموعد...'),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        try {
          final authProvider = Provider.of<AuthProviderLocal>(context, listen: false);
          final patient = authProvider.currentUser;
          if (patient == null) {
            throw Exception('تعذر تحديد حساب المريض الحالي');
          }

          final appointmentDateTime = DateTime(
            selectedDate!.year,
            selectedDate!.month,
            selectedDate!.day,
            selectedTime!.hour,
            selectedTime!.minute,
          );

          final appointment = DoctorAppointment(
            id: const Uuid().v4(),
            doctorId: selectedDoctor!.id,
            patientId: patient.id,
            patientName: patient.name,
            date: appointmentDateTime,
            status: AppointmentStatus.scheduled,
            type: 'استشارة طبية',
            notes: 'تم الحجز من قبل المريض',
            createdAt: DateTime.now(),
          );

          await _dataService.createAppointmentWithReminders(appointment);
          
          // إنشاء فاتورة تلقائية للموعد
          try {
            final invoiceService = InvoiceAutoService();
            await invoiceService.createAppointmentInvoice(
              appointment: appointment,
              patient: patient,
              appointmentFee: 100.0, // يمكن جعلها قابلة للتخصيص
            );
          } catch (e) {
            // لا نوقف العملية إذا فشل إنشاء الفاتورة
            debugPrint('خطأ في إنشاء فاتورة الموعد: $e');
          }
          
          // إغلاق مؤشر التحميل
          if (mounted) {
            Navigator.pop(context);
          }
          
          // تحديث القائمة فوراً
          await _loadAppointments();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تم حجز الموعد بنجاح مع ${selectedDoctor!.name} في ${DateFormat('yyyy-MM-dd').format(appointmentDateTime)}',
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          // إغلاق مؤشر التحميل في حالة الخطأ
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('خطأ في حجز الموعد: $e'),
                    ),
                  ],
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الأطباء: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markReminderCompleted(String reminderId) async {
    setState(() {
      final index = _medicationReminders.indexWhere((r) => r['id'] == reminderId);
      if (index != -1) {
        _medicationReminders[index]['isCompleted'] = true;
      }
    });
  }

  Future<void> _cancelAppointment(String appointmentId) async {
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
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dataService.updateAppointmentStatus(
          appointmentId,
          AppointmentStatus.cancelled,
        );
        await _loadAppointments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إلغاء الموعد'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في إلغاء الموعد: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

