import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/attendance_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider_local.dart';
import '../../services/data_service.dart';
import '../../utils/ui_snackbar.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final DataService _dataService = DataService();
  bool _loading = false;
  List<AttendanceRecord> _records = [];
  AttendanceRecord? _openRecord;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final auth = Provider.of<AuthProviderLocal>(context, listen: false);
      final user = auth.currentUser;
      if (user == null) throw Exception('لم يتم العثور على المستخدم');
      final list = await _dataService.getAttendance(userId: user.id) as List;
      final records = list.cast<AttendanceRecord>();
      AttendanceRecord? open;
      for (final r in records) {
        if (r.checkOut == null) {
          open = r;
          break;
        }
      }
      setState(() {
        _records = records;
        _openRecord = open;
      });
    } catch (e) { if (mounted) showFriendlyAuthError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkIn() async {
    try {
      setState(() => _loading = true);
      final auth = Provider.of<AuthProviderLocal>(context, listen: false);
      final user = auth.currentUser as UserModel;
      final record = AttendanceRecord(
        id: _dataService.generateId(),
        userId: user.id,
        role: user.role.toString().split('.').last,
        checkIn: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await _dataService.createAttendance(record);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الدخول')));
      }
    } catch (e) { if (mounted) showFriendlyAuthError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkOut() async {
    try {
      if (_openRecord == null) return;
      setState(() => _loading = true);
      await _dataService.updateAttendance(_openRecord!.id, checkOut: DateTime.now());
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الخروج')));
      }
    } catch (e) { if (mounted) showFriendlyAuthError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    return Scaffold(
      appBar: AppBar(title: const Text('الحضور')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading || _openRecord != null ? null : _checkIn,
                    icon: const Icon(Icons.login),
                    label: const Text('تسجيل دخول'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading || _openRecord == null ? null : _checkOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('تسجيل خروج'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: _records.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (context, index) {
                      final r = _records[index];
                      return ListTile(
                        leading: Icon(
                          r.checkOut == null ? Icons.access_time : Icons.check_circle,
                          color: r.checkOut == null ? Colors.orange : Colors.green,
                        ),
                        title: Text('دخول: ${fmt.format(r.checkIn)}'),
                        subtitle: Text(r.checkOut != null ? 'خروج: ${fmt.format(r.checkOut!)}' : 'قيد العمل'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}


