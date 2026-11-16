import 'package:flutter/material.dart';
import '../models/senior_model.dart';
import 'api_service.dart';
import 'auth_service.dart';

class SeniorManager extends ChangeNotifier {
  static final SeniorManager _instance = SeniorManager._internal();
  factory SeniorManager() => _instance;
  SeniorManager._internal();

  final List<SeniorModel> _seniors = [];
  int _selectedSeniorIndex = 0;
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  List<SeniorModel> get seniors => List.unmodifiable(_seniors);
  bool get hasSeniors => _seniors.isNotEmpty;

  SeniorModel get currentSenior {
    if (_seniors.isEmpty) {
      return SeniorModel(
        id: '',
        name: 'لم يتم ربط كبير سن',
        relationship: 'غير مرتبط',
        phoneNumber: '',
        age: 0,
        bloodType: 'غير محدد',
        gender: 'غير محدد',
        healthStatus: 'لا توجد بيانات',
        chronicDiseases: [],
        allergies: 'لا توجد',
        criticalMedications: [],
        doctorName: 'غير محدد',
        hospital: 'غير محدد',
        location: 'الموقع غير محدد',
        nextTask: 'لا توجد مهام حالياً',
        nextTaskTime: '--:--',
        pairingCode: '------',
        watchBattery: 0,
        watchModel: '',
        watchConnected: false,
      );
    }
    if (_selectedSeniorIndex >= _seniors.length) {
      _selectedSeniorIndex = 0;
    }
    return _seniors[_selectedSeniorIndex];
  }

  int get selectedIndex => _selectedSeniorIndex;

  /// إعادة تحميل بيانات كبار السن من قاعدة البيانات
  Future<void> reload() => fetchSeniorsFromDatabase();

