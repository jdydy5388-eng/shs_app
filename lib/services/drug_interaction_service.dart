import '../models/prescription_model.dart';

/// خدمة للتحقق من التفاعلات الدوائية
/// يمكن دمجها مع قاعدة بيانات دوائية أو API خارجي
class DrugInteractionService {
  // قاعدة بيانات مبسطة للتفاعلات الدوائية
  // في الإنتاج، يجب استخدام قاعدة بيانات شاملة أو API
  final Map<String, List<String>> _interactionDatabase = {
    'warfarin': ['aspirin', 'ibuprofen', 'naproxen'],
    'aspirin': ['warfarin', 'ibuprofen'],
    'ibuprofen': ['warfarin', 'aspirin'],
    'digoxin': ['amiodarone', 'quinidine'],
    'amiodarone': ['digoxin'],
  };

  Future<List<String>> checkDrugInteractions(List<Medication> medications) async {
    final List<String> interactions = [];
    
    if (medications.length < 2) {
      return interactions; // لا توجد تفاعلات إذا كان دواء واحد فقط
    }

    // الحصول على قائمة أسماء الأدوية (بدون مسافات وأحرف صغيرة)
    final drugNames = medications
        .map((m) => m.name.toLowerCase().trim())
        .toList();

    // فحص التفاعلات بين الأدوية
    for (int i = 0; i < drugNames.length; i++) {
      for (int j = i + 1; j < drugNames.length; j++) {
        final drug1 = drugNames[i];
        final drug2 = drugNames[j];

        // فحص إذا كان الدواء الأول يتفاعل مع الثاني
        if (_interactionDatabase.containsKey(drug1)) {
          if (_interactionDatabase[drug1]!.contains(drug2)) {
            interactions.add(
              'تحذير: تفاعل محتمل بين ${medications[i].name} و ${medications[j].name}',
            );
          }
        }

        // فحص العكس
        if (_interactionDatabase.containsKey(drug2)) {
          if (_interactionDatabase[drug2]!.contains(drug1)) {
            interactions.add(
              'تحذير: تفاعل محتمل بين ${medications[j].name} و ${medications[i].name}',
            );
          }
        }
      }
    }

    // محاكاة التأخير في الاستجابة (في الإنتاج قد يكون هناك استدعاء API)
    await Future.delayed(const Duration(milliseconds: 500));

    return interactions;
  }

  /// إضافة تفاعل دوائي جديد إلى قاعدة البيانات
  void addInteraction(String drug1, String drug2) {
    _interactionDatabase.putIfAbsent(
      drug1.toLowerCase(),
      () => [],
    );
    _interactionDatabase[drug1.toLowerCase()]!.add(drug2.toLowerCase());

    // إضافة العكس أيضاً
    _interactionDatabase.putIfAbsent(
      drug2.toLowerCase(),
      () => [],
    );
    _interactionDatabase[drug2.toLowerCase()]!.add(drug1.toLowerCase());
  }
}

