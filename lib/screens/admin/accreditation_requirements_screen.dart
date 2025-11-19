import 'package:flutter/material.dart';
import '../../models/quality_models.dart';
import '../../services/data_service.dart';

class AccreditationRequirementsScreen extends StatefulWidget {
  const AccreditationRequirementsScreen({super.key});

  @override
  State<AccreditationRequirementsScreen> createState() => _AccreditationRequirementsScreenState();
}

class _AccreditationRequirementsScreenState extends State<AccreditationRequirementsScreen> {
  final DataService _dataService = DataService();
  List<AccreditationRequirementModel> _requirements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequirements();
  }

  Future<void> _loadRequirements() async {
    setState(() => _isLoading = true);
    try {
      final requirements = await _dataService.getAccreditationRequirements();
      setState(() {
        _requirements = requirements.cast<AccreditationRequirementModel>();
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
          : _requirements.isEmpty
              ? const Center(child: Text('لا توجد متطلبات اعتماد'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _requirements.length,
                  itemBuilder: (context, index) {
                    final req = _requirements[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(req.title),
                        subtitle: Text(req.description),
                        trailing: Text(_getStatusText(req.status)),
                      ),
                    );
                  },
                ),
    );
  }

  String _getStatusText(AccreditationStatus status) {
    return {
      AccreditationStatus.notStarted: 'لم يبدأ',
      AccreditationStatus.inProgress: 'قيد التنفيذ',
      AccreditationStatus.compliant: 'متوافق',
      AccreditationStatus.nonCompliant: 'غير متوافق',
      AccreditationStatus.certified: 'معتمد',
    }[status]!;
  }
}

