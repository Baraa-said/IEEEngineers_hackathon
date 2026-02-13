import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// Language state provider — persists to Hive.
final languageProvider = StateNotifierProvider<LanguageNotifier, String>((ref) {
  return LanguageNotifier();
});

class LanguageNotifier extends StateNotifier<String> {
  LanguageNotifier() : super(_loadSaved());

  static String _loadSaved() {
    try {
      if (Hive.isBoxOpen('settings')) {
        final box = Hive.box('settings');
        return box.get('language', defaultValue: 'en') as String;
      }
    } catch (_) {}
    return 'en';
  }

  void toggle() {
    state = state == 'en' ? 'ar' : 'en';
    try {
      if (Hive.isBoxOpen('settings')) {
        Hive.box('settings').put('language', state);
      }
    } catch (_) {}
  }

  void setLanguage(String lang) {
    state = lang;
    try {
      if (Hive.isBoxOpen('settings')) {
        Hive.box('settings').put('language', state);
      }
    } catch (_) {}
  }

  bool get isArabic => state == 'ar';
}

/// All translatable strings.
class S {
  static Map<String, String> _get(String lang) => lang == 'ar' ? _ar : _en;

  static String t(String key, String lang) => _get(lang)[key] ?? key;

  static const _en = {
    // App
    'app_title': 'Aid NAV',
    'app_subtitle': 'Palestine West Bank Crisis Response',

    // Login & Signup
    'login': 'Login',
    'signup': 'Sign Up',
    'email': 'Email',
    'password': 'Password',
    'full_name': 'Full Name',
    'demo_user': 'Continue as Demo User',
    'demo_credentials': 'Demo Credentials',
    'login_failed': 'Login failed. Check your credentials.',
    'signup_hint': 'Password must be at least 8 characters',
    'remember_me': 'Remember me',
    'guest': 'Guest',

    // Home
    'welcome': 'Welcome',
    'ask_question': 'Ask a Question',
    'ask_subtitle': 'Query facilities, resources & incidents',
    'quick_actions': 'Quick Actions',
    'facilities': 'Facilities',
    'facilities_sub': 'Hospitals & clinics',
    'map_view': 'Map View',
    'map_sub': 'Interactive crisis map',
    'resources': 'Resources',
    'resources_sub': 'Ambulances & shelters',
    'incidents': 'Incidents',
    'incidents_sub': 'Active alerts',
    'try_queries': 'Try These Queries',

    // Query
    'ask_hint': 'Ask about facilities, resources...',
    'analyzing': 'Analyzing your query...',
    'ai_response': 'AI Response',
    'locations_found': 'Locations Found',
    'view_on_map': 'View on Map',
    'data_sources': 'Data Sources',
    'share': 'Share',
    'save': 'Save',
    'export': 'Export',
    'recent_queries': 'Recent Queries',
    'suggested_queries': 'Suggested Queries',
    'type_question': 'Type your question above',
    'try_again': 'Try Again',
    'high_confidence': 'High Confidence',
    'medium_confidence': 'Medium Confidence',
    'low_confidence': 'Low Confidence',

    // Facilities
    'health_facilities': 'Health Facilities',
    'search_facilities': 'Search facilities...',
    'filter': 'Filter Facilities',
    'sort': 'Sort',
    'sort_name': 'Sort by Name',
    'sort_beds': 'Sort by Beds',
    'sort_status': 'Sort by Status',
    'type': 'Type',
    'status': 'Status',
    'all': 'All',
    'hospital': 'Hospital',
    'clinic': 'Clinic',
    'pharmacy': 'Pharmacy',
    'ambulance': 'Ambulance',
    'operational': 'Operational',
    'reduced': 'Reduced',
    'damaged': 'Damaged',
    'no_facilities': 'No facilities found',
    'beds': 'Beds',
    'icu': 'ICU',
    'trauma': 'Trauma',
    'power': 'Power',
    'oxygen': 'O₂',
    'error_loading': 'Error loading data',
    'retry': 'Retry',

    // Map
    'crisis_map': 'Crisis Map',

    // Settings
    'settings': 'Settings',
    'language': 'Language',
    'english': 'English',
    'arabic': 'العربية',
    'dark_mode': 'Dark Mode',
    'system_default': 'Use system default',
    'notifications': 'Push Notifications',
    'receive_alerts': 'Receive real-time alerts',
    'general': 'General',
    'data_connectivity': 'Data & Connectivity',
    'offline_data': 'Offline Data',
    'download_maps': 'Download maps and facility data',
    'clear_cache': 'Clear Cache',
    'remove_cached': 'Remove cached queries and data',
    'cache_cleared': 'Cache cleared',
    'api_server': 'API Server',
    'emergency': 'Emergency',
    'emergency_mode': 'Emergency Mode',
    'emergency_desc': 'High-visibility UI with larger controls',
    'about': 'About',
    'version': 'Version',
    'ethics': 'Ethics & Privacy Policy',
    'licenses': 'Open Source Licenses',
    'logout': 'Logout',
    'no_alerts': 'No new alerts',

    // Sample queries
    'q1': 'Where is the nearest hospital?',
    'q2': 'Show shelters within 5km of Ramallah',
    'q3': 'Facilities with power and oxygen?',
    'q4': 'How many hospitals are operational?',

    // SOS
    'sos_button': 'SOS',
    'sos_title': 'Emergency Help',
    'sos_desc': 'Choose who to call for immediate help:',
    'sos_red_crescent': 'Red Crescent',
    'sos_civil_defense': 'Civil Defense',
    'sos_police': 'Police',
    'sos_nearest': 'Nearest Hospital',
    'sos_find': 'Find on map',
    'sos_sent': 'SOS alert sent successfully',
    'finding_hospital': 'Finding nearest hospital...',
    'no_hospital_found': 'No operational hospital found nearby',
    'location_disabled': 'Location services are disabled',
    'location_denied': 'Location permission denied',
    'location_denied_forever': 'Location permanently denied. Enable in Settings.',
    'cancel': 'Cancel',
  };

