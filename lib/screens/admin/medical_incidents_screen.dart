import 'package:flutter/material.dart';
import '../../models/quality_models.dart';
import '../../services/data_service.dart';
import 'create_incident_screen.dart';

class MedicalIncidentsScreen extends StatefulWidget {
  const MedicalIncidentsScreen({super.key});

  @override
  State<MedicalIncidentsScreen> createState() => _MedicalIncidentsScreenState();
}

class _MedicalIncidentsScreenState extends State<MedicalIncidentsScreen> {
  final DataService _dataService = DataService();
  List<MedicalIncidentModel> _incidents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadIncidents();
  }

  Future<void> _loadIncidents() async {
    setState(() => _isLoading = true);
    try {
      final incidents = await _dataService.getMedicalIncidents();
      setState(() {
        _incidents = incidents.cast<MedicalIncidentModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الحوادث: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _incidents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('لا توجد حوادث طبية', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _incidents.length,
                  itemBuilder: (context, index) {
                    final incident = _incidents[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getSeverityColor(incident.severity).withValues(alpha: 0.2),
                          child: Icon(
                            Icons.warning,
                            color: _getSeverityColor(incident.severity),
                          ),
                        ),
                        title: Text(incident.description),
                        subtitle: Text('${_getTypeText(incident.type)} - ${_getSeverityText(incident.severity)}'),
                        trailing: Text(_getStatusText(incident.status)),
                        onTap: () {
                          // TODO: Navigate to incident details
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateIncidentScreen()),
        ).then((_) => _loadIncidents()),
        icon: const Icon(Icons.add),
        label: const Text('إضافة حادث'),
      ),
    );
  }

  Color _getSeverityColor(IncidentSeverity severity) {
    switch (severity) {
      case IncidentSeverity.low:
        return Colors.green;
      case IncidentSeverity.medium:
        return Colors.yellow;
      case IncidentSeverity.high:
        return Colors.orange;
      case IncidentSeverity.critical:
        return Colors.red;
    }
  }

  String _getSeverityText(IncidentSeverity severity) {
    return {
      IncidentSeverity.low: 'منخفضة',
      IncidentSeverity.medium: 'متوسطة',
      IncidentSeverity.high: 'عالية',
      IncidentSeverity.critical: 'حرجة',
    }[severity]!;
  }

  String _getTypeText(IncidentType type) {
    return {
      IncidentType.medicationError: 'خطأ دوائي',
      IncidentType.fall: 'سقوط',
      IncidentType.infection: 'عدوى',
      IncidentType.equipmentFailure: 'عطل معدات',
      IncidentType.procedureError: 'خطأ في الإجراء',
      IncidentType.documentationError: 'خطأ في التوثيق',
      IncidentType.communicationError: 'خطأ في التواصل',
      IncidentType.other: 'أخرى',
    }[type]!;
  }

  String _getStatusText(IncidentStatus status) {
    return {
      IncidentStatus.reported: 'تم الإبلاغ',
      IncidentStatus.underInvestigation: 'قيد التحقيق',
      IncidentStatus.resolved: 'تم الحل',
      IncidentStatus.closed: 'مغلق',
    }[status]!;
  }
}

