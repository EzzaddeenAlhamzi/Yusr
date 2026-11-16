import 'package:flutter/material.dart';
import 'profile_page_caregiver.dart';

export 'profile_page_caregiver.dart';

/// صفحة الملف الشخصي لمقدم الرعاية - متصلة بالكامل بقاعدة البيانات MySQL
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfilePageCaregiver();
  }
}
