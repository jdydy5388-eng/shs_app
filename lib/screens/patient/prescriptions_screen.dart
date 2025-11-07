import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/prescription_model.dart';
import '../../providers/auth_provider_local.dart';
import '../../services/data_service.dart';

class PrescriptionsScreen extends StatefulWidget {
  const PrescriptionsScreen({super.key});

  @override
  State<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends State<PrescriptionsScreen> {
  final DataService _dataService = DataService();
  List<PrescriptionModel> _prescriptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrescriptions();
  }

  Future<void> _loadPrescriptions() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProviderLocal>(context, listen: false);
      final patientId = authProvider.currentUser?.id ?? '';
      final prescriptions = await _dataService.getPrescriptions(patientId: patientId);
      setState(() {
        _prescriptions = prescriptions.cast<PrescriptionModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الوصفات: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الوصفات الطبية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPrescriptions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _prescriptions.isEmpty
              ? const Center(child: Text('لا توجد وصفات طبية'))
              : RefreshIndicator(
                  onRefresh: _loadPrescriptions,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _prescriptions.length,
                    itemBuilder: (context, index) {
                      final prescription = _prescriptions[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ExpansionTile(
                          title: Text(prescription.diagnosis),
                          subtitle: Text('الطبيب: ${prescription.doctorName}'),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'التشخيص: ${prescription.diagnosis}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'الأدوية:',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  ...prescription.medications.map((med) => Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('• ${med.name}'),
                                            Text(
                                              '  الجرعة: ${med.dosage}',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                            Text(
                                              '  التكرار: ${med.frequency}',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                            Text(
                                              '  المدة: ${med.duration}',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      )),
                                  if (prescription.drugInteractions != null &&
                                      prescription.drugInteractions!.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'تحذيرات التفاعلات الدوائية:',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red,
                                            ),
                                          ),
                                          ...prescription.drugInteractions!
                                              .map((interaction) => Text(
                                                    '• $interaction',
                                                    style: const TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  )),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

