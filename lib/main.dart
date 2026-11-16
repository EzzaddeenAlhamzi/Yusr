import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants/app_theme.dart';
import 'pages/welcome_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/who_are_you_page.dart';
import 'pages/choose_mode_page.dart';
import 'pages/simple_elderly/simple_home_page.dart';
import 'pages/simple_elderly/simple_contacts_page.dart';
import 'pages/simple_elderly/simple_medicines_page.dart';
import 'pages/simple_elderly/simple_return_home_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/link_senior_page.dart';

// صفحات مقدم الرعاية (Caregiver)
import 'pages/main_caregiver_page.dart';
import 'pages/medicines_page.dart';
import 'pages/appointments_page.dart';
import 'pages/location_page.dart';
import 'pages/health_status_page.dart';
import 'pages/senior_data_page.dart';
import 'pages/activity_log_page.dart';
import 'pages/devices_page.dart';
import 'pages/emergency_page.dart';
import 'pages/notifications_page.dart';
import 'pages/profile_page_caregiver.dart';
import 'pages/services_page.dart';

// صفحات كبير السن (Elderly)
import 'pages/home_page.dart';
import 'pages/dates.dart';
import 'pages/add_date.dart';
import 'pages/past_dates.dart';
import 'pages/medicines_page_elderly.dart';
import 'pages/add_medicine.dart';
import 'pages/location_page_elderly.dart';
import 'pages/emergency_page_elderly.dart';
import 'pages/profile_page_elderly.dart';
import 'pages/caregiver_page.dart';
import 'pages/return_home_page.dart';
import 'pages/health_page.dart';
import 'pages/devices_page_elderly.dart';
import 'pages/ai_page.dart';
import 'pages/senior_help_page.dart';
import 'pages/senior_notifications_page.dart';
import 'pages/senior_link_code_page.dart';
import 'pages/senior_link_success_page.dart';
import 'core/services/api_service.dart';
import 'pages/senior_location_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ─── فحص الاتصال بقاعدة البيانات عند بدء التطبيق (Health Check) ───
  _runStartupHealthCheck();

  runApp(const YusrApp());
}

/// فحص الاتصال بالخادم وقاعدة البيانات في الخلفية عند بدء التطبيق
/// يطبع نتائج تفصيلية في الـ Console دون أن يعيق واجهة المستخدم
void _runStartupHealthCheck() {
  Future.microtask(() async {
    // ignore: avoid_print
    print('┌─────────────────────────────────────────────────────┐');
    // ignore: avoid_print
    print('│  [يُسر API] جاري فحص الاتصال بالخادم وقاعدة البيانات...');
    // ignore: avoid_print
    print('└─────────────────────────────────────────────────────┘');

    try {
      // 1. كشف الخادم النشط
      final serverUrl = await ApiService.instance.discoverWorkingServer();

      if (serverUrl == null) {
        // ignore: avoid_print
        print('[يُسر API] ⚠️  تعذّر الاتصال بأي خادم. تأكد من تشغيل Laravel (php artisan serve)');
        return;
      }

      // ignore: avoid_print
      print('[يُسر API] ✅ خادم نشط: $serverUrl');

      // 2. فحص الاتصال الفعلي (ping)
      final ping = await ApiService.instance.testConnection();
      if (ping['status'] == 'success') {
        // ignore: avoid_print
        print('[يُسر API] ✅ قاعدة البيانات: ${ping['database'] ?? 'yusr_application'} | إطار: ${ping['framework'] ?? 'Laravel'}');
      } else {
        // ignore: avoid_print
        print('[يُسر API] ❌ فشل فحص قاعدة البيانات: ${ping['message']}');
        return;
      }

      // 3. جلب الخدمات للتحقق من اتصال قاعدة البيانات
      final services = await ApiService.instance.getServices();
      // ignore: avoid_print
      print('[يُسر API] ✅ جدول services: ${services.length} خدمة متاحة');

      // ignore: avoid_print
      print('[يُسر API] ✅ جميع الاتصالات تعمل بنجاح 🎉');
    } catch (e) {
      // ignore: avoid_print
      print('[يُسر API] ❌ خطأ في فحص الاتصال: $e');
    }
  });
}


/// التطبيق الرئيسي (Yusr App)
class YusrApp extends StatelessWidget {
  const YusrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'يُسر - معاً نهتم',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme.copyWith(
        textTheme: GoogleFonts.cairoTextTheme(Theme.of(context).textTheme),
      ),
      locale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      initialRoute: '/',
      routes: {
        // تدفق البداية والتسجيل
        '/': (context) => const WelcomePage(),
        '/onboarding': (context) => const OnboardingPage(),
        '/who-are-you': (context) => const WhoAreYouPage(),
        '/choose-mode': (context) => const ChooseModePage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/link-senior': (context) => const LinkSeniorPage(),

        // مسارات الوضع البسيط لكبير السن (Simple Elderly Mode)
        '/simple-home': (context) => const SimpleHomePage(),
        '/simple-contacts': (context) => const SimpleContactsPage(),
        '/simple-medicines': (context) => const SimpleMedicinesPage(),
        '/simple-return-home': (context) => const SimpleReturnHomePage(),

        // مسارات مقدم الرعاية (Caregiver Flow)
        '/main-caregiver': (context) => const MainCaregiverPage(),
        '/medicines': (context) => const MedicinesPage(),
        '/appointments': (context) => const AppointmentsPage(),
        '/location': (context) => const LocationPage(),
        '/health-status': (context) => const HealthStatusPage(),
        '/senior-data': (context) => const SeniorDataPage(),
        '/activity-log': (context) => const ActivityLogPage(),
        '/devices': (context) => const DevicesPage(),
        '/emergency': (context) => const EmergencyPage(),
        '/notifications': (context) => const NotificationsPage(),
        '/profile': (context) => const ProfilePageCaregiver(),
        '/services': (context) => const ServicesPage(),

        // مسارات وضع كبير السن (Elderly Flow)
        '/home-elderly': (context) => const HomePage(),
        '/dates': (context) => const DatesScreen(),
        '/add-date': (context) => const AddDateScreen(),
        '/past-dates': (context) => const PastDatesScreen(),
        '/medicines-elderly': (context) => const MedicinesPageElderly(),
        '/add-medicine': (context) => const AddMedicineScreen(),
        '/location-elderly': (context) => const LocationPageElderly(),
        '/emergency-elderly': (context) => const EmergencyPageElderly(),
        '/profile-elderly': (context) => const ProfilePageElderly(),
        '/caregiver-contact': (context) => const CaregiverPage(),
        '/return-home': (context) => const ReturnHomePage(),
        '/health': (context) => const HealthPage(),
        '/devices-elderly': (context) => const DevicesPageElderly(),
        '/elderly-devices': (context) => const DevicesPageElderly(),
        '/ai': (context) => const AIPage(),
        '/senior-help': (context) => const SeniorHelpPage(),
        '/senior-notifications': (context) => const SeniorNotificationsPage(),
        '/senior-link-code': (context) => const SeniorLinkCodePage(),
        '/senior-link-success': (context) => const SeniorLinkSuccessPage(),
        '/senior-location': (context) => const SeniorLocationPage(),
      },
    );
  }
}
