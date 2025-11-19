import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/emergency_case_model.dart';
import '../../models/emergency_event_model.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';

class EmergencyEventsScreen extends StatefulWidget {
  final String caseId;

  const EmergencyEventsScreen({super.key, required this.caseId});

  @override
  State<EmergencyEventsScreen> createState() => _EmergencyEventsScreenState();
}

class _EmergencyEventsScreenState extends State<EmergencyEventsScreen> {
  final DataService _dataService = DataService();
  List<EmergencyEventModel> _events = [];
  EmergencyCaseModel? _case;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final events = await _dataService.getEmergencyEvents(caseId: widget.caseId);
      setState(() {
        _events = events.cast<EmergencyEventModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الأحداث: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل أحداث الطوارئ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _buildEventsList(),
            ),
    );
  }

  Widget _buildEventsList() {
    if (_events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد أحداث مسجلة',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _events.length,
      itemBuilder: (context, index) {
        final event = _events[index];
        return _buildEventCard(event);
      },
    );
  }

  Widget _buildEventCard(EmergencyEventModel event) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm', 'ar');

    final eventTypeText = {
      'intake': 'دخول',
      'update_vitals': 'تحديث العلامات الحيوية',
      'medication': 'إعطاء دواء',
      'imaging': 'طلب تصوير',
      'lab_request': 'طلب فحص مخبري',
      'transfer': 'تحويل',
      'discharge': 'إفراج',
    }[event.eventType] ?? event.eventType;

    final eventIcon = {
      'intake': Icons.local_hospital,
      'update_vitals': Icons.favorite,
      'medication': Icons.medication,
      'imaging': Icons.image,
      'lab_request': Icons.science,
      'transfer': Icons.transfer_within_a_station,
      'discharge': Icons.exit_to_app,
    }[event.eventType] ?? Icons.event;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withValues(alpha: 0.2),
          child: Icon(eventIcon, color: Colors.blue),
        ),
        title: Text(
          eventTypeText,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('التاريخ: ${dateFormat.format(event.createdAt)}'),
            if (event.details != null && event.details!.isNotEmpty)
              ...event.details!.entries.map((entry) => 
                Text('${entry.key}: ${entry.value}'),
              ),
          ],
        ),
      ),
    );
  }
}

