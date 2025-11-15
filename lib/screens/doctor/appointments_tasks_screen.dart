import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/doctor_appointment_model.dart';
import '../../models/doctor_task_model.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';

class AppointmentsTasksScreen extends StatefulWidget {
  const AppointmentsTasksScreen({super.key});

  @override
  State<AppointmentsTasksScreen> createState() => _AppointmentsTasksScreenState();
}

class _AppointmentsTasksScreenState extends State<AppointmentsTasksScreen>
    with SingleTickerProviderStateMixin {
  final DataService _dataService = DataService();
  late TabController _tabController;
  List<DoctorAppointment> _appointments = [];
  List<DoctorTask> _tasks = [];
  bool _isLoading = false;
  String? _doctorId;
  DateTime _selectedDate = DateTime.now();
  bool _showWeekView = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final user = AuthHelper.getCurrentUser(context);
    if (user == null) return;
    _doctorId = user.id;
    setState(() => _isLoading = true);
    
    // تحميل المواعيد والمهام بشكل منفصل
    await Future.wait([
      _loadAppointments(),
      _loadTasks(),
    ], eagerError: false);
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadAppointments() async {
    if (_doctorId == null) return;
    try {
      final appointments = await _dataService.getDoctorAppointments(_doctorId!);
      setState(() {
        _appointments = appointments.cast<DoctorAppointment>();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل المواعيد: $e')),
        );
      }
    }
  }

  Future<void> _loadTasks() async {
    if (_doctorId == null) return;
    try {
      final tasks = await _dataService.getDoctorTasks(_doctorId!, isCompleted: false);
      setState(() {
        _tasks = tasks.cast<DoctorTask>();
      });
    } catch (e) {
      // المهام غير متاحة في الوضع الشبكي - لا نعرض خطأ
      if (mounted && e.toString().contains('UnimplementedError')) {
        // المهام غير متاحة - نترك القائمة فارغة
        setState(() {
          _tasks = [];
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل المهام: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المواعيد والمهام'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'المواعيد', icon: Icon(Icons.calendar_today)),
            Tab(text: 'المهام', icon: Icon(Icons.task)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAppointmentsTab(),
                _buildTasksTab(),
              ],
            ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: () => _showAddAppointmentDialog(),
              child: const Icon(Icons.add),
            )
          : FloatingActionButton(
              onPressed: () => _showAddTaskDialog(),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildAppointmentsTab() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final todayAppointments = _appointments.where((apt) {
      final aptDate = DateTime(apt.date.year, apt.date.month, apt.date.day);
      return aptDate.isAtSameMomentAs(startOfDay) ||
          (aptDate.isAfter(startOfDay) && aptDate.isBefore(endOfDay));
    }).toList();

    final upcomingAppointments = _appointments
        .where((apt) => apt.date.isAfter(endOfDay) &&
            apt.status != AppointmentStatus.cancelled &&
            apt.status != AppointmentStatus.completed)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final pastAppointments = _appointments
        .where((apt) => apt.date.isBefore(startOfDay) ||
            apt.status == AppointmentStatus.completed)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _showWeekView = !_showWeekView),
                  icon: Icon(_showWeekView ? Icons.view_day : Icons.view_week),
                  label: Text(_showWeekView ? 'عرض يومي' : 'عرض أسبوعي'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () => _selectDate(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (todayAppointments.isNotEmpty) ...[
            const Text(
              'مواعيد اليوم',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...todayAppointments.map((apt) => _buildAppointmentCard(apt)),
            const SizedBox(height: 16),
          ],
          if (upcomingAppointments.isNotEmpty) ...[
            const Text(
              'المواعيد القادمة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...upcomingAppointments.map((apt) => _buildAppointmentCard(apt)),
            const SizedBox(height: 16),
          ],
          if (pastAppointments.isNotEmpty) ...[
            const Text(
              'المواعيد السابقة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...pastAppointments.map((apt) => _buildAppointmentCard(apt)),
          ],
          if (_appointments.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('لا توجد مواعيد مجدولة'),
              ),
            ),
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
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(Icons.calendar_today, color: statusColor),
        ),
        title: Text(appointment.patientName ?? 'موعد بدون مريض'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('التاريخ: ${_formatDateTime(appointment.date)}'),
            if (appointment.type != null) Text('النوع: ${appointment.type}'),
            if (appointment.notes != null) Text('ملاحظات: ${appointment.notes}'),
            Chip(
              label: Text(statusText, style: const TextStyle(fontSize: 12)),
              backgroundColor: statusColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(color: statusColor),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            if (appointment.status != AppointmentStatus.confirmed)
              const PopupMenuItem(
                value: 'confirm',
                child: ListTile(
                  leading: Icon(Icons.check),
                  title: Text('تأكيد'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            if (appointment.status != AppointmentStatus.cancelled)
              const PopupMenuItem(
                value: 'cancel',
                child: ListTile(
                  leading: Icon(Icons.cancel),
                  title: Text('إلغاء'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            const PopupMenuItem(
              value: 'reschedule',
              child: ListTile(
                leading: Icon(Icons.edit_calendar),
                title: Text('إعادة جدولة'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('حذف', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          onSelected: (value) => _handleAppointmentAction(appointment, value.toString()),
        ),
      ),
    );
  }

  Widget _buildTasksTab() {
    final pendingTasks = _tasks.where((task) => !task.isCompleted).toList();
    final completedTasks = _tasks.where((task) => task.isCompleted).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (pendingTasks.isNotEmpty) ...[
            const Text(
              'المهام المعلقة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...pendingTasks.map((task) => _buildTaskCard(task)),
            const SizedBox(height: 16),
          ],
          if (completedTasks.isNotEmpty) ...[
            const Text(
              'المهام المكتملة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...completedTasks.map((task) => _buildTaskCard(task)),
          ],
          if (_tasks.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('لا توجد مهام'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(DoctorTask task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        value: task.isCompleted,
        onChanged: (value) => _toggleTask(task.id, value ?? false),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description != null) Text(task.description!),
            if (task.dueDate != null)
              Text(
                'تاريخ الاستحقاق: ${_formatDateTime(task.dueDate!)}',
                style: TextStyle(
                  color: task.dueDate!.isBefore(DateTime.now()) &&
                          !task.isCompleted
                      ? Colors.red
                      : null,
                ),
              ),
          ],
        ),
        secondary: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _deleteTask(task.id),
        ),
      ),
    );
  }

  Future<void> _showAddAppointmentDialog() async {
    final dateController = TextEditingController(
      text: _formatDate(DateTime.now()),
    );
    final timeController = TextEditingController(
      text: _formatTime(DateTime.now()),
    );
    final patientNameController = TextEditingController();
    final typeController = TextEditingController();
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة موعد جديد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dateController,
                decoration: const InputDecoration(
                  labelText: 'التاريخ',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    dateController.text = _formatDate(date);
                  }
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: timeController,
                decoration: const InputDecoration(
                  labelText: 'الوقت',
                  suffixIcon: Icon(Icons.access_time),
                ),
                readOnly: true,
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    timeController.text = _formatTimeOfDay(time);
                  }
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: patientNameController,
                decoration: const InputDecoration(labelText: 'اسم المريض (اختياري)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: typeController,
                decoration: const InputDecoration(labelText: 'نوع الموعد (اختياري)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
                maxLines: 3,
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
              if (dateController.text.isEmpty || timeController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى تحديد التاريخ والوقت')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );

    if (result == true && _doctorId != null) {
      try {
        final dateParts = dateController.text.split('/');
        final timeParts = timeController.text.split(':');
        final dateTime = DateTime(
          int.parse(dateParts[2]),
          int.parse(dateParts[1]),
          int.parse(dateParts[0]),
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
        );

        final appointment = DoctorAppointment(
          id: const Uuid().v4(),
          doctorId: _doctorId!,
          patientName: patientNameController.text.trim().isEmpty
              ? null
              : patientNameController.text.trim(),
          date: dateTime,
          status: AppointmentStatus.scheduled,
          type: typeController.text.trim().isEmpty ? null : typeController.text.trim(),
          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
          createdAt: DateTime.now(),
        );

        await _dataService.createAppointmentWithReminders(appointment);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إضافة الموعد بنجاح')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في إضافة الموعد: $e')),
          );
        }
      }
    }
  }

  Future<void> _showAddTaskDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime? dueDate;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مهمة جديدة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'عنوان المهمة *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'الوصف (اختياري)'),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (context, setState) {
                  return ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text(dueDate == null
                        ? 'تاريخ الاستحقاق (اختياري)'
                        : _formatDate(dueDate!)),
                    trailing: dueDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => dueDate = null),
                          )
                        : null,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => dueDate = date);
                      }
                    },
                  );
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
            onPressed: () {
              if (titleController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى إدخال عنوان المهمة')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );

    if (result == true && _doctorId != null) {
      try {
        final task = DoctorTask(
          id: const Uuid().v4(),
          doctorId: _doctorId!,
          title: titleController.text.trim(),
          description: descriptionController.text.trim().isEmpty
              ? null
              : descriptionController.text.trim(),
          dueDate: dueDate,
          isCompleted: false,
          createdAt: DateTime.now(),
        );

        await _dataService.createTask(task);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إضافة المهمة بنجاح')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في إضافة المهمة: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleAppointmentAction(
    DoctorAppointment appointment,
    String action,
  ) async {
    try {
      switch (action) {
        case 'confirm':
          await _dataService.updateAppointmentStatus(
            appointment.id,
            AppointmentStatus.confirmed,
          );
          break;
        case 'cancel':
          await _dataService.updateAppointmentStatus(
            appointment.id,
            AppointmentStatus.cancelled,
          );
          break;
        case 'reschedule':
          await _showRescheduleDialog(appointment);
          break;
        case 'delete':
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('تأكيد الحذف'),
              content: const Text('هل أنت متأكد من حذف هذا الموعد؟'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('حذف'),
                ),
              ],
            ),
          );
          if (confirm == true) {
            await _dataService.deleteAppointment(appointment.id);
          }
          break;
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    }
  }

  Future<void> _showRescheduleDialog(DoctorAppointment appointment) async {
    final dateController = TextEditingController(
      text: _formatDate(appointment.date),
    );
    final timeController = TextEditingController(
      text: _formatTime(appointment.date),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة جدولة الموعد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dateController,
              decoration: const InputDecoration(
                labelText: 'التاريخ الجديد',
                suffixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: appointment.date,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  dateController.text = _formatDate(date);
                }
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: timeController,
              decoration: const InputDecoration(
                labelText: 'الوقت الجديد',
                suffixIcon: Icon(Icons.access_time),
              ),
              readOnly: true,
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(appointment.date),
                );
                if (time != null) {
                  timeController.text = _formatTimeOfDay(time);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final dateParts = dateController.text.split('/');
        final timeParts = timeController.text.split(':');
        final newDateTime = DateTime(
          int.parse(dateParts[2]),
          int.parse(dateParts[1]),
          int.parse(dateParts[0]),
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
        );

        await _dataService.updateAppointment(
          appointment.id,
          date: newDateTime,
          status: AppointmentStatus.scheduled,
        );
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleTask(String taskId, bool isCompleted) async {
    try {
      await _dataService.toggleTaskCompletion(taskId, isCompleted);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    }
  }

  Future<void> _deleteTask(String taskId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذه المهمة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dataService.deleteTask(taskId);
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e')),
          );
        }
      }
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
      await _loadData();
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)} ${_formatTime(dateTime)}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

