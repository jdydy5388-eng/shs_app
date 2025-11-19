import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/hr_models.dart';
import '../../services/data_service.dart';
import 'create_certification_screen.dart';

class CertificationsManagementScreen extends StatefulWidget {
  const CertificationsManagementScreen({super.key});

  @override
  State<CertificationsManagementScreen> createState() => _CertificationsManagementScreenState();
}

class _CertificationsManagementScreenState extends State<CertificationsManagementScreen> {
  final DataService _dataService = DataService();
  List<CertificationModel> _certifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCertifications();
  }

  Future<void> _loadCertifications() async {
    setState(() => _isLoading = true);
    try {
      final certifications = await _dataService.getCertifications();
      setState(() {
        _certifications = certifications.cast<CertificationModel>();
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
          : _certifications.isEmpty
              ? const Center(child: Text('لا توجد شهادات'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _certifications.length,
                  itemBuilder: (context, index) {
                    return _buildCertificationCard(_certifications[index]);
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateCertificationScreen()),
        ).then((_) => _loadCertifications()),
        icon: const Icon(Icons.add),
        label: const Text('إضافة شهادة'),
      ),
    );
  }

  Widget _buildCertificationCard(CertificationModel cert) {
    final dateFormat = DateFormat('yyyy-MM-dd', 'ar');
    final isExpired = cert.expiryDate.isBefore(DateTime.now());
    
    final statusColor = {
      CertificationStatus.active: Colors.green,
      CertificationStatus.expired: Colors.red,
      CertificationStatus.pending: Colors.orange,
      CertificationStatus.revoked: Colors.grey,
    }[cert.status]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(Icons.card_membership, color: statusColor),
        ),
        title: Text(cert.certificateName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${cert.employeeName ?? cert.employeeId}'),
            Text('${cert.issuingOrganization}'),
            Text('ينتهي: ${dateFormat.format(cert.expiryDate)}'),
            if (isExpired)
              Text(
                'منتهية الصلاحية',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        trailing: Text(_getStatusText(cert.status)),
      ),
    );
  }

  String _getStatusText(CertificationStatus status) {
    return {
      CertificationStatus.active: 'نشط',
      CertificationStatus.expired: 'منتهي',
      CertificationStatus.pending: 'قيد التجديد',
      CertificationStatus.revoked: 'ملغى',
    }[status]!;
  }
}

