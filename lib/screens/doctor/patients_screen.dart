import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/data_service.dart';
import '../../widgets/loading_widgets.dart';
import '../../widgets/status_banner.dart';
import '../../utils/ui_snackbar.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final DataService _dataService = DataService();
  List<UserModel> _patients = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final patients = await _dataService.getPatients();
      setState(() {
        _patients = patients.cast<UserModel>();
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      if (mounted) {
        showFriendlyAuthError(context, e);
      }
    }
  }

  List<UserModel> get _filteredPatients {
    if (_searchQuery.isEmpty) return _patients;
    final query = _searchQuery.toLowerCase();
    return _patients.where((patient) {
      return patient.name.toLowerCase().contains(query) ||
          patient.email.toLowerCase().contains(query) ||
          patient.phone.contains(query) ||
          (patient.bloodType?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المرضى'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPatients,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'بحث عن مريض...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
          // رسالة الخطأ إن وجدت
          if (_errorMessage != null && !_isLoading)
            StatusBanner(
              message: 'فشل تحميل المرضى. اضغط على "إعادة المحاولة" للتحميل مرة أخرى.',
              type: StatusBannerType.error,
              onDismiss: () {
                setState(() => _errorMessage = null);
              },
            ),
          // المحتوى الرئيسي
          Expanded(
            child: _isLoading
                ? const ListSkeletonLoader(itemCount: 6)
                : _filteredPatients.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.people_outline,
                        title: _searchQuery.isNotEmpty
                            ? 'لا توجد نتائج للبحث'
                            : 'لا يوجد مرضى',
                        subtitle: _searchQuery.isNotEmpty
                            ? 'جرب البحث بكلمات مختلفة'
                            : 'لم يتم إضافة أي مرضى بعد',
                        action: _searchQuery.isEmpty
                            ? ElevatedButton.icon(
                                onPressed: _loadPatients,
                                icon: const Icon(Icons.refresh),
                                label: const Text('تحديث'),
                              )
                            : null,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadPatients,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredPatients.length,
                          itemBuilder: (context, index) {
                            final patient = _filteredPatients[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue.shade100,
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                                title: Text(
                                  patient.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.email, size: 14, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            patient.email,
                                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Text(
                                          patient.phone,
                                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                        ),
                                      ],
                                    ),
                                    if (patient.bloodType != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.bloodtype, size: 14, color: Colors.red[300]),
                                          const SizedBox(width: 4),
                                          Text(
                                            'فصيلة الدم: ${patient.bloodType}',
                                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey[400],
                                ),
                                onTap: () {
                                  // TODO: فتح تفاصيل المريض
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

