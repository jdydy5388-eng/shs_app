import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/hr_models.dart';
import '../../services/data_service.dart';
import 'create_training_screen.dart';

class TrainingManagementScreen extends StatefulWidget {
  const TrainingManagementScreen({super.key});

  @override
  State<TrainingManagementScreen> createState() => _TrainingManagementScreenState();
}

class _TrainingManagementScreenState extends State<TrainingManagementScreen> {
  final DataService _dataService = DataService();
  List<TrainingModel> _trainings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrainings();
  }

  Future<void> _loadTrainings() async {
    setState(() => _isLoading = true);
    try {
      final trainings = await _dataService.getTrainings();
      setState(() {
        _trainings = trainings.cast<TrainingModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trainings.isEmpty
              ? const Center(child: Text('لا توجد برامج تدريبية'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _trainings.length,
                  itemBuilder: (context, index) {
                    return _buildTrainingCard(_trainings[index]);
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateTrainingScreen()),
        ).then((_) => _loadTrainings()),
        icon: const Icon(Icons.add),
        label: const Text('إضافة برنامج تدريبي'),
      ),
    );
  }

  Widget _buildTrainingCard(TrainingModel training) {
    final dateFormat = DateFormat('yyyy-MM-dd', 'ar');
    
    final statusColor = {
      TrainingStatus.scheduled: Colors.blue,
      TrainingStatus.inProgress: Colors.orange,
      TrainingStatus.completed: Colors.green,
      TrainingStatus.cancelled: Colors.grey,
    }[training.status]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(Icons.school, color: statusColor),
        ),
        title: Text(training.title),
        subtitle: Text(
          '${dateFormat.format(training.startDate)} - ${dateFormat.format(training.endDate)}',
        ),
        trailing: Text(_getStatusText(training.status)),
      ),
    );
  }

  String _getStatusText(TrainingStatus status) {
    return {
      TrainingStatus.scheduled: 'مجدول',
      TrainingStatus.inProgress: 'قيد التنفيذ',
      TrainingStatus.completed: 'مكتمل',
      TrainingStatus.cancelled: 'ملغى',
    }[status]!;
  }
}

