import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/nursing_task_model.dart';
import '../../providers/auth_provider_local.dart';
import '../../services/data_service.dart';

class NurseTasksScreen extends StatefulWidget {
  const NurseTasksScreen({super.key});

  @override
  State<NurseTasksScreen> createState() => _NurseTasksScreenState();
}

class _NurseTasksScreenState extends State<NurseTasksScreen> {
  final DataService _dataService = DataService();
  List<NursingTaskModel> _tasks = [];
  bool _isLoading = true;
  NursingTaskStatus? _filterStatus;
  NursingTaskType? _filterType;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProviderLocal>(context, listen: false);
      final nurseId = authProvider.currentUser?.id ?? '';
      
      // TODO: سيتم إضافة getNursingTasks في DataService
      // final tasks = await _dataService.getNursingTasks(nurseId: nurseId);
      // setState(() {
      //   _tasks = tasks.cast<NursingTaskModel>();
      //   _isLoading = false;
      // });
      
      // مؤقتاً: قائمة فارغة
      setState(() {
        _tasks = [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل المهام: $e')),
        );
      }
    }
  }

  List<NursingTaskModel> get _filteredTasks {
    var filtered = _tasks;
    
    if (_filterStatus != null) {
      filtered = filtered.where((t) => t.status == _filterStatus).toList();
    }
    
    if (_filterType != null) {
      filtered = filtered.where((t) => t.type == _filterType).toList();
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مهام التمريض'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              if (value == 'status') {
                _showStatusFilter();
              } else if (value == 'type') {
                _showTypeFilter();
              } else if (value == 'clear') {
                setState(() {
                  _filterStatus = null;
                  _filterType = null;
                });
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'status',
                child: Text('فلترة حسب الحالة'),
              ),
              const PopupMenuItem(
                value: 'type',
                child: Text('فلترة حسب النوع'),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Text('إزالة الفلاتر'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddTaskDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTasks,
              child: _buildTasksList(),
            ),
    );
  }

  Widget _buildTasksList() {
    final filtered = _filteredTasks;

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.task_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _tasks.isEmpty
                    ? 'لا توجد مهام حالياً'
                    : 'لا توجد مهام تطابق الفلتر',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final task = filtered[index];
        return _buildTaskCard(task);
      },
    );
  }

  Widget _buildTaskCard(NursingTaskModel task) {
    final statusColor = {
      NursingTaskStatus.pending: Colors.orange,
      NursingTaskStatus.inProgress: Colors.blue,
      NursingTaskStatus.completed: Colors.green,
      NursingTaskStatus.cancelled: Colors.red,
    }[task.status]!;

    final statusText = {
      NursingTaskStatus.pending: 'قيد الانتظار',
      NursingTaskStatus.inProgress: 'قيد التنفيذ',
      NursingTaskStatus.completed: 'مكتملة',
      NursingTaskStatus.cancelled: 'ملغاة',
    }[task.status]!;

    final typeText = {
      NursingTaskType.medication: 'إعطاء دواء',
      NursingTaskType.vitalSigns: 'قياس علامات حيوية',
      NursingTaskType.woundCare: 'عناية بالجروح',
      NursingTaskType.patientCheck: 'فحص مريض',
      NursingTaskType.documentation: 'توثيق',
      NursingTaskType.other: 'أخرى',
    }[task.type]!;

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm', 'ar');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(_getTaskIcon(task.type), color: statusColor),
        ),
        title: Text(
          task.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('النوع: $typeText'),
            if (task.patientName != null) Text('المريض: ${task.patientName}'),
            Text('المجدولة: ${dateFormat.format(task.scheduledAt)}'),
            Chip(
              label: Text(statusText, style: const TextStyle(fontSize: 12)),
              backgroundColor: statusColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(color: statusColor),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task.description != null && task.description!.isNotEmpty) ...[
                  const Text(
                    'الوصف:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(task.description!),
                  const SizedBox(height: 16),
                ],
                if (task.resultData != null && task.resultData!.isNotEmpty) ...[
                  const Text(
                    'النتائج:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  ...task.resultData!.entries.map((entry) => 
                    Text('${entry.key}: ${entry.value}'),
                  ),
                  const SizedBox(height: 16),
                ],
                if (task.status != NursingTaskStatus.completed &&
                    task.status != NursingTaskStatus.cancelled) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (task.status == NursingTaskStatus.pending)
                        ElevatedButton.icon(
                          onPressed: () => _updateTaskStatus(task, NursingTaskStatus.inProgress),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('بدء التنفيذ'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      if (task.status == NursingTaskStatus.inProgress)
                        ElevatedButton.icon(
                          onPressed: () => _showCompleteTaskDialog(task),
                          icon: const Icon(Icons.check),
                          label: const Text('إكمال المهمة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTaskIcon(NursingTaskType type) {
    switch (type) {
      case NursingTaskType.medication:
        return Icons.medication;
      case NursingTaskType.vitalSigns:
        return Icons.favorite;
      case NursingTaskType.woundCare:
        return Icons.healing;
      case NursingTaskType.patientCheck:
        return Icons.person_search;
      case NursingTaskType.documentation:
        return Icons.description;
      case NursingTaskType.other:
        return Icons.task;
    }
  }

  Future<void> _updateTaskStatus(NursingTaskModel task, NursingTaskStatus newStatus) async {
    try {
      // TODO: سيتم إضافة updateNursingTask في DataService
      // await _dataService.updateNursingTask(task.id, status: newStatus);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث حالة المهمة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        _loadTasks();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحديث الحالة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showCompleteTaskDialog(NursingTaskModel task) async {
    final resultData = <String, dynamic>{};
    
    // إذا كانت المهمة قياس علامات حيوية، نطلب إدخال القيم
    if (task.type == NursingTaskType.vitalSigns) {
      final bpController = TextEditingController();
      final pulseController = TextEditingController();
      final tempController = TextEditingController();
      final respController = TextEditingController();
      final spo2Controller = TextEditingController();

      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('إكمال المهمة - قياس العلامات الحيوية'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: bpController,
                  decoration: const InputDecoration(
                    labelText: 'ضغط الدم (مثال: 120/80)',
                  ),
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pulseController,
                  decoration: const InputDecoration(
                    labelText: 'النبض (نبضة/دقيقة)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: tempController,
                  decoration: const InputDecoration(
                    labelText: 'درجة الحرارة (°C)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: respController,
                  decoration: const InputDecoration(
                    labelText: 'معدل التنفس (نفس/دقيقة)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: spo2Controller,
                  decoration: const InputDecoration(
                    labelText: 'الأكسجين (SpO2 %)',
                  ),
                  keyboardType: TextInputType.number,
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
                resultData['bloodPressure'] = bpController.text.trim();
                resultData['pulse'] = pulseController.text.trim();
                resultData['temperature'] = tempController.text.trim();
                resultData['respiration'] = respController.text.trim();
                resultData['spo2'] = spo2Controller.text.trim();
                Navigator.pop(context, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      );

      if (result != true) return;
    } else {
      final notesController = TextEditingController();
      
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('إكمال المهمة'),
          content: TextField(
            controller: notesController,
            decoration: const InputDecoration(
              labelText: 'ملاحظات (اختياري)',
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (notesController.text.trim().isNotEmpty) {
                  resultData['notes'] = notesController.text.trim();
                }
                Navigator.pop(context, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      );

      if (result != true) return;
    }

    try {
      final authProvider = Provider.of<AuthProviderLocal>(context, listen: false);
      final nurseId = authProvider.currentUser?.id ?? '';
      
      // TODO: سيتم إضافة updateNursingTask في DataService
      // await _dataService.updateNursingTask(
      //   task.id,
      //   status: NursingTaskStatus.completed,
      //   resultData: resultData.isNotEmpty ? resultData : null,
      //   completedBy: nurseId,
      // );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إكمال المهمة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        _loadTasks();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إكمال المهمة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAddTaskDialog() async {
    // TODO: سيتم إضافة هذه الوظيفة لاحقاً
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('سيتم إضافة هذه الميزة قريباً')),
    );
  }

  void _showStatusFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فلترة حسب الحالة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<NursingTaskStatus?>(
              title: const Text('جميع الحالات'),
              value: null,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<NursingTaskStatus?>(
              title: const Text('قيد الانتظار'),
              value: NursingTaskStatus.pending,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<NursingTaskStatus?>(
              title: const Text('قيد التنفيذ'),
              value: NursingTaskStatus.inProgress,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<NursingTaskStatus?>(
              title: const Text('مكتملة'),
              value: NursingTaskStatus.completed,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTypeFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فلترة حسب النوع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<NursingTaskType?>(
              title: const Text('جميع الأنواع'),
              value: null,
              groupValue: _filterType,
              onChanged: (value) {
                setState(() => _filterType = value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<NursingTaskType?>(
              title: const Text('إعطاء دواء'),
              value: NursingTaskType.medication,
              groupValue: _filterType,
              onChanged: (value) {
                setState(() => _filterType = value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<NursingTaskType?>(
              title: const Text('قياس علامات حيوية'),
              value: NursingTaskType.vitalSigns,
              groupValue: _filterType,
              onChanged: (value) {
                setState(() => _filterType = value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<NursingTaskType?>(
              title: const Text('عناية بالجروح'),
              value: NursingTaskType.woundCare,
              groupValue: _filterType,
              onChanged: (value) {
                setState(() => _filterType = value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<NursingTaskType?>(
              title: const Text('فحص مريض'),
              value: NursingTaskType.patientCheck,
              groupValue: _filterType,
              onChanged: (value) {
                setState(() => _filterType = value);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

