import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../services/data_service.dart';
import '../../models/attendance_model.dart';

class ShiftsManagementScreen extends StatefulWidget {
  const ShiftsManagementScreen({super.key});

  @override
  State<ShiftsManagementScreen> createState() => _ShiftsManagementScreenState();
}

class _ShiftsManagementScreenState extends State<ShiftsManagementScreen> {
  final DataService _dataService = DataService();
  bool _loading = false;
  List<ShiftModel> _shifts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _dataService.getShifts() as List;
      setState(() => _shifts = list.cast<ShiftModel>());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateDialog() async {
    final userIdController = TextEditingController();
    final roleController = TextEditingController(text: 'doctor');
    final deptController = TextEditingController();
    final recurrence = ValueNotifier<String>('none');
    DateTime? start;
    DateTime? end;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنشاء مناوبة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: userIdController, decoration: const InputDecoration(labelText: 'معرّف المستخدم')),
              TextField(controller: roleController, decoration: const InputDecoration(labelText: 'الدور (doctor/nurse/...)')),
              TextField(controller: deptController, decoration: const InputDecoration(labelText: 'القسم')),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          initialDate: DateTime.now(),
                        );
                        if (picked != null) {
                          final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                          if (t != null) {
                            start = DateTime(picked.year, picked.month, picked.day, t.hour, t.minute);
                            setState(() {});
                          }
                        }
                      },
                      child: Text(start == null ? 'بداية المناوبة' : DateFormat('yyyy-MM-dd HH:mm').format(start!)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          initialDate: DateTime.now(),
                        );
                        if (picked != null) {
                          final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                          if (t != null) {
                            end = DateTime(picked.year, picked.month, picked.day, t.hour, t.minute);
                            setState(() {});
                          }
                        }
                      },
                      child: Text(end == null ? 'نهاية المناوبة' : DateFormat('yyyy-MM-dd HH:mm').format(end!)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<String>(
                valueListenable: recurrence,
                builder: (_, value, __) => DropdownButtonFormField<String>(
                  value: value,
                  decoration: const InputDecoration(labelText: 'التكرار'),
                  onChanged: (v) => recurrence.value = v ?? 'none',
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('بدون')),
                    DropdownMenuItem(value: 'daily', child: Text('يومي')),
                    DropdownMenuItem(value: 'weekly', child: Text('أسبوعي')),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
        ],
      ),
    );

    if (result == true && start != null && end != null && userIdController.text.trim().isNotEmpty) {
      try {
        final shift = ShiftModel(
          id: const Uuid().v4(),
          userId: userIdController.text.trim(),
          role: roleController.text.trim(),
          startTime: start!,
          endTime: end!,
          department: deptController.text.trim().isEmpty ? null : deptController.text.trim(),
          recurrence: recurrence.value == 'none' ? null : recurrence.value,
          createdAt: DateTime.now(),
        );
        await _dataService.createShift(shift);
        await _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء المناوبة')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  Future<void> _deleteShift(ShiftModel shift) async {
    try {
      await _dataService.deleteShift(shift.id);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المناوبات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openCreateDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _shifts.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (context, index) {
                final s = _shifts[index];
                return ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text('${fmt.format(s.startTime)} → ${fmt.format(s.endTime)}'),
                  subtitle: Text('المستخدم: ${s.userId} • الدور: ${s.role}${s.department != null ? ' • ${s.department}' : ''}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteShift(s),
                  ),
                );
              },
            ),
    );
  }
}


