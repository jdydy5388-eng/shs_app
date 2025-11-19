import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../models/lab_request_model.dart';
import '../../models/lab_test_type_model.dart';
import '../../services/data_service.dart';

class LabCriticalAlertsScreen extends StatefulWidget {
  const LabCriticalAlertsScreen({super.key});

  @override
  State<LabCriticalAlertsScreen> createState() => _LabCriticalAlertsScreenState();
}

class _LabCriticalAlertsScreenState extends State<LabCriticalAlertsScreen> {
  final DataService _dataService = DataService();
  List<Map<String, dynamic>> _criticalAlerts = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadCriticalAlerts();
    // تحديث تلقائي كل 30 ثانية
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadCriticalAlerts());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCriticalAlerts() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    try {
      // جلب جميع طلبات الفحوصات
      final requests = await _dataService.getLabRequests();
      final requestsList = requests.cast<LabRequestModel>();

      // جلب جميع النتائج
      final alerts = <Map<String, dynamic>>[];
      
      for (final request in requestsList) {
        if (request.status == LabRequestStatus.completed) {
          try {
            final result = await _dataService.getLabResult(request.id);
            if (result != null && result.isCritical) {
              alerts.add({
                'request': request,
                'result': result,
                'priority': 'critical',
              });
            }
          } catch (e) {
            // تجاهل الأخطاء
          }
        }
      }

      // جلب الفحوصات العاجلة
      final urgentRequests = requestsList.where((r) => 
        r.status == LabRequestStatus.pending || 
        r.status == LabRequestStatus.inProgress
      ).toList();

      for (final request in urgentRequests) {
        // يمكن إضافة منطق للتحقق من الأولوية
        alerts.add({
          'request': request,
          'result': null,
          'priority': 'urgent',
        });
      }

      setState(() {
        _criticalAlerts = alerts;
        _isLoading = false;
      });

      // عرض تنبيه إذا كان هناك حالات حرجة جديدة
      if (alerts.any((a) => a['priority'] == 'critical')) {
        _showCriticalAlert(alerts.where((a) => a['priority'] == 'critical').length);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل التنبيهات: $e')),
        );
      }
    }
  }

  void _showCriticalAlert(int count) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تنبيه: $count فحص حرج يحتاج مراجعة فورية!',
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'عرض',
          textColor: Colors.white,
          onPressed: () {
            // التمرير إلى الأعلى
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تنبيهات الفحوصات الحرجة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCriticalAlerts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCriticalAlerts,
              child: _criticalAlerts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد تنبيهات حرجة',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _criticalAlerts.length,
                      itemBuilder: (context, index) {
                        final alert = _criticalAlerts[index];
                        return _buildAlertCard(alert);
                      },
                    ),
            ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final request = alert['request'] as LabRequestModel;
    final result = alert['result'] as LabResultModel?;
    final priority = alert['priority'] as String;
    
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm', 'ar');
    final isCritical = priority == 'critical';
    final color = isCritical ? Colors.red : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isCritical ? 4 : 2,
      color: isCritical ? Colors.red.shade50 : Colors.orange.shade50,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(
            isCritical ? Icons.warning : Icons.priority_high,
            color: color,
          ),
        ),
        title: Text(
          request.testType,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المريض: ${request.patientName}'),
            if (request.diagnosisName != null)
              Text('الحالة: ${request.diagnosisName}'),
            Text('التاريخ: ${dateFormat.format(request.requestedAt)}'),
            if (result != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'النتائج الحرجة:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    ...result.results.entries.map((entry) => Text(
                      '${entry.key}: ${entry.value}',
                      style: const TextStyle(color: Colors.red),
                    )),
                    if (result.interpretation != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'التفسير: ${result.interpretation}',
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
        trailing: Icon(
          isCritical ? Icons.error : Icons.priority_high,
          color: color,
        ),
        onTap: () {
          // يمكن إضافة شاشة تفاصيل
        },
      ),
    );
  }
}

