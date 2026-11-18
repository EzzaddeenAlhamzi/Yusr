import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants/app_theme.dart';
import 'core/services/api_service.dart';
import 'core/widgets/auth_route_guard.dart';
import 'core/widgets/session_bootstrap_page.dart';
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
import 'pages/senior_location_page.dart';

/// Root navigator — used for 401 redirect without loops.
final GlobalKey<NavigatorState> yusrNavigatorKey = GlobalKey<NavigatorState>();

bool _unauthorizedNavInFlight = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ApiService.instance.ensureAuthHooksForSession();
  ApiService.onUnauthorized = _handleUnauthorized;

  // ─── فحص الاتصال بقاعدة البيانات عند بدء التطبيق (Health Check) ───
  _runStartupHealthCheck();

  runApp(const YusrApp());
}

/// Public auth / marketing surfaces — 401 must never bounce these to caregiver login.
const Set<String> _publicAuthRoutes = {
  '/',
  '/welcome',
  '/login',
  '/register',
  '/onboarding',
  '/who-are-you',
  '/choose-mode',
};

void _handleUnauthorized(String? _) {
  // Argument ignored on purpose: caregiver-default /login blocked elderly UI (EMA).
  if (_unauthorizedNavInFlight) return;
  final nav = yusrNavigatorKey.currentState;
  if (nav == null) return;

  // NavigatorKey.context's ModalRoute is unreliable; read the top route name safely.
  String? name;
  nav.popUntil((route) {
    name = route.settings.name;
    return true;
  });
  if (name != null && _publicAuthRoutes.contains(name)) {
    return;
  }

  _unauthorizedNavInFlight = true;
  nav.pushNamedAndRemoveUntil('/welcome', (r) => false).whenComplete(() {
    _unauthorizedNavInFlight = false;
  });
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

Widget _caregiver(Widget child) =>
    AuthRouteGuard(requiredRole: 'caregiver', child: child);

Widget _senior(Widget child) =>
    AuthRouteGuard(requiredRole: 'senior', child: child);

/// التطبيق الرئيسي (Yusr App)
class YusrApp extends StatelessWidget {
  const YusrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: yusrNavigatorKey,
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
        // تدفق البداية والتسجيل — P1.3 bootstrap validates session first
        '/': (context) => const SessionBootstrapPage(),
        '/welcome': (context) => const WelcomePage(),
        '/onboarding': (context) => const OnboardingPage(),
        '/who-are-you': (context) => const WhoAreYouPage(),
        '/choose-mode': (context) => const ChooseModePage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/link-senior': (context) =>
            _caregiver(const LinkSeniorPage()),

        // مسارات الوضع البسيط لكبير السن (Simple Elderly Mode)
        '/simple-home': (context) => _senior(const SimpleHomePage()),
        '/simple-contacts': (context) => _senior(const SimpleContactsPage()),
        '/simple-medicines': (context) => _senior(const SimpleMedicinesPage()),
        '/simple-return-home': (context) =>
            _senior(const SimpleReturnHomePage()),

        // مسارات مقدم الرعاية (Caregiver Flow)
        '/main-caregiver': (context) => _caregiver(const MainCaregiverPage()),
        '/medicines': (context) => _caregiver(const MedicinesPage()),
        '/appointments': (context) => _caregiver(const AppointmentsPage()),
        '/location': (context) => _caregiver(const LocationPage()),
        '/health-status': (context) => _caregiver(const HealthStatusPage()),
        '/senior-data': (context) => _caregiver(const SeniorDataPage()),
        '/activity-log': (context) => _caregiver(const ActivityLogPage()),
        '/devices': (context) => _caregiver(const DevicesPage()),
        '/emergency': (context) => _caregiver(const EmergencyPage()),
        '/notifications': (context) => _caregiver(const NotificationsPage()),
        '/profile': (context) => _caregiver(const ProfilePageCaregiver()),
        '/services': (context) => _caregiver(const ServicesPage()),

        // مسارات وضع كبير السن (Elderly Flow)
        '/home-elderly': (context) => _senior(const HomePage()),
        '/dates': (context) => _senior(const DatesScreen()),
        '/add-date': (context) => _senior(const AddDateScreen()),
        '/past-dates': (context) => _senior(const PastDatesScreen()),
        '/medicines-elderly': (context) => _senior(const MedicinesPageElderly()),
        '/add-medicine': (context) => _senior(const AddMedicineScreen()),
        '/location-elderly': (context) => _senior(const LocationPageElderly()),
        '/emergency-elderly': (context) =>
            _senior(const EmergencyPageElderly()),
        '/profile-elderly': (context) => _senior(const ProfilePageElderly()),
        '/caregiver-contact': (context) => _senior(const CaregiverPage()),
        '/return-home': (context) => _senior(const ReturnHomePage()),
        '/health': (context) => _senior(const HealthPage()),
        '/devices-elderly': (context) => _senior(const DevicesPageElderly()),
        '/elderly-devices': (context) => _senior(const DevicesPageElderly()),
        '/ai': (context) => _senior(const AIPage()),
        '/senior-help': (context) => _senior(const SeniorHelpPage()),
        '/senior-notifications': (context) =>
            _senior(const SeniorNotificationsPage()),
        '/senior-link-code': (context) => _senior(const SeniorLinkCodePage()),
        '/senior-link-success': (context) =>
            _senior(const SeniorLinkSuccessPage()),
        '/senior-location': (context) => _senior(const SeniorLocationPage()),
      },
    );
  }
}
