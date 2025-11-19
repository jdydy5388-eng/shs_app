import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/nursing_note_model.dart';
import '../../providers/auth_provider_local.dart';
import '../../services/data_service.dart';

class NursingNotesScreen extends StatefulWidget {
  const NursingNotesScreen({super.key});

  @override
  State<NursingNotesScreen> createState() => _NursingNotesScreenState();
}

class _NursingNotesScreenState extends State<NursingNotesScreen> {
  final DataService _dataService = DataService();
  List<NursingNoteModel> _notes = [];
  bool _isLoading = true;
  String? _filterPatientId;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProviderLocal>(context, listen: false);
      final nurseId = authProvider.currentUser?.id ?? '';
      
      // TODO: سيتم إضافة getNursingNotes في DataService
      // final notes = await _dataService.getNursingNotes(nurseId: nurseId, patientId: _filterPatientId);
      
      // مؤقتاً: قائمة فارغة
      setState(() {
        _notes = [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل السجلات: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل التمريض'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotes,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadNotes,
              child: _buildNotesList(),
            ),
    );
  }

  Widget _buildNotesList() {
    if (_notes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.note_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد سجلات تمريض',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _notes.length,
      itemBuilder: (context, index) {
        final note = _notes[index];
        return _buildNoteCard(note);
      },
    );
  }

  Widget _buildNoteCard(NursingNoteModel note) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm', 'ar');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: const CircleAvatar(
          child: Icon(Icons.note),
        ),
        title: Text(
          note.patientName ?? 'مريض',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('التاريخ: ${dateFormat.format(note.createdAt)}'),
            if (note.nurseName != null) Text('الممرض: ${note.nurseName}'),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'السجل:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(note.note),
                if (note.vitalSigns != null && note.vitalSigns!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'العلامات الحيوية:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...note.vitalSigns!.entries.map((entry) => 
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Text(
                            '${entry.key}: ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('${entry.value}'),
                        ],
                      ),
                    ),
                  ),
                ],
                if (note.observations != null && note.observations!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'الملاحظات:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(note.observations!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

