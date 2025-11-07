# دليل الاختبار - النظام الصحي الذكي

## الخطوات التالية بعد إعداد الخادم

### 1. التحقق من أن الخادم يعمل

```bash
# في مجلد server
dart run lib/main.dart
```

يجب أن ترى رسائل:
- ✅ Configuration loaded
- ✅ Database connected
- ✅ Database tables ready
- ✅ Server is running!

### 2. اختبار الاتصال

افتح المتصفح أو استخدم curl:

```bash
# Health check
curl http://localhost:8080/health

# أو في المتصفح
http://localhost:8080/health
```

يجب أن ترى: `Server is running`

### 3. تحديث إعدادات التطبيق

في `lib/config/app_config.dart`:
- إذا كان الخادم على نفس الجهاز: `localhost:8080`
- إذا كان على جهاز آخر: `http://192.168.x.x:8080`

### 4. تشغيل التطبيق

```bash
flutter run -d windows
```

### 5. اختبار الوظائف الأساسية

#### أ. تسجيل الدخول
- يجب أن يعمل تسجيل الدخول بشكل طبيعي
- البيانات تُجلب من الخادم

#### ب. إنشاء مستخدم جديد (من Admin)
- يجب أن يُحفظ في قاعدة البيانات المركزي

#### ج. إنشاء وصفة طبية (من Doctor)
- يجب أن تُحفظ في الخادم

#### د. إنشاء طلب (من Patient)
- يجب أن يُرسل إلى الخادم

### 6. التحقق من البيانات

اتصل بقاعدة البيانات PostgreSQL:

```sql
-- عرض المستخدمين
SELECT * FROM users;

-- عرض الوصفات
SELECT * FROM prescriptions;

-- عرض الطلبات
SELECT * FROM orders;
```

### 7. استكشاف الأخطاء

#### إذا كان التطبيق لا يتصل بالخادم:
1. تأكد أن الخادم يعمل
2. تحقق من `serverBaseUrl` في `app_config.dart`
3. تحقق من وجود أخطاء في console التطبيق
4. تحقق من logs الخادم

#### إذا فشل الاتصال بقاعدة البيانات:
1. تأكد أن PostgreSQL يعمل
2. تحقق من ملف `.env` في مجلد `server`
3. تأكد من وجود قاعدة البيانات المحددة

### 8. التبديل بين الوضع المحلي والشبكي

في `lib/config/app_config.dart`:

```dart
static const bool useLocalMode = false; // false = شبكي (REST API)
static const bool useLocalMode = true;  // true = محلي (SQLite)
```

## ملاحظات مهمة

- جميع الشاشات الآن تستخدم `DataService` الذي يتبدل تلقائياً بين المحلي والشبكي
- عند تغيير `useLocalMode`، يجب إعادة تشغيل التطبيق
- البيانات في الوضع المحلي منفصلة عن الوضع الشبكي

