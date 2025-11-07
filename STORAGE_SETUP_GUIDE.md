# دليل إعداد Storage - خطوة بخطوة

## ✅ الخطوة الحالية: Set up default bucket

### الإعدادات الموصى بها:

#### 1️⃣ Bucket Options (الحالية):

✅ **اختر: "No-cost location"** (هو المحدد حالياً)
- **Location**: `US-CENTRAL1` ✅ (مناسب وجيد)
- **Access frequency**: `Standard` ✅ (مناسب)

**لماذا هذا الخيار؟**
- ✅ مجاني تماماً
- ✅ US-CENTRAL1 موقع جيد وسريع
- ✅ مناسب للملفات الطبية (صور، PDFs)
- ✅ كافي للمشروع الحالي

**ملاحظة:** خيار "All locations" مخصص للمشاريع الكبيرة التي تحتاج توزيع عالمي - ليس ضرورياً الآن.

---

#### 2️⃣ اضغط "Continue" للمتابعة إلى Security Rules

---

### 3️⃣ Security Rules (الخطوة التالية):

بعد الضغط على "Continue"، ستظهر نافذة إعداد قواعد الأمان:

#### اختر: **"Start in test mode"** (للتطوير)

**أو للإنتاج:**
- اختر "Start in production mode"
- وأضف القواعد التالية بعد ذلك:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Medical records files - يمكن للمستخدمين رفع ملفاتهم فقط
    match /medical_records/{userId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
      allow delete: if request.auth != null && request.auth.uid == userId;
    }
    
    // Profile images
    match /profile_images/{userId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // General files - يمكن للمستخدمين المصرح لهم فقط
    match /{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

---

## 📋 ملخص الخطوات:

1. ✅ **Bucket Options**:
   - اختر "No-cost location"
   - Location: `US-CENTRAL1` ✅
   - Access frequency: `Standard` ✅
   - اضغط **"Continue"**

2. ⏳ **Security Rules**:
   - اختر "Start in test mode" (للتطوير)
   - أو "Start in production mode" + أضف القواعد أعلاه
   - اضغط **"Done"**

---

## ✅ بعد الإعداد:

- ✅ Storage جاهز لاستخدامه
- ✅ يمكن رفع الملفات (صور التقارير، PDFs)
- ✅ التطبيق سيستخدم Storage تلقائياً

---

## 🔧 استخدام Storage في التطبيق:

التطبيق جاهز للاستخدام! الملفات الطبية ستُرفع تلقائياً إلى:
- `medical_records/{userId}/{filename}`
- `profile_images/{userId}/{filename}`

---

## ⚠️ ملاحظات مهمة:

1. **Test Mode**: مناسب للتطوير فقط
2. **Production Mode**: استخدمه قبل النشر النهائي
3. **الموقع**: US-CENTRAL1 جيد، يمكن تغييره لاحقاً إذا لزم
4. **التكلفة**: الخيار الحالي مجاني تماماً

---

## 🎯 الخطوات التالية بعد Storage:

1. ✅ Storage - جاري الإعداد
2. ⏳ إضافة Android App + `google-services.json`
3. ⏳ `flutterfire configure`
4. ⏳ اختبار التطبيق

**اضغط "Continue" للمتابعة!** 🚀

