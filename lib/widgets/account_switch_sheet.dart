import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider_local.dart';
import '../utils/auth_helper.dart';
import '../routes/route_paths.dart';

class AccountSwitchSheet extends StatefulWidget {
  const AccountSwitchSheet({super.key});

  @override
  State<AccountSwitchSheet> createState() => _AccountSwitchSheetState();
}

class _AccountSwitchSheetState extends State<AccountSwitchSheet> {
  bool _processing = false;
  String? _error;

  Future<void> _useBiometric() async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final auth = Provider.of<AuthProviderLocal>(context, listen: false);
      final ok = await auth.signInWithBiometric();
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(); // أغلق الشيت
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الدخول بالبصمة')));
      } else {
        setState(() => _error = auth.errorMessage ?? 'فشل تسجيل الدخول بالبصمة');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _manualLogin() async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      await AuthHelper.signOut(context);
      if (!mounted) return;
      Navigator.of(context).pop();
      // الانتقال لصفحة تسجيل الدخول (مسار مركزي)
      Navigator.of(context).pushReplacementNamed(RoutePaths.login);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'تبديل الحساب',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            ElevatedButton.icon(
              onPressed: _processing ? null : _useBiometric,
              icon: const Icon(Icons.fingerprint),
              label: _processing ? const Text('...') : const Text('تسجيل الدخول بالبصمة'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _processing ? null : _manualLogin,
              icon: const Icon(Icons.login),
              label: const Text('تسجيل دخول يدوي'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}