  static const _ar = {
    // App
    'app_title': 'Aid NAV',
    'app_subtitle': 'استجابة أزمة الضفة الغربية - فلسطين',

    // Login & Signup
    'login': 'تسجيل الدخول',
    'signup': 'إنشاء حساب',
    'email': 'البريد الإلكتروني',
    'password': 'كلمة المرور',
    'full_name': 'الاسم الكامل',
    'demo_user': 'متابعة كمستخدم تجريبي',
    'demo_credentials': 'بيانات الدخول التجريبية',
    'login_failed': 'فشل تسجيل الدخول. تحقق منبياناتك.',
    'signup_hint': 'كلمة المرور يجب أن تكون 8 أحرف على الأقل',
    'remember_me': 'تذكرني',
    'guest': 'ضيف',

    // Home
    'welcome': 'مرحباً',
    'ask_question': 'اطرح سؤالاً',
    'ask_subtitle': 'استعلم عن المرافق والموارد والحوادث',
    'quick_actions': 'إجراءات سريعة',
    'facilities': 'المرافق',
    'facilities_sub': 'مستشفيات وعيادات',
    'map_view': 'الخريطة',
    'map_sub': 'خريطة الأزمات التفاعلية',
    'resources': 'الموارد',
    'resources_sub': 'إسعاف وملاجئ',
    'incidents': 'الحوادث',
    'incidents_sub': 'تنبيهات نشطة',
    'try_queries': 'جرّب هذه الاستعلامات',

    // Query
    'ask_hint': 'اسأل عن المرافق والموارد...',
    'analyzing': 'جارٍ تحليل استعلامك...',
    'ai_response': 'استجابة الذكاء الاصطناعي',
    'locations_found': 'المواقع المعثور عليها',
    'view_on_map': 'عرض على الخريطة',
    'data_sources': 'مصادر البيانات',
    'share': 'مشاركة',
    'save': 'حفظ',
    'export': 'تصدير',
    'recent_queries': 'الاستعلامات الأخيرة',
    'suggested_queries': 'استعلامات مقترحة',
    'type_question': 'اكتب سؤالك أعلاه',
    'try_again': 'حاول مجدداً',
    'high_confidence': 'ثقة عالية',
    'medium_confidence': 'ثقة متوسطة',
    'low_confidence': 'ثقة منخفضة',

    // Facilities
    'health_facilities': 'المرافق الصحية',
    'search_facilities': 'ابحث عن مرافق...',
    'filter': 'تصفية المرافق',
    'sort': 'ترتيب',
    'sort_name': 'ترتيب حسب الاسم',
    'sort_beds': 'ترتيب حسب الأسرّة',
    'sort_status': 'ترتيب حسب الحالة',
    'type': 'النوع',
    'status': 'الحالة',
    'all': 'الكل',
    'hospital': 'مستشفى',
    'clinic': 'عيادة',
    'pharmacy': 'صيدلية',
    'ambulance': 'إسعاف',
    'operational': 'عامل',
    'reduced': 'طاقة مخفضة',
    'damaged': 'متضرر',
    'no_facilities': 'لم يتم العثور على مرافق',
    'beds': 'أسرّة',
    'icu': 'عناية',
    'trauma': 'طوارئ',
    'power': 'كهرباء',
    'oxygen': 'أكسجين',
    'error_loading': 'خطأ في تحميل البيانات',
    'retry': 'إعادة المحاولة',

    // Map
    'crisis_map': 'خريطة الأزمات',

    // Settings
    'settings': 'الإعدادات',
    'language': 'اللغة',
    'english': 'English',
    'arabic': 'العربية',
    'dark_mode': 'الوضع الداكن',
    'system_default': 'استخدام إعداد النظام',
    'notifications': 'الإشعارات',
    'receive_alerts': 'تلقي تنبيهات فورية',
    'general': 'عام',
    'data_connectivity': 'البيانات والاتصال',
    'offline_data': 'بيانات بدون إنترنت',
    'download_maps': 'تحميل الخرائط وبيانات المرافق',
    'clear_cache': 'مسح التخزين المؤقت',
    'remove_cached': 'إزالة الاستعلامات والبيانات المخزنة',
    'cache_cleared': 'تم مسح التخزين المؤقت',
    'api_server': 'خادم API',
    'emergency': 'طوارئ',
    'emergency_mode': 'وضع الطوارئ',
    'emergency_desc': 'واجهة عالية الوضوح مع أزرار أكبر',
    'about': 'حول',
    'version': 'الإصدار',
    'ethics': 'سياسة الخصوصية والأخلاقيات',
    'licenses': 'تراخيص مفتوحة المصدر',
    'logout': 'تسجيل الخروج',
    'no_alerts': 'لا توجد تنبيهات جديدة',

    // Sample queries
    'q1': 'أين أقرب مستشفى؟',
    'q2': 'أظهر الملاجئ ضمن ٥ كم من رام الله',
    'q3': 'المرافق التي لديها كهرباء وأكسجين؟',
    'q4': 'كم عدد المستشفيات العاملة؟',
    // SOS
    'sos_button': 'نجدة',
    'sos_title': 'مساعدة طارئة',
    'sos_desc': 'اختر من تريد الاتصال به للمساعدة الفورية:',
    'sos_red_crescent': 'الهلال الأحمر',
    'sos_civil_defense': 'الدفاع المدني',
    'sos_police': 'الشرطة',
    'sos_nearest': 'أقرب مستشفى',
    'sos_find': 'اعثر على الخريطة',
    'sos_sent': 'تم إرسال تنبيه النجدة بنجاح',
    'finding_hospital': 'جارٍ البحث عن أقرب مستشفى...',
    'no_hospital_found': 'لم يتم العثور على مستشفى عامل قريب',
    'location_disabled': 'خدمات الموقع معطلة',
    'location_denied': 'تم رفض إذن الموقع',
    'location_denied_forever': 'تم رفض الموقع نهائياً. فعّله من الإعدادات.',
    'cancel': 'إلغاء',  };
}
