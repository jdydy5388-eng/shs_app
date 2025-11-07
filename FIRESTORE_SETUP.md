# إعداد Firestore Database - خطوة بخطوة

## الخطوة الحالية: Select edition

### ✅ اختر: **Standard edition**
- مناسب للمشروع الحالي
- كافي للوثائق حتى 1 ميجابايت
- يعمل مع جميع الاستعلامات البسيطة

**ملاحظة:** Enterprise edition مخصص للمشاريع الكبيرة التي تحتاج MongoDB compatibility - ليس مطلوباً لك الآن.

---

## الخطوات التالية بعد الضغط على "Next":

### 1. Database ID and location

- **Database ID**: اتركه `(default)` أو غير الاسم إذا أردت
- **Cloud Firestore location**: 
  - اختر أقرب منطقة جغرافية لك
  - أو اختر `us-central1` أو `europe-west1` للبدء
  
**مثال على المناطق:**
- `us-central1` (أمريكا الوسطى)
- `europe-west1` (أوروبا)
- `asia-south1` (جنوب آسيا)
- `middle-east1` (الشرق الأوسط - إن كان متاحاً)

### 2. Configure

#### ⚠️ مهم: اختر وضع الأمان

**للتطوير والاختبار:**
- اختر **"Start in test mode"**
- سيعطيك قاعدة بيانات تعمل بسرعة
- ⚠️ **لن تكون آمنة للإنتاج**

**للإنتاج:**
- اختر **"Start in production mode"**
- ستحتاج إضافة قواعد الأمان يدوياً بعد الإنشاء

#### 📝 قواعد الأمان الموصى بها:

بعد إنشاء قاعدة البيانات، اذهب إلى **Rules** وأضف:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users: يمكن للمستخدمين قراءة/كتابة بياناتهم فقط
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      allow read: if request.auth != null; // يمكن للجميع قراءة (للعثور على المرضى)
    }
    
    // Prescriptions: يمكن للأطباء والمرضى الوصول إليها
    match /prescriptions/{prescriptionId} {
      allow read: if request.auth != null && 
        (resource.data.doctorId == request.auth.uid || 
         resource.data.patientId == request.auth.uid);
      allow create: if request.auth != null && 
        request.resource.data.doctorId == request.auth.uid;
      allow update: if request.auth != null && 
        resource.data.doctorId == request.auth.uid;
    }
    
    // Medical Records: يمكن للأطباء والمرضى الوصول إليها
    match /medical_records/{recordId} {
      allow read: if request.auth != null && 
        (resource.data.doctorId == request.auth.uid || 
         resource.data.patientId == request.auth.uid);
      allow create, update: if request.auth != null;
    }
    
    // Orders: يمكن للمرضى والصيادلة الوصول إليها
    match /orders/{orderId} {
      allow read: if request.auth != null && 
        (resource.data.patientId == request.auth.uid || 
         resource.data.pharmacyId == request.auth.uid);
      allow create: if request.auth != null;
      allow update: if request.auth != null && 
        resource.data.pharmacyId == request.auth.uid;
    }
    
    // Inventory: يمكن للصيادلة فقط
    match /inventory/{inventoryId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        resource.data.pharmacyId == request.auth.uid;
    }
  }
}
```

---

## ملخص الإعداد:

1. ✅ **Standard edition** → Next
2. **Database ID**: `(default)` → اختر **Location** → Next  
3. **Configure**: اختر **Test mode** (للتطوير) → **Enable**
4. بعد الإنشاء: اذهب إلى **Rules** → أضف القواعد أعلاه → **Publish**

---

## بعد إنشاء قاعدة البيانات:

1. ✅ ستكون جاهزة لاستخدامها في التطبيق
2. ✅ يمكنك رؤية البيانات في Firebase Console
3. ✅ التطبيق سيحفظ البيانات تلقائياً

---

## خطوات تالية:

بعد إنشاء Firestore، تأكد من:
- ✅ Authentication مفعّل
- ✅ Storage مفعّل  
- ✅ تطبيق Android مضاف و `google-services.json` في المكان الصحيح

