import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/doctor_appointment_model.dart';
import '../../providers/auth_provider_local.dart';
import '../../services/data_service.dart';
import '../../services/invoice_auto_service.dart';
import '../../utils/ui_snackbar.dart';
import 'package:uuid/uuid.dart';

class CreatePatientScreen extends StatefulWidget {
  const CreatePatientScreen({super.key});

  @override
  State<CreatePatientScreen> createState() => _CreatePatientScreenState();
}

class _CreatePatientScreenState extends State<CreatePatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _bloodTypeController = TextEditingController();
  final _appointmentFeeController = TextEditingController(text: '100');
  final DataService _dataService = DataService();
  final InvoiceAutoService _invoiceService = InvoiceAutoService();
  final Uuid _uuid = const Uuid();
  bool _isLoading = false;
  List<UserModel> _doctors = [];
  UserModel? _selectedDoctor;
  DateTime _appointmentDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _appointmentTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _bloodTypeController.dispose();
    _appointmentFeeController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    try {
      final doctors = await _dataService.getUsers(role: UserRole.doctor);
      setState(() {
        _doctors = doctors.cast<UserModel>();
      });
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _createPatient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProviderLocal>(context, listen: false);
      
      final additionalInfo = {
        'bloodType': _bloodTypeController.text.trim().isEmpty 
            ? 'غير محدد' 
            : _bloodTypeController.text.trim(),
      };

      // التحقق من اختيار الطبيب
      if (_selectedDoctor == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يرجى اختيار الطبيب'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // التحقق من مبلغ الحجز
      final appointmentFee = double.tryParse(_appointmentFeeController.text.trim());
      if (appointmentFee == null || appointmentFee <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يرجى إدخال مبلغ الحجز صحيح'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final success = await authProvider.registerUser(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        role: UserRole.patient,
        additionalInfo: additionalInfo,
      );

      if (success && mounted) {
        // جلب بيانات المريض المُسجل حديثاً
        final patients = await _dataService.getPatients();
        final newPatient = patients.firstWhere(
          (p) => p.email == _emailController.text.trim(),
          orElse: () => throw Exception('لم يتم العثور على المريض المُسجل'),
        );

        // إنشاء الموعد
        final appointmentDateTime = DateTime(
          _appointmentDate.year,
          _appointmentDate.month,
          _appointmentDate.day,
          _appointmentTime.hour,
          _appointmentTime.minute,
        );

        final appointment = DoctorAppointment(
          id: _uuid.v4(),
          doctorId: _selectedDoctor!.id,
          patientId: newPatient.id,
          patientName: newPatient.name,
          date: appointmentDateTime,
          status: AppointmentStatus.scheduled,
          type: 'استشارة طبية',
          notes: 'تم الحجز من قبل موظف الاستقبال عند التسجيل',
          createdAt: DateTime.now(),
        );

        await _dataService.createAppointmentWithReminders(appointment);

        // إنشاء الفاتورة تلقائياً
        try {
          await _invoiceService.createAppointmentInvoice(
            appointment: appointment,
            patient: newPatient,
            appointmentFee: appointmentFee,
          );
        } catch (e) {
          // لا نوقف العملية إذا فشل إنشاء الفاتورة
          debugPrint('خطأ في إنشاء فاتورة الموعد: $e');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم تسجيل المريض وحجز الموعد بنجاح\nالتاريخ: ${DateFormat('yyyy-MM-dd HH:mm').format(appointmentDateTime)}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showFriendlyAuthError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل مريض جديد'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل *',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال الاسم';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني *',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال البريد الإلكتروني';
                  }
                  if (!value.contains('@')) {
                    return 'البريد الإلكتروني غير صحيح';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف *',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال رقم الهاتف';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور *',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال كلمة المرور';
                  }
                  if (value.length < 6) {
                    return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bloodTypeController,
                decoration: const InputDecoration(
                  labelText: 'فصيلة الدم (اختياري)',
                  prefixIcon: Icon(Icons.bloodtype),
                  border: OutlineInputBorder(),
                  hintText: 'مثال: A+, O-, B+',
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'معلومات الموعد',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<UserModel>(
                decoration: const InputDecoration(
                  labelText: 'اختيار الطبيب *',
                  prefixIcon: Icon(Icons.medical_services),
                  border: OutlineInputBorder(),
                ),
                value: _selectedDoctor,
                items: _doctors.map((doctor) {
                  final specialization = doctor.specialization ?? 'عام';
                  return DropdownMenuItem(
                    value: doctor,
                    child: Text('د. ${doctor.name} - $specialization'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedDoctor = value);
                },
                validator: (value) {
                  if (value == null) {
                    return 'يرجى اختيار الطبيب';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text('تاريخ ووقت الموعد: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime(
                  _appointmentDate.year,
                  _appointmentDate.month,
                  _appointmentDate.day,
                  _appointmentTime.hour,
                  _appointmentTime.minute,
                ))}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _appointmentDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _appointmentTime,
                    );
                    if (time != null) {
                      setState(() {
                        _appointmentDate = date;
                        _appointmentTime = time;
                      });
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _appointmentFeeController,
                decoration: const InputDecoration(
                  labelText: 'مبلغ الحجز (ر.س) *',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                  hintText: 'مثال: 100',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال مبلغ الحجز';
                  }
                  final fee = double.tryParse(value.trim());
                  if (fee == null || fee <= 0) {
                    return 'يرجى إدخال مبلغ صحيح';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _createPatient,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('تسجيل المريض'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

