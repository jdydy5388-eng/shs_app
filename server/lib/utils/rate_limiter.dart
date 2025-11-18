import 'package:shelf/shelf.dart';
import 'dart:collection';

/// Rate Limiter بسيط لمنع الهجمات
class RateLimiter {
  static final RateLimiter _instance = RateLimiter._internal();
  factory RateLimiter() => _instance;
  RateLimiter._internal();

  // تخزين عدد الطلبات لكل IP
  final Map<String, Queue<DateTime>> _requests = {};
  
  // الإعدادات
  final int maxRequests = 100; // عدد الطلبات المسموح
  final Duration window = const Duration(minutes: 1); // نافذة زمنية

  /// التحقق من Rate Limit
  bool checkLimit(String identifier) {
    final now = DateTime.now();
    final queue = _requests.putIfAbsent(identifier, () => Queue<DateTime>());

    // إزالة الطلبات القديمة خارج النافذة الزمنية
    while (queue.isNotEmpty && 
           now.difference(queue.first) > window) {
      queue.removeFirst();
    }

    // التحقق من الحد
    if (queue.length >= maxRequests) {
      return false; // تجاوز الحد
    }

    // إضافة الطلب الحالي
    queue.add(now);
    return true; // ضمن الحد
  }

  /// تنظيف الطلبات القديمة
  void cleanup() {
    final now = DateTime.now();
    _requests.removeWhere((key, queue) {
      while (queue.isNotEmpty && 
             now.difference(queue.first) > window) {
        queue.removeFirst();
      }
      return queue.isEmpty;
    });
  }
}

/// Middleware لـ Rate Limiting
Middleware rateLimitMiddleware() {
  final limiter = RateLimiter();
  
  // تنظيف دوري كل 5 دقائق
  Future.delayed(const Duration(minutes: 5), () {
    limiter.cleanup();
  });

  return (Handler handler) {
    return (Request request) async {
      // استخراج IP Address
      final ipAddress = request.headers['x-forwarded-for'] ?? 
                       request.headers['x-real-ip'] ?? 
                       request.headers['remote-addr'] ??
                       'unknown';

      // التحقق من Rate Limit
      if (!limiter.checkLimit(ipAddress)) {
        return Response(
          429, // Too Many Requests
          body: '{"error": "Too many requests. Please try again later."}',
          headers: {'Content-Type': 'application/json'},
        );
      }

      return await handler(request);
    };
  };
}

