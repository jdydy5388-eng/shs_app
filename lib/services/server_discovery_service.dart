import 'dart:io';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// خدمة اكتشاف الخادم تلقائياً في الشبكة المحلية
class ServerDiscoveryService {
  static const String _serverIpKey = 'server_ip_address';
  static const String _serverPortKey = 'server_port';
  static const int defaultPort = 8080;
  static const String healthEndpoint = '/health';
  
  /// الحصول على IP الخادم (من الحفظ أو الاكتشاف التلقائي)
  static Future<String> getServerBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. محاولة استخدام IP محفوظ
    final savedIp = prefs.getString(_serverIpKey);
    final savedPort = prefs.getInt(_serverPortKey) ?? defaultPort;
    
    if (savedIp != null && savedIp.isNotEmpty) {
      final url = 'http://$savedIp:$savedPort';
      if (await _testConnection(url)) {
        return url;
      }
    }
    
    // 2. على Windows/Linux/MacOS، محاولة localhost أولاً
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final localhostUrl = 'http://localhost:$defaultPort';
      if (await _testConnection(localhostUrl)) {
        await _saveServerInfo('localhost', defaultPort);
        return localhostUrl;
      }
      
      // محاولة 127.0.0.1
      final localhostIpUrl = 'http://127.0.0.1:$defaultPort';
      if (await _testConnection(localhostIpUrl)) {
        await _saveServerInfo('127.0.0.1', defaultPort);
        return localhostIpUrl;
      }
    }
    
    // 3. البحث في الشبكة المحلية
    final discoveredIp = await _discoverServerInNetwork(defaultPort);
    if (discoveredIp != null) {
      await _saveServerInfo(discoveredIp, defaultPort);
      return 'http://$discoveredIp:$defaultPort';
    }
    
    // 4. إذا فشل كل شيء، استخدام القيمة الافتراضية المحفوظة أو localhost
    return savedIp != null ? 'http://$savedIp:$savedPort' : 'http://localhost:$defaultPort';
  }
  
  /// اختبار الاتصال بالخادم
  static Future<bool> _testConnection(String baseUrl) async {
    try {
      final uri = Uri.parse('$baseUrl$healthEndpoint');
      final response = await http.get(uri).timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw TimeoutException('Connection timeout'),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  /// البحث عن الخادم في الشبكة المحلية
  static Future<String?> _discoverServerInNetwork(int port) async {
    try {
      // الحصول على جميع واجهات الشبكة
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );
      
      // جمع جميع عناوين IP المحلية
      final localIps = <String>[];
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            final ip = addr.address;
            // تجاهل loopback و link-local
            if (!ip.startsWith('127.') && !ip.startsWith('169.254.')) {
              localIps.add(ip);
            }
          }
        }
      }
      
      // إذا لم نجد أي IP، نستخدم شبكة محلية افتراضية
      if (localIps.isEmpty) {
        // محاولة IPs شائعة في الشبكات المحلية
        localIps.addAll([
          '192.168.1.100',
          '192.168.0.100',
          '192.168.43.196', // IP المعروف سابقاً
        ]);
      }
      
      // اختبار كل IP
      for (final ip in localIps) {
        final url = 'http://$ip:$port';
        if (await _testConnection(url)) {
          return ip;
        }
      }
      
      // البحث في نطاق الشبكة المحلية (أول 3 octets)
      if (localIps.isNotEmpty) {
        final networkBase = _getNetworkBase(localIps.first);
        if (networkBase != null) {
          // اختبار IPs شائعة أولاً (أسرع)
          final commonIps = [
            '100', '101', '1', '2', '10', '20', '50', 
            '196', '200', '254', '150', '102'
          ];
          
          for (final ipSuffix in commonIps) {
            final testIp = '$networkBase.$ipSuffix';
            if (await _testConnection('http://$testIp:$port')) {
              return testIp;
            }
          }
          
          // إذا لم نجد، نبحث في نطاق محدود (1-20, 100-120) لتسريع العملية
          final limitedRanges = [
            for (int i = 1; i <= 20; i++) i,
            for (int i = 100; i <= 120; i++) i,
          ];
          
          final futures = <Future<MapEntry<int, bool>>>[];
          for (final i in limitedRanges) {
            final testIp = '$networkBase.$i';
            futures.add(
              _testConnection('http://$testIp:$port')
                  .then((result) => MapEntry(i, result)),
            );
          }
          
          // انتظار أول نتيجة نجاح (مع timeout)
          try {
            final results = await Future.wait(futures).timeout(
              const Duration(seconds: 5),
              onTimeout: () => <MapEntry<int, bool>>[],
            );
            
            for (final result in results) {
              if (result.value) {
                final discoveredIp = '$networkBase.${result.key}';
                return discoveredIp;
              }
            }
          } catch (e) {
            // تجاهل الأخطاء واستمر
          }
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// استخراج قاعدة الشبكة (أول 3 octets)
  static String? _getNetworkBase(String ip) {
    final parts = ip.split('.');
    if (parts.length == 4) {
      return '${parts[0]}.${parts[1]}.${parts[2]}';
    }
    return null;
  }
  
  /// حفظ معلومات الخادم
  static Future<void> _saveServerInfo(String ip, int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverIpKey, ip);
    await prefs.setInt(_serverPortKey, port);
  }
  
  /// حفظ IP الخادم يدوياً
  static Future<void> saveServerIp(String ip, {int port = defaultPort}) async {
    await _saveServerInfo(ip, port);
  }
  
  /// مسح IP الخادم المحفوظ (لإعادة الاكتشاف)
  static Future<void> clearSavedServer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_serverIpKey);
    await prefs.remove(_serverPortKey);
  }
  
  /// الحصول على IP المحفوظ
  static Future<String?> getSavedServerIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverIpKey);
  }
}

