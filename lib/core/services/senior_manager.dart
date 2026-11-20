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
              nextTask = (meds.first['M_Name'] ?? 'تناول الدواء').toString();
              // DB column is M_RepatTime (legacy typo); never invent M_Time.
              nextTaskTime =
                  (meds.first['M_RepatTime'] ?? meds.first['M_Time'] ?? '--:--')
                      .toString();
            } else if (appts.isNotEmpty) {
              nextTask = (appts.first['A_DateType'] ?? 'موعد طبي').toString();
              nextTaskTime = (appts.first['A_Time'] ?? '--:--').toString();
            }

            String sName = (item['E_Name'] ?? '').toString().trim();
            if (sName.isEmpty || RegExp(r'^[\?\s]+$').hasMatch(sName)) sName = 'كبير السن';

            _seniors.add(SeniorModel(
              id: (item['Eldery_ID'] ?? linkedId).toString(),
              name: sName,
              gender: (item['E_sex'] ?? 'غير محدد').toString(),
              phoneNumber: (item['E_PhonNumber'] ?? '').toString(),
              relationship: 'كبير السن المشمول بالرعاية',
              age: 0,
              bloodType: 'غير محدد',
              // No health summary column — do not invent "مستقر".
              healthStatus: 'غير متوفر',
              chronicDiseases: [],
              allergies: 'غير محدد',
              criticalMedications: meds.map((m) => (m['M_Name'] ?? '').toString()).where((m) => m.isNotEmpty).toList(),
              doctorName: 'غير محدد',
              hospital: 'غير محدد',
              location: 'الموقع غير محدد',
              nextTask: nextTask,
              nextTaskTime: nextTaskTime,
              // Pairing codes are temporary server secrets — never invent YS-{id}.
              pairingCode: '——',
              watchConnected: hasWatch,
              watchModel: watchModel,
              // Battery % is not in devices table — never fake 85%.
              watchBattery: 0,
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
              nextTask = (meds.first['M_Name'] ?? 'تناول الدواء').toString();
              nextTaskTime =
                  (meds.first['M_RepatTime'] ?? meds.first['M_Time'] ?? '--:--')
                      .toString();
            } else if (appts.isNotEmpty) {
              nextTask = (appts.first['A_DateType'] ?? 'موعد طبي').toString();
              nextTaskTime = (appts.first['A_Time'] ?? '--:--').toString();
            }

            String myName = (item['E_Name'] ?? '').toString().trim();
            if (myName.isEmpty || RegExp(r'^[\?\s]+$').hasMatch(myName)) myName = 'كبير السن';

            _seniors.add(SeniorModel(
              id: (item['Eldery_ID'] ?? myId).toString(),
              name: myName,
              gender: (item['E_sex'] ?? 'غير محدد').toString(),
              phoneNumber: (item['E_PhonNumber'] ?? '').toString(),
              relationship: 'حسابي',
              age: 0,
              bloodType: 'غير محدد',
              healthStatus: 'غير متوفر',
              chronicDiseases: [],
              allergies: 'غير محدد',
              criticalMedications: meds.map((m) => (m['M_Name'] ?? '').toString()).where((m) => m.isNotEmpty).toList(),
              doctorName: 'غير محدد',
              hospital: 'غير محدد',
              location: 'الموقع غير محدد',
              nextTask: nextTask,
              nextTaskTime: nextTaskTime,
              pairingCode: '——',
              watchConnected: hasWatch,
              watchModel: watchModel,
              watchBattery: 0,
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

  /// Local-only add without API is dishonest. Prefer `/link-senior`.
  /// Returns false and does not mutate the list — callers must use linking.
  Future<bool> addSenior(SeniorModel senior) async {
    // registerElderly requires password — never invent a local "linked" senior.
    return false;
  }

  /// Updates local cache after a successful API persist.
  /// Returns false when the server update fails (local list unchanged on API fail).
  Future<bool> updateSenior(String id, SeniorModel updatedSenior) async {
    final intId = int.tryParse(id);
    if (intId == null) {
      return false;
    }
    try {
      final res = await ApiService.instance.updateElderly(
        elderlyId: intId,
        name: updatedSenior.name,
        sex: updatedSenior.gender,
        phone: updatedSenior.phoneNumber,
      );
      if (res['status'] != 'success') {
        return false;
      }
      final index = _seniors.indexWhere((s) => s.id == id);
      if (index != -1) {
        _seniors[index] = updatedSenior;
        notifyListeners();
      }
      return true;
    } catch (_) {
      return false;
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
