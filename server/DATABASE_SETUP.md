# دليل إنشاء قاعدة البيانات

## طريقة 1: استخدام سطر الأوامر (Command Line)

### Windows:

1. افتح **Command Prompt** أو **PowerShell**

2. انتقل إلى مجلد PostgreSQL (عادة في `C:\Program Files\PostgreSQL\XX\bin`):
```powershell
cd "C:\Program Files\PostgreSQL\16\bin"
```

3. سجّل الدخول إلى PostgreSQL:
```powershell
.\psql.exe -U postgres
```

**ملاحظة**: سيطلب منك كلمة مرور. إذا لم تكن قد حددت كلمة مرور، استخدم كلمة المرور الافتراضية التي أدخلتها أثناء التثبيت.

### Linux/macOS:

1. افتح Terminal

2. سجّل الدخول إلى PostgreSQL:
```bash
sudo -u postgres psql
```

أو إذا كنت تستخدم مستخدم PostgreSQL:
```bash
psql -U postgres
```

### 4. إنشاء قاعدة البيانات:

بعد تسجيل الدخول، ستظهر لك نافذة `postgres=#`. اكتب الأوامر التالية:

```sql
-- إنشاء قاعدة البيانات
CREATE DATABASE shs_app;

-- التحقق من إنشاء القاعدة بنجاح
\l
```

يجب أن ترى `shs_app` في قائمة قواعد البيانات.

### 5. إنشاء مستخدم جديد (اختياري - لكن موصى به):

```sql
-- إنشاء مستخدم جديد
CREATE USER shs_user WITH PASSWORD 'your_secure_password';

-- منح الصلاحيات
GRANT ALL PRIVILEGES ON DATABASE shs_app TO shs_user;

-- ربط المستخدم بقاعدة البيانات
\c shs_app
GRANT ALL ON SCHEMA public TO shs_user;
```

### 6. الخروج من psql:

```sql
\q
```

---

## طريقة 2: استخدام pgAdmin (واجهة رسومية)

### Windows/Linux/macOS:

1. افتح **pgAdmin 4** (يأتي مع PostgreSQL)

2. انقر بزر الماوس الأيمن على **Databases** في الشريط الجانبي

3. اختر **Create > Database**

4. في النافذة المنبثقة:
   - **Database name**: `shs_app`
   - **Owner**: `postgres` (أو المستخدم الذي أنشأته)
   - انقر **Save**

---

## طريقة 3: استخدام سطر أوامر واحد (Windows)

```powershell
# في PowerShell (كمسؤول)
& "C:\Program Files\PostgreSQL\16\bin\psql.exe" -U postgres -c "CREATE DATABASE shs_app;"
```

---

## طريقة 4: استخدام ملف SQL

1. أنشئ ملف `create_database.sql`:
```sql
CREATE DATABASE shs_app;
```

2. نفّذ الملف:
```bash
# Windows
psql -U postgres -f create_database.sql

# Linux/macOS
sudo -u postgres psql -f create_database.sql
```

---

## التحقق من نجاح العملية

بعد إنشاء قاعدة البيانات، تحقق منها:

```sql
-- قائمة جميع قواعد البيانات
\l

-- أو
\list
```

يجب أن ترى `shs_app` في القائمة.

---

## استكشاف الأخطاء

### خطأ: "password authentication failed"
**الحل**: تأكد من كلمة المرور الصحيحة، أو أعد تعيينها:
```sql
ALTER USER postgres PASSWORD 'new_password';
```

### خطأ: "database already exists"
**الحل**: القاعدة موجودة بالفعل. يمكنك استخدامها أو حذفها أولاً:
```sql
DROP DATABASE shs_app;
CREATE DATABASE shs_app;
```

### خطأ: "permission denied"
**الحل**: تأكد من أنك تستخدم مستخدم `postgres` أو مستخدم له صلاحيات:
```sql
-- في psql
\du  -- عرض المستخدمين وصلاحياتهم
```

---

## الخطوة التالية

بعد إنشاء قاعدة البيانات، عد إلى مجلد `server` وعدّل ملف `.env`:

```env
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=shs_app
DATABASE_USER=postgres
DATABASE_PASSWORD=your_password
```

ثم شغّل الخادم:
```bash
cd server
dart run lib/main.dart
```

الخادم سينشئ الجداول تلقائياً عند أول تشغيل! 🎉