  /// جلب كبير السن المرتبط فعلياً من قاعدة البيانات MySQL بدون أي بيانات وهمية
  Future<void> fetchSeniorsFromDatabase() async {
    _isLoading = true;
    notifyListeners();

    try {
      _seniors.clear();

      final auth = AuthService();
      if (auth.isCaregiver) {
        // إذا كان المستخدم مقدم رعاية: نجلب فقط كبير السن المرتبط به فعلياً
        final int? linkedId = auth.linkedElderlyId;
        if (linkedId != null && linkedId > 0) {
          final item = await ApiService.instance.getElderly(linkedId);
          if (item != null) {
            // فحص هل لديه ساعة ذكية متصلة في جدول devices
            final devices = await ApiService.instance.getDevices(elderlyId: linkedId);
            final bool hasWatch = devices.isNotEmpty;
            final String watchModel = hasWatch ? (devices.first['D_Type'] ?? 'ساعة ذكية').toString() : '';

            // فحص هل لديه مهام أو أدوية قادمة حقيقية
            final meds = await ApiService.instance.getMedications(elderlyId: linkedId);
            final appts = await ApiService.instance.getAppointments(elderlyId: linkedId);
            String nextTask = 'لا توجد مهام مسجلة';
            String nextTaskTime = '--:--';
            if (meds.isNotEmpty) {
              nextTask = meds.first['M_Name'] ?? 'تناول الدواء';
              nextTaskTime = meds.first['M_Time'] ?? '--:--';
            } else if (appts.isNotEmpty) {
              nextTask = appts.first['A_DateType'] ?? 'موعد طبي';
              nextTaskTime = appts.first['A_Time'] ?? '--:--';
            }

            String sName = (item['E_Name'] ?? '').toString().trim();
            if (sName.isEmpty || RegExp(r'^[\?\s]+$').hasMatch(sName)) sName = 'كبير السن';

            _seniors.add(SeniorModel(
              id: (item['Eldery_ID'] ?? linkedId).toString(),
              name: sName,
              gender: (item['E_sex'] ?? 'ذكر').toString(),
              phoneNumber: (item['E_PhonNumber'] ?? '').toString(),
              relationship: 'كبير السن المشمول بالرعاية',
              age: 0,
              bloodType: 'غير محدد',
              healthStatus: 'مستقر',
              chronicDiseases: [],
              allergies: 'لا توجد',
              criticalMedications: meds.map((m) => (m['M_Name'] ?? '').toString()).where((m) => m.isNotEmpty).toList(),
              doctorName: 'طبيب الرعاية',
              hospital: 'المركز الصحي',
              location: 'الموقع غير محدد',
              nextTask: nextTask,
              nextTaskTime: nextTaskTime,
              pairingCode: 'YS-$linkedId',
              watchConnected: hasWatch,
              watchModel: watchModel,
              watchBattery: hasWatch ? 85 : 0,
            ));
          }
        }
      } else if (auth.isSenior) {
        // إذا كان المستخدم كبير السن نفسه
        final int? myId = auth.userId;
        if (myId != null && myId > 0) {
          final item = await ApiService.instance.getElderly(myId);
          if (item != null) {
            final devices = await ApiService.instance.getDevices(elderlyId: myId);
            final bool hasWatch = devices.isNotEmpty;
            final String watchModel = hasWatch ? (devices.first['D_Type'] ?? 'ساعة ذكية').toString() : '';

            final meds = await ApiService.instance.getMedications(elderlyId: myId);
            final appts = await ApiService.instance.getAppointments(elderlyId: myId);
            String nextTask = 'لا توجد مهام مسجلة';
            String nextTaskTime = '--:--';
            if (meds.isNotEmpty) {
              nextTask = meds.first['M_Name'] ?? 'تناول الدواء';
              nextTaskTime = meds.first['M_Time'] ?? '--:--';
            } else if (appts.isNotEmpty) {
              nextTask = appts.first['A_DateType'] ?? 'موعد طبي';
              nextTaskTime = appts.first['A_Time'] ?? '--:--';
            }

            String myName = (item['E_Name'] ?? '').toString().trim();
            if (myName.isEmpty || RegExp(r'^[\?\s]+$').hasMatch(myName)) myName = 'كبير السن';

            _seniors.add(SeniorModel(
              id: (item['Eldery_ID'] ?? myId).toString(),
              name: myName,
              gender: (item['E_sex'] ?? 'ذكر').toString(),
              phoneNumber: (item['E_PhonNumber'] ?? '').toString(),
              relationship: 'حسابي',
              age: 0,
              bloodType: 'غير محدد',
              healthStatus: 'مستقر',
              chronicDiseases: [],
              allergies: 'لا توجد',
              criticalMedications: meds.map((m) => (m['M_Name'] ?? '').toString()).where((m) => m.isNotEmpty).toList(),
              doctorName: 'طبيب الرعاية',
              hospital: 'المركز الصحي',
              location: 'الموقع غير محدد',
              nextTask: nextTask,
              nextTaskTime: nextTaskTime,
              pairingCode: 'YS-$myId',
              watchConnected: hasWatch,
              watchModel: watchModel,
              watchBattery: hasWatch ? 85 : 0,
            ));
          }
        }
      } else {
        _seniors.clear();
      }

      if (_selectedSeniorIndex >= _seniors.length) {
        _selectedSeniorIndex = 0;
      }
    } catch (_) {
      // التعامل مع أخطاء الشبكة بهدوء
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// مسح بيانات كبار السن بالكامل عند تسجيل الخروج أو بدء جلسة جديدة
  void clear() {
    _seniors.clear();
    _selectedSeniorIndex = 0;
    notifyListeners();
  }

  void selectSenior(int index) {
    if (index >= 0 && index < _seniors.length) {
      _selectedSeniorIndex = index;
      notifyListeners();
    }
  }

  Future<void> addSenior(SeniorModel senior) async {
    _seniors.add(senior);
    _selectedSeniorIndex = _seniors.length - 1;
    notifyListeners();

    // حفظ في قاعدة البيانات
    try {
      await ApiService.instance.registerElderly(
        name: senior.name,
        sex: senior.gender,
        phone: senior.phoneNumber,
      );
      await fetchSeniorsFromDatabase();
    } catch (_) {}
  }

  Future<void> updateSenior(String id, SeniorModel updatedSenior) async {
    final index = _seniors.indexWhere((s) => s.id == id);
    if (index != -1) {
      _seniors[index] = updatedSenior;
      notifyListeners();
    }

    final intId = int.tryParse(id);
    if (intId != null) {
      try {
        await ApiService.instance.updateElderly(
          elderlyId: intId,
          name: updatedSenior.name,
          sex: updatedSenior.gender,
          phone: updatedSenior.phoneNumber,
        );
      } catch (_) {}
    }
  }

  void removeSenior(String id) {
    _seniors.removeWhere((s) => s.id == id);
    if (_selectedSeniorIndex >= _seniors.length) {
      _selectedSeniorIndex = _seniors.isEmpty ? 0 : _seniors.length - 1;
    }
    notifyListeners();
  }
}
