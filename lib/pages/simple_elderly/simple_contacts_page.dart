import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/api_service.dart';
import '../../core/services/senior_manager.dart';

/// شاشة الإتصال البسيطة (Simple Contacts Screen)
/// مربوطة بقاعدة البيانات MySQL لجهات اتصال الطوارئ
class SimpleContactsPage extends StatefulWidget {
  const SimpleContactsPage({super.key});

  @override
  State<SimpleContactsPage> createState() => _SimpleContactsPageState();
}

class _SimpleContactsPageState extends State<SimpleContactsPage> {
  List<Map<String, String>> contacts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final senior = SeniorManager().currentSenior;
      final int? seniorId = int.tryParse(senior.id);
      final list = await ApiService.instance.getEmergencyContacts(elderlyId: seniorId);
      if (mounted) {
        setState(() {
          contacts = list.map((c) {
            return {
              'name': (c['contact_Name'] ?? 'جهة اتصال').toString(),
              'phone': (c['Phone_Number'] ?? '').toString(),
              'relation': (c['Relationship'] ?? 'طوارئ').toString(),
            };
          }).toList();
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'تعذّر تحميل جهات الاتصال. يرجى التأكد من الاتصال بالشبكة.',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 16),
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _makeCall(BuildContext context, String name, String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'جاري الاتصال بـ $name ($phone)...',
              style: GoogleFonts.cairo(fontSize: 16),
            ),
            backgroundColor: const Color(0xFF00C853),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // الشريط العلوي المطابق لـ Figma: سهم الرجوع + العنوان "الإتصال" + أيقونة هاتف خضراء
            _buildTopAppBar(context),

            const SizedBox(height: 24),

            // قائمة جهات الاتصال البسيطة
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C853)))
                  : contacts.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.phone_disabled_outlined, size: 64, color: Colors.grey),
                                const SizedBox(height: 12),
                                Text(
                                  'لا توجد جهات اتصال طوارئ مسجلة حالياً',
                                  style: GoogleFonts.cairo(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          itemCount: contacts.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 18),
                          itemBuilder: (context, index) {
                            final contact = contacts[index];
                            final isFemale = contact['relation']?.contains('ابنة') ?? false;

                            return _buildContactCard(
                              context: context,
                              name: contact['name']!,
                              phone: contact['phone']!,
                              isFemale: isFemale,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // سهم الرجوع الرمادي/الأسود
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_rounded,
              color: Colors.black87,
              size: 28,
            ),
            onPressed: () => Navigator.pop(context),
          ),

          // العنوان في المنتصف "الإتصال"
          Text(
            'الإتصال',
            style: GoogleFonts.cairo(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),

          // أيقونة هاتف خضراء مائلة مطابقة للصورة
          Transform.rotate(
            angle: -0.2,
            child: const Icon(
              Icons.phone_rounded,
              size: 36,
              color: Color(0xFF00C853),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required BuildContext context,
    required String name,
    required String phone,
    required bool isFemale,
  }) {
    return InkWell(
      onTap: () => _makeCall(context, name, phone),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0), // الرمادي المطابق للـ Card في الصورة
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // الاسم بخط عريض وواضح جداً لكبير السن
            Text(
              name,
              style: GoogleFonts.cairo(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),

            // أيقونة الشخص (أنثى أو ذكر)
            Icon(
              isFemale ? Icons.face_3_rounded : Icons.person_rounded,
              size: 46,
              color: Colors.black87,
            ),
          ],
        ),
      ),
    );
  }
}
