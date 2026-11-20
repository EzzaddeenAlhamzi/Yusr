class SeniorModel {
  final String id;
  String name;
  String relationship;
  int age;
  String bloodType;
  String gender;
  String phoneNumber; // E_PhonNumber في قاعدة البيانات
  String healthStatus; // 'مستقر', 'يحتاج متابعة', 'تنبيه'
  List<String> chronicDiseases;
  String allergies;
  List<String> criticalMedications;
  String doctorName;
  String hospital;
  String location;
  String nextTask;
  String nextTaskTime;
  String sleepHours;
  String steps;
  int watchBattery;
  String watchModel;
  bool watchConnected;
  String pairingCode;
  String avatarAsset;

  SeniorModel({
    required this.id,
    required this.name,
    required this.relationship,
    required this.age,
    required this.bloodType,
    this.gender = 'غير محدد',
    this.phoneNumber = '',
    this.healthStatus = 'غير متوفر',
    required this.chronicDiseases,
    required this.allergies,
    required this.criticalMedications,
    required this.doctorName,
    required this.hospital,
    required this.location,
    required this.nextTask,
    required this.nextTaskTime,
    this.sleepHours = '',
    this.steps = '',
    this.watchBattery = 0,
    this.watchModel = '',
    this.watchConnected = false,
    required this.pairingCode,
    this.avatarAsset = '',
  });

  SeniorModel copyWith({
    String? name,
    String? relationship,
    int? age,
    String? bloodType,
    String? gender,
    String? phoneNumber,
    String? healthStatus,
    List<String>? chronicDiseases,
    String? allergies,
    List<String>? criticalMedications,
    String? doctorName,
    String? hospital,
    String? location,
    String? nextTask,
    String? nextTaskTime,
    String? sleepHours,
    String? steps,
    int? watchBattery,
    String? watchModel,
    bool? watchConnected,
    String? pairingCode,
    String? avatarAsset,
  }) {
    return SeniorModel(
      id: id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      age: age ?? this.age,
      bloodType: bloodType ?? this.bloodType,
      gender: gender ?? this.gender,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      healthStatus: healthStatus ?? this.healthStatus,
      chronicDiseases: chronicDiseases ?? this.chronicDiseases,
      allergies: allergies ?? this.allergies,
      criticalMedications: criticalMedications ?? this.criticalMedications,
      doctorName: doctorName ?? this.doctorName,
      hospital: hospital ?? this.hospital,
      location: location ?? this.location,
      nextTask: nextTask ?? this.nextTask,
      nextTaskTime: nextTaskTime ?? this.nextTaskTime,
      sleepHours: sleepHours ?? this.sleepHours,
      steps: steps ?? this.steps,
      watchBattery: watchBattery ?? this.watchBattery,
      watchModel: watchModel ?? this.watchModel,
      watchConnected: watchConnected ?? this.watchConnected,
      pairingCode: pairingCode ?? this.pairingCode,
      avatarAsset: avatarAsset ?? this.avatarAsset,
    );
  }
}
