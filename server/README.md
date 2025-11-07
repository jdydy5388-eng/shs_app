# خادم النظام الصحي الذكي

خادم REST API مركزي للنظام الصحي الذكي باستخدام Dart و PostgreSQL.

## المتطلبات

- Dart SDK 3.8.1 أو أحدث
- PostgreSQL 12 أو أحدث
- Node.js (اختياري - لتثبيت PostgreSQL)

## التثبيت

### 1. تثبيت PostgreSQL

#### Windows:
```bash
# تحميل من https://www.postgresql.org/download/windows/
# أو استخدام Chocolatey
choco install postgresql
```

#### Linux (Ubuntu/Debian):
```bash
sudo apt-get update
sudo apt-get install postgresql postgresql-contrib
```

#### macOS:
```bash
brew install postgresql
brew services start postgresql
```

### 2. إعداد قاعدة البيانات

```bash
# تسجيل الدخول إلى PostgreSQL
psql -U postgres

# إنشاء قاعدة بيانات جديدة
CREATE DATABASE shs_app;

# إنشاء مستخدم جديد (اختياري)
CREATE USER shs_user WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE shs_app TO shs_user;
```

### 3. تثبيت التبعيات

```bash
cd server
dart pub get
```

### 4. إعداد ملف البيئة

```bash
# نسخ ملف المثال
cp .env.example .env

# تعديل الإعدادات في .env
# DATABASE_HOST=localhost
# DATABASE_PORT=5432
# DATABASE_NAME=shs_app
# DATABASE_USER=postgres
# DATABASE_PASSWORD=your_password
# SERVER_HOST=0.0.0.0
# SERVER_PORT=8080
```

## التشغيل

```bash
dart run lib/main.dart
```

الخادم سيعمل على `http://localhost:8080`

## API Endpoints

### Authentication
- `POST /api/auth/register` - تسجيل مستخدم جديد
- `POST /api/auth/login` - تسجيل الدخول
- `POST /api/auth/logout` - تسجيل الخروج

### Users
- `GET /api/users` - جلب جميع المستخدمين
- `GET /api/users/<userId>` - جلب مستخدم محدد
- `GET /api/users/patients` - جلب جميع المرضى
- `PUT /api/users/<userId>` - تحديث مستخدم
- `DELETE /api/users/<userId>` - حذف مستخدم

### Prescriptions
- `GET /api/prescriptions?patientId=<id>&doctorId=<id>` - جلب الوصفات
- `GET /api/prescriptions/<id>` - جلب وصفة محددة
- `POST /api/prescriptions` - إنشاء وصفة جديدة
- `PUT /api/prescriptions/<id>/status` - تحديث حالة الوصفة

### Orders
- `GET /api/orders?patientId=<id>&pharmacyId=<id>` - جلب الطلبات
- `GET /api/orders/<id>` - جلب طلب محدد
- `POST /api/orders` - إنشاء طلب جديد
- `PUT /api/orders/<id>/status` - تحديث حالة الطلب
- `PUT /api/orders/<id>/alternative` - اقتراح بديل
- `PUT /api/orders/<id>/approve-alternative` - الموافقة على البديل
- `PUT /api/orders/<id>/reject-alternative` - رفض البديل

### Appointments
- `GET /api/appointments?doctorId=<id>&patientId=<id>&status=<status>` - جلب المواعيد
- `GET /api/appointments/<id>` - جلب موعد محدد
- `POST /api/appointments` - إنشاء موعد جديد
- `PUT /api/appointments/<id>/status` - تحديث حالة الموعد
- `PUT /api/appointments/<id>` - تحديث موعد
- `DELETE /api/appointments/<id>` - حذف موعد

### Medical Records
- `GET /api/medical-records?patientId=<id>` - جلب السجلات الطبية
- `GET /api/medical-records/<id>` - جلب سجل محدد
- `POST /api/medical-records` - إضافة سجل جديد
- `PUT /api/medical-records/<id>` - تحديث سجل
- `DELETE /api/medical-records/<id>` - حذف سجل

### Inventory
- `GET /api/inventory?pharmacyId=<id>` - جلب المخزون
- `GET /api/inventory/<id>` - جلب عنصر محدد
- `POST /api/inventory` - إضافة عنصر جديد
- `PUT /api/inventory/<id>` - تحديث عنصر
- `DELETE /api/inventory/<id>` - حذف عنصر

### Lab Requests
- `GET /api/lab-requests?doctorId=<id>&patientId=<id>&status=<status>` - جلب طلبات الفحوصات
- `GET /api/lab-requests/<id>` - جلب طلب محدد
- `POST /api/lab-requests` - إنشاء طلب جديد
- `PUT /api/lab-requests/<id>` - تحديث طلب
- `DELETE /api/lab-requests/<id>` - حذف طلب

### Entities
- `GET /api/entities?type=<type>` - جلب الكيانات
- `GET /api/entities/<id>` - جلب كيان محدد
- `POST /api/entities` - إضافة كيان جديد
- `PUT /api/entities/<id>` - تحديث كيان
- `DELETE /api/entities/<id>` - حذف كيان

### Audit Logs
- `GET /api/audit-logs?userId=<id>&resourceType=<type>&limit=<n>` - جلب سجلات التدقيق
- `POST /api/audit-logs` - إنشاء سجل تدقيق

### System Settings
- `GET /api/system-settings` - جلب جميع الإعدادات
- `GET /api/system-settings/<key>` - جلب إعداد محدد
- `PUT /api/system-settings/<key>` - تحديث إعداد

## الإعدادات الشبكية

### للوصول من أجهزة أخرى على نفس الشبكة:

1. تأكد من أن `SERVER_HOST=0.0.0.0` في `.env`
2. اكتشف IP الخادم:
   - Windows: `ipconfig`
   - Linux/macOS: `ifconfig` أو `ip addr`
3. في التطبيق، غيّر `serverBaseUrl` في `lib/config/app_config.dart`:
   ```dart
   static const String serverBaseUrl = 'http://192.168.1.100:8080'; // IP الخادم
   ```

### جدار الحماية

إذا كان الخادم لا يستجيب من الأجهزة الأخرى:

#### Windows:
```powershell
# فتح المنفذ 8080
New-NetFirewallRule -DisplayName "SHS Server" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow
```

#### Linux:
```bash
sudo ufw allow 8080/tcp
```

## ملاحظات

- قاعدة البيانات ستُنشأ تلقائياً عند أول تشغيل
- جميع الجداول ستُنشأ تلقائياً
- كلمات المرور يتم تشفيرها باستخدام SHA-256

## التطوير

```bash
# تشغيل في وضع التطوير مع إعادة التحميل التلقائي
dart run lib/main.dart

# أو استخدام watch
dart run watch lib/main.dart
```

