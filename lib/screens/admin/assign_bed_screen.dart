import 'package:flutter/material.dart';
import '../../models/room_bed_model.dart';
import '../../models/user_model.dart';
import '../../services/data_service.dart';

class AssignBedScreen extends StatefulWidget {
  final BedModel bed;

  const AssignBedScreen({super.key, required this.bed});

  @override
  State<AssignBedScreen> createState() => _AssignBedScreenState();
}

class _AssignBedScreenState extends State<AssignBedScreen> {
  final DataService _dataService = DataService();
  List<UserModel> _patients = [];
  UserModel? _selectedPatient;
  bool _isLoading = true;
  bool _isAssigning = false;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() => _isLoading = true);
    try {
      final patients = await _dataService.getPatients();
      setState(() {
        _patients = patients.cast<UserModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل المرضى: $e')),
        );
      }
    }
  }

  Future<void> _assignBed() async {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار مريض')),
      );
      return;
    }

    setState(() => _isAssigning = true);
    try {
      await _dataService.assignBed(widget.bed.id, _selectedPatient!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حجز السرير بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isAssigning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حجز السرير: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حجز سرير'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'معلومات السرير',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('التسمية: ${widget.bed.label}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'اختر المريض',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (_selectedPatient == null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showPatientSelector(),
                        icon: const Icon(Icons.person_add),
                        label: const Text('اختر مريض'),
                      ),
                    )
                  else
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(_selectedPatient!.name),
                        subtitle: Text(_selectedPatient!.email ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _selectedPatient = null),
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isAssigning ? null : _assignBed,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: _isAssigning
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('حجز السرير'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showPatientSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر مريض'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _patients.length,
            itemBuilder: (context, index) {
              final patient = _patients[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(patient.name),
                subtitle: Text(patient.email ?? ''),
                onTap: () {
                  setState(() => _selectedPatient = patient);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

