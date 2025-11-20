import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/data_service.dart';
import '../../services/local_auth_service.dart';
import '../../services/biometric_auth_service.dart';
import 'package:intl/intl.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final _dataService = DataService();
  final LocalAuthService _authService = LocalAuthService();
  final BiometricAuthService _biometricAuthService = BiometricAuthService();
  List<UserModel> _users = [];
  bool _isLoading = true;
  UserRole? _filterRole;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _dataService.getUsers();
      setState(() {
        _users = users.cast<UserModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل المستخدمين: $e')),
        );
      }
    }
  }

  List<UserModel> get _filteredUsers {
    var filtered = _users;
    
    if (_filterRole != null) {
      filtered = filtered.where((u) => u.role == _filterRole).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((u) {
        return u.name.toLowerCase().contains(query) ||
            u.email.toLowerCase().contains(query) ||
            u.phone.toLowerCase().contains(query);
      }).toList();
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المستخدمين والحسابات'),
        actions: [
          PopupMenuButton<UserRole?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (role) {
              setState(() => _filterRole = role);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('جميع المستخدمين'),
              ),
              const PopupMenuItem(
                value: UserRole.patient,
                child: Text('المرضى'),
              ),
              const PopupMenuItem(
                value: UserRole.doctor,
                child: Text('الأطباء'),
              ),
              const PopupMenuItem(
                value: UserRole.pharmacist,
                child: Text('الصيادلة'),
              ),
              const PopupMenuItem(
                value: UserRole.labTechnician,
                child: Text('فنيو المختبر'),
              ),
              const PopupMenuItem(
                value: UserRole.radiologist,
                child: Text('أخصائيو الأشعة'),
              ),
              const PopupMenuItem(
                value: UserRole.nurse,
                child: Text('الممرضون/الممرضات'),
              ),
              const PopupMenuItem(
                value: UserRole.admin,
                child: Text('المدراء'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'بحث في المستخدمين',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildUsersList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateUserDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildUsersList() {
    final filtered = _filteredUsers;

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isEmpty ? 'لا يوجد مستخدمين' : 'لا توجد نتائج',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final user = filtered[index];
          return _buildUserCard(user);
        },
      ),
    );
  }

  Widget _buildUserCard(UserModel user) {
    final roleColor = {
      UserRole.patient: Colors.blue,
      UserRole.doctor: Colors.green,
      UserRole.pharmacist: Colors.purple,
      UserRole.labTechnician: Colors.orange,
      UserRole.radiologist: Colors.teal,
      UserRole.nurse: Colors.pink,
      UserRole.admin: Colors.red,
    }[user.role]!;

    final roleText = {
      UserRole.patient: 'مريض',
      UserRole.doctor: 'طبيب',
      UserRole.pharmacist: 'صيدلي',
      UserRole.labTechnician: 'فني مختبر',
      UserRole.radiologist: 'أخصائي أشعة',
      UserRole.nurse: 'ممرض/ممرضة',
      UserRole.admin: 'مدير',
    }[user.role]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: roleColor.withValues(alpha: 0.2),
          child: Icon(
            _getRoleIcon(user.role),
            color: roleColor,
          ),
        ),
        title: Text(
          user.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email),
            Text(user.phone),
            Chip(
              label: Text(roleText, style: const TextStyle(fontSize: 12)),
              backgroundColor: roleColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(color: roleColor),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تاريخ الإنشاء: ${DateFormat('yyyy-MM-dd').format(user.createdAt)}'),
                if (user.lastLoginAt != null)
                  Text('آخر تسجيل دخول: ${DateFormat('yyyy-MM-dd HH:mm').format(user.lastLoginAt!)}'),
                if (user.role == UserRole.doctor && user.specialization != null)
                  Text('التخصص: ${user.specialization}'),
                if (user.role == UserRole.pharmacist && user.pharmacyName != null)
                  Text('الصيدلية: ${user.pharmacyName}'),
                if (user.role == UserRole.patient && user.bloodType != null)
                  Text('فصيلة الدم: ${user.bloodType}'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('تعديل'),
                      onPressed: () => _showEditUserDialog(user),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.lock_reset),
                      label: const Text('إعادة تعيين كلمة المرور'),
                      onPressed: () => _resetPassword(user),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('إعدادات المصادقة'),
                      onPressed: () => _manageBiometric(user),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('حذف', style: TextStyle(color: Colors.red)),
                      onPressed: () => _deleteUser(user),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.patient:
        return Icons.person;
      case UserRole.doctor:
        return Icons.medical_services;
      case UserRole.pharmacist:
        return Icons.local_pharmacy;
      case UserRole.labTechnician:
        return Icons.science;
      case UserRole.radiologist:
        return Icons.medical_services;
      case UserRole.nurse:
        return Icons.medical_services;
      case UserRole.receptionist:
        return Icons.receipt_long;
      case UserRole.admin:
        return Icons.admin_panel_settings;
    }
  }

  Future<void> _showCreateUserDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    UserRole? selectedRole = UserRole.patient;
    Map<String, dynamic>? additionalInfo;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('إنشاء حساب جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور *',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<UserRole>(
                  decoration: const InputDecoration(
                    labelText: 'الدور *',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedRole,
                  items: UserRole.values
                      .where((r) => r != UserRole.admin) // لا يمكن إنشاء مدير من هنا
                      .map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(_getRoleName(role)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => selectedRole = value);
                    if (value == UserRole.doctor) {
                      additionalInfo = {'specialization': 'عام'};
                    } else if (value == UserRole.pharmacist) {
                      additionalInfo = {'pharmacyName': 'صيدلية جديدة'};
                    } else if (value == UserRole.nurse) {
                      additionalInfo = {'department': 'عام'};
                    } else if (value == UserRole.receptionist) {
                      additionalInfo = {'department': 'الاستقبال'};
                    } else {
                      additionalInfo = null;
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty ||
                    emailController.text.trim().isEmpty ||
                    phoneController.text.trim().isEmpty ||
                    passwordController.text.isEmpty ||
                    selectedRole == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى ملء جميع الحقول المطلوبة')),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('إنشاء'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedRole != null) {
      try {
        await _authService.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text,
          name: nameController.text.trim(),
          phone: phoneController.text.trim(),
          role: selectedRole!,
          additionalInfo: additionalInfo,
        );

        await _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إنشاء الحساب بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في إنشاء الحساب: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showEditUserDialog(UserModel user) async {
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email);
    final phoneController = TextEditingController(text: user.phone);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل بيانات المستخدم'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final updatedUser = UserModel(
          id: user.id,
          name: nameController.text.trim(),
          email: emailController.text.trim(),
          phone: phoneController.text.trim(),
          role: user.role,
          profileImageUrl: user.profileImageUrl,
          additionalInfo: user.additionalInfo,
          createdAt: user.createdAt,
          lastLoginAt: user.lastLoginAt,
        );

        // تحديث المستخدم عبر DataService (يدعم الوضع المحلي والشبكي)
        await _dataService.updateUser(
          updatedUser.id,
          {
            'name': updatedUser.name,
            'email': updatedUser.email,
            'phone': updatedUser.phone,
            'additionalInfo': updatedUser.additionalInfo,
          },
        );
        
        // تحديث محلياً أيضاً للمصادقة البيومترية
        await _authService.updateUser(updatedUser);
        
        await _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث البيانات بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في التحديث: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _resetPassword(UserModel user) async {
    final passwordController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة تعيين كلمة المرور'),
        content: Material(
          child: TextField(
            controller: passwordController,
            decoration: const InputDecoration(
              labelText: 'كلمة المرور الجديدة *',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى إدخال كلمة المرور')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('تعيين'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        // TODO: تحديث كلمة المرور في قاعدة البيانات
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إعادة تعيين كلمة المرور بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _manageBiometric(UserModel user) async {
    final available = await _biometricAuthService.isBiometricAvailable();
    
    if (!mounted) return;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعدادات المصادقة البيومترية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('المستخدم: ${user.name}'),
            const SizedBox(height: 16),
            Text(available
                ? 'المصادقة البيومترية متاحة'
                : 'المصادقة البيومترية غير متاحة على هذا الجهاز'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          if (available)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تحديث إعدادات المصادقة البيومترية'),
                    ),
                  );
                }
              },
              child: const Text('تحديث'),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف حساب ${user.name}؟\nهذه العملية لا يمكن التراجع عنها.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // TODO: حذف المستخدم من قاعدة البيانات
        await _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف الحساب بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في الحذف: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _getRoleName(UserRole role) {
    switch (role) {
      case UserRole.patient:
        return 'مريض';
      case UserRole.doctor:
        return 'طبيب';
      case UserRole.pharmacist:
        return 'صيدلي';
      case UserRole.labTechnician:
        return 'فني مختبر';
      case UserRole.radiologist:
        return 'أخصائي أشعة';
      case UserRole.nurse:
        return 'ممرض/ممرضة';
      case UserRole.receptionist:
        return 'موظف استقبال';
      case UserRole.admin:
        return 'مدير';
    }
  }
}

